/* Nexvyn compat: <ucontext.h> for AArch64 (getcontext, setcontext, makecontext, swapcontext).
 *
 * Saves what the AAPCS64 calls callee-saved: x19-x30, sp, d8-d15, fpcr, fpsr (plus x0-x7 so makecontext can pass
 * arguments). The signal mask is stored in the structure but not switched. Do not let a C++ exception leave the function
 * a context runs. Contexts must be resumed on the thread that created them. */
#ifndef NEXVYN_COMPAT_UCONTEXT_H
#define NEXVYN_COMPAT_UCONTEXT_H

#include <signal.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct nxc_mcontext {
    uint64_t x[8];      /* x0-x7: argument registers (makecontext), x0 = 0 after getcontext resumes */
    uint64_t x19_28[10];
    uint64_t fp;        /* x29 */
    uint64_t lr;        /* x30 */
    uint64_t sp;
    uint64_t pc;        /* entry point of a made context, 0 = continue at lr */
    uint64_t d[8];      /* d8-d15 */
    uint64_t fpcr;
    uint64_t fpsr;
} mcontext_t;

typedef struct ucontext_t {
    unsigned long uc_flags;
    struct ucontext_t* uc_link; /* resumed when the made function returns; NULL ends the program */
    stack_t uc_stack;
    sigset_t uc_sigmask;
    mcontext_t uc_mcontext;
} ucontext_t;

int getcontext(ucontext_t* ucp);
int setcontext(const ucontext_t* ucp);
int swapcontext(ucontext_t* oucp, const ucontext_t* ucp);
/* argc integer arguments (at most 8) are passed to func. */
void makecontext(ucontext_t* ucp, void (*func)(void), int argc, ...);

#ifdef __cplusplus
}
#endif
#endif
