-- Photon Garden: guide beams of light with mirrors, splitters, filters and portals until every crystal bud blooms.
-- 120 levels in six gardens (handmade introductions, generated puzzles), stars, undo, hints and a level editor
-- whose levels can be shared as codes. Built on nexvyn.game with the shared kit (kit.lua).
local game = require("nexvyn.game")
local K = require("kit")
local L = require("levels")
local G, I, U = game.gfx, game.input, game.ui
local floor, min, max, sin, cos, abs, pi, sqrt = math.floor, math.min, math.max, math.sin, math.cos, math.abs, math.pi,
  math.sqrt

local save = game.save.open("garden")
local TRd = function(k, ...) return TR(k, ...) end   -- keys built at run time

-- ---------------------------------------------------------------- look
local COL = {[1] = "#FF4D5E", [2] = "#3DFF8A", [4] = "#4D8DFF", [3] = "#FFE14D", [5] = "#FF5CF0", [6] = "#4DF3FF",
             [7] = "#FFFFFF", [0] = "#8090A0"}
local PORTAL = {"#B98CFF", "#FFB547", "#4DF3FF"}
local WORLD = {
  {top = "#1B2B4A", bot = "#3A2A55", acc = "#FFB547"},
  {top = "#0F2A24", bot = "#1F3D2A", acc = "#7CFF9B"},
  {top = "#0B2238", bot = "#173B5C", acc = "#5CD6FF"},
  {top = "#2A1538", bot = "#3B1F4D", acc = "#FF7AD9"},
  {top = "#14232E", bot = "#22384A", acc = "#B8F2FF"},
  {top = "#0D0B24", bot = "#24164A", acc = "#B98CFF"},
}

-- ---------------------------------------------------------------- sound and music
K.track("title", "bundle:/music/title.ogg", 21.818)
K.track("garden", "bundle:/music/garden.ogg", 20)
K.sound("ui_move", "bundle:/sfx/ui_move.wav", 0.6)
K.sound("ui_ok", "bundle:/sfx/ui_ok.wav", 0.7)
K.sound("ui_back", "bundle:/sfx/ui_back.wav", 0.6)
K.sound("place", {"bundle:/sfx/place1.wav", "bundle:/sfx/place2.wav"}, 0.8)
K.sound("rotate", {"bundle:/sfx/rotate1.wav", "bundle:/sfx/rotate2.wav"}, 0.7)
K.sound("take", "bundle:/sfx/take.wav", 0.7)
K.sound("bloom", {"bundle:/sfx/bloom1.wav", "bundle:/sfx/bloom2.wav", "bundle:/sfx/bloom3.wav"}, 0.8, 0.08)
K.sound("thorn", "bundle:/sfx/thorn.wav", 0.8, 0.2)
K.sound("win", "bundle:/sfx/win.wav", 0.9)
K.sound("undo", "bundle:/sfx/undo.wav", 0.6)
K.sound("hint", "bundle:/sfx/hint.wav", 0.8)
K.sound("move", "bundle:/sfx/ui_move.wav", 0.35, 0.05)

-- ---------------------------------------------------------------- input
I.bind("take", {pad = "x", key = {"x", "delete"}, touch = "button:take"})
I.bind("prev", {pad = "l", key = "q"})
I.bind("next", {pad = "r", key = "e"})
I.bind("undo", {pad = {"b", "zl"}, key = {"z", "u"}})
I.bind("hint", {pad = "y", key = "h"})
I.bind("reset", {pad = "minus", key = "r"})
I.bind("tool", {pad = "zr", key = "t"})

-- ---------------------------------------------------------------- progress
local stars = {}
local function loadStars()
  local s = save:get("stars", "")
  for i = 1, L.COUNT do stars[i] = tonumber(s:sub(i, i)) or 0 end
end
local function saveStars()
  local t = {}
  for i = 1, L.COUNT do t[i] = tostring(stars[i] or 0) end
  save:set("stars", table.concat(t))
end
loadStars()
local function solvedIn(w)
  local n = 0
  for i = (w - 1) * L.PER_WORLD + 1, w * L.PER_WORLD do if stars[i] > 0 then n = n + 1 end end
  return n
end
local function starsIn(w)
  local n = 0
  for i = (w - 1) * L.PER_WORLD + 1, w * L.PER_WORLD do n = n + stars[i] end
  return n
end
local function worldOpen(w) return w == 1 or solvedIn(w - 1) >= 12 end
local function levelOpen(n)
  local w = L.worldOf(n)
  if not worldOpen(w) then return false end
  return (n - 1) % L.PER_WORLD + 1 <= solvedIn(w) + 3 or stars[n] > 0
end
local function nextLevel()
  for n = 1, L.COUNT do if stars[n] == 0 and levelOpen(n) then return n end end
  return 1
end
local function totalStars()
  local n = 0
  for i = 1, L.COUNT do n = n + stars[i] end
  return n
end

local customs = save:get("custom", {})
if type(customs) ~= "table" then customs = {} end
local function saveCustoms() save:set("custom", customs) end

-- ---------------------------------------------------------------- shared drawing
local fireflies = {}
for i = 1, 36 do
  fireflies[i] = {x = math.random() * 800, y = math.random() * 450, s = 0.5 + math.random() * 1.5,
                  p = math.random() * 6.28, v = 4 + math.random() * 10}
end
local function drawBackdrop(top, bot, acc)
  G.gradient(0, 0, game.width, game.height, top, bot)
  local t = game.realTime
  for _, f in ipairs(fireflies) do
    local x = (f.x + t * f.v) % (game.width + 40) - 20
    local y = (f.y + sin(t * 0.7 + f.p) * 14) % (game.height + 20) - 10
    local a = 0.35 + 0.35 * sin(t * 2 + f.p)
    G.circle(x, y, f.s * 3, (acc or "#FFE9A8") .. string.format("%02X", floor(a * 40)))
    G.circle(x, y, f.s, "#FFF6D0" .. string.format("%02X", floor(a * 255)))
  end
end

local function glowLine(x1, y1, x2, y2, col, w)
  G.color(col .. "26"); G.line(x1, y1, x2, y2, w * 1.0)
  G.color(col .. "66"); G.line(x1, y1, x2, y2, w * 0.46)
  G.color(col); G.line(x1, y1, x2, y2, w * 0.2)
  G.color("#FFFFFFD8"); G.line(x1, y1, x2, y2, max(0.8, w * 0.07))
end

-- pieces are drawn centred at cx, cy in a cell of size s
local function drawPiece(p, cx, cy, s, t, lit, ghost)
  local h = s / 2
  local k = p.t
  if k == "wall" then
    G.rect(cx - h + 1, cy - h + 1, s - 2, s - 2, s * 0.12, "#4E566B")
    G.rect(cx - h + 1, cy - h + 1, s - 2, s * 0.22, s * 0.12, "#6C7690")
    G.circle(cx - h * 0.4, cy + h * 0.35, s * 0.08, "#5D8A5A")
    G.circle(cx + h * 0.3, cy + h * 0.5, s * 0.06, "#6FA36A")
  elseif k == "emit" then
    local col = COL[p.c]
    local dx, dy = L.DX[p.d], L.DY[p.d]
    G.circle(cx, cy, h * 0.78, "#1A2236")
    G.circle(cx, cy, h * 0.66, "#2E3A56")
    G.polyT({h * 0.95, 0, h * 0.35, -h * 0.42, h * 0.35, h * 0.42}, cx, cy, math.atan(dy, dx), 1, 1, "#3C4A6C")
    G.circle(cx, cy, h * (0.46 + 0.04 * sin(t * 4)), col .. "50")
    G.circle(cx, cy, h * 0.3, col)
    G.circle(cx - h * 0.08, cy - h * 0.1, h * 0.1, "#FFFFFFC0")
  elseif k == "target" then
    local col = COL[p.need] or "#8090A0"
    local b = p.bloom or 0
    if b < 0.98 then
      local r = h * 0.55 * (1 - b * 0.5)
      G.poly({cx, cy - r * 1.2, cx + r * 0.8, cy, cx, cy + r * 1.2, cx - r * 0.8, cy}, col .. "90")
      G.poly({cx, cy - r * 1.2, cx + r * 0.8, cy, cx, cy - r * 0.1}, "#FFFFFF50")
      G.color(col)
      G.lines({cx, cy - r * 1.2, cx + r * 0.8, cy, cx, cy + r * 1.2, cx - r * 0.8, cy}, 1.4, true)
    end
    if b > 0.02 then
      local pr = h * 0.36 * b
      for i = 0, 5 do
        local a = i * pi / 3 + t * 0.4
        G.circle(cx + cos(a) * pr * 1.15, cy + sin(a) * pr * 1.15, pr * 0.8, col .. "D0")
      end
      G.circle(cx, cy, pr * 0.75, "#FFF3B0")
      G.circle(cx, cy, pr * 0.4, "#FFC94D")
    end
    -- the colour the bud needs, as three pips
    local px = cx - h * 0.36
    for _, bit in ipairs({1, 2, 4}) do
      local on = (p.need or 0) & bit ~= 0
      G.circle(px, cy + h * 0.78, s * 0.055, on and COL[bit] or "#FFFFFF22")
      px = px + h * 0.36
    end
  elseif k == "thorn" then
    local hit = p.hit
    local r = h * 0.62
    local pts = {}
    for i = 0, 15 do
      local a = i * pi / 8 + 0.2
      local rr = (i % 2 == 0) and r or r * 0.55
      pts[#pts + 1] = cx + cos(a) * rr
      pts[#pts + 1] = cy + sin(a) * rr
    end
    G.color(hit and "#FF3048" or "#5A2A6E")
    G.lines(pts, 2, true)
    G.circle(cx, cy, r * 0.5, hit and "#FF3048" or "#3E1A4E")
    G.circle(cx - r * 0.15, cy - r * 0.15, r * 0.16, hit and "#FFC0C8" or "#8A4AA6")
  elseif k == "mirror" or k == "split" then
    local a = p.o == 0 and -pi / 4 or pi / 4
    local ca, sa = cos(a) * h * 0.8, sin(a) * h * 0.8
    if k == "mirror" then
      G.color("#1B2233")
      G.line(cx - ca + 1, cy - sa + 2, cx + ca + 1, cy + sa + 2, s * 0.16)
      G.color("#C9D4E8")
      G.line(cx - ca, cy - sa, cx + ca, cy + sa, s * 0.13)
      G.color("#FFFFFF")
      G.line(cx - ca * 0.9, cy - sa * 0.9, cx + ca * 0.9, cy + sa * 0.9, s * 0.04)
    else
      G.color("#9FE8FF60")
      G.line(cx - ca, cy - sa, cx + ca, cy + sa, s * 0.16)
      G.color("#D8F8FF")
      for i = -3, 2 do
        local f0, f1 = i / 3.5, (i + 0.6) / 3.5
        G.line(cx + ca * f0, cy + sa * f0, cx + ca * f1, cy + sa * f1, s * 0.07)
      end
    end
    if p.lock == "rot" then
      G.color("#FFFFFF60")
      G.circleLine(cx, cy, h * 0.86, 1.2)
      G.icon("sync", cx + h * 0.62, cy - h * 0.62, s * 0.26, "#FFFFFFB0")
    elseif p.lock == "fixed" then
      G.circle(cx, cy, s * 0.06, "#FFD166")
    elseif p.lock == "free" then
      G.color((K.accent or "#FFFFFF") .. "50")
      G.circleLine(cx, cy, h * 0.86, 1)
    end
  elseif k == "filter" then
    local col = COL[p.c]
    G.rect(cx - h * 0.6, cy - h * 0.6, s * 0.6, s * 0.6, s * 0.1, col .. "55")
    G.color(col)
    G.rectLine(cx - h * 0.6, cy - h * 0.6, s * 0.6, s * 0.6, s * 0.1, 1.6)
    G.rect(cx - h * 0.45, cy - h * 0.5, s * 0.12, s * 0.45, s * 0.05, "#FFFFFF50")
    if p.lock == "free" then
      G.color((K.accent or "#FFFFFF") .. "50")
      G.circleLine(cx, cy, h * 0.86, 1)
    end
  elseif k == "portal" then
    local col = PORTAL[p.id] or "#B98CFF"
    G.circle(cx, cy, h * 0.7, col .. "30")
    G.color(col)
    for i = 0, 2 do
      local a0 = t * 2.4 + i * 2.094
      G.circleLine(cx, cy, h * (0.32 + i * 0.16), 1.6)
      G.circle(cx + cos(a0) * h * (0.32 + i * 0.16), cy + sin(a0) * h * (0.32 + i * 0.16), s * 0.05, "#FFFFFF")
    end
    G.circle(cx, cy, h * 0.18, "#0B0820")
  end
end

-- a bag item (inventory) drawn as its piece
local function invPiece(it)
  if it.t == "filter" then return {t = "filter", c = it.c} end
  return {t = it.t, o = 0}
end

-- ---------------------------------------------------------------- particles
local sparks = game.emitter{max = 400, life = {0.4, 1.1}, speed = {30, 140}, size = {3.5, 0}, damping = 2.2,
                            colors = {"#FFFFFF", "#FFE9A8", "#FFB54700"}, shape = "circle"}
local petals = game.emitter{max = 260, life = {1.2, 2.4}, speed = {40, 160}, gravity = 60, damping = 0.8,
                            size = {5, 2}, colors = {"#FF9AD5", "#FFD1E8", "#FFFFFF00"}, shape = "square"}

-- ======================================================================== TITLE
local Title = {pausable = false}
local Gardens, Play, Editor, MyLevels
function Title:enter()
  K.music("title")
  self.t = 0
  local items = {
    {label = TR("play"), icon = "play_arrow", action = function() K.go(Play, {n = nextLevel()}, "circle", 0.4) end},
    {label = TR("gardens"), icon = "grid_view", action = function() K.go(Gardens, {w = L.worldOf(nextLevel())}) end},
    {label = TR("editor"), icon = "edit", action = function() K.go(Editor, {}) end},
    {label = TR("my_gardens"), icon = "folder", action = function() K.go(MyLevels, {}) end},
    {label = TR("k_settings"), icon = "tune", action = function() game.push(K.SettingsScene, {fromTitle = true}) end},
    {label = TR("k_help"), icon = "help", action = function()
      game.push(K.HelpScene, {title = TR("k_help"), rows = {
        {icon = "flare", text = TR("help_goal")},
        {action = "confirm", text = TR("help_place")},
        {action = "take", text = TR("help_take")},
        {action = "next", text = TR("help_pick")},
        {action = "undo", text = TR("help_undo")},
        {action = "hint", text = TR("help_hint")},
        {icon = "touch_app", text = TR("help_touch")},
      }})
    end},
    {label = TR("k_quit"), icon = "logout", action = function() K.stopAudio(); sys.exit() end},
  }
  self.menu = K.menu{items = items, width = 220, itemHeight = 30, size = 13}
  -- the demo board on the title screen
  self.demo = L.fromRows({"..  ..  ..  ..  ..  ..  ..  ..", "R>  ..  \\f  ..  ..  ..  Zf  T*", "..  ..  ..  ..  ..  ..  ..  ..",
                          "..  ..  \\f  ..  Sf  ..  /f  ..", "..  ..  ..  ..  ..  ..  ..  ..", "B>  ..  ..  ..  /f  ..  T*  .."})
  self.trace = L.trace(self.demo)
end
function Title:update(dt)
  self.t = self.t + dt
  self.menu:update()
end
function Title:draw()
  K.accent = "#FFB547"
  drawBackdrop("#141A38", "#3A2050", "#FFB547")
  local t = game.realTime
  -- demo board, faint, behind the logo
  local cs = 30
  local ox, oy = game.width - 8 * cs - 26, 70
  G.alpha(0.55)
  for i = 1, self.trace.n, 5 do
    local s = self.trace.segs
    glowLine(ox + s[i] * cs, oy + s[i + 1] * cs, ox + s[i + 2] * cs, oy + s[i + 3] * cs, COL[s[i + 4]], cs * 0.5)
  end
  for y = 0, self.demo.h - 1 do
    for x = 0, self.demo.w - 1 do
      local p = self.demo.cells[y][x]
      if p then
        if p.t == "target" then p.bloom = 0.6 + 0.4 * sin(t * 1.5 + x) end
        drawPiece(p, ox + (x + 0.5) * cs, oy + (y + 0.5) * cs, cs, t)
      end
    end
  end
  G.unalpha()
  -- logo
  local a = min(1, self.t / 0.8)
  G.alpha(a)
  local lx, ly = 40, 46 - (1 - a) * 20
  for i = 3, 1, -1 do U.text(TR("title"), lx, ly, 38, "#FFB547" .. string.format("%02X", 30 * i), "left", nil, "bold", false) end
  U.text(TR("title"), lx, ly, 38, "#FFF3D6", "left", nil, "bold")
  U.text(TR("tagline"), lx + 2, ly + 46, 13, "#FFFFFFB0", "left", nil, "semibold", false)
  G.unalpha()
  self.menu:draw(lx + 110, 128)
  local ts = totalStars()
  G.icon("star", lx + 8, game.height - 22, 16, "#FFD166")
  U.text(TR("stars_total", ts, L.COUNT * 3), lx + 20, game.height - 30, 12, "#FFFFFFC0", "left", nil, "semibold", false)
end

-- ======================================================================== GARDENS (level select)
Gardens = {pausable = false}
function Gardens:enter(p)
  K.music("title")
  self.w = p and p.w or 1
  self.sel = (p and p.n) and ((p.n - 1) % L.PER_WORLD + 1) or 1
  self.t, self.slide = 0, 0
  if not p or not p.n then
    for i = 1, L.PER_WORLD do
      local n = (self.w - 1) * L.PER_WORLD + i
      if levelOpen(n) and stars[n] == 0 then self.sel = i break end
    end
  end
  self.rects = {}
end
function Gardens:update(dt)
  self.t = self.t + dt
  self.slide = self.slide * (1 - min(1, dt * 12))
  local function setW(d)
    local w = self.w + d
    if w < 1 or w > L.WORLDS then K.sfx("ui_back") return end
    self.w, self.slide = w, d * 60
    K.sfx("ui_move")
  end
  if I.pressed("prev") then setW(-1) end
  if I.pressed("next") then setW(1) end
  local col, row = (self.sel - 1) % 5, (self.sel - 1) // 5
  if I.pressed("left") then if col == 0 then setW(-1) else self.sel = self.sel - 1; K.sfx("ui_move") end end
  if I.pressed("right") then if col == 4 then setW(1) else self.sel = self.sel + 1; K.sfx("ui_move") end end
  if I.pressed("up") and row > 0 then self.sel = self.sel - 5; K.sfx("ui_move") end
  if I.pressed("down") and row < 3 then self.sel = self.sel + 5; K.sfx("ui_move") end
  if I.pressed("back") then K.sfx("ui_back"); K.go(Title) end
  local function open(i)
    local n = (self.w - 1) * L.PER_WORLD + i
    if levelOpen(n) then K.sfx("ui_ok"); K.go(Play, {n = n}, "circle", 0.35) else K.sfx("ui_back") end
  end
  if I.pressed("confirm") then open(self.sel) end
  local pt = I.pointer
  if pt.released then
    for i, r in pairs(self.rects) do
      if pt.x >= r[1] and pt.y >= r[2] and pt.x < r[1] + r[3] and pt.y < r[2] + r[4] then
        if i == "prev" then setW(-1) elseif i == "next" then setW(1) elseif i == "back" then K.go(Title)
        elseif self.sel == i then open(i) else self.sel = i; K.sfx("ui_move") end
      end
    end
  end
end
function Gardens:draw()
  local W = WORLD[self.w]
  K.accent = W.acc
  drawBackdrop(W.top, W.bot, W.acc)
  local open = worldOpen(self.w)
  local cx = game.width / 2 + self.slide
  U.text(TR("garden_n", self.w), 0, 18, 12, W.acc, "center", game.width, "bold", false)
  U.text(TRd("g" .. self.w), cx - 200, 32, 24, "#FFFFFF", "center", 400, "bold")
  U.text(TRd("g" .. self.w .. "_d"), cx - 260, 62, 12, "#FFFFFFB0", "center", 520, "semibold", false)
  -- arrows
  self.rects = {}
  if self.w > 1 then
    G.icon("chevron_left", 28, game.height / 2, 34, "#FFFFFFB0")
    self.rects.prev = {6, game.height / 2 - 30, 44, 60}
  end
  if self.w < L.WORLDS then
    G.icon("chevron_right", game.width - 28, game.height / 2, 34, "#FFFFFFB0")
    self.rects.next = {game.width - 50, game.height / 2 - 30, 44, 60}
  end
  local cw, ch, gap = 66, 52, 10
  local gx = cx - (5 * cw + 4 * gap) / 2
  local gy = 92
  for i = 1, L.PER_WORLD do
    local n = (self.w - 1) * L.PER_WORLD + i
    local c, r = (i - 1) % 5, (i - 1) // 5
    local x, y = gx + c * (cw + gap), gy + r * (ch + gap)
    local lo = levelOpen(n)
    local sel = i == self.sel
    self.rects[i] = {x, y, cw, ch}
    if sel then G.rect(x - 3, y - 3, cw + 6, ch + 6, 12, W.acc .. "60") end
    G.rect(x, y, cw, ch, 10, sel and W.acc or (lo and "#FFFFFF1C" or "#00000040"))
    if lo then
      U.text(tostring(i), x, y + 7, 17, sel and "#0B1020" or "#FFFFFF", "center", cw, "bold", false)
      for s = 1, 3 do
        G.icon("star", x + cw / 2 + (s - 2) * 15, y + ch - 12, 13,
          stars[n] >= s and (sel and "#0B1020" or "#FFD166") or (sel and "#0B102050" or "#FFFFFF30"))
      end
    else
      G.icon("lock", x + cw / 2, y + ch / 2, 18, "#FFFFFF50")
    end
  end
  local info = open and TR("garden_stars", starsIn(self.w), L.PER_WORLD * 3) or TR("garden_locked")
  U.text(info, 0, gy + 4 * (ch + gap) + 6, 12, "#FFFFFFC0", "center", game.width, "semibold", false)
  K.prompts({{"confirm", TR("play")}, {"prev", TR("prev_garden")}, {"next", TR("next_garden")}, {"back", TR("k_back")}},
    game.width / 2, game.height - 24, 10)
  if K.device == "touch" then
    G.icon("arrow_back", 22, 22, 22, "#FFFFFFC0")
    self.rects.back = {4, 4, 40, 40}
  end
end

-- ======================================================================== PLAY
Play = {controls = false}
local PANEL = 128

function Play:enter(p)
  p = p or {}
  K.music("garden")
  self.p = p
  if p.board then
    self.base = p.board
  else
    self.base = L.level(p.n or 1)
  end
  self.n = p.n
  self.world = p.n and L.worldOf(p.n) or (p.world or 4)
  self:reset(true)
  self.cx, self.cy = floor(self.b.w / 2), floor(self.b.h / 2)
  self.t = 0
  self.won, self.winT = false, 0
  self.hinted = false
  self.repeatT = 0
  self.press = nil
  self.shake = 0
  self.hintCell = nil
  -- first-time tips for the new pieces of this level
  local has = {}
  for y = 0, self.b.h - 1 do
    for x = 0, self.b.w - 1 do
      local q = self.b.cells[y][x]
      if q then has[q.t] = true; if q.lock == "rot" then has.rot = true end
        if q.t == "emit" and q.c ~= 1 then has.colour = true end end
    end
  end
  for _, it in ipairs(self.b.inv) do has[it.t] = true end
  K.clearTips()
  if self.b.inv[1] then K.tip("place", TR("tip_place", K.btn("confirm") or TR("tap"), K.btn("next") or "")) end
  K.tip("rotate", TR("tip_rotate"), "sync")
  if has.rot then K.tip("rot", TR("tip_rot"), "sync") end
  if has.thorn then K.tip("thorn", TR("tip_thorn"), "warning") end
  if has.split then K.tip("split", TR("tip_split"), "call_split") end
  if has.colour then K.tip("colour", TR("tip_colour"), "palette") end
  if has.filter then K.tip("filter", TR("tip_filter"), "filter_alt") end
  if has.portal then K.tip("portal", TR("tip_portal"), "blur_circular") end
  if (p.n or 0) >= 4 then K.tip("undo", TR("tip_undo", K.btn("undo") or "", K.btn("hint") or ""), "undo") end
end

function Play:reset(first)
  self.b = L.copyBoard(self.base)
  self.sel = 1
  self.moves = 0
  self.undo = {}
  self.won = false
  for y = 0, self.b.h - 1 do
    for x = 0, self.b.w - 1 do
      local q = self.b.cells[y][x]
      if q and q.t == "target" then q.bloom = 0 end
    end
  end
  self:retrace(true)
  if not first then K.sfx("undo") end
end
function Play:restart() self:reset() end

function Play:snapshot()
  local s = {cells = {}, inv = {}, moves = self.moves}
  for y = 0, self.b.h - 1 do
    for x = 0, self.b.w - 1 do
      local q = self.b.cells[y][x]
      if q and (q.lock == "free" or q.lock == "rot") then s.cells[#s.cells + 1] = {x, y, L.copyPiece(q)} end
    end
  end
  for i, it in ipairs(self.b.inv) do s.inv[i] = it.n end
  self.undo[#self.undo + 1] = s
  if #self.undo > 200 then table.remove(self.undo, 1) end
end
function Play:doUndo()
  local s = table.remove(self.undo)
  if not s then K.sfx("ui_back") return end
  for y = 0, self.b.h - 1 do
    for x = 0, self.b.w - 1 do
      local q = self.b.cells[y][x]
      if q and (q.lock == "free" or q.lock == "rot") then self.b.cells[y][x] = nil end
    end
  end
  for _, c in ipairs(s.cells) do self.b.cells[c[2]][c[1]] = c[3] end
  for i, n in ipairs(s.inv) do self.b.inv[i].n = n end
  self.moves = s.moves
  K.sfx("undo")
  self:retrace()
end

function Play:retrace(silent)
  local before = self.tr
  self.tr = L.trace(self.b)
  local prevLit = {}
  if before then for q, m in pairs(before.hits) do prevLit[q] = m end end
  local any = false
  for y = 0, self.b.h - 1 do
    for x = 0, self.b.w - 1 do
      local q = self.b.cells[y][x]
      if q and q.t == "target" then
        local on = self.tr.hits[q] == q.need
        local was = before and before.hits[q] == q.need
        if on and not was and not silent then
          any = true
          local cx, cy = self:cellCenter(x, y)
          sparks:setColors({"#FFFFFF", COL[q.need], COL[q.need] .. "00"})
          sparks:emit(26, cx, cy)
        end
      elseif q and q.t == "thorn" then
        q.hit = self.tr.thorn == q or (self.tr.hits[q] ~= nil)
      end
    end
  end
  if any then K.sfx("bloom"); K.rumble(0.35, 40) end
  if self.tr.thorn and not silent and not (before and before.thorn) then
    K.sfx("thorn")
    self.shake = 0.35
    K.rumble(0.7, 120)
    K.tip("thorn", TR("tip_thorn"), "warning")
  end
  if self.tr.solved and not silent and not self.won then self:win() end
end

function Play:layout()
  local b = self.b
  local aw, ah = game.width - PANEL - 34, game.height - 62
  local cs = floor(min(aw / b.w, ah / b.h, 52))
  self.cs = cs
  self.ox = 16 + (aw - cs * b.w) / 2
  self.oy = 44 + (ah - cs * b.h) / 2
end
function Play:cellCenter(x, y)
  self:layout()
  return self.ox + (x + 0.5) * self.cs, self.oy + (y + 0.5) * self.cs
end
function Play:cellAt(px, py)
  self:layout()
  local x, y = floor((px - self.ox) / self.cs), floor((py - self.oy) / self.cs)
  if x < 0 or y < 0 or x >= self.b.w or y >= self.b.h then return nil end
  return x, y
end

-- A: place the chosen piece / turn the piece under the cursor
function Play:act(x, y)
  if self.won then return end
  local q = self.b.cells[y][x]
  if q then
    if q.lock == "free" or q.lock == "rot" then
      if q.t == "mirror" or q.t == "split" then
        self:snapshot()
        q.o = 1 - q.o
        self.moves = self.moves + 1
        K.sfx("rotate")
        K.tipDone("rotate")
        if q.lock == "rot" then K.tipDone("rot") end
        self:retrace()
      else
        K.sfx("ui_back")
      end
    else
      K.sfx("ui_back")
      self.shake = 0.12
    end
    return
  end
  local it = self.b.inv[self.sel]
  if not it or it.n <= 0 then
    for i, it2 in ipairs(self.b.inv) do if it2.n > 0 then self.sel = i; it = it2 break end end
    if not it or it.n <= 0 then K.sfx("ui_back") return end
  end
  self:snapshot()
  local np = invPiece(it)
  np.lock = "free"
  self.b.cells[y][x] = np
  it.n = it.n - 1
  self.moves = self.moves + 1
  K.sfx("place")
  K.tipDone("place")
  local cx, cy = self:cellCenter(x, y)
  sparks:setColors({"#FFFFFF", K.accent, K.accent .. "00"})
  sparks:emit(8, cx, cy)
  if self.hintCell and self.hintCell.x == x and self.hintCell.y == y then self.hintCell = nil end
  self:retrace()
end
-- X: put a placed piece back in the bag
function Play:take(x, y)
  if self.won then return end
  local q = self.b.cells[y][x]
  if not q or q.lock ~= "free" then K.sfx("ui_back") return end
  self:snapshot()
  for i, it in ipairs(self.b.inv) do
    if it.t == q.t and (q.t ~= "filter" or it.c == q.c) then it.n = it.n + 1; self.sel = i break end
  end
  self.b.cells[y][x] = nil
  self.moves = self.moves + 1
  K.sfx("take")
  self:retrace()
end
function Play:hint()
  if self.won then return end
  -- the first piece of the solution that is not in place yet
  for _, s in ipairs(self.b.sol) do
    local q = self.b.cells[s.y][s.x]
    local ok = q and q.t == s.t and (s.o == nil or q.o == s.o) and (s.c == nil or q.c == s.c)
    if not ok then
      self.hinted = true
      self.hintCell = s
      self.cx, self.cy = s.x, s.y
      if s.bag then
        for i, it in ipairs(self.b.inv) do
          if it.t == s.t and (s.t ~= "filter" or it.c == s.c) then self.sel = i end
        end
      end
      K.sfx("hint")
      K.tipDone("undo")
      return
    end
  end
  K.sfx("ui_back")
end

function Play:win()
  self.won, self.winT = true, 0
  local st = 1
  local par = self.b.par or 1
  if self.moves <= par then st = 3 elseif self.moves <= par * 2 + 2 then st = 2 end
  if self.hinted then st = min(st, 2) end
  self.stars = st
  self.record = false
  if self.n then
    if st > stars[self.n] then stars[self.n] = st; saveStars(); self.record = true end
    save:inc("solved_total", 1)
  end
  K.sfx("win")
  K.rumble(0.5, 160)
  for _ = 1, 3 do
    petals:emit(40, game.width * (0.2 + math.random() * 0.6), game.height * 0.3)
  end
  local items = {}
  if self.n and self.n < L.COUNT and levelOpen(self.n + 1) then
    items[#items + 1] = {label = TR("next_level"), icon = "skip_next", action = function() K.go(Play, {n = self.n + 1}, "circle", 0.35) end}
  end
  items[#items + 1] = {label = TR("retry"), icon = "replay", action = function() self:reset(); self.won = false end}
  if self.p.fromEditor then
    items[#items + 1] = {label = TR("back_editor"), icon = "edit", action = function() K.go(Editor, {sol = self.p.sol, slot = self.p.slot}) end}
  elseif self.p.custom then
    items[#items + 1] = {label = TR("my_gardens"), icon = "folder", action = function() K.go(MyLevels, {}) end}
  else
    items[#items + 1] = {label = TR("gardens"), icon = "grid_view", action = function() K.go(Gardens, {w = self.world, n = self.n}) end}
  end
  self.winMenu = K.menu{items = items, width = 210, itemHeight = 30, size = 13}
end

function Play:pauseItems()
  local items = {
    {label = TR("hint"), icon = "lightbulb", action = function() game.resume(); self:hint() end},
  }
  if self.p.fromEditor then
    items[#items + 1] = {label = TR("back_editor"), icon = "edit", action = function()
      game.paused = false
      K.go(Editor, {sol = self.p.sol, slot = self.p.slot})
    end}
  elseif self.n then
    items[#items + 1] = {label = TR("gardens"), icon = "grid_view", action = function()
      game.paused = false
      K.go(Gardens, {w = self.world, n = self.n})
    end}
  end
  return items
end

function Play:update(dt)
  self.t = self.t + dt
  if self.shake > 0 then self.shake = self.shake - dt end
  sparks:update(dt)
  petals:update(dt)
  -- buds open and close smoothly
  for y = 0, self.b.h - 1 do
    for x = 0, self.b.w - 1 do
      local q = self.b.cells[y][x]
      if q and q.t == "target" then
        local goal = (self.tr.hits[q] == q.need) and 1 or 0
        q.bloom = (q.bloom or 0) + (goal - (q.bloom or 0)) * min(1, dt * 6)
      end
    end
  end
  if self.won then
    self.winT = self.winT + dt
    if self.winT > 1.1 then self.winMenu:update() end
    return
  end
  -- cursor with key repeat
  local mx, my = 0, 0
  if I.pressed("left") then mx = -1 elseif I.pressed("right") then mx = 1 end
  if I.pressed("up") then my = -1 elseif I.pressed("down") then my = 1 end
  local held = I.down("left") or I.down("right") or I.down("up") or I.down("down")
  if mx ~= 0 or my ~= 0 then
    self.repeatT = 0.3
  elseif held then
    self.repeatT = self.repeatT - dt
    if self.repeatT <= 0 then
      self.repeatT = 0.085
      mx = I.down("left") and -1 or (I.down("right") and 1 or 0)
      my = I.down("up") and -1 or (I.down("down") and 1 or 0)
    end
  end
  if mx ~= 0 or my ~= 0 then
    self.cx = (self.cx + mx) % self.b.w
    self.cy = (self.cy + my) % self.b.h
    K.sfx("move")
  end
  local n = #self.b.inv
  if n > 0 then
    if I.pressed("next") then self.sel = self.sel % n + 1; K.sfx("ui_move"); K.tipDone("place") end
    if I.pressed("prev") then self.sel = (self.sel - 2) % n + 1; K.sfx("ui_move") end
  end
  if I.pressed("confirm") then self:act(self.cx, self.cy) end
  if I.pressed("take") then self:take(self.cx, self.cy) end
  if I.pressed("undo") then self:doUndo() end
  if I.pressed("hint") then self:hint() end
  if I.pressed("reset") then self:snapshot(); self:reset() end
  -- pointer: tap a cell to place / turn, hold to pick up; tap the bag to choose
  local pt = I.pointer
  if pt.pressed then
    local x, y = self:cellAt(pt.x, pt.y)
    self.press = {x = x, y = y, t = 0, px = pt.x, py = pt.y, used = false}
    if x then self.cx, self.cy = x, y end
  end
  if self.press and pt.down then
    self.press.t = self.press.t + dt
    local pr = self.press
    if pr.x and not pr.used and pr.t > 0.45 then
      pr.used = true
      self:take(pr.x, pr.y)
    end
  end
  if pt.released and self.press then
    local pr = self.press
    self.press = nil
    if not pr.used then
      local x, y = self:cellAt(pt.x, pt.y)
      if x and x == pr.x and y == pr.y then
        self:act(x, y)
      else
        self:panelTap(pt.x, pt.y)
      end
    end
  end
end

function Play:panelTap(px, py)
  for i, r in pairs(self.slots or {}) do
    if px >= r[1] and py >= r[2] and px < r[1] + r[3] and py < r[2] + r[4] then
      if type(i) == "number" then self.sel = i; K.sfx("ui_move"); K.tipDone("place")
      elseif i == "undo" then self:doUndo()
      elseif i == "reset" then self:snapshot(); self:reset()
      elseif i == "hint" then self:hint()
      elseif i == "pause" then game.pause() end
      return
    end
  end
end

function Play:draw()
  local W = WORLD[self.world] or WORLD[1]
  K.accent = W.acc
  drawBackdrop(W.top, W.bot, W.acc)
  self:layout()
  local b, cs, ox, oy = self.b, self.cs, self.ox, self.oy
  local t = game.realTime
  local sx, sy = 0, 0
  if self.shake > 0 then
    local k = self.shake * 14 * K.shakeScale()
    sx, sy = (math.random() - 0.5) * k, (math.random() - 0.5) * k
  end
  G.push(sx, sy)
  -- board
  G.rect(ox - 8, oy - 8, cs * b.w + 16, cs * b.h + 16, 14, "#0000004A")
  G.rect(ox - 6, oy - 6, cs * b.w + 12, cs * b.h + 12, 12, "#FFFFFF10")
  for y = 0, b.h - 1 do
    for x = 0, b.w - 1 do
      G.rect(ox + x * cs + 1.5, oy + y * cs + 1.5, cs - 3, cs - 3, cs * 0.16, ((x + y) % 2 == 0) and "#FFFFFF10" or "#FFFFFF0A")
    end
  end
  -- beams
  local s = self.tr.segs
  for i = 1, self.tr.n, 5 do
    glowLine(ox + s[i] * cs, oy + s[i + 1] * cs, ox + s[i + 2] * cs, oy + s[i + 3] * cs, COL[s[i + 4]], cs * 0.5)
  end
  -- photons travelling along the beams
  for i = 1, self.tr.n, 5 do
    local x1, y1, x2, y2 = s[i], s[i + 1], s[i + 2], s[i + 3]
    local len = abs(x2 - x1) + abs(y2 - y1)
    if len > 0.01 then
      local k = ((t * 3.2 + i * 0.37) % 1)
      for j = 0, floor(len) do
        local f = (k + j) / max(len, 1)
        if f <= 1 then
          G.circle(ox + (x1 + (x2 - x1) * f) * cs, oy + (y1 + (y2 - y1) * f) * cs, cs * 0.06, "#FFFFFFE0")
        end
      end
    end
  end
  -- pieces
  for y = 0, b.h - 1 do
    for x = 0, b.w - 1 do
      local q = b.cells[y][x]
      if q then drawPiece(q, ox + (x + 0.5) * cs, oy + (y + 0.5) * cs, cs, t) end
    end
  end
  -- hint ghost
  local hc = self.hintCell
  if hc and not self.won then
    local hx, hy = ox + (hc.x + 0.5) * cs, oy + (hc.y + 0.5) * cs
    G.alpha(0.45 + 0.25 * sin(t * 6))
    drawPiece({t = hc.t, o = hc.o, c = hc.c}, hx, hy, cs, t)
    G.unalpha()
    G.color("#FFE14D")
    G.rectLine(ox + hc.x * cs + 2, oy + hc.y * cs + 2, cs - 4, cs - 4, cs * 0.16, 2)
  end
  -- cursor
  if not self.won and K.device ~= "touch" then
    local pulse = 1 + 0.06 * sin(t * 6)
    local cx, cy = ox + (self.cx + 0.5) * cs, oy + (self.cy + 0.5) * cs
    local hs = cs * 0.5 * pulse
    G.color(W.acc)
    G.rectLine(cx - hs, cy - hs, hs * 2, hs * 2, cs * 0.18, 2.2)
    local it = self.b.inv[self.sel]
    if not b.cells[self.cy][self.cx] and it and it.n > 0 then
      G.alpha(0.35)
      drawPiece(invPiece(it), cx, cy, cs, t)
      G.unalpha()
    end
  end
  sparks:draw()
  G.pop()
  self:drawPanel(W)
  self:drawTop(W)
  petals:draw()
  if self.won then self:drawWin(W) end
end

function Play:drawTop(W)
  local title
  if self.n then
    title = TR("level_title", L.worldOf(self.n), (self.n - 1) % L.PER_WORLD + 1)
  else
    title = (self.base.name and self.base.name ~= "") and self.base.name or TR("custom_level")
  end
  U.text(title, 16, 10, 15, "#FFFFFF", "left", nil, "bold")
  local lit = self.tr.lit .. "/" .. self.tr.targets
  G.icon("local_florist", 22, 40, 14, W.acc)
  U.text(TR("bloomed", lit), 32, 33, 11, "#FFFFFFC0", "left", nil, "semibold", false)
  local par = self.b.par or 0
  local mw = game.width - PANEL - 26
  U.text(TR("moves", self.moves), mw - 160, 12, 12, "#FFFFFFD0", "right", 160, "semibold", false)
  U.text(TR("par", par), mw - 160, 28, 11, "#FFFFFF90", "right", 160, "semibold", false)
end

function Play:drawPanel(W)
  local x = game.width - PANEL - 10
  local y = 10
  local h = game.height - 20
  G.rect(x, y, PANEL, h, 14, "#0B1020B0")
  G.color(W.acc .. "50")
  G.rectLine(x, y, PANEL, h, 14, 1)
  U.text(TR("bag"), x, y + 8, 12, W.acc, "center", PANEL, "bold", false)
  self.slots = {}
  local sy = y + 28
  local t = game.realTime
  if #self.b.inv == 0 then
    U.text(TR("bag_empty"), x + 8, sy + 6, 10, "#FFFFFF80", "center", PANEL - 16, "semibold", false)
  end
  for i, it in ipairs(self.b.inv) do
    local sel = i == self.sel
    local sh = 46
    if sel then G.rect(x + 8, sy, PANEL - 16, sh, 10, W.acc .. "40") end
    G.rect(x + 10, sy + 2, PANEL - 20, sh - 4, 9, sel and W.acc .. "30" or "#FFFFFF0C")
    G.alpha(it.n > 0 and 1 or 0.35)
    drawPiece(invPiece(it), x + 34, sy + sh / 2, 34, t)
    G.unalpha()
    U.text("×" .. it.n, x + 58, sy + 12, 17, it.n > 0 and "#FFFFFF" or "#FFFFFF60", "left", nil, "bold", false)
    self.slots[i] = {x + 8, sy, PANEL - 16, sh}
    sy = sy + sh + 4
  end
  if #self.b.inv > 1 and K.btn("next") then
    K.prompts({{"prev", ""}, {"next", TR("choose")}}, x + PANEL / 2, sy + 4, 9)
  end
  -- buttons
  local by = y + h - 40
  local names = {{"undo", "undo"}, {"reset", "restart_alt"}, {"hint", "lightbulb"}, {"pause", "menu"}}
  local bw = (PANEL - 16) / 4
  for i, nb in ipairs(names) do
    local bx = x + 8 + (i - 1) * bw
    G.rect(bx + 2, by, bw - 4, 30, 9, "#FFFFFF14")
    G.icon(nb[2], bx + bw / 2, by + 15, 17, "#FFFFFFD0")
    self.slots[nb[1]] = {bx, by, bw, 30}
  end
  if K.device ~= "touch" then
    local function hintLine(action, text, yy)
      local b = K.btn(action)
      if b then K.glyph(b, x + 12, yy, 9); U.text(text, x + 40, yy + 1, 9, "#FFFFFFA0", "left", nil, "semibold", false) end
    end
    hintLine("confirm", TR("act_place"), by - 64)
    hintLine("take", TR("act_take"), by - 48)
    hintLine("undo", TR("act_undo"), by - 32)
    hintLine("hint", TR("hint"), by - 16)
  end
end

function Play:drawWin(W)
  if self.winT < 1.1 then return end
  local k = min(1, (self.winT - 1.1) / 0.35)
  G.rect(0, 0, game.width, game.height, 0, string.format("#000000%02X", floor(140 * k)))
  local w, h = 300, 230
  local x, y = (game.width - w) / 2, (game.height - h) / 2 + (1 - k) * 30
  G.alpha(k)
  K.frame(x, y, w, h, TR("bloomed_title"), W.acc)
  for s = 1, 3 do
    local on = s <= self.stars
    local sk = min(1, max(0, (self.winT - 1.3 - s * 0.18) / 0.25))
    local sz = on and (26 + 10 * (1 - sk)) or 26
    G.icon("star", x + w / 2 + (s - 2) * 40, y + 66, sz, on and string.format("#FFD166%02X", floor(255 * sk)) or "#FFFFFF30")
  end
  U.text(TR("result_moves", self.moves, self.b.par or 0), x, y + 88, 12, "#FFFFFFD0", "center", w, "semibold", false)
  if self.record then U.text(TR("k_new_record"), x, y + 104, 11, "#FFD166", "center", w, "bold", false) end
  G.unalpha()
  self.winMenu:draw(x + w / 2, y + 124)
end

-- ======================================================================== EDITOR
Editor = {controls = false}
local TOOLS = {"wall", "emit", "target", "thorn", "mirror", "split", "filter", "portal", "erase"}
local TOOL_ICON = {wall = "square", emit = "wb_sunny", target = "local_florist", thorn = "warning", mirror = "flip",
                   split = "call_split", filter = "filter_alt", portal = "blur_circular", erase = "backspace"}

function Editor:enter(p)
  p = p or {}
  K.music("garden")
  self.sol = p.sol and L.copyBoard(p.sol) or nil
  if not self.sol then
    self.sol = L.newBoard(8, 6)
    self.sol.cells[2][0] = {t = "emit", c = 1, d = 0, lock = "fixed"}
    self.sol.cells[2][7] = {t = "target", lock = "fixed"}
  end
  self.slot = p.slot
  self.name = p.name or (p.slot and customs[p.slot] and customs[p.slot].name) or ""
  self.tool = 5
  self.cx, self.cy = 0, 0
  self.repeatT = 0
  self.t = 0
  self:retrace()
  K.clearTips()
  K.tip("editor", TR("tip_editor"), "edit", 7)
  K.tip("editor2", TR("tip_editor2"), "inventory_2", 7)
end
function Editor:retrace()
  for y = 0, self.sol.h - 1 do
    for x = 0, self.sol.w - 1 do
      local q = self.sol.cells[y][x]
      if q and q.t == "target" then q.need = 7 end
    end
  end
  self.tr = L.trace(self.sol)
  for y = 0, self.sol.h - 1 do
    for x = 0, self.sol.w - 1 do
      local q = self.sol.cells[y][x]
      if q and q.t == "target" then q.need = self.tr.hits[q] or 0; q.bloom = q.need > 0 and 1 or 0 end
      if q and q.t == "thorn" then q.hit = self.tr.hits[q] ~= nil end
    end
  end
  self.tr = L.trace(self.sol)   -- again, now that every bud wants what it gets
end
function Editor:layout()
  local b = self.sol
  local aw, ah = game.width - 40, game.height - 120
  local cs = floor(min(aw / b.w, ah / b.h, 46))
  self.cs = cs
  self.ox = (game.width - cs * b.w) / 2
  self.oy = 40 + (ah - cs * b.h) / 2
end
local function nextPortalId(b)
  local count = {}
  for y = 0, b.h - 1 do
    for x = 0, b.w - 1 do
      local q = b.cells[y][x]
      if q and q.t == "portal" then count[q.id] = (count[q.id] or 0) + 1 end
    end
  end
  for id = 1, 3 do if (count[id] or 0) < 2 then return id end end
  return nil
end
function Editor:apply(x, y)
  local tool = TOOLS[self.tool]
  local q = self.sol.cells[y][x]
  if tool == "erase" then
    if q then self.sol.cells[y][x] = nil; K.sfx("take") end
  elseif q and q.t == tool then
    -- same piece again: change its variant
    if tool == "emit" then
      q.d = (q.d + 1) % 4
      if q.d == 0 then
        local order = {1, 2, 4, 3, 5, 6, 7}
        local i = 1
        for k, v in ipairs(order) do if v == q.c then i = k end end
        q.c = order[i % #order + 1]
      end
    elseif tool == "mirror" or tool == "split" then q.o = 1 - q.o
    elseif tool == "filter" then q.c = q.c == 1 and 2 or (q.c == 2 and 4 or 1)
    elseif tool == "portal" then q.id = q.id % 3 + 1 end
    K.sfx("rotate")
  else
    local np = {t = tool, lock = "fixed"}
    if tool == "emit" then np.c, np.d = 1, 0
    elseif tool == "mirror" or tool == "split" then np.o = 0; np.lock = "bag"
    elseif tool == "filter" then np.c = 1
    elseif tool == "portal" then
      np.id = nextPortalId(self.sol)
      if not np.id then game.toast(TR("ed_portals_full")) return end
    end
    self.sol.cells[y][x] = np
    K.sfx("place")
  end
  self:retrace()
end
function Editor:cycleLock(x, y)
  local q = self.sol.cells[y][x]
  if not q or not (q.t == "mirror" or q.t == "split" or q.t == "filter") then K.sfx("ui_back") return end
  if q.t == "filter" then q.lock = q.lock == "bag" and "fixed" or "bag"
  else q.lock = q.lock == "fixed" and "rot" or (q.lock == "rot" and "bag" or "fixed") end
  K.sfx("ui_ok")
  K.tipDone("editor2")
  game.toast(TRd("lock_" .. q.lock))
end
function Editor:resize(dw, dh)
  local w, h = max(4, min(10, self.sol.w + dw)), max(3, min(7, self.sol.h + dh))
  local nb = L.newBoard(w, h)
  for y = 0, h - 1 do
    for x = 0, w - 1 do nb.cells[y][x] = (y < self.sol.h and x < self.sol.w) and self.sol.cells[y][x] or nil end
  end
  self.sol = nb
  self.cx, self.cy = min(self.cx, w - 1), min(self.cy, h - 1)
  self:retrace()
end
function Editor:validate()
  if self.tr.targets == 0 then return false, TR("ed_need_target") end
  if not self.tr.solved then return false, TR("ed_not_solved") end
  local bag = 0
  for y = 0, self.sol.h - 1 do
    for x = 0, self.sol.w - 1 do
      local q = self.sol.cells[y][x]
      if q and (q.lock == "bag" or q.lock == "rot") then bag = bag + 1 end
    end
  end
  if bag == 0 then return false, TR("ed_need_bag") end
  return true
end
function Editor:test()
  local ok, why = self:validate()
  if not ok then game.toast(why, 3) K.sfx("thorn") return end
  local lvl = L.prepare(L.copyBoard(self.sol))
  lvl.name = self.name
  K.go(Play, {board = lvl, custom = true, fromEditor = true, sol = L.copyBoard(self.sol), slot = self.slot, world = 4}, "circle", 0.35)
end
function Editor:saveLevel()
  local ok, why = self:validate()
  if not ok then game.toast(why, 3) K.sfx("thorn") return end
  local function store(name)
    self.name = name or self.name
    if self.name == "" then self.name = TR("custom_n", #customs + 1) end
    local code = L.encode(self.sol, self.name)
    if self.slot and customs[self.slot] then
      customs[self.slot] = {name = self.name, code = code}
    else
      if #customs >= 24 then game.toast(TR("ed_full")) return end
      customs[#customs + 1] = {name = self.name, code = code}
      self.slot = #customs
    end
    saveCustoms()
    K.sfx("win")
    game.toast(TR("ed_saved", self.name))
  end
  if ui and ui.keyboard then
    ui.keyboard(self.name ~= "" and self.name or TR("custom_n", #customs + 1), function(text)
      if text and text ~= "" then store(text:sub(1, 28)) end
    end, TR("ed_name"))
  else
    store()
  end
end
function Editor:share()
  local code = L.encode(self.sol, self.name)
  sys.clipboard(code)
  game.toast(TR("ed_copied"))
  K.sfx("ui_ok")
end
function Editor:import()
  local code = sys.clipboard()
  local sol = L.decode(code)
  if not sol then game.toast(TR("ed_bad_code")) K.sfx("thorn") return end
  self.sol, self.slot, self.name = sol, nil, sol.name or ""
  self.cx, self.cy = 0, 0
  self:retrace()
  game.toast(TR("ed_imported"))
  K.sfx("ui_ok")
end
function Editor:pauseItems()
  return {
    {label = TR("ed_test"), icon = "play_arrow", action = function() game.paused = false; game.resume(); self:test() end},
    {label = TR("ed_save"), icon = "save", action = function() game.resume(); self:saveLevel() end},
    {label = TR("ed_share"), icon = "share", action = function() game.resume(); self:share() end},
    {label = TR("ed_import"), icon = "content_paste", action = function() game.resume(); self:import() end},
    {label = TR("ed_size"), icon = "aspect_ratio", value = function() return self.sol.w .. "×" .. self.sol.h end,
     left = function() self:resize(-1, 0) end, right = function() self:resize(1, 0) end},
    {label = TR("ed_height"), icon = "height", value = function() return tostring(self.sol.h) end,
     left = function() self:resize(0, -1) end, right = function() self:resize(0, 1) end},
    {label = TR("ed_clear"), icon = "delete_sweep", action = function()
      game.resume()
      self.sol = L.newBoard(self.sol.w, self.sol.h)
      self:retrace()
    end},
  }
end
function Editor:update(dt)
  self.t = self.t + dt
  local mx, my = 0, 0
  if I.pressed("left") then mx = -1 elseif I.pressed("right") then mx = 1 end
  if I.pressed("up") then my = -1 elseif I.pressed("down") then my = 1 end
  local held = I.down("left") or I.down("right") or I.down("up") or I.down("down")
  if mx ~= 0 or my ~= 0 then self.repeatT = 0.3
  elseif held then
    self.repeatT = self.repeatT - dt
    if self.repeatT <= 0 then
      self.repeatT = 0.085
      mx = I.down("left") and -1 or (I.down("right") and 1 or 0)
      my = I.down("up") and -1 or (I.down("down") and 1 or 0)
    end
  end
  if mx ~= 0 or my ~= 0 then
    self.cx, self.cy = (self.cx + mx) % self.sol.w, (self.cy + my) % self.sol.h
    K.sfx("move")
  end
  if I.pressed("next") then self.tool = self.tool % #TOOLS + 1; K.sfx("ui_move"); K.tipDone("editor") end
  if I.pressed("prev") then self.tool = (self.tool - 2) % #TOOLS + 1; K.sfx("ui_move") end
  if I.pressed("confirm") then self:apply(self.cx, self.cy) end
  if I.pressed("take") then self.sol.cells[self.cy][self.cx] = nil; K.sfx("take"); self:retrace() end
  if I.pressed("hint") then self:cycleLock(self.cx, self.cy) end
  if I.pressed("tool") then self:test() end
  local pt = I.pointer
  if pt.released then
    self:layout()
    local x, y = floor((pt.x - self.ox) / self.cs), floor((pt.y - self.oy) / self.cs)
    if x >= 0 and y >= 0 and x < self.sol.w and y < self.sol.h then
      if self.cx == x and self.cy == y then self:apply(x, y) else self.cx, self.cy = x, y; K.sfx("move") end
    else
      for i, r in pairs(self.rects or {}) do
        if pt.x >= r[1] and pt.y >= r[2] and pt.x < r[1] + r[3] and pt.y < r[2] + r[4] then
          if type(i) == "number" then self.tool = i; K.sfx("ui_move")
          elseif i == "lock" then self:cycleLock(self.cx, self.cy)
          elseif i == "test" then self:test()
          elseif i == "menu" then game.pause() end
        end
      end
    end
  end
end
function Editor:draw()
  K.accent = "#FFB547"
  drawBackdrop("#151B30", "#2A1E40", "#FFB547")
  self:layout()
  local b, cs, ox, oy = self.sol, self.cs, self.ox, self.oy
  local t = game.realTime
  U.text(TR("editor"), 16, 10, 16, "#FFFFFF", "left", nil, "bold")
  U.text(self.name ~= "" and self.name or TR("untitled"), 16, 30, 11, "#FFFFFFA0", "left", nil, "semibold", false)
  local ok, why = self:validate()
  U.text(ok and TR("ed_ready") or why, game.width - 316, 14, 11, ok and "#7CFF9B" or "#FFD166", "right", 300, "semibold", false)
  G.rect(ox - 6, oy - 6, cs * b.w + 12, cs * b.h + 12, 12, "#FFFFFF10")
  for y = 0, b.h - 1 do
    for x = 0, b.w - 1 do
      G.rect(ox + x * cs + 1.5, oy + y * cs + 1.5, cs - 3, cs - 3, cs * 0.16, ((x + y) % 2 == 0) and "#FFFFFF10" or "#FFFFFF0A")
    end
  end
  local s = self.tr.segs
  for i = 1, self.tr.n, 5 do
    glowLine(ox + s[i] * cs, oy + s[i + 1] * cs, ox + s[i + 2] * cs, oy + s[i + 3] * cs, COL[s[i + 4]], cs * 0.5)
  end
  for y = 0, b.h - 1 do
    for x = 0, b.w - 1 do
      local q = b.cells[y][x]
      if q then
        local cx, cy = ox + (x + 0.5) * cs, oy + (y + 0.5) * cs
        drawPiece(q, cx, cy, cs, t)
        if q.lock == "bag" then
          G.color("#FFD166")
          G.rectLine(ox + x * cs + 3, oy + y * cs + 3, cs - 6, cs - 6, cs * 0.14, 1.4)
          G.icon("inventory_2", ox + x * cs + cs - 9, oy + y * cs + 9, cs * 0.24, "#FFD166")
        end
      end
    end
  end
  local cx, cy = ox + (self.cx + 0.5) * cs, oy + (self.cy + 0.5) * cs
  G.color("#FFB547")
  G.rectLine(cx - cs / 2, cy - cs / 2, cs, cs, cs * 0.18, 2.2)
  -- tool bar
  self.rects = {}
  local n = #TOOLS
  local tw = 40
  local tx = (game.width - n * tw - 80) / 2
  local ty = game.height - 64
  G.rect(tx - 8, ty - 6, n * tw + 96, 46, 12, "#0B1020C0")
  for i, tool in ipairs(TOOLS) do
    local x = tx + (i - 1) * tw
    local sel = i == self.tool
    G.rect(x + 2, ty, tw - 4, 34, 9, sel and "#FFB547" or "#FFFFFF14")
    G.icon(TOOL_ICON[tool], x + tw / 2, ty + 17, 19, sel and "#0B1020" or "#FFFFFFD0")
    self.rects[i] = {x, ty, tw, 34}
  end
  local bx = tx + n * tw + 6
  G.rect(bx, ty, 34, 34, 9, "#FFFFFF14"); G.icon("inventory_2", bx + 17, ty + 17, 18, "#FFD166")
  self.rects.lock = {bx, ty, 34, 34}
  G.rect(bx + 38, ty, 34, 34, 9, "#3DFF8A40"); G.icon("play_arrow", bx + 55, ty + 17, 20, "#FFFFFF")
  self.rects.test = {bx + 38, ty, 34, 34}
  G.rect(game.width - 44, 8, 34, 30, 9, "#FFFFFF14"); G.icon("menu", game.width - 27, 23, 18, "#FFFFFFD0")
  self.rects.menu = {game.width - 44, 8, 34, 30}
  U.text(TRd("tool_" .. TOOLS[self.tool]), 0, ty - 22, 11, "#FFFFFFD0", "center", game.width, "semibold", false)
  if K.device ~= "touch" then
    K.prompts({{"confirm", TR("ed_apply")}, {"take", TR("ed_erase")}, {"hint", TR("ed_lock")}, {"tool", TR("ed_test")},
               {"pause", TR("ed_menu")}}, game.width / 2, game.height - 18, 9)
  end
end

-- ======================================================================== MY GARDENS
MyLevels = {pausable = false}
function MyLevels:enter()
  K.music("title")
  self:build()
end
function MyLevels:build()
  local items = {}
  for i, c in ipairs(customs) do
    items[#items + 1] = {label = c.name, icon = "local_florist", action = function() self:open(i) end}
  end
  items[#items + 1] = {label = TR("ed_new"), icon = "add", action = function() K.go(Editor, {}) end}
  items[#items + 1] = {label = TR("ed_import"), icon = "content_paste", action = function()
    local sol = L.decode(sys.clipboard())
    if not sol then game.toast(TR("ed_bad_code")) return end
    customs[#customs + 1] = {name = (sol.name ~= "" and sol.name) or TR("custom_n", #customs + 1), code = L.encode(sol, sol.name)}
    saveCustoms()
    game.toast(TR("ed_imported"))
    self:build()
  end}
  items[#items + 1] = {label = TR("k_back"), icon = "arrow_back", action = function() K.go(Title) end}
  self.menu = K.menu{items = items, width = 300, itemHeight = 28, size = 12, onBack = function() K.go(Title) end,
                     selected = self.menu and min(self.menu.selected, #items) or 1}
end
function MyLevels:open(i)
  local c = customs[i]
  local sol = c and L.decode(c.code)
  if not sol then game.toast(TR("ed_bad_code")) return end
  U.dialog{title = c.name, buttons = {TR("play"), TR("ed_edit"), TR("ed_share"), TR("ed_delete"), TR("k_back")},
           onClose = function(k)
             if k == 1 then
               local lvl = L.prepare(L.copyBoard(sol))
               lvl.name = c.name
               K.go(Play, {board = lvl, custom = true, world = 4}, "circle", 0.35)
             elseif k == 2 then K.go(Editor, {sol = sol, slot = i, name = c.name})
             elseif k == 3 then sys.clipboard(c.code); game.toast(TR("ed_copied"))
             elseif k == 4 then table.remove(customs, i); saveCustoms(); self:build() end
           end}
end
function MyLevels:update() self.menu:update() end
function MyLevels:draw()
  K.accent = "#FFB547"
  drawBackdrop("#141A38", "#3A2050", "#FFB547")
  U.text(TR("my_gardens"), 0, 18, 22, "#FFFFFF", "center", game.width, "bold")
  U.text(#customs == 0 and TR("my_empty") or TR("my_count", #customs), 0, 46, 11, "#FFFFFFA0", "center", game.width, "semibold", false)
  local n = #self.menu.items
  local top = 70
  local visible = floor((game.height - top - 20) / 28)
  local first = max(0, self.menu.selected - visible)
  G.push(0, -first * 28)
  self.menu:draw(game.width / 2, top)
  G.pop()
  if first > 0 then
    -- pointer rects follow the scroll
    for _, r in pairs(self.menu.rects) do r.y = r.y - first * 28 end
  end
  local _ = n
end

-- ======================================================================== run
return K.run{
  width = 640, height = 360, scene = Title, title = Title, background = "#141A38", accent = "#FFB547", dark = "#0B0F20",
  difficulty = false,
  controls = {"take", "prev", "next", "undo", "hint", "reset"},
  onReset = function()
    for i = 1, L.COUNT do stars[i] = 0 end
    saveStars()
  end,
}
