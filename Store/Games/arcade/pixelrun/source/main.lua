-- Pixel Koşu: a platformer built with the nexvyn.game engine (romfs:/System/Lua/nexvyn/game).
-- Tilemap, gravity, coins, stomping enemies, checkpoints and three levels.

local game = require("nexvyn.game")
local LEVELS = require("levels")

local G, I, U, A = game.gfx, game.input, game.ui, game.audio
local floor, sin, abs, max, min = math.floor, math.sin, math.abs, math.max, math.min

local save = game.save.open("progress")

-- ---------------------------------------------------------------- art
local SHEET_OPTS = {spacing = 4, scale = 0.25}
local heroSheet, enemySheet, itemSheet, tileSheet
local heroAnims = game.animations{
  idle = {frames = "1,1,1,1,2", fps = 3}, run = {frames = "3-6", fps = 12},
  jump = {frames = {7}, loop = false}, fall = {frames = {8}, loop = false}, hurt = {frames = {9}, loop = false},
}
local walkerAnims = game.animations{walk = {frames = "1-2", fps = 5}, squash = {frames = {3}, loop = false}}
local flyerAnims = game.animations{fly = {frames = "4-5", fps = 6}}
local coinAnims = game.animations{spin = {frames = "1-4,3,2", fps = 9}}

local TILES = {
  [1] = {solid = true}, [2] = {solid = true}, [3] = {solid = true}, [4] = {oneway = true},
  [5] = {hazard = true}, [6] = {solid = true}, [7] = {}, [8] = {},
}
local LEGEND = {
  ["#"] = 1, B = 3, S = 6, ["="] = 4, ["^"] = 5, b = 7, f = 8,
  o = {object = "coin"}, h = {object = "heart"}, e = {object = "walker"}, v = {object = "flyer"},
  c = {object = "checkpoint"}, G = {object = "goal"}, P = {object = "player"},
}

local function loadArt()
  heroSheet = game.sheet("bundle:/img/hero.png", 64, 64, {spacing = 4, scale = 0.25, flipped = "bundle:/img/hero_flip.png"})
  enemySheet = game.sheet("bundle:/img/enemy.png", 64, 64, {spacing = 4, scale = 0.25, flipped = "bundle:/img/enemy_flip.png"})
  itemSheet = game.sheet("bundle:/img/items.png", 64, 64, SHEET_OPTS)
  tileSheet = game.sheet("bundle:/img/tiles.png", 64, 64, {margin = 4, spacing = 8})
end

-- ---------------------------------------------------------------- sounds and music
A.define("stomp", {wave = "square", volume = 0.2, notes = {{330, 0.04}, {660, 0.08}}})
A.define("checkpoint", {wave = "triangle", volume = 0.25, notes = "C5:0.08 E5:0.08 G5:0.16"})
local SONGS = {
  title = {bpm = 112, wave = "triangle", volume = 0.07, notes = "C5 E5 G5 E5 F5 A5 G5 - E5 G5 C6 G5 F5 D5 C5 -",
           bass = "C3:2 G2:2 F2:2 G2:2"},
  play = {bpm = 140, wave = "triangle", volume = 0.05,
          notes = "E5 G5 A5 G5 E5 D5 C5 D5 E5 - E5 D5 C5 - G4 - A4 C5 D5 C5 A4 G4 A4 C5 D5 - E5 D5 C5 - - -",
          bass = "A2:2 E3:2 F2:2 C3:2 D3:2 A2:2 G2:2 G2:2"},
}

-- ---------------------------------------------------------------- input
I.bind("jump", {pad = {"a", "b"}, key = {"space", "up", "w", "z", "k"}, touch = {"button:jump", "stick:up"}})
I.touchControls{stick = true, buttons = {{id = "jump", icon = "arrow_upward", action = "jump"}}}

-- ---------------------------------------------------------------- entities
local Hero = game.class(game.Sprite)
function Hero:init(o)
  game.Sprite.init(self, o)
  self.sheet, self.anims = heroSheet, heroAnims
  self.w, self.h, self.dy, self.z = 9, 14, -1, 10
  self.body, self.maxVx, self.maxVy, self.dragX = true, 112, 420, 900
  self.vx, self.vy, self.ax = 0, 0, 0
  self.coyote, self.buffer, self.invuln = 0, 0, 0
  self:play("idle")
end

function Hero:update(dt)
  local play = self.scene
  if self.dying then return end
  local mx = I.vector()
  if abs(mx) < 0.25 then mx = 0 end
  self.ax = mx * 950
  if mx ~= 0 and self.vx * mx < 0 then self.ax = mx * 1900 end   -- quick turn
  if mx ~= 0 then self.flipX = mx < 0 end
  if self.onFloor then self.coyote = 0.1 else self.coyote = self.coyote - dt end
  self.dropT = (self.dropT or 0) - dt
  if I.pressed("jump") and I.down("down") and self.onFloor then
    self.dropT = 0.25                                                  -- down + jump: drop through a platform
  elseif I.pressed("jump") then
    self.buffer = 0.12
  else
    self.buffer = self.buffer - dt
  end
  self.dropThrough = self.dropT > 0
  if self.buffer > 0 and self.coyote > 0 then
    self.vy = -318
    self.buffer, self.coyote = 0, 0
    A.play("jump")
  end
  if I.released("jump") and self.vy < -120 then self.vy = -120 end   -- short hop
  self.invuln = self.invuln - dt
  self.alpha = (self.invuln > 0 and floor(self.invuln * 12) % 2 == 0) and 0.35 or 1
  if self.onFloor then
    self:play(abs(self.vx) > 12 and "run" or "idle")
  else
    self:play(self.vy < 0 and "jump" or "fall")
  end
  -- spikes and falling out of the level
  local id = play.map:findTile(self.x - 3, self.y, 6, self.h / 2, "hazard")
  if id or self.y > play.map.pixelHeight + 40 then play:die() end
end

local Walker = game.class(game.Sprite)
function Walker:init(o)
  game.Sprite.init(self, o)
  self.sheet, self.anims = enemySheet, walkerAnims
  self.w, self.h, self.dy, self.body, self.dir, self.z = 12, 9, -3, true, -1, 5
  self:play("walk")
end
function Walker:update()
  if self.squashed then return end
  if self.onWall ~= 0 and self.onWall ~= nil then self.dir = -self.onWall end
  local map = self.scene.map
  local tx, ty = map:toTile(self.x + self.dir * (self.w / 2 + 2), self.y + self.h / 2 + 2)
  if self.onFloor and map:solid(tx, ty) == 0 then self.dir = -self.dir end
  self.vx = self.dir * 28
  self.flipX = self.dir > 0
end

local Flyer = game.class(game.Sprite)
function Flyer:init(o)
  game.Sprite.init(self, o)
  self.sheet, self.anims = enemySheet, flyerAnims
  self.w, self.h, self.z = 12, 8, 5
  self.x0, self.y0, self.t = self.x, self.y, math.random() * 6
  self:play("fly")
end
function Flyer:update(dt)
  if self.squashed then
    self.vy = (self.vy or 0) + 900 * dt
    self.y = self.y + self.vy * dt
    if self.y > self.scene.map.pixelHeight + 40 then self.dead = true end
    return
  end
  self.t = self.t + dt
  local px = self.x
  self.x = self.x0 + sin(self.t * 0.9) * 40
  self.y = self.y0 + sin(self.t * 3) * 6
  self.flipX = self.x > px
end

-- ---------------------------------------------------------------- background
local function drawBackground(play)
  local lv = play.level
  G.gradient(0, 0, game.width, game.height, lv.sky[1], lv.sky[2])
  local cam = play.cam
  -- far and near hills (parallax)
  for layer = 1, 2 do
    local f = layer == 1 and 0.2 or 0.45
    cam:attach(f)
    local x0, _, vw = cam:view()
    x0 = x0 * f
    G.color(lv.hills[layer])
    local base = play.map.pixelHeight - (layer == 1 and 70 or 40)
    local spacing = layer == 1 and 150 or 95
    local first = floor((x0 - 100) / spacing)
    for i = first, first + floor(vw / spacing) + 3 do
      local r = (layer == 1 and 90 or 55) + (i * 37 % 30)
      G.circle(i * spacing + (i * 53 % 40), base + 30, r)
    end
    G.rect(x0 - 200, base + 30, vw + 400, 300)
    cam:detach()
  end
  -- clouds
  cam:attach(0.1)
  local x0, _, vw = cam:view()
  x0 = x0 * 0.1
  G.color(255, 255, 255, 150)
  local first = floor((x0 - 60) / 120)
  for i = first, first + floor(vw / 120) + 2 do
    local cx, cy = i * 120 + (i * 71 % 50), 26 + (i * 29 % 40)
    G.circle(cx, cy, 10); G.circle(cx + 12, cy - 4, 13); G.circle(cx + 25, cy, 9)
  end
  cam:detach()
end

-- ---------------------------------------------------------------- scenes
local Title, Play, Clear, GameOver = {pausable = false}, {controls = true}, {transparent = true, pausable = false},
  {transparent = true, pausable = false}

local function fmtTime(t) return string.format("%d:%04.1f", floor(t / 60), t % 60) end

-- title -----------------------------------------------------------------------------------------
function Title:enter()
  self.t = 0
  self.level = LEVELS[1]
  self.selectLevel = 1
  local unlocked = save:get("unlocked", 1)
  self.menu = U.menu{width = 190, itemHeight = 27, size = 14, items = {
    {label = function() return TR("start") end, action = function() game.switch(Play, {level = 1, lives = 3}) end},
    {label = function() return TR("level_select", self.selectLevel, TR(LEVELS[self.selectLevel].name)) end,
     enabled = function() return save:get("unlocked", 1) > 1 end,
     action = function() game.switch(Play, {level = self.selectLevel, lives = 3}) end,
     left = function() self.selectLevel = (self.selectLevel - 2) % unlocked + 1 end,
     right = function() self.selectLevel = self.selectLevel % unlocked + 1 end},
    {label = function() return TR("sound", A.muted and TR("off") or TR("on")) end,
     action = function() A.setMuted(not A.muted); game.save.open("settings"):set("muted", A.muted) end},
    {label = function() return TR("quit") end, action = function() sys.exit() end},
  }}
  self.map = game.tilemap.fromStrings(LEVELS[1].build(), LEGEND, {tileset = tileSheet, tiles = TILES})
  self.cam = game.camera{}
  A.song(SONGS.title)
end
function Title:update(dt)
  self.t = self.t + dt
  self.cam:lookAt(game.width / 2 + self.t * 20 % (self.map.pixelWidth - game.width), self.map.pixelHeight - game.height / 2)
  self.menu:update()
end
function Title:draw()
  drawBackground(self)
  self.map:draw(self.cam)
end
function Title:ui()
  local cy = game.height * 0.16
  U.pixelText(TR("logo"), 0, cy, 5, "#FFE066", "center", game.width, "#3A2A10")
  U.text(TR("tagline"), 0, cy + 36, 12, "#FFFFFF", "center", game.width)
  self.menu:draw(game.width / 2, cy + 62)
  -- the controls line is long: it gets smaller instead of running off both edges
  local cs = TR("controls")
  local csz = math.min(9, 9 * (game.width - 16) / math.max(1, gfx.textWidth(cs, 9, "semibold")))
  U.text(cs, 0, game.height - 6 - csz * 1.3, csz, "#FFFFFFD0", "center", game.width, "semibold")
end

-- play ------------------------------------------------------------------------------------------
function Play:enter(p)
  p = p or {level = 1, lives = 3}
  self.levelIndex, self.lives = p.level, p.lives or 3
  self.coinsTotal = p.coins or 0
  self.level = LEVELS[self.levelIndex]
  self:build()
  A.song(SONGS.play)
end

function Play:build()
  local map = game.tilemap.fromStrings(self.level.build(), LEGEND, {tileset = tileSheet, tiles = TILES})
  -- grass on top of exposed ground
  for ty = 0, map.height - 1 do
    for tx = 0, map.width - 1 do
      if map:get(tx, ty) == 1 and map:solid(tx, ty - 1) ~= 1 then map:set(tx, ty, 2) end
    end
  end
  self.map = map
  self.cam = game.camera{lerp = 0.14, deadzone = {w = 36, h = 44}, offsetY = -12}
  self.cam:setBounds(0, -200, map.pixelWidth, map.pixelHeight + 200)
  local world = game.world{gravity = 920, map = map, camera = self.cam}
  self.world = world
  self.coins, self.stomps, self.time = 0, 0, 0
  self.dust = world:addEmitter(game.emitter{max = 120, life = {0.25, 0.5}, speed = {20, 70}, angle = -math.pi / 2,
    spread = 2.4, gravity = 200, size = {3, 0}, colors = {"#FFF6C0", "#FFD54A00"}, shape = "square"})
  self.puff = world:addEmitter(game.emitter{max = 120, life = {0.3, 0.6}, speed = {30, 90}, size = {4, 1},
    colors = {"#FFFFFF", "#C8C8E000"}, damping = 3})
  local spawnX, spawnY = 40, 150
  for _, o in ipairs(map.objects) do
    if o.type == "player" then spawnX, spawnY = o.x, o.y
    elseif o.type == "coin" or o.type == "heart" then
      local s = world:add(game.sprite{x = o.x, y = o.y, sheet = itemSheet, w = 10, h = 10, kind = o.type}, "items")
      if o.type == "coin" then s.anims = coinAnims; s:play("spin") else s.frame = 8; s.y0 = o.y end
    elseif o.type == "walker" then world:add(Walker{x = o.x, y = o.y + 3, scene = self}, "enemies")
    elseif o.type == "flyer" then world:add(Flyer{x = o.x, y = o.y, scene = self}, "enemies")
    elseif o.type == "checkpoint" then
      local f = world:add(game.sprite{x = o.x, y = o.y, sheet = itemSheet, frame = 5, z = 1})
      world:trigger{x = o.x - 8, y = o.y - 40, w = 16, h = 56, filter = "hero", onEnter = function(h)
        if self.checkX ~= o.x and not h.dying then
          self.checkX, self.checkY = o.x, o.y
          f.frame = 6
          A.play("checkpoint")
          U.toast(TR("checkpoint"), 1.5)
        end
      end}
    elseif o.type == "goal" then
      world:add(game.sprite{x = o.x, y = o.y, sheet = itemSheet, frame = 7, z = 1})
      world:trigger{x = o.x - 6, y = o.y - 60, w = 12, h = 76, filter = "hero", onEnter = function(h)
        if not h.dying and not self.finished then self:finish() end
      end}
    end
  end
  self.spawnX, self.spawnY = spawnX, spawnY
  self.checkX, self.checkY = spawnX, spawnY
  self.hero = world:add(Hero{x = spawnX, y = spawnY, scene = self}, "hero")
  self.cam:follow(self.hero)
  self.cam:snap()
  world:collide(self.hero, "items", function(h, it) self:collect(it) end)
  world:collide(self.hero, "enemies", function(h, e) self:touchEnemy(h, e) end)
  self.finished = false
end

function Play:restart() self:build() end

function Play:collect(it)
  if it.taken then return end
  it.taken = true
  if it.kind == "heart" then
    self.lives = self.lives + 1
    A.play("power")
  else
    self.coins = self.coins + 1
    A.play("coin")
  end
  self.dust:emit(8, it.x, it.y)
  it.anims = nil
  game.tween.to(it, 0.35, {y = it.y - 18, alpha = 0}, "outQuad"):oncomplete(function() it.dead = true end)
end

function Play:touchEnemy(h, e)
  if h.dying or e.squashed then return end
  if h.vy > 40 and h.y < e.y - 2 then
    e.squashed = true
    e.body = false
    self.stomps = self.stomps + 1
    h.vy = I.down("jump") and -330 or -230
    A.play("stomp")
    self.puff:emit(10, e.x, e.y)
    self.cam:shake(2, 0.15)
    if e.anims == walkerAnims then
      e:play("squash")
      game.tween.after(0.5, function() e.dead = true end)
    end
  elseif h.invuln <= 0 then
    self:die()
  end
end

function Play:die()
  local h = self.hero
  if h.dying or self.finished then return end
  h.dying = true
  h.collideMap = false
  h.vx, h.ax, h.vy = 0, 0, -260
  h:play("hurt")
  A.play("lose")
  sys.vibrate(0.6, 120)
  self.cam:shake(4, 0.3)
  self.cam.target = nil
  self.lives = self.lives - 1
  game.tween.after(1.3, function()
    if self.lives <= 0 then
      game.push(GameOver, {level = self.levelIndex})
    else
      h.dying, h.collideMap = false, true
      h.x, h.y, h.vx, h.vy = self.checkX, self.checkY, 0, 0
      h.invuln = 1.5
      h:play("idle")
      self.cam.target = h
      self.cam:snap()
    end
  end)
end

function Play:finish()
  self.finished = true
  local h = self.hero
  h.ax, h.vx = 0, 0
  A.play("win")
  self.dust:emit(30, h.x, h.y - 10)
  local i = self.levelIndex
  local best = save:best("time" .. i, floor(self.time * 10) / 10, true)
  save:best("coins" .. i, self.coins)
  save:set("unlocked", max(save:get("unlocked", 1), min(#LEVELS, i + 1)))
  game.tween.after(0.8, function()
    game.push(Clear, {level = i, coins = self.coins, time = self.time, record = best, lives = self.lives,
                      total = self.coinsTotal + self.coins})
  end)
end

function Play:update(dt)
  if not self.finished then self.time = self.time + dt end
  self.world:update(dt)
  local items = self.world:group("items")
  for i = 1, items.n do
    local it = items[i]
    if it.y0 and not it.taken then it.y = it.y0 + sin(game.time * 4) * 2 end
  end
end

function Play:draw()
  drawBackground(self)
  self.world:draw()
end

function Play:ui()
  local m = 8
  -- coins
  itemSheet:draw(1, m + 6, m + 6, 0, 1, 1)
  U.pixelText("x" .. self.coins, m + 16, m + 2, 2, "#FFE066")
  -- lives
  for k = 1, min(self.lives, 6) do itemSheet:draw(8, m + 6 + (k - 1) * 14, m + 26, 0, 0.8, 0.8) end
  -- level and time
  U.text(TR(self.level.name), 0, m, 11, "#FFFFFF", "center", game.width)
  U.pixelText(fmtTime(self.time), game.width - m - U.pixelWidth(fmtTime(self.time), 2) - (I.touchVisible() and 30 or 0),
              m + 2, 2, "#FFFFFF")
end

-- level clear -------------------------------------------------------------------------------------
function Clear:enter(p)
  self.p = p
  local last = p.level >= #LEVELS
  local items = {}
  if not last then
    items[#items + 1] = {label = function() return TR("next_level") end,
      action = function() game.switch(Play, {level = p.level + 1, lives = p.lives, coins = p.total}) end}
  end
  items[#items + 1] = {label = function() return TR("replay") end,
    action = function() game.switch(Play, {level = p.level, lives = 3}) end}
  items[#items + 1] = {label = function() return TR("main_menu") end, action = function() game.switch(Title) end}
  self.menu = U.menu{width = 180, items = items}
  self.last = last
  A.stopSong()
end
function Clear:update() self.menu:update() end
function Clear:ui()
  local p = self.p
  G.rect(0, 0, game.width, game.height, 0, "#00000080")
  local w, h = 240, 196
  local x, y = (game.width - w) / 2, (game.height - h) / 2
  U.panel(x, y, w, h, 12)
  U.text(self.last and TR("all_clear") or TR("level_clear"), x, y + 12, 17, "#FFE066", "center", w)
  U.text(TR("coins_got", p.coins), x, y + 40, 12, "#FFFFFF", "center", w, "semibold")
  U.text(TR("time_got", fmtTime(p.time)), x, y + 58, 12, "#FFFFFF", "center", w, "semibold")
  if p.record then U.text(TR("new_record"), x, y + 76, 12, "#7CFFB2", "center", w) end
  self.menu:draw(game.width / 2, y + 98)
end

-- game over -------------------------------------------------------------------------------------
function GameOver:enter(p)
  self.p = p
  self.menu = U.menu{width = 180, items = {
    {label = function() return TR("retry") end, action = function() game.switch(Play, {level = p.level, lives = 3}) end},
    {label = function() return TR("main_menu") end, action = function() game.switch(Title) end},
  }}
  A.stopSong()
end
function GameOver:update() self.menu:update() end
function GameOver:ui()
  G.rect(0, 0, game.width, game.height, 0, "#00000099")
  U.pixelText(TR("game_over"), 0, game.height / 2 - 60, 4, "#FF6060", "center", game.width)
  self.menu:draw(game.width / 2, game.height / 2 - 10)
end

-- ---------------------------------------------------------------- run
return game.run{
  width = 384, height = 216, scale = "expand",
  scene = Title, title = Title,
  background = "#7EC8F8",
  load = loadArt,
  menu = function()
    return {{title = TR("game_menu"), items = {
      {label = TR("pause_menu"), id = 1, shortcut = "Esc"},
      {label = TR("main_menu"), id = 2},
      "-",
      {label = TR("debug"), id = 3, shortcut = "F3"},
      {label = TR("reset_progress"), id = 4},
    }}}
  end,
  onmenu = function(id)
    if id == 1 then game.pause()
    elseif id == 2 then game.switch(Title)
    elseif id == 3 then game.debug = not game.debug
    elseif id == 4 then save:reset(); U.toast(TR("progress_reset"))
    end
  end,
}
