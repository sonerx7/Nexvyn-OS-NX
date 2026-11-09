/* Graphics Power: a native 3D keynote of Nexvyn OS (see README.md).
 *
 * One baked scene (data/town.nxsc + town.nxtx, made by tools/nxv_asset) is streamed and drawn by NexGFX (nexgfx_native.h):
 * metallic-roughness PBR, a fitted sun shadow map, ACES tone mapping, FXAA, per-chunk culling. Around it: an intro, seven
 * chapters (a cinematic camera, a title card, an info card with before -> after numbers, one live element), a benchmark with a
 * local score list, a summary. The frame rate is uncapped (NXN_DISPLAY_NO_VSYNC); the render scale only drops when the
 * frame rate falls below 60 (floor guard). Every "console" number on a card is a row of qa/PERFORMANS.md.
 * Test hook: <data>/script, lines "<seconds> <command> [arg]" (seconds since the town is ready): shot NAME, ch N, intro,
 * hub, finale, bench, scores, speed X, key A|B|Y|UP|DOWN|MINUS, quit.  Lines may also be separated by ";". Report: graphics_report.txt (also rewritten every 10 s). */
#include <glad/glad.h>
#include <malloc.h>
#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
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
static bool g_docked = false;
static int g_overlay = 1;      /* 0 off, 1 fps chip, 2 full HUD */
static float g_scale = 1.0f;   /* render scale: 1 unless the frame rate falls below 60 (or a chapter shows it off) */
static float g_tscale = 1.f;   /* test hook: speeds up every timeline */

static std::string g_report;
static void logf_(const char* fmt, ...) __attribute__((format(printf, 1, 2)));
static void logf_(const char* fmt, ...) {
    char b[512]; va_list ap; va_start(ap, fmt); vsnprintf(b, sizeof b, fmt, ap); va_end(ap);
    nxn_log(NXN_LOG_INFO, "%s", b); g_report += b; g_report += "\n";
}
static void report_write(const char* live = nullptr) {
    std::string r = g_report; if (live) { r += live; r += '\n'; }
    nxn_fs_write(NXN_DIR_DATA, "graphics_report.txt", r.data(), r.size());
}
static const char* T(const char* k) { return nxn_tr(k); }

static ngfx_device* g_dev;
static ngfx_frame_stats g_st = {sizeof(ngfx_frame_stats)};
static ngfx_scene g_scene = 0; static ngfx_scene_status g_ss; static ngfx_scene_info g_info; static bool g_geom = false, g_done = false;
static bool g_ready; static uint32_t g_prepDone, g_prepTotal = 5;
static uint64_t g_loadStart = 0; static double g_loadMs = 0;  /* the last scene load, ms */
static size_t heap_bytes() { struct mallinfo mi = mallinfo(); return (size_t)mi.uordblks + (size_t)mi.hblkhd; }
static uint64_t gpu_bytes() { ngfx_device_caps c = {sizeof c}; ngfx_device_caps_get(g_dev, &c); return c.gpu_bytes; }

/* ------------------------------------------------------------------ camera: one closed orbit path, a look-at target */
struct Key { V3 pos, tgt; float secs; };
static const Key kKeys[] = {
    {{0.0f, 11, -20.0f}, {0, 3, 10}, 11},  {{18.4f, 9, -8.4f}, {0, 3, 10}, 11},  {{24.0f, 8, 10.0f}, {0, 3, 10}, 11}, {{18.4f, 10, 28.4f}, {0, 3, 10}, 11},
    {{0.0f, 12, 40.0f}, {0, 3, 10}, 11},   {{-18.4f, 9, 28.4f}, {0, 3, 10}, 11}, {{-24.0f, 7, 10.0f}, {0, 3, 10}, 11}, {{-18.4f, 9, -8.4f}, {0, 3, 10}, 11},
};
static const int kNumKeys = (int)(sizeof kKeys / sizeof kKeys[0]);
static float path_total() { float s = 0; for (auto& k : kKeys) s += k.secs; return s; }
static V3 crom(const V3& p0, const V3& p1, const V3& p2, const V3& p3, float u) {
    float u2 = u * u, u3 = u2 * u;
    return (p1 * 2.f + (p2 - p0) * u + (p0 * 2.f - p1 * 5.f + p2 * 4.f - p3) * u2 + (p1 * 3.f - p0 - p2 * 3.f + p3) * u3) * 0.5f;
}
static void path_eval(float t, V3& pos, V3& tgt) {
    float total = path_total(); t = fmodf(t, total); if (t < 0) t += total;
    int i = 0; while (i < kNumKeys - 1 && t >= kKeys[i].secs) { t -= kKeys[i].secs; i++; }
    float u = t / kKeys[i].secs; u = u * u * (3.f - 2.f * u) * 0.35f + u * 0.65f;
    auto K = [&](int j) -> const Key& { return kKeys[((j % kNumKeys) + kNumKeys) % kNumKeys]; };
    pos = crom(K(i - 1).pos, K(i).pos, K(i + 1).pos, K(i + 2).pos, u);
    tgt = crom(K(i - 1).tgt, K(i).tgt, K(i + 1).tgt, K(i + 2).tgt, u);
}
struct Cam { V3 pos{0, 11, -20}; float yaw = 0, pitch = -0.2f, fovDeg = 60.f; } g_cam;
static V3 cam_fwd(const Cam& c) { return {sinf(c.yaw) * cosf(c.pitch), sinf(c.pitch), -cosf(c.yaw) * cosf(c.pitch)}; }
static void cam_path(float t, float fov) {
    V3 p, tg; path_eval(t, p, tg); V3 d = tg - p; float h = sqrtf(d.x * d.x + d.z * d.z);
    g_cam.pos = p; g_cam.yaw = atan2f(d.x, -d.z); g_cam.pitch = atan2f(d.y, std::max(h, 0.001f)); g_cam.fovDeg = fov;
}

/* ------------------------------------------------------------------ chapters */
struct Row { const char* key; float a, b; const char* unit; bool lower; const char* mult; const char* atxt; const char* btxt; };
struct Chapter { const char* id; const char* api; const char* langs; int nrows; Row rows[3]; float cam0, rate, fov; };
static const char* kLangAll = "C|C++|Lua|JS|Python";
static const Chapter kCh[] = {
    {"c0", "NexGFX ngfx_render  /  PBR, sun shadow map, shadow cache", kLangAll, 1, {{"c0.r0", 10.f, 59.3f, "fps", false, "x6", 0, 0}}, 0.f, 1.0f, 58.f},
    {"c1", "NexGFX render_scale  /  60 fps floor guard", kLangAll, 1, {{"c1.r0", 0, 0, "fps", false, 0, 0, 0}}, 12.f, 1.0f, 62.f},
    {"c2", "ngfx_scene_load / ngfx_scene_step  /  BC1 BC3 BC5 textures", "C|C++", 1, {{"c2.r0", 30.f, 0.58f, "s", true, "~50x", 0, 0}}, 24.f, 0.9f, 60.f},
    {"c3", "Windowed frame path  /  nxn_display_swap", "C|C++", 1, {{"c3.r0", 19.5f, 0.16f, "ms", true, "~150x", "0.10-0.22 ms", "15-24 ms"}}, 36.f, 1.0f, 64.f},
    {"c4", "nxn_input_poll  /  nxn_input_touch", kLangAll, 1, {{"c4.r0", 0, 0, "", false, 0, 0, 0}}, 48.f, 0.8f, 58.f},
    {"c5", "nxn_tone  /  SDL2-nexvyn mixer and resampler", kLangAll, 1, {{"c5.r0", 4.5f, 59.6f, "fps", false, "~13x", 0, 0}}, 60.f, 1.0f, 60.f},
    {"c6", "NexGFX tiled forward, half-res buffers, multi-draw", "C|C++", 3, {{"c6.r0", 5.9f, 27.5f, "fps", false, "x4.7", 0, 0}, {"c6.r1", 17.1f, 46.6f, "fps", false, "x2.7", 0, 0}, {"c6.r2", 1422.f, 337.f, "", true, "x4.2", 0, 0}}, 72.f, 1.1f, 62.f},
};
static const int kNumCh = (int)(sizeof kCh / sizeof kCh[0]);
static const float kChDur = 12.f;

/* ------------------------------------------------------------------ state */
enum Mode { M_INTRO, M_HUB, M_CHAPTER, M_BENCH, M_RESULTS, M_SCORES, M_FINALE, M_FREE };
static Mode g_mode = M_INTRO; static float g_mt = 0;
static int g_ch = 0, g_sel = 0; static bool g_tour = false;
static float g_fade = 1.f;     /* black overlay, 1 = black */
static double g_fps = 0, g_ms = 0, g_cpuMs = 0, g_fpsShown = 0, g_low1 = 0;
static std::vector<float> g_ring(600, 16.f); static int g_ringPos = 0;
static float g_spark[120]; static int g_sparkPos = 0;
static bool g_shotPending = false; static std::string g_shotName;

struct Stage { const char* key; float cam0, rate, fov, scale; };
static const Stage kStages[] = {{"b.s0", 0.f, 1.f, 60.f, 1.f}, {"b.s1", 20.f, 3.f, 60.f, 1.f}, {"b.s2", 40.f, 1.2f, 95.f, 1.f}, {"b.s3", 8.f, 1.f, 60.f, 0.6f}};
static const int kStageCount = 4, kBenchTotal = 5;  /* four timed passes + the streaming test */
static float g_stageSecs = 7.f; static const float kWarm = 1.f;
struct StageRes { double fps = 0, low = 0, pts = 0; int frames = 0; };
static StageRes g_bres[kBenchTotal]; static int g_bstage = 0; static float g_bt = 0; static std::vector<float> g_bms; static double g_bsum = 0;
static double g_btotal = 0; static int g_brank = 0; static bool g_bscripted = false;
static uint64_t g_reloadT0 = 0; static bool g_reloading = false;

struct ScoreRow { int score; long long when; int docked; };
static std::vector<ScoreRow> g_scores;
static void scores_load() {
    char b[2048]; size_t got = 0; g_scores.clear();
    if (nxn_fs_read(NXN_DIR_DATA, "scores.txt", b, sizeof b - 1, &got) != NXN_OK) return;
    b[got] = 0;
    for (char* l = strtok(b, "\n"); l; l = strtok(NULL, "\n")) { ScoreRow r; long long w; int d; if (sscanf(l, "%d %lld %d", &r.score, &w, &d) == 3) { r.when = w; r.docked = d; g_scores.push_back(r); } }
}
static void scores_save() {
    std::string s; char l[64];
    for (auto& r : g_scores) { snprintf(l, sizeof l, "%d %lld %d\n", r.score, r.when, r.docked); s += l; }
    nxn_fs_write(NXN_DIR_DATA, "scores.txt", s.data(), s.size());
}

/* ------------------------------------------------------------------ sound cues (nxn_tone; silent when audio is missing) */
static void tone(float f, float s, float v, uint32_t w = 0) { nxn_tone(f, s, v, w); }
static void cue_move() { tone(1300.f, 0.04f, 0.10f); }
static void cue_pick() { tone(660.f, 0.10f, 0.14f, 3); tone(990.f, 0.16f, 0.12f, 3); }
static void cue_chapter() { tone(196.f, 0.7f, 0.14f, 3); tone(392.f, 0.9f, 0.10f, 0); }
struct Snd { float t, f, d, v; uint32_t w; };
static const Snd kIntroSnd[] = {{0.3f, 55.f, 5.0f, 0.22f, 3}, {1.0f, 110.f, 4.0f, 0.12f, 0}, {3.2f, 330.f, 0.5f, 0.10f, 3}, {3.9f, 440.f, 0.9f, 0.12f, 3},
                                {4.6f, 660.f, 1.6f, 0.12f, 0}, {5.2f, 220.f, 3.0f, 0.12f, 3}, {11.5f, 262.f, 2.5f, 0.10f, 0}, {11.5f, 392.f, 2.5f, 0.08f, 0}, {15.f, 523.f, 3.f, 0.10f, 3}};
static int g_introSnd = 0;

/* ------------------------------------------------------------------ drawing helpers */
static ImFont *fBody, *fTitle, *fBig;
static float U() { return (float)g_h / 720.f; }
static ImU32 C(int r, int g, int b, float a = 1.f) { return IM_COL32(r, g, b, (int)(std::max(0.f, std::min(1.f, a)) * 255.f)); }
#define ACC 70, 205, 255
#define GOLD 255, 200, 90
#define GRN 120, 240, 170
#define RED 255, 110, 110
static float sat(float x) { return std::max(0.f, std::min(1.f, x)); }
static float eout(float x) { x = 1.f - sat(x); return 1.f - x * x * x; }
static float sstep(float x) { x = sat(x); return x * x * (3.f - 2.f * x); }
static float tw(ImFont* f, float sz, const char* s) { return f->CalcTextSizeA(sz * U(), FLT_MAX, 0.f, s).x; }
static void txt(ImFont* f, float sz, float x, float y, ImU32 c, const char* s, float ax = 0.f, bool shadow = true) {
    ImDrawList* dl = ImGui::GetForegroundDrawList(); sz *= U(); x -= f->CalcTextSizeA(sz, FLT_MAX, 0.f, s).x * ax;
    if (shadow) dl->AddText(f, sz, ImVec2(x + 1.5f, y + 1.5f), IM_COL32(0, 0, 0, (int)(((c >> 24) & 255) * 0.7f)), s);
    dl->AddText(f, sz, ImVec2(x, y), c, s);
}
static float wrap_txt(ImFont* f, float sz, float x, float y, float w, ImU32 c, const char* s) {  /* returns the height */
    ImDrawList* dl = ImGui::GetForegroundDrawList(); sz *= U();
    dl->AddText(f, sz, ImVec2(x, y), c, s, NULL, w);
    return f->CalcTextSizeA(sz, FLT_MAX, w, s).y;
}
static void glass(float x0, float y0, float x1, float y1, float a, float accA = 0.7f) {
    ImDrawList* dl = ImGui::GetForegroundDrawList(); float r = 14.f * U();
    dl->AddRectFilled(ImVec2(x0 - 3, y0 - 3), ImVec2(x1 + 3, y1 + 3), C(ACC, 0.06f * a), r + 3);
    dl->AddRectFilled(ImVec2(x0, y0), ImVec2(x1, y1), C(6, 10, 18, 0.80f * a), r);
    dl->AddRect(ImVec2(x0, y0), ImVec2(x1, y1), C(ACC, 0.35f * a), r, 0, 1.2f);
    dl->AddRectFilled(ImVec2(x0 + r, y0), ImVec2(x0 + r + (x1 - x0 - 2 * r) * 0.35f, y0 + 2.5f * U()), C(ACC, accA * a));
}
static void bars_letterbox(float k) {
    ImDrawList* dl = ImGui::GetForegroundDrawList(); float h = 0.065f * (float)g_h * k;
    dl->AddRectFilled(ImVec2(0, 0), ImVec2((float)g_w, h), C(0, 0, 0)); dl->AddRectFilled(ImVec2(0, (float)g_h - h), ImVec2((float)g_w, (float)g_h), C(0, 0, 0));
}
static void vignette(float a) {
    ImDrawList* dl = ImGui::GetForegroundDrawList(); float w = (float)g_w, h = (float)g_h;
    dl->AddRectFilledMultiColor(ImVec2(0, 0), ImVec2(w * 0.5f, h), C(0, 0, 0, 0.78f * a), C(0, 0, 0, 0), C(0, 0, 0, 0), C(0, 0, 0, 0.78f * a));
    dl->AddRectFilledMultiColor(ImVec2(0, h * 0.7f), ImVec2(w, h), C(0, 0, 0, 0), C(0, 0, 0, 0), C(0, 0, 0, 0.6f * a), C(0, 0, 0, 0.6f * a));
}
static std::string fmt_num(double v, const char* unit) {
    char b[48]; if (v >= 1000) snprintf(b, sizeof b, "%.0f %s", v, unit); else if (v >= 100) snprintf(b, sizeof b, "%.0f %s", v, unit); else if (v >= 10) snprintf(b, sizeof b, "%.1f %s", v, unit); else snprintf(b, sizeof b, "%.2f %s", v, unit);
    return b;
}

/* the animated before -> after rows of a card; returns the height used */
static float draw_rows(const Chapter& c, float x, float y, float w, float t, const Row* live) {
    ImDrawList* dl = ImGui::GetForegroundDrawList(); float y0 = y;
    for (int i = 0; i < c.nrows; i++) {
        const Row& r = (live && i == 0) ? *live : c.rows[i];
        float p = eout((t - 0.2f * i) / 1.2f); float ry = y;
        txt(fBody, 15, x, y, C(255, 255, 255, 0.92f * p), T(r.key)); y += 22.f * U();
        if (r.atxt && !r.btxt) { txt(fTitle, 22, x, y, C(GRN, p), r.atxt); y += 36.f * U(); continue; }
        if (r.atxt && r.btxt) {  /* a text pair (a measured range) drawn as two bars of fixed length */
            float bw = w * 0.9f, lh = 14.f * U();
            dl->AddRectFilled(ImVec2(x, y), ImVec2(x + bw * p, y + lh), C(RED, 0.75f), lh * 0.5f); txt(fBody, 14, x + 6, y - 2 * U(), C(255, 255, 255, p), r.btxt, 0, false); y += lh + 6 * U();
            float aw = bw * 0.12f * p;
            dl->AddRectFilled(ImVec2(x, y), ImVec2(x + aw, y + lh), C(GRN, 0.95f), lh * 0.5f); txt(fBody, 14, x + aw + 8 * U(), y - 2 * U(), C(GRN, p), r.atxt, 0, false); y += lh + 14 * U();
        } else {
            float mx = std::max(r.a, r.b); if (mx <= 0) mx = 1;
            float bw = w * 0.86f, lh = 14.f * U();
            float la = bw * (r.a / mx) * p, lb = bw * (r.b / mx) * p;
            dl->AddRectFilled(ImVec2(x, y), ImVec2(x + std::max(la, lh), y + lh), C(r.lower ? 255 : 150, r.lower ? 110 : 160, r.lower ? 110 : 175, 0.85f), lh * 0.5f);
            std::string sa = fmt_num(r.a * p, r.unit);
            txt(fBody, 14, x + std::max(la, lh) + 8 * U(), y - 2 * U(), C(255, 255, 255, 0.85f * p), sa.c_str(), 0, false); y += lh + 6 * U();
            dl->AddRectFilled(ImVec2(x, y), ImVec2(x + std::max(lb, lh), y + lh), C(GRN, 0.95f), lh * 0.5f);
            std::string sb = fmt_num(r.b * p, r.unit);
            txt(fBody, 14, x + std::max(lb, lh) + 8 * U(), y - 2 * U(), C(GRN, p), sb.c_str(), 0, false); y += lh + 14 * U();
        }
        if (r.mult) { float pop = 1.f + 0.25f * (1.f - sat((t - 1.2f - 0.2f * i) * 3.f)); if (t > 1.0f) txt(fTitle, 30 * pop, x + w, ry - 8 * U(), C(GOLD, sat((t - 1.0f) * 3.f)), r.mult, 1.f); }
    }
    return y - y0;
}

/* ------------------------------------------------------------------ chapter live widgets */
static float g_liveA = 0, g_liveB = 0;  /* chapter 1: fps at 100% / 60% (measured live) */
static float g_la_sum = 0, g_lb_sum = 0; static int g_la_n = 0, g_lb_n = 0;
static float g_env[12]; static int g_noteIdx = -1; static float g_noteT = 0;
static bool g_shadowsOn = true;
static void draw_live(int ci, float t) {
    ImDrawList* dl = ImGui::GetForegroundDrawList(); float x = 70.f * U(), y = (float)g_h * 0.66f, a = eout((t - 1.5f) / 0.8f); if (a <= 0) return;
    char b[160];
    if (ci == 0) {
        float cw = 330.f * U(), ch = 54.f * U(); glass(x, y, x + cw, y + ch, a);
        txt(fBody, 16, x + 18 * U(), y + 8 * U(), C(255, 255, 255, a), T("c0.live"));
        txt(fTitle, 26, x + cw - 18 * U(), y + 8 * U(), g_shadowsOn ? C(GRN, a) : C(RED, a), g_shadowsOn ? T("ui.on") : T("ui.off"), 1.f);
    } else if (ci == 1) {
        float cw = 420.f * U(), ch = 120.f * U(); glass(x, y - 30 * U(), x + cw, y + ch - 30 * U(), a);
        snprintf(b, sizeof b, "%u x %u   (%.0f%%)", g_st.render_width, g_st.render_height, g_scale * 100.f);
        txt(fTitle, 24, x + 18 * U(), y - 18 * U(), C(ACC, a), b);
        snprintf(b, sizeof b, "100%%  %.0f fps", g_liveA); txt(fBody, 16, x + 18 * U(), y + 24 * U(), C(255, 255, 255, a), b);
        snprintf(b, sizeof b, "60%%  %.0f fps", g_liveB); txt(fBody, 16, x + 18 * U(), y + 48 * U(), C(GRN, a), b);
    } else if (ci == 2) {
        float cw = 430.f * U(), ch = 80.f * U(); glass(x, y, x + cw, y + ch, a);
        snprintf(b, sizeof b, "%s  %.0f ms", T("c2.live"), g_loadMs); txt(fTitle, 26, x + 18 * U(), y + 8 * U(), C(GOLD, a), b);
        snprintf(b, sizeof b, "%d textures   %uk triangles", g_ss.textures_total, g_info.triangles ? g_info.triangles / 1000 : 80u); txt(fBody, 16, x + 18 * U(), y + 46 * U(), C(255, 255, 255, a * 0.9f), b);
    } else if (ci == 3) {
        float cw = 330.f * U(), ch = 80.f * U(); glass(x, y, x + cw, y + ch, a);
        snprintf(b, sizeof b, "%.1f ms   %.0f fps", g_ms, g_fpsShown); txt(fTitle, 26, x + 18 * U(), y + 8 * U(), C(ACC, a), b);
        txt(fBody, 15, x + 18 * U(), y + 46 * U(), C(255, 255, 255, a * 0.85f), T("c3.live"));
    } else if (ci == 4) {
        float cw = 460.f * U(), ch = 130.f * U(); glass(x, y - 30 * U(), x + cw, y + ch - 30 * U(), a);
        float r = 36.f * U(), cy = y + 34 * U(); ImVec2 l(x + 60 * U(), cy), rr(x + 190 * U(), cy);
        dl->AddCircle(l, r, C(255, 255, 255, 0.5f * a), 32, 2.f); dl->AddCircle(rr, r, C(255, 255, 255, 0.5f * a), 32, 2.f);
        dl->AddCircleFilled(ImVec2(l.x + g_in.lx * r * 0.8f, l.y - g_in.ly * r * 0.8f), 9.f * U(), C(ACC, a));
        dl->AddCircleFilled(ImVec2(rr.x + g_in.rx * r * 0.8f, rr.y - g_in.ry * r * 0.8f), 9.f * U(), C(ACC, a));
        const uint64_t bt[4] = {NXN_BTN_X, NXN_BTN_Y, NXN_BTN_B, NXN_BTN_A}; const float ox[4] = {0, 1, 1, 0}, oy[4] = {-1, 0, 1, 0};
        for (int i = 0; i < 4; i++) { ImVec2 p(x + 330 * U() + ox[i] * 24 * U() + (i == 3 ? -24 * U() : 0), cy + (oy[i]) * 22 * U() * (i == 3 ? 0 : 1)); (void)p; }
        const float bx[4] = {330, 354, 354, 306}, by[4] = {-22, 0, 22, 0}; const uint64_t bm[4] = {NXN_BTN_X, NXN_BTN_A, NXN_BTN_B, NXN_BTN_Y};
        (void)bt;
        for (int i = 0; i < 4; i++) { bool on = (g_in.buttons & bm[i]) != 0; ImVec2 p(x + bx[i] * U(), cy + by[i] * U()); dl->AddCircleFilled(p, 9.f * U(), on ? C(GOLD, a) : C(255, 255, 255, 0.18f * a)); }
        bool zl = (g_in.buttons & NXN_BTN_ZL) != 0, zr = (g_in.buttons & NXN_BTN_ZR) != 0;
        dl->AddRectFilled(ImVec2(x + 30 * U(), y + 88 * U()), ImVec2(x + 130 * U(), y + 96 * U()), zl ? C(GOLD, a) : C(255, 255, 255, 0.18f * a), 4.f);
        dl->AddRectFilled(ImVec2(x + 150 * U(), y + 88 * U()), ImVec2(x + 250 * U(), y + 96 * U()), zr ? C(GOLD, a) : C(255, 255, 255, 0.18f * a), 4.f);
        if (g_in.touch_count > 0) {
            nxn_touch tc = NXN_STRUCT_INIT(nxn_touch);
            if (nxn_input_touch(0, &tc) == NXN_OK) {
                ImVec2 p(tc.x * (float)g_w / 1280.f, tc.y * (float)g_h / 720.f); float k = fmodf(t * 1.6f, 1.f);
                dl->AddCircle(p, (22.f + 40.f * k) * U(), C(ACC, 0.9f * (1.f - k)), 40, 3.f); dl->AddCircleFilled(p, 8.f * U(), C(ACC, 0.9f));
            }
        }
    } else if (ci == 5) {
        float cw = 400.f * U(), ch = 110.f * U(); glass(x, y - 20 * U(), x + cw, y + ch - 20 * U(), a);
        for (int i = 0; i < 12; i++) {
            float h = (14.f + 70.f * g_env[i]) * U(), bx = x + 22 * U() + i * 31.f * U();
            dl->AddRectFilled(ImVec2(bx, y + 80 * U() - h), ImVec2(bx + 20 * U(), y + 80 * U()), C(ACC + 0 * i, (0.35f + 0.65f * g_env[i]) * a), 5.f);
        }
    } else if (ci == 6) {
        float cw = 360.f * U(), ch = 54.f * U(); glass(x, y, x + cw, y + ch, a);
        snprintf(b, sizeof b, "%.0f fps   %u draws", g_fpsShown, g_st.draws); txt(fTitle, 24, x + 18 * U(), y + 10 * U(), C(ACC, a), b);
    }
}

/* ------------------------------------------------------------------ chapter overlay: title card, info card, live widget */
static void draw_chapter(int ci, float t) {
    const Chapter& c = kCh[ci]; ImDrawList* dl = ImGui::GetForegroundDrawList(); (void)dl;
    float p2 = sstep((t - 3.2f) / 0.9f), in = eout(t / 0.7f);
    float sz = 64.f + (30.f - 64.f) * p2;
    float x = 70.f * U(), y = ((float)g_h * 0.40f) + ((float)g_h * 0.095f - (float)g_h * 0.40f) * p2;
    char b[64]; snprintf(b, sizeof b, "%02d / %02d", ci + 1, kNumCh);
    txt(fBody, 18, x + (1.f - in) * -40.f * U(), y - 30 * U() * (1.f - p2 * 0.6f), C(ACC, in), b);
    txt(fTitle, sz, x + (1.f - in) * -80.f * U(), y, C(255, 255, 255, in), T((std::string(c.id) + ".name").c_str()));
    float ay = y + (sz + 8.f) * U() * 1.0f * 0.85f;
    txt(fBody, 16, x, ay, C(ACC, in * 0.95f), c.api);
    dl->AddRectFilled(ImVec2(x, ay + 24 * U()), ImVec2(x + (tw(fBody, 16, c.api)) * eout((t - 0.3f) / 1.2f), ay + 26 * U()), C(ACC, 0.7f));
    /* info card */
    float ca = eout((t - 0.9f) / 0.8f);
    if (ca > 0.01f) {
        float pw = 390.f * U(), px = (float)g_w - pw - 36.f * U() + (1.f - ca) * 70.f * U(), py = (float)g_h * 0.17f, ix = px + 20 * U(), iw = pw - 40 * U(), yy = py + 16 * U();
        /* measure first: draw the panel after we know the height */
        const Row* live = nullptr; Row lr;
        if (ci == 1) { lr = c.rows[0]; lr.a = g_liveA; lr.b = g_liveB; live = &lr; }
        float hWhat = fBody->CalcTextSizeA(16.f * U(), FLT_MAX, iw, T((std::string(c.id) + ".what").c_str())).y;
        float rowsH = 0.f; for (int i = 0; i < c.nrows; i++) rowsH += (c.rows[i].atxt && !c.rows[i].btxt ? 58.f : 88.f) * U();
        float ph = 16 * U() + 18 * U() + hWhat + 14 * U() + 18 * U() + 30 * U() + 12 * U() + 18 * U() + rowsH + 14 * U();
        glass(px, py, px + pw, py + ph, ca);
        txt(fBody, 12, ix, yy, C(ACC, ca), T("card.what")); yy += 18 * U();
        yy += wrap_txt(fBody, 16, ix, yy, iw, C(255, 255, 255, 0.92f * ca), T((std::string(c.id) + ".what").c_str())) + 14 * U();
        txt(fBody, 12, ix, yy, C(ACC, ca), T("card.lang")); yy += 18 * U();
        float cx = ix; char tok[24]; const char* s = c.langs;
        while (*s) {
            int n = 0; while (*s && *s != '|' && n < 23) tok[n++] = *s++; tok[n] = 0; if (*s == '|') s++;
            float w = tw(fBody, 14, tok) + 18 * U();
            dl->AddRectFilled(ImVec2(cx, yy), ImVec2(cx + w, yy + 24 * U()), C(ACC, 0.16f * ca), 12 * U()); dl->AddRect(ImVec2(cx, yy), ImVec2(cx + w, yy + 24 * U()), C(ACC, 0.6f * ca), 12 * U());
            txt(fBody, 14, cx + 9 * U(), yy + 3 * U(), C(255, 255, 255, ca), tok, 0, false); cx += w + 8 * U();
        }
        yy += 38 * U();
        txt(fBody, 12, ix, yy, C(GOLD, ca), T(ci == 1 ? "card.live" : "card.meas")); yy += 18 * U();
        if (ci == 4) { txt(fTitle, 20, ix, yy + 2 * U(), C(RED, ca), T("c4.b")); txt(fBody, 20, ix + tw(fTitle, 20, T("c4.b")) + 14 * U(), yy + 4 * U(), C(255, 255, 255, ca), ">"); txt(fTitle, 20, ix + tw(fTitle, 20, T("c4.b")) + 40 * U(), yy + 2 * U(), C(GRN, ca), T("c4.a")); txt(fBody, 15, ix, yy + 34 * U(), C(255, 255, 255, 0.85f * ca), T("c4.r0")); }
        else draw_rows(c, ix, yy, iw, t - 1.0f, live);
    }
    draw_live(ci, t);
}

/* ------------------------------------------------------------------ HUD */
static void draw_hud() {
    if (g_overlay == 0) return;
    ImDrawList* dl = ImGui::GetForegroundDrawList(); float w = 270.f * U(), x = (float)g_w - w - 22.f * U(), y = (g_mode == M_INTRO || g_mode == M_CHAPTER ? 0.075f : 0.03f) * (float)g_h + 6 * U();
    char b[160];
    if (g_overlay == 1) {
        x = (float)g_w - 190.f * U(); glass(x, y, x + 168 * U(), y + 46 * U(), 0.9f, 0.5f);
        snprintf(b, sizeof b, "%.0f", g_fpsShown); txt(fBig, 34, x + 14 * U(), y + 2 * U(), C(255, 255, 255), b); txt(fBody, 12, x + 14 * U() + tw(fBig, 34, b) + 6 * U(), y + 18 * U(), C(ACC), T("hud.fps"));
        return;
    }
    float h = 218.f * U(); y = (float)g_h - h - 24.f * U(); glass(x, y, x + w, y + h, 0.95f);
    snprintf(b, sizeof b, "%.0f", g_fpsShown); txt(fBig, 48, x + 16 * U(), y + 6 * U(), C(255, 255, 255), b);
    txt(fBody, 13, x + 24 * U() + tw(fBig, 48, b), y + 30 * U(), C(ACC), T("hud.fps"));
    snprintf(b, sizeof b, "%s %.0f    %s %.1f ms    %s %.1f ms", T("hud.low"), g_low1, T("hud.frame"), g_ms, T("hud.cpu"), g_cpuMs); txt(fBody, 12, x + 16 * U(), y + 66 * U(), C(255, 255, 255, 0.9f), b);
    /* sparkline of the last frames, with the 60 fps line */
    float sx = x + 16 * U(), sy = y + 88 * U(), sw = w - 32 * U(), sh = 36 * U(); float guide = sy + sh - sh * (16.7f / 40.f);
    dl->AddLine(ImVec2(sx, guide), ImVec2(sx + sw, guide), C(GOLD, 0.35f), 1.f);
    ImVec2 pts[120]; for (int i = 0; i < 120; i++) { float v = g_spark[(g_sparkPos + i) % 120]; pts[i] = ImVec2(sx + sw * i / 119.f, sy + sh - sh * std::min(v, 40.f) / 40.f); }
    dl->AddPolyline(pts, 120, C(ACC, 0.95f), 0, 1.6f);
    snprintf(b, sizeof b, "%s %u (+%u)   %s %uk", T("hud.draws"), g_st.draws, g_st.shadow_draws, T("hud.tris"), g_st.triangles / 1000); txt(fBody, 12, x + 16 * U(), y + 132 * U(), C(255, 255, 255, 0.9f), b);
    snprintf(b, sizeof b, "%s %u / %u", T("hud.vis"), g_st.chunks_seen, g_st.chunks_total); txt(fBody, 12, x + 16 * U(), y + 150 * U(), C(255, 255, 255, 0.9f), b);
    snprintf(b, sizeof b, "%s %.0f MB   %s %.0f MB", T("hud.heap"), heap_bytes() / 1048576.0, T("hud.gpu"), gpu_bytes() / 1048576.0); txt(fBody, 12, x + 16 * U(), y + 168 * U(), C(255, 255, 255, 0.9f), b);
    snprintf(b, sizeof b, "%s %ux%u  %.0f%%   %s", T("hud.res"), g_st.render_width, g_st.render_height, g_scale * 100.f, T(g_docked ? "hud.docked" : "hud.hand")); txt(fBody, 12, x + 16 * U(), y + 188 * U(), C(ACC, 0.95f), b);
}

/* ------------------------------------------------------------------ intro, hub, benchmark, finale */
static void draw_logo(float t) {
    ImDrawList* dl = ImGui::GetForegroundDrawList(); float cx = (float)g_w * 0.5f, cy = (float)g_h * 0.42f, R = 84.f * U();
    float a = sat(t / 0.8f) * (1.f - sstep((t - 5.2f) / 1.0f)); if (a <= 0.f) return;
    /* hexagon drawn progressively, two counter-rotating arc rings, a light sweep */
    float prog = eout(t / 2.2f); const int N = 6; ImVec2 hp[N + 1];
    for (int i = 0; i <= N; i++) { float an = (float)i * 6.2831853f / N - 1.5708f; hp[i] = ImVec2(cx + cosf(an) * R, cy + sinf(an) * R); }
    int full = (int)(prog * N); float part = prog * N - (float)full;
    for (int i = 0; i < N; i++) {
        if (i < full) dl->AddLine(hp[i], hp[i + 1], C(ACC, a), 3.f * U());
        else if (i == full) dl->AddLine(hp[i], ImVec2(hp[i].x + (hp[i + 1].x - hp[i].x) * part, hp[i].y + (hp[i + 1].y - hp[i].y) * part), C(ACC, a), 3.f * U());
    }
    for (int k = 0; k < 2; k++) {
        float rr = R * (1.25f + 0.2f * k), rot = t * (k ? -0.7f : 0.9f);
        for (int s = 0; s < 3; s++) { float a0 = rot + s * 2.0944f, a1 = a0 + 0.9f * eout((t - 0.5f) / 1.5f); dl->PathArcTo(ImVec2(cx, cy), rr, a0, a1, 24); dl->PathStroke(C(k ? GOLD : ACC, 0.8f * a), 0, 2.2f * U()); }
    }
    float ip = eout((t - 1.2f) / 1.2f); float ir = R * 0.42f * ip;
    dl->AddTriangleFilled(ImVec2(cx - ir * 0.9f, cy + ir), ImVec2(cx, cy - ir), ImVec2(cx + ir * 0.9f, cy + ir), C(ACC, 0.25f * a));
    dl->AddTriangle(ImVec2(cx - ir * 0.9f, cy + ir), ImVec2(cx, cy - ir), ImVec2(cx + ir * 0.9f, cy + ir), C(255, 255, 255, 0.9f * a), 2.5f * U());
    const char* name = "NEXVYN"; float track = 1.f + 0.22f * (1.f - eout((t - 1.6f) / 2.4f)); float total = 0.f; char one[2] = {0, 0};
    for (const char* s = name; *s; s++) { one[0] = *s; total += tw(fBig, 76, one) * track; }
    float nx = cx - total * 0.5f, ny = cy + R * 1.6f; int i = 0;
    for (const char* s = name; *s; s++, i++) { one[0] = *s; float la = sstep((t - 1.8f - 0.14f * i) / 0.5f); txt(fBig, 76, nx, ny + (1.f - la) * 14.f * U(), C(255, 255, 255, la * a), one, 0, true); nx += tw(fBig, 76, one) * track; }
    float sw = sstep((t - 2.4f) / 1.6f);
    if (sw > 0.f && sw < 1.f) {
        float sxp = cx - total * 0.6f + total * 1.2f * sw, hw = 46.f * U();
        dl->AddRectFilledMultiColor(ImVec2(sxp - hw, ny), ImVec2(sxp, ny + 84 * U()), C(255, 255, 255, 0), C(255, 255, 255, 0.22f * a), C(255, 255, 255, 0.22f * a), C(255, 255, 255, 0));
        dl->AddRectFilledMultiColor(ImVec2(sxp, ny), ImVec2(sxp + hw, ny + 84 * U()), C(255, 255, 255, 0.22f * a), C(255, 255, 255, 0), C(255, 255, 255, 0), C(255, 255, 255, 0.22f * a));
    }
}
static void draw_intro(float t) {
    draw_logo(t);
    bars_letterbox(sstep((t - 4.5f) / 1.0f));
    if (t > 12.f && t < 24.5f) {  /* title card */
        float a = sstep((t - 12.5f) / 1.0f) * (1.f - sstep((t - 23.f) / 1.2f)); float cx = (float)g_w * 0.5f, cy = (float)g_h * 0.40f;
        ImGui::GetForegroundDrawList()->AddRectFilledMultiColor(ImVec2(0, cy - 90 * U()), ImVec2((float)g_w, cy + 60 * U()), C(0, 0, 0, 0), C(0, 0, 0, 0), C(0, 0, 0, 0.62f * a), C(0, 0, 0, 0.62f * a));
        ImGui::GetForegroundDrawList()->AddRectFilled(ImVec2(0, cy + 60 * U()), ImVec2((float)g_w, cy + 150 * U()), C(0, 0, 0, 0.62f * a));
        ImGui::GetForegroundDrawList()->AddRectFilledMultiColor(ImVec2(0, cy + 150 * U()), ImVec2((float)g_w, cy + 220 * U()), C(0, 0, 0, 0.62f * a), C(0, 0, 0, 0.62f * a), C(0, 0, 0, 0), C(0, 0, 0, 0));
        txt(fBody, 20, cx, cy - 46 * U(), C(ACC, a), "N E X V Y N   O S", 0.5f);
        txt(fBig, 84, cx, cy - 20 * U(), C(255, 255, 255, a), T("ui.sub"), 0.5f);
        txt(fTitle, 40, cx, cy + 86 * U(), C(GOLD, a), T("ui.tag"), 0.5f);
        float lw = 260.f * U() * eout((t - 13.f) / 1.5f); ImGui::GetForegroundDrawList()->AddRectFilled(ImVec2(cx - lw, cy + 74 * U()), ImVec2(cx + lw, cy + 76 * U()), C(ACC, 0.8f * a));
    }
    if (t > 6.f) txt(fBody, 14, (float)g_w * 0.5f, (float)g_h * 0.925f, C(255, 255, 255, 0.55f + 0.25f * sinf(t * 3.f)), T("ui.skip"), 0.5f);
}
static const int kHubItems = 2 + kNumCh + 2;  /* tour, chapters, benchmark, scores, free */
static const char* hub_label(int i, char* b, size_t n) {
    if (i == 0) return T("hub.tour");
    if (i <= kNumCh) { snprintf(b, n, "%02d   %s", i, T((std::string(kCh[i - 1].id) + ".name").c_str())); return b; }
    if (i == kNumCh + 1) return T("hub.bench");
    if (i == kNumCh + 2) return T("hub.scores");
    return T("hub.free");
}
static float g_rowY[16];
static void draw_hub(float t) {
    ImDrawList* dl = ImGui::GetForegroundDrawList(); (void)dl; vignette(1.f);
    float x = 56.f * U(); float a = eout(t / 0.8f);
    txt(fBig, 54, x, 36 * U(), C(255, 255, 255, a), "NEXVYN"); txt(fTitle, 26, x, 98 * U(), C(ACC, a), T("hub.title"));
    float y = 146.f * U(), rh = 34.f * U(); char b[96];
    for (int i = 0; i < kHubItems; i++) {
        float ia = eout((t - 0.15f - 0.04f * i) / 0.5f); bool sel = i == g_sel; g_rowY[i] = y;
        if (sel) { float pul = 0.75f + 0.25f * sinf(t * 5.f); dl->AddRectFilled(ImVec2(x - 12 * U(), y - 2 * U()), ImVec2(x + 360 * U(), y + rh - 4 * U()), C(ACC, 0.18f * ia), 8 * U()); dl->AddRectFilled(ImVec2(x - 12 * U(), y - 2 * U()), ImVec2(x - 8 * U(), y + rh - 4 * U()), C(ACC, pul * ia)); }
        const char* l = hub_label(i, b, sizeof b); bool sep = i == 0 || i == kNumCh || i == kNumCh + 2;
        txt(sel ? fTitle : fBody, sel ? 22 : 19, x + (sel ? 6 : 0) * U() + (1.f - ia) * -30.f * U(), y + (sel ? 0 : 3) * U(), sel ? C(255, 255, 255, ia) : C(255, 255, 255, 0.72f * ia), l);
        y += rh + (sep ? 8.f * U() : 0.f);
    }
    txt(fBody, 13, x, (float)g_h - 34 * U(), C(255, 255, 255, 0.6f * a), T("hub.hint"));
}
static void draw_bench(float t) {
    (void)t; ImDrawList* dl = ImGui::GetForegroundDrawList(); float cx = (float)g_w * 0.5f, y = (float)g_h * 0.09f;
    float pw = 520.f * U(); glass(cx - pw * 0.5f, y, cx + pw * 0.5f, y + 96 * U(), 0.95f);
    char b[96]; snprintf(b, sizeof b, "%s  %d / %d", T("b.title"), g_bstage + 1, kBenchTotal); txt(fBody, 14, cx, y + 10 * U(), C(ACC), b, 0.5f);
    txt(fTitle, 28, cx, y + 30 * U(), C(255, 255, 255), T(g_bstage < kStageCount ? kStages[g_bstage].key : "b.s4"), 0.5f);
    float p = g_bstage < kStageCount ? sat(g_bt / g_stageSecs) : (g_reloading ? 0.5f : 1.f);
    dl->AddRectFilled(ImVec2(cx - pw * 0.5f + 20 * U(), y + 76 * U()), ImVec2(cx + pw * 0.5f - 20 * U(), y + 82 * U()), C(255, 255, 255, 0.15f), 3.f);
    dl->AddRectFilled(ImVec2(cx - pw * 0.5f + 20 * U(), y + 76 * U()), ImVec2(cx - pw * 0.5f + 20 * U() + (pw - 40 * U()) * p, y + 82 * U()), C(ACC), 3.f);
}
static void draw_results(float t) {
    ImDrawList* dl = ImGui::GetForegroundDrawList(); vignette(0.8f); float cx = (float)g_w * 0.5f; float pw = 600.f * U(), ph = 400.f * U(), px = cx - pw * 0.5f, py = (float)g_h * 0.12f;
    glass(px, py, px + pw, py + ph, eout(t / 0.5f)); char b[96];
    txt(fBody, 14, cx, py + 14 * U(), C(ACC), T("b.title"), 0.5f);
    double shown = g_btotal * eout(t / 2.2f); snprintf(b, sizeof b, "%.0f", shown); txt(fBig, 68, cx, py + 30 * U(), C(GOLD), b, 0.5f); txt(fBody, 14, cx, py + 108 * U(), C(255, 255, 255, 0.8f), T("b.score"), 0.5f);
    float y = py + 140 * U(), mx = 1.f; for (int i = 0; i < kBenchTotal; i++) mx = std::max(mx, (float)g_bres[i].pts);
    for (int i = 0; i < kBenchTotal; i++) {
        float p = eout((t - 0.3f - 0.2f * i) / 0.9f); txt(fBody, 15, px + 24 * U(), y, C(255, 255, 255, 0.9f * p), T(i < kStageCount ? kStages[i].key : "b.s4"));
        float bx = px + 190 * U(), bw = pw - 190 * U() - 130 * U(); dl->AddRectFilled(ImVec2(bx, y + 4 * U()), ImVec2(bx + std::max(4.f, bw * (float)(g_bres[i].pts / mx) * p), y + 16 * U()), C(i == kStageCount ? GOLD : ACC, 0.9f), 6.f);
        if (i < kStageCount) snprintf(b, sizeof b, "%.0f fps  (1%% %.0f)", g_bres[i].fps * p, g_bres[i].low * p); else snprintf(b, sizeof b, "%.0f ms", g_loadMs * p);
        txt(fBody, 13, px + pw - 24 * U(), y + 1 * U(), C(255, 255, 255, 0.9f * p), b, 1.f); y += 36 * U();
    }
    if (t > 2.5f) { if (g_brank == 1) txt(fTitle, 22, cx, py + ph - 70 * U(), C(GRN), T("b.best"), 0.5f); else if (g_brank > 1) { char r[32]; snprintf(r, sizeof r, "#%d", g_brank); txt(fTitle, 22, cx, py + ph - 70 * U(), C(GRN), r, 0.5f); } }
    txt(fBody, 13, cx, py + ph - 36 * U(), C(255, 255, 255, 0.65f), T("b.saved"), 0.5f); txt(fBody, 14, cx, py + ph + 14 * U(), C(255, 255, 255, 0.8f), T("b.again"), 0.5f);
}
static void draw_scores(float t) {
    vignette(0.8f); float cx = (float)g_w * 0.5f, pw = 560.f * U(), ph = 440.f * U(), px = cx - pw * 0.5f, py = (float)g_h * 0.1f; glass(px, py, px + pw, py + ph, eout(t / 0.5f)); char b[96];
    txt(fTitle, 30, cx, py + 16 * U(), C(255, 255, 255), T("s.title"), 0.5f);
    if (g_scores.empty()) txt(fBody, 16, cx, py + 120 * U(), C(255, 255, 255, 0.8f), T("s.empty"), 0.5f);
    for (size_t i = 0; i < g_scores.size() && i < 10; i++) {
        float y = py + 70 * U() + i * 32 * U(), a = eout((t - 0.1f * i) / 0.5f); time_t tt = (time_t)g_scores[i].when; struct tm* tmv = gmtime(&tt);
        snprintf(b, sizeof b, "%zu", i + 1); txt(fBody, 17, px + 30 * U(), y, C(ACC, a), b);
        snprintf(b, sizeof b, "%d", g_scores[i].score); txt(fTitle, 22, px + 90 * U(), y - 3 * U(), i == 0 ? C(GOLD, a) : C(255, 255, 255, a), b);
        snprintf(b, sizeof b, "%04d-%02d-%02d   %s", tmv ? tmv->tm_year + 1900 : 0, tmv ? tmv->tm_mon + 1 : 0, tmv ? tmv->tm_mday : 0, T(g_scores[i].docked ? "hud.docked" : "hud.hand"));
        txt(fBody, 15, px + pw - 30 * U(), y, C(255, 255, 255, 0.8f * a), b, 1.f);
    }
    txt(fBody, 14, cx, py + ph + 14 * U(), C(255, 255, 255, 0.8f), T("s.back"), 0.5f);
}
static void draw_finale(float t) {
    vignette(0.9f); float cx = (float)g_w * 0.5f, pw = 700.f * U(), ph = 330.f * U(), px = cx - pw * 0.5f, py = (float)g_h * 0.13f; glass(px, py, px + pw, py + ph, eout(t / 0.6f));
    txt(fBig, 44, cx, py + 12 * U(), C(255, 255, 255), "NEXVYN", 0.5f); txt(fTitle, 24, cx, py + 66 * U(), C(ACC), T("f.title"), 0.5f);
    struct N { float v; const char* fmt; const char* key; } n[4] = {{6.f, "x%.0f", "f.n0"}, {50.f, "~%.0fx", "f.n1"}, {150.f, "~%.0fx", "f.n2"}, {13.f, "~%.0fx", "f.n3"}};
    for (int i = 0; i < 4; i++) {
        float p = eout((t - 0.4f - 0.25f * i) / 1.3f); float gx = px + 40 * U() + (i % 2) * (pw * 0.5f - 20 * U()), gy = py + 112 * U() + (i / 2) * 96 * U(); char b[32];
        snprintf(b, sizeof b, n[i].fmt, n[i].v * p); txt(fBig, 50, gx, gy, C(GOLD, p), b); txt(fBody, 15, gx, gy + 56 * U(), C(255, 255, 255, 0.85f * p), T(n[i].key));
    }
    char b[96]; if (!g_scores.empty()) { snprintf(b, sizeof b, "%s  %d", T("f.best"), g_scores[0].score); txt(fTitle, 20, cx, py + ph + 10 * U(), C(GRN), b, 0.5f); }
    txt(fBody, 15, cx, py + ph + 44 * U(), C(255, 255, 255, 0.85f), T("f.bench"), 0.5f); txt(fBody, 15, cx, py + ph + 66 * U(), C(255, 255, 255, 0.85f), T("f.menu"), 0.5f);
}

/* ------------------------------------------------------------------ flow */
static void go(Mode m);
static void start_chapter(int i, bool tour) {
    g_ch = i; g_tour = tour; g_mode = M_CHAPTER; g_mt = 0; g_fade = 1.f; g_scale = 1.f; g_noteIdx = -1; g_noteT = 0; g_shadowsOn = true; g_la_sum = g_lb_sum = 0; g_la_n = g_lb_n = 0; g_liveA = g_liveB = 0;
    for (float& e : g_env) e = 0; cue_chapter(); logf_("chapter %d (%s)", i, kCh[i].id);
}
static void scene_reload() {
    if (g_scene) ngfx_scene_free(g_dev, g_scene);
    g_scene = 0; g_done = false; g_geom = false; g_ss = ngfx_scene_status(); g_ss.size = sizeof g_ss; g_reloading = true; g_reloadT0 = nxn_time_ns();
}
static void bench_start() {
    g_mode = M_BENCH; g_mt = 0; g_bstage = 0; g_bt = 0; g_bms.clear(); g_bsum = 0; g_reloading = false; g_fade = 1.f; for (auto& r : g_bres) r = StageRes();
    logf_("benchmark start");
}
static void bench_finish() {
    g_btotal = 0; for (int i = 0; i < kBenchTotal; i++) g_btotal += g_bres[i].pts;
    ScoreRow r; r.score = (int)(g_btotal + 0.5); r.when = (long long)nxn_time_unix(); r.docked = g_docked ? 1 : 0; g_scores.push_back(r);
    std::sort(g_scores.begin(), g_scores.end(), [](const ScoreRow& a, const ScoreRow& b) { return a.score > b.score; }); if (g_scores.size() > 10) g_scores.resize(10);
    g_brank = 0; for (size_t i = 0; i < g_scores.size(); i++) if (g_scores[i].score == r.score && g_scores[i].when == r.when) { g_brank = (int)i + 1; break; }
    scores_save(); g_mode = M_RESULTS; g_mt = 0; g_scale = 1.f;
    logf_("benchmark done: score %d (rank %d)", r.score, g_brank);
    for (int i = 0; i < kStageCount; i++) logf_("  stage %d: %.1f fps, 1%% low %.1f, %d frames, %.0f pts", i, g_bres[i].fps, g_bres[i].low, g_bres[i].frames, g_bres[i].pts);
    logf_("  streaming: load %.0f ms, %.0f pts", g_loadMs, g_bres[kStageCount].pts);
    logf_("RESULT score=%d fail=0", r.score);
    {   /* score JSON next to the report: the console test run collects it (graphics_score.json) */
        std::string j = "{\"score\":" + std::to_string(r.score) + ",\"docked\":" + (g_docked ? "true" : "false") + ",\"load_ms\":" + std::to_string((int)g_loadMs) + ",\"stages\":[";
        for (int i = 0; i < kStageCount; i++) { char b[160]; snprintf(b, sizeof b, "%s{\"fps\":%.1f,\"low\":%.1f,\"frames\":%d,\"pts\":%.0f}", i ? "," : "", g_bres[i].fps, g_bres[i].low, g_bres[i].frames, g_bres[i].pts); j += b; }
        j += "]}\n"; nxn_fs_write(NXN_DIR_DATA, "graphics_score.json", j.data(), j.size());
    }
}
static void go(Mode m) { g_mode = m; g_mt = 0; g_fade = 1.f; g_scale = 1.f; if (m == M_HUB) g_tour = false; }
static void activate(int i) {
    cue_pick();
    if (i == 0) start_chapter(0, true);
    else if (i <= kNumCh) start_chapter(i - 1, false);
    else if (i == kNumCh + 1) bench_start();
    else if (i == kNumCh + 2) go(M_SCORES);
    else go(M_FREE);
}

static void screenshot(const char* name) {
    size_t rowb = ((size_t)g_w * 3 + 3) & ~(size_t)3, sz = rowb * g_h; std::vector<uint8_t> buf(54 + sz, 0);
    uint8_t* h = buf.data(); h[0] = 'B'; h[1] = 'M';
    uint32_t fs = (uint32_t)buf.size(), off = 54, ihs = 40, w = g_w, hh = g_h; uint16_t pl = 1, bpp = 24;
    memcpy(h + 2, &fs, 4); memcpy(h + 10, &off, 4); memcpy(h + 14, &ihs, 4); memcpy(h + 18, &w, 4); memcpy(h + 22, &hh, 4); memcpy(h + 26, &pl, 2); memcpy(h + 28, &bpp, 2);
    glBindFramebuffer(GL_FRAMEBUFFER, 0); glPixelStorei(GL_PACK_ALIGNMENT, 4); glReadBuffer(GL_BACK);
    glReadPixels(0, 0, (GLsizei)g_w, (GLsizei)g_h, 0x80E0 /* GL_BGR */, GL_UNSIGNED_BYTE, h + 54);
    nxn_fs_write(NXN_DIR_DATA, name, buf.data(), buf.size());
}
static const ImGuiKey kPadKeys[] = {ImGuiKey_GamepadDpadLeft, ImGuiKey_GamepadDpadRight, ImGuiKey_GamepadDpadUp, ImGuiKey_GamepadDpadDown};
static const uint64_t kPadBits[] = {NXN_BTN_LEFT, NXN_BTN_RIGHT, NXN_BTN_UP, NXN_BTN_DOWN};
struct Cmd { float t; std::string c, a; bool done; };

/* ------------------------------------------------------------------ main loop */
static int app_main(int, char**) {
    nxn_caps_get(&g_caps);
    char sb[1500]; size_t got = 0; std::vector<Cmd> script; bool scripted = nxn_fs_read(NXN_DIR_DATA, "script", sb, sizeof sb - 1, &got) == NXN_OK;
    if (scripted) { sb[got] = 0; for (char* l = strtok(sb, "\n;"); l; l = strtok(NULL, "\n;")) { float t; char c[24] = "", a[48] = ""; if (sscanf(l, "%f %23s %47s", &t, c, a) >= 2) script.push_back({t, c, a, false}); } }
    nxn_display_params dp = NXN_STRUCT_INIT(nxn_display_params); dp.flags = NXN_DISPLAY_NO_VSYNC;  /* no frame cap: the HUD shows what the hardware reaches */
    if (nxn_display_open(&dp, &g_disp) != NXN_OK) { nxn_request_return(NXN_RETURN_ERROR, 1, "OpenGL 4.3 is not available"); return 1; }
    gladLoadGLLoader((GLADloadproc)nxn_display_proc);
    nxn_display_size(g_disp, &g_w, &g_h); if (!g_w || !g_h) { g_w = 1280; g_h = 720; } g_docked = g_w >= 1900;
    if (ngfx_device_create(NULL, &g_dev) != NGFX_OK) { nxn_request_return(NXN_RETURN_ERROR, 1, ngfx_native_error()); return 1; }
    logf_("graphics demo: gl %s | %s | surface %ux%u | no vsync", (const char*)glGetString(GL_VERSION), (const char*)glGetString(GL_RENDERER), g_w, g_h);
    scores_load();

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

    uint64_t appT0 = nxn_time_ns(), last = appT0, lastFps = appT0, liveT = appT0, readyT = 0; g_loadStart = appT0;
    int fpsFrames = 0, liveN = 0, liveSlow = 0, slowRun = 0, fastRun = 0, raiseWait = 600, frameNo = 0; double liveSum = 0, liveWorst = 0; bool raised = false;
    float touchPrev = 0; bool touchWas = false;

    while (!nxn_should_quit()) {
        uint64_t now = nxn_time_ns(); float dt = (float)(now - last) / 1e9f; last = now; if (dt > 0.25f) dt = 0.25f; frameNo++;
        double frameMs = dt * 1000.0; g_ms = g_ms * 0.92 + frameMs * 0.08; fpsFrames++;
        g_ring[g_ringPos] = (float)frameMs; g_ringPos = (g_ringPos + 1) % (int)g_ring.size(); g_spark[g_sparkPos] = (float)frameMs; g_sparkPos = (g_sparkPos + 1) % 120;
        if (now - lastFps >= 400000000ull) { g_fps = fpsFrames * 1e9 / (double)(now - lastFps); fpsFrames = 0; lastFps = now; }
        g_fpsShown += (g_fps - g_fpsShown) * std::min(1.f, dt * 8.f);
        if (frameNo % 30 == 0) { std::vector<float> c = g_ring; size_t k = (size_t)(c.size() * 0.99); std::nth_element(c.begin(), c.begin() + k, c.end()); g_low1 = 1000.0 / std::max(c[k], 0.1f); }

        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {
            if (ev.type == NXN_EVENT_RESIZE && ev.width && ev.height) { nxn_display_resize(g_disp, ev.width, ev.height); nxn_display_size(g_disp, &g_w, &g_h); g_docked = ev.docked != 0; }
            if (ev.type == NXN_EVENT_DOCK) g_docked = ev.docked != 0;
            ev.size = sizeof ev;
        }
        nxn_input_poll(&g_in);
        uint64_t pr = g_in.pressed;
        /* touch: a tap acts as A (menu rows are picked by position) */
        bool tapRow = false; int tapIdx = -1;
        if (g_in.touch_count > 0) { if (!touchWas) { nxn_touch tc = NXN_STRUCT_INIT(nxn_touch); if (nxn_input_touch(0, &tc) == NXN_OK) { touchPrev = tc.y * (float)g_h / 720.f; tapRow = true; if (g_mode == M_HUB) for (int i = 0; i < kHubItems; i++) if (touchPrev >= g_rowY[i] - 4 && touchPrev < g_rowY[i] + 36.f * U()) tapIdx = i; if (g_mode != M_HUB) pr |= NXN_BTN_A; } } touchWas = true; } else touchWas = false;
        float sdt = dt * g_tscale;

        if (!g_ready) {
            int p = ngfx_device_prepare(g_dev, &g_prepDone, &g_prepTotal);
            if (p < 0) { nxn_request_return(NXN_RETURN_ERROR, 1, ngfx_native_error()); break; }
            g_ready = p == 1;
        }
        if (!g_scene && !g_ss.failed && (!g_done || g_reloading)) {
            char sc[512], tx[512]; nxn_fs_path(NXN_DIR_BUNDLE, "data/town.nxsc", sc, sizeof sc); nxn_fs_path(NXN_DIR_BUNDLE, "data/town.nxtx", tx, sizeof tx);
            g_ss.size = sizeof g_ss; g_info.size = sizeof g_info; ngfx_scene_desc d = {sizeof d, sc, tx, 0u};
            if (ngfx_scene_load(g_dev, &d, &g_scene) != NGFX_OK) { g_ss.failed = 1; snprintf(g_ss.error, sizeof g_ss.error, "%s", ngfx_native_error()); }
            if (!g_reloading) g_loadStart = now;
        }
        if (g_scene && !g_done && !g_ss.failed && g_ready) {
            ngfx_scene_step(g_dev, g_scene, 24000000ull, &g_ss);
            if (g_ss.geometry_ready && !g_geom) { g_geom = true; ngfx_scene_info_get(g_dev, g_scene, &g_info); }
            if (g_ss.ready) {
                g_done = true; g_loadMs = (now - (g_reloading ? g_reloadT0 : g_loadStart)) / 1e6; logf_("town ready: %.0f ms%s, heap %.0f MB", g_loadMs, g_reloading ? " (reload)" : " (with shaders)", heap_bytes() / 1048576.0);
                if (g_reloading) { g_reloading = false; if (g_mode == M_BENCH) { g_bres[kStageCount].pts = 100000.0 / std::max(g_loadMs, 50.0); g_bres[kStageCount].fps = 0; bench_finish(); } }
                else if (!readyT) readyT = now;
            }
        }
        bool playing = g_ready && g_done;

        if (playing) {
            float st = readyT ? (float)(now - readyT) / 1e9f * 1.f : 0.f;
            /* test script */
            for (auto& c : script) {
                if (c.done || st < c.t) continue; c.done = true;
                if (c.c == "shot") { g_shotPending = true; g_shotName = c.a + ".bmp"; }
                else if (c.c == "ch") start_chapter(atoi(c.a.c_str()), false);
                else if (c.c == "intro") { go(M_INTRO); g_introSnd = 0; }
                else if (c.c == "hub") go(M_HUB);
                else if (c.c == "free") go(M_FREE);
                else if (c.c == "finale") go(M_FINALE);
                else if (c.c == "bench") { bench_start(); g_bscripted = true; if (!c.a.empty()) g_stageSecs = (float)atof(c.a.c_str()); }
                else if (c.c == "scores") go(M_SCORES);
                else if (c.c == "speed") g_tscale = (float)atof(c.a.c_str());
                else if (c.c == "key") { pr |= c.a == "A" ? NXN_BTN_A : c.a == "B" ? NXN_BTN_B : c.a == "Y" ? NXN_BTN_Y : c.a == "UP" ? NXN_BTN_UP : c.a == "DOWN" ? NXN_BTN_DOWN : NXN_BTN_MINUS; }
                else if (c.c == "quit") { report_write(); nxn_request_return(NXN_RETURN_NORMAL, 7, NULL); }
            }
            if (pr & NXN_BTN_MINUS) g_overlay = (g_overlay + 1) % 3;
            g_mt += sdt; if (g_fade > 0.f) g_fade = std::max(0.f, g_fade - dt / 0.7f);
            bool anyBtn = (pr & (NXN_BTN_A | NXN_BTN_B | NXN_BTN_X | NXN_BTN_Y | NXN_BTN_L | NXN_BTN_R | NXN_BTN_ZL | NXN_BTN_ZR | NXN_BTN_PLUS)) != 0;
            switch (g_mode) {
            case M_INTRO:
                cam_path(8.f + g_mt * 0.7f, 52.f + std::min(g_mt, 20.f) * 0.5f);
                while (g_introSnd < (int)(sizeof kIntroSnd / sizeof kIntroSnd[0]) && kIntroSnd[g_introSnd].t <= g_mt) { const Snd& s = kIntroSnd[g_introSnd++]; tone(s.f, s.d, s.v, s.w); }
                if (anyBtn || g_mt > 25.f) { nxn_sfx_stop_all(); go(M_HUB); }
                break;
            case M_HUB:
                cam_path(20.f + g_mt * 0.25f, 55.f);
                if ((pr & NXN_BTN_DOWN) || (pr & NXN_BTN_UP)) { g_sel = (g_sel + ((pr & NXN_BTN_DOWN) ? 1 : kHubItems - 1)) % kHubItems; cue_move(); }
                if (tapIdx >= 0) { g_sel = tapIdx; activate(g_sel); } else if (pr & NXN_BTN_A) activate(g_sel);
                break;
            case M_CHAPTER: {
                const Chapter& c = kCh[g_ch]; cam_path(c.cam0 + g_mt * c.rate, c.fov + 4.f * sinf(g_mt * 0.5f));
                if (g_ch == 0) g_shadowsOn = ((int)(g_mt / 3.f) % 2) == 0 || g_mt < 3.f;
                if (g_ch == 1) {  /* 100% -> 60% -> 100%: the fps of each plateau is measured live */
                    float s = g_mt < 3.f ? 1.f : g_mt < 6.f ? 1.f - 0.4f * sstep((g_mt - 3.f) / 2.5f) : g_mt < 9.f ? 0.6f : 0.6f + 0.4f * sstep((g_mt - 9.f) / 2.5f); g_scale = s;
                    if (g_mt > 1.5f && g_mt < 3.f) { g_la_sum += (float)(1000.0 / std::max(frameMs, 0.1)); g_la_n++; g_liveA = g_la_sum / g_la_n; }
                    if (g_mt > 7.f && g_mt < 9.f) { g_lb_sum += (float)(1000.0 / std::max(frameMs, 0.1)); g_lb_n++; g_liveB = g_lb_sum / g_lb_n; }
                }
                if (g_ch == 5) {
                    static const float sc[8] = {261.6f, 293.7f, 329.6f, 392.f, 440.f, 523.3f, 587.3f, 659.3f}; g_noteT += sdt;
                    if (g_noteT >= 0.25f) { g_noteT = 0; g_noteIdx = (g_noteIdx + 1) % 12; int n = (g_noteIdx * 3 + (g_noteIdx / 4)) % 8; tone(sc[n], 0.4f, 0.12f, 3); g_env[g_noteIdx] = 1.f; }
                    for (float& e : g_env) e = std::max(0.f, e - sdt * 1.6f);
                }
                if (pr & NXN_BTN_B) go(M_HUB);
                else if ((pr & NXN_BTN_A) && g_tour && g_ch + 1 < kNumCh) start_chapter(g_ch + 1, true);
                else if (g_mt >= kChDur) { if (g_tour) { if (g_ch + 1 < kNumCh) start_chapter(g_ch + 1, true); else go(M_FINALE); } else go(M_HUB); }
                break; }
            case M_BENCH: {
                if (g_reloading) { g_mode = M_BENCH; cam_path(0.f, 60.f); break; }
                const Stage& s = kStages[std::min(g_bstage, kStageCount - 1)]; g_scale = s.scale; cam_path(s.cam0 + g_bt * s.rate, s.fov);
                g_bt += dt;  /* real time: the pass length is wall time */
                if (g_bt > kWarm) { g_bms.push_back((float)frameMs); g_bsum += frameMs; }
                if (g_bt >= g_stageSecs) {
                    StageRes& r = g_bres[g_bstage]; r.frames = (int)g_bms.size(); r.fps = r.frames * 1000.0 / std::max(g_bsum, 1.0);
                    std::vector<float> c = g_bms; size_t k = (size_t)(c.size() * 0.99); if (k >= c.size()) k = c.size() - 1; if (!c.empty()) { std::nth_element(c.begin(), c.begin() + k, c.end()); r.low = 1000.0 / std::max(c[k], 0.1f); }
                    r.pts = r.fps; g_bstage++; g_bt = 0; g_bms.clear(); g_bsum = 0;
                    if (g_bstage >= kStageCount) { g_scale = 1.f; scene_reload(); }
                }
                if (pr & NXN_BTN_B) go(M_HUB);
                break; }
            case M_RESULTS: cam_path(44.f + g_mt * 0.2f, 55.f); if (g_bscripted && g_mt > 4.f) pr |= NXN_BTN_A; /* scripted run: leave by itself */ if (pr & NXN_BTN_Y) bench_start(); else if (pr & (NXN_BTN_A | NXN_BTN_B)) { if (g_bscripted) { report_write(); nxn_request_return(NXN_RETURN_NORMAL, 7, NULL); } go(M_HUB); } break;
            case M_SCORES: cam_path(30.f + g_mt * 0.2f, 55.f); if (pr & (NXN_BTN_A | NXN_BTN_B)) go(M_HUB); break;
            case M_FINALE: cam_path(50.f + g_mt * 0.25f, 55.f); if (pr & NXN_BTN_A) bench_start(); else if (pr & NXN_BTN_B) go(M_HUB); break;
            case M_FREE: {
                float speed = 8.f * ((g_in.buttons & (NXN_BTN_LSTICK | NXN_BTN_X)) ? 4.f : 1.f);
                V3 f = cam_fwd(g_cam), fl = norm(V3{f.x, 0, f.z}), rt = norm(cross(f, V3{0, 1, 0}));
                g_cam.pos = g_cam.pos + fl * (g_in.ly * speed * dt) + rt * (g_in.lx * speed * dt);
                if (g_in.buttons & NXN_BTN_ZR) g_cam.pos.y += speed * 0.6f * dt;
                if (g_in.buttons & NXN_BTN_ZL) g_cam.pos.y -= speed * 0.6f * dt;
                g_cam.yaw += g_in.rx * 2.2f * dt; g_cam.pitch = std::max(-1.5f, std::min(1.5f, g_cam.pitch + g_in.ry * 1.6f * dt));
                if (pr & NXN_BTN_B) go(M_HUB);
                break; }
            }
            /* floor guard: the scale drops only when the frame rate falls below 60, and tries to come back later (waits longer after each failed try) */
            bool guard = (g_mode != M_BENCH) && !(g_mode == M_CHAPTER && g_ch == 1);
            if (guard && g_mt > 1.5f) {
                if (g_ms > 17.2) { fastRun = 0; if (++slowRun >= 12 && g_scale > 0.601f) { g_scale = std::max(0.6f, g_scale - 0.05f); slowRun = 0; if (raised) raiseWait = std::min(raiseWait * 2, 7200); raised = false; } }
                else { slowRun = 0; if (g_ms < 14.0 && ++fastRun >= raiseWait && g_scale < 0.999f) { g_scale = std::min(1.f, g_scale + 0.05f); fastRun = 0; raised = true; } }
            }
        }
        if (frameMs > 0 && frameMs < 10000) { liveSum += frameMs; liveN++; if (frameMs > liveWorst) liveWorst = frameMs; if (frameMs > 50) liveSlow++; }
        if (now - liveT >= 10000000000ull) {
            char ln[300]; snprintf(ln, sizeof ln, "live: %.0f s, mode %d ch %d, %d frames, avg %.2f ms (%.1f fps), longest %.1f ms, %d over 50 ms, scale %.2f, 1%% low %.0f", (double)(now - appT0) / 1e9, (int)g_mode, g_ch, liveN,
                                   liveSum / std::max(liveN, 1), liveN * 1000.0 / std::max(liveSum, 1.0), liveWorst, liveSlow, g_scale, g_low1);
            report_write(ln); liveT = now; liveSum = liveWorst = 0; liveN = liveSlow = 0;
        }

        /* frame: UI feed, 3D, UI */
        io.DisplaySize = ImVec2((float)g_w, (float)g_h); io.DeltaTime = dt > 0.0001f ? dt : 0.0001f;
        for (int i = 0; i < 4; i++) io.AddKeyEvent(kPadKeys[i], (g_in.buttons & kPadBits[i]) != 0);
        uint64_t cpu0 = nxn_time_ns();
        ImGui_ImplOpenGL3_NewFrame(); ImGui::NewFrame();
        if (!playing) {
            ImDrawList* dl = ImGui::GetForegroundDrawList(); float frac = !g_ready ? (float)g_prepDone / (float)std::max(g_prepTotal, 1u) : g_ss.progress; char msg[200];
            if (g_ss.failed) snprintf(msg, sizeof msg, "%s: %s", T("ui.fail"), g_ss.error); else snprintf(msg, sizeof msg, "%s", T(g_ready ? "ui.loading" : "ui.shaders"));
            float w = std::min(520.f, (float)g_w - 40.f), x = ((float)g_w - w) * 0.5f, y = (float)g_h * 0.5f;
            txt(fBody, 18, (float)g_w * 0.5f, y - 34 * U(), C(255, 255, 255, 0.9f), msg, 0.5f);
            dl->AddRectFilled(ImVec2(x, y), ImVec2(x + w, y + 8), C(255, 255, 255, 0.15f), 4.f); dl->AddRectFilled(ImVec2(x, y), ImVec2(x + w * frac, y + 8), C(ACC), 4.f);
        } else {
            if (g_mode == M_INTRO) {  /* the black dims the scene only: the logo and the title card draw above it */
                float fi = 1.f - sstep((g_mt - 3.8f) / 3.2f); if (g_mt > 23.5f) fi = sstep((g_mt - 23.5f) / 1.5f);
                if (fi > 0.003f) ImGui::GetForegroundDrawList()->AddRectFilled(ImVec2(0, 0), ImVec2((float)g_w, (float)g_h), C(0, 0, 0, fi));
            }
            switch (g_mode) {
            case M_INTRO: draw_intro(g_mt); break;
            case M_HUB: draw_hub(g_mt); break;
            case M_CHAPTER: bars_letterbox(sstep(g_mt / 0.8f) * (1.f - sstep((g_mt - 3.5f) / 1.0f)) * 0.8f + 0.2f); draw_chapter(g_ch, g_mt); break;
            case M_BENCH: draw_bench(g_bt); break;
            case M_RESULTS: draw_results(g_mt); break;
            case M_SCORES: draw_scores(g_mt); break;
            case M_FINALE: draw_finale(g_mt); break;
            case M_FREE: txt(fBody, 14, (float)g_w * 0.5f, (float)g_h - 30 * U(), C(255, 255, 255, 0.7f), T("free.hint"), 0.5f); break;
            }
            if (g_mode != M_INTRO || g_mt > 8.f) draw_hud();
            float fa = g_fade; if (g_mode == M_CHAPTER) { fa = std::max(fa, sstep((g_mt - (kChDur - 0.5f)) / 0.5f)); if (g_mt < 0.7f) fa = std::max(fa, 1.f - sstep(g_mt / 0.7f)); }
            if (g_mode == M_INTRO) fa = 0.f;
            if (fa > 0.003f) ImGui::GetForegroundDrawList()->AddRectFilled(ImVec2(0, 0), ImVec2((float)g_w, (float)g_h), C(0, 0, 0, fa));
        }
        ImGui::Render();
        if (g_ready) {
            bool shadows = !(g_mode == M_CHAPTER && g_ch == 0 && !g_shadowsOn);
            ngfx_view view = {sizeof view, {g_cam.pos.x, g_cam.pos.y, g_cam.pos.z}, g_cam.yaw, g_cam.pitch, g_cam.fovDeg, g_w, g_h, g_scale, (shadows ? NGFX_VIEW_SHADOWS : 0u) | NGFX_VIEW_FXAA, 1.0f, 0};
            ngfx_render(g_dev, g_geom && g_done ? g_scene : 0, &view, &g_st);
        } else { glBindFramebuffer(GL_FRAMEBUFFER, 0); glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h); glClearColor(0.02f, 0.03f, 0.05f, 1); glClear(GL_COLOR_BUFFER_BIT); }
        glBindFramebuffer(GL_FRAMEBUFFER, 0); glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h); glDisable(GL_DEPTH_TEST);
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
        if (g_shotPending) { screenshot(g_shotName.c_str()); g_shotPending = false; }
        g_cpuMs = g_cpuMs * 0.9 + 0.1 * ((nxn_time_ns() - cpu0) / 1e6);
        nxn_display_swap(g_disp);
        (void)tapRow;
    }
    report_write();
    if (g_scene) ngfx_scene_free(g_dev, g_scene);
    ngfx_device_destroy(g_dev);
    ImGui_ImplOpenGL3_Shutdown(); ImGui::DestroyContext();
    nxn_display_close(g_disp);
    return 0;
}

int main(int argc, char** argv) { return nxn_run(argc, argv, app_main, NULL); }
