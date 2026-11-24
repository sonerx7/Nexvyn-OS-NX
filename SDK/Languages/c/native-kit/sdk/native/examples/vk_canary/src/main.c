/* Nexvyn OS Vulkan canary application (N5-V.11).
 * Checks NXN_CAP_VULKAN and Vulkan API availability; refuses cleanly with exit 0 when
 * absent, or creates an instance, device, window-bound host WSI surface and swapchain,
 * renders a clear color plus one texture-free triangle each frame, handles lifecycle
 * events and device loss, and emits N5V11: frame telemetry lines.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <nexvyn/nxn_app.h>
#include <nexvyn/nxn_caps.h>
#include <nexvyn/nxn_event.h>
#include <nexvyn/nxn_fs.h>
#include <nexvyn/nxn_sys.h>
#include <nexvyn/nxn_ui.h>
#include <nexvyn/nxn_vk.h>
#include <nexvyn/nxn_window.h>

#include "vk_canary_stats.h"

#if defined(NEXVYN_VK_SHIMS) && NEXVYN_VK_SHIMS
#include <vulkan/vulkan_core.h>
#include "vk_canary_shaders.h"
#endif

static void emit_log_line(nxn_log_level level, const char* line) {
    nxn_log_write(level, line);
    puts(line);
    fflush(stdout);
}

static const char* localized_or(const char* key, const char* fallback) {
    const char* text = nxn_tr(key);
    if (!text || !*text || strcmp(text, key) == 0) {
        return fallback;
    }
    return text;
}

static vk_canary_mode read_bundle_mode(void) {
    char manifest[2048];
    size_t read_bytes = 0u;
    if (nxn_fs_read(NXN_DIR_BUNDLE, "app.json", manifest, sizeof(manifest) - 1u, &read_bytes) == NXN_OK &&
        read_bytes > 0u) {
        manifest[read_bytes] = '\0';
        return vk_canary_parse_manifest_mode(manifest, read_bytes);
    }
    return VK_CANARY_MODE_WINDOW;
}

static int report_unavailable(void) {
    char line[128];
    const char* msg = localized_or("canary.unavailable", "Vulkan is not available on this system");
    puts(msg);
    fflush(stdout);
    if (vk_canary_format_unavailable(line, sizeof(line)) > 0) {
        nxn_log_write(NXN_LOG_INFO, line);
    }
    return 0;
}

#if defined(NEXVYN_VK_SHIMS) && NEXVYN_VK_SHIMS

#define VK_CANARY_FRAMES_IN_FLIGHT 2u
#define VK_CANARY_WAIT_SLICE_NS 16000000ULL
#define VK_CANARY_REOPEN_MAX_TRIES 120u

typedef VkResult(VKAPI_PTR* PFN_nxn_vk_wsi_instance_extensions)(uint32_t* count, const char** names);
typedef VkResult(VKAPI_PTR* PFN_nxn_vk_wsi_create_surface)(VkInstance instance, VkSurfaceKHR* surface);

typedef struct CanaryApp {
    vk_canary_mode mode;
    PFN_nxn_vk_wsi_instance_extensions get_wsi_extensions;
    PFN_nxn_vk_wsi_create_surface create_wsi_surface;

    VkInstance instance;
    VkSurfaceKHR surface;
    VkPhysicalDevice physical_device;
    VkDevice device;
    uint32_t graphics_family;
    uint32_t present_family;
    VkQueue graphics_queue;
    VkQueue present_queue;

    VkShaderModule vert_module;
    VkShaderModule frag_module;
    VkPipelineLayout pipeline_layout;
    VkRenderPass render_pass;
    VkPipeline pipeline;
    VkFormat pipeline_format;

    VkSwapchainKHR swapchain;
    VkFormat swapchain_format;
    VkExtent2D swapchain_extent;
    uint32_t swapchain_image_count;
    VkImage swapchain_images[VK_CANARY_MAX_SWAPCHAIN_IMAGES];
    VkImageView swapchain_views[VK_CANARY_MAX_SWAPCHAIN_IMAGES];
    VkFramebuffer framebuffers[VK_CANARY_MAX_SWAPCHAIN_IMAGES];
    VkSemaphore render_finished[VK_CANARY_MAX_SWAPCHAIN_IMAGES];

    VkCommandPool command_pool;
    VkCommandBuffer command_buffers[VK_CANARY_FRAMES_IN_FLIGHT];
    VkSemaphore image_available[VK_CANARY_FRAMES_IN_FLIGHT];
    VkFence in_flight[VK_CANARY_FRAMES_IN_FLIGHT];
    uint32_t current_frame;

    uint32_t desired_width;
    uint32_t desired_height;
    int suspended;
    int focused;
    int quit_requested;
    vk_canary_phase phase;
    int device_lost;
    int idle_failed;
    int acquire_unsubmitted;
    uint32_t surface_attempts;

    uint32_t resizes;
    uint32_t suspends;
    vk_canary_stats stats;
    char fail_reason[64];
    int32_t fail_vk_result;
} CanaryApp;

static void drain_events(CanaryApp* app);
static vk_canary_phase next_step(const CanaryApp* app);

static void set_failure(CanaryApp* app, const char* reason, VkResult result) {
    if (!app->fail_reason[0] || (result == VK_ERROR_DEVICE_LOST && !app->device_lost)) {
        const char* prefix = result == VK_ERROR_DEVICE_LOST &&
                             strncmp(reason, "device_lost_", 12u) != 0 ? "device_lost_" : "";
        snprintf(app->fail_reason, sizeof(app->fail_reason), "%s%s", prefix, reason);
        app->fail_vk_result = (int32_t)result;
    }
    if (result == VK_ERROR_DEVICE_LOST) {
        app->device_lost = 1;
    }
}

static VkResult wait_for_retirement(CanaryApp* app, const char* step) {
    const VkResult r = vkDeviceWaitIdle(app->device);
    if (vk_canary_idle_policy((int32_t)r) != VK_CANARY_RETIRED) {
        app->idle_failed = 1;
        app->fail_reason[0] = '\0';
        set_failure(app, step, r);
    }
    return r;
}

static VkResult wsi_result(CanaryApp* app, const char* step, VkResult r) {
    const vk_canary_action action = vk_canary_wsi_action(app->phase, (int32_t)r);
    if (action == VK_CANARY_ACTION_FATAL || action == VK_CANARY_ACTION_DEVICE_LOST) {
        set_failure(app, step, r);
    }
    return r;
}

static void destroy_swapchain_views_and_fbs(CanaryApp* app) {
    for (uint32_t i = 0u; i < app->swapchain_image_count; ++i) {
        if (app->framebuffers[i] != VK_NULL_HANDLE) {
            vkDestroyFramebuffer(app->device, app->framebuffers[i], NULL);
            app->framebuffers[i] = VK_NULL_HANDLE;
        }
        if (app->swapchain_views[i] != VK_NULL_HANDLE) {
            vkDestroyImageView(app->device, app->swapchain_views[i], NULL);
            app->swapchain_views[i] = VK_NULL_HANDLE;
        }
        if (app->render_finished[i] != VK_NULL_HANDLE) {
            vkDestroySemaphore(app->device, app->render_finished[i], NULL);
            app->render_finished[i] = VK_NULL_HANDLE;
        }
        app->swapchain_images[i] = VK_NULL_HANDLE;
    }
    app->swapchain_image_count = 0u;
}

static void destroy_pipeline_and_render_pass(CanaryApp* app) {
    if (app->pipeline != VK_NULL_HANDLE) {
        vkDestroyPipeline(app->device, app->pipeline, NULL);
        app->pipeline = VK_NULL_HANDLE;
    }
    if (app->render_pass != VK_NULL_HANDLE) {
        vkDestroyRenderPass(app->device, app->render_pass, NULL);
        app->render_pass = VK_NULL_HANDLE;
    }
    app->pipeline_format = VK_FORMAT_UNDEFINED;
}

static void destroy_swapchain(CanaryApp* app) {
    destroy_swapchain_views_and_fbs(app);
    if (app->swapchain != VK_NULL_HANDLE) {
        vkDestroySwapchainKHR(app->device, app->swapchain, NULL);
        app->swapchain = VK_NULL_HANDLE;
    }
}

static void teardown_vulkan(CanaryApp* app) {
    if (app->device != VK_NULL_HANDLE) {
        const int retired = !app->device_lost && !app->idle_failed &&
                            wait_for_retirement(app, "idle_teardown") == VK_SUCCESS;
        /* Submitted commands never reference shader modules. */
        if (app->frag_module != VK_NULL_HANDLE) {
            vkDestroyShaderModule(app->device, app->frag_module, NULL);
            app->frag_module = VK_NULL_HANDLE;
        }
        if (app->vert_module != VK_NULL_HANDLE) {
            vkDestroyShaderModule(app->device, app->vert_module, NULL);
            app->vert_module = VK_NULL_HANDLE;
        }
        /* Keep the device and its parents owned if retirement is unproven.
         * An acquire with no consuming submit may still be signalling. */
        if (!retired || app->acquire_unsubmitted) return;

        destroy_swapchain(app);
        destroy_pipeline_and_render_pass(app);
        for (uint32_t i = 0u; i < VK_CANARY_FRAMES_IN_FLIGHT; ++i) {
            if (app->in_flight[i] != VK_NULL_HANDLE) {
                vkDestroyFence(app->device, app->in_flight[i], NULL);
                app->in_flight[i] = VK_NULL_HANDLE;
            }
            if (app->image_available[i] != VK_NULL_HANDLE) {
                vkDestroySemaphore(app->device, app->image_available[i], NULL);
                app->image_available[i] = VK_NULL_HANDLE;
            }
        }
        if (app->command_pool != VK_NULL_HANDLE) {
            vkDestroyCommandPool(app->device, app->command_pool, NULL);
            app->command_pool = VK_NULL_HANDLE;
        }
        if (app->pipeline_layout != VK_NULL_HANDLE) {
            vkDestroyPipelineLayout(app->device, app->pipeline_layout, NULL);
            app->pipeline_layout = VK_NULL_HANDLE;
        }
        vkDestroyDevice(app->device, NULL);
        app->device = VK_NULL_HANDLE;
    }
    if (app->instance != VK_NULL_HANDLE) {
        if (app->surface != VK_NULL_HANDLE) {
            vkDestroySurfaceKHR(app->instance, app->surface, NULL);
            app->surface = VK_NULL_HANDLE;
        }
        vkDestroyInstance(app->instance, NULL);
        app->instance = VK_NULL_HANDLE;
    }
}

static VkResult create_instance(CanaryApp* app) {
    const char* ext_names[16];
    uint32_t ext_count = 0u;

    if (app->get_wsi_extensions) {
        VkResult r = app->get_wsi_extensions(&ext_count, NULL);
        if (r != VK_SUCCESS) {
            set_failure(app, "wsi_ext_count", r);
            return r;
        }
        if (ext_count > 16u) {
            ext_count = 16u;
        }
        if (ext_count > 0u) {
            r = app->get_wsi_extensions(&ext_count, ext_names);
            if (r != VK_SUCCESS && r != VK_INCOMPLETE) {
                set_failure(app, "wsi_ext_list", r);
                return r;
            }
        }
    }
    if (ext_count == 0u) {
        ext_names[0] = VK_KHR_SURFACE_EXTENSION_NAME;
        ext_count = 1u;
    }

    const VkApplicationInfo app_info = {
        .sType = VK_STRUCTURE_TYPE_APPLICATION_INFO,
        .pApplicationName = "Nexvyn Vulkan Canary",
        .applicationVersion = VK_MAKE_VERSION(1, 0, 0),
        .pEngineName = "NexvynNativeKit",
        .engineVersion = VK_MAKE_VERSION(1, 2, 0),
        .apiVersion = VK_API_VERSION_1_3,
    };
    const VkInstanceCreateInfo create_info = {
        .sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO,
        .pApplicationInfo = &app_info,
        .enabledExtensionCount = ext_count,
        .ppEnabledExtensionNames = ext_names,
    };
    VkResult r = vkCreateInstance(&create_info, NULL, &app->instance);
    if (r != VK_SUCCESS) {
        set_failure(app, "create_instance", r);
    }
    return r;
}

static int device_has_swapchain_extension(VkPhysicalDevice gpu) {
    uint32_t count = 0u;
    if (vkEnumerateDeviceExtensionProperties(gpu, NULL, &count, NULL) != VK_SUCCESS || count == 0u) {
        return 0;
    }
    VkExtensionProperties* props = (VkExtensionProperties*)calloc(count, sizeof(VkExtensionProperties));
    if (!props) {
        return 0;
    }
    int found = 0;
    if (vkEnumerateDeviceExtensionProperties(gpu, NULL, &count, props) == VK_SUCCESS) {
        for (uint32_t i = 0u; i < count; ++i) {
            if (strcmp(props[i].extensionName, VK_KHR_SWAPCHAIN_EXTENSION_NAME) == 0) {
                found = 1;
                break;
            }
        }
    }
    free(props);
    return found;
}

static VkResult pick_physical_device_and_create_device(CanaryApp* app) {
    uint32_t gpu_count = 0u;
    VkResult r = vkEnumeratePhysicalDevices(app->instance, &gpu_count, NULL);
    if (r != VK_SUCCESS || gpu_count == 0u) {
        set_failure(app, "no_physical_device", r == VK_SUCCESS ? VK_ERROR_INITIALIZATION_FAILED : r);
        return r == VK_SUCCESS ? VK_ERROR_INITIALIZATION_FAILED : r;
    }
    VkPhysicalDevice gpus[8];
    if (gpu_count > 8u) {
        gpu_count = 8u;
    }
    r = vkEnumeratePhysicalDevices(app->instance, &gpu_count, gpus);
    if (r != VK_SUCCESS && r != VK_INCOMPLETE) {
        set_failure(app, "enum_physical_devices", r);
        return r;
    }

    int selected = 0;
    for (uint32_t g = 0u; g < gpu_count && !selected; ++g) {
        VkPhysicalDeviceProperties props = {0};
        vkGetPhysicalDeviceProperties(gpus[g], &props);
        if (props.apiVersion < VK_API_VERSION_1_3) continue;
        if (!device_has_swapchain_extension(gpus[g])) {
            continue;
        }
        uint32_t q_count = 0u;
        vkGetPhysicalDeviceQueueFamilyProperties(gpus[g], &q_count, NULL);
        if (q_count == 0u) {
            continue;
        }
        if (q_count > 16u) {
            q_count = 16u;
        }
        VkQueueFamilyProperties q_props[16];
        vkGetPhysicalDeviceQueueFamilyProperties(gpus[g], &q_count, q_props);

        uint32_t gfx = UINT32_MAX;
        uint32_t pres = UINT32_MAX;
        for (uint32_t i = 0u; i < q_count; ++i) {
            VkBool32 supports_present = VK_FALSE;
            r = vkGetPhysicalDeviceSurfaceSupportKHR(gpus[g], i, app->surface, &supports_present);
            if (r != VK_SUCCESS) return wsi_result(app, "surface_support", r);
            if ((q_props[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) != 0u && supports_present == VK_TRUE) {
                gfx = i;
                pres = i;
                break;
            }
            if (gfx == UINT32_MAX && (q_props[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) != 0u) {
                gfx = i;
            }
            if (pres == UINT32_MAX && supports_present == VK_TRUE) {
                pres = i;
            }
        }
        if (gfx != UINT32_MAX && pres != UINT32_MAX) {
            app->physical_device = gpus[g];
            app->graphics_family = gfx;
            app->present_family = pres;
            selected = 1;
        }
    }

    if (!selected) {
        set_failure(app, "no_suitable_queue_family", VK_ERROR_INITIALIZATION_FAILED);
        return VK_ERROR_INITIALIZATION_FAILED;
    }

    const float queue_priority = 1.0f;
    VkDeviceQueueCreateInfo queue_infos[2];
    uint32_t queue_info_count = 0u;
    queue_infos[queue_info_count++] = (VkDeviceQueueCreateInfo){
        .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
        .queueFamilyIndex = app->graphics_family,
        .queueCount = 1u,
        .pQueuePriorities = &queue_priority,
    };
    if (app->present_family != app->graphics_family) {
        queue_infos[queue_info_count++] = (VkDeviceQueueCreateInfo){
            .sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
            .queueFamilyIndex = app->present_family,
            .queueCount = 1u,
            .pQueuePriorities = &queue_priority,
        };
    }

    const char* device_exts[] = {VK_KHR_SWAPCHAIN_EXTENSION_NAME};
    const VkDeviceCreateInfo dev_info = {
        .sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO,
        .queueCreateInfoCount = queue_info_count,
        .pQueueCreateInfos = queue_infos,
        .enabledExtensionCount = 1u,
        .ppEnabledExtensionNames = device_exts,
    };
    r = vkCreateDevice(app->physical_device, &dev_info, NULL, &app->device);
    if (r != VK_SUCCESS) {
        set_failure(app, "create_device", r);
        return r;
    }
    /* Resolve vkDeviceWaitIdle while the app is alive: the loader binds lazily and refuses new lookups after close,
     * which made the final idle wait fail with -3. The device has no work yet, so this returns at once. */
    (void)vkDeviceWaitIdle(app->device);
    vkGetDeviceQueue(app->device, app->graphics_family, 0u, &app->graphics_queue);
    vkGetDeviceQueue(app->device, app->present_family, 0u, &app->present_queue);
    return VK_SUCCESS;
}

static VkResult create_static_resources(CanaryApp* app) {
    const VkShaderModuleCreateInfo vert_info = {
        .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = sizeof(kVkCanaryVertSpv),
        .pCode = kVkCanaryVertSpv,
    };
    VkResult r = vkCreateShaderModule(app->device, &vert_info, NULL, &app->vert_module);
    if (r != VK_SUCCESS) {
        set_failure(app, "create_vert_shader", r);
        return r;
    }

    const VkShaderModuleCreateInfo frag_info = {
        .sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
        .codeSize = sizeof(kVkCanaryFragSpv),
        .pCode = kVkCanaryFragSpv,
    };
    r = vkCreateShaderModule(app->device, &frag_info, NULL, &app->frag_module);
    if (r != VK_SUCCESS) {
        set_failure(app, "create_frag_shader", r);
        return r;
    }

    const VkPipelineLayoutCreateInfo layout_info = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO,
    };
    r = vkCreatePipelineLayout(app->device, &layout_info, NULL, &app->pipeline_layout);
    if (r != VK_SUCCESS) {
        set_failure(app, "create_pipeline_layout", r);
        return r;
    }

    const VkCommandPoolCreateInfo pool_info = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT,
        .queueFamilyIndex = app->graphics_family,
    };
    r = vkCreateCommandPool(app->device, &pool_info, NULL, &app->command_pool);
    if (r != VK_SUCCESS) {
        set_failure(app, "create_command_pool", r);
        return r;
    }

    const VkCommandBufferAllocateInfo alloc_info = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO,
        .commandPool = app->command_pool,
        .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY,
        .commandBufferCount = VK_CANARY_FRAMES_IN_FLIGHT,
    };
    r = vkAllocateCommandBuffers(app->device, &alloc_info, app->command_buffers);
    if (r != VK_SUCCESS) {
        set_failure(app, "alloc_command_buffers", r);
        return r;
    }

    const VkSemaphoreCreateInfo sem_info = {.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO};
    const VkFenceCreateInfo fence_info = {
        .sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO,
        .flags = VK_FENCE_CREATE_SIGNALED_BIT,
    };
    for (uint32_t i = 0u; i < VK_CANARY_FRAMES_IN_FLIGHT; ++i) {
        r = vkCreateSemaphore(app->device, &sem_info, NULL, &app->image_available[i]);
        if (r != VK_SUCCESS) {
            set_failure(app, "create_semaphore", r);
            return r;
        }
        r = vkCreateFence(app->device, &fence_info, NULL, &app->in_flight[i]);
        if (r != VK_SUCCESS) {
            set_failure(app, "create_fence", r);
            return r;
        }
    }
    return VK_SUCCESS;
}

static VkResult ensure_pipeline_for_format(CanaryApp* app, VkFormat format) {
    if (app->pipeline != VK_NULL_HANDLE && app->render_pass != VK_NULL_HANDLE &&
        app->pipeline_format == format) {
        return VK_SUCCESS;
    }
    destroy_pipeline_and_render_pass(app);

    const VkAttachmentDescription color_att = {
        .format = format,
        .samples = VK_SAMPLE_COUNT_1_BIT,
        .loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR,
        .storeOp = VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE,
        .stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED,
        .finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR,
    };
    const VkAttachmentReference color_ref = {
        .attachment = 0u,
        .layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
    };
    const VkSubpassDescription subpass = {
        .pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
        .colorAttachmentCount = 1u,
        .pColorAttachments = &color_ref,
    };
    const VkSubpassDependency dep = {
        .srcSubpass = VK_SUBPASS_EXTERNAL,
        .dstSubpass = 0u,
        .srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .srcAccessMask = 0u,
        .dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT,
    };
    const VkRenderPassCreateInfo rp_info = {
        .sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO,
        .attachmentCount = 1u,
        .pAttachments = &color_att,
        .subpassCount = 1u,
        .pSubpasses = &subpass,
        .dependencyCount = 1u,
        .pDependencies = &dep,
    };
    VkResult r = vkCreateRenderPass(app->device, &rp_info, NULL, &app->render_pass);
    if (r != VK_SUCCESS) {
        set_failure(app, "create_render_pass", r);
        return r;
    }

    const VkPipelineShaderStageCreateInfo stages[2] = {
        {
            .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = VK_SHADER_STAGE_VERTEX_BIT,
            .module = app->vert_module,
            .pName = "main",
        },
        {
            .sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO,
            .stage = VK_SHADER_STAGE_FRAGMENT_BIT,
            .module = app->frag_module,
            .pName = "main",
        },
    };
    const VkPipelineVertexInputStateCreateInfo vertex_input = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
    };
    const VkPipelineInputAssemblyStateCreateInfo input_assembly = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
        .topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST,
        .primitiveRestartEnable = VK_FALSE,
    };
    const VkPipelineViewportStateCreateInfo viewport_state = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
        .viewportCount = 1u,
        .scissorCount = 1u,
    };
    const VkPipelineRasterizationStateCreateInfo raster = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .polygonMode = VK_POLYGON_MODE_FILL,
        .cullMode = VK_CULL_MODE_NONE,
        .frontFace = VK_FRONT_FACE_CLOCKWISE,
        .lineWidth = 1.0f,
    };
    const VkPipelineMultisampleStateCreateInfo multisample = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
        .rasterizationSamples = VK_SAMPLE_COUNT_1_BIT,
    };
    const VkPipelineColorBlendAttachmentState blend_att = {
        .blendEnable = VK_FALSE,
        .colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT |
                          VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT,
    };
    const VkPipelineColorBlendStateCreateInfo blend = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
        .attachmentCount = 1u,
        .pAttachments = &blend_att,
    };
    const VkDynamicState dyn_states[2] = {VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR};
    const VkPipelineDynamicStateCreateInfo dynamic = {
        .sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
        .dynamicStateCount = 2u,
        .pDynamicStates = dyn_states,
    };

    const VkGraphicsPipelineCreateInfo pipe_info = {
        .sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO,
        .stageCount = 2u,
        .pStages = stages,
        .pVertexInputState = &vertex_input,
        .pInputAssemblyState = &input_assembly,
        .pViewportState = &viewport_state,
        .pRasterizationState = &raster,
        .pMultisampleState = &multisample,
        .pColorBlendState = &blend,
        .pDynamicState = &dynamic,
        .layout = app->pipeline_layout,
        .renderPass = app->render_pass,
        .subpass = 0u,
    };
    r = vkCreateGraphicsPipelines(app->device, VK_NULL_HANDLE, 1u, &pipe_info, NULL, &app->pipeline);
    if (r != VK_SUCCESS) {
        set_failure(app, "create_pipeline", r);
        return r;
    }
    app->pipeline_format = format;
    return VK_SUCCESS;
}

static VkResult recreate_swapchain(CanaryApp* app) {
    VkSurfaceCapabilitiesKHR caps;
    memset(&caps, 0, sizeof(caps));
    VkResult r = vkGetPhysicalDeviceSurfaceCapabilitiesKHR(app->physical_device, app->surface, &caps);
    if (r != VK_SUCCESS) return wsi_result(app, "surface_caps", r);

    uint32_t extent_w = 0u;
    uint32_t extent_h = 0u;
    vk_canary_choose_extent(caps.currentExtent.width, caps.currentExtent.height,
                            caps.minImageExtent.width, caps.minImageExtent.height,
                            caps.maxImageExtent.width, caps.maxImageExtent.height,
                            app->desired_width, app->desired_height,
                            &extent_w, &extent_h);
    if (extent_w == 0u || extent_h == 0u ||
        caps.maxImageExtent.width == 0u || caps.maxImageExtent.height == 0u) {
        return VK_NOT_READY;
    }

    uint32_t present_family = app->present_family;
    VkBool32 supports_present = VK_FALSE;
    r = vkGetPhysicalDeviceSurfaceSupportKHR(app->physical_device, present_family,
                                             app->surface, &supports_present);
    if (r != VK_SUCCESS) return wsi_result(app, "surface_support", r);
    if (!supports_present && present_family != app->graphics_family) {
        present_family = app->graphics_family;
        r = vkGetPhysicalDeviceSurfaceSupportKHR(app->physical_device, present_family,
                                                 app->surface, &supports_present);
        if (r != VK_SUCCESS) return wsi_result(app, "surface_support_graphics", r);
    }
    if (!supports_present) {
        return wsi_result(app, "surface_support_changed", VK_ERROR_INITIALIZATION_FAILED);
    }

    uint32_t fmt_count = 0u;
    r = vkGetPhysicalDeviceSurfaceFormatsKHR(app->physical_device, app->surface, &fmt_count, NULL);
    if (r != VK_SUCCESS) return wsi_result(app, "surface_formats", r);
    if (fmt_count == 0u) return wsi_result(app, "surface_formats", VK_ERROR_FORMAT_NOT_SUPPORTED);
    if (fmt_count > 16u) {
        fmt_count = 16u;
    }
    VkSurfaceFormatKHR fmts[16];
    r = vkGetPhysicalDeviceSurfaceFormatsKHR(app->physical_device, app->surface, &fmt_count, fmts);
    if (r != VK_SUCCESS && r != VK_INCOMPLETE) {
        return wsi_result(app, "surface_formats_read", r);
    }
    if (fmt_count == 0u) return wsi_result(app, "surface_formats_read", VK_ERROR_FORMAT_NOT_SUPPORTED);
    VkSurfaceFormatKHR chosen = fmts[0];
    if (fmt_count == 1u && chosen.format == VK_FORMAT_UNDEFINED) {
        chosen.format = VK_FORMAT_R8G8B8A8_UNORM;
    }
    for (uint32_t i = 0u; i < fmt_count; ++i) {
        if (fmts[i].format == VK_FORMAT_R8G8B8A8_UNORM &&
            fmts[i].colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) {
            chosen = fmts[i];
            break;
        }
    }

    if (!(caps.supportedUsageFlags & VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT)) {
        return wsi_result(app, "surface_color_attachment_usage", VK_ERROR_FORMAT_NOT_SUPPORTED);
    }

    const uint32_t min_images = vk_canary_choose_image_count(caps.minImageCount, caps.maxImageCount);
    if (min_images < caps.minImageCount) {
        set_failure(app, "swapchain_min_image_limit", VK_ERROR_INITIALIZATION_FAILED);
        return VK_ERROR_INITIALIZATION_FAILED;
    }
    const VkSurfaceTransformFlagBitsKHR pre_transform =
        (caps.supportedTransforms & VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR) != 0u
            ? VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR
            : caps.currentTransform;
    const VkCompositeAlphaFlagBitsKHR alpha_modes[] = {
        VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR,
        VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR,
        VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR,
        VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR,
    };
    VkCompositeAlphaFlagBitsKHR composite_alpha = 0;
    for (size_t i = 0; i < sizeof(alpha_modes) / sizeof(alpha_modes[0]); ++i) {
        if (caps.supportedCompositeAlpha & alpha_modes[i]) {
            composite_alpha = alpha_modes[i];
            break;
        }
    }
    if (!composite_alpha) {
        return wsi_result(app, "surface_composite_alpha", VK_ERROR_INITIALIZATION_FAILED);
    }

    const uint32_t queue_families[2] = {app->graphics_family, present_family};
    const int shared_queues = app->graphics_family != present_family;
    const VkSwapchainKHR old_swapchain = app->swapchain;

    const VkSwapchainCreateInfoKHR sc_info = {
        .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR,
        .surface = app->surface,
        .minImageCount = min_images,
        .imageFormat = chosen.format,
        .imageColorSpace = chosen.colorSpace,
        .imageExtent = {.width = extent_w, .height = extent_h},
        .imageArrayLayers = 1u,
        .imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT,
        .imageSharingMode = shared_queues ? VK_SHARING_MODE_CONCURRENT : VK_SHARING_MODE_EXCLUSIVE,
        .queueFamilyIndexCount = shared_queues ? 2u : 0u,
        .pQueueFamilyIndices = shared_queues ? queue_families : NULL,
        .preTransform = pre_transform,
        .compositeAlpha = composite_alpha,
        .presentMode = VK_PRESENT_MODE_FIFO_KHR,
        .clipped = VK_TRUE,
        .oldSwapchain = old_swapchain,
    };

    VkSwapchainKHR new_swapchain = VK_NULL_HANDLE;
    if (old_swapchain != VK_NULL_HANDLE) {
        const uint32_t resizes = app->resizes;
        const uint32_t suspends = app->suspends;
        r = wait_for_retirement(app, "idle_recreate");
        if (r != VK_SUCCESS) return r;
        drain_events(app);
        if (next_step(app) != VK_CANARY_CREATE_CHAIN ||
            resizes != app->resizes || suspends != app->suspends) return VK_NOT_READY;
    }
    r = vkCreateSwapchainKHR(app->device, &sc_info, NULL, &new_swapchain);
    if (r == VK_ERROR_DEVICE_LOST) return wsi_result(app, "create_swapchain", r);
    /* An attempted replacement consumes oldSwapchain even on failure. Keep
     * ownership until it is destroyed, then retry with VK_NULL_HANDLE. */
    destroy_swapchain(app);
    if (r != VK_SUCCESS) return wsi_result(app, "create_swapchain", r);
    app->swapchain = new_swapchain;
    vkGetDeviceQueue(app->device, present_family, 0u, &app->present_queue);
    app->swapchain_format = chosen.format;
    app->swapchain_extent.width = extent_w;
    app->swapchain_extent.height = extent_h;

    r = ensure_pipeline_for_format(app, chosen.format);
    if (r != VK_SUCCESS) {
        return r;
    }

    uint32_t img_count = 0u;
    r = vkGetSwapchainImagesKHR(app->device, app->swapchain, &img_count, NULL);
    if (r != VK_SUCCESS) return wsi_result(app, "swapchain_images_count", r);
    if (img_count == 0u) return wsi_result(app, "swapchain_images_count", VK_ERROR_INITIALIZATION_FAILED);
    if (img_count > VK_CANARY_MAX_SWAPCHAIN_IMAGES) {
        set_failure(app, "swapchain_image_limit", VK_ERROR_INITIALIZATION_FAILED);
        return VK_ERROR_INITIALIZATION_FAILED;
    }
    r = vkGetSwapchainImagesKHR(app->device, app->swapchain, &img_count, app->swapchain_images);
    if (r != VK_SUCCESS || img_count == 0u) {
        return wsi_result(app, "swapchain_images", r == VK_SUCCESS ? VK_ERROR_INITIALIZATION_FAILED : r);
    }
    app->swapchain_image_count = img_count;

    const VkSemaphoreCreateInfo sem_info = {.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO};
    for (uint32_t i = 0u; i < img_count; ++i) {
        r = vkCreateSemaphore(app->device, &sem_info, NULL, &app->render_finished[i]);
        if (r != VK_SUCCESS) {
            set_failure(app, "create_present_semaphore", r);
            return r;
        }
        const VkImageViewCreateInfo view_info = {
            .sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO,
            .image = app->swapchain_images[i],
            .viewType = VK_IMAGE_VIEW_TYPE_2D,
            .format = app->swapchain_format,
            .components = {
                .r = VK_COMPONENT_SWIZZLE_IDENTITY,
                .g = VK_COMPONENT_SWIZZLE_IDENTITY,
                .b = VK_COMPONENT_SWIZZLE_IDENTITY,
                .a = VK_COMPONENT_SWIZZLE_IDENTITY,
            },
            .subresourceRange = {
                .aspectMask = VK_IMAGE_ASPECT_COLOR_BIT,
                .baseMipLevel = 0u,
                .levelCount = 1u,
                .baseArrayLayer = 0u,
                .layerCount = 1u,
            },
        };
        r = vkCreateImageView(app->device, &view_info, NULL, &app->swapchain_views[i]);
        if (r != VK_SUCCESS) {
            set_failure(app, "create_image_view", r);
            return r;
        }
        const VkFramebufferCreateInfo fb_info = {
            .sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO,
            .renderPass = app->render_pass,
            .attachmentCount = 1u,
            .pAttachments = &app->swapchain_views[i],
            .width = app->swapchain_extent.width,
            .height = app->swapchain_extent.height,
            .layers = 1u,
        };
        r = vkCreateFramebuffer(app->device, &fb_info, NULL, &app->framebuffers[i]);
        if (r != VK_SUCCESS) {
            set_failure(app, "create_framebuffer", r);
            return r;
        }
    }

    char line[192];
    if (vk_canary_format_swapchain(line, sizeof(line), app->swapchain_image_count,
                                   app->swapchain_extent.width, app->swapchain_extent.height,
                                   (int32_t)app->swapchain_format) > 0) {
        emit_log_line(NXN_LOG_INFO, line);
    }
    return VK_SUCCESS;
}

static VkResult open_surface(CanaryApp* app) {
    if (app->surface != VK_NULL_HANDLE) {
        if (app->device != VK_NULL_HANDLE) {
            const VkResult r = wait_for_retirement(app, "idle_reopen");
            if (r != VK_SUCCESS) return r;
            destroy_swapchain(app);
        }
        vkDestroySurfaceKHR(app->instance, app->surface, NULL);
        app->surface = VK_NULL_HANDLE;
        drain_events(app);
        if (next_step(app) != VK_CANARY_OPEN_SURFACE) return VK_NOT_READY;
    }

    VkSurfaceKHR surface = VK_NULL_HANDLE;
    ++app->surface_attempts;
    VkResult r = app->create_wsi_surface(app->instance, &surface);
    if (r == VK_SUCCESS && surface != VK_NULL_HANDLE) {
        app->surface = surface;
        if (app->device != VK_NULL_HANDLE) {
            emit_log_line(NXN_LOG_INFO, "N5V11: event=surface_reopen");
        }
        return VK_SUCCESS;
    }
    return wsi_result(app, "open_surface", r == VK_SUCCESS ? VK_ERROR_INITIALIZATION_FAILED : r);
}

static void request_recreate(CanaryApp* app) {
    app->phase = vk_canary_wsi_transition(app->phase, VK_CANARY_ACTION_RECREATE);
}

static vk_canary_phase next_step(const CanaryApp* app) {
    return vk_canary_next_step(app->phase, app->quit_requested, app->suspended,
                               app->desired_width, app->desired_height);
}

static void drain_events(CanaryApp* app) {
    if (nxn_should_quit()) {
        app->quit_requested = 1;
    }
    nxn_event ev = NXN_STRUCT_INIT(nxn_event);
    while (nxn_event_poll(&ev) > 0) {
        switch (ev.type) {
            case NXN_EVENT_QUIT:
                app->quit_requested = 1;
                break;
            case NXN_EVENT_RESIZE:
                app->desired_width = ev.width;
                app->desired_height = ev.height;
                app->resizes++;
                request_recreate(app);
                nxn_log(NXN_LOG_INFO, "N5V11: event=resize extent=%ux%u",
                        (unsigned)ev.width, (unsigned)ev.height);
                break;
            case NXN_EVENT_SUSPEND:
                if (!app->suspended) {
                    app->suspended = 1;
                    app->suspends++;
                    emit_log_line(NXN_LOG_INFO, "N5V11: event=suspend");
                }
                break;
            case NXN_EVENT_RESUME:
                if (app->suspended) {
                    app->suspended = 0;
                    request_recreate(app);
                    emit_log_line(NXN_LOG_INFO, "N5V11: event=resume");
                }
                break;
            case NXN_EVENT_FOCUS:
                app->focused = ev.focused ? 1 : 0;
                break;
            case NXN_EVENT_DOCK:
                if (ev.width > 0u && ev.height > 0u) {
                    nxn_log(NXN_LOG_INFO, "N5V11: event=dock docked=%u output=%ux%u",
                            (unsigned)ev.docked, (unsigned)ev.width, (unsigned)ev.height);
                }
                break;
            default:
                break;
        }
        ev.size = (uint32_t)sizeof(ev);
    }
}

static VkResult record_command_buffer(CanaryApp* app, VkCommandBuffer cmd, uint32_t image_index) {
    VkResult r = vkResetCommandBuffer(cmd, 0u);
    if (r != VK_SUCCESS) {
        set_failure(app, "reset_cmd", r);
        return r;
    }
    const VkCommandBufferBeginInfo begin_info = {
        .sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
        .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
    };
    r = vkBeginCommandBuffer(cmd, &begin_info);
    if (r != VK_SUCCESS) {
        set_failure(app, "begin_cmd", r);
        return r;
    }

    const VkClearValue clear_value = {
        .color = {.float32 = {0.08f, 0.11f, 0.16f, 1.0f}},
    };
    const VkRenderPassBeginInfo rp_begin = {
        .sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO,
        .renderPass = app->render_pass,
        .framebuffer = app->framebuffers[image_index],
        .renderArea = {.offset = {0, 0}, .extent = app->swapchain_extent},
        .clearValueCount = 1u,
        .pClearValues = &clear_value,
    };
    vkCmdBeginRenderPass(cmd, &rp_begin, VK_SUBPASS_CONTENTS_INLINE);
    vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, app->pipeline);

    const VkViewport viewport = {
        .x = 0.0f,
        .y = 0.0f,
        .width = (float)app->swapchain_extent.width,
        .height = (float)app->swapchain_extent.height,
        .minDepth = 0.0f,
        .maxDepth = 1.0f,
    };
    const VkRect2D scissor = {
        .offset = {0, 0},
        .extent = app->swapchain_extent,
    };
    vkCmdSetViewport(cmd, 0u, 1u, &viewport);
    vkCmdSetScissor(cmd, 0u, 1u, &scissor);
    vkCmdDraw(cmd, 3u, 1u, 0u, 0u);
    vkCmdEndRenderPass(cmd);

    r = vkEndCommandBuffer(cmd);
    if (r != VK_SUCCESS) {
        set_failure(app, "end_cmd", r);
    }
    return r;
}

static void emit_stats_window(CanaryApp* app) {
    vk_canary_summary summary;
    if (!vk_canary_stats_summarize(&app->stats, &summary)) {
        return;
    }
    char line[256];
    if (vk_canary_format_window(line, sizeof(line), &summary, app->swapchain_image_count) > 0) {
        emit_log_line(NXN_LOG_INFO, line);
    }
    vk_canary_stats_reset_window(&app->stats);
}

static int run_vulkan_canary(const vk_canary_config* cfg, uint16_t vk_major, uint16_t vk_minor) {
    CanaryApp app;
    memset(&app, 0, sizeof(app));
    app.mode = cfg->mode;
    app.desired_width = cfg->mode == VK_CANARY_MODE_FULLSCREEN ? 1280u : 960u;
    app.desired_height = cfg->mode == VK_CANARY_MODE_FULLSCREEN ? 720u : 540u;
    app.phase = VK_CANARY_OPEN_SURFACE;
    uint32_t final_images = 0u;
    app.focused = 1;
    vk_canary_stats_init(&app.stats);

    char line[256];
    if (vk_canary_format_start(line, sizeof(line), app.mode, vk_major, vk_minor) > 0) {
        emit_log_line(NXN_LOG_INFO, line);
    }

    if (cfg->mode_override) {
        nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
        if (nxn_caps_get(&caps) == NXN_OK && (caps.features & NXN_CAP_WINDOW_CTL) != 0u) {
            (void)nxn_window_set_mode(cfg->mode == VK_CANARY_MODE_FULLSCREEN ? NXN_WIN_FULLSCREEN
                                                                             : NXN_WIN_NORMAL);
        }
    }

    app.get_wsi_extensions = (PFN_nxn_vk_wsi_instance_extensions)nxn_vk_proc("nxn_vk_wsi_instance_extensions");
    app.create_wsi_surface = (PFN_nxn_vk_wsi_create_surface)nxn_vk_proc("nxn_vk_wsi_create_surface");
    if (!app.create_wsi_surface) {
        set_failure(&app, "wsi_surface_hook_missing", VK_ERROR_EXTENSION_NOT_PRESENT);
        goto done;
    }

    if (create_instance(&app) != VK_SUCCESS) {
        goto done;
    }
    while (!app.fail_reason[0]) {
        drain_events(&app);
        const vk_canary_phase step = next_step(&app);
        if (step == VK_CANARY_STOP) break;
        if (step == VK_CANARY_PAUSE) {
            nxn_sleep_ns(VK_CANARY_WAIT_SLICE_NS);
            continue;
        }

        if (step == VK_CANARY_OPEN_SURFACE || step == VK_CANARY_CREATE_CHAIN) {
            VkResult r = VK_SUCCESS;
            if (step == VK_CANARY_OPEN_SURFACE) {
                r = open_surface(&app);
            } else {
                if (app.device == VK_NULL_HANDLE) {
                    r = pick_physical_device_and_create_device(&app);
                    if (r == VK_SUCCESS) r = create_static_resources(&app);
                }
                if (r == VK_SUCCESS) r = recreate_swapchain(&app);
                if (r == VK_SUCCESS) app.surface_attempts = 0u;
            }
            if (app.fail_reason[0]) break;
            const vk_canary_action action = vk_canary_wsi_action(step, (int32_t)r);
            app.phase = vk_canary_wsi_transition(step, action);
            if (app.phase == VK_CANARY_OPEN_SURFACE &&
                app.surface_attempts >= VK_CANARY_REOPEN_MAX_TRIES) {
                set_failure(&app, "surface_reopen_failed", r);
                break;
            }
            if (r != VK_SUCCESS) nxn_sleep_ns(VK_CANARY_WAIT_SLICE_NS);
            continue;
        }

        const uint64_t frame_start_ns = nxn_time_ns();
        const uint32_t slot = app.current_frame;
        VkResult wr = VK_TIMEOUT;
        while (wr == VK_TIMEOUT && next_step(&app) == VK_CANARY_DRAW) {
            wr = vkWaitForFences(app.device, 1u, &app.in_flight[slot], VK_TRUE, VK_CANARY_WAIT_SLICE_NS);
            if (wr == VK_TIMEOUT || wr == VK_SUCCESS) {
                drain_events(&app);
            }
        }
        if (wr != VK_SUCCESS && wr != VK_TIMEOUT) {
            set_failure(&app, wr == VK_ERROR_DEVICE_LOST ? "device_lost_fence" : "wait_fence", wr);
            break;
        }
        if (next_step(&app) != VK_CANARY_DRAW) continue;

        uint32_t image_index = 0u;
        VkResult ar = vkAcquireNextImageKHR(app.device, app.swapchain, VK_CANARY_WAIT_SLICE_NS,
                                            app.image_available[slot], VK_NULL_HANDLE, &image_index);
        const vk_canary_action acquire_act = vk_canary_classify_result((int32_t)ar);
        if (acquire_act == VK_CANARY_ACTION_RETRY) {
            nxn_sleep_ns(4000000ULL);
            continue;
        }
        if (ar != VK_SUCCESS) {
            wsi_result(&app, "acquire_image", ar);
            app.phase = vk_canary_wsi_transition(app.phase, acquire_act);
            if (ar != VK_SUBOPTIMAL_KHR) continue;
        }
        app.acquire_unsubmitted = 1;
        const uint32_t present_index =
            vk_canary_present_semaphore_index(image_index, app.swapchain_image_count);
        if (present_index == UINT32_MAX) {
            set_failure(&app, "acquire_image_index", VK_ERROR_INITIALIZATION_FAILED);
            break;
        }
        /* Waiting on this image's acquire semaphore also orders the new
         * render-finished signal after its previous presentation wait. */
        const VkSemaphore* render_finished = &app.render_finished[present_index];

        VkResult r = vkResetFences(app.device, 1u, &app.in_flight[slot]);
        if (r != VK_SUCCESS) {
            set_failure(&app, "reset_fence", r);
            break;
        }
        if (record_command_buffer(&app, app.command_buffers[slot], image_index) != VK_SUCCESS) {
            break;
        }

        const VkPipelineStageFlags wait_stage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        const VkSubmitInfo submit_info = {
            .sType = VK_STRUCTURE_TYPE_SUBMIT_INFO,
            .waitSemaphoreCount = 1u,
            .pWaitSemaphores = &app.image_available[slot],
            .pWaitDstStageMask = &wait_stage,
            .commandBufferCount = 1u,
            .pCommandBuffers = &app.command_buffers[slot],
            .signalSemaphoreCount = 1u,
            .pSignalSemaphores = render_finished,
        };
        r = vkQueueSubmit(app.graphics_queue, 1u, &submit_info, app.in_flight[slot]);
        if (r != VK_SUCCESS) {
            set_failure(&app, r == VK_ERROR_DEVICE_LOST ? "device_lost_submit" : "queue_submit", r);
            break;
        }
        app.acquire_unsubmitted = 0;

        const VkPresentInfoKHR present_info = {
            .sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR,
            .waitSemaphoreCount = 1u,
            .pWaitSemaphores = render_finished,
            .swapchainCount = 1u,
            .pSwapchains = &app.swapchain,
            .pImageIndices = &image_index,
        };
        VkResult pr = vkQueuePresentKHR(app.present_queue, &present_info);
        const vk_canary_action present_act = vk_canary_classify_result((int32_t)pr);
        if (present_act == VK_CANARY_ACTION_RECREATE || present_act == VK_CANARY_ACTION_REOPEN_SURFACE) {
            app.phase = vk_canary_wsi_transition(app.phase, present_act);
        } else if (pr != VK_SUCCESS) {
            set_failure(&app, present_act == VK_CANARY_ACTION_DEVICE_LOST ? "device_lost_present" : "queue_present", pr);
            break;
        }

        app.current_frame = (slot + 1u) % VK_CANARY_FRAMES_IN_FLIGHT;
        if (!vk_canary_present_accepted((int32_t)pr)) continue;
        const uint64_t frame_end_ns = nxn_time_ns();
        const uint64_t elapsed_ns = frame_end_ns >= frame_start_ns ? (frame_end_ns - frame_start_ns) : 0u;
        if (vk_canary_stats_record(&app.stats, elapsed_ns)) {
            emit_stats_window(&app);
            if (cfg->max_windows > 0u && app.stats.windows_completed >= cfg->max_windows) {
                break;
            }
        }
        if (cfg->max_frames > 0u && app.stats.total_frames >= cfg->max_frames) {
            break;
        }
    }

    if (!app.fail_reason[0] && app.stats.count > 0u) {
        emit_stats_window(&app);
    }

done:
    final_images = app.swapchain_image_count;
    teardown_vulkan(&app);
    if (app.fail_reason[0]) {
        const char* user_msg = app.device_lost
            ? localized_or("canary.device_lost", "Vulkan device lost")
            : localized_or("canary.init_failed", "Vulkan initialization failed");
        puts(user_msg);
        fflush(stdout);
    }

    const int passed = !app.fail_reason[0] && app.stats.total_frames > 0u;
    if (!passed && !app.fail_reason[0]) {
        snprintf(app.fail_reason, sizeof(app.fail_reason), "%s", "no_frames_rendered");
    }
    if (vk_canary_format_verdict(line, sizeof(line), passed, app.mode, app.stats.total_frames,
                                 final_images, app.resizes, app.suspends,
                                 app.fail_reason, app.fail_vk_result) > 0) {
        emit_log_line(passed ? NXN_LOG_INFO : NXN_LOG_ERROR, line);
    }
    return passed ? 0 : 1;
}
#endif

int main(int argc, char** argv) {
    vk_canary_config cfg;
    int args_rc = vk_canary_parse_args(argc, argv, &cfg);
    if (args_rc == 0 && argc <= 1) {
        // Native apps start without a command line: a test script (remote test phase V) can put the same options
        // into the data folder's args.txt, e.g. "--mode fullscreen --frames 1200".
        char text[128];
        size_t got = 0u;
        if (nxn_fs_read(NXN_DIR_DATA, "args.txt", text, sizeof(text) - 1u, &got) == NXN_OK) {
            text[got < sizeof(text) ? got : sizeof(text) - 1u] = '\0';
            args_rc = vk_canary_parse_arg_text(text, &cfg);
        }
    }
    if (args_rc != 0) {
        emit_log_line(NXN_LOG_ERROR, "N5V11: FAIL reason=invalid_args vk_result=0 mode=window frames=0");
        return 1;
    }
    if (!cfg.mode_override) {
        cfg.mode = read_bundle_mode();
    }

    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    uint16_t vk_major = 0u;
    uint16_t vk_minor = 0u;
    const int caps_ok = nxn_caps_get(&caps) == NXN_OK &&
                        vk_canary_caps_supports_vulkan(&caps, &vk_major, &vk_minor);
    if (!caps_ok || !nxn_vk_available()) {
        return report_unavailable();
    }

#if defined(NEXVYN_VK_SHIMS) && NEXVYN_VK_SHIMS
    if (!vkGetInstanceProcAddr(VK_NULL_HANDLE, "vkCreateInstance")) {
        return report_unavailable();
    }
    return run_vulkan_canary(&cfg, vk_major, vk_minor);
#else
    return report_unavailable();
#endif
}
