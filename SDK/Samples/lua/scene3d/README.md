# 3D Scene Demo

**English** · [Türkçe](README.tr.md)

`g3d.custom` meshes with UVs (crates, an octagonal pedestal, a curved brick wall, a tiled floor), a sun that follows the time of day, fog, glowing lamp halos and an orbit camera.

| | |
|---|---|
| Id | `com.sonerx7.demo.scene3d` |
| Language | Lua 5.4 |
| Min SDK | 1.0 |
| Permissions | none |
| Gamepad | drives the cursor |
| Window | 860 × 520, resizable |

## What it teaches

- Building your own meshes with `g3d.custom(vertices, indices, colors, flat, uvs)` and a quad helper
- Counter-clockwise winding seen from outside, and back-face culling
- UVs above 1 repeat the texture (floor); on the wall the UVs follow the arc length so bricks keep their shape
- `mesh:setTexture` on primitives; the `setColor` colour on the untextured (CPU) path
- `g3d.light` (direction, ambient, colour) and `g3d.fog` matched to the sky
- An orbit camera (drag, wheel, pinch), halos with `"glow"`, 2D labels over 3D points with `g3d.project`

**APIs used:** `g3d.custom`, `g3d.mesh`, `mesh:setTexture/setColor`, `g3d.begin/camera/light/fog/draw/point/project/finish`, `g3d.gpu`, `ui.slider/toggle/iconButton`, `store`

**Controls:** Drag: orbit · wheel or pinch: zoom · arrows: orbit · T: textures · W: wireframe · Tab: panel.

## Code excerpt

A cube with its own UVs on every face: corners are not shared and each quad is counter-clockwise seen from outside.

```lua
-- quad(b, bottomLeft, bottomRight, topRight, topLeft, u0, v0, u1, v1)
local function makeCrate(s)
  local b = builder()
  local n, p = -s, s
  quad(b, {n, n, p}, {p, n, p}, {p, p, p}, {n, p, p}, 0, 0, 1, 1)   -- front  (+z)
  quad(b, {p, n, n}, {n, n, n}, {n, p, n}, {p, p, n}, 0, 0, 1, 1)   -- back   (-z)
  -- ... right, left, top, bottom
  return g3d.custom(b.V, b.I, nil, true, b.UV)                     -- flat shading, UVs
end
crate = makeCrate(0.45)
if crate.setTexture then crate:setTexture("bundle:/tex/crate.png") end
```

## Running it

Copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `3DSceneDemo.nxvapp`, or pack it into one file with `python tools/nxvapp_pack.py`. Files: `main.lua` (366 lines), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`, `tex/*.png`.

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/scene3d/source --frames 900

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
