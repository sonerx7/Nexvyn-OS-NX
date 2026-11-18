# GRAPHICS

## Purpose
Covers native OpenGL 4.3 Core / OpenGL ES 3.2 display contexts, entry-point loading, resize handling, and the NexGFX PBR scene renderer (`ngfx_*`).

## Keys
| symbol/function | header or module | one-line meaning |
|---|---|---|
| `nxn_display_open` / `nxn_display_close` | `nxn_display.h` | Opens/closes the app's EGL surface and GL/GLES context (default GL 4.3 core) |
| `nxn_display_params` / `NXN_GFX_GL_CORE` / `GLES` | `nxn_display.h` | Configures GL 4.3 core or GLES 3.2, depth (24), stencil (8), and `NXN_DISPLAY_*` flags |
| `nxn_display_swap` | `nxn_display.h` | Presents frame, paces to OS display, and signals watchdog liveness |
| `nxn_display_size` | `nxn_display.h` | Queries current surface width and height |
| `nxn_display_resize` | `nxn_display.h` | Recreates EGL surface on `NXN_EVENT_RESIZE` while keeping GL context |
| `nxn_display_proc` | `nxn_display.h` | Resolves GL/GLES entry points (pass to `gladLoadGLLoader`) |
| `ngfx_device_create` / `destroy` | `nexgfx_native.h` | Creates/destroys NexGFX PBR renderer on current GL 4.3 core context (`NXN_CAP_NEXGFX`) |
| `ngfx_device_prepare` | `nexgfx_native.h` | Compiles one shader program per call (call once per frame behind a progress bar) |
| `ngfx_scene_load` / `ngfx_scene_step` | `nexgfx_native.h` | Async loads `.nxsc`/`.nxtx` on a worker and uploads within `budget_ns` per frame |
| `ngfx_render` / `ngfx_view` | `nexgfx_native.h` | Renders PBR scene + sky + shadows + ACES + optional FXAA into FBO or window |
| `ngfx_scene_info_get` / `ngfx_scene_free` | `nexgfx_native.h` | Reads scene bounds/camera/sun metadata and frees scene GPU resources |
| `ngfx_native_error` | `nexgfx_native.h` | Returns last `ngfx_*` failure string on the calling thread |

## Rules
- Resolve all GL functions through `nxn_display_proc`; do not link `libGLESv2` or `libEGL` directly in `.nxvmod` apps.
- Strict single-thread ownership: `nxn_display_open`, `swap`, `size`, `resize`, `close`, and all GL/`ngfx_*` calls must run on the display owner thread.
- Shared GL contexts, worker-thread GL, and other GPU APIs are unsupported for apps (a second `nxn_display_open` is refused).
- **Resize Busy rule:** if `nxn_display_resize` returns `NXN_ERR_BUSY` (zero-copy frames in flight), keep the old surface, retry on a later frame, and update `glViewport` only after `NXN_OK`. Never spin on `NXN_ERR_BUSY`.
- Target performance goals (not hardware guarantees): frame work P95 <= 16.667 ms (60 Hz), late presents <= 1%, GPU lock wait P95 <= 5 ms.

## Pitfalls
- Calling `glViewport` with the new dimensions before `nxn_display_resize` succeeds, or spinning in a loop when `NXN_ERR_BUSY` is returned.
- Using `NXN_ERR_*` constants to check `ngfx_*` return values (`NGFX_ERR_*` is a separate error enum).
- Calling `ngfx_render` before `ngfx_device_prepare` returns `1`.

## See also
- [INDEX](INDEX.md)
- [LIFECYCLE_WINDOW](LIFECYCLE_WINDOW.md)
- [UI_NXUI](UI_NXUI.md)
- [NATIVE_ABI](NATIVE_ABI.md)
