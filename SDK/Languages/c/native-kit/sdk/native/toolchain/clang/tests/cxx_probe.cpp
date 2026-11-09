// Nexvyn native SDK, clang spike: a windowed C++17 app that checks what a clang-built module must do:
// std::thread, thread_local (trivial and with a destructor), a C++ exception thrown and caught across frames,
// libstdc++ containers/strings, a GL clear + draw through the kit. The result goes to nxn_log ("clangprobe: ...") and to
// <data>/clang_probe.txt; the app returns with code 7 when every check passed, 8 otherwise.
#include <nexvyn/nexvyn_native.h>
#include <glad/glad.h>

#include <algorithm>
#include <atomic>
#include <cstdio>
#include <functional>
#include <map>
#include <memory>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

// -DPROBE_NO_TLS builds the probe without thread_local: clang 20 emits TLSDESC for aarch64 and the kit's loader refuses it
#ifdef PROBE_NO_TLS
#define PROBE_TL
#else
#define PROBE_TL thread_local
#endif
static PROBE_TL int tl_counter = 5;
struct TlObj {
    int v;
    TlObj() : v(11) {}
    ~TlObj() { g_dtor_ran.fetch_add(1); }
    static std::atomic<int> g_dtor_ran;
};
std::atomic<int> TlObj::g_dtor_ran{0};
static PROBE_TL TlObj tl_obj;

struct MyErr : std::runtime_error {
    explicit MyErr(const std::string& m) : std::runtime_error(m) {}
};

__attribute__((noinline)) static int thrower(int depth) {
    if (depth == 0) throw MyErr("boom from depth 0");
    std::string guard = "guard" + std::to_string(depth);  // a destructor to unwind through
    return thrower(depth - 1) + (int)guard.size();
}

static std::string g_report;
static int g_failed;

static void check(const char* name, bool ok) {
    nxn_log(ok ? NXN_LOG_INFO : NXN_LOG_ERROR, "clangprobe: %s %s", ok ? "ok  " : "FAIL", name);
    g_report += std::string(ok ? "ok   " : "FAIL ") + name + "\n";
    if (!ok) g_failed++;
}

static const char* kVert =
    "#version 330 core\n"
    "layout(location = 0) in vec2 pos;\n"
    "void main() { gl_Position = vec4(pos, 0.0, 1.0); }\n";
static const char* kFrag =
    "#version 330 core\n"
    "out vec4 o;\n"
    "void main() { o = vec4(1.0, 0.2, 0.2, 1.0); }\n";

static GLuint compile(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    return s;
}

static int app_main(int, char**) {
    // 1. exception across frames, with a destructor unwound on the way
    bool caught = false;
    std::string what;
    try {
        thrower(4);
    } catch (const MyErr& e) {
        caught = true;
        what = e.what();
    }
    check("exception thrown and caught across 5 frames", caught && what == "boom from depth 0");
    bool caught_base = false;
    try {
        throw std::out_of_range("range");
    } catch (const std::exception& e) {
        caught_base = std::string(e.what()) == "range";
    }
    check("std::out_of_range caught as std::exception", caught_base);
    bool caught_all = false;
    try {
        throw 42;
    } catch (...) {
        caught_all = true;
    }
    check("catch (...) of a thrown int", caught_all);
    bool dyn = false;
    try {
        std::unique_ptr<int[]> big(new int[4]);
        std::vector<int> v;
        (void)v.at(3);
    } catch (const std::out_of_range&) {
        dyn = true;
    }
    check("vector::at throws std::out_of_range from libstdc++", dyn);

    // 2. thread_local in the main thread and in a std::thread
    tl_counter += 1;
    check("thread_local int in main thread", tl_counter == 6 && tl_obj.v == 11);
    std::atomic<int> thread_ok{0};
    std::thread t([&] {
#ifdef PROBE_NO_TLS
        bool a = true;
#else
        bool a = tl_counter == 5;  // fresh copy in the new thread
#endif
        tl_counter = 99;
        bool b = tl_obj.v == 11;
        bool exc = false;
        try {
            thrower(2);
        } catch (const MyErr&) {
            exc = true;
        }
        thread_ok = (a && b && exc && tl_counter == 99) ? 1 : 2;
    });
    t.join();
    check("std::thread: own thread_local copy, exception inside the thread", thread_ok == 1);
#ifndef PROBE_NO_TLS
    check("thread_local int stayed 6 in main after the thread set 99", tl_counter == 6);
    check("thread_local destructor ran when the thread ended", TlObj::g_dtor_ran.load() >= 1);
#endif

    // 3. libstdc++ pieces: containers, string, algorithm, function
    std::map<std::string, int> m{{"b", 2}, {"a", 1}, {"c", 3}};
    std::vector<int> vec{5, 3, 9, 1};
    std::sort(vec.begin(), vec.end());
    std::function<int(int)> f = [&](int x) { return x + m["c"]; };
    check("map/vector/sort/std::function", m.size() == 3 && vec[0] == 1 && vec[3] == 9 && f(1) == 4);

    // 4. GL through the kit
    nxn_display* d = nullptr;
    bool gl_ok = false;
    if (nxn_display_open(nullptr, &d) == NXN_OK) {
        gladLoadGLLoader((GLADloadproc)nxn_display_proc);
        uint32_t sw = 640, sh = 400;
        nxn_display_size(d, &sw, &sh);
        glViewport(0, 0, (GLsizei)sw, (GLsizei)sh);
        GLuint prog = glCreateProgram();
        glAttachShader(prog, compile(GL_VERTEX_SHADER, kVert));
        glAttachShader(prog, compile(GL_FRAGMENT_SHADER, kFrag));
        glLinkProgram(prog);
        GLint linked = 0;
        glGetProgramiv(prog, GL_LINK_STATUS, &linked);
        static const float verts[] = {0.f, .6f, -.6f, -.5f, .6f, -.5f};
        GLuint vao, vbo;
        glGenVertexArrays(1, &vao);
        glGenBuffers(1, &vbo);
        glBindVertexArray(vao);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, sizeof verts, verts, GL_STATIC_DRAW);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 8, (void*)0);
        glEnableVertexAttribArray(0);
        glClearColor(0.f, 0.3f, 0.1f, 1.f);
        glClear(GL_COLOR_BUFFER_BIT);
        glUseProgram(prog);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        uint8_t px[4] = {0, 0, 0, 0}, corner[4] = {0, 0, 0, 0};
        glReadPixels((GLint)sw / 2, (GLint)sh / 2, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, px);
        glReadPixels(2, 2, 1, 1, GL_RGBA, GL_UNSIGNED_BYTE, corner);
        nxn_log(NXN_LOG_INFO, "clangprobe: gl link=%d center=%u,%u,%u corner=%u,%u,%u", (int)linked, px[0], px[1], px[2],
                corner[0], corner[1], corner[2]);
        gl_ok = linked && px[0] > 200 && px[1] < 100 && corner[1] > 50 && corner[0] < 20;
        nxn_display_swap(d);
        // keep drawing for ~6 s so a screenshot can be taken; the triangle turns green when the checks so far passed
        uint64_t t0 = nxn_time_ns();
        while (!nxn_should_quit() && nxn_time_ns() - t0 < 6000000000ull) {
            glClearColor(g_failed ? 0.4f : 0.f, g_failed ? 0.f : 0.3f, 0.1f, 1.f);
            glClear(GL_COLOR_BUFFER_BIT);
            glDrawArrays(GL_TRIANGLES, 0, 3);
            nxn_display_swap(d);
        }
        glDeleteBuffers(1, &vbo);
        glDeleteVertexArrays(1, &vao);
        glDeleteProgram(prog);
        nxn_display_close(d);
    }
    check("GL: shader link, clear and triangle draw read back", gl_ok);

    char line[96];
    int n = std::snprintf(line, sizeof line, "failed=%d\n", g_failed);
    g_report.append(line, (size_t)n);
    nxn_fs_write(NXN_DIR_DATA, "clang_probe.txt", g_report.data(), g_report.size());
    nxn_log(NXN_LOG_INFO, "clangprobe: done, %d failed", g_failed);
    nxn_request_return(NXN_RETURN_NORMAL, g_failed ? 8 : 7, nullptr);
    while (!nxn_should_quit()) std::this_thread::sleep_for(std::chrono::milliseconds(20));
    return g_failed ? 8 : 7;
}

int main(int argc, char** argv) { return nxn_run(argc, argv, app_main, nullptr); }
