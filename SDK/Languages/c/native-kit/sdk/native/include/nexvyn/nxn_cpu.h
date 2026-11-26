/* Nexvyn Native SDK - CPU information (nxn_cpu_info_get). Added after ABI v1 (add-only).
 *
 *   nxn_cpu_info c = NXN_STRUCT_INIT(nxn_cpu_info);
 *   if (nxn_cpu_info_get(&c) == NXN_OK && (c.features & NXN_CPU_FEAT_CRC32)) use_crc32_path();
 *
 * Where the values come from:
 *  - features, implementer, part: FIXED values of the Cortex-A57 that every console revision uses (Erista and Mariko).
 *    The ID registers (ID_AA64ISAR0_EL1, MIDR_EL1) cannot be read from EL0 on Horizon, so those fields are not probed;
 *    `flags` carries NXN_CPU_FLAG_FIXED_FEATURES to say so. A57 has NEON, FP, AES, PMULL, SHA1, SHA2 and CRC32, and does
 *    NOT have FP16 arithmetic or the LSE atomics (so those bits are never set today).
 *  - dcache_line, icache_line, cache_writeback_granule, ctr_el0: read from CTR_EL0 (readable from EL0; libnx's cache
 *    routines use it).
 *  - core_count: 4 (fixed). process_core_mask: svcGetInfo(InfoType_CoreMask) of the process. worker_core_mask: the cores
 *    an app's worker threads may be placed on by Nexvyn OS (cores 1 and 2 only, intersected with process_core_mask;
 *    core 0 runs the OS main thread and the mixer, core 3 belongs to the system). current_core: svcGetCurrentProcessorNumber
 *    at the time of the call.
 *
 * Fills min(out->size, sizeof(nxn_cpu_info)) bytes; fields past out->size are not written. Fields never move, new fields
 * are appended. Always NXN_OK for a valid out. NXN_ERR_INVALID: out NULL or out->size < 8.
 * Thread: any thread. Memory: written into the caller's struct. */
#ifndef NEXVYN_NXN_CPU_H
#define NEXVYN_NXN_CPU_H

#include "nxn_base.h"

NXN_EXTERN_C_BEGIN

#define NXN_CPU_FEAT_NEON    (1u << 0) /* Advanced SIMD */
#define NXN_CPU_FEAT_FP      (1u << 1) /* scalar floating point */
#define NXN_CPU_FEAT_AES     (1u << 2)
#define NXN_CPU_FEAT_PMULL   (1u << 3)
#define NXN_CPU_FEAT_SHA1    (1u << 4)
#define NXN_CPU_FEAT_SHA2    (1u << 5)
#define NXN_CPU_FEAT_CRC32   (1u << 6)
#define NXN_CPU_FEAT_FP16    (1u << 7) /* half-precision arithmetic (FEAT_FP16): not on Cortex-A57 */
#define NXN_CPU_FEAT_ATOMICS (1u << 8) /* LSE atomics (FEAT_LSE): not on Cortex-A57 */

#define NXN_CPU_FLAG_FIXED_FEATURES (1u << 0) /* features / implementer / part are fixed Cortex-A57 values, not probed */

typedef struct nxn_cpu_info {
    uint32_t size;                    /* set by the caller: sizeof(nxn_cpu_info) */
    uint32_t version;                 /* 1 */
    uint32_t features;                /* NXN_CPU_FEAT_* */
    uint32_t flags;                   /* NXN_CPU_FLAG_* */
    uint32_t implementer;             /* 0x41 (Arm) */
    uint32_t part;                    /* 0xD07 (Cortex-A57) */
    uint32_t core_count;              /* 4 */
    uint32_t process_core_mask;       /* bit n = the process may run on core n; 0 if the query fails */
    uint32_t worker_core_mask;        /* eligible for Nexvyn OS worker hints (0x6 at most) */
    uint32_t current_core;            /* core of the calling thread at the time of the call */
    uint32_t dcache_line;             /* bytes, from CTR_EL0.DminLine */
    uint32_t icache_line;             /* bytes, from CTR_EL0.IminLine */
    uint32_t cache_writeback_granule; /* bytes, from CTR_EL0.CWG (0: not reported) */
    uint32_t ctr_el0;                 /* raw CTR_EL0 */
} nxn_cpu_info;

NXN_API nxn_result nxn_cpu_info_get(nxn_cpu_info* out);

NXN_EXTERN_C_END

#endif /* NEXVYN_NXN_CPU_H */
