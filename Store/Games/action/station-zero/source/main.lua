-- Station Zero
-- A third-person stealth and escape game on a dead orbital station. Restore the reactor, crack the bridge lockdown
-- and reach the escape pod while security drones sweep the decks.
--
-- Built on Nexvyn OS SDK 1.9 (pbr renderer) with Game Engine 2 parts: Logic 2.0 behaviours (nexvyn.ge_logic), the
-- base hero and its locomotion machine (nexvyn.ge_character), camera rails (nexvyn.ge_anim) and Sound 2.0 recipes and
-- music stems rendered by tools/stationzero_audio.cpp. Art direction: docs/games/stationzero_art.md (source repo).
local app = {}

local S = require("sz.state")
local F = require("sz.fx")
local W = require("sz.world")
local A = require("sz.actors")
local T = require("sz.term")
local LV = require("sz.levels")
local L = require("nexvyn.ge_logic")
local Anim = require("nexvyn.ge_anim")

local sqrt, sin, cos, atan, min, max, abs, pi, floor, random =
  math.sqrt, math.sin, math.cos, math.atan, math.min, math.max, math.abs, math.pi, math.floor, math.random
local C = S.C

local state = "boot"       -- boot, title, howto, intro, play, pause, term, dead, exit, launch, ending
local sel = 1
local rects = {}
local held = {}
local touch = {stick = nil, look = nil}
local usingTouch = false
local Wd, Hd = 1280, 720
local cam = {yaw = 0, pitch = 0.3, x = 0, y = 2, z = 0, tx = 0, ty = 1.4, tz = 0, fov = 58}
local rail = nil           -- the running camera rail player
local fade, fadeTo = 1, 0  -- black overlay 0..1
local pending = nil        -- function to run when the fade is black
local stateT = 0
local renderer = "basic"
local neon, coneMesh, keyMesh, boltMesh, glowBall, ringMesh, coreMesh, handleMesh, holoCone, shaftMesh
local bootText = 0
local demo = nil           -- screenshot vantage from the launch argument ("demo:<level>:<vantage>")
local runStats = {alarms = 0, time = 0}
local interact = nil       -- the thing the use button would act on
local logs = {}            -- digit index per hologram thing
local countdown = nil
local launchT = 0

-- ---------------------------------------------------------------- save
local function loadSave()
  local ok, s = pcall(store.get, "sz_save", nil)
  if ok and type(s) == "table" and type(s.level) == "number" then return s end
  return nil
end
local function writeSave(s)
  S.save = s
  pcall(store.set, "sz_save", s)
  pcall(store.save)
end
local function newCode()
  local c = ""
  for _ = 1, 4 do c = c .. tostring(random(0, 9)) end
  return c
end

-- ---------------------------------------------------------------- level flow
local function copy(t) local o = {}; for k, v in pairs(t or {}) do o[k] = v end; return o end

local function setNeon(col)
  if neon and renderer == "pbr" then pcall(g3d.material, neon, {emissive = col, emissiveStrength = 3.2}) end
end

local function cellPos(c, r, h)
  local x, z = W.cellCenter(c, r)
  return {x, h, z}
end

local function startLevel(n, resume)
  local def = LV[n]
  S.levelIndex = n
  A.reset()
  F.init()
  F.lightsReset()
  S.level = W.build(def)
  local lv = S.level
  S.vars = {key = resume and S.save and S.save.key or 0}
  S.vars.hadKey = S.vars.key
  S.sent = {}
  S.alarm, S.alert = 0, 0
  T.open = false
  logs = {}
  local hn = 0
  for _, d in ipairs(lv.doors) do A.attachDoor(d) end
  for _, t in ipairs(lv.things) do
    A.attachThing(t)
    if t.k == "W" then A.spawnSentry(t.x, t.z, t.yaw + pi) end
    if t.k == "H" then
      hn = hn + 1
      logs[t] = n == 1 and 1 or (n == 2 and 2 or (n == 3 and (2 + hn) or nil))
    end
  end
  for _, dd in ipairs(def.drones or {}) do A.spawnDrone(dd) end
  local sx, sz = lv.start.x, lv.start.z
  if resume and S.save and S.save.cp then sx, sz = S.save.cp.x, S.save.cp.z end
  A.newPlayer(sx, sz, pi / 2)
  if resume and S.save and S.save.sent then
    for _, m in ipairs(S.save.sent) do
      L.send(m, "@all")
      S.sent[#S.sent + 1] = m
      if m == "power" then lv.powered = true end
    end
  end
  cam.yaw = S.player.yaw
  cam.x, cam.z = sx - sin(cam.yaw) * 3, sz - cos(cam.yaw) * 3
  countdown = def.countdown
  if def.alarm then S.alarm = 1e9 end
  setNeon(def.alarm and C.red or C.cyan)
  F.music(def.music == "danger" and "calm" or def.music)
  F.danger(def.alarm and true or false)
  -- the opening fly-through ends behind the hero
  rail = nil
  if not resume and def.rail then
    local pts = {}
    for i, p in ipairs(def.rail) do
      pts[i] = {pos = cellPos(p.pos[1], p.pos[2], p.pos[3]), look = cellPos(p.look[1], p.look[2], p.look[3]), fov = p.fov}
    end
    local fx, fz = sin(cam.yaw), cos(cam.yaw)
    pts[#pts + 1] = {pos = {sx - fx * 3.4, 2.4, sz - fz * 3.4}, look = {sx + fx * 2, 1.4, sz + fz * 2}, fov = 58}
    rail = Anim.railPlayer(Anim.rail({duration = 7.5, ease = "ease", points = pts}))
    rail.play()
  end
  state = rail and "intro" or "play"
  stateT = 0
  fadeTo = 0
end

local function progress(level, cp)
  local s = S.save or {}
  s.level, s.cp = level, cp
  s.sent = cp and copy(S.sent) or {}
  s.key = cp and (S.vars.key or 0) or 0
  writeSave(s)
end

S.onCheckpoint = function(e)
  -- respawn on a free cell next to the station
  local lv = S.level
  local c, r = W.cellAt(e.x, e.z)
  local best
  for _, d in ipairs({{0, 1}, {1, 0}, {-1, 0}, {0, -1}}) do
    if not best and not W.solidCell(lv, c + d[1], r + d[2]) then best = {W.cellCenter(c + d[1], r + d[2])} end
  end
  best = best or {e.x, e.z}
  progress(S.levelIndex, {x = best[1], z = best[2]})
end

local function fadeThen(fn)
  pending, fadeTo = fn, 1
end

local function newGame()
  writeSave({level = 1, code = newCode(), digits = {}, sent = {}, key = 0, alarms = 0})
  runStats = {alarms = 0, time = 0}
  fadeThen(function() startLevel(1, false) end)
end

local function continueGame()
  local s = loadSave()
  if not s then newGame() return end
  S.save = s
  s.code = s.code or newCode()
  s.digits = s.digits or {}
  fadeThen(function() startLevel(s.level, s.cp ~= nil) end)
end

local function levelDone()
  local n = S.levelIndex
  F.sound("win", 0.6)
  if n >= #LV then return end
  progress(n + 1, nil)
  fadeThen(function() startLevel(n + 1, false) end)
end

-- ---------------------------------------------------------------- title backdrop
local function titleScene()
  A.reset()
  F.init()
  F.lightsReset()
  S.level = W.build(LV[3])
  for _, d in ipairs(S.level.doors) do A.attachDoor(d) end
  for i, dd in ipairs(LV[3].drones) do if i <= 2 then A.spawnDrone(dd) end end
  A.newPlayer(-50, -50, 0)
  S.player.dead = true
  S.alarm = 0
  setNeon(C.cyan)
end

-- ---------------------------------------------------------------- app
function app.load(arg)
  math.randomseed(floor((sys.time() or 0) * 1000) % 100000)
  if type(arg) == "string" then
    local lvl, v = arg:match("^demo:(%d+):?(%w*)")
    if lvl then demo = {level = tonumber(lvl), v = v, opt = arg:match("^demo:%d+:%w*:(%w+)")} end
  end
  local opt = type(arg) == "string" and arg:match("^demo:%d+:%w*:(%w+)") or ""
  local okR, r = pcall(g3d.renderer, opt == "basic" and "basic" or "pbr")
  renderer = okR and r or "basic"
  if renderer == "pbr" then
    pcall(g3d.shadows, opt == "s0" and false or {quality = opt == "sl" and "low" or "medium", distance = 22, bias = 1.2})
    pcall(g3d.postfx, {exposure = 0.95, tonemap = "aces", bloom = opt == "b0" and 0 or 0.09, threshold = 0.9, msaa = opt == "m2" and 2 or 0,
                       hdr = opt ~= "h0"})
    pcall(g3d.environment, {sky = "#25313D", ground = "#0B0E12", intensity = 0.3, sun = 1.4})
  end
  -- glowing pieces made here (emissive above 1 blooms)
  neon = g3d.mesh("box", 1.96, 0.035, 0.04)
  neon:setColor(C.cyan)
  W.models.neon = neon
  setNeon(C.cyan)
  keyMesh = g3d.mesh("box", 0.34, 0.025, 0.22)
  keyMesh:setColor(C.amber)
  boltMesh = g3d.mesh("box", 0.07, 0.07, 0.7)
  boltMesh:setColor("#FF4B4B")
  glowBall = g3d.mesh("sphere", 0.5, 14, 8)
  glowBall:setColor("#FFFFFF")
  ringMesh = g3d.mesh("torus", 0.62, 0.05, 28, 6)
  ringMesh:setColor(C.amber)
  coreMesh = g3d.mesh("sphere", 1.0, 28, 18)
  coreMesh:setColor("#BFF4FF")
  shaftMesh = g3d.mesh("cylinder", 3.1, 7, 28)
  handleMesh = g3d.mesh("box", 0.08, 0.5, 0.08)
  handleMesh:setColor(C.amber)
  if renderer == "pbr" then
    pcall(g3d.material, keyMesh, {emissive = C.amber, emissiveStrength = 2.5, metallic = 0.6, roughness = 0.3})
    pcall(g3d.material, boltMesh, {emissive = "#FF3030", emissiveStrength = 5})
    pcall(g3d.material, ringMesh, {emissive = C.amber, emissiveStrength = 2.2})
    pcall(g3d.material, coreMesh, {emissive = "#9FEAFF", emissiveStrength = 4})
    pcall(g3d.material, handleMesh, {emissive = C.amber, emissiveStrength = 2})
  end
  -- the drones' vision cone: apex at the eye, 8.5 m long, additive with a fading edge
  do
    local V, I, Cc = {0, 0, 0}, {}, {{120, 120, 120}}
    local seg, len, rad = 18, 8.5, 8.5 * math.tan(math.rad(30))
    for i = 0, seg - 1 do
      local a = i / seg * 2 * pi
      V[#V + 1], V[#V + 2], V[#V + 3] = cos(a) * rad, sin(a) * rad, len
      Cc[#Cc + 1] = {6, 6, 6}
    end
    for i = 0, seg - 1 do
      I[#I + 1], I[#I + 2], I[#I + 3] = 1, 2 + i, 2 + (i + 1) % seg
    end
    coneMesh = g3d.custom(V, I, Cc)
    -- the hologram light beam: an upward cone
    local V2, I2, C2 = {0, 0, 0}, {}, {{90, 220, 255}}
    for i = 0, seg - 1 do
      local a = i / seg * 2 * pi
      V2[#V2 + 1], V2[#V2 + 2], V2[#V2 + 3] = cos(a) * 0.45, 1.4, sin(a) * 0.45
      C2[#C2 + 1] = {0, 10, 16}
    end
    for i = 0, seg - 1 do I2[#I2 + 1], I2[#I2 + 2], I2[#I2 + 3] = 1, 2 + i, 2 + (i + 1) % seg end
    holoCone = g3d.custom(V2, I2, C2)
    -- light shafts under the big rooms' ceiling lamps: a faint additive cone, bright at the lamp, gone at the floor
    local V3, I3, C3 = {}, {}, {}
    for i = 0, seg - 1 do
      local a = i / seg * 2 * pi
      V3[#V3 + 1], V3[#V3 + 2], V3[#V3 + 3] = cos(a) * 0.42, 0, sin(a) * 0.42
      C3[#C3 + 1] = {17, 22, 28}
    end
    for i = 0, seg - 1 do
      local a = i / seg * 2 * pi
      V3[#V3 + 1], V3[#V3 + 2], V3[#V3 + 3] = cos(a) * 1.5, -2.9, sin(a) * 1.5
      C3[#C3 + 1] = {0, 0, 0}
    end
    for i = 0, seg - 1 do
      local j = (i + 1) % seg
      I3[#I3 + 1], I3[#I3 + 2], I3[#I3 + 3] = 1 + i, 1 + seg + i, 1 + j
      I3[#I3 + 1], I3[#I3 + 2], I3[#I3 + 3] = 1 + j, 1 + seg + i, 1 + seg + j
    end
    W.models.shaft = g3d.custom(V3, I3, C3)
  end
  -- Logic library: the behaviours the game uses, read from the bundled copy of the Game Engine catalogue
  local ok, txt = pcall(fs.read, "bundle:/data/behaviours.json")
  local lib = ok and txt and json.decode(txt) or {}
  A.setup(lib.behaviours or lib)
  S.save = loadSave()
  local okv, vol = pcall(store.get, "sz_volume", 1)
  F.volume = okv and tonumber(vol) or 1
  W.load(function()
    -- the viewports' glass lets space through (thin glass, refraction of the scene behind it)
    if renderer == "pbr" and W.models.viewport then
      pcall(g3d.material, W.models.viewport, {transmission = 0.92, roughness = 0.05, metallic = 0}, "M_KSI_S1_Glass")
    end
    -- the wall emergency lamps glow red, softly, until an alarm makes them pulse
    if renderer == "pbr" and W.models.elamp then
      pcall(g3d.material, W.models.elamp, {emissive = "#FF2A2A", emissiveStrength = 0.5})
    end
    if demo then
      writeSave(S.save or {level = 1, code = "4719", digits = {true, true, false, false}, sent = {}, key = 0})
      S.save.code = S.save.code or "4719"
      startLevel(demo.level, false)
      rail = nil
      state = "play"
      fade, fadeTo = 0, 0
      local spot = LV[demo.level].hero
      if spot and (demo.v == "h" or demo.v == "a" or demo.v == "t") then
        local x, z = W.cellCenter(spot[1], spot[2])
        S.player.x, S.player.z, S.player.yaw = x, z, spot[3]
        cam.yaw = spot[3]
        cam.x, cam.z = x - sin(cam.yaw) * 3, z - cos(cam.yaw) * 3
      end
      -- screenshot runs: the drones do not see the hero, except in the alarm vantage
      if demo.v ~= "a" then S.player.ghost = true end
      if demo.v == "k" then
        -- key art: no HUD, the hero out of frame, one drone hunting straight at the camera
        S.noHud = true
        S.player.x, S.player.z = -50, -50
        S.alarm = 1e9
        setNeon(C.red)
        local d = A.drones[1]
        if d then
          d.x, d.z = W.cellCenter(24.3, 4.6)
          d.path, d.wp, d.speed, d.keyart = {{x = d.x, z = d.z}}, 1, 0, true
          local cx, cz = W.cellCenter(27.4, 4.4)
          d.yaw = atan(cx - d.x, cz - d.z)
        end
        demo.v = "4"
      end
      if demo.v == "a" then
        L.send("alert", "@enemy")
        S.alarm = 12
      elseif demo.v == "t" then
        state = "term"
        T.start(demo.level == 3 and "code" or "power", S.save.code)
      end
    else
      titleScene()
      state = "title"
      F.music("title")
      fadeTo = 0
    end
  end)
end

-- ---------------------------------------------------------------- input
local KEYMAP = {enter = "a", space = "a", e = "a", escape = "back", backspace = "b", p = "plus", up = "up", down = "down",
                left = "left", right = "right", w = "up", s = "down", a = "left", d = "right"}

local function menuItems()
  if state == "title" then
    local t = {}
    if S.save then t[#t + 1] = "continue" end
    t[#t + 1] = "new_game"
    t[#t + 1] = "controls"
    t[#t + 1] = "sound"
    t[#t + 1] = "quit"
    return t
  elseif state == "pause" then return {"resume", "restart_cp", "sound", "to_title"} end
  return {}
end

local function activate(id)
  F.sound("ok", 0.6)
  if id == "continue" then continueGame()
  elseif id == "new_game" then newGame()
  elseif id == "controls" then state = "howto"
  elseif id == "sound" then
    F.volume = F.volume > 0.6 and 0.5 or (F.volume > 0.2 and 0 or 1)
    pcall(store.set, "sz_volume", F.volume)
    if F.volume == 0 then F.stopAll() else F.music(state == "title" and "title" or "calm") end
  elseif id == "quit" then F.stopAll(); sys.exit()
  elseif id == "resume" then state = "play"
  elseif id == "restart_cp" then fadeThen(function() startLevel(S.levelIndex, S.save and S.save.cp ~= nil) end)
  elseif id == "to_title" then
    fadeThen(function() F.danger(false); titleScene(); state = "title"; sel = 1; F.music("title") end)
  end
end

local function pause()
  if state == "play" then state, sel = "pause", 1; touch.stick, touch.look = nil, nil end
end

local function press(name)
  if fadeTo == 1 then return end
  if state == "term" then T.input(name); return end
  if state == "intro" then
    if name == "a" or name == "b" or name == "plus" or name == "back" then rail = nil; state = "play" end
    return
  end
  if state == "play" then
    if name == "plus" or name == "back" then pause()
    elseif name == "a" then app.use() end
    return
  end
  if state == "howto" then
    if name == "a" or name == "b" or name == "back" then state = "title" end
    return
  end
  if state == "ending" then
    if stateT > 3 and (name == "a" or name == "b" or name == "plus" or name == "back") then
      fadeThen(function() titleScene(); state = "title"; sel = 1; F.music("title") end)
    end
    return
  end
  local list = menuItems()
  if #list == 0 then return end
  if name == "up" then sel = (sel - 2) % #list + 1; F.sound("tick", 0.4)
  elseif name == "down" then sel = sel % #list + 1; F.sound("tick", 0.4)
  elseif name == "a" then activate(list[sel])
  elseif state == "pause" and (name == "plus" or name == "b" or name == "back") then state = "play" end
end

function app.event(e)
  if e.type == "paddown" and e.pad then usingTouch = false; press(e.pad)
  elseif e.type == "keydown" and e.key then
    usingTouch = false
    held[e.key] = true
    if state == "term" and e.key:match("^%d$") then T.input(e.key) return end
    if KEYMAP[e.key] then
      local k = KEYMAP[e.key]
      if state == "play" and (e.key == "w" or e.key == "a" or e.key == "s" or e.key == "d") then return end
      press(k)
    end
  elseif e.type == "keyup" and e.key then held[e.key] = nil
  elseif e.type == "mousedown" then
    local x, y = e.x or 0, e.y or 0
    usingTouch = true
    if state == "term" then T.tap(x, y) return end
    if state == "play" then
      if x > Wd - 90 and y < 90 then pause()
      elseif x > Wd - 200 and y > Hd - 200 then app.use()
      elseif x < Wd * 0.45 then touch.stick = {x0 = x, y0 = y, x = x, y = y}
      else touch.look = {x = x, y = y} end
      return
    end
    if state == "intro" then rail = nil; state = "play" return end
    if state == "howto" then state = "title" return end
    if state == "ending" then press("a") return end
    for i, r in ipairs(rects) do
      if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then sel = i; activate(menuItems()[i]); return end
    end
  elseif e.type == "mousemove" then
    if touch.stick then touch.stick.x, touch.stick.y = e.x or touch.stick.x, e.y or touch.stick.y end
    if touch.look then
      local nx = e.x or touch.look.x
      cam.yaw = cam.yaw - (nx - touch.look.x) * 0.006
      touch.look.x = nx
    end
  elseif e.type == "mouseup" then touch.stick, touch.look = nil, nil end
end

-- the use button: pick up, read, open a terminal, board the pod (levers and plates are Logic machines)
function app.use()
  A.usePressed = true
  local t = interact
  if not t then return end
  local p = S.player
  if t.k == "K" and not t.taken then
    t.taken = true
    S.vars.key = (S.vars.key or 0) + 1
    S.vars.hadKey = 1
    F.sound("key", 0.9)
    S.say(TR("got_key"))
    F.burst(t.x, 1.1, t.z)
  elseif t.k == "H" and not t.read then
    t.read = true
    local i = logs[t]
    if i and S.save then
      S.save.digits = S.save.digits or {}
      S.save.digits[i] = true
      writeSave(S.save)
      S.say(TR("log_read", i, S.save.code:sub(i, i)), 5)
    end
    F.sound("beep", 0.8)
  elseif t.k == "T" then
    if S.levelIndex == 2 and not S.level.powered then
      state = "term"; T.start("power")
    elseif S.levelIndex == 3 and not S.level.unlocked then
      state = "term"; T.start("code", S.save and S.save.code or "0000")
    else
      F.sound("beep", 0.5)
    end
  elseif t.k == "E" then
    state, launchT = "launch", 0
    F.sound("launch", 1)
    F.danger(false)
    local lv = S.level
    local pts = {
      {pos = {lv.pod.x + 7, 3.5, lv.pod.z - 4}, look = {lv.pod.x, 1.5, lv.pod.z}, fov = 55},
      {pos = {lv.pod.x + 4, 6, lv.pod.z - 9}, look = {lv.pod.x, 0, lv.pod.z + 2}, fov = 62},
      {pos = {lv.pod.x, 12, lv.pod.z - 16}, look = {lv.pod.x, -8, lv.pod.z + 6}, fov = 70},
    }
    rail = Anim.railPlayer(Anim.rail({duration = 6, ease = "ease", points = pts}))
    rail.play()
  end
  local _ = p
end

-- ---------------------------------------------------------------- update
local function moveInput()
  local sx, sy = 0, 0
  local ok, x, y = pcall(input.stick, "left")
  if ok and x then sx, sy = x, y end
  if held.a or held.left or input.down("left") then sx = -1 end
  if held.d or held.right or input.down("right") then sx = 1 end
  if held.w or held.up or input.down("up") then sy = 1 end
  if held.s or held.down or input.down("down") then sy = -1 end
  if touch.stick then
    local dx, dy = touch.stick.x - touch.stick.x0, touch.stick.y - touch.stick.y0
    local l = sqrt(dx * dx + dy * dy)
    if l > 10 then sx, sy = dx / max(l, 70), -dy / max(l, 70) end
  end
  local l = sqrt(sx * sx + sy * sy)
  if l > 1 then sx, sy = sx / l, sy / l end
  -- camera space: forward (sin yaw, cos yaw), right (-cos yaw, sin yaw)
  local fx, fz = sin(cam.yaw), cos(cam.yaw)
  local rx, rz = -cos(cam.yaw), sin(cam.yaw)
  return fx * sy + rx * sx, fz * sy + rz * sx
end

local function nearestInteract()
  local p, best, bd = S.player, nil, 1.9 * 1.9
  for _, t in ipairs(S.level.things) do
    if (t.k == "K" and not t.taken) or (t.k == "H" and not t.read) or t.k == "T" or t.k == "l" then
      local d = (t.x - p.x) ^ 2 + (t.z - p.z) ^ 2
      if d < bd then best, bd = t, d end
    end
  end
  local lv = S.level
  if lv.pod then
    local d = (lv.pod.x - p.x) ^ 2 + (lv.pod.z - 3.2 - p.z) ^ 2
    if d < 2.6 * 2.6 then best = {k = "E", x = lv.pod.x, z = lv.pod.z - 2.6} end
  end
  return best
end

local function updateCamera(dt)
  local p = S.player
  local okr, rx, ry = pcall(input.stick, "right")
  if okr and rx then
    if abs(rx) > 0.15 then cam.yaw = cam.yaw - rx * dt * 2.6 end
    if abs(ry) > 0.2 then cam.pitch = max(0.08, min(0.75, cam.pitch - ry * dt * 1.2)) end
  end
  if held.j or held.q then cam.yaw = cam.yaw + dt * 2.2 end
  if held.l or held.o then cam.yaw = cam.yaw - dt * 2.2 end
  -- gentle auto-follow behind the hero while running
  local speed = sqrt(p.vx * p.vx + p.vz * p.vz)
  if speed > 2 and not touch.look and not (okr and rx and abs(rx) > 0.15) then
    local want = atan(p.vx, p.vz)
    local d = (want - cam.yaw + pi) % (2 * pi) - pi
    if abs(d) < 2.2 then cam.yaw = cam.yaw + d * min(1, dt * 0.9) end
  end
  local fx, fz = sin(cam.yaw), cos(cam.yaw)
  local rxv, rzv = -cos(cam.yaw), sin(cam.yaw)
  local tx, ty, tz = p.x + rxv * 0.55, 1.55, p.z + rzv * 0.55
  local dist = 3.5
  local wantX = tx - fx * dist * cos(cam.pitch)
  local wantZ = tz - fz * dist * cos(cam.pitch)
  local wantY = ty + dist * sin(cam.pitch)
  -- pull in when a wall is between the hero and the camera
  local lv = S.level
  local steps = 14
  local okX, okZ, okY = tx, tz, ty
  for i = 1, steps do
    local f = i / steps
    local x, z = tx + (wantX - tx) * f, tz + (wantZ - tz) * f
    local c, r = W.cellAt(x, z)
    if W.solidCell(lv, c, r, true) or W.blocksSight(lv, c, r) then break end
    okX, okZ, okY = x, z, ty + (wantY - ty) * f
  end
  -- keep a little off the wall we stopped at
  okX, okZ = tx + (okX - tx) * 0.92, tz + (okZ - tz) * 0.92
  okY = min(okY, S.WALL_H - 0.3)
  local k = 1 - math.exp(-dt * 10)
  cam.x, cam.y, cam.z = cam.x + (okX - cam.x) * k, cam.y + (okY - cam.y) * k, cam.z + (okZ - cam.z) * k
  cam.tx, cam.ty, cam.tz = tx + fx * 1.5, ty - 0.1, tz + fz * 1.5
  cam.fov = 58 + min(6, speed * 1.2)
end

local function world(dt)
  local lv = S.level
  local p = S.player
  L.update(dt)
  A.usePressed = false
  A.updateEnemies(dt)
  W.updateDoors(lv, dt, function(x, z, r)
    if not p.dead and (p.x - x) ^ 2 + (p.z - z) ^ 2 < r * r then return true end
    for _, d in ipairs(A.drones) do if (d.x - x) ^ 2 + (d.z - z) ^ 2 < (r - 0.5) ^ 2 then return true end end
    return false
  end)
  -- ambient effects
  for _, t in ipairs(lv.things) do
    if t.k == "x" then
      t.spark = t.spark - dt
      if t.spark <= 0 then
        t.spark = 0.6 + random() * 2.2
        F.sparks(t.x, 1.0, t.z, 10 + random(8))
        F.sound3("spark", t.x, t.z, 0.6, 10)
      end
    elseif t.k == "v" then
      t.steam = t.steam - dt
      if t.steam <= 0 then t.steam = 0.12; F.steam(t.x, 0.05, t.z, 1) end
    elseif t.k == "H" and not t.read then
      if random() < dt * 8 then F.holo(t.x, 0.8, t.z) end
    end
  end
  F.update(dt)
  if S.alarm > 0 and S.alarm < 1e8 then
    S.alarm = max(0, S.alarm - dt)
  end
end

local wasAlarm = false
-- frame timing for the performance log (demo runs only): mean and worst frame, CPU time of update + draw
local perf = {n = 0, sum = 0, worst = 0, cpu = 0, t = 0, sub = 0, fin = 0, upd = 0}
local function perfFrame(rawDt, cpu)
  if not demo then return end
  perf.n, perf.sum, perf.worst, perf.cpu, perf.t = perf.n + 1, perf.sum + rawDt, max(perf.worst, rawDt), perf.cpu + cpu, perf.t + rawDt
  if perf.t >= 4 then
    print(string.format("SZPERF level=%d frames=%d mean_ms=%.2f worst_ms=%.2f cpu_ms=%.2f update_ms=%.2f submit_ms=%.2f finish_ms=%.2f quality=%s",
                        S.levelIndex, perf.n, perf.sum / perf.n * 1000, perf.worst * 1000, perf.cpu / perf.n * 1000,
                        perf.upd / perf.n * 1000, perf.sub / perf.n * 1000, perf.fin / perf.n * 1000, S.quality))
    perf.n, perf.sum, perf.worst, perf.cpu, perf.t, perf.sub, perf.fin, perf.upd = 0, 0, 0, 0, 0, 0, 0, 0
  end
end
local cpuMark = 0

function app.update(dt)
  local raw = dt or 0.016
  local t0 = sys.time()
  if cpuMark > 0 then perfFrame(raw, cpuMark) end
  cpuMark = 0
  app.updateInner(dt)
  cpuMark = sys.time() - t0
  perf.upd = perf.upd + cpuMark
end

-- ---------------------------------------------------------------- self test ("demo:1:self")
-- Walks the whole game by teleporting the hero from goal to goal and pressing the buttons a player would; every step
-- logs "SZTEST <step> ok|FAIL". Used by tools/stationzero_ryu.py in the emulator.
local selfT, selfStep, selfWait = 0, 1, 0
local function thingOf(k)
  for _, t in ipairs(S.level.things) do if t.k == k then return t end end
end
local function doorOf(k)
  for _, d in ipairs(S.level.doors) do if d.kind == k then return d end end
end
local function near(x, z)
  local lv = S.level
  local c, r = W.cellAt(x, z)
  for _, d in ipairs({{0, 1}, {0, -1}, {1, 0}, {-1, 0}}) do
    if not W.solidCell(lv, c + d[1], r + d[2]) then
      local nx, nz = W.cellCenter(c + d[1], r + d[2])
      return nx, nz
    end
  end
  return x, z
end
local function put(x, z) S.player.x, S.player.z, S.player.vx, S.player.vz = x, z, 0, 0 end
local function log(name, ok) print("SZTEST " .. name .. " " .. (ok and "ok" or "FAIL")) end
local SELF = {
  function() local t = thingOf("K"); put(t.x, t.z); interact = t; app.use(); log("keycard", S.vars.key == 1); return 0.2 end,
  function() local d = doorOf("L"); put(d.x - 1.6, d.z); return 2.0 end,
  function() local d = doorOf("L"); log("keycard door", d.open > 0.8 and S.vars.key == 0); return 0.1 end,
  function() local t = thingOf("l"); put(near(t.x, t.z)); app.use(); return 2.2 end,
  function() log("lever shutter", doorOf("S").open > 0.8); return 0.1 end,
  function() local t = thingOf("H"); put(t.x, t.z); interact = t; app.use(); log("log 1", S.save.digits[1] == true); return 0.1 end,
  function() local t = thingOf("c"); put(near(t.x, t.z)); return 0.6 end,
  function() log("checkpoint", S.save.cp ~= nil and S.save.level == 1); return 0.1 end,
  function() local d = doorOf("X"); put(d.x - 1.4, d.z); return 1.6 end,
  function() local d = doorOf("X"); put(d.x, d.z); return 2.5 end,
  function() log("level 2", S.levelIndex == 2); rail = nil; state = "play"; return 0.5 end,
  function() local t = thingOf("p"); put(t.x, t.z); return 1.4 end,
  function() log("plate gate", doorOf("G").open > 0.8); return 0.1 end,
  function() local t = thingOf("T"); put(near(t.x, t.z)); interact = t; app.use(); log("power terminal opens", state == "term"); return 0.3 end,
  function() T.testSolve(); log("power puzzle", T.done); return 2.0 end,
  function() log("power door", S.level.powered and doorOf("Q").open > 0.8); return 0.1 end,
  function() local d = doorOf("X"); put(d.x - 1.4, d.z); return 1.6 end,
  function() local d = doorOf("X"); put(d.x, d.z); return 2.5 end,
  function() log("level 3", S.levelIndex == 3); rail = nil; state = "play"; return 0.5 end,
  function() local t = thingOf("T"); put(near(t.x, t.z)); interact = t; app.use(); return 0.3 end,
  function()
    for i = 1, 4 do T.input(S.save.code:sub(i, i)) end
    T.testPress(12)
    log("code terminal", T.done); return 2.0
  end,
  function() log("lockdown door", S.level.unlocked and doorOf("Y").open > 0.8); return 0.1 end,
  function() local d = doorOf("X"); put(d.x - 1.4, d.z); return 1.6 end,
  function() local d = doorOf("X"); put(d.x, d.z); return 2.5 end,
  function() log("level 4", S.levelIndex == 4 and countdown ~= nil); rail = nil; state = "play"; return 0.5 end,
  function() local lv = S.level; put(lv.pod.x, lv.pod.z - 2.8); return 0.3 end,
  function() interact = nearestInteract(); app.use(); log("pod launch", state == "launch"); return 8 end,
  function() log("ending", state == "ending"); print("SZTEST done"); return 1e9 end,
}
local function selfTest(dt)
  if not (demo and demo.v == "self") or fadeTo == 1 or pending or not S.level or state == "boot" then return end
  selfWait = selfWait - dt
  if selfWait > 0 or not SELF[selfStep] then return end
  local ok, w = pcall(SELF[selfStep])
  if not ok then print("SZTEST step " .. selfStep .. " error " .. tostring(w)); w = 0.1 end
  selfStep = selfStep + 1
  selfWait = w or 0.1
end

function app.updateInner(dt)
  selfTest(min(dt or 0.016, 0.05))
  dt = min(dt or 0.016, 0.05)
  S.t = S.t + dt
  stateT = stateT + dt
  bootText = bootText + dt
  -- fades
  if fadeTo == 1 then
    fade = min(1, fade + dt * 2.5)
    if fade >= 1 and pending then local f = pending; pending = nil; f(); fadeTo = 0 end
  else
    fade = max(0, fade - dt * 1.6)
  end
  if S.toast then S.toast.t = S.toast.t - dt; if S.toast.t <= 0 then S.toast = nil end end
  if state == "boot" or not S.level then return end
  if state == "title" or state == "howto" then
    -- the bridge backdrop keeps living: drones patrol
    L.update(dt)
    for _, d in ipairs(A.drones) do
      local w = d.path[d.wp]
      local dx, dz = w.x - d.x, w.z - d.z
      local l = sqrt(dx * dx + dz * dz)
      if l < 0.3 then d.wp = d.wp % #d.path + 1 else
        d.yaw = d.yaw + ((atan(dx, dz) - d.yaw + pi) % (2 * pi) - pi) * min(1, dt * 3)
        d.x, d.z = d.x + sin(d.yaw) * d.speed * dt, d.z + cos(d.yaw) * d.speed * dt
      end
      d.y = 2.0 + sin(S.t * 2 + d.phase) * 0.08
    end
    F.update(dt)
    return
  end
  if state == "pause" then return end
  if state == "term" then
    if not T.update(dt) then
      state = "play"
      if T.done then
        local msg = T.kind == "power" and "power" or "code"
        L.send(msg, "@all")
        S.sent[#S.sent + 1] = msg
        if msg == "power" then S.level.powered = true; S.say(TR("power_on"), 4)
        else S.level.unlocked = true; S.say(TR("lockdown_off"), 4) end
        progress(S.levelIndex, S.save and S.save.cp)
      end
    end
    world(dt * 0.25)
    return
  end
  if state == "intro" then
    local playing = rail and rail.update(dt)
    if not playing then rail = nil; state = "play" end
    world(dt)
    A.updatePlayer(dt, 0, 0, false, false)
    return
  end
  if state == "launch" then
    launchT = launchT + dt
    local playing = rail and rail.update(dt)
    world(dt)
    if not playing and launchT > 1 then
      state, stateT = "ending", 0
      F.sound("win", 0.9)
      local s = S.save or {}
      s.done = true
      s.level, s.cp, s.sent = 1, nil, {}
      writeSave(s)
      S.save = nil
      pcall(store.set, "sz_save", nil)
      F.music("title")
    end
    return
  end
  if state == "ending" then return end
  -- play
  local p = S.player
  runStats.time = runStats.time + dt
  local mx, mz = moveInput()
  local sprint = input.down("zr") or input.down("r") or held.lshift or held.rshift or held.shift
  local sneak = input.down("zl") or input.down("l") or held.lctrl or held.c or held.ctrl
  if p.dead then mx, mz = 0, 0 end
  A.updatePlayer(dt, mx, mz, sprint and not sneak, sneak and true or false)
  updateCamera(dt)
  world(dt)
  interact = (not p.dead) and nearestInteract() or nil
  local alarmNow = S.alarm > 0
  if alarmNow and not wasAlarm then runStats.alarms = runStats.alarms + 1; setNeon(C.red) end
  if not alarmNow and wasAlarm then setNeon(C.cyan) end
  wasAlarm = alarmNow
  F.danger(alarmNow or S.alert > 0.6)
  -- countdown of the escape bay
  if countdown then
    countdown = countdown - dt
    if countdown <= 0 and not p.dead then
      countdown = 0
      p.hp = 1
      p.inv = 0
      A.hurt(5)
    end
  end
  -- exit bulkhead: walk through it
  for _, d in ipairs(S.level.doors) do
    if d.kind == "X" and d.open > 0.8 and (p.x - d.x) ^ 2 + (p.z - d.z) ^ 2 < 0.8 and not pending then
      levelDone()
    end
  end
  if p.dead and p.deadT > 2.4 and not pending then
    fadeThen(function() startLevel(S.levelIndex, S.save and S.save.cp ~= nil) end)
  end
end

-- ---------------------------------------------------------------- 3D
local function droneColor(d)
  if d.hunting or d.keyart then return C.red, "#FF2B3A" end
  if d.sus > 0.3 then return C.amber, "#FFB23F" end
  return C.cyan, "#3FE6FF"
end

local function hexA(col, a)
  return col .. string.format("%02X", max(0, min(255, floor(a * 255))))
end

local perfDrawT0 = 0
local function drawScene(w, h, ex, ey, ez, tx, ty, tz, fov)
  perfDrawT0 = sys.time()
  local lv = S.level
  local p = S.player
  g3d.begin(0, 0, w, h, fov or 58, 0.08, 260)
  g3d.camera(ex, ey, ez, tx, ty, tz)
  g3d.light(0.35, 0.55, -1, 0.22, "#BFD6FF")
  g3d.fog(C.void, 140, 700)
  -- the light pool follows a point a few metres in front of the camera (the hero in play, the subject on a rail)
  local dx0, dz0 = tx - ex, tz - ez
  local dl0 = math.max(0.01, sqrt(dx0 * dx0 + dz0 * dz0))
  local lx, lz = ex + dx0 / dl0 * 5, ez + dz0 / dl0 * 5
  F.lightsUpdate(1 / 60, lx, lz)
  W.drawSpace(ex, ey, ez)
  local vx, vz = tx - ex, tz - ez
  local vl = sqrt(vx * vx + vz * vz)
  local radius = (demo and demo.opt == "old") and (S.quality == "high" and 34 or 28) or (S.quality == "high" and 32 or 24)
  W.draw(lv, ex, ez, vx / max(vl, 0.01), vz / max(vl, 0.01), radius)
  local m = W.models
  local t = S.t
  -- things
  for _, th in ipairs(lv.things) do
    local k = th.k
    if (th.x - ex) ^ 2 + (th.z - ez) ^ 2 < 900 then
      if k == "K" and not th.taken then
        g3d.draw(keyMesh, th.x, 1.05 + sin(t * 2) * 0.08, th.z, 0.4, t * 1.6, 0)
        g3d.draw(glowBall, th.x, 1.05, th.z, 0, 0, 0, 0.9, 0.9, 0.9, "#3A2508", "glow unlit nocull")
      elseif k == "H" then
        local a = th.read and 0.4 or 1
        g3d.draw(holoCone, th.x, 0.25, th.z, 0, t, 0, 1, 1, 1, hexA("#FFFFFF", a), "glow unlit nocull")
        if m.elamp then g3d.draw(m.elamp, th.x, 0.12, th.z, -pi / 2, 0, 0, 1.6, 1.6, 1.6, "#9FEFFF") end
      elseif k == "p" then
        local on = L and th.logic and L.stateOf(th.logic) == "down"
        g3d.draw(ringMesh, th.x, 0.03, th.z, 0, 0, 0, 1, 1, 1, on and "#FFFFFF" or "#B07020")
      elseif k == "l" then
        local on = th.logic and L.stateOf(th.logic) == "on"
        local yaw = th.yaw
        g3d.draw(handleMesh, th.x + sin(yaw) * 0.32, 1.25, th.z + cos(yaw) * 0.32, on and 0.7 or -0.7, yaw, 0)
      elseif (k == "T" or k == "c") then
        local yaw = th.yaw
        local col = k == "c" and "#7DFFB0" or C.cyan
        if k == "T" and ((S.levelIndex == 2 and lv.powered) or (S.levelIndex == 3 and lv.unlocked)) then col = "#7DFFB0" end
        if m.terminal then g3d.draw(m.terminal, th.x + sin(yaw) * 0.24, 1.0, th.z + cos(yaw) * 0.24, 0, yaw, 0, 1.3) end
        g3d.draw(glowBall, th.x + sin(yaw) * 0.45, 1.33, th.z + cos(yaw) * 0.45, 0, 0, 0, 0.7, 0.5, 0.7,
                 hexA(col, 0.18 + 0.05 * sin(t * 5 + th.x)), "glow unlit nocull")
      end
    end
  end
  -- reactor
  if lv.reactor then
    local rc = lv.reactor
    if m.reactor then g3d.draw(m.reactor, rc.x, 0, rc.z, 0, 0, 0, 0.85) end
    -- the shaft the reactor rises into, above the hole in the ceiling
    g3d.draw(shaftMesh, rc.x, S.WALL_H + 3.5, rc.z, 0, 0, 0, 1, 1, 1, "#1A2028", "nocull")
    local pulse = lv.powered and (1 + 0.06 * sin(t * 3)) or (0.55 + 0.25 * sin(t * 9) * sin(t * 2.3))
    g3d.draw(coreMesh, rc.x, 2.3, rc.z, 0, t * 0.4, 0, 0.32 * pulse, 0.55 * pulse, 0.32 * pulse,
             lv.powered and "#FFFFFF" or "#FFB23F")
    g3d.draw(glowBall, rc.x, 2.3, rc.z, 0, 0, 0, 2.2 * pulse, 3.0 * pulse, 2.2 * pulse,
             lv.powered and "#08303C" or "#241204", "glow unlit nocull")
  end
  -- pod
  if lv.pod then
    local pod = lv.pod
    local drop = state == "launch" and max(0, launchT - 1.2) ^ 2 * 2.2 or 0
    if m.cradle then g3d.draw(m.cradle, pod.x, 0, pod.z, 0, 0, 0, 0.75) end
    if m.pod then g3d.draw(m.pod, pod.x, 0.2 - drop, pod.z, 0, 0, 0, 0.68) end
    if state == "launch" and launchT > 1.2 then
      g3d.draw(glowBall, pod.x, 0.3 - drop - 0.6, pod.z, 0, 0, 0, 1.4, 2.4, 1.4, "#1F3C66", "glow unlit nocull")
      if random() < 0.7 then F.sparks(pod.x, 0.3 - drop, pod.z, 3, 1.4) end
    end
  end
  -- sentries
  for _, s in ipairs(A.sentries) do
    if m.warden then g3d.draw(m.warden, s.x, 0, s.z, 0, s.yaw, 0, 0.78) end
    g3d.draw(glowBall, s.x + sin(s.yaw) * 0.32, 1.72, s.z + cos(s.yaw) * 0.32, 0, 0, 0, 0.16, 0.16, 0.16,
             s.sus > 0.5 and "#FF3030" or "#FFB23F", "unlit")
  end
  -- drones and their cones; the nearest drone carries the shadow-casting searchlight
  local nearest, nd = nil, 15 * 15
  for _, d in ipairs(A.drones) do
    local dd = (d.x - lx) ^ 2 + (d.z - lz) ^ 2
    if dd < nd then nearest, nd = d, dd end
    if (d.x - ex) ^ 2 + (d.z - ez) ^ 2 < 1200 then
      if m.drone then g3d.draw(m.drone, d.x, d.y - 0.25, d.z, 0, d.yaw, 0, 1.7) end
      local col = droneColor(d)
      local ex2, ez2 = d.x + sin(d.yaw) * 0.42, d.z + cos(d.yaw) * 0.42
      g3d.draw(glowBall, ex2, d.y, ez2, 0, 0, 0, 0.1, 0.1, 0.1, col, "unlit")
      g3d.draw(glowBall, ex2, d.y, ez2, 0, 0, 0, 0.35, 0.35, 0.35, hexA(col, 0.22), "glow unlit nocull")
      local a = (d.hunting or d.keyart) and 0.55 or (0.3 + 0.4 * d.sus)
      g3d.draw(coneMesh, ex2, d.y, ez2, 0.24, d.yaw, 0, 1, 1, 1, hexA(col, a), "glow unlit nocull")
    end
  end
  if nearest then
    local col = droneColor(nearest)
    local dx, dz = sin(nearest.yaw), cos(nearest.yaw)
    F.spot(nearest.x + dx * 0.45, nearest.y, nearest.z + dz * 0.45, dx * 0.97, -0.24, dz * 0.97, col,
           nearest.hunting and 26 or 18)
  else F.spot(nil) end
  -- bolts
  for _, b in ipairs(A.bolts) do
    g3d.draw(boltMesh, b.x, b.y, b.z, 0, atan(b.vx, b.vz), 0)
  end
  -- alarm beacons on the walls
  if S.alarm > 0 then
    local pulse = 0.5 + 0.5 * sin(t * 6)
    for _, e in ipairs(lv.emit) do
      if e.kind == "alarmlamp" and (e.x - ex) ^ 2 + (e.z - ez) ^ 2 < 600 then
        g3d.draw(glowBall, e.x, e.y, e.z, 0, 0, 0, 0.5, 0.5, 0.5, hexA("#FF2020", 0.35 * pulse), "glow unlit nocull")
      end
    end
  end
  -- hero
  if p and m.hero and p.x > -40 then
    local cdx, cdz = ex - p.x, ez - p.z
    local cdl = math.max(0.01, sqrt(cdx * cdx + cdz * cdz))
    F.suit(p.x + cdx / cdl * 1.1, 2.1, p.z + cdz / cdl * 1.1, not p.dead)
    local blink = p.inv > 0 and floor(t * 14) % 2 == 0
    if not blink then g3d.draw(m.hero, p.x, 0, p.z, 0, p.yaw, 0) end
    -- suit lamp
    g3d.draw(glowBall, p.x + sin(p.yaw) * 0.18, 1.42, p.z + cos(p.yaw) * 0.18, 0, 0, 0, 0.06, 0.06, 0.06, C.cyan, "unlit")
  else F.suit(0, -50, 0, false) end
  F.draw(ex, ez)
  local tf = sys.time()
  perf.sub = perf.sub + (tf - perfDrawT0)
  g3d.finish()
  perf.fin = perf.fin + (sys.time() - tf)
end

-- ---------------------------------------------------------------- 2D: the terminal look of this game
local function spaced(s, x, y, size, font, track, col)
  gfx.color(col)
  for _, cp in utf8.codes(s) do
    local ch = utf8.char(cp)
    gfx.text(ch, x, y, size, font)
    x = x + gfx.textWidth(ch, size, font) + track
  end
  return x
end

local function bracket(x, y, w, h, col, k)
  T.frame(x, y, w, h, col)
end

local function prompt(text, sx, sy)
  local tw = gfx.textWidth(text, 15, "monobold")
  local x, y = floor(sx - tw / 2 - 14), floor(sy - 18)
  gfx.color("#06141BD8")
  gfx.rect(x, y, tw + 28, 30)
  bracket(x, y, tw + 28, 30, C.amber)
  gfx.color(C.amber)
  gfx.text(text, x + 14, y + 6, 15, "monobold")
end

local function drawHud(w, h)
  local lv, p = S.level, S.player
  local t = S.t
  local s = h / 720
  -- objective
  local obj = LV[S.levelIndex].objective
  if S.levelIndex == 2 and lv.powered then obj = "obj_reactor2" end
  if S.levelIndex == 3 and lv.unlocked then obj = "obj_bridge2" end
  if S.levelIndex == 1 and (S.vars.hadKey or 0) > 0 then obj = "obj_hangar2" end
  local ox, oy = floor(28 * s), floor(24 * s)
  gfx.gradient(0, 0, w, floor(110 * s), "#05070CA0", "#05070C00")
  gfx.color(C.dim)
  gfx.text(TR("sector_" .. LV[S.levelIndex].id), ox, oy, floor(12 * s), "mono")
  gfx.color(C.cyan)
  local line = "> " .. TR(obj) .. (floor(t * 2) % 2 == 0 and "_" or "")
  gfx.text(line, ox, oy + floor(18 * s), floor(17 * s), "monobold")
  -- detection meter
  if S.alert > 0.02 or S.alarm > 0 then
    local bw = floor(220 * s)
    local by = oy + floor(46 * s)
    gfx.color("#2A0A0E")
    gfx.rect(ox, by, bw, floor(6 * s))
    gfx.color(S.alarm > 0 and C.red or C.amber)
    gfx.rect(ox, by, floor(bw * (S.alarm > 0 and 1 or S.alert)), floor(6 * s))
    gfx.text(TR(S.alarm > 0 and "alarm" or "detected"), ox, by + floor(10 * s), floor(12 * s), "monobold")
  end
  -- suit cells
  local cx, cy = ox, h - floor(56 * s)
  gfx.color(C.dim)
  gfx.text(TR("suit"), cx, cy - floor(16 * s), floor(11 * s), "mono")
  for i = 1, 3 do
    local x = cx + (i - 1) * floor(34 * s)
    local on = i <= (p and p.hp or 0)
    gfx.color(on and C.cyan or "#3A1218")
    gfx.poly({x + 6 * s, cy, x + 28 * s, cy, x + 22 * s, cy + 22 * s, x, cy + 22 * s}, on and C.cyan or "#3A1218")
  end
  -- code digits and keycard
  local rx = w - floor(28 * s)
  if S.save and S.save.code and S.levelIndex <= 3 then
    local d = ""
    for i = 1, 4 do d = d .. ((S.save.digits and S.save.digits[i]) and S.save.code:sub(i, i) or "-") .. " " end
    gfx.color(C.dim)
    gfx.text(TR("code"), rx - floor(200 * s), oy, floor(12 * s), "mono", "right", floor(200 * s))
    gfx.color(C.text)
    gfx.text(d, rx - floor(200 * s), oy + floor(16 * s), floor(20 * s), "monobold", "right", floor(200 * s))
  end
  if (S.vars.key or 0) > 0 then
    gfx.color(C.amber)
    gfx.text(TR("keycard"), rx - floor(200 * s), oy + floor(44 * s), floor(13 * s), "monobold", "right", floor(200 * s))
  end
  -- countdown
  if countdown then
    local cs = max(0, countdown)
    local txt = string.format("T-%02d:%02d", floor(cs / 60), floor(cs % 60))
    gfx.color(floor(t * 2) % 2 == 0 and C.red or "#FF8088")
    gfx.text(txt, 0, floor(20 * s), floor(34 * s), "monobold", "center", w)
    gfx.color(C.red)
    gfx.text(TR("venting"), 0, floor(60 * s), floor(12 * s), "mono", "center", w)
  end
  -- interact prompt
  if interact then
    local ok, sx, sy = pcall(g3d.project, interact.x, 1.9, interact.z)
    local key = interact.k == "K" and "use_key" or interact.k == "H" and "use_log" or interact.k == "T" and "use_term"
                or interact.k == "l" and "use_lever" or "use_pod"
    if ok and sx then prompt((usingTouch and "" or "[A] ") .. TR(key), sx, sy) end
  end
  -- toast
  if S.toast then
    local a = min(1, S.toast.t * 2)
    gfx.alpha(a)
    local tw = min(w - 80, gfx.textWidth(S.toast.text, floor(16 * s), "monobold") + 40)
    local x, y = floor((w - tw) / 2), h - floor(120 * s)
    gfx.color("#06141BE0")
    gfx.rect(x, y, tw, floor(36 * s))
    bracket(x, y, tw, floor(36 * s), C.cyan)
    gfx.color(C.text)
    gfx.text(S.toast.text, x, y + floor(9 * s), floor(16 * s), "monobold", "center", tw)
    gfx.unalpha()
  end
  -- red edges when hurt or in an alarm
  local red = (p and p.inv or 0) / 1.4
  if S.alarm > 0 then red = max(red, 0.25 + 0.15 * sin(t * 6)) end
  if red > 0.01 then
    gfx.gradient(0, 0, w, floor(h * 0.12), hexA("#FF1020", 0.35 * red), "#FF102000")
    gfx.gradient(0, h - floor(h * 0.12), w, floor(h * 0.12), "#FF102000", hexA("#FF1020", 0.35 * red))
  end
  -- touch controls
  if usingTouch then
    gfx.color("#CFEFF540")
    gfx.circleLine(floor(140 * s), h - floor(150 * s), floor(60 * s), 2)
    if touch.stick then
      gfx.circleLine(touch.stick.x0, touch.stick.y0, floor(60 * s), 2)
      gfx.circle(touch.stick.x, touch.stick.y, floor(22 * s))
    end
    gfx.color("#FFB23F70")
    gfx.circleLine(w - floor(110 * s), h - floor(110 * s), floor(46 * s), 3)
    gfx.color(C.amber)
    gfx.text(TR("use"), w - floor(156 * s), h - floor(120 * s), floor(15 * s), "monobold", "center", floor(92 * s))
    gfx.color(C.text)
    gfx.rect(w - floor(56 * s), floor(30 * s), floor(6 * s), floor(24 * s))
    gfx.rect(w - floor(44 * s), floor(30 * s), floor(6 * s), floor(24 * s))
  end
  if p and p.dead then
    gfx.color(hexA("#000000", min(0.7, p.deadT * 0.5)))
    gfx.rect(0, 0, w, h)
    gfx.color(C.red)
    gfx.text(TR("signal_lost"), 0, floor(h * 0.42), floor(40 * s), "monobold", "center", w)
  end
end

local function drawLogo(x, y, size, t)
  -- the logotype boots like a terminal: letters appear one by one, the last one blinks
  local word = "STATION ZERO"
  local n = min(#word, floor(t * 12))
  local shown = word:sub(1, n)
  local track = floor(size * 0.18)
  local endX = spaced(shown, x + 3, y + 3, size, "monobold", track, "#0A3A44")
  spaced(shown, x, y, size, "monobold", track, C.text)
  if n < #word or floor(t * 2) % 2 == 0 then
    gfx.color(C.cyan)
    gfx.rect(endX + 4, y + size * 0.15, size * 0.45, size * 0.9)
  end
  gfx.color(C.cyan)
  gfx.rect(x, y + size * 1.35, floor(size * 6.8), 2)
  gfx.color(C.dim)
  gfx.text(TR("tagline"), x, y + size * 1.5, floor(size * 0.24), "mono")
end

local function drawMenu(x, y, size, list)
  for i, id in ipairs(list) do
    local yy = y + (i - 1) * floor(size * 1.9)
    local on = i == sel
    if on then
      gfx.color("#3FE6FF22")
      gfx.rect(x - 14, yy - 6, floor(size * 13), floor(size * 1.6))
      T.frame(x - 14, yy - 6, floor(size * 13), floor(size * 1.6), C.cyan)
    end
    gfx.color(on and C.cyan or C.dim)
    local label = TR(id)
    if id == "sound" then label = label .. "  " .. (F.volume >= 1 and "100%" or (F.volume > 0 and "50%" or TR("off"))) end
    gfx.text((on and "> " or "  ") .. label, x, yy, size, "monobold")
    rects[i] = {x = x - 14, y = yy - 6, w = floor(size * 13), h = floor(size * 1.6)}
  end
  for i = #list + 1, #rects do rects[i] = nil end
end

function app.draw(w, h)
  local t0 = sys.time()
  app.drawInner(w, h)
  cpuMark = cpuMark + (sys.time() - t0)
end

function app.drawInner(w, h)
  Wd, Hd = w, h
  local q = h >= 900 and "high" or "balanced"
  if q ~= S.quality then
    S.quality = q
    -- handheld: cheaper shadows; docked: the medium filter (demo option "old" keeps the first settings for comparison)
    if renderer == "pbr" and not (demo and demo.opt == "old") then
      pcall(g3d.shadows, {quality = q == "high" and "medium" or "low", distance = q == "high" and 24 or 18, bias = 1.2})
    end
  end
  gfx.clear(C.void)
  local s = h / 720
  if state == "boot" or not S.level then
    gfx.color(C.dim)
    gfx.text("KEPLER//RING-0  BOOT", floor(40 * s), floor(40 * s), floor(14 * s), "mono")
    gfx.color(C.cyan)
    local pr = W.progress()
    gfx.rect(floor(40 * s), floor(70 * s), floor((w - 80 * s) * pr), 3)
    gfx.text(TR("loading") .. string.format(" %d%%", floor(pr * 100)), floor(40 * s), floor(84 * s), floor(14 * s), "mono")
    return
  end
  if state == "title" or state == "howto" then
    local t = S.t
    local lv = S.level
    -- a slow dolly along the bridge viewports
    local px = 16 + 16 * (0.5 + 0.5 * sin(t * 0.05))
    drawScene(w, h, px, 2.3, 18.4, px + 5, 1.5, 5, 62)
    gfx.gradient(0, 0, floor(w * 0.55), h, "#05070CE6", "#05070C00", true)
    if state == "title" then
      drawLogo(floor(56 * s), floor(96 * s), floor(58 * s), bootText)
      drawMenu(floor(70 * s), floor(330 * s), floor(22 * s), menuItems())
      gfx.color(C.dim)
      gfx.text(TR("hint_menu"), floor(56 * s), h - floor(40 * s), floor(12 * s), "mono")
    else
      gfx.color(C.cyan)
      gfx.text(TR("controls"), floor(56 * s), floor(80 * s), floor(30 * s), "monobold")
      local y = floor(140 * s)
      for _, k in ipairs({"c_move", "c_look", "c_use", "c_sprint", "c_sneak", "c_pause", "c_goal", "c_drones"}) do
        gfx.color(C.amber)
        gfx.rect(floor(56 * s), y + floor(7 * s), 6, 6)
        gfx.color(C.text)
        y = y + gfx.wrap(TR(k), floor(74 * s), y, floor(w * 0.5), floor(16 * s), "mono") + floor(12 * s)
      end
      gfx.color(C.dim)
      gfx.text(TR("back"), floor(56 * s), h - floor(40 * s), floor(12 * s), "mono")
    end
    local _ = lv
  elseif state == "ending" then
    drawScene(w, h, S.level.pod.x + 30, 30, S.level.pod.z - 60, S.level.pod.x, -40, S.level.pod.z + 40, 60)
    gfx.color("#05070CC0")
    gfx.rect(0, 0, w, h)
    gfx.color(C.cyan)
    gfx.text(TR("escaped"), 0, floor(h * 0.3), floor(46 * s), "monobold", "center", w)
    gfx.color(C.text)
    gfx.text(TR("ending_line"), 0, floor(h * 0.3 + 70 * s), floor(16 * s), "mono", "center", w)
    gfx.color(C.dim)
    gfx.text(TR("stats", floor(runStats.time / 60), floor(runStats.time % 60), runStats.alarms), 0,
             floor(h * 0.3 + 110 * s), floor(14 * s), "mono", "center", w)
    if stateT > 3 then gfx.text(TR("back"), 0, h - floor(60 * s), floor(13 * s), "mono", "center", w) end
  else
    local ex, ey, ez, tx, ty, tz, fov = cam.x, cam.y, cam.z, cam.tx, cam.ty, cam.tz, cam.fov
    if rail and (state == "intro" or state == "launch") then
      local sm = rail.sample()
      ex, ey, ez, tx, ty, tz = sm.eye[1], sm.eye[2], sm.eye[3], sm.target[1], sm.target[2], sm.target[3]
      fov = sm.fov > 0 and sm.fov or 58
      cam.x, cam.y, cam.z = ex, ey, ez
    elseif demo and tonumber(demo.v) and tonumber(demo.v) > 0 then
      local v = LV[S.levelIndex].rail[tonumber(demo.v) or 1]
      if v then
        local a, b = cellPos(v.pos[1], v.pos[2], v.pos[3]), cellPos(v.look[1], v.look[2], v.look[3])
        ex, ey, ez, tx, ty, tz, fov = a[1], a[2], a[3], b[1], b[2], b[3], v.fov
      end
    end
    local sh = A.shake or 0
    if sh > 0 then
      A.shake = max(0, sh - 1 / 60 * 1.5)
      ex, ey = ex + (random() - 0.5) * sh * 0.12, ey + (random() - 0.5) * sh * 0.12
    end
    drawScene(w, h, ex, ey, ez, tx, ty, tz, fov)
    if state == "intro" then
      gfx.color("#000000")
      gfx.rect(0, 0, w, floor(h * 0.1))
      gfx.rect(0, h - floor(h * 0.1), w, floor(h * 0.1))
      gfx.color(C.cyan)
      gfx.text(TR("sector_" .. LV[S.levelIndex].id), floor(40 * s), h - floor(58 * s), floor(18 * s), "monobold")
      gfx.color(C.dim)
      gfx.text(TR("skip"), w - floor(240 * s), h - floor(52 * s), floor(12 * s), "mono", "right", floor(200 * s))
    elseif state == "launch" then
      gfx.color("#000000")
      gfx.rect(0, 0, w, floor(h * 0.1))
      gfx.rect(0, h - floor(h * 0.1), w, floor(h * 0.1))
    elseif not S.noHud then
      drawHud(w, h)
    end
    if state == "term" then T.draw(w, h, S.save and S.save.digits) end
    if state == "pause" then
      gfx.color("#05070CD0")
      gfx.rect(0, 0, w, h)
      gfx.color(C.cyan)
      gfx.text(TR("paused"), floor(70 * s), floor(110 * s), floor(36 * s), "monobold")
      drawMenu(floor(70 * s), floor(200 * s), floor(22 * s), menuItems())
    end
  end
  if fade > 0.01 then
    gfx.color(hexA("#000000", fade))
    gfx.rect(0, 0, w, h)
  end
end

function app.suspend() pause() end
function app.focus(f) if not f then pause() end end
function app.close() F.stopAll() end

return app
