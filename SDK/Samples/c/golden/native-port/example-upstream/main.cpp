// Original stand-in: no upstream source and no downloads.
#include "window.h"
static int run(int, char**) {
    Window win; if (!win.open()) return 1;
    auto color = (void (*)(float,float,float,float))nxn_display_proc("glClearColor");
    auto clear = (void (*)(unsigned))nxn_display_proc("glClear");
    if (!color || !clear) { win.close(); return 1; }
    float shade = .2f;
    while (win.tick()) {
        if (!win.active()) { nxn_sleep_ns(16000000); continue; }
        if (win.confirm) shade = shade < .4f ? .6f : .2f;
        color(.08f,shade,.35f,1); clear(0x4000); nxn_display_swap(win.display);
    }
    win.close(); return 0;
}
int main(int argc,char** argv) { return nxn_run(argc,argv,run,nullptr); }
