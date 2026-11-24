/* Vulkan variant of the GL gpu_stress load app (N5-H.2). Same load.txt contract, load table and
 * GSTRESS: log lines as ../../src/main.cpp, so tools/n5_h2_shell_load.py parses both. Each frame
 * records `draws` full-screen alpha-blended triangles in one render pass. Setup mirrors vk_canary. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include <nexvyn/nexvyn_native.h>
#include <nexvyn/nxn_vk.h>

#include <vulkan/vulkan_core.h>
#include "vk_canary_shaders.h"

#define BATCH_FRAMES 300u
#define SECOND_NS 1000000000ULL
#define MAX_IMAGES 8u
#define IN_FLIGHT 2u
#define WAIT_NS 16000000ULL

typedef struct Load { uint32_t texture; uint32_t draws; int taps; } Load;
/* Same table as the GL app; "texture" is only reported (the Vulkan scene is texture-free). */
static const Load kLoads[] = {{64, 1, 1}, {256, 4, 2}, {512, 16, 3}, {1024, 48, 5}, {2048, 96, 8}};

typedef struct Settings { unsigned level, seconds; uint32_t width, height; } Settings;

typedef VkResult(VKAPI_PTR* PFN_wsi_exts)(uint32_t* count, const char** names);
typedef VkResult(VKAPI_PTR* PFN_wsi_surface)(VkInstance instance, VkSurfaceKHR* surface);

static int read_settings(Settings* s) {
    char in[32];
    size_t size = 0;
    nxn_result rd = nxn_fs_read(NXN_DIR_DATA, "load.txt", in, sizeof(in) - 1, &size);
    if (rd == NXN_ERR_NOT_FOUND) return 1;
    if (rd != NXN_OK || size == 0 || in[0] < '0' || in[0] > '4' || memchr(in, '\0', size)) return 0;
    in[size] = '\0';
    s->level = (unsigned)(in[0] - '0');
    char* p = in + 1;
    if (*p && !isspace((unsigned char)*p)) return 0;
    while (isspace((unsigned char)*p)) ++p;
    if (!*p) return 1;
    if (*p < '0' || *p > '9') return 0;
    char* end = NULL;
    unsigned long sec = strtoul(p, &end, 10);
    if (sec < 1 || sec > 180 || (*end && !isspace((unsigned char)*end))) return 0;
    while (isspace((unsigned char)*end)) ++end;
    if (*end) {
        char* e = end + strlen(end);
        while (e > end && isspace((unsigned char)e[-1])) --e;
        *e = '\0';
        if (strcmp(end, "720p") == 0) { s->width = 1280; s->height = 720; }
        else if (strcmp(end, "1080p") == 0) { s->width = 1920; s->height = 1080; }
        else return 0;
    }
    s->seconds = (unsigned)sec;
    return 1;
}

static int cmp_u64(const void* a, const void* b) {
    uint64_t x = *(const uint64_t*)a, y = *(const uint64_t*)b;
    return x < y ? -1 : x > y;
}

typedef struct App {
    VkInstance instance;
    VkSurfaceKHR surface;
    VkPhysicalDevice gpu;
    VkDevice device;
    uint32_t family;
    VkQueue queue;
    VkShaderModule vert, frag;
    VkPipelineLayout layout;
    VkRenderPass pass;
    VkPipeline pipeline;
    VkSwapchainKHR swapchain;
    VkExtent2D extent;
    uint32_t image_count;
    VkImageView views[MAX_IMAGES];
    VkFramebuffer fbs[MAX_IMAGES];
    VkSemaphore render_done[MAX_IMAGES];
    VkCommandPool pool;
    VkCommandBuffer cmds[IN_FLIGHT];
    VkSemaphore image_ready[IN_FLIGHT];
    VkFence fences[IN_FLIGHT];
} App;

#define CHECK(call, what) do { VkResult r_ = (call); if (r_ != VK_SUCCESS) { \
    printf("GSTRESS: FAIL %s vk_result=%d\n", what, (int)r_); return 0; } } while (0)

static int init_vulkan(App* a, uint32_t want_w, uint32_t want_h, int32_t taps) {
    PFN_wsi_exts get_exts = (PFN_wsi_exts)nxn_vk_proc("nxn_vk_wsi_instance_extensions");
    PFN_wsi_surface make_surface = (PFN_wsi_surface)nxn_vk_proc("nxn_vk_wsi_create_surface");
    if (!make_surface) { printf("GSTRESS: FAIL wsi_surface_hook_missing\n"); return 0; }

    const char* names[16];
    uint32_t n = 0;
    if (get_exts) {
        if (get_exts(&n, NULL) != VK_SUCCESS) return 0;
        if (n > 16) n = 16;
        VkResult r = n ? get_exts(&n, names) : VK_SUCCESS;
        if (r != VK_SUCCESS && r != VK_INCOMPLETE) return 0;
    }
    if (n == 0) { names[0] = VK_KHR_SURFACE_EXTENSION_NAME; n = 1; }
    const VkApplicationInfo ai = {.sType = VK_STRUCTURE_TYPE_APPLICATION_INFO, .pApplicationName = "GPU Stress",
                                  .apiVersion = VK_API_VERSION_1_3};
    const VkInstanceCreateInfo ici = {.sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO, .pApplicationInfo = &ai,
                                      .enabledExtensionCount = n, .ppEnabledExtensionNames = names};
    CHECK(vkCreateInstance(&ici, NULL, &a->instance), "create_instance");
    CHECK(make_surface(a->instance, &a->surface), "create_surface");

    uint32_t gc = 0;
    VkPhysicalDevice gpus[8];
    CHECK(vkEnumeratePhysicalDevices(a->instance, &gc, NULL), "enum_devices");
    if (gc > 8) gc = 8;
    VkResult er = vkEnumeratePhysicalDevices(a->instance, &gc, gpus);
    if ((er != VK_SUCCESS && er != VK_INCOMPLETE) || gc == 0) { printf("GSTRESS: FAIL no_device\n"); return 0; }
    int found = 0;
    for (uint32_t g = 0; g < gc && !found; ++g) {
        VkPhysicalDeviceProperties props;
        vkGetPhysicalDeviceProperties(gpus[g], &props);
        if (props.apiVersion < VK_API_VERSION_1_3) continue;
        uint32_t qc = 16;
        VkQueueFamilyProperties qp[16];
        vkGetPhysicalDeviceQueueFamilyProperties(gpus[g], &qc, qp);
        for (uint32_t i = 0; i < qc; ++i) {
            VkBool32 present = VK_FALSE;
            if (vkGetPhysicalDeviceSurfaceSupportKHR(gpus[g], i, a->surface, &present) != VK_SUCCESS) return 0;
            if ((qp[i].queueFlags & VK_QUEUE_GRAPHICS_BIT) && present) {
                a->gpu = gpus[g]; a->family = i; found = 1; break;
            }
        }
    }
    if (!found) { printf("GSTRESS: FAIL no_queue_family\n"); return 0; }

    const float prio = 1.0f;
    const VkDeviceQueueCreateInfo qi = {.sType = VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO,
                                        .queueFamilyIndex = a->family, .queueCount = 1, .pQueuePriorities = &prio};
    const char* dext[] = {VK_KHR_SWAPCHAIN_EXTENSION_NAME};
    const VkDeviceCreateInfo di = {.sType = VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO, .queueCreateInfoCount = 1,
                                   .pQueueCreateInfos = &qi, .enabledExtensionCount = 1, .ppEnabledExtensionNames = dext};
    CHECK(vkCreateDevice(a->gpu, &di, NULL, &a->device), "create_device");
    /* Bind vkDeviceWaitIdle while the app is alive (the loader refuses new lookups after close). */
    (void)vkDeviceWaitIdle(a->device);
    vkGetDeviceQueue(a->device, a->family, 0, &a->queue);

    const VkShaderModuleCreateInfo vi = {.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                                         .codeSize = sizeof(kVkCanaryVertSpv), .pCode = kVkCanaryVertSpv};
    const VkShaderModuleCreateInfo fi = {.sType = VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO,
                                         .codeSize = sizeof(kVkCanaryFragSpv), .pCode = kVkCanaryFragSpv};
    CHECK(vkCreateShaderModule(a->device, &vi, NULL, &a->vert), "vert_shader");
    CHECK(vkCreateShaderModule(a->device, &fi, NULL, &a->frag), "frag_shader");
    /* No push constants: early N5 OS builds did not export vkCmdPushConstants (the call was
     * dropped, taps=0, black window). Taps is a specialization constant and the per-draw phase travels
     * in firstInstance, so the app also works on those builds. */
    const VkPipelineLayoutCreateInfo li = {.sType = VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO};
    CHECK(vkCreatePipelineLayout(a->device, &li, NULL, &a->layout), "pipeline_layout");

    VkSurfaceCapabilitiesKHR caps;
    CHECK(vkGetPhysicalDeviceSurfaceCapabilitiesKHR(a->gpu, a->surface, &caps), "surface_caps");
    if (caps.currentExtent.width != 0xFFFFFFFFu) {
        a->extent = caps.currentExtent;
    } else {
        a->extent.width = want_w < caps.minImageExtent.width ? caps.minImageExtent.width
                        : want_w > caps.maxImageExtent.width ? caps.maxImageExtent.width : want_w;
        a->extent.height = want_h < caps.minImageExtent.height ? caps.minImageExtent.height
                         : want_h > caps.maxImageExtent.height ? caps.maxImageExtent.height : want_h;
    }
    if (!a->extent.width || !a->extent.height) { printf("GSTRESS: FAIL zero_extent\n"); return 0; }

    uint32_t fc = 16;
    VkSurfaceFormatKHR fmts[16];
    VkResult fr = vkGetPhysicalDeviceSurfaceFormatsKHR(a->gpu, a->surface, &fc, fmts);
    if ((fr != VK_SUCCESS && fr != VK_INCOMPLETE) || fc == 0) { printf("GSTRESS: FAIL surface_formats\n"); return 0; }
    VkSurfaceFormatKHR fmt = fmts[0];
    if (fc == 1 && fmt.format == VK_FORMAT_UNDEFINED) fmt.format = VK_FORMAT_R8G8B8A8_UNORM;
    for (uint32_t i = 0; i < fc; ++i)
        if (fmts[i].format == VK_FORMAT_R8G8B8A8_UNORM && fmts[i].colorSpace == VK_COLOR_SPACE_SRGB_NONLINEAR_KHR) { fmt = fmts[i]; break; }

    uint32_t min_images = caps.minImageCount + 1;
    if (caps.maxImageCount && min_images > caps.maxImageCount) min_images = caps.maxImageCount;
    VkCompositeAlphaFlagBitsKHR alpha = 0;
    const VkCompositeAlphaFlagBitsKHR modes[] = {VK_COMPOSITE_ALPHA_OPAQUE_BIT_KHR, VK_COMPOSITE_ALPHA_PRE_MULTIPLIED_BIT_KHR,
                                                 VK_COMPOSITE_ALPHA_POST_MULTIPLIED_BIT_KHR, VK_COMPOSITE_ALPHA_INHERIT_BIT_KHR};
    for (size_t i = 0; i < 4 && !alpha; ++i) if (caps.supportedCompositeAlpha & modes[i]) alpha = modes[i];
    if (!alpha || !(caps.supportedUsageFlags & VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT)) {
        printf("GSTRESS: FAIL surface_caps_unsupported\n"); return 0;
    }
    const VkSwapchainCreateInfoKHR sci = {
        .sType = VK_STRUCTURE_TYPE_SWAPCHAIN_CREATE_INFO_KHR, .surface = a->surface, .minImageCount = min_images,
        .imageFormat = fmt.format, .imageColorSpace = fmt.colorSpace, .imageExtent = a->extent, .imageArrayLayers = 1,
        .imageUsage = VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT, .imageSharingMode = VK_SHARING_MODE_EXCLUSIVE,
        .preTransform = (caps.supportedTransforms & VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR)
                            ? VK_SURFACE_TRANSFORM_IDENTITY_BIT_KHR : caps.currentTransform,
        .compositeAlpha = alpha, .presentMode = VK_PRESENT_MODE_FIFO_KHR, .clipped = VK_TRUE};
    CHECK(vkCreateSwapchainKHR(a->device, &sci, NULL, &a->swapchain), "create_swapchain");

    const VkAttachmentDescription att = {.format = fmt.format, .samples = VK_SAMPLE_COUNT_1_BIT,
        .loadOp = VK_ATTACHMENT_LOAD_OP_CLEAR, .storeOp = VK_ATTACHMENT_STORE_OP_STORE,
        .stencilLoadOp = VK_ATTACHMENT_LOAD_OP_DONT_CARE, .stencilStoreOp = VK_ATTACHMENT_STORE_OP_DONT_CARE,
        .initialLayout = VK_IMAGE_LAYOUT_UNDEFINED, .finalLayout = VK_IMAGE_LAYOUT_PRESENT_SRC_KHR};
    const VkAttachmentReference ref = {.attachment = 0, .layout = VK_IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL};
    const VkSubpassDescription sub = {.pipelineBindPoint = VK_PIPELINE_BIND_POINT_GRAPHICS,
                                      .colorAttachmentCount = 1, .pColorAttachments = &ref};
    const VkSubpassDependency dep = {.srcSubpass = VK_SUBPASS_EXTERNAL, .dstSubpass = 0,
        .srcStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT, .dstStageMask = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT,
        .dstAccessMask = VK_ACCESS_COLOR_ATTACHMENT_WRITE_BIT};
    const VkRenderPassCreateInfo rpi = {.sType = VK_STRUCTURE_TYPE_RENDER_PASS_CREATE_INFO, .attachmentCount = 1,
        .pAttachments = &att, .subpassCount = 1, .pSubpasses = &sub, .dependencyCount = 1, .pDependencies = &dep};
    CHECK(vkCreateRenderPass(a->device, &rpi, NULL, &a->pass), "render_pass");

    const VkSpecializationMapEntry spec_entry = {.constantID = 0, .offset = 0, .size = sizeof(taps)};
    const VkSpecializationInfo spec = {.mapEntryCount = 1, .pMapEntries = &spec_entry, .dataSize = sizeof(taps), .pData = &taps};
    const VkPipelineShaderStageCreateInfo stages[2] = {
        {.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, .stage = VK_SHADER_STAGE_VERTEX_BIT, .module = a->vert, .pName = "main"},
        {.sType = VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, .stage = VK_SHADER_STAGE_FRAGMENT_BIT, .module = a->frag, .pName = "main",
         .pSpecializationInfo = &spec}};
    const VkPipelineVertexInputStateCreateInfo vin = {.sType = VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO};
    const VkPipelineInputAssemblyStateCreateInfo ia = {.sType = VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
                                                       .topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST};
    const VkPipelineViewportStateCreateInfo vp = {.sType = VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO,
                                                  .viewportCount = 1, .scissorCount = 1};
    const VkPipelineRasterizationStateCreateInfo rs = {.sType = VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
        .polygonMode = VK_POLYGON_MODE_FILL, .cullMode = VK_CULL_MODE_NONE, .frontFace = VK_FRONT_FACE_COUNTER_CLOCKWISE, .lineWidth = 1.0f};
    const VkPipelineMultisampleStateCreateInfo ms = {.sType = VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
                                                     .rasterizationSamples = VK_SAMPLE_COUNT_1_BIT};
    /* Color blends; destination alpha keeps the opaque clear alpha (1.0). The compositor draws the
     * window texture alpha-blended over black, so a blended alpha below 1 darkens the whole window. */
    const VkPipelineColorBlendAttachmentState cba = {.blendEnable = VK_TRUE,
        .srcColorBlendFactor = VK_BLEND_FACTOR_SRC_ALPHA, .dstColorBlendFactor = VK_BLEND_FACTOR_ONE_MINUS_SRC_ALPHA,
        .colorBlendOp = VK_BLEND_OP_ADD, .srcAlphaBlendFactor = VK_BLEND_FACTOR_ZERO,
        .dstAlphaBlendFactor = VK_BLEND_FACTOR_ONE, .alphaBlendOp = VK_BLEND_OP_ADD,
        .colorWriteMask = VK_COLOR_COMPONENT_R_BIT | VK_COLOR_COMPONENT_G_BIT | VK_COLOR_COMPONENT_B_BIT | VK_COLOR_COMPONENT_A_BIT};
    const VkPipelineColorBlendStateCreateInfo cb = {.sType = VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
                                                    .attachmentCount = 1, .pAttachments = &cba};
    const VkDynamicState dyn[2] = {VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR};
    const VkPipelineDynamicStateCreateInfo ds = {.sType = VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO,
                                                 .dynamicStateCount = 2, .pDynamicStates = dyn};
    const VkGraphicsPipelineCreateInfo gpi = {.sType = VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO, .stageCount = 2,
        .pStages = stages, .pVertexInputState = &vin, .pInputAssemblyState = &ia, .pViewportState = &vp,
        .pRasterizationState = &rs, .pMultisampleState = &ms, .pColorBlendState = &cb, .pDynamicState = &ds,
        .layout = a->layout, .renderPass = a->pass};
    CHECK(vkCreateGraphicsPipelines(a->device, VK_NULL_HANDLE, 1, &gpi, NULL, &a->pipeline), "pipeline");

    VkImage images[MAX_IMAGES];
    uint32_t ic = MAX_IMAGES;
    VkResult ir = vkGetSwapchainImagesKHR(a->device, a->swapchain, &ic, images);
    if ((ir != VK_SUCCESS && ir != VK_INCOMPLETE) || ic == 0) { printf("GSTRESS: FAIL swapchain_images\n"); return 0; }
    a->image_count = ic;
    const VkSemaphoreCreateInfo semi = {.sType = VK_STRUCTURE_TYPE_SEMAPHORE_CREATE_INFO};
    for (uint32_t i = 0; i < ic; ++i) {
        const VkImageViewCreateInfo vwi = {.sType = VK_STRUCTURE_TYPE_IMAGE_VIEW_CREATE_INFO, .image = images[i],
            .viewType = VK_IMAGE_VIEW_TYPE_2D, .format = fmt.format,
            .subresourceRange = {VK_IMAGE_ASPECT_COLOR_BIT, 0, 1, 0, 1}};
        CHECK(vkCreateImageView(a->device, &vwi, NULL, &a->views[i]), "image_view");
        const VkFramebufferCreateInfo fbi = {.sType = VK_STRUCTURE_TYPE_FRAMEBUFFER_CREATE_INFO, .renderPass = a->pass,
            .attachmentCount = 1, .pAttachments = &a->views[i], .width = a->extent.width, .height = a->extent.height, .layers = 1};
        CHECK(vkCreateFramebuffer(a->device, &fbi, NULL, &a->fbs[i]), "framebuffer");
        CHECK(vkCreateSemaphore(a->device, &semi, NULL, &a->render_done[i]), "semaphore");
    }
    const VkCommandPoolCreateInfo pi = {.sType = VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO,
        .flags = VK_COMMAND_POOL_CREATE_RESET_COMMAND_BUFFER_BIT, .queueFamilyIndex = a->family};
    CHECK(vkCreateCommandPool(a->device, &pi, NULL, &a->pool), "command_pool");
    const VkCommandBufferAllocateInfo cai = {.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO, .commandPool = a->pool,
        .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY, .commandBufferCount = IN_FLIGHT};
    CHECK(vkAllocateCommandBuffers(a->device, &cai, a->cmds), "command_buffers");
    const VkFenceCreateInfo fci = {.sType = VK_STRUCTURE_TYPE_FENCE_CREATE_INFO, .flags = VK_FENCE_CREATE_SIGNALED_BIT};
    for (uint32_t i = 0; i < IN_FLIGHT; ++i) {
        CHECK(vkCreateSemaphore(a->device, &semi, NULL, &a->image_ready[i]), "semaphore");
        CHECK(vkCreateFence(a->device, &fci, NULL, &a->fences[i]), "fence");
    }
    return 1;
}

static void destroy_vulkan(App* a) {
    if (a->device) {
        if (vkDeviceWaitIdle(a->device) != VK_SUCCESS) return; /* retirement unproven: keep objects owned */
        for (uint32_t i = 0; i < IN_FLIGHT; ++i) {
            if (a->fences[i]) vkDestroyFence(a->device, a->fences[i], NULL);
            if (a->image_ready[i]) vkDestroySemaphore(a->device, a->image_ready[i], NULL);
        }
        if (a->pool) vkDestroyCommandPool(a->device, a->pool, NULL);
        for (uint32_t i = 0; i < MAX_IMAGES; ++i) {
            if (a->fbs[i]) vkDestroyFramebuffer(a->device, a->fbs[i], NULL);
            if (a->views[i]) vkDestroyImageView(a->device, a->views[i], NULL);
            if (a->render_done[i]) vkDestroySemaphore(a->device, a->render_done[i], NULL);
        }
        if (a->pipeline) vkDestroyPipeline(a->device, a->pipeline, NULL);
        if (a->pass) vkDestroyRenderPass(a->device, a->pass, NULL);
        if (a->swapchain) vkDestroySwapchainKHR(a->device, a->swapchain, NULL);
        if (a->layout) vkDestroyPipelineLayout(a->device, a->layout, NULL);
        if (a->frag) vkDestroyShaderModule(a->device, a->frag, NULL);
        if (a->vert) vkDestroyShaderModule(a->device, a->vert, NULL);
        vkDestroyDevice(a->device, NULL);
    }
    if (a->instance) {
        if (a->surface) vkDestroySurfaceKHR(a->instance, a->surface, NULL);
        vkDestroyInstance(a->instance, NULL);
    }
}

static int record(App* a, VkCommandBuffer cmd, uint32_t image, const Load* load, unsigned frame) {
    if (vkResetCommandBuffer(cmd, 0) != VK_SUCCESS) return 0;
    const VkCommandBufferBeginInfo bi = {.sType = VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO,
                                         .flags = VK_COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT};
    if (vkBeginCommandBuffer(cmd, &bi) != VK_SUCCESS) return 0;
    const VkClearValue clear = {.color = {.float32 = {0.07f, 0.10f, 0.16f, 1.0f}}};
    const VkRenderPassBeginInfo rb = {.sType = VK_STRUCTURE_TYPE_RENDER_PASS_BEGIN_INFO, .renderPass = a->pass,
        .framebuffer = a->fbs[image], .renderArea = {{0, 0}, a->extent}, .clearValueCount = 1, .pClearValues = &clear};
    vkCmdBeginRenderPass(cmd, &rb, VK_SUBPASS_CONTENTS_INLINE);
    vkCmdBindPipeline(cmd, VK_PIPELINE_BIND_POINT_GRAPHICS, a->pipeline);
    const VkViewport vp = {0.0f, 0.0f, (float)a->extent.width, (float)a->extent.height, 0.0f, 1.0f};
    const VkRect2D sc = {{0, 0}, a->extent};
    vkCmdSetViewport(cmd, 0, 1, &vp);
    vkCmdSetScissor(cmd, 0, 1, &sc);
    for (uint32_t pass = 0; pass < load->draws; ++pass) {
        /* phase = firstInstance / 251 in the vertex shader (same value the push constant carried). */
        vkCmdDraw(cmd, 3, 1, 0, (frame % 251) + pass * 17);
    }
    vkCmdEndRenderPass(cmd);
    return vkEndCommandBuffer(cmd) == VK_SUCCESS;
}

static int run_scene(const Settings* s, App* a) {
    const Load* load = &kLoads[s->level];
    const uint64_t limit = nxn_time_ns() + s->seconds * SECOND_NS;
    int suspended = 0;
    unsigned frames = 0, slot = 0;
    uint64_t elapsed[BATCH_FRAMES];
    memset(elapsed, 0, sizeof(elapsed));
    while (!nxn_should_quit() && nxn_time_ns() < limit) {
        nxn_event ev = NXN_STRUCT_INIT(nxn_event);
        while (nxn_event_poll(&ev) > 0) {
            if (ev.type == NXN_EVENT_SUSPEND) suspended = 1;
            if (ev.type == NXN_EVENT_RESUME) suspended = 0;
            ev.size = (uint32_t)sizeof(ev);
        }
        if (nxn_should_quit()) break;
        if (suspended) { nxn_sleep_ns(10000000); continue; }
        const uint64_t start = nxn_time_ns();
        VkResult wr = vkWaitForFences(a->device, 1, &a->fences[slot], VK_TRUE, WAIT_NS);
        if (wr == VK_TIMEOUT) continue;
        if (wr != VK_SUCCESS) { printf("GSTRESS: FAIL fence level=%u vk_result=%d\n", s->level, (int)wr); return 1; }
        uint32_t image = 0;
        VkResult ar = vkAcquireNextImageKHR(a->device, a->swapchain, WAIT_NS, a->image_ready[slot], VK_NULL_HANDLE, &image);
        if (ar == VK_TIMEOUT || ar == VK_NOT_READY) continue;
        if (ar != VK_SUCCESS && ar != VK_SUBOPTIMAL_KHR) {
            printf("GSTRESS: FAIL acquire level=%u vk_result=%d\n", s->level, (int)ar); return 1;
        }
        if (vkResetFences(a->device, 1, &a->fences[slot]) != VK_SUCCESS ||
            !record(a, a->cmds[slot], image, load, frames)) {
            printf("GSTRESS: FAIL record level=%u\n", s->level); return 1;
        }
        const VkPipelineStageFlags stage = VK_PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT_BIT;
        const VkSubmitInfo si = {.sType = VK_STRUCTURE_TYPE_SUBMIT_INFO, .waitSemaphoreCount = 1,
            .pWaitSemaphores = &a->image_ready[slot], .pWaitDstStageMask = &stage, .commandBufferCount = 1,
            .pCommandBuffers = &a->cmds[slot], .signalSemaphoreCount = 1, .pSignalSemaphores = &a->render_done[image]};
        VkResult sr = vkQueueSubmit(a->queue, 1, &si, a->fences[slot]);
        if (sr != VK_SUCCESS) { printf("GSTRESS: FAIL submit level=%u vk_result=%d\n", s->level, (int)sr); return 1; }
        const VkPresentInfoKHR pi = {.sType = VK_STRUCTURE_TYPE_PRESENT_INFO_KHR, .waitSemaphoreCount = 1,
            .pWaitSemaphores = &a->render_done[image], .swapchainCount = 1, .pSwapchains = &a->swapchain, .pImageIndices = &image};
        VkResult pr = vkQueuePresentKHR(a->queue, &pi);
        if (pr != VK_SUCCESS && pr != VK_SUBOPTIMAL_KHR) {
            printf("GSTRESS: FAIL present level=%u vk_result=%d\n", s->level, (int)pr); return 1;
        }
        slot = (slot + 1) % IN_FLIGHT;
        elapsed[frames % BATCH_FRAMES] = nxn_time_ns() - start;
        if (++frames == 1) {
            printf("GSTRESS: BEGIN renderer=vulkan level=%u surface=%ux%u texture=%u draws=%u taps=%d\n",
                   s->level, a->extent.width, a->extent.height, load->texture, load->draws, load->taps);
            fflush(stdout);
        }
        if (frames % BATCH_FRAMES == 0) {
            uint64_t sorted[BATCH_FRAMES];
            memcpy(sorted, elapsed, sizeof(sorted));
            qsort(sorted, BATCH_FRAMES, sizeof(sorted[0]), cmp_u64);
            printf("GSTRESS: WINDOW level=%u frames=300 total=%u p50_ms=%.3f p95_ms=%.3f\n",
                   s->level, frames, sorted[149] / 1e6, sorted[284] / 1e6);
            fflush(stdout);
        }
    }
    printf("GSTRESS: END level=%u frames=%u reason=%s\n", s->level, frames,
           nxn_time_ns() >= limit ? "duration" : "quit");
    fflush(stdout);
    return 0;
}

static int app_main(int argc, char** argv) {
    (void)argc; (void)argv;
    Settings s = {0, 45, 800, 450};
    if (!read_settings(&s)) { printf("GSTRESS: FAIL load.txt\n"); puts(nxn_tr("stress.failed")); return 1; }
    if (!nxn_vk_available() || !vkGetInstanceProcAddr(VK_NULL_HANDLE, "vkCreateInstance")) {
        printf("GSTRESS: FAIL vulkan_unavailable level=%u\n", s.level); puts(nxn_tr("stress.failed")); return 1;
    }
    App app;
    memset(&app, 0, sizeof(app));
    int result = 1;
    if (init_vulkan(&app, s.width, s.height, kLoads[s.level].taps)) result = run_scene(&s, &app);
    else printf("GSTRESS: FAIL setup level=%u\n", s.level);
    destroy_vulkan(&app);
    if (result != 0) puts(nxn_tr("stress.failed"));
    return result;
}

int main(int argc, char** argv) {
    return nxn_run(argc, argv, app_main, NULL);
}
