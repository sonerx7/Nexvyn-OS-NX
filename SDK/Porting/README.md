# Nexvyn OS Porting & Decompilation Hub (Native SDK 1.2)

Everything developers and AI assistants need to port existing C/C++ games, engines, decompilations, static recompilations, and emulators to **Nexvyn OS N2** as native `.nxvmod` applications (`"runtime": "native"`, Frozen ABI v1).

---

## 1. Choosing Your Porting Pathway

| Pathway | Typical Projects | Key Nexvyn OS Stack |
|---|---|---|
| **Open-Source SDL2 / OpenGL Ports** | `ClassiCube`, `Yamagi Quake II`, `DevilutionX`, `OpenTTD`, `fheroes2`, `Augustus`, `ScummVM`, `OpenRCT2` | `nxn_display_*`, `gladLoadGLLoader(nxn_display_proc)`, bundled SDL2 + POSIX compat (`nexvyn-compat.cmake`) |
| **Decompilation & Fast3D/GL Ports** | C/C++ decompilations (e.g., `Ship of Harkinian`, `sm64ex`) | `nxn_display_open` + OpenGL 4.3 Core / GLES, `nxn_input_*` controller mapping, external user-asset loader |
| **Static Recompilation / Win32 Host-Shim** | Statically recompiled legacy PC executables | Thin Win32 / DirectDraw / DirectSound host shim on top of `nxn_*` ([Large Game Porting Guide](../Guides/PORTING_LARGE_GAMES.md)) |
| **Emulators & JIT Engines** | Console / PC emulators using dynamic recompilation | `NXN_CAP_JIT` (`nxn_jit_*` W^X memory), `.nxvlib` shared cores (`NXN_CAP_SHARED_LIBS`) |

---

## 2. Quick Start: Porting an Existing CMake / C++ Project

1. **Scaffold the manifest & layout** using Smart Creator:
   ```bash
   python SDK/Tools/nxv/nxv.py create "My Port" --profile port --runtime native
   ```
2. **Integrate the Native Kit & POSIX Compat in `CMakeLists.txt`:**
   - Include `SDK/Languages/c/native-kit/sdk/native/compat/cmake/nexvyn-compat.cmake` (or link `compat.mk`).
   - Load OpenGL via `gladLoadGLLoader((GLADloadproc)nxn_display_proc)` — never link `libEGL` or `libGLESv2` directly in a windowed `.nxvmod`.
   - Use `nxn_run(argc, argv, app_main, NULL)` as the entry point.
3. **Configure `app.json` for Heavy Ports:**
   ```json
   {
     "id": "com.yourname.myport",
     "name": {"en": "My Port"},
     "description": {"en": "Native port for Nexvyn OS"},
     "version": "1.0.0",
     "runtime": "native",
     "mode": "window",
     "main": "com.yourname.myport.nxvmod",
     "minSdk": "1.13",
     "targetSdk": "2.0",
     "minNative": "1.2",
     "loadingHint": true,
     "memory": 256,
     "gamepad": true,
     "category": "games",
     "window": {"width": 1280, "height": 720, "resizable": true},
     "permissions": ["files"]
   }
   ```
   - `"loadingHint": true` extends the startup watchdog from 5 s to 120 s while large assets unpack or shaders compile.
   - `"memory"` declares the estimated RAM requirement in MB so the OS warns the user cleanly if free memory is too low.

---

## 3. Core Rules for Clean Ports

- **Keep the Window Alive During Long Loads:** Call `nxn_should_quit()` at least every 250 ms inside loading loops, asset unpackers, and shader warmups, and exit cleanly within 5 s if it returns `true`.
- **Disable Internal Vsync:** Call `SDL_GL_SetSwapInterval(0)` inside the port. Nexvyn OS paces window frames at the compositor level; waiting on Vsync inside the game thread cuts framerate in half.
- **User-Supplied Game Data (Never Bundle Copyrighted Assets):** For ports or decompilations that require original game files (`.wad`, `.mpq`, `.otr`, `.z64`, `.dat`), never include proprietary assets in the `.nxvapp`. Prompt the user once with `nxn_choose_folder` (or `ui.chooseFolder`) and remember the granted path across launches.
- **Handle Window Resize & Dock/Handheld Switching:** Listen for `NXN_EVENT_RESIZE`, call `nxn_display_resize(disp, ev.width, ev.height)`, and update `glViewport`.
- **Avoid Frame-Copy Bottlenecks:** For 8-bit/16-bit software-rendered ports, convert palettes via a 256-entry lookup table and upload only dirty rectangles when possible.
- **Maximum Input Support (Gamepad, Multi-Touch Pinch-Zoom, Keyboard):**
  - Always set `"minNative": "1.2"` so 16-finger multi-touch is enabled.
  - **SDL2 Ports:** `sdl2-nexvyn` automatically translates **two-finger pinch-to-zoom** to `SDL_MOUSEWHEEL` (or `Ctrl +/-` via `SDL_SetHint("NEXVYN_PINCH_MODE", "ctrl_pm")`), **two-finger tap** and **long-press** to `SDL_BUTTON_RIGHT`, **two-finger pan** to scroll wheel, and supports `SDL_SetHint("NEXVYN_GAMEPAD_MOUSE", "1")` + `SDL_JoystickRumble`. Call `SDL_StopTextInput()` unless a text box is focused.
  - **Custom / Non-SDL2 / Recompiled Ports:** Use the header-only `<nexvyn/nxn_port_input.h>` (`NXN_PI_PROFILE_RTS`, `NXN_PI_PROFILE_CRPG`, `NXN_PI_PROFILE_FPS`, `NXN_PI_PROFILE_GAMEPAD`) for unified pinch-zoom, multi-touch gestures, virtual stick cursor, custom button bindings, USB/BT keyboard, and OSK toggle.

---

## 4. Essential Porting References

- **[Porting a Large PC Game or Engine](../Guides/PORTING_LARGE_GAMES.md)** — Static recompilation architecture, Win32/DirectDraw shims, memory arena, dirty-rect presentation.
- **[Native SDK Guide](../Guides/NATIVE_GUIDE.md)** — `.nxvmod` lifecycle, display, events, audio, input, and storage.
- **[Native Kit Reference](../Guides/NATIVE_KIT.md)** — `nxv_native` CLI, CMake toolchain, headers (`nexvyn/nexvyn_native.h`, `nexvyn/nxn_nxui.h`, `nexvyn/nxn_gl.h`).
- **[POSIX Compatibility Layer](../Guides/NATIVE_COMPAT.md)** — `dlfcn.h`, `sys/mman.h`, `ucontext.h`, file mapping, and threading shims.
- **[Native Modules & Shared Libraries](../Guides/NATIVE_MODULES.md)** — Building `.nxvlib` cores and `NXN_CAP_JIT`.
- **[AI Native Pack](../AI/languages/native.md)** — Zero-hallucination context pack for AI assistants writing Native C/C++ ports.
- **[Porting Pre-Release Checklist](CHECKLIST.md)** — Mandatory checks before shipping a port to the App Store.
