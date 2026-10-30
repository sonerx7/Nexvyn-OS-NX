-- Globe: a 3D Earth with continents from an embedded land mask, real-time day/night lighting from the current
-- UTC time, an atmosphere glow and city markers with local times.
local app = {}

local floor, min, max, abs, sqrt, sin, cos, pi, atan, asin, exp = math.floor, math.min, math.max, math.abs, math.sqrt, math.sin, math.cos, math.pi, math.atan, math.asin, math.exp
local rad = pi / 180

local SEG, RINGS = 60, 34
local LIST_W, BAR_H = 206, 58

-- name key, latitude, longitude, UTC offset (standard time)
local CITIES = {
  {"c_istanbul", 41.01, 28.98, 3}, {"c_ankara", 39.93, 32.86, 3}, {"c_izmir", 38.42, 27.14, 3},
  {"c_london", 51.51, -0.13, 0}, {"c_paris", 48.86, 2.35, 1}, {"c_berlin", 52.52, 13.40, 1},
  {"c_moscow", 55.76, 37.62, 3}, {"c_cairo", 30.04, 31.24, 2}, {"c_dubai", 25.20, 55.27, 4},
  {"c_delhi", 28.61, 77.21, 5.5}, {"c_beijing", 39.90, 116.40, 8}, {"c_tokyo", 35.68, 139.69, 9},
  {"c_singapore", 1.35, 103.82, 8}, {"c_sydney", -33.87, 151.21, 10}, {"c_nairobi", -1.29, 36.82, 3},
  {"c_capetown", -33.92, 18.42, 2}, {"c_reykjavik", 64.15, -21.94, 0}, {"c_newyork", 40.71, -74.01, -5},
  {"c_mexico", 19.43, -99.13, -6}, {"c_losangeles", 34.05, -118.24, -8}, {"c_honolulu", 21.31, -157.86, -10},
  {"c_rio", -22.91, -43.17, -3}, {"c_buenosaires", -34.60, -58.38, -3},
}

local globeMesh
local land = {}
local camLon, camLat, dist = 30, 25, 3.4
local wantLon, wantLat, wantDist = 30, 25, 3.4
local flying = false
local autoRotate, showGrid, gyroOn = true, false, false
local selected = 1
local timeShift = 0
local lastDx, lastDy, dragTotal = 0, 0, 0
local stars = {}
local tilt0x, tilt0y = 0, 0
local held = {}
local projected = {}

local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function c3(r, g, b) return {clamp(floor(r + 0.5), 0, 254), clamp(floor(g + 0.5), 0, 254), clamp(floor(b + 0.5), 0, 254)} end
local function mix(a, b, t) return c3(a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t) end
local function wrap180(a) return (a + 180) % 360 - 180 end

-- latitude/longitude (degrees) -> unit vector; lon 0 faces +z, east is +x, north is +y
local function sph(lat, lon)
  local la, lo = lat * rad, lon * rad
  return cos(la) * sin(lo), sin(la), cos(la) * cos(lo)
end

-- land mask ------------------------------------------------------------------------------
local function loadLand()
  local rows = require("landmask")
  for r = 1, #rows do
    local s = rows[r]
    for c = 0, 179 do
      local v = tonumber(s:sub(c // 4 + 1, c // 4 + 1), 16) or 0
      land[(r - 1) * 180 + c] = ((v >> (3 - c % 4)) & 1)
    end
  end
end
local function landAt(lat, lon)
  local r = clamp(floor((90 - lat) / 2), 0, 89)
  local c = floor((lon + 180) / 2) % 180
  return land[r * 180 + c]
end
local function landFrac(lat, lon, radius)
  local sum, n = 0, 0
  for dy = -1, 1 do
    for dx = -1, 1 do
      local w = (dx == 0 and dy == 0) and 2 or 1
      local la = clamp(lat + dy * radius, -89.9, 89.9)
      local cl = max(0.25, cos(la * rad))
      sum = sum + landAt(la, lon + dx * radius / cl) * w
      n = n + w
    end
  end
  return sum / n
end

local function hash(a, b)
  local s = sin(a * 12.9898 + b * 78.233) * 43758.5453
  return s - floor(s)
end

local function inBox(lat, lon, la0, la1, lo0, lo1) return lat >= la0 and lat <= la1 and lon >= lo0 and lon <= lo1 end

local function surfaceColor(lat, lon)
  local f = landFrac(lat, lon, 1.6)
  local coast = landFrac(lat, lon, 4.5)
  local n = hash(floor(lat / 3), floor(lon / 3)) * 0.5 + hash(floor(lat), floor(lon)) * 0.5
  -- oceans: shallow near the coasts, deep in the open sea
  local deep, shallow = c3(14, 46, 110), c3(36, 104, 168)
  local ocean = mix(deep, shallow, min(1, coast * 1.6))
  if lat < -62 then ocean = mix(ocean, c3(200, 214, 228), 0.35) end
  -- land biomes
  local alat = abs(lat)
  local g
  if lat < -60 or (lat > 59 and lon > -75 and lon < -10) or alat > 78 then g = c3(238, 242, 246)
  elseif inBox(lat, lon, 14, 33, -17, 60) or inBox(lat, lon, -32, -18, 114, 146) or inBox(lat, lon, -28, -19, 14, 26) or
    inBox(lat, lon, 25, 42, -120, -102) or inBox(lat, lon, -30, -18, -72, -66) then
    g = c3(206 + n * 20, 176 + n * 18, 116 + n * 10)
  elseif inBox(lat, lon, 36, 48, 52, 118) then g = c3(176 + n * 20, 158 + n * 16, 110)
  elseif alat > 64 then g = c3(130 + n * 20, 128 + n * 16, 104)
  elseif alat > 50 then g = c3(48 + n * 16, 98 + n * 20, 56)
  elseif alat < 15 then g = c3(34 + n * 18, 112 + n * 26, 44)
  else g = c3(78 + n * 34, 128 + n * 24, 62 + n * 10) end
  return mix(ocean, g, clamp((f - 0.15) / 0.7, 0, 1))
end

local function buildGlobe()
  local v, idx, cols = {}, {}, {}
  local function add(lat, lon)
    local x, y, z = sph(lat, lon)
    v[#v + 1] = x; v[#v + 1] = y; v[#v + 1] = z
    cols[#cols + 1] = surfaceColor(lat, lon)
    return #v // 3
  end
  local north = add(90, 0)
  local ring = {}
  for i = 1, RINGS - 1 do
    local lat = 90 - 180 * i / RINGS
    ring[i] = {}
    for j = 0, SEG - 1 do ring[i][j] = add(lat, -180 + 360 * j / SEG) end
  end
  local south = add(-90, 0)
  -- winding: viewed from outside, (east, north) is counter-clockwise, so (p, p_south, p_south_east) works
  local function tri(a, b, c)
    local ax, ay, az = v[a * 3 - 2], v[a * 3 - 1], v[a * 3]
    local bx, by, bz = v[b * 3 - 2], v[b * 3 - 1], v[b * 3]
    local cx, cy, cz = v[c * 3 - 2], v[c * 3 - 1], v[c * 3]
    local ux, uy, uz = bx - ax, by - ay, bz - az
    local wx, wy, wz = cx - ax, cy - ay, cz - az
    local nx, ny, nz = uy * wz - uz * wy, uz * wx - ux * wz, ux * wy - uy * wx
    if nx * (ax + bx + cx) + ny * (ay + by + cy) + nz * (az + bz + cz) < 0 then b, c = c, b end
    idx[#idx + 1] = a; idx[#idx + 1] = b; idx[#idx + 1] = c
  end
  for j = 0, SEG - 1 do
    local j2 = (j + 1) % SEG
    tri(north, ring[1][j], ring[1][j2])
    tri(south, ring[RINGS - 1][j2], ring[RINGS - 1][j])
  end
  for i = 1, RINGS - 2 do
    for j = 0, SEG - 1 do
      local j2 = (j + 1) % SEG
      tri(ring[i][j], ring[i + 1][j], ring[i + 1][j2])
      tri(ring[i][j], ring[i + 1][j2], ring[i][j2])
    end
  end
  globeMesh = g3d.custom(v, idx, cols)
end

-- time and sun --------------------------------------------------------------------------
local function nowEpoch() return sys.epoch() + timeShift * 3600 end

-- subsolar point (degrees) for a Unix time (low-precision solar position)
local function subsolar(epoch)
  local n = epoch / 86400 + 2440587.5 - 2451545.0
  local L = (280.460 + 0.9856474 * n) % 360
  local g = ((357.528 + 0.9856003 * n) % 360) * rad
  local lam = (L + 1.915 * sin(g) + 0.020 * sin(2 * g)) * rad
  local eps = (23.439 - 0.0000004 * n) * rad
  local dec = asin(sin(eps) * sin(lam))
  local ra = atan(cos(eps) * sin(lam), cos(lam))
  local gmst = (18.697374558 + 24.06570982441908 * n) % 24
  local lon = wrap180(ra / rad - gmst * 15)
  return dec / rad, lon
end

-- days since 1970-01-01 -> y, m, d (proleptic Gregorian)
local function civil(days)
  local z = days + 719468
  local era = (z >= 0 and z or z - 146096) // 146097
  local doe = z - era * 146097
  local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
  local y = yoe + era * 400
  local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
  local mp = (5 * doy + 2) // 153
  local d = doy - (153 * mp + 2) // 5 + 1
  local m = mp < 10 and mp + 3 or mp - 9
  if m <= 2 then y = y + 1 end
  return y, m, d
end

local function localTime(tz)
  local e = floor(nowEpoch() + tz * 3600)
  local secs = e % 86400
  local y, m, d = civil(e // 86400)
  return floor(secs / 3600), floor(secs % 3600 / 60), y, m, d
end

local function fmtOffset(tz)
  local sign = tz < 0 and "−" or "+"
  local a = abs(tz)
  local h = floor(a)
  local mm = floor((a - h) * 60 + 0.5)
  if mm > 0 then return string.format("UTC%s%d:%02d", sign, h, mm) end
  if tz == 0 then return "UTC" end
  return string.format("UTC%s%d", sign, h)
end

local function readTilt()
  local ax, ay, az = input.motion()
  return atan(ax, sqrt(ay * ay + az * az)), atan(az, -ay)
end

local function selectCity(i)
  selected = i
  local c = CITIES[i]
  wantLat, wantLon = clamp(c[2], -70, 70), c[3]
  wantDist = min(dist, 2.6)
  flying = true
  audio.play("click")
end

-- app ------------------------------------------------------------------------------------
function app.load(arg)
  loadLand()
  buildGlobe()
  autoRotate = store.get("auto", true)
  showGrid = store.get("grid", false)
  gyroOn = store.get("gyro", false)
  selected = store.get("city", 1)
  if selected < 1 or selected > #CITIES then selected = 1 end
  local c = CITIES[selected]
  camLat, camLon = clamp(c[2], -70, 70), c[3]
  wantLat, wantLon = camLat, camLon
  local s = 99
  local function rnd() s = (s * 1103515245 + 12345) % 2147483648; return s / 2147483648 end
  for i = 1, 180 do stars[i] = {rnd(), rnd(), rnd() < 0.15 and 2 or 1, floor(70 + rnd() * 170)} end
  tilt0x, tilt0y = readTilt()
end

function app.update(dt)
  dt = min(dt, 0.05)
  local lx, ly = input.stick("left")
  local rx, ry = input.stick("right")
  local user = false
  if abs(lx) > 0.15 then camLon = camLon + lx * dt * 70; user = true end
  if abs(ly) > 0.15 then camLat = camLat + ly * dt * 55; user = true end
  if abs(ry) > 0.15 then wantDist = wantDist * exp(-ry * dt * 1.2) end
  if abs(rx) > 0.15 then camLon = camLon + rx * dt * 70; user = true end
  if held.left then camLon = camLon - dt * 60; user = true end
  if held.right then camLon = camLon + dt * 60; user = true end
  if held.up then camLat = camLat + dt * 45; user = true end
  if held.down then camLat = camLat - dt * 45; user = true end
  if input.down("zl") then wantDist = wantDist * exp(dt) end
  if input.down("zr") then wantDist = wantDist * exp(-dt) end
  if gyroOn then
    local tx, ty = readTilt()
    local gx, gy = tx - tilt0x, ty - tilt0y
    if abs(gx) > 0.05 then camLon = camLon - gx * dt * 120; user = true end
    if abs(gy) > 0.05 then camLat = camLat + gy * dt * 90; user = true end
  end
  if user then flying = false end
  if flying then
    local dl = wrap180(wantLon - camLon)
    local k = min(1, dt * 3)
    camLon = camLon + dl * k
    camLat = camLat + (wantLat - camLat) * k
    if abs(dl) < 0.3 and abs(wantLat - camLat) < 0.3 then flying = false end
  elseif autoRotate and not user then
    camLon = camLon - dt * 4   -- surface drifts eastward like the real Earth seen from space
  end
  camLon = wrap180(camLon)
  camLat = clamp(camLat, -80, 80)
  wantDist = clamp(wantDist, 1.45, 7)
  dist = dist + (wantDist - dist) * min(1, dt * 4)
end

local function drawGrid(ex, ey, ez)
  local el = sqrt(ex * ex + ey * ey + ez * ez)
  local hx, hy, hz = ex / el, ey / el, ez / el
  local lim = 1 / dist + 0.02
  local col = {255, 255, 255, 45}
  local function seg(la1, lo1, la2, lo2)
    local x1, y1, z1 = sph(la1, lo1)
    local x2, y2, z2 = sph(la2, lo2)
    local mx, my, mz = (x1 + x2) / 2, (y1 + y2) / 2, (z1 + z2) / 2
    local ml = sqrt(mx * mx + my * my + mz * mz)
    if (mx * hx + my * hy + mz * hz) / ml > lim then
      local r = 1.004
      g3d.line(x1 * r, y1 * r, z1 * r, x2 * r, y2 * r, z2 * r, col, 1)
    end
  end
  for lat = -60, 60, 30 do
    for k = 0, 47 do seg(lat, -180 + k * 7.5, lat, -180 + (k + 1) * 7.5) end
  end
  for lon = -180, 150, 30 do
    for k = 0, 23 do seg(-90 + k * 7.5, lon, -90 + (k + 1) * 7.5, lon) end
  end
end

function app.draw(w, h)
  gfx.clear("#03050B")
  local vx, vy, vw, vh = LIST_W, 0, w - LIST_W, h - BAR_H
  for _, s in ipairs(stars) do
    gfx.color(255, 255, 255, s[4])
    gfx.rect(vx + s[1] * vw, s[2] * vh, s[3], s[3])
  end
  -- drag to rotate, tap a marker to select (drawn first so widgets on top win)
  local hit = ui.hit("globe", vx, vy, vw, vh)
  if hit.pressed then lastDx, lastDy, dragTotal = 0, 0, 0 end
  if hit.held then
    local ddx, ddy = hit.dx - lastDx, hit.dy - lastDy
    lastDx, lastDy = hit.dx, hit.dy
    dragTotal = dragTotal + abs(ddx) + abs(ddy)
    local k = 0.18 * (dist - 1) / 2.4
    camLon = wrap180(camLon - ddx * k)
    camLat = clamp(camLat + ddy * k, -80, 80)
    if dragTotal > 4 then flying = false end
  end
  local pickX, pickY = nil, nil
  if hit.clicked and dragTotal < 8 then pickX, pickY = ui.mouse() end

  local ex, ey, ez = sph(camLat, camLon)
  ex, ey, ez = ex * dist, ey * dist, ez * dist
  local fov = 42
  local focal = (vh / 2) / math.tan(fov * pi / 360)
  local epoch = nowEpoch()
  local sdec, slon = subsolar(epoch)
  local sx, sy, sz = sph(sdec, slon)

  g3d.begin(vx, vy, vw, vh, fov, 0.05, 50)
  g3d.camera(ex, ey, ez, 0, 0, 0)
  -- atmosphere glow behind the globe
  local cx, cy = g3d.project(0, 0, 0)
  local pr = focal / sqrt(dist * dist - 1)
  if cx then
    for k = 8, 1, -1 do
      gfx.color(90, 160, 255, floor(6 + (8 - k) * 3))
      gfx.circle(cx, cy, pr * (1 + k * 0.022))
    end
  end
  g3d.light(sx, sy, sz, 0.13, {255, 250, 240})
  g3d.draw(globeMesh)
  if showGrid then drawGrid(ex, ey, ez) end
  -- city markers
  projected = {}
  local inv = 1 / dist
  for i, c in ipairs(CITIES) do
    local px, py, pz = sph(c[2], c[3])
    local facing = (px * ex + py * ey + pz * ez) * inv
    if facing > inv + 0.02 then
      local day = px * sx + py * sy + pz * sz
      local col = day > 0 and {255, 90, 70} or {255, 220, 120}
      if i == selected then col = {80, 220, 255} end
      g3d.point(px * 1.006, py * 1.006, pz * 1.006, i == selected and 9 or 6, col)
      local qx, qy = g3d.project(px * 1.006, py * 1.006, pz * 1.006)
      if qx then projected[#projected + 1] = {i, qx, qy, day, facing} end
    end
  end
  -- subsolar point
  local sunx, suny
  if (sx * ex + sy * ey + sz * ez) * inv > inv then sunx, suny = g3d.project(sx * 1.01, sy * 1.01, sz * 1.01) end
  g3d.finish()

  -- atmosphere rim on top
  if cx then
    gfx.color(140, 200, 255, 70)
    gfx.circleLine(cx, cy, pr + 1, 3)
    gfx.color(170, 220, 255, 40)
    gfx.circleLine(cx, cy, pr + 4, 4)
  end
  if sunx then gfx.icon("wb_sunny", sunx, suny, 22, {255, 214, 90}) end

  -- picking
  if pickX then
    local best, bd = nil, 20
    for _, p in ipairs(projected) do
      local d = sqrt((p[2] - pickX) ^ 2 + (p[3] - pickY) ^ 2)
      if d < bd then best, bd = p[1], d end
    end
    if best then selectCity(best); store.set("city", best) end
  end

  -- labels (selected first, then greedy without overlaps)
  table.sort(projected, function(a, b)
    if (a[1] == selected) ~= (b[1] == selected) then return a[1] == selected end
    return a[5] > b[5]
  end)
  local boxes = {}
  for _, p in ipairs(projected) do
    local c = CITIES[p[1]]
    local hh, mm = localTime(c[4])
    local name = TR(c[1])
    local text = string.format("%s  %02d:%02d", name, hh, mm)
    local tw = gfx.textWidth(text, 12, "semibold") + 12
    local bx, by = p[2] + 8, p[3] - 10
    local ok = true
    for _, b in ipairs(boxes) do
      if bx < b[1] + b[3] and bx + tw > b[1] and by < b[2] + b[4] and by + 20 > b[2] then ok = false; break end
    end
    if ok and bx < vx + vw then
      boxes[#boxes + 1] = {bx, by, tw, 20}
      local sel = p[1] == selected
      gfx.color(sel and {20, 90, 140, 220} or {8, 12, 24, 170})
      gfx.rect(bx, by, tw, 20, 6)
      gfx.color(sel and "#FFFFFF" or {230, 236, 245})
      gfx.text(text, bx + 6, by + 3, 12, "semibold")
    end
  end

  -- UTC clock + sun info (top of the globe view)
  local uh, um, uy, umo, ud = localTime(0)
  gfx.color(8, 12, 24, 190)
  gfx.rect(vx + 12, 12, 196, 50, 12)
  gfx.color("#FFFFFF")
  gfx.text(string.format("UTC %02d:%02d", uh, um), vx + 24, 18, 16, "monobold")
  gfx.color(255, 255, 255, 160)
  gfx.text(TR("sun_over", string.format("%.0f°%s", abs(sdec), sdec >= 0 and TR("dir_n") or TR("dir_s")),
    string.format("%.0f°%s", abs(slon), slon >= 0 and TR("dir_e") or TR("dir_w"))), vx + 24, 40, 11)
  if timeShift ~= 0 then
    gfx.color(255, 200, 90)
    gfx.text(TR("shifted", string.format("%+.1f", timeShift)), vx + 220, 22, 12, "semibold")
  end

  -- selected city card
  do
    local c = CITIES[selected]
    local hh, mm, y, mo, d = localTime(c[4])
    local px, py, pz = sph(c[2], c[3])
    local elev = asin(clamp(px * sx + py * sy + pz * sz, -1, 1)) / rad
    local status = elev > 0.8 and TR("day") or (elev > -6 and TR("twilight") or TR("night"))
    local cw, ch = 220, 132
    local cxp, cyp = vx + vw - cw - 12, 12
    gfx.color(8, 12, 24, 200)
    gfx.rect(cxp, cyp, cw, ch, 12)
    gfx.color("#FFFFFF")
    gfx.text(TR(c[1]), cxp + 14, cyp + 10, 17, "bold")
    gfx.text(string.format("%02d:%02d", hh, mm), cxp + 14, cyp + 34, 30, "monobold")
    gfx.color(255, 255, 255, 170)
    local dateStr = sys.lang() == "tr" and string.format("%02d.%02d.%04d", d, mo, y) or string.format("%04d-%02d-%02d", y, mo, d)
    gfx.text(dateStr .. "  ·  " .. fmtOffset(c[4]), cxp + 14, cyp + 74, 12)
    gfx.icon(elev > 0.8 and "wb_sunny" or (elev > -6 and "wb_twilight" or "nightlight_round"), cxp + 24, cyp + 108, 18,
      elev > 0.8 and {255, 214, 90} or {170, 190, 255})
    gfx.color("#FFFFFF")
    gfx.text(TR("sun_elev", status, string.format("%.0f", elev)), cxp + 40, cyp + 99, 12, "semibold")
  end

  -- city list
  gfx.color(theme.dark and "#16181E" or "#F3F4F7")
  gfx.rect(0, 0, LIST_W, h)
  gfx.color(theme.separator)
  gfx.rect(LIST_W - 1, 0, 1, h)
  gfx.color(theme.text)
  gfx.text(TR("cities"), 16, 14, 17, "bold")
  local rowH = 34
  ui.beginScroll("cities", 0, 44, LIST_W - 1, h - 44, #CITIES * rowH + 8)
  for i, c in ipairs(CITIES) do
    local y = 4 + (i - 1) * rowH
    if ui.row("city" .. i, 6, y, LIST_W - 13, rowH - 2, i == selected) then selectCity(i); store.set("city", i) end
    local hh, mm = localTime(c[4])
    local px, py, pz = sph(c[2], c[3])
    local isDay = px * sx + py * sy + pz * sz > 0
    gfx.icon(isDay and "wb_sunny" or "nightlight_round", 22, y + rowH / 2 - 1, 15, isDay and {240, 170, 40} or {120, 140, 220})
    gfx.color(i == selected and "#FFFFFF" or theme.text)
    gfx.text(TR(c[1]), 36, y + 8, 13, "semibold")
    gfx.color(i == selected and "#FFFFFFCC" or theme.text2)
    gfx.text(string.format("%02d:%02d", hh, mm), 0, y + 8, 13, "mono", "right", LIST_W - 20)
  end
  ui.endScroll()

  -- bottom bar
  local by = h - BAR_H
  gfx.color(theme.dark and "#1B1E25" or "#FFFFFF")
  gfx.rect(LIST_W, by, w - LIST_W, BAR_H)
  gfx.color(theme.separator)
  gfx.rect(LIST_W, by, w - LIST_W, 1)
  local x = LIST_W + 12
  if ui.iconButton("sync", x, by + 11, 36, 36, nil, autoRotate) then autoRotate = not autoRotate; store.set("auto", autoRotate) end
  if ui.iconButton("grid_on", x + 42, by + 11, 36, 36, nil, showGrid) then showGrid = not showGrid; store.set("grid", showGrid) end
  if ui.iconButton("screen_rotation", x + 84, by + 11, 36, 36, nil, gyroOn) then
    gyroOn = not gyroOn; store.set("gyro", gyroOn); tilt0x, tilt0y = readTilt()
  end
  x = x + 134
  gfx.color(theme.separator)
  gfx.rect(x - 6, by + 14, 1, 30)
  gfx.color(theme.text)
  gfx.text(TR("time_shift"), x + 4, by + 20, 13)
  x = x + gfx.textWidth(TR("time_shift"), 13) + 14
  local sw = max(60, w - x - 120)
  local nt = ui.slider("shift", timeShift, -12, 12, x, by + 16, sw, 0.5)
  if nt ~= timeShift then timeShift = nt end
  gfx.color(theme.text2)
  gfx.text(TR("hours_n", string.format("%+.1f", timeShift)), x + sw + 8, by + 20, 12, "mono")
  if ui.iconButton("restore", w - 50, by + 11, 36, 36, nil) then timeShift = 0 end
end

function app.event(e)
  if e.type == "keydown" then
    if e.key == "left" or e.key == "right" or e.key == "up" or e.key == "down" then held[e.key] = true
    elseif e.key == "space" then autoRotate = not autoRotate; store.set("auto", autoRotate)
    elseif e.key == "g" then showGrid = not showGrid; store.set("grid", showGrid)
    elseif e.key == "n" or e.key == "tab" then selectCity(selected % #CITIES + 1); store.set("city", selected)
    elseif e.key == "pageup" then wantDist = wantDist * 0.85
    elseif e.key == "pagedown" then wantDist = wantDist * 1.18
    elseif e.key == "escape" then timeShift = 0
    end
  elseif e.type == "keyup" then
    held[e.key] = nil
  elseif e.type == "scroll" then
    if (e.x or 0) > LIST_W then wantDist = wantDist * exp(-e.dy * 0.003) end
  elseif e.type == "paddown" then
    if e.pad == "r" then selectCity(selected % #CITIES + 1); store.set("city", selected)
    elseif e.pad == "l" then selectCity((selected - 2) % #CITIES + 1); store.set("city", selected)
    elseif e.pad == "a" then selectCity(selected)
    elseif e.pad == "y" then autoRotate = not autoRotate; store.set("auto", autoRotate)
    elseif e.pad == "x" then showGrid = not showGrid; store.set("grid", showGrid)
    elseif e.pad == "minus" then gyroOn = not gyroOn; store.set("gyro", gyroOn); tilt0x, tilt0y = readTilt()
    elseif e.pad == "right" then timeShift = min(12, timeShift + 1)
    elseif e.pad == "left" then timeShift = max(-12, timeShift - 1)
    elseif e.pad == "b" then timeShift = 0
    end
  end
end

function app.menu()
  return {{title = TR("view"), items = {
    {label = TR("next_city"), id = 1, shortcut = "Tab"},
    {label = TR("toggle_spin"), id = 2, shortcut = "Space"},
    {label = TR("toggle_grid"), id = 3, shortcut = "G"},
    {label = TR("toggle_gyro"), id = 4},
    "-",
    {label = TR("reset_time"), id = 5, shortcut = "Esc"},
  }}}
end

function app.onmenu(id)
  if id == 1 then selectCity(selected % #CITIES + 1); store.set("city", selected)
  elseif id == 2 then autoRotate = not autoRotate; store.set("auto", autoRotate)
  elseif id == 3 then showGrid = not showGrid; store.set("grid", showGrid)
  elseif id == 4 then gyroOn = not gyroOn; store.set("gyro", gyroOn); tilt0x, tilt0y = readTilt()
  elseif id == 5 then timeShift = 0
  end
end

return app
