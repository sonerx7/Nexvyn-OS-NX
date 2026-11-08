/* rtlib.nxvlib - the C/C++ runtime self-test library of the Showcase (W2a): thread_local data (.tdata and .tbss) and
 * C++ exceptions inside a shared library. The C++ runtime (operator new, std::runtime_error, the exception
 * machinery) comes from the app that loads it, so there is one copy of it. */
#include <stdexcept>

static thread_local int t_count = 100; /* .tdata: every thread starts at 100 */
static __thread int t_zero;            /* .tbss: every thread starts at 0 */
static __thread char t_name[16] = "rtlib";

extern "C" int* rtlib_tls_count(void) { return &t_count; }
extern "C" int* rtlib_tls_zero(void) { return &t_zero; }
extern "C" const char* rtlib_tls_name(void) { return t_name; }

/* throws out of the library: the app catches it */
extern "C" void rtlib_throw(int code) { throw std::runtime_error(code == 7 ? "rtlib seven" : "rtlib other"); }

/* throw and catch inside the library (its frames, the app's exception machinery) */
extern "C" int rtlib_catch_inside(void) {
    try {
        throw 42;
    } catch (int v) {
        return v;
    }
    return -1;
}
