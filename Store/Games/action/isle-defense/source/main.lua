-- Isle Defense: 3D tower defence on a tropical island. Raiders land from a sea portal and march to the island's heart;
-- build and upgrade towers on stone pads along their route. Engine pieces: g3d pbr renderer (sun shadows, bloom,
-- water with moving ripples), Game Engine terrain and td route (generated island), camera rail (nexvyn.ge_anim),
-- Sound 2.0 recipes and composer (built offline), our own particles and interface.
local D = require("id_data")
local Wd = require("id_world")
local Gm = require("id_game")
local F = require("id_fx")
local U = require("id_ui")
local A = require("id_audio")
local Anim = require("nexvyn.ge_anim")

local app = {}
local sin, cos, pi, sqrt, abs, min, max, floor, atan, tan = math.sin, math.cos, math.pi, math.sqrt, math.abs, math.min, math.max, math.floor, math.atan, math.tan

-- ------------------------------------------------------------------ state
local mode = "boot"         -- boot, title, play, pause, result, options
local t = 0
local W, H = 1280, 720
local opt = {music = 0.7, sfx = 0.9, shake = true, slot = 1}
local menu = {sel = 1}
local cam = {tx = 0, tz = 4, yaw = 0, dist = 56, pitch = 0.95, fov = 42, shake = 0}
local camGoal = {tx = 0, tz = 4, dist = 52}
local cursor = {x = 0, z = 4, on = false}
local speed = 1
local sel = nil             -- {pad, ring = true | card = true, i}
local msg = nil             -- {text, sub, t, dur, boss}
local rail = nil            -- ge_anim rail player for the intro sweep
local result = nil
local touch = {}
local keys = {}
local frameMs, perfT, perfN, perfSum, perfMax = 0, 0, 0, 0, 0
local goldFlash, heartBeat = 0, 0
local lastPad = false
local debugShot = nil
local SLOTS = 3

local function save(k, v) store.set(k, v) end
local function load(k, d) local v = store.get(k); if v == nil then return d end return v end
local function slotData() return load("slot" .. opt.slot, nil) or {stars = 0, best = 0} end

-- ------------------------------------------------------------------ camera
local function eye()
  local cp = cos(cam.pitch)
  local ex = cam.tx + sin(cam.yaw) * cp * cam.dist
  local ez = cam.tz + cos(cam.yaw) * cp * cam.dist
  local ey = Wd.heightAt(cam.tx, cam.tz) * 0.5 + sin(cam.pitch) * cam.dist
  return ex, ey, ez
end

-- ray through a screen point, then onto the ground (a few steps on the terrain height)
local function pick(sx, sy)
  local ex, ey, ez = eye()
  local ty = Wd.heightAt(cam.tx, cam.tz) * 0.5
  local fx, fy, fz = cam.tx - ex, ty - ey, cam.tz - ez
  local fl = sqrt(fx * fx + fy * fy + fz * fz)
  fx, fy, fz = fx / fl, fy / fl, fz / fl
  local rx, ry, rz = -fz, 0, fx                       -- right = forward x up
  local rl = sqrt(rx * rx + rz * rz)
  rx, rz = rx / rl, rz / rl
  local ux, uy, uz = ry * fz - rz * fy, rz * fx - rx * fz, rx * fy - ry * fx
  local th = tan(math.rad(cam.fov) / 2)
  local nx, ny = (2 * sx / W - 1) * th * W / H, (1 - 2 * sy / H) * th
  local dx, dy, dz = fx + rx * nx + ux * ny, fy + ry * nx + uy * ny, fz + rz * nx + uz * ny
  if dy >= -0.01 then return nil end
  local gy = 1
  local px, pz
  for _ = 1, 4 do
    local k = (gy - ey) / dy
    px, pz = ex + dx * k, ez + dz * k
    gy = max(Wd.heightAt(px, pz), Wd.S.waterY)
  end
  return px, pz
end

local function padAt(x, z, r)
  local best, bd = nil, (r or 2.0) ^ 2
  for i, p in ipairs(Wd.S.pads) do
    local dx, dz = p[1] - x, p[3] - z
    local d = dx * dx + dz * dz
    if d < bd then best, bd = i, d end
  end
  return best
end

-- ------------------------------------------------------------------ events from the battle
local function say(text, sub, dur, boss)
  msg = {text = text, sub = sub, t = 0, dur = dur or 3, boss = boss}
end

local function writeRun(run)
  local s = slotData()
  s.run = run
  save("slot" .. opt.slot, s)
end

Gm.emit = function(ev, a, b, c)
  if ev == "shot" then
    local snd = ({archer = (math.random() < 0.5 and "bow" or "bow2"), cannon = "cannon", frost = "frost", storm = "zap"})[a]
    if snd then A.play(snd, 0.7) end
    if a == "storm" and math.random() < 0.3 then A.play("thunder", 0.35) end
  elseif ev == "boom" then A.play("boom", 0.8); if opt.shake then cam.shake = max(cam.shake, 0.12) end
  elseif ev == "hit" then A.play(a.f.armor and "clang" or "arrow_hit", 0.5)
  elseif ev == "kill" then A.play(math.random() < 0.5 and "die1" or "die2", 0.6); A.play("coin", 0.4); goldFlash = 0.3
  elseif ev == "build" then A.play("build", 0.9); A.play("thud", 0.6)
  elseif ev == "upgrade" then A.play("upgrade", 0.8)
  elseif ev == "sell" then A.play("sell", 0.8)
  elseif ev == "error" then A.play("error", 0.6)
  elseif ev == "splash" then A.play("splash", 0.5)
  elseif ev == "wave" then
    A.play(b and "horn_boss" or "horn", 0.9)
    A.song("battle")
    say(TR("msg_wave", a), c and c > 0 and TR("msg_bonus", c) or TR("msg_landing"), 2.6, b)
  elseif ev == "cleared" then
    A.song("calm")
    A.play("bell", 0.6)
    say(TR("msg_cleared", a), b and b > 0 and TR("msg_income", b) or TR("msg_build"), 2.6)
    writeRun(Gm.snapshot())
  elseif ev == "leak" then
    A.play("heart", 0.9)
    heartBeat = 1
    if opt.shake then cam.shake = max(cam.shake, 0.3) end
  elseif ev == "win" then
    A.song(nil)
    A.play("win", 0.9)
    local s = slotData()
    s.stars = max(s.stars or 0, a)
    s.run = nil
    save("slot" .. opt.slot, s)
    result = {win = true, stars = a, t = 0}
  elseif ev == "lose" then
    A.song(nil)
    A.play("lose", 0.9)
    local s = slotData()
    s.run = nil
    save("slot" .. opt.slot, s)
    result = {win = false, stars = 0, t = 0}
  end
end

-- ------------------------------------------------------------------ lights
local function setupLights()
  g3d.clearLights()
  local S = Wd.S
  g3d.addLight({type = "point", x = S.heart[1], y = S.heart[2] + 2.5, z = S.heart[3], color = "#40E8FF", intensity = 10, range = 9})
  g3d.addLight({type = "point", x = S.portal.x, y = S.waterY + 1.2, z = S.portal.z, color = "#C060FF", intensity = 12, range = 10})
  for i, p in ipairs(S.torches or {}) do
    if i <= 3 then g3d.addLight({type = "point", x = p.x, y = p.y + 2.1, z = p.z, color = "#FF9A3C", intensity = 3, range = 5}) end
  end
end

local function setupRenderer(def)
  g3d.environment({sky = def.sky, ground = def.ground, intensity = 0.95, sun = def.sunI})
end

-- ------------------------------------------------------------------ flow
local function startIsland(run, intro)
  Wd.build(1)
  Gm.new(1, run)
  F.clear()
  setupRenderer(Wd.S.def)
  setupLights()
  local S = Wd.S
  -- frame the play field
  camGoal.tx, camGoal.tz, camGoal.dist = 0, 6, 56
  cam.tx, cam.tz, cam.dist, cam.yaw = camGoal.tx, camGoal.tz, camGoal.dist, 0
  cursor.x, cursor.z = S.pads[1][1], S.pads[1][3]
  sel = nil
  result = nil
  speed = 1
  mode = "play"
  A.song("calm")
  A.ambience(1)
  -- the intro sweep: from the portal over the route to the heart, then up to the play view
  if intro then
    local pts = {}
    local r = S.route
    local function P(x, y, z, lx, ly, lz) pts[#pts + 1] = {pos = {x, y, z}, look = {lx, ly, lz}} end
    P(r[1][1] - 6, 6, r[1][3] + 10, r[1][1], 0, r[1][3])
    local mid = r[floor(#r / 2)]
    P(mid[1] - 4, 9, mid[3] + 12, mid[1], mid[2], mid[3])
    P(S.heart[1] - 6, 6, S.heart[3] + 8, S.heart[1], S.heart[2] + 2, S.heart[3])
    local ex, ey, ez = eye()
    P(ex, ey, ez, cam.tx, Wd.heightAt(cam.tx, cam.tz) * 0.5, cam.tz)
    rail = Anim.railPlayer(Anim.rail({duration = 7, ease = "ease", points = pts}))
    rail.play()
    say(TR(S.def.name), TR("msg_intro"), 4)
  else
    rail = nil
  end
end

local function goTitle()
  if not Wd.S.terrain then Wd.build(1); Gm.new(1); setupRenderer(Wd.S.def); setupLights() end
  mode = "title"
  menu = {sel = 1}
  sel = nil
  result = nil
  A.song("title")
  A.ambience(1)
end

local function titleItems()
  local s = slotData()
  local items = {}
  if s.run then items[#items + 1] = {label = TR("m_continue"), id = "continue"} end
  items[#items + 1] = {label = TR("m_new"), id = "new"}
  items[#items + 1] = {label = TR("m_slot"), id = "slot", value = TR("m_slot_v", opt.slot, s.stars or 0)}
  items[#items + 1] = {label = TR("m_options"), id = "options"}
  return items
end

local function pauseItems()
  return {{label = TR("m_resume"), id = "resume"}, {label = TR("m_restart"), id = "restart"}, {label = TR("m_options"), id = "options"},
          {label = TR("m_quit"), id = "quit"}}
end

local function optItems()
  local function pct(v) return floor(v * 100 + 0.5) .. "%" end
  return {{label = TR("o_music"), id = "music", value = pct(opt.music)}, {label = TR("o_sfx"), id = "sfx", value = pct(opt.sfx)},
          {label = TR("o_shake"), id = "shake", value = TR(opt.shake and "on" or "off")}, {label = TR("m_back"), id = "back"}}
end

local function items()
  if mode == "title" then return titleItems() elseif mode == "pause" then return pauseItems() elseif mode == "options" then return optItems() end
  return {}
end

local function applyOpts()
  A.sfx, A.music = opt.sfx, opt.music
  save("opts", opt)
end

local function choose(it, dir)
  if not it then return end
  A.play("click", 0.6)
  local id = it.id
  if id == "continue" then startIsland(slotData().run, false)
  elseif id == "new" then
    local s = slotData(); s.run = nil; save("slot" .. opt.slot, s)
    startIsland(nil, true)
  elseif id == "slot" then opt.slot = (opt.slot + (dir or 1) - 1) % SLOTS + 1; applyOpts(); menu.sel = math.min(menu.sel, #titleItems())
  elseif id == "options" then menu = {sel = 1, back = mode}; mode = "options"
  elseif id == "resume" then mode = "play"
  elseif id == "restart" then local s = slotData(); s.run = nil; save("slot" .. opt.slot, s); startIsland(nil, false)
  elseif id == "quit" then goTitle()
  elseif id == "music" then opt.music = (floor(opt.music * 10 + 0.5) + (dir or 1)) % 11 / 10; applyOpts(); A.restartSong()
  elseif id == "sfx" then opt.sfx = (floor(opt.sfx * 10 + 0.5) + (dir or 1)) % 11 / 10; applyOpts()
  elseif id == "shake" then opt.shake = not opt.shake; applyOpts()
  elseif id == "back" then mode = menu.back or "title"; menu = {sel = 1} end
end

-- ------------------------------------------------------------------ selection
local function openPad(i)
  if not i then sel = nil; return end
  if Gm.towers[i] then sel = {pad = i, card = true} else sel = {pad = i, ring = true, i = sel and sel.i or 1} end
  A.play("open", 0.5)
end

local function selRange()
  if not sel or not sel.pad then return nil end
  local tw = Gm.towers[sel.pad]
  if tw then return Gm.towerStat(tw, "range"), "#FFE6A0" end
  if sel.ring then
    local d = D.TOWERS[sel.i or 1]
    return d.range[1], d.color
  end
  if sel.drag then local d = D.TOWERS[sel.drag]; return d.range[1], d.color end
end

local function buildSel(i)
  if sel and sel.pad and Gm.build(sel.pad, D.TOWERS[i].id) then sel = {pad = sel.pad, card = true} end
end

-- ------------------------------------------------------------------ input
local function padInput(dt)
  local lx, ly = input.stick("left")
  local rx, ry = input.stick("right")
  local any = abs(lx) + abs(ly) + abs(rx) + abs(ry) > 0.2
  for _, b in ipairs({"a", "b", "x", "y", "l", "r", "zl", "zr", "up", "down", "left", "right", "plus"}) do
    if input.pressed(b) then any = true end
  end
  if any then lastPad = true end
  -- ring choice with the stick / d-pad
  if sel and sel.ring then
    local n = #D.TOWERS
    if abs(lx) + abs(ly) > 0.5 then
      local a = atan(lx, ly)                      -- 0 = up, clockwise
      sel.i = floor(((a / (2 * pi)) % 1) * n + 0.5) % n + 1
    end
    if input.pressed("right") or input.pressed("down") then sel.i = sel.i % n + 1; A.play("hover", 0.4) end
    if input.pressed("left") or input.pressed("up") then sel.i = (sel.i - 2) % n + 1; A.play("hover", 0.4) end
    if input.pressed("a") then buildSel(sel.i) end
    if input.pressed("b") then sel = nil; A.play("back", 0.5) end
    return
  end
  if sel and sel.card then
    if input.pressed("a") then Gm.upgrade(sel.pad) end
    if input.pressed("x") then Gm.sell(sel.pad); sel = nil end
    if input.pressed("b") then sel = nil; A.play("back", 0.5) end
    return
  end
  -- cursor on the ground, relative to the camera's yaw
  local sp = 16 * dt * (cam.dist / 52)
  local cy, sy = cos(cam.yaw), sin(cam.yaw)
  local mx, mz = 0, 0
  if abs(lx) > 0.15 or abs(ly) > 0.15 then mx, mz = lx, -ly end
  if input.down("left") or keys.a then mx = -1 end
  if input.down("right") or keys.d then mx = 1 end
  if input.down("up") or keys.w then mz = -1 end
  if input.down("down") or keys.s then mz = 1 end
  if mx ~= 0 or mz ~= 0 then
    cursor.on = true
    cursor.x = max(-48, min(48, cursor.x + (mx * cy + mz * sy) * sp))
    cursor.z = max(-40, min(48, cursor.z + (-mx * sy + mz * cy) * sp))
  end
  -- snap between pads with L / R
  if input.pressed("r") or input.pressed("l") then
    local cur = padAt(cursor.x, cursor.z, 2.5) or 0
    local n = #Wd.S.pads
    local nxt = input.pressed("r") and (cur % n + 1) or ((cur - 2) % n + 1)
    cursor.x, cursor.z, cursor.on = Wd.S.pads[nxt][1], Wd.S.pads[nxt][3], true
    A.play("hover", 0.4)
  end
  if abs(rx) > 0.2 then cam.yaw = cam.yaw - rx * dt * 1.8 end
  if abs(ry) > 0.2 then camGoal.dist = max(36, min(84, camGoal.dist - ry * dt * 30)) end
  if input.down("zl") then camGoal.dist = min(84, camGoal.dist + dt * 30) end
  if input.down("zr") then camGoal.dist = max(36, camGoal.dist - dt * 30) end
  if keys.q then cam.yaw = cam.yaw + dt * 1.6 end
  if keys.e then cam.yaw = cam.yaw - dt * 1.6 end
  if input.pressed("a") or input.key("enter") then
    local p = padAt(cursor.x, cursor.z, 2.6)
    if p then openPad(p) end
  end
  if input.pressed("x") or input.key("space") then Gm.callWave() end
  if input.pressed("y") or input.key("f") then speed = speed % 3 + 1; A.play("click", 0.5) end
  -- the camera follows the cursor when it leaves the middle of the view
  if cursor.on then
    local dx, dz = cursor.x - camGoal.tx, cursor.z - camGoal.tz
    local lim = 12 * cam.dist / 52
    if abs(dx) > lim then camGoal.tx = camGoal.tx + (dx - lim * (dx > 0 and 1 or -1)) end
    if abs(dz) > lim * 0.7 then camGoal.tz = camGoal.tz + (dz - lim * 0.7 * (dz > 0 and 1 or -1)) end
  end
end

local function menuInput()
  local list = items()
  if #list == 0 then return end
  if input.pressed("down") or input.key("down") then menu.sel = menu.sel % #list + 1; A.play("hover", 0.4) end
  if input.pressed("up") or input.key("up") then menu.sel = (menu.sel - 2) % #list + 1; A.play("hover", 0.4) end
  local _, sy = input.stick("left")
  menu.stickT = (menu.stickT or 0) - 1 / 60
  if abs(sy) > 0.6 and menu.stickT <= 0 then
    menu.sel = sy < 0 and (menu.sel % #list + 1) or ((menu.sel - 2) % #list + 1)
    menu.stickT = 0.22
    A.play("hover", 0.4)
  end
  if input.pressed("right") or input.key("right") then if list[menu.sel].value then choose(list[menu.sel], 1) end end
  if input.pressed("left") or input.key("left") then if list[menu.sel].value then choose(list[menu.sel], -1) end end
  if input.pressed("a") or input.key("enter") then choose(list[menu.sel], 1) end
  if input.pressed("b") or input.key("escape") then
    if mode == "pause" then mode = "play" elseif mode == "options" then choose({id = "back"}) end
  end
end

-- ------------------------------------------------------------------ test hooks (emulator screenshots)
-- "play:<wave>:<preset>[:<yawDeg>:<dist>]" starts the island at a wave with towers built; "title"; "card"/"ring"
local function debugArg(arg)
  if type(arg) ~= "string" or arg == "" then return false end
  local p = {}
  for s in arg:gmatch("[^:]+") do p[#p + 1] = s end
  if p[1] == "title" then goTitle(); return true end
  if p[1] == "play" then
    local wave = tonumber(p[2]) or 0
    local run = nil
    if wave > 0 then
      local towers = {}
      local preset = tonumber(p[3]) or 1
      local kinds = {"archer", "cannon", "frost", "storm"}
      for i = 1, #require("isles.isle1").pads do
        if preset >= 2 or i % 2 == 1 then
          towers[#towers + 1] = {pad = i, id = kinds[(i - 1) % 4 + 1], tier = math.min(3, 1 + ((i + preset) % 3)), spent = 150}
        end
      end
      run = {gold = 600, lives = 18, wave = wave - 1, towers = towers}
    end
    startIsland(run, wave == 0 and p[3] == "intro")
    if p[4] then cam.yaw = math.rad(tonumber(p[4]) or 0) end
    if p[5] then camGoal.dist = tonumber(p[5]) or 52; cam.dist = camGoal.dist end
    if wave > 0 then Gm.callWave() end
    return true
  end
  if p[1] == "ring" and mode == "play" then
    for i = 1, #Wd.S.pads do if not Gm.towers[i] then openPad(i); sel.i = 2; break end end
    return true
  end
  if p[1] == "card" and mode == "play" then
    for i = 1, #Wd.S.pads do if Gm.towers[i] then openPad(i); break end end
    return true
  end
  if p[1] == "pause" and mode == "play" then mode = "pause"; menu = {sel = 1}; return true end
  if p[1] == "speed" then speed = tonumber(p[2]) or 2; return true end
  return false
end

function app.open(arg) debugArg(arg) end

function app.load(arg)
  local r = g3d.renderer("pbr")
  print("isledefense: renderer " .. tostring(r))
  g3d.shadows({enabled = true, quality = "medium", distance = 70})
  g3d.postfx({exposure = 0.95, tonemap = "aces", bloom = 0.1, threshold = 1.0, msaa = 0})
  local o = load("opts", nil)
  if type(o) == "table" then for k, v in pairs(o) do opt[k] = v end end
  A.sfx, A.music = opt.sfx, opt.music
  Wd.init()
  F.init()
  U.init()
  math.randomseed(os.time())
  if not debugArg(arg) then goTitle() end
end

-- ------------------------------------------------------------------ update
function app.update(dt)
  dt = min(dt, 0.05)
  t = t + dt
  A.update(dt)
  local t0 = sys.time()
  goldFlash = max(0, goldFlash - dt)
  heartBeat = max(0, heartBeat - dt * 2)
  if msg then msg.t = msg.t + dt; if msg.t > msg.dur then msg = nil end end
  cam.shake = max(0, cam.shake - dt)
  if mode == "title" then
    menuInput()
    cam.yaw = cam.yaw + dt * 0.05
    cam.tx, cam.tz, cam.dist, cam.pitch = 4, 2, 58, 0.42
    Gm.update(dt * 0)
    F.update(dt)
    return
  end
  if mode == "pause" or mode == "options" then menuInput(); return end
  if mode ~= "play" then return end
  if rail then
    rail.update(dt)
    if not rail.playing or input.pressed("a") or input.pressed("b") or touch.skip then rail = nil; touch.skip = nil end
  end
  if result then
    result.t = result.t + dt
    local btns = result.win and 2 or 2
    if input.pressed("left") then result.sel = ((result.sel or 1) - 2) % btns + 1 end
    if input.pressed("right") then result.sel = (result.sel or 1) % btns + 1 end
    if input.pressed("a") or input.key("enter") or touch.result then
      local s = touch.result or result.sel or 1
      touch.result = nil
      if s == 1 then startIsland(nil, false) else goTitle() end
      return
    end
  else
    if input.pressed("plus") or input.key("escape") or input.key("p") or touch.pause then
      touch.pause = nil
      if sel then sel = nil else mode = "pause"; menu = {sel = 1}; A.play("click", 0.5); return end
    end
    if not rail then padInput(dt) end
  end
  -- simulation at the chosen speed, in steps of at most 1/30 s
  local steps = result and 1 or speed
  for _ = 1, steps do Gm.update(dt) end
  -- camera easing
  local k = min(1, dt * 5)
  cam.tx = cam.tx + (camGoal.tx - cam.tx) * k
  cam.tz = cam.tz + (camGoal.tz - cam.tz) * k
  cam.dist = cam.dist + (camGoal.dist - cam.dist) * k
  cam.pitch = 0.84 + (cam.dist - 36) / 48 * 0.22
  if sel and sel.pad and sel.zoom ~= false then
    local p = Wd.S.pads[sel.pad]
    cam.tx = cam.tx + (p[1] - cam.tx) * dt * 1.2
    cam.tz = cam.tz + (p[3] - cam.tz) * dt * 1.2
  end
  -- glints on the water near the sun's reflection
  if math.random() < dt * 14 then
    local a, d = math.random() * pi * 2, 30 + math.random() * 40
    local x, z = cam.tx + cos(a) * d, cam.tz + sin(a) * d * 0.7 - 10
    if Wd.heightAt(x, z) < Wd.S.waterY - 0.3 then F.spawn("glint", x, Wd.S.waterY + 0.1, z, 0, 0, 0, 0.6 + math.random() * 0.5, 0.35 + math.random() * 0.4, -0.3) end
  end
  if math.random() < dt * 6 then
    local px, pz = Wd.S.portal.x, Wd.S.portal.z
    local a = math.random() * pi * 2
    F.spawn("portal", px + cos(a) * 2.5, Wd.S.waterY + 0.2, pz + sin(a) * 2.5, -cos(a) * 1.2, 0.8, -sin(a) * 1.2, 1.2, 0.6, -0.2)
  end
  if math.random() < dt * 5 then
    local h = Wd.S.heart
    F.spawn("heart", h[1] + (math.random() - 0.5) * 1.2, h[2] + 1.4, h[3] + (math.random() - 0.5) * 1.2, 0, 0.9, 0, 1.4, 0.16, 0)
  end
  for _, p in ipairs(Wd.S.torches or {}) do F.flame(p.x, p.y + 2.05, p.z, 0.45, dt, 10) end
  frameMs = frameMs * 0.9 + (sys.time() - t0) * 1000 * 0.1
end

-- ------------------------------------------------------------------ draw
local function drawWorld(w, h)
  local def = Wd.S.def
  gfx.gradient(0, 0, w, h, def.sky, def.horizon)
  local ex, ey, ez = eye()
  local tx, ty, tz = cam.tx, Wd.heightAt(cam.tx, cam.tz) * 0.5, cam.tz
  local fov = cam.fov
  if rail and rail.playing then
    local s = rail.sample()
    ex, ey, ez, tx, ty, tz = s.eye[1], s.eye[2], s.eye[3], s.target[1], s.target[2], s.target[3]
  end
  if cam.shake > 0 then
    local a = cam.shake * 0.6
    ex, ey, ez = ex + (math.random() - 0.5) * a, ey + (math.random() - 0.5) * a, ez + (math.random() - 0.5) * a
  end
  g3d.begin(0, 0, w, h, fov, 0.5, 900)
  g3d.camera(ex, ey, ez, tx, ty, tz)
  g3d.light(def.sun[1], def.sun[2], def.sun[3], def.ambient, def.sunColor)
  g3d.fog(def.fog[1], def.fog[2], def.fog[3])
  Wd.draw(t, cam)
  local range, rcol = selRange()
  local selInfo = sel and {pad = sel.pad, range = range, color = rcol} or nil
  if not selInfo and cursor.on and lastPad and mode == "play" then
    local p = padAt(cursor.x, cursor.z, 2.6)
    if p then selInfo = {pad = p, range = Gm.towers[p] and Gm.towerStat(Gm.towers[p], "range") or nil} end
  end
  Gm.draw(t, cam, 1 / 60, selInfo)
  -- controller cursor
  if mode == "play" and cursor.on and lastPad and not sel and not rail then
    local gy = max(Wd.heightAt(cursor.x, cursor.z), Wd.S.waterY)
    g3d.draw(Wd.mesh.disc, cursor.x, gy + 0.3, cursor.z, 0, t, 0, 0.9, 1, 0.9, "#FFF2C0", "glow unlit nocull")
  end
  local fyaw = atan(ex - tx, ez - tz)
  local fpitch = atan(ey - ty, sqrt((ex - tx) ^ 2 + (ez - tz) ^ 2))
  F.draw(fyaw, -fpitch)
  Gm.project()
  if sel and sel.pad then
    local p = Wd.S.pads[sel.pad]
    sel.sx, sel.sy = g3d.project(p[1], p[2] + 1.5, p[3])
  end
  return g3d.finish()
end

function app.draw(w, h)
  W, H = w, h
  local t0 = sys.time()
  U.begin()
  if mode == "boot" then U.loading(w, h, 0.5, t); return end
  local tris = drawWorld(w, h)
  local u = h / 720
  local st = Gm.st
  if mode == "title" then
    gfx.gradient(0, 0, w * 0.55, h, "#00000070", "#00000000", true)
    U.menu(w, h, "", items(), menu.sel, t, {logo = true, left = true, top = h * 0.42, width = 400, tagline = TR("tagline"), footer = TR(lastPad and "f_pad" or "f_touch")})
  elseif mode == "play" or mode == "pause" or mode == "options" then
    if not rail then
      U.bars(Gm.enemies, u)
      U.hud(w, h, {st = st, preview = Gm.preview(st.spawning and st.wave or nil), speed = speed, t = t, touch = input.touch(), pad = lastPad,
                   hover = touch.hover, selTray = sel and sel.drag, goldFlash = goldFlash, heartBeat = heartBeat})
      if sel and sel.ring and sel.sx then U.ring(w, h, {x = sel.sx, y = sel.sy, sel = sel.i, gold = st.gold, t = t}) end
      if sel and sel.card and sel.sx and Gm.towers[sel.pad] then
        U.towerCard(w, h, {tower = Gm.towers[sel.pad], x = sel.sx, y = sel.sy, upCost = Gm.upgradeCost(sel.pad), sell = Gm.sellValue(sel.pad), gold = st.gold, t = t, pad = lastPad})
      end
      if sel and sel.drag and touch.dx then
        local d = D.TOWERS[sel.drag]
        U.seal(touch.dx, touch.dy - 50 * u, 30 * u, d.color, d.icon, "hot", t)
      end
      if input.touch() and not lastPad then U.touchHint(w, h) end
    else
      gfx.color(255, 245, 220, 200)
      gfx.text(TR("skip"), w - 220 * u, h - 40 * u, 16 * u, "semibold", "right", 200 * u)
      U.hit("skip", 0, 0, w, h)
    end
    if msg then
      local a = min(1, msg.t * 4, (msg.dur - msg.t) * 2)
      U.banner(w, h, msg.text, msg.sub, max(0, a), msg.boss)
    end
    if result then
      U.result(w, h, {win = result.win, stars = result.stars, t = result.t, a = min(1, result.t * 2), wave = st.wave, waves = st.waves,
                      kills = st.kills, lives = st.lives, sel = result.sel or 1,
                      buttons = {{label = TR(result.win and "b_again" or "b_retry")}, {label = TR("b_menu")}}})
    end
    if mode == "pause" or mode == "options" then
      gfx.color(0, 0, 0, 110)
      gfx.rect(0, 0, w, h)
      U.menu(w, h, TR(mode == "pause" and "t_pause" or "t_options"), items(), menu.sel, t)
    end
  end
  -- frame time for relative measurements (emulator: relative only)
  local ms = (sys.time() - t0) * 1000
  perfN, perfSum, perfMax = perfN + 1, perfSum + ms, max(perfMax, ms)
  if t - perfT > 5 and mode == "play" then
    print(string.format("isledefense perf draw_ms=%.2f max=%.2f upd_ms=%.2f tris=%d foes=%d parts=%d fps=%d", perfSum / perfN, perfMax, frameMs,
      floor(tonumber(tris) or 0), #Gm.enemies, F.count(), floor(tonumber(sys.fps()) or 0)))
    perfT, perfN, perfSum, perfMax = t, 0, 0, 0
  end
end

-- ------------------------------------------------------------------ pointer and touch
local function pointerDown(x, y, isTouch)
  if mode == "title" or mode == "pause" or mode == "options" then
    local id, data = U.hitAt(x, y)
    if id and id:sub(1, 1) == "m" and data then
      local list = items()
      if data == menu.sel or isTouch then menu.sel = data; choose(list[data], 1) else menu.sel = data end
    end
    return
  end
  if mode ~= "play" then return end
  if rail then touch.skip = true; return end
  local id, data = U.hitAt(x, y)
  if result then
    if id and id:sub(1, 1) == "r" and data then touch.result = data end
    return
  end
  if id == "pause" then touch.pause = true return end
  if id == "speed" then speed = speed % 3 + 1; A.play("click", 0.5) return end
  if id == "call" then Gm.callWave() return end
  if id and id:sub(1, 4) == "ring" and data then buildSel(data) return end
  if id == "upgrade" then Gm.upgrade(sel.pad) return end
  if id == "sell" then Gm.sell(sel.pad); sel = nil return end
  if id == "card" or id == "ringbg" then return end
  if id and id:sub(1, 4) == "tray" and data then
    -- drag a tower from the tray onto a pad (or tap the seal, then a pad)
    sel = {drag = data}
    touch.dx, touch.dy = x, y
    A.play("open", 0.5)
    return
  end
  local wx, wz = pick(x, y)
  local p = wx and padAt(wx, wz, 2.6)
  if p then
    if sel and sel.drag and not Gm.towers[p] then
      local d = sel.drag
      sel = {pad = p}
      buildSel(d)
      return
    end
    openPad(p)
    return
  end
  sel = nil
  touch.pan, touch.px, touch.py = true, x, y
end

function app.event(e)
  if e.type == "keydown" and e.key then keys[e.key] = true; lastPad = false
  elseif e.type == "keyup" and e.key then keys[e.key] = nil end
  if e.type == "mousedown" then
    lastPad = false
    pointerDown(e.x, e.y, e.touch)
  elseif e.type == "mousemove" then
    touch.hover = U.hitAt(e.x, e.y)
    if sel and sel.drag and touch.dx then
      touch.dx, touch.dy = e.x, e.y
      local wx, wz = pick(e.x, e.y - 50 * H / 720)
      local p = wx and padAt(wx, wz, 2.6)
      sel.pad = p and not Gm.towers[p] and p or nil
      sel.zoom = false
    elseif touch.pan and mode == "play" then
      local dx, dy = e.x - touch.px, e.y - touch.py
      touch.px, touch.py = e.x, e.y
      local k = cam.dist / H * 1.1
      local cy, sy = cos(cam.yaw), sin(cam.yaw)
      camGoal.tx = max(-45, min(45, camGoal.tx - (dx * cy + dy * sy) * k))
      camGoal.tz = max(-35, min(45, camGoal.tz - (-dx * sy + dy * cy) * k))
      cam.tx, cam.tz = camGoal.tx, camGoal.tz
    end
  elseif e.type == "mouseup" then
    if sel and sel.drag and touch.dx then
      local d = sel.drag
      if sel.pad then
        local p = sel.pad
        sel = {pad = p}
        buildSel(d)
      elseif e.y > H - 120 * H / 720 then
        sel = {drag = d}           -- a tap on the seal: keep it chosen, the next tap on a pad builds
      else
        sel = nil
      end
      touch.dx = nil
    end
    touch.pan = false
  elseif e.type == "scroll" and mode == "play" then
    if not e.touch then camGoal.dist = max(36, min(84, camGoal.dist - (e.dy or 0) * 0.05)) end
  elseif e.type == "pinch" and mode == "play" then
    camGoal.dist = max(36, min(84, camGoal.dist / (e.scale or 1)))
    cam.dist = camGoal.dist
  elseif e.type == "rotate" and mode == "play" then
    cam.yaw = cam.yaw - (e.angle or 0)
  end
end

function app.focus(on)
  keys = {}
  if not on and mode == "play" and not result then mode = "pause"; menu = {sel = 1} end
end

function app.suspend()
  if mode == "play" and not result then mode = "pause"; menu = {sel = 1} end
end

function app.close()
  A.stopAll()
  return true
end

return app
