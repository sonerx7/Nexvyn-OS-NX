-- Crypt Light: interactive things of a level. Their rules run as Game Engine Logic 2.0 machines (nexvyn.ge_logic):
-- library behaviours (lever, pressure_plate, door_switch, door_key, trap_spikes, pickup_key) and a few machines of
-- our own in the same data format (timed gate, gate that needs two levers, seals, shrines, oil).
local LG = require("nexvyn.ge_logic")
local LIB = require("cl_behaviours")
local Wd = require("cl_world")
local F = require("cl_fx")

local P = {}
local sin, cos, pi, sqrt, abs, min, max = math.sin, math.cos, math.pi, math.sqrt, math.abs, math.min, math.max
local G         -- the game (set in P.init)
local ents = {}
local meshes = {}
P.ents = ents

local function dist2(a, x, z) local dx, dz = a.x - x, a.z - z; return dx * dx + dz * dz end

-- ------------------------------------------------------------------ meshes
function P.loadMeshes()
  if meshes.bar then return end
  local iron = Wd.TEX("castle", "T_MC_Iron_BaseColor")
  local stone = Wd.TEX("castle", "T_MC_Stone_BaseColor")
  local sand = Wd.TEX("temple", "T_DT_Sandstone_BaseColor")
  local relief = Wd.TEX("temple", "T_DT_Relief_BaseColor")
  local wood = Wd.TEX("castle", "T_MC_Wood_BaseColor")
  local function mk(kind, tex, color, ...)
    local m = g3d.mesh(kind, ...)
    if tex then m:setTexture(tex) end
    if color then m:setColor(color) end
    return m
  end
  meshes.bar = mk("cylinder", iron, "#9A9A9A", 0.04, 1, 8)
  meshes.rail = mk("box", iron, "#8A8A8A", 1, 0.09, 0.09)
  meshes.spike = mk("cone", iron, "#B0B0B0", 0.06, 0.5, 6)
  meshes.spikeBase = mk("box", iron, "#3A3A3A", 1.7, 0.06, 1.7)
  meshes.plate = mk("box", stone, "#9A9890", 1.1, 0.1, 1.1)
  meshes.plateRim = mk("box", stone, "#4A4844", 1.4, 0.04, 1.4)
  meshes.leverBase = mk("box", iron, "#6A6A6A", 0.36, 0.5, 0.14)
  meshes.leverArm = mk("cylinder", iron, "#B0A890", 0.035, 0.6, 8)
  meshes.knob = mk("sphere", wood, "#C08050", 0.07, 10, 8)
  meshes.keyRing = mk("torus", nil, "#E8B850", 0.07, 0.018, 16, 8)
  meshes.keyShaft = mk("box", nil, "#E8B850", 0.025, 0.2, 0.025)
  meshes.flask = mk("sphere", nil, "#FF9A30", 0.085, 14, 10)
  meshes.neck = mk("cylinder", nil, "#5A4030", 0.03, 0.09, 8)
  meshes.slab = mk("box", relief, "#B8A890", 4, 4.4, 0.6)
  meshes.ring = mk("torus", nil, "#5FD4C8", 0.42, 0.03, 32, 6)
  meshes.dark = mk("box", nil, "#000000", 2.6, 0.02, 2.6)
  meshes.coal = mk("sphere", nil, "#3A1A0A", 0.16, 8, 6)
  meshes.halo = mk("sphere", nil, "#2A2010", 0.5, 12, 8)
  for _, k in ipairs({"flask", "keyRing", "keyShaft", "ring"}) do
    g3d.material(meshes[k], {metallic = k == "flask" and 0 or 0.9, roughness = 0.3, emissive = k == "ring" and "#5FD4C8" or (k == "flask" and "#FF8A20" or "#C08020"),
      emissiveStrength = k == "ring" and 2.5 or 1.2})
  end
  meshes.wood = wood
  meshes.sand = sand
end

-- ------------------------------------------------------------------ the world adapter of ge_logic
local function adapter()
  local w = {}
  function w.matches(owner, to)
    if to == "@all" or to == "@any" then return true end
    if to == "@player" then return owner.isPlayer end
    return owner.name == to or owner.tag == to
  end
  function w.var(name) return G.vars[name] or 0 end
  function w.setVar(name, v) G.vars[name] = v end
  function w.nearest(owner, sel) if sel == "@player" or sel == "player" then return G.playerOwner end end
  function w.pos(e) return e.x, e.z end
  function w.heading() return 0, 1 end
  function w.alive(o) return not o.dead end
  function w.touching(owner, tag)
    if tag ~= "@player" and tag ~= "player" and tag ~= "@any" then return nil end
    local p = G.playerOwner
    if owner.needsFocus then
      if G.focus ~= owner.ent then return nil end
    elseif dist2(owner, p.x, p.z) > (owner.touchR or 1) ^ 2 then
      return nil
    end
    return p
  end
  function w.input(b, mode)
    if b == "use" or b == "talk" then return G.usePressed end
    return false
  end
  function w.setProp(owner, prop, v)
    owner.props[prop] = v
    if owner.onProp then owner.onProp(prop, v) end
  end
  function w.anim(owner, name)
    if owner.anim ~= name then owner.anim, owner.animT = name, 0 end
  end
  function w.sound(s) G.sfx(s) end
  function w.say(t) G.say(t) end
  function w.hurt(who, n) if who == G.playerOwner then G.damage(n * 5) end end
  function w.heal() end
  function w.destroy(o) if not o.dead then o.dead = true; if o.onDestroy then o.onDestroy() end end end
  function w.save(owner) G.checkpoint(owner.ent) end
  function w.rand() return math.random() end
  function w.shake() G.shake(0.3) end
  return w
end

-- ------------------------------------------------------------------ helpers
local function owner(e, tag)
  local o = {name = e.id or tag, tag = tag, x = e.x, z = e.z, y = e.y, props = {}, anim = nil, animT = 0, ent = e}
  e.owner = o
  return o
end

local function attachLib(e, id, given, initial)
  local def = LIB[id]
  local m = LG.build(def, given, true)
  if initial then m.initial = initial end
  for k, v in pairs(def.flags or {}) do e.owner.props[k] = v end
  e.inst = LG.attach(e.owner, m, m.params)
end
local function attachOwn(e, machine, initial)
  local m = LG.build({machine = machine, params = {}}, {}, true)
  if initial then m.initial = initial end
  e.inst = LG.attach(e.owner, m, m.params)
end

local function sidePos(L, c, side, inset)
  local x, z = c[1] * 4, c[2] * 4
  local d = Wd.SIDE[side]
  local face = (L.def.style == "sewer") and 1.62 or 1.88
  return x + d[1] * (face - (inset or 0)), z + d[2] * (face - (inset or 0)), d
end

-- a solid blocker (a gate or a door): physics box + nav blocker, toggled by the machine's "solid" property
local function blocker(e, hx, hy, hz)
  e.solidOn = function(on)
    if not G.N then e.pendingSolid = on; return end
    if on and not e.body then
      e.body = phys.addBox(G.L.phys, e.x, e.y + hy, e.z, hx, hy, hz)
      if G.N then e.navb = nav.block(G.N, e.x, e.y, e.z, max(hx, hz) * 0.55, 3) end
    elseif not on and e.body then
      phys.remove(G.L.phys, e.body); e.body = nil
      if e.navb and G.N then nav.unblock(G.N, e.navb); e.navb = nil end
    end
  end
  e.owner.onProp = function(prop, v) if prop == "solid" then e.solidOn(v) end end
end

-- ------------------------------------------------------------------ entity kinds
local K = {}

K.torch = function(e, L)
  local x, z, d = sidePos(L, e.c, e.side, 0)
  local ry = (e.side == "n") and -pi / 2 or (e.side == "s" and pi / 2 or (e.side == "e" and pi or 0))
  local y = L.floorY + (L.def.style == "sewer" and 1.25 or 1.65)
  Wd.piece(L, "castle/GEO_TorchSconce", x, y, z, ry, 1, {r = 1})
  e.flame = F.torch(x - d[1] * 0.11, y + 0.62, z - d[2] * 0.11)
  -- the light sits a little off the wall: a light touching it makes a hard, stretched hot spot
  e.flame.x, e.flame.z = x - d[1] * 0.55, z - d[2] * 0.55
end

K.brazier = function(e, L)
  local y = Wd.ground(L, e.x, e.z) or L.floorY
  Wd.piece(L, "temple/GEO_Brazier", e.x, y, e.z, 0, 1, {r = 1.5})
  e.flame = F.brazier(e.x, y + 1.35, e.z)
  e.flame.on = not e.unlit
  G.box(e.x, y + 0.7, e.z, 0.35, 0.7, 0.35)
end

K.deco = function(e, L)
  local m = Wd.model(e.m)
  local s = e.s or 1
  local p
  if e.side then
    local x, z = sidePos(L, e.c, e.side, 0.15)
    local ry = (e.side == "n") and 0 or (e.side == "s" and pi or (e.side == "e" and -pi / 2 or pi / 2))
    p = Wd.piece(L, e.m, x, (e.y or 0) + 0.8, z, ry, s, {r = 3})
  else
    local y = e.y or (e.out and 0 or (Wd.ground(L, e.x, e.z, 2.5) or L.floorY))
    p = Wd.piece(L, e.m, e.x, y, e.z, e.ry or 0, s, {r = 6, sx = e.sx, sy = e.sy, sz = e.sz, tint = e.tint})
  end
  if m and (e.col or 0) > 0 then
    local info = m:info()
    local function v3(t) return {x = t.x or t[1] or 0, y = t.y or t[2] or 0, z = t.z or t[3] or 0} end
    local mn, mx = v3(info.min or {}), v3(info.max or {})
    local sx, sy, sz = (e.sx or 1) * s, (e.sy or 1) * s, (e.sz or 1) * s
    local c, sn = cos(p.ry), sin(p.ry)
    local hx = (mx.x - mn.x) * 0.5 * sx * e.col
    local hz = (mx.z - mn.z) * 0.5 * sz * e.col
    local ax, az = abs(c) * hx + abs(sn) * hz, abs(sn) * hx + abs(c) * hz
    local ox, oz = (mx.x + mn.x) * 0.5 * sx, (mx.z + mn.z) * 0.5 * sz
    local wx, wz = p.x + ox * c + oz * sn, p.z - ox * sn + oz * c
    local hy = (mx.y - mn.y) * 0.5 * sy
    G.box(wx, p.y + mn.y * sy + hy, wz, max(0.1, ax), hy, max(0.1, az))
  end
  if m then
    local sz = m:info().size or {}
    p.r = max(2, ((sz.w or sz[1] or 2) + (sz.d or sz[3] or 2)) * 0.5 * s)
  end
end

K.gatehouse = function(e, L)
  local x, z = e.c[1] * 4 - 2, e.c[2] * 4 + 0.8
  local p = Wd.piece(L, "castle/GEO_Gatehouse", x, 0, z, 0, 1, {r = 5})
  local m = Wd.model("castle/GEO_Gatehouse")
  if m then phys.addModel(L.phys, m, {x = x, y = 0, z = z}) end
  F.torch(e.c[1] * 4 - 1.55, 3.0, e.c[2] * 4 - 0.6, 0.8)
  F.torch(e.c[1] * 4 + 1.55, 3.0, e.c[2] * 4 - 0.6, 0.8)
end

K.mist = function(e, L) F.mist(e.x, L.floorY, e.z, e.r or 5) end

K.shaftlight = function(e, L)
  G.statics[#G.statics + 1] = {x = e.x, y = e.y or 6.5, z = e.z, color = "#6E8CC0", int = 8, range = (e.y or 6.5) + 3}
  F.beam(e.x, L.floorY, e.z)
end

K.candles = function(e, L)
  local y = Wd.ground(L, e.x, e.z, 2) or L.floorY
  local fl = F.torch(e.x, y + 0.85, e.z, 0.35)
  fl.int, fl.range = 2.2, 3.5
end

K.hatch = function(e, L)
  e.y = L.floorY + 0.02
  Wd.piece(L, "sewer/GEO_Ladder", e.x - 0.9, -3.0, e.z, 0, 1, {r = 3})
  e.draw = function() g3d.draw(meshes.dark, e.x, e.y, e.z, 0, 0, 0, 1, 1, 1, "#000000", "unlit") end
end

-- checkpoint: a ward flame on a small plinth; walking to it lights it and saves
K.shrine = function(e, L)
  local y = Wd.ground(L, e.x, e.z) or L.floorY
  e.y = y
  Wd.piece(L, "temple/GEO_Podium", e.x, y, e.z, 0, 1, {r = 2, sx = 0.22, sy = 0.62, sz = 0.22})
  G.box(e.x, y + 0.37, e.z, 0.45, 0.37, 0.45)
  local o = owner(e, "shrine")
  o.touchR = 1.8
  e.prompt = nil
  e.lit = false
  local done = G.done[e.id]
  attachOwn(e, {initial = "idle", states = {
    {id = "idle", transitions = {{to = "lit", ["if"] = {{t = "touch", tag = "@player"}}, ["do"] = {{t = "sound", s = "ward"}, {t = "say", text = "msg_saved"}, {t = "save"}}}}},
    {id = "lit", enter = {{t = "anim", name = "lit"}}, transitions = {}},
  }}, done and "lit" or nil)
  e.update = function()
    if e.owner.anim == "lit" and not e.lit then
      e.lit = true
      F.ward(e.x, y + 0.85, e.z)
    end
  end
  e.draw = function(t)
    if not e.lit then
      g3d.draw(meshes.coal, e.x, y + 0.78, e.z, 0, t * 0.1, 0, 1, 0.5, 1, "#5A2A10")
    end
  end
end

K.key = function(e, L)
  local o = owner(e, "key")
  o.touchR = 1.7
  if G.done[e.id] then e.dead = true; return end
  attachLib(e, "pickup_key", {var = "key", sound = "key", text = "msg_key"})
  o.onDestroy = function() G.done[e.id] = true; e.dead = true; G.pickupFx(e.x, (e.y or 0.85) + 0.15, e.z, "#E8B850") end
  e.light = {color = "#E8B850", int = 1.6, range = 2.2}
  e.draw = function(t)
    local y = (e.y or 0.85) + 0.12 + sin(t * 2) * 0.04
    g3d.draw(meshes.keyRing, e.x, y + 0.12, e.z, pi / 2, t * 1.2, 0)
    g3d.draw(meshes.keyShaft, e.x, y, e.z, 0, t * 1.2, 0)
  end
end

K.oil = function(e, L)
  local o = owner(e, "oil")
  o.touchR = 1.2
  if G.done[e.id] then e.dead = true; return end
  e.y = (Wd.ground(L, e.x, e.z) or L.floorY)
  attachOwn(e, {initial = "wait", states = {
    {id = "wait", transitions = {{to = "done", ["if"] = {{t = "touch", tag = "@player"}}, ["do"] = {{t = "sound", s = "oil"}, {t = "say", text = "msg_oil"}, {t = "destroy"}}}}},
    {id = "done", transitions = {}},
  }})
  o.onDestroy = function() G.done[e.id] = true; e.dead = true; G.addOil(40); G.pickupFx(e.x, e.y + 0.2, e.z, "#FF9A30") end
  e.light = {color = "#FF8A30", int = 1.2, range = 2}
  e.draw = function(t)
    g3d.draw(meshes.flask, e.x, e.y + 0.1, e.z, 0, 0, 0, 1, 1.15, 1)
    g3d.draw(meshes.neck, e.x, e.y + 0.22, e.z)
  end
end

K.lever = function(e, L)
  local x, z, d = sidePos(L, e.c, e.side, 0.05)
  e.x, e.z = x, z
  e.y = L.floorY + 1.1
  e.d = d
  local o = owner(e, "lever")
  o.needsFocus = true
  e.prompt = "act_pull"
  e.focusR = 2.7
  local on = e.var and (G.vars[e.var] or 0) >= 1
  if e.var then
    attachOwn(e, {initial = "off", states = {
      {id = "off", enter = {{t = "anim", name = "off"}}, transitions = {{to = "on", ["if"] = {{t = "touch", tag = "@player"}, {t = "input", b = "use", mode = "pressed"}},
        ["do"] = {{t = "setvar", name = e.var, n = 1}, {t = "send", msg = e.msg, to = "@all"}, {t = "sound", s = "lever"}, {t = "say", text = "msg_lever"}}}}},
      {id = "on", enter = {{t = "anim", name = "on"}}, transitions = {}},
    }}, on and "on" or nil)
  else
    attachLib(e, "lever", {on = e.on, off = e.off}, G.done[e.id] and "on" or nil)
    if G.done[e.id] then LG.send(e.on, "@all", o) end
  end
  e.angle = on and 2.3 or 0.6
  e.draw = function(t, dt)
    local want = (o.anim == "on") and 2.3 or 0.6
    e.angle = e.angle + (want - e.angle) * min(1, dt * 10)
    if o.anim == "on" and e.id and not e.var then G.done[e.id] = true end
    if o.anim == "off" and e.id and not e.var then G.done[e.id] = nil end
    local ry = Wd.yawTo(-d[1], -d[2])
    g3d.draw(meshes.leverBase, x, e.y, z, 0, ry, 0)
    -- the arm pivots at the base: up and away from the wall (off) or swung down (on)
    local a = e.angle
    local ax, az = -d[1], -d[2]
    local ox, oy = sin(a) * 0.3, cos(a) * 0.3
    local rx, rz = 0, 0
    if e.side == "n" then rx = a elseif e.side == "s" then rx = -a elseif e.side == "e" then rz = a else rz = -a end
    g3d.draw(meshes.leverArm, x + ax * (0.1 + ox), e.y + oy, z + az * (0.1 + ox), rx, 0, rz)
    g3d.draw(meshes.knob, x + ax * (0.1 + ox * 2), e.y + oy * 2, z + az * (0.1 + ox * 2))
  end
end

local function gateVisual(e, L, width, height, bars)
  e.lift, e.liftWant = 0, 0
  e.width, e.height = width, height
  local axisX = e.axis ~= "z"
  e.draw = function(t, dt)
    e.liftWant = (e.owner.props.solid == false) and (height - 0.2) or 0
    local was = e.lift
    e.lift = e.lift + max(-dt * 3.5, min(dt * 1.4, e.liftWant - e.lift))
    if abs(e.lift - was) > 0.001 and not e.rumble then e.rumble = true end
    local y0 = e.y + height * 0.5 + e.lift
    for i = 0, bars - 1 do
      local u = -width * 0.5 + (i + 0.5) * width / bars
      local bx, bz = axisX and (e.x + u) or e.x, axisX and e.z or (e.z + u)
      g3d.draw(meshes.bar, bx, y0, bz, 0, 0, 0, 1, height, 1)
    end
    for _, hh in ipairs({0.25, 0.6, 0.95}) do
      g3d.draw(meshes.rail, e.x, e.y + height * hh + e.lift, e.z, 0, axisX and 0 or pi / 2, 0, width, 1, 1)
    end
  end
end

K.gate = function(e, L)
  e.y = L.floorY
  if L.def.style == "sewer" then e.y = 0.2 end
  local o = owner(e, "gate")
  local axisX = e.axis ~= "z"
  local w = (L.def.style == "sewer") and 3.5 or 3.6
  blocker(e, axisX and w * 0.5 or 0.15, 1.8, axisX and 0.15 or w * 0.5)
  if L.def.style ~= "sewer" then
    -- a gatehouse arch frames the portcullis
    local gx, gz = e.x - 2, e.z + 0.8
    Wd.piece(L, "castle/GEO_Gatehouse", gx, 0, gz, 0, 1, {r = 5})
    local m = Wd.model("castle/GEO_Gatehouse")
    if m then phys.addModel(L.phys, m, {x = gx, y = 0, z = gz}) end
    w = 2.4
  end
  gateVisual(e, L, w, L.def.style == "sewer" and 3.3 or 3.0, L.def.style == "sewer" and 11 or 8)
  local open = G.done[e.id]
  if e.need then
    local conds = {}
    for _, v in ipairs(e.need) do conds[#conds + 1] = {t = "var", name = v, op = ">=", n = 1} end
    attachOwn(e, {initial = "closed", states = {
      {id = "closed", enter = {{t = "set", prop = "solid", v = true}}, transitions = {{to = "open", ["if"] = conds, ["do"] = {{t = "sound", s = "gate"}, {t = "say", text = "msg_gate"}}}}},
      {id = "open", enter = {{t = "set", prop = "solid", v = false}}, transitions = {}},
    }}, open and "open" or nil)
    e.persist = true
  elseif e.timed then
    attachOwn(e, {initial = "closed", states = {
      {id = "closed", enter = {{t = "set", prop = "solid", v = true}}, transitions = {{to = "open", on = e.open, ["do"] = {{t = "sound", s = "gate"}}}}},
      {id = "open", enter = {{t = "set", prop = "solid", v = false}}, transitions = {{to = "closed", after = e.timed, ["do"] = {{t = "sound", s = "gate"}}}}},
    }})
    e.timedGate = true
  else
    attachLib(e, "door_switch", {open = e.open, close = e.close, sound = "gate"}, open and "open" or nil)
  end
  if open then e.lift = 2.8 end
end

K.door = function(e, L)
  e.y = L.floorY
  local o = owner(e, "door")
  blocker(e, 1.6, 1.6, 0.2)
  local gx, gz = e.x - 2, e.z + 0.8
  Wd.piece(L, "castle/GEO_Gatehouse", gx, 0, gz, 0, 1, {r = 5})
  local m = Wd.model("castle/GEO_Gatehouse")
  if m then phys.addModel(L.phys, m, {x = gx, y = 0, z = gz}) end
  local open = G.done[e.id]
  attachLib(e, "door_key", {var = e.key or "key", need = 1, near = 2.4, sound = "door"}, open and "open" or nil)
  e.swing = open and 1.45 or 0
  local door = Wd.model("castle/GEO_WoodenDoor")
  e.draw = function(t, dt)
    local want = (o.props.solid == false) and 1.45 or 0
    if o.props.solid == false then G.done[e.id] = true end
    e.swing = e.swing + (want - e.swing) * min(1, dt * 2.5)
    if door then g3d.draw(door, e.x - 1.0, e.y, e.z + 0.05, 0, -e.swing, 0) end
  end
  e.update = function()
    if o.props.solid ~= false and G.playerOwner and dist2(o, G.playerOwner.x, G.playerOwner.z) < 2.6 * 2.6 and (G.vars.key or 0) < 1 then G.hint("msg_locked") end
  end
end

K.plate = function(e, L)
  e.y = (Wd.ground(L, e.x, e.z) or L.floorY)
  local o = owner(e, "plate")
  o.touchR = 0.75
  attachLib(e, "pressure_plate", {on = e.on, off = e.off or "plate_off", who = "@player"})
  e.press = 0
  e.draw = function(t, dt)
    local want = (o.anim == "down") and 1 or 0
    if want == 1 and e.press < 0.5 then G.sfx("plate") end
    e.press = e.press + (want - e.press) * min(1, dt * 12)
    g3d.draw(meshes.plateRim, e.x, e.y + 0.02, e.z)
    g3d.draw(meshes.plate, e.x, e.y + 0.07 - e.press * 0.05, e.z)
  end
  e.light = {color = "#5FD4C8", int = 0.8, range = 1.6}
end

K.spikes = function(e, L)
  e.y = (L.def.style == "sewer") and 0.2 or L.floorY
  local o = owner(e, "spikes")
  o.touchR = 1.15
  e.rise = 0
  e.startIn = e.phase or 0
  e.update = function(dt)
    if not e.inst and e.startIn then
      e.startIn = e.startIn - dt
      if e.startIn <= 0 then attachLib(e, "trap_spikes", {down = e.down or 1.5, up = e.up or 1.0, damage = 8}); e.startIn = nil end
    end
  end
  e.draw = function(t, dt)
    local want = (o.anim == "up") and 0.55 or ((o.anim == "warn") and 0.08 or 0)
    e.rise = e.rise + (want - e.rise) * min(1, dt * ((o.anim == "up") and 30 or 6))
    if o.anim == "up" and (e.lastAnim ~= "up") then G.sfxAt("spikes", e.x, e.z) end
    if o.anim == "warn" and (e.lastAnim ~= "warn") then G.sfxAt("tick", e.x, e.z) end
    e.lastAnim = o.anim
    -- the trap fills the walkway: in a sewer tunnel spikes stand in the channel and on both ledges
    g3d.draw(meshes.spikeBase, e.x, e.y + 0.01, e.z, 0, 0, 0, 2, 1, 2)
    if not e.gy then
      e.gy, e.buf = {}, {}
      for i = 0, 5 do
        for j = 0, 5 do
          local sx, sz = e.x - 1.5 + i * 0.6, e.z - 1.5 + j * 0.6
          e.gy[#e.gy + 1] = {sx, (Wd.ground(L, sx, sz, 2.0) or e.y), sz}
        end
      end
    end
    local buf, n = e.buf, 0
    for _, g in ipairs(e.gy) do
      buf[n + 1], buf[n + 2], buf[n + 3], buf[n + 4], buf[n + 5], buf[n + 6], buf[n + 7] = g[1], g[2] - 0.3 + e.rise, g[3], 0, 0, 0, 1
      n = n + 7
    end
    g3d.drawInstanced(meshes.spike, buf)
  end
  o.touchR = 1.6
end

-- the three seals of the temple: hold use for a moment to wake each
K.seal = function(e, L)
  e.y = Wd.ground(L, e.x, e.z) or L.floorY
  Wd.piece(L, "temple/GEO_Podium", e.x, e.y, e.z, 0, 1, {r = 2, sx = 0.3, sy = 0.5, sz = 0.3})
  G.box(e.x, e.y + 0.3, e.z, 0.6, 0.3, 0.6)
  local o = owner(e, "seal")
  o.needsFocus = true
  e.prompt = "act_wake"
  e.focusR = 2.4
  local lit = G.done[e.id]
  attachOwn(e, {initial = "idle", states = {
    {id = "idle", enter = {{t = "anim", name = "idle"}}, transitions = {{to = "charge", ["if"] = {{t = "touch", tag = "@player"}, {t = "input", b = "use", mode = "pressed"}}, ["do"] = {{t = "sound", s = "charge"}}}}},
    {id = "charge", enter = {{t = "anim", name = "charge"}}, transitions = {
      {to = "idle", ["if"] = {{t = "touch", tag = "@player", neg = true}}},
      {to = "lit", after = 2.2, ["do"] = {{t = "addvar", name = "seals", n = 1}, {t = "send", msg = "seal", to = "@all"}, {t = "sound", s = "seal"}, {t = "say", text = "msg_seal"}}}}},
    {id = "lit", enter = {{t = "anim", name = "lit"}}, transitions = {}},
  }}, lit and "lit" or nil)
  e.glow = 0
  e.draw = function(t, dt)
    local a = o.anim
    if a == "lit" and not e.flame then
      G.done[e.id] = true
      e.flame = F.ward(e.x, e.y + 0.75, e.z)
      e.prompt = nil
      G.awaken(e.x, e.z)
    end
    local want = a == "lit" and 1 or (a == "charge" and 0.6 or 0.12)
    e.glow = e.glow + (want - e.glow) * min(1, dt * 3)
    local s = 1 + (a == "charge" and sin(t * 12) * 0.05 or 0)
    g3d.draw(meshes.ring, e.x, e.y + 0.62, e.z, pi / 2, t * (0.3 + e.glow), 0, s, s, s, e.glow > 0.5 and "#FFFFFF" or "#3A6A66")
  end
  e.light = {color = "#5FD4C8", int = 1.5, range = 3}
end

K.sealgate = function(e, L)
  e.y = L.floorY
  local o = owner(e, "sealgate")
  blocker(e, 2.0, 2.2, 0.35)
  local open = G.done[e.id]
  attachOwn(e, {initial = "closed", states = {
    {id = "closed", enter = {{t = "set", prop = "solid", v = true}}, transitions = {{to = "open", on = "seal", ["if"] = {{t = "var", name = "seals", op = ">=", n = 3}},
      ["do"] = {{t = "sound", s = "bigdoor"}, {t = "say", text = "msg_sealgate"}}}}},
    {id = "open", enter = {{t = "set", prop = "solid", v = false}}, transitions = {}},
  }}, open and "open" or nil)
  e.sink = open and 4.6 or 0
  e.draw = function(t, dt)
    if o.props.solid == false then
      if not G.done[e.id] then G.done[e.id] = true; G.finalChase(); G.shake(1.2) end
      e.sink = min(4.6, e.sink + dt * 0.9)
    end
    g3d.draw(meshes.slab, e.x, e.y + 2.2 - e.sink, e.z)
  end
end

K.exit = function(e, L)
  e.y = L.floorY
  e.prompt = e.final and nil or "act_descend"
  e.focusR = e.r or 1.6
  e.isExit = true
  if e.final then
    G.statics[#G.statics + 1] = {x = e.x, y = 2.5, z = e.z - 1.5, color = "#FFD9A0", int = 14, range = 10, final = true}
  end
end

-- creates every entity of the level (enemies are made by cl_ai)
function P.build(L, game)
  G = game
  P.loadMeshes()
  for i = #ents, 1, -1 do ents[i] = nil end
  LG.reset()
  LG.setLibrary(LIB)
  LG.setWorld(adapter())
  for _, d in ipairs(L.def.ents) do
    local mk = K[d.t]
    if mk then
      local e = {}
      for k, v in pairs(d) do e[k] = v end
      e.x, e.z = d.c[1] * 4, d.c[2] * 4
      mk(e, L)
      ents[#ents + 1] = e
    end
  end
end

-- bodies of gates and doors wait for the navigation bake (closed gates must not be baked into the grid)
function P.navReady()
  for _, e in ipairs(ents) do
    if e.pendingSolid ~= nil then
      local v = e.pendingSolid
      e.pendingSolid = nil
      e.solidOn(v)
    end
  end
end

-- the interactive thing in reach that the player looks at
function P.focus(px, pz, fx, fz)
  local best, bd
  for _, e in ipairs(ents) do
    if not e.dead and (e.prompt or e.isExit) and e.focusR then
      local dx, dz = e.x - px, e.z - pz
      local d = sqrt(dx * dx + dz * dz)
      if d < e.focusR and (d < 0.9 or (dx * fx + dz * fz) / d > 0.45) then
        if not bd or d < bd then best, bd = e, d end
      end
    end
  end
  return best
end

function P.update(dt)
  for _, e in ipairs(ents) do
    if e.update and not e.dead then e.update(dt) end
  end
  LG.update(dt)
end

function P.draw(t, dt, cx, cz)
  for _, e in ipairs(ents) do
    if e.draw and not e.dead then
      local dx, dz = e.x - cx, e.z - cz
      if dx * dx + dz * dz < 30 * 30 then e.draw(t, dt) end
    end
  end
end

-- small lights of pickups and seals near the player (the game picks the strongest few)
function P.lights(out, px, pz)
  for _, e in ipairs(ents) do
    if e.light and not e.dead then
      local dx, dz = e.x - px, e.z - pz
      out[#out + 1] = {x = e.x, y = (e.y or 0.5) + 0.5, z = e.z, color = e.light.color, int = e.light.int * (e.glow and (0.4 + e.glow) or 1),
        range = e.light.range, d2 = dx * dx + dz * dz}
    end
  end
end

return P
