-- Solar System: the Sun, eight planets and the Moon on their real orbital periods (stylised sizes and distances).
-- Positions start from today's date (mean longitudes at J2000 + circular orbits).
local app = {}

local floor, min, max, abs, sqrt, sin, cos, pi, atan, exp = math.floor, math.min, math.max, math.abs, math.sqrt, math.sin, math.cos, math.pi, math.atan, math.exp
local rad = pi / 180

local J2000 = 946728000 -- 2000-01-01 12:00 UTC

-- r: display radius, d: display orbit radius, P: orbital period (days), L0: mean longitude at J2000 (deg),
-- rot: sidereal rotation (hours, negative = retrograde), tilt: axial tilt (deg)
local BODIES = {
  {key = "sun", r = 2.4, d = 0, P = 0, L0 = 0, rot = 609.1, tilt = 7.25, seg = 28, rings = 16,
    diam = 1392700, typ = "type_star", temp = "5 500 °C", moons = "8"},
  {key = "mercury", r = 0.28, d = 4.6, P = 87.969, L0 = 252.25, rot = 1407.6, tilt = 0.03, seg = 16, rings = 12,
    diam = 4879, au = 0.387, typ = "type_rocky", temp = "−173 … 427 °C", moons = "0"},
  {key = "venus", r = 0.46, d = 6.4, P = 224.701, L0 = 181.98, rot = -5832.5, tilt = 177.4, seg = 18, rings = 12,
    diam = 12104, au = 0.723, typ = "type_rocky", temp = "465 °C", moons = "0"},
  {key = "earth", r = 0.5, d = 8.6, P = 365.256, L0 = 100.46, rot = 23.934, tilt = 23.44, seg = 30, rings = 18,
    diam = 12742, au = 1.0, typ = "type_rocky", temp = "−89 … 57 °C", moons = "1"},
  {key = "mars", r = 0.36, d = 11.0, P = 686.98, L0 = 355.43, rot = 24.623, tilt = 25.19, seg = 18, rings = 12,
    diam = 6779, au = 1.524, typ = "type_rocky", temp = "−140 … 20 °C", moons = "2"},
  {key = "jupiter", r = 1.25, d = 15.5, P = 4332.59, L0 = 34.40, rot = 9.925, tilt = 3.13, seg = 26, rings = 16,
    diam = 139820, au = 5.203, typ = "type_gas", temp = "−110 °C", moons = "95+"},
  {key = "saturn", r = 1.05, d = 20.5, P = 10759.22, L0 = 49.94, rot = 10.656, tilt = 26.73, seg = 26, rings = 16,
    diam = 116460, au = 9.537, typ = "type_gas", temp = "−140 °C", moons = "270+"},
  {key = "uranus", r = 0.75, d = 25.0, P = 30688.5, L0 = 313.23, rot = -17.24, tilt = 97.77, seg = 20, rings = 14,
    diam = 50724, au = 19.19, typ = "type_ice", temp = "−195 °C", moons = "28+"},
  {key = "neptune", r = 0.72, d = 29.0, P = 60182, L0 = 304.88, rot = 16.11, tilt = 28.32, seg = 20, rings = 14,
    diam = 49244, au = 30.07, typ = "type_ice", temp = "−200 °C", moons = "16"},
  {key = "moon", r = 0.14, d = 1.05, P = 27.3217, L0 = 218.32, rot = 655.72, tilt = 6.68, seg = 14, rings = 10, parent = 4,
    diam = 3474, typ = "type_moon", temp = "−173 … 127 °C", moons = "—"},
}
local NAME_KEYS = {"name_sun", "name_mercury", "name_venus", "name_earth", "name_mars", "name_jupiter", "name_saturn", "name_uranus", "name_neptune", "name_moon"}
local FACT_KEYS = {"fact_sun", "fact_mercury", "fact_venus", "fact_earth", "fact_mars", "fact_jupiter", "fact_saturn", "fact_uranus", "fact_neptune", "fact_moon"}
local SHORT_KEYS = {"short_sun", "short_mercury", "short_venus", "short_earth", "short_mars", "short_jupiter", "short_saturn", "short_uranus", "short_neptune", "short_moon"}

local simDays = 0
local speedSlider = 0.42
local playing = true
local focus = 0                 -- 0 = overview, else body index
local yaw, pitch, dist = 0.5, 0.55, 52
local tgtX, tgtY, tgtZ = 0, 0, 0
local wantDist = 52
local showOrbits, showLabels = true, true
local lastDx, lastDy, dragTotal = 0, 0, 0
local ringMesh, ringMeshLo
local stars = {}
local belt = {}
local land = nil
local projected = {}
local held = {}
local lang = "en"

local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function c3(r, g, b) return {clamp(floor(r + 0.5), 0, 254), clamp(floor(g + 0.5), 0, 254), clamp(floor(b + 0.5), 0, 254)} end
local function mix(a, b, t) return c3(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t) end

local function hash(a, b)
  local s = sin(a * 12.9898 + b * 78.233) * 43758.5453
  return s - floor(s)
end
local function noise(lat, lon, f)
  -- smooth value noise on the sphere (cheap)
  local x, y = lon * f, lat * f
  local xi, yi = floor(x), floor(y)
  local xf, yf = x - xi, y - yi
  xf, yf = xf * xf * (3 - 2 * xf), yf * yf * (3 - 2 * yf)
  local a, b = hash(xi, yi), hash(xi + 1, yi)
  local c, d = hash(xi, yi + 1), hash(xi + 1, yi + 1)
  return (a + (b - a) * xf) + ((c + (d - c) * xf) - (a + (b - a) * xf)) * yf
end

local function loadLand()
  local rows = require("landmask")
  land = {}
  for r = 1, #rows do
    local s = rows[r]
    for c = 0, 179 do
      local v = tonumber(s:sub(c // 4 + 1, c // 4 + 1), 16) or 0
      land[(r - 1) * 180 + c] = ((v >> (3 - c % 4)) & 1) == 1 and 1 or 0
    end
  end
end
local function landAt(latd, lond)
  local r = clamp(floor((90 - latd) / 2), 0, 89)
  local c = floor((lond + 180) / 2) % 180
  return land[r * 180 + c]
end
local function landFrac(latd, lond)
  return (landAt(latd, lond) * 2 + landAt(latd + 1.6, lond) + landAt(latd - 1.6, lond) + landAt(latd, lond + 2) + landAt(latd, lond - 2)) / 6
end

-- surface colour functions (lat, lon in radians) ------------------------------------
local COLFN = {
  sun = function(la, lo) local n = noise(la, lo, 5); return c3(255, 190 + n * 50, 70 + n * 60) end,
  mercury = function(la, lo) local n = noise(la, lo, 4) * 0.5 + noise(la, lo, 9) * 0.5; return c3(120 + n * 70, 114 + n * 64, 106 + n * 60) end,
  venus = function(la, lo) local n = noise(la * 3, lo * 0.6, 3); return c3(222 + n * 25, 190 + n * 30, 130 + n * 30) end,
  earth = function(la, lo)
    local latd, lond = la / rad, lo / rad
    if abs(latd) > 70 then return c3(236, 240, 244) end
    local f = landFrac(latd, lond)
    local n = noise(la, lo, 6)
    local ocean = c3(24 + n * 14, 70 + n * 20, 150 + n * 30)
    local alat = abs(latd)
    local g
    if alat > 14 and alat < 32 and n > 0.35 then g = c3(196, 168, 110) elseif alat > 55 then g = c3(96, 120, 80) else g = c3(64 + n * 40, 130 + n * 30, 60) end
    return mix(ocean, g, f)
  end,
  mars = function(la, lo)
    if abs(la) > 1.32 then return c3(240, 236, 230) end
    local n = noise(la, lo, 4) * 0.6 + noise(la, lo, 10) * 0.4
    return c3(170 + n * 60, 80 + n * 40, 50 + n * 25)
  end,
  jupiter = function(la, lo)
    local b = sin(la * 14 + noise(la, lo, 3) * 0.8)
    local c = b > 0 and c3(226, 206, 170) or c3(176, 128, 90)
    -- the Great Red Spot near 22 S
    local dl, dlo = (la + 0.38) / 0.09, (lo - 1.0) / 0.2
    if dl * dl + dlo * dlo < 1 then c = c3(200, 90, 60) end
    return c
  end,
  saturn = function(la, lo)
    local b = sin(la * 12 + 0.4) * 0.5 + 0.5
    return c3(214 + b * 24, 188 + b * 22, 130 + b * 20)
  end,
  uranus = function(la, lo) local b = sin(la * 6) * 0.5 + 0.5; return c3(150 + b * 20, 210 + b * 14, 220 + b * 10) end,
  neptune = function(la, lo)
    local b = sin(la * 7) * 0.5 + 0.5
    local c = c3(50 + b * 24, 90 + b * 30, 200 + b * 30)
    local dl, dlo = (la + 0.35) / 0.12, (lo + 0.6) / 0.25
    if dl * dl + dlo * dlo < 1 then c = c3(30, 50, 120) end
    return c
  end,
  moon = function(la, lo) local n = noise(la, lo, 5) * 0.6 + noise(la, lo, 12) * 0.4; return c3(130 + n * 70, 130 + n * 68, 132 + n * 66) end,
}

-- sphere with its poles on the z axis (so rz spins it and rx tilts it)
local function makeSphere(r, seg, rings, colfn)
  local v, idx, cols = {}, {}, {}
  local function add(x, y, z, c) v[#v + 1] = x; v[#v + 1] = y; v[#v + 1] = z; cols[#cols + 1] = c; return #v // 3 end
  local north = add(0, 0, r, colfn(pi / 2, 0))
  local ring = {}
  for i = 1, rings - 1 do
    local th = pi * i / rings
    local la = pi / 2 - th
    ring[i] = {}
    for j = 0, seg - 1 do
      local ph = 2 * pi * j / seg
      local lo = ph - pi
      ring[i][j] = add(sin(th) * cos(ph) * r, sin(th) * sin(ph) * r, cos(th) * r, colfn(la, lo))
    end
  end
  local south = add(0, 0, -r, colfn(-pi / 2, 0))
  local function tri(a, b, c)
    -- keep the winding outward (sphere centred at the origin)
    local ax, ay, az = v[a * 3 - 2], v[a * 3 - 1], v[a * 3]
    local bx, by, bz = v[b * 3 - 2], v[b * 3 - 1], v[b * 3]
    local cx, cy, cz = v[c * 3 - 2], v[c * 3 - 1], v[c * 3]
    local ux, uy, uz = bx - ax, by - ay, bz - az
    local wx, wy, wz = cx - ax, cy - ay, cz - az
    local nx, ny, nz = uy * wz - uz * wy, uz * wx - ux * wz, ux * wy - uy * wx
    if nx * (ax + bx + cx) + ny * (ay + by + cy) + nz * (az + bz + cz) < 0 then b, c = c, b end
    idx[#idx + 1] = a; idx[#idx + 1] = b; idx[#idx + 1] = c
  end
  for j = 0, seg - 1 do
    local j2 = (j + 1) % seg
    tri(north, ring[1][j], ring[1][j2])
    tri(south, ring[rings - 1][j2], ring[rings - 1][j])
  end
  for i = 1, rings - 2 do
    for j = 0, seg - 1 do
      local j2 = (j + 1) % seg
      tri(ring[i][j], ring[i + 1][j], ring[i + 1][j2])
      tri(ring[i][j], ring[i + 1][j2], ring[i][j2])
    end
  end
  return g3d.custom(v, idx, cols)
end

local function makeRings(inner, outer, seg, bands)
  local v, idx, cols = {}, {}, {}
  local palette = {{196, 174, 132, 150}, {226, 206, 160, 215}, {150, 130, 100, 110}, {214, 194, 150, 190}}
  for b = 0, bands do
    local r = inner + (outer - inner) * b / bands
    for j = 0, seg - 1 do
      local a = 2 * pi * j / seg
      v[#v + 1] = cos(a) * r; v[#v + 1] = sin(a) * r; v[#v + 1] = 0
      cols[#cols + 1] = palette[(b % #palette) + 1]
    end
  end
  for b = 0, bands - 1 do
    for j = 0, seg - 1 do
      local j2 = (j + 1) % seg
      local a, c = b * seg + j + 1, (b + 1) * seg + j + 1
      local a2, c2 = b * seg + j2 + 1, (b + 1) * seg + j2 + 1
      idx[#idx + 1] = a; idx[#idx + 1] = c; idx[#idx + 1] = c2
      idx[#idx + 1] = a; idx[#idx + 1] = c2; idx[#idx + 1] = a2
    end
  end
  return g3d.custom(v, idx, cols, true)
end

-- simulation -------------------------------------------------------------------------
local function nowDays() return (sys.epoch() - J2000) / 86400 end

local function speedDays()
  if speedSlider <= 0.005 then return 0 end
  return 10 ^ (speedSlider * 5 - 3)   -- 0.001 .. 100 days per second
end

local function updatePositions()
  for i, b in ipairs(BODIES) do
    if b.P > 0 then
      local a = (b.L0 + 360 * simDays / b.P) * rad
      local px, py, pz = 0, 0, 0
      if b.parent then local p = BODIES[b.parent]; px, py, pz = p.x, p.y, p.z end
      b.x, b.y, b.z = px + cos(a) * b.d, py, pz - sin(a) * b.d
      b.angle = a
    else
      b.x, b.y, b.z = 0, 0, 0
    end
  end
end

local function setFocus(i)
  focus = i
  if i == 0 then wantDist = 52
  else
    local b = BODIES[i]
    wantDist = max(1.6, b.r * 6 + 1.2)
    if b.key == "saturn" then wantDist = b.r * 8 end
  end
  audio.play("click")
end

-- formatting ---------------------------------------------------------------------------
local function fmtNum(x, dec)
  dec = dec or 0
  local s = string.format("%." .. dec .. "f", x)
  local int, frac = s:match("^(-?%d+)%.?(%d*)$")
  if not int then return s end
  local sep, dsep = lang == "tr" and "." or ",", lang == "tr" and "," or "."
  local out = int:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
  if out:sub(1, 1) == sep then out = out:sub(2) end
  if out:sub(1, 2) == "-" .. sep then out = "-" .. out:sub(3) end
  if frac ~= "" then out = out .. dsep .. frac end
  return out
end

local function fmtPeriod(days)
  if days >= 730 then return TR("unit_years", fmtNum(days / 365.25, 2)) end
  return TR("unit_days", fmtNum(days, days < 100 and 1 or 0))
end

local function fmtDay(hours)
  local h = abs(hours)
  local s
  if h < 72 then
    local hh = floor(h)
    s = TR("unit_hm", hh, floor((h - hh) * 60 + 0.5))
  else
    s = TR("unit_days", fmtNum(h / 24, 1))
  end
  if hours < 0 then s = s .. " " .. TR("retrograde") end
  return s
end

local function fmtSpeed()
  local d = speedDays()
  if not playing or d == 0 then return TR("speed_paused") end
  if d < 1 / 24 then return TR("speed_min", fmtNum(d * 1440, 1)) end
  if d < 1 then return TR("speed_hours", fmtNum(d * 24, 1)) end
  return TR("speed_days", fmtNum(d, d < 10 and 1 or 0))
end

local function fmtDate()
  local e = J2000 + simDays * 86400
  local ok, d = pcall(sys.date, floor(e))
  if not ok or type(d) ~= "table" then return "" end
  if lang == "tr" then return string.format("%02d.%02d.%04d  %02d:%02d", d.day, d.month, d.year, d.hour, d.min) end
  return string.format("%04d-%02d-%02d  %02d:%02d", d.year, d.month, d.day, d.hour, d.min)
end

-- app ------------------------------------------------------------------------------------
function app.load(arg)
  lang = sys.lang() == "tr" and "tr" or "en"
  loadLand()
  for i, b in ipairs(BODIES) do
    local fn = COLFN[b.key]
    b.hi = makeSphere(b.r, b.seg, b.rings, fn)
    b.lo = makeSphere(b.r, 10, 7, fn)
    b.spin = 0
  end
  ringMesh = makeRings(BODIES[7].r * 1.25, BODIES[7].r * 2.3, 64, 4)
  ringMeshLo = makeRings(BODIES[7].r * 1.25, BODIES[7].r * 2.3, 28, 2)
  -- star directions
  local s = 12345
  local function rnd() s = (s * 1103515245 + 12345) % 2147483648; return s / 2147483648 end
  for i = 1, 260 do
    local z = rnd() * 2 - 1
    local a = rnd() * 2 * pi
    local r = sqrt(1 - z * z)
    stars[i] = {cos(a) * r, z, sin(a) * r, rnd() < 0.12 and 2 or 1, floor(80 + rnd() * 170)}
  end
  for i = 1, 150 do
    local f = rnd()
    local au = 2.2 + f * 1.1                      -- main belt between ~2.2 and 3.3 AU
    belt[i] = {12.6 + f * 1.6, rnd() * 2 * pi, (rnd() - 0.5) * 0.5, 365.25 * au ^ 1.5}
  end
  showOrbits = store.get("orbits", true)
  showLabels = store.get("labels", true)
  speedSlider = store.get("speed", 0.42)
  simDays = nowDays()
  updatePositions()
end

function app.update(dt)
  dt = min(dt, 0.05)
  local spd = playing and speedDays() or 0
  simDays = simDays + spd * dt
  updatePositions()
  for _, b in ipairs(BODIES) do
    -- visual spin: real rate, but capped so fast-forwarding does not strobe
    local revPerSec = spd * 24 / b.rot
    if abs(revPerSec) > 0.4 then revPerSec = revPerSec > 0 and 0.4 or -0.4 end
    b.spin = (b.spin + revPerSec * 2 * pi * dt) % (2 * pi)
  end
  -- camera inputs
  local lx, ly = input.stick("left")
  local rx, ry = input.stick("right")
  if abs(lx) > 0.15 then yaw = yaw - lx * dt * 1.8 end
  if abs(ly) > 0.15 then pitch = pitch + ly * dt * 1.4 end
  if abs(ry) > 0.15 then wantDist = wantDist * exp(-ry * dt * 1.5) end
  if abs(rx) > 0.15 then yaw = yaw - rx * dt * 1.8 end
  if held.left then yaw = yaw + dt * 1.5 end
  if held.right then yaw = yaw - dt * 1.5 end
  if held.up then pitch = pitch + dt * 1.2 end
  if held.down then pitch = pitch - dt * 1.2 end
  if input.down("zl") then wantDist = wantDist * exp(dt * 1.2) end
  if input.down("zr") then wantDist = wantDist * exp(-dt * 1.2) end
  pitch = clamp(pitch, -1.45, 1.45)
  local minD = focus > 0 and BODIES[focus].r * 2.2 or 6
  wantDist = clamp(wantDist, minD, 120)
  dist = dist + (wantDist - dist) * min(1, dt * 4)
  local fx, fy, fz = 0, 0, 0
  if focus > 0 then local b = BODIES[focus]; fx, fy, fz = b.x, b.y, b.z end
  local k = min(1, dt * 4)
  tgtX, tgtY, tgtZ = tgtX + (fx - tgtX) * k, tgtY + (fy - tgtY) * k, tgtZ + (fz - tgtZ) * k
end

local function drawStars(ex, ey, ez)
  for _, s in ipairs(stars) do
    local x, y = g3d.project(ex + s[1] * 300, ey + s[2] * 300, ez + s[3] * 300)
    if x then
      gfx.color(255, 255, 255, s[5])
      gfx.rect(x, y, s[4], s[4])
    end
  end
end

local function drawOrbit(b, ex, ey, ez, highlight)
  local pts = {}
  local cx, cz = 0, 0
  if b.parent then local p = BODIES[b.parent]; cx, cz = p.x, p.z end
  local n = b.parent and 40 or 72
  local function flush()
    if #pts >= 4 then gfx.lines(pts, highlight and 2 or 1.2, false) end
    pts = {}
  end
  if highlight then gfx.color(140, 200, 255, 170) else gfx.color(140, 170, 220, 70) end
  for k = 0, n do
    local a = 2 * pi * k / n
    local x, y = g3d.project(cx + cos(a) * b.d, 0, cz - sin(a) * b.d)
    if x then pts[#pts + 1] = x; pts[#pts + 1] = y else flush() end
  end
  flush()
end

function app.draw(w, h)
  gfx.clear("#04060C")
  local barH = 96
  local vh = h - barH
  -- camera drag / tap to pick (drawn first so widgets on top win)
  local hit = ui.hit("space", 0, 0, w, vh)
  if hit.pressed then lastDx, lastDy, dragTotal = 0, 0, 0 end
  if hit.held then
    local ddx, ddy = hit.dx - lastDx, hit.dy - lastDy
    lastDx, lastDy = hit.dx, hit.dy
    dragTotal = dragTotal + abs(ddx) + abs(ddy)
    yaw = yaw - ddx * 0.008
    pitch = clamp(pitch + ddy * 0.006, -1.45, 1.45)
  end
  local pickX, pickY = nil, nil
  if hit.clicked and dragTotal < 8 then pickX, pickY = ui.mouse() end

  local cp = cos(pitch)
  local ex, ey, ez = tgtX + dist * cp * sin(yaw), tgtY + dist * sin(pitch), tgtZ + dist * cp * cos(yaw)
  local fov = 50
  local focal = (vh / 2) / math.tan(fov * pi / 360)
  g3d.begin(0, 0, w, vh, fov, 0.05, 600)
  g3d.camera(ex, ey, ez, tgtX, tgtY, tgtZ)
  drawStars(ex, ey, ez)
  -- sun glow (2D, behind everything 3D)
  local sun = BODIES[1]
  local gx, gy, gd = g3d.project(0, 0, 0)
  if gx then
    local pr = sun.r * focal / gd
    for k = 7, 1, -1 do
      gfx.color(255, 170, 60, floor(10 + 4 * (7 - k)))
      gfx.circle(gx, gy, pr * (1 + k * 0.32))
    end
  end
  if showOrbits then
    for i = 2, #BODIES do
      local b = BODIES[i]
      if not b.parent or dist < 14 then drawOrbit(b, ex, ey, ez, focus == i) end
    end
  end
  -- bodies
  projected = {}
  for i, b in ipairs(BODIES) do
    local sx, sy, d = g3d.project(b.x, b.y, b.z)
    if sx then
      local pr = b.r * focal / d
      projected[i] = {sx, sy, pr, d}
      local tilt = -pi / 2 + b.tilt * rad
      if i == 1 then
        g3d.draw(pr > 14 and b.hi or b.lo, 0, 0, 0, tilt, 0, b.spin, 1, 1, 1, nil, "unlit")
      elseif pr < 1.2 then
        g3d.point(b.x, b.y, b.z, 2.5, COLFN[b.key](0.3, 0.5))
      else
        local lx, ly, lz = -b.x, -b.y, -b.z
        if lx * lx + lz * lz < 1e-6 then lx = 1 end
        g3d.light(lx, ly, lz, 0.07)
        g3d.draw(pr > 10 and b.hi or b.lo, b.x, b.y, b.z, tilt, 0, b.spin)
        if b.key == "saturn" then
          g3d.draw(pr > 18 and ringMesh or ringMeshLo, b.x, b.y, b.z, tilt, 0, 0, 1, 1, 1, nil, "nocull unlit")
        end
      end
    end
  end
  -- asteroid belt
  local t = simDays
  for _, a in ipairs(belt) do
    local ang = a[2] + t * 2 * pi / a[4]
    g3d.point(cos(ang) * a[1], a[3], -sin(ang) * a[1], 2, {150, 140, 125})
  end
  g3d.finish()

  -- picking
  if pickX then
    local bestI, bestD = nil, 1e9
    for i, p in pairs(projected) do
      local dx, dy = pickX - p[1], pickY - p[2]
      local d = sqrt(dx * dx + dy * dy)
      if d < max(p[3], 16) + 6 and p[4] < bestD then bestI, bestD = i, p[4] end
    end
    if bestI then setFocus(bestI) end
  end

  -- labels
  if showLabels then
    for i, p in pairs(projected) do
      local b = BODIES[i]
      if (not b.parent or dist < 14) and p[1] > -50 and p[1] < w + 50 and p[2] > -20 and p[2] < vh then
        local name = TR(NAME_KEYS[i])
        local ly = p[2] + max(p[3], 3) + 4
        gfx.color(0, 0, 0, 150)
        gfx.text(name, p[1] - 60 + 1, ly + 1, 12, "semibold", "center", 120)
        gfx.color(focus == i and {140, 210, 255} or {230, 236, 245})
        gfx.text(name, p[1] - 60, ly, 12, "semibold", "center", 120)
      end
    end
  end
  if focus > 0 and projected[focus] then
    local p = projected[focus]
    gfx.color(140, 210, 255, 160)
    gfx.circleLine(p[1], p[2], max(p[3], 6) + 6, 1.5)
  end

  -- top-left: date and speed
  gfx.color(10, 14, 26, 190)
  gfx.rect(14, 14, 270, 58, 12)
  gfx.icon("event", 34, 33, 18, "#FFFFFF")
  gfx.color("#FFFFFF")
  gfx.text(fmtDate(), 50, 22, 15, "monobold")
  gfx.color(255, 255, 255, 170)
  gfx.text(fmtSpeed(), 50, 46, 12, "semibold")
  -- toggles
  if ui.iconButton("blur_circular", w - 100, 14, 38, 38, "#FFFFFF", showOrbits) then showOrbits = not showOrbits; store.set("orbits", showOrbits) end
  if ui.iconButton("label", w - 54, 14, 38, 38, "#FFFFFF", showLabels) then showLabels = not showLabels; store.set("labels", showLabels) end

  -- info panel
  if focus > 0 then
    local b = BODIES[focus]
    local pw = 300
    local px, py = w - pw - 14, 64
    local fact = TR(FACT_KEYS[focus])
    local fh = gfx.measureWrap(fact, pw - 32, 13)
    local ph = 252 + fh
    gfx.shadow(px, py, pw, ph, 14, 20, 4)
    gfx.color(12, 16, 30, 225)
    gfx.rect(px, py, pw, ph, 14)
    gfx.color("#FFFFFF")
    gfx.text(TR(NAME_KEYS[focus]), px + 16, py + 14, 22, "bold")
    gfx.color(140, 200, 255)
    gfx.text(TR(b.typ), px + 16, py + 44, 13, "semibold")
    local rows = {
      {TR("f_diameter"), TR("unit_km", fmtNum(b.diam))},
    }
    if b.key == "moon" then
      rows[#rows + 1] = {TR("f_distance"), TR("moon_distance")}
      rows[#rows + 1] = {TR("f_orbit"), fmtPeriod(b.P)}
    elseif b.au then
      rows[#rows + 1] = {TR("f_distance"), TR("unit_au", fmtNum(b.au, b.au < 10 and 2 or 1), fmtNum(b.au * 149.6, 1))}
      rows[#rows + 1] = {TR("f_orbit"), fmtPeriod(b.P)}
    end
    rows[#rows + 1] = {TR("f_rotation"), fmtDay(b.rot)}
    rows[#rows + 1] = {TR("f_tilt"), fmtNum(b.tilt, 1) .. "°"}
    rows[#rows + 1] = {TR("f_temp"), b.temp}
    if b.key ~= "moon" then rows[#rows + 1] = {TR(b.key == "sun" and "f_planets" or "f_moons"), b.moons} end
    local ry = py + 70
    for _, r in ipairs(rows) do
      gfx.color(255, 255, 255, 150)
      gfx.text(r[1], px + 16, ry, 12)
      gfx.color("#FFFFFF")
      gfx.text(r[2], px + 16, ry, 12, "semibold", "right", pw - 32)
      ry = ry + 22
    end
    ry = ry + 6
    gfx.color(255, 255, 255, 40)
    gfx.rect(px + 16, ry, pw - 32, 1)
    gfx.color(230, 236, 245)
    gfx.wrap(fact, px + 16, ry + 10, pw - 32, 13)
    if ui.iconButton("close", px + pw - 40, py + 10, 30, 30, "#FFFFFF") then setFocus(0) end
  end

  -- bottom bar: bodies + time controls
  gfx.color(12, 16, 28, 240)
  gfx.rect(0, vh, w, barH)
  gfx.color(255, 255, 255, 30)
  gfx.rect(0, vh, w, 1)
  local order = {1, 2, 3, 4, 10, 5, 6, 7, 8, 9}
  local bw = (w - 32 - 9 * 6) / 10
  for k, i in ipairs(order) do
    local x = 16 + (k - 1) * (bw + 6)
    if ui.button(TR(SHORT_KEYS[i]) .. "##b" .. i, x, vh + 10, bw, 32, focus == i and "primary" or "default") then setFocus(i) end
  end
  local cy = vh + 52
  if ui.iconButton(playing and "pause" or "play_arrow", 16, cy, 36, 36, "#FFFFFF") then playing = not playing end
  gfx.color(255, 255, 255, 170)
  gfx.text(TR("time_speed"), 62, cy + 10, 12, "semibold")
  local tw = gfx.textWidth(TR("time_speed"), 12, "semibold")
  local sw = 280
  local ns = ui.slider("speed", speedSlider, 0, 1, 72 + tw, cy + 4, sw)
  if ns ~= speedSlider then speedSlider = ns; store.set("speed", ns) end
  gfx.color("#FFFFFF")
  gfx.text(fmtSpeed(), 84 + tw + sw, cy + 10, 12, "semibold")
  if ui.button(TR("today"), w - 244, cy + 2, 110, 32, "default", "today") then simDays = nowDays() end
  if ui.button(TR("overview"), w - 126, cy + 2, 110, 32, "default", "public") then setFocus(0) end
end

local KEYBODY = {["0"] = 1, ["1"] = 2, ["2"] = 3, ["3"] = 4, ["4"] = 5, ["5"] = 6, ["6"] = 7, ["7"] = 8, ["8"] = 9, ["9"] = 10}
local CYCLE = {1, 2, 3, 4, 10, 5, 6, 7, 8, 9}

local function cycle(dir)
  local pos = 0
  for k, i in ipairs(CYCLE) do if i == focus then pos = k end end
  pos = pos + dir
  if pos < 1 then pos = #CYCLE elseif pos > #CYCLE then pos = 1 end
  setFocus(CYCLE[pos])
end

function app.event(e)
  if e.type == "keydown" then
    if KEYBODY[e.key] then setFocus(KEYBODY[e.key])
    elseif e.key == "space" then playing = not playing
    elseif e.key == "escape" then setFocus(0)
    elseif e.key == "o" then showOrbits = not showOrbits; store.set("orbits", showOrbits)
    elseif e.key == "l" then showLabels = not showLabels; store.set("labels", showLabels)
    elseif e.key == "t" then simDays = nowDays()
    elseif e.key == "tab" then cycle(e.shift and -1 or 1)
    elseif e.key == "pageup" then wantDist = wantDist * 0.8
    elseif e.key == "pagedown" then wantDist = wantDist * 1.25
    elseif e.key == "left" or e.key == "right" or e.key == "up" or e.key == "down" then held[e.key] = true
    end
  elseif e.type == "keyup" then
    held[e.key] = nil
  elseif e.type == "scroll" then
    wantDist = wantDist * exp(-e.dy * 0.004)
  elseif e.type == "paddown" then
    if e.pad == "r" then cycle(1)
    elseif e.pad == "l" then cycle(-1)
    elseif e.pad == "a" then playing = not playing
    elseif e.pad == "b" then setFocus(0)
    elseif e.pad == "x" then showOrbits = not showOrbits; store.set("orbits", showOrbits)
    elseif e.pad == "y" then showLabels = not showLabels; store.set("labels", showLabels)
    elseif e.pad == "right" then speedSlider = min(1, speedSlider + 0.05); store.set("speed", speedSlider)
    elseif e.pad == "left" then speedSlider = max(0, speedSlider - 0.05); store.set("speed", speedSlider)
    elseif e.pad == "minus" then simDays = nowDays()
    end
  end
end

function app.menu()
  return {{title = TR("view"), items = {
    {label = TR("overview"), id = 1, shortcut = "Esc"},
    {label = TR("today"), id = 2, shortcut = "T"},
    {label = TR("play_pause"), id = 3, shortcut = "Space"},
    "-",
    {label = TR("toggle_orbits"), id = 4, shortcut = "O"},
    {label = TR("toggle_labels"), id = 5, shortcut = "L"},
  }}}
end

function app.onmenu(id)
  if id == 1 then setFocus(0)
  elseif id == 2 then simDays = nowDays()
  elseif id == 3 then playing = not playing
  elseif id == 4 then showOrbits = not showOrbits; store.set("orbits", showOrbits)
  elseif id == 5 then showLabels = not showLabels; store.set("labels", showLabels)
  end
end

return app
