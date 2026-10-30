# Effects Demo

**English** · [Türkçe](README.tr.md)

Three classic demoscene effects drawn with nothing but `gfx.rect`, `gfx.line` and colours: plasma, tunnel and starfield, with four palettes and a cell size control.

| | |
|---|---|
| Id | `com.sonerx7.demo.effects` |
| Language | Lua 5.4 |
| Min SDK | 1.0 |
| Permissions | none |
| Gamepad | drives the cursor |
| Window | 900 × 560, resizable |

## What it teaches

- A "pixel" grid: the window is split into 4-16 px cells and every cell is one `gfx.rect`; the cell size trades sharpness for speed
- Look-up tables (LUTs): everything that does not change over time (angles, distances, palettes) is computed once per window size
- Trig identities: sin(a + b) = sin a cos b + cos a sin b to share per-column and per-row tables
- Run merging: neighbouring cells of the same colour on a row become one wider rectangle
- A starfield: 3D points projected with x / z, streaks at warp speed
- Palettes indexed by an integer and cycled over time

**APIs used:** `gfx.rect/color/line/clear`, `gfx.size`, `sys.time/fps`, `ui.segmented/dropdown/slider/checkbox`, `store`

**Controls:** Drag: steer · 1 2 3: effect · C: colour cycling.

## Code excerpt

Run merging: neighbouring cells of the same colour become one `gfx.rect`; a palette with fewer entries means longer runs.

```lua
local function flushRow(y, cols, cell)
  local c = 0
  while c < cols do
    local k, s = rowIdx[c], rowShade[c]
    local run = 1
    while c + run < cols and rowIdx[c + run] == k and rowShade[c + run] == s do run = run + 1 end
    gfx.color(floor(PR[k] * s), floor(PG[k] * s), floor(PB[k] * s))
    gfx.rect(c * cell, y, run * cell, cell)       -- one rectangle for the whole run
    c = c + run
  end
end
```

## Running it

Copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `EffectsDemo.nxvapp`, or pack it into one file with `python tools/nxvapp_pack.py`. Files: `main.lua` (283 lines), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/effects/source --frames 900

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
