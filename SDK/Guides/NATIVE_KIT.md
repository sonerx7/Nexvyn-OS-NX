# Nexvyn Native Kit

Graphics overview for app developers: section 10 of `SDK/AI_GUIDE.md` (GL/GLES, NexGFX, Vulkan preview).

The kit builds C and C++ apps that run inside Nexvyn OS: the app is a `.nxvmod` that Nexvyn OS loads into its own
process, in a window or full screen (`app.json` `"mode": "window"` or `"fullscreen"`; section "Apps in Nexvyn OS"). Use
it for games, emulators, engines and ports. Scripted apps (Lua, JavaScript, Python, C via TinyCC) do not need it.

Status: the toolchain, sysroot scripts, templates and CLI work today. The Nexvyn ABI (`#include <nexvyn/nexvyn_native.h>`,
`-lnexvyn_native`) is linked by default. SDL2 runs inside Nexvyn OS windows (and full screen) through the kit's own
SDL2 driver: section "SDL2 in a window". Without SDL, use the `nxn_*` API directly (`examples/hello_gl`,
`examples/showcase`).

**ABI v1 is frozen (2026-11-09).** The `nxn_*` functions, the `nxn_nxui_*` Retained UI Engine (`#include <nexvyn/nxn_nxui.h>`), the `ngfx_*` API, every struct layout, constant, capability bit,
error code, host import name and the module identity are recorded in `toolchain/nxn_abi_v1.json`. The rule from now on is
add-only: nothing in that file is ever removed or changed; new functions, constants and struct fields (appended at the end,
never into padding) may come. An app built with any earlier kit keeps loading; a module built with the 1.0 kit is part of
every test run. When your app calls a function added in a later Native SDK version, raise `"minNative"` in `app.json` to
that version: an older Nexvyn OS refuses a module that imports an `nxn_*` name it does not have, with a clear message. Use
`NXN_STRUCT_INIT(type)` for every struct you pass, test capability bits (`NXN_CAP_*`, `uint64_t` masks) before optional
calls, and treat any negative result you do not know as a plain failure.

## Capability queries and migration

Existing apps can keep using `nxn_caps_get` and its feature mask. New code can use
`nxn_capability_query` from `<nexvyn/nxn_caps.h>` for JIT, VM guards and fault
handlers, module TLS, and the GL/GLES/NexGFX paths. This header-only helper uses
the existing import, so adopting it requires no `minNative` bump. It returns
`NXN_OK` for an advertised path, `NXN_ERR_UNSUPPORTED` for an absent path,
`NXN_ERR_INVALID` for an unknown selector, `NXN_ERR_NOT_READY` for an unavailable
snapshot, or `NXN_ERR_SYSTEM` for other snapshot failures.

Flags and GL version ceilings describe the current runtime's advertised paths.
Check each operation's result, the actual GL context and required entry points.
Keep an interpreter for JIT failures, checked memory accesses when guards or
fault handlers are unavailable, and a serial path if worker start fails.
TLS availability does not guarantee worker admission or change synchronization
requirements. Use an available GL profile or a non-GL path if context creation
fails. Keep display and GL operations on the display owner thread.

## Install

### Project creators

Start a native project with `python tools/nxv_native new <name> --template app|game|port|...` (below). The public
`SDK/Tools/nxv/nxv.py create` and `new` commands create script projects; see `SDK/AI_GUIDE.md` section 4.

1. Install devkitPro with the target packages. The tested versions are
   in `tools/toolchain.json`; `python tools/nxv_native doctor` compares them.
2. Python 3 (no other packages). CMake and Ninja come with devkitPro's shell.
3. Windows: the CLI runs the build inside devkitPro's msys2 shell by itself (`DKP_BASH` overrides its path). Linux and
   macOS: run inside an environment where `DEVKITPRO` is set.

## New, build, package, run

```
python tools/nxv_native new mygame --template game      # app | game | port | sdl2 | gl | emu-skeleton | decomp-skeleton | shared-lib
python tools/nxv_native build mygame                    # -> mygame/build/mygame.nxvmod (checked)
python tools/nxv_native lib mylib                       # a library-only project -> mylib/build/<name>.nxvlib
python tools/nxv_native package mygame                  # -> mygame/build/mygame.nxvapp
python tools/nxv_native run mygame --sd <SD card root>  # copies the bundle to <sd>/NexvynOS/Applications
```

- `build` options: `--abi` (kept for older scripts; the ABI is linked anyway), `--debug`, `--clean`, `--sysroot DIR` (extra libraries, below).
- `package` writes an `app.json` with `"runtime": "native"`, `"mode": "window"` (your `"fullscreen"` is kept),
  `"main": "<name>.nxvmod"`, `"minNative": "1.0"` and `"minSdk": "1.10"`, then packs the bundle with
  `tools/nxvapp_pack.py` (add `--sign key.pem` to sign it). Edit the project's `app.json` first: id, name, author,
  category, permissions. `minSdk` 1.10 is the script SDK that brought Native 1.0: older Nexvyn OS builds show the package
  as "needs a newer Nexvyn OS" instead of reading it as a script, so the packer refuses a native package without it.
- `python tools/nxv.py pack --delta old.nxvapp new.nxvapp` (source checkout only) makes a delta package (only the files that changed; the new
  package packed with `--stamp`) for the App Market's optional delta updates (`NXVAPP_FORMAT.md` 5c).
- `run` only copies files. It never starts an emulator or Nexvyn; you do that. Default SD root:
  `<emulator-profile>/sdcard`.
- Project layout: `CMakeLists.txt`, `src/`, `app.json`, `icon.png`. Optional `data/` and `romfs/` folders are packed
  next to the module.

Without the CLI: `cmake -S . -B build -DCMAKE_TOOLCHAIN_FILE=<kit>/toolchain/nexvyn-switch.cmake -DNEXVYN_KIT=<kit>`
inside the devkitPro shell. Meson users take `toolchain/nexvyn-switch.meson.ini` (it builds the ELF; make the `.nro`
with `elf2nro` and `nacptool`).

## Apps in Nexvyn OS (.nxvmod)

A native app runs inside Nexvyn OS, next to the other apps; Nexvyn OS keeps running. `"mode": "window"` opens a normal
window, `"mode": "fullscreen"` opens it covering the whole screen (Nexvyn OS's own fullscreen: menu bar and Dock hidden; the bar slides over the content only while the pointer rests at the top edge, and it stays hidden after entering full screen with the pointer up there until the pointer has left and come back, so the app needs no safe area).
It is one build: the user switches between the two while the app runs (Ctrl+Alt+F, the window menu, or the exit button
at the top of a full-screen window) and the app gets `NXN_EVENT_RESIZE`. `nxn_caps_get()` sets `NXN_CAP_WINDOWED` in both.
`"windowed"` is the older spelling of `"window"` and keeps working.

```
python tools/nxv_native build mygame                 # -> mygame/build/mygame.nxvmod (checked)
python tools/nxv_native package mygame               # app.json "mode": "window", "main": "mygame.nxvmod"
python tools/nxv_native check-win file.nxvmod        # identity, -fPIC, every import offered by Nexvyn OS
```

CMake: `-DNEXVYN_WINDOWED=ON` (what the CLI passes) builds every `nexvyn_add_nro()` target as a windowed module
from the same sources, or call `nexvyn_add_windowed(mygame SOURCES src/main.c)` yourself. Makefile projects: see
`examples/hello_gl` (`make windowed`, `make package-windowed`): `-fPIC` objects, then
`-shared -nostartfiles -nostdlib -Wl,-Bsymbolic -Wl,-z,now -Wl,-z,text -Wl,--hash-style=sysv
-Wl,--undefined=nxnwin_identity ... -lnexvyn_window -lgcc` (`make -C sdk/native/lib` builds `libnexvyn_window.a`).

```json
{ "id": "com.you.game", "name": "Game", "version": "1.0.0", "runtime": "native", "mode": "window",
  "main": "game.nxvmod", "window": {"width": 960, "height": 540, "resizable": true},
  "minNative": "1.0", "minSdk": "1.10", "targetSdk": "1.10" }
```

What changes for the app:

| Area | In a window |
|---|---|
| Imports | only Nexvyn OS's host import set: `nxn_*`, the C library (newlib libc / libm, POSIX and pthreads of libsysbase) and a small libnx subset (threads, mutexes, sleep). Anything else (SDL, EGL, libnx services) is refused at start with "missing symbol". C++ (libstdc++, exceptions, RTTI) is linked into the module; `thread_local` is not supported. |
| GL | load GL through `nxn_display_proc` (glad: `gladLoadGLLoader((GLADloadproc)nxn_display_proc)`; `eglGetProcAddress` answers the same). Framebuffer 0 is the window's frame. Do not link `libGLESv2` / `libEGL` directly. |
| Display | `nxn_display_open(NULL, ...)` = the window's content size; `NXN_EVENT_RESIZE` when the window changes, follow it with `nxn_display_resize`. `nxn_display_swap` paces to Nexvyn OS's frames (a minimized window slows the app down). |
| Input | only while the window has focus (`NXN_EVENT_FOCUS`); touch in surface pixels. HOME, L + R (hold) and + with - stay with Nexvyn OS. |
| Closing | the close button sends `NXN_EVENT_QUIT` and makes `nxn_should_quit()` true; return from your entry within 5 seconds or the app is stopped. |
| Process calls | `exit` / `abort` / a failed `assert` end only the app; `atexit` handlers run when the app ends; `chdir` is refused. |
| POSIX and sockets | link the compatibility layer (`nexvyn_use_compat()`, `NATIVE_COMPAT.md` "In a window"): pipes, `poll`, `mmap`, signals, an own environment and working directory, all released when the app ends. BSD sockets need `"network"` in `app.json` `"permissions"`; without it every call fails with `EACCES`. |
| Shared libraries | `nxn_lib_open` / `dlopen` load the package's `.nxvlib` files with setting `native.windowedLibs` (`NXN_CAP_SHARED_LIBS`; off: `NXN_ERR_UNSUPPORTED`). `thread_local` (`native.windowedTls`, `NXN_CAP_TLS`) and C++ exceptions (`native.windowedEh`, `NXN_CAP_CXX_EXCEPTIONS`) work in the module and its libraries when those settings are on (default on for apps with `"minNative": "1.1"` or later, off for 1.0 apps; a value set explicitly holds for every app; verified in the emulator only, not yet on a console); the kit builds every object with `-mtls-dialect=trad -ftls-model=global-dynamic` and links `crtend.o` last (Makefile projects do the same). |
| JIT and fastmem | `nxn_jit_*` (code memory, rw + rx views; setting `native.windowedJit`, `NXN_CAP_JIT`), `nxn_fault_handler_set` (data aborts to the app first; `native.windowedFaultHandler`, `NXN_CAP_FAULT_HANDLER`), `nxn_mem_guard` (guard pages in the app's heap; `native.windowedGuardPages`, `NXN_CAP_GUARD_PAGES`). All stay off by default until a console has verified them (`NXN_ERR_UNSUPPORTED`); keep an interpreter / slow path. x17 is not restored after a handled fault. |
| 3D collision | `nxn_phys_*` (`nxn_phys.h`, `NXN_CAP_PHYS`, setting `native.phys`, on by default): worlds of meshes and boxes, raycast / sweep / overlap, capsule character controllers, triggers; the core of the script SDK's `phys.*` (SDK 1.15). Inside Nexvyn OS only: a stand-alone `.nro` gets `NXN_ERR_UNSUPPORTED`. |
| 3D navigation | `nxn_nav_*` (`nxn_nav.h`, `NXN_CAP_NAV`, setting `native.nav`, on by default): a walkable grid baked from an `nxn_phys` world on a worker thread, A* paths, blockers and cost areas, walking agents with re-planning; the core of the script SDK `nav.*` (SDK 1.15). Inside Nexvyn OS only: a stand-alone `.nro` gets `NXN_ERR_UNSUPPORTED` |
| Memory | the app's `malloc` / `free` / `realloc` / `memalign` / `strdup` come from the app's own heap, not Nexvyn OS's: when the app ends clean, the whole heap goes back in one step, so a leak never outlives the app. There is no fixed limit: the heap grows while the system has memory, and `malloc` returns `NULL` (`errno` = `ENOMEM`) when only the reserve Nexvyn OS needs to keep running is left (the `nxn_*` calls then answer `NXN_ERR_NO_MEMORY`). Optional `"memory"` in `app.json` (MB, 1 to 16384) is the heap the app wants: if that much is not free at the start, Nexvyn OS says so ("needs X MB, Y MB are free; close some open apps") and does not open the app; if it is, the memory is set aside for the app. Memory the C library allocates itself (`fopen`, `asprintf` ...) is not part of the app's heap. |
| Crashes | a fault in any thread of the app closes its window ("<app> stopped"), writes the crash line to its log and a report to `System/Logs/Crashes`; Nexvyn OS keeps running. The app still shares Nexvyn OS's process: a wild write can damage it, and there is no memory isolation (). |

Settings `native.windowed` (default on) turns windowed native apps off; `native.enabled` turns both modes off;
`native.windowedArena` (not set: an app whose `app.json` has `"minNative"` 1.1 or later gets its own heap, an older one (1.0) keeps Nexvyn OS's malloc as before; `true` / `false` holds for every app); `native.memoryReserveMB` (default 64) is
the memory the apps' heaps leave free for Nexvyn OS.

## Examples

- `examples/hello_gl`: the smallest app (GL, input, tone, files, crash tests).
- `examples/showcase`: every Native SDK feature with live self-tests and a `showcase_report.txt` (windowed, Dear ImGui). `python sdk/native/examples/showcase/package.py`.
- `examples/scenes`: windowed 3D scene viewer (worker-thread streaming, PBR, shadow map, culling) for baked FBX scenes you provide. `python sdk/native/examples/scenes/package.py`.

## Assets: `nxv-asset`

`python tools/nxv_asset bake IN.fbx|IN.glb|IN.gltf -o OUT --name NAME` turns a 3D file into the two files the runtime loads fast:
`NAME.nxsc` (materials, chunks of 16 m cut by material, vertices with tangents, indices, camera and sun if the file has them)
and `NAME.nxtx` (every texture resized to a power of two, with mips, block-compressed: BC1 base colour, BC3 with alpha, BC5
normals; the target GPU decodes them natively). `python tools/nxv_asset check FILE.nxsc|FILE.nxtx...` verifies baked files.
Needs Python 3 with numpy, Pillow and etcpak; FBX also needs a host C compiler (gcc, clang or MSVC), GLB / glTF do not. The
tool never crashes on a damaged file: it prints one `nxv-asset: error:` line, exits with 1 and leaves no half-written output
(it is tested with truncated, bit-flipped and garbage files; the `nxv_asset` tool belongs to the Nexvyn OS source checkout, not to this kit). The BC texture path itself is verified on a console later (emulator evidence covers loading).

## Shader validation

The Native SDK CLI can validate a GLSL or ESSL shader with glslang. It can also compile
GLSL to Vulkan 1.3 SPIR-V and validate it with SPIRV-Tools. Install the host tools and put
them on PATH or pass `--glslang` and `--spirv-val` with the executable paths.

```sh
python tools/nxv_native shader shaders/triangle.vert --target gl
python tools/nxv_native shader shaders/triangle.vert --target vulkan -o build/triangle.vert.spv
```

Create the output directory first. Use `--stage` when the filename does not identify the
shader stage. The Vulkan command replaces the output only after validation succeeds.

### Experimental Clang profile

The `clang-build` command builds an explicit list of C or C++ sources into a windowed
module with Clang 20.1.8 and devkitA64's PIC libstdc++. It supports C++17, 20 and 23.
Pass the LLVM root containing `bin/`. An optional `--sysroot` adds the assembled native
sysroot's windowed headers. The SDK checks the resulting ELF before replacing
the output. The existing loader rejects the TLSDESC relocations Clang emits for
`thread_local`, so use the default GCC profile for modules that need that feature.

```sh
python tools/nxv_native clang-build hello src/main.cpp --llvm /path/to/llvm --std 20
```

### Memory budget

Check `NXN_CAP_MEMORY_BUDGET` before calling the hosted memory budget API. Initialize an
`nxn_memory_budget` with `NXN_STRUCT_INIT` and call `nxn_memory_budget_get` to read the cached
free heap, shell reserve and estimated bytes available above that reserve.
`nxn_memory_budget_request(bytes)` checks whether a desired working set fits the current
estimate. It creates no reservation. Handle allocation failure independently.
On an older host, use weak imports and check that the functions are present. Standalone
builds return `NXN_ERR_UNSUPPORTED`.

Signatures (`<nexvyn/nxn_sys.h>`): `nxn_result nxn_memory_budget_get(nxn_memory_budget* out)` and
`nxn_result nxn_memory_budget_request(uint64_t working_set_bytes)`. The struct has `free_heap_bytes`,
`shell_reserve_bytes` and `available_bytes` (free heap minus the shell reserve, never below zero).
`nxn_memory_budget_get` answers `NXN_ERR_NOT_READY` while no sample exists; `nxn_memory_budget_request`
answers `NXN_ERR_NO_MEMORY` when the request exceeds the estimate. `NXN_OK` is not a guarantee: other apps
can take the memory before you allocate.

```c
#include <nexvyn/nxn_sys.h>

nxn_memory_budget mb = NXN_STRUCT_INIT(nxn_memory_budget);
if (nxn_memory_budget_get(&mb) == NXN_OK)
    nxn_log(NXN_LOG_INFO, "available %llu MiB", (unsigned long long)(mb.available_bytes >> 20));

uint64_t want = 192ull << 20;                  // texture cache + level data
if (nxn_memory_budget_request(want) == NXN_ERR_NO_MEMORY)
    want = 96ull << 20;                        // choose the smaller quality tier
```

## NexGFX in a native app (`nexgfx_native.h`)

Native apps draw baked 3D scenes (`nxv-asset`, above) with Nexvyn's PBR renderer through a small versioned C API, `ngfx_*`:
`ngfx_device_create` (in the app's own GL context), `ngfx_device_prepare` (builds the shader programs, one per call, behind your
progress bar), `ngfx_scene_load` / `ngfx_scene_step` (a worker thread reads and checks the files, `step` uploads a little per frame:
no stall), `ngfx_scene_info_get`, `ngfx_render` (sky, metallic-roughness PBR with normal / emissive maps, one sun with a fitted PCF
shadow map, hemisphere ambient, fog, alpha test and blend, ACES tone mapping, optional FXAA, render scale; into the window or any
FBO), `ngfx_scene_free`, `ngfx_device_destroy`. Handles are opaque, every struct starts with `size`, functions are only added.
- **Where it lives.** Add `sdk/native/nexgfx/nexgfx_native.cpp` to the SOURCES and put `sdk/native/nexgfx` and glad on the
  include path (see `examples/scenes/CMakeLists.txt`). That file is a thin shell plus a copy of the renderer: `ngfx_device_create`
  first asks Nexvyn OS for its renderer (`nxn_ngfx_backend`, a versioned table, `nexgfx_backend.h`) and uses the copy in your app
  when the system has none, has it turned off (`native.ngfxHost`) or answers another generation. You call the same `ngfx_*`
  functions either way; your log says which one draws (`ngfx backend: host gen 1 (gl)` or `ngfx backend: static`). Both draw
  into your own GL context (`nxn_display_open`) through your entry points (`nxn_display_proc`), so the GPU lock that keeps the
  shared command stream safe applies as for any app GL, and Nexvyn OS's own NexGFX (bound to the desktop's context) is never
  touched. When Nexvyn OS gets a faster graphics backend, apps built with this shell get it without being rebuilt; apps that
  call GL directly stay on Mesa GL. If you pass your own GL loader (`ngfx_device_desc.get_proc`), the copy in your app is used.
- **Feature bit.** `NXN_CAP_NEXGFX` (bit 23): the window's GL context offers what the device needs (OpenGL 4.3 core). Without it
  `ngfx_device_create` fails with a plain message.
- **Damaged files.** The loader checks every count, offset and index of a `.nxsc` / `.nxtx` before it copies or uploads anything:
  a damaged file ends as `NGFX_ERR_FORMAT` in `ngfx_scene_step`, never as a crash or a bad GPU read.
- **Games are not templates.** NexGFX draws what you give it; its sky, light and tone are defaults, not an art direction. No menu or
  HUD comes with it: build those from your own fonts, layouts and shaders.
- **Proof.** `examples/scenes` draws its scenes through `ngfx_*` (the only GL it keeps is its Dear ImGui overlay); the showcase row
  "NexGFX native" draws a triangle and checks the pixels. Not in the script SDK yet (`g3d.*` stays the script face): the native C
  API has no Lua / JavaScript / Python twin, tracked as a parity debt.

## OS sound mixer and button mapping (`nxn_audio.h`, `nxn_input.h`)

Two thin calls onto things Nexvyn OS already has, for windowed apps (without the cap they return `NXN_ERR_UNSUPPORTED`):
- **`nxn_sfx_play` / `nxn_tone` / `nxn_sfx_stop_all` (`NXN_CAP_MIXER`).** Short effects and synthesized tones on the OS mixer: no stream
  of your own, the user's volume applies, and the sounds stop when the window closes. `nxn_sfx_play` takes a system sound name
  ("click", "notify") or a file path (wav, ogg, mp3). The calls only queue the sound for the OS main thread, so they never wait for
  the mixer or for a file; a sound that cannot be played is logged, not reported. Music, mixing your own PCM and 3D sound stay with
  `nxn_audio` (your stream) or your own mixer.
- **`nxn_input_action_buttons` (`NXN_CAP_INPUT_ACTIONS`).** The `NXN_BTN_*` mask of the physical buttons the user mapped to a
  function in Settings > Controllers ("select", "back", "context", ...; names in `nxn_input.h`). An app that wants "confirm" and
  "cancel" on the user's own buttons tests the mask against `nxn_input_state`. It is a per-window snapshot the OS main thread
  refreshes when the mapping changes, so it is cheap and safe from any app thread. It is not a rebinding system for your game: a game
  keeps its own action map (and can start from this one).

## Vulkan in the native kit

Native Vulkan is **opt-in** and verified on the console with the `vk_canary` example and the GPU load test
(`gpu_stress`). It is not a default path: never depend on it without a GL fallback. A game port that uses Vulkan
(vkQuake, for example) is not confirmed on the console yet.

**Requesting it.** Two things must be true: the Nexvyn OS build has Vulkan compiled in (every release build since 1.4.0 does), and the numeric setting
`native.vulkan` is `1` (read when Nexvyn OS starts, so restart after changing it). The system then runs a driver
check; only when it succeeds does it advertise `NXN_CAP_VULKAN` (and `NXN_GFX_API_VULKAN` in the caps snapshot).
`"vulkan": true` in `app.json` only declares that the module is Vulkan aware (the packer runs its import check); it
does not switch Vulkan on. In the app:

```c
#include <nexvyn/nxn_vk.h>

if (nxn_vk_available()) {           // NXN_CAP_VULKAN + NXN_GFX_API_VULKAN + weak nxn_vk_proc resolver
    nxn_caps caps = NXN_STRUCT_INIT(nxn_caps);
    uint16_t maj = 0, min = 0;
    nxn_caps_get(&caps);
    nxn_caps_gfx_version(&caps, NXN_GFX_API_VULKAN, &maj, &min);   // advertised maximum; check it before use
    start_vulkan_renderer();
} else {
    start_gl_renderer();            // always keep this path
}
```

**Fallback.** When Vulkan is absent, `nxn_vk_available()` returns 0 and the weak `nxn_vk_proc` is `NULL`. An SDL2
window created with `SDL_WINDOW_VULKAN` fails and `SDL_GetError()` says `Vulkan is not available on this system`.
Decide between Vulkan and GL before you create a window (one SDL window per app).

**Swapchain and usage rules.** Window surfaces are strict; a swapchain that breaks a rule fails at creation:
- Format `VK_FORMAT_R8G8B8A8_UNORM` with `VK_COLOR_SPACE_SRGB_NONLINEAR_KHR`.
- Present mode `VK_PRESENT_MODE_FIFO_KHR` only (vsync paced).
- 2 or 3 images (`minImageCount` 2..3), one array layer, identity pre-transform, opaque composite alpha, no `pNext`, no flags.
- Image usage may combine only `VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT`, `VK_IMAGE_USAGE_TRANSFER_SRC_BIT` and
  `VK_IMAGE_USAGE_TRANSFER_DST_BIT`. Any other flag (storage, sampled, input attachment ...) is refused: render to your own
  image and blit it, or draw into the swapchain image as a color attachment.
- Read the surface capabilities for the extent; they report the window's current content size.

**Window resize.** Vulkan windows follow the content size. After a resize (or when the window is suspended and comes back)
the old swapchain reports `VK_ERROR_OUT_OF_DATE_KHR` (acquire or present). Wait for the device to be idle, read the surface
capabilities again, and create a new swapchain with the old one in `oldSwapchain`. Destroy the swapchain and the surface
before you destroy the SDL window.

**Pipeline cache between launches.** Nexvyn OS keeps a disk copy of each app's `VkPipelineCache` in the app's data
folder and seeds a new cache from it, so shaders compiled in an earlier run are not compiled again. This only happens when
you create the cache with no initial data (`initialDataSize` 0); if you pass your own blob, yours is used and nothing is
seeded. The copy is written when the cache is destroyed or the app exits, only if something new was compiled, and is
limited to 8 MiB; a blob with a different driver header is ignored. Create one cache early, use it for every pipeline and
destroy it on exit. Do not rely on the cache for correctness.

The SDK builds optional link-time `vk*` shims into `libnexvyn_window.a` with
`NEXVYN_VK_SHIMS=1` and the `vulkan-headers` sysroot recipe. Try the `vulkan`
template, the `hello_vk` instance probe, or the windowed and fullscreen
`vk_canary` example. The `vkquake` port is a separate `.nxvapp` package with a
host build and package result. Its Vulkan gameplay requires an enabled host and is not yet confirmed on the console.

Windowed SDL2 uses the host lookup and accepts a null library path. Create an
`SDL_WINDOW_VULKAN` window, query its required instance extension
(`VK_KHR_surface`), and use `SDL_Vulkan_CreateSurface`. The adapter supports
one SDL window per app. Destroy the swapchain and surface before destroying
the SDL window. When support is missing, library load reports
`Vulkan is not available on this system` through `SDL_GetError()`.

Build the surface probe separately from the default SDL2 checks. It uses
function pointers from SDL and requires only the optional Vulkan headers.

```sh
python sdk/native/sysroot/build.py vulkan-headers sdl2-nexvyn
NEXVYN_SDL2_CHECK_VULKAN=1 NEXVYN_VK_SHIMS=0 python tools/nxv_native build sdk/native/examples/sdl2_check
```

The probe logs `N5SDL:` lines and reports success after creating and destroying
a surface across two consecutive SDL windows, or after checking the expected
unavailable error on a host without Vulkan.

The Dear ImGui Vulkan backend is opt-in for compile checks. Set
`NEXVYN_IMGUI_VULKAN=ON` and point `NEXVYN_IMGUI_VULKAN_BACKENDS` to
the `backends` directory from Dear ImGui 1.91.5. With the Vulkan headers
in the sysroot, `<nexvyn/nxn_imgui_vk.h>` exposes `nxn_imgui_vulkan_init`,
which loads the renderer functions through host dispatch. The caller
supplies its Vulkan instance and device and owns rendering and teardown.
See the Vulkan section of `SDK/AI_GUIDE.md` (10.4) for the capability check, the instance probe and the
manifest flag.

## SDL2 in a window

Most ports and games are SDL2 programs. Inside Nexvyn OS an SDL2 program needs no changes: the kit ships an SDL2 (the
devkitPro target fork of SDL 2.28 with the Nexvyn OS drivers added, `sdk/native/sdl2/`) that talks to the window through
`nxn_*` instead of libnx, EGL and audren. It links into the app statically, so the module imports nothing outside the host
import set. `nxv-native build` picks it up for every project that includes SDL (`pkg_check_modules(SDL2 ... sdl2)`);
build it once with `python sdk/native/sysroot/build.py sdl2-nexvyn` (it goes to `<sysroot>/windowed`, which only
window builds look at: a `--exclusive` build keeps the portlibs SDL2). The same source builds in both ways; the templates
`sdl2` and `gl` do. `examples/sdl2_check` is the
self-test: it exercises every part below and writes `sdl2_check_report.txt`.

| SDL2 part | What happens in a Nexvyn OS window |
| --- | --- |
| Video | One window uses the Nexvyn OS content area. Vulkan windows follow the content size. For GL, `SDL_WINDOW_FULLSCREEN` / `RESIZABLE` windows follow the content size and fixed-size windows keep their size and are scaled by the host. Driver name `nexvyn`. |
| GL | `SDL_GL_CreateContext` makes the app's `nxn_display` context: OpenGL ES (default 2.0, asks for 3.0 / 3.1 / 3.2 work) or core profile 4.3. No compatibility profile, one context. `SDL_GL_SetSwapInterval(0)` / `(-1)` / `(1)` succeed; a window paces to the OS frame (vsync) and does not wait only when the developer setting `perf.uncapped` is on, so `SDL_GL_GetSwapInterval()` answers 1 (the app cannot switch the wait off by itself). `SDL_GL_GetAttribute(SDL_GL_DEPTH_SIZE / STENCIL_SIZE)` answer the real buffer, 24 and 8. `SDL_GetCPUCount()` is the core count of the process mask (3 on a console). `SDL_Renderer` (OpenGL ES 2) works. `glDrawArrays`-style direct calls link too: `libnexvyn_window.a` carries every ES 3.2 entry point, and every OpenGL core 1.0 - 4.3 entry point ES lacks (`glPolygonMode`, `glClearDepth`, `glDepthRange`, `glGetTexImage` ...; 184 of them, `nxwin_glcore.c`, generated by `tools/gen_gles_shim.py`): a desktop-GL port links with no wrapper. They resolve through `nxn_display_proc` like the rest; a call the driver does not have does nothing (check `glGetString(GL_VERSION)` and extensions as on a PC). |
| Audio | any format and rate (SDL converts); a push stream in Nexvyn OS's mixer with at most two SDL buffers queued (`SDL_AudioSpec.samples`), measured 42.7 ms for 1024 samples at 48 kHz. No capture. |
| Controller | one pad, 16 buttons (the order of `NXN_BTN_*`) and 4 axes; the game controller mapping is built in. Empty while the window has no focus. |
| Touch, mouse, keyboard | touch fingers (`SDL_FINGERDOWN` ...; SDL also makes mouse events from them), the USB mouse / Nexvyn OS pointer (position, buttons, wheel, relative mode), the USB keyboard (HID usage = SDL scancode, modifiers, `SDL_TEXTINPUT` after `SDL_StartTextInput`). |
| Lifecycle | `SDL_QUIT` when the window closes; `SDL_APP_WILLENTERBACKGROUND` ... `SDL_APP_DIDENTERFOREGROUND` on sleep / HOME menu. |
| Files | `SDL_GetBasePath` = the package folder (read-only), `SDL_GetPrefPath` = the app's data folder. |
| Not there | Power info, haptics, sensors, `SDL_LoadObject`, a second window. SDL threads keep the priority Nexvyn OS gave them (`SDL_SetThreadPriority` does nothing). |

### Worker scheduling hints

`nxn_thread_hint_request` in `nxn_sys.h` sets an app-wide hint for future worker threads in a windowed native app.
It returns the granted core count and can also report the granted priority class. A zero request clears the hint
and restores the default policy for subsequent workers. Already running threads keep their placement and priority.

In both docked and handheld modes, the host reserves core 0 for the shell, its input loop and the system audio
mixer. Core 3 is reserved for the system. The host grants up to two cores from 1 and 2, subject to the process
affinity mask. With an active grant, the host honors explicit worker core requests within the grant. It remaps
explicit requests for core 0 and other placements outside the grant across the granted cores. Normal workers run
at priority 0x2D or lower. Throughput workers run at 0x30 or lower for sustained background
work. These priorities are below the shell (0x2C) and the system audio mixer (0x2B when its priority change succeeds).
The app main thread keeps its existing policy. The grant is advisory and shares CPU time with other work. If the
kernel refuses the selected placement, thread creation retries with the default core and the same priority limit.

Build with the updated kit and use the same `minNative` required by the app's other imports. The kit's weak host
import lets an older OS run the app with a grant of zero cores and normal priority. Standalone apps return the same
values. Check the grant before sizing parallel work.

The SDL2 source is zlib licensed; the added drivers are marked as altered source (`sdk/native/sdl2/overlay`).

Signature (`<nexvyn/nxn_sys.h>`): `uint32_t nxn_thread_hint_request(uint32_t worker_cores, nxn_thread_hint_priority priority,
nxn_thread_hint_priority* granted_priority)`; priorities are `NXN_THREAD_HINT_NORMAL` and `NXN_THREAD_HINT_THROUGHPUT`.
Call it before you start the workers.

```c
nxn_thread_hint_priority got = NXN_THREAD_HINT_NORMAL;
uint32_t cores = nxn_thread_hint_request(2, NXN_THREAD_HINT_THROUGHPUT, &got);   // 0..2 granted, advisory
int workers = cores ? (int)cores : 1;      // 0 on older hosts or standalone: plan for one worker
start_worker_threads(workers);
// when the load ends: nxn_thread_hint_request(0, NXN_THREAD_HINT_NORMAL, NULL);
```

## Windowed JIT, fault handler and guard pages (`nxn_jit.h`)

For recompilers and fastmem. Everything is optional and off by default: each path sits behind a setting
(`native.windowedJit`, `native.windowedFaultHandler`, `native.windowedGuardPages`; capabilities `NXN_CAP_JIT`,
`NXN_CAP_FAULT_HANDLER`, `NXN_CAP_GUARD_PAGES`). With the setting off, the calls answer `NXN_ERR_UNSUPPORTED`, so keep an
interpreter as the fallback. POSIX `PROT_EXEC` stays unsupported.

- **RW/RX model.** `nxn_jit_create(bytes, &j)` returns a buffer with two views at different addresses: write through `rw`
  (never executed) and run from `rx` (never written). `nxn_jit_get` reads both pointers; call `nxn_jit_begin_write(j)` before
  writing; `nxn_jit_end_write(j, offset, len)` after writing and before running (cleans caches for that range, len 0 =
  all); `nxn_jit_destroy(j)` when done. Code with pc-relative data must be written for the `rx` address.
- **Limits.** Up to 256 MB in total and 64 buffers per app, also bounded by the free memory above the system reserve
  (`NXN_ERR_NO_MEMORY`). Everything is returned when the app ends or crashes.
- **Your job.** The app serializes its own writes and executions: `nxn_jit_begin_write` is not a lock. No thread may run
  code in a buffer while it is rewritten or destroyed.
- **Fault handler.** `nxn_fault_handler_set(fn, user)` receives data aborts of app code on the faulting thread and may resume
  at `f->pc` (return 1) or let the app end (return 0). x17 is not restored on resume. The handler must be short, must not
  block and must not call `nxn_*` functions.
- **Guard pages.** `nxn_mem_guard(block, offset, len, mode)` with `NXN_GUARD_NOACCESS` or `NXN_GUARD_READONLY` on a
  page-aligned range inside your own `malloc` block (up to 32 ranges).

```c
nxn_jit* j;
if (nxn_capability_query(NXN_QUERY_JIT) == NXN_OK && nxn_jit_create(4 << 20, &j) == NXN_OK) {
    nxn_jit_info in = NXN_STRUCT_INIT(nxn_jit_info);
    nxn_jit_get(j, &in);
    nxn_jit_begin_write(j);
    memcpy(in.rw, code, n);
    nxn_jit_end_write(j, 0, n);
    ((int (*)(void))in.rx)();
} // else: interpreter
```

## Port input helper (`nxn_port_input.h`)

A header-only helper for ports of PC games and emulators. It turns the pad, the touch screen and the USB keyboard and mouse
into one event stream, so an engine that expects a mouse and keyboard needs one translation layer.

```c
#include <nexvyn/nxn_port_input.h>

nxn_pi_ctx pi;
nxn_pi_init(&pi, NXN_PI_PROFILE_RTS, 1280.0f, 720.0f);   // profile, view width, view height
// optional: pi.pinch_mode = NXN_PI_PINCH_EVENT_ONLY;   pi.rotate_deadzone = 0.12f;
// each frame:
nxn_pi_update(&pi, dt_sec);                              // polls input, fills the queue
nxn_pi_event ev;
while (nxn_pi_poll_event(&pi, &ev)) {
    switch (ev.type) {
    case NXN_PI_EV_MOUSE_MOVE:   engine_mouse_move(ev.x, ev.y, ev.dx, ev.dy); break;
    case NXN_PI_EV_MOUSE_DOWN:   engine_mouse_button(ev.button, 1, ev.x, ev.y); break;
    case NXN_PI_EV_MOUSE_UP:     engine_mouse_button(ev.button, 0, ev.x, ev.y); break;
    case NXN_PI_EV_MOUSE_WHEEL:  engine_wheel(ev.wheel_x, ev.wheel_y); break;
    case NXN_PI_EV_KEY_DOWN:     engine_key(ev.hid_usage, 1, ev.mods); break;
    case NXN_PI_EV_KEY_UP:       engine_key(ev.hid_usage, 0, ev.mods); break;
    case NXN_PI_EV_TEXT:         engine_text(ev.text); break;               // UTF-8, up to 63 bytes
    case NXN_PI_EV_PINCH:        engine_zoom(ev.pinch_delta, ev.x, ev.y); break;   // only in EVENT_ONLY mode
    case NXN_PI_EV_TWO_FINGER_TAP: break;           // a right click (down + up) follows in the stream
    case NXN_PI_EV_ROTATE:       engine_rotate(ev.angle_delta, ev.angle_total, ev.x, ev.y); break;
    case NXN_PI_EV_DOUBLE_TAP:   engine_double_tap(ev.x, ev.y); break;
    default: break;
    }
}
```

Profiles: `NXN_PI_PROFILE_GAMEPAD` (no bindings, gestures only), `NXN_PI_PROFILE_RTS` and `NXN_PI_PROFILE_CRPG` (left stick moves
a virtual cursor, triggers click) and `NXN_PI_PROFILE_FPS` (left stick as W/A/S/D, right stick relative mouse look, ZR / ZL
fire / alt). Change bindings with `nxn_pi_clear_bindings`, `nxn_pi_bind(ctx, button_mask, kind, code)` and
`nxn_pi_apply_profile`; at most `NXN_PI_MAX_BINDINGS` (32) bindings and `NXN_PI_MAX_EVENTS` (128) queued events.

Touch gestures (set `pi.two_finger_gestures = 0` to turn the two-finger ones off):

| Gesture | Event | Notes |
| --- | --- | --- |
| Two-finger pinch | `NXN_PI_EV_PINCH`, or mouse wheel, or Ctrl +/- keys | `pi.pinch_mode`: `NXN_PI_PINCH_WHEEL` (default, one wheel notch per step), `NXN_PI_PINCH_CTRL_PM`, `NXN_PI_PINCH_EVENT_ONLY` |
| Two-finger pan | `NXN_PI_EV_MOUSE_WHEEL` with `wheel_x` / `wheel_y` | scrolls while the fingers move together |
| Two-finger rotate | `NXN_PI_EV_ROTATE`: `angle_delta` (radians since the last event, positive clockwise with y down) and `angle_total` (since the gesture began) | starts after the angle changed by `pi.rotate_deadzone` (default 0.08 rad) |
| Two-finger tap | `NXN_PI_EV_TWO_FINGER_TAP`, then right mouse down and up | a quick tap with no pinch, pan or rotate |
| Double tap (one finger) | `NXN_PI_EV_DOUBLE_TAP` at the second tap | `pi.double_tap_ms` (default 300) and `pi.double_tap_dist` (default 20 px) set the window; `pi.double_tap_ms = 0` turns it off. It emits no mouse click: the app decides what it means |
| Long press (one finger) | right mouse down and up after about 550 ms | `pi.long_press_right = 0` turns it off |

The pad also moves the virtual cursor in the RTS and CRPG profiles (`pi.cursor_x`, `pi.cursor_y`, speed `pi.cursor_speed`,
dead zone `pi.deadzone`). `NXN_BTN_Y` toggles the on-screen keyboard (`NXN_PI_BIND_TOGGLE_OSK`) in those profiles. The
struct holds the event queue and is large: keep one per app, not on a small thread stack.

## Fullscreen memory: `"fullscreenPause"`

`"fullscreenPause": true` in `app.json` is for a native app or port that runs fullscreen and wants the most free memory.
While the app is fullscreen and focused, the shell pauses its own desktop composition and frees its rebuildable caches
(about 18 MiB of heap, measured in the emulator); it restores them when the app leaves fullscreen, loses focus, is suspended or
stops. Use it for memory-hungry ports and emulators that never need the desktop visible. It is pointless for a windowed app.
It is the per-app version of the shell setting `native.compositorPause`; older systems ignore the field.

## On-screen performance panel

Press Ctrl+Alt+P (or L+R+ZL+ZR on the pad) to show or hide the panel in Nexvyn OS 1.4.0. It shows frame time and its
phases, skipped frames, RAM and GPU lock time. Use it while porting: check that a scene holds its frame time before and
after a change, that RAM stays under your budget (compare with `nxn_memory_budget_get`), and whether long GPU lock times
mean your app blocks the shared command stream. The panel is optional and hidden by default. Record measurements together
with the hardware they came from; emulator numbers are not console numbers.

## Input and docking

Inside Nexvyn OS the host delivers input and size changes (section above). This section describes the `nxn_*` library's
own input owner and docking events; the SDL2 driver for Nexvyn OS windows is built on the same calls, so an SDL app is
its own input owner and never calls `nxn_input_poll` itself.

**Native SDK 1.1 additions** (each is announced by an `nxn_caps.features` bit; a system without it answers
`NXN_ERR_UNSUPPORTED` and nothing else changes for older apps):

- `nxn_audio_clear` (`NXN_CAP_AUDIO_CLEAR`): drops what a push stream has queued, the next `nxn_audio_queue` starts fresh.
- `nxn_input_text_request(wanted)` (`NXN_CAP_TEXT_REQUEST`, bit 36; Native 1.1 add-on, add-only): tells Nexvyn OS that a text field is being edited, so the system's on-screen keyboard opens by itself (not with a USB keyboard) and the typed text arrives through `nxn_input_text`. ImGui apps call `nxn_imgui_text_sync()` (`nxn_imgui.h`) once per frame; SDL apps get it from `SDL_StartTextInput` / `SDL_StopTextInput` (the Nexvyn SDL2 video driver). The stand-alone library answers `NXN_ERR_UNSUPPORTED`.
- `nxn_input_key_poll`, `nxn_input_text`, `nxn_input_mouse` (`NXN_CAP_USB_INPUT`): ordered USB key events (a tap inside one
  frame is not lost), typed text (UTF-8) and the pointer as a mouse. Calling `nxn_input_mouse` once turns the app into a
  mouse user: the pointer then no longer also counts as touch 0 in `nxn_input_touch`. `nxn_input_key_held` knows the
  modifier keys (usage 224..231). On the touch screen `nxn_input_touch` gives every finger (up to 16) with a stable
  `id` (0, 1, 2 ...: the lowest free number when the finger went down, so one finger is always 0); in SDL apps each id is an
  `SDL_FingerID`, so two fingers send two distinct `SDL_FINGERDOWN` / `SDL_FINGERMOTION` / `SDL_FINGERUP` streams.
- `NXN_EVENT_DOCK`, `NXN_EVENT_SUSPEND`, `NXN_EVENT_RESUME` (`NXN_CAP_POWER_EVENTS`): docked / handheld, and sleep or the
  HOME menu. After `SUSPEND` Nexvyn OS plays no sound of the app and `nxn_display_swap` reads nothing back until `RESUME`,
  which drops the sound queued before the suspend.
- System services (`nxn_sys.h`, windowed mode; the stand-alone library answers `NXN_ERR_UNSUPPORTED`): `nxn_notify`
  (`NXN_CAP_NOTIFY`, needs `"notifications"` in app.json), `nxn_clipboard_get` / `nxn_clipboard_set` (`NXN_CAP_CLIPBOARD`, no
  permission), `nxn_rumble` (`NXN_CAP_RUMBLE`: only while the window has focus, stops by itself, at most 2 s per call),
  `nxn_pick` (`NXN_CAP_PICKER`: Nexvyn OS's open / save / folder dialog; `NXN_ERR_CANCELLED` when dismissed) with
  `nxn_grant_get` / `nxn_grant_check` / `nxn_grant_revoke` (a folder picked with `NXN_PICK_REMEMBER` stays granted across runs, the
  user can take it back), `nxn_save_path` / `nxn_save_backup` / `nxn_save_restore` / `nxn_save_backup_get` /
  `nxn_save_backup_delete` (`NXN_CAP_SAVEDATA`: the user's own save folder `<data>/save` and named backups in
  `Library/Backups/<app id>`, restore keeps the current save until the copy is in place) and `nxn_perm_query` /
  `nxn_perm_request` (`NXN_CAP_PERMISSIONS`, for `"network"` and `"notifications"`; a question is asked at most once per
  permission and session). Calls that need Nexvyn OS's interface run on its main thread while the app thread waits (and
  stays "alive" for the not-responding check); put `nxn_pick`, `nxn_perm_request` and the save calls on a worker thread
  when the frame loop must go on. `examples/showcase` has a row and a self-test for each.

**Large read-only assets.** With `NXN_CAP_STREAM`, `nxn_stream_*` uses the windowed host's shared block cache.
Use `NXN_STREAM_NOWAIT` on a render/audio path and retry Busy on a later frame; blocking reads belong on a suitable
worker. Prefetch is an advisory bounded window, not a completion signal: cached or already queued blocks share work,
and `NXN_ERR_BUSY` means the rest could not be admitted yet (some blocks may already be queued). Do not spin on it or
load the whole asset as a fallback. Keep the stream until current calls return, then close it; the host retains any
in-flight ownership until its worker finishes. Stand-alone builds still read files directly and ignore Nowait, as
documented in `nxn_stream.h`; do not infer asynchronous behavior without the windowed capability.

**Who owns the controller.** By default the input owner is `nxn_input`: `nxn_input_poll` reads the pads through libnx,
maps the buttons to Nexvyn's bit order and adds the user's confirm / cancel buttons (`NXN_ACT_CONFIRM` / `NXN_ACT_CANCEL`,
also `nxn_info_get`). The library touches no HID state until the first `nxn_input_poll` or `nxn_input_key_held` call.

An app that wants SDL's joystick or game controller API (most SDL2 ports) therefore chooses SDL as its input owner:

- do not call `nxn_input_poll`, `nxn_input_touch` or `nxn_input_key_held` anywhere in the program;
- call `SDL_Init(SDL_INIT_JOYSTICK | SDL_INIT_GAMECONTROLLER)` and read the pads through SDL;
- keep using the rest of `nxn_*` (display, audio, files, log, return). Read `nxn_info_get().confirm_buttons` /
  `cancel_buttons` if the app wants the user's mapping (the masks use the `NXN_BTN_*` bits; SDL joystick button
  numbers are a different numbering, so the app converts).

Mixing both layers is possible but not supported: each keeps its own "pressed this frame" state.

**Docking.** `nxn_event_poll` (header `nxn_event.h`, capability `NXN_CAP_EVENTS`) returns `NXN_EVENT_RESIZE` when the
console is docked or undocked: the new output size (1920x1080 docked, 1280x720 handheld) and `docked`. The library
never changes the surface by itself. An app that wants the new size calls `nxn_display_resize` (the EGL surface is
recreated, the context stays) and sets `glViewport`; an app that ignores the event keeps its size and the system
scales it. Events arrive while the app calls `nxn_should_quit()` (or while SDL pumps events), so call it every frame.
`examples/hello_gl` shows the loop. The surface change has to be proven on a console before it is relied on.

**Applet mode.** Nexvyn OS started from the Album (applet mode) has far less memory; an app sees
`NXN_CAP_APPLET_MODE` in `nxn_caps_get`. Start Nexvyn OS in title mode instead (hold R while starting a game).

**Crashes.** An app that crashes three times in a row makes Nexvyn OS ask "Close / Keep enabled"; a normal exit
starts the count again.

## System integration (Native 1.2)

For apps that should feel like part of Nexvyn OS. Each call is announced by an `nxn_caps` bit and answers `NXN_ERR_UNSUPPORTED` without it (a stand-alone `.nro`, an older system); an app that uses them says `"minNative": "1.2"`. Everything is add-only: apps built for 1.0 / 1.1 run unchanged. Sample: `sdk/native/examples/services12`.

- **Window control** (`nxn_window.h`, `NXN_CAP_WINDOW_CTL`): `nxn_window_set_title(title, subtitle)` sets the title bar ("Game - Level 3", 200 bytes each, cut at a character boundary), `nxn_window_set_mode(NXN_WIN_NORMAL / MAXIMIZED / FULLSCREEN)` asks for a window mode (the answer is `NXN_EVENT_RESIZE`; maximize is ignored for a window that is not resizable), `nxn_window_set_modified(1)` shows the OS "edited" mark in the title and lists the app among those with unsaved work before Nexvyn OS quits, restarts or powers off (closing still posts `NXN_EVENT_QUIT`). The calls return at once; the OS main thread applies the newest values within a frame.
- **Power and network state** (`nxn_power.h`, `NXN_CAP_POWER_STATE`): `nxn_power_get(&p)` copies the battery percent (-1 = unknown, e.g. an emulator), charging, docked and online flags that Nexvyn OS already keeps (no file, network or service call: cheap enough for every frame). `NXN_EVENT_POWER` (only apps with `"minNative": "1.2"` or later) arrives when one of them changed (battery by 1 percent or more), at most once a second, unread ones merge: read the state with `nxn_power_get`. A network change is the `online` flag. Use it to lower the load on a low battery or skip an online request while offline.
- **OS dialogs** (`nxn_dialog.h`, `NXN_CAP_DIALOG`): `nxn_dialog(&params, &picked)` shows the OS alert / question with 1 to 4 buttons of your own (the first is the default, `cancel_button` is what Esc / B answers, `danger_button` is drawn as destructive; labels may be keys of the app's `lang/<code>.json`), `nxn_prompt(title, message, initial, out, cap)` a text field (`NXN_ERR_CANCELLED` when dismissed). Same look, theme, gamepad and touch handling as the OS apps. **Both wait for the user on the calling app thread** (like `nxn_pick`): the OS main thread keeps drawing, the window is not "not responding", and the wait ends with `NXN_ERR_NOT_READY` when the window closes. To keep the app running meanwhile (an emulator that keeps emulating), call them from a worker thread; to pause it, from the main thread. One dialog per app at a time (`NXN_ERR_BUSY`).

## OS look and the app's own texts (Native 1.1, `nxn_ui.h`)

For ordinary apps, tools, editors and game/port launchers, use the OS frame layer and shared controls. Games keep their own art direction and may build custom gameplay HUDs; a companion launcher or settings form can reuse the OS controls. Start from the app, game or port template as appropriate.

- `nxn_ui_tokens_get`: one sized struct with the colours (background, surface, text, secondary text, accent, error, warning, success, border...), sizes (corner radius, spacing steps, row / control height, text sizes, text scale) and `revision`. The values come from the OS's own palette, not from copies, and follow light / dark, accent and high contrast. `ui_scale` (field added at the end, 0 on systems before it) is the window surface's pixels per OS UI point: 1.0 at the default interface size, 1.5 for 150 % or a full-screen TV surface that shows the 1280 x 720 layout; it follows the window (a `NXN_EVENT_RESIZE` comes with a change) and does not raise `revision` or send `NXN_EVENT_THEME`.
- `NXN_EVENT_MENU` (`nxn_menu.h`, `NXN_CAP_MENU`, setting `native.windowMenu`, default on for apps with `"minNative": "1.1"` or later, `false` turns it off; not verified on a console): the user picked an item of the app's window menu (`nxn_menu_set`); `item_id` is its id. Only apps with `"minNative": "1.1"` get it. Not for games.
  Drain events every frame. The windowed host admits up to 16 pending menu commands and temporarily disables app
  commands at that limit; OS close/recovery controls remain available. Stale callbacks at capacity are not admitted.
  Admitted commands arrive once in order, independently of coalesced resize/focus/lifecycle state. No app rebuild is
  required for this host correction; event structs and imports are unchanged.
- **Cancellation edges.** The current host preserves a pending focus loss or suspend before its final restore. Forward every lifecycle event to `nxn_imgui_input_event` before the shared input/frame helpers. Rebuild apps with the updated kit to cancel same-frame loss/regain, discard the cancelled press and wait for held contacts/mouse buttons to lift. Resume preserves prior focus; it does not grant focus. Frozen event layouts and imports are unchanged.
- **Responsive resize.** The current app template explicitly opts in with `"liveResize": true`. The host requires lifecycle support (`"minNative": "1.1"` or later), coalesces unread sizes and does not deliberately delay the responsive path by 120 ms. Existing saved `native.liveResize: false` settings and manifest opt-outs remain authoritative; legacy/opted-out apps retain settled resizing. Current hosts also recognize a responsive default for `targetNative` 2.0 or later, but keep `targetNative` at the SDK version actually tested rather than raising it to select behavior. Process `NXN_EVENT_RESIZE`, call `nxn_display_resize`, query the resulting dimensions and reflow from those dimensions while retaining edits, focus and scroll state. This is an interaction contract, not a hardware frame-rate guarantee. See [responsive interaction quality](NATIVE_GUIDE.md#responsive-interaction-quality).
- `NXN_EVENT_THEME`: the look changed; read the tokens again. Only apps with `"minNative": "1.1"` get it; older apps can compare `revision` once a frame.
- `nxn_ui_font_get` gives the system font bytes (for example ImGui `AddFontFromMemoryTTF`, `FontDataOwnedByAtlas = false`), `nxn_ui_icon_code("folder")` the code point in the `NXN_UI_FONT_ICONS` font.
- **Text and fonts.** ImGui loads Latin-1 only unless it is given glyph ranges, so Turkish (dotless i, g-breve, s-cedilla, capital I with dot), Cyrillic, Greek or Japanese text would show as `?`. `#include <nexvyn/nxn_imgui.h>` (header only, after `imgui.h`) and call `nxn_imgui_add_font(io.Fonts, NXN_UI_FONT_SANS, px, 0, icon_ranges)`: it adds the system font with the ranges the app's language needs (`nxn_info_string(NXN_INFO_LANGUAGE)`): Latin-1 and Latin Extended-A always (en, tr, de, es, fr), Latin Extended-B for `vi`, Greek for `el`, Cyrillic for `ru uk bg sr`; the flag `NXN_IMGUI_ALL_SCRIPTS` adds all of them for text the app did not translate (file names). The atlas stays small because only those ranges are loaded. Icons are merged into the same font when `icon_ranges` is given. The system font is Inter (Latin, Greek, Cyrillic); the Han / Kana / Hangul font comes as `NXN_UI_FONT_CJK` (`NXN_CAP_UI_FONT_CJK`, bit 32; the console's shared font, else a font pack on the SD card, cut to the face of the app's language) and the same helper merges it for `ja`, `ko` and `zh` with no change in the app: a compact set of common characters (about 2400-3000: ImGui's Japanese and Simplified Chinese tables, the 2350 syllables of KS X 1001 for Korean), not the whole font. Each font that gets it grows the atlas by about 1 MB per 20 px, so pass `NXN_IMGUI_NO_CJK` for digit / monospace fonts; fonts above 30 px skip it unless `NXN_IMGUI_CJK_LARGE`. A system without the font (older Nexvyn OS, no font installed) draws Latin only and nothing fails. The `app` template, the Showcase and the Tour use the helper; use it in your own ImGui apps and keep texts in `lang/*.json`.
  - **4-Runtime Typography Scaling Parity (1.21x Factor; the frame layer applies it, this is for games and scenes that build their own fonts):** FreeType scales glyphs relative to its Em-box (`upem = 2048`), while Dear ImGui's `stb_truetype` scales relative to `(ascent - descent)` (`2478` for Inter). The shared OS frame layer owns this calibration for ordinary apps. For a custom font setup using the same Inter face, `1.21f` (`2478 / 2048`) is the current reference calibration; validate baselines, text scale and each supported locale rather than assuming that one factor guarantees parity for every font:
    - Title / Hero: `floorf(19.2f * 1.21f * sc + 0.5f)` (`NXN_UI_FONT_BOLD`)
    - Card Header: `floorf(15.2f * 1.21f * sc + 0.5f)` (`NXN_UI_FONT_BOLD`)
    - Body / Controls: `floorf(13.8f * 1.21f * sc + 0.5f)` (`NXN_UI_FONT_MEDIUM`) -> Assign to `ImGui::GetIO().FontDefault`
    - Badge / Subtitle: `floorf(12.0f * 1.21f * sc + 0.5f)` (`NXN_UI_FONT_MEDIUM`)
    Keep `io.FontGlobalScale = 1.0f` and snap custom drawing coordinates to integer pixels.
- **Controller and touch in ImGui.** ImGui moves its focus with a pad only when the app sets `ImGuiConfigFlags_NavEnableGamepad` and the backend sets `ImGuiBackendFlags_HasGamepad`; the OpenGL3 backend never does, so a controller did nothing. Call `nxn_imgui_enable_gamepad(io)` (`nxn_imgui.h`, also done by `nxn_imgui_add_font`) after `ImGui::CreateContext()` and feed the pad with `io.AddKeyEvent(ImGuiKey_Gamepad...)`. In a window `nxn_input_touch` already gives pixels of the app's surface (the same space as `DisplaySize`): pass them to `io.AddMousePosEvent` unchanged. Only a full-screen build gets a 1280x720 space and scales (`#ifndef NEXVYN_WINDOWED`).
- **Unified OS Widget Kit for ImGui (`<nexvyn/nxn_os_ui.h>`, header-only).** Never ship raw unstyled Dear ImGui checkboxes, thick tables, or hardcoded dark `glClearColor(...)` in utility/tool/HUD apps. Include `<nexvyn/nxn_os_ui.h>` after `imgui.h` (it includes `nexvyn_native.h` and `nxn_imgui.h` itself):
  - **Frame layer (required):** `nxn_os_frame_begin(&tok, fb_w, fb_h)` ... `nxn_os_frame_end()` replace `ImGui_ImplOpenGL3_NewFrame` / `ImGui::NewFrame` / `ImGui::Render`. They read the tokens and `ui_scale`, build the text roles (Title, Header, Body, Caption, Strong, Mono at `floorf(pt * 1.21f + 0.5f)` x text size x scale; rebuilt with a 0.2 s debounce and a new GL texture when the scale or text size changes), apply `nxn_os_apply_style` x scale every frame, open a full-window root with the OS margins and enforce the minimum sizes (text controls 30 px high and 44 px wide, icon buttons / rail items / list rows / menu rows 44 px, all x scale). Sizes the app writes go through `NXN_S(px)`; spacing `nxn_os_sp(NXN_OS_SP_*)`, radii `nxn_os_radius(NXN_OS_R_*)`, widths `nxn_os_fill(frac)`. Text by role: `nxn_os_text(NXN_OS_TEXT_*, s)`. Rows: `nxn_os_row_begin` / `_end` (equal height, vertically centred), `nxn_os_labeled(label, widget)`, `nxn_os_align_right(w)`. New widgets: `nxn_os_select`, `nxn_os_input` / `_multiline`, `nxn_os_toggle_button` (ON / OFF), `nxn_os_icon_button` (44 px, system icons merged into the role fonts), `nxn_os_switch_row`, `nxn_os_slider_int`, `nxn_os_sidebar_begin` / `_end` + `nxn_os_rail_item`, `nxn_os_list_row`. `nxn_os_set_text_zoom()` is an app's own text size option (sharp, rebuilt fonts). Another renderer than imgui_impl_opengl3: `NXN_OS_UI_NO_GL3`, `NXN_OS_FRAME_NO_BACKEND`, `nxn_os_set_font_uploader`. Without the frame layer every `nxn_os_*` widget behaves as before (scale 1, no minimum). Reference: `product/showcase/com.nexvyn.uikit.cpp`; counter-example (must fail the checker): `tests/fixtures/design_bad_native`.
  - `nxn_os_apply_style(tok)` & `nxn_os_clear_color(tok)` — syncs Light/Dark/High-Contrast `ImGuiStyle` and window clear color (the frame layer calls the first one every frame; the app clears with the second).
  - `nxn_os_segmented_tabs(...)`, `nxn_os_card_begin/end(...)`, `nxn_os_kv_row(...)`, `nxn_os_switch(...)`, `nxn_os_dropdown(...)`, `nxn_os_button(..., NXN_OS_BTN_PRIMARY | DEFAULT | DESTRUCTIVE | PLAIN)`, `nxn_os_badge(...)`, `nxn_os_progress_bar(...)`, `nxn_os_separator(...)` — renders the same visual language as OS `ui.*` & `nxui.*` widgets.
  - Note: `nxn_nxui_*` in `<nexvyn/nxn_nxui.h>` runs layout/focus solvers in memory and never paints inside an OpenGL `nxn_display` framebuffer (an app thread must not use the shared OS renderer). `nxn_nxui_end_ex()` returns `NXN_ERR_UNSUPPORTED` in that case; GL-based C++ apps use `<nexvyn/nxn_os_ui.h>` for the UI.
  - **Strict design rules:** `python tools/nxv_native check-design <dir>` (or `python tools/design_check.py`) FAILs an ImGui app that skips the frame layer, lacks `nxn_os_clear_color` (or clears to a constant behind its UI), sets `io.FontGlobalScale` or `SetWindowFontScale`, adds fonts itself (`AddFont*`, `nxn_imgui_add_font`), uses a raw ImGui widget that has an `nxn_os_*` counterpart (`Button`, `Combo`, `Checkbox`, `SliderFloat`, `SliderInt`, `InputText*`, `RadioButton`, `ProgressBar`, `BeginTabBar`) or writes a pixel literal outside `NXN_S()` (`SetNextItemWidth`, `Dummy`, `SameLine`, `BeginChild`, `ImVec2(...)`, `nxn_os_*` size arguments); each finding names the fix. The same rules run in `python tools/nxv_native check-design <dir>` (exit 1; the public `nxv.py check` does not run them) and are listed by `nxv_native package`. Examples are capped at warnings; games and sources marked `nxn-design: scene` are exempt from the widget, font and pixel rules. Reference: the `app` template (`sdk/native/templates/app`).
- `nxn_tr(key)` / `nxn_tr_format(key, out, cap, args, argc)`: texts from the package's `lang/<code>.json` (the package tool copies the `lang` folder). Same rule as `TR()` of the script SDK: nested keys joined with dots, `{0}` placeholders, fallback language -> base language -> `en` -> the key. The language is the one at start; the system's own strings are not available.
- Caps: `NXN_CAP_UI_TOKENS`, `NXN_CAP_TEXT`. In a stand-alone .nro the calls return `NXN_ERR_UNSUPPORTED` and `nxn_tr` returns the key.
- The showcase has a "UI tokens" page and self-test rows for all of it.

## Error codes (`nxn_result`, `nxn_base.h`)

Values never change (add-only). 0 is `NXN_OK`; every error is negative.

| Code | Value | Meaning |
|---|---|---|
| `NXN_ERR_INVALID` | -1 | bad argument |
| `NXN_ERR_UNSUPPORTED` | -2 | feature missing (see `nxn_caps_get`) |
| `NXN_ERR_NOT_READY` | -3 | `nxn_init` not called, or object closed |
| `NXN_ERR_IO` | -4 | file system error |
| `NXN_ERR_DENIED` | -5 | refused (path outside the app's folders, read-only) |
| `NXN_ERR_NO_MEMORY` | -6 | out of memory |
| `NXN_ERR_TOO_SMALL` | -7 | output buffer too small |
| `NXN_ERR_NOT_FOUND` | -8 | not found |
| `NXN_ERR_SYSTEM` | -9 | a system service failed (`nxn_last_error`) |
| `NXN_ERR_CANCELLED` | -10 | the user dismissed a dialog |
| `NXN_ERR_TIMEOUT` | -11 | reserved: a wait ran out of time |
| `NXN_ERR_BUSY` | -12 | reserved: resource in use, retry later |
| `NXN_ERR_EXISTS` | -13 | reserved: target already exists |
| `NXN_ERR_LIMIT` | -14 | reserved: a limit was reached |

Reserved codes are not returned by any call yet; handle them as "failed, see `nxn_last_error`". Planned mapping of NexGFX
failures when `ngfx_*` calls surface through `nxn_*` (documentation only, no ngfx ABI change): invalid handle or argument
-> `NXN_ERR_INVALID`; feature not in caps -> `NXN_ERR_UNSUPPORTED`; allocation failure -> `NXN_ERR_NO_MEMORY`; GL or driver
failure -> `NXN_ERR_SYSTEM`; resource or queue limit -> `NXN_ERR_LIMIT`.

## Performance, frame pacing and settings (Nexvyn OS 1.2.2)

What changed for native apps, measured on a console (nothing here needs a code change; older apps run as before):

- **Faster by default.** The GPU lock is held only while drawing, shaders compile without the lock, an unobstructed fullscreen native window bypasses desktop composition and still presents through the shell, and an unchanged frame is not presented again. Measured: a 3D scene demo 10 to 59 fps, an OpenGL showcase 10-16 to 60 fps, a GBA emulator at full speed, the frame handoff from app to system 15-24 ms to 0.1 ms, scene loading about 30 s to 0.6 s. Every one of these can be turned off with its setting (`native.gpuLazyLock`, `native.gpuUnlockedCompile`, `native.fullscreenDirect`, `compose.idleSkip`, `gfx.ngfxOpaqueNoDiscard`: `false`).
- **Settings > Performance.** Official maximum clocks (`perf.official`, on by default) and a CPU boost while an app loads (`perf.loadBoost`) stay inside the console's official limits. An optional overclock (`perf.mode`, off by default) asks once and needs a clear yes (`perf.consent`). Your app does not call any of this; it only sees the result.
- **Frame pacing.** `native.frameAhead` (0 default, 1, 2) lets the swap return at once when the previous frame was already taken; it costs up to one frame of latency, so leave it at 0 for games unless you measured a gain. `gfx.dynamicRes` (`auto`, `on`, `off`) scales the render size towards `gfx.dynamicResFps` (60) between `gfx.dynamicResMin` (0.6) and the view's own `render_scale`; `auto` is on only for apps that target an SDK newer than 1.12. Keep your frame time under 16.6 ms and let the system pace the frame: do not busy-wait.
- **Sound.** The kit's SDL2 now converts every sample format (U8, S8, S16, S32, F32; 11 025 to 48 000 Hz) and mixes more than two channels down to stereo correctly. If your game crackled, rebuild it with the current kit (`python sdk/native/sysroot/build.py sdl2-nexvyn`, then your build).
- **Errors.** `NXN_ERR_TIMEOUT`, `NXN_ERR_BUSY`, `NXN_ERR_EXISTS` and `NXN_ERR_LIMIT` are reserved (-11 to -14, see "Error codes" above). They are not returned by any call yet: treat any unknown negative result as a plain failure.
- **Store pictures.** For a game, we recommend five Store screenshots from the best camera angles, taken with the system language set to English. This is advice, not a rule.

## Toolchain

C11 and C++17 (GNU dialect), `-O2 -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer` in Release (crash backtraces, `-DNEXVYN_FRAME_POINTER=OFF` drops it; aarch64 already keeps a frame record in every non-leaf function, so the first flag alone changes nothing: the second one gives leaf functions a record too, which keeps the caller of a crashing leaf on the chain; measured on a template app: .text 713332 -> 725500 bytes, +1.7 %), exceptions and RTTI on, `-march=armv8-a+crc+crypto -mtp=soft`, devkitPro
portlibs on the search path. Every module link adds a build-id and moves the debug information to `<name>.nxvmod.debug` (`.nxvlib.debug` for libraries) in the build folder; it is never packaged (`nxv-native symbolize`, guide section 4). `nexvyn_add_nro(target TITLE AUTHOR VERSION ICON ROMFS)` makes the `.nro`.
## Templates

| Template | What it is |
| --- | --- |
| `app` | A small real UI app: file picker, a setting kept between runs, `lang/en.json` + `lang/tr.json`, the Nexvyn OS look from `nxn_ui` tokens (ImGui over GL; windowed). The default. |
| `game` | Building blocks, no menu: fixed-step loop, resize / focus / suspend, a GL quad batch, an action map, OS mixer sound, a save file. Full screen by default. |
| `port` | Glue for an existing CMake project: `fetch.py` (pinned tag and commit, patches), toolchain, SDL2, optional compat layer; `example-upstream/` stands in until you fetch. |
| `sdl2` | SDL2 window, controller input, frame loop with delta time, renderer (window / full screen in Nexvyn OS, `.nro` with `--exclusive`). |
| `gl` | SDL2 + EGL OpenGL ES 2 context, one shader, a spinning triangle. |
| `emu-skeleton` | Emulator shape: `Cpu` with registers, memory and a fetch/decode/execute loop with a per-frame cycle budget, and `JitMemory` (libnx `jitCreate`, with a clearly marked fallback and TODO). |
| `decomp-skeleton` | PC-style `main(argc, argv)`, data folder on the SD card, `fopen_ci()` for case-insensitive file access. |
| `shared-lib` | A tiny shared library (`greet.nxvlib`) and an app that loads it with `nxn_lib_open` (uses the Nexvyn ABI). |

The guide `docs/NATIVE_GUIDE.md` walks through install, build, package, run and diagnosis. Except `app`, `game`, `port` and `shared-lib`, each builds to a `.nro` without the Nexvyn ABI. Look for `#ifdef NEXVYN_ABI` in `src/`: that is where the ABI calls
go.

## Libraries (sysroot)

`python sdk/native/sysroot/assemble.py` lists what devkitPro already gives and what the overlay adds:

- From devkitPro (portlibs): SDL2 (+ image, mixer, ttf, gfx), mesa (EGL, GLES), glad, zlib, libpng, libjpeg-turbo,
  freetype, curl, mbedtls, ffmpeg, bzip2, harfbuzz, libwebp, opus, ogg, flac, mpg123.
- From the Nexvyn sysroot (static libraries, built by `sysroot/build.py`):

| Library | Version | Licence | What is built |
| --- | --- | --- | --- |
| zstd | 1.5.6 | BSD-3-Clause | library, multithreaded |
| lz4 | 1.10.0 | BSD-2-Clause | library |
| SQLite | 3.47.2 | public domain | amalgamation with FTS5, no WAL, exclusive locking |
| libarchive | 3.7.7 | BSD-2-Clause | zip, tar, gzip, bzip2, zstd, lz4; no ACL, xattr or external program filters |
| OpenAL Soft | 1.23.1 | LGPL-2.0-or-later | SDL2 backend only (audio goes through SDL2) |
| GNU libiconv | 1.17 | LGPL-2.1-or-later | full encoding set; the sysroot `iconv.h` replaces newlib's small one |
| pixman | 0.43.4 | MIT | with AArch64 NEON |
| GLib | 2.78.6 | LGPL-2.1-or-later | glib, gobject, gthread, gmodule; no gio (see below) |
| PCRE2, libffi | 10.44, 3.4.6 | BSD-3-Clause, MIT | GLib's dependencies |

- Dear ImGui 1.91.5 (MIT) is in `sysroot/vendor/imgui` with the SDL2 and OpenGL ES 3 backends:
  `add_subdirectory(${NEXVYN_KIT}/sysroot/vendor/imgui imgui)` and link `imgui`.

### Build it, package it, use it

```
python sdk/native/sysroot/build.py --setup-venv      # once: a local meson (pixman, glib) in the cache folder
python sdk/native/sysroot/build.py                   # every library into build/native-sysroot/
python sdk/native/sysroot/build.py glib              # one library (its dependencies first)
python sdk/native/sysroot/build.py package           # build/nexvyn-native-sysroot-<version>.tar.zst + .manifest.json
python sdk/native/sysroot/build.py test              # builds the sysroot proof .nro
python sdk/native/sysroot/assemble.py --prefix DIR --archive nexvyn-native-sysroot-1.0.0.tar.zst
```

How the builder works: sources are downloaded once into `build/native-sysroot-cache/dl`, checked against the sha256 in
`recipes.json`, unpacked and built in the same cache folder (`src/`, `bld/`, one log per library in `logs/`). A restart
or a second run skips what is finished (a stamp per library in the prefix); change a recipe, a patch or a shim and only
that library rebuilds (`--force` rebuilds one anyway). The prefix has `include/` and `lib/` (with a `pkgconfig` folder; relocatable:
the `.pc` files use `${pcfiledir}`) and the CMake config files the libraries ship. The archive has normalised tar
metadata, `manifest.json` (library, version, licence, source URL and sha256, file sizes) and `licenses/<library>/`.
None of this is committed; the archive (about 4.5 MB, debug sections stripped) is a download, built or fetched on demand.

The builder needs devkitPro with its msys2 (cmake, ninja, make, zstd, pkg-config), Python 3.9 or newer and `patch`
(Windows: it comes with Git for Windows). `--setup-venv` puts meson into the cache folder; nothing else on the machine
is touched. Use the prefix with `NEXVYN_SYSROOT=DIR` (CMake kit) or `-I DIR/include -L DIR/lib` (plain make).

### Proof: the sysroot test program

One `.nro` calls every library once: zstd and lz4 round trips, an in-memory SQLite query, a zip and a tar.zst written
and read back through libarchive, an OpenAL device and context on the SDL2 backend (`ALSOFT_DRIVERS=sdl2`, so a silent
fallback to the null backend fails the test), a UTF-8 to UTF-16LE and a latin1 to UTF-8 iconv conversion, a pixman
rectangle fill, and a GLib hash table, string and main-loop iteration. It writes `sdmc:/sysroot_test_results.txt` (one
line per library, then `RESULT pass=N fail=M`) and returns M. Last run in the emulator: pass=8, fail=0.

### Things to know

- GLib has no gio: sockets, D-Bus, subprocesses and inotify are outside the supported target port, and gio's configure step needs
  headers newlib does not have. The GLib main loop needs `pipe()` and friends, which newlib lacks: link the
  compatibility layer (`nexvyn_use_compat()`), otherwise the link fails with `undefined reference to pipe`. gettext is a
  pass-through stub (header only); translate with your own files.
- libarchive reads and writes archives in memory and through files. It cannot walk a directory tree (`fchdir`) and has
  no external program filters (`fork`, `exec`). Symlink entries must still be skipped when extracting to FAT.
- SQLite: no WAL (no shared memory on FAT), exclusive locking by default, no extension loading.
- OpenAL Soft takes its device from SDL2: call `SDL_Init(SDL_INIT_AUDIO)` first if your app does not do it already.
- The few missing POSIX calls the libraries reference are weak symbols in `sysroot/shims/`: the compatibility layer or
  your app may define real versions and those win.
- LGPL libraries (OpenAL Soft, libiconv, GLib) are static archives: an app that links them has to follow the LGPL, that
  is, give the user a way to relink (ship your object files or a linkable archive of the app) and the library source
  and licence. The kit archive has every licence file in `licenses/`; the manifest lists the source URL and hash.

`assemble.py --prefix DIR` still creates an empty overlay prefix for libraries you build yourself; pass it with
`build --sysroot DIR`.

POSIX / PC compatibility layer (`libnexvyn_compat`, optional, hooks into the runtime): `NATIVE_COMPAT.md`.

## Shared libraries (.nxvlib)

Static linking stays the default. A library many ports use (SDL2, a big runtime, a codec), or a plugin, can instead be
built once as a `.nxvlib` and loaded at run time with `nxn_lib_open` (`<nexvyn/nxn_lib.h>`) or `dlopen` (compat
layer). Start from the template: `python tools/nxv_native new mytool --template shared-lib`.

```cmake
nexvyn_add_lib(greet NAME greet VERSION 1.2.0 SOURCES lib/greet.c)   # -> build/greet.nxvlib
add_executable(mytool src/main.c)
nexvyn_export_symbols(mytool LIBS greet)                              # the app provides libc / libnx to it
nexvyn_add_nro(mytool ...)                                            # with NEXVYN_ABI on (libnexvyn_native)
```

```c
nxn_lib* lib;
if (nxn_lib_open("greet", "1.2", &lib) != NXN_OK) { nxn_log(NXN_LOG_ERROR, "%s", nxn_lib_error()); return; }
const char* (*hello)(void) = (const char* (*)(void))nxn_lib_sym(lib, "greet_hello");
```

- Building: `nexvyn_add_lib` compiles with `-fPIC` and links an AArch64 shared object with its imports left open
  (`-nostdlib`, `-z text`: text relocations are a link error, SysV hash). `nxv-native build` / `lib` then checks every
  `build/*.nxvlib` (`nxv-native check-lib FILE [--host app.elf]`): no text relocations, `thread_local` only in the kit's TLS model, an identity
  section, and every import exported by the app.
- Installed libraries: a package with `"type": "lib"` goes to `Libraries/`; with the setting `libs.sideBySide` several major
  versions of one library are installed side by side (`Libraries/<id>/<major>/`), an app's `needs` entry (`"id@6.1"`)
  picks the highest installed version of that major, and a version an installed app needs is never removed. Settings >
  Storage > Libraries shows what is installed, who uses it, and removes unused versions (`NXVAPP_FORMAT.md` 5b).
- One C library, one heap: a library takes `malloc`, `printf`, libstdc++ and libnx from the app that loads it.
  `nexvyn_export_symbols` links the app with `--export-dynamic` (its symbol table goes into the `.nro`, which grows
  with the number of global symbols) and pulls in every function the listed libraries import. Plugins unknown at build time can only
  use what the app exports; a missing one is a clean error that names it. Makefile projects:
  `nxv-native exports a.nxvlib -o imports.ld`, then link the app with `imports.ld -Wl,--export-dynamic
  -Wl,--hash-style=sysv`.
- The boundary is C only: `extern "C"` functions and plain data. No C++ classes or `thread_local` across it. Inside a
  library C++ works; in a window an exception may cross into the app when `native.windowedEh` is on (the library takes
  the app's C++ runtime), elsewhere build libraries with `-fno-exceptions`.
- Identity: `NXN_LIB_ABI_GEN` (raised by hand, in `nxn_lib.h`) and the library's semver, written into its `.nxvlib`
  section. `min_version "1.2"` accepts 1.2.0 up to any 1.x; another major, an older version or another ABI generation
  is refused with a message. The OS version and the build never enter it.
- Where it is looked up: an explicit path, or a bare name (`greet`, `libgreet.so`) as `<name>.nxvlib` next to the
  app's `.nro`, then in `<data>/lib/`. `nxv-native package` puts the `build/*.nxvlib` files next to the `.nro`.
- A library stays mapped until the app ends (`nxn_lib_close` only drops a reference), so function pointers into it
  stay valid; its destructors run at exit.
- Loading needs JIT code memory, like the OS's own modules: `NXN_CAP_SHARED_LIBS` in `nxn_caps_get`. In applet mode the
  error says to start Nexvyn OS through Atmosphère's homebrew loader (hold R while launching a game).
- The loader is the one Nexvyn OS uses for its modules (`sdk/native/loader/nxelf.c`), compiled into
  `libnexvyn_native`, so it works while Nexvyn OS is not in memory.
- Packages: `"type": "lib"` Store packages and `"needs"` in `app.json` are available (one version of each library; the App
  Market installs the libraries an app needs first, with one approval; a library in use is never removed). Packing and
  checking: `python tools/nxvapp_pack.py` (one tool for script, native and library packages, also checks the module
  ABI). An update keeps the previous version (System Settings > Apps) and copies the user's data first when `dataSchema`
  goes up (`docs/NXVAPP_FORMAT.md` section 2, 5). Side-by-side majors and a Libraries screen are planned; the field formats are fixed.

## Runtime providers (ABI v1)

A runtime provider is a library package that runs apps of one language. It is installed as a normal library
(`"type": "lib"`, App Market `"kind": "runtime"`) and describes itself in `app.json`:

```json
"provider": { "id": "nexvyn.runtime.lua", "kind": "runtime", "runtime": "lua", "abi": 1, "capabilities": ["script"] }
```

The Runtime Resolver reads only that identity; it never executes provider code to decide.
Rules:

- Runtime ids are canonical and never renamed: `lua`, `js`, `python`, `python3`, `squirrel`, `c`, `java`. Aliases are
  mapped once (`javascript` → `js`, `py` → `python`); an unknown name is `missing`, not guessed.
- One provider per runtime: the highest installed version serves it. An installed `kind: "runtime"` provider owns its
  runtime; the system never silently falls back to a different engine for that runtime. Removing the package brings the
  built-in engine back.
- `abi` must be `1` (this header). Another generation is `incompatible` with a clean, localizable reason
  (`comp.incompatible`); never loaded.
- `kind: "compat"` is a legacy compatibility framework (PocketPy 2 for `python`, TinyCC for `c`, miniJVM for `java`,
  Squirrel 3.2): it is a dependency of a runtime, never an engine, and it never replaces the resolver's choice.
- Built-in engines stay available, so the OS, Settings and Native apps open with no provider installed. The provider
  loader (`<package>/provider.nxvlib`) is behind the setting `runtime.providerLoader`,
  **off by default** until installed providers pass the equivalence tests against the built-in engines. While it is off
  an installed provider resolves as `unavailable` (`comp.unavailable`) with its name and path, exactly as before; it is
  never started by the wrong interpreter.
- C contract: `sdk/native/include/nexvyn/nxn_provider.h` (`NXN_PROVIDER_ABI_GEN 1`). Exported symbols:
  `nxn_provider_query`, `nxn_provider_create`, `nxn_provider_start`, `nxn_provider_stop`, `nxn_provider_destroy`.
  `query` writes `nxn_provider_info` (id, version, kind, runtime, capabilities) and must not allocate or start a thread;
  `create` receives the host table and a NUL-terminated UTF-8 JSON object of the app's manifest subset.
- Packaging/checking: `python tools/nxvapp_pack.py` validates the object (only for `lib`/`runtime`; a `runtime`
  package without it is refused). Layout, entry points and failure rules are documented on the header.

### Provider ABI v1.1: drawing surface (add-only)

`NXN_PROVIDER_ABI_GEN` stays `1`. A provider that shows something in its app window also exports two optional symbols
(`NXN_PROVIDER_ABI_MINOR 1`):

| Symbol | Type | When |
| --- | --- | --- |
| `nxn_provider_surface` | `nxn_provider_surface_fn` (optional) | asks for the surface size inside the available window area |
| `nxn_provider_draw` | `nxn_provider_draw_fn` | one frame into the host-owned `nxn_provider_surface` |

- The host owns the pixels: one RGBA8 CPU surface per instance (`width`, `height`, `stride`, `frame`, `time`), valid only
  during the call. Sizes are clamped to `NXN_PROVIDER_SURFACE_MAX` (2048).
- The provider never calls a graphics API and never waits for the UI thread from these calls: `draw` may run on a host
  worker thread. The host holds no lock during the provider call and publishes the finished frame with a pointer swap
  (`provider_loader::SurfaceBridge`); the UI thread only try-locks, so it never waits for a provider frame. This build
  calls `draw` on the UI thread inside the crash guard (a fault there is isolated; on a worker it would not be).
- `draw` returns `NXN_OK` for a new frame and `NXN_ERR_BUSY` when nothing changed. Any other result, or a crash, stops
  drawing for that instance and shows the clean problem screen.
- A v1 provider (five symbols only) keeps loading and running; its window shows the provider identity.
- Tests: `n2e_provider_v1_and_v11_both_load`, `n2e_provider_surface_bridge_worker_producer_never_blocks_ui`.

### Loading, safe mode and Settings

- At each launch of a script app the OS asks `provider_loader::plan` (loader on: `compmgr::resolveSafe`). A provider
  package fails the health check when its `provider.nxvlib` is missing or empty, or when an earlier start of that exact
  version failed (setting `runtime.providerFailed`, keyed `<id>@<version>`). A failing package is skipped: the next older
  healthy version runs, and when none is left the built-in engine runs the app in safe mode (`comp.safemode`). The user
  is told once per version (setting `runtime.safeModeSeen`). The OS, the desktop and other runtimes are never affected.
- The library file is read and checked on the background worker; the main thread maps and binds it and calls
  `create` / `start` inside the crash guard. Any failure records the version and shows the problem screen.
- Settings > Runtimes & Frameworks lists the built-in engines and every installed runtime / compat package with version,
  ABI compatibility and state (active, standby, safe mode, damaged, incompatible, off). It can switch the loader, remove
  a version, roll back (remove the newest when an older version is installed), retry a version whose start failed, and
  open the App Market's Runtimes & Libraries section, which downloads and installs packages. The list is read on a
  worker; the pane needs no network.

## Target platform limits

| Not available | Workaround |
| --- | --- |
| `fork`, `exec`, `system`, `popen` | Call the code in-process (turn the helper into a function), or run it in a thread. |
| Several processes | One process, several threads (`pthread` / `std::thread` work). Replace process pools with thread pools. |
| `pty`, `openpty` | Build a console in the app (libnx `consoleInit`, or draw text with SDL2). |
| Real symlinks (FAT) | Copy the file, or keep a path table in the app. Archive extractors must skip symlink entries. |
| `mmap` of files | Read the file into memory. |
| `dlopen` of a Linux `.so` | Rebuild the plugin as a `.nxvlib` ("Shared libraries" above); `dlopen` then loads it. |
| `ucontext` (`makecontext`) | Use the kit's coroutine layer once the compatibility layer lands, or a small context-switch routine in assembly. |
| `SIGSEGV` handlers | Not available in this kit version; do bounds checks in software. |
| Case-sensitive file names | Use `fopen_ci()` (in the `decomp-skeleton` template) for PC data. |
| Writing next to the program | Write under `sdmc:/` (use the data directory associated with your app). |
| Fixed fullscreen mode switching | The display is 1280x720 handheld, 1920x1080 docked; query it at start-up. |

The checks that are not enforced at build time yet are listed in the native platform plan (stage 3.5).

## Licences

Third-party code in the kit: Dear ImGui (MIT, `sysroot/vendor/imgui/LICENSE.txt`). Libraries from the recipes keep their
own licences; LGPL ones (OpenAL, libiconv, glib) need the usual care when linked statically.
