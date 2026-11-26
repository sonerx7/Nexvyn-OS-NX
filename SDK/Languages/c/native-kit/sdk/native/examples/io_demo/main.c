/* N6 P5 IO demo: exercises per-pad motion/sticks/rumble, audio stream stats,
 * nxn_stream_cancel and nxn_thread_cpu_ns in both windowed and standalone builds.
 * Logs `IOD key=value` lines and a final `IOD END`, and writes io_demo_report.txt. */
#include <nexvyn/nexvyn_native.h>
#include <math.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define APP_ID "com.nexvyn.example.iodemo"
#define REPORT_FILE "io_demo_report.txt"
#define STREAM_FILE "io_demo_stream.bin"

typedef void (*clear_color_fn)(float, float, float, float);
typedef void (*clear_fn)(unsigned);

static char g_report[4096];
static size_t g_report_len;

static void iod_log(const char* line) {
    nxn_log(NXN_LOG_INFO, "%s", line);
    size_t n = strlen(line);
    if (n + 1 <= sizeof g_report - g_report_len) {
        memcpy(g_report + g_report_len, line, n);
        g_report_len += n;
        g_report[g_report_len++] = '\n';
    }
}

static void iod_fmt(const char* fmt, ...) __attribute__((format(printf, 1, 2)));
static void iod_fmt(const char* fmt, ...) {
    char line[384];
    va_list ap;
    va_start(ap, fmt);
    int n = vsnprintf(line, sizeof line, fmt, ap);
    va_end(ap);
    if (n > 0 && (size_t)n < sizeof line) iod_log(line);
}

static void test_cpu_time(void) {
    uint64_t t0 = nxn_thread_cpu_ns();
    volatile uint64_t acc = 0;
    for (uint32_t i = 1; i <= 250000u; ++i) acc += i * 3u;
    (void)acc;
    uint64_t t1 = nxn_thread_cpu_ns();
    uint64_t delta = t1 >= t0 ? t1 - t0 : 0;
    iod_fmt("IOD probe=cpu before=%llu after=%llu delta_ns=%llu",
            (unsigned long long)t0, (unsigned long long)t1, (unsigned long long)delta);
}

static void test_audio_stats(void) {
    nxn_audio_params ap = NXN_STRUCT_INIT(nxn_audio_params);
    ap.rate = 48000;
    ap.channels = 2;
    ap.format = NXN_AUDIO_S16;
    ap.frames = 1024;

    nxn_audio* au = NULL;
    nxn_result open_rc = nxn_audio_open(&ap, &au);
    if (open_rc != NXN_OK || !au) {
        iod_fmt("IOD probe=audio open_rc=%d stats_rc=%d underruns=0 mixer_reads=0 queued_frames=0 latency_ns=0",
                (int)open_rc, (int)NXN_ERR_NOT_READY);
        return;
    }

    int16_t pcm[1024 * 2];
    for (int i = 0; i < 1024; ++i) {
        int16_t s = (int16_t)(sinf((float)i * 2.f * 3.14159265f * 440.f / 48000.f) * 2400.f);
        pcm[i * 2] = s;
        pcm[i * 2 + 1] = s;
    }
    nxn_result queue_rc = nxn_audio_queue(au, pcm, sizeof pcm);
    nxn_result pause_rc = nxn_audio_pause(au, 0);
    nxn_sleep_ns(35000000ull);

    nxn_audio_stats stats = NXN_STRUCT_INIT(nxn_audio_stats);
    nxn_result stats_rc = nxn_audio_stats_get(au, &stats);
    iod_fmt("IOD probe=audio open_rc=%d queue_rc=%d pause_rc=%d stats_rc=%d underruns=%llu mixer_reads=%llu queued_frames=%u latency_ns=%llu",
            (int)open_rc, (int)queue_rc, (int)pause_rc, (int)stats_rc,
            (unsigned long long)stats.underruns, (unsigned long long)stats.mixer_reads,
            stats.queued_frames, (unsigned long long)stats.latency_ns);

    nxn_audio_clear(au);
    nxn_audio_close(au);
}

static void test_stream_cancel(void) {
    static uint8_t data[256 * 1024];
    for (size_t i = 0; i < sizeof data; ++i) data[i] = (uint8_t)(i & 0xFFu);
    nxn_result write_rc = nxn_fs_write(NXN_DIR_DATA, STREAM_FILE, data, sizeof data);
    if (write_rc != NXN_OK) {
        iod_fmt("IOD probe=stream write_rc=%d open_rc=%d cancel_rc=%d cancelled=0 read_rc=%d got=0",
                (int)write_rc, (int)NXN_ERR_IO, (int)NXN_ERR_IO, (int)NXN_ERR_IO);
        return;
    }

    nxn_stream* st = NULL;
    uint64_t total = 0;
    nxn_result open_rc = nxn_stream_open(NXN_DIR_DATA, STREAM_FILE, &st, &total);
    if (open_rc != NXN_OK || !st) {
        iod_fmt("IOD probe=stream write_rc=%d open_rc=%d cancel_rc=%d cancelled=0 read_rc=%d got=0",
                (int)write_rc, (int)open_rc, (int)NXN_ERR_NOT_READY, (int)NXN_ERR_NOT_READY);
        return;
    }

    nxn_result pre_rc = nxn_stream_prefetch(st, 0, total);
    uint64_t cancelled = 0;
    nxn_result cancel_rc = nxn_stream_cancel(st, 65536ull, total > 65536ull ? total - 65536ull : 0, &cancelled);

    uint8_t buf[64];
    uint64_t got = 0;
    nxn_result read_rc = nxn_stream_read(st, 0, buf, sizeof buf, 0, &got);
    int match = (read_rc == NXN_OK && got == sizeof buf && memcmp(buf, data, sizeof buf) == 0);
    iod_fmt("IOD probe=stream write_rc=%d open_rc=%d prefetch_rc=%d cancel_rc=%d cancelled=%llu read_rc=%d got=%llu match=%d",
            (int)write_rc, (int)open_rc, (int)pre_rc, (int)cancel_rc,
            (unsigned long long)cancelled, (int)read_rc, (unsigned long long)got, match);

    nxn_stream_close(st);
}

static void test_pads_and_motion(nxn_display* disp, clear_color_fn clear_color, clear_fn clear) {
    nxn_pad_sticks sticks = NXN_STRUCT_INIT(nxn_pad_sticks);
    nxn_result bad_pad_rc = nxn_input_pad_sticks(8, &sticks);

    nxn_pad_rumble bad_rumble = NXN_STRUCT_INIT(nxn_pad_rumble);
    bad_rumble.low_amp = NAN;
    nxn_result nan_rumble_rc = nxn_rumble_pad(0, &bad_rumble);

    int pad_count = nxn_input_pad_count();
    iod_fmt("IOD probe=pad count=%d bad_pad_rc=%d nan_rumble_rc=%d", pad_count, (int)bad_pad_rc, (int)nan_rumble_rc);

    nxn_pad_motion motion = NXN_STRUCT_INIT(nxn_pad_motion);
    nxn_result sticks_rc = NXN_ERR_NOT_FOUND;
    nxn_result motion_rc = NXN_ERR_NOT_FOUND;
    for (int frame = 0; frame < 6 && !nxn_should_quit(); ++frame) {
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {
            if (ev.type == NXN_EVENT_RESIZE && disp) nxn_display_resize(disp, ev.width, ev.height);
            ev.size = sizeof ev;
        }
        nxn_pad_state p0 = NXN_STRUCT_INIT(nxn_pad_state);
        nxn_input_pad_poll(0, &p0);
        sticks = (nxn_pad_sticks)NXN_STRUCT_INIT(nxn_pad_sticks);
        sticks_rc = nxn_input_pad_sticks(0, &sticks);
        motion = (nxn_pad_motion)NXN_STRUCT_INIT(nxn_pad_motion);
        motion_rc = nxn_input_pad_motion(0, &motion);
        if (clear_color && clear) {
            clear_color(0.10f, 0.14f, 0.22f, 1.0f);
            clear(0x4000);
        }
        if (disp) nxn_display_swap(disp);
        else nxn_sleep_ns(16000000ull);
    }

    iod_fmt("IOD probe=sticks pad=0 rc=%d lx=%.3f ly=%.3f rx=%.3f ry=%.3f",
            (int)sticks_rc, sticks.lx, sticks.ly, sticks.rx, sticks.ry);
    iod_fmt("IOD probe=motion pad=0 rc=%d valid=%u sample=%llu ts=%llu ax=%.3f ay=%.3f az=%.3f gx=%.3f gy=%.3f gz=%.3f",
            (int)motion_rc, motion.valid, (unsigned long long)motion.sample_number,
            (unsigned long long)motion.timestamp_ns,
            motion.accel[0], motion.accel[1], motion.accel[2],
            motion.gyro[0], motion.gyro[1], motion.gyro[2]);

    nxn_pad_rumble rumble = NXN_STRUCT_INIT(nxn_pad_rumble);
    rumble.duration_ms = 60;
    rumble.low_amp = 0.25f;
    rumble.low_freq_hz = 160.f;
    rumble.high_amp = 0.15f;
    rumble.high_freq_hz = 320.f;
    nxn_result rumble_rc = nxn_rumble_pad(0, &rumble);
    nxn_sleep_ns(20000000ull);
    rumble.low_amp = 0.f;
    rumble.high_amp = 0.f;
    nxn_result stop_rc = nxn_rumble_pad(0, &rumble);
    iod_fmt("IOD probe=rumble pad=0 start_rc=%d stop_rc=%d", (int)rumble_rc, (int)stop_rc);
}

static int app_main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    nxn_result caps_rc = nxn_caps_get(&caps);
    iod_fmt("IOD probe=caps rc=%d abi=%u native=%u.%u features=0x%llx",
            (int)caps_rc, caps.abi_gen, caps.version_major, caps.version_minor,
            (unsigned long long)caps.features);

    nxn_display* disp = NULL;
    clear_color_fn clear_color = NULL;
    clear_fn clear = NULL;
    nxn_result disp_rc = nxn_display_open(NULL, &disp);
    if (disp_rc == NXN_OK && disp) {
        clear_color = (clear_color_fn)nxn_display_proc("glClearColor");
        clear = (clear_fn)nxn_display_proc("glClear");
    }

    test_cpu_time();
    test_pads_and_motion(disp, clear_color, clear);
    test_audio_stats();
    test_stream_cancel();

    iod_log("IOD END");
    nxn_fs_write(NXN_DIR_DATA, REPORT_FILE, g_report, g_report_len);
    if (disp) nxn_display_close(disp);
    return 0;
}

int main(int argc, char** argv) {
    nxn_init_params params = NXN_STRUCT_INIT(nxn_init_params);
    params.standalone_id = APP_ID;
    return nxn_run(argc, argv, app_main, &params);
}
