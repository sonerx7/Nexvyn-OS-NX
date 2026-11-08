/* Nexvyn Native SDK library - shared state of the exclusive-mode implementation (not installed with the headers). */
#ifndef NEXVYN_NXN_INTERNAL_H
#define NEXVYN_NXN_INTERNAL_H

#include <switch.h>
#include "nexvyn/nexvyn_native.h"
#include "nxn_handoff.h"

typedef struct nxn__state {
    int inited;
    uint32_t flags;
    int hosted;        /* hand-off read */
    int returns;       /* the loader starts Nexvyn OS when the app ends */
    int crash_guard;   /* our exception handler is active */
    nxn__handoff h;
    char app_id[128];
    char data[NXN__PATH], cache[NXN__PATH], bundle[NXN__PATH], log[NXN__PATH], ret[NXN__PATH];
    nxn__return_rec rec;
    volatile int quit;
    uint64_t base;     /* load address of the .nro (crash offsets) */
    Handle main_thread;
    Mutex lock;        /* return record + log file */
} nxn__state;

extern nxn__state g_nxn;

/* Optional compat layer (libnexvyn_compat). Weak references: an app that does not link it sees NULL and behaves as
 * before; a weak undefined symbol never pulls the archive member in. Signatures match nexvyn/compat.h. */
extern int nxc_init(void) __attribute__((weak));
extern int nxc_signal_poll(void) __attribute__((weak));
extern void nxc_shutdown(void) __attribute__((weak));
extern int nxc_sleep_interruptible(uint64_t ns) __attribute__((weak));


void nxn__set_error(const char* fmt, ...);
/* Writes g_nxn.rec to the return file (hosted only). Safe from the crash handler (no allocation besides stdio). */
void nxn__write_return(void);
void nxn__log_open(void);
void nxn__log_close(void);
/* Name of an nxn thread by its handle ("" if not one of ours). */
const char* nxn__thread_name(Handle h);
void nxn__crash_install(void);
int nxn__mkdirs(const char* path);
/* System event queue (nxn_event.c): hooked in nxn_init, released in nxn_shutdown. */
void nxn__events_start(void);
void nxn__events_stop(void);
/* The output size of the current mode: 1920x1080 docked, 1280x720 handheld. */
void nxn__output_size(uint32_t* w, uint32_t* h, uint32_t* docked);

/* Teardown before the process returns to the loader (nxn_teardown.c). Runs once; later calls return at once. */
enum { NXN__TD_NORMAL = 0, NXN__TD_BOUNDED = 1 };
void nxn__teardown(int mode);
/* Prepares the helper thread of the bounded teardown (nxn_init). */
void nxn__teardown_prepare(void);
/* The thread that leaves through a bounded teardown (0: none). While set, a fault in that thread exits at once and a
 * fault in any other thread ends only that thread (nxn_crash.c). */
extern volatile Handle nxn__exiting;
/* Pauses every running nxn thread except self (nxn_sys.c): after a crash nothing may run the app's code once the
 * loader has unmapped it. Returns how many were paused. */
int nxn__threads_pause_others(Handle self);
/* Closes the nxn display if the app left it open (nxn_display.c). 1 when it closed one. */
int nxn__display_teardown(void);
/* The heap guard of the app's start (nxn_heap.c): one log line at nxn_init. */
void nxn__heap_log(void);
/* Faults of threads the program before left running, ended by the crash handler (nxn_crash.c). */
extern volatile unsigned nxn__leftover_faults;
/* Shared libraries (nxn_lib.c; weak references in nxn_teardown.c: an app without libraries does not link the loader).
 * The heap ranges their JIT memory locks, as [lo, hi) pairs: */
int nxn__libs_ranges(uint64_t* pairs, int max_pairs);
/* Unmaps every library's JIT code memory at the very end (userAppExit: no library code runs after it). may_free: give
 * the pages back to malloc (not after a crash: the crashed thread may hold malloc's lock). Returns how many. */
int nxn__libs_release(int may_free);

#endif /* NEXVYN_NXN_INTERNAL_H */
