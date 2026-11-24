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
    NXN_QUERY_NEXGFX = 7,
    NXN_QUERY_VULKAN = 8
} nxn_capability;

/* Runtime advertisement only. No hardware probe, allocation, context creation,
 * driver startup, or thread start. TLS describes module/library TLS, not worker admission.
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
        case NXN_QUERY_VULKAN: flag = NXN_CAP_VULKAN; break;
        default: return NXN_ERR_INVALID;
    }

    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    nxn_result result = nxn_caps_get(&caps);
    if (result == NXN_ERR_NOT_READY || result == NXN_ERR_UNSUPPORTED) return result;
    if (result != NXN_OK) return NXN_ERR_SYSTEM;
    return (caps.features & flag) ? NXN_OK : NXN_ERR_UNSUPPORTED;
}

/* Reports whether a single NXN_GFX_API_* bit is advertised in a filled nxn_caps snapshot.
 * Compatible with older OSes that leave gfx_apis zeroed: falls back to caps->features when
 * gfx_apis is absent or 0. Never starts a driver or reads past caps->size. */
static inline int nxn_caps_has_gfx_api(const nxn_caps* caps, uint32_t api_bit) {
    if (!caps || api_bit == 0u || (api_bit & (api_bit - 1u)) != 0u) return 0;
    if (caps->size >= offsetof(nxn_caps, gfx_apis) + sizeof(caps->gfx_apis) && caps->gfx_apis != 0u) {
        return (caps->gfx_apis & api_bit) != 0u;
    }
    if (caps->size < offsetof(nxn_caps, features) + sizeof(caps->features)) return 0;
    if (api_bit == (uint32_t)NXN_GFX_API_GL_CORE) return (caps->features & NXN_CAP_GL_CORE) != 0u;
    if (api_bit == (uint32_t)NXN_GFX_API_GLES) return (caps->features & NXN_CAP_GLES) != 0u;
    if (api_bit == (uint32_t)NXN_GFX_API_VULKAN) return (caps->features & NXN_CAP_VULKAN) != 0u;
    return 0;
}

/* Reads the advertised maximum major.minor version for one NXN_GFX_API_* bit from a filled
 * nxn_caps snapshot. Always zeroes *max_major and *max_minor first when non-NULL.
 * Returns NXN_OK when advertised, NXN_ERR_UNSUPPORTED when unavailable, or NXN_ERR_INVALID
 * for NULL caps or an unknown/multi-bit api_bit. Never starts a driver or reads past caps->size. */
static inline nxn_result nxn_caps_gfx_version(const nxn_caps* caps, uint32_t api_bit,
                                              uint16_t* max_major, uint16_t* max_minor) {
    if (max_major) *max_major = 0u;
    if (max_minor) *max_minor = 0u;
    if (!caps) return NXN_ERR_INVALID;
    if (api_bit != (uint32_t)NXN_GFX_API_GL_CORE &&
        api_bit != (uint32_t)NXN_GFX_API_GLES &&
        api_bit != (uint32_t)NXN_GFX_API_VULKAN) {
        return NXN_ERR_INVALID;
    }
    if (!nxn_caps_has_gfx_api(caps, api_bit)) return NXN_ERR_UNSUPPORTED;

    uint16_t maj = 0u;
    uint16_t min = 0u;
    if (api_bit == (uint32_t)NXN_GFX_API_GL_CORE) {
        if (caps->size >= offsetof(nxn_caps, gl_max_minor) + sizeof(caps->gl_max_minor)) {
            maj = caps->gl_max_major;
            min = caps->gl_max_minor;
        }
    } else if (api_bit == (uint32_t)NXN_GFX_API_GLES) {
        if (caps->size >= offsetof(nxn_caps, gles_max_minor) + sizeof(caps->gles_max_minor)) {
            maj = caps->gles_max_major;
            min = caps->gles_max_minor;
        }
    } else if (api_bit == (uint32_t)NXN_GFX_API_VULKAN) {
        if (caps->size >= offsetof(nxn_caps, vk_max_minor) + sizeof(caps->vk_max_minor)) {
            maj = caps->vk_max_major;
            min = caps->vk_max_minor;
        }
    }
    if (max_major) *max_major = maj;
    if (max_minor) *max_minor = min;
    return NXN_OK;
}

/* Convenience query: fetches nxn_caps_get and returns availability and maximum version for one
 * NXN_GFX_API_* bit. Build-time/runtime advertisement only; never starts a driver. No new host import. */
static inline nxn_result nxn_gfx_api_query(uint32_t api_bit, uint16_t* max_major, uint16_t* max_minor) {
    if (max_major) *max_major = 0u;
    if (max_minor) *max_minor = 0u;
    if (api_bit != (uint32_t)NXN_GFX_API_GL_CORE &&
        api_bit != (uint32_t)NXN_GFX_API_GLES &&
        api_bit != (uint32_t)NXN_GFX_API_VULKAN) {
        return NXN_ERR_INVALID;
    }

    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    nxn_result result = nxn_caps_get(&caps);
    if (result == NXN_ERR_NOT_READY || result == NXN_ERR_UNSUPPORTED) return result;
    if (result != NXN_OK) return NXN_ERR_SYSTEM;
    return nxn_caps_gfx_version(&caps, api_bit, max_major, max_minor);
}

NXN_EXTERN_C_END

#endif
