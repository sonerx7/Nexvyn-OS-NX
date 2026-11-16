-- Crypt Light: particles (additive camera-facing quads drawn with g3d.drawInstanced) and flickering flame sources.
local F = {}
local random, sin, cos, pi, sqrt, floor, min, max = math.random, math.sin, math.cos, math.pi, math.sqrt, math.floor, math.min, math.max

local MAXP = 900
local px, py, pz, vx, vy, vz, life, tot, size, grow, kind = {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}
local count = 0
local emitters = {}
local quads = {}
F.flames = {}      -- {x, y, z, phase, strength, color, range, on}

-- particle kinds: texture, colour per brightness bucket (bright -> faint), upward drift
local KINDS = {
  flame = {tex = "flame", colors = {"#FF9A3A", "#C2541A", "#5A2008"}},
  ember = {tex = "soft", colors = {"#FFB060", "#B05A20", "#40180A"}},
  dust = {tex = "soft", colors = {"#5A4A38", "#2E261E", "#16120E"}},
  mist = {tex = "soft", colors = {"#1C232C", "#12171D", "#0A0D10"}},
  ward = {tex = "flame", colors = {"#7FFFF0", "#2C9C94", "#0C3A38"}},
  wardmote = {tex = "soft", colors = {"#9FFFF4", "#3AA89E", "#0E3634"}},
  wisp = {tex = "soft", colors = {"#9FE8FF", "#3A7A99", "#102A36"}},
  beam = {tex = "soft", colors = {"#1E2A3C", "#141C28", "#0A0E16"}},
  spark = {tex = "soft", colors = {"#FFE0A0", "#FF9A40", "#803010"}},
  blood = {tex = "soft", colors = {"#801010", "#400808", "#200404"}},
}
local KLIST = {}
for name, k in pairs(KINDS) do k.name = name; KLIST[#KLIST + 1] = k end

function F.init()
  local function quad(tex)
    local m = g3d.custom({-0.5, -0.5, 0, 0.5, -0.5, 0, 0.5, 0.5, 0, -0.5, 0.5, 0}, {1, 2, 3, 1, 3, 4}, nil, false,
      {0, 1, 1, 1, 1, 0, 0, 0})
    m:setTexture("bundle:/tex/" .. tex .. ".png")
    return m
  end
  quads.soft = quad("soft")
  quads.flame = quad("flame")
  for _, k in ipairs(KLIST) do
    k.mesh = quads[k.tex]
    k.bufs = {{}, {}, {}}
  end
end

function F.clear()
  count = 0
  emitters = {}
  F.flames = {}
end

local function spawn(k, x, y, z, ivx, ivy, ivz, l, s, g)
  if count >= MAXP then return end
  count = count + 1
  local i = count
  px[i], py[i], pz[i], vx[i], vy[i], vz[i] = x, y, z, ivx, ivy, ivz
  life[i], tot[i], size[i], grow[i], kind[i] = l, l, s, g or 0, k
end
F.spawn = function(name, ...) spawn(KINDS[name], ...) end

-- a looping emitter: kind, position, rate (per second), and a spawn function
function F.emitter(e)
  e.acc = 0
  e.on = e.on ~= false
  emitters[#emitters + 1] = e
  return e
end

-- emitter presets
function F.torch(x, y, z, scale)
  scale = scale or 1
  local fl = {x = x, y = y + 0.15, z = z, phase = random() * 10, strength = 1, color = "#FF7A2E", range = 6 * scale, int = 3.0 * scale, on = true}
  F.flames[#F.flames + 1] = fl
  F.emitter({x = x, y = y, z = z, rate = 26 * scale, fn = function(e)
    spawn(KINDS.flame, e.x + (random() - 0.5) * 0.08 * scale, e.y, e.z + (random() - 0.5) * 0.08 * scale,
      (random() - 0.5) * 0.15, 0.7 + random() * 0.5, (random() - 0.5) * 0.15, 0.35 + random() * 0.25, 0.26 * scale, -0.35 * scale)
    if random() < 0.12 then
      spawn(KINDS.ember, e.x, e.y + 0.15, e.z, (random() - 0.5) * 0.4, 0.8 + random() * 0.8, (random() - 0.5) * 0.4, 1.2 + random(), 0.05, 0)
    end
  end})
  return fl
end

function F.brazier(x, y, z, scale)
  local fl = F.torch(x, y, z, 1.7 * (scale or 1))
  fl.range, fl.int = 7.5, 5
  return fl
end

function F.ward(x, y, z)
  local fl = {x = x, y = y + 0.2, z = z, phase = random() * 10, strength = 1, color = "#5FD4C8", range = 6, int = 6, on = true}
  F.flames[#F.flames + 1] = fl
  local e = F.emitter({x = x, y = y, z = z, rate = 22, fn = function(e)
    spawn(KINDS.ward, e.x + (random() - 0.5) * 0.1, e.y, e.z + (random() - 0.5) * 0.1, (random() - 0.5) * 0.1, 0.5 + random() * 0.4,
      (random() - 0.5) * 0.1, 0.45 + random() * 0.3, 0.3, -0.3)
    if random() < 0.25 then
      local a = random() * pi * 2
      spawn(KINDS.wardmote, e.x + cos(a) * 0.5, e.y - 0.3, e.z + sin(a) * 0.5, -cos(a) * 0.2, 0.6, -sin(a) * 0.2, 1.4, 0.06, 0)
    end
  end})
  return fl, e
end

-- slow floor mist inside a radius
function F.mist(x, y, z, r)
  F.emitter({x = x, y = y, z = z, rate = 1.2 + r * 0.25, fn = function(e)
    local a, d = random() * pi * 2, sqrt(random()) * r
    spawn(KINDS.mist, e.x + cos(a) * d, e.y + 0.15 + random() * 0.35, e.z + sin(a) * d, (random() - 0.5) * 0.15, 0.01, (random() - 0.5) * 0.15,
      7 + random() * 5, 2.6 + random() * 1.5, 0.12)
  end})
end

-- a cold shaft of light from above with dust in it
function F.beam(x, y, z)
  F.emitter({x = x, y = y, z = z, rate = 6, fn = function(e)
    spawn(KINDS.beam, e.x + (random() - 0.5) * 1.2, e.y + 0.5 + random() * 5, e.z + (random() - 0.5) * 1.2, 0, -0.05, 0, 4 + random() * 2, 2.4, 0.05)
    spawn(KINDS.dust, e.x + (random() - 0.5) * 1.4, e.y + random() * 4, e.z + (random() - 0.5) * 1.4, (random() - 0.5) * 0.05, -0.03, (random() - 0.5) * 0.05, 6, 0.04, 0)
  end})
end

-- dust motes that drift around the player (they only show near light)
function F.dustAround(x, y, z, dt)
  if random() < dt * 9 then
    local a, d = random() * pi * 2, 0.6 + random() * 3.5
    spawn(KINDS.dust, x + cos(a) * d, y - 1 + random() * 2.2, z + sin(a) * d, (random() - 0.5) * 0.06, (random() - 0.5) * 0.04,
      (random() - 0.5) * 0.06, 5 + random() * 3, 0.03 + random() * 0.02, 0)
  end
end

function F.burst(name, x, y, z, n, speed, l, s)
  local k = KINDS[name]
  for _ = 1, n do
    local a, b = random() * pi * 2, random() * pi - pi / 2
    local sp = speed * (0.4 + random() * 0.6)
    spawn(k, x, y, z, cos(a) * cos(b) * sp, sin(b) * sp + speed * 0.3, sin(a) * cos(b) * sp, l * (0.6 + random() * 0.6), s, 0)
  end
end

function F.update(dt, t, camx, camz)
  for _, e in ipairs(emitters) do
    if e.on then
      local dx, dz = e.x - camx, e.z - camz
      if dx * dx + dz * dz < 26 * 26 then
        e.acc = e.acc + e.rate * dt
        while e.acc >= 1 do e.acc = e.acc - 1; e.fn(e) end
      end
    end
  end
  local i = 1
  while i <= count do
    local l = life[i] - dt
    if l <= 0 then
      -- swap with the last
      px[i], py[i], pz[i], vx[i], vy[i], vz[i] = px[count], py[count], pz[count], vx[count], vy[count], vz[count]
      life[i], tot[i], size[i], grow[i], kind[i] = life[count], tot[count], size[count], grow[count], kind[count]
      count = count - 1
    else
      life[i] = l
      local k = kind[i]
      px[i], py[i], pz[i] = px[i] + vx[i] * dt, py[i] + vy[i] * dt, pz[i] + vz[i] * dt
      if k == KINDS.dust or k == KINDS.mist or k == KINDS.beam then
        vx[i] = vx[i] + sin(t * 0.7 + i) * 0.01 * dt
        vz[i] = vz[i] + cos(t * 0.6 + i * 1.3) * 0.01 * dt
      elseif k == KINDS.blood or k == KINDS.spark then
        vy[i] = vy[i] - 6 * dt
      end
      size[i] = max(0.01, size[i] + grow[i] * dt)
      i = i + 1
    end
  end
  -- flame flicker: two sines and a little noise
  for _, f in ipairs(F.flames) do
    local p = f.phase
    f.flick = 0.86 + 0.08 * sin(t * 9.1 + p) + 0.05 * sin(t * 23.7 + p * 2.3) + 0.03 * (random() - 0.5)
  end
end

-- lx, ly, lz: the lantern; dust is brighter near it (it only exists where light is)
function F.draw(camYaw, lx, ly, lz, lantern)
  for _, k in ipairs(KLIST) do
    local b = k.bufs
    b.n1, b.n2, b.n3 = 0, 0, 0
  end
  local ry = -camYaw
  for i = 1, count do
    local k = kind[i]
    local f = life[i] / tot[i]
    local bucket
    if k == KINDS.dust then
      local dx, dy, dz = px[i] - lx, py[i] - ly, pz[i] - lz
      local d2 = dx * dx + dy * dy + dz * dz
      local near = d2 * (1.5 - lantern) * 0.25
      bucket = near < 0.35 and 1 or (near < 1.6 and 2 or 3)
      if f > 0.85 or f < 0.15 then bucket = min(3, bucket + 1) end
    elseif k == KINDS.mist or k == KINDS.beam then
      bucket = (f > 0.8 or f < 0.25) and 3 or ((f > 0.65 or f < 0.4) and 2 or 1)
    else
      bucket = f > 0.6 and 1 or (f > 0.28 and 2 or 3)
    end
    local buf = k.bufs[bucket]
    local key = bucket == 1 and "n1" or (bucket == 2 and "n2" or "n3")
    local n = k.bufs[key]
    local rx = (k == KINDS.mist) and -pi / 2 or 0
    buf[n + 1], buf[n + 2], buf[n + 3], buf[n + 4], buf[n + 5], buf[n + 6], buf[n + 7] = px[i], py[i], pz[i], rx, rx == 0 and ry or 0, 0, size[i]
    k.bufs[key] = n + 7
  end
  for _, k in ipairs(KLIST) do
    local b = k.bufs
    for bi = 1, 3 do
      local buf = b[bi]
      local n = b[bi == 1 and "n1" or (bi == 2 and "n2" or "n3")]
      for j = #buf, n + 1, -1 do buf[j] = nil end
      if n > 0 then g3d.drawInstanced(k.mesh, buf, k.colors[bi], "glow unlit nocull") end
    end
  end
end

function F.count() return count end

return F
