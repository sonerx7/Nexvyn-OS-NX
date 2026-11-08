/* greet.nxvlib - a tiny shared library. snprintf comes from the app that loads it (one C library, one heap); the
 * call counter is the library's own data. */
#include "greet.h"
#include <stdio.h>

static int g_calls;
static int g_started;

/* runs when the library is loaded (the loader calls .init_array) */
__attribute__((constructor)) static void greet_start(void) { g_started = 1; }

const char* greet_hello(void) { return g_started ? "Hello from greet.nxvlib" : "greet.nxvlib: constructor did not run"; }

int greet_format(char* out, size_t size, const char* who) {
    g_calls++;
    return snprintf(out, size, "Hello, %s! (call %d)", who ? who : "?", g_calls);
}
