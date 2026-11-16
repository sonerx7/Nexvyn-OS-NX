-- Station Zero: particles, the light pool and sound.
local S = require("sz.state")
local F = {}

local random, sin, cos, sqrt, min, max, pi, floor = math.random, math.sin, math.cos, math.sqrt, math.min, math.max, math.pi, math.floor

-- ---------------------------------------------------------------- sound
local SFX = {click = "tick", door = "door", alarm = "alarm", shoot = "shot", powerup = "save", pop = "tick",
             key = "key", ok = "ok", err = "err", power = "power", spark = "spark", steam = "steam", step = "step",
             zap = "zap", shot = "shot", spot = "spot", lever = "lever", save = "save", launch = "launch",
             whoosh = "whoosh", win = "win", lose = "lose", beep = "beep", tick = "tick", drone = "drone",
             heart = "heart", door_lock = "door_lock"}
F.volume = 1

function F.sound(name, vol)
  local f = SFX[name] or name
  if F.volume <= 0 then return end
  pcall(audio.play, "bundle:/audio/" .. f .. ".ogg", min(1, (vol or 0.8) * F.volume))
end

-- a sound placed in the world: quieter with distance from the player (silent past `range`)
function F.sound3(name, x, z, vol, range)
  local p = S.player
  if not p then F.sound(name, vol) return end
  local d = sqrt((x - p.x) ^ 2 + (z - p.z) ^ 2)
  range = range or 14
  if d >= range then return end
  F.sound(name, (vol or 0.8) * (1 - d / range) ^ 1.5)
end

local musicNow, dangerCh = nil, nil
function F.music(name)
  if musicNow == name then return end
  musicNow = name
  if name then pcall(audio.music, "bundle:/audio/music_" .. name .. ".ogg") else pcall(audio.musicStop) end
end
-- the danger layer: a looping channel over the calm bed while the alert is high
function F.danger(on)
  if on and not dangerCh and F.volume > 0 then
    local ok, ch = pcall(audio.play, "bundle:/audio/music_danger.ogg", 0.55 * F.volume, -1)
    if ok then dangerCh = ch end
  elseif not on and dangerCh then
    pcall(audio.stop, dangerCh)
    dangerCh = nil
  end
end
function F.stopAll()
  F.danger(false)
  F.music(nil)
  pcall(audio.stopAll)
end

-- ---------------------------------------------------------------- particles
-- kinds: spark (falls, orange-white points), steam (rising soft puffs), holo (cyan motes), ember (hit), dust
local P = {}
local MAXP = 360
local puff  -- soft sphere for steam

function F.init()
  P = {}
  if not puff then
    puff = g3d.mesh("sphere", 0.5, 10, 6)
    puff:setColor("#9FB4C0")
  end
end

local function add(kind, x, y, z, vx, vy, vz, life, size)
  if #P >= MAXP then table.remove(P, 1) end
  P[#P + 1] = {k = kind, x = x, y = y, z = z, vx = vx, vy = vy, vz = vz, life = life, max = life, s = size or 1}
end

function F.sparks(x, y, z, n, power)
  power = power or 1
  for _ = 1, n or 14 do
    local a, e = random() * 2 * pi, random() * 0.9
    local sp = (1.5 + random() * 3.5) * power
    add("spark", x, y, z, cos(a) * sp * (1 - e), sp * e + 0.6, sin(a) * sp * (1 - e), 0.35 + random() * 0.5, 1)
  end
end

function F.steam(x, y, z, n)
  for _ = 1, n or 1 do
    add("steam", x + (random() - 0.5) * 0.4, y, z + (random() - 0.5) * 0.4, (random() - 0.5) * 0.3, 1.2 + random() * 0.6,
        (random() - 0.5) * 0.3, 1.6 + random() * 0.8, 0.3 + random() * 0.2)
  end
end

function F.holo(x, y, z)
  add("holo", x + (random() - 0.5) * 0.5, y, z + (random() - 0.5) * 0.5, 0, 0.35 + random() * 0.3, 0, 1.4, 1)
end

function F.burst(x, y, z, color)
  for _ = 1, 22 do
    local a, b = random() * 2 * pi, (random() - 0.3) * pi
    local sp = 1 + random() * 3
    add(color == "red" and "ember" or "spark", x, y, z, cos(a) * cos(b) * sp, sin(b) * sp + 1, sin(a) * cos(b) * sp,
        0.5 + random() * 0.4, 1)
  end
end

function F.update(dt)
  local n = 0
  for i = 1, #P do
    local p = P[i]
    p.life = p.life - dt
    if p.life > 0 then
      if p.k == "spark" or p.k == "ember" then
        p.vy = p.vy - 9.8 * dt
        if p.y < 0.02 and p.vy < 0 then p.vy, p.vx, p.vz = -p.vy * 0.35, p.vx * 0.6, p.vz * 0.6 end
      elseif p.k == "steam" then
        p.vx, p.vz = p.vx * (1 - dt), p.vz * (1 - dt)
        p.s = p.s + dt * 0.55
      end
      p.x, p.y, p.z = p.x + p.vx * dt, p.y + p.vy * dt, p.z + p.vz * dt
      n = n + 1
      P[n] = p
    end
  end
  for i = #P, n + 1, -1 do P[i] = nil end
end

local function hex2(v) return string.format("%02X", max(0, min(255, math.floor(v)))) end

function F.draw(camx, camz)
  for i = 1, #P do
    local p = P[i]
    local f = p.life / p.max
    if p.k == "spark" then
      g3d.point(p.x, p.y, p.z, 2 + 3 * f, f > 0.5 and "#FFF3C8" or "#FF9A3C")
    elseif p.k == "ember" then
      g3d.point(p.x, p.y, p.z, 2 + 3 * f, "#FF4A3A")
    elseif p.k == "holo" then
      g3d.draw(puff, p.x, p.y, p.z, 0, 0, 0, 0.05, 0.05, 0.05, "#2A8FA0", "glow unlit nocull")
    elseif p.k == "steam" then
      local a = f * (1 - f) * 4
      local v = math.floor(26 * a)
      g3d.draw(puff, p.x, p.y, p.z, 0, 0, 0, p.s, p.s, p.s, string.format("#%02X%02X%02X", v, v + 3, v + 6), "glow unlit nocull")
    end
  end
end

-- ---------------------------------------------------------------- lights
-- A fixed pool of g3d lights is moved onto the light sources nearest the player (the renderer takes 16 lights, 8 per
-- object), so a level may have any number of lamps.
local pool, spot, suit = {}, nil, nil
local POOL = 9
F.sources = {}
local pick = 0

function F.lightsReset()
  pcall(g3d.clearLights)
  pool, spot, suit = {}, nil, nil
  F.sources = {}
  for i = 1, POOL do
    pool[i] = g3d.addLight({type = "point", x = 0, y = -50, z = 0, color = "#000000", intensity = 0, range = 1})
  end
  spot = g3d.addLight({type = "spot", x = 0, y = -50, z = 0, dx = 0, dy = -1, dz = 0, color = "#FFFFFF", intensity = 0,
                       range = 12, inner = 14, outer = 26, shadow = true})
  suit = g3d.addLight({type = "point", x = 0, y = -50, z = 0, color = S.C.cyan, intensity = 1.3, range = 3.2})
  pick = 0
end

-- src: {x, y, z, color, intensity, range, kind = "lamp"|"alarm"|"fixed", phase}
function F.addSource(src)
  src.phase = src.phase or random() * 6
  F.sources[#F.sources + 1] = src
  return src
end

local chosen = {}
function F.lightsUpdate(dt, px, pz)
  if not pool[1] then return end
  pick = pick - dt
  if pick <= 0 then
    pick = 0.2
    local list = {}
    for _, s in ipairs(F.sources) do
      if s.on ~= false then
        local d = (s.x - px) ^ 2 + (s.z - pz) ^ 2
        if d < 22 * 22 then list[#list + 1] = {s = s, d = d - (s.boost or 0)} end
      end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    for i = 1, POOL do chosen[i] = list[i] and list[i].s or nil end
  end
  local alarm = S.alarm > 0
  local pulse = 0.55 + 0.45 * sin(S.t * 6)
  for i = 1, POOL do
    local s = chosen[i]
    if s and s.on ~= false then
      local inten, col = s.intensity, s.color
      if s.flicker then inten = inten * (0.75 + 0.25 * sin(S.t * 23 + s.phase) * sin(S.t * 7 + s.phase)) end
      if alarm and s.kind == "lamp" then
        -- in an alarm every other lamp turns red and pulses, the rest drop to a dim cold glow
        if floor(s.x + s.z) % 4 < 2 then inten, col = inten * (0.2 + 0.9 * pulse), "#FF2A2A" else inten = inten * 0.3 end
      end
      if s.kind == "core" then
        local on = S.level and S.level.powered
        col = on and "#7FE8FF" or S.C.amber
        inten = on and inten * 1.2 or inten * (0.55 + 0.35 * sin(S.t * 7 + s.phase) * sin(S.t * 2.3))
      end
      if s.kind == "alarm" then inten = alarm and inten * pulse or 0 end
      g3d.updateLight(pool[i], {x = s.x, y = s.y, z = s.z, color = col, intensity = inten, range = s.range})
    else
      g3d.updateLight(pool[i], {intensity = 0})
    end
  end
end

-- the one shadow-casting spot light: a searchlight (drone) or nothing
function F.spot(x, y, z, dx, dy, dz, color, intensity)
  if not spot then return end
  if not x then g3d.updateLight(spot, {intensity = 0}) return end
  g3d.updateLight(spot, {x = x, y = y, z = z, dx = dx, dy = dy, dz = dz, color = color, intensity = intensity})
end

-- the hero's fill light: between the hero and the camera, so the back of the suit reads against the dark
function F.suit(x, y, z, on)
  if not suit then return end
  g3d.updateLight(suit, {x = x, y = y, z = z, intensity = on and 2.2 or 0, range = 3.6, color = "#BFEFFF"})
end

return F
