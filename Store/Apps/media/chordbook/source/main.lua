-- Chordbook for Nexvyn OS: chords, scales and progressions for guitar, ukulele, bass and piano. Chord shapes are
-- worked out for every root and type (not a fixed table), scales are drawn across the whole neck, the circle of
-- fifths shows each key's chords, and a progression player loops your own sequences. Every chord can be heard.
local K = require("kit")
local app = {}

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local clamp, alpha, mix = K.clamp, K.alpha, K.mix

-- ================================================================== music data
local SHARP = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local FLAT = {"C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"}
local SOLF = {"Do", "Do#", "Re", "Re#", "Mi", "Fa", "Fa#", "Sol", "Sol#", "La", "La#", "Si"}
local SOLF_FLAT = {"Do", "Re♭", "Re", "Mi♭", "Mi", "Fa", "Sol♭", "Sol", "La♭", "La", "Si♭", "Si"}
-- chord types: symbol, intervals, name key
local QUAL = {
  {"", {0, 4, 7}, "q_maj"}, {"m", {0, 3, 7}, "q_min"}, {"7", {0, 4, 7, 10}, "q_7"}, {"maj7", {0, 4, 7, 11}, "q_maj7"},
  {"m7", {0, 3, 7, 10}, "q_m7"}, {"sus2", {0, 2, 7}, "q_sus2"}, {"sus4", {0, 5, 7}, "q_sus4"}, {"dim", {0, 3, 6}, "q_dim"},
  {"aug", {0, 4, 8}, "q_aug"}, {"6", {0, 4, 7, 9}, "q_6"}, {"m6", {0, 3, 7, 9}, "q_m6"}, {"add9", {0, 4, 7, 2}, "q_add9"},
  {"9", {0, 4, 7, 10, 2}, "q_9"}, {"7sus4", {0, 5, 7, 10}, "q_7sus4"}, {"dim7", {0, 3, 6, 9}, "q_dim7"}, {"m7♭5", {0, 3, 6, 10}, "q_m7b5"},
}
local SCALES = {
  {"s_major", {0, 2, 4, 5, 7, 9, 11}}, {"s_minor", {0, 2, 3, 5, 7, 8, 10}}, {"s_hminor", {0, 2, 3, 5, 7, 8, 11}},
  {"s_mminor", {0, 2, 3, 5, 7, 9, 11}}, {"s_pmaj", {0, 2, 4, 7, 9}}, {"s_pmin", {0, 3, 5, 7, 10}}, {"s_blues", {0, 3, 5, 6, 7, 10}},
  {"s_dorian", {0, 2, 3, 5, 7, 9, 10}}, {"s_phrygian", {0, 1, 3, 5, 7, 8, 10}}, {"s_lydian", {0, 2, 4, 6, 7, 9, 11}},
  {"s_mixo", {0, 2, 4, 5, 7, 9, 10}}, {"s_locrian", {0, 1, 3, 5, 6, 8, 10}}, {"s_whole", {0, 2, 4, 6, 8, 10}},
}
local INSTR = {
  {key = "i_guitar", tuning = {40, 45, 50, 55, 59, 64}, frets = 15},
  {key = "i_ukulele", tuning = {67, 60, 64, 69}, frets = 12},
  {key = "i_bass", tuning = {28, 33, 38, 43}, frets = 15},
  {key = "i_piano"},
}
local DEGREE_Q = {1, 2, 2, 1, 1, 2, 8}               -- diatonic triads of a major key
local ROMAN = {"I", "ii", "iii", "IV", "V", "vi", "vii°"}
local MAJOR = {0, 2, 4, 5, 7, 9, 11}
local PRESETS = {
  {"p_pop", {1, 5, 6, 4}}, {"p_doo", {1, 6, 4, 5}}, {"p_jazz", {2, 5, 1, 1}}, {"p_sad", {6, 4, 1, 5}},
  {"p_rock", {1, 4, 5, 4}}, {"p_blues", {1, 1, 1, 1, 4, 4, 1, 1, 5, 4, 1, 5}},
}

-- ================================================================== state
local tab = 1                       -- 1 chords, 2 scales, 3 circle, 4 progressions
local inst = 1
local root, qual = 1, 1             -- root 1..12 (C..B), quality index
local voicing = 1
local scaleRoot, scaleIdx = 10, 2   -- A minor
local showDegrees = false
local useFlats, solfege = false, false
local keyRoot = 1                   -- circle of fifths: selected major key (pc + 1)
local progs = {}
local progIdx = 1
local playing = nil                 -- progression playback {i, t}
local strumQ = {}                   -- pending notes {at, freq}
local hist = K.history(60)
local dirty, changedAt = false, 0
local litNotes = {}                 -- notes sounding now (pc -> time) for the piano/fretboard glow
local frameDt = 1 / 60
local listScroll = K.scroller()
local listRect = {0, 0, 0, 0}

local function markDirty() dirty, changedAt = true, sys.time() end
local function noteName(pc)
  pc = pc % 12 + 1
  if solfege then return useFlats and SOLF_FLAT[pc] or SOLF[pc] end
  return useFlats and FLAT[pc] or SHARP[pc]
end
local function chordName(r, q) return noteName(r - 1) .. QUAL[q][1] end
local function freq(m) return 440 * 2 ^ ((m - 69) / 12) end

-- ================================================================== sound
local function playMidi(list, gap, dur)
  local t = sys.time()
  for i, m in ipairs(list) do strumQ[#strumQ + 1] = {at = t + (i - 1) * (gap or 0.035), m = m, dur = dur or 1.4} end
end
local function chordMidi(r, q, base)
  local out = {}
  base = base or 48
  for _, iv in ipairs(QUAL[q][2]) do out[#out + 1] = base + (r - 1) + iv end
  table.sort(out)
  return out
end

-- ================================================================== voicing finder (fretted instruments)
local vcache = {}
local function findVoicings(ii, r, q)
  local key = ii .. ":" .. r .. ":" .. q
  if vcache[key] then return vcache[key] end
  local I = INSTR[ii]
  local tun = I.tuning
  local n = #tun
  local pcs = {}
  local rootPc = (r - 1) % 12
  for _, iv in ipairs(QUAL[q][2]) do pcs[(rootPc + iv) % 12] = true end
  local need = #QUAL[q][2]
  local results, seen = {}, {}
  local isBass = ii == 3
  for base = 0, I.frets - 3 do
    local shape = {}
    local function dfs(s, anyPlayed)
      if s > n then
        -- evaluate
        local played, fretted, lo, hi, used, opens = 0, 0, 99, 0, {}, 0
        local bassPc, bassM = nil, 999
        for i = 1, n do
          local f = shape[i]
          if f >= 0 then
            played = played + 1
            local pc = (tun[i] + f) % 12
            used[pc] = true
            if tun[i] + f < bassM then bassM, bassPc = tun[i] + f, pc end
            if f > 0 then fretted = fretted + 1; lo = min(lo, f); hi = max(hi, f) else opens = opens + 1 end
          end
        end
        if played < (isBass and 2 or min(3, n)) then return end
        local cover = 0
        for pc in pairs(pcs) do if used[pc] then cover = cover + 1 end end
        local fifth = (rootPc + 7) % 12
        local missingOk = need >= 4 and cover == need - 1 and pcs[fifth] and not used[fifth]
        if cover < need and not missingOk and not isBass then return end
        if isBass and not used[rootPc] then return end
        if hi > 0 and hi - lo > 3 then return end
        local k = table.concat(shape, ",")
        if seen[k] then return end
        seen[k] = true
        local score = played * 3 + (bassPc == rootPc and 12 or 0) - (hi > 0 and (hi - lo) * 1.5 or 0) - lo * 0.6
        if missingOk then score = score - 4 end
        if hi >= 5 then score = score - opens * 5 end      -- open strings far from the nut are awkward
        if hi <= 3 then score = score + 3 end              -- open position
        -- fingers: notes above the lowest fret count; a barre covers the lowest fret
        local atLo = 0
        for i = 1, n do if shape[i] == lo then atLo = atLo + 1 end end
        local fingers = fretted - (atLo >= 2 and atLo - 1 or 0)
        if fingers > 4 then return end
        results[#results + 1] = {frets = {table.unpack(shape)}, score = score, lo = lo, hi = hi, barre = atLo >= 3 and lo > 0}
        return
      end
      local opts = {}
      -- muting is allowed only on the low strings (before anything sounds) or on the top string of a bass shape
      if not anyPlayed or isBass then opts[#opts + 1] = -1 end
      if pcs[tun[s] % 12] then opts[#opts + 1] = 0 end
      for f = max(1, base), base + 3 do
        if f <= I.frets and pcs[(tun[s] + f) % 12] then opts[#opts + 1] = f end
      end
      for _, f in ipairs(opts) do
        shape[s] = f
        dfs(s + 1, anyPlayed or f >= 0)
      end
      shape[s] = nil
    end
    dfs(1, false)
  end
  table.sort(results, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.lo < b.lo end)
  local out = {}
  for i = 1, min(8, #results) do out[i] = results[i] end
  vcache[key] = out
  return out
end

-- ================================================================== progressions
local function defaultProgs()
  return {
    {name = TR("p_pop"), key = 1, chords = {{1, 1}, {8, 1}, {10, 2}, {6, 1}}, bpm = 96, beats = 4},
    {name = TR("p_jazz"), key = 6, chords = {{8, 5}, {1, 3}, {6, 4}, {6, 4}}, bpm = 110, beats = 4},
  }
end
local function saveNow()
  store.set("progs", progs)
  store.set("prefs", {tab = tab, inst = inst, root = root, qual = qual, scaleRoot = scaleRoot, scale = scaleIdx, flats = useFlats,
                      solf = solfege, key = keyRoot, prog = progIdx, deg = showDegrees})
  dirty = false
end
local function loadAll()
  local p = store.get("prefs", nil)
  local lang = sys.lang()
  solfege = (lang == "tr" or lang == "fr" or lang == "es")
  if type(p) == "table" then
    tab = clamp(K.int(p.tab, 1), 1, 4); inst = clamp(K.int(p.inst, 1), 1, #INSTR)
    root = clamp(K.int(p.root, 1), 1, 12); qual = clamp(K.int(p.qual, 1), 1, #QUAL)
    scaleRoot = clamp(K.int(p.scaleRoot, 10), 1, 12); scaleIdx = clamp(K.int(p.scale, 2), 1, #SCALES)
    useFlats = p.flats == true; if p.solf ~= nil then solfege = p.solf == true end
    keyRoot = clamp(K.int(p.key, 1), 1, 12); progIdx = K.int(p.prog, 1); showDegrees = p.deg == true
  end
  local raw = store.get("progs", nil)
  progs = {}
  if type(raw) == "table" then
    for _, x in ipairs(raw) do
      if type(x) == "table" and type(x.chords) == "table" then
        local np = {name = K.str(x.name, "?"), key = clamp(K.int(x.key, 1), 1, 12), chords = {}, bpm = clamp(K.int(x.bpm, 100), 40, 220), beats = clamp(K.int(x.beats, 4), 1, 8)}
        for _, c in ipairs(x.chords) do
          if type(c) == "table" then np.chords[#np.chords + 1] = {clamp(K.int(c[1], 1), 1, 12), clamp(K.int(c[2], 1), 1, #QUAL)} end
        end
        progs[#progs + 1] = np
      end
    end
  end
  if #progs == 0 then progs = defaultProgs() end
  progIdx = clamp(progIdx, 1, #progs)
end
local function prog() return progs[progIdx] end
local function pushHist() hist:push(K.copy(progs)) end
local function undo() local s = hist:undo(K.copy(progs)); if s then progs = s; progIdx = clamp(progIdx, 1, #progs); markDirty(); K.toast(TR("undone"), "undo") end end
local function redo() local s = hist:redo(K.copy(progs)); if s then progs = s; progIdx = clamp(progIdx, 1, #progs); markDirty(); K.toast(TR("redone"), "redo") end end

local function diatonic(keyPc, deg)
  return (keyPc + MAJOR[deg]) % 12 + 1, DEGREE_Q[deg]
end

local function playChord(r, q)
  local I = INSTR[inst]
  if I.tuning then
    local v = findVoicings(inst, r, q)[clamp(voicing, 1, 8)] or findVoicings(inst, r, q)[1]
    if v then
      local list = {}
      for i, f in ipairs(v.frets) do if f >= 0 then list[#list + 1] = I.tuning[i] + f end end
      playMidi(list, 0.04, 1.6)
      return
    end
  end
  playMidi(chordMidi(r, q, 48), 0.02, 1.6)
end

-- ================================================================== drawing helpers
local function noteChip(id, label, x, y, w, h, active, color)
  local hit = ui.hit(id, x, y, w, h)
  local c = color or theme.accent
  gfx.rect(x, y, w, h, 8, active and c or (hit.hovered and theme.hover or alpha(theme.text, 0.05)))
  gfx.color(active and K.onColor(c) or theme.text)
  gfx.text(label, x, y + (h - 17) / 2, 14, "semibold", "center", w)
  return hit.clicked
end

local function rootPicker(x, y, w, cur, idp)
  local per = w >= 380 and 12 or 6
  local bw = floor((w - (per - 1) * 4) / per)
  local picked = nil
  for i = 1, 12 do
    local cx = x + ((i - 1) % per) * (bw + 4)
    local cy = y + floor((i - 1) / per) * 38
    if noteChip(idp .. i, noteName(i - 1), cx, cy, bw, 34, cur == i) then picked = i end
  end
  return picked, (per == 12) and 38 or 76
end

-- chord diagram for fretted instruments
local function drawDiagram(v, x, y, w, h, tun)
  local n = #tun
  local frets = 5
  local start = (v.hi <= 5) and 1 or v.lo
  local top = y + 34
  local fh = (h - 60) / frets
  local sw = w / (n - 1)
  -- nut or start fret
  if start == 1 then gfx.rect(x - 2, top - 5, w + 4, 6, 2, theme.text)
  else gfx.color(theme.text2); gfx.text(TR("fret_n", start), x - 52, top + fh / 2 - 8, 13, "medium", "right", 46) end
  gfx.color(alpha(theme.text, 0.5))
  for f = 0, frets do gfx.line(x, top + f * fh, x + w, top + f * fh, 1.5) end
  for s = 1, n do gfx.line(x + (s - 1) * sw, top, x + (s - 1) * sw, top + frets * fh, 1.5 + (n - s) * 0.25) end
  if v.barre then
    local first, last = nil, nil
    for s = 1, n do if v.frets[s] == v.lo then first = first or s; last = s end end
    local by = top + (v.lo - start + 0.5) * fh
    gfx.rect(x + (first - 1) * sw - 9, by - 9, (last - first) * sw + 18, 18, 9, theme.accent)
  end
  for s = 1, n do
    local f = v.frets[s]
    local sx = x + (s - 1) * sw
    if f < 0 then gfx.color(theme.text3); gfx.text("×", sx - 10, top - 30, 18, "bold", "center", 20)
    elseif f == 0 then gfx.color(theme.text2); gfx.circleLine(sx, top - 18, 7, 2)
    else
      local fy = top + (f - start + 0.5) * fh
      local isRoot = (tun[s] + f) % 12 == (root - 1)
      gfx.circle(sx, fy, min(13, sw * 0.32), isRoot and theme.orange or theme.accent)
    end
    -- note name under the string
    if f >= 0 then
      gfx.color(theme.text2)
      gfx.text(noteName((tun[s] + f) % 12), sx - 18, top + frets * fh + 8, 12, "medium", "center", 36)
    end
  end
end

local function drawPiano(x, y, w, h, notes, rootPc, labels)
  local whites = {0, 2, 4, 5, 7, 9, 11}
  local octs = w > 520 and 3 or 2
  local nW = 7 * octs
  local kw = w / nW
  local now = sys.time()
  local set = {}
  for _, m in ipairs(notes) do set[m % 12] = true end
  for i = 0, nW - 1 do
    local pc = whites[i % 7 + 1]
    local kx = x + i * kw
    local on = set[pc]
    local glow = litNotes[pc] and now - litNotes[pc] < 0.5
    gfx.rect(kx + 1, y, kw - 2, h, 5, glow and mix("#FFFFFF", theme.accent, 0.5) or "#FFFFFF")
    gfx.color(alpha("#000000", 0.2)); gfx.rectLine(kx + 1, y, kw - 2, h, 5, 1)
    if on then
      gfx.circle(kx + kw / 2, y + h - 22, min(12, kw * 0.3), pc == rootPc and theme.orange or theme.accent)
      if labels then gfx.color("#3A3A3C"); gfx.text(noteName(pc), kx, y + h - 50, 11, "semibold", "center", kw) end
    end
  end
  for i = 0, nW - 2 do
    local pc = whites[i % 7 + 1]
    if pc ~= 4 and pc ~= 11 then
      local bpc = pc + 1
      local bx = x + (i + 1) * kw - kw * 0.3
      local glow = litNotes[bpc] and now - litNotes[bpc] < 0.5
      gfx.rect(bx, y, kw * 0.6, h * 0.6, 4, glow and theme.accent or "#1C1C1E")
      if set[bpc] then gfx.circle(bx + kw * 0.3, y + h * 0.6 - 14, min(9, kw * 0.22), bpc == rootPc and theme.orange or theme.accent) end
    end
  end
end

-- whole-neck fretboard for scales
local function drawFretboard(x, y, w, h, tun, frets, pcsSet, rootPc, degrees)
  local n = #tun
  local fw = w / (frets + 1)
  local sh = h / n
  gfx.rect(x + fw, y, w - fw, h, 6, theme.dark and "#3B2E22" or "#E9D5B5")
  for f = 1, frets do
    gfx.color(f == 1 and alpha(theme.text, 0.8) or alpha(theme.text, 0.25))
    gfx.line(x + fw * (f + 0.0), y, x + fw * f, y + h, f == 1 and 3 or 1.5)
  end
  for _, m in ipairs({3, 5, 7, 9, 15}) do if m <= frets then gfx.circle(x + fw * (m + 0.5), y + h / 2, 4, alpha(theme.text, 0.25)) end end
  if frets >= 12 then gfx.circle(x + fw * 12.5, y + h * 0.3, 4, alpha(theme.text, 0.25)); gfx.circle(x + fw * 12.5, y + h * 0.7, 4, alpha(theme.text, 0.25)) end
  for s = 1, n do
    local sy = y + h - (s - 0.5) * sh
    gfx.color(alpha(theme.text, 0.45))
    gfx.line(x + fw, sy, x + w, sy, 1 + (n - s) * 0.3)
    for f = 0, frets do
      local pc = (tun[s] + f) % 12
      if pcsSet[pc] then
        local cx = f == 0 and x + fw * 0.5 or x + fw * (f + 0.5)
        local r = min(fw, sh) * 0.36
        gfx.circle(cx, sy, r, pc == rootPc and theme.orange or theme.accent)
        gfx.color("#FFFFFF")
        local label = degrees and pcsSet[pc] or noteName(pc)
        gfx.text(tostring(label), cx - r, sy - r * 0.62, max(8, floor(r * 1.05)), "bold", "center", r * 2)
      end
    end
  end
  gfx.color(theme.text3)
  for f = 1, frets do gfx.text(tostring(f), x + fw * f, y + h + 4, 11, "mono", "center", fw) end
end

-- ================================================================== tabs
local function drawChords(x, y, w, h)
  local p = 16
  local picked, ph = rootPicker(x + p, y + 10, w - p * 2, root, "r")
  if picked then root = picked; voicing = 1; markDirty(); playChord(root, qual) end
  local yy = y + 10 + ph + 6
  -- qualities
  local cx = x + p
  for i, q in ipairs(QUAL) do
    local label = noteName(root - 1) .. q[1]
    local cw = gfx.textWidth(label, 13, "semibold") + 22
    if cx + cw > x + w - p then cx = x + p; yy = yy + 36 end
    local hit = ui.hit("q" .. i, cx, yy, cw, 30)
    gfx.rect(cx, yy, cw, 30, 15, qual == i and theme.accent or (hit.hovered and theme.hover or alpha(theme.text, 0.05)))
    gfx.color(qual == i and "#FFFFFF" or theme.text)
    gfx.text(label, cx, yy + 6, 13, "semibold", "center", cw)
    if hit.clicked then qual = i; voicing = 1; markDirty(); playChord(root, qual) end
    cx = cx + cw + 6
  end
  yy = yy + 44
  -- info line
  local q = QUAL[qual]
  local notes = {}
  for _, iv in ipairs(q[2]) do notes[#notes + 1] = noteName(root - 1 + iv) end
  gfx.color(theme.text)
  gfx.text(chordName(root, qual), x + p, yy, 28, "bold")
  local nw = gfx.textWidth(chordName(root, qual), 28, "bold")
  gfx.color(theme.text2)
  gfx.text(TR(q[3]) .. " · " .. table.concat(notes, " – "), x + p + nw + 14, yy + 10, 14, "medium")
  if ui.button(TR("play"), x + w - p - 110, yy, 110, 34, "primary", "play_arrow") then playChord(root, qual) end
  yy = yy + 48
  local I = INSTR[inst]
  local area = h - (yy - y) - 10
  if I.tuning then
    local vs = findVoicings(inst, root, qual)
    if #vs == 0 then K.empty("music_off", TR("no_shape"), nil, x, yy, w, area); return end
    voicing = clamp(voicing, 1, #vs)
    local dw = min(300, w * 0.42, area * 0.75)
    local dx = x + p + 60
    drawDiagram(vs[voicing], dx, yy, dw, min(area, dw * 1.15), I.tuning)
    -- voicing switcher and list of the other shapes
    local lx = dx + dw + 40
    if lx + 160 < x + w then
      gfx.color(theme.text2)
      gfx.text(TR("shape_n", voicing, #vs), lx, yy, 13, "medium")
      if ui.iconButton("chevron_left", lx, yy + 22, 40, 34, theme.text2, false, "##vp") then voicing = (voicing - 2) % #vs + 1; playChord(root, qual) end
      if ui.iconButton("chevron_right", lx + 44, yy + 22, 40, 34, theme.text2, false, "##vn") then voicing = voicing % #vs + 1; playChord(root, qual) end
      local ly = yy + 66
      for i, v in ipairs(vs) do
        if ly + 30 > yy + area then break end
        local parts = {}
        for _, f in ipairs(v.frets) do parts[#parts + 1] = f < 0 and "x" or tostring(f) end
        local hit = ui.hit("vs" .. i, lx, ly, x + w - p - lx, 30)
        gfx.rect(lx, ly, x + w - p - lx, 30, 8, i == voicing and alpha(theme.accent, 0.16) or (hit.hovered and theme.hover or alpha(theme.text, 0.04)))
        gfx.color(theme.text)
        gfx.text(table.concat(parts, " "), lx + 10, ly + 6, 14, "mono")
        if hit.clicked then voicing = i; playChord(root, qual) end
        ly = ly + 34
      end
    end
  else
    drawPiano(x + p, yy, w - p * 2, min(area, 170), chordMidi(root, qual, 48), root - 1, true)
  end
end

local function drawScales(x, y, w, h)
  local p = 16
  local picked, ph = rootPicker(x + p, y + 10, w - p * 2, scaleRoot, "sr")
  if picked then scaleRoot = picked; markDirty() end
  local yy = y + 10 + ph + 4
  local names = {}
  for i, s in ipairs(SCALES) do names[i] = TR(s[1]) end
  local ns = ui.dropdown("scale", names, scaleIdx, x + p, yy, min(260, w * 0.4), 32)
  if ns ~= scaleIdx then scaleIdx = ns; markDirty() end
  local dg = ui.segmented("deg", {TR("names"), TR("degrees")}, showDegrees and 2 or 1, x + p + min(260, w * 0.4) + 10, yy, 200, 32)
  if (dg == 2) ~= showDegrees then showDegrees = dg == 2; markDirty() end
  if ui.button(TR("play"), x + w - p - 110, yy, 110, 32, "primary", "play_arrow") then
    local list = {}
    local base = 48 + scaleRoot - 1
    for _, iv in ipairs(SCALES[scaleIdx][2]) do list[#list + 1] = base + iv end
    list[#list + 1] = base + 12
    playMidi(list, 0.28, 0.5)
  end
  yy = yy + 44
  local sc = SCALES[scaleIdx][2]
  local set = {}
  local degLabels = {"1", "♭2", "2", "♭3", "3", "4", "♭5", "5", "♭6", "6", "♭7", "7"}
  for _, iv in ipairs(sc) do set[(scaleRoot - 1 + iv) % 12] = showDegrees and degLabels[iv + 1] or true end
  local notes = {}
  for _, iv in ipairs(sc) do notes[#notes + 1] = noteName(scaleRoot - 1 + iv) end
  gfx.color(theme.text2)
  gfx.text(noteName(scaleRoot - 1) .. " " .. TR(SCALES[scaleIdx][1]) .. ":  " .. table.concat(notes, "  "), x + p, yy, 14, "medium")
  yy = yy + 30
  local I = INSTR[inst]
  local area = h - (yy - y) - 24
  if I.tuning then
    drawFretboard(x + p, yy, w - p * 2, min(area, #I.tuning * 34), I.tuning, min(I.frets, w > 800 and 15 or 12), set, scaleRoot - 1, showDegrees)
  else
    local ms = {}
    for _, iv in ipairs(sc) do ms[#ms + 1] = 48 + scaleRoot - 1 + iv end
    drawPiano(x + p, yy, w - p * 2, min(area, 170), ms, scaleRoot - 1, true)
  end
end

local function drawCircle(x, y, w, h)
  local listW = w >= 760 and 300 or 0
  local cw = w - listW
  local cx, cy = x + cw / 2, y + h / 2
  local R = min(cw, h) / 2 - 24
  local mx, my = ui.mouse()
  local hitAll = ui.hit("circle", x, y, cw, h)
  local hoverIdx = nil
  for i = 0, 11 do
    local pc = (i * 7) % 12
    local a0 = (i - 0.5) / 12 * math.pi * 2 - math.pi / 2
    local a1 = (i + 0.5) / 12 * math.pi * 2 - math.pi / 2
    local am = i / 12 * math.pi * 2 - math.pi / 2
    local selected = keyRoot - 1 == pc
    local neighbour = (keyRoot - 1 + 7) % 12 == pc or (keyRoot - 1 + 5) % 12 == pc
    local col = selected and theme.accent or (neighbour and mix(theme.window, theme.accent, 0.35) or mix(theme.window, theme.text, 0.06))
    gfx.color(col)
    gfx.arc(cx, cy, R * 0.82, a0 + 0.02, a1 - 0.02, R * 0.32)
    local dx, dy = mx - cx, my - cy
    local d = math.sqrt(dx * dx + dy * dy)
    local ang = (math.atan(dy, dx) + math.pi / 2) % (math.pi * 2)
    local idx = floor(ang / (math.pi * 2) * 12 + 0.5) % 12
    if hitAll.hovered and d > R * 0.4 and d < R and idx == i then hoverIdx = i end
    gfx.color(selected and "#FFFFFF" or theme.text)
    gfx.text(noteName(pc), cx + math.cos(am) * R * 0.82 - 30, cy + math.sin(am) * R * 0.82 - 11, 18, "bold", "center", 60)
    gfx.color(selected and alpha("#FFFFFF", 0.85) or theme.text2)
    gfx.text(noteName((pc + 9) % 12) .. "m", cx + math.cos(am) * R * 0.52 - 30, cy + math.sin(am) * R * 0.52 - 8, 13, "medium", "center", 60)
  end
  -- centre: key signature
  local pos = 0
  for i = 0, 11 do if (i * 7) % 12 == keyRoot - 1 then pos = i end end
  local acc = pos <= 6 and pos or 12 - pos
  gfx.color(theme.text)
  gfx.text(noteName(keyRoot - 1), cx - 60, cy - 26, 26, "bold", "center", 120)
  gfx.color(theme.text2)
  gfx.text(acc == 0 and TR("no_accidentals") or (pos <= 6 and TR("sharps_n", acc) or TR("flats_n", acc)), cx - 80, cy + 6, 12, "medium", "center", 160)
  if hitAll.clicked and hoverIdx then
    keyRoot = (hoverIdx * 7) % 12 + 1
    markDirty()
    playChord(keyRoot, 1)
  end
  -- diatonic chords
  local lx = listW > 0 and x + cw or x
  local ly = listW > 0 and y + 20 or y + h - 120
  local lw = listW > 0 and listW - 20 or w
  if listW > 0 then
    K.heading(TR("key_chords", noteName(keyRoot - 1)), lx, ly, lw)
    ly = ly + 26
    for d = 1, 7 do
      local r, q = diatonic(keyRoot - 1, d)
      local hit = ui.hit("dc" .. d, lx, ly, lw, 44)
      gfx.rect(lx, ly, lw, 44, 10, hit.hovered and theme.hover or alpha(theme.text, 0.04))
      gfx.color(theme.accent)
      gfx.text(ROMAN[d], lx + 10, ly + 12, 15, "bold")
      gfx.color(theme.text)
      gfx.text(chordName(r, q), lx + 64, ly + 12, 16, "semibold")
      gfx.color(theme.text3)
      gfx.text(TR(QUAL[q][3]), lx + 140, ly + 14, 12)
      if hit.clicked then playChord(r, q) end
      if hit.doubleClicked or hit.rightClicked then root, qual, voicing, tab = r, q, 1, 1 end
      ly = ly + 50
    end
  end
end

local function drawProgressions(x, y, w, h)
  local p = 16
  local P = prog()
  local sideW = w >= 760 and 230 or 0
  -- list of saved progressions
  if sideW > 0 then
    gfx.rect(x, y, sideW, h, 0, theme.sidebar)
    local ly = y + 10
    listRect = {x, ly, sideW, h - 60}
    listScroll:setMax(#progs * 46 - (h - 60))
    gfx.clip(x, ly, sideW, h - 60)
    for i, pr in ipairs(progs) do
      local ry = ly + (i - 1) * 46 - listScroll.y
      local hit = ui.hit("pl" .. i, x + 8, ry, sideW - 16, 42)
      gfx.rect(x + 8, ry, sideW - 16, 42, 10, i == progIdx and alpha(theme.accent, 0.16) or (hit.hovered and theme.hover or alpha(theme.text, 0.04)))
      gfx.color(theme.text)
      gfx.text(K.ellipsize(pr.name, 13, "semibold", sideW - 40), x + 18, ry + 4, 13, "semibold")
      gfx.color(theme.text3)
      local names = {}
      for k, c in ipairs(pr.chords) do if k <= 6 then names[#names + 1] = chordName(c[1], c[2]) end end
      gfx.text(K.ellipsize(table.concat(names, " "), 11, "sans", sideW - 40), x + 18, ry + 22, 11)
      if hit.clicked and not listScroll:dragged() then progIdx = i; playing = nil; markDirty() end
    end
    gfx.unclip()
    if ui.button(TR("new_prog"), x + 8, y + h - 44, sideW - 16, 34, "default", "add") then
      pushHist()
      progs[#progs + 1] = {name = TR("prog_n", #progs + 1), key = keyRoot, chords = {}, bpm = 100, beats = 4}
      progIdx = #progs
      markDirty()
    end
    gfx.color(theme.separator); gfx.line(x + sideW, y, x + sideW, y + h, 1)
  end
  local ex = x + sideW + p
  local ew = w - sideW - p * 2
  local yy = y + 10
  -- header: name, play, tempo
  gfx.color(theme.text)
  local nh = ui.hit("pname", ex - 4, yy, min(ew - 260, gfx.textWidth(P.name, 18, "bold") + 16), 32)
  if nh.hovered then gfx.rect(ex - 4, yy, min(ew - 260, gfx.textWidth(P.name, 18, "bold") + 16), 32, 8, theme.hover) end
  gfx.text(K.ellipsize(P.name, 18, "bold", ew - 280), ex + 4, yy + 5, 18, "bold")
  if nh.clicked then ui.prompt(TR("rename"), TR("prog_name"), P.name, function(t) if t and K.trim(t) ~= "" then pushHist(); P.name = K.trim(t); markDirty() end end) end
  if ui.button(playing and TR("stop") or TR("play"), ex + ew - 110, yy, 110, 34, playing and "destructive" or "primary", playing and "stop" or "play_arrow") then
    if playing then playing = nil elseif #P.chords > 0 then playing = {i = 1, t = 0} ; playChord(P.chords[1][1], P.chords[1][2]) end
  end
  if ui.iconButton("redo", ex + ew - 152, yy + 1, 36, 32, theme.text2, false, "##pr") then redo() end
  if ui.iconButton("undo", ex + ew - 190, yy + 1, 36, 32, theme.text2, false, "##pu") then undo() end
  yy = yy + 46
  -- tempo and beats
  gfx.color(theme.text2)
  gfx.text(TR("bpm_n", P.bpm), ex, yy + 2, 13, "medium")
  local nb = ui.slider("bpm", P.bpm, 40, 200, ex + 90, yy + 2, min(220, ew * 0.35), 2)
  if nb ~= P.bpm then P.bpm = floor(nb); markDirty() end
  local bx = ex + 100 + min(220, ew * 0.35)
  if bx + 170 < ex + ew then
    local nbt = ui.segmented("beats", {"2", "4", "8"}, P.beats == 2 and 1 or (P.beats == 8 and 3 or 2), bx, yy - 4, 150, 30)
    local bv = ({2, 4, 8})[nbt]
    if bv ~= P.beats then P.beats = bv; markDirty() end
  end
  yy = yy + 40
  -- the chord slots
  local slotW = clamp(floor((ew + 8) / 4) - 8, 90, 150)
  local per = max(1, floor((ew + 8) / (slotW + 8)))
  for i, c in ipairs(P.chords) do
    local sx = ex + ((i - 1) % per) * (slotW + 8)
    local sy = yy + floor((i - 1) / per) * 78
    local active = playing and playing.i == i
    local hit = ui.hit("slot" .. i, sx, sy, slotW, 70)
    gfx.rect(sx, sy, slotW, 70, 12, active and theme.accent or (hit.hovered and theme.hover or alpha(theme.text, 0.06)))
    if active then gfx.rect(sx, sy + 64, slotW * min(1, playing.t), 6, 3, alpha("#FFFFFF", 0.7)) end
    gfx.color(active and "#FFFFFF" or theme.text)
    gfx.text(chordName(c[1], c[2]), sx, sy + 14, 22, "bold", "center", slotW)
    gfx.color(active and alpha("#FFFFFF", 0.8) or theme.text3)
    -- the roman numeral in this key, if diatonic
    local rn = ""
    for d = 1, 7 do local r, q = diatonic(P.key - 1, d); if r == c[1] and q == c[2] then rn = ROMAN[d] end end
    gfx.text(rn, sx, sy + 44, 12, "medium", "center", slotW)
    if hit.clicked then playChord(c[1], c[2]) end
    if hit.rightClicked then
      ui.contextMenu({{label = TR("remove"), id = 1, icon = "delete"}, {label = TR("show_chord"), id = 2, icon = "music_note"}}, function(id)
        if id == 1 then pushHist(); table.remove(P.chords, i); markDirty() elseif id == 2 then root, qual, voicing, tab = c[1], c[2], 1, 1 end
      end)
    end
  end
  local rows = math.ceil(max(1, #P.chords) / per)
  if #P.chords == 0 then gfx.color(theme.text3); gfx.text(TR("empty_prog"), ex, yy + 24, 14, "italic"); rows = 1 end
  yy = yy + rows * 78 + 8
  -- add chords: the key and its diatonic chords
  K.heading(TR("add_from_key"), ex, yy, ew)
  yy = yy + 22
  local keys = {}
  for i = 1, 12 do keys[i] = noteName(i - 1) end
  local nk = ui.dropdown("pkey", keys, P.key, ex, yy, 90, 32)
  if nk ~= P.key then pushHist(); P.key = nk; markDirty() end
  local cx = ex + 100
  for d = 1, 7 do
    local r, q = diatonic(P.key - 1, d)
    local label = ROMAN[d] .. "  " .. chordName(r, q)
    local cw = gfx.textWidth(label, 13, "semibold") + 22
    if cx + cw > ex + ew then cx = ex + 100; yy = yy + 38 end
    local hit = ui.hit("add" .. d, cx, yy, cw, 32)
    gfx.rect(cx, yy, cw, 32, 16, hit.hovered and theme.hover or alpha(theme.accent, 0.12))
    gfx.color(theme.accent)
    gfx.text(label, cx, yy + 7, 13, "semibold", "center", cw)
    if hit.clicked and #P.chords < 32 then pushHist(); P.chords[#P.chords + 1] = {r, q}; markDirty(); playChord(r, q) end
    cx = cx + cw + 6
  end
  yy = yy + 44
  K.heading(TR("presets"), ex, yy, ew)
  yy = yy + 22
  cx = ex
  for i, pr in ipairs(PRESETS) do
    local label = TR(pr[1])
    local cw = gfx.textWidth(label, 13, "medium") + 22
    if cx + cw > ex + ew then cx = ex; yy = yy + 38 end
    local hit = ui.hit("pre" .. i, cx, yy, cw, 32)
    gfx.rect(cx, yy, cw, 32, 16, hit.hovered and theme.hover or alpha(theme.text, 0.06))
    gfx.color(theme.text)
    gfx.text(label, cx, yy + 7, 13, "medium", "center", cw)
    if hit.clicked then
      pushHist()
      P.chords = {}
      for _, d in ipairs(pr[2]) do local r, q = diatonic(P.key - 1, d); P.chords[#P.chords + 1] = {r, q} end
      if pr[1] == "p_blues" then for k, d in ipairs(pr[2]) do local r = (P.key - 1 + MAJOR[d]) % 12 + 1; P.chords[k] = {r, 3} end end
      markDirty()
    end
    cx = cx + cw + 6
  end
end

-- ================================================================== app callbacks
function app.load(arg)
  loadAll()
end

function app.update(dt)
  frameDt = dt
  listScroll:update(dt)
  local now = sys.time()
  local i = 1
  while i <= #strumQ do
    local s = strumQ[i]
    if now >= s.at then
      audio.tone(floor(freq(s.m) * 100 + 0.5) / 100, s.dur, 0.32, "triangle")
      litNotes[s.m % 12] = now
      table.remove(strumQ, i)
    else i = i + 1 end
  end
  if playing then
    local P = prog()
    if not P or #P.chords == 0 then playing = nil
    else
      local chordSec = 60 / P.bpm * P.beats
      playing.t = playing.t + dt / chordSec
      if playing.t >= 1 then
        playing.t = playing.t - 1
        playing.i = playing.i % #P.chords + 1
        local c = P.chords[playing.i]
        playChord(c[1], c[2])
      end
    end
  end
  if dirty and now - changedAt > 1.2 then saveNow() end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  -- header
  gfx.rect(0, 0, w, 52, 0, theme.window)
  local tabs = {TR("t_chords"), TR("t_scales"), TR("t_circle"), TR("t_progs")}
  local tw = min(520, w - 260)
  if w < 640 then tw = w - 20 end
  local nt = ui.segmented("tabs", tabs, tab, 10, 10, tw, 32)
  if nt ~= tab then tab = nt; markDirty() end
  if w >= 640 then
    local names = {}
    for i, I in ipairs(INSTR) do names[i] = TR(I.key) end
    local ni = ui.dropdown("inst", names, inst, w - 230, 10, 150, 32)
    if ni ~= inst then inst = ni; voicing = 1; markDirty() end
    if ui.iconButton("tune", w - 74, 10, 32, 32, theme.text2, false, "##names") then
      ui.contextMenu({{label = TR("n_letters"), id = 1, icon = solfege and "radio_button_unchecked" or "radio_button_checked"},
                      {label = TR("n_solfege"), id = 2, icon = solfege and "radio_button_checked" or "radio_button_unchecked"}, "-",
                      {label = useFlats and TR("use_sharps") or TR("use_flats"), id = 3, icon = "swap_horiz"}}, function(id) app.onmenu(40 + id) end)
    end
    if ui.iconButton("volume_up", w - 40, 10, 32, 32, theme.text2, false, "##tune") then
      -- reference tones of the open strings
      local I = INSTR[inst]
      if I.tuning then playMidi(I.tuning, 0.45, 1.2) else playMidi({60, 64, 67, 72}, 0.3, 1) end
    end
  end
  gfx.color(theme.separator); gfx.line(0, 52, w, 52, 1)
  local y0 = 53
  local bh = h - y0
  if w < 640 then
    local names = {}
    for i, I in ipairs(INSTR) do names[i] = TR(I.key) end
    local ni = ui.segmented("inst2", names, inst, 10, y0 + 6, w - 20, 30)
    if ni ~= inst then inst = ni; voicing = 1; markDirty() end
    y0, bh = y0 + 42, bh - 42
  end
  gfx.clip(0, y0, w, bh)
  if tab == 1 then drawChords(0, y0, w, bh)
  elseif tab == 2 then drawScales(0, y0, w, bh)
  elseif tab == 3 then drawCircle(0, y0, w, bh)
  else drawProgressions(0, y0, w, bh) end
  gfx.unclip()
  K.drawToast(w, h)
  K.frameEnd()
end

function app.event(e)
  if K.press(e) then return end
  if tab == 4 and listScroll:event(e, listRect) then return end
  if e.type ~= "keydown" or K.editing then return end
  local k = e.key
  if e.ctrl then
    if k == "z" then if e.shift then redo() else undo() end elseif k == "y" then redo()
    elseif k >= "1" and k <= "4" and #k == 1 then tab = tonumber(k); markDirty() end
    return
  end
  if k == "tab" then tab = tab % 4 + 1; markDirty()
  elseif k >= "1" and k <= "4" and #k == 1 then tab = tonumber(k); markDirty()
  elseif k == "space" or k == "enter" then
    if tab == 4 then
      local P = prog()
      if playing then playing = nil elseif #P.chords > 0 then playing = {i = 1, t = 0}; playChord(P.chords[1][1], P.chords[1][2]) end
    elseif tab == 3 then playChord(keyRoot, 1)
    else playChord(root, qual) end
  elseif k == "left" or k == "right" then
    local d = k == "left" and -1 or 1
    if tab == 1 then root = (root - 1 + d) % 12 + 1; voicing = 1
    elseif tab == 2 then scaleRoot = (scaleRoot - 1 + d) % 12 + 1
    elseif tab == 3 then
      local pos = 0
      for i = 0, 11 do if (i * 7) % 12 == keyRoot - 1 then pos = i end end
      keyRoot = ((pos + d) % 12 * 7) % 12 + 1
    elseif tab == 4 then progIdx = clamp(progIdx + d, 1, #progs); playing = nil end
    markDirty()
  elseif k == "up" or k == "down" then
    local d = k == "up" and -1 or 1
    if tab == 1 then qual = (qual - 1 + d) % #QUAL + 1; voicing = 1
    elseif tab == 2 then scaleIdx = (scaleIdx - 1 + d) % #SCALES + 1 end
    markDirty()
  elseif k == "pagedown" or k == "n" then voicing = voicing + 1; local n = #findVoicings(inst, root, qual); if voicing > n then voicing = 1 end
  elseif k == "pageup" or k == "p" then voicing = voicing - 1; if voicing < 1 then voicing = max(1, #findVoicings(inst, root, qual)) end
  elseif k == "i" then inst = inst % #INSTR + 1; voicing = 1; markDirty()
  elseif k == "backspace" and tab == 4 then local P = prog(); if #P.chords > 0 then pushHist(); table.remove(P.chords); markDirty() end end
end

function app.menu()
  local items = {}
  for i, I in ipairs(INSTR) do items[#items + 1] = {label = TR(I.key), id = 20 + i} end
  return {
    {title = TR("m_view"), items = {
      {label = TR("t_chords"), id = 1, shortcut = "1"}, {label = TR("t_scales"), id = 2, shortcut = "2"},
      {label = TR("t_circle"), id = 3, shortcut = "3"}, {label = TR("t_progs"), id = 4, shortcut = "4"},
      "-", {label = TR("n_letters"), id = 41}, {label = TR("n_solfege"), id = 42}, {label = TR("toggle_flats"), id = 43},
    }},
    {title = TR("m_instrument"), items = items},
    {title = TR("m_prog"), items = {
      {label = TR("new_prog"), id = 30}, {label = TR("copy_prog"), id = 31}, {label = TR("export_prog"), id = 32},
      {label = TR("delete_prog"), id = 33}, "-", {label = TR("undo"), id = 34, shortcut = "Ctrl+Z"}, {label = TR("redo"), id = 35, shortcut = "Ctrl+Y"},
    }},
  }
end

local function progText(P)
  local names = {}
  for _, c in ipairs(P.chords) do names[#names + 1] = chordName(c[1], c[2]) end
  return P.name .. " (" .. TR("key_of", noteName(P.key - 1)) .. ", " .. P.bpm .. " BPM)\n| " .. table.concat(names, " | ") .. " |"
end

function app.onmenu(id)
  if id >= 1 and id <= 4 then tab = id; markDirty()
  elseif id > 20 and id <= 20 + #INSTR then inst = id - 20; voicing = 1; markDirty()
  elseif id == 30 then pushHist(); progs[#progs + 1] = {name = TR("prog_n", #progs + 1), key = keyRoot, chords = {}, bpm = 100, beats = 4}; progIdx = #progs; tab = 4; markDirty()
  elseif id == 31 then sys.clipboard(progText(prog())); K.toast(TR("copied"), "content_copy")
  elseif id == 32 then
    local P = prog()
    ui.saveFile(function(p)
      if not p then return end
      if not p:lower():match("%.txt$") then p = p .. ".txt" end
      if fs.write(p, progText(P) .. "\n") then K.toast(TR("exported"), "ios_share") else K.toast(TR("write_failed"), "error") end
    end, P.name:gsub("[/\\:%*%?\"<>|]", "-") .. ".txt", TR("export_prog"))
  elseif id == 33 then
    if #progs > 1 then
      ui.alert(TR("delete_prog"), TR("delete_prog_msg", prog().name), {TR("delete"), TR("cancel")}, function(b)
        if b == 1 then pushHist(); table.remove(progs, progIdx); progIdx = clamp(progIdx, 1, #progs); playing = nil; markDirty() end
      end)
    end
  elseif id == 34 then undo() elseif id == 35 then redo()
  elseif id == 41 then solfege = false; markDirty() elseif id == 42 then solfege = true; markDirty()
  elseif id == 43 then useFlats = not useFlats; markDirty() end
end

function app.suspend() playing = nil; if dirty then saveNow() end end
function app.autosave() if dirty then saveNow() end end
function app.unsaved() return dirty end
function app.close() saveNow(); store.save(); return true end

return app
