-- Synth demo: an on-screen keyboard with four waveforms, an ADSR envelope driven by timers, chords and a scope.
--
-- What this file teaches:
--   1. audio.tone(freq, seconds, volume, wave) and note frequencies: f = 440 * 2^((n - 69) / 12)
--   2. an ADSR envelope (attack, decay, sustain, release) built with timer.every: audio.tone's volume is fixed
--      when the tone starts, so a held note is played as a stream of short overlapping "grains", each one at
--      the envelope's current level
--   3. timer.after for a strummed chord (each note a few milliseconds after the previous one)
--   4. polyphony with a voice list, and pointer glides across keys (mousedown / mousemove / mouseup)
--   5. drawing data: the envelope shape, live envelope positions and an oscilloscope with gfx.lines
--   6. a layout computed from the window size every frame (resizable window)

local app = {}
local sin, pi, floor, min, max, abs = math.sin, math.pi, math.floor, math.min, math.max, math.abs

-- ------------------------------------------------------------------ settings (saved with store)
local WAVES = {"sine", "square", "saw", "triangle"}
local CHORDS = {{0}, {0, 4, 7}, {0, 3, 7}, {0, 4, 7, 10}, {0, 5, 7}}    -- semitones above the root
local set = {wave = 4, chord = 1, octave = 4, a = 0.02, d = 0.25, s = 0.6, r = 0.45, vol = 0.6, strum = true}

-- ------------------------------------------------------------------ 1. notes
local NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local function freqOf(note) return 440 * 2 ^ ((note - 69) / 12) end           -- MIDI note number -> Hz
local function nameOf(note) return NAMES[note % 12 + 1] .. (floor(note / 12) - 1) end

-- ------------------------------------------------------------------ 2. voices and the envelope clock
local GRAIN = 0.05          -- the envelope advances in 50 ms steps
local GRAIN_LEN = 0.085     -- each grain lasts a little longer than a step, so grains overlap and sound continuous
local MAX_VOICES = 8
local voices = {}           -- {note, freq, t, held, relT, relFrom, level, owner}
local heldOwners = {}       -- owner ("pointer" or "key_a" ...) -> root note it is holding

-- envelope level of a voice at its current time
local function level(v)
  if v.held then
    if v.t < set.a then return v.t / max(set.a, 0.001) end                   -- attack: 0 -> 1
    local dt = v.t - set.a
    if dt < set.d then return 1 - (1 - set.s) * dt / max(set.d, 0.001) end  -- decay: 1 -> sustain
    return set.s                                                             -- sustain while held
  end
  return v.relFrom * max(0, 1 - v.relT / max(set.r, 0.001))                  -- release: -> 0
end

local function playGrain(v)
  local l = level(v)
  v.level = l
  if l > 0.005 then audio.tone(v.freq, GRAIN_LEN, l * l * set.vol, WAVES[set.wave]) end
end

-- timer.every calls this 20 times a second: advance every voice, play its next grain, drop finished voices
local function tick()
  for i = #voices, 1, -1 do
    local v = voices[i]
    if v.held then v.t = v.t + GRAIN else v.relT = v.relT + GRAIN end
    if not v.held and v.relT >= set.r then
      table.remove(voices, i)
    else
      playGrain(v)
    end
  end
end

local function noteOn(note, owner)
  if #voices >= MAX_VOICES then table.remove(voices, 1) end   -- steal the oldest voice
  local v = {note = note, freq = freqOf(note), t = 0, held = true, relT = 0, relFrom = 0, level = 0, owner = owner}
  voices[#voices + 1] = v
  playGrain(v)                                                -- start right away, not at the next tick
end

local function noteOff(owner)
  for _, v in ipairs(voices) do
    if v.owner == owner and v.held then
      v.relFrom = level(v)
      v.held = false
    end
  end
end

-- 3. a chord: the root now, the other notes a little later when "strum" is on
local function chordOn(root, owner)
  for i, interval in ipairs(CHORDS[set.chord]) do
    local delay = set.strum and (i - 1) * 0.035 or 0
    if delay == 0 then
      noteOn(root + interval, owner)
    else
      timer.after(delay, function()
        -- the key may already be up: then start the note and release it at once
        noteOn(root + interval, owner)
        if not heldOwners[owner] then noteOff(owner) end
      end)
    end
  end
end

local function press(owner, root)
  if heldOwners[owner] == root then return end
  if heldOwners[owner] then noteOff(owner) end
  heldOwners[owner] = root
  chordOn(root, owner)
end
local function release(owner)
  if not heldOwners[owner] then return end
  heldOwners[owner] = nil
  noteOff(owner)
end

-- ------------------------------------------------------------------ app
function app.load()
  local saved = store.get("synth", nil)
  if type(saved) == "table" then
    for k, v in pairs(saved) do if set[k] ~= nil and type(v) == type(set[k]) then set[k] = v end end
  end
  timer.every(GRAIN, tick)                      -- the envelope clock runs for the whole session
end

-- ------------------------------------------------------------------ keyboard geometry
local WHITE = {0, 2, 4, 5, 7, 9, 11}            -- semitones of the white keys in an octave
local BLACK_AFTER = {[0] = 1, [1] = 3, [3] = 6, [4] = 8, [5] = 10}   -- white index -> black semitone after it
local kb = {x = 0, y = 0, w = 0, h = 0, keys = {}}

local function layoutKeyboard(x, y, w, h)
  kb.x, kb.y, kb.w, kb.h = x, y, w, h
  local octaves = w >= 700 and 3 or 2
  local whites = octaves * 7 + 1
  local ww = w / whites
  local keys = {}
  local base = set.octave * 12 + 12             -- MIDI number of the leftmost C
  for i = 0, whites - 1 do
    local oct, k = floor(i / 7), i % 7
    keys[#keys + 1] = {note = base + oct * 12 + WHITE[k + 1], x = x + i * ww, y = y, w = ww, h = h, black = false}
  end
  for i = 0, whites - 2 do
    local oct, k = floor(i / 7), i % 7
    if BLACK_AFTER[k] then
      keys[#keys + 1] = {note = base + oct * 12 + BLACK_AFTER[k], x = x + (i + 1) * ww - ww * 0.32, y = y,
                         w = ww * 0.64, h = h * 0.6, black = true}
    end
  end
  kb.keys = keys
end

local function keyAt(px, py)
  -- black keys are on top, so test them first
  for pass = 1, 2 do
    for _, k in ipairs(kb.keys) do
      if k.black == (pass == 1) and px >= k.x and px < k.x + k.w and py >= k.y and py < k.y + k.h then return k.note end
    end
  end
end

local function isDown(note)
  for _, v in ipairs(voices) do if v.note == note and v.held then return true end end
  return false
end

-- ------------------------------------------------------------------ 4. input
-- computer keyboard: one row of letters plays an octave, like a piano (A = C, W = C#, S = D ...)
local LETTERS = {a = 0, w = 1, s = 2, e = 3, d = 4, f = 5, t = 6, g = 7, y = 8, h = 9, u = 10, j = 11, k = 12, o = 13,
                 l = 14}

function app.event(e)
  if e.type == "mousedown" and e.button == "left" then
    local n = keyAt(e.x, e.y)
    if n then press("pointer", n) end
  elseif e.type == "mousemove" and heldOwners.pointer then
    local n = keyAt(e.x, e.y)                    -- glide: sliding to another key changes the note
    if n then press("pointer", n) end
  elseif e.type == "mouseup" then
    release("pointer")
  elseif e.type == "keydown" then
    local semi = LETTERS[e.key]
    if semi then press("key_" .. e.key, set.octave * 12 + 12 + semi) end
    if e.key == "z" then set.octave = max(2, set.octave - 1) end
    if e.key == "x" then set.octave = min(6, set.octave + 1) end
    if e.key == "escape" then app.onmenu(1) end
  elseif e.type == "keyup" then
    release("key_" .. e.key)
  end
end

-- ------------------------------------------------------------------ 5. drawing helpers
local function waveValue(kind, ph)                 -- ph in 0..1 -> -1..1, the same shapes the mixer synthesises
  if kind == 1 then return sin(ph * 2 * pi)
  elseif kind == 2 then return ph < 0.5 and 0.7 or -0.7
  elseif kind == 3 then return (2 * ph - 1) * 0.8
  end
  return ph < 0.5 and 4 * ph - 1 or 3 - 4 * ph
end

local pts = {}                                       -- reused point list for gfx.lines

local function drawEnvelope(x, y, w, h)
  ui.group(x, y, w, h)
  gfx.color(theme.text2)
  gfx.text(TR("envelope"), x + 14, y + 10, 12, "semibold")
  local gx, gy, gw, gh = x + 14, y + 34, w - 28, h - 48
  local total = set.a + set.d + 0.4 + set.r      -- 0.4 s of sustain is shown in the middle
  local sx = gw / total
  local function px(t) return gx + t * sx end
  local function py(l) return gy + gh - l * gh end
  local n = 0
  local function add(t, l) pts[n + 1], pts[n + 2] = px(t), py(l); n = n + 2 end
  for i = #pts, 1, -1 do pts[i] = nil end
  add(0, 0); add(set.a, 1); add(set.a + set.d, set.s); add(set.a + set.d + 0.4, set.s); add(total, 0)
  gfx.color(theme.separator)
  gfx.line(gx, gy + gh, gx + gw, gy + gh, 1)
  gfx.color(theme.accent)
  gfx.lines(pts, 2.5)
  -- a dot per voice where it is on the curve
  for _, v in ipairs(voices) do
    local t
    if v.held then t = min(v.t, set.a + set.d + 0.4) else t = set.a + set.d + 0.4 + min(v.relT, set.r) end
    gfx.circle(px(t), py(v.level), 5, theme.orange)
  end
  gfx.color(theme.text3)
  gfx.text("A", px(set.a / 2) - 4, gy + gh + 2, 11, "semibold")
  gfx.text("D", px(set.a + set.d / 2) - 4, gy + gh + 2, 11, "semibold")
  gfx.text("S", px(set.a + set.d + 0.2) - 4, gy + gh + 2, 11, "semibold")
  gfx.text("R", px(set.a + set.d + 0.4 + set.r / 2) - 4, gy + gh + 2, 11, "semibold")
end

local function drawScope(x, y, w, h, t)
  gfx.rect(x, y, w, h, 12, "#0D1B12")
  gfx.color("#1E3A26")
  for i = 1, 3 do gfx.line(x + 8, y + h * i / 4, x + w - 8, y + h * i / 4, 1) end
  gfx.color("#7CFF9E")
  gfx.text(TR("scope"), x + 12, y + 8, 12, "semibold")
  -- the sum of all voices: each voice is its wave at its own frequency times its envelope level
  local samples = floor(w / 3)
  local n = 0
  for i = #pts, 1, -1 do pts[i] = nil end
  local lowest = 1e9
  for _, v in ipairs(voices) do lowest = min(lowest, v.freq) end
  for i = 0, samples do
    local s = 0
    for _, v in ipairs(voices) do
      local cycles = 3 * v.freq / lowest       -- three periods of the lowest note across the scope
      local ph = (i / samples * cycles + t * 0.5) % 1
      s = s + waveValue(set.wave, ph) * v.level
    end
    s = max(-1.2, min(1.2, s * 0.6))
    pts[n + 1], pts[n + 2] = x + 8 + i / samples * (w - 16), y + h / 2 - s * h * 0.38
    n = n + 2
  end
  gfx.lines(pts, 2)
end

local function drawKeyboard()
  for pass = 1, 2 do
    for _, k in ipairs(kb.keys) do
      if k.black == (pass == 2) then
        local down = isDown(k.note)
        if k.black then
          gfx.rect(k.x, k.y, k.w, k.h, 4, down and theme.accent or "#1C1C22")
        else
          gfx.rect(k.x + 1, k.y, k.w - 2, k.h, 6, down and "#BFD8FF" or "#FAFAFA")
          gfx.rect(k.x + 1, k.y + k.h - 6, k.w - 2, 6, 6, down and "#9DC2FF" or "#E2E2E8")
          if k.note % 12 == 0 then
            gfx.color("#8E8E93")
            gfx.text(nameOf(k.note), k.x, k.y + k.h - 24, 11, "semibold", "center", k.w)
          end
        end
      end
    end
  end
end

local function label(text, x, y)
  gfx.color(theme.text)
  gfx.text(text, x, y, 13)
end

-- ------------------------------------------------------------------ 6. layout
function app.draw(w, h)
  gfx.clear(theme.bg)
  local m = 16
  -- row 1: waveform, chord, octave
  gfx.color(theme.text)
  gfx.text(TR("title"), m, 14, 20, "bold")
  local changed = false
  local nw = ui.segmented("wave", {TR("sine"), TR("square"), TR("saw"), TR("triangle")}, set.wave,
                          m, 48, min(360, w - 2 * m - 170), 30)
  if nw ~= set.wave then set.wave = nw; changed = true end
  local cy = 88
  local nc = ui.segmented("chord", {TR("single"), TR("major"), TR("minor"), TR("seventh"), TR("sus4")}, set.chord,
                          m, cy, min(420, w - 2 * m - 170), 30)
  if nc ~= set.chord then set.chord = nc; changed = true end
  local ox = w - m - 150
  if ui.button("-", ox, cy, 36, 30) then set.octave = max(2, set.octave - 1); changed = true end
  gfx.color(theme.text)
  gfx.text(TR("octave", set.octave), ox + 36, cy + 7, 13, "semibold", "center", 78)
  if ui.button("+", ox + 114, cy, 36, 30) then set.octave = min(6, set.octave + 1); changed = true end
  local ns = ui.checkbox(TR("strum"), set.strum, w - m - 150, 54)
  if ns ~= set.strum then set.strum = ns; changed = true end

  -- row 2: envelope sliders + curve, scope
  local kbH = min(200, max(110, h * 0.32))
  local top, bottom = 132, h - kbH - 16
  local midH = bottom - top
  local leftW = w >= 760 and (w - 3 * m) * 0.5 or w - 2 * m
  local sliders = {{"a", TR("attack"), 0, 1}, {"d", TR("decay"), 0, 1}, {"s", TR("sustain"), 0, 1},
                   {"r", TR("release"), 0.02, 2}, {"vol", TR("volume"), 0, 1}}
  local rowH = min(34, (midH * 0.55) / #sliders)
  for i, sl in ipairs(sliders) do
    local y = top + (i - 1) * rowH
    label(sl[2], m, y + 6)
    local v = ui.slider("sl_" .. sl[1], set[sl[1]], sl[3], sl[4], m + 96, y, leftW - 170)
    if v ~= set[sl[1]] then set[sl[1]] = v; changed = true end
    gfx.color(theme.text2)
    local unit = (sl[1] == "s" or sl[1] == "vol") and string.format("%d%%", floor(set[sl[1]] * 100 + 0.5))
      or string.format("%.2f s", set[sl[1]])
    gfx.text(unit, 0, y + 6, 12, "mono", "right", m + leftW)
  end
  local envY = top + #sliders * rowH + 6
  if bottom - envY > 70 then drawEnvelope(m, envY, leftW, bottom - envY) end
  if w >= 760 then drawScope(2 * m + leftW, top, w - 3 * m - leftW, midH, sys.time()) end

  -- keyboard
  layoutKeyboard(m, h - kbH - 8, w - 2 * m, kbH)
  drawKeyboard()
  if #voices == 0 then
    gfx.color(theme.text3)
    gfx.text(TR("hint"), 0, h - kbH - 30, 12, "sans", "center", w)
  end
  if changed then store.set("synth", set) end
end

function app.menu()
  return {{title = TR("title"), items = {
    {label = TR("panic"), id = 1, shortcut = "Esc"},
    {label = TR("reset"), id = 2},
  }}}
end

function app.onmenu(id)
  if id == 1 then
    voices = {}                                  -- stop everything: the next tick plays nothing
    heldOwners = {}
  elseif id == 2 then
    set = {wave = 4, chord = 1, octave = 4, a = 0.02, d = 0.25, s = 0.6, r = 0.45, vol = 0.6, strum = true}
    store.set("synth", set)
  end
end

return app
