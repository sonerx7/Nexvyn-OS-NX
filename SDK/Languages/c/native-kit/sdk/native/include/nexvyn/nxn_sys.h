/* Nexvyn Native SDK - time, threads, logging, and the system services (permissions, notification, clipboard, rumble,
 * dialogs, save folder).
 *
 * Logging goes to Nexvyn OS's log folder (System/Logs/Apps/<app id>.log), where the Console app and crash reports
 * find it; standalone it goes to the app's data folder (app.log).
 *
 * Threads: everything here may be called from any app thread (logging is serialized inside the library); a thread
 * handle is joined once, by one thread. Memory: nothing is allocated for the caller to free; nxn_thread* is freed by
 * nxn_thread_join. */
#ifndef NEXVYN_NXN_SYS_H
#define NEXVYN_NXN_SYS_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

/* ---------------------------------------------------------------- time */
/* Thread: any thread. Memory: none (nxn_sleep_ns only blocks the calling thread). */
NXN_API uint64_t nxn_time_ns(void);   /* monotonic, since boot */
NXN_API int64_t nxn_time_unix(void);  /* wall clock, seconds since 1970 (UTC) */
NXN_API void nxn_sleep_ns(uint64_t ns);

/* ---------------------------------------------------------------- threads */
typedef struct nxn_thread nxn_thread; /* opaque */
typedef void (*nxn_thread_fn)(void* arg);

typedef struct nxn_thread_params {
    uint32_t size;
    nxn_thread_fn fn;
    void* arg;
    uint32_t stack_size;  /* 0 = 256 KB */
    int32_t core;         /* -2 = any core (default), 0..2 = that core; core 3 belongs to the system */
    const char* name;     /* shown in crash records */
} nxn_thread_params;

/* A crash in a thread started here is recorded with its name and makes nxn_should_quit() true.
 * Thread: any app thread. Memory: *out is a library-owned handle, freed by nxn_thread_join (the app must join every
 * thread before it returns); `params` and `name` are read during the call only (the name is copied); `arg` is passed
 * to `fn` as is and stays the app's. Inside Nexvyn OS the thread's priority is clamped and core 3 is avoided. */
NXN_API nxn_result nxn_thread_start(const nxn_thread_params* params, nxn_thread** out);
/* Waits, then frees the handle. Thread: any app thread except the thread being joined. Memory: `t` must not be used
 * afterwards. */
NXN_API nxn_result nxn_thread_join(nxn_thread* t);

/* ---------------------------------------------------------------- logging */
typedef enum nxn_log_level {
    NXN_LOG_DEBUG = 0,
    NXN_LOG_INFO = 1,
    NXN_LOG_WARN = 2,
    NXN_LOG_ERROR = 3
} nxn_log_level;

/* Thread: any app thread. Memory: the text is formatted into a library buffer (about 500 bytes, longer text is cut)
 * and copied out; the caller keeps ownership of `fmt` and its arguments. */
NXN_API void nxn_log(nxn_log_level level, const char* fmt, ...) __attribute__((format(printf, 2, 3)));
/* Thread: any app thread. Memory: `message` is copied during the call. */
NXN_API void nxn_log_write(nxn_log_level level, const char* message);

/* ================================================================ system services (Native 1.1)
 * Windowed mode only (a window or full screen inside Nexvyn OS). Every service has a NXN_CAP_* bit in nxn_caps_get();
 * a library or system without it answers NXN_ERR_UNSUPPORTED (the stand-alone libnexvyn_native.a always does).
 * Each call runs on the calling app thread; whatever needs Nexvyn OS's user interface (notification, clipboard,
 * dialogs) is handed to the OS's main thread and the calling thread waits for the answer, never the other way round. A
 * call that waits for the user (nxn_pick, nxn_perm_request) keeps the app "alive" for the not-responding check and
 * returns NXN_ERR_NOT_READY when the window is closing. Put such a call on a worker thread when the frame loop must not
 * stop; a game normally calls it from a menu. */

/* ---------------------------------------------------------------- permissions */
/* The permissions app.json "permissions" can declare and a native app can use: "network" (sockets) and
 * "notifications" (nxn_notify). The user answers on the install sheet and in System Settings > Privacy & Security. */
typedef enum nxn_perm_state {
    NXN_PERM_NOT_DECLARED = 0, /* app.json does not list it: the calls it gates fail with NXN_ERR_DENIED */
    NXN_PERM_DENIED = 1,       /* declared, but the user turned it off */
    NXN_PERM_GRANTED = 2
} nxn_perm_state;

/* Current state of `name` (any letter case). NXN_ERR_INVALID for another name or NULL; NXN_ERR_UNSUPPORTED without
 * NXN_CAP_PERMISSIONS. Thread: any app thread. Memory: written to *out; `name` is read during the call. */
NXN_API nxn_result nxn_perm_query(const char* name, nxn_perm_state* out);
/* Asks the user again for a permission the app declares and the user turned off (a dialog; at most once per
 * permission and session, an app cannot nag). Waits for the answer; *out is the state afterwards. Without a question
 * to ask (granted, not declared, already asked this session) it returns the current state at once.
 * Thread: any app thread; blocks until answered. Memory: as nxn_perm_query. */
NXN_API nxn_result nxn_perm_request(const char* name, nxn_perm_state* out);

/* ---------------------------------------------------------------- notification, clipboard, rumble */
/* Posts a notification banner (a title and a body, UTF-8; longer text is cut at 200 bytes) that Nexvyn OS shows at
 * the top right. Needs the "notifications" permission: NXN_ERR_DENIED without it (one line goes to the app's log).
 * Does not wait for the banner. Thread: any app thread. Memory: both strings are copied during the call (body may be
 * NULL). */
NXN_API nxn_result nxn_notify(const char* title, const char* body);

/* The clipboard (text, UTF-8; open to every app, no permission). nxn_clipboard_get copies the text into buf (with a
 * terminating 0) and stores its length in bytes, without the 0, in *len (len may be NULL); NXN_ERR_TOO_SMALL when it does
 * not fit (*len is the size needed, buf is untouched); an empty clipboard is NXN_OK with "" in buf. It is the clipboard of
 * Nexvyn OS, shared with its apps. Thread: any app thread; both hand the work to the OS's main thread and wait a moment.
 * Memory: the caller owns buf; the text is copied during the call. */
NXN_API nxn_result nxn_clipboard_get(char* buf, size_t cap, size_t* len);
NXN_API nxn_result nxn_clipboard_set(const char* text);

/* Controller rumble: strength 0..1, ms 1..2000 (more is cut to 2000). strength 0 stops it. A newer call replaces
 * the running one; the motors stop when the time is up, when the window closes or crashes, and a window in the
 * background never rumbles (the call returns NXN_OK and does nothing). Does not wait.
 * Thread: any app thread. Memory: none. */
NXN_API nxn_result nxn_rumble(float strength, uint32_t ms);

/* ---------------------------------------------------------------- file and folder dialogs, folder access */
typedef enum nxn_pick_kind {
    NXN_PICK_OPEN_FILE = 0,
    NXN_PICK_SAVE_FILE = 1,
    NXN_PICK_FOLDER = 2
} nxn_pick_kind;

enum {
    NXN_PICK_REMEMBER = 1u << 0 /* NXN_PICK_FOLDER: keep the folder as one the user gave this app access to */
};

typedef struct nxn_pick_params {
    uint32_t size;
    uint32_t kind;             /* nxn_pick_kind */
    uint32_t flags;            /* NXN_PICK_* */
    const char* title;         /* dialog title, NULL = the system's */
    const char* extensions;    /* NXN_PICK_OPEN_FILE: ".png;.jpg" (any case); NULL or "" = every file */
    const char* default_name;  /* NXN_PICK_SAVE_FILE: the name offered ("save.dat"), NULL = "untitled" */
} nxn_pick_params;

/* Shows Nexvyn OS's open / save / folder dialog and waits for the user. On NXN_OK `path` holds the chosen full path
 * ("sdmc:/...", for stdio / POSIX calls); NXN_ERR_CANCELLED when the user dismissed it (path is ""); NXN_ERR_TOO_SMALL
 * when the path does not fit. A path the user picked is the app's to use; native code is not sandboxed by the kernel, so
 * this is the honest way to ask (Store review checks it). With NXN_PICK_REMEMBER a folder stays granted across runs
 * (nxn_grant_*): the app asks once and finds the folder again at its next start.
 * Thread: any app thread, not meant for a frame loop (it waits for the user). Memory: the caller owns `path`; the
 * params and their strings are read during the call. */
NXN_API nxn_result nxn_pick(const nxn_pick_params* params, char* path, size_t cap);
/* The index-th folder the user gave this app access to (kept in Nexvyn OS's settings, not in the app's data: the user
 * can take it back); NXN_ERR_NOT_FOUND at the end of the list. */
NXN_API nxn_result nxn_grant_get(uint32_t index, char* path, size_t cap);
/* *granted = 1 when `path` is a granted folder or lies inside one. */
NXN_API nxn_result nxn_grant_check(const char* path, int* granted);
/* Gives a granted folder back (the exact path nxn_grant_get returned); NXN_ERR_NOT_FOUND when it is not in the list.
 * Thread of the three: any app thread (settings access, no dialog). Memory: caller buffers; strings read during the call. */
NXN_API nxn_result nxn_grant_revoke(const char* path);

/* ---------------------------------------------------------------- the user's save folder and its backups */
/* Each Nexvyn OS user has their own save folder for the app: <data>/save inside NXN_DIR_DATA (the data folder is per
 * user already). Backups live outside the app's data, in the user's Library/Backups/<app id>/<slot>, so clearing the
 * app's data does not take them. A slot name is 1..48 characters of A-Z a-z 0-9 . _ - and not "." or "..".
 * These calls copy files on the calling thread and can take a while on a slow SD card: call them from a worker thread.
 * Thread of all nxn_save_*: any app thread (two threads on one slot race like any file access). Memory: caller buffers. */
/* Full path of the save folder (created when missing). */
NXN_API nxn_result nxn_save_path(char* path, size_t cap);
/* Copies the save folder into the slot; an older backup of the same name is replaced only after the copy succeeded. */
NXN_API nxn_result nxn_save_backup(const char* slot);
/* Replaces the save folder with the slot's copy. The current save is kept until the copy is in place; on any failure it
 * stays as it was. NXN_ERR_NOT_FOUND when the slot does not exist. */
NXN_API nxn_result nxn_save_restore(const char* slot);
/* The index-th slot name, sorted by name; NXN_ERR_NOT_FOUND at the end of the list. */
NXN_API nxn_result nxn_save_backup_get(uint32_t index, char* slot, size_t cap);
NXN_API nxn_result nxn_save_backup_delete(const char* slot);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_SYS_H */
