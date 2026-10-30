-- Meteor Yağmuru / Meteor Shower for Nexvyn OS: dodge the falling meteors, collect stars, score near misses
-- and pick up shields, slow motion and star magnets while the storm keeps getting faster.
local K = require("arcade")
local floor, min, max, abs, sqrt, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sqrt, math.sin,
  math.cos, math.pi
local random = math.random

local H = 600
local G = {icon = "local_fire_department", accent = "#FF6B35", overIcon = "public"}

local S, VW = 1, 900
local ship = {x = 450, y = 520, vx = 0, vy = 0, tilt = 0, inv = 0, shield = false}
local M = {}
for i = 1, 40 do M[i] = {on = false, x = 0, y = 0, vx = 0, vy = 0, r = 20, rot = 0, vr = 0, near = false, shape = {}} end
for i = 1, 40 do for k = 1, 9 do M[i].shape[k] = 0.75 + random() * 0.3 end end
local ITEMS = {}
for i = 1, 8 do ITEMS[i] = {on = false, x = 0, y = 0, kind = "star", t = 0} end
local STARS = {}
for i = 1, 90 do STARS[i] = {random(), random(), 0.3 + random() * 1.5} end
local SCR = {}
for i = 1, 18 do SCR[i] = 0 end
local SHIP, FLAME = {0, 0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0}
local lives, elapsed, spawnT, itemT, slowT, magnetT = 3, 0, 0.6, 2, 0, 0
local starsGot, nears, scoreClock = 0, 0, 0
local drag = nil
local starfield = 0

function G.controls() return {TR("c_move"), TR("c_touch")} end

function G.layout(w, h)
  S = h / H
  VW = w / S
  ship.x = K.clamp(ship.x, 20, VW - 20)
end

function G.reset()
  for i = 1, #M do M[i].on = false end
  for i = 1, #ITEMS do ITEMS[i].on = false end
  ship.x, ship.y, ship.vx, ship.vy, ship.inv, ship.shield = VW / 2, 520, 0, 0, 0, false
  lives, elapsed, spawnT, itemT, slowT, magnetT = 3, 0, 0.6, 2, 0, 0
  starsGot, nears, scoreClock = 0, 0, 0
  drag = nil
end

local function level() return min(1, elapsed / 120) end

local function spawnMeteor()
  for i = 1, #M do
    local m = M[i]
    if not m.on then
      local d = level()
      m.on, m.near = true, false
      m.r = 12 + random() * 26
      m.x = random() * VW
      m.y = -m.r - 10
      local speed = (170 + random() * 90) * (1 + d * 1.3) * (1.2 - m.r / 80)
      local a = pi / 2 + (random() - 0.5) * 0.5
      m.vx, m.vy = cos(a) * speed, sin(a) * speed
      m.rot, m.vr = random() * 6, (random() - 0.5) * 3
      return
    end
  end
end

local function spawnItem()
  for i = 1, #ITEMS do
    local it = ITEMS[i]
    if not it.on then
      it.on, it.t = true, 0
      it.x, it.y = 30 + random() * (VW - 60), -20
      local r = random()
      it.kind = r < 0.78 and "star" or r < 0.86 and "shield" or r < 0.93 and "slow" or "magnet"
      return
    end
  end
end

function G.pointer(e)
  if e.type == "mousedown" then
    drag = {x = e.x, y = e.y, sx = ship.x, sy = ship.y}
  elseif e.type == "mousemove" and drag then
    ship.tx = drag.sx + (e.x - drag.x) / S * 1.3
    ship.ty = drag.sy + (e.y - drag.y) / S * 1.3
  elseif e.type == "mouseup" then
    drag, ship.tx, ship.ty = nil, nil, nil
  end
end

local function hit(m)
  if ship.inv > 0 then return end
  K.burst(m.x, m.y, 30, "#FF6B35", 260, 0.7, 3.5)
  m.on = false
  if ship.shield then
    ship.shield = false
    ship.inv = 1
    K.callout(TR("shield_gone"), "#64D2FF", 28, "shield")
    K.chord({1046, 784, 523}, 0.12, 0.08, "triangle")
    K.shake(6)
    return
  end
  lives = lives - 1
  ship.inv = 1.6
  K.comboBreak()
  K.sfx("boom")
  K.shake(14)
  K.flash("#FF453A50", 0.3)
  K.vibrate(1, 240)
  if lives <= 0 then
    K.burst(ship.x, ship.y, 60, "#FFD60A", 300, 1.0, 3)
    K.over({stats = {{TR("survived"), K.fmtTime(elapsed)}, {TR("stars"), tostring(starsGot)},
      {TR("near"), tostring(nears)}}})
  end
end

local function collect(it, playing)
  it.on = false
  K.burst(it.x, it.y, 16, it.kind == "star" and "#FFD60A" or "#64D2FF", 180, 0.5, 2.5)
  if not playing then return end
  if it.kind == "star" then
    starsGot = starsGot + 1
    local c = K.comboHit(2.5, "#FFD60A")
    local pts = 25 * min(c, 8)
    K.addScore(pts)
    K.popup(it.x, it.y - 18, "+" .. pts, "#FFD60A")
    K.sfx("coin", 0.8)
  elseif it.kind == "shield" then
    ship.shield = true
    K.callout(TR("shield"), "#64D2FF", 30, "pow")
    K.sfx("power")
  elseif it.kind == "slow" then
    slowT = 4
    K.callout(TR("slow"), "#BF5AF2", 30, "pow")
    K.sfx("power")
  else
    magnetT = 7
    K.callout(TR("magnet"), "#FF375F", 30, "pow")
    K.sfx("power")
  end
end

local function simulate(dt, demo)
  local playing = not demo
  elapsed = elapsed + dt
  if slowT > 0 then slowT = slowT - dt end
  if magnetT > 0 then magnetT = magnetT - dt end
  local tdt = slowT > 0 and dt * 0.45 or dt
  starfield = starfield + tdt * (80 + level() * 160)
  -- ship
  local ax, ay = 0, 0
  if demo then
    -- dodge: steer away from the closest meteor above, drift to center otherwise
    local best, bd = nil, 1e9
    for i = 1, #M do
      local m = M[i]
      if m.on and m.y < ship.y and m.y > ship.y - 260 then
        local d = abs(m.x - ship.x)
        if d < bd then best, bd = m, d end
      end
    end
    if best and bd < best.r + 50 then ax = best.x > ship.x and -1 or 1 else ax = K.clamp((VW / 2 - ship.x) / 200, -0.4, 0.4) end
    ay = (520 - ship.y) / 100
  else
    ax, ay = K.axis()
  end
  if ship.tx then
    ship.vx = K.clamp((ship.tx - ship.x) * 12, -900, 900)
    ship.vy = K.clamp((ship.ty - ship.y) * 12, -900, 900)
  else
    ship.vx = K.smooth(ship.vx, ax * 460, 10, dt)
    ship.vy = K.smooth(ship.vy, ay * 320, 10, dt)
  end
  ship.x = K.clamp(ship.x + ship.vx * dt, 22, VW - 22)
  ship.y = K.clamp(ship.y + ship.vy * dt, H * 0.45, H - 30)
  ship.tilt = K.smooth(ship.tilt, ship.vx / 900, 10, dt)
  if ship.inv > 0 then ship.inv = ship.inv - dt end
  if random() < 0.8 then
    K.burst(ship.x, ship.y + 16, 1, random() < 0.5 and "#FFD60A" or "#FF6B35", 120, 0.25, 2.2, 0, pi / 2, 0.4)
  end
  -- spawning
  spawnT = spawnT - tdt
  if spawnT <= 0 then
    spawnMeteor()
    spawnT = (0.55 - level() * 0.38) * (0.5 + random())
  end
  itemT = itemT - tdt
  if itemT <= 0 then
    spawnItem()
    itemT = 1.2 + random() * 1.8
  end
  -- meteors
  for i = 1, #M do
    local m = M[i]
    if m.on then
      m.x, m.y = m.x + m.vx * tdt, m.y + m.vy * tdt
      m.rot = m.rot + m.vr * tdt
      if random() < 0.5 then K.burst(m.x - m.vx * 0.04, m.y - m.vy * 0.04, 1, "#FF9F0A", 30, 0.35, m.r * 0.18) end
      local dx, dy = m.x - ship.x, m.y - ship.y
      local d2 = dx * dx + dy * dy
      if d2 < (m.r * 0.85 + 13) ^ 2 then
        if playing then hit(m) else m.on = false end
      elseif playing and not m.near and m.y > ship.y and d2 < (m.r + 40) ^ 2 and ship.inv <= 0 then
        m.near = true
        nears = nears + 1
        K.addScore(5)
        K.popup(ship.x, ship.y - 30, TR("close"), "#7DF9FF")
        K.tone(1500, 0.04, 0.05, "sine")
      end
      if m.y > H + m.r + 10 or m.x < -80 or m.x > VW + 80 then m.on = false end
    end
  end
  -- items
  for i = 1, #ITEMS do
    local it = ITEMS[i]
    if it.on then
      it.t = it.t + dt
      it.y = it.y + 120 * tdt
      if magnetT > 0 and it.kind == "star" then
        it.x = K.smooth(it.x, ship.x, 4, dt)
        it.y = K.smooth(it.y, ship.y, 3, dt)
      end
      if (it.x - ship.x) ^ 2 + (it.y - ship.y) ^ 2 < 30 * 30 then collect(it, playing)
      elseif it.y > H + 30 then it.on = false end
    end
  end
  if playing then
    scoreClock = scoreClock + dt
    while scoreClock >= 0.1 do
      scoreClock = scoreClock - 0.1
      K.score = K.score + 1          -- survival points tick quietly (no score-pill glow)
    end
    if floor(elapsed / 30) ~= floor((elapsed - dt) / 30) then
      K.callout(TR("faster"), "#FF6B35", 32, "faster")
      K.sfx("level", 0.8)
    end
  end
end

function G.update(dt) simulate(dt, false) end
function G.idle(dt) if K.state == "title" then simulate(dt, true) end end

-- ------------------------------------------------------------------ drawing
local function drawMeteor(m)
  local x, y = m.x * S, m.y * S
  local n = 9
  -- glowing trail
  local tl = 0.18
  K.color("#FF6B35", 0.25)
  gfx.line(x, y, x - m.vx * tl * S, y - m.vy * tl * S, m.r * 1.3 * S)
  K.color("#FFD60A", 0.25)
  gfx.line(x, y, x - m.vx * tl * 0.5 * S, y - m.vy * tl * 0.5 * S, m.r * 0.7 * S)
  for i = 1, n do
    local a = m.rot + (i - 1) / n * 2 * pi
    local rr = m.r * m.shape[i] * S
    SCR[i * 2 - 1], SCR[i * 2] = x + cos(a) * rr, y + sin(a) * rr
  end
  K.color("#5A3D2B")
  gfx.circle(x, y, m.r * 0.85 * S)
  K.color("#8A5A3C")
  gfx.lines(SCR, max(2, m.r * 0.18 * S), true)
  K.color("#3D2A1E")
  gfx.circle(x + cos(m.rot) * m.r * 0.3 * S, y + sin(m.rot) * m.r * 0.3 * S, m.r * 0.22 * S)
  gfx.circle(x - sin(m.rot) * m.r * 0.35 * S, y + cos(m.rot) * m.r * 0.25 * S, m.r * 0.14 * S)
end

local function drawShip(t)
  local x, y = ship.x * S, ship.y * S
  local s = S
  local tl = ship.tilt
  if ship.inv > 0 and floor(t * 14) % 2 == 0 and K.state == "play" then return end
  local fl = 0.7 + random() * 0.5
  FLAME[1], FLAME[2] = x - 7 * s, y + 12 * s
  FLAME[3], FLAME[4] = x, y + (12 + 22 * fl) * s
  FLAME[5], FLAME[6] = x + 7 * s, y + 12 * s
  K.color("#FF9F0A", 0.85)
  gfx.poly(FLAME)
  SHIP[1], SHIP[2] = x + tl * 6 * s, y - 22 * s
  SHIP[3], SHIP[4] = x + (16 + tl * 4) * s, y + 14 * s
  SHIP[5], SHIP[6] = x, y + 8 * s
  SHIP[7], SHIP[8] = x - (16 - tl * 4) * s, y + 14 * s
  K.color("#7DF9FF", 0.25)
  gfx.circle(x, y, 26 * s)
  K.color("#E5E5EA")
  gfx.poly(SHIP)
  K.color("#0A84FF")
  gfx.circle(x + tl * 3 * s, y - 4 * s, 5 * s)
  if ship.shield then
    K.color("#64D2FF", 0.35 + 0.15 * sin(t * 8))
    gfx.circleLine(x, y, 30 * s, 3)
  end
end

local ICON = {star = "star", shield = "shield", slow = "hourglass_top", magnet = "bolt"}
local ICOL = {star = "#FFD60A", shield = "#64D2FF", slow = "#BF5AF2", magnet = "#FF375F"}

function G.draw(w, h)
  local t = K.now
  gfx.gradient(0, 0, w, h, "#0B0420", "#2B0F3A")
  local sx, sy = K.shakeXY()
  gfx.push(sx, sy)
  -- nebula and planet
  K.color("#7B2CBF", 0.12)
  gfx.circle(w * 0.25, h * 0.3, 220 * S)
  K.color("#FF375F", 0.08)
  gfx.circle(w * 0.75, h * 0.6, 260 * S)
  K.color("#3A2A6B")
  gfx.circle(w * 0.85, h * 0.18, 50 * S)
  K.color("#5B47A8", 0.6)
  gfx.circle(w * 0.85 - 12 * S, h * 0.18 - 12 * S, 30 * S)
  for i = 1, #STARS do
    local st = STARS[i]
    local y = (st[2] * H + starfield * st[3] * 0.5) % H
    K.color("#FFFFFF", 0.2 + st[3] * 0.25)
    gfx.rect(st[1] * w, y * S, st[3] * S, st[3] * 3 * S)
  end
  for i = 1, #ITEMS do
    local it = ITEMS[i]
    if it.on then
      local x, y = it.x * S, it.y * S
      local p = 1 + sin(it.t * 6) * 0.1
      K.color(ICOL[it.kind], 0.25)
      gfx.circle(x, y, 22 * S * p)
      gfx.icon(ICON[it.kind], x, y, 28 * S * p, ICOL[it.kind])
    end
  end
  for i = 1, #M do if M[i].on then drawMeteor(M[i]) end end
  K.drawParticles(S, 0, 0)
  drawShip(t)
  K.drawPopups(S, 0, 0, 16)
  if slowT > 0 then
    K.color("#BF5AF2", 0.12)
    gfx.rect(0, 0, w, h)
  end
  gfx.pop()
  -- HUD
  local x = 12
  x = x + K.scorePill(x, 8) + 8
  x = x + K.pill(x, 8, "timer", K.fmtTime(elapsed), "#7DF9FF") + 8
  gfx.color(0, 0, 0, 110)
  gfx.rect(x, 8, 20 + 3 * 24, 34, 17)
  for i = 1, 3 do
    gfx.icon(i <= lives and "favorite" or "favorite_border", x + i * 24 - 2, 25, 20, i <= lives and "#FF375F" or "#FFFFFF")
  end
  K.bestPill(w - 60, 8)
end

return K.run(G)
