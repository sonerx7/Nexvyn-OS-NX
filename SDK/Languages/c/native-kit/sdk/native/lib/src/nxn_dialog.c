/* Nexvyn Native SDK library - nxn_dialog.h in a stand-alone .nro: dialogs belong to Nexvyn OS's user interface, so the
 * calls say NXN_ERR_UNSUPPORTED (no NXN_CAP_DIALOG bit) and the app keeps working (draw your own box there). Inside Nexvyn
 * OS (windowed mode) the system implements them (source/runtimes/nxwin_dialog.cpp). */
#include "nxn_internal.h"

nxn_result nxn_dialog(const nxn_dialog_params* params, uint32_t* picked) {
    if (!params || params->size < sizeof(uint32_t) || !picked) return NXN_ERR_INVALID;
    return NXN_ERR_UNSUPPORTED;
}

nxn_result nxn_prompt(const char* title, const char* message, const char* initial, char* out, size_t cap) {
    (void)title;
    (void)message;
    (void)initial;
    if (!out || !cap) return NXN_ERR_INVALID;
    out[0] = 0;
    return NXN_ERR_UNSUPPORTED;
}
