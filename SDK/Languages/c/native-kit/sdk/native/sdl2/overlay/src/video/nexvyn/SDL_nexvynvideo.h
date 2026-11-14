/* Nexvyn OS SDL2 driver (windowed native apps): video, GL context, window events, touch, keyboard, mouse.
 * Added to SDL2 (zlib license) by the Nexvyn native kit; see sdk/native/sdl2/README.md. Not part of upstream SDL. */
#ifndef SDL_nexvynvideo_h_
#define SDL_nexvynvideo_h_

#include "../../SDL_internal.h"
#include "../SDL_sysvideo.h"
#include <nexvyn/nexvyn_native.h>

#if SDL_VIDEO_DRIVER_NEXVYN

/* The one SDL window of the app and the one nxn display behind its GL context. */
typedef struct NEXVYN_GLContext {
    nxn_display *display;
    SDL_Window *window;
    int follow;   /* the display follows the window's content size (opened with 0 x 0) */
} NEXVYN_GLContext;

typedef struct NEXVYN_VideoData {
    SDL_Window *window;
    NEXVYN_GLContext *gl;
    int focused;
    int touch_added;
    uint32_t touch_ids[16];
    int touch_count;
    int usb_input; /* the system has NXN_CAP_USB_INPUT: keyboard events, text, mouse */
    int mouse_seen, mouse_x, mouse_y;

    /* Two-finger gesture & long-press state (translates multi-touch to wheel / pinch zoom / right-click) */
    int gesture_active;
    uint32_t g_id0, g_id1;
    float g_start_dist, g_last_dist;
    float g_start_cx, g_start_cy;
    float g_last_cx, g_last_cy;
    float g_pinch_acc, g_pan_acc_x, g_pan_acc_y;
    Uint64 g_start_ms;
    int g_moved_or_zoomed;

    int lp_active;
    uint32_t lp_id;
    float lp_x, lp_y;
    Uint64 lp_start_ms;
    int lp_fired;

    /* Optional gamepad-to-mouse bridge state (NEXVYN_GAMEPAD_MOUSE=1) */
    float gp_cur_x, gp_cur_y;
    int gp_cur_init;
    Uint64 gp_last_ms;
    uint64_t gp_prev_btns;
    float gp_wheel_acc;
    int gp_osk_open;
} NEXVYN_VideoData;

/* Shared with the joystick driver: one nxn_input_poll per pump (nxn_input_poll keeps per-app edge state, so two
 * pollers would steal each other's edges). force = 1 takes a new sample, 0 reuses one younger than 2 ms. */
const nxn_input_state *NEXVYN_PollInput(int force);

#endif /* SDL_VIDEO_DRIVER_NEXVYN */
#endif /* SDL_nexvynvideo_h_ */
