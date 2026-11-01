-- track.lua: the three island circuits of Turbo Isles. A track is a closed Catmull-Rom spline through control
-- points, resampled every STEP units; the road, kerbs, barriers, verges, scenery and boost pads are built into chunk
-- meshes once and drawn only near the camera.
local B = require("b3d")
local T = {}

local sqrt, sin, cos, atan, floor, min, max, abs, pi = math.sqrt, math.sin, math.cos, math.atan, math.floor, math.min,
  math.max, math.abs, math.pi
local STEP = 2.0
local CHUNK = 24
T.STEP = STEP

T.THEMES = {
  bay = {sky1 = "#3E8EDB", sky2 = "#BFE6FF", fog = "#BFE6FF", fogNear = 140, fogFar = 520, water = "#1FA3C9",
         road = {"#4A4E5C", "#464A57"}, line = "#F2F2F2", kerb = {"#E8343F", "#F5F5F5"}, verge = {"#E9D7A4", "#E1CC94"},
         slope = {"#7DC46A", "#6DB75C"}, wall = "#F5F5F5", wall2 = "#2C7BE5", sun = {0.35, 0.9, 0.25}, amb = 0.5,
         isle = {"#3D8F7A", "#4FA88A"}, sunCol = "#FFF6D8"},
  harbor = {sky1 = "#0B0A24", sky2 = "#3B1E5C", fog = "#2A1B4A", fogNear = 90, fogFar = 420, water = "#141C3A",
            road = {"#2B2D3A", "#282A36"}, line = "#FFD23F", kerb = {"#FF2E97", "#2B2D3A"}, verge = {"#30344A", "#2C3044"},
            slope = {"#262A3E", "#22263A"}, wall = "#3A3F5A", wall2 = "#00E5FF", sun = {-0.3, 0.8, 0.4}, amb = 0.42,
            isle = {"#1A1838", "#231F48"}, sunCol = "#FFE9F5", night = true},
  ridge = {sky1 = "#4B2A6E", sky2 = "#FF9A5A", fog = "#F7A06A", fogNear = 120, fogFar = 480, water = "#C9774A",
           road = {"#55484A", "#504345"}, line = "#FFE7C2", kerb = {"#FF7A1A", "#FFF1D6"}, verge = {"#D98A54", "#CF8250"},
           slope = {"#B8613A", "#AD5934"}, wall = "#FFE7C2", wall2 = "#B23A2A", sun = {0.6, 0.45, -0.3}, amb = 0.48,
           isle = {"#8A3B3B", "#A24A40"}, sunCol = "#FFD08A"},
}

-- control points {x, z, height}; scaled by 1.7 below
T.TRACKS = {
  {key = "bay", theme = "bay", w = 18, pts = {
    {0, 0, 0}, {0, -110, 2}, {18, -195, 6}, {85, -240, 9}, {165, -225, 7}, {212, -160, 3}, {196, -80, 0},
    {236, -10, 2}, {226, 75, 7}, {160, 122, 5}, {88, 96, 1}, {42, 58, 0}}},
  {key = "harbor", theme = "harbor", w = 16, pts = {
    {0, 0, 0}, {0, -96, 0}, {52, -140, 3}, {136, -146, 9}, {184, -96, 12}, {150, -42, 10}, {104, -16, 6},
    {118, 42, 2}, {198, 58, 0}, {232, 136, 0}, {164, 192, 0}, {66, 176, 2}, {18, 116, 1}, {-16, 58, 0}}},
  {key = "ridge", theme = "ridge", w = 17, pts = {
    {0, 0, 0}, {-10, -88, 9}, {28, -168, 22}, {108, -204, 31}, {190, -166, 25}, {204, -84, 12}, {262, -40, 6},
    {302, 40, 15}, {252, 122, 23}, {172, 132, 16}, {112, 84, 8}, {62, 112, 3}, {12, 70, 0}}},
}

local function catmull(p0, p1, p2, p3, t)
  local t2, t3 = t * t, t * t * t
  return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

-- deterministic random numbers for scenery
local function rng(seed)
  local s = seed
  return function(a, b)
    s = (s * 1103515245 + 12345) % 2147483648
    local r = s / 2147483648
    if a then return a + (b - a) * r end
    return r
  end
end

-- samples of the centre line
local function sample(def, mirror)
  local P = {}
  for i, p in ipairs(def.pts) do
    P[i] = {(mirror and -p[1] or p[1]) * 1.7, p[3] * 1.0, p[2] * 1.7}
  end
  local n = #P
  local dense = {}
  for i = 1, n do
    local p0, p1, p2, p3 = P[(i - 2) % n + 1], P[i], P[i % n + 1], P[(i + 1) % n + 1]
    for k = 0, 59 do
      local t = k / 60
      dense[#dense + 1] = {catmull(p0[1], p1[1], p2[1], p3[1], t), catmull(p0[2], p1[2], p2[2], p3[2], t),
                           catmull(p0[3], p1[3], p2[3], p3[3], t)}
    end
  end
  -- resample at equal distances
  local out = {}
  local acc = 0
  local m = #dense
  out[1] = dense[1]
  local need = STEP
  for i = 1, m do
    local a, b = dense[i], dense[i % m + 1]
    local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
    local d = sqrt(dx * dx + dz * dz)
    local pos = 0
    while acc + (d - pos) >= need do
      local f = (pos + (need - acc)) / d
      out[#out + 1] = {a[1] + dx * f, a[2] + dy * f, a[3] + dz * f}
      pos = pos + (need - acc)
      acc = 0
    end
    acc = acc + (d - pos)
  end
  if #out > 2 then
    local a, b = out[#out], out[1]
    if (a[1] - b[1]) ^ 2 + (a[3] - b[3]) ^ 2 < (STEP * 0.5) ^ 2 then out[#out] = nil end
  end
  return out
end

function T.build(index, mirror)
  local def = T.TRACKS[index]
  local th = T.THEMES[def.theme]
  local S = sample(def, mirror)
  local N = #S
  local tr = {def = def, th = th, N = N, mirror = mirror, w = def.w, px = {}, py = {}, pz = {}, fx = {}, fz = {},
              rx = {}, rz = {}, cur = {}, line = {}, chunks = {}, pads = {}, len = N * STEP}
  for i = 0, N - 1 do
    local p = S[i + 1]
    tr.px[i], tr.py[i], tr.pz[i] = p[1], p[2], p[3]
  end
  local cx, cz, minx, maxx, minz, maxz = 0, 0, 1e9, -1e9, 1e9, -1e9
  for i = 0, N - 1 do
    local a, b = (i - 1) % N, (i + 1) % N
    local dx, dz = tr.px[b] - tr.px[a], tr.pz[b] - tr.pz[a]
    local d = sqrt(dx * dx + dz * dz)
    tr.fx[i], tr.fz[i] = dx / d, dz / d
    tr.rx[i], tr.rz[i] = -tr.fz[i], tr.fx[i]
    cx, cz = cx + tr.px[i], cz + tr.pz[i]
    minx, maxx, minz, maxz = min(minx, tr.px[i]), max(maxx, tr.px[i]), min(minz, tr.pz[i]), max(maxz, tr.pz[i])
  end
  tr.cx, tr.cz = cx / N, cz / N
  tr.minx, tr.maxx, tr.minz, tr.maxz = minx, maxx, minz, maxz
  -- signed curvature (heading change per sample), smoothed; positive = turning right
  for i = 0, N - 1 do
    local a, b = (i - 2) % N, (i + 2) % N
    local h1 = atan(tr.fz[a], tr.fx[a])
    local h2 = atan(tr.fz[b], tr.fx[b])
    local d = (h2 - h1 + pi) % (2 * pi) - pi
    tr.cur[i] = d / 4
  end
  -- racing line: hug the inside of corners ahead
  local raw = {}
  for i = 0, N - 1 do
    local c = 0
    for k = -6, 10 do c = c + tr.cur[(i + k) % N] end
    raw[i] = max(-1, min(1, c * 6))
  end
  for i = 0, N - 1 do
    local s = 0
    for k = -8, 8 do s = s + raw[(i + k) % N] end
    tr.line[i] = (s / 17) * def.w * 0.32
  end
  -- boost pads on the three longest straight runs
  local runs, cur = {}, nil
  for i = 0, N - 1 do
    if abs(tr.cur[i]) < 0.004 then
      if not cur then cur = {a = i, n = 0} end
      cur.n = cur.n + 1
    elseif cur then runs[#runs + 1] = cur; cur = nil end
  end
  if cur then runs[#runs + 1] = cur end
  table.sort(runs, function(a, b) return a.n > b.n end)
  for k = 1, min(3, #runs) do
    local r = runs[k]
    if r.n > 14 and r.a > 20 then
      tr.pads[#tr.pads + 1] = {i = (r.a + floor(r.n * 0.4)) % N, off = (k % 2 == 0 and 1 or -1) * def.w * 0.18}
    end
  end
  T.mesh(tr)
  return tr
end

-- local position along the track: index, lateral offset (right = positive), fraction to the next sample
function T.locate(tr, x, z, hint)
  local N = tr.N
  local best, bd = hint or 0, 1e18
  local from, to = -12, 12
  if not hint then from, to = 0, N - 1 end
  for k = from, to do
    local i = hint and (hint + k) % N or k
    local dx, dz = x - tr.px[i], z - tr.pz[i]
    local d = dx * dx + dz * dz
    if d < bd then bd, best = d, i end
  end
  local i = best
  local dx, dz = x - tr.px[i], z - tr.pz[i]
  local along = dx * tr.fx[i] + dz * tr.fz[i]
  if along < 0 then
    i = (i - 1) % N
    dx, dz = x - tr.px[i], z - tr.pz[i]
    along = dx * tr.fx[i] + dz * tr.fz[i]
  end
  local f = max(0, min(1, along / STEP))
  local lat = dx * tr.rx[i] + dz * tr.rz[i]
  local j = (i + 1) % N
  local y = tr.py[i] + (tr.py[j] - tr.py[i]) * f
  return i, lat, f, y
end

-- world point at sample i, lateral offset lat
function T.point(tr, i, lat, up)
  i = i % tr.N
  return tr.px[i] + tr.rx[i] * lat, tr.py[i] + (up or 0), tr.pz[i] + tr.rz[i] * lat
end

-- ---------------------------------------------------------------- meshes
local function P(tr, i, lat, dy) local x, y, z = T.point(tr, i, lat, dy) return {x, y, z} end

local function palm(b, x, y, z, r, s, th)
  local lean = (r() - 0.5) * 2.2
  b:column(x, y, z, 0.5 * s, y + 8 * s, 0.32 * s, 5, "#8A6A45", nil, lean)
  local tx, ty = x + lean, y + 8 * s
  for k = 0, 6 do
    local a = k / 7 * 2 * pi + r() * 0.4
    local lx, lz = cos(a) * 4.2 * s, sin(a) * 4.2 * s
    local wx, wz = -sin(a) * 1.0 * s, cos(a) * 1.0 * s
    b:quad2({tx, ty, z}, {tx + lx * 0.5 + wx, ty + 0.5 * s, z + lz * 0.5 + wz}, {tx + lx, ty - 1.6 * s, z + lz},
            {tx + lx * 0.5 - wx, ty + 0.5 * s, z + lz * 0.5 - wz}, k % 2 == 0 and "#2FA35A" or "#3DBA6A")
  end
  b:cone(tx, ty - 0.6 * s, z, 0.7 * s, ty + 0.3 * s, 5, "#6B4E2E")
end
local function rock(b, x, y, z, r, s, col)
  b:cone(x, y - 0.5, z, 2.4 * s, y + (1.6 + r() * 1.6) * s, 5, col, r() * 6)
end
local function hut(b, x, y, z, r, s, yaw)
  b:box(x, y + 1.6 * s, z, 2.2 * s, 1.6 * s, 2.0 * s, yaw, "#F2E2C0", "#E8D2A8")
  b:cone(x, y + 3.2 * s, z, 3.4 * s, y + 5.4 * s, 4, "#C9894A", yaw + pi / 4)
end
local function umbrella(b, x, y, z, r, s)
  b:column(x, y, z, 0.12, y + 3.0 * s, 0.12, 4, "#FFFFFF")
  b:cone(x, y + 2.6 * s, z, 2.6 * s, y + 3.6 * s, 8, r() < 0.5 and "#FF5A5F" or "#FFC93C")
end
local function tower(b, g, x, y, z, r, s, yaw)
  local h = (10 + r() * 22) * s
  local wcol = {"#2A2E48", "#30355A", "#262A44"}
  local c = wcol[floor(r() * 3) + 1]
  b:box(x, y + h / 2 - 1, z, 4.5 * s, h / 2, 4.5 * s, yaw, "#1C1F33", c)
  -- lit windows: rows of bright quads on two faces
  local cs, sn = cos(yaw), sin(yaw)
  for k = 1, floor(h / 3) - 1 do
    if r() < 0.75 then
      local wy = y + k * 3
      local col = r() < 0.3 and "#7FF7FF" or (r() < 0.5 and "#FFB3E6" or "#FFE7A3")
      for side = -1, 1, 2 do
        local fx, fz = side * 4.6 * s * cs, -side * 4.6 * s * sn
        local ax, az = 3.4 * s * sn, 3.4 * s * cs
        g:quad2({x + fx - ax, wy, z + fz - az}, {x + fx + ax, wy, z + fz + az}, {x + fx + ax, wy + 1.2, z + fz + az},
                {x + fx - ax, wy + 1.2, z + fz - az}, col)
      end
    end
  end
  if r() < 0.5 then g:box(x, y + h, z, 0.25, 1.5, 0.25, 0, "#FF2E97", "#FF2E97") end
end
local function lamp(b, g, x, y, z, s)
  b:column(x, y, z, 0.18, y + 7 * s, 0.14, 4, "#5A6078")
  g:box(x, y + 7 * s, z, 0.7, 0.3, 0.7, 0, "#FFE7A3", "#FFE7A3")
end
local function mesa(b, x, y, z, r, s, th)
  local h = (6 + r() * 16) * s
  b:column(x, y - 1, z, (5 + r() * 4) * s, y + h, (3 + r() * 2) * s, 6, "#B5533A", "#D9784A", 0)
  b:column(x, y + h, z, (3.2) * s, y + h + 1.2 * s, 3.6 * s, 6, "#C9663F", "#E08A55", 0)
end
local function cactus(b, x, y, z, r, s)
  b:column(x, y, z, 0.45 * s, y + 4.5 * s, 0.4 * s, 6, "#3F8A4A", "#4FA05A")
  b:column(x + 0.9 * s, y + 2 * s, z, 0.3 * s, y + 3.6 * s, 0.28 * s, 5, "#3F8A4A", "#4FA05A")
end

function T.mesh(tr)
  local th, N, w = tr.th, tr.N, tr.w
  local hw = w / 2
  local r = rng(1234 + tr.def.w * 7 + (tr.mirror and 99 or 0))
  local kind = tr.def.theme
  local padAt = {}
  for _, p in ipairs(tr.pads) do
    for k = 0, 3 do padAt[(p.i + k) % N] = p end
  end
  local nChunks = (N + CHUNK - 1) // CHUNK
  for c = 0, nChunks - 1 do
    local b, g = B.new(), B.new()
    local first = c * CHUNK
    local last = min(N, first + CHUNK)
    for i = first, last - 1 do
      local j = (i + 1) % N
      local stripe = (i // 3) % 2 + 1
      local curv = abs(tr.cur[i]) > 0.012
      -- road
      b:quad(P(tr, i, -hw, 0), P(tr, j, -hw, 0), P(tr, j, hw, 0), P(tr, i, hw, 0), th.road[stripe], 0, 1, 0)
      -- centre dashes, start line
      if i < 2 then
        for q = 0, 5 do
          local l0, l1 = -hw + q * w / 6, -hw + (q + 1) * w / 6
          local col = ((q + i) % 2 == 0) and "#FFFFFF" or "#1A1A1A"
          b:quad(P(tr, i, l0, 0.04), P(tr, j, l0, 0.04), P(tr, j, l1, 0.04), P(tr, i, l1, 0.04), col, 0, 1, 0)
        end
      elseif i % 6 < 3 then
        b:quad(P(tr, i, -0.25, 0.03), P(tr, j, -0.25, 0.03), P(tr, j, 0.25, 0.03), P(tr, i, 0.25, 0.03), th.line, 0, 1, 0)
      end
      for side = -1, 1, 2 do
        local s = side
        -- kerbs on corners, a painted edge on straights
        local e0, e1 = hw, hw + (curv and 1.5 or 0.5)
        local kc = curv and th.kerb[(i % 2) + 1] or th.line
        b:quad(P(tr, i, s * e0, 0.06), P(tr, j, s * e0, 0.06), P(tr, j, s * e1, 0.06), P(tr, i, s * e1, 0.06), kc, 0, 1, 0)
        if not curv then
          b:quad(P(tr, i, s * e1, 0.0), P(tr, j, s * e1, 0.0), P(tr, j, s * (hw + 1.5), 0.0), P(tr, i, s * (hw + 1.5), 0.0), th.road[stripe], 0, 1, 0)
        end
        -- verge
        local v0, v1 = hw + 1.5, hw + 6
        b:quad(P(tr, i, s * v0, -0.05), P(tr, j, s * v0, -0.05), P(tr, j, s * v1, -0.15), P(tr, i, s * v1, -0.15), th.verge[stripe], 0, 1, 0)
        -- barrier: an inner face, a top and an outer face
        local b0, b1 = hw + 6, hw + 6.6
        local wc = (i // 2) % 2 == 0 and th.wall or th.wall2
        local ix, iz = -tr.rx[i] * s, -tr.rz[i] * s
        b:quad(P(tr, i, s * b0, -0.15), P(tr, j, s * b0, -0.15), P(tr, j, s * b0, 1.1), P(tr, i, s * b0, 1.1), wc, ix, 0, iz)
        b:quad(P(tr, i, s * b0, 1.1), P(tr, j, s * b0, 1.1), P(tr, j, s * b1, 1.1), P(tr, i, s * b1, 1.1), th.wall, 0, 1, 0)
        if th.night then
          g:quad2(P(tr, i, s * (b0 - 0.02), 0.9), P(tr, j, s * (b0 - 0.02), 0.9), P(tr, j, s * (b0 - 0.02), 1.05),
                  P(tr, i, s * (b0 - 0.02), 1.05), s < 0 and "#00B8D9" or "#D92E8A")
        end
        -- outer slope down to the sea / desert floor
        local o0, o1 = b1, hw + 34
        local yi, yj = tr.py[i], tr.py[j]
        local drop = -3.5
        b:quad(P(tr, i, s * o0, -0.15), P(tr, j, s * o0, -0.15), {T.point(tr, j, s * o1, drop - yj)},
               {T.point(tr, i, s * o1, drop - yi)}, th.slope[stripe], 0, 1, 0)
      end
      -- boost pads (glowing chevrons)
      local pad = padAt[i]
      if pad then
        local o = pad.off
        b:quad(P(tr, i, o - 2.6, 0.05), P(tr, j, o - 2.6, 0.05), P(tr, j, o + 2.6, 0.05), P(tr, i, o + 2.6, 0.05), "#1B2A4A", 0, 1, 0)
        local a, mid = P(tr, i, o - 2.0, 0.09), P(tr, j, o, 0.09)
        local b2 = P(tr, i, o + 2.0, 0.09)
        g:tri(a[1], a[2], a[3], mid[1], mid[2], mid[3], b2[1], b2[2], b2[3], "#FFB000", 0, 1, 0)
      end
      -- scenery every few samples on both sides
      if i % 5 == 0 then
        for side = -1, 1, 2 do
          if r() < 0.85 then
            local off = side * (hw + 9 + r() * 18)
            local x, y, z = T.point(tr, i, off, 0)
            y = tr.py[i] - 0.15 - (abs(off) - hw - 6.6) / (34 - 6.6) * (tr.py[i] + 3.5)
            local s = 0.8 + r() * 0.6
            if kind == "bay" then
              local roll = r()
              if roll < 0.55 then palm(b, x, y, z, r, s, th)
              elseif roll < 0.75 then umbrella(b, x, y, z, r, s)
              elseif roll < 0.88 then hut(b, x, y, z, r, s, r() * pi)
              else rock(b, x, y, z, r, s, "#8E8A80") end
            elseif kind == "harbor" then
              if r() < 0.6 then tower(b, g, x + side * 6, y, z, r, s, atan(tr.fz[i], tr.fx[i]))
              else lamp(b, g, x, y, z, s) end
            else
              local roll = r()
              if roll < 0.45 then mesa(b, x + side * 6, y, z, r, s, th)
              elseif roll < 0.8 then cactus(b, x, y, z, r, s)
              else rock(b, x, y, z, r, s, "#9A4A34") end
            end
          end
        end
      end
    end
    -- start gantry
    if first == 0 then
      local a1 = P(tr, 0, -hw - 6.3, 0)
      local a2 = P(tr, 0, hw + 6.3, 0)
      b:column(a1[1], a1[2], a1[3], 0.5, a1[2] + 9, 0.5, 6, "#D0D4DE")
      b:column(a2[1], a2[2], a2[3], 0.5, a2[2] + 9, 0.5, 6, "#D0D4DE")
      local yaw = atan(tr.fz[0], tr.fx[0])
      local mx, my, mz = (a1[1] + a2[1]) / 2, a1[2] + 8.4, (a1[3] + a2[3]) / 2
      b:box(mx, my, mz, 0.6, 1.2, hw + 6.6, -yaw, "#1A1A22", "#1A1A22", "#1A1A22", "#1A1A22")
      for k = -5, 4 do
        local lx, lz = tr.rx[0] * (k + 0.5) * 2.2, tr.rz[0] * (k + 0.5) * 2.2
        g:box(mx + lx - tr.fx[0] * 0.65, my, mz + lz - tr.fz[0] * 0.65, 0.05, 0.9, 0.9, -yaw, (k % 2 == 0) and "#FFFFFF" or "#FF2E4F",
              (k % 2 == 0) and "#FFFFFF" or "#FF2E4F")
      end
    end
    local mx, mz = tr.px[first + (last - first) // 2], tr.pz[first + (last - first) // 2]
    tr.chunks[#tr.chunks + 1] = {mesh = b:mesh(), glow = g:mesh(), first = first, last = last - 1, x = mx, z = mz,
                                 tris = b:count() + g:count()}
  end
  -- sea / desert floor
  tr.water = g3d.mesh("plane", 4000, 4000, 1)
  tr.water:setColor(th.water)
  -- far islands / mesas (2D silhouettes projected at a large radius)
  tr.isles = {}
  for k = 1, 14 do
    tr.isles[k] = {az = k / 14 * 2 * pi + r() * 0.3, w = 0.06 + r() * 0.1, h = 0.03 + r() * 0.06,
                   col = th.isle[k % 2 + 1]}
  end
end

return T
