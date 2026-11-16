-- Crypt Light: sound effects with distance falloff and the adaptive music (drone always, tension and chase layers).
local A = {}
local random, sqrt, min, max = math.random, math.sqrt, math.min, math.max

A.volume = 1.0
A.musicVolume = 0.8
local layers = {}       -- name -> channel
local layerOff = {}     -- name -> seconds since it was last wanted
local heartT = 0
local ambT = 4

local VARIANTS = {step_stone = 4, step_wet = 4, step_sand = 3, moan = 3, drip = 3}

function A.play(name, vol)
  local n = VARIANTS[name]
  local file = n and (name .. random(1, n)) or name
  return audio.play("bundle:/snd/" .. file .. ".ogg", min(1, (vol or 1) * A.volume))
end

-- a sound at a world position: quieter with distance, silent beyond `range`
function A.at(name, x, z, lx, lz, vol, range)
  local dx, dz = x - lx, z - lz
  local d = sqrt(dx * dx + dz * dz)
  range = range or 18
  if d > range then return end
  local g = (1 - d / range)
  A.play(name, (vol or 1) * g * g)
end

local function want(name, on)
  if on then
    layerOff[name] = 0
    if not layers[name] then
      layers[name] = audio.play("bundle:/snd/mus_" .. name .. ".ogg", A.musicVolume * A.volume * (name == "drone" and 0.9 or 0.75), -1)
    end
  elseif layers[name] then
    layerOff[name] = (layerOff[name] or 0)
  end
end

-- danger 0..1: 0 calm, > 0.35 a creature is near or searching, > 0.7 a creature is chasing
function A.update(dt, danger, hpFrac, playing)
  if not playing then return end
  want("drone", true)
  want("tension", danger > 0.35)
  want("chase", danger > 0.7)
  for _, name in ipairs({"tension", "chase"}) do
    if layers[name] and danger <= (name == "tension" and 0.35 or 0.7) then
      layerOff[name] = (layerOff[name] or 0) + dt
      -- hold the layer a while so it does not stutter
      if layerOff[name] > (name == "tension" and 6 or 4) then
        audio.stop(layers[name]); layers[name] = nil
      end
    end
  end
  -- heartbeat: faster with danger and low health
  local stress = max(danger, 1 - hpFrac)
  if stress > 0.45 then
    heartT = heartT - dt
    if heartT <= 0 then
      A.play("heart", 0.35 + stress * 0.5)
      heartT = 1.15 - stress * 0.55
    end
  end
  -- ambience: drips, far moans and rumbles
  ambT = ambT - dt
  if ambT <= 0 then
    local r = random()
    if r < 0.5 then A.play("drip", 0.25 + random() * 0.2)
    elseif r < 0.8 then A.play("moan", 0.12 + random() * 0.12)
    else A.play("rumble", 0.25) end
    ambT = 3 + random() * 7
  end
end

function A.stopMusic()
  for name, ch in pairs(layers) do audio.stop(ch) end
  layers, layerOff = {}, {}
end

function A.title(on)
  if on and not layers.title then
    A.stopMusic()
    layers.title = audio.play("bundle:/snd/mus_title.ogg", A.musicVolume * A.volume * 0.85, -1)
  elseif not on and layers.title then
    audio.stop(layers.title); layers.title = nil
  end
end

function A.stopAll()
  A.stopMusic()
  audio.stopAll()
end

return A
