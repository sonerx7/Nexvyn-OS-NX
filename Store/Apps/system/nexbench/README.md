# NexMark Ultra (`system.nexbench`)

NexMark Ultra is a full-screen, multi-stage hardware, graphics, and operating-system benchmark suite built on the **Nexvyn Native SDK 1.2** (`nexbench.nxvmod`, C++17 + OpenGL 4.3 Core + Dear ImGui + POSIX compat).

| Field | Value |
|---|---|
| **ID** | `system.nexbench` |
| **Version** | `2.1.0` |
| **Category** | `system` |
| **Runtime** | `native` (`NXN_ABI v1`, `minNative 1.2`) |
| **Target SDK** | `1.13` (`minSdk 1.10`) |
| **Languages** | `en`, `tr`, `de`, `fr`, `es`, `ja`, `ko`, `zh` |
| **Permissions** | `files` (storage I/O benchmark & cache hygiene), `notifications` (completion alert) |
| **License** | `MIT` |

## Deterministic 8-Stage Pipeline (< 120s)

1. **CPU Single-Core:** Sieve of Eratosthenes primes, double-precision FP64 Mandelbrot, FIPS 180-4 SHA-256 block hashing, ARMv8 HW CRC32C (`__crc32cd`), and deterministic sort.
2. **CPU Multi-Core (3 Worker Threads):** 1-thread calibration baseline followed by 3 parallel worker threads (`nxn_thread_start`) running a live `320x180` multi-bounce corridor raytracer + 4x4 bone skinning.
3. **Memory Hierarchy:** 32 MiB streaming DRAM read/write/copy throughput and L1 / 16 MiB DRAM Sattolo pointer-chase latency.
4. **Storage I/O & Serialization:** Sequential cache write + `fsync`, sequential read, 4K random read IOPS inside `NXN_DIR_CACHE`, and schema report throughput.
5. **GPU 2D Raster & Fill-Rate:** 48-layer full-resolution alpha-blended plasma overdraw + 12,000 instanced vortex particles inside an HDR FBO with async `GL_TIME_ELAPSED` measurement.
6. **GPU 3D Heavy PBR Prison (602,544 Polygons / 870,612 Triangles):** Baked `.nxbm` three-wing prison compound with patrolling robotic guards, 2048x2048 9-tap PCF shadows, Cook-Torrance PBR + normal/MRA maps, Bloom, and ACES filmic tone mapping along a 12-waypoint Catmull-Rom tour.
7. **GPU 3D Orbital Reactor (461,376 Animated Polys + 64 Dynamic Lights):** Multi-axis gyroscope torus rings, pulsing ion core, 48 hydraulic pistons, and 256 vortex drones illuminated by 64 colored dynamic UBO point lights.
8. **Platform Frameworks & Services:** Live probe of Native SDK capabilities, fullscreen window control, power/dock telemetry, NXUI design tokens/i18n, OS permissions, audio mixer/tone, rumble haptics, save backup, and POSIX `pipe` / `mmap` / `clock_gettime` / `getentropy`.

## Controls

- **Gamepad:** `D-Pad / Left Stick` navigate, `A` select, `L / R` switch tabs or 3D scenes, `X` toggle fullscreen / reset camera, `Y` toggle alarm in 3D Explorer, hold `B` (2.0s) emergency abort during run.
- **Touch & Mouse/Keyboard:** Full touch & mouse navigation; in 3D Explorer use `WASD` + drag/mouse look, `Tab` switch scene, `F` alarm, `R` reset camera, `Esc` return.

## Versions

| Version | Highlights |
|---|---|
| `2.1.0` | Dual animated 3D PBR scenes (602K Prison + 461K Orbital Reactor), thousands-scale scoring (`S+ >= 42,000`), 8 languages, Dark/Light NXUI tokens, pre-flight RAM hygiene modal. |
| `2.0.0` | Initial Native SDK 1.2 full-screen 8-stage pipeline. |

## Third-Party Notices

- **Dear ImGui** (MIT License)
- **Inter** & **Noto Sans CJK** system fonts provided by Nexvyn OS
- 3D prison environment geometry baked from local FBX kit into `data/prison.nxbm`
