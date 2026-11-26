/* SDL3 GPU API demo for Nexvyn OS (Vulkan 1.3 driver).
 * Steps: check Vulkan -> SDL_Init -> SDL_CreateWindow -> SDL_CreateGPUDevice(SPIRV) ->
 * claim window -> upload RGBA8 texture -> render to off-screen texture -> blit to swapchain -> present.
 * Logs machine-readable "SDL3G key=value" lines and ends with "SDL3G END status=...". */
#include <SDL3/SDL.h>
#include <nexvyn/nexvyn_native.h>
#include <nexvyn/nxn_vk.h>

#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "sdl3_gpu_demo_shaders.h"

#define DEMO_TEX_W 64
#define DEMO_TEX_H 64
#define DEMO_OFFSCREEN_W 256
#define DEMO_OFFSCREEN_H 256
#define DEMO_FRAMES 5

static void sanitize_token(const char *src, char *dst, size_t dst_size)
{
    size_t j = 0;
    if (!src || !src[0]) {
        snprintf(dst, dst_size, "unknown");
        return;
    }
    for (size_t i = 0; src[i] && j + 1 < dst_size; i++) {
        unsigned char c = (unsigned char)src[i];
        if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') ||
            c == '_' || c == '-' || c == '.') {
            dst[j++] = (char)c;
        } else {
            dst[j++] = '_';
        }
    }
    dst[j] = '\0';
}

static void fill_checkerboard(uint8_t *pixels, uint32_t w, uint32_t h)
{
    for (uint32_t y = 0; y < h; y++) {
        for (uint32_t x = 0; x < w; x++) {
            uint32_t idx = (y * w + x) * 4u;
            int cell = ((x / 8u) + (y / 8u)) & 1;
            pixels[idx + 0] = cell ? 240u : 32u;
            pixels[idx + 1] = cell ? 180u : 96u;
            pixels[idx + 2] = cell ? 48u : 220u;
            pixels[idx + 3] = 255u;
        }
    }
}

int main(int argc, char **argv)
{
    (void)argc;
    (void)argv;

    SDL_Window *window = NULL;
    SDL_GPUDevice *device = NULL;
    SDL_GPUTexture *src_tex = NULL;
    SDL_GPUTexture *offscreen_tex = NULL;
    SDL_GPUTransferBuffer *transfer = NULL;
    SDL_GPUSampler *sampler = NULL;
    SDL_GPUGraphicsPipeline *pipeline = NULL;
    const char *fail_step = NULL;
    bool claimed = false;
    int presented = 0;
    int exit_code = 1;

    if (!nxn_vk_available()) {
        nxn_log(NXN_LOG_INFO, "SDL3G step=vk_available rc=0");
        nxn_log(NXN_LOG_INFO, "SDL3G END status=UNAVAILABLE");
        return 0;
    }
    nxn_log(NXN_LOG_INFO, "SDL3G step=vk_available rc=1");

    if (!SDL_Init(SDL_INIT_VIDEO)) {
        nxn_log(NXN_LOG_ERROR, "SDL3G step=sdl_init rc=-1 err=%s", SDL_GetError());
        nxn_log(NXN_LOG_INFO, "SDL3G END status=FAIL step=sdl_init");
        return 1;
    }
    nxn_log(NXN_LOG_INFO, "SDL3G step=sdl_init rc=0 video_driver=%s",
            SDL_GetCurrentVideoDriver() ? SDL_GetCurrentVideoDriver() : "unknown");

    const char *title = nxn_tr("title");
    window = SDL_CreateWindow(title, 960, 540, SDL_WINDOW_VULKAN | SDL_WINDOW_RESIZABLE);
    if (!window) {
        fail_step = "create_window";
        nxn_log(NXN_LOG_ERROR, "SDL3G step=create_window rc=-1 err=%s", SDL_GetError());
        goto cleanup;
    }
    nxn_window_set_title(title, NULL);
    {
        int w = 0, h = 0;
        SDL_GetWindowSize(window, &w, &h);
        nxn_log(NXN_LOG_INFO, "SDL3G step=create_window rc=0 w=%d h=%d", w, h);
    }

    device = SDL_CreateGPUDevice(SDL_GPU_SHADERFORMAT_SPIRV, false, "vulkan");
    if (!device) {
        fail_step = "create_device";
        nxn_log(NXN_LOG_ERROR, "SDL3G step=create_device rc=-1 err=%s", SDL_GetError());
        goto cleanup;
    }
    {
        const char *drv = SDL_GetGPUDeviceDriver(device);
        SDL_PropertiesID props = SDL_GetGPUDeviceProperties(device);
        const char *raw_name = props ? SDL_GetStringProperty(props, SDL_PROP_GPU_DEVICE_NAME_STRING, "unknown") : "unknown";
        char dev_tok[128];
        char drv_tok[64];
        sanitize_token(raw_name, dev_tok, sizeof(dev_tok));
        sanitize_token(drv, drv_tok, sizeof(drv_tok));
        nxn_log(NXN_LOG_INFO, "SDL3G step=create_device rc=0 driver=%s device=%s", drv_tok, dev_tok);
    }

    if (!SDL_ClaimWindowForGPUDevice(device, window)) {
        fail_step = "claim_window";
        nxn_log(NXN_LOG_ERROR, "SDL3G step=claim_window rc=-1 err=%s", SDL_GetError());
        goto cleanup;
    }
    claimed = true;
    SDL_GPUTextureFormat swap_fmt = SDL_GetGPUSwapchainTextureFormat(device, window);
    nxn_log(NXN_LOG_INFO, "SDL3G step=claim_window rc=0 swapchain_format=%d", (int)swap_fmt);

    /* Create and upload 64x64 RGBA8 source texture */
    {
        SDL_GPUTextureCreateInfo tci;
        SDL_zero(tci);
        tci.type = SDL_GPU_TEXTURETYPE_2D;
        tci.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
        tci.usage = SDL_GPU_TEXTUREUSAGE_SAMPLER;
        tci.width = DEMO_TEX_W;
        tci.height = DEMO_TEX_H;
        tci.layer_count_or_depth = 1;
        tci.num_levels = 1;
        src_tex = SDL_CreateGPUTexture(device, &tci);
        if (!src_tex) {
            fail_step = "create_src_texture";
            nxn_log(NXN_LOG_ERROR, "SDL3G step=create_src_texture rc=-1 err=%s", SDL_GetError());
            goto cleanup;
        }

        SDL_GPUTransferBufferCreateInfo tbci;
        SDL_zero(tbci);
        tbci.usage = SDL_GPU_TRANSFERBUFFERUSAGE_UPLOAD;
        tbci.size = DEMO_TEX_W * DEMO_TEX_H * 4u;
        transfer = SDL_CreateGPUTransferBuffer(device, &tbci);
        if (!transfer) {
            fail_step = "create_transfer";
            nxn_log(NXN_LOG_ERROR, "SDL3G step=create_transfer rc=-1 err=%s", SDL_GetError());
            goto cleanup;
        }

        uint8_t *mapped = (uint8_t *)SDL_MapGPUTransferBuffer(device, transfer, false);
        if (!mapped) {
            fail_step = "map_transfer";
            nxn_log(NXN_LOG_ERROR, "SDL3G step=map_transfer rc=-1 err=%s", SDL_GetError());
            goto cleanup;
        }
        fill_checkerboard(mapped, DEMO_TEX_W, DEMO_TEX_H);
        SDL_UnmapGPUTransferBuffer(device, transfer);

        SDL_GPUCommandBuffer *upload_cmd = SDL_AcquireGPUCommandBuffer(device);
        if (!upload_cmd) {
            fail_step = "upload_cmd";
            nxn_log(NXN_LOG_ERROR, "SDL3G step=upload_texture rc=-1 err=%s", SDL_GetError());
            goto cleanup;
        }
        SDL_GPUCopyPass *copy_pass = SDL_BeginGPUCopyPass(upload_cmd);
        SDL_GPUTextureTransferInfo src_info;
        SDL_zero(src_info);
        src_info.transfer_buffer = transfer;
        src_info.offset = 0;
        src_info.pixels_per_row = DEMO_TEX_W;
        src_info.rows_per_layer = DEMO_TEX_H;

        SDL_GPUTextureRegion dst_region;
        SDL_zero(dst_region);
        dst_region.texture = src_tex;
        dst_region.w = DEMO_TEX_W;
        dst_region.h = DEMO_TEX_H;
        dst_region.d = 1;

        SDL_UploadToGPUTexture(copy_pass, &src_info, &dst_region, false);
        SDL_EndGPUCopyPass(copy_pass);
        if (!SDL_SubmitGPUCommandBuffer(upload_cmd)) {
            fail_step = "upload_submit";
            nxn_log(NXN_LOG_ERROR, "SDL3G step=upload_texture rc=-1 err=%s", SDL_GetError());
            goto cleanup;
        }
        nxn_log(NXN_LOG_INFO, "SDL3G step=upload_texture rc=0 w=%u h=%u", DEMO_TEX_W, DEMO_TEX_H);
    }

    /* Create off-screen render target texture */
    {
        SDL_GPUTextureCreateInfo oci;
        SDL_zero(oci);
        oci.type = SDL_GPU_TEXTURETYPE_2D;
        oci.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;
        oci.usage = SDL_GPU_TEXTUREUSAGE_COLOR_TARGET | SDL_GPU_TEXTUREUSAGE_SAMPLER;
        oci.width = DEMO_OFFSCREEN_W;
        oci.height = DEMO_OFFSCREEN_H;
        oci.layer_count_or_depth = 1;
        oci.num_levels = 1;
        offscreen_tex = SDL_CreateGPUTexture(device, &oci);
        if (!offscreen_tex) {
            fail_step = "create_offscreen";
            nxn_log(NXN_LOG_ERROR, "SDL3G step=create_offscreen rc=-1 err=%s", SDL_GetError());
            goto cleanup;
        }
        nxn_log(NXN_LOG_INFO, "SDL3G step=create_offscreen rc=0 w=%u h=%u", DEMO_OFFSCREEN_W, DEMO_OFFSCREEN_H);
    }

    /* Create SPIR-V shaders, sampler, and graphics pipeline for the off-screen target */
    {
        SDL_GPUShaderCreateInfo vci;
        SDL_zero(vci);
        vci.code = kQuadVertSpv;
        vci.code_size = sizeof(kQuadVertSpv);
        vci.entrypoint = "main";
        vci.format = SDL_GPU_SHADERFORMAT_SPIRV;
        vci.stage = SDL_GPU_SHADERSTAGE_VERTEX;
        SDL_GPUShader *vert = SDL_CreateGPUShader(device, &vci);
        if (!vert) {
            fail_step = "create_vert_shader";
            nxn_log(NXN_LOG_ERROR, "SDL3G step=create_pipeline rc=-1 err=%s", SDL_GetError());
            goto cleanup;
        }

        SDL_GPUShaderCreateInfo fci;
        SDL_zero(fci);
        fci.code = kQuadFragSpv;
        fci.code_size = sizeof(kQuadFragSpv);
        fci.entrypoint = "main";
        fci.format = SDL_GPU_SHADERFORMAT_SPIRV;
        fci.stage = SDL_GPU_SHADERSTAGE_FRAGMENT;
        fci.num_samplers = 1;
        SDL_GPUShader *frag = SDL_CreateGPUShader(device, &fci);
        if (!frag) {
            SDL_ReleaseGPUShader(device, vert);
            fail_step = "create_frag_shader";
            nxn_log(NXN_LOG_ERROR, "SDL3G step=create_pipeline rc=-1 err=%s", SDL_GetError());
            goto cleanup;
        }

        SDL_GPUColorTargetDescription ctd;
        SDL_zero(ctd);
        ctd.format = SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM;

        SDL_GPUGraphicsPipelineCreateInfo pci;
        SDL_zero(pci);
        pci.vertex_shader = vert;
        pci.fragment_shader = frag;
        pci.primitive_type = SDL_GPU_PRIMITIVETYPE_TRIANGLELIST;
        pci.rasterizer_state.fill_mode = SDL_GPU_FILLMODE_FILL;
        pci.rasterizer_state.cull_mode = SDL_GPU_CULLMODE_NONE;
        pci.rasterizer_state.enable_depth_clip = true;
        pci.target_info.num_color_targets = 1;
        pci.target_info.color_target_descriptions = &ctd;

        pipeline = SDL_CreateGPUGraphicsPipeline(device, &pci);
        SDL_ReleaseGPUShader(device, vert);
        SDL_ReleaseGPUShader(device, frag);
        if (!pipeline) {
            fail_step = "create_pipeline";
            nxn_log(NXN_LOG_ERROR, "SDL3G step=create_pipeline rc=-1 err=%s", SDL_GetError());
            goto cleanup;
        }

        SDL_GPUSamplerCreateInfo sci;
        SDL_zero(sci);
        sci.min_filter = SDL_GPU_FILTER_NEAREST;
        sci.mag_filter = SDL_GPU_FILTER_NEAREST;
        sci.mipmap_mode = SDL_GPU_SAMPLERMIPMAPMODE_NEAREST;
        sci.address_mode_u = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
        sci.address_mode_v = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
        sci.address_mode_w = SDL_GPU_SAMPLERADDRESSMODE_CLAMP_TO_EDGE;
        sampler = SDL_CreateGPUSampler(device, &sci);
        if (!sampler) {
            fail_step = "create_sampler";
            nxn_log(NXN_LOG_ERROR, "SDL3G step=create_pipeline rc=-1 err=%s", SDL_GetError());
            goto cleanup;
        }
        nxn_log(NXN_LOG_INFO, "SDL3G step=create_pipeline rc=0");
    }

    /* Render to off-screen target, blit to swapchain, and present DEMO_FRAMES frames */
    for (int f = 0; f < DEMO_FRAMES && !nxn_should_quit(); f++) {
        SDL_Event ev;
        while (SDL_PollEvent(&ev)) {
            if (ev.type == SDL_EVENT_QUIT) {
                goto done_frames;
            }
        }

        SDL_GPUCommandBuffer *cmd = SDL_AcquireGPUCommandBuffer(device);
        if (!cmd) {
            fail_step = "acquire_cmd";
            nxn_log(NXN_LOG_ERROR, "SDL3G step=present frame=%d rc=-1 err=%s", f, SDL_GetError());
            goto cleanup;
        }

        /* Pass 1: draw uploaded texture into off-screen texture */
        SDL_GPUColorTargetInfo color_target;
        SDL_zero(color_target);
        color_target.texture = offscreen_tex;
        color_target.clear_color.r = 0.08f;
        color_target.clear_color.g = 0.12f;
        color_target.clear_color.b = 0.18f;
        color_target.clear_color.a = 1.0f;
        color_target.load_op = SDL_GPU_LOADOP_CLEAR;
        color_target.store_op = SDL_GPU_STOREOP_STORE;

        SDL_GPURenderPass *pass = SDL_BeginGPURenderPass(cmd, &color_target, 1, NULL);
        SDL_BindGPUGraphicsPipeline(pass, pipeline);
        SDL_GPUTextureSamplerBinding tex_binding;
        tex_binding.texture = src_tex;
        tex_binding.sampler = sampler;
        SDL_BindGPUFragmentSamplers(pass, 0, &tex_binding, 1);
        SDL_DrawGPUPrimitives(pass, 6, 1, 0, 0);
        SDL_EndGPURenderPass(pass);

        /* Pass 2: acquire swapchain and blit off-screen render target onto it */
        SDL_GPUTexture *swap_tex = NULL;
        Uint32 sw = 0, sh = 0;
        if (!SDL_WaitAndAcquireGPUSwapchainTexture(cmd, window, &swap_tex, &sw, &sh)) {
            SDL_CancelGPUCommandBuffer(cmd);
            fail_step = "acquire_swapchain";
            nxn_log(NXN_LOG_ERROR, "SDL3G step=present frame=%d rc=-1 err=%s", f, SDL_GetError());
            goto cleanup;
        }

        if (swap_tex && sw > 0 && sh > 0) {
            SDL_GPUBlitInfo blit;
            SDL_zero(blit);
            blit.source.texture = offscreen_tex;
            blit.source.w = DEMO_OFFSCREEN_W;
            blit.source.h = DEMO_OFFSCREEN_H;
            blit.destination.texture = swap_tex;
            blit.destination.w = sw;
            blit.destination.h = sh;
            blit.load_op = SDL_GPU_LOADOP_DONT_CARE;
            blit.filter = SDL_GPU_FILTER_LINEAR;
            SDL_BlitGPUTexture(cmd, &blit);
        }

        if (!SDL_SubmitGPUCommandBuffer(cmd)) {
            fail_step = "submit_frame";
            nxn_log(NXN_LOG_ERROR, "SDL3G step=present frame=%d rc=-1 err=%s", f, SDL_GetError());
            goto cleanup;
        }
        if (swap_tex && sw > 0 && sh > 0) {
            presented++;
            nxn_log(NXN_LOG_INFO, "SDL3G step=present frame=%d rc=0 swap_w=%u swap_h=%u", f, sw, sh);
        } else {
            nxn_log(NXN_LOG_INFO, "SDL3G step=present frame=%d rc=0 skipped=no_swapchain_image", f);
        }
    }

done_frames:
    if (!SDL_WaitForGPUIdle(device)) {
        fail_step = "wait_idle";
        nxn_log(NXN_LOG_ERROR, "SDL3G step=wait_idle rc=-1 err=%s", SDL_GetError());
        goto cleanup;
    }
    nxn_log(NXN_LOG_INFO, "SDL3G step=wait_idle rc=0");
    exit_code = (presented > 0) ? 0 : 1;
    if (presented == 0) {
        fail_step = "no_frames";
    }

cleanup:
    if (device) {
        if (exit_code != 0) SDL_WaitForGPUIdle(device);
        if (pipeline) SDL_ReleaseGPUGraphicsPipeline(device, pipeline);
        if (sampler) SDL_ReleaseGPUSampler(device, sampler);
        if (offscreen_tex) SDL_ReleaseGPUTexture(device, offscreen_tex);
        if (src_tex) SDL_ReleaseGPUTexture(device, src_tex);
        if (transfer) SDL_ReleaseGPUTransferBuffer(device, transfer);
        if (claimed) SDL_ReleaseWindowFromGPUDevice(device, window);
        SDL_DestroyGPUDevice(device);
    }
    if (window) {
        SDL_DestroyWindow(window);
    }
    SDL_Quit();

    if (exit_code == 0) {
        nxn_log(NXN_LOG_INFO, "SDL3G END status=PASS frames=%d", presented);
    } else {
        nxn_log(NXN_LOG_INFO, "SDL3G END status=FAIL step=%s frames=%d", fail_step ? fail_step : "unknown", presented);
    }
    return exit_code;
}
