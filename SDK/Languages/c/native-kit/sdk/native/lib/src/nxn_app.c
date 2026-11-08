/* Nexvyn Native SDK library - lifecycle, hand-off, return record, capabilities and info (nxn_app.h). */
#include "nxn_internal.h"
#include "nxelf.h"
#include <errno.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>

nxn__state g_nxn;

extern int __system_argc;
extern char** __system_argv;

/* SDL is optional for an nxn app: these resolve to NULL when the app does not link SDL2. */
extern uint32_t SDL_WasInit(uint32_t flags) __attribute__((weak));
#define NXN_SDL_INIT_VIDEO 0x20u

static __thread char t_error[160];

void nxn__set_error(const char* fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(t_error, sizeof t_error, fmt, ap);
    va_end(ap);
}

const char* nxn_last_error(void) { return t_error; }

static void copy(char* dst, size_t cap, const char* src) {
    snprintf(dst, cap, "%s", src ? src : "");
}

int nxn__mkdirs(const char* path) {
    char tmp[NXN__PATH];
    copy(tmp, sizeof tmp, path);
    size_t n = strlen(tmp);
    while (n > 0 && tmp[n - 1] == '/') tmp[--n] = 0;
    char* start = strstr(tmp, ":/");
    for (char* p = start ? start + 2 : tmp + 1; *p; p++) {
        if (*p != '/') continue;
        *p = 0;
        mkdir(tmp, 0777);
        *p = '/';
    }
    return mkdir(tmp, 0777) == 0 || errno == EEXIST;
}

static void parent_of(const char* path, char* out, size_t cap) {
    copy(out, cap, path);
    char* s = strrchr(out, '/');
    if (s && s > out && s[-1] != ':') *s = 0;
    else if (s) s[1] = 0;
}

void nxn__write_return(void) {
    if (!g_nxn.hosted || !g_nxn.ret[0]) return;
    char text[1024];
    size_t n = nxn__return_format(&g_nxn.rec, text, sizeof text);
    if (!n) return;
    char tmp[NXN__PATH + 8];
    snprintf(tmp, sizeof tmp, "%s.tmp", g_nxn.ret);
    FILE* f = fopen(tmp, "wb");
    if (!f) return;
    int ok = fwrite(text, 1, n, f) == n;
    ok = fclose(f) == 0 && ok;
    if (ok) {
        remove(g_nxn.ret);
        rename(tmp, g_nxn.ret);
    }
}

static int read_text(const char* path, char* buf, size_t cap, size_t* len) {
    FILE* f = fopen(path, "rb");
    if (!f) return 0;
    *len = fread(buf, 1, cap - 1, f);
    buf[*len] = 0;
    fclose(f);
    return 1;
}

/* Standalone (Homebrew menu): the app's folder next to its .nro under sdmc:/switch/<id>/. */
static void standalone_paths(const nxn_init_params* p) {
    const char* argv0 = __system_argc > 0 && __system_argv ? __system_argv[0] : "";
    char stem[128] = "app";
    const char* base = strrchr(argv0, '/');
    copy(stem, sizeof stem, base ? base + 1 : argv0);
    char* dot = strrchr(stem, '.');
    if (dot) *dot = 0;
    if (!stem[0]) copy(stem, sizeof stem, "app");
    copy(g_nxn.app_id, sizeof g_nxn.app_id, p && p->standalone_id && p->standalone_id[0] ? p->standalone_id : stem);
    snprintf(g_nxn.data, sizeof g_nxn.data, "sdmc:/switch/%s/data", g_nxn.app_id);
    snprintf(g_nxn.cache, sizeof g_nxn.cache, "sdmc:/switch/%s/cache", g_nxn.app_id);
    snprintf(g_nxn.log, sizeof g_nxn.log, "%s/app.log", g_nxn.data);
    if (argv0[0]) {
        char full[NXN__PATH];
        if (strncmp(argv0, "sdmc:", 5) == 0) copy(full, sizeof full, argv0);
        else snprintf(full, sizeof full, "sdmc:%s", argv0);
        parent_of(full, g_nxn.bundle, sizeof g_nxn.bundle);
    } else {
        copy(g_nxn.bundle, sizeof g_nxn.bundle, g_nxn.data);
    }
    g_nxn.h.accent = 0x0A84FF;
    g_nxn.h.confirm = NXN_BTN_A;
    g_nxn.h.cancel = NXN_BTN_B;
    copy(g_nxn.h.theme, sizeof g_nxn.h.theme, "dark");
    copy(g_nxn.h.language, sizeof g_nxn.h.language, "en");
    if (R_SUCCEEDED(setInitialize())) {
        u64 code = 0;
        if (R_SUCCEEDED(setGetSystemLanguage(&code))) {
            char lang[9] = {0};
            memcpy(lang, &code, 8);
            char* dash = strchr(lang, '-');
            if (dash && strcmp(lang, "zh-Hans") != 0 && strcmp(lang, "zh-Hant") != 0) *dash = 0;
            if (strncmp(lang, "zh", 2) == 0) lang[2] = 0;
            if (lang[0]) copy(g_nxn.h.language, sizeof g_nxn.h.language, lang);
        }
        setExit();
    }
}

static void read_handoff(void) {
    const char* path = nxn__handoff_arg(__system_argc, __system_argv);
    if (!path) return;
    static char text[16384];
    size_t len = 0;
    if (!read_text(path, text, sizeof text, &len)) return;
    nxn__handoff h;
    memset(&h, 0, sizeof h);
    if (!nxn__handoff_parse(text, len, &h) || !h.app_id[0] || !h.data[0]) return;
    g_nxn.h = h;
    g_nxn.hosted = 1;
    copy(g_nxn.app_id, sizeof g_nxn.app_id, h.app_id);
    copy(g_nxn.data, sizeof g_nxn.data, h.data);
    copy(g_nxn.cache, sizeof g_nxn.cache, h.cache[0] ? h.cache : h.data);
    copy(g_nxn.bundle, sizeof g_nxn.bundle, h.bundle);
    copy(g_nxn.log, sizeof g_nxn.log, h.log);
    copy(g_nxn.ret, sizeof g_nxn.ret, h.ret);
    if (!g_nxn.log[0]) snprintf(g_nxn.log, sizeof g_nxn.log, "%s/app.log", g_nxn.data);
}

/* The loader starts Nexvyn OS next, whichever way this process ends (return, exit, abort, crash guard). */
static void arm_return(void) {
    if (!g_nxn.hosted || !g_nxn.h.host_nro[0] || (g_nxn.flags & NXN_INIT_NO_RETURN) || !envHasNextLoad()) return;
    const char* p = g_nxn.h.host_nro;
    const char* argv0 = strncmp(p, "sdmc:", 5) == 0 ? p + 5 : p;
    char argv[NXN__PATH + 64];
    snprintf(argv, sizeof argv, "\"%s\" --nxn-returned=%s", argv0, g_nxn.h.launch_id);
    g_nxn.returns = R_SUCCEEDED(envSetNextLoad(p, argv));
}

static void at_exit(void) { nxn_shutdown(); }

nxn_result nxn_init(const nxn_init_params* params) {
    if (g_nxn.inited) return NXN_OK;
    mutexInit(&g_nxn.lock);
    g_nxn.flags = params && params->size >= offsetof(nxn_init_params, flags) + sizeof(uint32_t) ? params->flags : 0;
    g_nxn.main_thread = envGetMainThreadHandle();
    MemoryInfo mi;
    u32 pi;
    if (R_SUCCEEDED(svcQueryMemory(&mi, &pi, (u64)(uintptr_t)&nxn_init))) g_nxn.base = mi.addr;
    read_handoff();
    if (!g_nxn.hosted) {
        const nxn_init_params* p = params && params->size >= offsetof(nxn_init_params, standalone_id) + sizeof(char*) ? params : NULL;
        standalone_paths(p);
    }
    nxn__mkdirs(g_nxn.data);
    nxn__mkdirs(g_nxn.cache);
    char dir[NXN__PATH];
    parent_of(g_nxn.log, dir, sizeof dir);
    nxn__mkdirs(dir);
    if (g_nxn.ret[0]) {
        parent_of(g_nxn.ret, dir, sizeof dir);
        nxn__mkdirs(dir);
    }
    memset(&g_nxn.rec, 0, sizeof g_nxn.rec);
    copy(g_nxn.rec.launch_id, sizeof g_nxn.rec.launch_id, g_nxn.h.launch_id);
    copy(g_nxn.rec.state, sizeof g_nxn.rec.state, "running");
    copy(g_nxn.rec.reason, sizeof g_nxn.rec.reason, "normal");
    g_nxn.rec.time = (int64_t)time(NULL);
    g_nxn.inited = 1;
    nxn__log_open();
    nxn__write_return();
    arm_return();
    if (nxc_init) nxc_init(); /* sandbox paths are known now: the compat layer moves the working directory there */
    nxn__events_start();
    nxn__teardown_prepare();
    if (!(g_nxn.flags & NXN_INIT_NO_CRASH_HANDLER)) nxn__crash_install();
    atexit(at_exit);
    nxn_log(NXN_LOG_INFO, "nxn %s: %s started (%s)", NXN_VERSION_STRING, g_nxn.app_id,
            g_nxn.hosted ? (g_nxn.returns ? "hosted, returns to Nexvyn OS" : "hosted") : "standalone");
    nxn__heap_log();
    return NXN_OK;
}

void nxn_shutdown(void) {
    if (!g_nxn.inited) return;
    nxn__events_stop();
    if (nxc_shutdown) nxc_shutdown();
    /* before the record: audio, display and SDL closed, the heap free of locked pages (nxn_teardown.c) */
    nxn__teardown(NXN__TD_NORMAL);
    mutexLock(&g_nxn.lock);
    if (strcmp(g_nxn.rec.state, "running") == 0) copy(g_nxn.rec.state, sizeof g_nxn.rec.state, "exited");
    g_nxn.rec.time = (int64_t)time(NULL);
    nxn__write_return();
    mutexUnlock(&g_nxn.lock);
    nxn_log(NXN_LOG_INFO, "nxn: %s ended (%s, code %d)", g_nxn.app_id, g_nxn.rec.state, (int)g_nxn.rec.code);
    nxn__log_close();
    g_nxn.inited = 0;
}

int nxn_run(int argc, char** argv, nxn_entry_fn entry, const nxn_init_params* params) {
    if (!entry) return -1;
    nxn_init(params);
    int rc = entry(argc, argv);
    mutexLock(&g_nxn.lock);
    if (strcmp(g_nxn.rec.reason, "normal") == 0 && !g_nxn.rec.code) g_nxn.rec.code = rc;
    mutexUnlock(&g_nxn.lock);
    nxn_shutdown();
    return rc;
}

int nxn_should_quit(void) {
    if (nxc_signal_poll) nxc_signal_poll(); /* emulated signals (alarm, setitimer) are delivered once per frame */
    if (g_nxn.quit) return 1;
    /* With an SDL window, SDL's event pump owns the applet messages (it turns the exit request into SDL_QUIT). */
    if (SDL_WasInit && (SDL_WasInit(NXN_SDL_INIT_VIDEO) & NXN_SDL_INIT_VIDEO)) return 0;
    if (!appletMainLoop()) {
        nxn_request_return(NXN_RETURN_USER, 0, NULL);
        return 1;
    }
    return 0;
}

void nxn_request_return(nxn_return_reason reason, int32_t code, const char* message) {
    static const char* const kReason[] = {"normal", "user", "error", "crash"};
    mutexLock(&g_nxn.lock);
    if (strcmp(g_nxn.rec.state, "crashed") != 0) {
        copy(g_nxn.rec.reason, sizeof g_nxn.rec.reason, kReason[(unsigned)reason < 4 ? (unsigned)reason : 0]);
        g_nxn.rec.code = code;
        copy(g_nxn.rec.message, sizeof g_nxn.rec.message, message);
    }
    mutexUnlock(&g_nxn.lock);
    g_nxn.quit = 1;
}

nxn_result nxn_caps_get(nxn_caps* out) {
    if (!out || out->size < sizeof(uint32_t)) return NXN_ERR_INVALID;
    nxn_caps c;
    memset(&c, 0, sizeof c);
    c.size = out->size;
    c.abi_gen = NXN_ABI_GEN;
    c.version_major = NXN_VERSION_MAJOR;
    c.version_minor = NXN_VERSION_MINOR;
    c.features = NXN_CAP_GL_CORE | NXN_CAP_GLES | NXN_CAP_AUDIO | NXN_CAP_TOUCH | NXN_CAP_KEYBOARD | NXN_CAP_EVENTS |
                 NXN_CAP_AUDIO_CLEAR;
    if (g_nxn.hosted) c.features |= NXN_CAP_HOSTED;
    if (g_nxn.returns) c.features |= NXN_CAP_RETURN;
    if (g_nxn.crash_guard) c.features |= NXN_CAP_CRASH_GUARD;
    AppletType t = appletGetAppletType();
    if (t != AppletType_Application && t != AppletType_SystemApplication) c.features |= NXN_CAP_APPLET_MODE;
    if (nxelf_jit_available()) c.features |= NXN_CAP_SHARED_LIBS | NXN_CAP_JIT;
    c.gl_max_major = 4;
    c.gl_max_minor = 3;
    c.gles_max_major = 3;
    c.gles_max_minor = 2;
    size_t n = out->size < sizeof c ? out->size : sizeof c;
    memcpy(out, &c, n);
    return NXN_OK;
}

nxn_result nxn_info_get(nxn_info* out) {
    if (!out || out->size < sizeof(uint32_t)) return NXN_ERR_INVALID;
    nxn_info i;
    memset(&i, 0, sizeof i);
    i.size = out->size;
    i.hosted = (uint32_t)g_nxn.hosted;
    i.theme_dark = strcmp(g_nxn.h.theme, "light") != 0;
    i.accent_rgb = g_nxn.h.accent ? g_nxn.h.accent : 0x0A84FF;
    i.confirm_buttons = g_nxn.h.confirm ? g_nxn.h.confirm : NXN_BTN_A;
    i.cancel_buttons = g_nxn.h.cancel ? g_nxn.h.cancel : NXN_BTN_B;
    size_t n = out->size < sizeof i ? out->size : sizeof i;
    memcpy(out, &i, n);
    return NXN_OK;
}

const char* nxn_info_string(nxn_info_key key) {
    switch (key) {
        case NXN_INFO_APP_ID: return g_nxn.app_id;
        case NXN_INFO_APP_VERSION: return g_nxn.h.app_version;
        case NXN_INFO_OS_VERSION: return g_nxn.h.os_version;
        case NXN_INFO_SDK_VERSION: return g_nxn.h.sdk_version;
        case NXN_INFO_NATIVE_VERSION: return g_nxn.h.native_version;
        case NXN_INFO_LANGUAGE: return g_nxn.h.language[0] ? g_nxn.h.language : "en";
        case NXN_INFO_USER_NAME: return g_nxn.h.user;
        case NXN_INFO_THEME: return strcmp(g_nxn.h.theme, "light") == 0 ? "light" : "dark";
        default: return "";
    }
}
