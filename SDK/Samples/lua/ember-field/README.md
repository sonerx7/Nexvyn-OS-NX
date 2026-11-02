# Ember Field

**English** · [Türkçe](README.tr.md)

A small, complete 3D game built the way [Make a game](../../../Guides/MAKE_A_GAME.en.md) describes: a round courier
bird collects embers on a floating island at dusk while stones roll across it. Three lamps, then it is over.

| | |
|---|---|
| Id | `com.sonerx7.demo.emberfield` |
| Language | Lua 5.4 |
| Min SDK | 1.8 (target 1.8) |
| Permissions | none |
| Gamepad | yes (also keyboard and touch) |
| Window | 960 × 540, resizable (opens full screen) |
| Languages | English, Turkish |

## What it teaches

- `g3d.loadModel`: both models load on a background thread while the title screen is already playing; *Play* stays
  grey until they arrive, and a failed load shows a message
- A skinned `.glb` hero with three clips: `Idle` and `Run` loop and crossfade, `Hop` plays once and hands back
  (`model:playing()`); the run speed follows the movement
- An attachment: the glow halo rides on the `Lamp` bone through `model:nodeMatrix` + `g3d.drawMatrix`
- A heightmap island built with `g3d.custom`; the same height function keeps the hero and the stones on the ground
- Collision without a physics engine: circle vs circle (stones, embers, tree trunks) and the island edge
- States (title, how to play, play, pause, game over), pause on +, suspend and focus loss, a best score in `store`
- An art direction of its own: dusk palette, letter-spaced titles with an offset print, a horizontal menu with a
  wavy underline, slanted cards. **Do not copy it:** your game needs its own (guide section 11)
- `art/make_models.py` builds and animates both models in Blender from a script; `art/make_keyart.py` renders the
  store icon from the same model (key art, not a glyph)

**APIs used:** `g3d.loadModel`, `model:play/update/playing/nodeMatrix`, `g3d.drawMatrix`, `g3d.custom`, `g3d.mesh`,
`g3d.draw` with `"glow unlit nocull"`, `g3d.fog/light/camera`, `gfx.gradient/poly/lines/text/wrap`, `audio.tone`,
`sys.vibrate`, `timer.after`, `store`

**Controls:** left stick, D-pad, WASD / arrows or drag a finger: move · A / Enter: choose · left / right: menu ·
+ / Esc / P or the top-right button: pause.

## Code excerpt

The halo follows a bone of the animated model; the clip changes only when the state changes:

```lua
if hero.clip == "Hop" then
    if not pip:playing() then hero.clip = "" end
elseif speed > 0.8 then playClip("Run", {fade = 0.15, speed = 0.7 + speed * 0.12})
else playClip("Idle", {fade = 0.25}) end
pip:update(dt)
-- ...
g3d.draw(pip, x, y, z, 0, yaw, 0)
local m = pip:nodeMatrix("Lamp", x, y, z, 0, yaw, 0)                 -- the halo rides on the "Lamp" bone
if m then g3d.drawMatrix(halo, m, "#FFFFFF", "glow unlit nocull") end
```

## Running it

Copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `EmberField.nxvapp`, or start it from Studio's
templates (*3D Game: Ember Field*). Files: `main.lua`, `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`,
`models/pip.glb` (986 triangles, 8 bones, 3 clips), `models/rock.glb` (80 triangles).

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/ember-field/source --frames 1500

Rebuild the models or the icon (tested with Blender 5.2):

    blender -b --factory-startup -P art/make_models.py -- source/models
    blender -b --factory-startup -P art/make_keyart.py -- source/models/pip.glb keyart.png 1024

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |

The models, the icon and the code were made for this sample (GPL-3.0-or-later, like the SDK samples).
