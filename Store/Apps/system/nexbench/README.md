# Nexy Benchmark 2 (`system.nexbench`)

Nexy Benchmark 2 measures CPU, memory, storage, 2D and 3D graphics and shows the result in a calm Nexvyn OS window with a left sidebar, a detail panel and a status bar. It is a native app (`nexbench.nxvmod`, C++17 + OpenGL + Dear ImGui) built on the **Nexvyn Native SDK 1.2**.

| Field | Value |
|---|---|
| **ID** | `system.nexbench` |
| **Version** | `2.4.4` |
| **Category** | `system` |
| **Runtime** | `native` (window mode, Native 1.2; OS 1.3.26 or later) |
| **Target SDK** | `1.13` (`minSdk 1.10`) |
| **Languages** | `en`, `tr`, `de`, `fr`, `es`, `ja`, `ko`, `zh` |
| **Permissions** | `files` (storage benchmark, history), `notifications` |
| **License** | `MIT` |

## Window

The app opens as a normal 1120x680 window that you can resize; the layout scales from handheld to docked sizes. It has three parts: a **left sidebar** with the five pages, a **content area** and a **status bar** at the bottom (live fps, memory use, console mode with battery, and whether the 3D scenes are ready). On wide windows a **detail panel** on the right explains the selected test (last result, what it measures, recent results); on History it holds the run comparison. The app goes full screen only while a test runs and returns to the window, on the Results page, when the test ends. A confirmation dialog appears before a full test starts; use the visible Stop Test button or semantic Cancel/Escape to request a stop. The app follows the shared OS frame, text roles, focus and touch-scroll behavior.

## Pages

- **Benchmark:** score ring with the last total, tier badge and a Docked or Handheld badge, the *Start Full Test* button, one row per category with its last result and a *Run* button for manual single-category tests.
- **Results:** score ring, radar chart, per-category bars and per-stage details; *Run Again* and *Copy Report*.
- **History:** bar chart of past runs with Docked or Handheld and tier badges, best docked and best handheld score, and a side-by-side comparison of any two runs (change in percent).
- **System:** capability probes of the platform frameworks and runtime information.
- **3D Explore:** free camera in Kepler Reactor, Kepler Cryo Bay and Kepler Station with live fps and polygon count.

## What is measured

1. **CPU single-core:** primes, Mandelbrot, SHA-256, CRC32C and sorting.
2. **CPU multi-core:** worker threads running a CPU ray tracer, with a scaling figure against one thread.
3. **Memory:** streaming read/write/copy bandwidth and pointer-chase latency.
4. **Storage:** sequential write/read, random 4K reads and serialization throughput.
5. **2D graphics:** layered alpha-blended fill rate and instanced particles.
6. **3D scene 1, Kepler Reactor:** 275,820 scene triangles in the single geometry pass.
7. **3D scene 2, Kepler Cryo Bay:** 363,160 scene triangles in the single geometry pass.
8. **Frameworks:** a live check of Native SDK services.

Scores are on a thousands scale (CPU, Graphics, Memory, Storage and system, plus a total and a tier). The three Kepler scene packs remain intact; Station has 137,324 scene triangles. Only one scene is resident at a time. Worker threads read and decompress packs; GPU uploads remain on the render thread in small slices. Safe mode and the Explore quality settings are retained.

Version 2.4.4 uses **workload profile 6**: 1280x720 3D targets, normal-mapped surfaces, a 512x512 directional shadow map with four bilinear PCF taps, bounded material highlights and FXAA. Bloom, HDR, SSAO and full PBR remain disabled. All restored model geometry remains present, including stairs and ladder; the Reactor starting camera turns toward the stairs. This is a quality increase toward the user's roughly 50 FPS goal, not a measured console frame-rate guarantee. Texture caps remain 512/256 pixels and only one scene is resident. Safe mode disables shadows and selects Low quality.

These are pixel and effect reductions, not a measured 50% decrease in frame time, polygon count or total memory. Older history stays readable. Reports persist the workload profile; comparison refuses different profiles, unknown render dimensions or different render sizes. Best-in-mode scores use the current profile. Console modes remain labeled; emulator timings are not physical-device timings. See [changes](CHANGELOG.md) and the private development validation record.

## Controls

- **Gamepad:** D-pad navigates every page and dialog; Confirm/Cancel follow the system mapping. In Explore, sticks orbit/tilt, ZL/ZR change elevation, L/R select scenes and X resets the camera. The scene selector, Reset camera, Back and Stop Test buttons also accept pad focus.
- **Touch:** OS controls and lists handle taps and captured swipes. Drag the scene to orbit, or use two scene contacts to pinch-zoom. Contact IDs own the gesture; lifting either pinch contact waits for all contacts to lift before restarting. A toolbar gesture never becomes a scene drag.
- **Keyboard/mouse:** Tab/Shift+Tab, arrows and activation use the shared backend. Keys 1-5 open pages, S opens the full-test dialog, Escape cancels, WASD/EQ move the Explore camera and R resets it. Scene selection uses the visible selector. Mouse drag orbits and the wheel zooms over the scene.
- **Lifecycle:** focus loss or suspend cancels captures and aborts an active measurement instead of mixing background time into its score. Essential actions have visible alternatives.

## Build and verification

Use an updated Native SDK containing the shared `nxn_imgui_input.h` and `nxn_os_ui.h` helpers:

```text
python build.py --kit <native-sdk-directory>
```

The build checks module imports and packs only the manifest, icon, module, eight locale files and scene data with the SDK packer and its integrity manifest. It copies the resulting package into the configured local testing folders. It does not launch a browser or emulator. Do not use `--install-emu` against a user's installed app as a substitute for the OS update workflow.

`tests/test_history_profile.cpp` is a host regression for legacy history retention, workload identity, comparison rules and failed-save propagation. Emulator scenarios live in `tests/`. Test the actual package on OS 1.3.26 or later, including compact/wide layouts, modal navigation, touch cancellation, three scenes, a full benchmark, offline launch and update preservation. Physical-device multitouch, disconnect and crash acceptance require separate hardware evidence.

## Versions

| Version | Highlights |
|---|---|
| `2.4.1` | Diffuse-only 640x360 3D profile, smaller textures and no dynamic shadows, bloom, HDR, FXAA or normal/ORM GPU maps. |
| `2.4.0` | Shared OS input/frame/controls, touch Stop/Reset/Back, compact reflow, stable scene gesture capture and separate half-pixel 3D Lite workload. |
| `2.3.2` | Lighter 3D scenes tuned for real Switch hardware (about 135K triangles per scene, 512 px textures, no screen-space effects), one scene in memory at a time, crash recovery with safe mode, Graphics quality setting (Auto, Low, Medium), scene memory shown in the System tab. Scoring formula unchanged. |
| `2.3.1` | Redesigned window: left sidebar, detail panel on wide windows and a status bar; scales from handheld to docked size. Benchmark stages render at a fixed 1280x720 internal resolution (scaled to the window), so docked and handheld scores are comparable. Every run is tagged Docked or Handheld (console mode when the test starts); History shows the mode, warns when two compared runs differ in mode, and lists the best docked and best handheld score. Scoring formula unchanged. |
| `2.3.0` | Resizable Nexvyn OS style window with colourful charts, full screen only during tests, Kepler Reactor and Kepler Cryo Bay benchmark scenes plus Kepler Station in 3D Explore, retuned thousands-scale scoring, history with comparison and manual single-category tests. 3D upgrade: soft shadows, image-based lighting, ambient occlusion, reflections and bloom. |
| `2.2.1` | Interface polish and 3D rendering fixes on Switch hardware. |
| `2.1.0` | First thousands-scale scoring, 8 languages, light and dark themes. |
| `2.0.0` | Initial Native SDK 1.2 benchmark. |

## Third-Party Notices

- **Dear ImGui** (MIT License)
- **Inter** and **Noto Sans CJK** system fonts provided by Nexvyn OS
