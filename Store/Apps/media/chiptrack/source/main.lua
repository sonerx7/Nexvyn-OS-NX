-- Chiptrack for Nexvyn OS: a four-channel chiptune tracker. Patterns of notes, instruments with waveforms and
-- envelopes, effects (arpeggio, slides, vibrato, cut, tempo), a song order, live playback while you edit, an exact
-- render that plays back the finished mix, and WAV export. Keyboard (tracker layout), touch piano and controller.
local K = require("kit")
local S = require("synth")
local app = {}

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local clamp, alpha, mix = K.clamp, K.alpha, K.mix
local CH = S.CH

-- ================================================================== constants
local NOTE_NAMES = {"C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-"}
local WAVES = {"square", "pulse", "triangle", "saw", "sine", "noise", "kick", "snare", "hat"}
local WAVE_KEYS = {square = "w_square", pulse = "w_pulse", triangle = "w_triangle", saw = "w_saw", sine = "w_sine",
                   noise = "w_noise", kick = "w_kick", snare = "w_snare", hat = "w_hat"}
local FX = {"", "A", "U", "D", "V", "K", "T"}              -- index = code + 1
local FX_KEYS = {"fx_none", "fx_arp", "fx_up", "fx_down", "fx_vib", "fx_cut", "fx_tempo"}
local CH_COLORS = {"blue", "green", "orange", "pink"}
-- tracker keyboard: two rows of piano keys
local KEYMAP = {z = 0, s = 1, x = 2, d = 3, c = 4, v = 5, g = 6, b = 7, h = 8, n = 9, j = 10, m = 11,
                q = 12, ["2"] = 13, w = 14, ["3"] = 15, e = 16, r = 17, ["5"] = 18, t = 19, ["6"] = 20, y = 21,
                ["7"] = 22, u = 23, i = 24, ["9"] = 25, o = 26, ["0"] = 27, p = 28}

-- ================================================================== state
local songs, song, songIdx = {}, nil, 1
local curPat = 1
local cur = {row = 1, ch = 1, col = 1}
local octave, step = 4, 1
local curIns = 1
local selBlock = nil                 -- {r0, c0, r1, c1} (rows, channels)
local clipBlock = nil
local hist = K.history(60)
local dirty, changedAt = false, 0
local mutes, solo = {}, nil
local play = nil                     -- live playback {mode, rows, idx, acc, rowSec}
local hq = nil                       -- exact playback {times, rows, start}
local job = nil                      -- {co, purpose, progress, rows}
local meters = {0, 0, 0, 0}
local sideTab = 1                    -- 1 song, 2 instruments
local narrowTab = 1                  -- narrow windows: 1 pattern, 2 song, 3 instruments
local gridRect = {0, 0, 0, 0}
local gridScroll = 0
local hexRow = false
local sideScroll = K.scroller()
local sideRect = {0, 0, 0, 0}
local pendingDigit = nil             -- first hex digit typed into a two-digit column
local gridPress, lastPiano, sliderPushed = nil, nil, false

local function markDirty() dirty, changedAt = true, sys.time() end
local function pat() return song.patterns[curPat] end
local function cellAt(p, r, c)
  if not p or not p.cells then return nil end
  local v = p.cells[(r - 1) * CH + c]
  if type(v) == "table" then return v end
  return nil
end
local function setCell(p, r, c, v) p.cells[(r - 1) * CH + c] = v or 0 end
local function noteName(n)
  if n == -1 then return "===" end
  if not n or n <= 0 then return "···" end
  return NOTE_NAMES[n % 12 + 1] .. (floor(n / 12) - 1)
end
local function hex2(v) if not v or v < 0 then return "··" end return string.format("%02X", v) end

-- ================================================================== songs
local function emptyPattern(rows)
  local p = {rows = rows or 32, cells = {}}
  for i = 1, p.rows * CH do p.cells[i] = 0 end
  return p
end
local function defaultInstruments()
  return {
    {name = TR("ins_lead"), wave = "square", a = 0.004, d = 0.12, s = 0.55, r = 0.08, vol = 0.5},
    {name = TR("ins_arp"), wave = "pulse", a = 0.002, d = 0.05, s = 0.35, r = 0.04, vol = 0.35},
    {name = TR("ins_bass"), wave = "triangle", a = 0.003, d = 0.15, s = 0.8, r = 0.05, vol = 0.85},
    {name = TR("ins_kick"), wave = "kick", a = 0, d = 0, s = 1, r = 0.02, vol = 0.95},
    {name = TR("ins_snare"), wave = "snare", a = 0, d = 0, s = 1, r = 0.02, vol = 0.6},
    {name = TR("ins_hat"), wave = "hat", a = 0, d = 0, s = 1, r = 0.02, vol = 0.35},
  }
end

local function demoSong()
  local s = {name = TR("demo_name"), bpm = 128, lpb = 4, patterns = {emptyPattern(32), emptyPattern(32)}, order = {1, 2, 1, 2},
             instruments = defaultInstruments()}
  local function n(name, oct)
    local idx = {C = 0, ["C#"] = 1, D = 2, ["D#"] = 3, E = 4, F = 5, ["F#"] = 6, G = 7, ["G#"] = 8, A = 9, ["A#"] = 10, B = 11}
    return 12 * (oct + 1) + idx[name]
  end
  local function put(p, r, c, note, ins, vol, f, prm) setCell(s.patterns[p], r, c, {note, ins or 0, vol or -1, f or 0, prm or 0}) end
  -- lead melody
  local lead1 = {{1, "E", 5, 4}, {5, "D", 5, 2}, {7, "C", 5, 2}, {9, "D", 5, 4}, {13, "E", 5, 4},
                 {17, "F", 5, 4}, {21, "E", 5, 2}, {23, "D", 5, 2}, {25, "C", 5, 6}, {31, "A", 4, 2}}
  local lead2 = {{1, "G", 5, 4}, {5, "E", 5, 2}, {7, "C", 5, 2}, {9, "E", 5, 4}, {13, "G", 5, 2}, {15, "A", 5, 2},
                 {17, "G", 5, 4}, {21, "F", 5, 2}, {23, "E", 5, 2}, {25, "D", 5, 8}}
  for _, m in ipairs(lead1) do put(1, m[1], 1, n(m[2], m[3]), 1, nil, m[4] >= 4 and 4 or 0, m[4] >= 4 and 0x42 or 0) end
  for _, m in ipairs(lead2) do put(2, m[1], 1, n(m[2], m[3]), 1, nil, m[4] >= 4 and 4 or 0, m[4] >= 4 and 0x42 or 0) end
  put(1, 32, 1, -1)
  -- arpeggio chords: Am F | C G
  local chords = {{{"A", 4}, {"C", 5}, {"E", 5}}, {{"F", 4}, {"A", 4}, {"C", 5}}, {{"C", 5}, {"E", 5}, {"G", 5}}, {{"G", 4}, {"B", 4}, {"D", 5}}}
  for half = 0, 3 do
    local p = half < 2 and 1 or 2
    local ch = chords[half + 1]
    local base = (half % 2) * 16
    for r = 0, 15 do
      local tone = ch[r % 3 + 1]
      put(p, base + r + 1, 2, n(tone[1], tone[2]), 2, (r % 4 == 0) and 48 or 34)
    end
  end
  -- bass
  local roots = {{"A", 2}, {"F", 2}, {"C", 3}, {"G", 2}}
  for half = 0, 3 do
    local p = half < 2 and 1 or 2
    local base = (half % 2) * 16
    local rt = roots[half + 1]
    for k, off in ipairs({0, 4, 8, 12}) do
      put(p, base + off + 1, 3, n(rt[1], rt[2] + ((k % 2 == 0) and 1 or 0)), 3)
      put(p, base + off + 3, 3, -1)
    end
  end
  -- drums
  for p = 1, 2 do
    for r = 0, 31 do
      if r % 8 == 0 then put(p, r + 1, 4, n("C", 3), 4)
      elseif r % 8 == 4 then put(p, r + 1, 4, n("C", 3), 5)
      elseif r % 2 == 0 then put(p, r + 1, 4, n("C", 3), 6, (r % 4 == 2) and 40 or 26) end
    end
  end
  put(2, 31, 4, n("C", 3), 5, 40)
  return s
end

local function newSong()
  return {name = TR("new_song"), bpm = 120, lpb = 4, patterns = {emptyPattern(32)}, order = {1}, instruments = defaultInstruments()}
end

local function sanitizeSong(s)
  if type(s) ~= "table" then return nil end
  local o = {name = K.str(s.name, TR("new_song")), bpm = clamp(K.int(s.bpm, 120), 32, 255), lpb = clamp(K.int(s.lpb, 4), 1, 8),
             patterns = {}, order = {}, instruments = {}}
  for _, p in ipairs(type(s.patterns) == "table" and s.patterns or {}) do
    local rows = clamp(K.int(p.rows, 32), 8, 128)
    local np = {rows = rows, cells = {}}
    for i = 1, rows * CH do
      local c = type(p.cells) == "table" and p.cells[i] or 0
      if type(c) == "table" then
        np.cells[i] = {K.int(c[1], 0), K.int(c[2], 0), K.int(c[3], -1), K.int(c[4], 0), K.int(c[5], 0)}
      else np.cells[i] = 0 end
    end
    o.patterns[#o.patterns + 1] = np
  end
  if #o.patterns == 0 then o.patterns[1] = emptyPattern(32) end
  for _, v in ipairs(type(s.order) == "table" and s.order or {}) do
    local i = K.int(v, 1)
    if o.patterns[i] then o.order[#o.order + 1] = i end
  end
  if #o.order == 0 then o.order = {1} end
  for _, ins in ipairs(type(s.instruments) == "table" and s.instruments or {}) do
    if type(ins) == "table" then
      local w = "square"
      for _, x in ipairs(WAVES) do if x == ins.wave then w = x end end
      o.instruments[#o.instruments + 1] = {name = K.str(ins.name, "?"), wave = w, a = K.num(ins.a, 0.005), d = K.num(ins.d, 0.1),
                                           s = clamp(K.num(ins.s, 0.7), 0, 1), r = K.num(ins.r, 0.08), vol = clamp(K.num(ins.vol, 0.6), 0, 1)}
    end
  end
  if #o.instruments == 0 then o.instruments = defaultInstruments() end
  return o
end

local function saveNow()
  store.set("songs", songs)
  store.set("cur", songIdx)
  store.set("prefs", {octave = octave, step = step, hex = hexRow})
  dirty = false
end

local function loadAll()
  songs = {}
  local raw = store.get("songs", nil)
  if type(raw) == "table" then
    for _, s in ipairs(raw) do local x = sanitizeSong(s); if x then songs[#songs + 1] = x end end
  end
  if #songs == 0 then songs[1] = demoSong() end
  songIdx = clamp(K.int(store.get("cur", 1), 1), 1, #songs)
  song = songs[songIdx]
  local p = store.get("prefs", nil)
  if type(p) == "table" then octave = clamp(K.int(p.octave, 4), 0, 8); step = clamp(K.int(p.step, 1), 0, 16); hexRow = p.hex == true end
  curPat = song.order[1] or 1
end

-- ================================================================== undo
local function snap() return K.copy({patterns = song.patterns, order = song.order, instruments = song.instruments, bpm = song.bpm, lpb = song.lpb}) end
local function pushHist() hist:push(snap()) end
local function restore(s)
  song.patterns, song.order, song.instruments, song.bpm, song.lpb = s.patterns, s.order, s.instruments, s.bpm, s.lpb
  curPat = clamp(curPat, 1, #song.patterns)
  curIns = clamp(curIns, 1, #song.instruments)
  cur.row = clamp(cur.row, 1, pat().rows)
  markDirty()
end
local function undo() local s = hist:undo(snap()); if s then restore(s); K.toast(TR("undone"), "undo") end end
local function redo() local s = hist:redo(snap()); if s then restore(s); K.toast(TR("redone"), "redo") end end

-- ================================================================== sound
local LIVE_WAVE = {square = "square", pulse = "square", triangle = "triangle", saw = "saw", sine = "sine", noise = "noise"}
local function liveTone(ins, note, secs, vol)
  if not ins then return end
  local v = (ins.vol or 0.6) * (vol or 1)
  if ins.wave == "kick" then audio.tone(55, 0.14, min(1, v * 1.1), "sine")
  elseif ins.wave == "snare" then audio.tone(1800, 0.12, v * 0.7, "noise")
  elseif ins.wave == "hat" then audio.tone(6000, 0.04, v * 0.6, "noise")
  else
    secs = clamp(floor(secs * 20 + 0.5) / 20, 0.05, 2)
    audio.tone(floor(S.freq(note) * 100 + 0.5) / 100, secs, clamp(v, 0, 1), LIVE_WAVE[ins.wave] or "square")
  end
end
local function preview(note, insIdx)
  liveTone(song.instruments[insIdx or curIns], note, 0.35, 0.9)
end

local function stopAll()
  play = nil
  if hq then audio.musicStop(); hq = nil end
  job = job and job.purpose == "export" and job or nil
end

-- live playback: tones are triggered row by row
local function startLive(mode)
  stopAll()
  local rows = S.rowsOf(song, mode, curPat)
  local startIdx = 1
  if mode == "pattern" then startIdx = 1
  else
    -- start the song at the current pattern's first entry in the order
    local acc = 0
    for _, pi in ipairs(song.order) do
      if pi == curPat then startIdx = acc + 1; break end
      acc = acc + song.patterns[pi].rows
    end
  end
  play = {mode = mode, rows = rows, idx = startIdx - 1, acc = 1e9, bpm = song.bpm}
end

local function rowLength(rows, idx, c)
  -- how many rows until the next event in channel c
  local n = 0
  for k = idx + 1, min(#rows, idx + 16) do
    local rr = rows[k]
    local cell = cellAt(song.patterns[rr[1]], rr[2], c)
    n = n + 1
    if cell and cell[1] ~= 0 then break end
  end
  return max(1, n)
end

local function liveStep()
  play.idx = play.idx + 1
  if play.idx > #play.rows then
    if #play.rows == 0 then play = nil; return end
    play.idx = 1
  end
  local rr = play.rows[play.idx]
  local p = song.patterns[rr[1]]
  if not p or rr[2] > p.rows then play = nil; return end
  if play.mode == "song" and curPat ~= rr[1] then curPat = rr[1] end
  local rowSec = 60 / (play.bpm * song.lpb)
  for c = 1, CH do
    local cell = cellAt(p, rr[2], c)
    if cell then
      if cell[4] == 6 and cell[5] >= 32 then play.bpm = cell[5] end
      local audible = not mutes[c] and (not solo or solo == c)
      if cell[1] > 0 and audible then
        local ins = song.instruments[cell[2] > 0 and cell[2] or (play.lastIns and play.lastIns[c]) or 1]
        play.lastIns = play.lastIns or {}
        if cell[2] > 0 then play.lastIns[c] = cell[2] end
        local len = rowLength(play.rows, play.idx, c) * rowSec
        liveTone(ins, cell[1], len, cell[3] >= 0 and cell[3] / 64 or 1)
        meters[c] = 1
      end
    end
  end
end

-- exact playback / export: render in the background
local function startRender(purpose, mode)
  stopAll()
  local rows = S.rowsOf(song, mode or "song", curPat)
  if #rows == 0 then return end
  local m = {}
  for c = 1, CH do m[c] = mutes[c] or (solo and solo ~= c) or false end
  job = {co = S.job(song, rows, purpose == "play" and m or nil, 1), purpose = purpose, progress = 0, rows = rows, mode = mode}
end

local function finishRender(buf)
  local data = S.wav(buf)
  if job.purpose == "export" then
    local name = song.name:gsub("[/\\:%*%?\"<>|]", "-") .. ".wav"
    local secs = #buf / S.RATE
    ui.saveFile(function(p)
      if not p then return end
      if not p:lower():match("%.wav$") then p = p .. ".wav" end
      if fs.write(p, data) then K.toast(TR("exported_wav", string.format("%d:%02d", floor(secs / 60), floor(secs % 60))), "ios_share")
      else K.toast(TR("write_failed"), "error") end
    end, name, TR("export_wav"))
  else
    local path = fs.dir("cache") .. "/preview.wav"
    if fs.write(path, data) and audio.music(path) then
      -- row start times for the playhead
      local times, t, bpm = {}, 0, song.bpm
      for i, rr in ipairs(job.rows) do
        times[i] = t
        for c = 1, CH do
          local cell = cellAt(song.patterns[rr[1]], rr[2], c)
          if cell and cell[4] == 6 and cell[5] >= 32 then bpm = cell[5] end
        end
        t = t + 60 / (bpm * song.lpb)
      end
      hq = {times = times, rows = job.rows, start = sys.time(), total = t}
    else
      K.toast(TR("play_failed"), "error")
    end
  end
end

-- ================================================================== editing
local function curCell() return cellAt(pat(), cur.row, cur.ch) end
local function editCell(fn)
  pushHist()
  local p = pat()
  local c = curCell()
  local nc = c and {c[1], c[2], c[3], c[4], c[5]} or {0, 0, -1, 0, 0}
  fn(nc)
  if nc[1] == 0 and nc[2] == 0 and nc[3] < 0 and nc[4] == 0 then setCell(p, cur.row, cur.ch, 0) else setCell(p, cur.row, cur.ch, nc) end
  markDirty()
end
local function advance() if step > 0 then cur.row = clamp(cur.row + step, 1, pat().rows) end end

local function enterNote(n)
  editCell(function(c) c[1] = n; if n > 0 then c[2] = curIns end end)
  if n > 0 then preview(n) end
  advance()
end
local function clearCell()
  if selBlock then
    pushHist()
    local b = selBlock
    for r = min(b[1], b[3]), max(b[1], b[3]) do
      for c = min(b[2], b[4]), max(b[2], b[4]) do setCell(pat(), r, c, 0) end
    end
    markDirty()
    return
  end
  editCell(function(c)
    if cur.col == 1 then c[1], c[2], c[3], c[4], c[5] = 0, 0, -1, 0, 0
    elseif cur.col == 2 then c[2] = 0 elseif cur.col == 3 then c[3] = -1 else c[4], c[5] = 0, 0 end
  end)
  advance()
end

local function typeHex(d)
  if cur.col == 1 then return end
  if cur.col == 4 then
    -- effect letter column takes letters; digits go to the parameter
    cur.col = 5
  end
  local first = pendingDigit and pendingDigit.row == cur.row and pendingDigit.ch == cur.ch and pendingDigit.col == cur.col
  editCell(function(c)
    local idx = cur.col == 5 and 5 or cur.col
    local v = first and pendingDigit.v * 16 + d or d
    if cur.col == 2 then v = clamp(v, 0, #song.instruments)
    elseif cur.col == 3 then v = clamp(v, 0, 64) end
    c[idx] = v
  end)
  if first then pendingDigit = nil; advance() else pendingDigit = {row = cur.row, ch = cur.ch, col = cur.col, v = d} end
end

local function setEffect(code)
  editCell(function(c) c[4] = code; if code == 6 and c[5] < 32 then c[5] = song.bpm end end)
end

local function insertRow(delete)
  pushHist()
  local p = pat()
  for c = 1, CH do
    if delete then
      for r = cur.row, p.rows - 1 do setCell(p, r, c, cellAt(p, r + 1, c)) end
      setCell(p, p.rows, c, 0)
    else
      for r = p.rows, cur.row + 1, -1 do setCell(p, r, c, cellAt(p, r - 1, c)) end
      setCell(p, cur.row, c, 0)
    end
  end
  markDirty()
end

local function copyBlock(cut)
  local b = selBlock or {cur.row, cur.ch, cur.row, cur.ch}
  local r0, r1, c0, c1 = min(b[1], b[3]), max(b[1], b[3]), min(b[2], b[4]), max(b[2], b[4])
  clipBlock = {rows = r1 - r0 + 1, chs = c1 - c0 + 1, cells = {}}
  for r = r0, r1 do
    for c = c0, c1 do clipBlock.cells[#clipBlock.cells + 1] = K.copy(cellAt(pat(), r, c)) or 0 end
  end
  if cut then
    pushHist()
    for r = r0, r1 do for c = c0, c1 do setCell(pat(), r, c, 0) end end
    markDirty()
  end
  K.toast(TR(cut and "cut_done" or "copied", clipBlock.rows), "content_copy")
end
local function pasteBlock()
  if not clipBlock then return end
  pushHist()
  local i = 0
  for r = 0, clipBlock.rows - 1 do
    for c = 0, clipBlock.chs - 1 do
      i = i + 1
      local rr, cc = cur.row + r, cur.ch + c
      if rr <= pat().rows and cc <= CH then setCell(pat(), rr, cc, K.copy(clipBlock.cells[i])) end
    end
  end
  markDirty()
end
local function transpose(d)
  pushHist()
  local b = selBlock or {1, cur.ch, pat().rows, cur.ch}
  for r = min(b[1], b[3]), max(b[1], b[3]) do
    for c = min(b[2], b[4]), max(b[2], b[4]) do
      local cell = cellAt(pat(), r, c)
      if cell and cell[1] > 0 then cell[1] = clamp(cell[1] + d, 12, 119) end
    end
  end
  markDirty()
  K.toast(TR(d > 0 and "transposed_up" or "transposed_down", abs(d)), "music_note")
end

local function addPattern(copyOf)
  pushHist()
  local p = copyOf and K.copy(copyOf) or emptyPattern(pat().rows)
  song.patterns[#song.patterns + 1] = p
  curPat = #song.patterns
  markDirty()
end

-- ================================================================== drawing helpers
local function stepper(id, label, value, x, y, w, onMinus, onPlus)
  gfx.color(theme.text2)
  local lw = label ~= "" and gfx.textWidth(label, 12, "medium") + 6 or 0
  if lw > 0 then gfx.text(label, x, y + 9, 12, "medium") end
  if ui.iconButton("remove", x + lw, y + 2, 26, 28, theme.text2, false, "##m" .. id) then onMinus() end
  gfx.color(theme.text)
  gfx.text(value, x + lw + 26, y + 7, 14, "monobold", "center", w - lw - 52)
  if ui.iconButton("add", x + w - 26, y + 2, 26, 28, theme.text2, false, "##p" .. id) then onPlus() end
end

-- ================================================================== pattern grid
local function colLayout(cw)
  -- note, instrument, volume, effect+param
  local fs = cw >= 132 and 14 or 13
  local u = gfx.textWidth("0", fs, "mono")
  local wNote, w2 = u * 3 + 6, u * 2 + 6
  local full = wNote + w2 * 2 + u * 3 + 10 <= cw
  return {fs = fs, u = u, wNote = wNote, w2 = w2, full = full}
end

local function drawGrid(x, y, w, h)
  local p = pat()
  local headH = 30
  local rowH = 20
  local numW = 34
  local cw = floor((w - numW - 8) / CH)
  local L = colLayout(cw)
  gridRect = {x, y + headH, w, h - headH}
  -- headers with mute / solo
  for c = 1, CH do
    local hx = x + numW + (c - 1) * cw
    local col = theme[CH_COLORS[c]]
    gfx.rect(hx + 2, y + 4, cw - 4, headH - 6, 7, alpha(col, (mutes[c] or (solo and solo ~= c)) and 0.08 or 0.18))
    gfx.rect(hx + 2, y + headH - 5, (cw - 4) * meters[c], 3, 1.5, col)
    gfx.color(theme.text)
    gfx.text(TR("channel", c), hx + 10, y + 9, 12, "semibold")
    if ui.iconButton(mutes[c] and "volume_off" or "volume_up", hx + cw - 56, y + 3, 26, 24, mutes[c] and theme.red or theme.text2, mutes[c], "##mute" .. c) then
      mutes[c] = not mutes[c]
    end
    if ui.iconButton("headphones", hx + cw - 30, y + 3, 26, 24, solo == c and theme.accent or theme.text2, solo == c, "##solo" .. c) then
      solo = solo ~= c and c or nil
    end
  end
  -- rows
  local gy = y + headH
  local gh = h - headH
  local visible = floor(gh / rowH)
  local playRow = nil
  if play and play.rows[play.idx] and play.rows[play.idx][1] == curPat then playRow = play.rows[play.idx][2] end
  if hq then
    local t = sys.time() - hq.start
    if t > hq.total + 0.5 then hq = nil
    else
      local k = 1
      for i = 1, #hq.times do if hq.times[i] <= t then k = i else break end end
      local rr = hq.rows[k]
      if rr then
        if curPat ~= rr[1] and hq.follow ~= false then curPat = rr[1] end
        if rr[1] == curPat then playRow = rr[2] end
      end
    end
  end
  local focusRow = playRow or cur.row
  -- keep the focus row in the middle third
  local want = focusRow - floor(visible / 2)
  gridScroll = clamp(want, 0, max(0, p.rows - visible))
  gfx.clip(x, gy, w, gh)
  local hit = ui.hit("grid", x, gy, w, gh)
  for i = 1, visible + 1 do
    local r = gridScroll + i
    if r > p.rows then break end
    local ry = gy + (i - 1) * rowH
    local beat = (r - 1) % song.lpb == 0
    local bar = (r - 1) % (song.lpb * 4) == 0
    if bar then gfx.rect(x, ry, w, rowH, 0, alpha(theme.text, 0.07))
    elseif beat then gfx.rect(x, ry, w, rowH, 0, alpha(theme.text, 0.035)) end
    if r == playRow then gfx.rect(x, ry, w, rowH, 0, alpha(theme.green, 0.28)) end
    if r == cur.row then gfx.rect(x, ry, w, rowH, 0, alpha(theme.accent, 0.13)) end
    if selBlock then
      local b = selBlock
      if r >= min(b[1], b[3]) and r <= max(b[1], b[3]) then
        local c0, c1 = min(b[2], b[4]), max(b[2], b[4])
        gfx.rect(x + numW + (c0 - 1) * cw, ry, (c1 - c0 + 1) * cw, rowH, 0, alpha(theme.accent, 0.22))
      end
    end
    gfx.color(beat and theme.text2 or theme.text3)
    gfx.text(hexRow and string.format("%02X", r - 1) or string.format("%02d", r - 1), x + 4, ry + 2, L.fs - 1, "mono")
    for c = 1, CH do
      local cx = x + numW + (c - 1) * cw + 4
      local cell = cellAt(p, r, c)
      local cols = {}
      if cell then
        cols[1] = {noteName(cell[1]), cell[1] == -1 and theme.text3 or (cell[1] > 0 and theme.text or theme.text3)}
        cols[2] = {cell[2] > 0 and hex2(cell[2]) or "··", cell[2] > 0 and theme[CH_COLORS[c]] or theme.text3}
        cols[3] = {hex2(cell[3]), cell[3] >= 0 and theme.green or theme.text3}
        cols[4] = {cell[4] > 0 and (FX[cell[4] + 1] .. hex2(cell[5])) or "···", cell[4] > 0 and theme.purple or theme.text3}
      else
        cols = {{"···", theme.text3}, {"··", theme.text3}, {"··", theme.text3}, {"···", theme.text3}}
      end
      local xs = {cx, cx + L.wNote, cx + L.wNote + L.w2, cx + L.wNote + L.w2 * 2}
      local last = L.full and 4 or 2
      for k = 1, last do
        if r == cur.row and c == cur.ch and (cur.col == k or (k == 4 and cur.col == 5)) then
          local ww = (k == 1 or k == 4) and L.u * 3 + 4 or L.u * 2 + 4
          gfx.rect(xs[k] - 2, ry + 1, ww, rowH - 2, 4, alpha(theme.accent, K.editing and 0.25 or 0.5))
        end
        gfx.color(cols[k][2])
        gfx.text(cols[k][1], xs[k], ry + 2, L.fs, "mono")
      end
      gfx.color(alpha(theme.separator, 0.7))
      gfx.line(x + numW + c * cw - 1, ry, x + numW + c * cw - 1, ry + rowH, 1)
    end
  end
  gfx.unclip()
  -- pointer: pick a cell / drag a block
  local mx, my = ui.mouse()
  local function cellAtPointer()
    local r = gridScroll + floor((my - gy) / rowH) + 1
    local c = floor((mx - x - numW) / cw) + 1
    if c < 1 or c > CH or r < 1 or r > p.rows then return nil end
    local lx = mx - (x + numW + (c - 1) * cw + 4)
    local col = 1
    if lx >= L.wNote then col = 2 end
    if lx >= L.wNote + L.w2 then col = 3 end
    if lx >= L.wNote + L.w2 * 2 then col = 4 end
    if not L.full and col > 2 then col = 2 end
    return r, c, col
  end
  if hit.pressed then
    local r, c, col = cellAtPointer()
    if r then
      if selBlock and not hit.doubleClicked then selBlock = nil end
      cur.row, cur.ch, cur.col = r, c, col
      pendingDigit = nil
      gridPress = {r = r, c = c}
    end
  end
  if hit.held and gridPress then
    local r, c = cellAtPointer()
    if r and (r ~= gridPress.r or c ~= gridPress.c) then selBlock = {gridPress.r, gridPress.c, r, c} end
  end
  if not hit.held then gridPress = nil end
  if hit.rightClicked then
    ui.contextMenu({{label = TR("copy"), id = 1, icon = "content_copy"}, {label = TR("cut"), id = 2, icon = "content_cut"},
                    {label = TR("paste"), id = 3, icon = "content_paste"}, "-",
                    {label = TR("insert_row"), id = 4, icon = "vertical_align_bottom"}, {label = TR("delete_row"), id = 5, icon = "vertical_align_top"},
                    "-", {label = TR("transpose_up"), id = 6, icon = "arrow_upward"}, {label = TR("transpose_down"), id = 7, icon = "arrow_downward"},
                    {label = TR("clear"), id = 8, icon = "backspace"}}, function(id)
      if id == 1 then copyBlock(false) elseif id == 2 then copyBlock(true) elseif id == 3 then pasteBlock()
      elseif id == 4 then insertRow(false) elseif id == 5 then insertRow(true)
      elseif id == 6 then transpose(1) elseif id == 7 then transpose(-1) elseif id == 8 then clearCell() end
    end)
  end
end

-- ================================================================== piano and cell inspector
local function drawPiano(x, y, w, h)
  gfx.rect(x, y, w, h, 0, theme.sidebar)
  local whites = {0, 2, 4, 5, 7, 9, 11}
  local nW = clamp(floor(w / 44), 7, 21)
  local kw = w / nW
  local base = 12 * (octave + 1)
  local mx, my = ui.mouse()
  local hit = ui.hit("piano", x, y, w, h)
  local pressedNote = nil
  -- black keys first for hit testing
  local blackRects = {}
  for i = 0, nW - 1 do
    local oct, wi = floor(i / 7), i % 7
    local semi = whites[wi + 1]
    if semi ~= 4 and semi ~= 11 and i < nW - 1 then
      blackRects[#blackRects + 1] = {x + (i + 1) * kw - kw * 0.3, y, kw * 0.6, h * 0.6, base + oct * 12 + semi + 1}
    end
  end
  if hit.pressed then
    for _, b in ipairs(blackRects) do
      if mx >= b[1] and mx <= b[1] + b[3] and my >= b[2] and my <= b[2] + b[4] then pressedNote = b[5] end
    end
    if not pressedNote then
      local i = floor((mx - x) / kw)
      pressedNote = base + floor(i / 7) * 12 + whites[i % 7 + 1]
    end
  end
  for i = 0, nW - 1 do
    local oct, wi = floor(i / 7), i % 7
    local note = base + oct * 12 + whites[wi + 1]
    local kx = x + i * kw
    local lit = (pressedNote == note) or (hit.held and hit.hovered and lastPiano == note)
    gfx.rect(kx + 1, y + 1, kw - 2, h - 2, 5, lit and alpha(theme.accent, 0.5) or (theme.dark and "#E8E8EA" or "#FFFFFF"))
    gfx.color(alpha("#000000", 0.25)); gfx.rectLine(kx + 1, y + 1, kw - 2, h - 2, 5, 1)
    if wi == 0 then
      gfx.color("#6E6E73")
      gfx.text("C" .. (octave + oct), kx, y + h - 18, 11, "medium", "center", kw)
    end
  end
  for _, b in ipairs(blackRects) do
    local lit = (pressedNote == b[5]) or (hit.held and lastPiano == b[5])
    gfx.rect(b[1], b[2], b[3], b[4], 4, lit and theme.accent or "#1C1C1E")
  end
  if pressedNote then
    lastPiano = pressedNote
    if pressedNote <= 119 then
      if cur.col == 1 then enterNote(pressedNote) else preview(pressedNote) end
    end
  end
  if not hit.held then lastPiano = nil end
end

local function drawInspector(x, y, w, h)
  gfx.rect(x, y, w, h, 0, theme.window)
  gfx.color(theme.separator); gfx.line(x, y, x + w, y, 1)
  local c = curCell() or {0, 0, -1, 0, 0}
  local bx = x + 10
  local by = y + (h - 32) / 2
  local function seg(width) local r = bx; bx = bx + width + 8; return r end
  local compact = w < 760
  stepper("oct", TR("octave"), tostring(octave), seg(compact and 96 or 120), by, compact and 96 or 120, function() octave = max(0, octave - 1) end, function() octave = min(8, octave + 1) end)
  stepper("step", TR("step"), tostring(step), seg(compact and 96 or 112), by, compact and 96 or 112, function() step = max(0, step - 1) end, function() step = min(16, step + 1) end)
  stepper("ins", TR("ins_short"), hex2(curIns), seg(compact and 96 or 112), by, compact and 96 or 112,
          function() curIns = max(1, curIns - 1) end, function() curIns = min(#song.instruments, curIns + 1) end)
  if w > 640 then
    local fxi = ui.dropdown("fxsel", (function() local t = {}; for i, k in ipairs(FX_KEYS) do t[i] = TR(k) end; return t end)(), c[4] + 1, seg(150), by, 150, 32)
    if fxi - 1 ~= c[4] then setEffect(fxi - 1) end
  end
  if w > 860 then
    stepper("prm", "", hex2(c[4] > 0 and c[5] or nil), seg(100), by, 100,
            function() if c[4] > 0 then editCell(function(x2) x2[5] = max(0, x2[5] - 1) end) end end,
            function() if c[4] > 0 then editCell(function(x2) x2[5] = min(255, x2[5] + 1) end) end end)
  end
  local right = x + w - 10
  right = right - 44
  if ui.button("===", right, by, 44, 32, "default") then enterNote(-1) end
  right = right - 40
  if ui.iconButton("backspace", right, by, 36, 32, theme.text2, false, "##clr") then clearCell() end
end

-- ================================================================== side panel: song and instruments
local function drawSong(x, y, w, h)
  local p = 14
  local yy = y + 8
  gfx.color(theme.text)
  local nh = ui.hit("songname", x + p - 4, yy, w - p * 2 + 8, 28)
  if nh.hovered then gfx.rect(x + p - 4, yy, w - p * 2 + 8, 28, 6, theme.hover) end
  gfx.text(K.ellipsize(song.name, 16, "bold", w - p * 2 - 24), x + p, yy + 4, 16, "bold")
  gfx.icon("edit", x + w - p - 8, yy + 14, 14, theme.text3)
  if nh.clicked then
    ui.prompt(TR("rename"), TR("song_name"), song.name, function(t) if t and K.trim(t) ~= "" then song.name = K.trim(t); markDirty() end end)
  end
  yy = yy + 38
  stepper("bpm", TR("bpm"), tostring(song.bpm), x + p, yy, w - p * 2,
          function() pushHist(); song.bpm = max(32, song.bpm - 2); markDirty() end, function() pushHist(); song.bpm = min(255, song.bpm + 2); markDirty() end)
  yy = yy + 36
  stepper("lpb", TR("lpb"), tostring(song.lpb), x + p, yy, w - p * 2,
          function() pushHist(); song.lpb = max(1, song.lpb - 1); markDirty() end, function() pushHist(); song.lpb = min(8, song.lpb + 1); markDirty() end)
  yy = yy + 36
  stepper("rows", TR("rows"), tostring(pat().rows), x + p, yy, w - p * 2, function()
    local pp = pat()
    if pp.rows > 8 then
      pushHist()
      local nr = pp.rows <= 16 and pp.rows - 4 or pp.rows - 8
      local cells = {}
      for i = 1, nr * CH do cells[i] = pp.cells[i] or 0 end
      pp.cells, pp.rows = cells, nr
      cur.row = clamp(cur.row, 1, nr)
      markDirty()
    end
  end, function()
    local pp = pat()
    if pp.rows < 128 then
      pushHist()
      local nr = pp.rows < 16 and pp.rows + 4 or pp.rows + 8
      for i = pp.rows * CH + 1, nr * CH do pp.cells[i] = 0 end
      pp.rows = nr
      markDirty()
    end
  end)
  yy = yy + 44
  K.heading(TR("order"), x + p, yy, w - p * 2)
  yy = yy + 20
  -- order list
  local listH = h - (yy - y) - 52
  local rowH = 34
  local playing = nil
  if play and play.mode == "song" then
    local acc = 0
    for i, pi in ipairs(song.order) do
      if play.idx > acc and play.idx <= acc + song.patterns[pi].rows then playing = i end
      acc = acc + song.patterns[pi].rows
    end
  end
  gfx.clip(x, yy, w, listH)
  for i, pi in ipairs(song.order) do
    local ry = yy + (i - 1) * rowH - sideScroll.y
    if ry > yy - rowH and ry < yy + listH then
      local active = pi == curPat
      local hit = ui.hit("ord" .. i, x + p, ry, w - p * 2 - 70, rowH - 4)
      gfx.rect(x + p, ry, w - p * 2, rowH - 4, 8, active and alpha(theme.accent, 0.18) or (hit.hovered and theme.hover or alpha(theme.text, 0.04)))
      if playing == i then gfx.icon("play_arrow", x + p + 12, ry + 15, 16, theme.green) end
      gfx.color(theme.text2)
      gfx.text(string.format("%02d", i), x + p + 22, ry + 7, 13, "mono")
      gfx.color(theme.text)
      gfx.text(TR("pattern_n", string.format("%02d", pi)), x + p + 50, ry + 7, 13, "semibold")
      if hit.clicked and not sideScroll:dragged() then curPat = pi; cur.row = clamp(cur.row, 1, pat().rows) end
      if ui.iconButton("chevron_left", x + w - p - 66, ry + 1, 30, rowH - 6, theme.text2, false, "##ol" .. i) then
        pushHist(); song.order[i] = pi > 1 and pi - 1 or #song.patterns; markDirty()
      end
      if ui.iconButton("chevron_right", x + w - p - 34, ry + 1, 30, rowH - 6, theme.text2, false, "##or" .. i) then
        pushHist(); song.order[i] = pi < #song.patterns and pi + 1 or 1; markDirty()
      end
    end
  end
  gfx.unclip()
  sideRect = {x, yy, w, listH}
  sideScroll:setMax(#song.order * rowH - listH)
  local by = y + h - 44
  local bw = floor((w - p * 2 - 18) / 4)
  if ui.iconButton("playlist_add", x + p, by, bw, 34, theme.text2, false, "##oadd") then
    pushHist(); song.order[#song.order + 1] = curPat; markDirty()
  end
  if ui.iconButton("add_box", x + p + (bw + 6), by, bw, 34, theme.text2, false, "##pnew") then
    addPattern(nil); song.order[#song.order + 1] = curPat
  end
  if ui.iconButton("library_add", x + p + (bw + 6) * 2, by, bw, 34, theme.text2, false, "##pdup") then
    addPattern(pat()); song.order[#song.order + 1] = curPat
  end
  if ui.iconButton("playlist_remove", x + p + (bw + 6) * 3, by, bw, 34, theme.text2, false, "##odel") then
    if #song.order > 1 then
      pushHist()
      local idx = #song.order
      for i, pi in ipairs(song.order) do if pi == curPat then idx = i end end
      table.remove(song.order, idx)
      markDirty()
    end
  end
end

local WAVE_ICONS = {square = "crop_square", pulse = "view_week", triangle = "change_history", saw = "show_chart", sine = "waves",
                    noise = "grain", kick = "radio_button_checked", snare = "blur_on", hat = "flare"}
local function drawInstruments(x, y, w, h)
  local p = 14
  local yy = y + 8
  local listH = min(6, #song.instruments) * 34
  for i, ins in ipairs(song.instruments) do
    if i > 6 and #song.instruments > 6 and i ~= curIns then goto continue end
    do
      local ry = yy + (min(i, 6) - 1) * 34
      if i > 6 then ry = yy + 5 * 34 end
      local hit = ui.hit("ins" .. i, x + p, ry, w - p * 2 - 36, 30)
      gfx.rect(x + p, ry, w - p * 2, 30, 8, i == curIns and alpha(theme.accent, 0.18) or (hit.hovered and theme.hover or alpha(theme.text, 0.04)))
      gfx.color(theme.text2)
      gfx.text(hex2(i), x + p + 8, ry + 7, 13, "mono")
      gfx.icon(WAVE_ICONS[ins.wave] or "graphic_eq", x + p + 44, ry + 15, 16, theme.accent)
      gfx.color(theme.text)
      gfx.text(K.ellipsize(ins.name, 13, "semibold", w - p * 2 - 110), x + p + 60, ry + 7, 13, "semibold")
      if hit.clicked then curIns = i; preview(60, i) end
      if ui.iconButton("play_arrow", x + w - p - 34, ry, 32, 30, theme.text2, false, "##ip" .. i) then preview(60, i) end
    end
    ::continue::
  end
  yy = yy + listH + 6
  local ins = song.instruments[curIns]
  if not ins then return end
  local bw = floor((w - p * 2 - 12) / 3)
  if ui.button(TR("ins_new"), x + p, yy, bw, 30, "default", "add") then
    if #song.instruments < 16 then
      pushHist()
      local n = K.copy(ins)
      n.name = TR("ins_n", #song.instruments + 1)
      song.instruments[#song.instruments + 1] = n
      curIns = #song.instruments
      markDirty()
    end
  end
  if ui.button(TR("rename"), x + p + bw + 6, yy, bw, 30, "default") then
    ui.prompt(TR("rename"), TR("ins_name"), ins.name, function(t) if t and K.trim(t) ~= "" then ins.name = K.trim(t); markDirty() end end)
  end
  if ui.button(TR("delete"), x + p + (bw + 6) * 2, yy, bw, 30, "destructive") then
    if #song.instruments > 1 then
      pushHist()
      table.remove(song.instruments, curIns)
      curIns = clamp(curIns, 1, #song.instruments)
      markDirty()
    end
  end
  yy = yy + 40
  local waveNames = {}
  for i, wv in ipairs(WAVES) do waveNames[i] = TR(WAVE_KEYS[wv]) end
  local wi = 1
  for i, wv in ipairs(WAVES) do if wv == ins.wave then wi = i end end
  gfx.color(theme.text2); gfx.text(TR("wave"), x + p, yy + 7, 13, "medium")
  local nwi = ui.dropdown("wave", waveNames, wi, x + p + 80, yy, w - p * 2 - 80, 30)
  if nwi ~= wi then pushHist(); ins.wave = WAVES[nwi]; markDirty(); preview(60) end
  yy = yy + 40
  -- envelope drawing
  local drum = ins.wave == "kick" or ins.wave == "snare" or ins.wave == "hat"
  local ew, eh = w - p * 2, 56
  gfx.rect(x + p, yy, ew, eh, 8, alpha(theme.text, 0.05))
  local pts = {}
  local total = drum and 0.3 or ((ins.a or 0) + (ins.d or 0) + 0.25 + (ins.r or 0))
  for i = 0, 40 do
    local t = i / 40 * total
    local lvl
    if drum then
      local dec = ins.wave == "kick" and 0.22 or (ins.wave == "snare" and 0.16 or 0.05)
      lvl = max(0, 1 - t / dec) ^ 2
    elseif t < (ins.a or 0) + (ins.d or 0) + 0.25 then lvl = S.envLevel(ins, t)
    else lvl = S.envLevel(ins, t, t - ((ins.a or 0) + (ins.d or 0) + 0.25), S.envLevel(ins, (ins.a or 0) + (ins.d or 0) + 0.25)) end
    pts[#pts + 1] = x + p + 6 + i / 40 * (ew - 12)
    pts[#pts + 1] = yy + eh - 6 - lvl * (eh - 12) * (ins.vol or 0.6)
  end
  gfx.color(theme.accent)
  gfx.lines(pts, 2, false)
  yy = yy + eh + 10
  local function slider(label, key, lo, hi, fmt)
    gfx.color(theme.text2)
    gfx.text(label, x + p, yy + 4, 12, "medium")
    gfx.color(theme.text)
    gfx.text(string.format(fmt, ins[key] or 0), x + p, yy + 4, 12, "mono", "right", w - p * 2)
    local nv = ui.slider("sl_" .. key, ins[key] or 0, lo, hi, x + p, yy + 20, w - p * 2)
    if abs(nv - (ins[key] or 0)) > 1e-6 then
      if not sliderPushed then pushHist(); sliderPushed = true end
      ins[key] = nv
      markDirty()
    end
    yy = yy + 48
  end
  slider(TR("volume"), "vol", 0, 1, "%.2f")
  if not drum then
    slider(TR("attack"), "a", 0, 0.5, "%.3fs")
    slider(TR("decay"), "d", 0, 1, "%.2fs")
    slider(TR("sustain"), "s", 0, 1, "%.2f")
    slider(TR("release"), "r", 0.01, 1.5, "%.2fs")
  end
end

local function drawSide(x, y, w, h)
  gfx.rect(x, y, w, h, 0, theme.sidebar)
  gfx.color(theme.separator); gfx.line(x, y, x, y + h, 1)
  sideTab = ui.segmented("stab", {TR("song"), TR("instruments")}, sideTab, x + 12, y + 10, w - 24, 30)
  if sideTab == 1 then drawSong(x, y + 46, w, h - 46) else drawInstruments(x, y + 46, w, h - 46) end
end

-- ================================================================== top bar
local function drawTop(w)
  local tb = 52
  gfx.rect(0, 0, w, tb, 0, theme.window)
  local bx = 10
  if ui.iconButton("library_music", bx, 10, 36, 32, theme.text2, false, "##songs") then
    local items = {}
    for i, s in ipairs(songs) do items[#items + 1] = {label = (i == songIdx and "• " or "") .. s.name, id = i, icon = "music_note"} end
    items[#items + 1] = "-"
    items[#items + 1] = {label = TR("new_song"), id = 1001, icon = "add"}
    items[#items + 1] = {label = TR("open_file"), id = 1002, icon = "folder_open"}
    items[#items + 1] = {label = TR("save_file"), id = 1003, icon = "save"}
    items[#items + 1] = {label = TR("delete_song"), id = 1004, icon = "delete"}
    ui.contextMenu(items, function(id)
      if id <= #songs then
        stopAll(); songIdx = id; song = songs[id]; curPat = song.order[1] or 1; hist:clear(); cur.row = 1; saveNow()
      elseif id == 1001 then
        stopAll(); songs[#songs + 1] = newSong(); songIdx = #songs; song = songs[songIdx]; curPat = 1; hist:clear(); cur.row = 1; saveNow()
      elseif id == 1002 then app.onmenu(3)
      elseif id == 1003 then app.onmenu(4)
      elseif id == 1004 then app.onmenu(6) end
    end)
  end
  bx = bx + 42
  local playingPat = play and play.mode == "pattern"
  local playingSong = (play and play.mode == "song") or hq ~= nil
  if ui.iconButton(playingPat and "stop" or "play_arrow", bx, 8, 40, 36, playingPat and theme.red or theme.green, playingPat, "##pp") then
    if playingPat then stopAll() else startLive("pattern") end
  end
  bx = bx + 44
  if ui.iconButton(playingSong and "stop" or "queue_music", bx, 8, 40, 36, playingSong and theme.red or theme.accent, playingSong, "##ps") then
    if playingSong then stopAll() else startLive("song") end
  end
  bx = bx + 48
  -- pattern selector
  if ui.iconButton("chevron_left", bx, 10, 28, 32, theme.text2, false, "##pprev") then curPat = max(1, curPat - 1); cur.row = clamp(cur.row, 1, pat().rows) end
  gfx.color(theme.text)
  gfx.text(TR("pattern_n", string.format("%02d", curPat)), bx + 28, 18, 14, "semibold", "center", 96)
  if ui.iconButton("chevron_right", bx + 124, 10, 28, 32, theme.text2, false, "##pnext") then
    if curPat < #song.patterns then curPat = curPat + 1 else addPattern(nil) end
    cur.row = clamp(cur.row, 1, pat().rows)
  end
  bx = bx + 160
  local right = w - 10
  local function rb(icon, id, tint, enabled, label)
    if label and w > 900 then
      local bw = gfx.textWidth(label, 13, "medium") + 46
      right = right - bw - 4
      if ui.button(label, right, 10, bw, 32, "default", icon, enabled ~= false) then return true end
      return false
    end
    right = right - 38
    if enabled == false then gfx.icon(icon, right + 18, 26, 20, theme.text3); return false end
    return ui.iconButton(icon, right, 10, 36, 32, tint or theme.text2, false, id)
  end
  if rb("ios_share", "##exp", nil, job == nil, TR("export_wav_short")) then startRender("export", "song") end
  if rb("high_quality", "##hq", theme.purple, job == nil, TR("render_play")) then startRender("play", "song") end
  if rb("redo", "##redo", nil, hist:canRedo()) then redo() end
  if rb("undo", "##undo", nil, hist:canUndo()) then undo() end
  -- render progress
  if job then
    local px = bx
    local pw = right - bx - 12
    if pw > 60 then
      gfx.color(theme.text2)
      gfx.text(job.purpose == "export" and TR("rendering_export") or TR("rendering"), px, 10, 11, "medium")
      ui.progress(job.progress, px, 30, pw, 6)
    end
  elseif hq then
    gfx.color(theme.purple)
    local t = sys.time() - hq.start
    gfx.text(TR("hq_playing", string.format("%d:%02d", floor(t / 60), floor(t % 60))), bx, 18, 13, "medium")
  end
  gfx.color(theme.separator); gfx.line(0, tb, w, tb, 1)
  return tb
end

-- ================================================================== app callbacks
function app.load(arg)
  loadAll()
  if type(arg) == "string" and arg:lower():match("%.chiptrack$") then app.onmenu(1000, arg) end
end
function app.open(arg)
  if type(arg) == "string" and arg:lower():match("%.chiptrack$") then app.onmenu(1000, arg) end
end

function app.update(dt)
  sideScroll:update(dt)
  for c = 1, CH do meters[c] = max(0, meters[c] - dt * 2.5) end
  if play then
    local rowSec = 60 / (play.bpm * song.lpb)
    play.acc = play.acc + dt
    if play.acc >= rowSec then
      play.acc = play.acc >= 1e8 and 0 or (play.acc - rowSec)
      if play.acc > rowSec then play.acc = 0 end
      liveStep()
    end
  end
  if hq then
    local t = sys.time() - hq.start
    local k = 1
    for i = 1, #hq.times do if hq.times[i] <= t then k = i else break end end
    if hq.lastK ~= k then
      hq.lastK = k
      local rr = hq.rows[k]
      if rr then for c = 1, CH do local cell = cellAt(song.patterns[rr[1]], rr[2], c); if cell and cell[1] > 0 then meters[c] = 1 end end end
    end
  end
  if job then
    local t0 = os.clock()
    while os.clock() - t0 < 0.012 do
      local ok, res = coroutine.resume(job.co)
      if not ok then K.toast(TR("render_failed"), "error"); sys.log("render: " .. tostring(res)); job = nil; break end
      if coroutine.status(job.co) == "dead" then
        local j = job
        finishRender(res)
        if job == j then job = nil end
        break
      end
      job.progress = res or job.progress
    end
  end
  if dirty and sys.time() - changedAt > 1.5 then saveNow() end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  if not song then return end
  local tb = drawTop(w)
  local narrow = w < 820
  local pianoH = h >= 520 and 86 or (h >= 440 and 64 or 0)
  local inspH = 46
  local bodyH = h - tb - inspH - pianoH
  if narrow then
    narrowTab = ui.segmented("ntab", {TR("pattern"), TR("song"), TR("instruments")}, narrowTab, 10, tb + 6, w - 20, 30)
    local by = tb + 42
    if narrowTab == 1 then
      drawGrid(0, by, w, bodyH - 42)
      drawInspector(0, h - inspH - pianoH, w, inspH)
      if pianoH > 0 then drawPiano(0, h - pianoH, w, pianoH) end
    else
      gfx.rect(0, by, w, h - by, 0, theme.sidebar)
      if narrowTab == 2 then drawSong(0, by, w, h - by) else drawInstruments(0, by, w, h - by) end
    end
  else
    local sw = clamp(floor(w * 0.28), 250, 330)
    drawGrid(0, tb, w - sw, bodyH)
    drawInspector(0, tb + bodyH, w - sw, inspH)
    if pianoH > 0 then drawPiano(0, h - pianoH, w - sw, pianoH) end
    drawSide(w - sw, tb, sw, h - tb)
  end
  K.drawToast(w, h)
  K.frameEnd()
end

local function moveCursor(dr, dc, shift)
  local p = pat()
  if shift then
    selBlock = selBlock or {cur.row, cur.ch, cur.row, cur.ch}
  elseif dr ~= 0 or dc ~= 0 then
    selBlock = nil
  end
  if dc ~= 0 then
    local maxCol = 5
    cur.col = cur.col + dc
    if cur.col == 5 and dc > 0 then cur.col = 5 end
    if cur.col > maxCol then cur.col = 1; cur.ch = cur.ch % CH + 1
    elseif cur.col < 1 then cur.col = maxCol; cur.ch = (cur.ch - 2) % CH + 1 end
  end
  if dr ~= 0 then
    cur.row = cur.row + dr
    if cur.row < 1 then cur.row = p.rows elseif cur.row > p.rows then cur.row = 1 end
  end
  if shift then selBlock[3], selBlock[4] = cur.row, cur.ch end
  pendingDigit = nil
end

function app.event(e)
  if K.press(e) then return end
  if e.type == "mouseup" then sliderPushed = false end
  if sideScroll:event(e, sideRect) then return end
  if e.type == "scroll" and gridRect[3] > 0 and e.x >= gridRect[1] and e.x <= gridRect[1] + gridRect[3] and e.y >= gridRect[2] then
    local d = (e.dy or 0) > 0 and 1 or ((e.dy or 0) < 0 and -1 or 0)
    if d ~= 0 then cur.row = clamp(cur.row + d * 2, 1, pat().rows) end
    return
  end
  if e.type ~= "keydown" or K.editing then return end
  local k = e.key
  if e.ctrl then
    if k == "z" then if e.shift then redo() else undo() end
    elseif k == "y" then redo()
    elseif k == "c" then copyBlock(false)
    elseif k == "x" then copyBlock(true)
    elseif k == "v" then pasteBlock()
    elseif k == "a" then selBlock = {1, 1, pat().rows, CH}
    elseif k == "s" then saveNow(); K.toast(TR("saved"), "save")
    elseif k == "e" then if not job then startRender("export", "song") end
    elseif k == "r" then if not job then startRender("play", "song") end
    elseif k == "up" then transpose(e.shift and 12 or 1)
    elseif k == "down" then transpose(e.shift and -12 or -1)
    elseif k == "o" then app.onmenu(3) end
    return
  end
  if k == "space" then
    if play or hq then stopAll() else startLive(e.shift and "song" or "pattern") end
  elseif k == "enter" then
    if play or hq then stopAll() else startLive("song") end
  elseif k == "up" then moveCursor(-1, 0, e.shift)
  elseif k == "down" then moveCursor(1, 0, e.shift)
  elseif k == "left" then moveCursor(0, -1, e.shift)
  elseif k == "right" then moveCursor(0, 1, e.shift)
  elseif k == "tab" then cur.ch = e.shift and ((cur.ch - 2) % CH + 1) or (cur.ch % CH + 1); cur.col = 1
  elseif k == "pageup" then cur.row = max(1, cur.row - 16)
  elseif k == "pagedown" then cur.row = min(pat().rows, cur.row + 16)
  elseif k == "home" then cur.row = 1
  elseif k == "end" then cur.row = pat().rows
  elseif k == "delete" or k == "backspace" then clearCell()
  elseif k == "insert" then insertRow(false)
  elseif k == "escape" then selBlock = nil; stopAll()
  elseif k == "f1" then octave = max(0, octave - 1); K.toast(TR("octave_n", octave), "piano")
  elseif k == "f2" then octave = min(8, octave + 1); K.toast(TR("octave_n", octave), "piano")
  elseif cur.col == 1 then
    if k == "1" or k == "a" then enterNote(-1)
    elseif KEYMAP[k] then
      local n = 12 * (octave + 1) + KEYMAP[k]
      if n <= 119 then enterNote(n) end
    end
  elseif cur.col == 4 then
    local codes = {a = 1, u = 2, d = 3, v = 4, k = 5, t = 6}
    if codes[k] then setEffect(codes[k]); cur.col = 5
    elseif k:match("^[0-9]$") then typeHex(tonumber(k)) end
  else
    local d = k:match("^[0-9a-f]$") and tonumber(k, 16)
    if d then typeHex(d) end
  end
end

function app.menu()
  return {
    {title = TR("m_file"), items = {
      {label = TR("new_song"), id = 1},
      {label = TR("demo_load"), id = 2},
      {label = TR("open_file"), id = 3, shortcut = "Ctrl+O"},
      {label = TR("save_file"), id = 4},
      "-",
      {label = TR("export_wav"), id = 5, shortcut = "Ctrl+E"},
      "-",
      {label = TR("delete_song"), id = 6},
    }},
    {title = TR("m_edit"), items = {
      {label = TR("undo"), id = 10, shortcut = "Ctrl+Z"},
      {label = TR("redo"), id = 11, shortcut = "Ctrl+Y"},
      "-",
      {label = TR("copy"), id = 12, shortcut = "Ctrl+C"},
      {label = TR("cut"), id = 13, shortcut = "Ctrl+X"},
      {label = TR("paste"), id = 14, shortcut = "Ctrl+V"},
      {label = TR("select_all"), id = 15, shortcut = "Ctrl+A"},
      "-",
      {label = TR("transpose_up"), id = 16, shortcut = "Ctrl+↑"},
      {label = TR("transpose_down"), id = 17, shortcut = "Ctrl+↓"},
      {label = TR("insert_row"), id = 18, shortcut = "Ins"},
      {label = TR("delete_row"), id = 19},
    }},
    {title = TR("m_play"), items = {
      {label = TR("play_pattern"), id = 20, shortcut = "Space"},
      {label = TR("play_song"), id = 21, shortcut = "Enter"},
      {label = TR("render_play"), id = 22, shortcut = "Ctrl+R"},
      {label = TR("stop"), id = 23, shortcut = "Esc"},
      "-",
      {label = TR("hex_rows"), id = 24},
    }},
  }
end

function app.onmenu(id, path)
  if id == 1 then stopAll(); songs[#songs + 1] = newSong(); songIdx = #songs; song = songs[songIdx]; curPat = 1; hist:clear(); saveNow()
  elseif id == 2 then stopAll(); songs[#songs + 1] = demoSong(); songIdx = #songs; song = songs[songIdx]; curPat = 1; hist:clear(); saveNow()
  elseif id == 3 then
    ui.openFile(function(p) if p then app.onmenu(1000, p) end end, {".chiptrack", ".json"}, TR("open_file"))
  elseif id == 1000 and path then
    local data = fs.read(path)
    local s = data and sanitizeSong(json.decode(data))
    if s and data:find("chiptrack", 1, true) then
      stopAll()
      songs[#songs + 1] = s
      songIdx = #songs
      song = s
      curPat = s.order[1] or 1
      hist:clear()
      saveNow()
      K.toast(TR("opened", s.name), "folder_open")
    else K.toast(TR("not_song"), "error") end
  elseif id == 4 then
    ui.saveFile(function(p)
      if not p then return end
      if not p:lower():match("%.chiptrack$") then p = p .. ".chiptrack" end
      local d = K.copy(song)
      d.app = "chiptrack"
      if fs.write(p, json.encode(d, true)) then K.toast(TR("saved"), "save") else K.toast(TR("write_failed"), "error") end
    end, song.name:gsub("[/\\:%*%?\"<>|]", "-") .. ".chiptrack", TR("save_file"))
  elseif id == 5 then if not job then startRender("export", "song") end
  elseif id == 6 then
    ui.alert(TR("delete_song"), TR("delete_song_msg", song.name), {TR("delete"), TR("cancel")}, function(b)
      if b ~= 1 then return end
      stopAll()
      table.remove(songs, songIdx)
      if #songs == 0 then songs[1] = newSong() end
      songIdx = clamp(songIdx, 1, #songs)
      song = songs[songIdx]
      curPat = song.order[1] or 1
      hist:clear()
      saveNow()
    end)
  elseif id == 10 then undo() elseif id == 11 then redo()
  elseif id == 12 then copyBlock(false) elseif id == 13 then copyBlock(true) elseif id == 14 then pasteBlock()
  elseif id == 15 then selBlock = {1, 1, pat().rows, CH}
  elseif id == 16 then transpose(1) elseif id == 17 then transpose(-1)
  elseif id == 18 then insertRow(false) elseif id == 19 then insertRow(true)
  elseif id == 20 then startLive("pattern") elseif id == 21 then startLive("song")
  elseif id == 22 then if not job then startRender("play", "song") end
  elseif id == 23 then stopAll()
  elseif id == 24 then hexRow = not hexRow; saveNow() end
end

function app.suspend() stopAll(); if dirty then saveNow() end end
function app.autosave() if dirty then saveNow() end end
function app.unsaved() return dirty end
function app.close()
  stopAll()
  saveNow()
  store.save()
  return true
end

return app
