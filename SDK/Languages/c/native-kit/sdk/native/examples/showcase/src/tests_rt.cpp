/* Showcase: the C/C++ runtime in a window (W2a). Compiled with exceptions and RTTI (the rest of the Showcase is not).
 * Each row needs its capability (NXN_CAP_CXX_EXCEPTIONS, NXN_CAP_TLS, NXN_CAP_SHARED_LIBS); without it the row says
 * "not available" and nothing that would end the app runs. thread_local lives in rtlib.nxvlib, so the module itself
 * has no PT_TLS and still loads where windowed thread_local is off. */
#include "showcase.h"
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <stdexcept>
#include <string>

extern nxn_caps g_caps;

namespace {

struct MyError : std::logic_error {
    int code;
    MyError(const char* m, int c) : std::logic_error(m), code(c) {}
};

int g_dtors;
struct Guard {
    ~Guard() { g_dtors++; }
};

[[gnu::noinline]] void deep(int n) {
    Guard g;
    if (n == 0) throw MyError("deep", 3);
    deep(n - 1);
}

int eh_basic(char* msg, size_t n) {
    int score = 0;
    try {  // a derived std::exception through 4 frames with destructors
        g_dtors = 0;
        deep(3);
    } catch (const std::exception& e) {
        const MyError* m = dynamic_cast<const MyError*>(&e);
        if (m && m->code == 3 && g_dtors == 4 && !strcmp(e.what(), "deep")) score++;
    }
    try {  // nested: caught, rethrown as another type, caught outside
        try {
            throw MyError("inner", 1);
        } catch (const MyError& e) {
            throw std::runtime_error(std::string("outer(") + e.what() + ")");
        }
    } catch (const std::runtime_error& e) {
        if (!strcmp(e.what(), "outer(inner)")) score++;
    }
    try {  // rethrow of the same object
        try {
            throw 5;
        } catch (int) {
            throw;
        }
    } catch (int v) {
        if (v == 5) score++;
    }
    snprintf(msg, n, "derived + 4 destructors, nested, rethrow: %d/3", score);
    return score == 3;
}

struct ThreadRes {
    int id, ok;
    int* where;
};

typedef int* (*ptr_fn)(void);
ptr_fn g_tls_count, g_tls_zero;
const char* (*g_tls_name)(void);

void tls_thread(void* p) {
    ThreadRes* r = (ThreadRes*)p;
    int* c = g_tls_count();
    int* z = g_tls_zero();
    int first = *c == 100 && *z == 0 && !strcmp(g_tls_name(), "rtlib");
    *c = 1000 + r->id;
    *z = r->id + 1;
    nxn_sleep_ns(30 * 1000000ull);  // the other threads write theirs meanwhile
    r->ok = first && *g_tls_count() == 1000 + r->id && *g_tls_zero() == r->id + 1;
    r->where = c;
}

}  // namespace

/* W2b / W3a. JIT: a tiny function written as machine code (mov w0, #42; ret), run from the rx view. The fault handler
 * and guard pages are only registered / set and lifted again: a real fault is never made here (emulators stop the
 * whole program on one); the console check list is in NATIVE_KIT.en.md 3.2.11. */
static int fault_noop(nxn_fault* f, void* user) {
    (void)f;
    (void)user;
    return 0;  // never fixes anything: a fault still ends the app as before
}

static void test_menu(Lines& L);

static void test_jit(Lines& L) {
    if (!(g_caps.features & NXN_CAP_JIT)) {
        nxn_jit* j = NULL;
        nxn_result r = nxn_jit_create(4096, &j);  // must answer UNSUPPORTED, never crash
        Res res = r == NXN_ERR_UNSUPPORTED && !j ? RES_NA : RES_FAIL;
        feat_set(F_JIT, res, "off in this window (setting native.windowedJit), create answered %d", (int)r);
        L.add(res, "JIT: not available (%d)", (int)r);
    } else {
        nxn_jit* j = NULL;
        nxn_result r = nxn_jit_create(4096, &j);
        nxn_jit_info in = NXN_STRUCT_INIT(nxn_jit_info);
        int v = -1;
        if (r == NXN_OK && nxn_jit_get(j, &in) == NXN_OK && in.rw && in.rx && in.bytes >= 4096) {
            static const uint32_t code[] = {0x52800540u /* mov w0, #42 */, 0xd65f03c0u /* ret */};
            nxn_jit_begin_write(j);
            memcpy(in.rw, code, sizeof code);
            nxn_jit_end_write(j, 0, sizeof code);
            v = ((int (*)(void))in.rx)();
        }
        nxn_jit_destroy(j);
        Res res = v == 42 ? RES_OK : RES_FAIL;
        feat_set(F_JIT, res, "create %d, rw %p, rx %p, result %d", (int)r, in.rw, in.rx, v);
        L.add(res, "JIT: %s (result %d)", v == 42 ? "code ran" : "failed", v);
    }
    bool fh = g_caps.features & NXN_CAP_FAULT_HANDLER, gp = g_caps.features & NXN_CAP_GUARD_PAGES;
    nxn_result rf = nxn_fault_handler_set(fault_noop, NULL);
    nxn_fault_handler_set(NULL, NULL);
    nxn_result rg = NXN_ERR_UNSUPPORTED;
    if (gp) {
        void* blk = aligned_alloc(4096, 8192);
        rg = blk ? nxn_mem_guard(blk, 4096, 4096, NXN_GUARD_READONLY) : NXN_ERR_NO_MEMORY;
        if (rg == NXN_OK) rg = nxn_mem_guard(blk, 4096, 4096, NXN_GUARD_OFF);  // lifted before anything touches it
        free(blk);
    } else {
        rg = nxn_mem_guard(NULL, 0, 4096, NXN_GUARD_NOACCESS);
    }
    bool ok = (fh ? rf == NXN_OK : rf == NXN_ERR_UNSUPPORTED) &&
              (gp ? (rg == NXN_OK || rg == NXN_ERR_UNSUPPORTED) : rg == NXN_ERR_UNSUPPORTED);
    Res res = !ok ? RES_FAIL : (fh || gp) ? RES_OK : RES_NA;
    feat_set(F_FAULT, res, "handler %d (cap %d), guard %d (cap %d); a real fault is a console test", (int)rf, (int)fh,
             (int)rg, (int)gp);
    L.add(res, "fault handler %d, guard pages %d", (int)rf, (int)rg);
    test_menu(L);
}

/* Window menu: with the setting off the calls answer UNSUPPORTED (NXN_CAP_MENU not set); with it on a menu is set (the
 * labels are lang keys), a bad spec is refused and leaves the menu alone, then the menu is cleared. A pick needs a click on
 * the OS menu bar: a console test, it arrives as NXN_EVENT_MENU (main.cpp logs it). */
static void test_menu(Lines& L) {
    nxn_menu_item items[3] = {{sizeof(nxn_menu_item), 1, "menu.about", "Ctrl+I", 0, 0},
                              {sizeof(nxn_menu_item), 0, NULL, NULL, NXN_MENU_SEPARATOR, 0},
                              {sizeof(nxn_menu_item), 2, "menu.toggle", NULL, NXN_MENU_CHECKED, 0}};
    nxn_menu_menu m = {sizeof(nxn_menu_menu), "menu.title", items, 3, sizeof(nxn_menu_item)};
    nxn_menu_spec s = {sizeof(nxn_menu_spec), &m, 1, sizeof(nxn_menu_menu)};
    nxn_result r = nxn_menu_set(&s);
    if (!(g_caps.features & NXN_CAP_MENU)) {
        Res res = r == NXN_ERR_UNSUPPORTED && nxn_menu_clear() == NXN_ERR_UNSUPPORTED ? RES_NA : RES_FAIL;
        feat_set(F_MENU, res, "off in this window (setting native.windowMenu), set answered %d", (int)r);
        L.add(res, "window menu: not available (%d)", (int)r);
        return;
    }
    items[2].id = 1;  // duplicate id
    nxn_result bad = nxn_menu_set(&s);
    items[2].id = 2;
    m.item_count = NXN_MENU_MAX_ITEMS + 1;  // too many items
    nxn_result many = nxn_menu_set(&s);
    m.item_count = 3;
    nxn_result clr = nxn_menu_clear();
    Res res = r == NXN_OK && bad == NXN_ERR_INVALID && many == NXN_ERR_INVALID && clr == NXN_OK ? RES_OK : RES_FAIL;
    nxn_menu_set(&s);  // left in place for the console check (a pick is logged as NXN_EVENT_MENU)
    feat_set(F_MENU, res, "set %d, duplicate id %d, too many %d, clear %d; a pick is a console test", (int)r, (int)bad,
             (int)many, (int)clr);
    L.add(res, "window menu: set %d, bad %d/%d, clear %d", (int)r, (int)bad, (int)many, (int)clr);
}

void test_runtime(void) {
    Lines& L = g_lines[L_LIBS];
    char msg[200];
    if (g_windowed) test_jit(L);
    else {  /* the retired stand-alone .nro: not tested here */
        feat_set(F_JIT, RES_NA, "windowed rows only");
        feat_set(F_FAULT, RES_NA, "windowed rows only");
    }
    bool eh = g_caps.features & NXN_CAP_CXX_EXCEPTIONS;
    bool tls = g_caps.features & NXN_CAP_TLS;
    bool libs = g_caps.features & NXN_CAP_SHARED_LIBS;
    if (!g_windowed) {  // the retired stand-alone .nro: exceptions always worked, its loader refuses thread_local libraries
        eh = libs = true;
        tls = false;
    }

    if (eh) {
        stage("runtime: exceptions");
        int ok = eh_basic(msg, sizeof msg);
        feat_set(F_EH, ok ? RES_OK : RES_FAIL, "%s", msg);
        L.add(ok ? RES_OK : RES_FAIL, "C++ exceptions: %s", msg);
    } else {
        feat_set(F_EH, RES_NA, "off in this window (setting native.windowedEh)");
    }

    stage("runtime: rtlib.nxvlib");
    nxn_lib* lib = NULL;
    nxn_result r = libs ? nxn_lib_open("rtlib", "1.0", &lib) : NXN_ERR_UNSUPPORTED;
    if (r != NXN_OK) {
        const char* why = libs ? nxn_lib_error() : "shared libraries are off in this window (setting native.windowedLibs)";
        // thread_local in a library needs both switches: a refused PT_TLS is the expected answer when only libs are on
        Res res = libs && tls ? RES_FAIL : RES_NA;
        feat_set(F_TLS, res, "rtlib.nxvlib not loaded: %s", why);
        feat_set(F_TLS_LIB_EH, res, "rtlib.nxvlib not loaded: %s", why);
        L.add(res, "rtlib.nxvlib: %s", why);
        return;
    }
    g_tls_count = (ptr_fn)nxn_lib_sym(lib, "rtlib_tls_count");
    g_tls_zero = (ptr_fn)nxn_lib_sym(lib, "rtlib_tls_zero");
    g_tls_name = (const char* (*)(void))nxn_lib_sym(lib, "rtlib_tls_name");
    if (tls && g_tls_count && g_tls_zero && g_tls_name) {
        stage("runtime: thread_local");
        *g_tls_count() = 1;  // the main thread's own value must survive the workers
        ThreadRes res[3] = {{0, 0, NULL}, {1, 0, NULL}, {2, 0, NULL}};
        nxn_thread* th[3] = {};
        for (int i = 0; i < 3; i++) {
            nxn_thread_params p = NXN_STRUCT_INIT(nxn_thread_params);
            p.fn = tls_thread;
            p.arg = &res[i];
            p.name = "showcase-tls";
            nxn_thread_start(&p, &th[i]);
        }
        for (int i = 0; i < 3; i++)
            if (th[i]) nxn_thread_join(th[i]);
        int ok = res[0].ok && res[1].ok && res[2].ok && *g_tls_count() == 1 && res[0].where != res[1].where &&
                 res[1].where != res[2].where && res[0].where != res[2].where;
        snprintf(msg, sizeof msg, "3 threads own values %d/%d/%d, main kept %d, .tdata 100 + .tbss 0 at start", res[0].ok,
                 res[1].ok, res[2].ok, *g_tls_count());
        feat_set(F_TLS, ok ? RES_OK : RES_FAIL, "%s", msg);
        L.add(ok ? RES_OK : RES_FAIL, "thread_local (rtlib.nxvlib): %s", msg);
    } else {
        feat_set(F_TLS, tls ? RES_FAIL : RES_NA, "%s",
                 tls ? "rtlib symbols missing" : "off in this window (setting native.windowedTls)");
    }
    void (*thr)(int) = (void (*)(int))nxn_lib_sym(lib, "rtlib_throw");
    int (*inside)(void) = (int (*)(void))nxn_lib_sym(lib, "rtlib_catch_inside");
    if (eh && thr && inside) {
        stage("runtime: library exceptions");
        int caught = 0;
        try {
            thr(7);
        } catch (const std::runtime_error& e) {
            caught = !strcmp(e.what(), "rtlib seven");
        }
        int in = inside();
        snprintf(msg, sizeof msg, "thrown in the library, caught in the app: %d; inside the library: %d", caught, in);
        feat_set(F_TLS_LIB_EH, caught && in == 42 ? RES_OK : RES_FAIL, "%s", msg);
        L.add(caught && in == 42 ? RES_OK : RES_FAIL, "exceptions across rtlib.nxvlib: %s", msg);
    } else {
        feat_set(F_TLS_LIB_EH, eh ? RES_FAIL : RES_NA, "%s",
                 eh ? "rtlib symbols missing" : "off in this window (setting native.windowedEh)");
    }
    nxn_lib_close(lib);
}

/* <data>/throwtest: an exception nobody catches. The app must end as a crash (std::terminate -> abort) and Nexvyn OS
 * must go on. */
void action_throw_uncaught(void) {
    nxn_log(NXN_LOG_WARN, "showcase: throwing an exception nobody catches");
    throw std::runtime_error("showcase: uncaught on purpose");
}
