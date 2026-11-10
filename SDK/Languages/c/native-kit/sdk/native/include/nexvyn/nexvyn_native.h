/* Nexvyn Native SDK (nxn_*) - one include for everything. ABI v1, frozen (NATIVE_KIT.en.md;
 * the frozen surface: sdk/native/toolchain/nxn_abi_v1.json, add-only).
 *
 *   #include <nexvyn/nexvyn_native.h>       link: -lnexvyn_native (before SDL2, EGL and -lnx)
 *
 *   static int app_main(int argc, char** argv) {
 *       nxn_display* d; nxn_display_open(NULL, &d);
 *       while (!nxn_should_quit()) { ...draw...; nxn_display_swap(d); }
 *       nxn_display_close(d);
 *       return 0;
 *   }
 *   int main(int argc, char** argv) { return nxn_run(argc, argv, app_main, NULL); }
 */
#ifndef NEXVYN_NATIVE_H
#define NEXVYN_NATIVE_H

#include "nxn_base.h"
#include "nxn_app.h"
#include "nxn_display.h"
#include "nxn_input.h"
#include "nxn_event.h"
#include "nxn_audio.h"
#include "nxn_fs.h"
#include "nxn_sys.h"
#include "nxn_lib.h"
#include "nxn_ui.h"
#include "nxn_menu.h"
#include "nxn_window.h"
#include "nxn_power.h"
#include "nxn_dialog.h"
#include "nxn_jit.h"

#endif /* NEXVYN_NATIVE_H */
