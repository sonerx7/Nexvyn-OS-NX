-- Isle Defense: the island scene. Terrain mesh from the generated island (ge_terrain + ge_gen route), water with
-- moving ripples, shore foam, scatter plants (kit trees, instanced), kit props (village, pier, beach), the heart
-- crystal, the sea portal of the raiders and the volcano's lava. Everything is built once per island.
local D = require("id_data")
local W = {}
local sin, cos, sqrt, floor, min, max, abs, pi, random = math.sin, math.cos, math.sqrt, math.floor, math.min, math.max, math.abs, math.pi, math.random

local models = {}
local function M(path)
  local m = models[path]
  if m == nil then
    m = g3d.model("bundle:/models/" .. path .. ".glb") or false
    models[path] = m
  end
  return m or nil
end
W.model = M

-- ------------------------------------------------------------------ terrain
local T            -- {n, cell, hw, H (metres), water}
function W.heightAt(x, z)
  if not T then return 0 end
  local cell, n = T.cell, T.n
  local gx, gz = (x + T.hw) / cell, (z + T.hw) / cell
  if gx < 0 then gx = 0 elseif gx > n - 1.001 then gx = n - 1.001 end
  if gz < 0 then gz = 0 elseif gz > n - 1.001 then gz = n - 1.001 end
  local i, j = floor(gx), floor(gz)
  local u, v = gx - i, gz - j
  local H = T.H
  local k = j * n + i + 1
  local y00, y10, y01, y11 = H[k], H[k + 1], H[k + n], H[k + n + 1]
  if u + v <= 1 then return y00 + u * (y10 - y00) + v * (y01 - y00) end
  return y11 + (1 - u) * (y01 - y11) + (1 - v) * (y10 - y11)
end

local function buildTerrain(def)
  local n, cell = def.n, def.cell
  local hw = (n - 1) * cell / 2
  local H = {}
  for k = 1, n * n do H[k] = def.h[k] / 100 end
  T = {n = n, cell = cell, hw = hw, H = H, water = def.water}
  local xyz, cols, idx = {}, {}, {}
  local c = def.c
  for j = 0, n - 1 do
    for i = 0, n - 1 do
      local k = j * n + i
      xyz[#xyz + 1] = -hw + i * cell
      xyz[#xyz + 1] = H[k + 1]
      xyz[#xyz + 1] = -hw + j * cell
      cols[k + 1] = "#" .. c:sub(k * 6 + 1, k * 6 + 6)
    end
  end
  for j = 0, n - 2 do
    for i = 0, n - 2 do
      local a = j * n + i + 1
      local b, cc = a + 1, a + n
      idx[#idx + 1], idx[#idx + 2], idx[#idx + 3] = a, cc, b
      idx[#idx + 1], idx[#idx + 2], idx[#idx + 3] = b, cc, cc + 1
    end
  end
  local mesh = g3d.custom(xyz, idx, cols, false)
  g3d.material(mesh, {roughness = 0.92, metallic = 0})
  -- shore foam: quads of the cells around the water line, white with alpha by closeness to the line
  local fx, fc, fi = {}, {}, {}
  local wy = def.water
  local function alphaAt(h)
    local d = abs(h - wy)
    return max(0, 1 - d / 0.7)
  end
  local vmap = {}
  local function vert(i, j)
    local k = j * n + i
    local v = vmap[k]
    if v then return v end
    fx[#fx + 1], fx[#fx + 2], fx[#fx + 3] = -hw + i * cell, wy + 0.04, -hw + j * cell
    local a = alphaAt(H[k + 1])
    fc[#fc + 1] = string.format("#FFFFFF%02X", floor(a * a * 210))
    vmap[k] = #fc
    return #fc
  end
  for j = 0, n - 2 do
    for i = 0, n - 2 do
      local k = j * n + i + 1
      local lo = min(H[k], H[k + 1], H[k + n], H[k + n + 1])
      local hi = max(H[k], H[k + 1], H[k + n], H[k + n + 1])
      if lo < wy + 0.7 and hi > wy - 0.7 then
        local a, b, cc, d = vert(i, j), vert(i + 1, j), vert(i, j + 1), vert(i + 1, j + 1)
        fi[#fi + 1], fi[#fi + 2], fi[#fi + 3] = a, cc, b
        fi[#fi + 1], fi[#fi + 2], fi[#fi + 3] = b, cc, d
      end
    end
  end
  local foam = #fi > 0 and g3d.custom(fx, fi, fc, false) or nil
  return mesh, foam
end

-- ------------------------------------------------------------------ water
local water
local function buildWater()
  if water then return water end
  -- a big plane with tiled texture coordinates: one 8 m tile of the ripple normal map
  local S, tile = 1600, 8
  local reps = S / tile
  local m = g3d.custom({-S / 2, 0, -S / 2, S / 2, 0, -S / 2, S / 2, 0, S / 2, -S / 2, 0, S / 2}, {1, 3, 2, 1, 4, 3}, nil, false,
    {0, 0, reps, 0, reps, reps, 0, reps})
  local m2 = g3d.custom({-S / 2, 0, -S / 2, S / 2, 0, -S / 2, S / 2, 0, S / 2, -S / 2, 0, S / 2}, {1, 3, 2, 1, 4, 3}, nil, false,
    {0, 0, reps * 0.7, 0, reps * 0.7, reps * 0.7, 0, reps * 0.7})
  g3d.material(m, {roughness = 0.08, metallic = 0, normalMap = "bundle:/tex/water_n.png", normalScale = 0.55})
  g3d.material(m2, {roughness = 0.12, metallic = 0, normalMap = "bundle:/tex/water_n.png", normalScale = 0.4})
  water = {a = m, b = m2, tile = tile}
  return water
end

-- ------------------------------------------------------------------ helpers
local S = {}   -- the current scene
W.S = S

local function distToRoute(x, z)
  local best = 1e9
  local r = S.route
  for k = 1, #r - 1 do
    local ax, az, bx, bz = r[k][1], r[k][3], r[k + 1][1], r[k + 1][3]
    local dx, dz = bx - ax, bz - az
    local l2 = dx * dx + dz * dz
    local u = l2 > 0 and max(0, min(1, ((x - ax) * dx + (z - az) * dz) / l2)) or 0
    local qx, qz = ax + dx * u - x, az + dz * u - z
    local d = sqrt(qx * qx + qz * qz)
    if d < best then best = d end
  end
  return best
end
W.distToRoute = distToRoute

local function freeSpot(x, z, clear)
  if distToRoute(x, z) < clear then return false end
  for _, p in ipairs(S.pads) do
    local dx, dz = p[1] - x, p[3] - z
    if dx * dx + dz * dz < (clear + 0.5) ^ 2 then return false end
  end
  for _, o in ipairs(S.taken) do
    local dx, dz = o[1] - x, o[2] - z
    if dx * dx + dz * dz < (o[3] + clear * 0.6) ^ 2 then return false end
  end
  local h = W.heightAt(x, z)
  if h < T.water + 0.35 then return false end
  -- not on a steep slope
  local e = 1.2
  local s = max(abs(W.heightAt(x + e, z) - W.heightAt(x - e, z)), abs(W.heightAt(x, z + e) - W.heightAt(x, z - e)))
  return s < 1.0
end

local function prop(path, x, z, yaw, s, r, opts)
  local m = M(path)
  if not m then return nil end
  local p = {m = m, x = x, y = W.heightAt(x, z) + (opts and opts.dy or 0), z = z, yaw = yaw or 0, s = s or 1, r = r or 1.5}
  S.props[#S.props + 1] = p
  S.taken[#S.taken + 1] = {x, z, r or 1.5}
  return p
end

-- try to place a prop in a ring around (cx, cz)
local function ringProp(path, cx, cz, r0, r1, s, clear, yawFn)
  for _ = 1, 40 do
    local a, d = random() * pi * 2, r0 + random() * (r1 - r0)
    local x, z = cx + cos(a) * d, cz + sin(a) * d
    if freeSpot(x, z, clear) then
      local yaw = yawFn and yawFn(x, z) or random() * pi * 2
      return prop(path, x, z, yaw, s, clear)
    end
  end
end

-- coast point: march from the sea towards the centre along an angle
local function coastAt(a)
  for d = 58, 4, -0.5 do
    local x, z = cos(a) * d, sin(a) * d
    if W.heightAt(x, z) > T.water + 0.05 then return x, z, d end
  end
end

-- ------------------------------------------------------------------ build an island
function W.build(isleIndex)
  local def = D.ISLES[isleIndex]
  local data = require(def.file)
  for k in pairs(S) do S[k] = nil end
  S.def, S.isle = def, isleIndex
  S.terrain, S.foam = buildTerrain(data)
  S.water = buildWater()
  S.waterY = data.water
  S.route, S.pads, S.heart, S.crater = data.route, data.pads, data.heart, data.crater
  S.props, S.taken = {}, {}
  math.randomseed(isleIndex * 977)
  -- scatter plants, grouped by kind for instanced drawing
  local KIND = {
    palm = {{"lp/CoconutPalm_A", 0.4}, {"lp/FanPalm_A", 0.34}},
    tree = isleIndex == 2 and {{"lp/Oak_A", 0.62}, {"lp/Jacaranda_A", 0.6}, {"lp/StreetTreeRound_A", 0.6}} or {{"lp/Oak_A", 0.58}},
    pine = {{"lp/Pine_A", 0.55}, {"lp/Cypress_A", 0.5}},
    bush = {{"lp/RoundBush_A", 1.1}, {"lp/FloweringShrub_A", 0.85}, {"tb/TropicalBush_B", 0.9}},
    rock = {{"vk/RockLarge", 1.0}, {"tb/Rock_A", 1.2}, {"vk/RockCluster", 1.4}},
    dead = {{"lp/Cypress_A", 0.42}, {"lp/Pine_A", 0.45}},
  }
  local groups = {}
  for _, it in ipairs(data.scatter) do
    local kind, x, y, z, yaw, s = it[1], it[2], it[3], it[4], it[5], it[6]
    local opts = KIND[kind]
    if opts then
      local pick = opts[(floor(x * 13 + z * 7) % #opts) + 1]
      local key = pick[1]
      local g = groups[key]
      if not g then
        g = {m = M(key), tf = {}, base = pick[2]}
        groups[key] = g
      end
      if g.m then
        local tf = g.tf
        local sc = g.base * s
        tf[#tf + 1], tf[#tf + 2], tf[#tf + 3], tf[#tf + 4], tf[#tf + 5], tf[#tf + 6], tf[#tf + 7] = x, y - 0.05, z, 0, yaw, 0, sc
        S.taken[#S.taken + 1] = {x, z, 1.2}
      end
    end
  end
  S.plants = {}
  for k, g in pairs(groups) do
    if g.m and #g.tf > 0 then
      -- the near ones are listed per group; the renderer instances them (128 per GPU call)
      S.plants[#S.plants + 1] = {m = g.m, tf = g.tf, name = k, dead = (k:find("Cypress") and isleIndex == 3)}
    end
  end
  -- the heart: shrine ring and crystal (drawn by W.draw), and the village behind it
  local hx, hz = S.heart[1], S.heart[3]
  S.heart[2] = W.heightAt(hx, hz)
  S.taken[#S.taken + 1] = {hx, hz, 4}
  local away = function(x, z) return math.atan(x - hx, z - hz) end
  prop("mc/TowerCap", hx, hz, 0, 0.5, 2.2, {dy = -0.55})
  local face = function(x, z) return math.atan(hx - x, hz - z) end
  ringProp("vk/Longhouse", hx, hz, 13, 18, 0.42, 6, away)
  ringProp("vk/SmallHut", hx, hz, 8, 13, 0.62, 3.2, face)
  ringProp("vk/SmallHut", hx, hz, 8, 14, 0.58, 3.2, face)
  ringProp("vk/StorageHouse", hx, hz, 7, 12, 0.55, 2.6, face)
  ringProp("vk/Campfire", hx, hz, 5.5, 9, 1.0, 1.6)
  ringProp("vk/DryingRackFish", hx, hz, 7, 12, 0.85, 2.2, face)
  ringProp("vk/Cart", hx, hz, 6, 12, 0.8, 2.2)
  for _ = 1, 3 do ringProp("vk/Barrel", hx, hz, 5, 10, 1.0, 0.8) end
  for _ = 1, 3 do ringProp("vk/Crate", hx, hz, 5, 10, 1.0, 0.8) end
  ringProp("vk/BannerA", hx, hz, 4.5, 6, 0.9, 0.8)
  ringProp("vk/BannerB", hx, hz, 4.5, 6, 0.9, 0.8)
  -- the shore: pier, boats, beach huts, torches, big palms
  local sx, sz = S.route[1][1], S.route[1][3]
  local spawnA = math.atan(sz, sx)
  local best, bestA = nil, nil
  for k = 0, 23 do
    local a = k / 24 * pi * 2
    local da = abs(((a - spawnA + pi) % (2 * pi)) - pi)
    -- the camera looks from the south (+z): put the pier on the near shore, away from the raiders' landing
    local score = sin(a) * 2 + da
    if da > 0.9 and (not best or score > best) then best, bestA = score, a end
  end
  if bestA then
    local cx, cz = coastAt(bestA)
    if cx then
      local dx, dz = cos(bestA), sin(bestA)
      local yaw = math.atan(dx, dz)
      local deck = 2.5
      for i = 0, 3 do
        local px, pz = cx + dx * (i * deck - 1), cz + dz * (i * deck - 1)
        local p = prop(i == 3 and "tb/PierEnd" or "tb/PierDeck", px, pz, yaw + pi / 2, 1.0, 1.5)
        if p then p.y = T.water + 0.05 end
      end
      local k1 = prop("tb/Kayak", cx + dx * 3 - dz * 3, cz + dz * 3 + dx * 3, yaw + 0.4, 1.0, 1.2)
      if k1 then k1.y = T.water + 0.02; k1.bob = true end
      if isleIndex == 1 then
        ringProp("tb/Cabana", cx - dx * 6, cz - dz * 6, 2, 7, 0.75, 3)
      end
      for _ = 1, 3 do
        local p = ringProp("tb/TikiTorch", cx - dx * 4, cz - dz * 4, 2, 6, 1.0, 0.8)
        if p then S.torches = S.torches or {}; S.torches[#S.torches + 1] = p end
      end
      ringProp("tb/Kayak", cx - dx * 2, cz - dz * 2, 3, 8, 1.0, 1.4)
    end
  end
  for k = 0, 7 do
    local a = k / 8 * pi * 2 + 0.3
    local cx, cz = coastAt(a)
    if cx then
      local inx, inz = cx - cos(a) * 3, cz - sin(a) * 3
      if freeSpot(inx, inz, 3) then prop(k % 2 == 0 and "tb/PalmTree_A" or "tb/PalmTree_B", inx, inz, random() * 6, 0.65 + random() * 0.2, 2) end
      local rx, rz = cx + cos(a) * 1.2, cz + sin(a) * 1.2
      local p = prop("tb/Rock_B", rx, rz, random() * 6, 1.2 + random(), 1.5)
      if p then p.y = math.max(p.y, T.water - 0.25) end
    end
  end
  -- portal (the raiders' landing): a whirl in the sea at the first route point
  S.portal = {x = S.route[1][1], z = S.route[1][3]}
  -- pads: stone plinths are drawn by the game (empty pads glow softly)
  for _, p in ipairs(S.pads) do p[2] = W.heightAt(p[1], p[3]) end
  for _, p in ipairs(S.route) do p[2] = W.heightAt(p[1], p[3]) end
  return S
end

-- ------------------------------------------------------------------ own meshes
local mesh = {}
function W.init()
  -- crystal (heart, frost tower): an elongated octahedron with flat facets
  local function crystal(r, h)
    local v = {0, h, 0, 0, -h * 0.55, 0}
    local n = 6
    for i = 0, n - 1 do
      local a = i / n * pi * 2
      v[#v + 1], v[#v + 2], v[#v + 3] = cos(a) * r, 0, sin(a) * r
    end
    local idx = {}
    for i = 0, n - 1 do
      local a, b = 3 + i, 3 + (i + 1) % n
      idx[#idx + 1], idx[#idx + 2], idx[#idx + 3] = 1, b, a
      idx[#idx + 1], idx[#idx + 2], idx[#idx + 3] = 2, a, b
    end
    local m = g3d.custom(v, idx, nil, true)
    return m
  end
  mesh.crystal = crystal(0.5, 1.4)
  g3d.material(mesh.crystal, {roughness = 0.15, metallic = 0.1, emissive = "#38F0FF", emissiveStrength = 2.2})
  mesh.ice = crystal(0.35, 0.8)
  g3d.material(mesh.ice, {roughness = 0.1, metallic = 0.0, emissive = "#9AE8FF", emissiveStrength = 1.5})
  mesh.orb = g3d.mesh("sphere", 0.32, 16, 10)
  g3d.material(mesh.orb, {roughness = 0.2, emissive = "#C58BFF", emissiveStrength = 3.0})
  mesh.torus = g3d.mesh("torus", 0.55, 0.05, 20, 6)
  g3d.material(mesh.torus, {roughness = 0.3, metallic = 0.9})
  mesh.barrel = g3d.mesh("cylinder", 0.2, 1.3, 12)
  g3d.material(mesh.barrel, {roughness = 0.35, metallic = 0.85})
  mesh.ball = g3d.mesh("sphere", 0.2, 10, 8)
  g3d.material(mesh.ball, {roughness = 0.4, metallic = 0.6})
  mesh.arrow = g3d.mesh("box", 0.05, 0.05, 0.8)
  mesh.arrow:setColor("#F3E3B0")
  mesh.plinth = g3d.mesh("cylinder", 1.15, 0.4, 16)
  g3d.material(mesh.plinth, {roughness = 0.85})
  mesh.plinth:setColor("#B8A890")
  mesh.disc = g3d.custom({-1, 0, -1, 1, 0, -1, 1, 0, 1, -1, 0, 1}, {1, 3, 2, 1, 4, 3}, nil, false, {0, 0, 1, 0, 1, 1, 0, 1})
  mesh.disc:setTexture("bundle:/tex/ring.png")
  mesh.soft = g3d.custom({-1, 0, -1, 1, 0, -1, 1, 0, 1, -1, 0, 1}, {1, 3, 2, 1, 4, 3}, nil, false, {0, 0, 1, 0, 1, 1, 0, 1})
  mesh.soft:setTexture("bundle:/tex/soft.png")
  mesh.lava = g3d.mesh("cylinder", 4.6, 0.2, 24)
  g3d.material(mesh.lava, {roughness = 0.6, emissive = "#FF5A12", emissiveStrength = 3.5})
  mesh.lava:setColor("#FF6A1A")
  mesh.flag = g3d.mesh("box", 0.6, 0.38, 0.03)
  mesh.bar = g3d.mesh("box", 1, 0.1, 0.1)
  W.mesh = mesh
  buildWater()
end

-- ------------------------------------------------------------------ draw
local tfBuf = {}
function W.draw(t, cam)
  local def = S.def
  g3d.draw(S.terrain, 0, 0, 0)
  -- water: two ripple layers sliding in different directions (the texture repeats every tile, so the slide wraps)
  local wt = S.water
  local o1, o2 = (t * 0.35) % wt.tile, (t * 0.22) % (wt.tile / 0.7)
  g3d.draw(wt.a, o1, S.waterY, o1 * 0.4, 0, 0, 0, 1, 1, 1, def.water .. "C8")
  g3d.draw(wt.b, -o2, S.waterY + 0.03, o2 * 0.8, 0, 0, 0, 1, 1, 1, def.deep .. "50")
  if S.foam then
    local a = 0.72 + 0.28 * sin(t * 1.3)
    g3d.draw(S.foam, 0, 0.02 + 0.05 * sin(t * 1.3), 0, 0, 0, 0, 1, 1, 1, string.format("#FFFFFF%02X", floor(a * 255)))
  end
  -- plants
  for _, g in ipairs(S.plants) do
    g3d.drawInstanced(g.m, g.tf, g.dead and "#6A5A50" or nil)
  end
  -- props
  for _, p in ipairs(S.props) do
    local y = p.y
    if p.bob then y = y + sin(t * 1.4 + p.x) * 0.05 end
    g3d.draw(p.m, p.x, y, p.z, 0, p.yaw, 0, p.s, p.s, p.s)
  end
  -- heart crystal: floats and turns above the shrine ring
  local hx, hy, hz = S.heart[1], S.heart[2], S.heart[3]
  local pulse = S.heartHit and (S.heartHit > 0 and S.heartHit or 0) or 0
  local hc = pulse > 0 and "#FF8080" or nil
  g3d.draw(mesh.crystal, hx, hy + 2.2 + sin(t * 1.6) * 0.18, hz, 0, t * 0.6, 0, 1.15, 1.15, 1.15, hc)
  g3d.draw(mesh.crystal, hx, hy + 2.2 + sin(t * 1.6) * 0.18, hz, 0, -t * 0.4, 0, 1.6, 1.6, 1.6, "#2AD8FF30", "glow unlit nocull")
  g3d.draw(mesh.soft, hx, hy + 0.15, hz, 0, 0, 0, 3.4, 1, 3.4, "#2AB8FF60", "glow unlit nocull")
  -- portal in the sea
  local px, pz = S.portal.x, S.portal.z
  g3d.draw(mesh.disc, px, S.waterY + 0.08, pz, 0, t * 1.2, 0, 4.2, 1, 4.2, "#B04AFF", "glow unlit nocull")
  g3d.draw(mesh.disc, px, S.waterY + 0.1, pz, 0, -t * 2.0, 0, 2.6, 1, 2.6, "#FF5AE0", "glow unlit nocull")
  g3d.draw(mesh.soft, px, S.waterY + 0.06, pz, 0, 0, 0, 4.8, 1, 4.8, "#4A0C6A", "glow unlit nocull")
  -- lava
  if S.crater then
    local cx, cy, cz = S.crater[1], S.crater[2], S.crater[3]
    g3d.draw(mesh.lava, cx, cy + 0.6 + sin(t * 0.7) * 0.08, cz, 0, 0, 0, 1, 1, 1, nil)
    g3d.draw(mesh.soft, cx, cy + 1.2, cz, 0, 0, 0, 9, 1, 9, "#FF6A1A70", "glow unlit nocull")
  end
end

return W
