-- Banners of Aldmoor: a turn-based tactics campaign. Lead Ser Maren's company through eight battles to take back
-- Aldmoor: terrain, ranges, counter-attacks, healing, experience and levels carried from battle to battle, an enemy
-- that thinks before it moves, and replays of every battle you have won. Built on nexvyn.game with the shared kit.
local game = require("nexvyn.game")
local K = require("kit")
local M = require("missions")
local G, I, U, A = game.gfx, game.input, game.ui, game.audio
local floor, min, max, sin, cos, abs, pi, sqrt, random = math.floor, math.min, math.max, math.sin, math.cos,
  math.abs, math.pi, math.sqrt, math.random

local TRd = function(k, ...) return TR(k, ...) end
local save = game.save.open("campaign")
local W, H = 14, 9
local BLUE, RED = "#3A6FD8", "#D8483A"
local ICON = {lord = "military_tech", knight = "shield", spear = "navigation", archer = "gps_fixed", rider = "bolt",
              mage = "auto_fix_high", cleric = "healing", brute = "fitness_center", warlord = "whatshot"}

-- ---------------------------------------------------------------- sound and music
K.track("title", "bundle:/music/title.ogg", 24)
K.track("battle", "bundle:/music/battle.ogg", 18)
K.track("enemy", "bundle:/music/enemy.ogg", 16)
K.sound("ui_move", "bundle:/sfx/ui_move.wav", 0.6)
K.sound("ui_ok", "bundle:/sfx/ui_ok.wav", 0.7)
K.sound("ui_back", "bundle:/sfx/ui_back.wav", 0.6)
K.sound("step", {"bundle:/sfx/step1.wav", "bundle:/sfx/step2.wav"}, 0.35, 0.06)
K.sound("sword", {"bundle:/sfx/sword1.wav", "bundle:/sfx/sword2.wav"}, 0.8, 0.05)
K.sound("arrow", "bundle:/sfx/arrow.wav", 0.7, 0.05)
K.sound("magic", "bundle:/sfx/magic.wav", 0.8, 0.05)
K.sound("heal", "bundle:/sfx/heal.wav", 0.8, 0.05)
K.sound("fall", "bundle:/sfx/fall.wav", 0.8, 0.1)
K.sound("levelup", "bundle:/sfx/levelup.wav", 0.9)
K.sound("horn", "bundle:/sfx/horn.wav", 0.8, 0.5)
K.sound("victory", "bundle:/sfx/victory.wav", 1.0)
K.sound("defeat", "bundle:/sfx/defeat.wav", 0.9)
K.sound("crit", "bundle:/sfx/crit.wav", 0.9, 0.1)

-- ---------------------------------------------------------------- input
I.bind("endturn", {pad = "x", key = {"e"}, touch = "button:endturn"})
I.bind("danger", {pad = "y", key = {"i"}})
I.bind("nextunit", {pad = {"r", "zr"}, key = {"tab", "n"}})
I.bind("prevunit", {pad = {"l", "zl"}, key = {"b"}})

-- ---------------------------------------------------------------- the company (saved)
local function heroState(id)
  local all = save:get("heroes", {})
  if type(all) ~= "table" then all = {} end
  return all[id]
end
local function setHeroState(id, st)
  local all = save:get("heroes", {})
  if type(all) ~= "table" then all = {} end
  all[id] = st
  save:set("heroes", all)
end
local function cleared(n) return save:get("cleared", 0) >= n end

-- ---------------------------------------------------------------- particles
local sparks = game.emitter{max = 260, life = {0.25, 0.6}, speed = {40, 200}, size = {3.5, 0}, damping = 3, gravity = 120,
                            colors = {"#FFFFFF", "#FFD36A", "#FF8A1A00"}, shape = "square"}
local glows = game.emitter{max = 120, life = {0.6, 1.2}, speed = {10, 50}, size = {4, 0}, damping = 1, gravity = -60,
                           colors = {"#FFFFFF", "#7CFF9B", "#7CFF9B00"}, shape = "circle"}

-- ======================================================================== battle model
local B = {}

local function terrainAt(x, y) return M.TERRAIN[B.map[y + 1]:sub(x + 1, x + 1)] end
local function unitAt(x, y)
  for _, u in ipairs(B.units) do if u.alive and u.x == x and u.y == y then return u end end
end
local function cls(u) return M.CLASSES[u.class] end
local function dist(ax, ay, bx, by) return abs(ax - bx) + abs(ay - by) end

local function makeUnit(class, team, x, y, level, name, hero)
  local c = M.CLASSES[class]
  local u = {class = class, team = team, x = x, y = y, px = x, py = y, alive = true, done = false, lvl = level or 1,
             xp = 0, name = name, hero = hero, flash = 0, lunge = 0, lx = 0, ly = 0, fade = 1}
  local lv = (level or 1) - 1
  u.maxHp = floor(c.hp + c.grow.hp * lv)
  u.atk = floor(c.atk + c.grow.atk * lv * 0.8)
  u.def = floor(c.def + c.grow.def * lv * 0.7)
  u.hp = u.maxHp
  u.mov, u.r0, u.r1 = c.mov, c.r0, c.r1
  return u
end

-- reachable tiles: cost so far, previous tile (for the path)
local function reach(u)
  local out = {}
  local key = function(x, y) return y * W + x end
  out[key(u.x, u.y)] = {x = u.x, y = u.y, c = 0}
  local open = {out[key(u.x, u.y)]}
  while #open > 0 do
    table.sort(open, function(a, b) return a.c > b.c end)
    local n = table.remove(open)
    for d = 1, 4 do
      local nx, ny = n.x + ({1, -1, 0, 0})[d], n.y + ({0, 0, 1, -1})[d]
      if nx >= 0 and ny >= 0 and nx < W and ny < H then
        local t = terrainAt(nx, ny)
        local o = unitAt(nx, ny)
        if t.cost and not (o and o.team ~= u.team) then
          local c = n.c + t.cost
          local k = key(nx, ny)
          if c <= u.mov and (not out[k] or out[k].c > c) then
            out[k] = {x = nx, y = ny, c = c, prev = n}
            open[#open + 1] = out[k]
          end
        end
      end
    end
  end
  -- tiles with allies can be crossed but not stopped on
  for k, n in pairs(out) do
    local o = unitAt(n.x, n.y)
    if o and o ~= u then n.pass = true end
  end
  return out
end
local function pathTo(node)
  local p = {}
  while node do table.insert(p, 1, node); node = node.prev end
  return p
end
local function rangeOf(u, x, y)
  local r1 = u.r1
  local t = terrainAt(x, y)
  if t.range and u.r1 > 1 then r1 = r1 + t.range end
  return u.r0, r1
end
local function canHit(u, x, y, target)
  local r0, r1 = rangeOf(u, x, y)
  local d = dist(x, y, target.x, target.y)
  return d >= r0 and d <= r1
end

-- damage of a on d (a standing at ax, ay)
local function damage(a, d)
  local ca, cd = cls(a), cls(d)
  local t = terrainAt(d.x, d.y)
  local def = d.def * (1 + t.def)
  if ca.magic then def = def * 0.3 end
  local atk = a.atk
  if ca.vsRider and cd.rider then atk = atk * ca.vsRider end
  if a.team == 2 then atk = atk * K.pick(0.78, 0.92, 1.05) else atk = atk * 1.08 end
  return max(1, floor(atk * 1.4 - def * 0.8 + 0.5))
end
local function forecast(a, d, ax, ay)
  local ox, oy = a.x, a.y
  a.x, a.y = ax, ay
  local dmg = damage(a, d)
  local counter = 0
  if d.hp - dmg > 0 and cls(d).heal == nil and canHit(d, d.x, d.y, a) then counter = damage(d, a) end
  a.x, a.y = ox, oy
  return dmg, counter
end

-- ---------------------------------------------------------------- coroutine helpers (animations run as scripts)
local function wait(t) while t > 0 do t = t - coroutine.yield() end end

local Battle, Briefing, Result, Title, Chronicle, Ending

local function floatText(text, x, y, col)
  B.floats[#B.floats + 1] = {text = text, x = x, y = y, col = col or "#FFFFFF", t = 0}
end
local function cellCenter(x, y) return B.ox + (x + 0.5) * B.cs, B.oy + (y + 0.5) * B.cs end

local function moveAlong(u, path)
  for i = 2, #path do
    local n = path[i]
    local fx, fy = u.px, u.py
    local t = 0
    K.sfx("step")
    while t < 0.11 do
      t = t + coroutine.yield()
      local k = min(1, t / 0.11)
      u.px, u.py = fx + (n.x - fx) * k, fy + (n.y - fy) * k
    end
  end
  local last = path[#path]
  u.x, u.y, u.px, u.py = last.x, last.y, last.x, last.y
end

local function gainXp(u, n)
  if u.team ~= 1 or not u.alive then return end
  u.xp = u.xp + n
  while u.xp >= 100 do
    u.xp = u.xp - 100
    u.lvl = u.lvl + 1
    local g = cls(u).grow
    u.maxHp = u.maxHp + g.hp
    u.hp = u.hp + g.hp
    u.atk = u.atk + g.atk
    u.def = u.def + g.def
    K.sfx("levelup")
    local cx, cy = cellCenter(u.x, u.y)
    floatText(TR("level_up"), cx, cy - 20, "#FFE14D")
    glows:setColors({"#FFFFFF", "#FFE14D", "#FFE14D00"})
    glows:emit(24, cx, cy)
    B.levelUps = (B.levelUps or 0) + 1
    wait(0.6)
  end
end

local function strike(a, d)
  local ca = cls(a)
  local dmg = damage(a, d)
  local crit = random() < (a.team == 1 and 0.08 or 0.05)
  if crit then dmg = floor(dmg * 1.6 + 0.5) end
  local ax, ay = cellCenter(a.x, a.y)
  local dx, dy = cellCenter(d.x, d.y)
  local l = sqrt((dx - ax) ^ 2 + (dy - ay) ^ 2) + 0.01
  a.lx, a.ly = (dx - ax) / l, (dy - ay) / l
  -- wind up and lunge
  local t = 0
  while t < 0.16 do t = t + coroutine.yield(); a.lunge = min(1, t / 0.16) end
  if ca.r1 > 1 and dist(a.x, a.y, d.x, d.y) > 1 then K.sfx(ca.magic and "magic" or "arrow") else K.sfx("sword") end
  if crit then K.sfx("crit"); game.flash("#FFFFFF", 0.15, 0.4); floatText(TR("critical"), dx, dy - 26, "#FFE14D") end
  d.hp = max(0, d.hp - dmg)
  d.flash = 0.25
  floatText("-" .. dmg, dx, dy - 10, d.team == 1 and "#FF8A8A" or "#FFFFFF")
  sparks:setColors({"#FFFFFF", ca.magic and "#B98CFF" or "#FFD36A", "#FF8A1A00"})
  sparks:emit(crit and 26 or 14, dx, dy)
  B.shake = crit and 6 or 3
  K.rumble(crit and 0.7 or 0.35, crit and 120 or 60)
  t = 0
  while t < 0.18 do t = t + coroutine.yield(); a.lunge = max(0, 1 - t / 0.18) end
  a.lunge = 0
  if d.hp <= 0 then
    d.alive = false
    K.sfx("fall")
    local fx, fy = cellCenter(d.x, d.y)
    sparks:setColors({"#FFFFFF", d.team == 1 and BLUE or RED, "#00000000"})
    sparks:emit(30, fx, fy)
    t = 0
    while t < 0.4 do t = t + coroutine.yield(); d.fade = max(0, 1 - t / 0.4) end
    return true
  end
  wait(0.12)
  return false
end

-- a full exchange: attack, then the counter if the defender can answer
local function combat(a, d)
  local killed = strike(a, d)
  gainXp(a, 12 + max(0, (d.lvl - a.lvl) * 3) + (killed and 30 or 0))
  if not killed and cls(d).heal == nil and canHit(d, d.x, d.y, a) then
    wait(0.1)
    local k2 = strike(d, a)
    gainXp(d, 8 + (k2 and 30 or 0))
  end
end

local function healUnit(c, t)
  local amount = min(t.maxHp - t.hp, cls(c).heal + floor(c.lvl / 2))
  t.hp = t.hp + amount
  K.sfx("heal")
  local cx, cy = cellCenter(t.x, t.y)
  floatText("+" .. amount, cx, cy - 10, "#7CFF9B")
  glows:setColors({"#FFFFFF", "#7CFF9B", "#7CFF9B00"})
  glows:emit(20, cx, cy)
  wait(0.45)
  gainXp(c, 18)
end

-- ---------------------------------------------------------------- objectives
local function enemiesLeft()
  local n = 0
  for _, u in ipairs(B.units) do if u.alive and u.team == 2 then n = n + 1 end end
  return n
end
local function checkEnd()
  local lord, heroes = false, 0
  for _, u in ipairs(B.units) do
    if u.alive and u.team == 1 then heroes = heroes + 1; if u.hero == "maren" then lord = true end end
  end
  if not lord or heroes == 0 then return "defeat" end
  local m = B.mission
  if m.goal == "rout" and enemiesLeft() == 0 then return "victory" end
  if m.goal == "boss" then
    local boss = false
    for _, u in ipairs(B.units) do if u.alive and u.class == "warlord" then boss = true end end
    if not boss then return "victory" end
  end
  if m.goal == "seize" then
    local s = m.seize
    local u = unitAt(s[1], s[2])
    if u and u.team == 1 and u.hero == "maren" then return "victory" end
  end
  if m.goal == "survive" and B.turn > m.turns then return "victory" end
  return nil
end

-- ---------------------------------------------------------------- enemy turn
local function enemyThink(u)
  local tiles = reach(u)
  local best, bestScore = nil, -1e9
  local foes = {}
  for _, o in ipairs(B.units) do if o.alive and o.team ~= u.team then foes[#foes + 1] = o end end
  if cls(u).heal then
    for _, n in pairs(tiles) do
      if not n.pass then
        for _, o in ipairs(B.units) do
          if o.alive and o.team == u.team and o ~= u and o.hp < o.maxHp and dist(n.x, n.y, o.x, o.y) == 1 then
            local s = (o.maxHp - o.hp) * 2 - n.c * 0.1
            if s > bestScore then best, bestScore = {node = n, heal = o}, s end
          end
        end
      end
    end
    if best then return best end
  end
  -- the warlord and guards wait until someone comes close
  local holding = (u.class == "warlord" or u.hold) and not u.roused
  if holding then
    for _, f in ipairs(foes) do if dist(f.x, f.y, u.x, u.y) <= 5 then u.roused = true end end
  end
  for _, n in pairs(tiles) do
    if not n.pass and (not holding or (n.x == u.x and n.y == u.y) or u.roused) then
      for _, f in ipairs(foes) do
        local ox, oy = u.x, u.y
        u.x, u.y = n.x, n.y
        local ok = canHit(u, n.x, n.y, f)
        u.x, u.y = ox, oy
        if ok then
          local dmg, counter = forecast(u, f, n.x, n.y)
          local s = dmg * 1.2 + (dmg >= f.hp and 40 or 0) - counter * 0.7 + terrainAt(n.x, n.y).def * 12 - n.c * 0.05
          if f.hero == "maren" then s = s + 6 end
          if s > bestScore then best, bestScore = {node = n, target = f}, s end
        end
      end
    end
  end
  if best then return best end
  if holding and not u.roused then return nil end
  -- no target in reach: walk towards the closest foe
  local goal, gd = nil, 1e9
  for _, f in ipairs(foes) do
    local d = dist(f.x, f.y, u.x, u.y)
    if d < gd then goal, gd = f, d end
  end
  if not goal then return nil end
  local bestN, bd = nil, 1e9
  for _, n in pairs(tiles) do
    if not n.pass then
      local d = dist(n.x, n.y, goal.x, goal.y) + n.c * 0.01
      if d < bd then bestN, bd = n, d end
    end
  end
  return bestN and {node = bestN} or nil
end


local function enemyPhase()
  B.phase = "enemy"
  B.banner = {text = TR("enemy_phase"), col = RED, t = 1.2}
  K.music("enemy")
  K.sfx("horn")
  wait(1.0)
  for _, u in ipairs(B.units) do
    if u.alive and u.team == 2 then
      local plan = enemyThink(u)
      if plan then
        B.cursor.x, B.cursor.y = u.x, u.y
        B.focus = u
        wait(0.15)
        local path = pathTo(plan.node)
        if #path > 1 then moveAlong(u, path) end
        if plan.target and plan.target.alive then
          wait(0.1)
          combat(u, plan.target)
        elseif plan.heal then
          healUnit(u, plan.heal)
        end
        local r = checkEnd()
        if r then return r end
        wait(0.08)
      end
    end
  end
  B.focus = nil
  return nil
end

-- ======================================================================== BATTLE scene
Battle = {controls = false}

function Battle:enter(p)
  self.p = p
  local m = M.MISSIONS[p.n]
  B = {mission = m, n = p.n, map = m.map, units = {}, turn = 1, phase = "player", cursor = {x = 0, y = 0}, floats = {},
       shake = 0, mode = "idle", danger = false}
  K.music("battle")
  K.clearTips()
  -- deploy the company on the numbered slots, enemies on their letters
  local slots = {}
  for y = 0, H - 1 do
    local row = m.units[y + 1]
    for x = 0, W - 1 do
      local ch = row:sub(x + 1, x + 1)
      if tonumber(ch) then slots[tonumber(ch)] = {x, y}
      elseif M.ELETTER[ch] then
        local lvl = m.level + K.pick(-1, 0, 1)
        if ch == "W" then lvl = lvl + 2 end
        local u = makeUnit(M.ELETTER[ch], 2, x, y, max(1, lvl), TRd("cls_" .. M.ELETTER[ch]))
        B.units[#B.units + 1] = u
      end
    end
  end
  local k = 1
  for _, h in ipairs(M.HEROES) do
    if h.join <= p.n and slots[k] then
      local st = heroState(h.id)
      local u = makeUnit(h.class, 1, slots[k][1], slots[k][2], 1, TRd("hero_" .. h.id), h.id)
      if st then u.lvl, u.xp, u.maxHp, u.atk, u.def = st.lvl, st.xp, st.maxHp, st.atk, st.def; u.hp = u.maxHp end
      B.units[#B.units + 1] = u
      if k == 1 then B.cursor.x, B.cursor.y = u.x, u.y end
      k = k + 1
    end
  end
  self.t = 0
  self.co = nil
  self.repeatT = 0
  B.banner = {text = TR("player_phase"), col = BLUE, t = 1.4}
  K.sfx("horn")
  if p.n == 1 then
    K.tip("select", TR("tip_select", K.btn("confirm") or TR("tap")), "touch_app", 7)
    K.tip("terrain", TR("tip_terrain"), "forest", 7)
    K.tip("counter", TR("tip_counter"), "shield", 7)
    K.tip("endturn", TR("tip_endturn", K.btn("endturn") or ""), "hourglass_bottom", 7)
  end
  if p.n == 2 then K.tip("heal", TR("tip_heal"), "healing", 6) end
  if m.goal == "seize" then K.tip("seize", TR("tip_seize"), "flag", 6) end
  if m.goal == "survive" then K.tip("survive", TR("tip_survive", m.turns), "hourglass_bottom", 6) end
  K.tip("danger", TR("tip_danger", K.btn("danger") or ""), "visibility", 6)
end
function Battle:restart() K.go(Battle, self.p, "fade", 0.3) end
function Battle:pauseItems()
  return {{label = TR("end_turn"), icon = "hourglass_bottom", action = function() game.resume(); self:endTurn() end},
          {label = TR("chronicle"), icon = "menu_book", action = function() game.paused = false; K.go(Chronicle) end}}
end

function Battle:layout()
  local cs = floor(min((game.width - 190) / W, (game.height - 44) / H))
  B.cs = cs
  B.ox = 12
  B.oy = 34 + ((game.height - 44) - cs * H) / 2
end

function Battle:run(fn)
  self.co = coroutine.create(fn)
end

function Battle:select(u)
  B.sel = u
  B.reach = reach(u)
  B.mode = "move"
  K.sfx("ui_ok")
  K.tipDone("select")
end
function Battle:cancel()
  if B.mode == "action" or B.mode == "target" then
    -- undo the move
    local u = B.sel
    u.x, u.y, u.px, u.py = B.from[1], B.from[2], B.from[1], B.from[2]
    B.mode = "move"
    B.reach = reach(u)
    B.actions = nil
    K.sfx("ui_back")
  elseif B.mode == "move" then
    B.mode, B.sel, B.reach = "idle", nil, nil
    K.sfx("ui_back")
  end
end

function Battle:targetsFrom(u, x, y)
  local out = {}
  local heal = cls(u).heal
  for _, o in ipairs(B.units) do
    if o.alive and o ~= u then
      if heal then
        if o.team == u.team and o.hp < o.maxHp and dist(x, y, o.x, o.y) == 1 then out[#out + 1] = o end
      elseif o.team ~= u.team then
        local ox, oy = u.x, u.y
        u.x, u.y = x, y
        if canHit(u, x, y, o) then out[#out + 1] = o end
        u.x, u.y = ox, oy
      end
    end
  end
  return out
end

function Battle:moveTo(node)
  local u = B.sel
  B.from = {u.x, u.y}
  B.mode = "anim"
  self:run(function()
    moveAlong(u, pathTo(node))
    B.targets = self:targetsFrom(u, u.x, u.y)
    B.actions = {}
    if #B.targets > 0 then B.actions[#B.actions + 1] = cls(u).heal and "heal" or "attack" end
    B.actions[#B.actions + 1] = "wait"
    B.actionSel = 1
    B.mode = "action"
  end)
end

function Battle:finishUnit(u)
  u.done = true
  B.sel, B.reach, B.actions, B.targets = nil, nil, nil, nil
  B.mode = "idle"
  local r = checkEnd()
  if r then self:finish(r) return end
  -- every unit has acted: the enemy moves
  for _, o in ipairs(B.units) do if o.alive and o.team == 1 and not o.done then return end end
  self:endTurn()
end

function Battle:doAction(name)
  local u = B.sel
  if name == "wait" then
    K.sfx("ui_ok")
    self:finishUnit(u)
  elseif name == "attack" or name == "heal" then
    B.mode = "target"
    B.targetSel = 1
    local t = B.targets[1]
    B.cursor.x, B.cursor.y = t.x, t.y
    K.sfx("ui_ok")
  end
end

function Battle:confirmTarget(t)
  local u = B.sel
  B.mode = "anim"
  self:run(function()
    if cls(u).heal then healUnit(u, t) else combat(u, t) end
    K.tipDone("counter")
    self:finishUnit(u)
  end)
end

function Battle:endTurn()
  if B.phase ~= "player" or B.mode == "anim" then return end
  B.mode, B.sel, B.reach = "anim", nil, nil
  K.tipDone("endturn")
  self:run(function()
    local r = enemyPhase()
    if r then self:finish(r) return end
    -- new turn: heal on villages and castles, everyone ready again
    B.turn = B.turn + 1
    for _, u in ipairs(B.units) do
      if u.alive then
        u.done = false
        local t = terrainAt(u.x, u.y)
        if t.heal and u.hp < u.maxHp then
          local a = min(u.maxHp - u.hp, t.heal)
          u.hp = u.hp + a
          local cx, cy = cellCenter(u.x, u.y)
          floatText("+" .. a, cx, cy - 10, "#7CFF9B")
        end
      end
    end
    r = checkEnd()
    if r then self:finish(r) return end
    B.phase = "player"
    K.music("battle")
    B.banner = {text = TR("player_phase"), col = BLUE, t = 1.2}
    K.sfx("horn")
    wait(0.8)
    B.mode = "idle"
  end)
end

function Battle:finish(result)
  B.mode = "end"
  self.co = nil
  local win = result == "victory"
  K.sfx(win and "victory" or "defeat")
  K.rumble(win and 0.6 or 0.4, 300)
  if win then
    -- the company keeps its experience
    for _, u in ipairs(B.units) do
      if u.team == 1 and u.hero then
        setHeroState(u.hero, {lvl = u.lvl, xp = u.xp, maxHp = u.maxHp, atk = u.atk, def = u.def})
      end
    end
    if B.n > save:get("cleared", 0) then save:set("cleared", B.n) end
    save:best("turns_" .. B.n, B.turn, true)
  end
  game.tween.after(1.2, function()
    K.go(Result, {n = B.n, win = win, turns = B.turn, levelUps = B.levelUps or 0}, "fade", 0.5)
  end)
end

-- ---------------------------------------------------------------- input
function Battle:update(dt)
  self.t = self.t + dt
  self:layout()
  sparks:update(dt)
  glows:update(dt)
  if B.shake > 0 then B.shake = max(0, B.shake - dt * 18) end
  for _, u in ipairs(B.units) do if u.flash > 0 then u.flash = u.flash - dt end end
  for i = #B.floats, 1, -1 do
    local f = B.floats[i]
    f.t = f.t + dt
    if f.t > 1.1 then table.remove(B.floats, i) end
  end
  if B.banner then B.banner.t = B.banner.t - dt; if B.banner.t <= 0 then B.banner = nil end end
  if self.co then
    local co = self.co
    local ok, err = coroutine.resume(co, dt)
    if not ok then error(err) end
    if coroutine.status(co) == "dead" and self.co == co then self.co = nil end
    return
  end
  if B.mode == "end" or B.phase ~= "player" then return end
  if I.pressed("danger") then B.danger = not B.danger; K.sfx("ui_move"); K.tipDone("danger") end
  if I.pressed("endturn") then
    if B.mode == "idle" then
      U.dialog{title = TR("end_turn"), text = TR("end_turn_q"), buttons = {TR("k_yes"), TR("k_no")},
               onClose = function(i) if i == 1 then self:endTurn() end end}
    end
    return
  end
  -- action menu
  if B.mode == "action" then
    if I.pressed("up") then B.actionSel = (B.actionSel - 2) % #B.actions + 1; K.sfx("ui_move") end
    if I.pressed("down") then B.actionSel = B.actionSel % #B.actions + 1; K.sfx("ui_move") end
    if I.pressed("confirm") then self:doAction(B.actions[B.actionSel]) end
    if I.pressed("back") then self:cancel() end
    self:pointerMenu()
    return
  end
  if B.mode == "target" then
    local n = #B.targets
    if I.pressed("right") or I.pressed("down") or I.pressed("nextunit") then B.targetSel = B.targetSel % n + 1; K.sfx("ui_move") end
    if I.pressed("left") or I.pressed("up") or I.pressed("prevunit") then B.targetSel = (B.targetSel - 2) % n + 1; K.sfx("ui_move") end
    local t = B.targets[B.targetSel]
    B.cursor.x, B.cursor.y = t.x, t.y
    if I.pressed("confirm") then self:confirmTarget(t) return end
    if I.pressed("back") then B.mode = "action"; K.sfx("ui_back") end
    self:pointerTarget()
    return
  end
  -- cursor movement with repeat
  local mx, my = 0, 0
  if I.pressed("left") then mx = -1 elseif I.pressed("right") then mx = 1 end
  if I.pressed("up") then my = -1 elseif I.pressed("down") then my = 1 end
  local held = I.down("left") or I.down("right") or I.down("up") or I.down("down")
  if mx ~= 0 or my ~= 0 then self.repeatT = 0.28
  elseif held then
    self.repeatT = self.repeatT - dt
    if self.repeatT <= 0 then
      self.repeatT = 0.08
      mx = I.down("left") and -1 or (I.down("right") and 1 or 0)
      my = I.down("up") and -1 or (I.down("down") and 1 or 0)
    end
  end
  if mx ~= 0 or my ~= 0 then
    B.cursor.x = max(0, min(W - 1, B.cursor.x + mx))
    B.cursor.y = max(0, min(H - 1, B.cursor.y + my))
    K.sfx("ui_move")
  end
  if I.pressed("nextunit") or I.pressed("prevunit") then
    local list = {}
    for _, u in ipairs(B.units) do if u.alive and u.team == 1 and not u.done then list[#list + 1] = u end end
    if #list > 0 then
      B.cycle = ((B.cycle or 0) + (I.pressed("nextunit") and 1 or -1)) % #list
      local u = list[B.cycle + 1]
      B.cursor.x, B.cursor.y = u.x, u.y
      K.sfx("ui_move")
    end
  end
  if I.pressed("confirm") then self:pick(B.cursor.x, B.cursor.y) end
  if I.pressed("back") then self:cancel() end
  local pt = I.pointer
  if pt.released then
    local x, y = floor((pt.x - B.ox) / B.cs), floor((pt.y - B.oy) / B.cs)
    if x >= 0 and y >= 0 and x < W and y < H then
      B.cursor.x, B.cursor.y = x, y
      self:pick(x, y)
    elseif self.endRect and pt.x >= self.endRect[1] and pt.y >= self.endRect[2] and pt.x <= self.endRect[1] + self.endRect[3]
        and pt.y <= self.endRect[2] + self.endRect[4] then
      self:endTurn()
    end
  end
end

function Battle:pick(x, y)
  local u = unitAt(x, y)
  if B.mode == "idle" then
    if u and u.team == 1 and not u.done then self:select(u)
    elseif u then K.sfx("ui_move"); B.inspect = u
    else K.sfx("ui_back") end
  elseif B.mode == "move" then
    local n = B.reach[y * W + x]
    if u == B.sel then
      -- act from where it stands
      self:moveTo(B.reach[y * W + x])
    elseif n and not n.pass then
      self:moveTo(n)
    elseif u and u.team == 1 and not u.done then
      self:select(u)
    else
      K.sfx("ui_back")
    end
  end
end

function Battle:pointerMenu()
  local pt = I.pointer
  if not pt.released or not self.menuRects then return end
  for i, r in ipairs(self.menuRects) do
    if pt.x >= r[1] and pt.y >= r[2] and pt.x <= r[1] + r[3] and pt.y <= r[2] + r[4] then
      B.actionSel = i
      self:doAction(B.actions[i])
      return
    end
  end
  self:cancel()
end
function Battle:pointerTarget()
  local pt = I.pointer
  if not pt.released then return end
  local x, y = floor((pt.x - B.ox) / B.cs), floor((pt.y - B.oy) / B.cs)
  for i, t in ipairs(B.targets) do
    if t.x == x and t.y == y then
      if B.targetSel == i then self:confirmTarget(t) else B.targetSel = i; K.sfx("ui_move") end
      return
    end
  end
end

-- ---------------------------------------------------------------- drawing
local function drawTile(ch, x, y, s, t, gx, gy)
  local grass = ((gx + gy) % 2 == 0) and "#6FA85A" or "#68A055"
  if ch == "~" or ch == "b" then
    G.rect(x, y, s, s, 0, "#3A7BC8")
    G.color("#FFFFFF40")
    local o = (t * 8 + gx * 7) % s
    G.line(x + o * 0.3, y + s * 0.35, x + o * 0.3 + s * 0.3, y + s * 0.35, 1.2)
    G.line(x + s * 0.5 - o * 0.2, y + s * 0.7, x + s * 0.8 - o * 0.2, y + s * 0.7, 1.2)
    if ch == "b" then
      G.rect(x, y + s * 0.15, s, s * 0.7, 0, "#9C7A52")
      G.color("#6B5038")
      for k = 1, 3 do G.line(x + k * s / 4, y + s * 0.15, x + k * s / 4, y + s * 0.85, 1) end
    end
    return
  end
  if ch == "c" then
    G.rect(x, y, s, s, 0, "#8A8478")
    G.rect(x + 2, y + 2, s - 4, s - 4, 3, "#A39C8E")
    G.rect(x + s * 0.2, y + s * 0.15, s * 0.6, s * 0.7, 2, "#6E685C")
    G.rect(x + s * 0.35, y + s * 0.5, s * 0.3, s * 0.35, 2, "#3A3530")
    return
  end
  if ch == "^" then
    G.rect(x, y, s, s, 0, "#7A7468")
    G.poly({x + s * 0.05, y + s, x + s * 0.45, y + s * 0.15, x + s * 0.85, y + s}, "#9A9284")
    G.poly({x + s * 0.32, y + s * 0.42, x + s * 0.45, y + s * 0.15, x + s * 0.58, y + s * 0.42}, "#F2F2F2")
    return
  end
  G.rect(x, y, s, s, 0, ch == "=" and "#C9B48A" or grass)
  if ch == "f" then
    for _, p in ipairs({{0.3, 0.38}, {0.68, 0.32}, {0.5, 0.68}}) do
      G.rect(x + s * p[1] - 1.5, y + s * p[2] + 3, 3, 6, 1, "#5A4030")
      G.circle(x + s * p[1], y + s * p[2], s * 0.19, "#2F6A3A")
      G.circle(x + s * p[1] - 2, y + s * p[2] - 2, s * 0.08, "#4E8F52")
    end
  elseif ch == "h" then
    G.circle(x + s * 0.5, y + s * 0.95, s * 0.48, "#8DB866")
    G.circle(x + s * 0.4, y + s * 0.8, s * 0.12, "#A8CC80")
  elseif ch == "v" then
    G.rect(x + s * 0.22, y + s * 0.45, s * 0.56, s * 0.4, 2, "#E8D8B8")
    G.poly({x + s * 0.15, y + s * 0.48, x + s * 0.5, y + s * 0.18, x + s * 0.85, y + s * 0.48}, "#B8573A")
    G.rect(x + s * 0.44, y + s * 0.62, s * 0.12, s * 0.23, 1, "#6B4A30")
  end
end

local function drawUnit(u, t)
  if not u.alive and u.fade <= 0 then return end
  local cs = B.cs
  local cx, cy = B.ox + (u.px + 0.5) * cs + u.lx * u.lunge * cs * 0.35, B.oy + (u.py + 0.5) * cs + u.ly * u.lunge * cs * 0.35
  local col = u.team == 1 and BLUE or RED
  local bob = (not u.done and u.team == 1 and B.phase == "player") and sin(t * 4 + u.x) * 1.2 or 0
  G.alpha(u.fade * ((u.done and u.team == 1) and 0.55 or 1))
  G.circle(cx + 1, cy + 3, cs * 0.36, "#00000050")
  G.circle(cx, cy + bob, cs * 0.36, u.flash > 0 and "#FFFFFF" or col)
  G.circle(cx, cy + bob, cs * 0.28, u.team == 1 and "#22407A" or "#7A2A22")
  G.icon(ICON[u.class] or "circle", cx, cy + bob, cs * 0.36, "#FFFFFF")
  if cls(u).boss then G.icon("whatshot", cx + cs * 0.3, cy - cs * 0.3 + bob, cs * 0.28, "#FFD166") end
  -- hp bar
  local w = cs * 0.7
  G.rect(cx - w / 2, cy + cs * 0.36, w, 4, 2, "#00000090")
  G.rect(cx - w / 2, cy + cs * 0.36, w * u.hp / u.maxHp, 4, 2, u.hp / u.maxHp > 0.4 and "#7CFF9B" or "#FF6B6B")
  G.unalpha()
end

function Battle:draw()
  K.accent = "#E8B04A"
  self:layout()
  local t = game.realTime
  local cs, ox, oy = B.cs, B.ox, B.oy
  G.gradient(0, 0, game.width, game.height, "#2A2236", "#16121E")
  local sx, sy = 0, 0
  if B.shake > 0 then sx, sy = (random() - 0.5) * B.shake * K.shakeScale(), (random() - 0.5) * B.shake * K.shakeScale() end
  G.push(sx, sy)
  G.rect(ox - 4, oy - 4, cs * W + 8, cs * H + 8, 6, "#0E0B14")
  for y = 0, H - 1 do
    local row = B.map[y + 1]
    for x = 0, W - 1 do drawTile(row:sub(x + 1, x + 1), ox + x * cs, oy + y * cs, cs, t, x, y) end
  end
  G.color("#00000022")
  for x = 1, W - 1 do G.line(ox + x * cs, oy, ox + x * cs, oy + H * cs, 1) end
  for y = 1, H - 1 do G.line(ox, oy + y * cs, ox + W * cs, oy + y * cs, 1) end
  -- seize marker
  local m = B.mission
  if m.goal == "seize" then
    local fx, fy = ox + (m.seize[1] + 0.5) * cs, oy + (m.seize[2] + 0.5) * cs
    G.icon("flag", fx, fy - cs * 0.15 + sin(t * 3) * 2, cs * 0.6, "#FFD166")
  end
  -- danger zone: every tile an enemy could hit next turn
  if B.danger then
    local zone = {}
    for _, u in ipairs(B.units) do
      if u.alive and u.team == 2 then
        for _, n in pairs(reach(u)) do
          local r0, r1 = rangeOf(u, n.x, n.y)
          for dy = -r1, r1 do
            for dx = -r1, r1 do
              local d = abs(dx) + abs(dy)
              if d >= r0 and d <= r1 then zone[(n.y + dy) * W + n.x + dx] = true end
            end
          end
        end
      end
    end
    for k in pairs(zone) do
      local x, y = k % W, k // W
      if x >= 0 and y >= 0 and x < W and y < H then G.rect(ox + x * cs + 1, oy + y * cs + 1, cs - 2, cs - 2, 3, "#FF3B3B30") end
    end
  end
  -- movement and attack ranges
  if B.mode == "move" and B.reach then
    local u = B.sel
    local hit = {}
    for k, n in pairs(B.reach) do
      G.rect(ox + n.x * cs + 1, oy + n.y * cs + 1, cs - 2, cs - 2, 4, "#5AA0FF60")
      if not n.pass then
        local r0, r1 = rangeOf(u, n.x, n.y)
        for dy = -r1, r1 do
          for dx = -r1, r1 do
            local d = abs(dx) + abs(dy)
            if d >= r0 and d <= r1 then hit[(n.y + dy) * W + n.x + dx] = true end
          end
        end
      end
    end
    for k in pairs(hit) do
      local x, y = k % W, k // W
      if x >= 0 and y >= 0 and x < W and y < H and not B.reach[k] then
        G.rect(ox + x * cs + 1, oy + y * cs + 1, cs - 2, cs - 2, 4, cls(u).heal and "#7CFF9B40" or "#FF5A5A50")
      end
    end
    -- path preview
    local n = B.reach[B.cursor.y * W + B.cursor.x]
    if n then
      local path = pathTo(n)
      local pts = {}
      for _, p in ipairs(path) do pts[#pts + 1] = ox + (p.x + 0.5) * cs; pts[#pts + 1] = oy + (p.y + 0.5) * cs end
      if #pts >= 4 then G.color("#FFFFFFC0"); G.lines(pts, 3) end
    end
  end
  if B.mode == "target" then
    for i, tg in ipairs(B.targets) do
      G.color(i == B.targetSel and "#FFD166" or "#FF5A5A")
      G.rectLine(ox + tg.x * cs + 2, oy + tg.y * cs + 2, cs - 4, cs - 4, 5, 2)
    end
  end
  for _, u in ipairs(B.units) do drawUnit(u, t) end
  -- cursor
  if B.phase == "player" and B.mode ~= "anim" and B.mode ~= "end" then
    local p = 1 + sin(t * 6) * 0.06
    local cx, cy = ox + (B.cursor.x + 0.5) * cs, oy + (B.cursor.y + 0.5) * cs
    G.color("#FFD166")
    G.rectLine(cx - cs * 0.5 * p, cy - cs * 0.5 * p, cs * p, cs * p, 6, 2.4)
  end
  sparks:draw()
  glows:draw()
  for _, f in ipairs(B.floats) do
    G.alpha(min(1, (1.1 - f.t) * 3))
    U.text(f.text, f.x - 40, f.y - f.t * 26, 14, f.col, "center", 80, "bold")
    G.unalpha()
  end
  G.pop()
  self:drawPanel(t)
  if B.mode == "action" then self:drawActions() end
  if B.banner then
    local a = min(1, B.banner.t * 3)
    G.alpha(a)
    G.rect(0, game.height * 0.42, game.width, 44, 0, "#000000A0")
    G.rect(0, game.height * 0.42, game.width, 3, 0, B.banner.col)
    U.text(B.banner.text, 0, game.height * 0.42 + 10, 22, "#FFFFFF", "center", game.width, "bold")
    G.unalpha()
  end
end

function Battle:drawActions()
  local u = B.sel
  local cs = B.cs
  local x = B.ox + (u.x + 1.1) * cs
  if x + 110 > B.ox + W * cs then x = B.ox + (u.x - 0.1) * cs - 110 end
  local y = B.oy + u.y * cs
  self.menuRects = {}
  G.rect(x, y, 110, #B.actions * 26 + 8, 8, "#0E0B14E8")
  for i, a in ipairs(B.actions) do
    local sel = i == B.actionSel
    G.rect(x + 4, y + 4 + (i - 1) * 26, 102, 24, 6, sel and "#E8B04A" or "#FFFFFF10")
    U.text(TRd("act_" .. a), x + 4, y + 9 + (i - 1) * 26, 12, sel and "#1A1020" or "#FFFFFF", "center", 102, "semibold", false)
    self.menuRects[i] = {x + 4, y + 4 + (i - 1) * 26, 102, 24}
  end
end

function Battle:drawPanel(t)
  local px = B.ox + W * B.cs + 12
  local pw = game.width - px - 10
  local m = B.mission
  U.text(TRd("m_" .. m.key), 12, 8, 14, "#FFFFFF", "left", nil, "bold")
  local goal = m.goal == "survive" and TR("goal_survive", m.turns) or TRd("goal_" .. m.goal)
  U.text(goal, 12 + G.textWidth(TRd("m_" .. m.key), 14, "bold") + 12, 11, 11, "#E8B04A", "left", nil, "semibold", false)
  G.rect(px, 34, pw, game.height - 44, 10, "#0E0B14C0")
  U.text(TR("turn_n", B.turn), px, 42, 13, "#FFFFFF", "center", pw, "bold")
  U.text(B.phase == "player" and TR("your_move") or TR("enemy_move"), px, 60, 10, B.phase == "player" and "#8AB4FF" or "#FF8A7A", "center", pw, "semibold", false)
  -- the unit under the cursor (or the forecast while choosing a target)
  local u = unitAt(B.cursor.x, B.cursor.y) or B.sel
  local y = 82
  if B.mode == "target" and B.sel then
    local tg = B.targets[B.targetSel]
    U.text(TR("forecast"), px, y, 11, "#E8B04A", "center", pw, "bold", false)
    y = y + 18
    if cls(B.sel).heal then
      U.text(TR("heal_amount", min(tg.maxHp - tg.hp, cls(B.sel).heal + floor(B.sel.lvl / 2))), px, y, 12, "#7CFF9B", "center", pw, "bold", false)
    else
      local dmg, counter = forecast(B.sel, tg, B.sel.x, B.sel.y)
      U.text(B.sel.name, px + 8, y, 11, "#8AB4FF", "left", nil, "semibold", false)
      U.text(B.sel.hp .. " → " .. max(0, B.sel.hp - counter), px, y + 14, 12, "#FFFFFF", "right", pw - 8, "bold", false)
      U.text(TR("deals", dmg), px + 8, y + 14, 10, "#FFFFFFB0", "left", nil, "semibold", false)
      y = y + 36
      U.text(tg.name, px + 8, y, 11, "#FF8A7A", "left", nil, "semibold", false)
      U.text(tg.hp .. " → " .. max(0, tg.hp - dmg), px, y + 14, 12, "#FFFFFF", "right", pw - 8, "bold", false)
      U.text(counter > 0 and TR("deals", counter) or TR("no_counter"), px + 8, y + 14, 10, "#FFFFFFB0", "left", nil, "semibold", false)
    end
    y = y + 40
  elseif u then
    G.circle(px + 22, y + 14, 14, u.team == 1 and BLUE or RED)
    G.icon(ICON[u.class], px + 22, y + 14, 16, "#FFFFFF")
    U.text(u.name, px + 42, y + 1, 12, "#FFFFFF", "left", nil, "bold", false)
    U.text(TRd("cls_" .. u.class) .. " · " .. TR("lv", u.lvl), px + 42, y + 16, 10, "#FFFFFFB0", "left", nil, "semibold", false)
    y = y + 34
    U.bar(px + 8, y, pw - 16, 7, u.hp / u.maxHp, "#7CFF9B")
    U.text(u.hp .. "/" .. u.maxHp, px, y + 9, 10, "#FFFFFFC0", "center", pw, "mono", false)
    y = y + 24
    local stats = {{TR("st_atk"), u.atk}, {TR("st_def"), u.def}, {TR("st_mov"), u.mov}, {TR("st_rng"), u.r0 == u.r1 and u.r1 or (u.r0 .. "-" .. u.r1)}}
    for i, s in ipairs(stats) do
      local sx = px + 8 + ((i - 1) % 2) * (pw / 2 - 4)
      local sy = y + floor((i - 1) / 2) * 15
      U.text(s[1], sx, sy, 10, "#FFFFFF90", "left", nil, "semibold", false)
      U.text(tostring(s[2]), sx, sy, 10, "#FFFFFF", "right", pw / 2 - 16, "bold", false)
    end
    y = y + 34
    if u.team == 1 then U.bar(px + 8, y, pw - 16, 4, u.xp / 100, "#E8B04A"); y = y + 10 end
  end
  -- terrain under the cursor
  local tr = terrainAt(B.cursor.x, B.cursor.y)
  U.text(TRd("t_" .. tr.key), px, y + 4, 10, "#FFFFFFC0", "center", pw, "semibold", false)
  local info = tr.cost and TR("t_info", tr.cost, floor(tr.def * 100)) or TR("t_blocked")
  U.text(info, px, y + 18, 9, "#FFFFFF80", "center", pw, "semibold", false)
  -- end turn button and hints
  local by = game.height - 50
  self.endRect = {px + 8, by, pw - 16, 26}
  G.rect(px + 8, by, pw - 16, 26, 8, B.phase == "player" and "#E8B04A" or "#FFFFFF20")
  U.text(TR("end_turn"), px + 8, by + 6, 11, "#1A1020", "center", pw - 16, "bold", false)
  local b = K.btn("endturn")
  if b then U.text(b, px + 8, by + 30, 9, "#FFFFFF80", "center", pw - 16, "semibold", false) end
end

-- ======================================================================== BRIEFING
Briefing = {pausable = false}
function Briefing:enter(p)
  self.p, self.t = p, 0
  K.music("title")
  local key = M.MISSIONS[p.n].key
  local lines = {}
  for i = 1, 3 do
    local s = TRd(key .. "_" .. i)
    if s ~= key .. "_" .. i then
      local who, text = s:match("^(.-): (.+)$")
      lines[#lines + 1] = who and {who = who, text = text} or s
    end
  end
  self.talk = U.dialogue{lines = lines, speed = 55, height = 78, color = "#1A1424F0"}
end
function Briefing:update(dt)
  self.t = self.t + dt
  if self.t < 0.4 then return end
  self.talk:update(dt)
  if self.talk.done or I.pressed("back") or I.pressed("pause") then K.go(Battle, {n = self.p.n}, "circle", 0.5) end
end
function Briefing:draw()
  local m = M.MISSIONS[self.p.n]
  G.gradient(0, 0, game.width, game.height, "#3A2C20", "#1A1410")
  -- a parchment map of the battlefield
  local cs = 16
  local ox, oy = game.width / 2 - W * cs / 2, 70
  G.rect(ox - 10, oy - 10, W * cs + 20, H * cs + 20, 8, "#E8D8B0")
  for y = 0, H - 1 do
    local row = m.map[y + 1]
    for x = 0, W - 1 do
      local ch = row:sub(x + 1, x + 1)
      local col = ({["~"] = "#7FA8C8", f = "#7A9A60", h = "#B8B080", ["^"] = "#8A8070", c = "#7A6A5A", v = "#C88A60", ["="] = "#D8C090", b = "#A08060"})[ch]
      if col then G.rect(ox + x * cs, oy + y * cs, cs, cs, 2, col) end
      local u = m.units[y + 1]:sub(x + 1, x + 1)
      if tonumber(u) then G.circle(ox + (x + 0.5) * cs, oy + (y + 0.5) * cs, 5, BLUE)
      elseif M.ELETTER[u] then G.circle(ox + (x + 0.5) * cs, oy + (y + 0.5) * cs, 5, RED) end
    end
  end
  U.text(TR("battle_n", self.p.n, #M.MISSIONS), 0, 14, 11, "#E8B04A", "center", game.width, "bold", false)
  U.text(TRd("m_" .. m.key), 0, 28, 20, "#FFF1D6", "center", game.width, "bold")
  local goal = m.goal == "survive" and TR("goal_survive", m.turns) or TRd("goal_" .. m.goal)
  U.text(goal, 0, oy + H * cs + 16, 12, "#E8B04A", "center", game.width, "semibold", false)
  if self.t >= 0.4 then self.talk:draw() end
end

-- ======================================================================== RESULT
Result = {pausable = false}
function Result:enter(p)
  self.p, self.t = p, 0
  K.music("title")
  local items = {}
  if p.win then
    if p.n < #M.MISSIONS then
      items[#items + 1] = {label = TR("next_battle"), icon = "skip_next", action = function() K.go(Briefing, {n = p.n + 1}) end}
    else
      items[#items + 1] = {label = TR("epilogue"), icon = "auto_awesome", action = function() K.go(Ending) end}
    end
  else
    items[#items + 1] = {label = TR("retry"), icon = "replay", action = function() K.go(Battle, {n = p.n}, "circle", 0.5) end}
  end
  items[#items + 1] = {label = TR("chronicle"), icon = "menu_book", action = function() K.go(Chronicle) end}
  items[#items + 1] = {label = TR("k_menu"), icon = "home", action = function() K.go(Title) end}
  self.menu = K.menu{items = items, width = 230, itemHeight = 28, size = 12, accent = "#E8B04A"}
end
function Result:update(dt) self.t = self.t + dt; if self.t > 0.5 then self.menu:update() end end
function Result:draw()
  local p = self.p
  G.gradient(0, 0, game.width, game.height, p.win and "#3A2C14" or "#2A1418", "#120E0A")
  local k = min(1, self.t / 0.5)
  G.alpha(k)
  U.text(p.win and TR("victory") or TR("defeat"), 0, 50, 34, p.win and "#FFD166" or "#FF6B6B", "center", game.width, "bold")
  U.text(TRd("m_" .. M.MISSIONS[p.n].key), 0, 92, 14, "#FFF1D6", "center", game.width, "semibold")
  if p.win then
    U.text(TR("won_in", p.turns) .. "   ·   " .. TR("best_turns", save:get("turns_" .. p.n, p.turns)), 0, 118, 12, "#FFFFFFC0", "center", game.width, "semibold", false)
    if p.levelUps > 0 then U.text(TR("level_ups", p.levelUps), 0, 136, 12, "#E8B04A", "center", game.width, "bold", false) end
  else
    U.text(TR("defeat_hint"), 0, 118, 12, "#FFFFFFC0", "center", game.width, "semibold", false)
  end
  G.unalpha()
  self.menu:draw(game.width / 2, 170)
end

-- ======================================================================== CHRONICLE (mission list)
Chronicle = {pausable = false}
function Chronicle:enter()
  K.music("title")
  local items = {}
  local done = save:get("cleared", 0)
  for n, m in ipairs(M.MISSIONS) do
    items[#items + 1] = {label = TR("battle_n", n, #M.MISSIONS) .. "  " .. TRd("m_" .. m.key), icon = n <= done and "check_circle" or "flag",
      enabled = n <= done + 1, value = function()
        local tb = save:get("turns_" .. n)
        return tb and TR("turns_short", tb) or (n <= done + 1 and TR("new") or "")
      end, action = function() K.go(Briefing, {n = n}) end}
  end
  items[#items + 1] = {label = TR("k_back"), icon = "arrow_back", action = function() K.go(Title) end}
  self.menu = K.menu{items = items, width = 400, itemHeight = 27, size = 12, accent = "#E8B04A", onBack = function() K.go(Title) end,
                     selected = min(done + 1, #M.MISSIONS)}
end
function Chronicle:update() self.menu:update() end
function Chronicle:draw()
  G.gradient(0, 0, game.width, game.height, "#2A2236", "#16121E")
  U.text(TR("chronicle"), 0, 14, 20, "#FFF1D6", "center", game.width, "bold")
  U.text(TR("chronicle_d"), 0, 40, 11, "#FFFFFFA0", "center", game.width, "semibold", false)
  self.menu:draw(game.width / 2, 62)
end

-- ======================================================================== ENDING
Ending = {pausable = false}
function Ending:enter() self.t = 0; K.music("title"); save:set("finished", true) end
function Ending:update(dt)
  self.t = self.t + dt
  if self.t > 3 and (I.pressed("confirm") or I.pointer.released) then K.go(Title) end
end
function Ending:draw()
  local W2, H2 = game.width, game.height
  G.gradient(0, 0, W2, H2, "#3A2C14", "#120E0A")
  for i = 1, 3 do
    local a = min(1, max(0, (self.t - i) / 1))
    G.alpha(a)
    U.text(TRd("end" .. i), 40, H2 * 0.25 + i * 32, 15, "#FFF1D6", "center", W2 - 80, "semibold")
    G.unalpha()
  end
  if self.t > 4 then K.prompts({{"confirm", TR("k_menu")}}, W2 / 2, H2 - 30, 10) end
end

-- ======================================================================== TITLE
Title = {pausable = false}
function Title:enter()
  K.music("title")
  K.clearTips()
  self.t = 0
  local nextN = min(#M.MISSIONS, save:get("cleared", 0) + 1)
  local items = {
    {label = save:get("cleared", 0) > 0 and TR("continue") or TR("new_campaign"), icon = "play_arrow",
     action = function() K.go(Briefing, {n = nextN}, "fade", 0.5) end},
    {label = TR("chronicle"), icon = "menu_book", action = function() K.go(Chronicle) end},
    {label = TR("k_settings"), icon = "tune", action = function() game.push(K.SettingsScene, {fromTitle = true}) end},
    {label = TR("k_help"), icon = "help", action = function()
      game.push(K.HelpScene, {title = TR("k_help"), rows = {
        {action = "confirm", text = TR("help_select")}, {action = "back", text = TR("help_cancel")},
        {action = "endturn", text = TR("help_end")}, {action = "danger", text = TR("help_danger")},
        {action = "nextunit", text = TR("help_next")}, {icon = "forest", text = TR("help_terrain")},
        {icon = "shield", text = TR("help_counter")}, {icon = "touch_app", text = TR("help_touch")},
      }})
    end},
    {label = TR("k_quit"), icon = "logout", action = function() K.stopAudio(); sys.exit() end},
  }
  self.menu = K.menu{items = items, width = 210, itemHeight = 28, size = 12, accent = "#E8B04A"}
end
function Title:update(dt) self.t = self.t + dt; self.menu:update() end
function Title:draw()
  local W2, H2 = game.width, game.height
  local t = game.realTime
  G.gradient(0, 0, W2, H2, "#1E1A30", "#5A3A2A")
  -- a castle on a hill at dusk
  G.circle(W2 * 0.72, H2 * 0.36, 40, "#FFD08A30")
  G.circle(W2 * 0.72, H2 * 0.36, 24, "#FFD08A")
  G.circle(W2 * 0.7, H2 + 160, 260, "#2A2030")
  local cx, cy = W2 * 0.7, H2 * 0.62
  G.rect(cx - 70, cy - 20, 140, 60, 0, "#1A1424")
  for k = -2, 2 do G.rect(cx + k * 30 - 10, cy - 50 - (k == 0 and 20 or 0), 20, 40 + (k == 0 and 20 or 0), 0, "#1A1424") end
  for k = -2, 2 do G.poly({cx + k * 30 - 12, cy - 50 - (k == 0 and 20 or 0), cx + k * 30, cy - 70 - (k == 0 and 24 or 0), cx + k * 30 + 12, cy - 50 - (k == 0 and 20 or 0)}, "#2A2036") end
  -- a waving banner
  local bx, by = cx, cy - 94
  G.color("#C9B48A"); G.line(bx, by, bx, by - 50, 2)
  local pts = {}
  for i = 0, 8 do
    local f = i / 8
    pts[#pts + 1] = bx + f * 46
    pts[#pts + 1] = by - 48 + sin(t * 4 - f * 5) * 3 * f
  end
  for i = 8, 0, -1 do
    local f = i / 8
    pts[#pts + 1] = bx + f * 46
    pts[#pts + 1] = by - 28 + sin(t * 4 - f * 5) * 3 * f
  end
  G.color("#3A6FD8")
  G.lines(pts, 6, true)
  for i = 1, 16, 2 do
    G.poly({pts[i], pts[i + 1], pts[i + 2], pts[i + 3], pts[#pts - i - 2], pts[#pts - i - 1], pts[#pts - i], pts[#pts - i + 1]}, "#3A6FD8")
  end
  G.icon("shield", bx + 22, by - 38, 14, "#FFD166")
  local a = min(1, self.t / 0.7)
  G.alpha(a)
  U.text(TR("title_a"), 30, 30, 18, "#E8B04A", "left", nil, "bold")
  U.text(TR("title_b"), 30, 48, 40, "#FFF1D6", "left", nil, "bold")
  U.text(TR("tagline"), 32, 96, 12, "#FFFFFFB0", "left", nil, "semibold", false)
  G.unalpha()
  self.menu:draw(30 + 105, 130)
end

return K.run{
  width = 640, height = 360, scene = Title, title = Title, background = "#16121E", accent = "#E8B04A", dark = "#0A080E",
  controls = {"endturn", "danger", "nextunit", "prevunit"},
  onReset = function()
    for _, k in ipairs({"cleared", "heroes", "finished"}) do save:set(k, nil) end
    for n = 1, #M.MISSIONS do save:set("turns_" .. n, nil) end
  end,
}
