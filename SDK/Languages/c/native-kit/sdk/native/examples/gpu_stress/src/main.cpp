#include <nexvyn/nexvyn_native.h>
#include <GL/glcorearb.h>

#include <algorithm>
#include <array>
#include <cctype>
#include <cstdio>
#include <cstdlib>
#include <cstring>

namespace {

constexpr unsigned kBatchFrames = 300;
constexpr uint64_t kSecondNs = 1000000000;
constexpr uint32_t kWidth = 800, kHeight = 450;

struct Load {
    GLsizei textureSide;
    int draws;
    GLint taps;
};

constexpr Load kLoads[] = {{64, 1, 1}, {256, 4, 2}, {512, 16, 3},
                           {1024, 48, 5}, {2048, 96, 8}};

struct Settings {
    unsigned level = 0;
    unsigned seconds = 45;
    uint32_t width = kWidth;
    uint32_t height = kHeight;
};

bool readSettings(Settings& settings) {
    // App data load.txt contains a level, an optional duration, and an optional measurement extent.
    char input[32];
    size_t size = 0;
    nxn_result read = nxn_fs_read(NXN_DIR_DATA, "load.txt", input, sizeof(input) - 1, &size);
    if (read == NXN_ERR_NOT_FOUND) return true;
    if (read != NXN_OK || size == 0 || input[0] < '0' || input[0] > '4' ||
        std::memchr(input, '\0', size)) return false;
    input[size] = '\0';
    settings.level = static_cast<unsigned>(input[0] - '0');
    char* duration = input + 1;
    if (*duration && !std::isspace(static_cast<unsigned char>(*duration))) return false;
    while (std::isspace(static_cast<unsigned char>(*duration))) ++duration;
    if (!*duration) return true;
    if (*duration < '0' || *duration > '9') return false;
    char* end = nullptr;
    unsigned long seconds = std::strtoul(duration, &end, 10);
    if (seconds < 1 || seconds > 180 || (*end && !std::isspace(static_cast<unsigned char>(*end)))) return false;
    while (std::isspace(static_cast<unsigned char>(*end))) ++end;
    if (*end) {
        char* extentEnd = end + std::strlen(end);
        while (extentEnd > end && std::isspace(static_cast<unsigned char>(extentEnd[-1]))) --extentEnd;
        *extentEnd = '\0';
        if (std::strcmp(end, "720p") == 0) {
            settings.width = 1280;
            settings.height = 720;
        } else if (std::strcmp(end, "1080p") == 0) {
            settings.width = 1920;
            settings.height = 1080;
        } else {
            return false;
        }
    }
    settings.seconds = static_cast<unsigned>(seconds);
    return true;
}

// Resolve only the calls this scene makes. All run on the display-owning thread.
#define STRESS_GL(X) \
    X(CREATESHADER, CreateShader) X(SHADERSOURCE, ShaderSource) X(COMPILESHADER, CompileShader) \
    X(GETSHADERIV, GetShaderiv) X(GETSHADERINFOLOG, GetShaderInfoLog) X(DELETESHADER, DeleteShader) \
    X(CREATEPROGRAM, CreateProgram) X(ATTACHSHADER, AttachShader) X(LINKPROGRAM, LinkProgram) \
    X(GETPROGRAMIV, GetProgramiv) X(GETPROGRAMINFOLOG, GetProgramInfoLog) X(DELETEPROGRAM, DeleteProgram) \
    X(USEPROGRAM, UseProgram) X(GETUNIFORMLOCATION, GetUniformLocation) X(UNIFORM1I, Uniform1i) \
    X(UNIFORM1F, Uniform1f) X(GENVERTEXARRAYS, GenVertexArrays) X(BINDVERTEXARRAY, BindVertexArray) \
    X(DELETEVERTEXARRAYS, DeleteVertexArrays) X(GENTEXTURES, GenTextures) X(BINDTEXTURE, BindTexture) \
    X(TEXPARAMETERI, TexParameteri) X(TEXIMAGE2D, TexImage2D) X(DELETETEXTURES, DeleteTextures) \
    X(VIEWPORT, Viewport) X(ENABLE, Enable) X(BLENDFUNC, BlendFunc) X(DRAWARRAYS, DrawArrays) \
    X(CLEAR, Clear) X(CLEARCOLOR, ClearColor) X(GETERROR, GetError)

struct Gl {
#define DECLARE(type, name) PFNGL##type##PROC name = nullptr;
    STRESS_GL(DECLARE)
#undef DECLARE

    bool resolve() {
#define RESOLVE(type, name) \
        name = reinterpret_cast<PFNGL##type##PROC>(nxn_display_proc("gl" #name)); \
        if (!name) return false;
        STRESS_GL(RESOLVE)
#undef RESOLVE
        return true;
    }
};
#undef STRESS_GL

constexpr const char* kVertex = R"(
#version 330 core
out vec2 uv;
void main() {
    uv = vec2((gl_VertexID << 1) & 2, gl_VertexID & 2);
    gl_Position = vec4(uv * 2.0 - 1.0, 0.0, 1.0);
}
)";

constexpr const char* kFragment = R"(
#version 330 core
in vec2 uv;
out vec4 color;
uniform sampler2D image;
uniform float phase;
uniform int taps;
void main() {
    vec2 coord = uv * 1.71 + vec2(phase, phase * 0.71);
    vec3 sum = vec3(0.0);
    for (int i = 0; i < taps; ++i) {
        vec3 sampleColor = texture(image, coord).rgb;
        sum += sampleColor;
        coord = coord * 1.18 + sampleColor.rg * 0.47 + 0.013;
    }
    vec3 tint = vec3(0.42, 0.63, 0.85);
    color = vec4(mix(tint * 0.5, tint, uv.y) * (0.65 + 0.35 * sum / float(taps)), 0.38);
}
)";

GLuint compile(const Gl& gl, GLenum type, const char* source) {
    GLuint shader = gl.CreateShader(type);
    if (!shader) return 0;
    gl.ShaderSource(shader, 1, &source, nullptr);
    gl.CompileShader(shader);
    GLint ok = GL_FALSE;
    gl.GetShaderiv(shader, GL_COMPILE_STATUS, &ok);
    if (ok == GL_TRUE) return shader;
    char log[256] = {};
    gl.GetShaderInfoLog(shader, sizeof(log), nullptr, log);
    std::printf("GSTRESS: FAIL shader %s\n", log);
    gl.DeleteShader(shader);
    return 0;
}

struct Scene {
    Gl gl;
    GLuint vao = 0, program = 0, texture = 0;
    GLint phase = -1;

    ~Scene() {
        if (texture) gl.DeleteTextures(1, &texture);
        if (vao) gl.DeleteVertexArrays(1, &vao);
        if (program) {
            gl.UseProgram(0);
            gl.DeleteProgram(program);
        }
    }

    bool init(const Load& load, uint32_t width, uint32_t height) {
        if (!gl.resolve()) return false;
        GLuint vertex = compile(gl, GL_VERTEX_SHADER, kVertex);
        GLuint fragment = compile(gl, GL_FRAGMENT_SHADER, kFragment);
        if (vertex && fragment) program = gl.CreateProgram();
        if (program) {
            gl.AttachShader(program, vertex);
            gl.AttachShader(program, fragment);
            gl.LinkProgram(program);
        }
        if (vertex) gl.DeleteShader(vertex);
        if (fragment) gl.DeleteShader(fragment);
        if (!program) return false;
        GLint linked = GL_FALSE;
        gl.GetProgramiv(program, GL_LINK_STATUS, &linked);
        if (linked != GL_TRUE) {
            char log[256] = {};
            gl.GetProgramInfoLog(program, sizeof(log), nullptr, log);
            std::printf("GSTRESS: FAIL link %s\n", log);
            return false;
        }
        const size_t texels = static_cast<size_t>(load.textureSide) * load.textureSide;
        auto* pixels = static_cast<uint8_t*>(std::malloc(texels * 4));
        if (!pixels) return false;
        uint32_t noise = 1;
        for (size_t index = 0; index < texels * 4; ++index) {
            noise = noise * 1664525u + 1013904223u;
            pixels[index] = static_cast<uint8_t>(noise >> 24);
        }
        gl.GenTextures(1, &texture);
        gl.BindTexture(GL_TEXTURE_2D, texture);
        gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        gl.TexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
        gl.TexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, load.textureSide, load.textureSide, 0,
                      GL_RGBA, GL_UNSIGNED_BYTE, pixels);
        std::free(pixels);
        gl.GenVertexArrays(1, &vao);
        gl.BindVertexArray(vao);
        gl.UseProgram(program);
        phase = gl.GetUniformLocation(program, "phase");
        GLint taps = gl.GetUniformLocation(program, "taps");
        gl.Uniform1i(taps, load.taps);
        gl.Viewport(0, 0, width, height);
        gl.ClearColor(0.07f, 0.10f, 0.16f, 1.0f);
        gl.Enable(GL_BLEND);
        gl.BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        return texture && vao && phase >= 0 && taps >= 0 && gl.GetError() == GL_NO_ERROR;
    }

    void draw(const Load& load, unsigned frame) const {
        gl.Clear(GL_COLOR_BUFFER_BIT);
        for (int pass = 0; pass < load.draws; ++pass) {
            gl.Uniform1f(phase, ((frame % 251) + pass * 17) / 251.0f);
            gl.DrawArrays(GL_TRIANGLES, 0, 3);
        }
    }
};

int runScene(nxn_display* display, Settings settings) {
    uint32_t width = 0, height = 0;
    Scene scene;
    const Load& load = kLoads[settings.level];
    if (nxn_display_size(display, &width, &height) != NXN_OK || !width || !height ||
        !scene.init(load, width, height)) {
        std::printf("GSTRESS: FAIL setup level=%u\n", settings.level);
        return 1;
    }
    const uint64_t limit = nxn_time_ns() + settings.seconds * kSecondNs;
    bool suspended = false;
    unsigned frames = 0;
    std::array<uint64_t, kBatchFrames> elapsed{};
    while (!nxn_should_quit() && nxn_time_ns() < limit) {
        nxn_event event{};
        event.size = sizeof(event);
        while (nxn_event_poll(&event) > 0) {
            if (event.type == NXN_EVENT_SUSPEND) suspended = true;
            if (event.type == NXN_EVENT_RESUME) suspended = false;
        }
        if (nxn_should_quit()) break;
        if (suspended) {
            nxn_sleep_ns(10000000);
            continue;
        }
        const uint64_t start = nxn_time_ns();
        scene.draw(load, frames);
        if (nxn_display_swap(display) != NXN_OK) {
            std::printf("GSTRESS: FAIL swap level=%u\n", settings.level);
            return 1;
        }
        elapsed[frames % kBatchFrames] = nxn_time_ns() - start;
        if (++frames == 1) {
            std::printf("GSTRESS: BEGIN renderer=gl level=%u surface=%ux%u texture=%d draws=%d taps=%d\n",
                        settings.level, width, height, load.textureSide, load.draws, load.taps);
        }
        if (frames % kBatchFrames == 0) {
            std::sort(elapsed.begin(), elapsed.end());
            std::printf("GSTRESS: WINDOW level=%u frames=300 total=%u p50_ms=%.3f p95_ms=%.3f\n",
                        settings.level, frames, elapsed[149] / 1e6, elapsed[284] / 1e6);
        }
    }
    const bool finished = nxn_time_ns() >= limit;
    std::printf("GSTRESS: END level=%u frames=%u reason=%s\n", settings.level, frames,
                finished ? "duration" : "quit");
    return 0;
}

int runStress() {
    Settings settings;
    if (!readSettings(settings)) {
        std::printf("GSTRESS: FAIL load.txt\n");
        return 1;
    }
    nxn_display_params params{};
    params.size = sizeof(params);
    params.width = settings.width;
    params.height = settings.height;
    nxn_display* display = nullptr;
    if (nxn_display_open(&params, &display) != NXN_OK) {
        std::printf("GSTRESS: FAIL display level=%u\n", settings.level);
        return 1;
    }
    int result = runScene(display, settings);
    nxn_display_close(display);
    return result;
}

int appMain(int, char**) {
    int result = runStress();
    if (result != 0) std::puts(nxn_tr("stress.failed"));
    return result;
}

}  // namespace

int main(int argc, char** argv) {
    return nxn_run(argc, argv, appMain, nullptr);
}
