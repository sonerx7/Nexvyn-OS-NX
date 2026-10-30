-- Asteroitler / Asteroids for Nexvyn OS: rotate, thrust and shoot in a wrap-around field, rocks split in
-- three sizes, flying saucers, hyperspace, waves, lives, chain combos and a demo ship behind the title.
local K = require("arcade")
local floor, min, max, abs, sqrt, sin, cos, pi, atan = math.floor, math.min, math.max, math.abs, math.sqrt,
  math.sin, math.cos, math.pi, math.atan
local random = math.random

local W, H = 960, 600
local G = {icon = "rocket_launch", accent = "#FF7A45", overIcon = "public"}
local RAD = {14, 26, 46}
local PTS = {100, 50, 20}

local S, OX, OY = 1, 0, 0
local ship = {x = W / 2, y = H / 2, vx = 0, vy = 0, a = -pi / 2, inv = 0, alive = true, thrust = false, respawn = 0}
local rocks = {}
local BUL = {}
for i = 1, 16 do BUL[i] = {x = 0, y = 0, vx = 0, vy = 0, life = 0, enemy = false} end
local ufo = {on = false, x = 0, y = 0, vx = 0, fire = 0, t = 0, small = false}
local STARS = {}
for i = 1, 90 do STARS[i] = {random() * W, random() * H, 0.3 + random() * 1.4, random() * 6} end
local SCR = {}
for i = 1, 24 do SCR[i] = 0 end
local wave, lives, fireCd, ufoT = 1, 3, 0, 12
local shots, hits, destroyed, nextLife = 0, 0, 0, 10000
local pointer = nil
local demoT = 0

function G.controls() return {TR("c_turn"), TR("c_fire"), TR("c_hyper"), TR("c_touch")} end

function G.layout(w, h)
  S = min(w / W, h / H)
  OX, OY = floor((w - W * S) / 2), floor((h - H * S) / 2)
end

local function wrap(o)
  if o.x < 0 then o.x = o.x + W elseif o.x >= W then o.x = o.x - W end
  if o.y < 0 then o.y = o.y + H elseif o.y >= H then o.y = o.y - H end
end

local function newRock(size, x, y, sp)
  local a = random() * 2 * pi
  sp = sp or (40 + random() * 50) * (1 + (3 - size) * 0.35) * (1 + wave * 0.04)
  local shape = {}
  for i = 1, 11 do shape[i] = 0.72 + random() * 0.32 end
  rocks[#rocks + 1] = {x = x, y = y, vx = cos(a) * sp, vy = sin(a) * sp, size = size, r = RAD[size],
    rot = random() * 6, vr = (random() - 0.5) * 1.6, shape = shape, born = K.now}
end

local function spawnWave()
  rocks = {}
  for _ = 1, min(11, 3 + wave) do
    local x, y
    repeat
      x, y = random() * W, random() * H
    until (x - ship.x) ^ 2 + (y - ship.y) ^ 2 > 200 * 200
    newRock(3, x, y)
  end
end

function G.reset()
  wave, lives, fireCd, ufoT = 1, 3, 0, 14
  shots, hits, destroyed, nextLife = 0, 0, 0, 10000
  ship.x, ship.y, ship.vx, ship.vy, ship.a = W / 2, H / 2, 0, 0, -pi / 2
  ship.inv, ship.alive, ship.respawn = 2, true, 0
  for i = 1, #BUL do BUL[i].life = 0 end
  ufo.on = false
  pointer = nil
  spawnWave()
end

local function fire(x, y, a, enemy, sp)
  for i = 1, #BUL do
    local b = BUL[i]
    if b.life <= 0 then
      b.x, b.y = x, y
      b.vx, b.vy = cos(a) * (sp or 600), sin(a) * (sp or 600)
      if not enemy then b.vx, b.vy = b.vx + ship.vx * 0.5, b.vy + ship.vy * 0.5 end
      b.life, b.enemy = enemy and 1.6 or 0.85, enemy
      return true
    end
  end
  return false
end

local function shoot()
  if not ship.alive or fireCd > 0 then return end
  local n = 0
  for i = 1, #BUL do if BUL[i].life > 0 and not BUL[i].enemy then n = n + 1 end end
  if n >= 8 then return end
  if fire(ship.x + cos(ship.a) * 16, ship.y + sin(ship.a) * 16, ship.a, false) then
    fireCd = 0.12
    if K.state == "play" then
      shots = shots + 1
      K.sfx("shoot", 0.6)
    end
  end
end

local function hyperspace()
  if not ship.alive then return end
  K.burst(ship.x, ship.y, 20, "#64D2FF", 200, 0.5, 2.5)
  ship.x, ship.y, ship.vx, ship.vy = 40 + random() * (W - 80), 40 + random() * (H - 80), 0, 0
  ship.inv = max(ship.inv, 0.6)
  K.burst(ship.x, ship.y, 20, "#64D2FF", 200, 0.5, 2.5)
  if K.state == "play" then K.chord({300, 600, 1200}, 0.15, 0.08, "sine") end
end

function G.press(act)
  if act == "a" then shoot()
  elseif act == "x" or act == "y" then hyperspace() end
end

function G.pointer(e)
  if e.type == "mousedown" then
    pointer = {x = (e.x - OX) / S, y = (e.y - OY) / S}
  elseif e.type == "mousemove" and pointer then
    pointer.x, pointer.y = (e.x - OX) / S, (e.y - OY) / S
  elseif e.type == "mouseup" then
    pointer = nil
  end
end

local function explodeShip()
  ship.alive = false
  ship.respawn = 2
  K.burst(ship.x, ship.y, 60, "#FF7A45", 260, 1.2, 3.5)
  K.burst(ship.x, ship.y, 30, "#FFFFFF", 160, 0.8, 2)
  K.shake(16)
  K.flash("#FF453A50", 0.35)
  K.sfx("boom")
  K.vibrate(1, 300)
  K.comboBreak()
  lives = lives - 1
  if lives <= 0 then
    local acc = shots > 0 and floor(hits / shots * 100 + 0.5) or 0
    K.over({stats = {{TR("wave"), tostring(wave)}, {TR("destroyed"), tostring(destroyed)},
      {TR("accuracy"), acc .. "%"}}})
  end
end

local function breakRock(i, byPlayer)
  local r = rocks[i]
  table.remove(rocks, i)
  local col = r.size == 3 and "#C9B8A6" or r.size == 2 and "#E0C7AE" or "#FFE2C2"
  K.burst(r.x, r.y, 8 + r.size * 6, col, 90 + r.size * 30, 0.7, 2 + r.size * 0.6)
  if r.size > 1 then
    for _ = 1, 2 do newRock(r.size - 1, r.x, r.y) end
  end
  if byPlayer and K.state == "play" then
    destroyed = destroyed + 1
    local c = K.comboHit(1.6, "#FF7A45")
    local pts = PTS[r.size] + (c > 1 and (c - 1) * 10 or 0)
    K.addScore(pts)
    K.popup(r.x, r.y - r.r, "+" .. pts, c > 1 and "#FFD60A" or "#FFFFFF")
    K.sfx(r.size == 3 and "boom" or "small", r.size == 3 and 0.7 or 1)
    K.shake(r.size * 2.5)
    if K.score >= nextLife then
      nextLife = nextLife + 10000
      lives = lives + 1
      K.callout(TR("extra_life"), "#32D74B", 32, "life")
      K.sfx("power")
    end
  end
end

local function circleHit(ax, ay, bx, by, r)
  local dx, dy = ax - bx, ay - by
  return dx * dx + dy * dy < r * r
end

local function simulate(dt, demo)
  -- ship control
  if ship.alive then
    local turn, thrust = 0, false
    if demo then
      demoT = demoT + dt
      turn = sin(demoT * 0.7) * 0.8
      if demoT % 0.5 < dt then shoot() end
    else
      local ax, ay = K.axis()
      turn = ax
      thrust = K.down.up or K.down.b or ay < -0.5
      if pointer then
        local want = atan(pointer.y - ship.y, pointer.x - ship.x)
        local d = (want - ship.a + pi) % (2 * pi) - pi
        turn = K.clamp(d * 4, -1, 1)
        thrust = (pointer.x - ship.x) ^ 2 + (pointer.y - ship.y) ^ 2 > 160 * 160
        if abs(d) < 0.3 then shoot() end
      end
      if K.down.a then shoot() end
    end
    ship.a = ship.a + turn * 4.6 * dt
    ship.thrust = thrust
    if thrust then
      ship.vx, ship.vy = ship.vx + cos(ship.a) * 420 * dt, ship.vy + sin(ship.a) * 420 * dt
      if random() < 0.7 then
        K.burst(ship.x - cos(ship.a) * 12, ship.y - sin(ship.a) * 12, 1, random() < 0.5 and "#FFD60A" or "#FF7A45",
          140, 0.3, 2.2, 0, ship.a + pi, 0.5)
      end
      if not demo and random() < 0.15 then K.tone(70 + random() * 30, 0.05, 0.05, "noise") end
    end
    local sp = sqrt(ship.vx * ship.vx + ship.vy * ship.vy)
    if sp > 430 then ship.vx, ship.vy = ship.vx / sp * 430, ship.vy / sp * 430 end
    local drag = 1 - min(1, 0.55 * dt)
    ship.vx, ship.vy = ship.vx * drag, ship.vy * drag
    ship.x, ship.y = ship.x + ship.vx * dt, ship.y + ship.vy * dt
    wrap(ship)
    if ship.inv > 0 then ship.inv = ship.inv - dt end
  elseif lives > 0 then
    ship.respawn = ship.respawn - dt
    if ship.respawn <= 0 then
      ship.alive, ship.inv = true, 2.5
      ship.x, ship.y, ship.vx, ship.vy, ship.a = W / 2, H / 2, 0, 0, -pi / 2
      K.callout(TR("ready"), "#FFFFFF", 30, "ready", 0.8)
    end
  end
  if fireCd > 0 then fireCd = fireCd - dt end
  -- rocks
  for i = 1, #rocks do
    local r = rocks[i]
    r.x, r.y = r.x + r.vx * dt, r.y + r.vy * dt
    r.rot = r.rot + r.vr * dt
    wrap(r)
  end
  -- bullets
  for i = 1, #BUL do
    local b = BUL[i]
    if b.life > 0 then
      b.life = b.life - dt
      b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
      wrap(b)
      if b.enemy then
        if ship.alive and ship.inv <= 0 and not demo and circleHit(b.x, b.y, ship.x, ship.y, 13) then
          b.life = 0
          explodeShip()
        end
      else
        for j = #rocks, 1, -1 do
          local r = rocks[j]
          if circleHit(b.x, b.y, r.x, r.y, r.r) then
            b.life = 0
            if not demo then hits = hits + 1 end
            breakRock(j, not demo)
            break
          end
        end
        if b.life > 0 and ufo.on and circleHit(b.x, b.y, ufo.x, ufo.y, ufo.small and 14 or 22) then
          b.life = 0
          ufo.on = false
          K.burst(ufo.x, ufo.y, 40, "#BF5AF2", 240, 0.9, 3)
          if not demo then
            hits = hits + 1
            local pts = ufo.small and 1000 or 200
            K.addScore(pts)
            K.popup(ufo.x, ufo.y - 20, "+" .. pts, "#BF5AF2")
            K.callout(TR("ufo_down"), "#BF5AF2", 30, "ufo")
            K.sfx("boom")
            K.shake(8)
          end
        end
      end
    end
  end
  -- ship vs rocks
  if ship.alive and ship.inv <= 0 and not demo then
    for j = #rocks, 1, -1 do
      local r = rocks[j]
      if circleHit(ship.x, ship.y, r.x, r.y, r.r * 0.85 + 10) then
        breakRock(j, true)
        explodeShip()
        break
      end
    end
  end
  -- saucer
  ufoT = ufoT - dt
  if not ufo.on and ufoT <= 0 and (wave >= 2 or demo) then
    ufo.on = true
    ufo.small = wave >= 4 and random() < 0.5
    ufo.x = random() < 0.5 and -20 or W + 20
    ufo.vx = (ufo.x < 0 and 1 or -1) * (ufo.small and 150 or 110)
    ufo.y = 60 + random() * (H - 120)
    ufo.fire, ufo.t = 1, 0
  end
  if ufo.on then
    ufo.t = ufo.t + dt
    ufo.x = ufo.x + ufo.vx * dt
    ufo.y = ufo.y + sin(ufo.t * 2) * 50 * dt
    ufo.fire = ufo.fire - dt
    if ufo.fire <= 0 and ship.alive then
      ufo.fire = ufo.small and 0.9 or 1.4
      local a = atan(ship.y - ufo.y, ship.x - ufo.x) + (random() - 0.5) * (ufo.small and 0.25 or 0.9)
      fire(ufo.x, ufo.y, a, true, 330)
      if not demo then K.tone(900, 0.06, 0.06, "square") end
    end
    if not demo and floor(ufo.t * 6) ~= floor((ufo.t - dt) * 6) then K.tone(ufo.small and 1100 or 700, 0.05, 0.03, "sine") end
    if ufo.x < -40 or ufo.x > W + 40 then
      ufo.on = false
      ufoT = 12 + random() * 10
    end
    if not ufo.on then ufoT = 12 + random() * 10 end
  end
  -- next wave
  if #rocks == 0 then
    wave = wave + 1
    if not demo then
      K.addScore(500)
      K.callout(TR("wave_n", wave), "#FF7A45", 40, "wave", 1.5)
      K.sfx("level")
    end
    spawnWave()
    ship.inv = max(ship.inv, 1.5)
  end
end

function G.update(dt) simulate(dt, false) end
function G.idle(dt)
  if K.state == "title" then
    ship.inv = 10
    simulate(dt, true)
    if wave > 3 then wave = 1 end
  end
end

-- ------------------------------------------------------------------ drawing
local function drawRock(r, ox, oy)
  local n = #r.shape
  local x, y = ox + r.x * S, oy + r.y * S
  for i = 1, n do
    local a = r.rot + (i - 1) / n * 2 * pi
    local rr = r.r * r.shape[i] * S
    SCR[i * 2 - 1], SCR[i * 2] = x + cos(a) * rr, y + sin(a) * rr
  end
  for i = n * 2 + 1, #SCR do SCR[i] = nil end
  local grow = K.easeOutBack((K.now - r.born) / 0.3)
  K.color("#2A2430", 0.9)
  gfx.circle(x, y, r.r * 0.8 * S * grow)
  K.color(r.size == 3 and "#C9B8A6" or r.size == 2 and "#E0C7AE" or "#FFE2C2")
  gfx.lines(SCR, max(1.5, 2.2 * S), true)
end

local TA, TB, TL, TF = {0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0}
local function shipShape(x, y, a, s, col, alpha)
  local c, sn = cos(a), sin(a)
  local x1, y1 = x + 18 * c * s, y + 18 * sn * s
  local x2, y2 = x + (-12 * c + 11 * sn) * s, y + (-12 * sn - 11 * c) * s
  local x3, y3 = x - 7 * c * s, y - 7 * sn * s
  local x4, y4 = x + (-12 * c - 11 * sn) * s, y + (-12 * sn + 11 * c) * s
  K.color(col, 0.25 * alpha)
  gfx.circle(x, y, 20 * s)
  TA[1], TA[2], TA[3], TA[4], TA[5], TA[6] = x1, y1, x2, y2, x3, y3
  TB[1], TB[2], TB[3], TB[4], TB[5], TB[6] = x1, y1, x3, y3, x4, y4
  TL[1], TL[2], TL[3], TL[4], TL[5], TL[6], TL[7], TL[8] = x1, y1, x2, y2, x3, y3, x4, y4
  K.color("#14101C", alpha)
  gfx.poly(TA)
  gfx.poly(TB)
  K.color(col, alpha)
  gfx.lines(TL, max(1.5, 2.4 * s), true)
end

function G.draw(w, h)
  local t = K.now
  gfx.gradient(0, 0, w, h, "#0A0614", "#140A1E")
  local sx, sy = K.shakeXY()
  local ox, oy = OX + sx, OY + sy
  gfx.clip(OX, OY, W * S, H * S)
  for i = 1, #STARS do
    local st = STARS[i]
    local px = (st[1] - ship.vx * 0.02 * st[3] * t) % W
    local py = (st[2] - ship.vy * 0.02 * st[3] * t) % H
    K.color("#FFFFFF", 0.2 + 0.25 * st[3] / 1.7 * (0.7 + 0.3 * sin(t * 2 + st[4])))
    gfx.circle(ox + px * S, oy + py * S, st[3] * S)
  end
  for i = 1, #rocks do drawRock(rocks[i], ox, oy) end
  for i = 1, #BUL do
    local b = BUL[i]
    if b.life > 0 then
      local c = b.enemy and "#FF375F" or "#FFD60A"
      K.color(c, 0.3)
      gfx.circle(ox + b.x * S, oy + b.y * S, 6 * S)
      K.color(c)
      gfx.line(ox + b.x * S, oy + b.y * S, ox + (b.x - b.vx * 0.02) * S, oy + (b.y - b.vy * 0.02) * S, 3 * S)
    end
  end
  if ufo.on then
    local us = ufo.small and 0.65 or 1
    local x, y = ox + ufo.x * S, oy + ufo.y * S
    K.color("#BF5AF2", 0.25)
    gfx.circle(x, y, 30 * us * S)
    K.color("#BF5AF2")
    gfx.rect(x - 24 * us * S, y - 5 * us * S, 48 * us * S, 12 * us * S, 6 * us * S)
    K.color("#E5C8FF")
    gfx.circle(x, y - 6 * us * S, 10 * us * S)
    for k = -1, 1 do
      K.color(floor(t * 8 + k) % 2 == 0 and "#FFD60A" or "#FF375F")
      gfx.circle(x + k * 14 * us * S, y + 1 * S, 2.5 * us * S)
    end
  end
  if ship.alive and (ship.inv <= 0 or floor(t * 12) % 2 == 0 or K.state ~= "play") then
    if ship.thrust then
      local fl = 0.7 + random() * 0.6
      local c, sn = cos(ship.a), sin(ship.a)
      K.color("#FF7A45", 0.8)
      TF[1], TF[2] = ox + (ship.x - c * 9 - sn * 6) * S, oy + (ship.y - sn * 9 + c * 6) * S
      TF[3], TF[4] = ox + (ship.x - c * (9 + 18 * fl)) * S, oy + (ship.y - sn * (9 + 18 * fl)) * S
      TF[5], TF[6] = ox + (ship.x - c * 9 + sn * 6) * S, oy + (ship.y - sn * 9 - c * 6) * S
      gfx.poly(TF)
    end
    shipShape(ox + ship.x * S, oy + ship.y * S, ship.a, S, "#7DF9FF", 1)
    if ship.inv > 0 and K.state == "play" then
      K.color("#7DF9FF", 0.25 + 0.15 * sin(t * 10))
      gfx.circleLine(ox + ship.x * S, oy + ship.y * S, 26 * S, 2)
    end
  end
  K.drawParticles(S, ox, oy)
  K.drawPopups(S, ox, oy, 18)
  gfx.unclip()
  -- HUD
  local x = 12
  x = x + K.scorePill(x, 8) + 8
  x = x + K.pill(x, 8, "public", TR("wave_n", wave), "#FF7A45") + 8
  -- lives as little ships
  gfx.color(0, 0, 0, 120)
  gfx.rect(x, 8, 20 + max(1, lives) * 22, 34, 17)
  for i = 1, lives do shipShape(x + 4 + i * 22, 25, -pi / 2, 0.6, "#7DF9FF", 1) end
  K.bestPill(w - 60, 8)
end

return K.run(G)
