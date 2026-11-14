/* Nexvyn compat layer - shared internals (not installed). */
#ifndef NXC_INTERNAL_H
#define NXC_INTERNAL_H

#include <errno.h>
#include <stdarg.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <switch.h>
#include <time.h>

#include "nexvyn/nxc_clockids.h"

/* 1 in a windowed app (.nxvmod): see the end of this file. */
#ifndef NXC_WINDOWED
#define NXC_WINDOWED 0
#endif

#define NXC_PAGE 4096u
#define NXC_FAIL(e) (errno = (e), -1)

/* One lock and one condition variable guard every virtual fd, the signal state and the timer. Nothing allocates or calls
 * the OS while holding it except the condition wait, so it cannot take part in a lock cycle with SDL, GL or malloc. */
extern Mutex g_nxc_mu;
extern CondVar g_nxc_cv;

/* Logs one line (nxn_log when the Nexvyn ABI is linked, else stderr). Never allocates more than a small buffer. */
void nxc_log(const char* fmt, ...) __attribute__((format(printf, 1, 2)));
/* Logs "<what>: <hint>" once per name (first 64 names), for calls that cannot work on this platform. */
void nxc_unsupported(const char* what, const char* hint);

uint64_t nxc_now_ns(void); /* monotonic */
void nxc_wake_all(void);   /* wakes every blocked compat call (state changed or signal pending) */

/* Result of nxc_block_locked(). */
enum { NXC_WAIT_OK = 0, NXC_WAIT_TIMEOUT = 1, NXC_WAIT_INTR = 2 };
/* Called with g_nxc_mu held. Waits once on the condition variable until woken, or deadline_ns (absolute nxc_now_ns
 * value, 0 = none) passes, or at most slice_ns (0 = until deadline / forever). Pending signals are delivered first (the
 * lock is released around the handlers). NXC_WAIT_INTR when a handler ran, unless restartable is set (read / write
 * style calls) and every handler that ran is marked SA_RESTART; sleep / poll / select pass 0: they never restart. */
int nxc_block_locked(uint64_t deadline_ns, uint64_t slice_ns, int restartable);

/* Signals (nxc_signal.c). deliver: runs the handlers of pending unblocked signals, *no_restart gets 1 when one of them
 * lacks SA_RESTART. Returns the number of handlers run. Call without g_nxc_mu. */
int nxc_signal_deliver(int* no_restart);
int nxc_signal_any_pending(void);
/* Wakes the signal timer thread bookkeeping (nxc_signal.c) when the program exits. */

/* Paths (nxc_path.c, pure). */
int nxc_path_normalize(const char* in, char* out, size_t cap);

/* Paths (nxc_fsmap.c): the configured translation, applied to one path (buf holds NXC_PATH_MAX); NULL + errno on failure. */
const char* nxc__map_path(const char* in, char* buf);

/* Pseudo devices (nxc_fd.c): /dev/null, /dev/zero, /dev/random, /dev/urandom and the /dev folder. match: 0 = not ours.
 * The others are only called for a path that matched; they return like open / fopen / stat / access. */
struct stat;
int nxc__dev_match(const char* path);
int nxc__dev_open(const char* path, int flags);
FILE* nxc__dev_fopen(const char* path, const char* mode);
int nxc__dev_stat(const char* path, struct stat* st);
int nxc__dev_access(const char* path, int mode);

/* Virtual fds (nxc_fd.c): true when fd belongs to us. */
int nxc_fd_is_virtual(int fd);


#if NXC_WINDOWED
/* In a window (the module is linked -fPIC, win/nxc_win.c; docs/NATIVE_COMPAT.md "In a window"): all state of the layer
 * lives in the app's module, so it belongs to one app, and it is released when the app ends (nxc_shutdown runs from
 * atexit). */
void nxc__win_register_exit(void); /* once: atexit(nxc_shutdown); called when something needs cleaning up later */
void nxc__mman_releaseall(void);
void nxc__fd_releaseall(void);     /* closes the virtual descriptors and removes the devoptab entry */
void nxc__env_releaseall(void);
/* thread_local is not available in a module (the loader refuses PT_TLS, and soft thread-pointer code would address the
 * wrong block): per-thread values live in a libnx TLS slot, allocated on first use and released at app end. */
typedef struct nxc_tlskey {
    int ready;
    int slot;
    void (*dtor)(void*); /* runs for the value of a thread when it ends */
} nxc_tlskey;
void* nxc__tls_get(nxc_tlskey* k);
void nxc__tls_set(nxc_tlskey* k, void* value);
void nxc__tls_releaseall(void);
void nxc__sock_track(int fd);
void nxc__sock_forget(int fd);
void nxc__sock_releaseall(void);
const char* nxc__vcwd(void);       /* the app's own working directory (a window cannot chdir the process) */
#endif

#endif
