/* Nexvyn Native SDK library - nxn_power.h in a stand-alone .nro: the battery and network belong to Nexvyn OS's services,
 * so the call says NXN_ERR_UNSUPPORTED (no NXN_CAP_POWER_STATE bit) and the app keeps working. Inside Nexvyn OS (windowed
 * mode) the system implements it (source/runtimes/nxwin_power.cpp). */
#include "nxn_internal.h"

nxn_result nxn_power_get(nxn_power* out) {
    if (!out || out->size < sizeof(uint32_t)) return NXN_ERR_INVALID;
    return NXN_ERR_UNSUPPORTED;
}
