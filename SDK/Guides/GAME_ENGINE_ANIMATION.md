# Game Engine animation (WP11)

Animation without code for the 3D Game Engine: prop timelines, camera rails and the Animator state machine. The playback
core is `source/core/ge_anim.{h,cpp}` (pure C++, deterministic); the Lua runtime plays the same data through
`romfs/System/Lua/nexvyn/ge_anim.lua`; the editor tab is `source/apps/ge_anim_panel.cpp`.

## Prop timelines

A timeline animates one object with key frames. Channels: `x y z` (offset in metres), `rx ry rz` (degrees, added),
`sx sy sz s` (multiply; `s` is uniform), `r g b` (colour 0..1, replaces) and `visible` (never blended).
A key is `[time, value, ease]`; the ease is used from that key to the next: `linear in out ease spring step`.
`loop` is `once`, `loop` or `pingpong`. `autoplay` starts it with the level; `trigger` names an event that restarts it
(`touch` starts it when the player stands next to the object). `events` are `[time, name]`; a once-timeline emits
`onEnd` when it ends. An event starts every timeline and rail whose `trigger` has that name, so a door can open when a
lever's timeline ends, and it reaches the object's script as `script.timelineEvent(name)`.

An object carries it in the field `tl` (the v1 view; v1 and v2 projects both keep it). In a v2 project the same data is
the add-only component `Timeline` (see `GAME_ENGINE_FORMAT_V2.md`); `ge_schema::lower` writes it back as `tl`.
Limits: 32 tracks, 256 keys per track, 64 events, duration 0.05 to 600 s; bad numbers are clamped, bad tracks skipped.

Runtime note: position, yaw and uniform size move the object itself (what stands on it is carried along). Turns about
x / z and the per-axis stretch turn and stretch the model parts around the object's origin.

## Camera rails

`rail` (component `CameraRail`): way points `{pos, look, fov}` joined by a Catmull-Rom path, a `duration`, an `ease` and
`play`: `enter` (game start), `end` (game over), `trigger` or `none`. While a rail runs it replaces the follow camera;
`onEnd` is emitted as an event when it ends.

## Animator state machine

`ge_anim::Machine` holds a graph: states (a clip, loop, speed, optional `speedParam`), parameters (float, bool, trigger)
and transitions with conditions (`> < >= <= == != true false trigger`), a crossfade time and an optional exit time (the
fraction of the clip that must have played; `1` = until it ends). It chooses what to play and reports the blend weights,
which always sum to 1 (a fade interrupted by another transition keeps up to four clips blending). A trigger waits 0.25 s
for a transition that can take it. `Machine::takeCommand()` tells the `g3d::Animator` to `play(clip, loop, speed, fade)`;
the Animator crossfades from its current pose, so there is no pop. A transition that interrupts a running crossfade used to start
from one clip alone (a visible jump); the new opt-in `Animator::smoothInterrupt` (off by default, so every script and every
existing app behaves as before) starts it from the pose on screen instead. The editor and `geanimrigtest` turn it on. The shipped graph is
`timelines/animators/humanoid_locomotion.json` (idle / walk / run / jump / attack).

Decision: the Animator stays inside the engine and the editor in this work package. It adds no SDK function (the SDK stays
1.15). The base characters of WP15 (`GAME_ENGINE_CHARACTERS.md`) are driven in the play scene by a Lua twin of this machine (`nexvyn.ge_character`, graph `Workshop/character_locomotion.json`); `smoothInterrupt` stays an editor / engine flag. Existing apps
that use `g3d.model` animation are unchanged.

## Editor

The Animation tab (3D projects) has three modes. Props: the preset list, a live preview prop, a time bar with tracks,
draggable key diamonds, a ruler to scrub, play / pause / stop, loop mode, duration, value and curve of the selected key,
add / delete key and track, "Play on stage" (objects with a timeline move in the scene view) and "Attach to selected
object". Camera: path preview with way points, a camera view toggle, duration, ease and play-when. Animator: the rigged test
character (`timelines/test_rig.glb`, three bones, five clips, made by `tools/gen_test_rig.py` with Blender), parameter
controls (speed, on the ground, jump, attack) and the live blend of the states.

## Libraries

`timelines/presets`: 17 prop timelines (door opens / closes, elevator, floating pickup, swinging sign, sliding platform,
breathing, bounce, glowing pulse, pop in, spinner, torch flicker, drawbridge, trapdoor, hit wobble, pendulum, chest lid).
`timelines/rails`: 3 camera rails (intro flyover, orbit reveal, dolly in). `timelines/animators`: 1 graph.
`python tools/ge_anim_check.py` checks them (ranges, sorted keys, clips that exist in the rig, labels in all 8 languages).

## Tests

`tests/test_geanim.cpp` (22 cases: eases, track sampling, loop modes, events, triggers, rails, state machine
transitions and crossfade weights, determinism, bad input, every shipped preset, the shared fixture),
`tests/test_ge_anim_lua.py` (the Lua runtime against the same fixture `tests/fixtures/ge_anim/cases.json`),
`tools/ge_anim_check.py`, and the schema cases in `tests/test_geschema.cpp`.
Emulator: `launch gamemaker geanimtest` and `geanimstep:<mode>:<id>` / `geanimrigtest` (see `tools/ge_anim_ryu.py`).
