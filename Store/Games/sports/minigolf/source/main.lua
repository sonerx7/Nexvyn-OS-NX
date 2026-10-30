-- Mini Golf: nine hand-made top-down holes with walls, angled banks, posts, sand, water and a windmill bar.
-- Built on the nexvyn.game engine (romfs:/System/Lua/nexvyn/game). All art is drawn with shapes.
--
-- Aim: drag back from anywhere and release (touch/mouse, like a slingshot), or turn with the stick/D-pad/arrows and
-- hold A/Space to charge the power meter, release to putt. Water costs a penalty stroke and puts the ball back.

local game = require("nexvyn.game")
local fx = require("fx")

local G, I, U, A = game.gfx, game.input, game.ui, game.audio
local floor, ceil, sqrt, min, max, abs = math.floor, math.ceil, math.sqrt, math.min, math.max, math.abs
local cos, sin, atan, pi, random = math.cos, math.sin, math.atan, math.pi, math.random

local save = game.save.open("golf")
local CW, CH = 400, 240            -- course size in course units
local BALL_R, CUP_R = 4, 6.5
local WALL_R = 2.5                  -- half the wall thickness
local MAX_SPEED = 390               -- full-power putt, course units per second
local MAX_STROKES = 10              -- the ball is picked up after this many

-- ---------------------------------------------------------------- input
I.bind("shoot", {pad = {"a", "zr", "r"}, key = {"space", "enter"}})
I.bind("cancel", {pad = {"b", "x"}, key = {"backspace", "c"}})
I.touchControls{stick = false, pause = true}

-- ---------------------------------------------------------------- sounds (layered: several notes per effect)
A.define("putt", {wave = "triangle", volume = 0.32, notes = {{196, 0.03}, {147, 0.06}}})
A.define("tap", {wave = "square", volume = 0.07, notes = {{620, 0.025}}})
A.define("thud", {wave = "triangle", volume = 0.22, notes = {{140, 0.05}, {90, 0.06}}})
A.define("splash", {wave = "noise", volume = 0.26, notes = {{300, 0.12}, {120, 0.22}}})
A.define("sand", {wave = "noise", volume = 0.09, notes = {{90, 0.1}}})
A.define("rattle", {wave = "square", volume = 0.08, notes = {{880, 0.03}, {660, 0.03}, {990, 0.04}}})
A.define("charge", {wave = "sine", volume = 0.05, notes = {{440, 0.02}}})

local function cupJingle(good)
  if good then
    fx.chord("C5 E5 G5", 0.18, 0.09, "triangle")
    A.tone("C6", 0.32, 0.12, "triangle")
    game.tween.after(0.16, function() fx.chord("E5 G5 C6", 0.35, 0.08, "triangle") end)
  else
    fx.chord("G4 B4 D5", 0.25, 0.09, "triangle")
  end
end

-- ---------------------------------------------------------------- course data
local function R(x, y, w, h) return {x, y, x + w, y, x + w, y + h, x, y + h} end

-- floor: convex polygons (the green), walls: closed outlines, blocks: solid convex obstacles,
-- posts: {x, y, r}, water/sand: {"r", x, y, w, h} or {"c", x, y, r}, spin: windmill bar {x, y, halfLength, speed}
local HOLES = {
  { par = 2, tee = {70, 120}, cup = {330, 120},
    floor = {R(40, 80, 320, 80)},
    walls = {{40, 80, 360, 80, 360, 160, 40, 160}},
    blocks = {{40, 80, 62, 80, 40, 102}, {360, 138, 360, 160, 338, 160}} },
  { par = 3, tee = {72, 75}, cup = {320, 172},
    floor = {R(40, 40, 320, 70), R(280, 110, 80, 90)},
    walls = {{40, 40, 360, 40, 360, 200, 280, 200, 280, 110, 40, 110}},
    blocks = {{318, 40, 360, 40, 360, 82}},
    posts = {{200, 75, 7}} },
  { par = 3, tee = {72, 150}, cup = {320, 150},
    floor = {R(40, 60, 320, 120)},
    walls = {{40, 60, 360, 60, 360, 180, 40, 180}},
    blocks = {R(246, 110, 8, 70)},
    sand = {{"r", 160, 60, 62, 70}} },
  { par = 3, tee = {72, 90}, cup = {322, 92},
    floor = {R(40, 50, 320, 140)},
    walls = {{40, 50, 360, 50, 360, 190, 40, 190}},
    water = {{"r", 165, 50, 70, 92}, {"c", 300, 160, 17}},
    blocks = {{40, 168, 40, 190, 62, 190}} },
  { par = 3, tee = {68, 120}, cup = {332, 120},
    floor = {{40, 120, 120, 40, 280, 40, 360, 120, 280, 200, 120, 200}},
    walls = {{40, 120, 120, 40, 280, 40, 360, 120, 280, 200, 120, 200}},
    blocks = {R(194, 82, 12, 76)},
    posts = {{140, 120, 7}, {262, 78, 7}, {262, 162, 7}} },
  { par = 4, tee = {330, 58}, cup = {78, 182},
    floor = {R(40, 30, 320, 180)},
    walls = {{40, 30, 360, 30, 360, 210, 40, 210}},
    blocks = {R(110, 86, 250, 8), R(40, 146, 250, 8), {40, 30, 72, 30, 40, 62}, {330, 94, 360, 94, 360, 124},
              {360, 180, 360, 210, 330, 210}},
    sand = {{"r", 160, 154, 40, 56}} },
  { par = 3, tee = {70, 120}, cup = {332, 120},
    floor = {R(40, 60, 320, 120)},
    walls = {{40, 60, 360, 60, 360, 180, 40, 180}},
    blocks = {R(196, 60, 8, 40), R(196, 140, 8, 40)},
    posts = {{290, 90, 6}, {290, 150, 6}},
    spin = {200, 120, 19, 2.3} },
  { par = 3, tee = {60, 120}, cup = {340, 120},
    floor = {R(30, 30, 340, 180)},
    walls = {{30, 30, 370, 30, 370, 210, 30, 210}},
    water = {{"c", 200, 120, 58}},
    sand = {{"c", 306, 70, 24}},
    posts = {{120, 62, 7}, {120, 178, 7}} },
  { par = 4, tee = {70, 65}, cup = {72, 175},
    floor = {R(40, 30, 320, 70), R(290, 100, 70, 40), R(40, 140, 320, 70)},
    walls = {{40, 30, 360, 30, 360, 210, 40, 210, 40, 140, 290, 140, 290, 100, 40, 100}},
    blocks = {{330, 30, 360, 30, 360, 60}, {360, 180, 360, 210, 330, 210}},
    water = {{"c", 190, 176, 15}},
    sand = {{"r", 150, 30, 44, 30}},
    posts = {{325, 120, 6}} },
}
local NH = #HOLES
local TOTAL_PAR = 0
for _, h in ipairs(HOLES) do TOTAL_PAR = TOTAL_PAR + h.par end

-- collision segments {x1, y1, x2, y2, radius} built once per hole
for _, h in ipairs(HOLES) do
  local segs = {}
  local function addLoop(pts, rad)
    local n = #pts
    for i = 1, n - 1, 2 do
      local j = i + 2
      if j > n then j = 1 end
      segs[#segs + 1] = {pts[i], pts[i + 1], pts[j], pts[j + 1], rad}
    end
  end
  for _, w in ipairs(h.walls) do addLoop(w, BALL_R + WALL_R) end
  for _, b in ipairs(h.blocks or {}) do addLoop(b, BALL_R + 0.8) end
  h.segs = segs
  h.posts, h.water, h.sand, h.blocks = h.posts or {}, h.water or {}, h.sand or {}, h.blocks or {}
end

-- ---------------------------------------------------------------- physics helpers
-- Circle (the ball) against a segment. Pushes the ball out, reflects the velocity relative to the surface (which
-- may rotate around px, py with angular speed w). Returns the impact speed (0 = no hit).
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
  if d2 >= rad * rad then return 0 end
  local d = sqrt(d2)
  local nx, ny = 0, -1
  if d > 1e-6 then nx, ny = dx / d, dy / d end
  b.x, b.y = cx + nx * rad, cy + ny * rad
  local vn = b.vx * nx + b.vy * ny
  if vn >= 0 then return 0 end
  b.vx, b.vy = b.vx - (1 + e) * vn * nx, b.vy - (1 + e) * vn * ny
  return -vn
end

local function inZones(list, x, y)
  for i = 1, #list do
    local z = list[i]
    if z[1] == "r" then
      if x >= z[2] and y >= z[3] and x <= z[2] + z[4] and y <= z[3] + z[5] then return true end
    else
      local dx, dy = x - z[2], y - z[3]
      if dx * dx + dy * dy <= z[4] * z[4] then return true end
    end
  end
  return false
end

-- the windmill bar's end points
local function spinEnds(sp, a)
  local c, s = cos(a) * sp[3], sin(a) * sp[3]
  return sp[1] - c, sp[2] - s, sp[1] + c, sp[2] + s
end

-- ---------------------------------------------------------------- drawing the course
local function drawZone(z, c)
  if z[1] == "r" then G.rect(z[2], z[3], z[4], z[5], 4, c) else G.circle(z[2], z[3], z[4], c) end
end

local function drawCourse(h, spinA, t)
  -- shadow and fringe under the green
  for _, f in ipairs(h.floor) do G.poly(f, "#2E6B36") end
  G.push(0, -2)
  for _, f in ipairs(h.floor) do G.poly(f, "#43A04F") end
  G.pop()
  -- mowing stripes
  G.color(255, 255, 255, 14)
  for x = 50, CW - 20, 40 do
    for _, f in ipairs(h.floor) do
      if #f == 8 and f[2] == f[4] and x >= f[1] and x + 20 <= f[3] then G.rect(x, f[2], 20, f[6] - f[2]) end
    end
  end
  for _, z in ipairs(h.sand) do
    drawZone(z, "#C9AE66")
    G.push(0, -1)
    drawZone(z, "#E8D290")
    G.pop()
  end
  for _, z in ipairs(h.water) do
    drawZone(z, "#1F6FB5")
    G.push(0, -1)
    drawZone(z, "#3196E0")
    G.pop()
    -- ripples
    G.color(255, 255, 255, 60)
    local k = (t * 0.6) % 1
    if z[1] == "c" then
      G.circleLine(z[2], z[3], z[4] * (0.3 + 0.6 * k), 1)
    else
      local cx, cy = z[2] + z[4] / 2, z[3] + z[5] / 2
      G.circleLine(cx, cy, min(z[4], z[5]) * 0.45 * k + 2, 1)
    end
  end
  -- tee and cup
  G.rect(h.tee[1] - 7, h.tee[2] - 7, 14, 14, 3, "#FFFFFF22")
  G.circle(h.cup[1], h.cup[2], CUP_R + 2, "#2F7A38")
  G.circle(h.cup[1], h.cup[2], CUP_R, "#0E2412")
  -- walls (shadow, wood, highlight)
  for _, w in ipairs(h.walls) do
    G.push(1.5, 2)
    G.color(0, 0, 0, 70)
    G.lines(w, 6, true)
    G.pop()
    G.color("#6B4226")
    G.lines(w, 5, true)
    G.color("#B07D4A")
    G.lines(w, 1.6, true)
  end
  for _, b in ipairs(h.blocks) do
    G.push(1.5, 2)
    G.poly(b, "#00000046")
    G.pop()
    G.poly(b, "#7A4E2D")
    G.color("#B07D4A")
    G.lines(b, 1.4, true)
  end
  for _, p in ipairs(h.posts) do
    G.circle(p[1] + 1.5, p[2] + 2, p[3], "#00000046")
    G.circle(p[1], p[2], p[3], "#8D5A33")
    G.circle(p[1] - p[3] * 0.25, p[2] - p[3] * 0.25, p[3] * 0.45, "#C99A62")
  end
  if h.spin then
    local x1, y1, x2, y2 = spinEnds(h.spin, spinA)
    G.color(0, 0, 0, 70)
    G.line(x1 + 1.5, y1 + 2, x2 + 1.5, y2 + 2, 5)
    G.color("#D84343")
    G.line(x1, y1, x2, y2, 5)
    G.color("#FFFFFF")
    G.line(x1 + (x2 - x1) * 0.4, y1 + (y2 - y1) * 0.4, x1 + (x2 - x1) * 0.6, y1 + (y2 - y1) * 0.6, 5)
    G.circle(h.spin[1], h.spin[2], 4, "#F3E2C0")
  end
end

-- flag on a pole; waves with time, dips when `lift` > 0 (pulled while the ball drops)
local FLAG = {0, 0, 0, 0, 0, 0}
local function drawFlag(h, t, lift)
  local x, y = h.cup[1], h.cup[2] - (lift or 0) * 10
  G.color(0, 0, 0, 60)
  G.line(x + 2, y + 1, x + 10, y - 6, 1.6)
  G.color("#EDEDED")
  G.line(x, y, x, y - 26, 1.6)
  local wv = sin(t * 5) * 2
  FLAG[1], FLAG[2], FLAG[3], FLAG[4], FLAG[5], FLAG[6] = x, y - 26, x + 15, y - 22 + wv, x, y - 17
  G.poly(FLAG, "#FF4D4D")
end

local function courseView()
  local top, bottom = 24, 18
  local W, H = game.width, game.height
  local s = min((W - 16) / CW, (H - top - bottom) / CH)
  return (W - CW * s) / 2, top + (H - top - bottom - CH * s) / 2, s
end

local function relText(n)
  if n > 0 then return "+" .. n elseif n == 0 then return "E" end
  return tostring(n)
end

local function resultText(strokes, par)
  if strokes == 1 then return TR("r_ace") end
  local d = strokes - par
  if d <= -3 then return TR("r_albatross")
  elseif d == -2 then return TR("r_eagle")
  elseif d == -1 then return TR("r_birdie")
  elseif d == 0 then return TR("r_par")
  elseif d == 1 then return TR("r_bogey")
  elseif d == 2 then return TR("r_double") end
  return TR("r_over", d)
end

-- ---------------------------------------------------------------- scenes
local Title, Play, Card = {pausable = false}, {controls = true}, {transparent = true, pausable = false}

-- title ----------------------------------------------------------------------------------------------
function Title:enter()
  self.t, self.show, self.fade = 0, 1, 1
  self.logo = {y = -50, a = 0}
  self.tweens:to(self.logo, 0.9, {y = 0, a = 1}, "outBack")
  self.menu = U.menu{width = 190, items = {
    {label = function() return TR("play") end, action = function() game.switch(Play) end},
    fx.soundItem(),
    {label = function() return TR("quit") end, action = function() sys.exit() end},
  }}
  self.ball = {u = 0}
end
function Title:update(dt)
  self.t = self.t + dt
  self.menu:update()
  -- a new hole slides in every few seconds
  local cycle = self.t % 4
  self.fade = cycle < 0.4 and cycle / 0.4 or (cycle > 3.6 and (4 - cycle) / 0.4 or 1)
  self.show = floor(self.t / 4) % NH + 1
end
function Title:draw()
  G.gradient(0, 0, game.width, game.height, "#163F24", "#0B2414")
  local h = HOLES[self.show]
  local ox, oy, s = courseView()
  G.alpha(0.55 * self.fade)
  G.push(ox, oy, s)
  drawCourse(h, self.t * 2.3, self.t)
  drawFlag(h, self.t, 0)
  G.pop()
  G.unalpha()
  G.rect(0, 0, game.width, game.height, 0, "#00000059")
end
function Title:ui()
  local y = game.height * 0.1 + self.logo.y
  G.alpha(max(0, min(1, self.logo.a)))
  U.text(TR("logo"), 0, y, 30, "#FFFFFF", "center", game.width, "bold", "#0B3D1C")
  G.unalpha()
  -- a ball rolling across under the logo and dropping into a little cup
  local cx = game.width / 2
  local k = (self.t % 3) / 3
  local bx = cx - 70 + 140 * fx.ease("outCubic", min(1, k * 1.4))
  local drop = k > 0.72 and min(1, (k - 0.72) / 0.12) or 0
  G.circle(cx + 70, y + 48, 6, "#0E2412")
  if drop < 1 then G.circle(bx, y + 48, 4 * (1 - drop * 0.6), "#FFFFFF") end
  local best = save:get("best", nil)
  local line = best and TR("best_round", best, relText(best - TOTAL_PAR)) or TR("no_best")
  U.text(line, 0, y + 60, 12, "#FFE27A", "center", game.width)
  self.menu:draw(game.width / 2, y + 84)
  fx.fitLine(TR("controls"), game.height - 16, 9)
end

-- play -----------------------------------------------------------------------------------------------
function Play:enter()
  self.pop = fx.popups(8)
  self.shake = fx.shake()
  self.splashFx = game.emitter{max = 80, life = {0.3, 0.8}, speed = {40, 140}, gravity = 0, damping = 3,
                               size = {4, 0}, colors = {"#FFFFFF", "#9FD8FFAA", "#3196E000"}}
  self.puff = game.emitter{max = 60, life = {0.3, 0.6}, speed = {15, 50}, damping = 3, size = {4, 1},
                           colors = {"#F2E2A8C0", "#E8D29000"}}
  self.sparks = game.emitter{max = 80, life = {0.4, 0.9}, speed = {40, 160}, damping = 2.5, size = {3, 0},
                             shape = "square", colors = {"#FFFFFF", "#FFE066", "#FF9F4300"}}
  self.trail = game.emitter{max = 60, life = {0.15, 0.35}, speed = {0, 6}, size = {3, 0},
                            colors = {"#FFFFFF80", "#FFFFFF00"}}
  self:newRound()
end

function Play:newRound()
  self.scores = {}
  self:loadHole(1)
end
function Play:restart() self:newRound() end

function Play:loadHole(i)
  if i > NH then i = NH end
  local h = HOLES[i]
  self.hole, self.h = i, h
  self.ball = {x = h.tee[1], y = h.tee[2], vx = 0, vy = 0, scale = 1}
  self.lastX, self.lastY = h.tee[1], h.tee[2]
  self.strokes = 0
  self.state = "aim"
  self.aim = atan(h.cup[2] - h.tee[2], h.cup[1] - h.tee[1])
  self.power, self.charging, self.chargeDir, self.dragging = 0, false, 1, false
  self.spinA, self.timer, self.tapCool, self.inSand, self.lift = 0, 0, 0, false, 0
  self.intro = {k = 0}
  self.tweens:to(self.intro, 0.6, {k = 1}, "outBack")
  self.pop:clear()
  self.splashFx:clear(); self.puff:clear(); self.sparks:clear(); self.trail:clear()
  local cx = CW / 2
  self.pop:add(TR("hole_n", i), cx, CH / 2 - 6, "#FFFFFF", 22, 1.5, 18)
  self.pop:add(TR("par_n", h.par), cx, CH / 2 + 18, "#FFE27A", 13, 1.5, 18)
  A.play("confirm")
end

function Play:resume(result)
  if result == "next" then self:loadHole(self.hole + 1) end
end

function Play:totals()
  local strokes, par = 0, 0
  for i = 1, NH do
    if self.scores[i] then strokes, par = strokes + self.scores[i], par + HOLES[i].par end
  end
  return strokes, par
end

function Play:shoot()
  local b = self.ball
  local p = min(1, max(0, self.power))
  local sp = MAX_SPEED * p
  b.vx, b.vy = cos(self.aim) * sp, sin(self.aim) * sp
  self.strokes = self.strokes + 1
  self.lastX, self.lastY = b.x, b.y
  self.state = "roll"
  self.power, self.charging, self.dragging = 0, false, false
  self.shake:add(0.8 + p * 2, 0.15)
  self.puff:emit(6, b.x, b.y)
  A.play("putt", 0.6 + p * 0.6)
end

-- water: penalty stroke, the ball goes back to where it was hit from
function Play:splash()
  local b = self.ball
  self.state, self.timer = "splash", 0.9
  self.strokes = self.strokes + 1
  self.splashFx:emit(36, b.x, b.y)
  self.shake:add(3, 0.3)
  self.pop:add(TR("penalty"), b.x, b.y - 8, "#9FD8FF", 12, 1.3)
  b.vx, b.vy = 0, 0
  A.play("splash")
  sys.vibrate(0.4, 90)
end

function Play:sink()
  local b = self.ball
  local h = self.h
  self.state, self.timer = "sunk", 0.55
  b.x, b.y, b.vx, b.vy = h.cup[1], h.cup[2], 0, 0
  self.tweens:to(b, 0.45, {scale = 0}, "inBack")
  self.tweens:to(self, 0.25, {lift = 1}, "outQuad"):after(self, 0.3, {lift = 0}, "outBounce")
  local good = self.strokes <= h.par
  self.sparks:emit(good and 40 or 18, h.cup[1], h.cup[2])
  self.shake:add(good and 4 or 2, 0.35)
  self.pop:add(resultText(self.strokes, h.par), h.cup[1], h.cup[2] - 30, good and "#7CFFB2" or "#FFFFFF",
               self.strokes == 1 and 22 or 17, 1.6, 30)
  A.play("rattle")
  cupJingle(good)
  sys.vibrate(0.5, 120)
end

function Play:finishHole()
  if self.state == "done" then return end
  self.state = "done"
  local i = self.hole
  self.scores[i] = min(self.strokes, MAX_STROKES)
  save:best("h" .. i, self.scores[i], true)
  local p = {play = self, hole = i, strokes = self.scores[i], par = self.h.par, final = i >= NH}
  if p.final then
    local total = self:totals()
    p.total = total
    p.record = save:best("best", total, true)
    save:inc("rounds", 1)
  end
  game.tween.after(0.25, function() game.push(Card, p) end)
end

function Play:updateAim(dt)
  local p = I.pointer
  local b = self.ball
  -- the windmill can knock a resting ball
  if self.h.spin and self:spinHit(b) > 0 then self.state = "roll" return end
  if not self.dragging then
    local lx, ly = I.sticks()
    if lx * lx + ly * ly > 0.36 then
      -- the stick points where the ball goes
      local target = atan(ly, lx)
      local d = (target - self.aim + pi) % (2 * pi) - pi
      self.aim = self.aim + d * min(1, dt * 10)
    else
      local turn = 0
      if I.down("left") then turn = turn - 1.7 end
      if I.down("right") then turn = turn + 1.7 end
      if I.down("up") then turn = turn - 0.3 end
      if I.down("down") then turn = turn + 0.3 end
      self.aim = self.aim + turn * dt
    end
    -- hold to charge, release to putt
    if I.pressed("shoot") then self.charging, self.power, self.chargeDir = true, 0, 1 end
    if self.charging then
      if I.pressed("cancel") then
        self.charging, self.power = false, 0
      elseif I.down("shoot") then
        local before = self.power
        self.power = self.power + self.chargeDir * dt * 0.8
        if self.power >= 1 then self.power, self.chargeDir = 1, -1 elseif self.power <= 0 then self.power, self.chargeDir = 0, 1 end
        if floor(before * 10) ~= floor(self.power * 10) then A.play("charge", 0.5 + self.power) end
      else
        self.charging = false
        if self.power > 0.03 then self:shoot() else self.power = 0 end
        return
      end
    end
  end
  -- slingshot drag with touch or the mouse (from anywhere)
  if not self.charging then
    if p.pressed then self.dragging = true end
    if self.dragging then
      local _, _, s = courseView()
      local dx, dy = (p.downX - p.x) / s, (p.downY - p.y) / s
      local len = sqrt(dx * dx + dy * dy)
      if len > 3 then self.aim = atan(dy, dx) end
      self.power = min(1, len / 110)
      if p.released or not p.down then
        self.dragging = false
        if p.released and self.power > 0.05 then self:shoot() else self.power = 0 end
      end
    end
  end
end

function Play:spinHit(b)
  local sp = self.h.spin
  local x1, y1, x2, y2 = spinEnds(sp, self.spinA)
  return segHit(b, x1, y1, x2, y2, BALL_R + 2.5, 0.7, sp[1], sp[2], sp[4])
end

function Play:collide(b)
  local h = self.h
  local best = 0
  local segs = h.segs
  for i = 1, #segs do
    local s = segs[i]
    local imp = segHit(b, s[1], s[2], s[3], s[4], s[5], 0.72)
    if imp > best then best = imp end
  end
  local posts = h.posts
  for i = 1, #posts do
    local p = posts[i]
    local imp = circleHit(b, p[1], p[2], p[3] + BALL_R, 0.8)
    if imp > best then best = imp end
  end
  if h.spin then
    local imp = self:spinHit(b)
    if imp > best then best = imp end
  end
  return best
end

function Play:updateRoll(dt)
  local b, h = self.ball, self.h
  local speed = sqrt(b.vx * b.vx + b.vy * b.vy)
  local n = min(40, max(1, ceil(speed * dt / 1.5)))
  local sdt = dt / n
  local hit = 0
  for _ = 1, n do
    b.x, b.y = b.x + b.vx * sdt, b.y + b.vy * sdt
    local imp = self:collide(b)
    if imp > hit then hit = imp end
    if inZones(h.water, b.x, b.y) then self:splash() return end
    local dx, dy = h.cup[1] - b.x, h.cup[2] - b.y
    if dx * dx + dy * dy < (CUP_R - 1.5) ^ 2 and speed < 250 then self:sink() return end
  end
  if b.x < -20 or b.y < -20 or b.x > CW + 20 or b.y > CH + 20 then self:splash() return end
  -- impact feedback
  self.tapCool = self.tapCool - dt
  if hit > 25 and self.tapCool <= 0 then
    self.tapCool = 0.06
    A.play(hit > 160 and "thud" or "tap", min(1.2, 0.4 + hit / 200))
    if hit > 160 then self.shake:add(min(4, hit / 80), 0.2) end
    self.sparks:emit(hit > 160 and 6 or 2, b.x, b.y)
  end
  -- rolling resistance: sand is much slower
  local sand = inZones(h.sand, b.x, b.y)
  if sand and not self.inSand then A.play("sand"); self.puff:emit(10, b.x, b.y) end
  self.inSand = sand
  speed = sqrt(b.vx * b.vx + b.vy * b.vy)
  local decel = sand and (230 + 3.2 * speed) or (40 + 0.62 * speed)
  -- the cup's slope pulls slow balls in
  local dx, dy = h.cup[1] - b.x, h.cup[2] - b.y
  local d = sqrt(dx * dx + dy * dy)
  if d < 13 and d > 0.01 and speed < 150 then
    b.vx, b.vy = b.vx + dx / d * 260 * dt, b.vy + dy / d * 260 * dt
  end
  local ns = speed - decel * dt
  if ns <= 0 or speed < 1e-6 then
    b.vx, b.vy = 0, 0
    if self.strokes >= MAX_STROKES then
      self.pop:add(TR("picked_up"), b.x, b.y - 10, "#FFB86B", 12, 1.4)
      self:finishHole()
    else
      self.state = "aim"
    end
  else
    local k = ns / speed
    b.vx, b.vy = b.vx * k, b.vy * k
    if speed > 60 and random() < 0.6 then self.trail:emit(1, b.x, b.y) end
    if sand and speed > 20 and random() < 0.3 then self.puff:emit(1, b.x, b.y) end
  end
end

function Play:update(dt)
  local h = self.h
  if h.spin then self.spinA = (self.spinA + h.spin[4] * dt) % (2 * pi) end
  local st = self.state
  if st == "aim" then
    self:updateAim(dt)
  elseif st == "roll" then
    self:updateRoll(dt)
  elseif st == "splash" then
    self.timer = self.timer - dt
    if self.timer <= 0 then
      if self.strokes >= MAX_STROKES then
        self:finishHole()
      else
        local b = self.ball
        b.x, b.y, b.vx, b.vy, b.scale = self.lastX, self.lastY, 0, 0, 0
        self.tweens:to(b, 0.35, {scale = 1}, "outBack")
        self.state = "aim"
      end
    end
  elseif st == "sunk" then
    self.timer = self.timer - dt
    if self.timer <= 0 then self:finishHole() end
  end
  self.shake:update(dt)
  self.pop:update(dt)
  self.splashFx:update(dt); self.puff:update(dt); self.sparks:update(dt); self.trail:update(dt)
end

function Play:draw()
  G.gradient(0, 0, game.width, game.height, "#1A4A2A", "#0F2E1A")
  local ox, oy, s = courseView()
  local h, b = self.h, self.ball
  G.push(ox + self.shake.x, oy + self.shake.y, s)
  drawCourse(h, self.spinA, game.time)
  self.trail:draw()
  self.puff:draw()
  -- aim guide: dotted line, longer with more power
  if self.state == "aim" then
    local len = 22 + self.power * 90
    local c, sn = cos(self.aim), sin(self.aim)
    local col = self.power > 0.75 and "#FF6B6B" or (self.power > 0.4 and "#FFD166" or "#FFFFFF")
    for d = 9, len, 7 do
      G.circle(b.x + c * d, b.y + sn * d, 1.4 + (1 - d / (len + 1)) * 0.8, col)
    end
    local ex, ey = b.x + c * (len + 4), b.y + sn * (len + 4)
    G.circle(ex, ey, 2.6, col)
  end
  -- ball with shadow
  if self.state ~= "splash" or self.timer > 0.85 then
    local r = BALL_R * b.scale
    if r > 0.2 then
      G.circle(b.x + 1.2, b.y + 1.6, r, "#00000055")
      G.circle(b.x, b.y, r, "#FFFFFF")
      G.circle(b.x - r * 0.3, b.y - r * 0.3, r * 0.35, "#E8F0FF")
    end
  end
  drawFlag(h, game.time, self.lift)
  self.splashFx:draw()
  self.sparks:draw()
  self.pop:draw()
  G.pop()
  -- power meter next to the course bottom
  if self.charging or self.dragging then
    local w = min(160, game.width * 0.4)
    local x, y = (game.width - w) / 2, oy + CH * s - 14
    U.panel(x - 6, y - 5, w + 12, 16, 8, "#000000A0")
    local col = self.power > 0.75 and "#FF6B6B" or (self.power > 0.4 and "#FFD166" or "#7CFFB2")
    U.bar(x, y, w, 6, self.power, col)
  end
end

function Play:ui()
  local m, W = 8, game.width
  local tot, par = self:totals()
  U.panel(0, 0, W, 20, 0, "#00000070")
  U.text(TR("hole_of", self.hole, NH), m, 4, 11, "#FFFFFF")
  U.text(TR("par_n", self.h.par), 0, 4, 11, "#FFE27A", "center", W)
  local right = W - m - (I.touchVisible() and 34 or 0)
  local rs = TR("strokes_n", self.strokes) .. "   " .. TR("total_n", relText(tot - par))
  U.text(rs, right - 300, 4, 11, "#FFFFFF", "right", 300)
  fx.fitLine(TR("hint"), game.height - 14, 9, "#FFFFFFB0")
end

-- scorecard ------------------------------------------------------------------------------------------
local ROWS = {"row_hole", "row_par", "row_you", "row_best"}

function Card:enter(p)
  self.p = p
  self.anim = {k = 0}
  self.tweens:to(self.anim, 0.5, {k = 1}, "outBack")
  self.confetti = fx.confetti(60)
  self.party = 0
  local items
  if p.final then
    items = {
      {label = function() return TR("again") end, action = function() game.switch(Play) end},
      {label = function() return TR("main_menu") end, action = function() game.switch(Title) end},
    }
  else
    items = {{label = function() return TR("next_hole") end, action = function() game.pop("next") end}}
  end
  self.menu = U.menu{width = 170, items = items}
  if p.record then
    self.party = 2.2
    fx.chord("C5 E5 G5 C6", 0.5, 0.08, "triangle")
    A.play("win")
    game.tween.after(0.4, function() fx.chord("D5 F5 A5 D6", 0.6, 0.08, "triangle") end)
  elseif p.strokes and p.par and p.strokes < p.par then
    self.party = 0.6
  end
end

function Card:update(dt)
  self.menu:update()
  if self.party > 0 then
    local before = self.party
    self.party = self.party - dt
    if floor(before * 4) ~= floor(self.party * 4) then
      self.confetti:burst(18, game.width * (0.2 + random() * 0.6), game.height * 0.95, -pi / 2, 1.2)
    end
  end
  self.confetti:update(dt)
end

function Card:ui()
  local p, play = self.p, self.p.play
  local k = self.anim.k
  G.rect(0, 0, game.width, game.height, 0, "#000000A0")
  local W = min(game.width - 16, 420)
  local H = p.final and 220 or 200
  local x = (game.width - W) / 2
  local y = (game.height - H) / 2 + (1 - k) * 40
  G.alpha(max(0, min(1, k)))
  U.panel(x, y, W, H, 12, "#10261AEE")
  -- header
  if p.final then
    U.text(TR("round_done"), x, y + 10, 18, "#FFFFFF", "center", W)
    local rel = relText(p.total - TOTAL_PAR)
    U.text(TR("round_total", p.total, rel), x, y + 34, 13, "#FFE27A", "center", W)
  else
    U.text(resultText(p.strokes, p.par), x, y + 10, 20, p.strokes <= p.par and "#7CFFB2" or "#FFFFFF", "center", W)
    U.text(TR("hole_result", p.hole, p.strokes), x, y + 36, 12, "#FFFFFFC0", "center", W, "semibold")
  end
  -- scorecard table
  local tx, ty = x + 10, y + 58
  local labelW, totW = 52, 40
  local cw = (W - 20 - labelW - totW) / NH
  local rowH = 18
  U.panel(tx, ty, W - 20, rowH * 4, 6, "#FFFFFF14")
  for r = 1, 4 do
    local ry = ty + (r - 1) * rowH
    if r > 1 then G.rect(tx, ry, W - 20, 1, 0, "#FFFFFF20") end
    U.text(TR(ROWS[r]), tx + 6, ry + 3, 10, "#FFFFFFB0", nil, nil, "semibold", false)
    local sum, any = 0, false
    for i = 1, NH do
      local cx = tx + labelW + (i - 1) * cw
      local v, col = nil, "#FFFFFF"
      if r == 1 then
        v, col = i, (i == p.hole and not p.final) and "#FFE27A" or "#FFFFFF90"
      elseif r == 2 then
        v = HOLES[i].par
      elseif r == 3 then
        v = play.scores[i]
        if v then
          local d = v - HOLES[i].par
          col = d < 0 and "#7CFFB2" or (d == 0 and "#FFFFFF" or (d == 1 and "#FFD166" or "#FF8A8A"))
          if i == p.hole and not p.final then G.rect(cx + 1, ry + 1, cw - 2, rowH - 2, 4, "#FFFFFF22") end
        end
      else
        v, col = save:get("h" .. i, nil), "#9FD8FF"
      end
      if v and r > 1 then sum, any = sum + v, true end
      U.text(v and tostring(v) or "-", cx, ry + 3, 10, col, "center", cw, "semibold", false)
    end
    local tv = r == 1 and TR("col_total") or (any and tostring(sum) or "-")
    U.text(tv, tx + labelW + NH * cw, ry + 3, 10, "#FFFFFF", "center", totW, "bold", false)
  end
  -- footer
  local fy = ty + rowH * 4 + 8
  if p.final then
    if p.record then
      local pulse = 1 + sin(game.realTime * 8) * 0.06
      U.text(TR("new_best"), x, fy, 14 * pulse, "#7CFFB2", "center", W)
    else
      U.text(TR("best_round", save:get("best", p.total), relText(save:get("best", p.total) - TOTAL_PAR)), x, fy, 12,
             "#FFE27A", "center", W)
    end
    fy = fy + 22
  else
    local tot, par = play:totals()
    U.text(TR("so_far", relText(tot - par)), x, fy, 12, "#FFE27A", "center", W)
    fy = fy + 22
  end
  self.menu:draw(game.width / 2, fy)
  G.unalpha()
  self.confetti:draw()
end

-- ---------------------------------------------------------------- run
return game.run{
  width = 480, height = 270, scale = "expand",
  scene = Title, title = Title,
  background = "#0F2E1A",
  menu = function()
    return {{title = TR("game_menu"), items = {
      {label = TR("pause_menu"), id = 1, shortcut = "Esc"},
      {label = TR("new_round"), id = 2},
      {label = TR("main_menu"), id = 3},
      "-",
      {label = TR("reset_best"), id = 4},
    }}}
  end,
  onmenu = function(id)
    if id == 1 then game.pause()
    elseif id == 2 then game.switch(Play)
    elseif id == 3 then game.switch(Title)
    elseif id == 4 then save:reset(); U.toast(TR("best_reset"))
    end
  end,
}
