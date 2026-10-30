-- 3D Viewer: open .obj / .stl models or explore the built-in samples with an orbit / pan / zoom camera,
-- shaded / wireframe / combined display, auto-rotate, backgrounds and model info.
local app = {}
local Builder = require("builder")

local floor, min, max, abs, sqrt, sin, cos, pi, exp = math.floor, math.min, math.max, math.abs, math.sqrt, math.sin, math.cos, math.pi, math.exp

local TOOLBAR_H = 52

local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function c3(r, g, b) return {clamp(floor(r + 0.5), 0, 254), clamp(floor(g + 0.5), 0, 254), clamp(floor(b + 0.5), 0, 254)} end
local function hsv(h, s, v)
  h = (h % 360) / 60
  local i = floor(h)
  local f = h - i
  local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
  local r, g, b
  if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
  return c3(r * 255, g * 255, b * 255)
end

-- built-in samples ---------------------------------------------------------------------------
local function makeKnot()
  local b = Builder.new()
  local pts = {}
  local n = 96
  for k = 0, n - 1 do
    local t = k / n * 2 * pi
    local r = 0.62 + 0.28 * cos(3 * t)
    pts[#pts + 1] = {r * cos(2 * t), 0.28 * sin(3 * t), r * sin(2 * t)}
  end
  b:tube(pts, 0.13, 8, function(i, j, cnt) return hsv(i / cnt * 360, 0.62, 0.95) end, true)
  return b:mesh(false)
end

local function makeTree()
  local b = Builder.new()
  local s = 4242
  local function rnd() s = (s * 1103515245 + 12345) % 2147483648; return s / 2147483648 end
  b:prism("y", 0, -1.0, 0, 1.15, 0.14, 9, {104, 150, 70}, {112, 168, 76})
  b:prism("y", 0, -0.62, 0, 0.13, 0.66, 6, {116, 80, 52}, nil, 0.09)
  b:prism("y", 0, -0.08, 0, 0.78, 0.8, 8, {46, 122, 66}, {40, 104, 58}, 0, 0.1)
  b:prism("y", 0, 0.38, 0, 0.62, 0.72, 8, {58, 140, 74}, {48, 120, 64}, 0, 0.5)
  b:prism("y", 0, 0.8, 0, 0.44, 0.62, 8, {72, 158, 84}, {60, 136, 72}, 0, 0.9)
  b:sphere(0.65, -0.86, 0.35, 0.18, 6, 4, {130, 130, 126}, 0.25, rnd, 0.7)
  b:sphere(-0.55, -0.88, -0.5, 0.13, 6, 4, {120, 118, 112}, 0.25, rnd, 0.7)
  b:sphere(-0.6, -0.85, 0.45, 0.16, 6, 4, {200, 70, 60}, 0.05, rnd, 0.55)
  b:prism("y", -0.6, -0.9, 0.45, 0.04, 0.16, 5, {240, 236, 220})
  return b:mesh(true)
end

local function finPrism(b, dx, dz, col)
  -- triangular fin in the plane through the rocket axis and direction (dx, dz)
  local r0, th = 0.3, 0.035
  local px, pz = -dz, dx   -- thickness direction
  local prof = {{r0, -0.92}, {r0 + 0.42, -1.05}, {r0, -0.3}}
  local top, bot = {}, {}
  for k, p in ipairs(prof) do
    top[k] = {dx * p[1] + px * th, p[2], dz * p[1] + pz * th}
    bot[k] = {dx * p[1] - px * th, p[2], dz * p[1] - pz * th}
  end
  local cx, cy, cz = dx * (r0 + 0.14), -0.76, dz * (r0 + 0.14)
  b:tri(top[1], top[2], top[3], col, cx, cy, cz)
  b:tri(bot[1], bot[2], bot[3], col, cx, cy, cz)
  for k = 1, 3 do
    local k2 = k % 3 + 1
    b:quad(top[k], top[k2], bot[k2], bot[k], col, cx, cy, cz)
  end
end

local function makeRocket()
  local b = Builder.new()
  local white, red, dark, blue = {236, 238, 242}, {214, 52, 48}, {70, 74, 84}, {60, 120, 200}
  b:prism("y", 0, -0.45, 0, 0.3, 0.9, 16, white, white)
  b:prism("y", 0, 0.06, 0, 0.3, 0.12, 16, red, red)
  b:prism("y", 0, 0.42, 0, 0.3, 0.6, 16, white, white)
  b:prism("y", 0, 1.0, 0, 0.3, 0.56, 16, red, red, 0)
  b:prism("z", 0, 0.42, 0.29, 0.1, 0.06, 12, dark, {120, 190, 250})
  b:prism("y", 0, -0.98, 0, 0.24, 0.16, 12, dark, {40, 40, 44}, 0.17)
  b:prism("y", 0, -1.25, 0, 0, 0.38, 10, {255, 150, 40}, {255, 220, 120}, 0.15)
  for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do finPrism(b, d[1], d[2], red) end
  b:box(0, -1.5, 0, 1.3, 0.06, 1.3, {150, 152, 160}, {170, 172, 180})
  b:box(0.75, -0.6, 0, 0.08, 1.8, 0.08, {200, 90, 50})
  b:box(0.55, 0.0, 0, 0.4, 0.05, 0.05, {200, 90, 50})
  return b:mesh(true)
end

local function makeTeapot()
  local b = Builder.new()
  local porcelain, band = {228, 234, 242}, {60, 104, 190}
  local body = {{0, -0.75}, {0.5, -0.75}, {0.74, -0.66}, {0.9, -0.44}, {0.96, -0.16}, {0.92, 0.12}, {0.8, 0.34}, {0.64, 0.47}, {0.58, 0.5}}
  b:lathe(0, 0, body, 28, function(k) return (k == 5 or k == 6) and band or porcelain end)
  local lid = {{0.58, 0.5}, {0.56, 0.57}, {0.44, 0.65}, {0.22, 0.71}, {0.09, 0.74}, {0.11, 0.8}, {0.14, 0.86}, {0.1, 0.93}, {0, 0.95}}
  b:lathe(0, 0, lid, 24, function(k) return k >= 6 and band or porcelain end)
  -- spout (quadratic Bezier, tapering)
  local sp = {}
  for k = 0, 14 do
    local t = k / 14
    local p0, p1, p2 = {0.78, -0.28, 0}, {1.38, -0.22, 0}, {1.48, 0.42, 0}
    local u = 1 - t
    sp[#sp + 1] = {u * u * p0[1] + 2 * u * t * p1[1] + t * t * p2[1], u * u * p0[2] + 2 * u * t * p1[2] + t * t * p2[2], 0}
  end
  b:tube(sp, function(i, n) return 0.17 - 0.1 * (i - 1) / (n - 1) end, 10, porcelain, false)
  -- handle (arc on the other side)
  local hd = {}
  for k = 0, 16 do
    local a = (80 + 200 * k / 16) * pi / 180
    hd[#hd + 1] = {-0.86 + 0.44 * cos(a), -0.06 + 0.42 * sin(a), 0}
  end
  b:tube(hd, 0.075, 8, porcelain, false)
  return b:mesh(false)
end

local function makeGear()
  local b = Builder.new()
  local metal, side, hub = {176, 184, 196}, {140, 148, 162}, {90, 96, 108}
  local teeth, R, r, h = 14, 1.0, 0.8, 0.3
  local pts = {}
  for k = 0, teeth - 1 do
    local a0 = k / teeth * 2 * pi
    local da = 2 * pi / teeth
    pts[#pts + 1] = {cos(a0) * r, sin(a0) * r}
    pts[#pts + 1] = {cos(a0 + da * 0.18) * R, sin(a0 + da * 0.18) * R}
    pts[#pts + 1] = {cos(a0 + da * 0.42) * R, sin(a0 + da * 0.42) * R}
    pts[#pts + 1] = {cos(a0 + da * 0.6) * r, sin(a0 + da * 0.6) * r}
  end
  local n = #pts
  for k = 1, n do
    local p, q = pts[k], pts[k % n + 1]
    b:tri({0, h / 2, 0}, {p[1], h / 2, p[2]}, {q[1], h / 2, q[2]}, metal, 0, -5, 0)
    b:tri({0, -h / 2, 0}, {p[1], -h / 2, p[2]}, {q[1], -h / 2, q[2]}, metal, 0, 5, 0)
    -- side wall: winding centre just inside the edge
    local dx, dz = q[1] - p[1], q[2] - p[2]
    local l = sqrt(dx * dx + dz * dz)
    local nx, nz = dz / l, -dx / l
    local mx, mz = (p[1] + q[1]) / 2 - nx * 0.05, (p[2] + q[2]) / 2 - nz * 0.05
    b:quad({p[1], -h / 2, p[2]}, {q[1], -h / 2, q[2]}, {q[1], h / 2, q[2]}, {p[1], h / 2, p[2]}, side, mx, 0, mz)
  end
  b:prism("y", 0, h / 2 + 0.1, 0, 0.32, 0.2, 16, metal, hub)
  b:prism("y", 0, -h / 2 - 0.1, 0, 0.32, 0.2, 16, metal, hub)
  return b:mesh(true)
end

local SAMPLES = {
  {key = "m_knot", make = makeKnot},
  {key = "m_tree", make = makeTree},
  {key = "m_rocket", make = makeRocket},
  {key = "m_teapot", make = makeTeapot},
  {key = "m_gear", make = makeGear},
}

local BACKGROUNDS = {
  {key = "bg_night", top = "#2A3142", bottom = "#0B0D12", grid = {150, 160, 180, 60}, fog = nil},
  {key = "bg_studio", top = "#F2F3F6", bottom = "#B9BFCB", grid = {60, 70, 90, 50}},
  {key = "bg_sunset", top = "#3B2A5C", bottom = "#E3866A", grid = {255, 230, 210, 60}},
  {key = "bg_ocean", top = "#0E3A5C", bottom = "#06131F", grid = {120, 200, 255, 50}},
  {key = "bg_black", top = "#000000", bottom = "#000000", grid = {120, 120, 120, 60}},
}
local MATERIALS = {
  {key = "mat_original", tint = nil},
  {key = "mat_clay", tint = {226, 196, 170}},
  {key = "mat_blue", tint = {130, 170, 255}},
  {key = "mat_jade", tint = {120, 220, 170}},
  {key = "mat_gold", tint = {255, 206, 110}},
}
local MODE_KEYS = {"mode_shaded", "mode_wire", "mode_both"}

-- state ---------------------------------------------------------------------------------------
local model, modelName, modelTris, modelSample = nil, "", 0, 1
local isFile = false
local cache = {}
local mode, bgIdx, matIdx = 1, 1, 1
local autoRotate, showGrid, headlight, panMode = true, true, false, false
local yaw, pitch, dist = 0.6, 0.35, 4.6
local tx, ty, tz = 0, 0, 0
local spin = 0
local lastDx, lastDy = 0, 0
local rdrag = nil
local lastTris = 0
local held = {}
local loadError = nil

local function loadSample(i)
  modelSample = i
  if not cache[i] then cache[i] = SAMPLES[i].make() end
  model = cache[i]
  modelName = TR(SAMPLES[i].key)
  modelTris = model:triangles()
  isFile = false
  loadError = nil
  store.set("sample", i)
end

local function resetView()
  yaw, pitch, dist = 0.6, 0.35, 4.6
  tx, ty, tz = 0, 0, 0
  spin = 0
end

local function baseName(p)
  return p:match("([^/\\]+)$") or p
end

local function loadFile(path)
  if type(path) ~= "string" or path == "" then return end
  local lower = path:lower()
  if not (lower:sub(-4) == ".obj" or lower:sub(-4) == ".stl") then return end
  local m, err = g3d.load(path, 2.2)
  if not m then
    loadError = tostring(err or "?")
    ui.alert(TR("load_failed"), TR("load_failed_msg", baseName(path), loadError), {TR("ok")})
    audio.play("error")
    return
  end
  model = m
  model:setColor({214, 206, 196})
  modelName = baseName(path)
  modelTris = model:triangles()
  isFile = true
  loadError = nil
  if matIdx == 1 then matIdx = 2 end
  resetView()
  audio.play("pop")
end

local function openDialog()
  ui.openFile(function(p) if p then loadFile(p) end end, {".obj", ".stl"}, TR("open_title"))
end

local function nextSample(d)
  local i = isFile and (d > 0 and 1 or #SAMPLES) or ((modelSample - 1 + d) % #SAMPLES + 1)
  loadSample(i)
  resetView()
end

-- app -----------------------------------------------------------------------------------------
function app.load(arg)
  mode = store.get("mode", 1)
  bgIdx = store.get("bg", 1)
  matIdx = store.get("mat", 1)
  autoRotate = store.get("auto", true)
  showGrid = store.get("grid", true)
  headlight = store.get("headlight", false)
  if bgIdx < 1 or bgIdx > #BACKGROUNDS then bgIdx = 1 end
  if matIdx < 1 or matIdx > #MATERIALS then matIdx = 1 end
  if mode < 1 or mode > 3 then mode = 1 end
  local s = store.get("sample", 1)
  if s < 1 or s > #SAMPLES then s = 1 end
  loadSample(s)
  if arg and arg ~= "" then loadFile(arg) end
end

function app.open(arg)
  loadFile(arg)
end

local function pan(dx, dy)
  -- move the target in the camera plane
  local rx, rz = cos(yaw), -sin(yaw)
  local ux, uy, uz = -sin(pitch) * sin(yaw), cos(pitch), -sin(pitch) * cos(yaw)
  local k = dist * 0.0016
  tx = tx - (rx * dx) * k + ux * dy * k
  ty = ty + uy * dy * k
  tz = tz - (rz * dx) * k + uz * dy * k
end

function app.update(dt)
  dt = min(dt, 0.05)
  if autoRotate then spin = spin + dt * 0.5 end
  local lx, ly = input.stick("left")
  local rx, ry = input.stick("right")
  if abs(lx) > 0.15 then yaw = yaw - lx * dt * 2 end
  if abs(ly) > 0.15 then pitch = pitch + ly * dt * 1.5 end
  if abs(rx) > 0.15 or abs(ry) > 0.15 then pan(rx * dt * 500, -ry * dt * 500) end
  if input.down("zl") then dist = dist * exp(dt * 1.2) end
  if input.down("zr") then dist = dist * exp(-dt * 1.2) end
  if held.left then yaw = yaw + dt * 1.8 end
  if held.right then yaw = yaw - dt * 1.8 end
  if held.up then pitch = pitch + dt * 1.4 end
  if held.down then pitch = pitch - dt * 1.4 end
  pitch = clamp(pitch, -1.5, 1.5)
  dist = clamp(dist, 1.2, 30)
end

function app.draw(w, h)
  local bg = BACKGROUNDS[bgIdx]
  local vy, vh = TOOLBAR_H, h - TOOLBAR_H
  gfx.gradient(0, vy, w, vh, bg.top, bg.bottom)
  local light = bgIdx == 2

  -- orbit / pan by dragging in the viewport (drawn first so the toolbar wins)
  local hit = ui.hit("view", 0, vy, w, vh)
  if hit.pressed then lastDx, lastDy = 0, 0 end
  if hit.held and not rdrag then
    local ddx, ddy = hit.dx - lastDx, hit.dy - lastDy
    lastDx, lastDy = hit.dx, hit.dy
    if panMode then pan(ddx, ddy)
    else
      yaw = yaw - ddx * 0.01
      pitch = clamp(pitch + ddy * 0.008, -1.5, 1.5)
    end
  end

  local cp = cos(pitch)
  local ex, ey, ez = tx + dist * cp * sin(yaw), ty + dist * sin(pitch), tz + dist * cp * cos(yaw)
  g3d.begin(0, vy, w, vh, 45, 0.02, 200)
  g3d.camera(ex, ey, ez, tx, ty, tz)
  if headlight then g3d.light(ex - tx + 0.3, ey - ty + 1, ez - tz, 0.3)
  else g3d.light(0.5, 0.9, 0.6, 0.38) end
  if showGrid then
    local gy = -1.15
    for k = -10, 10 do
      local v = k * 0.25
      g3d.line(v, gy, -2.5, v, gy, 2.5, k == 0 and {220, 90, 90, 150} or bg.grid, k == 0 and 1.5 or 1)
      g3d.line(-2.5, gy, v, 2.5, gy, v, k == 0 and {90, 140, 230, 150} or bg.grid, k == 0 and 1.5 or 1)
    end
  end
  if model then
    local tint = MATERIALS[matIdx].tint
    if mode == 1 then
      g3d.draw(model, 0, 0, 0, 0, spin, 0, 1, 1, 1, tint)
    elseif mode == 2 then
      g3d.draw(model, 0, 0, 0, 0, spin, 0, 1, 1, 1, tint or (light and {60, 70, 90} or nil), "wire")
    else
      g3d.draw(model, 0, 0, 0, 0, spin, 0, 1, 1, 1, tint)
      g3d.draw(model, 0, 0, 0, 0, spin, 0, 1, 1, 1, {30, 34, 44}, "wire unlit")
    end
  end
  lastTris = g3d.finish()

  -- info overlay
  local ix, iy = 16, h - 96
  gfx.color(light and {255, 255, 255, 200} or {0, 0, 0, 140})
  gfx.rect(ix, iy, 300, 80, 12)
  gfx.color(light and theme.text or "#FFFFFF")
  gfx.text(modelName, ix + 14, iy + 10, 15, "bold")
  gfx.color(light and theme.text2 or {255, 255, 255, 190})
  gfx.text(TR("tri_info", modelTris, lastTris), ix + 14, iy + 34, 12, "mono")
  gfx.text(TR("fps_info", floor(sys.fps() + 0.5), isFile and TR("source_file") or TR("source_sample")), ix + 14, iy + 52, 12)
  if modelTris > 20000 then
    gfx.color(theme.orange)
    gfx.text(TR("large_warning"), ix, iy - 22, 12, "semibold")
  end
  gfx.color(light and {40, 44, 56, 150} or {255, 255, 255, 120})
  gfx.text(TR(panMode and "hint_pan" or "hint_orbit"), 0, h - 26, 11, "sans", "right", w - 16)

  -- toolbar
  gfx.color(theme.dark and "#1C1F26" or "#F6F7F9")
  gfx.rect(0, 0, w, TOOLBAR_H)
  gfx.color(theme.separator)
  gfx.rect(0, TOOLBAR_H - 1, w, 1)
  local x = 10
  if ui.button(TR("open"), x, 10, 92, 32, "primary", "folder_open") then openDialog() end
  x = x + 100
  -- model picker: the loaded file (if any) is listed first, then the samples
  local names = {}
  local off = isFile and 1 or 0
  if isFile then names[1] = modelName end
  for i, s in ipairs(SAMPLES) do names[i + off] = TR(s.key) end
  local cur = isFile and 1 or modelSample
  local ns = ui.dropdown("sample", names, cur, x, 10, 150, 32)
  if ns ~= cur and ns - off >= 1 then loadSample(ns - off); resetView() end
  x = x + 158
  local mnames = {}
  for i, k in ipairs(MODE_KEYS) do mnames[i] = TR(k) end
  local nm = ui.segmented("mode", mnames, mode, x, 10, 228, 32)
  if nm ~= mode then mode = nm; store.set("mode", mode) end
  x = x + 236
  local bnames = {}
  for i, b in ipairs(BACKGROUNDS) do bnames[i] = TR(b.key) end
  local nb = ui.dropdown("bg", bnames, bgIdx, x, 10, 110, 32)
  if nb ~= bgIdx then bgIdx = nb; store.set("bg", bgIdx) end
  x = x + 118
  -- material swatches
  for i, m in ipairs(MATERIALS) do
    local sx = x + (i - 1) * 26
    local sh = ui.hit("mat" .. i, sx, 13, 24, 26)
    local col = m.tint or {200, 200, 200}
    gfx.color(col)
    gfx.circle(sx + 12, 26, 9)
    if i == 1 then
      gfx.color(theme.text2)
      gfx.circleLine(sx + 12, 26, 9, 1.5)
    end
    if matIdx == i then
      gfx.color(theme.accent)
      gfx.circleLine(sx + 12, 26, 12, 2)
    end
    if sh.clicked then matIdx = i; store.set("mat", i) end
  end
  x = x + #MATERIALS * 26 + 6
  local icons = {
    {autoRotate and "sync" or "sync_disabled", autoRotate, function() autoRotate = not autoRotate; store.set("auto", autoRotate) end},
    {"grid_on", showGrid, function() showGrid = not showGrid; store.set("grid", showGrid) end},
    {"flashlight_on", headlight, function() headlight = not headlight; store.set("headlight", headlight) end},
    {"pan_tool", panMode, function() panMode = not panMode end},
    {"center_focus_strong", false, resetView},
  }
  for i, ic in ipairs(icons) do
    if ui.iconButton(ic[1], x + (i - 1) * 36, 10, 32, 32, nil, ic[2], "t" .. i) then ic[3]() end
  end
end

local HOLD = {left = true, right = true, up = true, down = true}

function app.event(e)
  if e.type == "mousedown" and e.button == "right" then
    rdrag = {e.x, e.y}
  elseif e.type == "mousemove" and rdrag then
    pan(e.x - rdrag[1], e.y - rdrag[2])
    rdrag = {e.x, e.y}
  elseif e.type == "mouseup" and e.button == "right" then
    rdrag = nil
  elseif e.type == "scroll" then
    dist = clamp(dist * exp(-e.dy * 0.004), 1.2, 30)
  elseif e.type == "keydown" then
    if HOLD[e.key] then held[e.key] = true
    elseif e.key == "w" then mode = mode % 3 + 1; store.set("mode", mode)
    elseif e.key == "r" then resetView()
    elseif e.key == "space" then autoRotate = not autoRotate; store.set("auto", autoRotate)
    elseif e.key == "g" then showGrid = not showGrid; store.set("grid", showGrid)
    elseif e.key == "o" then openDialog()
    elseif e.key == "n" or e.key == "pagedown" then nextSample(1)
    elseif e.key == "p" or e.key == "pageup" then nextSample(-1)
    elseif e.key == "b" then bgIdx = bgIdx % #BACKGROUNDS + 1; store.set("bg", bgIdx)
    end
  elseif e.type == "keyup" then
    held[e.key] = nil
  elseif e.type == "paddown" then
    if e.pad == "a" then mode = mode % 3 + 1; store.set("mode", mode)
    elseif e.pad == "y" then autoRotate = not autoRotate; store.set("auto", autoRotate)
    elseif e.pad == "x" then resetView()
    elseif e.pad == "b" then showGrid = not showGrid; store.set("grid", showGrid)
    elseif e.pad == "r" or e.pad == "right" then nextSample(1)
    elseif e.pad == "l" or e.pad == "left" then nextSample(-1)
    elseif e.pad == "up" then dist = clamp(dist * 0.85, 1.2, 30)
    elseif e.pad == "down" then dist = clamp(dist * 1.18, 1.2, 30)
    elseif e.pad == "plus" then bgIdx = bgIdx % #BACKGROUNDS + 1; store.set("bg", bgIdx)
    elseif e.pad == "minus" then openDialog()
    end
  end
end

function app.menu()
  local samples = {}
  for i, s in ipairs(SAMPLES) do samples[#samples + 1] = {label = TR(s.key), id = 10 + i} end
  return {
    {title = TR("file"), items = {{label = TR("open_dots"), id = 1, shortcut = "O"}}},
    {title = TR("view"), items = {
      {label = TR("mode_next"), id = 2, shortcut = "W"},
      {label = TR("toggle_rotate"), id = 3, shortcut = "Space"},
      {label = TR("toggle_grid"), id = 4, shortcut = "G"},
      {label = TR("toggle_headlight"), id = 5},
      {label = TR("next_bg"), id = 6, shortcut = "B"},
      "-",
      {label = TR("reset_view"), id = 7, shortcut = "R"},
    }},
    {title = TR("samples"), items = samples},
  }
end

function app.onmenu(id)
  if id == 1 then openDialog()
  elseif id == 2 then mode = mode % 3 + 1; store.set("mode", mode)
  elseif id == 3 then autoRotate = not autoRotate; store.set("auto", autoRotate)
  elseif id == 4 then showGrid = not showGrid; store.set("grid", showGrid)
  elseif id == 5 then headlight = not headlight; store.set("headlight", headlight)
  elseif id == 6 then bgIdx = bgIdx % #BACKGROUNDS + 1; store.set("bg", bgIdx)
  elseif id == 7 then resetView()
  elseif id > 10 and id <= 10 + #SAMPLES then loadSample(id - 10); resetView()
  end
end

return app
