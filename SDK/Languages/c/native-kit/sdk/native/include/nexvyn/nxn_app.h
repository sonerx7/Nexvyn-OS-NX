/* Nexvyn Native SDK - lifecycle, capabilities, system info and the return to Nexvyn OS.
 *
 * The app is a .nxvmod that Nexvyn OS loads into its own process and runs in a window or full screen (app.json "mode":
 * "window" / "fullscreen"; NXN_CAP_WINDOWED, NATIVE_KIT.en.md 3.2). Nexvyn OS implements these calls; the app
 * does not call nxn_init itself in that case (it is already done when main starts).
 * The same library also builds a stand-alone .nro (the retired exclusive mode, kept only for packages built earlier):
 * nxn_init then reads the hand-off file (--nxn-handoff=<file>: paths, user, language, theme, where to return) and the
 * return record tells Nexvyn OS how the app ended. Started without Nexvyn OS (from the Homebrew menu), the same calls
 * work with standalone defaults and the app returns to whatever started it. */
#ifndef NEXVYN_NXN_APP_H
#define NEXVYN_NXN_APP_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

/* ---------------------------------------------------------------- init / shutdown */

enum {
    NXN_INIT_NO_CRASH_HANDLER = 1u << 0, /* the app installs its own __libnx_exception_handler */
    NXN_INIT_NO_RETURN = 1u << 1         /* do not start Nexvyn OS again when the app ends */
};

typedef struct nxn_init_params {
    uint32_t size;
    uint32_t flags;               /* NXN_INIT_* */
    const char* standalone_id;    /* app id used when not started by Nexvyn OS (NULL: the .nro file name) */
} nxn_init_params;

/* Reads the hand-off, opens the log, marks the launch as running. params may be NULL. Safe to call twice.
 * Thread: the main thread, once, before any other nxn_* call (inside Nexvyn OS it is already done). Memory: nothing
 * to free; `params` is only read during the call. */
NXN_API nxn_result nxn_init(const nxn_init_params* params);

/* Writes the final return record (state "exited"), closes what nxn_* opened. Called by nxn_run and at exit().
 * Thread: the main thread, after every other app thread was joined. Memory: releases every handle the app left open
 * (display, audio streams); pointers returned by nxn_info_string become invalid. */
NXN_API void nxn_shutdown(void);

/* Recommended entry: nxn_init, then entry(argc, argv) inside a crash guard, then nxn_shutdown.
 * A CPU fault on the main thread inside entry is recorded and the app returns to Nexvyn OS with
 * NXN_EXIT_CRASHED instead of taking the console down.
 *     int main(int argc, char** argv) { return nxn_run(argc, argv, app_main, NULL); }
 * Thread: the main thread; `entry` runs on the calling thread. Memory: argv is owned by the caller. */
typedef int (*nxn_entry_fn)(int argc, char** argv);
NXN_API int nxn_run(int argc, char** argv, nxn_entry_fn entry, const nxn_init_params* params);

#define NXN_EXIT_CRASHED 0x6E786E00 /* exit code of a run that ended in a recorded crash */

/* True once the app should end: the system asked to close it, nxn_request_return was called, or a worker
 * thread crashed. Call it once per frame (it also processes applet messages when the app has no SDL window).
 * Thread: any app thread (the main thread's calls also count as "alive" for the not-responding check). Memory: none. */
NXN_API int nxn_should_quit(void);

/* ---------------------------------------------------------------- return to Nexvyn OS */

typedef enum nxn_return_reason {
    NXN_RETURN_NORMAL = 0, /* finished */
    NXN_RETURN_USER = 1,   /* the user chose to go back to Nexvyn OS */
    NXN_RETURN_ERROR = 2,  /* the app could not continue; message is shown by Nexvyn OS */
    NXN_RETURN_CRASH = 3   /* set by the library only */
} nxn_return_reason;

/* Records why the app ends and makes nxn_should_quit() true. message (optional, <= 200 bytes UTF-8) is shown by
 * Nexvyn OS for NXN_RETURN_ERROR. The app then leaves its main loop and returns from its entry function.
 * Thread: any app thread. Memory: `message` is copied; it may be freed after the call. */
NXN_API void nxn_request_return(nxn_return_reason reason, int32_t code, const char* message);

/* ---------------------------------------------------------------- capabilities */

enum {
    NXN_CAP_HOSTED = 1ull << 0,       /* started by Nexvyn OS (hand-off read) */
    NXN_CAP_RETURN = 1ull << 1,       /* ending the app starts Nexvyn OS again */
    NXN_CAP_CRASH_GUARD = 1ull << 2,  /* CPU faults are recorded and returned (crash handler installed) */
    NXN_CAP_GL_CORE = 1ull << 3,      /* desktop OpenGL core profile (up to gl_max_major.gl_max_minor) */
    NXN_CAP_GLES = 1ull << 4,         /* OpenGL ES (up to gles_max_major.gles_max_minor) */
    NXN_CAP_AUDIO = 1ull << 5,
    NXN_CAP_TOUCH = 1ull << 6,
    NXN_CAP_KEYBOARD = 1ull << 7,     /* USB keyboard state */
    NXN_CAP_APPLET_MODE = 1ull << 8,  /* running as a library applet (less memory; see the porting guide) */
    NXN_CAP_EVENTS = 1ull << 9,       /* nxn_event_poll (NXN_EVENT_RESIZE) and nxn_display_resize */
    NXN_CAP_SHARED_LIBS = 1ull << 10, /* nxn_lib_open can load .nxvlib libraries (JIT code memory is available) */
    NXN_CAP_WINDOWED = 1ull << 11,    /* the app runs inside Nexvyn OS, in a window or full screen (a .nxvmod in the
                                         OS's process); without it the app is a stand-alone .nro */
    NXN_CAP_AUDIO_CLEAR = 1ull << 12, /* nxn_audio_clear (Native 1.1) */
    NXN_CAP_USB_INPUT = 1ull << 13,   /* nxn_input_mouse, nxn_input_key_poll, nxn_input_text (Native 1.1) */
    NXN_CAP_POWER_EVENTS = 1ull << 14,/* NXN_EVENT_DOCK / SUSPEND / RESUME (Native 1.1) */
    /* system services (nxn_sys.h, Native 1.1); windowed mode only, the stand-alone library answers NXN_ERR_UNSUPPORTED */
    NXN_CAP_NOTIFY = 1ull << 15,      /* nxn_notify */
    NXN_CAP_CLIPBOARD = 1ull << 16,   /* nxn_clipboard_get / nxn_clipboard_set */
    NXN_CAP_RUMBLE = 1ull << 17,      /* nxn_rumble */
    NXN_CAP_PICKER = 1ull << 18,      /* nxn_pick, nxn_grant_* (file / folder dialogs, folder access that is kept) */
    NXN_CAP_SAVEDATA = 1ull << 19,    /* nxn_save_* (the user's save folder and its backups) */
    NXN_CAP_PERMISSIONS = 1ull << 20, /* nxn_perm_query / nxn_perm_request */
    NXN_CAP_UI_TOKENS = 1ull << 21,   /* nxn_ui_tokens_get, nxn_ui_font_get, nxn_ui_icon_code, NXN_EVENT_THEME (nxn_ui.h) */
    NXN_CAP_TEXT = 1ull << 22,        /* nxn_tr, nxn_tr_format: the app's lang/<code>.json (nxn_ui.h) */
    NXN_CAP_NEXGFX = 1ull << 23,      /* the window's GL context offers what NexGFX needs (OpenGL 4.3 core): ngfx_* (nexgfx_native.h) */
    NXN_CAP_MIXER = 1ull << 24,       /* nxn_sfx_play, nxn_sfx_stop_all, nxn_tone: the OS sound mixer (nxn_audio.h) */
    NXN_CAP_INPUT_ACTIONS = 1ull << 25, /* nxn_input_action_buttons: the user's button mapping (nxn_input.h) */
    /* C/C++ runtime in windowed mode (W2a); the stand-alone .nro always had both */
    NXN_CAP_TLS = 1ull << 26,         /* thread_local / __thread in the module and its libraries (-mtls-dialect=trad) */
    NXN_CAP_CXX_EXCEPTIONS = 1ull << 27, /* C++ throw / catch across the module and its libraries */
    /* JIT and faults (nxn_jit.h); in a window each behind its own setting, off by default */
    NXN_CAP_JIT = 1ull << 28,           /* nxn_jit_*: executable code memory (rw + rx views) */
    NXN_CAP_FAULT_HANDLER = 1ull << 29, /* nxn_fault_handler_set: data aborts go to the app's handler first (fastmem) */
    NXN_CAP_GUARD_PAGES = 1ull << 30,   /* nxn_mem_guard: inaccessible / read-only pages in the app's own heap */
    /* window menu (nxn_menu.h): the app's menus in the OS menu bar, NXN_EVENT_MENU; setting native.windowMenu, minNative 1.1 */
    NXN_CAP_MENU = 1ull << 31,
    /* NXN_UI_FONT_CJK (nxn_ui.h) is a font id this system answers; the font itself may still be absent (NXN_ERR_NOT_FOUND) */
    NXN_CAP_UI_FONT_CJK = 1ull << 32
};

typedef struct nxn_caps {
    uint32_t size;
    uint32_t abi_gen;          /* NXN_ABI_GEN of the library */
    uint16_t version_major;    /* Native SDK version of the library */
    uint16_t version_minor;
    uint64_t features;         /* NXN_CAP_* */
    uint16_t gl_max_major, gl_max_minor;
    uint16_t gles_max_major, gles_max_minor;
} nxn_caps;

/* Fills min(out->size, sizeof(nxn_caps)) bytes. out->size must be set (NXN_STRUCT_INIT).
 * Thread: any thread (it needs no app state). Memory: written into the caller's struct. */
NXN_API nxn_result nxn_caps_get(nxn_caps* out);

/* ---------------------------------------------------------------- system / user info */

typedef struct nxn_info {
    uint32_t size;
    uint32_t hosted;           /* 1 when started by Nexvyn OS */
    uint32_t theme_dark;       /* 1 dark appearance, 0 light */
    uint32_t accent_rgb;       /* 0xRRGGBB, the user's accent colour */
    uint64_t confirm_buttons;  /* NXN_BTN_* mask the user confirms with (Nexvyn OS's mapping) */
    uint64_t cancel_buttons;   /* NXN_BTN_* mask the user goes back with */
} nxn_info;

/* Thread: any app thread. Memory: written into the caller's struct. */
NXN_API nxn_result nxn_info_get(nxn_info* out);

typedef enum nxn_info_key {
    NXN_INFO_APP_ID = 0,
    NXN_INFO_APP_VERSION = 1,
    NXN_INFO_OS_VERSION = 2,      /* "" when standalone */
    NXN_INFO_SDK_VERSION = 3,     /* script SDK of the system, "" when standalone */
    NXN_INFO_NATIVE_VERSION = 4,  /* Native SDK version of the system ("1.1"), "" when standalone */
    NXN_INFO_LANGUAGE = 5,        /* "en", "tr", ... (the system language when standalone) */
    NXN_INFO_USER_NAME = 6,
    NXN_INFO_THEME = 7            /* "dark" / "light" */
} nxn_info_key;

/* Never NULL: "" for an unknown key or value. The string lives until nxn_shutdown.
 * Thread: any app thread. Memory: owned by the library, read-only, never freed by the caller. */
NXN_API const char* nxn_info_string(nxn_info_key key);

/* Text of the last NXN_ERR_SYSTEM / NXN_ERR_IO on this thread ("" if none).
 * Thread: any app thread; the text is per thread (another thread's failure never shows here). Memory: owned by the
 * library; the pointer stays valid until the next failing nxn_* call on the same thread; never freed by the caller. */
NXN_API const char* nxn_last_error(void);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_APP_H */
