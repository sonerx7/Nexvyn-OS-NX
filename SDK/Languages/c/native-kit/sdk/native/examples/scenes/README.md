# Native SDK Scenes

A windowed scene viewer: it loads two baked 3D scenes (made from FBX files you provide) and lets you walk through them.
It shows what the Native SDK can do with `nxn_*` plus OpenGL 4.3 in a Nexvyn OS window.

- Loading: a worker thread streams the scene (1 MB reads); the main thread uploads up to 24 ms of textures per frame behind a progress
  bar and the half loaded scene is not drawn (a `oldload` file in the app data folder brings back the 5 ms budget and the draw, for measuring).
  The log has `scene worker: ...` (read speed per file) and `scene ready ...` (GL upload time).
- Rendering: metallic-roughness PBR (base colour, normal, metal-roughness, emissive), one sun with a fitted PCF shadow map,
  hemisphere ambient, ACES tone mapping, sRGB, optional FXAA, alpha-tested cutouts, per-chunk frustum culling, draws sorted
  by material. Textures are BC1 / BC3 / BC5 (native on the Tegra X1); a CPU decoder is the fallback.
- Controls: left stick move (click = fast), right stick or touch drag look, ZL down, ZR up, L / R previous / next scene,
  + quality menu (shadows, FXAA, resolution scale), - overlay (fps, draw calls, triangles, memory), Y restarts the auto tour (a smooth path through the scene; any stick input takes over; it moves on to the next scene when it ends).
- Self-test: if `<app data>/autotest` exists the app loads both scenes three times, writes `scenes_report.txt`
  (load time, fps, draw calls, triangles, heap and GPU memory, GL errors) and `shot_*.bmp`, then returns code 7.
- Benchmark: if `<app data>/bench` exists (text `<scene> <seconds>`, default `0 60`) the app loads that scene, keeps the
  camera at the start point for that long, adds the frame numbers to `scenes_report.txt` and returns code 7.
- Every run rewrites `scenes_report.txt` every 10 s with a `live:` line (fps, longest frame, frames over 50 ms), so a run
  that is killed still leaves its numbers.

## Bake and package

The FBX files are your own input. They and the baked output are never committed (`build/scene-demo`, `data/` are ignored).
Needs devkitPro, a host C compiler (gcc, clang or MSVC) and Python with Pillow, numpy and etcpak.

    python sdk/native/examples/scenes/package.py --level1 Level1.fbx --library Library.fbx

`tools/nxv_asset` does the baking (`python tools/nxv_asset bake IN.fbx -o OUT --name level1`; GLB / glTF work too): it merges
meshes by material, splits them into 16 m chunks, generates tangents and writes `.nxsc`, then resizes the textures
(2048 / 1024 / 512 by object size), builds mip chains and compresses to `.nxtx`. A damaged input stops with one plain
message and leaves no output; `python tools/nxv_asset check FILE...` verifies baked files.
The package is `com.nexvyn.example.scenes`; put it into `NexvynOS/Applications` as `com.nexvyn.example.scenes.zip`.

Limits today: the frame is copied out of the GL context in windowed mode and the GPU is shared with the desktop, so fps
depends on the window size; there is no collision (free fly); the start point is a heuristic when the FBX has no camera.
