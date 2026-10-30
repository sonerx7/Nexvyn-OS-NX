-- Effects demo: three classic demoscene effects drawn with nothing but gfx.rect, gfx.line and colours.
--
-- What this file teaches:
--   1. a "pixel" grid: the window is split into cells (4-16 px) and every cell is one gfx.rect;
--      the cell size slider trades sharpness for speed, and the FPS counter shows the effect live
--   2. look-up tables (LUTs): everything that does not change with time (angles, distances, palettes) is
--      computed once per window size into flat arrays, so the per-frame loop only adds and indexes
--   3. trig identities to share work: sin(a + b) = sin a cos b + cos a sin b with per-column and per-row tables
--   4. run merging: neighbouring cells of the same colour on a row are drawn as one wider rectangle
--   5. a starfield: 3D points projected with x / z, drawn as dots or as streaks at warp speed
--   6. palettes as three arrays (r, g, b) indexed by an integer, cycled over time

local app = {}
local sin, cos, sqrt, atan, floor, ceil, min, max, pi, abs = math.sin, math.cos, math.sqrt, math.atan, math.floor,
  math.ceil, math.min, math.max, math.pi, math.abs
local random = math.random

local set = {effect = 1, cell = 8, palette = 1, speed = 0.5, cycle = true}
local PAL_N = 64                      -- palette entries; few entries = longer runs of equal colour (4.)

-- ------------------------------------------------------------------ 6. palettes
local PR, PG, PB = {}, {}, {}
local function buildPalette(kind)
  for i = 0, PAL_N - 1 do
    local f = i / PAL_N
    local r, g, b
    if kind == 1 then          -- fire: black -> red -> yellow -> white -> back
      local k = 0.5 - 0.5 * cos(f * 2 * pi)
      r, g, b = min(1, k * 1.8), max(0, k * 1.6 - 0.45), max(0, k * 2 - 1.4)
    elseif kind == 2 then      -- ocean
      local k = 0.5 - 0.5 * cos(f * 2 * pi)
      r, g, b = k * 0.15, 0.25 + k * 0.6, 0.45 + k * 0.55
    elseif kind == 3 then      -- neon: magenta / cyan
      r = 0.5 + 0.5 * sin(f * 2 * pi)
      g = 0.15 + 0.35 * sin(f * 4 * pi + 1)
      b = 0.6 + 0.4 * cos(f * 2 * pi)
    else                       -- rainbow
      r = 0.5 + 0.5 * sin(f * 2 * pi)
      g = 0.5 + 0.5 * sin(f * 2 * pi + 2.094)
      b = 0.5 + 0.5 * sin(f * 2 * pi + 4.189)
    end
    PR[i], PG[i], PB[i] = floor(r * 255), floor(g * 255), floor(b * 255)
  end
end

-- ------------------------------------------------------------------ 2. look-up tables
local lut = {w = 0, h = 0, cell = 0}
local function buildLUT(w, h, cell)
  lut.w, lut.h, lut.cell = w, h, cell
  local cols, rows = ceil(w / cell), ceil(h / cell)
  lut.cols, lut.rows = cols, rows
  local cx, cy = cols / 2, rows / 2
  local maxD = sqrt(cx * cx + cy * cy)
  -- plasma: per column / row frequencies, per cell distance from the centre
  lut.sx, lut.cx, lut.sy, lut.cy = {}, {}, {}, {}
  for c = 0, cols - 1 do
    local a = c * cell * 0.011
    lut.sx[c], lut.cx[c] = sin(a), cos(a)
  end
  for r = 0, rows - 1 do
    local a = r * cell * 0.013
    lut.sy[r], lut.cy[r] = sin(a), cos(a)
  end
  -- per cell: radial term for the plasma, angle / depth / shade for the tunnel
  lut.sd, lut.cd, lut.ang, lut.depth, lut.shade = {}, {}, {}, {}, {}
  for r = 0, rows - 1 do
    for c = 0, cols - 1 do
      local i = r * cols + c + 1
      local dx, dy = c - cx + 0.5, r - cy + 0.5
      local d = sqrt(dx * dx + dy * dy)
      local dp = d * cell * 0.02
      lut.sd[i], lut.cd[i] = sin(dp), cos(dp)
      lut.ang[i] = (atan(dy, dx) / (2 * pi)) % 1          -- 0..1 around the centre
      lut.depth[i] = 32 / max(d * cell / 12, 0.5)           -- far away in the middle, near at the edges
      lut.shade[i] = min(1, d / maxD * 1.6)                 -- dark in the middle (fog)
    end
  end
end

-- draws one row of cells, merging equal colours (4.). idx[c] holds palette indexes, sh[c] brightness 0..1
local rowIdx, rowShade = {}, {}
local function flushRow(y, cols, cell)
  local c = 0
  while c < cols do
    local k, s = rowIdx[c], rowShade[c]
    local run = 1
    while c + run < cols and rowIdx[c + run] == k and rowShade[c + run] == s do run = run + 1 end
    gfx.color(floor(PR[k] * s), floor(PG[k] * s), floor(PB[k] * s))
    gfx.rect(c * cell, y, run * cell, cell)
    c = c + run
  end
end

-- ------------------------------------------------------------------ effects
local colTerm, rowTerm = {}, {}       -- reused every frame: no new tables in the draw loop
local function plasma(t, px, py)
  local cols, rows, cell = lut.cols, lut.rows, lut.cell
  local sx, cxs, sy, cys, sd, cd = lut.sx, lut.cx, lut.sy, lut.cy, lut.sd, lut.cd
  local ct, st = cos(t * 0.7), sin(t * 0.7)
  local c2, s2 = cos(t * 2.1 + px * 3), sin(t * 2.1 + px * 3)
  local shift = set.cycle and floor(t * 20) or 0
  -- term 1 sin(x + t), term 2 sin(y - 1.3t) as tables per column / row for this frame
  local s1, c1 = sin(t), cos(t)
  for c = 0, cols - 1 do colTerm[c] = sx[c] * c1 + cxs[c] * s1 end
  local s3, c3 = sin(-1.3 * t + py * 3), cos(-1.3 * t + py * 3)
  for r = 0, rows - 1 do rowTerm[r] = sy[r] * c3 + cys[r] * s3 end
  for r = 0, rows - 1 do
    local rt, syr, cyr = rowTerm[r], sy[r], cys[r]
    -- term 3 sin(x + y + 0.7t) = sin(x) cos(y + 0.7t) + cos(x) sin(y + 0.7t)  (3.)
    local cB, sB = cyr * ct - syr * st, syr * ct + cyr * st
    local base = r * cols + 1
    for c = 0, cols - 1 do
      local i = base + c
      local v = colTerm[c] + rt + (sx[c] * cB + cxs[c] * sB)
            + (sd[i] * c2 - cd[i] * s2)                       -- term 4: rings, sin(d - 2.1t)
      rowIdx[c] = (floor((v + 4) * PAL_N / 4) + shift) % PAL_N
      rowShade[c] = 1
    end
    flushRow(r * cell, cols, cell)
  end
end

local function tunnel(t, px, py)
  local cols, rows, cell = lut.cols, lut.rows, lut.cell
  local ang, depth, shade = lut.ang, lut.depth, lut.shade
  local twist = t * 0.15 + px
  local travel = t * (0.6 + set.speed * 2.5)
  local shift = set.cycle and floor(t * 12) or 0
  for r = 0, rows - 1 do
    local base = r * cols + 1
    for c = 0, cols - 1 do
      local i = base + c
      local u = ang[i] * 4 + twist
      local v = depth[i] + travel
      -- a checker texture wrapped on the inside of a pipe: u around it, v along it
      local check = (floor(u * 4) + floor(v * 2)) % 2
      rowIdx[c] = (floor(v * 6) + shift + check * PAL_N / 2) % PAL_N
      rowShade[c] = floor(shade[i] * 8 + 0.5) / 8              -- 9 levels: keeps runs long
    end
    flushRow(r * cell, cols, cell)
  end
end

-- 5. starfield
local stars = {n = 0, x = {}, y = {}, z = {}, pz = {}}
local function resetStar(i, far)
  stars.x[i] = (random() * 2 - 1) * 1.6
  stars.y[i] = (random() * 2 - 1) * 1.0
  stars.z[i] = far and 4 or (0.2 + random() * 3.8)
  stars.pz[i] = stars.z[i]
end
local function initStars(n)
  stars.n = n
  for i = 1, n do resetStar(i, false) end
end

local function starfield(w, h, dt, px, py)
  gfx.clear("#05060C")
  local cx, cy = w / 2 - px * w * 0.4, h / 2 - py * h * 0.4    -- steer: the vanishing point follows the pointer
  local scale = min(w, h) * 0.5
  local speed = 0.4 + set.speed * 6
  local warp = speed > 3
  local x, y, z, pz = stars.x, stars.y, stars.z, stars.pz
  for i = 1, stars.n do
    pz[i] = z[i]
    z[i] = z[i] - speed * dt
    if z[i] <= 0.05 then resetStar(i, true) end
    local sx, sy = cx + x[i] / z[i] * scale, cy + y[i] / z[i] * scale
    if sx < -50 or sx > w + 50 or sy < -50 or sy > h + 50 then
      resetStar(i, true)
    else
      local near = 1 - z[i] / 4                              -- 0 far .. 1 near
      local k = floor(near * (PAL_N - 1))                    -- tint the stars with the palette
      local b = 0.35 + near * 0.65
      gfx.color(floor(min(255, PR[k] * 0.4 + 150) * b), floor(min(255, PG[k] * 0.4 + 150) * b),
                floor(min(255, PB[k] * 0.4 + 150) * b))
      if warp and pz[i] > z[i] then
        local ox, oy = cx + x[i] / pz[i] * scale, cy + y[i] / pz[i] * scale
        gfx.line(ox, oy, sx, sy, 1 + near * 2)
      else
        local s = 1 + near * 3
        gfx.rect(sx - s / 2, sy - s / 2, s, s)
      end
    end
  end
end

-- ------------------------------------------------------------------ app
local pointer = {x = 0, y = 0, tx = 0, ty = 0}               -- -0.5..0.5, smoothed
local dragging = false
local lastT = 0

function app.load()
  local saved = store.get("fx", nil)
  if type(saved) == "table" then
    for k, v in pairs(saved) do if set[k] ~= nil and type(v) == type(set[k]) then set[k] = v end end
  end
  buildPalette(set.palette)
  initStars(500)
  lastT = sys.time()
end

function app.event(e)
  if e.type == "mousedown" and e.y > 64 then dragging = true end
  if e.type == "mouseup" then dragging = false end
  if (e.type == "mousemove" and dragging) or e.type == "mousedown" then
    local w, h = gfx.size()
    pointer.tx, pointer.ty = e.x / w - 0.5, e.y / h - 0.5
  end
  if e.type == "keydown" then
    local n = tonumber(e.key)
    if n and n >= 1 and n <= 3 then set.effect = n; store.set("fx", set) end
    if e.key == "c" then set.cycle = not set.cycle; store.set("fx", set) end
  end
end

local function bar(w)
  local twoRows = w < 760
  local bh = twoRows and 96 or 54
  gfx.rect(0, 0, w, bh, 0, "#000000A8")
  local changed = false
  local ne = ui.segmented("fx", {TR("plasma"), TR("tunnel"), TR("starfield")}, set.effect, 12, 12, 300, 30)
  if ne ~= set.effect then set.effect = ne; changed = true end
  local x, y = 324, 12
  if twoRows then x, y = 12, 54 end
  local np = ui.dropdown("pal", {TR("pal_fire"), TR("pal_ocean"), TR("pal_neon"), TR("pal_rainbow")}, set.palette,
                         x, y, 130, 30)
  if np ~= set.palette then set.palette = np; buildPalette(np); changed = true end
  x = x + 142
  gfx.color("#FFFFFF")
  if set.effect == 3 then
    gfx.text(TR("speed"), x, y + 7, 13, "semibold")
    local v = ui.slider("speed", set.speed, 0, 1, x + 70, y, 150)
    if v ~= set.speed then set.speed = v; changed = true end
  else
    gfx.text(TR("cell", set.cell), x, y + 7, 13, "semibold")
    local v = ui.slider("cell", set.cell, 4, 16, x + 70, y, 150, 1)
    if v ~= set.cell then set.cell = v; changed = true end
  end
  local nc = ui.checkbox(TR("cycle"), set.cycle, x + 236, y + 6)
  if nc ~= set.cycle then set.cycle = nc; changed = true end
  if changed then store.set("fx", set) end
  return bh
end

function app.draw(w, h)
  local now = sys.time()
  local dt = min(0.1, now - lastT)
  lastT = now
  local k = min(1, dt * 4)
  pointer.x = pointer.x + (pointer.tx - pointer.x) * k
  pointer.y = pointer.y + (pointer.ty - pointer.y) * k
  local cell = floor(set.cell)
  if set.effect ~= 3 and (lut.w ~= w or lut.h ~= h or lut.cell ~= cell) then buildLUT(w, h, cell) end
  if set.effect == 1 then plasma(now, pointer.x, pointer.y)
  elseif set.effect == 2 then tunnel(now, pointer.x, pointer.y)
  else starfield(w, h, dt, pointer.x, pointer.y) end
  local bh = bar(w)
  local info = set.effect == 3 and TR("info_stars", stars.n, floor(sys.fps() + 0.5))
    or TR("info_cells", lut.cols * lut.rows, floor(sys.fps() + 0.5))
  gfx.rect(10, h - 34, gfx.textWidth(info, 12, "semibold") + 20, 24, 12, "#000000A0")
  gfx.color("#FFFFFF")
  gfx.text(info, 20, h - 29, 12, "semibold")
  gfx.color("#FFFFFF90")
  gfx.text(TR("hint"), 0, bh + 8, 12, "semibold", "center", w)
end

function app.menu()
  return {{title = TR("menu_title"), items = {
    {label = TR("plasma"), id = 1, shortcut = "1"},
    {label = TR("tunnel"), id = 2, shortcut = "2"},
    {label = TR("starfield"), id = 3, shortcut = "3"},
    "-",
    {label = TR("cycle"), id = 4, shortcut = "C"},
  }}}
end

function app.onmenu(id)
  if id <= 3 then set.effect = id else set.cycle = not set.cycle end
  store.set("fx", set)
end

return app
