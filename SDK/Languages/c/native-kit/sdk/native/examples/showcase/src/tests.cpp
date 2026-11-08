/* Native SDK Showcase - the self-tests. Every test sets its Status row (feat_set) and adds detail lines for its page.
 * Compat-layer tests (pipe, mmap, ...) and library tests are compiled in only when the build has them
 * (SHOWCASE_COMPAT: the compat layer is linked in, both modes, SHOWCASE_LIBS: zstd / lz4 / sqlite found in the sysroot). */
#include "showcase.h"
#include <dirent.h>
#include <errno.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

Feature g_feat[F_COUNT];
Lines g_lines[L_COUNT];
int g_windowed;
int g_feat_dirty;

#ifdef SHOWCASE_COMPAT
#include <dlfcn.h>
extern "C" {
int sc_c_pipe(char*, size_t);
int sc_c_poll(char*, size_t);
int sc_c_eventfd(char*, size_t);
int sc_c_select(char*, size_t);
int sc_c_mmap(char*, size_t);
int sc_c_mprotect(char*, size_t);
int sc_c_signal(char*, size_t);
int sc_c_fcntl(char*, size_t);
int sc_c_devnull(char*, size_t);
int sc_c_devrandom(char*, size_t);
int sc_c_timespec(char*, size_t);
int sc_c_coro(char*, size_t);
int sc_c_dlopen(char*, size_t);
extern nxn_caps g_caps;
int sc_c_socket(char*, size_t);
int sc_c_envcwd(char*, size_t);
}
#endif
#ifdef SHOWCASE_LIBS
extern "C" {
int sc_zstd(char*, size_t);
int sc_lz4(char*, size_t);
int sc_sqlite(char*, size_t);
}
#endif

const char* res_text(Res r) {
    switch (r) {
    case RES_OK: return "OK";
    case RES_FAIL: return "FAIL";
    case RES_NA: return "-";
    case RES_TODO: return "NOT IMPLEMENTED";
    default: return "not run";
    }
}

void feat_set(int id, Res r, const char* fmt, ...) {
    if (id < 0 || id >= F_COUNT) return;
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(g_feat[id].note, sizeof g_feat[id].note, fmt, ap);
    va_end(ap);
    g_feat[id].res = r;
    g_feat_dirty = 1;
    if (r == RES_FAIL) nxn_log(NXN_LOG_ERROR, "[%s] FAIL: %s", g_feat[id].name, g_feat[id].note);
}

void Lines::add(Res r, const char* fmt, ...) {
    if (n >= 40) return;
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(text[n], sizeof text[n], fmt, ap);
    va_end(ap);
    res[n++] = r;
}

void tests_init(int windowed) {
    g_windowed = windowed;
    int i = 0;
#define X(id, g, n, m) g_feat[i++] = Feature{g, n, m, RES_PEND, ""};
    SC_FEATURES(X)
#undef X
    for (i = 0; i < F_COUNT; i++) {
        if (g_feat[i].modes == 'E' && windowed) {
            g_feat[i].res = RES_NA;
            snprintf(g_feat[i].note, sizeof g_feat[i].note, "- (exclusive mode retired)");
        } else if (g_feat[i].modes == 'W' && !windowed) {
            g_feat[i].res = RES_NA;
            snprintf(g_feat[i].note, sizeof g_feat[i].note, "windowed mode only");
        }
    }
    for (int k = 0; k < L_COUNT; k++) g_lines[k].clear();
}

/* ---------------------------------------------------------------- core */
void test_core(void) {
    Lines& L = g_lines[L_CORE];
    L.clear();
    nxn_caps c = NXN_STRUCT_INIT(nxn_caps);
    nxn_result r = nxn_caps_get(&c);
    if (r == NXN_OK && c.abi_gen == NXN_ABI_GEN && c.version_major == NXN_VERSION_MAJOR) {
        feat_set(F_INIT, RES_OK, "abi %u, native %u.%u, features 0x%llx", c.abi_gen, c.version_major, c.version_minor,
                 (unsigned long long)c.features);
    } else {
        feat_set(F_INIT, RES_FAIL, "nxn_caps_get -> %d, abi %u (header %d)", (int)r, c.abi_gen, NXN_ABI_GEN);
    }
    L.add(RES_OK, "caps: abi_gen %u, native %u.%u, features 0x%llx", c.abi_gen, c.version_major, c.version_minor,
          (unsigned long long)c.features);
    L.add(RES_OK, "GL core up to %u.%u, GLES up to %u.%u", c.gl_max_major, c.gl_max_minor, c.gles_max_major,
          c.gles_max_minor);
    static const struct { uint64_t bit; const char* name; } bits[] = {
        {NXN_CAP_HOSTED, "HOSTED"},   {NXN_CAP_RETURN, "RETURN"},     {NXN_CAP_CRASH_GUARD, "CRASH_GUARD"},
        {NXN_CAP_GL_CORE, "GL_CORE"}, {NXN_CAP_GLES, "GLES"},         {NXN_CAP_AUDIO, "AUDIO"},
        {NXN_CAP_TOUCH, "TOUCH"},     {NXN_CAP_KEYBOARD, "KEYBOARD"}, {NXN_CAP_APPLET_MODE, "APPLET_MODE"},
        {NXN_CAP_EVENTS, "EVENTS"},   {NXN_CAP_SHARED_LIBS, "SHARED_LIBS"}, {NXN_CAP_WINDOWED, "WINDOWED"}};
    for (const auto& b : bits) L.add((c.features & b.bit) ? RES_OK : RES_NA, "NXN_CAP_%s: %s", b.name, (c.features & b.bit) ? "yes" : "no");
    int win_cap = (c.features & NXN_CAP_WINDOWED) != 0;
    if (win_cap != g_windowed) L.add(RES_FAIL, "NXN_CAP_WINDOWED (%d) does not match the build mode (%d)", win_cap, g_windowed);

    nxn_info in = NXN_STRUCT_INIT(nxn_info);
    r = nxn_info_get(&in);
    if (r == NXN_OK && *nxn_info_string(NXN_INFO_APP_ID))
        feat_set(F_INFO, RES_OK, "hosted %u, theme %s, accent #%06X, app %s", in.hosted, in.theme_dark ? "dark" : "light",
                 in.accent_rgb, nxn_info_string(NXN_INFO_APP_ID));
    else
        feat_set(F_INFO, RES_FAIL, "nxn_info_get -> %d, app id '%s'", (int)r, nxn_info_string(NXN_INFO_APP_ID));
    L.add(RES_OK, "confirm buttons 0x%llx, cancel buttons 0x%llx", (unsigned long long)in.confirm_buttons,
          (unsigned long long)in.cancel_buttons);

    nxn_log(NXN_LOG_INFO, "showcase: log test line");
    feat_set(F_LOG, RES_OK, "line written (System/Logs/Apps/<id>.log)");
}

/* ---------------------------------------------------------------- files */
#define FS_CHECK(cond, ...)                      \
    do {                                         \
        if (!(cond)) {                           \
            snprintf(err, sizeof err, __VA_ARGS__); \
            L.add(RES_FAIL, "%s", err);            \
            ok = 0;                              \
        }                                        \
    } while (0)

void test_files(void) {
    Lines& L = g_lines[L_FILES];
    L.clear();
    char path[320], err[200] = "";
    int ok;

    /* write / read through the SDK */
    ok = 1;
    const char msg[] = "hello from the showcase";
    nxn_result r = nxn_fs_mkdirs(NXN_DIR_DATA, "showcase/sub");
    FS_CHECK(r == NXN_OK, "nxn_fs_mkdirs -> %d (%s)", (int)r, nxn_last_error());
    r = nxn_fs_write(NXN_DIR_DATA, "showcase/sub/a.txt", msg, sizeof msg - 1);
    FS_CHECK(r == NXN_OK, "nxn_fs_write -> %d (%s)", (int)r, nxn_last_error());
    char buf[64] = {0};
    size_t got = 0;
    r = nxn_fs_read(NXN_DIR_DATA, "showcase/sub/a.txt", buf, sizeof buf, &got);
    FS_CHECK(r == NXN_OK && got == sizeof msg - 1 && memcmp(buf, msg, got) == 0, "nxn_fs_read -> %d, %zu bytes", (int)r, got);
    r = nxn_fs_read(NXN_DIR_DATA, "showcase/sub/a.txt", buf, 4, &got);
    FS_CHECK(r == NXN_ERR_TOO_SMALL, "small buffer: expected NXN_ERR_TOO_SMALL, got %d", (int)r);
    if (ok) L.add(RES_OK, "write + read back %zu bytes; a too small buffer gives NXN_ERR_TOO_SMALL", sizeof msg - 1);
    feat_set(F_FS_WRITE, ok ? RES_OK : RES_FAIL, "%s", ok ? "mkdirs, atomic write, read, TOO_SMALL" : err);

    /* stat on an open file */
    ok = 1;
    nxn_fs_path(NXN_DIR_DATA, "showcase/sub/b.txt", path, sizeof path);
    FILE* f = fopen(path, "wb");
    FS_CHECK(f != NULL, "fopen(%.100s) failed: errno %d", path, errno);
    if (f) {
        fwrite("0123456789", 1, 10, f);
        fflush(f);
        struct stat st;
        memset(&st, 0, sizeof st);
        int rc = fstat(fileno(f), &st);
        FS_CHECK(rc == 0 && st.st_size == 10, "fstat: rc %d, size %ld (expected 10)", rc, (long)st.st_size);
        if (rc == 0) L.add(ok ? RES_OK : RES_FAIL, "fstat on the open file: size %ld, mode 0%o", (long)st.st_size, (unsigned)st.st_mode);
        fclose(f);
    }
    feat_set(F_FS_STAT, ok ? RES_OK : RES_FAIL, "%s", ok ? "size 10 after fflush" : err);

    /* list */
    ok = 1;
    nxn_fs_path(NXN_DIR_DATA, "showcase/sub", path, sizeof path);
    DIR* d = opendir(path);
    int seen_a = 0, seen_b = 0, count = 0;
    FS_CHECK(d != NULL, "opendir(%.100s) failed: errno %d", path, errno);
    if (d) {
        while (struct dirent* e = readdir(d)) {
            if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
            count++;
            seen_a |= !strcmp(e->d_name, "a.txt");
            seen_b |= !strcmp(e->d_name, "b.txt");
        }
        closedir(d);
        FS_CHECK(seen_a && seen_b, "listing: %d entries, a.txt %d, b.txt %d", count, seen_a, seen_b);
    }
    if (ok) L.add(RES_OK, "list: %d entries (a.txt, b.txt)", count);
    if (ok)
        feat_set(F_FS_LIST, RES_OK, "%d entries", count);
    else
        feat_set(F_FS_LIST, RES_FAIL, "%s", err);

    /* delete */
    ok = 1;
    char p1[320], p2[320], dir[320];
    nxn_fs_path(NXN_DIR_DATA, "showcase/sub/a.txt", p1, sizeof p1);
    nxn_fs_path(NXN_DIR_DATA, "showcase/sub/b.txt", p2, sizeof p2);
    nxn_fs_path(NXN_DIR_DATA, "showcase/sub", dir, sizeof dir);
    FS_CHECK(unlink(p1) == 0, "unlink a.txt: errno %d", errno);
    FS_CHECK(unlink(p2) == 0, "unlink b.txt: errno %d", errno);
    struct stat st;
    FS_CHECK(stat(p1, &st) != 0, "a.txt still exists after unlink");
    FS_CHECK(rmdir(dir) == 0, "rmdir: errno %d", errno);
    if (ok) L.add(RES_OK, "unlink x2, stat says gone, rmdir ok");
    feat_set(F_FS_DELETE, ok ? RES_OK : RES_FAIL, "%s", ok ? "unlink, rmdir, stat after delete" : err);

    /* sandbox helpers */
    ok = 1;
    r = nxn_fs_write(NXN_DIR_BUNDLE, "x.txt", "x", 1);
    FS_CHECK(r == NXN_ERR_DENIED, "write into the bundle: expected NXN_ERR_DENIED (-5), got %d", (int)r);
    /* nxn_fs.h: a path outside the folders is NXN_ERR_DENIED (both the library and the host answer it) */
    r = nxn_fs_write(NXN_DIR_DATA, "../escape.txt", "x", 1);
    int dots_r = (int)r;
    FS_CHECK(r == NXN_ERR_DENIED, "../ path: expected NXN_ERR_DENIED (-5), got %d", dots_r);
    r = nxn_fs_write(NXN_DIR_DATA, "/abs.txt", "x", 1);
    int abs_r = (int)r;
    FS_CHECK(r == NXN_ERR_DENIED, "absolute path: expected NXN_ERR_DENIED (-5), got %d", abs_r);
    /* error codes come from the file system (errno), not a guess: a missing file is NOT_FOUND, an empty name is INVALID */
    char nobuf[8];
    size_t nogot = 99;
    r = nxn_fs_read(NXN_DIR_DATA, "showcase/does-not-exist.bin", nobuf, sizeof nobuf, &nogot);
    FS_CHECK(r == NXN_ERR_NOT_FOUND && nogot == 0, "read of a missing file: expected NXN_ERR_NOT_FOUND (-8), got %d", (int)r);
    r = nxn_fs_read(NXN_DIR_DATA, "", nobuf, sizeof nobuf, &nogot);
    FS_CHECK(r == NXN_ERR_INVALID, "read of an empty name: expected NXN_ERR_INVALID (-1), got %d", (int)r);
    if (ok) L.add(RES_OK, "bundle write, ../ and absolute path -> DENIED (-5); missing file -> NOT_FOUND (-8); empty name -> INVALID (-1)");
    feat_set(F_FS_SANDBOX, ok ? RES_OK : RES_FAIL, "%s", ok ? "bundle and ../ and absolute paths DENIED, missing file NOT_FOUND, empty name INVALID" : err);

#ifdef SHOWCASE_COMPAT
    char msgbuf[200];
    int rc = sc_c_devnull(msgbuf, sizeof msgbuf);
    feat_set(F_DEV_NULL, rc ? RES_OK : RES_FAIL, "%s", msgbuf);
    L.add(rc ? RES_OK : RES_FAIL, "/dev/null: %s", msgbuf);
    rc = sc_c_devrandom(msgbuf, sizeof msgbuf);
    feat_set(F_DEV_RANDOM, rc ? RES_OK : RES_FAIL, "%s", msgbuf);
    L.add(rc ? RES_OK : RES_FAIL, "/dev/random: %s", msgbuf);
#else
    L.add(RES_NA, "/dev/null, /dev/random: the compat layer is not part of a windowed app");
#endif
    test_saves();
}

/* ---------------------------------------------------------------- UI tokens, fonts, icons, texts (nxn_ui.h) */
nxn_ui_tokens g_tok;

static int has_magic(const void* d, size_t n) {
    const unsigned char* b = (const unsigned char*)d;
    if (n < 12) return 0;
    static const unsigned char ttf[4] = {0, 1, 0, 0};
    return (!memcmp(b, ttf, 4) || !memcmp(b, "OTTO", 4) || !memcmp(b, "true", 4) || !memcmp(b, "ttcf", 4));
}

void test_ui(void) {
    Lines& L = g_lines[L_UI];
    L.clear();
    memset(&g_tok, 0, sizeof g_tok);
    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    nxn_caps_get(&caps);
    if (!(caps.features & NXN_CAP_UI_TOKENS)) {
        feat_set(F_UI_TOKENS, RES_NA, "NXN_CAP_UI_TOKENS is not set (not in a Nexvyn OS window)");
        feat_set(F_UI_THEME_EVT, RES_NA, "NXN_CAP_UI_TOKENS is not set");
    } else {
        g_tok.size = sizeof g_tok;
        nxn_result r = nxn_ui_tokens_get(&g_tok);
        nxn_info info = NXN_STRUCT_INIT(nxn_info);
        nxn_info_get(&info);
        int ok = r == NXN_OK;
        L.add(ok ? RES_OK : RES_FAIL, "nxn_ui_tokens_get -> %d, revision %u, %s", (int)r, g_tok.revision, g_tok.dark ? "dark" : "light");
        int sane = (g_tok.text >> 24) != 0 && g_tok.text != g_tok.window_bg &&
                   g_tok.corner_radius > 0 && g_tok.control_height > 0 && g_tok.font_body > 0 && g_tok.revision >= 1 &&
                   g_tok.spacing[0] > 0 && g_tok.spacing[5] > g_tok.spacing[0] && g_tok.text_scale > 0.5f;
        L.add(sane ? RES_OK : RES_FAIL, "values: opaque text %08X on window %08X, radius %.0f, spacing %.0f..%.0f, body %.0f px", g_tok.text,
              g_tok.window_bg, g_tok.corner_radius, g_tok.spacing[0], g_tok.spacing[5], g_tok.font_body);
        int same = (g_tok.dark != 0) == (info.theme_dark != 0) && (g_tok.accent & 0xFFFFFF) == info.accent_rgb;
        L.add(same ? RES_OK : RES_FAIL, "same look as nxn_info: dark %u/%u, accent %06X/%06X", g_tok.dark, info.theme_dark, g_tok.accent & 0xFFFFFF,
              info.accent_rgb);
        /* an app built against an older, shorter struct: only its own bytes are written */
        struct { nxn_ui_tokens t; uint32_t guard[4]; } probe;
        memset(&probe, 0xAB, sizeof probe);
        probe.t.size = 4 * sizeof(uint32_t);
        nxn_result sr = nxn_ui_tokens_get(&probe.t);
        int intact = probe.guard[0] == 0xABABABABu && probe.t.accent == 0xABABABABu && probe.t.revision == g_tok.revision;
        L.add(sr == NXN_OK && intact ? RES_OK : RES_FAIL, "short struct (size %u): header only (%d), nothing past it written (%d)", probe.t.size, (int)sr, intact);
        const void* d = NULL;
        size_t n = 0;
        nxn_result fr = nxn_ui_font_get(NXN_UI_FONT_SANS, &d, &n);
        int fok = fr == NXN_OK && n > 10000 && has_magic(d, n);
        L.add(fok ? RES_OK : RES_FAIL, "font SANS: %d, %zu bytes, font header %d", (int)fr, n, has_magic(d, n));
        nxn_result ir = nxn_ui_font_get(NXN_UI_FONT_ICONS, &d, &n);
        int iok = ir == NXN_OK && n > 10000 && has_magic(d, n);
        L.add(iok ? RES_OK : RES_FAIL, "font ICONS: %d, %zu bytes", (int)ir, n);
        const void* d2 = (const void*)1;
        size_t n2 = 7;
        nxn_result br = nxn_ui_font_get((nxn_ui_font)99, &d2, &n2);
        L.add(br == NXN_ERR_NOT_FOUND && !d2 && n2 == 0 ? RES_OK : RES_FAIL, "unknown font id -> %d (NXN_ERR_NOT_FOUND = %d)", (int)br, NXN_ERR_NOT_FOUND);
        uint32_t fc = nxn_ui_icon_code("folder");
        uint32_t nc = nxn_ui_icon_code("no_such_icon_xyz");
        L.add(fc != 0 && nc == 0 ? RES_OK : RES_FAIL, "icon 'folder' = U+%04X, unknown name = %u", fc, nc);
        feat_set(F_UI_TOKENS, ok && sane && same && sr == NXN_OK && intact && fok && iok && br == NXN_ERR_NOT_FOUND && fc != 0 && nc == 0 ? RES_OK : RES_FAIL,
                 "tokens %s, accent %06X, font %zu bytes, icon folder U+%04X", g_tok.dark ? "dark" : "light", g_tok.accent & 0xFFFFFF, n, fc);
        if (g_feat[F_UI_THEME_EVT].res != RES_OK) feat_set(F_UI_THEME_EVT, RES_PEND, "waiting: switch light / dark in Settings > Appearance");
    }
    if (!(caps.features & NXN_CAP_TEXT)) {
        feat_set(F_UI_TEXT, RES_NA, "NXN_CAP_TEXT is not set (not in a Nexvyn OS window)");
    } else {
        const char* lang = nxn_info_string(NXN_INFO_LANGUAGE);
        int tr = !strcmp(lang, "tr");
        const char* hello = nxn_tr("hello");
        const char* open = nxn_tr("menu.open");
        const char* only = nxn_tr("only_en");
        const char* gone = nxn_tr("no.such.key");
        const char* args[] = {"42"};
        char out[64], tiny[4];
        nxn_result fr = nxn_tr_format("times", out, sizeof out, args, 1);
        nxn_result tr2 = nxn_tr_format("times", tiny, sizeof tiny, args, 1);
        int c1 = !strcmp(hello, tr ? "Merhaba" : "Hello");
        int c2 = !strcmp(open, tr ? "Aç" : "Open");
        int c3 = !strcmp(only, "English only"); /* lang/tr.json lacks it: the English text */
        int c4 = !strcmp(gone, "no.such.key");
        int c5 = fr == NXN_OK && !strcmp(out, tr ? "42 kez tıklandı" : "Clicked 42 times");
        int c6 = tr2 == NXN_ERR_TOO_SMALL;
        int c7 = nxn_tr("hello") == hello; /* the pointer is stable */
        L.add(c1 ? RES_OK : RES_FAIL, "language '%s': hello = '%s'", lang, hello);
        L.add(c2 ? RES_OK : RES_FAIL, "nested key menu.open = '%s'", open);
        L.add(c3 ? RES_OK : RES_FAIL, "missing in the language file: falls back to English: '%s'", only);
        L.add(c4 ? RES_OK : RES_FAIL, "unknown key returns the key: '%s'", gone);
        L.add(c5 ? RES_OK : RES_FAIL, "nxn_tr_format -> %d '%s'", (int)fr, out);
        L.add(c6 ? RES_OK : RES_FAIL, "buffer too small -> %d (NXN_ERR_TOO_SMALL = %d)", (int)tr2, NXN_ERR_TOO_SMALL);
        L.add(c7 ? RES_OK : RES_FAIL, "pointer stays the same between calls");
        feat_set(F_UI_TEXT, c1 && c2 && c3 && c4 && c5 && c6 && c7 ? RES_OK : RES_FAIL, "'%s' -> '%s', %s", "hello", hello, fr == NXN_OK ? out : "format failed");
    }
    for (int i = 0; i < L.n; i++)
        if (L.res[i] == RES_FAIL) nxn_log(NXN_LOG_ERROR, "ui line %d: %s", i, L.text[i]);
}

/* ---------------------------------------------------------------- OS mixer and button mapping (Native 1.1, windowed) */
static void test_mixer_actions(void) {
    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    nxn_caps_get(&caps);
    if (!(caps.features & NXN_CAP_MIXER)) {
        feat_set(F_MIXER, RES_NA, "NXN_CAP_MIXER is not set (not in a Nexvyn OS window)");
    } else {
        /* volume 0: the calls are really made, nobody hears them */
        nxn_result p = nxn_sfx_play("click", 0.f, 0), t = nxn_tone(440.f, 0.05f, 0.f, 0), s = nxn_sfx_stop_all();
        nxn_result bad1 = nxn_sfx_play("", 1.f, 0), bad2 = nxn_tone(440.f, 1.f, 1.f, 99);
        bool ok = p == NXN_OK && t == NXN_OK && s == NXN_OK && bad1 == NXN_ERR_INVALID && bad2 == NXN_ERR_INVALID;
        feat_set(F_MIXER, ok ? RES_OK : RES_FAIL, "play %d, tone %d, stop %d, empty name %d, wave 99 %d (INVALID = %d)", (int)p, (int)t, (int)s, (int)bad1, (int)bad2, NXN_ERR_INVALID);
    }
    if (!(caps.features & NXN_CAP_INPUT_ACTIONS)) {
        feat_set(F_ACTIONS, RES_NA, "NXN_CAP_INPUT_ACTIONS is not set (not in a Nexvyn OS window)");
    } else {
        uint64_t sel = 0, back = 0, none = 7;
        nxn_result r1 = NXN_ERR_NOT_READY, r2 = NXN_ERR_NOT_READY;
        for (int i = 0; i < 100 && (sel == 0 || back == 0); i++) { /* the first snapshot comes with the OS's next frame */
            r1 = nxn_input_action_buttons("select", &sel);
            r2 = nxn_input_action_buttons("back", &back);
            if (sel && back) break;
            nxn_sleep_ns(10000000ull);
        }
        nxn_result r3 = nxn_input_action_buttons("no_such_action", &none);
        bool ok = r1 == NXN_OK && r2 == NXN_OK && sel != 0 && back != 0 && (sel & back) == 0 && sel < 0x10000 && back < 0x10000 && r3 == NXN_ERR_NOT_FOUND && none == 0;
        feat_set(F_ACTIONS, ok ? RES_OK : RES_FAIL, "select = 0x%llx, back = 0x%llx (NXN_BTN_* masks), unknown name -> %d (NOT_FOUND = %d)", (unsigned long long)sel, (unsigned long long)back, (int)r3, NXN_ERR_NOT_FOUND);
    }
}

/* ---------------------------------------------------------------- system */
void test_system(void) {
    Lines& L = g_lines[L_SYSTEM];
    L.clear();
    const char* user = nxn_info_string(NXN_INFO_USER_NAME);
    const char* lang = nxn_info_string(NXN_INFO_LANGUAGE);
    const char* theme = nxn_info_string(NXN_INFO_THEME);
    L.add(*user ? RES_OK : RES_FAIL, "user: '%s'", user);
    L.add(*lang ? RES_OK : RES_FAIL, "language: '%s'", lang);
    L.add(*theme ? RES_OK : RES_FAIL, "theme: '%s'", theme);
    nxn_info info = NXN_STRUCT_INIT(nxn_info);
    nxn_info_get(&info);
    int hosted = info.hosted != 0;
    if (!hosted && !*user && *lang)
        feat_set(F_USER, RES_NA, "started without Nexvyn OS (Homebrew menu): no user name; language %s, theme %s", lang, theme);
    else
        feat_set(F_USER, (*user && *lang && *theme) ? RES_OK : RES_FAIL, "%s / %s / %s", user, lang, theme);

    const char* os = nxn_info_string(NXN_INFO_OS_VERSION);
    const char* sdk = nxn_info_string(NXN_INFO_SDK_VERSION);
    const char* nat = nxn_info_string(NXN_INFO_NATIVE_VERSION);
    const char* app = nxn_info_string(NXN_INFO_APP_VERSION);
    L.add(RES_OK, "Nexvyn OS '%s', script SDK '%s', Native SDK '%s'", os, sdk, nat);
    L.add(RES_OK, "this app: %s %s", nxn_info_string(NXN_INFO_APP_ID), app);
    if (!hosted && !*os && !*nat)
        feat_set(F_VERSIONS, RES_NA, "started without Nexvyn OS (Homebrew menu): versions are empty by design");
    else
        feat_set(F_VERSIONS, (*os && *nat) ? RES_OK : RES_FAIL, "OS %s, SDK %s, native %s", os, sdk, nat);

    nxn_caps c = NXN_STRUCT_INIT(nxn_caps);
    nxn_caps_get(&c);
    L.add(RES_OK, "launch mode: %s", (c.features & NXN_CAP_WINDOWED) ? "windowed (a window of Nexvyn OS)" : "exclusive (own .nro)");
    L.add(RES_OK, "started by Nexvyn OS: %s", (c.features & NXN_CAP_HOSTED) ? "yes (hand-off read)" : "no (standalone)");
    L.add(RES_OK, "applet mode: %s", (c.features & NXN_CAP_APPLET_MODE) ? "yes (less memory)" : "no");
    feat_set(F_MODES, RES_OK, "%s%s", (c.features & NXN_CAP_WINDOWED) ? "windowed" : "exclusive",
             (c.features & NXN_CAP_APPLET_MODE) ? ", applet" : "");
    test_services();
}

/* ---------------------------------------------------------------- system services (nxn_sys.h, Native 1.1) */
static const char* perm_name(int s) { return s == NXN_PERM_GRANTED ? "granted" : (s == NXN_PERM_DENIED ? "denied by the user" : "not declared"); }

void test_services(void) {
    Lines& L = g_lines[L_SYSTEM];
    nxn_caps c = NXN_STRUCT_INIT(nxn_caps);
    nxn_caps_get(&c);
    char buf[256];

    /* permissions: the manifest declares "files", "network" and "notifications" */
    if (c.features & NXN_CAP_PERMISSIONS) {
        nxn_perm_state net = NXN_PERM_NOT_DECLARED, ntf = NXN_PERM_NOT_DECLARED, bad = NXN_PERM_NOT_DECLARED;
        nxn_result a = nxn_perm_query("network", &net), b = nxn_perm_query("Notifications", &ntf);
        nxn_result bad_name = nxn_perm_query("files", &bad), bad_null = nxn_perm_query(NULL, &bad);
        nxn_perm_state again = NXN_PERM_NOT_DECLARED;
        nxn_result rq = nxn_perm_request("network", &again); /* granted already: answers at once, no dialog */
        int ok = a == NXN_OK && b == NXN_OK && bad_name == NXN_ERR_INVALID && bad_null == NXN_ERR_INVALID && rq == NXN_OK &&
                 again == net && ntf == NXN_PERM_GRANTED;
        L.add(ok ? RES_OK : RES_FAIL, "permissions: network %s, notifications %s; request on a granted one -> %d, no dialog", perm_name(net), perm_name(ntf), (int)rq);
        feat_set(F_PERM, ok ? RES_OK : RES_FAIL, "network %s, notifications %s, unknown name -> %d", perm_name(net), perm_name(ntf), (int)bad_name);
    } else {
        feat_set(F_PERM, RES_NA, "NXN_CAP_PERMISSIONS is not set");
    }

    /* notification */
    if (c.features & NXN_CAP_NOTIFY) {
        nxn_result r = nxn_notify("Native SDK Showcase", "nxn_notify works: this banner came from the app");
        nxn_result bad = nxn_notify("", "empty title");
        int ok = r == NXN_OK && bad == NXN_ERR_INVALID;
        L.add(ok ? RES_OK : RES_FAIL, "notification posted -> %d, empty title -> %d", (int)r, (int)bad);
        feat_set(F_NOTIF, ok ? RES_OK : RES_FAIL, "nxn_notify -> %d (the banner is shown by Nexvyn OS; check it on the console)", (int)r);
    } else {
        feat_set(F_NOTIF, RES_NA, "NXN_CAP_NOTIFY is not set");
    }

    /* clipboard: write, read back, a too small buffer */
    if (c.features & NXN_CAP_CLIPBOARD) {
        char text[64];
        snprintf(text, sizeof text, "showcase clipboard %llu", (unsigned long long)nxn_time_ns());
        nxn_result w = nxn_clipboard_set(text);
        size_t len = 0;
        nxn_result r = nxn_clipboard_get(buf, sizeof buf, &len);
        char tiny[4];
        size_t need = 0;
        nxn_result small = nxn_clipboard_get(tiny, sizeof tiny, &need);
        int ok = w == NXN_OK && r == NXN_OK && !strcmp(buf, text) && len == strlen(text) && small == NXN_ERR_TOO_SMALL && need == strlen(text);
        L.add(ok ? RES_OK : RES_FAIL, "clipboard round trip: set -> %d, get -> %d ('%.30s'), 4-byte buffer -> %d (needs %u)", (int)w, (int)r, buf, (int)small, (unsigned)need);
        nxn_clipboard_set("");
        feat_set(F_CLIP, ok ? RES_OK : RES_FAIL, "set %d, get %d, %u bytes, too small -> %d", (int)w, (int)r, (unsigned)len, (int)small);
    } else {
        feat_set(F_CLIP, RES_NA, "NXN_CAP_CLIPBOARD is not set");
    }

    /* rumble: accepted, then stopped (the motors themselves are felt on a console) */
    if (c.features & NXN_CAP_RUMBLE) {
        nxn_result a = nxn_rumble(0.4f, 40), nan = nxn_rumble(__builtin_nanf(""), 10), stop = nxn_rumble(0.f, 0);
        int ok = a == NXN_OK && nan == NXN_ERR_INVALID && stop == NXN_OK;
        L.add(ok ? RES_OK : RES_FAIL, "rumble 0.4 for 40 ms -> %d, NaN -> %d, stop -> %d", (int)a, (int)nan, (int)stop);
        feat_set(F_RUMBLE, ok ? RES_OK : RES_FAIL, "nxn_rumble -> %d, stop -> %d (feel it on a console: Rumble button, Input page)", (int)a, (int)stop);
    } else {
        feat_set(F_RUMBLE, RES_NA, "NXN_CAP_RUMBLE is not set");
    }
}

/* ---------------------------------------------------------------- dialogs' arguments, kept folder access, saves */
static int read_text(const char* path, char* out, size_t cap) {
    FILE* f = fopen(path, "rb");
    if (!f) return 0;
    size_t n = fread(out, 1, cap - 1, f);
    out[n] = 0;
    fclose(f);
    return 1;
}

void test_saves(void) {
    Lines& L = g_lines[L_FILES];
    nxn_caps c = NXN_STRUCT_INIT(nxn_caps);
    nxn_caps_get(&c);
    char err[200] = "", path[320], got[64], slot[64];
    int ok;

    /* the dialogs need a person: only the arguments are checked here (the Files page has buttons for the real thing) */
    if (c.features & NXN_CAP_PICKER) {
        nxn_pick_params bad = NXN_STRUCT_INIT(nxn_pick_params);
        bad.kind = 9;
        nxn_pick_params good = NXN_STRUCT_INIT(nxn_pick_params);
        nxn_result a = nxn_pick(NULL, path, sizeof path), b = nxn_pick(&bad, path, sizeof path), d = nxn_pick(&good, NULL, 0);
        ok = a == NXN_ERR_INVALID && b == NXN_ERR_INVALID && d == NXN_ERR_INVALID;
        L.add(ok ? RES_OK : RES_FAIL, "nxn_pick arguments: NULL params -> %d, kind 9 -> %d, no buffer -> %d (the dialogs are the buttons below)", (int)a, (int)b, (int)d);
        feat_set(F_PICK, ok ? RES_OK : RES_FAIL, "arguments checked (NXN_ERR_INVALID); open / save / folder: buttons on this page");

        /* kept folder access: nothing is granted by this run, so the calls answer for an empty or user-filled list */
        int granted = 7;
        nxn_result g1 = nxn_grant_check("sdmc:/showcase-not-granted", &granted);
        int none = granted == 0;
        nxn_result g2 = nxn_grant_revoke("sdmc:/showcase-not-granted");
        nxn_result g3 = nxn_grant_get(100000, path, sizeof path);
        nxn_result g4 = nxn_grant_check(NULL, &granted);
        ok = g1 == NXN_OK && none && g2 == NXN_ERR_NOT_FOUND && g3 == NXN_ERR_NOT_FOUND && g4 == NXN_ERR_INVALID;
        int count = 0;
        while (nxn_grant_get((uint32_t)count, path, sizeof path) == NXN_OK && count < 100) count++;
        L.add(ok ? RES_OK : RES_FAIL, "folder grants: unknown path not granted (%d), revoke -> %d, past the end -> %d; this app has %d kept folder(s)", g1, (int)g2, (int)g3, count);
        feat_set(F_GRANT, ok ? RES_OK : RES_FAIL, "%d kept folder(s); not-granted path, revoke and index checks passed", count);
    } else {
        feat_set(F_PICK, RES_NA, "NXN_CAP_PICKER is not set");
        feat_set(F_GRANT, RES_NA, "NXN_CAP_PICKER is not set");
    }

    /* the user's saves: write, back up, change, restore, list, delete */
    if (c.features & NXN_CAP_SAVEDATA) {
        ok = 1;
        char dir[320], file[360];
        nxn_result r = nxn_save_path(dir, sizeof dir);
        FS_CHECK(r == NXN_OK, "nxn_save_path -> %d", (int)r);
        snprintf(file, sizeof file, "%s/progress.txt", dir);
        FILE* f = ok ? fopen(file, "wb") : NULL;
        FS_CHECK(f != NULL, "cannot write %s", file);
        if (f) {
            fputs("level 1", f);
            fclose(f);
        }
        const char* name = "showcase-test";
        nxn_save_backup_delete(name);
        r = nxn_save_backup(name);
        FS_CHECK(r == NXN_OK, "nxn_save_backup -> %d", (int)r);
        f = fopen(file, "wb");
        if (f) {
            fputs("level 2", f);
            fclose(f);
        }
        r = nxn_save_restore(name);
        FS_CHECK(r == NXN_OK, "nxn_save_restore -> %d", (int)r);
        FS_CHECK(read_text(file, got, sizeof got) && !strcmp(got, "level 1"), "after the restore the save reads '%s', expected 'level 1'", got);
        int found = 0;
        for (uint32_t i = 0; i < 64 && nxn_save_backup_get(i, slot, sizeof slot) == NXN_OK; i++) found += !strcmp(slot, name);
        FS_CHECK(found == 1, "the slot is listed %d time(s), expected 1", found);
        FS_CHECK(nxn_save_backup("../x") == NXN_ERR_INVALID, "slot '../x' was not refused");
        FS_CHECK(nxn_save_restore("showcase-none") == NXN_ERR_NOT_FOUND, "restore of a missing slot was not NOT_FOUND");
        FS_CHECK(nxn_save_backup_delete(name) == NXN_OK, "nxn_save_backup_delete failed");
        FS_CHECK(nxn_save_restore(name) == NXN_ERR_NOT_FOUND, "the deleted slot can still be restored");
        remove(file);
        if (ok) L.add(RES_OK, "saves: backup, change, restore -> 'level 1' again; slot listed once; bad / missing / deleted slots refused");
        feat_set(F_SAVE, ok ? RES_OK : RES_FAIL, "%s", ok ? "round trip: backup, change, restore, list, delete; saves in <data>/save, backups in Library/Backups" : err);
    } else {
        feat_set(F_SAVE, RES_NA, "NXN_CAP_SAVEDATA is not set");
    }
}

/* ---------------------------------------------------------------- threads */
struct Shared {
    pthread_mutex_t mu;
    pthread_cond_t cv;
    int counter;
    int ready;
};

static void worker_fn(void* arg) {
    Shared* s = (Shared*)arg;
    for (int i = 0; i < 5000; i++) {
        pthread_mutex_lock(&s->mu);
        s->counter++;
        pthread_mutex_unlock(&s->mu);
    }
    pthread_mutex_lock(&s->mu);
    s->ready++;
    pthread_cond_signal(&s->cv);
    pthread_mutex_unlock(&s->mu);
}

static void plain_thread_fn(void* arg) { *(volatile int*)arg = 1234; }

void test_threads(void) {
    Lines& L = g_lines[L_THREADS];
    L.clear();

    /* nxn_thread alone */
    volatile int flag = 0;
    nxn_thread_params tp = NXN_STRUCT_INIT(nxn_thread_params);
    tp.fn = plain_thread_fn;
    tp.arg = (void*)&flag;
    tp.name = "showcase-plain";
    nxn_thread* t = NULL;
    nxn_result r = nxn_thread_start(&tp, &t);
    if (r == NXN_OK) r = nxn_thread_join(t);
    if (r == NXN_OK && flag == 1234) {
        feat_set(F_THREAD, RES_OK, "started, ran, joined");
        L.add(RES_OK, "nxn_thread_start + join: worker wrote its result");
    } else {
        feat_set(F_THREAD, RES_FAIL, "start/join -> %d, flag %d (%s)", (int)r, (int)flag, nxn_last_error());
        L.add(RES_FAIL, "nxn_thread: %d, flag %d", (int)r, (int)flag);
    }

    /* three workers, mutex, condvar */
    Shared s;
    pthread_mutex_init(&s.mu, NULL);
    pthread_cond_init(&s.cv, NULL);
    s.counter = 0;
    s.ready = 0;
    nxn_thread* w[3] = {0, 0, 0};
    int started = 0;
    for (int i = 0; i < 3; i++) {
        nxn_thread_params p = NXN_STRUCT_INIT(nxn_thread_params);
        p.fn = worker_fn;
        p.arg = &s;
        p.name = "showcase-worker";
        if (nxn_thread_start(&p, &w[i]) == NXN_OK) started++;
    }
    uint64_t t0 = nxn_time_ns();
    pthread_mutex_lock(&s.mu);
    while (s.ready < started && nxn_time_ns() - t0 < 5000000000ull) {
        struct timespec ts;
        clock_gettime(CLOCK_REALTIME, &ts);
        ts.tv_sec += 1;
        pthread_cond_timedwait(&s.cv, &s.mu, &ts);
    }
    int ready = s.ready, counter = s.counter;
    pthread_mutex_unlock(&s.mu);
    for (int i = 0; i < 3; i++)
        if (w[i]) nxn_thread_join(w[i]);
    int ok = started == 3 && ready == 3 && counter == 15000;
    feat_set(F_PTHREAD, ok ? RES_OK : RES_FAIL, "%d workers, counter %d (expected 15000), condvar woke %d times", started, counter,
             ready);
    L.add(ok ? RES_OK : RES_FAIL, "mutex + condvar: 3 workers x 5000 increments = %d, %d signals in %.1f ms", counter, ready,
          (nxn_time_ns() - t0) / 1e6);
    pthread_cond_destroy(&s.cv);
    pthread_mutex_destroy(&s.mu);

    /* clocks */
    struct timespec a, b;
    uint64_t n0 = nxn_time_ns();
    clock_gettime(CLOCK_MONOTONIC, &a);
    nxn_sleep_ns(20 * 1000000ull);
    clock_gettime(CLOCK_MONOTONIC, &b);
    uint64_t n1 = nxn_time_ns();
    double d_posix = (b.tv_sec - a.tv_sec) * 1e3 + (b.tv_nsec - a.tv_nsec) / 1e6, d_nxn = (n1 - n0) / 1e6;
    ok = d_posix > 15 && d_posix < 60 && d_nxn - d_posix < 5 && d_posix - d_nxn < 5;
    feat_set(F_CLOCK, ok ? RES_OK : RES_FAIL, "20 ms sleep: clock_gettime %.2f ms, nxn_time_ns %.2f ms", d_posix, d_nxn);
    L.add(ok ? RES_OK : RES_FAIL, "clock_gettime(MONOTONIC) %.2f ms vs nxn_time_ns %.2f ms for one 20 ms sleep", d_posix, d_nxn);
    L.add(RES_OK, "wall clock: nxn_time_unix %lld", (long long)nxn_time_unix());

    /* sleep accuracy */
    double mn = 1e9, mx = 0, sum = 0;
    for (int i = 0; i < 10; i++) {
        uint64_t s0 = nxn_time_ns();
        nxn_sleep_ns(10 * 1000000ull);
        double ms = (nxn_time_ns() - s0) / 1e6;
        if (ms < mn) mn = ms;
        if (ms > mx) mx = ms;
        sum += ms;
    }
    ok = mn >= 9.5 && mx < 40;
    feat_set(F_SLEEP, ok ? RES_OK : RES_FAIL, "10 x 10 ms: min %.2f, avg %.2f, max %.2f ms", mn, sum / 10, mx);
    L.add(ok ? RES_OK : RES_FAIL, "nxn_sleep_ns(10 ms) x10: min %.2f avg %.2f max %.2f ms", mn, sum / 10, mx);

#ifdef SHOWCASE_COMPAT
    char msg[200];
    int rc = sc_c_timespec(msg, sizeof msg);
    feat_set(F_TIMESPEC, rc ? RES_OK : RES_FAIL, "%s", msg);
    L.add(rc ? RES_OK : RES_FAIL, "timespec_get: %s", msg);
    rc = sc_c_coro(msg, sizeof msg);
    feat_set(F_CORO, rc ? RES_OK : RES_FAIL, "%s", msg);
    L.add(rc ? RES_OK : RES_FAIL, "coroutines: %s", msg);
#else
    L.add(RES_NA, "timespec_get, nxc_coro, ucontext: compat layer, exclusive mode only");
#endif
}

/* ---------------------------------------------------------------- compat */
void test_compat(void) {
    Lines& L = g_lines[L_COMPAT];
    L.clear();
#ifdef SHOWCASE_COMPAT
    static const struct { int id; const char* name; int (*fn)(char*, size_t); } t[] = {
        {F_PIPE, "pipe", sc_c_pipe},         {F_POLL, "poll", sc_c_poll},
        {F_EVENTFD, "eventfd", sc_c_eventfd}, {F_SELECT, "select", sc_c_select},
        {F_MMAP, "mmap", sc_c_mmap},         {F_MPROTECT, "mprotect", sc_c_mprotect},
        {F_SIGNAL, "signal", sc_c_signal},   {F_FCNTL, "fcntl", sc_c_fcntl},
        {F_SOCKET, "sockets", sc_c_socket}, {F_ENVCWD, "env + cwd", sc_c_envcwd}};
    for (const auto& x : t) {
        char msg[200] = "";
        stage(x.name);
        int rc = x.fn(msg, sizeof msg);
        feat_set(x.id, rc ? RES_OK : RES_FAIL, "%s", msg);
        L.add(rc ? RES_OK : RES_FAIL, "%s: %s", x.name, msg);
    }
#else
    L.add(RES_NA, "Built without the compat layer (libnexvyn_compat): no pipe, poll, eventfd, select, mmap, sigaction.");
#endif
}

/* ---------------------------------------------------------------- libraries */
void test_libs(void) {
    Lines& L = g_lines[L_LIBS];
    L.clear();
    char msg[200];
#ifdef SHOWCASE_LIBS
    static const struct { int id; const char* name; int (*fn)(char*, size_t); } t[] = {
        {F_ZSTD, "zstd", sc_zstd}, {F_LZ4, "lz4", sc_lz4}, {F_SQLITE, "sqlite", sc_sqlite}};
    for (const auto& x : t) {
        msg[0] = 0;
        int rc = x.fn(msg, sizeof msg);
        feat_set(x.id, rc ? RES_OK : RES_FAIL, "%s", msg);
        L.add(rc ? RES_OK : RES_FAIL, "%s: %s", x.name, msg);
    }
#else
    feat_set(F_ZSTD, RES_NA, "not linked: sysroot library not found at build time");
    feat_set(F_LZ4, RES_NA, "not linked: sysroot library not found at build time");
    feat_set(F_SQLITE, RES_NA, "not linked: sysroot library not found at build time");
    L.add(RES_NA, "zstd, lz4, sqlite: not linked in this build (sysroot missing, see README)");
#endif

    /* shared library: exclusive only in Native 1.0 */
    nxn_lib* lib = NULL;
    nxn_result r = nxn_lib_open("greet", "1.0", &lib);
    if (r == NXN_OK) {
        typedef const char* (*hello_fn)(void);
        hello_fn hello = (hello_fn)nxn_lib_sym(lib, "greet_hello");
        const char* text = hello ? hello() : NULL;
        int ok = text && strstr(text, "greet.nxvlib");
        feat_set(F_NXVLIB, ok ? RES_OK : RES_FAIL, "%s %s: %s", nxn_lib_name(lib), nxn_lib_version(lib), text ? text : "no greet_hello");
        L.add(ok ? RES_OK : RES_FAIL, "nxn_lib_open(greet): %s", text ? text : "greet_hello missing");
        nxn_lib_close(lib);
    } else if (g_windowed && r == NXN_ERR_UNSUPPORTED) {  // setting native.windowedLibs off, or an older Nexvyn OS
        feat_set(F_NXVLIB, RES_NA, "not supported in windowed mode (NXN_ERR_UNSUPPORTED): %s", nxn_lib_error());
        L.add(RES_NA, "nxn_lib_open in a window: UNSUPPORTED (%s)", nxn_lib_error());
    } else {
        feat_set(F_NXVLIB, RES_FAIL, "nxn_lib_open -> %d: %s", (int)r, nxn_lib_error());
        L.add(RES_FAIL, "nxn_lib_open -> %d: %s", (int)r, nxn_lib_error());
    }
#ifdef SHOWCASE_COMPAT
    if (g_windowed && !(g_caps.features & NXN_CAP_SHARED_LIBS)) {  // libraries off in this window: dlopen fails cleanly
        void* h = dlopen("libgreet.so", RTLD_NOW);
        const char* e = h ? NULL : dlerror();
        feat_set(F_DLOPEN, RES_NA, "not supported in a window yet (dlopen -> NULL: %s)", e ? e : "?");
        L.add(RES_NA, "dlopen in a window: not supported yet (%s)", e ? e : "?");
        if (h) dlclose(h);
    } else {
        int rc = sc_c_dlopen(msg, sizeof msg);
        feat_set(F_DLOPEN, rc ? RES_OK : RES_FAIL, "%s", msg);
        L.add(rc ? RES_OK : RES_FAIL, "dlopen: %s", msg);
    }
#else
    L.add(RES_NA, "dlopen: compat layer, exclusive mode only");
#endif
}

/* the name of the test that is running goes to <data>/showcase_stage.txt first: if a test hangs, this file says which */
void stage(const char* name) {
    nxn_log(NXN_LOG_INFO, "showcase: stage %s", name);
    nxn_fs_write(NXN_DIR_DATA, "showcase_stage.txt", name, strlen(name));
}

void tests_run_all(void) {
    stage("core");
    test_core();
    stage("files");
    test_files();
    stage("system");
    test_system();
    test_mixer_actions();
    stage("ui");
    test_ui();
    stage("threads");
    test_threads();
    stage("compat");
    test_compat();
    stage("libs");
    test_libs();
    stage("runtime");
    test_runtime();
    stage("done");
}

/* ---------------------------------------------------------------- report */
int report_write(const char* header) {
    static char buf[16384];
    int n = snprintf(buf, sizeof buf, "Native SDK Showcase report\n%s\n\n", header ? header : "");
    int ok = 0, fail = 0, na = 0, todo = 0, pend = 0;
    for (int i = 0; i < F_COUNT && n < (int)sizeof buf - 300; i++) {
        const Feature& f = g_feat[i];
        n += snprintf(buf + n, sizeof buf - n, "%-10s | %-44s | %c | %-15s | %s\n", f.group, f.name, f.modes, res_text(f.res), f.note);
        switch (f.res) {
        case RES_OK: ok++; break;
        case RES_FAIL: fail++; break;
        case RES_NA: na++; break;
        case RES_TODO: todo++; break;
        default: pend++; break;
        }
    }
    n += snprintf(buf + n, sizeof buf - n, "\nTOTAL: ok %d, fail %d, not available %d, not implemented %d, not run %d\n", ok, fail, na,
                  todo, pend);
    nxn_result r = nxn_fs_write(NXN_DIR_DATA, "showcase_report.txt", buf, (size_t)n);
    g_feat_dirty = 0;
    return r == NXN_OK;
}

/* ---------------------------------------------------------------- lifecycle actions */
/* an unmapped address behind a volatile pointer, so the compiler keeps the faulting store */
static volatile int* volatile g_bad = (volatile int*)8;

/* a 4-deep call chain (never inlined) so a crash report shows a real backtrace: crash_level3 <- 2 <- 1 <- the caller */
static __attribute__((noinline)) void crash_level3(int how) {
    if (how == 1) abort();
    *g_bad = how;
}
static __attribute__((noinline)) void crash_level2(int how) { crash_level3(how); g_bad = g_bad; }
static __attribute__((noinline)) void crash_level1(int how) { crash_level2(how); g_bad = g_bad; }
static __attribute__((noinline)) void crash_deep(int how) { crash_level1(how); g_bad = g_bad; }

static void crash_thread_fn(void*) {
    nxn_log(NXN_LOG_WARN, "showcase: worker crashes on purpose");
    nxn_sleep_ns(200 * 1000000ull);
    crash_deep(0);
}

void action_crash_worker(void) {
    feat_set(F_CRASH_WORKER, RES_PEND, "crash requested; if you read this, check the Nexvyn OS crash report");
    report_write("crash worker requested");
    nxn_thread_params p = NXN_STRUCT_INIT(nxn_thread_params);
    p.fn = crash_thread_fn;
    p.name = "showcase-crash";
    nxn_thread* t = NULL;
    nxn_thread_start(&p, &t);
}

/* abort() on a worker thread while the main thread runs on: the same window state as a worker fault, for emulators,
 * which stop the whole program on a real fault (Nexvyn OS setting native.windowedSimFault turns abort into a fault) */
static void crash_abort_thread_fn(void*) {
    nxn_log(NXN_LOG_WARN, "showcase: worker abort() on purpose");
    nxn_sleep_ns(200 * 1000000ull);
    crash_deep(1);
}

void action_crash_worker_abort(void) {
    feat_set(F_CRASH_WORKER, RES_PEND, "worker abort() requested; check the Nexvyn OS crash report");
    report_write("crash worker abort requested");
    nxn_thread_params p = NXN_STRUCT_INIT(nxn_thread_params);
    p.fn = crash_abort_thread_fn;
    p.name = "showcase-crash";
    nxn_thread* t = NULL;
    nxn_thread_start(&p, &t);
}

void action_crash_main(void) {
    feat_set(F_CRASH_MAIN, RES_PEND, "crash requested; the app should end and Nexvyn OS should report it");
    report_write("crash main requested");
    nxn_log(NXN_LOG_WARN, "showcase: main thread crashes on purpose");
    crash_deep(0);
}

void action_crash_abort(void) {
    feat_set(F_CRASH_MAIN, RES_PEND, "abort() requested; the app should end and the report should show a backtrace");
    report_write("crash abort requested");
    nxn_log(NXN_LOG_WARN, "showcase: abort() on purpose");
    crash_deep(1);
}

void action_hang(int seconds) {
    feat_set(F_HANG, RES_PEND, "hang of %d s requested; Nexvyn OS should show 'not responding'", seconds);
    report_write("hang requested");
    nxn_log(NXN_LOG_WARN, "showcase: hanging %d s on purpose", seconds);
    uint64_t end = nxn_time_ns() + (uint64_t)seconds * 1000000000ull;
    while (nxn_time_ns() < end) {
    }
    feat_set(F_HANG, RES_OK, "survived a %d s hang (no forced stop)", seconds);
}

void action_quit42(void) {
    feat_set(F_RETURN, RES_PEND, "returning with code 42 (check Nexvyn OS for the exit record)");
    report_write("quit 42 requested");
    nxn_request_return(NXN_RETURN_NORMAL, 42, NULL);
}
