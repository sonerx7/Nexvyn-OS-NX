-- car.lua: car meshes, arcade driving physics with drifting, mini-turbos, nitro and boost pads, and the AI drivers.
-- Contacts are arcade style: cars are capsules that push each other apart, trade a little speed along their heading
-- and get a short sideways slide (car.kx, car.kz) for the rest, so a touch never turns a car round. Walls take speed
-- by the impact angle, bounce the car off a little and steer it back along the barrier gently.
local B = require("b3d")
local T = require("track")
local C = {}

local sqrt, sin, cos, atan, floor, min, max, abs, pi, exp = math.sqrt, math.sin, math.cos, math.atan, math.floor,
  math.min, math.max, math.abs, math.pi, math.exp

C.TOP = 58          -- top speed in units per second
C.MODELS = {
  {key = "comet", acc = 1.0, top = 1.0, grip = 1.0, turn = 1.0, color = "#2F80ED", stripe = "#FFFFFF"},
  {key = "swift", acc = 1.12, top = 0.97, grip = 1.15, turn = 1.12, color = "#27C26C", stripe = "#103A22"},
  {key = "bolt", acc = 0.94, top = 1.07, grip = 0.92, turn = 0.95, color = "#F2C94C", stripe = "#2B2B2B"},
}
C.AI_COLORS = {"#EB5757", "#9B51E0", "#F2994A", "#2D9CDB", "#E84393", "#6FCF97", "#BDBDBD"}
C.AI_NAMES = {"Mako", "Juno", "Rio", "Kai", "Vex", "Nova", "Taro"}
-- paint colours with a livery texture (tools/gen_textures.py writes textures/car_<hex>.png for each)
local CAR_TEX = {}
for _, h in ipairs({"#2F80ED", "#27C26C", "#F2C94C", "#EB5757", "#9B51E0", "#F2994A", "#2D9CDB", "#E84393", "#6FCF97",
                    "#BDBDBD"}) do CAR_TEX[h] = true end

local function clamp(v, a, b) return v < a and a or (v > b and b or v) end

local function shade(hex, k)
  local r, g, b = tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
  local function f(v) return max(0, min(255, floor(v * k + 0.5))) end
  return string.format("#%02X%02X%02X", f(r), f(g), f(b))
end
C.shade = shade

-- livery texture layout (256 px), mirrored in tools/gen_textures.py
local function R(x0, y0, x1, y1) local e = 1.5 / 256 return {x0 / 256 + e, y0 / 256 + e, x1 / 256 - e, y1 / 256 - e} end
local UV = {side = R(0, 0, 256, 64), top = R(0, 64, 256, 128), front = R(0, 128, 128, 176), rear = R(128, 128, 256, 176),
            glass = R(0, 176, 128, 224), roof = R(128, 176, 256, 224), tyre = R(0, 224, 128, 256),
            rim = R(128, 224, 160, 256), dark = R(160, 224, 256, 256)}
UV.sideM = {UV.side[3], UV.side[2], UV.side[1], UV.side[4]}    -- the far side, mirrored so the number reads
-- part of a rectangle: fractions (a..b) along u and (c..d) along v
local function sub(r, a, b, c, d)
  return {r[1] + (r[3] - r[1]) * a, r[2] + (r[4] - r[2]) * (c or 0), r[1] + (r[3] - r[1]) * b, r[2] + (r[4] - r[2]) * (d or 1)}
end
local function subM(r, a, b, c, d) local q = sub(r, a, b, c, d) return {q[3], q[2], q[1], q[4]} end

-- a low-poly sports car facing +x (length 4.4, width 2.0)
local meshCache = {}
function C.mesh(color, stripe, style)
  local key = color .. (stripe or "") .. (style or 1)
  if meshCache[key] then return meshCache[key] end
  local tex = B.textured() and CAR_TEX[color]
  local function K(c, t) if tex then return t or "#FFFFFF" end return c end
  local b = B.new(UV.dark[1], UV.dark[2])
  local top, side, dark = shade(color, 1.18), color, shade(color, 0.7)
  style = style or 1
  local L = 2.15
  local function ux(x) return (x + L) / (2 * L) end    -- position along the car -> fraction of the side / top art
  -- chassis
  b:box(0, 0.55, 0, L, 0.3, 0.98, 0, K(top), K(side, "#F2F2F2"), K(side, "#F2F2F2"), K(dark, "#FFFFFF"),
        tex and {top = UV.top, bottom = UV.dark, pz = UV.side, nz = UV.sideM, px = UV.front, nx = UV.rear})
  -- nose and tail
  b:box(1.55, 0.42, 0, 0.62, 0.16, 0.92, 0, K(top), K(side, "#E8E8E8"), nil, nil,
        tex and {top = sub(UV.top, ux(0.93), 1, 0.04, 0.96), pz = sub(UV.side, ux(0.93), 1, 0.55, 0.85),
                 nz = subM(UV.side, ux(0.93), 1, 0.55, 0.85), px = sub(UV.front, 0, 1, 0.5, 1), nx = UV.dark})
  b:box(-1.9, 0.62, 0, 0.3, 0.26, 0.96, 0, K(top), K(dark, "#F2F2F2"), nil, nil,
        tex and {top = sub(UV.top, 0, ux(-1.6), 0.02, 0.98), pz = sub(UV.side, 0, ux(-1.6), 0, 0.8),
                 nz = subM(UV.side, 0, ux(-1.6), 0, 0.8), nx = UV.rear, px = UV.dark})
  -- cabin and glass
  local cl = style == 3 and 0.8 or 0.95
  b:box(-0.35, 1.04, 0, cl, 0.22, 0.78, 0, K("#1B2A44"), K("#22355A"), K("#2C4470"), nil,
        tex and {top = UV.roof, pz = UV.glass, nz = UV.glass, px = UV.glass, nx = UV.glass})
  b:box(-0.35, 0.86, 0, cl + 0.12, 0.05, 0.86, 0, K(side), K(side, "#DDDDDD"), nil, nil,
        tex and {top = UV.roof, pz = UV.dark, nz = UV.dark, px = UV.dark, nx = UV.dark})
  if stripe and not tex then b:box(0.2, 0.86, 0, 1.9, 0.02, 0.18, 0, stripe, stripe) end
  -- spoiler
  b:box(-2.05, 1.28, 0, 0.26, 0.05, 1.0, 0, K(top), K(dark, "#BBBBBB"), nil, nil,
        tex and {top = UV.roof, pz = UV.dark, nz = UV.dark, px = UV.dark, nx = UV.dark})
  b:box(-2.05, 1.06, 0.7, 0.08, 0.2, 0.06, 0, K(dark, "#FFFFFF"), K(dark, "#FFFFFF"))
  b:box(-2.05, 1.06, -0.7, 0.08, 0.2, 0.06, 0, K(dark, "#FFFFFF"), K(dark, "#FFFFFF"))
  -- wheels (cylinders along z): tread around, a spoked rim on the outside
  local T0, RM = UV.tyre, UV.rim
  local rcu, rcv, rru, rrv = (RM[1] + RM[3]) / 2, (RM[2] + RM[4]) / 2, (RM[3] - RM[1]) / 2, (RM[4] - RM[2]) / 2
  for _, wx in ipairs({1.38, -1.38}) do
    for _, wz in ipairs({0.98, -0.98}) do
      for k = 0, 11 do
        local a0, a1 = k / 12 * 2 * pi, (k + 1) / 12 * 2 * pi
        local x0, y0, x1, y1 = cos(a0) * 0.44, sin(a0) * 0.44, cos(a1) * 0.44, sin(a1) * 0.44
        local zi, zo = wz - 0.16 * (wz > 0 and 1 or -1), wz + 0.12 * (wz > 0 and 1 or -1)
        local u0, u1 = T0[1] + (T0[3] - T0[1]) * k / 12, T0[1] + (T0[3] - T0[1]) * (k + 1) / 12
        b:quadUV({wx + x0, 0.44 + y0, zi}, {wx + x1, 0.44 + y1, zi}, {wx + x1, 0.44 + y1, zo}, {wx + x0, 0.44 + y0, zo},
                 K("#18191E", "#FFFFFF"), x0 + x1, y0 + y1, 0, u0, T0[2], u1, T0[2], u1, T0[4], u0, T0[4])
        b:tri(wx, 0.44, zo, wx + x0, 0.44 + y0, zo, wx + x1, 0.44 + y1, zo, K(k % 2 == 0 and "#C8CDD8" or "#8D94A5", "#FFFFFF"),
              0, 0, wz, rcu, rcv, rcu + cos(a0) * rru, rcv + sin(a0) * rrv, rcu + cos(a1) * rru, rcv + sin(a1) * rrv)
      end
    end
  end
  local m = b:mesh()
  if tex then m:setTexture("bundle:/textures/car_" .. color:sub(2):upper() .. ".png") end
  -- lights: a glow mesh
  local g = B.new()
  g:box(2.18, 0.62, 0.62, 0.04, 0.09, 0.22, 0, "#FFF6D0", "#FFF6D0")
  g:box(2.18, 0.62, -0.62, 0.04, 0.09, 0.22, 0, "#FFF6D0", "#FFF6D0")
  g:box(-2.21, 0.72, 0.6, 0.04, 0.08, 0.26, 0, "#FF3040", "#FF3040")
  g:box(-2.21, 0.72, -0.6, 0.04, 0.08, 0.26, 0, "#FF3040", "#FF3040")
  local lights = g:mesh()
  meshCache[key] = {body = m, lights = lights}
  return meshCache[key]
end

-- exhaust flame (a glow cone pointing backwards, along -x)
function C.flameMesh()
  if meshCache.flame then return meshCache.flame end
  local b = B.new()
  for k = 0, 7 do
    local a0, a1 = k / 8 * 2 * pi, (k + 1) / 8 * 2 * pi
    b:tri(0, cos(a0) * 0.28, sin(a0) * 0.28, 0, cos(a1) * 0.28, sin(a1) * 0.28, -1.6, 0, 0, "#FF8A1A")
    b:tri(0, cos(a1) * 0.28, sin(a1) * 0.28, 0, cos(a0) * 0.28, sin(a0) * 0.28, -1.6, 0, 0, "#FF8A1A")
  end
  meshCache.flame = b:mesh()
  return meshCache.flame
end

-- ---------------------------------------------------------------- state
function C.new(tr, slot, model, color, ai)
  local i = (-6 - slot * 4) % tr.N           -- grid: two columns behind the line
  local lat = (slot % 2 == 0 and -1 or 1) * tr.w * 0.22
  local x, y, z = T.point(tr, i, lat)
  local a = atan(tr.fz[i], tr.fx[i])
  local car = {x = x, y = y, z = z, a = a, va = a, v = 0, steer = 0, drift = nil, driftT = 0, tier = 0, boostT = 0,
               boostK = 0, nitro = 0.35, nitroOn = false, idx = i, lat = lat, f = 0, lap = 0, half = false, finished = false,
               time = 0, lapStart = 0, lapTimes = {}, best = nil, pitch = 0, roll = 0, hop = 0, stats = model, ai = ai,
               color = color, slot = slot, wallT = 0, place = slot + 1, offT = 0, skid = 0, kx = 0, kz = 0, bumpT = 0,
               stuckT = 0, hw = tr.w / 2}
  car.meshes = C.mesh(color, model.stripe, (slot % 3) + 1)
  if ai then
    car.skill = ai.skill
    car.offset = ai.offset
    car.name = ai.name
  end
  return car
end

-- progress along the race in samples
function C.progress(car, tr)
  local N = tr.N
  local rel = (car.idx - (car.startIdx or 0)) % N + car.f
  if not car.half and rel > N * 0.5 then rel = rel - N end   -- still behind the line it is about to cross
  return car.lap * N + rel
end

local function angDiff(a, b) return (a - b + pi) % (2 * pi) - pi end
C.angDiff = angDiff

-- puts a stuck car back on the road, pointing down the track (keeps lap progress)
function C.recover(car, tr)
  local i = (car.idx + 2) % tr.N
  local lat = clamp(car.lat, -tr.w / 2 + 2.5, tr.w / 2 - 2.5)
  car.x, car.y, car.z = T.point(tr, i, lat)
  car.idx, car.lat = i, lat
  car.a = atan(tr.fz[i], tr.fx[i])
  car.va = car.a
  car.v = max(car.v, 14)
  car.kx, car.kz, car.stuckT, car.wallT = 0, 0, 0, 0
  car.drift, car.driftT, car.tier = nil, 0, 0
  car.recoverT = 1.2      -- blinks and ignores contacts for a moment
end

-- ---------------------------------------------------------------- driving
-- inp = {gas 0..1, brake 0..1, steer -1..1, drift bool, nitro bool}; events go to ev (sounds, effects)
function C.update(car, tr, inp, dt, ev)
  local st = car.stats
  local hw = tr.w / 2
  local boosting = car.boostT > 0 or (car.nitroOn and car.nitro > 0)
  local off = abs(car.lat) > hw + 1.5
  local top = C.TOP * st.top * (car.ai and (car.skillNow or car.skill) or 1)
  if boosting then top = top * 1.32 end
  if off then top = top * 0.62; car.offT = car.offT + dt else car.offT = 0 end
  local v = car.v
  -- throttle and brakes
  if inp.gas > 0 and v >= -1 then
    local k = 1 - (v / top) ^ 2
    v = v + 30 * st.acc * inp.gas * max(0.15, k) * dt * (boosting and 1.6 or 1)
  end
  if inp.brake > 0 then
    if v > 1 then v = v - 52 * inp.brake * dt else v = max(-14, v - 14 * inp.brake * dt) end
  end
  if inp.gas == 0 and inp.brake == 0 then v = v - v * 0.35 * dt end
  if v > top then v = v - (v - top) * (boosting and 1 or 2.4) * dt end
  -- steering
  car.steer = car.steer + (inp.steer - car.steer) * min(1, dt * 10)
  local sp = abs(v)
  local speedK = min(1, sp / 14) * (1 - 0.32 * min(1, sp / C.TOP))
  local turn = 1.75 * st.turn
  local yaw
  if car.drift then
    local d = car.drift
    yaw = d * (1.05 + 0.7 * car.steer * d) * turn * speedK
    car.driftT = car.driftT + dt * (0.7 + 0.6 * max(0, car.steer * d))
    local tier = car.driftT > 2.7 and 3 or (car.driftT > 1.6 and 2 or (car.driftT > 0.75 and 1 or 0))
    if tier > car.tier then car.tier = tier; ev[#ev + 1] = {"tier", car, tier} end
    car.nitro = min(1, car.nitro + dt * 0.07)
    if not inp.drift or sp < 14 or off then
      -- release: a mini-turbo for the colour reached
      if car.tier > 0 then
        car.boostT = max(car.boostT, ({0.55, 0.95, 1.45})[car.tier])
        ev[#ev + 1] = {"turbo", car, car.tier}
      end
      car.drift, car.driftT, car.tier = nil, 0, 0
    end
  else
    yaw = car.steer * turn * speedK * (v < 0 and -1 or 1)
    if inp.driftPressed and abs(inp.steer) > 0.25 and sp > 20 and not off then
      car.drift = inp.steer > 0 and 1 or -1
      car.driftT, car.tier, car.hop = 0, 0, 0.18
      ev[#ev + 1] = {"drift", car}
    end
  end
  car.a = car.a + yaw * dt
  local grip = car.drift and 2.4 or (8.5 * st.grip)
  if off then grip = grip * 0.7 end
  car.va = car.va + angDiff(car.a, car.va) * min(1, grip * dt)
  car.skid = abs(angDiff(car.a, car.va))
  -- nitro
  car.nitroOn = inp.nitro and car.nitro > 0.02
  if car.nitroOn then car.nitro = max(0, car.nitro - dt * 0.32) end
  if car.boostT > 0 then car.boostT = car.boostT - dt end
  car.boostK = car.boostK + ((boosting and 1 or 0) - car.boostK) * min(1, dt * 5)
  if car.hop > 0 then car.hop = car.hop - dt end
  if car.bumpT > 0 then car.bumpT = car.bumpT - dt end
  if car.recoverT then
    car.recoverT = car.recoverT - dt
    if car.recoverT <= 0 then car.recoverT = nil end
  end
  car.v = v
  -- move: heading velocity plus the sideways slide from contacts, which fades out quickly
  car.x = car.x + (cos(car.va) * v + car.kx) * dt
  car.z = car.z + (sin(car.va) * v + car.kz) * dt
  local kd = exp(-dt * 5)
  car.kx, car.kz = car.kx * kd, car.kz * kd
  local prev = car.idx
  local i, lat, f, y = T.locate(tr, car.x, car.z, car.idx)
  car.idx, car.lat, car.f = i, lat, f
  -- barriers
  local limit = hw + 5.0
  if abs(lat) > limit then
    local s = lat > 0 and 1 or -1
    local push = lat - s * limit
    local rx, rz = tr.rx[i], tr.rz[i]
    car.x = car.x - rx * push
    car.z = car.z - rz * push
    car.lat = s * limit
    local wallA = atan(tr.fz[i], tr.fx[i])
    local mv = car.v >= 0 and car.va or car.va + pi            -- direction of motion
    local tA = abs(angDiff(mv, wallA)) <= pi * 0.5 and wallA or wallA + pi
    local into = abs(sin(angDiff(mv, tA)))                     -- 0 = grazing, 1 = head-on
    if car.wallT <= 0 then
      -- a fresh impact: speed lost by the angle, a small bounce off the wall
      car.v = car.v * (1 - min(0.4, into * 0.55))
      car.kx = car.kx - rx * s * (1.2 + 5 * into)
      car.kz = car.kz - rz * s * (1.2 + 5 * into)
      if into > 0.1 then ev[#ev + 1] = {"wall", car, into, s} end
      car.wallT = 0.3
      if car.drift and into > 0.35 then car.drift, car.driftT, car.tier = nil, 0, 0 end
    else
      car.v = car.v * (1 - 0.6 * dt)                           -- scraping along
    end
    -- the velocity slides along the barrier; no slide into it
    car.va = car.v >= 0 and tA or tA + pi
    local kl = car.kx * rx + car.kz * rz
    if kl * s > 0 then car.kx, car.kz = car.kx - rx * kl, car.kz - rz * kl end
    -- the nose turns back along the wall at a limited rate (never a whip round)
    local want = car.v >= 0 and tA or tA + pi
    local dA = angDiff(want, car.a)
    if abs(dA) < pi * 0.6 then car.a = car.a + clamp(dA, -2.4 * dt, 2.4 * dt) end
  end
  if car.wallT > 0 then car.wallT = car.wallT - dt end
  -- height and pitch
  local hop = car.hop > 0 and sin((0.18 - car.hop) / 0.18 * pi) * 0.45 or 0
  car.y = y + hop
  local j = (i + 1) % tr.N
  local slope = (tr.py[j] - tr.py[i]) / T.STEP
  car.pitch = car.pitch + (atan(slope) - car.pitch) * min(1, dt * 10)
  local rollT = car.drift and -car.drift * 0.07 or -car.steer * min(1, sp / C.TOP) * 0.05
  car.roll = car.roll + (rollT - car.roll) * min(1, dt * 8)
  -- boost pads
  for _, p in ipairs(tr.pads) do
    local d = (i - p.i) % tr.N
    if d <= 3 and abs(lat - p.off) < 3.2 then
      if car.boostT < 1.0 then ev[#ev + 1] = {"pad", car} end
      car.boostT = max(car.boostT, 1.25)
    end
  end
  -- stuck (against a wall, turned round): back on the road after a moment
  local fwd = cos(car.a) * tr.fx[i] + sin(car.a) * tr.fz[i]
  if (abs(car.v) < 3 and (inp.gas > 0 or car.ai)) or (car.ai and fwd < -0.3) then
    car.stuckT = car.stuckT + dt
    if car.stuckT > (car.ai and 1.5 or 2.5) then
      C.recover(car, tr)
      ev[#ev + 1] = {"recover", car}
    end
  else
    car.stuckT = 0
  end
  -- laps
  car.time = car.time + dt
  local N = tr.N
  local rel = (car.idx - (car.startIdx or 0)) % N
  if rel > N * 0.4 and rel < N * 0.6 then car.half = true end
  local prel = (prev - (car.startIdx or 0)) % N
  if car.half and prel > N * 0.8 and rel < N * 0.2 then
    car.half = false
    car.lap = car.lap + 1
    local lt = car.time - car.lapStart
    car.lapTimes[#car.lapTimes + 1] = lt
    car.lapStart = car.time
    if not car.best or lt < car.best then car.best = lt end
    ev[#ev + 1] = {"lap", car, lt}
  elseif prel < N * 0.2 and rel > N * 0.8 then
    -- drove backwards over the line
    car.lap = car.lap - 1
    car.half = true
  end
end

-- ---------------------------------------------------------------- AI
function C.think(car, tr, cars, leader, player, dt)
  local N = tr.N
  local hw = tr.w / 2 - 1.6
  local look = 5 + floor(car.v * 0.22)
  local ti = (car.idx + look) % N
  local lat = tr.line[ti] + car.offset
  -- boost pads close ahead pull the sharper drivers onto them
  if car.skill > 0.9 then
    for _, p in ipairs(tr.pads) do
      local d = (p.i - car.idx) % N
      if d > 2 and d < 16 and abs(p.off - lat) < 6 then lat = p.off end
    end
  end
  -- traffic: pass a slower car ahead on the side with room, follow it when there is none, give room alongside
  local follow
  for _, o in ipairs(cars) do
    if o ~= car and not o.recoverT then
      local d = (o.idx - car.idx) % N
      if d > N / 2 then d = d - N end
      local dl = o.lat - car.lat
      if d >= 1 and d < 9 and abs(o.lat - lat) < 3.2 then
        local left, right = o.lat - 3.8, o.lat + 3.8
        local pick = abs(left - lat) < abs(right - lat) and left or right
        if pick < -hw or pick > hw then pick = (pick == left) and right or left end
        if pick >= -hw and pick <= hw then lat = pick
        elseif d < 5 and car.v > o.v then follow = min(follow or 1e9, o.v) end
        if d < 4 and abs(dl) < 2.3 and car.v > o.v + 1 then follow = min(follow or 1e9, o.v + 0.5) end
      elseif d > -2 and d < 2 and abs(dl) < 2.8 then
        lat = lat + (dl > 0 and -1.4 or 1.4)
      end
    end
  end
  lat = max(-hw, min(hw, lat))
  local tx, _, tz = T.point(tr, ti, lat)
  local want = atan(tz - car.z, tx - car.x)
  local gain = car.bumpT > 0 and 1.6 or 2.6                     -- calmer right after a contact
  local steer = max(-1, min(1, angDiff(want, car.a) * gain))
  -- corner speed from the curvature ahead
  local c = 0
  for k = 2, 22, 2 do c = max(c, abs(tr.cur[(car.idx + k + floor(car.v * 0.3)) % N])) end
  local corner = C.TOP * car.stats.top * car.skill * (1 - min(0.5, c * 11))
  -- rubber band towards the player
  local gap = 0
  if player then gap = (C.progress(player, tr) - C.progress(car, tr)) / N end
  car.rubber = max(0.9, min(1.12, 1 + gap * 0.28))
  local limit = corner * car.rubber
  if follow then limit = min(limit, follow) end
  local gas, brake = 1, 0
  if car.v > limit + 2 then gas, brake = 0, min(1, (car.v - limit) / 12) end
  local nitro = false
  if c < 0.006 and car.nitro > 0.5 and gap > -0.15 and not follow then nitro = true end
  if car.nitroOn and car.nitro > 0.05 and c < 0.01 then nitro = true end
  car.aiInput = car.aiInput or {}
  local inp = car.aiInput
  inp.gas, inp.brake, inp.steer, inp.drift, inp.driftPressed, inp.nitro = gas, brake, steer, false, false, nitro
  car.skillNow = car.skill * car.rubber
  return inp
end

-- ---------------------------------------------------------------- contacts
local CAP_L, CAP_R = 1.25, 0.98     -- capsule: half length of the core segment, radius (a 4.5 x 2.0 car)

-- closest points of two segments p1-q1 and p2-q2 (2D, x/z)
local function closest(p1x, p1z, q1x, q1z, p2x, p2z, q2x, q2z)
  local d1x, d1z, d2x, d2z = q1x - p1x, q1z - p1z, q2x - p2x, q2z - p2z
  local rx, rz = p1x - p2x, p1z - p2z
  local a, e = d1x * d1x + d1z * d1z, d2x * d2x + d2z * d2z
  local f, c, b = d2x * rx + d2z * rz, d1x * rx + d1z * rz, d1x * d2x + d1z * d2z
  local den = a * e - b * b
  local s = den > 1e-6 and clamp((b * f - c * e) / den, 0, 1) or 0
  local t = (b * s + f) / e
  if t < 0 then t, s = 0, clamp(-c / a, 0, 1)
  elseif t > 1 then t, s = 1, clamp((b - c) / a, 0, 1) end
  return p1x + d1x * s, p1z + d1z * s, p2x + d2x * t, p2z + d2z * t
end

-- an impulse (ix, iz) on a car: the part along its heading changes its speed, the rest becomes a sideways slide
local function nudge(car, ix, iz)
  local fx, fz = cos(car.va), sin(car.va)
  local along = ix * fx + iz * fz
  car.v = car.v + along * 0.85
  local lx, lz = ix - along * fx, iz - along * fz
  car.kx, car.kz = car.kx + lx * 0.75, car.kz + lz * 0.75
  local k = sqrt(car.kx * car.kx + car.kz * car.kz)
  if k > 6 then car.kx, car.kz = car.kx / k * 6, car.kz / k * 6 end
end

function C.collide(cars, ev)
  local n = #cars
  for a = 1, n do
    local A = cars[a]
    if not A.recoverT then
      local afx, afz = cos(A.a) * CAP_L, sin(A.a) * CAP_L
      for b = a + 1, n do
        local Bc = cars[b]
        local dx, dz = Bc.x - A.x, Bc.z - A.z
        if not Bc.recoverT and dx * dx + dz * dz < 30 and abs(A.y - Bc.y) < 2 then
          local bfx, bfz = cos(Bc.a) * CAP_L, sin(Bc.a) * CAP_L
          local px, pz, qx, qz = closest(A.x - afx, A.z - afz, A.x + afx, A.z + afz,
                                         Bc.x - bfx, Bc.z - bfz, Bc.x + bfx, Bc.z + bfz)
          local ex, ez = qx - px, qz - pz
          local d2 = ex * ex + ez * ez
          if d2 < (2 * CAP_R) ^ 2 then
            local d = sqrt(d2)
            local nx, nz
            if d > 1e-3 then nx, nz = ex / d, ez / d
            else
              local dd = sqrt(dx * dx + dz * dz) + 1e-6
              nx, nz = dx / dd, dz / dd
            end
            -- separate (half each)
            local push = (2 * CAP_R - d) * 0.5
            A.x, A.z = A.x - nx * push, A.z - nz * push
            Bc.x, Bc.z = Bc.x + nx * push, Bc.z + nz * push
            -- closing speed along the contact normal
            local avx, avz = cos(A.va) * A.v + A.kx, sin(A.va) * A.v + A.kz
            local bvx, bvz = cos(Bc.va) * Bc.v + Bc.kx, sin(Bc.va) * Bc.v + Bc.kz
            local vn = (bvx - avx) * nx + (bvz - avz) * nz
            if vn < 0 then
              local j = -vn * 0.6                                -- a soft, slightly bouncy contact
              nudge(A, -j * nx, -j * nz)
              nudge(Bc, j * nx, j * nz)
              local loss = 1 - min(0.06, -vn * 0.005)            -- both lose a little speed
              A.v, Bc.v = A.v * loss, Bc.v * loss
              if -vn > 2 and (A.bumpT <= 0 or Bc.bumpT <= 0) then ev[#ev + 1] = {"bump", A, Bc, -vn} end
              A.bumpT, Bc.bumpT = 0.4, 0.4
            end
          end
        end
      end
    end
  end
end

return C
