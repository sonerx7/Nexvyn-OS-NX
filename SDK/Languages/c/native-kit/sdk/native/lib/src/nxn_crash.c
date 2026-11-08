/* Nexvyn Native SDK library - crash guard.
 *
 * libnx copies the faulting thread's context, returns from the kernel exception (the kernel's exception slot is
 * free again) and then calls __libnx_exception_handler on __nx_exception_stack in normal user mode. From there:
 *   main thread  -> the crash is recorded, the thread moves to its own exit stack, the bounded teardown closes SDL
 *                   audio on a helper thread (nxn_teardown.c, at most a few seconds) and the process leaves through
 *                   _exit(), which returns to the homebrew loader; the loader starts Nexvyn OS (envSetNextLoad was
 *                   armed at nxn_init). A fault during that exit leaves at once; a fault in another thread then only
 *                   ends that thread.
 *   other thread -> the crash is recorded, nxn_should_quit() becomes true and only that thread ends
 *                   (a join on it returns), so the main loop can end normally (nxn_shutdown runs the full teardown).
 * Returning from the handler would end in svcBreak (a system crash report), so it never returns while the guard
 * is active. Both definitions are weak: an app with its own handler keeps it (NXN_INIT_NO_CRASH_HANDLER). */
#include "nxn_internal.h"
#include "nxmem.h"
#include <stdio.h>
#include <string.h>
#include <unistd.h>

__attribute__((weak, aligned(16))) u8 __nx_exception_stack[0x4000];
__attribute__((weak)) u64 __nx_exception_stack_size = sizeof(__nx_exception_stack);

static volatile int g_in_handler;

void nxn__crash_install(void) { g_nxn.crash_guard = 1; }

static const char* kind_of(u32 desc) {
    switch (desc) {
        case ThreadExceptionDesc_InstructionAbort: return "instruction abort";
        case ThreadExceptionDesc_MisalignedPC: return "misaligned PC";
        case ThreadExceptionDesc_MisalignedSP: return "misaligned SP";
        case ThreadExceptionDesc_SError: return "SError";
        case ThreadExceptionDesc_BadSVC: return "bad SVC";
        case ThreadExceptionDesc_Trap: return "trap / illegal instruction";
        case ThreadExceptionDesc_Other: return "data abort";
        default: return "CPU exception";
    }
}

static u64 offset(u64 addr) { return addr >= g_nxn.base ? addr - g_nxn.base : addr; }

/* No lock: the faulting thread may hold it. A later crash (another thread) keeps the first record. */
static void record(const ThreadExceptionDump* ctx, Handle self, int main_thread) {
    nxn__return_rec* r = &g_nxn.rec;
    if (strcmp(r->state, "crashed") == 0) return;
    snprintf(r->state, sizeof r->state, "crashed");
    snprintf(r->reason, sizeof r->reason, "crash");
    snprintf(r->crash_kind, sizeof r->crash_kind, "%s", kind_of(ctx->error_desc));
    const char* name = main_thread ? "main" : nxn__thread_name(self);
    snprintf(r->crash_thread, sizeof r->crash_thread, "%s", name[0] ? name : "worker");
    r->crash_pc = offset(ctx->pc.x);
    r->crash_lr = offset(ctx->lr.x);
    r->crash_far = ctx->far.x;
    r->code = NXN_EXIT_CRASHED;
    nxn__write_return();
    nxn_log(NXN_LOG_ERROR, "crash: %s in thread %s, pc +0x%llx, lr +0x%llx, address 0x%llx", r->crash_kind,
            r->crash_thread, (unsigned long long)r->crash_pc, (unsigned long long)r->crash_lr,
            (unsigned long long)r->crash_far);
}

/* The main thread leaves the crash on its own stack: while it waits for the teardown helper, a fault in another
 * thread enters this handler again on __nx_exception_stack, which must not hold the main thread's frames then. */
static u8 g_exit_stack[0x10000] __attribute__((aligned(16)));

static void __attribute__((noreturn, used)) crash_exit_main(void) {
    nxn__teardown(NXN__TD_BOUNDED);  // SDL audio closed on a helper thread, bounded in time (nxn_teardown.c)
    nxn__log_close();
    g_nxn.inited = 0;
    _exit(NXN_EXIT_CRASHED);  // skips atexit / destructors of the broken program, returns to the loader
}

static void __attribute__((noreturn)) run_on_exit_stack(void (*fn)(void)) {
    __asm__ volatile("mov sp, %0\n\tblr %1\n" ::"r"(g_exit_stack + sizeof g_exit_stack), "r"(fn) : "memory", "x30");
    __builtin_unreachable();
}

__attribute__((weak)) void __libnx_exception_handler(ThreadExceptionDump* ctx) {
    /* A thread the program before left running (Nexvyn OS's script watch thread did, console 2026-11-04), faulting in
     * that program's unmapped code: not the app's crash. It ends at once; its thread variables (threadGetCurHandle,
     * threadExit) point into the old program and are not touched. */
    if (nxmem_thread_is_leftover()) {
        __atomic_add_fetch(&nxn__leftover_faults, 1, __ATOMIC_RELAXED);
        svcExitThread();
    }
    Handle self = threadGetCurHandle();
    if (nxn__exiting) {
        /* the process is on its way out (bounded teardown): the exiting thread leaves now, any other one just ends */
        if (self == nxn__exiting) _exit(NXN_EXIT_CRASHED);
        svcExitThread();
    }
    if (!g_nxn.crash_guard || !g_nxn.inited || __sync_lock_test_and_set(&g_in_handler, 1)) return;  // -> svcBreak
    int main_thread = self == g_nxn.main_thread;
    record(ctx, self, main_thread);
    g_nxn.quit = 1;
    if (main_thread) {
        nxn__exiting = self;
        run_on_exit_stack(crash_exit_main);
    }
    g_in_handler = 0;  /* another thread may still crash; the record keeps the first crash */
    /* libnx's own thread exit, not svcExitThread: it marks the Thread as ended, so the join's threadClose unmaps the
     * stack and frees it. With a bare svcExitThread threadClose refuses, and the stack pages stay locked (Perm_None)
     * in the heap the next program gets: the console crash after a worker crash (hello_gl Y). */
    threadExit();
}
