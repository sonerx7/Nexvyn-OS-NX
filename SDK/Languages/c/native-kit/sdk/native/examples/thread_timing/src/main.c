/* Thread Timing: how accurate are sleeps and timed waits, how fast is a wake-up, what does JIT write cost? See README.md.
 * Output: lines `THRT key=value ...` in the app log and in thread_timing.txt (app data folder); the last line is
 * `THRT END`. Every number is a measurement of this device, nothing here is a promise. */
#include <nexvyn/nexvyn_native.h>
#include <errno.h>
#include <pthread.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

/* svcWaitForAddress / svcSignalToAddress are host imports (sdk/native/toolchain/nxwin_imports.txt) and libnx's own
 * functions in a stand-alone NRO. No nxn_* header names them: libnx declares them in <switch/kernel/svc.h>
 * (devkitPro/libnx/include); the prototypes below are the same (Result = uint32_t). Firmware 4.0.0 or later. */
uint32_t svcWaitForAddress(void* address, uint32_t arb_type, int64_t value, int64_t timeout);
uint32_t svcSignalToAddress(void* address, uint32_t signal_type, int32_t value, int32_t count);
#define ARB_WAIT_IF_EQUAL 2u
#define SIGNAL_ONLY 0u
#define KERNEL_TIMED_OUT ((117u << 9) | 1u) /* libnx KernelError_TimedOut, kernel module 1 */

#define REPORT_FILE "thread_timing.txt"
#define SAMPLES 40

static char report[8192];
static size_t report_size;

static void marker(const char* format, ...) {
    char line[256];
    va_list args;
    va_start(args, format);
    int length = vsnprintf(line, sizeof line, format, args);
    va_end(args);
    if (length < 0 || (size_t)length >= sizeof line) return;
    nxn_log(NXN_LOG_INFO, "%s", line);
    if ((size_t)length + 1 <= sizeof report - report_size) {
        memcpy(report + report_size, line, (size_t)length);
        report_size += (size_t)length;
        report[report_size++] = '\n';
    }
}

static int cmp_u64(const void* a, const void* b) {
    uint64_t x = *(const uint64_t*)a, y = *(const uint64_t*)b;
    return x < y ? -1 : x > y;
}
static uint64_t pct(const uint64_t* v, int n, int p) { /* v sorted, p in 1..100 */
    int i = (n * p + 99) / 100;
    return v[i < 1 ? 0 : (i > n ? n - 1 : i - 1)];
}
/* One line: sorted samples in nanoseconds, printed as microseconds with one decimal. */
static void stat_line(const char* what, const char* tag, uint64_t req, uint64_t* v, int n) {
    qsort(v, (size_t)n, sizeof v[0], cmp_u64);
    uint64_t p50 = pct(v, n, 50), p95 = pct(v, n, 95), mx = v[n - 1];
    marker("THRT %s req=%llu n=%d %s_p50_us=%llu.%llu %s_p95_us=%llu.%llu %s_max_us=%llu.%llu", what,
           (unsigned long long)req, n, tag, (unsigned long long)(p50 / 1000), (unsigned long long)(p50 % 1000 / 100),
           tag, (unsigned long long)(p95 / 1000), (unsigned long long)(p95 % 1000 / 100), tag,
           (unsigned long long)(mx / 1000), (unsigned long long)(mx % 1000 / 100));
}

/* Requested durations in nanoseconds (100 us .. 10 ms). */
static const uint64_t REQ_NS[] = {100000, 250000, 500000, 1000000, 2000000, 5000000, 10000000};
#define NREQ ((int)(sizeof REQ_NS / sizeof REQ_NS[0]))

static void time_resolution(void) {
    uint64_t calls[1000], diffs[1000];
    uint64_t t0 = nxn_time_ns();
    for (int i = 0; i < 1000; ++i) calls[i] = nxn_time_ns();
    uint64_t t1 = nxn_time_ns();
    int nd = 0;
    for (int i = 1; i < 1000; ++i)
        if (calls[i] > calls[i - 1]) diffs[nd++] = calls[i] - calls[i - 1];
    uint64_t smallest = 0;
    if (nd) {
        qsort(diffs, (size_t)nd, sizeof diffs[0], cmp_u64);
        smallest = diffs[0];
    }
    marker("THRT time_ns smallest_step_ns=%llu call_cost_ns=%llu distinct_steps=%d", (unsigned long long)smallest,
           (unsigned long long)((t1 - t0) / 1000), nd);
}

static void cpu_report(void) {
    nxn_cpu_info c = NXN_STRUCT_INIT(nxn_cpu_info);
    nxn_result rc = nxn_cpu_info_get(&c);
    if (rc != NXN_OK) {
        marker("THRT cpu rc=%d", rc);
        return;
    }
    marker("THRT cpu features=0x%x flags=0x%x part=0x%x cores=%u process_mask=0x%x worker_mask=0x%x core=%u", c.features,
           c.flags, c.part, c.core_count, c.process_core_mask, c.worker_core_mask, c.current_core);
    marker("THRT cache dline=%u iline=%u cwg=%u ctr=0x%x", c.dcache_line, c.icache_line, c.cache_writeback_granule,
           c.ctr_el0);
}

static void sleep_report(void) {
    for (int r = 0; r < NREQ; ++r) {
        uint64_t over[SAMPLES];
        for (int i = 0; i < SAMPLES; ++i) {
            uint64_t t0 = nxn_time_ns();
            nxn_sleep_ns(REQ_NS[r]);
            uint64_t d = nxn_time_ns() - t0;
            over[i] = d > REQ_NS[r] ? d - REQ_NS[r] : 0;
        }
        stat_line("sleep", "over", REQ_NS[r], over, SAMPLES);
    }
}

/* Clock for pthread_cond_timedwait: monotonic when the C library takes it, else the realtime default. */
static clockid_t g_cond_clock = CLOCK_REALTIME;
static pthread_cond_t g_cond;
static pthread_mutex_t g_mu = PTHREAD_MUTEX_INITIALIZER;

static int abs_after(struct timespec* ts, uint64_t ns) {
    if (clock_gettime(g_cond_clock, ts) != 0) return errno;
    uint64_t total = (uint64_t)ts->tv_nsec + ns;
    ts->tv_sec += (time_t)(total / 1000000000ull);
    ts->tv_nsec = (long)(total % 1000000000ull);
    return 0;
}

static int condvar_init(void) {
    pthread_condattr_t attr;
    int rc = pthread_condattr_init(&attr);
    if (rc != 0) return rc;
    if (pthread_condattr_setclock(&attr, CLOCK_MONOTONIC) == 0) g_cond_clock = CLOCK_MONOTONIC;
    rc = pthread_cond_init(&g_cond, &attr);
    pthread_condattr_destroy(&attr);
    return rc;
}

static void condvar_report(void) {
    marker("THRT condvar clock=%s", g_cond_clock == CLOCK_MONOTONIC ? "monotonic" : "realtime");
    for (int r = 0; r < NREQ; ++r) {
        uint64_t over[SAMPLES];
        int timedout = 0;
        for (int i = 0; i < SAMPLES; ++i) {
            struct timespec ts;
            pthread_mutex_lock(&g_mu);
            uint64_t t0 = nxn_time_ns();
            int rc = abs_after(&ts, REQ_NS[r]);
            if (rc == 0) rc = pthread_cond_timedwait(&g_cond, &g_mu, &ts);
            uint64_t d = nxn_time_ns() - t0;
            pthread_mutex_unlock(&g_mu);
            if (rc == ETIMEDOUT) {
                over[timedout++] = d > REQ_NS[r] ? d - REQ_NS[r] : 0;
            } else if (rc != 0) {
                marker("THRT condvar rc=%d", rc);
                return;
            }
        }
        marker("THRT condvar_rc req=%llu timedout=%d of=%d", (unsigned long long)REQ_NS[r], timedout, SAMPLES);
        if (timedout) stat_line("condvar", "over", REQ_NS[r], over, timedout);
    }
}

static int waitaddr_report(void) {
    static volatile int32_t word;
    unsigned probe_rc = svcWaitForAddress((void*)&word, ARB_WAIT_IF_EQUAL, 0, 1000000);
    marker("THRT waitaddr probe_rc=0x%x", probe_rc);
    if (probe_rc != KERNEL_TIMED_OUT) return 0;
    for (int r = 0; r < NREQ; ++r) {
        uint64_t over[SAMPLES];
        for (int i = 0; i < SAMPLES; ++i) {
            word = 0;
            uint64_t t0 = nxn_time_ns();
            uint32_t rc = svcWaitForAddress((void*)&word, ARB_WAIT_IF_EQUAL, 0, (int64_t)REQ_NS[r]);
            uint64_t d = nxn_time_ns() - t0;
            if (rc != KERNEL_TIMED_OUT) {
                marker("THRT waitaddr rc=0x%x", rc);
                return 0;
            }
            over[i] = d > REQ_NS[r] ? d - REQ_NS[r] : 0;
        }
        stat_line("waitaddr", "over", REQ_NS[r], over, SAMPLES);
    }
    return 1;
}

/* Wake-up latency: a worker thread signals after about 1 ms and stamps the time just before; main stamps on return. */
static volatile int32_t g_wake_word;
static volatile uint64_t g_signal_ns;
static int g_use_cond;
static volatile int g_worker_go;

static void wake_worker(void* arg) {
    (void)arg;
    for (int i = 0; i < SAMPLES && !nxn_should_quit(); ++i) {
        while (!__atomic_load_n(&g_worker_go, __ATOMIC_ACQUIRE)) {
            if (nxn_should_quit()) return;
            nxn_sleep_ns(50000);
        }
        nxn_sleep_ns(1000000);
        if (g_use_cond) {
            pthread_mutex_lock(&g_mu);
            g_signal_ns = nxn_time_ns();
            g_wake_word = 1;
            pthread_cond_signal(&g_cond);
            pthread_mutex_unlock(&g_mu);
        } else {
            g_signal_ns = nxn_time_ns();
            __atomic_store_n(&g_wake_word, 1, __ATOMIC_RELEASE);
            svcSignalToAddress((void*)&g_wake_word, SIGNAL_ONLY, 0, 1);
        }
        __atomic_store_n(&g_worker_go, 0, __ATOMIC_RELEASE);
    }
}

static void wake_report(int use_cond) {
    uint64_t lat[SAMPLES];
    int n = 0;
    const char* kind = use_cond ? "condvar" : "waitaddr";
    g_use_cond = use_cond;
    g_worker_go = 0;
    nxn_thread_params p = NXN_STRUCT_INIT(nxn_thread_params);
    p.fn = wake_worker;
    p.name = "thrt-wake";
    nxn_thread* th = NULL;
    nxn_result rc = nxn_thread_start(&p, &th);
    if (rc != NXN_OK) {
        marker("THRT wake kind=%s rc=%d", kind, rc);
        return;
    }
    for (int i = 0; i < SAMPLES && !nxn_should_quit(); ++i) {
        g_wake_word = 0;
        __atomic_store_n(&g_worker_go, 1, __ATOMIC_RELEASE);
        uint64_t woke;
        if (use_cond) {
            struct timespec ts;
            pthread_mutex_lock(&g_mu);
            if (abs_after(&ts, 50000000ull) == 0) {
                while (!g_wake_word && pthread_cond_timedwait(&g_cond, &g_mu, &ts) == 0) {}
            }
            woke = nxn_time_ns();
            pthread_mutex_unlock(&g_mu);
        } else {
            if (!__atomic_load_n(&g_wake_word, __ATOMIC_ACQUIRE))
                svcWaitForAddress((void*)&g_wake_word, ARB_WAIT_IF_EQUAL, 0, 50000000);
            woke = nxn_time_ns();
        }
        while (__atomic_load_n(&g_worker_go, __ATOMIC_ACQUIRE) && !nxn_should_quit()) nxn_sleep_ns(50000);
        if (nxn_should_quit()) break;
        if (g_wake_word && woke >= g_signal_ns) lat[n++] = woke - g_signal_ns;
    }
    nxn_thread_join(th);
    if (n) {
        stat_line(use_cond ? "wake_condvar" : "wake_waitaddr", "latency", 1000000, lat, n);
    } else {
        marker("THRT wake kind=%s n=0", kind);
    }
}

/* JIT W^X cost (needs setting native.windowedJit in Nexvyn OS; off: reports unsupported). */
static void jit_report(void) {
    nxn_jit* j = NULL;
    nxn_result rc = nxn_jit_create(1u << 20, &j);
    if (rc != NXN_OK) {
        marker("THRT jit status=%s rc=%d", rc == NXN_ERR_UNSUPPORTED ? "unsupported" : "failed", rc);
        return;
    }
    nxn_jit_info in = NXN_STRUCT_INIT(nxn_jit_info);
    rc = nxn_jit_get(j, &in);
    if (rc != NXN_OK) {
        marker("THRT jit stage=get rc=%d", rc);
        nxn_jit_destroy(j);
        return;
    }
    static const uint32_t sizes[] = {4096, 65536, 1u << 20};
    for (int s = 0; s < 3; ++s) {
        uint64_t begin[SAMPLES], end[SAMPLES], total[SAMPLES];
        uint32_t words = sizes[s] / 4;
        for (int i = 0; i < SAMPLES; ++i) {
            uint64_t t0 = nxn_time_ns();
            rc = nxn_jit_begin_write(j);
            uint64_t t1 = nxn_time_ns();
            if (rc != NXN_OK) {
                marker("THRT jit stage=begin_write bytes=%u rc=%d", sizes[s], rc);
                nxn_jit_destroy(j);
                return;
            }
            uint32_t* code = (uint32_t*)in.rw;
            for (uint32_t w = 0; w + 1 < words; ++w) code[w] = 0xD503201Fu; /* nop */
            code[words - 1] = 0xD65F03C0u;                                   /* ret */
            uint64_t t2 = nxn_time_ns();
            rc = nxn_jit_end_write(j, 0, sizes[s]);
            uint64_t t3 = nxn_time_ns();
            if (rc != NXN_OK) {
                marker("THRT jit stage=end_write bytes=%u rc=%d", sizes[s], rc);
                nxn_jit_destroy(j);
                return;
            }
            begin[i] = t1 - t0;
            end[i] = t3 - t2;
            total[i] = t3 - t0;
        }
        ((void (*)(void))in.rx)(); /* runs the nops and returns: the code is really executable */
        marker("THRT jit bytes=%u ran=1", sizes[s]);
        stat_line("jit_begin_write", "t", sizes[s], begin, SAMPLES);
        stat_line("jit_end_write", "t", sizes[s], end, SAMPLES);
        stat_line("jit_write_cycle", "t", sizes[s], total, SAMPLES);
    }
    nxn_jit_destroy(j);
}

static int app_main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    marker("THRT START version=1");
    cpu_report();
    time_resolution();
    sleep_report();
    int cond_rc = condvar_init();
    if (cond_rc == 0) {
        condvar_report();
        wake_report(1);
        pthread_cond_destroy(&g_cond);
    } else {
        marker("THRT condvar stage=init rc=%d", cond_rc);
    }
    if (waitaddr_report()) wake_report(0);
    jit_report();
    marker("THRT END");
    nxn_result rc = nxn_fs_write(NXN_DIR_DATA, REPORT_FILE, report, report_size);
    if (rc != NXN_OK) nxn_log(NXN_LOG_ERROR, "Thread timing report write failed rc=%d", rc);
    return rc != NXN_OK;
}

int main(int argc, char** argv) {
    nxn_init_params params = NXN_STRUCT_INIT(nxn_init_params);
    params.standalone_id = "com.nexvyn.example.threadtiming";
    return nxn_run(argc, argv, app_main, &params);
}
