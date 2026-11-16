-- Crypt Light: a first-person tomb crawl. One lantern, three levels, creatures that hunt by light and sound.
-- Engine pieces: g3d pbr renderer (lights, spot shadow, fog, bloom), phys (capsule controller, raycasts), nav (creature
-- paths), Game Engine Logic 2.0 machines (cl_logic), our own particles (cl_fx) and the owner's kits as asset packs.
local LV = require("cl_levels")
local Wd = require("cl_world")
local F = require("cl_fx")
local P = require("cl_logic")
local AI = require("cl_ai")
local A = require("cl_audio")
local U = require("cl_ui")

local app = {}
local sin, cos, pi, sqrt, abs, min, max, floor, random, atan = math.sin, math.cos, math.pi, math.sqrt, math.abs, math.min, math.max, math.floor, math.random, math.atan

-- ------------------------------------------------------------------ state
local G = {vars = {}, done = {}, statics = {}, msgT = 0, msgDur = 3, objT = 0, hurtFlash = 0, oilShow = 0, shakeT = 0, flare = 0, fx = F}
local Pl = {x = 0, y = 0, z = 0, yaw = 0, pitch = 0, hp = 100, oil = 100, lantern = 1, bob = 0, run = false, invuln = 0, calm = 0, flareCool = 0}
local keys = {}               -- keyboard keys held (from events)
local opt = {sens = 1.0, invert = false, motion = true, volume = 1.0}
local mode = "boot"          -- boot, loading, title, play, pause, dead, exit, ending
local menu = {id = "main", sel = 1}
local t, frameMs, lastPerf = 0, 0, 0
local W, H = 1280, 720
local loader, loadFrac, loadLabel = nil, 0, nil
local level = 1
local slot = 1
local fade, fadeTo, fadeCb = 1, 0, nil
local lights = {}
local T = {}                 -- touch state
local stats = {deaths = 0, time = 0}
local perfLog = {}

local function save(key, v) store.set(key, v) end
local function load(key, d) return store.get(key, d) end

-- ------------------------------------------------------------------ helpers the other modules call
function G.say(key) G.msg, G.msgT, G.msgDur = TR(key), 3.2, 3.2 end
local hintCool = 0
function G.hint(key) if hintCool <= 0 then G.say(key); hintCool = 4 end end
function G.sfx(name) A.play(name, 0.9) end
function G.sfxAt(name, x, z, vol, range) A.at(name, x, z, Pl.x, Pl.z, vol, range) end
function G.shake(s) if opt.motion then G.shakeT = max(G.shakeT, s) end end
function G.groundAt(x, z) return G.L and Wd.ground(G.L, x, z, 3.0) end
function G.box(x, y, z, hx, hy, hz) return phys.addBox(G.L.phys, x, y, z, hx, hy, hz) end
function G.addOil(n) Pl.oil = min(100, Pl.oil + n); G.oilShow = 3 end
function G.drainOil(n) Pl.oil = max(0, Pl.oil - n); G.oilShow = 2 end
function G.pickupFx(x, y, z, col) F.burst("spark", x, y, z, 16, 1.6, 0.7, 0.04) end
function G.awaken(x, z) AI.wake(x, z, 22) end
function G.finalChase() AI.hunt(Pl.x, Pl.z); G.say("msg_run") end
function G.damage(n, fromX, fromZ)
  if mode ~= "play" or Pl.invuln > 0 then return end
  Pl.hp = Pl.hp - n
  Pl.invuln, Pl.calm = 0.9, 0
  G.hurtFlash = 0.9
  G.shake(0.35)
  sys.vibrate(0.6, 160)
  A.play("hurt", 0.9)
  F.burst("blood", Pl.x + sin(Pl.yaw) * 0.5, Pl.y + 1.3, Pl.z - cos(Pl.yaw) * 0.5, 10, 1.2, 0.6, 0.05)
  if Pl.hp <= 0 then
    Pl.hp = 0
    mode = "dead"
    stats.deaths = stats.deaths + 1
    A.play("death", 1)
    G.deadT = 0
  end
end

-- the save of the current slot: level, checkpoint, oil, health, puzzle progress
local function writeSlot(cp)
  local vars, done = {}, {}
  for k, v in pairs(G.vars) do vars[k] = v end
  for k, v in pairs(G.done) do done[k] = v end
  local s = {level = level, cpx = cp and cp.x, cpz = cp and cp.z, oil = max(Pl.oil, 50), hp = max(Pl.hp, 70), vars = vars, done = done,
    time = floor(stats.time), deaths = stats.deaths, when = sys.epoch()}
  save("slot" .. slot, s)
  save("lastSlot", slot)
end
function G.checkpoint(ent)
  G.cp = {x = ent.x, z = ent.z}
  writeSlot(G.cp)
end

-- ------------------------------------------------------------------ level loading (a coroutine, a few steps per frame)
local EXTRA = {"castle/GEO_TorchSconce", "castle/GEO_Gatehouse", "castle/GEO_WoodenDoor", "temple/GEO_Brazier", "temple/GEO_Podium",
  "sewer/GEO_Ladder"}

local function freeLevel()
  if G.N then nav.free(G.N); G.N = nil end
  if G.L then Wd.free(G.L); G.L = nil end
  F.clear()
  G.statics = {}
  G.focus = nil
end

local function startLoad(idx, s, title)
  freeLevel()
  level = idx
  loadFrac, loadLabel = 0, TR(LV[idx].name)
  mode = "loading"
  G.titleMode = title
  loader = coroutine.create(function()
    local def = LV[idx]
    G.vars, G.done = {}, {}
    if s and s.level == idx then
      for k, v in pairs(s.vars or {}) do G.vars[k] = v end
      for k, v in pairs(s.done or {}) do G.done[k] = v end
    end
    local L = Wd.new(def)
    G.L = L
    -- models: the level pieces, the entity decorations and the fixed set
    local keys, seen = {}, {}
    local function add(k) if k and not seen[k] then seen[k] = true; keys[#keys + 1] = k end end
    for _, k in ipairs(Wd.keys(L)) do add(k) end
    for _, e in ipairs(def.ents) do add(e.m) end
    for _, k in ipairs(EXTRA) do add(k) end
    for i, k in ipairs(keys) do
      Wd.model(k)
      loadFrac = 0.65 * i / #keys
      coroutine.yield()
    end
    Wd.finishCollision(L)
    coroutine.yield()
    P.build(L, G)
    F.update(0, 0, 0, 0)
    loadFrac = 0.7
    coroutine.yield()
    G.N = nav.bake(L.phys, {cell = 0.5, radius = 0.35, height = 1.7, step = 0.55, slope = 50})
    while true do
      local st = nav.state(G.N)
      if st.state ~= "baking" then
        if st.state ~= "ready" then print("cryptlight: nav " .. tostring(st.state) .. " " .. tostring(st.error)) end
        break
      end
      loadFrac = 0.7 + 0.25 * (st.progress or 0)
      coroutine.yield()
    end
    P.navReady()
    AI.build(L, G, G.N)
    Wd.prepareDraw(L)
    -- the player
    local sx, sz, yaw = def.start[1] * 4, def.start[2] * 4, def.start.yaw or 0
    if s and s.level == idx and s.cpx then sx, sz = s.cpx + 0.2, s.cpz + 1.6 end
    local dbg = G.debugStart
    if dbg then sx, sz, yaw = dbg.x * 4, dbg.z * 4, dbg.yaw; G.debugStart = nil end
    local gy = Wd.ground(L, sx, sz, 3) or L.floorY
    Pl.ctrl = phys.controller(L.phys, sx, gy + 0.05, sz, {radius = 0.3, height = 1.7, step = 0.55, slope = 50, jump = 0.1})
    phys.setLayer(L.phys, Pl.ctrl, 8)
    Pl.x, Pl.y, Pl.z, Pl.yaw, Pl.pitch = sx, gy, sz, yaw, dbg and dbg.pitch or -0.05
    Pl.hp, Pl.oil = s and s.hp or 100, s and s.oil or 100
    Pl.invuln, Pl.calm, Pl.flareCool = 1.5, 10, 0
    G.cp = s and s.cpx and {x = s.cpx, z = s.cpz} or nil
    G.playerOwner = {isPlayer = true, name = "player", tag = "player", x = sx, z = sz, props = {}}
    G.objective, G.objT = def.objective, 6
    loadFrac = 1
  end)
end

-- ------------------------------------------------------------------ renderer setup per level
local function setupRenderer(def)
  g3d.environment({sky = def.sky, ground = def.ground, intensity = def.envI or 0.8, sun = def.moon and def.moon.sun or 0})
end

local function initLights()
  g3d.clearLights()
  lights.point = g3d.addLight({type = "point", x = 0, y = 0, z = 0, color = "#FFB25A", intensity = 7, range = 9})
  lights.spot = g3d.addLight({type = "spot", x = 0, y = 0, z = 0, dx = 0, dy = 0, dz = -1, color = "#FFC888", intensity = 9, range = 15,
    inner = 16, outer = 40, shadow = true})
  lights.pool = {}
  for i = 1, 6 do
    lights.pool[i] = g3d.addLight({type = "point", x = 0, y = -50, z = 0, color = "#FF7A2E", intensity = 0, range = 6})
  end
end

local cands = {}
local function updateLights(eyeX, eyeY, eyeZ, fx, fy, fz, rx, rz)
  -- the lantern: right of and below the eye, swinging a little
  local flick = 0.9 + 0.06 * sin(t * 11.3) + 0.04 * sin(t * 27.1) + 0.03 * (random() - 0.5)
  if Pl.oil <= 0 then flick = flick * (0.6 + 0.4 * ((sin(t * 17) > -0.2) and 1 or 0.3)) end
  local lan = Pl.lantern * flick
  local lx, ly, lz = Pl.lx, Pl.ly, Pl.lz
  g3d.updateLight(lights.point, {x = lx, y = ly + 0.1, z = lz, intensity = 4.2 * lan + G.flare * 30, range = 3 + 6.5 * Pl.lantern + G.flare * 8})
  g3d.updateLight(lights.spot, {x = lx + fx * 0.1, y = ly + 0.05 + fy * 0.1, z = lz + fz * 0.1, dx = fx, dy = fy - 0.12, dz = fz,
    intensity = 6 * lan + G.flare * 20, range = 6 + 10 * Pl.lantern})
  -- the strongest other sources near the player
  local n = 0
  for i = #cands, 1, -1 do cands[i] = nil end
  for _, f in ipairs(F.flames) do
    if f.on then
      local dx, dz = f.x - eyeX, f.z - eyeZ
      cands[#cands + 1] = {x = f.x, y = f.y, z = f.z, color = f.color, int = f.int * (f.flick or 1), range = f.range, d2 = dx * dx + dz * dz}
    end
  end
  for _, s in ipairs(G.statics) do
    local dx, dz = s.x - eyeX, s.z - eyeZ
    cands[#cands + 1] = {x = s.x, y = s.y, z = s.z, color = s.color, int = s.int, range = s.range, d2 = dx * dx + dz * dz}
  end
  P.lights(cands, eyeX, eyeZ)
  AI.lights(cands, eyeX, eyeZ)
  for _, c in ipairs(cands) do
    -- prefer what is in front; fade with distance so a light that leaves the pool is already dark
    local d = sqrt(c.d2)
    local front = ((c.x - eyeX) * fx + (c.z - eyeZ) * fz) > -3 and 1 or 0.35
    c.score = c.int * front / (1 + c.d2 * 0.02)
    c.fadeK = max(0, min(1, (24 - d) / 8))
  end
  table.sort(cands, function(a, b) return a.score > b.score end)
  for i = 1, #lights.pool do
    local c = cands[i]
    if c and c.fadeK > 0 then
      g3d.updateLight(lights.pool[i], {x = c.x, y = c.y, z = c.z, color = c.color, intensity = c.int * c.fadeK, range = c.range})
    else
      g3d.updateLight(lights.pool[i], {intensity = 0, y = -50})
    end
  end
end

-- ------------------------------------------------------------------ lantern in the hand
local lanternMesh = {}
local function makeLantern()
  local iron = Wd.TEX("castle", "T_MC_Iron_BaseColor")
  local cap = g3d.mesh("cone", 0.075, 0.08, 10); cap:setTexture(iron); cap:setColor("#8A8070")
  local base = g3d.mesh("cylinder", 0.07, 0.03, 10); base:setTexture(iron); base:setColor("#7A7064")
  local bar = g3d.mesh("box", 0.012, 0.16, 0.012); bar:setColor("#3A3A3A")
  local core = g3d.mesh("sphere", 0.035, 10, 8); core:setColor("#FFC070")
  local glass = g3d.mesh("cylinder", 0.055, 0.15, 12); glass:setColor("#5A2A08")
  local ring = g3d.mesh("torus", 0.025, 0.004, 12, 6); ring:setColor("#4A4A4A")
  lanternMesh = {cap = cap, base = base, bar = bar, core = core, glass = glass, ring = ring}
end

local function drawLantern(fx, fz)
  local m = lanternMesh
  if not m.cap then return end
  local x, y, z = Pl.lx, Pl.ly, Pl.lz
  local ry = -Pl.yaw
  g3d.draw(m.base, x, y - 0.085, z, 0, ry, 0)
  g3d.draw(m.cap, x, y + 0.115, z, 0, ry, 0)
  g3d.draw(m.ring, x, y + 0.18, z, pi / 2, ry, 0)
  for i = 0, 3 do
    local a = i * pi / 2 + pi / 4 + Pl.yaw
    g3d.draw(m.bar, x + cos(a) * 0.058, y, z + sin(a) * 0.058, 0, ry, 0)
  end
  local c = Pl.lantern * (0.85 + 0.15 * sin(t * 13))
  g3d.draw(m.core, x, y - 0.01, z, 0, 0, 0, 0.6 + c * 0.5, 0.9 + c * 0.6, 0.6 + c * 0.5, "#FFE0B0", "glow unlit")
  g3d.draw(m.glass, x, y, z, 0, ry, 0, 1, 1, 1, "#FFB060", "glow unlit")
end

-- ------------------------------------------------------------------ input
local function stick()
  local sx, sy = input.stick("left")
  sx, sy = sx or 0, sy or 0
  local kx, ky = 0, 0
  if keys.w or input.down("up") then ky = ky + 1 end
  if keys.s or input.down("down") then ky = ky - 1 end
  if keys.a then kx = kx - 1 end
  if keys.d then kx = kx + 1 end
  if abs(kx) + abs(ky) > 0 then sx, sy = kx, ky end
  if T.stickOn then sx, sy = T.sx, T.sy end
  return sx, sy
end

local function look()
  local lx, ly = input.stick("right")
  lx, ly = lx or 0, ly or 0
  local kx, ky = 0, 0
  if keys.left or input.down("left") then kx = kx - 1 end
  if keys.right or input.down("right") then kx = kx + 1 end
  if keys.up then ky = ky + 1 end
  if keys.down then ky = ky - 1 end
  if abs(kx) + abs(ky) > 0 then lx, ly = kx, ky end
  return lx, ly
end

local function pressedUse() return input.pressed("zr") or input.pressed("a") or input.key("e") or input.key("space") or input.key("enter") or T.use end
local function pressedFlare() return input.pressed("x") or input.pressed("r") or input.key("f") or T.flare end
local function holdingRun() return input.down("zl") or input.down("l") or keys.shift or keys.c or T.runToggle end

-- ------------------------------------------------------------------ the player
local function updatePlayer(dt)
  local L = G.L
  local sx, sy = stick()
  local lx, ly = look()
  local sens = opt.sens
  -- tank-style turning from the touch stick (one finger can explore)
  if T.stickOn then Pl.yaw = Pl.yaw + T.sx * 1.9 * dt; sx = 0 end
  Pl.yaw = Pl.yaw + lx * 2.7 * sens * dt + (T.lookDX or 0) * 0.006 * sens
  Pl.pitch = max(-1.2, min(1.1, Pl.pitch + ly * 1.9 * sens * dt * (opt.invert and -1 or 1) - (T.lookDY or 0) * 0.006 * sens))
  T.lookDX, T.lookDY = 0, 0
  local mag = min(1, sqrt(sx * sx + sy * sy))
  local running = holdingRun() and sy > 0.3
  local speed = running and 4.4 or 2.5
  local fx, fz = sin(Pl.yaw), -cos(Pl.yaw)
  local rx, rz = cos(Pl.yaw), sin(Pl.yaw)
  local vx = (fx * sy + rx * sx) * speed
  local vz = (fz * sy + rz * sx) * speed
  if mag > 1 then vx, vz = vx / mag, vz / mag end
  -- wading through sewer water is slow
  local wet = L.def.style == "sewer" and Pl.y < 0.42
  if wet then vx, vz = vx * 0.72, vz * 0.72 end
  local r = phys.move(L.phys, Pl.ctrl, vx, vz, dt)
  Pl.x, Pl.y, Pl.z = r.x, r.y, r.z
  G.playerOwner.x, G.playerOwner.z = Pl.x, Pl.z
  Pl.moving = mag > 0.15
  Pl.running = running and Pl.moving
  -- head bob and footsteps
  if Pl.moving and r.grounded then
    local before = Pl.bob
    Pl.bob = Pl.bob + dt * (running and 11.5 or 7.2)
    if floor(before / pi) ~= floor(Pl.bob / pi) then
      local surf = wet and "step_wet" or ((L.def.style == "temple") and "step_sand" or "step_stone")
      A.play(surf, running and 0.55 or 0.32)
      if wet then F.burst("mist", Pl.x, 0.5, Pl.z, 2, 0.4, 0.8, 0.25) end
    end
  else
    Pl.bob = Pl.bob + dt * 1.2
  end
  -- oil burns down; less oil, smaller light
  Pl.oil = max(0, Pl.oil - dt * 0.62)
  local target = Pl.oil > 0 and (0.5 + 0.5 * min(1, Pl.oil / 45)) or 0.22
  Pl.lantern = Pl.lantern + (target - Pl.lantern) * min(1, dt * 2)
  if Pl.oil < 25 then G.oilShow = max(G.oilShow, 1) end
  if Pl.oil < 12 and random() < dt * 0.6 then A.play("sputter", 0.35) end
  -- flare: burn oil for a flash that stuns creatures near
  Pl.flareCool = max(0, Pl.flareCool - dt)
  if pressedFlare() and Pl.flareCool <= 0 then
    if Pl.oil >= 12 then
      Pl.oil = Pl.oil - 12
      Pl.flareCool = 2.5
      G.flare = 1
      G.oilShow = 3
      A.play("flare", 1)
      F.burst("spark", Pl.lx, Pl.ly, Pl.lz, 40, 3.5, 0.9, 0.05)
      AI.stunAll(Pl.x, Pl.z, 7.5)
    else
      G.say("msg_nooil")
    end
  end
  -- health returns slowly when nothing hurts for a while
  Pl.invuln = max(0, Pl.invuln - dt)
  Pl.calm = (Pl.calm or 0) + dt
  if Pl.calm > 5 and Pl.hp < 100 then Pl.hp = min(100, Pl.hp + dt * 5) end
  -- interaction
  G.focus = P.focus(Pl.x, Pl.z, fx, fz)
  G.usePressed = pressedUse() and true or false
  if G.usePressed and G.focus and G.focus.isExit and not G.focus.final then
    A.play("descend", 0.9)
    mode = "exit"
    fadeTo, fadeCb = 1, function()
      if level < #LV then
        startLoad(level + 1, nil)
        G.autosave = true
      end
    end
  end
  for _, e in ipairs(P.ents) do
    if e.isExit and e.final and not e.dead then
      local dx, dz = e.x - Pl.x, e.z - Pl.z
      if dx * dx + dz * dz < (e.r or 2) ^ 2 then
        mode = "ending"
        G.endT = 0
        A.stopMusic()
        A.play("relief", 1)
        local s = load("slot" .. slot, nil)
        if s then s.finished = true; save("slot" .. slot, s) end
        save("finishedOnce", true)
      end
    end
  end
end

-- ------------------------------------------------------------------ menus
local function slotLabel(i)
  local s = load("slot" .. i, nil)
  if not s then return TR("slot_empty", i), nil end
  local mins = floor((s.time or 0) / 60)
  return TR("slot_n", i) .. "  " .. TR(LV[s.level] and LV[s.level].name or "lvl1"), TR("slot_info", mins, s.deaths or 0)
end

local function anySave()
  for i = 1, 3 do if load("slot" .. i, nil) then return true end end
  return false
end

local function menuItems()
  local items = {}
  if menu.id == "main" then
    if anySave() then items[#items + 1] = {label = TR("m_continue"), id = "continue"} end
    items[#items + 1] = {label = TR("m_new"), id = "new"}
    if anySave() then items[#items + 1] = {label = TR("m_load"), id = "load"} end
    items[#items + 1] = {label = TR("m_options"), id = "options"}
    items[#items + 1] = {label = TR("m_quit"), id = "quit"}
  elseif menu.id == "new" or menu.id == "load" then
    for i = 1, 3 do
      local l, sub = slotLabel(i)
      items[#items + 1] = {label = l, sub = sub, id = "slot", slot = i, disabled = (menu.id == "load" and not sub)}
    end
    items[#items + 1] = {label = TR("m_back"), id = "back"}
  elseif menu.id == "options" then
    items[#items + 1] = {label = TR("o_sens"), id = "sens", value = string.format("%.1f", opt.sens)}
    items[#items + 1] = {label = TR("o_invert"), id = "invert", value = opt.invert and TR("on") or TR("off")}
    items[#items + 1] = {label = TR("o_motion"), id = "motion", value = opt.motion and TR("on") or TR("off")}
    items[#items + 1] = {label = TR("o_volume"), id = "volume", value = floor(opt.volume * 100 + 0.5) .. "%"}
    items[#items + 1] = {label = TR("m_back"), id = "back"}
  elseif menu.id == "pause" then
    items[#items + 1] = {label = TR("m_resume"), id = "resume"}
    items[#items + 1] = {label = TR("m_retry"), id = "retry"}
    items[#items + 1] = {label = TR("m_options"), id = "options"}
    items[#items + 1] = {label = TR("m_title"), id = "totitle"}
  elseif menu.id == "confirm" then
    items[#items + 1] = {label = TR("m_overwrite"), id = "yes"}
    items[#items + 1] = {label = TR("m_back"), id = "back"}
  end
  return items
end

local function saveOpts() save("opts", opt); A.volume = opt.volume end

local function beginGame(s)
  stats.time, stats.deaths = s and s.time or 0, s and s.deaths or 0
  A.title(false)
  startLoad(s and s.level or 1, s)
  if not s then G.autosave = true end
end

local function goTitle()
  A.stopAll()
  menu = {id = "main", sel = 1}
  startLoad(1, nil, true)
end

local function choose(it, dir)
  if not it or it.disabled then return end
  local id = it.id
  dir = dir or 0
  if id == "continue" then
    slot = load("lastSlot", 1)
    local s = load("slot" .. slot, nil)
    if not s then for i = 1, 3 do if load("slot" .. i, nil) then slot = i; s = load("slot" .. i) break end end end
    beginGame(s)
  elseif id == "new" then menu = {id = "new", sel = 1, back = menu}
  elseif id == "load" then menu = {id = "load", sel = 1, back = menu}
  elseif id == "options" then menu = {id = "options", sel = 1, back = menu}
  elseif id == "quit" then sys.exit()
  elseif id == "back" then menu = menu.back or {id = "main", sel = 1}
  elseif id == "slot" then
    if menu.id == "new" then
      if load("slot" .. it.slot, nil) then menu = {id = "confirm", sel = 2, slot = it.slot, back = menu}
      else slot = it.slot; beginGame(nil) end
    else
      slot = it.slot
      beginGame(load("slot" .. it.slot, nil))
    end
  elseif id == "yes" then
    slot = menu.slot
    save("slot" .. slot, nil)
    beginGame(nil)
  elseif id == "sens" then opt.sens = ((floor(opt.sens * 10 + 0.5) + (dir < 0 and -2 or 2) - 4) % 26 + 4) / 10; saveOpts()
  elseif id == "invert" then opt.invert = not opt.invert; saveOpts()
  elseif id == "motion" then opt.motion = not opt.motion; saveOpts()
  elseif id == "volume" then opt.volume = ((floor(opt.volume * 10 + 0.5) + (dir < 0 and -1 or 1)) % 11) / 10; saveOpts()
  elseif id == "resume" then mode = "play"; menu = {id = "main", sel = 1}
  elseif id == "retry" then
    mode = "play"
    beginGame(load("slot" .. slot, nil))
  elseif id == "totitle" then goTitle()
  end
end

local function menuInput()
  local items = menuItems()
  local up = input.pressed("up") or input.key("up") or input.key("w")
  local down = input.pressed("down") or input.key("down") or input.key("s")
  local sy = select(2, input.stick("left"))
  menu.stickT = (menu.stickT or 0) - 1 / 60
  if abs(sy or 0) > 0.6 and menu.stickT <= 0 then
    if sy > 0 then up = true else down = true end
    menu.stickT = 0.22
  elseif abs(sy or 0) < 0.3 then menu.stickT = 0 end
  local n = #items
  if up then menu.sel = (menu.sel - 2) % n + 1; A.play("tick", 0.4) end
  if down then menu.sel = menu.sel % n + 1; A.play("tick", 0.4) end
  local it = items[menu.sel]
  if input.pressed("a") or input.key("enter") or input.key("space") then A.play("select", 0.6); choose(it, 1) end
  if (input.pressed("left") or input.key("left")) and it and it.value then choose(it, -1) end
  if (input.pressed("right") or input.key("right")) and it and it.value then choose(it, 1) end
  if input.pressed("b") or input.key("escape") then
    if menu.id == "pause" then mode = "play"; menu = {id = "main", sel = 1}
    elseif menu.back then menu = menu.back end
  end
end

-- ------------------------------------------------------------------ app
-- test hooks (emulator screenshots): "play:<level>:<cellX>:<cellZ>:<yawDeg>[:<pitchDeg>]" starts there,
-- "tp:<cellX>:<cellZ>:<yawDeg>[:<pitchDeg>]" moves the player in the running level, "title" goes to the title
local function parseArg(arg)
  if type(arg) ~= "string" then return nil end
  local parts = {}
  for p in arg:gmatch("[^:]+") do parts[#parts + 1] = p end
  return parts
end
local function debugArg(arg)
  local p = parseArg(arg)
  if not p or not p[1] then return false end
  if p[1] == "play" and p[2] then
    G.debugStart = {x = tonumber(p[3]) or 0, z = tonumber(p[4]) or 0, yaw = math.rad(tonumber(p[5]) or 0), pitch = math.rad(tonumber(p[6]) or -3)}
    slot = 3
    stats.time, stats.deaths = 0, 0
    A.title(false)
    startLoad(tonumber(p[2]) or 1, nil)
    return true
  elseif p[1] == "tp" and G.L and Pl.ctrl then
    local x, z = (tonumber(p[2]) or 0) * 4, (tonumber(p[3]) or 0) * 4
    local gy = Wd.ground(G.L, x, z, 3) or G.L.floorY
    phys.setPos(G.L.phys, Pl.ctrl, x, gy + 0.05, z)
    Pl.x, Pl.y, Pl.z = x, gy, z
    Pl.yaw, Pl.pitch = math.rad(tonumber(p[4]) or 0), math.rad(tonumber(p[5]) or -3)
    Pl.lx = nil
    mode = "play"
    return true
  elseif p[1] == "oil" then
    Pl.oil = tonumber(p[2]) or Pl.oil
    return true
  elseif p[1] == "title" then
    goTitle()
    return true
  end
  return false
end

function app.open(arg) debugArg(arg) end

function app.load(arg)
  local r = g3d.renderer("pbr")
  print("cryptlight: renderer " .. tostring(r))
  g3d.shadows({enabled = true, quality = "low", distance = 16})
  g3d.postfx({exposure = 1.0, tonemap = "aces", bloom = 0.11, threshold = 0.8, msaa = 0})
  local o = load("opts", nil)
  if o then for k, v in pairs(o) do opt[k] = v end end
  A.volume = opt.volume
  F.init()
  U.init()
  makeLantern()
  initLights()
  if not debugArg(arg) then goTitle() end
end

function app.update(dt)
  dt = min(dt, 0.05)
  t = t + dt
  hintCool = hintCool - dt
  local t0 = sys.time()
  if mode == "loading" then
    if loader then
      local ok, err = coroutine.resume(loader)
      if not ok then print("cryptlight: load error " .. tostring(err)); loader = nil end
      if loader and coroutine.status(loader) == "dead" then
        loader = nil
        setupRenderer(LV[level])
        mode = G.titleMode and "title" or "play"
        fade, fadeTo = 1, 0
        if mode == "title" then A.title(true) end
        if G.autosave then writeSlot(nil); G.autosave = nil end
      end
    end
    return
  end
  -- fade
  if fadeTo ~= fade then
    local step = dt * 1.6
    if abs(fadeTo - fade) <= step then
      fade = fadeTo
      if fadeCb then local cb = fadeCb; fadeCb = nil; cb() end
    else fade = fade + (fadeTo > fade and step or -step) end
  end
  if mode == "title" then
    menuInput()
    F.update(dt, t, 28, 8)
    P.update(dt)
    return
  end
  if mode == "pause" then menuInput(); return end
  if mode == "play" then
    stats.time = stats.time + dt
    if input.pressed("plus") or input.key("escape") or input.key("p") or T.pause then
      mode = "pause"; menu = {id = "pause", sel = 1}; T.pause = nil
      return
    end
    updatePlayer(dt)
    P.update(dt)
    AI.update(dt, Pl)
    A.update(dt, AI.danger, Pl.hp / 100, true)
  elseif mode == "dead" then
    G.deadT = G.deadT + dt
    if G.deadT > 2.2 and not fadeCb then
      fadeTo, fadeCb = 1, function()
        local d, tm = stats.deaths, stats.time
        beginGame(load("slot" .. slot, nil))
        stats.deaths, stats.time = d, tm
      end
    end
  elseif mode == "ending" then
    G.endT = G.endT + dt
    if G.endT > 2 and (input.pressed("a") or input.key("enter") or T.use) and G.endT > 4 then goTitle() end
  end
  T.use, T.flare = nil, nil
  G.flare = max(0, (G.flare or 0) - dt * 2.2)
  G.hurtFlash = max(0, G.hurtFlash - dt * 1.4)
  G.msgT = max(0, G.msgT - dt)
  G.objT = max(0, G.objT - dt * 0.5)
  G.oilShow = max(0, G.oilShow - dt * 0.6)
  G.shakeT = max(0, G.shakeT - dt)
  F.update(dt, t, Pl.x, Pl.z)
  if random() < dt * 6 then F.dustAround(Pl.x, Pl.y + 1.5, Pl.z, 1) end
  frameMs = frameMs * 0.9 + (sys.time() - t0) * 1000 * 0.1
end

local function drawWorld(w, h, ex, ey, ez, yaw, pitch, fov)
  local def = LV[level]
  local L = G.L
  local fx, fy, fz = sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)
  gfx.clear(def.fog[1])
  g3d.begin(0, 0, w, h, fov or 72, 0.05, 60)
  g3d.camera(ex, ey, ez, ex + fx, ey + fy, ez + fz)
  if def.moon then
    g3d.light(def.moon.dx, def.moon.dy, def.moon.dz, def.ambient, def.moon.color)
  else
    g3d.light(0.2, 1, 0.1, def.ambient, "#000000")
  end
  g3d.fog(def.fog[1], def.fog[2], def.fog[3])
  updateLights(ex, ey, ez, fx, fy, fz)
  Wd.draw(L, ex, ey, ez, sin(yaw), -cos(yaw), def.fog[3] + 4)
  P.draw(t, 1 / 60, ex, ez)
  AI.draw(t, ex, ez)
  if mode ~= "title" then drawLantern(fx, fz) end
  F.draw(yaw, Pl.lx or ex, Pl.ly or ey, Pl.lz or ez, Pl.lantern)
  local tris = g3d.finish()
  return tris
end

function app.draw(w, h)
  W, H = w, h
  local t0 = sys.time()
  if mode == "boot" or mode == "loading" then
    U.loading(w, h, loadFrac, loadLabel, t)
    return
  end
  local tris = 0
  if mode == "title" then
    -- the courtyard of the first level as a living backdrop
    local a = t * 0.05
    local ex, ey, ez = 28 + sin(a) * 2.2, 1.75 + sin(t * 0.3) * 0.08, 7.0 + cos(a * 0.7) * 1.2
    Pl.lx, Pl.ly, Pl.lz, Pl.lantern = ex + 0.6, ey - 0.4, ez - 0.8, 0.85
    tris = drawWorld(w, h, ex, ey, ez, sin(a * 1.3) * 0.25 + pi, -0.08 + sin(t * 0.21) * 0.03, 64)
    U.menu(w, h, menu.id == "main" and "logo" or TR("t_" .. menu.id), menuItems(), menu.sel, t, {touch = input.touch()})
  else
    -- camera: eye with bob, breathing, shake
    local bobA = (opt.motion and 1 or 0) * (Pl.running and 1.7 or 1)
    local by = sin(Pl.bob * 2) * 0.03 * bobA + sin(t * 1.6) * 0.008
    local bx = cos(Pl.bob) * 0.022 * bobA
    local sh = G.shakeT > 0 and G.shakeT * 0.12 or 0
    local rx, rz = cos(Pl.yaw), sin(Pl.yaw)
    local ex = Pl.x + rx * bx + (random() - 0.5) * sh
    local ey = Pl.y + 1.62 + by + (random() - 0.5) * sh
    local ez = Pl.z + rz * bx + (random() - 0.5) * sh
    local fx, fz = sin(Pl.yaw), -cos(Pl.yaw)
    -- the lantern hangs right of and below the eye and lags a little
    local tx = ex + rx * 0.27 + fx * 0.55
    local ty = ey - 0.40 + sin(Pl.bob) * 0.012 * bobA
    local tz = ez + rz * 0.27 + fz * 0.55
    if not Pl.lx then Pl.lx, Pl.ly, Pl.lz = tx, ty, tz end
    local k = 0.35
    Pl.lx, Pl.ly, Pl.lz = Pl.lx + (tx - Pl.lx) * k, Pl.ly + (ty - Pl.ly) * k, Pl.lz + (tz - Pl.lz) * k
    tris = drawWorld(w, h, ex, ey, ez, Pl.yaw, Pl.pitch, 72)
    if mode == "play" or mode == "exit" then
      G.touch = input.touch()
      U.hud(w, h, G, Pl, t)
      if G.touch then U.drawTouch(w, h, T) end
    elseif mode == "pause" then
      U.hud(w, h, G, Pl, t)
      U.menu(w, h, TR("t_pause"), menuItems(), menu.sel, t, {touch = input.touch()})
    elseif mode == "dead" then
      U.hud(w, h, G, Pl, t)
      local a = min(1, G.deadT / 1.2)
      gfx.color(0, 0, 0, floor(a * 200))
      gfx.rect(0, 0, w, h)
      U.card(w, h, {TR("dead_title"), TR("dead_sub")}, a)
    elseif mode == "ending" then
      local a = min(1, G.endT / 2)
      gfx.color(0, 0, 0, floor(a * 235))
      gfx.rect(0, 0, w, h)
      local mins = floor(stats.time / 60)
      U.card(w, h, {TR("end_title"), TR("end_sub"), TR("end_stats", mins, stats.deaths), G.endT > 4 and TR("end_continue") or ""}, a)
    end
  end
  if fade > 0.001 then
    gfx.color(0, 0, 0, floor(fade * 255))
    gfx.rect(0, 0, w, h)
  end
  -- frame time log for measurements (relative only)
  local ms = (sys.time() - t0) * 1000
  perfLog[#perfLog + 1] = ms
  if t - lastPerf > 5 and mode == "play" then
    local s, mx = 0, 0
    for _, v in ipairs(perfLog) do s = s + v; mx = max(mx, v) end
    print(string.format("cryptlight perf level=%d draw_ms=%.2f max=%.2f upd_ms=%.2f tris=%d parts=%d fps=%d", level, s / #perfLog, mx, frameMs, floor(tonumber(tris) or 0), floor(F.count()), floor(tonumber(sys.fps()) or 0)))
    perfLog, lastPerf = {}, t
  end
end

function app.event(e)
  if e.type == "keydown" and e.key then keys[e.key] = true; keys.shift = e.shift or nil
  elseif e.type == "keyup" and e.key then keys[e.key] = nil; keys.shift = e.shift or nil end
  if e.touch or e.type == "mousedown" or e.type == "mousemove" or e.type == "mouseup" then
    if mode == "title" or mode == "pause" then
      if e.type == "mousedown" then
        local i = U.hitMenu(e.x, e.y)
        if i then
          local items = menuItems()
          if i == menu.sel or e.touch then menu.sel = i; choose(items[i], 1) else menu.sel = i end
        end
      end
      return
    end
    if mode == "ending" and e.type == "mousedown" then T.use = true return end
    if mode ~= "play" or not e.touch then return end
    local b = U.touchLayout(W, H)
    if e.type == "mousedown" then
      local hit = U.hitTouch(e.x, e.y)
      if hit == "use" then T.use = true
      elseif hit == "flare" then T.flare = true
      elseif hit == "run" then T.runToggle = not T.runToggle
      elseif hit == "pause" then T.pause = true
      elseif e.x < W * 0.45 then
        T.stickOn, T.ox, T.oy, T.sx, T.sy = true, e.x, e.y, 0, 0
      else
        T.lookOn, T.lx, T.ly = true, e.x, e.y
      end
    elseif e.type == "mousemove" then
      if T.stickOn then
        local r = b.stick.r
        T.sx = max(-1, min(1, (e.x - T.ox) / r))
        T.sy = max(-1, min(1, -(e.y - T.oy) / r))
      elseif T.lookOn then
        T.lookDX = (T.lookDX or 0) + (e.x - T.lx)
        T.lookDY = (T.lookDY or 0) + (e.y - T.ly)
        T.lx, T.ly = e.x, e.y
      end
    elseif e.type == "mouseup" then
      T.stickOn, T.lookOn, T.sx, T.sy = false, false, 0, 0
    end
  end
end

function app.focus(on)
  keys = {}
  if not on and mode == "play" then mode = "pause"; menu = {id = "pause", sel = 1} end
end

function app.suspend()
  if mode == "play" then mode = "pause"; menu = {id = "pause", sel = 1} end
end

function app.close()
  A.stopAll()
  return true
end

return app
