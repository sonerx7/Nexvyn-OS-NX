-- nexvyn.ge_character - Game Engine base characters (WP15): the locomotion state machine and the pop meter. Pure Lua, no
-- g3d calls, so the same code runs in the host simulation test (tests/test_ge_character_lua.lua). The graph is the file
-- Workshop/character_locomotion.json (same format as the editor's Animator graphs, see docs/GAME_ENGINE_ANIMATION.md); the
-- play scene (workshop3d.lua) turns the commands this machine returns into model:play(clip, {loop, speed, fade}).
--
-- No pop: the core only crossfades from the clip that is playing, so a transition that starts while a fade is still
-- running would jump (what `Animator::smoothInterrupt` fixes inside the engine). The machine therefore never starts a
-- transition during a fade (except death) and a trigger waits for the fade to end (triggers live 0.25 s).
local M = {}

local TRIGGER_LIFE = 0.25
local max, min, sqrt = math.max, math.min, math.sqrt

local Machine = {}
Machine.__index = Machine

-- graph: decoded character_locomotion.json; durations: {clipName = seconds} (from model:info().animations)
function M.machine(graph, durations)
  local m = setmetatable({g = graph, dur = durations or {}, params = {}, trig = {}, states = {}, time = 0, fadeLeft = 0,
                          speed = 1}, Machine)
  for k, v in pairs(graph.params or {}) do m.params[k] = v end
  for _, s in ipairs(graph.states or {}) do m.states[s.name] = s end
  m.cur = m.states[graph.initial] or graph.states[1]
  return m
end

function Machine:set(name, v) self.params[name] = v end
function Machine:trigger(name) self.trig[name] = TRIGGER_LIFE end
function Machine:state() return self.cur.name end
-- the command for the state the machine starts in (play it once after creating the machine)
function Machine:first()
  self.speed = self:stateSpeed(self.cur)
  return {clip = self.cur.clip, loop = self.cur.loop ~= false, speed = self.speed, fade = 0, state = self.cur.name}
end

function Machine:stateSpeed(s)
  local v = s.speedParam and self.params[s.speedParam]
  if type(v) ~= "number" or v ~= v then return s.speed or 1 end
  return (s.speed or 1) * max(0.25, min(3, v))
end

local function cond(m, c)
  local k, op, v = c[1], c[2], c[3]
  if op == "trigger" then return (m.trig[k] or 0) > 0 end
  local p = m.params[k]
  if op == "true" then return p == true or (type(p) == "number" and p ~= 0) end
  if op == "false" then return not (p == true or (type(p) == "number" and p ~= 0)) end
  local n = tonumber(p) or 0
  if op == ">" then return n > v elseif op == "<" then return n < v elseif op == ">=" then return n >= v
  elseif op == "<=" then return n <= v elseif op == "==" then return n == v elseif op == "!=" then return n ~= v end
  return false
end

-- advances the machine; returns a command {clip, loop, speed, fade, state} when a new state starts, else nil
function Machine:update(dt)
  self.time = self.time + dt
  if self.fadeLeft > 0 then self.fadeLeft = max(0, self.fadeLeft - dt) end
  for k, t in pairs(self.trig) do
    local n = t - dt
    self.trig[k] = n > 0 and n or nil
  end
  local cur = self.cur
  local d = self.dur[cur.clip] or 0
  local played = d > 0 and self.time * self.speed / d or 1
  for _, t in ipairs(self.g.transitions or {}) do
    if (t.from == "*" and t.to ~= cur.name) or t.from == cur.name then
      local ok = true
      for _, c in ipairs(t.when or {}) do
        if not cond(self, c) then ok = false break end
      end
      if ok and t.exit ~= nil and played < t.exit - 1e-6 then ok = false end
      if ok and self.fadeLeft > 0 and t.to ~= "death" then ok = false end
      if ok then
        for _, c in ipairs(t.when or {}) do
          if c[2] == "trigger" then self.trig[c[1]] = nil end
        end
        local to = self.states[t.to]
        if to then
          self.cur, self.time = to, 0
          self.speed = self:stateSpeed(to)
          self.fadeLeft = t.fade or 0.15
          return {clip = to.clip, loop = to.loop ~= false, speed = self.speed, fade = self.fadeLeft, state = to.name}
        end
      end
    end
  end
  return nil
end

-- walk / run clip speed that matches the distance the object really covers (no foot sliding): speed in m/s,
-- ref = metres per second one cycle of the clip covers (manifest walkSpeed / runSpeed), scale clamped to 0.5 .. 1.6
function M.cycleScale(speed, ref)
  if not ref or ref <= 0 then return 1 end
  return max(0.5, min(1.6, speed / ref))
end

-- The graph's thresholds are written for the hero (run at 4.2 m/s): other characters scale their speed to it
function M.normSpeed(speed, runRef)
  if not runRef or runRef <= 0 then return speed end
  return speed * 4.2 / runRef
end

-- Pop meter: samples a few body nodes of a model each frame (model:node(name) -> x, y, z in the current pose) and
-- reports how fast the fastest one moved. A pop is a node that jumps further than `limit` metres per second.
-- popRatio = pops / transitions (a transition counts once, however many frames it covers).
local Meter = {}
Meter.__index = Meter
function M.popMeter(nodes, limit)
  return setmetatable({nodes = nodes, limit = limit or 14, last = {}, transitions = 0, pops = 0, maxSpeed = 0, window = 0,
                       popped = false, frames = 0}, Meter)
end
function Meter:transition() self.transitions = self.transitions + 1; self.window, self.popped = 0.4, false end
-- model: anything with :node(name) -> x, y, z (nil when the node is missing)
function Meter:sample(model, dt)
  if dt <= 0 then return end
  local worst = 0
  for _, n in ipairs(self.nodes) do
    local x, y, z = model:node(n)
    local l = self.last[n]
    if x and l then
      local dx, dy, dz = x - l[1], y - l[2], z - l[3]
      worst = max(worst, sqrt(dx * dx + dy * dy + dz * dz) / dt)
    end
    if x then self.last[n] = {x, y, z} end
  end
  self.frames = self.frames + 1
  self.maxSpeed = max(self.maxSpeed, worst)
  if self.window > 0 then
    self.window = self.window - dt
    if worst > self.limit and not self.popped then self.popped, self.pops = true, self.pops + 1 end
  end
end
function Meter:ratio() return self.transitions > 0 and self.pops / self.transitions or 0 end

return M
