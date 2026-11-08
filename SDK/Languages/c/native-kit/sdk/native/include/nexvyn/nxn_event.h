/* Nexvyn Native SDK - system events: a small queue the app drains once per frame.
 *
 * Inside Nexvyn OS the events are NXN_EVENT_RESIZE (the window's content size changed: the user resized it, or switched
 * between a window and full screen), NXN_EVENT_QUIT and NXN_EVENT_FOCUS. A stand-alone .nro has RESIZE only: the console
 * was docked or undocked. The output the system composes changes
 * between 1280x720 (handheld) and 1920x1080 (docked); the app decides whether to follow it (nxn_display_resize) or to
 * keep drawing at its size, which the system scales. The ABI is add-only: new event types may appear, an app ignores
 * types it does not know, and `nxn_event.size` lets later versions append fields (the same rule as every other struct).
 *
 *     nxn_event e = NXN_STRUCT_INIT(nxn_event);
 *     while (nxn_event_poll(&e) > 0) {
 *         if (e.type == NXN_EVENT_RESIZE) { nxn_display_resize(d, e.width, e.height); glViewport(0, 0, e.width, e.height); }
 *         e.size = sizeof e;
 *     }
 *
 * Events are collected while the app calls nxn_should_quit() (or while SDL pumps its events), so call that every frame.
 * Check nxn_caps.features for NXN_CAP_EVENTS. */
#ifndef NEXVYN_NXN_EVENT_H
#define NEXVYN_NXN_EVENT_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

typedef enum nxn_event_type {
    NXN_EVENT_NONE = 0,
    NXN_EVENT_RESIZE = 1, /* the window's content size changed (window <-> full screen too); stand-alone: docked /
                             handheld change. width, height (the new size) and docked are set */
    NXN_EVENT_QUIT = 2,   /* inside Nexvyn OS: the close button or Nexvyn OS quitting. Save and return from the entry soon (a
                             few seconds); nxn_should_quit() is true from now on */
    NXN_EVENT_FOCUS = 3,  /* inside Nexvyn OS: the window gained (focused = 1) or lost (0, also when minimized) the focus.
                             Input is empty while unfocused; a game may pause */
    NXN_EVENT_DOCK = 4,   /* Native 1.1 (NXN_CAP_POWER_EVENTS): the console was docked (docked = 1) or taken out of its
                             dock (0). width / height = the new output (1920x1080 / 1280x720). A window that follows the
                             output also gets NXN_EVENT_RESIZE; this one tells apps that do not (fixed size) to switch
                             touch / button hints or the quality of a heavy scene */
    NXN_EVENT_SUSPEND = 5,/* Native 1.1 (NXN_CAP_POWER_EVENTS): Nexvyn OS goes to the background or the console goes to
                             sleep: save, stop the sound and heavy work. Until NXN_EVENT_RESUME Nexvyn OS plays no sound
                             of the app and shows no new frame (nxn_display_swap does not read the picture back) */
    NXN_EVENT_RESUME = 6, /* Native 1.1: back in the foreground / the console woke up. The sound that was queued before
                             the suspend is dropped (a stale buffer never plays); the network may have dropped, clocks
                             jumped: check time and connections */
    NXN_EVENT_THEME = 7,  /* Native 1.1 (NXN_CAP_UI_TOKENS): the OS look changed (light / dark, accent, accessibility). Read
                             nxn_ui_tokens_get again; nxn_info.theme_dark / accent_rgb follow too. Only apps with "minNative"
                             1.1 or later get it */
    NXN_EVENT_MENU = 8    /* Native 1.1 (NXN_CAP_MENU): the user picked an item of the app's window menu (nxn_menu.h);
                             item_id is the id the app gave it. Never merged: every pick arrives. Only apps with "minNative"
                             1.1 or later get it */
} nxn_event_type;

typedef struct nxn_event {
    uint32_t size;      /* sizeof(nxn_event) of the caller; set it (NXN_STRUCT_INIT) before every poll */
    uint32_t type;      /* nxn_event_type */
    uint64_t time_ns;   /* nxn_time_ns() when the system reported it */
    uint32_t width;     /* NXN_EVENT_RESIZE: 1920 docked, 1280 handheld */
    uint32_t height;    /* 1080 docked, 720 handheld */
    uint32_t docked;    /* 1 docked (TV), 0 handheld */
    uint32_t focused;   /* NXN_EVENT_FOCUS: 1 gained, 0 lost (added in Native 1.0 windowed mode; size rule applies) */
    uint32_t item_id;   /* NXN_EVENT_MENU: the picked item's id (Native 1.1; size rule applies) */
    uint32_t reserved;  /* 0; the tail padding made explicit (same layout), see nxn_base.h */
} nxn_event;

/* Takes the oldest event off the queue and fills min(out->size, sizeof(nxn_event)) bytes.
 * Returns 1 when an event was written, 0 when there is none, a negative nxn_result for a bad argument or when
 * nxn_init was not called. Events of the same kind that pile up while the app is busy are merged (the newest
 * RESIZE wins), so a loop that polls every frame never falls behind.
 * Thread: one consumer thread, normally the main thread (events are taken in order; two threads polling would split
 * them). Memory: written into the caller's struct. */
NXN_API int nxn_event_poll(nxn_event* out);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_EVENT_H */
