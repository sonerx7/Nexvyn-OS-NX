-- Zıpla Zıpla / Sky Jumper for Nexvyn OS: a Doodle Jump-style vertical platformer. Bounce from platform to
-- platform, wrap around the sides, use springs and rockets, collect coins and climb from the sky into space.
-- Moving, crumbling and one-time platforms appear as you climb.
local K = require("arcade")
local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi
local random = math.random

local W, VH = 480, 720
local GRAV, JUMP, SPRING = 1450, 740, 1250
local G = {icon = "keyboard_double_arrow_up", accent = "#34C759", overIcon = "south"}

local S, OX = 1, 0
local hero = {x = W / 2, y = 600, vy = 0, vx = 0, face = 1, squash = 0, rocket = 0}
local plats = {}                -- {x, y, w, kind, vx, broken, used, spring, coin, t}
local camY, topY, best = 0, 600, 0
local coins, springs, rockets = 0, 0, 0
local touchDir = 0
local falling = false
local CLOUDS = {}
for i = 1, 10 do CLOUDS[i] = {random() * W, random() * 2000, 0.4 + random() * 0.6} end
local STARS = {}
for i = 1, 60 do STARS[i] = {random() * W, random() * VH, random() * 1.6 + 0.4} end

function G.controls() return {TR("c_move"), TR("c_touch")} end

function G.layout(w, h)
  S = min(h / VH, w / W)
  OX = floor((w - W * S) / 2)
end

local function height() return max(0, floor((600 - hero.y) / 10)) end

local function addPlatform(y)
  local hgt = (600 - y) / 10
  local d = min(1, hgt / 3000)
  local p = {x = 0, y = y, w = 70 - d * 16, kind = "n", vx = 0, broken = false, used = false, spring = false,
    coin = false, t = 0}
  p.x = random() * (W - p.w)
  local r = random()
  if hgt > 150 and r < 0.12 + d * 0.15 then
    p.kind = "move"
    p.vx = (random() < 0.5 and -1 or 1) * (60 + d * 120)
  elseif hgt > 300 and r < 0.22 + d * 0.15 then
    p.kind = "crumble"
  elseif hgt > 500 and r < 0.30 + d * 0.15 then
    p.kind = "once"
  end
  if p.kind ~= "crumble" then
    local q = random()
    if q < 0.06 then p.spring = true
    elseif q < 0.075 and hgt > 200 then p.rocket = true
    elseif q < 0.25 then p.coin = true end
  end
  plats[#plats + 1] = p
  return p
end

local function generate()
  while topY > camY - 120 do
    local hgt = (600 - topY) / 10
    local gap = 55 + min(1, hgt / 3000) * 85 + random() * 25
    topY = topY - gap
    local p = addPlatform(topY)
    -- a crumbling platform alone could strand the player: add a safe one next to it
    if p.kind == "crumble" then
      local q = addPlatform(topY - 20)
      q.kind, q.vx = "n", 0
    end
  end
end

function G.reset()
  plats = {}
  hero.x, hero.y, hero.vy, hero.vx, hero.face, hero.squash, hero.rocket = W / 2, 560, -JUMP, 0, 1, 0, 0
  camY = 0
  topY = 620
  coins, springs, rockets = 0, 0, 0
  falling = false
  touchDir = 0
  local base = {x = W / 2 - 50, y = 620, w = 100, kind = "n", vx = 0, broken = false, used = false, t = 0}
  plats[1] = base
  generate()
end

function G.pointer(e)
  if e.type == "mousedown" or (e.type == "mousemove" and touchDir ~= 0) then
    touchDir = e.x < OX + W * S / 2 and -1 or 1
  elseif e.type == "mouseup" then
    touchDir = 0
  end
end

local function bounce(p, playing)
  hero.squash = 1
  if p.spring then
    hero.vy = -SPRING
    K.burst(hero.x, p.y, 16, "#FFD60A", 220, 0.5, 3, 0, -pi / 2, 1.4)
    if playing then
      springs = springs + 1
      K.chord({523, 784, 1047}, 0.12, 0.09, "triangle")
      K.callout(TR("boing"), "#FFD60A", 28, "spring", 0.7)
    end
  elseif p.rocket then
    p.rocket = false
    hero.rocket = 2.2
    if playing then
      rockets = rockets + 1
      K.callout(TR("rocket"), "#FF6B35", 32, "rocket")
      K.sfx("power")
    end
  else
    hero.vy = -JUMP
    if playing then K.chord({440 + min(height(), 3000) * 0.1, 660 + min(height(), 3000) * 0.15}, 0.05, 0.07, "square") end
  end
  K.burst(hero.x, p.y, 6, p.kind == "move" and "#64D2FF" or "#7CFC6A", 90, 0.35, 2, 200, -pi / 2, 2)
  if p.kind == "once" then
    p.broken = true
    K.burst(p.x + p.w / 2, p.y, 12, "#FFFFFF", 120, 0.5, 2.5)
  end
end

local function simulate(dt, demo)
  local playing = not demo
  -- input
  local ax = 0
  if demo then
    local target = nil
    for _, p in ipairs(plats) do
      if not p.broken and p.kind ~= "crumble" and p.y < hero.y - 30 and p.y > hero.y - 220 then
        if not target or p.y > target.y then target = p end
      end
    end
    if target then ax = K.clamp((target.x + target.w / 2 - hero.x) / 60, -1, 1) end
  else
    ax = K.axis()
    if touchDir ~= 0 then ax = touchDir end
  end
  hero.vx = K.smooth(hero.vx, ax * 380, 9, dt)
  if abs(ax) > 0.1 then hero.face = ax > 0 and 1 or -1 end
  hero.x = hero.x + hero.vx * dt
  if hero.x < -15 then hero.x = hero.x + W + 30 elseif hero.x > W + 15 then hero.x = hero.x - W - 30 end
  -- vertical
  if hero.rocket > 0 then
    hero.rocket = hero.rocket - dt
    hero.vy = -1000
    K.burst(hero.x, hero.y + 20, 2, random() < 0.5 and "#FFD60A" or "#FF6B35", 160, 0.4, 3, 0, pi / 2, 0.6)
    if playing and random() < 0.3 then K.tone(80 + random() * 40, 0.05, 0.06, "noise") end
  else
    hero.vy = hero.vy + GRAV * dt
  end
  local oldY = hero.y
  hero.y = hero.y + hero.vy * dt
  hero.squash = max(0, hero.squash - dt * 5)
  -- platforms
  for _, p in ipairs(plats) do
    p.t = p.t + dt
    if p.kind == "move" then
      p.x = p.x + p.vx * dt
      if p.x < 0 then p.x, p.vx = 0, abs(p.vx) elseif p.x > W - p.w then p.x, p.vx = W - p.w, -abs(p.vx) end
    end
    if p.fallV then
      p.fallV = p.fallV + GRAV * dt
      p.y = p.y + p.fallV * dt
    end
    if hero.vy > 0 and not p.broken and hero.rocket <= 0 and oldY + 18 <= p.y and hero.y + 18 >= p.y
      and hero.x + 14 > p.x and hero.x - 14 < p.x + p.w then
      if p.kind == "crumble" then
        p.broken, p.fallV = true, 0
        K.burst(p.x + p.w / 2, p.y, 14, "#A0522D", 120, 0.6, 3, 400)
        if playing then K.sfx("drop", 0.7) end
      else
        hero.y = p.y - 18
        bounce(p, playing)
      end
    end
    if p.coin and abs(hero.x - (p.x + p.w / 2)) < 26 and abs(hero.y - (p.y - 34)) < 26 then
      p.coin = false
      K.burst(p.x + p.w / 2, p.y - 34, 14, "#FFD60A", 150, 0.5, 2.5)
      if playing then
        coins = coins + 1
        local c = K.comboHit(2.5, "#FFD60A")
        local pts = 50 * min(c, 6)
        K.addScore(pts)
        K.popup(p.x + p.w / 2, p.y - 50, "+" .. pts, "#FFD60A")
        K.sfx("coin", 0.8)
      end
    end
  end
  -- camera follows upward only (and down when falling)
  local target = hero.y - VH * 0.45
  if target < camY then camY = K.smooth(camY, target, 10, dt) end
  if hero.y > camY + VH + 40 then
    if demo then G.reset() return end
    if not falling then
      falling = true
      K.sfx("lose")
      K.vibrate(0.8, 200)
      K.over({stats = {{TR("height"), height() .. " m"}, {TR("coins"), tostring(coins)},
        {TR("springs"), tostring(springs)}, {TR("rockets"), tostring(rockets)}}})
    end
    return
  end
  -- score from height
  local hgt = height()
  if playing and hgt > best then
    if floor(hgt / 500) > floor(best / 500) then
      K.callout(TR("height_n", floor(hgt / 500) * 500), "#34C759", 34, "height")
      K.sfx("level", 0.8)
    end
    K.score = K.score + (hgt - best)
    best = hgt
  end
  generate()
  -- forget platforms far below
  local i = 1
  while i <= #plats do
    if plats[i].y > camY + VH + 200 then table.remove(plats, i) else i = i + 1 end
  end
end

function G.update(dt) simulate(dt, false) end
function G.idle(dt) if K.state == "title" then simulate(dt, true) end end

local oldReset = G.reset
G.reset = function()
  oldReset()
  best = 0
end

-- ------------------------------------------------------------------ drawing
function G.draw(w, h)
  local t = K.now
  local alt = min(1, height() / 4000)
  -- sky turns into space as you climb
  K.mix("#5AC8FA", "#0B0D2E", alt)
  gfx.rect(0, 0, w, h)
  gfx.gradient(0, h * 0.5, w, h * 0.5, "#00000000", alt > 0.5 and "#1A1040" or "#BDEBFF")
  local sx, sy = K.shakeXY()
  local ox, oy = OX + sx, sy
  local function Y(y) return oy + (y - camY) * S end
  gfx.clip(OX, 0, W * S, h)
  -- stars fade in at altitude, clouds fade out
  if alt > 0.2 then
    for i = 1, #STARS do
      local st = STARS[i]
      K.color("#FFFFFF", (alt - 0.2) * (0.5 + 0.5 * sin(t * 2 + i)))
      gfx.circle(ox + st[1] * S, oy + ((st[2] - camY * 0.1) % VH) * S, st[3] * S)
    end
  end
  for i = 1, #CLOUDS do
    local c = CLOUDS[i]
    local cy = (c[2] - camY * 0.3 * c[3]) % 2000 - 300
    K.color("#FFFFFF", 0.6 * (1 - alt))
    gfx.circle(ox + c[1] * S, oy + cy * S, 34 * c[3] * S)
    gfx.circle(ox + (c[1] + 36 * c[3]) * S, oy + (cy - 10) * S, 40 * c[3] * S)
    gfx.circle(ox + (c[1] + 72 * c[3]) * S, oy + cy * S, 30 * c[3] * S)
  end
  -- platforms
  for _, p in ipairs(plats) do
    local py = Y(p.y)
    if py > -40 and py < h + 40 and not (p.broken and p.kind == "once") then
      local x, pw = ox + p.x * S, p.w * S
      local c1, c2 = "#7CFC6A", "#2E9E44"
      if p.kind == "move" then c1, c2 = "#9EEBFF", "#0A84FF"
      elseif p.kind == "crumble" then c1, c2 = "#D2A26B", "#8B5A2B"
      elseif p.kind == "once" then c1, c2 = "#FFFFFF", "#C7C7CC" end
      gfx.color(0, 0, 0, 50)
      gfx.rect(x + 3, py + 4, pw, 14 * S, 7 * S)
      gfx.gradient(x, py, pw, 14 * S, c1, c2, false, 7 * S)
      if p.kind == "crumble" then
        K.color("#5A3A1A", 0.7)
        gfx.line(x + pw * 0.3, py, x + pw * 0.4, py + 14 * S, 2)
        gfx.line(x + pw * 0.7, py, x + pw * 0.6, py + 14 * S, 2)
      end
      if p.spring then
        local cx = x + pw / 2
        K.color("#8E8E93")
        gfx.rect(cx - 8 * S, py - 12 * S, 16 * S, 12 * S, 2)
        K.color("#FFD60A")
        gfx.rect(cx - 11 * S, py - 15 * S, 22 * S, 5 * S, 2)
      end
      if p.rocket then
        gfx.icon("rocket", x + pw / 2, py - 20 * S, 30 * S, "#FF6B35")
      end
      if p.coin then
        local wv = abs(cos(t * 3 + p.x))
        K.color("#FFD60A", 0.3)
        gfx.circle(x + pw / 2, py - 34 * S, 15 * S)
        K.color("#FFC300")
        gfx.rect(x + pw / 2 - 10 * S * wv, py - 44 * S, 20 * S * wv, 20 * S, 10 * S * wv)
      end
    end
  end
  -- hero: a round jumper with squash and stretch
  local hx, hy = ox + hero.x * S, Y(hero.y)
  local stretch = K.clamp(-hero.vy / 2000, -0.15, 0.25)
  local sq = hero.squash * 0.3
  local rw, rh = 18 * S * (1 + sq - stretch * 0.5), 18 * S * (1 - sq + stretch)
  if hero.rocket > 0 then
    K.color("#FF6B35")
    gfx.rect(hx - 8 * S, hy + 4 * S, 16 * S, 18 * S, 4 * S)
  end
  K.color("#34C759", 0.25)
  gfx.circle(hx, hy, 26 * S)
  K.color("#34C759")
  gfx.rect(hx - rw, hy - rh, rw * 2, rh * 2, min(rw, rh))
  K.color("#9DFFB0")
  gfx.rect(hx - rw * 0.6, hy - rh * 0.1, rw * 1.2, rh * 0.9, min(rw, rh) * 0.6)
  for k = -1, 1, 2 do
    local ex = hx + hero.face * 5 * S + k * 6 * S
    K.color("#FFFFFF")
    gfx.circle(ex, hy - rh * 0.35, 5 * S)
    K.color("#1C1C1E")
    gfx.circle(ex + hero.face * 2 * S, hy - rh * 0.35 + (hero.vy > 0 and 1.5 or -1.5) * S, 2.5 * S)
  end
  K.drawParticles(S, ox, oy - camY * S)
  K.drawPopups(S, ox, oy - camY * S, 18)
  gfx.unclip()
  -- side panels
  K.color("#000000", 0.25)
  gfx.rect(0, 0, OX, h)
  gfx.rect(OX + W * S, 0, w - OX - W * S, h)
  -- HUD
  local x = 12
  x = x + K.scorePill(x, 8) + 8
  K.pill(x, 8, "height", height() .. " m", "#34C759")
  K.bestPill(w - 60, 8)
end

return K.run(G)
