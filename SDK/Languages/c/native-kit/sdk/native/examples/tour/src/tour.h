// Native Tour: shared types between main.cpp (no exceptions) and tour_rt.cpp (built with -fexceptions -frtti).
#ifndef TOUR_H
#define TOUR_H
#include <stdint.h>

enum Res { RES_PENDING = 0, RES_OK = 1, RES_NA = 2, RES_FAIL = 3 };

struct RtRow {
    Res res;
    const char* label;  // lang key
    char detail[160];
};

struct RtReport {
    RtRow rows[6];
    int n;
    int tls_vals[3];      // what each of the three threads read back (0 when not run)
    char lib_version[24];
    char hello[96];
    char greeting[96];
};

// Runs the runtime checks (thread_local in a library, C++ exceptions, nxn_lib_open). `features` is nxn_caps.features.
// Only paths that can succeed run: a missing switch is reported as RES_NA, never provoked.
void rt_run(RtReport& out, uint64_t features);

#endif
