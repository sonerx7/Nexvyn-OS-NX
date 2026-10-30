-- Terrain demo: a procedural island (value noise + fBm), coloured by height and slope, with water, fog,
-- a minimap and a fly camera.
--
-- What this file teaches:
--   1. seeded value noise and fractal Brownian motion (several octaves of noise added together)
--   2. turning a height grid into one g3d.custom mesh with a colour per vertex
--   3. flat versus smooth shading (mesh:flat) for a low-poly or a soft look
--   4. a fly camera: forward/right vectors from yaw and pitch, sticks, keys and touch, terrain collision
--   5. debouncing expensive work with timer.after: sliders rebuild the island only after you stop moving them
--   6. picking the mesh size from g3d.gpu(): fewer triangles on the CPU fallback

local app = {}
local sin, cos, pi, sqrt, min, max, floor, abs = math.sin, math.cos, math.pi, math.sqrt, math.min, math.max,
  math.floor, math.abs

local SIZE = 64            -- the island is SIZE x SIZE world units, centred on the origin
local HEIGHT = 11          -- height of the highest peak

local cfg = {seed = 1234, rough = 0.5, scale = 1.0, water = 0.28, flat = true}
local N                    -- grid points per side (chosen in app.load)
local heights = {}         -- N*N heights in world units
local mesh, water
local mini = {}            -- minimap colours
local MINI = 32
local cam = {x = 0, y = 14, z = 30, yaw = 0, pitch = -0.25}
local idle, autopilot, autoT = 0, true, 0
local look = nil           -- pointer drag for looking around
local rebuildTimer = nil
local tris = 0
local buildMs = 0
local panelOpen, touchMove = true, 0
local keys = {}            -- keyboard keys held right now (input.down only knows controller buttons)

-- ------------------------------------------------------------------ 1. noise
local perm, vals = {}, {}

local function seedNoise(seed)
  local p = {}
  for i = 0, 255 do p[i] = i end
  local s = seed
  for i = 255, 1, -1 do                         -- Fisher-Yates shuffle with a tiny LCG: same seed, same island
    s = (s * 1103515245 + 12345) % 2147483648
    local j = s % (i + 1)
    p[i], p[j] = p[j], p[i]
  end
  for i = 0, 511 do perm[i] = p[i & 255] end
  for i = 0, 255 do
    s = (s * 1103515245 + 12345) % 2147483648
    vals[i] = s / 2147483648                     -- one random value per lattice hash
  end
end

local function lattice(ix, iy) return vals[perm[(ix & 255) + perm[iy & 255]]] end

-- smooth value noise: random values on integer points, blended with a smoothstep curve
local function noise(x, y)
  local ix, iy = floor(x), floor(y)
  local fx, fy = x - ix, y - iy
  local ux, uy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
  local a, b = lattice(ix, iy), lattice(ix + 1, iy)
  local c, d = lattice(ix, iy + 1), lattice(ix + 1, iy + 1)
  return a + (b - a) * ux + (c - a) * uy + (a - b - c + d) * ux * uy
end

-- fBm: each octave doubles the frequency and multiplies the amplitude by `rough`
local function fbm(x, y, octaves, rough)
  local sum, amp, freq, norm = 0, 1, 1, 0
  for _ = 1, octaves do
    sum = sum + noise(x * freq, y * freq) * amp
    norm = norm + amp
    amp, freq = amp * rough, freq * 2
  end
  return sum / norm
end

-- ------------------------------------------------------------------ 2. the mesh
local function lerp(a, b, t) return a + (b - a) * t end
local BANDS = {                                  -- height (0..1 of HEIGHT) -> colour
  {0.00, 194, 178, 128}, {0.06, 222, 206, 150}, {0.12, 98, 160, 64}, {0.35, 60, 125, 52},
  {0.55, 118, 108, 96}, {0.72, 150, 144, 138}, {0.82, 242, 244, 248}, {1.00, 255, 255, 255},
}
local function bandColor(h)
  for i = 1, #BANDS - 1 do
    local a, b = BANDS[i], BANDS[i + 1]
    if h <= b[1] then
      local t = (h - a[1]) / (b[1] - a[1])
      return lerp(a[2], b[2], t), lerp(a[3], b[3], t), lerp(a[4], b[4], t)
    end
  end
  local l = BANDS[#BANDS]
  return l[2], l[3], l[4]
end

local function heightAt(x, z)                   -- bilinear sample of the grid, for collision
  local gx = (x / SIZE + 0.5) * (N - 1)
  local gz = (z / SIZE + 0.5) * (N - 1)
  if gx < 0 or gz < 0 or gx >= N - 1 or gz >= N - 1 then return 0 end
  local i, j = floor(gx), floor(gz)
  local fx, fz = gx - i, gz - j
  local h00, h10 = heights[j * N + i + 1], heights[j * N + i + 2]
  local h01, h11 = heights[(j + 1) * N + i + 1], heights[(j + 1) * N + i + 2]
  return lerp(lerp(h00, h10, fx), lerp(h01, h11, fx), fz)
end

local function build()
  local t0 = os.clock()
  seedNoise(cfg.seed)
  local waterY = cfg.water * HEIGHT
  local V, I, C = {}, {}, {}
  -- heights: fBm, pushed down towards the edges so the land becomes an island
  for j = 0, N - 1 do
    for i = 0, N - 1 do
      local u, v = i / (N - 1) - 0.5, j / (N - 1) - 0.5
      local d = min(1, sqrt(u * u + v * v) * 2)
      local h = fbm(u * 5 * cfg.scale + 50, v * 5 * cfg.scale + 50, 6, cfg.rough)
      h = h * (1 - d ^ 2.4) * 1.5 - 0.12
      h = max(0, h) ^ 1.3                         -- flatter valleys, sharper peaks
      heights[j * N + i + 1] = h * HEIGHT
    end
  end
  -- vertices and colours: height bands, steep slopes turn to rock, a little noise breaks the stripes
  local step = SIZE / (N - 1)
  for j = 0, N - 1 do
    for i = 0, N - 1 do
      local k = j * N + i + 1
      local h = heights[k]
      V[#V + 1], V[#V + 2], V[#V + 3] = -SIZE / 2 + i * step, h, -SIZE / 2 + j * step
      local hx = heights[j * N + min(N - 1, i + 1) + 1] - heights[j * N + max(0, i - 1) + 1]
      local hz = heights[min(N - 1, j + 1) * N + i + 1] - heights[max(0, j - 1) * N + i + 1]
      local slope = sqrt(hx * hx + hz * hz) / (2 * step)
      local rel = (h - waterY) / (HEIGHT - waterY)
      local r, g, b
      if h < waterY + 0.25 then
        r, g, b = 214, 198, 140                    -- beach (and the sea floor)
      else
        r, g, b = bandColor(max(0, rel) + (noise(i * 0.7, j * 0.7) - 0.5) * 0.06)
        if slope > 0.9 and rel < 0.8 then
          local t = min(1, (slope - 0.9) * 1.5)
          r, g, b = lerp(r, 112, t), lerp(g, 104, t), lerp(b, 94, t)
        end
      end
      C[k] = {floor(r), floor(g), floor(b)}
    end
  end
  -- two triangles per grid cell, counter-clockwise seen from above
  for j = 0, N - 2 do
    for i = 0, N - 2 do
      local a = j * N + i + 1
      local b, c, d = a + 1, a + N, a + N + 1
      I[#I + 1], I[#I + 2], I[#I + 3] = a, c, b
      I[#I + 1], I[#I + 2], I[#I + 3] = b, c, d
    end
  end
  mesh = g3d.custom(V, I, C, cfg.flat)
  -- minimap colours (top view)
  for my = 0, MINI - 1 do
    for mx = 0, MINI - 1 do
      local i, j = floor(mx / (MINI - 1) * (N - 1)), floor(my / (MINI - 1) * (N - 1))
      local k = j * N + i + 1
      local c = C[k]
      if heights[k] < waterY then mini[my * MINI + mx + 1] = {40, 110, 180}
      else mini[my * MINI + mx + 1] = c end
    end
  end
  buildMs = floor((os.clock() - t0) * 1000)
end

-- 5. sliders call this on every change; the island is rebuilt once, 0.35 s after the last change
local function scheduleBuild()
  if rebuildTimer then timer.cancel(rebuildTimer) end
  rebuildTimer = timer.after(0.35, function()
    rebuildTimer = nil
    build()
    store.set("cfg", cfg)
  end)
end

function app.load()
  local saved = store.get("cfg", nil)
  if type(saved) == "table" then
    for k, v in pairs(saved) do if cfg[k] ~= nil and type(v) == type(cfg[k]) then cfg[k] = v end end
  end
  N = g3d.gpu() and 97 or 33                     -- 6. ~18k triangles on the GPU, ~2k on the CPU fallback
  water = g3d.mesh("plane", SIZE * 3, SIZE * 3, 8)
  water:setColor("#2F7FC8B0")                    -- alpha < 255: drawn after the land, see-through
  build()
end

-- ------------------------------------------------------------------ 4. fly camera
local function forward()
  local cp = cos(cam.pitch)
  return sin(cam.yaw) * cp, sin(cam.pitch), -cos(cam.yaw) * cp
end

function app.update(dt)
  local mx, mz, my, turn, tilt = 0, 0, 0, 0, 0
  -- left stick / WASD move, right stick / arrows look, ZR / E up, ZL / Q down
  local lx, ly = input.stick("left")
  local rx, ry = input.stick("right")
  if abs(lx) > 0.15 then mx = lx end
  if abs(ly) > 0.15 then mz = ly end
  if abs(rx) > 0.15 then turn = rx end
  if abs(ry) > 0.15 then tilt = ry end
  if keys.w then mz = 1 elseif keys.s then mz = -1 end
  if keys.d then mx = 1 elseif keys.a then mx = -1 end
  if keys.left or input.down("left") then turn = -1 elseif keys.right or input.down("right") then turn = 1 end
  if keys.up or input.down("up") then tilt = 1 elseif keys.down or input.down("down") then tilt = -1 end
  if input.down("zr") or keys.e then my = 1 elseif input.down("zl") or keys.q then my = -1 end
  if touchMove ~= 0 then mz = touchMove end
  local active = mx ~= 0 or mz ~= 0 or my ~= 0 or turn ~= 0 or tilt ~= 0 or look ~= nil
  if active then idle, autopilot = 0, false else idle = idle + dt end
  if idle > 6 and not autopilot then autopilot, autoT = true, 0 end

  if autopilot then
    -- a slow circle around the island, looking along the path and a little down
    autoT = autoT + dt * 0.06
    local r = SIZE * 0.42
    local tx, tz = cos(autoT) * r, sin(autoT) * r
    cam.x, cam.z = lerp(cam.x, tx, min(1, dt * 0.8)), lerp(cam.z, tz, min(1, dt * 0.8))
    local want = max(heightAt(cam.x, cam.z), cfg.water * HEIGHT) + 7
    cam.y = lerp(cam.y, want, min(1, dt * 0.6))
    local dirYaw = math.atan(-sin(autoT), -cos(autoT)) -- along the circle: forward = (sin yaw, -cos yaw)
    local d = (dirYaw - cam.yaw + pi) % (2 * pi) - pi
    cam.yaw = cam.yaw + d * min(1, dt * 1.2)
    cam.pitch = lerp(cam.pitch, -0.28, min(1, dt))
    return
  end

  cam.yaw = cam.yaw + turn * 1.8 * dt
  cam.pitch = max(-1.3, min(1.3, cam.pitch + tilt * 1.4 * dt))
  local speed = 14 * dt
  local fx, fy, fz = forward()
  local rxv, rzv = cos(cam.yaw), sin(cam.yaw)    -- right vector (horizontal)
  cam.x = cam.x + (fx * mz + rxv * mx) * speed
  cam.y = cam.y + (fy * mz + my) * speed
  cam.z = cam.z + (fz * mz + rzv * mx) * speed
  local lim = SIZE * 0.9
  cam.x, cam.z = max(-lim, min(lim, cam.x)), max(-lim, min(lim, cam.z))
  -- collision: stay a little above the ground (and the water), below a ceiling
  local floorY = max(heightAt(cam.x, cam.z), cfg.water * HEIGHT) + 0.8
  cam.y = max(floorY, min(40, cam.y))
end

function app.event(e)
  if e.type == "keydown" then keys[e.key] = true elseif e.type == "keyup" then keys[e.key] = nil end
  if e.type == "mousedown" and e.button == "left" and not (e.x < 290 and e.y < 330 and panelOpen) then
    look = {x = e.x, y = e.y}
  elseif e.type == "mousemove" and look then
    cam.yaw = cam.yaw + (e.x - look.x) * 0.006
    cam.pitch = max(-1.3, min(1.3, cam.pitch - (e.y - look.y) * 0.005))
    look.x, look.y = e.x, e.y
    idle, autopilot = 0, false
  elseif e.type == "mouseup" then
    look = nil
  elseif e.type == "keydown" and e.key == "f" then
    cfg.flat = not cfg.flat
    mesh:flat(cfg.flat)
  elseif e.type == "paddown" and e.pad == "y" then
    panelOpen = not panelOpen
  end
end

-- ------------------------------------------------------------------ drawing

local function drawMinimap(w, h)
  local cell = 3
  local size = MINI * cell
  local x0, y0 = w - size - 14, 14
  gfx.rect(x0 - 4, y0 - 4, size + 8, size + 8, 8, "#00000080")
  for my = 0, MINI - 1 do
    for mx = 0, MINI - 1 do
      local c = mini[my * MINI + mx + 1]
      gfx.color(c[1], c[2], c[3])
      gfx.rect(x0 + mx * cell, y0 + my * cell, cell, cell)
    end
  end
  -- camera marker and view direction
  local px = x0 + (cam.x / SIZE + 0.5) * size
  local py = y0 + (cam.z / SIZE + 0.5) * size
  if px > x0 and px < x0 + size and py > y0 and py < y0 + size then
    gfx.color("#FFFFFF")
    gfx.line(px, py, px + sin(cam.yaw) * 10, py - cos(cam.yaw) * 10, 2)
    gfx.circle(px, py, 3, "#FF4D4D")
  end
end

local function label(text, x, y)
  gfx.color(theme.text)
  gfx.text(text, x, y + 6, 13)
end

local function drawPanel(w, h)
  if not panelOpen then return end
  local x, y, pw = 12, 60, 270
  gfx.shadow(x, y, pw, 262, 12, 16, 4)
  gfx.rect(x, y, pw, 262, 12, theme.window)
  local sx, sw = x + 104, pw - 118
  label(TR("roughness"), x + 16, y + 12)
  local v = ui.slider("rough", cfg.rough, 0.3, 0.7, sx, y + 10, sw)
  if v ~= cfg.rough then cfg.rough = v; scheduleBuild() end
  label(TR("zoom"), x + 16, y + 46)
  v = ui.slider("scale", cfg.scale, 0.5, 2.0, sx, y + 44, sw)
  if v ~= cfg.scale then cfg.scale = v; scheduleBuild() end
  label(TR("water"), x + 16, y + 80)
  v = ui.slider("water", cfg.water, 0.05, 0.5, sx, y + 78, sw)
  if v ~= cfg.water then cfg.water = v; scheduleBuild() end
  label(TR("flat"), x + 16, y + 116)
  local f = ui.toggle("flat", cfg.flat, x + pw - 62, y + 116)
  if f ~= cfg.flat then cfg.flat = f; mesh:flat(f); store.set("cfg", cfg) end   -- 3. no rebuild needed
  if ui.button(TR("new_island"), x + 16, y + 156, pw - 32, 32, "primary", "shuffle") then
    cfg.seed = (cfg.seed * 7919 + 17) % 100000
    build()
    store.set("cfg", cfg)
    audio.play("pop")
  end
  gfx.color(theme.text2)
  gfx.text(TR("seed", cfg.seed, buildMs), x + 16, y + 200, 12)
  gfx.text(TR("stats", tris, g3d.gpu() and "GPU" or "CPU", floor(sys.fps() + 0.5)), x + 16, y + 220, 12)
  if rebuildTimer then ui.spinner(x + pw - 28, y + 206, 8) end
end

-- hold-to-fly buttons for touch (ui.hit reports `held` every frame the finger stays on it)
local function drawTouchButtons(w, h)
  touchMove = 0
  local size = 56
  local x, y = w - size - 18, h - size * 2 - 30
  local fwd = ui.hit("fly_fwd", x, y, size, size)
  local back = ui.hit("fly_back", x, y + size + 10, size, size)
  if fwd.held then touchMove = 1 elseif back.held then touchMove = -1 end
  gfx.rect(x, y, size, size, size / 2, fwd.held and "#FFFFFF60" or "#00000060")
  gfx.icon("arrow_upward", x + size / 2, y + size / 2, 28, "#FFFFFF")
  gfx.rect(x, y + size + 10, size, size, size / 2, back.held and "#FFFFFF60" or "#00000060")
  gfx.icon("arrow_downward", x + size / 2, y + size * 1.5 + 10, 28, "#FFFFFF")
end

function app.draw(w, h)
  local sky1, sky2 = "#5E9FE0", "#CFE6F7"
  gfx.gradient(0, 0, w, h, sky1, sky2)
  g3d.begin(0, 0, w, h, 65, 0.1, 140)
  local fx, fy, fz = forward()
  g3d.camera(cam.x, cam.y, cam.z, cam.x + fx, cam.y + fy, cam.z + fz)
  g3d.light(0.6, 0.8, 0.35, 0.38, "#FFF4E0")
  g3d.fog(sky2, 30, 110)
  g3d.draw(mesh, 0, 0, 0)
  g3d.draw(water, 0, cfg.water * HEIGHT + sin(sys.time() * 0.8) * 0.05, 0)
  tris = g3d.finish()

  drawMinimap(w, h)
  drawTouchButtons(w, h)
  if ui.iconButton("tune", 12, 12, 36, 36, nil, panelOpen) then panelOpen = not panelOpen end
  local msg = autopilot and TR("autopilot") or TR("controls")
  local size = min(12, 12 * (w - 56 - MINI * 3 - 40) / max(1, gfx.textWidth(msg, 12, "semibold")))  -- fit the width
  gfx.color("#FFFFFF")
  gfx.text(msg, 56, 30 - size * 0.65, size, "semibold")
  drawPanel(w, h)
end

function app.menu()
  return {{title = TR("menu_title"), items = {
    {label = TR("new_island"), id = 1},
    {label = TR("flat"), id = 2, shortcut = "F"},
    {label = TR("autopilot_menu"), id = 3},
  }}}
end

function app.onmenu(id)
  if id == 1 then cfg.seed = (cfg.seed * 7919 + 17) % 100000; build()
  elseif id == 2 then cfg.flat = not cfg.flat; mesh:flat(cfg.flat)
  elseif id == 3 then autopilot, autoT = true, 0 end
  store.set("cfg", cfg)
end

return app
