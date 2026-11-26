/* Nexvyn compat: <sys/signal.h> (and so <signal.h>, which newlib builds on it).
 *
 * newlib's struct sigaction has no sa_sigaction, its siginfo_t has no si_addr, and its flag set is only SA_NOCLDSTOP,
 * so PC code that installs SA_SIGINFO handlers does not compile. This header renames newlib's structures and defines
 * the POSIX / Linux style ones. Emulated signals deliver at safe points (nxc_signal_poll()); hardware data aborts
 * deliver directly to SA_SIGINFO handlers for SIGSEGV and SIGBUS via nxn_fault_handler_set (docs/NATIVE_COMPAT.md). */
#ifndef NEXVYN_COMPAT_SYS_SIGNAL_H
#define NEXVYN_COMPAT_SYS_SIGNAL_H

#define sigaction __nxc_newlib_sigaction
#define siginfo_t __nxc_newlib_siginfo_t
#include_next <sys/signal.h>
#undef siginfo_t
#undef sigaction

/* newlib shifts a signed int in these macros. On this target SIGUSR2 is 31;
 * use the unsigned sigset_t width so valid high-bit signals have defined masks.
 * No layout/function/ordinal change; callers adopting this fix must rebuild. */
#undef sigaddset
#undef sigdelset
#undef sigismember
#define sigaddset(what, sig) (*(what) |= ((sigset_t)1u << (sig)), 0)
#define sigdelset(what, sig) (*(what) &= ~((sigset_t)1u << (sig)), 0)
#define sigismember(what, sig) (((*(what)) & ((sigset_t)1u << (sig))) != 0)

#undef SA_NOCLDSTOP
#define SA_NOCLDSTOP 0x1
#undef SA_SIGINFO
#define SA_SIGINFO 0x4
#undef SA_ONSTACK
#define SA_ONSTACK 0x08000000
#define SA_RESTART 0x10000000
#define SA_NODEFER 0x40000000
#define SA_RESETHAND 0x80000000u
#define SA_NOCLDWAIT 0x2
#define SA_NOMASK SA_NODEFER
#define SA_ONESHOT SA_RESETHAND

#ifndef SI_TIMER
#define SI_TIMER 3
#endif
#ifndef SI_QUEUE
#define SI_QUEUE 4
#endif

/* SIGSEGV si_code values */
#ifndef SEGV_MAPERR
#define SEGV_MAPERR 1
#endif
#ifndef SEGV_ACCERR
#define SEGV_ACCERR 2
#endif

/* SIGBUS si_code values */
#ifndef BUS_ADRALN
#define BUS_ADRALN 1
#endif
#ifndef BUS_ADRERR
#define BUS_ADRERR 2
#endif
#ifndef BUS_OBJERR
#define BUS_OBJERR 3
#endif

#ifdef __cplusplus
extern "C" {
#endif

typedef struct siginfo {
    int          si_signo;    /* Signal number */
    int          si_errno;    /* Errno value (0 for hardware faults) */
    int          si_code;     /* Signal code (SI_USER, SEGV_MAPERR, SEGV_ACCERR, BUS_ADRALN, ...) */
    union sigval si_value;    /* Signal value */
    void*        si_addr;     /* Faulting memory address (FAR) for SIGSEGV / SIGBUS */
} siginfo_t;

struct sigaction {
    union {
        void (*sa_handler)(int);
        void (*sa_sigaction)(int, siginfo_t*, void*);
    };
    sigset_t sa_mask;
    int sa_flags;
    void (*sa_restorer)(void);
};

int sigaction(int sig, const struct sigaction* act, struct sigaction* oldact);
int sigaltstack(const stack_t* ss, stack_t* old);
int siginterrupt(int sig, int flag);

#ifdef __cplusplus
}
#endif
#endif
