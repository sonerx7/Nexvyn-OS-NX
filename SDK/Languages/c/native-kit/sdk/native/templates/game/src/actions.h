// Action map: the game asks for actions ("left", "jump"), never for a particular button. Every action lists the pad
// buttons and keyboard keys (USB HID usage ids) that trigger it; change the table, or load it from a file in the data
// folder to let players rebind. Touch is handled by the game itself (nxn_input_touch).
#pragma once
#include <nexvyn/nexvyn_native.h>

enum Action { ACT_LEFT, ACT_RIGHT, ACT_UP, ACT_DOWN, ACT_JUMP, ACT_PAUSE, ACT_COUNT };

struct Binding {
    uint64_t pad;     // NXN_BTN_* bits (any of them triggers)
    uint32_t keys[2]; // HID usage ids, 0 = unused (4 = 'a' ... 26 = 'w', 79..82 arrows, 44 = space)
};

static const Binding kBindings[ACT_COUNT] = {
    /* ACT_LEFT  */ {NXN_BTN_LEFT, {80, 4}},
    /* ACT_RIGHT */ {NXN_BTN_RIGHT, {79, 7}},
    /* ACT_UP    */ {NXN_BTN_UP, {82, 26}},
    /* ACT_DOWN  */ {NXN_BTN_DOWN, {81, 22}},
    /* ACT_JUMP  */ {NXN_BTN_A, {44, 0}},
    /* ACT_PAUSE */ {NXN_BTN_PLUS, {41, 0}},
};

struct ActionState {
    bool held[ACT_COUNT];
    bool pressed[ACT_COUNT];  // went down this frame
    float axis_x, axis_y;     // left stick, or the d-pad as -1 / 0 / 1; y is up
};

static inline void actions_update(ActionState& s, const nxn_input_state& in) {
    for (int a = 0; a < ACT_COUNT; a++) {
        const Binding& b = kBindings[a];
        bool now = (in.buttons & b.pad) != 0;
        for (uint32_t k : b.keys)
            if (k && nxn_input_key_held(k) > 0) now = true;
        s.pressed[a] = now && !s.held[a];
        s.held[a] = now;
    }
    s.axis_x = in.lx + (s.held[ACT_RIGHT] ? 1.f : 0.f) - (s.held[ACT_LEFT] ? 1.f : 0.f);
    s.axis_y = in.ly + (s.held[ACT_UP] ? 1.f : 0.f) - (s.held[ACT_DOWN] ? 1.f : 0.f);
    if (s.axis_x > 1.f) s.axis_x = 1.f;
    if (s.axis_x < -1.f) s.axis_x = -1.f;
    if (s.axis_y > 1.f) s.axis_y = 1.f;
    if (s.axis_y < -1.f) s.axis_y = -1.f;
}
