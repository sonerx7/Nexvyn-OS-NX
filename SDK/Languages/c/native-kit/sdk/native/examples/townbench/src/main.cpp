/* Nexvyn Village Bench: a fixed 60 s camera flight over one baked village (data/town.nxsc + town.nxtx, drawn by NexGFX),
 * three quality presets, no sound, no frame cap (NXN_DISPLAY_NO_VSYNC). Result: average / minimum / 1% low frame times,
 * fps and a score; the last result is also written to townbench_result.json and the log ("RESULT ...").
 * Based on sdk/native/examples/graphics (scene, camera path, display setup); see README.md.
 * Test hook: <data>/autorun, words "preset=0|1|2 secs=N hold=N": starts that run at once, writes the result and quits. */
#include <glad/glad.h>
#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <string>
#include <vector>
#include <algorithm>

#include "imgui.h"
#include "imgui_impl_opengl3.h"
#include <nexvyn/nexvyn_native.h>
#include <nexvyn/nexgfx_native.h>
#include <nexvyn/nxn_imgui.h>
#include "nexgfx_math.h"

static nxn_display* g_disp;
static nxn_caps g_caps = NXN_STRUCT_INIT(nxn_caps);
static uint32_t g_w = 1280, g_h = 720;
static nxn_input_state g_in = NXN_STRUCT_INIT(nxn_input_state);
static ngfx_device* g_dev;
static ngfx_frame_stats g_st = {sizeof(ngfx_frame_stats)};
static ngfx_scene g_scene = 0; static ngfx_scene_status g_ss; static bool g_geom = false, g_done = false, g_ready = false;
static uint32_t g_prepDone, g_prepTotal = 5;
static const char* T(const char* k) { return nxn_tr(k); }
static void logf_(const char* fmt, ...) __attribute__((format(printf, 1, 2)));
static void logf_(const char* fmt, ...) { char b[400]; va_list ap; va_start(ap, fmt); vsnprintf(b, sizeof b, fmt, ap); va_end(ap); nxn_log(NXN_LOG_INFO, "%s", b); }

/* ---- fixed camera path: a closed 8-key flight, 7.5 s per key = 60 s; the camera depends on wall time only */
struct Key { V3 pos, tgt; };
static const Key kKeys[] = {
    {{0.0f, 11, -20.0f}, {0, 3, 10}},   {{18.4f, 6, -8.4f}, {0, 3, 10}},   {{24.0f, 8, 10.0f}, {0, 3, 10}},  {{18.4f, 5, 28.4f}, {0, 3, 10}},
    {{0.0f, 12, 40.0f}, {0, 3, 10}},    {{-18.4f, 6, 28.4f}, {0, 3, 10}},  {{-24.0f, 7, 10.0f}, {0, 3, 10}}, {{-18.4f, 9, -8.4f}, {0, 3, 10}},
};
static const int kNumKeys = 8;
static const float kKeySecs = 7.5f, kRunSecs = 60.f, kWarm = 1.f;
static V3 crom(const V3& p0, const V3& p1, const V3& p2, const V3& p3, float u) {
    float u2 = u * u, u3 = u2 * u;
    return (p1 * 2.f + (p2 - p0) * u + (p0 * 2.f - p1 * 5.f + p2 * 4.f - p3) * u2 + (p1 * 3.f - p0 - p2 * 3.f + p3) * u3) * 0.5f;
}
struct Cam { V3 pos{0, 11, -20}; float yaw = 0, pitch = -0.2f, fovDeg = 60.f; } g_cam;
static void cam_path(float t, float fov) {
    float total = kKeySecs * kNumKeys; t = fmodf(t, total); if (t < 0) t += total;
    int i = (int)(t / kKeySecs); if (i >= kNumKeys) i = kNumKeys - 1; float u = t / kKeySecs - (float)i; u = u * u * (3.f - 2.f * u) * 0.35f + u * 0.65f;
    auto K = [&](int j) -> const Key& { return kKeys[((j % kNumKeys) + kNumKeys) % kNumKeys]; };
    V3 p = crom(K(i - 1).pos, K(i).pos, K(i + 1).pos, K(i + 2).pos, u), tg = crom(K(i - 1).tgt, K(i).tgt, K(i + 1).tgt, K(i + 2).tgt, u);
    V3 d = tg - p; float h = sqrtf(d.x * d.x + d.z * d.z);
    g_cam.pos = p; g_cam.yaw = atan2f(d.x, -d.z); g_cam.pitch = atan2f(d.y, std::max(h, 0.001f)); g_cam.fovDeg = fov;
}

/* ---- presets: render scale, sun shadows, FXAA; the weight makes scores of different presets comparable */
struct Preset { const char* key; float scale; bool shadows, fxaa; double weight; };
static const Preset kPre[3] = {{"p0", 0.60f, false, false, 1.0}, {"p1", 0.80f, true, true, 1.6}, {"p2", 1.00f, true, true, 2.4}};

enum Mode { M_MENU, M_RUN, M_RESULT };
static Mode g_mode = M_MENU; static int g_pre = 1, g_runPre = 1; static float g_rt = 0, g_mt = 0, g_runSecs = kRunSecs;
static std::vector<float> g_ms; static double g_fpsNow = 0; static int g_best[3] = {0, 0, 0};
struct Res { double avg_ms = 0, avg_fps = 0, min_fps = 0, low1_fps = 0, max_ms = 0, score = 0; int frames = 0; } g_res;
static bool g_auto = false; static float g_quitT = 0, g_hold = 5.f;  /* autorun: seconds the result stays before the app quits */

static void best_io(bool save) {
    if (save) { char b[96]; snprintf(b, sizeof b, "%d %d %d\n", g_best[0], g_best[1], g_best[2]); nxn_fs_write(NXN_DIR_DATA, "best.txt", b, strlen(b)); return; }
    char b[96]; size_t got = 0; if (nxn_fs_read(NXN_DIR_DATA, "best.txt", b, sizeof b - 1, &got) == NXN_OK) { b[got] = 0; sscanf(b, "%d %d %d", &g_best[0], &g_best[1], &g_best[2]); }
}
static void run_start(int pre) { g_runPre = pre; g_mode = M_RUN; g_rt = 0; g_ms.clear(); logf_("benchmark start: preset %d, %.0f s", pre, g_runSecs); }
static void run_finish() {
    g_res = Res(); g_res.frames = (int)g_ms.size(); double sum = 0; for (float m : g_ms) { sum += m; g_res.max_ms = std::max<double>(g_res.max_ms, m); }
    if (g_res.frames) {
        g_res.avg_ms = sum / g_res.frames; g_res.avg_fps = 1000.0 / g_res.avg_ms; g_res.min_fps = 1000.0 / std::max(g_res.max_ms, 0.1);
        std::vector<float> c = g_ms; std::sort(c.begin(), c.end()); size_t n = std::max<size_t>(1, c.size() / 100); double s = 0;
        for (size_t i = c.size() - n; i < c.size(); i++) s += c[i];
        g_res.low1_fps = 1000.0 / std::max(s / (double)n, 0.1);   /* 1% low: fps of the slowest 1% of frames, averaged */
        g_res.score = (0.7 * g_res.avg_fps + 0.3 * g_res.low1_fps) * 10.0 * kPre[g_runPre].weight;
    }
    int sc = (int)(g_res.score + 0.5); if (sc > g_best[g_runPre]) { g_best[g_runPre] = sc; best_io(true); }
    char j[420]; snprintf(j, sizeof j, "{\"preset\":%d,\"secs\":%.0f,\"frames\":%d,\"avg_ms\":%.3f,\"avg_fps\":%.2f,\"min_fps\":%.2f,\"low1_fps\":%.2f,\"max_ms\":%.2f,\"score\":%d,\"complete\":true}\n",
                          g_runPre, g_runSecs, g_res.frames, g_res.avg_ms, g_res.avg_fps, g_res.min_fps, g_res.low1_fps, g_res.max_ms, sc);
    nxn_fs_write(NXN_DIR_DATA, "townbench_result.json", j, strlen(j));
    logf_("RESULT preset=%d frames=%d avg_ms=%.2f avg_fps=%.1f min_fps=%.1f low1_fps=%.1f score=%d", g_runPre, g_res.frames, g_res.avg_ms, g_res.avg_fps, g_res.min_fps, g_res.low1_fps, sc);
    g_mode = M_RESULT; g_mt = 0;
}

/* ---- drawing */
static ImFont *fBody, *fTitle, *fBig;
static float U() { return (float)g_h / 720.f; }
static ImU32 C(int r, int g, int b, float a = 1.f) { return IM_COL32(r, g, b, (int)(std::max(0.f, std::min(1.f, a)) * 255.f)); }
#define ACC 70, 205, 255
#define GOLD 255, 200, 90
static float sat(float x) { return std::max(0.f, std::min(1.f, x)); }
static float eout(float x) { x = 1.f - sat(x); return 1.f - x * x * x; }
static void txt(ImFont* f, float sz, float x, float y, ImU32 c, const char* s, float ax = 0.f) {
    ImDrawList* dl = ImGui::GetForegroundDrawList(); sz *= U(); x -= f->CalcTextSizeA(sz, FLT_MAX, 0.f, s).x * ax;
    dl->AddText(f, sz, ImVec2(x + 1.5f, y + 1.5f), IM_COL32(0, 0, 0, (int)(((c >> 24) & 255) * 0.7f)), s); dl->AddText(f, sz, ImVec2(x, y), c, s);
}
static void glass(float x0, float y0, float x1, float y1, float a) {
    ImDrawList* dl = ImGui::GetForegroundDrawList(); float r = 14.f * U();
    dl->AddRectFilled(ImVec2(x0, y0), ImVec2(x1, y1), C(6, 10, 18, 0.82f * a), r); dl->AddRect(ImVec2(x0, y0), ImVec2(x1, y1), C(ACC, 0.35f * a), r, 0, 1.2f);
}
static void draw_menu(float t) {
    float cx = (float)g_w * 0.5f, a = eout(t / 0.6f), pw = 620.f * U(), py = (float)g_h * 0.12f, ph = 450.f * U(); char b[160];
    glass(cx - pw * 0.5f, py, cx + pw * 0.5f, py + ph, a);
    txt(fBody, 14, cx, py + 16 * U(), C(ACC, a), "N E X V Y N", 0.5f);
    txt(fTitle, 36, cx, py + 36 * U(), C(255, 255, 255, a), T("m.title"), 0.5f);
    txt(fBody, 15, cx, py + 90 * U(), C(255, 255, 255, 0.75f * a), T("m.sub"), 0.5f);
    txt(fBody, 12, cx - pw * 0.5f + 40 * U(), py + 136 * U(), C(ACC, a), T("m.preset"));
    for (int i = 0; i < 3; i++) {
        float y = py + 160 * U() + i * 64 * U(); bool sel = i == g_pre; float x0 = cx - pw * 0.5f + 30 * U(), x1 = cx + pw * 0.5f - 30 * U();
        if (sel) ImGui::GetForegroundDrawList()->AddRectFilled(ImVec2(x0, y), ImVec2(x1, y + 56 * U()), C(ACC, 0.18f * a), 10 * U());
        snprintf(b, sizeof b, "%s.n", kPre[i].key); txt(fTitle, 24, x0 + 16 * U(), y + 4 * U(), sel ? C(255, 255, 255, a) : C(255, 255, 255, 0.7f * a), T(b));
        snprintf(b, sizeof b, "%s.d", kPre[i].key); txt(fBody, 13, x0 + 16 * U(), y + 34 * U(), C(255, 255, 255, 0.65f * a), T(b));
        if (g_best[i]) { snprintf(b, sizeof b, "%s %d", T("m.best"), g_best[i]); txt(fBody, 14, x1 - 14 * U(), y + 18 * U(), C(GOLD, a), b, 1.f); }
    }
    txt(fTitle, 22, cx, py + ph - 70 * U(), C(ACC, a * (0.75f + 0.25f * sinf(t * 4.f))), T("m.start"), 0.5f);
    txt(fBody, 12, cx, py + ph - 34 * U(), C(255, 255, 255, 0.55f * a), T("m.hint"), 0.5f);
}
static void draw_run() {
    float cx = (float)g_w * 0.5f, pw = 440.f * U(), y = (float)g_h * 0.04f; char b[96];
    glass(cx - pw * 0.5f, y, cx + pw * 0.5f, y + 58 * U(), 0.9f);
    snprintf(b, sizeof b, "%s   %.0f fps", T("run.title"), g_fpsNow); txt(fBody, 18, cx, y + 8 * U(), C(255, 255, 255), b, 0.5f);
    ImDrawList* dl = ImGui::GetForegroundDrawList(); float p = sat(g_rt / g_runSecs), x0 = cx - pw * 0.5f + 20 * U(), x1 = cx + pw * 0.5f - 20 * U();
    dl->AddRectFilled(ImVec2(x0, y + 40 * U()), ImVec2(x1, y + 46 * U()), C(255, 255, 255, 0.15f), 3.f); dl->AddRectFilled(ImVec2(x0, y + 40 * U()), ImVec2(x0 + (x1 - x0) * p, y + 46 * U()), C(ACC), 3.f);
    txt(fBody, 12, cx, (float)g_h - 30 * U(), C(255, 255, 255, 0.5f), T("run.abort"), 0.5f);
}
static void row(float px, float pw, float y, float t, int i, const char* key, const char* val) {
    float a = eout((t - 0.2f - 0.12f * i) / 0.6f); txt(fBody, 16, px + 40 * U(), y, C(255, 255, 255, 0.8f * a), T(key)); txt(fTitle, 22, px + pw - 40 * U(), y - 3 * U(), C(255, 255, 255, a), val, 1.f);
}
static void draw_result(float t) {
    float cx = (float)g_w * 0.5f, pw = 620.f * U(), py = (float)g_h * 0.1f, ph = 500.f * U(), px = cx - pw * 0.5f; char b[96];
    glass(px, py, px + pw, py + ph, eout(t / 0.5f));
    txt(fBody, 14, cx, py + 14 * U(), C(ACC), T("r.title"), 0.5f);
    snprintf(b, sizeof b, "%s.n", kPre[g_runPre].key); txt(fBody, 15, cx, py + 34 * U(), C(255, 255, 255, 0.8f), T(b), 0.5f);
    snprintf(b, sizeof b, "%.0f", g_res.score * eout(t / 1.8f)); txt(fBig, 72, cx, py + 56 * U(), C(GOLD), b, 0.5f);
    txt(fBody, 13, cx, py + 138 * U(), C(255, 255, 255, 0.7f), T("r.score"), 0.5f);
    float y = py + 176 * U(), dy = 40 * U();
    snprintf(b, sizeof b, "%.1f fps   %.2f ms", g_res.avg_fps, g_res.avg_ms); row(px, pw, y, t, 0, "r.avg", b);
    snprintf(b, sizeof b, "%.1f fps   %.2f ms", g_res.min_fps, g_res.max_ms); row(px, pw, y + dy, t, 1, "r.min", b);
    snprintf(b, sizeof b, "%.1f fps   %.2f ms", g_res.low1_fps, 1000.0 / std::max(g_res.low1_fps, 0.1)); row(px, pw, y + 2 * dy, t, 2, "r.low", b);
    snprintf(b, sizeof b, "%d", g_res.frames); row(px, pw, y + 3 * dy, t, 3, "r.frames", b);
    txt(fBody, 13, cx, py + ph - 40 * U(), C(255, 255, 255, 0.7f), T("r.keys"), 0.5f);
}
static int app_main(int, char**) {
    nxn_caps_get(&g_caps);
    int autoPre = -1; { char ab[200]; size_t got = 0; if (nxn_fs_read(NXN_DIR_DATA, "autorun", ab, sizeof ab - 1, &got) == NXN_OK) { ab[got] = 0; int v; float s;
        for (char* w = strtok(ab, " \r\n"); w; w = strtok(NULL, " \r\n")) { if (sscanf(w, "preset=%d", &v) == 1 && v >= 0 && v < 3) autoPre = v; else if (sscanf(w, "secs=%f", &s) == 1 && s >= 3.f && s <= 120.f) g_runSecs = s; else if (sscanf(w, "hold=%f", &s) == 1 && s >= 1.f && s <= 60.f) g_hold = s; } } }
    nxn_display_params dp = NXN_STRUCT_INIT(nxn_display_params); dp.flags = NXN_DISPLAY_NO_VSYNC;  /* no frame cap */
    if (nxn_display_open(&dp, &g_disp) != NXN_OK) { nxn_request_return(NXN_RETURN_ERROR, 1, "OpenGL 4.3 is not available"); return 1; }
    gladLoadGLLoader((GLADloadproc)nxn_display_proc);
    nxn_display_size(g_disp, &g_w, &g_h); if (!g_w || !g_h) { g_w = 1280; g_h = 720; }
    if (ngfx_device_create(NULL, &g_dev) != NGFX_OK) { nxn_request_return(NXN_RETURN_ERROR, 1, ngfx_native_error()); return 1; }
    logf_("village bench: gl %s | %s | surface %ux%u | no vsync", (const char*)glGetString(GL_VERSION), (const char*)glGetString(GL_RENDERER), g_w, g_h);
    best_io(false);

    IMGUI_CHECKVERSION(); ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); io.IniFilename = nullptr; io.LogFilename = nullptr;
    ImFontConfig fc; fc.SizePixels = 20.f;
    if (g_caps.features & NXN_CAP_UI_TOKENS) {
        fBody = nxn_imgui_add_font(io.Fonts, NXN_UI_FONT_SANS, 20.f, 0, NULL);
        fTitle = nxn_imgui_add_font(io.Fonts, NXN_UI_FONT_SANS, 40.f, NXN_IMGUI_CJK_LARGE, NULL);
        fBig = nxn_imgui_add_font(io.Fonts, NXN_UI_FONT_SANS, 72.f, NXN_IMGUI_NO_CJK, NULL);
    }
    if (!fBody) fBody = io.Fonts->AddFontDefault(&fc);
    if (!fTitle) { ImFontConfig f2; f2.SizePixels = 40.f; fTitle = io.Fonts->AddFontDefault(&f2); }
    if (!fBig) { ImFontConfig f3; f3.SizePixels = 72.f; fBig = io.Fonts->AddFontDefault(&f3); }
    ImGui_ImplOpenGL3_Init("#version 330 core");

    uint64_t last = nxn_time_ns(), lastFps = last; int fpsFrames = 0; bool autoDone = false, touchWas = false; static const ImGuiKey kPadKeys[4] = {ImGuiKey_GamepadDpadLeft, ImGuiKey_GamepadDpadRight, ImGuiKey_GamepadDpadUp, ImGuiKey_GamepadDpadDown};
    while (!nxn_should_quit()) {
        uint64_t now = nxn_time_ns(); float dt = (float)(now - last) / 1e9f; last = now; double frameMs = dt * 1000.0; fpsFrames++;
        if (now - lastFps >= 400000000ull) { g_fpsNow = fpsFrames * 1e9 / (double)(now - lastFps); fpsFrames = 0; lastFps = now; }
        if (dt > 0.25f) dt = 0.25f;
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) { if (ev.type == NXN_EVENT_RESIZE && ev.width && ev.height) { nxn_display_resize(g_disp, ev.width, ev.height); nxn_display_size(g_disp, &g_w, &g_h); } ev.size = sizeof ev; }
        nxn_input_poll(&g_in); uint64_t pr = g_in.pressed;
        if (g_in.touch_count > 0) { if (!touchWas) pr |= NXN_BTN_A; touchWas = true; } else touchWas = false;

        if (!g_ready) { int p = ngfx_device_prepare(g_dev, &g_prepDone, &g_prepTotal); if (p < 0) { nxn_request_return(NXN_RETURN_ERROR, 1, ngfx_native_error()); break; } g_ready = p == 1; }
        if (!g_scene && !g_ss.failed && !g_done) {
            char sc[512], tx[512]; nxn_fs_path(NXN_DIR_BUNDLE, "data/town.nxsc", sc, sizeof sc); nxn_fs_path(NXN_DIR_BUNDLE, "data/town.nxtx", tx, sizeof tx);
            g_ss.size = sizeof g_ss; ngfx_scene_desc d = {sizeof d, sc, tx, 0u};
            if (ngfx_scene_load(g_dev, &d, &g_scene) != NGFX_OK) { g_ss.failed = 1; snprintf(g_ss.error, sizeof g_ss.error, "%s", ngfx_native_error()); }
        }
        if (g_scene && !g_done && !g_ss.failed && g_ready) {
            ngfx_scene_step(g_dev, g_scene, 24000000ull, &g_ss);
            if (g_ss.geometry_ready) g_geom = true;
            if (g_ss.ready) { g_done = true; logf_("village ready"); }
        }
        bool playing = g_ready && g_done; float fov = 60.f;
        if (playing) {
            g_mt += dt;
            if (autoPre >= 0 && !autoDone && g_mode == M_MENU && g_mt > 1.f) { autoDone = true; g_auto = true; g_pre = autoPre; run_start(autoPre); }
            if (g_mode == M_MENU) {
                cam_path(g_mt * 0.5f, 56.f);
                if (pr & NXN_BTN_DOWN) g_pre = (g_pre + 1) % 3; if (pr & NXN_BTN_UP) g_pre = (g_pre + 2) % 3;
                if (pr & (NXN_BTN_A | NXN_BTN_PLUS)) run_start(g_pre);
                else if (pr & NXN_BTN_B) nxn_request_return(NXN_RETURN_NORMAL, 0, NULL);
            } else if (g_mode == M_RUN) {
                g_rt += dt; cam_path(g_rt * (kKeySecs * kNumKeys / kRunSecs), fov);
                if (g_rt > kWarm) g_ms.push_back((float)frameMs);
                if (pr & NXN_BTN_B) { g_mode = M_MENU; g_mt = 0; logf_("benchmark aborted"); }
                else if (g_rt >= g_runSecs) run_finish();
            } else {
                cam_path(g_mt * 0.5f, 56.f);
                if (g_auto) { g_quitT += dt; if (g_quitT > g_hold) nxn_request_return(NXN_RETURN_NORMAL, 7, NULL); }
                if (pr & (NXN_BTN_A | NXN_BTN_Y)) run_start(g_runPre); else if (pr & NXN_BTN_B) { g_mode = M_MENU; g_mt = 0; }
            }
        }
        io.DisplaySize = ImVec2((float)g_w, (float)g_h); io.DeltaTime = dt > 0.0001f ? dt : 0.0001f;
        for (int i = 0; i < 4; i++) { static const uint64_t bits[4] = {NXN_BTN_LEFT, NXN_BTN_RIGHT, NXN_BTN_UP, NXN_BTN_DOWN}; io.AddKeyEvent(kPadKeys[i], (g_in.buttons & bits[i]) != 0); }
        ImGui_ImplOpenGL3_NewFrame(); ImGui::NewFrame();
        if (!playing) {
            float frac = !g_ready ? (float)g_prepDone / (float)std::max(g_prepTotal, 1u) : g_ss.progress; char msg[200];
            if (g_ss.failed) snprintf(msg, sizeof msg, "%s: %s", T("ui.fail"), g_ss.error); else snprintf(msg, sizeof msg, "%s", T(g_ready ? "ui.loading" : "ui.shaders"));
            float w = std::min(520.f, (float)g_w - 40.f), x = ((float)g_w - w) * 0.5f, y = (float)g_h * 0.5f; ImDrawList* dl = ImGui::GetForegroundDrawList();
            txt(fBody, 18, (float)g_w * 0.5f, y - 34 * U(), C(255, 255, 255, 0.9f), msg, 0.5f);
            dl->AddRectFilled(ImVec2(x, y), ImVec2(x + w, y + 8), C(255, 255, 255, 0.15f), 4.f); dl->AddRectFilled(ImVec2(x, y), ImVec2(x + w * frac, y + 8), C(ACC), 4.f);
        } else if (g_mode == M_MENU) draw_menu(g_mt); else if (g_mode == M_RUN) draw_run(); else draw_result(g_mt);
        ImGui::Render();
        if (g_ready) {
            const Preset& P = kPre[g_mode == M_RUN ? g_runPre : g_mode == M_MENU ? g_pre : g_runPre];
            ngfx_view view = {sizeof view, {g_cam.pos.x, g_cam.pos.y, g_cam.pos.z}, g_cam.yaw, g_cam.pitch, g_cam.fovDeg, g_w, g_h, P.scale, (P.shadows ? NGFX_VIEW_SHADOWS : 0u) | (P.fxaa ? NGFX_VIEW_FXAA : 0u), 1.0f, 0};
            ngfx_render(g_dev, g_geom && g_done ? g_scene : 0, &view, &g_st);
        } else { glBindFramebuffer(GL_FRAMEBUFFER, 0); glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h); glClearColor(0.02f, 0.03f, 0.05f, 1); glClear(GL_COLOR_BUFFER_BIT); }
        glBindFramebuffer(GL_FRAMEBUFFER, 0); glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h); glDisable(GL_DEPTH_TEST);
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
        nxn_display_swap(g_disp);
    }
    if (g_scene) ngfx_scene_free(g_dev, g_scene);
    ngfx_device_destroy(g_dev); ImGui_ImplOpenGL3_Shutdown(); ImGui::DestroyContext(); nxn_display_close(g_disp);
    return 0;
}
int main(int argc, char** argv) { return nxn_run(argc, argv, app_main, NULL); }
