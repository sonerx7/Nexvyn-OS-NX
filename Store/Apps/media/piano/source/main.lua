-- Piano for Nexvyn OS: three playable octaves, four waveforms, octave shift, recording & playback,
-- demo songs with animated keys and a light-bar visualizer.
local app = {}

local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi

-- ------------------------------------------------------------------ colors
local cache = {}
local function rgba(c)
  local t = cache[c]
  if not t then
    t = {tonumber(c:sub(2, 3), 16) or 0, tonumber(c:sub(4, 5), 16) or 0, tonumber(c:sub(6, 7), 16) or 0,
         #c >= 9 and (tonumber(c:sub(8, 9), 16) or 255) or 255}
    cache[c] = t
  end
  return t
end
local function alpha(c, a)
  local t = rgba(c)
  return {t[1], t[2], t[3], max(0, min(255, floor(t[4] * a + 0.5)))}
end
local function mix(c1, c2, k)
  local a, b = rgba(c1), rgba(c2)
  return {floor(a[1] + (b[1] - a[1]) * k + 0.5), floor(a[2] + (b[2] - a[2]) * k + 0.5),
          floor(a[3] + (b[3] - a[3]) * k + 0.5), floor(a[4] + (b[4] - a[4]) * k + 0.5)}
end

-- ------------------------------------------------------------------ music data
local WAVES = {"sine", "square", "saw", "triangle"}
local WAVE_KEYS = {"wave_sine", "wave_square", "wave_saw", "wave_triangle"}
local NOTE_NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local BLACK = {[1] = true, [3] = true, [6] = true, [8] = true, [10] = true}
local NOTE_COLORS = {"red", "red", "orange", "orange", "yellow", "green", "green", "#30B0C7", "#30B0C7", "blue", "blue", "purple"}

-- computer keyboard -> semitone offset from the active octave's C
local KEYMAP = {a = 0, w = 1, s = 2, e = 3, d = 4, f = 5, t = 6, g = 7, y = 8, h = 9, u = 10, j = 11, k = 12, o = 13, l = 14}
local KEYLABEL = {}
for k, v in pairs(KEYMAP) do KEYLABEL[v] = k:upper() end

-- demo songs: {midi or 0 for rest, beats}
local SONGS = {
  {key = "song_ode", bpm = 120, notes = {
    {64, 1}, {64, 1}, {65, 1}, {67, 1}, {67, 1}, {65, 1}, {64, 1}, {62, 1}, {60, 1}, {60, 1}, {62, 1}, {64, 1}, {64, 1.5}, {62, 0.5}, {62, 2},
    {64, 1}, {64, 1}, {65, 1}, {67, 1}, {67, 1}, {65, 1}, {64, 1}, {62, 1}, {60, 1}, {60, 1}, {62, 1}, {64, 1}, {62, 1.5}, {60, 0.5}, {60, 2},
    {62, 1}, {62, 1}, {64, 1}, {60, 1}, {62, 1}, {64, 0.5}, {65, 0.5}, {64, 1}, {60, 1},
    {62, 1}, {64, 0.5}, {65, 0.5}, {64, 1}, {62, 1}, {60, 1}, {62, 1}, {55, 2},
    {64, 1}, {64, 1}, {65, 1}, {67, 1}, {67, 1}, {65, 1}, {64, 1}, {62, 1}, {60, 1}, {60, 1}, {62, 1}, {64, 1}, {62, 1.5}, {60, 0.5}, {60, 2}}},
  {key = "song_twinkle", bpm = 110, notes = {
    {60, 1}, {60, 1}, {67, 1}, {67, 1}, {69, 1}, {69, 1}, {67, 2}, {65, 1}, {65, 1}, {64, 1}, {64, 1}, {62, 1}, {62, 1}, {60, 2},
    {67, 1}, {67, 1}, {65, 1}, {65, 1}, {64, 1}, {64, 1}, {62, 2}, {67, 1}, {67, 1}, {65, 1}, {65, 1}, {64, 1}, {64, 1}, {62, 2},
    {60, 1}, {60, 1}, {67, 1}, {67, 1}, {69, 1}, {69, 1}, {67, 2}, {65, 1}, {65, 1}, {64, 1}, {64, 1}, {62, 1}, {62, 1}, {60, 2}}},
  {key = "song_elise", bpm = 160, notes = {
    {76, 0.5}, {75, 0.5}, {76, 0.5}, {75, 0.5}, {76, 0.5}, {71, 0.5}, {74, 0.5}, {72, 0.5}, {69, 1.5},
    {60, 0.5}, {64, 0.5}, {69, 0.5}, {71, 1.5}, {64, 0.5}, {68, 0.5}, {71, 0.5}, {72, 1.5}, {64, 0.5},
    {76, 0.5}, {75, 0.5}, {76, 0.5}, {75, 0.5}, {76, 0.5}, {71, 0.5}, {74, 0.5}, {72, 0.5}, {69, 1.5},
    {60, 0.5}, {64, 0.5}, {69, 0.5}, {71, 1.5}, {64, 0.5}, {72, 0.5}, {71, 0.5}, {69, 2.5}}},
  {key = "song_jacques", bpm = 130, notes = {
    {60, 1}, {62, 1}, {64, 1}, {60, 1}, {60, 1}, {62, 1}, {64, 1}, {60, 1},
    {64, 1}, {65, 1}, {67, 2}, {64, 1}, {65, 1}, {67, 2},
    {67, 0.5}, {69, 0.5}, {67, 0.5}, {65, 0.5}, {64, 1}, {60, 1}, {67, 0.5}, {69, 0.5}, {67, 0.5}, {65, 0.5}, {64, 1}, {60, 1},
    {60, 1}, {55, 1}, {60, 2}, {60, 1}, {55, 1}, {60, 2}}},
}

-- ------------------------------------------------------------------ state
local wave = 4
local base = 3                 -- visible range: C(base) .. C(base + 3)
local sustain = false
local volume = 0.8
local held = {}                -- midi -> {source = true}
local voices = {}              -- midi -> {ch1, ch2, t}
local glow = {}                -- midi -> 0..1 animation
local bars = {}                -- rising light bars {m, t0, t1}
local recording = false
local recStart = 0
local recOpen = {}             -- midi -> start time while recording
local recEvents = {}           -- {t, m, d}
local player = nil             -- {events, idx, start, offs, kind}
local song = 1
local selected = 60
local lastInput = "touch"
local ptrNote = nil
local ptrDown = false
local layout = {keys = {}, x = 0, y = 0, w = 0, h = 0, ww = 0, rollTop = 0, rollBottom = 0}
local layoutKey = ""
local padRepeat = {}

local function lowNote() return 12 * (base + 1) end
local function highNote() return lowNote() + 36 end
local function freq(m) return 440 * 2 ^ ((m - 69) / 12) end
local function noteName(m) return NOTE_NAMES[m % 12 + 1] .. tostring(floor(m / 12) - 1) end
local function noteColor(m)
  local c = NOTE_COLORS[m % 12 + 1]
  if c:sub(1, 1) == "#" then return c end
  return theme[c]
end

local function save()
  store.set("wave", wave)
  store.set("base", base)
  store.set("sustain", sustain)
  store.set("volume", volume)
end

-- ------------------------------------------------------------------ sound
local function soundOn(m)
  local wv = WAVES[wave]
  local loud = (wv == "square" or wv == "saw") and 0.16 or 0.3
  local v = loud * volume
  local f = freq(m)
  local now = sys.time()
  -- two layers: a bright attack and a longer, softer body give a simple decay envelope
  local c1 = audio.tone(f, 0.22, v, wv)
  local c2 = audio.tone(f, 1.6, v * 0.6, wv)
  voices[m] = {c1, c2, now}
end

local function soundOff(m)
  local v = voices[m]
  if not v then return end
  voices[m] = nil
  if sustain then return end
  local age = sys.time() - v[3]
  -- only stop channels that are still ours (a finished channel may already play another sound)
  if age < 0.22 and v[1] and v[1] >= 0 then audio.stop(v[1]) end
  if age < 1.6 and v[2] and v[2] >= 0 then audio.stop(v[2]) end
end

local function press(m, src)
  local h = held[m]
  if not h then
    h = {}
    held[m] = h
  end
  if h[src] then return end
  local first = next(h) == nil
  h[src] = true
  if first then
    soundOn(m)
    glow[m] = 1
    if src:sub(1, 4) ~= "auto" then
      bars[#bars + 1] = {m = m, t0 = sys.time()}
      if recording then recOpen[m] = sys.time() - recStart end
    end
  end
end

local function release(m, src)
  local h = held[m]
  if not h or not h[src] then return end
  h[src] = nil
  if next(h) == nil then
    held[m] = nil
    soundOff(m)
    for i = #bars, 1, -1 do
      if bars[i].m == m and not bars[i].t1 then bars[i].t1 = sys.time(); break end
    end
    if recOpen[m] then
      local t0 = recOpen[m]
      recOpen[m] = nil
      recEvents[#recEvents + 1] = {t = t0, m = m, d = max(0.08, sys.time() - recStart - t0)}
    end
  end
end

local function releaseAll(prefix)
  for m, h in pairs(held) do
    for src in pairs(h) do
      if not prefix or src:sub(1, #prefix) == prefix then release(m, src) end
    end
  end
end

-- ------------------------------------------------------------------ record & playback
local function stopPlayer()
  if not player then return end
  player = nil
  releaseAll("auto")
end

local function startPlayer(events, kind)
  stopPlayer()
  if #events == 0 then audio.play("error"); return end
  table.sort(events, function(a, b) return a.t < b.t end)
  player = {events = events, idx = 1, start = sys.time() + 0.6, offs = {}, kind = kind}
end

local function songEvents(s)
  local spb = 60 / s.bpm
  local t = 0
  local ev = {}
  for _, n in ipairs(s.notes) do
    if n[1] > 0 then ev[#ev + 1] = {t = t, m = n[1], d = n[2] * spb * 0.9} end
    t = t + n[2] * spb
  end
  return ev
end

local function toggleRecord()
  if recording then
    recording = false
    -- close notes that are still held
    local now = sys.time()
    for m, t0 in pairs(recOpen) do recEvents[#recEvents + 1] = {t = t0, m = m, d = max(0.08, now - recStart - t0)} end
    recOpen = {}
    table.sort(recEvents, function(a, b) return a.t < b.t end)
    -- trim leading silence
    if #recEvents > 0 then
      local off = recEvents[1].t
      for _, e in ipairs(recEvents) do e.t = e.t - off end
    end
    store.set("recording", recEvents)
    audio.tone(660, 0.06, 0.25, "triangle")
    timer.after(0.07, function() audio.tone(440, 0.1, 0.25, "triangle") end)
  else
    stopPlayer()
    recording = true
    recStart = sys.time()
    recEvents = {}
    recOpen = {}
    audio.tone(440, 0.06, 0.25, "triangle")
    timer.after(0.07, function() audio.tone(660, 0.1, 0.25, "triangle") end)
  end
end

local function playRecording()
  if recording then toggleRecord() end
  if player and player.kind == "rec" then stopPlayer(); return end
  local copy = {}
  for i, e in ipairs(recEvents) do copy[i] = {t = e.t, m = e.m, d = e.d} end
  startPlayer(copy, "rec")
end

local function playSong(i)
  if recording then toggleRecord() end
  if player and player.kind == "song" and player.song == i then stopPlayer(); return end
  song = i
  startPlayer(songEvents(SONGS[i]), "song")
  if player then player.song = i end
end

local function shiftOctave(d)
  local nb = max(1, min(5, base + d))
  if nb == base then audio.play("error"); return end
  releaseAll("kbd")
  releaseAll("pad")
  base = nb
  selected = max(lowNote(), min(highNote(), selected + d * 12))
  save()
end

function app.load()
  wave = max(1, min(4, floor(tonumber(store.get("wave", 4)) or 4)))
  base = max(1, min(5, floor(tonumber(store.get("base", 3)) or 3)))
  sustain = store.get("sustain", false) == true
  volume = tonumber(store.get("volume", 0.8)) or 0.8
  local r = store.get("recording", {})
  recEvents = {}
  if type(r) == "table" then
    for _, e in ipairs(r) do
      if type(e) == "table" and tonumber(e.t) and tonumber(e.m) and tonumber(e.d) then
        recEvents[#recEvents + 1] = {t = tonumber(e.t), m = floor(tonumber(e.m)), d = tonumber(e.d)}
      end
    end
  end
  selected = lowNote() + 12
end

-- ------------------------------------------------------------------ update
function app.update(dt)
  local now = sys.time()
  if player then
    local el = now - player.start
    local ev = player.events
    while player.idx <= #ev and ev[player.idx].t <= el do
      local e = ev[player.idx]
      local src = "auto" .. player.idx
      press(e.m, src)
      player.offs[#player.offs + 1] = {at = e.t + e.d, m = e.m, src = src}
      player.idx = player.idx + 1
    end
    for i = #player.offs, 1, -1 do
      local o = player.offs[i]
      if el >= o.at then
        release(o.m, o.src)
        table.remove(player.offs, i)
      end
    end
    if player.idx > #ev and #player.offs == 0 then player = nil end
  end
  for m, g in pairs(glow) do
    if not held[m] then
      g = g - dt * 3
      if g <= 0 then glow[m] = nil else glow[m] = g end
    end
  end
  local top = layout.rollTop
  for i = #bars, 1, -1 do
    local b = bars[i]
    if b.t1 and layout.rollBottom - (now - b.t1) * 110 < top then table.remove(bars, i) end
  end
  -- d-pad repeat for the key cursor
  for dir, t0 in pairs(padRepeat) do
    if now - t0.at > 0.3 and now >= t0.next then
      selected = max(lowNote(), min(highNote(), selected + (dir == "left" and -1 or 1)))
      t0.next = now + 0.08
    end
  end
end

-- ------------------------------------------------------------------ layout & drawing
local function buildLayout(x, y, w, h)
  local key = table.concat({x, y, w, h, base}, ",")
  if key == layoutKey then return end
  layoutKey = key
  local keys = {}
  local nWhite = 0
  for m = lowNote(), highNote() do if not BLACK[m % 12] then nWhite = nWhite + 1 end end
  local ww = w / nWhite
  local bw, bh = ww * 0.6, h * 0.62
  local wi = 0
  for m = lowNote(), highNote() do
    if BLACK[m % 12] then
      keys[#keys + 1] = {m = m, black = true, x = x + wi * ww - bw / 2, y = y, w = bw, h = bh}
    else
      keys[#keys + 1] = {m = m, black = false, x = x + wi * ww, y = y, w = ww, h = h}
      wi = wi + 1
    end
  end
  layout.keys, layout.x, layout.y, layout.w, layout.h, layout.ww = keys, x, y, w, h, ww
end

local function keyAt(px, py)
  for _, k in ipairs(layout.keys) do
    if k.black and px >= k.x and px <= k.x + k.w and py >= k.y and py <= k.y + k.h then return k.m end
  end
  for _, k in ipairs(layout.keys) do
    if not k.black and px >= k.x and px < k.x + k.w and py >= k.y and py <= k.y + k.h then return k.m end
  end
  return nil
end

local function keyCenter(m)
  for _, k in ipairs(layout.keys) do
    if k.m == m then return k.x + k.w / 2, k.w end
  end
  return nil
end

local function drawRoll(x, y, w, h, now)
  layout.rollTop, layout.rollBottom = y, y + h
  gfx.color(theme.dark and "#141418" or "#1E1E24")
  gfx.rect(x, y, w, h, 10)
  gfx.clip(x, y, w, h)
  -- beat grid lines
  gfx.color(255, 255, 255, 10)
  for i = 1, 6 do gfx.rect(x, y + i * h / 7, w, 1) end
  -- octave separators
  for _, k in ipairs(layout.keys) do
    if k.m % 12 == 0 then
      gfx.color(255, 255, 255, 16)
      gfx.rect(k.x, y, 1, h)
    end
  end
  -- falling preview of upcoming playback notes
  if player then
    local el = now - player.start
    local look = 1.6
    for i = player.idx, min(#player.events, player.idx + 40) do
      local e = player.events[i]
      if e.t - el > look then break end
      local cx, kw = keyCenter(e.m)
      if cx then
        local bottom = y + h - (e.t - el) / look * h
        local hh = max(6, e.d / look * h)
        local col = noteColor(e.m)
        local bw = kw * 0.7
        gfx.color(alpha(col, 0.85))
        gfx.rect(cx - bw / 2, bottom - hh, bw, hh, 4)
        gfx.color(255, 255, 255, 60)
        gfx.rect(cx - bw / 2 + 2, bottom - hh + 2, bw - 4, 3, 2)
      end
    end
  end
  -- rising bars for live notes
  local speed = 110
  for _, b in ipairs(bars) do
    local cx, kw = keyCenter(b.m)
    if cx then
      local top = y + h - (now - b.t0) * speed
      local bottom = b.t1 and (y + h - (now - b.t1) * speed) or (y + h)
      if bottom - top < 4 then top = bottom - 4 end
      local col = noteColor(b.m)
      local bw = kw * 0.62
      gfx.gradient(cx - bw / 2, top, bw, bottom - top, alpha(col, 0.15), alpha(col, 0.95), false, 4)
      if not b.t1 then
        gfx.color(alpha(col, 0.35))
        gfx.circle(cx, y + h, kw * 0.5)
      end
    end
  end
  gfx.unclip()
  -- soft top fade
  gfx.gradient(x, y, w, 18, {0, 0, 0, theme.dark and 120 or 80}, {0, 0, 0, 0}, false, 0)
end

local function drawKeys(now)
  local L = layout
  local felt = 8
  -- piano case
  gfx.shadow(L.x - 10, L.y - felt - 6, L.w + 20, L.h + felt + 16, 12, 16, 4)
  gfx.color(theme.dark and "#1A1A1D" or "#26262B")
  gfx.rect(L.x - 10, L.y - felt - 6, L.w + 20, L.h + felt + 16, 12)
  local activeLow = lowNote() + 12
  -- white keys
  for _, k in ipairs(L.keys) do
    if not k.black then
      local g = glow[k.m] or 0
      local down = held[k.m] ~= nil
      local dy = down and 2 or 0
      local col = noteColor(k.m)
      local topC = down and mix("#FFFFFF", col, 0.35) or (g > 0 and mix("#FFFFFF", col, g * 0.25) or "#FFFFFF")
      local botC = down and mix("#E6E6EA", col, 0.55) or "#E3E3E8"
      gfx.gradient(k.x + 1, k.y, k.w - 2, k.h + dy, topC, botC, false, 5)
      gfx.color(0, 0, 0, 40)
      gfx.rect(k.x + k.w - 1, k.y, 1, k.h)
      if not down then
        gfx.color(0, 0, 0, 30)
        gfx.rect(k.x + 2, k.y + k.h - 6, k.w - 4, 6, 4)
      end
      local off = k.m - activeLow
      if KEYLABEL[off] then
        gfx.color(off >= 0 and off <= 14 and (down and col or "#8E8E93") or "#8E8E93")
        gfx.text(KEYLABEL[off], k.x, k.y + k.h - 42 + dy, 12, "semibold", "center", k.w)
      end
      if k.m % 12 == 0 then
        gfx.color(k.m == 60 and theme.accent or "#A1A1AA")
        gfx.text(noteName(k.m), k.x, k.y + k.h - 24 + dy, 11, k.m == 60 and "bold" or "medium", "center", k.w)
      end
    end
  end
  -- black keys
  for _, k in ipairs(L.keys) do
    if k.black then
      local down = held[k.m] ~= nil
      local g = glow[k.m] or 0
      local col = noteColor(k.m)
      local dy = down and 2 or 0
      gfx.color(0, 0, 0, 80)
      gfx.rect(k.x + 2, k.y, k.w, k.h + 4, 4)
      local topC = down and mix("#3A3A40", col, 0.55) or (g > 0 and mix("#2C2C30", col, g * 0.3) or "#3A3A40")
      gfx.gradient(k.x, k.y, k.w, k.h + dy, topC, down and mix("#111114", col, 0.35) or "#111114", false, 4)
      gfx.color(255, 255, 255, down and 30 or 45)
      gfx.rect(k.x + 3, k.y + k.h - 14 + dy, k.w - 6, 8, 3)
      local off = k.m - activeLow
      if KEYLABEL[off] then
        gfx.color(down and "#FFFFFF" or "#C7C7CC")
        gfx.text(KEYLABEL[off], k.x, k.y + k.h - 34 + dy, 11, "semibold", "center", k.w)
      end
    end
  end
  -- felt strip
  gfx.gradient(L.x - 2, L.y - felt, L.w + 4, felt, "#8B1E2B", "#5E121C", false, 2)
  -- active octave bracket for the computer keyboard
  local ax = nil
  for _, k in ipairs(L.keys) do
    if k.m == activeLow then ax = k.x end
  end
  if ax and lastInput ~= "pad" then
    local bw = L.ww * 8
    gfx.color(alpha(theme.accent, 0.9))
    gfx.rect(ax + 4, L.y + L.h + 4, min(bw, L.x + L.w - ax) - 8, 3, 2)
  end
  -- controller cursor
  if lastInput == "pad" then
    for _, k in ipairs(L.keys) do
      if k.m == selected then
        local pulse = 0.6 + 0.4 * sin(now * 6)
        gfx.color(alpha(theme.accent, pulse))
        gfx.rectLine(k.x + 1, k.y + 2, k.w - 2, k.h - 2, 5, 3)
        gfx.poly({k.x + k.w / 2 - 6, L.y + L.h + 12, k.x + k.w / 2 + 6, L.y + L.h + 12, k.x + k.w / 2, L.y + L.h + 5}, theme.accent)
      end
    end
  end
end

local function padGlyph(label, x, y)
  local tw = max(18, gfx.textWidth(label, 10, "bold") + 8)
  gfx.color(theme.text2)
  gfx.rect(x, y, tw, 18, 9)
  gfx.color(theme.bg)
  gfx.text(label, x, y + 3, 10, "bold", "center", tw)
  return tw
end
local function keyCap(label, x, y)
  local tw = max(18, gfx.textWidth(label, 11, "semibold") + 10)
  gfx.color(theme.text3)
  gfx.rectLine(x, y, tw, 18, 4, 1)
  gfx.color(theme.text2)
  gfx.text(label, x, y + 2, 11, "semibold", "center", tw)
  return tw
end
local function drawHints(w, y)
  local items
  if lastInput == "pad" then
    items = {{"icon", "gamepad", TR("hint_select")}, {"pad", "A", TR("hint_play")}, {"pad", "ZL ZR", TR("hint_octave")},
             {"pad", "Y", TR("hint_wave")}, {"pad", "X", TR("hint_record")}, {"pad", "+", TR("hint_playback")},
             {"pad", "−", TR("hint_demo")}}
  elseif lastInput == "key" then
    items = {{"key", "A–K", TR("hint_white")}, {"key", "W E T Y U", TR("hint_black")}, {"key", "Z X", TR("hint_octave")},
             {"key", "R", TR("hint_record")}, {"key", TR("key_space"), TR("hint_playback")}, {"key", "1–4", TR("hint_wave")}}
  else
    items = {{"icon", "touch_app", TR("hint_touch")}}
  end
  local total = 0
  for _, it in ipairs(items) do
    local gw = 18
    if it[1] == "key" then gw = max(18, gfx.textWidth(it[2], 11, "semibold") + 10)
    elseif it[1] == "pad" then gw = max(18, gfx.textWidth(it[2], 10, "bold") + 8) end
    total = total + gw + 5 + gfx.textWidth(it[3], 12) + 14
  end
  local x = (w - total + 14) / 2
  for _, it in ipairs(items) do
    local gw
    if it[1] == "pad" then gw = padGlyph(it[2], x, y)
    elseif it[1] == "key" then gw = keyCap(it[2], x, y)
    else gfx.icon(it[2], x + 9, y + 9, 18, theme.text2); gw = 18 end
    gfx.color(theme.text2)
    local tw = gfx.text(it[3], x + gw + 5, y + 2, 12)
    x = x + gw + 5 + tw + 14
  end
end

local songLabels = nil
local songLang = nil

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  if songLang ~= sys.lang() then
    songLang = sys.lang()
    songLabels = {}
    for i, s in ipairs(SONGS) do local k = s.key; songLabels[i] = TR(k) end
  end

  -- toolbar
  local x = 16
  local labels = {TR(WAVE_KEYS[1]), TR(WAVE_KEYS[2]), TR(WAVE_KEYS[3]), TR(WAVE_KEYS[4])}
  local nw = ui.segmented("wave", labels, wave, x, 12, 300, 30)
  if nw ~= wave then wave = nw; save(); lastInput = "touch" end
  x = x + 314
  if ui.iconButton("remove", x, 12, 30, 30, nil, false, "oct") then shiftOctave(-1); lastInput = "touch" end
  gfx.color(theme.text)
  gfx.text(TR("octave_range", noteName(lowNote()), noteName(highNote())), x + 30, 19, 13, "semibold", "center", 92)
  if ui.iconButton("add", x + 122, 12, 30, 30, nil, false, "oct") then shiftOctave(1); lastInput = "touch" end
  x = x + 166

  -- record / play recording
  local recCol = recording and theme.red or nil
  if recording then
    local p = 0.5 + 0.5 * sin(now * 6)
    gfx.color(alpha(theme.red, 0.15 + 0.15 * p))
    gfx.rect(x - 2, 10, 34, 34, 8)
  end
  if ui.iconButton("fiber_manual_record", x, 12, 30, 30, recCol or theme.red, recording, "rec") then
    toggleRecord(); lastInput = "touch"
  end
  local playingRec = player and player.kind == "rec"
  if ui.iconButton(playingRec and "stop" or "play_arrow", x + 34, 12, 30, 30, nil, playingRec, "prec") then
    playRecording(); lastInput = "touch"
  end
  gfx.color(recording and theme.red or theme.text2)
  local recText
  if recording then
    local t = now - recStart
    recText = TR("rec_time", string.format("%d:%02d", floor(t / 60), floor(t) % 60))
  else
    recText = #recEvents > 0 and TR("rec_notes", #recEvents) or TR("rec_empty")
  end
  gfx.text(recText, x + 70, 19, 12, "medium")
  x = x + 70 + max(70, gfx.textWidth(recText, 12, "medium")) + 12

  -- demo songs
  local ddW = max(120, w - x - 16 - 40)
  local ns = ui.dropdown("song", songLabels, song, x, 13, ddW, 28)
  if ns ~= song then song = ns end
  local playingSong = player and player.kind == "song"
  if ui.iconButton(playingSong and "stop" or "queue_music", x + ddW + 6, 12, 32, 30, playingSong and theme.accent or nil,
      playingSong, "song") then
    playSong(song); lastInput = "touch"
  end

  -- keyboard geometry
  local kbH = min(190, h - 54 - 120 - 40)
  local ky = h - 40 - kbH
  buildLayout(24, ky, w - 48, kbH)
  drawRoll(14, 54, w - 28, ky - 54 - 20, now)
  drawKeys(now)

  -- sustain toggle + volume (small, bottom-right of the roll)
  gfx.color(255, 255, 255, 160)
  gfx.text(TR("sustain"), 0, 62, 12, "medium", "right", w - 82)
  local ns2 = ui.toggle("sustain", sustain, w - 72, 60)
  if ns2 ~= sustain then sustain = ns2; save() end

  drawHints(w, h - 24)
end

-- ------------------------------------------------------------------ input
local function inKeys(x, y)
  local L = layout
  return x >= L.x and x <= L.x + L.w and y >= L.y and y <= L.y + L.h
end

function app.event(e)
  local t = e.type
  if t == "mousedown" then
    lastInput = "touch"
    if inKeys(e.x, e.y) then
      local m = keyAt(e.x, e.y)
      if m then
        ptrDown = true
        ptrNote = m
        press(m, "ptr")
      end
    end
  elseif t == "mousemove" then
    if ptrDown then
      local m = inKeys(e.x, e.y) and keyAt(e.x, e.y) or nil
      if m ~= ptrNote then
        if ptrNote then release(ptrNote, "ptr") end
        ptrNote = m
        if m then press(m, "ptr") end
      end
    end
  elseif t == "mouseup" then
    if ptrNote then release(ptrNote, "ptr") end
    ptrNote = nil
    ptrDown = false
  elseif t == "keydown" then
    lastInput = "key"
    local k = e.key
    local off = KEYMAP[k]
    if off and not e.ctrl then
      local m = lowNote() + 12 + off
      press(m, "kbd" .. k)
    elseif k == "z" then shiftOctave(-1)
    elseif k == "x" then shiftOctave(1)
    elseif k == "r" then toggleRecord()
    elseif k == "space" then playRecording()
    elseif k == "escape" then stopPlayer(); if recording then toggleRecord() end
    elseif k == "enter" then playSong(song)
    elseif k == "1" or k == "2" or k == "3" or k == "4" then wave = tonumber(k); save()
    elseif k == "tab" then song = song % #SONGS + 1
    end
  elseif t == "keyup" then
    local off = KEYMAP[e.key]
    if off then
      for m, h in pairs(held) do
        if h["kbd" .. e.key] then release(m, "kbd" .. e.key) end
      end
    end
  elseif t == "paddown" then
    lastInput = "pad"
    local p = e.pad
    if p == "left" or p == "right" then
      selected = max(lowNote(), min(highNote(), selected + (p == "left" and -1 or 1)))
      padRepeat[p] = {at = sys.time(), next = 0}
    elseif p == "up" or p == "down" then
      selected = max(lowNote(), min(highNote(), selected + (p == "up" and 12 or -12)))
    elseif p == "a" then press(selected, "pad")
    elseif p == "b" then stopPlayer(); if recording then toggleRecord() end
    elseif p == "zl" or p == "l" then shiftOctave(-1)
    elseif p == "zr" or p == "r" then shiftOctave(1)
    elseif p == "y" then wave = wave % 4 + 1; save(); audio.tone(523.25, 0.08, 0.25, WAVES[wave])
    elseif p == "x" then toggleRecord()
    elseif p == "plus" then playRecording()
    elseif p == "minus" then playSong(song)
    end
  elseif t == "padup" then
    padRepeat[e.pad] = nil
    if e.pad == "a" then
      for m, h in pairs(held) do if h.pad then release(m, "pad") end end
    end
  end
end

function app.menu()
  local waves = {}
  for i, k in ipairs(WAVE_KEYS) do waves[#waves + 1] = {label = TR(k), id = 10 + i, checked = wave == i, shortcut = tostring(i)} end
  waves[#waves + 1] = "-"
  waves[#waves + 1] = {label = TR("sustain"), id = 20, checked = sustain}
  local songs = {}
  for i, s in ipairs(SONGS) do local k = s.key; songs[#songs + 1] = {label = TR(k), id = 30 + i} end
  songs[#songs + 1] = "-"
  songs[#songs + 1] = {label = TR("stop"), id = 40, shortcut = "Esc"}
  return {
    {title = TR("menu_piano"), items = {
      {label = recording and TR("stop_recording") or TR("start_recording"), id = 1, shortcut = "R"},
      {label = TR("play_recording"), id = 2, shortcut = "Space", enabled = #recEvents > 0},
      {label = TR("clear_recording"), id = 3, enabled = #recEvents > 0},
      "-",
      {label = TR("octave_down"), id = 4, shortcut = "Z"},
      {label = TR("octave_up"), id = 5, shortcut = "X"},
    }},
    {title = TR("menu_sound"), items = waves},
    {title = TR("menu_songs"), items = songs},
  }
end

function app.onmenu(id)
  if id == 1 then toggleRecord()
  elseif id == 2 then playRecording()
  elseif id == 3 then recEvents = {}; store.set("recording", recEvents)
  elseif id == 4 then shiftOctave(-1)
  elseif id == 5 then shiftOctave(1)
  elseif id > 10 and id <= 14 then wave = id - 10; save()
  elseif id == 20 then sustain = not sustain; save()
  elseif id > 30 and id <= 30 + #SONGS then playSong(id - 30)
  elseif id == 40 then stopPlayer()
  end
end

function app.close()
  if recording then toggleRecord() end
  stopPlayer()
  save()
  return true
end

return app
