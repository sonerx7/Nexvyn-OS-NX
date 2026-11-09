// Links stl_heavy.cpp into a windowed module and logs its result (clang spike, point 5).
#include <nexvyn/nexvyn_native.h>

int stl_heavy(const char* text);

static int app_main(int, char**) {
    int r = stl_heavy("key=42");
    nxn_log(NXN_LOG_INFO, "clangprobe: stl_heavy returned %d", r);
    nxn_request_return(NXN_RETURN_NORMAL, 7, nullptr);
    return 7;
}

int main(int argc, char** argv) { return nxn_run(argc, argv, app_main, nullptr); }
