/* Nexvyn Native SDK - Canonical Nexvyn OS Design System & Widget Kit for Dear ImGui.
 *
 * Include AFTER <imgui.h>. Header-only C++ (no ABI exports added). It pulls in <nexvyn/nexvyn_native.h> and
 * <nexvyn/nxn_imgui.h> itself.
 *
 * Renders grouped cards, segmented tabs, animated switches, chevron dropdowns, pill badges,
 * sleek progress meters, and hairline list rows parameterized live by `nxn_ui_tokens` so
 * Native C/C++ utility/tool/HUD apps match Nexvyn OS's Lua/JS/Python `ui.*` & `nxui.*` look
 * across Light, Dark, High-Contrast, and custom accent themes.
 *
 * THE FRAME LAYER (required for apps; tools/design_check.py and `nxv check` fail an ImGui app without it)
 *
 *     ImGui_ImplOpenGL3_Init("#version 330 core");        // once, after ImGui::CreateContext()
 *     ...every frame, after feeding input:
 *     nxn_os_frame_begin(&tok, fb_w, fb_h);                // scale, fonts, style, ImGui NewFrame, full-window root
 *         nxn_os_text(NXN_OS_TEXT_TITLE, "Title");
 *         nxn_os_row_begin();                               // one line of controls, equal height, centred
 *             nxn_os_select("mode", items, 3, &mode, nxn_os_fill(0.5f));
 *             if (nxn_os_button("Apply", NXN_OS_BTN_PRIMARY, tok)) apply();
 *         nxn_os_row_end();
 *     nxn_os_frame_end();                                  // ImGui::Render()
 *     glClearColor(nxn_os_clear_color(tok)...); ImGui_ImplOpenGL3_RenderDrawData(ImGui::GetDrawData());
 *
 * What the frame layer owns, so the app cannot get it wrong:
 *   - the UI scale: 1.0 = the OS's 1280 x 720 logical layout. Inside Nexvyn OS it is the window surface scale the system
 *     reports (nxn_ui_tokens.ui_scale: interface size of Settings > Display, handheld or TV); on an older system 1.0;
 *     in a stand-alone .nro the screen height / 720. Never FontGlobalScale: text is rasterised at its real size.
 *   - the fonts: the four text roles (Title 19.2 bold, Header 15.2 bold, Body 13.8, Caption 11.5 pt; pixel size
 *     floor(pt * 1.21 + 0.5) x text size x scale, PixelSnap, 2x density) with the glyphs of the user's language. When the
 *     scale or the accessibility text size changes the atlas is rebuilt (debounced, 0.2 s) and the GL texture updated.
 *     The app adds no fonts of its own (AddFont* / nxn_imgui_add_font are for games and scenes).
 *   - the style: nxn_os_apply_style() x scale, every frame (theme, accent and contrast follow without app code).
 *   - minimum sizes: text controls are never lower than the OS control height (30 x scale), icon buttons, rail items
 *     and list rows never smaller than the 44 px touch target (x scale); every widget draws its text with its role
 *     font whatever font the app pushed.
 *   - sizes: NXN_S(px) / nxn_os_s(px) for any number of pixels the app needs, nxn_os_sp(NXN_OS_SP_*) for spacing,
 *     nxn_os_radius(NXN_OS_R_*) for radii, nxn_os_fill(frac) for widths. A bare pixel literal in an app is a design
 *     error (tools/design_check.py).
 * Widget size arguments are pixels of the surface (already scaled: pass NXN_S(x), nxn_os_fill() or 0 for the default).
 * Without nxn_os_frame_begin every widget behaves exactly as in earlier kits (scale 1, no minimum sizes).
 *
 * The kit draws with the OpenGL 3 backend of Dear ImGui (imgui_impl_opengl3). Another renderer: define
 * NXN_OS_UI_NO_GL3 before the include, pass NXN_OS_FRAME_NO_BACKEND and nxn_os_set_font_uploader(fn).
 *
 * Note: Games give themselves their own art direction; this kit is for utilities, dashboards,
 * benchmarks, settings panels, editors, and system overlays that belong to Nexvyn OS.
 */
#ifndef NEXVYN_NXN_OS_UI_H
#define NEXVYN_NXN_OS_UI_H

#ifdef __cplusplus

#include <math.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include "nexvyn_native.h"

#ifndef IMGUI_VERSION
#error "Include <imgui.h> before <nexvyn/nxn_os_ui.h>"
#endif

#include "nxn_imgui.h"
#include "nxn_imgui_input.h"
#include "nxn_scroll_physics.h"
#include "imgui_internal.h"

/* Per-context touch scroll capture. The innermost hovered scroll window wins;
 * slider/text edits retain capture. Mouse drags never become touch scrolling. */
struct NxnOsTouchScroll {
    ImGuiID window = 0, protected_item = 0;
    ImVec2 start, last;
    ImVec2 velocity = ImVec2(0, 0);
    double moved_at = 0;
    bool dragging = false;
};
static inline float nxn_os_scale();
static inline NxnOsTouchScroll& nxn_os__touch_scroll() {
    static NxnOsTouchScroll s;
    static ImGuiContext* owner = NULL;
    if (owner != ImGui::GetCurrentContext()) { s = NxnOsTouchScroll(); owner = ImGui::GetCurrentContext(); }
    return s;
}
static inline void nxn_os__touch_scroll_update() {
    NxnOsTouchScroll& s = nxn_os__touch_scroll();
    ImGuiIO& io = ImGui::GetIO();
    if (io.AppFocusLost ||
        (io.MouseSource != ImGuiMouseSource_TouchScreen &&
         (io.MouseDown[0] || io.MouseWheel != 0 || io.MouseWheelH != 0))) {
        s = NxnOsTouchScroll(); return;
    }
    ImGuiWindow* w = s.window ? ImGui::FindWindowByID(s.window) : NULL;
    ImGuiWindow* modal = ImGui::GetTopMostPopupModal();
    if (modal && w) {
        ImGuiWindow* ancestor = w;
        while (ancestor && ancestor != modal) ancestor = ancestor->ParentWindow;
        if (!ancestor) { s = NxnOsTouchScroll(); return; }
    }
    if (ImGui::IsMouseClicked(0)) {
        bool catch_fling = fabsf(s.velocity.x) > NXN_SCROLL_CATCH || fabsf(s.velocity.y) > NXN_SCROLL_CATCH;
        ImGuiWindow* hovered = ImGui::GetCurrentContext()->HoveredWindow;
        while (hovered && hovered != w) hovered = hovered->ParentWindow;
        if (catch_fling && w && hovered == w) {
            // A tap stops a moving list without activating the row underneath.
            ImGui::ClearActiveID();
            ImGui::SetKeyOwner(ImGuiKey_MouseLeft, w->ID, ImGuiInputFlags_LockUntilRelease);
        }
        s = NxnOsTouchScroll();
        return;
    }
    if (w && !io.MouseDown[0] && !s.dragging) {
        if (s.velocity.x == 0 && s.velocity.y == 0) { s = NxnOsTouchScroll(); return; }
        float x = w->Scroll.x, y = w->Scroll.y;
        nxn_scroll_step(&x, &s.velocity.x, io.DeltaTime);
        nxn_scroll_step(&y, &s.velocity.y, io.DeltaTime);
        if (x < 0 || x > w->ScrollMax.x) s.velocity.x = 0;
        if (y < 0 || y > w->ScrollMax.y) s.velocity.y = 0;
        ImGui::SetScrollX(w, ImClamp(x, 0.f, w->ScrollMax.x));
        ImGui::SetScrollY(w, ImClamp(y, 0.f, w->ScrollMax.y));
        if (s.velocity.x == 0 && s.velocity.y == 0) s = NxnOsTouchScroll();
        return;
    }
    if (w && io.MouseDown[0] && !s.protected_item) {
        float dx = io.MousePos.x - s.start.x, dy = io.MousePos.y - s.start.y;
        float threshold = 9.0f * nxn_os_scale();
        if (!s.dragging && ((w->ScrollMax.y > 0 && fabsf(dy) > threshold && fabsf(dy) >= fabsf(dx)) ||
                           (w->ScrollMax.x > 0 && fabsf(dx) > threshold && fabsf(dx) > fabsf(dy)))) {
            s.dragging = true;
            s.last = s.start;
            if (fabsf(dy) >= fabsf(dx)) s.last.y += copysignf(threshold, dy);
            else s.last.x += copysignf(threshold, dx);
            ImGui::ClearActiveID();
        }
        if (s.dragging) {
            float dx = io.MousePos.x - s.last.x, dy = io.MousePos.y - s.last.y;
            if (w->ScrollMax.y > 0) ImGui::SetScrollY(w, w->Scroll.y - dy);
            if (w->ScrollMax.x > 0) ImGui::SetScrollX(w, w->Scroll.x - dx);
            if (fabsf(dx) > 0.01f || fabsf(dy) > 0.01f) {
                float dt = (float)ImMax(0.001, ImGui::GetTime() - s.moved_at);
                s.velocity = ImVec2(w->ScrollMax.x > 0 ? -dx / dt : 0, w->ScrollMax.y > 0 ? -dy / dt : 0);
                s.moved_at = ImGui::GetTime();
            }
            /* Keep any child under the finger from acquiring the drag. */
            ImGui::ClearActiveID();
        }
        s.last = io.MousePos;
    }
    if (!io.MouseDown[0] && s.dragging) {
        s.velocity.x = nxn_scroll_release(s.velocity.x, ImGui::GetTime() - s.moved_at);
        s.velocity.y = nxn_scroll_release(s.velocity.y, ImGui::GetTime() - s.moved_at);
        s.dragging = false;
        s.protected_item = 0;
    }
}
static inline void nxn_os__touch_scroll_end() {
    ImGuiContext& g = *ImGui::GetCurrentContext();
    if (g.IO.MouseSource != ImGuiMouseSource_TouchScreen || !ImGui::IsMouseClicked(0)) return;
    NxnOsTouchScroll& s = nxn_os__touch_scroll();
    ImGuiWindow* w = g.HoveredWindow;
    while (w && w->ScrollMax.x <= 0 && w->ScrollMax.y <= 0) w = w->ParentWindow;
    s.window = w ? w->ID : 0;
    s.start = s.last = g.IO.MousePos;
    s.moved_at = ImGui::GetTime();
    if (g.ActiveId && g.InputTextState.ID == g.ActiveId) s.protected_item = g.ActiveId;
}

#ifndef NXN_OS_UI_NO_GL3
/* the OpenGL 3 backend of Dear ImGui (imgui_impl_opengl3.cpp): the frame layer starts its frames and refreshes the
   font texture after a rebuild */
bool ImGui_ImplOpenGL3_CreateFontsTexture();
void ImGui_ImplOpenGL3_DestroyFontsTexture();
void ImGui_ImplOpenGL3_NewFrame();
#endif

typedef enum nxn_os_btn_variant {
    NXN_OS_BTN_DEFAULT = 0,
    NXN_OS_BTN_PRIMARY = 1,
    NXN_OS_BTN_DESTRUCTIVE = 2,
    NXN_OS_BTN_PLAIN = 3,
    NXN_OS_BTN_TOOLBAR = 4
} nxn_os_btn_variant;

/* Text roles: the OS type scale. Pixel size = floor(pt * 1.21 + 0.5) at scale 1 (stb_truetype renders 1.21x smaller
   than the OS's FreeType text at the same nominal size). */
typedef enum nxn_os_text_role {
    NXN_OS_TEXT_TITLE = 0,    /* 19.2 pt bold: the screen title */
    NXN_OS_TEXT_HEADER = 1,   /* 15.2 pt bold: card and section headers */
    NXN_OS_TEXT_BODY = 2,     /* 13.8 pt medium: everything else, control labels */
    NXN_OS_TEXT_CAPTION = 3,  /* 11.5 pt semibold, secondary colour: hints, field labels, metadata */
    NXN_OS_TEXT_STRONG = 4,   /* 13.8 pt semibold: emphasis in body text, selected rows */
    NXN_OS_TEXT_MONO = 5,     /* 12 pt monospace: numbers in tables, code, logs */
    NXN_OS_TEXT_ROLES = 6
} nxn_os_text_role;

/* Spacing steps (the OS's 4 / 8 / 12 / 16 / 24 / 32) and radii, both scaled: nxn_os_sp(), nxn_os_radius(). */
enum { NXN_OS_SP_XS = 0, NXN_OS_SP_S = 1, NXN_OS_SP_M = 2, NXN_OS_SP_L = 3, NXN_OS_SP_XL = 4, NXN_OS_SP_XXL = 5 };
enum { NXN_OS_R_CONTROL = 0, NXN_OS_R_FIELD = 1, NXN_OS_R_ROW = 2, NXN_OS_R_CARD = 3, NXN_OS_R_PILL = 4 };

/* nxn_os_frame_begin_ex flags */
enum {
    NXN_OS_FRAME_NO_WINDOW = 1u << 0,   /* do not open the full-window root (the app calls ImGui::Begin itself) */
    NXN_OS_FRAME_NO_BACKEND = 1u << 1   /* do not call ImGui_ImplOpenGL3_NewFrame (another renderer backend) */
};

/* Canonical OS metrics at scale 1 (the same numbers as source/core/ui.cpp and the script ui.* defaults). */
static const float NXN_OS_CONTROL_H = 30.0f;   /* button, field, dropdown */
static const float NXN_OS_SEGMENT_H = 28.0f;   /* segmented tabs (script ui.segmented default) */
static const float NXN_OS_SWITCH_W = 38.0f, NXN_OS_SWITCH_H = 22.0f;
static const float NXN_OS_BADGE_H = 22.0f, NXN_OS_BADGE_MIN_W = 58.0f;
static const float NXN_OS_PROGRESS_H = 6.0f, NXN_OS_SLIDER_H = 22.0f;
static const float NXN_OS_TOUCH_MIN = 44.0f;   /* icon buttons, rail items, list rows */
static const float NXN_OS_MARGIN = 20.0f;      /* window side margin */
static const float NXN_OS_CARD_RADIUS = 10.0f;

static inline ImVec4 nxn_os_imvec4(uint32_t argb, float alpha_mul = 1.0f) {
    float a = (((argb >> 24) & 0xFFu) / 255.0f) * alpha_mul;
    if (a < 0.0f) a = 0.0f;
    if (a > 1.0f) a = 1.0f;
    return ImVec4(
        ((argb >> 16) & 0xFFu) / 255.0f,
        ((argb >> 8)  & 0xFFu) / 255.0f,
        ( argb        & 0xFFu) / 255.0f,
        a
    );
}

static inline ImU32 nxn_os_u32(uint32_t argb, float alpha_mul = 1.0f) {
    return ImGui::ColorConvertFloat4ToU32(nxn_os_imvec4(argb, alpha_mul));
}

static inline ImU32 nxn_os_lerp_u32(ImU32 a, ImU32 b, float t) {
    if (t <= 0.0f) return a;
    if (t >= 1.0f) return b;
    ImVec4 ca = ImGui::ColorConvertU32ToFloat4(a);
    ImVec4 cb = ImGui::ColorConvertU32ToFloat4(b);
    return ImGui::ColorConvertFloat4ToU32(ImVec4(
        ca.x + (cb.x - ca.x) * t,
        ca.y + (cb.y - ca.y) * t,
        ca.z + (cb.z - ca.z) * t,
        ca.w + (cb.w - ca.w) * t
    ));
}

static inline ImU32 nxn_os_shift_u32(uint32_t argb, float delta, float alpha_mul = 1.0f) {
    ImVec4 c = nxn_os_imvec4(argb, alpha_mul);
    auto clamp01 = [](float v) { return v < 0.0f ? 0.0f : (v > 1.0f ? 1.0f : v); };
    c.x = clamp01(c.x + delta);
    c.y = clamp01(c.y + delta);
    c.z = clamp01(c.z + delta);
    return ImGui::ColorConvertFloat4ToU32(c);
}

static inline ImVec4 nxn_os_clear_color(const nxn_ui_tokens& tok) {
    return nxn_os_imvec4(tok.window_bg, 1.0f);
}

/* The OS light / dark palette and metrics, for a stand-alone .nro (no system tokens) or before the first
   nxn_ui_tokens_get. The frame layer uses it by itself when the system has no tokens. */
static inline void nxn_os_default_tokens(nxn_ui_tokens* t, bool dark) {
    if (!t) return;
    memset(t, 0, sizeof *t);
    t->size = (uint32_t)sizeof *t;
    t->dark = dark ? 1 : 0;
    t->revision = 1;
    t->accent = 0xFF0A84FFu; t->accent_hover = 0xFF3395FFu; t->accent_text = 0xFFFFFFFFu;
    t->window_bg = dark ? 0xFF1E1E1Eu : 0xFFECECECu;
    t->content_bg = dark ? 0xFF262626u : 0xFFFFFFFFu;
    t->sidebar_bg = dark ? 0xFF2A2A2Cu : 0xFFE3E3E6u;
    t->surface = dark ? 0xFF3A3A3Cu : 0xFFFFFFFFu;
    t->surface_hover = dark ? 0xFF454547u : 0xFFF2F2F4u;
    t->surface_pressed = dark ? 0xFF505052u : 0xFFE4E4E8u;
    t->text = dark ? 0xFFF5F5F7u : 0xFF1D1D1Fu;
    t->text_secondary = dark ? 0xFFA1A1A6u : 0xFF6E6E73u;
    t->text_tertiary = dark ? 0xFF6E6E73u : 0xFFA1A1A6u;
    t->separator = dark ? 0xFF3A3A3Cu : 0xFFD9D9DEu;
    t->border = dark ? 0xFF48484Au : 0xFFC9C9CEu;
    t->field_bg = dark ? 0xFF2C2C2Eu : 0xFFFFFFFFu;
    t->field_border = dark ? 0xFF48484Au : 0xFFC9C9CEu;
    t->selection = 0xFF0A84FFu; t->selection_text = 0xFFFFFFFFu;
    t->hover = dark ? 0x1AFFFFFFu : 0x0F000000u;
    t->error = 0xFFFF453Au; t->warning = 0xFFFF9F0Au; t->success = 0xFF30D158u; t->info = 0xFF0A84FFu;
    t->corner_radius = 7.0f; t->corner_radius_field = 6.0f; t->corner_radius_row = 6.0f;
    static const float sp[6] = {4, 8, 12, 16, 24, 32};
    for (int i = 0; i < 6; i++) t->spacing[i] = sp[i];
    t->control_height = 30.0f; t->row_height = 36.0f;
    t->font_small = 12.0f; t->font_body = 14.0f; t->font_large = 16.0f; t->font_title = 22.0f;
    t->text_scale = 1.0f;
}

/* ---------------------------------------------------------------- frame layer state
   One state for the whole app (an inline function: every source file of the app shares it). */
struct NxnOsRowState {
    float x0, y0, h, gap, next_x, right;
    int n;
};
struct NxnOsFrameState {
    bool ever;                 /* nxn_os_frame_begin ran once: the kit rules (scale, minimum sizes, role fonts) apply */
    bool active;               /* between nxn_os_frame_begin and nxn_os_frame_end */
    bool own_window;           /* the root window is open */
    bool own_frame;            /* the kit called ImGui::NewFrame */
    bool tok_ok;
    unsigned flags;
    int fb_w, fb_h, frames;
    float scale;               /* the UI scale of this frame */
    nxn_ui_tokens tok;         /* the kit's copy of the OS tokens (defaults when the system has none) */
    uint32_t app_rev;
    /* fonts */
    ImFont* font[NXN_OS_TEXT_ROLES];
    float font_scale, font_text_scale; /* what the atlas was built for (0: not built) */
    float text_zoom;           /* the app's own text size choice (nxn_os_set_text_zoom), 0 = 1 */
    uint32_t font_bold;
    float want_scale;
    double want_since;
    bool icons_dirty;
    int icon_count;
    uint32_t icon_codes[96];
    ImWchar icon_ranges[2 * 96 + 1];
    void (*uploader)(void);
    /* rows */
    int row_depth;
    NxnOsRowState row[8];
    /* inner right edge of the open cards (rows and fills stop at the card padding) */
    int card_depth;
    float card_right[16];
};

inline NxnOsFrameState& nxn_os_frame_state() {
    static NxnOsFrameState st;  /* zero-initialised */
    return st;
}

static inline bool nxn_os__kit() { return nxn_os_frame_state().ever; }

/* The UI scale (1.0 = the OS's 1280 x 720 layout). 1 before the first nxn_os_frame_begin. */
static inline float nxn_os_scale() {
    const NxnOsFrameState& f = nxn_os_frame_state();
    return (f.ever && f.scale > 0.1f) ? f.scale : 1.0f;
}

/* `px` OS pixels in surface pixels at the current scale, snapped to whole pixels (0.5 and below stay fractional). */
static inline float nxn_os_s(float px) {
    float v = px * nxn_os_scale();
    if (v > 1.0f || v < -1.0f) return floorf(v + 0.5f);
    return v;
}
#define NXN_S(x) nxn_os_s((float)(x))

/* The kit's tokens (the system's, refreshed by the frame layer; defaults in a stand-alone .nro). */
static inline const nxn_ui_tokens& nxn_os_tok() {
    NxnOsFrameState& f = nxn_os_frame_state();
    if (!f.tok_ok) {
        nxn_ui_tokens t = NXN_STRUCT_INIT(nxn_ui_tokens);
        if (nxn_ui_tokens_get(&t) == NXN_OK && (t.text | t.window_bg) != 0) {
            f.tok = t;
        } else {
            const char* th = nxn_info_string(NXN_INFO_THEME);
            nxn_os_default_tokens(&f.tok, th && th[0] == 'd');
        }
        f.tok_ok = true;
    }
    return f.tok;
}

/* Spacing step NXN_OS_SP_XS .. NXN_OS_SP_XXL (4, 8, 12, 16, 24, 32 x scale). */
static inline float nxn_os_sp(int step) {
    static const float def[6] = {4, 8, 12, 16, 24, 32};
    if (step < 0) step = 0;
    if (step > 5) step = 5;
    const nxn_ui_tokens& t = nxn_os_tok();
    float v = t.spacing[step] > 0.5f ? t.spacing[step] : def[step];
    return nxn_os_s(v);
}

/* Radius NXN_OS_R_CONTROL (7), _FIELD (6), _ROW (6), _CARD (10), _PILL (999), scaled. */
static inline float nxn_os_radius(int kind) {
    const nxn_ui_tokens& t = nxn_os_tok();
    switch (kind) {
        case NXN_OS_R_FIELD: return nxn_os_s(t.corner_radius_field > 0.5f ? t.corner_radius_field : 6.0f);
        case NXN_OS_R_ROW: return nxn_os_s(t.corner_radius_row > 0.5f ? t.corner_radius_row : 6.0f);
        case NXN_OS_R_CARD: return nxn_os_s(NXN_OS_CARD_RADIUS);
        case NXN_OS_R_PILL: return 999.0f;
        default: return nxn_os_s(t.corner_radius > 0.5f ? t.corner_radius : 7.0f);
    }
}

/* Vertical space of one spacing step. */
static inline void nxn_os_gap(int step = NXN_OS_SP_M) { ImGui::Dummy(ImVec2(0.0f, nxn_os_sp(step))); }

/* The font of a text role (NULL before the first frame: the current font is used then). */
static inline ImFont* nxn_os_font(nxn_os_text_role role) {
    NxnOsFrameState& f = nxn_os_frame_state();
    if ((int)role < 0 || (int)role >= NXN_OS_TEXT_ROLES) role = NXN_OS_TEXT_BODY;
    return f.font[role];
}
static inline void nxn_os_push_role(nxn_os_text_role role) {
    ImFont* fo = nxn_os_font(role);
    ImGui::PushFont(fo ? fo : ImGui::GetFont());
}
static inline void nxn_os_pop_role() { ImGui::PopFont(); }
/* The kit pushes the role font of a widget only under the frame layer (old apps keep their own font). */
static inline bool nxn_os__push_role_if_kit(nxn_os_text_role role) {
    if (!nxn_os__kit() || !nxn_os_font(role)) return false;
    ImGui::PushFont(nxn_os_font(role));
    return true;
}

/* Right edge of the space the next item may use: the window's content region, inside a card its padding. */
static inline float nxn_os__content_right() {
    float right = ImGui::GetCursorScreenPos().x + ImGui::GetContentRegionAvail().x;
    NxnOsFrameState& f = nxn_os_frame_state();
    if (f.ever && f.card_depth > 0 && f.card_depth <= 16 && f.card_right[f.card_depth - 1] < right)
        right = f.card_right[f.card_depth - 1];
    return right;
}

/* ---------------------------------------------------------------- rows
   nxn_os_row_begin(h) ... nxn_os_row_end(): every nxn_os_* widget and nxn_os_text between them goes on one line, each
   vertically centred in a row of height h (0 = the OS control height), `gap` apart (< 0 = 8 px x scale). */
static inline NxnOsRowState* nxn_os__row() {
    NxnOsFrameState& f = nxn_os_frame_state();
    return f.row_depth > 0 ? &f.row[f.row_depth - 1] : NULL;
}

static inline void nxn_os_row_begin(float height = 0.0f, float gap = -1.0f) {
    NxnOsFrameState& f = nxn_os_frame_state();
    if (f.row_depth >= 8) return;
    NxnOsRowState& r = f.row[f.row_depth++];
    ImVec2 p = ImGui::GetCursorScreenPos();
    float minh = nxn_os_s(NXN_OS_CONTROL_H);
    r.h = height > minh ? height : minh;
    r.gap = gap >= 0.0f ? gap : nxn_os_sp(NXN_OS_SP_S);
    r.x0 = p.x;
    r.y0 = p.y;
    r.next_x = p.x;
    r.right = nxn_os__content_right();
    r.n = 0;
}

static inline void nxn_os_row_end() {
    NxnOsFrameState& f = nxn_os_frame_state();
    if (f.row_depth <= 0) return;
    NxnOsRowState r = f.row[--f.row_depth];
    ImGui::SetCursorScreenPos(ImVec2(r.x0, r.y0));
    float w = r.right - r.x0;
    ImGui::Dummy(ImVec2(w > 1.0f ? w : 1.0f, r.h));
}

/* Width left in the row (or the content region) for the next item. */
static inline float nxn_os__avail() {
    NxnOsRowState* r = nxn_os__row();
    if (!r) {
        float w = nxn_os__content_right() - ImGui::GetCursorScreenPos().x;
        return w > 0.0f ? w : 0.0f;
    }
    float x = r->n == 0 ? r->x0 : r->next_x;
    float w = r->right - x;
    return w > 0.0f ? w : 0.0f;
}

/* `frac` (0..1) of the width left for the next item: nxn_os_fill(0.5f) then nxn_os_fill(1.0f) splits a row in two. */
static inline float nxn_os_fill(float frac = 1.0f) {
    if (frac <= 0.0f) frac = 1.0f;
    if (frac > 1.0f) frac = 1.0f;
    NxnOsRowState* r = nxn_os__row();
    float w = nxn_os__avail();
    /* the remaining items keep their gap: with frac < 1 another item follows */
    if (r && frac < 1.0f) w -= r->gap * (1.0f - frac);
    return floorf(w * frac);
}

/* The next item of the row ends at the right edge (a switch or a button pushed to the right). */
static inline void nxn_os_align_right(float item_w) {
    NxnOsRowState* r = nxn_os__row();
    if (!r) {
        float avail = nxn_os__avail();
        if (avail > item_w) ImGui::SetCursorPosX(ImGui::GetCursorPosX() + avail - item_w);
        return;
    }
    float x = r->right - item_w;
    float min_x = r->n == 0 ? r->x0 : r->next_x;
    r->next_x = x > min_x ? x : min_x;
    if (r->n == 0) r->n = -1;  /* place at next_x even as the first item */
}

/* Places an item of w x h: in a row, beside the previous one and vertically centred; elsewhere at the cursor. */
static inline ImVec2 nxn_os__place(float w, float h) {
    NxnOsRowState* r = nxn_os__row();
    if (!r) return ImGui::GetCursorScreenPos();
    float x = r->n == 0 ? r->x0 : r->next_x;
    float y = floorf(r->y0 + (r->h - h) * 0.5f + 0.5f);
    ImGui::SetCursorScreenPos(ImVec2(x, y));
    r->next_x = x + w + r->gap;
    r->n = r->n < 0 ? 1 : r->n + 1;
    return ImVec2(x, y);
}

/* ---------------------------------------------------------------- text */
/* End of the visible part of an ImGui label ("Save##id" -> "Save"). */
static inline const char* nxn_os__label_end(const char* s) {
    const char* e = strstr(s, "##");
    return e ? e : s + strlen(s);
}

static inline uint32_t nxn_os__role_color(nxn_os_text_role role) {
    const nxn_ui_tokens& t = nxn_os_tok();
    return role == NXN_OS_TEXT_CAPTION ? t.text_secondary : t.text;
}

/* Text in a role's font and colour (Caption: secondary colour). In a row it is centred like the controls. */
static inline void nxn_os_text_colored(nxn_os_text_role role, const char* text, uint32_t argb) {
    const char* s = text ? text : "";
    bool pushed = nxn_os_font(role) != NULL;
    if (pushed) ImGui::PushFont(nxn_os_font(role));
    ImVec2 sz = ImGui::CalcTextSize(s);
    if (nxn_os__row()) nxn_os__place(sz.x, sz.y);
    ImGui::PushStyleColor(ImGuiCol_Text, nxn_os_imvec4(argb));
    ImGui::TextUnformatted(s);
    ImGui::PopStyleColor();
    if (pushed) ImGui::PopFont();
}
static inline void nxn_os_text(nxn_os_text_role role, const char* text) {
    nxn_os_text_colored(role, text, nxn_os__role_color(role));
}
/* Wrapped text (paragraphs) in a role, inside `width` (0 = the width left). */
static inline void nxn_os_text_wrapped(nxn_os_text_role role, const char* text, float width = 0.0f) {
    bool pushed = nxn_os_font(role) != NULL;
    if (pushed) ImGui::PushFont(nxn_os_font(role));
    float w = width > 0.0f ? width : nxn_os__avail();
    ImGui::PushTextWrapPos(ImGui::GetCursorPosX() + w);
    ImGui::PushStyleColor(ImGuiCol_Text, nxn_os_imvec4(nxn_os__role_color(role)));
    ImGui::TextUnformatted(text ? text : "");
    ImGui::PopStyleColor();
    ImGui::PopTextWrapPos();
    if (pushed) ImGui::PopFont();
}

/* Applies full Nexvyn OS Light/Dark/High-Contrast appearance and spacing metrics to ImGuiStyle. */
static inline void nxn_os_apply_style(const nxn_ui_tokens& tok) {
    ImGuiStyle& s = ImGui::GetStyle();
    ImVec4* c = s.Colors;

    c[ImGuiCol_WindowBg]              = nxn_os_imvec4(tok.window_bg);
    c[ImGuiCol_ChildBg]               = nxn_os_imvec4(tok.content_bg);
    c[ImGuiCol_PopupBg]               = nxn_os_imvec4(tok.content_bg);
    c[ImGuiCol_MenuBarBg]             = nxn_os_imvec4(tok.window_bg);
    c[ImGuiCol_TitleBg]               = nxn_os_imvec4(tok.window_bg);
    c[ImGuiCol_TitleBgActive]         = nxn_os_imvec4(tok.window_bg);
    c[ImGuiCol_TitleBgCollapsed]      = nxn_os_imvec4(tok.window_bg);

    c[ImGuiCol_Text]                  = nxn_os_imvec4(tok.text);
    c[ImGuiCol_TextDisabled]          = nxn_os_imvec4(tok.text_secondary);
    c[ImGuiCol_Border]                = nxn_os_imvec4(tok.border);
    c[ImGuiCol_BorderShadow]          = ImVec4(0, 0, 0, 0);
    c[ImGuiCol_Separator]             = nxn_os_imvec4(tok.separator);
    c[ImGuiCol_SeparatorHovered]      = nxn_os_imvec4(tok.accent, 0.7f);
    c[ImGuiCol_SeparatorActive]       = nxn_os_imvec4(tok.accent);

    c[ImGuiCol_Button]                = nxn_os_imvec4(tok.surface);
    c[ImGuiCol_ButtonHovered]         = nxn_os_imvec4(tok.surface_hover);
    c[ImGuiCol_ButtonActive]          = nxn_os_imvec4(tok.surface_pressed);

    c[ImGuiCol_FrameBg]               = nxn_os_imvec4(tok.field_bg);
    c[ImGuiCol_FrameBgHovered]        = nxn_os_imvec4(tok.surface_hover);
    c[ImGuiCol_FrameBgActive]         = nxn_os_imvec4(tok.surface_pressed);

    c[ImGuiCol_CheckMark]             = nxn_os_imvec4(tok.accent);
    c[ImGuiCol_SliderGrab]            = nxn_os_imvec4(tok.accent);
    c[ImGuiCol_SliderGrabActive]      = nxn_os_imvec4(tok.accent_hover);
    c[ImGuiCol_PlotHistogram]         = nxn_os_imvec4(tok.accent);
    c[ImGuiCol_PlotLines]             = nxn_os_imvec4(tok.accent);

    c[ImGuiCol_Header]                = nxn_os_imvec4(tok.selection);
    c[ImGuiCol_HeaderHovered]         = nxn_os_imvec4(tok.hover);
    c[ImGuiCol_HeaderActive]          = nxn_os_imvec4(tok.selection);

    c[ImGuiCol_Tab]                   = nxn_os_imvec4(tok.surface);
    c[ImGuiCol_TabHovered]            = nxn_os_imvec4(tok.surface_hover);
    c[ImGuiCol_TabSelected]           = nxn_os_imvec4(tok.content_bg);

    c[ImGuiCol_TableHeaderBg]         = nxn_os_imvec4(tok.window_bg);
    c[ImGuiCol_TableBorderStrong]     = nxn_os_imvec4(tok.separator);
    c[ImGuiCol_TableBorderLight]      = nxn_os_imvec4(tok.separator, 0.65f);
    c[ImGuiCol_TableRowBg]            = ImVec4(0, 0, 0, 0);
    c[ImGuiCol_TableRowBgAlt]         = tok.dark ? ImVec4(1, 1, 1, 0.025f) : ImVec4(0, 0, 0, 0.022f);

    c[ImGuiCol_ScrollbarBg]           = ImVec4(0, 0, 0, 0);
    c[ImGuiCol_ScrollbarGrab]         = nxn_os_imvec4(tok.text_tertiary, 0.45f);
    c[ImGuiCol_ScrollbarGrabHovered]  = nxn_os_imvec4(tok.text_secondary, 0.65f);
    c[ImGuiCol_ScrollbarGrabActive]   = nxn_os_imvec4(tok.text_secondary, 0.85f);

    c[ImGuiCol_NavHighlight]          = nxn_os_imvec4(tok.accent);
    c[ImGuiCol_ModalWindowDimBg]      = ImVec4(0.0f, 0.0f, 0.0f, tok.dark ? 0.56f : 0.34f);

    float cr = tok.corner_radius > 0.5f ? tok.corner_radius : 7.0f;
    float s1 = tok.spacing[1] > 0.5f ? tok.spacing[1] : 8.0f;
    float s2 = tok.spacing[2] > 0.5f ? tok.spacing[2] : 12.0f;
    float s3 = tok.spacing[3] > 0.5f ? tok.spacing[3] : 16.0f;

    s.WindowRounding    = 0.0f;
    s.ChildRounding     = 10.0f;
    s.FrameRounding     = cr;
    s.PopupRounding     = 8.0f;
    s.ScrollbarRounding = 6.0f;
    s.GrabRounding      = 6.0f;
    s.TabRounding       = 6.0f;

    s.WindowBorderSize  = 0.0f;
    s.ChildBorderSize   = 1.0f;
    s.PopupBorderSize   = 1.0f;
    s.FrameBorderSize   = tok.high_contrast ? 1.0f : 0.0f;

    s.WindowPadding     = ImVec2(s3, s2);
    s.FramePadding      = ImVec2(s2, s1 * 0.72f);
    s.ItemSpacing       = ImVec2(s2, s1);
    s.ItemInnerSpacing  = ImVec2(s1, s1 * 0.5f);
    s.CellPadding       = ImVec2(s2 * 0.75f, s1 * 0.7f);
    s.ScrollbarSize     = 8.0f;
    s.ButtonTextAlign   = ImVec2(0.5f, 0.5f);
}

/* Draws a 1px OS hairline separator across available content width (or explicit width). */
static inline void nxn_os_separator(const nxn_ui_tokens& tok, float inset_x = 0.0f) {
    ImVec2 p = ImGui::GetCursorScreenPos();
    float w = nxn_os__kit() ? nxn_os__avail() : ImGui::GetContentRegionAvail().x;
    float t = nxn_os__kit() ? floorf(nxn_os_scale()) : 1.0f;
    if (t < 1.0f) t = 1.0f;
    if (w > inset_x * 2.0f) {
        ImGui::GetWindowDrawList()->AddRectFilled(
            ImVec2(p.x + inset_x, p.y),
            ImVec2(p.x + w - inset_x, p.y + t),
            nxn_os_u32(tok.separator)
        );
    }
    ImGui::Dummy(ImVec2(0.0f, t));
}

/* Uppercase-style subtle section header inside pages or above grouped cards. */
static inline void nxn_os_section_label(const char* text, const nxn_ui_tokens& tok) {
    bool pushed = nxn_os__push_role_if_kit(NXN_OS_TEXT_CAPTION);
    ImGui::PushStyleColor(ImGuiCol_Text, nxn_os_imvec4(tok.text_secondary));
    ImGui::TextUnformatted(text ? text : "");
    ImGui::PopStyleColor();
    if (pushed) ImGui::PopFont();
}

/* Auto-sizing grouped OS card (matching OS Settings / Performance white/dark cards). */
struct NxnOsCardState {
    ImDrawList* dl;
    ImDrawListSplitter splitter;
    float x0, y0, width, pad_x, pad_y, radius;
    bool custom_border;
    ImU32 border_col;
    ImU32 bg_col;
    bool draw_shadow;
};

static inline NxnOsCardState* nxn_os_card_stack(int* depth_out = NULL) {
    static NxnOsCardState stack[16];
    static int depth = 0;
    if (depth_out) *depth_out = depth;
    return stack;
}

static inline int& nxn_os_card_depth() {
    static int depth = 0;
    return depth;
}

static inline void nxn_os_card_begin_ex(const char* id, float width, float pad_x, float pad_y,
                                        const nxn_ui_tokens& tok, ImU32 bg_col = 0, ImU32 border_col = 0) {
    int& depth = nxn_os_card_depth();
    if (depth >= 15) depth = 15;
    NxnOsCardState& st = nxn_os_card_stack()[depth++];

    float avail = ImGui::GetContentRegionAvail().x;
    float card_w = (width > 0.0f) ? width : avail;
    if (card_w < 1.0f) card_w = 1.0f;

    ImVec2 p = ImGui::GetCursorScreenPos();
    st.dl = ImGui::GetWindowDrawList();
    st.x0 = p.x;
    st.y0 = p.y;
    st.width = card_w;
    st.pad_x = pad_x;
    st.pad_y = pad_y;
    st.radius = nxn_os__kit() ? nxn_os_s(NXN_OS_CARD_RADIUS) : 10.0f;
    st.bg_col = (bg_col != 0) ? bg_col : nxn_os_u32(tok.content_bg);
    st.border_col = (border_col != 0) ? border_col : nxn_os_u32(tok.border);
    st.draw_shadow = !tok.dark;

    st.splitter.Split(st.dl, 2);
    st.splitter.SetCurrentChannel(st.dl, 1);
    NxnOsFrameState& fs = nxn_os_frame_state();
    if (fs.card_depth < 16) fs.card_right[fs.card_depth] = p.x + card_w - pad_x;
    fs.card_depth++;

    ImGui::PushID(id ? id : "card");
    ImGui::BeginGroup();
    ImGui::SetCursorScreenPos(ImVec2(p.x + pad_x, p.y + pad_y));
    ImGui::PushItemWidth(card_w - pad_x * 2.0f);
    ImGui::BeginGroup();
}

/* Card with the OS padding (16 x 13.6 px, scaled under the frame layer). */
static inline void nxn_os_card_begin(const char* id, const nxn_ui_tokens& tok, float width = 0.0f) {
    float p = tok.spacing[3] > 0.5f ? tok.spacing[3] : 16.0f;
    if (nxn_os__kit()) p = nxn_os_s(p);
    nxn_os_card_begin_ex(id, width, p, p * 0.85f, tok);
}

static inline void nxn_os_card_end() {
    int& depth = nxn_os_card_depth();
    if (depth <= 0) return;
    NxnOsCardState& st = nxn_os_card_stack()[--depth];
    NxnOsFrameState& fs = nxn_os_frame_state();
    if (fs.card_depth > 0) fs.card_depth--;

    ImGui::EndGroup();
    ImGui::PopItemWidth();
    float end_y = ImGui::GetItemRectMax().y + st.pad_y;
    float card_h = end_y - st.y0;
    if (card_h < st.pad_y * 2.0f + 8.0f) card_h = st.pad_y * 2.0f + 8.0f;

    ImGui::SetCursorScreenPos(ImVec2(st.x0, st.y0));
    ImGui::Dummy(ImVec2(st.width, card_h));
    ImGui::EndGroup();
    ImGui::PopID();

    st.splitter.SetCurrentChannel(st.dl, 0);
    if (st.draw_shadow) {
        st.dl->AddRectFilled(
            ImVec2(st.x0, st.y0 + 1.5f),
            ImVec2(st.x0 + st.width, st.y0 + card_h + 2.5f),
            IM_COL32(0, 0, 0, 14), st.radius + 1.0f
        );
    }
    st.dl->AddRectFilled(
        ImVec2(st.x0, st.y0),
        ImVec2(st.x0 + st.width, st.y0 + card_h),
        st.bg_col, st.radius
    );
    st.dl->AddRect(
        ImVec2(st.x0, st.y0),
        ImVec2(st.x0 + st.width, st.y0 + card_h),
        st.border_col, st.radius, 0, 1.0f
    );
    st.splitter.Merge(st.dl);
}

/* Segmented capsule tabs matching OS `ui::segmented` (source/core/ui.cpp). Zero-based index. Height 0 = 28 px, the
   script ui.segmented default (NXN_OS_SEGMENT_H; the OS draws it 26-34 px depending on the panel). Width 0 = fit. */
static inline bool nxn_os_segmented_tabs(const char* id, const char* const* labels, int count, int* active,
                                         const nxn_ui_tokens& tok, float height = 0.0f, float width = 0.0f) {
    if (!labels || count <= 0 || !active) return false;
    const bool kit = nxn_os__kit();
    const float S = nxn_os_scale();
    ImGui::PushID(id ? id : "seg");
    bool font_pushed = nxn_os__push_role_if_kit(NXN_OS_TEXT_BODY);

    ImDrawList* dl = ImGui::GetWindowDrawList();
    float h;
    if (kit) {
        float def = nxn_os_s(NXN_OS_SEGMENT_H);
        h = height > def ? height : def;
    } else {
        h = height > 22.0f ? height : NXN_OS_SEGMENT_H;
    }

    float total_w = width;
    if (total_w <= 0.0f) {
        float max_seg = 64.0f * S;
        for (int i = 0; i < count; ++i) {
            float tw = ImGui::CalcTextSize(labels[i] ? labels[i] : "").x + 28.0f * S;
            if (tw > max_seg) max_seg = tw;
        }
        total_w = max_seg * (float)count;
        float avail = nxn_os__avail();
        if (total_w > avail && avail > 40.0f) total_w = avail;
    }
    ImVec2 p = nxn_os__place(total_w, h);
    if (!nxn_os__row()) p = ImGui::GetCursorScreenPos();
    const float in = 2.0f * S, kr = 5.5f * S, sep_in = 7.0f * S;

    ImU32 track_col = tok.dark ? IM_COL32(255, 255, 255, 25) : IM_COL32(0, 0, 0, 16);
    dl->AddRectFilled(p, ImVec2(p.x + total_w, p.y + h), track_col, 7.0f * S);

    float sw = total_w / (float)count;
    bool changed = false;
    ImU32 sep_col = nxn_os_u32(tok.separator);
    ImU32 hover_col = nxn_os_u32(tok.hover);
    ImU32 txt_active = nxn_os_u32(tok.text);
    ImU32 txt_idle = nxn_os_u32(tok.text_secondary);

    for (int i = 0; i < count; ++i) {
        ImVec2 s0(p.x + i * sw, p.y);
        ImVec2 s1(s0.x + sw, p.y + h);
        ImGui::SetCursorScreenPos(s0);
        ImGui::PushID(i);
        bool clicked = ImGui::InvisibleButton("##tab", ImVec2(sw > 4.0f ? sw : 4.0f, h), ImGuiButtonFlags_EnableNav);
        bool hovered = ImGui::IsItemHovered();
        bool held = ImGui::IsItemActive();
        ImGui::PopID();

        if (clicked && *active != i) {
            *active = i;
            changed = true;
        }

        if (*active == i) {
            ImVec2 k0(floorf(s0.x + in + 0.5f), floorf(s0.y + in + 0.5f));
            ImVec2 k1(floorf(s1.x - in + 0.5f), floorf(s1.y - in + 0.5f));
            if (!tok.dark) {
                dl->AddRectFilled(ImVec2(k0.x, k0.y + 1.0f), ImVec2(k1.x, k1.y + 1.5f), IM_COL32(0, 0, 0, 12), kr);
            }
            ImU32 pill_col = tok.dark ? IM_COL32(99, 99, 102, 255) : IM_COL32(255, 255, 255, 255);
            dl->AddRectFilled(k0, k1, pill_col, kr);
            if (!tok.dark) {
                dl->AddRect(k0, k1, IM_COL32(0, 0, 0, 16), kr, 0, 1.0f);
            }
        } else if (hovered || held) {
            dl->AddRectFilled(ImVec2(floorf(s0.x + in + 0.5f), floorf(s0.y + in + 0.5f)),
                              ImVec2(floorf(s1.x - in + 0.5f), floorf(s1.y - in + 0.5f)), hover_col, kr);
        }

        if (i > 0 && *active != i && *active != i - 1) {
            dl->AddLine(ImVec2(floorf(s0.x + 0.5f), s0.y + sep_in), ImVec2(floorf(s0.x + 0.5f), s1.y - sep_in), sep_col, 1.0f);
        }

        const char* lbl = labels[i] ? labels[i] : "";
        ImVec2 tsz = ImGui::CalcTextSize(lbl);
        ImVec2 tp(floorf(s0.x + (sw - tsz.x) * 0.5f + 0.5f), floorf(s0.y + (h - tsz.y) * 0.5f + 0.5f));
        dl->AddText(tp, (*active == i) ? txt_active : txt_idle, lbl);
    }

    ImGui::SetCursorScreenPos(p);
    ImGui::Dummy(ImVec2(total_w, h));
    if (font_pushed) ImGui::PopFont();
    ImGui::PopID();
    return changed;
}

/* OS Pill Switch matching `ui::toggle` with smooth animation in ImGui state storage. 0 = 38 x 22 px. */
static inline bool nxn_os_switch(const char* id, bool* v, const nxn_ui_tokens& tok,
                                 float width = 0.0f, float height = 0.0f) {
    if (!v) return false;
    const bool kit = nxn_os__kit();
    ImGui::PushID(id ? id : "sw");
    ImGuiID anim_id = ImGui::GetID("##anim");
    ImGuiStorage* st = ImGui::GetStateStorage();
    float a = st->GetFloat(anim_id, *v ? 1.0f : 0.0f);

    float h, w;
    if (kit) {
        float dh = nxn_os_s(NXN_OS_SWITCH_H), dw = nxn_os_s(NXN_OS_SWITCH_W);
        h = height > dh ? height : dh;
        w = width > dw ? width : dw;
        if (w < h * 1.4f) w = h * 1.4f;
    } else {
        if (width <= 0.0f) width = NXN_OS_SWITCH_W;
        if (height <= 0.0f) height = NXN_OS_SWITCH_H;
        h = height > 12.0f ? height : 12.0f;
        w = width > h * 1.4f ? width : h * 1.4f;
    }
    nxn_os__place(w, h);
    ImVec2 p = ImGui::GetCursorScreenPos();
    bool clicked = ImGui::InvisibleButton("##btn", ImVec2(w, h), ImGuiButtonFlags_EnableNav);
    bool held = ImGui::IsItemActive();
    if (clicked) *v = !*v;

    float target = *v ? 1.0f : 0.0f;
    float dt = ImGui::GetIO().DeltaTime;
    if (dt > 0.0f && dt < 0.25f) {
        float step = dt * 14.0f;
        if (fabsf(a - target) <= step) a = target;
        else a += (a < target ? step : -step);
    } else {
        a = target;
    }
    st->SetFloat(anim_id, a);

    ImDrawList* dl = ImGui::GetWindowDrawList();
    ImU32 off_col = tok.dark ? IM_COL32(72, 72, 74, 255) : IM_COL32(227, 227, 232, 255);
    ImU32 on_col = nxn_os_u32(tok.accent);
    dl->AddRectFilled(p, ImVec2(p.x + w, p.y + h), nxn_os_lerp_u32(off_col, on_col, a), h * 0.5f);
    if (tok.high_contrast) {
        dl->AddRect(p, ImVec2(p.x + w, p.y + h), nxn_os_u32(tok.border), h * 0.5f, 0, 1.2f);
    } else if (!tok.dark) {
        dl->AddRect(p, ImVec2(p.x + w, p.y + h), IM_COL32(0, 0, 0, (int)(25.0f * (1.0f - a))), h * 0.5f, 0, 0.75f);
    }

    float in = 2.0f * (kit ? nxn_os_scale() : 1.0f);
    float kr = h * 0.5f - in;
    float kx = (p.x + in + kr) + ((p.x + w - in - kr) - (p.x + in + kr)) * a;
    float ky = p.y + h * 0.5f;
    dl->AddCircleFilled(ImVec2(kx, ky + 1.0f), kr, IM_COL32(0, 0, 0, 42));
    dl->AddCircleFilled(ImVec2(kx, ky), kr, held ? IM_COL32(240, 240, 240, 255) : IM_COL32(255, 255, 255, 255));

    ImGui::PopID();
    return clicked;
}

/* OS Button matching `ui::button` variants (`NXN_OS_BTN_PRIMARY`, `DEFAULT`, `DESTRUCTIVE`, `PLAIN`, `TOOLBAR`).
   Size 0 = the OS size (fits the label, 30 px high); a negative width leaves that much room on the right. */
static inline bool nxn_os_button(const char* label, nxn_os_btn_variant variant, const nxn_ui_tokens& tok,
                                 const ImVec2& size = ImVec2(0, 0)) {
    ImVec4 bg, bg_hov, bg_act, fg;
    float border = 0.0f;

    if (variant == NXN_OS_BTN_PRIMARY) {
        bg     = nxn_os_imvec4(tok.accent);
        bg_hov = nxn_os_imvec4(tok.accent_hover);
        bg_act = ImGui::ColorConvertU32ToFloat4(nxn_os_shift_u32(tok.accent, -0.10f));
        fg     = nxn_os_imvec4(tok.accent_text);
    } else if (variant == NXN_OS_BTN_DESTRUCTIVE) {
        bg     = nxn_os_imvec4(tok.error);
        bg_hov = ImGui::ColorConvertU32ToFloat4(nxn_os_shift_u32(tok.error, 0.08f));
        bg_act = ImGui::ColorConvertU32ToFloat4(nxn_os_shift_u32(tok.error, -0.10f));
        fg     = ImVec4(1, 1, 1, 1);
    } else if (variant == NXN_OS_BTN_PLAIN || variant == NXN_OS_BTN_TOOLBAR) {
        bg     = ImVec4(0, 0, 0, 0);
        bg_hov = nxn_os_imvec4(tok.hover);
        bg_act = nxn_os_imvec4(tok.surface_pressed);
        fg     = nxn_os_imvec4(tok.text);
    } else {
        bg     = nxn_os_imvec4(tok.surface);
        bg_hov = nxn_os_imvec4(tok.surface_hover);
        bg_act = nxn_os_imvec4(tok.surface_pressed);
        fg     = nxn_os_imvec4(tok.text);
        border = 1.0f;
    }

    const bool kit = nxn_os__kit();
    bool font_pushed = nxn_os__push_role_if_kit(NXN_OS_TEXT_BODY);
    ImVec2 sz = size;
    if (kit) {
        float minh = nxn_os_s(tok.control_height > 20.0f ? tok.control_height : NXN_OS_CONTROL_H);
        float minw = nxn_os_s(NXN_OS_TOUCH_MIN);
        if (sz.y < minh) sz.y = minh;
        if (sz.x == 0.0f) {
            const char* vis_end = nxn_os__label_end(label ? label : "");
            float tw = ImGui::CalcTextSize(label ? label : "", vis_end).x;
            sz.x = floorf(tw + nxn_os_sp(NXN_OS_SP_L) * 2.0f + 0.5f);
        } else if (sz.x < 0.0f) {
            sz.x = nxn_os__avail() + sz.x;
        }
        if (sz.x < minw) sz.x = minw;
        nxn_os__place(sz.x, sz.y);
    } else if (sz.y <= 0.0f) {
        sz.y = tok.control_height > 20.0f ? tok.control_height : NXN_OS_CONTROL_H;
    }

    ImGui::PushStyleColor(ImGuiCol_Button, bg);
    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, bg_hov);
    ImGui::PushStyleColor(ImGuiCol_ButtonActive, bg_act);
    ImGui::PushStyleColor(ImGuiCol_Text, fg);
    ImGui::PushStyleColor(ImGuiCol_Border, nxn_os_imvec4(tok.border));
    ImGui::PushStyleVar(ImGuiStyleVar_FrameBorderSize, border);
    bool pressed = ImGui::Button(label ? label : "##btn", sz);
    ImGui::PopStyleVar(1);
    ImGui::PopStyleColor(5);
    if (font_pushed) ImGui::PopFont();
    return pressed;
}

/* OS Dropdown matching `ui::popup`: rounded control + accent right chip with double chevron. Zero-based index. */
static inline bool nxn_os_dropdown(const char* id, const char* const* items, int count, int* selected,
                                   float width, const nxn_ui_tokens& tok, float height = 0.0f) {
    if (!items || count <= 0 || !selected) return false;
    const bool kit = nxn_os__kit();
    const float S = nxn_os_scale();
    ImGui::PushID(id ? id : "dd");
    bool font_pushed = nxn_os__push_role_if_kit(NXN_OS_TEXT_BODY);

    /* height: the argument when given, else the OS token (recommended control height), else 28 = the script ui.dropdown default */
    float h = height > 14.0f ? height : (tok.control_height > 14.0f ? tok.control_height : 28.0f);
    float w = width > 40.0f ? width : nxn_os__avail();
    if (kit) {
        float minh = nxn_os_s(tok.control_height > 14.0f ? tok.control_height : NXN_OS_CONTROL_H);
        if (height <= 14.0f) h = minh;
        if (h < minh) h = minh;
        if (w < nxn_os_s(NXN_OS_TOUCH_MIN * 2.0f)) w = nxn_os_s(NXN_OS_TOUCH_MIN * 2.0f);
    }
    nxn_os__place(w, h);
    ImVec2 p = ImGui::GetCursorScreenPos();

    bool clicked = ImGui::InvisibleButton("##ddbtn", ImVec2(w, h), ImGuiButtonFlags_EnableNav);
    bool hovered = ImGui::IsItemHovered();
    bool held = ImGui::IsItemActive();

    ImDrawList* dl = ImGui::GetWindowDrawList();
    float r = (tok.corner_radius_field > 1.0f ? tok.corner_radius_field : 6.0f) * (kit ? S : 1.0f);
    ImU32 fill = held ? nxn_os_u32(tok.surface_pressed)
                      : (hovered ? nxn_os_u32(tok.surface_hover) : nxn_os_u32(tok.surface));
    dl->AddRectFilled(p, ImVec2(p.x + w, p.y + h), fill, r);
    dl->AddRect(p, ImVec2(p.x + w, p.y + h), nxn_os_u32(tok.border), r, 0, 1.0f);

    float chip_w = h * 0.64f;
    if (chip_w < 14.0f) chip_w = 14.0f;
    float pad_chip = h * 0.11f;
    if (pad_chip < 2.0f) pad_chip = 2.0f;
    const float tpad = 10.0f * (kit ? S : 1.0f), cpad = 8.0f * (kit ? S : 1.0f);

    const char* cur = (*selected >= 0 && *selected < count && items[*selected]) ? items[*selected] : "";
    ImVec2 tsz = ImGui::CalcTextSize(cur);
    float tx = floorf(p.x + tpad + 0.5f);
    float ty = floorf(p.y + (h - tsz.y) * 0.5f + 0.5f);
    dl->PushClipRect(ImVec2(p.x + cpad, p.y), ImVec2(p.x + w - chip_w - cpad, p.y + h), true);
    dl->AddText(ImVec2(tx, ty), nxn_os_u32(tok.text), cur);
    dl->PopClipRect();

    /* Trailing accent double-chevron chip matching OS ui::popup */
    ImVec2 c0(p.x + w - chip_w - pad_chip, p.y + pad_chip);
    ImVec2 c1(p.x + w - pad_chip,          p.y + h - pad_chip);
    dl->AddRectFilled(c0, c1, nxn_os_u32(tok.accent), r * 0.7f);
    float cx = (c0.x + c1.x) * 0.5f;
    float cy = (c0.y + c1.y) * 0.5f;
    float cs = h * 0.10f;
    if (cs < 2.0f) cs = 2.0f;
    float lw = kit && S > 1.0f ? 1.2f * S : 1.2f;
    ImU32 chev_col = nxn_os_u32(tok.accent_text);
    dl->AddLine(ImVec2(cx - cs, cy - cs * 0.45f), ImVec2(cx, cy - cs * 1.35f), chev_col, lw);
    dl->AddLine(ImVec2(cx, cy - cs * 1.35f),      ImVec2(cx + cs, cy - cs * 0.45f), chev_col, lw);
    dl->AddLine(ImVec2(cx - cs, cy + cs * 0.45f), ImVec2(cx, cy + cs * 1.35f), chev_col, lw);
    dl->AddLine(ImVec2(cx, cy + cs * 1.35f),      ImVec2(cx + cs, cy + cs * 0.45f), chev_col, lw);

    if (clicked) {
        ImGui::OpenPopup("##dd_popup");
    }

    bool changed = false;
    float pop_max_h = kit ? nxn_os_s(360.0f) : 320.0f, pop_min_w = kit ? nxn_os_s(320.0f) : 320.0f;
    ImGui::SetNextWindowPos(ImVec2(p.x, p.y + h + (kit ? nxn_os_s(2.0f) : 2.0f)));
    ImGui::SetNextWindowSizeConstraints(ImVec2(w, 0.0f), ImVec2(w > pop_min_w ? w : pop_min_w, pop_max_h));
    if (ImGui::BeginPopup("##dd_popup")) {
        float item_h = kit ? nxn_os_s(NXN_OS_TOUCH_MIN) - ImGui::GetStyle().ItemSpacing.y : 0.0f;
        for (int i = 0; i < count; ++i) {
            bool sel = (*selected == i);
            const char* opt = items[i] ? items[i] : "";
            ImGui::PushID(i);
            if (kit) {
                /* touch-sized rows with the text centred vertically */
                ImGui::PushStyleVar(ImGuiStyleVar_SelectableTextAlign, ImVec2(0.0f, 0.5f));
            }
            bool hit = ImGui::Selectable(opt, sel, 0, ImVec2(0.0f, item_h));
            if (kit) ImGui::PopStyleVar();
            ImGui::PopID();
            if (hit) {
                if (*selected != i) {
                    *selected = i;
                    changed = true;
                }
                ImGui::CloseCurrentPopup();
            }
            if (sel) ImGui::SetItemDefaultFocus();
        }
        ImGui::EndPopup();
    }

    if (font_pushed) ImGui::PopFont();
    ImGui::PopID();
    return changed;
}

/* Pill status badge (tinted surface + subtle outline + crisp theme-aware text). */
static inline void nxn_os_badge(const char* text, uint32_t color_argb, const nxn_ui_tokens& tok) {
    const char* s = text ? text : "";
    const bool kit = nxn_os__kit();
    bool font_pushed = nxn_os__push_role_if_kit(NXN_OS_TEXT_CAPTION);
    ImVec2 tsz = ImGui::CalcTextSize(s);
    /* canonical pill: 22 px high, 9 px side padding, at least 58 px wide, text centred */
    float k = kit ? nxn_os_scale() : 1.0f;
    float px = 9.0f * k;
    float bh = kit ? nxn_os_s(NXN_OS_BADGE_H) : 22.0f;
    float bw = tsz.x + px * 2.0f;
    float min_w = kit ? nxn_os_s(NXN_OS_BADGE_MIN_W) : 58.0f;
    if (bw < min_w) bw = min_w;
    bw = floorf(bw + 0.5f);
    float py = (bh - tsz.y) * 0.5f;
    px = (bw - tsz.x) * 0.5f;
    nxn_os__place(bw, bh);
    ImVec2 p = ImGui::GetCursorScreenPos();
    ImDrawList* dl = ImGui::GetWindowDrawList();

    ImU32 fill = nxn_os_u32(color_argb, tok.dark ? 0.18f : 0.12f);
    ImU32 brd  = nxn_os_u32(color_argb, tok.dark ? 0.45f : 0.35f);
    ImU32 fg   = tok.dark ? nxn_os_shift_u32(color_argb, 0.16f) : nxn_os_shift_u32(color_argb, -0.14f);

    dl->AddRectFilled(p, ImVec2(p.x + bw, p.y + bh), fill, bh * 0.5f);
    dl->AddRect(p, ImVec2(p.x + bw, p.y + bh), brd, bh * 0.5f, 0, 1.0f);
    dl->AddText(ImVec2(floorf(p.x + px + 0.5f), floorf(p.y + py + 0.5f)), fg, s);
    ImGui::Dummy(ImVec2(bw, bh));
    if (font_pushed) ImGui::PopFont();
}

/* Sleek OS capsule progress/ratio bar (replaces thick legacy histogram bars). Height 0 = 6 px. */
static inline void nxn_os_progress_bar(float fraction, float width, float height,
                                       uint32_t fill_argb, const nxn_ui_tokens& tok) {
    if (fraction < 0.0f) fraction = 0.0f;
    if (fraction > 1.0f) fraction = 1.0f;
    const bool kit = nxn_os__kit();
    float w = width > 0.0f ? width : nxn_os__avail();
    float h = height > 2.0f ? height : (kit ? nxn_os_s(NXN_OS_PROGRESS_H) : NXN_OS_PROGRESS_H);
    if (kit && h < nxn_os_s(4.0f)) h = nxn_os_s(4.0f);
    nxn_os__place(w, h);
    ImVec2 p = ImGui::GetCursorScreenPos();
    ImDrawList* dl = ImGui::GetWindowDrawList();

    ImU32 track = tok.dark ? IM_COL32(255, 255, 255, 24) : IM_COL32(0, 0, 0, 18);
    ImU32 fill  = nxn_os_u32(fill_argb != 0 ? fill_argb : tok.accent);
    float rad = h * 0.5f;
    dl->AddRectFilled(p, ImVec2(p.x + w, p.y + h), track, rad);
    if (fraction > 0.005f) {
        float fw = w * fraction;
        if (fw < h && fw > 0.0f) fw = (h < w) ? h : w;
        dl->AddRectFilled(p, ImVec2(p.x + fw, p.y + h), fill, rad);
    }
    ImGui::Dummy(ImVec2(w, h));
}

/* OS Pill Slider matching `ui::slider` (thin track + accent fill + round white knob with subtle shadow). 0 = 22 px. */
static inline bool nxn_os_slider(const char* id, float* v, float vmin, float vmax, const nxn_ui_tokens& tok,
                                 float width = 0.0f, float height = 0.0f) {
    if (!v || vmax <= vmin) return false;
    const bool kit = nxn_os__kit();
    ImGui::PushID(id ? id : "sld");
    float w = width > 24.0f ? width : nxn_os__avail();
    float h;
    if (kit) {
        float dh = nxn_os_s(NXN_OS_SLIDER_H);
        h = height > dh ? height : dh;
    } else {
        if (height <= 0.0f) height = NXN_OS_SLIDER_H;
        h = height > 12.0f ? height : 12.0f;
    }
    nxn_os__place(w, h);
    ImVec2 p = ImGui::GetCursorScreenPos();

    /* Use ImGui's slider behavior for navigation/activation, while keeping the
     * OS drawing below. A plain InvisibleButton is neither focusable nor a slider. */
    ImGui::SetNextItemWidth(w);
    ImGui::PushStyleVar(ImGuiStyleVar_FramePadding, ImVec2(0, (h > ImGui::GetFontSize() ? h - ImGui::GetFontSize() : 0) * 0.5f));
    ImGui::PushStyleColor(ImGuiCol_FrameBg, ImVec4(0, 0, 0, 0));
    ImGui::PushStyleColor(ImGuiCol_FrameBgHovered, ImVec4(0, 0, 0, 0));
    ImGui::PushStyleColor(ImGuiCol_FrameBgActive, ImVec4(0, 0, 0, 0));
    ImGui::PushStyleColor(ImGuiCol_SliderGrab, ImVec4(0, 0, 0, 0));
    ImGui::PushStyleColor(ImGuiCol_SliderGrabActive, ImVec4(0, 0, 0, 0));
    float before = *v;
    ImVec2 old_touch_padding = ImGui::GetStyle().TouchExtraPadding;
    if (ImGui::GetIO().MouseSource == ImGuiMouseSource_TouchScreen) {
        float extra = (nxn_os_s(NXN_OS_TOUCH_MIN) - h) * 0.5f;
        if (extra > ImGui::GetStyle().TouchExtraPadding.y) ImGui::GetStyle().TouchExtraPadding.y = extra;
    }
    ImGui::SliderFloat("##sld", v, vmin, vmax, "", ImGuiSliderFlags_NoInput);
    ImGui::GetStyle().TouchExtraPadding = old_touch_padding;
    ImGui::PopStyleColor(5);
    ImGui::PopStyleVar();
    bool held = ImGui::IsItemActive();
    bool hovered = ImGui::IsItemHovered();
    bool changed = before != *v;
    if (held) nxn_os__touch_scroll().protected_item = ImGui::GetItemID();
    float kr = nxn_os_s(10.f);
    float x0 = p.x + kr;
    float x1 = p.x + w - kr;
    if (held && ImGui::IsMouseDown(0) && x1 > x0) {
        float t = (ImGui::GetIO().MousePos.x - x0) / (x1 - x0);
        if (t < 0.0f) t = 0.0f;
        if (t > 1.0f) t = 1.0f;
        float nv = vmin + t * (vmax - vmin);
        if (nv != *v) { *v = nv; changed = true; }
    }

    float frac = (*v - vmin) / (vmax - vmin);
    if (frac < 0.0f) frac = 0.0f;
    if (frac > 1.0f) frac = 1.0f;
    float kx = x0 + (x1 - x0) * frac;
    float cy = p.y + h * 0.5f;
    float th = nxn_os_s(4.f);
    float track_left = p.x + nxn_os_s(2.f), track_right = p.x + w - nxn_os_s(2.f);

    ImDrawList* dl = ImGui::GetWindowDrawList();
    ImU32 track = tok.dark ? IM_COL32(255, 255, 255, 40) : IM_COL32(0, 0, 0, 30);
    dl->AddRectFilled(ImVec2(track_left, cy - th * 0.5f), ImVec2(track_right, cy + th * 0.5f), track, th * 0.5f);
    if (kx > x0 + 1.0f) {
        dl->AddRectFilled(ImVec2(track_left, cy - th * 0.5f), ImVec2(kx, cy + th * 0.5f), nxn_os_u32(tok.accent), th * 0.5f);
    }
    dl->AddCircleFilled(ImVec2(kx, cy + 1.0f), kr, IM_COL32(0, 0, 0, 36));
    dl->AddCircleFilled(ImVec2(kx, cy), kr, (held || hovered) ? IM_COL32(246, 246, 248, 255) : IM_COL32(255, 255, 255, 255));
    if (!tok.dark) {
        dl->AddCircle(ImVec2(kx, cy), kr, IM_COL32(0, 0, 0, 34), 0, 0.8f);
    }
    ImGui::PopID();
    return changed;
}

/* Clean grouped key-value row with optional hairline divider below. */
static inline void nxn_os_kv_row(const char* label, const char* value, const nxn_ui_tokens& tok,
                                 bool with_divider = true, uint32_t value_color = 0) {
    bool font_pushed = nxn_os__push_role_if_kit(NXN_OS_TEXT_BODY);
    float avail = nxn_os__kit() ? nxn_os__avail() : ImGui::GetContentRegionAvail().x;
    float row_h = (tok.row_height > 26.0f ? tok.row_height : 34.0f) - 4.0f;
    if (nxn_os__kit()) row_h = nxn_os_s(row_h);
    ImVec2 p = ImGui::GetCursorScreenPos();
    ImDrawList* dl = ImGui::GetWindowDrawList();

    const char* l = label ? label : "";
    const char* v = value ? value : "";
    ImVec2 lsz = ImGui::CalcTextSize(l);
    ImVec2 vsz = ImGui::CalcTextSize(v);
    float ly = floorf(p.y + (row_h - lsz.y) * 0.5f + 0.5f);
    float vy = floorf(p.y + (row_h - vsz.y) * 0.5f + 0.5f);

    dl->AddText(ImVec2(p.x, ly), nxn_os_u32(tok.text_secondary), l);
    dl->AddText(ImVec2(floorf(p.x + avail - vsz.x + 0.5f), vy),
                value_color != 0 ? nxn_os_u32(value_color) : nxn_os_u32(tok.text), v);
    ImGui::Dummy(ImVec2(avail, row_h));
    if (font_pushed) ImGui::PopFont();
    if (with_divider) nxn_os_separator(tok);
}

/* ================================================================ frame layer widgets (use the kit's tokens) */

/* Icons: the names an app draws (nxn_os_icon_button, nxn_os_rail_item, nxn_os_icon) are merged into the role fonts.
   A new name is added by itself on first use (the atlas is rebuilt once); declaring them up front avoids that frame. */
static inline bool nxn_os__icon_known(uint32_t code) {
    NxnOsFrameState& f = nxn_os_frame_state();
    for (int i = 0; i < f.icon_count; i++)
        if (f.icon_codes[i] == code) return true;
    return false;
}
static inline uint32_t nxn_os_use_icon(const char* name) {
    if (!name || !name[0]) return 0;
    uint32_t code = nxn_ui_icon_code(name);
    if (!code || code > 0xFFFF) return 0;
    NxnOsFrameState& f = nxn_os_frame_state();
    if (!nxn_os__icon_known(code) && f.icon_count < 96) {
        f.icon_codes[f.icon_count++] = code;
        f.icons_dirty = true;
    }
    return code;
}
static inline void nxn_os_use_icons(const char* const* names, int count) {
    for (int i = 0; names && i < count; i++) nxn_os_use_icon(names[i]);
}
/* UTF-8 of an icon (empty when the system has no such icon or the glyph is not in the atlas yet). */
static inline const char* nxn_os_icon(const char* name) {
    static char buf[8][8];
    static int slot = 0;
    char* out = buf[slot = (slot + 1) & 7];
    out[0] = 0;
    uint32_t c = nxn_os_use_icon(name);
    ImFont* fo = nxn_os_font(NXN_OS_TEXT_BODY);
    if (!c || !fo || !fo->FindGlyphNoFallback((ImWchar)c)) return out;
    if (c < 0x800) {
        out[0] = (char)(0xC0 | (c >> 6));
        out[1] = (char)(0x80 | (c & 0x3F));
        out[2] = 0;
    } else {
        out[0] = (char)(0xE0 | (c >> 12));
        out[1] = (char)(0x80 | ((c >> 6) & 0x3F));
        out[2] = (char)(0x80 | (c & 0x3F));
        out[3] = 0;
    }
    return out;
}

/* Square 44 px (touch target) button with a system icon; `fallback` is drawn when the icon is unavailable. */
static inline bool nxn_os_icon_button(const char* id, const char* icon_name, const char* fallback = NULL,
                                      nxn_os_btn_variant variant = NXN_OS_BTN_PLAIN, float size = 0.0f) {
    const nxn_ui_tokens& tok = nxn_os_tok();
    float d = nxn_os_s(NXN_OS_TOUCH_MIN);
    float w = size > d ? size : d;
    ImGui::PushID(id ? id : "ib");
    nxn_os__place(w, w);
    ImVec2 p = ImGui::GetCursorScreenPos();
    bool clicked = ImGui::InvisibleButton("##ib", ImVec2(w, w), ImGuiButtonFlags_EnableNav);
    bool hov = ImGui::IsItemHovered(), held = ImGui::IsItemActive();
    ImDrawList* dl = ImGui::GetWindowDrawList();
    float r = nxn_os_radius(NXN_OS_R_CONTROL);
    ImU32 bg = 0, fg = nxn_os_u32(tok.text);
    if (variant == NXN_OS_BTN_PRIMARY) {
        bg = nxn_os_u32(held ? tok.accent_hover : tok.accent);
        fg = nxn_os_u32(tok.accent_text);
    } else if (variant == NXN_OS_BTN_DESTRUCTIVE) {
        bg = nxn_os_u32(tok.error);
        fg = IM_COL32(255, 255, 255, 255);
    } else if (variant == NXN_OS_BTN_DEFAULT) {
        bg = nxn_os_u32(held ? tok.surface_pressed : (hov ? tok.surface_hover : tok.surface));
    } else if (held || hov) {
        bg = nxn_os_u32(held ? tok.surface_pressed : tok.hover);
    }
    if (bg) dl->AddRectFilled(p, ImVec2(p.x + w, p.y + w), bg, r);
    if (variant == NXN_OS_BTN_DEFAULT) dl->AddRect(p, ImVec2(p.x + w, p.y + w), nxn_os_u32(tok.border), r, 0, 1.0f);
    const char* g = nxn_os_icon(icon_name);
    const char* s = g[0] ? g : (fallback ? fallback : "?");
    ImFont* fo = nxn_os_font(g[0] ? NXN_OS_TEXT_HEADER : NXN_OS_TEXT_BODY);
    if (!fo) fo = ImGui::GetFont();
    float fs = fo->FontSize * fo->Scale;
    ImVec2 ts = fo->CalcTextSizeA(fs, 1e6f, 0.0f, s);
    dl->AddText(fo, fs, ImVec2(floorf(p.x + (w - ts.x) * 0.5f + 0.5f), floorf(p.y + (w - ts.y) * 0.5f + 0.5f)), fg, s);
    ImGui::PopID();
    return clicked;
}

/* A button with a clear on / off state: off = plain control with "OFF", on = accent tint, accent outline and "ON".
   Toggles *on when pressed and returns true then. Width 0 = fit the label. */
static inline bool nxn_os_toggle_button(const char* label, bool* on, float width = 0.0f,
                                        const char* on_text = "ON", const char* off_text = "OFF") {
    if (!on) return false;
    const nxn_ui_tokens& tok = nxn_os_tok();
    ImGui::PushID(label ? label : "tg");
    bool fp = nxn_os__push_role_if_kit(NXN_OS_TEXT_BODY);
    const char* lbl = label ? label : "";
    const char* lbl_end = nxn_os__label_end(lbl);
    const char* st = *on ? (on_text ? on_text : "ON") : (off_text ? off_text : "OFF");
    ImFont* cap = nxn_os_font(NXN_OS_TEXT_CAPTION);
    if (!cap) cap = ImGui::GetFont();
    float cfs = cap->FontSize * cap->Scale;
    ImVec2 lsz = ImGui::CalcTextSize(lbl, lbl_end);
    ImVec2 ssz = cap->CalcTextSizeA(cfs, 1e6f, 0.0f, st);
    float pad = nxn_os_sp(NXN_OS_SP_M), chip_px = nxn_os_s(7.0f), gap = nxn_os_sp(NXN_OS_SP_S);
    float chip_w = ssz.x + chip_px * 2.0f;
    float h = nxn_os_s(tok.control_height > 20.0f ? tok.control_height : NXN_OS_CONTROL_H);
    float w = width > 0.0f ? width : floorf(pad + lsz.x + gap + chip_w + nxn_os_s(5.0f) + 0.5f);
    if (w < nxn_os_s(NXN_OS_TOUCH_MIN)) w = nxn_os_s(NXN_OS_TOUCH_MIN);
    nxn_os__place(w, h);
    ImVec2 p = ImGui::GetCursorScreenPos();
    bool clicked = ImGui::InvisibleButton("##tg", ImVec2(w, h), ImGuiButtonFlags_EnableNav);
    bool hov = ImGui::IsItemHovered(), held = ImGui::IsItemActive();
    if (clicked) *on = !*on;
    ImDrawList* dl = ImGui::GetWindowDrawList();
    float r = nxn_os_radius(NXN_OS_R_CONTROL);
    if (*on) {
        dl->AddRectFilled(p, ImVec2(p.x + w, p.y + h), nxn_os_u32(tok.accent, held ? 0.26f : (hov ? 0.20f : 0.14f)), r);
        dl->AddRect(p, ImVec2(p.x + w, p.y + h), nxn_os_u32(tok.accent), r, 0, nxn_os_scale() > 1.2f ? 2.0f : 1.5f);
    } else {
        dl->AddRectFilled(p, ImVec2(p.x + w, p.y + h),
                          nxn_os_u32(held ? tok.surface_pressed : (hov ? tok.surface_hover : tok.surface)), r);
        dl->AddRect(p, ImVec2(p.x + w, p.y + h), nxn_os_u32(tok.border), r, 0, 1.0f);
    }
    dl->AddText(ImVec2(floorf(p.x + pad + 0.5f), floorf(p.y + (h - lsz.y) * 0.5f + 0.5f)),
                nxn_os_u32(*on ? (tok.dark ? tok.text : tok.accent) : tok.text), lbl, lbl_end);
    float ch = floorf(cfs + nxn_os_s(6.0f));
    ImVec2 c0(floorf(p.x + w - chip_w - nxn_os_s(5.0f)), floorf(p.y + (h - ch) * 0.5f));
    ImVec2 c1(c0.x + chip_w, c0.y + ch);
    dl->AddRectFilled(c0, c1, *on ? nxn_os_u32(tok.accent) : nxn_os_u32(tok.text_tertiary, 0.22f), ch * 0.5f);
    dl->AddText(cap, cfs, ImVec2(floorf(c0.x + chip_px + 0.5f), floorf(c0.y + (ch - ssz.y) * 0.5f + 0.5f)),
                nxn_os_u32(*on ? tok.accent_text : tok.text_secondary), st);
    if (fp) ImGui::PopFont();
    ImGui::PopID();
    return clicked;
}

/* Dropdown (nxn_os_dropdown) with the kit's tokens and the OS control height. Width 0 = the width left. */
static inline bool nxn_os_select(const char* id, const char* const* items, int count, int* selected, float width = 0.0f) {
    return nxn_os_dropdown(id, items, count, selected, width, nxn_os_tok(), 0.0f);
}

/* Single-line text field in the OS look (field colours, radius, 30 px), with a placeholder. Width 0 = the width left. */
static inline bool nxn_os_input(const char* id, const char* hint, char* buf, size_t cap, float width = 0.0f,
                                ImGuiInputTextFlags flags = 0) {
    if (!buf || cap == 0) return false;
    const nxn_ui_tokens& tok = nxn_os_tok();
    bool fp = nxn_os__push_role_if_kit(NXN_OS_TEXT_BODY);
    float h = nxn_os_s(tok.control_height > 20.0f ? tok.control_height : NXN_OS_CONTROL_H);
    float w = width > 0.0f ? width : nxn_os__avail();
    if (w < nxn_os_s(NXN_OS_TOUCH_MIN)) w = nxn_os_s(NXN_OS_TOUCH_MIN);
    nxn_os__place(w, h);
    float fpy = floorf((h - ImGui::GetFontSize()) * 0.5f);
    ImGui::PushStyleVar(ImGuiStyleVar_FramePadding, ImVec2(nxn_os_sp(NXN_OS_SP_M), fpy > 0.0f ? fpy : 0.0f));
    ImGui::PushStyleVar(ImGuiStyleVar_FrameRounding, nxn_os_radius(NXN_OS_R_FIELD));
    ImGui::PushStyleVar(ImGuiStyleVar_FrameBorderSize, 1.0f);
    ImGui::PushStyleColor(ImGuiCol_FrameBg, nxn_os_imvec4(tok.field_bg));
    ImGui::PushStyleColor(ImGuiCol_Border, nxn_os_imvec4(tok.field_border ? tok.field_border : tok.border));
    ImGui::PushStyleColor(ImGuiCol_TextDisabled, nxn_os_imvec4(tok.text_tertiary ? tok.text_tertiary : tok.text_secondary));
    ImGui::SetNextItemWidth(w);
    char lid[96];
    snprintf(lid, sizeof lid, "##%s", id ? id : "in");
    bool changed = ImGui::InputTextWithHint(lid, hint ? hint : "", buf, cap, flags);
    ImGui::PopStyleColor(3);
    ImGui::PopStyleVar(3);
    if (fp) ImGui::PopFont();
    return changed;
}

/* Multi-line text box in the OS look. `size` 0 = the width left x 4 lines. */
static inline bool nxn_os_input_multiline(const char* id, char* buf, size_t cap, const ImVec2& size = ImVec2(0, 0),
                                          ImGuiInputTextFlags flags = 0) {
    if (!buf || cap == 0) return false;
    const nxn_ui_tokens& tok = nxn_os_tok();
    bool fp = nxn_os__push_role_if_kit(NXN_OS_TEXT_BODY);
    ImVec2 sz = size;
    if (sz.x <= 0.0f) sz.x = nxn_os__avail();
    if (sz.y <= 0.0f) sz.y = floorf(ImGui::GetTextLineHeightWithSpacing() * 4.0f + nxn_os_sp(NXN_OS_SP_M));
    nxn_os__place(sz.x, sz.y);
    ImGui::PushStyleVar(ImGuiStyleVar_FramePadding, ImVec2(nxn_os_sp(NXN_OS_SP_M), nxn_os_sp(NXN_OS_SP_S)));
    ImGui::PushStyleVar(ImGuiStyleVar_FrameRounding, nxn_os_radius(NXN_OS_R_FIELD));
    ImGui::PushStyleVar(ImGuiStyleVar_FrameBorderSize, 1.0f);
    ImGui::PushStyleColor(ImGuiCol_FrameBg, nxn_os_imvec4(tok.field_bg));
    ImGui::PushStyleColor(ImGuiCol_Border, nxn_os_imvec4(tok.field_border ? tok.field_border : tok.border));
    char lid[96];
    snprintf(lid, sizeof lid, "##%s", id ? id : "ml");
    bool changed = ImGui::InputTextMultiline(lid, buf, cap, sz, flags);
    ImGui::PopStyleColor(2);
    ImGui::PopStyleVar(3);
    if (fp) ImGui::PopFont();
    return changed;
}

/* Integer slider on top of nxn_os_slider. */
static inline bool nxn_os_slider_int(const char* id, int* v, int vmin, int vmax, float width = 0.0f) {
    if (!v || vmax <= vmin) return false;
    float f = (float)*v;
    bool ch = nxn_os_slider(id, &f, (float)vmin, (float)vmax, nxn_os_tok(), width, 0.0f);
    int nv = (int)floorf(f + 0.5f);
    if (ch && nv != *v) {
        *v = nv;
        return true;
    }
    return false;
}

/* Row with a label on the left and a switch on the right; the whole row toggles (touch friendly). */
static inline bool nxn_os_switch_row(const char* label, bool* v) {
    if (!v) return false;
    const nxn_ui_tokens& tok = nxn_os_tok();
    ImGui::PushID(label ? label : "swr");
    float h = nxn_os_s(NXN_OS_TOUCH_MIN);
    ImVec2 p = ImGui::GetCursorScreenPos();
    float w = nxn_os__avail();
    ImGui::SetNextItemAllowOverlap();
    bool clicked = ImGui::InvisibleButton("##row", ImVec2(w > 1.0f ? w : 1.0f, h), ImGuiButtonFlags_EnableNav);
    ImGui::SetCursorScreenPos(p);
    nxn_os_row_begin(h);
    nxn_os_text(NXN_OS_TEXT_BODY, label);
    nxn_os_align_right(nxn_os_s(NXN_OS_SWITCH_W));
    bool sw = nxn_os_switch("##sw", v, tok);
    nxn_os_row_end();
    if (clicked && !sw) *v = !*v;
    ImGui::PopID();
    return clicked || sw;
}

/* Form row: `label` in a left column (`label_frac` of the width), then the next widget(s) on the same line, centred.
   Close it with nxn_os_row_end(), or use the one-call form nxn_os_labeled(label, [&] { widget; }). */
static inline void nxn_os_labeled_begin(const char* label, float label_frac = 0.36f, float height = 0.0f) {
    float avail = nxn_os__avail();
    if (label_frac <= 0.05f || label_frac >= 0.9f) label_frac = 0.36f;
    nxn_os_row_begin(height);
    NxnOsRowState* r = nxn_os__row();
    nxn_os_text(NXN_OS_TEXT_BODY, label);
    if (r) {
        float col = r->x0 + floorf(avail * label_frac);
        if (r->next_x < col) r->next_x = col;
    }
}
template <typename F>
static inline void nxn_os_labeled(const char* label, F&& widget, float label_frac = 0.36f) {
    nxn_os_labeled_begin(label, label_frac);
    widget();
    nxn_os_row_end();
}

/* Side panel (navigation rail) in the sidebar colour. Put nxn_os_rail_item rows inside. Width 0 = 220 px. */
static inline bool nxn_os_sidebar_begin(const char* id, float width = 0.0f, float height = 0.0f) {
    const nxn_ui_tokens& tok = nxn_os_tok();
    float w = width > 0.0f ? width : nxn_os_s(220.0f);
    ImGui::PushStyleColor(ImGuiCol_ChildBg, nxn_os_imvec4(tok.sidebar_bg ? tok.sidebar_bg : tok.window_bg));
    ImGui::PushStyleVar(ImGuiStyleVar_ItemSpacing, ImVec2(nxn_os_sp(NXN_OS_SP_S), nxn_os_sp(NXN_OS_SP_XS)));  /* inside */
    ImGui::PushStyleVar(ImGuiStyleVar_ChildRounding, nxn_os_radius(NXN_OS_R_CARD));
    ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(nxn_os_sp(NXN_OS_SP_S), nxn_os_sp(NXN_OS_SP_S)));
    bool open = ImGui::BeginChild(id ? id : "##sidebar", ImVec2(w, height), ImGuiChildFlags_AlwaysUseWindowPadding);
    ImGui::PopStyleVar(2);
    return open;
}
static inline void nxn_os_sidebar_end() {
    ImGui::EndChild();
    ImGui::PopStyleVar(1);
    ImGui::PopStyleColor(1);
}

/* Navigation rail / sidebar row: 44 px, icon + label, the selected one in the selection colour. Returns true on click. */
static inline bool nxn_os_rail_item(const char* id, const char* icon_name, const char* label, bool selected) {
    const nxn_ui_tokens& tok = nxn_os_tok();
    ImGui::PushID(id ? id : "rail");
    float h = nxn_os_s(NXN_OS_TOUCH_MIN);
    float w = nxn_os__avail();
    nxn_os__place(w, h);
    ImVec2 p = ImGui::GetCursorScreenPos();
    bool clicked = ImGui::InvisibleButton("##rail", ImVec2(w > 1.0f ? w : 1.0f, h), ImGuiButtonFlags_EnableNav);
    bool hov = ImGui::IsItemHovered(), held = ImGui::IsItemActive();
    ImDrawList* dl = ImGui::GetWindowDrawList();
    float r = nxn_os_radius(NXN_OS_R_ROW);
    if (selected) dl->AddRectFilled(p, ImVec2(p.x + w, p.y + h), nxn_os_u32(tok.selection), r);
    else if (held || hov) dl->AddRectFilled(p, ImVec2(p.x + w, p.y + h), nxn_os_u32(held ? tok.surface_pressed : tok.hover), r);
    ImU32 fg = nxn_os_u32(selected ? tok.selection_text : tok.text);
    float x = p.x + nxn_os_sp(NXN_OS_SP_M);
    const char* g = nxn_os_icon(icon_name);
    ImFont* body = nxn_os_font(NXN_OS_TEXT_BODY);
    ImFont* strong = nxn_os_font(selected ? NXN_OS_TEXT_STRONG : NXN_OS_TEXT_BODY);
    if (!body) body = ImGui::GetFont();
    if (!strong) strong = body;
    if (g[0]) {
        ImFont* ifo = nxn_os_font(NXN_OS_TEXT_HEADER);
        if (!ifo) ifo = body;
        float fs = ifo->FontSize * ifo->Scale;
        ImVec2 ts = ifo->CalcTextSizeA(fs, 1e6f, 0.0f, g);
        float box = nxn_os_s(22.0f);
        dl->AddText(ifo, fs, ImVec2(floorf(x + (box - ts.x) * 0.5f + 0.5f), floorf(p.y + (h - ts.y) * 0.5f + 0.5f)),
                    selected ? fg : nxn_os_u32(tok.accent), g);
        x += box + nxn_os_sp(NXN_OS_SP_M);
    }
    const char* l = label ? label : "";
    float fs = strong->FontSize * strong->Scale;
    ImVec2 ts = strong->CalcTextSizeA(fs, 1e6f, 0.0f, l);
    dl->PushClipRect(p, ImVec2(p.x + w - nxn_os_sp(NXN_OS_SP_S), p.y + h), true);
    dl->AddText(strong, fs, ImVec2(floorf(x + 0.5f), floorf(p.y + (h - ts.y) * 0.5f + 0.5f)), fg, l);
    dl->PopClipRect();
    ImGui::PopID();
    return clicked;
}

/* List row: 44 px (56 with a subtitle), title + optional subtitle on the left, optional trailing text and a chevron on
   the right, hairline below. Returns true on click. */
static inline bool nxn_os_list_row(const char* id, const char* title, const char* subtitle = NULL,
                                   const char* trailing = NULL, bool selected = false, bool chevron = true) {
    const nxn_ui_tokens& tok = nxn_os_tok();
    ImGui::PushID(id ? id : "lr");
    bool two = subtitle && subtitle[0];
    float h = nxn_os_s(two ? 56.0f : NXN_OS_TOUCH_MIN);
    float w = nxn_os__avail();
    nxn_os__place(w, h);
    ImVec2 p = ImGui::GetCursorScreenPos();
    bool clicked = ImGui::InvisibleButton("##lr", ImVec2(w > 1.0f ? w : 1.0f, h), ImGuiButtonFlags_EnableNav);
    bool hov = ImGui::IsItemHovered(), held = ImGui::IsItemActive();
    ImDrawList* dl = ImGui::GetWindowDrawList();
    float r = nxn_os_radius(NXN_OS_R_ROW);
    if (selected) dl->AddRectFilled(p, ImVec2(p.x + w, p.y + h), nxn_os_u32(tok.selection), r);
    else if (held || hov) dl->AddRectFilled(p, ImVec2(p.x + w, p.y + h), nxn_os_u32(held ? tok.surface_pressed : tok.hover), r);
    ImFont* tf = nxn_os_font(NXN_OS_TEXT_BODY);
    ImFont* sf = nxn_os_font(NXN_OS_TEXT_CAPTION);
    if (!tf) tf = ImGui::GetFont();
    if (!sf) sf = tf;
    float tfs = tf->FontSize * tf->Scale, sfs = sf->FontSize * sf->Scale;
    float pad = nxn_os_sp(NXN_OS_SP_M);
    ImU32 c_title = nxn_os_u32(selected ? tok.selection_text : tok.text);
    ImU32 c_sub = selected ? nxn_os_u32(tok.selection_text, 0.8f) : nxn_os_u32(tok.text_secondary);
    float right = p.x + w - pad;
    if (chevron) {
        float cs = nxn_os_s(4.0f), cx = right - cs, cy = p.y + h * 0.5f;
        float lw = nxn_os_scale() > 1.2f ? 2.0f : 1.5f;
        dl->AddLine(ImVec2(cx - cs, cy - cs * 1.6f), ImVec2(cx + cs * 0.4f, cy), c_sub, lw);
        dl->AddLine(ImVec2(cx + cs * 0.4f, cy), ImVec2(cx - cs, cy + cs * 1.6f), c_sub, lw);
        right -= cs * 2.0f + nxn_os_sp(NXN_OS_SP_S);
    }
    if (trailing && trailing[0]) {
        ImVec2 ts = tf->CalcTextSizeA(tfs, 1e6f, 0.0f, trailing);
        dl->AddText(tf, tfs, ImVec2(floorf(right - ts.x + 0.5f), floorf(p.y + (h - ts.y) * 0.5f + 0.5f)), c_sub, trailing);
        right -= ts.x + nxn_os_sp(NXN_OS_SP_M);
    }
    dl->PushClipRect(p, ImVec2(right > p.x ? right : p.x, p.y + h), true);
    const char* t = title ? title : "";
    if (two) {
        float gap = nxn_os_s(2.0f);
        float th = tfs + gap + sfs;
        float y0 = floorf(p.y + (h - th) * 0.5f + 0.5f);
        dl->AddText(tf, tfs, ImVec2(p.x + pad, y0), c_title, t);
        dl->AddText(sf, sfs, ImVec2(p.x + pad, floorf(y0 + tfs + gap)), c_sub, subtitle);
    } else {
        dl->AddText(tf, tfs, ImVec2(p.x + pad, floorf(p.y + (h - tfs) * 0.5f + 0.5f)), c_title, t);
    }
    dl->PopClipRect();
    if (!selected) {
        float t1 = floorf(nxn_os_scale());
        if (t1 < 1.0f) t1 = 1.0f;
        dl->AddRectFilled(ImVec2(p.x + pad, p.y + h - t1), ImVec2(p.x + w, p.y + h), nxn_os_u32(tok.separator));
    }
    ImGui::PopID();
    return clicked;
}

/* ================================================================ frame begin / end */

/* After a font rebuild: the renderer needs the new atlas texture. Default: the OpenGL 3 backend recreates it. */
static inline void nxn_os_set_font_uploader(void (*fn)(void)) { nxn_os_frame_state().uploader = fn; }

/* The app's own text size on top of the user's accessibility size (a "Large text" option): 0.8 .. 1.6, 1 = normal.
   The fonts are rebuilt at the new size (sharp, not stretched). */
static inline void nxn_os_set_text_zoom(float zoom) {
    if (zoom < 0.8f) zoom = 0.8f;
    if (zoom > 1.6f) zoom = 1.6f;
    nxn_os_frame_state().text_zoom = zoom;
}

/* UI scale from the system (window surface scale), a stand-alone screen, or 1.0. */
static inline float nxn_os__compute_scale(const nxn_ui_tokens& t, int fb_w, int fb_h) {
    float s = 0.0f;
    if (t.size >= offsetof(nxn_ui_tokens, ui_scale) + sizeof(float) && t.ui_scale > 0.25f) {
        s = t.ui_scale;
    } else {
        const char* os = nxn_info_string(NXN_INFO_OS_VERSION);
        if (!os || !os[0]) {  /* a stand-alone .nro owns the whole screen: 1280 x 720 is 1.0 */
            float sx = fb_w / 1280.0f, sy = fb_h / 720.0f;
            s = sx < sy ? sx : sy;
            if (s < 1.0f) s = 1.0f;
        } else {
            s = 1.0f;  /* a system before ui_scale: the surface is in OS pixels at the default interface size */
        }
    }
    if (s < 0.5f) s = 0.5f;
    if (s > 3.0f) s = 3.0f;
    return floorf(s * 20.0f + 0.5f) / 20.0f;  /* steps of 0.05: no rebuild for rounding noise */
}

static inline void nxn_os__build_fonts(NxnOsFrameState& f, float scale) {
    static const float pt[NXN_OS_TEXT_ROLES] = {19.2f, 15.2f, 13.8f, 11.5f, 13.8f, 12.0f};
    ImGuiIO& io = ImGui::GetIO();
    float ts = (f.tok.text_scale > 0.5f ? f.tok.text_scale : 1.0f) * (f.text_zoom > 0.5f ? f.text_zoom : 1.0f);
    bool bold = f.tok.bold_text != 0;
    int n = 0;
    for (int i = 0; i < f.icon_count && n < 2 * 96; i++) {
        f.icon_ranges[n++] = (ImWchar)f.icon_codes[i];
        f.icon_ranges[n++] = (ImWchar)f.icon_codes[i];
    }
    f.icon_ranges[n] = 0;
    const ImWchar* icons = n ? f.icon_ranges : NULL;
    io.Fonts->Clear();
    for (int r = 0; r < NXN_OS_TEXT_ROLES; r++) {
        nxn_ui_font face = NXN_UI_FONT_MEDIUM;
        if (r == NXN_OS_TEXT_TITLE || r == NXN_OS_TEXT_HEADER) face = NXN_UI_FONT_BOLD;
        else if (r == NXN_OS_TEXT_CAPTION || r == NXN_OS_TEXT_STRONG) face = bold ? NXN_UI_FONT_BOLD : NXN_UI_FONT_SEMIBOLD;
        else if (r == NXN_OS_TEXT_MONO) face = bold ? NXN_UI_FONT_MONO_BOLD : NXN_UI_FONT_MONO;
        else if (bold) face = NXN_UI_FONT_SEMIBOLD;
        float px = floorf(pt[r] * 1.21f * ts * scale + 0.5f);
        if (px < 8.0f) px = 8.0f;
        unsigned fl = (r == NXN_OS_TEXT_MONO) ? (unsigned)NXN_IMGUI_NO_CJK : 0u;
        f.font[r] = nxn_imgui_add_font(io.Fonts, face, px, fl, r == NXN_OS_TEXT_MONO ? NULL : icons);
    }
    io.FontDefault = f.font[NXN_OS_TEXT_BODY];
    io.Fonts->Build();
    f.font_scale = scale;
    f.font_text_scale = ts;
    f.font_bold = bold ? 1u : 0u;
    f.icons_dirty = false;
    if (f.uploader) {
        f.uploader();
    } else {
#ifndef NXN_OS_UI_NO_GL3
        if (io.BackendRendererUserData) ImGui_ImplOpenGL3_DestroyFontsTexture();  /* NewFrame makes the new one */
#endif
    }
}

/* Starts a frame of an OS-look app: refreshes the tokens and the UI scale, rebuilds the fonts when needed, applies the
   scaled style, starts the ImGui frame (backend + ImGui::NewFrame) and opens a full-window root with the OS margins.
   `tok` may be NULL (the kit reads the system tokens itself); fb_w x fb_h is the surface the app renders into. */
static inline bool nxn_os_frame_begin_ex(const nxn_ui_tokens* tok, int fb_w, int fb_h, unsigned flags) {
    NxnOsFrameState& f = nxn_os_frame_state();
    ImGuiIO& io = ImGui::GetIO();
    if (f.active) return true;  /* nested call: one frame at a time */
    if (fb_w <= 0 || fb_h <= 0) {
        fb_w = (int)io.DisplaySize.x;
        fb_h = (int)io.DisplaySize.y;
    }
    bool fb_changed = fb_w != f.fb_w || fb_h != f.fb_h;
    uint32_t app_rev = tok ? tok->revision : 0u;
    if (!f.ever || fb_changed || app_rev != f.app_rev || (f.frames % 60) == 0) {
        nxn_ui_tokens t = NXN_STRUCT_INIT(nxn_ui_tokens);
        if (nxn_ui_tokens_get(&t) == NXN_OK && (t.text | t.window_bg) != 0) f.tok = t;
        else if (tok && (tok->text | tok->window_bg) != 0) f.tok = *tok;
        else if (!f.tok_ok) {
            const char* th = nxn_info_string(NXN_INFO_THEME);
            nxn_os_default_tokens(&f.tok, th && th[0] == 'd');
        }
        f.tok_ok = true;
        f.app_rev = app_rev;
    }
    f.ever = true;
    f.flags = flags;
    f.fb_w = fb_w;
    f.fb_h = fb_h;
    f.scale = nxn_os__compute_scale(f.tok, fb_w, fb_h);

    /* fonts: built for this scale, text size and bold setting; a change waits 0.2 s (live resize, slider drags) */
    float ts = (f.tok.text_scale > 0.5f ? f.tok.text_scale : 1.0f) * (f.text_zoom > 0.5f ? f.text_zoom : 1.0f);
    bool stale = f.font_scale <= 0.0f || f.font_scale != f.scale || f.font_text_scale != ts ||
                 f.font_bold != (f.tok.bold_text ? 1u : 0u) || f.icons_dirty;
    bool in_frame = io.Fonts->Locked;  /* the app already called ImGui::NewFrame: the atlas cannot change now */
    if (stale && !in_frame) {
        double now = ImGui::GetTime();
        if (f.want_scale != f.scale) {
            f.want_scale = f.scale;
            f.want_since = now;
        }
        if (f.font_scale <= 0.0f || f.icons_dirty || now - f.want_since >= 0.2 || f.font_text_scale != ts)
            nxn_os__build_fonts(f, f.scale);
    }
    /* until the rebuild, draw the old atlas at the new size (a few frames at most) */
    float k = f.font_scale > 0.0f ? f.scale / f.font_scale : 1.0f;
    for (int r = 0; r < NXN_OS_TEXT_ROLES; r++)
        if (f.font[r]) f.font[r]->Scale = k;
    io.FontGlobalScale = 1.0f;

    /* style: the OS look x scale, every frame (theme changes need no app code; nothing accumulates) */
    ImGuiStyle& st = ImGui::GetStyle();
    st = ImGuiStyle();
    nxn_os_apply_style(f.tok);
    st.ScaleAllSizes(f.scale);
    st.ScrollbarSize = floorf(st.ScrollbarSize + 0.5f);

    io.DisplaySize = ImVec2((float)fb_w, (float)fb_h);
    f.own_frame = !in_frame;
    if (!in_frame) {
#ifndef NXN_OS_UI_NO_GL3
        if (!(flags & NXN_OS_FRAME_NO_BACKEND)) ImGui_ImplOpenGL3_NewFrame();
#endif
        ImGui::NewFrame();
    }
    nxn_os__touch_scroll_update();
    f.row_depth = 0;
    f.card_depth = 0;
    f.own_window = !(flags & NXN_OS_FRAME_NO_WINDOW);
    if (f.own_window) {
        ImGui::SetNextWindowPos(ImVec2(0.0f, 0.0f));
        ImGui::SetNextWindowSize(ImVec2((float)fb_w, (float)fb_h));
        ImGui::PushStyleVar(ImGuiStyleVar_WindowPadding, ImVec2(nxn_os_s(NXN_OS_MARGIN), nxn_os_sp(NXN_OS_SP_L)));
        ImGui::Begin("##nxn_os_root", NULL,
                     ImGuiWindowFlags_NoDecoration | ImGuiWindowFlags_NoMove | ImGuiWindowFlags_NoSavedSettings |
                         ImGuiWindowFlags_NoBringToFrontOnFocus);
        ImGui::PopStyleVar();
    }
    if (f.font[NXN_OS_TEXT_BODY]) ImGui::PushFont(f.font[NXN_OS_TEXT_BODY]);
    f.active = true;
    return true;
}

static inline bool nxn_os_frame_begin(const nxn_ui_tokens* tok, int fb_w, int fb_h) {
    return nxn_os_frame_begin_ex(tok, fb_w, fb_h, 0u);
}

/* Ends the frame: closes open rows and the root window and calls ImGui::Render(). Then clear the surface with
   nxn_os_clear_color() and draw ImGui::GetDrawData() with the renderer backend. */
static inline void nxn_os_frame_end() {
    NxnOsFrameState& f = nxn_os_frame_state();
    if (!f.active) return;
    while (f.row_depth > 0) nxn_os_row_end();
    nxn_os__touch_scroll_end();
    if (f.font[NXN_OS_TEXT_BODY]) ImGui::PopFont();
    if (f.own_window) ImGui::End();
    f.own_window = false;
    f.active = false;
    f.frames++;
    if (f.own_frame) ImGui::Render();
}

#endif /* __cplusplus */
#endif /* NEXVYN_NXN_OS_UI_H */
