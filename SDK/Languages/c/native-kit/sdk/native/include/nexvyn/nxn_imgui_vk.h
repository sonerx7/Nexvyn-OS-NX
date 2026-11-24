#ifndef NEXVYN_NXN_IMGUI_VK_H
#define NEXVYN_NXN_IMGUI_VK_H

#include "nxn_vk.h"
#include "imgui_impl_vulkan.h"

/* Call with a current ImGui context and an app-owned Vulkan instance/device.
 * The caller owns rendering, shutdown, and all Vulkan resources. */
static inline bool nxn_imgui_vulkan_init(ImGui_ImplVulkan_InitInfo* info) {
    if (!info || !info->Instance || !info->Device || !nxn_vk_available()) return false;
    const auto lookup = reinterpret_cast<PFN_vkGetInstanceProcAddr>(nxn_vk_proc("vkGetInstanceProcAddr"));
    if (!lookup) return false;
    struct Lookup {
        PFN_vkGetInstanceProcAddr proc;
        VkInstance instance;
    } dispatch = {lookup, info->Instance};
    if (!ImGui_ImplVulkan_LoadFunctions([](const char* name, void* user) {
        const auto* data = static_cast<const Lookup*>(user);
        return data->proc(data->instance, name);
    }, &dispatch)) return false;
    return ImGui_ImplVulkan_Init(info);
}

#endif
