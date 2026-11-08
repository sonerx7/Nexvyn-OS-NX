// Native Tour: the new Native SDK 1.1 features in one app that looks like Nexvyn OS (see README.md).
//   3D       NexGFX native: a baked PBR scene with a shadow, orbiting camera, fps counter
//   Sound    the OS mixer (nxn_sfx_play, nxn_tone), procedural tones, the user's button mapping (nxn_input_action_buttons)
//   System   notification, clipboard, rumble, file / folder dialogs, save data backups, permissions
//   Runtime  thread_local on 3 threads, C++ exceptions, a .nxvlib loaded with nxn_lib_open (tour_rt.cpp)
//   About    SDK version, capability bits, memory
// The shell is the OS look: colours, sizes, fonts and icons come from the system tokens, pages are picked from the
// window menu (nxn_menu_*), or from a tab bar when the menu is not available. L / R switch pages as well.
// Every page checks what it needs (nxn_caps) and says "not available" instead of failing. Self-test: the app writes
// "TOUR selftest <page> OK|NA|FAIL ..." lines to its log; when <data>/autotest exists it also runs the calls that touch the
// user's things (clipboard, notification, save backup) once.
#include <glad/glad.h>
#include <float.h>
#include <malloc.h>
#include <math.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <atomic>
#include <nexvyn/nexvyn_native.h>
#include <nexvyn/nexgfx_native.h>

#include "imgui.h"
#include "imgui_impl_opengl3.h"
#include <nexvyn/nxn_imgui.h>
#include "tour.h"

enum Page { P_3D, P_SOUND, P_SYSTEM, P_RUNTIME, P_ABOUT, P_COUNT };
static const char* kPageKey[P_COUNT] = {"page.3d", "page.sound", "page.system", "page.runtime", "page.about"};
static const char* kPageName[P_COUNT] = {"3D", "Sound", "System", "Runtime", "About"};
static const char* kPageIcon[P_COUNT] = {"view_in_ar", "graphic_eq", "tune", "memory", "info"};

// ------------------------------------------------------------------ globals
static nxn_display* g_disp;
static uint32_t g_w = 1100, g_h = 680;
static nxn_ui_tokens g_tok = NXN_STRUCT_INIT(nxn_ui_tokens);
static nxn_input_state g_in = NXN_STRUCT_INIT(nxn_input_state);
static nxn_caps g_caps = NXN_STRUCT_INIT(nxn_caps);
static uint64_t g_start_ns;
static int g_page = P_3D;
static bool g_menu_on;
static bool g_autotest;
static bool g_autorotate = true, g_shadows = true, g_fxaa = true;
static int g_scale_idx = 3;
static float g_fps, g_ms;

static ImFont *f_body, *f_small, *f_title, *f_big, *f_mono;

static bool cap(uint64_t bit) { return (g_caps.features & bit) != 0; }
static const char* T(const char* key) { return nxn_tr(key); }

static void say(const char* fmt, ...) __attribute__((format(printf, 1, 2)));
static void say(const char* fmt, ...) {
    char b[400];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(b, sizeof b, fmt, ap);
    va_end(ap);
    nxn_log(NXN_LOG_INFO, "TOUR %s", b);
}

// ------------------------------------------------------------------ self-test book
static Res g_test[P_COUNT];
static char g_test_detail[P_COUNT][180];
static bool g_test_done_logged;

static void test_set(int page, Res r, const char* fmt, ...) __attribute__((format(printf, 3, 4)));
static void test_set(int page, Res r, const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(g_test_detail[page], sizeof g_test_detail[page], fmt, ap);
    va_end(ap);
    g_test[page] = r;
    say("selftest %s %s %s", kPageName[page], r == RES_OK ? "OK" : r == RES_NA ? "NA" : "FAIL", g_test_detail[page]);
    int ok = 0, na = 0, fail = 0, pending = 0;
    for (int i = 0; i < P_COUNT; i++) {
        ok += g_test[i] == RES_OK;
        na += g_test[i] == RES_NA;
        fail += g_test[i] == RES_FAIL;
        pending += g_test[i] == RES_PENDING;
    }
    if (!pending && !g_test_done_logged) {
        g_test_done_logged = true;
        say("selftest DONE ok=%d na=%d fail=%d", ok, na, fail);
    }
}

// ------------------------------------------------------------------ look: colours, fonts, icons
static ImVec4 col(uint32_t argb) {
    return ImVec4(((argb >> 16) & 255) / 255.f, ((argb >> 8) & 255) / 255.f, (argb & 255) / 255.f, ((argb >> 24) & 255) / 255.f);
}
static ImU32 colu(uint32_t argb, float alpha = 1.f) {
    ImVec4 c = col(argb);
    c.w *= alpha;
    return ImGui::ColorConvertFloat4ToU32(c);
}
static ImVec4 colo(uint32_t argb) { ImVec4 c = col(argb); c.w = 1.f; return c; }  // tokens such as content_bg are translucent: base layers need an opaque colour
// the system's control colours are translucent overlays made for its own layers: on a card the controls get a gray tint
static ImVec4 tintc(float a) { ImVec4 c = col(g_tok.text_tertiary); c.w = a; return c; }
static float sp(int step) { return g_tok.spacing[step < 0 ? 0 : step > 5 ? 5 : step]; }

static void apply_tokens() {
    nxn_ui_tokens_get(&g_tok);
    ImGuiStyle& s = ImGui::GetStyle();
    ImVec4* c = s.Colors;
    c[ImGuiCol_WindowBg] = colo(g_tok.window_bg);
    c[ImGuiCol_ChildBg] = colo(g_tok.content_bg);
    c[ImGuiCol_PopupBg] = colo(g_tok.content_bg);
    c[ImGuiCol_Text] = col(g_tok.text);
    c[ImGuiCol_TextDisabled] = col(g_tok.text_secondary);
    c[ImGuiCol_Border] = col(g_tok.separator);
    c[ImGuiCol_Separator] = col(g_tok.separator);
    c[ImGuiCol_Button] = tintc(0.11f);
    c[ImGuiCol_ButtonHovered] = tintc(0.20f);
    c[ImGuiCol_ButtonActive] = tintc(0.28f);
    c[ImGuiCol_FrameBg] = tintc(0.11f);
    c[ImGuiCol_FrameBgHovered] = tintc(0.17f);
    c[ImGuiCol_FrameBgActive] = tintc(0.24f);
    c[ImGuiCol_CheckMark] = col(g_tok.accent);
    c[ImGuiCol_SliderGrab] = col(g_tok.accent);
    c[ImGuiCol_SliderGrabActive] = col(g_tok.accent_hover);
    c[ImGuiCol_Header] = col(g_tok.selection);
    c[ImGuiCol_HeaderHovered] = col(g_tok.hover);
    c[ImGuiCol_PlotHistogram] = col(g_tok.accent);
    c[ImGuiCol_NavHighlight] = col(g_tok.accent);
    c[ImGuiCol_ScrollbarBg] = ImVec4(0, 0, 0, 0);
    c[ImGuiCol_ScrollbarGrab] = col(g_tok.border);
    s.FrameRounding = g_tok.corner_radius;
    s.GrabRounding = g_tok.corner_radius;
    s.WindowRounding = 0;
    s.ScrollbarSize = 8;
    s.ScrollbarRounding = 4;
    s.ItemSpacing = ImVec2(sp(2), sp(1));
    s.FramePadding = ImVec2(sp(2), sp(1) * 0.8f);
    s.PopupRounding = g_tok.corner_radius_row;
}

// system icon font: names are Material Icons names; a name the system does not know draws nothing
static const char* kIconNames[] = {"view_in_ar", "graphic_eq", "tune", "memory", "info", "check_circle", "cancel", "remove_circle",
                                   "play_arrow", "stop", "notifications", "content_copy", "content_paste", "vibration",
                                   "folder_open", "save", "backup", "restore", "delete", "lock", "speed", "music_note",
                                   "volume_up", "gamepad", "refresh", "shield", "videogame_asset", "layers", "widgets"};
static ImWchar g_icon_ranges[2 * (sizeof kIconNames / sizeof kIconNames[0]) + 1];

static const char* ic(const char* name) {
    static const char* keys[64];
    static uint32_t codes[64];
    static int n;
    static char buf[8][8];
    static int rot;
    uint32_t code = 0;
    int i = 0;
    for (; i < n; i++)
        if (keys[i] == name) break;
    if (i < n) code = codes[i];
    else {
        code = nxn_ui_icon_code(name);
        if (n < 64) keys[n] = name, codes[n++] = code;
    }
    char* b = buf[rot++ & 7];
    if (code == 0 || code > 0xFFFF) {
        b[0] = 0;
        return b;
    }
    b[0] = (char)(0xE0 | (code >> 12));
    b[1] = (char)(0x80 | ((code >> 6) & 0x3F));
    b[2] = (char)(0x80 | (code & 0x3F));
    b[3] = 0;
    return b;
}

static void setup_fonts() {
    ImGuiIO& io = ImGui::GetIO();
    // icon glyph ranges: one pair per name the system knows
    int r = 0;
    for (const char* name : kIconNames) {
        uint32_t c = nxn_ui_icon_code(name);
        if (c && c <= 0xFFFF) g_icon_ranges[r++] = (ImWchar)c, g_icon_ranges[r++] = (ImWchar)c;
    }
    g_icon_ranges[r] = 0;
    bool have_icons = r > 0;
    float k = g_tok.text_scale > 0.5f ? g_tok.text_scale : 1.f;
    // the system font with the glyph ranges of the user's language (nxn_imgui.h): "ı ğ ş İ", Cyrillic, ... are not "?"
    auto make = [&](nxn_ui_font id, float px, bool merge_icons, unsigned flags) -> ImFont* {
        return nxn_imgui_add_font(io.Fonts, id, floorf(px * k + 0.5f), flags, merge_icons && have_icons ? g_icon_ranges : NULL);
    };
    float body = g_tok.font_body > 1.f ? g_tok.font_body : 15.f;
    float small = g_tok.font_small > 1.f ? g_tok.font_small : 12.f;
    float large = g_tok.font_title > 1.f ? g_tok.font_title : 22.f;
    f_body = make(g_tok.bold_text ? NXN_UI_FONT_SEMIBOLD : NXN_UI_FONT_SANS, body, true, 0);
    f_small = make(NXN_UI_FONT_SANS, small, true, 0);
    f_title = make(NXN_UI_FONT_SEMIBOLD, large, true, 0);
    f_big = make(NXN_UI_FONT_BOLD, large * 1.7f, false, 0);
    f_mono = make(NXN_UI_FONT_MONO, small + 2.f, false, NXN_IMGUI_ALL_SCRIPTS | NXN_IMGUI_NO_CJK);  // paths and user text: any Latin-like script (CJK costs atlas memory)
    {   // build the atlas now to log what the language costs (ja / ko / zh merge the system's CJK font)
        uint64_t t0 = nxn_time_ns();
        io.Fonts->Build();
        size_t glyphs = 0;
        for (ImFont* f : io.Fonts->Fonts) glyphs += (size_t)f->Glyphs.Size;
        nxn_log(NXN_LOG_INFO, "TOUR fonts: lang %s, %zu glyphs, atlas %dx%d (%.1f MB as RGBA), built in %.0f ms", nxn_info_string(NXN_INFO_LANGUAGE),
                glyphs, io.Fonts->TexWidth, io.Fonts->TexHeight, io.Fonts->TexWidth * (double)io.Fonts->TexHeight * 4 / 1048576.0,
                (nxn_time_ns() - t0) / 1e6);
    }
}

// ------------------------------------------------------------------ small widgets
static void status_dot(Res r, const char* text) {
    ImDrawList* dl = ImGui::GetWindowDrawList();
    ImVec2 p = ImGui::GetCursorScreenPos();
    float fh = ImGui::GetTextLineHeight();
    uint32_t c = r == RES_OK ? g_tok.success : r == RES_FAIL ? g_tok.error : r == RES_PENDING ? g_tok.warning : g_tok.text_tertiary;
    dl->AddCircleFilled(ImVec2(p.x + fh * 0.4f, p.y + fh * 0.5f), fh * 0.24f, colu(c));
    ImGui::Dummy(ImVec2(fh * 0.95f, fh));
    ImGui::SameLine(0, 2);
    ImGui::TextUnformatted(text);
}
static const char* res_text(Res r) {
    return r == RES_OK ? T("res.ok") : r == RES_NA ? T("res.na") : r == RES_FAIL ? T("res.fail") : T("res.pending");
}

static void muted(const char* text) {
    ImGui::PushStyleColor(ImGuiCol_Text, col(g_tok.text_secondary));
    ImGui::TextWrapped("%s", text);
    ImGui::PopStyleColor();
}
static void unavailable(const char* what_key) {
    ImGui::PushStyleColor(ImGuiCol_Text, col(g_tok.text_secondary));
    ImGui::TextWrapped("%s  %s", ic("lock"), T(what_key));
    ImGui::PopStyleColor();
}

static bool card_begin(const char* id, const char* icon, const char* title, float w, float h = 0.f) {
    ImGui::PushStyleColor(ImGuiCol_ChildBg, colo(g_tok.content_bg));
    ImGui::PushStyleColor(ImGuiCol_Border, col(g_tok.separator));
    ImGui::PushStyleVar(ImGuiStyleVar_ChildRounding, g_tok.corner_radius_row + 4);
    ImGui::PushStyleVar(ImGuiStyleVar_ChildBorderSize, 1.f);
    ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(sp(3), sp(2) + 2));
    ImGuiChildFlags fl = ImGuiChildFlags_Borders | (h <= 0.f ? ImGuiChildFlags_AutoResizeY : 0);
    bool open = ImGui::BeginChild(id, ImVec2(w, h), fl, ImGuiWindowFlags_NoScrollbar | ImGuiWindowFlags_NoScrollWithMouse);
    ImGui::PopStyleVar(3);
    ImGui::PopStyleColor(2);
    if (open) {
        ImGui::PushFont(f_small);
        ImGui::PushStyleColor(ImGuiCol_Text, col(g_tok.accent));
        ImGui::TextUnformatted(icon);
        ImGui::PopStyleColor();
        ImGui::SameLine(0, sp(1));
        ImGui::PushStyleColor(ImGuiCol_Text, col(g_tok.text_secondary));
        ImGui::TextUnformatted(title);
        ImGui::PopStyleColor();
        ImGui::PopFont();
        ImGui::Dummy(ImVec2(0, 2));
    }
    return open;
}
static void card_end() { ImGui::EndChild(); }

static bool accent_button(const char* label, const ImVec2& size = ImVec2(0, 0)) {
    ImGui::PushStyleColor(ImGuiCol_Button, col(g_tok.accent));
    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, col(g_tok.accent_hover));
    ImGui::PushStyleColor(ImGuiCol_Text, col(g_tok.accent_text));
    bool r = ImGui::Button(label, size);
    ImGui::PopStyleColor(3);
    return r;
}
static bool selected_button(const char* label, bool selected, const ImVec2& size = ImVec2(0, 0)) {
    if (!selected) return ImGui::Button(label, size);
    ImGui::PushStyleColor(ImGuiCol_Button, col(g_tok.selection));
    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, col(g_tok.selection));
    ImGui::PushStyleColor(ImGuiCol_Text, col(g_tok.selection_text));
    bool r = ImGui::Button(label, size);
    ImGui::PopStyleColor(3);
    return r;
}

// ------------------------------------------------------------------ input
static void feed_imgui(float dt) {
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2((float)g_w, (float)g_h);
    io.DeltaTime = dt > 0.0001f ? dt : 0.0001f;
    io.AddKeyEvent(ImGuiKey_GamepadFaceDown, (g_in.actions & NXN_ACT_CONFIRM) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadDpadLeft, (g_in.buttons & NXN_BTN_LEFT) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadDpadRight, (g_in.buttons & NXN_BTN_RIGHT) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadDpadUp, (g_in.buttons & NXN_BTN_UP) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadDpadDown, (g_in.buttons & NXN_BTN_DOWN) != 0);
    {  // the left stick moves the focus too (ImGui's own dead zone and repeat; y of nxn_input_state is up-positive),
       // except on the 3D page, where it turns the camera
        float lx = g_page == P_3D ? 0.f : g_in.lx, ly = g_page == P_3D ? 0.f : g_in.ly;
        io.AddKeyAnalogEvent(ImGuiKey_GamepadLStickLeft, lx < -0.3f, lx < 0 ? -lx : 0.f);
        io.AddKeyAnalogEvent(ImGuiKey_GamepadLStickRight, lx > 0.3f, lx > 0 ? lx : 0.f);
        io.AddKeyAnalogEvent(ImGuiKey_GamepadLStickUp, ly > 0.3f, ly > 0 ? ly : 0.f);
        io.AddKeyAnalogEvent(ImGuiKey_GamepadLStickDown, ly < -0.3f, ly < 0 ? -ly : 0.f);
    }
    static int was_down;
    nxn_touch t = NXN_STRUCT_INIT(nxn_touch);
    if (g_in.touch_count > 0 && nxn_input_touch(0, &t) == NXN_OK) {
        io.AddMouseSourceEvent(ImGuiMouseSource_TouchScreen);
        io.AddMousePosEvent(t.x, t.y);  // in a window nxn_input_touch already reports pixels of the app surface (same space as DisplaySize): no scaling
        io.AddMouseButtonEvent(0, true);
        was_down = 1;
    } else if (was_down) {
        io.AddMouseButtonEvent(0, false);
        io.AddMousePosEvent(-FLT_MAX, -FLT_MAX);
        was_down = 0;
    }
}

// ------------------------------------------------------------------ the window menu
static void menu_update() {
    static const char* pk[P_COUNT] = {"menu.p3d", "menu.psound", "menu.psystem", "menu.pruntime", "menu.pabout"};
    static const char* sc[P_COUNT] = {"1", "2", "3", "4", "5"};
    nxn_menu_item pages[P_COUNT];
    for (int i = 0; i < P_COUNT; i++) {
        pages[i] = NXN_STRUCT_INIT(nxn_menu_item);
        pages[i].id = (uint32_t)(i + 1);
        pages[i].label = pk[i];
        pages[i].shortcut = sc[i];
        pages[i].flags = i == g_page ? NXN_MENU_CHECKED : 0;
    }
    nxn_menu_item view[3];
    for (int i = 0; i < 3; i++) view[i] = NXN_STRUCT_INIT(nxn_menu_item);
    view[0].id = 11, view[0].label = "menu.autorotate", view[0].flags = g_autorotate ? NXN_MENU_CHECKED : 0;
    view[1].id = 12, view[1].label = "menu.shadows", view[1].flags = g_shadows ? NXN_MENU_CHECKED : 0;
    view[2].id = 13, view[2].label = "menu.fxaa", view[2].flags = g_fxaa ? NXN_MENU_CHECKED : 0;
    nxn_menu_menu menus[2];
    menus[0] = NXN_STRUCT_INIT(nxn_menu_menu);
    menus[0].title = "menu.pages", menus[0].items = pages, menus[0].item_count = P_COUNT, menus[0].item_stride = sizeof(nxn_menu_item);
    menus[1] = NXN_STRUCT_INIT(nxn_menu_menu);
    menus[1].title = "menu.view", menus[1].items = view, menus[1].item_count = 3, menus[1].item_stride = sizeof(nxn_menu_item);
    nxn_menu_spec spec = NXN_STRUCT_INIT(nxn_menu_spec);
    spec.menus = menus, spec.menu_count = 2, spec.menu_stride = sizeof(nxn_menu_menu);
    nxn_result r = nxn_menu_set(&spec);
    static bool logged;
    if (!logged) {
        logged = true;
        g_menu_on = r == NXN_OK;
        say("window menu: %s (%d)", g_menu_on ? "on" : "off, tab bar instead", (int)r);
    }
}

static void goto_page(int p) {
    if (p < 0) p = P_COUNT - 1;
    if (p >= P_COUNT) p = 0;
    if (p == g_page) return;
    g_page = p;
    say("page -> %s", kPageName[p]);
    if (g_menu_on) menu_update();
}

// ------------------------------------------------------------------ 3D page (NexGFX native)
static ngfx_device* g_dev;
static ngfx_scene g_scene;
static ngfx_scene_status g_sst = {sizeof(ngfx_scene_status)};
static ngfx_scene_info g_sinfo = {sizeof(ngfx_scene_info)};
static ngfx_frame_stats g_fst = {sizeof(ngfx_frame_stats)};
static ngfx_device_caps g_dcaps = {sizeof(ngfx_device_caps)};
static bool g_gfx_ready, g_gfx_failed, g_scene_ready;
static uint32_t g_prep_done, g_prep_total = 5;
static char g_gfx_error[200];
static float g_orbit = 0.7f, g_elev = 0.30f, g_dist = 9.5f;
static uint64_t g_gfx_start;
static const float kScales[] = {0.5f, 0.67f, 0.75f, 1.0f};

static void gfx_fail(const char* what) {
    g_gfx_failed = true;
    snprintf(g_gfx_error, sizeof g_gfx_error, "%s", what);
    test_set(P_3D, RES_FAIL, "%s", what);
}

static void gfx_init() {
    if (!cap(NXN_CAP_NEXGFX)) {
        test_set(P_3D, RES_NA, "NexGFX needs OpenGL 4.3 core in the window (NXN_CAP_NEXGFX is off)");
        return;
    }
    g_gfx_start = nxn_time_ns();
    if (ngfx_device_create(NULL, &g_dev) != NGFX_OK) return gfx_fail(ngfx_native_error());
    ngfx_device_caps_get(g_dev, &g_dcaps);
    char sc[512], tx[512];
    nxn_fs_path(NXN_DIR_BUNDLE, "data/tour.nxsc", sc, sizeof sc);
    nxn_fs_path(NXN_DIR_BUNDLE, "data/tour.nxtx", tx, sizeof tx);
    ngfx_scene_desc d = {sizeof d, sc, tx, 0};
    if (ngfx_scene_load(g_dev, &d, &g_scene) != NGFX_OK) return gfx_fail(ngfx_native_error());
}

// one step per frame: shader programs (one per call), then the scene upload
static void gfx_step() {
    if (!g_dev || g_gfx_failed || g_scene_ready) return;
    if (!g_gfx_ready) {
        int r = ngfx_device_prepare(g_dev, &g_prep_done, &g_prep_total);
        if (r < 0) return gfx_fail(ngfx_native_error());
        if (r == 1) g_gfx_ready = true;
    }
    ngfx_scene_step(g_dev, g_scene, 4000000ull, &g_sst);
    if (g_sst.failed) return gfx_fail(g_sst.error);
    if (g_sst.geometry_ready && !g_sinfo.chunks) ngfx_scene_info_get(g_dev, g_scene, &g_sinfo);
    if (g_gfx_ready && g_sst.ready) {
        g_scene_ready = true;
        ngfx_device_caps_get(g_dev, &g_dcaps);
        test_set(P_3D, RES_OK, "scene ready in %.0f ms: %u chunks, %u triangles; GPU %s", (nxn_time_ns() - g_gfx_start) / 1e6,
                 g_sinfo.chunks, g_sinfo.triangles, g_dcaps.device);
    } else if (nxn_time_ns() - g_gfx_start > 20000000000ull) {
        gfx_fail("the scene was not ready after 20 s");
    }
}

static void gfx_draw(float dt) {
    if (!g_dev || g_gfx_failed || !g_gfx_ready) return;
    if (g_autorotate) g_orbit += dt * 0.35f;
    float ex = sinf(g_orbit) * cosf(g_elev) * g_dist, ez = cosf(g_orbit) * cosf(g_elev) * g_dist, ey = 1.3f + sinf(g_elev) * g_dist;
    float dx = -ex, dy = 1.3f - ey, dz = -ez, len = sqrtf(dx * dx + dy * dy + dz * dz);
    ngfx_view v = {sizeof v};
    v.eye[0] = ex, v.eye[1] = ey, v.eye[2] = ez;
    v.yaw = atan2f(dx, -dz);
    v.pitch = asinf(dy / len);
    v.fov_deg = 48.f;
    v.width = g_w, v.height = g_h;
    v.render_scale = kScales[g_scale_idx];
    v.flags = (g_shadows ? NGFX_VIEW_SHADOWS : 0) | (g_fxaa ? NGFX_VIEW_FXAA : 0);
    v.exposure = 1.0f;
    ngfx_render(g_dev, g_scene_ready ? g_scene : 0, &v, &g_fst);
}

static void page_3d(float top) {
    ImGuiIO& io = ImGui::GetIO();
    if (!g_gfx_failed && g_dev && !io.WantCaptureMouse && ImGui::IsMouseDragging(0, 2.f)) {  // drag the picture to orbit
        g_orbit -= io.MouseDelta.x * 0.008f;
        g_elev += io.MouseDelta.y * 0.006f;
        g_elev = g_elev < 0.05f ? 0.05f : g_elev > 1.2f ? 1.2f : g_elev;
    }
    if (!g_gfx_failed && g_dev) {  // the sticks: left orbits the camera, right moves it in and out
        float dt = io.DeltaTime, lx = g_in.lx, ly = g_in.ly, ry = g_in.ry;
        if (lx * lx + ly * ly > 0.04f) {
            g_orbit -= lx * dt * 1.8f;
            g_elev += ly * dt * 0.9f;
            g_elev = g_elev < 0.05f ? 0.05f : g_elev > 1.2f ? 1.2f : g_elev;
        }
        if (ry * ry > 0.04f) {
            g_dist -= ry * dt * 6.f;
            g_dist = g_dist < 4.f ? 4.f : g_dist > 16.f ? 16.f : g_dist;
        }
    }
    float pw = 260.f;
    ImGui::SetNextWindowPos(ImVec2(sp(3), top + sp(2)));
    ImGui::SetNextWindowSize(ImVec2(pw, 0));
    ImGui::PushStyleColor(ImGuiCol_WindowBg, col((g_tok.content_bg & 0x00FFFFFF) | 0xE6000000));
    ImGui::PushStyleVar(ImGuiStyleVar_WindowRounding, g_tok.corner_radius_row + 4);
    ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(sp(3), sp(2)));
    ImGui::PushStyleVar(ImGuiStyleVar_WindowBorderSize, 1.f);
    ImGui::PushStyleColor(ImGuiCol_Border, col(g_tok.separator));
    ImGui::Begin("##ctl3d", NULL, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_AlwaysAutoResize);
    ImGui::PopStyleVar(3);
    ImGui::PopStyleColor(2);
    if (g_gfx_failed || !g_dev) {
        unavailable(g_gfx_failed ? "g3d.failed" : "g3d.na");
        if (g_gfx_failed) muted(g_gfx_error);
    } else {
        ImGui::PushFont(f_big);
        ImGui::Text("%.0f", g_fps);
        ImGui::PopFont();
        ImGui::SameLine(0, sp(1));
        ImGui::BeginGroup();
        ImGui::Dummy(ImVec2(0, 6));
        ImGui::TextUnformatted(T("g3d.fps"));
        ImGui::PushStyleColor(ImGuiCol_Text, col(g_tok.text_secondary));
        ImGui::Text("%.1f ms", g_ms);
        ImGui::PopStyleColor();
        ImGui::EndGroup();
        ImGui::Separator();
        if (!g_scene_ready) {
            float prog = g_gfx_ready ? g_sst.progress : (float)g_prep_done / (float)(g_prep_total ? g_prep_total : 1);
            ImGui::TextUnformatted(g_gfx_ready ? T("g3d.loading") : T("g3d.shaders"));
            ImGui::ProgressBar(prog, ImVec2(-1, 6), "");
        } else {
            ImGui::PushStyleColor(ImGuiCol_Text, col(g_tok.text_secondary));
            ImGui::Text("%s: %u / %u", T("g3d.draws"), g_fst.draws, g_fst.shadow_draws);
            ImGui::Text("%s: %u", T("g3d.tris"), g_fst.triangles);
            ImGui::Text("%s: %.1f MB", T("g3d.gpu"), g_dcaps.gpu_bytes / 1048576.0);
            ImGui::PopStyleColor();
        }
        ImGui::Spacing();
        bool changed = false;
        changed |= ImGui::Checkbox(T("g3d.rotate"), &g_autorotate);
        changed |= ImGui::Checkbox(T("g3d.shadows"), &g_shadows);
        changed |= ImGui::Checkbox(T("g3d.fxaa"), &g_fxaa);
        static const char* scales[] = {"50%", "67%", "75%", "100%"};
        ImGui::TextUnformatted(T("g3d.scale"));
        for (int i = 0; i < 4; i++) {
            if (i) ImGui::SameLine(0, 4);
            if (selected_button(scales[i], g_scale_idx == i, ImVec2((pw - 2 * sp(3) - 12) / 4.f, 0))) g_scale_idx = i;
        }
        if (changed && g_menu_on) menu_update();
        ImGui::Spacing();
        muted(T("g3d.hint"));
    }
    ImGui::End();
}

// ------------------------------------------------------------------ Sound page
static const char* kNoteName[8] = {"C", "D", "E", "F", "G", "A", "B", "C"};
static const float kNoteHz[8] = {261.63f, 293.66f, 329.63f, 349.23f, 392.00f, 440.00f, 493.88f, 523.25f};
static float g_vol = 0.35f, g_freq = 440.f, g_len = 0.35f;
static int g_wave = 0;
static float g_flash[8];
static float g_flash_free;
static int g_seq_i = -1;
static uint64_t g_seq_next;
static const int kMelody[] = {2, 2, 3, 4, 4, 3, 2, 1, 0, 0, 1, 2, 2, 1, 1};

static void play_note(int idx, float len) {
    if (!cap(NXN_CAP_MIXER)) return;
    nxn_tone(kNoteHz[idx], len, g_vol, (uint32_t)g_wave);
    g_flash[idx] = 1.f;
}

static const char* buttons_text(uint64_t mask, char* out, size_t cap_) {
    static const char* names[16] = {"A", "B", "X", "Y", "LS", "RS", "L", "R", "ZL", "ZR", "+", "-", "Left", "Up", "Right", "Down"};
    out[0] = 0;
    size_t n = 0;
    for (int i = 0; i < 16; i++)
        if (mask & (1ull << i)) n += (size_t)snprintf(out + n, cap_ - n, "%s%s", n ? " + " : "", names[i]);
    if (!n) snprintf(out, cap_, "-");
    return out;
}

static void wave_preview(float w, float h) {
    ImDrawList* dl = ImGui::GetWindowDrawList();
    ImVec2 p = ImGui::GetCursorScreenPos();
    dl->AddRectFilled(p, ImVec2(p.x + w, p.y + h), ImGui::ColorConvertFloat4ToU32(tintc(0.07f)), g_tok.corner_radius_field);
    dl->AddLine(ImVec2(p.x + 6, p.y + h / 2), ImVec2(p.x + w - 6, p.y + h / 2), colu(g_tok.separator));
    const int N = 160;
    ImVec2 pts[N];
    float cycles = 2.f + 4.f * (log2f(g_freq / 110.f) / 4.f);  // a higher tone shows more periods
    unsigned seed = 12345;
    for (int i = 0; i < N; i++) {
        float ph = (float)i / (N - 1) * cycles, fr = ph - floorf(ph), s = 0;
        switch (g_wave) {
            case 0: s = sinf(ph * 6.2831853f); break;
            case 1: s = fr < 0.5f ? 1.f : -1.f; break;
            case 2: s = 2.f * fr - 1.f; break;
            case 3: s = fr < 0.5f ? 4.f * fr - 1.f : 3.f - 4.f * fr; break;
            default: seed = seed * 1664525u + 1013904223u; s = ((seed >> 16) & 0x7FFF) / 16384.f - 1.f; break;
        }
        pts[i] = ImVec2(p.x + 6 + (w - 12) * i / (N - 1), p.y + h / 2 - s * (h / 2 - 8) * (0.35f + 0.65f * g_vol));
    }
    dl->AddPolyline(pts, N, colu(g_tok.accent), 0, 2.f);
    ImGui::Dummy(ImVec2(w, h));
}

static void page_sound(float dt) {
    for (float& f : g_flash) f = f > 0 ? f - dt * 2.4f : 0;
    // the melody: one note every 0.22 s from the frame loop
    if (g_seq_i >= 0 && nxn_time_ns() >= g_seq_next) {
        if (g_seq_i >= (int)(sizeof kMelody / sizeof kMelody[0])) g_seq_i = -1;
        else {
            play_note(kMelody[g_seq_i++], 0.2f);
            g_seq_next = nxn_time_ns() + 220000000ull;
        }
    }
    // the user's own mapping: select / back / context play C, E, G
    static const char* actions[3] = {"select", "back", "context"};
    static const int act_note[3] = {0, 2, 4};
    uint64_t masks[3] = {0, 0, 0};
    nxn_result ar[3];
    for (int i = 0; i < 3; i++) {
        ar[i] = cap(NXN_CAP_INPUT_ACTIONS) ? nxn_input_action_buttons(actions[i], &masks[i]) : NXN_ERR_UNSUPPORTED;
        if (ar[i] == NXN_OK && (g_in.pressed & masks[i])) play_note(act_note[i], 0.25f);
    }

    float avail = ImGui::GetContentRegionAvail().x, gap = sp(2);
    bool two = avail > 720.f;
    float w = two ? (avail - gap) / 2.f : avail;
    ImGui::BeginGroup();
    if (card_begin("##mixer", ic("graphic_eq"), T("snd.mixer"), w)) {
        if (!cap(NXN_CAP_MIXER)) {
            unavailable("snd.na");
        } else {
            ImGui::SetNextItemWidth(-1);
            char vf[64];
            snprintf(vf, sizeof vf, "%s  %%.2f", T("snd.volume"));
            ImGui::SliderFloat("##vol", &g_vol, 0.f, 1.f, vf);
            static const char* waves[5] = {"wave.sine", "wave.square", "wave.saw", "wave.triangle", "wave.noise"};
            float bw = (w - 2 * sp(3) - 4 * 4) / 5.f;
            for (int i = 0; i < 5; i++) {
                if (i) ImGui::SameLine(0, 4);
                if (selected_button(T(waves[i]), g_wave == i, ImVec2(bw, 0))) g_wave = i;
            }
            ImGui::SetNextItemWidth(-1);
            ImGui::SliderFloat("##freq", &g_freq, 110.f, 1760.f, "%.0f Hz", ImGuiSliderFlags_Logarithmic);
            ImGui::SetNextItemWidth(-1);
            ImGui::SliderFloat("##len", &g_len, 0.1f, 2.f, "%.2f s");
            wave_preview(w - 2 * sp(3), 84.f);
            if (accent_button(T("snd.play"))) {
                nxn_tone(g_freq, g_len, g_vol, (uint32_t)g_wave);
                g_flash_free = 1.f;
            }
            ImGui::SameLine();
            if (ImGui::Button(T("snd.click"))) nxn_sfx_play("click", g_vol, 0);
            ImGui::SameLine();
            if (ImGui::Button(T("snd.notify"))) nxn_sfx_play("notify", g_vol, 0);
            ImGui::SameLine();
            if (ImGui::Button(T("snd.stop"))) {
                nxn_sfx_stop_all();
                g_seq_i = -1;
            }
        }
        card_end();
    }
    ImGui::EndGroup();
    if (two) ImGui::SameLine(0, gap);
    ImGui::BeginGroup();
    if (card_begin("##keys", ic("music_note"), T("snd.keys"), w)) {
        if (!cap(NXN_CAP_MIXER)) {
            unavailable("snd.na");
        } else {
            float kw = (w - 2 * sp(3) - 7 * 4) / 8.f, kh = 110.f;
            ImDrawList* dl = ImGui::GetWindowDrawList();
            for (int i = 0; i < 8; i++) {
                if (i) ImGui::SameLine(0, 4);
                ImVec2 p = ImGui::GetCursorScreenPos();
                char id[16];
                snprintf(id, sizeof id, "##key%d", i);
                if (ImGui::InvisibleButton(id, ImVec2(kw, kh))) play_note(i, 0.5f);
                bool hov = ImGui::IsItemHovered();
                dl->AddRectFilled(p, ImVec2(p.x + kw, p.y + kh), ImGui::ColorConvertFloat4ToU32(tintc(hov ? 0.20f : 0.09f)), g_tok.corner_radius);
                if (g_flash[i] > 0) dl->AddRectFilled(p, ImVec2(p.x + kw, p.y + kh), colu(g_tok.accent, g_flash[i] * 0.85f), g_tok.corner_radius);
                dl->AddRect(p, ImVec2(p.x + kw, p.y + kh), colu(g_tok.border), g_tok.corner_radius);
                ImVec2 ts = ImGui::CalcTextSize(kNoteName[i]);
                dl->AddText(ImVec2(p.x + (kw - ts.x) / 2, p.y + kh - ts.y - 8), colu(g_tok.text_secondary), kNoteName[i]);
            }
            ImGui::Spacing();
            if (ImGui::Button(g_seq_i >= 0 ? T("snd.melody_stop") : T("snd.melody"))) {
                g_seq_i = g_seq_i >= 0 ? -1 : 0;
                g_seq_next = nxn_time_ns();
                if (g_seq_i < 0) nxn_sfx_stop_all();
            }
            ImGui::SameLine();
            muted(T("snd.proc"));
        }
        card_end();
    }
    if (card_begin("##ctl", ic("gamepad"), T("snd.ctl"), w)) {
        if (!cap(NXN_CAP_INPUT_ACTIONS)) {
            unavailable("snd.ctl_na");
        } else {
            muted(T("snd.ctl_hint"));
            for (int i = 0; i < 3; i++) {
                char b[64];
                bool down = ar[i] == NXN_OK && (g_in.buttons & masks[i]);
                ImGui::PushStyleColor(ImGuiCol_Text, col(down ? g_tok.accent : g_tok.text));
                ImGui::Text("%s", T(i == 0 ? "act.select" : i == 1 ? "act.back" : "act.context"));
                ImGui::PopStyleColor();
                ImGui::SameLine(w * 0.42f);
                ImGui::Text("%s", ar[i] == NXN_OK ? buttons_text(masks[i], b, sizeof b) : "n/a");
                ImGui::SameLine(w * 0.72f);
                ImGui::PushStyleColor(ImGuiCol_Text, col(g_tok.text_secondary));
                ImGui::Text("%s", kNoteName[act_note[i]]);
                ImGui::PopStyleColor();
            }
        }
        card_end();
    }
    ImGui::EndGroup();
    (void)g_flash_free;
}

// ------------------------------------------------------------------ System page
struct Job {
    std::atomic<int> state{0};  // 0 idle, 1 running, 2 done
    int kind = 0;               // 1 open file, 2 save file, 3 folder, 4 backup, 5 restore, 6 delete
    char arg[96] = "";
    char path[512] = "";
    nxn_result result = NXN_OK;
    nxn_thread* th = NULL;
};
static Job g_job;
static char g_picked[512], g_pick_note[96], g_save_note[120], g_save_dir[512];
static char g_slots[6][64];
static int g_slot_count;
static int g_launches = -1;
static Res g_notify_res = RES_PENDING, g_clip_res = RES_PENDING, g_rumble_res = RES_PENDING;
static char g_clip_text[160];
static float g_rumble_strength = 0.6f;
static nxn_perm_state g_perm[2];
static nxn_result g_perm_r[2];
static const char* kPerms[2] = {"network", "notifications"};

static void job_run(void* p) {
    Job* j = (Job*)p;
    if (j->kind == 1 || j->kind == 2 || j->kind == 3) {
        nxn_pick_params pp = NXN_STRUCT_INIT(nxn_pick_params);
        pp.kind = j->kind == 1 ? NXN_PICK_OPEN_FILE : j->kind == 2 ? NXN_PICK_SAVE_FILE : NXN_PICK_FOLDER;
        pp.title = T(j->kind == 1 ? "sys.open" : j->kind == 2 ? "sys.saveas" : "sys.folder");
        pp.default_name = "tour.txt";
        j->path[0] = 0;
        j->result = nxn_pick(&pp, j->path, sizeof j->path);
    } else if (j->kind == 4) {
        j->result = nxn_save_backup(j->arg);
    } else if (j->kind == 5) {
        j->result = nxn_save_restore(j->arg);
    } else if (j->kind == 6) {
        j->result = nxn_save_backup_delete(j->arg);
    }
    j->state = 2;
}
static bool job_start(int kind, const char* arg) {
    if (g_job.state != 0) return false;
    g_job.kind = kind;
    snprintf(g_job.arg, sizeof g_job.arg, "%s", arg ? arg : "");
    g_job.state = 1;
    nxn_thread_params p = NXN_STRUCT_INIT(nxn_thread_params);
    p.fn = job_run;
    p.arg = &g_job;
    p.name = "tour-job";
    p.stack_size = 128 * 1024;
    if (nxn_thread_start(&p, &g_job.th) != NXN_OK) {
        g_job.state = 0;
        return false;
    }
    return true;
}
static void slots_refresh() {
    g_slot_count = 0;
    if (!cap(NXN_CAP_SAVEDATA)) return;
    char s[64];
    for (uint32_t i = 0; i < 64 && g_slot_count < 6; i++) {
        if (nxn_save_backup_get(i, s, sizeof s) != NXN_OK) break;
        snprintf(g_slots[g_slot_count++], 64, "%s", s);
    }
}
static void job_finish() {
    if (g_job.state != 2) return;
    if (g_job.th) nxn_thread_join(g_job.th);
    g_job.th = NULL;
    int kind = g_job.kind;
    nxn_result r = g_job.result;
    g_job.state = 0;
    say("job %d -> %d", kind, (int)r);
    if (kind <= 3) {
        if (r == NXN_OK) snprintf(g_picked, sizeof g_picked, "%s", g_job.path), g_pick_note[0] = 0;
        else snprintf(g_pick_note, sizeof g_pick_note, "%s", r == NXN_ERR_CANCELLED ? T("sys.cancelled") : T("res.fail"));
    } else {
        snprintf(g_save_note, sizeof g_save_note, "%s: %s", kind == 4 ? T("sys.backup") : kind == 5 ? T("sys.restore") : T("sys.delete"),
                 r == NXN_OK ? T("res.ok") : T("res.fail"));
        slots_refresh();
    }
}

static void perms_refresh() {
    for (int i = 0; i < 2; i++) g_perm_r[i] = cap(NXN_CAP_PERMISSIONS) ? nxn_perm_query(kPerms[i], &g_perm[i]) : NXN_ERR_UNSUPPORTED;
}

static void save_init() {
    if (!cap(NXN_CAP_SAVEDATA)) return;
    if (nxn_save_path(g_save_dir, sizeof g_save_dir) == NXN_OK) {
        char f[600];
        snprintf(f, sizeof f, "%s/tour.txt", g_save_dir);
        int n = 0;
        if (FILE* fp = fopen(f, "rb")) {
            if (fscanf(fp, "%d", &n) != 1) n = 0;
            fclose(fp);
        }
        n++;
        if (FILE* fp = fopen(f, "wb")) {
            fprintf(fp, "%d\n", n);
            fclose(fp);
            g_launches = n;
        }
    }
    slots_refresh();
}

static const char* shorten(const char* path, char* out, size_t n) {
    size_t len = strlen(path);
    if (len < n) return path;
    snprintf(out, n, "...%s", path + len - (n - 4));
    return out;
}

static void page_system() {
    float avail = ImGui::GetContentRegionAvail().x, gap = sp(2);
    bool two = avail > 720.f;
    float w = two ? (avail - gap) / 2.f : avail;
    char tmp[200];
    ImGui::BeginGroup();
    if (card_begin("##notify", ic("notifications"), T("sys.notify"), w)) {
        if (!cap(NXN_CAP_NOTIFY)) unavailable("sys.na");
        else {
            if (accent_button(T("sys.send"))) {
                nxn_result r = nxn_notify(T("sys.notify_title"), T("sys.notify_body"));
                g_notify_res = r == NXN_OK ? RES_OK : RES_FAIL;
                say("notify -> %d", (int)r);
            }
            ImGui::SameLine();
            if (g_notify_res != RES_PENDING) status_dot(g_notify_res, res_text(g_notify_res));
            else muted(T("sys.notify_hint"));
        }
        card_end();
    }
    if (card_begin("##clip", ic("content_copy"), T("sys.clipboard"), w)) {
        if (!cap(NXN_CAP_CLIPBOARD)) unavailable("sys.na");
        else {
            if (ImGui::Button(T("sys.copy"))) {
                char t[96];
                snprintf(t, sizeof t, "Native Tour, %lld", (long long)nxn_time_unix());
                g_clip_res = nxn_clipboard_set(t) == NXN_OK ? RES_OK : RES_FAIL;
            }
            ImGui::SameLine();
            if (ImGui::Button(T("sys.paste"))) {
                size_t len = 0;
                g_clip_text[0] = 0;
                g_clip_res = nxn_clipboard_get(g_clip_text, sizeof g_clip_text - 1, &len) == NXN_OK ? RES_OK : RES_FAIL;
                if (g_clip_res == RES_OK) g_clip_text[len < sizeof g_clip_text ? len : sizeof g_clip_text - 1] = 0;
            }
            ImGui::SameLine();
            if (g_clip_res != RES_PENDING) status_dot(g_clip_res, res_text(g_clip_res));
            ImGui::PushFont(f_mono);
            muted(g_clip_text[0] ? g_clip_text : "-");
            ImGui::PopFont();
        }
        card_end();
    }
    if (card_begin("##rumble", ic("vibration"), T("sys.rumble"), w)) {
        if (!cap(NXN_CAP_RUMBLE)) unavailable("sys.na");
        else {
            ImGui::SetNextItemWidth(w * 0.5f);
            ImGui::SliderFloat("##str", &g_rumble_strength, 0.f, 1.f, "%.2f");
            ImGui::SameLine();
            if (ImGui::Button(T("sys.rumble_go"))) {
                nxn_result r = nxn_rumble(g_rumble_strength, 250);
                g_rumble_res = r == NXN_OK ? RES_OK : RES_FAIL;
            }
            ImGui::SameLine();
            if (g_rumble_res != RES_PENDING) status_dot(g_rumble_res, res_text(g_rumble_res));
        }
        card_end();
    }
    if (card_begin("##perm", ic("shield"), T("sys.perms"), w)) {
        if (!cap(NXN_CAP_PERMISSIONS)) unavailable("sys.na");
        else {
            for (int i = 0; i < 2; i++) {
                Res r = g_perm_r[i] != NXN_OK ? RES_NA : g_perm[i] == NXN_PERM_GRANTED ? RES_OK : g_perm[i] == NXN_PERM_DENIED ? RES_FAIL : RES_NA;
                const char* st = g_perm_r[i] != NXN_OK ? T("perm.unknown") : g_perm[i] == NXN_PERM_GRANTED ? T("perm.granted") : g_perm[i] == NXN_PERM_DENIED ? T("perm.denied") : T("perm.notdeclared");
                ImGui::Text("%s", kPerms[i]);
                ImGui::SameLine(w * 0.4f);
                status_dot(r, st);
                if (g_perm_r[i] == NXN_OK && g_perm[i] == NXN_PERM_DENIED) {
                    ImGui::SameLine();
                    char id[24];
                    snprintf(id, sizeof id, "%s##req%d", T("perm.request"), i);
                    if (ImGui::SmallButton(id)) {
                        nxn_perm_request(kPerms[i], &g_perm[i]);
                        perms_refresh();
                    }
                }
            }
        }
        card_end();
    }
    ImGui::EndGroup();
    if (two) ImGui::SameLine(0, gap);
    ImGui::BeginGroup();
    if (card_begin("##files", ic("folder_open"), T("sys.files"), w)) {
        if (!cap(NXN_CAP_PICKER)) unavailable("sys.na");
        else {
            bool busy = g_job.state != 0;
            if (busy) ImGui::BeginDisabled();
            if (ImGui::Button(T("sys.open"))) job_start(1, NULL);
            ImGui::SameLine();
            if (ImGui::Button(T("sys.saveas"))) job_start(2, NULL);
            ImGui::SameLine();
            if (ImGui::Button(T("sys.folder"))) job_start(3, NULL);
            if (busy) ImGui::EndDisabled();
            ImGui::PushFont(f_mono);
            muted(g_picked[0] ? shorten(g_picked, tmp, 64) : T("sys.nothing"));
            ImGui::PopFont();
            if (g_pick_note[0]) muted(g_pick_note);
        }
        card_end();
    }
    if (card_begin("##save", ic("backup"), T("sys.save"), w)) {
        if (!cap(NXN_CAP_SAVEDATA)) unavailable("sys.na");
        else {
            if (g_launches >= 0) {
                snprintf(tmp, sizeof tmp, "%d", g_launches);
                const char* a[1] = {tmp};
                char line[120];
                if (nxn_tr_format("sys.launches", line, sizeof line, a, 1) == NXN_OK) ImGui::TextUnformatted(line);
            }
            ImGui::PushFont(f_mono);
            muted(shorten(g_save_dir, tmp, 60));
            ImGui::PopFont();
            bool busy = g_job.state != 0;
            if (busy) ImGui::BeginDisabled();
            if (accent_button(T("sys.backup_now"))) {
                char slot[64];
                snprintf(slot, sizeof slot, "tour-%lld", (long long)nxn_time_unix());
                job_start(4, slot);
            }
            for (int i = 0; i < g_slot_count; i++) {
                ImGui::PushID(i);
                ImGui::PushFont(f_mono);
                ImGui::TextUnformatted(g_slots[i]);
                ImGui::PopFont();
                ImGui::SameLine(w - 190.f);
                if (ImGui::SmallButton(T("sys.restore"))) job_start(5, g_slots[i]);
                ImGui::SameLine();
                if (ImGui::SmallButton(T("sys.delete"))) job_start(6, g_slots[i]);
                ImGui::PopID();
            }
            if (busy) ImGui::EndDisabled();
            if (g_slot_count == 0) muted(T("sys.no_backups"));
            if (g_save_note[0]) muted(g_save_note);
        }
        card_end();
    }
    ImGui::EndGroup();
}

// the calls that touch the user's things: only with <data>/autotest, once
static void system_autotest() {
    int fail = 0, ran = 0;
    char note[160] = "";
    if (cap(NXN_CAP_CLIPBOARD)) {
        char mark[64], back[64] = "";
        size_t len = 0;
        snprintf(mark, sizeof mark, "tour-selftest-%lld", (long long)nxn_time_unix());
        ran++;
        if (nxn_clipboard_set(mark) != NXN_OK || nxn_clipboard_get(back, sizeof back - 1, &len) != NXN_OK || strcmp(back, mark)) fail++;
    }
    if (cap(NXN_CAP_NOTIFY)) {
        ran++;
        nxn_result r = nxn_notify(T("sys.notify_title"), T("sys.notify_body"));
        if (r != NXN_OK && r != NXN_ERR_DENIED) fail++;
    }
    if (cap(NXN_CAP_RUMBLE)) {
        ran++;
        if (nxn_rumble(0.f, 10) != NXN_OK) fail++;
    }
    if (cap(NXN_CAP_SAVEDATA) && g_launches >= 0) {
        ran++;
        const char* slot = "tour-selftest";
        char s[64];
        bool found = false;
        int ok = nxn_save_backup(slot) == NXN_OK;
        for (uint32_t i = 0; i < 64 && nxn_save_backup_get(i, s, sizeof s) == NXN_OK; i++) found |= strcmp(s, slot) == 0;
        ok = ok && found && nxn_save_restore(slot) == NXN_OK && nxn_save_backup_delete(slot) == NXN_OK;
        if (!ok) fail++;
        slots_refresh();
    }
    snprintf(note, sizeof note, "autotest ran %d of 5 calls", ran);
    test_set(P_SYSTEM, fail ? RES_FAIL : ran ? RES_OK : RES_NA, "%s, %d failed; dialogs are interactive", note, fail);
}

// ------------------------------------------------------------------ Runtime page
static RtReport g_rt;
static Res g_rt_res = RES_PENDING;

static void runtime_run(bool first) {
    rt_run(g_rt, g_caps.features);
    int ok = 0, na = 0, fail = 0;
    char d[170] = "";
    size_t n = 0;
    for (int i = 0; i < g_rt.n; i++) {
        ok += g_rt.rows[i].res == RES_OK;
        na += g_rt.rows[i].res == RES_NA;
        fail += g_rt.rows[i].res == RES_FAIL;
        n += (size_t)snprintf(d + n, sizeof d - n, "%s%s=%c", i ? " " : "", g_rt.rows[i].label + 3, g_rt.rows[i].res == RES_OK ? 'o' : g_rt.rows[i].res == RES_NA ? '-' : 'F');
    }
    g_rt_res = fail ? RES_FAIL : ok ? RES_OK : RES_NA;
    if (first) test_set(P_RUNTIME, g_rt_res, "%s", d);
    else say("runtime rerun %s", d);
}

static void page_runtime() {
    float avail = ImGui::GetContentRegionAvail().x;
    if (card_begin("##rt", ic("memory"), T("rt.title"), avail)) {
        for (int i = 0; i < g_rt.n; i++) {
            const RtRow& r = g_rt.rows[i];
            ImGui::PushFont(f_title);
            ImGui::PopFont();
            status_dot(r.res, T(r.label));
            ImGui::SameLine(avail * 0.30f);
            ImGui::PushFont(f_mono);
            if (r.res == RES_NA) muted(T("rt.na"));
            else muted(r.detail);
            ImGui::PopFont();
            ImGui::Dummy(ImVec2(0, 2));
        }
        ImGui::Spacing();
        if (accent_button(T("rt.rerun"))) runtime_run(false);
        ImGui::SameLine();
        muted(T("rt.switches"));
        card_end();
    }
    if (g_rt.tls_vals[0]) {
        float gap = sp(2), w = (avail - 2 * gap) / 3.f;
        for (int i = 0; i < 3; i++) {
            if (i) ImGui::SameLine(0, gap);
            char id[16];
            snprintf(id, sizeof id, "##th%d", i);
            if (card_begin(id, ic("layers"), "thread_local", w)) {
                ImGui::PushFont(f_big);
                ImGui::Text("%d", g_rt.tls_vals[i]);
                ImGui::PopFont();
                char k[32];
                snprintf(k, sizeof k, "rt.thread%d", i + 1);
                muted(T(k));
                card_end();
            }
        }
    }
    if (g_rt.greeting[0]) {
        if (card_begin("##greet", ic("widgets"), T("rt.lib_card"), avail)) {
            ImGui::PushFont(f_mono);
            ImGui::Text("%s", g_rt.hello);
            ImGui::Text("%s", g_rt.greeting);
            ImGui::PopFont();
            card_end();
        }
    }
}

// ------------------------------------------------------------------ About page
static float g_heap_hist[120];
static int g_heap_n;
static uint64_t g_heap_last;
static size_t heap_bytes() {
    struct mallinfo mi = mallinfo();
    return (size_t)mi.uordblks + (size_t)mi.hblkhd;
}

static void page_about() {
    if (nxn_time_ns() - g_heap_last > 500000000ull) {
        g_heap_last = nxn_time_ns();
        if (g_heap_n < 120) g_heap_hist[g_heap_n++] = heap_bytes() / 1048576.f;
        else {
            memmove(g_heap_hist, g_heap_hist + 1, sizeof(float) * 119);
            g_heap_hist[119] = heap_bytes() / 1048576.f;
        }
    }
    float avail = ImGui::GetContentRegionAvail().x, gap = sp(2);
    bool two = avail > 720.f;
    float w = two ? (avail - gap) / 2.f : avail;
    ImGui::BeginGroup();
    if (card_begin("##ver", ic("info"), T("about.sdk"), w)) {
        char v[40];
        snprintf(v, sizeof v, "%u.%u", g_caps.version_major, g_caps.version_minor);
        struct { const char* k; char val[64]; } rows[9];
        int n = 0;
        auto row = [&](const char* k, const char* val) { rows[n].k = k; snprintf(rows[n].val, sizeof rows[n].val, "%s", val); n++; };
        row("about.native", v);
        snprintf(v, sizeof v, "%u", g_caps.abi_gen);
        row("about.abi", v);
        row("about.os", nxn_info_string(NXN_INFO_OS_VERSION));
        row("about.script", nxn_info_string(NXN_INFO_SDK_VERSION));
        snprintf(v, sizeof v, "%s %s", nxn_info_string(NXN_INFO_APP_ID), nxn_info_string(NXN_INFO_APP_VERSION));
        row("about.app", v);
        row("about.lang", nxn_info_string(NXN_INFO_LANGUAGE));
        row("about.theme", nxn_info_string(NXN_INFO_THEME));
        for (int i = 0; i < n; i++) {
            ImGui::PushStyleColor(ImGuiCol_Text, col(g_tok.text_secondary));
            ImGui::TextUnformatted(T(rows[i].k));
            ImGui::PopStyleColor();
            ImGui::SameLine(w * 0.34f);
            ImGui::PushFont(i == 0 ? f_title : f_body);
            ImGui::TextUnformatted(rows[i].val[0] ? rows[i].val : "-");
            ImGui::PopFont();
        }
        card_end();
    }
    if (card_begin("##mem", ic("speed"), T("about.memory"), w)) {
        float mb = heap_bytes() / 1048576.f;
        ImGui::PushFont(f_big);
        ImGui::Text("%.1f", mb);
        ImGui::PopFont();
        ImGui::SameLine();
        ImGui::BeginGroup();
        ImGui::Dummy(ImVec2(0, 8));
        ImGui::TextUnformatted("MB");
        ImGui::EndGroup();
        muted(T("about.heap"));
        ImGui::PushStyleColor(ImGuiCol_PlotLines, col(g_tok.accent));
        ImGui::PushStyleColor(ImGuiCol_FrameBg, col(g_tok.field_bg));
        {
            float lo = FLT_MAX, hi = 0;
            for (int i = 0; i < g_heap_n; i++) lo = fminf(lo, g_heap_hist[i]), hi = fmaxf(hi, g_heap_hist[i]);
            ImGui::PlotLines("##heap", g_heap_hist, g_heap_n, 0, NULL, lo - 2.f, hi + 2.f, ImVec2(w - 2 * sp(3), 56));
        }
        ImGui::PopStyleColor(2);
        if (g_dev) ImGui::Text("%s: %.1f MB", T("about.gpu"), g_dcaps.gpu_bytes / 1048576.0);
        ImGui::Text("%s: %.0f s", T("about.uptime"), (nxn_time_ns() - g_start_ns) / 1e9);
        card_end();
    }
    ImGui::EndGroup();
    if (two) ImGui::SameLine(0, gap);
    ImGui::BeginGroup();
    if (card_begin("##caps", ic("check_circle"), T("about.caps"), w)) {
        static const struct { uint64_t bit; const char* name; } kCaps[] = {
            {NXN_CAP_HOSTED, "HOSTED"}, {NXN_CAP_WINDOWED, "WINDOWED"}, {NXN_CAP_CRASH_GUARD, "CRASH_GUARD"}, {NXN_CAP_GL_CORE, "GL_CORE"},
            {NXN_CAP_GLES, "GLES"}, {NXN_CAP_AUDIO, "AUDIO"}, {NXN_CAP_TOUCH, "TOUCH"}, {NXN_CAP_KEYBOARD, "KEYBOARD"},
            {NXN_CAP_EVENTS, "EVENTS"}, {NXN_CAP_SHARED_LIBS, "SHARED_LIBS"}, {NXN_CAP_AUDIO_CLEAR, "AUDIO_CLEAR"}, {NXN_CAP_USB_INPUT, "USB_INPUT"},
            {NXN_CAP_POWER_EVENTS, "POWER_EVENTS"}, {NXN_CAP_NOTIFY, "NOTIFY"}, {NXN_CAP_CLIPBOARD, "CLIPBOARD"}, {NXN_CAP_RUMBLE, "RUMBLE"},
            {NXN_CAP_PICKER, "PICKER"}, {NXN_CAP_SAVEDATA, "SAVEDATA"}, {NXN_CAP_PERMISSIONS, "PERMISSIONS"}, {NXN_CAP_UI_TOKENS, "UI_TOKENS"},
            {NXN_CAP_TEXT, "TEXT"}, {NXN_CAP_NEXGFX, "NEXGFX"}, {NXN_CAP_MIXER, "MIXER"}, {NXN_CAP_INPUT_ACTIONS, "INPUT_ACTIONS"},
            {NXN_CAP_TLS, "TLS"}, {NXN_CAP_CXX_EXCEPTIONS, "CXX_EXCEPTIONS"}, {NXN_CAP_JIT, "JIT"}, {NXN_CAP_FAULT_HANDLER, "FAULT_HANDLER"},
            {NXN_CAP_GUARD_PAGES, "GUARD_PAGES"}, {NXN_CAP_MENU, "MENU"}, {NXN_CAP_UI_FONT_CJK, "UI_FONT_CJK"}};
        const int N = (int)(sizeof kCaps / sizeof kCaps[0]);
        int on = 0;
        for (int i = 0; i < N; i++) on += cap(kCaps[i].bit);
        char head[48];
        snprintf(head, sizeof head, "%d / %d", on, N);
        ImGui::TextUnformatted(head);
        ImGui::PushFont(f_mono);
        float cw = (w - 2 * sp(3)) / 2.f;
        for (int i = 0; i < N; i++) {
            bool on_ = cap(kCaps[i].bit);
            if (i % 2) ImGui::SameLine(sp(3) + cw);
            ImVec2 p = ImGui::GetCursorScreenPos();
            float fh = ImGui::GetTextLineHeight();
            ImGui::GetWindowDrawList()->AddCircleFilled(ImVec2(p.x + fh * 0.4f, p.y + fh * 0.5f), fh * 0.25f, colu(on_ ? g_tok.success : g_tok.text_tertiary, on_ ? 1.f : 0.55f));
            ImGui::Dummy(ImVec2(fh, fh));
            ImGui::SameLine(0, 2);
            ImGui::PushStyleColor(ImGuiCol_Text, col(on_ ? g_tok.text : g_tok.text_tertiary));
            ImGui::TextUnformatted(kCaps[i].name);
            ImGui::PopStyleColor();
        }
        ImGui::PopFont();
        card_end();
    }
    ImGui::EndGroup();
}

// ------------------------------------------------------------------ shell
static float draw_shell() {
    float hh = g_tok.control_height + sp(2);
    float tabs_h = g_menu_on ? 0.f : g_tok.control_height + sp(1);
    bool over3d = g_page == P_3D && g_dev && !g_gfx_failed && g_gfx_ready;
    ImGui::SetNextWindowPos(ImVec2(0, 0));
    ImGui::SetNextWindowSize(ImVec2((float)g_w, hh + tabs_h));
    ImGui::PushStyleColor(ImGuiCol_WindowBg, col((g_tok.window_bg & 0x00FFFFFF) | (over3d ? 0xC8000000u : 0xFF000000u)));
    ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(sp(3), 0));
    ImGui::Begin("##hdr", NULL, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoScrollbar);
    ImGui::PopStyleVar();
    ImGui::PopStyleColor();
    ImDrawList* dl = ImGui::GetWindowDrawList();
    // title row
    ImGui::PushFont(f_title);
    float th = ImGui::GetTextLineHeight();
    ImGui::SetCursorPosY((hh - th) / 2);
    ImGui::PushStyleColor(ImGuiCol_Text, col(g_tok.accent));
    ImGui::TextUnformatted(ic(kPageIcon[g_page]));
    ImGui::PopStyleColor();
    ImGui::SameLine(0, sp(1));
    ImGui::TextUnformatted(T(kPageKey[g_page]));
    ImGui::PopFont();
    // right side: self-test result of this page and the fps
    char right[96];
    snprintf(right, sizeof right, "%.0f fps", g_fps);
    ImGui::PushFont(f_small);
    float rw = ImGui::CalcTextSize(right).x + ImGui::CalcTextSize(res_text(g_test[g_page])).x + 3 * sp(3);
    ImGui::SameLine(g_w - rw - sp(3));
    ImGui::SetCursorPosY((hh - ImGui::GetTextLineHeight()) / 2);
    status_dot(g_test[g_page], res_text(g_test[g_page]));
    ImGui::SameLine(0, sp(3));
    ImGui::PushStyleColor(ImGuiCol_Text, col(g_tok.text_secondary));
    ImGui::TextUnformatted(right);
    ImGui::PopStyleColor();
    ImGui::PopFont();
    dl->AddLine(ImVec2(0, hh - 1), ImVec2((float)g_w, hh - 1), colu(g_tok.separator));
    if (!g_menu_on) {  // fallback: a tab bar under the title
        ImGui::SetCursorPos(ImVec2(sp(3), hh + (tabs_h - g_tok.control_height) / 2));
        float x = sp(3);
        for (int i = 0; i < P_COUNT; i++) {
            char label[64];
            snprintf(label, sizeof label, "%s  %s", ic(kPageIcon[i]), T(kPageKey[i]));
            ImGui::SetCursorPos(ImVec2(x, hh + (tabs_h - g_tok.control_height) / 2));
            ImVec2 sz(ImGui::CalcTextSize(label).x + 2 * sp(3), g_tok.control_height - 4);
            if (selected_button(label, g_page == i, sz)) goto_page(i);
            x += sz.x + sp(1);
        }
    }
    ImGui::End();
    return hh + tabs_h;
}

static void draw_ui(float dt) {
    float top = draw_shell();
    if (g_page == P_3D) {
        page_3d(top);
        return;
    }
    ImGui::SetNextWindowPos(ImVec2(0, top));
    ImGui::SetNextWindowSize(ImVec2((float)g_w, (float)g_h - top));
    ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(sp(3), sp(3)));
    ImGui::Begin("##page", NULL, ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoSavedSettings | ImGuiWindowFlags_NoBackground);
    ImGui::PopStyleVar();
    ImGui::PushFont(f_body);
    switch (g_page) {
        case P_SOUND: page_sound(dt); break;
        case P_SYSTEM: page_system(); break;
        case P_RUNTIME: page_runtime(); break;
        case P_ABOUT: page_about(); break;
    }
    ImGui::PopFont();
    ImGui::End();
}

// ------------------------------------------------------------------ the quiet self-tests of Sound, System, About
static void quiet_tests() {
    // Sound: the mixer takes a tone (a silent one: inaudible volume, 50 ms) and the mapping answers
    if (!cap(NXN_CAP_MIXER) && !cap(NXN_CAP_INPUT_ACTIONS)) {
        test_set(P_SOUND, RES_NA, "mixer and button mapping are off in this window");
    } else {
        nxn_result t = cap(NXN_CAP_MIXER) ? nxn_tone(440.f, 0.05f, 0.f, 0) : NXN_ERR_UNSUPPORTED;
        uint64_t m = 0;
        nxn_result a = cap(NXN_CAP_INPUT_ACTIONS) ? nxn_input_action_buttons("select", &m) : NXN_ERR_UNSUPPORTED;
        bool bad = (cap(NXN_CAP_MIXER) && t != NXN_OK) || (cap(NXN_CAP_INPUT_ACTIONS) && a != NXN_OK);
        char b[64];
        test_set(P_SOUND, bad ? RES_FAIL : RES_OK, "tone %d, select mapped to %s (%d)", (int)t, a == NXN_OK ? buttons_text(m, b, sizeof b) : "n/a", (int)a);
    }
    // System
    uint64_t sysbits = NXN_CAP_NOTIFY | NXN_CAP_CLIPBOARD | NXN_CAP_RUMBLE | NXN_CAP_PICKER | NXN_CAP_SAVEDATA | NXN_CAP_PERMISSIONS;
    if (!(g_caps.features & sysbits)) test_set(P_SYSTEM, RES_NA, "no system service is available in this window");
    else if (g_autotest) system_autotest();
    else test_set(P_SYSTEM, RES_OK, "services present (notify %d clipboard %d rumble %d picker %d save %d perms %d); calls run with <data>/autotest",
                  cap(NXN_CAP_NOTIFY), cap(NXN_CAP_CLIPBOARD), cap(NXN_CAP_RUMBLE), cap(NXN_CAP_PICKER), cap(NXN_CAP_SAVEDATA), cap(NXN_CAP_PERMISSIONS));
    // About
    test_set(P_ABOUT, nxn_info_string(NXN_INFO_NATIVE_VERSION)[0] || g_caps.version_major ? RES_OK : RES_FAIL, "native %u.%u abi %u, features 0x%llx, heap %.1f MB",
             g_caps.version_major, g_caps.version_minor, g_caps.abi_gen, (unsigned long long)g_caps.features, heap_bytes() / 1048576.0);
}

static int app_main(int, char**) {
    if (nxn_display_open(NULL, &g_disp) != NXN_OK) {
        nxn_request_return(NXN_RETURN_ERROR, 1, "OpenGL is not available");
        return 1;
    }
    gladLoadGLLoader((GLADloadproc)nxn_display_proc);
    nxn_display_size(g_disp, &g_w, &g_h);
    nxn_caps_get(&g_caps);
    g_start_ns = nxn_time_ns();
    say("start native %u.%u features 0x%llx %ux%u", g_caps.version_major, g_caps.version_minor, (unsigned long long)g_caps.features, g_w, g_h);
    {
        char probe[8];
        size_t got = 0;
        g_autotest = nxn_fs_read(NXN_DIR_DATA, "autotest", probe, sizeof probe - 1, &got) == NXN_OK;
    }

    nxn_ui_tokens_get(&g_tok);
    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = nullptr;
    io.LogFilename = nullptr;
    nxn_imgui_enable_gamepad(io);
    setup_fonts();
    apply_tokens();
    ImGui_ImplOpenGL3_Init("#version 330 core");

    if (cap(NXN_CAP_MENU)) menu_update();
    else say("window menu: off, tab bar instead (NXN_CAP_MENU is off)");
    gfx_init();
    save_init();
    perms_refresh();
    runtime_run(true);
    quiet_tests();

    uint64_t last = nxn_time_ns(), fps_t = last;
    int fps_n = 0, page_frames = 0, shown_page = -1;
    bool quit = false;
    while (!quit && !nxn_should_quit()) {
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {
            if (ev.type == NXN_EVENT_RESIZE) {
                if (nxn_display_resize(g_disp, ev.width, ev.height) == NXN_OK) nxn_display_size(g_disp, &g_w, &g_h);
                say("resize %ux%u", g_w, g_h);
            } else if (ev.type == NXN_EVENT_THEME) {
                apply_tokens();
            } else if (ev.type == NXN_EVENT_MENU) {
                say("menu pick %u", ev.item_id);
                if (ev.item_id >= 1 && ev.item_id <= P_COUNT) goto_page((int)ev.item_id - 1);
                else if (ev.item_id == 11) g_autorotate = !g_autorotate, menu_update();
                else if (ev.item_id == 12) g_shadows = !g_shadows, menu_update();
                else if (ev.item_id == 13) g_fxaa = !g_fxaa, menu_update();
            } else if (ev.type == NXN_EVENT_QUIT) {
                quit = true;
            }
            ev = NXN_STRUCT_INIT(nxn_event);
        }
        nxn_input_poll(&g_in);
        if (g_in.actions & NXN_ACT_CANCEL) quit = true;
        if (g_in.pressed & NXN_BTN_R) goto_page(g_page + 1);
        if (g_in.pressed & NXN_BTN_L) goto_page(g_page - 1);
        if (cap(NXN_CAP_USB_INPUT)) {
            nxn_key_event ke = NXN_STRUCT_INIT(nxn_key_event);
            while (nxn_input_key_poll(&ke) > 0) {
                if (ke.down && ke.usage >= 30 && ke.usage <= 34) goto_page((int)ke.usage - 30);  // 1..5
                ke = NXN_STRUCT_INIT(nxn_key_event);
            }
        }
        job_finish();

        uint64_t now = nxn_time_ns();
        float dt = (float)((now - last) / 1e9);
        last = now;
        fps_n++;
        if (now - fps_t >= 500000000ull) {
            g_fps = fps_n / ((now - fps_t) / 1e9f);
            g_ms = 1000.f / (g_fps > 0.1f ? g_fps : 0.1f);
            fps_n = 0;
            fps_t = now;
        }
        if (g_page != shown_page) {
            shown_page = g_page;
            page_frames = 0;
            if (g_page == P_SYSTEM) {
                perms_refresh();
                slots_refresh();
            }
        }
        if (++page_frames == 90) say("page %s drawn (%.0f fps)", kPageName[g_page], g_fps);

        gfx_step();
        feed_imgui(dt);
        ImGui_ImplOpenGL3_NewFrame();
        ImGui::NewFrame();
        draw_ui(dt);
        ImGui::Render();
        glViewport(0, 0, (GLsizei)g_w, (GLsizei)g_h);
        glDisable(GL_SCISSOR_TEST);
        if (g_page == P_3D && g_dev && !g_gfx_failed && g_gfx_ready) {
            gfx_draw(dt);
        } else {
            ImVec4 bg = col(g_tok.window_bg);
            glClearColor(bg.x, bg.y, bg.z, 1.f);
            glClear(GL_COLOR_BUFFER_BIT);
        }
        ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
        nxn_display_swap(g_disp);
    }
    if (g_job.state != 0 && g_job.th) nxn_thread_join(g_job.th);  // every thread is joined before the app returns
    nxn_sfx_stop_all();
    if (g_menu_on) nxn_menu_clear();
    if (g_dev) {
        if (g_scene) ngfx_scene_free(g_dev, g_scene);
        ngfx_device_destroy(g_dev);
    }
    ImGui_ImplOpenGL3_Shutdown();
    ImGui::DestroyContext();
    nxn_display_close(g_disp);
    say("ended");
    return 0;
}

int main(int argc, char** argv) { return nxn_run(argc, argv, app_main, NULL); }
