// Decomp port skeleton: keep the original PC-style main(argc, argv) and run the game from a data folder on the SD card.
// Typical ports also need: no fork/exec (run helpers in-process), no symlinks (copy), a fixed display size
// (1280x720 handheld, 1920x1080 docked), and file names written in the PC case (use fopen_ci).
#include <stdio.h>
#include <string.h>
#include <switch.h>
#include "compat_fs.h"

#ifdef NEXVYN_ABI
#include <nexvyn/nexvyn_native.h>
#endif

#define DATA_DIR "sdmc:/switch/@NAME@"

// The ported game starts here, exactly like the PC entry point.
int game_main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    FILE* f = fopen_ci(DATA_DIR "/Data/Config.INI", "rb");  // any spelling of the name works
    printf("data folder: %s\nConfig.INI: %s\n\nPress (+) to exit.\n", DATA_DIR, f ? "found" : "not found");
    if (f) fclose(f);
    PadState pad;
    padInitializeDefault(&pad);
    while (appletMainLoop()) {
        padUpdate(&pad);
        if (padGetButtonsDown(&pad) & HidNpadButton_Plus) break;
        consoleUpdate(NULL);
    }
    return 0;
}

int main(int argc, char** argv) {
    consoleInit(NULL);
    padConfigureInput(1, HidNpadStyleSet_NpadStandard);
    int rc = game_main(argc, argv);
    consoleExit(NULL);
    return rc;
}
