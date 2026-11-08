/* Nexvyn Native SDK library - nxn_menu.h in a stand-alone .nro: there is no Nexvyn OS menu bar. The calls say so
 * (NXN_ERR_UNSUPPORTED, NXN_CAP_MENU not set), so an app that uses them still runs. Inside Nexvyn OS (windowed mode) the
 * system implements them. */
#include "nxn_internal.h"

nxn_result nxn_menu_set(const nxn_menu_spec* spec) {
    if (!spec || spec->size < sizeof(uint32_t)) return NXN_ERR_INVALID;
    return NXN_ERR_UNSUPPORTED;
}

nxn_result nxn_menu_clear(void) { return NXN_ERR_UNSUPPORTED; }
