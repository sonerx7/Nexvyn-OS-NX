-- Pinball (Langırt): a portrait table built on the nexvyn.game engine (romfs:/System/Lua/nexvyn/game).
-- Two flippers, a plunger, three pop bumpers, slingshots, drop targets, top rollover lanes, a playfield multiplier,
-- end-of-ball bonus, ball save and a saved high score. Circle-vs-segment physics with sub-steps, so the ball never
-- passes through a wall or a flipper. All art is drawn with shapes.

local game = require("nexvyn.game")
local fx = require("fx")

local G, I, U, A = game.gfx, game.input, game.ui, game.audio
local floor, ceil, sqrt, min, max, abs = math.floor, math.ceil, math.sqrt, math.min, math.max, math.abs
local cos, sin, pi, random = math.cos, math.sin, math.pi, math.random

local save = game.save.open("pinball")

-- ---------------------------------------------------------------- table geometry (table units, y down)
local TW, TH = 300, 540
local BALL_R = 7
local GRAV = 1000                              -- the table's slope
local MAX_V = 1600
local FL_LEN, FL_R = 50, 5.5
local FL_REST, FL_UP = 0.52, -0.42             -- flipper angles (left flipper convention)
local FL_UPSPD, FL_DNSPD = 26, 14              -- rad/s
local LANE_X, PL_Y, PL_TRAVEL = 262, 506, 26   -- plunger lane divider, plunger top at rest, pull distance
local BALLS = 3
local SAVE_TIME = 6                            -- ball save after each launch

local WALLS = {}
local function seg(x1, y1, x2, y2, e) WALLS[#WALLS + 1] = {x1, y1, x2, y2, e or 0.45} end
seg(10, 140, 10, 400); seg(10, 400, 72, 460)              -- left wall and inlane guide
seg(262, 400, 200, 460)                                   -- right inlane guide
seg(LANE_X, 170, LANE_X, 536)                             -- plunger lane divider
seg(290, 140, 290, 536); seg(LANE_X, 536, 290, 536)       -- outer right wall, lane floor
local ARC = {}
for i = 0, 18 do
  local a = pi + i * pi / 18
  ARC[#ARC + 1] = 150 + cos(a) * 140
  ARC[#ARC + 1] = 140 + sin(a) * 140
end
for i = 1, #ARC - 3, 2 do
  seg(ARC[i], ARC[i + 1], ARC[i + 2], ARC[i + 3], 0.35)
  WALLS[#WALLS].arc = true   -- drawn as one polyline
end
seg(82, 50, 82, 80); seg(118, 46, 118, 80); seg(154, 46, 154, 80); seg(190, 50, 190, 80)   -- top lane posts
seg(10, 340, 22, 350); seg(58, 432, 22, 411.6)            -- left slingshot cap and back
seg(262, 340, 250, 350); seg(214, 432, 250, 411.6)        -- right slingshot cap and back
local GATE = {LANE_X, 70, LANE_X, 170}                    -- one-way: the ball leaves the lane, never re-enters

local SLINGS = {
  {22, 350, 58, 432, 0.915, -0.402, poly = {22, 350, 58, 432, 22, 411.6}},
  {250, 350, 214, 432, -0.915, -0.402, poly = {250, 350, 250, 411.6, 214, 432}},
}
local BUMPERS = {{100, 165, 15}, {172, 165, 15}, {136, 215, 15}}
local POSTS = {{52, 250, 5}, {220, 250, 5}, {136, 120, 4}}
local TARGETS = {{98, 300, 118}, {126, 300, 146}, {154, 300, 174}}
local LANES = {{100, 63}, {136, 63}, {172, 63}}
local FLIPPERS = {{px = 78, py = 468, sign = 1}, {px = 194, py = 468, sign = -1}}

-- ---------------------------------------------------------------- input
I.bind("flipL", {pad = {"l", "zl", "left"}, key = {"left", "z", "a"}})
I.bind("flipR", {pad = {"r", "zr", "right"}, key = {"right", "m", "d"}})
I.bind("launch", {pad = {"a", "down"}, key = {"down", "space", "enter", "s"}})
I.touchControls{stick = false, pause = true}

-- ---------------------------------------------------------------- sounds
A.define("bumper", {wave = "square", volume = 0.09, notes = {{523, 0.03}, {784, 0.06}}})
A.define("sling", {wave = "square", volume = 0.08, notes = {{330, 0.03}, {247, 0.05}}})
A.define("flip", {wave = "noise", volume = 0.07, notes = {{200, 0.03}}})
A.define("thunk", {wave = "triangle", volume = 0.18, notes = {{150, 0.04}}})
A.define("target", {wave = "triangle", volume = 0.18, notes = "E6:0.04 G6:0.07"})
A.define("lane", {wave = "triangle", volume = 0.16, notes = "C6:0.04 E6:0.04 G6:0.06"})
A.define("launch", {wave = "noise", volume = 0.16, notes = {{600, 0.05}, {300, 0.12}}})
A.define("drain", {wave = "saw", volume = 0.16, notes = "E4:0.12 C4:0.12 G3:0.12 C3:0.35"})
A.define("tickup", {wave = "square", volume = 0.04, notes = {{1200, 0.015}}})
local SONG = {bpm = 140, wave = "square", volume = 0.025, div = 2,
              notes = "E5 G5 A5 G5 E5 D5 C5 D5 E5 G5 A5 C6 B5 A5 G5 -",
              bass = "A2:2 A2:2 F2:2 F2:2 C3:2 C3:2 G2:2 G2:2"}

local function bumperChord(i) fx.chord(i == 1 and "C6 E6" or (i == 2 and "D6 F6" or "E6 G6"), 0.07, 0.05, "square") end
local function bigFanfare() fx.chord("C5 E5 G5", 0.12, 0.07, "square"); game.tween.after(0.12, function() fx.chord("E5 G5 C6", 0.3, 0.07, "triangle") end) end

-- ---------------------------------------------------------------- physics helpers
-- ball vs segment, the segment may rotate around (px, py) with angular speed w; returns the impact speed
local function segHit(b, x1, y1, x2, y2, rad, e, px, py, w)
  local ex, ey = x2 - x1, y2 - y1
  local l2 = ex * ex + ey * ey
  local t = 0
  if l2 > 0 then
    t = ((b.x - x1) * ex + (b.y - y1) * ey) / l2
    if t < 0 then t = 0 elseif t > 1 then t = 1 end
  end
  local cx, cy = x1 + ex * t, y1 + ey * t
  local dx, dy = b.x - cx, b.y - cy
  local d2 = dx * dx + dy * dy
  if d2 >= rad * rad then return 0 end
  local d = sqrt(d2)
  local nx, ny
  if d > 1e-6 then
    nx, ny = dx / d, dy / d
  else
    local l = sqrt(l2)
    if l < 1e-6 then nx, ny = 0, -1 else nx, ny = -ey / l, ex / l end
  end
  b.x, b.y = cx + nx * rad, cy + ny * rad
  local svx, svy = 0, 0
  if w then svx, svy = -w * (cy - py), w * (cx - px) end
  local vn = (b.vx - svx) * nx + (b.vy - svy) * ny
  if vn >= 0 then return 0 end
  b.vx, b.vy = b.vx - (1 + e) * vn * nx, b.vy - (1 + e) * vn * ny
  return -vn
end

local function circleHit(b, cx, cy, rad, e)
  local dx, dy = b.x - cx, b.y - cy
  local d2 = dx * dx + dy * dy
  if d2 >= rad * rad then return 0, 0, 0 end
  local d = sqrt(d2)
  local nx, ny = 0, -1
  if d > 1e-6 then nx, ny = dx / d, dy / d end
  b.x, b.y = cx + nx * rad, cy + ny * rad
  local vn = b.vx * nx + b.vy * ny
  if vn >= 0 then return 0, nx, ny end
  b.vx, b.vy = b.vx - (1 + e) * vn * nx, b.vy - (1 + e) * vn * ny
  return -vn, nx, ny
end

local function flipperTip(f)
  return f.px + f.sign * FL_LEN * cos(f.a), f.py + FL_LEN * sin(f.a)
end

-- ---------------------------------------------------------------- the table simulation
-- Shared by the game and the self-playing title screen. `on(kind, x, y, i)` receives events.
local Table = {}
Table.__index = Table

function Table.new(on)
  local t = setmetatable({on = on or function() end}, Table)
  t.ball = {x = 276, y = PL_Y - BALL_R, vx = 0, vy = 0}
  t.flippers = {}
  for i, f in ipairs(FLIPPERS) do
    t.flippers[i] = {px = f.px, py = f.py, sign = f.sign, a = FL_REST, rate = 0, held = false}
  end
  t.bflash, t.sflash = {0, 0, 0}, {0, 0}
  t.targets, t.lanes = {true, true, true}, {false, false, false}
  t.inLane = {false, false, false}
  t.pull, t.prevLaunch, t.targetReset, t.laneFlash, t.multFlash = 0, false, 0, 0, 0
  t.mult, t.saveT = 1, 0
  return t
end

function Table:resetBall()
  local b = self.ball
  b.x, b.y, b.vx, b.vy = 276, PL_Y - BALL_R, 0, 0
  self.pull = 0
end

function Table:onPlunger()
  local b = self.ball
  return b.x > LANE_X and b.y > PL_Y - BALL_R - 4 and abs(b.vy) < 60
end

-- the lit top lanes move with the flippers (classic "lane change")
function Table:laneChange(dir)
  local l = self.lanes
  if dir < 0 then l[1], l[2], l[3] = l[2], l[3], l[1] else l[1], l[2], l[3] = l[3], l[1], l[2] end
end

function Table:step(dt, inL, inR, inLaunch)
  local b, fl = self.ball, self.flippers
  -- flippers
  for i, f in ipairs(fl) do
    local held = (i == 1 and inL) or (i == 2 and inR)
    if held and not f.held then self.on("flip", f.px, f.py, i); self:laneChange(i == 1 and -1 or 1) end
    f.held = held
  end
  -- plunger: hold to pull, release to fire
  if inLaunch then
    self.pull = min(1, self.pull + dt * 1.1)
  elseif self.prevLaunch then
    if self.pull > 0.05 and self:onPlunger() then
      b.vy = -(620 + 760 * self.pull)
      self.saveT = SAVE_TIME
      self.on("launch", b.x, b.y, 0)
    end
    self.pull = 0
  end
  self.prevLaunch = inLaunch
  -- timers
  self.saveT = max(0, self.saveT - dt)
  for i = 1, 3 do self.bflash[i] = max(0, self.bflash[i] - dt * 4) end
  for i = 1, 2 do self.sflash[i] = max(0, self.sflash[i] - dt * 5) end
  self.laneFlash, self.multFlash = max(0, self.laneFlash - dt), max(0, self.multFlash - dt)
  if self.targetReset > 0 then
    self.targetReset = self.targetReset - dt
    if self.targetReset <= 0 then self.targets[1], self.targets[2], self.targets[3] = true, true, true end
  end
  -- sub-steps: the ball moves at most ~2.5 units per step
  local speed = sqrt(b.vx * b.vx + b.vy * b.vy)
  local n = max(4, min(30, ceil(speed * dt / 2.5)))
  local h = dt / n
  local plY = PL_Y + self.pull * PL_TRAVEL
  for _ = 1, n do
    for i = 1, 2 do
      local f = fl[i]
      local target = f.held and FL_UP or FL_REST
      local old = f.a
      if f.a > target then f.a = max(target, f.a - FL_UPSPD * h) elseif f.a < target then f.a = min(target, f.a + FL_DNSPD * h) end
      f.rate = (f.a - old) / h
    end
    b.vy = b.vy + GRAV * h
    b.x, b.y = b.x + b.vx * h, b.y + b.vy * h
    self:collide(b, plY)
  end
  speed = sqrt(b.vx * b.vx + b.vy * b.vy)
  if speed > MAX_V then b.vx, b.vy = b.vx / speed * MAX_V, b.vy / speed * MAX_V end
  if b.y > TH + 20 or b.x < -20 or b.x > TW + 20 then self.on("drain", b.x, b.y, 0) end
end

function Table:collide(b, plY)
  local R = BALL_R
  for i = 1, #WALLS do
    local w = WALLS[i]
    local imp = segHit(b, w[1], w[2], w[3], w[4], R + 1.5, w[5])
    if imp > 220 then self.on("wall", b.x, b.y, imp) end
  end
  if b.x < LANE_X then segHit(b, GATE[1], GATE[2], GATE[3], GATE[4], R + 1.5, 0.3) end
  -- plunger top
  if b.x > LANE_X and b.y > plY - R then
    b.y = plY - R
    if b.vy > 0 then b.vy = b.vy > 150 and -b.vy * 0.25 or 0 end
  end
  -- slingshots kick the ball away
  for i = 1, 2 do
    local s = SLINGS[i]
    local imp = segHit(b, s[1], s[2], s[3], s[4], R + 2, 0.5)
    if imp > 60 then
      b.vx, b.vy = b.vx + s[5] * 280, b.vy + s[6] * 280
      self.sflash[i] = 1
      self.on("sling", b.x, b.y, i)
    end
  end
  -- pop bumpers: always at least 400 units/s away
  for i = 1, 3 do
    local bp = BUMPERS[i]
    local imp, nx, ny = circleHit(b, bp[1], bp[2], bp[3] + R, 0.9)
    if imp > 0 then
      local vn = b.vx * nx + b.vy * ny
      if vn < 400 then b.vx, b.vy = b.vx + (400 - vn) * nx, b.vy + (400 - vn) * ny end
      self.bflash[i] = 1
      self.on("bumper", bp[1] + nx * bp[3], bp[2] + ny * bp[3], i)
    end
  end
  for i = 1, #POSTS do
    local p = POSTS[i]
    local imp = circleHit(b, p[1], p[2], p[3] + R, 0.75)
    if imp > 80 then self.on("post", b.x, b.y, i) end
  end
  -- drop targets
  for i = 1, 3 do
    if self.targets[i] then
      local t = TARGETS[i]
      local imp = segHit(b, t[1], t[2], t[3], t[2], R + 3, 0.5)
      if imp > 40 then
        self.targets[i] = false
        self.on("target", (t[1] + t[3]) / 2, t[2], i)
        if not self.targets[1] and not self.targets[2] and not self.targets[3] then
          self.targetReset = 1.2
          self:raiseMult()
          self.on("targets", 136, 300, 0)
        end
      end
    end
  end
  -- rollover lanes light up when the ball passes over them
  for i = 1, 3 do
    local l = LANES[i]
    local dx, dy = b.x - l[1], b.y - l[2]
    local over = dx * dx + dy * dy < 144
    if over and not self.inLane[i] then
      if not self.lanes[i] then
        self.lanes[i] = true
        self.on("lane", l[1], l[2], i)
        if self.lanes[1] and self.lanes[2] and self.lanes[3] then
          self.lanes[1], self.lanes[2], self.lanes[3] = false, false, false
          self.laneFlash = 1.2
          self:raiseMult()
          self.on("lanes", 136, 63, 0)
        end
      end
    end
    self.inLane[i] = over
  end
  -- flippers (moving surfaces)
  for i = 1, 2 do
    local f = self.flippers[i]
    local tx, ty = flipperTip(f)
    local imp = segHit(b, f.px, f.py, tx, ty, R + FL_R, 0.25, f.px, f.py, f.sign * f.rate)
    if imp > 250 then self.on("hitflip", b.x, b.y, imp) end
  end
end

function Table:raiseMult()
  if self.mult < 5 then self.mult = self.mult + 1 end
  self.multFlash = 1.5
end

-- ---------------------------------------------------------------- drawing (table units)
local TRI = {0, 0, 0, 0, 0, 0}
local function drawTable(t, time, trail)
  -- cabinet and playfield
  G.rect(-6, -6, TW + 12, TH + 12, 14, "#120A24")
  G.gradient(10, 0, LANE_X - 10, TH, "#251150", "#0E1838")
  G.gradient(LANE_X, 0, TW - LANE_X - 10, TH, "#1A0E38", "#0B1028")
  -- artwork: rings and a starburst
  G.color(255, 255, 255, 12)
  for r = 30, 120, 30 do G.circleLine(136, 215, r, 2) end
  G.color(255, 120, 220, 22)
  for k = 0, 11 do
    local a = k * pi / 6 + time * 0.1
    G.line(136, 215, 136 + cos(a) * 110, 215 + sin(a) * 110, 1)
  end
  -- multiplier lights
  for m = 2, 5 do
    local x, y = 136 + (m - 3.5) * 24, 372
    local lit = t.mult >= m
    local blink = t.multFlash > 0 and floor(t.multFlash * 8) % 2 == 0
    G.circle(x, y, 9, lit and (blink and "#FFFFFF" or "#FFB020") or "#FFB02030")
    G.color(lit and "#2A1400" or "#FFB02080")
    G.text(m .. "x", x - 10, y - 5, 8, "bold", "center", 20)
  end
  -- ball save light
  if t.saveT > 0 and floor(time * 6) % 2 == 0 then
    G.color("#7CFFB2")
    G.text(TR("shoot_again"), 86, 392, 8, "bold", "center", 100)
  end
  -- arrows pointing at the drop targets (lit while they are up)
  for i = 1, 3 do
    local tg = TARGETS[i]
    local cx = (tg[1] + tg[3]) / 2
    TRI[1], TRI[2], TRI[3], TRI[4], TRI[5], TRI[6] = cx, 318, cx - 6, 330, cx + 6, 330
    G.poly(TRI, t.targets[i] and "#FFE06688" or "#FFE06622")
  end
  -- walls: glow, colour, highlight
  for pass = 1, 3 do
    if pass == 1 then G.color(80, 220, 255, 40) elseif pass == 2 then G.color("#36C5F0") else G.color("#E8FBFF") end
    local th = pass == 1 and 7 or (pass == 2 and 3 or 1)
    G.lines(ARC, th, false)
    for i = 1, #WALLS do
      local w = WALLS[i]
      if not w.arc then G.line(w[1], w[2], w[3], w[4], th) end
    end
  end
  G.color(255, 255, 255, 70)
  G.line(GATE[1], GATE[2], GATE[3], GATE[4], 1)
  -- top rollover lanes
  for i = 1, 3 do
    local l = LANES[i]
    local lit = t.lanes[i] or (t.laneFlash > 0 and floor(t.laneFlash * 10) % 2 == 0)
    G.circle(l[1], l[2], 6, lit and "#7CFFB2" or "#7CFFB230")
    G.color(255, 255, 255, lit and 200 or 60)
    G.circleLine(l[1], l[2], 8, 1)
  end
  -- slingshots
  for i = 1, 2 do
    local s = SLINGS[i]
    local f = t.sflash[i]
    G.poly(s.poly, f > 0 and "#FFFFFF" or "#C2185B")
    G.color(f > 0 and "#FFFFFF" or "#FF6BB5")
    G.line(s[1], s[2], s[3], s[4], 3)
  end
  -- posts
  for _, p in ipairs(POSTS) do
    G.circle(p[1], p[2], p[3] + 1, "#FFFFFF")
    G.circle(p[1], p[2], p[3] - 1.5, "#FF4D8D")
  end
  -- bumpers pulse when hit
  for i = 1, 3 do
    local bp = BUMPERS[i]
    local f = t.bflash[i]
    local r = bp[3] * (1 + 0.22 * fx.ease("outQuad", f))
    G.circle(bp[1] + 2, bp[2] + 3, r, "#00000060")
    G.circle(bp[1], bp[2], r, f > 0 and "#FFF6C0" or "#FF6B35")
    G.circle(bp[1], bp[2], r * 0.72, f > 0 and "#FFFFFF" or "#FFC94D")
    G.circle(bp[1], bp[2], r * 0.38, "#B23A12")
    G.color(255, 255, 255, 150)
    G.circleLine(bp[1], bp[2], r, 1.5)
  end
  -- drop targets
  for i = 1, 3 do
    local tg = TARGETS[i]
    if t.targets[i] then
      G.rect(tg[1], tg[2] - 3, tg[3] - tg[1], 6, 2, "#FFE066")
      G.rect(tg[1] + 2, tg[2] - 2, tg[3] - tg[1] - 4, 1.5, 1, "#FFFFFF")
    else
      G.color(255, 224, 102, 70)
      G.rectLine(tg[1], tg[2] - 3, tg[3] - tg[1], 6, 2, 1)
    end
  end
  -- plunger
  local py = PL_Y + t.pull * PL_TRAVEL
  G.color("#8892A6")
  for k = 0, 5 do
    local y1 = py + 2 + k * (534 - py) / 6
    local y2 = py + 2 + (k + 0.5) * (534 - py) / 6
    G.line(268, y1, 284, y2, 1.5)
    G.line(284, y2, 268, y2 + (534 - py) / 12, 1.5)
  end
  G.rect(265, py, 22, 5, 2, t.pull > 0 and "#FF6B6B" or "#D0D6E2")
  -- flippers
  for i = 1, 2 do
    local f = t.flippers[i]
    local tx, ty = flipperTip(f)
    G.color(0, 0, 0, 90)
    G.line(f.px + 2, f.py + 3, tx + 2, ty + 3, FL_R * 2 + 1)
    G.color(f.held and "#FFFFFF" or "#F0F4FF")
    G.line(f.px, f.py, tx, ty, FL_R * 2 + 1)
    G.color("#E53958")
    G.line(f.px, f.py, tx, ty, FL_R * 1.1)
    G.circle(f.px, f.py, FL_R + 1.5, "#B0B8C8")
  end
  -- ball with a light trail
  if trail then trail:draw() end
  local b = t.ball
  G.circle(b.x + 2, b.y + 3, BALL_R, "#00000070")
  G.circle(b.x, b.y, BALL_R, "#C9D1DE")
  G.circle(b.x - 1, b.y - 1, BALL_R * 0.75, "#E9EEF6")
  G.circle(b.x - 2.5, b.y - 2.5, BALL_R * 0.3, "#FFFFFF")
end

-- table placement in the virtual screen
local V = {x = 0, y = 0, s = 1}
local function layout()
  local W, H = game.width, game.height
  local s = min((H - 8) / TH, (W * 0.56) / TW)
  V.s, V.x, V.y = s, (W - TW * s) / 2, (H - TH * s) / 2
end

-- ---------------------------------------------------------------- scenes
local Title, Play, Over = {pausable = false}, {controls = true}, {transparent = true, pausable = false}

-- title: the table plays itself in attract mode
function Title:enter()
  self.t, self.hold, self.flip = 0, 0, {0, 0}
  self.table = Table.new(function(kind) if kind == "drain" then self.table:resetBall() end end)
  self.logo = {y = -40, a = 0}
  self.tweens:to(self.logo, 0.9, {y = 0, a = 1}, "outBack")
  self.menu = U.menu{width = 170, items = {
    {label = function() return TR("play") end, action = function() game.switch(Play) end},
    fx.soundItem(),
    {label = function() return TR("quit") end, action = function() sys.exit() end},
  }}
  A.stopSong()
end
function Title:update(dt)
  self.t = self.t + dt
  self.menu:update()
  local tb = self.table
  local b = tb.ball
  -- simple autopilot: a short flip when the ball falls onto a flipper, pull the plunger when the ball waits
  local fl = self.flip
  fl[1], fl[2] = max(0, fl[1] - dt), max(0, fl[2] - dt)
  if b.y > 425 and b.y < 488 and b.vy > 20 and b.x < LANE_X then
    local side = b.x < 136 and 1 or 2
    if fl[side] <= 0 then fl[side] = 0.28 end
  end
  local launch = false
  if tb:onPlunger() then
    self.hold = self.hold + dt
    launch = self.hold < 0.9
  else
    self.hold = 0
  end
  tb:step(dt, fl[1] > 0.08, fl[2] > 0.08, launch)
end
function Title:draw()
  G.gradient(0, 0, game.width, game.height, "#1A0B33", "#06060F")
  layout()
  G.push(V.x, V.y, V.s)
  drawTable(self.table, self.t)
  G.pop()
  G.rect(0, 0, game.width, game.height, 0, "#00000070")
end
function Title:ui()
  local y = game.height * 0.12 + self.logo.y
  G.alpha(max(0, min(1, self.logo.a)))
  local glow = 0.5 + 0.5 * sin(self.t * 3)
  U.text(TR("logo"), 0, y, 34, "#FFFFFF", "center", game.width, "bold", glow > 0.5 and "#FF2D95" or "#36C5F0")
  G.unalpha()
  U.text(TR("high_score", save:get("high", 0)), 0, y + 44, 12, "#FFE27A", "center", game.width)
  self.menu:draw(game.width / 2, y + 66)
  fx.fitLine(TR("controls"), game.height - 16, 9)
end

-- play -----------------------------------------------------------------------------------------------
function Play:enter()
  self.pop = fx.popups(10)
  self.shake = fx.shake()
  self.sparks = game.emitter{max = 160, life = {0.2, 0.6}, speed = {80, 260}, damping = 2.5, size = {3, 0},
                             shape = "line", lineScale = 0.03, colors = {"#FFFFFF", "#FFD166", "#FF6B3500"}}
  self.trail = game.emitter{max = 60, life = {0.12, 0.3}, speed = {0, 10}, size = {6, 0},
                            colors = {"#9FE8FF60", "#7B5CFF00"}}
  self:newGame()
  A.song(SONG)
end
function Play:leave() A.stopSong() end

function Play:newGame()
  self.table = Table.new(function(kind, x, y, i) self:event_(kind, x, y, i) end)
  self.score, self.ball, self.bonus = 0, 1, 0
  self.stats = {bumpers = 0, targets = 0, bestMult = 1}
  self.state, self.timer, self.stall = "ready", 0, 0
  self.pop:clear()
  self.sparks:clear(); self.trail:clear()
  self.shown = {score = 0}
  self.pop:add(TR("ball_n", 1, BALLS), TW / 2, 250, "#FFFFFF", 25, 1.4, 16)
end
function Play:restart() self.tweens:clear(); self:newGame() end

function Play:add(points, x, y, color)
  local p = points * self.table.mult
  self.score = self.score + p
  if x then self.pop:add("+" .. p, x, y - 10, color or "#FFFFFF", 16, 0.8, 18) end
end

-- events from the table simulation
function Play:event_(kind, x, y, i)
  if self.state ~= "play" and self.state ~= "ready" then return end
  local tb = self.table
  if kind == "bumper" then
    self:add(100, x, y, "#FFD166")
    self.bonus = self.bonus + 10
    self.stats.bumpers = self.stats.bumpers + 1
    self.sparks:emit(10, x, y)
    self.shake:add(1.6, 0.12)
    A.play("bumper"); bumperChord(i)
  elseif kind == "sling" then
    self:add(30, x, y, "#FF8AC8")
    self.sparks:emit(6, x, y)
    self.shake:add(1.2, 0.1)
    A.play("sling")
  elseif kind == "post" then
    self:add(20)
    A.play("thunk", 0.6)
  elseif kind == "target" then
    self:add(250, x, y, "#FFE066")
    self.bonus = self.bonus + 50
    self.sparks:emit(12, x, y)
    self.shake:add(2, 0.15)
    A.play("target")
  elseif kind == "targets" then
    self:add(1000)
    self.stats.targets = self.stats.targets + 1
    self.pop:add(TR("targets_done", tb.mult), TW / 2, 340, "#FFE066", 28, 1.6, 24)
    bigFanfare()
  elseif kind == "lane" then
    self:add(150, x, y, "#7CFFB2")
    self.bonus = self.bonus + 25
    A.play("lane")
  elseif kind == "lanes" then
    self:add(1500)
    self.pop:add(TR("lanes_done", tb.mult), TW / 2, 110, "#7CFFB2", 28, 1.6, 24)
    bigFanfare()
  elseif kind == "flip" then
    A.play("flip")
  elseif kind == "hitflip" then
    A.play("thunk", min(1.2, i / 900))
  elseif kind == "wall" then
    A.play("thunk", min(0.8, i / 1500))
  elseif kind == "launch" then
    self.state = "play"
    A.play("launch")
    self.shake:add(2, 0.2)
  elseif kind == "drain" then
    self:drain()
  end
  if tb.mult > self.stats.bestMult then self.stats.bestMult = tb.mult end
end

function Play:drain()
  local tb = self.table
  if tb.saveT > 0 then
    tb:resetBall()
    tb.saveT = 0
    self.state = "ready"
    self.pop:add(TR("ball_saved"), TW / 2, 300, "#7CFFB2", 28, 1.6, 20)
    fx.chord("G5 B5 D6", 0.3, 0.07, "triangle")
    return
  end
  self.state = "drain"
  A.play("drain")
  self.shake:add(5, 0.4)
  sys.vibrate(0.6, 150)
  -- end-of-ball bonus counts up
  local total = self.bonus * tb.mult
  self.pop:add(TR("bonus", self.bonus, tb.mult), TW / 2, 260, "#FFD166", 25, 2.0, 16)
  self.bonusLeft = total
  self.tweens:every(0.04, function()
    if (self.bonusLeft or 0) > 0 then
      local step = max(10, floor(total / 30))
      local d = min(step, self.bonusLeft)
      self.bonusLeft = self.bonusLeft - d
      self.score = self.score + d
      A.play("tickup")
    end
  end, 40)
  game.tween.after(2.0, function()
    if self.state ~= "drain" then return end
    self.score = self.score + (self.bonusLeft or 0)
    self.bonusLeft = 0
    self.bonus = 0
    tb.mult = 1
    if self.ball >= BALLS then
      self.state = "over"
      local record = self.score > 0 and save:best("high", self.score)
      save:inc("games", 1)
      A.stopSong()
      game.push(Over, {play = self, record = record})
    else
      self.ball = self.ball + 1
      tb:resetBall()
      self.state = "ready"
      self.pop:add(TR("ball_n", self.ball, BALLS), TW / 2, 250, "#FFFFFF", 25, 1.4, 16)
    end
  end)
end

function Play:update(dt)
  local tb = self.table
  local p = I.pointer
  -- touch / mouse: the left or right half of the screen holds a flipper; while the ball waits, it pulls the plunger
  local touchL, touchR, touchLaunch = false, false, false
  if p.down then
    if self.state == "ready" and tb:onPlunger() then touchLaunch = true
    elseif p.x < game.width / 2 then touchL = true else touchR = true end
  end
  local active = self.state == "play" or self.state == "ready"
  local inL = active and (I.down("flipL") or touchL)
  local inR = active and (I.down("flipR") or touchR)
  local inLaunch = self.state == "ready" and (I.down("launch") or touchLaunch)
  if self.state == "drain" or self.state == "over" then
    tb.flippers[1].held, tb.flippers[2].held = false, false
  end
  tb:step(dt, inL, inR, inLaunch)
  local b = tb.ball
  -- the ball fell back into the plunger lane: launch again
  if self.state == "play" and tb:onPlunger() then self.state = "ready" end
  -- a stalled ball gets a nudge
  local sp = sqrt(b.vx * b.vx + b.vy * b.vy)
  if self.state == "play" and sp < 8 and b.y < 420 then
    self.stall = self.stall + dt
    if self.stall > 2.5 then
      self.stall = 0
      b.vx, b.vy = (random() - 0.5) * 300, -220
      self.pop:add(TR("nudge"), b.x, b.y - 12, "#FFFFFF", 16, 1)
    end
  else
    self.stall = 0
  end
  if sp > 300 then self.trail:emit(1, b.x, b.y) end
  self.shown.score = self.shown.score + (self.score - self.shown.score) * min(1, dt * 12)
  self.shake:update(dt)
  self.pop:update(dt)
  self.sparks:update(dt)
  self.trail:update(dt)
end

function Play:draw()
  G.gradient(0, 0, game.width, game.height, "#1A0B33", "#06060F")
  layout()
  G.push(V.x + self.shake.x, V.y + self.shake.y, V.s)
  drawTable(self.table, game.time, self.trail)
  self.sparks:draw()
  self.pop:draw()
  G.pop()
end

function Play:ui()
  local tb = self.table
  local pw = V.x - 16
  local small = pw < 110
  -- left panel: score, high score, balls, multiplier, bonus
  local x, y = 8, 10
  U.text(TR("score"), x, y, 9, "#FFFFFF90", nil, nil, "semibold")
  local sc = tostring(floor(self.shown.score + 0.5))
  local size = min(22, pw / max(1, #sc) * 1.6)
  U.text(sc, x, y + 12, size, "#FFFFFF")
  y = y + 16 + size
  U.text(TR("high_score", max(save:get("high", 0), self.score)), x, y, small and 8 or 10, "#FFE27A", nil, nil, "semibold")
  y = y + 18
  U.text(TR("ball_n", min(self.ball, BALLS), BALLS), x, y, 11, "#FFFFFF")
  for k = 1, BALLS do
    G.circle(x + 6 + (k - 1) * 14, y + 22, 5, k <= BALLS - self.ball + 1 and "#C9D1DE" or "#FFFFFF30")
  end
  y = y + 36
  local mpulse = tb.multFlash > 0 and (1 + 0.3 * fx.ease("outQuad", tb.multFlash / 1.5)) or 1
  U.text(TR("multiplier", tb.mult), x, y, 12 * mpulse, tb.mult > 1 and "#FFB020" or "#FFFFFFB0")
  y = y + 18
  U.text(TR("bonus_now", self.bonus), x, y, 10, "#FFFFFFB0", nil, nil, "semibold")
  if tb.saveT > 0 then U.text(TR("ball_save_on"), x, y + 16, 9, "#7CFFB2", nil, nil, "semibold") end
  -- right panel: controls
  local rx = V.x + TW * V.s + 8
  local rw = game.width - rx - 8 - (I.touchVisible() and 30 or 0)
  if rw > 50 then
    local ry = 10
    local lines = self.hintLines
    if not lines then
      lines = {TR("h_left"), TR("h_right"), TR("h_launch"), TR("h_touch"), TR("h_pause")}
      self.hintLines = lines
    end
    local ts = G.scale()
    for k = 1, #lines do
      local sx, sy = G.toScreen(rx, ry)
      gfx.color("#FFFFFFA0")
      local hp = gfx.wrap(lines[k], sx, sy, rw * ts, 9 * ts, "semibold") or 0
      ry = ry + max(12, hp / max(0.01, ts)) + 5
    end
  end
  if self.state == "ready" then
    local blink = floor(game.realTime * 3) % 2 == 0
    if blink then fx.fitLine(TR("launch_hint"), game.height - 16, 10, "#7CFFB2") end
  end
end

-- game over -------------------------------------------------------------------------------------------
function Over:enter(p)
  self.p = p
  self.anim = {k = 0, score = 0}
  self.tweens:to(self.anim, 0.5, {k = 1}, "outBack")
  self.tweens:to(self.anim, 1.3, {score = p.play.score}, "outCubic")
  self.confetti = fx.confetti(70)
  self.party = p.record and 2.5 or 0
  self.labels = {TR("stat_bumpers"), TR("stat_targets"), TR("stat_mult")}
  self.menu = U.menu{width = 180, items = {
    {label = function() return TR("again") end, action = function() game.switch(Play) end},
    {label = function() return TR("main_menu") end, action = function() game.switch(Title) end},
  }}
  if p.record then
    A.play("win")
    game.tween.after(0.35, function() fx.chord("C5 E5 G5 C6", 0.6, 0.08, "triangle") end)
  else
    fx.chord("A3 C4 E4", 0.6, 0.07, "triangle")
  end
end
function Over:update(dt)
  self.menu:update()
  if self.party > 0 then
    local before = self.party
    self.party = self.party - dt
    if floor(before * 4) ~= floor(self.party * 4) then
      self.confetti:burst(20, game.width * (0.15 + random() * 0.7), game.height, -pi / 2, 1.0)
    end
  end
  self.confetti:update(dt)
end
function Over:ui()
  local p, pl = self.p, self.p.play
  local k = max(0, min(1, self.anim.k))
  G.rect(0, 0, game.width, game.height, 0, "#000000A8")
  local w, h = min(game.width - 16, 300), 196
  local x, y = (game.width - w) / 2, (game.height - h) / 2 + (1 - k) * 40
  G.alpha(k)
  U.panel(x, y, w, h, 12, "#180C30F0")
  U.text(TR("game_over"), x, y + 10, 16, "#FFFFFF", "center", w)
  U.text(tostring(floor(self.anim.score + 0.5)), x, y + 30, 32, "#FFE27A", "center", w)
  if p.record then
    local pulse = 1 + sin(game.realTime * 8) * 0.06
    U.text(TR("new_high"), x, y + 70, 13 * pulse, "#7CFFB2", "center", w)
  else
    U.text(TR("high_score", save:get("high", 0)), x, y + 70, 12, "#FFFFFFB0", "center", w, "semibold")
  end
  local sw = w / 3
  local st = pl.stats
  for i = 1, 3 do
    local v = i == 1 and st.bumpers or (i == 2 and st.targets or (st.bestMult .. "x"))
    U.text(tostring(v), x + (i - 1) * sw, y + 90, 14, "#FFFFFF", "center", sw)
    U.text(self.labels[i], x + (i - 1) * sw, y + 108, 8, "#FFFFFF90", "center", sw, "semibold", false)
  end
  self.menu:draw(game.width / 2, y + 128)
  G.unalpha()
  self.confetti:draw()
end

-- ---------------------------------------------------------------- run
return game.run{
  width = 480, height = 270, scale = "expand",
  scene = Title, title = Title,
  background = "#06060F",
  menu = function()
    return {{title = TR("game_menu"), items = {
      {label = TR("pause_menu"), id = 1, shortcut = "Esc"},
      {label = TR("new_game"), id = 2},
      {label = TR("main_menu"), id = 3},
      "-",
      {label = TR("reset_high"), id = 4},
    }}}
  end,
  onmenu = function(id)
    if id == 1 then game.pause()
    elseif id == 2 then game.switch(Play)
    elseif id == 3 then game.switch(Title)
    elseif id == 4 then save:reset(); U.toast(TR("high_reset"))
    end
  end,
}
