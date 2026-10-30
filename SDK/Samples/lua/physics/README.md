# Verlet Physics Demo

**English** · [Türkçe](README.tr.md)

Ropes, a rope bridge and a tearable cloth with Verlet integration; grab and drag points, cut links, pin them, turn on the wind.

| | |
|---|---|
| Id | `com.sonerx7.demo.physics` |
| Language | Lua 5.4 |
| Min SDK | 1.2 |
| Permissions | none |
| Gamepad | drives the cursor |
| Window | 800 × 450, resizable |

## What it teaches

- Verlet integration: a point stores its current and previous position; the difference is its velocity
- Distance constraints relaxed in a few passes; inverse masses (0 = pinned, small = heavy) so weights pull the light rope
- Tearing (an overstretched link breaks) and cutting (links crossed by the drag line break, segment intersection)
- Picking the nearest point under the finger and moving it with the pointer
- Plain arrays instead of objects and one reused table for every triangle: no garbage per frame

**APIs used:** `game.run` (sabit 60 Hz adım / fixed 60 Hz step), `game.input.pointer`, `game.ui.button`, `game.gfx.poly/line/circle`, `store`, `audio.tone`

**Controls:** Grab: drag any point · Cut: swipe across links · Pin: tap a point to fix or free it · Wind, Tear, Reset buttons · W wind, R reset, 1-3 tools.

## Code excerpt

The heart of a step: velocity from the position difference, then a correction per link shared by inverse mass.

```lua
-- integrate: new = now + (now - previous) * damping + gravity * dt^2
local vx, vy = (px - ox[i]) * 0.995, (py - oy[i]) * 0.995
ox[i], oy[i] = px, py
x[i], y[i] = px + vx, py + vy + gdt
-- relax one link a-b towards its rest length
local dx, dy = x[b] - x[a], y[b] - y[a]
local d = sqrt(dx * dx + dy * dy)
local k = (d - len[c]) / (d * (im[a] + im[b]))
x[a], y[a] = x[a] + dx * k * im[a], y[a] + dy * k * im[a]
x[b], y[b] = x[b] - dx * k * im[b], y[b] - dy * k * im[b]
```

## Running it

Copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `VerletPhysicsDemo.nxvapp`, or pack it into one file with `python tools/nxvapp_pack.py`. Files: `main.lua` (384 lines), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/physics/source --frames 900

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
