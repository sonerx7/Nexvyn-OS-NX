/* Nexvyn Native SDK - JIT code memory of a stand-alone .nro (exclusive mode); fault handler and guard pages are
 * windowed-only (NATIVE_KIT.md 3.2.11). Code memory comes from libnx's Jit (CodeMemory: an rw and an rx
 * view of the same pages, both mapped for the buffer's whole life; transitions only clean the caches). */
#include <stdlib.h>
#include <string.h>
#include <switch.h>

#include "nexvyn/nxn_jit.h"
#include "nxelf.h"

#define NXN__JIT_MAX_BYTES (256ull << 20)
#define NXN__JIT_MAX 64

struct nxn_jit {
    Jit j;
    uint64_t bytes;
};

static Mutex g_jit_mu;
static uint64_t g_jit_bytes;
static int g_jit_count;

nxn_result nxn_jit_create(uint64_t bytes, nxn_jit** out) {
    if (out) *out = NULL;
    if (!bytes || !out || bytes > NXN__JIT_MAX_BYTES) return NXN_ERR_INVALID;
    if (!nxelf_jit_available()) return NXN_ERR_UNSUPPORTED; /* only CodeMemory, never the process-permission fallback */
    bytes = (bytes + 0xFFF) & ~0xFFFull;
    mutexLock(&g_jit_mu);
    int ok = g_jit_count < NXN__JIT_MAX && g_jit_bytes + bytes <= NXN__JIT_MAX_BYTES;
    if (ok) {
        g_jit_count++;
        g_jit_bytes += bytes;
    }
    mutexUnlock(&g_jit_mu);
    if (!ok) return NXN_ERR_NO_MEMORY;
    nxn_jit* j = (nxn_jit*)calloc(1, sizeof *j);
    if (j && R_SUCCEEDED(jitCreate(&j->j, bytes)) && j->j.type == JitType_CodeMemory) {
        j->bytes = bytes;
        *out = j;
        return NXN_OK;
    }
    if (j && j->j.rx_addr) jitClose(&j->j);
    free(j);
    mutexLock(&g_jit_mu);
    g_jit_count--;
    g_jit_bytes -= bytes;
    mutexUnlock(&g_jit_mu);
    return NXN_ERR_NO_MEMORY;
}

nxn_result nxn_jit_get(nxn_jit* j, nxn_jit_info* out) {
    if (!j || !out || out->size < sizeof(uint32_t)) return NXN_ERR_INVALID;
    nxn_jit_info i;
    memset(&i, 0, sizeof i);
    i.size = out->size; /* the caller's size stays: it says how much of *out was written */
    i.rw = jitGetRwAddr(&j->j);
    i.rx = jitGetRxAddr(&j->j);
    i.bytes = j->bytes;
    size_t n = out->size < sizeof i ? out->size : sizeof i;
    memcpy(out, &i, n);
    return NXN_OK;
}

nxn_result nxn_jit_begin_write(nxn_jit* j) { return j ? NXN_OK : NXN_ERR_INVALID; }

nxn_result nxn_jit_end_write(nxn_jit* j, uint64_t offset, uint64_t len) {
    if (!j || offset > j->bytes) return NXN_ERR_INVALID;
    if (!len || len > j->bytes - offset) len = j->bytes - offset;
    if (!len) return NXN_OK;
    armDCacheFlush((uint8_t*)jitGetRwAddr(&j->j) + offset, len);
    armICacheInvalidate((uint8_t*)jitGetRxAddr(&j->j) + offset, len);
    return NXN_OK;
}

void nxn_jit_destroy(nxn_jit* j) {
    if (!j) return;
    jitClose(&j->j);
    mutexLock(&g_jit_mu);
    g_jit_count--;
    g_jit_bytes -= j->bytes;
    mutexUnlock(&g_jit_mu);
    free(j);
}

nxn_result nxn_fault_handler_set(nxn_fault_fn fn, void* user) {
    (void)fn;
    (void)user;
    return NXN_ERR_UNSUPPORTED;
}

nxn_result nxn_mem_guard(void* block, uint64_t offset, uint64_t len, uint32_t mode) {
    (void)block;
    (void)offset;
    (void)len;
    (void)mode;
    return NXN_ERR_UNSUPPORTED;
}
