/* tourlib.nxvlib - the Tour's small shared library: thread_local data, a greeting and C++ exceptions. Only C types cross
 * the boundary (extern "C"); the C++ runtime comes from the app that loads it, so there is one copy of it. */
#include <stdexcept>
#include <stdio.h>

static thread_local int t_count = 100;  /* .tdata: every thread starts at 100 */
static __thread int t_zero;             /* .tbss: every thread starts at 0 */
static __thread char t_name[16] = "tourlib";
static int g_calls;

extern "C" int* tourlib_tls_count(void) { return &t_count; }
extern "C" int* tourlib_tls_zero(void) { return &t_zero; }
extern "C" const char* tourlib_tls_name(void) { return t_name; }

extern "C" const char* tourlib_hello(void) { return "Hello from tourlib.nxvlib"; }

extern "C" int tourlib_greet(char* out, size_t size, const char* who) {
    g_calls++;
    return snprintf(out, size, "Hello, %s! (call %d)", who ? who : "?", g_calls);
}

/* thrown out of the library: the app catches it */
extern "C" void tourlib_throw(int code) { throw std::runtime_error(code == 7 ? "tourlib seven" : "tourlib other"); }

/* thrown and caught inside the library */
extern "C" int tourlib_catch_inside(void) {
    try {
        throw 42;
    } catch (int v) {
        return v;
    }
    return -1;
}
