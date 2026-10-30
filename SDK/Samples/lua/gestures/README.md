# Gestures Demo

**English** · [Türkçe](README.tr.md)

Pinch, rotate and two-finger pan that keep the point between the fingers in place. On the second tab you tilt the console to roll a marble that rumbles when it hits a wall.

| | |
|---|---|
| Id | `com.sonerx7.demo.gestures` |
| Language | Lua 5.4 |
| Min SDK | 1.0 |
| Permissions | none |
| Gamepad | drives the cursor |
| Window | 900 × 600, resizable |

## What it teaches

- The `"pinch"` (`e.scale`), `"rotate"` (`e.angle`) and two-finger `"scroll"` (`e.dx`, `e.dy`) events; zooming and rotating around the point between the fingers
- The same view with mouse and controller: drag, wheel, Q / E, double click
- A rotated, scaled picture with `gfx.poly` by transforming the corner points yourself
- `input.motion()`: acceleration (G), angular velocity (rad/s) and accumulated rotation, as live bars and an artificial horizon
- `sys.vibrate` as strong as the impact, a light tick every 45 degrees and a rumble pattern made with timers

**APIs used:** `app.event` (pinch, rotate, scroll, mousedown/move/up), `input.motion`, `input.stick`, `sys.vibrate`, `gfx.poly/clip/alpha`, `timer.after`, `ui.segmented/button`

**Controls:** Gestures: pinch / rotate / pan with two fingers · mouse: drag, wheel · Q / E rotate · Z / X zoom · double tap or R: reset. Tilt: tilt the console (arrows and the left stick work too) · Calibrate: the current pose becomes "flat".

## Code excerpt

Zooming around a point: the vector from that point to the picture's centre grows by the same factor.

```lua
local function zoomAt(k, sx, sy)
  local nz = max(0.3, min(6, view.zoom * k))
  k = nz / view.zoom
  local ox, oy = sx - canvas.x - canvas.w / 2, sy - canvas.y - canvas.h / 2
  view.panX = ox + (view.panX - ox) * k
  view.panY = oy + (view.panY - oy) * k
  view.zoom = nz
end
function app.event(e)
  if e.type == "pinch" then zoomAt(e.scale, e.x, e.y)
  elseif e.type == "rotate" then rotateAt(e.angle, e.x, e.y)
  elseif e.type == "scroll" and e.touch then view.panX, view.panY = view.panX - e.dx, view.panY - e.dy end
end
```

## Running it

Copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `GesturesDemo.nxvapp`, or pack it into one file with `python tools/nxvapp_pack.py`. Files: `main.lua` (307 lines), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/gestures/source --frames 900

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
