/* hello_gl - the smallest Nexvyn native app (Native SDK 1.0 draft). The same source builds for both modes: windowed
 * (`make windowed`, a .nxvmod in a Nexvyn OS window, the primary mode) and exclusive (`make`, its own .nro).
 *
 *   confirm (A by default)  play a 440 Hz tone
 *   X                       write hello.txt into the app's data folder
 *   Y                       crash a worker thread (the app ends, Nexvyn OS reports it)
 *   ZL + ZR                 crash the main thread (the app returns to Nexvyn OS, which reports it)
 *   +                       return to Nexvyn OS with code 42 (windowed: the window closes)
 *   dock / undock / resize  NXN_EVENT_RESIZE: the surface follows the new size (nxn_display_resize)
 *   close button            NXN_EVENT_QUIT (windowed): nxn_should_quit() turns true, the loop ends
 *
 * Self-test: when <data>/autotest exists, the app plays the tone, writes hello.txt and returns with code 7 after
 * about 3 seconds without any input (used by the emulator test). With "main" or "worker" in that file it crashes
 * that thread after 1.5 seconds instead (crash guard test); "abort-main" / "abort-worker" end it with abort(); "hang" spins forever. */
#include <nexvyn/nexvyn_native.h>
#include <glad/glad.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static const char* kVert =
    "#version 330 core\n"
    "layout(location = 0) in vec2 pos;\n"
    "layout(location = 1) in vec3 col;\n"
    "uniform float ang;\n"
    "uniform float aspect;\n"
    "out vec3 v;\n"
    "void main() {\n"
    "  float c = cos(ang), s = sin(ang);\n"
    "  gl_Position = vec4(c * pos.x - s * pos.y, (s * pos.x + c * pos.y) * aspect, 0.0, 1.0);\n"
    "  v = col;\n"
    "}\n";
static const char* kFrag =
    "#version 330 core\n"
    "in vec3 v;\n"
    "out vec4 o;\n"
    "void main() { o = vec4(v, 1.0); }\n";

static GLuint compile(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, NULL);
    glCompileShader(s);
    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[512];
        glGetShaderInfoLog(s, sizeof log, NULL, log);
        nxn_log(NXN_LOG_ERROR, "shader: %s", log);
    }
    return s;
}

static void play_tone(nxn_audio* a) {
    static int16_t buf[48000 / 4 * 2]; /* 0.25 s stereo */
    const int frames = 48000 / 4;
    for (int i = 0; i < frames; i++) {
        float env = i < 480 ? i / 480.f : (i > frames - 960 ? (frames - i) / 960.f : 1.f);
        int16_t v = (int16_t)(sinf(i * 2.f * 3.14159265f * 440.f / 48000.f) * 9000.f * env);
        buf[i * 2] = buf[i * 2 + 1] = v;
    }
    if (a && nxn_audio_queue(a, buf, sizeof buf) == NXN_OK) nxn_log(NXN_LOG_INFO, "tone queued");
}

static int write_hello(int count) {
    char text[256];
    int n = snprintf(text, sizeof text, "hello from %s (%s), language %s, count %d\n",
                     nxn_info_string(NXN_INFO_APP_ID), nxn_info_string(NXN_INFO_OS_VERSION),
                     nxn_info_string(NXN_INFO_LANGUAGE), count);
    nxn_result r = nxn_fs_write(NXN_DIR_DATA, "hello.txt", text, (size_t)n);
    nxn_log(r == NXN_OK ? NXN_LOG_INFO : NXN_LOG_ERROR, "hello.txt written: %d", (int)r);
    return r == NXN_OK;
}

/* an unmapped address behind a volatile pointer, so the compiler keeps the faulting store */
static volatile int* volatile g_bad = (volatile int*)8;
/* "abort-main" / "abort-worker" self-tests end that thread with abort() instead of a CPU fault: the same way out for
 * an app (an assert, std::terminate), and one an emulator can run (emulators stop the whole program on a real fault) */
static int g_use_abort;

static void crash_worker(void* arg) {
    (void)arg;
    nxn_log(NXN_LOG_WARN, "worker: crashing on purpose");
    if (g_use_abort) abort();
    *g_bad = 1;
}

static int app_main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    nxn_caps_get(&caps);
    nxn_info info = NXN_STRUCT_INIT(nxn_info);
    nxn_info_get(&info);
    nxn_log(NXN_LOG_INFO, "abi %u, native %u.%u, features 0x%llx, user '%s', theme %s", caps.abi_gen,
            caps.version_major, caps.version_minor, (unsigned long long)caps.features,
            nxn_info_string(NXN_INFO_USER_NAME), nxn_info_string(NXN_INFO_THEME));

    char probe[16] = {0};
    size_t got = 0;
    int autotest = nxn_fs_read(NXN_DIR_DATA, "autotest", probe, sizeof probe - 1, &got) == NXN_OK;
    /* "main" / "worker" in the file: the self-test ends in that crash instead of a normal return */
    g_use_abort = autotest && strncmp(probe, "abort-", 6) == 0;
    const char* what = g_use_abort ? probe + 6 : probe;
    int hang = autotest && strncmp(probe, "hang", 4) == 0; /* busy forever: the "not responding" / forced stop test */
    int crash_main = autotest && strncmp(what, "main", 4) == 0, crash_thread = autotest && strncmp(what, "worker", 6) == 0;

    nxn_display* d = NULL;
    if (nxn_display_open(NULL, &d) != NXN_OK) {
        nxn_request_return(NXN_RETURN_ERROR, 1, "OpenGL 4.3 is not available");
        return 1;
    }
    gladLoadGLLoader((GLADloadproc)nxn_display_proc);
    GLuint prog = glCreateProgram();
    glAttachShader(prog, compile(GL_VERTEX_SHADER, kVert));
    glAttachShader(prog, compile(GL_FRAGMENT_SHADER, kFrag));
    glLinkProgram(prog);
    static const float verts[] = {0.f, .5f, 1.f, .3f, .3f, -.45f, -.35f, .3f, 1.f, .3f, .45f, -.35f, .3f, .4f, 1.f};
    GLuint vao, vbo;
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof verts, verts, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)0);
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 5 * sizeof(float), (void*)(2 * sizeof(float)));
    glEnableVertexAttribArray(0);
    glEnableVertexAttribArray(1);
    GLint ang = glGetUniformLocation(prog, "ang"), aspect = glGetUniformLocation(prog, "aspect");
    uint32_t sw = 1280, sh = 720;
    nxn_display_size(d, &sw, &sh);
    glViewport(0, 0, (GLsizei)sw, (GLsizei)sh);

    nxn_audio* audio = NULL;
    if (nxn_audio_open(NULL, &audio) == NXN_OK) nxn_audio_pause(audio, 0);

    float r = ((info.accent_rgb >> 16) & 255) / 255.f, g = ((info.accent_rgb >> 8) & 255) / 255.f,
          b = (info.accent_rgb & 255) / 255.f;
    uint64_t start = nxn_time_ns();
    int count = 0;
    nxn_thread* worker = NULL;
    while (!nxn_should_quit()) {
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) { /* docked / handheld: follow the new output size */
            if (ev.type == NXN_EVENT_RESIZE && nxn_display_resize(d, ev.width, ev.height) == NXN_OK) {
                nxn_display_size(d, &sw, &sh);
                glViewport(0, 0, (GLsizei)sw, (GLsizei)sh);
                nxn_log(NXN_LOG_INFO, "resized to %ux%u (%s)", sw, sh, ev.docked ? "docked" : "handheld");
            }
            ev.size = sizeof ev;
        }
        nxn_input_state in = NXN_STRUCT_INIT(nxn_input_state);
        nxn_input_poll(&in);
        double t = (nxn_time_ns() - start) / 1e9;
        if (in.actions_pressed & NXN_ACT_CONFIRM) play_tone(audio);
        if (in.pressed & NXN_BTN_X) write_hello(++count);
        if (((in.pressed & NXN_BTN_Y) || (crash_thread && t > 1.5)) && !worker) {
            nxn_thread_params tp = NXN_STRUCT_INIT(nxn_thread_params);
            tp.fn = crash_worker;
            tp.name = "crash-test";
            tp.core = -2;
            nxn_thread_start(&tp, &worker);
        }
        if ((in.buttons & (NXN_BTN_ZL | NXN_BTN_ZR)) == (NXN_BTN_ZL | NXN_BTN_ZR) || (crash_main && t > 1.5)) {
            nxn_log(NXN_LOG_WARN, "main: crashing on purpose");
            if (g_use_abort) abort();
            *g_bad = 1;
        }
        if (in.pressed & NXN_BTN_PLUS) nxn_request_return(NXN_RETURN_USER, 42, NULL);
        if (hang && t > 1.5) {
            nxn_log(NXN_LOG_WARN, "main: hanging on purpose");
            for (volatile unsigned long n = 0;; n++) {
            }
        }
        if (autotest) {
            if (count == 0 && t > 0.5) {
                play_tone(audio);
                write_hello(++count);
            }
            if (t > 3.0) nxn_request_return(NXN_RETURN_NORMAL, 7, NULL);
        }
        glClearColor(r * .25f, g * .25f, b * .25f + .05f, 1.f);
        glClear(GL_COLOR_BUFFER_BIT);
        /* a white square in the top-left corner: shows the picture is the right way up (both modes) */
        glEnable(GL_SCISSOR_TEST);
        glScissor(8, (GLint)sh - 32, 24, 24);
        glClearColor(1.f, 1.f, 1.f, 1.f);
        glClear(GL_COLOR_BUFFER_BIT);
        glDisable(GL_SCISSOR_TEST);
        glUseProgram(prog);
        glUniform1f(ang, (float)t);
        glUniform1f(aspect, (float)sw / (float)sh);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        nxn_display_swap(d);
    }
    if (worker) nxn_thread_join(worker);
    nxn_audio_close(audio);
    glDeleteBuffers(1, &vbo);
    glDeleteVertexArrays(1, &vao);
    glDeleteProgram(prog);
    nxn_display_close(d);
    return 0;
}

int main(int argc, char** argv) { return nxn_run(argc, argv, app_main, NULL); }
