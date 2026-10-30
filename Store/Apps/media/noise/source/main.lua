-- White Noise: calming sound generator built only from audio.tone. Continuous sound comes from overlapping
-- chunks that are re-triggered before the previous one ends; textures (rain, waves, fire) come from short
-- bursts at random volumes. Sleep timer with fade-out, animated visuals. Nexvyn OS Lua SDK.
local app = {}

local floor, min, max, sin, cos, pi, random = math.floor, math.min, math.max, math.sin, math.cos, math.pi, math.random
local M = 18

-- ------------------------------------------------------------------ sound recipes
-- A layer plays chunks of `len` seconds every `every` seconds (plus random `jitter`).
-- vol is {lo, hi} (random each chunk) or a function of the clock. Few distinct (freq, len, wave) values are used
-- on purpose: the system caches every distinct chunk and flushes all channels after 96 of them.
local function swell(t)            -- ocean waves: rises and falls over ~8 s
  local c = (1 - cos(2 * pi * t / 8.3)) / 2
  return c ^ 1.6
end

local SOUNDS = {
  {id = "white", icon = "grain", color = "#8E8E93", c2 = "#C7C7CC", layers = {
    {wave = "noise", f = {1}, len = 3, every = 2.95, vol = {0.55, 0.55}},
  }},
  {id = "pink", icon = "blur_on", color = "#FF6F91", c2 = "#FFC2D1", layers = {
    {wave = "noise", f = {1}, len = 3, every = 2.95, vol = {0.30, 0.30}},
    {wave = "sine", f = {110}, len = 3, every = 2.95, vol = {0.10, 0.12}},
    {wave = "triangle", f = {164.81}, len = 3, every = 2.95, vol = {0.05, 0.07}},
  }},
  {id = "brown", icon = "landscape", color = "#A2845E", c2 = "#E0C9A6", layers = {
    {wave = "sine", f = {48, 55, 62}, len = 3, every = 2.95, vol = {0.25, 0.42}},
    {wave = "sine", f = {36.71}, len = 3, every = 2.95, vol = {0.18, 0.26}},
    {wave = "triangle", f = {73.42, 82.41}, len = 3, every = 2.95, vol = {0.08, 0.16}},
    {wave = "noise", f = {1}, len = 3, every = 2.95, vol = {0.05, 0.06}},
  }},
  {id = "rain", icon = "umbrella", color = "#0A84FF", c2 = "#64D2FF", layers = {
    {wave = "noise", f = {1}, len = 3, every = 2.95, vol = {0.17, 0.17}},
    {wave = "noise", f = {1}, len = {0.05, 0.08, 0.12}, every = 0.02, jitter = 0.07, vol = {0.04, 0.34}, curve = 3},
    {wave = "sine", f = {1800, 2150, 2550}, len = 0.03, every = 0.5, jitter = 1.6, vol = {0.02, 0.05}},
  }},
  {id = "ocean", icon = "waves", color = "#30B0C7", c2 = "#A0E7E5", layers = {
    {wave = "noise", f = {1}, len = 3, every = 2.95, vol = {0.07, 0.07}},
    {wave = "noise", f = {1}, len = 0.6, every = 0.24, jitter = 0.1, vol = function(t) return 0.04 + 0.42 * swell(t) end},
    {wave = "sine", f = {55}, len = 3, every = 2.95, vol = {0.06, 0.1}},
  }},
  {id = "fire", icon = "local_fire_department", color = "#FF9F0A", c2 = "#FFD60A", layers = {
    {wave = "noise", f = {1}, len = 3, every = 2.95, vol = {0.12, 0.12}},
    {wave = "sine", f = {55, 62}, len = 3, every = 2.95, vol = {0.12, 0.2}},
    {wave = "noise", f = {1}, len = {0.01, 0.02, 0.03}, every = 0.04, jitter = 0.35, vol = {0.1, 0.55}, curve = 2},
  }},
}

local TIMERS = {0, 15, 30, 45, 60, 90}

-- ------------------------------------------------------------------ state
local sel = 1
local volume = 60                -- 0..100
local timerSel = 1
local playing = false
local clock = 0
local layers = {}                -- {def, nextAt}
local active = {}                -- {ch, endAt}
local endAt = nil                -- sleep timer end (clock), nil = no timer
local fadeOut = 1                -- 1 normal, goes to 0 in the last minute of the sleep timer
local playedVol = 0
local restartAt = 0
local level, levelShown = 0, 0   -- loudness of the last chunks, for the visual
local playAnim = 0
local toast, toastT = "", 0

-- visuals: precomputed particles
local drops, motes, embers = {}, {}, {}
local wavePts = {{}, {}, {}}

local function nameOf(i)
  local id = SOUNDS[i] and SOUNDS[i].id
  if id == "white" then return TR("s_white") elseif id == "pink" then return TR("s_pink")
  elseif id == "brown" then return TR("s_brown") elseif id == "rain" then return TR("s_rain")
  elseif id == "ocean" then return TR("s_ocean") end
  return TR("s_fire")
end

local function descOf(i)
  local id = SOUNDS[i] and SOUNDS[i].id
  if id == "white" then return TR("d_white") elseif id == "pink" then return TR("d_pink")
  elseif id == "brown" then return TR("d_brown") elseif id == "rain" then return TR("d_rain")
  elseif id == "ocean" then return TR("d_ocean") end
  return TR("d_fire")
end

local function showToast(m) toast, toastT = m, 2.6 end

local function mmss(s)
  s = max(0, floor(s + 0.5))
  return string.format("%d:%02d", floor(s / 60), s % 60)
end

-- ------------------------------------------------------------------ engine
local function masterVol()
  local v = volume / 100
  return v * v * fadeOut
end

local function pick(v)
  if type(v) == "table" then return v[random(#v)] end
  return v
end

local function stopAll()
  for _, a in ipairs(active) do
    if a.endAt > clock and a.ch and a.ch >= 0 then audio.stop(a.ch) end
  end
  active = {}
end

local function resetLayers()
  layers = {}
  local s = SOUNDS[sel]
  for i, l in ipairs(s.layers) do layers[i] = {def = l, nextAt = clock + (i - 1) * 0.01} end
end

local function playLayer(l)
  local d = l.def
  local v
  if type(d.vol) == "function" then v = d.vol(clock)
  else
    local r = random()
    if d.curve then r = r ^ d.curve end
    v = d.vol[1] + (d.vol[2] - d.vol[1]) * r
  end
  local len = pick(d.len)
  if len >= 1 then level = max(level * 0.9, v) else level = max(level, v * 0.8) end   -- drives the visual
  v = v * masterVol()
  if v < 0.003 then return end
  local ch = audio.tone(pick(d.f), len, min(1, v), d.wave)
  if ch and ch >= 0 then active[#active + 1] = {ch = ch, endAt = clock + len} end
end

local function startPlay()
  playing = true
  fadeOut = 1
  resetLayers()
  playedVol = volume
  local m = TIMERS[timerSel] or 0
  endAt = m > 0 and clock + m * 60 or nil
  audio.play("click", 0.3)
end

local function stopPlay()
  playing = false
  stopAll()
  endAt = nil
end

local function togglePlay() if playing then stopPlay() else startPlay() end end

local function selectSound(i)
  i = (i - 1) % #SOUNDS + 1
  if i == sel then return end
  sel = i
  store.set("sound", sel)
  if playing then stopAll(); resetLayers() end
end

local function setTimer(i)
  timerSel = max(1, min(#TIMERS, i))
  store.set("timer", timerSel)
  local m = TIMERS[timerSel]
  if playing then
    fadeOut = 1
    endAt = m > 0 and clock + m * 60 or nil
  end
  if m > 0 then showToast(TR("timer_set", m)) else showToast(TR("timer_off")) end
end

local function setVolume(v)
  volume = max(0, min(100, floor(v + 0.5)))
  store.set("volume", volume)
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  sel = max(1, min(#SOUNDS, floor(tonumber(store.get("sound", 1)) or 1)))
  volume = max(0, min(100, floor(tonumber(store.get("volume", 60)) or 60)))
  timerSel = max(1, min(#TIMERS, floor(tonumber(store.get("timer", 1)) or 1)))
  for i = 1, 70 do drops[i] = {x = random(), sp = 0.6 + random() * 0.8, ph = random(), l = 8 + random() * 14} end
  for i = 1, 40 do motes[i] = {x = random(), y = random(), r = 1.5 + random() * 3, sp = 0.2 + random() * 0.6, ph = random() * 6.28} end
  for i = 1, 36 do embers[i] = {x = random(), sp = 0.15 + random() * 0.35, ph = random(), r = 1.5 + random() * 2.5} end
end

function app.update(dt)
  clock = clock + dt
  playAnim = playAnim + ((playing and 1 or 0) - playAnim) * min(1, dt * 5)
  levelShown = levelShown + (level - levelShown) * min(1, dt * 4)
  level = level * (1 - min(1, dt * 0.8))
  if toastT > 0 then toastT = toastT - dt end
  -- drop finished channels from the list
  for i = #active, 1, -1 do if active[i].endAt <= clock then table.remove(active, i) end end
  if not playing then return end

  if endAt then
    local left = endAt - clock
    fadeOut = max(0, min(1, left / 60))
    if left <= 0 then stopPlay(); showToast(TR("sleep_done")); return end
  end
  -- a big volume change restarts the long chunks so it is heard at once
  if math.abs(volume - playedVol) >= 12 and clock >= restartAt then
    playedVol, restartAt = volume, clock + 0.4
    stopAll(); resetLayers()
  end
  for _, l in ipairs(layers) do
    if clock - l.nextAt > 2 then l.nextAt = clock end          -- the app was paused: do not catch up
    local guard = 0
    while clock >= l.nextAt and guard < 4 do
      playLayer(l)
      l.nextAt = l.nextAt + l.def.every + (l.def.jitter and random() * l.def.jitter or 0)
      guard = guard + 1
    end
  end
end

-- ------------------------------------------------------------------ visuals
local function drawVisual(x, y, w, h)
  local s = SOUNDS[sel]
  local t = clock
  gfx.clip(x, y, w, h)
  gfx.gradient(x, y, w, h, theme.dark and "#0E1220" or "#EEF2FA", theme.dark and "#05070D" or "#DCE3F0", false, 16)
  local a = 0.35 + 0.65 * playAnim
  local lv = levelShown
  gfx.alpha(a)
  if s.id == "rain" then
    gfx.color(s.c2)
    for _, d in ipairs(drops) do
      local yy = y + ((t * d.sp * 0.55 + d.ph) % 1) * (h + 40) - 20
      local xx = x + d.x * w + (yy - y) * 0.12
      gfx.line(xx, yy, xx + d.l * 0.12, yy + d.l, 1.5)
    end
    gfx.color(s.color)
    for i = 1, 5 do                         -- ripples at the bottom
      local ph = (t * 0.5 + i * 0.37) % 1
      gfx.alpha(a * (1 - ph) * 0.8)
      gfx.circleLine(x + w * ((i * 0.23 + floor(t * 0.5 + i * 0.37) * 0.31) % 1), y + h - 30, 6 + ph * 30, 1.5)
      gfx.unalpha()
    end
  elseif s.id == "ocean" then
    local sw = swell(t)
    local cols = {s.c2, s.color, "#0A6A8A"}
    for k = 1, 3 do
      local pts = wavePts[k]
      local base = y + h * (0.45 + k * 0.13) - sw * 26 * (1.2 - k * 0.25)
      local n = 0
      for i = 0, 40 do
        local px = x + w * i / 40
        n = n + 1; pts[n] = px
        n = n + 1; pts[n] = base + sin(i * 0.38 + t * (0.8 + k * 0.3) + k) * (10 + sw * 12)
      end
      for i = n + 1, #pts do pts[i] = nil end
      gfx.color(cols[k])
      gfx.lines(pts, 3 + k)
    end
  elseif s.id == "fire" then
    for _, e in ipairs(embers) do
      local ph = (t * e.sp + e.ph) % 1
      local xx = x + w * (0.3 + e.x * 0.4) + sin(t * 2 + e.ph * 10) * 14 * ph
      local yy = y + h - 30 - ph * h * 0.75
      gfx.color(ph < 0.5 and s.c2 or s.color)
      gfx.alpha(a * (1 - ph))
      gfx.circle(xx, yy, e.r * (1 - ph * 0.5))
      gfx.unalpha()
    end
    gfx.color(s.color)
    gfx.alpha(a * 0.25)
    gfx.circle(x + w / 2, y + h - 20, 60 + lv * 60 + sin(t * 9) * 4)
    gfx.unalpha()
  else
    gfx.color(s.c2)
    for _, m in ipairs(motes) do
      local xx = x + ((m.x + t * 0.01 * m.sp) % 1) * w
      local yy = y + ((m.y + sin(t * 0.3 * m.sp + m.ph) * 0.04) % 1) * h
      gfx.alpha(a * (0.4 + 0.4 * sin(t * m.sp + m.ph)))
      gfx.circle(xx, yy, m.r)
      gfx.unalpha()
    end
  end
  -- breathing rings around the play button
  local cx, cy = x + w / 2, y + h / 2
  for i = 1, 3 do
    local br = 60 + i * 22 + sin(t * 0.8 - i * 0.6) * 6 * playAnim + lv * 30 * playAnim
    gfx.color(s.color)
    gfx.alpha(a * (0.22 - i * 0.05))
    gfx.circle(cx, cy, br)
    gfx.unalpha()
  end
  gfx.unalpha()
  gfx.unclip()
end

local function drawPlayButton(cx, cy)
  local s = SOUNDS[sel]
  local r = 46
  gfx.shadow(cx - r, cy - r, 2 * r, 2 * r, r, 16, 5)
  gfx.color(s.color)
  gfx.circle(cx, cy, r)
  gfx.icon(playing and "stop" or "play_arrow", cx, cy, 46, "#FFFFFF")
  if endAt and playing then                   -- sleep timer progress ring
    local total = (TIMERS[timerSel] or 1) * 60
    local frac = max(0, min(1, (endAt - clock) / total))
    gfx.color(theme.separator)
    gfx.circleLine(cx, cy, r + 9, 4)
    gfx.color(s.color)
    if frac > 0.002 then gfx.arc(cx, cy, r + 9, -pi / 2, -pi / 2 + frac * 2 * pi, 4) end
  end
  local hit = ui.hit("play", cx - r - 10, cy - r - 10, 2 * r + 20, 2 * r + 20)
  if hit.clicked then togglePlay() end
end

local function drawToast(w, h)
  if toastT <= 0 then return end
  local a = min(1, toastT * 3, (2.6 - toastT) * 6)
  local tw = gfx.textWidth(toast, 13, "medium") + 32
  local tx, ty = (w - tw) / 2, 14 + (1 - a) * -10
  gfx.alpha(a)
  gfx.shadow(tx, ty, tw, 34, 17, 10, 3)
  gfx.color(theme.text)
  gfx.rect(tx, ty, tw, 34, 17)
  gfx.color(theme.bg)
  gfx.text(toast, tx + 16, ty + 9, 13, "medium")
  gfx.unalpha()
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  -- sound picker
  local n = #SOUNDS
  local cw = (w - 2 * M - (n - 1) * 10) / n
  for i, s in ipairs(SOUNDS) do
    local cx = M + (i - 1) * (cw + 10)
    local on = i == sel
    local hit = ui.hit("snd" .. i, cx, 14, cw, 78)
    if on then
      gfx.color(s.color)
      gfx.alpha(0.18)
      gfx.rect(cx, 14, cw, 78, 12)
      gfx.unalpha()
      gfx.color(s.color)
      gfx.rectLine(cx, 14, cw, 78, 12, 2)
    else
      gfx.color(hit.hovered and theme.hover or theme.field)
      gfx.rect(cx, 14, cw, 78, 12)
      gfx.color(theme.separator)
      gfx.rectLine(cx, 14, cw, 78, 12, 1)
    end
    gfx.icon(s.icon, cx + cw / 2, 42, 28, on and s.color or theme.text2)
    gfx.color(on and theme.text or theme.text2)
    gfx.text(nameOf(i), cx + 2, 64, 12, on and "semibold" or "sans", "center", cw - 4)
    if hit.clicked then selectSound(i) end
  end

  -- visual + play
  local vy, vh = 104, h - 104 - 116
  drawVisual(M, vy, w - 2 * M, vh)
  drawPlayButton(w / 2, vy + vh / 2)
  gfx.color(theme.dark and "#FFFFFFB0" or "#000000A0")
  local status = playing and (endAt and TR("sleep_left", mmss(endAt - clock)) or TR("playing")) or descOf(sel)
  gfx.text(status, M, vy + vh - 30, 13, "medium", "center", w - 2 * M)

  -- volume
  local y = h - 100
  gfx.icon("volume_down", M + 12, y + 15, 22, theme.text2)
  local sw = w - 2 * M - 110
  local v = ui.slider("vol", volume, 0, 100, M + 32, y + 2, sw, 1)
  if v ~= volume then setVolume(v) end
  gfx.icon("volume_up", M + 32 + sw + 16, y + 15, 22, theme.text2)
  gfx.color(theme.text)
  gfx.text(volume .. "%", 0, y + 6, 13, "semibold", "right", w - M)

  -- sleep timer
  local ty = h - 52
  gfx.icon("bedtime", M + 12, ty + 17, 20, theme.text2)
  gfx.color(theme.text2)
  local lw = gfx.text(TR("sleep"), M + 30, ty + 8, 13, "semibold")
  local labels = {TR("off")}
  for i = 2, #TIMERS do labels[i] = tostring(TIMERS[i]) end
  local segX = M + 30 + lw + 12
  local nsel = ui.segmented("timer", labels, timerSel, segX, ty + 2, min(380, w - segX - M - 40), 32)
  if nsel ~= timerSel then setTimer(nsel) end
  gfx.color(theme.text3)
  gfx.text(TR("min"), segX + min(380, w - segX - M - 40) + 8, ty + 10, 12)
  drawToast(w, h)
end

function app.event(e)
  if e.type ~= "keydown" then return end
  local k = e.key
  if k == "space" or k == "enter" then togglePlay()
  elseif k == "right" then selectSound(sel + 1)
  elseif k == "left" then selectSound(sel - 1)
  elseif k == "up" then setVolume(volume + 5)
  elseif k == "down" then setVolume(volume - 5)
  elseif k == "t" then setTimer(timerSel % #TIMERS + 1)
  elseif k == "escape" and playing then stopPlay() end
end

function app.menu()
  local timers = {}
  for i, m in ipairs(TIMERS) do
    timers[i] = {label = m == 0 and TR("timer_none") or TR("n_min", m), id = 100 + i}
  end
  return {
    {title = TR("menu_sound"), items = {
      {label = TR("play_stop"), id = 1, shortcut = "Space"},
      {label = TR("next_sound"), id = 2, shortcut = "→"},
      {label = TR("prev_sound"), id = 3, shortcut = "←"},
      "-",
      {label = TR("louder"), id = 4, shortcut = "↑"},
      {label = TR("quieter"), id = 5, shortcut = "↓"},
    }},
    {title = TR("menu_timer"), items = timers},
  }
end

function app.onmenu(id)
  if id == 1 then togglePlay() elseif id == 2 then selectSound(sel + 1) elseif id == 3 then selectSound(sel - 1)
  elseif id == 4 then setVolume(volume + 5) elseif id == 5 then setVolume(volume - 5)
  elseif id > 100 and id <= 100 + #TIMERS then setTimer(id - 100) end
end

function app.close()
  stopPlay()
  store.save()
  return true
end

return app
