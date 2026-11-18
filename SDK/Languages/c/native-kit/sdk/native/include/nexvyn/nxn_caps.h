#ifndef NEXVYN_NXN_CAPS_H
#define NEXVYN_NXN_CAPS_H

#include "nxn_app.h"

NXN_EXTERN_C_BEGIN

typedef enum nxn_capability {
    NXN_QUERY_JIT = 1,
    NXN_QUERY_GUARD_PAGES = 2,
    NXN_QUERY_FAULT_HANDLER = 3,
    NXN_QUERY_THREAD_TLS = 4,
    NXN_QUERY_GL_CORE = 5,
    NXN_QUERY_GLES = 6,
    NXN_QUERY_NEXGFX = 7
} nxn_capability;

/* Runtime advertisement only. No hardware probe, allocation, context creation,
 * or thread start. TLS describes module/library TLS, not worker admission.
 * Returns only NXN_OK (advertised), NXN_ERR_UNSUPPORTED (absent),
 * NXN_ERR_INVALID (unknown selector), NXN_ERR_NOT_READY (runtime unavailable),
 * or NXN_ERR_SYSTEM (other snapshot failure).
 * Thread: same as nxn_caps_get. No new host import. */
static inline nxn_result nxn_capability_query(nxn_capability capability) {
    uint64_t flag;
    switch (capability) {
        case NXN_QUERY_JIT: flag = NXN_CAP_JIT; break;
        case NXN_QUERY_GUARD_PAGES: flag = NXN_CAP_GUARD_PAGES; break;
        case NXN_QUERY_FAULT_HANDLER: flag = NXN_CAP_FAULT_HANDLER; break;
        case NXN_QUERY_THREAD_TLS: flag = NXN_CAP_TLS; break;
        case NXN_QUERY_GL_CORE: flag = NXN_CAP_GL_CORE; break;
        case NXN_QUERY_GLES: flag = NXN_CAP_GLES; break;
        case NXN_QUERY_NEXGFX: flag = NXN_CAP_NEXGFX; break;
        default: return NXN_ERR_INVALID;
    }

    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    nxn_result result = nxn_caps_get(&caps);
    if (result == NXN_ERR_NOT_READY || result == NXN_ERR_UNSUPPORTED) return result;
    if (result != NXN_OK) return NXN_ERR_SYSTEM;
    return (caps.features & flag) ? NXN_OK : NXN_ERR_UNSUPPORTED;
}

NXN_EXTERN_C_END

#endif
