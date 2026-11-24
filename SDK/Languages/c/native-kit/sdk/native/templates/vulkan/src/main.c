#include <stdio.h>
#include <string.h>
#include <nexvyn/nxn_vk.h>
#include <nexvyn/nxn_ui.h>

#if defined(NEXVYN_VK_SHIMS) && NEXVYN_VK_SHIMS
#include <vulkan/vulkan_core.h>
#endif

int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
#if defined(NEXVYN_VK_SHIMS) && NEXVYN_VK_SHIMS
    if (nxn_vk_available()) {
        PFN_vkCreateInstance create = (PFN_vkCreateInstance)vkGetInstanceProcAddr(
            VK_NULL_HANDLE, "vkCreateInstance");
        if (create) {
            const VkApplicationInfo app = {
                .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
                .apiVersion = VK_API_VERSION_1_0,
            };
            const VkInstanceCreateInfo info = {
                .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
                .pApplicationInfo = &app,
            };
            VkInstance instance = VK_NULL_HANDLE;
            VkResult result = create(&info, NULL, &instance);
            if (result != VK_SUCCESS) {
                printf("%s (%d)\n", nxn_tr("vulkan.create_failed"), (int)result);
                return 1;
            }
            vkDestroyInstance(instance, NULL);
            puts(nxn_tr("vulkan.created"));
            return 0;
        }
    }
#endif
    const char* message = nxn_tr("vulkan.unavailable");
    puts(strcmp(message, "vulkan.unavailable") == 0 ? "Vulkan is not available on this system" : message);
    return 0;
}
