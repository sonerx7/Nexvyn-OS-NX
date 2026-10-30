-- Tank Düellosu / Tank Duel: turn-based artillery built with the nexvyn.game engine.
-- Two tanks on destructible terrain (a heightmap: explosions carve craters, the dirt above falls in, tanks drop
-- onto the new surface), wind that drifts every turn, angle + power aiming, two players on one console or a CPU
-- with three difficulty levels. A match is won by the first tank to take 3 rounds; match records are saved.

local game = require("nexvyn.game")

local G, I, U, A = game.gfx, game.input, game.ui, game.audio
local floor, sqrt, sin, cos, abs, min, max, random, pi = math.floor, math.sqrt, math.sin, math.cos, math.abs,
  math.min, math.max, math.random, math.pi
local atan, rad, deg = math.atan, math.rad, math.deg

local W, H = 480, 270
local FLOOR_Y = 264        -- bedrock: craters never go deeper than this
local GRAV = 200           -- shell gravity (units/s²)
local SPEED_K = 3.4        -- power 100 -> 340 units/s
local WIND_K = 7           -- wind 10 -> 70 units/s² sideways
local BLAST = 22           -- crater radius
local REACH = BLAST + 10   -- damage radius around the impact
local WINS_NEEDED = 3
local STEP = 1 / 60

local save = game.save.open("tanks")
-- CPU aiming error per difficulty: max angle error (degrees), max power error, thinking time
local CPU_ERR = {{a = 9, p = 12, think = 1.0}, {a = 4.5, p = 6, think = 0.8}, {a = 1.2, p = 1.5, think = 0.6}}

local P_COLORS = {{body = "#4FA3FF", dark = "#1F5FA8"}, {body = "#FF5A5A", dark = "#A82424"}}

-- ---------------------------------------------------------------- input
-- left/right (d-pad, stick, arrows, A/D) turn the barrel, up/down change the power; fire with A, ZR, Space, Enter
I.bind("fire", {pad = {"a", "zr"}, key = {"space", "enter"}})

-- ---------------------------------------------------------------- sounds
A.define("fire", {wave = "noise", volume = 0.3, notes = {{140, 0.14}}})
A.define("boom", {wave = "noise", volume = 0.5, notes = {{60, 0.5}}})
A.define("thud", {wave = "triangle", volume = 0.3, notes = {{110, 0.07}, {70, 0.12}}})
A.define("tick", {wave = "square", volume = 0.035, notes = {{880, 0.015}}})
A.define("turn", {wave = "triangle", volume = 0.18, notes = "C5:0.06 G5:0.1"})
A.define("hurt", {wave = "saw", volume = 0.2, notes = {{240, 0.08}, {150, 0.2}}})
A.define("round", {wave = "square", volume = 0.1, notes = "C5:0.1 E5:0.1 G5:0.1 C6:0.3"})
A.define("puff", {wave = "noise", volume = 0.12, notes = {{80, 0.25}}})

-- several notes at once (a chord); respects the mute switch of the pause menu / title screen
local function chord(notes, secs, vol, wave)
  if A.muted then return end
  for i = 1, #notes do audio.tone(A.freq(notes[i]), secs, vol, wave or "triangle") end
end
local CH_ROUND, CH_WIN, CH_WIN2, CH_LOSE = {"C4", "G4", "C5"}, {"C5", "E5", "G5"}, {"F5", "A5", "C6"}, {"A3", "C4", "Eb4"}
local function bigBoom()
  A.play("boom")
  if not A.muted then audio.tone(48, 0.45, 0.35, "sine"); audio.tone(72, 0.25, 0.2, "triangle") end
end
local function fanfare()
  A.play("win")
  chord(CH_WIN, 0.3, 0.07)
  game.tween.after(0.32, function() chord(CH_WIN2, 0.6, 0.07) end)
end

-- ---------------------------------------------------------------- terrain (shared by title and play)
local hm = {}       -- surface y of every 1-unit column, 1..W; solid ground fills everything below it
local surf = {}     -- polyline of the surface for the grass edge, rebuilt after every change
for i = 1, W do hm[i] = 200 end

local function rebuildSurface()
  local n = 0
  for x = 0, W, 4 do
    surf[n + 1], surf[n + 2] = x, hm[min(W, x + 1)]
    n = n + 2
  end
  for i = n + 1, #surf do surf[i] = nil end
end

local function groundAt(x)
  local i = floor(x) + 1
  if i < 1 then i = 1 elseif i > W then i = W end
  return hm[i]
end

-- three sine layers: broad hills, bumps and a little roughness
local function genTerrain()
  local base = 170 + random() * 35
  local a1, f1, p1 = 22 + random() * 32, 0.007 + random() * 0.009, random() * 6.28
  local a2, f2, p2 = 6 + random() * 14, 0.022 + random() * 0.022, random() * 6.28
  local a3, f3, p3 = 1.5 + random() * 3, 0.08 + random() * 0.06, random() * 6.28
  for i = 1, W do
    local y = base + a1 * sin(i * f1 + p1) + a2 * sin(i * f2 + p2) + a3 * sin(i * f3 + p3)
    hm[i] = min(FLOOR_Y - 22, max(80, y))
  end
end

-- a level pad under a tank so it starts upright
local function flatten(cx, half)
  local a, b = max(1, floor(cx - half) + 1), min(W, floor(cx + half) + 1)
  local s = 0
  for i = a, b do s = s + hm[i] end
  local avg = s / (b - a + 1)
  for i = a, b do hm[i] = avg end
end

-- removes a disc of ground; the dirt above the hole falls straight down into it
local function carve(ex, ey, r)
  local a, b = max(1, floor(ex - r) + 1), min(W, floor(ex + r) + 1)
  for i = a, b do
    local dx = (i - 0.5) - ex
    local d2 = r * r - dx * dx
    if d2 > 0 then
      local dy = sqrt(d2)
      local h = hm[i]
      local bot = ey + dy
      if bot > h then hm[i] = min(FLOOR_Y, h + (bot - max(h, ey - dy))) end
    end
  end
  rebuildSurface()
end

-- ---------------------------------------------------------------- shared drawing
local TANK_BODY = {-8, -2, 8, -2, 6, -7, -6, -7}
local ARROW = {0, -4, 7, 0, 0, 4}

local clouds = {}
for i = 1, 6 do clouds[i] = {x = random() * W, y = 18 + random() * 70, s = 0.6 + random() * 0.8} end

local function drawSky(wind, dt)
  G.gradient(0, 0, W, H, "#5DA9E9", "#CFE8F7")
  G.circle(W * 0.82, 48, 16, "#FFF4C2")
  for i = 1, #clouds do
    local c = clouds[i]
    c.x = c.x + (wind * 2.2 + 3) * c.s * (dt or 0)
    if c.x > W + 40 then c.x = -40 elseif c.x < -40 then c.x = W + 40 end
    local s = c.s
    G.color(255, 255, 255, 200)
    G.circle(c.x, c.y, 9 * s)
    G.circle(c.x + 10 * s, c.y + 3 * s, 7 * s)
    G.circle(c.x - 10 * s, c.y + 3 * s, 6 * s)
  end
end

local function drawTerrain()
  for i = 1, W, 2 do
    local y = min(hm[i], hm[min(W, i + 1)])
    G.gradient(i - 1, y, 2, H - y, "#8A5A32", "#3E2414")
  end
  G.color("#5DBB46")
  G.lines(surf, 3)
end

local function drawTank(t, active, time)
  if t.hp <= 0 then
    -- wreck: dark hull and a little smoke
    G.polyT(TANK_BODY, t.x, t.y, 0, 1, 1, "#3A3A3A")
    G.color(80, 80, 80, 120)
    G.circle(t.x + sin(time * 2) * 2, t.y - 12 - (time * 10) % 8, 3)
    return
  end
  local a = rad(t.angle)
  local bx, by = t.x, t.y - 8
  G.color(t.flash > 0 and "#FFFFFF" or t.dark)
  G.line(bx, by, bx + cos(a) * 12, by - sin(a) * 12, 3)
  G.circle(bx, by, 4.5, t.flash > 0 and "#FFFFFF" or t.dark)
  G.polyT(TANK_BODY, t.x, t.y, 0, 1, 1, t.flash > 0 and "#FFFFFF" or t.body)
  G.rect(t.x - 9, t.y - 3, 18, 3.5, 1.7, "#2A2A2A")
  if active then
    local bob = sin(time * 6) * 2
    G.polyT(ARROW, t.x, t.y - 24 + bob, pi / 2, 1, 1, "#FFFFFF")
  end
end

-- ---------------------------------------------------------------- scenes
local Title, Play, Over = {pausable = false}, {}, {transparent = true, pausable = false}

local function diffName(d)
  if d == 1 then return TR("diff_easy") elseif d == 3 then return TR("diff_hard") end
  return TR("diff_normal")
end

local function cycleDiff(dir)
  local d = save:get("diff", 2)
  d = (d - 1 + dir) % 3 + 1
  save:set("diff", d)
end

function Title:enter()
  self.t = 0
  genTerrain()
  flatten(90, 10)
  flatten(W - 90, 10)
  rebuildSurface()
  -- logo drops in, the menu slides up
  self.logo = {y = -50, s = 0.6}
  game.tween.to(self.logo, 0.9, {y = 14}, "outBounce")
  game.tween.to(self.logo, 0.9, {s = 1}, "outBack")
  self.menuY = {y = H + 20}
  game.tween.to(self.menuY, 0.6, {y = 52}, {ease = "outCubic", delay = 0.25})
  -- demo duel in the background: the tanks lob shells at each other
  self.demo = {active = false, x = 0, y = 0, vx = 0, vy = 0, next = 1.6, who = 1}
  self.boom = game.emitter{max = 120, life = {0.3, 0.8}, speed = {30, 150}, size = {3, 0}, damping = 2, gravity = 100,
    colors = {"#FFFFFF", "#FFC94D", "#FF5A2000"}}
  self.dirt = game.emitter{max = 100, life = {0.4, 0.9}, speed = {50, 140}, size = {2.5, 1}, gravity = 360,
    angle = -pi / 2, spread = 2.2, colors = {"#8A5A32", "#5A3A1A00"}, shape = "square"}
  self.shake = 0
  self.tanks = {
    {x = 90, y = groundAt(90), angle = 40, hp = 100, flash = 0, body = P_COLORS[1].body, dark = P_COLORS[1].dark},
    {x = W - 90, y = groundAt(W - 90), angle = 140, hp = 100, flash = 0, body = P_COLORS[2].body, dark = P_COLORS[2].dark},
  }
  self.menu = U.menu{width = 220, itemHeight = 28, size = 13, items = {
    {label = function() return TR("play_cpu") end,
     action = function() game.switch(Play, {mode = "cpu", diff = save:get("diff", 2)}) end},
    {label = function() return TR("difficulty", diffName(save:get("diff", 2))) end,
     action = function() cycleDiff(1) end, left = function() cycleDiff(-1) end, right = function() cycleDiff(1) end},
    {label = function() return TR("play_pvp") end, action = function() game.switch(Play, {mode = "pvp"}) end},
    {label = function() return TR("sound", A.muted and TR("off") or TR("on")) end,
     action = function() A.setMuted(not A.muted); game.save.open("settings"):set("muted", A.muted) end},
  }}
end

function Title:update(dt)
  self.t = self.t + dt
  self.menu:update()
  self.boom:update(dt)
  self.dirt:update(dt)
  self.shake = max(0, self.shake - dt * 12)
  local d = self.demo
  local shooter, target = self.tanks[d.who], self.tanks[3 - d.who]
  if not d.active then
    -- swing the barrel towards the next shot, then fire
    d.next = d.next - dt
    shooter.angle = game.approach(shooter.angle, d.who == 1 and 50 or 130, 40 * dt)
    if d.next <= 0 then
      local a = rad(shooter.angle)
      local dx = abs(target.x - shooter.x) * (0.85 + random() * 0.3)
      local v = sqrt(dx * GRAV / max(0.2, sin(2 * rad(50))))
      d.x, d.y = shooter.x + cos(a) * 12, shooter.y - 8 - sin(a) * 12
      d.vx, d.vy, d.active = cos(a) * v, -sin(a) * v, true
      A.play("fire", 0.4)
    end
  else
    d.vy = d.vy + GRAV * dt
    d.x, d.y = d.x + d.vx * dt, d.y + d.vy * dt
    if d.x < -20 or d.x > W + 20 or d.y > H then d.active = false
    elseif d.x >= 0 and d.x < W and d.y >= groundAt(d.x) then
      d.active = false
      self.boom:emit(22, d.x, d.y)
      self.dirt:emit(14, d.x, d.y)
      self.shake = 3
      A.play("puff")
      -- small craters only, so the title terrain never gets ruined
      local ay = groundAt(d.x)
      if ay < FLOOR_Y - 40 then carve(d.x, d.y, 9) end
    end
    if not d.active then
      d.who, d.next = 3 - d.who, 1.4 + random() * 1.2
    end
  end
  for i = 1, 2 do
    local t = self.tanks[i]
    t.y = game.approach(t.y, groundAt(t.x), 60 * dt)
  end
end

function Title:draw()
  drawSky(2, STEP)
  local sx, sy = (random() - 0.5) * self.shake, (random() - 0.5) * self.shake
  G.push(sx, sy)
  drawTerrain()
  drawTank(self.tanks[1], false, self.t)
  drawTank(self.tanks[2], false, self.t)
  local d = self.demo
  if d.active then G.circle(d.x, d.y, 2.4, "#202020") end
  self.dirt:draw()
  self.boom:draw()
  G.pop()
end

function Title:ui()
  local lg = self.logo
  local size = 30 * lg.s
  U.text(TR("logo"), 0, lg.y + (30 - size) / 2, size, "#FFE066", "center", W, "bold", "#5A3A10")
  local y = self.menuY.y
  self.menu:draw(W / 2, y)
  local rec = TR("record_cpu", save:get("cpu_w", 0), save:get("cpu_l", 0)) .. "   ·   " ..
    TR("record_pvp", save:get("pvp_1", 0), save:get("pvp_2", 0))
  U.panel(W / 2 - 170, y + 118, 340, 18, 9, "#00000070")
  U.text(rec, 0, y + 121, 9, "#FFFFFF", "center", W, "semibold")
  local best = save:get("best_streak", 0)
  if best > 0 then U.text(TR("best_streak", best), 0, y + 140, 8, "#FFE9A0", "center", W, "semibold") end
  local cs = TR("controls")
  local csz = min(8, 8 * (W - 16) / max(1, G.textWidth(cs, 8, "semibold")))
  U.panel(0, H - 20, W, 20, 0, "#00000080")
  U.text(cs, 0, H - 10 - csz * 0.65, csz, "#FFFFFFD0", "center", W, "semibold")
end

-- ---------------------------------------------------------------- play
-- states: "aim" (current player aims), "flight" (shell in the air), "settle" (explosion, tanks fall),
-- "roundover" (short pause before the next round or the match result)

local FIRE_BTN = {x = W - 78, y = H - 23, w = 72, h = 20}
local PAUSE_BTN = {x = W - 106, y = H - 23, w = 24, h = 20}
local function inRect(r, x, y) return x >= r.x and y >= r.y and x < r.x + r.w and y < r.y + r.h end

function Play:enter(p)
  p = p or {}
  self.mode = p.mode or "pvp"
  self.diff = p.diff or 2
  self.boom = game.emitter{max = 260, life = {0.3, 0.9}, speed = {40, 210}, size = {4, 0}, damping = 2, gravity = 120,
    colors = {"#FFFFFF", "#FFC94D", "#FF5A2000"}}
  self.dirt = game.emitter{max = 200, life = {0.5, 1.1}, speed = {60, 180}, size = {3, 1}, gravity = 380,
    angle = -pi / 2, spread = 2.2, colors = {"#8A5A32", "#5A3A1A00"}, shape = "square"}
  self.smoke = game.emitter{max = 120, life = {0.3, 0.7}, speed = {5, 20}, size = {3, 6}, damping = 1,
    colors = {"#FFFFFFB0", "#C8C8C800"}}
  self.trails = {{}, {}}
  self.trailN = {0, 0}
  self.popups = {}
  for i = 1, 8 do self.popups[i] = {t = 0, x = 0, y = 0, text = "", color = "#FFFFFF", size = 11} end
  self.banner = {text = "", a = 0, s = 1}
  self.shot = {x = 0, y = 0, vx = 0, vy = 0, t = 0, steps = 0}
  self.cpu = {phase = "think", t = 0}
  self:startMatch()
end

function Play:restart() self:startMatch() end

function Play:startMatch()
  local names = {TR("p1"), self.mode == "cpu" and TR("cpu") or TR("p2")}
  if self.mode == "cpu" then names[1] = TR("you") end
  self.tanks = {}
  for i = 1, 2 do
    self.tanks[i] = {id = i, name = names[i], wins = 0, hp = 100, shots = 0, hits = 0, direct = 0, dealt = 0,
                     x = 0, y = 0, vy = 0, falling = false, fallFrom = 0,
                     angle = i == 1 and 45 or 135, power = 60, flash = 0, body = P_COLORS[i].body,
                     dark = P_COLORS[i].dark, cpu = (i == 2 and self.mode == "cpu")}
  end
  self.round = 0
  self.wind = 0
  self.shake = 0
  self.time = 0
  self:startRound()
end

function Play:clearTrail(i)
  local t = self.trails[i]
  for k = #t, 1, -1 do t[k] = nil end
  self.trailN[i] = 0
end

function Play:startRound()
  self.round = self.round + 1
  genTerrain()
  local x1 = 25 + random() * 95
  local x2 = W - 25 - random() * 95
  flatten(x1, 11)
  flatten(x2, 11)
  rebuildSurface()
  local xs = {x1, x2}
  for i = 1, 2 do
    local t = self.tanks[i]
    t.x, t.hp, t.vy, t.falling, t.flash = xs[i], 100, 0, false, 0
    t.y = self:restY(t)
    t.angle, t.power = i == 1 and 45 or 135, 60
    self:clearTrail(i)
  end
  self.boom:clear(); self.dirt:clear(); self.smoke:clear()
  self.cur = (self.round - 1) % 2 + 1     -- players take turns starting a round
  self.wind = random(-6, 6)
  self.state = "aim"
  self.dragging = false
  self.cpu.phase, self.cpu.t = "think", 0
  self.fireReq, self.pauseReq = false, false
  A.play("round")
  chord(CH_ROUND, 0.5, 0.05)
  self:showBanner(TR("round_n", self.round))
end

-- the tank rests on the highest point under its tracks
function Play:restY(t)
  local y = FLOOR_Y
  local a, b = max(1, floor(t.x - 7) + 1), min(W, floor(t.x + 7) + 1)
  for i = a, b do if hm[i] < y then y = hm[i] end end
  return y
end

-- floating feedback text from a fixed pool (the oldest one is reused when all are busy)
function Play:popup(x, y, text, color, size)
  local best = self.popups[1]
  for i = 1, #self.popups do
    local p = self.popups[i]
    if p.t <= 0 then best = p; break end
    if p.t < best.t then best = p end
  end
  best.x, best.y, best.text, best.t = max(40, min(W - 40, x)), y, text, 1.3
  best.color, best.size = color or "#FFE066", size or 11
end

-- big centred banner ("Round 2"): pops in with outBack, holds, fades
function Play:showBanner(text)
  local b = self.banner
  b.text, b.a, b.s = text, 0, 0.4
  if b.tw then b.tw:cancel() end
  if b.tw2 then b.tw2:cancel() end
  b.tw = game.tween.to(b, 0.45, {a = 1, s = 1}, "outBack")
  b.tw2 = game.tween.to(b, 0.4, {a = 0}, {ease = "inQuad", delay = 1.3})
end

function Play:damage(t, dmg, by)
  if dmg <= 0 or t.hp <= 0 then return end
  dmg = min(dmg, t.hp)
  t.hp = max(0, t.hp - dmg)
  t.flash = 0.25
  if by and by ~= t then by.dealt = by.dealt + dmg end
  self:popup(t.x, t.y - 20, "-" .. dmg, "#FFE066", 12)
  if t.hp <= 0 then
    self.boom:emit(50, t.x, t.y - 5)
    A.play("explode")
  else
    A.play("hurt")
  end
end

function Play:nextTurn()
  self.cur = 3 - self.cur
  -- the wind drifts a little every turn
  local w = self.wind + random(-4, 4)
  if w == self.wind then w = w + (random() < 0.5 and -1 or 1) end
  self.wind = max(-10, min(10, w))
  self.state = "aim"
  self.cpu.phase, self.cpu.t = "think", 0
  self.fireReq = false
  self.dragging = false
  A.play("turn")
end

function Play:fire()
  local t = self.tanks[self.cur]
  local a = rad(t.angle)
  local v = t.power * SPEED_K
  local s = self.shot
  s.x, s.y = t.x + cos(a) * 12, t.y - 8 - sin(a) * 12
  s.vx, s.vy, s.t, s.steps = cos(a) * v, -sin(a) * v, 0, 0
  self:clearTrail(self.cur)
  self.state = "flight"
  t.shots = t.shots + 1
  self.smoke:emit(8, s.x, s.y)
  self.shake = max(self.shake, 1.5)
  A.play("fire")
  sys.vibrate(0.4, 60)
end

function Play:explode(x, y, direct)
  carve(x, y, BLAST)
  self.boom:emit(40, x, y)
  self.dirt:emit(30, x, y)
  self.shake = direct and 9 or 6
  bigBoom()
  sys.vibrate(0.7, 140)
  local shooter = self.tanks[self.cur]
  local foe = self.tanks[3 - self.cur]
  local foeHp = foe.hp
  for i = 1, 2 do
    local t = self.tanks[i]
    local dx, dy = t.x - x, (t.y - 5) - y
    local d = sqrt(dx * dx + dy * dy)
    if d < REACH then
      local dmg = floor(8 + 40 * (1 - d / REACH) + 0.5)
      if direct == t then dmg = dmg + 12 end
      self:damage(t, dmg, shooter)
    end
  end
  if foe.hp < foeHp then shooter.hits = shooter.hits + 1 end
  if direct == foe then
    shooter.direct = shooter.direct + 1
    self:popup(foe.x, foe.y - 36, TR("direct_hit"), "#FF8A5A", 13)
  elseif foe.hp == foeHp then
    self:popup(x, y - 26, TR("miss"), "#FFFFFFC0", 10)
  end
  -- tanks whose ground was blown away start to fall
  for i = 1, 2 do
    local t = self.tanks[i]
    if self:restY(t) > t.y + 0.5 then t.falling, t.vy, t.fallFrom = true, 0, t.y end
  end
  self.state = "settle"
  self.settleT = 0.7
end

-- one simulation step of the shell; returns nothing, changes the state on impact
function Play:stepShot(dt)
  local s = self.shot
  s.vx = s.vx + self.wind * WIND_K * dt
  s.vy = s.vy + GRAV * dt
  s.x, s.y = s.x + s.vx * dt, s.y + s.vy * dt
  s.t = s.t + dt
  s.steps = s.steps + 1
  -- trail: one point every 3 steps, at most 250 points
  local n = self.trailN[self.cur]
  if s.steps % 3 == 0 and n < 500 then
    local tr = self.trails[self.cur]
    tr[n + 1], tr[n + 2] = s.x, s.y
    self.trailN[self.cur] = n + 2
  end
  for i = 1, 2 do
    local t = self.tanks[i]
    if t.hp > 0 and (i ~= self.cur or s.t > 0.15) then
      local dx, dy = s.x - t.x, s.y - (t.y - 5)
      if dx * dx + dy * dy < 81 then self:explode(s.x, s.y, t); return end
    end
  end
  if s.x >= 0 and s.x < W and s.y >= groundAt(s.x) then self:explode(s.x, s.y); return end
  if s.x < -80 or s.x > W + 80 or s.y > H + 10 or s.t > 10 then
    -- off the map: a miss
    self.state = "settle"
    self.settleT = 0.4
    self:popup(max(30, min(W - 30, s.x)), 60, TR("miss"), "#FFFFFFC0", 11)
  end
end

-- ---------------------------------------------------------------- CPU
-- same physics as the real shell; returns how far from the target the shot lands
function Play:simulate(sx, sy, angle, power, tx, ty)
  local a = rad(angle)
  local v = power * SPEED_K
  local x, y, vx, vy = sx, sy, cos(a) * v, -sin(a) * v
  local ax = self.wind * WIND_K
  local dt = STEP
  for _ = 1, 600 do
    vx = vx + ax * dt
    vy = vy + GRAV * dt
    x, y = x + vx * dt, y + vy * dt
    local dx, dy = x - tx, y - ty
    if dx * dx + dy * dy < 81 then return 0 end
    if x < -80 or x > W + 80 or y > H + 10 then return 300 + abs(x - tx) end
    if x >= 0 and x < W and y >= groundAt(x) then return sqrt(dx * dx + dy * dy) end
  end
  return 9999
end

-- thinking is spread over several update steps: one candidate angle per step
function Play:cpuUpdate(dt)
  local c, t = self.cpu, self.tanks[self.cur]
  local foe = self.tanks[3 - self.cur]
  c.t = c.t + dt
  if c.phase == "think" then
    c.phase = "search"
    c.k, c.bestD, c.bestA, c.bestP = 0, 1e9, t.angle, t.power
    c.left = foe.x < t.x
  elseif c.phase == "search" then
    if c.k < 9 then
      local base = 18 + c.k * 7          -- 18..74 degrees above the horizon
      local ang = c.left and (180 - base) or base
      local a = rad(ang)
      local sx, sy = t.x + cos(a) * 12, t.y - 8 - sin(a) * 12
      for p = 12, 100, 3 do
        local d = self:simulate(sx, sy, ang, p, foe.x, foe.y - 5)
        if d < c.bestD then c.bestD, c.bestA, c.bestP = d, ang, p end
      end
      c.k = c.k + 1
    else
      -- refine the power around the best shot
      local a = rad(c.bestA)
      local sx, sy = t.x + cos(a) * 12, t.y - 8 - sin(a) * 12
      local p0 = c.bestP
      for p = max(5, p0 - 3), min(100, p0 + 3), 0.5 do
        local d = self:simulate(sx, sy, c.bestA, p, foe.x, foe.y - 5)
        if d < c.bestD then c.bestD, c.bestP = d, p end
      end
      local e = CPU_ERR[self.diff] or CPU_ERR[2]
      c.ta = max(0, min(180, c.bestA + (random() * 2 - 1) * e.a))
      c.tp = max(5, min(100, c.bestP + (random() * 2 - 1) * e.p))
      c.phase = "turn"
      c.wait = e.think
    end
  elseif c.phase == "turn" then
    c.wait = c.wait - dt
    if c.wait <= 0 then
      t.angle = game.approach(t.angle, c.ta, 50 * dt)
      t.power = game.approach(t.power, c.tp, 45 * dt)
      if t.angle == c.ta and t.power == c.tp then c.phase = "fire"; c.wait = 0.35 end
    end
  elseif c.phase == "fire" then
    c.wait = c.wait - dt
    if c.wait <= 0 then c.phase = "done"; self:fire() end
  end
end

-- ---------------------------------------------------------------- human aiming
function Play:humanAim(dt)
  local t = self.tanks[self.cur]
  local mx, my = I.vector()
  if mx ~= 0 or my ~= 0 then
    self.holdT = (self.holdT or 0) + dt
    local k = min(1, 0.3 + self.holdT * 0.7)   -- slow at first for fine aiming, faster when held
    local a0, p0 = floor(t.angle), floor(t.power)
    t.angle = max(0, min(180, t.angle - mx * 70 * k * dt))
    t.power = max(5, min(100, t.power - my * 50 * k * dt))
    if floor(t.angle) ~= a0 or floor(t.power) ~= p0 then
      self.tickT = (self.tickT or 0) - dt
      if self.tickT <= 0 then A.play("tick"); self.tickT = 0.06 end
    end
  else
    self.holdT = 0
  end
  -- touch / mouse: drag anywhere on the field; the barrel points at the finger, the distance sets the power
  local p = I.pointer
  local onButton = inRect(FIRE_BTN, p.downX, p.downY) or inRect(PAUSE_BTN, p.downX, p.downY)
  if p.down and not onButton then
    self.dragging = true
    local dx, dy = p.x - t.x, (t.y - 8) - p.y
    if dy < 0 then dy = 0 end
    if dx ~= 0 or dy ~= 0 then t.angle = max(0, min(180, deg(atan(dy, dx)))) end
    t.power = max(5, min(100, sqrt(dx * dx + dy * dy) / 1.6))
  else
    self.dragging = false
  end
  if I.pressed("fire") or self.fireReq then
    self.fireReq = false
    self:fire()
  end
end

function Play:update(dt)
  self.time = self.time + dt
  self.dt = dt
  self.boom:update(dt); self.dirt:update(dt); self.smoke:update(dt)
  self.shake = max(0, self.shake - dt * 14)
  for i = 1, #self.popups do
    local p = self.popups[i]
    if p.t > 0 then p.t = p.t - dt; p.y = p.y - 14 * dt end
  end
  for i = 1, 2 do local t = self.tanks[i]; if t.flash > 0 then t.flash = t.flash - dt end end
  if self.pauseReq then self.pauseReq = false; game.pause(); return end

  local st = self.state
  if st == "aim" then
    local t = self.tanks[self.cur]
    if t.cpu then self:cpuUpdate(dt) else self:humanAim(dt) end
  elseif st == "flight" then
    self:stepShot(dt)
    if self.state == "flight" and self.shot.steps % 2 == 0 then self.smoke:emit(1, self.shot.x, self.shot.y) end
  elseif st == "settle" then
    self.settleT = self.settleT - dt
    local moving = false
    for i = 1, 2 do
      local t = self.tanks[i]
      if t.falling then
        moving = true
        t.vy = t.vy + 400 * dt
        t.y = t.y + t.vy * dt
        local ry = self:restY(t)
        if t.y >= ry then
          t.y, t.falling = ry, false
          local fall = ry - t.fallFrom
          A.play("thud")
          self.dirt:emit(6, t.x, t.y)
          if fall > 12 then self:damage(t, min(30, floor((fall - 12) * 0.5)), self.tanks[self.cur]) end
        end
      end
    end
    if not moving and self.settleT <= 0 then self:afterShot() end
  elseif st == "roundover" then
    self.overT = self.overT - dt
    if self.overT <= 0 then
      local t1, t2 = self.tanks[1], self.tanks[2]
      if t1.wins >= WINS_NEEDED or t2.wins >= WINS_NEEDED then
        self.state = "matchover"
        self:finishMatch()
      else
        self:startRound()
      end
    end
  end
end

function Play:afterShot()
  local t1, t2 = self.tanks[1], self.tanks[2]
  local d1, d2 = t1.hp <= 0, t2.hp <= 0
  if d1 or d2 then
    self.state = "roundover"
    self.overT = 2.2
    if d1 and d2 then
      self:showBanner(TR("round_draw"))
    else
      local w = d1 and t2 or t1
      w.wins = w.wins + 1
      self:showBanner(TR("round_won", w.name))
      if w.cpu then A.play("lose"); chord(CH_LOSE, 0.6, 0.06) else fanfare() end
    end
  else
    self:nextTurn()
  end
end

local function accuracy(t) return t.shots > 0 and floor(t.hits * 100 / t.shots + 0.5) or 0 end

function Play:finishMatch()
  local t1, t2 = self.tanks[1], self.tanks[2]
  local winner = t1.wins >= WINS_NEEDED and 1 or 2
  local cpuLost = self.mode == "cpu" and winner == 2
  local records = {}
  if self.mode == "cpu" then
    save:inc(winner == 1 and "cpu_w" or "cpu_l")
    -- win streak against the CPU
    local streak = winner == 1 and save:get("streak", 0) + 1 or 0
    save:set("streak", streak)
    if streak > 0 and save:best("best_streak", streak) and streak > 1 then
      records[#records + 1] = TR("new_streak", streak)
    end
  else
    save:inc(winner == 1 and "pvp_1" or "pvp_2")
  end
  -- best accuracy of a human match winner (at least 3 shots)
  local w = self.tanks[winner]
  if not w.cpu and w.shots >= 3 and save:best("best_acc", accuracy(w)) then
    records[#records + 1] = TR("new_acc", accuracy(w))
  end
  game.push(Over, {play = self, winner = winner, name = w.name, t1 = t1, t2 = t2, cpuLost = cpuLost,
                   records = records})
end

-- ---------------------------------------------------------------- play drawing
function Play:draw()
  drawSky(self.wind, self.dt)
  local sx, sy = 0, 0
  if self.shake > 0 then sx, sy = (random() - 0.5) * self.shake, (random() - 0.5) * self.shake end
  G.push(sx, sy)
  drawTerrain()
  -- trails: the other player's last shot faintly, the current one brighter
  for i = 1, 2 do
    local tr = self.trails[i]
    if #tr >= 4 then
      local mine = i == self.cur
      local r, g, b = game.rgba(self.tanks[i].body)
      G.color(r, g, b, mine and 200 or 90)
      G.lines(tr, mine and 1.5 or 1)
    end
  end
  for i = 1, 2 do
    drawTank(self.tanks[i], self.state == "aim" and i == self.cur, self.time)
  end
  -- aiming guide: a short dotted line in the barrel direction, its length shows the power
  if self.state == "aim" then
    local t = self.tanks[self.cur]
    local a = rad(t.angle)
    local len = 14 + t.power * 0.45
    G.color(255, 255, 255, 170)
    for d = 16, len, 6 do G.circle(t.x + cos(a) * d, t.y - 8 - sin(a) * d, 1.2) end
    if self.dragging then
      local p = I.pointer
      G.color(255, 255, 255, 60)
      G.line(t.x, t.y - 8, p.x, p.y, 1)
    end
  end
  self.smoke:draw()
  if self.state == "flight" then
    local s = self.shot
    if s.y < 0 then
      -- above the screen: a marker at the top edge
      G.polyT(ARROW, max(4, min(W - 4, s.x)), 30, -pi / 2, 1, 1, "#FFFFFFC0")
    else
      G.circle(s.x, s.y, 2.6, "#202020")
      G.circle(s.x - 0.7, s.y - 0.7, 1, "#FFFFFF")
    end
  end
  self.dirt:draw()
  self.boom:draw()
  for i = 1, #self.popups do
    local p = self.popups[i]
    if p.t > 0 then
      G.alpha(min(1, p.t * 2))
      U.text(p.text, p.x - 60, p.y, p.size, p.color, "center", 120)
      G.unalpha()
    end
  end
  G.pop()
end

local function drawPlayerPanel(t, x, alignRight, active)
  local w = 150
  U.panel(x, 4, w, 26, 6, active and "#000000A0" or "#00000060")
  local al = alignRight and "right" or "left"
  U.text(t.name, x + 6, 6, 9, t.body, al, w - 12, "bold")
  U.bar(x + 6, 19, w - 50, 6, t.hp / 100, t.hp > 35 and "#4CD964" or "#FF5A5A")
  U.text(tostring(floor(t.hp)), x + w - 44, 16, 9, "#FFFFFF", "left", 20, "semibold")
  -- round wins
  for k = 1, WINS_NEEDED do
    local cx = x + w - 22 + (k - 1) * 7
    if k <= t.wins then G.circle(cx, 21, 2.6, "#FFE066") else G.circleLine(cx, 21, 2.6, 1) end
  end
end

function Play:ui()
  local t1, t2 = self.tanks[1], self.tanks[2]
  drawPlayerPanel(t1, 4, false, self.cur == 1)
  drawPlayerPanel(t2, W - 154, true, self.cur == 2)
  -- wind in the middle
  local cx = W / 2
  U.panel(cx - 56, 4, 112, 26, 6, "#00000070")
  if self.wind == 0 then
    U.text(TR("calm"), cx - 56, 11, 10, "#FFFFFF", "center", 112, "semibold")
  else
    U.text(TR("wind", abs(self.wind)), cx - 56, 6, 8, "#FFFFFFD0", "center", 112, "semibold")
    local dir = self.wind > 0 and 1 or -1
    local len = 6 + abs(self.wind) * 3.2
    G.color("#9FE3FF")
    G.line(cx - dir * len, 22, cx + dir * len, 22, 2)
    G.polyT(ARROW, cx + dir * len, 22, dir > 0 and 0 or pi, 0.9, 0.9, "#9FE3FF")
  end
  U.text(TR("round_short", self.round), cx - 56, 32, 8, "#FFFFFFC0", "center", 112, "semibold")
  -- round banner
  local b = self.banner
  if b.a > 0.01 then
    G.alpha(min(1, b.a))
    local sz = 24 * b.s
    U.panel(W / 2 - 150 * b.s, 86 - 4 * b.s, 300 * b.s, sz + 14 * b.s, 10, "#00000080")
    U.text(b.text, 0, 90 + (24 - sz) / 2 - 2, sz, "#FFFFFF", "center", W, "bold")
    G.unalpha()
  end

  -- bottom strip: angle/power, hints, buttons
  U.panel(0, H - 26, W, 26, 0, "#00000088")
  local t = self.tanks[self.cur]
  local myTurn = self.state == "aim" and not t.cpu and game.current() == self
  local shown = math.floor(t.angle + 0.5)
  if shown > 90 then shown = 180 - shown end   -- elevation above the horizon, whichever way the tank faces
  U.text(TR("aim_info", t.name, shown, floor(t.power + 0.5)), 6, H - 24, 9, t.body, "left", 300, "bold")
  local hint
  if self.state == "aim" and t.cpu then hint = TR("cpu_thinking")
  elseif self.state == "aim" then hint = TR("hint")
  else hint = TR("hint_wait") end
  local hsz = min(7, 7 * 360 / max(1, G.textWidth(hint, 7, "semibold")))
  U.text(hint, 6, H - 12, hsz, "#FFFFFFB0", "left", 380, "semibold")
  if game.current() == self then
    if U.button(TR("fire"), FIRE_BTN.x, FIRE_BTN.y, FIRE_BTN.w, FIRE_BTN.h, false, "#E04848") and myTurn then
      self.fireReq = true
    end
    if U.button("", PAUSE_BTN.x, PAUSE_BTN.y, PAUSE_BTN.w, PAUSE_BTN.h) then self.pauseReq = true end
    G.icon("pause", PAUSE_BTN.x + PAUSE_BTN.w / 2, PAUSE_BTN.y + PAUSE_BTN.h / 2, 14, "#FFFFFF")
  end
end

-- ---------------------------------------------------------------- match over
-- panel slides in, confetti and a fanfare for the winner, stats per player, "new best" lines
function Over:enter(p)
  self.p = p
  self.t = 0
  self.panel = {y = -200}
  game.tween.to(self.panel, 0.6, {y = (H - 196) / 2}, "outBack")
  self.confetti = game.emitter{max = 220, life = {1.4, 2.6}, speed = {40, 140}, angle = pi / 2, spread = 1.2,
    gravity = 90, damping = 0.6, size = {3, 2}, shape = "square",
    colors = {"#FFE066", "#FF5A5A", "#4FA3FF", "#4CD964", "#C77DFF"}}
  self.burst = 0
  if p.cpuLost then
    A.play("lose")
    chord(CH_LOSE, 0.8, 0.07)
  else
    fanfare()
    for k = 1, 6 do self.confetti:emit(14, random() * W, -6) end
    if #p.records > 0 then game.tween.after(0.7, function() A.play("power"); chord(CH_WIN2, 0.5, 0.06) end) end
  end
  self.menu = U.menu{width = 180, itemHeight = 28, size = 13, items = {
    {label = function() return TR("rematch") end, action = function() game.pop(); p.play:startMatch() end},
    {label = function() return TR("main_menu") end, action = function() game.switch(Title) end},
  }}
end
function Over:update(dt)
  self.t = self.t + dt
  self.menu:update()
  self.confetti:update(dt)
  -- keep the confetti coming for a few seconds after a win
  if not self.p.cpuLost and self.t < 3.5 then
    self.burst = self.burst - dt
    if self.burst <= 0 then self.burst = 0.18; self.confetti:emit(5, random() * W, -6) end
  end
end
function Over:ui()
  local p = self.p
  G.rect(0, 0, W, H, 0, "#00000080")
  self.confetti:draw()
  local w, h = 300, 196
  local x, y = (W - w) / 2, self.panel.y
  U.panel(x, y, w, h, 12, "#141A28EE")
  local title = p.cpuLost and TR("cpu_wins") or TR("match_won", p.name)
  local pulse = 1 + sin(self.t * 5) * 0.04
  U.text(title, x, y + 10, 16 * pulse, p.cpuLost and "#FF6B6B" or "#FFE066", "center", w, "bold")
  U.score(p.t1.wins, x + w / 2 - 14, y + 34, 3, P_COLORS[1].body, 0, "right")
  U.pixelText("-", x + w / 2 - 5, y + 34, 3, "#FFFFFF")
  U.score(p.t2.wins, x + w / 2 + 14, y + 34, 3, P_COLORS[2].body, 0, "left")
  -- stats table
  local ty = y + 56
  local c0, c1, c2 = x + 14, x + 150, x + 226
  U.text(p.t1.name, c1 - 30, ty, 8, P_COLORS[1].body, "center", 60, "bold")
  U.text(p.t2.name, c2 - 30, ty, 8, P_COLORS[2].body, "center", 60, "bold")
  local rows = {{"st_shots", "shots"}, {"st_acc", nil}, {"st_direct", "direct"}, {"st_damage", "dealt"}}
  for r = 1, #rows do
    local ry = ty + 11 * r
    local row = rows[r]
    local v1 = row[2] and tostring(p.t1[row[2]]) or (accuracy(p.t1) .. "%")
    local v2 = row[2] and tostring(p.t2[row[2]]) or (accuracy(p.t2) .. "%")
    U.text(TR(row[1]), c0, ry, 8, "#FFFFFFB0", "left", 120, "semibold")
    U.text(v1, c1 - 30, ry, 8, "#FFFFFF", "center", 60, "semibold")
    U.text(v2, c2 - 30, ry, 8, "#FFFFFF", "center", 60, "semibold")
  end
  local ry = ty + 50
  for k = 1, #p.records do
    local glow = 0.75 + sin(self.t * 8) * 0.25
    G.alpha(glow)
    U.text(p.records[k], x, ry, 9, "#7CFFB2", "center", w, "bold")
    G.unalpha()
    ry = ry + 11
  end
  self.menu:draw(W / 2, y + h - 62)
end

-- ---------------------------------------------------------------- run
return game.run{
  width = W, height = H, scale = "fit",
  scene = Title, title = Title,
  background = "#5DA9E9", border = "#10141C",
  load = rebuildSurface,
  menu = function()
    return {{title = TR("game_menu"), items = {
      {label = TR("pause_menu"), id = 1, shortcut = "Esc"},
      {label = TR("new_match"), id = 2},
      {label = TR("main_menu"), id = 3},
      "-",
      {label = TR("reset_records"), id = 4},
    }}}
  end,
  onmenu = function(id)
    if id == 1 then game.pause()
    elseif id == 2 then
      if game.current() == Play then Play:startMatch() end
    elseif id == 3 then game.switch(Title)
    elseif id == 4 then
      local d = save:get("diff", 2)
      save:reset()
      save:set("diff", d)
      U.toast(TR("records_reset"))
    end
  end,
}
