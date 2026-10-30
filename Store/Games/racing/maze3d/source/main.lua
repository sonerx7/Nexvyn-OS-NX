-- 3D Maze: find the glowing exit of ten first-person labyrinths, from 5×5 to 25×25 rooms, against the clock.
-- Mazes are generated with a seeded recursive backtracker (the same maze every time for a level, so best times
-- compare), and the walls of a level are one g3d.custom mesh with coplanar faces merged.
local app = {}

local BS, WH, EYE = 2.0, 2.4, 1.15          -- block size, wall height, eye height
local RADIUS = 0.42                         -- player collision radius
local SIZES = {5, 7, 9, 11, 13, 15, 17, 19, 21, 25}
local THEMES = {
  {wall = "#B9A58A", wall2 = "#A38F75", floor = "#5B5148", ceil = "#2E2A27", fog = "#1A1715"},   -- sandstone
  {wall = "#5E8C4A", wall2 = "#4D7A3B", floor = "#3D3226", ceil = "#20301D", fog = "#121A10"},   -- hedge
  {wall = "#8FB8D8", wall2 = "#78A3C6", floor = "#DDE8F0", ceil = "#2B3D52", fog = "#16202B"},   -- ice
  {wall = "#9C6B5A", wall2 = "#86594A", floor = "#3A2A26", ceil = "#1E1513", fog = "#120C0B"},   -- brick
  {wall = "#7A6FA8", wall2 = "#665C92", floor = "#2C2840", ceil = "#17142A", fog = "#0D0B18"},   -- dusk
}

local screen = "title"         -- "title", "play", "done"
local level, unlocked = 1, 1
local best = {}                -- ["3"] = seconds
local G, GW, GH = {}, 0, 0     -- block grid: 1 wall, 0 open
local seen = {}                -- explored blocks for the minimap
local mesh, floorMesh, ceilMesh, exitMesh, orbMesh = nil, nil, nil, nil, nil
local px, pz, yaw = 0, 0, 0
local vel, turnVel = 0, 0
local ex, ez = 0, 0            -- exit position
local time, paused = 0, false
local bob, stepT = 0, 0
local bump = 0
local bigMap = false
local parts = {}
local result = nil             -- {time, newBest}
local touchDir = {f = false, b = false, l = false, r = false}
local held = {}
local anim = 0

-- ------------------------------------------------------------------ maze generation
local seed = 1
local function rnd(n)            -- deterministic LCG, 1..n
  seed = (seed * 1103515245 + 12345) % 2147483648
  return seed % n + 1
end

local function gen(n, lv)
  seed = 7919 * lv + 17
  GW, GH = n * 2 + 1, n * 2 + 1
  G = {}
  for i = 1, GW * GH do G[i] = 1 end
  local function open(x, y) G[y * GW + x + 1] = 0 end
  local visited = {}
  local stack = {{0, 0}}
  visited[0] = true
  open(1, 1)
  local dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
  while #stack > 0 do
    local c = stack[#stack]
    local cx, cy = c[1], c[2]
    local opts = {}
    for _, d in ipairs(dirs) do
      local nx, ny = cx + d[1], cy + d[2]
      if nx >= 0 and ny >= 0 and nx < n and ny < n and not visited[ny * n + nx] then opts[#opts + 1] = d end
    end
    if #opts == 0 then
      stack[#stack] = nil
    else
      local d = opts[rnd(#opts)]
      local nx, ny = cx + d[1], cy + d[2]
      visited[ny * n + nx] = true
      open(cx * 2 + 1 + d[1], cy * 2 + 1 + d[2])
      open(nx * 2 + 1, ny * 2 + 1)
      stack[#stack + 1] = {nx, ny}
    end
  end
end

local function wall(x, y)
  if x < 0 or y < 0 or x >= GW or y >= GH then return true end
  return G[y * GW + x + 1] == 1
end

-- ------------------------------------------------------------------ meshes
local function buildMeshes()
  local th = THEMES[(level - 1) % #THEMES + 1]
  local v, idx, col = {}, {}, {}
  local function vert(x, y, z, c)
    v[#v + 1] = x; v[#v + 1] = y; v[#v + 1] = z
    col[#col + 1] = c
    return #v // 3
  end
  -- quad with corners a, b, c, d (counter-clockwise when seen from the side the normal points to)
  local function quad(a, b, c, d, color)
    local i1, i2, i3, i4 = vert(a[1], a[2], a[3], color), vert(b[1], b[2], b[3], color), vert(c[1], c[2], c[3], color), vert(d[1], d[2], d[3], color)
    idx[#idx + 1] = i1; idx[#idx + 1] = i2; idx[#idx + 1] = i3
    idx[#idx + 1] = i1; idx[#idx + 1] = i3; idx[#idx + 1] = i4
  end
  -- faces along x (normal ±z) merged into runs; block (x, y) spans world x in [x*BS, (x+1)*BS], z likewise
  for y = 0, GH - 1 do
    for side = -1, 1, 2 do         -- -1: face towards -z (open block above), 1: towards +z
      local x = 0
      while x < GW do
        if wall(x, y) and not wall(x, y + side) then
          local x2 = x
          while x2 + 1 < GW and wall(x2 + 1, y) and not wall(x2 + 1, y + side) do x2 = x2 + 1 end
          local z = side == 1 and (y + 1) * BS or y * BS
          local x0, x1 = x * BS, (x2 + 1) * BS
          local c = (x + y) % 2 == 0 and th.wall or th.wall2
          if side == 1 then quad({x0, 0, z}, {x1, 0, z}, {x1, WH, z}, {x0, WH, z}, c)
          else quad({x1, 0, z}, {x0, 0, z}, {x0, WH, z}, {x1, WH, z}, c) end
          x = x2 + 1
        else
          x = x + 1
        end
      end
    end
  end
  for x = 0, GW - 1 do
    for side = -1, 1, 2 do         -- faces towards ±x
      local y = 0
      while y < GH do
        if wall(x, y) and not wall(x + side, y) then
          local y2 = y
          while y2 + 1 < GH and wall(x, y2 + 1) and not wall(x + side, y2 + 1) do y2 = y2 + 1 end
          local xx = side == 1 and (x + 1) * BS or x * BS
          local z0, z1 = y * BS, (y2 + 1) * BS
          local c = (x + y) % 2 == 0 and th.wall2 or th.wall
          if side == 1 then quad({xx, 0, z1}, {xx, 0, z0}, {xx, WH, z0}, {xx, WH, z1}, c)
          else quad({xx, 0, z0}, {xx, 0, z1}, {xx, WH, z1}, {xx, WH, z0}, c) end
          y = y2 + 1
        else
          y = y + 1
        end
      end
    end
  end
  mesh = g3d.custom(v, idx, col, true)
  local W, D = GW * BS, GH * BS
  floorMesh = g3d.custom({0, 0, 0, W, 0, 0, W, 0, D, 0, 0, D}, {1, 3, 2, 1, 4, 3}, {th.floor, th.floor, th.floor, th.floor}, true)
  ceilMesh = g3d.custom({0, WH, 0, W, WH, 0, W, WH, D, 0, WH, D}, {1, 2, 3, 1, 3, 4}, {th.ceil, th.ceil, th.ceil, th.ceil}, true)
  exitMesh = exitMesh or g3d.mesh("torus", 0.5, 0.12, 24, 10)
  orbMesh = orbMesh or g3d.mesh("sphere", 0.28, 18, 12)
  exitMesh:setColor("#FFD60A")
  orbMesh:setColor("#FFF3B0")
end

-- ------------------------------------------------------------------ level flow
local function blockAt(x, z) return math.floor(x / BS), math.floor(z / BS) end

local function reveal()
  local bx, by = blockAt(px, pz)
  for dy = -1, 1 do for dx = -1, 1 do seen[(by + dy) * GW + (bx + dx)] = true end end
  -- look along the corridor in the four directions
  for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
    local x, y = bx, by
    for _ = 1, 8 do
      x, y = x + d[1], y + d[2]
      seen[y * GW + x] = true
      seen[(y + d[1]) * GW + (x + d[2])] = true
      seen[(y - d[1]) * GW + (x - d[2])] = true
      if wall(x, y) then break end
    end
  end
end

local function startLevel(lv)
  level = math.max(1, math.min(#SIZES, lv))
  gen(SIZES[level], level)
  buildMeshes()
  px, pz = 1.5 * BS, 1.5 * BS
  yaw = wall(2, 1) and math.pi / 2 or 0     -- face the open corridor (yaw 0 looks towards +x)
  ex, ez = (GW - 1.5) * BS, (GH - 1.5) * BS
  vel, turnVel, time, bob, bump = 0, 0, 0, 0, 0
  seen = {}
  reveal()
  paused, result, parts = false, nil, {}
  screen = "play"
  anim = 0
  store.set("level", level)
  audio.tone(523, 0.1, 0.35, "triangle")
end

local function fmtTime(t)
  t = math.max(0, t or 0)
  return string.format("%d:%04.1f", math.floor(t / 60), t % 60)
end

local function confetti(w, h)
  local cols = {"#FFD60A", "#FF375F", "#30D158", "#0A84FF", "#BF5AF2"}
  for i = 1, 120 do
    parts[#parts + 1] = {x = w / 2 + math.random(-60, 60), y = h * 0.35, vx = math.random(-320, 320), vy = math.random(-520, -160),
      r = math.random() * 6.3, c = cols[i % 5 + 1], life = 2.2 + math.random()}
  end
end

local function finishLevel()
  local key = tostring(level)
  local prev = tonumber(best[key])
  local nb = not prev or time < prev
  if nb then best[key] = time; store.set("best", best) end
  if level >= unlocked and level < #SIZES then unlocked = level + 1; store.set("unlocked", unlocked) end
  result = {time = time, newBest = nb, prev = prev}
  screen = "done"
  local w, h = gfx.size()
  confetti(w, h)
  audio.play("notify")
  audio.tone(784, 0.15, 0.4, "triangle")
  sys.vibrate(0.5, 120)
end

-- ------------------------------------------------------------------ update
local function collides(x, z)
  local r = RADIUS
  local bx0, bx1 = math.floor((x - r) / BS), math.floor((x + r) / BS)
  local by0, by1 = math.floor((z - r) / BS), math.floor((z + r) / BS)
  for by = by0, by1 do
    for bx = bx0, bx1 do
      if wall(bx, by) then
        -- circle vs square: closest point of the block
        local cx = math.max(bx * BS, math.min(x, (bx + 1) * BS))
        local cz = math.max(by * BS, math.min(z, (by + 1) * BS))
        if (cx - x) ^ 2 + (cz - z) ^ 2 < r * r then return true end
      end
    end
  end
  return false
end

local function axis(neg, pos)
  local v = 0
  for _, k in ipairs(neg) do if held[k] then v = v - 1 end end
  for _, k in ipairs(pos) do if held[k] then v = v + 1 end end
  return math.max(-1, math.min(1, v))
end

function app.load()
  local b = store.get("best", {})
  best = type(b) == "table" and b or {}
  unlocked = math.max(1, math.min(#SIZES, store.get("unlocked", 1)))
  level = math.max(1, math.min(unlocked, store.get("level", 1)))
  if level > unlocked then level = unlocked end
end

function app.update(dt)
  dt = math.min(dt, 1 / 20)
  anim = math.min(1, anim + dt * 2)
  for i = #parts, 1, -1 do
    local p = parts[i]
    p.vy = p.vy + 600 * dt
    p.x, p.y, p.r, p.life = p.x + p.vx * dt, p.y + p.vy * dt, p.r + dt * 7, p.life - dt
    if p.life <= 0 then table.remove(parts, i) end
  end
  if screen ~= "play" or paused then return end
  time = time + dt
  bump = math.max(0, bump - dt)
  local lx, ly = input.stick("left")
  local rx = input.stick("right")
  local fwd = math.max(-1, math.min(1, ly - axis({"w", "up"}, {"s", "down"}) * 1))
  if touchDir.f then fwd = 1 elseif touchDir.b then fwd = -1 end
  if input.down("up") then fwd = 1 elseif input.down("down") then fwd = -1 end
  local turn = lx + rx + axis({"a", "left"}, {"d", "right"})
  if touchDir.l then turn = -1 elseif touchDir.r then turn = 1 end
  if input.down("left") then turn = -1 elseif input.down("right") then turn = 1 end
  turn = math.max(-1, math.min(1, turn))
  local strafe = axis({"q"}, {"e"})
  local run = (held["shift"] or input.down("zr") or input.down("r")) and 1.5 or 1
  -- smooth acceleration
  vel = vel + (fwd * 4.2 * run - vel) * math.min(1, dt * 8)
  turnVel = turnVel + (turn * 2.4 - turnVel) * math.min(1, dt * 10)
  yaw = yaw + turnVel * dt
  local dx, dz = math.cos(yaw), math.sin(yaw)
  local mx, mz = dx * vel * dt - dz * strafe * 3 * dt, dz * vel * dt + dx * strafe * 3 * dt
  local hit = false
  if not collides(px + mx, pz) then px = px + mx else hit = true end
  if not collides(px, pz + mz) then pz = pz + mz else hit = true end
  local speed = math.abs(vel)
  if hit and speed > 1.5 and bump <= 0 then
    bump = 0.35
    audio.tone(110, 0.08, 0.3, "triangle")
    sys.vibrate(0.25, 40)
  end
  bob = bob + dt * speed * 2.2
  stepT = stepT - dt * speed
  if stepT <= 0 and speed > 0.5 then
    stepT = 2.2
    audio.tone(160 + math.random(0, 3) * 20, 0.04, 0.12, "noise")
  end
  reveal()
  if (px - ex) ^ 2 + (pz - ez) ^ 2 < (BS * 0.55) ^ 2 then finishLevel() end
end

-- ------------------------------------------------------------------ drawing
local function drawWorld(w, h, t)
  local th = THEMES[(level - 1) % #THEMES + 1]
  gfx.clear(th.fog)
  if not mesh then return end
  local ey = EYE + math.sin(bob) * 0.04
  g3d.begin(0, 0, w, h, 72, 0.05, GW * BS * 1.5)
  g3d.camera(px, ey, pz, px + math.cos(yaw), ey, pz + math.sin(yaw))
  g3d.light(0.3, 1, 0.5, 0.45)
  g3d.fog(th.fog, BS * 3, BS * 11)
  g3d.draw(floorMesh)
  g3d.draw(ceilMesh)
  g3d.draw(mesh)
  local pulse = 1 + math.sin(t * 3) * 0.12
  g3d.draw(exitMesh, ex, EYE, ez, math.pi / 2, t * 1.2, 0, pulse, pulse, pulse, nil, "unlit glow")
  g3d.draw(orbMesh, ex, EYE + math.sin(t * 2) * 0.1, ez, 0, 0, 0, pulse, pulse, pulse, nil, "unlit glow")
  g3d.point(ex, EYE, ez, 10, "#FFD60A")
  g3d.finish()
end

local function drawMinimap(w, h)
  local cell = bigMap and math.max(3, math.floor(math.min(w * 0.6, h * 0.7) / GW)) or math.max(2, math.floor(150 / GW))
  local mw, mh = GW * cell, GH * cell
  local x0, y0 = bigMap and (w - mw) / 2 or w - mw - 14, bigMap and (h - mh) / 2 or 14
  gfx.alpha(bigMap and 0.95 or 0.85)
  gfx.rect(x0 - 6, y0 - 6, mw + 12, mh + 12, 8, "#000000AA")
  for y = 0, GH - 1 do
    local runStart, runKind = 0, -1
    for x = 0, GW do
      local kind = -1
      if x < GW and seen[y * GW + x] then kind = wall(x, y) and 1 or 0 end
      if kind ~= runKind then
        if runKind >= 0 then
          gfx.rect(x0 + runStart * cell, y0 + y * cell, (x - runStart) * cell, cell, 0, runKind == 1 and "#8E8E93" or "#2C2C2E")
        end
        runStart, runKind = x, kind
      end
    end
  end
  local ebx, eby = blockAt(ex, ez)
  if seen[eby * GW + ebx] then gfx.circle(x0 + (ebx + 0.5) * cell, y0 + (eby + 0.5) * cell, math.max(3, cell * 0.6), "#FFD60A") end
  local sx, sy = x0 + px / BS * cell, y0 + pz / BS * cell
  local a = math.max(4, cell * 1.2)
  local cx, cz = math.cos(yaw), math.sin(yaw)
  gfx.poly({sx + cx * a * 1.4, sy + cz * a * 1.4, sx - cx * a + cz * a * 0.8, sy - cz * a - cx * a * 0.8,
    sx - cx * a - cz * a * 0.8, sy - cz * a + cx * a * 0.8}, "#30D158")
  gfx.unalpha()
end

local function touchPad(w, h)
  local s = 54
  local x0, y0 = 18, h - s * 2 - 30
  local function btn(id, icon, x, y, key)
    local hit = ui.hit(id, x, y, s, s)
    touchDir[key] = hit.held
    gfx.alpha(hit.held and 0.75 or 0.4)
    gfx.rect(x, y, s, s, 14, "#000000")
    gfx.icon(icon, x + s / 2, y + s / 2, 30, "#FFFFFF")
    gfx.unalpha()
  end
  btn("tf", "arrow_upward", x0 + s + 6, y0, "f")
  btn("tb", "arrow_downward", x0 + s + 6, y0 + s + 6, "b")
  btn("tl", "rotate_left", x0, y0 + s / 2 + 3, "l")
  btn("tr", "rotate_right", x0 + 2 * (s + 6), y0 + s / 2 + 3, "r")
end

local function panel(w, h, pw, ph)
  local x, y = (w - pw) / 2, (h - ph) / 2
  gfx.shadow(x, y, pw, ph, 18, 22, 4)
  gfx.rect(x, y, pw, ph, 18, theme.window)
  return x, y
end

local function drawTitle(w, h, t)
  -- slow fly-through of level 1 behind the menu
  if not mesh then gen(SIZES[1], 1); buildMeshes(); px, pz = 1.5 * BS, 1.5 * BS end
  yaw = t * 0.25
  drawWorld(w, h, t)
  local pw, ph = math.min(460, w - 40), 330
  local x, y = panel(w, h, pw, ph)
  gfx.color(theme.text)
  gfx.text(TR("app_name"), x, y + 18, 30, "bold", "center", pw)
  gfx.color(theme.text2)
  gfx.text(TR("tagline"), x, y + 58, 13, "sans", "center", pw)
  -- level picker
  gfx.color(theme.text)
  gfx.text(TR("level_n", level, SIZES[level], SIZES[level]), x, y + 96, 18, "semibold", "center", pw)
  if ui.iconButton("chevron_left", x + 24, y + 92, 40, 32, nil, false, "lp") and level > 1 then level = level - 1 end
  if ui.iconButton("chevron_right", x + pw - 64, y + 92, 40, 32, nil, false, "ln") and level < unlocked then level = level + 1 end
  local b = tonumber(best[tostring(level)])
  gfx.color(b and theme.orange or theme.text3)
  gfx.text(b and TR("best_time", fmtTime(b)) or TR("no_time"), x, y + 130, 13, "sans", "center", pw)
  -- stars for unlocked levels
  local dots = #SIZES
  for i = 1, dots do
    local dx = x + pw / 2 + (i - (dots + 1) / 2) * 18
    gfx.circle(dx, y + 160, 5, i == level and theme.accent or (best[tostring(i)] and theme.green or (i <= unlocked and theme.text3 or theme.separator)))
  end
  if ui.button(TR("play"), x + pw / 2 - 100, y + 184, 200, 42, "primary", "play_arrow") then startLevel(level) end
  gfx.color(theme.text3)
  gfx.wrap(TR("controls"), x + 24, y + 240, pw - 48, 12, "sans", "center")
end

local function drawPause(w, h)
  gfx.rect(0, 0, w, h, 0, "#00000088")
  local pw, ph = 300, 220
  local x, y = panel(w, h, pw, ph)
  gfx.color(theme.text)
  gfx.text(TR("paused"), x, y + 18, 20, "bold", "center", pw)
  if ui.button(TR("resume"), x + 30, y + 60, pw - 60, 38, "primary", "play_arrow") then paused = false end
  if ui.button(TR("restart"), x + 30, y + 108, pw - 60, 38, "default", "refresh") then startLevel(level) end
  if ui.button(TR("menu"), x + 30, y + 156, pw - 60, 38, "default", "home") then paused = false; screen = "title" end
end

local function drawDone(w, h)
  local pw, ph = math.min(420, w - 40), 270
  local x, y = panel(w, h, pw, ph)
  gfx.icon("emoji_events", x + pw / 2, y + 40, 44, theme.yellow)
  gfx.color(theme.text)
  gfx.text(TR("escaped"), x, y + 70, 22, "bold", "center", pw)
  gfx.color(theme.accent)
  gfx.text(fmtTime(result.time), x, y + 102, 32, "bold", "center", pw)
  gfx.color(result.newBest and theme.orange or theme.text2)
  local msg = result.newBest and (result.prev and TR("new_best_by", fmtTime(result.prev - result.time)) or TR("first_time"))
    or TR("best_time", fmtTime(best[tostring(level)]))
  gfx.text(msg, x, y + 146, 14, result.newBest and "bold" or "sans", "center", pw)
  local bw = (pw - 60) / 2
  local last = level >= #SIZES
  if ui.button(last and TR("menu") or TR("next"), x + 20, y + 196, bw, 40, "primary", last and "home" or "skip_next") then
    if last then screen = "title" else startLevel(level + 1) end
  end
  if ui.button(TR("again"), x + 40 + bw, y + 196, bw, 40, "default", "refresh") then startLevel(level) end
end

function app.draw(w, h)
  local t = sys.time()
  if screen == "title" then
    drawTitle(w, h, t)
  else
    drawWorld(w, h, t)
    if screen == "play" then
      drawMinimap(w, h)
      gfx.color("#FFFFFF")
      gfx.text(TR("level_short", level) .. "   " .. fmtTime(time), 16, 14, 18, "semibold")
      if ui.iconButton("pause", 16, 44, 38, 34, "#FFFFFF", false, "pz") then paused = true end
      if ui.iconButton("map", 60, 44, 38, 34, "#FFFFFF", bigMap, "mp") then bigMap = not bigMap end
      if bump > 0 then gfx.alpha(bump); gfx.color("#FF3B30"); gfx.rectLine(0, 0, w, h, 0, 10); gfx.unalpha() end
      if input.touch() or touchDir.f or touchDir.b or touchDir.l or touchDir.r then touchPad(w, h) end
      if anim < 1 then
        gfx.alpha(1 - anim)
        gfx.color("#FFFFFF")
        gfx.text(TR("find_exit"), 0, h / 2 - 40, 26, "bold", "center", w)
        gfx.unalpha()
      end
      if paused then drawPause(w, h) end
    elseif screen == "done" and result then
      drawDone(w, h)
    end
  end
  for _, p in ipairs(parts) do
    gfx.color(p.c)
    gfx.poly({p.x + math.cos(p.r) * 6, p.y + math.sin(p.r) * 6, p.x + math.cos(p.r + 2.2) * 6, p.y + math.sin(p.r + 2.2) * 6,
      p.x + math.cos(p.r + 3.9) * 6, p.y + math.sin(p.r + 3.9) * 6})
  end
end

-- actions from the keyboard and the controller: "ok", "back", "restart", "map", "pause", "left", "right"
local function press(k)
  if screen == "title" then
    if k == "ok" then startLevel(level)
    elseif k == "left" and level > 1 then level = level - 1
    elseif k == "right" and level < unlocked then level = level + 1 end
  elseif screen == "done" then
    if k == "ok" then if level < #SIZES then startLevel(level + 1) else screen = "title" end
    elseif k == "back" then screen = "title"
    elseif k == "restart" then startLevel(level) end
  elseif screen == "play" then
    if k == "pause" or (k == "back" and not paused) then paused = not paused
    elseif paused and k == "ok" then paused = false
    elseif paused and k == "back" then paused = false; screen = "title"
    elseif paused and k == "restart" then startLevel(level)
    elseif k == "map" then bigMap = not bigMap end
  end
end

local KEYMAP = {enter = "ok", space = "ok", escape = "back", r = "restart", m = "map", p = "pause", left = "left", right = "right"}
local PADMAP = {a = "ok", b = "back", x = "restart", y = "map", minus = "map", plus = "pause", left = "left", right = "right"}

function app.event(e)
  if e.type == "keydown" then
    held[e.key] = true
    if e.shift then held.shift = true end
    if KEYMAP[e.key] then press(KEYMAP[e.key]) end
  elseif e.type == "keyup" then
    held[e.key] = false
    held.shift = e.shift == true
  elseif e.type == "paddown" then
    if PADMAP[e.pad] then press(PADMAP[e.pad]) end
  end
end

function app.menu()
  return {{title = TR("app_name"), items = {
    {label = TR("play"), id = 1, shortcut = "Enter"},
    {label = TR("pause"), id = 2, shortcut = "Esc"},
    {label = TR("restart"), id = 3},
    {label = TR("big_map"), id = 4, shortcut = "M"},
    "-",
    {label = TR("reset_times"), id = 5},
  }}}
end

function app.onmenu(id)
  if id == 1 then if screen ~= "play" then startLevel(level) end
  elseif id == 2 then if screen == "play" then paused = not paused end
  elseif id == 3 then startLevel(level)
  elseif id == 4 then bigMap = not bigMap
  elseif id == 5 then
    ui.alert(TR("reset_times"), TR("reset_msg"), {TR("reset"), TR("common.cancel")}, function(b)
      if b == 1 then best, unlocked = {}, 1; store.set("best", best); store.set("unlocked", 1); level = 1 end
    end)
  end
end

function app.close()
  store.save()
  return true
end

return app
