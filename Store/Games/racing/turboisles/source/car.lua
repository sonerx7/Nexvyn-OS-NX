-- car.lua: car meshes, arcade driving physics with drifting, mini-turbos, nitro and boost pads, and the AI drivers.
local B = require("b3d")
local T = require("track")
local C = {}

local sqrt, sin, cos, atan, floor, min, max, abs, pi = math.sqrt, math.sin, math.cos, math.atan, math.floor, math.min,
  math.max, math.abs, math.pi

C.TOP = 58          -- top speed in units per second (shown as km/h x 3.6 x 1.25)
C.MODELS = {
  {key = "comet", acc = 1.0, top = 1.0, grip = 1.0, turn = 1.0, color = "#2F80ED", stripe = "#FFFFFF"},
  {key = "swift", acc = 1.12, top = 0.97, grip = 1.15, turn = 1.12, color = "#27C26C", stripe = "#103A22"},
  {key = "bolt", acc = 0.94, top = 1.07, grip = 0.92, turn = 0.95, color = "#F2C94C", stripe = "#2B2B2B"},
}
C.AI_COLORS = {"#EB5757", "#9B51E0", "#F2994A", "#2D9CDB", "#E84393", "#6FCF97", "#BDBDBD"}
C.AI_NAMES = {"Mako", "Juno", "Rio", "Kai", "Vex", "Nova", "Taro"}

local function shade(hex, k)
  local r, g, b = tonumber(hex:sub(2, 3), 16), tonumber(hex:sub(4, 5), 16), tonumber(hex:sub(6, 7), 16)
  local function f(v) return max(0, min(255, floor(v * k + 0.5))) end
  return string.format("#%02X%02X%02X", f(r), f(g), f(b))
end
C.shade = shade

-- a low-poly sports car facing +x (length 4.4, width 2.0)
local meshCache = {}
function C.mesh(color, stripe, style)
  local key = color .. (stripe or "") .. (style or 1)
  if meshCache[key] then return meshCache[key] end
  local b = B.new()
  local top, side, dark = shade(color, 1.18), color, shade(color, 0.7)
  style = style or 1
  -- chassis and nose
  b:box(0, 0.55, 0, 2.15, 0.3, 0.98, 0, top, side, side, dark)
  b:box(1.55, 0.42, 0, 0.62, 0.16, 0.92, 0, top, side)
  b:box(-1.9, 0.62, 0, 0.3, 0.26, 0.96, 0, top, dark)
  -- cabin and glass
  local cl = style == 3 and 0.8 or 0.95
  b:box(-0.35, 1.04, 0, cl, 0.22, 0.78, 0, "#1B2A44", "#22355A", "#2C4470")
  b:box(-0.35, 0.86, 0, cl + 0.12, 0.05, 0.86, 0, side, side)
  -- stripe and spoiler
  if stripe then b:box(0.2, 0.86, 0, 1.9, 0.02, 0.18, 0, stripe, stripe) end
  b:box(-2.05, 1.28, 0, 0.26, 0.05, 1.0, 0, top, dark)
  b:box(-2.05, 1.06, 0.7, 0.08, 0.2, 0.06, 0, dark, dark)
  b:box(-2.05, 1.06, -0.7, 0.08, 0.2, 0.06, 0, dark, dark)
  -- wheels (cylinders along z)
  for _, wx in ipairs({1.38, -1.38}) do
    for _, wz in ipairs({0.98, -0.98}) do
      for k = 0, 9 do
        local a0, a1 = k / 10 * 2 * pi, (k + 1) / 10 * 2 * pi
        local x0, y0, x1, y1 = cos(a0) * 0.44, sin(a0) * 0.44, cos(a1) * 0.44, sin(a1) * 0.44
        local zi, zo = wz - 0.16 * (wz > 0 and 1 or -1), wz + 0.12 * (wz > 0 and 1 or -1)
        b:quad({wx + x0, 0.44 + y0, zi}, {wx + x1, 0.44 + y1, zi}, {wx + x1, 0.44 + y1, zo}, {wx + x0, 0.44 + y0, zo},
               "#18191E", x0 + x1, y0 + y1, 0)
        b:tri(wx, 0.44, zo, wx + x0, 0.44 + y0, zo, wx + x1, 0.44 + y1, zo, k % 2 == 0 and "#C8CDD8" or "#8D94A5", 0, 0, wz)
      end
    end
  end
  local m = b:mesh()
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
               color = color, slot = slot, wallT = 0, place = slot + 1, offT = 0, skid = 0}
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

-- ---------------------------------------------------------------- driving
-- inp = {gas 0..1, brake 0..1, steer -1..1, drift bool, nitro bool}; events go to car.events (sounds, effects)
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
  car.steer = car.steer + (inp.steer - car.steer) * min(1, dt * 9)
  local sp = abs(v)
  local speedK = min(1, sp / 16) * (1 - 0.3 * min(1, sp / C.TOP))
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
  car.v = v
  -- move
  car.x = car.x + cos(car.va) * v * dt
  car.z = car.z + sin(car.va) * v * dt
  local prev = car.idx
  local i, lat, f, y = T.locate(tr, car.x, car.z, car.idx)
  car.idx, car.lat, car.f = i, lat, f
  -- barriers
  local limit = hw + 5.0
  if abs(lat) > limit then
    local s = lat > 0 and 1 or -1
    local push = lat - s * limit
    car.x = car.x - tr.rx[i] * push
    car.z = car.z - tr.rz[i] * push
    car.lat = s * limit
    -- slide along the wall, lose speed by the impact angle
    local wallA = atan(tr.fz[i], tr.fx[i])
    local into = abs(sin(angDiff(car.va, wallA)))
    car.v = car.v * (1 - min(0.55, into * 0.9 + 0.05))
    car.va = wallA + (car.v >= 0 and 0 or pi)
    car.a = car.a + angDiff(wallA, car.a) * 0.35
    if car.wallT <= 0 and into > 0.12 then
      ev[#ev + 1] = {"wall", car, into, s}
      car.wallT = 0.25
    end
    if car.drift then car.drift, car.driftT, car.tier = nil, 0, 0 end
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
  -- laps
  car.time = car.time + dt
  local N = tr.N
  local rel = (i - (car.startIdx or 0)) % N
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
  local look = 5 + floor(car.v * 0.22)
  local ti = (car.idx + look) % N
  local lat = tr.line[ti] + car.offset
  -- move over for a car right ahead
  for _, o in ipairs(cars) do
    if o ~= car then
      local d = (o.idx - car.idx) % N
      if d > 0 and d < 7 and abs(o.lat - lat) < 3.2 then
        lat = lat + ((o.lat > lat) and -3.4 or 3.4)
      end
    end
  end
  local hw = tr.w / 2 - 1.6
  lat = max(-hw, min(hw, lat))
  local tx, _, tz = T.point(tr, ti, lat)
  local want = atan(tz - car.z, tx - car.x)
  local steer = max(-1, min(1, angDiff(want, car.a) * 2.6))
  -- corner speed from the curvature ahead
  local c = 0
  for k = 2, 22, 2 do c = max(c, abs(tr.cur[(car.idx + k + floor(car.v * 0.3)) % N])) end
  local corner = C.TOP * car.stats.top * car.skill * (1 - min(0.5, c * 11))
  -- rubber band towards the player
  local gap = 0
  if player then gap = (C.progress(player, tr) - C.progress(car, tr)) / N end
  car.rubber = max(0.9, min(1.12, 1 + gap * 0.28))
  local gas, brake = 1, 0
  if car.v > corner * car.rubber + 2 then gas, brake = 0, min(1, (car.v - corner) / 12) end
  local nitro = false
  if c < 0.006 and car.nitro > 0.5 and gap > -0.15 then nitro = true end
  if car.nitroOn and car.nitro > 0.05 and c < 0.01 then nitro = true end
  car.aiInput = car.aiInput or {}
  local inp = car.aiInput
  inp.gas, inp.brake, inp.steer, inp.drift, inp.driftPressed, inp.nitro = gas, brake, steer, false, false, nitro
  car.skillNow = car.skill * car.rubber
  return inp
end

-- cars push each other apart
function C.collide(cars, ev)
  for a = 1, #cars do
    local A = cars[a]
    for b = a + 1, #cars do
      local Bc = cars[b]
      local dx, dz = Bc.x - A.x, Bc.z - A.z
      local d2 = dx * dx + dz * dz
      if d2 < 3.4 * 3.4 and d2 > 0.0001 and abs(A.y - Bc.y) < 2 then
        local d = sqrt(d2)
        local push = (3.4 - d) / 2
        local nx, nz = dx / d, dz / d
        A.x, A.z = A.x - nx * push, A.z - nz * push
        Bc.x, Bc.z = Bc.x + nx * push, Bc.z + nz * push
        local rv = (Bc.v - A.v)
        if abs(rv) > 2 then
          A.v, Bc.v = A.v + rv * 0.25, Bc.v - rv * 0.25
          ev[#ev + 1] = {"bump", A, Bc, abs(rv)}
        end
      end
    end
  end
end

return C
