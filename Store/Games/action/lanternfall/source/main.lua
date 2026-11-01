-- Lanternfall: a 2D action platformer. Carry the last lantern through the Mossy Hollow, the Crystal Caverns and the
-- Sky Ruins; learn the double jump, the dash and the wall jump at old altars, light shrines to save, find three star
-- shards in every level and defeat a guardian at the end of each world. Built on nexvyn.game with the shared kit.
local game = require("nexvyn.game")
local K = require("kit")
local LV = require("levels")
local G, I, U, A = game.gfx, game.input, game.ui, game.audio
local floor, min, max, sin, cos, abs, pi, sqrt, atan, random = math.floor, math.min, math.max, math.sin, math.cos,
  math.abs, math.pi, math.sqrt, math.atan, math.random

local TRd = function(k, ...) return TR(k, ...) end
local TS = 20

-- ---------------------------------------------------------------- worlds
local THEME = {
  hollow = {sky1 = "#7EC8F2", sky2 = "#FBE6C2", far = "#9CCB9A", mid = "#5E9F62", near = "#3E7A4A", ground = "#5B3A29",
            ground2 = "#4A2F22", cap = "#5CC45C", cap2 = "#8BE07A", plank = "#B07A4A", accent = "#FFB547", music = "hollow"},
  caverns = {sky1 = "#0B1030", sky2 = "#1B1446", far = "#24245A", mid = "#1C1C44", near = "#141434", ground = "#2E2A4A",
             ground2 = "#24203C", cap = "#5FD8F0", cap2 = "#B7F4FF", plank = "#5A4E8A", accent = "#7FE7FF", music = "caverns"},
  ruins = {sky1 = "#8FA8F0", sky2 = "#FFD6E8", far = "#C2B4E0", mid = "#A797C8", near = "#8A7AAE", ground = "#B9A58A",
           ground2 = "#9C8A70", cap = "#EDE4D2", cap2 = "#FFFFFF", plank = "#8C6B4E", accent = "#FF8FB8", music = "ruins"},
}

-- ---------------------------------------------------------------- sound and music
K.track("title", "bundle:/music/title.ogg", 21.818)
K.track("hollow", "bundle:/music/hollow.ogg", 17.143)
K.track("caverns", "bundle:/music/caverns.ogg", 20)
K.track("ruins", "bundle:/music/ruins.ogg", 16)
K.track("boss", "bundle:/music/boss.ogg", 13.714)
K.sound("ui_move", "bundle:/sfx/ui_move.wav", 0.6)
K.sound("ui_ok", "bundle:/sfx/ui_ok.wav", 0.7)
K.sound("ui_back", "bundle:/sfx/ui_back.wav", 0.6)
K.sound("jump", "bundle:/sfx/jump.wav", 0.55, 0.05)
K.sound("djump", "bundle:/sfx/djump.wav", 0.6, 0.05)
K.sound("land", "bundle:/sfx/land.wav", 0.4, 0.08)
K.sound("swing", {"bundle:/sfx/swing1.wav", "bundle:/sfx/swing2.wav"}, 0.55, 0.05)
K.sound("hit", "bundle:/sfx/hit.wav", 0.7, 0.04)
K.sound("stomp", "bundle:/sfx/stomp.wav", 0.7, 0.05)
K.sound("ember", {"bundle:/sfx/ember1.wav", "bundle:/sfx/ember2.wav", "bundle:/sfx/ember3.wav"}, 0.45, 0.03)
K.sound("shard", "bundle:/sfx/shard.wav", 0.9)
K.sound("hurt", "bundle:/sfx/hurt.wav", 0.8, 0.2)
K.sound("die", "bundle:/sfx/die.wav", 0.9, 0.5)
K.sound("dash", "bundle:/sfx/dash.wav", 0.6, 0.05)
K.sound("spring", "bundle:/sfx/spring.wav", 0.7, 0.1)
K.sound("crumble", "bundle:/sfx/crumble.wav", 0.6, 0.1)
K.sound("shrine", "bundle:/sfx/shrine.wav", 0.9)
K.sound("ability", "bundle:/sfx/ability.wav", 1.0)
K.sound("clear", "bundle:/sfx/clear.wav", 1.0)
K.sound("boss_hit", "bundle:/sfx/boss_hit.wav", 0.8, 0.1)
K.sound("boom", "bundle:/sfx/boom.wav", 0.8, 0.1)
K.sound("shoot", "bundle:/sfx/shoot.wav", 0.5, 0.1)

-- ---------------------------------------------------------------- input
I.bind("jump", {pad = {"a", "b"}, key = {"space", "z", "up", "w"}, touch = {"button:jump", "stick:up"}})
I.bind("attack", {pad = {"x", "y"}, key = {"x", "j"}, touch = "button:attack"})
I.bind("dash", {pad = {"zr", "r"}, key = {"c", "k"}, touch = "button:dash"})
I.touchControls{stick = true, buttons = {{id = "jump", icon = "arrow_upward", action = "jump"},
                                         {id = "attack", icon = "flare", action = "attack"},
                                         {id = "dash", icon = "double_arrow", action = "dash"}}}

-- ---------------------------------------------------------------- save slots
local slotIndex = K.prefs:get("slot", 1)
local slot
local function openSlot(i)
  slotIndex = i
  K.prefs:set("slot", i)
  slot = game.save.slot(i)
end
local function has(ab) return slot and slot:get("ab_" .. ab, false) end
local function shardsOf(n)
  local s = slot:get("shards", {})
  return type(s) == "table" and (s[tostring(n)] or 0) or 0
end
local function setShards(n, mask)
  local s = slot:get("shards", {})
  if type(s) ~= "table" then s = {} end
  s[tostring(n)] = mask
  slot:set("shards", s)
end
local function totalShards()
  local t = 0
  for n = 1, #LV.LEVELS do
    local m = shardsOf(n)
    t = t + (m & 1) + ((m >> 1) & 1) + ((m >> 2) & 1)
  end
  return t
end
local function maxHearts() return K.pick(5, 4, 3) + (slot and slot:get("bonusHeart", 0) or 0) end

-- ---------------------------------------------------------------- particles
local dust = game.emitter{max = 160, life = {0.25, 0.55}, speed = {20, 90}, size = {4, 0}, damping = 4, gravity = -30,
                          colors = {"#FFFFFFB0", "#FFFFFF00"}, shape = "circle"}
local sparks = game.emitter{max = 300, life = {0.3, 0.8}, speed = {50, 220}, size = {3.5, 0}, damping = 2.5, gravity = 200,
                            colors = {"#FFFFFF", "#FFD36A", "#FF8A1A00"}, shape = "square"}
local motes = game.emitter{max = 120, life = {2, 4}, speed = {4, 16}, size = {2.2, 0}, damping = 0.2, gravity = -8,
                           colors = {"#FFE9A8", "#FFE9A800"}, shape = "circle"}

-- ---------------------------------------------------------------- tiles
local function tileDefs(th)
  return {
    [1] = {solid = true, color = th.ground},
    [2] = {oneway = true, draw = function(_, _, x, y, s)
      G.rect(x, y, s, s * 0.32, 3, th.plank)
      G.rect(x, y, s, s * 0.1, 2, "#FFFFFF30")
    end},
    [3] = {hazard = true, draw = function(_, _, x, y, s)
      G.color("#D8DEE9")
      for k = 0, 2 do
        local bx = x + k * s / 3
        G.poly({bx, y + s, bx + s / 6, y + s * 0.35, bx + s / 3, y + s})
      end
    end},
    [4] = {solid = true, crumble = true, draw = function(map, _, x, y, s)
      local shake = map.shaking and map.shaking[(y // s) * 1000 + (x // s)] or 0
      local ox = shake > 0 and (random() - 0.5) * 3 or 0
      G.rect(x + 1 + ox, y + 1, s - 2, s - 2, 3, th.plank)
      G.color("#00000050")
      G.line(x + s * 0.2 + ox, y + s * 0.3, x + s * 0.6 + ox, y + s * 0.7, 1.5)
      G.line(x + s * 0.6 + ox, y + s * 0.2, x + s * 0.8 + ox, y + s * 0.5, 1.5)
    end},
    [5] = {oneway = true, spring = true, draw = function(_, _, x, y, s)
      G.rect(x + 2, y + s * 0.55, s - 4, s * 0.45, 3, "#3A3F55")
      G.rect(x + 1, y + s * 0.35, s - 2, s * 0.22, 3, "#FF5A6E")
      G.color("#D8DEE9")
      G.line(x + s * 0.3, y + s * 0.55, x + s * 0.7, y + s * 0.75, 2)
    end},
  }
end

-- ---------------------------------------------------------------- entities
local Player = game.class(game.Sprite)
function Player:init(o)
  game.Sprite.init(self, o)
  self.w, self.h, self.body, self.collideMap = 11, 17, true, true
  self.maxVy = 520
  self.face, self.coyote, self.buffer, self.jumps = 1, 0, 0, 0
  self.dashT, self.dashCd, self.attackT, self.attackCd, self.inv = 0, 0, 0, 0, 0
  self.sx, self.sy = 1, 1
  self.z = 10
  self.wasFloor = true
end
function Player:render()
  local t = game.time
  if self.inv > 0 and floor(self.inv * 14) % 2 == 0 then return end
  local x, y = self.x, self.y + self.h / 2
  local f = self.face
  local run = self.onFloor and abs(self.vx) > 20
  local bob = run and abs(sin(t * 16)) * 1.6 or 0
  local sx, sy = self.sx, self.sy
  -- legs
  G.color("#2A1E3A")
  if run then
    G.line(x - 2, y - 5, x - 2 + sin(t * 16) * 4, y, 2.4)
    G.line(x + 2, y - 5, x + 2 - sin(t * 16) * 4, y, 2.4)
  else
    G.line(x - 2.5, y - 5, x - 3, y, 2.4)
    G.line(x + 2.5, y - 5, x + 3, y, 2.4)
  end
  -- cloak
  local top = y - 18 * sy - bob
  G.poly({x - 7 * sx, y - 4, x + 7 * sx, y - 4, x + 4 * sx, top + 6, x - 4 * sx, top + 6}, "#3B5BA8")
  G.poly({x - 7 * sx, y - 4, x - 4 * sx, top + 6, x - 9 * sx - f * 3, y - 2}, "#2E4785")
  -- head and hood
  G.circle(x, top + 4, 6 * sx, "#3B5BA8")
  G.circle(x + f * 1.6, top + 5, 4.2 * sx, "#FFE3C8")
  G.circle(x + f * 3, top + 4.5, 0.9, "#1A1020")
  -- lantern on a short pole
  local lx, ly = x + f * 9, top + 9 + sin(t * 4) * 0.8
  if self.attackT > 0 then lx, ly = x + f * 15, top + 5 end
  G.color("#5A4632")
  G.line(x + f * 3, top + 10, lx, ly - 4, 1.6)
  G.circle(lx, ly, 9, "#FFD36A26")
  G.circle(lx, ly, 5.5, "#FFD36A50")
  G.rect(lx - 3, ly - 3.5, 6, 7, 2, "#FFE9A8")
  G.rect(lx - 3, ly - 4.5, 6, 1.6, 0.8, "#5A4632")
  if self.attackT > 0 then
    G.color("#FFE9A8A0")
    G.circleLine(x + f * 16, top + 8, 14 * (1 - self.attackT / 0.18) + 6, 2)
  end
  if self.dashT > 0 then
    G.color("#7FE7FF80")
    G.line(x - f * 18, top + 8, x - f * 4, top + 8, 3)
  end
end

local Enemy = game.class(game.Sprite)
local EDEF = {
  slime = {hp = 1, speed = 28, w = 14, h = 11, col = "#7CD95C", stomp = true},
  crawler = {hp = 2, speed = 34, w = 15, h = 11, col = "#7FE7FF", stomp = false},
  guard = {hp = 2, speed = 24, w = 13, h = 17, col = "#C8B8E8", stomp = true, thrower = true},
  bat = {hp = 1, speed = 40, w = 13, h = 9, col = "#8A6ACD", stomp = true, fly = true},
  moth = {hp = 1, speed = 46, w = 13, h = 10, col = "#FFE9A8", stomp = true, fly = true},
  wisp = {hp = 2, speed = 54, w = 12, h = 12, col = "#FF8FB8", stomp = true, fly = true},
  sprout = {hp = 2, w = 14, h = 16, col = "#5CC45C", stomp = true, turret = true},
  prism = {hp = 3, w = 14, h = 16, col = "#B98CFF", stomp = false, turret = true},
  cannon = {hp = 3, w = 16, h = 14, col = "#8C7A68", stomp = true, turret = true},
}
function Enemy:init(o)
  game.Sprite.init(self, o)
  local d = EDEF[self.kind]
  self.def = d
  self.w, self.h = d.w, d.h
  self.hp = d.hp
  self.dir = -1
  self.t = random() * 6
  self.hx, self.hy = self.x, self.y
  self.cd = 1 + random() * 1.5
  if not d.fly then self.body, self.collideMap = true, true end
  if d.turret then self.body = true; self.collideMap = true end
  self.flash = 0
end
function Enemy:render()
  local d = self.def
  local x, y = self.x, self.y
  local col = self.flash > 0 and "#FFFFFF" or d.col
  local k = self.kind
  local t = self.t
  if k == "slime" then
    local sq = 1 + sin(t * 8) * 0.12
    G.circle(x, y + 2, 7 * sq, col)
    G.rect(x - 7 * sq, y + 2, 14 * sq, 4, 2, col)
    G.circle(x + self.dir * 3, y, 1.5, "#1A1020")
  elseif k == "crawler" then
    G.circle(x, y + 2, 7, "#3A3F6A")
    for i = -2, 2 do G.poly({x + i * 3 - 2, y - 1, x + i * 3 + 2, y - 1, x + i * 3, y - 7}, col) end
    G.circle(x + self.dir * 4, y + 2, 1.5, "#FFFFFF")
  elseif k == "guard" then
    G.rect(x - 6, y - 8, 12, 16, 3, col)
    G.rect(x - 4, y - 5, 8, 3, 1, "#3A2A5A")
    G.circle(x + self.dir * 2, y - 4, 1.2, "#FF5A6E")
  elseif d.fly then
    local flap = sin(t * 18) * 5
    G.circle(x, y, 5, col)
    G.poly({x - 3, y, x - 11, y - flap, x - 9, y + 3}, col)
    G.poly({x + 3, y, x + 11, y - flap, x + 9, y + 3}, col)
    G.circle(x + 2, y - 1, 1.2, "#1A1020")
    if k == "moth" then G.circle(x, y, 10, "#FFE9A820") end
  elseif d.turret then
    G.rect(x - 7, y - 2, 14, 10, 3, k == "sprout" and "#4A3020" or "#3A3F55")
    G.circle(x, y - 3, 6, col)
    G.circle(x + self.dir * 3, y - 4, 2, "#1A1020")
  end
end
function Enemy:update(dt)
  self.t = self.t + dt
  if self.flash > 0 then self.flash = self.flash - dt end
end

-- ======================================================================== scenes
local Title, Slots, Map, Play, Clear, Ending

local function backdrop(th, cam, wpx)
  G.gradient(0, 0, game.width, game.height, th.sky1, th.sky2)
  local cx = cam and cam.x or game.realTime * 20
  -- three parallax layers of rounded hills or crystals, drawn from repeating shapes
  local layers = {{0.15, th.far, 150, 90}, {0.35, th.mid, 110, 60}, {0.6, th.near, 80, 34}}
  for li, L in ipairs(layers) do
    local f, col, spacing, base = L[1], L[2], L[3], L[4]
    local off = (cx * f) % spacing
    local y0 = game.height - base
    local i0 = floor(cx * f / spacing)
    for k = -1, floor(game.width / spacing) + 2 do
      local x = k * spacing - off
      local seed = (i0 + k) * 37 + li * 101
      local h = 30 + (seed * 13) % 50
      if th == THEME.caverns then
        G.poly({x - spacing * 0.35, game.height, x, y0 - h, x + spacing * 0.35, game.height}, col)
      elseif th == THEME.ruins and li == 2 then
        G.rect(x - 12, y0 - h, 24, h + base, 2, col)
        G.rect(x - 16, y0 - h - 6, 32, 8, 2, col)
      else
        G.circle(x, y0 + 20 - h * 0.3, spacing * 0.55, col)
      end
      G.rect(x - spacing, y0 + 14, spacing * 2, base, 0, col)
    end
  end
  if th == THEME.ruins then
    for k = 0, 5 do
      local x = (k * 170 - (cx * 0.1 + game.realTime * 8)) % (game.width + 200) - 100
      local y = 40 + (k * 53) % 90
      G.circle(x, y, 22, "#FFFFFFB0"); G.circle(x + 22, y + 6, 18, "#FFFFFFB0"); G.circle(x - 22, y + 8, 16, "#FFFFFFB0")
    end
  end
end

-- ---------------------------------------------------------------- title
Title = {pausable = false}
function Title:enter()
  K.music("title")
  K.clearTips()
  self.t = 0
  openSlot(slotIndex)
  local items = {
    {label = TR("continue"), icon = "play_arrow", enabled = function() return slot:exists() end,
     action = function() K.go(Map, {}, "circle", 0.45) end},
    {label = TR("save_slots"), icon = "save", action = function() game.push(Slots) end},
    {label = TR("k_settings"), icon = "tune", action = function() game.push(K.SettingsScene, {fromTitle = true}) end},
    {label = TR("k_help"), icon = "help", action = function()
      game.push(K.HelpScene, {title = TR("k_help"), rows = {
        {icon = "gamepad", text = TR("help_move")}, {action = "jump", text = TR("help_jump")},
        {action = "attack", text = TR("help_attack")}, {action = "dash", text = TR("help_dash")},
        {icon = "local_fire_department", text = TR("help_shrine")}, {icon = "star", text = TR("help_shards")},
        {icon = "touch_app", text = TR("help_touch")},
      }})
    end},
    {label = TR("k_quit"), icon = "logout", action = function() K.stopAudio(); sys.exit() end},
  }
  self.menu = K.menu{items = items, width = 200, itemHeight = 28, size = 12, accent = "#FFB547"}
end
function Title:update(dt)
  self.t = self.t + dt
  self.menu:update()
  if random() < 0.3 then motes:emit(1, random() * game.width, game.height * (0.4 + random() * 0.6)) end
  motes:update(dt)
end
function Title:draw()
  K.accent = "#FFB547"
  local th = THEME.hollow
  G.gradient(0, 0, game.width, game.height, "#2A2050", "#E8946A")
  backdrop({sky1 = "#2A2050", sky2 = "#E8946A", far = "#7A5A8A", mid = "#4E3A6A", near = "#2A1E40"}, {x = game.realTime * 30})
  motes:draw()
  -- the lantern glow behind the title
  local gx, gy = game.width * 0.72, game.height * 0.46
  for k = 5, 1, -1 do G.circle(gx, gy, 24 + k * 16, string.format("#FFD36A%02X", 10 + k * 3)) end
  G.rect(gx - 9, gy - 12, 18, 24, 4, "#FFE9A8")
  G.rect(gx - 11, gy - 16, 22, 5, 2, "#5A4632")
  G.color("#5A4632"); G.line(gx, gy - 16, gx, gy - 40, 2)
  local a = min(1, self.t / 0.7)
  G.alpha(a)
  U.text(TR("title"), 30, 34, 40, "#FFF1D6", "left", nil, "bold")
  U.text(TR("tagline"), 32, 80, 12, "#FFE0B0", "left", nil, "semibold", false)
  G.unalpha()
  self.menu:draw(30 + 100, 118)
  local _ = th
end

-- ---------------------------------------------------------------- save slots
Slots = {transparent = true, pausable = false}
function Slots:enter()
  self.t = 0
  local items = {}
  for i, info in ipairs(game.save.slots(3)) do
    items[#items + 1] = {label = function()
      if info.used then return TR("slot_n", i) .. "  ·  " .. (info.summary or "") end
      return TR("slot_n", i) .. "  ·  " .. TR("empty")
    end, icon = info.used and "bookmark" or "bookmark_border", action = function()
      openSlot(i)
      if not slot:exists() then
        slot:set("unlocked", 1)
        slot:stamp(TR("slot_summary", 1, 0))
        game.pop()
        K.go(Play, {n = 1}, "circle", 0.5)
      else
        game.pop()
        K.go(Map, {}, "circle", 0.45)
      end
    end, value = info.used and function() return info.when or "" end or nil}
  end
  items[#items + 1] = {label = TR("delete_slot"), icon = "delete", action = function()
    U.dialog{title = TR("delete_slot"), text = TR("delete_q", slotIndex), buttons = {TR("k_yes"), TR("k_no")}, color = "#E5484D",
             onClose = function(k) if k == 1 then game.save.slot(slotIndex):delete(); game.pop(); game.push(Slots) end end}
  end}
  items[#items + 1] = {label = TR("k_back"), icon = "arrow_back", action = function() game.pop() end}
  self.menu = K.menu{items = items, width = 360, itemHeight = 30, size = 12, accent = "#FFB547", onBack = function() game.pop() end,
                     selected = slotIndex}
end
function Slots:update(dt) self.t = self.t + dt; if game.current() == Slots then self.menu:update() end end
function Slots:draw()
  G.rect(0, 0, game.width, game.height, 0, "#000000A0")
  local h = #self.menu.items * 30 + 64
  local y = (game.height - h) / 2
  K.frame(game.width / 2 - 200, y, 400, h, TR("save_slots"), "#FFB547")
  self.menu:draw(game.width / 2, y + 52)
end

-- ---------------------------------------------------------------- world map
Map = {pausable = false}
local NODES = {}
for n = 1, #LV.LEVELS do
  local w = LV.LEVELS[n].w
  local i = (n - 1) % 4
  NODES[n] = {x = 70 + (w - 1) * 190 + i * 44, y = 250 - i * 30 - ((i % 2) * 18) + (LV.LEVELS[n].boss and -30 or 0)}
end
function Map:enter(p)
  K.music("title")
  self.t = 0
  local unl = slot:get("unlocked", 1)
  self.sel = min(unl, p and p.n or unl)
end
function Map:update(dt)
  self.t = self.t + dt
  local unl = slot:get("unlocked", 1)
  if I.pressed("right") or I.pressed("down") then if self.sel < unl and self.sel < #LV.LEVELS then self.sel = self.sel + 1; K.sfx("ui_move") else K.sfx("ui_back") end end
  if I.pressed("left") or I.pressed("up") then if self.sel > 1 then self.sel = self.sel - 1; K.sfx("ui_move") end end
  if I.pressed("confirm") then K.sfx("ui_ok"); K.go(Play, {n = self.sel}, "circle", 0.5) end
  if I.pressed("back") then K.sfx("ui_back"); K.go(Title) end
  local pt = I.pointer
  if pt.released then
    for n, nd in ipairs(NODES) do
      if (pt.x - nd.x) ^ 2 + (pt.y - nd.y) ^ 2 < 18 * 18 and n <= unl then
        if self.sel == n then K.go(Play, {n = n}, "circle", 0.5) else self.sel = n; K.sfx("ui_move") end
      end
    end
  end
end
function Map:draw()
  K.accent = "#FFB547"
  local W, H = game.width, game.height
  G.gradient(0, 0, W, H, "#1E1A3A", "#3A2A50")
  local cols = {"#5CC45C", "#7FE7FF", "#FF8FB8"}
  for w = 1, 3 do
    local x0 = 40 + (w - 1) * 190
    G.rect(x0, 60, 180, 240, 18, cols[w] .. "18")
    U.text(TRd("world" .. w), x0, 70, 13, cols[w], "center", 180, "bold")
  end
  local unl = slot:get("unlocked", 1)
  G.color("#FFFFFF40")
  for n = 1, #NODES - 1 do G.line(NODES[n].x, NODES[n].y, NODES[n + 1].x, NODES[n + 1].y, 3) end
  for n, nd in ipairs(NODES) do
    local lv = LV.LEVELS[n]
    local open = n <= unl
    local sel = n == self.sel
    local r = lv.boss and 14 or 10
    if sel then G.circle(nd.x, nd.y, r + 6 + sin(self.t * 5) * 2, "#FFFFFF40") end
    G.circle(nd.x, nd.y, r, open and cols[lv.w] or "#40405A")
    if lv.boss then G.icon("whatshot", nd.x, nd.y, 16, open and "#1A1020" or "#80809A")
    elseif not open then G.icon("lock", nd.x, nd.y, 12, "#80809A") end
    if open and not lv.boss then
      local m = shardsOf(n)
      for k = 0, 2 do G.circle(nd.x - 7 + k * 7, nd.y + r + 6, 2.2, (m >> k) & 1 == 1 and "#FFE14D" or "#FFFFFF30") end
    end
  end
  local lv = LV.LEVELS[self.sel]
  local name = lv.boss and TRd("boss_" .. LV.WORLDS[lv.w].boss) or TR("level_n", lv.w, (self.sel - 1) % 4 + 1)
  U.text(name, 0, 18, 20, "#FFFFFF", "center", W, "bold")
  local best = slot:get("best_" .. self.sel)
  U.text(best and TR("best_time", string.format("%d:%02d", floor(best / 60), floor(best % 60))) or " ", 0, 42, 11, "#FFFFFFA0", "center", W, "semibold", false)
  U.text(TR("shards_total", totalShards(), 27) .. "   ·   " .. TR("embers_total", slot:get("embers", 0)), 0, H - 40, 11, "#FFE9A8", "center", W, "semibold", false)
  K.prompts({{"confirm", TR("play")}, {"back", TR("k_back")}}, W / 2, H - 22, 10)
end

-- ---------------------------------------------------------------- play
Play = {controls = true}

function Play:build(n)
  local lv = LV.LEVELS[n]
  local wd = LV.WORLDS[lv.w]
  self.lv, self.wd, self.th = lv, wd, THEME[wd.key]
  self.boss, self.bossSpawn = nil, nil
  local rows = LV.rows(n)
  local legend = {["#"] = 1, ["="] = 2, ["^"] = 3, c = 4, j = 5,
                  o = {object = "ember"}, ["*"] = {object = "shard"}, S = {object = "shrine"}, E = {object = "exit"},
                  P = {object = "start"}, A = {object = "altar"}, B = {object = "boss"}, e = {object = "walker"},
                  f = {object = "flyer"}, t = {object = "shooter"}}
  local map = game.tilemap.fromStrings(rows, legend, {tileSize = TS, tiles = tileDefs(self.th)})
  map.edges = {left = true, right = true, top = false, bottom = false}
  map.layers[1].visible = false   -- drawn by Play:draw with the ground caps
  map.shaking = {}
  self.map = map
  self.cam = game.camera{lerp = 0.12, deadzone = {w = 40, h = 50}}
  self.cam:setBounds(0, 0, map.pixelWidth, map.pixelHeight)
  self.world = game.world{gravity = 980, map = map, camera = self.cam, cell = 64}
  self.world:addEmitter(dust)
  self.world:addEmitter(sparks)
  dust:clear(); sparks:clear()
  self.items, self.shots, self.crumbles = {}, {}, {}
  self.shardMask = 0
  self.oldMask = shardsOf(n)
  local sx, sy = 60, 200
  for _, o in ipairs(map.objects) do
    if o.type == "start" then sx, sy = o.x, o.y
    elseif o.type == "ember" or o.type == "shard" or o.type == "shrine" or o.type == "exit" or o.type == "altar" then
      local it = {kind = o.type, x = o.x, y = o.y, t = random() * 6}
      if o.type == "shard" then
        local idx = 0
        for _, it2 in ipairs(self.items) do if it2.kind == "shard" then idx = idx + 1 end end
        it.bit = 1 << idx
        it.old = (self.oldMask & it.bit) ~= 0
      end
      self.items[#self.items + 1] = it
    elseif o.type == "walker" or o.type == "flyer" or o.type == "shooter" then
      local kind = o.type == "walker" and wd.walker or (o.type == "flyer" and wd.flyer or wd.shooter)
      self.world:add(Enemy{kind = kind, x = o.x, y = o.y}, "enemies")
    elseif o.type == "boss" then
      self.bossSpawn = {x = o.x, y = o.y}
    end
  end
  self.startX, self.startY = sx, sy
  self.player = self.world:add(Player{x = sx, y = sy}, "player")
  self.cam:follow(self.player)
  self.cam:lookAt(sx, sy)
  self.cam:snap()
  self.world:collide(self.player, "enemies", function(p, e) self:touchEnemy(e) end)
  -- top edges of the ground for grass / crystal / stone caps
  self.caps = {}
  for ty = 0, map.height - 1 do
    local run0 = nil
    for tx = 0, map.width do
      local id = tx < map.width and map:get(tx, ty) or 0
      local above = ty > 0 and map:get(tx, ty - 1) or 0
      local cap = id == 1 and above ~= 1
      if cap and not run0 then run0 = tx end
      if not cap and run0 then self.caps[#self.caps + 1] = {run0 * TS, tx * TS, ty * TS}; run0 = nil end
    end
  end
  -- darkness and lights in the caverns
  self.lights = nil
  if wd.dark then
    self.lights = game.lights{ambient = 0.84, color = "#04030C", cell = 10, levels = 10}
    self.lantern = self.lights:add{x = sx, y = sy, radius = 120, intensity = 1, flicker = 0.06}
    for _, it in ipairs(self.items) do
      if it.kind == "shrine" or it.kind == "exit" or it.kind == "altar" then
        it.light = self.lights:add{x = it.x, y = it.y, radius = 70, intensity = 0.7}
      elseif it.kind == "shard" then
        self.lights:add{x = it.x, y = it.y, radius = 40, intensity = 0.6}
      end
    end
  end
  if lv.boss then self:spawnBoss() end
end

function Play:enter(p)
  self.n = p.n or 1
  self:build(self.n)
  local lv = self.lv
  K.music(lv.boss and "boss" or self.th.music)
  K.clearTips()
  self.t, self.time, self.embers, self.deaths = 0, 0, 0, 0
  self.hp = maxHearts()
  self.respawnX, self.respawnY = self.startX, self.startY
  self.dead, self.done = false, false
  self.banner = {text = lv.boss and TRd("boss_" .. self.wd.boss) or TR("level_n", lv.w, (self.n - 1) % 4 + 1),
                 sub = TRd("world" .. lv.w), t = 2.4}
  if self.n == 1 then
    K.tip("move", TR("tip_move"), "gamepad", 5)
    K.tip("jump", TR("tip_jump", K.btn("jump") or TR("tap")), "arrow_upward", 6)
    K.tip("attack", TR("tip_attack", K.btn("attack") or "⚔"), "flare", 6)
    K.tip("stomp", TR("tip_stomp"), "south", 5)
  end
  if has("dash") then K.tip("dash_use", TR("tip_dash", K.btn("dash") or ""), "double_arrow", 5) end
end
function Play:restart() K.go(Play, {n = self.n}, "fade", 0.25) end
function Play:pauseItems()
  return {{label = TR("world_map"), icon = "map", action = function() game.paused = false; K.go(Map, {n = self.n}) end}}
end

function Play:hurt(fromX)
  local p = self.player
  if p.inv > 0 or p.dashT > 0 or self.dead or self.done then return end
  self.hp = self.hp - 1
  p.inv = 1.2
  p.vx = (p.x < (fromX or p.x) and -1 or 1) * 160
  p.vy = -220
  K.sfx("hurt")
  K.rumble(0.7, 140)
  K.shake(self.cam, 5, 0.25)
  game.flash("#FF3048", 0.2, 0.3)
  sparks:setColors({"#FFFFFF", "#FF5A6E", "#FF5A6E00"})
  sparks:emit(14, p.x, p.y)
  if self.hp <= 0 then self:die() end
end
function Play:die()
  self.dead, self.deadT = true, 0
  self.deaths = self.deaths + 1
  slot:inc("deaths", 1)
  K.sfx("die")
  local p = self.player
  sparks:setColors({"#FFFFFF", "#FFD36A", "#FF8A1A00"})
  sparks:emit(40, p.x, p.y)
  p.visible = false
  p.active = false
end
function Play:respawn()
  local p = self.player
  p.x, p.y, p.vx, p.vy = self.respawnX, self.respawnY - 10, 0, 0
  p.visible, p.active = true, true
  p.inv = 1.5
  self.hp = maxHearts()
  self.dead = false
  self.cam:lookAt(p.x, p.y)
  self.cam:snap()
  if self.boss and not self.boss.dead then self.boss.hp = min(self.boss.maxHp, self.boss.hp + self.boss.maxHp * 0.25) end
end

function Play:touchEnemy(e)
  local p = self.player
  if e.dead or self.dead then return end
  local d = e.def
  if d.stomp and p.vy > 40 and p.y + p.h / 2 < e.y + 2 then
    self:killEnemy(e)
    p.vy = I.down("jump") and -360 or -260
    p.jumps = 0
    K.sfx("stomp")
    K.tipDone("stomp")
    return
  end
  if p.dashT > 0 and has("dash") then self:killEnemy(e) return end
  self:hurt(e.x)
end
function Play:killEnemy(e)
  e.dead = true
  sparks:setColors({"#FFFFFF", e.def.col, e.def.col .. "00"})
  sparks:emit(16, e.x, e.y)
  K.sfx("hit")
  K.shake(self.cam, 2, 0.1)
  self.items[#self.items + 1] = {kind = "ember", x = e.x, y = e.y - 6, t = 0, pop = 0.4}
end

-- ---------------------------------------------------------------- bosses
function Play:spawnBoss()
  local kind = self.wd.boss
  local b = {kind = kind, x = self.bossSpawn.x, y = self.bossSpawn.y - 14, vx = 0, vy = 0, t = 0, st = "intro", stT = 1.6,
             flash = 0, inv = 0, face = -1}
  b.maxHp = ({bramble = 14, golem = 18, owl = 22})[kind] * K.pick(0.75, 1, 1.25)
  b.hp = b.maxHp
  b.r = kind == "owl" and 18 or 22
  if kind == "owl" then b.y = 80 end
  self.boss = b
end
function Play:bossShot(x, y, vx, vy, grav, kind)
  self.shots[#self.shots + 1] = {x = x, y = y, vx = vx, vy = vy, grav = grav or 0, kind = kind or "orb", t = 0, r = 6}
end
function Play:hitBoss(dmg)
  local b = self.boss
  if not b or b.dead or b.inv > 0 or b.st == "intro" then return false end
  b.hp = b.hp - dmg
  b.flash, b.inv = 0.12, 0.35
  K.sfx("boss_hit")
  K.rumble(0.4, 60)
  K.shake(self.cam, 3, 0.15)
  sparks:setColors({"#FFFFFF", "#FFD36A", "#FF8A1A00"})
  sparks:emit(12, b.x, b.y)
  if b.hp <= 0 then
    b.dead = true
    b.deadT = 0
    K.sfx("boom")
    K.rumble(1, 400)
    K.shake(self.cam, 10, 0.8)
    game.flash("#FFFFFF", 0.5, 0.7)
    for _ = 1, 4 do sparks:emit(30, b.x + random(-20, 20), b.y + random(-20, 20)) end
    self.shots = {}
  end
  return true
end
function Play:updateBoss(dt)
  local b = self.boss
  if not b then return end
  local p = self.player
  b.t = b.t + dt
  if b.flash > 0 then b.flash = b.flash - dt end
  if b.inv > 0 then b.inv = b.inv - dt end
  if b.dead then
    b.deadT = b.deadT + dt
    if b.deadT > 1.6 and not self.done then self:complete() end
    return
  end
  local floorY = 15 * TS - b.r
  local W = self.map.pixelWidth
  local rage = b.hp < b.maxHp * 0.5
  b.stT = b.stT - dt
  if b.kind == "bramble" then
    if b.st == "intro" then if b.stT <= 0 then b.st, b.stT = "walk", 2 end
    elseif b.st == "walk" then
      b.face = p.x < b.x and -1 or 1
      b.vx = b.face * (rage and 70 or 50)
      if b.stT <= 0 then b.st, b.stT = "crouch", 0.5; b.vx = 0 end
    elseif b.st == "crouch" then
      if b.stT <= 0 then
        b.st = "leap"
        b.vy = -420
        b.vx = (p.x - b.x) * 1.1
        K.sfx("jump")
      end
    elseif b.st == "leap" then
      b.vy = b.vy + 900 * dt
      if b.y >= floorY and b.vy > 0 then
        b.y, b.vy, b.vx = floorY, 0, 0
        b.st, b.stT = "walk", rage and 1.4 or 2.2
        K.sfx("boom")
        K.shake(self.cam, 6, 0.3)
        self:bossShot(b.x - b.r, 15 * TS - 8, -170, 0, 0, "wave")
        self:bossShot(b.x + b.r, 15 * TS - 8, 170, 0, 0, "wave")
        if rage then
          for k = -2, 2 do self:bossShot(b.x, b.y - b.r, k * 70, -280, 600, "thorn") end
        end
      end
    end
    b.x = max(TS + b.r, min(W - TS - b.r, b.x + b.vx * dt))
    b.y = b.y + b.vy * dt
    if b.st ~= "leap" then b.y = floorY end
  elseif b.kind == "golem" then
    b.y = floorY
    if b.st == "intro" then if b.stT <= 0 then b.st, b.stT = "walk", 1.5 end
    elseif b.st == "walk" then
      b.face = p.x < b.x and -1 or 1
      b.x = max(TS + b.r, min(W - TS - b.r, b.x + b.face * 30 * dt))
      if b.stT <= 0 then
        b.n = (b.n or 0) + 1
        if b.n % 2 == 1 then b.st, b.stT = "volley", 0.6 else b.st, b.stT = "slam", 0.7 end
      end
    elseif b.st == "volley" then
      if b.stT <= 0 then
        for k = 1, rage and 7 or 5 do
          local vx = (p.x - b.x) * (0.5 + k * 0.18) / 1.0
          self:bossShot(b.x, b.y - b.r, vx * 0.9, -330 - k * 20, 600, "crystal")
        end
        K.sfx("shoot")
        b.st, b.stT = "walk", rage and 1.0 or 1.6
      end
    elseif b.st == "slam" then
      if b.stT <= 0 then
        K.sfx("boom")
        K.shake(self.cam, 8, 0.4)
        for k = 1, rage and 7 or 5 do
          local x = TS * 2 + random() * (W - TS * 4)
          self.shots[#self.shots + 1] = {x = x, y = TS + 4, vx = 0, vy = 0, grav = 0, kind = "stalactite", t = -0.7, r = 7}
        end
        b.st, b.stT = "walk", 1.6
      end
    end
  else -- owl
    if b.st == "intro" then
      b.y = 80 + sin(b.t * 2) * 8
      if b.stT <= 0 then b.st, b.stT = "hover", 2.4 end
    elseif b.st == "hover" then
      b.x = b.x + ((p.x - b.x) * 1.2) * dt
      b.y = b.y + ((80 + sin(b.t * 2) * 12) - b.y) * min(1, dt * 3)
      b.drop = (b.drop or 0) - dt
      if b.drop <= 0 then
        b.drop = rage and 0.6 or 0.9
        for k = -1, 1 do self:bossShot(b.x + k * 10, b.y + 10, k * 60, 120, 120, "feather") end
        K.sfx("shoot")
      end
      if b.stT <= 0 then b.st, b.stT = "aim", 0.6; b.tx, b.ty = p.x, p.y end
    elseif b.st == "aim" then
      if b.stT <= 0 then
        local dx, dy = b.tx - b.x, b.ty - b.y
        local d = sqrt(dx * dx + dy * dy) + 1
        b.vx, b.vy = dx / d * (rage and 420 or 340), dy / d * (rage and 420 or 340)
        b.st, b.stT = "dive", 1.2
        K.sfx("dash")
      end
    elseif b.st == "dive" then
      b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
      if b.y >= floorY - 4 or b.stT <= 0 then
        b.y = min(b.y, floorY - 4)
        b.st, b.stT = "rest", rage and 0.7 or 1.0
        K.sfx("boom")
        K.shake(self.cam, 5, 0.2)
        if rage then for k = 0, 7 do self:bossShot(b.x, b.y, cos(k * pi / 4) * 150, sin(k * pi / 4) * 150 - 40, 100, "feather") end end
      end
    elseif b.st == "rest" then
      if b.stT <= 0 then b.st, b.stT = "rise", 0.8 end
    elseif b.st == "rise" then
      b.y = b.y + (80 - b.y) * min(1, dt * 3)
      if b.stT <= 0 then b.st, b.stT = "hover", rage and 1.6 or 2.4 end
    end
    b.x = max(TS + b.r, min(W - TS - b.r, b.x))
  end
  -- contact
  local dx, dy = p.x - b.x, p.y - b.y
  if dx * dx + dy * dy < (b.r + 7) ^ 2 and not self.dead then
    if p.vy > 60 and p.y < b.y - b.r * 0.4 and b.kind ~= "golem" then
      if self:hitBoss(1) then p.vy = -330; K.sfx("stomp") end
    else
      self:hurt(b.x)
    end
  end
end

-- ---------------------------------------------------------------- update
function Play:update(dt)
  self.t = self.t + dt
  local p = self.player
  if self.banner then self.banner.t = self.banner.t - dt; if self.banner.t <= 0 then self.banner = nil end end
  if not self.done then self.time = self.time + dt end
  if self.dead then
    self.deadT = self.deadT + dt
    if self.deadT > 1.2 then self:respawn() end
    self.world:update(dt)
    self.cam:update(dt)
    return
  end
  if self.done then
    self.world:update(dt)
    self.cam:update(dt)
    return
  end
  -- run
  local mx = I.axis("left", "right")
  local lx = I.sticks()
  if abs(lx) > 0.25 then mx = lx end
  if I.touch.stick.active then mx = I.touch.stick.vx end
  if abs(mx) > 0.2 then K.tipDone("move") end
  local target = mx * 150
  local accel = p.onFloor and 1300 or 900
  if p.dashT > 0 then
    p.dashT = p.dashT - dt
    p.vx, p.vy = p.face * 380, 0
    p.gravity = 0
    if random() < 0.7 then dust:emit(1, p.x, p.y) end
    if p.dashT <= 0 then p.gravity = 1; p.vx = p.face * 150 end
  else
    if p.vx < target then p.vx = min(target, p.vx + accel * dt) elseif p.vx > target then p.vx = max(target, p.vx - accel * dt) end
    if abs(mx) > 0.2 then p.face = mx > 0 and 1 or -1 end
  end
  if p.dashCd > 0 then p.dashCd = p.dashCd - dt end
  if p.onFloor then p.coyote, p.jumps = 0.1, 0 else p.coyote = p.coyote - dt end
  if I.pressed("jump") then p.buffer = 0.12 else p.buffer = p.buffer - dt end
  -- wall slide / wall jump
  local wall = 0
  if has("wall") and not p.onFloor then
    local m = self.map
    local tx1, ty = m:toTile(p.x + p.w / 2 + 5, p.y)
    local tx0 = m:toTile(p.x - p.w / 2 - 5, p.y)
    local touch = (m:solid(tx1, ty) == 1 or p.onWall == 1) and 1 or ((m:solid(tx0, ty) == 1 or p.onWall == -1) and -1 or 0)
    if touch ~= 0 then p.wallDir, p.wallGrace = touch, 0.14 end   -- a wall jump still works just after letting go
    if touch ~= 0 and mx * touch > 0.2 and p.vy > 50 then
      p.vy = 50
      if random() < 0.3 then dust:emit(1, p.x + touch * 6, p.y) end
    end
  end
  if p.wallGrace and p.wallGrace > 0 then
    p.wallGrace = p.wallGrace - dt
    if not p.onFloor then wall = p.wallDir end
  end
  if p.buffer > 0 then
    if p.coyote > 0 then
      p.vy, p.buffer, p.coyote = -340, 0, 0
      p.sx, p.sy = 0.8, 1.25
      K.sfx("jump")
      K.tipDone("jump")
      dust:emit(5, p.x, p.y + p.h / 2)
    elseif wall ~= 0 then
      p.vy, p.vx, p.buffer = -340, -wall * 170, 0
      p.face = -wall
      K.sfx("jump")
      K.tipDone("wall_use")
      dust:emit(6, p.x + wall * 6, p.y)
    elseif has("double") and p.jumps < 1 then
      p.jumps = p.jumps + 1
      p.vy, p.buffer = -330, 0
      p.sx, p.sy = 0.8, 1.25
      K.sfx("djump")
      K.tipDone("double_use")
      sparks:setColors({"#FFFFFF", "#FFD36A", "#FFD36A00"})
      sparks:emit(10, p.x, p.y + p.h / 2)
    end
  end
  if I.released("jump") and p.vy < -140 then p.vy = -140 end
  if has("dash") and I.pressed("dash") and p.dashCd <= 0 then
    p.dashT, p.dashCd = 0.18, 0.55
    if abs(mx) > 0.2 then p.face = mx > 0 and 1 or -1 end
    K.sfx("dash")
    K.tipDone("dash_use")
  end
  -- lantern swing
  if p.attackCd > 0 then p.attackCd = p.attackCd - dt end
  if p.attackT > 0 then p.attackT = p.attackT - dt end
  if I.pressed("attack") and p.attackCd <= 0 then
    p.attackT, p.attackCd = 0.18, 0.32
    K.sfx("swing")
    K.tipDone("attack")
    local hx, hy = p.x + p.face * 16, p.y - 2
    local hit = false
    for _, e in ipairs(self.world:group("enemies")) do
      if not e.dead and abs(e.x - hx) < 18 + e.w / 2 and abs(e.y - hy) < 16 + e.h / 2 then
        e.hp = e.hp - 1
        e.flash = 0.12
        hit = true
        if e.hp <= 0 then self:killEnemy(e) else K.sfx("hit"); e.vx = p.face * 120 end
      end
    end
    local b = self.boss
    if b and not b.dead and abs(b.x - hx) < 18 + b.r and abs(b.y - hy) < 18 + b.r then hit = self:hitBoss(1) or hit end
    if hit then K.rumble(0.3, 40) end
  end
  -- squash and stretch back to normal
  p.sx = p.sx + (1 - p.sx) * min(1, dt * 12)
  p.sy = p.sy + (1 - p.sy) * min(1, dt * 12)
  local vyBefore = p.vy
  self.world:update(dt)
  if p.inv > 0 then p.inv = p.inv - dt end
  -- landing
  if p.onFloor and not p.wasFloor and vyBefore > 200 then
    p.sx, p.sy = 1.25, 0.78
    dust:emit(6, p.x, p.y + p.h / 2)
    K.sfx("land")
  end
  p.wasFloor = p.onFloor
  local m = self.map
  -- springs and crumbling blocks under the feet
  if p.onFloor then
    local ftx, fty = m:toTile(p.x, p.y + p.h / 2 + 2)
    local id = m:get(ftx, fty)
    if id == 5 then
      p.vy = -600
      p.sx, p.sy = 0.7, 1.35
      p.jumps = 0
      K.sfx("spring")
      K.rumble(0.3, 50)
    end
    for k = -1, 1 do
      local tx = m:toTile(p.x + k * p.w * 0.45, 0)
      if m:get(tx, fty) == 4 then
        local key = fty * 1000 + tx
        if not self.crumbles[key] then
          self.crumbles[key] = {tx = tx, ty = fty, t = 0.45, back = nil}
          m.shaking[key] = 1
          K.sfx("crumble")
        end
      end
    end
  end
  for key, c in pairs(self.crumbles) do
    if c.t then
      c.t = c.t - dt
      if c.t <= 0 then
        m:set(c.tx, c.ty, 0)
        m.shaking[key] = nil
        c.t, c.back = nil, 3.5
        dust:setColors({self.th.plank, self.th.plank .. "00"})
        dust:emit(6, (c.tx + 0.5) * TS, (c.ty + 0.5) * TS)
        dust:setColors({"#FFFFFFB0", "#FFFFFF00"})
      end
    elseif c.back then
      c.back = c.back - dt
      local px0, px1 = (c.tx) * TS, (c.tx + 1) * TS
      local inside = p.x + p.w / 2 > px0 and p.x - p.w / 2 < px1 and abs(p.y - (c.ty + 0.5) * TS) < TS
      if c.back <= 0 and not inside then m:set(c.tx, c.ty, 4); self.crumbles[key] = nil end
    end
  end
  -- spikes and falling
  if m:findTile(p.x - p.w / 2 + 2, p.y - p.h / 2, p.w - 4, p.h, "hazard") then
    self:hurt(p.x - p.face)
    if not self.dead then p.vy = -330 end
  end
  if p.y > m.pixelHeight + 30 then self.hp = 1; p.inv = 0; self:hurt(p.x) end
  -- enemies
  for _, e in ipairs(self.world:group("enemies")) do
    if not e.dead then self:enemyAI(e, dt) end
  end
  self:updateShots(dt)
  self:updateBoss(dt)
  self:updateItems(dt)
  if self.lantern then
    self.lantern.x, self.lantern.y = p.x + p.face * 9, p.y - 6
  end
  self.cam:update(dt)
  K.stat("entities", self.world:group("enemies").n)
  K.stat("particles", dust.count + sparks.count)
end

function Play:enemyAI(e, dt)
  local d = e.def
  local p = self.player
  local m = self.map
  if d.fly then
    local dx, dy = p.x - e.x, p.y - e.y
    local near = dx * dx + dy * dy < 160 * 160
    if near then
      e.x = e.x + (dx > 0 and 1 or -1) * d.speed * dt
      e.y = e.y + (dy > 0 and 1 or -1) * d.speed * 0.6 * dt + sin(e.t * 4) * 0.6
      e.dir = dx > 0 and 1 or -1
    else
      e.x = e.hx + sin(e.t * 0.8) * 40
      e.y = e.hy + sin(e.t * 2.1) * 12
    end
  elseif d.turret then
    e.vx = 0
    e.dir = p.x < e.x and -1 or 1
    e.cd = e.cd - dt
    local dx = p.x - e.x
    if e.cd <= 0 and abs(dx) < 260 then
      e.cd = 2.2
      local a = atan(p.y - 20 - e.y, dx)
      self.shots[#self.shots + 1] = {x = e.x, y = e.y - 4, vx = cos(a) * 140, vy = sin(a) * 140 - 60, grav = 180,
                                     kind = "orb", t = 0, r = 4, col = d.col}
      K.sfx("shoot")
    end
  else
    e.vx = e.dir * d.speed * K.pick(0.8, 1, 1.2)
    -- turn at walls and ledges
    local ahead = e.x + e.dir * (e.w / 2 + 2)
    local tx, ty = m:toTile(ahead, e.y)
    local _, gy = m:toTile(ahead, e.y + e.h / 2 + 4)
    if e.onWall ~= 0 or m:solid(tx, ty) == 1 or m:solid(tx, gy) == 0 then e.dir = -e.dir end
    if d.thrower then
      e.cd = e.cd - dt
      if e.cd <= 0 and abs(p.x - e.x) < 200 then
        e.cd = 2.5
        self.shots[#self.shots + 1] = {x = e.x, y = e.y - 8, vx = (p.x > e.x and 1 or -1) * 110, vy = -230, grav = 600,
                                       kind = "rock", t = 0, r = 4}
      end
    end
  end
end

function Play:updateShots(dt)
  local p = self.player
  local m = self.map
  for i = #self.shots, 1, -1 do
    local s = self.shots[i]
    s.t = s.t + dt
    if s.t >= 0 then
      s.vy = s.vy + s.grav * dt
      if s.kind == "stalactite" then s.vy = s.vy + 700 * dt end
      s.x, s.y = s.x + s.vx * dt, s.y + s.vy * dt
    end
    local dead = s.t > 6 or s.x < 0 or s.x > m.pixelWidth or s.y > m.pixelHeight + 20
    if not dead and s.t >= 0 and s.kind ~= "wave" then
      local tx, ty = m:toTile(s.x, s.y)
      if m:solid(tx, ty) == 1 then
        dead = true
        dust:emit(4, s.x, s.y)
      end
    end
    if s.kind == "wave" and (s.x < TS or s.x > m.pixelWidth - TS) then dead = true end
    if not dead and s.t >= 0 and not self.dead then
      local dx, dy = p.x - s.x, p.y - s.y
      if dx * dx + dy * dy < (s.r + 6) ^ 2 then
        self:hurt(s.x)
        dead = true
      end
    end
    if dead then table.remove(self.shots, i) end
  end
end

function Play:updateItems(dt)
  local p = self.player
  for i = #self.items, 1, -1 do
    local it = self.items[i]
    it.t = it.t + dt
    if it.pop then it.pop = it.pop - dt; if it.pop <= 0 then it.pop = nil end end
    local dx, dy = p.x - it.x, p.y - it.y
    local near = abs(dx) < 14 and abs(dy) < 18
    local zone = abs(dx) < 16 and dy > -44 and dy < 20   -- shrines, altars and doors: anywhere in their height
    if it.kind == "ember" and not it.pop and (near or (dx * dx + dy * dy < 40 * 40 and self.boss == nil and false)) then
      self.embers = self.embers + 1
      K.sfx("ember")
      sparks:setColors({"#FFFFFF", "#FFB547", "#FFB54700"})
      sparks:emit(4, it.x, it.y)
      table.remove(self.items, i)
    elseif it.kind == "shard" and near then
      self.shardMask = self.shardMask | it.bit
      K.sfx("shard")
      K.rumble(0.5, 90)
      game.flash("#FFE14D", 0.2, 0.25)
      sparks:setColors({"#FFFFFF", "#FFE14D", "#FFE14D00"})
      sparks:emit(24, it.x, it.y)
      K.tip("shards", TR("tip_shards"), "star", 5)
      table.remove(self.items, i)
    elseif it.kind == "shrine" and zone and not it.lit then
      it.lit = true
      self.respawnX, self.respawnY = it.x, it.y
      self.hp = maxHearts()
      K.sfx("shrine")
      K.rumble(0.4, 100)
      game.toast(TR("shrine_lit"))
      sparks:setColors({"#FFFFFF", "#FFB547", "#FF8A1A00"})
      sparks:emit(30, it.x, it.y - 10)
      if it.light then it.light.radius = 110 end
      slot:set("embers", slot:get("embers", 0) + self.embers)
      self.embers = 0
      slot:stamp(TR("slot_summary", slot:get("unlocked", 1), totalShards()))
      K.tip("shrine", TR("tip_shrine"), "local_fire_department", 5)
    elseif it.kind == "altar" and abs(dx) < 18 and dy > -110 and dy < 20 and not it.used then   -- a beam of light: tall
      it.used = true
      local ab = self.lv.ability
      if ab then
        slot:set("ab_" .. ab, true)
        K.sfx("ability")
        K.rumble(0.8, 300)
        game.flash("#FFF1D6", 0.5, 0.6)
        self.banner = {text = TRd("ab_" .. ab), sub = TR("new_ability"), t = 3}
        sparks:setColors({"#FFFFFF", "#FFE14D", "#FFE14D00"})
        sparks:emit(60, it.x, it.y)
        if ab == "double" then K.tip("double_use", TR("tip_double", K.btn("jump") or ""), "keyboard_double_arrow_up", 7)
        elseif ab == "dash" then K.tip("dash_use", TR("tip_dash", K.btn("dash") or ""), "double_arrow", 7)
        else K.tip("wall_use", TR("tip_wall", K.btn("jump") or ""), "swap_horiz", 7) end
      end
    elseif it.kind == "exit" and abs(dx) < 16 and dy > -110 and dy < 20 then
      self:complete()
    end
  end
end

function Play:complete()
  if self.done then return end
  self.done = true
  K.sfx("clear")
  K.rumble(0.6, 200)
  local n = self.n
  slot:set("embers", slot:get("embers", 0) + self.embers)
  setShards(n, self.oldMask | self.shardMask)
  if n + 1 > slot:get("unlocked", 1) then slot:set("unlocked", min(#LV.LEVELS, n + 1)) end
  if self.lv.boss then slot:set("bonusHeart", max(slot:get("bonusHeart", 0), min(2, n // 4))) end   -- a heart per guardian
  slot:best("best_" .. n, self.time, true)
  slot:set("playtime", slot:get("playtime", 0) + self.time)
  slot:stamp(TR("slot_summary", slot:get("unlocked", 1), totalShards()))
  if n == #LV.LEVELS then slot:set("finished", true) end
  game.tween.after(1.0, function()
    game.push(Clear, {n = n, time = self.time, shards = self.shardMask, old = self.oldMask, embers = self.embers,
                      deaths = self.deaths, boss = self.lv.boss})
  end)
end

-- ---------------------------------------------------------------- draw
local function drawItem(it, t)
  local x, y = it.x, it.y
  if it.kind == "ember" then
    local b = sin(t * 4 + it.t) * 2
    G.circle(x, y + b, 6, "#FFB54730")
    G.polyT({0, -5, 4, 0, 0, 5, -4, 0}, x, y + b, 0, 1, 1, "#FFB547")
    G.circle(x, y + b - 1, 1.5, "#FFF1D6")
  elseif it.kind == "shard" then
    local b = sin(t * 3 + it.t) * 3
    G.circle(x, y + b, 13, "#FFE14D30")
    G.icon("star", x, y + b, 18, it.old and "#FFE14D90" or "#FFE14D")
  elseif it.kind == "shrine" then
    G.rect(x - 9, y - 6, 18, 16, 3, "#6A6A80")
    G.rect(x - 11, y - 10, 22, 5, 2, "#8A8AA0")
    if it.lit then
      G.circle(x, y - 16, 12 + sin(t * 6) * 1.5, "#FFB54740")
      G.poly({x - 5, y - 10, x + 5, y - 10, x, y - 24 - sin(t * 9) * 3}, "#FFB547")
      G.poly({x - 2.5, y - 10, x + 2.5, y - 10, x, y - 18}, "#FFF1D6")
    else
      G.circle(x, y - 14, 3, "#FFFFFF40")
    end
  elseif it.kind == "exit" then
    G.rect(x - 14, y - 30, 28, 40, 12, "#2A2440")
    G.rect(x - 11, y - 27, 22, 37, 10, "#FFE9A8" .. string.format("%02X", floor(140 + 60 * sin(t * 3))))
    G.icon("door_front", x, y - 8, 18, "#5A4632")
  elseif it.kind == "altar" then
    G.rect(x - 12, y - 4, 24, 14, 3, "#8A8AA0")
    if not it.used then
      G.circle(x, y - 16 + sin(t * 2) * 3, 9, "#FFE14D50")
      G.circle(x, y - 16 + sin(t * 2) * 3, 5, "#FFF1D6")
    end
  end
end

function Play:draw()
  local th = self.th
  K.accent = th.accent
  local cam, m, t = self.cam, self.map, game.realTime
  backdrop(th, cam)
  cam:attach()
  m:drawLayer(m.layers[1], nil)
  for _, c in ipairs(self.caps) do
    if cam:visible(c[1], c[3] - 8, c[2] - c[1], 16) then
      G.rect(c[1], c[3], c[2] - c[1], 5, 2, th.cap)
      G.color(th.cap2)
      for x = c[1] + 4, c[2] - 4, 9 do G.line(x, c[3] + 1, x + ((x * 7) % 5) - 2, c[3] - 3 - (x % 4), 1.4) end
    end
  end
  for _, it in ipairs(self.items) do
    if cam:visible(it.x - 20, it.y - 40, 40, 60) then drawItem(it, t) end
  end
  cam:detach()
  self.world:draw()
  cam:attach()
  for _, s in ipairs(self.shots) do
    if s.t < 0 then
      G.color("#FFFFFF60")
      G.line(s.x, TS, s.x, 15 * TS, 1)
    end
    local col = s.col or ({wave = "#B5E06A", thorn = "#7CD95C", crystal = "#7FE7FF", stalactite = "#B98CFF",
                           feather = "#FF8FB8", rock = "#9C8A70", orb = "#FF8A1A"})[s.kind] or "#FFFFFF"
    if s.kind == "wave" then
      G.poly({s.x - 8, s.y + 8, s.x, s.y - 10, s.x + 8, s.y + 8}, col)
    else
      G.circle(s.x, s.y, s.r * 1.8, col .. "40")
      G.circle(s.x, s.y, s.r, col)
    end
  end
  self:drawBoss(t)
  cam:detach()
  if self.lights then self.lights:draw(cam) end
  self:drawHUD()
end

function Play:drawBoss(t)
  local b = self.boss
  if not b or (b.dead and b.deadT > 1.0) then return end
  local x, y, r = b.x, b.y, b.r
  if b.dead then G.alpha(1 - b.deadT) end
  local flash = b.flash > 0
  if b.kind == "bramble" then
    local col = flash and "#FFFFFF" or "#6A8A3A"
    G.circle(x, y + 4, r, col)
    for k = 0, 8 do
      local a = pi + k / 8 * pi
      G.poly({x + cos(a) * r * 0.8, y + sin(a) * r * 0.8, x + cos(a + 0.18) * r * 1.5, y + sin(a + 0.18) * r * 1.5,
              x + cos(a + 0.36) * r * 0.8, y + sin(a + 0.36) * r * 0.8}, flash and "#FFFFFF" or "#3E5A22")
    end
    G.circle(x + b.face * 9, y - 2, 4, "#FFE14D")
    G.circle(x + b.face * 10, y - 2, 1.8, "#1A1020")
    if b.st == "crouch" then G.color("#FFFFFF80"); G.circleLine(x, y, r + 6, 2) end
  elseif b.kind == "golem" then
    local col = flash and "#FFFFFF" or "#5A5490"
    G.rect(x - r, y - r, r * 2, r * 2 + 2, 6, col)
    G.rect(x - r - 8, y - r * 0.4, 8, r, 3, col)
    G.rect(x + r, y - r * 0.4, 8, r, 3, col)
    G.poly({x - 8, y - r, x, y - r - 16, x + 8, y - r}, "#7FE7FF")
    G.circle(x + b.face * 6, y - 6, 4, (b.st == "slam" or b.st == "volley") and "#FF5A6E" or "#7FE7FF")
  else
    local col = flash and "#FFFFFF" or "#8A6ACD"
    local flap = sin(t * (b.st == "dive" and 4 or 12)) * 10
    G.poly({x - 6, y, x - 34, y - flap, x - 26, y + 10}, col)
    G.poly({x + 6, y, x + 34, y - flap, x + 26, y + 10}, col)
    G.circle(x, y, r, col)
    G.circle(x - 6, y - 4, 5, "#FFE14D"); G.circle(x + 6, y - 4, 5, "#FFE14D")
    G.circle(x - 6, y - 4, 2, "#1A1020"); G.circle(x + 6, y - 4, 2, "#1A1020")
    G.poly({x - 3, y + 2, x + 3, y + 2, x, y + 8}, "#FFB547")
    if b.st == "aim" then G.color("#FF5A6E90"); G.line(x, y, b.tx, b.ty, 2) end
  end
  if b.dead then G.unalpha() end
end

function Play:drawHUD()
  local W, H = game.width, game.height
  U.hearts(self.hp, maxHearts(), 14, 10, 14, "#FF5A6E")
  G.icon("local_fire_department", 20, 36, 14, "#FFB547")
  U.text(tostring(self.embers + slot:get("embers", 0)), 30, 29, 12, "#FFE9A8", "left", nil, "bold")
  if not self.lv.boss then
    local all = self.oldMask | self.shardMask
    for k = 0, 2 do
      local on = (all >> k) & 1 == 1
      G.icon("star", W - 70 + k * 20, 18, 16, on and "#FFE14D" or "#FFFFFF40")
    end
  end
  local ax = W - 70
  for i, ab in ipairs({"double", "dash", "wall"}) do
    if has(ab) then G.icon(({"keyboard_double_arrow_up", "double_arrow", "swap_horiz"})[i], ax + (i - 1) * 20, 40, 14, "#FFFFFFB0") end
  end
  local b = self.boss
  if b and not b.dead and b.st ~= "intro" then
    U.text(TRd("boss_" .. b.kind), 0, H - 34, 11, "#FFFFFF", "center", W, "bold")
    U.bar(W / 2 - 150, H - 18, 300, 8, b.hp / b.maxHp, "#FF5A6E")
  end
  if self.banner then
    local a = min(1, self.banner.t * 2, (2.4 - self.banner.t) * 4 + 1)
    G.alpha(max(0, min(1, a)))
    U.text(self.banner.text, 0, H * 0.3, 24, "#FFFFFF", "center", W, "bold")
    U.text(self.banner.sub, 0, H * 0.3 + 30, 12, self.th.accent, "center", W, "semibold")
    G.unalpha()
  end
end

-- ---------------------------------------------------------------- level clear
Clear = {transparent = true, pausable = false}
function Clear:enter(p)
  self.p, self.t = p, 0
  local items = {}
  local final = p.n == #LV.LEVELS
  if final then
    items[#items + 1] = {label = TR("continue"), icon = "auto_awesome", action = function() K.go(Ending, {}, "fade", 1.0) end}
  else
    items[#items + 1] = {label = TR("next_level"), icon = "skip_next", action = function() K.go(Play, {n = p.n + 1}, "circle", 0.5) end}
    items[#items + 1] = {label = TR("world_map"), icon = "map", action = function() K.go(Map, {n = p.n + 1}) end}
  end
  items[#items + 1] = {label = TR("retry"), icon = "replay", action = function() K.go(Play, {n = p.n}, "fade", 0.3) end}
  self.menu = K.menu{items = items, width = 220, itemHeight = 28, size = 12, accent = "#FFB547"}
end
function Clear:update(dt) self.t = self.t + dt; if self.t > 0.5 then self.menu:update() end end
function Clear:draw()
  local W, H = game.width, game.height
  local k = min(1, self.t / 0.4)
  G.rect(0, 0, W, H, 0, string.format("#000000%02X", floor(150 * k)))
  local w, h = 320, 210
  local x, y = (W - w) / 2, (H - h) / 2 + (1 - k) * 20
  K.frame(x, y, w, h, self.p.boss and TR("guardian_down") or TR("level_clear"), "#FFB547")
  local p = self.p
  local yy = y + 50
  if not p.boss then
    for s = 0, 2 do
      local got = ((p.shards | p.old) >> s) & 1 == 1
      local new = (p.shards >> s) & 1 == 1 and (p.old >> s) & 1 == 0
      local sk = min(1, max(0, (self.t - 0.3 - s * 0.15) / 0.25))
      G.icon("star", x + w / 2 + (s - 1) * 34, yy + 10, got and (20 + 8 * (1 - sk) * (new and 1 or 0)) or 20, got and "#FFE14D" or "#FFFFFF30")
    end
    yy = yy + 30
  end
  U.text(TR("clear_time", string.format("%d:%02d", floor(p.time / 60), floor(p.time % 60))), x, yy, 12, "#FFFFFFD0", "center", w, "semibold", false)
  U.text(TR("clear_embers", p.embers) .. "   ·   " .. TR("clear_deaths", p.deaths), x, yy + 18, 11, "#FFFFFFA0", "center", w, "semibold", false)
  self.menu:draw(W / 2, yy + 44)
end

-- ---------------------------------------------------------------- ending
Ending = {pausable = false}
function Ending:enter()
  K.music("title")
  self.t = 0
end
function Ending:update(dt)
  self.t = self.t + dt
  if random() < 0.6 then motes:emit(1, random() * game.width, game.height + 4) end
  motes:update(dt)
  if self.t > 3 and (I.pressed("confirm") or I.pointer.released) then K.go(Title) end
end
function Ending:draw()
  local W, H = game.width, game.height
  G.gradient(0, 0, W, H, "#1A1438", "#FFB088")
  motes:draw()
  local lines = {TR("end1"), TR("end2"), TR("end3")}
  for i, l in ipairs(lines) do
    local a = min(1, max(0, (self.t - i * 1.2) / 1.0))
    G.alpha(a)
    U.text(l, 40, H * 0.25 + i * 30, 15, "#FFF1D6", "center", W - 80, "semibold")
    G.unalpha()
  end
  if self.t > 4.5 then
    U.text(TR("end_stats", totalShards(), 27, slot:get("deaths", 0)), 0, H * 0.72, 12, "#FFFFFFC0", "center", W, "semibold", false)
    K.prompts({{"confirm", TR("k_menu")}}, W / 2, H - 30, 10)
  end
end

return K.run{
  width = 640, height = 360, scene = Title, title = Title, background = "#1A1438", accent = "#FFB547", dark = "#0A0818",
  controls = {"jump", "attack", "dash"},
  onDifficulty = function() end,
  onReset = function() for i = 1, 3 do game.save.slot(i):delete() end end,
}
