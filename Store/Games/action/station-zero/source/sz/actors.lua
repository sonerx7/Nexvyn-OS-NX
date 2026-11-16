-- Station Zero: the hero, the drones, the sentries, the doors' and switches' Logic machines.
--
-- Game Engine Logic 2.0 (nexvyn.ge_logic) runs every machine: the library behaviours guard_alert (drones join the
-- hunt), aim_fire (armed drones and sentries), guard_alarm (sentries raise the alarm), door_key (keycard door), lever,
-- pressure_plate and checkpoint_save, plus this game's own small door machines. The world adapter below connects them
-- to the station.
local S = require("sz.state")
local F = require("sz.fx")
local W = require("sz.world")
local L = require("nexvyn.ge_logic")
local Char = require("nexvyn.ge_character")
local A = {}

local sqrt, sin, cos, atan, min, max, abs, pi, random, floor =
  math.sqrt, math.sin, math.cos, math.atan, math.min, math.max, math.abs, math.pi, math.random, math.floor

A.drones, A.sentries, A.bolts, A.items = {}, {}, {}, {}
local lib = {}

local function angleDiff(a, b) return (a - b + pi) % (2 * pi) - pi end

-- ---------------------------------------------------------------- Logic world adapter
local world = {}
function world.pos(e) return e.x, e.z end
function world.heading(e) return sin(e.yaw or 0), cos(e.yaw or 0) end
function world.face(e, dx, dz) if e.isDrone or e.isSentry then e.aimYaw = atan(dx, dz) end end
function world.setVel(e, vx, vz) e.lvx, e.lvz = vx, vz end
function world.alive(e) return not e.dead end
function world.matches(e, sel)
  if sel == "@all" or sel == "@any" then return true end
  if sel == "@player" then return e.isPlayer and true or false end
  if sel == "@enemy" then return e.isEnemy and true or false end
  return e.tag == sel
end
function world.nearest(e, sel)
  if sel == "@player" then
    local p = S.player
    if not p or p.dead then return nil end
    if (p.ghost and e.isEnemy) or (e.needLos and not A.sees(e, p)) then return nil end
    return p
  end
  return nil
end
function world.touching(e, sel)
  if sel == "@player" or sel == nil then
    local p = S.player
    if p and not p.dead and (p.x - e.x) ^ 2 + (p.z - e.z) ^ 2 < (e.touchR or 1.1) ^ 2 then return p end
  end
  return nil
end
function world.var(name) return S.vars[name] or 0 end
function world.setVar(name, v) S.vars[name] = v end
function world.input(b, mode)
  if b == "use" then return A.usePressed and true or false end
  return false
end
function world.axis() return 0, 0 end
function world.sound(s) F.sound(s) end
function world.say(t) if t and t ~= "" and t ~= "!" then S.say(TR(t)) end end
function world.anim(e, name) e.anim = name end
function world.setProp(e, k, v)
  if k == "solid" and e.door then e.door.forced = not v end
end
function world.fire(e, kind, dx, dz, speed)
  if e.dead then return end
  local y = e.y or 1.4
  A.bolts[#A.bolts + 1] = {x = e.x + dx * 0.6, y = y, z = e.z + dz * 0.6, vx = dx * 11, vz = dz * 11, life = 2.2}
  F.sound3("shot", e.x, e.z, 0.8)
end
function world.save(e)
  if S.onCheckpoint then S.onCheckpoint(e) end
end
function world.hurt(e, n) if e.isPlayer then A.hurt(n) end end
function world.hp(e) if e.isPlayer then return S.player.hp end return 1 end
function world.rand() return random() end
function world.shake() A.shake = 0.6 end
function world.flash() end
function world.count() return 0 end
function world.score() end
function world.life() end
function world.music() end
function world.win() end
function world.lose() end
function world.restart() end
function world.scene() end
function world.spin() end
function world.jump() end
function world.onGround() return true end
function world.blocked(e) return e.blocked and true or false end
function world.destroy(e) e.dead = true end
function world.find() return nil end
function world.camera() end
function world.teleport() end
function world.heal() end
function world.spawn() end
function world.confetti() end
function world.load() end

-- ---------------------------------------------------------------- machines of this game (GE format)
local function doorMachine(openMsg, closeMsg, delay)
  local m = {initial = "closed", states = {
    {id = "closed", enter = {{t = "set", prop = "solid", v = true}}, transitions = {{to = "open", on = openMsg}}},
    {id = "open", enter = {{t = "set", prop = "solid", v = false}, {t = "sound", s = "door"}}, transitions = {}},
  }}
  if closeMsg then
    m.states[2].transitions = {{to = "closing", on = closeMsg}}
    m.states[3] = {id = "closing", transitions = {{to = "open", on = openMsg}, {to = "closed", after = delay or 3}}}
  end
  return m
end

function A.setup(behaviours)
  lib = {}
  for _, b in ipairs(behaviours or {}) do lib[b.id] = b end
  L.setLibrary(lib)
  L.setWorld(world)
end

-- ---------------------------------------------------------------- player
local graph, durations
function A.newPlayer(x, z, yaw)
  local p = {isPlayer = true, x = x, z = z, y = 0, yaw = yaw or 0, vx = 0, vz = 0, hp = 3, inv = 0, dead = false,
             deadT = 0, noise = 0, step = 0, sneak = false}
  local m = W.models.hero
  if m then
    if not graph then
      local ok, txt = pcall(fs.read, "bundle:/data/locomotion.json")
      graph = ok and txt and json.decode(txt) or nil
      durations = {}
      local info = m:info()
      for _, a in ipairs(info and info.animations or {}) do durations[a.name] = a.duration end
    end
    if graph then
      p.machine = Char.machine(graph, durations)
      local cmd = p.machine:first()
      m:play(cmd.clip, {loop = cmd.loop, speed = cmd.speed, fade = 0})
    end
  end
  S.player = p
  return p
end

function A.hurt(n)
  local p = S.player
  if not p or p.dead or p.inv > 0 then return end
  p.hp = p.hp - (n or 1)
  p.inv = 1.4
  A.shake = 0.8
  F.sound("zap", 1)
  F.burst(p.x, 1.2, p.z, "red")
  pcall(sys.vibrate, 0.9, 180)
  if p.machine then p.machine:trigger("hit") end
  if p.hp <= 0 then
    p.dead, p.deadT = true, 0
    if p.machine then p.machine:set("dead", true) end
    F.sound("lose", 0.9)
  end
end

-- mx, mz: wanted direction in the world (length <= 1); run: 0..1
function A.updatePlayer(dt, mx, mz, sprint, sneak)
  local p = S.player
  local lv = S.level
  p.inv = max(0, p.inv - dt)
  local speed = 0
  if not p.dead then
    local len = sqrt(mx * mx + mz * mz)
    local top = sneak and 1.7 or (sprint and 5.4 or 4.0)
    if len < 0.55 and not sprint then top = min(top, 2.0) end
    local tx, tz = mx * top, mz * top
    local k = 1 - math.exp(-dt * 10)
    p.vx = p.vx + (tx - p.vx) * k
    p.vz = p.vz + (tz - p.vz) * k
    local nx, nz = p.x + p.vx * dt, p.z + p.vz * dt
    nx, nz = W.collide(lv, nx, nz, 0.36)
    nx, nz = W.collide(lv, nx, nz, 0.36)
    p.x, p.z = nx, nz
    speed = sqrt(p.vx * p.vx + p.vz * p.vz)
    if speed > 0.3 then
      local target = atan(p.vx, p.vz)
      p.yaw = p.yaw + angleDiff(target, p.yaw) * min(1, dt * 12)
    end
    p.sneak = sneak
    -- noise: running is heard by drones nearby
    p.noise = (sprint and speed > 3) and 6.5 or (speed > 2.5 and 3.0 or 0)
    p.step = p.step + speed * dt
    if p.step > (sprint and 1.5 or 1.2) then
      p.step = 0
      if not sneak then F.sound("step", sprint and 0.35 or 0.2) end
    end
  else
    p.deadT = p.deadT + dt
  end
  local m = W.models.hero
  if p.machine and m then
    p.machine:set("speed", speed)
    p.machine:set("grounded", true)
    p.machine:set("vy", 0)
    local cmd = p.machine:update(dt)
    if cmd then m:play(cmd.clip, {loop = cmd.loop, speed = cmd.speed, fade = cmd.fade}) end
    m:update(dt)
  end
end

-- ---------------------------------------------------------------- drones and sentries
function A.sees(e, p)
  return W.los(S.level, e.x, e.z, p.x, p.z)
end

function A.spawnDrone(def)
  local path = {}
  for i, c in ipairs(def.path) do
    local x, z = W.cellCenter(c[1], c[2])
    path[i] = {x = x, z = z}
  end
  local d = {isEnemy = true, isDrone = true, x = path[1].x, z = path[1].z, y = 2.0, yaw = 0, aimYaw = nil, path = path,
             wp = 2, speed = def.speed or 2, armed = def.armed, sus = 0, hunting = false, lvx = 0, lvz = 0, touchR = 1.0,
             phase = random() * 6, hum = random(), cool = 0, needLos = true}
  local n = path[2] or path[1]
  d.yaw = atan(n.x - d.x, n.z - d.z)
  d.guard = L.attachBehaviour(d, "guard_alert", {speed = 3.4, msg = "alert", time = 9}, true)
  if d.armed then d.gun = L.attachBehaviour(d, "aim_fire", {range = 8, cooldown = 1.9, speed = 11}, true) end
  A.drones[#A.drones + 1] = d
  return d
end

function A.spawnSentry(x, z, yaw)
  local s = {isEnemy = true, isSentry = true, x = x, z = z, y = 1.9, yaw = yaw or 0, baseYaw = yaw or 0, needLos = true,
             touchR = 0.9, sus = 0}
  s.gun = L.attachBehaviour(s, "aim_fire", {range = 9, cooldown = 1.6, speed = 11}, true)
  s.alarm = L.attachBehaviour(s, "guard_alarm", {range = 7, msg = "alert", calm = 6}, true)
  A.sentries[#A.sentries + 1] = s
  return s
end

-- door machines and switches as Logic objects
function A.attachDoor(d)
  d.door = d
  if d.kind == "L" then
    L.attachBehaviour(d, "door_key", {var = "key", need = 1, near = 2.6, sound = "door"}, true)
  elseif d.kind == "S" then L.attach(d, doorMachine("shutter"))
  elseif d.kind == "G" then L.attach(d, doorMachine("gate_open", "gate_close", 3.2))
  elseif d.kind == "Q" then L.attach(d, doorMachine("power"))
  elseif d.kind == "Y" then L.attach(d, doorMachine("code"))
  end
  if d.kind ~= "D" and d.kind ~= "X" then d.forced = false end
end

function A.attachThing(t)
  if t.k == "l" then
    t.touchR = 2.1
    t.logic = L.attachBehaviour(t, "lever", {on = "shutter", off = "shutter"}, true)
  elseif t.k == "p" then
    t.touchR = 0.9
    t.logic = L.attachBehaviour(t, "pressure_plate", {on = "gate_open", off = "gate_close", who = "@player"}, true)
  elseif t.k == "c" then
    t.touchR = 2.1
    t.logic = L.attachBehaviour(t, "checkpoint_save", {text = "checkpoint", sound = "save"}, true)
  end
end

local VIEW_R, VIEW_HALF = 8.5, math.rad(34)

-- one frame of every enemy
function A.updateEnemies(dt)
  local lv, p = S.level, S.player
  W.flow(lv, p.x, p.z)
  local maxSus = 0
  for _, d in ipairs(A.drones) do
    d.hunting = d.guard and L.stateOf(d.guard) == "hunt"
    if d.keyart then d.sus = 0 end
    -- senses: the vision cone and the noise of a running hero
    local dx, dz = p.x - d.x, p.z - d.z
    local dist = sqrt(dx * dx + dz * dz)
    local seen = false
    if not p.dead and not p.ghost then
      local range = p.sneak and VIEW_R * 0.7 or VIEW_R
      if dist < range and abs(angleDiff(atan(dx, dz), d.yaw)) < VIEW_HALF and W.los(lv, d.x, d.z, p.x, p.z) then
        seen = true
      elseif dist < p.noise and W.los(lv, d.x, d.z, p.x, p.z) then
        seen = true
        d.sus = max(d.sus, 0.35)
      elseif dist < 1.6 then
        seen = true
      end
    end
    d.seen = seen
    if seen and not d.hunting then
      local rate = 0.55 + 1.6 * (1 - min(1, dist / VIEW_R))
      d.sus = min(1, d.sus + rate * dt)
      if d.sus >= 1 then
        L.send("alert", "@enemy", d)
        d.sus = 1
        S.alarm = max(S.alarm, 10)
        F.sound3("alarm", d.x, d.z, 0.9, 30)
        F.sound("spot", 0.8)
      end
    else
      d.sus = max(0, d.sus - dt * (d.hunting and 0 or 0.35))
    end
    if d.hunting then d.sus = 1 end
    maxSus = max(maxSus, d.sus)
    -- movement
    local tx, tz, sp
    if d.hunting then
      local fx, fz = W.flowTarget(lv, d.x, d.z)
      if seen or not fx then fx, fz = p.x, p.z end
      tx, tz, sp = fx, fz, 3.4
    elseif d.sus > 0.3 then
      tx, tz, sp = d.x, d.z, 0  -- stop and look
      d.yaw = d.yaw + angleDiff(atan(dx, dz), d.yaw) * min(1, dt * 2.5)
    elseif d.keyart then
      tx, tz, sp = d.x, d.z, 0
    else
      local w = d.path[d.wp]
      if (w.x - d.x) ^ 2 + (w.z - d.z) ^ 2 < 0.09 then
        d.wp = d.wp % #d.path + 1
        w = d.path[d.wp]
      end
      tx, tz, sp = w.x, w.z, d.speed
    end
    local mx, mz = tx - d.x, tz - d.z
    local ml = sqrt(mx * mx + mz * mz)
    if ml > 0.05 and sp > 0 then
      local want = atan(mx, mz)
      d.yaw = d.yaw + angleDiff(want, d.yaw) * min(1, dt * (d.hunting and 6 or 3.2))
      local step = min(ml, sp * dt)
      local fx, fz = sin(d.yaw), cos(d.yaw)
      local nx, nz = d.x + fx * step, d.z + fz * step
      nx, nz = W.collide(lv, nx, nz, 0.45, true)
      d.x, d.z = nx, nz
    end
    -- contact: a hunting drone zaps the hero and backs off
    d.cool = max(0, d.cool - dt)
    if d.hunting and dist < 1.0 and d.cool <= 0 and not p.dead then
      A.hurt(1)
      d.cool = 1.6
      d.x, d.z = d.x - dx / max(dist, 0.1) * 0.8, d.z - dz / max(dist, 0.1) * 0.8
      p.vx, p.vz = p.vx + dx / max(dist, 0.1) * 5, p.vz + dz / max(dist, 0.1) * 5
    end
    d.y = 2.0 + sin(S.t * 2.1 + d.phase) * 0.08
    -- the hum of the rotors
    d.hum = d.hum - dt
    if d.hum <= 0 then d.hum = 1.5; F.sound3("drone", d.x, d.z, 0.5, 11) end
  end
  for _, s in ipairs(A.sentries) do
    local dx, dz = p.x - s.x, p.z - s.z
    local dist = sqrt(dx * dx + dz * dz)
    local sees = dist < 9 and not p.dead and not p.ghost and W.los(lv, s.x, s.z, p.x, p.z)
    if sees then
      s.yaw = s.yaw + angleDiff(atan(dx, dz), s.yaw) * min(1, dt * 4)
      s.sus = min(1, s.sus + dt)
    else
      s.yaw = s.baseYaw + sin(S.t * 0.6 + s.x) * 1.1
      s.sus = max(0, s.sus - dt * 0.5)
    end
    maxSus = max(maxSus, s.sus * 0.8)
    if s.alarm and L.stateOf(s.alarm) == "alarm" and S.alarm < 1 then
      S.alarm = 8
      F.sound3("alarm", s.x, s.z, 0.9, 30)
    end
  end
  S.alert = maxSus
  -- bolts
  local n = 0
  for i = 1, #A.bolts do
    local b = A.bolts[i]
    b.life = b.life - dt
    b.x, b.z = b.x + b.vx * dt, b.z + b.vz * dt
    local c, r = W.cellAt(b.x, b.z)
    local hit = false
    if W.blocksSight(lv, c, r) then hit = true; F.sparks(b.x, b.y, b.z, 10) end
    if not hit and not p.dead and (b.x - p.x) ^ 2 + (b.z - p.z) ^ 2 < 0.45 * 0.45 then
      hit = true
      A.hurt(1)
    end
    if b.life > 0 and not hit then n = n + 1; A.bolts[n] = b end
  end
  for i = #A.bolts, n + 1, -1 do A.bolts[i] = nil end
end

function A.reset()
  L.reset()
  A.drones, A.sentries, A.bolts = {}, {}, {}
  A.shake = 0
end

return A
