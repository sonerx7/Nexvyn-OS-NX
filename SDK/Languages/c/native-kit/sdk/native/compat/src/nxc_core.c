/* Nexvyn compat layer - shared lock, logging, blocking primitive, process / system identity calls. */
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <malloc.h>
#include <sys/utsname.h>
#include <sys/random.h>
#include <time.h>
#include <unistd.h>

#include "nexvyn/compat.h"
#include "nexvyn/nxn_sys.h"
#include "nexvyn/nxn_fs.h"
#include "nxc_internal.h"

#pragma weak nxn_log_write
#pragma weak nxn_fs_path
#pragma weak nxc_fs_root
const char* nxc__default_root(void);

Mutex g_nxc_mu;
CondVar g_nxc_cv;

uint64_t nxc_now_ns(void) { return armTicksToNs(armGetSystemTick()); }

void nxc_wake_all(void) { condvarWakeAll(&g_nxc_cv); }

void nxc_log(const char* fmt, ...) {
    char line[256];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(line, sizeof line, fmt, ap);
    va_end(ap);
    if (nxn_log_write) {
        nxn_log_write(NXN_LOG_WARN, line);
    } else {
        fprintf(stderr, "[nxc] %s\n", line);
    }
}

void nxc_unsupported(const char* what, const char* hint) {
    static const char* seen[64];
    static int count;
    mutexLock(&g_nxc_mu);
    for (int i = 0; i < count; i++) {
        if (seen[i] == what || strcmp(seen[i], what) == 0) {
            mutexUnlock(&g_nxc_mu);
            return;
        }
    }
    if (count < 64) seen[count++] = what; /* callers pass string literals */
    mutexUnlock(&g_nxc_mu);
    nxc_log("%s is not available on Nexvyn: %s", what, hint);
}

int nxc_block_locked(uint64_t deadline_ns, uint64_t slice_ns, int restartable) {
    if (nxc_signal_any_pending()) {
        mutexUnlock(&g_nxc_mu);
        int no_restart = 0;
        int n = nxc_signal_deliver(&no_restart);
        mutexLock(&g_nxc_mu);
        if (n) return (no_restart || !restartable) ? NXC_WAIT_INTR : NXC_WAIT_OK;
    }
    uint64_t wait = UINT64_MAX;
    if (deadline_ns) {
        uint64_t now = nxc_now_ns();
        if (now >= deadline_ns) return NXC_WAIT_TIMEOUT;
        wait = deadline_ns - now;
    }
    if (slice_ns && slice_ns < wait) wait = slice_ns;
    if (wait == UINT64_MAX) {
        condvarWait(&g_nxc_cv, &g_nxc_mu);
    } else {
        condvarWaitTimeout(&g_nxc_cv, &g_nxc_mu, wait);
    }
    return NXC_WAIT_OK;
}

/* ---- setup ---- */

const char* nxc_version(void) { return NXC_VERSION_STRING; }

int nxc_init(void) {
    static int done;
    if (done) return 0;
    done = 1;
    const char* root = nxc_fs_root ? nxc_fs_root() : nxc__default_root(); /* weak: no PC path code in a NO_WRAP link */
    if (root && root[0]) {
        mkdir(root, 0777); /* may exist already; the ABI creates it on nxn_init */
        chdir(root);
        setenv("HOME", root, 0);
        setenv("PWD", root, 1);
    }
    if (!getenv("TMPDIR")) {
        char tmp[PATH_MAX] = "";
        if (nxn_fs_path && nxn_fs_path(NXN_DIR_CACHE, "", tmp, sizeof tmp) == NXN_OK && tmp[0]) setenv("TMPDIR", tmp, 0);
        else if (root && root[0]) {
            snprintf(tmp, sizeof tmp, "%s/tmp", root);
            mkdir(tmp, 0777);
            setenv("TMPDIR", tmp, 0);
        }
    }
    setenv("USER", "switch", 0);
    setenv("LOGNAME", "switch", 0);
    setenv("SHELL", "/bin/sh", 0); /* nothing runs it; programs only look at the name */
    return 0;
}

/* The default root: the app's data folder. Defined here so nxc_path.c stays pure. */
const char* nxc__default_root(void) {
    static char buf[PATH_MAX];
    if (!buf[0]) {
        if (!(nxn_fs_path && nxn_fs_path(NXN_DIR_DATA, "", buf, sizeof buf) == NXN_OK && buf[0])) {
            snprintf(buf, sizeof buf, "sdmc:/switch");
        }
    }
    return buf;
}

/* ---- environment ---- */

#if NXC_WINDOWED
/* A window must not change Nexvyn OS's environment: the app has its own table (win/nxc_win.c). */
int nxc__env_set(const char* name, const char* value, int overwrite);
int nxc__env_unset(const char* name);
int nxc__env_clear(void);
int clearenv(void) { return nxc__env_clear(); }
static int env_name_ok(const char* name) { return name && name[0] && !strchr(name, '='); }
int __wrap_setenv(const char* name, const char* value, int overwrite) {
    if (!env_name_ok(name) || !value) return NXC_FAIL(EINVAL);
    return nxc__env_set(name, value, overwrite);
}
int __wrap_unsetenv(const char* name) {
    if (!env_name_ok(name)) return NXC_FAIL(EINVAL);
    return nxc__env_unset(name);
}
#else
int clearenv(void) {
    extern char** environ;
    /* Cut the table to zero entries but keep the array: newlib's setenv() reallocs the table it allocated itself, so
     * swapping in another array (or NULL) would crash it. The strings leak, which is fine for a call this rare. */
    if (environ) environ[0] = NULL;
    return 0;
}

int __real_setenv(const char* name, const char* value, int overwrite);
int __real_unsetenv(const char* name);

static int env_name_ok(const char* name) { return name && name[0] && !strchr(name, '='); }

int __wrap_setenv(const char* name, const char* value, int overwrite) {
    if (!env_name_ok(name) || !value) return NXC_FAIL(EINVAL);
    return __real_setenv(name, value, overwrite);
}

int __wrap_unsetenv(const char* name) {
    if (!env_name_ok(name)) return NXC_FAIL(EINVAL);
    return __real_unsetenv(name);
}


char* secure_getenv(const char* name) { return getenv(name); }
#endif

/* ---- identity ---- */

pid_t __wrap_getpid(void) {
    static pid_t pid;
    if (!pid) {
        u64 id = 0;
        pid = R_SUCCEEDED(svcGetProcessId(&id, CUR_PROCESS_HANDLE)) && id ? (pid_t)id : 1;  /* the OS process: shared by every window */
    }
    return pid;
}

pid_t getppid(void) { return 1; }
uid_t getuid(void) { return 1000; }
uid_t geteuid(void) { return 1000; }
gid_t getgid(void) { return 1000; }
gid_t getegid(void) { return 1000; }
pid_t getpgrp(void) { return __wrap_getpid(); }
pid_t getpgid(pid_t pid) { return (pid == 0 || pid == __wrap_getpid()) ? __wrap_getpid() : (errno = ESRCH, -1); }
pid_t getsid(pid_t pid) { return getpgid(pid); }

mode_t umask(mode_t mask) {
    static mode_t cur = 022;
    mode_t old = cur;
    cur = mask & 0777;
    return old;
}

int uname(struct utsname* name) {
    if (!name) return NXC_FAIL(EFAULT);
    memset(name, 0, sizeof *name);
    snprintf(name->sysname, sizeof name->sysname, "Nexvyn");
    snprintf(name->nodename, sizeof name->nodename, "switch");
    snprintf(name->release, sizeof name->release, "%s", NXC_VERSION_STRING);
    snprintf(name->version, sizeof name->version, "Nexvyn native compat %s", NXC_VERSION_STRING);
    snprintf(name->machine, sizeof name->machine, "aarch64");
    return 0;
}

int getpagesize(void) { return (int)NXC_PAGE; }

static u64 info(InfoType t) {
    u64 v = 0;
    return R_SUCCEEDED(svcGetInfo(&v, t, CUR_PROCESS_HANDLE, 0)) ? v : 0;
}

long sysconf(int name) {
    switch (name) {
        case _SC_PAGESIZE: return (long)NXC_PAGE;
        case _SC_NPROCESSORS_CONF:
        case _SC_NPROCESSORS_ONLN: {
            u64 mask = info(InfoType_CoreMask);
            long n = 0;
            for (; mask; mask >>= 1) n += (long)(mask & 1);
            return n ? n : 3;
        }
        case _SC_PHYS_PAGES: return (long)(info(InfoType_TotalMemorySize) / NXC_PAGE);
        case _SC_AVPHYS_PAGES: {
            /* libnx takes all remaining memory as one heap at start-up, so "used" by the process is nearly everything:
             * report what is left of that heap instead */
            extern char *fake_heap_start, *fake_heap_end;
            size_t heap = (size_t)(fake_heap_end - fake_heap_start);
            size_t used = (size_t)mallinfo().uordblks;
            return (long)((heap > used ? heap - used : 0) / NXC_PAGE);
        }
        case _SC_CLK_TCK: return 100;
        case _SC_OPEN_MAX: return 1024;
        case _SC_ARG_MAX: return 131072;
        case _SC_CHILD_MAX: return 0;
        case _SC_NGROUPS_MAX: return 0;
        case _SC_LINE_MAX: return 2048;
        case _SC_HOST_NAME_MAX: return 64;
        case _SC_IOV_MAX: return IOV_MAX;
        case _SC_THREAD_STACK_MIN: return 16384;
        case _SC_MONOTONIC_CLOCK: return 200809L;
        case _SC_THREADS: return 200809L;
        case _SC_VERSION: return 200809L;
        case _SC_GETPW_R_SIZE_MAX:
        case _SC_GETGR_R_SIZE_MAX: return 1024;
        default: errno = EINVAL; return -1;
    }
}

int getrlimit(int resource, struct rlimit* rl) {
    if (!rl) return NXC_FAIL(EFAULT);
    rl->rlim_cur = rl->rlim_max = RLIM_INFINITY;
    if (resource == RLIMIT_NOFILE) rl->rlim_cur = rl->rlim_max = 1024;
    if (resource == RLIMIT_STACK) rl->rlim_cur = 8u << 20;
    if (resource == RLIMIT_CORE) rl->rlim_cur = rl->rlim_max = 0;
    return 0;
}

int setrlimit(int resource, const struct rlimit* rl) {
    (void)resource;
    return rl ? 0 : NXC_FAIL(EFAULT); /* accepted, not enforced */
}

/* ---- random ---- */

ssize_t getrandom(void* buf, size_t len, unsigned int flags) {
    (void)flags;
    if (!buf && len) return NXC_FAIL(EFAULT);
    randomGet(buf, len);
    return (ssize_t)len;
}

int getentropy(void* buf, size_t len) {
    if (len > 256) return NXC_FAIL(EIO);
    if (!buf && len) return NXC_FAIL(EFAULT);
    randomGet(buf, len);
    return 0;
}


/* ---- clocks ---- */

int __real_clock_gettime(clockid_t id, struct timespec* ts);
int __real_clock_getres(clockid_t id, struct timespec* ts);

static int map_clock(clockid_t* id, int* cpu) {
    *cpu = 0;
    switch (*id) {
        case CLOCK_REALTIME:
        case CLOCK_REALTIME_COARSE:
        case CLOCK_REALTIME_ALARM: *id = CLOCK_REALTIME; return 0;
        case CLOCK_MONOTONIC:
        case CLOCK_MONOTONIC_RAW:
        case CLOCK_MONOTONIC_COARSE:
        case CLOCK_BOOTTIME:
        case CLOCK_BOOTTIME_ALARM: *id = CLOCK_MONOTONIC; return 0;
        case CLOCK_PROCESS_CPUTIME_ID:
        case CLOCK_THREAD_CPUTIME_ID: *cpu = 1; return 0;
        default: return -1;
    }
}

int __wrap_clock_gettime(clockid_t id, struct timespec* ts) {
    int cpu;
    if (!ts) return NXC_FAIL(EFAULT);
    if (map_clock(&id, &cpu) != 0) return NXC_FAIL(EINVAL);
    if (cpu) {
        /* The kernel gives no CPU time of a process or thread: report the time since the first call (an upper bound). */
        static uint64_t start;
        uint64_t now = nxc_now_ns();
        if (!start) start = now;
        uint64_t d = now - start;
        ts->tv_sec = (time_t)(d / 1000000000ull);
        ts->tv_nsec = (long)(d % 1000000000ull);
        return 0;
    }
    return __real_clock_gettime(id, ts);
}

int __wrap_clock_getres(clockid_t id, struct timespec* ts) {
    int cpu;
    if (map_clock(&id, &cpu) != 0) return NXC_FAIL(EINVAL);
    if (cpu) {
        if (ts) {
            ts->tv_sec = 0;
            ts->tv_nsec = 52;
        }
        return 0;
    }
    return __real_clock_getres(id, ts);
}

int timespec_get(struct timespec* ts, int base) {
    if (!ts || base != TIME_UTC) return 0;
    return clock_gettime(CLOCK_REALTIME, ts) == 0 ? base : 0;
}

/* ---- sleeping (signal aware) ---- */

static int sleep_ns(uint64_t ns, uint64_t* left_ns);
int nxc_sleep_interruptible(uint64_t ns) { return sleep_ns(ns, NULL); }

static int sleep_ns(uint64_t ns, uint64_t* left_ns) {
    if (left_ns) *left_ns = 0;
    if (ns == 0) {
        svcSleepThread(0);
        return 0;
    }
    uint64_t deadline = nxc_now_ns() + ns;
    int rc = 0;
    mutexLock(&g_nxc_mu);
    for (;;) {
        int r = nxc_block_locked(deadline, 0, 0);
        if (r == NXC_WAIT_TIMEOUT) break;
        if (r == NXC_WAIT_INTR) {
            uint64_t now = nxc_now_ns();
            if (left_ns) *left_ns = now < deadline ? deadline - now : 0;
            rc = NXC_FAIL(EINTR);
            break;
        }
    }
    mutexUnlock(&g_nxc_mu);
    return rc;
}

int __wrap_nanosleep(const struct timespec* req, struct timespec* rem) {
    if (!req || req->tv_sec < 0 || req->tv_nsec < 0 || req->tv_nsec >= 1000000000L) return NXC_FAIL(EINVAL);
    uint64_t left = 0;
    int rc = sleep_ns((uint64_t)req->tv_sec * 1000000000ull + (uint64_t)req->tv_nsec, &left);
    if (rc && rem) {
        rem->tv_sec = (time_t)(left / 1000000000ull);
        rem->tv_nsec = (long)(left % 1000000000ull);
    }
    return rc;
}

unsigned int __wrap_sleep(unsigned int seconds) {
    uint64_t left = 0;
    if (sleep_ns((uint64_t)seconds * 1000000000ull, &left) != 0) return (unsigned int)((left + 999999999ull) / 1000000000ull);
    return 0;
}

int __wrap_usleep(useconds_t us) { return sleep_ns((uint64_t)us * 1000ull, NULL); }

int clock_nanosleep(clockid_t clk, int flags, const struct timespec* req, struct timespec* rem) {
    if (!req || req->tv_sec < 0 || req->tv_nsec < 0 || req->tv_nsec >= 1000000000L) return EINVAL;
    uint64_t ns = (uint64_t)req->tv_sec * 1000000000ull + (uint64_t)req->tv_nsec;
    if (flags & TIMER_ABSTIME) {
        struct timespec now;
        if (clock_gettime(clk, &now) != 0) return errno;
        uint64_t cur = (uint64_t)now.tv_sec * 1000000000ull + (uint64_t)now.tv_nsec;
        if (ns <= cur) return 0;
        ns -= cur;
        rem = NULL; /* POSIX: rem is unused for absolute sleeps */
    }
    uint64_t left = 0;
    if (sleep_ns(ns, &left) != 0) {
        if (rem) {
            rem->tv_sec = (time_t)(left / 1000000000ull);
            rem->tv_nsec = (long)(left % 1000000000ull);
        }
        return EINTR;
    }
    return 0;
}
