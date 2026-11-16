-- Neon Drift: engine tiers by revs, drift / nitro / rain loops, one-shots and the race music with a speed layer
-- that joins on bar boundaries (the race track is 120 BPM: one bar = 2 s).
local S = {music = true, sfx = true}
local A = "bundle:/audio/"
local ch = {}
local tier, tierVol = 0, 0
local musicName, musicT0 = nil, 0
local layerOn, layerCh = false, nil
local BAR = 2.0

local function play(name, vol, loops)
  if not S.sfx then return nil end
  return audio.play(A .. "sfx/" .. name .. ".wav", vol or 1, loops or 0)
end
function S.play(name, vol) return play(name, vol) end

local function loop(key, name, on, vol)
  if on and S.sfx then
    if not ch[key] then ch[key] = play(name, vol, -1) end
  elseif ch[key] then
    audio.stop(ch[key]); ch[key] = nil
  end
end

function S.music_(name)
  if musicName == name then return end
  audio.musicStop()
  musicName = nil
  if layerCh then audio.stop(layerCh); layerCh = nil end
  layerOn = false
  if name and S.music then
    audio.music(A .. "music/" .. name .. ".ogg")
    musicName = name
    musicT0 = sys.time()
  end
end
S.music_play = S.music_

-- per frame while racing: car = the player's car (or nil to silence)
function S.engine(car, active, dt)
  if not car or not active then
    if ch.engine then audio.stop(ch.engine); ch.engine = nil end
    tier = 0
    loop("drift", "drift", false); loop("nitro", "nitro_loop", false); loop("scrape", "scrape", false)
    return
  end
  local t
  if car.speed < 2 and car.input.gas == 0 then t = 0 else t = math.max(1, math.min(6, math.floor(car.rpm * 6) + 1)) end
  local vol = car.input.gas > 0 and 0.55 or 0.36
  if t ~= tier or math.abs(vol - tierVol) > 0.1 then
    if ch.engine then audio.stop(ch.engine) end
    ch.engine = play(t == 0 and "idle" or ("engine" .. t), vol, -1)
    tier, tierVol = t, vol
  end
  loop("drift", "drift", (car.drifting or car.slip > 7) and car.speed > 8, 0.45)
  loop("nitro", "nitro_loop", car.nitroOn, 0.5)
  loop("splash", "splash", car.speed > 20, 0.18)
end

-- audio.music plays a song once: restart it at its end so it loops (durations of our own tracks)
local DUR = {race = 64.0, menu = 45.176}
function S.update()
  if musicName and S.music then
    local d = DUR[musicName]
    if d and sys.time() - musicT0 >= d - 0.01 then
      audio.music(A .. "music/" .. musicName .. ".ogg")
      musicT0 = musicT0 + d
      if sys.time() - musicT0 > 1 then musicT0 = sys.time() end
    end
  end
end

function S.rain(on) loop("rain", "rain", on, 0.28) end

-- the speed layer: on when fast, joins and leaves on a bar boundary of the race music
function S.intensity(want)
  if musicName ~= "race" then return end
  local t = sys.time() - musicT0
  local phase = t % BAR
  if want and not layerOn and phase < 0.06 then
    layerCh = audio.play(A .. "music/layer.ogg", 0.55, -1)
    layerOn = true
  elseif not want and layerOn and phase < 0.06 then
    if layerCh then audio.stop(layerCh) end
    layerCh, layerOn = nil, false
  end
end

function S.stopAll()
  for k, c in pairs(ch) do audio.stop(c); ch[k] = nil end
  tier = 0
  if layerCh then audio.stop(layerCh); layerCh = nil end
  layerOn = false
end

function S.setMusic(on)
  S.music = on
  if not on then audio.musicStop(); musicName = nil end
end

return S
