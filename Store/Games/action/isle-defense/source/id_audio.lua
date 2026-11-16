-- Isle Defense: sound effects (rate-limited per name so a big wave does not turn into noise), the music (calm
-- adventure theme between waves, battle layer during a wave, title loop) and the island ambience.
local A = {}
local random, min, max = math.random, math.min, math.max

A.sfx = 0.9
A.music = 0.7
local last = {}            -- name -> time it last played
local now = 0
local songName, songCh
local amb = {}

local LIMIT = {bow = 0.07, bow2 = 0.07, arrow_hit = 0.06, hit = 0.06, clang = 0.08, die1 = 0.06, die2 = 0.06, coin = 0.05,
               boom = 0.08, cannon = 0.1, frost = 0.08, zap = 0.08, fire = 0.15, splash = 0.2, heal = 0.4, hover = 0.04}

function A.play(name, vol)
  local lim = LIMIT[name] or 0.03
  if last[name] and now - last[name] < lim then return end
  last[name] = now
  return audio.play("bundle:/snd/" .. name .. ".ogg", min(1, (vol or 1) * A.sfx))
end

function A.song(name)
  if songName == name then return end
  if songCh then audio.stop(songCh); songCh = nil end
  songName = name
  if name and A.music > 0.01 then
    songCh = audio.play("bundle:/snd/mus_" .. name .. ".ogg", min(1, 0.75 * A.music), -1)
  end
end

function A.restartSong()
  local n = songName
  songName = nil
  A.song(n)
end

-- island ambience: surf always, wind on the high islands, the volcano's rumble on the third
function A.ambience(isle)
  for k, ch in pairs(amb) do audio.stop(ch); amb[k] = nil end
  if not isle or A.sfx < 0.01 then return end
  amb.sea = audio.play("bundle:/snd/sea.ogg", 0.28 * A.sfx, -1)
  amb.wind = audio.play("bundle:/snd/wind.ogg", (isle == 2 and 0.18 or 0.12) * A.sfx, -1)
  if isle == 3 then amb.rumble = audio.play("bundle:/snd/rumble.ogg", 0.3 * A.sfx, -1) end
end

function A.update(dt) now = now + dt end

function A.stopAll()
  A.song(nil)
  A.ambience(nil)
  audio.stopAll()
end

return A
