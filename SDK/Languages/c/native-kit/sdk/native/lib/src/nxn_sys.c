/* Nexvyn Native SDK library - time, threads and logging (nxn_sys.h). */
#include "nxn_internal.h"
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

/* ---------------------------------------------------------------- time */
uint64_t nxn_time_ns(void) { return armTicksToNs(armGetSystemTick()); }
int64_t nxn_time_unix(void) { return (int64_t)time(NULL); }
void nxn_sleep_ns(uint64_t ns) {
    if (!nxc_sleep_interruptible) {
        svcSleepThread((s64)ns);
        return;
    }
    /* compat linked: emulated signals are delivered while sleeping; the sleep itself still lasts the full time */
    uint64_t end = nxn_time_ns() + ns;
    for (;;) {
        if (nxc_sleep_interruptible(ns) == 0) return;
        uint64_t now = nxn_time_ns();
        if (now >= end) return;
        ns = end - now;
    }
}

/* ---------------------------------------------------------------- threads */
struct nxn_thread {
    Thread t;
    nxn_thread_fn fn;
    void* arg;
    char name[48];
};

#define NXN_MAX_THREADS 64
static struct nxn_thread* g_threads[NXN_MAX_THREADS];
static Mutex g_threads_lock;

const char* nxn__thread_name(Handle h) {
    for (int i = 0; i < NXN_MAX_THREADS; i++) {
        struct nxn_thread* t = g_threads[i];
        if (t && t->t.handle == h) return t->name;
    }
    return "";
}

int nxn__threads_pause_others(Handle self) {
    /* no lock: the crashed thread may hold it; the table only ever holds valid pointers or NULL */
    int n = 0;
    for (int i = 0; i < NXN_MAX_THREADS; i++) {
        struct nxn_thread* t = g_threads[i];
        if (t && t->t.handle != self && R_SUCCEEDED(svcSetThreadActivity(t->t.handle, ThreadActivity_Paused))) n++;
    }
    return n;
}

static void trampoline(void* p) {
    struct nxn_thread* t = (struct nxn_thread*)p;
    t->fn(t->arg);
}

nxn_result nxn_thread_start(const nxn_thread_params* p, nxn_thread** out) {
    if (!p || !out || p->size < offsetof(nxn_thread_params, arg) + sizeof(void*) || !p->fn) return NXN_ERR_INVALID;
    int has_stack = p->size >= offsetof(nxn_thread_params, stack_size) + sizeof(uint32_t);
    int has_core = p->size >= offsetof(nxn_thread_params, core) + sizeof(int32_t);
    int has_name = p->size >= offsetof(nxn_thread_params, name) + sizeof(const char*);
    struct nxn_thread* t = (struct nxn_thread*)calloc(1, sizeof *t);
    if (!t) return NXN_ERR_NO_MEMORY;
    t->fn = p->fn;
    t->arg = p->arg;
    snprintf(t->name, sizeof t->name, "%s", has_name && p->name ? p->name : "worker");
    size_t stack = has_stack && p->stack_size ? p->stack_size : 256 * 1024;
    int core = has_core ? p->core : -2;
    if (core == 3 || core < -2 || core > 3) core = -2;
    Result rc = threadCreate(&t->t, trampoline, t, NULL, (stack + 0xFFF) & ~(size_t)0xFFF, 0x2C, core);
    if (R_FAILED(rc)) {
        free(t);
        nxn__set_error("threadCreate failed (0x%x)", rc);
        return NXN_ERR_SYSTEM;
    }
    mutexLock(&g_threads_lock);
    for (int i = 0; i < NXN_MAX_THREADS; i++)
        if (!g_threads[i]) {
            g_threads[i] = t;
            break;
        }
    mutexUnlock(&g_threads_lock);
    rc = threadStart(&t->t);
    if (R_FAILED(rc)) {
        nxn_thread_join(t);
        nxn__set_error("threadStart failed (0x%x)", rc);
        return NXN_ERR_SYSTEM;
    }
    *out = t;
    return NXN_OK;
}

nxn_result nxn_thread_join(nxn_thread* t) {
    if (!t) return NXN_ERR_INVALID;
    if (nxc_signal_poll) {
        /* compat linked: wait in slices so emulated signals reach this thread while it joins */
        while (R_FAILED(waitSingleHandle(t->t.handle, 10000000ull))) nxc_signal_poll();
    } else {
        threadWaitForExit(&t->t);
    }
    mutexLock(&g_threads_lock);
    for (int i = 0; i < NXN_MAX_THREADS; i++)
        if (g_threads[i] == t) g_threads[i] = NULL;
    mutexUnlock(&g_threads_lock);
    Result rc = threadClose(&t->t);
    if (R_FAILED(rc)) {
        /* libnx still lists the thread: the struct stays allocated (no dangling pointer), the teardown reports the
         * stack pages that stay locked */
        nxn_log(NXN_LOG_WARN, "thread %s: threadClose failed (0x%x)", t->name, rc);
        return NXN_ERR_SYSTEM;
    }
    free(t);
    return NXN_OK;
}

/* ---------------------------------------------------------------- logging */
static FILE* g_log;
static Mutex g_log_lock;

void nxn__log_open(void) {
    if (g_log || !g_nxn.log[0]) return;
    struct stat st;
    /* one launch per log, like Nexvyn OS's own app logs; a huge old log starts over */
    int fresh = stat(g_nxn.log, &st) != 0 || st.st_size > 512 * 1024;
    g_log = fopen(g_nxn.log, fresh ? "w" : "a");
}

void nxn__log_close(void) {
    mutexLock(&g_log_lock);
    if (g_log) fclose(g_log);
    g_log = NULL;
    mutexUnlock(&g_log_lock);
}

void nxn_log_write(nxn_log_level level, const char* message) {
    static const char kLevel[] = "DIWE";
    if (!message) return;
    time_t now = time(NULL);
    struct tm tmv;
    localtime_r(&now, &tmv);
    mutexLock(&g_log_lock);
    if (g_log) {
        fprintf(g_log, "[%02d:%02d:%02d] %c %s\n", tmv.tm_hour, tmv.tm_min, tmv.tm_sec,
                kLevel[(unsigned)level < 4 ? (unsigned)level : 1], message);
        fflush(g_log);
        /* commit to the card: the line must survive a crash or power-off right after it (debug lines skip this) */
        if (level >= NXN_LOG_INFO) fsync(fileno(g_log));
    }
    mutexUnlock(&g_log_lock);
}

void nxn_log(nxn_log_level level, const char* fmt, ...) {
    char buf[512];
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(buf, sizeof buf, fmt, ap);
    va_end(ap);
    nxn_log_write(level, buf);
}
