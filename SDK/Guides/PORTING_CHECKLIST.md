# Porting checklist (Nexvyn OS 1.4.0)

Use this page to port an SDL2, GL or Vulkan game or an emulator to a native Nexvyn OS app, or to write a native app from
scratch. Details for every item are in `NATIVE_GUIDE.md` (first steps) and `NATIVE_KIT.md` (every header and command).
Do the items in order. Report only what you really tested.

## 1. Before you start

- [ ] The source is allowed: a licence that lets you distribute it, no game data or firmware in the package, sources pinned
      to a tag and commit (`nxv_native new <name> --template port`).
- [ ] Choose the path: SDL2 (best for most ports; the kit ships an SDL2 for windows), GL through `nxn_display`, NexGFX native,
      or Vulkan (opt-in, section 6). deko3d is not a path for existing GL ports.
- [ ] Not possible in a window: `fork`, `exec`, `system`, `popen`, a second SDL window, Linux `.so` files, POSIX `PROT_EXEC`
      (use `nxn_jit_*` for code memory, see section 5).

## 2. Build

- [ ] `python tools/nxv_native doctor` shows no `MISSING` line.
- [ ] `python tools/nxv_native build <project> --sysroot <sysroot>`; build the SDL2 once with
      `python sdk/native/sysroot/build.py sdl2-nexvyn`. Libraries go through the sysroot recipes.
- [ ] `build` runs the load check (`check-win`): every import must be offered by the host. Remove or replace what it lists.
- [ ] Keep the build folder of every release (debug symbols and build-id) so `nxv_native symbolize <report>` can read crash
      reports.
- [ ] `app.json`: id, name, author, category, `"runtime": "native"`, `"mode"` (`window` or `fullscreen`), `"permissions"`
      (only what the port needs), `"minNative"` and `"minSdk"` (the packer sets sensible values).
- [ ] Texts in all eight required `lang/*.json` dictionaries (en, tr, de, es, fr, ja, ko, zh) for a Store submission.

## 3. Input

- [ ] Every action reachable with the pad alone (the console is mostly used handheld or docked). Use
      `nxn_input_poll` and `NXN_BTN_*`, or the SDL2 controller.
- [ ] Mouse- and keyboard-driven engines (strategy, RPG, shooters): use `<nexvyn/nxn_port_input.h>` with a profile
      (`NXN_PI_PROFILE_RTS`, `_CRPG`, `_FPS`, `_GAMEPAD`) and read one stream with `nxn_pi_poll_event`.
- [ ] Touch: map pinch (zoom), two-finger pan (scroll), two-finger rotate (`NXN_PI_EV_ROTATE`), two-finger tap (right click),
      double tap (`NXN_PI_EV_DOUBLE_TAP`) and long press to engine actions; or read raw fingers with `nxn_input_touch`.
- [ ] Text entry works: `NXN_PI_EV_TEXT` or `SDL_TEXTINPUT` after `SDL_StartTextInput`; the on-screen keyboard opens from the
      helper's `NXN_PI_BIND_TOGGLE_OSK` binding.
- [ ] The user can leave a fullscreen app by holding the minus button for one second; do not bind that.
- [ ] Rumble, if used, goes through `nxn_rumble`.

## 4. Memory and threads

- [ ] Read `nxn_memory_budget_get` at start (check `NXN_CAP_MEMORY_BUDGET`) and pick texture and cache sizes from
      `available_bytes`; `nxn_memory_budget_request` only checks, it never reserves. Handle `malloc` failure.
- [ ] The app shares memory with Nexvyn OS (no isolation). Open and close the app ten times: memory stays flat.
- [ ] Workers: call `nxn_thread_hint_request(2, NXN_THREAD_HINT_THROUGHPUT, &got)` before starting them. Treat 0 cores as
      "one worker". Core 0 and 3 are never granted.
- [ ] `thread_local` and C++ exceptions need `"minNative": "1.1"` or later (settings `native.windowedTls`,
      `native.windowedEh`); check `NXN_CAP_TLS` and `NXN_CAP_CXX_EXCEPTIONS`.
- [ ] Big saves: use `nxn_fs_*` folders; the system keeps saves safe from truncated copies, but do your own atomic writes
      (write a temp file, then rename).

## 5. Fullscreen and windows

- [ ] Decide `"mode": "fullscreen"` for games. Handle resize, focus loss, suspend and `SDL_QUIT` (or `NXN_EVENT_*`).
- [ ] Set `"fullscreenPause": true` in `app.json` for a fullscreen port that needs free memory: while it is fullscreen and
      focused the shell pauses desktop composition and frees its caches (about 18 MiB measured in the emulator).
- [ ] Recompilers (emulators): `NXN_CAP_JIT` and setting `native.windowedJit` (off by default). Write through `rw`, run from
      `rx`, call `nxn_jit_end_write` before running; keep an interpreter for when `nxn_jit_create` answers
      `NXN_ERR_UNSUPPORTED`. Fastmem needs `native.windowedFaultHandler` / `native.windowedGuardPages`.

## 6. Graphics: GL or Vulkan

- [ ] GL (default): the display is OpenGL core 4.x or ES 3.2. Desktop GL ports usually need small changes; the kit links every
      ES 3.2 and OpenGL core 1.0 - 4.3 entry point. Ask `glGetString(GL_VERSION)` and the extensions as on a PC.
- [ ] Vulkan is opt-in (setting `native.vulkan` = 1 on an OS build with Vulkan, then `NXN_CAP_VULKAN`). Verified on the
      console with the canary and a GPU load test; ports that use it are not confirmed yet, so do not promise them.
      Check `nxn_vk_available()` and keep GL as the fallback.
- [ ] Swapchain rules: `R8G8B8A8_UNORM` + sRGB non-linear, FIFO, 2 or 3 images, usage only color attachment, transfer
      source and transfer destination. Recreate the swapchain on `VK_ERROR_OUT_OF_DATE_KHR` after a resize.
- [ ] Create one `VkPipelineCache` with no initial data; Nexvyn OS saves it between launches, so the second start compiles
      fewer shaders.
- [ ] Validate shaders on the PC: `python tools/nxv_native shader <file> --target gl|vulkan`.
- [ ] Do not busy-wait for frames; keep the frame time under 16.6 ms and let the system pace the swap.

## 7. Test and measure

- [ ] Run the app in the emulator first, then on a console. Test handheld and docked, with a pad, with touch only, and with
      a USB keyboard and mouse.
- [ ] Open the performance panel with Ctrl+Alt+P (or L+R+ZL+ZR): look at frame time and its phases, skipped frames, RAM and
      GPU lock time before and after each change. Note the hardware with every number; emulator fps is not console fps.
- [ ] Close the app with the window button and with the app's own exit; the log ends with `ended`. No crash report in
      `System/Logs/Crashes`.
- [ ] Test an update over an installed older version and a fresh install.

## 8. Package and publish

- [ ] `python tools/nxv_native package <project>` gives `build/<name>.nxvapp`; sign it with `--sign key.pem` if you also
      distribute it yourself.
- [ ] For the Store, follow `../Publishing/PUBLISHING.md`: the catalog `sha256` of the exact `.nxvapp` is checked before
      unpacking, so any rebuilt file needs a rebuilt catalog.
- [ ] Screenshots in the English UI, a short honest description, the licence and the source link in the package.
