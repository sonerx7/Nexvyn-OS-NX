-- Neon Drift: arcade car physics (shared by the player and the rivals) and the rival driver.
-- Forward of a car with heading `yaw` is (-sin yaw, -cos yaw) in x, z (the model faces -Z); right is (cos yaw, -sin yaw).
local Track = require("nd.track")
local C = {}

C.VMAX = 62        -- m/s top speed without nitro (~223 km/h)
C.NITRO_VMAX = 76

local function clamp(v, a, b) return v < a and a or (v > b and b or v) end
C.clamp = clamp

function C.new(tr, s, lat, opts)
  local x, y, z, tx, tz, i = Track.at(tr, s, lat)
  local car = {
    x = x, y = y, z = z, yaw = math.atan(-tx, -tz), vx = 0, vz = 0, vy = 0, yawRate = 0,
    steer = 0, speed = 0, vF = 0, vR = 0, idx = i, lat = lat, s = s, lap = 0, progress = 0, prevS = s,
    nitro = opts.nitro or 0.35, nitroOn = false, drifting = false, driftT = 0, driftCharge = 0, boostT = 0,
    color = opts.color or "#FF2E88", glow = opts.glow or "#19E6FF", ai = opts.ai, name = opts.name or "",
    skill = opts.skill or 1, laneBias = opts.laneBias or 0, wheelSpin = 0, pitch = 0, roll = 0,
    gear = 1, rpm = 0, hitT = 0, finished = false, finishTime = 0, lapTimes = {}, lapStart = 0, best = nil,
    checkpoint = 0, wrongT = 0, slip = 0, offT = 0, rank = 0, sectorOk = {false, false},
    input = {gas = 0, brake = 0, steer = 0, drift = false, nitro = false},
  }
  return car
end

-- one physics step; returns impact strength against walls (0 = none)
function C.step(car, tr, W, dt, race)
  local inp = car.input
  local s, c = math.sin(car.yaw), math.cos(car.yaw)
  local fx, fz = -s, -c
  local rx, rz = c, -s
  local vF = car.vx * fx + car.vz * fz
  local vR = car.vx * rx + car.vz * rz
  local spd = math.abs(vF)

  -- steering: less lock at speed
  local maxSteer = 0.62 / (1 + spd * 0.045)
  local target = inp.steer * maxSteer
  car.steer = car.steer + (target - car.steer) * math.min(1, dt * 10)

  -- drift state: button + steering at speed, or a hard flick
  local wantDrift = inp.drift and spd > 14 and math.abs(inp.steer) > 0.25
  if wantDrift and not car.drifting then car.drifting = true; car.driftT = 0; car.driftDir = inp.steer > 0 and 1 or -1 end
  if car.drifting and (not inp.drift or spd < 9) then
    if car.driftT > 0.9 then car.boostT = math.min(1.4, car.driftT * 0.45) end   -- release: mini boost
    car.drifting = false
  end

  -- engine and brakes
  local vmax = car.nitroOn and C.NITRO_VMAX or C.VMAX
  vmax = vmax * (car.ai and car.skill or 1)
  local acc = 0
  if inp.gas > 0 then
    local f = clamp(1 - vF / vmax, 0, 1)
    acc = acc + inp.gas * (9 + 17 * f) * (f > 0 and 1 or 0)
  end
  if inp.brake > 0 then
    if vF > 1 then acc = acc - 26 * inp.brake else acc = acc - 9 * inp.brake * (vF > -14 and 1 or 0) end
  end
  car.nitroOn = false
  if inp.nitro and car.nitro > 0.02 and vF > 5 then
    car.nitroOn = true
    car.nitro = math.max(0, car.nitro - dt * 0.28)
    acc = acc + 15
  end
  if car.boostT > 0 then car.boostT = car.boostT - dt; acc = acc + 10 end
  vF = vF + acc * dt
  vF = vF - vF * (0.012 + (inp.gas == 0 and 0.18 or 0)) * dt - (vF > 0 and 1 or -1) * math.min(math.abs(vF), 0.6 * dt)
  if vF > vmax * 1.08 then vF = vF - (vF - vmax) * dt * 2 end

  -- yaw from a bicycle model, extra rotation while drifting
  local wb = 2.65
  local yawRate = -vF * math.tan(car.steer) / wb
  local grip = 9.5
  if car.drifting then
    car.driftT = car.driftT + dt
    yawRate = yawRate * 1.25 - car.driftDir * (0.55 + 0.35 * math.abs(inp.steer)) * clamp(spd / 30, 0, 1)
    grip = 1.9
    car.driftCharge = car.driftCharge + dt
    car.nitro = math.min(1, car.nitro + dt * 0.16 * clamp(math.abs(vR) / 6, 0.4, 1.2))
  end
  car.yawRate = car.yawRate + (yawRate - car.yawRate) * math.min(1, dt * (car.drifting and 5 or 12))
  car.yaw = car.yaw + car.yawRate * dt * (vF < 0 and 1 or 1)
  -- lateral grip
  vR = vR * math.exp(-grip * dt)
  car.slip = math.abs(vR)

  -- back to world velocity in the new heading
  s, c = math.sin(car.yaw), math.cos(car.yaw)
  fx, fz, rx, rz = -s, -c, c, -s
  car.vx = fx * vF + rx * vR
  car.vz = fz * vF + rz * vR
  car.vF, car.vR, car.speed = vF, vR, math.sqrt(car.vx * car.vx + car.vz * car.vz)

  -- move with a swept sphere against the walls
  local dx, dz = car.vx * dt, car.vz * dt
  local len = math.sqrt(dx * dx + dz * dz)
  local impact = 0
  if len > 1e-4 and W then
    local hit = phys.sweepSphere(W, car.x, car.y + 0.7, car.z, 0.95, dx / len, 0, dz / len, len + 0.05)
    if hit then
      local nx, nz = hit.nx, hit.nz
      local nl = math.sqrt(nx * nx + nz * nz)
      if nl > 1e-3 then
        nx, nz = nx / nl, nz / nl
        local move = math.max(0, hit.dist - 0.04)
        car.x, car.z = car.x + dx / len * move, car.z + dz / len * move
        local vn = car.vx * nx + car.vz * nz
        if vn < 0 then
          impact = -vn
          car.vx = car.vx - 1.25 * vn * nx
          car.vz = car.vz - 1.25 * vn * nz
          local keep = clamp(1 - impact * 0.012, 0.75, 0.97)
          car.vx, car.vz = car.vx * keep, car.vz * keep
          -- turn the nose along the wall a bit
          local tyaw = math.atan(-car.vx, -car.vz)
          local d = (tyaw - car.yaw + math.pi) % (2 * math.pi) - math.pi
          if car.vF > 0 then car.yaw = car.yaw + d * 0.25 end
          car.hitT = 0.3
          if car.drifting and impact > 6 then car.drifting = false end
        end
        len = 0
      end
    end
  end
  if len > 0 then car.x, car.z = car.x + dx, car.z + dz end

  -- follow the road surface; safety clamp inside the barriers
  local i, along, lat, sNow = Track.locate(tr, car.x, car.z, car.idx)
  local lim = tr.w / 2 + 0.5 - 0.98
  if math.abs(lat) > lim then
    local push = (math.abs(lat) - lim) * (lat > 0 and 1 or -1)
    car.x = car.x + tr.tz[i] * push
    car.z = car.z - tr.tx[i] * push
    lat = lim * (lat > 0 and 1 or -1)
  end
  car.idx, car.lat = i, lat
  local ty = Track.heightAt(tr, i, along)
  local slope = (tr.y[Track.wrap(i + 1, tr.N)] - tr.y[i]) / tr.ds
  car.y = ty
  car.pitch = car.pitch + (math.atan(slope * (fx * tr.tx[i] + fz * tr.tz[i])) - car.pitch) * math.min(1, dt * 8)
  car.roll = car.roll + ((-car.yawRate * vF * 0.0028) - car.roll) * math.min(1, dt * 6)
  car.wheelSpin = car.wheelSpin + vF * dt / 0.34
  if car.hitT > 0 then car.hitT = car.hitT - dt end

  -- progress, laps and checkpoints
  if race then
    local L = tr.L
    local d = sNow - car.prevS
    if d < -L / 2 then
      -- crossed the line forwards
      if car.sectorOk[1] and car.sectorOk[2] then
        car.lap = car.lap + 1
        car.lapCrossed = true
      end
      car.sectorOk = {false, false}
    elseif d > L / 2 then
      car.lap = car.lap - 1
      car.sectorOk = {true, true}
    end
    if sNow > L * 0.33 and sNow < L * 0.5 then car.sectorOk[1] = true end
    if sNow > L * 0.66 and sNow < L * 0.85 then car.sectorOk[2] = car.sectorOk[1] end
    car.prevS = sNow
    car.s = sNow
    car.progress = car.lap * L + sNow
    -- wrong way: moving against the road direction
    local along_v = car.vx * tr.tx[i] + car.vz * tr.tz[i]
    if along_v < -4 then car.wrongT = car.wrongT + dt else car.wrongT = 0 end
  end

  -- gears and revs for the engine sound
  local g = clamp(math.floor(math.abs(vF) / (C.VMAX / 6)) + 1, 1, 6)
  car.gear = g
  local lo, hi = (g - 1) * C.VMAX / 6, g * C.VMAX / 6
  car.rpm = clamp(0.32 + 0.68 * (math.abs(vF) - lo) / (hi - lo), 0, 1.05)
  if inp.gas == 0 then car.rpm = car.rpm * 0.82 end
  return impact
end

-- car-to-car contacts (circles); returns list of {a, b, strength}
function C.contacts(cars)
  local out = {}
  for a = 1, #cars do
    for b = a + 1, #cars do
      local A, B = cars[a], cars[b]
      local dx, dz = B.x - A.x, B.z - A.z
      local d2 = dx * dx + dz * dz
      local R = 2.1
      if d2 < R * R and d2 > 1e-6 then
        local d = math.sqrt(d2)
        local nx, nz = dx / d, dz / d
        local pen = (R - d) * 0.5
        A.x, A.z = A.x - nx * pen, A.z - nz * pen
        B.x, B.z = B.x + nx * pen, B.z + nz * pen
        local rv = (B.vx - A.vx) * nx + (B.vz - A.vz) * nz
        if rv < 0 then
          local j = -rv * 0.6
          A.vx, A.vz = A.vx - nx * j, A.vz - nz * j
          B.vx, B.vz = B.vx + nx * j, B.vz + nz * j
          out[#out + 1] = {A, B, -rv}
        end
      end
    end
  end
  return out
end

-- rival driver: racing line, braking for corners, overtaking, nitro on straights
local DIFF = {easy = {lat = 12.5, skill = 0.88, nitro = 0.25}, normal = {lat = 15.5, skill = 0.95, nitro = 0.5},
              hard = {lat = 18.0, skill = 1.0, nitro = 0.8}}
C.DIFF = DIFF

function C.drive(car, tr, cars, player, diff, dt, t, showoff)
  local D = DIFF[diff] or DIFF.normal
  local inp = car.input
  local N = tr.N
  local spd = math.max(car.speed, 5)
  -- curvature ahead
  local look = math.floor((spd * 1.4 + 20) / tr.ds)
  local maxK, kSum = 0, 0
  for k = 2, look do
    local cv = tr.curv[Track.wrap(car.idx + k, N)]
    kSum = kSum + cv
    if math.abs(cv) > maxK then maxK = math.abs(cv) end
  end
  local vTarget = math.sqrt(D.lat * car.skill / math.max(maxK, 1e-4))
  vTarget = math.min(vTarget, C.VMAX * D.skill * car.skill)
  -- gentle rubber band so the race stays together
  if player then
    local gap = car.progress - player.progress
    if gap > 120 then vTarget = vTarget * 0.93 elseif gap < -150 then vTarget = vTarget * (diff == "hard" and 1.08 or 1.04) end
  end
  -- racing line: inside of the coming bend, plus the driver's own lane
  local hw = tr.w / 2 - 1.6
  local want = clamp(kSum * 60, -1, 1) * hw * 0.7 + car.laneBias
  -- avoid the car ahead
  for _, o in ipairs(cars) do
    if o ~= car then
      local ds = (o.progress - car.progress)
      if ds > 0 and ds < 14 and math.abs(o.lat - want) < 2.4 then
        want = (o.lat > 0) and o.lat - 3.2 or o.lat + 3.2
        if ds < 7 and math.abs(o.lat - car.lat) < 2 then vTarget = math.min(vTarget, o.speed * 0.98 + 2) end
      end
    end
  end
  want = clamp(want, -hw, hw)
  local ahead = math.max(10, spd * 0.55)
  local px, _, pz = Track.at(tr, car.s + ahead, want)
  local dx, dz = px - car.x, pz - car.z
  local desired = math.atan(-dx, -dz)
  local d = (desired - car.yaw + math.pi) % (2 * math.pi) - math.pi
  inp.steer = clamp(-d * 2.6, -1, 1)
  if car.speed < vTarget - 1 then inp.gas, inp.brake = 1, 0
  elseif car.speed > vTarget + 3 then inp.gas, inp.brake = 0, clamp((car.speed - vTarget) / 10, 0.2, 1)
  else inp.gas, inp.brake = 0.4, 0 end
  inp.drift = false
  if showoff then
    -- autopilot for demos and screenshots: drift through the bends, nitro on the straights
    inp.drift = maxK > 0.010 and car.speed > 22
    if inp.drift then inp.gas, inp.brake = 1, 0 end
  end
  -- nitro on straights
  inp.nitro = car.nitro > 0.3 and maxK < 0.006 and car.speed > 30 and ((t * 0.37 + car.laneBias) % 1) < D.nitro
  if not inp.nitro and car.nitro < 1 then car.nitro = math.min(1, car.nitro + dt * 0.035) end
end

return C
