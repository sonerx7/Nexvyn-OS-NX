-- Yılan / Snake for Nexvyn OS: classic snake with smooth gliding movement, speeds up as it grows, walls or
-- wrap-around mode, apple combos, bonus stars, an AI demo behind the title screen and a best score per mode.
local K = require("arcade")
local floor, min, max, abs, sin = math.floor, math.min, math.max, math.abs, math.sin
local random = math.random

local COLS, ROWS = 28, 18
local G = {icon = "timeline", accent = "#34C759", stickPress = true, optionsHeight = 34}

local mode = 1                       -- 1 = walls, 2 = wrap-around
local snake, occ = {}, {}
local dx, dy = 1, 0
local qx, qy, qn = {0, 0}, {0, 0}, 0 -- up to two queued turns
local food = {x = 0, y = 0, born = 0}
local star = {x = 0, y = 0, t = 0, born = 0}
local tailFrom = {x = 0, y = 0}
local eaten, stars, clock, interval = 0, 0, 0, 0.14
local lastEat, eatAt = -10, -10
local L = {cell = 20, x = 0, y = 0}
local swipe = nil
local dead, deadAt = false, 0

local function id(x, y) return y * COLS + x end

local function freeCell()
  for _ = 1, 300 do
    local x, y = random(0, COLS - 1), random(0, ROWS - 1)
    if not occ[id(x, y)] and not (x == food.x and y == food.y) then return x, y end
  end
  for y = 0, ROWS - 1 do
    for x = 0, COLS - 1 do
      if not occ[id(x, y)] then return x, y end
    end
  end
  return 0, 0
end

function G.load() mode = store.get("mode", 1) end
function G.bestKey() return mode == 2 and "best_wrap" or "best_walls" end
function G.controls() return {TR("c_move"), TR("c_touch")} end

function G.layout(w, h)
  local top = 54
  L.cell = max(6, floor(min((w - 24) / COLS, (h - top - 12) / ROWS)))
  L.x = floor((w - L.cell * COLS) / 2)
  L.y = floor(top + (h - top - 12 - L.cell * ROWS) / 2)
end

function G.reset()
  snake, occ = {}, {}
  local cx, cy = floor(COLS / 2) - 2, floor(ROWS / 2)
  for i = 1, 4 do
    local s = {x = cx - i + 1, y = cy}
    snake[i] = s
    occ[id(s.x, s.y)] = true
  end
  tailFrom.x, tailFrom.y = cx - 4, cy
  dx, dy, qn = 1, 0, 0
  eaten, stars, clock, interval = 0, 0, 0, 0.14
  lastEat, eatAt = -10, -10
  star.t = 0
  dead = false
  food.x, food.y = -1, -1
  food.x, food.y = freeCell()
  food.born = K.now
end

local function turn(nx, ny)
  local lx, ly = dx, dy
  if qn > 0 then lx, ly = qx[qn], qy[qn] end
  if (nx == lx and ny == ly) or (nx == -lx and ny == -ly) then return end
  if qn < 2 then
    qn = qn + 1
    qx[qn], qy[qn] = nx, ny
    K.sfx("turn", 0.5)
  end
end

function G.press(act)
  if act == "up" then turn(0, -1)
  elseif act == "down" then turn(0, 1)
  elseif act == "left" then turn(-1, 0)
  elseif act == "right" then turn(1, 0) end
end

local function setMode(m)
  mode = m
  store.set("mode", mode)
  K.loadBest()
  G.reset()
end

function G.titlePress(act)
  if act == "left" or act == "right" then
    setMode(3 - mode)
    K.sfx("click")
  end
end

function G.options(x, y, w)
  local m = ui.segmented("mode", {TR("walls"), TR("wrap")}, mode, x, y, w, 32)
  if m ~= mode then setMode(m) end
end

local function die()
  dead, deadAt = true, K.now
  for i = 1, #snake, 2 do
    local s = snake[i]
    K.burst(s.x + 0.5, s.y + 0.5, 3, "#7CFC6A", 6, 0.9, 0.25)
  end
  local h = snake[1]
  K.burst(h.x + 0.5, h.y + 0.5, 34, "#FFD60A", 10, 1.0, 0.3)
  K.shake(12)
  K.flash("#FF3B3060", 0.3)
  K.sfx("boom")
  K.vibrate(1, 250)
  K.over({stats = {{TR("length"), tostring(#snake)}, {TR("apples"), tostring(eaten)}, {TR("stars"), tostring(stars)},
    {TR("speed"), tostring(1 + floor(eaten / 5))}}})
end

local function blocked(nx, ny)
  if mode == 2 then nx, ny = nx % COLS, ny % ROWS
  elseif nx < 0 or ny < 0 or nx >= COLS or ny >= ROWS then return true end
  local tail = snake[#snake]
  return occ[id(nx, ny)] and not (tail.x == nx and tail.y == ny)
end

-- demo player behind the title card: greedy towards the apple, never into a wall if avoidable
local function think()
  local h = snake[1]
  local bx, by, bd = dx, dy, 1e9
  local opts = {dx, dy, -dy, dx, dy, -dx}
  for k = 1, 5, 2 do
    local ox, oy = opts[k], opts[k + 1]
    if not blocked(h.x + ox, h.y + oy) then
      local d = abs(h.x + ox - food.x) + abs(h.y + oy - food.y) + random() * 0.5
      if d < bd then bx, by, bd = ox, oy, d end
    end
  end
  dx, dy = bx, by
end

local function step()
  if K.state ~= "play" then think() end
  if qn > 0 then
    dx, dy = qx[1], qy[1]
    qx[1], qy[1] = qx[2], qy[2]
    qn = qn - 1
  end
  local h = snake[1]
  local nx, ny = h.x + dx, h.y + dy
  local hitWall = false
  if mode == 2 then
    nx, ny = nx % COLS, ny % ROWS
  elseif nx < 0 or ny < 0 or nx >= COLS or ny >= ROWS then
    hitWall = true
  end
  local grow = nx == food.x and ny == food.y
  local tail = snake[#snake]
  if hitWall or (occ[id(nx, ny)] and (grow or tail.x ~= nx or tail.y ~= ny)) then
    if K.state == "play" then die() else G.reset() end
    return
  end
  local seg
  if grow then
    seg = {x = nx, y = ny}
    tailFrom.x, tailFrom.y = tail.x, tail.y
  else
    seg = table.remove(snake)
    occ[id(seg.x, seg.y)] = nil
    tailFrom.x, tailFrom.y = seg.x, seg.y
    seg.x, seg.y = nx, ny
  end
  table.insert(snake, 1, seg)
  occ[id(nx, ny)] = true
  local playing = K.state == "play"
  if grow then
    eaten = eaten + 1
    eatAt = K.now
    local combo = 1
    if playing then combo = K.comboHit(3.5, "#8CFF6E") end
    lastEat = K.now
    local pts = (10 + floor(eaten / 5) * 2) * combo
    if playing then
      K.addScore(pts)
      K.popup(nx + 0.5, ny, "+" .. pts, combo > 1 and "#8CFF6E" or "#FFFFFF")
    end
    K.burst(nx + 0.5, ny + 0.5, 16, "#FF453A", 6, 0.55, 0.18)
    K.burst(nx + 0.5, ny + 0.5, 8, "#8CFF6E", 4, 0.5, 0.14)
    interval = max(0.055, 0.14 - eaten * 0.0025)
    food.x, food.y = freeCell()
    food.born = K.now
    if eaten % 5 == 0 then
      star.x, star.y = freeCell()
      star.t, star.born = 7, K.now
      if playing then
        K.sfx("level")
        K.callout(TR("speed_up"), "#64D2FF", 30, "speed")
      end
    elseif playing then
      K.sfx("eat")
    end
  elseif star.t > 0 and nx == star.x and ny == star.y then
    star.t = 0
    stars = stars + 1
    if playing then
      K.addScore(50)
      K.popup(nx + 0.5, ny, "+50", "#FFD60A")
      K.sfx("coin")
      K.vibrate(0.4, 60)
    end
    K.burst(nx + 0.5, ny + 0.5, 28, "#FFD60A", 8, 0.8, 0.2)
  end
end

local function advance(dt)
  if dead then return end
  if star.t > 0 then star.t = max(0, star.t - dt) end
  clock = clock + dt
  local guard = 0
  while clock >= interval and not dead and guard < 4 do
    clock = clock - interval
    guard = guard + 1
    step()
  end
end

function G.update(dt) advance(dt) end
function G.idle(dt) if K.state == "title" then advance(dt) end end

function G.pointer(e)
  if e.type == "mousedown" then
    swipe = {x = e.x, y = e.y, moved = false}
  elseif e.type == "mousemove" and swipe then
    local ddx, ddy = e.x - swipe.x, e.y - swipe.y
    if abs(ddx) > 26 or abs(ddy) > 26 then
      if abs(ddx) > abs(ddy) then turn(ddx > 0 and 1 or -1, 0) else turn(0, ddy > 0 and 1 or -1) end
      swipe.x, swipe.y, swipe.moved = e.x, e.y, true
    end
  elseif e.type == "mouseup" and swipe then
    if not swipe.moved and not e.cancel then
      local h = snake[1]
      local hx, hy = L.x + (h.x + 0.5) * L.cell, L.y + (h.y + 0.5) * L.cell
      local lx = qn > 0 and qx[qn] or dx
      if lx ~= 0 then turn(0, e.y < hy and -1 or 1) else turn(e.x < hx and -1 or 1, 0) end
    end
    swipe = nil
  end
end

-- ------------------------------------------------------------------ drawing
-- interpolated position of body slot i between its previous and current cell
local function slotPos(i, f)
  local s = snake[i]
  local fx, fy
  if i < #snake then fx, fy = snake[i + 1].x, snake[i + 1].y else fx, fy = tailFrom.x, tailFrom.y end
  if abs(fx - s.x) > 1 or abs(fy - s.y) > 1 then return s.x + 0.5, s.y + 0.5 end
  return fx + (s.x - fx) * f + 0.5, fy + (s.y - fy) * f + 0.5
end

function G.draw(w, h)
  gfx.gradient(0, 0, w, h, "#0E1A12", "#16261A")
  local sx, sy = K.shakeXY()
  gfx.push(sx, sy)
  local c = L.cell
  local t = K.now
  -- board
  K.color("#000000", 0.35)
  gfx.rect(L.x - 6, L.y - 6, c * COLS + 12, c * ROWS + 12, 10)
  K.color(mode == 1 and "#3E7A4A" or "#2B4D33")
  gfx.rectLine(L.x - 6, L.y - 6, c * COLS + 12, c * ROWS + 12, 10, mode == 1 and 3 or 1)
  K.color("#1A2D20")
  gfx.rect(L.x, L.y, c * COLS, c * ROWS)
  K.color("#1E3324")
  for y = 0, ROWS - 1 do
    for x = y % 2, COLS - 1, 2 do gfx.rect(L.x + x * c, L.y + y * c, c, c) end
  end
  -- food (pops in with an overshoot, then pulses)
  local grow = K.easeOutBack((t - food.born) / 0.35)
  local pul = grow * (1 + sin(t * 6) * 0.07)
  local fx, fy = L.x + (food.x + 0.5) * c, L.y + (food.y + 0.55) * c
  K.color("#FF453A", 0.25)
  gfx.circle(fx, fy, c * 0.55 * pul)
  K.color("#FF453A")
  gfx.circle(fx, fy, c * 0.36 * pul)
  K.color("#FFFFFF", 0.5)
  gfx.circle(fx - c * 0.12 * pul, fy - c * 0.12 * pul, c * 0.1 * pul)
  K.color("#5BD15B")
  gfx.rect(fx, fy - c * 0.47 * pul, c * 0.22 * pul, c * 0.14 * pul, 3)
  if star.t > 0 and (star.t > 2 or floor(t * 8) % 2 == 0) then
    local sg = K.easeOutBack((t - star.born) / 0.4)
    K.color("#FFD60A", 0.25)
    gfx.circle(L.x + (star.x + 0.5) * c, L.y + (star.y + 0.5) * c, c * 0.75 * sg)
    gfx.icon("star", L.x + (star.x + 0.5) * c, L.y + (star.y + 0.5) * c, c * 1.15 * sg, "#FFD60A")
  end
  -- snake: smooth body made of circles joined by thick lines
  local n = #snake
  local f = dead and 1 or K.clamp(clock / interval, 0, 1)
  local bulge = (t - eatAt) / interval
  local px, py
  for i = n, 1, -1 do
    local x, y = slotPos(i, f)
    local k = (i - 1) / max(1, n - 1)
    if dead and floor((t - deadAt) * 10) % 2 == 0 then K.color("#FF6B5E") else K.mix("#8CFF6E", "#1C8C64", k) end
    local r = c * (i == 1 and 0.47 or 0.42 - 0.08 * k)
    if abs(i - bulge) < 1.2 then r = r * (1 + 0.25 * (1.2 - abs(i - bulge))) end
    local X, Y = L.x + x * c, L.y + y * c
    if px and abs(px - X) + abs(py - Y) < c * 1.6 then gfx.line(px, py, X, Y, r * 2) end
    gfx.circle(X, Y, r)
    px, py = X, Y
  end
  -- belly stripe highlight and eyes
  if n > 0 then
    local hx, hy = slotPos(1, f)
    hx, hy = L.x + hx * c, L.y + hy * c
    local ox, oy = -dy, dx
    for k = -1, 1, 2 do
      local ex, ey = hx + dx * c * 0.15 + ox * k * c * 0.22, hy + dy * c * 0.15 + oy * k * c * 0.22
      K.color("#FFFFFF")
      gfx.circle(ex, ey, c * 0.15)
      K.color("#0B1A10")
      gfx.circle(ex + dx * c * 0.05, ey + dy * c * 0.05, c * 0.075)
    end
    if not dead and (t - eatAt) < 0.25 then
      K.color("#FF453A", 1 - (t - eatAt) / 0.25)
      gfx.circle(hx + dx * c * 0.45, hy + dy * c * 0.45, c * 0.12)
    end
  end
  K.drawParticles(c, L.x, L.y)
  K.drawPopups(c, L.x, L.y, 16)
  gfx.pop()
  -- HUD
  local x = 12
  x = x + K.scorePill(x, 10) + 8
  x = x + K.pill(x, 10, "timeline", TR("length_n", n), "#8CFF6E") + 8
  K.pill(x, 10, "speed", TR("speed_n", 1 + floor(eaten / 5)), "#64D2FF")
  K.bestPill(w - 60, 10)
end

return K.run(G)
