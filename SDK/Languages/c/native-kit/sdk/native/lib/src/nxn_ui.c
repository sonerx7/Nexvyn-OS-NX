/* Nexvyn Native SDK library - nxn_ui.h in a stand-alone .nro: there is no Nexvyn OS look to follow. The calls say so
 * (NXN_ERR_UNSUPPORTED, NXN_CAP_UI_TOKENS / NXN_CAP_TEXT not set) and nxn_tr returns the key, so an app that uses them
 * still runs. Inside Nexvyn OS (windowed mode) the system implements them. */
#include "nxn_internal.h"
#include <stdio.h>
#include <string.h>

nxn_result nxn_ui_tokens_get(nxn_ui_tokens* out) {
    if (!out || out->size < sizeof(uint32_t)) return NXN_ERR_INVALID;
    return NXN_ERR_UNSUPPORTED;
}

nxn_result nxn_ui_font_get(nxn_ui_font font, const void** data, size_t* size) {
    (void)font;
    if (!data || !size) return NXN_ERR_INVALID;
    *data = NULL;
    *size = 0;
    return NXN_ERR_UNSUPPORTED;
}

uint32_t nxn_ui_icon_code(const char* name) {
    (void)name;
    return 0;
}

const char* nxn_tr(const char* key) { return key ? key : ""; }

nxn_result nxn_tr_format(const char* key, char* out, size_t cap, const char* const* args, uint32_t argc) {
    (void)args;
    (void)argc;
    if (!out || cap == 0) return NXN_ERR_INVALID;
    int n = snprintf(out, cap, "%s", key ? key : "");
    return n >= 0 && (size_t)n < cap ? NXN_OK : NXN_ERR_TOO_SMALL;
}
