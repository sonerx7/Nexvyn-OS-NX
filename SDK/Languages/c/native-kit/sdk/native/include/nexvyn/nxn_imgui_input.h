/* Shared native UI input backend. Include after imgui.h and nexvyn_native.h.
 * Call once per frame BEFORE NewFrame, after nxn_input_poll. Do not feed a
 * second backend or consume mouse/key/text queues elsewhere in the same frame.
 * Raw multi-touch remains available through nxn_input_touch for games/canvases.
 * UI capture follows a stable finger id, never the changing touch-array index.
 */
#ifndef NEXVYN_NXN_IMGUI_INPUT_H
#define NEXVYN_NXN_IMGUI_INPUT_H
#include <float.h>
#include <math.h>
#include "imgui_internal.h"

/* Adapter-local rounding, shared by direct stick motion and touch inertia.
 * Logical position stays fractional; ImGui's applied integer coordinate is
 * tracked so a layout/programmatic scroll re-anchors the affected axis. */
struct nxn_imgui_scroll_position {
    ImGuiID window = 0;
    ImGuiContext* context = NULL;
    ImVec2 remainder = ImVec2(0, 0), expected = ImVec2(0, 0);
    ImVec2 read(ImGuiWindow* w) {
        if (window != w->ID || context != ImGui::GetCurrentContext()) {
            window = w->ID; context = ImGui::GetCurrentContext();
            remainder = ImVec2(0, 0); expected = w->Scroll;
        }
        if (w->Scroll.x != expected.x) remainder.x = 0;
        if (w->Scroll.y != expected.y) remainder.y = 0;
        return ImVec2(w->Scroll.x + remainder.x, w->Scroll.y + remainder.y);
    }
    void write(ImGuiWindow* w, ImVec2 logical, bool horizontal = true, bool vertical = true) {
        if (horizontal) {
            logical.x = ImClamp(logical.x, 0.f, w->ScrollMax.x);
            expected.x = ImMin(IM_ROUND(logical.x), w->ScrollMax.x);
            remainder.x = logical.x - expected.x;
            ImGui::SetScrollX(w, logical.x);
        }
        if (vertical) {
            logical.y = ImClamp(logical.y, 0.f, w->ScrollMax.y);
            expected.y = ImMin(IM_ROUND(logical.y), w->ScrollMax.y);
            remainder.y = logical.y - expected.y;
            ImGui::SetScrollY(w, logical.y);
        }
    }
};

struct nxn_imgui_input_state {
    bool finger_down = false;
    bool wait_all_up = false;
    uint32_t finger_id = 0;
    float x = 0, y = 0;
    nxn_imgui_scroll_position pad_scroll;
    bool wait_mouse_up = false;
};

/* One app UI context is active at a time, like the scroll helper. Keep the
 * cancellation latch outside caller-allocated input state to preserve its prefix.
 * External inline storage shares the latch across the app's translation units. */
struct nxn_imgui_lifecycle_state {
    ImGuiContext* context = NULL;
    bool focused = true, suspended = false, closed = false, cancel_pending = false;
    int cancel_frame = -1, observed_frame = -1;
};
inline nxn_imgui_lifecycle_state& nxn_imgui_lifecycle() {
    static nxn_imgui_lifecycle_state state;
    ImGuiContext* context = ImGui::GetCurrentContext();
    int frame = ImGui::GetFrameCount();
    if (state.context != context || frame < state.observed_frame) {
        state = nxn_imgui_lifecycle_state(); state.context = context;
    }
    state.observed_frame = frame;
    return state;
}

/* Forward lifecycle events before NewFrame so ImGui releases keys, active edits
 * and touch motion when the window loses focus or is minimized. */
static inline void nxn_imgui_input_event(const nxn_event& event) {
    if (event.size < offsetof(nxn_event, type) + sizeof(event.type)) return;
    nxn_imgui_lifecycle_state& state = nxn_imgui_lifecycle();
    switch (event.type) {
    case NXN_EVENT_FOCUS:
        if (event.size < offsetof(nxn_event, focused) + sizeof(event.focused)) return;
        state.focused = event.focused != 0;
        if (!state.focused) state.cancel_pending = true;
        break;
    case NXN_EVENT_SUSPEND: state.suspended = true; state.cancel_pending = true; break;
    case NXN_EVENT_RESUME: state.suspended = false; break;
    case NXN_EVENT_QUIT: state.closed = true; state.cancel_pending = true; break;
    default: return;
    }
    ImGui::GetIO().AddFocusEvent(state.focused && !state.suspended && !state.closed);
}

static inline ImGuiKey nxn_imgui_hid_key(uint32_t u) {
    if (u >= 4 && u <= 29) return (ImGuiKey)(ImGuiKey_A + u - 4);
    if (u >= 30 && u <= 38) return (ImGuiKey)(ImGuiKey_1 + u - 30);
    if (u >= 58 && u <= 69) return (ImGuiKey)(ImGuiKey_F1 + u - 58);
    switch (u) {
    case 39: return ImGuiKey_0; case 40: return ImGuiKey_Enter;
    case 41: return ImGuiKey_Escape; case 42: return ImGuiKey_Backspace;
    case 43: return ImGuiKey_Tab; case 44: return ImGuiKey_Space;
    case 45: return ImGuiKey_Minus; case 46: return ImGuiKey_Equal;
    case 47: return ImGuiKey_LeftBracket; case 48: return ImGuiKey_RightBracket;
    case 49: return ImGuiKey_Backslash; case 51: return ImGuiKey_Semicolon;
    case 52: return ImGuiKey_Apostrophe; case 53: return ImGuiKey_GraveAccent;
    case 54: return ImGuiKey_Comma; case 55: return ImGuiKey_Period;
    case 56: return ImGuiKey_Slash; case 73: return ImGuiKey_Insert;
    case 74: return ImGuiKey_Home; case 75: return ImGuiKey_PageUp;
    case 76: return ImGuiKey_Delete; case 77: return ImGuiKey_End;
    case 78: return ImGuiKey_PageDown; case 79: return ImGuiKey_RightArrow;
    case 80: return ImGuiKey_LeftArrow; case 81: return ImGuiKey_DownArrow;
    case 82: return ImGuiKey_UpArrow;
    case 224: case 228: return ImGuiMod_Ctrl;
    case 225: case 229: return ImGuiMod_Shift;
    case 226: case 230: return ImGuiMod_Alt;
    case 227: case 231: return ImGuiMod_Super;
    default: return ImGuiKey_None;
    }
}

static inline void nxn_imgui_input(nxn_imgui_input_state& s, const nxn_input_state& in, float dt) {
    ImGuiIO& io = ImGui::GetIO();
    io.DeltaTime = isfinite(dt) && dt > 0.0f ? fminf(dt, 1.f) : 1.0f / 60.0f;
    nxn_imgui_lifecycle_state& lifecycle = nxn_imgui_lifecycle();
    bool accepting = lifecycle.focused && !lifecycle.suspended && !lifecycle.closed;
    if (lifecycle.cancel_pending || !accepting) {
        // ImGui intentionally merges focus false/true in one frame. Our OS
        // lifecycle contract requires the intervening cancellation to survive.
        io.ClearEventsQueue(); io.ClearInputKeys(); io.ClearInputMouse();
        ImGui::ClearActiveID();
        s = nxn_imgui_input_state();
        s.wait_all_up = in.touch_count != 0;
        nxn_mouse m = NXN_STRUCT_INIT(nxn_mouse);
        if (nxn_input_mouse(&m) == NXN_OK) s.wait_mouse_up = m.buttons != 0;
        nxn_key_event key = NXN_STRUCT_INIT(nxn_key_event);
        for (int n = 0; n < 64 && nxn_input_key_poll(&key) > 0; ++n) {}
        char discard[512]; nxn_input_text(discard, sizeof discard);
        nxn_input_text_request(0);
        io.AddFocusEvent(accepting);
        lifecycle.cancel_pending = false;
        lifecycle.cancel_frame = ImGui::GetFrameCount() + 1;
        return;
    }
    io.ConfigFlags |= ImGuiConfigFlags_NavEnableKeyboard | ImGuiConfigFlags_NavEnableGamepad;
    io.BackendFlags |= ImGuiBackendFlags_HasGamepad;
    io.AddKeyEvent(ImGuiKey_GamepadFaceDown, (in.actions & NXN_ACT_CONFIRM) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadFaceRight, (in.actions & NXN_ACT_CANCEL) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadDpadLeft, (in.buttons & NXN_BTN_LEFT) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadDpadRight, (in.buttons & NXN_BTN_RIGHT) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadDpadUp, (in.buttons & NXN_BTN_UP) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadDpadDown, (in.buttons & NXN_BTN_DOWN) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadL1, (in.buttons & NXN_BTN_L) != 0);
    io.AddKeyEvent(ImGuiKey_GamepadR1, (in.buttons & NXN_BTN_R) != 0);
    const float dead = 0.2f;
    auto axis = [dead](float v) { return v > dead ? (v - dead) / (1.0f - dead) : 0.0f; };
    io.AddKeyAnalogEvent(ImGuiKey_GamepadLStickLeft, in.lx < -dead, axis(-in.lx));
    io.AddKeyAnalogEvent(ImGuiKey_GamepadLStickRight, in.lx > dead, axis(in.lx));
    io.AddKeyAnalogEvent(ImGuiKey_GamepadLStickUp, in.ly > dead, axis(in.ly));
    io.AddKeyAnalogEvent(ImGuiKey_GamepadLStickDown, in.ly < -dead, axis(-in.ly));
    nxn_key_event key = NXN_STRUCT_INIT(nxn_key_event);
    for (int n = 0; n < 64 && nxn_input_key_poll(&key) > 0; ++n) {
        ImGuiKey k = nxn_imgui_hid_key(key.usage);
        if (k != ImGuiKey_None) io.AddKeyEvent(k, key.down != 0);
        io.AddKeyEvent(ImGuiMod_Ctrl, (key.mods & NXN_MOD_CTRL) != 0);
        io.AddKeyEvent(ImGuiMod_Shift, (key.mods & NXN_MOD_SHIFT) != 0);
        io.AddKeyEvent(ImGuiMod_Alt, (key.mods & NXN_MOD_ALT) != 0);
        io.AddKeyEvent(ImGuiMod_Super, (key.mods & NXN_MOD_GUI) != 0);
    }
    char text[512];
    if (nxn_input_text(text, sizeof text) > 0) io.AddInputCharactersUTF8(text);
    nxn_input_text_request(io.WantTextInput ? 1 : 0);

    nxn_mouse m = NXN_STRUCT_INIT(nxn_mouse);
    bool mouse_ok = nxn_input_mouse(&m) == NXN_OK;
    if (mouse_ok && !m.buttons) s.wait_mouse_up = false;
    nxn_touch finger = NXN_STRUCT_INIT(nxn_touch);
    bool found = false;
    if (!in.touch_count) s.wait_all_up = false;
    for (uint32_t i = 0; i < in.touch_count && i < 16; ++i) {
        nxn_touch t = NXN_STRUCT_INIT(nxn_touch);
        if (nxn_input_touch(i, &t) != NXN_OK) continue;
        if ((s.finger_down && t.id == s.finger_id) || (!s.finger_down && !s.wait_all_up && !found)) {
            finger = t;
            found = true;
        }
    }
    if (found) {
        s.finger_id = finger.id; s.x = finger.x; s.y = finger.y;
        io.AddMouseSourceEvent(ImGuiMouseSource_TouchScreen);
        io.AddMousePosEvent(s.x, s.y);
        io.AddMouseButtonEvent(0, true);
        s.finger_down = true;
    } else if (s.finger_down) {
        /* Release at the last valid position. Invalidating the pointer in this
         * frame used to lose taps depending on ImGui's event trickling. */
        io.AddMouseSourceEvent(ImGuiMouseSource_TouchScreen);
        io.AddMousePosEvent(s.x, s.y);
        io.AddMouseButtonEvent(0, false);
        s.finger_down = false;
        s.wait_all_up = in.touch_count != 0;
    } else if (mouse_ok && !s.wait_all_up && !s.wait_mouse_up) {
        io.AddMouseSourceEvent(ImGuiMouseSource_Mouse);
        io.AddMousePosEvent(m.present || m.buttons ? m.x : -FLT_MAX, m.present || m.buttons ? m.y : -FLT_MAX);
        for (int b = 0; b < 3; ++b) {
            const uint32_t bit = 1u << b;
            if (m.pressed & bit) io.AddMouseButtonEvent(b, true);
            io.AddMouseButtonEvent(b, (m.buttons & bit) != 0);
        }
        io.AddMouseWheelEvent(m.wheel_x, m.wheel_y);
    }
    if (s.finger_down || s.wait_all_up || s.wait_mouse_up) s.pad_scroll = nxn_imgui_scroll_position();
    if (!s.finger_down && !s.wait_all_up && !s.wait_mouse_up) {
        float x = axis(in.rx) - axis(-in.rx), y = axis(in.ry) - axis(-in.ry);
        if (mouse_ok && m.present) {
            s.pad_scroll = nxn_imgui_scroll_position();
            io.AddMouseWheelEvent(-x * io.DeltaTime * 12.0f, y * io.DeltaTime * 12.0f);
        } else if (x != 0 || y != 0) {
            // A pad can scroll the focused pane without a visible mouse cursor.
            ImGuiWindow* w = ImGui::GetCurrentContext()->NavWindow;
            while (w && w->ScrollMax.x <= 0 && w->ScrollMax.y <= 0) w = w->ParentWindow;
            if (w && w->ScrollTarget.x == FLT_MAX && w->ScrollTarget.y == FLT_MAX) {
                ImVec2 p = s.pad_scroll.read(w);
                p.x += x * io.DeltaTime * 720.0f;
                p.y -= y * io.DeltaTime * 720.0f;
                s.pad_scroll.write(w, p, w->ScrollMax.x > 0 && x != 0, w->ScrollMax.y > 0 && y != 0);
            } else s.pad_scroll = nxn_imgui_scroll_position();
        } else s.pad_scroll = nxn_imgui_scroll_position();
    }
}
#endif
