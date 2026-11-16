-- nexvyn.ge_anim - Game Engine animation playback (WP11): prop timelines and camera rails. Pure Lua, no g3d calls, so
-- the same code runs in the host simulation test (tests/test_ge_anim_lua.py). It mirrors core/ge_anim.cpp (the editor's
-- player): the shared cases in tests/fixtures/ge_anim/cases.json give the same numbers in both.
--
-- Timeline table (the object's "tl" field, as the editor writes it): {duration, loop = "once"|"loop"|"pingpong",
-- autoplay, trigger, onEnd, speed, tracks = {{prop = "y", keys = {{t, v, ease}, ...}}}, events = {{t, name}, ...}}.
-- Props: x y z (offset), rx ry rz (degrees, added), sx sy sz s (multiply), r g b (replace, 0..1), visible (replace).
-- Rail table (the object's "rail" field): {duration, ease, play = "enter"|"end"|"trigger"|"none", trigger, onEnd,
-- points = {{pos = {x, y, z}, look = {x, y, z}, fov}, ...}}.

local M = {}
local floor, abs, min, max, sqrt, exp, cos, fmod = math.floor, math.abs, math.min, math.max, math.sqrt, math.exp, math.cos, math.fmod

local CHANS = {"x", "y", "z", "rx", "ry", "rz", "sx", "sy", "sz", "s", "r", "g", "b", "visible"}
local ALIAS = {px = "x", py = "y", pz = "z", scale = "s", vis = "visible"}
local VALID = {}
for _, c in ipairs(CHANS) do VALID[c] = true end
M.CHANS = CHANS

local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function clamp(v, lo, hi) return v < lo and lo or (v > hi and hi or v) end
local function num(v, def, lo, hi)
  if not finite(v) then return def end
  return clamp(v, lo, hi)
end

-- ---------------------------------------------------------------- eases
local function spring(t)
  local function raw(x) return 1 - exp(-6 * x) * cos(12 * x) end
  return raw(t) + (1 - raw(1)) * t * t * t
end
local EASE = {
  linear = function(t) return t end,
  ["in"] = function(t) return t * t * t end,
  out = function(t) local u = 1 - t; return 1 - u * u * u end,
  ease = function(t) if t < 0.5 then return 4 * t * t * t end return 1 - (-2 * t + 2) ^ 3 / 2 end,
  spring = spring,
  step = function() return 0 end,
}
EASE.inout, EASE.ease_in_out, EASE.ease_in, EASE.ease_out = EASE.ease, EASE.ease, EASE["in"], EASE.out

function M.ease(name, t)
  if not finite(t) or t <= 0 then return 0 end
  if t >= 1 then return 1 end
  return (EASE[name or "linear"] or EASE.linear)(t)
end

-- ---------------------------------------------------------------- timelines
-- Clamped copy of an editor timeline (the same limits as the C++ parser). nil when nothing usable is left.
function M.timeline(j)
  if type(j) ~= "table" then return nil end
  local tl = {duration = num(j.duration, 1, 0.05, 600), loop = j.loop or "loop", trigger = j.trigger or "", onEnd = j.onEnd or "",
              speed = num(j.speed, 1, 0, 20), autoplay = j.autoplay ~= false, tracks = {}, events = {}}
  if tl.loop == "ping-pong" then tl.loop = "pingpong" end
  if tl.loop ~= "once" and tl.loop ~= "pingpong" then tl.loop = "loop" end
  local def = type(j.ease) == "string" and j.ease or "linear"
  for _, tj in ipairs(type(j.tracks) == "table" and j.tracks or {}) do
    if #tl.tracks >= 32 then break end
    local prop = type(tj) == "table" and (ALIAS[tj.prop] or tj.prop)
    if prop and VALID[prop] and type(tj.keys) == "table" then
      local td = type(tj.ease) == "string" and tj.ease or def
      local keys = {}
      for _, kj in ipairs(tj.keys) do
        if #keys >= 256 then break end
        if type(kj) == "table" then
          local t, v, e = kj[1] or kj.t, kj[2] or kj.v, kj[3] or kj.e
          if finite(t) and finite(v) then
            keys[#keys + 1] = {t = clamp(t, 0, 600), v = clamp(v, -1e6, 1e6), e = type(e) == "string" and e or td, i = #keys}
          end
        end
      end
      if #keys > 0 then
        table.sort(keys, function(a, b) if a.t ~= b.t then return a.t < b.t end return a.i < b.i end)
        tl.tracks[#tl.tracks + 1] = {prop = prop, keys = keys}
      end
    end
  end
  for _, ej in ipairs(type(j.events) == "table" and j.events or {}) do
    if #tl.events >= 64 then break end
    if type(ej) == "table" then
      local t, n = ej[1] or ej.t, ej[2] or ej.name
      if finite(t) and type(n) == "string" then tl.events[#tl.events + 1] = {t = clamp(t, 0, 600), name = n, i = #tl.events} end
    end
  end
  table.sort(tl.events, function(a, b) if a.t ~= b.t then return a.t < b.t end return a.i < b.i end)
  if #tl.tracks == 0 and #tl.events == 0 then return nil end
  return tl
end

local function evalTrack(tr, t)
  local k = tr.keys
  local n = #k
  if t <= k[1].t then return k[1].v end
  if t >= k[n].t then return k[n].v end
  local i = 1
  while i < n and k[i + 1].t <= t do i = i + 1 end
  local a, b = k[i], k[i + 1]
  local span = b.t - a.t
  if span <= 1e-6 or a.e == "step" or tr.prop == "visible" then return a.v end
  return a.v + (b.v - a.v) * M.ease(a.e, (t - a.t) / span)
end
M.evalTrack = evalTrack

-- time inside a cycle for the unrolled time u
function M.cycleTime(tl, u)
  local d = max(tl.duration, 0.05)
  if not (u > 0) then return 0 end
  if tl.loop == "once" then return min(u, d) end
  if tl.loop == "loop" then return fmod(u, d) end
  local m = fmod(u, 2 * d)
  return m > d and 2 * d - m or m
end

-- pose at t: {x=, y=, ..., has = {x = true, ...}} with neutral values for channels not animated
function M.pose(tl, t)
  local p = {x = 0, y = 0, z = 0, rx = 0, ry = 0, rz = 0, sx = 1, sy = 1, sz = 1, s = 1, r = 1, g = 1, b = 1, visible = 1, has = {}}
  for _, tr in ipairs(tl.tracks) do
    p[tr.prop] = evalTrack(tr, t)
    p.has[tr.prop] = true
  end
  return p
end

-- A player: update(dt) returns the events passed (names, in time order); pose() the current pose.
function M.player(tl)
  local P = {tl = tl, u = 0, last = -1, speed = tl.speed, playing = false, paused = false, finished = false}
  function P.play() P.u, P.last, P.playing, P.paused, P.finished = 0, -1, true, false, false end
  function P.stop() P.u, P.last, P.playing, P.paused, P.finished = 0, -1, false, false, false end
  function P.trigger(name)
    if tl.trigger ~= "" and tl.trigger == name then P.play() return true end
    return false
  end
  function P.time() return M.cycleTime(tl, P.u) end
  function P.pose() return M.pose(tl, M.cycleTime(tl, P.u)) end
  function P.update(dt)
    local out = {}
    if not P.playing or P.paused or not finite(dt) or dt <= 0 then return out end
    local d = tl.duration
    local u0, u1 = P.last, P.u + dt * P.speed
    if tl.loop == "once" and u1 >= d then u1 = d end
    if #tl.events > 0 then
      local k0 = u0 < 0 and 0 or floor(u0 / d)
      local k1 = floor(u1 / d)
      if tl.loop == "once" then k0, k1 = 0, 0 end
      if k1 - k0 > 16 then k0 = k1 - 16 end
      local hit = {}
      for k = k0, k1 do
        for _, e in ipairs(tl.events) do
          if e.t <= d then
            local T = k * d + ((tl.loop == "pingpong" and k % 2 == 1) and d - e.t or e.t)
            if T > u0 and T <= u1 then hit[#hit + 1] = {T = T, name = e.name, i = #hit} end
          end
        end
      end
      table.sort(hit, function(a, b) if a.T ~= b.T then return a.T < b.T end return a.i < b.i end)
      for _, h in ipairs(hit) do out[#out + 1] = h.name end
    end
    P.u, P.last = u1, u1
    if tl.loop == "once" and P.u >= d then
      P.playing, P.finished = false, true
      if tl.onEnd ~= "" then out[#out + 1] = tl.onEnd end
    end
    return out
  end
  if tl.autoplay then P.play() end
  return P
end

-- ---------------------------------------------------------------- camera rails
local function catmull(p0, p1, p2, p3, t)
  local t2, t3 = t * t, t * t * t
  local o = {}
  for i = 1, 3 do
    o[i] = 0.5 * ((2 * p1[i]) + (-p0[i] + p2[i]) * t + (2 * p0[i] - 5 * p1[i] + 4 * p2[i] - p3[i]) * t2 +
                  (-p0[i] + 3 * p1[i] - 3 * p2[i] + p3[i]) * t3)
  end
  return o
end

function M.rail(j)
  if type(j) ~= "table" then return nil end
  local r = {duration = num(j.duration, 4, 0.1, 600), ease = type(j.ease) == "string" and j.ease or "ease", play = j.play or "none",
             trigger = j.trigger or "", onEnd = j.onEnd or "", points = {}}
  if r.play ~= "enter" and r.play ~= "end" and r.play ~= "trigger" then r.play = "none" end
  for _, pj in ipairs(type(j.points) == "table" and j.points or {}) do
    if #r.points >= 64 then break end
    if type(pj) == "table" and type(pj.pos) == "table" and #pj.pos >= 3 then
      local w = {pos = {}, look = {0, 1, 0}, fov = num(pj.fov, 0, 0, 170)}
      for i = 1, 3 do
        w.pos[i] = num(pj.pos[i], 0, -1e5, 1e5)
        if type(pj.look) == "table" and #pj.look >= 3 then w.look[i] = num(pj.look[i], w.look[i], -1e5, 1e5) end
      end
      r.points[#r.points + 1] = w
    end
  end
  if #r.points == 0 then return nil end
  return r
end

function M.evalRail(r, t)
  local n = #r.points
  local p = M.ease(r.ease, clamp(t / max(r.duration, 0.1), 0, 1)) * (n - 1)
  local i = min(floor(p), max(0, n - 2))
  local f = n == 1 and 0 or p - i
  local function P(k) return r.points[min(max(k, 0), n - 1) + 1] end
  local a, b, c, d = P(i - 1), P(i), P(i + 1), P(i + 2)
  local eye = catmull(a.pos, b.pos, c.pos, d.pos, f)
  local tgt = catmull(a.look, b.look, c.look, d.look, f)
  return {eye = eye, target = tgt, fov = b.fov + (c.fov - b.fov) * f}
end

function M.railPlayer(r)
  local P = {rail = r, t = 0, playing = false, ended = false}
  function P.play() P.t, P.playing, P.ended = 0, true, false end
  function P.stop() P.t, P.playing, P.ended = 0, false, false end
  function P.trigger(name)
    if r.trigger ~= "" and r.trigger == name then P.play() return true end
    return false
  end
  -- returns playing, event (the onEnd name once, when the rail ends)
  function P.update(dt)
    if not P.playing then return false end
    if finite(dt) and dt > 0 then P.t = P.t + dt end
    if P.t >= r.duration then
      P.t, P.playing = r.duration, false
      if not P.ended then
        P.ended = true
        if r.onEnd ~= "" then return false, r.onEnd end
      end
    end
    return P.playing
  end
  function P.sample() return M.evalRail(r, P.t) end
  return P
end

return M
