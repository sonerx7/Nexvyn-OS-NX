-- Neon Drift: rendering of the circuit, the cars and the effects (rain, sparks, smoke, nitro flames, wet-road
-- reflection streaks), lights and the chase camera.
local Track = require("nd.track")
local W = {}

local models = {}       -- piece name -> model
local pieceInfo = {}    -- piece name -> {w, h, d}
W.pieces = pieceInfo
W.quality = "quality"
local mesh = {}
local tr                -- current track
local lightIds = {}
local headSpot
local tex = "bundle:/tex/"

---------------------------------------------------------------------------------------------- math
local function mul(a, b)
  local r = {}
  for c = 0, 3 do
    for rr = 0, 3 do
      local s = 0
      for k = 0, 3 do s = s + a[k * 4 + rr + 1] * b[c * 4 + k + 1] end
      r[c * 4 + rr + 1] = s
    end
  end
  return r
end
local function trs(x, y, z, yaw, pitch, roll, sc)
  local cy, sy = math.cos(yaw), math.sin(yaw)
  local cx, sx = math.cos(pitch or 0), math.sin(pitch or 0)
  local cz, sz = math.cos(roll or 0), math.sin(roll or 0)
  sc = sc or 1
  -- R = Ry * Rx * Rz
  local r00 = cy * cz + sy * sx * sz
  local r01 = -cy * sz + sy * sx * cz
  local r02 = sy * cx
  local r10 = cx * sz
  local r11 = cx * cz
  local r12 = -sx
  local r20 = -sy * cz + cy * sx * sz
  local r21 = sy * sz + cy * sx * cz
  local r22 = cy * cx
  return {r00 * sc, r10 * sc, r20 * sc, 0, r01 * sc, r11 * sc, r21 * sc, 0, r02 * sc, r12 * sc, r22 * sc, 0, x, y, z, 1}
end
W.trs = trs
W.mul = mul

---------------------------------------------------------------------------------------------- loading
-- start loading every piece in the background; progress() -> 0..1
local queue, loaded, total = {}, 0, 0
function W.loadPieces()
  local man = json.decode(fs.read("bundle:/pack/manifest.json") or "{}") or {}
  for _, p in ipairs(man.pieces or {}) do
    local b = p.bbox or {-1, 0, -1, 1, 2, 1}
    pieceInfo[p.name] = {w = b[4] - b[1], h = b[5] - b[2], d = b[6] - b[3]}
    queue[#queue + 1] = p.name
  end
  W.night = man.night or {}
  total = #queue + 2
end
-- load one model per call (small files; the caller yields between them so frames keep coming)
function W.loadNext()
  if loaded < #queue then
    local nm = queue[loaded + 1]
    local m, err = g3d.model("bundle:/pack/parts/" .. nm .. ".glb")
    if m then
      models[nm] = m
      -- night look: lit windows, glowing signs (maps made by tools/neondrift_assets.py)
      for mat, nt in pairs(W.night or {}) do
        local k = (mat == "M_SF_ShopWindows") and 0.45 or 1   -- shop windows: warm, not blown out
        if mat == "M_LP_FacadeDowntown" then k = 0.75 end
        g3d.material(m, {emissiveMap = "bundle:/pack/" .. nt.map, emissive = "#FFFFFF", emissiveStrength = nt.strength * k}, mat)
      end
    else print("model " .. nm .. ": " .. tostring(err)) end
  elseif loaded == #queue then
    W.carModel = g3d.model("bundle:/models/car_body.glb")
  else
    W.wheelModel = g3d.model("bundle:/models/car_wheel.glb")
  end
  loaded = loaded + 1
  return loaded >= total
end
function W.progress() return total > 0 and loaded / total or 0 end

local function quadMesh(w, h, texName, ox, oy)
  -- a quad in the x-y plane facing +z, origin at (ox, oy) of its size (0.5, 0.5 = centre)
  ox, oy = ox or 0.5, oy or 0.5
  local x0, x1, y0, y1 = -w * ox, w * (1 - ox), -h * oy, h * (1 - oy)
  local m = g3d.custom({x0, y0, 0, x1, y0, 0, x1, y1, 0, x0, y1, 0}, {1, 2, 3, 1, 3, 4}, nil, true, {0, 1, 1, 1, 1, 0, 0, 0})
  if texName then m:setTexture(tex .. texName) end
  return m
end

function W.init(quality)
  W.quality = quality or "quality"
  g3d.renderer("pbr")
  mesh.glow = quadMesh(1, 1, "glow.png")
  mesh.streak = g3d.custom({-0.5, 0, 0, 0.5, 0, 0, 0.5, 0, 1, -0.5, 0, 1}, {1, 3, 2, 1, 4, 3}, nil, true, {0, 0, 1, 0, 1, 1, 0, 1})
  mesh.streak:setTexture(tex .. "streak.png")
  mesh.smoke = quadMesh(1, 1, "smoke.png")
  -- two crossed quads along +y (0 = nozzle), hot end at v = 0
  mesh.flame = g3d.custom({-0.28, 0, 0, 0.28, 0, 0, 0.28, 1.8, 0, -0.28, 1.8, 0, 0, 0, -0.28, 0, 0, 0.28, 0, 1.8, 0.28, 0, 1.8, -0.28},
    {1, 2, 3, 1, 3, 4, 5, 6, 7, 5, 7, 8}, nil, true, {0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1})
  mesh.flame:setTexture(tex .. "flame.png")
  mesh.rain = g3d.custom({-0.012, 0, 0, 0.012, 0, 0, 0.012, 0.75, 0, -0.012, 0.75, 0}, {1, 2, 3, 1, 3, 4, 1, 3, 2, 1, 4, 3}, nil, true)
  mesh.rain:setColor("#5A6A88")
  mesh.lamp = g3d.mesh("box", 0.7, 0.7, 0.3)
  mesh.shadow = g3d.custom({-1.05, 0, -2.3, 1.05, 0, -2.3, 1.05, 0, 2.3, -1.05, 0, 2.3}, {1, 3, 2, 1, 4, 3}, nil, true, {0, 0, 1, 0, 1, 1, 0, 1})
  mesh.shadow:setTexture(tex .. "glow.png")
  W.applyQuality()
end

function W.applyQuality()
  local q = W.quality == "quality"
  local d = W.dbg or {}
  g3d.postfx({exposure = d.exposure or 1.1, tonemap = "aces", bloom = d.bloom or (q and 0.09 or 0.07), threshold = 0.9,
              msaa = d.msaa or 0, hdr = d.hdr ~= false})
  g3d.shadows(false)
end

---------------------------------------------------------------------------------------------- track
function W.setTrack(t)
  tr = t
  W.visSig = nil
  local d = t.def
  g3d.clearLights()
  lightIds = {}
  local n = W.quality == "quality" and 7 or 4
  for k = 1, n do lightIds[k] = g3d.addLight({type = "point", x = 0, y = -100, z = 0, color = "#FFFFFF", intensity = 0, range = 10}) end
  headSpot = g3d.addLight({type = "spot", x = 0, y = 1, z = 0, dx = 0, dy = -0.2, dz = -1, color = "#DDE8FF",
                           intensity = 22, range = 45, inner = 14, outer = 30})
  W.tailLight = g3d.addLight({type = "point", x = 0, y = -50, z = 0, color = "#FF2030", intensity = 2.5, range = 6})
  W.nitroLight = g3d.addLight({type = "point", x = 0, y = -50, z = 0, color = "#7FB8FF", intensity = 0, range = 9})
  local sky = {}
  for _, f in ipairs({"px", "nx", "py", "ny", "pz", "nz"}) do sky[#sky + 1] = tex .. "sky_" .. f .. ".jpg" end
  g3d.environment({cubemap = sky, intensity = 0.55, sun = 0.35})
  -- materials of the generated chunk meshes
  for _, ch in ipairs(t.chunks) do
    if ch.mRoad then ch.mRoad:setTexture(tex .. "asphalt.jpg"); g3d.material(ch.mRoad, {metallic = 0.0, roughness = 0.5, roughnessMap = tex .. "asphalt_rough.png"}) end
    if ch.mSide then ch.mSide:setTexture(tex .. "concrete.jpg"); g3d.material(ch.mSide, {roughness = 0.45}) end
    if ch.mBarrier then ch.mBarrier:setTexture(tex .. "barrier.jpg"); g3d.material(ch.mBarrier, {roughness = 0.6}) end
    if ch.mConc then ch.mConc:setTexture(tex .. "concrete.jpg"); g3d.material(ch.mConc, {roughness = 0.7}) end
    if ch.mCont then ch.mCont:setTexture(tex .. "container.jpg"); g3d.material(ch.mCont, {roughness = 0.5, metallic = 0.4}) end
    if ch.mTun then ch.mTun:setTexture(tex .. "tunnel.jpg"); g3d.material(ch.mTun, {roughness = 0.35}) end
    if ch.mSigns then
      ch.mSigns:setTexture(tex .. "signs.jpg")
      g3d.material(ch.mSigns, {emissiveMap = tex .. "signs.jpg", emissive = "#FFFFFF", emissiveStrength = 2.6, roughness = 0.4})
    end
    for _, e in ipairs(ch.mEmis) do
      e[1]:setColor("#FFFFFF")
      if W.emisMat then g3d.material(e[1], {emissive = e[2], emissiveStrength = 4.5}) end
    end
  end
  -- ground / water
  local minY = 1e9
  for i = 1, t.N do minY = math.min(minY, t.y[i]) end
  local G = 3000
  local u = G / 24
  mesh.ground = g3d.custom({-G, 0, -G, G, 0, -G, G, 0, G, -G, 0, G}, {1, 3, 2, 1, 4, 3}, nil, true, {0, 0, u, 0, u, u, 0, u})
  if d.water then
    mesh.ground:setColor("#0B1630")
    g3d.material(mesh.ground, {roughness = 0.03, metallic = 0.2})
    W.groundY = minY - 1.4
  else
    mesh.ground:setTexture(tex .. "concrete.jpg")
    g3d.material(mesh.ground, {roughness = 0.55})
    W.groundY = minY - (d.theme == "express" and 1.0 or 0.05)
  end
  -- wall collision
  if W.phys then phys.free(W.phys) end
  W.phys = phys.world({budget = 32})
  phys.addMesh(W.phys, t.walls, t.wallI)
  -- start lamps
  mesh.lampRed = g3d.mesh("box", 0.7, 0.7, 0.3); mesh.lampRed:setColor("#000000")
  g3d.material(mesh.lampRed, {emissive = "#FF1A2A", emissiveStrength = 9})
  mesh.lampGreen = g3d.mesh("box", 0.7, 0.7, 0.3); mesh.lampGreen:setColor("#000000")
  g3d.material(mesh.lampGreen, {emissive = "#2BFF7A", emissiveStrength = 9})
  mesh.lampOff = g3d.mesh("box", 0.7, 0.7, 0.3); mesh.lampOff:setColor("#141418")
  W.initRain()
end

---------------------------------------------------------------------------------------------- cars
function W.makeCarModel(car)
  if not W.carModel then return end
  car.model = g3d.model("bundle:/models/car_body.glb")
  if car.model then
    g3d.material(car.model, {emissive = car.glow, emissiveStrength = 5}, "M_Neon")
    -- a faint glow of its own colour keeps the paint readable on dark streets (a stylised rim light)
    g3d.material(car.model, {metallic = 0.55, roughness = 0.25, clearcoat = 1, clearcoatRoughness = 0.05,
                             emissive = car.color, emissiveStrength = 0.22}, "M_Paint")
  end
end

local WHEELS = {{0.74, 0.34, -1.35, 1}, {-0.74, 0.34, -1.35, -1}, {0.74, 0.34, 1.30, 1}, {-0.74, 0.34, 1.30, -1}}
local function drawCar(car)
  local M = trs(car.x, car.y + 0.02, car.z, car.yaw, car.pitch, car.roll)
  local m = car.model or W.carModel
  if m then g3d.drawMatrix(m, M, car.color) end
  local dx, dz = car.x - W.cam.x, car.z - W.cam.z
  if W.wheelModel and dx * dx + dz * dz < 70 * 70 then
    for k, wd in ipairs(WHEELS) do
      local steer = k <= 2 and -car.steer * 0.9 or 0
      local local_ = trs(wd[1], wd[2], wd[3], steer + (wd[4] < 0 and math.pi or 0), (wd[4] < 0 and 1 or -1) * car.wheelSpin, 0)
      g3d.drawMatrix(W.wheelModel, mul(M, local_))
    end
  end
  -- soft contact shadow
  g3d.draw(mesh.shadow, car.x, car.y + 0.03, car.z, 0, car.yaw, 0, 1, 1, 1, "#000000B0", "unlit nocull")
end

---------------------------------------------------------------------------------------------- particles
local parts = {}
local MAXP = 70
function W.emit(kind, x, y, z, vx, vy, vz, life, size, color)
  if #parts >= MAXP then table.remove(parts, 1) end
  parts[#parts + 1] = {k = kind, x = x, y = y, z = z, vx = vx, vy = vy, vz = vz, t = 0, life = life, s = size, c = color}
end
function W.clearParticles() parts = {} end

function W.updateParticles(dt)
  local j = 0
  for i = 1, #parts do
    local p = parts[i]
    p.t = p.t + dt
    if p.t < p.life then
      if p.k == "spark" then p.vy = p.vy - 14 * dt
      elseif p.k == "smoke" then p.vx, p.vz, p.vy = p.vx * (1 - dt * 1.5), p.vz * (1 - dt * 1.5), p.vy + dt * 0.6
      elseif p.k == "spray" then p.vy = p.vy - 6 * dt end
      p.x, p.y, p.z = p.x + p.vx * dt, p.y + p.vy * dt, p.z + p.vz * dt
      j = j + 1
      parts[j] = p
    end
  end
  for i = j + 1, #parts do parts[i] = nil end
end

local function hexa(c, a)
  return string.sub(c, 1, 7) .. string.format("%02X", math.floor(math.max(0, math.min(1, a)) * 255))
end
W.hexa = hexa

local cam = {x = 0, y = 5, z = 10, tx = 0, ty = 0, tz = 0, fov = 62, yaw = 0, shake = 0}
W.cam = cam

local buckets = {{}, {}, {}, {}}
local function drawParticles()
  for _, b in ipairs(buckets) do for k = #b, 1, -1 do b[k] = nil end end
  for _, p in ipairs(parts) do
    local f = p.t / p.life
    if p.k == "spark" then
      g3d.line(p.x, p.y, p.z, p.x - p.vx * 0.03, p.y - p.vy * 0.03, p.z - p.vz * 0.03, hexa(p.c or "#FFB040", 1 - f), 2)
    else
      -- one instanced draw per fade step instead of one draw per puff
      local yaw = math.atan(cam.x - p.x, cam.z - p.z)
      local sc = p.s * (1 + f * (p.k == "smoke" and 2.2 or 1.2))
      local b = buckets[math.min(4, math.floor(f * 4) + 1)]
      local n = #b
      b[n + 1] = p.x; b[n + 2] = p.y; b[n + 3] = p.z; b[n + 4] = 0; b[n + 5] = yaw; b[n + 6] = 0; b[n + 7] = sc
    end
  end
  for k, b in ipairs(buckets) do
    if #b > 0 then g3d.drawInstanced(mesh.smoke, b, hexa("#BCC0DA", 0.40 * (1 - (k - 0.5) / 4)), "nocull") end
  end
end

---------------------------------------------------------------------------------------------- rain
function W.initRain() end
-- rain: one static mesh of crossed streaks around the origin, drawn twice stacked and scrolled down (2 draws)
local rainMesh, rainMeshLite
local function buildRain(n)
  local v, idx = {}, {}
  local q = 0
  for k = 1, n do
    local a, r = math.random() * math.pi * 2, 4 + math.random() * 26
    local x, y, z = math.cos(a) * r, math.random() * 22, math.sin(a) * r
    for _, d in ipairs({{0.012, 0}, {0, 0.012}}) do
      local dx, dz = d[1], d[2]
      v[#v + 1] = x - dx; v[#v + 1] = y; v[#v + 1] = z - dz
      v[#v + 1] = x + dx; v[#v + 1] = y; v[#v + 1] = z + dz
      v[#v + 1] = x + dx; v[#v + 1] = y + 0.75; v[#v + 1] = z + dz
      v[#v + 1] = x - dx; v[#v + 1] = y + 0.75; v[#v + 1] = z - dz
      idx[#idx + 1] = q + 1; idx[#idx + 1] = q + 2; idx[#idx + 1] = q + 3
      idx[#idx + 1] = q + 1; idx[#idx + 1] = q + 3; idx[#idx + 1] = q + 4
      q = q + 4
    end
  end
  return g3d.custom(v, idx, nil, true)
end
local rainY = 0
local function drawRain(dt, intensity)
  if intensity <= 0 then return end
  if not rainMesh then rainMesh = buildRain(360); rainMeshLite = buildRain(180) end
  local m = (W.quality == "quality" and intensity > 0.6) and rainMesh or rainMeshLite
  rainY = (rainY + dt * 26) % 22
  local col = hexa("#9AB0D8", 0.5 + 0.5 * intensity)
  g3d.draw(m, cam.x, cam.y - 8 - rainY, cam.z, 0, 0, 0, 1, 1, 1, col, "unlit nocull glow")
  g3d.draw(m, cam.x, cam.y - 8 - rainY + 22, cam.z, 0, 0, 0, 1, 1, 1, col, "unlit nocull glow")
end

---------------------------------------------------------------------------------------------- camera
function W.updateCamera(car, dt, mode, nitro, shakeAdd)
  local s, c = math.sin(car.yaw), math.cos(car.yaw)
  local fx, fz = -s, -c
  -- the camera's heading follows the car's heading (and a little of the direction of travel in drifts) with a short
  -- lag; its position is then rigidly behind the car, so the car stays framed at any speed
  local vl = math.sqrt(car.vx * car.vx + car.vz * car.vz)
  local hx, hz = fx, fz
  if vl > 4 then
    hx, hz = fx * 0.6 + car.vx / vl * 0.4, fz * 0.6 + car.vz / vl * 0.4
  end
  local l = math.sqrt(hx * hx + hz * hz)
  hx, hz = hx / l, hz / l
  if not cam.hx or cam.reset then cam.hx, cam.hz, cam.reset = hx, hz, false end
  local k = math.min(1, dt * 6)
  cam.hx, cam.hz = cam.hx + (hx - cam.hx) * k, cam.hz + (hz - cam.hz) * k
  l = math.sqrt(cam.hx * cam.hx + cam.hz * cam.hz)
  hx, hz = cam.hx / l, cam.hz / l
  local spd = car.speed
  local dist, height, lookH = 6.2 + spd * 0.02, 2.1 + spd * 0.005, 1.0
  if mode == 2 then dist, height, lookH = 4.4, 1.5, 0.9 end
  local ex, ey, ez = car.x - hx * dist, car.y + height, car.z - hz * dist
  local tx, ty, tz = car.x + hx * 6, car.y + lookH, car.z + hz * 6
  if mode == 3 then
    ex, ey, ez = car.x + fx * 0.6, car.y + 1.05, car.z + fz * 0.6
    tx, ty, tz = car.x + fx * 20, car.y + 0.9, car.z + fz * 20
  elseif mode == 4 then  -- key-art view (launch argument only): low, front quarter, looking back at the car
    local rx, rz = c, -s
    local side = car.lat > 0 and -1 or 1   -- stay on the road side of the car
    ex, ey, ez = car.x + fx * 5.2 + rx * 2.6 * side, car.y + 0.75, car.z + fz * 5.2 + rz * 2.6 * side
    tx, ty, tz = car.x - fx * 0.5, car.y + 0.6, car.z - fz * 0.5
  end
  -- keep the camera on the road side of the barriers (tight hairpins would swing it into the buildings)
  if W.phys and mode ~= 3 and mode ~= 4 then
    local dx, dy, dz = ex - car.x, ey - (car.y + 1.2), ez - car.z
    local dl = math.sqrt(dx * dx + dy * dy + dz * dz)
    local hit = phys.raycast(W.phys, car.x, car.y + 1.2, car.z, dx / dl, dy / dl, dz / dl, dl)
    if hit then
      local f = math.max(0.25, (hit.dist - 0.4) / dl)
      ex, ey, ez = car.x + dx * f, car.y + 1.2 + dy * f, car.z + dz * f
    end
  end
  cam.x, cam.z = ex, ez
  cam.y = (mode == 3 or mode == 4) and ey or (cam.y + (ey - cam.y) * math.min(1, dt * 8))
  cam.tx, cam.ty, cam.tz = tx, ty, tz
  local fovT = 60 + math.min(1, spd / 70) * 14 + (nitro and 8 or 0)
  cam.fov = cam.fov + (fovT - cam.fov) * math.min(1, dt * 3)
  cam.shake = math.max(cam.shake * math.exp(-dt * 6), (shakeAdd or 0))
  cam.yaw = math.atan(fx, fz)
end

-- free camera for the menu fly-over
function W.setCamera(ex, ey, ez, tx, ty, tz, fov)
  cam.x, cam.y, cam.z, cam.tx, cam.ty, cam.tz, cam.fov = ex, ey, ez, tx, ty, tz, fov or 60
  cam.shake = 0
end

---------------------------------------------------------------------------------------------- frame
local frameT = 0
local instBuf = {}
function W.draw(w, h, cars, player, dt, opts)
  opts = opts or {}
  frameT = frameT + dt
  W.tm0 = sys.time()
  local d = tr.def
  local sx = (math.random() - 0.5) * cam.shake
  local sy = (math.random() - 0.5) * cam.shake
  g3d.begin(0, 0, w, h, cam.fov, 0.3, 1200)
  g3d.camera(cam.x + sx, cam.y + sy, cam.z, cam.tx + sx * 0.5, cam.ty + sy * 0.5, cam.tz)
  g3d.light(0.3, 0.8, -0.4, 0.22, d.moon)
  g3d.fog(d.fog[1], d.fog[2], d.fog[3])

  -- visible chunks: within range and not behind the camera
  local vx, vz = cam.tx - cam.x, cam.tz - cam.z
  local vl = math.sqrt(vx * vx + vz * vz)
  vx, vz = vx / vl, vz / vl
  local range = math.min(W.quality == "quality" and 520 or 380, d.fog[3] + 60)
  local vis, nvis = W.vis or {}, 0
  W.vis = vis
  local key = {}
  for ci, ch in ipairs(tr.chunks) do
    local dx, dz = ch.cx - cam.x, ch.cz - cam.z
    local dd = math.sqrt(dx * dx + dz * dz)
    if dd < range and (dd < 70 or (dx * vx + dz * vz) / dd > 0.25) then
      nvis = nvis + 1
      vis[nvis] = ch
      ch.near = dd < 160
      key[nvis] = ch.near and -ci or ci
      if ch.mRoad then g3d.draw(ch.mRoad, 0, 0, 0) end
      if ch.mSide then g3d.draw(ch.mSide, 0, 0, 0) end
      if ch.mBarrier then g3d.draw(ch.mBarrier, 0, 0, 0) end
      if ch.mConc then g3d.draw(ch.mConc, 0, 0, 0) end
      if ch.mCont then g3d.draw(ch.mCont, 0, 0, 0) end
      if ch.mTun then g3d.draw(ch.mTun, 0, 0, 0) end
      if ch.mSigns then g3d.draw(ch.mSigns, 0, 0, 0, 0, 0, 0, 1, 1, 1, nil, "nocull") end
      if not W.hideEmis then
        for _, e in ipairs(ch.mEmis) do
          if W.emisMat then g3d.draw(e[1], 0, 0, 0) else g3d.draw(e[1], 0, 0, 0, 0, 0, 0, 1, 1, 1, e[2], "unlit nocull") end
        end
      end
    end
  end
  for k = nvis + 1, #vis do vis[k] = nil end
  -- instance lists change only when the set of visible chunks does
  local sig = table.concat(key, ",")
  if sig ~= W.visSig then
    W.visSig = sig
    for k in pairs(instBuf) do instBuf[k] = nil end
    for _, ch in ipairs(vis) do
      for _, set in ipairs(ch.near and {ch.inst, ch.instNear} or {ch.inst}) do
        for nm, l in pairs(set) do
          local b = instBuf[nm]
          if not b then b = {}; instBuf[nm] = b end
          for q = 1, #l do b[#b + 1] = l[q] end
        end
      end
    end
  end
  for nm, b in pairs(instBuf) do
    local m = models[nm]
    if m and #b > 0 and not W.hideModels then g3d.drawInstanced(m, b, tr.def.tint or "#5C6488") end
  end
  g3d.draw(mesh.ground, 0, W.groundY, 0)

  -- start lamps
  if tr.lamps[1] then
    local lit = opts.lamps or 0
    for k, l in ipairs(tr.lamps) do
      local m = (opts.green and mesh.lampGreen) or (k <= lit and mesh.lampRed) or mesh.lampOff
      g3d.draw(m, l.x, l.y, l.z, 0, l.yaw, 0)
    end
  end

  -- lights: the nearest light sources ahead of the camera get the point lights
  local cand = {}
  for _, ch in ipairs(vis) do
    for _, L in ipairs(ch.lights) do
      local dx, dz = L.x - cam.x, L.z - cam.z
      local dd = dx * dx + dz * dz
      if dd < 140 * 140 and (dd < 900 or (dx * vx + dz * vz) > 0) then cand[#cand + 1] = {L, dd} end
    end
  end
  table.sort(cand, function(a, b) return a[2] < b[2] end)
  for k, id in ipairs(lightIds) do
    local c = cand[k]
    if c then
      g3d.updateLight(id, {x = c[1].x, y = c[1].y, z = c[1].z, color = c[1].color, intensity = c[1].int, range = c[1].range})
    else
      g3d.updateLight(id, {intensity = 0})
    end
  end
  -- halos around light sources (glow sprites) and their streaks on the wet road
  local streakN = 0
  for _, ch in ipairs(vis) do for _, S in ipairs(ch.streaks) do
    local dx, dz = S.x - cam.x, S.z - cam.z
    local dd = dx * dx + dz * dz
    if dd < 160 * 160 and dd > 9 and (dx * vx + dz * vz) > 0 and streakN < (W.quality == "quality" and 22 or 12) then
      streakN = streakN + 1
      local dist = math.sqrt(dd)
      local len = math.min(26, 6 + dist * 0.16) * (1 + (S.h or 6) * 0.04)
      local yaw = math.atan(-dx, -dz)
      local a = math.min(1, 0.35 + 30 / dist) * (opts.wet or 1)
      g3d.draw(mesh.streak, S.x, S.y + 0.04, S.z, 0, yaw, 0, 2.2 + dist * 0.014, 1, len, hexa(S.color, 0.8 * a), "unlit nocull glow")
    end
  end end
  for k = 1, math.min(#cand, W.quality == "quality" and 12 or 6) do
    local L = cand[k][1]
    local yaw = math.atan(cam.x - L.x, cam.z - L.z)
    local s = 2.4 + math.sqrt(cand[k][2]) * 0.02
    g3d.draw(mesh.glow, L.x, L.y, L.z, 0, yaw, 0, s, s, s, hexa(L.color, 0.5), "unlit nocull glow")
  end

  -- cars
  for _, car in ipairs(cars) do
    local dx, dz = car.x - W.cam.x, car.z - W.cam.z
    if dx * dx + dz * dz < 300 * 300 and not W.hideCars then drawCar(car) end
  end
  -- headlight spot follows the player (or the leading car in the menu)
  local hc = player or cars[1]
  if hc then
    local s, c = math.sin(hc.yaw), math.cos(hc.yaw)
    g3d.updateLight(headSpot, {x = hc.x - s * 2.3, y = hc.y + 0.75, z = hc.z - c * 2.3, dx = -s, dy = -0.12, dz = -c})
    g3d.updateLight(W.tailLight, {x = hc.x + s * 2.6, y = hc.y + 0.6, z = hc.z + c * 2.6})
    g3d.updateLight(W.nitroLight, {x = hc.x + s * 3, y = hc.y + 0.5, z = hc.z + c * 3, intensity = hc.nitroOn and 8 or 0})
    -- headlight beams on the wet road
    g3d.draw(mesh.streak, hc.x - s * 2.4, hc.y + 0.05, hc.z - c * 2.4, 0, hc.yaw + math.pi, 0, 2.6, 1, 16, "#5A6A8840", "unlit nocull glow")
  end
  -- nitro flames, tail-light glows
  for _, car in ipairs(cars) do
    local s, c = math.sin(car.yaw), math.cos(car.yaw)
    local bx, bz = car.x + s * 2.25, car.z + c * 2.25
    local yawc = math.atan(cam.x - bx, cam.z - bz)
    if car.nitroOn or car.boostT > 0 then
      local fl = 0.8 + math.random() * 0.5
      for k = -1, 1, 2 do
        local px, pz = bx + c * 0.38 * k, bz - s * 0.38 * k
        -- flame: a quad pointing backwards, drawn twice crossed
        g3d.drawMatrix(mesh.flame, trs(px, car.y + 0.42, pz, car.yaw, math.pi / 2, 0, fl), "#9FC8FFE0", "unlit nocull glow")
        g3d.draw(mesh.glow, px, car.y + 0.42, pz, 0, yawc, 0, 1.6 * fl, 1.6 * fl, 1.6 * fl, "#4F7BFF80", "unlit nocull glow")
      end
    end
  end
  if not W.hideFx then
    if not W.hideParts then drawParticles() end
    if not W.hideRain then drawRain(dt, (opts.rain or 0)) end
  end
  -- screen positions for the rival tags
  if player then
    for _, c in ipairs(cars) do
      if c ~= player then
        local dx, dz = c.x - cam.x, c.z - cam.z
        local dd = math.sqrt(dx * dx + dz * dz)
        local want = (dd > 7 and dd < 90 and (dx * vx + dz * vz) > 0) and 1 or 0
        c.tagA = (c.tagA or 0) + (want - (c.tagA or 0)) * math.min(1, dt * 6)
        if want > 0 then
          local px, py = g3d.project(c.x, c.y + 1.9, c.z)
          c.sx, c.sy = px, py
          if not px then c.tagA = 0 end
        end
      end
    end
  end
  local tf = sys.time()
  local tris = g3d.finish()
  W.tris = tris
  local te = sys.time()
  W.tm = W.tm or {pre = 0, fin = 0, n = 0}
  W.tm.pre = W.tm.pre + (tf - W.tm0)
  W.tm.fin = W.tm.fin + (te - tf)
  W.tm.n = W.tm.n + 1
  return tris
end

-- screen position of a world point (call between begin and finish is not needed for the cached camera)
return W
