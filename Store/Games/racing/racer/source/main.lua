-- Racer: 3-lap 3D circuit race with hills, kerbs, trackside scenery, AI rivals, touch pedals and tilt steering.
local app = {}
local Builder = require("builder")

local floor, min, max, abs, sqrt, sin, cos, pi, atan, exp = math.floor, math.min, math.max, math.abs, math.sqrt, math.sin, math.cos, math.pi, math.atan, math.exp

-- track layout ------------------------------------------------------------------
local W, KERB, GRASS = 7, 1.2, 22          -- road half width, kerb width, grass width
local LIMIT = W + KERB + GRASS - 1.6       -- barrier distance from the centre line
local CHUNK = 10
local AHEAD, BEHIND = 72, 4
local LAPS = 3
local MAXV = 62
local SKY_TOP, SKY_BOT = {58, 112, 188}, {176, 204, 228}
local FOG = {190, 208, 220}
local CTRL = {
  {0, 0, 0}, {0, 0, -150}, {10, 6, -300}, {60, 10, -380}, {150, 10, -400}, {230, 6, -360}, {260, 0, -280},
  {230, -4, -200}, {270, -2, -120}, {250, 4, -40}, {290, 12, 40}, {300, 14, 140}, {240, 8, 220}, {140, 2, 230},
  {60, 0, 190}, {20, 0, 110},
}

local N, SEG, LEN = 0, 5, 0
local TX, TY, TZ, DX, DZ, RX, RZ, VT = {}, {}, {}, {}, {}, {}, {}, {}
local chunks = {}
local objects = {}       -- objects[i] = list of {mesh, x, y, z, yaw, top, r}
local treeMeshes = {}
local signMeshes = {}
local gantry
local carMeshes = {}
local mountains = {}
local mapPts, mapScale, mapOx, mapOz = {}, 1, 0, 0

-- game state ----------------------------------------------------------------------
local state = "menu"     -- menu | countdown | race | paused | finished
local pausedFrom = "race"
local car = {}
local ais = {}
local aiCount = 3
local raceTime, countdown = 0, 0
local lapStart, lastLap, bestLap, bestRace = 0, nil, nil, nil
local lapTimes = {}
local finishPos, finishTime = 0, 0
local newBestLap, newBestRace = false, false
local camMode = 1
local camYaw, camX, camY, camZ = 0, 0, 5, 10
local gyroOn, gyroInv, engineOn = false, false, true
local roll0 = 0
local tiltSmooth = 0
local engineT = 0
local held = {}
local touchGas, touchBrake, touchSteer = false, false, 0
local menuT = 0
local bumpT = 0
local messages = {}

local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function c3(r, g, b) return {clamp(floor(r + 0.5), 0, 254), clamp(floor(g + 0.5), 0, 254), clamp(floor(b + 0.5), 0, 254)} end
local function wrapAngle(a) while a > pi do a = a - 2 * pi end while a < -pi do a = a + 2 * pi end return a end
local function yawOf(dx, dz) return atan(-dx, -dz) end

-- spline + resampling ----------------------------------------------------------------
local function buildTrack()
  local n = #CTRL
  local dense = {}
  for k = 1, n do
    local p0, p1, p2, p3 = CTRL[(k - 2) % n + 1], CTRL[k], CTRL[k % n + 1], CTRL[(k + 1) % n + 1]
    for s = 0, 39 do
      local t = s / 40
      local t2, t3 = t * t, t * t * t
      local p = {}
      for c = 1, 3 do
        p[c] = 0.5 * (2 * p1[c] + (-p0[c] + p2[c]) * t + (2 * p0[c] - 5 * p1[c] + 4 * p2[c] - p3[c]) * t2 + (-p0[c] + 3 * p1[c] - 3 * p2[c] + p3[c]) * t3)
      end
      dense[#dense + 1] = p
    end
  end
  local cum = {0}
  for i = 2, #dense + 1 do
    local a, b = dense[i - 1], dense[(i - 1) % #dense + 1]
    local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
    cum[i] = cum[i - 1] + sqrt(dx * dx + dy * dy + dz * dz)
  end
  local total = cum[#dense + 1]
  N = floor(total / 5)
  SEG = total / N
  LEN = total
  local j = 1
  for i = 0, N - 1 do
    local s = i * SEG
    while cum[j + 1] < s do j = j + 1 end
    local a, b = dense[j], dense[j % #dense + 1]
    local f = (s - cum[j]) / max(1e-6, cum[j + 1] - cum[j])
    TX[i] = a[1] + (b[1] - a[1]) * f
    TY[i] = a[2] + (b[2] - a[2]) * f
    TZ[i] = a[3] + (b[3] - a[3]) * f
  end
  for i = 0, N - 1 do
    local p, q = (i - 1) % N, (i + 1) % N
    local dx, dz = TX[q] - TX[p], TZ[q] - TZ[p]
    local l = sqrt(dx * dx + dz * dz)
    DX[i], DZ[i] = dx / l, dz / l
    RX[i], RZ[i] = -DZ[i], DX[i]
  end
  for i = 0, N - 1 do
    local p, q = (i - 1) % N, (i + 1) % N
    local da = abs(wrapAngle(atan(DZ[q], DX[q]) - atan(DZ[p], DX[p])))
    local kappa = da / (2 * SEG)
    VT[i] = min(70, sqrt(26 / max(kappa, 1e-5)))
  end
  -- smooth the AI target speeds backwards so they brake before corners
  for _ = 1, 2 do
    for i = N - 1, 0, -1 do
      local nx = VT[(i + 1) % N]
      local lim = sqrt(nx * nx + 2 * 20 * SEG)
      if VT[i] > lim then VT[i] = lim end
    end
  end
end

local function trackPos(s, lat)
  s = s % LEN
  local fi = s / SEG
  local i = floor(fi) % N
  local u = fi - floor(fi)
  local j = (i + 1) % N
  local cx, cy, cz = TX[i] + (TX[j] - TX[i]) * u, TY[i] + (TY[j] - TY[i]) * u, TZ[i] + (TZ[j] - TZ[i]) * u
  local dx, dz = DX[i] + (DX[j] - DX[i]) * u, DZ[i] + (DZ[j] - DZ[i]) * u
  local l = sqrt(dx * dx + dz * dz)
  dx, dz = dx / l, dz / l
  return cx - dz * lat, cy, cz + dx * lat, dx, dz, i, (TY[j] - TY[i]) / SEG
end

local function locate(x, z, guess)
  local best, bd = guess, 1e18
  for k = -6, 10 do
    local i = (guess + k) % N
    local dx, dz = x - TX[i], z - TZ[i]
    local d = dx * dx + dz * dz
    if d < bd then bd, best = d, i end
  end
  local i = best
  local dx, dz = x - TX[i], z - TZ[i]
  local u = (dx * DX[i] + dz * DZ[i]) / SEG
  if u < 0 then
    i = (i - 1) % N
    dx, dz = x - TX[i], z - TZ[i]
    u = (dx * DX[i] + dz * DZ[i]) / SEG
  end
  u = clamp(u, 0, 0.999)
  local j = (i + 1) % N
  return i, u, dx * RX[i] + dz * RZ[i], TY[i] + (TY[j] - TY[i]) * u, (TY[j] - TY[i]) / SEG
end

-- meshes ------------------------------------------------------------------------------
local OFF = {-(W + KERB + GRASS), -(W + KERB), -W, -0.18, 0.18, W, W + KERB, W + KERB + GRASS}

local function buildChunks()
  chunks = {}
  local grass1, grass2 = {84, 146, 64}, {74, 132, 56}
  local road1, road2 = {92, 95, 102}, {86, 89, 96}
  local white, red = {236, 236, 232}, {204, 42, 40}
  local barA, barB = {40, 90, 200}, {236, 236, 236}
  for c = 0, (N - 1) // CHUNK do
    local b = Builder.new()
    for i = c * CHUNK, min(N - 1, c * CHUNK + CHUNK - 1) do
      local j = (i + 1) % N
      local road = (floor(i / 2) % 2 == 0) and road1 or road2
      local cols = {
        (floor(i / 3) % 2 == 0) and grass1 or grass2,
        (i % 2 == 0) and red or white,
        road,
        (floor(i / 3) % 2 == 0) and white or road,
        road,
        (i % 2 == 0) and red or white,
        (floor(i / 3) % 2 == 0) and grass1 or grass2,
      }
      if i == 0 then cols[3], cols[4], cols[5] = white, white, white end
      if i == 1 then cols[3], cols[4], cols[5] = {40, 40, 44}, {40, 40, 44}, {40, 40, 44} end
      for s = 1, 7 do
        local o0, o1 = OFF[s], OFF[s + 1]
        local a = {TX[i] + RX[i] * o0, TY[i], TZ[i] + RZ[i] * o0}
        local bb = {TX[i] + RX[i] * o1, TY[i], TZ[i] + RZ[i] * o1}
        local cc = {TX[j] + RX[j] * o1, TY[j], TZ[j] + RZ[j] * o1}
        local d = {TX[j] + RX[j] * o0, TY[j], TZ[j] + RZ[j] * o0}
        b:quad(a, bb, cc, d, cols[s], (a[1] + cc[1]) / 2, (a[2] + cc[2]) / 2 - 50, (a[3] + cc[3]) / 2)
      end
      -- barriers at both edges, facing the track
      local bc = (floor(i / 2) % 2 == 0) and barA or barB
      for side = -1, 1, 2 do
        local o = side * (W + KERB + GRASS)
        local p0 = {TX[i] + RX[i] * o, TY[i], TZ[i] + RZ[i] * o}
        local p1 = {TX[j] + RX[j] * o, TY[j], TZ[j] + RZ[j] * o}
        local q0 = {p0[1], p0[2] + 1.1, p0[3]}
        local q1 = {p1[1], p1[2] + 1.1, p1[3]}
        -- winding centre outside the track so the face points inwards
        local mx, mz = (p0[1] + p1[1]) / 2 + RX[i] * side * 3, (p0[3] + p1[3]) / 2 + RZ[i] * side * 3
        b:quad(p0, p1, q1, q0, bc, mx, (p0[2] + q1[2]) / 2, mz)
      end
    end
    chunks[c + 1] = {first = c * CHUNK, last = min(N - 1, c * CHUNK + CHUNK - 1), mesh = b:mesh(true)}
  end
end

local function makeCar(body, accent)
  local b = Builder.new()
  local dark, glass, tyre = c3(body[1] * 0.55, body[2] * 0.55, body[3] * 0.55), {40, 52, 70}, {26, 26, 28}
  b:box(0, 0.55, 0.1, 1.9, 0.5, 4.0, body)                         -- main body
  b:box(0, 0.42, -1.85, 1.8, 0.3, 0.6, body)                        -- nose
  b:box(0, 1.0, 0.35, 1.5, 0.45, 1.9, glass, body)                  -- cabin
  b:box(0, 1.25, 0.35, 1.45, 0.06, 1.7, body)                       -- roof
  b:box(0, 1.05, 1.95, 1.9, 0.08, 0.45, accent)                     -- spoiler wing
  b:box(-0.7, 0.85, 1.95, 0.1, 0.4, 0.3, dark)
  b:box(0.7, 0.85, 1.95, 0.1, 0.4, 0.3, dark)
  b:box(0, 0.82, -0.6, 0.5, 0.04, 1.6, accent)                      -- stripe on the bonnet
  b:box(-0.62, 0.6, -2.12, 0.42, 0.14, 0.06, {255, 244, 200})       -- headlights
  b:box(0.62, 0.6, -2.12, 0.42, 0.14, 0.06, {255, 244, 200})
  b:box(-0.62, 0.66, 2.11, 0.42, 0.14, 0.06, {220, 30, 30})         -- tail lights
  b:box(0.62, 0.66, 2.11, 0.42, 0.14, 0.06, {220, 30, 30})
  for _, w in ipairs({{-0.98, -1.3}, {0.98, -1.3}, {-0.98, 1.35}, {0.98, 1.35}}) do
    b:prism("x", w[1], 0.38, w[2], 0.38, 0.32, 8, tyre, {120, 120, 126})
  end
  return b:mesh(true)
end

local function rngFrom(seed)
  local s = seed
  return function()
    s = (s * 1103515245 + 12345) % 2147483648
    return s / 2147483648
  end
end

local function buildScenery()
  local rnd = rngFrom(4242)
  -- trees
  local b = Builder.new()
  b:prism("y", 0, 1.0, 0, 0.32, 2.0, 5, {110, 78, 50})
  b:prism("y", 0, 3.4, 0, 2.3, 3.4, 7, {38, 110, 58}, nil, 0)
  b:prism("y", 0, 5.2, 0, 1.6, 2.8, 7, {48, 128, 66}, nil, 0)
  treeMeshes[1] = {mesh = b:mesh(true), top = 6.6, r = 0.8}
  b = Builder.new()
  b:prism("y", 0, 1.2, 0, 0.35, 2.4, 5, {104, 74, 48})
  b:sphere(0, 3.6, 0, 2.1, 7, 5, {70, 140, 60}, 0.12, rnd)
  treeMeshes[2] = {mesh = b:mesh(true), top = 5.7, r = 0.8}
  b = Builder.new()
  b:sphere(0, 0.7, 0, 1.3, 6, 4, {110, 112, 108}, 0.22, rnd, 0.6)
  treeMeshes[3] = {mesh = b:mesh(true), top = 1.6, r = 1.2}
  -- billboards (local x along the track's right vector)
  local signCols = {{{230, 60, 50}, {250, 250, 250}}, {{40, 110, 220}, {255, 210, 40}}, {{30, 160, 90}, {250, 250, 250}}}
  for k, sc in ipairs(signCols) do
    b = Builder.new()
    b:box(-3.2, 1.6, 0, 0.3, 3.2, 0.3, {80, 80, 86})
    b:box(3.2, 1.6, 0, 0.3, 3.2, 0.3, {80, 80, 86})
    b:box(0, 3.6, 0, 8, 2.4, 0.3, sc[1], sc[2], {sc[1], sc[1], sc[2], sc[1], sc[1], sc[2]})
    b:box(0, 3.6, -0.17, 6.4, 0.7, 0.05, sc[2])
    b:box(0, 3.6, 0.17, 6.4, 0.7, 0.05, sc[2])
    signMeshes[k] = {mesh = b:mesh(true), top = 4.8, r = 0}
  end
  -- start gantry with a chequered banner
  b = Builder.new()
  local span = W + KERB + 0.8
  b:box(-span, 3.8, 0, 0.6, 7.6, 0.6, {200, 200, 205})
  b:box(span, 3.8, 0, 0.6, 7.6, 0.6, {200, 200, 205})
  local cells = 16
  for k = 0, cells - 1 do
    for r = 0, 1 do
      local cw = span * 2 / cells
      local col = ((k + r) % 2 == 0) and {24, 24, 26} or {240, 240, 240}
      b:box(-span + cw * (k + 0.5), 7.0 + r * 0.6, 0, cw, 0.6, 0.4, col)
    end
  end
  gantry = {mesh = b:mesh(true), top = 8}
  -- place objects
  objects = {}
  for i = 0, N - 1 do
    objects[i] = {}
    for side = -1, 1, 2 do
      if i > 3 and rnd() < 0.3 then
        local kind = rnd() < 0.55 and 1 or (rnd() < 0.75 and 2 or 3)
        local lat = side * (W + KERB + 3 + rnd() * (GRASS - 6))
        local u = rnd()
        local j = (i + 1) % N
        local x = TX[i] + (TX[j] - TX[i]) * u + RX[i] * lat
        local z = TZ[i] + (TZ[j] - TZ[i]) * u + RZ[i] * lat
        local y = TY[i] + (TY[j] - TY[i]) * u
        local tm = treeMeshes[kind]
        local sc = 0.8 + rnd() * 0.5
        local list = objects[i]
        list[#list + 1] = {mesh = tm.mesh, x = x, y = y, z = z, yaw = rnd() * 6.28, s = sc, top = tm.top * sc, r = tm.r * sc}
      end
    end
    if i % 37 == 18 then
      local side = (i // 37) % 2 == 0 and 1 or -1
      local lat = side * (W + KERB + 4)
      local sm = signMeshes[(i // 37) % #signMeshes + 1]
      local list = objects[i]
      list[#list + 1] = {mesh = sm.mesh, x = TX[i] + RX[i] * lat, y = TY[i], z = TZ[i] + RZ[i] * lat,
        yaw = yawOf(DX[i], DZ[i]) + (side > 0 and 0.35 or -0.35), s = 1, top = sm.top, r = 0}
    end
  end
  -- distant mountains
  mountains = {}
  for k = 1, 26 do
    local far = k <= 13
    mountains[#mountains + 1] = {az = rnd() * 2 * pi, h = far and (90 + rnd() * 160) or (50 + rnd() * 90),
      w = 0.12 + rnd() * 0.2, col = far and {150, 172, 196} or {112, 136, 150}}
  end
  table.sort(mountains, function(a, b) return a.h > b.h end)
  -- minimap outline
  local mnx, mxx, mnz, mxz = 1e9, -1e9, 1e9, -1e9
  for i = 0, N - 1 do
    mnx, mxx = min(mnx, TX[i]), max(mxx, TX[i])
    mnz, mxz = min(mnz, TZ[i]), max(mxz, TZ[i])
  end
  mapScale = 130 / max(mxx - mnx, mxz - mnz)
  mapOx, mapOz = (mnx + mxx) / 2, (mnz + mxz) / 2
  mapPts = {}
  for i = 0, N - 1, 3 do
    mapPts[#mapPts + 1] = (TX[i] - mapOx) * mapScale
    mapPts[#mapPts + 1] = (TZ[i] - mapOz) * mapScale
  end
end

-- race setup ------------------------------------------------------------------------------
local AI_COLORS = {{{40, 96, 220}, {250, 250, 250}}, {{250, 196, 30}, {30, 30, 30}}, {{40, 170, 90}, {250, 250, 250}}}
local AI_NAMES = {"ai_1", "ai_2", "ai_3"}

local function placeCar(c, s, lat)
  local x, y, z, dx, dz, i = trackPos(s, lat)
  c.x, c.y, c.z = x, y, z
  c.yaw = yawOf(dx, dz)
  c.idx = i
end

local function readTilt()
  local ax, ay, az = input.motion()
  return atan(ax, sqrt(ay * ay + az * az))
end

local function newRace()
  car = {vF = 0, vR = 0, steer = 0, lap = 0, cp1 = true, cp2 = true, noRecord = true, pitch = 0, lat = 0, u = 0, off = false}
  placeCar(car, LEN - 10, 3.5)
  ais = {}
  local grid = {{LEN - 10, -3.5}, {LEN - 22, 3.5}, {LEN - 22, -3.5}}
  for k = 1, aiCount do
    local a = {s = grid[k][1] - LEN, lat = grid[k][2], targetLat = grid[k][2], v = 0, vmax = 52.5 + k * 1.8,
      mesh = carMeshes[k + 1], name = AI_NAMES[k], finished = false, lane = grid[k][2], wobble = math.random() * 6}
    ais[k] = a
  end
  raceTime, countdown = 0, 3.6
  lapTimes, lastLap = {}, nil
  finishPos, finishTime = 0, 0
  newBestLap, newBestRace = false, false
  camYaw = car.yaw
  state = "countdown"
  roll0 = readTilt()
  messages = {}
end

local function message(text, col)
  messages[#messages + 1] = {text = text, t = 0, col = col or {255, 255, 255}}
end

local function fmtTime(t)
  if not t then return "--:--.--" end
  local m = floor(t / 60)
  return string.format("%d:%05.2f", m, t - m * 60)
end

local function playerProgress()
  return (car.lap - 1) * LEN + (car.idx + car.u) * SEG
end

local function racePosition()
  local p = playerProgress()
  local pos = 1
  for _, a in ipairs(ais) do if a.s > p then pos = pos + 1 end end
  return pos
end

local function finishRace()
  state = "finished"
  finishTime = raceTime
  finishPos = racePosition()
  if not bestRace or finishTime < bestRace then
    bestRace = finishTime
    store.set("bestRace", bestRace)
    newBestRace = true
  end
  local notes = finishPos == 1 and {523.25, 659.25, 783.99, 1046.5, 1318.5} or {440, 554.37, 659.25}
  for i, f in ipairs(notes) do timer.after((i - 1) * 0.12, function() audio.tone(f, 0.25, 0.3, "triangle") end) end
  sys.vibrate(0.5, 150)
end

local function lapComplete()
  if car.noRecord then
    car.noRecord = false
  else
    lastLap = raceTime - lapStart
    lapTimes[#lapTimes + 1] = lastLap
    if not bestLap or lastLap < bestLap then
      bestLap = lastLap
      store.set("bestLap", bestLap)
      newBestLap = true
      message(TR("best_lap_msg", fmtTime(lastLap)), {255, 220, 90})
    else
      message(TR("lap_time_msg", fmtTime(lastLap)))
    end
  end
  car.lap = car.lap + 1
  lapStart = raceTime
  car.cp1, car.cp2 = false, false
  if car.lap > LAPS then
    finishRace()
  elseif car.lap == LAPS and #lapTimes > 0 then
    message(TR("final_lap"), {255, 140, 90})
    audio.tone(880, 0.12, 0.25, "square")
    timer.after(0.14, function() audio.tone(1175, 0.18, 0.25, "square") end)
  elseif car.lap > 1 then
    audio.tone(784, 0.15, 0.25, "triangle")
  end
end

-- input --------------------------------------------------------------------------------
local function gatherInput()
  local throttle, brake, steer = 0, 0, 0
  if input.down("zr") or input.down("a") or held.up or held.w then throttle = 1 end
  if input.down("zl") or input.down("b") or held.down or held.s then brake = 1 end
  local lx = input.stick("left")
  if abs(lx) > 0.12 then steer = lx end
  if input.down("left") or held.left or held.a then steer = -1 end
  if input.down("right") or held.right or held.d then steer = 1 end
  if touchGas then throttle = 1 end
  if touchBrake then brake = 1 end
  if abs(touchSteer) > abs(steer) then steer = touchSteer end
  if gyroOn then
    local r = readTilt()
    tiltSmooth = tiltSmooth + (r - roll0 - tiltSmooth) * 0.35
    local g = clamp(-tiltSmooth * 2.6 * (gyroInv and -1 or 1), -1, 1)
    if abs(g) > abs(steer) then steer = g end
  end
  return throttle, brake, steer
end

-- physics ------------------------------------------------------------------------------
local function updateCar(dt, throttle, brake, steerIn)
  local c = car
  c.steer = c.steer + (steerIn - c.steer) * min(1, dt * 8)
  local off = abs(c.lat) > W + KERB + 0.2
  c.off = off
  local maxv = off and 24 or MAXV
  local vF, vR = c.vF, c.vR
  if throttle > 0 then
    if vF < -0.5 then vF = vF + 30 * dt
    else vF = vF + throttle * 26 * max(0.08, 1 - (max(vF, 0) / (MAXV + 4)) ^ 2) * dt end
  end
  if brake > 0 then
    if vF > 0.5 then vF = vF - 40 * brake * dt else vF = max(-9, vF - 12 * brake * dt) end
  end
  if throttle == 0 and brake == 0 then
    local roll = (off and 6 or 2.2) * dt
    if abs(vF) < roll then vF = 0 else vF = vF - roll * (vF > 0 and 1 or -1) end
  end
  vF = vF - vF * 0.1 * dt
  if vF > maxv then vF = vF - (vF - maxv) * 2.2 * dt end
  -- gravity along the slope (slope is per metre along the track direction)
  vF = vF - (c.slope or 0) * (c.align or 1) * 9.8 * 0.7 * dt
  local sf = clamp(abs(vF) / 9, 0, 1) * (1 - 0.42 * clamp(abs(vF) / MAXV, 0, 1))
  local dir = vF >= 0 and 1 or -1
  c.yaw = c.yaw - c.steer * 1.85 * sf * dir * dt
  vR = vR * exp(-(off and 3.5 or 8) * dt) - c.steer * vF * 0.05 * dt
  local fx, fz = -sin(c.yaw), -cos(c.yaw)
  local rx, rz = cos(c.yaw), -sin(c.yaw)
  local vx, vz = fx * vF + rx * vR, fz * vF + rz * vR
  c.x = c.x + vx * dt
  c.z = c.z + vz * dt
  c.vF, c.vR = vF, vR
  -- where are we on the track?
  local prev = c.idx
  local i, u, lat, y, slope = locate(c.x, c.z, c.idx)
  c.idx, c.u, c.lat, c.slope = i, u, lat, slope
  c.y = c.y + (y - c.y) * min(1, dt * 20)
  c.align = -sin(c.yaw) * DX[i] - cos(c.yaw) * DZ[i]
  c.pitch = c.pitch + (atan(slope * c.align) - c.pitch) * min(1, dt * 8)
  -- barrier
  if abs(lat) > LIMIT then
    local push = lat - (lat > 0 and LIMIT or -LIMIT)
    c.x = c.x - RX[i] * push
    c.z = c.z - RZ[i] * push
    c.vF = c.vF * 0.55
    c.vR = 0
    -- turn the car slightly away from the barrier
    local ty = yawOf(DX[i], DZ[i])
    c.yaw = c.yaw + wrapAngle(ty - c.yaw) * 0.25
    if bumpT <= 0 then
      audio.tone(70, 0.15, 0.4, "noise")
      sys.vibrate(0.7, 80)
      bumpT = 0.3
    end
  end
  -- trees and rocks
  for k = -1, 1 do
    local list = objects[(i + k) % N]
    for _, o in ipairs(list) do
      if o.r > 0 then
        local dx, dz = c.x - o.x, c.z - o.z
        local d2 = dx * dx + dz * dz
        local rr = o.r + 0.9
        if d2 < rr * rr then
          local d = sqrt(d2)
          if d < 1e-4 then dx, dz, d = 1, 0, 1 end
          c.x = o.x + dx / d * rr
          c.z = o.z + dz / d * rr
          c.vF = c.vF * 0.3
          if bumpT <= 0 then audio.tone(90, 0.2, 0.45, "noise"); sys.vibrate(0.9, 120); bumpT = 0.4 end
        end
      end
    end
  end
  -- laps and checkpoints
  if prev > N - 15 and i < 15 then
    if c.cp1 and c.cp2 then lapComplete() end
  elseif prev < 15 and i > N - 15 then
    c.lap = c.lap - 1
    c.cp1, c.cp2 = true, true
    c.noRecord = true
  end
  if i > N * 0.3 and i < N * 0.5 then c.cp1 = true end
  if c.cp1 and i > N * 0.65 and i < N * 0.85 then c.cp2 = true end
  if off and abs(vF) > 8 and math.random() < dt * 6 then sys.vibrate(0.25, 30) end
end

local function updateAI(dt, racing)
  local pp = playerProgress()
  for k, a in ipairs(ais) do
    local s = a.s % LEN
    local i = floor(s / SEG) % N
    local vt = 1e9
    for q = 0, 12 do vt = min(vt, VT[(i + q) % N]) end
    vt = min(a.vmax, vt)
    -- gentle rubber band
    local gap = a.s - pp
    if gap > 120 then vt = vt * 0.9 elseif gap < -120 then vt = vt * 1.06 end
    if not racing then vt = 0 end
    if a.finished then vt = min(vt, 20) end
    if a.v < vt then a.v = min(vt, a.v + 15 * dt) else a.v = max(vt, a.v - 28 * dt) end
    a.s = a.s + a.v * dt
    -- lane choice: dodge the player and the other cars
    local target = a.lane + sin(raceTime * 0.3 + a.wobble) * 1.2
    local dp = pp - a.s
    if dp > 0 and dp < 14 and abs(car.lat - a.lat) < 3.2 then target = car.lat > a.lat and car.lat - 4 or car.lat + 4 end
    for k2, b in ipairs(ais) do
      if k2 ~= k then
        local d = b.s - a.s
        if d > 0 and d < 12 and abs(b.lat - a.lat) < 3 then target = b.lat > 0 and b.lat - 4 or b.lat + 4 end
      end
    end
    target = clamp(target, -W + 1.4, W - 1.4)
    a.targetLat = target
    a.lat = a.lat + (target - a.lat) * min(1, dt * 1.6)
    if not a.finished and a.s >= LAPS * LEN then a.finished = true; a.finishTime = raceTime end
    local x, y, z, dx, dz, idx, slope = trackPos(a.s, a.lat)
    a.x, a.y, a.z, a.idx = x, y, z, idx
    a.yaw = yawOf(dx, dz) - (target - a.lat) * 0.04
    a.pitch = atan(slope)
    -- bump with the player
    local ddx, ddz = car.x - x, car.z - z
    local d2 = ddx * ddx + ddz * ddz
    if d2 < 3.4 * 3.4 and state == "race" then
      local d = sqrt(d2)
      if d < 1e-4 then ddx, ddz, d = 1, 0, 1 end
      local push = 3.4 - d
      car.x = car.x + ddx / d * push
      car.z = car.z + ddz / d * push
      if dp < 0 then car.vF = min(car.vF, a.v * 0.92) else a.v = a.v * 0.9 end
      if bumpT <= 0 then audio.tone(110, 0.12, 0.35, "noise"); sys.vibrate(0.5, 60); bumpT = 0.3 end
    end
  end
end

-- app ---------------------------------------------------------------------------------
function app.load(arg)
  buildTrack()
  buildChunks()
  buildScenery()
  carMeshes[1] = makeCar({214, 36, 40}, {250, 250, 250})
  for k = 1, 3 do carMeshes[k + 1] = makeCar(AI_COLORS[k][1], AI_COLORS[k][2]) end
  aiCount = store.get("ai", 3)
  gyroOn = store.get("gyro", false)
  gyroInv = store.get("gyroInv", false)
  engineOn = store.get("engine", true)
  camMode = store.get("cam", 1)
  bestLap = store.get("bestLap", nil)
  bestRace = store.get("bestRace", nil)
  newRace()
  state = "menu"
end

function app.update(dt)
  dt = min(dt, 0.05)
  bumpT = bumpT - dt
  menuT = menuT + dt
  for i = #messages, 1, -1 do
    messages[i].t = messages[i].t + dt
    if messages[i].t > 2.2 then table.remove(messages, i) end
  end
  if state == "paused" then return end
  if state == "menu" then
    updateAI(dt, true)
    return
  end
  local throttle, brake, steer = gatherInput()
  if state == "countdown" then
    local before = countdown
    countdown = countdown - dt
    if before >= 3.5 and countdown < 3.5 then audio.tone(440, 0.18, 0.35, "square") end
    local b0, b1 = math.ceil(before - 0.6), math.ceil(countdown - 0.6)
    if b1 < b0 and b1 >= 1 then audio.tone(440, 0.18, 0.35, "square") end
    if countdown <= 0.6 and before > 0.6 then
      audio.tone(880, 0.4, 0.35, "square")
      state = "race"
      lapStart = 0
    end
    car.vF, car.vR = 0, 0
    updateAI(dt, false)
  elseif state == "race" then
    raceTime = raceTime + dt
    updateCar(dt, throttle, brake, steer)
    updateAI(dt, true)
  elseif state == "finished" then
    if car.vF > 0.5 then updateCar(dt, 0, 0.35, 0) else car.vF = 0; updateCar(dt, 0, 0, 0) end
    updateAI(dt, true)
  end
  if engineOn and (state == "race" or state == "countdown") then
    engineT = engineT - dt
    if engineT <= 0 then
      engineT = 0.1
      audio.tone(52 + abs(car.vF) * 2.3 + throttle * 14, 0.12, 0.035 + throttle * 0.025, "saw")
    end
  end
end

-- rendering ------------------------------------------------------------------------------
local horizonMax = {}

local function cameraSetup(dt)
  local c = car
  if state == "menu" then
    local a = menuT * 0.12
    local x, y, z = trackPos(LEN - 30, 0)
    camX, camY, camZ = x + sin(a) * 26, y + 9, z + cos(a) * 26
    return camX, camY, camZ, x, y + 1, z - 20
  end
  local d = wrapAngle(c.yaw - camYaw)
  camYaw = camYaw + d * min(1, dt * 5)
  local fx, fz = -sin(camYaw), -cos(camYaw)
  if state == "finished" then
    local a = menuT * 0.3
    camX, camY, camZ = c.x + sin(a) * 10, c.y + 4, c.z + cos(a) * 10
    return camX, camY, camZ, c.x, c.y + 0.8, c.z
  end
  local back, up = 8.5, 3.3
  if camMode == 2 then back, up = 14, 5.6 end
  if camMode == 3 then
    local cx, cz = -sin(c.yaw), -cos(c.yaw)
    camX, camY, camZ = c.x + cx * 0.4, c.y + 1.3, c.z + cz * 0.4
    return camX, camY, camZ, c.x + cx * 12, c.y + 1.0 + c.pitch * 12, c.z + cz * 12
  end
  camX, camZ = c.x - fx * back, c.z - fz * back
  local _, _, _, gy = locate(camX, camZ, (c.idx - 2) % N)
  camY = max(c.y + up, gy + 1.2)
  return camX, camY, camZ, c.x + fx * 5, c.y + 1.2, c.z + fz * 5
end

local function drawCarAt(mesh, x, y, z, pitch, yaw, rollz)
  g3d.draw(mesh, x, y, z, pitch, yaw, rollz or 0)
end

local function drawHUD(w, h)
  local pos = racePosition()
  -- left panel: lap + times
  gfx.color(10, 14, 22, 165)
  gfx.rect(14, 14, 220, 86, 12)
  gfx.color("#FFFFFF")
  gfx.text(TR("lap_n", clamp(car.lap, 1, LAPS), LAPS), 28, 22, 20, "bold")
  gfx.text(fmtTime(raceTime), 28, 50, 18, "monobold")
  gfx.color(255, 255, 255, 170)
  gfx.text(TR("last_best", fmtTime(lastLap), fmtTime(bestLap)), 28, 76, 12, "sans")
  -- position
  if #ais > 0 then
    gfx.color(10, 14, 22, 165)
    gfx.rect(w / 2 - 70, 14, 140, 60, 12)
    gfx.color(255, 255, 255, 170)
    gfx.text(TR("position"), w / 2 - 70, 20, 12, "semibold", "center", 140)
    gfx.color(pos == 1 and {255, 214, 80} or {255, 255, 255})
    gfx.text(TR("pos_n", pos, #ais + 1), w / 2 - 70, 36, 26, "bold", "center", 140)
  end
  -- minimap
  local mx, my = w - 90, 92
  gfx.color(10, 14, 22, 150)
  gfx.rect(mx - 78, my - 78, 156, 156, 14)
  gfx.push(mx, my)
  gfx.color(255, 255, 255, 200)
  gfx.lines(mapPts, 3, true)
  for k, a in ipairs(ais) do
    if a.x then gfx.circle((a.x - mapOx) * mapScale, (a.z - mapOz) * mapScale, 4, AI_COLORS[k][1]) end
  end
  gfx.circle((TX[0] - mapOx) * mapScale, (TZ[0] - mapOz) * mapScale, 3, {40, 40, 40})
  gfx.circle((car.x - mapOx) * mapScale, (car.z - mapOz) * mapScale, 5.5, {255, 60, 50})
  gfx.pop()
  -- speedometer
  local kmh = floor(abs(car.vF) * 3.6 + 0.5)
  local sx, sy = w / 2, h - 30
  gfx.color(10, 14, 22, 150)
  gfx.circle(sx, sy, 62)
  gfx.color(255, 255, 255, 60)
  gfx.arc(sx, sy, 52, pi, 2 * pi, 6)
  local k = clamp(abs(car.vF) / MAXV, 0, 1)
  gfx.color(car.off and {255, 170, 60} or {90, 200, 255})
  if k > 0.005 then gfx.arc(sx, sy, 52, pi, pi + pi * k, 6) end
  gfx.color("#FFFFFF")
  gfx.text(tostring(kmh), sx - 50, sy - 36, 24, "bold", "center", 100)
  gfx.color(255, 255, 255, 160)
  gfx.text(TR("kmh"), sx - 50, sy - 10, 11, "semibold", "center", 100)
  -- messages
  for i, m in ipairs(messages) do
    local a = m.t < 1.8 and 1 or (2.2 - m.t) / 0.4
    gfx.alpha(clamp(a, 0, 1))
    gfx.color(0, 0, 0, 110)
    gfx.text(m.text, 1, h * 0.28 + (i - 1) * 30 + 1, 20, "bold", "center", w)
    gfx.color(m.col)
    gfx.text(m.text, 0, h * 0.28 + (i - 1) * 30, 20, "bold", "center", w)
    gfx.unalpha()
  end
end

local function drawPedals(w, h)
  local size = 104
  local gx, gy = w - size - 20, h - size - 20
  local bx, by = 20, h - size - 20
  local hb = ui.hit("brake", bx, by, size, size)
  local hg = ui.hit("gas", gx, gy, size, size)
  touchBrake = hb.held and (state == "race")
  touchGas = hg.held and (state == "race")
  touchSteer = 0
  if hg.held then touchSteer = clamp(hg.dx / 70, -1, 1) elseif hb.held then touchSteer = clamp(hb.dx / 70, -1, 1) end
  local function pedal(x, y, on, icon, col)
    gfx.color(col[1], col[2], col[3], on and 200 or 90)
    gfx.rect(x, y, size, size, 22)
    gfx.color(255, 255, 255, on and 255 or 170)
    gfx.rectLine(x, y, size, size, 22, 2)
    gfx.icon(icon, x + size / 2, y + size / 2, 44, "#FFFFFF")
  end
  pedal(bx, by, touchBrake, "south", {200, 50, 50})
  pedal(gx, gy, touchGas, "north", {40, 170, 90})
  if touchGas or touchBrake then
    gfx.color(255, 255, 255, 140)
    gfx.text(TR("slide_to_steer"), 0, h - size - 48, 12, "semibold", "center", w)
  end
end

local function panel(x, y, pw, ph)
  gfx.shadow(x, y, pw, ph, 16, 24, 6)
  gfx.color(12, 16, 28, 215)
  gfx.rect(x, y, pw, ph, 16)
end

local function drawMenu(w, h)
  local pw, ph = 470, 400
  local x, y = (w - pw) / 2, (h - ph) / 2
  panel(x, y, pw, ph)
  gfx.icon("sports_score", x + pw / 2, y + 34, 34, {255, 214, 80})
  gfx.color("#FFFFFF")
  gfx.text(TR("title"), x, y + 54, 30, "bold", "center", pw)
  gfx.color(255, 255, 255, 180)
  gfx.text(TR("subtitle", LAPS), x, y + 92, 14, "sans", "center", pw)
  local ry = y + 126
  gfx.color("#FFFFFF")
  gfx.text(TR("opponents"), x + 30, ry + 6, 14, "semibold")
  local na = ui.segmented("ai", {"0", "1", "2", "3"}, aiCount + 1, x + pw - 230, ry, 200, 30) - 1
  if na ~= aiCount then aiCount = na; store.set("ai", aiCount); newRace(); state = "menu" end
  ry = ry + 44
  gfx.color("#FFFFFF")
  gfx.text(TR("gyro_steer"), x + 30, ry + 6, 14, "semibold")
  local ng = ui.toggle("gyro", gyroOn, x + pw - 80, ry)
  if ng ~= gyroOn then gyroOn = ng; store.set("gyro", gyroOn); roll0 = readTilt() end
  ry = ry + 40
  gfx.color("#FFFFFF")
  gfx.text(TR("gyro_invert"), x + 30, ry + 6, 14, "semibold")
  local ni = ui.toggle("gyroinv", gyroInv, x + pw - 80, ry)
  if ni ~= gyroInv then gyroInv = ni; store.set("gyroInv", gyroInv) end
  ry = ry + 40
  gfx.color("#FFFFFF")
  gfx.text(TR("engine_sound"), x + 30, ry + 6, 14, "semibold")
  local ne = ui.toggle("engine", engineOn, x + pw - 80, ry)
  if ne ~= engineOn then engineOn = ne; store.set("engine", engineOn) end
  ry = ry + 46
  gfx.color(255, 214, 120)
  gfx.text(TR("records", fmtTime(bestLap), fmtTime(bestRace)), x, ry, 14, "semibold", "center", pw)
  if ui.button(TR("start_race"), x + pw / 2 - 110, y + ph - 60, 220, 42, "primary", "flag") then newRace() end
  gfx.color(255, 255, 255, 130)
  gfx.text(TR("controls"), 0, h - 26, 12, "sans", "center", w)
end

function app.draw(w, h)
  local dt = min(0.05, 1 / max(20, sys.fps()))
  local ex, ey, ez, tx, ty, tz = cameraSetup(dt)
  local fx, fz = tx - ex, tz - ez
  local fl = sqrt(fx * fx + fz * fz)
  fx, fz = fx / fl, fz / fl

  -- pass 1: sky, mountains, ground haze, road
  g3d.begin(0, 0, w, h, 62, 0.3, 420)
  g3d.camera(ex, ey, ez, tx, ty, tz)
  gfx.gradient(0, 0, w, h, SKY_TOP, SKY_BOT)
  local hx, hy = g3d.project(ex + fx * 3000, ey, ez + fz * 3000)
  local horizon = clamp(hy or h * 0.45, -10, h + 10)
  for _, m in ipairs(mountains) do
    local R = 3000
    local ca, sa = sin(m.az), cos(m.az)
    if ca * fx + sa * fz > 0.2 then
      local x1, y1 = g3d.project(ex + sin(m.az - m.w) * R, ey - 60, ez + cos(m.az - m.w) * R)
      local x2, y2 = g3d.project(ex + ca * R, ey + m.h * 3, ez + sa * R)
      local x3, y3 = g3d.project(ex + sin(m.az + m.w) * R, ey - 60, ez + cos(m.az + m.w) * R)
      if x1 and x2 and x3 then gfx.poly({x1, y1, x2, y2, x3, y3}, m.col) end
    end
  end
  gfx.color(FOG)
  gfx.rect(0, horizon, w, h - horizon + 2)
  g3d.light(0.4, 0.9, 0.35, 0.5)
  g3d.fog(FOG, 110, 360)
  local base = car.idx or 0
  if state == "menu" then base = N - 10 end
  local from, to = base - BEHIND, base + AHEAD
  for _, ch in ipairs(chunks) do
    -- chunk visible if its range intersects [from, to] modulo N
    local a = (ch.first - from) % N
    local b = (ch.last - from) % N
    if a <= to - from or b <= to - from or a > b then g3d.draw(ch.mesh) end
  end
  g3d.finish()

  -- horizon profile ahead for hill occlusion of objects
  local maxA = -1e9
  for j = 0, AHEAD do
    local i = (base + j) % N
    local dx, dz = TX[i] - ex, TZ[i] - ez
    local d = sqrt(dx * dx + dz * dz)
    horizonMax[j] = maxA
    if d > 4 then maxA = max(maxA, (TY[i] - ey) / d) end
  end
  local function visible(x, y, z, top, j)
    if j < 2 then return true end
    local dx, dz = x - ex, z - ez
    local d = sqrt(dx * dx + dz * dz)
    if d < 1 then return true end
    return (y + top - ey) / d >= (horizonMax[j] or -1e9) - 0.004
  end

  -- pass 2: scenery and cars
  g3d.begin(0, 0, w, h, 62, 0.3, 420)
  g3d.camera(ex, ey, ez, tx, ty, tz)
  g3d.light(0.4, 0.9, 0.35, 0.5)
  g3d.fog(FOG, 110, 360)
  for j = -BEHIND, AHEAD - 2 do
    local i = (base + j) % N
    for _, o in ipairs(objects[i]) do
      local dx, dz = o.x - ex, o.z - ez
      if dx * fx + dz * fz > -6 and visible(o.x, o.y, o.z, o.top, j) then
        g3d.draw(o.mesh, o.x, o.y, o.z, 0, o.yaw, 0, o.s)
      end
    end
    if i == 0 and visible(TX[0], TY[0], TZ[0], gantry.top, j) then
      g3d.draw(gantry.mesh, TX[0], TY[0], TZ[0], 0, yawOf(DX[0], DZ[0]), 0)
    end
  end
  for _, a in ipairs(ais) do
    if a.x then
      local j = (a.idx - base) % N
      if j > N / 2 then j = j - N end
      local dx, dz = a.x - ex, a.z - ez
      if j > -BEHIND - 4 and j < AHEAD and dx * fx + dz * fz > -4 and visible(a.x, a.y, a.z, 1.4, j) then
        drawCarAt(a.mesh, a.x, a.y, a.z, a.pitch or 0, a.yaw, 0)
      end
    end
  end
  if camMode ~= 3 or state == "menu" or state == "finished" then
    drawCarAt(carMeshes[1], car.x, car.y, car.z, car.pitch, car.yaw, -car.steer * clamp(car.vF / MAXV, 0, 1) * 0.05)
  end
  g3d.finish()

  if state == "menu" then
    touchGas, touchBrake, touchSteer = false, false, 0
    drawMenu(w, h)
    return
  end

  if state == "race" or state == "countdown" then drawPedals(w, h) else touchGas, touchBrake, touchSteer = false, false, 0 end
  drawHUD(w, h)

  if state == "countdown" then
    local n = math.ceil(countdown - 0.6)
    local cx, cy = w / 2, h * 0.32
    gfx.color(10, 14, 22, 190)
    gfx.rect(cx - 96, cy - 34, 192, 68, 34)
    for k = 1, 3 do
      local lit = n <= 3 - k + 1
      gfx.color(lit and {255, 60, 50} or {70, 30, 30})
      gfx.circle(cx - 64 + (k - 1) * 64, cy, 24)
    end
  elseif state == "race" and raceTime < 1.2 then
    gfx.alpha(1 - raceTime / 1.2)
    gfx.color(0, 0, 0, 120)
    gfx.text(TR("go"), 2, h * 0.26 + 2, 64, "bold", "center", w)
    gfx.color({80, 230, 120})
    gfx.text(TR("go"), 0, h * 0.26, 64, "bold", "center", w)
    gfx.unalpha()
  end

  if state == "race" or state == "countdown" then
    if ui.iconButton("pause", w - 56, 180, 40, 40, "#FFFFFF") then pausedFrom = state; state = "paused" end
    if ui.iconButton("videocam", w - 56, 228, 40, 40, "#FFFFFF") then camMode = camMode % 3 + 1; store.set("cam", camMode) end
  elseif state == "paused" then
    gfx.color(0, 0, 0, 120)
    gfx.rect(0, 0, w, h)
    local pw, ph = 340, 300
    local x, y = (w - pw) / 2, (h - ph) / 2
    panel(x, y, pw, ph)
    gfx.color("#FFFFFF")
    gfx.text(TR("paused"), x, y + 20, 26, "bold", "center", pw)
    if ui.button(TR("resume"), x + 40, y + 70, pw - 80, 38, "primary", "play_arrow") then state = pausedFrom end
    if ui.button(TR("restart"), x + 40, y + 116, pw - 80, 38, "default", "refresh") then newRace() end
    if ui.button(TR("main_menu"), x + 40, y + 162, pw - 80, 38, "default", "home") then newRace(); state = "menu" end
    gfx.color("#FFFFFF")
    gfx.text(TR("gyro_steer"), x + 40, y + 222, 14, "semibold")
    local ng = ui.toggle("gyro_p", gyroOn, x + pw - 96, y + 216)
    if ng ~= gyroOn then gyroOn = ng; store.set("gyro", gyroOn); roll0 = readTilt() end
    gfx.color(255, 255, 255, 140)
    gfx.text(TR("pause_hint"), x, y + ph - 30, 12, "sans", "center", pw)
  elseif state == "finished" then
    local pw, ph = 380, 310
    local x, y = (w - pw) / 2, (h - ph) / 2
    panel(x, y, pw, ph)
    gfx.icon(finishPos == 1 and "emoji_events" or "sports_score", x + pw / 2, y + 36, 38, finishPos == 1 and {255, 210, 80} or {255, 255, 255})
    gfx.color("#FFFFFF")
    gfx.text(#ais > 0 and TR("finished_pos", finishPos, #ais + 1) or TR("finished"), x, y + 62, 24, "bold", "center", pw)
    gfx.color(255, 255, 255, 220)
    gfx.text(TR("total_time", fmtTime(finishTime)), x, y + 100, 16, "semibold", "center", pw)
    for k, t in ipairs(lapTimes) do
      gfx.color(255, 255, 255, 170)
      gfx.text(TR("lap_line", k, fmtTime(t)), x, y + 126 + (k - 1) * 20, 13, "mono", "center", pw)
    end
    local ry = y + 132 + #lapTimes * 20
    if newBestRace or newBestLap then
      gfx.color(255, 214, 90)
      gfx.text(newBestRace and TR("new_record") or TR("new_best_lap"), x, ry, 15, "bold", "center", pw)
    end
    if ui.button(TR("race_again"), x + 24, y + ph - 58, (pw - 60) / 2, 38, "primary", "refresh") then newRace() end
    if ui.button(TR("main_menu"), x + 36 + (pw - 60) / 2, y + ph - 58, (pw - 60) / 2, 38, "default", "home") then newRace(); state = "menu" end
  end
end

local HOLD = {up = true, down = true, left = true, right = true, w = true, a = true, s = true, d = true}

local function togglePause()
  if state == "race" or state == "countdown" then pausedFrom = state; state = "paused"
  elseif state == "paused" then state = pausedFrom end
end

function app.event(e)
  if e.type == "keydown" then
    if HOLD[e.key] then held[e.key] = true end
    if e.key == "escape" or e.key == "p" then togglePause()
    elseif e.key == "c" then camMode = camMode % 3 + 1; store.set("cam", camMode)
    elseif e.key == "r" and state ~= "menu" then newRace()
    elseif e.key == "enter" or e.key == "space" then
      if state == "menu" or state == "finished" then newRace() elseif state == "paused" then state = pausedFrom end
    end
  elseif e.type == "keyup" then
    held[e.key] = nil
  elseif e.type == "paddown" then
    if e.pad == "plus" then
      if state == "menu" or state == "finished" then newRace() else togglePause() end
    elseif e.pad == "y" then camMode = camMode % 3 + 1; store.set("cam", camMode)
    elseif e.pad == "x" and state == "paused" then newRace()
    elseif e.pad == "minus" and (state == "paused" or state == "finished") then newRace(); state = "menu"
    elseif e.pad == "a" and (state == "menu" or state == "finished") then newRace()
    elseif e.pad == "a" and state == "paused" then state = pausedFrom
    end
  end
end

function app.menu()
  return {{title = TR("race"), items = {
    {label = TR("restart"), id = 1, shortcut = "R"},
    {label = TR("pause_resume"), id = 2, shortcut = "Esc"},
    {label = TR("camera_view"), id = 3, shortcut = "C"},
    "-",
    {label = TR("toggle_gyro"), id = 4},
    {label = TR("main_menu"), id = 5},
    {label = TR("reset_records"), id = 6},
  }}}
end

function app.onmenu(id)
  if id == 1 then newRace()
  elseif id == 2 then togglePause()
  elseif id == 3 then camMode = camMode % 3 + 1; store.set("cam", camMode)
  elseif id == 4 then gyroOn = not gyroOn; store.set("gyro", gyroOn); roll0 = readTilt()
  elseif id == 5 then newRace(); state = "menu"
  elseif id == 6 then bestLap, bestRace = nil, nil; store.set("bestLap", nil); store.set("bestRace", nil)
  end
end

return app
