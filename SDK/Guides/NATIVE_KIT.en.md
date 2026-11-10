# Nexvyn Native Kit

The kit builds C and C++ apps that run inside Nexvyn OS: the app is a `.nxvmod` that Nexvyn OS loads into its own
process, in a window or full screen (`app.json` `"mode": "window"` or `"fullscreen"`; section "Apps in Nexvyn OS"). Use
it for games, emulators, engines and ports. Scripted apps (Lua, JavaScript, Python, C via TinyCC) do not need it.

Status: the toolchain, sysroot scripts, templates and CLI work today. The Nexvyn ABI (`#include <nexvyn/nexvyn_native.h>`,
`-lnexvyn_native`) is linked by default. SDL2 runs inside Nexvyn OS windows (and full screen) through the kit's own
SDL2 driver: section "SDL2 in a window". Without SDL, use the `nxn_*` API directly (`examples/hello_gl`,
`examples/showcase`).

**ABI v1 is frozen (2026-11-09).** The `nxn_*` functions, the `ngfx_*` API, every struct layout, constant, capability bit,
error code, host import name and the module identity are recorded in `toolchain/nxn_abi_v1.json`. The rule from now on is
add-only: nothing in that file is ever removed or changed; new functions, constants and struct fields (appended at the end,
never into padding) may come. An app built with any earlier kit keeps loading; a module built with the 1.0 kit is part of
every test run. When your app calls a function added in a later Native SDK version, raise `"minNative"` in `app.json` to
that version: an older Nexvyn OS refuses a module that imports an `nxn_*` name it does not have, with a clear message. Use
`NXN_STRUCT_INIT(type)` for every struct you pass, test capability bits (`NXN_CAP_*`, `uint64_t` masks) before optional
calls, and treat any negative result you do not know as a plain failure.

## Install

1. Install devkitPro with the Switch packages (`switch-dev`, `switch-sdl2`, `switch-mesa`, ...). The tested versions are
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
- `python tools/nxv.py pack --delta old.nxvapp new.nxvapp` makes a delta package (only the files that changed; the new
  package packed with `--stamp`) for the App Market's optional delta updates (`NXVAPP_FORMAT.en.md` 5c).
- `run` only copies files. It never starts an emulator or Nexvyn; you do that. Default SD root:
  `%APPDATA%/the emulator/sdcard`.
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

What changes for the app (details: `NATIVE_SDK_DESIGN.md` 3.2):

| Area | In a window |
|---|---|
| Imports | only Nexvyn OS's host import set: `nxn_*`, the C library (newlib libc / libm, POSIX and pthreads of libsysbase) and a small libnx subset (threads, mutexes, sleep). Anything else (SDL, EGL, libnx services) is refused at start with "missing symbol". C++ (libstdc++, exceptions, RTTI) is linked into the module; `thread_local` is not supported. |
| GL | load GL through `nxn_display_proc` (glad: `gladLoadGLLoader((GLADloadproc)nxn_display_proc)`; `eglGetProcAddress` answers the same). Framebuffer 0 is the window's frame. Do not link `libGLESv2` / `libEGL` directly. |
| Display | `nxn_display_open(NULL, ...)` = the window's content size; `NXN_EVENT_RESIZE` when the window changes, follow it with `nxn_display_resize`. `nxn_display_swap` paces to Nexvyn OS's frames (a minimized window slows the app down). |
| Input | only while the window has focus (`NXN_EVENT_FOCUS`); touch in surface pixels. HOME, L + R (hold) and + with - stay with Nexvyn OS. |
| Closing | the close button sends `NXN_EVENT_QUIT` and makes `nxn_should_quit()` true; return from your entry within 5 seconds or the app is stopped. |
| Process calls | `exit` / `abort` / a failed `assert` end only the app; `atexit` handlers run when the app ends; `chdir` is refused. |
| POSIX and sockets | link the compatibility layer (`nexvyn_use_compat()`, `NATIVE_COMPAT.en.md` "In a window"): pipes, `poll`, `mmap`, signals, an own environment and working directory, all released when the app ends. BSD sockets need `"network"` in `app.json` `"permissions"`; without it every call fails with `EACCES`. |
| Shared libraries | `nxn_lib_open` / `dlopen` load the package's `.nxvlib` files with setting `native.windowedLibs` (`NXN_CAP_SHARED_LIBS`; off: `NXN_ERR_UNSUPPORTED`). `thread_local` (`native.windowedTls`, `NXN_CAP_TLS`) and C++ exceptions (`native.windowedEh`, `NXN_CAP_CXX_EXCEPTIONS`) work in the module and its libraries when those settings are on (default on for apps with `"minNative": "1.1"` or later, off for 1.0 apps; a value set explicitly holds for every app; verified in the emulator only, not yet on a console); the kit builds every object with `-mtls-dialect=trad -ftls-model=global-dynamic` and links `crtend.o` last (Makefile projects do the same). `NATIVE_SDK_DESIGN.md` 3.2.10. |
| JIT and fastmem | `nxn_jit_*` (code memory, rw + rx views; setting `native.windowedJit`, `NXN_CAP_JIT`), `nxn_fault_handler_set` (data aborts to the app first; `native.windowedFaultHandler`, `NXN_CAP_FAULT_HANDLER`), `nxn_mem_guard` (guard pages in the app's heap; `native.windowedGuardPages`, `NXN_CAP_GUARD_PAGES`). All stay off by default until a console has verified them (`NXN_ERR_UNSUPPORTED`); keep an interpreter / slow path. x17 is not restored after a handled fault. `NATIVE_SDK_DESIGN.md` 3.2.11. |
| Memory | the app's `malloc` / `free` / `realloc` / `memalign` / `strdup` come from the app's own heap, not Nexvyn OS's: when the app ends clean, the whole heap goes back in one step, so a leak never outlives the app. There is no fixed limit: the heap grows while the system has memory, and `malloc` returns `NULL` (`errno` = `ENOMEM`) when only the reserve Nexvyn OS needs to keep running is left (the `nxn_*` calls then answer `NXN_ERR_NO_MEMORY`). Optional `"memory"` in `app.json` (MB, 1 to 16384) is the heap the app wants: if that much is not free at the start, Nexvyn OS says so ("needs X MB, Y MB are free; close some open apps") and does not open the app; if it is, the memory is set aside for the app. Memory the C library allocates itself (`fopen`, `asprintf` ...) is not part of the app's heap. |
| Crashes | a fault in any thread of the app closes its window ("<app> stopped"), writes the crash line to its log and a report to `System/Logs/Crashes`; Nexvyn OS keeps running. The app still shares Nexvyn OS's process: a wild write can damage it, and there is no memory isolation (`NATIVE_SDK_DESIGN.md` 3.2.7). |

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
normals; the Tegra X1 decodes them natively). `python tools/nxv_asset check FILE.nxsc|FILE.nxtx...` verifies baked files.
Needs Python 3 with numpy, Pillow and etcpak; FBX also needs a host C compiler (gcc, clang or MSVC), GLB / glTF do not. The
tool never crashes on a damaged file: it prints one `nxv-asset: error:` line, exits with 1 and leaves no half-written output
(`tools/tests/nxv_asset_test.py` feeds it truncated, bit-flipped and garbage files). The file layout is in the header comment of
`tools/nxv_asset/__main__.py`; the BC texture path itself is verified on a console later (the emulator only shows that it loads).

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

## SDL2 in a window

Most ports and games are SDL2 programs. Inside Nexvyn OS an SDL2 program needs no changes: the kit ships an SDL2 (the
devkitPro Switch fork of SDL 2.28 with the Nexvyn OS drivers added, `sdk/native/sdl2/`) that talks to the window through
`nxn_*` instead of libnx, EGL and audren. It links into the app statically, so the module imports nothing outside the host
import set. `nxv-native build` picks it up for every project that includes SDL (`pkg_check_modules(SDL2 ... sdl2)`);
build it once with `python sdk/native/sysroot/build.py sdl2-nexvyn` (it goes to `<sysroot>/windowed`, which only
window builds look at: a `--exclusive` build keeps the portlibs SDL2). The same source builds in both ways; the templates
`sdl2` and `gl` and the canary `imgui` (`python tools/canary.py build-win imgui`) do. `examples/sdl2_check` is the
self-test: it exercises every part below and writes `sdl2_check_report.txt`.

| SDL2 part | What happens in a Nexvyn OS window |
| --- | --- |
| Video | one window = the content area of the Nexvyn OS window (or full screen: the same build serves both, the user can switch). `SDL_WINDOW_FULLSCREEN` / `RESIZABLE` windows follow the content size (`SDL_WINDOWEVENT_SIZE_CHANGED` when it changes); a fixed-size window keeps its size and Nexvyn OS scales it. Driver name `nexvyn`. |
| GL | `SDL_GL_CreateContext` makes the app's `nxn_display` context: OpenGL ES (default 2.0, asks for 3.0 / 3.1 / 3.2 work) or core profile 4.3. No compatibility profile, one context. `SDL_GL_SetSwapInterval(0)` / `(-1)` / `(1)` succeed; a window paces to the OS frame (vsync) and does not wait only when the developer setting `perf.uncapped` is on, so `SDL_GL_GetSwapInterval()` answers 1 (the app cannot switch the wait off by itself). `SDL_GL_GetAttribute(SDL_GL_DEPTH_SIZE / STENCIL_SIZE)` answer the real buffer, 24 and 8. `SDL_GetCPUCount()` is the core count of the process mask (3 on a console). `SDL_Renderer` (OpenGL ES 2) works. `glDrawArrays`-style direct calls link too: `libnexvyn_window.a` carries every ES 3.2 entry point, and every OpenGL core 1.0 - 4.3 entry point ES lacks (`glPolygonMode`, `glClearDepth`, `glDepthRange`, `glGetTexImage` ...; 184 of them, `nxwin_glcore.c`, generated by `tools/gen_gles_shim.py`): a desktop-GL port links with no wrapper. They resolve through `nxn_display_proc` like the rest; a call the driver does not have does nothing (check `glGetString(GL_VERSION)` and extensions as on a PC). |
| Audio | any format and rate (SDL converts); a push stream in Nexvyn OS's mixer with at most two SDL buffers queued (`SDL_AudioSpec.samples`), measured 42.7 ms for 1024 samples at 48 kHz. No capture. |
| Controller | one pad, named `Switch Controller`, 16 buttons (the order of `NXN_BTN_*`) and 4 axes; the game controller mapping is built in. Empty while the window has no focus. |
| Touch, mouse, keyboard | touch fingers (`SDL_FINGERDOWN` ...; SDL also makes mouse events from them), the USB mouse / Nexvyn OS pointer (position, buttons, wheel, relative mode), the USB keyboard (HID usage = SDL scancode, modifiers, `SDL_TEXTINPUT` after `SDL_StartTextInput`). |
| Lifecycle | `SDL_QUIT` when the window closes; `SDL_APP_WILLENTERBACKGROUND` ... `SDL_APP_DIDENTERFOREGROUND` on sleep / HOME menu. |
| Files | `SDL_GetBasePath` = the package folder (read-only), `SDL_GetPrefPath` = the app's data folder. |
| Not there | power info, haptics, sensors, `SDL_LoadObject`, Vulkan, a second window. SDL threads keep the priority Nexvyn OS gave them (`SDL_SetThreadPriority` does nothing). |

The SDL2 source is zlib licensed; the added drivers are marked as altered source (`sdk/native/sdl2/overlay`).

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

For apps that should look like part of Nexvyn OS (tools, editors, front ends). **Games do not use this**: a game builds its own look and never copies the OS menu; there is no ready-made menu template.

- `nxn_ui_tokens_get`: one sized struct with the colours (background, surface, text, secondary text, accent, error, warning, success, border...), sizes (corner radius, spacing steps, row / control height, text sizes, text scale) and `revision`. The values come from the OS's own palette, not from copies, and follow light / dark, accent and high contrast.
- `NXN_EVENT_MENU` (`nxn_menu.h`, `NXN_CAP_MENU`, setting `native.windowMenu`, default on for apps with `"minNative": "1.1"` or later, `false` turns it off; not verified on a console): the user picked an item of the app's window menu (`nxn_menu_set`); `item_id` is its id. Only apps with `"minNative": "1.1"` get it. Not for games. `NATIVE_SDK_DESIGN.md` 3.2.12.
- Live resize (setting `native.liveResize`, default off; not verified on a console): while the user drags a window edge the app gets `NXN_EVENT_RESIZE` about every 0.12 s with the new content size, not only after release. Apps with `"minNative": "1.1"` or later get it when the setting is on; an older app only with `"liveResize": true` in `app.json` (`false` keeps the stretch-until-release behaviour). Handle it like any resize: `nxn_display_resize`.
- `NXN_EVENT_THEME`: the look changed; read the tokens again. Only apps with `"minNative": "1.1"` get it; older apps can compare `revision` once a frame.
- `nxn_ui_font_get` gives the system font bytes (for example ImGui `AddFontFromMemoryTTF`, `FontDataOwnedByAtlas = false`), `nxn_ui_icon_code("folder")` the code point in the `NXN_UI_FONT_ICONS` font.
- **Text and fonts.** ImGui loads Latin-1 only unless it is given glyph ranges, so Turkish `ı ğ ş İ`, Cyrillic, Greek or Japanese text would show as `?`. `#include <nexvyn/nxn_imgui.h>` (header only, after `imgui.h`) and call `nxn_imgui_add_font(io.Fonts, NXN_UI_FONT_SANS, px, 0, icon_ranges)`: it adds the system font with the ranges the app's language needs (`nxn_info_string(NXN_INFO_LANGUAGE)`): Latin-1 and Latin Extended-A always (en, tr, de, es, fr), Latin Extended-B for `vi`, Greek for `el`, Cyrillic for `ru uk bg sr`; the flag `NXN_IMGUI_ALL_SCRIPTS` adds all of them for text the app did not translate (file names). The atlas stays small because only those ranges are loaded. Icons are merged into the same font when `icon_ranges` is given. The system font is Inter (Latin, Greek, Cyrillic); the Han / Kana / Hangul font comes as `NXN_UI_FONT_CJK` (`NXN_CAP_UI_FONT_CJK`, bit 32; the console's shared font, else a font pack on the SD card, cut to the face of the app's language) and the same helper merges it for `ja`, `ko` and `zh` with no change in the app: a compact set of common characters (about 2400-3000: ImGui's Japanese and Simplified Chinese tables, the 2350 syllables of KS X 1001 for Korean), not the whole font. Each font that gets it grows the atlas by about 1 MB per 20 px, so pass `NXN_IMGUI_NO_CJK` for digit / monospace fonts; fonts above 30 px skip it unless `NXN_IMGUI_CJK_LARGE`. A system without the font (older Nexvyn OS, no font installed) draws Latin only and nothing fails. The `app` template, the Showcase and the Tour use the helper; use it in your own ImGui apps and keep texts in `lang/*.json`.
- **Controller and touch in ImGui.** ImGui moves its focus with a pad only when the app sets `ImGuiConfigFlags_NavEnableGamepad` and the backend sets `ImGuiBackendFlags_HasGamepad`; the OpenGL3 backend never does, so a Joy-Con did nothing. Call `nxn_imgui_enable_gamepad(io)` (`nxn_imgui.h`, also done by `nxn_imgui_add_font`) after `ImGui::CreateContext()` and feed the pad with `io.AddKeyEvent(ImGuiKey_Gamepad...)`. In a window `nxn_input_touch` already gives pixels of the app's surface (the same space as `DisplaySize`): pass them to `io.AddMousePosEvent` unchanged. Only a full-screen build gets a 1280x720 space and scales (`#ifndef NEXVYN_WINDOWED`).
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

- **Faster by default.** The GPU lock is held only while drawing, shaders compile without the lock, a single full-screen window draws straight to the screen, and an unchanged frame is not presented again. Measured: a 3D scene demo 10 to 59 fps, an OpenGL showcase 10-16 to 60 fps, a GBA emulator at full speed, the frame handoff from app to system 15-24 ms to 0.1 ms, scene loading about 30 s to 0.6 s. Every one of these can be turned off with its setting (`native.gpuLazyLock`, `native.gpuUnlockedCompile`, `native.fullscreenDirect`, `compose.idleSkip`, `gfx.ngfxOpaqueNoDiscard`: `false`).
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

The guide `docs/NATIVE_GUIDE.en.md` walks through install, build, package, run and diagnosis. Except `app`, `game`, `port` and `shared-lib`, each builds to a `.nro` without the Nexvyn ABI. Look for `#ifdef NEXVYN_ABI` in `src/`: that is where the ABI calls
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
python sdk/native/sysroot/build.py test              # builds tests/sysroot_test (the proof .nro)
python sdk/native/sysroot/assemble.py --prefix DIR --archive nexvyn-native-sysroot-1.0.0.tar.zst
```

How the builder works: sources are downloaded once into `build/native-sysroot-cache/dl`, checked against the sha256 in
`recipes.json`, unpacked and built in the same cache folder (`src/`, `bld/`, one log per library in `logs/`). A restart
or a second run skips what is finished (a stamp per library in the prefix); change a recipe, a patch or a shim and only
that library rebuilds (`--force` rebuilds one anyway). The prefix has `include/`, `lib/`, `lib/pkgconfig/` (relocatable:
the `.pc` files use `${pcfiledir}`) and the CMake config files the libraries ship. The archive has normalised tar
metadata, `manifest.json` (library, version, licence, source URL and sha256, file sizes) and `licenses/<library>/`.
None of this is committed; the archive (about 4.5 MB, debug sections stripped) is a download, built or fetched on demand.

The builder needs devkitPro with its msys2 (cmake, ninja, make, zstd, pkg-config), Python 3.9 or newer and `patch`
(Windows: it comes with Git for Windows). `--setup-venv` puts meson into the cache folder; nothing else on the machine
is touched. Use the prefix with `NEXVYN_SYSROOT=DIR` (CMake kit) or `-I DIR/include -L DIR/lib` (plain make).

### Proof: `sysroot/tests/sysroot_test`

One `.nro` calls every library once: zstd and lz4 round trips, an in-memory SQLite query, a zip and a tar.zst written
and read back through libarchive, an OpenAL device and context on the SDL2 backend (`ALSOFT_DRIVERS=sdl2`, so a silent
fallback to the null backend fails the test), a UTF-8 to UTF-16LE and a latin1 to UTF-8 iconv conversion, a pixman
rectangle fill, and a GLib hash table, string and main-loop iteration. It writes `sdmc:/sysroot_test_results.txt` (one
line per library, then `RESULT pass=N fail=M`) and returns M. Last run in the emulator: pass=8, fail=0.

### Things to know

- GLib has no gio: sockets, D-Bus, subprocesses and inotify cannot work on the Switch, and gio's configure step needs
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

POSIX / PC compatibility layer (`libnexvyn_compat`, optional, hooks into the runtime): `NATIVE_COMPAT.en.md`.

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
  Storage > Libraries shows what is installed, who uses it, and removes unused versions (`NXVAPP_FORMAT.en.md` 5b).
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
  checking: `python tools/nxv.py pack` / `check` (one tool for script, native and library packages, also checks the module
  ABI). An update keeps the previous version (System Settings > Apps) and copies the user's data first when `dataVersion`
  goes up (`docs/NXVAPP_FORMAT.en.md` section 2, 5). Side-by-side majors and a Libraries screen are planned
  (`NATIVE_SDK_DESIGN.md`); the field formats are fixed.

## Canary projects

Four real open-source programs the kit did not write, compiled with the kit and launched, never shipped or ported. They
prove the kit builds general C/C++ code; one broken canary blocks a release. This is a local pre-release gate: CI does
not run it, because it needs the sysroot (about 15 minutes to build from scratch) and an emulator.

| Canary | Upstream | What it proves | Last run in the emulator |
| --- | --- | --- | --- |
| `glib` | GLib 2.78.6 unit tests (data structures, strings, threads, main loop) | sysroot GLib, compat `pipe`/`poll`, threads | 333 cases ok, 8 skipped by name, 19 s |
| `imgui` | Dear ImGui 1.91.5 SDL2 + OpenGL3 example (one small patch) | C++ build, SDL2 window, GLES3 context, vendored ImGui; also as a Nexvyn OS window (`build-win`, window and full screen) | 120 frames, 1440 vertices, 12 s (window: 120 frames, 1432 vertices) |
| `minicoro` | minicoro 0.1.3 test programs on the ucontext backend | `makecontext`/`swapcontext`, `thread_local`, pthreads | 4 programs ok, 7 s |
| `qemu` | QEMU 9.2.0, `aarch64-softmmu` | feasibility note only: configure against the sysroot, blockers listed | not a gate |

```
python tools/canary.py --list                  # recipes and build state
python tools/canary.py build [name ...]        # download (sha256 checked), patch, build -> build/canary/<name>.nro
python tools/canary.py run [name ...]          # optional: the emulator, one canary at a time, reads sdmc:/canary/<name>.txt
python tools/canary.py check                   # recipe sanity only, no toolchain needed
```

Each program writes one line, `PASS <detail>` or `FAIL <detail>`, to `sdmc:/canary/<name>.txt` (and its output to
`<name>.log`); the file starts as `FAIL did not finish`, so a crash cannot pass. Sources are downloaded into
`build/canary-cache` (ignored by version control, never copied into the repository). A patch is kept only where the
upstream has no headless mode (`imgui`); each canary folder in `sdk/native/canary/` has a `README.md` that lists every
change and every skipped case with the evidence. `build` needs the sysroot (`build/native-sysroot`, unpacked from the
archive when missing) and builds the kit libraries when they are missing. A restart loses nothing: finished canaries are
skipped.

## What is not possible on the Switch

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
| Writing next to the program | Write under `sdmc:/` (for example `sdmc:/switch/<app>/`). |
| Fixed fullscreen mode switching | The display is 1280x720 handheld, 1920x1080 docked; query it at start-up. |

The checks that are not enforced at build time yet are listed in the native platform plan (stage 3.5).

## Licences

Third-party code in the kit: Dear ImGui (MIT, `sysroot/vendor/imgui/LICENSE.txt`). Libraries from the recipes keep their
own licences; LGPL ones (OpenAL, libiconv, glib) need the usual care when linked statically.
