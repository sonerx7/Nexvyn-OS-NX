// Emulator skeleton: console front end; one frame = one slice of guest cycles.
#include <switch.h>
#include <cstdio>
#include "cpu.h"
#include "jit_memory.h"

#ifdef NEXVYN_ABI
#include <nexvyn/nexvyn_native.h>
#endif

int main(int, char**) {
    consoleInit(nullptr);
    padConfigureInput(1, HidNpadStyleSet_NpadStandard);
    PadState pad;
    padInitializeDefault(&pad);

    JitMemory jit;
    bool jitOk = jit.create(0x10000);

    Cpu cpu(0x10000);
    // r1 = 1000; r2 = 0; loop: r2 += r1; r1--; if r1 != 0 goto loop; halt
    const uint32_t prog[] = {0x011003E8, 0x01200000, 0x02210000, 0x04100000, 0x03100008, 0xFF000000};
    for (size_t i = 0; i < sizeof prog / 4; i++) cpu.write32((uint32_t)(i * 4), prog[i]);

    int frame = 0, total = 0;
    while (appletMainLoop()) {
        padUpdate(&pad);
        if (padGetButtonsDown(&pad) & HidNpadButton_Plus) break;
        total += cpu.run(500);  // frame budget
        frame++;
        std::printf("\x1b[1;1HNexvyn emulator skeleton\nframe %d  cycles %d  halted %d  r2 %u  jit %s\n(+) exit",
                    frame, total, cpu.halted, cpu.r[2], jitOk ? "real" : "fallback");
        consoleUpdate(nullptr);
    }
    jit.destroy();
    consoleExit(nullptr);
    return 0;
}
