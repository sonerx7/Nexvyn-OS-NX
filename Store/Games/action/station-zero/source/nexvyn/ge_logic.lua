-- Nexvyn OS - Game Engine Logic 2.0 runtime (WP10): per-object state machines, messages, timers, waits, functions, lists.
--
-- Engine independent: everything the machines touch goes through a "world" table (L.setWorld), so the same code runs in
-- the 2D and 3D play tests, in object scripts and in the headless check (tools/ge_logic_check.py).
--
-- A machine is plain data (the format of docs/GAME_ENGINE_FORMAT_V2.md behaviors.stateMachines):
--   {initial = "walk", states = {{id = "walk", enter = {acts}, update = {acts}, exit = {acts},
--                                 transitions = {{to = "turn", ["if"] = {conds}, on = "message", after = 1.5, ["do"] = {acts}}}}}}
-- Conditions and actions are {t = "name", ...args}. A condition may carry neg = true. Ground-plane coordinates are
-- (x, y) in 2D and (x, z) in 3D; the world adapter hides the difference.
--
-- Guards (nothing here can freeze the game): at most MAX_TRANS state changes per machine and step, call depth MAX_CALL,
-- MAX_OPS actions per machine and step, MAX_QUEUE queued messages, messages are delivered one frame later (so two
-- machines answering each other cannot loop inside a frame).
local L = {}

local floor, abs, sqrt, min, max = math.floor, math.abs, math.sqrt, math.min, math.max
local cos, sin, rad, atan = math.cos, math.sin, math.rad, math.atan

L.MAX_TRANS, L.MAX_CALL, L.MAX_OPS, L.MAX_QUEUE, L.MAX_STATES = 8, 12, 4000, 256, 128

local world = {}
function L.setWorld(w) world = w or {} end
local function W(name, ...)
  local f = world[name]
  if f then return f(...) end
end

local instances, queue, inbox, lists, gvars, fns = {}, {}, {}, {}, {}, {}
local lib = {}  -- behaviour definitions by id (set with L.setLibrary)

function L.reset()
  instances, queue, inbox, lists, fns = {}, {}, {}, {}, {}
end
function L.setLibrary(l) lib = l or {} end
function L.setFunctions(f) fns = f or {} end
function L.list(name) lists[name] = lists[name] or {}; return lists[name] end
L.instances = function() return instances end

-- ---------------------------------------------------------------- parameters
-- "$speed", "-$speed", "$dist/$speed", "$a*$b", "$index-1" inside machine data become numbers (or text) from the parameter table.
local function pval(tok, p)
  if tok:match("^[%d%.]+$") then return tonumber(tok) end
  return p[tok]
end
local function subst(v, p)
  if type(v) == "string" and v:sub(1, 1) == "$" or (type(v) == "string" and v:sub(1, 2) == "-$") then
    local neg, a, op, b = v:match("^(%-?)%$([%w_]+)([%*/%+%-]?)%$?([%w_%.]*)$")
    if a then
      local x = pval(a, p)
      if op ~= "" and b ~= "" then
        local y = tonumber(pval(b, p)) or 1
        local xn = tonumber(x) or 0
        if op == "*" then x = xn * y elseif op == "/" then x = xn / (y ~= 0 and y or 1)
        elseif op == "+" then x = xn + y else x = xn - y end
      end
      if neg == "-" then x = -(tonumber(x) or 0) end
      return x
    end
  end
  return v
end
local function copy(t, p)
  if type(t) ~= "table" then return subst(t, p) end
  local o = {}
  for k, v in pairs(t) do o[k] = copy(v, p) end
  return o
end

-- parameters of a behaviour with defaults (is3d picks d3)
function L.params(def, given, is3d)
  local p = {}
  for _, s in ipairs(def.params or {}) do
    local d = s.d
    if is3d and s.d3 ~= nil then d = s.d3 end
    local v = given and given[s.k]
    if v == nil then v = d end
    if s.kind == "num" and type(v) ~= "number" then v = tonumber(v) or d or 0 end
    if s.kind == "num" and s.min and v < s.min then v = s.min end
    if s.kind == "num" and s.max and v > s.max then v = s.max end
    p[s.k] = v
  end
  return p
end

-- the machine of a behaviour with its parameters filled in
function L.build(def, given, is3d)
  local p = L.params(def, given, is3d)
  local m = copy(def.machine, p)
  m.params = p
  return m
end

-- ---------------------------------------------------------------- validation (twin of source/core/ge_logic.cpp)
local KNOWN_ACT = {steer = 1, move = 1, stop = 1, turn = 1, rotate = 1, face = 1, randomdir = 1, markhome = 1, spin = 1, jump = 1,
  setvar = 1, addvar = 1, score = 1, say = 1, sound = 1, anim = 1, shake = 1, flash = 1, confetti = 1, spawn = 1,
  destroy = 1, send = 1, scene = 1, save = 1, win = 1, lose = 1, hurt = 1, heal = 1, timer = 1, stoptimer = 1, wait = 1,
  call = 1, ["goto"] = 1, push = 1, pop = 1, clear = 1, fire = 1, set = 1, camera = 1, teleport = 1, ["if"] = 1,
  ["repeat"] = 1, music = 1, restart = 1, ["next"] = 1, life = 1, load = 1}
local KNOWN_COND = {blocked = 1, flag = 1, home = 1, sender = 1, var = 1, dist = 1, touch = 1, input = 1, timer = 1, chance = 1, hp = 1, time = 1, count = 1,
  list = 1, msg = 1, ground = 1, always = 1, tag = 1}
L.KNOWN_ACT, L.KNOWN_COND = KNOWN_ACT, KNOWN_COND

local function issue(out, sev, code, path, msg) out[#out + 1] = {severity = sev, code = code, path = path, message = msg} end

local function scanActs(list, path, out, calls)
  for i, a in ipairs(list or {}) do
    local p = path .. "/" .. (i - 1)
    if type(a) ~= "table" or type(a.t) ~= "string" then
      issue(out, "error", "type", p, "an action needs a text field t")
    else
      if not KNOWN_ACT[a.t] then issue(out, "warning", "unknown_action", p, "unknown action " .. a.t) end
      if a.t == "call" and type(a.fn) == "string" then calls[#calls + 1] = a.fn end
      if a.t == "if" then
        scanActs(a["do"], p .. "/do", out, calls)
        scanActs(a["else"], p .. "/else", out, calls)
      elseif a.t == "repeat" then
        scanActs(a["do"], p .. "/do", out, calls)
      end
    end
  end
end
local function scanConds(list, path, out)
  for i, c in ipairs(list or {}) do
    if type(c) ~= "table" or type(c.t) ~= "string" then
      issue(out, "error", "type", path .. "/" .. (i - 1), "a condition needs a text field t")
    elseif not KNOWN_COND[c.t] then
      issue(out, "warning", "unknown_condition", path .. "/" .. (i - 1), "unknown condition " .. c.t)
    end
  end
end

-- issues of one machine {initial, states}: duplicate_state, no_states, too_many, bad_initial, bad_target, bad_goto,
-- unreachable (warning), zero_loop (state changes that need no time, message or condition and lead back), unknown_*
function L.validate(m, path, out, callsOut)
  out, path = out or {}, path or ""
  if type(m) ~= "table" then issue(out, "error", "type", path, "a machine is an object") return out end
  local states = m.states
  if type(states) ~= "table" or #states == 0 then issue(out, "error", "no_states", path .. "/states", "a machine needs states") return out end
  if #states > L.MAX_STATES then issue(out, "error", "too_many", path .. "/states", "too many states") end
  local ids, calls = {}, callsOut or {}
  for i, s in ipairs(states) do
    local p = path .. "/states/" .. (i - 1)
    if type(s) ~= "table" or type(s.id) ~= "string" or s.id == "" then
      issue(out, "error", "required", p .. "/id", "a state needs an id")
    elseif ids[s.id] then
      issue(out, "error", "duplicate_id", p .. "/id", "duplicate state " .. s.id)
    else
      ids[s.id] = i
    end
  end
  if m.initial ~= nil and not ids[m.initial] then issue(out, "error", "bad_initial", path .. "/initial", "initial names no state") end
  local first = states[1] and states[1].id
  local stack = {ids[m.initial] and m.initial or first}
  local edges = {}  -- state id -> list of targets reached with no wait
  for i, s in ipairs(states) do
    if type(s) == "table" and type(s.id) == "string" then
      local p = path .. "/states/" .. (i - 1)
      for _, k in ipairs({"enter", "exit", "update"}) do scanActs(s[k], p .. "/" .. k, out, calls) end
      edges[s.id] = edges[s.id] or {}
      for j, t in ipairs(s.transitions or {}) do
        local tp = p .. "/transitions/" .. (j - 1)
        if type(t) ~= "table" or not ids[t.to] then
          issue(out, "error", "bad_ref", tp .. "/to", "transition target names no state")
        else
          scanConds(t["if"], tp .. "/if", out)
          scanActs(t["do"], tp .. "/do", out, calls)
          if t.after == nil and t.on == nil and not (t["if"] and #t["if"] > 0) then
            edges[s.id][#edges[s.id] + 1] = t.to
          end
        end
      end
      for _, k in ipairs({"enter", "exit", "update"}) do
        for ai, a in ipairs(s[k] or {}) do
          if type(a) == "table" and a.t == "goto" and not ids[a.state] then
            issue(out, "error", "bad_goto", p .. "/" .. k .. "/" .. (ai - 1), "goto names no state")
          end
        end
      end
    end
  end
  -- reachability
  local seen = {}
  while #stack > 0 do
    local id = table.remove(stack)
    if id and not seen[id] and ids[id] then
      seen[id] = true
      local s = states[ids[id]]
      for _, t in ipairs(s.transitions or {}) do if type(t) == "table" then stack[#stack + 1] = t.to end end
      for _, k in ipairs({"enter", "exit", "update"}) do
        for _, a in ipairs(s[k] or {}) do if type(a) == "table" and a.t == "goto" then stack[#stack + 1] = a.state end end
      end
    end
  end
  for i, s in ipairs(states) do
    if type(s) == "table" and type(s.id) == "string" and ids[s.id] == i and not seen[s.id] then
      issue(out, "warning", "unreachable", path .. "/states/" .. (i - 1), "state " .. s.id .. " is never entered")
    end
  end
  -- zero-time loops: a cycle through transitions that fire at once
  local color = {}
  local function dfs(id)
    color[id] = 1
    for _, to in ipairs(edges[id] or {}) do
      if color[to] == 1 then return true end
      if not color[to] and dfs(to) then return true end
    end
    color[id] = 2
    return false
  end
  for id in pairs(edges) do
    if not color[id] and dfs(id) then
      issue(out, "error", "zero_loop", path, "state changes without a wait lead back to a state (endless loop)")
      break
    end
  end
  return out
end

-- a whole logic block {machines = {...}, functions = {{id, do}}}: machines and the function call graph (no cycles)
function L.validateAll(logic, out)
  out = out or {}
  local fnCalls, fnIds = {}, {}
  for i, f in ipairs(logic.functions or {}) do
    local p = "/functions/" .. (i - 1)
    if type(f.id) ~= "string" or f.id == "" then issue(out, "error", "required", p .. "/id", "a function needs an id")
    elseif fnIds[f.id] then issue(out, "error", "duplicate_id", p .. "/id", "duplicate function " .. f.id)
    else
      fnIds[f.id] = true
      local calls = {}
      scanActs(f["do"], p .. "/do", out, calls)
      fnCalls[f.id] = calls
    end
  end
  local allCalls = {}
  local mids = {}
  for i, m in ipairs(logic.machines or {}) do
    local p = "/machines/" .. (i - 1)
    if type(m.id) == "string" then
      if mids[m.id] then issue(out, "error", "duplicate_id", p .. "/id", "duplicate machine " .. m.id) end
      mids[m.id] = true
    end
    L.validate(m, p, out, allCalls)
  end
  for _, c in ipairs(allCalls) do
    if not fnIds[c] then issue(out, "error", "bad_ref", "/functions", "call names no function " .. c) end
  end
  local color = {}
  local function dfs(id)
    color[id] = 1
    for _, to in ipairs(fnCalls[id] or {}) do
      if color[to] == 1 then return true end
      if fnIds[to] and not color[to] and dfs(to) then return true end
    end
    color[id] = 2
  end
  for id in pairs(fnIds) do
    if not color[id] and dfs(id) then issue(out, "error", "cycle", "/functions", "functions call each other in a circle") break end
  end
  return out
end

function L.hasErrors(out)
  for _, i in ipairs(out) do if i.severity == "error" then return true end end
  return false
end

-- ---------------------------------------------------------------- messages
-- Queued now, delivered at the start of the next update (to: "@all", a selector, or a machine owner).
function L.send(name, to, from)
  if #queue >= L.MAX_QUEUE then return false end
  queue[#queue + 1] = {name = name, to = to or "@all", from = from}
  return true
end

local function addressed(inst, m)
  local to = m.to
  if to == "@all" or to == nil then return m.from ~= inst.owner end
  if to == "@self" then return m.from == inst.owner end
  if to == "@other" then return m.from ~= inst.owner end
  if type(to) == "table" then return to == inst.owner end
  if m.from == inst.owner then return false end
  local r = W("matches", inst.owner, to)
  return r and true or false
end

-- ---------------------------------------------------------------- values
local OPS = {
  ["="] = function(a, b) return a == b end, ["!="] = function(a, b) return a ~= b end,
  ["<"] = function(a, b) return a < b end, [">"] = function(a, b) return a > b end,
  ["<="] = function(a, b) return a <= b end, [">="] = function(a, b) return a >= b end,
}
local function cmp(op, a, b) return (OPS[op or "="] or OPS["="])(a, b) end
local function num(v, d) return tonumber(v) or d or 0 end
function L.truthy(v) return v ~= nil and v ~= false and v ~= 0 and v ~= "" end
local truthy = L.truthy

local function getVar(inst, name)
  if type(name) ~= "string" then return 0 end
  if name:sub(1, 1) == "." then return tonumber(inst.vars[name]) or 0 end
  local v = W("var", name)
  return tonumber(v) or 0
end
local function setVar(inst, name, v)
  if type(name) ~= "string" then return end
  if name:sub(1, 1) == "." then inst.vars[name] = v else W("setVar", name, v) end
end

local function unit(dx, dy)
  local d = sqrt(dx * dx + dy * dy)
  if d < 1e-6 then return 0, 0, 0 end
  return dx / d, dy / d, d
end

local function targetOf(inst, sel, ctx)
  if sel == nil or sel == "@player" then
    local p = W("nearest", inst.owner, "@player")
    return p
  end
  if sel == "@other" then return ctx and ctx.other end
  if sel == "@self" then return inst.owner end
  return W("nearest", inst.owner, sel)
end

-- "self" (default), "other" (the object of the last touch / distance test), "player", or a selector: whom an action acts on
local function who(inst, w, ctx)
  if w == nil or w == "self" then return inst.owner end
  if w == "other" then return ctx.other end
  if w == "player" then return W("nearest", inst.owner, "@player") end
  return W("nearest", inst.owner, w)
end

local function posOf(e)
  local x, y = W("pos", e)
  return x or 0, y or 0
end

-- ---------------------------------------------------------------- conditions
local COND = {}
COND.always = function() return true end
COND.var = function(inst, c) return cmp(c.op, getVar(inst, c.name), num(c.n)) end
COND.dist = function(inst, c, ctx)
  local o = targetOf(inst, c.to, ctx)
  if not o then return c.op == ">" or c.op == ">=" end  -- nobody there: "farther than" is true
  local x, y = posOf(inst.owner)
  local ox, oy = posOf(o)
  ctx.other = o
  local _, _, d = unit(ox - x, oy - y)
  return cmp(c.op or "<", d, num(c.n))
end
COND.touch = function(inst, c, ctx)
  local o = W("touching", inst.owner, c.tag or c.to or "@player")
  if o then ctx.other = o end
  return o and true or false
end
COND.tag = COND.touch
COND.input = function(inst, c)
  local r = W("input", c.b or "jump", c.mode or "down")
  return r and true or false
end
COND.timer = function(inst, c)
  local t = inst.timers[c.name or "t"]
  return t ~= nil and t <= 0
end
COND.chance = function(inst, c, ctx)
  local p = num(c.p, 50) / 100
  return (W("rand") or math.random()) < min(1, p * (ctx.dt or 0.016))
end
COND.hp = function(inst, c) return cmp(c.op, num(W("hp", inst.owner), 0), num(c.n)) end
COND.time = function(inst, c) return cmp(c.op or ">=", inst.t, num(c.n)) end
COND.count = function(inst, c) return cmp(c.op, num(W("count", c.k or "@enemy"), 0), num(c.n)) end
COND.list = function(inst, c) return cmp(c.op, #L.list(c.name or "list"), num(c.n)) end
COND.msg = function(inst, c, ctx) return ctx.inbox and ctx.inbox[c.name or ""] and true or false end
COND.ground = function(inst) local r = W("onGround", inst.owner); return r == nil or r end
COND.blocked = function(inst) return W("blocked", inst.owner) and true or false end
COND.flag = function(inst, c) return L.truthy(c.v) end
COND.home = function(inst, c)
  local x, y = posOf(inst.owner)
  local _, _, d = unit((inst.homeX or x) - x, (inst.homeY or y) - y)
  return cmp(c.op or "<", d, num(c.n))
end
-- distance to whoever sent the message of the transition being tested (the "on" of that transition)
COND.sender = function(inst, c, ctx)
  local from = ctx.msgFrom
  if type(from) ~= "table" then return false end
  local x, y = posOf(inst.owner)
  local fx, fy = posOf(from)
  local _, _, d = unit(fx - x, fy - y)
  return cmp(c.op or "<", d, num(c.n))
end

local function check(inst, conds, ctx)
  if not conds then return true end
  for i = 1, #conds do
    local c = conds[i]
    local f = COND[c.t]
    local r = true
    if f then r = f(inst, c, ctx) and true or false end
    if truthy(c.neg) then r = not r end
    if not r then return false end
  end
  return true
end

-- ---------------------------------------------------------------- actions
local ACT = {}
local exec

local function setHeading(inst, dx, dy)
  if dx == 0 and dy == 0 then return end
  inst.dx, inst.dy = dx, dy
  W("face", inst.owner, dx, dy)
end

ACT.move = function(inst, a, ctx)
  local speed = num(a.speed, 1)
  local dir = a.dir or "forward"
  local dx, dy
  if dir == "forward" then dx, dy = inst.dx, inst.dy
  elseif dir == "back" then dx, dy = -inst.dx, -inst.dy
  elseif dir == "left" then dx, dy = -inst.dy, inst.dx
  elseif dir == "right" then dx, dy = inst.dy, -inst.dx
  elseif dir == "toward" or dir == "away" then
    local o = targetOf(inst, a.to, ctx)
    if not o then W("setVel", inst.owner, 0, 0) return end
    local x, y = posOf(inst.owner)
    local ox, oy = posOf(o)
    dx, dy = unit(ox - x, oy - y)
    if dir == "away" then dx, dy = -dx, -dy end
    setHeading(inst, dx, dy)
  elseif dir == "home" then
    local x, y = posOf(inst.owner)
    local d
    dx, dy, d = unit((inst.homeX or x) - x, (inst.homeY or y) - y)
    if d < speed * (ctx.dt or 0.016) then W("setVel", inst.owner, 0, 0) return end
    setHeading(inst, dx, dy)
  elseif dir == "input" then
    local ix, iy = W("axis")
    dx, dy = ix or 0, iy or 0
    if dx == 0 and dy == 0 then W("setVel", inst.owner, 0, 0) return end
    local ux, uy = unit(dx, dy)
    setHeading(inst, ux, uy)
    dx, dy = ux * min(1, sqrt(dx * dx + dy * dy)), uy * min(1, sqrt(dx * dx + dy * dy))
  else dx, dy = inst.dx, inst.dy end
  W("setVel", inst.owner, dx * speed, dy * speed)
end
ACT.stop = function(inst) W("setVel", inst.owner, 0, 0) end
ACT.turn = function(inst, a)
  if a.deg then
    local r = rad(num(a.deg))
    local c, s = cos(r), sin(r)
    setHeading(inst, inst.dx * c - inst.dy * s, inst.dx * s + inst.dy * c)
  else
    setHeading(inst, -inst.dx, -inst.dy)
  end
end
ACT.rotate = function(inst, a, ctx)
  local r = rad(num(a.deg)) * (ctx.dt or 0)
  local c, s = cos(r), sin(r)
  setHeading(inst, inst.dx * c - inst.dy * s, inst.dx * s + inst.dy * c)
end
ACT.face = function(inst, a, ctx)
  local o = targetOf(inst, a.to, ctx)
  if not o then return end
  local x, y = posOf(inst.owner)
  local ox, oy = posOf(o)
  local dx, dy = unit(ox - x, oy - y)
  setHeading(inst, dx, dy)
end
ACT.randomdir = function(inst)
  local a = (W("rand") or math.random()) * math.pi * 2
  setHeading(inst, cos(a), sin(a))
end
ACT.markhome = function(inst)
  inst.homeX, inst.homeY = posOf(inst.owner)
end
ACT.spin = function(inst, a) W("spin", inst.owner, num(a.speed, 90)) end
ACT.jump = function(inst, a, ctx)
  local w = who(inst, a.w, ctx)
  if w then W("jump", w, a.power ~= nil and num(a.power) or nil) end
end
-- turn by a.deg degrees per second times the steering axis (left / right)
ACT.steer = function(inst, a, ctx)
  local ix = W("axis")
  if not ix or ix == 0 then return end
  local r = rad(num(a.deg, 90)) * ix * (ctx.dt or 0)
  local c, s = cos(r), sin(r)
  setHeading(inst, inst.dx * c - inst.dy * s, inst.dx * s + inst.dy * c)
end
ACT.setvar = function(inst, a) setVar(inst, a.name, num(a.n)) end
ACT.addvar = function(inst, a) setVar(inst, a.name, getVar(inst, a.name) + num(a.n, 1)) end
ACT.score = function(inst, a) W("score", num(a.n, 1)) end
ACT.life = function(inst, a) W("life", num(a.n, 1)) end
ACT.say = function(inst, a) W("say", tostring(a.text or "")) end
ACT.sound = function(inst, a) W("sound", a.s or "pop") end
ACT.music = function(inst, a) W("music", a.m) end
ACT.anim = function(inst, a) W("anim", inst.owner, a.name or "idle") end
ACT.shake = function() W("shake") end
ACT.flash = function() W("flash") end
ACT.confetti = function(inst) W("confetti", inst.owner) end
ACT.spawn = function(inst, a, ctx)
  local x, y = posOf(a.at == "other" and ctx.other or inst.owner)
  if a.at == "player" then local p = W("nearest", inst.owner, "@player"); if p then x, y = posOf(p) end end
  W("spawn", a.k or "coin", x + num(a.dx), y + num(a.dy), a)
end
ACT.destroy = function(inst, a, ctx)
  local w = who(inst, a.w, ctx)
  if w then W("destroy", w) end
  if w == inst.owner then inst.dead = true end
end
ACT.send = function(inst, a) L.send(a.msg or "msg", a.to, inst.owner) end
ACT.scene = function(inst, a) W("scene", a.n or "next") end
ACT["next"] = function() W("scene", "next") end
ACT.restart = function() W("restart") end
-- "save" without a slot is the checkpoint (the spot is kept); with slot = "auto" | "1".."9" it writes that save slot
local function slotOf(v)
  if v == nil or v == "checkpoint" then return nil end
  if v == "auto" then return 0 end
  return tonumber(v)
end
ACT.save = function(inst, a) W("save", inst.owner, slotOf(a.slot)) end
ACT.load = function(inst, a) W("load", slotOf(a.slot) or 0) end
ACT.win = function() W("win") end
ACT.lose = function() W("lose") end
ACT.hurt = function(inst, a, ctx)
  local w = who(inst, a.w, ctx)
  if w then W("hurt", w, num(a.n, 1)) end
end
ACT.heal = function(inst, a, ctx)
  local w = who(inst, a.w, ctx)
  if w then W("heal", w, num(a.n, 1)) end
end
ACT.timer = function(inst, a) inst.timers[a.name or "t"] = num(a.sec, 1) end
ACT.stoptimer = function(inst, a) inst.timers[a.name or "t"] = nil end
ACT.push = function(inst, a) local l = L.list(a.list or "list"); if #l < 1000 then l[#l + 1] = a.v ~= nil and a.v or 1 end end
ACT.pop = function(inst, a)
  local l = L.list(a.list or "list")
  local v = table.remove(l, 1)
  if a.into then setVar(inst, a.into, num(v)) end
end
ACT.clear = function(inst, a) lists[a.list or "list"] = {} end
ACT.fire = function(inst, a, ctx)
  local dx, dy = inst.dx, inst.dy
  if a.to then
    local o = targetOf(inst, a.to, ctx)
    if o then
      local x, y = posOf(inst.owner)
      local ox, oy = posOf(o)
      dx, dy = unit(ox - x, oy - y)
    end
  end
  W("fire", inst.owner, a.k or "bullet", dx, dy, num(a.speed, 1), a)
end
ACT.set = function(inst, a, ctx)
  local w = who(inst, a.w, ctx)
  if w then W("setProp", w, a.prop, a.v) end
end
ACT.camera = function(inst, a) W("camera", inst.owner, a.mode or "third", num(a.dist, 8), num(a.height, 4)) end
ACT.teleport = function(inst, a, ctx)
  local w = who(inst, a.w, ctx)
  if not w then return end
  if a.to == "@home" then W("teleport", w, inst.homeX or 0, inst.homeY or 0) return end
  local o = a.name and a.name ~= "" and W("find", a.name) or (a.to and targetOf(inst, a.to, ctx))
  if o then local x, y = posOf(o); W("teleport", w, x, y) else W("teleport", w, num(a.x), num(a.y)) end
end
ACT["goto"] = function(inst, a) inst.go = a.state end
ACT.wait = function() end  -- handled by exec

ACT["if"] = function(inst, a, ctx, depth)
  if check(inst, a.c or a["if"], ctx) then exec(inst, a["do"], ctx, depth) else exec(inst, a["else"], ctx, depth) end
end
ACT["repeat"] = function(inst, a, ctx, depth)
  local n = a.var and getVar(inst, a.var) or num(a.n, 1)
  for _ = 1, min(floor(n), 100) do
    if inst.ops > L.MAX_OPS then break end
    exec(inst, a["do"], ctx, depth)
  end
end
ACT.call = function(inst, a, ctx, depth)
  local f = fns[a.fn]
  if not f then return end
  if depth >= L.MAX_CALL then return end
  exec(inst, f["do"] or f, ctx, depth + 1)
end

-- Runs an action list. A wait action schedules the rest of the list and returns (the caller goes on at once).
exec = function(inst, list, ctx, depth, scoped)
  if not list then return end
  depth = depth or 0
  for i = 1, #list do
    local a = list[i]
    inst.ops = inst.ops + 1
    if inst.ops > L.MAX_OPS then return end
    if a.t == "wait" then
      if #inst.pending < 64 then
        inst.pending[#inst.pending + 1] = {t = num(a.sec, 1), list = list, i = i + 1, ctx = {other = ctx.other, dt = ctx.dt},
                                           scoped = scoped ~= false, state = inst.state, depth = depth}
      end
      return
    end
    local f = ACT[a.t]
    if f and (a.when == nil or truthy(a.when)) then f(inst, a, ctx, depth) end
    if inst.dead then return end
  end
end

-- ---------------------------------------------------------------- machines
local function stateOf(inst, id) return inst.ids[id] end

local function enterState(inst, id, ctx)
  local s = stateOf(inst, id)
  if not s then return false end
  inst.state, inst.cur, inst.t = id, s, 0
  exec(inst, s.enter, ctx or {dt = 0}, 0)
  return true
end

local function changeState(inst, to, doList, ctx)
  local s = inst.cur
  if s then exec(inst, s.exit, ctx, 0) end
  for i = #inst.pending, 1, -1 do if inst.pending[i].scoped then table.remove(inst.pending, i) end end
  if doList then exec(inst, doList, ctx, 0, false) end
  inst.changes = inst.changes + 1
  return enterState(inst, to, ctx)
end

-- Attaches a machine (data as above) to an owner. params (the result of L.params) are kept for scripts.
function L.attach(owner, m, params)
  local inst = {owner = owner, def = m, ids = {}, pending = {}, timers = {}, vars = {}, t = 0, ops = 0, changes = 0,
                dx = 1, dy = 0, params = params or m.params or {}}
  for _, s in ipairs(m.states or {}) do
    if type(s.id) == "string" and not inst.ids[s.id] then inst.ids[s.id] = s end
  end
  local hx, hy = W("heading", owner)
  if hx and (hx ~= 0 or hy ~= 0) then inst.dx, inst.dy = hx, hy end
  inst.homeX, inst.homeY = posOf(owner)
  local first = m.initial or (m.states and m.states[1] and m.states[1].id)
  instances[#instances + 1] = inst
  enterState(inst, first, {dt = 0})
  return inst
end

-- A library behaviour by id on an owner; returns the instance (nil when the id is unknown or the machine invalid).
function L.attachBehaviour(owner, id, given, is3d)
  local def = lib[id]
  if not def then return nil end
  local m = L.build(def, given, is3d)
  if L.hasErrors(L.validate(m)) then return nil end
  for k, v in pairs(def.flags or {}) do W("setProp", owner, k, v) end
  return L.attach(owner, m, m.params)
end

local function step(inst, dt)
  inst.ops, inst.changes = 0, 0
  inst.t = inst.t + dt
  for k, v in pairs(inst.timers) do if v > 0 then inst.timers[k] = v - dt end end
  local ctx = {dt = dt, inbox = inst.inbox}
  -- pending waits
  for i = #inst.pending, 1, -1 do
    local p = inst.pending[i]
    if p then
      p.t = p.t - dt
      if p.t <= 0 then
        table.remove(inst.pending, i)
        local rest = {}
        for j = p.i, #p.list do rest[#rest + 1] = p.list[j] end
        local c = {other = p.ctx.other, dt = dt}
        exec(inst, rest, c, p.depth, p.scoped)
      end
    end
  end
  if inst.dead then return end
  local s = inst.cur
  if s then exec(inst, s.update, ctx, 0) end
  local guard = 0
  while inst.cur and not inst.dead do
    s = inst.cur
    local fired
    if inst.go then
      local g = inst.go
      inst.go = nil
      if inst.ids[g] then fired = {to = g} end
    end
    if not fired then
      for _, t in ipairs(s.transitions or {}) do
        local ok = true
        -- after the first state change of a step only unconditional transitions chain on: the same button press or
        -- message cannot drive two changes in one frame
        if guard > 0 and (t.after ~= nil or t.on ~= nil or (t["if"] and #t["if"] > 0)) then ok = false end
        if ok and t.after ~= nil and inst.t < num(t.after) then ok = false end
        if ok and t.on ~= nil and not (inst.inbox and inst.inbox[t.on]) then ok = false end
        if ok then
          ctx.other = nil
          ctx.msgFrom = t.on and inst.inbox and inst.inbox[t.on] or nil
          ok = check(inst, t["if"], ctx)
        end
        if ok then fired = t break end
      end
    end
    if not fired then break end
    guard = guard + 1
    if guard > L.MAX_TRANS then break end  -- loop guard: stay in this state until the next step
    if fired.on and inst.inbox then inst.inbox[fired.on] = nil end
    changeState(inst, fired.to, fired["do"], ctx)
  end
end

-- One frame: deliver the messages queued since the last one, step every machine, drop machines of removed owners.
function L.update(dt)
  dt = dt or 0.016
  local now = queue
  queue = {}
  for _, inst in ipairs(instances) do
    inst.inbox = nil
    if now[1] then
      for _, m in ipairs(now) do
        if addressed(inst, m) then
          inst.inbox = inst.inbox or {}
          inst.inbox[m.name] = m.from or true
        end
      end
    end
  end
  local n = 0
  for i = 1, #instances do
    local inst = instances[i]
    if inst.dead or (world.alive and not world.alive(inst.owner)) then
      inst.dead = true
    else
      step(inst, dt)
      n = n + 1
      instances[n] = inst
    end
  end
  for i = #instances, n + 1, -1 do instances[i] = nil end
end

function L.stateOf(inst) return inst.state end
function L.detach(inst) inst.dead = true end

return L
