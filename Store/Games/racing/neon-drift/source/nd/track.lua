-- Neon Drift: the three circuits. A closed spline is sampled every DS metres; the road, barriers, sidewalks, tunnel,
-- gantries and kit-bashed scenery are generated from it into chunks (for culling) at load time.
local Geo = require("nd.geo")
local T = {}
local DS = 2.0
local CHUNK = 40
T.DS = DS

local NEON = {pink = "#FF2E88", cyan = "#19E6FF", violet = "#8A5BFF", amber = "#FFB13B", white = "#E8F0FF",
              red = "#FF2A3A", lime = "#B8FF3C"}
T.NEON = NEON

-- control points: x, z, y (height)
T.defs = {
  {id = "downtown", key = "track_downtown", width = 14, theme = "city", sky = "#120A26", fog = {"#1C0E36", 40, 330},
   moon = "#8FA6FF", pts = {{0, 0, 0}, {0, -260, 0}, {30, -330, 1}, {160, -350, 3}, {250, -300, 3}, {270, -180, 1},
   {380, -140, 0}, {470, -60, 0}, {460, 60, 2}, {360, 110, 4}, {220, 90, 3}, {150, 170, 1}, {40, 180, 0}, {-20, 120, 0}},
   neonL = "pink", neonR = "cyan", rain = 1.0},
  {id = "harbor", key = "track_harbor", width = 15, theme = "harbor", sky = "#0A0E22", fog = {"#101633", 50, 420},
   moon = "#9FC0FF", pts = {{0, 0, 0}, {0, -170, 0}, {0, -340, 0}, {0, -500, 0}, {-20, -585, 1}, {-70, -620, 2},
   {-120, -595, 2}, {-135, -520, 1}, {-130, -420, 0}, {-150, -330, 0}, {-115, -250, 0}, {-150, -160, 0},
   {-240, -100, 1}, {-265, 10, 1}, {-200, 95, 0}, {-100, 110, 0}, {-25, 70, 0}},
   neonL = "amber", neonR = "violet", rain = 0.7, water = true},
  {id = "express", key = "track_express", width = 18, theme = "express", sky = "#140822", fog = {"#200C30", 60, 520},
   moon = "#B08CFF", pts = {{0, 0, 0}, {60, -300, 2}, {220, -480, 9}, {450, -520, 14}, {640, -420, 12}, {700, -200, 6},
   {620, 20, 0}, {450, 120, -1}, {300, 60, 0}, {180, 180, 4}, {40, 220, 3}, {-40, 140, 0}},
   tunnel = {0.70, 0.86}, neonL = "violet", neonR = "pink", rain = 0.5},
}

local function cr(a, b, c, d, t)
  local t2, t3 = t * t, t * t * t
  return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
end

local function wrap(i, n) return (i - 1) % n + 1 end
T.wrap = wrap
-- loading runs in a coroutine: give the frame back now and then
local function Y() if coroutine.isyieldable() then coroutine.yield() end end
T.yield = Y

-- sample the closed spline every DS metres
function T.sample(def)
  local P = def.pts
  local n = #P
  local dense = {}
  for i = 1, n do
    local a, b, c, d = P[wrap(i - 1, n)], P[i], P[wrap(i + 1, n)], P[wrap(i + 2, n)]
    for s = 0, 79 do
      local t = s / 80
      dense[#dense + 1] = {cr(a[1], b[1], c[1], d[1], t), cr(a[2], b[2], c[2], d[2], t), cr(a[3], b[3], c[3], d[3], t)}
    end
  end
  local acc = {0}
  for i = 2, #dense + 1 do
    local p, q = dense[i - 1], dense[wrap(i, #dense)]
    acc[i] = acc[i - 1] + math.sqrt((q[1] - p[1]) ^ 2 + (q[2] - p[2]) ^ 2)
  end
  local L = acc[#dense + 1]
  local N = math.floor(L / DS)
  local ds = L / N
  local tr = {N = N, L = L, ds = ds, x = {}, y = {}, z = {}, tx = {}, tz = {}, curv = {}, def = def, w = def.width}
  local j = 1
  for i = 1, N do
    local s = (i - 1) * ds
    while acc[j + 1] < s do j = j + 1 end
    local p, q = dense[j], dense[wrap(j + 1, #dense)]
    local f = (s - acc[j]) / math.max(1e-6, acc[j + 1] - acc[j])
    tr.x[i] = p[1] + (q[1] - p[1]) * f
    tr.z[i] = p[2] + (q[2] - p[2]) * f
    tr.y[i] = p[3] + (q[3] - p[3]) * f
  end
  for i = 1, N do
    local a, b = wrap(i - 1, N), wrap(i + 1, N)
    local dx, dz = tr.x[b] - tr.x[a], tr.z[b] - tr.z[a]
    local l = math.sqrt(dx * dx + dz * dz)
    tr.tx[i], tr.tz[i] = dx / l, dz / l
  end
  for i = 1, N do
    local a, b = wrap(i - 2, N), wrap(i + 2, N)
    local h1 = math.atan(tr.tz[a], tr.tx[a])
    local h2 = math.atan(tr.tz[b], tr.tx[b])
    local d = (h2 - h1 + math.pi) % (2 * math.pi) - math.pi
    tr.curv[i] = d / (4 * ds)  -- signed: positive turns right (towards +right vector)
  end
  -- spatial hash of samples (40 m cells) for "is this spot on/near the road" queries
  tr.grid = {}
  for i = 1, N do
    local k = math.floor(tr.x[i] / 40) .. ":" .. math.floor(tr.z[i] / 40)
    local c = tr.grid[k]
    if not c then c = {}; tr.grid[k] = c end
    c[#c + 1] = i
  end
  return tr
end

-- distance from (x, z) to the nearest road sample
function T.roadDist(tr, x, z, reach)
  local best = 1e9
  local cx, cz = math.floor(x / 40), math.floor(z / 40)
  local r = math.ceil((reach or 40) / 40)
  for gx = cx - r, cx + r do
    for gz = cz - r, cz + r do
      local c = tr.grid[gx .. ":" .. gz]
      if c then
        for _, i in ipairs(c) do
          local d = (tr.x[i] - x) ^ 2 + (tr.z[i] - z) ^ 2
          if d < best then best = d end
        end
      end
    end
  end
  return math.sqrt(best)
end

-- position on the track near sample hint: idx, along (m past sample), lateral (m, + = right), s (m from start)
function T.locate(tr, x, z, hint)
  local N = tr.N
  local bi, bd = hint or 1, 1e18
  if hint then
    for k = -18, 18 do
      local i = wrap(hint + k, N)
      local d = (tr.x[i] - x) ^ 2 + (tr.z[i] - z) ^ 2
      if d < bd then bd, bi = d, i end
    end
  end
  if bd > 30 * 30 then
    for i = 1, N, 2 do
      local d = (tr.x[i] - x) ^ 2 + (tr.z[i] - z) ^ 2
      if d < bd then bd, bi = d, i end
    end
  end
  local dx, dz = x - tr.x[bi], z - tr.z[bi]
  local along = dx * tr.tx[bi] + dz * tr.tz[bi]
  local lat = dx * -tr.tz[bi] + dz * tr.tx[bi]
  local s = (bi - 1) * tr.ds + along
  if s < 0 then s = s + tr.L end
  return bi, along, lat, s
end

-- point on the centre line at distance s, plus lateral offset
function T.at(tr, s, lat)
  s = s % tr.L
  local f = s / tr.ds
  local i = math.floor(f) + 1
  local k = f - (i - 1)
  local j = wrap(i + 1, tr.N)
  local x = tr.x[i] + (tr.x[j] - tr.x[i]) * k
  local z = tr.z[i] + (tr.z[j] - tr.z[i]) * k
  local y = tr.y[i] + (tr.y[j] - tr.y[i]) * k
  local tx = tr.tx[i] + (tr.tx[j] - tr.tx[i]) * k
  local tz = tr.tz[i] + (tr.tz[j] - tr.tz[i]) * k
  local l = math.sqrt(tx * tx + tz * tz)
  tx, tz = tx / l, tz / l
  lat = lat or 0
  return x - tz * lat, y, z + tx * lat, tx, tz, i
end

function T.heightAt(tr, i, along)
  local j = wrap(i + 1, tr.N)
  local i0 = i
  if along < 0 then j = i; i0 = wrap(i - 1, tr.N); along = along + tr.ds end
  return tr.y[i0] + (tr.y[j] - tr.y[i0]) * math.max(0, math.min(1, along / tr.ds))
end

function T.inTunnel(tr, i)
  local tn = tr.def.tunnel
  if not tn then return false end
  local f = (i - 1) / tr.N
  return f >= tn[1] and f <= tn[2]
end

---------------------------------------------------------------------------------------------- build
local function hash(i)
  local x = math.sin(i * 12.9898 + 78.233) * 43758.5453
  return x - math.floor(x)
end

local SIGN_RECTS = {}
for k = 0, 11 do
  local cx, cy = (k % 2) * 0.5, math.floor(k / 2) / 6
  SIGN_RECTS[k + 1] = {cx, cy, cx + 0.5, cy + 1 / 6}
end
T.SIGN_COLORS = {"#FF3C96", "#3CE6FF", "#FFBE3C", "#965AFF", "#FF5050", "#FF3CC8", "#50A0FF", "#78FFC8", "#FF783C",
                 "#FF4678", "#FFD250", "#5ADCFF"}

-- shoulder width per side (sidewalk / apron), metres beyond the barrier
local function shoulders(tr, i)
  local th = tr.def.theme
  if th == "city" then return 5, 5 end
  if th == "harbor" then
    local f = (i - 1) / tr.N
    if f < 0.27 then return 26, 0 end  -- the long quay: water right up to the barrier on the right
    return 18, 18
  end
  return 1.5, 1.5
end

-- pieces: {name = {w, h, d}} from the pack manifest; models are drawn by world.lua
function T.build(tr, pieces)
  local N, w = tr.N, tr.w
  local hw = w / 2
  local bar = hw + 0.5
  local chunks = {}
  tr.chunks = chunks
  tr.walls = {}          -- phys triangles
  tr.lights = {}         -- point light candidates {x, y, z, color, idx}
  tr.streaks = {}        -- road reflection sources {x, z, color, h, idx}
  tr.inst = {}           -- per chunk: name -> flat transform list
  tr.lamps = {}          -- start gantry lamps
  local th = tr.def.theme
  local nL, nR = NEON[tr.def.neonL], NEON[tr.def.neonR]
  local nch = math.ceil(N / CHUNK)
  for c = 1, nch do
    chunks[c] = {road = Geo.new(), side = Geo.new(), barrier = Geo.new(), conc = Geo.new(), cont = Geo.new(),
                 tun = Geo.new(), signs = Geo.new(), emis = {}, inst = {}, instNear = {}, cx = 0, cz = 0, i0 = (c - 1) * CHUNK + 1}
  end
  local function chunkOf(i) return math.floor((wrap(i, N) - 1) / CHUNK) + 1 end
  local function emis(c, col)
    local g = chunks[c].emis[col]
    if not g then g = Geo.new(); chunks[c].emis[col] = g end
    return g
  end
  -- small pieces (shopfronts, lamps, roof props) are drawn only near the camera: every model copy is its own draw
  local NEAR = {GEO_ShopFront4m_A = true, GEO_ShopFront4m_B = true, GEO_ShopFront6m_A = true, GEO_WaterTank = true,
                GEO_HVACUnitLarge = true, GEO_StreetLampDouble_A = true, GEO_HighwayLamp_A = true}
  local function addInst(c, name, x, y, z, yaw, s)
    local ch = chunks[c]
    local set = NEAR[name] and ch.instNear or ch.inst
    local l = set[name]
    if not l then l = {}; set[name] = l end
    l[#l + 1] = x; l[#l + 1] = y; l[#l + 1] = z; l[#l + 1] = 0; l[#l + 1] = yaw; l[#l + 1] = 0; l[#l + 1] = s or 1
  end
  local function edge(i, off)
    return tr.x[i] - tr.tz[i] * off, tr.z[i] + tr.tx[i] * off
  end

  -- road, curbs, sidewalks, barriers with neon tubes, tunnel
  local wallV, wallI = tr.walls, {}
  tr.wallI = wallI
  for c = 1, nch do
    local ch = chunks[c]
    local i0 = (c - 1) * CHUNK + 1
    local i1 = math.min(N + 1, i0 + CHUNK)
    ch.cx, ch.cz = tr.x[wrap(math.floor((i0 + i1) / 2), N)], tr.z[wrap(math.floor((i0 + i1) / 2), N)]
    if c % 4 == 0 then Y() end
    for ii = i0, i1 - 1 do
      local a, b = wrap(ii, N), wrap(ii + 1, N)
      local ya, yb = tr.y[a], tr.y[b]
      local va, vb = (ii - 1) * tr.ds / 16, ii * tr.ds / 16
      -- road surface
      local lax, laz = edge(a, -hw); local rax, raz = edge(a, hw)
      local lbx, lbz = edge(b, -hw); local rbx, rbz = edge(b, hw)
      ch.road:quad(lax, ya, laz, rax, ya, raz, rbx, yb, rbz, lbx, yb, lbz, 0, vb, 1, va)
      for side = -1, 1, 2 do
        -- barrier: inner face, top, outer face (concrete jersey wall), neon tube along the top inner edge
        local o1, o2 = side * bar, side * (bar + 0.5)
        local p1x, p1z = edge(a, o1); local q1x, q1z = edge(b, o1)
        local p2x, p2z = edge(a, o2); local q2x, q2z = edge(b, o2)
        local H = 1.05
        local u0, u1 = (ii - 1) * tr.ds / 8, ii * tr.ds / 8
        if side > 0 then
          ch.barrier:quad(q1x, yb, q1z, p1x, ya, p1z, p1x, ya + H, p1z, q1x, yb + H, q1z, u1, 0, u0, 1)
          ch.barrier:quad(p1x, ya + H, p1z, p2x, ya + H, p2z, q2x, yb + H, q2z, q1x, yb + H, q1z, u0, 0, u1, 0.12)
          ch.barrier:quad(p2x, ya, p2z, q2x, yb, q2z, q2x, yb + H, q2z, p2x, ya + H, p2z, u0, 0, u1, 1)
        else
          ch.barrier:quad(p1x, ya, p1z, q1x, yb, q1z, q1x, yb + H, q1z, p1x, ya + H, p1z, u0, 0, u1, 1)
          ch.barrier:quad(q1x, yb + H, q1z, q2x, yb + H, q2z, p2x, ya + H, p2z, p1x, ya + H, p1z, u1, 0, u0, 0.12)
          ch.barrier:quad(q2x, yb, q2z, p2x, ya, p2z, p2x, ya + H, p2z, q2x, yb + H, q2z, u1, 0, u0, 1)
        end
        -- neon tube: a thin glowing strip on the inner face just under the top
        local e = emis(c, side < 0 and nL or nR)
        local ex1, ez1 = edge(a, side * (bar - 0.02)); local ex2, ez2 = edge(b, side * (bar - 0.02))
        e:quad(ex1, ya + 0.86, ez1, ex2, yb + 0.86, ez2, ex2, yb + 0.98, ez2, ex1, ya + 0.98, ez1)
        e:quad(ex2, yb + 0.86, ez2, ex1, ya + 0.86, ez1, ex1, ya + 0.98, ez1, ex2, yb + 0.98, ez2)
        -- collision wall (inner face, 3 m high so nothing climbs it)
        local base = #wallV / 3
        wallV[#wallV + 1] = p1x; wallV[#wallV + 1] = ya - 1; wallV[#wallV + 1] = p1z
        wallV[#wallV + 1] = q1x; wallV[#wallV + 1] = yb - 1; wallV[#wallV + 1] = q1z
        wallV[#wallV + 1] = q1x; wallV[#wallV + 1] = yb + 3; wallV[#wallV + 1] = q1z
        wallV[#wallV + 1] = p1x; wallV[#wallV + 1] = ya + 3; wallV[#wallV + 1] = p1z
        wallI[#wallI + 1] = base + 1; wallI[#wallI + 1] = base + 2; wallI[#wallI + 1] = base + 3
        wallI[#wallI + 1] = base + 1; wallI[#wallI + 1] = base + 3; wallI[#wallI + 1] = base + 4
        -- shoulder (sidewalk / quay apron / hard shoulder) from the barrier outwards
        local sl, sr = shoulders(tr, a)
        local sw = side < 0 and sl or sr
        if sw > 0 then
          local s1x, s1z = edge(a, side * (bar + 0.5)); local t1x, t1z = edge(b, side * (bar + 0.5))
          local s2x, s2z = edge(a, side * (bar + 0.5 + sw)); local t2x, t2z = edge(b, side * (bar + 0.5 + sw))
          local yo = th == "city" and 0.15 or 0.02
          local su = sw / 4
          if side < 0 then
            ch.side:quad(s2x, ya + yo, s2z, s1x, ya + yo, s1z, t1x, yb + yo, t1z, t2x, yb + yo, t2z, 0, vb * 4, su, va * 4)
          else
            ch.side:quad(s1x, ya + yo, s1z, s2x, ya + yo, s2z, t2x, yb + yo, t2z, t1x, yb + yo, t1z, 0, vb * 4, su, va * 4)
          end
        end
      end
      -- elevated road: deck sides and pillars
      local yl = math.min(ya, yb)
      if th == "express" and yl > 1.5 then
        local d1x, d1z = edge(a, -(bar + 0.5)); local d2x, d2z = edge(b, -(bar + 0.5))
        local e1x, e1z = edge(a, bar + 0.5); local e2x, e2z = edge(b, bar + 0.5)
        ch.conc:quad(d2x, yb - 1.2, d2z, d1x, ya - 1.2, d1z, d1x, ya, d1z, d2x, yb, d2z, 0, 0, 2, 0.3)
        ch.conc:quad(e1x, ya - 1.2, e1z, e2x, yb - 1.2, e2z, e2x, yb, e2z, e1x, ya, e1z, 0, 0, 2, 0.3)
        ch.conc:quad(d1x, ya - 1.2, d1z, d2x, yb - 1.2, d2z, e2x, yb - 1.2, e2z, e1x, ya - 1.2, e1z, 0, 0, 2, 2)
        if a % 12 == 0 then
          local yaw = math.atan(-tr.tz[a], tr.tx[a])
          ch.conc:box(tr.x[a], -2, tr.z[a], 3.2, ya - 1.2 + 2, 2.2, yaw, 4)
        end
      end
      -- tunnel: walls just outside the barriers, ceiling with light strips
      if T.inTunnel(tr, a) then
        local TH = 7.5
        for side = -1, 1, 2 do
          local o = side * (bar + 0.6)
          local p1x, p1z = edge(a, o); local q1x, q1z = edge(b, o)
          if side > 0 then
            ch.tun:quad(q1x, yb, q1z, p1x, ya, p1z, p1x, ya + TH, p1z, q1x, yb + TH, q1z, 0, 0, 1, 2)
          else
            ch.tun:quad(p1x, ya, p1z, q1x, yb, q1z, q1x, yb + TH, q1z, p1x, ya + TH, p1z, 0, 0, 1, 2)
          end
          if a % 3 == 0 then  -- amber side lamps
            local lx, lz = edge(a, side * (bar + 0.55))
            emis(c, NEON.amber):panel(lx, ya + 2.4, lz, -side * -tr.tz[a], -side * tr.tx[a], 0.5, 0.18)
          end
        end
        local l1x, l1z = edge(a, -(bar + 0.6)); local r1x, r1z = edge(a, bar + 0.6)
        local l2x, l2z = edge(b, -(bar + 0.6)); local r2x, r2z = edge(b, bar + 0.6)
        ch.tun:quad(r1x, ya + TH, r1z, l1x, ya + TH, l1z, l2x, yb + TH, l2z, r2x, yb + TH, r2z, 0, 0, 3, 0.4)
        ch.tun:quad(l1x, ya + TH + 0.6, l1z, r1x, ya + TH + 0.6, r1z, r2x, yb + TH + 0.6, r2z, l2x, yb + TH + 0.6, l2z, 0, 0, 3, 0.4)
        if a % 4 == 0 then  -- white ceiling strip, two rows
          for _, off in ipairs({-hw * 0.5, hw * 0.5}) do
            local cx, cz = edge(a, off)
            local fx, fz = tr.tx[a], tr.tz[a]
            local g = emis(c, NEON.white)
            local rx, rz = -fz, fx
            g:quad(cx - rx * 0.35 - fx * 1.6, ya + TH - 0.05, cz - rz * 0.35 - fz * 1.6, cx - rx * 0.35 + fx * 1.6, ya + TH - 0.05, cz - rz * 0.35 + fz * 1.6,
                   cx + rx * 0.35 + fx * 1.6, ya + TH - 0.05, cz + rz * 0.35 + fz * 1.6, cx + rx * 0.35 - fx * 1.6, ya + TH - 0.05, cz + rz * 0.35 - fz * 1.6)
            g:quad(cx + rx * 0.35 - fx * 1.6, ya + TH - 0.05, cz + rz * 0.35 - fz * 1.6, cx + rx * 0.35 + fx * 1.6, ya + TH - 0.05, cz + rz * 0.35 + fz * 1.6,
                   cx - rx * 0.35 + fx * 1.6, ya + TH - 0.05, cz - rz * 0.35 + fz * 1.6, cx - rx * 0.35 - fx * 1.6, ya + TH - 0.05, cz - rz * 0.35 - fz * 1.6)
            if a % 12 == 0 then
              tr.lights[#tr.lights + 1] = {x = cx, y = ya + TH - 0.6, z = cz, color = "#DDE8FF", idx = a, int = 7, range = 16}
            end
            tr.streaks[#tr.streaks + 1] = {x = cx, y = ya, z = cz, color = "#AFC4FF", h = TH, idx = a}
          end
        end
      end
    end
  end

  Y()
  -- gantries: neon arches over the road (start / finish gantry carries the countdown lamps)
  local gstep = th == "express" and 160 or 130
  local gi = 1
  while gi <= N do
    if not T.inTunnel(tr, gi) then
      local c = chunkOf(gi)
      local x, y, z = tr.x[gi], tr.y[gi], tr.z[gi]
      local yaw = math.atan(-tr.tz[gi], tr.tx[gi])  -- local x along the road's right vector
      local span = bar + 1.4
      local GH = 7.2
      local rx, rz = -tr.tz[gi], tr.tx[gi]
      for side = -1, 1, 2 do
        chunks[c].conc:box(x + rx * span * side, y, z + rz * span * side, 0.9, GH, 0.9, yaw, 2)
      end
      chunks[c].conc:box(x, y + GH, z, span * 2 + 0.9, 1.0, 1.1, yaw, 2)
      local col = gi == 1 and NEON.white or ((gi // gstep) % 2 == 0 and nL or nR)
      local e = emis(c, col)
      local fx, fz = tr.tx[gi], tr.tz[gi]
      for k = -1, 1, 2 do  -- tube under the beam on both faces
        e:panel(x + fx * 0.56 * k, y + GH - 0.25, z + fz * 0.56 * k, fx * k, fz * k, span * 2 - 0.6, 0.2)
        e:panel(x + fx * 0.56 * k, y + GH + 1.0, z + fz * 0.56 * k, fx * k, fz * k, span * 2 + 0.6, 0.12)
      end
      tr.lights[#tr.lights + 1] = {x = x, y = y + GH - 1, z = z, color = col, idx = gi, int = 9, range = 22}
      tr.streaks[#tr.streaks + 1] = {x = x - rx * hw * 0.5, y = y, z = z - rz * hw * 0.5, color = col, h = GH, idx = gi}
      tr.streaks[#tr.streaks + 1] = {x = x + rx * hw * 0.5, y = y, z = z + rz * hw * 0.5, color = col, h = GH, idx = gi}
      if gi == 1 then
        -- start banner (checkered emissive) and five countdown lamps facing the grid
        local g = emis(c, NEON.white)
        for k = 0, 15 do
          if k % 2 == 0 then
            local off = -span + 0.4 + (k + 0.5) * (span * 2 - 0.8) / 16
            g:panel(x + rx * off + fx * 0.6, y + GH + 0.15, z + rz * off + fz * 0.6, fx, fz, (span * 2 - 0.8) / 16, 0.35)
          end
        end
        for k = 1, 5 do
          local off = (k - 3) * 1.2
          tr.lamps[k] = {x = x + rx * off + fx * 0.75, y = y + GH - 0.9, z = z + rz * off + fz * 0.75, yaw = yaw}
        end
      end
    end
    gi = gi + gstep // 2
  end

  -- kit-bashed scenery
  local placed = {}
  local function free(x, z, r)
    for _, p in ipairs(placed) do
      if (p[1] - x) ^ 2 + (p[2] - z) ^ 2 < (p[3] + r) ^ 2 then return false end
    end
    return true
  end
  local function pick(list, h)
    local tot = 0
    for _, e in ipairs(list) do tot = tot + e[2] end
    local r = h * tot
    for _, e in ipairs(list) do
      r = r - e[2]
      if r <= 0 then return e[1] end
    end
    return list[#list][1]
  end
  local function piece(nm) return pieces[nm] end
  local seed = 0
  -- row: walk one side placing pieces of `list` at setback `back` (metres beyond the barrier)
  local function row(side, list, back, gap, from, to, opts)
    opts = opts or {}
    local s = from or 0
    local stop = to or tr.L
    local guard = 0
    while s < stop do
      guard = guard + 1
      if guard % 12 == 0 then Y() end
      seed = seed + 1
      local nm = pick(list, hash(seed * 3.7 + side))
      local p = piece(nm)
      if not p then s = s + 10 else
        local pw, pd = p.w, p.d
        local i = wrap(math.floor(s / tr.ds) + 1, N)
        local rx, rz = -tr.tz[i], tr.tx[i]
        local off = side * (bar + 0.5 + back + pd / 2)
        local x, z = tr.x[i] + rx * off, tr.z[i] + rz * off
        local rad = 0.5 * math.sqrt(pw * pw + pd * pd)
        local yaw = math.atan(-side * rx, -side * rz)
        -- the footprint's corners (and centre) must stay clear of every part of the road
        local ok = not T.inTunnel(tr, i)
        if ok then
          local ax, az = math.cos(yaw), -math.sin(yaw)
          local bx, bz = math.sin(yaw), math.cos(yaw)
          local need = bar + math.min(back, 4) * 0.7 + 0.8
          for _, c in ipairs({{0, 0}, {-1, -1}, {1, -1}, {1, 1}, {-1, 1}}) do
            local qx = x + ax * c[1] * pw / 2 + bx * c[2] * pd / 2
            local qz = z + az * c[1] * pw / 2 + bz * c[2] * pd / 2
            if T.roadDist(tr, qx, qz, need + 40) < need then ok = false; break end
          end
        end
        if ok and free(x, z, rad * 0.8) then
          placed[#placed + 1] = {x, z, rad * 0.8}
          local y = math.min(tr.y[i], 0) - (th == "express" and 0 or 0)
          if th ~= "express" then y = tr.y[i] + (th == "city" and 0.15 or 0.02) end
          if opts.yfix then y = opts.yfix end
          addInst(chunkOf(i), nm, x, y, z, yaw, 1)
          if opts.onPlace then opts.onPlace(i, x, y, z, yaw, p, side) end
          s = s + pw + (gap or 2)
        else
          s = s + 6
        end
      end
    end
  end

  local function signOn(i, x, y, z, yaw, p, side, blade)
    -- a neon sign on the road-facing wall of a building
    seed = seed + 1
    local k = math.floor(hash(seed * 1.3) * 12) + 1
    local r = SIGN_RECTS[k]
    local fx, fz = math.sin(yaw), math.cos(yaw)   -- local +z: towards the road
    local c = chunkOf(i)
    local sh = math.min(p.h - 3, 6 + hash(seed * 2.1) * 10)
    if sh < 4 then return end
    local cx, cz = x + fx * (p.d / 2 + 0.15), z + fz * (p.d / 2 + 0.15)
    local g = chunks[c].signs
    if blade then
      -- vertical blade sticking out towards the road, text running down
      local tx, tz = tr.tx[i], tr.tz[i]
      local bx, bz = cx + fx * 1.2, cz + fz * 1.2
      local bw, bh = 2.2, 8
      for k2 = -1, 1, 2 do
        local nx, nz = tx * k2, tz * k2
        local rxx, rzz = nz, -nx
        local ox, oz = bx + nx * 0.06, bz + nz * 0.06  -- the two faces sit apart: no z-fighting, no mirrored text
        local x0, z0 = ox - rxx * bw / 2, oz - rzz * bw / 2
        local x1, z1 = ox + rxx * bw / 2, oz + rzz * bw / 2
        -- rotated uv: the word reads top to bottom
        local a = g:vert(x0, y + sh, z0, r[1], r[2])
        local b = g:vert(x1, y + sh, z1, r[1], r[4])
        local cc = g:vert(x1, y + sh + bh, z1, r[3], r[4])
        local d = g:vert(x0, y + sh + bh, z0, r[3], r[2])
        g:tri(a, b, cc); g:tri(a, cc, d)
      end
      tr.lights[#tr.lights + 1] = {x = bx, y = y + sh + bh / 2, z = bz, color = T.SIGN_COLORS[k], idx = i, int = 6, range = 14}
      tr.streaks[#tr.streaks + 1] = {x = bx, y = tr.y[i], z = bz, color = T.SIGN_COLORS[k], h = sh, idx = i}
    else
      local sw = math.min(p.w * 0.8, 9)
      g:panel(cx, y + sh, cz, fx, fz, sw, sw / 4, r[1], r[2], r[3], r[4])
      tr.lights[#tr.lights + 1] = {x = cx + fx * 2, y = y + sh + 1, z = cz + fz * 2, color = T.SIGN_COLORS[k], idx = i, int = 6, range = 16}
      tr.streaks[#tr.streaks + 1] = {x = cx, y = tr.y[i], z = cz, color = T.SIGN_COLORS[k], h = sh, idx = i}
    end
  end

  local function lamps(name, step, offset, both, color, armOut)
    local s = 10
    local side = 1
    while s < tr.L do
      local i = wrap(math.floor(s / tr.ds) + 1, N)
      if not T.inTunnel(tr, i) then
        for _, sd in ipairs(both and {-1, 1} or {side}) do
          local rx, rz = -tr.tz[i], tr.tx[i]
          local off = sd * (bar + offset)
          local x, z = tr.x[i] + rx * off, tr.z[i] + rz * off
          local yaw = math.atan(-sd * rx, -sd * rz)
          addInst(chunkOf(i), name, x, tr.y[i], z, yaw, 1)
          local hx, hz = x - rx * sd * armOut, z - rz * sd * armOut
          local p = pieces[name]
          local ly = tr.y[i] + (p and p.h or 9) - 0.5
          if (i // 4) % 2 == 0 then
            tr.lights[#tr.lights + 1] = {x = hx, y = ly, z = hz, color = color, idx = i, int = 7, range = 18}
          end
          tr.streaks[#tr.streaks + 1] = {x = hx, y = tr.y[i], z = hz, color = color, h = ly - tr.y[i], idx = i}
        end
        side = -side
      end
      s = s + step
    end
  end

  if th == "city" then
    local front = {{"GEO_Apt_Brick5_A", 3}, {"GEO_Apt_Modern6_A", 3}, {"GEO_Apt_Modern8_A", 2}, {"GEO_Apt_Stucco4_A", 2},
                   {"GEO_OldTown_Row3_A", 2}, {"GEO_OldTown_Pair_A", 2}, {"GEO_Office_Punched_A", 2}, {"GEO_Office_GlassMid_A", 2},
                   {"GEO_Office_Ribbon_A", 2}, {"GEO_Office_BronzeChamfer_A", 1}, {"GEO_Retail_Strip_A", 1}}
    local tall = {{"GEO_Tower_GlassBlue_A", 3}, {"GEO_Tower_GlassBlue_B", 3}, {"GEO_Tower_Bronze_A", 2}, {"GEO_Tower_SetBack_A", 2},
                  {"GEO_Tower_Ribbon_A", 2}, {"GEO_Tower_Round_A", 2}, {"GEO_Tower_Slab_A", 1}, {"GEO_Office_Punched_B", 2}}
    local shops = {{"GEO_ShopFront4m_A", 3}, {"GEO_ShopFront4m_B", 3}, {"GEO_ShopFront6m_A", 2}}
    for _, side in ipairs({-1, 1}) do
      row(side, front, 5.0, 1.0, 0, nil, {onPlace = function(i, x, y, z, yaw, p, sd)
        seed = seed + 1
        -- shopfronts along the building's road face (ground floor)
        local fx, fz = math.sin(yaw), math.cos(yaw)
        local ax, az = math.cos(yaw), -math.sin(yaw)  -- local +x
        local u0 = -math.min(p.w / 2 - 0.4, 5.5)
        local cnt = 0
        while cnt < 2 do
          cnt = cnt + 1
          seed = seed + 1
          local nm = pick(shops, hash(seed * 1.7))
          local sp = pieces[nm]
          if not sp or u0 + sp.w > math.min(p.w / 2 - 0.4, 6.5) then break end
          local cu = u0 + sp.w / 2
          addInst(chunkOf(i), nm, x + ax * cu + fx * (p.d / 2 + 0.22), y, z + az * cu + fz * (p.d / 2 + 0.22), yaw, 1)
          u0 = u0 + sp.w
        end
        if hash(seed * 7.7) < 0.7 then signOn(i, x, y, z, yaw, p, sd, hash(seed * 3.3) < 0.5) end
        if p.h < 25 and hash(seed * 5.1) < 0.35 then
          addInst(chunkOf(i), hash(seed) < 0.5 and "GEO_WaterTank" or "GEO_HVACUnitLarge", x, y + p.h, z, yaw, 1)
        end
      end})
      row(side, tall, 42, 10, 0, nil, {})
    end
    lamps("GEO_StreetLampDouble_A", 34, 0.9, false, "#FFC98A", 2.4)
  elseif th == "harbor" then
    local wh = {{"GEO_Warehouse_A", 3}, {"GEO_Warehouse_B", 3}, {"GEO_Factory_Shed_A", 2}, {"GEO_Factory_Saw_A", 2}, {"GEO_Factory_Silo_A", 1}}
    local far = {{"GEO_Tower_GlassBlue_A", 2}, {"GEO_Tower_Slab_A", 2}, {"GEO_Tower_SetBack_A", 1}, {"GEO_Office_Punched_B", 2}}
    for _, side in ipairs({-1, 1}) do
      row(side, wh, 20, 6, side > 0 and tr.L * 0.27 or 0, nil, {onPlace = function(i, x, y, z, yaw, p, sd)
        seed = seed + 1
        if hash(seed * 9.1) < 0.5 then signOn(i, x, y, z, yaw, p, sd, false) end
      end})
      row(side, far, 120, 30, side > 0 and tr.L * 0.27 or 0, nil, {})
    end
    -- the skyline across the bay, seen over the water from the quay
    row(1, far, 170, 6, 0, tr.L * 0.27, {yfix = -1, onPlace = function(i, x, y, z, yaw, p, sd)
      seed = seed + 1
      if hash(seed * 4.3) < 0.7 then signOn(i, x, y, z, yaw, p, sd, false) end
    end})
    -- container stacks and cranes on the aprons (own geometry)
    local s = 20
    while s < tr.L do
      seed = seed + 1
      local i = wrap(math.floor(s / tr.ds) + 1, N)
      local f = (i - 1) / N
      for _, side in ipairs({-1, 1}) do
        if not (side > 0 and f < 0.27) then
          local rx, rz = -tr.tz[i], tr.tx[i]
          local yaw = math.atan(-tr.tz[i], tr.tx[i]) + math.pi / 2
          local off = side * (bar + 4 + hash(seed + side) * 8)
          local x, z = tr.x[i] + rx * off, tr.z[i] + rz * off
          if T.roadDist(tr, x, z, 30) > hw + 6 and free(x, z, 4) then
            placed[#placed + 1] = {x, z, 4}
            local stack = 1 + math.floor(hash(seed * 4.4 + side) * 3)
            for k = 0, stack - 1 do
              local cv = math.floor(hash(seed * 11 + k + side) * 6) / 6
              chunks[chunkOf(i)].cont:box(x, tr.y[i] + k * 2.6, z, 2.44, 2.59, 12.2, yaw + (hash(k + seed) - 0.5) * 0.08, 12.2, cv, cv + 1 / 6)
            end
          end
        end
      end
      s = s + 14
    end
    -- harbour cranes along the quay (right side of the long straight)
    for k = 1, 4 do
      local i = wrap(math.floor(tr.N * (0.04 + k * 0.05)), N)
      local rx, rz = -tr.tz[i], tr.tx[i]
      local x, z = tr.x[i] + rx * (bar + 9), tr.z[i] + rz * (bar + 9)
      local yaw = math.atan(-tr.tz[i], tr.tx[i])
      local c = chunkOf(i)
      local g = chunks[c].conc
      for _, dz in ipairs({-5, 5}) do
        for _, dx in ipairs({-4, 4}) do
          local px = x + dx * math.cos(yaw) + dz * math.sin(yaw)
          local pz = z - dx * math.sin(yaw) + dz * math.cos(yaw)
          g:box(px, -1, pz, 0.9, 30, 0.9, yaw, 3)
        end
      end
      g:box(x, 29, z, 1.4, 1.6, 52, yaw, 3)
      g:box(x, 29, z, 9.5, 1.2, 1.2, yaw, 3)
      local e = emis(c, NEON.red)
      for _, dz in ipairs({-25, 0, 25}) do
        local px, pz = x + dz * math.sin(yaw), z + dz * math.cos(yaw)
        e:box(px, 30.6, pz, 0.5, 0.5, 0.5, yaw, 1)
      end
      tr.lights[#tr.lights + 1] = {x = x, y = 12, z = z, color = "#FFB060", idx = i, int = 8, range = 30}
    end
    lamps("GEO_HighwayLamp_A", 30, 0.9, true, "#FFB060", 3.4)
  else
    local towers = {{"GEO_Tower_GlassBlue_A", 3}, {"GEO_Tower_GlassBlue_B", 3}, {"GEO_Tower_Bronze_A", 2}, {"GEO_Tower_SetBack_A", 2},
                    {"GEO_Tower_Ribbon_A", 2}, {"GEO_Tower_Round_A", 2}, {"GEO_Tower_Slab_A", 2}, {"GEO_Office_Punched_B", 1},
                    {"GEO_Office_BronzeChamfer_A", 1}}
    for _, side in ipairs({-1, 1}) do
      row(side, towers, 44, 14, 0, nil, {yfix = -1, onPlace = function(i, x, y, z, yaw, p, sd)
        seed = seed + 1
        if hash(seed * 2.9) < 0.6 then signOn(i, x, -1, z, yaw, p, sd, false) end
      end})
      row(side, towers, 110, 20, 0, nil, {yfix = -1})
    end
    -- billboards on the roadside
    local s = 60
    local side = 1
    while s < tr.L do
      local i = wrap(math.floor(s / tr.ds) + 1, N)
      if not T.inTunnel(tr, i) then
        local rx, rz = -tr.tz[i], tr.tx[i]
        local off = side * (bar + 9)
        local x, z = tr.x[i] + rx * off, tr.z[i] + rz * off
        if T.roadDist(tr, x, z, 30) > hw + 6 then
          local yaw = math.atan(-tr.tz[i], tr.tx[i])  -- face down the road
          local y = math.max(tr.y[i], 0)
          chunks[chunkOf(i)].conc:box(x, -1, z, 0.8, y + 6, 0.8, yaw, 3)
          seed = seed + 1
          local k = math.floor(hash(seed * 6.1) * 12) + 1
          local r = SIGN_RECTS[k]
          local fx, fz = -tr.tx[i], -tr.tz[i]
          chunks[chunkOf(i)].signs:panel(x + fx * 0.06, y + 5, z + fz * 0.06, fx, fz, 12, 3, r[1], r[2], r[3], r[4])
          chunks[chunkOf(i)].signs:panel(x - fx * 0.06, y + 5, z - fz * 0.06, -fx, -fz, 12, 3, r[1], r[2], r[3], r[4])
          tr.lights[#tr.lights + 1] = {x = x, y = y + 6, z = z, color = T.SIGN_COLORS[k], idx = i, int = 8, range = 22}
        end
        side = -side
      end
      s = s + 90
    end
    lamps("GEO_HighwayLamp_A", 36, 0.6, true, "#FFB45A", 3.4)
  end
  table.sort(tr.lights, function(a, b) return a.idx < b.idx end)
  table.sort(tr.streaks, function(a, b) return a.idx < b.idx end)
  for _, ch in ipairs(chunks) do ch.lights, ch.streaks = {}, {} end
  for _, L in ipairs(tr.lights) do local l = chunks[chunkOf(L.idx)].lights; l[#l + 1] = L end
  for _, L in ipairs(tr.streaks) do local l = chunks[chunkOf(L.idx)].streaks; l[#l + 1] = L end
end

-- turn the geometry builders into meshes (call once after build)
function T.finalize(tr, tex)
  for ci, ch in ipairs(tr.chunks) do
    if ci % 6 == 0 then Y() end
    ch.mRoad = ch.road:mesh()
    ch.mSide = ch.side:mesh()
    ch.mBarrier = ch.barrier:mesh(true)
    ch.mConc = ch.conc:mesh(true)
    ch.mCont = ch.cont:mesh(true)
    ch.mTun = ch.tun:mesh(true)
    ch.mSigns = ch.signs:mesh(true)
    ch.mEmis = {}
    for col, g in pairs(ch.emis) do ch.mEmis[#ch.mEmis + 1] = {g:mesh(true), col} end
    ch.road, ch.side, ch.barrier, ch.conc, ch.cont, ch.tun, ch.signs, ch.emis = nil
  end
end

return T
