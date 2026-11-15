/* Nexvyn Native SDK - Universal Port Input System (Gamepad + Multi-Touch Gestures + Mouse + Keyboard + OSK).
 *
 * Header-only C99/C++ helper for porting PC games, RTS/CRPG/FPS engines, and emulators to Nexvyn OS N2.
 * Provides:
 *   1. Multi-touch gesture recognizer: two-finger pinch-to-zoom, two-finger pan/scroll, two-finger tap -> right-click,
 *      and single-finger long-press -> right-click.
 *   2. Configurable Gamepad -> Virtual Mouse / Keyboard / Scroll mapping with ready presets:
 *      - NXN_PI_PROFILE_GAMEPAD (native gamepad + multi-touch gestures)
 *      - NXN_PI_PROFILE_RTS     (Red Alert 2 / C&C / OpenTTD / OpenRCT2: pinch zoom, 2-finger right-click, stick cursor)
 *      - NXN_PI_PROFILE_CRPG    (Fallout 1/2, Diablo, ScummVM: stick cursor, triggers click, long-press/2-finger right-click)
 *      - NXN_PI_PROFILE_FPS     (Quake II, Half-Life: L-stick WASD, R-stick relative mouse look, ZR/ZL fire/alt)
 *   3. Unified event queue (nxn_pi_poll_event) combining USB/BT keyboard, OSK text, physical mouse, touch gestures,
 *      and gamepad bindings into one clean stream.
 *
 * Usage:
 *   #include <nexvyn/nxn_port_input.h>
 *   nxn_pi_ctx pi;
 *   nxn_pi_init(&pi, NXN_PI_PROFILE_RTS, 1280.0f, 720.0f);
 *   // In frame loop:
 *   nxn_pi_update(&pi, dt_sec);
 *   nxn_pi_event ev;
 *   while (nxn_pi_poll_event(&pi, &ev)) { ... }
 */
#ifndef NEXVYN_NXN_PORT_INPUT_H
#define NEXVYN_NXN_PORT_INPUT_H

#include "nexvyn_native.h"
#include <math.h>
#include <string.h>

NXN_EXTERN_C_BEGIN

typedef enum nxn_pi_profile {
    NXN_PI_PROFILE_GAMEPAD = 0,
    NXN_PI_PROFILE_RTS     = 1,
    NXN_PI_PROFILE_CRPG    = 2,
    NXN_PI_PROFILE_FPS     = 3
} nxn_pi_profile;

typedef enum nxn_pi_pinch_mode {
    NXN_PI_PINCH_WHEEL      = 0, /* Emit mouse wheel +1/-1 notches at pinch center (default, ideal for RA2/OpenTTD/etc.) */
    NXN_PI_PINCH_CTRL_PM    = 1, /* Emit Ctrl + '=' / '-' key events */
    NXN_PI_PINCH_EVENT_ONLY = 2  /* Emit only NXN_PI_EV_PINCH with scale/delta */
} nxn_pi_pinch_mode;

typedef enum nxn_pi_ev_type {
    NXN_PI_EV_NONE = 0,
    NXN_PI_EV_MOUSE_MOVE,    /* x, y, dx, dy */
    NXN_PI_EV_MOUSE_DOWN,    /* button (NXN_MOUSE_*), x, y */
    NXN_PI_EV_MOUSE_UP,      /* button (NXN_MOUSE_*), x, y */
    NXN_PI_EV_MOUSE_WHEEL,   /* wheel_x, wheel_y, x, y */
    NXN_PI_EV_KEY_DOWN,      /* hid_usage, mods */
    NXN_PI_EV_KEY_UP,        /* hid_usage, mods */
    NXN_PI_EV_PINCH,         /* pinch_delta (>0 zoom in, <0 zoom out), x, y */
    NXN_PI_EV_TWO_FINGER_TAP,/* x, y */
    NXN_PI_EV_TEXT           /* text[64] UTF-8 */
} nxn_pi_ev_type;

typedef enum nxn_pi_bind_kind {
    NXN_PI_BIND_NONE = 0,
    NXN_PI_BIND_KEY,
    NXN_PI_BIND_MOUSE_BTN,
    NXN_PI_BIND_WHEEL,
    NXN_PI_BIND_TOGGLE_OSK
} nxn_pi_bind_kind;

typedef struct nxn_pi_binding {
    uint64_t btn_mask;       /* NXN_BTN_* */
    nxn_pi_bind_kind kind;
    uint32_t code;           /* HID usage, NXN_MOUSE_*, or (uint32_t)(+1/-1) for wheel */
} nxn_pi_binding;

typedef struct nxn_pi_event {
    nxn_pi_ev_type type;
    float x, y;
    float dx, dy;
    float wheel_x, wheel_y;
    float pinch_delta;
    uint32_t button;
    uint32_t hid_usage;
    uint32_t mods;
    char text[64];
} nxn_pi_event;

#define NXN_PI_MAX_EVENTS   128
#define NXN_PI_MAX_BINDINGS 32

typedef struct nxn_pi_ctx {
    nxn_pi_profile profile;
    nxn_pi_pinch_mode pinch_mode;
    float view_w, view_h;
    float cursor_x, cursor_y;
    float cursor_speed;
    float deadzone;
    int long_press_right;
    int two_finger_gestures;
    int relative_mouse;
    int osk_open;

    nxn_input_state pad;
    uint64_t prev_btns;
    uint8_t stick_wasd_held[4]; /* W, A, S, D */

    /* Gesture state */
    int g_active;
    uint32_t g_id0, g_id1;
    float g_start_dist, g_last_dist;
    float g_start_cx, g_start_cy, g_last_cx, g_last_cy;
    float g_pinch_acc, g_pan_x, g_pan_y;
    uint64_t g_start_ms;
    int g_moved;

    /* Long-press state */
    int lp_active;
    uint32_t lp_id;
    float lp_x, lp_y;
    uint64_t lp_start_ms;
    int lp_fired;

    /* Single touch mouse sync */
    int t1_active;
    uint32_t t1_id;

    /* Bindings & event queue */
    nxn_pi_binding bindings[NXN_PI_MAX_BINDINGS];
    int binding_count;
    nxn_pi_event queue[NXN_PI_MAX_EVENTS];
    int q_head, q_tail, q_count;
    float wheel_acc;
} nxn_pi_ctx;

static inline uint64_t nxn_pi_now_ms(void) {
    return nxn_time_ns() / 1000000ULL;
}

static inline void nxn_pi_push(nxn_pi_ctx* ctx, const nxn_pi_event* ev) {
    if (!ctx || !ev) return;
    if (ctx->q_count >= NXN_PI_MAX_EVENTS) {
        ctx->q_head = (ctx->q_head + 1) % NXN_PI_MAX_EVENTS;
        ctx->q_count--;
    }
    ctx->queue[ctx->q_tail] = *ev;
    ctx->q_tail = (ctx->q_tail + 1) % NXN_PI_MAX_EVENTS;
    ctx->q_count++;
}

static inline void nxn_pi_clear_bindings(nxn_pi_ctx* ctx) {
    if (ctx) ctx->binding_count = 0;
}

static inline void nxn_pi_bind(nxn_pi_ctx* ctx, uint64_t btn_mask, nxn_pi_bind_kind kind, uint32_t code) {
    if (!ctx || ctx->binding_count >= NXN_PI_MAX_BINDINGS) return;
    ctx->bindings[ctx->binding_count].btn_mask = btn_mask;
    ctx->bindings[ctx->binding_count].kind = kind;
    ctx->bindings[ctx->binding_count].code = code;
    ctx->binding_count++;
}

static inline void nxn_pi_apply_profile(nxn_pi_ctx* ctx, nxn_pi_profile profile) {
    if (!ctx) return;
    ctx->profile = profile;
    nxn_pi_clear_bindings(ctx);
    ctx->relative_mouse = (profile == NXN_PI_PROFILE_FPS) ? 1 : 0;

    if (profile == NXN_PI_PROFILE_RTS) {
        nxn_pi_bind(ctx, NXN_BTN_ZR,    NXN_PI_BIND_MOUSE_BTN, NXN_MOUSE_LEFT);
        nxn_pi_bind(ctx, NXN_BTN_A,     NXN_PI_BIND_MOUSE_BTN, NXN_MOUSE_LEFT);
        nxn_pi_bind(ctx, NXN_BTN_ZL,    NXN_PI_BIND_MOUSE_BTN, NXN_MOUSE_RIGHT);
        nxn_pi_bind(ctx, NXN_BTN_X,     NXN_PI_BIND_KEY,       225); /* Left Shift (multi-select / queue) */
        nxn_pi_bind(ctx, NXN_BTN_B,     NXN_PI_BIND_KEY,       41);  /* Escape */
        nxn_pi_bind(ctx, NXN_BTN_PLUS,  NXN_PI_BIND_KEY,       40);  /* Return */
        nxn_pi_bind(ctx, NXN_BTN_MINUS, NXN_PI_BIND_KEY,       43);  /* Tab */
        nxn_pi_bind(ctx, NXN_BTN_Y,     NXN_PI_BIND_TOGGLE_OSK, 0);
        nxn_pi_bind(ctx, NXN_BTN_R,     NXN_PI_BIND_WHEEL,     1);   /* Zoom in */
        nxn_pi_bind(ctx, NXN_BTN_L,     NXN_PI_BIND_WHEEL,     (uint32_t)-1); /* Zoom out */
        nxn_pi_bind(ctx, NXN_BTN_UP,    NXN_PI_BIND_KEY,       82);  /* Up arrow */
        nxn_pi_bind(ctx, NXN_BTN_DOWN,  NXN_PI_BIND_KEY,       81);  /* Down arrow */
        nxn_pi_bind(ctx, NXN_BTN_LEFT,  NXN_PI_BIND_KEY,       80);  /* Left arrow */
        nxn_pi_bind(ctx, NXN_BTN_RIGHT, NXN_PI_BIND_KEY,       79);  /* Right arrow */
    } else if (profile == NXN_PI_PROFILE_CRPG) {
        nxn_pi_bind(ctx, NXN_BTN_ZR,    NXN_PI_BIND_MOUSE_BTN, NXN_MOUSE_LEFT);
        nxn_pi_bind(ctx, NXN_BTN_A,     NXN_PI_BIND_MOUSE_BTN, NXN_MOUSE_LEFT);
        nxn_pi_bind(ctx, NXN_BTN_ZL,    NXN_PI_BIND_MOUSE_BTN, NXN_MOUSE_RIGHT);
        nxn_pi_bind(ctx, NXN_BTN_X,     NXN_PI_BIND_MOUSE_BTN, NXN_MOUSE_RIGHT);
        nxn_pi_bind(ctx, NXN_BTN_B,     NXN_PI_BIND_KEY,       41);  /* Escape */
        nxn_pi_bind(ctx, NXN_BTN_Y,     NXN_PI_BIND_TOGGLE_OSK, 0);
        nxn_pi_bind(ctx, NXN_BTN_L,     NXN_PI_BIND_KEY,       43);  /* Tab */
        nxn_pi_bind(ctx, NXN_BTN_R,     NXN_PI_BIND_KEY,       44);  /* Space */
        nxn_pi_bind(ctx, NXN_BTN_PLUS,  NXN_PI_BIND_KEY,       40);  /* Return */
    } else if (profile == NXN_PI_PROFILE_FPS) {
        nxn_pi_bind(ctx, NXN_BTN_ZR,    NXN_PI_BIND_MOUSE_BTN, NXN_MOUSE_LEFT);
        nxn_pi_bind(ctx, NXN_BTN_ZL,    NXN_PI_BIND_MOUSE_BTN, NXN_MOUSE_RIGHT);
        nxn_pi_bind(ctx, NXN_BTN_A,     NXN_PI_BIND_KEY,       44);  /* Space */
        nxn_pi_bind(ctx, NXN_BTN_B,     NXN_PI_BIND_KEY,       224); /* Ctrl / crouch */
        nxn_pi_bind(ctx, NXN_BTN_X,     NXN_PI_BIND_KEY,       21);  /* R (reload) */
        nxn_pi_bind(ctx, NXN_BTN_Y,     NXN_PI_BIND_KEY,       8);   /* E (use) */
        nxn_pi_bind(ctx, NXN_BTN_PLUS,  NXN_PI_BIND_KEY,       41);  /* Escape */
        nxn_pi_bind(ctx, NXN_BTN_UP,    NXN_PI_BIND_KEY,       30);  /* 1 */
        nxn_pi_bind(ctx, NXN_BTN_RIGHT, NXN_PI_BIND_KEY,   31);  /* 2 */
        nxn_pi_bind(ctx, NXN_BTN_DOWN,  NXN_PI_BIND_KEY,       32);  /* 3 */
        nxn_pi_bind(ctx, NXN_BTN_LEFT,  NXN_PI_BIND_KEY,       33);  /* 4 */
    }
}

static inline void nxn_pi_init(nxn_pi_ctx* ctx, nxn_pi_profile profile, float view_w, float view_h) {
    if (!ctx) return;
    memset(ctx, 0, sizeof(*ctx));
    ctx->view_w = view_w > 0 ? view_w : 1280.0f;
    ctx->view_h = view_h > 0 ? view_h : 720.0f;
    ctx->cursor_x = ctx->view_w * 0.5f;
    ctx->cursor_y = ctx->view_h * 0.5f;
    ctx->cursor_speed = 680.0f;
    ctx->deadzone = 0.18f;
    ctx->long_press_right = 1;
    ctx->two_finger_gestures = 1;
    ctx->pinch_mode = NXN_PI_PINCH_WHEEL;
    nxn_pi_apply_profile(ctx, profile);
}

static inline void nxn_pi_emit_zoom(nxn_pi_ctx* ctx, float cx, float cy, int dir) {
    nxn_pi_event ev;
    memset(&ev, 0, sizeof(ev));
    ev.x = cx;
    ev.y = cy;
    ev.pinch_delta = (float)dir;
    if (ctx->pinch_mode == NXN_PI_PINCH_CTRL_PM) {
        ev.type = NXN_PI_EV_KEY_DOWN; ev.hid_usage = 224; ev.mods = NXN_MOD_CTRL; nxn_pi_push(ctx, &ev);
        ev.hid_usage = (dir > 0) ? 46u : 45u; nxn_pi_push(ctx, &ev);
        ev.type = NXN_PI_EV_KEY_UP; nxn_pi_push(ctx, &ev);
        ev.hid_usage = 224; ev.mods = 0; nxn_pi_push(ctx, &ev);
    } else if (ctx->pinch_mode == NXN_PI_PINCH_WHEEL) {
        ev.type = NXN_PI_EV_MOUSE_WHEEL;
        ev.wheel_y = (float)dir;
        nxn_pi_push(ctx, &ev);
    } else {
        ev.type = NXN_PI_EV_PINCH;
        nxn_pi_push(ctx, &ev);
    }
}

static inline void nxn_pi_update(nxn_pi_ctx* ctx, float dt_sec) {
    if (!ctx) return;
    if (dt_sec <= 0.0f || dt_sec > 0.1f) dt_sec = 0.016f;
    uint64_t now_ms = nxn_pi_now_ms();

    ctx->pad.size = sizeof(ctx->pad);
    if (nxn_input_poll(&ctx->pad) != NXN_OK) return;

    /* 1. Physical USB/BT keyboard events & text */
    nxn_key_event ke;
    ke.size = sizeof(ke);
    while (nxn_input_key_poll(&ke) > 0) {
        nxn_pi_event ev;
        memset(&ev, 0, sizeof(ev));
        ev.type = ke.down ? NXN_PI_EV_KEY_DOWN : NXN_PI_EV_KEY_UP;
        ev.hid_usage = ke.usage;
        ev.mods = ke.mods;
        nxn_pi_push(ctx, &ev);
        ke.size = sizeof(ke);
    }
    {
        nxn_pi_event ev;
        memset(&ev, 0, sizeof(ev));
        int n = nxn_input_text(ev.text, sizeof(ev.text));
        if (n > 0) {
            ev.type = NXN_PI_EV_TEXT;
            nxn_pi_push(ctx, &ev);
        }
    }

    /* 2. Physical mouse */
    nxn_mouse ms;
    ms.size = sizeof(ms);
    if (nxn_input_mouse(&ms) == NXN_OK) {
        if (ms.present && (ms.dx != 0.0f || ms.dy != 0.0f)) {
            ctx->cursor_x = ms.x;
            ctx->cursor_y = ms.y;
            nxn_pi_event ev;
            memset(&ev, 0, sizeof(ev));
            ev.type = NXN_PI_EV_MOUSE_MOVE;
            ev.x = ms.x; ev.y = ms.y; ev.dx = ms.dx; ev.dy = ms.dy;
            nxn_pi_push(ctx, &ev);
        }
        uint32_t mbtns[3] = {NXN_MOUSE_LEFT, NXN_MOUSE_RIGHT, NXN_MOUSE_MIDDLE};
        for (int i = 0; i < 3; i++) {
            if (ms.pressed & mbtns[i]) {
                nxn_pi_event ev; memset(&ev, 0, sizeof(ev));
                ev.type = NXN_PI_EV_MOUSE_DOWN; ev.button = mbtns[i]; ev.x = ms.x; ev.y = ms.y;
                nxn_pi_push(ctx, &ev);
            }
            if (ms.released & mbtns[i]) {
                nxn_pi_event ev; memset(&ev, 0, sizeof(ev));
                ev.type = NXN_PI_EV_MOUSE_UP; ev.button = mbtns[i]; ev.x = ms.x; ev.y = ms.y;
                nxn_pi_push(ctx, &ev);
            }
        }
        if (ms.wheel_x != 0.0f || ms.wheel_y != 0.0f) {
            nxn_pi_event ev; memset(&ev, 0, sizeof(ev));
            ev.type = NXN_PI_EV_MOUSE_WHEEL; ev.wheel_x = ms.wheel_x; ev.wheel_y = ms.wheel_y;
            ev.x = ms.x; ev.y = ms.y;
            nxn_pi_push(ctx, &ev);
        }
    }

    /* 3. Multi-touch & gestures */
    uint32_t ids[16];
    float tx[16], ty[16];
    int tc = 0;
    for (uint32_t i = 0; i < ctx->pad.touch_count && tc < 16; i++) {
        nxn_touch t;
        t.size = sizeof(t);
        if (nxn_input_touch(i, &t) == NXN_OK) {
            ids[tc] = t.id;
            tx[tc] = t.x;
            ty[tc] = t.y;
            tc++;
        }
    }
    if (ctx->two_finger_gestures && tc >= 2) {
        ctx->lp_active = 0;
        float dx = tx[1] - tx[0], dy = ty[1] - ty[0];
        float dist = sqrtf(dx * dx + dy * dy);
        float cx = (tx[0] + tx[1]) * 0.5f, cy = (ty[0] + ty[1]) * 0.5f;
        if (!ctx->g_active || ctx->g_id0 != ids[0] || ctx->g_id1 != ids[1]) {
            ctx->g_active = 1;
            ctx->g_id0 = ids[0]; ctx->g_id1 = ids[1];
            ctx->g_start_dist = ctx->g_last_dist = dist;
            ctx->g_start_cx = ctx->g_last_cx = cx;
            ctx->g_start_cy = ctx->g_last_cy = cy;
            ctx->g_pinch_acc = ctx->g_pan_x = ctx->g_pan_y = 0.0f;
            ctx->g_start_ms = now_ms;
            ctx->g_moved = 0;
        } else {
            float ddist = dist - ctx->g_last_dist;
            float dcx = cx - ctx->g_last_cx, dcy = cy - ctx->g_last_cy;
            ctx->g_last_dist = dist; ctx->g_last_cx = cx; ctx->g_last_cy = cy;
            if (fabsf(cx - ctx->g_start_cx) > 18.0f || fabsf(cy - ctx->g_start_cy) > 18.0f ||
                fabsf(dist - ctx->g_start_dist) > 18.0f) {
                ctx->g_moved = 1;
            }
            if (dist >= 20.0f) {
                ctx->g_pinch_acc += ddist;
                while (ctx->g_pinch_acc >= 26.0f) {
                    nxn_pi_emit_zoom(ctx, cx, cy, 1);
                    ctx->g_pinch_acc -= 26.0f;
                    ctx->g_moved = 1;
                }
                while (ctx->g_pinch_acc <= -26.0f) {
                    nxn_pi_emit_zoom(ctx, cx, cy, -1);
                    ctx->g_pinch_acc += 26.0f;
                    ctx->g_moved = 1;
                }
            }
            if (fabsf(ddist) < 10.0f) {
                ctx->g_pan_x += dcx;
                ctx->g_pan_y += dcy;
                float wx = 0.0f, wy = 0.0f;
                while (ctx->g_pan_x >= 24.0f)  { wx += 1.0f; ctx->g_pan_x -= 24.0f; }
                while (ctx->g_pan_x <= -24.0f) { wx -= 1.0f; ctx->g_pan_x += 24.0f; }
                while (ctx->g_pan_y >= 24.0f)  { wy += 1.0f; ctx->g_pan_y -= 24.0f; }
                while (ctx->g_pan_y <= -24.0f) { wy -= 1.0f; ctx->g_pan_y += 24.0f; }
                if (wx != 0.0f || wy != 0.0f) {
                    nxn_pi_event ev; memset(&ev, 0, sizeof(ev));
                    ev.type = NXN_PI_EV_MOUSE_WHEEL;
                    ev.x = cx; ev.y = cy; ev.wheel_x = wx; ev.wheel_y = wy;
                    nxn_pi_push(ctx, &ev);
                    ctx->g_moved = 1;
                }
            }
        }
    } else {
        if (ctx->g_active && tc == 0) {
            if (!ctx->g_moved && (now_ms - ctx->g_start_ms) <= 320) {
                nxn_pi_event ev; memset(&ev, 0, sizeof(ev));
                ev.type = NXN_PI_EV_TWO_FINGER_TAP; ev.x = ctx->g_start_cx; ev.y = ctx->g_start_cy;
                nxn_pi_push(ctx, &ev);
                ev.type = NXN_PI_EV_MOUSE_DOWN; ev.button = NXN_MOUSE_RIGHT; nxn_pi_push(ctx, &ev);
                ev.type = NXN_PI_EV_MOUSE_UP;   ev.button = NXN_MOUSE_RIGHT; nxn_pi_push(ctx, &ev);
            }
            ctx->g_active = 0;
        }
        if (tc == 1 && ctx->long_press_right && !ctx->g_active) {
            if (!ctx->lp_active || ctx->lp_id != ids[0]) {
                ctx->lp_active = 1; ctx->lp_id = ids[0];
                ctx->lp_x = tx[0]; ctx->lp_y = ty[0];
                ctx->lp_start_ms = now_ms; ctx->lp_fired = 0;
            } else if (!ctx->lp_fired) {
                if (fabsf(tx[0] - ctx->lp_x) + fabsf(ty[0] - ctx->lp_y) > 16.0f) {
                    ctx->lp_fired = 1;
                } else if ((now_ms - ctx->lp_start_ms) >= 550) {
                    ctx->lp_fired = 1;
                    nxn_pi_event ev; memset(&ev, 0, sizeof(ev));
                    ev.x = tx[0]; ev.y = ty[0]; ev.button = NXN_MOUSE_RIGHT;
                    ev.type = NXN_PI_EV_MOUSE_DOWN; nxn_pi_push(ctx, &ev);
                    ev.type = NXN_PI_EV_MOUSE_UP;   nxn_pi_push(ctx, &ev);
                }
            }
        } else {
            ctx->lp_active = 0;
        }
    }

    /* 4. Gamepad sticks & button bindings */
    if (ctx->profile == NXN_PI_PROFILE_RTS || ctx->profile == NXN_PI_PROFILE_CRPG) {
        float lx = fabsf(ctx->pad.lx) > ctx->deadzone ? ctx->pad.lx : 0.0f;
        float ly = fabsf(ctx->pad.ly) > ctx->deadzone ? ctx->pad.ly : 0.0f;
        if (lx != 0.0f || ly != 0.0f) {
            float spd = ctx->cursor_speed * ((ctx->pad.buttons & NXN_BTN_LSTICK) ? 1.8f : 1.0f);
            float dx = lx * spd * dt_sec, dy = -ly * spd * dt_sec;
            ctx->cursor_x += dx; ctx->cursor_y += dy;
            if (ctx->cursor_x < 0.0f) ctx->cursor_x = 0.0f;
            if (ctx->cursor_y < 0.0f) ctx->cursor_y = 0.0f;
            if (ctx->cursor_x >= ctx->view_w) ctx->cursor_x = ctx->view_w - 1.0f;
            if (ctx->cursor_y >= ctx->view_h) ctx->cursor_y = ctx->view_h - 1.0f;
            nxn_pi_event ev; memset(&ev, 0, sizeof(ev));
            ev.type = NXN_PI_EV_MOUSE_MOVE;
            ev.x = ctx->cursor_x; ev.y = ctx->cursor_y; ev.dx = dx; ev.dy = dy;
            nxn_pi_push(ctx, &ev);
        }
        float ry = fabsf(ctx->pad.ry) > ctx->deadzone ? ctx->pad.ry : 0.0f;
        if (ry != 0.0f) {
            ctx->wheel_acc += ry * 10.0f * dt_sec;
            int st = (int)ctx->wheel_acc;
            if (st != 0) {
                ctx->wheel_acc -= (float)st;
                nxn_pi_event ev; memset(&ev, 0, sizeof(ev));
                ev.type = NXN_PI_EV_MOUSE_WHEEL;
                ev.x = ctx->cursor_x; ev.y = ctx->cursor_y; ev.wheel_y = (float)st;
                nxn_pi_push(ctx, &ev);
            }
        }
    } else if (ctx->profile == NXN_PI_PROFILE_FPS) {
        static const uint32_t wasd[4] = {26, 4, 22, 7}; /* W, A, S, D */
        uint8_t want[4] = {
            (uint8_t)(ctx->pad.ly >  ctx->deadzone ? 1 : 0),
            (uint8_t)(ctx->pad.lx < -ctx->deadzone ? 1 : 0),
            (uint8_t)(ctx->pad.ly < -ctx->deadzone ? 1 : 0),
            (uint8_t)(ctx->pad.lx >  ctx->deadzone ? 1 : 0)
        };
        for (int i = 0; i < 4; i++) {
            if (want[i] != ctx->stick_wasd_held[i]) {
                ctx->stick_wasd_held[i] = want[i];
                nxn_pi_event ev; memset(&ev, 0, sizeof(ev));
                ev.type = want[i] ? NXN_PI_EV_KEY_DOWN : NXN_PI_EV_KEY_UP;
                ev.hid_usage = wasd[i];
                nxn_pi_push(ctx, &ev);
            }
        }
        float rx = fabsf(ctx->pad.rx) > ctx->deadzone ? ctx->pad.rx : 0.0f;
        float ry = fabsf(ctx->pad.ry) > ctx->deadzone ? ctx->pad.ry : 0.0f;
        if (rx != 0.0f || ry != 0.0f) {
            nxn_pi_event ev; memset(&ev, 0, sizeof(ev));
            ev.type = NXN_PI_EV_MOUSE_MOVE;
            ev.dx = rx * 900.0f * dt_sec;
            ev.dy = -ry * 700.0f * dt_sec;
            nxn_pi_push(ctx, &ev);
        }
    }

    uint64_t newly = ctx->pad.buttons & ~ctx->prev_btns;
    uint64_t rel   = ctx->prev_btns & ~ctx->pad.buttons;
    ctx->prev_btns = ctx->pad.buttons;
    for (int i = 0; i < ctx->binding_count; i++) {
        const nxn_pi_binding* b = &ctx->bindings[i];
        int down = (newly & b->btn_mask) ? 1 : 0;
        int up   = (rel & b->btn_mask) ? 1 : 0;
        if (!down && !up) continue;
        if (b->kind == NXN_PI_BIND_KEY) {
            nxn_pi_event ev; memset(&ev, 0, sizeof(ev));
            ev.type = down ? NXN_PI_EV_KEY_DOWN : NXN_PI_EV_KEY_UP;
            ev.hid_usage = b->code;
            nxn_pi_push(ctx, &ev);
        } else if (b->kind == NXN_PI_BIND_MOUSE_BTN) {
            nxn_pi_event ev; memset(&ev, 0, sizeof(ev));
            ev.type = down ? NXN_PI_EV_MOUSE_DOWN : NXN_PI_EV_MOUSE_UP;
            ev.button = b->code; ev.x = ctx->cursor_x; ev.y = ctx->cursor_y;
            nxn_pi_push(ctx, &ev);
        } else if (b->kind == NXN_PI_BIND_WHEEL && down) {
            nxn_pi_event ev; memset(&ev, 0, sizeof(ev));
            ev.type = NXN_PI_EV_MOUSE_WHEEL;
            ev.wheel_y = (float)(int32_t)b->code;
            ev.x = ctx->cursor_x; ev.y = ctx->cursor_y;
            nxn_pi_push(ctx, &ev);
        } else if (b->kind == NXN_PI_BIND_TOGGLE_OSK && down) {
            ctx->osk_open = !ctx->osk_open;
            nxn_input_text_request(ctx->osk_open);
        }
    }
}

static inline int nxn_pi_poll_event(nxn_pi_ctx* ctx, nxn_pi_event* out) {
    if (!ctx || !out || ctx->q_count <= 0) return 0;
    *out = ctx->queue[ctx->q_head];
    ctx->q_head = (ctx->q_head + 1) % NXN_PI_MAX_EVENTS;
    ctx->q_count--;
    return 1;
}

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_PORT_INPUT_H */
