# Game Engine: 3D particles (WP12)

CPU particle simulation with camera-facing quads, 14 presets and a Particles tab in the Game Engine editor.

## Files

| File | Role |
|---|---|
| `source/core/ge_particles.{h,cpp}` | Pure C++ simulation: emitters, forces, envelopes, sub-emitters, caps. No GL. |
| `source/apps/ge_particles_panel.{h,cpp}` | Preset library, quad renderer, scene runtime, Particles tab. |
| `romfs/Applications/gamemaker.app/particles/presets/*.json` | The preset library (one file per preset). |
| `romfs/Applications/gamemaker.app/particles/atlas.png` | 4 x 4 cell atlas, rendered by `tools/gen_particle_atlas.py` (no outside source, public domain). |
| `tools/ge_particles_check.py` | Preset checker (part of `tools/n2_gate.py`). |
| `tests/test_geparticles.cpp` | Host tests (15 cases, one prints the 2000-particle benchmark). |

## Simulation

- Fixed 1/60 s step with a double accumulator: the same seed gives the same particles at any frame rate
  (`stateHash()` is the determinism check). A long frame runs at most 6 steps.
- Emitter shapes: point, sphere, cone, box, ring, mesh surface (`System::setMesh`, area-weighted triangles).
  Start direction is radial for spheres and a cone of `angle` degrees around +Y for the others.
- Per particle: position, velocity, life, size, rotation, spin, brightness variation, atlas cell.
- Forces: gravity, wind, drag, turbulence (sine noise), vortex with pull toward the axis.
- Envelopes: size curve, alpha curve (up to 4 keys each) and a colour gradient (up to 4 keys) over particle life.
- Sub-emitter: `sub` + `subCount` spawns particles where a particle dies (rain splash, spark embers). One level only.
- Floor plane: `floor {y, mode: bounce | kill, bounce}`. There is no collision with level geometry (that comes with
  the physics work package).
- Timeline: `loop` or one shot (`duration`, `burst`, `delay`), `restart()`, `stop()`, `play()`, `setTimeScale()`.
- Budget: per-emitter `max`, and a global live-particle cap of 2000 (`Budget`, handheld budget of the plan, 2.6)
  shared by every system of the OS. Storage is reserved once per system (no allocation per frame).
- Reads (`collect`, `count`, `stateHash`) share the update mutex and may run on another thread.
- Bad preset JSON never crashes: every number is clamped, unknown keys are ignored, `parsePreset` returns false only
  when no usable emitter is left.

## Drawing

All live particles of a system become two meshes (alpha, additive) of camera-facing quads built per frame and drawn
through `g3d::draw` with the atlas as texture: unlit, no culling, vertex colours carry the tint and the alpha, the
additive mesh uses `DrawOpts::additive`. Alpha quads are sorted back to front. Quads stretch along the screen-space
velocity when the emitter sets `stretch` (rain, sparks). There is no depth read, so no soft particles. No NexGFX
function and no script API were added.

## Presets

explosion, fire, smoke, sparks, rain, snow, magic_sparkle, dust, water_splash, hit_burst (generic hit / blood /
spark), leaf_fall, fireflies, power_up, portal. Each file is `{ "name", "emitters": [ ... ] }`; keys are listed in
`tools/ge_particles_check.py` and read in `ge_particles.cpp` (`readParams`).

## In a project

A 3D level object `{ "kind": "particles", "preset": "fire", "x", "y", "z", "ry", "s" }` plus optional tweaks:
`pr` amount, `ps` size, `pv` speed, `pl` lifetime, `pg` gravity (multipliers), `tc` colour tint (`#rrggbb`),
`seed`, `loop` (true / false, absent = as the preset). It lives in the v1 view the editor edits, so v1 and v2
projects both carry it (ge_schema keeps unknown object fields). The v2 `Particles` component got matching optional
fields (`size`, `speed`, `life`, `gravity`, `tint`, `seed`, `loop`; add-only).

- Editor: the 3D scene view plays particle objects live (a small cross marks each emitter) and the budget bar counts
  them as two draw calls. The Particles tab (3D projects, Advanced layout) picks a preset, has sliders for amount,
  size, speed, lifetime and gravity, colour tint swatches, loop mode, slow motion, seed, a live preview scene and
  "Place in scene".
- Play: `romfs/System/Lua/nexvyn/workshop3d.lua` plays the same objects as a light stand-in (point sprites from a
  small table of looks, up to 150 particles per emitter and 600 together). The full quad renderer needs a script
  binding, which belongs to the SDK work package; until then play mode shows the simplified look.

## Measurements

Host micro-benchmark (`geparticles_microbenchmark_2000`): 2000 live particles, simulation plus quad collection per
frame. See `qa/PERFORMANS.md` for the rows with profile, version and commit. Emulator frame times are relative only
(same profile, before and after), never console numbers.
