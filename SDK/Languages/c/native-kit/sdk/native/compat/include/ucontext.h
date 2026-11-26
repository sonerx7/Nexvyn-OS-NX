/* Nexvyn compat: <ucontext.h> for AArch64 (getcontext, setcontext, makecontext, swapcontext, and SA_SIGINFO fault delivery).
 *
 * Coroutines (getcontext/setcontext/swapcontext/makecontext): saves what AAPCS64 calls callee-saved (regs[19..30], sp,
 * d8-d15, fpcr, fpsr) plus regs[0..7] so makecontext can pass arguments. The signal mask is stored but not switched.
 * Do not let a C++ exception leave the function a context runs. Contexts must be resumed on the thread that created them.
 *
 * Hardware fault delivery (SIGSEGV / SIGBUS with SA_SIGINFO, docs/NATIVE_COMPAT.md): fault_address, regs[0..30], sp,
 * pc, pstate and esr are populated from nxn_fault (data aborts only). Changes to regs[0..30] (except x17), sp, pc and
 * pstate NZCV bits (31..28) are written back on handler return. SIMD registers (d[], q0..q31) and fpcr/fpsr are not
 * populated or editable in fault handlers. */
#ifndef NEXVYN_COMPAT_UCONTEXT_H
#define NEXVYN_COMPAT_UCONTEXT_H

#include <signal.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* AArch64 Data Abort ESR_EL1 syndrome fields exposed in uc->uc_mcontext.esr. */
#define NXC_ESR_DFSC_MASK UINT64_C(0x3F)
#define NXC_ESR_WNR       (UINT64_C(1) << 6) /* 1 = write (store), 0 = read (load) */

typedef struct nxc_mcontext {
    uint64_t fault_address; /* faulting data address (FAR) on hardware fault delivery, else 0 */
    uint64_t regs[31];      /* x0-x30 (regs[29] = fp, regs[30] = lr); x17 is not restored on fault resume */
    uint64_t sp;
    uint64_t pc;            /* faulting instruction on fault delivery; entry point of a made context (0 = continue at lr) */
    uint64_t pstate;        /* NZCV in bits 31..28 restored on fault resume */
    uint64_t esr;           /* AArch64 ESR_EL1 syndrome on hardware fault delivery (bit 6 = WnR: 1 write, 0 read) */
    uint64_t d[8];          /* d8-d15 (getcontext/setcontext/swapcontext only; not editable in fault handlers) */
    uint64_t fpcr;          /* getcontext/setcontext/swapcontext only */
    uint64_t fpsr;          /* getcontext/setcontext/swapcontext only */
} mcontext_t;

typedef struct ucontext_t {
    unsigned long uc_flags;
    struct ucontext_t* uc_link; /* resumed when the made function returns; NULL ends the program */
    stack_t uc_stack;
    sigset_t uc_sigmask;
    mcontext_t uc_mcontext;
} ucontext_t;

/* Returns 1 when a hardware data abort ucontext came from a write (ESR WnR bit = 1), 0 for a read or NULL. */
static inline int nxc_fault_is_write(const ucontext_t* uc) {
    return uc != NULL && (uc->uc_mcontext.esr & NXC_ESR_WNR) != 0;
}

int getcontext(ucontext_t* ucp);
int setcontext(const ucontext_t* ucp);
int swapcontext(ucontext_t* oucp, const ucontext_t* ucp);
/* argc integer arguments (at most 8) are passed to func. */
void makecontext(ucontext_t* ucp, void (*func)(void), int argc, ...);

#ifdef __cplusplus
}
#endif
#endif
