/* One implementation of nxn_cpu_info_get, shared by the stand-alone library (nxn_cpu.c) and Nexvyn OS's host import
 * (source/runtimes/nxwin_cpu.cpp). Header-only so both include the same code. See nexvyn/nxn_cpu.h for the sources. */
#ifndef NEXVYN_NXN_CPU_IMPL_H
#define NEXVYN_NXN_CPU_IMPL_H

#include <nexvyn/nxn_cpu.h>
#include <string.h>
#include <switch.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Cores an app's workers may use: 1 and 2 (core 0: OS main thread and mixer, core 3: the system). Same rule as
 * nxwin::grantWorkerHint (source/runtimes/nxwin_rules.cpp). */
#define NXN_CPU_WORKER_CORES 0x6u

static inline void nxn_cpu__fill(nxn_cpu_info* o, uint64_t process_mask, uint32_t current_core, uint32_t ctr) {
    memset(o, 0, sizeof *o);
    o->size = (uint32_t)sizeof *o;
    o->version = 1;
    o->features = NXN_CPU_FEAT_NEON | NXN_CPU_FEAT_FP | NXN_CPU_FEAT_AES | NXN_CPU_FEAT_PMULL | NXN_CPU_FEAT_SHA1 |
                  NXN_CPU_FEAT_SHA2 | NXN_CPU_FEAT_CRC32;
    o->flags = NXN_CPU_FLAG_FIXED_FEATURES;
    o->implementer = 0x41;
    o->part = 0xD07;
    o->core_count = 4;
    o->process_core_mask = (uint32_t)(process_mask & 0xFu);
    o->worker_core_mask = o->process_core_mask & NXN_CPU_WORKER_CORES;
    o->current_core = current_core;
    o->dcache_line = 4u << ((ctr >> 16) & 0xF);
    o->icache_line = 4u << (ctr & 0xF);
    o->cache_writeback_granule = ((ctr >> 24) & 0xF) ? (4u << ((ctr >> 24) & 0xF)) : 0;
    o->ctr_el0 = ctr;
}

static inline nxn_result nxn_cpu__get(nxn_cpu_info* out) {
    if (!out || out->size < 8) return NXN_ERR_INVALID;
    uint64_t mask = 0;
    if (R_FAILED(svcGetInfo(&mask, InfoType_CoreMask, CUR_PROCESS_HANDLE, 0))) mask = 0;
    uint64_t ctr = 0;
    __asm__ volatile("mrs %0, ctr_el0" : "=r"(ctr));
    nxn_cpu_info full;
    nxn_cpu__fill(&full, mask, (uint32_t)svcGetCurrentProcessorNumber(), (uint32_t)ctr);
    uint32_t n = out->size < sizeof full ? out->size : (uint32_t)sizeof full;
    uint32_t keep = out->size;
    memcpy(out, &full, n);
    out->size = keep;
    return NXN_OK;
}

#ifdef __cplusplus
}
#endif
#endif
