# Particles Demo

**English** · [Türkçe](README.tr.md)

Five emitter presets (fire, fountain, sparks, snow, magic), tap bursts and gravity wells placed with a finger.

| | |
|---|---|
| Id | `com.sonerx7.demo.particles` |
| Language | Lua 5.4 |
| Min SDK | 1.2 |
| Permissions | none |
| Gamepad | drives the cursor |
| Window | 800 × 450, resizable |

## What it teaches

- `game.emitter` options: `rate`, `life`, `speed`, `angle`, `spread`, `gravity`, `damping`, `size`, `colors`, `shape`, `offset`
- Continuous emitters (`rate` + `start` + `moveTo`) versus bursts (`emit(n, x, y)`)
- Adding your own forces: an emitter keeps particles in plain arrays (`px`, `py`, `vx`, `vy`, `t`, `life`), so a loop applies gravity without creating tables
- Tap, drag and grabbing objects with `game.input.pointer`
- Touch buttons (`game.ui.button`) laid out from `game.width` / `game.height`, so every window size works

**APIs used:** `game.emitter`, `emitter:emit/start/stop/moveTo/update/draw/clear`, `game.input.pointer`, `game.ui.button/text`, `game.gfx`, `game.toast`, `audio.tone`

**Controls:** Spawn: tap = burst, drag = stream · Attract / Repel: tap to place a well; drag a well to move it, tap it to remove it · 1-5: presets · C: clear wells.

## Code excerpt

A gravity well: the force falls off with distance squared; a particle that reaches the centre is recycled by setting `t = life`.

```lua
local px, py, vx, vy, t, life = em.px, em.py, em.vx, em.vy, em.t, em.life
for i = 1, em.count do
  local dx, dy = wx - px[i], wy - py[i]
  local d2 = dx * dx + dy * dy + 300            -- "softening": finite force in the middle
  local s = k / (d2 * sqrt(d2))                  -- k / d^2 times the unit vector (dx, dy) / d
  vx[i], vy[i] = vx[i] + dx * s, vy[i] + dy * s
  if well.power > 0 and d2 < 340 then t[i] = life[i] end   -- absorbed
end
```

## Running it

Copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `ParticlesDemo.nxvapp`, or pack it into one file with `python tools/nxvapp_pack.py`. Files: `main.lua` (238 lines), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/particles/source --frames 900

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
