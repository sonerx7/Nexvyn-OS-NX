/* Nexvyn compat layer - the parts that only exist in a window (windowed app, .nxvmod; docs/NATIVE_COMPAT.en.md "In a
 * window"). Built only into libnexvyn_compat_pic.a (-DNXC_WINDOWED=1).
 *
 * The layer is linked into the app's module, so every table of it (descriptors, mappings, signals, timer thread, the
 * environment, the working directory) belongs to that one app and goes away with it. What this file adds:
 *  - the exit hook: nxc_shutdown() and the releases of the other units run from atexit, on the app's thread, while the
 *    module is still mapped (a window's heap is not reclaimed by Nexvyn OS);
 *  - the runtime hooks of exclusive mode (nxn_init, nxn_event_poll, nxn_should_quit, nxn_sleep_ns, nxn_shutdown, nxn_run),
 *    done with --wrap on the nxn_* imports: Nexvyn OS implements nxn_* for windows and cannot call into the module;
 *  - the app's own environment table and `environ` (setenv in a window must not change Nexvyn OS's environment);
 *  - tracking of the sockets the app opens, closed when it ends. */
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/iosupport.h>
#include <sys/socket.h>
#include <unistd.h>

#include "nexvyn/compat.h"
#include "nexvyn/nxn_app.h"
#include "nexvyn/nxn_event.h"
#include "nxc_internal.h"

#if !NXC_WINDOWED
#error "nxc_win.c is part of the windowed build only"
#endif

/* ---- exit hook ---- */

static void win_exit(void) {
    nxc_shutdown();
    nxc__tls_releaseall();
    nxc__sock_releaseall();
    nxc__fd_releaseall();
    nxc__mman_releaseall();
    nxc__env_releaseall();
}

void nxc__win_register_exit(void) {
    static int done;
    if (__atomic_exchange_n(&done, 1, __ATOMIC_ACQ_REL)) return;
    if (atexit(win_exit) != 0) __atomic_store_n(&done, 0, __ATOMIC_RELEASE); /* try again at the next use */
}

/* ---- runtime hooks (--wrap of wrap_win.txt) ---- */

nxn_result __real_nxn_init(const nxn_init_params* params);
void __real_nxn_shutdown(void);
int __real_nxn_event_poll(nxn_event* out);
int __real_nxn_should_quit(void);
void __real_nxn_sleep_ns(uint64_t ns);
int __real_nxn_run(int argc, char** argv, nxn_entry_fn entry, const nxn_init_params* params);

nxn_result __wrap_nxn_init(const nxn_init_params* params) {
    nxn_result rc = __real_nxn_init(params);
    if (rc == NXN_OK) nxc_init(); /* sandbox paths are known now */
    return rc;
}

void __wrap_nxn_shutdown(void) {
    nxc_shutdown();
    __real_nxn_shutdown();
}

int __wrap_nxn_event_poll(nxn_event* out) {
    nxc_signal_poll(); /* emulated signals are delivered once per frame */
    return __real_nxn_event_poll(out);
}

int __wrap_nxn_should_quit(void) {
    nxc_signal_poll();
    return __real_nxn_should_quit();
}

void __wrap_nxn_sleep_ns(uint64_t ns) {
    /* emulated signals are delivered while sleeping; the sleep itself still lasts the full time */
    uint64_t end = nxc_now_ns() + ns;
    for (;;) {
        if (nxc_sleep_interruptible(ns) == 0) return;
        uint64_t now = nxc_now_ns();
        if (now >= end) return;
        ns = end - now;
    }
}

/* nxn_run starts Nexvyn OS's own nxn_init, which cannot reach the wrap above: the layer starts inside the entry. */
static nxn_entry_fn g_entry;
static int run_entry(int argc, char** argv) {
    nxc_init();
    int rc = g_entry(argc, argv);
    nxc_shutdown();
    return rc;
}

int __wrap_nxn_run(int argc, char** argv, nxn_entry_fn entry, const nxn_init_params* params) {
    g_entry = entry;
    return __real_nxn_run(argc, argv, entry ? run_entry : entry, params);
}

/* ---- per-thread values (no thread_local in a module) ---- */

static nxc_tlskey* g_keys[8];
static int g_key_n;

void* nxc__tls_get(nxc_tlskey* k) {
    if (!__atomic_load_n(&k->ready, __ATOMIC_ACQUIRE)) return NULL;
    return threadTlsGet(k->slot);
}

void nxc__tls_set(nxc_tlskey* k, void* value) {
    if (!__atomic_load_n(&k->ready, __ATOMIC_ACQUIRE)) {
        mutexLock(&g_nxc_mu);
        if (!k->ready && g_key_n < 8) {
            s32 slot = threadTlsAlloc(k->dtor);
            if (slot >= 0) {
                k->slot = slot;
                g_keys[g_key_n++] = k;
                __atomic_store_n(&k->ready, 1, __ATOMIC_RELEASE);
            }
        }
        mutexUnlock(&g_nxc_mu);
        if (!k->ready) return; /* no slot left: the caller's fallback is used */
        nxc__win_register_exit();
    }
    threadTlsSet(k->slot, value);
}

/* App end: the calling thread's value is freed here, the slots go back (other threads freed theirs when they ended). */
void nxc__tls_releaseall(void) {
    mutexLock(&g_nxc_mu);
    int n = g_key_n;
    g_key_n = 0;
    mutexUnlock(&g_nxc_mu);
    for (int i = 0; i < n; i++) {
        nxc_tlskey* k = g_keys[i];
        void* v = threadTlsGet(k->slot);
        if (v && k->dtor) k->dtor(v);
        threadTlsSet(k->slot, NULL);
        __atomic_store_n(&k->ready, 0, __ATOMIC_RELEASE);
        threadTlsFree(k->slot);
    }
}

/* ---- environment ---- */

char** environ;
static char** g_env; /* "NAME=value" strings, malloc'ed */
static size_t g_env_n, g_env_cap;
static Mutex g_env_mu;

/* index of name, or -1. Lock held. */
static long env_find(const char* name, size_t len) {
    for (size_t i = 0; i < g_env_n; i++)
        if (!strncmp(g_env[i], name, len) && g_env[i][len] == '=') return (long)i;
    return -1;
}

static int env_grow_locked(void) {
    if (g_env_n + 2 <= g_env_cap) return 0;
    size_t cap = g_env_cap ? g_env_cap * 2 : 16;
    char** n = (char**)realloc(g_env, cap * sizeof *n);
    if (!n) return -1;
    g_env = n;
    g_env_cap = cap;
    environ = g_env;
    return 0;
}

/* name is the first nl bytes of its string (putenv hands "NAME=value" without cutting it); nothing of the caller's
 * strings is written or kept. */
static int env_set_n(const char* name, size_t nl, const char* value, int overwrite) {
    size_t vl = strlen(value);
    nxc__win_register_exit();
    char* e = (char*)malloc(nl + vl + 2);
    if (!e) return NXC_FAIL(ENOMEM);
    memcpy(e, name, nl);
    e[nl] = '=';
    memcpy(e + nl + 1, value, vl + 1);
    mutexLock(&g_env_mu);
    long at = env_find(name, nl);
    if (at >= 0) {
        if (overwrite) {
            free(g_env[at]);
            g_env[at] = e;
        } else {
            free(e);
        }
        mutexUnlock(&g_env_mu);
        return 0;
    }
    if (env_grow_locked() != 0) {
        mutexUnlock(&g_env_mu);
        free(e);
        return NXC_FAIL(ENOMEM);
    }
    g_env[g_env_n++] = e;
    g_env[g_env_n] = NULL;
    environ = g_env;
    mutexUnlock(&g_env_mu);
    return 0;
}

int nxc__env_set(const char* name, const char* value, int overwrite) {
    return env_set_n(name, strlen(name), value, overwrite);
}

int nxc__env_unset(const char* name) {
    mutexLock(&g_env_mu);
    long at = env_find(name, strlen(name));
    if (at >= 0) {
        free(g_env[at]);
        memmove(&g_env[at], &g_env[at + 1], (g_env_n - (size_t)at) * sizeof *g_env); /* includes the NULL */
        g_env_n--;
    }
    mutexUnlock(&g_env_mu);
    return 0;
}

int nxc__env_clear(void) {
    mutexLock(&g_env_mu);
    for (size_t i = 0; i < g_env_n; i++) free(g_env[i]);
    g_env_n = 0;
    if (g_env) g_env[0] = NULL;
    mutexUnlock(&g_env_mu);
    return 0;
}

char* getenv(const char* name) {
    if (!name || !name[0] || strchr(name, '=')) return NULL;
    mutexLock(&g_env_mu);
    long at = env_find(name, strlen(name));
    char* v = at >= 0 ? strchr(g_env[at], '=') + 1 : NULL;
    mutexUnlock(&g_env_mu);
    return v;
}

char* secure_getenv(const char* name) { return getenv(name); }

int putenv(char* string) {
    if (!string) return NXC_FAIL(EINVAL);
    char* eq = strchr(string, '=');
    if (!eq) return nxc__env_unset(string); /* glibc: "NAME" removes it */
    if (eq == string) return NXC_FAIL(EINVAL);
    /* a copy: the caller's string is neither kept nor written (it is often a literal in read-only memory; cutting it at
     * '=' for a moment faulted on the console) */
    return env_set_n(string, (size_t)(eq - string), eq + 1, 1);
}

void nxc__env_releaseall(void) {
    nxc__env_clear();
    mutexLock(&g_env_mu);
    free(g_env);
    g_env = NULL;
    g_env_cap = 0;
    environ = NULL;
    mutexUnlock(&g_env_mu);
}

/* ---- sockets ----
 * Sockets are descriptors of the process-wide "soc:" device: the ones this app opens are noted so that a window that
 * ends does not leave them behind. */

#define NXC_SOCK_MAX 256
static int g_socks[NXC_SOCK_MAX];
static int g_sock_n;

int __real_socket(int domain, int type, int protocol);
int __real_accept(int fd, struct sockaddr* addr, socklen_t* len);

void nxc__sock_track(int fd) {
    if (fd < 0) return;
    nxc__win_register_exit();
    mutexLock(&g_nxc_mu);
    if (g_sock_n < NXC_SOCK_MAX) g_socks[g_sock_n++] = fd; /* more than 256: not tracked, the app closes them itself */
    mutexUnlock(&g_nxc_mu);
}

void nxc__sock_forget(int fd) {
    if (g_sock_n == 0) return;
    mutexLock(&g_nxc_mu);
    for (int i = 0; i < g_sock_n; i++)
        if (g_socks[i] == fd) {
            g_socks[i] = g_socks[--g_sock_n];
            break;
        }
    mutexUnlock(&g_nxc_mu);
}

int __wrap_socket(int domain, int type, int protocol) {
    int fd = __real_socket(domain, type, protocol);
    nxc__sock_track(fd);
    return fd;
}

int __wrap_accept(int fd, struct sockaddr* addr, socklen_t* len) {
    int c = __real_accept(fd, addr, len);
    nxc__sock_track(c);
    return c;
}

void nxc__sock_releaseall(void) {
    int soc = FindDevice("soc:");
    for (;;) {
        mutexLock(&g_nxc_mu);
        int fd = g_sock_n ? g_socks[--g_sock_n] : -1;
        mutexUnlock(&g_nxc_mu);
        if (fd < 0) break;
        __handle* h = __get_handle(fd);
        if (soc >= 0 && h && h->refcount && (int)h->device == soc) close(fd); /* still a socket of that device */
    }
}
