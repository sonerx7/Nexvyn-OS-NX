-- Void Delve: a twin-stick roguelite. Delve through three procedurally built floors of the Void, clear rooms of
-- enemies, pick relics that change how you fight, buy from the shop, beat a boss on every floor and spend the void
-- essence you bring back on permanent upgrades. Built on nexvyn.game with the shared kit (kit.lua).
local game = require("nexvyn.game")
local K = require("kit")
local D = require("data")
local G, I, U, A = game.gfx, game.input, game.ui, game.audio
local floor, min, max, sin, cos, abs, pi, sqrt, atan, random = math.floor, math.min, math.max, math.sin, math.cos,
  math.abs, math.pi, math.sqrt, math.atan, math.random

local save = game.save.open("delve")
local TRd = function(k, ...) return TR(k, ...) end

-- arena (virtual units): 13 x 7 cells inside the walls
local AX, AY, AW, AH = 20, 46, 600, 296
local CW, CH = AW / 13, AH / 7
local FLOORS = 3
local FLOORCOL = {"#2EE6D6", "#FF4DCB", "#FFB547"}
local FLOORBG = {{"#070A1A", "#0E1430"}, {"#12061A", "#22092E"}, {"#160B06", "#2A1508"}}

-- ---------------------------------------------------------------- sound and music
K.track("title", "bundle:/music/title.ogg", 20)
K.track("delve", "bundle:/music/delve.ogg", 15)
K.track("boss", "bundle:/music/boss.ogg", 12.632)
K.sound("ui_move", "bundle:/sfx/ui_move.wav", 0.6)
K.sound("ui_ok", "bundle:/sfx/ui_ok.wav", 0.7)
K.sound("ui_back", "bundle:/sfx/ui_back.wav", 0.6)
K.sound("shoot", {"bundle:/sfx/shoot1.wav", "bundle:/sfx/shoot2.wav", "bundle:/sfx/shoot3.wav"}, 0.32, 0.05)
K.sound("hit", {"bundle:/sfx/hit1.wav", "bundle:/sfx/hit2.wav"}, 0.5, 0.04)
K.sound("kill", {"bundle:/sfx/kill1.wav", "bundle:/sfx/kill2.wav"}, 0.7, 0.05)
K.sound("hurt", "bundle:/sfx/hurt.wav", 0.9, 0.2)
K.sound("dash", "bundle:/sfx/dash.wav", 0.6, 0.1)
K.sound("bomb", "bundle:/sfx/bomb.wav", 1.0, 0.3)
K.sound("shard", {"bundle:/sfx/shard1.wav", "bundle:/sfx/shard2.wav"}, 0.45, 0.04)
K.sound("door", "bundle:/sfx/door.wav", 0.7, 0.3)
K.sound("relic", "bundle:/sfx/relic.wav", 0.9)
K.sound("eshoot", "bundle:/sfx/eshoot.wav", 0.35, 0.07)
K.sound("boom", "bundle:/sfx/boom.wav", 0.8, 0.1)
K.sound("warp", "bundle:/sfx/warp.wav", 0.5, 0.15)
K.sound("buy", "bundle:/sfx/buy.wav", 0.8)
K.sound("bossdie", "bundle:/sfx/bossdie.wav", 1.0)
K.sound("lose", "bundle:/sfx/lose.wav", 0.9)

-- ---------------------------------------------------------------- input (twin stick)
I.bind("mleft", {pad = "left", key = "a", axis = "lx-", touch = "stick:left"})
I.bind("mright", {pad = "right", key = "d", axis = "lx+", touch = "stick:right"})
I.bind("mup", {pad = "up", key = "w", axis = "ly-", touch = "stick:up"})
I.bind("mdown", {pad = "down", key = "s", axis = "ly+", touch = "stick:down"})
I.bind("aleft", {key = "left", axis = "rx-"})
I.bind("aright", {key = "right", axis = "rx+"})
I.bind("aup", {key = "up", axis = "ry-"})
I.bind("adown", {key = "down", axis = "ry+"})
I.bind("fire", {pad = {"zr", "r"}, key = "j"})
I.bind("dash", {pad = {"b", "zl"}, key = {"space", "l"}, touch = "button:dash"})
I.bind("bomb", {pad = "y", key = {"e", "k"}, touch = "button:bomb"})
I.bind("use", {pad = {"a", "x"}, key = {"f", "enter"}, touch = "button:use"})
I.touchControls{stick = true, buttons = {{id = "dash", icon = "double_arrow", action = "dash"},
                                         {id = "bomb", icon = "brightness_7", action = "bomb"},
                                         {id = "use", icon = "pan_tool", action = "use"}}}

-- ---------------------------------------------------------------- meta progress
local function metaLevel(id) return save:get("meta_" .. id, 0) end

-- ---------------------------------------------------------------- particles
local fx = game.emitter{max = 420, life = {0.25, 0.7}, speed = {40, 220}, size = {4, 0}, damping = 3,
                        colors = {"#FFFFFF", "#FF4D8D", "#FF4D8D00"}, shape = "square"}
local smoke = game.emitter{max = 120, life = {0.4, 0.9}, speed = {10, 60}, size = {7, 14}, damping = 2,
                           colors = {"#FFFFFF40", "#80809000"}, shape = "circle"}
local function burst(x, y, n, c1, c2, spd)
  fx:setColors({"#FFFFFF", c1, (c2 or c1) .. "00"})
  fx.speedMin, fx.speedMax = 40, spd or 220
  fx:emit(n, x, y)
end

-- ---------------------------------------------------------------- run state
local run = nil
local Title, Play, Pick, Summary, Sanctum, Records

local function newPlayer()
  local p = {x = AX + AW / 2, y = AY + AH / 2, vx = 0, vy = 0, r = 8, hp = 3 + metaLevel("vitality"), inv = 0, dashT = 0,
             dashCd = 0, fireT = 0, ax = 1, ay = 0, shotN = 0, bombs = 1 + metaLevel("arsenal"), revive = 0, kills = 0,
             flash = 0, droneA = 0}
  p.maxHp = p.hp
  p.s = {dmg = 1 + 0.1 * metaLevel("power"), rate = 5.5, bspeed = 340, range = 0.85, shots = 1, spread = 0, bounce = 0,
         pierce = 0, homing = 0, crit = 0.05, size = 1, speed = 150 * (1 + 0.06 * metaLevel("agility")), drones = 0,
         shrapnel = 0, magnet = 46, shardK = 1 + 0.2 * metaLevel("fortune"), chain = 0, slow = 0,
         dashCd = 0.75 - 0.08 * metaLevel("agility"), dashHit = 0, vamp = 0, over = 0}
  return p
end

-- floor layout: a random walk on a 6 x 6 grid
local function genFloor(f)
  local rooms, list = {}, {}
  local function key(x, y) return y * 10 + x end
  local function add(x, y, kind)
    local r = {x = x, y = y, kind = kind or "combat", cleared = false, seen = false, layout = random(#D.ROOMS)}
    rooms[key(x, y)] = r
    list[#list + 1] = r
    return r
  end
  local start = add(2, 2, "start")
  start.cleared, start.layout = true, 1
  local target = 7 + f * 2
  local guard = 0
  while #list < target and guard < 2000 do
    guard = guard + 1
    local base = list[random(#list)]
    local d = random(4)
    local nx, ny = base.x + ({1, -1, 0, 0})[d], base.y + ({0, 0, 1, -1})[d]
    if nx >= 0 and ny >= 0 and nx < 6 and ny < 6 and not rooms[key(nx, ny)] then
      local nb = 0
      for k = 1, 4 do if rooms[key(nx + ({1, -1, 0, 0})[k], ny + ({0, 0, 1, -1})[k])] then nb = nb + 1 end end
      if nb == 1 or random() < 0.25 then add(nx, ny) end
    end
  end
  -- distances from the start
  local dist = {[start] = 0}
  local q = {start}
  local qi = 1
  while qi <= #q do
    local r = q[qi]
    qi = qi + 1
    for k = 1, 4 do
      local n = rooms[key(r.x + ({1, -1, 0, 0})[k], r.y + ({0, 0, 1, -1})[k])]
      if n and not dist[n] then dist[n] = dist[r] + 1; q[#q + 1] = n end
    end
  end
  local ends = {}
  for _, r in ipairs(list) do
    local nb = 0
    for k = 1, 4 do if rooms[key(r.x + ({1, -1, 0, 0})[k], r.y + ({0, 0, 1, -1})[k])] then nb = nb + 1 end end
    r.dist = dist[r] or 0
    if r ~= start and nb == 1 then ends[#ends + 1] = r end
  end
  table.sort(ends, function(a, b) return a.dist > b.dist end)
  local boss = ends[1]
  if not boss then
    table.sort(list, function(a, b) return (a.dist or 0) > (b.dist or 0) end)
    boss = list[1]
  end
  boss.kind = "boss"
  if ends[2] then ends[2].kind = "treasure" end
  if ends[3] then ends[3].kind = "shop" end
  for _, r in ipairs(list) do
    if r.kind == "combat" and r.dist >= 2 and random() < 0.2 + f * 0.08 then r.elite = true end
  end
  start.seen = true
  return {rooms = rooms, list = list, start = start, boss = boss}
end

local function roomAt(x, y) return run.floorMap.rooms[y * 10 + x] end

local function newRun()
  run = {floor = 1, score = 0, kills = 0, time = 0, shardsGot = 0, relics = {}, roomsCleared = 0, floorsCleared = 0}
  run.p = newPlayer()
  run.shards = 0
  if metaLevel("relic") > 0 then
    local r = D.RELICS[random(#D.RELICS)]
    r.apply(run.p)
    run.relics[#run.relics + 1] = r.id
  end
  run.floorMap = genFloor(1)
  run.room = run.floorMap.start
end

-- ---------------------------------------------------------------- pools
local PB, EB, EN, SH = {n = 0}, {n = 0}, {n = 0}, {n = 0}   -- player bullets, enemy bullets, enemies, shards
local function take(pool)
  pool.n = pool.n + 1
  local o = pool[pool.n]
  if not o then o = {}; pool[pool.n] = o end
  return o
end
local function drop(pool, i)
  pool[i], pool[pool.n] = pool[pool.n], pool[i]
  pool.n = pool.n - 1
end

-- ---------------------------------------------------------------- room geometry
local blocks = {}
local function buildBlocks(room)
  for i = #blocks, 1, -1 do blocks[i] = nil end
  if room.kind == "boss" or room.kind == "treasure" or room.kind == "shop" or room.kind == "start" then return end
  local lay = D.ROOMS[room.layout]
  for cy = 1, 7 do
    local row = lay[cy]
    for cx = 1, 13 do
      if row:sub(cx, cx) == "#" then
        blocks[#blocks + 1] = {x = AX + (cx - 1) * CW + 3, y = AY + (cy - 1) * CH + 3, w = CW - 6, h = CH - 6}
      end
    end
  end
end
local function hitBlock(x, y, r)
  for i = 1, #blocks do
    local b = blocks[i]
    local nx = max(b.x, min(x, b.x + b.w))
    local ny = max(b.y, min(y, b.y + b.h))
    local dx, dy = x - nx, y - ny
    if dx * dx + dy * dy < r * r then return b, dx, dy end
  end
  return nil
end
-- push a circle out of the walls and blocks
local function collideWorld(o, r, doorsOpen)
  local room = run.room
  local x0, x1, y0, y1 = AX + r, AX + AW - r, AY + r, AY + AH - r
  local cx, cy = AX + AW / 2, AY + AH / 2
  local inDoorX = abs(o.x - cx) < 26
  local inDoorY = abs(o.y - cy) < 26
  if not (doorsOpen and inDoorY and ((o.x < x0 and roomAt(room.x - 1, room.y)) or (o.x > x1 and roomAt(room.x + 1, room.y)))) then
    o.x = max(x0, min(x1, o.x))
  end
  if not (doorsOpen and inDoorX and ((o.y < y0 and roomAt(room.x, room.y - 1)) or (o.y > y1 and roomAt(room.x, room.y + 1)))) then
    o.y = max(y0, min(y1, o.y))
  end
  for _ = 1, 2 do
    local b, dx, dy = hitBlock(o.x, o.y, r)
    if not b then break end
    local d = sqrt(dx * dx + dy * dy)
    if d < 0.001 then
      o.x = o.x < b.x + b.w / 2 and b.x - r or b.x + b.w + r
    else
      o.x, o.y = o.x + dx / d * (r - d), o.y + dy / d * (r - d)
    end
  end
end

-- ---------------------------------------------------------------- enemies
local function scaleHp() return K.pick(0.8, 1, 1.3) * (1 + (run.floor - 1) * 0.45) end
local function spawnEnemy(kind, x, y, elite)
  local def = D.ENEMIES[kind]
  local e = take(EN)
  for k in pairs(e) do e[k] = nil end
  e.kind, e.def, e.x, e.y, e.vx, e.vy = kind, def, x, y, 0, 0
  e.hp = def.hp * scaleHp() * (elite and 2.2 or 1)
  e.maxHp = e.hp
  e.r = def.r * (elite and 1.3 or 1)
  e.elite = elite
  e.t, e.cd, e.warp, e.flash, e.slowT = 0, 0.8 + random() * 1.2, 0.6, 0, 0
  e.ang = random() * pi * 2
  e.phase = random() * 6
  return e
end
local function spawnBoss(kind)
  local e = take(EN)
  for k in pairs(e) do e[k] = nil end
  local hp = ({90, 150, 230})[run.floor] * K.pick(0.8, 1, 1.25)
  e.kind, e.boss, e.x, e.y, e.vx, e.vy = kind, true, AX + AW / 2, AY + AH * 0.32, 0, 0
  e.def = {col = ({warden = "#2EE6D6", maw = "#FF4DCB", heart = "#FFB547"})[kind], dmg = 1, shards = 25, score = 1000, speed = 50}
  e.hp, e.maxHp, e.r = hp, hp, kind == "heart" and 30 or 26
  e.t, e.cd, e.warp, e.flash, e.slowT, e.ang, e.phase, e.state = 0, 1.5, 1.0, 0, 0, 0, 0, "idle"
  run.bossRef = e
  return e
end
local function enemyShot(x, y, a, spd, r, col)
  if EB.n > 220 then return end
  local b = take(EB)
  b.x, b.y, b.vx, b.vy, b.r, b.life, b.col = x, y, cos(a) * spd, sin(a) * spd, r or 4, 6, col or "#FF4D6D"
end

local function spawnWave(room)
  local pool = D.FLOOR_POOL[run.floor]
  local n = 3 + run.floor + random(0, 2) + K.pick(-1, 0, 1)
  local p = run.p
  for _ = 1, n do
    local x, y
    for _ = 1, 30 do
      x, y = AX + 30 + random() * (AW - 60), AY + 30 + random() * (AH - 60)
      local dx, dy = x - p.x, y - p.y
      if dx * dx + dy * dy > 140 * 140 and not hitBlock(x, y, 16) then break end
    end
    spawnEnemy(pool[random(#pool)], x, y, room.elite and random() < 0.35)
  end
  K.sfx("warp")
end

-- ---------------------------------------------------------------- damage
local function shakeIt(a, s) run.shake = max(run.shake or 0, a * K.shakeScale()); run.shakeT = s or 0.2 end
local function hurtPlayer(src)
  local p = run.p
  if p.inv > 0 or p.dashT > 0 or run.dead then return end
  p.hp = p.hp - 1
  p.inv = 1.1
  p.flash = 0.25
  K.sfx("hurt")
  K.rumble(0.8, 160)
  shakeIt(7, 0.3)
  game.flash("#FF2040", 0.25, 0.35)
  burst(p.x, p.y, 20, "#FF4D6D", nil, 260)
  if p.hp <= 0 then
    if p.revive > 0 then
      p.revive = p.revive - 1
      p.hp = 2
      p.inv = 2.5
      game.toast(TR("revived"))
      K.sfx("relic")
      for i = EB.n, 1, -1 do drop(EB, i) end
    else
      run.dead = true
      run.deadT = 0
      K.sfx("lose")
      K.music(nil)
    end
  end
end

local killEnemy
local function damageEnemy(e, dmg, crit)
  if e.warp > 0 or e.dead then return end
  e.hp = e.hp - dmg
  e.flash = 0.08
  if run.p.s.slow > 0 then e.slowT = 1.2 end
  if e.hp <= 0 then killEnemy(e) else K.sfx("hit", crit and 1 or 0.7) end
end

local function dropShards(x, y, n)
  for _ = 1, n do
    if SH.n < 120 then
      local s = take(SH)
      local a = random() * pi * 2
      local v = 40 + random() * 90
      s.x, s.y, s.vx, s.vy, s.t, s.v = x, y, cos(a) * v, sin(a) * v, 0, 1
    end
  end
end

killEnemy = function(e)
  e.dead = true
  local p = run.p
  run.kills = run.kills + 1
  run.score = run.score + floor((e.def.score or 10) * (e.elite and 2 or 1) * (1 + (run.floor - 1) * 0.5))
  burst(e.x, e.y, e.boss and 80 or (e.elite and 30 or 18), e.def.col, nil, e.boss and 360 or 240)
  smoke:emit(e.boss and 20 or 5, e.x, e.y)
  K.sfx(e.boss and "bossdie" or "kill")
  shakeIt(e.boss and 12 or (e.elite and 4 or 2.2), e.boss and 0.8 or 0.12)
  if e.boss then K.rumble(1, 400); game.flash("#FFFFFF", 0.4, 0.6) end
  dropShards(e.x, e.y, floor((e.def.shards or 1) * (e.elite and 2 or 1)))
  if e.kind == "splitter" then
    for k = -1, 1, 2 do
      local m = spawnEnemy("mini", e.x + k * 10, e.y, false)
      m.warp = 0
    end
  end
  if e.kind == "bomber" then
    for k = 0, 9 do enemyShot(e.x, e.y, k / 10 * pi * 2, 150, 4, "#FFE14D") end
    K.sfx("boom")
  end
  if p.s.shrapnel > 0 then
    for k = 1, p.s.shrapnel do
      local b = take(PB)
      local a = random() * pi * 2
      b.x, b.y, b.vx, b.vy, b.life, b.dmg, b.r, b.pierce, b.bounce, b.crit, b.last, b.home =
        e.x, e.y, cos(a) * 260, sin(a) * 260, 0.35, p.s.dmg * 0.6, 3, 0, 0, false, e, 0
    end
  end
  if p.s.vamp > 0 then
    run.vampN = (run.vampN or 0) + 1
    if run.vampN >= max(8, 28 - p.s.vamp * 6) then
      run.vampN = 0
      if p.hp < p.maxHp then p.hp = p.hp + 1; game.toast(TR("healed")) end
    end
  end
  K.tipDone("shoot")
end

local function chainFrom(e, dmg)
  local p = run.p
  local from = e
  local hitSet = {[e] = true}
  run.arcs = run.arcs or {}
  for _ = 1, p.s.chain do
    local best, bd = nil, 95 * 95
    for i = 1, EN.n do
      local o = EN[i]
      if not o.dead and not hitSet[o] and o.warp <= 0 then
        local dx, dy = o.x - from.x, o.y - from.y
        local d = dx * dx + dy * dy
        if d < bd then best, bd = o, d end
      end
    end
    if not best then break end
    hitSet[best] = true
    run.arcs[#run.arcs + 1] = {from.x, from.y, best.x, best.y, 0.15}
    damageEnemy(best, dmg * 0.45)
    from = best
  end
end

-- ---------------------------------------------------------------- the player's gun
local function fire(p, ax, ay)
  local s = p.s
  p.shotN = p.shotN + 1
  local over = s.over > 0 and p.shotN % max(2, 6 - s.over) == 0
  local base = atan(ay, ax)
  local n = s.shots
  for k = 1, n do
    local a = base + (n > 1 and ((k - 1) / (n - 1) - 0.5) * s.spread * (n - 1) or 0) + (random() - 0.5) * 0.05
    local b = take(PB)
    local crit = random() < s.crit
    local dmg = s.dmg * (crit and 2 or 1) * (over and 3 or 1)
    b.x, b.y = p.x + cos(a) * 10, p.y + sin(a) * 10
    b.vx, b.vy = cos(a) * s.bspeed, sin(a) * s.bspeed
    b.life, b.dmg, b.r, b.pierce, b.bounce, b.crit, b.last, b.home = s.range, dmg, 3.2 * s.size * (over and 1.5 or 1), s.pierce, s.bounce, crit or over, nil, s.homing
  end
  K.sfx("shoot")
end

-- nearest living enemy (auto aim for touch and the fire button)
local function nearest(x, y)
  local best, bd = nil, 1e12
  for i = 1, EN.n do
    local e = EN[i]
    if not e.dead and e.warp <= 0 then
      local dx, dy = e.x - x, e.y - y
      local d = dx * dx + dy * dy
      if d < bd then best, bd = e, d end
    end
  end
  return best
end

-- ======================================================================== TITLE
Title = {pausable = false}
function Title:enter()
  K.music("title")
  K.clearTips()
  self.t = 0
  local items = {
    {label = TR("new_run"), icon = "play_arrow", action = function() newRun(); K.go(Play, {enter = true}, "circle", 0.5) end},
    {label = TR("sanctum"), icon = "temple_buddhist", action = function() K.go(Sanctum) end},
    {label = TR("records"), icon = "military_tech", action = function() K.go(Records) end},
    {label = TR("k_settings"), icon = "tune", action = function() game.push(K.SettingsScene, {fromTitle = true}) end},
    {label = TR("k_help"), icon = "help", action = function()
      game.push(K.HelpScene, {title = TR("k_help"), rows = {
        {icon = "gamepad", text = TR("help_move")}, {icon = "my_location", text = TR("help_aim")},
        {action = "fire", text = TR("help_fire")}, {action = "dash", text = TR("help_dash")},
        {action = "bomb", text = TR("help_bomb")}, {action = "use", text = TR("help_use")},
        {icon = "auto_awesome", text = TR("help_relics")}, {icon = "temple_buddhist", text = TR("help_meta")},
      }})
    end},
    {label = TR("k_quit"), icon = "logout", action = function() K.stopAudio(); sys.exit() end},
  }
  self.menu = K.menu{items = items, width = 210, itemHeight = 28, size = 12, accent = "#2EE6D6"}
end
function Title:update(dt)
  self.t = self.t + dt
  self.menu:update()
  if random() < 0.5 then
    local a = random() * pi * 2
    fx:setColors({"#FFFFFF", random() < 0.5 and "#2EE6D6" or "#FF4DCB", "#2EE6D600"})
    fx.speedMin, fx.speedMax = 20, 90
    fx:emit(1, game.width * 0.7 + cos(a) * 30, game.height * 0.48 + sin(a) * 30)
  end
  fx:update(dt)
end
local function vortex(cx, cy, t, col1, col2, R)
  for i = 1, 6 do
    local r = R * (1 - (((t * 0.25 + i / 6) % 1)))
    G.color((i % 2 == 0 and col1 or col2) .. string.format("%02X", floor(40 + 160 * (1 - r / R))))
    G.circleLine(cx, cy, r, 2)
  end
  for i = 0, 11 do
    local a = i / 12 * pi * 2 + t * 0.6
    G.color(col1 .. "40")
    G.line(cx + cos(a) * R * 0.2, cy + sin(a) * R * 0.2, cx + cos(a + 0.9) * R, cy + sin(a + 0.9) * R, 1.5)
  end
  G.circle(cx, cy, R * 0.16, "#000000")
  G.color("#FFFFFF")
  G.circleLine(cx, cy, R * 0.16, 1.5)
end
function Title:draw()
  K.accent = "#2EE6D6"
  G.gradient(0, 0, game.width, game.height, "#05060F", "#120A2A")
  vortex(game.width * 0.7, game.height * 0.48, game.realTime, "#2EE6D6", "#FF4DCB", 150)
  fx:draw()
  local a = min(1, self.t / 0.6)
  G.alpha(a)
  U.text(TR("title"), 30, 30, 40, "#FFFFFF", "left", nil, "bold")
  U.text(TR("tagline"), 32, 76, 12, "#2EE6D6", "left", nil, "semibold", false)
  G.unalpha()
  self.menu:draw(30 + 105, 112)
  local best = save:get("best", 0)
  U.text(TR("best_score", best, save:get("essence", 0)), 30, game.height - 26, 11, "#FFFFFFA0", "left", nil, "semibold", false)
end

-- ======================================================================== PLAY
Play = {controls = true}

function Play:enterRoom(room, fromDir)
  run.room = room
  room.seen = true
  for k = 1, 4 do
    local n = roomAt(room.x + ({1, -1, 0, 0})[k], room.y + ({0, 0, 1, -1})[k])
    if n then n.known = true end
  end
  buildBlocks(room)
  EB.n, PB.n = 0, 0
  for i = SH.n, 1, -1 do drop(SH, i) end
  EN.n = 0
  run.bossRef = nil
  local p = run.p
  local cx, cy = AX + AW / 2, AY + AH / 2
  if fromDir == "left" then p.x, p.y = AX + AW - 24, cy
  elseif fromDir == "right" then p.x, p.y = AX + 24, cy
  elseif fromDir == "up" then p.x, p.y = cx, AY + AH - 24
  elseif fromDir == "down" then p.x, p.y = cx, AY + 24
  else p.x, p.y = cx, cy + 40 end
  self.slide = fromDir
  self.slideT = 0.3
  self.items = {}
  self.portal = nil
  if room.kind == "start" and run.floor == 1 and not room.warm then
    -- a warm-up: three slow wisps to practise aiming before the first door opens
    room.warm, room.cleared = true, false
    for k = 1, 3 do
      local e = spawnEnemy("wisp", AX + AW * (0.3 + k * 0.15), AY + 50 + (k % 2) * 30, false)
      e.hp, e.warp = 1.5, 1.2 + k * 0.2
      e.def = {hp = 2, speed = 55, r = 9, col = "#FF4D8D", dmg = 1, shards = 1, score = 10}
    end
  end
  if not room.cleared then
    if room.kind == "combat" then
      spawnWave(room)
      room.waves = (run.floor >= 2 and random() < 0.5) and 2 or 1
      K.music("delve")
    elseif room.kind == "boss" then
      spawnBoss(D.BOSSES[run.floor])
      K.music("boss")
      self.bossIntro = 1.6
      K.sfx("warp")
    elseif room.kind == "start" then
      K.music("delve")
    elseif room.kind == "treasure" then
      room.cleared = true
    elseif room.kind == "shop" then
      room.cleared = true
    end
  end
  if room.kind == "treasure" and not room.taken then
    self.items[#self.items + 1] = {x = cx, y = cy - 10, kind = "chest"}
  elseif room.kind == "shop" then
    room.stock = room.stock or {{kind = "heal", price = 12}, {kind = "relic", price = 40 + run.floor * 8}, {kind = "bomb", price = 15}}
    for i, s in ipairs(room.stock) do
      if not s.sold then self.items[#self.items + 1] = {x = cx + (i - 2) * 110, y = cy, kind = s.kind, price = s.price, stock = s} end
    end
    K.tip("shop", TR("tip_shop", K.btn("use") or TR("tap")), "storefront")
  elseif room.kind == "boss" and room.cleared then
    self.portal = {x = cx, y = cy}
  end
  if room.kind ~= "boss" and room.kind ~= "combat" then K.music("delve") end
end

function Play:enter(p)
  if not run then newRun() end
  K.clearTips()
  self.t = 0
  self.picking = false
  run.shake, run.shakeT = 0, 0
  if p and p.enter then
    self:enterRoom(run.floorMap.start)
    self.floorBanner = 2.2
    K.tip("move", TR("tip_move"), "gamepad", 6)
    K.tip("shoot", TR("tip_shoot", K.btn("fire") or "ZR"), "my_location", 7)
    K.tip("dash", TR("tip_dash", K.btn("dash") or "B"), "double_arrow", 6)
    K.tip("bomb", TR("tip_bomb", K.btn("bomb") or "Y"), "brightness_7", 6)
  end
end
function Play:leaveToMenu()
  if run and not run.dead then self:endRun(false) end
end

function Play:doorsOpen()
  for i = 1, EN.n do if not EN[i].dead then return false end end
  return run.room.cleared
end

function Play:roomCleared()
  local room = run.room
  room.cleared = true
  run.roomsCleared = run.roomsCleared + 1
  K.sfx("door")
  if room.kind == "boss" then
    self.portal = {x = AX + AW / 2, y = AY + AH / 2}
    run.floorsCleared = run.floorsCleared + 1
    run.score = run.score + 500 * run.floor
    game.push(Pick, {source = "boss"})
  elseif room.elite or run.roomsCleared % 4 == 0 then
    -- an elite room or every fourth cleared room drops a relic chest
    self.items[#self.items + 1] = {x = AX + AW / 2, y = AY + AH / 2, kind = "chest"}
  elseif random() < 0.25 then
    self.items[#self.items + 1] = {x = AX + AW / 2, y = AY + AH / 2, kind = "heart"}
  end
end

function Play:update(dt)
  self.t = self.t + dt
  local p = run.p
  run.time = run.time + dt
  if self.slideT > 0 then self.slideT = self.slideT - dt end
  if self.floorBanner then self.floorBanner = self.floorBanner - dt; if self.floorBanner <= 0 then self.floorBanner = nil end end
  if self.bossIntro then self.bossIntro = self.bossIntro - dt; if self.bossIntro <= 0 then self.bossIntro = nil end end
  if run.shakeT > 0 then run.shakeT = run.shakeT - dt else run.shake = 0 end
  fx:update(dt)
  smoke:update(dt)
  if run.arcs then
    for i = #run.arcs, 1, -1 do
      run.arcs[i][5] = run.arcs[i][5] - dt
      if run.arcs[i][5] <= 0 then table.remove(run.arcs, i) end
    end
  end
  if run.dead then
    run.deadT = run.deadT + dt
    if run.deadT > 1.6 and not self.ended then self.ended = true; self:endRun(false) end
    return
  end
  -- movement
  local lx, ly = I.sticks()
  local mx, my = 0, 0
  if lx * lx + ly * ly > 0.04 then mx, my = lx, ly
  elseif I.touch.stick.active then mx, my = I.touch.stick.vx, I.touch.stick.vy
  else
    mx = (I.down("mright") and 1 or 0) - (I.down("mleft") and 1 or 0)
    my = (I.down("mdown") and 1 or 0) - (I.down("mup") and 1 or 0)
    if mx ~= 0 and my ~= 0 then mx, my = mx * 0.7071, my * 0.7071 end
  end
  local ml = sqrt(mx * mx + my * my)
  if ml > 1 then mx, my = mx / ml, my / ml end
  if ml > 0.2 then K.tipDone("move") end
  local s = p.s
  if p.dashT > 0 then
    p.dashT = p.dashT - dt
    if random() < 0.8 then smoke:emit(1, p.x, p.y) end
    if s.dashHit > 0 then
      for i = 1, EN.n do
        local e = EN[i]
        local dx, dy = e.x - p.x, e.y - p.y
        if not e.dead and dx * dx + dy * dy < (e.r + 12) ^ 2 and e.dashHitT ~= run.dashId then
          e.dashHitT = run.dashId
          damageEnemy(e, s.dmg * s.dashHit * 2)
        end
      end
    end
  else
    p.vx = p.vx + (mx * s.speed - p.vx) * min(1, dt * 14)
    p.vy = p.vy + (my * s.speed - p.vy) * min(1, dt * 14)
  end
  if p.dashCd > 0 then p.dashCd = p.dashCd - dt end
  if I.pressed("dash") and p.dashCd <= 0 then
    local dx, dy = mx, my
    if dx * dx + dy * dy < 0.04 then dx, dy = p.ax, p.ay end
    local l = sqrt(dx * dx + dy * dy) + 1e-6
    p.vx, p.vy = dx / l * 430, dy / l * 430
    p.dashT, p.dashCd = 0.16, s.dashCd
    run.dashId = (run.dashId or 0) + 1
    K.sfx("dash")
    K.tipDone("dash")
  end
  p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
  collideWorld(p, p.r, self:doorsOpen())
  -- room exits
  local room = run.room
  if self:doorsOpen() and self.slideT <= 0 then
    local nx, ny, dir
    if p.x < AX - 2 then nx, ny, dir = room.x - 1, room.y, "left"
    elseif p.x > AX + AW + 2 then nx, ny, dir = room.x + 1, room.y, "right"
    elseif p.y < AY - 2 then nx, ny, dir = room.x, room.y - 1, "up"
    elseif p.y > AY + AH + 2 then nx, ny, dir = room.x, room.y + 1, "down" end
    if dir then
      local n = roomAt(nx, ny)
      if n then self:enterRoom(n, dir); return end
    end
  end
  -- aiming and shooting
  local ax, ay = 0, 0
  local rx, ry = select(3, I.sticks())
  local aimed = false
  if rx * rx + ry * ry > 0.09 then ax, ay, aimed = rx, ry, true
  else
    ax = (I.down("aright") and 1 or 0) - (I.down("aleft") and 1 or 0)
    ay = (I.down("adown") and 1 or 0) - (I.down("aup") and 1 or 0)
    aimed = ax ~= 0 or ay ~= 0
  end
  local pt = I.pointer
  if not aimed and pt.down and not pt.touch and pt.y > AY - 10 then
    ax, ay, aimed = pt.x - p.x, pt.y - p.y, true
  end
  local wantFire = aimed or I.down("fire") or I.touchVisible() or I.touch.stick.active
  if not aimed then
    local e = nearest(p.x, p.y)
    if e then ax, ay = e.x - p.x, e.y - p.y else ax, ay = p.ax, p.ay end
    if not e and not I.down("fire") then wantFire = false end
  end
  local al = sqrt(ax * ax + ay * ay)
  if al > 0.001 then p.ax, p.ay = ax / al, ay / al end
  p.fireT = p.fireT - dt
  if wantFire and p.fireT <= 0 and EN.n > 0 then
    fire(p, p.ax, p.ay)
    p.fireT = 1 / s.rate
  end
  -- bomb
  if I.pressed("bomb") and p.bombs > 0 then
    p.bombs = p.bombs - 1
    for i = EB.n, 1, -1 do burst(EB[i].x, EB[i].y, 1, "#FFFFFF"); drop(EB, i) end
    for i = 1, EN.n do
      local e = EN[i]
      if not e.dead then damageEnemy(e, 8 + run.floor * 3) end
    end
    K.sfx("bomb")
    K.rumble(0.9, 250)
    shakeIt(10, 0.4)
    game.flash("#FFFFFF", 0.3, 0.7)
    self.nova = 0.5
    K.tipDone("bomb")
  end
  if self.nova then self.nova = self.nova - dt; if self.nova <= 0 then self.nova = nil end end
  if p.inv > 0 then p.inv = p.inv - dt end
  if p.flash > 0 then p.flash = p.flash - dt end
  self:updateBullets(dt)
  self:updateEnemies(dt)
  self:updateShards(dt)
  self:updateItems(dt)
  -- drones
  if s.drones > 0 then
    p.droneA = p.droneA + dt * 3.2
    for k = 1, s.drones do
      local a = p.droneA + k / s.drones * pi * 2
      local dx, dy = p.x + cos(a) * 28, p.y + sin(a) * 28
      for i = 1, EN.n do
        local e = EN[i]
        if not e.dead and e.warp <= 0 and (e.x - dx) ^ 2 + (e.y - dy) ^ 2 < (e.r + 6) ^ 2 and (e.droneT or 0) <= self.t then
          e.droneT = self.t + 0.3
          damageEnemy(e, s.dmg * 0.8)
        end
      end
    end
  end
  -- waves and clearing
  local alive = 0
  for i = EN.n, 1, -1 do
    if EN[i].dead then drop(EN, i) else alive = alive + 1 end
  end
  if not room.cleared and alive == 0 and (room.kind == "combat" or room.kind == "boss" or room.kind == "start") and self.slideT <= 0 then
    if room.waves and room.waves > 1 then
      room.waves = room.waves - 1
      spawnWave(room)
    else
      self:roomCleared()
    end
  end
  -- portal to the next floor
  if self.portal and not self.picking then
    local dx, dy = p.x - self.portal.x, p.y - self.portal.y
    if dx * dx + dy * dy < 22 * 22 then self:nextFloor() end
  end
  K.stat("enemies", alive)
  K.stat("bullets", PB.n + EB.n)
  K.stat("fx", fx.count)
end

function Play:nextFloor()
  if run.floor >= FLOORS then
    run.won = true
    self:endRun(true)
    return
  end
  run.floor = run.floor + 1
  run.floorMap = genFloor(run.floor)
  self.portal = nil
  K.go(Play, {enter = true}, "circle", 0.5)
end

function Play:updateBullets(dt)
  local p = run.p
  local s = p.s
  local i = 1
  while i <= PB.n do
    local b = PB[i]
    b.life = b.life - dt
    if b.home and b.home > 0 then
      local e = nearest(b.x, b.y)
      if e then
        local want = atan(e.y - b.y, e.x - b.x)
        local cur = atan(b.vy, b.vx)
        local d = (want - cur + pi) % (2 * pi) - pi
        cur = cur + max(-b.home * dt, min(b.home * dt, d))
        local sp = sqrt(b.vx * b.vx + b.vy * b.vy)
        b.vx, b.vy = cos(cur) * sp, sin(cur) * sp
      end
    end
    b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
    local dead = b.life <= 0
    -- walls and blocks
    if not dead then
      local hitW = b.x < AX or b.x > AX + AW or b.y < AY or b.y > AY + AH or hitBlock(b.x, b.y, b.r)
      if hitW then
        if b.bounce > 0 then
          b.bounce = b.bounce - 1
          if b.x < AX or b.x > AX + AW then b.vx = -b.vx else b.vy = -b.vy end
          local blk = hitBlock(b.x, b.y, b.r)
          if blk then
            local cx, cy = blk.x + blk.w / 2, blk.y + blk.h / 2
            if abs(b.x - cx) / blk.w > abs(b.y - cy) / blk.h then b.vx = -b.vx else b.vy = -b.vy end
          end
          b.x, b.y = b.x + b.vx * dt * 2, b.y + b.vy * dt * 2
        else
          dead = true
          burst(b.x, b.y, 3, FLOORCOL[run.floor], nil, 90)
        end
      end
    end
    -- enemies
    if not dead then
      for j = 1, EN.n do
        local e = EN[j]
        if not e.dead and e.warp <= 0 and b.last ~= e then
          local dx, dy = e.x - b.x, e.y - b.y
          local rr = e.r + b.r
          if dx * dx + dy * dy < rr * rr then
            damageEnemy(e, b.dmg, b.crit)
            burst(b.x, b.y, b.crit and 8 or 4, b.crit and "#FFE14D" or e.def.col, nil, 140)
            if s.chain > 0 then chainFrom(e, b.dmg) end
            if b.pierce > 0 then b.pierce = b.pierce - 1; b.last = e else dead = true end
            break
          end
        end
      end
    end
    if dead then drop(PB, i) else i = i + 1 end
  end
  -- enemy bullets
  i = 1
  while i <= EB.n do
    local b = EB[i]
    b.life = b.life - dt
    b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
    local dead = b.life <= 0 or b.x < AX - 6 or b.x > AX + AW + 6 or b.y < AY - 6 or b.y > AY + AH + 6 or hitBlock(b.x, b.y, b.r * 0.6)
    if not dead then
      local dx, dy = p.x - b.x, p.y - b.y
      local rr = p.r * 0.75 + b.r
      if dx * dx + dy * dy < rr * rr then
        if p.inv <= 0 and p.dashT <= 0 then hurtPlayer(b); dead = true end
      end
    end
    if dead then drop(EB, i) else i = i + 1 end
  end
end

local function steer(e, tx, ty, speed, dt, k)
  local dx, dy = tx - e.x, ty - e.y
  local d = sqrt(dx * dx + dy * dy) + 1e-6
  e.vx = e.vx + (dx / d * speed - e.vx) * min(1, dt * (k or 4))
  e.vy = e.vy + (dy / d * speed - e.vy) * min(1, dt * (k or 4))
  return d
end

function Play:bossAI(e, dt)
  local p = run.p
  local col = e.def.col
  local phase2 = e.hp < e.maxHp * 0.5
  e.cd = e.cd - dt
  if e.kind == "warden" then
    steer(e, AX + AW / 2 + cos(e.t * 0.5) * 160, AY + AH * 0.35 + sin(e.t * 0.8) * 40, 60, dt, 2)
    if e.cd <= 0 then
      e.phase = e.phase + 1
      if e.phase % 3 == 0 then
        for k = 1, (phase2 and 3 or 2) do
          local m = spawnEnemy("wisp", e.x + (k - 1.5) * 40, e.y + 30, false)
          m.warp = 0.4
        end
        e.cd = 1.8
      else
        local n = phase2 and 20 or 14
        for k = 0, n - 1 do enemyShot(e.x, e.y, k / n * pi * 2 + e.phase * 0.2, phase2 and 120 or 100, 5, col) end
        K.sfx("eshoot")
        e.cd = phase2 and 1.0 or 1.4
      end
    end
  elseif e.kind == "maw" then
    if e.state == "idle" then
      steer(e, p.x, p.y, 45, dt, 2)
      if e.cd <= 0 then e.state, e.st = "aim", 0.7; e.tx, e.ty = p.x, p.y end
    elseif e.state == "aim" then
      e.vx, e.vy = e.vx * 0.9, e.vy * 0.9
      e.st = e.st - dt
      if e.st <= 0 then
        local a = atan(e.ty - e.y, e.tx - e.x)
        e.vx, e.vy = cos(a) * (phase2 and 380 or 320), sin(a) * (phase2 and 380 or 320)
        e.state, e.st = "charge", 0.75
        K.sfx("dash")
      end
    elseif e.state == "charge" then
      e.st = e.st - dt
      if e.st <= 0 or e.x < AX + e.r + 2 or e.x > AX + AW - e.r - 2 or e.y < AY + e.r + 2 or e.y > AY + AH - e.r - 2 then
        shakeIt(6, 0.25)
        K.sfx("boom")
        for k = 0, 15 do enemyShot(e.x, e.y, k / 16 * pi * 2, 130, 5, col) end
        if phase2 then for k = 0, 7 do enemyShot(e.x, e.y, k / 8 * pi * 2 + 0.2, 80, 6, "#FFFFFF") end end
        e.vx, e.vy = 0, 0
        e.state = "idle"
        e.cd = phase2 and 0.9 or 1.4
      end
    end
  else -- heart
    e.vx, e.vy = 0, 0
    e.x, e.y = AX + AW / 2, AY + AH * 0.42
    local third = e.hp < e.maxHp * 0.3
    e.ang = e.ang + dt * (third and 2.2 or 1.4)
    if e.cd <= 0 then
      local arms = phase2 and 4 or 3
      for k = 0, arms - 1 do enemyShot(e.x, e.y, e.ang + k / arms * pi * 2, 110, 4.5, col) end
      e.cd = third and 0.09 or 0.13
      e.burst = (e.burst or 0) + 1
      if e.burst % 30 == 0 then
        local a = atan(p.y - e.y, p.x - e.x)
        for k = -2, 2 do enemyShot(e.x, e.y, a + k * 0.16, 190, 5, "#FFFFFF") end
        K.sfx("eshoot")
      end
      if phase2 and e.burst % 120 == 0 then
        local o = spawnEnemy("orbiter", e.x + random(-80, 80), e.y + 60, false)
        o.warp = 0.5
      end
    end
  end
end

function Play:updateEnemies(dt)
  local p = run.p
  for i = 1, EN.n do
    local e = EN[i]
    if not e.dead then
      e.t = e.t + dt
      if e.flash > 0 then e.flash = e.flash - dt end
      if e.warp > 0 then
        e.warp = e.warp - dt
      else
        local slow = e.slowT > 0 and (1 - min(0.6, p.s.slow)) or 1
        if e.slowT > 0 then e.slowT = e.slowT - dt end
        local k, def = e.kind, e.def
        local sp = (def.speed or 60) * slow * (e.elite and 1.1 or 1) * K.pick(0.85, 1, 1.12)
        if e.boss then
          self:bossAI(e, dt * slow)
        elseif k == "wisp" or k == "mini" then
          steer(e, p.x + sin(e.t * 3 + e.phase) * 20, p.y + cos(e.t * 3 + e.phase) * 20, sp, dt)
        elseif k == "spitter" then
          local d = steer(e, p.x, p.y, sp, dt)
          if d < 150 then e.vx, e.vy = -e.vx, -e.vy end
          e.cd = e.cd - dt
          if e.cd <= 0 then
            local a = atan(p.y - e.y, p.x - e.x)
            for s = -1, 1 do enemyShot(e.x, e.y, a + s * 0.22, 130, 4, def.col) end
            K.sfx("eshoot")
            e.cd = 1.8 + random() * 0.6
          end
        elseif k == "brute" then
          e.cd = e.cd - dt
          if e.state == "charge" then
            e.st = e.st - dt
            if e.st <= 0 then e.state = nil; e.cd = 2.6 end
          elseif e.state == "wind" then
            e.vx, e.vy = e.vx * 0.85, e.vy * 0.85
            e.st = e.st - dt
            if e.st <= 0 then
              local a = atan(p.y - e.y, p.x - e.x)
              e.vx, e.vy = cos(a) * 270, sin(a) * 270
              e.state, e.st = "charge", 0.55
            end
          else
            steer(e, p.x, p.y, sp, dt)
            if e.cd <= 0 then e.state, e.st = "wind", 0.6 end
          end
        elseif k == "splitter" then
          steer(e, p.x, p.y, sp, dt, 2)
        elseif k == "orbiter" then
          e.ang = e.ang + dt * 1.1
          steer(e, p.x + cos(e.ang) * 120, p.y + sin(e.ang) * 120, sp * 1.4, dt)
          e.cd = e.cd - dt
          if e.cd <= 0 then
            enemyShot(e.x, e.y, atan(p.y - e.y, p.x - e.x), 150, 4, def.col)
            e.cd = 1.4 + random() * 0.5
          end
        elseif k == "bomber" then
          if e.fuse then
            e.fuse = e.fuse - dt
            e.vx, e.vy = e.vx * 0.8, e.vy * 0.8
            if e.fuse <= 0 then
              local dx, dy = p.x - e.x, p.y - e.y
              if dx * dx + dy * dy < 46 * 46 then hurtPlayer(e) end
              killEnemy(e)
            end
          else
            local d = steer(e, p.x, p.y, sp, dt, 3)
            if d < 42 then e.fuse = 0.55 end
          end
        elseif k == "sentinel" then
          e.ang = e.ang + dt * 1.6
          e.cd = e.cd - dt
          if e.cd <= 0 then
            for s = 0, 3 do enemyShot(e.x, e.y, e.ang + s * pi / 2, 95, 4, def.col) end
            e.cd = (e.t % 4 < 2.6) and 0.22 or 0.6
          end
        elseif k == "phantom" then
          e.cd = e.cd - dt
          steer(e, p.x + cos(e.t) * 90, p.y + sin(e.t) * 70, sp, dt, 2)
          if e.cd <= 0 then
            local a = random() * pi * 2
            e.x, e.y = max(AX + 20, min(AX + AW - 20, p.x + cos(a) * 130)), max(AY + 20, min(AY + AH - 20, p.y + sin(a) * 110))
            e.warp = 0.35
            local aa = atan(p.y - e.y, p.x - e.x)
            for s = -2, 2 do enemyShot(e.x, e.y, aa + s * 0.18, 120, 4, def.col) end
            e.cd = 2.6
            K.sfx("warp")
          end
        end
        e.x, e.y = e.x + e.vx * dt, e.y + e.vy * dt
        if not e.boss or e.kind ~= "heart" then collideWorld(e, e.r, false) end
        -- contact damage
        local dx, dy = p.x - e.x, p.y - e.y
        local rr = p.r * 0.8 + e.r * 0.85
        if dx * dx + dy * dy < rr * rr then hurtPlayer(e) end
      end
    end
  end
  -- enemies keep a little apart
  for i = 1, EN.n do
    local a = EN[i]
    for j = i + 1, EN.n do
      local b = EN[j]
      local dx, dy = b.x - a.x, b.y - a.y
      local rr = (a.r + b.r) * 0.9
      local d2 = dx * dx + dy * dy
      if d2 < rr * rr and d2 > 0.01 then
        local d = sqrt(d2)
        local push = (rr - d) * 0.5
        if not a.boss then a.x, a.y = a.x - dx / d * push, a.y - dy / d * push end
        if not b.boss then b.x, b.y = b.x + dx / d * push, b.y + dy / d * push end
      end
    end
  end
end

function Play:updateShards(dt)
  local p = run.p
  local i = 1
  while i <= SH.n do
    local s = SH[i]
    s.t = s.t + dt
    local dx, dy = p.x - s.x, p.y - s.y
    local d = sqrt(dx * dx + dy * dy) + 1e-6
    if s.t > 0.35 and (d < p.s.magnet or run.room.cleared) then
      local k = min(1, dt * 10)
      s.vx = s.vx + (dx / d * 420 - s.vx) * k
      s.vy = s.vy + (dy / d * 420 - s.vy) * k
    else
      s.vx, s.vy = s.vx * (1 - min(1, dt * 4)), s.vy * (1 - min(1, dt * 4))
    end
    s.x, s.y = s.x + s.vx * dt, s.y + s.vy * dt
    if d < 12 and s.t > 0.2 then
      local v = p.s.shardK
      run.shards = run.shards + v
      run.shardsGot = run.shardsGot + v
      run.score = run.score + 2
      K.sfx("shard")
      drop(SH, i)
    else
      i = i + 1
    end
  end
end

function Play:updateItems(dt)
  local p = run.p
  for i = #self.items, 1, -1 do
    local it = self.items[i]
    local dx, dy = p.x - it.x, p.y - it.y
    local near = dx * dx + dy * dy < 30 * 30
    it.near = near
    if near then
      if it.kind == "heart" then
        if p.hp < p.maxHp then p.hp = p.hp + 1; K.sfx("relic"); table.remove(self.items, i) end
      elseif it.kind == "chest" then
        if I.pressed("use") or I.pressed("confirm") or K.device == "touch" then
          table.remove(self.items, i)
          if run.room.kind == "treasure" then run.room.taken = true end
          K.sfx("relic")
          game.push(Pick, {source = "chest"})
          return
        end
      elseif it.price then
        if I.pressed("use") then
          if run.shards >= it.price then
            run.shards = run.shards - it.price
            it.stock.sold = true
            table.remove(self.items, i)
            K.sfx("buy")
            K.tipDone("shop")
            if it.kind == "heal" then p.hp = min(p.maxHp, p.hp + 2)
            elseif it.kind == "bomb" then p.bombs = p.bombs + 1
            else game.push(Pick, {source = "shop"}); return end
          else
            K.sfx("ui_back")
            game.toast(TR("no_shards"))
          end
        end
      end
    end
  end
end

function Play:endRun(won)
  local essence = floor(run.score / 45) + run.floorsCleared * 12 + (won and 40 or 0)
  save:set("essence", save:get("essence", 0) + essence)
  save:inc("runs", 1)
  if won then save:inc("wins", 1) end
  local newBest = save:best("best", run.score)
  save:best("depth", run.floor)
  save:set("kills", save:get("kills", 0) + run.kills)
  K.go(Summary, {won = won, essence = essence, best = newBest, score = run.score, floor = run.floor, kills = run.kills,
                 time = run.time, relics = #run.relics}, "fade", 0.6)
end

-- ---------------------------------------------------------------- drawing
local function drawEnemy(e, t)
  local col = e.flash > 0 and "#FFFFFF" or e.def.col
  local x, y, r = e.x, e.y, e.r
  if e.warp > 0 then
    G.color(e.def.col .. "90")
    G.circleLine(x, y, r * (1 + e.warp * 2), 1.5)
    G.circle(x, y, r * 0.4 * (1 - e.warp), e.def.col .. "80")
    return
  end
  G.circle(x, y, r * 1.7, col .. "22")
  local k = e.kind
  if e.boss then
    G.circle(x, y, r * 2.2, col .. "18")
    local spikes = {}
    for i = 0, 15 do
      local a = i / 16 * pi * 2 + t * (k == "heart" and 1.2 or 0.4)
      local rr = (i % 2 == 0) and r * 1.25 or r * 0.95
      spikes[#spikes + 1] = x + cos(a) * rr
      spikes[#spikes + 1] = y + sin(a) * rr
    end
    G.color(col)
    G.lines(spikes, 3, true)
    G.circle(x, y, r * 0.8, "#0A0A18")
    G.circle(x, y, r * (0.45 + 0.08 * sin(t * 6)), col)
    G.circle(x - r * 0.15, y - r * 0.15, r * 0.15, "#FFFFFFC0")
    if e.state == "aim" then
      G.color("#FF4DCB80")
      G.line(x, y, e.tx, e.ty, 2)
    end
    return
  end
  if k == "wisp" or k == "mini" then
    G.polyT({r, 0, -r * 0.8, -r * 0.8, -r * 0.4, 0, -r * 0.8, r * 0.8}, x, y, atan(e.vy, e.vx), 1, 1, col)
  elseif k == "spitter" then
    G.circle(x, y, r, col)
    G.circle(x, y, r * 0.5, "#1A1020")
  elseif k == "brute" then
    G.rect(x - r, y - r, r * 2, r * 2, r * 0.4, e.state == "wind" and "#FFFFFF" or col)
    G.rect(x - r * 0.5, y - r * 0.3, r, r * 0.4, 2, "#1A1020")
  elseif k == "splitter" then
    G.polyT({0, -r, r, 0, 0, r, -r, 0}, x, y, t * 2, 1, 1, col)
  elseif k == "orbiter" then
    G.circleLine(x, y, r, 2.5)
    G.circle(x, y, r * 0.45, col)
  elseif k == "bomber" then
    G.circle(x, y, r, e.fuse and (floor(t * 20) % 2 == 0 and "#FFFFFF" or "#FF3030") or col)
    G.circle(x, y - r, r * 0.3, "#FF8A1A")
  elseif k == "sentinel" then
    G.polyT({r, 0, 0, r, -r, 0, 0, -r}, x, y, e.ang, 1, 1, col)
    G.circle(x, y, r * 0.4, "#1A1020")
  elseif k == "phantom" then
    G.alpha(0.55 + 0.45 * sin(t * 5))
    G.polyT({0, -r, r * 0.8, r, -r * 0.8, r}, x, y, 0, 1, 1, col)
    G.unalpha()
  end
  if e.elite then
    G.color("#FFE14D")
    G.circleLine(x, y, r + 4, 1.5)
  end
end

local function drawItem(it, t)
  local x, y = it.x, it.y + sin(t * 3) * 3
  if it.kind == "chest" then
    G.circle(x, y, 20, "#FFE14D20")
    G.rect(x - 13, y - 9, 26, 18, 4, "#7A4ED9")
    G.rect(x - 13, y - 9, 26, 6, 3, "#A47CFF")
    G.circle(x, y, 3, "#FFE14D")
  elseif it.kind == "heart" then
    G.icon("favorite", x, y, 22, "#FF4D6D")
  else
    local icon = it.kind == "heal" and "favorite" or (it.kind == "bomb" and "brightness_7" or "auto_awesome")
    G.rect(x - 22, y - 22, 44, 44, 10, "#FFFFFF10")
    G.icon(icon, x, y - 4, 22, it.kind == "heal" and "#FF4D6D" or "#FFE14D")
    U.text("◆ " .. it.price, x - 30, y + 14, 11, run.shards >= it.price and "#7CFFB2" or "#FF6B6B", "center", 60, "bold", false)
  end
  if it.near and (it.kind == "chest" or it.price) and K.btn("use") then
    K.prompts({{"use", it.price and TR("buy") or TR("open")}}, x, y - 40, 10)
  end
end

function Play:drawRoom(ox, oy)
  local fl = run.floor
  local col = FLOORCOL[fl]
  local bg = FLOORBG[fl]
  G.push(ox, oy)
  G.gradient(AX, AY, AW, AH, bg[1], bg[2])
  G.color(col .. "14")
  for x = AX, AX + AW, CW do G.line(x, AY, x, AY + AH, 1) end
  for y = AY, AY + AH, CH do G.line(AX, y, AX + AW, y, 1) end
  -- walls with doors
  local room = run.room
  local open = self:doorsOpen()
  local cx, cy = AX + AW / 2, AY + AH / 2
  G.color(col)
  local function wall(x1, y1, x2, y2) G.line(x1, y1, x2, y2, 3) end
  local gaps = {left = roomAt(room.x - 1, room.y), right = roomAt(room.x + 1, room.y), up = roomAt(room.x, room.y - 1),
                down = roomAt(room.x, room.y + 1)}
  local g = 30
  if gaps.up then wall(AX, AY, cx - g, AY); wall(cx + g, AY, AX + AW, AY) else wall(AX, AY, AX + AW, AY) end
  if gaps.down then wall(AX, AY + AH, cx - g, AY + AH); wall(cx + g, AY + AH, AX + AW, AY + AH) else wall(AX, AY + AH, AX + AW, AY + AH) end
  if gaps.left then wall(AX, AY, AX, cy - g); wall(AX, cy + g, AX, AY + AH) else wall(AX, AY, AX, AY + AH) end
  if gaps.right then wall(AX + AW, AY, AX + AW, cy - g); wall(AX + AW, cy + g, AX + AW, AY + AH) else wall(AX + AW, AY, AX + AW, AY + AH) end
  local barCol = open and (col .. "50") or "#FF3B5C"
  G.color(barCol)
  if gaps.up then G.line(cx - g, AY, cx + g, AY, open and 1 or 4) end
  if gaps.down then G.line(cx - g, AY + AH, cx + g, AY + AH, open and 1 or 4) end
  if gaps.left then G.line(AX, cy - g, AX, cy + g, open and 1 or 4) end
  if gaps.right then G.line(AX + AW, cy - g, AX + AW, cy + g, open and 1 or 4) end
  for _, b in ipairs(blocks) do
    G.rect(b.x, b.y, b.w, b.h, 6, "#00000080")
    G.rect(b.x + 2, b.y + 2, b.w - 4, b.h - 4, 5, bg[2])
    G.color(col .. "A0")
    G.rectLine(b.x + 2, b.y + 2, b.w - 4, b.h - 4, 5, 1.5)
  end
  G.pop()
end

function Play:draw()
  K.accent = FLOORCOL[run.floor]
  local t = game.realTime
  G.rect(0, 0, game.width, game.height, 0, "#03040A")
  local ox, oy = 0, 0
  if self.slideT > 0 then
    local k = (self.slideT / 0.3) ^ 2
    local d = self.slide
    if d == "left" then ox = -k * 80 elseif d == "right" then ox = k * 80 elseif d == "up" then oy = -k * 60 elseif d == "down" then oy = k * 60 end
  end
  if run.shake and run.shake > 0 then
    ox, oy = ox + (random() - 0.5) * run.shake, oy + (random() - 0.5) * run.shake
  end
  self:drawRoom(ox, oy)
  G.push(ox, oy)
  local col = FLOORCOL[run.floor]
  -- portal
  if self.portal then
    vortex(self.portal.x, self.portal.y, t * 2, col, "#FFFFFF", 26)
    if not self.portalTip then self.portalTip = true; K.tip("portal", TR("tip_portal"), "cyclone") end
  end
  for _, it in ipairs(self.items) do drawItem(it, t) end
  -- shards
  for i = 1, SH.n do
    local s = SH[i]
    G.polyT({0, -4, 3, 0, 0, 4, -3, 0}, s.x, s.y, 0, 1, 1, "#7CFFB2")
  end
  for i = 1, EN.n do drawEnemy(EN[i], t) end
  -- player
  local p = run.p
  if not run.dead and not (p.inv > 0 and floor(p.inv * 16) % 2 == 0) then
    local a = atan(p.ay, p.ax)
    G.circle(p.x, p.y, 16, col .. "26")
    G.polyT({13, 0, -8, -9, -4, 0, -8, 9}, p.x, p.y, a, 1, 1, p.flash > 0 and "#FF4D6D" or "#F2FBFF")
    G.color(col)
    G.linesT({13, 0, -8, -9, -4, 0, -8, 9}, p.x, p.y, a, 1, 1, 1.6, true)
    if p.s.drones > 0 then
      for k = 1, p.s.drones do
        local da = p.droneA + k / p.s.drones * pi * 2
        G.circle(p.x + cos(da) * 28, p.y + sin(da) * 28, 7, col .. "40")
        G.circle(p.x + cos(da) * 28, p.y + sin(da) * 28, 4, "#FFFFFF")
      end
    end
  end
  -- bullets
  for i = 1, PB.n do
    local b = PB[i]
    local c = b.crit and "#FFE14D" or col
    G.circle(b.x, b.y, b.r * 2, c .. "40")
    G.circle(b.x, b.y, b.r, "#FFFFFF")
  end
  for i = 1, EB.n do
    local b = EB[i]
    G.circle(b.x, b.y, b.r * 1.9, b.col .. "50")
    G.circle(b.x, b.y, b.r, b.col)
    G.circle(b.x, b.y, b.r * 0.45, "#FFFFFF")
  end
  if run.arcs then
    G.color("#9FE8FF")
    for _, a in ipairs(run.arcs) do
      local mx, my = (a[1] + a[3]) / 2 + (random() - 0.5) * 14, (a[2] + a[4]) / 2 + (random() - 0.5) * 14
      G.line(a[1], a[2], mx, my, 2)
      G.line(mx, my, a[3], a[4], 2)
    end
  end
  smoke:draw()
  fx:draw()
  if self.nova then
    G.color(string.format("#FFFFFF%02X", floor(self.nova * 400)))
    G.circleLine(p.x, p.y, (0.5 - self.nova) * 900, 6)
  end
  G.pop()
  self:drawHUD()
end

function Play:drawHUD()
  local p = run.p
  local W = game.width
  U.hearts(p.hp, p.maxHp, 20, 12, 14)
  local bx = 20 + p.maxHp * 16 + 10
  for k = 1, p.bombs do G.icon("brightness_7", bx + (k - 1) * 16, 19, 14, "#FFE14D") end
  U.text("◆ " .. floor(run.shards), 20, 30, 11, "#7CFFB2", "left", nil, "bold", false)
  U.text(TR("floor_n", run.floor, FLOORS), 0, 6, 12, FLOORCOL[run.floor], "center", W, "bold")
  U.text(tostring(run.score), 0, 22, 11, "#FFFFFFC0", "center", W, "mono", false)
  -- minimap
  local ms = 9
  local mx, my = W - 6 * (ms + 2) - 12, 4
  for _, r in ipairs(run.floorMap.list) do
    if r.seen or r.known then
      local x, y = mx + r.x * (ms + 2), my + r.y * (ms + 2) * 0.62
      local c = r == run.room and "#FFFFFF" or (r.seen and "#FFFFFF50" or "#FFFFFF20")
      G.rect(x, y, ms, ms * 0.55, 2, c)
      if r.kind == "boss" then G.circle(x + ms / 2, y + ms * 0.28, 2, "#FF3B5C")
      elseif r.kind == "treasure" then G.circle(x + ms / 2, y + ms * 0.28, 2, "#FFE14D")
      elseif r.kind == "shop" then G.circle(x + ms / 2, y + ms * 0.28, 2, "#7CFFB2") end
    end
  end
  local boss = run.bossRef
  if boss and not boss.dead then
    U.text(TRd("boss_" .. boss.kind), 0, game.height - 30, 11, boss.def.col, "center", W, "bold")
    U.bar(W / 2 - 150, game.height - 14, 300, 7, boss.hp / boss.maxHp, boss.def.col)
  end
  if self.floorBanner then
    local a = min(1, self.floorBanner, (2.2 - self.floorBanner) * 3)
    G.alpha(max(0, a))
    U.text(TR("floor_n", run.floor, FLOORS), 0, game.height * 0.36, 26, "#FFFFFF", "center", W, "bold")
    U.text(TRd("floor_name" .. run.floor), 0, game.height * 0.36 + 32, 13, FLOORCOL[run.floor], "center", W, "semibold")
    G.unalpha()
  end
  if self.bossIntro and boss then
    G.alpha(min(1, self.bossIntro))
    U.text(TRd("boss_" .. boss.kind), 0, game.height * 0.62, 24, boss.def.col, "center", W, "bold")
    G.unalpha()
  end
  if run.dead then
    G.alpha(min(1, run.deadT))
    U.text(TR("you_fell"), 0, game.height * 0.42, 28, "#FF4D6D", "center", W, "bold")
    G.unalpha()
  end
end

-- ======================================================================== PICK (relic cards)
Pick = {transparent = true, pausable = false}
function Pick:enter(p)
  self.t, self.sel = 0, 2
  Play.picking = true
  local have = {}
  for _, id in ipairs(run.relics) do have[id] = (have[id] or 0) + 1 end
  local pool = {}
  for _, r in ipairs(D.RELICS) do
    local w = ({6, 3, 1.5})[r.rare]
    if (have[r.id] or 0) >= 3 or (r.id == "angel" and (have.angel or 0) >= 1) then w = 0 end
    if p and p.source == "boss" then w = w * (r.rare + 1) end
    if w > 0 then pool[#pool + 1] = {r, w} end
  end
  self.cards = {}
  for k = 1, 3 do
    local total = 0
    for _, e in ipairs(pool) do total = total + e[2] end
    local x = random() * total
    for i, e in ipairs(pool) do
      x = x - e[2]
      if x <= 0 then self.cards[k] = e[1]; table.remove(pool, i) break end
    end
  end
  K.tip("relic", TR("tip_relic"), "auto_awesome", 5)
end
function Pick:choose(i)
  local r = self.cards[i]
  if not r then return end
  r.apply(run.p)
  run.relics[#run.relics + 1] = r.id
  K.sfx("relic")
  K.rumble(0.4, 80)
  burst(run.p.x, run.p.y, 30, "#FFE14D", nil, 260)
  Play.picking = false
  K.tipDone("relic")
  game.pop()
end
function Pick:update(dt)
  self.t = self.t + dt
  if self.t < 0.35 then return end
  if I.pressed("left") or I.pressed("mleft") then self.sel = (self.sel - 2) % #self.cards + 1; K.sfx("ui_move") end
  if I.pressed("right") or I.pressed("mright") then self.sel = self.sel % #self.cards + 1; K.sfx("ui_move") end
  if I.pressed("confirm") or I.pressed("use") then self:choose(self.sel) end
  local pt = I.pointer
  if pt.released and self.rects then
    for i, r in ipairs(self.rects) do
      if pt.x >= r[1] and pt.x <= r[1] + r[3] and pt.y >= r[2] and pt.y <= r[2] + r[4] then
        if self.sel == i or K.device == "touch" then self:choose(i) else self.sel = i; K.sfx("ui_move") end
      end
    end
  end
end
function Pick:draw()
  local W, H = game.width, game.height
  local k = min(1, self.t / 0.3)
  G.rect(0, 0, W, H, 0, string.format("#000000%02X", floor(170 * k)))
  U.text(TR("choose_relic"), 0, 40 - (1 - k) * 20, 20, "#FFFFFF", "center", W, "bold")
  self.rects = {}
  local cw, ch = 168, 200
  local gap = 14
  local x0 = (W - (#self.cards * cw + (#self.cards - 1) * gap)) / 2
  for i, r in ipairs(self.cards) do
    local x, y = x0 + (i - 1) * (cw + gap), 80 + (1 - k) * 40 * i
    local sel = i == self.sel
    local rc = ({"#7CFFB2", "#5CC8FF", "#FFB547"})[r.rare]
    if sel then G.rect(x - 4, y - 4 - 6, cw + 8, ch + 8, 16, rc .. "50") end
    G.rect(x, y - (sel and 6 or 0), cw, ch, 14, "#101428F0")
    G.color(rc)
    G.rectLine(x, y - (sel and 6 or 0), cw, ch, 14, sel and 2.5 or 1.2)
    local yy = y - (sel and 6 or 0)
    G.circle(x + cw / 2, yy + 52, 30, rc .. "26")
    G.icon(r.icon, x + cw / 2, yy + 52, 34, rc)
    U.text(TRd("r_" .. r.id), x + 8, yy + 92, 14, "#FFFFFF", "center", cw - 16, "bold", false)
    G.color("#FFFFFFC0")
    local px, py = G.toScreen(x + 12, yy + 116)
    local sc = G.scale()
    gfx.wrap(TRd("r_" .. r.id .. "_d"), px, py, (cw - 24) * sc, 11 * sc, "semibold", "center")
    U.text(TRd("rare" .. r.rare), x, yy + ch - 22, 10, rc, "center", cw, "bold", false)
    self.rects[i] = {x, yy, cw, ch}
  end
  K.prompts({{"confirm", TR("take")}}, W / 2, H - 36, 11)
end

-- ======================================================================== SUMMARY
Summary = {pausable = false}
function Summary:enter(p)
  self.p, self.t = p, 0
  K.music("title")
  run = nil
  self.menu = K.menu{items = {
    {label = TR("again"), icon = "replay", action = function() newRun(); K.go(Play, {enter = true}, "circle", 0.5) end},
    {label = TR("sanctum"), icon = "temple_buddhist", action = function() K.go(Sanctum) end},
    {label = TR("k_menu"), icon = "home", action = function() K.go(Title) end},
  }, width = 220, itemHeight = 28, size = 12, accent = "#2EE6D6"}
  if p.won then K.sfx("bossdie") end
end
function Summary:update(dt) self.t = self.t + dt; if self.t > 0.6 then self.menu:update() end end
function Summary:draw()
  local W, H = game.width, game.height
  G.gradient(0, 0, W, H, "#05060F", self.p.won and "#0E2A2A" or "#2A0A18")
  vortex(W / 2, H * 0.3, game.realTime * 0.5, self.p.won and "#2EE6D6" or "#FF4D6D", "#FFFFFF", 70)
  U.text(self.p.won and TR("victory") or TR("run_over"), 0, 26, 26, "#FFFFFF", "center", W, "bold")
  local lines = {
    {TR("s_score"), tostring(self.p.score) .. (self.p.best and ("  ·  " .. TR("k_new_record")) or "")},
    {TR("s_depth"), TR("floor_n", self.p.floor, FLOORS)},
    {TR("s_kills"), tostring(self.p.kills)},
    {TR("s_time"), string.format("%d:%02d", floor(self.p.time / 60), floor(self.p.time % 60))},
    {TR("s_relics"), tostring(self.p.relics)},
    {TR("s_essence"), "+" .. self.p.essence},
  }
  local y = 140
  for i, l in ipairs(lines) do
    local k = min(1, max(0, (self.t - i * 0.12) / 0.25))
    G.alpha(k)
    U.text(l[1], W / 2 - 160, y, 12, "#FFFFFFA0", "left", nil, "semibold", false)
    U.text(l[2], W / 2 - 160, y, 12, i == #lines and "#2EE6D6" or "#FFFFFF", "right", 320, "bold", false)
    G.unalpha()
    y = y + 20
  end
  self.menu:draw(W / 2, y + 12)
end

-- ======================================================================== SANCTUM (permanent upgrades)
Sanctum = {pausable = false}
function Sanctum:enter()
  K.music("title")
  local items = {}
  for _, m in ipairs(D.META) do
    items[#items + 1] = {label = TRd("m_" .. m.id), icon = m.icon, value = function()
        local lv = metaLevel(m.id)
        if lv >= m.max then return TR("maxed") end
        return lv .. "/" .. m.max .. "  ·  ✦ " .. m.cost[lv + 1]
      end, action = function()
        local lv = metaLevel(m.id)
        if lv >= m.max then K.sfx("ui_back") return end
        local cost = m.cost[lv + 1]
        local ess = save:get("essence", 0)
        if ess < cost then game.toast(TR("no_essence")); K.sfx("ui_back") return end
        save:set("essence", ess - cost)
        save:set("meta_" .. m.id, lv + 1)
        K.sfx("buy")
        K.rumble(0.3, 60)
      end}
  end
  items[#items + 1] = {label = TR("k_back"), icon = "arrow_back", action = function() K.go(Title) end}
  self.menu = K.menu{items = items, width = 340, itemHeight = 28, size = 12, accent = "#2EE6D6", onBack = function() K.go(Title) end}
  K.tip("sanctum", TR("tip_sanctum"), "temple_buddhist")
end
function Sanctum:update() self.menu:update() end
function Sanctum:draw()
  local W, H = game.width, game.height
  G.gradient(0, 0, W, H, "#05060F", "#0E1430")
  vortex(W * 0.85, H * 0.8, game.realTime * 0.3, "#2EE6D6", "#FF4DCB", 90)
  U.text(TR("sanctum"), 0, 16, 22, "#FFFFFF", "center", W, "bold")
  U.text(TR("essence_have", save:get("essence", 0)), 0, 44, 12, "#2EE6D6", "center", W, "bold", false)
  self.menu:draw(W / 2, 70)
  local it = D.META[self.menu.selected]
  if it then U.text(TRd("m_" .. it.id .. "_d"), 0, H - 30, 11, "#FFFFFFB0", "center", W, "semibold", false) end
end

-- ======================================================================== RECORDS
Records = {pausable = false}
function Records:enter()
  self.menu = K.menu{items = {{label = TR("k_back"), icon = "arrow_back", action = function() K.go(Title) end}},
                     width = 200, itemHeight = 28, size = 12, accent = "#2EE6D6", onBack = function() K.go(Title) end}
end
function Records:update() self.menu:update() end
function Records:draw()
  local W, H = game.width, game.height
  G.gradient(0, 0, W, H, "#05060F", "#120A2A")
  U.text(TR("records"), 0, 20, 22, "#FFFFFF", "center", W, "bold")
  local rows = {{TR("r_best"), save:get("best", 0)}, {TR("r_depth"), save:get("depth", 0)}, {TR("r_runs"), save:get("runs", 0)},
                {TR("r_wins"), save:get("wins", 0)}, {TR("r_kills"), save:get("kills", 0)}, {TR("r_essence"), save:get("essence", 0)}}
  local y = 70
  for _, r in ipairs(rows) do
    G.rect(W / 2 - 170, y, 340, 26, 8, "#FFFFFF10")
    U.text(r[1], W / 2 - 158, y + 6, 12, "#FFFFFFB0", "left", nil, "semibold", false)
    U.text(tostring(r[2]), W / 2 - 160, y + 6, 12, "#FFFFFF", "right", 308, "bold", false)
    y = y + 32
  end
  self.menu:draw(W / 2, H - 50)
end

-- ======================================================================== run
return K.run{
  width = 640, height = 360, scene = Title, title = Title, background = "#03040A", accent = "#2EE6D6", dark = "#020308",
  controls = {"fire", "dash", "bomb", "use"},
  lockDifficulty = true,
  onReset = function()
    for _, k in ipairs({"best", "depth", "runs", "wins", "kills", "essence"}) do save:set(k, nil) end
    for _, m in ipairs(D.META) do save:set("meta_" .. m.id, nil) end
  end,
}
