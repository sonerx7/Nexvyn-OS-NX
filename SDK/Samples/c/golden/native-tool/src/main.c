/* Dynamic-library probe: C boundary, errors logged, all handles closed. */
#include <nexvyn/nexvyn_native.h>
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
    (void)argc; (void)argv;
    char report[1024] = "";
    int ok = try_library(report, sizeof report);
    nxn_log(ok ? NXN_LOG_INFO : NXN_LOG_ERROR, "%s", report);
    nxn_window_set_title(nxn_tr("title"), nxn_tr(ok ? "success" : "error"));
    nxn_display* d = NULL;
    if (nxn_display_open(NULL, &d) != NXN_OK) return 1;
    void (*color)(float,float,float,float) = (void (*)(float,float,float,float))nxn_display_proc("glClearColor");
    void (*clear)(unsigned) = (void (*)(unsigned))nxn_display_proc("glClear");
    if (!color || !clear) { nxn_display_close(d); return 1; }
    uint32_t pending_w = 0, pending_h = 0;
    int suspended = 0, focused = 1, quit = 0;
    while (!quit && !nxn_should_quit()) {
        nxn_event e = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&e) > 0) {
            if (e.type == NXN_EVENT_QUIT) quit = 1;
            if (e.type == NXN_EVENT_RESIZE) { pending_w=e.width; pending_h=e.height; }
            if (e.type == NXN_EVENT_SUSPEND) suspended=1;
            if (e.type == NXN_EVENT_RESUME) suspended=0;
            if (e.type == NXN_EVENT_FOCUS) focused=e.focused != 0;
            if (e.type == NXN_EVENT_LANGUAGE) nxn_window_set_title(nxn_tr("title"), nxn_tr(ok ? "success" : "error"));
            e = (nxn_event)NXN_STRUCT_INIT(nxn_event);
        }
        if (quit) break;
        if (suspended || !focused) { nxn_sleep_ns(16000000); continue; }
        if (pending_w && pending_h) {
            nxn_result r=nxn_display_resize(d,pending_w,pending_h);
            if (r != NXN_ERR_BUSY) pending_w=pending_h=0;
        }
        nxn_input_state in = NXN_STRUCT_INIT(nxn_input_state);
        nxn_input_poll(&in);
        if ((in.actions_pressed & NXN_ACT_CANCEL) || (in.pressed & NXN_BTN_PLUS)) break;
        color(ok ? .1f : .6f,ok ? .5f : .1f,.2f,1); clear(0x4000); nxn_display_swap(d);
    }
    nxn_display_close(d); return 0;
}
int main(int argc,char** argv) { return nxn_run(argc,argv,app_main,NULL); }
