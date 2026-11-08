/* Nexvyn compat layer - signal emulation.
 *
 * There is no kernel signal delivery on this platform, so a signal is a pending bit that a handler call consumes at a
 * safe point: inside raise() / kill(getpid(), sig) / pthread_kill(), inside blocking compat calls (sleep, poll, select,
 * pipe and eventfd reads and writes, sigsuspend, sigwait), and in nxc_signal_poll(). alarm() / setitimer(ITIMER_REAL)
 * run a small timer thread that only sets the pending bit and wakes the waiters; handlers always run on a thread that
 * called into this layer. One process-wide signal mask. SIGSEGV / SIGBUS / SIGILL / SIGFPE are never delivered. */
#include <errno.h>
#include <pthread.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <unistd.h>

#include "nexvyn/compat.h"
#include "nxc_internal.h"

#define SIGBIT(s) (1ull << (s))
#define VALID(s) ((s) > 0 && (s) < 32)
#define CANNOT_BLOCK (SIGBIT(SIGKILL) | SIGBIT(SIGSTOP))

static struct sigaction g_act[32];
static volatile uint64_t g_pending;
static uint64_t g_blocked;

/* A timer signal belongs to the thread that armed the timer (what programs expect from alarm() / setitimer()): other threads
 * leave it pending, so a helper thread sleeping in the layer cannot swallow it. Every other signal goes to whoever polls. */
static void* g_owner[32];

static void* self_id(void) { return armGetTls(); }

static uint64_t deliverable(uint64_t p) {
    void* me = self_id();
    for (uint64_t rest = p; rest;) {
        int s = __builtin_ctzll(rest);
        rest &= rest - 1;
        if (g_owner[s] && g_owner[s] != me) p &= ~SIGBIT(s);
    }
    return p;
}

/* On the heap, not in the module's static data: libnx keeps every live thread's record in one list that later thread
 * starts and exits write into, so in a window a record inside the module would keep a crashed app's code memory from
 * being given back while this thread is stopped (Nexvyn OS checks it). */
static Thread* g_timer_thread;
static int g_timer_started;
static CondVar g_timer_cv;
static uint64_t g_it_deadline, g_it_interval; /* 0 = disarmed */

/* newlib's sigaddset() macro does 1 << sig on an int: SIGUSR2 (31) sign-extends, so only bits 1..31 count */
static uint64_t mask_of(const sigset_t* s) { return ((uint64_t)*s) & 0xfffffffeull; }

int nxc_signal_any_pending(void) {
    uint64_t p = __atomic_load_n(&g_pending, __ATOMIC_ACQUIRE);
    return deliverable(p & ~__atomic_load_n(&g_blocked, __ATOMIC_RELAXED)) != 0;
}

static int default_is_ignore(int sig) {
    return sig == SIGCHLD || sig == SIGWINCH || sig == SIGURG || sig == SIGCONT || sig == SIGPIPE || sig == SIGIO ||
           sig == SIGPROF || sig == SIGVTALRM;
}

static void default_terminate(int sig) {
    nxc_log("signal %d with no handler: ending the app (exit code %d)", sig, 128 + sig);
    if (sig == SIGABRT || sig == SIGKILL) _exit(128 + sig);
    exit(128 + sig);
}

int nxc_signal_deliver(int* no_restart) {
    int count = 0;
    mutexLock(&g_nxc_mu);
    for (;;) {
        uint64_t ready = deliverable(g_pending & ~g_blocked & ~1ull);
        if (!ready) break;
        int sig = __builtin_ctzll(ready);
        __atomic_and_fetch(&g_pending, ~SIGBIT(sig), __ATOMIC_ACQ_REL);
        struct sigaction act = g_act[sig];
        void (*h)(int) = act.sa_handler;
        if (h == SIG_IGN) continue;
        if (h == SIG_DFL) {
            if (default_is_ignore(sig)) continue;
            mutexUnlock(&g_nxc_mu);
            default_terminate(sig);
            return count;
        }
        uint64_t saved = g_blocked;
        g_blocked |= mask_of(&act.sa_mask);
        if (!(act.sa_flags & SA_NODEFER)) g_blocked |= SIGBIT(sig);
        if (act.sa_flags & SA_RESETHAND) g_act[sig].sa_handler = SIG_DFL;
        mutexUnlock(&g_nxc_mu);
        if (act.sa_flags & SA_SIGINFO) {
            siginfo_t si;
            memset(&si, 0, sizeof si);
            si.si_signo = sig;
            si.si_code = sig == SIGALRM ? SI_TIMER : SI_USER;
            act.sa_sigaction(sig, &si, NULL);
        } else {
            h(sig);
        }
        mutexLock(&g_nxc_mu);
        g_blocked = (g_blocked & ~(mask_of(&act.sa_mask) | SIGBIT(sig))) | (saved & (mask_of(&act.sa_mask) | SIGBIT(sig)));
        count++;
        if (no_restart && !(act.sa_flags & SA_RESTART)) *no_restart = 1;
    }
    mutexUnlock(&g_nxc_mu);
    return count;
}

int nxc_signal_poll(void) { return nxc_signal_deliver(NULL); }

static void post(int sig) {
    __atomic_or_fetch(&g_pending, SIGBIT(sig), __ATOMIC_ACQ_REL);
    mutexLock(&g_nxc_mu);
    nxc_wake_all();
    mutexUnlock(&g_nxc_mu);
}

/* ---- raise / kill ---- */

int __wrap_raise(int sig) {
    if (sig == 0) return 0;
    if (!VALID(sig)) return NXC_FAIL(EINVAL);
    post(sig);
    nxc_signal_deliver(NULL);
    return 0;
}

int __wrap_kill(pid_t pid, int sig) {
    if (sig < 0 || (sig && !VALID(sig))) return NXC_FAIL(EINVAL);
    if (pid != getpid() && pid != 0 && pid != -1 && pid != -getpid()) return NXC_FAIL(ESRCH);
    return sig ? __wrap_raise(sig) : 0;
}

int killpg(pid_t pgrp, int sig) { return __wrap_kill(pgrp == 0 ? 0 : -pgrp, sig); }
int pthread_kill(pthread_t t, int sig) { return __wrap_raise(sig) == 0 ? 0 : errno; }

/* ---- handlers ---- */

static int sig_changeable(int sig) { return VALID(sig) && sig != SIGKILL && sig != SIGSTOP; }

int sigaction(int sig, const struct sigaction* act, struct sigaction* old) {
    if (!VALID(sig) || (act && !sig_changeable(sig))) return NXC_FAIL(EINVAL);
    mutexLock(&g_nxc_mu);
    if (old) *old = g_act[sig];
    if (act) g_act[sig] = *act;
    mutexUnlock(&g_nxc_mu);
    if (act && act->sa_handler != SIG_DFL && act->sa_handler != SIG_IGN &&
        (sig == SIGSEGV || sig == SIGBUS || sig == SIGILL || sig == SIGFPE)) {
        nxc_unsupported("hardware fault signals", "a handler for SIGSEGV / SIGBUS / SIGILL / SIGFPE is accepted but never called (Native v2)");
    }
    return 0;
}

void (*__wrap_signal(int sig, void (*handler)(int)))(int) {
    struct sigaction act, old;
    memset(&act, 0, sizeof act);
    act.sa_handler = handler;
    act.sa_flags = SA_RESTART;
    if (!sig_changeable(sig)) return (errno = EINVAL, SIG_ERR);
    if (sigaction(sig, &act, &old) != 0) return SIG_ERR;
    return old.sa_handler;
}

int siginterrupt(int sig, int flag) {
    struct sigaction act;
    if (sigaction(sig, NULL, &act) != 0) return -1;
    if (flag) act.sa_flags &= ~SA_RESTART; else act.sa_flags |= SA_RESTART;
    return sigaction(sig, &act, NULL);
}

int sigaltstack(const stack_t* ss, stack_t* old) {
    if (old) memset(old, 0, sizeof *old);
    (void)ss; /* handlers run on the caller's stack; accepted for programs that always set one up */
    return 0;
}

/* ---- mask ---- */

int sigprocmask(int how, const sigset_t* set, sigset_t* old) {
    mutexLock(&g_nxc_mu);
    if (old) *old = (sigset_t)g_blocked;
    if (set) {
        uint64_t m = mask_of(set) & ~CANNOT_BLOCK;
        if (how == SIG_BLOCK) g_blocked |= m;
        else if (how == SIG_UNBLOCK) g_blocked &= ~m;
        else if (how == SIG_SETMASK) g_blocked = m;
        else {
            mutexUnlock(&g_nxc_mu);
            return NXC_FAIL(EINVAL);
        }
    }
    mutexUnlock(&g_nxc_mu);
    if (set && how != SIG_BLOCK) nxc_signal_deliver(NULL); /* unblocked signals that were pending run now */
    return 0;
}

int pthread_sigmask(int how, const sigset_t* set, sigset_t* old) { return sigprocmask(how, set, old) == 0 ? 0 : errno; }

int sigpending(sigset_t* set) {
    if (!set) return NXC_FAIL(EFAULT);
    *set = (sigset_t)(__atomic_load_n(&g_pending, __ATOMIC_ACQUIRE) & g_blocked);
    return 0;
}

int sigsuspend(const sigset_t* mask) {
    if (!mask) return NXC_FAIL(EFAULT);
    mutexLock(&g_nxc_mu);
    uint64_t saved = g_blocked;
    g_blocked = mask_of(mask) & ~CANNOT_BLOCK;
    mutexUnlock(&g_nxc_mu);
    for (;;) {
        if (nxc_signal_deliver(NULL)) break;
        mutexLock(&g_nxc_mu);
        if (!(g_pending & ~g_blocked)) condvarWaitTimeout(&g_nxc_cv, &g_nxc_mu, 50000000ull);
        mutexUnlock(&g_nxc_mu);
    }
    mutexLock(&g_nxc_mu);
    g_blocked = saved;
    mutexUnlock(&g_nxc_mu);
    return NXC_FAIL(EINTR);
}

int sigwait(const sigset_t* set, int* sig) {
    if (!set || !sig) return EFAULT;
    uint64_t want = mask_of(set);
    mutexLock(&g_nxc_mu);
    for (;;) {
        uint64_t hit = g_pending & want;
        if (hit) {
            int s = __builtin_ctzll(hit);
            __atomic_and_fetch(&g_pending, ~SIGBIT(s), __ATOMIC_ACQ_REL);
            mutexUnlock(&g_nxc_mu);
            *sig = s;
            return 0;
        }
        condvarWaitTimeout(&g_nxc_cv, &g_nxc_mu, 50000000ull);
    }
}

/* ---- timers ---- */

static int g_timer_stop;

static void timer_main(void* unused) {
    mutexLock(&g_nxc_mu);
    for (;;) {
        if (g_timer_stop) break;
        if (!g_it_deadline) {
            condvarWait(&g_timer_cv, &g_nxc_mu);
            continue;
        }
        uint64_t now = nxc_now_ns();
        if (now < g_it_deadline) {
            condvarWaitTimeout(&g_timer_cv, &g_nxc_mu, g_it_deadline - now);
            continue;
        }
        if (g_it_interval) {
            do g_it_deadline += g_it_interval; while (g_it_deadline <= now);
        } else {
            g_it_deadline = 0;
        }
        __atomic_or_fetch(&g_pending, SIGBIT(SIGALRM), __ATOMIC_ACQ_REL);
        nxc_wake_all();
    }
    mutexUnlock(&g_nxc_mu);
}

void nxc_shutdown(void) {
    mutexLock(&g_nxc_mu);
    g_it_deadline = 0;
    g_it_interval = 0;
    if (!g_timer_started) {
        mutexUnlock(&g_nxc_mu);
        return;
    }
    g_timer_stop = 1;
    condvarWakeAll(&g_timer_cv);
    mutexUnlock(&g_nxc_mu);
    threadWaitForExit(g_timer_thread);
    threadClose(g_timer_thread);
    free(g_timer_thread);
    g_timer_thread = NULL;
    mutexLock(&g_nxc_mu);
    g_timer_started = 0;
    g_timer_stop = 0;
    mutexUnlock(&g_nxc_mu);
}

/* Lock held. */
static int timer_start_locked(void) {
    if (g_timer_started) return 0;
    mutexUnlock(&g_nxc_mu);
    Thread* t = g_timer_thread ? g_timer_thread : (Thread*)calloc(1, sizeof *t);
    Result rc = t ? threadCreate(t, timer_main, NULL, NULL, 0x4000, 0x2C, -2) : MAKERESULT(Module_Libnx, LibnxError_OutOfMemory);
    if (R_SUCCEEDED(rc)) rc = threadStart(t);
    mutexLock(&g_nxc_mu);
    if (t && !g_timer_thread) g_timer_thread = t;
    if (R_FAILED(rc)) return -1;
    g_timer_started = 1;
    return 0;
}

static uint64_t tv_to_ns(const struct timeval* tv) { return (uint64_t)tv->tv_sec * 1000000000ull + (uint64_t)tv->tv_usec * 1000ull; }

static void ns_to_tv(uint64_t ns, struct timeval* tv) {
    tv->tv_sec = (time_t)(ns / 1000000000ull);
    tv->tv_usec = (suseconds_t)((ns % 1000000000ull) / 1000ull);
}

int setitimer(int which, const struct itimerval* val, struct itimerval* old) {
    if (which != ITIMER_REAL) return NXC_FAIL(EINVAL);
    if (!val || val->it_value.tv_sec < 0 || val->it_value.tv_usec < 0 || val->it_value.tv_usec >= 1000000 || val->it_interval.tv_sec < 0 ||
        val->it_interval.tv_usec < 0 || val->it_interval.tv_usec >= 1000000)
        return NXC_FAIL(EINVAL);
    uint64_t value = tv_to_ns(&val->it_value), interval = tv_to_ns(&val->it_interval);
    mutexLock(&g_nxc_mu);
    if (value && timer_start_locked() != 0) {
        mutexUnlock(&g_nxc_mu);
        return NXC_FAIL(EAGAIN);
    }
    uint64_t now = nxc_now_ns();
    if (old) {
        ns_to_tv(g_it_deadline > now ? g_it_deadline - now : 0, &old->it_value);
        ns_to_tv(g_it_interval, &old->it_interval);
    }
    g_it_deadline = value ? now + value : 0;
    g_it_interval = interval;
    g_owner[SIGALRM] = value ? self_id() : NULL;
    if (g_timer_started) condvarWakeAll(&g_timer_cv);
    mutexUnlock(&g_nxc_mu);
    return 0;
}

int getitimer(int which, struct itimerval* cur) {
    if (which != ITIMER_REAL || !cur) return NXC_FAIL(EINVAL);
    mutexLock(&g_nxc_mu);
    uint64_t now = nxc_now_ns();
    ns_to_tv(g_it_deadline > now ? g_it_deadline - now : 0, &cur->it_value);
    ns_to_tv(g_it_interval, &cur->it_interval);
    mutexUnlock(&g_nxc_mu);
    return 0;
}

unsigned int alarm(unsigned int seconds) {
    struct itimerval nv, ov;
    memset(&nv, 0, sizeof nv);
    nv.it_value.tv_sec = (time_t)seconds;
    if (setitimer(ITIMER_REAL, &nv, &ov) != 0) return 0;
    return (unsigned int)(ov.it_value.tv_sec + (ov.it_value.tv_usec ? 1 : 0));
}

useconds_t ualarm(useconds_t usecs, useconds_t interval) {
    struct itimerval nv, ov;
    nv.it_value.tv_sec = (time_t)(usecs / 1000000u);
    nv.it_value.tv_usec = (suseconds_t)(usecs % 1000000u);
    nv.it_interval.tv_sec = (time_t)(interval / 1000000u);
    nv.it_interval.tv_usec = (suseconds_t)(interval % 1000000u);
    if (setitimer(ITIMER_REAL, &nv, &ov) != 0) return 0;
    return (useconds_t)(ov.it_value.tv_sec * 1000000 + ov.it_value.tv_usec);
}
