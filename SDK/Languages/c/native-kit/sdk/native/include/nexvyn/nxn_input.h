/* Nexvyn Native SDK - input: controller (player 1 + handheld), touch screen, USB keyboard.
 *
 * Button bits are the same as Nexvyn OS's pad bits (and the console's HID order). confirm / cancel follow the
 * user's button mapping in Nexvyn OS (System Settings), so an app that uses NXN_ACT_CONFIRM / NXN_ACT_CANCEL feels
 * the same as every other Nexvyn app.
 *
 * Threads: poll from one thread (normally the main thread, once per frame): "pressed" and "released" are kept per
 * app between two polls, so two polling threads would each miss edges the other consumed. nxn_input_touch and
 * nxn_input_key_held read the state of the last poll and may be called from any app thread. Inside Nexvyn OS input is
 * empty while the window has no focus. Memory: written into the caller's structs; nothing to free. */
#ifndef NEXVYN_NXN_INPUT_H
#define NEXVYN_NXN_INPUT_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

enum {
    NXN_BTN_A = 1ull << 0, NXN_BTN_B = 1ull << 1, NXN_BTN_X = 1ull << 2, NXN_BTN_Y = 1ull << 3,
    NXN_BTN_LSTICK = 1ull << 4, NXN_BTN_RSTICK = 1ull << 5, NXN_BTN_L = 1ull << 6, NXN_BTN_R = 1ull << 7,
    NXN_BTN_ZL = 1ull << 8, NXN_BTN_ZR = 1ull << 9, NXN_BTN_PLUS = 1ull << 10, NXN_BTN_MINUS = 1ull << 11,
    NXN_BTN_LEFT = 1ull << 12, NXN_BTN_UP = 1ull << 13, NXN_BTN_RIGHT = 1ull << 14, NXN_BTN_DOWN = 1ull << 15
};

/* Logical actions (Nexvyn OS's mapping). */
enum {
    NXN_ACT_CONFIRM = 1u << 0,
    NXN_ACT_CANCEL = 1u << 1
};

typedef struct nxn_input_state {
    uint32_t size;
    uint32_t actions;          /* NXN_ACT_* held */
    uint64_t buttons;          /* NXN_BTN_* held */
    uint64_t pressed;          /* went down since the previous nxn_input_poll */
    uint64_t released;         /* went up since the previous nxn_input_poll */
    float lx, ly, rx, ry;      /* sticks, -1..1, y up */
    uint32_t actions_pressed;  /* NXN_ACT_* that went down */
    uint32_t touch_count;      /* touches this frame (see nxn_input_touch) */
} nxn_input_state;

typedef struct nxn_touch {
    uint32_t size;
    uint32_t id;      /* stable while the finger stays down */
    float x, y;       /* screen pixels of a 1280x720 space */
} nxn_touch;

/* Reads the controllers and the touch screen. Call once per frame. */
NXN_API nxn_result nxn_input_poll(nxn_input_state* out);
NXN_API nxn_result nxn_input_touch(uint32_t index, nxn_touch* out);
/* USB keyboard: is the key with this HID usage id (4 = 'a' ... see the USB HID tables) held? Usage ids 224..231 are the
 * modifiers (224 left Ctrl, 225 left Shift, 226 left Alt, 227 left GUI, 228..231 the right ones; Nexvyn OS reports the
 * modifier state per kind, so the left and the right key of a pair are held together). */
NXN_API int nxn_input_key_held(uint32_t hid_usage);

/* ---- USB keyboard events, USB mouse and typed text (Native 1.1; check nxn_caps.features for NXN_CAP_USB_INPUT).
 * Without NXN_CAP_USB_INPUT these return NXN_ERR_UNSUPPORTED (nxn_input_key_poll and nxn_input_text: 0). Inside Nexvyn
 * OS they work only while the window has focus. */

typedef struct nxn_key_event {
    uint32_t size;
    uint32_t usage;  /* USB HID usage id (4 = 'a'; 224..231 modifiers) */
    uint32_t down;   /* 1 pressed (a held key repeats as presses), 0 released */
    uint32_t mods;   /* NXN_MOD_* held after this event */
} nxn_key_event;

enum {
    NXN_MOD_SHIFT = 1u << 0, NXN_MOD_CTRL = 1u << 1, NXN_MOD_ALT = 1u << 2, NXN_MOD_GUI = 1u << 3
};

/* Takes the oldest key event off the queue (64 deep, in the order the keys went down and up: a tap inside one frame is
 * not lost). Returns 1 when an event was written, 0 when there is none, a negative nxn_result for a bad argument.
 * Thread: one consumer thread. Memory: written into the caller's struct. */
NXN_API int nxn_input_key_poll(nxn_key_event* out);

/* Text the user typed since the last call, UTF-8 and NUL terminated, as the system's keyboard produced it (layout, dead
 * keys and the on-screen keyboard included; the keys themselves also arrive through nxn_input_key_poll). Returns the
 * number of bytes written without the NUL (0: none), a negative nxn_result for a bad argument. What does not fit in
 * `cap` stays for the next call. Thread: one consumer thread. Memory: written into the caller's buffer. */
NXN_API int nxn_input_text(char* out, size_t cap);

enum {
    NXN_MOUSE_LEFT = 1u << 0, NXN_MOUSE_RIGHT = 1u << 1, NXN_MOUSE_MIDDLE = 1u << 2
};

typedef struct nxn_mouse {
    uint32_t size;
    uint32_t present;        /* 1 when the pointer is inside the window's content */
    float x, y;              /* position in display pixels (the surface of nxn_display_open), y down */
    float dx, dy;            /* movement since the previous nxn_input_mouse call, in display pixels */
    float wheel_x, wheel_y;  /* scrolling since the previous call, in notches (+y = away from the user = up) */
    uint32_t buttons;        /* NXN_MOUSE_* held */
    uint32_t pressed;        /* NXN_MOUSE_* that went down since the previous call (a click inside one frame is kept) */
    uint32_t released;       /* NXN_MOUSE_* that went up since the previous call */
} nxn_mouse;

/* The pointer Nexvyn OS shows over the window (a USB mouse, or the controller pointer), as a mouse. The first call
 * turns the app into a mouse user: from then on the pointer no longer also counts as touch 0 in nxn_input_touch (an
 * app that never calls this keeps the old behaviour, the pointer acts as a finger). Call it once per frame.
 * Thread: one consumer thread (the main thread). Memory: written into the caller's struct. */
NXN_API nxn_result nxn_input_mouse(nxn_mouse* out);

/* ---- action -> button mapping (NXN_CAP_INPUT_ACTIONS, windowed apps). The user maps controller buttons to functions in
 * Settings > Controllers ("select", "back", "context", "close_window", "launcher", "overview", "switch_prev", "switch_next",
 * "desktop", "notifications", "control_center", "keyboard", "screenshot", "search", "assistant", "scroll_mode", "zoom",
 * "volume_up", "volume_down", "brightness_up", "brightness_down", "lock", "nav_up", "nav_down", "nav_left", "nav_right").
 * This returns the NXN_BTN_* mask of the physical buttons the user mapped to `action` now (0 = none), so an app can offer
 * "confirm" and "cancel" on the buttons the user chose: test it against nxn_input_state.buttons / .pressed. The mask follows
 * the setting within a frame: read it when you need it, do not cache it for a whole session. NXN_ERR_NOT_FOUND for an unknown name. Without the cap: NXN_ERR_UNSUPPORTED.
 * Thread: any app thread (it reads a snapshot the OS main thread keeps per window). Memory: none. */
NXN_API nxn_result nxn_input_action_buttons(const char* action, uint64_t* mask);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_INPUT_H */
