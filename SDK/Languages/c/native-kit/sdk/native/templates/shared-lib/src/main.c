/* @TITLE@ - loads greet.nxvlib at run time with nxn_lib_open and calls into it (template "shared-lib").
 *
 * The library is looked up next to this .nro, then in <data>/lib/. Every failure (missing file, wrong version,
 * no JIT memory in applet mode, an import the app does not export) is an error message, never a crash.
 *   +  return to Nexvyn OS
 * Self-test: when <data>/autotest exists the app writes its result to <data>/shared-lib.txt and returns at once with
 * code 7 (loaded and called) or 8 (failed). */
#include <nexvyn/nexvyn_native.h>
#include <switch.h>
#include <stdio.h>
#include <string.h>

#include "greet.h"

static int try_library(char* report, size_t size) {
    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    nxn_caps_get(&caps);
    if (!(caps.features & NXN_CAP_SHARED_LIBS))
        snprintf(report, size, "note: NXN_CAP_SHARED_LIBS is off (applet mode?), loading will explain why\n");
    nxn_lib* lib = NULL;
    if (nxn_lib_open("greet", "1.0", &lib) != NXN_OK) {
        snprintf(report + strlen(report), size - strlen(report), "nxn_lib_open failed: %s\n", nxn_lib_error());
        return 0;
    }
    greet_hello_fn hello = (greet_hello_fn)nxn_lib_sym(lib, "greet_hello");
    greet_format_fn format = (greet_format_fn)nxn_lib_sym(lib, "greet_format");
    if (!hello || !format) {
        snprintf(report + strlen(report), size - strlen(report), "missing function: %s\n", nxn_lib_error());
        nxn_lib_close(lib);
        return 0;
    }
    char line[96];
    format(line, sizeof line, "Nexvyn");
    format(line, sizeof line, "Nexvyn");
    snprintf(report + strlen(report), size - strlen(report), "%s %s\n%s\n%s\n", nxn_lib_name(lib), nxn_lib_version(lib),
             hello(), line);
    nxn_lib_close(lib);
    return strstr(line, "(call 2)") != NULL;
}

static int app_main(int argc, char** argv) {
    char probe[8];
    size_t got = 0;
    int autotest = nxn_fs_read(NXN_DIR_DATA, "autotest", probe, sizeof probe, &got) == NXN_OK;
    char report[1024] = "";
    int ok = try_library(report, sizeof report);
    nxn_log(ok ? NXN_LOG_INFO : NXN_LOG_ERROR, "%s", report);
    if (autotest) {
        nxn_fs_write(NXN_DIR_DATA, "shared-lib.txt", report, strlen(report));
        nxn_request_return(NXN_RETURN_NORMAL, ok ? 7 : 8, NULL);
        return 0;
    }
#ifdef NEXVYN_WINDOWED
    /* windowed build (`nxv-native build --windowed`): no text console in a window. The report is in the app's log; the
     * window is green when the library was loaded and called, red otherwise (Native SDK 1.0 loads .nxvlib libraries in
     * exclusive mode only, so a windowed build reports NXN_ERR_UNSUPPORTED). + closes it. */
    nxn_display* d = NULL;
    void (*clear_color)(float, float, float, float) = NULL;
    void (*clear)(unsigned) = NULL;
    if (nxn_display_open(NULL, &d) == NXN_OK) {
        clear_color = (void (*)(float, float, float, float))nxn_display_proc("glClearColor");
        clear = (void (*)(unsigned))nxn_display_proc("glClear");
    }
    while (!nxn_should_quit()) {
        nxn_input_state in = NXN_STRUCT_INIT(nxn_input_state);
        nxn_input_poll(&in);
        if (in.pressed & NXN_BTN_PLUS) break;
        if (d && clear_color && clear) {
            clear_color(ok ? .1f : .6f, ok ? .5f : .1f, .2f, 1.f);
            clear(0x4000 /* GL_COLOR_BUFFER_BIT */);
            nxn_display_swap(d);
        } else {
            nxn_sleep_ns(16000000);
        }
    }
    if (d) nxn_display_close(d);
    return 0;
#endif
    consoleInit(NULL);
    padConfigureInput(1, HidNpadStyleSet_NpadStandard);
    PadState pad;
    padInitializeDefault(&pad);
    printf("@TITLE@ - shared library template\n\n%s\n%s\n\nPress + to return.\n", report, ok ? "OK" : "FAILED");
    while (appletMainLoop() && !nxn_should_quit()) {
        padUpdate(&pad);
        if (padGetButtonsDown(&pad) & HidNpadButton_Plus) break;
        consoleUpdate(NULL);
    }
    consoleExit(NULL);
    return 0;
}

int main(int argc, char** argv) { return nxn_run(argc, argv, app_main, NULL); }
