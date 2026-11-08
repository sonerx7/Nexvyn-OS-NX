// Sysroot proof for the Nexvyn native SDK: every library of the overlay sysroot is called once.
// Writes sdmc:/sysroot_test_results.txt (one line per library, then "RESULT pass=N fail=M") and exits with M as the
// return code. Libraries that were not built are compiled out (HAVE_<NAME> comes from CMakeLists.txt) and listed as SKIP.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <switch.h>

#ifdef HAVE_ZSTD
#include <zstd.h>
#endif
#ifdef HAVE_LZ4
#include <lz4.h>
#endif
#ifdef HAVE_SQLITE3
#include <sqlite3.h>
#endif
#ifdef HAVE_ARCHIVE
#include <archive.h>
#include <archive_entry.h>
#endif
#ifdef HAVE_OPENAL
#include <SDL2/SDL.h>
#include <AL/al.h>
#include <AL/alc.h>
#endif
#ifdef HAVE_ICONV
#include <iconv.h>
#endif
#ifdef HAVE_PIXMAN_1
#include <pixman.h>
#endif
#ifdef HAVE_GLIB_2_0
#include <glib.h>
#endif

static FILE *g_out;
static int g_pass, g_fail;

static void report(const char *lib, int ok, const char *detail)
{
    printf("%-10s %s  %s\n", lib, ok ? "PASS" : "FAIL", detail);
    if (g_out)
        fprintf(g_out, "%s %s %s\n", lib, ok ? "PASS" : "FAIL", detail);
    if (ok)
        g_pass++;
    else
        g_fail++;
}

static void skip(const char *lib)
{
    printf("%-10s SKIP  not built\n", lib);
    if (g_out)
        fprintf(g_out, "%s SKIP not built\n", lib);
}

#define SAMPLE_LEN 4096
static char g_sample[SAMPLE_LEN];

static void make_sample(void)
{
    for (int i = 0; i < SAMPLE_LEN; i++)
        g_sample[i] = (char)('a' + (i * 7 + i / 13) % 17);
}

#ifdef HAVE_ZSTD
static void test_zstd(void)
{
    char comp[8192], back[SAMPLE_LEN];
    size_t c = ZSTD_compress(comp, sizeof comp, g_sample, SAMPLE_LEN, 3);
    size_t d = ZSTD_isError(c) ? 0 : ZSTD_decompress(back, sizeof back, comp, c);
    char msg[96];
    snprintf(msg, sizeof msg, "zstd %s %u -> %u bytes", ZSTD_versionString(), SAMPLE_LEN, (unsigned)c);
    report("zstd", !ZSTD_isError(c) && d == SAMPLE_LEN && memcmp(back, g_sample, SAMPLE_LEN) == 0, msg);
}
#endif

#ifdef HAVE_LZ4
static void test_lz4(void)
{
    char comp[8192], back[SAMPLE_LEN];
    int c = LZ4_compress_default(g_sample, comp, SAMPLE_LEN, sizeof comp);
    int d = c > 0 ? LZ4_decompress_safe(comp, back, c, sizeof back) : -1;
    char msg[96];
    snprintf(msg, sizeof msg, "lz4 %s %u -> %d bytes", LZ4_versionString(), SAMPLE_LEN, c);
    report("lz4", c > 0 && d == SAMPLE_LEN && memcmp(back, g_sample, SAMPLE_LEN) == 0, msg);
}
#endif

#ifdef HAVE_SQLITE3
static void test_sqlite(void)
{
    sqlite3 *db = NULL;
    sqlite3_stmt *st = NULL;
    long long sum = -1;
    int ok = 0;
    if (sqlite3_open(":memory:", &db) == SQLITE_OK &&
        sqlite3_exec(db, "CREATE TABLE t(a INTEGER, b TEXT);"
                         "INSERT INTO t VALUES (1,'x'),(2,'y'),(39,'z');", NULL, NULL, NULL) == SQLITE_OK &&
        sqlite3_prepare_v2(db, "SELECT SUM(a) FROM t WHERE b <> 'q'", -1, &st, NULL) == SQLITE_OK &&
        sqlite3_step(st) == SQLITE_ROW) {
        sum = sqlite3_column_int64(st, 0);
        ok = sum == 42;
    }
    sqlite3_finalize(st);
    sqlite3_close(db);
    char msg[96];
    snprintf(msg, sizeof msg, "sqlite %s in-memory SUM=%lld", sqlite3_libversion(), sum);
    report("sqlite", ok, msg);
}
#endif

#ifdef HAVE_ARCHIVE
static int test_archive_roundtrip(int zip, char *msg, size_t msgsz)
{
    static char buf[16384];
    size_t used = 0;
    const char *payload = "hello from libarchive";
    struct archive *w = archive_write_new();
    if (zip) {
        archive_write_set_format_zip(w);
    } else {
        archive_write_set_format_pax_restricted(w);
        archive_write_add_filter_zstd(w);
    }
    if (archive_write_open_memory(w, buf, sizeof buf, &used) != ARCHIVE_OK) {
        snprintf(msg, msgsz, "write open: %s", archive_error_string(w));
        return 0;
    }
    struct archive_entry *e = archive_entry_new();
    archive_entry_set_pathname(e, "dir/a.txt");
    archive_entry_set_size(e, (la_int64_t)strlen(payload));
    archive_entry_set_filetype(e, AE_IFREG);
    archive_entry_set_perm(e, 0644);
    archive_write_header(w, e);
    archive_write_data(w, payload, strlen(payload));
    archive_entry_free(e);
    archive_write_close(w);
    archive_write_free(w);

    struct archive *r = archive_read_new();
    archive_read_support_format_zip(r);
    archive_read_support_format_tar(r);
    archive_read_support_filter_all(r);
    int ok = 0;
    if (archive_read_open_memory(r, buf, used) == ARCHIVE_OK) {
        struct archive_entry *re;
        char back[64] = {0};
        if (archive_read_next_header(r, &re) == ARCHIVE_OK && strcmp(archive_entry_pathname(re), "dir/a.txt") == 0) {
            la_ssize_t n = archive_read_data(r, back, sizeof back - 1);
            ok = n == (la_ssize_t)strlen(payload) && strcmp(back, payload) == 0;
        }
    }
    snprintf(msg, msgsz, "%s %u bytes, read back %s", zip ? "zip" : "tar.zst", (unsigned)used, ok ? "ok" : "BAD");
    archive_read_free(r);
    return ok;
}

static void test_archive(void)
{
    char m1[64], m2[64], msg[160];
    int a = test_archive_roundtrip(1, m1, sizeof m1);
    int b = test_archive_roundtrip(0, m2, sizeof m2);
    snprintf(msg, sizeof msg, "%s; %s; %s", archive_version_string(), m1, m2);
    report("libarchive", a && b, msg);
}
#endif

#ifdef HAVE_OPENAL
static void test_openal(void)
{
    char msg[160];
    int ok = 0;
    if (SDL_Init(SDL_INIT_AUDIO) != 0) {
        snprintf(msg, sizeof msg, "SDL_Init audio: %s", SDL_GetError());
        report("openal", 0, msg);
        return;
    }
    setenv("ALSOFT_DRIVERS", "sdl2", 1); // only the SDL2 backend: a silent fall back to the null backend must fail the test
    ALCdevice *dev = alcOpenDevice(NULL);
    ALCcontext *ctx = dev ? alcCreateContext(dev, NULL) : NULL;
    if (ctx && alcMakeContextCurrent(ctx)) {
        ALuint buf = 0, src = 0;
        short pcm[480];
        for (int i = 0; i < 480; i++)
            pcm[i] = (short)((i % 48) < 24 ? 8000 : -8000);
        alGenBuffers(1, &buf);
        alBufferData(buf, AL_FORMAT_MONO16, pcm, sizeof pcm, 48000);
        alGenSources(1, &src);
        alSourcei(src, AL_BUFFER, (ALint)buf);
        alSourcef(src, AL_GAIN, 0.0f); // silent: the test only proves the device, context and a queued buffer
        alSourcePlay(src);
        ALint state = 0;
        alGetSourcei(src, AL_SOURCE_STATE, &state);
        ok = alGetError() == AL_NO_ERROR && (state == AL_PLAYING || state == AL_STOPPED);
        snprintf(msg, sizeof msg, "%s device=\"%s\" state=%d", alGetString(AL_VERSION),
                 alcGetString(dev, ALC_DEVICE_SPECIFIER), (int)state);
        alDeleteSources(1, &src);
        alDeleteBuffers(1, &buf);
        alcMakeContextCurrent(NULL);
    } else {
        snprintf(msg, sizeof msg, "no device/context (alc error %d)", dev ? (int)alcGetError(dev) : -1);
    }
    if (ctx)
        alcDestroyContext(ctx);
    if (dev)
        alcCloseDevice(dev);
    SDL_Quit();
    report("openal", ok, msg);
}
#endif

#ifdef HAVE_ICONV
static void test_iconv(void)
{
    char msg[128];
    int ok = 0;
    // "h\xc3\xa9llo" (UTF-8) -> UTF-16LE: 68 00 e9 00 6c 00 6c 00 6f 00
    const unsigned char want[] = {0x68, 0, 0xe9, 0, 0x6c, 0, 0x6c, 0, 0x6f, 0};
    char in[] = "h\xc3\xa9llo";
    char out[32];
    char *ip = in, *op = out;
    size_t il = strlen(in), ol = sizeof out;
    iconv_t cd = iconv_open("UTF-16LE", "UTF-8");
    if (cd != (iconv_t)-1) {
        size_t r = iconv(cd, &ip, &il, &op, &ol);
        size_t n = sizeof out - ol;
        ok = r != (size_t)-1 && n == sizeof want && memcmp(out, want, n) == 0;
        iconv_close(cd);
        // latin1 (0xE9) -> UTF-8 (c3 a9)
        char l1[] = "\xe9";
        char u8[8];
        char *p1 = l1, *p2 = u8;
        size_t i1 = 1, o1 = sizeof u8;
        iconv_t c2 = iconv_open("UTF-8", "ISO-8859-1");
        if (c2 != (iconv_t)-1) {
            iconv(c2, &p1, &i1, &p2, &o1);
            ok = ok && (sizeof u8 - o1) == 2 && (unsigned char)u8[0] == 0xc3 && (unsigned char)u8[1] == 0xa9;
            iconv_close(c2);
        } else {
            ok = 0;
        }
    }
    snprintf(msg, sizeof msg, "UTF-8 -> UTF-16LE and latin1 -> UTF-8 %s", ok ? "ok" : "BAD");
    report("iconv", ok, msg);
}
#endif

#ifdef HAVE_PIXMAN_1
static void test_pixman(void)
{
    char msg[96];
    pixman_image_t *img = pixman_image_create_bits(PIXMAN_a8r8g8b8, 16, 16, NULL, 0);
    int ok = 0;
    if (img) {
        pixman_color_t c = {0xffff, 0x8000, 0x0000, 0xffff};
        pixman_box32_t box = {2, 2, 10, 10};
        pixman_image_fill_boxes(PIXMAN_OP_SRC, img, &c, 1, &box);
        uint32_t *p = pixman_image_get_data(img);
        int stride = pixman_image_get_stride(img) / 4;
        uint32_t in_px = p[5 * stride + 5], out_px = p[0];
        ok = (in_px >> 24) == 0xff && ((in_px >> 16) & 0xff) == 0xff && out_px == 0;
        snprintf(msg, sizeof msg, "pixman %s fill: inside=%08x outside=%08x", pixman_version_string(),
                 (unsigned)in_px, (unsigned)out_px);
        pixman_image_unref(img);
    } else {
        snprintf(msg, sizeof msg, "image create failed");
    }
    report("pixman", ok, msg);
}
#endif

#ifdef HAVE_GLIB_2_0
static int g_idle_hits;
static gboolean idle_cb(gpointer d)
{
    (void)d;
    g_idle_hits++;
    return G_SOURCE_REMOVE;
}

static void test_glib(void)
{
    char msg[128];
    GHashTable *h = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, NULL);
    for (int i = 0; i < 100; i++)
        g_hash_table_insert(h, g_strdup_printf("key%d", i), GINT_TO_POINTER(i + 1));
    int hv = GPOINTER_TO_INT(g_hash_table_lookup(h, "key41"));
    guint n = g_hash_table_size(h);
    g_hash_table_destroy(h);

#ifdef NEXVYN_COMPAT
    // Main loop: one idle source dispatched by one iteration. g_main_context_new() creates a wakeup pipe, which is
    // the compat layer's pipe()/eventfd, so this part only exists in builds that link it.
    GMainContext *ctx = g_main_context_new();
    GSource *s = g_idle_source_new();
    g_source_set_callback(s, idle_cb, NULL, NULL);
    g_source_attach(s, ctx);
    g_source_unref(s);
    g_main_context_iteration(ctx, FALSE);
    g_main_context_unref(ctx);
#else
    g_idle_hits = 1; // no compat layer: the main loop is not exercised, only hash table and string
    (void)idle_cb;
#endif

    GString *str = g_string_new("glib");
    g_string_append_printf(str, "-%d", 2);
    int sl = (int)str->len;
    g_string_free(str, TRUE);

    int ok = hv == 42 && n == 100 && g_idle_hits == 1 && sl == 6;
    snprintf(msg, sizeof msg, "glib %u.%u.%u hash=%d size=%u idle=%d%s", glib_major_version, glib_minor_version,
             glib_micro_version, hv, (unsigned)n, g_idle_hits,
#ifdef NEXVYN_COMPAT
             "");
#else
             " (main loop not built: needs compat layer)");
#endif
    report("glib", ok, msg);
}
#endif

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;
    consoleInit(NULL);
    padConfigureInput(1, HidNpadStyleSet_NpadStandard);
    PadState pad;
    padInitializeDefault(&pad);
    g_out = fopen("sdmc:/sysroot_test_results.txt", "w");
    make_sample();
    printf("Nexvyn sysroot test\n");
    consoleUpdate(NULL);

#ifdef HAVE_ZSTD
    test_zstd();
#else
    skip("zstd");
#endif
#ifdef HAVE_LZ4
    test_lz4();
#else
    skip("lz4");
#endif
#ifdef HAVE_SQLITE3
    test_sqlite();
#else
    skip("sqlite");
#endif
#ifdef HAVE_ARCHIVE
    test_archive();
#else
    skip("libarchive");
#endif
#ifdef HAVE_ICONV
    test_iconv();
#else
    skip("iconv");
#endif
#ifdef HAVE_PIXMAN_1
    test_pixman();
#else
    skip("pixman");
#endif
#ifdef HAVE_GLIB_2_0
    test_glib();
#else
    skip("glib");
#endif
#ifdef HAVE_OPENAL
    test_openal(); // last: it brings up SDL audio
#else
    skip("openal");
#endif

    printf("RESULT pass=%d fail=%d\n", g_pass, g_fail);
    if (g_out) {
        fprintf(g_out, "RESULT pass=%d fail=%d\n", g_pass, g_fail);
        fclose(g_out);
    }
    consoleUpdate(NULL);
    // Hold the screen for a moment (or until + is pressed) so a person can read it; autorun reads the file instead.
    for (int i = 0; i < 180 && appletMainLoop(); i++) {
        padUpdate(&pad);
        if (padGetButtonsDown(&pad) & HidNpadButton_Plus)
            break;
        svcSleepThread(16666667LL);
        consoleUpdate(NULL);
    }
    consoleExit(NULL);
    return g_fail;
}
