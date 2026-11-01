-- Turbo Isles: an arcade racer on three island circuits, drawn with g3d. Drift for mini-turbos, burn nitro, hit the
-- boost pads and beat five rivals in Grand Prix cups, quick races and time trials against your own ghost.
-- Built on nexvyn.game (scenes, input, menus) with the shared kit (kit.lua).
local game = require("nexvyn.game")
local K = require("kit")
local T = require("track")
local C = require("car")
local G, I, U, A = game.gfx, game.input, game.ui, game.audio
local floor, min, max, sin, cos, abs, pi, sqrt, atan = math.floor, math.min, math.max, math.sin, math.cos, math.abs,
  math.pi, math.sqrt, math.atan

local save = game.save.open("turbo")
local TRd = function(k, ...) return TR(k, ...) end   -- keys built at run time

-- ---------------------------------------------------------------- sound and music
K.track("title", "bundle:/music/title.ogg", 19.2)
K.track("race", "bundle:/music/race.ogg", 13.714)
K.sound("ui_move", "bundle:/sfx/ui_move.wav", 0.6)
K.sound("ui_ok", "bundle:/sfx/ui_ok.wav", 0.7)
K.sound("ui_back", "bundle:/sfx/ui_back.wav", 0.6)
K.sound("beep", "bundle:/sfx/beep.wav", 0.8)
K.sound("go", "bundle:/sfx/go.wav", 0.9)
K.sound("turbo", {"bundle:/sfx/turbo1.wav", "bundle:/sfx/turbo2.wav"}, 0.8)
K.sound("pad", "bundle:/sfx/pad.wav", 0.8, 0.3)
K.sound("nitro", "bundle:/sfx/nitro.wav", 0.7, 0.4)
K.sound("wall", {"bundle:/sfx/wall1.wav", "bundle:/sfx/wall2.wav"}, 0.8, 0.12)
K.sound("bump", "bundle:/sfx/bump.wav", 0.7, 0.15)
K.sound("tier", "bundle:/sfx/tier.wav", 0.6)
K.sound("lap", "bundle:/sfx/lap.wav", 0.8)
K.sound("final", "bundle:/sfx/final.wav", 0.8)
K.sound("finish", "bundle:/sfx/finish.wav", 0.9)
K.sound("drift", "bundle:/sfx/drift.wav", 0.5, 0.2)

-- the engine: short overlapping notes from eight recorded pitches (K.play keeps the channels, so leaving the race
-- or quitting stops them at once)
local engineT, skidT = 0, 0
local engCh, engN = {}, 0
local function engPlay(path, vol)
  local ch = K.play(path, vol)
  if ch then engN = engN % 8 + 1; engCh[engN] = ch end
end
local function stopEngine()
  for i, ch in pairs(engCh) do audio.stop(ch); engCh[i] = nil end
end
local function engineSound(car, dt, on)
  if not on or A.muted or K.P.sfx <= 0 then return end
  engineT = engineT - dt
  if engineT <= 0 then
    engineT = 0.1
    local r = min(1, abs(car.v) / (C.TOP * 1.25) + car.boostK * 0.15)
    local k = 1 + floor(r * 7.99)
    engPlay("bundle:/sfx/engine" .. k .. ".wav", (0.16 + 0.14 * r) * K.P.sfx)
  end
  skidT = skidT - dt
  if (car.drift or (car.skid > 0.25 and abs(car.v) > 15)) and skidT <= 0 then
    skidT = 0.13
    engPlay("bundle:/sfx/skid.wav", 0.18 * K.P.sfx)
  end
end

-- ---------------------------------------------------------------- input
I.bind("gas", {pad = {"a", "zr"}, key = {"up", "w"}})
I.bind("brake", {pad = {"b", "zl"}, key = {"down", "s"}})
I.bind("drift", {pad = {"r", "l"}, key = {"space", "j"}, touch = "button:drift"})
I.bind("nitro", {pad = "x", key = {"n", "k"}, touch = "button:nitro"})
I.bind("cam", {pad = "y", key = "c"})
I.touchControls{stick = true, buttons = {{id = "nitro", icon = "bolt", action = "nitro"},
                                         {id = "drift", icon = "rotate_right", action = "drift"}}}

-- ---------------------------------------------------------------- progress
local GYRO = save:get("gyro", false)
local camMode = save:get("cam", 1)
local function unlocked(what) return save:get("unlock_" .. what, false) end
local function unlock(what)
  if not unlocked(what) then save:set("unlock_" .. what, true); return true end
  return false
end
local function trackName(t, m) return TRd("track_" .. T.TRACKS[t].key) .. (m and (" · " .. TR("mirror")) or "") end
local function fmtTime(t)
  if not t then return "--:--.--" end
  local m = floor(t / 60)
  return string.format("%d:%05.2f", m, t - m * 60)
end

-- ---------------------------------------------------------------- tracks (built once each)
local trackCache = {}
local function getTrack(t, m)
  local key = t .. (m and "m" or "")
  if not trackCache[key] then trackCache[key] = T.build(t, m) end
  return trackCache[key]
end

-- ---------------------------------------------------------------- particles (3D points)
local PMAX = 260
local P = {n = 0}
for i = 1, PMAX do P[i] = {x = 0, y = 0, z = 0, vx = 0, vy = 0, vz = 0, t = 0, life = 1, size = 4, cols = nil, grav = 0} end
local colCache = {}
local function fades(hex)
  local c = colCache[hex]
  if c then return c end
  c = {}
  for k = 0, 7 do c[k] = hex .. string.format("%02X", floor(255 * (1 - k / 8))) end
  colCache[hex] = c
  return c
end
local function emit(x, y, z, vx, vy, vz, life, size, hex, grav)
  if P.n >= PMAX then return end
  P.n = P.n + 1
  local p = P[P.n]
  p.x, p.y, p.z, p.vx, p.vy, p.vz, p.t, p.life, p.size, p.cols, p.grav = x, y, z, vx, vy, vz, 0, life, size, fades(hex), grav or 0
end
local function updateParticles(dt)
  local i = 1
  while i <= P.n do
    local p = P[i]
    p.t = p.t + dt
    if p.t >= p.life then
      P[i], P[P.n] = P[P.n], P[i]
      P.n = P.n - 1
    else
      p.vy = p.vy - p.grav * dt
      p.x, p.y, p.z = p.x + p.vx * dt, p.y + p.vy * dt, p.z + p.vz * dt
      i = i + 1
    end
  end
end
local function drawParticles(cam)
  for i = 1, P.n do
    local p = P[i]
    local dx, dy, dz = p.x - cam.x, p.y - cam.y, p.z - cam.z
    local d = sqrt(dx * dx + dy * dy + dz * dz) + 1
    local k = p.t / p.life
    g3d.point(p.x, p.y, p.z, max(1.5, p.size * (1 + k) * 60 / d), p.cols[floor(k * 7.99)])
  end
end
local TIERCOL = {[0] = "#FFFFFF", "#5CC8FF", "#FFB020", "#D46BFF"}

-- ---------------------------------------------------------------- the 3D view
local flame
local function drawCar(car, alpha)
  if car.recoverT and floor(car.recoverT * 12) % 2 == 0 then return end
  local m = car.meshes
  local tint = alpha and ("#FFFFFF" .. alpha) or nil
  g3d.draw(m.body, car.x, car.y, car.z, car.roll, -car.a, car.pitch, 1, 1, 1, tint)
  g3d.draw(m.lights, car.x, car.y, car.z, car.roll, -car.a, car.pitch, 1, 1, 1, nil, "glow unlit nocull")
  if car.boostK > 0.05 and not alpha then
    local fx, fz = cos(car.a), sin(car.a)
    local s = car.boostK * (0.8 + 0.4 * math.random())
    for side = -1, 1, 2 do
      local rx, rz = -fz * 0.5 * side, fx * 0.5 * side
      g3d.draw(flame, car.x - fx * 2.25 + rx, car.y + 0.55, car.z - fz * 2.25 + rz, 0, -car.a, 0, s, s, s,
        car.nitroOn and "#7FD8FF" or nil, "glow unlit nocull")
    end
  end
end

local function drawWorld(tr, cam, cars, ghost)
  local W, H = game.screenW, game.screenH
  local th = tr.th
  g3d.begin(0, 0, W, H, cam.fov or 62, 0.4, th.fogFar + 120)
  g3d.camera(cam.x, cam.y, cam.z, cam.tx, cam.ty, cam.tz)
  local fx, fz = cam.tx - cam.x, cam.tz - cam.z
  local fl = sqrt(fx * fx + fz * fz) + 1e-6
  fx, fz = fx / fl, fz / fl
  local hx, hy = g3d.project(cam.x + fx * 3000, cam.y, cam.z + fz * 3000)
  local horizon = hy and max(-10, min(H + 10, hy)) or H * 0.5
  -- sky: a panorama of 90 degrees per image (clouds, stars and the far islands baked in), or a gradient
  if tr.sky then
    local img = tr.sky
    local hf = 2 * atan(math.tan(math.rad(cam.fov or 62) / 2) * W / H)
    local pw = W * (pi / 2) / hf
    local ph = pw * img.height / img.width
    local top = horizon - ph * 0.75
    local x0 = (-atan(fz, fx) / (pi / 2) * pw) % pw - pw
    if top > 0 then gfx.rect(0, 0, W, top + 1, 0, th.sky1) end
    gfx.color("#FFFFFF")
    for x = x0, W, pw do gfx.draw(img, x, top, pw + 1, ph) end
    gfx.rect(0, top + ph - 1, W, H, 0, th.fog)
  else
    gfx.gradient(0, 0, W, H, th.sky1, th.sky2)
  end
  -- sun (or moon) and, without textures, far islands projected far away
  local sd = th.sun
  local sx, sy = g3d.project(cam.x + sd[1] * 3000, cam.y + sd[2] * 1300, cam.z + sd[3] * 3000)
  if sx and (sd[1] * fx + sd[3] * fz) > 0 then
    for k = 4, 1, -1 do
      gfx.color(th.sunCol .. string.format("%02X", 18 * k))
      gfx.circle(sx, sy, H * (0.04 + k * 0.035))
    end
    gfx.color(th.sunCol)
    gfx.circle(sx, sy, H * 0.045)
  end
  for _, isle in ipairs(tr.isles) do
    local ca, sa = cos(isle.az), sin(isle.az)
    if ca * fx + sa * fz > 0.15 then
      local R = 3000
      local x1, y1 = g3d.project(cam.x + cos(isle.az - isle.w) * R, cam.y - 40, cam.z + sin(isle.az - isle.w) * R)
      local x2, y2 = g3d.project(cam.x + ca * R, cam.y + isle.h * R * 0.6, cam.z + sa * R)
      local x3, y3 = g3d.project(cam.x + cos(isle.az + isle.w) * R, cam.y - 40, cam.z + sin(isle.az + isle.w) * R)
      if x1 and x2 and x3 then gfx.poly({x1, y1, x2, y2, x3, y3}, isle.col) end
    end
  end
  if not tr.sky then
    gfx.color(th.fog)
    gfx.rect(0, horizon, W, H - horizon + 4)
  end
  g3d.light(sd[1], sd[2], sd[3], th.amb)
  g3d.fog(th.fog, th.fogNear, th.fogFar)
  -- the sea follows the camera in steps of one texture repeat and drifts slowly
  local WT = T.WATER
  local drift = th.night ~= nil or tr.def.theme == "bay"
  local wx = floor(cam.x / WT) * WT + (drift and (game.time * 0.9) % WT or 0)
  local wz = floor(cam.z / WT) * WT + (drift and (game.time * 0.55) % WT or 0)
  g3d.draw(tr.water, wx, -3.6, wz)
  local far = th.fogFar + 70
  local glows = {}
  local drawn = 0
  for _, ch in ipairs(tr.chunks) do
    local dx, dz = ch.x - cam.x, ch.z - cam.z
    local d2 = dx * dx + dz * dz
    if d2 < far * far and (dx * fx + dz * fz > -70 or d2 < 4900) then
      if ch.ground then g3d.draw(ch.ground) end
      if ch.road then g3d.draw(ch.road) end
      if ch.props then g3d.draw(ch.props) end
      if ch.unlit then g3d.draw(ch.unlit, 0, 0, 0, 0, 0, 0, 1, 1, 1, nil, "unlit") end
      if ch.glow then glows[#glows + 1] = ch.glow end
      drawn = drawn + 1
    end
  end
  for _, gm in ipairs(glows) do g3d.draw(gm, 0, 0, 0, 0, 0, 0, 1, 1, 1, nil, "glow unlit nocull") end
  for _, car in ipairs(cars) do
    local dx, dz = car.x - cam.x, car.z - cam.z
    if dx * dx + dz * dz < far * far then drawCar(car) end
  end
  if ghost then drawCar(ghost, "70") end
  drawParticles(cam)
  local tris = g3d.finish()
  K.stat("tris", tris)
  K.stat("chunks", drawn)
  K.stat("particles", P.n)
end

-- chase camera
local function newCam() return {x = 0, y = 5, z = 0, tx = 0, ty = 0, tz = 1, fov = 62, a = 0, shake = 0} end
local function chase(cam, car, dt, mode, snap)
  local k = snap and 1 or (1 - math.exp(-dt * 9))
  local ca = car.a + C.angDiff(car.va, car.a) * 0.45
  cam.a = snap and ca or (cam.a + C.angDiff(ca, cam.a) * min(1, dt * 6))
  local fx, fz = cos(cam.a), sin(cam.a)
  local ex, ey, ez, tx, ty, tz
  if mode == 3 then
    ex, ey, ez = car.x + cos(car.a) * 0.6, car.y + 1.45, car.z + sin(car.a) * 0.6
    tx, ty, tz = car.x + cos(car.a) * 20, car.y + 1.2, car.z + sin(car.a) * 20
    k = 1
  else
    local dist, hgt = mode == 2 and 12.5 or 8.2, mode == 2 and 4.6 or 3.1
    dist = dist + car.boostK * 1.2
    ex, ey, ez = car.x - fx * dist, car.y + hgt, car.z - fz * dist
    tx, ty, tz = car.x + fx * 6, car.y + 1.3, car.z + fz * 6
  end
  cam.x, cam.y, cam.z = cam.x + (ex - cam.x) * k, cam.y + (ey - cam.y) * k, cam.z + (ez - cam.z) * k
  cam.tx, cam.ty, cam.tz = tx, ty, tz
  local sp = min(1, abs(car.v) / C.TOP)
  local fov = 60 + 9 * sp + 7 * car.boostK
  cam.fov = cam.fov + (fov - cam.fov) * min(1, dt * 4)
  if cam.shake > 0 then
    local s = cam.shake * K.shakeScale()
    cam.x, cam.y, cam.z = cam.x + (math.random() - 0.5) * s, cam.y + (math.random() - 0.5) * s, cam.z + (math.random() - 0.5) * s
    cam.shake = max(0, cam.shake - dt * 2.2)
  end
end

-- ---------------------------------------------------------------- events from the physics (sound, sparks, shake)
local function handleEvents(ev, player, cam)
  for i = 1, #ev do
    local e = ev[i]
    local kind, car = e[1], e[2]
    local me = car == player
    if kind == "wall" then
      if me then
        K.sfx("wall", 0.4 + e[3])
        cam.shake = max(cam.shake, 0.4 + e[3] * 0.8)
        K.rumble(0.4 + e[3] * 0.5, 90)
      end
      local s = e[4]
      local x, z = car.x + (-sin(car.a)) * s * 1.1, car.z + cos(car.a) * s * 1.1
      for _ = 1, 14 do
        emit(x, car.y + 0.6, z, (math.random() - 0.5) * 12, 3 + math.random() * 6, (math.random() - 0.5) * 12,
             0.35 + math.random() * 0.3, 4, "#FFC14D", 22)
      end
    elseif kind == "bump" then
      if me or e[3] == player then K.sfx("bump"); K.rumble(0.35, 60); cam.shake = max(cam.shake, 0.3) end
    elseif kind == "turbo" then
      if me then K.sfx("turbo"); K.rumble(0.25 + e[3] * 0.15, 80 + e[3] * 30); cam.shake = max(cam.shake, 0.15 * e[3]) end
    elseif kind == "pad" then
      if me then K.sfx("pad"); K.rumble(0.4, 100); game.flash("#FFD36A", 0.2, 0.25) end
    elseif kind == "tier" then
      if me then K.sfx("tier", 0.6 + e[3] * 0.15) end
    elseif kind == "drift" then
      if me then K.sfx("drift"); K.tipDone("drift") end
    end
  end
end

-- drift sparks, smoke, dust
local function carEffects(car, dt, th)
  local fx, fz = cos(car.a), sin(car.a)
  local rx, rz = -fz, fx
  if car.drift then
    local hex = TIERCOL[car.tier]
    for side = -1, 1, 2 do
      local x, z = car.x - fx * 1.5 + rx * side * 0.95, car.z - fz * 1.5 + rz * side * 0.95
      if math.random() < 0.8 then
        emit(x, car.y + 0.15, z, (math.random() - 0.5) * 4 - fx * 3, 1.5 + math.random() * 3, (math.random() - 0.5) * 4 - fz * 3,
             0.25 + math.random() * 0.2, car.tier > 0 and 5 or 3, hex, 14)
      end
    end
    if math.random() < 0.35 then
      emit(car.x - fx * 2, car.y + 0.3, car.z - fz * 2, -fx * 2, 1.2, -fz * 2, 0.7, 9, "#E8E8F0", -0.5)
    end
  elseif abs(car.lat) > car.hw + 1.5 and abs(car.v) > 10 and math.random() < 0.5 then
    emit(car.x - fx * 2, car.y + 0.3, car.z - fz * 2, -fx * 3 + (math.random() - 0.5) * 3, 1.5, -fz * 3, 0.6, 8, th.verge[1], -0.2)
  end
  if car.nitroOn and math.random() < 0.7 then
    emit(car.x - fx * 2.5, car.y + 0.6, car.z - fz * 2.5, -fx * 6, 0.5, -fz * 6, 0.3, 6, "#7FD8FF", 0)
  end
end

-- ======================================================================== TITLE (attract mode)
local Title, Setup, Race, Standings, Records = {pausable = false}, {pausable = false}, {controls = true}, {pausable = false}, {pausable = false}
local GP = nil   -- the Grand Prix in progress

local function demoRace(t, m, n)
  local tr = getTrack(t, m)
  local cars = {}
  for k = 0, n - 1 do
    local car = C.new(tr, k, C.MODELS[k % 3 + 1], C.AI_COLORS[k % #C.AI_COLORS + 1],
                      {skill = 0.86 + 0.03 * (k % 4), offset = (k % 3 - 1) * 1.6, name = C.AI_NAMES[k + 1]})
    car.hw = tr.w / 2
    cars[#cars + 1] = car
  end
  return tr, cars
end

function Title:enter()
  K.music("title")
  K.clearTips()
  self.t = 0
  self.tr, self.cars = demoRace(1, false, 6)
  self.cam = newCam()
  self.shot, self.shotT = 3, 0   -- open on the wide orbit over the island
  self.ev = {}
  local items = {
    {label = TR("grand_prix"), icon = "emoji_events", action = function() K.go(Setup, {mode = "gp"}) end},
    {label = TR("quick_race"), icon = "flag", action = function() K.go(Setup, {mode = "quick"}) end},
    {label = TR("time_trial"), icon = "timer", action = function() K.go(Setup, {mode = "trial"}) end},
    {label = TR("records"), icon = "military_tech", action = function() K.go(Records) end},
    {label = TR("k_settings"), icon = "tune", action = function() game.push(K.SettingsScene, {fromTitle = true}) end},
    {label = TR("k_help"), icon = "help", action = function()
      game.push(K.HelpScene, {title = TR("k_help"), rows = {
        {action = "gas", text = TR("help_gas")}, {action = "brake", text = TR("help_brake")},
        {action = "drift", text = TR("help_drift")}, {action = "nitro", text = TR("help_nitro")},
        {action = "cam", text = TR("help_cam")}, {icon = "bolt", text = TR("help_pads")},
        {icon = "touch_app", text = TR("help_touch")}, {icon = "screen_rotation", text = TR("help_gyro")},
      }})
    end},
    {label = TR("k_quit"), icon = "logout", action = function() K.quit() end},
  }
  self.menu = K.menu{items = items, width = 200, itemHeight = 28, size = 12, accent = "#FF5A36"}
end
function Title:update(dt)
  self.t = self.t + dt
  self.menu:update()
  for i = 1, #self.ev do self.ev[i] = nil end
  for _, car in ipairs(self.cars) do
    local inp = C.think(car, self.tr, self.cars, nil, nil, dt)
    C.update(car, self.tr, inp, dt, self.ev)
  end
  C.collide(self.cars, self.ev)
  updateParticles(dt)
  self.shotT = self.shotT + dt
  if self.shotT > 7 then self.shotT, self.shot = 0, self.shot % 3 + 1 end
end
function Title:draw()
  K.accent = "#FF5A36"
  local car = self.cars[(floor(self.t / 21) % #self.cars) + 1]
  local cam = self.cam
  local dt = game.dt
  if self.shot == 1 then
    chase(cam, car, dt, 2, self.shotT < 0.05)
  elseif self.shot == 2 then
    -- low side shot travelling with the car
    local fx, fz = cos(car.a), sin(car.a)
    cam.x, cam.y, cam.z = car.x - fz * 7 + fx * 3, car.y + 1.2, car.z + fx * 7 + fz * 3
    cam.tx, cam.ty, cam.tz = car.x, car.y + 0.8, car.z
    cam.fov = 55
  else
    local a = self.t * 0.12
    local tr = self.tr
    cam.x, cam.y, cam.z = tr.cx + cos(a) * 260, 90, tr.cz + sin(a) * 260
    cam.tx, cam.ty, cam.tz = car.x, car.y, car.z
    cam.fov = 40
  end
  drawWorld(self.tr, cam, self.cars)
  -- logo and menu over a soft panel
  G.gradient(0, 0, 250, game.height, "#0A0E1ACC", "#0A0E1A00", true)
  local a = min(1, self.t / 0.6)
  G.alpha(a)
  local lx, ly = 26, 30
  U.text(TR("title_a"), lx, ly, 34, "#FFFFFF", "left", nil, "bold")
  U.text(TR("title_b"), lx + 4, ly + 34, 34, "#FF5A36", "left", nil, "bold")
  G.rect(lx + 2, ly + 76, 120, 3, 1.5, "#FFC93C")
  U.text(TR("tagline"), lx + 2, ly + 84, 11, "#FFFFFFC0", "left", nil, "semibold", false)
  G.unalpha()
  self.menu:draw(lx + 100, 140)
end

-- ======================================================================== SETUP (track, car, options)
function Setup:enter(p)
  K.music("title")
  self.p = p or {mode = "quick"}
  self.mode = self.p.mode
  self.t = 0
  self.track = save:get("lastTrack", 1)
  self.mirror = false
  self.laps = save:get("laps", 3)
  self.rivals = save:get("rivals", 5)
  self.car = save:get("car", 1)
  self.cup = 1
  local items = {}
  local function cyc(field, n, d) self[field] = (self[field] - 1 + d) % n + 1 end
  if self.mode == "gp" then
    items[#items + 1] = {label = TR("cup"), icon = "emoji_events", value = function() return TRd("cup" .. self.cup) end,
      left = function() cyc("cup", 2, -1) end, right = function() cyc("cup", 2, 1) end}
  else
    items[#items + 1] = {label = TR("track"), icon = "map", value = function() return TRd("track_" .. T.TRACKS[self.track].key) end,
      left = function() cyc("track", #T.TRACKS, -1) end, right = function() cyc("track", #T.TRACKS, 1) end}
    items[#items + 1] = {label = TR("mirror"), icon = "flip", value = function()
        return unlocked("mirror") and TR(self.mirror and "k_on" or "k_off") or TR("locked") end,
      left = function() if unlocked("mirror") then self.mirror = not self.mirror end end,
      right = function() if unlocked("mirror") then self.mirror = not self.mirror end end}
  end
  if self.mode == "quick" then
    items[#items + 1] = {label = TR("laps"), icon = "repeat", value = function() return tostring(self.laps) end,
      left = function() self.laps = max(1, self.laps - 1) end, right = function() self.laps = min(7, self.laps + 1) end}
    items[#items + 1] = {label = TR("rivals"), icon = "groups", value = function() return tostring(self.rivals) end,
      left = function() self.rivals = max(0, self.rivals - 1) end, right = function() self.rivals = min(5, self.rivals + 1) end}
  end
  items[#items + 1] = {label = TR("car"), icon = "directions_car", value = function()
      local key = C.MODELS[self.car].key
      return TRd("car_" .. key) .. ((self.car > 1 and not unlocked(key)) and (" · " .. TR("locked")) or "") end,
    left = function() cyc("car", #C.MODELS, -1) end, right = function() cyc("car", #C.MODELS, 1) end}
  items[#items + 1] = {label = TR("start"), icon = "sports_score", action = function() self:start() end}
  items[#items + 1] = {label = TR("k_back"), icon = "arrow_back", action = function() K.go(Title) end}
  self.menu = K.menu{items = items, width = 270, itemHeight = 28, size = 12, accent = "#FF5A36", onBack = function() K.go(Title) end}
  self.cam = newCam()
end
function Setup:carOK()
  local key = C.MODELS[self.car].key
  return self.car == 1 or unlocked(key)
end
function Setup:start()
  if not self:carOK() then
    game.toast(TRd("unlock_" .. C.MODELS[self.car].key), 2.5)
    K.sfx("ui_back")
    return
  end
  if self.mode == "gp" and self.cup == 2 and not unlocked("mirror") then
    game.toast(TR("cup2_locked"), 2.5)
    K.sfx("ui_back")
    return
  end
  save:set("car", self.car)
  if self.mode == "gp" then
    GP = {cup = self.cup, round = 1, points = {}, car = self.car, results = {}}
    K.go(Race, {mode = "gp", track = 1, mirror = self.cup == 2, laps = 3, rivals = 5, car = self.car}, "circle", 0.45)
  else
    save:set("lastTrack", self.track)
    save:set("laps", self.laps)
    save:set("rivals", self.rivals)
    K.go(Race, {mode = self.mode, track = self.track, mirror = self.mirror, laps = self.mode == "trial" and 3 or self.laps,
                rivals = self.mode == "trial" and 0 or self.rivals, car = self.car}, "circle", 0.45)
  end
end
function Setup:update(dt)
  self.t = self.t + dt
  self.menu:update()
end
function Setup:draw()
  K.accent = "#FF5A36"
  local tnum = self.mode == "gp" and 1 or self.track
  local th = T.THEMES[T.TRACKS[tnum].theme]
  local W, H = game.screenW, game.screenH
  local model = C.MODELS[self.car]
  local mesh = C.mesh(model.color, model.stripe, 1)
  if not self.platform then
    self.platform = g3d.mesh("cylinder", 4.2, 0.4, 40)
    self.platform:setColor("#2A2F44")
    self.ring = g3d.mesh("torus", 4.25, 0.08, 48, 6)
    self.ring:setColor("#FF5A36")
  end
  g3d.begin(0, 0, W, H, 40, 0.3, 200)
  g3d.camera(-2.5, 3.2, 10.5, -2.2, 0.9, 0)
  gfx.gradient(0, 0, W, H, th.sky1, th.sky2)
  g3d.light(0.4, 0.9, 0.5, 0.45)
  g3d.draw(self.platform, 1.5, -0.2, 0)
  g3d.draw(self.ring, 1.5, 0.02, 0, 0, 0, 0, 1, 1, 1, nil, "glow unlit nocull")
  local a = self.t * 0.6
  g3d.draw(mesh.body, 1.5, 0.02, 0, 0, a, 0)
  g3d.draw(mesh.lights, 1.5, 0.02, 0, 0, a, 0, 1, 1, 1, nil, "glow unlit nocull")
  g3d.finish()
  G.gradient(0, 0, 330, game.height, "#0A0E1AE0", "#0A0E1A00", true)
  U.text(TRd("mode_" .. self.mode), 24, 22, 22, "#FFFFFF", "left", nil, "bold")
  U.text(TRd("mode_" .. self.mode .. "_d"), 24, 50, 11, "#FFFFFFB0", "left", 280, "semibold", false)
  self.menu:draw(24 + 135, 82)
  -- car stats
  local sx, sy = game.width - 200, game.height - 92
  G.rect(sx - 10, sy - 12, 196, 86, 12, "#0A0E1AB0")
  U.text(TRd("car_" .. model.key), sx, sy - 4, 14, "#FFFFFF", "left", nil, "bold")
  local stats = {{TR("stat_speed"), model.top}, {TR("stat_accel"), model.acc}, {TR("stat_grip"), model.grip}}
  for i, s in ipairs(stats) do
    local y = sy + 16 + (i - 1) * 16
    U.text(s[1], sx, y, 10, "#FFFFFFB0", "left", nil, "semibold", false)
    U.bar(sx + 70, y + 3, 100, 7, (s[2] - 0.8) / 0.4, "#FF5A36")
  end
  if not self:carOK() then
    G.icon("lock", game.width - 40, game.height - 40, 28, "#FFFFFFC0")
    U.text(TRd("unlock_" .. model.key), sx - 200, sy - 36, 11, "#FFD166", "right", 380, "semibold", false)
  end
  if self.mode ~= "gp" then
    local key = self.track .. (self.mirror and "m" or "")
    U.text(TR("best_lap", fmtTime(save:get("lap_" .. key))), game.width - 260, 18, 11, "#FFFFFFD0", "right", 240, "semibold", false)
  else
    local tro = save:get("cup" .. self.cup)
    if tro then
      G.icon("emoji_events", game.width - 34, 28, 22, tro == 1 and "#FFD166" or (tro == 2 and "#D8DEE9" or "#E0A06A"))
    end
  end
end

-- ======================================================================== RACE
local POINTS = {10, 8, 6, 5, 4, 3}
function Race:enter(p)
  self.p = p
  -- building the track and uploading its textures can hold up the first frames; the engine would read that pause in
  -- drawing as a lost focus and open the pause menu, so the race is not pausable until the lights go out
  Race.pausable = false
  K.music("race")
  K.clearTips()
  P.n = 0
  local tr = getTrack(p.track, p.mirror)
  self.tr = tr
  self.cars = {}
  local n = p.rivals
  local diffK = K.pick(0.86, 0.95, 1.03) + (p.mirror and 0.03 or 0) + (GP and GP.cup == 2 and 0.02 or 0)
  for k = 0, n - 1 do
    local model = C.MODELS[k % 3 + 1]
    local car = C.new(tr, k, model, C.AI_COLORS[k % #C.AI_COLORS + 1],
      {skill = diffK - 0.02 * k + 0.012 * (k % 2), offset = ((k % 3) - 1) * 1.5, name = C.AI_NAMES[k + 1]})
    self.cars[#self.cars + 1] = car
  end
  local model = C.MODELS[p.car or 1]
  self.player = C.new(tr, n, model, model.color, nil)
  self.player.name = TR("you")
  self.player.offset, self.player.skill = 0, 1
  self.cars[#self.cars + 1] = self.player
  for _, car in ipairs(self.cars) do car.hw = tr.w / 2 end
  self.cam = newCam()
  self.state, self.t = "intro", 0
  self.count = 3
  self.ev = {}
  self.finishOrder = {}
  self.banner, self.bannerT = nil, 0
  self.wrongT = 0
  self.inp = {gas = 0, brake = 0, steer = 0, drift = false, driftPressed = false, nitro = false}
  self.rocket = false
  self.lastPlace = #self.cars
  -- ghost (time trial)
  self.ghostKey = p.track .. (p.mirror and "m" or "")
  if p.mode == "trial" then
    local g = save:get("ghost_" .. self.ghostKey)
    if type(g) == "table" and type(g.x) == "table" and #g.x > 4 then
      self.ghostData = g
      local m = C.MODELS[g.car or 1]
      self.ghost = {x = 0, y = 0, z = 0, a = 0, roll = 0, pitch = 0, meshes = C.mesh("#C9D4E8", nil, 1), boostK = 0}
      self.ghost.meshes = C.mesh(m.color, m.stripe, 1)
    end
    self.rec = {x = {}, y = {}, z = {}, a = {}, car = p.car or 1}
    self.recT = 0
  end
  self.calib = nil
  -- tips for the first race
  K.tip("gas", TR("tip_gas", K.btn("gas") or "", K.btn("brake") or ""), "sports_score", 5)
  K.tip("drift", TR("tip_drift", K.btn("drift") or TR("tip_stick")), "rotate_right", 8)
  K.tip("nitro", TR("tip_nitro", K.btn("nitro") or "⚡"), "bolt", 6)
  K.tip("pads", TR("tip_pads"), "double_arrow", 5)
  chase(self.cam, self.player, 1 / 60, camMode, true)
end
function Race:restart() K.go(Race, self.p, "fade", 0.25) end
function Race:pauseItems()
  return {{label = TR("camera"), icon = "videocam", value = function() return TRd("cam" .. camMode) end,
           left = function() camMode = (camMode - 2) % 3 + 1; save:set("cam", camMode) end,
           right = function() camMode = camMode % 3 + 1; save:set("cam", camMode) end}}
end
function Race:leaveToMenu() GP = nil end
-- leaving the race (menu, restart, results, quit): no engine or skid note may ring on
function Race:leave()
  stopEngine()
  P.n = 0
end

function Race:readInput(dt)
  local inp = self.inp
  local lx = I.sticks()
  local s = 0
  -- a gentle response curve on the stick: fine corrections near the centre, full lock at the edge
  if abs(lx) > 0.1 then s = (lx > 0 and 1 or -1) * ((abs(lx) - 0.1) / 0.9) ^ 1.35 else s = I.axis("left", "right") end
  local touching = I.touch.stick.active
  if touching then s = I.touch.stick.vx * 1.2 end
  if GYRO then
    local _, _, _, _, _, _, _, roll = input.motion()
    if roll then
      if not self.calib then self.calib = roll end
      local g = (roll - self.calib) * 2.2
      if abs(g) > 0.06 then s = s + g end
    end
  end
  inp.steer = max(-1, min(1, s))
  inp.gas = I.down("gas") and 1 or 0
  inp.brake = I.down("brake") and 1 or 0
  if touching or I.touchVisible() then
    inp.gas = 1
    if touching and I.touch.stick.vy > 0.6 then inp.gas, inp.brake = 0, 1 end
  end
  inp.drift = I.down("drift")
  inp.driftPressed = I.pressed("drift")
  if touching and abs(I.touch.stick.vx) > 0.8 and abs(self.player.v) > C.TOP * 0.55 then
    inp.drift = true
    if not self.player.drift then inp.driftPressed = true end
  end
  inp.nitro = I.down("nitro")
  if I.pressed("cam") then camMode = camMode % 3 + 1; save:set("cam", camMode); K.sfx("ui_move") end
  if inp.gas > 0 then K.tipDone("gas") end
  if inp.nitro and self.player.nitro > 0.05 then K.tipDone("nitro") end
  return inp
end

function Race:banner2(text, sec, color)
  self.banner, self.bannerT, self.bannerCol = text, sec or 1.6, color or "#FFFFFF"
end

function Race:update(dt)
  self.t = self.t + dt
  if Race.pausable == false then
    if not game.focused then game.focused = true end
    if self.state == "race" and self.t > 0.5 then Race.pausable = nil end
  end
  local tr, player = self.tr, self.player
  for i = 1, #self.ev do self.ev[i] = nil end
  if self.bannerT > 0 then self.bannerT = self.bannerT - dt end
  if self.state == "intro" then
    if self.t > 2.6 or I.pressed("confirm") or I.pointer.pressed then
      self.state, self.t, self.count = "count", 0, 3
      K.sfx("beep")
    end
  elseif self.state == "count" then
    local c = 3 - floor(self.t)
    if c < self.count and c > 0 then self.count = c; K.sfx("beep") end
    -- holding gas exactly when the lights go out gives a rocket start
    if self.t > 2.55 and self.t < 3 and I.down("gas") then self.rocket = true end
    if self.t > 2 and self.t < 2.5 and I.down("gas") then self.rocket = false; self.early = true end
    if self.t >= 3 then
      self.state, self.t = "race", 0
      K.sfx("go")
      K.rumble(0.5, 120)
      self:banner2(TR("go"), 0.8, "#7CFF9B")
      if self.rocket and not self.early then
        player.boostT = 1.0
        self:banner2(TR("rocket"), 1.2, "#FFC93C")
        K.sfx("turbo")
      end
      for _, c2 in ipairs(self.cars) do
        if c2.ai and math.random() < 0.4 then c2.boostT = 0.5 end
      end
    end
  end
  local racing = self.state == "race" or self.state == "finish"
  local inp = self:readInput(dt)
  for _, car in ipairs(self.cars) do
    if racing then
      local ci
      if car == player and self.state == "race" then ci = inp
      else ci = C.think(car, tr, self.cars, nil, (car ~= player) and player or nil, dt) end
      if car.finished and car ~= player then ci.gas = 0.6 end
      C.update(car, tr, ci, dt, self.ev)
    else
      car.y = select(4, T.locate(tr, car.x, car.z, car.idx))
    end
  end
  if racing then C.collide(self.cars, self.ev) end
  -- laps, finish and places
  for _, e in ipairs(self.ev) do
    if e[1] == "lap" then
      local car = e[2]
      if car.lap >= self.p.laps and not car.finished then
        car.finished = true
        car.finishTime = car.time
        self.finishOrder[#self.finishOrder + 1] = car
        if car == player then self:playerFinished() end
      elseif car == player then
        local lt = e[3]
        local key = self.ghostKey
        local best = save:get("lap_" .. key)
        if not best or lt < best then
          save:set("lap_" .. key, lt)
          self:banner2(TR("best_lap_new", fmtTime(lt)), 2.0, "#FFD166")
          self:saveGhost(lt)
        else
          self:banner2(TR("lap_time", fmtTime(lt)), 1.6)
        end
        if car.lap == self.p.laps - 1 then self:banner2(TR("final_lap"), 2.0, "#FF5A36"); K.sfx("final")
        else K.sfx("lap") end
      end
    end
  end
  for _, e in ipairs(self.ev) do
    if e[1] == "recover" and e[2] == player then self:banner2(TR("recovered"), 1.2, "#7FD8FF") end
  end
  handleEvents(self.ev, player, self.cam)
  -- ghost recording and playback (time trial)
  if self.rec and self.state == "race" then
    if player.lap ~= self.recLap then self.recLap = player.lap; self.rec.x, self.rec.y, self.rec.z, self.rec.a = {}, {}, {}, {}; self.recT = 0 end
    self.recT = self.recT - dt
    if self.recT <= 0 then
      self.recT = 0.1
      local r = self.rec
      r.x[#r.x + 1] = floor(player.x * 10) / 10
      r.y[#r.y + 1] = floor(player.y * 10) / 10
      r.z[#r.z + 1] = floor(player.z * 10) / 10
      r.a[#r.a + 1] = floor(player.a * 100) / 100
    end
  end
  if self.ghost and racing then
    local g, gd = self.ghost, self.ghostData
    local tt = (player.time - player.lapStart) / 0.1
    local i0 = floor(tt) + 1
    local f = tt - floor(tt)
    if i0 < #gd.x then
      g.x = gd.x[i0] + (gd.x[i0 + 1] - gd.x[i0]) * f
      g.y = gd.y[i0] + (gd.y[i0 + 1] - gd.y[i0]) * f
      g.z = gd.z[i0] + (gd.z[i0 + 1] - gd.z[i0]) * f
      g.a = gd.a[i0] + C.angDiff(gd.a[i0 + 1], gd.a[i0]) * f
      g.hidden = false
    else
      g.hidden = true
    end
  end
  -- places
  local order = {}
  for _, car in ipairs(self.cars) do order[#order + 1] = car end
  local function score(car)
    if car.finished then return 1e9 - (car.finishTime or 0) end
    return C.progress(car, tr)
  end
  table.sort(order, function(a, b) return score(a) > score(b) end)
  for i, car in ipairs(order) do car.place = i end
  self.order = order
  if self.state == "race" and player.place < self.lastPlace and #self.cars > 1 then K.sfx("ui_move") end
  self.lastPlace = player.place
  -- wrong way
  local fx, fz = tr.fx[player.idx], tr.fz[player.idx]
  if self.state == "race" and cos(player.va) * fx + sin(player.va) * fz < -0.3 and abs(player.v) > 4 then
    self.wrongT = self.wrongT + dt
  else
    self.wrongT = 0
  end
  -- effects and sound
  for _, car in ipairs(self.cars) do
    local dx, dz = car.x - self.cam.x, car.z - self.cam.z
    if dx * dx + dz * dz < 6400 then carEffects(car, dt, tr.th) end
  end
  updateParticles(dt)
  engineSound(player, dt, racing and not game.paused)
  if self.state == "finish" then
    self.t2 = (self.t2 or 0) + dt
    if self.t2 > 2.2 and not self.resultsShown then self:showResults() end
    if self.resultsMenu then self.resultsMenu:update() end
  end
  K.stat("cars", #self.cars)
end

function Race:saveGhost(lt)
  if not self.rec or #self.rec.x < 5 then return end
  save:set("ghost_" .. self.ghostKey, {x = self.rec.x, y = self.rec.y, z = self.rec.z, a = self.rec.a, car = self.rec.car, t = lt})
end

function Race:playerFinished()
  local player = self.player
  self.state = "finish"
  self.t2 = 0
  K.sfx("finish")
  K.rumble(0.6, 200)
  local key = self.ghostKey
  if self.p.laps == 3 then
    local best = save:get("race_" .. key)
    if not best or player.time < best then save:set("race_" .. key, player.time); self.newRecord = true end
  end
  save:inc("races", 1)
  if player.place == 1 and #self.cars > 1 then save:inc("wins", 1) end
  self:banner2(player.place == 1 and #self.cars > 1 and TR("you_win") or TR("finished"), 3, "#FFD166")
  if self.p.mode == "quick" and player.place <= 3 and #self.cars >= 4 then
    if unlock("swift") then self.unlockMsg = TR("unlocked_swift") end
  end
end

function Race:results()
  -- every car gets a time: finishers their real one, the others an estimate from their pace
  local tr = self.tr
  local list = {}
  for _, car in ipairs(self.cars) do
    local t = car.finishTime
    if not t then
      local done = max(0.1, C.progress(car, tr))
      t = car.time * (self.p.laps * tr.N) / done
    end
    list[#list + 1] = {car = car, time = t}
  end
  table.sort(list, function(a, b) return a.time < b.time end)
  return list
end

function Race:showResults()
  self.resultsShown = true
  self.final = self:results()
  local items = {}
  if self.p.mode == "gp" then
    for i, r in ipairs(self.final) do
      local key = r.car == self.player and "you" or r.car.name
      GP.points[key] = (GP.points[key] or 0) + (POINTS[i] or 0)
    end
    GP.results[GP.round] = self.player.place
    items[#items + 1] = {label = TR("standings"), icon = "leaderboard", action = function() K.go(Standings, {}) end}
  else
    items[#items + 1] = {label = TR("race_again"), icon = "replay", action = function() self:restart() end}
    items[#items + 1] = {label = TR("change_setup"), icon = "tune", action = function() K.go(Setup, {mode = self.p.mode}) end}
    items[#items + 1] = {label = TR("k_menu"), icon = "home", action = function() K.go(Title) end}
  end
  self.resultsMenu = K.menu{items = items, width = 220, itemHeight = 28, size = 12, accent = "#FF5A36"}
end

-- ---------------------------------------------------------------- race drawing
local MINI = {}
local function minimap(tr, x, y, s, cars, player)
  local key = tr
  local pts = MINI[key]
  if not pts then
    pts = {}
    local w, h = tr.maxx - tr.minx, tr.maxz - tr.minz
    local k = 1 / max(w, h)
    for i = 0, tr.N - 1, 4 do
      pts[#pts + 1] = (tr.px[i] - tr.minx - w / 2) * k
      pts[#pts + 1] = (tr.pz[i] - tr.minz - h / 2) * k
    end
    pts.k, pts.w, pts.h = k, w, h
    MINI[key] = pts
  end
  local sc = {}
  for i = 1, #pts, 2 do sc[i], sc[i + 1] = x + pts[i] * s, y + pts[i + 1] * s end
  G.color("#00000070"); G.lines(sc, 6, true)
  G.color("#FFFFFFD0"); G.lines(sc, 2.5, true)
  for _, car in ipairs(cars) do
    local cx = x + (car.x - tr.minx - pts.w / 2) * pts.k * s
    local cy = y + (car.z - tr.minz - pts.h / 2) * pts.k * s
    if car == player then
      G.circle(cx, cy, 5, "#FFFFFF"); G.circle(cx, cy, 3.6, car.color)
    else
      G.circle(cx, cy, 3, car.color)
    end
  end
end

local ORD = {"st", "nd", "rd"}
local function ordinal(n)
  local s = TRd("ord_" .. n)
  return s
end

function Race:draw()
  K.accent = "#FF5A36"
  local tr, player, cam = self.tr, self.player, self.cam
  local dt = game.dt
  if self.state == "intro" then
    -- a sweeping fly-in to the grid
    local k = min(1, self.t / 2.6)
    local e = 1 - (1 - k) ^ 3
    local a = player.a + pi * (1 - e) * 0.9
    local d = 8.2 + 40 * (1 - e)
    cam.x, cam.y, cam.z = player.x - cos(a) * d, player.y + 3.1 + 22 * (1 - e), player.z - sin(a) * d
    cam.tx, cam.ty, cam.tz = player.x + cos(player.a) * 6, player.y + 1.3, player.z + sin(player.a) * 6
    cam.a = a
    cam.fov = 58
  elseif self.state == "finish" then
    -- a slow orbit around the car after the line
    local a = player.a + pi * 0.5 + (self.t2 or 0) * 0.35
    cam.x, cam.y, cam.z = player.x + cos(a) * 11, player.y + 3.5, player.z + sin(a) * 11
    cam.tx, cam.ty, cam.tz = player.x, player.y + 1, player.z
    cam.fov = 50
  else
    chase(cam, player, dt, camMode)
  end
  drawWorld(tr, cam, self.cars, (self.ghost and not self.ghost.hidden) and self.ghost or nil)
  self:drawHUD()
end

function Race:drawHUD()
  local W, H = game.width, game.height
  local player = self.player
  local t = game.realTime
  -- speed lines while boosting
  if player.boostK > 0.1 and self.state ~= "finish" then
    local n = floor(18 * player.boostK)
    G.color(string.format("#FFFFFF%02X", floor(70 * player.boostK)))
    for i = 1, n do
      local a = (i * 2.399 + t * 0.9) % (2 * pi)
      local r0 = 150 + ((i * 37 + t * 900) % 120)
      G.line(W / 2 + cos(a) * r0, H / 2 + sin(a) * r0 * 0.6, W / 2 + cos(a) * (r0 + 60), H / 2 + sin(a) * (r0 + 60) * 0.6, 1.6)
    end
  end
  if self.state == "intro" then
    U.text(trackName(self.p.track, self.p.mirror), 0, H * 0.18, 26, "#FFFFFF", "center", W, "bold")
    local sub = self.p.mode == "gp" and TR("gp_round", GP and GP.round or 1, 3) or TRd("mode_" .. self.p.mode)
    U.text(sub, 0, H * 0.18 + 34, 13, "#FFC93C", "center", W, "semibold")
    K.prompts({{"confirm", TR("skip")}}, W / 2, H - 30, 10)
    return
  end
  -- position and lap over a soft panel
  G.rect(8, 6, 150, #self.cars > 1 and 104 or 60, 12, "#0A0E1A80")
  if #self.cars > 1 then
    U.text(tostring(player.place), 18, 10, 40, "#FFFFFF", "left", nil, "bold")
    U.text(ordinal(player.place) .. " / " .. #self.cars, 18 + G.textWidth(tostring(player.place), 40, "bold") + 4, 32, 13, "#FFFFFFC0", "left", nil, "bold")
  end
  local lap = min(self.p.laps, player.lap + 1)
  U.text(TR("lap_n", lap, self.p.laps), 18, #self.cars > 1 and 58 or 14, 13, "#FFC93C", "left", nil, "bold")
  U.text(fmtTime(player.time), 18, #self.cars > 1 and 76 or 32, 12, "#FFFFFFD0", "left", nil, "mono")
  if player.best then U.text(TR("best_short", fmtTime(player.best)), 18, #self.cars > 1 and 92 or 48, 10, "#FFFFFF90", "left", nil, "mono", false) end
  -- minimap
  minimap(self.tr, W - 70, 70, 110, self.cars, player)
  -- speedometer
  local cx, cy, R = W - 64, H - 60, 44
  G.circle(cx, cy, R + 6, "#0A0E1AA0")
  local sp = abs(player.v)
  local frac = min(1, sp / (C.TOP * 1.35))
  G.color("#FFFFFF30")
  G.lines(self:arcPts(cx, cy, R, 0.75 * pi, 2.25 * pi, 24), 5)
  G.color(player.boostK > 0.2 and "#7FD8FF" or "#FF5A36")
  G.lines(self:arcPts(cx, cy, R, 0.75 * pi, 0.75 * pi + 1.5 * pi * frac, 24), 5)
  U.text(tostring(floor(sp * 4.5)), cx - 40, cy - 16, 24, "#FFFFFF", "center", 80, "bold")
  U.text(TR("kmh"), cx - 40, cy + 10, 9, "#FFFFFFA0", "center", 80, "semibold", false)
  -- nitro
  local nx, ny = W - 170, H - 30
  G.icon("bolt", nx - 12, ny + 4, 16, player.nitroOn and "#7FD8FF" or "#FFFFFFC0")
  U.bar(nx, ny, 70, 9, player.nitro, player.nitro > 0.25 and "#7FD8FF" or "#4A6A8A")
  -- drift charge
  if player.drift then
    local k = player.tier
    local col = TIERCOL[k]
    local fr = k >= 3 and 1 or (player.driftT - ({0, 0.75, 1.6})[k + 1]) / (({0.75, 1.6, 2.7})[k + 1] - ({0, 0.75, 1.6})[k + 1])
    U.bar(W / 2 - 50, H - 40, 100, 8, fr, col)
    U.text(TRd("tier" .. k), 0, H - 58, 11, col, "center", W, "bold")
  end
  -- banners
  if self.state == "count" then
    local c = 3 - floor(self.t)
    local f = self.t % 1
    local s = 60 * (1.3 - 0.3 * f)
    G.alpha(1 - f * 0.6)
    U.text(tostring(c), 0, H * 0.32 - s / 2, s, "#FFFFFF", "center", W, "bold")
    G.unalpha()
    for i = 1, 3 do
      G.circle(W / 2 + (i - 2) * 30, H * 0.18, 10, "#0A0E1AC0")
      G.circle(W / 2 + (i - 2) * 30, H * 0.18, 7, (4 - c) >= i and "#FF3B3B" or "#3A2020")
    end
  end
  if self.bannerT > 0 and self.banner then
    local a = min(1, self.bannerT * 3)
    G.alpha(a)
    U.text(self.banner, 0, H * 0.24, 24, self.bannerCol, "center", W, "bold")
    G.unalpha()
  end
  if self.wrongT > 1.2 and floor(t * 3) % 2 == 0 then
    U.text(TR("wrong_way"), 0, H * 0.4, 26, "#FF4D4D", "center", W, "bold")
  end
  if self.state == "finish" and self.resultsShown then self:drawResults() end
end

function Race:arcPts(cx, cy, r, a0, a1, n)
  local pts = self.arcBuf or {}
  self.arcBuf = pts
  for i = #pts, 1, -1 do pts[i] = nil end
  for i = 0, n do
    local a = a0 + (a1 - a0) * i / n
    pts[#pts + 1] = cx + cos(a) * r
    pts[#pts + 1] = cy + sin(a) * r
  end
  return pts
end

function Race:drawResults()
  local W, H = game.width, game.height
  local k = min(1, ((self.t2 or 0) - 2.2) / 0.4)
  G.rect(0, 0, W, H, 0, string.format("#000000%02X", floor(120 * k)))
  local pw, ph = 380, 60 + #self.final * 22 + #self.resultsMenu.items * 28 + 20
  local x, y = (W - pw) / 2, (H - ph) / 2 + (1 - k) * 30
  K.frame(x, y, pw, ph, TR("results"), "#FF5A36")
  local ry = y + 48
  for i, r in ipairs(self.final) do
    local me = r.car == self.player
    if me then G.rect(x + 12, ry - 2, pw - 24, 20, 6, "#FF5A3650") end
    U.text(tostring(i), x + 22, ry, 12, "#FFFFFF", "left", nil, "bold", false)
    G.circle(x + 48, ry + 8, 5, r.car.color)
    U.text(r.car.name or "?", x + 60, ry, 12, me and "#FFD166" or "#FFFFFF", "left", nil, "semibold", false)
    U.text((r.car.finishTime and "" or "~") .. fmtTime(r.time), x + pw - 150, ry, 12, "#FFFFFFD0", "right", 70, "mono", false)
    if self.p.mode == "gp" then
      U.text("+" .. (POINTS[i] or 0), x + pw - 70, ry, 12, "#FFC93C", "right", 50, "bold", false)
    end
    ry = ry + 22
  end
  if self.newRecord then U.text(TR("k_new_record"), x, ry, 11, "#FFD166", "center", pw, "bold", false) end
  if self.unlockMsg then U.text(self.unlockMsg, x, ry + 12, 11, "#7CFF9B", "center", pw, "bold", false) end
  self.resultsMenu:draw(W / 2, ry + 28)
end

-- ======================================================================== GRAND PRIX STANDINGS
function Standings:enter()
  K.music("title")
  self.t = 0
  local list = {}
  for name, pts in pairs(GP.points) do list[#list + 1] = {name = name, pts = pts} end
  table.sort(list, function(a, b) return a.pts > b.pts end)
  self.list = list
  self.place = 1
  for i, e in ipairs(list) do if e.name == "you" then self.place = i end end
  self.done = GP.round >= 3
  local items = {}
  if self.done then
    local cup = GP.cup
    local old = save:get("cup" .. cup)
    if self.place <= 3 and (not old or self.place < old) then save:set("cup" .. cup, self.place) end
    self.unlocks = {}
    if self.place <= 3 and unlock("mirror") then self.unlocks[#self.unlocks + 1] = TR("unlocked_mirror") end
    if self.place <= 3 and unlock("swift") then self.unlocks[#self.unlocks + 1] = TR("unlocked_swift") end
    if self.place == 1 and unlock("bolt") then self.unlocks[#self.unlocks + 1] = TR("unlocked_bolt") end
    K.sfx(self.place <= 3 and "finish" or "ui_ok")
    items[#items + 1] = {label = TR("k_menu"), icon = "home", action = function() GP = nil; K.go(Title) end}
  else
    items[#items + 1] = {label = TR("next_race"), icon = "sports_score", action = function()
      GP.round = GP.round + 1
      K.go(Race, {mode = "gp", track = GP.round, mirror = GP.cup == 2, laps = 3, rivals = 5, car = GP.car}, "circle", 0.45)
    end}
    items[#items + 1] = {label = TR("quit_gp"), icon = "close", action = function() GP = nil; K.go(Title) end}
  end
  self.menu = K.menu{items = items, width = 220, itemHeight = 28, size = 12, accent = "#FF5A36"}
end
function Standings:update(dt) self.t = self.t + dt; self.menu:update() end
function Standings:draw()
  K.accent = "#FF5A36"
  local W, H = game.width, game.height
  G.gradient(0, 0, W, H, "#1A1036", "#3B1E4C")
  for i = 1, 30 do
    local x = (i * 97 + self.t * 20 * (i % 3 + 1)) % W
    G.circle(x, (i * 53) % H, 1 + i % 3, "#FFFFFF20")
  end
  local title = self.done and TRd("cup" .. GP.cup) or TR("standings")
  U.text(title, 0, 18, 22, "#FFFFFF", "center", W, "bold")
  U.text(self.done and TR("gp_final") or TR("gp_after", GP.round, 3), 0, 46, 12, "#FFC93C", "center", W, "semibold", false)
  local x, y = W / 2 - 170, 72
  for i, e in ipairs(self.list) do
    local me = e.name == "you"
    local k = min(1, max(0, (self.t - i * 0.08) / 0.3))
    G.alpha(k)
    G.rect(x, y, 340, 24, 8, me and "#FF5A3670" or "#FFFFFF14")
    U.text(tostring(i), x + 12, y + 5, 12, "#FFFFFF", "left", nil, "bold", false)
    U.text(me and TR("you") or e.name, x + 40, y + 5, 12, me and "#FFD166" or "#FFFFFF", "left", nil, "semibold", false)
    U.text(TR("pts", e.pts), x + 220, y + 5, 12, "#FFFFFFD0", "right", 108, "bold", false)
    G.unalpha()
    y = y + 28
  end
  if self.done then
    local col = self.place == 1 and "#FFD166" or (self.place == 2 and "#D8DEE9" or (self.place == 3 and "#E0A06A" or "#FFFFFF60"))
    G.icon("emoji_events", W / 2, y + 26, 40 + 4 * sin(self.t * 3), col)
    for i, u in ipairs(self.unlocks or {}) do
      U.text(u, 0, y + 48 + i * 16, 11, "#7CFF9B", "center", W, "bold", false)
    end
    y = y + 48 + #(self.unlocks or {}) * 16
  end
  self.menu:draw(W / 2, max(y + 20, H - 80))
end

-- ======================================================================== RECORDS
function Records:enter()
  K.music("title")
  self.menu = K.menu{items = {{label = TR("k_back"), icon = "arrow_back", action = function() K.go(Title) end}},
                     width = 200, itemHeight = 28, size = 12, accent = "#FF5A36", onBack = function() K.go(Title) end}
end
function Records:update() self.menu:update() end
function Records:draw()
  K.accent = "#FF5A36"
  local W, H = game.width, game.height
  G.gradient(0, 0, W, H, "#10142A", "#2A1838")
  U.text(TR("records"), 0, 16, 22, "#FFFFFF", "center", W, "bold")
  local x, y = W / 2 - 250, 56
  U.text(TR("best_lap_h"), x + 230, y, 10, "#FFFFFFA0", "left", nil, "bold", false)
  U.text(TR("best_race_h"), x + 370, y, 10, "#FFFFFFA0", "left", nil, "bold", false)
  y = y + 18
  for t = 1, #T.TRACKS do
    for _, m in ipairs({false, true}) do
      local key = t .. (m and "m" or "")
      G.rect(x, y, 500, 24, 8, "#FFFFFF10")
      U.text(trackName(t, m), x + 12, y + 5, 12, "#FFFFFF", "left", nil, "semibold", false)
      U.text(fmtTime(save:get("lap_" .. key)), x + 230, y + 5, 12, "#FFD166", "left", nil, "mono", false)
      U.text(fmtTime(save:get("race_" .. key)), x + 370, y + 5, 12, "#FFFFFFD0", "left", nil, "mono", false)
      y = y + 28
    end
  end
  y = y + 6
  for cup = 1, 2 do
    local p = save:get("cup" .. cup)
    local col = p == 1 and "#FFD166" or (p == 2 and "#D8DEE9" or (p == 3 and "#E0A06A" or "#FFFFFF30"))
    G.icon("emoji_events", x + 20 + (cup - 1) * 250, y + 12, 22, col)
    U.text(TRd("cup" .. cup), x + 38 + (cup - 1) * 250, y + 5, 12, "#FFFFFF", "left", nil, "semibold", false)
  end
  U.text(TR("stats_line", save:get("races", 0), save:get("wins", 0)), 0, y + 34, 11, "#FFFFFFA0", "center", W, "semibold", false)
  self.menu:draw(W / 2, H - 46)
end

-- ======================================================================== run
flame = C.flameMesh()
return K.run{
  width = 640, height = 360, scene = Title, title = Title, background = "#0A0E1A", accent = "#FF5A36", dark = "#05070F",
  controls = {"gas", "brake", "drift", "nitro", "cam"},
  lockDifficulty = true,
  settings = {
    {label = TR("gyro"), icon = "screen_rotation", value = function() return TR(GYRO and "k_on" or "k_off") end,
     left = function() GYRO = not GYRO; save:set("gyro", GYRO) end, right = function() GYRO = not GYRO; save:set("gyro", GYRO) end},
  },
  onReset = function()
    for _, k in ipairs({"unlock_mirror", "unlock_swift", "unlock_bolt", "cup1", "cup2", "races", "wins"}) do save:set(k, nil) end
    for t = 1, #T.TRACKS do
      for _, m in ipairs({"", "m"}) do
        save:set("lap_" .. t .. m, nil); save:set("race_" .. t .. m, nil); save:set("ghost_" .. t .. m, nil)
      end
    end
  end,
}
