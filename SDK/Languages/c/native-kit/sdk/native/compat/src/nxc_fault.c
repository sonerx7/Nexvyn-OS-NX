/* Nexvyn compat layer - POSIX SIGSEGV / SIGBUS hardware fault bridge on top of nxn_fault_handler_set.
 *
 * When a native module installs a SA_SIGINFO handler for SIGSEGV or SIGBUS, this unit registers a single
 * nxn_fault_fn callback with the host (nxn_fault_handler_set, weak symbol). On a data abort, the callback runs
 * lock-free on the faulting thread's own stack, translates nxn_fault into siginfo_t + ucontext_t, invokes
 * sa_sigaction, and writes modified registers / sp / pc / NZCV back to nxn_fault so the thread resumes.
 *
 * Contract and limits (docs/current/n4/N4_FAULT_CONTRACT.md, docs/NATIVE_COMPAT.md):
 *  - Data aborts only (NXN_FAULT_DATA_ABORT). Other faults keep the host crash path.
 *  - SIG_DFL, SIG_IGN, non-SA_SIGINFO handlers, blocked signals, and unhandled signal kinds return 0 (crash path).
 *  - Lock-free, reentrant across threads; no nxn_* calls, locks, or allocations inside the fault callback.
 *  - x17 (regs[17]) is clobbered by nxw_fault_resume and not restored; SIMD registers and FPCR/FPSR are not editable. */
#include <signal.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#include <ucontext.h>

#include "nexvyn/nxn_jit.h"

#ifndef NXC_HOST_TEST
#include "nxc_internal.h"
#pragma weak nxn_fault_handler_set
#endif

typedef void (*nxc_fault_sigaction_fn)(int, siginfo_t*, void*);

typedef struct nxc_fault_entry {
    nxc_fault_sigaction_fn fn; /* NULL when inactive (SIG_DFL / SIG_IGN / non-SA_SIGINFO) */
    int flags;                 /* SA_SIGINFO, SA_RESETHAND, ... (immutable once published via active) */
} nxc_fault_entry;

typedef struct nxc_fault_slot {
    nxc_fault_entry entries[2]; /* double-buffered so fn and flags publish atomically without tearing */
    unsigned active;
    int reset_pending;          /* set atomically to 1 when a SA_RESETHAND hardware fault fires */
} nxc_fault_slot;

enum {
    NXC_FAULT_SLOT_SEGV = 0,
    NXC_FAULT_SLOT_BUS = 1,
    NXC_FAULT_SLOT_COUNT = 2
};

static nxc_fault_slot g_fault_slots[NXC_FAULT_SLOT_COUNT];
static int g_fault_installed;

/* Defined in nxc_signal.c (lock-free atomic load of g_blocked). */
extern uint64_t nxc__signal_blocked_mask(void);

static int slot_index(int sig) {
    if (sig == SIGSEGV) return NXC_FAULT_SLOT_SEGV;
    if (sig == SIGBUS) return NXC_FAULT_SLOT_BUS;
    return -1;
}

/* Decode ARMv8 ESR_EL1 Data Abort DFSC (bits 5..0) into POSIX (signo, si_code). */
void nxc__fault_decode_esr(uint64_t esr, int* out_sig, int* out_code) {
    uint32_t dfsc = (uint32_t)(esr & NXC_ESR_DFSC_MASK);
    int sig = SIGSEGV;
    int code = SEGV_MAPERR;

    if ((dfsc & 0x3Cu) == 0x0Cu) {
        /* Permission fault, level 0..3 (0x0C..0x0F). */
        sig = SIGSEGV;
        code = SEGV_ACCERR;
    } else if ((dfsc & 0x3Cu) == 0x04u || (dfsc & 0x3Cu) == 0x00u || (dfsc & 0x3Cu) == 0x08u) {
        /* Translation fault (0x04..0x07), address size fault (0x00..0x03), access flag fault (0x08..0x0B). */
        sig = SIGSEGV;
        code = SEGV_MAPERR;
    } else if (dfsc == 0x21u) {
        /* Alignment fault. */
        sig = SIGBUS;
        code = BUS_ADRALN;
    } else if (dfsc == 0x10u || dfsc == 0x11u || (dfsc & 0x3Cu) == 0x14u) {
        /* Synchronous external abort (not on table walk, tag check, or on translation table walk). */
        sig = SIGBUS;
        code = BUS_ADRERR;
    } else if (dfsc == 0x18u || (dfsc & 0x3Cu) == 0x1Cu) {
        /* Synchronous parity or ECC error on memory access / translation table walk. */
        sig = SIGBUS;
        code = BUS_OBJERR;
    }

    if (out_sig) *out_sig = sig;
    if (out_code) *out_code = code;
}

/* Host nxn_fault_fn callback: runs on the faulting thread's stack. Must not lock, allocate, or call nxn_*. */
int nxc__fault_dispatch(nxn_fault* f, void* user) {
    (void)user;
    if (!f || f->size < sizeof(nxn_fault) || f->kind != NXN_FAULT_DATA_ABORT) return 0;

    int sig = 0;
    int code = 0;
    nxc__fault_decode_esr(f->esr, &sig, &code);

    int idx = slot_index(sig);
    if (idx < 0) return 0;

    /* Synchronous hardware faults cannot be deferred: a blocked signal takes the crash path (as on Linux). */
    uint64_t blocked = nxc__signal_blocked_mask();
    if (sig > 0 && sig < 64 && (blocked & (UINT64_C(1) << sig))) return 0;

    nxc_fault_slot* slot = &g_fault_slots[idx];
    unsigned active = __atomic_load_n(&slot->active, __ATOMIC_ACQUIRE) & 1u;
    nxc_fault_entry* entry = &slot->entries[active];
    nxc_fault_sigaction_fn fn = __atomic_load_n(&entry->fn, __ATOMIC_ACQUIRE);
    if (!fn) return 0;

    int flags = entry->flags;
    if (flags & SA_RESETHAND) {
        nxc_fault_sigaction_fn expected = fn;
        if (!__atomic_compare_exchange_n(&entry->fn, &expected, NULL, 0, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE)) {
            return 0;
        }
        __atomic_store_n(&slot->reset_pending, 1, __ATOMIC_RELEASE);
    }

    siginfo_t si;
    memset(&si, 0, sizeof si);
    si.si_signo = sig;
    si.si_errno = 0;
    si.si_code = code;
    si.si_addr = (void*)(uintptr_t)f->addr;

    ucontext_t uc;
    memset(&uc, 0, sizeof uc);
    uc.uc_sigmask = (sigset_t)blocked;
    uc.uc_mcontext.fault_address = f->addr;
    for (int i = 0; i < 31; i++) uc.uc_mcontext.regs[i] = f->x[i];
    uc.uc_mcontext.sp = f->sp;
    uc.uc_mcontext.pc = f->pc;
    uc.uc_mcontext.pstate = f->pstate;
    uc.uc_mcontext.esr = f->esr;

    fn(sig, &si, &uc);

    /* Write editable state back into *f. x17 is clobbered by nxw_fault_resume; only NZCV (bits 31..28) of pstate apply. */
    for (int i = 0; i < 31; i++) f->x[i] = uc.uc_mcontext.regs[i];
    f->sp = uc.uc_mcontext.sp;
    f->pc = uc.uc_mcontext.pc;
    f->pstate = (f->pstate & ~UINT64_C(0xF0000000)) | (uc.uc_mcontext.pstate & UINT64_C(0xF0000000));
    return 1;
}

static int action_wants_fault_bridge(const struct sigaction* act) {
    return act != NULL && (act->sa_flags & SA_SIGINFO) != 0 && act->sa_sigaction != NULL &&
           act->sa_handler != SIG_DFL && act->sa_handler != SIG_IGN;
}

static void store_slot_locked(int idx, const struct sigaction* act) {
    nxc_fault_slot* slot = &g_fault_slots[idx];
    unsigned next = 1u - (__atomic_load_n(&slot->active, __ATOMIC_RELAXED) & 1u);
    if (action_wants_fault_bridge(act)) {
        slot->entries[next].flags = act->sa_flags;
        __atomic_store_n(&slot->entries[next].fn, act->sa_sigaction, __ATOMIC_RELAXED);
    } else {
        slot->entries[next].flags = 0;
        __atomic_store_n(&slot->entries[next].fn, NULL, __ATOMIC_RELAXED);
    }
    __atomic_store_n(&slot->reset_pending, 0, __ATOMIC_RELEASE);
    __atomic_store_n(&slot->active, next, __ATOMIC_RELEASE);
}

/* Synchronize SIGSEGV/SIGBUS fault slots and host nxn_fault_handler_set registration.
 * Caller holds g_nxc_mu. Returns: 1 = active & installed, 0 = inactive, -1 = active wanted but host unsupported. */
int nxc__fault_sync_locked(const struct sigaction* segv_act, const struct sigaction* bus_act) {
    store_slot_locked(NXC_FAULT_SLOT_SEGV, segv_act);
    store_slot_locked(NXC_FAULT_SLOT_BUS, bus_act);

    int want = action_wants_fault_bridge(segv_act) || action_wants_fault_bridge(bus_act);
    if (want) {
        if (!g_fault_installed) {
#ifndef NXC_HOST_TEST
            if (!nxn_fault_handler_set) return -1;
#endif
            if (nxn_fault_handler_set(nxc__fault_dispatch, NULL) != NXN_OK) return -1;
            g_fault_installed = 1;
        }
        return 1;
    }

    if (g_fault_installed) {
#ifndef NXC_HOST_TEST
        if (nxn_fault_handler_set) nxn_fault_handler_set(NULL, NULL);
#else
        nxn_fault_handler_set(NULL, NULL);
#endif
        g_fault_installed = 0;
    }
    return 0;
}

int nxc__fault_consume_reset(int sig) {
    int idx = slot_index(sig);
    if (idx < 0) return 0;
    return __atomic_exchange_n(&g_fault_slots[idx].reset_pending, 0, __ATOMIC_ACQ_REL);
}

void nxc__fault_shutdown_locked(void) {
    store_slot_locked(NXC_FAULT_SLOT_SEGV, NULL);
    store_slot_locked(NXC_FAULT_SLOT_BUS, NULL);
    if (g_fault_installed) {
#ifndef NXC_HOST_TEST
        if (nxn_fault_handler_set) nxn_fault_handler_set(NULL, NULL);
#else
        nxn_fault_handler_set(NULL, NULL);
#endif
        g_fault_installed = 0;
    }
}
