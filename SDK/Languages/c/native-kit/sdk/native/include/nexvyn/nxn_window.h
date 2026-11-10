/* Nexvyn Native SDK - window control (Native 1.2, NXN_CAP_WINDOW_CTL).
 *
 * For windowed apps that should behave like part of Nexvyn OS: the title bar says what is open ("Game - Emulator"), a
 * full screen switch from a menu or key, and the dot that tells the user there is unsaved work (the same "edited" mark
 * and quit-time list the OS apps use). Script apps have this as sys.title and the app.json "window" block; nothing
 * changes for them.
 *
 *     nxn_window_set_title("Super Game", "Level 3");        // title bar: "Super Game - Level 3"
 *     nxn_window_set_mode(NXN_WIN_FULLSCREEN);              // F11; NXN_EVENT_RESIZE follows when the size changed
 *     nxn_window_set_modified(1);                           // unsaved work: Nexvyn OS asks before quitting
 *
 * All three return at once; the OS main thread applies them within a frame (nothing here waits for it). They return
 * NXN_ERR_UNSUPPORTED when NXN_CAP_WINDOW_CTL is not set (a stand-alone .nro has no window). Add-only like the rest of
 * the ABI: an app built for 1.0 or 1.1 never sees a difference. Thread: any app thread. Memory: strings are copied. */
#ifndef NEXVYN_NXN_WINDOW_H
#define NEXVYN_NXN_WINDOW_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

#define NXN_WINDOW_TITLE_MAX 200 /* bytes of title, and of subtitle; longer text is cut (never in the middle of a UTF-8 character) */

typedef enum nxn_window_mode {
    NXN_WIN_NORMAL = 0,    /* the window as the user last sized it */
    NXN_WIN_MAXIMIZED = 1, /* fills the work area (ignored when the app.json "window" says "resizable": false) */
    NXN_WIN_FULLSCREEN = 2 /* the whole screen: menu bar and Dock hidden while focused */
} nxn_window_mode;

/* Sets the title bar text: `title` (NULL or "" keeps the app's name) and an optional `subtitle` (NULL = none), shown as
 * "title - subtitle". The text is a plain string, not a lang key (use nxn_tr first for a translated one). */
NXN_API nxn_result nxn_window_set_title(const char* title, const char* subtitle);

/* Asks for a window mode. A request, not a promise: the user can change it again at once. NXN_ERR_INVALID for a value not in
 * nxn_window_mode. Nexvyn OS answers a size change with NXN_EVENT_RESIZE like for a user's own resize. */
NXN_API nxn_result nxn_window_set_mode(nxn_window_mode mode);

/* modified != 0: the window has unsaved work. The title shows the OS "edited" mark and Nexvyn OS lists the app among the
 * ones with unsaved work before it quits, restarts or powers off. Closing the window still posts NXN_EVENT_QUIT as always:
 * the app saves (or asks) then. 0 clears the mark. */
NXN_API nxn_result nxn_window_set_modified(int modified);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_WINDOW_H */
