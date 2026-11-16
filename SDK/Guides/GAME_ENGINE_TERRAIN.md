# Game Engine: terrain and scatter (WP7)

Heightmap terrain with brushes, painted ground layers, a water plane and seeded plant scatter, plus a Terrain tab in the
Game Engine editor. A beginner makes a landscape in a few taps: "Make an island", then brush, paint and add trees.

## Files

| File | Role |
|---|---|
| `source/core/ge_terrain.{h,cpp}` | Pure C++ core: sample grid, brushes, river, island generator, splat, chunk meshes, collision triangles, scatter, budget, save format. No GL, no files. |
| `source/apps/ge_terrain_panel.{h,cpp}` | Scene runtime (loads and draws the level's terrain object), the Terrain tab, save of `terrain/<name>.bin` and `.rt.json`. |
| `romfs/System/Lua/nexvyn/workshop3d.lua` | Play-test and exported game runtime: object kind `terrain` (mesh, walking height, water, scatter). |
| `tests/test_geterrain.cpp` | Host tests (17 cases). |
| `tests/fixtures/ge_terrain/project` | Tiny project with a terrain object, run on the mock SDK by `tools/n2_gate.py`. |
| `tools/ge_terrain_ryu.py` | Emulator session: 8 x 8 island, screenshots, timing, save and reopen. |

## Data model

- One shared sample grid per terrain, split into chunks of 32 x 32 or 64 x 64 cells, at most 8 x 8 chunks. Neighbouring chunks
  use the same edge samples, so seams cannot open; normals come from the shared grid.
- Heights are `uint16` between `baseY` and `baseY + range` metres (default -8 .. +32, cell 1 m). Resolution is 0.6 mm at the default range.
- Four splat layers per sample (grass, dirt, rock, sand), one weight byte each, always summing to 255. Layer colours are
  blended into vertex colours with a small deterministic speckle (no texture files, no outside content).
- Memory cap: 2 MB for samples and splat (the biggest terrain, 8 x 8 chunks of 64 cells, needs 1.6 MB).
- Everything is deterministic: the same calls and seeds give the same `Terrain::hash()`.

## Brushes

Raise, lower, flatten, smooth, rough (seeded fractal noise), plateau (flat top, soft skirt), river (a seeded meander between two taps,
flat bed, sloped banks) and paint (one layer). Radius 1.5-40 m, strength, soft edge. One-tap island: seeded fractal noise, a
noisy coast falloff, mountains and roughness sliders, then automatic paint (sand at the shore, rock on slopes and peaks, dirt patches,
grass elsewhere). Eight undo snapshots of strokes live in the tab; the project's undo list gets one "Edit terrain" step per stroke.

## Meshes and budget

- `buildChunk(step)`: step 1, 2 or 4 samples per cell. `recommendedStep` keeps the land inside 40K triangles (plan 2.6: 30-60K per frame):
  8 x 8 chunks of 32 cells draw at step 2 (32768 triangles), 4 x 4 at step 1, 8 x 8 chunks of 64 cells at step 4. No LOD switching.
- Scatter instances are merged into the mesh of the chunk they stand on, so the whole terrain is one draw call per chunk plus the water
  plane (64 + 1 for 8 x 8). The basic renderer draws `drawInstanced` copies one by one, which cost 987 calls; merging brought it to 64.
- The tab's budget bar shows land triangles, plants (cap 2000) and total triangles against 60K, amber above 80 %, red above the limit.

## Scatter

Rules (`sr` on the object): kind (`tree`, `bush`, `rock`, `grass`), amount per 100 m2, maximum slope, splat layer filter, seed. The core also
supports a minimum slope, a height range, a minimum weight, scale range and a circular region. Instances come from seeded dart throwing with a
minimum distance (spatial hash), so the same rule and terrain always give the same plants. Only the rules and the seed are saved; the
instances are rebuilt on load. Built-in shapes are boxes and cones with vertex colours (tree 26, bush 10, rock 12, grass 6 triangles).
Pack parts (`pack:...`) are not scattered yet.

## Collision

`ge_terrain::addToWorld(phys3d::World&, terrain, origin, layer, step, ids, err)` adds one static `phys3d` body per chunk. At step 1 the
triangles are exactly the surface `heightAt` interpolates, so rays, sweeps and the character controller stand on the same ground.
Tests compare 200 ray hits with `heightAt` and with a brute-force triangle search. No script API was added for this (see below).

## Save format

- `terrain/t<id>.bin`: `NXTR`, version, chunk layout, floats, water, layer colours, heights as zigzag varint deltas, splat as run-length
  samples, FNV-1a checksum. Written atomically. A damaged or hostile file gives a clean error, never a crash or a huge allocation.
  8 x 8 chunks of 32 cells: 192 KB; biggest terrain with an island: under 900 KB.
- `terrain/t<id>.rt.json`: what the Lua runtime reads: a coarse height grid (hex), the splat (hex), colours, water, scatter instances (about 225 KB
  for the 8 x 8 island with 923 plants). Copied into every bundle (`buildBundle` copies `terrain/`).
- The level object stays small: `{kind:"terrain", file, rt, sr, x, y, z}`. Heavy data is not in `project.json`, so undo snapshots stay light.
- `ge_schema` knows a `Terrain` component (file, rt, rules); the editor works on the lowered v1 view, which both formats carry.
- Placing a terrain sets the level's flat ground size to 0.

## Runtime (Lua)

`workshop3d.lua` builds one mesh with `g3d.custom` from the coarse grid (same triangulation as the editor, so what you see is what you
stand on), uses it for walking (`groundTop`), draws water as a translucent plane with a small wave, and builds scatter as real triangles in one
mesh per 48 m cell. No SDK function was added.

## SDK surface decision

No public `phys`/`nav` binding for terrain was added. The terrain lives inside the Game Engine (editor + Lua runtime object kind) and the C++
`addToWorld` is ready for the first script surface that needs it. This keeps SDK 1.15 unchanged (no new minor, no new native capability bit, no
four-language parity work) until a script API for heightfields is actually wanted.

## Gaps

- The Lua runtime was checked on the mock SDK (fixture build, walking height, draw), not yet in a real play test on the emulator.
- No LOD or frustum culling; the budget is held by the step choice.
- Scatter uses built-in shapes only; no pack parts, no per-instance colour variation.
- Rivers carve a bed but do not fill it with flowing water.
