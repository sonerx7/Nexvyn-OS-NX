-- Uzay Arenası: a top-down arena shooter built with the nexvyn.game engine (romfs:/System/Lua/nexvyn/game).
-- Waves of enemies, particles, power-ups, score multiplier and a saved high score. All art is drawn with shapes.

local game = require("nexvyn.game")

local G, I, U, A = game.gfx, game.input, game.ui, game.audio
local floor, sin, cos, sqrt, abs, min, max, random, pi = math.floor, math.sin, math.cos, math.sqrt, math.abs, math.min,
  math.max, math.random, math.pi
local atan = math.atan

local save = game.save.open("arena")
local ARENA_W, ARENA_H = 1100, 700

-- ---------------------------------------------------------------- input
I.bind("fire", {pad = {"zr", "r", "a"}, key = {"space", "j", "enter"}, touch = "button:fire"})
I.bind("bomb", {pad = {"x", "y", "zl"}, key = {"b", "k", "x"}, touch = "button:bomb"})
I.touchControls{stick = true, buttons = {{id = "bomb", icon = "flare", action = "bomb"}}}

-- ---------------------------------------------------------------- sounds
A.define("laser", {wave = "square", volume = 0.05, notes = {{1250, 0.025}, {900, 0.03}}})
A.define("ehit", {wave = "noise", volume = 0.12, notes = {{400, 0.04}}})
A.define("boom", {wave = "noise", volume = 0.28, notes = {{90, 0.22}}})
A.define("bomb", {wave = "noise", volume = 0.5, notes = {{50, 0.5}}})
A.define("wave", {wave = "triangle", volume = 0.22, notes = "G4:0.1 C5:0.1 E5:0.1 G5:0.25"})
A.define("pickup", {wave = "triangle", volume = 0.25, notes = "E5:0.06 A5:0.06 E6:0.12"})
A.define("hurt", {wave = "saw", volume = 0.25, notes = {{220, 0.1}, {140, 0.25}}})
local SONG = {bpm = 128, wave = "square", volume = 0.035, div = 4,
              notes = "A3 - A4 - G4 - E4 - D4 - E4 - G4 - A4 - C5 - B4 - A4 - G4 - E4 - G4 - A4:4",
              bass = "A2:4 A2:4 F2:4 F2:4 G2:4 G2:4 E2:4 E2:4"}

-- ---------------------------------------------------------------- shapes (local points)
local SHIP = {14, 0, -9, -9, -5, 0, -9, 9}
local TRI = {11, 0, -8, -8, -8, 8}
local SQUARE = {-8, -8, 8, -8, 8, 8, -8, 8}
local HEX = {}
for i = 0, 5 do HEX[#HEX + 1] = cos(i * pi / 3) * 11; HEX[#HEX + 1] = sin(i * pi / 3) * 11 end
local DIAMOND = {0, -6, 5, 0, 0, 6, -5, 0}

-- ---------------------------------------------------------------- starfield
local stars = {}
local function makeStars()
  for layer = 1, 3 do
    local s = {f = layer * 0.25, n = 70, x = {}, y = {}, r = layer * 0.45 + 0.3, a = 70 + layer * 50}
    for i = 1, s.n do s.x[i], s.y[i] = random() * 1200, random() * 800 end
    stars[layer] = s
  end
end
local function drawStars(cam, t)
  G.gradient(0, 0, game.width, game.height, "#070A1C", "#160A2E")
  for layer = 1, 3 do
    local s = stars[layer]
    local ox = cam and cam.x * s.f or t * 8 * s.f
    local oy = cam and cam.y * s.f or 0
    gfx.color(200, 220, 255, s.a)
    for i = 1, s.n do
      local x = (s.x[i] - ox) % 1200
      local y = (s.y[i] - oy) % 800
      if x < game.width + 4 and y < game.height + 4 then G.circle(x, y, s.r) end
    end
  end
end

-- ---------------------------------------------------------------- entities
local Ship = game.class(game.Sprite)
function Ship:init(o)
  game.Sprite.init(self, o)
  self.r, self.body, self.damping, self.z = 8, true, 3.2, 10
  self.angle, self.cool, self.invuln, self.rapid, self.shield = 0, 0, 2, 0, 0
end
function Ship:render()
  local blink = self.invuln > 0 and floor(self.invuln * 14) % 2 == 0
  if blink then return end
  if self.shield > 0 then
    G.color(120, 220, 255, 110 + floor(sin(game.time * 10) * 40))
    G.circleLine(self.x, self.y, 15, 2)
  end
  G.polyT(SHIP, self.x, self.y, self.angle, 1, 1, "#E8F4FF")
  G.color("#36C5F0")
  G.linesT(SHIP, self.x, self.y, self.angle, 1, 1, 1.5, true)
  G.circle(self.x + cos(self.angle) * 3, self.y + sin(self.angle) * 3, 2.5, "#36C5F0")
end

local Bullet = game.class(game.Sprite)
function Bullet:render()
  G.color(self.color)
  G.line(self.x, self.y, self.x - self.vx * 0.025, self.y - self.vy * 0.025, self.enemy and 3 or 2.5)
end
function Bullet:update(dt)
  self.life = self.life - dt
  if self.life <= 0 or self.x < -20 or self.y < -20 or self.x > ARENA_W + 20 or self.y > ARENA_H + 20 then
    self.dead = true
  end
end

local KINDS = {
  chaser = {shape = TRI, color = "#FF4D6D", hp = 1, speed = 95, score = 50, r = 8},
  drifter = {shape = SQUARE, color = "#FFA62B", hp = 2, speed = 85, score = 75, r = 9},
  shooter = {shape = HEX, color = "#B45CFF", hp = 3, speed = 60, score = 150, r = 11},
  splitter = {shape = HEX, color = "#4CD964", hp = 4, speed = 45, score = 100, r = 15, scale = 1.4},
  mini = {shape = TRI, color = "#7CFFB2", hp = 1, speed = 130, score = 25, r = 6, scale = 0.7},
}

local Enemy = game.class(game.Sprite)
function Enemy:init(o)
  game.Sprite.init(self, o)
  local k = KINDS[self.kind]
  self.def, self.hp, self.r, self.body, self.z = k, k.hp, k.r, true, 5
  self.angle, self.spin, self.cool, self.flash = random() * pi * 2, (random() - 0.5) * 3, 1 + random() * 2, 0
  if self.kind == "drifter" then
    local a = random() * pi * 2
    self.vx, self.vy = cos(a) * k.speed, sin(a) * k.speed
  end
end
function Enemy:update(dt)
  local ship, k = self.scene.ship, self.def
  self.flash = self.flash - dt
  local dx, dy = ship.x - self.x, ship.y - self.y
  local d = sqrt(dx * dx + dy * dy) + 0.001
  if self.kind == "drifter" then
    self.angle = self.angle + self.spin * dt
    if self.x < self.r and self.vx < 0 or self.x > ARENA_W - self.r and self.vx > 0 then self.vx = -self.vx end
    if self.y < self.r and self.vy < 0 or self.y > ARENA_H - self.r and self.vy > 0 then self.vy = -self.vy end
  else
    local want = 1
    if self.kind == "shooter" then
      want = d > 200 and 1 or (d < 150 and -1 or 0)
      self.cool = self.cool - dt
      if self.cool <= 0 and d < 420 then
        self.cool = 2.2 + random()
        self.scene:enemyShot(self.x, self.y, dx / d, dy / d)
      end
    end
    local sp = k.speed * want * (1 + min(0.6, self.scene.wave * 0.05))
    self.vx = self.vx + (dx / d * sp - self.vx) * min(1, dt * 3)
    self.vy = self.vy + (dy / d * sp - self.vy) * min(1, dt * 3)
    self.angle = atan(dy, dx)
    if self.kind == "splitter" then self.angle = self.angle + game.time end
  end
  self.x = min(max(self.x, 0), ARENA_W)
  self.y = min(max(self.y, 0), ARENA_H)
end
function Enemy:render()
  local k = self.def
  local s = k.scale or 1
  local col = self.flash > 0 and "#FFFFFF" or k.color
  G.polyT(k.shape, self.x, self.y, self.angle, s, s, col)
  G.color(255, 255, 255, 160)
  G.linesT(k.shape, self.x, self.y, self.angle, s, s, 1, true)
end

local Pickup = game.class(game.Sprite)
local PU_TEXT = {rapid = "pu_rapid", shield = "pu_shield", life = "pu_life"}
local PICKUPS = {rapid = {"#FFE066", "bolt"}, shield = {"#78DCFF", "shield"}, life = {"#FF6B8B", "favorite"}}
function Pickup:update(dt)
  self.life = self.life - dt
  if self.life <= 0 then self.dead = true end
end
function Pickup:render()
  local p = PICKUPS[self.kind]
  local pulse = 1 + sin(game.time * 6) * 0.12
  if self.life < 3 and floor(self.life * 8) % 2 == 0 then return end
  G.circle(self.x, self.y, 9 * pulse, "#0A0F24D0")
  G.color(p[1])
  G.circleLine(self.x, self.y, 9 * pulse, 1.5)
  G.icon(p[2], self.x, self.y, 11, p[1])
end

-- ---------------------------------------------------------------- scenes
local Title, Play, Over = {pausable = false}, {controls = true}, {transparent = true, pausable = false}

function Title:enter()
  self.t = 0
  self.menu = U.menu{width = 190, items = {
    {label = function() return TR("start") end, action = function() game.switch(Play) end},
    {label = function() return TR("sound", A.muted and TR("off") or TR("on")) end,
     action = function() A.setMuted(not A.muted); game.save.open("settings"):set("muted", A.muted) end},
    {label = function() return TR("quit") end, action = function() sys.exit() end},
  }}
  A.song(nil)
end
function Title:update(dt) self.t = self.t + dt; self.menu:update() end
function Title:draw()
  drawStars(nil, self.t)
  for i = 0, 5 do
    local a = self.t * 0.4 + i * pi / 3
    G.polyT(TRI, game.width / 2 + cos(a) * 150, game.height * 0.55 + sin(a) * 70, a + pi / 2, 1, 1, "#FF4D6D80")
  end
  G.polyT(SHIP, game.width / 2, game.height * 0.55, self.t * 1.5, 1.6, 1.6, "#E8F4FF")
end
function Title:ui()
  local y = game.height * 0.12
  U.pixelText(TR("logo"), 0, y, 4, "#36C5F0", "center", game.width, "#0A2A55")
  U.text(TR("high_score", save:get("high", 0)), 0, y + 30, 12, "#FFE066", "center", game.width)
  self.menu:draw(game.width / 2, y + 56)
  -- the controls line is long: it gets smaller instead of running off both edges
  local cs = TR("controls")
  local csz = math.min(9, 9 * (game.width - 16) / math.max(1, gfx.textWidth(cs, 9, "semibold")))
  U.text(cs, 0, game.height - 6 - csz * 1.3, csz, "#FFFFFFC0", "center", game.width, "semibold")
end

-- play ----------------------------------------------------------------------------------------------
function Play:enter()
  self:start()
  A.song(SONG)
end

function Play:start()
  self.cam = game.camera{lerp = 0.12, deadzone = {w = 50, h = 40}}
  self.cam:setBounds(-60, -60, ARENA_W + 120, ARENA_H + 120)
  local w = game.world{camera = self.cam, cell = 48}
  self.world = w
  self.score, self.lives, self.bombs, self.wave, self.combo, self.comboT = 0, 3, 3, 0, 1, 0
  self.spawns, self.waveT, self.bombRing = {}, 1.2, nil
  self.ship = w:add(Ship{x = ARENA_W / 2, y = ARENA_H / 2, scene = self}, "ship")
  self.cam:follow(self.ship)
  self.cam:snap()
  self.boom = w:addEmitter(game.emitter{max = 500, life = {0.3, 0.9}, speed = {40, 260}, size = {4, 0}, damping = 2.5,
    colors = {"#FFFFFF", "#FFC94D", "#FF4D6D00"}, shape = "square"})
  self.sparks = w:addEmitter(game.emitter{max = 200, life = {0.1, 0.3}, speed = {80, 220}, spread = 1.4, size = {2, 1},
    colors = {"#FFFFFF", "#36C5F000"}, shape = "line", lineScale = 0.04})
  self.trail = w:addEmitter(game.emitter{max = 160, rate = 0, life = {0.2, 0.45}, speed = {30, 70}, spread = 0.6,
    size = {4, 0}, colors = {"#7FE7FF", "#3A6BFF00"}, damping = 2})
  w:collide("bullets", "enemies", function(b, e) self:hitEnemy(b, e) end)
  w:collide(self.ship, "enemies", function(s, e) self:hurt(e) end)
  w:collide(self.ship, "ebullets", function(s, b) b.dead = true; self:hurt(b) end)
  w:collide(self.ship, "pickups", function(s, p) self:pick(p) end)
  w:collide("enemies", "enemies", nil, true)
  self.over = false
end
function Play:restart() self:start() end

function Play:shoot(ax, ay)
  local s = self.ship
  local a = atan(ay, ax)
  s.angle = a
  s.cool = s.rapid > 0 and 0.06 or 0.13
  local spread = s.rapid > 0 and 0.07 or 0
  for k = -1, 1, 2 do
    local aa = a + k * spread
    local b = Bullet{x = s.x + cos(a) * 12 + cos(a + pi / 2) * k * 4, y = s.y + sin(a) * 12 + sin(a + pi / 2) * k * 4,
                     vx = cos(aa) * 520 + s.vx * 0.3, vy = sin(aa) * 520 + s.vy * 0.3, body = true, r = 3, life = 1.1,
                     color = "#7FE7FF", noCull = true}
    self.world:add(b, "bullets")
  end
  A.play("laser")
end

function Play:enemyShot(x, y, dx, dy)
  self.world:add(Bullet{x = x, y = y, vx = dx * 170, vy = dy * 170, body = true, r = 4, life = 4, color = "#FF5CD6",
                        enemy = true}, "ebullets")
end

function Play:explode(x, y, color, n)
  self.boom:setColors({"#FFFFFF", color, "#00000000"})
  self.boom:emit(n or 24, x, y)
end

function Play:hitEnemy(b, e)
  if b.dead or e.dead then return end
  b.dead = true
  e.hp = e.hp - 1
  e.flash = 0.06
  e.vx, e.vy = e.vx + b.vx * 0.05, e.vy + b.vy * 0.05
  self.sparks:emit(4, b.x, b.y, atan(-b.vy, -b.vx))
  if e.hp <= 0 then self:kill(e) else A.play("ehit") end
end

function Play:kill(e)
  e.dead = true
  self.combo = min(8, self.comboT > 0 and self.combo + 1 or 1)
  self.comboT = 1.6
  self.score = self.score + e.def.score * self.combo
  self:explode(e.x, e.y, e.def.color, e.kind == "splitter" and 40 or 22)
  self.cam:shake(e.kind == "splitter" and 5 or 2.5, 0.2)
  A.play("boom")
  if e.kind == "splitter" then
    for i = 1, 3 do
      local a = i * pi * 2 / 3
      self.world:add(Enemy{kind = "mini", x = e.x + cos(a) * 12, y = e.y + sin(a) * 12, scene = self}, "enemies")
    end
  end
  if random() < 0.09 then
    local r = random()
    local kind = r < 0.45 and "rapid" or (r < 0.85 and "shield" or "life")
    self.world:add(Pickup{x = e.x, y = e.y, kind = kind, r = 10, life = 9}, "pickups")
  end
end

function Play:pick(p)
  if p.dead then return end
  p.dead = true
  local s = self.ship
  if p.kind == "rapid" then s.rapid = 8 elseif p.kind == "shield" then s.shield = 12 else self.lives = self.lives + 1 end
  A.play("pickup")
  U.toast(TR(PU_TEXT[p.kind]), 1.2)
end

function Play:hurt(src)
  local s = self.ship
  if s.invuln > 0 or self.over then return end
  if s.shield > 0 then
    s.shield, s.invuln = 0, 1
    self:explode(s.x, s.y, "#78DCFF", 16)
    A.play("ehit")
    return
  end
  self.lives = self.lives - 1
  s.invuln = 2.2
  self:explode(s.x, s.y, "#36C5F0", 50)
  self.cam:shake(8, 0.45)
  sys.vibrate(0.8, 180)
  A.play("hurt")
  self.combo = 1
  if src and src.kind then src.vx, src.vy = (src.x - s.x) * 4, (src.y - s.y) * 4 end
  if self.lives <= 0 then
    self.over = true
    s.visible = false
    s.active = false
    self:explode(s.x, s.y, "#FFFFFF", 80)
    local record = save:best("high", self.score)
    save:best("bestWave", self.wave)
    game.tween.after(1.4, function() game.push(Over, {score = self.score, wave = self.wave, record = record}) end)
  end
end

function Play:bomb()
  if self.bombs <= 0 or self.over then return end
  self.bombs = self.bombs - 1
  local s = self.ship
  self.bombRing = {x = s.x, y = s.y, r = 10}
  game.tween.to(self.bombRing, 0.5, {r = 260}, "outCubic"):oncomplete(function() self.bombRing = nil end)
  A.play("bomb")
  self.cam:shake(9, 0.5)
  local en = self.world:group("enemies")
  for i = 1, en.n do
    local e = en[i]
    if not e.dead and game.dist(e.x, e.y, s.x, s.y) < 260 then self:kill(e) end
  end
  local eb = self.world:group("ebullets")
  for i = 1, eb.n do eb[i].dead = true end
end

local function waveMix(n)
  local list = {}
  local count = 3 + n * 2
  for i = 1, count do
    local r = random()
    local kind = "chaser"
    if n >= 2 and r < 0.3 then kind = "drifter" end
    if n >= 3 and r > 0.82 then kind = "shooter" end
    if n >= 4 and r > 0.93 then kind = "splitter" end
    list[i] = kind
  end
  if n % 5 == 0 then list[#list + 1] = "splitter"; list[#list + 1] = "splitter" end
  return list
end

function Play:nextWave()
  self.wave = self.wave + 1
  local s = self.ship
  for i, kind in ipairs(waveMix(self.wave)) do
    local x, y
    repeat
      x, y = 30 + random() * (ARENA_W - 60), 30 + random() * (ARENA_H - 60)
    until game.dist(x, y, s.x, s.y) > 220
    self.spawns[#self.spawns + 1] = {x = x, y = y, kind = kind, t = 0.9 + i * 0.12}
  end
  A.play("wave")
  U.toast(TR("wave_n", self.wave), 1.6)
  if self.wave > 1 then self.bombs = min(5, self.bombs + 1) end
end

function Play:update(dt)
  local s, w = self.ship, self.world
  if not self.over then
    -- movement
    local mx, my = I.vector()
    s.ax, s.ay = mx * 900, my * 900
    local moving = mx ~= 0 or my ~= 0
    if moving then
      self.trail.angle = s.angle + pi
      self.trail:emit(1, s.x - cos(s.angle) * 8, s.y - sin(s.angle) * 8)
    end
    s.x, s.y = min(max(s.x, 8), ARENA_W - 8), min(max(s.y, 8), ARENA_H - 8)
    -- aiming: right stick, then the mouse, then the nearest enemy, then facing
    s.cool = s.cool - dt
    s.invuln, s.rapid, s.shield = s.invuln - dt, s.rapid - dt, s.shield - dt
    local ax, ay, aiming = I.aim()
    local fire = aiming or I.down("fire") or I.touchVisible()
    local p = I.pointer
    if not aiming and p.down and not p.touch then
      local wx, wy = self.cam:toWorld(p.x, p.y)
      ax, ay, fire = wx - s.x, wy - s.y, true
    elseif not aiming then
      local target = w:group("enemies"):nearest(s.x, s.y, 320)
      if target then ax, ay = target.x - s.x, target.y - s.y
      elseif moving then ax, ay = mx, my
      else ax, ay = cos(s.angle), sin(s.angle) end
      if I.touchVisible() and not target then fire = false end
    end
    if moving and not fire then s.angle = atan(my, mx) end
    if fire and s.cool <= 0 then self:shoot(ax, ay) end
    if I.pressed("bomb") then self:bomb() end
  end
  -- waves and spawns
  for i = #self.spawns, 1, -1 do
    local sp = self.spawns[i]
    sp.t = sp.t - dt
    if sp.t <= 0 then
      table.remove(self.spawns, i)
      w:add(Enemy{kind = sp.kind, x = sp.x, y = sp.y, scene = self}, "enemies")
      self.boom:setColors({"#FFFFFF", KINDS[sp.kind].color, "#00000000"})
      self.boom:emit(8, sp.x, sp.y)
    end
  end
  if not self.over and #self.spawns == 0 and w:group("enemies").n == 0 then
    self.waveT = self.waveT - dt
    if self.waveT <= 0 then self.waveT = 1.6; self:nextWave() end
  end
  self.comboT = self.comboT - dt
  if self.comboT <= 0 then self.combo = 1 end
  w:update(dt)
end

function Play:draw()
  drawStars(self.cam)
  local cam = self.cam
  cam:attach()
  -- arena floor grid and border
  G.color(80, 120, 255, 28)
  local x0, y0, vw, vh = cam:view()
  local gs = 50
  for x = max(0, floor(x0 / gs) * gs), min(ARENA_W, x0 + vw), gs do G.line(x, 0, x, ARENA_H, 1) end
  for y = max(0, floor(y0 / gs) * gs), min(ARENA_H, y0 + vh), gs do G.line(0, y, ARENA_W, y, 1) end
  G.color(90, 160, 255, 170)
  G.rectLine(0, 0, ARENA_W, ARENA_H, 6, 2)
  -- spawn warnings
  for _, sp in ipairs(self.spawns) do
    local k = KINDS[sp.kind]
    local r, g, b = game.rgba(k.color)
    gfx.color(r, g, b, 90 + floor(sin(game.time * 20) * 60))
    G.circleLine(sp.x, sp.y, 6 + sp.t * 14, 1.5)
  end
  if self.bombRing then
    gfx.color(255, 240, 200, floor(220 * (1 - self.bombRing.r / 260)))
    G.circleLine(self.bombRing.x, self.bombRing.y, self.bombRing.r, 4)
  end
  cam:detach()
  self.world:draw()
end

function Play:ui()
  local m = 8
  U.score(self.score, m, m, 2, "#FFFFFF", 7)
  if self.combo > 1 then U.pixelText("x" .. self.combo, m + U.pixelWidth("0000000", 2) + 6, m, 2, "#FFE066") end
  U.text(TR("wave_short", self.wave), 0, m - 1, 11, "#9FD8FF", "center", game.width)
  local right = game.width - m - (I.touchVisible() and 30 or 0)
  for i = 1, min(self.lives, 6) do
    G.polyT(SHIP, right - (i - 1) * 16 - 6, m + 6, -pi / 2, 0.6, 0.6, "#E8F4FF")
  end
  for i = 1, self.bombs do G.icon("flare", right - (i - 1) * 14 - 6, m + 24, 12, "#FFC94D") end
  local s = self.ship
  if s.rapid > 0 then U.bar(m, m + 16, 50, 4, s.rapid / 8, "#FFE066") end
  if s.shield > 0 then U.bar(m, m + 23, 50, 4, s.shield / 12, "#78DCFF") end
end

-- game over --------------------------------------------------------------------------------------
function Over:enter(p)
  self.p = p
  self.menu = U.menu{width = 180, items = {
    {label = function() return TR("again") end, action = function() game.switch(Play) end},
    {label = function() return TR("main_menu") end, action = function() game.switch(Title) end},
  }}
  A.stopSong()
end
function Over:update() self.menu:update() end
function Over:ui()
  local p = self.p
  G.rect(0, 0, game.width, game.height, 0, "#00000099")
  local w, h = 240, 190
  local x, y = (game.width - w) / 2, (game.height - h) / 2
  U.panel(x, y, w, h, 12)
  U.pixelText(TR("game_over"), x, y + 14, 3, "#FF6B8B", "center", w)
  U.score(p.score, x + w / 2, y + 42, 3, "#FFFFFF", 0, "center")
  U.text(p.record and TR("new_high") or TR("high_score", save:get("high", 0)), x, y + 66, 12,
         p.record and "#7CFFB2" or "#FFE066", "center", w)
  U.text(TR("reached_wave", p.wave), x, y + 84, 11, "#FFFFFFC0", "center", w, "semibold")
  self.menu:draw(game.width / 2, y + 108)
end

-- ---------------------------------------------------------------- run
return game.run{
  width = 480, height = 270, scale = "expand",
  scene = Title, title = Title,
  background = "#070A1C",
  load = makeStars,
  menu = function()
    return {{title = TR("game_menu"), items = {
      {label = TR("pause_menu"), id = 1, shortcut = "Esc"},
      {label = TR("main_menu"), id = 2},
      "-",
      {label = TR("debug"), id = 3, shortcut = "F3"},
      {label = TR("reset_high"), id = 4},
    }}}
  end,
  onmenu = function(id)
    if id == 1 then game.pause()
    elseif id == 2 then game.switch(Title)
    elseif id == 3 then game.debug = not game.debug
    elseif id == 4 then save:reset(); U.toast(TR("high_reset"))
    end
  end,
}
