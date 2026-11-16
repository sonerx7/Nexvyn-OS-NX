# Game Engine base characters (WP15)

"Put a character in, it walks, jumps and hits" without code. The pack `characters_core` holds three skinned, animated
characters made by our own script; the play scene drives them with a locomotion state machine.

## The characters

| Piece | What | Bones | Triangles | Clips | Height |
|---|---|---|---|---|---|
| `hero` | humanoid, flat-painted, stylized | 16 | 1136 | idle walk run jump fall land attack hit death interact dodge | 1.85 m |
| `creature` | four-legged pet with ears and tail | 18 | 1092 | idle walk run jump fall land attack hit death interact pounce | 0.76 m |
| `drone` | flying robot with spinning rotors | 10 | 696 | idle walk run jump fall land attack hit death hover dash | 1.03 m |

Every GLB is under 300 KB (limit 1.5 MB). Looks: flat colour materials, no textures. Weights are rigid per part (each
part follows one bone), so there is nothing to paint. Content is CC0 by construction: shapes, rig and clips all come from
`tools/gen_characters_blender.py`.

Clips: `idle walk run fall hover` are loops (the last pose equals the first, checked), the rest play once. No clip moves
the skeleton root: the game moves the object, the clips only pose the body (the main body bone may rise and fall, and
turn, but a loop never drifts sideways more than 6 cm, a one-shot at most 0.8 m, e.g. a death fall).

## Axes and size

Y is up, one unit is one metre, the model stands on y = 0 and looks toward **+Z** (glTF front). An object with yaw 0 faces
+Z and `atan(dx, dz)` turns it, exactly like the built-in models. The human is 1.8 m (the hair and ears add a few
centimetres). The origin is between the feet. A node `front_marker` sits in front of the model so the checker can prove the
orientation. (Blender looks toward -Y; the exporter turns that into +Z.)

## Making the pack

```
python tools/gen_characters_blender.py [--out DIR] [--blender EXE]
```

Starts Blender headless (5.2 or 4.4, `--factory-startup`, its own config folders, below-normal priority) and writes
`<out>/characters_core/` in the pack format of `GAME_ENGINE_PACKS.md`: `manifest.json`, `LICENSE.txt` and
`characters/<id>.glb`. Each piece lists `bones`, `tris`, `clips`, `height`, `walkSpeed`, `runSpeed` (metres per second one
cycle of the clip covers) and `beh` (the behaviours a freshly placed character gets). A copy for tests and the gate is in
`tests/fixtures/ge_characters/characters_core/`. The pack is a local product: nothing here is published.

## Rules and checks

`tools/ge_character_spec.py` holds the numbers; `source/core/ge_character.{h,cpp}` is the C++ twin used by the editor.

* at most **32 bones** (one GPU draw palette, `kMaxPaletteBones`), at most 3000 triangles, at least 10 clips, the nine core
  clips present, no duplicate clip names, `walkSpeed < runSpeed`;
* `python tools/ge_character_check.py` parses the GLBs in pure Python: bones, skin weights summing to 1 (at most 4 joints),
  triangles, no textures, size, feet on y = 0, expected height, `front_marker` toward +Z, a root that never moves, loop
  closure, clip names and durations, and the manifest (through `ge_pack_validate.py`);
* `tests/test_gecharacters.cpp` (7 cases: fixture pieces, bone limit, triangle budget, clip rules, speeds, bad input, speed
  formulas), `tests/test_ge_character_lua.py` (the locomotion machine on the real graph, a fuzz of 6000 frames, the pop
  meter), `tools/ge_anim_check.py` (the graph's clips exist in every character). All run in `tools/n2_gate.py`.

## In the editor

The pack's name is "Characters", so its pieces appear as the group **Characters** under Pieces & packs. A placed
character gets the behaviours of its piece (`beh` in the manifest: the hero a `player` and a third-person camera, the
creature and the drone a patrol) and the status line says what it can do. Nothing about packs changes for other pieces.

## At run time

`workshop3d.lua` draws an object of kind `pack:<id>/<piece>` with `g3d.model`. The play test and exported games carry the
piece and the pack's manifest in the bundle (`packs/<id>/`, written by `ws::buildBundle`), so a game never depends on the
pack folder of the device. A missing pack or file leaves the labelled box.

A model that has the `idle` and `walk` clips gets the machine of `romfs/System/Workshop/character_locomotion.json`
(`romfs/System/Lua/nexvyn/ge_character.lua`): the speed (`speed`, scaled so the hero's thresholds fit every character), `grounded`,
the vertical speed, a `jump` trigger (the object leaves the ground upward), `attack` (the fire button of the player),
`hit` (hp falls, or invulnerability starts), `interact` (script) and `dead`. Walk and run play at `speed / walkSpeed`
and `speed / runSpeed` (clamped 0.5 to 1.6) so the feet do not slide. `behaviours` and scripts may call
`e.charTrigger("attack")` and `e.charPlay("pounce")` for any other clip.

**No pop.** The core crossfades from the clip that is playing, so a transition that starts inside a running fade would
jump (what `Animator::smoothInterrupt` fixes in the C++ editor). The Lua machine never starts a transition during a fade
(except death) and a trigger waits at most one fade (0.2 s; triggers live 0.25 s). `smoothInterrupt` itself is not
exposed: that would add SDK surface. In the play test a pop meter samples head, hips, hands and feet through `model:node`
and logs `popRatio` (transitions where a node moved faster than 14 m/s, per transition).

## Evidence

`python tools/ge_char_ryu.py` (the emulator, minimized, under 60 s): a project with the three characters, the play test, keys
for run, jump and attack. Screenshots in `qa/screens/ge/ge_wp15_*.png`, the log in `build/ge_char_ryu/system.log`.

## Gaps

Keyboard moves the hero at full speed, so the walk clip is seen only on the way into the run; the stick (partial tilt) gives
walking. Clip speed is fixed when a state starts (the core has no live speed change), so a change of speed inside a
state keeps the clip speed until the next transition. No hand-held props, no facial animation, no root motion, no retargeting
of other models yet.
