# Vulkan Model

A windowed native Vulkan example (`com.nexvyn.example.vkmodel`). It draws one model ten times in a 5 x 2 grid under a
slowly orbiting camera. The renderer uses Lambert lighting with a hemispheric ambient term, the material's base texture
(or its flat colour) and a depth buffer. A Dear ImGui overlay shows these numbers:

- triangles per copy, and triangles drawn (copies x triangles)
- draw calls: model draws, plus the overlay's own draws
- FPS and frame time, averaged over one second
- resolution, GPU name and driver

The app writes the same numbers to its log once per second, in this format (example values):

```text
VKMODEL: fps=59.9 frame_ms=16.69 tris_per_copy=3630 copies=10 tris=36300 draws=7 overlay_draws=1 res=960x540 frames=600 gpu="..."
```

Vulkan is on by default when the driver check at start passes (`docs/NATIVE_KIT.md`, "Vulkan in the native kit"). When `nxn_vk_available()` is false, the app
logs `VKMODEL: FAIL reason=vulkan_unavailable`. It then returns to Nexvyn OS, which shows the localized message
"Vulkan is not available on this system; this app needs it."

## Design

- **The model is baked when the package is built.** The console never parses FBX: parsing a large FBX needs several
  times the file size in RAM and seconds of CPU. `sdk/native/examples/vk_model/tools/vk_model_bake.c` (host C, `lib/ufbx` + `lib/stb`) flattens
  every mesh instance to world space and triangulates it. It groups triangles by base texture and welds identical
  vertices. It also decodes only the base textures the materials use, embedded or next to the FBX. Each texture becomes
  an RGBA8 mip chain capped at `--max-tex` (default 512). The result is `data/model.nxvmesh`
  (`src/vk_model_format.h`). Each vertex is 24 bytes: a position, an snorm8 normal and a texture coordinate. Indices
  are 32-bit.
- **Low memory, no GPU copies where the device allows it.** On the console GPU all memory is the same system memory.
  The app reads vertices and indices from the file straight into mapped device-local buffers. Textures, including
  the overlay font, use the first upload path that works:
  1. Host image copy (Vulkan 1.4 `vkCopyMemoryToImage`, optimal tiling, mips kept).
  2. Linear-tiled images that the CPU writes directly (mip 0 only, so distant surfaces can shimmer).
  3. A staging buffer with `vkCmdCopyBufferToImage`.

  The log line `VKMODEL: upload path=...` names the chosen path. The app streams one texture at a time through one
  reused heap block (1.4 MB at 512 x 512). `nxn_memory_budget_request` checks the file size first. In the emulator,
  GPU copy commands crash the host (`ErrorOutOfDeviceMemory`, the same compute and copy limit as vkQuake), and the
  host does not route host image copy, so the emulator uses linear textures.
- **One vertex and index buffer for all copies.** Each texture group is one `vkCmdDrawIndexed` with
  `instanceCount = 10`. The vertex shader places each instance in its grid cell from `gl_InstanceIndex`. Push constants
  carry the view-projection matrix, the grid spacing and the group colour. Model draw calls equal the group count.
- **Overlay.** It uses Dear ImGui with the Vulkan backend through `<nexvyn/nxn_imgui_vk.h>`, drawn in the same
  render pass. It follows the kit's design rules (`nxv-native check-design` is clean). The OS frame layer
  (`<nexvyn/nxn_os_ui.h>` with `NXN_OS_UI_NO_GL3`, `nxn_os_frame_begin_ex(..., NXN_OS_FRAME_NO_BACKEND)`) sets the
  UI scale, the style and the text-role fonts with the user's glyphs. Text uses `nxn_os_text`, and spacing uses
  `nxn_os_sp`. `nxn_imgui_input` handles input. The scene clears to `nxn_os_clear_color`. When the frame layer
  rebuilds the fonts, `nxn_os_set_font_uploader` uploads the new atlas through the app's texture path.
- **Kit rules.** The swapchain uses `VK_FORMAT_R8G8B8A8_UNORM` with sRGB nonlinear colour space and FIFO present
  mode. It has 2-3 images, an identity transform, opaque composite alpha and color-attachment usage only. On
  `VK_ERROR_OUT_OF_DATE_KHR` or `VK_SUBOPTIMAL_KHR`, the app waits for idle and recreates the swapchain with
  `oldSwapchain`. One `VkPipelineCache`, created empty so that Nexvyn OS seeds it from an earlier run, serves every
  pipeline and is destroyed on exit.

For whole scenes with block-compressed textures, streaming and culling, see `examples/scenes` and `tools/nxv_asset`.
This example keeps its own small baker, so that it stays self-contained.

## Build and package

The packaging script needs a host C compiler, `glslangValidator`, `spirv-val`, a sysroot with the `vulkan-headers`
recipe and the `backends` folder of Dear ImGui 1.91.5. It bakes the FBX you give it into a temporary copy of this
folder, then builds and packs the app. The model never enters the source tree:

```sh
NEXVYN_SYSROOT=<sysroot> NEXVYN_GLSLANG=<glslangValidator> NEXVYN_SPIRV_VAL=<spirv-val> \
NEXVYN_IMGUI_VULKAN_BACKENDS=<imgui-1.91.5>/backends NEXVYN_HOST_CC=<gcc> \
python sdk/native/examples/vk_model/tools/package.py MODEL.fbx -o build/vk_model/vk_model.nxvapp
```

No setting is needed: Vulkan is on by default. The emulator runs the app and logs the `VKMODEL:` lines.
The Vulkan window pixels may stay black there (the emulator's NVK compute copy limit); only a console shows the image.
