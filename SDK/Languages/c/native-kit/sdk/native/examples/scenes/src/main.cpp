/* Native SDK Scenes: a windowed scene viewer for baked FBX scenes (see README.md).
 *
 * Two baked scenes ship in the package (data/ folder: .nxsc + .nxtx, made by tools/nxv_asset). NexGFX (nexgfx_native.h, ngfx_*) streams a scene
 * (a worker thread reads, ngfx_scene_step uploads a little per frame, no stall) and draws it: metallic-roughness PBR,
 * one sun with a fitted PCF shadow map, hemisphere ambient, ACES tone mapping, optional FXAA, alpha-tested cutouts,
 * per-chunk frustum culling and material-sorted draws. L / R switch the scene, + opens the quality menu.
 * Self-test: when <data>/autotest exists the app loads the scenes in turn, measures, writes scenes_report.txt and shot_*.bmp
 * and returns code 7. Benchmark: when <data>/bench exists (its text: "<scene> <seconds>", default "0 60") the app loads
 * that scene, keeps the camera at the start point for that long, writes the numbers every 10 s and returns code 7. */
#include <glad/glad.h>
#include <malloc.h>
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
#include "nexgfx_math.h"  /* V3 / M4 helpers, shared with the library */

/* ------------------------------------------------------------------ catalogue */
struct SceneDef { const char* file; const char* title; };
static const SceneDef kScenes[] = {{"level1", "Level 1"}, {"library", "Library"}};
static const int kNumScenes = 2;

/* ------------------------------------------------------------------ globals */
static nxn_display* g_disp;
static uint32_t g_w = 1280, g_h = 720;
static nxn_input_state g_in = NXN_STRUCT_INIT(nxn_input_state);
static char g_glinfo[3][160];

static bool g_drawWhileLoading = false;  /* true: the half loaded scene is drawn while it streams (old behaviour, slower to load) */
static bool g_shadows = true, g_fxaa = true, g_overlay = true, g_menu = false;
static const float kScales[] = {0.5f, 0.67f, 0.75f, 1.0f};
static int g_scaleIdx = 3;

static void logf_(const char* fmt, ...) __attribute__((format(printf, 1, 2)));
static std::string g_report;
static void logf_(const char* fmt, ...) {
    char b[512]; va_list ap; va_start(ap, fmt); vsnprintf(b, sizeof b, fmt, ap); va_end(ap);
    nxn_log(NXN_LOG_INFO, "%s", b);
    g_report += b; g_report += "\n";
}
static void report_write() { nxn_fs_write(NXN_DIR_DATA, "scenes_report.txt", g_report.data(), g_report.size()); }
/* every 10 s: the report so far plus a live line, so a run that is killed (or never ends) still leaves numbers */
static void report_live(const char* live) {
    std::string r = g_report; r += live; r += '\n';
    nxn_fs_write(NXN_DIR_DATA, "scenes_report.txt", r.data(), r.size());
}

static size_t heap_bytes() { struct mallinfo mi = mallinfo(); return (size_t)mi.uordblks + (size_t)mi.hblkhd; }
static int g_glErr; static GLenum g_lastErr;
/* NexGFX device (one per GL context) and the scene the viewer shows */
static ngfx_device* g_dev;
static ngfx_frame_stats g_st = {sizeof(ngfx_frame_stats)};
static bool g_ready;               /* every NexGFX program is built */
static uint32_t g_prepDone, g_prepTotal = 5;
struct SceneState {
    ngfx_scene h = 0; int index = -1;
    ngfx_scene_status st; ngfx_scene_info info; bool geom = false, done = false;
    uint64_t tStart = 0, tGeom = 0, tDone = 0; size_t memBefore = 0, memAfter = 0; double maxFrameMs = 0;
} S;
static uint64_t gpu_bytes() { ngfx_device_caps c = {sizeof c}; ngfx_device_caps_get(g_dev, &c); return c.gpu_bytes; }
static void scene_unload() { if (S.h) ngfx_scene_free(g_dev, S.h); S = SceneState(); }
static void scene_load(int index) {
    scene_unload();
    S.index = index; S.memBefore = heap_bytes(); S.tStart = nxn_time_ns(); S.st.size = sizeof S.st; S.info.size = sizeof S.info;
    char rel[64], sc[512], tx[512];
    snprintf(rel, sizeof rel, "data/%s.nxsc", kScenes[index].file); nxn_fs_path(NXN_DIR_BUNDLE, rel, sc, sizeof sc);
    snprintf(rel, sizeof rel, "data/%s.nxtx", kScenes[index].file); nxn_fs_path(NXN_DIR_BUNDLE, rel, tx, sizeof tx);
    ngfx_scene_desc d = {sizeof d, sc, tx, g_drawWhileLoading ? 1u : 0u};  /* (flag 1: the libc's small read buffer, only with the oldload file) */
    if (ngfx_scene_load(g_dev, &d, &S.h) != NGFX_OK) { S.st.failed = 1; snprintf(S.st.error, sizeof S.st.error, "%s", ngfx_native_error()); }
}
/* one ngfx_scene_step per frame: uploads a little, then keeps the timings the self-test reports */
static void scene_step(uint64_t budgetNs) {
    if (!S.h || S.done || S.st.failed) return;
    ngfx_scene_step(g_dev, S.h, budgetNs, &S.st);
    if (S.st.geometry_ready && !S.geom) { S.geom = true; S.tGeom = nxn_time_ns(); ngfx_scene_info_get(g_dev, S.h, &S.info); }
    if (S.st.ready && !S.done) { S.done = true; S.tDone = nxn_time_ns(); S.memAfter = heap_bytes(); }
}

/* ------------------------------------------------------------------ camera */
struct Cam { V3 pos{0, 2, 0}; float yaw = 0, pitch = 0, fov = 65.f * 3.14159265f / 180.f; } g_cam;
static V3 cam_fwd(const Cam& c) { return {sinf(c.yaw) * cosf(c.pitch), sinf(c.pitch), -cosf(c.yaw) * cosf(c.pitch)}; }
static void cam_spawn() {
    const ngfx_scene_info& h = S.info;
    if (h.has_camera) { g_cam.pos = {h.camera[0], h.camera[1], h.camera[2]}; g_cam.yaw = h.camera[3]; g_cam.pitch = h.camera[4]; if (h.fov_deg > 5) g_cam.fov = h.fov_deg * 3.14159265f / 180.f; return; }
    g_cam.pos = {(h.bmin[0] + h.bmax[0]) * 0.5f, (h.bmin[1] < 0.f && h.bmax[1] > 0.f ? 0.f : h.bmin[1]) + 1.7f, (h.bmin[2] + h.bmax[2]) * 0.5f};
    g_cam.yaw = 0; g_cam.pitch = 0;
}

/* ------------------------------------------------------------------ auto tour */
/* A Catmull-Rom path through up to 11 waypoints taken from large flat chunks (floors, ground), so the eye stays about
 * 1.7 m above a floor; the camera looks a little ahead along the path. Any stick input hands control back. */
struct Tour { std::vector<V3> wp; float s = 0; bool active = false; bool pending = true; } g_tour;
static V3 tour_eval(float s) {
    int n = (int)g_tour.wp.size(); if (n < 2) return g_tour.wp.empty() ? V3{0, 0, 0} : g_tour.wp[0];
    s = std::max(0.f, std::min(s, (float)(n - 1) - 0.001f)); int i = (int)s; float u = s - (float)i;
    V3 p0 = g_tour.wp[i > 0 ? i - 1 : 0], p1 = g_tour.wp[i], p2 = g_tour.wp[i + 1], p3 = g_tour.wp[i + 2 < n ? i + 2 : n - 1];
    float u2 = u * u, u3 = u2 * u;
    return (p1 * 2.f + (p2 - p0) * u + (p0 * 2.f - p1 * 5.f + p2 * 4.f - p3) * u2 + (p1 * 3.f - p0 - p2 * 3.f + p3) * u3) * 0.5f;
}
static void tour_build() {
    g_tour.wp.clear(); g_tour.s = 0;
    float floorY = g_cam.pos.y - 1.7f;
    std::vector<V3> cand;
    for (uint32_t ci = 0; ci < S.info.chunks; ci++) {
        struct { float bmin[3], bmax[3]; } c;
        if (ngfx_scene_chunk_bounds(g_dev, S.h, ci, c.bmin, c.bmax) != NGFX_OK) continue;
        float dx = c.bmax[0] - c.bmin[0], dz = c.bmax[2] - c.bmin[2];
        if (c.bmax[1] - c.bmin[1] < 0.8f && dx * dz > 30.f && fabsf(c.bmax[1] - floorY) < 3.f)
            cand.push_back({(c.bmin[0] + c.bmax[0]) * 0.5f, c.bmax[1] + 1.7f, (c.bmin[2] + c.bmax[2]) * 0.5f});
    }
    g_tour.wp.push_back(g_cam.pos);
    std::vector<float> dmin(cand.size(), 1e30f);
    for (int k = 0; k < 10 && !cand.empty(); k++) { /* farthest-point sampling from the spawn */
        int best = -1; float bd = -1;
        for (size_t i = 0; i < cand.size(); i++) {
            V3 d = cand[i] - g_tour.wp.back(); dmin[i] = std::min(dmin[i], d.x * d.x + d.z * d.z);
            if (dmin[i] > bd) { bd = dmin[i]; best = (int)i; }
        }
        if (best < 0 || bd < 25.f) break;
        g_tour.wp.push_back(cand[best]); dmin[best] = -1;
    }
    if (g_tour.wp.size() < 3) { /* no floors found: a gentle circle around the spawn */
        g_tour.wp.clear(); V3 p = g_cam.pos;
        for (int k = 0; k < 9; k++) { float a = (float)k * 0.785398f; g_tour.wp.push_back({p.x + cosf(a) * 8.f - 8.f, p.y, p.z + sinf(a) * 8.f}); }
    }
    logf_("tour: %d waypoints", (int)g_tour.wp.size());
}
/* true while the tour owns the camera; at the end it asks for the next scene */
static bool tour_update(float dt, int& want, int cur) {
    int n = (int)g_tour.wp.size(); if (!g_tour.active || n < 2) return false;
    int i = std::min((int)g_tour.s, n - 2); V3 d = g_tour.wp[i + 1] - g_tour.wp[i]; float len = std::max(sqrtf(dot(d, d)), 1.f);
    float edge = std::min(g_tour.s, (float)(n - 1) - g_tour.s), ease = std::min(1.f, 0.2f + 0.8f * edge);
    g_tour.s += dt * 4.5f * ease / len;
    if (g_tour.s >= (float)(n - 1) - 0.01f) { g_tour.active = false; g_tour.pending = true; want = (cur + 1) % kNumScenes; return false; }
    g_cam.pos = tour_eval(g_tour.s);
    V3 look = tour_eval(g_tour.s + 0.35f) - g_cam.pos;
    if (look.x * look.x + look.z * look.z > 1e-4f) {
        float dy = atan2f(look.x, -look.z) - g_cam.yaw;
        while (dy > 3.14159f) dy -= 6.28318f;
        while (dy < -3.14159f) dy += 6.28318f;
        g_cam.yaw += dy * std::min(1.f, dt * 2.5f);
    }
    g_cam.pitch += (-0.05f - g_cam.pitch) * std::min(1.f, dt * 2.f);
    return true;
}

/* ------------------------------------------------------------------ rendering */
/* writes the visible frame as a 24-bit BMP into the app's data folder (self-test screenshots) */
static void screenshot(const char* name) {
    size_t rowb = ((size_t)g_w * 3 + 3) & ~(size_t)3, sz = rowb * g_h;
    std::vector<uint8_t> buf(54 + sz, 0);
    uint8_t* h = buf.data(); h[0] = 'B'; h[1] = 'M';
    uint32_t fs = (uint32_t)buf.size(), off = 54, ihs = 40, w = g_w, hh = g_h; uint16_t pl = 1, bpp = 24;
    memcpy(h + 2, &fs, 4); memcpy(h + 10, &off, 4); memcpy(h + 14, &ihs, 4); memcpy(h + 18, &w, 4); memcpy(h + 22, &hh, 4); memcpy(h + 26, &pl, 2); memcpy(h + 28, &bpp, 2);
    glBindFramebuffer(GL_FRAMEBUFFER, 0); glPixelStorei(GL_PACK_ALIGNMENT, 4); glReadBuffer(GL_BACK);
    glReadPixels(0, 0, (GLsizei)g_w, (GLsizei)g_h, 0x80E0 /* GL_BGR */, GL_UNSIGNED_BYTE, h + 54);
    nxn_fs_write(NXN_DIR_DATA, name, buf.data(), buf.size());
}

/* ------------------------------------------------------------------ UI */
static const ImGuiKey kPadKeys[] = {ImGuiKey_GamepadDpadLeft, ImGuiKey_GamepadDpadRight, ImGuiKey_GamepadDpadUp, ImGuiKey_GamepadDpadDown};
static const uint64_t kPadBits[] = {NXN_BTN_LEFT, NXN_BTN_RIGHT, NXN_BTN_UP, NXN_BTN_DOWN};
static void feed_imgui(float dt) {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2((float)g_w, (float)g_h);
    io.DeltaTime = dt > 0.0001f ? dt : 0.0001f;
    io.AddKeyEvent(ImGuiKey_GamepadFaceDown, (g_in.actions & NXN_ACT_CONFIRM) != 0);
    for (int i = 0; i < 4; i++) io.AddKeyEvent(kPadKeys[i], (g_in.buttons & kPadBits[i]) != 0);
    static int was_down;
    if (g_in.touch_count > 0) {
        nxn_touch t = NXN_STRUCT_INIT(nxn_touch);
        if (nxn_input_touch(0, &t) == NXN_OK) {
            io.AddMouseSourceEvent(ImGuiMouseSource_TouchScreen); io.AddMousePosEvent(t.x, t.y); io.AddMouseButtonEvent(0, true); was_down = 1;
        }
    } else if (was_down) { io.AddMouseButtonEvent(0, false); io.AddMousePosEvent(-FLT_MAX, -FLT_MAX); was_down = 0; }
}

static double g_fps, g_ms;
static void draw_ui() {
    ImDrawList* dl = ImGui::GetBackgroundDrawList();
    bool loading = S.h && !S.done && !S.st.failed;
    if (g_overlay) {
        char t[256];
        snprintf(t, sizeof t, "%s  %.0f fps  %.1f ms\ndraws %d (+%d shadow)  tris %ldk  chunks %d/%d\nheap %.0f MB  gpu %.0f MB  %dx%d x%.2f",
                 S.index >= 0 ? kScenes[S.index].title : "-", g_fps, g_ms, g_st.draws, g_st.shadow_draws, g_st.triangles / 1000, g_st.chunks_seen, g_st.chunks_total,
                 heap_bytes() / 1048576.0, gpu_bytes() / 1048576.0, g_st.render_width, g_st.render_height, kScales[g_scaleIdx]);
        ImVec2 ts = ImGui::CalcTextSize(t);
        dl->AddRectFilled(ImVec2(6, 6), ImVec2(18 + ts.x, 14 + ts.y), IM_COL32(0, 0, 0, 150), 6.f);
        dl->AddText(ImVec2(12, 10), IM_COL32(255, 255, 255, 235), t);
    }
    const char* hint = "L/R scene   + menu   Y tour   - overlay   L-stick move (click = fast)   R-stick look   ZL down  ZR up";
    ImVec2 hs = ImGui::CalcTextSize(hint);
    dl->AddText(ImVec2(((float)g_w - hs.x) * 0.5f, (float)g_h - hs.y - 10), IM_COL32(255, 255, 255, 170), hint);
    if (!g_ready || loading || (S.h && S.st.failed)) {
        float frac = !g_ready ? (float)g_prepDone / (float)g_prepTotal : 0.f; const char* what = "Preparing shaders";
        char msg[240];
        if (g_ready && S.h) {
            if (S.st.failed) { snprintf(msg, sizeof msg, "Cannot load: %s", S.st.error); what = msg; }
            else {
                frac = S.st.progress;
                snprintf(msg, sizeof msg, "Loading %s: %d / %d textures", kScenes[S.index].title, S.st.textures_uploaded, S.st.textures_total); what = msg;
            }
        }
        float w = std::min(520.f, (float)g_w - 40.f), x = ((float)g_w - w) * 0.5f, y = (float)g_h * 0.5f;
        dl->AddRectFilled(ImVec2(x - 14, y - 40), ImVec2(x + w + 14, y + 30), IM_COL32(10, 12, 18, 215), 8.f);
        dl->AddText(ImVec2(x, y - 32), IM_COL32(255, 255, 255, 240), what);
        dl->AddRectFilled(ImVec2(x, y), ImVec2(x + w, y + 14), IM_COL32(70, 76, 90, 255), 5.f);
        dl->AddRectFilled(ImVec2(x, y), ImVec2(x + w * frac, y + 14), IM_COL32(90, 170, 255, 255), 5.f);
    }
    if (g_menu) {
        ImGui::SetNextWindowPos(ImVec2((float)g_w * 0.5f, (float)g_h * 0.5f), ImGuiCond_Always, ImVec2(0.5f, 0.5f));
        ImGui::SetNextWindowSize(ImVec2(std::min(460.f, (float)g_w - 20.f), 0));
        ImGui::Begin("Quality", &g_menu, ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoSavedSettings);
        ImGui::Checkbox("Shadows", &g_shadows); ImGui::Checkbox("FXAA", &g_fxaa); ImGui::Checkbox("Overlay (-)", &g_overlay);
        char b[64]; snprintf(b, sizeof b, "Resolution scale: %.0f%%  (A: next)", kScales[g_scaleIdx] * 100.f);
        if (ImGui::Button(b)) g_scaleIdx = (g_scaleIdx + 1) % 4;
        if (ImGui::Button("Previous scene (L)")) { g_in.pressed |= NXN_BTN_L; }
        ImGui::SameLine(); if (ImGui::Button("Next scene (R)")) { g_in.pressed |= NXN_BTN_R; }
        if (ImGui::Button("Close menu")) g_menu = false;
        ImGui::End();
    }
}

/* ------------------------------------------------------------------ main loop */
struct AutoStep { int scene; };
static int app_main(int, char**) {
    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps); nxn_caps_get(&caps);
    char probe[16]; size_t got = 0;
    bool autotest = nxn_fs_read(NXN_DIR_DATA, "autotest", probe, sizeof probe - 1, &got) == NXN_OK;
    got = 0;
    bool bench = !autotest && nxn_fs_read(NXN_DIR_DATA, "bench", probe, sizeof probe - 1, &got) == NXN_OK;
    int benchScene = 0, benchSecs = 60;
    if (bench) { probe[got] = 0; sscanf(probe, "%d %d", &benchScene, &benchSecs); benchScene = benchScene == 1 ? 1 : 0; if (benchSecs < 5) benchSecs = 60; }
    { char o[8]; size_t og = 0; g_drawWhileLoading = nxn_fs_read(NXN_DIR_DATA, "oldload", o, sizeof o - 1, &og) == NXN_OK; }  /* measuring aid: the 5 ms budget and the half loaded draw of before */
    nxn_result r = nxn_display_open(NULL, &g_disp);
    if (r != NXN_OK) { nxn_request_return(NXN_RETURN_ERROR, 1, "OpenGL 4.3 is not available"); return 1; }
    int ok = gladLoadGLLoader((GLADloadproc)nxn_display_proc);
    nxn_display_size(g_disp, &g_w, &g_h); if (!g_w || !g_h) { g_w = 1280; g_h = 720; }
    snprintf(g_glinfo[0], sizeof g_glinfo[0], "%s", (const char*)glGetString(GL_VERSION));
    snprintf(g_glinfo[1], sizeof g_glinfo[1], "%s", (const char*)glGetString(GL_RENDERER));
    if (ngfx_device_create(NULL, &g_dev) != NGFX_OK) { nxn_request_return(NXN_RETURN_ERROR, 1, ngfx_native_error()); return 1; }
    ngfx_device_caps dc = {sizeof dc}; ngfx_device_caps_get(g_dev, &dc);
    logf_("gl %s | %s | glad %d | nexgfx native api %u.%u | s3tc %d srgb-s3tc %d rgtc %d aniso %.0f | nexgfx cap %d | windowed %d | surface %ux%u", g_glinfo[0], g_glinfo[1], ok,
          ngfx_native_version() >> 16, ngfx_native_version() & 0xffff, dc.bc_native, dc.bc_srgb, dc.rgtc, dc.max_anisotropy, (caps.features & NXN_CAP_NEXGFX) ? 1 : 0,
          (caps.features & NXN_CAP_WINDOWED) ? 1 : 0, g_w, g_h);

    IMGUI_CHECKVERSION(); ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO(); io.IniFilename = nullptr; io.LogFilename = nullptr; io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad; io.BackendFlags |= ImGuiBackendFlags_HasGamepad;
    ImFontConfig fc; fc.SizePixels = 18.f; io.Fonts->AddFontDefault(&fc);
    ImGui::StyleColorsDark(); ImGui::GetStyle().WindowRounding = 8; ImGui::GetStyle().FrameRounding = 4;
    ImGui_ImplOpenGL3_Init("#version 330 core");

    const int kAutoOrder[] = {0, 1, 0, 1, 0, 1, 0}; /* load, measure, unload: three round trips between the two scenes */
    int autoStep = 0; uint64_t autoT = 0; int autoPhase = 0; double fpsSum = 0, msSum = 0; int fpsN = 0; long drawSum = 0, triSum = 0;
    int cur = 0, want = -1; if (autotest) cur = kAutoOrder[0]; if (bench) cur = benchScene;
    uint64_t appT0 = nxn_time_ns(), liveT = appT0, benchT = 0; double liveSum = 0, liveWorst = 0, benchSum = 0, benchWorst = 0; int liveN = 0, liveSlow = 0, benchN = 0, benchSlow = 0;
    size_t memStart = heap_bytes(); logf_("heap at start: %.1f MB", memStart / 1048576.0);
    uint64_t last = nxn_time_ns(), lastFps = last; int fpsFrames = 0; bool loadedOnce = false;
    float lastTx = 0, lastTy = 0; bool touchDown = false;
    int shotsTaken = 0;
    std::vector<float> loadFrameMs;

    while (!nxn_should_quit()) {
        uint64_t now = nxn_time_ns(); float dt = (float)(now - last) / 1e9f; last = now;
        double frameMs = dt * 1000.0; g_ms = g_ms * 0.9 + frameMs * 0.1; fpsFrames++;
        if (now - lastFps >= 500000000ull) { g_fps = fpsFrames * 1e9 / (double)(now - lastFps); fpsFrames = 0; lastFps = now; }
        if (S.h && !S.done && frameMs > S.maxFrameMs && loadedOnce) S.maxFrameMs = frameMs;
        
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {
            if (ev.type == NXN_EVENT_RESIZE && ev.width && ev.height) { nxn_display_resize(g_disp, ev.width, ev.height); nxn_display_size(g_disp, &g_w, &g_h); }
            ev.size = sizeof ev;
        }
        nxn_input_poll(&g_in);
        if (!autotest && !bench) {
            if (g_in.pressed & NXN_BTN_PLUS) g_menu = !g_menu;
            if (g_menu && (g_in.pressed & NXN_BTN_B)) g_menu = false;
            if (g_in.pressed & NXN_BTN_MINUS) g_overlay = !g_overlay;
            if ((g_in.pressed & NXN_BTN_Y) && S.geom) { cam_spawn(); tour_build(); g_tour.pending = true; g_tour.active = true; g_menu = false; }
            if (g_in.pressed & NXN_BTN_L) want = (cur + kNumScenes - 1) % kNumScenes;
            if (g_in.pressed & NXN_BTN_R) want = (cur + 1) % kNumScenes;
        }

        /* shaders first (one per frame, behind the progress bar), then the first scene */
        if (!g_ready) {
            int pr = ngfx_device_prepare(g_dev, &g_prepDone, &g_prepTotal);
            if (pr < 0) { nxn_request_return(NXN_RETURN_ERROR, 1, ngfx_native_error()); break; }
            g_ready = pr == 1;
        }
        /* the scene files are read by a worker thread, so the first scene starts loading at once and overlaps the shader build */
        if (!S.h && S.index < 0) { scene_load(cur); }
        else if (!g_ready) { /* shaders still building */ }
        else if (want >= 0 && want != cur) { cur = want; want = -1; scene_load(cur); loadedOnce = false; }
        else want = -1;

        if (S.h) {
            /* while a scene loads, the frame is mostly upload: a long budget (several textures per frame) and no 3D draw of the half
             * loaded scene (the draw was the slow part of the frame, so loading took as many frames as there are textures) */
            scene_step(S.done || g_drawWhileLoading ? 5000000ull : 24000000ull);
            if (S.geom && !loadedOnce) { loadedOnce = true; cam_spawn(); if (!autotest && !bench) { tour_build(); g_tour.active = g_tour.pending; } }
        }
        if (S.h && !S.done && !S.st.failed && S.geom && S.maxFrameMs < frameMs) S.maxFrameMs = frameMs;

        /* camera */
        if (g_tour.active && (fabsf(g_in.lx) > 0.25f || fabsf(g_in.ly) > 0.25f || fabsf(g_in.rx) > 0.25f || fabsf(g_in.ry) > 0.25f || g_in.touch_count > 0 || (g_in.buttons & (NXN_BTN_ZL | NXN_BTN_ZR)))) { g_tour.active = false; g_tour.pending = false; }
        bool touring = !autotest && !bench && S.geom && loadedOnce && !g_menu && tour_update(dt, want, cur);
        if (!autotest && !bench && S.geom && !g_menu && !touring) {
            float speed = (3.f + S.info.radius * 0.025f) * ((g_in.buttons & (NXN_BTN_LSTICK | NXN_BTN_X)) ? 4.f : 1.f);
            V3 f = cam_fwd(g_cam), fl = norm(V3{f.x, 0, f.z}), rt = norm(cross(f, V3{0, 1, 0}));
            g_cam.pos = g_cam.pos + fl * (g_in.ly * speed * dt) + rt * (g_in.lx * speed * dt);
            if (g_in.buttons & NXN_BTN_ZR) g_cam.pos.y += speed * 0.6f * dt;
            if (g_in.buttons & NXN_BTN_ZL) g_cam.pos.y -= speed * 0.6f * dt;
            g_cam.yaw += g_in.rx * 2.2f * dt; g_cam.pitch += g_in.ry * 1.6f * dt;
            if (g_in.touch_count > 0) {
                nxn_touch t = NXN_STRUCT_INIT(nxn_touch);
                if (nxn_input_touch(0, &t) == NXN_OK) {
                    if (touchDown) { g_cam.yaw += (t.x - lastTx) * 0.004f; g_cam.pitch -= (t.y - lastTy) * 0.004f; }
                    lastTx = t.x; lastTy = t.y; touchDown = true;
                }
            } else touchDown = false;
        }
        g_cam.pitch = std::max(-1.5f, std::min(1.5f, g_cam.pitch));

        /* self-test: scripted camera and the measuring sequence */
        if (autotest && S.geom && loadedOnce) {
            if (autoPhase == 0 && S.done) { autoPhase = autoStep < 2 ? 1 : 3; autoT = now; logf_("[%d] %s ready: load %.0f ms (geometry %.0f ms), longest frame while loading %.0f ms, heap %.1f -> %.1f MB, gpu %.0f MB",
                                                                 autoStep, kScenes[S.index].title, (S.tDone - S.tStart) / 1e6, (S.tGeom - S.tStart) / 1e6, S.maxFrameMs, S.memBefore / 1048576.0, S.memAfter / 1048576.0, gpu_bytes() / 1048576.0); }
            else if (autoPhase == 1 && now - autoT > 1500000000ull) { /* settle, then one screenshot per first visit */
                if (autoStep < 2) {
                    char nm[64]; snprintf(nm, sizeof nm, "shot_%s.bmp", kScenes[S.index].file); screenshot(nm); shotsTaken++;
                    autoPhase = 2; autoT = now;
                } else { autoPhase = 2; autoT = now; }
                fpsSum = msSum = 0; fpsN = 0; drawSum = triSum = 0;
            } else if (autoPhase == 2) { /* 3 s fly-through measure */
                float t = (float)(now - autoT) / 1e9f;
                g_cam.yaw += 0.6f * dt; g_cam.pos = g_cam.pos + norm(V3{cam_fwd(g_cam).x, 0, cam_fwd(g_cam).z}) * (3.f * dt);
                fpsSum += frameMs; fpsN++; msSum = std::max(msSum, frameMs); drawSum += g_st.draws; triSum += g_st.triangles;
                if (t > 3.f) {
                    logf_("[%d] %s run: avg %.1f ms (%.0f fps), worst %.1f ms, draws %ld (+%d shadow), tris %ldk", autoStep, kScenes[S.index].title, fpsSum / fpsN, 1000.0 * fpsN / fpsSum, msSum,
                          drawSum / std::max(fpsN, 1), g_st.shadow_draws, triSum / std::max(fpsN, 1) / 1000);
                    logf_("[%d] gl errors so far: %d (last 0x%x), textures %d/%d uploaded, texture+buffer gpu %.0f MB", autoStep, g_glErr, (unsigned)g_lastErr, S.st.textures_uploaded, S.st.textures_total, S.st.gpu_bytes / 1048576.0);
                    autoPhase = 3;
                }
            } else if (autoPhase == 3) {
                scene_unload(); size_t m = heap_bytes();
                logf_("[%d] unloaded: heap %.1f MB (start %.1f), gpu %.0f MB", autoStep, m / 1048576.0, memStart / 1048576.0, gpu_bytes() / 1048576.0);
                report_write();
                if (++autoStep >= (int)(sizeof kAutoOrder / sizeof kAutoOrder[0])) { nxn_request_return(NXN_RETURN_NORMAL, 7, NULL); }
                else { cur = kAutoOrder[autoStep]; S.index = -1; autoPhase = 0; loadedOnce = false; }
                (void)shotsTaken;
            }
        }

        /* live numbers (every run) and the fixed-camera benchmark */
        if (frameMs > 0 && frameMs < 10000) { liveSum += frameMs; liveN++; if (frameMs > liveWorst) liveWorst = frameMs; if (frameMs > 50) liveSlow++; }
        if (bench && S.done) {
            if (!benchT) logf_("bench: scene ready %.0f ms after the app started (shaders, files and uploads)", (S.tDone - appT0) / 1e6);
            if (!benchT) { benchT = now; logf_("bench: %s ready: load %.0f ms (geometry %.0f ms), longest frame while loading %.0f ms, heap %.1f MB, gpu %.0f MB",
                                               kScenes[S.index].title, (S.tDone - S.tStart) / 1e6, (S.tGeom - S.tStart) / 1e6, S.maxFrameMs, S.memAfter / 1048576.0, gpu_bytes() / 1048576.0); }
            else { benchSum += frameMs; benchN++; if (frameMs > benchWorst) benchWorst = frameMs; if (frameMs > 50) benchSlow++; }
            if (benchT && now - benchT >= (uint64_t)benchSecs * 1000000000ull) {
                logf_("bench: %s %d s fixed camera: %d frames, avg %.2f ms (%.1f fps), longest %.1f ms, %d over 50 ms, draws %d, tris %ldk, %dx%d",
                      kScenes[S.index].title, benchSecs, benchN, benchSum / std::max(benchN, 1), benchN * 1000.0 / std::max(benchSum, 1.0), benchWorst, benchSlow,
                      g_st.draws, g_st.triangles / 1000, g_st.render_width, g_st.render_height);
                report_write();
                nxn_request_return(NXN_RETURN_NORMAL, 7, NULL);
                bench = false;
            }
        }
        if (now - liveT >= 10000000000ull) {
            char ln[300];
            snprintf(ln, sizeof ln, "live: %.0f s, %s, %d frames, avg %.2f ms (%.1f fps), longest %.1f ms, %d over 50 ms, %s%s",
                     (double)(now - appT0) / 1e9, S.index >= 0 ? kScenes[S.index].title : "-", liveN,
                     liveSum / std::max(liveN, 1), liveN * 1000.0 / std::max(liveSum, 1.0), liveWorst, liveSlow,
                     S.done ? "loaded" : "loading", benchT ? " (bench running)" : "");
            report_live(ln);
            liveT = now; liveSum = liveWorst = 0; liveN = liveSlow = 0;
        }

        feed_imgui(dt);
        ImGui_ImplOpenGL3_NewFrame(); ImGui::NewFrame(); draw_ui(); ImGui::Render();

                if (g_ready) {
            ngfx_view view = {sizeof view, {g_cam.pos.x, g_cam.pos.y, g_cam.pos.z}, g_cam.yaw, g_cam.pitch, g_cam.fov * 180.f / 3.14159265f, g_w, g_h, kScales[g_scaleIdx],
                              (g_shadows ? NGFX_VIEW_SHADOWS : 0u) | (g_fxaa ? NGFX_VIEW_FXAA : 0u), 1.0f, 0};
            ngfx_render(g_dev, S.geom && (S.done || g_drawWhileLoading) ? S.h : 0, &view, &g_st);
        } else { glBindFramebuffer(GL_FRAMEBUFFER, 0); glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h); glClearColor(0.05f, 0.06f, 0.09f, 1); glClear(GL_COLOR_BUFFER_BIT); }
        glBindFramebuffer(GL_FRAMEBUFFER, 0); glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h); glDisable(GL_DEPTH_TEST);
        for (GLenum e; (e = glGetError()) != GL_NO_ERROR;) { g_glErr++; g_lastErr = e; }
        if (autotest && autoPhase == 1 && now - autoT > 1500000000ull && autoStep < 2) { /* screenshot without the UI: the frame is already tone mapped */ }
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
        nxn_display_swap(g_disp);
    }
    report_write();
    scene_unload();
    ngfx_device_destroy(g_dev);
    ImGui_ImplOpenGL3_Shutdown(); ImGui::DestroyContext();
    nxn_display_close(g_disp);
    return 0;
}

int main(int argc, char** argv) { return nxn_run(argc, argv, app_main, NULL); }
