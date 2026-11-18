// Bounded toy interpreter; blue while running, green on the expected result.
#include "window.h"
#include "cpu.h"
static int emulate(int, char**) {
    Window win; if (!win.open()) return 1;
    auto color = (void (*)(float,float,float,float))nxn_display_proc("glClearColor");
    auto clear = (void (*)(unsigned))nxn_display_proc("glClear");
    if (!color || !clear) { win.close(); return 1; }
    Cpu cpu(0x10000);
    const uint32_t program[] = {0x011003E8,0x01200000,0x02210000,0x04100000,0x03100008,0xFF000000};
    auto reset = [&]() {
        cpu.pc=0; cpu.halted=false; for(auto& r:cpu.r) r=0;
        for(size_t i=0;i<sizeof program/sizeof program[0];i++) cpu.write32(i*4,program[i]);
    };
    reset(); bool reported=false;
    while (win.tick()) {
        if (!win.active()) { nxn_sleep_ns(16000000); continue; }
        if (win.confirm) { reset(); reported=false; }
        cpu.run(500); // bounded per-frame guest work, never an unbounded guest loop
        if (cpu.halted && !reported) {
            nxn_log(NXN_LOG_INFO,"toy result: %u (expected 500500)",cpu.r[2]); reported=true;
            nxn_window_set_title(nxn_tr("title"),nxn_tr(cpu.r[2]==500500 ? "success" : "error"));
        }
        color(.05f,cpu.halted && cpu.r[2]==500500 ? .5f : .1f,.3f,1);
        clear(0x4000); nxn_display_swap(win.display);
    }
    win.close(); return 0;
}
int main(int argc,char** argv) { return nxn_run(argc,argv,emulate,nullptr); }
