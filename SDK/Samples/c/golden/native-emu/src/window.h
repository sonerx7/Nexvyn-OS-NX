// Main-thread display ownership; retry Busy once on each later frame.
#pragma once
#include <nexvyn/nexvyn_native.h>
struct Window {
    nxn_display* display = nullptr;
    uint32_t w = 0, h = 0, pending_w = 0, pending_h = 0;
    bool focused = true, suspended = false, paused = false, cancelled = false;
    bool key_held = false, touch_held = false, confirm = false, armed = false;
    nxn_input_state input = NXN_STRUCT_INIT(nxn_input_state);
    bool open() {
        if (nxn_display_open(nullptr, &display) != NXN_OK) return false;
        nxn_display_size(display, &w, &h);
        nxn_window_set_title(nxn_tr("title"), nxn_tr("hint"));
        return true;
    }
    bool tick() {
        if (nxn_should_quit()) return false;
        cancelled = confirm = false;
        nxn_event e = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&e) > 0) {
            if (e.type == NXN_EVENT_QUIT) return false;
            if (e.type == NXN_EVENT_RESIZE) { pending_w = e.width; pending_h = e.height; }
            if (e.type == NXN_EVENT_FOCUS) { focused = e.focused != 0; if (!focused) cancelled = paused = true; }
            if (e.type == NXN_EVENT_SUSPEND) { suspended = true; cancelled = paused = true; }
            if (e.type == NXN_EVENT_RESUME) { suspended = false; paused = true; }
            if (e.type == NXN_EVENT_LANGUAGE) nxn_window_set_title(nxn_tr("title"), nxn_tr("hint"));
            e = NXN_STRUCT_INIT(nxn_event);
        }
        if (pending_w && pending_h && !suspended) {
            nxn_result r = nxn_display_resize(display, pending_w, pending_h);
            if (r == NXN_OK) { nxn_display_size(display, &w, &h); pending_w = pending_h = 0; }
            else if (r != NXN_ERR_BUSY) { nxn_log(NXN_LOG_WARN, "resize failed: %d", r); pending_w = pending_h = 0; }
        }
        nxn_input_poll(&input);
        if (input.actions_pressed & NXN_ACT_CANCEL) return false;
        bool key = nxn_input_key_held(40) > 0; // Enter
        bool touch = input.touch_count > 0;
        if (cancelled || suspended || !focused) {
            armed = false; key_held = key; touch_held = touch;
            return true; // cancellation is never a click
        }
        if (!armed) {
            key_held = key; touch_held = touch;
            if (!key and !touch and !input.actions) armed = true;
            return true;
        }
        confirm = (input.actions_pressed & NXN_ACT_CONFIRM) || (key && !key_held) || (touch && !touch_held);
        key_held = key; touch_held = touch;
        if (input.pressed & NXN_BTN_PLUS) paused = !paused;
        if (paused && confirm) { paused = false; confirm = false; }
        return true;
    }
    bool active() const { return focused && !suspended && !paused; }
    void close() { if (display) nxn_display_close(display); display = nullptr; }
};
