#ifndef NEXVYN_NXN_VK_H
#define NEXVYN_NXN_VK_H

#include "nxn_caps.h"

NXN_EXTERN_C_BEGIN

/* Optional windowed-module import. Test the resolver before calling it. */
extern void* nxn_vk_proc(const char* name) __attribute__((weak));

static inline int nxn_vk_available(void) {
    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    return nxn_caps_get(&caps) == NXN_OK &&
           (caps.features & NXN_CAP_VULKAN) != 0 &&
           nxn_caps_has_gfx_api(&caps, NXN_GFX_API_VULKAN) &&
           nxn_vk_proc != NULL;
}

NXN_EXTERN_C_END
#endif
