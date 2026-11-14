# Porting & Decompilation Pre-Release Checklist

Run through every item before packaging a `.nxvapp` port or submitting to the App Store.

- [ ] **No Proprietary Assets:** No copyrighted ROMs, `.wad`, `.pak`, `.mpq`, `.z64`, or commercial game data bundled inside `.nxvapp`. Uses `nxn_choose_folder` (or clear user data folder instructions).
- [ ] **Manifest (`app.json`):** `"runtime": "native"`, `"minNative": "1.2"`, `"targetSdk": "2.0"`, `"loadingHint": true` (if load > 3 s), `"memory"` set to realistic MB requirement, `"gamepad": true` for games.
- [ ] **Watchdog Liveness:** `nxn_should_quit()` polled at least every 250 ms during asset loading, decompression, or shader compilation; exits within 5 s when closed.
- [ ] **No Double Vsync:** `SDL_GL_SetSwapInterval(0)` is set so the OS compositor paces frames without stalling the game loop.
- [ ] **Dynamic Resize:** `NXN_EVENT_RESIZE` calls `nxn_display_resize()` and updates `glViewport` for both handheld (720p) and docked (1080p) modes.
- [ ] **Unified Input (Gamepad + Multi-Touch + Keyboard):** `"minNative": "1.2"` enabled for multi-touch; two-finger pinch-zoom, two-finger tap / long-press right-click, gamepad (or `NEXVYN_GAMEPAD_MOUSE=1` / `<nexvyn/nxn_port_input.h>`), and USB/BT keyboard + OSK (`SDL_StopTextInput()` when not typing) all verified; pauses cleanly on `NXN_EVENT_SUSPEND` / focus loss.
- [ ] **Capability Checks:** Optional APIs (`NXN_CAP_JIT`, `NXN_CAP_WINDOW_CTL`, `NXN_CAP_POWER_STATE`, `NXN_CAP_DIALOG`) guarded via `nxn_caps_get()`.
- [ ] **Verification:** Tested on emulator (`nxvtest`) with no crashes, no `not_responding` stalls, and `SDK/Tools/nxv/nxv.py check <bundle>` passing.
