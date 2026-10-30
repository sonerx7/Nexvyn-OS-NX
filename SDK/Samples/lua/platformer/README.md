# Platformer Demo

**English** · [Türkçe](README.tr.md)

A small but complete platformer level made with the nexvyn.game engine: tiles drawn by code, camera, animation, one-way platforms and coins.

| | |
|---|---|
| Id | `com.sonerx7.demo.platformer` |
| Language | Lua 5.4 |
| Min SDK | 1.2 |
| Permissions | none |
| Gamepad | goes to the app (L+R: cursor) |
| Window | 800 × 450, resizable |

## What it teaches

- A map from text rows with `game.tilemap.fromStrings`; tiles are drawn by a `draw` callback instead of an image
- `oneway` tiles: jump up through them, press down + jump to drop through (`dropThrough`)
- `game.camera`: smooth follow, deadzone, bounds, shake; parallax backgrounds with `cam:attach(factor)`
- `game.animations` only advances `frame`; the hero is drawn with shapes for each frame number (no sprite sheet needed)
- Squash and stretch with `game.tween`, coyote time and a jump buffer
- Coins from map objects, `world:collide`, `game.emitter` particles, a `world:trigger` flag, a `game.save` record

**APIs used:** `require("nexvyn.game")`, `game.run`, `game.tilemap.fromStrings`, `game.world`, `game.camera`, `game.class(game.Sprite)`, `game.animations`, `game.tween`, `game.emitter`, `game.input.bind/touchControls/vector`, `game.ui`, `game.save`, `game.audio`, `sys.vibrate`

**Controls:** Left stick / arrows: walk · A, B, Space: jump (let go early for a short hop) · down + jump: drop through a plank · R / −: restart · F3: colliders. On the touch screen a stick and a jump button appear.

## Code excerpt

An animation is only a number: the engine advances `self.frame`, and `render` draws a different pose for each frame.

```lua
local HERO_ANIMS = game.animations{
  idle = {frames = "1,1,1,2", fps = 3},
  run = {frames = "3-6", fps = 12},          -- frames 3, 4, 5, 6 at 12 fps
  jump = {frames = {7}, loop = false},
}
-- in Hero:update(): pick the animation from the physics state
if self.onFloor then
  self:play(abs(self.vx) > 15 and "run" or "idle")   -- play() restarts only when the name changes
else
  self:play(self.vy < 0 and "jump" or "fall")
end
-- in Hero:render(): legs and body bob depend on self.frame
local leg = LEGS[self.frame]
G.rect(x + leg[1] * d - 1.5, feet - 4 - leg[2], 3, 4, 1, "#2B2F4A")
```

## Running it

Copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `PlatformerDemo.nxvapp`, or pack it into one file with `python tools/nxvapp_pack.py`. Files: `main.lua` (377 lines), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/platformer/source --frames 900

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
