# Game Engine 3D level editor

The Scene tab of a 3D project (`source/apps/ge_editor3d.*`, pure math in `ge_editor3d_core.*`, prefab browser in
`ge_prefab_browser.*`). Plan: `docs/plans/GAME_ENGINE_2_PLAN.md` (WP5).

## Controls

| Input | Action |
|---|---|
| Drag on empty space / one finger | orbit |
| Two fingers, mouse wheel | pan, pinch / zoom |
| Fly button + controller | left stick moves, right stick looks, ZL / ZR lower / raise |
| Click, Shift / Ctrl click, box select button | select, add to selection, marquee |
| Q W E R | hand, move, rotate, scale tools; Move shows X / Y / Z arrows and a free handle, Rotate a ring, Scale uniform handles |
| Ctrl+C / V / D / G, T, Delete, F | copy, paste, duplicate, group / ungroup, turn by the rotation step, delete, frame |

Snapping (tool bar): grid 1 / 0.5 / 0.25 m or off, rotation 90 / 45 / 15 degrees or off, surfaces (drop on floors and
walls, ray test), pieces (walls and floors meet edge to edge, within 0.4 m, base heights continue). Paint scatters props
in a circle or lays pieces end to end along a drag; Array makes lines, grids and circles of the selected piece; Align
aligns or distributes the selection; Layers hide and lock sets of objects.

The budget bar shows triangles, draw calls, texture memory and object count against the handheld planning limits
(plan section 2.6): amber from 30K triangles / 100 calls / 48 MB, red from 60K / 150 / 64 MB.

## Data

The editor edits the level's `objects` of the v1 view the engine works on; a v2 project is lowered to it and written
back by `ge_schema`, which keeps unknown fields (`v1extra`), so these survive both formats: object `grp` (group id),
`hid`, `lock`, `elayer` (layer index) and level `elayers` (`[{n, v, l}]`). Pack pieces are objects whose `kind` is
`pack:<packId>/<pieceId>`; a missing pack or file draws a labelled box and never stops loading. A pack's thumbnail is
the listed file `thumbs/<pieceId>.png`.

## Tests

`tests/test_ge_editor3d.cpp` covers the core: snapping, ray picking (turned boxes), camera, gizmo axis and ring math,
surface placement, sockets and piece snapping, group transforms, arrays, scatter, stroke steps, align / distribute,
history trimming and budget levels. `launch gamemaker ge3dtest` (with `sdmc:/NexvynOS/ge3dtest.txt` on the card) builds
a 60-piece scene through the real commands, runs 210 undo steps and logs the result.
