// Native Tour, "Runtime" page checks. Built with -fexceptions -frtti (the rest of the app has neither).
//   * C++ exceptions: needs setting native.windowedEh (NXN_CAP_CXX_EXCEPTIONS); without it a throw would end in
//     std::terminate, so nothing is thrown and the row says "not available"
//   * thread_local lives in tourlib.nxvlib: needs native.windowedLibs and native.windowedTls
#include <stdexcept>
#include <stdio.h>
#include <string.h>
#include <nexvyn/nexvyn_native.h>
#include "tour.h"

namespace {

typedef int* (*ptr_fn)(void);
ptr_fn g_count, g_zero;
const char* (*g_name)(void);

struct ThreadRes {
    int id;
    int ok;
    int val;
};

void tls_thread(void* p) {
    ThreadRes* r = (ThreadRes*)p;
    int* c = g_count();
    int* z = g_zero();
    int first = *c == 100 && *z == 0 && !strcmp(g_name(), "tourlib");
    *c = 1000 + r->id;
    *z = r->id + 1;
    nxn_sleep_ns(30 * 1000000ull);  // the other threads write their own values meanwhile
    r->val = *g_count();
    r->ok = first && r->val == 1000 + r->id && *g_zero() == r->id + 1;
}

__attribute__((noinline)) void thrower(int v) {
    if (v == 1) throw std::runtime_error("tour exception");
    if (v == 2) throw 7;
}

RtRow& add(RtReport& R, Res res, const char* label) {
    RtRow& r = R.rows[R.n++];
    r.res = res;
    r.label = label;
    r.detail[0] = 0;
    return r;
}

}  // namespace

void rt_run(RtReport& R, uint64_t feat) {
    memset(&R, 0, sizeof R);
    bool eh = (feat & NXN_CAP_CXX_EXCEPTIONS) != 0;
    bool tls = (feat & NXN_CAP_TLS) != 0;
    bool libs = (feat & NXN_CAP_SHARED_LIBS) != 0;

    // 1. exceptions in the app
    RtRow& e = add(R, eh ? RES_OK : RES_NA, "rt.eh");
    if (eh) {
        int caught = 0;
        char what[48] = "";
        try {
            thrower(1);
        } catch (const std::runtime_error& ex) {
            caught++;
            snprintf(what, sizeof what, "%s", ex.what());
        }
        try {
            thrower(2);
        } catch (int v) {
            caught += v == 7;
        }
        try {
            try {
                thrower(1);
            } catch (...) {
                throw;  // rethrown, caught outside
            }
        } catch (const std::exception&) {
            caught++;
        }
        e.res = caught == 3 ? RES_OK : RES_FAIL;
        snprintf(e.detail, sizeof e.detail, "%d/3 caught: runtime_error \"%s\", int, rethrown", caught, what);
    }

    // 2. the library
    nxn_lib* lib = NULL;
    nxn_result r = libs ? nxn_lib_open("tourlib", "1.0", &lib) : NXN_ERR_UNSUPPORTED;
    RtRow& lo = add(R, r == NXN_OK ? RES_OK : (libs ? RES_FAIL : RES_NA), "rt.lib");
    if (r != NXN_OK) {
        if (libs) snprintf(lo.detail, sizeof lo.detail, "%s", nxn_lib_error());
        add(R, RES_NA, "rt.tls");
        add(R, RES_NA, "rt.ehlib");
        return;
    }
    const char* (*hello)(void) = (const char* (*)(void))nxn_lib_sym(lib, "tourlib_hello");
    int (*greet)(char*, size_t, const char*) = (int (*)(char*, size_t, const char*))nxn_lib_sym(lib, "tourlib_greet");
    snprintf(R.lib_version, sizeof R.lib_version, "%s", nxn_lib_version(lib) ? nxn_lib_version(lib) : "?");
    if (hello) snprintf(R.hello, sizeof R.hello, "%s", hello());
    if (greet) greet(R.greeting, sizeof R.greeting, "Nexvyn");
    lo.res = hello && greet ? RES_OK : RES_FAIL;
    snprintf(lo.detail, sizeof lo.detail, "%s %s: %s", nxn_lib_name(lib) ? nxn_lib_name(lib) : "tourlib", R.lib_version, R.hello);

    // 3. thread_local on three threads
    g_count = (ptr_fn)nxn_lib_sym(lib, "tourlib_tls_count");
    g_zero = (ptr_fn)nxn_lib_sym(lib, "tourlib_tls_zero");
    g_name = (const char* (*)(void))nxn_lib_sym(lib, "tourlib_tls_name");
    RtRow& t = add(R, tls ? RES_OK : RES_NA, "rt.tls");
    if (tls && g_count && g_zero && g_name) {
        *g_count() = 1;  // the main thread's own value must survive the workers
        ThreadRes res[3] = {{0, 0, 0}, {1, 0, 0}, {2, 0, 0}};
        nxn_thread* th[3] = {};
        for (int i = 0; i < 3; i++) {
            nxn_thread_params p = NXN_STRUCT_INIT(nxn_thread_params);
            p.fn = tls_thread;
            p.arg = &res[i];
            p.name = "tour-tls";
            nxn_thread_start(&p, &th[i]);
        }
        for (int i = 0; i < 3; i++)
            if (th[i]) nxn_thread_join(th[i]);
        for (int i = 0; i < 3; i++) R.tls_vals[i] = res[i].val;
        bool ok = res[0].ok && res[1].ok && res[2].ok && *g_count() == 1;
        t.res = ok ? RES_OK : RES_FAIL;
        snprintf(t.detail, sizeof t.detail, "3 threads, own values %d / %d / %d; main thread kept %d", res[0].val, res[1].val,
                 res[2].val, *g_count());
    } else if (tls) {
        t.res = RES_FAIL;
        snprintf(t.detail, sizeof t.detail, "tourlib symbols missing");
    }

    // 4. an exception thrown inside the library and caught here
    void (*thr)(int) = (void (*)(int))nxn_lib_sym(lib, "tourlib_throw");
    int (*inside)(void) = (int (*)(void))nxn_lib_sym(lib, "tourlib_catch_inside");
    RtRow& x = add(R, eh ? RES_OK : RES_NA, "rt.ehlib");
    if (eh && thr && inside) {
        int caught = 0;
        try {
            thr(7);
        } catch (const std::runtime_error& ex) {
            caught = !strcmp(ex.what(), "tourlib seven");
        }
        int in = inside();
        x.res = caught && in == 42 ? RES_OK : RES_FAIL;
        snprintf(x.detail, sizeof x.detail, "thrown in the library, caught in the app: %d; inside the library: %d", caught, in);
    } else if (eh) {
        x.res = RES_FAIL;
        snprintf(x.detail, sizeof x.detail, "tourlib symbols missing");
    }
    nxn_lib_close(lib);
}
