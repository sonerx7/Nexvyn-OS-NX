-- Scene 3D demo: textured g3d.custom meshes with UVs, a moving sun, fog and an orbit camera.
--
-- What this file teaches:
--   1. building your own meshes with g3d.custom(vertices, indices, colors, flat, uvs): quads, a cube with one
--      texture per face, an octagonal pedestal and a curved brick wall whose UVs follow the arc length
--   2. counter-clockwise winding (seen from outside) so back faces are culled correctly
--   3. UVs above 1 repeat the image (the floor tiles), and mesh:setTexture(path) on primitives
--   4. g3d.light (direction, ambient, colour) driven by a time-of-day slider, g3d.fog matched to the sky
--   5. an orbit camera: drag to rotate, wheel or pinch to zoom, arrow keys too
--   6. the "glow" flag (additive blending) for soft lamp halos, and g3d.project for 2D labels over 3D points
-- Meshes are created once in app.load and drawn every frame: they live on the GPU.

local app = {}
local sin, cos, pi, sqrt, min, max, floor, abs = math.sin, math.cos, math.pi, math.sqrt, math.min, math.max,
  math.floor, math.abs

-- ------------------------------------------------------------------ 1. mesh building helpers
-- A builder collects flat arrays: V = {x,y,z, ...}, I = {i1,i2,i3, ...} (1-based), UV = {u,v, ...}.
local function builder() return {V = {}, I = {}, UV = {}, n = 0} end

local function vertex(b, x, y, z, u, v)
  local V, UV = b.V, b.UV
  V[#V + 1], V[#V + 2], V[#V + 3] = x, y, z
  UV[#UV + 1], UV[#UV + 2] = u, v
  b.n = b.n + 1
  return b.n
end

-- quad from 4 corners given counter-clockwise as seen from outside: bottom-left, bottom-right, top-right, top-left.
-- (u0, v0) is the top-left of the image region, (u1, v1) the bottom-right; v grows downwards in the image.
local function quad(b, bl, br, tr, tl, u0, v0, u1, v1)
  local a = vertex(b, bl[1], bl[2], bl[3], u0, v1)
  local c = vertex(b, br[1], br[2], br[3], u1, v1)
  local d = vertex(b, tr[1], tr[2], tr[3], u1, v0)
  local e = vertex(b, tl[1], tl[2], tl[3], u0, v0)
  local I = b.I
  I[#I + 1], I[#I + 2], I[#I + 3] = a, c, d          -- two triangles, both counter-clockwise
  I[#I + 1], I[#I + 2], I[#I + 3] = a, d, e
end

local function finish(b, flat) return g3d.custom(b.V, b.I, nil, flat, b.UV) end

-- floor: a grid of quads (several small quads sort better on the CPU fallback than one huge one).
-- UVs go from 0 to `rep`, so the tile image repeats rep x rep times.
local function makeFloor(size, div, rep)
  local b = builder()
  local s, h = size / div, size / 2
  for j = 0, div - 1 do
    for i = 0, div - 1 do
      local x0, x1, z0, z1 = -h + i * s, -h + (i + 1) * s, -h + j * s, -h + (j + 1) * s
      local u0, u1, v0, v1 = i / div * rep, (i + 1) / div * rep, j / div * rep, (j + 1) / div * rep
      -- seen from above, "bottom" of the quad is +z and "right" is +x
      quad(b, {x0, 0, z1}, {x1, 0, z1}, {x1, 0, z0}, {x0, 0, z0}, u0, v0, u1, v1)
    end
  end
  return finish(b, true)
end

-- cube with the whole texture on every face (24 vertices: corners are not shared, each face has its own UVs)
local function makeCrate(s)
  local b = builder()
  local n, p = -s, s
  quad(b, {n, n, p}, {p, n, p}, {p, p, p}, {n, p, p}, 0, 0, 1, 1)   -- front  (+z)
  quad(b, {p, n, n}, {n, n, n}, {n, p, n}, {p, p, n}, 0, 0, 1, 1)   -- back   (-z)
  quad(b, {p, n, p}, {p, n, n}, {p, p, n}, {p, p, p}, 0, 0, 1, 1)   -- right  (+x)
  quad(b, {n, n, n}, {n, n, p}, {n, p, p}, {n, p, n}, 0, 0, 1, 1)   -- left   (-x)
  quad(b, {n, p, p}, {p, p, p}, {p, p, n}, {n, p, n}, 0, 0, 1, 1)   -- top    (+y)
  quad(b, {n, n, n}, {p, n, n}, {p, n, p}, {n, n, p}, 0, 0, 1, 1)   -- bottom (-y)
  return finish(b, true)
end

-- octagonal pedestal: sides wrap the texture around once; the caps map the circle onto the image
local function makePrism(sides, r, h)
  local b = builder()
  local function at(a, y) return {r * cos(a), y, -r * sin(a)} end   -- angle grows counter-clockwise from above
  for i = 0, sides - 1 do
    local a0, a1 = i / sides * 2 * pi, (i + 1) / sides * 2 * pi
    quad(b, at(a0, 0), at(a1, 0), at(a1, h), at(a0, h), i / sides, 0, (i + 1) / sides, 1)
  end
  local I = b.I
  local top = vertex(b, 0, h, 0, 0.5, 0.5)
  local bottom = vertex(b, 0, 0, 0, 0.5, 0.5)
  for i = 0, sides - 1 do
    local a0, a1 = i / sides * 2 * pi, (i + 1) / sides * 2 * pi
    local p0, p1 = at(a0, h), at(a1, h)
    local t0 = vertex(b, p0[1], h, p0[3], 0.5 + 0.5 * cos(a0), 0.5 - 0.5 * sin(a0))
    local t1 = vertex(b, p1[1], h, p1[3], 0.5 + 0.5 * cos(a1), 0.5 - 0.5 * sin(a1))
    I[#I + 1], I[#I + 2], I[#I + 3] = top, t0, t1                     -- counter-clockwise from above
    local q0 = vertex(b, p0[1], 0, p0[3], 0.5 + 0.5 * cos(a0), 0.5 - 0.5 * sin(a0))
    local q1 = vertex(b, p1[1], 0, p1[3], 0.5 + 0.5 * cos(a1), 0.5 - 0.5 * sin(a1))
    I[#I + 1], I[#I + 2], I[#I + 3] = bottom, q1, q0                  -- reversed: seen from below
  end
  return finish(b, true)
end

-- curved wall: outer face, inner face and a top. u = arc length / brick-repeat so bricks keep their shape.
local function makeArcWall(radius, a0, a1, h, thick, segs)
  local b = builder()
  local ri, ro = radius - thick / 2, radius + thick / 2
  local function at(r, a, y) return {r * cos(a), y, -r * sin(a)} end
  local rep = 2.0                                      -- metres of wall per texture repeat
  for i = 0, segs - 1 do
    local s0, s1 = a0 + (a1 - a0) * i / segs, a0 + (a1 - a0) * (i + 1) / segs
    local u0, u1 = ro * (s0 - a0) / rep, ro * (s1 - a0) / rep
    quad(b, at(ro, s0, 0), at(ro, s1, 0), at(ro, s1, h), at(ro, s0, h), u0, 0, u1, h / rep)       -- outside
    quad(b, at(ri, s1, 0), at(ri, s0, 0), at(ri, s0, h), at(ri, s1, h), u1, 0, u0, h / rep)       -- inside
    quad(b, at(ro, s0, h), at(ro, s1, h), at(ri, s1, h), at(ri, s0, h), u0, 0, u1, thick / rep)   -- top
  end
  return finish(b, false)                              -- smooth normals: the curve looks round
end

-- soft light halo: three crossed quads with a texture that fades to black. With "glow" (additive) black adds
-- nothing, so the blob looks round from every side without turning it towards the camera.
local function makeHalo()
  local b = builder()
  local s = 0.5
  quad(b, {-s, -s, 0}, {s, -s, 0}, {s, s, 0}, {-s, s, 0}, 0, 0, 1, 1)
  quad(b, {0, -s, s}, {0, -s, -s}, {0, s, -s}, {0, s, s}, 0, 0, 1, 1)
  quad(b, {-s, 0, s}, {s, 0, s}, {s, 0, -s}, {-s, 0, -s}, 0, 0, 1, 1)
  return finish(b, true)
end

-- ------------------------------------------------------------------ 3. textures
-- mesh:setTexture exists since SDK 1.1 and draws on the GPU path. The check keeps the demo running (with plain
-- colours) on systems or tools that do not have it.
local textured = {}
local function texture(mesh, path, color)
  mesh:setColor(color)                                 -- used when there is no texture (CPU fallback)
  textured[#textured + 1] = {mesh = mesh, path = path}
  if mesh.setTexture then mesh:setTexture(path) end
end
local function setTextures(on)
  for _, t in ipairs(textured) do
    if t.mesh.setTexture then t.mesh:setTexture(on and t.path or nil) end
  end
end

-- ------------------------------------------------------------------ state
local M = {}                                           -- meshes
local cam = {yaw = 0.7, pitch = 0.42, dist = 9, tx = 0, ty = 0.9, tz = 0}
local opts = {sun = 0.32, ambient = 0.3, fog = 26, textures = true, auto = true, wire = false, labels = true,
              autoSun = false}
local panelOpen = true
local drag = nil                                       -- {x, y} while orbiting with the pointer
local idle = 0
local tris = 0
local labels = {}
local PANEL_W = 250
local keys = {}                                        -- keyboard keys held (input.down only knows controller buttons)

function app.load()
  M.floor = makeFloor(18, 9, 9)
  texture(M.floor, "bundle:/tex/tiles.png", "#B8B0A0")
  M.crate = makeCrate(0.45)
  texture(M.crate, "bundle:/tex/crate.png", "#A06A3A")
  M.pedestal = makePrism(8, 1.1, 1.0)
  texture(M.pedestal, "bundle:/tex/marble.png", "#D8D4DC")
  M.wall = makeArcWall(6.5, pi * 0.55, pi * 1.45, 2.4, 0.5, 24)
  texture(M.wall, "bundle:/tex/bricks.png", "#A85038")
  M.halo = makeHalo()
  texture(M.halo, "bundle:/tex/glow.png", "#FFD9A0")
  -- primitives come with texture coordinates too
  M.ball = g3d.mesh("sphere", 0.62, 40, 24)
  texture(M.ball, "bundle:/tex/marble.png", "#E8E4F0")
  M.ring = g3d.mesh("torus", 1.0, 0.07, 48, 12)
  M.ring:setColor("#FFC24A")
  M.post = g3d.mesh("cylinder", 0.08, 1.6, 12)
  M.post:setColor("#2E3440")
  M.lamp = g3d.mesh("sphere", 0.16, 16, 10)
  M.lamp:setColor("#FFF2C8")
  local saved = store.get("view", nil)
  if type(saved) == "table" then
    for k, v in pairs(saved) do if opts[k] ~= nil and type(v) == type(opts[k]) then opts[k] = v end end
  end
  setTextures(opts.textures)
  panelOpen = select(1, gfx.size()) >= 560
end

-- ------------------------------------------------------------------ 4. sun, sky and fog from the time of day
local function mix(a, b, t) return a + (b - a) * t end
local function rgb(r, g, b) return string.format("#%02X%02X%02X", floor(r), floor(g), floor(b)) end

local function environment()
  local a = opts.sun * pi                              -- 0 = sunrise (east), 0.5 = noon, 1 = sunset (west)
  local elev = sin(a)                                  -- 0 at the horizon, 1 straight up
  local lx, ly, lz = cos(a), 0.08 + elev, 0.45
  local warm = 1 - min(1, elev * 2.2)                  -- low sun: orange light and sky
  local sunColor = rgb(255, mix(250, 170, warm), mix(235, 110, warm))
  local horizon = {mix(170, 250, warm), mix(205, 160, warm), mix(235, 120, warm)}
  local zenith = {mix(60, 70, warm), mix(120, 70, warm), mix(200, 140, warm)}
  return lx, ly, lz, sunColor, horizon, zenith
end

-- ------------------------------------------------------------------ update
function app.update(dt)
  -- keyboard orbit
  -- arrow keys (the controller's D-pad sends them too while it drives the cursor)
  if keys.left then cam.yaw = cam.yaw - 1.6 * dt; idle = 0 end
  if keys.right then cam.yaw = cam.yaw + 1.6 * dt; idle = 0 end
  if keys.up then cam.pitch = min(1.35, cam.pitch + 1.2 * dt); idle = 0 end
  if keys.down then cam.pitch = max(0.05, cam.pitch - 1.2 * dt); idle = 0 end
  idle = idle + dt
  if opts.auto and not drag and idle > 2 then cam.yaw = cam.yaw + 0.18 * dt end   -- slow turntable when idle
  if opts.autoSun then opts.sun = (opts.sun + dt * 0.03) % 1 end
end

-- ------------------------------------------------------------------ 5. orbit camera input
local function inPanel(x, y)
  return panelOpen and x < PANEL_W + 16 and y < 330
end

function app.event(e)
  if e.type == "keydown" then keys[e.key] = true elseif e.type == "keyup" then keys[e.key] = nil end
  if e.type == "mousedown" and e.button == "left" and not inPanel(e.x, e.y) and not (e.x < 56 and e.y < 56) then
    drag = {x = e.x, y = e.y}
  elseif e.type == "mousemove" and drag then
    cam.yaw = cam.yaw - (e.x - drag.x) * 0.008
    cam.pitch = max(0.05, min(1.35, cam.pitch + (e.y - drag.y) * 0.006))
    drag.x, drag.y = e.x, e.y
    idle = 0
  elseif e.type == "mouseup" then
    drag = nil
  elseif e.type == "scroll" and not e.touch then
    cam.dist = max(3, min(22, cam.dist * (1 + e.dy * 0.002)))      -- wheel / right stick
    idle = 0
  elseif e.type == "pinch" then
    cam.dist = max(3, min(22, cam.dist / e.scale))                   -- fingers apart = closer
    idle = 0
  elseif e.type == "keydown" then
    if e.key == "t" then opts.textures = not opts.textures; setTextures(opts.textures) end
    if e.key == "w" then opts.wire = not opts.wire end
    if e.key == "tab" then panelOpen = not panelOpen end
  end
end

-- ------------------------------------------------------------------ drawing
local function drawScene(w, h, t)
  local lx, ly, lz, sunColor, horizon, zenith = environment()
  local fogColor = rgb(horizon[1], horizon[2], horizon[3])
  local cp = cos(cam.pitch)
  local ex = cam.tx + cam.dist * cp * sin(cam.yaw)
  local ey = cam.ty + cam.dist * sin(cam.pitch)
  local ez = cam.tz + cam.dist * cp * cos(cam.yaw)

  g3d.begin(0, 0, w, h, 55, 0.1, 80)
  g3d.camera(ex, ey, ez, cam.tx, cam.ty, cam.tz)
  g3d.light(lx, ly, lz, opts.ambient, sunColor)
  g3d.fog(fogColor, opts.fog * 0.35, opts.fog)
  local f = opts.wire and "wire" or nil
  local gpu = g3d.gpu()

  g3d.draw(M.floor, 0, 0, 0, 0, 0, 0, 1, 1, 1, nil, f)
  g3d.draw(M.wall, 0, 0, 0, 0, 0, 0, 1, 1, 1, nil, f)
  g3d.draw(M.pedestal, 0, 0, 0, 0, t * 0.1, 0, 1, 1, 1, nil, f)
  g3d.draw(M.ball, 0, 1.65 + sin(t * 1.5) * 0.08, 0, 0, t * 0.6, 0, 1, 1, 1, nil, f)
  g3d.draw(M.ring, 0, 1.65, 0, 1.1 + sin(t * 0.7) * 0.2, t * 0.9, 0.3, 1, 1, 1, nil, f)
  -- crates: two on the floor, one on top, each turned a little
  g3d.draw(M.crate, 3.0, 0.45, 1.4, 0, 0.3, 0, 1, 1, 1, nil, f)
  g3d.draw(M.crate, 3.3, 0.45, 2.5, 0, -0.2, 0, 1, 1, 1, nil, f)
  g3d.draw(M.crate, 3.1, 1.35, 1.9, 0, 0.9, 0, 1, 1, 1, nil, f)
  -- two lamp posts with glowing halos (drawn last by the renderer, they never hide anything)
  local lamps = {{-2.6, 2.6}, {2.4, -2.8}}
  for i, L in ipairs(lamps) do
    g3d.draw(M.post, L[1], 0.8, L[2], 0, 0, 0, 1, 1, 1, nil, f)
    g3d.draw(M.lamp, L[1], 1.68, L[2], 0, 0, 0, 1, 1, 1, nil, "unlit")
    if gpu then                                        -- the CPU fallback has no textures: skip the halos
      local pulse = 1.6 + sin(t * 3 + i) * 0.12
      g3d.draw(M.halo, L[1], 1.68, L[2], 0, 0, 0, pulse, pulse, pulse, "#FFB060", "glow unlit nocull")
    end
  end
  -- the sun, far away in the light direction
  local d = 30 / sqrt(lx * lx + ly * ly + lz * lz)
  if gpu then g3d.draw(M.halo, lx * d, ly * d, lz * d, 0, 0, 0, 7, 7, 7, sunColor, "glow unlit nocull") end
  g3d.point(lx * d, ly * d, lz * d, 10, sunColor)
  -- 6. world -> screen for the labels; project must be called before finish
  labels[1] = {TR("label_pedestal"), g3d.project(0, 2.5, 0)}
  labels[2] = {TR("label_crates"), g3d.project(3.1, 2.1, 1.9)}
  labels[3] = {TR("label_wall"), g3d.project(-6.5 * 0.95, 2.7, 0)}
  tris = g3d.finish()
  return horizon, zenith
end

local function drawLabels()
  for _, L in ipairs(labels) do
    local text, sx, sy = L[1], L[2], L[3]
    if sx then                                         -- nil when the point is behind the camera
      local tw = gfx.textWidth(text, 12, "semibold") + 16
      gfx.rect(sx - tw / 2, sy - 12, tw, 22, 11, "#000000A0")
      gfx.color("#FFFFFF")
      gfx.text(text, sx - tw / 2, sy - 8, 12, "semibold", "center", tw)
    end
  end
end

local function row(label, y)
  gfx.color(theme.text)
  gfx.text(label, 28, y + 6, 13)
end

local function drawPanel(w, h)
  if not panelOpen then return end
  local x, y, pw = 12, 60, PANEL_W
  gfx.shadow(x, y, pw, 268, 12, 16, 4)
  gfx.rect(x, y, pw, 268, 12, theme.window)
  local sx = x + 96
  local sw = pw - 110
  row(TR("sun"), y + 12)
  opts.sun = ui.slider("sun", opts.sun, 0, 1, sx, y + 10, sw)
  row(TR("ambient"), y + 46)
  opts.ambient = ui.slider("amb", opts.ambient, 0, 0.8, sx, y + 44, sw)
  row(TR("fog"), y + 80)
  opts.fog = ui.slider("fog", opts.fog, 8, 60, sx, y + 78, sw)
  ui.separator(x + 16, y + 116, x + pw - 16)
  local toggles = {{"textures", TR("textures")}, {"auto", TR("auto_orbit")}, {"autoSun", TR("auto_sun")},
                   {"wire", TR("wireframe")}}
  for i, tg in ipairs(toggles) do
    local ty = y + 124 + (i - 1) * 34
    row(tg[2], ty)
    local v = ui.toggle("tg_" .. tg[1], opts[tg[1]], x + pw - 62, ty + 2)
    if v ~= opts[tg[1]] then
      opts[tg[1]] = v
      if tg[1] == "textures" then setTextures(v) end
      store.set("view", opts)
    end
  end
  gfx.color(theme.text2)
  gfx.text(TR("stats", tris, g3d.gpu() and "GPU" or "CPU", floor(sys.fps() + 0.5)), x + 16, y + 268 - 22, 11)
end

function app.draw(w, h)
  local t = sys.time()
  -- sky: a gradient behind the 3D view, matched to the fog colour at the horizon
  local _, _, _, _, horizon, zenith = environment()
  gfx.gradient(0, 0, w, h, rgb(zenith[1], zenith[2], zenith[3]), rgb(horizon[1], horizon[2], horizon[3]))
  drawScene(w, h, t)
  if opts.labels then drawLabels() end
  if ui.iconButton("tune", 12, 12, 36, 36, nil, panelOpen) then panelOpen = not panelOpen end
  gfx.color("#FFFFFF")
  gfx.text(TR("hint"), 56, 22, 12, "semibold")
  drawPanel(w, h)
end

function app.menu()
  return {{title = TR("menu_title"), items = {
    {label = TR("textures"), id = 1, shortcut = "T"},
    {label = TR("wireframe"), id = 2, shortcut = "W"},
    {label = TR("labels"), id = 3},
    "-",
    {label = TR("reset_view"), id = 4},
  }}}
end

function app.onmenu(id)
  if id == 1 then opts.textures = not opts.textures; setTextures(opts.textures)
  elseif id == 2 then opts.wire = not opts.wire
  elseif id == 3 then opts.labels = not opts.labels
  elseif id == 4 then cam.yaw, cam.pitch, cam.dist = 0.7, 0.42, 9 end
  store.set("view", opts)
end

function app.close()
  store.set("view", opts)
  return true
end

return app
