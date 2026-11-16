# Nexy Benchmark 2 (`system.nexbench`)

Nexy Benchmark 2 measures CPU, memory, storage, 2D and 3D graphics and shows the result in a calm, Apple-style Nexvyn OS window with colourful charts. It is a native app (`nexbench.nxvmod`, C++17 + OpenGL + Dear ImGui) built on the **Nexvyn Native SDK 1.2**.

| Field | Value |
|---|---|
| **ID** | `system.nexbench` |
| **Version** | `2.3.0` |
| **Category** | `system` |
| **Runtime** | `native` (window mode, `minNative 1.2`) |
| **Target SDK** | `1.13` (`minSdk 1.10`) |
| **Languages** | `en`, `tr`, `de`, `fr`, `es`, `ja`, `ko`, `zh` |
| **Permissions** | `files` (storage benchmark, history), `notifications` |
| **License** | `MIT` |

## Window

The app opens as a normal 960x620 resizable window. It goes full screen only while a test runs and returns to the window, on the Results tab, when the test ends. A confirmation dialog appears before a full test starts; press `B` or `Esc` to stop a running test.

## Tabs

- **Benchmark:** last score with tier badge, the *Start Full Test* button, one row per category with its last result and a *Run* button for manual single-category tests, and a Device card.
- **Results:** score ring, radar chart, per-category bars and per-stage details; *Run Again* and *Copy Report*.
- **History:** bar chart of past runs and a side-by-side comparison of any two runs (change in percent).
- **System:** capability probes of the platform frameworks and runtime information.
- **3D Explore:** free camera in Kepler Reactor, Kepler Cryo Bay and Kepler Station with live fps and polygon count.

## What is measured

1. **CPU single-core:** primes, Mandelbrot, SHA-256, CRC32C and sorting.
2. **CPU multi-core:** worker threads running a CPU ray tracer, with a scaling figure against one thread.
3. **Memory:** streaming read/write/copy bandwidth and pointer-chase latency.
4. **Storage:** sequential write/read, random 4K reads and serialization throughput.
5. **2D graphics:** layered alpha-blended fill rate and instanced particles.
6. **3D scene 1, Kepler Reactor:** about 276K triangles in 26 draw batches.
7. **3D scene 2, Kepler Cryo Bay:** about 363K triangles in 18 draw batches.
8. **Frameworks:** a live check of Native SDK services.

Scores are on a thousands scale (CPU, Graphics, Memory, Storage and system, plus a total and a tier). The 3D scenes ship as packs in `data/scenes/*.nxpk`; Kepler Station (about 295K triangles) is available in 3D Explore. The 3D renderer uses physically based materials with soft shadows, image-based lighting, ambient occlusion, reflections and bloom, and falls back to simpler passes when a feature is not available. The package is about 22 MB because it carries the scene packs. Scores come from the device the app runs on; emulator numbers are not console numbers.

## Controls

- **Gamepad:** stick or D-pad navigate, `A` select; in 3D Explore the stick orbits, `ZL` / `ZR` zoom, `L` / `R` change scene, `X` resets the camera, `B` goes back.
- **Touch, mouse and keyboard:** full touch and mouse navigation; keys `1`-`5` open the tabs, `Tab` changes the 3D Explore scene, `Esc` stops a running test.

## Versions

| Version | Highlights |
|---|---|
| `2.3.0` | Resizable Nexvyn OS style window with colourful charts, full screen only during tests, Kepler Reactor and Kepler Cryo Bay benchmark scenes plus Kepler Station in 3D Explore, retuned thousands-scale scoring, history with comparison and manual single-category tests. 3D upgrade: soft shadows, image-based lighting, ambient occlusion, reflections and bloom. |
| `2.2.1` | Interface polish and 3D rendering fixes on Switch hardware. |
| `2.1.0` | First thousands-scale scoring, 8 languages, light and dark themes. |
| `2.0.0` | Initial Native SDK 1.2 benchmark. |

## Third-Party Notices

- **Dear ImGui** (MIT License)
- **Inter** and **Noto Sans CJK** system fonts provided by Nexvyn OS
