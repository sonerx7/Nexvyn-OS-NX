/* pacing_demo: measures present-to-present time at swap interval 1 and 2 (nxn_display_set_interval,
 * nxn_display_last_present_ns). Draws a cleared, moving-colour frame; no shaders, so the numbers are pacing, not GPU.
 * Output (app log and pacing_demo.txt in the data folder), one marker per line:
 *   PACE interval=1 frames=N p50_ms=16.7 p95_ms=17.2 ...
 *   PACE status=COMPLETE
 *   PACE END */
#include <nexvyn/nexvyn_native.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <GL/glcorearb.h>

#define APP_ID "com.nexvyn.example.pacingdemo"
#define RESULT "pacing_demo.txt"
#define FRAMES 180   /* measured frames per interval */
#define WARMUP 20    /* frames ignored after a change of interval */

static PFNGLCLEARCOLORPROC glClearColor_;
static PFNGLCLEARPROC glClear_;

static char report[2048];
static size_t report_size;

static void marker(const char* line) {
    nxn_log(NXN_LOG_INFO, "%s", line);
    size_t n = strlen(line);
    if (n + 1 <= sizeof report - report_size) {
        memcpy(report + report_size, line, n);
        report_size += n;
        report[report_size++] = '\n';
    }
}

static int cmp_u64(const void* a, const void* b) {
    uint64_t x = *(const uint64_t*)a, y = *(const uint64_t*)b;
    return x < y ? -1 : x > y;
}

/* Run one interval with a fixed warmup and sample budget. Only new compositor handoffs count. */
static int run_interval(nxn_display* display, uint32_t interval, uint64_t* deltas) {
    if (nxn_display_set_interval(display, interval) != NXN_OK) return -1;
    uint64_t prev = 0, now = 0;
    int measured = 0;
    uint32_t width = 0, height = 0;
    for (int i = 0; i < WARMUP + FRAMES && !nxn_should_quit(); ++i) {
        nxn_event event = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&event) > 0) {
            if (event.type == NXN_EVENT_RESIZE) {
                width = event.width;
                height = event.height;
            }
            event.size = sizeof event;
        }
        if (width && height && nxn_display_resize(display, width, height) != NXN_ERR_BUSY) {
            width = height = 0;
        }
        float t = (float)i / 60.0f;
        glClearColor_(0.2f + 0.2f * (t - (int)t), 0.3f, 0.5f, 1.0f);
        glClear_(GL_COLOR_BUFFER_BIT);
        if (nxn_display_swap(display) != NXN_OK) continue; /* a dropped frame is not a present */
        if (nxn_display_last_present_ns(display, &now) != NXN_OK) return -1;
        if (i >= WARMUP && prev && now > prev) deltas[measured++] = now - prev;
        prev = now;
    }
    return measured;
}

static void report_interval(uint32_t interval, uint64_t* deltas, int n) {
    char line[200];
    if (n < 2) {
        snprintf(line, sizeof line, "PACE interval=%u frames=%d status=FAIL", interval, n);
        marker(line);
        return;
    }
    qsort(deltas, (size_t)n, sizeof *deltas, cmp_u64);
    double p50 = (double)deltas[(n + 1) / 2 - 1] / 1e6;
    double p95 = (double)deltas[(n * 95 + 99) / 100 - 1] / 1e6;
    double max = (double)deltas[n - 1] / 1e6;
    snprintf(line, sizeof line, "PACE interval=%u frames=%d p50_ms=%.2f p95_ms=%.2f max_ms=%.2f fps=%.1f", interval, n, p50,
             p95, max, p50 > 0 ? 1000.0 / p50 : 0.0);
    marker(line);
}

static int app_main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    nxn_display* display = NULL;
    nxn_display_params params = NXN_STRUCT_INIT(nxn_display_params);
    params.api = NXN_GFX_GL_CORE;
    if (nxn_display_open(&params, &display) != NXN_OK || !display) {
        marker("PACE status=FAIL reason=display_open");
        marker("PACE END");
        return 1;
    }
    glClearColor_ = (PFNGLCLEARCOLORPROC)nxn_display_proc("glClearColor");
    glClear_ = (PFNGLCLEARPROC)nxn_display_proc("glClear");
    int ok = glClearColor_ && glClear_;
    static uint64_t deltas[FRAMES];
    for (uint32_t interval = 1; ok && interval <= 2; ++interval) {
        int n = run_interval(display, interval, deltas);
        report_interval(interval, deltas, n);
        if (n < 2) ok = 0;
    }
    nxn_display_close(display);
    marker(ok ? "PACE status=COMPLETE" : "PACE status=FAIL");
    marker("PACE END");
    nxn_fs_write(NXN_DIR_DATA, RESULT, report, report_size);
    return !ok;
}

int main(int argc, char** argv) {
    nxn_init_params params = NXN_STRUCT_INIT(nxn_init_params);
    params.standalone_id = APP_ID;
    return nxn_run(argc, argv, app_main, &params);
}
