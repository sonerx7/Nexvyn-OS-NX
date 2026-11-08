/* Nexvyn Native SDK library - teardown before the process goes back to the homebrew loader.
 *
 * A native app runs in Nexvyn OS's process: the loader starts Nexvyn OS next in the same process, with the same heap.
 * What the app leaves open stays alive there. A thread that was never closed keeps its stack pages locked (libnx maps
 * the stack with svcMapMemory; the heap source becomes Perm_None + IsBorrowed), and so does transfer memory a service
 * still holds: SDL's audio device runs an audio renderer whose work buffer is transfer memory (Perm_None), and libnx's
 * audrenExit frees that buffer right after closing the session without waiting for the service to let go of it
 * (nvExit waits: tmemWaitForPermission). Nexvyn OS's malloc then hands those pages out and its first write faults.
 *
 * nxn__teardown() is the one place that closes what an app may have left open, on every exit path:
 *   NXN__TD_NORMAL   nxn_shutdown (return from the entry, nxn_run, exit(), atexit): on the calling thread. The nxn
 *                    display, SDL audio (every device, also ones the app opened itself), the rest of SDL, an EGL
 *                    context still current; then it waits (bounded) until no heap page is locked any more.
 *   NXN__TD_BOUNDED  main-thread crash (nxn_crash.c), abort() and _exit() (userAppExit): the crashed code may hold any
 *                    lock, so the work runs on a helper thread prepared at nxn_init and the caller waits at most
 *                    NXN__TD_BOUNDED_MS. Only SDL audio is closed there (the GPU state is left: it belongs to the
 *                    crashed thread's context, and the console showed the desktop coming back with it left open);
 *                    then the app's other nxn threads are paused, so none runs the app's code after the loader
 *                    unmapped it.
 * A crashed worker thread ends through libnx's threadExit (nxn_crash.c), so the app's join can unmap its stack.
 * Each step runs at most once; the app's log gets the heap before ("teardown (end|crash or abort): the heap has ...")
 * and after ("teardown: <steps>; heap clean ..." or the blocks still locked). Nexvyn OS's heap guard
 * (source/core/heapguard.h) keeps whatever is left out of its malloc. */
#include "nxn_internal.h"
#include "nxmem.h"
#include <SDL2/SDL.h>
#include <EGL/egl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* SDL, EGL and the nxn display are optional for an app: weak references never pull them in. */
#pragma weak SDL_WasInit
#pragma weak SDL_QuitSubSystem
#pragma weak SDL_Quit
#pragma weak eglGetCurrentContext
#pragma weak eglGetCurrentDisplay
#pragma weak eglMakeCurrent
#pragma weak eglTerminate
#pragma weak eglReleaseThread
#pragma weak nxn__display_teardown
#pragma weak nxn__libs_ranges
#pragma weak nxn__libs_release

extern char* fake_heap_start;
extern char* fake_heap_end;

#define NXN__REAPER_STACK 0x10000
#define NXN__TD_NORMAL_MS 1500   /* the wait for locked heap pages after a normal end */
#define NXN__TD_SETTLE_MS 600    /* the same wait on the helper thread (crash, abort) */
#define NXN__TD_BOUNDED_MS 2500  /* the most a crashed thread waits for the helper thread */
#define NXN__LIB_PAIRS 32        /* library JIT ranges the heap check leaves to userAppExit */

static volatile int g_state;     /* 0 not run, 1 running, 2 done */
static int g_mode = -1;          /* the teardown that ran: NXN__TD_NORMAL or NXN__TD_BOUNDED */
volatile Handle nxn__exiting;    /* the thread leaving through a bounded teardown (nxn_internal.h) */
static Thread g_reaper;
static void* g_reaper_stack;
static int g_reaper_ready;
static volatile int g_reaper_done;
static char g_steps[160];

static void step(const char* s) {
    size_t n = strlen(g_steps);
    snprintf(g_steps + n, sizeof g_steps - n, "%s%s", n ? ", " : "", s);
}

/* Closes every SDL audio device (the renderer session, its thread and its transfer memory). */
static void sdl_audio_quit(void) {
    if (!SDL_WasInit || !SDL_QuitSubSystem || !SDL_WasInit(SDL_INIT_AUDIO)) return;
    for (int i = 0; i < 16 && SDL_WasInit(SDL_INIT_AUDIO); i++) SDL_QuitSubSystem(SDL_INIT_AUDIO); /* init count */
    step(SDL_WasInit(SDL_INIT_AUDIO) ? "SDL audio (still open)" : "SDL audio");
}

static nxmem_report g_report; /* static: the helper thread's stack is small; one teardown at a time */

/* What the app leaves locked before the teardown starts (the helper's own stack is not counted). */
static void audit_before(const char* how) {
    uint64_t lo = (uint64_t)(uintptr_t)fake_heap_start, hi = (uint64_t)(uintptr_t)fake_heap_end;
    if (!lo || hi <= lo) return;
    uint64_t skip[2] = {0, 0};
    if (g_reaper_ready) {
        skip[0] = (uint64_t)(uintptr_t)g_reaper_stack;
        skip[1] = skip[0] + NXN__REAPER_STACK;
    }
    nxmem_scan(nxmem_query_svc, NULL, lo, hi, skip, 1, &g_report);
    char d[420];
    nxmem_describe(&g_report, d, sizeof d);
    nxn_log(NXN_LOG_INFO, "teardown (%s): the heap has %s", how, d);
    if (nxn__leftover_faults)
        nxn_log(NXN_LOG_WARN, "teardown: %u fault(s) of threads the program before left running (they were ended, the "
                "app was not affected)", nxn__leftover_faults);
}

/* Waits until no page of the heap is locked (or ms ran out) and logs what is left. */
static void settle(int ms, const uint64_t* skip, int n_skip) {
    uint64_t lo = (uint64_t)(uintptr_t)fake_heap_start, hi = (uint64_t)(uintptr_t)fake_heap_end;
    if (!lo || hi <= lo) return;
    nxmem_report* r = &g_report;
    uint64_t t0 = armTicksToNs(armGetSystemTick()), waited = 0;
    for (;;) {
        nxmem_scan(nxmem_query_svc, NULL, lo, hi, skip, n_skip, r);
        waited = (armTicksToNs(armGetSystemTick()) - t0) / 1000000ull;
        if (!r->dirty_count || waited >= (uint64_t)ms) break;
        svcSleepThread(10000000ll);
    }
    if (!r->dirty_count) {
        nxn_log(NXN_LOG_INFO, "teardown: %s; heap clean after %llu ms", g_steps[0] ? g_steps : "nothing open",
                (unsigned long long)waited);
    } else {
        char d[420];
        nxmem_describe(r, d, sizeof d);
        nxn_log(NXN_LOG_WARN, "teardown: %s; after %llu ms the heap still has %s", g_steps[0] ? g_steps : "nothing open",
                (unsigned long long)waited, d);
    }
}

static void reaper_main(void* arg) {
    (void)arg;
    sdl_audio_quit();
    /* the whole block given to threadCreate is mapped (stack + reent + TLS; Thread.stack_sz is the stack part); the
     * libraries' pages are unmapped later (userAppExit) */
    static uint64_t skip[2 * (NXN__LIB_PAIRS + 1)];
    skip[0] = (uint64_t)(uintptr_t)g_reaper_stack;
    skip[1] = skip[0] + NXN__REAPER_STACK;
    int n_skip = 1 + (nxn__libs_ranges ? nxn__libs_ranges(skip + 2, NXN__LIB_PAIRS) : 0);
    settle(NXN__TD_SETTLE_MS, skip, n_skip);
    g_reaper_done = 1;
}

void nxn__teardown_prepare(void) {
    if (g_reaper_ready) return;
    g_reaper_stack = aligned_alloc(0x1000, NXN__REAPER_STACK);
    if (!g_reaper_stack) return;
    /* created now, started only by a bounded teardown: nothing is allocated after a crash */
    if (R_FAILED(threadCreate(&g_reaper, reaper_main, NULL, g_reaper_stack, NXN__REAPER_STACK, 0x2C, -2))) {
        free(g_reaper_stack);
        g_reaper_stack = NULL;
        return;
    }
    g_reaper_ready = 1;
}

/* A never-started helper is closed before the heap check (its stack is mapped like any thread's). */
static void reaper_release(void) {
    if (!g_reaper_ready) return;
    g_reaper_ready = 0;
    if (R_FAILED(threadClose(&g_reaper))) return; /* still mapped: never handed back to malloc */
    free(g_reaper_stack);
    g_reaper_stack = NULL;
}

static void teardown_normal(void) {
    if (nxn__display_teardown && nxn__display_teardown()) step("display");
    sdl_audio_quit();
    if (SDL_WasInit && SDL_Quit && SDL_WasInit(0)) {
        SDL_Quit();
        step("SDL");
    }
    /* an EGL context the app made itself (no nxn display, no SDL window) */
    if (eglGetCurrentContext && eglGetCurrentDisplay && eglMakeCurrent && eglTerminate &&
        eglGetCurrentContext() != EGL_NO_CONTEXT) {
        EGLDisplay dpy = eglGetCurrentDisplay();
        eglMakeCurrent(dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
        eglTerminate(dpy);
        if (eglReleaseThread) eglReleaseThread();
        step("EGL");
    }
    reaper_release();
    /* shared libraries stay mapped until userAppExit (atexit handlers and destructors may still call into them): the
     * wait does not count their pages */
    uint64_t skip[2 * NXN__LIB_PAIRS];
    int n_skip = nxn__libs_ranges ? nxn__libs_ranges(skip, NXN__LIB_PAIRS) : 0;
    if (n_skip) step("library code (unmapped at the very end)");
    settle(NXN__TD_NORMAL_MS, skip, n_skip);
}

/* Closes SDL audio on the helper thread and waits for it at most NXN__TD_BOUNDED_MS. */
static void bounded_audio(void) {
    if (!g_reaper_ready) {
        nxn_log(NXN_LOG_WARN, "teardown: no helper thread, audio left open");
        return;
    }
    if (R_FAILED(threadStart(&g_reaper))) {
        nxn_log(NXN_LOG_WARN, "teardown: the helper thread did not start, audio left open");
        return;
    }
    Result rc = waitSingleHandle(g_reaper.handle, (u64)NXN__TD_BOUNDED_MS * 1000000ull);
    if (R_SUCCEEDED(rc)) {
        /* the stack memory stays allocated: no free() after a crash, only the mapping goes */
        svcUnmapMemory(g_reaper.stack_mirror, g_reaper_stack, NXN__REAPER_STACK);
        svcCloseHandle(g_reaper.handle);
        g_reaper_ready = 0;
        if (!g_reaper_done) nxn_log(NXN_LOG_WARN, "teardown: the helper thread failed (%s)", g_steps);
    } else {
        /* a lock the crashed code holds: the helper is paused where it waits (it must not run once the code is
         * gone) and the process returns anyway */
        svcSetThreadActivity(g_reaper.handle, ThreadActivity_Paused);
        nxn_log(NXN_LOG_WARN, "teardown: gave up after %d ms (%s)", NXN__TD_BOUNDED_MS,
                g_steps[0] ? g_steps : "SDL audio did not close");
    }
}

static void teardown_bounded(void) {
    if (!nxn__exiting) nxn__exiting = threadGetCurHandle();
    bounded_audio();
    /* threads of the app that still run would go on running its code after the loader unmaps it (a fault Nexvyn OS
     * would get): they stop here. Their stacks stay locked; Nexvyn OS's heap guard keeps those pages out of malloc. */
    int paused = nxn__threads_pause_others(threadGetCurHandle());
    if (paused) nxn_log(NXN_LOG_INFO, "teardown: %d app thread(s) paused", paused);
}

void nxn__teardown(int mode) {
    if (!__sync_bool_compare_and_swap(&g_state, 0, 1)) return;
    g_mode = mode;
    audit_before(mode == NXN__TD_NORMAL ? "end" : "crash or abort");
    if (mode == NXN__TD_NORMAL) teardown_normal();
    else teardown_bounded();
    g_state = 2;
}

/* Shared libraries go last: exit() has run every atexit handler and destructor by now (userAppExit is the first step
 * of libnx's __appExit), so no library code runs any more. Their JIT memory keeps its source pages locked in the heap
 * while it is mapped; the console showed those pages where the loader reads Nexvyn OS's image (greetlib, 2026-11-04). */
static void release_libraries(void) {
    if (!nxn__libs_release) return;
    int normal = g_mode == NXN__TD_NORMAL;
    int n = nxn__libs_release(normal);
    if (!n) return;
    /* what the next program gets now (the bounded teardown's helper may still be listed: its stack is skipped) */
    char d[420] = "";
    uint64_t lo = (uint64_t)(uintptr_t)fake_heap_start, hi = (uint64_t)(uintptr_t)fake_heap_end;
    if (lo && hi > lo) {
        uint64_t skip[2] = {0, 0};
        if (g_reaper_ready) {
            skip[0] = (uint64_t)(uintptr_t)g_reaper_stack;
            skip[1] = skip[0] + NXN__REAPER_STACK;
        }
        nxmem_scan(nxmem_query_svc, NULL, lo, hi, skip, 1, &g_report);
        if (g_report.dirty_count) nxmem_describe(&g_report, d, sizeof d);
    }
    const char* what = n == 1 ? "y" : "ies";
    if (g_nxn.inited) {
        nxn_log(NXN_LOG_INFO, "teardown: %d shared librar%s unmapped; %s%s", n, what, d[0] ? "the heap has " : "heap clean",
                d);
    } else if (normal) { /* nxn_shutdown closed the log already: one more line */
        nxn__log_open();
        nxn_log(NXN_LOG_INFO, "teardown: %d shared librar%s unmapped at the very end; %s%s", n, what,
                d[0] ? "the heap has " : "heap clean", d);
        nxn__log_close();
    }
}

/* abort(), _exit() and every other way out pass libnx's __appExit, which calls userAppExit first. After a normal end
 * the teardown already ran; otherwise the bounded one runs here. Weak: an app's own userAppExit wins (it then
 * calls nxn_shutdown itself). */
__attribute__((weak)) void userAppExit(void) {
    if (g_nxn.inited) nxn__teardown(NXN__TD_BOUNDED);
    release_libraries();
}
