// Prism - a small but demanding Nexvyn native app (Native SDK 1.0 draft, exclusive mode).
// One full-screen fragment shader ray-marches a scene: reflective metal spheres orbiting a glowing ring over a
// checker floor, soft shadows, ambient occlusion, fog and a sky gradient. Everything goes through the nxn ABI:
// display (EGL + GLES 3.2), input (sticks, confirm action), audio (a synthesized chime), events (dock / handheld),
// logging into Nexvyn's app log and the return to Nexvyn OS.
//
//   left stick    orbit the camera          right stick   zoom / height
//   confirm (A)   chime                     +             back to Nexvyn OS
#include <nexvyn/nexvyn_native.h>
#include <GLES3/gl32.h>
#include <atomic>
#include <cmath>
#include <cstdio>
#include <cstring>

static const char* kVert = R"(#version 320 es
const vec2 P[3] = vec2[](vec2(-1.0,-1.0), vec2(3.0,-1.0), vec2(-1.0,3.0));
out vec2 uv;
void main() { vec2 p = P[gl_VertexID]; uv = p * 0.5 + 0.5; gl_Position = vec4(p, 0.0, 1.0); }
)";

static const char* kFrag = R"(#version 320 es
precision highp float;
in vec2 uv;
out vec4 frag;
uniform vec2 res;
uniform float t;
uniform vec3 eye;
uniform vec3 target;

float sdSphere(vec3 p, float r) { return length(p) - r; }
float sdTorus(vec3 p, vec2 q) { vec2 d = vec2(length(p.xz) - q.x, p.y); return length(d) - q.y; }

// x: distance, y: material (0 floor, 1 metal, 2 glow ring)
vec2 map(vec3 p) {
    vec2 r = vec2(p.y + 1.0, 0.0);
    for (int i = 0; i < 5; i++) {
        float a = t * 0.6 + float(i) * 1.2566;
        vec3 c = vec3(cos(a) * 2.2, 0.15 + 0.35 * sin(t * 1.3 + float(i)), sin(a) * 2.2);
        float d = sdSphere(p - c, 0.55);
        if (d < r.x) r = vec2(d, 1.0);
    }
    vec3 q = p - vec3(0.0, 0.2, 0.0);
    float ca = cos(t * 0.4), sa = sin(t * 0.4);
    q.xy = mat2(ca, -sa, sa, ca) * q.xy;
    float d = sdTorus(q, vec2(1.0, 0.12));
    if (d < r.x) r = vec2(d, 2.0);
    return r;
}

vec3 normalAt(vec3 p) {
    const vec2 e = vec2(0.0015, 0.0);
    return normalize(vec3(map(p + e.xyy).x - map(p - e.xyy).x, map(p + e.yxy).x - map(p - e.yxy).x,
                          map(p + e.yyx).x - map(p - e.yyx).x));
}

vec2 march(vec3 ro, vec3 rd, float maxd) {
    float d = 0.0;
    for (int i = 0; i < 96; i++) {
        vec2 h = map(ro + rd * d);
        if (h.x < 0.001) return vec2(d, h.y);
        d += h.x;
        if (d > maxd) break;
    }
    return vec2(-1.0);
}

float softShadow(vec3 ro, vec3 rd) {
    float res = 1.0, d = 0.02;
    for (int i = 0; i < 32; i++) {
        float h = map(ro + rd * d).x;
        res = min(res, 10.0 * h / d);
        d += clamp(h, 0.02, 0.3);
        if (res < 0.01 || d > 12.0) break;
    }
    return clamp(res, 0.0, 1.0);
}

float ao(vec3 p, vec3 n) {
    float o = 0.0, w = 1.0;
    for (int i = 1; i <= 5; i++) {
        float h = 0.06 * float(i);
        o += (h - map(p + n * h).x) * w;
        w *= 0.6;
    }
    return clamp(1.0 - 2.5 * o, 0.0, 1.0);
}

vec3 sky(vec3 rd) {
    vec3 c = mix(vec3(0.02, 0.025, 0.05), vec3(0.10, 0.22, 0.48), clamp(rd.y * 0.5 + 0.5, 0.0, 1.0));
    return c + vec3(2.5, 1.7, 0.9) * pow(max(dot(rd, normalize(vec3(0.6, 0.5, -0.4))), 0.0), 48.0);
}

vec3 shade(vec3 p, vec3 rd, float m, out vec3 nOut, out float refl) {
    vec3 n = normalAt(p);
    nOut = n;
    vec3 L = normalize(vec3(0.6, 0.8, -0.4));
    float dif = max(dot(n, L), 0.0) * softShadow(p + n * 0.01, L);
    float occ = ao(p, n);
    vec3 h = normalize(L - rd);
    vec3 base;
    float spec;
    if (m < 0.5) {
        float chk = mod(floor(p.x) + floor(p.z), 2.0);
        base = mix(vec3(0.12, 0.13, 0.16), vec3(0.55, 0.57, 0.62), chk);
        spec = 0.15; refl = 0.25;
    } else if (m < 1.5) {
        base = vec3(0.95, 0.72, 0.42);
        spec = 1.0; refl = 0.75;
    } else {
        refl = 0.0;
        return vec3(0.2, 1.6, 2.4) * (0.6 + 0.4 * sin(t * 3.0));   // emissive ring
    }
    vec3 col = base * (0.06 * occ + dif * vec3(2.2, 1.9, 1.5));
    col += spec * pow(max(dot(n, h), 0.0), 96.0) * dif;
    // the ring lights its surroundings
    col += vec3(0.1, 0.6, 0.9) * 0.35 / (1.0 + 2.0 * dot(p - vec3(0.0, 0.2, 0.0), p - vec3(0.0, 0.2, 0.0))) * occ;
    return col;
}

void main() {
    vec2 q = (uv * res - 0.5 * res) / res.y;
    vec3 fw = normalize(target - eye), rt = normalize(cross(fw, vec3(0.0, 1.0, 0.0))), up = cross(rt, fw);
    vec3 ro = eye, rd = normalize(fw * 1.6 + q.x * rt + q.y * up);
    vec3 col = vec3(0.0), att = vec3(1.0);
    for (int bounce = 0; bounce < 2; bounce++) {
        vec2 h = march(ro, rd, 40.0);
        if (h.x < 0.0) { col += att * sky(rd); break; }
        vec3 p = ro + rd * h.x, n;
        float refl;
        vec3 c = shade(p, rd, h.y, n, refl);
        float fog = 1.0 - exp(-0.0025 * h.x * h.x);
        col += att * mix(c, sky(rd), fog) * (1.0 - refl);
        if (refl <= 0.0) break;
        att *= refl * (h.y > 0.5 ? vec3(1.0, 0.72, 0.38) : vec3(0.9));
        ro = p + n * 0.01;
        rd = reflect(rd, n);
    }
    col = col / (1.0 + col);                       // tone map
    col = pow(col, vec3(1.0 / 2.2));               // gamma
    col *= 0.5 + 0.5 * pow(16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y), 0.15);   // vignette
    frag = vec4(col, 1.0);
}
)";

// --- a chime made in the audio callback: two decaying sines a fifth apart
static std::atomic<int> g_chime{0};
static void audioCallback(void*, void* buffer, uint32_t bytes) {
    static double phase = 0, env = 0;
    if (g_chime.exchange(0)) env = 1.0;
    float* out = (float*)buffer;
    uint32_t frames = bytes / (sizeof(float) * 2);
    for (uint32_t i = 0; i < frames; i++) {
        float s = (float)(env * (0.6 * std::sin(phase) + 0.4 * std::sin(phase * 1.5)) * 0.25);
        out[i * 2] = out[i * 2 + 1] = s;
        phase += 2.0 * M_PI * 660.0 / 48000.0;
        env *= 0.99985;
    }
}

static GLuint compile(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[1024];
        glGetShaderInfoLog(s, sizeof log, nullptr, log);
        nxn_log(NXN_LOG_ERROR, "prism: shader error: %s", log);
    }
    return s;
}

static int app(int, char**) {
    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    nxn_caps_get(&caps);
    nxn_log(NXN_LOG_INFO, "prism: native %u.%u abi %u features 0x%llx lang %s user %s os %s", caps.version_major,
            caps.version_minor, caps.abi_gen, (unsigned long long)caps.features, nxn_info_string(NXN_INFO_LANGUAGE),
            nxn_info_string(NXN_INFO_USER_NAME), nxn_info_string(NXN_INFO_OS_VERSION));

    nxn_display_params dp = NXN_STRUCT_INIT(nxn_display_params);
    dp.api = NXN_GFX_GLES;
    nxn_display* d = nullptr;
    if (nxn_display_open(&dp, &d) != 0) {
        nxn_request_return(NXN_RETURN_ERROR, 1, nxn_last_error());
        return 1;
    }
    uint32_t w = 1280, h = 720;
    nxn_display_size(d, &w, &h);
    nxn_log(NXN_LOG_INFO, "prism: %s %ux%u", (const char*)glGetString(GL_VERSION), w, h);

    GLuint prog = glCreateProgram();
    glAttachShader(prog, compile(GL_VERTEX_SHADER, kVert));
    glAttachShader(prog, compile(GL_FRAGMENT_SHADER, kFrag));
    glLinkProgram(prog);
    GLuint vao;
    glGenVertexArrays(1, &vao);
    GLint uRes = glGetUniformLocation(prog, "res"), uT = glGetUniformLocation(prog, "t"),
          uEye = glGetUniformLocation(prog, "eye"), uTarget = glGetUniformLocation(prog, "target");

    nxn_audio_params ap = NXN_STRUCT_INIT(nxn_audio_params);
    ap.format = NXN_AUDIO_F32;
    ap.callback = audioCallback;
    nxn_audio* audio = nullptr;
    if (nxn_audio_open(&ap, &audio) == 0) nxn_audio_pause(audio, 0);

    float yaw = 0.6f, dist = 6.5f, height = 1.6f;
    uint64_t start = nxn_time_ns(), last = start, fpsAt = start;
    int frames = 0;
    while (!nxn_should_quit()) {
        nxn_event e = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&e)) {
            if (e.type == NXN_EVENT_RESIZE && nxn_display_resize(d, e.width, e.height) == 0) {
                w = e.width;
                h = e.height;
                nxn_log(NXN_LOG_INFO, "prism: resized to %ux%u (%s)", w, h, e.docked ? "docked" : "handheld");
            }
            e = NXN_STRUCT_INIT(nxn_event);
        }
        nxn_input_state in = NXN_STRUCT_INIT(nxn_input_state);
        nxn_input_poll(&in);
        if (in.pressed & NXN_BTN_PLUS) {
            nxn_request_return(NXN_RETURN_USER, 0, nullptr);
            break;
        }
        if (in.actions_pressed & NXN_ACT_CONFIRM) g_chime = 1;

        uint64_t now = nxn_time_ns();
        float dt = (float)((now - last) * 1e-9);
        last = now;
        yaw += in.lx * dt * 1.6f + dt * 0.12f;
        dist = std::fmax(3.0f, std::fmin(12.0f, dist - in.ry * dt * 4.0f));
        height = std::fmax(0.2f, std::fmin(5.0f, height + in.rx * dt * 2.0f));
        float t = (float)((now - start) * 1e-9);

        glViewport(0, 0, (GLsizei)w, (GLsizei)h);
        glUseProgram(prog);
        glUniform2f(uRes, (float)w, (float)h);
        glUniform1f(uT, t);
        glUniform3f(uEye, std::cos(yaw) * dist, height, std::sin(yaw) * dist);
        glUniform3f(uTarget, 0.0f, 0.3f, 0.0f);
        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        nxn_display_swap(d);

        frames++;
        if (now - fpsAt > 2000000000ull) {
            nxn_log(NXN_LOG_INFO, "prism: %.1f fps at %ux%u", frames / ((now - fpsAt) * 1e-9), w, h);
            frames = 0;
            fpsAt = now;
        }
    }
    if (audio) nxn_audio_close(audio);
    glDeleteProgram(prog);
    nxn_display_close(d);
    return 0;
}

int main(int argc, char** argv) {
    nxn_init_params p = NXN_STRUCT_INIT(nxn_init_params);
    return nxn_run(argc, argv, app, &p);
}
