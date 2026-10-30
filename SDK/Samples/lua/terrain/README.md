# Terrain Demo

**English** · [Türkçe](README.tr.md)

An island made from value noise and fBm, coloured by height and slope, with a see-through sea, fog, a minimap, an autopilot and a fly camera.

| | |
|---|---|
| Id | `com.sonerx7.demo.terrain` |
| Language | Lua 5.4 |
| Min SDK | 1.0 |
| Permissions | none |
| Gamepad | goes to the app (L+R: cursor) |
| Window | 860 × 520, resizable |

## What it teaches

- Seeded value noise and fractal Brownian motion (several octaves added); an island mask that sinks the edges
- One `g3d.custom` mesh with a colour per vertex from a height grid
- Low-poly or smooth shading with `mesh:flat` (no rebuild)
- Forward/right vectors from yaw and pitch; stick + keyboard + touch flying; terrain collision (bilinear sampling)
- Debouncing with `timer.after` + `timer.cancel`: the island is rebuilt once after you stop moving a slider
- Choosing the grid size from `g3d.gpu()` (~18k triangles on the GPU, ~2k on the CPU)

**APIs used:** `g3d.custom` (renkler / colours), `g3d.mesh("plane")`, `mesh:flat`, `g3d.fog`, `input.stick/down`, `ui.hit` (basılı tut / hold), `timer.after/cancel`, `ui.slider/toggle/button/spinner`, `store`

**Controls:** Left stick / WASD: fly · right stick / arrows / drag: look · ZR ZL / E Q: up and down · on-screen arrows: forward and back · F: low poly · Y: panel. After 6 idle seconds the autopilot takes over.

## Code excerpt

fBm: each octave doubles the frequency and multiplies the amplitude by the roughness.

```lua
local function fbm(x, y, octaves, rough)
  local sum, amp, freq, norm = 0, 1, 1, 0
  for _ = 1, octaves do
    sum = sum + noise(x * freq, y * freq) * amp
    norm = norm + amp
    amp, freq = amp * rough, freq * 2
  end
  return sum / norm
end
-- sliders call scheduleBuild(); only the last call within 0.35 s rebuilds
if rebuildTimer then timer.cancel(rebuildTimer) end
rebuildTimer = timer.after(0.35, function() rebuildTimer = nil; build() end)
```

## Running it

Copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `TerrainDemo.nxvapp`, or pack it into one file with `python tools/nxvapp_pack.py`. Files: `main.lua` (373 lines), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/terrain/source --frames 900

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
