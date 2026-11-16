// Stable-ID virtual controls for the game starter. No ImGui or OS UI ownership is involved.
#pragma once
#include <nexvyn/nexvyn_native.h>
#include "actions.h"

struct TouchActions {
    struct Capture { uint32_t id = 0; unsigned zone = 0; bool active = false; } captures[16];
    uint32_t held = 0;
    uint32_t primary = 0;
    bool primary_set = false, blocked = false;

    void cancel() {
        for (auto& c : captures) c.active = false;
        held = 0; primary_set = false; blocked = true;
    }
    void update(const nxn_touch* contacts, unsigned count, float width, float height, bool multiple) {
        held = 0;
        if (!count) { cancel(); blocked = false; return; }
        if (!contacts || width <= 0 || height <= 0 || blocked) return;
        if (count > 16) count = 16;
        if (!primary_set) { primary = contacts[0].id; primary_set = true; }
        for (auto& c : captures) {
            bool present = false;
            for (unsigned i = 0; i < count; ++i) if (contacts[i].id == c.id) present = true;
            if (!present) c.active = false;
        }
        for (unsigned i = 0; i < count; ++i) {
            const nxn_touch& t = contacts[i];
            if (!multiple && t.id != primary) continue;
            Capture* capture = nullptr;
            for (auto& c : captures) if (c.active && c.id == t.id) { capture = &c; break; }
            if (!capture) {
                for (auto& c : captures) if (!c.active) {
                    capture = &c; c.active = true; c.id = t.id;
                    c.zone = t.y < 64.f ? (t.x < 64.f ? 3u : (t.x >= width - 64.f ? 4u : 0u))
                                        : (t.x < width * 2.f / 3.f ? 1u : 2u);
                    break;
                }
            }
            if (!capture) continue;
            // Ownership is fixed on contact-down: crossing into Jump never fires it.
            if (capture->zone == 1) held |= 1u << (t.x < width / 3.f ? ACT_LEFT : ACT_RIGHT);
            if (capture->zone == 2) held |= 1u << ACT_JUMP;
            if (capture->zone == 3) held |= 1u << ACT_PAUSE;
            if (capture->zone == 4) held |= 1u << ACT_TOUCH_MODE;
        }
    }
};
