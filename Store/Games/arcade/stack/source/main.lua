-- Kule Kur / Tower Stack for Nexvyn OS: a sliding block crosses the screen, drop it on the tower in time.
-- The overhang is cut off and tumbles away; perfect drops keep the full width, build a streak and even grow
-- the block back. Colors drift with every floor and the camera eases up as the tower climbs.
local K = require("arcade")
local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi
local random = math.random

local W = 480
local BH = 30
local BASEY = 560
local DEPTH = 16                       -- fake 3D: top face depth
local G = {icon = "stacked_bar_chart", accent = "#FF9F0A", overIcon = "layers"}

local S, OX, OYW = 1, 0, 600            -- scale, x offset, visible world height
local tower = {}                        -- {x, w, hue, born}
local mover = {x = 0, w = 200, dir = 1, speed = 160}
local DEB = {}
for i = 1, 12 do DEB[i] = {on = false, x = 0, y = 0, w = 0, vx = 0, vy = 0, rot = 0, vr = 0, hue = 0} end
local QUAD, TOP = {0, 0, 0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0}
local camY, hue0 = 0, 0
local perfects, streak, dropping = 0, 0, false
local skyN, skyA, skyB = -1, "#1A2238", "#0D1020"
local demoT = 0
local ring = {t = 0, x = 0, y = 0, w = 0}

function G.controls() return {TR("c_drop"), TR("c_touch")} end

function G.layout(w, h)
  S = min(h / 600, w / W)
  OX = floor((w - W * S) / 2)
  OYW = h / S
end

local function topY() return BASEY - #tower * BH end

local function hueRGB(h, s, v)
  h = (h % 1) * 6
  local i = floor(h)
  local f = h - i
  local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
  local r, g, b
  if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
  return string.format("#%02X%02X%02X", floor(r * 255), floor(g * 255), floor(b * 255))
end

local function newMover()
  local top = tower[#tower]
  mover.w = top.w
  mover.dir = (#tower % 2 == 0) and 1 or -1
  mover.x = mover.dir > 0 and -mover.w * 0.6 or W - mover.w * 0.4
  mover.speed = min(430, 165 + #tower * 6)
end

function G.reset()
  tower = {}
  hue0 = random()
  tower[1] = {x = W / 2 - 110, w = 220, hue = hue0, born = -10}
  camY = 0
  perfects, streak, dropping = 0, 0, false
  for i = 1, #DEB do DEB[i].on = false end
  skyN = -1
  newMover()
end

local function debris(x, y, w, dir, hue)
  for i = 1, #DEB do
    local d = DEB[i]
    if not d.on then
      d.on, d.x, d.y, d.w, d.hue = true, x, y, w, hue
      d.vx, d.vy = dir * (40 + random() * 60), -40
      d.rot, d.vr = 0, dir * (1.5 + random() * 2)
      return
    end
  end
end

local function drop(playing)
  -- a press while the block is still completely off screen does nothing
  if mover.x + mover.w <= 0 or mover.x >= W then return end
  local top = tower[#tower]
  local y = topY()
  local hue = hue0 + #tower * 0.035
  local left, right = max(mover.x, top.x), min(mover.x + mover.w, top.x + top.w)
  local overlap = right - left
  if overlap <= 0 then
    -- missed the tower completely
    debris(mover.x, y - BH, mover.w, mover.dir, hue)
    if playing then
      K.sfx("drop")
      K.sfx("lose", 0.8)
      K.shake(10)
      K.vibrate(0.8, 200)
      K.over({stats = {{TR("floors"), tostring(#tower - 1)}, {TR("perfects"), tostring(perfects)}}})
    else
      G.reset()
    end
    return
  end
  local perfect = abs(mover.x - top.x) <= 5
  local nx, nw = left, overlap
  if perfect then
    nx, nw = top.x, top.w
    streak = streak + 1
    if streak >= 3 then
      -- streaks grow the block back a little
      local grow = min(16, 220 - nw)
      nx, nw = nx - grow / 2, nw + grow
    end
  else
    streak = 0
    -- cut the overhang off and let it fall
    if mover.x < top.x then
      debris(mover.x, y - BH, top.x - mover.x, -1, hue)
    else
      debris(top.x + top.w, y - BH, mover.x + mover.w - (top.x + top.w), 1, hue)
    end
  end
  tower[#tower + 1] = {x = nx, w = nw, hue = hue, born = K.now}
  ring.t, ring.x, ring.y, ring.w = 0.5, nx, y - BH, nw
  K.burst(nx + nw / 2, y - BH / 2, perfect and 20 or 8, perfect and "#FFFFFF" or "#FFD60A", perfect and 200 or 100, 0.5, 2.5)
  if playing then
    local floors = #tower - 1
    if perfect then
      perfects = perfects + 1
      local c = K.comboHit(100, "#FFFFFF")
      K.addScore(1 + min(c, 10))
      K.popup(nx + nw / 2, y - BH - 10, TR("perfect"), "#FFFFFF")
      local base = 523 * 2 ^ (min(streak, 12) / 12)
      K.chord({base, base * 1.25, base * 1.5}, 0.12, 0.07, "triangle")
      K.vibrate(0.35, 50)
      K.shake(2)
    else
      K.comboBreak()
      K.addScore(1)
      K.sfx("drop", 0.8)
      K.tone(300 + floors * 4, 0.05, 0.06, "triangle")
      K.shake(3)
    end
    if floors % 25 == 0 then
      K.callout(TR("floors_n", floors), "#FF9F0A", 38, "floors")
      K.sfx("level", 0.8)
    end
  end
  newMover()
end

function G.press(act)
  if act == "a" or act == "b" or act == "up" or act == "down" then drop(true) end
end

function G.pointer(e)
  if e.type == "mousedown" then drop(true) end
end

local function simulate(dt, demo)
  mover.x = mover.x + mover.dir * mover.speed * dt
  if mover.dir > 0 and mover.x > W then mover.dir = -1
  elseif mover.dir < 0 and mover.x + mover.w < 0 then mover.dir = 1 end
  if demo then
    local top = tower[#tower]
    demoT = demoT + dt
    local err = abs(mover.x - top.x)
    if (err < 4 or (err < 30 and random() < 0.02)) and demoT > 0.3 then
      demoT = 0
      drop(false)
      if #tower > 40 then G.reset() end
    end
  end
  for i = 1, #DEB do
    local d = DEB[i]
    if d.on then
      d.vy = d.vy + 1200 * dt
      d.x, d.y = d.x + d.vx * dt, d.y + d.vy * dt
      d.rot = d.rot + d.vr * dt
      if d.y - camY > OYW + 200 then d.on = false end
    end
  end
  if ring.t > 0 then ring.t = ring.t - dt end
  -- camera: keep the top of the tower in the upper part of the view
  local want = min(0, topY() - OYW * 0.45)
  camY = K.smooth(camY, want, 5, dt)
end

function G.update(dt) simulate(dt, false) end
function G.idle(dt) if K.state == "title" then simulate(dt, true) end end

-- ------------------------------------------------------------------ drawing
local function block(x, y, bw, hue, a, ox, oy)
  local X, Y, BW2, H2, D = ox + x * S, oy + y * S, bw * S, BH * S, DEPTH * S
  -- top face (a parallelogram towards the back)
  TOP[1], TOP[2] = X, Y
  TOP[3], TOP[4] = X + D, Y - D * 0.6
  TOP[5], TOP[6] = X + BW2 + D, Y - D * 0.6
  TOP[7], TOP[8] = X + BW2, Y
  K.hsv(hue, 0.45, 1, a)
  gfx.poly(TOP)
  -- side face
  QUAD[1], QUAD[2] = X + BW2, Y
  QUAD[3], QUAD[4] = X + BW2 + D, Y - D * 0.6
  QUAD[5], QUAD[6] = X + BW2 + D, Y + H2 - D * 0.6
  QUAD[7], QUAD[8] = X + BW2, Y + H2
  K.hsv(hue, 0.7, 0.6, a)
  gfx.poly(QUAD)
  -- front face
  K.hsv(hue, 0.6, 0.85, a)
  gfx.rect(X, Y, BW2, H2)
  K.color("#FFFFFF", 0.18 * a)
  gfx.rect(X, Y, BW2, 3 * S)
end

function G.draw(w, h)
  local t = K.now
  local n = #tower
  if skyN ~= n then
    skyN = n
    skyA = hueRGB(hue0 + n * 0.035 + 0.5, 0.45, 0.32)
    skyB = hueRGB(hue0 + n * 0.035 + 0.6, 0.55, 0.12)
  end
  gfx.gradient(0, 0, w, h, skyA, skyB)
  -- drifting light particles in the background
  for i = 1, 20 do
    local px = (i * 137 + t * (8 + i)) % w
    local py = (i * 89 - camY * S * 0.2) % h
    K.color("#FFFFFF", 0.06 + 0.05 * sin(t + i))
    gfx.circle(px, py, 2 + i % 4)
  end
  local sx, sy = K.shakeXY()
  local ox, oy = OX + sx, sy - camY * S
  -- ground
  K.color("#000000", 0.25)
  gfx.rect(0, oy + BASEY * S, w, max(0, h - (oy + BASEY * S)))
  -- tower (only the visible floors)
  for i = 1, n do
    local b = tower[i]
    local y = BASEY - i * BH
    local sy2 = oy + y * S
    if sy2 > -BH * S * 2 and sy2 < h + BH * S then
      local land = K.easeOut((t - b.born) / 0.25)
      block(b.x, y - (1 - land) * 12, b.w, b.hue, 1, ox, oy)
    end
  end
  -- landing ring for feedback
  if ring.t > 0 then
    K.color("#FFFFFF", ring.t * 1.4)
    local grow = (0.5 - ring.t) * 30
    gfx.rectLine(ox + (ring.x - grow) * S, oy + (ring.y - grow * 0.5) * S, (ring.w + grow * 2) * S, (BH + grow) * S, 4, 2)
  end
  -- debris
  for i = 1, #DEB do
    local d = DEB[i]
    if d.on then
      local cx, cy = ox + (d.x + d.w / 2) * S, oy + (d.y + BH / 2) * S
      local c, s2 = cos(d.rot), sin(d.rot)
      local hw, hh = d.w * S / 2, BH * S / 2
      QUAD[1], QUAD[2] = cx - hw * c + hh * s2, cy - hw * s2 - hh * c
      QUAD[3], QUAD[4] = cx + hw * c + hh * s2, cy + hw * s2 - hh * c
      QUAD[5], QUAD[6] = cx + hw * c - hh * s2, cy + hw * s2 + hh * c
      QUAD[7], QUAD[8] = cx - hw * c - hh * s2, cy - hw * s2 + hh * c
      K.hsv(d.hue, 0.6, 0.8, 0.9)
      gfx.poly(QUAD)
    end
  end
  -- the sliding block
  if K.state ~= "over" then
    local y = topY() - BH
    block(mover.x, y, mover.w, hue0 + n * 0.035, 1, ox, oy)
    -- guide marks above the tower edges
    local top = tower[n]
    K.color("#FFFFFF", 0.25)
    gfx.rect(ox + top.x * S, oy + (y - 10) * S, 2, 8 * S)
    gfx.rect(ox + (top.x + top.w) * S - 2, oy + (y - 10) * S, 2, 8 * S)
  end
  K.drawParticles(S, ox, oy)
  K.drawPopups(S, ox, oy, 18)
  -- HUD: the floor count big in the middle
  if K.state == "play" then
    local s = tostring(floor(K.shown + 0.5))
    local fs = floor(54 * (1 + K.bump * 0.2) / 2) * 2
    gfx.color(0, 0, 0, 90)
    gfx.text(s, 3, 23, fs, "bold", "center", w)
    K.color("#FFFFFF")
    gfx.text(s, 0, 20, fs, "bold", "center", w)
    if streak >= 2 then
      K.color("#FFFFFF", 0.7 + 0.3 * sin(t * 8))
      gfx.text(TR("streak_n", streak), 0, 20 + fs + 4, 16, "semibold", "center", w)
    end
  end
  K.pill(12, 8, "layers", TR("floors_short", n - 1), "#FF9F0A")
  K.bestPill(w - 60, 8)
end

return K.run(G)
