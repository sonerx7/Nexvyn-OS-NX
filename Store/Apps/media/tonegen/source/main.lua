-- Tone Generator: 20 Hz - 20 kHz test tones (sine, square, saw, triangle) with a log slider, numeric entry,
-- fine steps, note snapping, sweeps and an oscilloscope view. Nexvyn OS Lua SDK.
-- Continuous sound: 2-second chunks re-triggered every 1.95 s. Every distinct frequency is a new cached chunk
-- in the system (flushed after 96), so frequencies are rounded and restarts while dragging are throttled.
local app = {}

local floor, min, max, log, sin, pi, abs = math.floor, math.min, math.max, math.log, math.sin, math.pi, math.abs
local M = 18
local FMIN, FMAX = 20, 20000
local CHUNK, EVERY = 2.0, 1.95
local WAVES = {"sine", "square", "saw", "triangle"}
local NOTES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}

-- ------------------------------------------------------------------ state
local mode = 1                -- 1 tone, 2 sweep
local freq, wave, volume = 440, 1, 25
local sweepFrom, sweepTo, sweepDur, sweepLoop = 20, 20000, 20, false
local playing = false
local clock = 0
local ch, nextAt = nil, 0
local playedKey = ""          -- freq/wave/volume of the chunk that is playing
local restartAt = 0
local sweepT, sweepStep, sweepCur = 0, -1, 0
local freqStr, fromStr, toStr = "440", "20", "20000"
local scopePts = {}
local phase = 0
local toast, toastT = "", 0

-- ------------------------------------------------------------------ helpers
local function roundFreq(f)
  f = max(FMIN, min(FMAX, f))
  return floor(f * 10 + 0.5) / 10
end

local function fmtFreq(f)
  if f >= 1000 then
    local s = string.format("%.2f", f / 1000):gsub("0+$", ""):gsub("%.$", "")
    return s .. " kHz"
  end
  local s = string.format("%.1f", f):gsub("%.0$", "")
  return s .. " Hz"
end

local function noteOf(f)
  local n = 69 + 12 * log(f / 440, 2)
  local k = floor(n + 0.5)
  local cents = floor((n - k) * 100 + 0.5)
  return NOTES[k % 12 + 1] .. tostring(k // 12 - 1), cents, k
end

local function noteFreq(k) return 440 * 2 ^ ((k - 69) / 12) end

local function toPos(f) return 1000 * log(f / FMIN) / log(FMAX / FMIN) end
local function fromPos(p)
  local f = FMIN * (FMAX / FMIN) ^ (p / 1000)
  if f < 100 then return floor(f * 10 + 0.5) / 10 elseif f < 1000 then return floor(f + 0.5) end
  return floor(f / 10 + 0.5) * 10
end

local function showToast(m) toast, toastT = m, 2.4 end

local function saveAll()
  store.set("freq", freq); store.set("wave", wave); store.set("volume", volume); store.set("mode", mode)
  store.set("sweep", {from = sweepFrom, to = sweepTo, dur = sweepDur, loop = sweepLoop})
end

local function vol() return (volume / 100) ^ 2 end

-- ------------------------------------------------------------------ audio
local function stopSound()
  if ch and ch >= 0 then audio.stop(ch) end
  ch = nil
end

local function playChunk(f)
  -- the previous chunk (if any) fades out on its own with its 60 ms release while the new one starts
  ch = audio.tone(f, CHUNK, vol(), WAVES[wave])
  nextAt = clock + EVERY
  playedKey = f .. "/" .. wave .. "/" .. volume
end

local function startTone()
  playing = true
  stopSound()
  if mode == 2 then
    sweepT, sweepStep = 0, -1
  else
    playChunk(freq)
  end
end

local function stopAll()
  playing = false
  stopSound()
end

local function togglePlay() if playing then stopAll() else startTone() end end

local function setFreq(f, quiet)
  f = tonumber(f)
  if not f or f ~= f then return end
  freq = roundFreq(f)
  freqStr = tostring(freq):gsub("%.0$", "")
  store.set("freq", freq)
  if not quiet then audio.play("key", 0.2) end
end

local function snapNote()
  local _, _, k = noteOf(freq)
  local f = noteFreq(k)
  if f < FMIN then f = noteFreq(k + 12) elseif f > FMAX then f = noteFreq(k - 12) end
  setFreq(f)
end

-- sweep: log-spaced steps, at most 48 distinct frequencies (rounded to 1 Hz)
local function sweepSteps() return max(2, min(48, floor(sweepDur * 4))) end
local function sweepFreqAt(i, n)
  local f = sweepFrom * (sweepTo / sweepFrom) ^ (i / (n - 1))
  return max(FMIN, min(FMAX, floor(f + 0.5)))
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  freq = roundFreq(tonumber(store.get("freq", 440)) or 440)
  wave = max(1, min(4, floor(tonumber(store.get("wave", 1)) or 1)))
  volume = max(0, min(100, floor(tonumber(store.get("volume", 25)) or 25)))
  mode = max(1, min(2, floor(tonumber(store.get("mode", 1)) or 1)))
  local s = store.get("sweep", {})
  if type(s) == "table" then
    sweepFrom = roundFreq(tonumber(s.from) or 20)
    sweepTo = roundFreq(tonumber(s.to) or 20000)
    sweepDur = max(2, min(60, floor(tonumber(s.dur) or 20)))
    sweepLoop = s.loop == true
  end
  freqStr = tostring(freq):gsub("%.0$", "")
  fromStr, toStr = tostring(floor(sweepFrom)), tostring(floor(sweepTo))
end

function app.update(dt)
  clock = clock + dt
  if toastT > 0 then toastT = toastT - dt end
  if not playing then return end
  if mode == 1 then
    phase = phase + dt * 1.5
    local key = freq .. "/" .. wave .. "/" .. volume
    if key ~= playedKey and clock >= restartAt then       -- settings changed: restart at once (throttled)
      restartAt = clock + 0.12
      stopSound()
      playChunk(freq)
    elseif clock >= nextAt then
      playChunk(freq)
    end
  else
    sweepT = sweepT + dt
    local n = sweepSteps()
    local stepLen = sweepDur / n
    local i = floor(sweepT / stepLen)
    if i >= n then
      if sweepLoop then sweepT, i = 0, 0 else stopAll(); showToast(TR("sweep_done")); return end
    end
    if i ~= sweepStep then
      sweepStep = i
      sweepCur = sweepFreqAt(i, n)
      ch = audio.tone(sweepCur, stepLen + 0.06, vol(), WAVES[wave])
    end
    phase = phase + dt * 1.5
  end
end

-- ------------------------------------------------------------------ drawing
local function waveSample(w, x)       -- x in cycles
  local p = x % 1
  if w == 1 then return sin(2 * pi * p)
  elseif w == 2 then return p < 0.5 and 0.8 or -0.8
  elseif w == 3 then return (2 * p - 1) * 0.9 end
  return p < 0.5 and (4 * p - 1) or (3 - 4 * p)
end

local function drawScope(x, y, w, h, f)
  gfx.color(theme.dark and "#0B1410" or "#F2F7F3")
  gfx.rect(x, y, w, h, 12)
  gfx.color(theme.separator)
  gfx.rectLine(x, y, w, h, 12, 1)
  -- grid
  gfx.color(theme.dark and "#1E3A2A" or "#D6E6DA")
  for i = 1, 7 do gfx.line(x + w * i / 8, y + 6, x + w * i / 8, y + h - 6, 1) end
  for i = 1, 3 do gfx.line(x + 6, y + h * i / 4, x + w - 6, y + h * i / 4, 1) end
  local cycles = 1 + 7 * log(f / FMIN) / log(FMAX / FMIN)
  local amp = (h / 2 - 12) * (0.15 + 0.85 * volume / 100)
  local n = 0
  local N = 200
  local ph = playing and phase or 0
  for i = 0, N do
    local px = x + 8 + (w - 16) * i / N
    local v = waveSample(wave, i / N * cycles + ph)
    n = n + 1; scopePts[n] = px
    n = n + 1; scopePts[n] = y + h / 2 - v * amp
  end
  for i = n + 1, #scopePts do scopePts[i] = nil end
  gfx.color(playing and "#30D158" or theme.text3)
  gfx.lines(scopePts, playing and 2.5 or 2)
  gfx.color(theme.text3)
  gfx.text(fmtFreq(f) .. " · " .. TR("cycles_shown"), x + 12, y + h - 22, 11)
end

local function drawWarnings(x, y, w, f)
  local msg, color = nil, theme.orange
  if volume > 70 then msg, color = TR("warn_volume"), theme.red
  elseif f > 12000 then msg = TR("warn_high")
  elseif f < 40 then msg = TR("warn_low") end
  if msg then
    gfx.icon("warning", x + 10, y + 9, 18, color)
    gfx.color(color)
    gfx.text(msg, x + 26, y + 1, 12, "semibold")
  end
end

local PRESETS = {
  {label = "A4 · 440 Hz", f = 440}, {label = "C4 · 261.6 Hz", f = 261.6}, {label = "1 kHz", f = 1000},
  {label = "100 Hz", f = 100}, {label = "50 Hz", f = 50}, {label = "10 kHz", f = 10000}, {label = "15 kHz", f = 15000},
}

local function drawTone(x, y, w)
  -- frequency read-out
  gfx.color(theme.text)
  local fw = gfx.text(fmtFreq(freq), x, y, 40, "bold")
  local name, cents = noteOf(freq)
  gfx.color(abs(cents) <= 2 and theme.green or theme.text2)
  local cs = cents == 0 and "±0" or ((cents > 0 and "+" or "") .. cents)
  gfx.text(name .. "  " .. cs .. "¢", x + fw + 14, y + 18, 16, "semibold")
  local tfw = 120
  local nf, sub = ui.textfield("freq", freqStr, x + w - tfw - 70, y + 8, tfw, 32, "Hz", "numeric")
  freqStr = nf
  local apply = ui.button(TR("set"), x + w - 62, y + 8, 62, 32, "default")
  if sub or apply then
    local v = tonumber((freqStr:gsub(",", ".")))
    if not v or v ~= v then showToast(TR("bad_number"))
    elseif v < FMIN or v > FMAX then showToast(TR("out_of_range"))
    else setFreq(v) end
  end

  -- log slider with a scale
  local sy = y + 58
  local p = ui.slider("logf", floor(toPos(freq) + 0.5), 0, 1000, x, sy, w, 1)
  if abs(p - floor(toPos(freq) + 0.5)) >= 1 then setFreq(fromPos(p), true) end
  gfx.color(theme.text3)
  for _, t in ipairs({20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000}) do
    local tx = x + 10 + (w - 20) * toPos(t) / 1000
    local lbl = t >= 1000 and (floor(t / 1000) .. "k") or tostring(t)
    gfx.text(lbl, tx - 20, sy + 30, 10, "sans", "center", 40)
  end

  -- fine steps
  local by = sy + 52
  local steps = {{"−10", -10}, {"−1", -1}, {"−0.1", -0.1}, {"+0.1", 0.1}, {"+1", 1}, {"+10", 10}}
  local n = #steps + 3
  local bw = (w - (n - 1) * 6) / n
  for i, s in ipairs(steps) do
    if ui.button(s[1] .. "##st" .. i, x + (i - 1) * (bw + 6), by, bw, 32, "default") then setFreq(freq + s[2]) end
  end
  local bx = x + #steps * (bw + 6)
  if ui.button("½##oct", bx, by, bw, 32, "default", nil, freq / 2 >= FMIN) then setFreq(freq / 2) end
  if ui.button("×2##oct", bx + bw + 6, by, bw, 32, "default", nil, freq * 2 <= FMAX) then setFreq(freq * 2) end
  if ui.button(TR("snap") .. "##snap", bx + 2 * (bw + 6), by, bw, 32, "default") then snapNote() end
  return by + 44
end

local function drawSweep(x, y, w)
  local fw = (w - 3 * 12) / 4
  gfx.color(theme.text2)
  gfx.text(TR("from"), x, y, 12, "semibold")
  gfx.text(TR("to"), x + fw + 12, y, 12, "semibold")
  gfx.text(TR("duration", sweepDur), x + 2 * (fw + 12), y, 12, "semibold")
  local a, sa = ui.textfield("from", fromStr, x, y + 18, fw, 32, "Hz", "numeric")
  local b, sb = ui.textfield("to", toStr, x + fw + 12, y + 18, fw, 32, "Hz", "numeric")
  fromStr, toStr = a, b
  if sa or sb then
    local va, vb = tonumber((fromStr:gsub(",", "."))), tonumber((toStr:gsub(",", ".")))
    if not va or not vb or va ~= va or vb ~= vb then showToast(TR("bad_number"))
    elseif va < FMIN or va > FMAX or vb < FMIN or vb > FMAX then showToast(TR("out_of_range"))
    elseif abs(va - vb) < 1 then showToast(TR("same_freq"))
    else sweepFrom, sweepTo = roundFreq(va), roundFreq(vb); saveAll() end
  end
  local d = ui.slider("dur", sweepDur, 2, 60, x + 2 * (fw + 12), y + 22, fw * 2 + 12, 1)
  if d ~= sweepDur then sweepDur = d; saveAll() end

  local py = y + 64
  local frac = playing and min(1, sweepT / sweepDur) or 0
  ui.progress(frac, x, py + 8, w - 220, 8)
  gfx.color(theme.text)
  gfx.text(playing and fmtFreq(sweepCur) or (fmtFreq(sweepFrom) .. " → " .. fmtFreq(sweepTo)), x + w - 210, py, 16, "bold")
  local lp = ui.checkbox(TR("loop"), sweepLoop, x, py + 26)
  if lp ~= sweepLoop then sweepLoop = lp; saveAll() end
  if ui.button(TR("swap"), x + 140, py + 22, 120, 30, "plain", "swap_horiz") then
    sweepFrom, sweepTo = sweepTo, sweepFrom
    fromStr, toStr = tostring(floor(sweepFrom)), tostring(floor(sweepTo))
    saveAll()
  end
  if ui.button(TR("full_range"), x + 270, py + 22, 150, 30, "plain", "open_in_full") then
    sweepFrom, sweepTo = 20, 20000
    fromStr, toStr = "20", "20000"
    saveAll()
  end
  return py + 64
end

local function drawToast(w, h)
  if toastT <= 0 then return end
  local a = min(1, toastT * 3, (2.4 - toastT) * 6)
  local tw = gfx.textWidth(toast, 13, "medium") + 32
  local tx, ty = (w - tw) / 2, h - 96 + (1 - a) * 10
  gfx.alpha(a)
  gfx.color(theme.text)
  gfx.rect(tx, ty, tw, 34, 17)
  gfx.color(theme.bg)
  gfx.text(toast, tx + 16, ty + 9, 13, "medium")
  gfx.unalpha()
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local cw = w - 2 * M
  local nm = ui.segmented("mode", {TR("mode_tone"), TR("mode_sweep")}, mode, M, 14, min(260, cw - 160), 32)
  if nm ~= mode then
    if playing then stopAll() end
    mode = nm; saveAll()
  end
  if ui.button(playing and TR("stop") or TR("play"), w - M - 140, 12, 140, 36, playing and "destructive" or "primary", playing and "stop" or "play_arrow") then
    togglePlay()
  end

  local y = 64
  local nextY = mode == 1 and drawTone(M, y, cw) or drawSweep(M, y, cw)

  -- bottom rows: presets, warning, wave + volume
  local py = h - M - 32
  local wy = py - 30
  local vy = wy - 44
  drawScope(M, nextY, cw, max(60, vy - nextY - 12), mode == 2 and playing and sweepCur > 0 and sweepCur or (mode == 2 and sweepFrom or freq))

  local ww = min(330, cw * 0.5)
  local nw = ui.segmented("wave", {TR("w_sine"), TR("w_square"), TR("w_saw"), TR("w_triangle")}, wave, M, vy, ww, 32)
  if nw ~= wave then wave = nw; saveAll() end
  gfx.icon("volume_up", M + ww + 26, vy + 16, 20, theme.text2)
  local sw = cw - ww - 100
  local v = ui.slider("vol", volume, 0, 100, M + ww + 40, vy + 2, sw, 1)
  if v ~= volume then volume = v; store.set("volume", volume) end
  gfx.color(volume > 70 and theme.red or theme.text)
  gfx.text(volume .. "%", 0, vy + 8, 13, "semibold", "right", w - M)

  drawWarnings(M, wy + 4, cw, mode == 2 and sweepTo or freq)

  -- presets as chips
  local px = M
  for i, p in ipairs(PRESETS) do
    local bw = gfx.textWidth(p.label, 12, "medium") + 26
    if px + bw > w - M then break end
    if ui.button(p.label .. "##pr" .. i, px, py, bw, 30, "default") then
      if mode ~= 1 then mode = 1; if playing then stopAll() end end
      setFreq(p.f); saveAll()
    end
    px = px + bw + 8
  end
  drawToast(w, h)
end

function app.event(e)
  if e.type ~= "keydown" then return end
  local k = e.key
  local step = e.shift and 10 or 1
  if k == "space" then togglePlay()
  elseif k == "escape" then stopAll()
  elseif mode == 1 then
    if k == "right" then setFreq(freq + step, true)
    elseif k == "left" then setFreq(freq - step, true)
    elseif k == "up" then setFreq(freq * 2, true)
    elseif k == "down" then setFreq(freq / 2, true)
    elseif k == "n" then snapNote()
    elseif k == "w" then wave = wave % 4 + 1; saveAll() end
  end
end

function app.menu()
  return {
    {title = TR("menu_tone"), items = {
      {label = TR("play") .. " / " .. TR("stop"), id = 1, shortcut = "Space"},
      {label = TR("snap"), id = 2, shortcut = "N"},
      {label = TR("octave_up"), id = 3, shortcut = "↑"},
      {label = TR("octave_down"), id = 4, shortcut = "↓"},
      {label = TR("next_wave"), id = 5, shortcut = "W"},
      "-",
      {label = TR("mode_tone"), id = 6},
      {label = TR("mode_sweep"), id = 7},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then togglePlay() elseif id == 2 then snapNote()
  elseif id == 3 then setFreq(freq * 2) elseif id == 4 then setFreq(freq / 2)
  elseif id == 5 then wave = wave % 4 + 1; saveAll()
  elseif id == 6 or id == 7 then
    if playing then stopAll() end
    mode = id - 5; saveAll()
  end
end

function app.close()
  stopAll()
  store.save()
  return true
end

return app
