-- Go Fishing: a relaxed fishing game built with the nexvyn.game engine.
-- Charge and cast, wait for a bite, hook it in time, then reel while keeping the line tension inside the moving
-- green zone: too much tension snaps the line, too little lets the fish slip away. 19 species across three spots and
-- three times of day, a collection log with best weights, coins to unlock spots and a stronger rod.

local game = require("nexvyn.game")
local G, I, U, A = game.gfx, game.input, game.ui, game.audio
local floor, min, max, abs, sin, cos, pi, random, sqrt = math.floor, math.min, math.max, math.abs, math.sin,
  math.cos, math.pi, math.random, math.sqrt

local save = game.save.open("fishing")
local BAIT = 8                       -- casts per trip

-- ---------------------------------------------------------------- input
I.bind("cast", {pad = {"a", "zr", "r"}, key = {"space", "enter", "z"}})
I.bind("reelin", {pad = {"b"}, key = {"backspace", "x"}})
I.touchControls{stick = false, pause = true}

A.define("splash", {wave = "noise", volume = 0.16, notes = {{200, 0.18}}})
A.define("plop", {wave = "sine", volume = 0.25, notes = {{620, 0.04}, {300, 0.08}}})
A.define("bite", {wave = "square", volume = 0.16, notes = "A5:0.05 E6:0.05 A6:0.1"})
A.define("nibble", {wave = "sine", volume = 0.12, notes = {{700, 0.03}}})
A.define("snap", {wave = "saw", volume = 0.22, notes = {{900, 0.03}, {300, 0.06}, {120, 0.2}}})
A.define("swoosh", {wave = "noise", volume = 0.07, notes = {{1000, 0.22}}})
A.define("buy", {wave = "triangle", volume = 0.2, notes = "E5:0.06 G5:0.06 C6:0.16"})
A.define("chirp", {wave = "sine", volume = 0.035, notes = "E7:0.04 G7:0.05 E7:0.04"})
A.define("cricket", {wave = "square", volume = 0.012, notes = "B7:0.02 -:0.03 B7:0.02 -:0.03 B7:0.02"})

-- ---------------------------------------------------------------- world data
local LOCS = {
  {id = "lake", name = "loc_lake", price = 0, w1 = "#2F8F9D", w2 = "#0F4652"},
  {id = "river", name = "loc_river", price = 150, w1 = "#3C8DB5", w2 = "#163F5C"},
  {id = "sea", name = "loc_sea", price = 400, w1 = "#1E6FB0", w2 = "#06244A"},
}
local TIMES = {
  {id = "day", name = "time_day", s1 = "#6FB8EC", s2 = "#CDEBFA", shade = nil},
  {id = "dusk", name = "time_dusk", s1 = "#3B2E6E", s2 = "#F59E6B", shade = "#40104038"},
  {id = "night", name = "time_night", s1 = "#040817", s2 = "#1B2650", shade = "#00001470"},
}
local TIME_KEYS = {any = "time_any", day = "time_day", dusk = "time_dusk", night = "time_night"}
local RODS = {{zone = 1.0, price = 0}, {zone = 1.18, price = 200}, {zone = 1.36, price = 600}}
local RARITY = {"rar_common", "rar_uncommon", "rar_rare", "rar_epic", "rar_legend"}
local RARITY_COLORS = {"#C9D2DC", "#6CE38A", "#55B6FF", "#C17BFF", "#FFC93C"}
local RARITY_WEIGHT = {60, 26, 10, 3.5, 1.2}
local RARITY_BASE = {5, 12, 30, 70, 160}

-- id, name key, spot, time ("any"/"day"/"dusk"/"night"), rarity, min/max kg, coins per kg, colours, shape:
-- h = body height / length, mark = stripes|spots|sword|whiskers|lure, long = length factor for cm
local FISH = {
  {id = "bluegill", loc = "lake", time = "any", r = 1, w0 = 0.1, w1 = 0.6, val = 10, c1 = "#5C8FD6", c2 = "#F2B33D", h = 0.62},
  {id = "perch", loc = "lake", time = "day", r = 1, w0 = 0.2, w1 = 1.5, val = 9, c1 = "#9DB83A", c2 = "#E86A2C", h = 0.45, mark = "stripes"},
  {id = "carp", loc = "lake", time = "any", r = 2, w0 = 1, w1 = 12, val = 4, c1 = "#B58A3C", c2 = "#E8CE8A", h = 0.48},
  {id = "pike", loc = "lake", time = "dusk", r = 3, w0 = 2, w1 = 14, val = 6, c1 = "#6C8F4E", c2 = "#D9E3A0", h = 0.28, mark = "spots", long = 1.3},
  {id = "catfish", loc = "lake", time = "night", r = 3, w0 = 3, w1 = 40, val = 2.5, c1 = "#4E4A44", c2 = "#A39A8A", h = 0.34, mark = "whiskers"},
  {id = "koi", loc = "lake", time = "day", r = 5, w0 = 2, w1 = 10, val = 25, c1 = "#FF8A1F", c2 = "#FFFFFF", h = 0.44, mark = "spots"},
  {id = "chub", loc = "river", time = "any", r = 1, w0 = 0.3, w1 = 2.5, val = 7, c1 = "#8E9AA6", c2 = "#D9DDE2", h = 0.38},
  {id = "trout", loc = "river", time = "day", r = 2, w0 = 0.3, w1 = 4, val = 12, c1 = "#7FA36B", c2 = "#F2A0B0", h = 0.36, mark = "spots"},
  {id = "zander", loc = "river", time = "dusk", r = 2, w0 = 1, w1 = 10, val = 7, c1 = "#9C9F7A", c2 = "#E3E4C8", h = 0.32, mark = "stripes"},
  {id = "salmon", loc = "river", time = "any", r = 3, w0 = 3, w1 = 20, val = 6, c1 = "#B6C2CC", c2 = "#F28C6B", h = 0.36},
  {id = "eel", loc = "river", time = "night", r = 4, w0 = 0.5, w1 = 5, val = 22, c1 = "#3F4A2E", c2 = "#9AA36E", h = 0.14, long = 2.2},
  {id = "sturgeon", loc = "river", time = "night", r = 5, w0 = 10, w1 = 120, val = 2.5, c1 = "#6B6F7A", c2 = "#C8CCD6", h = 0.24, mark = "whiskers", long = 1.4},
  {id = "sardine", loc = "sea", time = "any", r = 1, w0 = 0.05, w1 = 0.2, val = 40, c1 = "#4D7FA8", c2 = "#E6EEF5", h = 0.3},
  {id = "mackerel", loc = "sea", time = "day", r = 1, w0 = 0.2, w1 = 1.5, val = 9, c1 = "#3E7CB1", c2 = "#D6E9F5", h = 0.3, mark = "stripes"},
  {id = "seabass", loc = "sea", time = "any", r = 2, w0 = 0.5, w1 = 6, val = 8, c1 = "#9AA7B5", c2 = "#EEF1F4", h = 0.36},
  {id = "bluefish", loc = "sea", time = "dusk", r = 3, w0 = 1, w1 = 8, val = 9, c1 = "#2F6E9E", c2 = "#B9DCEF", h = 0.34},
  {id = "angler", loc = "sea", time = "night", r = 4, w0 = 2, w1 = 25, val = 5, c1 = "#5B4636", c2 = "#9C8268", h = 0.62, mark = "lure"},
  {id = "tuna", loc = "sea", time = "day", r = 4, w0 = 20, w1 = 250, val = 0.9, c1 = "#24476B", c2 = "#C9D6E2", h = 0.38},
  {id = "swordfish", loc = "sea", time = "any", r = 5, w0 = 50, w1 = 400, val = 0.7, c1 = "#2E4A7A", c2 = "#AFC3DE", h = 0.26, mark = "sword", long = 1.6},
}
local FISH_BY_ID = {}
for i, f in ipairs(FISH) do f.index = i; f.name = "fish_" .. f.id; FISH_BY_ID[f.id] = f end

-- ---------------------------------------------------------------- persistence
local function coins() return save:get("coins", 0) end
local function addCoins(n) save:set("coins", coins() + n) end
local function rodLevel() local r = save:get("rod", 1); if not RODS[r] then r = 1 end; return r end
local function unlocked(li)
  if li == 1 then return true end
  local u = save:get("unlocked", {})
  return type(u) == "table" and u[LOCS[li].id] == true
end
local function logOf(id)
  local log = save:get("log", {})
  if type(log) ~= "table" then return nil end
  local e = log[id]
  if type(e) ~= "table" then return nil end
  return e
end
-- records a catch; returns isNewSpecies, isNewRecord
local function logCatch(f, kg)
  local log = save:get("log", {})
  if type(log) ~= "table" then log = {} end
  local e = log[f.id]
  local new = type(e) ~= "table"
  if new then e = {n = 0, best = 0} end
  local rec = not new and kg > (e.best or 0)
  e.n = (e.n or 0) + 1
  e.best = max(e.best or 0, kg)
  log[f.id] = e
  save:set("log", log)
  return new, rec
end
local function caughtCount()
  local n = 0
  for _, f in ipairs(FISH) do if logOf(f.id) then n = n + 1 end end
  return n
end

-- ---------------------------------------------------------------- shapes
local ELL = {}
for i = 0, 17 do local a = i / 18 * 2 * pi; ELL[#ELL + 1] = cos(a); ELL[#ELL + 1] = sin(a) end
local TAIL = {0, 0, -1, -1, -1, 1}
local FIN = {-1, 0, 0.7, 0, -0.5, -1}
local TREE = {0, -1, 0.5, 0, -0.5, 0}

-- a fish drawn from shapes; face 1 = looking right, -1 = left; dark = unknown silhouette
local function drawFish(f, x, y, len, face, dark)
  local h = len * (f.h or 0.4)
  local c1 = dark and "#0E1E30" or f.c1
  local c2 = dark and "#0E1E30" or f.c2
  G.polyT(TAIL, x - face * len * 0.4, y, 0, face * len * (f.long and f.long > 2 and 0.12 or 0.26), h * 0.55, c1)
  G.polyT(FIN, x - face * len * 0.04, y - h * 0.38, 0, face * len * 0.2, h * 0.5, c1)
  G.polyT(ELL, x, y, 0, len / 2, h / 2, c1)
  G.polyT(ELL, x + face * len * 0.05, y + h * 0.16, 0, len * 0.36, h * 0.24, c2)
  if dark then return end
  local m = f.mark
  if m == "stripes" then
    gfx.color(0, 0, 0, 70)
    for i = -1, 1 do G.line(x + i * len * 0.16, y - h * 0.4, x + i * len * 0.16 - face * len * 0.04, y + h * 0.15, max(1, len * 0.04)) end
  elseif m == "spots" then
    gfx.color(0, 0, 0, 60)
    for i = 0, 4 do G.circle(x + ((i * 37) % 9 - 4) * len * 0.06, y - h * 0.12 + ((i * 53) % 5 - 2) * h * 0.08, max(0.8, len * 0.025)) end
  elseif m == "sword" then
    gfx.color(c1)
    G.line(x + face * len * 0.45, y - h * 0.05, x + face * len * 0.95, y - h * 0.08, max(1, len * 0.03))
  elseif m == "whiskers" then
    gfx.color(c1)
    G.line(x + face * len * 0.45, y + h * 0.1, x + face * len * 0.62, y + h * 0.45, max(0.8, len * 0.015))
    G.line(x + face * len * 0.45, y + h * 0.1, x + face * len * 0.66, y + h * 0.25, max(0.8, len * 0.015))
  elseif m == "lure" then
    gfx.color(c1)
    G.line(x + face * len * 0.25, y - h * 0.45, x + face * len * 0.55, y - h * 0.65, max(1, len * 0.02))
    G.circle(x + face * len * 0.55, y - h * 0.65, max(1.2, len * 0.05), "#FFE45C")
  end
  local ex, ey = x + face * len * 0.3, y - h * 0.1
  local er = max(1, h * 0.1)
  G.circle(ex, ey, er, "#FFFFFF")
  G.circle(ex + face * er * 0.25, ey, er * 0.55, "#101010")
end

-- ---------------------------------------------------------------- scenery
local stars = {}
for i = 1, 60 do stars[i] = {random(), random() * 0.45, random() * 1.2 + 0.4, random() * 6} end
local WAVE = {}          -- reused polyline buffer
for i = 1, 66 do WAVE[i] = 0 end
local LINE = {}          -- reused fishing-line buffer (9 points)
for i = 1, 18 do LINE[i] = 0 end
local BEAM = {0, 0, 0, 0, 0, 0}   -- lighthouse beam triangle

local function waterY() return floor(game.height * 0.5) end

local function drawScene(li, ti, t)
  local W, H = game.width, game.height
  local loc, tm = LOCS[li], TIMES[ti]
  local wy = waterY()
  G.gradient(0, 0, W, wy, tm.s1, tm.s2)
  -- sky lights
  if tm.id == "night" then
    for _, s in ipairs(stars) do
      local tw = 0.5 + 0.5 * sin(t * 2 + s[4])
      gfx.color(255, 255, 230, floor(80 + tw * 140))
      G.circle(s[1] * W, s[2] * wy * 2, s[3] * 0.6)
    end
    G.circle(W * 0.78, wy * 0.28, 16, "#F4F1D8")
    G.circle(W * 0.78 + 6, wy * 0.28 - 4, 14, tm.s1)
  elseif tm.id == "dusk" then
    G.circle(W * 0.7, wy - 6, 34, "#FFB067")
    G.circle(W * 0.7, wy - 6, 24, "#FFD08A")
  else
    gfx.color(255, 248, 200, 70)
    G.circle(W * 0.8, wy * 0.3, 30)
    G.circle(W * 0.8, wy * 0.3, 18, "#FFF6C8")
    -- drifting clouds
    for i = 0, 2 do
      local cx = ((t * 6 + i * 190) % (W + 160)) - 80
      local cy = wy * (0.2 + i * 0.13)
      gfx.color(255, 255, 255, 190)
      G.circle(cx, cy, 12); G.circle(cx + 14, cy - 5, 15); G.circle(cx + 30, cy, 11)
      G.rect(cx, cy, 30, 10, 5)
    end
  end
  -- far shore per spot
  if loc.id == "lake" then
    gfx.color(tm.id == "night" and "#0A1A18" or (tm.id == "dusk" and "#2D2440" or "#3E7A4A"))
    G.circle(W * 0.35, wy + 30, 70); G.circle(W * 0.75, wy + 40, 90)
    for i = 0, 11 do
      local x = W * 0.25 + i * (W * 0.06)
      G.polyT(TREE, x, wy - 4, 0, 10 + (i % 3) * 3, 26 + (i * 7) % 14, tm.id == "night" and "#071311" or (tm.id == "dusk" and "#251C36" or "#2D6038"))
    end
  elseif loc.id == "river" then
    gfx.color(tm.id == "night" and "#0B140F" or (tm.id == "dusk" and "#352A45" or "#5C8F55"))
    G.rect(0, wy - 18, W, 18, 0)
    for i = 0, 30 do
      local x = (i * 37) % W
      gfx.color(tm.id == "night" and "#122017" or (tm.id == "dusk" and "#433456" or "#78A85E"))
      G.line(x, wy - 18, x + 3, wy - 34 - (i * 13) % 10, 1.5)
    end
  else
    -- island with a lighthouse on the horizon
    gfx.color(tm.id == "night" and "#0B1222" or (tm.id == "dusk" and "#2C2342" or "#4C7A6E"))
    G.circle(W * 0.82, wy + 14, 40)
    G.rect(W * 0.82 - 4, wy - 52, 8, 30, 1, "#E8E2D6")
    G.rect(W * 0.82 - 6, wy - 58, 12, 7, 2, "#C84B3C")
    if tm.id ~= "day" then
      local a = t * 1.4
      gfx.color(255, 240, 170, 60)
      BEAM[1], BEAM[2] = W * 0.82, wy - 55
      BEAM[3], BEAM[4] = W * 0.82 + cos(a) * 90, wy - 55 + sin(a) * 6 - 8
      BEAM[5], BEAM[6] = W * 0.82 + cos(a) * 90, wy - 55 + sin(a) * 6 + 8
      G.poly(BEAM)
    end
  end
  -- water
  G.gradient(0, wy, W, H - wy, loc.w1, loc.w2)
  local flow = loc.id == "river" and 30 or (loc.id == "sea" and 10 or 4)
  local amp = loc.id == "sea" and 2.5 or 1.2
  local n = 33
  for i = 0, n - 1 do
    local x = i * W / (n - 1)
    WAVE[i * 2 + 1] = x
    WAVE[i * 2 + 2] = wy + sin(x * 0.05 + t * 1.8) * amp
  end
  gfx.color(255, 255, 255, 120)
  G.lines(WAVE, 1.5)
  -- shimmer streaks
  gfx.color(255, 255, 255, 34)
  for i = 0, 13 do
    local y = wy + 10 + (i * 29) % (H - wy - 12)
    local x = ((i * 83 + t * flow * (1 + i % 3)) % (W + 60)) - 30
    G.line(x, y, x + 18 + (i % 4) * 6, y, 1)
  end
  if tm.shade then G.rect(0, 0, W, H, 0, tm.shade) end
end

-- the dock and the angler; returns the rod tip position
local function drawDock(bend, t)
  local wy = waterY()
  local dy = wy - 8
  for i = 0, 3 do G.rect(12 + i * 24, dy, 5, 28, 1, "#4A3220") end
  G.rect(0, dy - 4, 104, 8, 2, "#8A5A34")
  gfx.color(0, 0, 0, 50)
  G.line(0, dy, 104, dy, 1)
  local fx = 58
  -- legs, body, head, hat
  G.rect(fx - 6, dy - 22, 4, 18, 1, "#2E3A5C")
  G.rect(fx + 2, dy - 22, 4, 18, 1, "#2E3A5C")
  G.rect(fx - 8, dy - 40, 16, 20, 4, "#D9573B")
  G.circle(fx, dy - 47, 7, "#F2C9A0")
  G.rect(fx - 9, dy - 54, 18, 4, 2, "#6E5326")
  G.rect(fx - 6, dy - 60, 12, 7, 3, "#8A6A33")
  -- rod: bends towards the water with the tension
  local hx, hy = fx + 8, dy - 32
  local tipX = hx + 48 - bend * 8
  local tipY = hy - 40 + bend * 26 + sin(t * 1.3) * 1
  local mx, my = (hx + tipX) / 2 + bend * 6, (hy + tipY) / 2 + bend * 6
  gfx.color("#3A2A1A")
  G.line(hx, hy, mx, my, 2.5)
  G.line(mx, my, tipX, tipY, 1.6)
  G.circle(hx + 3, hy + 2, 3, "#555555")
  return tipX, tipY
end

-- line from the rod tip to (x, y), sagging when slack
local function drawLine(x1, y1, x2, y2, sag)
  for i = 0, 8 do
    local k = i / 8
    LINE[i * 2 + 1] = x1 + (x2 - x1) * k
    LINE[i * 2 + 2] = y1 + (y2 - y1) * k + sin(k * pi) * sag
  end
  gfx.color(255, 255, 255, 150)
  G.lines(LINE, 1)
end

-- ---------------------------------------------------------------- scenes
local Title = {pausable = false}
local Setup = {pausable = false}
local Play = {controls = true}
local Catch = {transparent = true, pausable = false}
local Log = {pausable = false}
local Trip = {pausable = false}

local MENU_SONG = {bpm = 92, div = 2, wave = "triangle", volume = 0.045,
  notes = "E5:2 G5:2 A5:3 G5:1 E5:2 D5:2 C5:4 D5:2 E5:2 G5:3 E5:1 D5:6 -:2 " ..
          "E5:2 G5:2 A5:3 C6:1 B5:2 A5:2 G5:4 E5:2 D5:2 C5:3 D5:1 C5:6 -:2",
  bass = "C3:8 A2:8 F2:8 G2:8 C3:8 A2:8 F2:8 G2:4 C3:4"}
local menuMusic = false
local function startMenuMusic() if not menuMusic then A.song(MENU_SONG); menuMusic = true end end
local function stopMenuMusic() A.stopSong(); menuMusic = false end
local function toggleSound()
  A.setMuted(not A.muted)
  game.save.open("settings"):set("muted", A.muted)
end
local function hint(s, y)
  local W = game.width
  local sz = min(9, 9 * (W - 16) / max(1, G.textWidth(s, 9, "semibold")))
  U.text(s, 0, y or (game.height - 8 - sz * 1.3), sz, "#FFFFFFD0", "center", W, "semibold")
end

-- title ---------------------------------------------------------------------------------------------
function Title:enter()
  self.t = 0
  self.jump = {x = 0, y = 0, a = 0, on = false, f = FISH[1], face = 1}
  self.splash = game.emitter{max = 120, life = {0.4, 0.8}, speed = {40, 120}, angle = -pi / 2, spread = 1.4,
    gravity = 260, size = {3, 0}, colors = {"#FFFFFF", "#9FE0FF00"}}
  self.logo = {y = -40}
  game.tween.to(self.logo, 0.9, {y = 0}, "outBounce")
  self.menu = U.menu{width = 200, items = {
    {label = function() return TR("go_fishing") end, action = function() game.switch(Setup) end},
    {label = function() return TR("collection") end, action = function() game.switch(Log) end},
    {label = function() return TR("sound", A.muted and TR("off") or TR("on")) end, action = toggleSound,
     left = toggleSound, right = toggleSound},
    {label = function() return TR("quit") end, action = function() sys.exit() end},
  }}
  self.nextJump = 1.5
  startMenuMusic()
end
function Title:update(dt)
  self.t = self.t + dt
  self.menu:update()
  self.splash:update(dt)
  self.nextJump = self.nextJump - dt
  if self.nextJump <= 0 and not self.jump.on then
    -- a fish leaps out of the water along an arc
    local j = self.jump
    local W, wy = game.width, waterY()
    j.on, j.k = true, 0
    j.f = FISH[random(#FISH)]
    j.face = random() < 0.5 and 1 or -1
    j.x0 = W * (0.15 + random() * 0.7)
    j.wy = wy
    self.splash:emit(14, j.x0, wy)
    A.play("plop", 0.6)
    game.tween.to(j, 1.1, {k = 1}, "linear"):oncomplete(function()
      j.on = false
      self.splash:emit(18, j.x0 + j.face * 90, j.wy)
      A.play("splash", 0.6)
    end)
    self.nextJump = 2.5 + random() * 2
  end
end
function Title:draw()
  drawScene(1, 1, self.t)
  local j = self.jump
  if j.on then
    local x = j.x0 + j.face * 90 * j.k
    local y = j.wy - sin(j.k * pi) * 70
    drawFish(j.f, x, y, 34, j.face)
  end
  self.splash:draw()
  drawDock(0, self.t)
end
function Title:ui()
  local W, H = game.width, game.height
  local y = H * 0.08 + self.logo.y
  U.text(TR("logo"), 0, y, 40, "#FFFFFF", "center", W, "bold", "#0B3B5C")
  U.text(TR("tagline"), 0, y + 48, 11, "#FFFFFF", "center", W, "semibold")
  local cy = y + 66
  G.icon("monetization_on", W / 2 - 34, cy + 7, 12, "#FFD24F")
  U.text(tostring(coins()), W / 2 - 25, cy + 1, 11, "#FFE68A", nil, nil, "bold")
  G.icon("set_meal", W / 2 + 16, cy + 7, 12, "#9FE0FF")
  U.text(caughtCount() .. "/" .. #FISH, W / 2 + 25, cy + 1, 11, "#CFF1FF", nil, nil, "bold")
  self.menu:draw(W / 2, cy + 22)
  hint(TR("hint_title"))
end

-- setup: spot, time of day, rod -------------------------------------------------------------------
function Setup:enter()
  self.t = 0
  self.loc = save:get("loc", 1)
  if not LOCS[self.loc] or not unlocked(self.loc) then self.loc = 1 end
  self.time = save:get("time", 1)
  if not TIMES[self.time] then self.time = 1 end
  local function cycleLoc(d) self.loc = (self.loc - 1 + d) % #LOCS + 1 end
  local function cycleTime(d) self.time = (self.time - 1 + d) % #TIMES + 1 end
  self.menu = U.menu{width = 260, itemHeight = 30, size = 13, items = {
    {label = function()
       local l = LOCS[self.loc]
       if unlocked(self.loc) then return TR("spot", TR(l.name)) end
       return TR("spot_locked", TR(l.name), l.price)
     end,
     action = function() self:buyLoc() end, left = function() cycleLoc(-1) end, right = function() cycleLoc(1) end},
    {label = function() return TR("time_of_day", TR(TIMES[self.time].name)) end,
     action = function() cycleTime(1) end, left = function() cycleTime(-1) end, right = function() cycleTime(1) end},
    {label = function()
       local r = rodLevel()
       if RODS[r + 1] then return TR("rod_upgrade", r, RODS[r + 1].price) end
       return TR("rod_max", r)
     end,
     action = function() self:buyRod() end},
    {label = function() return TR("start_trip") end, action = function() self:start() end,
     enabled = function() return unlocked(self.loc) end},
    {label = function() return TR("back") end, action = function() game.switch(Title) end},
  }, onBack = function() game.switch(Title) end}
  self.menu.selected = 4
  startMenuMusic()
end
function Setup:buyLoc()
  if unlocked(self.loc) then self:start(); return end
  local l = LOCS[self.loc]
  if coins() >= l.price then
    addCoins(-l.price)
    local u = save:get("unlocked", {})
    if type(u) ~= "table" then u = {} end
    u[l.id] = true
    save:set("unlocked", u)
    A.play("buy")
    U.toast(TR("unlocked_toast", TR(l.name)), 1.6)
  else
    A.play("lose", 0.5)
    U.toast(TR("need_coins", l.price - coins()), 1.6)
  end
end
function Setup:buyRod()
  local r = rodLevel()
  local nxt = RODS[r + 1]
  if not nxt then return end
  if coins() >= nxt.price then
    addCoins(-nxt.price)
    save:set("rod", r + 1)
    A.play("buy")
    U.toast(TR("rod_bought", r + 1), 1.6)
  else
    A.play("lose", 0.5)
    U.toast(TR("need_coins", nxt.price - coins()), 1.6)
  end
end
function Setup:start()
  if not unlocked(self.loc) then return end
  save:set("loc", self.loc)
  save:set("time", self.time)
  game.switch(Play, {loc = self.loc, time = self.time}, {fade = 0.5, color = "#061A2A"})
end
function Setup:update(dt) self.t = self.t + dt; self.menu:update() end
function Setup:draw()
  drawScene(self.loc, self.time, self.t)
  drawDock(0, self.t)
  if not unlocked(self.loc) then G.rect(0, 0, game.width, game.height, 0, "#00000070") end
end
function Setup:ui()
  local W, H = game.width, game.height
  U.text(TR("plan_trip"), 0, 14, 18, "#FFFFFF", "center", W, "bold", "#0B3B5C")
  G.icon("monetization_on", W / 2 - 22, 46, 13, "#FFD24F")
  U.text(tostring(coins()), W / 2 - 12, 40, 12, "#FFE68A", nil, nil, "bold")
  U.panel(W / 2 - 140, 60, 280, 5 * 30 + 12, 12, "#08182AC8")
  self.menu:draw(W / 2, 66)
  -- which species live here at this time
  local n, total = 0, 0
  for _, f in ipairs(FISH) do
    if f.loc == LOCS[self.loc].id and (f.time == "any" or f.time == TIMES[self.time].id) then
      total = total + 1
      if logOf(f.id) then n = n + 1 end
    end
  end
  U.text(TR("species_here", n, total), 0, 60 + 5 * 30 + 18, 10, "#CFF1FF", "center", W, "semibold")
  hint(TR("hint_setup"))
end

-- play ----------------------------------------------------------------------------------------------
function Play:enter(p)
  self.li = (p and p.loc) or 1
  self.ti = (p and p.time) or 1
  if not LOCS[self.li] then self.li = 1 end
  if not TIMES[self.ti] then self.ti = 1 end
  stopMenuMusic()
  self.splash = game.emitter{max = 200, life = {0.35, 0.8}, speed = {40, 150}, angle = -pi / 2, spread = 1.5,
    gravity = 300, size = {3.2, 0}, colors = {"#FFFFFF", "#9FE0FF00"}}
  self.ripples = {}
  for i = 1, 8 do self.ripples[i] = {t = 0, x = 0, y = 0} end
  self:startTrip()
end
function Play:startTrip()
  self.bait = BAIT
  self.trip = {coins = 0, catches = 0, newSpecies = 0, records = 0, best = nil, bestKg = 0, list = {}}
  self.t = 0
  self.amb = 3
  self.shake = 0
  self.splash:clear()
  self:toAim()
end
function Play:restart() self:startTrip() end

function Play:toAim()
  self.state = "aim"
  self.power = 0
  self.bend = 0
  self.msg = nil
end

function Play:ripple(x, y)
  local best = self.ripples[1]
  for i = 1, #self.ripples do
    local r = self.ripples[i]
    if r.t <= 0 then best = r; break end
    if r.t < best.t then best = r end
  end
  best.x, best.y, best.t = x, y, 1
end

function Play:message(key, color, ...)
  self.msg = {text = TR(key, ...), color = color or "#FFFFFF", t = 1.8, s = 1.4}
  game.tween.to(self.msg, 0.25, {s = 1}, "outBack")
end

-- choose the fish that bites: spot + time of day, rarer fish favoured by long casts
function Play:pickFish()
  local loc, tm = LOCS[self.li].id, TIMES[self.ti].id
  local total = 0
  local pool = self.pool or {}
  self.pool = pool
  local n = 0
  for _, f in ipairs(FISH) do
    if f.loc == loc and (f.time == "any" or f.time == tm) then
      local w = RARITY_WEIGHT[f.r]
      if f.r >= 3 then w = w * (0.6 + self.power * 1.2) end
      n = n + 1
      pool[n] = f
      pool[-n] = w
      total = total + w
    end
  end
  local r = random() * total
  for i = 1, n do
    r = r - pool[-i]
    if r <= 0 then return pool[i] end
  end
  return pool[max(1, n)] or FISH[1]
end

function Play:cast()
  self.state = "fly"
  local W = game.width
  self.tx = 130 + self.power * max(40, W - 170)
  self.fly = {k = 0}
  self.fromX, self.fromY = self.tipX or 100, self.tipY or 100
  A.play("swoosh")
  game.tween.to(self.fly, 0.45 + self.power * 0.35, {k = 1}, "outQuad"):oncomplete(function()
    self.state = "wait"
    self.bx, self.by = self.tx, waterY()
    self.waitT = 1.5 + random() * 4 - (self.ti == 3 and 0.5 or 0)
    self.nibbleT = 0.6 + random() * 1.2
    self.bob = 0
    self.splash:emit(12, self.bx, waterY())
    self:ripple(self.bx, waterY())
    A.play("plop")
  end)
end

function Play:hook()
  local f = self.fish
  local r = f.r
  self.state = "reel"
  self.reel = {
    tension = 0.35, tv = 0, progress = 0.25,
    zc = 0.5, zt = 0.5, zh = (0.17 - 0.016 * r) * RODS[rodLevel()].zone,
    zspeed = 0.22 + 0.11 * r, retarget = 0.8,
    surge = 1.2 + random(), over = 0, slack = 0, tick = 0,
    fx = self.bx, face = -1,
  }
  A.play("confirm")
  sys.vibrate(0.5, 80)
end

function Play:lose(key, sound)
  self.bait = self.bait - 1
  self:message(key, "#FF8A80")
  A.play(sound or "lose", 0.7)
  self.state = "lost"
  self.lostT = 1.6
  self.shake = 4
end

function Play:landed()
  local f = self.fish
  local kg = f.w0 + (f.w1 - f.w0) * (random() ^ 2.2) * (0.75 + 0.25 * self.power)
  kg = floor(kg * 100 + 0.5) / 100
  if kg < 0.01 then kg = 0.01 end
  local cm = floor(46 * kg ^ (1 / 3) * (f.long or 1) + 0.5)
  local value = floor(RARITY_BASE[f.r] + f.val * kg)
  local new, rec = logCatch(f, kg)
  addCoins(value)
  self.bait = self.bait - 1
  local tr = self.trip
  tr.coins, tr.catches = tr.coins + value, tr.catches + 1
  if new then tr.newSpecies = tr.newSpecies + 1 end
  if rec then tr.records = tr.records + 1 end
  if kg > tr.bestKg then tr.best, tr.bestKg = f, kg end
  if #tr.list < 12 then tr.list[#tr.list + 1] = f end
  self.state = "caught"
  self.splash:emit(30, self.bx or 200, waterY())
  game.push(Catch, {fish = f, kg = kg, cm = cm, value = value, new = new, record = rec})
end

-- the Catch overlay pops back here
function Play:resume(result)
  if self.state == "caught" then
    if self.bait <= 0 then self:endTrip() else self:toAim() end
  end
end

function Play:endTrip()
  self.state = "done"
  local tr = self.trip
  game.tween.after(0.3, function()
    game.switch(Trip, {trip = tr, loc = self.li, time = self.ti}, {fade = 0.5, color = "#061A2A"})
  end)
end

function Play:holding()
  local p = I.pointer
  return I.down("cast") or (p.down and self.pointerHold)
end

function Play:update(dt)
  self.t = self.t + dt
  self.splash:update(dt)
  self.shake = max(0, self.shake - dt * 12)
  for i = 1, #self.ripples do local r = self.ripples[i]; if r.t > 0 then r.t = r.t - dt * 0.9 end end
  if self.msg then self.msg.t = self.msg.t - dt; if self.msg.t <= 0 then self.msg = nil end end
  -- ambience: birds by day, crickets at night
  self.amb = self.amb - dt
  if self.amb <= 0 then
    self.amb = 3 + random() * 5
    if self.ti == 3 then A.play("cricket") elseif self.ti == 1 then A.play("chirp") end
  end
  local p = I.pointer
  if p.pressed then self.pointerHold = true; self.dragX, self.dragY = p.x, p.y end
  if not p.down then self.pointerHold = false end
  local st = self.state
  if st == "aim" then
    self.bend = game.approach(self.bend, 0, dt * 3)
    if I.pressed("cast") or (p.pressed) then
      self.state, self.chargeT, self.byPointer = "charge", 0, not I.down("cast")
    end
  elseif st == "charge" then
    self.chargeT = self.chargeT + dt
    local drag = self.byPointer and game.dist(self.dragX or 0, self.dragY or 0, p.x, p.y) or 0
    if drag > 12 then
      self.power = min(1, drag / 110)        -- slingshot: drag farther for a longer cast
    else
      self.power = (1 - cos(self.chargeT * 2.6)) / 2
    end
    self.bend = -self.power * 0.6
    if not self:holding() then self:cast() end
  elseif st == "wait" then
    self.waitT = self.waitT - dt
    self.nibbleT = self.nibbleT - dt
    self.bob = max(0, (self.bob or 0) - dt * 4)
    if self.nibbleT <= 0 and self.waitT > 0.6 then
      -- a nibble: the bobber twitches, but it is not a bite yet
      self.nibbleT = 0.8 + random() * 1.5
      self.bob = 0.5
      A.play("nibble")
      self:ripple(self.bx, waterY())
    end
    if I.pressed("cast") or I.pressed("reelin") or p.pressed then
      self:message("too_early", "#FFE68A")
      self:toAim()
    elseif self.waitT <= 0 then
      self.fish = self:pickFish()
      self.state = "bite"
      self.biteT = 0.95 - self.fish.r * 0.06
      self.bob = 1
      A.play("bite")
      sys.vibrate(0.7, 120)
      self.splash:emit(8, self.bx, waterY())
      self:ripple(self.bx, waterY())
    end
  elseif st == "bite" then
    self.biteT = self.biteT - dt
    if I.pressed("cast") or p.pressed then self:hook()
    elseif self.biteT <= 0 then self:lose("got_away") end
  elseif st == "reel" then
    self:updateReel(dt)
  elseif st == "lost" then
    self.lostT = self.lostT - dt
    self.bend = game.approach(self.bend, 0, dt * 3)
    if self.lostT <= 0 then
      if self.bait <= 0 then self:endTrip() else self:toAim() end
    end
  end
  if st ~= "reel" and st ~= "done" and I.pressed("reelin") and st ~= "wait" then
    if st == "charge" then self:toAim() end
  end
end

-- reeling: hold to pull (tension rises), let go to give line (tension falls)
function Play:updateReel(dt)
  local R = self.reel
  local hold = self:holding()
  local acc = hold and 2.2 or -2.0
  R.tv = game.clamp(R.tv + acc * dt, -1.1, 1.1) * (1 - 2.4 * dt)
  -- the fish fights back now and then
  R.surge = R.surge - dt
  if R.surge <= 0 then
    R.surge = 0.9 + random() * 1.8 - self.fish.r * 0.1
    R.tv = R.tv + 0.35 + self.fish.r * 0.08
    self.shake = 2.5
    self.splash:emit(6, R.fx, waterY())
    A.play("splash", 0.5)
  end
  R.tension = game.clamp(R.tension + R.tv * dt, 0, 1)
  -- moving green zone
  R.retarget = R.retarget - dt
  if R.retarget <= 0 then
    R.retarget = 0.5 + random() * 1.2
    R.zt = R.zh + 0.05 + random() * (0.9 - 2 * R.zh)
  end
  R.zc = game.approach(R.zc, R.zt, R.zspeed * dt)
  local inZone = abs(R.tension - R.zc) <= R.zh
  if inZone then R.progress = R.progress + (0.2 - self.fish.r * 0.018) * dt
  else R.progress = R.progress - 0.09 * dt end
  -- breaking and slack
  if R.tension >= 0.99 then R.over = R.over + dt else R.over = max(0, R.over - dt * 2) end
  if R.tension <= 0.03 then R.slack = R.slack + dt else R.slack = max(0, R.slack - dt * 2) end
  self.bend = 0.3 + R.tension * 0.9
  R.tick = R.tick - dt
  if hold and R.tick <= 0 then
    R.tick = 0.08
    A.tone(500 + R.tension * 700, 0.02, 0.05, "square")
  end
  -- the fish swims towards the dock as you win
  R.fx = game.lerp(self.bx, 125, game.clamp(R.progress, 0, 1)) + sin(self.t * 3) * 14
  R.face = cos(self.t * 3) > 0 and 1 or -1
  if R.over > 0.35 then
    self:lose("line_snapped", "snap")
    sys.vibrate(1, 200)
  elseif R.slack > 1.4 or R.progress <= 0 then
    self:lose("slipped_away")
  elseif R.progress >= 1 then
    self:landed()
  end
end

function Play:draw()
  local W, H = game.width, game.height
  local sx = self.shake > 0 and (random() - 0.5) * self.shake or 0
  local sy = self.shake > 0 and (random() - 0.5) * self.shake or 0
  G.push(sx, sy)
  drawScene(self.li, self.ti, self.t)
  local wy = waterY()
  -- ripples
  for i = 1, #self.ripples do
    local r = self.ripples[i]
    if r.t > 0 then
      gfx.color(255, 255, 255, floor(r.t * 150))
      G.rectLine(r.x - (1 - r.t) * 28 - 4, r.y - (1 - r.t) * 4 - 1, (1 - r.t) * 56 + 8, (1 - r.t) * 8 + 2, 6, 1)
    end
  end
  local st = self.state
  -- fish shadow while reeling
  if st == "reel" then
    local R = self.reel
    gfx.color(0, 0, 0, 80)
    G.alpha(0.55)
    drawFish(self.fish, R.fx, wy + 24, 30 + self.fish.r * 3, R.face, true)
    G.unalpha()
  end
  local tipX, tipY = drawDock(self.bend, self.t)
  self.tipX, self.tipY = tipX, tipY
  if st == "fly" and self.fly then
    local k = self.fly.k
    local x = game.lerp(self.fromX, self.tx, k)
    local y = game.lerp(self.fromY, wy, k) - sin(k * pi) * (40 + self.power * 50)
    drawLine(tipX, tipY, x, y, 4)
    G.circle(x, y, 3.5, "#E8463A")
  elseif st == "wait" or st == "bite" then
    local dip = (self.bob or 0) * 5 + sin(self.t * 2.5) * 1
    local by = wy + dip - 2
    drawLine(tipX, tipY, self.bx, by, 22)
    if st == "bite" then
      G.circle(self.bx, wy + 4, 3.5, "#E8463A")
      local s = 1 + 0.15 * sin(self.t * 25)
      G.circle(self.bx, wy - 30, 11 * s, "#FFFFFF")
      U.text("!", self.bx - 10, wy - 41, 18 * s, "#E8463A", "center", 20, "bold", false)
    else
      G.circle(self.bx, by, 4, "#FFFFFF")
      G.rect(self.bx - 4, by - 4, 8, 4, 2, "#E8463A")
    end
  elseif st == "reel" then
    local R = self.reel
    drawLine(tipX, tipY, R.fx, wy + 2, (1 - R.tension) * 18)
  end
  self.splash:draw()
  G.pop()
end

function Play:ui()
  local W, H = game.width, game.height
  local st = self.state
  local right = W - 10 - (I.touchVisible() and 40 or 0)
  -- top bar: coins, bait, spot
  U.panel(8, 6, 150, 22, 11, "#00000066")
  G.icon("monetization_on", 20, 17, 12, "#FFD24F")
  U.text(tostring(coins()), 30, 10, 11, "#FFE68A", nil, nil, "bold")
  G.icon("phishing", 88, 17, 12, "#FFFFFF")
  U.text(TR("bait_left", self.bait, BAIT), 98, 10, 11, "#FFFFFF", nil, nil, "bold")
  U.text(TR(LOCS[self.li].name) .. " · " .. TR(TIMES[self.ti].name), right - 160, 10, 11, "#FFFFFF", "right", 160, "semibold")
  -- power meter while charging
  if st == "charge" then
    local bx, by = 112, waterY() - 96
    U.panel(bx - 4, by - 4, 18, 70, 6, "#00000080")
    local h = 62 * self.power
    G.gradient(bx, by + 62 - h, 10, h, "#FF6B5C", "#FFE45C")
    U.text(floor(self.power * 100) .. "%", bx - 20, by + 66, 10, "#FFFFFF", "center", 50, "bold")
  end
  -- tension bar while reeling
  if st == "reel" then
    local R = self.reel
    local bh = min(170, H - 90)
    local bx, by = W - 52 - (I.touchVisible() and 30 or 0), (H - bh) / 2
    U.panel(bx - 6, by - 20, 36, bh + 46, 10, "#000000A0")
    U.text(TR("tension"), bx - 30, by - 17, 8, "#FFFFFFC0", "center", 84, "semibold", false)
    G.rect(bx, by, 24, bh, 6, "#1B2B3A")
    G.rect(bx, by, 24, bh * 0.1, 6, "#FF5C5C55")          -- danger at the top
    local zy = by + bh * (1 - (R.zc + R.zh))
    local inZone = abs(R.tension - R.zc) <= R.zh
    G.rect(bx + 1, zy, 22, bh * R.zh * 2, 5, inZone and "#6CE38ACC" or "#6CE38A70")
    local ty = by + bh * (1 - R.tension)
    local tc = R.over > 0 and ((floor(self.t * 16) % 2 == 0) and "#FF4040" or "#FFFFFF") or "#FFFFFF"
    G.rect(bx - 4, ty - 2, 32, 4, 2, tc)
    -- catch progress beside it
    U.bar(bx - 2, by + bh + 6, 28, 6, R.progress, "#FFD24F")
    if R.slack > 0.4 then U.text(TR("slack"), bx - 40, ty + 6, 9, "#FFE68A", "right", 36, "bold") end
  end
  if self.msg then
    G.alpha(min(1, self.msg.t * 2))
    U.text(self.msg.text, 0, H * 0.28, 18 * self.msg.s, self.msg.color, "center", W, "bold")
    G.unalpha()
  end
  local key = ({aim = "hint_aim", charge = "hint_charge", wait = "hint_wait", bite = "hint_bite", reel = "hint_reel"})[st]
  if key then hint(TR(key)) end
end

-- catch card (overlay) ------------------------------------------------------------------------------
function Catch:enter(p)
  self.p = p
  self.t = 0
  self.card = {s = 0.3, a = 0}
  game.tween.to(self.card, 0.45, {s = 1, a = 1}, "outBack")
  self.confetti = game.emitter{max = 220, life = {1.4, 2.4}, speed = {80, 220}, angle = -pi / 2, spread = 2.2,
    gravity = 160, damping = 0.8, size = {4.5, 2.5}, sizeVar = 0.5, shape = "square",
    colors = {"#FFD24F", "#FF6B8B", "#6CE38A", "#55B6FF", "#FFFFFF00"}}
  local f = p.fish
  local root = 523.25 * (1 + (f.r - 1) * 0.06)
  -- a chord that grows with the rarity
  A.tone(root, 0.5, 0.1, "triangle")
  A.tone(root * 1.26, 0.5, 0.08, "triangle")
  A.tone(root * 1.5, 0.6, 0.07, "triangle")
  if f.r >= 3 or p.new or p.record then
    game.tween.after(0.18, function() A.play("win") end)
    self.confetti:emit(f.r >= 4 and 140 or 80, game.width / 2, game.height * 0.45)
  else
    A.play("coin")
  end
end
function Catch:update(dt)
  self.t = self.t + dt
  self.confetti:update(dt)
  if self.t > 0.6 and (I.pressed("cast") or I.pressed("confirm") or I.pressed("back") or I.pointer.pressed) then
    A.play("select")
    game.pop()
  end
end
function Catch:ui()
  local W, H = game.width, game.height
  local p, f = self.p, self.p.fish
  G.rect(0, 0, W, H, 0, "#00000080")
  local cw, ch = min(300, W - 30), 190
  local s = self.card.s
  local x, y = W / 2 - cw * s / 2, H / 2 - ch * s / 2 - 6
  G.alpha(self.card.a)
  G.push(x, y, s)
  U.panel(0, 0, cw, ch, 14, "#0B2236F0")
  G.rect(0, 0, cw, 26, 14, RARITY_COLORS[f.r] .. "40")
  U.text(TR(RARITY[f.r]), 0, 6, 11, RARITY_COLORS[f.r], "center", cw, "bold")
  -- glowing rays behind the fish
  gfx.color(255, 255, 255, 18)
  for i = 0, 7 do
    local a = self.t * 0.6 + i * pi / 4
    G.line(cw / 2, 72, cw / 2 + cos(a) * 80, 72 + sin(a) * 40, 6)
  end
  drawFish(f, cw / 2, 72 + sin(self.t * 3) * 2, 96, 1)
  U.text(TR(f.name), 0, 112, 17, "#FFFFFF", "center", cw, "bold")
  U.text(string.format("%.2f kg · %d cm", p.kg, p.cm), 0, 134, 12, "#CFF1FF", "center", cw, "semibold")
  G.icon("monetization_on", cw / 2 - 22, 160, 13, "#FFD24F")
  U.text("+" .. p.value, cw / 2 - 12, 153, 13, "#FFE68A", nil, nil, "bold")
  if p.new then
    G.rect(cw - 96, 30, 88, 18, 9, "#FFD24F")
    U.text(TR("new_species"), cw - 96, 33, 9, "#3A2A00", "center", 88, "bold", false)
  elseif p.record then
    G.rect(cw - 96, 30, 88, 18, 9, "#6CE38A")
    U.text(TR("new_record"), cw - 96, 33, 9, "#0B2A12", "center", 88, "bold", false)
  end
  G.pop()
  G.unalpha()
  self.confetti:draw()
  if self.t > 0.6 then hint(TR("hint_continue")) end
end

-- collection log ------------------------------------------------------------------------------------
function Log:enter()
  self.t = 0
  self.sel = 1
  startMenuMusic()
end
function Log:grid()
  local W, H = game.width, game.height
  local cols = max(4, min(7, floor((W - 24) / 64)))
  local cw = floor((W - 24) / cols)
  local chh = min(52, floor((H - 112) / math.ceil(#FISH / cols)))
  local x0 = (W - cols * cw) / 2
  return cols, cw, chh, x0, 40
end
function Log:update(dt)
  self.t = self.t + dt
  local cols, cw, chh, x0, y0 = self:grid()
  local n = #FISH
  local s = self.sel
  if I.pressed("left") then s = s - 1 end
  if I.pressed("right") then s = s + 1 end
  if I.pressed("up") then s = s - cols end
  if I.pressed("down") then s = s + cols end
  s = game.clamp(s, 1, n)
  if s ~= self.sel then self.sel = s; A.play("select") end
  local p = I.pointer
  if p.released then
    for i = 1, n do
      local cx = x0 + ((i - 1) % cols) * cw
      local cy = y0 + floor((i - 1) / cols) * chh
      if p.x >= cx and p.x < cx + cw and p.y >= cy and p.y < cy + chh then self.sel = i; A.play("select") end
    end
  end
  if I.pressed("back") then game.switch(Title) end
end
function Log:draw()
  G.gradient(0, 0, game.width, game.height, "#0B2A44", "#06182A")
end
function Log:ui()
  local W, H = game.width, game.height
  local cols, cw, chh, x0, y0 = self:grid()
  U.text(TR("collection"), 14, 10, 17, "#FFFFFF", nil, nil, "bold")
  U.text(TR("caught_of", caughtCount(), #FISH), W - 214, 14, 11, "#CFF1FF", "right", 200, "semibold")
  for i, f in ipairs(FISH) do
    local cx = x0 + ((i - 1) % cols) * cw
    local cy = y0 + floor((i - 1) / cols) * chh
    local e = logOf(f.id)
    local sel = i == self.sel
    G.rect(cx + 2, cy + 2, cw - 4, chh - 4, 8, sel and "#1F5A86" or "#FFFFFF14")
    if sel then gfx.color(RARITY_COLORS[f.r]); G.rectLine(cx + 2, cy + 2, cw - 4, chh - 4, 8, 1.5) end
    G.rect(cx + 6, cy + chh - 9, cw - 12, 2, 1, RARITY_COLORS[f.r] .. (e and "FF" or "50"))
    drawFish(f, cx + cw / 2, cy + chh / 2 - 3, min(cw - 22, 44), 1, e == nil)
    if not e then U.text("?", cx, cy + chh / 2 - 10, 14, "#FFFFFF90", "center", cw, "bold", false) end
  end
  -- details of the selected species
  local f = FISH[self.sel]
  local e = logOf(f.id)
  local py = H - 58
  U.panel(10, py, W - 20, 50, 10, "#00000070")
  local where = TR(LOCS[f.loc == "lake" and 1 or (f.loc == "river" and 2 or 3)].name) .. " · " ..
    TR(TIME_KEYS[f.time] or "time_any")
  if e then
    U.text(TR(f.name), 22, py + 7, 14, "#FFFFFF", nil, nil, "bold")
    U.text(TR(RARITY[f.r]) .. " · " .. where, 22, py + 27, 10, RARITY_COLORS[f.r], nil, nil, "semibold")
    U.text(TR("best_weight", string.format("%.2f", e.best or 0)), W - 222, py + 9, 11, "#FFE68A", "right", 200, "bold")
    U.text(TR("times_caught", e.n or 0), W - 222, py + 27, 10, "#CFF1FF", "right", 200, "semibold")
  else
    U.text(TR("unknown_fish"), 22, py + 7, 14, "#FFFFFFA0", nil, nil, "bold")
    U.text(TR("hint_where", where), 22, py + 27, 10, "#CFF1FF", nil, nil, "semibold")
  end
  if U.button(TR("back"), W - 84, 8, 72, 24) then game.switch(Title) end
end

-- trip summary --------------------------------------------------------------------------------------
function Trip:enter(p)
  self.p = p
  self.t = 0
  local tr = p.trip
  self.shown = {coins = 0}
  game.tween.to(self.shown, 1.0, {coins = tr.coins}, {ease = "outCubic", delay = 0.4})
  self.confetti = game.emitter{max = 260, life = {1.6, 2.8}, speed = {50, 160}, angle = pi / 2, spread = 1.2,
    gravity = 80, damping = 0.6, size = {5, 3}, sizeVar = 0.5, shape = "square",
    colors = {"#FFD24F", "#FF6B8B", "#6CE38A", "#55B6FF", "#FFFFFF00"}}
  self.celebrate = tr.newSpecies > 0 or tr.records > 0
  if self.celebrate then game.tween.after(0.5, function() A.play("win") end)
  elseif tr.catches > 0 then A.play("coin") else A.play("lose", 0.6) end
  self.menu = U.menu{width = 180, itemHeight = 28, size = 13, items = {
    {label = function() return TR("new_trip") end,
     action = function() game.switch(Play, {loc = p.loc, time = p.time}, {fade = 0.5, color = "#061A2A"}) end},
    {label = function() return TR("change_spot") end, action = function() game.switch(Setup) end},
    {label = function() return TR("main_menu") end, action = function() game.switch(Title) end},
  }}
end
function Trip:update(dt)
  self.t = self.t + dt
  if self.celebrate and self.t > 0.5 and self.t < 3 then self.confetti:emit(3, random() * game.width, -8) end
  self.confetti:update(dt)
  self.menu:update()
end
function Trip:draw()
  drawScene(self.p.loc, self.p.time, self.t)
  G.rect(0, 0, game.width, game.height, 0, "#00000060")
end
function Trip:ui()
  local W, H = game.width, game.height
  local tr = self.p.trip
  local pw, ph = min(360, W - 24), 150
  local px, py = (W - pw) / 2, 14
  U.panel(px, py, pw, ph, 14, "#0B2236E8")
  U.text(TR("trip_over"), px, py + 10, 17, "#FFFFFF", "center", pw, "bold")
  local cx = px + 18
  U.text(TR("fish_caught", tr.catches, BAIT), cx, py + 40, 12, "#CFF1FF", nil, nil, "semibold")
  G.icon("monetization_on", cx + 6, py + 66, 13, "#FFD24F")
  U.text("+" .. floor(self.shown.coins), cx + 16, py + 59, 13, "#FFE68A", nil, nil, "bold")
  if tr.best then
    U.text(TR("biggest", TR(tr.best.name), string.format("%.2f", tr.bestKg)), cx, py + 82, 11, "#FFFFFF", nil, nil, "semibold")
  end
  if tr.newSpecies > 0 then
    U.text(TR("new_species_n", tr.newSpecies), cx, py + 100, 11, "#FFD24F", nil, nil, "bold")
  end
  if tr.records > 0 then
    U.text(TR("records_n", tr.records), cx + pw * 0.5, py + 100, 11, "#6CE38A", nil, nil, "bold")
  end
  -- the day's catch in a row
  for i, f in ipairs(tr.list) do
    local fx = px + 22 + (i - 1) * min(28, (pw - 40) / max(1, #tr.list))
    drawFish(f, fx, py + 132, 22, 1)
  end
  if tr.catches == 0 then U.text(TR("empty_trip"), px, py + 124, 11, "#FFFFFFA0", "center", pw, "semibold") end
  self.menu:draw(W / 2, py + ph + 10)
  self.confetti:draw()
end

-- ---------------------------------------------------------------- run
return game.run{
  width = 480, height = 270, scale = "expand",
  scene = Title, title = Title,
  background = "#06182A",
  menu = function()
    return {{title = TR("game_menu"), items = {
      {label = TR("pause_menu"), id = 1, shortcut = "Esc"},
      {label = TR("collection"), id = 2},
      {label = TR("main_menu"), id = 3},
      "-",
      {label = TR("reset_progress"), id = 4},
    }}}
  end,
  onmenu = function(id)
    if id == 1 then game.pause()
    elseif id == 2 then game.switch(Log)
    elseif id == 3 then game.switch(Title)
    elseif id == 4 then
      ui.alert(TR("reset_progress"), TR("reset_confirm"), {TR("reset"), TR("cancel")}, function(i)
        if i == 1 then save:reset(); U.toast(TR("progress_reset")) end
      end)
    end
  end,
}
