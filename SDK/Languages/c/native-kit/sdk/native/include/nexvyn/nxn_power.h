/* Nexvyn Native SDK - power and network state (Native 1.2, NXN_CAP_POWER_STATE).
 *
 * For apps that adapt to the console: lower the frame rate or the emulation speed on a low battery, skip an online
 * request while there is no network. Script apps have this as sys.battery() / sys.online(); nothing changes for them.
 *
 *     nxn_power p = NXN_STRUCT_INIT(nxn_power);
 *     if (nxn_power_get(&p) == NXN_OK && p.percent >= 0 && p.percent < 15 && !p.charging) lower_the_load();
 *     ...
 *     if (ev.type == NXN_EVENT_POWER) { nxn_power_get(&p); ... }     // battery, charger, dock or network changed
 *
 * nxn_power_get is cheap: it copies what Nexvyn OS keeps up to date, with no file, network or service call, so it can be
 * called every frame. NXN_EVENT_POWER (only apps with "minNative" 1.2 or later get it) says one of the four values
 * changed (the battery by at least 1 percent); at most one per second, and unread ones merge into one, so read
 * the state with nxn_power_get when it arrives. Without NXN_CAP_POWER_STATE (a stand-alone .nro)
 * nxn_power_get returns NXN_ERR_UNSUPPORTED. Thread: any app thread. Memory: written into the caller's struct. */
#ifndef NEXVYN_NXN_POWER_H
#define NEXVYN_NXN_POWER_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

typedef struct nxn_power {
    uint32_t size;      /* sizeof(nxn_power) of the caller; set it (NXN_STRUCT_INIT) */
    int32_t percent;    /* battery charge 0..100, -1 = unknown (no battery information, e.g. an emulator) */
    uint32_t charging;  /* 1 while the battery is charging */
    uint32_t docked;    /* 1 docked (TV), 0 handheld */
    uint32_t online;    /* 1 while the console has an internet connection */
    uint32_t reserved;  /* 0 */
} nxn_power;

NXN_API nxn_result nxn_power_get(nxn_power* out);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_POWER_H */
