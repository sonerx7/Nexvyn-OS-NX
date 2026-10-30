-- Kule Savunması / Tower Defense, built with the nexvyn.game engine.
-- A fixed path across a grid, three tower types (rapid gun, splash cannon, slowing frost) with two upgrades each,
-- selling, money and lives, 15 waves (normal, fast, armoured enemies and a boss on the last wave), a 2x speed
-- switch and a saved best result. Enemies, shells, rings and popups live in pre-allocated pools, so a wave does
-- not create garbage and the game keeps 60 fps.

local game = require("nexvyn.game")

local G, I, U, A = game.gfx, game.input, game.ui, game.audio
local floor, sqrt, sin, cos, abs, min, max, random, pi = math.floor, math.sqrt, math.sin, math.cos, math.abs,
  math.min, math.max, math.random, math.pi
local atan = math.atan

local W, H = 480, 270
local CELL, COLS, ROWS = 19, 20, 12
local GX, GY = 4, 28                       -- grid origin
local GW, GH = COLS * CELL, ROWS * CELL    -- 380 x 228
local PX, PW = GX + GW + 4, W - (GX + GW + 4) - 4   -- right panel
local START_MONEY, START_LIVES, LAST_WAVE = 150, 20, 15
local MAX_ENEMIES, MAX_SHOTS, MAX_RINGS, MAX_POPS = 96, 128, 32, 16

local save = game.save.open("towerdefense")

-- ---------------------------------------------------------------- data
-- Towers: cost, upgrade costs and three levels of stats. rate = seconds between shots.
local TOWERS = {
  {key = "gun", color = "#4FA3FF", icon = "gps_fixed", cost = 50, up = {40, 75}, shot = 360,
   lv = {{dmg = 6, rate = 0.3, range = 54}, {dmg = 9, rate = 0.26, range = 58}, {dmg = 15, rate = 0.2, range = 64}}},
  {key = "cannon", color = "#FF9F43", icon = "local_fire_department", cost = 80, up = {65, 110}, shot = 170,
   lv = {{dmg = 20, rate = 1.4, range = 62, splash = 22}, {dmg = 36, rate = 1.25, range = 68, splash = 26},
         {dmg = 60, rate = 1.1, range = 74, splash = 30}}},
  {key = "frost", color = "#7FE7FF", icon = "ac_unit", cost = 60, up = {50, 90}, shot = 230,
   lv = {{dmg = 2, rate = 0.9, range = 48, slow = 0.4, slowT = 1.5}, {dmg = 4, rate = 0.8, range = 54, slow = 0.5,
         slowT = 2}, {dmg = 7, rate = 0.7, range = 60, slow = 0.6, slowT = 2.5, splash = 18}}},
}
local function towerName(k)
  if k == 1 then return TR("t_gun") elseif k == 2 then return TR("t_cannon") end
  return TR("t_frost")
end

local ENEMIES = {
  normal = {hp = 30, speed = 30, armor = 0, reward = 4, r = 5, color = "#FF6B6B", lives = 1},
  fast = {hp = 18, speed = 56, armor = 0, reward = 5, r = 4, color = "#FFD84D", lives = 1},
  armored = {hp = 70, speed = 22, armor = 3, reward = 9, r = 6, color = "#9AA5B1", lives = 2},
  boss = {hp = 2000, speed = 14, armor = 5, reward = 150, r = 10, color = "#B45CFF", lives = 10},
}

-- each wave: groups of {kind, count, seconds between spawns}
local WAVES = {
  {{"normal", 8, 0.9}},
  {{"normal", 12, 0.75}},
  {{"normal", 8, 0.8}, {"fast", 6, 0.5}},
  {{"fast", 14, 0.45}},
  {{"normal", 10, 0.7}, {"armored", 4, 1.4}},
  {{"armored", 8, 1.1}, {"fast", 8, 0.4}},
  {{"normal", 16, 0.5}, {"armored", 6, 1.0}},
  {{"fast", 20, 0.35}},
  {{"armored", 12, 0.9}, {"normal", 10, 0.5}},
  {{"armored", 6, 1.0}, {"fast", 14, 0.35}, {"armored", 6, 1.0}},
  {{"normal", 20, 0.4}, {"armored", 10, 0.8}},
  {{"fast", 24, 0.3}, {"armored", 8, 0.8}},
  {{"armored", 18, 0.7}},
  {{"fast", 20, 0.3}, {"armored", 14, 0.6}, {"normal", 16, 0.35}},
  {{"armored", 8, 0.8}, {"boss", 1, 2.5}, {"fast", 16, 0.35}},
}

-- ---------------------------------------------------------------- map
-- path through the grid as cell waypoints (column, row); the first and last lie just outside the grid
local PATH_WP = {{-1, 2}, {4, 2}, {4, 8}, {9, 8}, {9, 3}, {14, 3}, {14, 9}, {20, 9}}
local wpx, wpy = {}, {}
local cellPath = {}    -- [c + r * COLS + 1] = true for path cells
local pathCells = {}   -- flat {x, y, ...} of path cell origins for drawing

for i, p in ipairs(PATH_WP) do
  wpx[i], wpy[i] = GX + (p[1] + 0.5) * CELL, GY + (p[2] + 0.5) * CELL
end
wpx[1], wpx[#wpx] = GX - 10, GX + GW + 10
for i = 1, #PATH_WP - 1 do
  local a, b = PATH_WP[i], PATH_WP[i + 1]
  local dc = b[1] > a[1] and 1 or (b[1] < a[1] and -1 or 0)
  local dr = b[2] > a[2] and 1 or (b[2] < a[2] and -1 or 0)
  local c, r = a[1], a[2]
  while true do
    if c >= 0 and c < COLS and r >= 0 and r < ROWS and not cellPath[c + r * COLS + 1] then
      cellPath[c + r * COLS + 1] = true
      pathCells[#pathCells + 1] = GX + c * CELL
      pathCells[#pathCells + 1] = GY + r * CELL
    end
    if c == b[1] and r == b[2] then break end
    c, r = c + dc, r + dr
  end
end

local function isPath(c, r) return cellPath[c + r * COLS + 1] == true end

-- decorative grass tufts and stones (precomputed once)
local deco = {}
for i = 1, 26 do
  local c, r = random(0, COLS - 1), random(0, ROWS - 1)
  if not isPath(c, r) then
    deco[#deco + 1] = {x = GX + c * CELL + 4 + random() * 11, y = GY + r * CELL + 4 + random() * 11,
                       stone = random() < 0.4}
  end
end

local function drawMap(t)
  G.rect(GX, GY, GW, GH, 4, "#3E7D3A")
  G.color(255, 255, 255, 10)
  for r = 0, ROWS - 1 do
    for c = (r % 2), COLS - 1, 2 do G.rect(GX + c * CELL, GY + r * CELL, CELL, CELL) end
  end
  for i = 1, #deco do
    local d = deco[i]
    if d.stone then G.circle(d.x, d.y, 2, "#8C9A86") else
      G.color("#5FA352")
      G.line(d.x, d.y, d.x - 1.5, d.y - 3, 1)
      G.line(d.x, d.y, d.x + 1.5, d.y - 3, 1)
    end
  end
  for i = 1, #pathCells, 2 do G.rect(pathCells[i], pathCells[i + 1], CELL, CELL, 0, "#C9A46A") end
  -- path centre line: little arrows marching along the route
  G.color(150, 110, 60, 140)
  local off = (t * 18) % 12
  for i = 1, #wpx - 1 do
    local x1, y1, x2, y2 = wpx[i], wpy[i], wpx[i + 1], wpy[i + 1]
    local dx, dy = x2 - x1, y2 - y1
    local len = sqrt(dx * dx + dy * dy)
    if len > 0 then
      local ux, uy = dx / len, dy / len
      for d = off, len, 12 do G.circle(x1 + ux * d, y1 + uy * d, 1.1) end
    end
  end
end

-- ---------------------------------------------------------------- sounds
A.define("gun", {wave = "square", volume = 0.03, notes = {{1300, 0.02}, {900, 0.02}}})
A.define("cannon", {wave = "noise", volume = 0.18, notes = {{90, 0.18}}})
A.define("frost", {wave = "triangle", volume = 0.08, notes = {{1800, 0.04}, {2400, 0.06}}})
A.define("kill", {wave = "square", volume = 0.06, notes = {{520, 0.03}, {780, 0.05}}})
A.define("build", {wave = "triangle", volume = 0.2, notes = "C5:0.05 G5:0.08"})
A.define("upgrade", {wave = "triangle", volume = 0.2, notes = "C5:0.05 E5:0.05 G5:0.05 C6:0.12"})
A.define("sell", {wave = "square", volume = 0.1, notes = "E6:0.04 C6:0.08"})
A.define("leak", {wave = "saw", volume = 0.2, notes = {{300, 0.08}, {160, 0.22}}})
A.define("deny", {wave = "square", volume = 0.1, notes = {{140, 0.12}}})
A.define("move", {wave = "square", volume = 0.025, notes = {{700, 0.015}}})
A.define("bossdie", {wave = "noise", volume = 0.45, notes = {{55, 0.6}}})

local function chord(notes, secs, vol, wave)
  if A.muted then return end
  for i = 1, #notes do audio.tone(A.freq(notes[i]), secs, vol, wave or "triangle") end
end
local CH_WAVE, CH_CLEAR, CH_WIN, CH_LOSE = {"G4", "C5", "E5"}, {"C5", "E5", "G5"}, {"F5", "A5", "C6"},
  {"A3", "C4", "Eb4"}

-- ---------------------------------------------------------------- simulation
-- One Sim holds a board: towers, enemy/shot/ring/popup pools and particle emitters. The title screen runs a demo
-- Sim in the background; the Play scene runs the real one.
local Sim = {}
Sim.__index = Sim

local function newSim(demo)
  local s = setmetatable({demo = demo}, Sim)
  s.enemies, s.shots, s.rings, s.pops = {}, {}, {}, {}
  for i = 1, MAX_ENEMIES do
    s.enemies[i] = {active = false, x = 0, y = 0, hp = 0, maxhp = 1, gen = 0, seg = 2, prog = 0, slowT = 0, slowF = 0,
                    flash = 0, dir = 0, def = ENEMIES.normal, kind = "normal"}
  end
  for i = 1, MAX_SHOTS do
    s.shots[i] = {active = false, kind = 1, x = 0, y = 0, tx = 0, ty = 0, target = nil, gen = 0, speed = 0, lv = nil}
  end
  for i = 1, MAX_RINGS do s.rings[i] = {t = 0, dur = 1, x = 0, y = 0, r = 0, color = "#FFFFFF"} end
  for i = 1, MAX_POPS do s.pops[i] = {t = 0, x = 0, y = 0, text = "", color = "#FFFFFF"} end
  s.boom = game.emitter{max = 200, life = {0.2, 0.6}, speed = {30, 140}, size = {3, 0}, damping = 3,
    colors = {"#FFFFFF", "#FFC94D", "#FF5A2000"}}
  s.spark = game.emitter{max = 120, life = {0.1, 0.25}, speed = {60, 160}, size = {2, 1}, shape = "line",
    lineScale = 0.05, colors = {"#FFFFFF", "#7FC8FF00"}}
  s.ice = game.emitter{max = 120, life = {0.3, 0.7}, speed = {10, 60}, size = {2.5, 0}, shape = "square",
    colors = {"#FFFFFF", "#7FE7FF00"}}
  s.death = {}
  for k, d in pairs(ENEMIES) do
    s.death[k] = game.emitter{max = 140, life = {0.3, 0.8}, speed = {30, 130}, size = {3, 0}, damping = 2.5,
      shape = "square", colors = {"#FFFFFF", d.color, d.color .. "00"}}
  end
  s:reset()
  return s
end

function Sim:reset()
  for i = 1, MAX_ENEMIES do self.enemies[i].active = false end
  for i = 1, MAX_SHOTS do self.shots[i].active = false end
  for i = 1, MAX_RINGS do self.rings[i].t = 0 end
  for i = 1, MAX_POPS do self.pops[i].t = 0 end
  self.boom:clear(); self.spark:clear(); self.ice:clear()
  for _, e in pairs(self.death) do e:clear() end
  self.towers, self.towerAt = {}, {}
  self.alive, self.gen, self.time, self.shake = 0, 0, 0, 0
  self.sfxT = {gun = 0, cannon = 0, frost = 0, kill = 0}
end

-- a sound at most every `gap` seconds (dozens of towers would otherwise flood the mixer)
function Sim:sfx(name, gap)
  if self.demo then return end
  local t = self.sfxT[name] or 0
  if self.time - t < gap then return end
  self.sfxT[name] = self.time
  A.play(name)
end

function Sim:popup(x, y, text, color)
  local best = self.pops[1]
  for i = 1, MAX_POPS do
    local p = self.pops[i]
    if p.t <= 0 then best = p; break end
    if p.t < best.t then best = p end
  end
  best.x, best.y, best.text, best.color, best.t = x, y, text, color or "#FFE066", 0.9
end

function Sim:ring(x, y, r, color, dur)
  for i = 1, MAX_RINGS do
    local g = self.rings[i]
    if g.t <= 0 then g.x, g.y, g.r, g.color, g.dur, g.t = x, y, r, color, dur or 0.35, dur or 0.35; return end
  end
end

function Sim:spawn(kind, hpMul)
  for i = 1, MAX_ENEMIES do
    local e = self.enemies[i]
    if not e.active then
      local d = ENEMIES[kind] or ENEMIES.normal
      self.gen = self.gen + 1
      e.active, e.kind, e.def, e.gen = true, kind, d, self.gen
      e.maxhp = floor(d.hp * (hpMul or 1))
      e.hp = e.maxhp
      e.x, e.y, e.seg, e.prog = wpx[1], wpy[1] + (random() - 0.5) * 4, 2, 0
      e.slowT, e.slowF, e.flash, e.dir = 0, 0, 0, 0
      self.alive = self.alive + 1
      return true
    end
  end
  return false   -- pool full: the caller keeps it queued
end

function Sim:build(c, r, k)
  local def = TOWERS[k]
  local t = {kind = k, def = def, lvl = 1, c = c, r = r, x = GX + (c + 0.5) * CELL, y = GY + (r + 0.5) * CELL,
             cd = 0.2, angle = -pi / 2, spent = def.cost, recoil = 0, pop = 0}
  self.towers[#self.towers + 1] = t
  self.towerAt[c + r * COLS + 1] = t
  game.tween.to(t, 0.35, {pop = 1}, "outBack")
  self.ring(self, t.x, t.y, 14, def.color, 0.4)
  self.ice:emit(8, t.x, t.y)
  return t
end

function Sim:removeTower(t)
  self.towerAt[t.c + t.r * COLS + 1] = nil
  for i = #self.towers, 1, -1 do if self.towers[i] == t then table.remove(self.towers, i) end end
end

function Sim:kill(e)
  e.active = false
  self.alive = self.alive - 1
  local em = self.death[e.kind]
  if em then em:emit(e.kind == "boss" and 60 or 12, e.x, e.y) end
  if e.kind == "boss" then
    self.shake = 8
    if not self.demo then A.play("bossdie"); chord(CH_WIN, 0.5, 0.06) end
  else
    self:sfx("kill", 0.05)
  end
  if self.onKill then self.onKill(e) end
end

function Sim:hurt(e, dmg, pierce)
  if not e.active then return end
  local armor = e.def.armor * (pierce or 1)
  e.hp = e.hp - max(1, dmg - armor)
  e.flash = 0.08
  if e.hp <= 0 then self:kill(e) end
end

-- damages everything within radius of (x, y); frost also slows
function Sim:area(x, y, radius, dmg, pierce, slow, slowT)
  local r2 = radius * radius
  for i = 1, MAX_ENEMIES do
    local e = self.enemies[i]
    if e.active then
      local dx, dy = e.x - x, e.y - y
      if dx * dx + dy * dy <= r2 then
        if slow then e.slowF, e.slowT = max(e.slowT > 0 and e.slowF or 0, slow), slowT end
        self:hurt(e, dmg, pierce)
      end
    end
  end
end

function Sim:fire(t, e)
  local lv = t.def.lv[t.lvl]
  for i = 1, MAX_SHOTS do
    local s = self.shots[i]
    if not s.active then
      s.active, s.kind, s.lv = true, t.kind, lv
      s.x, s.y = t.x + cos(t.angle) * 7, t.y + sin(t.angle) * 7
      s.tx, s.ty, s.target, s.gen, s.speed = e.x, e.y, e, e.gen, t.def.shot
      break
    end
  end
  t.recoil = 1
  if t.kind == 1 then self:sfx("gun", 0.06); self.spark:emit(2, t.x + cos(t.angle) * 8, t.y + sin(t.angle) * 8, t.angle)
  elseif t.kind == 2 then self:sfx("cannon", 0.12)
  else self:sfx("frost", 0.1) end
end

function Sim:step(dt)
  self.time = self.time + dt
  self.shake = max(0, self.shake - dt * 16)
  -- enemies walk along the path
  local n = #wpx
  for i = 1, MAX_ENEMIES do
    local e = self.enemies[i]
    if e.active then
      if e.flash > 0 then e.flash = e.flash - dt end
      local f = 1
      if e.slowT > 0 then e.slowT = e.slowT - dt; f = 1 - e.slowF end
      local dist = e.def.speed * f * dt
      while dist > 0 and e.active do
        local tx, ty = wpx[e.seg], wpy[e.seg]
        local dx, dy = tx - e.x, ty - e.y
        local d = sqrt(dx * dx + dy * dy)
        if d <= dist then
          e.x, e.y, e.prog = tx, ty, e.prog + d
          dist = dist - d
          e.seg = e.seg + 1
          if e.seg > n then
            e.active = false
            self.alive = self.alive - 1
            if self.onLeak then self.onLeak(e) end
          end
        else
          e.x, e.y, e.prog = e.x + dx / d * dist, e.y + dy / d * dist, e.prog + dist
          e.dir = atan(dy, dx)
          dist = 0
        end
      end
    end
  end
  -- towers: aim at the enemy furthest along the path inside the range
  for ti = 1, #self.towers do
    local t = self.towers[ti]
    t.cd = t.cd - dt
    if t.recoil > 0 then t.recoil = max(0, t.recoil - dt * 6) end
    if t.cd <= 0 then
      local lv = t.def.lv[t.lvl]
      local r2 = lv.range * lv.range
      local best, bp = nil, -1
      for i = 1, MAX_ENEMIES do
        local e = self.enemies[i]
        if e.active and e.prog > bp then
          local dx, dy = e.x - t.x, e.y - t.y
          if dx * dx + dy * dy <= r2 then best, bp = e, e.prog end
        end
      end
      if best then
        t.angle = atan(best.y - t.y, best.x - t.x)
        t.cd = lv.rate
        self:fire(t, best)
      else
        t.cd = 0.1   -- look again soon
      end
    end
  end
  -- shots fly to their target (or to where it was when it died)
  for i = 1, MAX_SHOTS do
    local s = self.shots[i]
    if s.active then
      local e = s.target
      if e and e.active and e.gen == s.gen then s.tx, s.ty = e.x, e.y else s.target = nil end
      local dx, dy = s.tx - s.x, s.ty - s.y
      local d = sqrt(dx * dx + dy * dy)
      local step = s.speed * dt
      if d <= step + 2 then
        s.active = false
        local lv = s.lv
        if s.kind == 1 then
          if s.target then self:hurt(s.target, lv.dmg) ; self.spark:emit(3, s.tx, s.ty) end
        elseif s.kind == 2 then
          self:area(s.tx, s.ty, lv.splash, lv.dmg, 0.5)
          self.boom:emit(14, s.tx, s.ty)
          self:ring(s.tx, s.ty, lv.splash, "#FFC94D", 0.3)
          self.shake = max(self.shake, 1.5)
        else
          if lv.splash then
            self:area(s.tx, s.ty, lv.splash, lv.dmg, 1, lv.slow, lv.slowT)
            self:ring(s.tx, s.ty, lv.splash, "#7FE7FF", 0.4)
          elseif s.target then
            local t = s.target
            t.slowF, t.slowT = max(t.slowT > 0 and t.slowF or 0, lv.slow), lv.slowT
            self:hurt(t, lv.dmg)
          end
          self.ice:emit(6, s.tx, s.ty)
        end
      else
        s.x, s.y = s.x + dx / d * step, s.y + dy / d * step
      end
    end
  end
  for i = 1, MAX_RINGS do local g = self.rings[i]; if g.t > 0 then g.t = g.t - dt end end
  for i = 1, MAX_POPS do local p = self.pops[i]; if p.t > 0 then p.t = p.t - dt; p.y = p.y - 16 * dt end end
  self.boom:update(dt); self.spark:update(dt); self.ice:update(dt)
  for _, em in pairs(self.death) do em:update(dt) end
end

-- shapes (local points)
local TRI = {6, 0, -4, -4.5, -4, 4.5}
local HEX = {}
for i = 0, 5 do HEX[#HEX + 1] = cos(i * pi / 3) * 10; HEX[#HEX + 1] = sin(i * pi / 3) * 10 end
local DIAMOND = {0, -6, 4.5, 0, 0, 6, -4.5, 0}

local function drawTower(t, time)
  local s = t.pop
  if s <= 0.01 then return end
  local col = t.def.color
  G.rect(t.x - 8 * s, t.y - 8 * s, 16 * s, 16 * s, 4 * s, "#25303F")
  G.color(col)
  G.rectLine(t.x - 8 * s, t.y - 8 * s, 16 * s, 16 * s, 4 * s, 1)
  local a = t.angle
  local ca, sa = cos(a), sin(a)
  local back = t.recoil * 2
  if t.kind == 1 then
    -- twin barrels
    local px, py = -sa * 2, ca * 2
    G.color("#D8E6F5")
    G.line(t.x + px - ca * back, t.y + py - sa * back, t.x + px + ca * (9 - back), t.y + py + sa * (9 - back), 1.6)
    G.line(t.x - px - ca * back, t.y - py - sa * back, t.x - px + ca * (9 - back), t.y - py + sa * (9 - back), 1.6)
    G.circle(t.x, t.y, 4.5 * s, col)
  elseif t.kind == 2 then
    G.color("#3A3A3A")
    G.line(t.x - ca * back, t.y - sa * back, t.x + ca * (9 - back), t.y + sa * (9 - back), 4.5)
    G.circle(t.x, t.y, 5.5 * s, col)
  else
    G.polyT(DIAMOND, t.x, t.y, time * 1.5, s, s, col)
    G.color(255, 255, 255, 160)
    G.linesT(DIAMOND, t.x, t.y, time * 1.5, s * 0.55, s * 0.55, 1, true)
  end
  -- level pips
  for k = 1, t.lvl do G.circle(t.x - 6 + (k - 1) * 4, t.y + 6.5, 1.3, "#FFE066") end
end

function Sim:draw()
  local t = self.time
  for i = 1, #self.towers do drawTower(self.towers[i], t) end
  for i = 1, MAX_ENEMIES do
    local e = self.enemies[i]
    if e.active then
      local d = e.def
      local col = e.flash > 0 and "#FFFFFF" or d.color
      local bob = sin(t * 10 + e.gen) * 0.6
      G.circle(e.x + 1, e.y + 2, d.r, "#00000040")
      if e.kind == "fast" then
        G.polyT(TRI, e.x, e.y + bob, e.dir, 1, 1, col)
      elseif e.kind == "armored" then
        G.rect(e.x - d.r, e.y - d.r + bob, d.r * 2, d.r * 2, 2, col)
        G.color("#5A6470")
        G.rectLine(e.x - d.r, e.y - d.r + bob, d.r * 2, d.r * 2, 2, 1.2)
      elseif e.kind == "boss" then
        G.polyT(HEX, e.x, e.y + bob, t, 1, 1, col)
        G.icon("military_tech", e.x, e.y + bob, 11, "#FFE066")
      else
        G.circle(e.x, e.y + bob, d.r, col)
        G.circle(e.x + cos(e.dir) * 2, e.y + bob + sin(e.dir) * 2, 1.4, "#FFFFFF")
      end
      if e.slowT > 0 then
        G.color(127, 231, 255, 150)
        G.circleLine(e.x, e.y + bob, d.r + 2, 1)
      end
      if e.hp < e.maxhp then
        local w = d.r * 2 + 4
        G.rect(e.x - w / 2, e.y - d.r - 5, w, 2, 1, "#00000090")
        G.rect(e.x - w / 2, e.y - d.r - 5, w * max(0, e.hp / e.maxhp), 2, 1, "#5BE37A")
      end
    end
  end
  for i = 1, MAX_SHOTS do
    local s = self.shots[i]
    if s.active then
      if s.kind == 1 then G.circle(s.x, s.y, 1.4, "#FFF3A0")
      elseif s.kind == 2 then G.circle(s.x, s.y, 2.6, "#2A2A2A")
      else G.circle(s.x, s.y, 2, "#BFF6FF") end
    end
  end
  self.ice:draw()
  for _, em in pairs(self.death) do em:draw() end
  self.boom:draw()
  self.spark:draw()
  for i = 1, MAX_RINGS do
    local g = self.rings[i]
    if g.t > 0 then
      local k = 1 - g.t / g.dur
      local r, gg, b = game.rgba(g.color)
      G.color(r, gg, b, floor(220 * (1 - k)))
      G.circleLine(g.x, g.y, g.r * (0.4 + 0.6 * k), 1.5)
    end
  end
  for i = 1, MAX_POPS do
    local p = self.pops[i]
    if p.t > 0 then
      G.alpha(min(1, p.t * 3))
      U.text(p.text, p.x - 30, p.y, 8, p.color, "center", 60, "bold")
      G.unalpha()
    end
  end
end

-- ---------------------------------------------------------------- input
I.bind("upgrade", {pad = "x", key = "u"})
I.bind("sell", {pad = "y", key = {"x", "delete"}})
I.bind("wave", {pad = "zr", key = "n"})
I.bind("speed", {pad = "zl", key = "f"})
I.bind("prevT", {pad = "l", key = "q"})
I.bind("nextT", {pad = "r", key = "e"})

local function inside(px, py, x, y, w, h) return px >= x and py >= y and px < x + w and py < y + h end
-- a tap (touch or mouse) that started and ended inside the rectangle, this frame
local function tapped(x, y, w, h)
  local p = I.pointer
  return p.frameReleased and inside(p.x, p.y, x, y, w, h) and inside(p.downX, p.downY, x, y, w, h)
end

-- ---------------------------------------------------------------- scenes
local Title, Play, Over = {pausable = false}, {}, {transparent = true, pausable = false}
local titleSim, playSim

-- the demo board on the title screen: a few towers and an endless trickle of enemies
function Title:enter()
  self.t = 0
  if not titleSim then titleSim = newSim(true) end
  titleSim:reset()
  local spots = {{2, 4, 1}, {6, 6, 2}, {11, 5, 3}, {12, 1, 1}, {16, 7, 2}, {7, 10, 1}}
  for _, sp in ipairs(spots) do
    local t = titleSim:build(sp[1], sp[2], sp[3])
    t.lvl = random(1, 3)
  end
  self.spawnT = 0
  self.logo = {y = -50, s = 0.6}
  game.tween.to(self.logo, 0.9, {y = 34}, "outBounce")
  game.tween.to(self.logo, 0.9, {s = 1}, "outBack")
  self.menuY = {y = H + 20}
  game.tween.to(self.menuY, 0.6, {y = 92}, {ease = "outCubic", delay = 0.25})
  self.menu = U.menu{width = 200, itemHeight = 28, size = 13, items = {
    {label = function() return TR("start") end, action = function() game.switch(Play) end},
    {label = function() return TR("sound", A.muted and TR("off") or TR("on")) end,
     action = function() A.setMuted(not A.muted); game.save.open("settings"):set("muted", A.muted) end},
  }}
end

function Title:update(dt)
  self.t = self.t + dt
  self.menu:update()
  self.spawnT = self.spawnT - dt
  if self.spawnT <= 0 then
    self.spawnT = 0.9 + random() * 0.8
    titleSim:spawn(random() < 0.3 and "fast" or (random() < 0.3 and "armored" or "normal"), 1.5)
  end
  titleSim:step(dt)
end

function Title:draw()
  G.gradient(0, 0, W, H, "#1B3A2A", "#0E1F18")
  G.clip(GX, GY, GW, GH)
  drawMap(self.t)
  titleSim:draw()
  G.unclip()
  G.rect(0, 0, W, H, 0, "#00000070")
end

function Title:ui()
  local lg = self.logo
  local size = 30 * lg.s
  U.text(TR("logo"), 0, lg.y + (30 - size) / 2, size, "#FFE066", "center", W, "bold", "#3A2A00")
  local y = self.menuY.y
  self.menu:draw(W / 2, y)
  local best = save:get("best_wave", 0)
  local wins = save:get("wins", 0)
  local line = TR("best_line", best, LAST_WAVE) .. "   ·   " .. TR("wins_line", wins)
  U.panel(W / 2 - 150, y + 66, 300, 18, 9, "#00000080")
  U.text(line, 0, y + 69, 9, "#FFFFFF", "center", W, "semibold")
  local cs = TR("controls")
  local csz = min(8, 8 * (W - 16) / max(1, G.textWidth(cs, 8, "semibold")))
  U.panel(0, H - 20, W, 20, 0, "#00000090")
  U.text(cs, 0, H - 10 - csz * 0.65, csz, "#FFFFFFD0", "center", W, "semibold")
end

-- ---------------------------------------------------------------- play
local qKind, qGap = {}, {}   -- spawn queue of the running wave (reused every wave)

function Play:enter()
  if not playSim then playSim = newSim(false) end
  self.sim = playSim
  self.sim.onKill = function(e) self:onKill(e) end
  self.sim.onLeak = function(e) self:onLeak(e) end
  self.banner = {text = "", a = 0, s = 1}
  self.hud = {money = 1, lives = 1}
  self:startGame()
end

function Play:restart() self:startGame() end

function Play:startGame()
  self.sim:reset()
  self.money, self.lives, self.wave = START_MONEY, START_LIVES, 0
  self.state = "build"        -- "build" (between waves), "wave", "done"
  self.cx, self.cy, self.sel, self.rep = 6, 5, 1, 0
  self.fast = false
  self.qN, self.qI, self.spawnT = 0, 1, 0
  self.kills, self.built, self.earned, self.leaked = 0, 0, 0, 0
  self.req = nil
  self:showBanner(TR("get_ready"))
end

function Play:showBanner(text)
  local b = self.banner
  b.text, b.a, b.s = text, 0, 0.4
  if b.tw then b.tw:cancel() end
  if b.tw2 then b.tw2:cancel() end
  b.tw = game.tween.to(b, 0.4, {a = 1, s = 1}, "outBack")
  b.tw2 = game.tween.to(b, 0.4, {a = 0}, {ease = "inQuad", delay = 1.4})
end

function Play:bump(field)
  local h = self.hud
  h[field] = 1.45
  game.tween.to(h, 0.3, {[field] = 1}, "outQuad")
end

function Play:addMoney(n)
  self.money = self.money + n
  if n > 0 then self.earned = self.earned + n end
  self:bump("money")
end

function Play:onKill(e)
  self.kills = self.kills + 1
  local r = e.def.reward
  self:addMoney(r)
  self.sim:popup(e.x, e.y - 8, "+" .. r, "#FFE066")
  if e.kind == "boss" then self.sim:popup(e.x, e.y - 22, TR("boss_down"), "#E0B0FF") end
end

function Play:onLeak(e)
  if self.state == "done" then return end
  self.lives = max(0, self.lives - e.def.lives)
  self.leaked = self.leaked + 1
  self:bump("lives")
  self.sim.shake = max(self.sim.shake, 5)
  self.sim:popup(GX + GW - 24, e.y - 10, "-" .. e.def.lives, "#FF6B6B")
  A.play("leak")
  sys.vibrate(0.6, 120)
  if self.lives <= 0 then self:finish(false) end
end

function Play:startWave()
  if self.state ~= "build" or self.wave >= LAST_WAVE then return end
  self.wave = self.wave + 1
  local n = 0
  for _, grp in ipairs(WAVES[self.wave]) do
    for _ = 1, grp[2] do
      n = n + 1
      qKind[n], qGap[n] = grp[1], grp[3]
    end
  end
  self.qN, self.qI, self.spawnT = n, 1, 0.3
  self.state = "wave"
  self:showBanner(self.wave == LAST_WAVE and TR("final_wave") or TR("wave_n", self.wave))
  A.play("power")
  chord(CH_WAVE, 0.4, 0.05)
end

function Play:finish(won)
  if self.state == "done" then return end
  self.state = "done"
  local cleared = won and LAST_WAVE or max(0, self.wave - 1)
  local newBest = save:best("best_wave", cleared) and cleared > 0
  if won then
    save:inc("wins")
    if save:best("best_lives", self.lives) then newBest = true end
  end
  local stats = {won = won, wave = self.wave, cleared = cleared, kills = self.kills, built = self.built,
                 earned = self.earned, lives = self.lives, newBest = newBest}
  game.tween.after(won and 1.0 or 1.2, function() game.push(Over, stats) end)
end

-- the tower under the cursor, if any
function Play:cursorTower() return self.sim.towerAt[self.cx + self.cy * COLS + 1] end

function Play:act()
  local c, r = self.cx, self.cy
  if self:cursorTower() then return end      -- selecting is just pointing at it
  if isPath(c, r) then A.play("deny"); return end
  local def = TOWERS[self.sel]
  if self.money < def.cost then
    A.play("deny")
    self.sim:popup(GX + (c + 0.5) * CELL, GY + r * CELL, TR("no_money"), "#FF8A8A")
    return
  end
  self:addMoney(-def.cost)
  self.sim:build(c, r, self.sel)
  self.built = self.built + 1
  A.play("build")
  chord({"C5", "G5"}, 0.15, 0.04)
end

function Play:upgrade()
  local t = self:cursorTower()
  if not t then return end
  if t.lvl >= 3 then A.play("deny"); return end
  local cost = t.def.up[t.lvl]
  if self.money < cost then A.play("deny"); self.sim:popup(t.x, t.y - 12, TR("no_money"), "#FF8A8A"); return end
  self:addMoney(-cost)
  t.lvl, t.spent, t.pop = t.lvl + 1, t.spent + cost, 0.6
  game.tween.to(t, 0.35, {pop = 1}, "outBack")
  self.sim:ring(t.x, t.y, 16, "#FFE066", 0.45)
  self.sim.ice:emit(10, t.x, t.y)
  self.sim:popup(t.x, t.y - 14, TR("level_n", t.lvl), "#FFE066")
  A.play("upgrade")
end

function Play:sell()
  local t = self:cursorTower()
  if not t then return end
  local value = floor(t.spent * 0.7)
  self.sim:removeTower(t)
  self:addMoney(value)
  self.sim.boom:emit(10, t.x, t.y)
  self.sim:popup(t.x, t.y - 10, "+" .. value, "#FFE066")
  A.play("sell")
end

function Play:moveCursor(dx, dy)
  local nx, ny = max(0, min(COLS - 1, self.cx + dx)), max(0, min(ROWS - 1, self.cy + dy))
  if nx ~= self.cx or ny ~= self.cy then self.cx, self.cy = nx, ny; A.play("move") end
end

function Play:event(e)
  if e.type == "keydown" then
    if e.key == "1" then self.sel = 1 elseif e.key == "2" then self.sel = 2 elseif e.key == "3" then self.sel = 3 end
  end
end

function Play:update(dt)
  local req = self.req
  self.req = nil
  if req == "pause" then game.pause(); return end
  if self.state ~= "done" then
    -- cursor: one cell per press, then auto-repeat while held
    local pdx = (I.pressed("right") and 1 or 0) - (I.pressed("left") and 1 or 0)
    local pdy = (I.pressed("down") and 1 or 0) - (I.pressed("up") and 1 or 0)
    if pdx ~= 0 or pdy ~= 0 then
      self:moveCursor(pdx, pdy)
      self.rep = 0.3
    else
      local hdx = (I.down("right") and 1 or 0) - (I.down("left") and 1 or 0)
      local hdy = (I.down("down") and 1 or 0) - (I.down("up") and 1 or 0)
      if hdx ~= 0 or hdy ~= 0 then
        self.rep = self.rep - dt
        if self.rep <= 0 then self.rep = 0.075; self:moveCursor(hdx, hdy) end
      end
    end
    -- touch / mouse on the grid: the first tap moves the cursor, a second tap on the same cell builds
    local p = I.pointer
    if p.released and inside(p.downX, p.downY, GX, GY, GW, GH) and inside(p.x, p.y, GX, GY, GW, GH) then
      local c, r = floor((p.x - GX) / CELL), floor((p.y - GY) / CELL)
      if c == self.cx and r == self.cy then self:act() else self.cx, self.cy = c, r; A.play("move") end
    end
    if I.pressed("confirm") then self:act() end
    if I.pressed("upgrade") or req == "upgrade" then self:upgrade() end
    if I.pressed("sell") or req == "sell" then self:sell() end
    if I.pressed("prevT") then self.sel = (self.sel + 1) % 3 + 1; A.play("select") end
    if I.pressed("nextT") then self.sel = self.sel % 3 + 1; A.play("select") end
    if type(req) == "number" then self.sel = req; A.play("select") end
    if I.pressed("wave") or req == "wave" then self:startWave() end
    if I.pressed("speed") or req == "speed" then self.fast = not self.fast; A.play("select") end
  end
  -- simulation (twice per step at 2x speed)
  local steps = self.fast and 2 or 1
  for _ = 1, steps do
    if self.state == "wave" then
      if self.qI <= self.qN then
        self.spawnT = self.spawnT - dt
        if self.spawnT <= 0 then
          if self.sim:spawn(qKind[self.qI], 1 + (self.wave - 1) * 0.24) then
            self.spawnT = qGap[self.qI]
            self.qI = self.qI + 1
          end
        end
      elseif self.sim.alive <= 0 then
        -- wave cleared
        if self.wave >= LAST_WAVE then
          self:finish(true)
        else
          self.state = "build"
          local bonus = 20 + self.wave * 5
          self:addMoney(bonus)
          self:showBanner(TR("wave_clear", bonus))
          chord(CH_CLEAR, 0.4, 0.05)
          A.play("coin")
        end
      end
    end
    self.sim:step(dt)
  end
end

-- ---------------------------------------------------------------- play drawing
function Play:draw()
  G.gradient(0, 0, W, H, "#1B2A22", "#101814")
  local s = self.sim
  local sx, sy = 0, 0
  if s.shake > 0 then sx, sy = (random() - 0.5) * s.shake, (random() - 0.5) * s.shake end
  G.push(sx, sy)
  G.clip(GX, GY, GW, GH)
  drawMap(s.time)
  -- range preview under the towers
  local t = self:cursorTower()
  local cxp, cyp = GX + (self.cx + 0.5) * CELL, GY + (self.cy + 0.5) * CELL
  if t then
    local lv = t.def.lv[t.lvl]
    G.circle(t.x, t.y, lv.range, "#FFFFFF14")
    G.color(255, 255, 255, 90)
    G.circleLine(t.x, t.y, lv.range, 1)
  elseif not isPath(self.cx, self.cy) and self.state ~= "done" then
    local def = TOWERS[self.sel]
    local ok = self.money >= def.cost
    G.circle(cxp, cyp, def.lv[1].range, ok and "#FFFFFF10" or "#FF505014")
    G.color(ok and "#FFFFFF60" or "#FF6B6B80")
    G.circleLine(cxp, cyp, def.lv[1].range, 1)
  end
  s:draw()
  -- cursor
  if self.state ~= "done" then
    local pulse = 0.5 + sin(s.time * 8) * 0.5
    local bad = isPath(self.cx, self.cy)
    G.color(bad and "#FF6B6B" or "#FFFFFF")
    G.rectLine(GX + self.cx * CELL + 0.5, GY + self.cy * CELL + 0.5, CELL - 1, CELL - 1, 3, 1.2 + pulse)
    if not t and not bad then
      gfx.alpha(0.5)
      G.icon(TOWERS[self.sel].icon, cxp, cyp, 11, TOWERS[self.sel].color)
      gfx.unalpha()
    end
  end
  G.unclip()
  G.pop()
end

local function panelButton(label, x, y, w, h, color, enabled, icon)
  local p = I.pointer
  local hot = enabled and p.down and inside(p.x, p.y, x, y, w, h) and inside(p.downX, p.downY, x, y, w, h)
  G.rect(x, y, w, h, 5, enabled and (hot and "#FFFFFF" or color) or "#FFFFFF1A")
  local tc = enabled and (hot and "#000000" or "#FFFFFF") or "#FFFFFF60"
  if icon then
    G.icon(icon, x + 10, y + h / 2, 11, tc)
    U.text(label, x + 17, y + h / 2 - 5, 8.5, tc, "center", w - 19, "bold", false)
  else
    U.text(label, x, y + h / 2 - 5, 8.5, tc, "center", w, "bold", false)
  end
  return enabled and tapped(x, y, w, h)
end

function Play:ui()
  local active = game.current() == self and self.state ~= "done"
  -- top bar: lives, money, wave, speed, pause
  U.panel(0, 0, W, 25, 0, "#00000080")
  local h = self.hud
  G.icon("favorite", 14, 12.5, 13 * h.lives, "#FF5A6E")
  U.text(tostring(self.lives), 24, 6, 11 * min(1.2, h.lives), self.lives <= 5 and "#FF8A8A" or "#FFFFFF", "left", 40)
  G.icon("monetization_on", 70, 12.5, 13 * h.money, "#FFD84D")
  U.text(tostring(self.money), 80, 6, 11 * min(1.2, h.money), "#FFE9A0", "left", 60)
  U.text(TR("wave_of", self.wave, LAST_WAVE), 0, 6, 11, "#FFFFFF", "center", W, "bold")
  if self.state == "wave" then
    local left = self.qN - self.qI + 1 + self.sim.alive
    U.text(TR("enemies_left", max(0, left)), 280, 8, 8, "#FFFFFFA0", "left", 100, "semibold")
  end
  local fx = W - 74
  if panelButton(self.fast and "2x" or "1x", fx, 3, 40, 19, self.fast and "#E07A2F" or "#3A4A5A", active, "fast_forward") then
    self.req = "speed"
  end
  if panelButton("", W - 30, 3, 26, 19, "#3A4A5A", game.current() == self) then self.req = "pause" end
  G.icon("pause", W - 17, 12.5, 13, "#FFFFFF")

  -- right panel: tower palette
  local x, w = PX, PW
  U.panel(x, GY, w, GH, 6, "#00000070")
  U.text(TR("towers"), x, GY + 3, 8, "#FFFFFFA0", "center", w, "semibold")
  for k = 1, 3 do
    local def = TOWERS[k]
    local by = GY + 14 + (k - 1) * 31
    local selected = self.sel == k
    local afford = self.money >= def.cost
    G.rect(x + 3, by, w - 6, 28, 5, selected and "#FFFFFF30" or "#FFFFFF10")
    if selected then G.color(def.color); G.rectLine(x + 3, by, w - 6, 28, 5, 1.5) end
    G.icon(def.icon, x + 15, by + 14, 14, def.color)
    U.text(towerName(k), x + 26, by + 3, 8, "#FFFFFF", "left", w - 28, "bold", false)
    U.text("$" .. def.cost, x + 26, by + 15, 8, afford and "#FFE066" or "#FF8A8A", "left", w - 28, "semibold", false)
    if active and tapped(x + 3, by, w - 6, 28) then self.req = k end
  end
  -- info about the tower under the cursor (or the one about to be built)
  local iy = GY + 108
  local t = self:cursorTower()
  local def = t and t.def or TOWERS[self.sel]
  local lvl = t and t.lvl or 1
  local lv = def.lv[lvl]
  G.rect(x + 3, iy, w - 6, 57, 5, "#FFFFFF10")
  U.text(t and TR("level_of", towerName(t.kind), lvl) or TR("new_tower"), x + 6, iy + 3, 8, def.color, "left", w - 10,
         "bold", false)
  U.text(TR("st_damage", lv.dmg), x + 6, iy + 14, 7.5, "#FFFFFFD0", "left", w - 10, "semibold", false)
  U.text(TR("st_range", lv.range), x + 6, iy + 23, 7.5, "#FFFFFFD0", "left", w - 10, "semibold", false)
  U.text(TR("st_rate", string.format("%.1f", 1 / lv.rate)), x + 6, iy + 32, 7.5, "#FFFFFFD0", "left", w - 10,
         "semibold", false)
  local extra = ""
  if lv.splash and lv.slow then extra = TR("st_slow_area", floor(lv.slow * 100))
  elseif lv.splash then extra = TR("st_splash", lv.splash)
  elseif lv.slow then extra = TR("st_slow", floor(lv.slow * 100)) end
  U.text(extra, x + 6, iy + 41, 7.5, "#BFF6FF", "left", w - 10, "semibold", false)
  -- upgrade / sell
  local uy = iy + 61
  local bw = (w - 9) / 2
  local canUp = t ~= nil and t.lvl < 3
  local upLabel = canUp and ("$" .. t.def.up[t.lvl]) or TR("max")
  if panelButton(upLabel, x + 3, uy, bw, 23, "#2F8F5B", active and canUp and self.money >= t.def.up[t.lvl], "upgrade") then
    self.req = "upgrade"
  end
  local sellLabel = t and ("$" .. floor(t.spent * 0.7)) or TR("sell")
  if panelButton(sellLabel, x + 6 + bw, uy, bw, 23, "#A8483A", active and t ~= nil, "sell") then self.req = "sell" end
  -- next wave
  local ny = GY + GH - 30
  local canWave = active and self.state == "build" and self.wave < LAST_WAVE
  local waveLabel = canWave and TR("next_wave", self.wave + 1) or TR("wave_running")
  local col = canWave and (sin(self.sim.time * 5) > 0 and "#3A86FF" or "#2F6FD6") or "#3A4A5A"
  if panelButton(waveLabel, x + 3, ny, w - 6, 26, col, canWave, "play_arrow") then self.req = "wave" end

  -- hint line under the grid
  local hint = TR("hint")
  local hsz = min(7, 7 * (GW - 4) / max(1, G.textWidth(hint, 7, "semibold")))
  U.text(hint, GX, GY + GH + 3, hsz, "#FFFFFF90", "left", GW, "semibold", false)

  -- wave banner
  local b = self.banner
  if b.a > 0.01 then
    G.alpha(min(1, b.a))
    local sz = 22 * b.s
    U.panel(GX + GW / 2 - 140 * b.s, 96 - 4 * b.s, 280 * b.s, sz + 14 * b.s, 10, "#00000090")
    U.text(b.text, GX, 100 + (22 - sz) / 2 - 2, sz, "#FFFFFF", "center", GW, "bold")
    G.unalpha()
  end
end

-- ---------------------------------------------------------------- game over / victory
function Over:enter(p)
  self.p = p
  self.t = 0
  self.panel = {y = -220}
  game.tween.to(self.panel, 0.6, {y = (H - 200) / 2}, "outBack")
  self.confetti = game.emitter{max = 220, life = {1.4, 2.6}, speed = {40, 140}, angle = pi / 2, spread = 1.2,
    gravity = 90, damping = 0.6, size = {3, 2}, shape = "square",
    colors = {"#FFE066", "#FF5A5A", "#4FA3FF", "#4CD964", "#C77DFF"}}
  self.burst = 0
  self.party = p.won or p.newBest
  if p.won then
    A.play("win")
    chord(CH_CLEAR, 0.3, 0.07)
    game.tween.after(0.32, function() chord(CH_WIN, 0.7, 0.07) end)
  else
    A.play("lose")
    chord(CH_LOSE, 0.8, 0.07)
    if p.newBest then game.tween.after(0.9, function() A.play("power"); chord(CH_WIN, 0.5, 0.06) end) end
  end
  if self.party then for _ = 1, 6 do self.confetti:emit(14, random() * W, -6) end end
  self.menu = U.menu{width = 180, itemHeight = 28, size = 13, items = {
    {label = function() return TR("again") end, action = function() game.switch(Play) end},
    {label = function() return TR("main_menu") end, action = function() game.switch(Title) end},
  }}
end
function Over:update(dt)
  self.t = self.t + dt
  self.menu:update()
  self.confetti:update(dt)
  if self.party and self.t < 3.5 then
    self.burst = self.burst - dt
    if self.burst <= 0 then self.burst = 0.18; self.confetti:emit(5, random() * W, -6) end
  end
end
function Over:ui()
  local p = self.p
  G.rect(0, 0, W, H, 0, "#00000088")
  self.confetti:draw()
  local w, h = 280, 200
  local x, y = (W - w) / 2, self.panel.y
  U.panel(x, y, w, h, 12, "#141A28EE")
  local pulse = 1 + sin(self.t * 5) * 0.04
  U.text(p.won and TR("victory") or TR("defeat"), x, y + 10, 18 * pulse, p.won and "#7CFFB2" or "#FF6B6B", "center", w,
         "bold")
  U.text(p.won and TR("victory_sub", p.lives) or TR("defeat_sub", p.wave), x, y + 34, 9, "#FFFFFFC0", "center", w,
         "semibold")
  local rows = {
    {TR("st_cleared"), p.cleared .. " / " .. LAST_WAVE}, {TR("st_kills"), tostring(p.kills)},
    {TR("st_built"), tostring(p.built)}, {TR("st_earned"), "$" .. p.earned},
  }
  for r = 1, #rows do
    local ry = y + 50 + (r - 1) * 12
    U.text(rows[r][1], x + 40, ry, 8.5, "#FFFFFFB0", "left", 140, "semibold")
    U.text(rows[r][2], x + w - 120, ry, 8.5, "#FFFFFF", "right", 80, "bold")
  end
  if p.newBest then
    G.alpha(0.75 + sin(self.t * 8) * 0.25)
    U.text(TR("new_best"), x, y + 102, 11, "#FFE066", "center", w, "bold")
    G.unalpha()
  else
    U.text(TR("best_line", save:get("best_wave", 0), LAST_WAVE), x, y + 104, 8.5, "#FFFFFF90", "center", w, "semibold")
  end
  self.menu:draw(W / 2, y + h - 66)
end

-- ---------------------------------------------------------------- run
return game.run{
  width = W, height = H, scale = "fit",
  scene = Title, title = Title,
  background = "#101814", border = "#0A0F0C",
  menu = function()
    return {{title = TR("game_menu"), items = {
      {label = TR("pause_menu"), id = 1, shortcut = "Esc"},
      {label = TR("new_game"), id = 2},
      {label = TR("main_menu"), id = 3},
      "-",
      {label = TR("reset_records"), id = 4},
    }}}
  end,
  onmenu = function(id)
    if id == 1 then game.pause()
    elseif id == 2 then
      if game.current() == Play then Play:startGame() else game.switch(Play) end
    elseif id == 3 then game.switch(Title)
    elseif id == 4 then save:reset(); U.toast(TR("records_reset"))
    end
  end,
}
