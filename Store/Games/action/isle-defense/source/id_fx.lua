-- Isle Defense: particles. Camera-facing quads drawn with g3d.drawInstanced, additive ("glow") for light and fire,
-- and a few alpha kinds for smoke and water. Colours fade through three buckets (bright, mid, faint) per kind, so one
-- draw call per kind and bucket covers every particle.
local F = {}
local random, sin, cos, pi, sqrt, floor, min, max = math.random, math.sin, math.cos, math.pi, math.sqrt, math.floor, math.min, math.max

local MAXP = 1400
local px, py, pz, vx, vy, vz, life, tot, size, grow, kind, drag = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
local count = 0
local quads = {}
F.bolts = {}   -- lightning: {pts = {{x,y,z}...}, t, col}

local KINDS = {
  fire = {tex = "soft", glow = true, colors = {"#FFC060", "#E2571B", "#5A1A06"}, g = 0},
  ember = {tex = "spark", glow = true, colors = {"#FFD080", "#FF7A20", "#702008"}, g = -4},
  spark = {tex = "spark", glow = true, colors = {"#FFF4C0", "#FFB040", "#803010"}, g = -9},
  frost = {tex = "spark", glow = true, colors = {"#E6FBFF", "#7FD8FF", "#1A5A8A"}, g = -2},
  magic = {tex = "spark", glow = true, colors = {"#F2DFFF", "#B36BFF", "#3A1066"}, g = 0},
  gold = {tex = "spark", glow = true, colors = {"#FFF2B0", "#FFC23A", "#7A4A08"}, g = -6},
  heal = {tex = "soft", glow = true, colors = {"#C8FFE8", "#3FD8A0", "#0C4A36"}, g = 0},
  glint = {tex = "spark", glow = true, colors = {"#FFFFFF", "#FFF0C0", "#80705A"}, g = 0},
  portal = {tex = "soft", glow = true, colors = {"#F0A0FF", "#9030E0", "#2A0848"}, g = 0},
  heart = {tex = "spark", glow = true, colors = {"#E0FFFF", "#40E0FF", "#0A4060"}, g = 0},
  smoke = {tex = "puff", glow = false, colors = {"#5A5450B0", "#4A4642A0", "#3A363380"}, g = 0},
  ash = {tex = "puff", glow = false, colors = {"#3A3433C0", "#2A2524A0", "#1A161560"}, g = 0},
  splash = {tex = "puff", glow = false, colors = {"#FFFFFFE0", "#D8F6FFB0", "#A0E8F870"}, g = -9},
  dust = {tex = "puff", glow = false, colors = {"#D8C090A0", "#B89A6A80", "#8A704A50"}, g = 0},
}
local KLIST = {}
for name, k in pairs(KINDS) do k.name = name; KLIST[#KLIST + 1] = k end
table.sort(KLIST, function(a, b) return (a.glow and 1 or 0) < (b.glow and 1 or 0) end)

function F.init()
  local function quad(tex)
    local m = g3d.custom({-0.5, -0.5, 0, 0.5, -0.5, 0, 0.5, 0.5, 0, -0.5, 0.5, 0}, {1, 2, 3, 1, 3, 4}, nil, false,
      {0, 1, 1, 1, 1, 0, 0, 0})
    m:setTexture("bundle:/tex/" .. tex .. ".png")
    return m
  end
  for _, k in ipairs(KLIST) do
    quads[k.tex] = quads[k.tex] or quad(k.tex)
    k.mesh = quads[k.tex]
    k.bufs = {{}, {}, {}}
    k.n = {0, 0, 0}
  end
end

function F.clear() count = 0; F.bolts = {} end
function F.count() return count end

local function spawn(k, x, y, z, ivx, ivy, ivz, l, s, g, d)
  if count >= MAXP then return end
  count = count + 1
  local i = count
  px[i], py[i], pz[i], vx[i], vy[i], vz[i] = x, y, z, ivx, ivy, ivz
  life[i], tot[i], size[i], grow[i], kind[i], drag[i] = l, l, s, g or 0, k, d or 0
end
function F.spawn(name, ...) spawn(KINDS[name], ...) end

-- a burst in all directions
function F.burst(name, x, y, z, n, speed, l, s, g)
  local k = KINDS[name]
  for _ = 1, n do
    local a, b = random() * pi * 2, random() * pi * 0.5
    local sp = speed * (0.35 + random() * 0.65)
    spawn(k, x, y, z, cos(a) * cos(b) * sp, sin(b) * sp + speed * 0.25, sin(a) * cos(b) * sp, l * (0.6 + random() * 0.6), s * (0.7 + random() * 0.6), g or 0, 1.5)
  end
end

-- a cannon blast: fire ball, sparks, smoke, dust ring
function F.explosion(x, y, z, r)
  r = r or 1
  F.burst("fire", x, y + 0.3, z, floor(14 * r), 3.2 * r, 0.45, 1.3 * r, -1.2)
  F.burst("spark", x, y + 0.3, z, floor(16 * r), 7 * r, 0.7, 0.22)
  for _ = 1, floor(6 * r) do
    spawn(KINDS.smoke, x + (random() - 0.5) * r, y + 0.4, z + (random() - 0.5) * r, (random() - 0.5) * 1.2, 1.2 + random(), (random() - 0.5) * 1.2, 1.4 + random() * 0.8, 1.0 * r, 1.4 * r, 1.2)
  end
  for i = 1, 10 do
    local a = i / 10 * pi * 2
    spawn(KINDS.dust, x, y + 0.15, z, cos(a) * 4 * r, 0.3, sin(a) * 4 * r, 0.6, 0.7 * r, 1.4, 4)
  end
end

function F.splash(x, y, z, n)
  for _ = 1, n or 10 do
    local a = random() * pi * 2
    local sp = 1 + random() * 1.6
    spawn(KINDS.splash, x, y + 0.1, z, cos(a) * sp, 3 + random() * 2.5, sin(a) * sp, 0.7 + random() * 0.3, 0.35 + random() * 0.25, 0.5)
  end
end

function F.frostHit(x, y, z, r)
  F.burst("frost", x, y, z, 10, 2.4, 0.6, 0.28)
  if r and r > 0 then
    for i = 1, 14 do
      local a = i / 14 * pi * 2
      spawn(KINDS.frost, x + cos(a) * 0.3, y, z + sin(a) * 0.3, cos(a) * r * 2.2, 0.2, sin(a) * r * 2.2, 0.45, 0.35, 0, 3)
    end
  end
end

-- fire tower pulse: a ring of flame rolling out to the radius
function F.fireRing(x, y, z, r)
  local n = floor(18 + r * 4)
  for i = 1, n do
    local a = i / n * pi * 2 + random() * 0.2
    local sp = r / 0.55
    spawn(KINDS.fire, x + cos(a) * 0.6, y + 0.35, z + sin(a) * 0.6, cos(a) * sp, 0.6 + random() * 0.6, sin(a) * sp, 0.55, 0.8 + random() * 0.4, 0.6, 1.6)
  end
end

function F.bolt(x1, y1, z1, x2, y2, z2, col)
  local pts = {{x1, y1, z1}}
  local seg = 6
  for i = 1, seg - 1 do
    local f = i / seg
    local j = 0.55 * sin(f * pi)
    pts[#pts + 1] = {x1 + (x2 - x1) * f + (random() - 0.5) * j, y1 + (y2 - y1) * f + (random() - 0.5) * j, z1 + (z2 - z1) * f + (random() - 0.5) * j}
  end
  pts[#pts + 1] = {x2, y2, z2}
  F.bolts[#F.bolts + 1] = {pts = pts, t = 0.22, col = col or "#E6CCFF"}
  F.burst("magic", x2, y2, z2, 6, 2.0, 0.35, 0.3)
end

-- continuous sources, called each frame with dt
function F.flame(x, y, z, s, dt, rate)
  local n = (rate or 18) * dt
  while n > 0 do
    if random() < n then
      spawn(KINDS.fire, x + (random() - 0.5) * 0.3 * s, y, z + (random() - 0.5) * 0.3 * s, (random() - 0.5) * 0.2, 1.0 + random() * 0.7, (random() - 0.5) * 0.2, 0.45 + random() * 0.3, 0.55 * s, -0.5 * s)
      if random() < 0.15 then spawn(KINDS.ember, x, y + 0.2, z, (random() - 0.5) * 0.6, 1.4 + random(), (random() - 0.5) * 0.6, 1.2 + random(), 0.1, 0) end
    end
    n = n - 1
  end
end

function F.update(dt)
  local i = 1
  while i <= count do
    local l = life[i] - dt
    if l <= 0 then
      local c = count
      px[i], py[i], pz[i], vx[i], vy[i], vz[i] = px[c], py[c], pz[c], vx[c], vy[c], vz[c]
      life[i], tot[i], size[i], grow[i], kind[i], drag[i] = life[c], tot[c], size[c], grow[c], kind[c], drag[c]
      count = c - 1
    else
      life[i] = l
      local k = kind[i]
      local dr = drag[i]
      if dr > 0 then
        local f = max(0, 1 - dr * dt)
        vx[i], vz[i] = vx[i] * f, vz[i] * f
        if k.g == 0 then vy[i] = vy[i] * f end
      end
      vy[i] = vy[i] + k.g * dt
      px[i], py[i], pz[i] = px[i] + vx[i] * dt, py[i] + vy[i] * dt, pz[i] + vz[i] * dt
      size[i] = max(0.02, size[i] + grow[i] * dt)
      i = i + 1
    end
  end
  local b = 1
  while b <= #F.bolts do
    local bo = F.bolts[b]
    bo.t = bo.t - dt
    if bo.t <= 0 then table.remove(F.bolts, b) else b = b + 1 end
  end
end

-- yaw and pitch of the camera: quads turn to face it
function F.draw(camYaw, camPitch)
  for _, k in ipairs(KLIST) do k.n[1], k.n[2], k.n[3] = 0, 0, 0 end
  local ry, rx = camYaw, camPitch
  for i = 1, count do
    local k = kind[i]
    local f = life[i] / tot[i]
    local bucket = f > 0.62 and 1 or (f > 0.3 and 2 or 3)
    local buf = k.bufs[bucket]
    local n = k.n[bucket]
    buf[n + 1], buf[n + 2], buf[n + 3], buf[n + 4], buf[n + 5], buf[n + 6], buf[n + 7] = px[i], py[i], pz[i], rx, ry, 0, size[i]
    k.n[bucket] = n + 7
  end
  for _, k in ipairs(KLIST) do
    for bi = 1, 3 do
      local buf, n = k.bufs[bi], k.n[bi]
      for j = #buf, n + 1, -1 do buf[j] = nil end
      if n > 0 then g3d.drawInstanced(k.mesh, buf, k.colors[bi], k.glow and "glow unlit nocull" or "unlit nocull") end
    end
  end
  for _, bo in ipairs(F.bolts) do
    local p = bo.pts
    local a = bo.t / 0.22
    for j = 1, #p - 1 do
      g3d.line(p[j][1], p[j][2], p[j][3], p[j + 1][1], p[j + 1][2], p[j + 1][3], bo.col, 3 + 2 * a)
    end
  end
end

return F
