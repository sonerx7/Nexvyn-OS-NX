/* Nexvyn Native SDK - Canonical Nexvyn OS Design System & Widget Kit for Dear ImGui.
 *
 * Include AFTER <imgui.h> and <nexvyn/nxn_ui.h>. Header-only C++ (no ABI exports added).
 *
 * Renders grouped cards, segmented tabs, animated switches, chevron dropdowns, pill badges,
 * sleek progress meters, and hairline list rows parameterized live by `nxn_ui_tokens` so
 * Native C/C++ utility/tool/HUD apps match Nexvyn OS's Lua/JS/Python `ui.*` & `nxui.*` look
 * across Light, Dark, High-Contrast, and custom accent themes.
 *
 * Note: Games give themselves their own art direction; this kit is for utilities, dashboards,
 * benchmarks, settings panels, editors, and system overlays that belong to Nexvyn OS.
 */
#ifndef NEXVYN_NXN_OS_UI_H
#define NEXVYN_NXN_OS_UI_H

#ifdef __cplusplus

#include <math.h>
#include <stdio.h>
#include <string.h>
#include "nxn_ui.h"

#ifndef IMGUI_VERSION
#error "Include <imgui.h> before <nexvyn/nxn_os_ui.h>"
#endif

typedef enum nxn_os_btn_variant {
    NXN_OS_BTN_DEFAULT = 0,
    NXN_OS_BTN_PRIMARY = 1,
    NXN_OS_BTN_DESTRUCTIVE = 2,
    NXN_OS_BTN_PLAIN = 3,
    NXN_OS_BTN_TOOLBAR = 4
} nxn_os_btn_variant;

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
    float w = ImGui::GetContentRegionAvail().x;
    if (w > inset_x * 2.0f) {
        ImGui::GetWindowDrawList()->AddLine(
            ImVec2(p.x + inset_x, p.y),
            ImVec2(p.x + w - inset_x, p.y),
            nxn_os_u32(tok.separator), 1.0f
        );
    }
    ImGui::Dummy(ImVec2(0.0f, 1.0f));
}

/* Uppercase-style subtle section header inside pages or above grouped cards. */
static inline void nxn_os_section_label(const char* text, const nxn_ui_tokens& tok) {
    ImGui::PushStyleColor(ImGuiCol_Text, nxn_os_imvec4(tok.text_secondary));
    ImGui::TextUnformatted(text ? text : "");
    ImGui::PopStyleColor();
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
    st.radius = 10.0f;
    st.bg_col = (bg_col != 0) ? bg_col : nxn_os_u32(tok.content_bg);
    st.border_col = (border_col != 0) ? border_col : nxn_os_u32(tok.border);
    st.draw_shadow = !tok.dark;

    st.splitter.Split(st.dl, 2);
    st.splitter.SetCurrentChannel(st.dl, 1);

    ImGui::PushID(id ? id : "card");
    ImGui::BeginGroup();
    ImGui::SetCursorScreenPos(ImVec2(p.x + pad_x, p.y + pad_y));
    ImGui::PushItemWidth(card_w - pad_x * 2.0f);
    ImGui::BeginGroup();
}

static inline void nxn_os_card_begin(const char* id, const nxn_ui_tokens& tok, float width = 0.0f) {
    float p = tok.spacing[3] > 0.5f ? tok.spacing[3] : 16.0f;
    nxn_os_card_begin_ex(id, width, p, p * 0.85f, tok);
}

static inline void nxn_os_card_end() {
    int& depth = nxn_os_card_depth();
    if (depth <= 0) return;
    NxnOsCardState& st = nxn_os_card_stack()[--depth];

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

/* Segmented capsule tabs matching OS `ui::segmented` (source/core/ui.cpp). Zero-based index. Default height 28 = the
   script ui.segmented default (the OS draws it 26-34 px depending on the panel; pass `height` for another one). */
static inline bool nxn_os_segmented_tabs(const char* id, const char* const* labels, int count, int* active,
                                         const nxn_ui_tokens& tok, float height = 28.0f, float width = 0.0f) {
    if (!labels || count <= 0 || !active) return false;
    ImGui::PushID(id ? id : "seg");

    ImDrawList* dl = ImGui::GetWindowDrawList();
    ImVec2 p = ImGui::GetCursorScreenPos();
    float h = height > 22.0f ? height : 28.0f;

    float total_w = width;
    if (total_w <= 0.0f) {
        float max_seg = 64.0f;
        for (int i = 0; i < count; ++i) {
            float tw = ImGui::CalcTextSize(labels[i] ? labels[i] : "").x + 28.0f;
            if (tw > max_seg) max_seg = tw;
        }
        total_w = max_seg * (float)count;
        float avail = ImGui::GetContentRegionAvail().x;
        if (total_w > avail && avail > 40.0f) total_w = avail;
    }

    ImU32 track_col = tok.dark ? IM_COL32(255, 255, 255, 25) : IM_COL32(0, 0, 0, 16);
    dl->AddRectFilled(p, ImVec2(p.x + total_w, p.y + h), track_col, 7.0f);

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
        bool clicked = ImGui::InvisibleButton("##tab", ImVec2(sw > 4.0f ? sw : 4.0f, h));
        bool hovered = ImGui::IsItemHovered();
        bool held = ImGui::IsItemActive();
        ImGui::PopID();

        if (clicked && *active != i) {
            *active = i;
            changed = true;
        }

        if (*active == i) {
            ImVec2 k0(floorf(s0.x + 2.0f + 0.5f), floorf(s0.y + 2.0f + 0.5f));
            ImVec2 k1(floorf(s1.x - 2.0f + 0.5f), floorf(s1.y - 2.0f + 0.5f));
            if (!tok.dark) {
                dl->AddRectFilled(ImVec2(k0.x, k0.y + 1.0f), ImVec2(k1.x, k1.y + 1.5f), IM_COL32(0, 0, 0, 12), 5.5f);
            }
            ImU32 pill_col = tok.dark ? IM_COL32(99, 99, 102, 255) : IM_COL32(255, 255, 255, 255);
            dl->AddRectFilled(k0, k1, pill_col, 5.5f);
            if (!tok.dark) {
                dl->AddRect(k0, k1, IM_COL32(0, 0, 0, 16), 5.5f, 0, 1.0f);
            }
        } else if (hovered || held) {
            dl->AddRectFilled(ImVec2(floorf(s0.x + 2.0f + 0.5f), floorf(s0.y + 2.0f + 0.5f)),
                              ImVec2(floorf(s1.x - 2.0f + 0.5f), floorf(s1.y - 2.0f + 0.5f)), hover_col, 5.5f);
        }

        if (i > 0 && *active != i && *active != i - 1) {
            dl->AddLine(ImVec2(floorf(s0.x + 0.5f), s0.y + 7.0f), ImVec2(floorf(s0.x + 0.5f), s1.y - 7.0f), sep_col, 1.0f);
        }

        const char* lbl = labels[i] ? labels[i] : "";
        ImVec2 tsz = ImGui::CalcTextSize(lbl);
        ImVec2 tp(floorf(s0.x + (sw - tsz.x) * 0.5f + 0.5f), floorf(s0.y + (h - tsz.y) * 0.5f + 0.5f));
        dl->AddText(tp, (*active == i) ? txt_active : txt_idle, lbl);
    }

    ImGui::SetCursorScreenPos(p);
    ImGui::Dummy(ImVec2(total_w, h));
    ImGui::PopID();
    return changed;
}

/* OS Pill Switch matching `ui::toggle` with smooth animation in ImGui state storage. */
static inline bool nxn_os_switch(const char* id, bool* v, const nxn_ui_tokens& tok,
                                 float width = 38.0f, float height = 22.0f) {
    if (!v) return false;
    ImGui::PushID(id ? id : "sw");
    ImGuiID anim_id = ImGui::GetID("##anim");
    ImGuiStorage* st = ImGui::GetStateStorage();
    float a = st->GetFloat(anim_id, *v ? 1.0f : 0.0f);

    const float h = height > 12.0f ? height : 12.0f;
    const float w = width > h * 1.4f ? width : h * 1.4f;
    ImVec2 p = ImGui::GetCursorScreenPos();
    bool clicked = ImGui::InvisibleButton("##btn", ImVec2(w, h));
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

    float kr = h * 0.5f - 2.0f;
    float kx = (p.x + 2.0f + kr) + ((p.x + w - 2.0f - kr) - (p.x + 2.0f + kr)) * a;
    float ky = p.y + h * 0.5f;
    dl->AddCircleFilled(ImVec2(kx, ky + 1.0f), kr, IM_COL32(0, 0, 0, 42));
    dl->AddCircleFilled(ImVec2(kx, ky), kr, held ? IM_COL32(240, 240, 240, 255) : IM_COL32(255, 255, 255, 255));

    ImGui::PopID();
    return clicked;
}

/* OS Button matching `ui::button` variants (`NXN_OS_BTN_PRIMARY`, `DEFAULT`, `DESTRUCTIVE`, `PLAIN`, `TOOLBAR`). */
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

    ImVec2 sz = size;
    if (sz.y <= 0.0f) {
        sz.y = tok.control_height > 20.0f ? tok.control_height : 30.0f;
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
    return pressed;
}

/* OS Dropdown matching `ui::popup`: rounded control + accent right chip with double chevron. Zero-based index. */
static inline bool nxn_os_dropdown(const char* id, const char* const* items, int count, int* selected,
                                   float width, const nxn_ui_tokens& tok, float height = 0.0f) {
    if (!items || count <= 0 || !selected) return false;
    ImGui::PushID(id ? id : "dd");

    /* height: the argument when given, else the OS token (recommended control height), else 28 = the script ui.dropdown default */
    float h = height > 14.0f ? height : (tok.control_height > 14.0f ? tok.control_height : 28.0f);
    float w = width > 40.0f ? width : ImGui::GetContentRegionAvail().x;
    ImVec2 p = ImGui::GetCursorScreenPos();

    bool clicked = ImGui::InvisibleButton("##ddbtn", ImVec2(w, h));
    bool hovered = ImGui::IsItemHovered();
    bool held = ImGui::IsItemActive();

    ImDrawList* dl = ImGui::GetWindowDrawList();
    float r = tok.corner_radius_field > 1.0f ? tok.corner_radius_field : 6.0f;
    ImU32 fill = held ? nxn_os_u32(tok.surface_pressed)
                      : (hovered ? nxn_os_u32(tok.surface_hover) : nxn_os_u32(tok.surface));
    dl->AddRectFilled(p, ImVec2(p.x + w, p.y + h), fill, r);
    dl->AddRect(p, ImVec2(p.x + w, p.y + h), nxn_os_u32(tok.border), r, 0, 1.0f);

    float chip_w = h * 0.64f;
    if (chip_w < 14.0f) chip_w = 14.0f;
    float pad_chip = h * 0.11f;
    if (pad_chip < 2.0f) pad_chip = 2.0f;

    const char* cur = (*selected >= 0 && *selected < count && items[*selected]) ? items[*selected] : "";
    ImVec2 tsz = ImGui::CalcTextSize(cur);
    float tx = floorf(p.x + 10.0f + 0.5f);
    float ty = floorf(p.y + (h - tsz.y) * 0.5f + 0.5f);
    dl->PushClipRect(ImVec2(p.x + 8.0f, p.y), ImVec2(p.x + w - chip_w - 8.0f, p.y + h), true);
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
    ImU32 chev_col = nxn_os_u32(tok.accent_text);
    dl->AddLine(ImVec2(cx - cs, cy - cs * 0.45f), ImVec2(cx, cy - cs * 1.35f), chev_col, 1.2f);
    dl->AddLine(ImVec2(cx, cy - cs * 1.35f),      ImVec2(cx + cs, cy - cs * 0.45f), chev_col, 1.2f);
    dl->AddLine(ImVec2(cx - cs, cy + cs * 0.45f), ImVec2(cx, cy + cs * 1.35f), chev_col, 1.2f);
    dl->AddLine(ImVec2(cx, cy + cs * 1.35f),      ImVec2(cx + cs, cy + cs * 0.45f), chev_col, 1.2f);

    if (clicked) {
        ImGui::OpenPopup("##dd_popup");
    }

    bool changed = false;
    ImGui::SetNextWindowPos(ImVec2(p.x, p.y + h + 2.0f));
    ImGui::SetNextWindowSizeConstraints(ImVec2(w, 0.0f), ImVec2(w > 320.0f ? w : 320.0f, 320.0f));
    if (ImGui::BeginPopup("##dd_popup")) {
        for (int i = 0; i < count; ++i) {
            bool sel = (*selected == i);
            const char* opt = items[i] ? items[i] : "";
            if (ImGui::Selectable(opt, sel)) {
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

    ImGui::PopID();
    return changed;
}

/* Pill status badge (tinted surface + subtle outline + crisp theme-aware text). */
static inline void nxn_os_badge(const char* text, uint32_t color_argb, const nxn_ui_tokens& tok) {
    const char* s = text ? text : "";
    ImVec2 tsz = ImGui::CalcTextSize(s);
    /* canonical pill: 22 px high, 9 px side padding, at least 58 px wide, text centred */
    float px = 9.0f;
    float bh = 22.0f;
    float bw = tsz.x + px * 2.0f;
    if (bw < 58.0f) bw = 58.0f;
    float py = (bh - tsz.y) * 0.5f;
    px = (bw - tsz.x) * 0.5f;
    ImVec2 p = ImGui::GetCursorScreenPos();
    ImDrawList* dl = ImGui::GetWindowDrawList();

    ImU32 fill = nxn_os_u32(color_argb, tok.dark ? 0.18f : 0.12f);
    ImU32 brd  = nxn_os_u32(color_argb, tok.dark ? 0.45f : 0.35f);
    ImU32 fg   = tok.dark ? nxn_os_shift_u32(color_argb, 0.16f) : nxn_os_shift_u32(color_argb, -0.14f);

    dl->AddRectFilled(p, ImVec2(p.x + bw, p.y + bh), fill, bh * 0.5f);
    dl->AddRect(p, ImVec2(p.x + bw, p.y + bh), brd, bh * 0.5f, 0, 1.0f);
    dl->AddText(ImVec2(floorf(p.x + px + 0.5f), floorf(p.y + py + 0.5f)), fg, s);
    ImGui::Dummy(ImVec2(bw, bh));
}

/* Sleek OS capsule progress/ratio bar (replaces thick legacy histogram bars). */
static inline void nxn_os_progress_bar(float fraction, float width, float height,
                                       uint32_t fill_argb, const nxn_ui_tokens& tok) {
    if (fraction < 0.0f) fraction = 0.0f;
    if (fraction > 1.0f) fraction = 1.0f;
    float w = width > 0.0f ? width : ImGui::GetContentRegionAvail().x;
    float h = height > 2.0f ? height : 6.0f;
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

/* OS Pill Slider matching `ui::slider` (thin track + accent fill + round white knob with subtle shadow). */
static inline bool nxn_os_slider(const char* id, float* v, float vmin, float vmax, const nxn_ui_tokens& tok,
                                 float width = 0.0f, float height = 22.0f) {
    if (!v || vmax <= vmin) return false;
    ImGui::PushID(id ? id : "sld");
    float w = width > 24.0f ? width : ImGui::GetContentRegionAvail().x;
    float h = height > 12.0f ? height : 12.0f;
    ImVec2 p = ImGui::GetCursorScreenPos();

    ImGui::InvisibleButton("##sld", ImVec2(w, h));
    bool held = ImGui::IsItemActive();
    bool hovered = ImGui::IsItemHovered();
    bool changed = false;
    float kr = h * 0.42f;
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
    float th = h * 0.18f;
    if (th < 2.5f) th = 2.5f;

    ImDrawList* dl = ImGui::GetWindowDrawList();
    ImU32 track = tok.dark ? IM_COL32(255, 255, 255, 28) : IM_COL32(0, 0, 0, 24);
    dl->AddRectFilled(ImVec2(x0, cy - th * 0.5f), ImVec2(x1, cy + th * 0.5f), track, th * 0.5f);
    if (kx > x0 + 1.0f) {
        dl->AddRectFilled(ImVec2(x0, cy - th * 0.5f), ImVec2(kx, cy + th * 0.5f), nxn_os_u32(tok.accent), th * 0.5f);
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
    float avail = ImGui::GetContentRegionAvail().x;
    float row_h = (tok.row_height > 26.0f ? tok.row_height : 34.0f) - 4.0f;
    ImVec2 p = ImGui::GetCursorScreenPos();
    ImDrawList* dl = ImGui::GetWindowDrawList();

    const char* l = label ? label : "";
    const char* v = value ? value : "";
    ImVec2 lsz = ImGui::CalcTextSize(l);
    ImVec2 vsz = ImGui::CalcTextSize(v);
    float ly = p.y + (row_h - lsz.y) * 0.5f;
    float vy = p.y + (row_h - vsz.y) * 0.5f;

    dl->AddText(ImVec2(p.x, ly), nxn_os_u32(tok.text_secondary), l);
    dl->AddText(ImVec2(p.x + avail - vsz.x, vy),
                value_color != 0 ? nxn_os_u32(value_color) : nxn_os_u32(tok.text), v);
    ImGui::Dummy(ImVec2(avail, row_h));
    if (with_divider) nxn_os_separator(tok);
}

#endif /* __cplusplus */
#endif /* NEXVYN_NXN_OS_UI_H */
