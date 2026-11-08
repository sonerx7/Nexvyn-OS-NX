/* Native SDK Showcase - shared declarations: the feature table, result lines and the self-tests. */
#ifndef SHOWCASE_H
#define SHOWCASE_H
#include <nexvyn/nexvyn_native.h>
#include <stdarg.h>
#include <stddef.h>

enum Res { RES_PEND = 0, RES_OK, RES_FAIL, RES_NA, RES_TODO };

/* One row of the Status page (id, group, name, modes: B both, E exclusive only, W windowed only). Order = screen order. */
#define SC_FEATURES(X)                                                          \
    X(F_INIT, "Core", "nxn_init / nxn_caps_get / ABI", 'B')                     \
    X(F_INFO, "Core", "nxn_info_get / nxn_info_string", 'B')                    \
    X(F_LOG, "Core", "nxn_log (app log)", 'B')                                  \
    X(F_GL, "Display", "nxn_display_open + GL 4.3 core", 'B')                   \
    X(F_GLAD, "Display", "nxn_display_proc (glad loader)", 'B')                \
    X(F_NEXGFX, "Display", "NexGFX native: ngfx_* PBR draw (pixel check)", 'W')    \
    X(F_MIXER, "Sound", "nxn_sfx_play / nxn_tone / nxn_sfx_stop_all (OS mixer)", 'W') \
    X(F_ACTIONS, "Input", "nxn_input_action_buttons (button mapping)", 'W')       \
    X(F_SWAP, "Display", "nxn_display_swap (frames)", 'B')                      \
    X(F_RESIZE_EVT, "Display", "NXN_EVENT_RESIZE", 'B')                         \
    X(F_RESIZE, "Display", "nxn_display_resize", 'B')                           \
    X(F_FOCUS_EVT, "Display", "NXN_EVENT_FOCUS", 'W')                           \
    X(F_DOCK_EVT, "Display", "NXN_EVENT_DOCK (dock / handheld, console)", 'W')\
    X(F_SLEEP_EVT, "Display", "NXN_EVENT_SUSPEND / RESUME (sleep)", 'W')    \
    X(F_PAD, "Input", "nxn_input_poll (buttons, sticks)", 'B')                  \
    X(F_TOUCH, "Input", "nxn_input_touch", 'B')                                 \
    X(F_KEYS, "Input", "nxn_input_key_held (USB keyboard)", 'B')                \
    X(F_USB_MOUSE, "Input", "nxn_input_mouse (USB mouse / pointer)", 'W')   \
    X(F_KEYPOLL, "Input", "nxn_input_key_poll + nxn_input_text", 'W')       \
    X(F_RUMBLE, "Input", "nxn_rumble (controller vibration)", 'W')              \
    X(F_AUDIO_OPEN, "Audio", "nxn_audio_open / pause", 'B')                     \
    X(F_AUDIO_TONE, "Audio", "nxn_audio_queue (tone, pan)", 'B')                \
    X(F_AUDIO_STOP, "Audio", "nxn_audio_clear (drop queued audio at once)", 'B')\
    X(F_FS_WRITE, "Files", "nxn_fs_write / nxn_fs_read", 'B')                   \
    X(F_FS_LIST, "Files", "nxn_fs_path + opendir / readdir", 'B')               \
    X(F_FS_STAT, "Files", "fstat on an open file", 'B')                         \
    X(F_FS_DELETE, "Files", "unlink / rmdir / stat after delete", 'B')          \
    X(F_FS_SANDBOX, "Files", "sandbox: bundle write, ../ path refused", 'B')    \
    X(F_PICK, "Files", "nxn_pick (open / save / folder dialog)", 'W')           \
    X(F_GRANT, "Files", "nxn_grant_get / check / revoke (kept folder access)", 'W')\
    X(F_SAVE, "Files", "nxn_save_path / backup / restore (user's saves)", 'W')  \
    X(F_DEV_NULL, "Files", "/dev/null (compat)", 'B')                           \
    X(F_DEV_RANDOM, "Files", "/dev/random (compat)", 'B')                       \
    X(F_USER, "System", "user name, language, theme", 'B')                      \
    X(F_VERSIONS, "System", "OS / SDK / native versions", 'B')                  \
    X(F_MODES, "System", "launch modes (caps: windowed, applet)", 'B')          \
    X(F_PERM, "System", "nxn_perm_query / nxn_perm_request", 'W')               \
    X(F_NOTIF, "System", "nxn_notify (permission notifications)", 'W')          \
    X(F_CLIP, "System", "nxn_clipboard_set / nxn_clipboard_get", 'W')           \
    X(F_UI_TOKENS, "UI", "nxn_ui_tokens_get / font / icon (OS look)", 'W')       \
    X(F_UI_THEME_EVT, "UI", "NXN_EVENT_THEME (change light / dark)", 'W')        \
    X(F_UI_TEXT, "UI", "nxn_tr / nxn_tr_format (lang/*.json)", 'W')              \
    X(F_THREAD, "Threads", "nxn_thread_start / join", 'B')                      \
    X(F_PTHREAD, "Threads", "pthread mutex + condvar", 'B')                     \
    X(F_CLOCK, "Threads", "clock_gettime vs nxn_time_ns", 'B')                  \
    X(F_SLEEP, "Threads", "nxn_sleep_ns accuracy", 'B')                         \
    X(F_TIMESPEC, "Threads", "timespec_get (compat)", 'B')                      \
    X(F_CORO, "Threads", "nxc_coro / ucontext (compat)", 'B')                   \
    X(F_PIPE, "Compat", "pipe", 'B')                                            \
    X(F_POLL, "Compat", "poll", 'B')                                            \
    X(F_EVENTFD, "Compat", "eventfd", 'B')                                      \
    X(F_SELECT, "Compat", "select", 'B')                                        \
    X(F_MMAP, "Compat", "mmap / munmap", 'B')                                   \
    X(F_MPROTECT, "Compat", "mprotect", 'B')                                    \
    X(F_SIGNAL, "Compat", "signal + ualarm + raise", 'B')                       \
    X(F_FCNTL, "Compat", "fcntl", 'B')                                          \
    X(F_SOCKET, "Compat", "BSD sockets (permission network)", 'B')              \
    X(F_ENVCWD, "Compat", "own environment + working directory", 'B')           \
    X(F_ZSTD, "Libraries", "zstd round trip", 'B')                              \
    X(F_LZ4, "Libraries", "lz4 round trip", 'B')                                \
    X(F_SQLITE, "Libraries", "sqlite in-memory query", 'B')                     \
    X(F_NXVLIB, "Libraries", "nxn_lib_open greet.nxvlib", 'E')                  \
    X(F_DLOPEN, "Libraries", "dlopen / dlsym (compat)", 'E')                    \
    X(F_EH, "Runtime", "C++ throw / catch (nested, derived, rethrow)", 'B')     \
    X(F_TLS, "Runtime", "thread_local in a .nxvlib, 3 threads", 'B')            \
    X(F_TLS_LIB_EH, "Runtime", "exception thrown in a .nxvlib", 'B')                X(F_JIT, "Runtime", "nxn_jit: write code, run it from code memory", 'B')        X(F_FAULT, "Runtime", "fault handler + guard pages (console only)", 'W')   \
    X(F_MENU, "Runtime", "nxn_menu_set / clear (window menu, setting native.windowMenu)", 'W')                  X(F_RETURN, "Lifecycle", "nxn_request_return, code 42 (manual)", 'B')      \
    X(F_CRASH_WORKER, "Lifecycle", "crash in a worker thread (manual)", 'B')    \
    X(F_CRASH_MAIN, "Lifecycle", "crash on the main thread (manual)", 'B')      \
    X(F_HANG, "Lifecycle", "hang 10 s, not-responding dialog (manual)", 'B')

enum FeatId {
#define X(id, g, n, m) id,
    SC_FEATURES(X)
#undef X
    F_COUNT
};

struct Feature {
    const char* group;
    const char* name;
    char modes;
    Res res;
    char note[160];
};
extern Feature g_feat[F_COUNT];
extern int g_windowed; /* 1 when running in a Nexvyn OS window */
extern int g_feat_dirty;

void feat_set(int id, Res r, const char* fmt, ...) __attribute__((format(printf, 3, 4)));
void nexgfx_selftest(void); /* nexgfx_test.cpp (windowed builds only) */
const char* res_text(Res r);

/* A page of result lines. */
struct Lines {
    char text[40][200];
    Res res[40];
    int n;
    void clear() { n = 0; }
    void add(Res r, const char* fmt, ...) __attribute__((format(printf, 3, 4)));
};
enum { L_CORE, L_FILES, L_SYSTEM, L_UI, L_THREADS, L_COMPAT, L_LIBS, L_COUNT };
extern Lines g_lines[L_COUNT];

void tests_init(int windowed); /* feature table, mode rules */
void test_core(void);
void test_files(void);
void test_system(void);
void test_services(void); /* permissions, notification, clipboard, rumble (adds to the System page) */
void test_saves(void);    /* dialogs' arguments, kept folder access, the user's saves and their backups (Files page) */
void test_ui(void); /* nxn_ui.h: tokens, fonts, icons, texts */
extern nxn_ui_tokens g_tok; /* the OS look now (main.cpp keeps it fresh) */
void test_threads(void);
void test_compat(void);
void test_libs(void);
void test_runtime(void); /* tests_rt.cpp: thread_local, C++ exceptions, rtlib.nxvlib (W2a) */
void action_throw_uncaught(void); /* tests_rt.cpp: ends the app through std::terminate */
void tests_run_all(void); /* everything above (the GL / audio / input parts live in main.cpp) */
int report_write(const char* header);
void stage(const char* name); /* writes <data>/showcase_stage.txt: what the app is doing now (finds hangs) */

/* manual crash / hang actions (Lifecycle page) */
void action_crash_worker(void);
void action_crash_worker_abort(void);
void action_crash_main(void);
void action_crash_abort(void);
void action_hang(int seconds);
void action_quit42(void);

#endif
