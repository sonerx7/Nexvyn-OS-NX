/* Nexvyn compat: <sys/signal.h> (and so <signal.h>, which newlib builds on it).
 *
 * newlib's struct sigaction has no sa_sigaction and its flag set is only SA_NOCLDSTOP, so PC code that installs
 * SA_SIGINFO handlers does not compile. This header renames newlib's structure and defines the Linux style one.
 * Signals are emulated (docs/NATIVE_COMPAT.md): delivery happens at safe points, see nxc_signal_poll(). */
#ifndef NEXVYN_COMPAT_SYS_SIGNAL_H
#define NEXVYN_COMPAT_SYS_SIGNAL_H

#define sigaction __nxc_newlib_sigaction
#include_next <sys/signal.h>
#undef sigaction

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

#ifdef __cplusplus
extern "C" {
#endif

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
