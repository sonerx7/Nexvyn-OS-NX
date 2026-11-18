# Capabilities and limits

Use this matrix before you promise a feature. "Supported" means proven on the host and in emulation; a physical
device column is not measured yet. Treat every performance number below as a target, not a measured device result.

## Platform capabilities (native C/C++ apps)

| Capability | Status | Limits and rules |
|---|---|---|
| Threads: start/stop/join, TLS, mutex, condition variables | Supported | Normal app use. Join workers before exit. |
| GL core 4.3 / GLES 3.2 context, FBO, depth, fences | Supported | One context, owned by the render thread; resolve GL functions through the display API (`nxn_display.h`). |
| Shared GL context, GL on a worker thread | Unsupported | A second display is refused. Upload on the render thread; prepare data on workers. |
| Other GPU producers (Vulkan and similar) | Unsupported | GL is the app GPU path. |
| Generated machine code (JIT) via RW/RX views (`nxn_jit_*`) | Limited | Opt in with app.json `native.windowedJit`. 1-64 buffers, at most 256 MiB total, admitted against free heap. Always keep an interpreter fallback. |
| Running published JIT code from several threads | Limited | Only after the app is quiescent: join workers before rewriting code. |
| Precise virtual memory reserve/commit/decommit | Unsupported | A heap-backed compatibility VM is used. Do not design around large sparse address spaces. |
| Guard pages (`nxn_mem_guard`) | Limited | Opt in; whole pages inside the app's own malloc blocks; 32 ranges. |
| Data-abort fault handler | Limited | Data aborts only; no SIMD/FPCR/x17 edits; not a sandbox. |
| Other fault classes, recursive faults, safe kill | Unsupported | A crash ends the app. |
| Memory isolation between apps | None | Window and fullscreen native apps run in-process. A bug can affect the OS session: test carefully. |
| RAM guarantee per app | None | Stay inside the profile budget and handle allocation failure. |
| x86 translation, PE/DLL loading, Wine-like layers, DirectX, Android apps | Excluded | Port the source instead. |

## Script runtimes

| Runtime | Use for | Notes |
|---|---|---|
| Lua 5.4.7 | Utilities, 2D games (`nexvyn.game`), NXUI apps, simple 3D (`g3d`) | Fastest start, smallest RAM. |
| JavaScript ES2023 | Network apps, feeds, JSON-heavy logic | Promises/async. |
| Python 3.12 | Data and standard-library heavy tools | Highest RAM of the script runtimes. |
| C (script, TinyCC), Squirrel, Java | Small apps and teaching samples | See `SDK/AI/languages/`. |

When a script app needs native speed or direct GL control, use the native runtime.

## Budgets per profile (`nxv create --recommend-only`)

| Profile | Runtime | RAM budget | Target |
|---|---|---|---|
| calculator | lua | 16 MB | 60 fps |
| utility | lua | 24 MB | 60 fps |
| network | js | 32 MB | 60 fps |
| data | python | 48 MB | 60 fps |
| game | native | 128 MB | 60 fps |
| port | native | 192 MB | 60 fps |
| emulator, qemu | native | 256 MB | 60 fps |

## Performance targets (proposed device targets)

| Metric | Target |
|---|---|
| Frame work P95 | <= 16.7 ms (60 Hz) |
| Late presents | <= 1 % of frames |
| Window resize, request to present, P95 | <= 50 ms |
| Launch to first window | <= 50 ms (shell stage, not your app's loading) |
| Memory growth per open/close cycle after warm-up | <= about 43 KB |
| GPU lock wait P95 | <= 5 ms |

Measure on the console when you can. Emulator and PC numbers are useful as regression guards only.

## Using the system well

- Docked and handheld: the display size changes; lay out from the size the display/window API reports, never from
  constants. Keep text readable at handheld size and UI reachable by controller and touch.
- Performance modes can lower clocks: keep work per frame bounded, scale resolution or effects instead of dropping
  frames, and move heavy decode/IO to worker threads.
- Window mode: apps may run windowed and resizable (`liveResize`, `window` in app.json). A resize can return Busy;
  keep the old surface and retry next frame.
- Suspend: when the app loses focus or is suspended, pause audio, timers and network polling; save state.
- Storage: use the app's data folder; write saves atomically (temp file then rename); stream large assets
  (`nxn_stream.h`); prefetch is advisory, check completion before use.
- Audio: fill buffers from a dedicated callback/thread; never block it on IO or locks held by the render thread.
- Native ABI: `NXN_ABI_VERSION` 1 is frozen and append-only; declare `minNative` for newer functions; query optional
  capabilities (`nxn_caps.h`) and fall back.
