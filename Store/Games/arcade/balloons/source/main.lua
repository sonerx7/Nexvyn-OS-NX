-- Balon Patlat / Balloon Pop for Nexvyn OS: pop the rising balloons before they float away, chain pops for
-- combos, catch golden, ice (freeze), heart and blast balloons, and never pop a bomb.
-- Touch / mouse, or a controller crosshair with A.
local K = require("arcade")
local floor, min, max, abs, sqrt, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sqrt, math.sin,
  math.cos, math.pi
local random = math.random

local H = 600
local G = {icon = "celebration", accent = "#FF375F", overIcon = "air"}
local COLORS = {"#FF453A", "#FF9F0A", "#FFD60A", "#32D74B", "#64D2FF", "#0A84FF", "#BF5AF2", "#FF375F"}

local S, VW = 1, 900
local B = {}
for i = 1, 40 do B[i] = {on = false, x = 0, y = 0, r = 30, vy = 0, ph = 0, kind = "n", col = "#FF453A", born = 0} end
local CLOUDS = {}
for i = 1, 7 do CLOUDS[i] = {random() * 1600, 60 + random() * 300, 0.5 + random() * 0.8} end
local cursor = {x = 450, y = 300, vx = 0, vy = 0}
local lives, spawnT, elapsed, freezeT = 5, 0.5, 0, 0
local popped, golds, bombsHit, escaped = 0, 0, 0, 0
local scroll = 0

function G.controls() return {TR("c_touch"), TR("c_aim"), TR("c_pop")} end

function G.layout(w, h)
  S = h / H
  VW = w / S
end

function G.reset()
  for i = 1, #B do B[i].on = false end
  lives, spawnT, elapsed, freezeT = 5, 0.5, 0, 0
  popped, golds, bombsHit, escaped = 0, 0, 0, 0
  cursor.x, cursor.y = VW / 2, 320
end

local function spawn()
  for i = 1, #B do
    local b = B[i]
    if not b.on then
      local d = min(1, elapsed / 90)
      b.on, b.born = true, K.now
      b.r = 26 + random() * 14 - d * 6
      b.x = b.r + random() * (VW - 2 * b.r)
      b.y = H + b.r + 10
      b.vy = (55 + random() * 40) * (1 + d * 1.4)
      b.ph = random() * 6
      local r = random()
      b.kind = "n"
      if r < 0.10 + d * 0.06 then b.kind = "bomb"
      elseif r < 0.16 + d * 0.06 then b.kind = "gold"
      elseif r < 0.19 + d * 0.06 then b.kind = "ice"
      elseif r < 0.21 + d * 0.06 then b.kind = "blast"
      elseif r < 0.225 + d * 0.06 and lives < 5 then b.kind = "heart" end
      b.col = b.kind == "gold" and "#FFD60A" or b.kind == "ice" and "#9EEBFF" or b.kind == "bomb" and "#2C2C2E"
        or b.kind == "heart" and "#FF375F" or b.kind == "blast" and "#FF9F0A" or COLORS[random(#COLORS)]
      return
    end
  end
end

local popAt
local function popBalloon(b, chain, playing)
  b.on = false
  K.burst(b.x, b.y, 22, b.col, 260, 0.6, 3.5, 200)
  K.burst(b.x, b.y, 6, "#FFFFFF", 160, 0.3, 2)
  if not playing then return end
  if b.kind == "bomb" then
    bombsHit = bombsHit + 1
    lives = lives - 1
    K.burst(b.x, b.y, 40, "#FF9F0A", 320, 0.8, 4)
    K.comboBreak()
    K.sfx("boom")
    K.shake(16)
    K.flash("#FF453A60", 0.3)
    K.vibrate(1, 260)
    K.callout(TR("boom"), "#FF453A", 34, "boom")
    return
  end
  popped = popped + 1
  local c = K.comboHit(1.0, b.col)
  local base = b.kind == "gold" and 50 or 10
  local pts = base * (1 + floor(c / 4))
  K.addScore(pts)
  K.popup(b.x, b.y - b.r, "+" .. pts, b.kind == "gold" and "#FFD60A" or "#FFFFFF")
  local f = 900 - b.r * 8 + min(c, 10) * 40
  K.chord({f, f * 1.5}, 0.05, 0.1, "sine")
  K.tone(f * 2, 0.03, 0.05, "triangle")
  K.shake(2)
  if b.kind == "gold" then
    golds = golds + 1
    K.sfx("coin")
  elseif b.kind == "ice" then
    freezeT = 3.5
    K.callout(TR("freeze"), "#9EEBFF", 32, "ice")
    K.chord({1568, 2093, 2637}, 0.25, 0.05, "sine")
  elseif b.kind == "heart" then
    lives = min(5, lives + 1)
    K.callout(TR("life"), "#FF375F", 32, "life")
    K.sfx("power")
  elseif b.kind == "blast" and not chain then
    K.callout(TR("blast"), "#FF9F0A", 32, "blast")
    K.sfx("boom", 0.6)
    for i = 1, #B do
      local o = B[i]
      if o.on and o.kind ~= "bomb" and (o.x - b.x) ^ 2 + (o.y - b.y) ^ 2 < 180 * 180 then popBalloon(o, true, true) end
    end
  end
end
popAt = function(x, y, playing)
  -- topmost balloon under the point (a little forgiving)
  for i = #B, 1, -1 do
    local b = B[i]
    if b.on and (x - b.x) ^ 2 + (y - b.y) ^ 2 < (b.r + 8) ^ 2 then
      popBalloon(b, false, playing)
      return true
    end
  end
  if playing then
    K.comboBreak()
    K.tone(180, 0.04, 0.06, "triangle")
  end
  return false
end

function G.press(act)
  if act == "a" or act == "b" then
    popAt(cursor.x, cursor.y, true)
    K.burst(cursor.x, cursor.y, 4, "#FFFFFF", 80, 0.25, 2)
  end
end

function G.pointer(e)
  local x, y = e.x / S, e.y / S
  if e.type == "mousemove" then cursor.x, cursor.y = x, y
  elseif e.type == "mousedown" then
    cursor.x, cursor.y = x, y
    popAt(x, y, true)
  end
end

local function simulate(dt, demo)
  local playing = not demo
  elapsed = elapsed + dt
  scroll = scroll + dt * 20
  if freezeT > 0 then freezeT = freezeT - dt end
  if not demo then
    local ax, ay = K.axis()
    cursor.vx = K.smooth(cursor.vx, ax * 620, 14, dt)
    cursor.vy = K.smooth(cursor.vy, ay * 620, 14, dt)
    cursor.x = K.clamp(cursor.x + cursor.vx * dt, 0, VW)
    cursor.y = K.clamp(cursor.y + cursor.vy * dt, 40, H)
  end
  spawnT = spawnT - dt
  if spawnT <= 0 then
    spawn()
    local d = min(1, elapsed / 90)
    spawnT = (0.9 - d * 0.55) * (0.5 + random())
  end
  local slow = freezeT > 0 and 0.15 or 1
  for i = 1, #B do
    local b = B[i]
    if b.on then
      b.y = b.y - b.vy * slow * dt
      b.x = b.x + sin(K.now * 1.5 + b.ph) * 18 * dt * slow
      if demo and b.kind ~= "bomb" and b.y < H * 0.55 and random() < 0.01 then popBalloon(b, false, false) end
      if b.y < -b.r * 2 - 40 then
        b.on = false
        if playing and b.kind ~= "bomb" then
          escaped = escaped + 1
          lives = lives - 1
          K.comboBreak()
          K.sfx("hit", 0.7)
          K.flash("#FF453A30", 0.2)
          K.vibrate(0.5, 100)
        end
      end
    end
  end
  if playing and lives <= 0 then
    K.over({stats = {{TR("popped"), tostring(popped)}, {TR("golden"), tostring(golds)},
      {TR("escaped"), tostring(escaped)}, {TR("bombs"), tostring(bombsHit)}}})
  end
end

function G.update(dt) simulate(dt, false) end
function G.idle(dt) if K.state == "title" then simulate(dt, true) end end

-- ------------------------------------------------------------------ drawing
local function drawBalloon(b, t)
  local s = S
  local grow = K.easeOutBack((t - b.born) / 0.3)
  local x, y, r = b.x * s, b.y * s, b.r * s * grow
  if r < 1 then return end
  -- string
  K.color("#FFFFFF", 0.6)
  local sx, sy = x, y + r * 1.1
  for k = 1, 3 do
    local nx, ny = x + sin(t * 3 + b.ph + k) * 5 * s, sy + 18 * s
    gfx.line(sx, sy, nx, ny, 1.5)
    sx, sy = nx, ny
  end
  -- body (slightly taller than wide) and knot
  K.color(b.col)
  gfx.circle(x, y, r)
  gfx.circle(x, y + r * 0.25, r * 0.86)
  gfx.rect(x - r * 0.14, y + r * 1.02, r * 0.28, r * 0.14, 2)
  K.color("#FFFFFF", b.kind == "bomb" and 0.15 or 0.4)
  gfx.circle(x - r * 0.35, y - r * 0.35, r * 0.24)
  if b.kind == "bomb" then
    gfx.icon("dangerous", x, y + r * 0.1, r * 1.1, "#FF453A")
  elseif b.kind == "gold" then
    gfx.icon("star", x, y + r * 0.1, r * 0.9, "#FFFFFF")
  elseif b.kind == "ice" then
    gfx.icon("ac_unit", x, y + r * 0.1, r * 0.9, "#0A84FF")
  elseif b.kind == "heart" then
    gfx.icon("favorite", x, y + r * 0.1, r * 0.9, "#FFFFFF")
  elseif b.kind == "blast" then
    gfx.icon("flare", x, y + r * 0.1, r * 0.9, "#FFFFFF")
  end
end

function G.draw(w, h)
  local t = K.now
  gfx.gradient(0, 0, w, h, freezeT > 0 and "#BDEBFF" or "#5AC8FA", freezeT > 0 and "#F0FBFF" or "#D7F2FF")
  local sx, sy = K.shakeXY()
  gfx.push(sx, sy)
  K.color("#FFF6C2", 0.8)
  gfx.circle(w * 0.85, h * 0.16, 44 * S)
  for i = 1, #CLOUDS do
    local c = CLOUDS[i]
    local x = ((c[1] + scroll * c[3]) % (VW + 300)) - 150
    K.color("#FFFFFF", 0.7)
    gfx.circle(x * S, c[2] * S, 30 * c[3] * S)
    gfx.circle((x + 34 * c[3]) * S, (c[2] - 12) * S, 36 * c[3] * S)
    gfx.circle((x + 70 * c[3]) * S, c[2] * S, 28 * c[3] * S)
  end
  -- distant hills
  K.color("#7CCB7A", 0.8)
  for i = 0, 8 do gfx.circle((i * 140 + 40) * S, (H + 60) * S, 130 * S) end
  for i = 1, #B do
    local b = B[i]
    if b.on then drawBalloon(b, t) end
  end
  K.drawParticles(S, 0, 0)
  K.drawPopups(S, 0, 0, 18)
  if freezeT > 0 then
    K.color("#FFFFFF", 0.25 * min(1, freezeT))
    gfx.rect(0, 0, w, h)
  end
  -- crosshair for controller / keyboard players
  if K.state == "play" and K.lastInput ~= "touch" then
    local X, Y = cursor.x * S, cursor.y * S
    local r = 18 + sin(t * 6) * 2
    gfx.color(0, 0, 0, 80)
    gfx.circleLine(X + 1, Y + 1, r, 3)
    K.color("#FFFFFF")
    gfx.circleLine(X, Y, r, 3)
    gfx.circle(X, Y, 3)
  end
  gfx.pop()
  -- HUD
  local x = 12
  x = x + K.scorePill(x, 8) + 8
  gfx.color(0, 0, 0, 110)
  gfx.rect(x, 8, 20 + 5 * 24, 34, 17)
  for i = 1, 5 do
    gfx.icon(i <= lives and "favorite" or "favorite_border", x + i * 24 - 2, 25, 20, i <= lives and "#FF375F" or "#FFFFFF")
  end
  K.bestPill(w - 60, 8)
end

return K.run(G)
