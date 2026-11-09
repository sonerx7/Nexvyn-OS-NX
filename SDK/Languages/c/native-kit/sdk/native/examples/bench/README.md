# Nexvyn Bench

A repeatable stress benchmark for the Native SDK (windowed app, OpenGL 4.3, NexGFX). Eight stages, each with a fixed camera
path and a fixed length (8 s); every count lives in the `kStages` table at the top of `src/main.cpp`.

| # | Stage | Path | What it stresses |
|---|---|---|---|
| 1 | City x1 | NexGFX | baseline (the Scenes demo's city, same loader) |
| 2 | City x5 naive | NexGFX, five `ngfx_render` calls per frame | draw calls, shadow passes, post pass x5 |
| 3 | City x5 fastest SDK flags | same, shadows and FXAA off | NexGFX has no instancing or batching API, so this is the cheapest the SDK offers |
| 4 | 128 dynamic point lights | own GL, instanced boxes, forward shading | fragment cost per light |
| 5 | Particles and fill rate | own GL, 1500 large transparent sprites | overdraw, blending |
| 6 | CPU, 20000 moving objects | own GL, instanced | per-frame transform + frustum culling + buffer upload |
| 7 | 128 lights, tiled forward | stage 4's scene: depth prepass, light bits per 32x32 tile (CPU), one shading pass over the tile's lights | what per-tile light lists save; same picture as stage 4 |
| 8 | Particles, half-res buffer | stage 5's sprites into a half-resolution RGBA16F buffer, added with one full-screen pass | what a half-resolution transparent layer saves (softer sprites) |

No frame cap (`NXN_DISPLAY_NO_VSYNC`). Per stage: avg fps, 1% low fps, avg / max frame ms, CPU ms (frame start to swap), GPU ms
(GL timer query, `n/a` when the driver gives none), draws, triangles, heap and GPU memory; stage 7's `visible` field is the
average number of lights per covered tile. Score = sum of the fps of stages 1-6 (stages 7 and 8 are reported, not scored,
so scores stay comparable with the first reports).

- Start: A (or a touch), or unattended: `<app data>/autorun` exists or the launch argument is `autorun`. The autorun text may
  hold `secs=N` (stage length, default 8), `stages=NNN` (digits of the stages to run, default `12345678`) and `shots=1` (one
  `bench_shot_<stage>.bmp` per stage; that frame is not measured). At the end the
  score stays on screen for 6 s and the app returns code 7.
- Output in the app data folder, rewritten after every stage: `bench_results.json` (`"complete": true` at the end) and
  `bench_report.txt` (table, `RESULT score=... fail=0` line, log).
- PC emulator run: the private test tools run the same package for 4 s per stage (VSync off for the run, everything put
  back).
- GPU time per NexGFX pass (shadow, sky, opaque, blend, post): turn on the setting `gfx.ngfxPassTimers`; the app log gets one
  `nexgfx: gpu ms per render` line every 2 s (consoles; emulators give no timestamps).

## Package

The city is the Scenes demo's baked Level 1 (your own FBX, baked with `tools/nxv_asset`; never committed).

    python sdk/native/examples/bench/package.py [--baked build/scene-demo]

Neutral name and icon on purpose (no company logo in the app).
