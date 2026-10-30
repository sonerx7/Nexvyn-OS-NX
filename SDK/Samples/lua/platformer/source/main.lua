-- Platformer demo: a guided tour of the nexvyn.game engine (sdk/SDK.md, section 8c).
--
-- What this file teaches, top to bottom:
--   1. a tilemap built from strings, with tiles drawn by code (no image files needed)
--   2. one-way platforms ("=" tiles): jump up through them, press down + jump to drop down
--   3. a camera that follows the hero with a deadzone, stays inside the level and shakes
--   4. parallax background layers drawn through cam:attach(factor)
--   5. frame animations (game.animations) driving a hero that is drawn with shapes
--   6. squash and stretch with game.tween, coyote time and a jump buffer for a fair jump
--   7. coins as map objects, world:collide, particles (game.emitter) and engine sounds
--   8. a trigger zone (the flag), game.save records and a HUD in scene:ui()

local game = require("nexvyn.game")
local G, I, U, A = game.gfx, game.input, game.ui, game.audio
local floor, sin, abs, max, min = math.floor, math.sin, math.abs, math.max, math.min

local TS = 16                                   -- tile size in world units
local save = game.save.open("records")          -- stored in the app's `store`

-- ------------------------------------------------------------------ 1. the level
-- One character per tile. "#" ground, "B" stone, "=" one-way platform, "o" coin, "P" start, "F" flag.
local ROWS = {
  "....................................................................................................",
  "....................................................................................................",
  "....................................................................................................",
  "....................................................................................................",
  ".........................................................ooo........................................",
  "...............ooo......................................=====........................ooo............",
  "..............=====.................................................................=====...........",
  "................................oo.................o.o.o...........oo.....................oo........",
  ".........ooo...........o........BB...ooo......o...======..........====..o......o.o........BB........",
  "........=====.........o.o.......BB..=====....o.o............BB.........o.o....=====.......BB........",
  "..............................BBBB..........................BBBB..........................BB........",
  "..P...........................BBBB..........................BBBB..........................BB....F...",
  "######################...####################...#######################...##########################",
  "######################...####################...#######################...##########################",
}

-- legend: a number is a tile id, a table places an object (and optionally a tile under it)
local LEGEND = {["#"] = 1, B = 2, ["="] = 3, o = {object = "coin"}, P = {object = "player"}, F = {object = "flag"}}

-- Tile drawing callbacks get world coordinates; the camera transform is already applied, so game.gfx is used.
local function drawGround(map, id, x, y, s)
  local tx, ty = floor(x / s), floor(y / s)
  G.rect(x, y, s, s, 0, "#8B5A3C")
  G.rect(x + 3, y + 7, 3, 3, 0, "#7A4D33")         -- pebbles
  G.rect(x + 10, y + 11, 2, 2, 0, "#A06A48")
  if map:get(tx, ty - 1) == 0 then                -- open sky above: grass on top
    G.rect(x, y, s, 5, 0, "#5CC85A")
    G.rect(x, y + 5, s, 2, 0, "#3E9E46")
  end
end
local function drawStone(map, id, x, y, s)
  G.rect(x, y, s, s, 0, "#6E7488")
  G.rect(x + 1, y + 1, s - 2, s - 2, 3, "#8C93A8")
  G.rect(x + 3, y + 3, s - 8, 3, 1, "#A7AEC2")    -- highlight
end
local function drawPlank(map, id, x, y, s)
  G.rect(x, y, s, 5, 1, "#C98B4B")
  G.rect(x, y + 5, s, 2, 0, "#8A5A2B")
  G.rect(x + s / 2 - 1, y + 2, 2, 2, 0, "#8A5A2B")  -- nail
end

local TILES = {
  [1] = {solid = true, draw = drawGround},
  [2] = {solid = true, draw = drawStone},
  [3] = {oneway = true, draw = drawPlank},          -- 2. one-way: solid only when landing from above
}

-- ------------------------------------------------------------------ input
-- "jump" works with A/B, space/up/W, the touch button and pushing the touch stick up.
I.bind("jump", {pad = {"a", "b"}, key = {"space", "up", "w", "z"}, touch = {"button:jump", "stick:up"}})
I.bind("restart", {key = {"r"}, pad = {"minus"}})
I.touchControls{stick = true, buttons = {{id = "jump", icon = "arrow_upward", action = "jump"}}}

-- ------------------------------------------------------------------ 5. the hero: animation + shapes
-- Frame numbers do not need a sprite sheet: the animation system only advances `self.frame`,
-- and Hero:render() below draws a different pose for every frame number.
local HERO_ANIMS = game.animations{
  idle = {frames = "1,1,1,2", fps = 3},
  run = {frames = "3-6", fps = 12},
  jump = {frames = {7}, loop = false},
  fall = {frames = {8}, loop = false},
}
-- leg offsets {left x, left lift, right x, right lift} and body bob for frames 1..8
local LEGS = {{-3, 0, 2, 0}, {-3, 0, 2, 0}, {-5, 0, 3, 2}, {-2, 1, 1, 0}, {-4, 2, 4, 0}, {-1, 0, 2, 1},
              {-4, 3, 2, 1}, {-3, 0, 2, 2}}
local BOB = {0, 1, 0, -1, 0, -1, -1, 0}

local Hero = game.class(game.Sprite)
function Hero:init(o)
  game.Sprite.init(self, o)
  self.anims = HERO_ANIMS
  self.w, self.h, self.z = 10, 14, 10           -- hitbox (centre based)
  self.body = true                              -- the world integrates velocity, gravity and tile collision
  self.maxVx, self.maxVy, self.dragX = 120, 420, 1000
  self.coyote, self.buffer, self.dropT = 0, 0, 0
  self.wasOnFloor, self.lastVy = true, 0
  self:play("idle")
end

-- squash and stretch: scale the drawing for a moment, then spring back (6.)
function Hero:squash(sx, sy)
  game.tween.to(self, 0.07, {sx = sx, sy = sy}, "outQuad"):after(self, 0.18, {sx = 1, sy = 1}, "outBack")
end

function Hero:update(dt)
  local mx = I.vector()                          -- -1..1 from stick, d-pad, keys or touch stick
  if abs(mx) < 0.2 then mx = 0 end
  self.ax = mx * 1100
  if mx ~= 0 and self.vx * mx < 0 then self.ax = mx * 2200 end   -- turning around is snappier
  if mx ~= 0 then self.flipX = mx < 0 end

  -- coyote time: you can still jump for 0.1 s after walking off a ledge
  if self.onFloor then self.coyote = 0.1 else self.coyote = self.coyote - dt end
  -- jump buffer: a jump pressed 0.12 s before landing still counts
  self.dropT = self.dropT - dt
  if I.pressed("jump") and I.down("down") and self.onFloor then
    self.dropT = 0.25                            -- 2. down + jump: fall through the plank you stand on
  elseif I.pressed("jump") then
    self.buffer = 0.12
  else
    self.buffer = self.buffer - dt
  end
  self.dropThrough = self.dropT > 0
  if self.buffer > 0 and self.coyote > 0 then
    self.vy = -340
    self.buffer, self.coyote = 0, 0
    self:squash(0.75, 1.3)
    A.play("jump")
  end
  if I.released("jump") and self.vy < -140 then self.vy = -140 end   -- let go early for a short hop

  -- landing: squash proportional to the fall speed, plus a puff of dust
  if self.onFloor and not self.wasOnFloor and self.lastVy > 160 then
    local k = min(1, self.lastVy / 420)
    self:squash(1 + 0.35 * k, 1 - 0.3 * k)
    self.scene.dust:emit(6, self.x, self.y + self.h / 2)
  end
  self.wasOnFloor, self.lastVy = self.onFloor, self.vy

  -- pick the animation from the physics state; play() only restarts when the name changes
  if self.onFloor then
    self:play(abs(self.vx) > 15 and "run" or "idle")
    self.animSpeed = max(0.5, abs(self.vx) / 100)
  else
    self:play(self.vy < 0 and "jump" or "fall")
  end
end

function Hero:render()
  local f = self.frame
  local d = self.flipX and -1 or 1
  local x, feet = self.x, self.y + self.h / 2
  local sx, sy = self.sx, self.sy
  local leg = LEGS[f]
  -- legs (drawn first, behind the body)
  G.rect(x + leg[1] * d - 1.5, feet - 4 - leg[2], 3, 4, 1, "#2B2F4A")
  G.rect(x + leg[3] * d - 1.5, feet - 4 - leg[4], 3, 4, 1, "#2B2F4A")
  -- body, scaled around the feet so squash keeps the hero on the ground
  local bw, bh = 12 * sx, 12 * sy
  local by = feet - 3 - bh + BOB[f]
  G.rect(x - bw / 2, by, bw, bh, 4, "#FF6B4A")
  G.rect(x - bw / 2, by + bh * 0.62, bw, 2, 0, "#C9432B")      -- belt
  -- scarf trailing behind, waving with time
  local wave = sin(game.time * 14) * 1.5
  G.color("#FFD23F")
  G.line(x - d * 4, by + 3, x - d * (10 + abs(self.vx) / 30), by + 2 + wave, 2.5)
  -- eye looks in the walking direction
  G.rect(x + d * 2 - 2, by + 3, 4, 4, 1, "#FFFFFF")
  G.rect(x + d * 3 - 1, by + 4, 2, 3, 0, "#1B1B2F")
end

-- ------------------------------------------------------------------ 7. coins
local COIN_ANIMS = game.animations{spin = {frames = "1-4,3,2", fps = 10}}
local COIN_W = {10, 7, 4, 2}                    -- apparent width per frame: a turning disc

local Coin = game.class(game.Sprite)
function Coin:init(o)
  game.Sprite.init(self, o)
  self.anims, self.r, self.y0 = COIN_ANIMS, 5, self.y
  self:play("spin")
  self.animTime = (self.x * 0.37) % 1           -- desynchronise the spins
end
function Coin:update() if not self.taken then self.y = self.y0 + sin(game.time * 3 + self.x * 0.1) * 1.5 end end
function Coin:render()
  local w = COIN_W[self.frame]
  G.rect(self.x - w / 2, self.y - 5, w, 10, min(w, 10) / 2, "#FFC93C")
  if w > 3 then G.rect(self.x - w / 2 + 1.5, self.y - 3, 1.5, 5, 0.75, "#FFF2B3") end   -- shine
end

-- ------------------------------------------------------------------ 4. parallax background
local function drawBackground(play)
  G.gradient(0, 0, game.width, game.height, "#6EC6FF", "#D9F1FF")
  local cam = play.cam
  -- far mountains move at 15 %, near hills at 40 %, clouds at 8 % of the camera speed
  local layers = {
    {f = 0.15, color = "#9DB8E8", base = 150, step = 120, size = 70},
    {f = 0.4, color = "#7CC79A", base = 175, step = 80, size = 42},
  }
  for _, L in ipairs(layers) do
    cam:attach(L.f)
    local vx, _, vw = cam:view()
    vx = vx * L.f                               -- the view, as seen through this layer
    G.color(L.color)
    local first = floor((vx - L.size * 2) / L.step)
    for i = first, first + floor(vw / L.step) + 4 do
      local px = i * L.step + (i * 37 % 23)
      local hgt = L.size + (i * 53 % 30)
      G.poly({px - hgt, L.base + 40, px, L.base - hgt * 0.8, px + hgt, L.base + 40})
    end
    G.rect(vx - 50, L.base + 39, vw + 100, 200)
    cam:detach()
  end
  cam:attach(0.08)
  local vx, _, vw = cam:view()
  vx = vx * 0.08
  G.color(255, 255, 255, 190)
  local first = floor((vx - 80) / 110)
  for i = first, first + floor(vw / 110) + 2 do
    local cx, cy = i * 110 + (i * 71 % 40), 30 + (i * 29 % 35)
    G.circle(cx, cy, 9); G.circle(cx + 11, cy - 4, 12); G.circle(cx + 23, cy, 8)
  end
  cam:detach()
end

-- ------------------------------------------------------------------ the scene
local Play = {controls = true}                  -- controls: show the touch stick/buttons after a touch

function Play:enter()
  -- 1. build the map from the strings above
  self.map = game.tilemap.fromStrings(ROWS, LEGEND, {tileSize = TS, tiles = TILES})
  -- 3. camera: smooth follow, a deadzone the hero can move in freely, aim a little above the hero
  self.cam = game.camera{lerp = 0.12, deadzone = {w = 40, h = 48}, offsetY = -12}
  self.cam:setBounds(0, 0, self.map.pixelWidth, self.map.pixelHeight)
  self.world = game.world{gravity = 900, map = self.map, camera = self.cam}
  local world = self.world

  -- particles live in the world, so they are drawn through the camera
  self.dust = world:addEmitter(game.emitter{max = 80, life = {0.2, 0.45}, speed = {15, 60}, angle = -math.pi / 2,
    spread = 2.6, gravity = 150, size = {4, 0}, colors = {"#FFFFFFD0", "#E8DCC800"}})
  self.sparkle = world:addEmitter(game.emitter{max = 200, life = {0.3, 0.7}, speed = {40, 140}, size = {3, 0},
    gravity = 220, colors = {"#FFF6B0", "#FFC93C", "#FF8A0000"}, shape = "square"})

  -- objects placed in the strings become entities
  self.total, self.coins, self.falls, self.time, self.won = 0, 0, 0, 0, false
  for _, o in ipairs(self.map.objects) do
    if o.type == "player" then
      self.spawnX, self.spawnY = o.x, o.y
    elseif o.type == "coin" then
      world:add(Coin{x = o.x, y = o.y}, "coins")
      self.total = self.total + 1
    elseif o.type == "flag" then
      self.flag = {x = o.x, y = o.y + TS / 2}
      -- 8. a trigger zone: onEnter runs once when the hero walks into the rectangle
      world:trigger{x = o.x - 6, y = o.y - 48, w = 12, h = 64, filter = "hero", onEnter = function() self:reachFlag() end}
    end
  end
  self.hero = world:add(Hero{x = self.spawnX, y = self.spawnY, scene = self}, "hero")
  self.safeX, self.safeY = self.spawnX, self.spawnY
  self.cam:follow(self.hero)
  self.cam:snap()                               -- start on the hero instead of gliding in

  -- 7. hero touches a coin: count it, burst of sparkles, float up and fade out
  world:collide(self.hero, "coins", function(h, c)
    if c.taken then return end
    c.taken = true
    self.coins = self.coins + 1
    A.play("coin")
    self.sparkle:emit(12, c.x, c.y)
    game.tween.to(c, 0.4, {y = c.y - 20, alpha = 0}, "outQuad"):oncomplete(function() c.dead = true end)
    if self.coins == self.total then U.toast(TR("all_coins"), 2) end
  end)
  self.best = save:get("best", nil)
end

function Play:restart() self:enter() end      -- also adds "Restart" to the pause menu

function Play:reachFlag()
  if self.won then return end
  if self.coins < self.total then
    U.toast(TR("coins_left", self.total - self.coins), 1.6)
    return
  end
  self.won = true
  A.play("win")
  -- :best(key, value, lower) keeps the smallest time and tells whether this is a new record
  self.record = save:best("best", floor(self.time * 10) / 10, true)
  self.best = save:get("best", nil)
  game.tween.every(0.25, function()            -- a few fireworks over the flag
    self.sparkle:emit(25, self.flag.x + game.rand(-40, 40), self.flag.y - game.rand(40, 90))
  end, 6)
end

function Play:update(dt)
  if not self.won then self.time = self.time + dt end
  local h = self.hero
  if h.onFloor then self.safeX, self.safeY = h.x, h.y end
  -- fell into a gap: back to the last ground, shake the camera, buzz the controller
  if h.y > self.map.pixelHeight + 40 then
    self.falls = self.falls + 1
    h.x, h.y, h.vx, h.vy = self.safeX - (h.vx > 0 and 24 or -24), self.safeY - 8, 0, 0
    self.cam:shake(4, 0.3)
    A.play("hit")
    sys.vibrate(0.5, 90)
  end
  if (self.won and I.pressed("confirm")) or I.pressed("restart") then self:restart() return end
  self.world:update(dt)                         -- entities, animation, physics, collisions, camera, particles
end

function Play:draw()
  drawBackground(self)
  -- the flag pole is drawn through the camera too
  self.cam:attach()
  local f = self.flag
  if f then
    G.rect(f.x - 1, f.y - 56, 2, 56, 0, "#E8E8F0")
    local wave = sin(game.time * 6) * 2
    G.poly({f.x + 1, f.y - 56, f.x + 20, f.y - 50 + wave, f.x + 1, f.y - 44}, self.won and "#4CD964" or "#FF4D6D")
  end
  self.cam:detach()
  self.world:draw()                             -- tilemap, entities sorted by z, emitters
end

local function fmtTime(t) return string.format("%d:%04.1f", floor(t / 60), t % 60) end

-- scene:ui() is drawn after draw(), in screen units, without the camera
function Play:ui()
  local m = 8
  U.panel(m, m, 112, 34, 8, "#00000066")
  G.circle(m + 13, m + 11, 5, "#FFC93C")
  U.text(TR("coins", self.coins, self.total), m + 24, m + 4, 11, "#FFFFFF")
  U.text(TR("time", fmtTime(self.time)), m + 8, m + 19, 9, "#FFFFFFC0", nil, nil, "semibold")
  if self.best then
    U.text(TR("best", fmtTime(self.best)), 0, m + 4, 9, "#FFFFFFC0", "right", game.width - m - (I.touchVisible() and 34 or 0), "semibold")
  end
  if self.time < 6 and not self.won then
    local hint = TR("hint")                     -- shrinks to fit narrow windows
    local size = min(9, 9 * (game.width - 16) / max(1, G.textWidth(hint, 9, "semibold")))
    U.text(hint, 0, game.height - 8 - size * 1.3, size, "#FFFFFF", "center", game.width, "semibold")
  end
  if self.won then
    local w, h = 220, 92
    local x, y = (game.width - w) / 2, (game.height - h) / 2
    U.panel(x, y, w, h, 12, "#101828E0")
    U.text(TR("clear"), x, y + 10, 18, "#FFE066", "center", w)
    U.text(TR("result", fmtTime(self.time), self.falls), x, y + 38, 11, "#FFFFFF", "center", w, "semibold")
    if self.record then U.text(TR("new_record"), x, y + 54, 10, "#7CFFB2", "center", w, "semibold") end
    if U.button(TR("again"), x + w / 2 - 50, y + h - 26, 100, 20) then self:restart() end
  end
end

-- ------------------------------------------------------------------ run
return game.run{
  width = 400, height = 225,                    -- design size; "expand" grows the longer side, no bars
  scale = "expand",
  scene = Play,
  background = "#6EC6FF",
  menu = function()
    return {{title = TR("menu_title"), items = {
      {label = TR("restart"), id = 1, shortcut = "R"},
      {label = TR("debug"), id = 2, shortcut = "F3"},
      "-",
      {label = TR("reset_record"), id = 3},
    }}}
  end,
  onmenu = function(id)
    local play = game.current()
    if id == 1 and play and play.restart then play:restart()
    elseif id == 2 then game.debug = not game.debug   -- F3 overlay: FPS, bodies and the colliders
    elseif id == 3 then
      save:reset()
      if play then play.best = nil end
      U.toast(TR("record_reset"))
    end
  end,
}
