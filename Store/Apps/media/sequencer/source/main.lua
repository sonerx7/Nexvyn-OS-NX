-- Melody Studio for Nexvyn OS: 2-octave x 32-step piano roll, waveform instruments, tempo, transpose,
-- looping playback, saved songs and text-score export to Documents.
local app = {}

local floor, min, max, abs = math.floor, math.min, math.max, math.abs

-- ------------------------------------------------------------------ helpers
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local ccache = {}
local function rgba(c)
  if type(c) == "table" then return c end
  local t = ccache[c]
  if not t then
    t = {tonumber(c:sub(2, 3), 16) or 0, tonumber(c:sub(4, 5), 16) or 0, tonumber(c:sub(6, 7), 16) or 0,
         #c >= 9 and (tonumber(c:sub(8, 9), 16) or 255) or 255}
    ccache[c] = t
  end
  return t
end
local function alpha(c, a)
  local t = rgba(c)
  return {t[1], t[2], t[3], clamp(floor(t[4] * a + 0.5), 0, 255)}
end
local function mix(c1, c2, k)
  local a, b = rgba(c1), rgba(c2)
  return {floor(a[1] + (b[1] - a[1]) * k + 0.5), floor(a[2] + (b[2] - a[2]) * k + 0.5),
          floor(a[3] + (b[3] - a[3]) * k + 0.5), floor(a[4] + (b[4] - a[4]) * k + 0.5)}
end
local function approach(cur, target, speed, dt) return cur + (target - cur) * (1 - math.exp(-speed * dt)) end
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local editing, pressAt, fieldHit = false, nil, false
local function field(id, text, x, y, w, h, ph, flags)
  local nt, sub = ui.textfield(id, text, x, y, w, h, ph, flags)
  if pressAt then
    local mx, my = ui.mouse()
    if mx >= x and mx <= x + w and my >= y and my <= y + h then fieldHit = true end
  end
  return nt, sub
end

-- ------------------------------------------------------------------ music
local ROWS, STEPS = 24, 32
local BASE = 60                 -- C4 is the bottom row
local NAMES = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
local BLACK = {[1] = true, [3] = true, [6] = true, [8] = true, [10] = true}
local WAVES = {"sine", "triangle", "square", "saw"}
local WAVEKEY = {"wave_sine", "wave_triangle", "wave_square", "wave_saw"}
local WAVEGAIN = {0.75, 0.75, 0.42, 0.45}
local DURS = {0.06, 0.09, 0.12, 0.18, 0.25, 0.35, 0.5, 0.7, 1.0, 1.4, 2.0, 2.8}
local PITCHCOL = {"#FF6B6B", "#FF8E53", "#FFB13B", "#FFD43B", "#A9E34B", "#51CF66",
                  "#20C997", "#22B8CF", "#4DABF7", "#748FFC", "#9775FA", "#DA77F2"}

local function noteName(midi)
  return NAMES[midi % 12 + 1] .. tostring(floor(midi / 12) - 1)
end
local function freqOf(midi) return 440 * 2 ^ ((midi - 69) / 12) end
local function quantDur(secs)
  local best, bd = DURS[1], 1e9
  for _, d in ipairs(DURS) do
    local diff = abs(d - secs)
    if diff < bd then best, bd = d, diff end
  end
  return best
end

-- ------------------------------------------------------------------ song state
local song = {name = "", bpm = 112, wave = 2, transpose = 0, volume = 0.8, notes = {}}
local songs = {}
local songSel = 0               -- index into songs (0 = unsaved)

local function demoNotes()
  local seq = {{4, 2}, {4, 2}, {5, 2}, {7, 2}, {7, 2}, {5, 2}, {4, 2}, {2, 2}, {0, 2}, {0, 2}, {2, 2}, {4, 2},
               {4, 3}, {2, 1}, {2, 4}}
  local out, s = {}, 0
  for _, n in ipairs(seq) do
    out[#out + 1] = {n[1] + 12, s, n[2]}
    if n[2] >= 2 then out[#out + 1] = {n[1], s, 1} end
    s = s + n[2]
  end
  return out
end

local function sanitizeNotes(list)
  local out = {}
  if type(list) == "table" then
    for _, n in ipairs(list) do
      if type(n) == "table" then
        local p, s, l = math.tointeger(n[1]), math.tointeger(n[2]), math.tointeger(n[3])
        if p and s and l and p >= 0 and p < ROWS and s >= 0 and s < STEPS then
          out[#out + 1] = {p, s, clamp(l, 1, STEPS - s)}
        end
      end
    end
  end
  return out
end

local function saveCurrent()
  store.set("current", song)
  store.set("songSel", songSel)
end

local function loadSong(s)
  song = {name = tostring(s.name or ""), bpm = clamp(math.tointeger(s.bpm) or 112, 60, 200),
          wave = clamp(math.tointeger(s.wave) or 2, 1, #WAVES), transpose = clamp(math.tointeger(s.transpose) or 0, -12, 12),
          volume = clamp(tonumber(s.volume) or 0.8, 0, 1), notes = sanitizeNotes(s.notes)}
end

local function copySong()
  local c = {name = song.name, bpm = song.bpm, wave = song.wave, transpose = song.transpose, volume = song.volume, notes = {}}
  for i, n in ipairs(song.notes) do c.notes[i] = {n[1], n[2], n[3]} end
  return c
end

-- ------------------------------------------------------------------ playback
local playing = false
local step = -1
local stepT0 = 0
local nextT = 0
local glow = {}                 -- [note table] = 0..1
local previewKey = nil

local function stepDur() return 60 / song.bpm / 4 end

local function playNote(p, l, vol)
  local midi = BASE + p + song.transpose
  local secs = quantDur(l * stepDur() * 0.92)
  audio.tone(freqOf(midi), secs, clamp((vol or 1) * song.volume * WAVEGAIN[song.wave], 0, 1), WAVES[song.wave])
end

local function preview(p)
  playNote(p, 1.6, 0.9)
  previewKey = p
end

local function togglePlay()
  playing = not playing
  if playing then
    step = -1
    nextT = sys.time() + 0.04
  end
end

-- ------------------------------------------------------------------ export
local function exportScore()
  local name = trim(song.name) ~= "" and trim(song.name) or TR("untitled")
  local lines = {}
  lines[#lines + 1] = TR("app_title") .. " - " .. name
  lines[#lines + 1] = TR("score_meta", song.bpm, TR(WAVEKEY[song.wave]), (song.transpose > 0 and "+" or "") .. song.transpose)
  lines[#lines + 1] = TR("score_steps")
  lines[#lines + 1] = ""
  local sorted = {}
  for _, n in ipairs(song.notes) do sorted[#sorted + 1] = n end
  table.sort(sorted, function(a, b) if a[2] ~= b[2] then return a[2] < b[2] end return a[1] > b[1] end)
  lines[#lines + 1] = TR("score_header")
  for _, n in ipairs(sorted) do
    lines[#lines + 1] = string.format("%4d   %-4s  %2d", n[2] + 1, noteName(BASE + n[1] + song.transpose), n[3])
  end
  lines[#lines + 1] = ""
  lines[#lines + 1] = TR("score_roll")
  local ruler = "      "
  for s = 1, STEPS do ruler = ruler .. ((s - 1) % 4 == 0 and tostring((s - 1) // 4 + 1) or " ") end
  lines[#lines + 1] = ruler
  for p = ROWS - 1, 0, -1 do
    local row = {}
    for s = 1, STEPS do row[s] = ((s - 1) % 4 == 0) and ":" or "." end
    for _, n in ipairs(song.notes) do
      if n[1] == p then
        row[n[2] + 1] = "#"
        for k = n[2] + 2, min(STEPS, n[2] + n[3]) do row[k] = "=" end
      end
    end
    lines[#lines + 1] = string.format("%-4s |", noteName(BASE + p + song.transpose)) .. table.concat(row) .. "|"
  end
  local safe = "song"
  local ok = pcall(function()
    local out = {}
    for _, cp in utf8.codes(name) do
      local ch = utf8.char(cp)
      if cp >= 128 or ch:match("^[%w%-_ ]$") then out[#out + 1] = ch else out[#out + 1] = "_" end
    end
    safe = table.concat(out)
  end)
  if not ok or safe == "" then safe = "song" end
  local path = fs.dir("documents") .. "/" .. safe .. ".txt"
  if fs.write(path, table.concat(lines, "\n") .. "\n") then
    sys.notify(TR("export_done"), path)
    audio.play("notify", 0.5)
  else
    ui.alert(TR("export_failed"), path, {TR("ok")})
  end
end

local function saveSong()
  local name = trim(song.name)
  if name == "" then name = TR("song_n", #songs + 1); song.name = name end
  local idx = nil
  for i, s in ipairs(songs) do if s.name == name then idx = i end end
  if idx then songs[idx] = copySong() else songs[#songs + 1] = copySong(); idx = #songs end
  songSel = idx
  store.set("songs", songs)
  saveCurrent()
  audio.play("pop", 0.5)
  sys.notify(TR("saved_title"), TR("saved_msg", name))
end

local function newSong()
  song = {name = "", bpm = song.bpm, wave = song.wave, transpose = 0, volume = song.volume, notes = {}}
  songSel = 0
  saveCurrent()
end

-- ------------------------------------------------------------------ app
function app.load()
  local ss = store.get("songs", {})
  songs = {}
  if type(ss) == "table" then for _, s in ipairs(ss) do if type(s) == "table" then songs[#songs + 1] = s end end end
  local cur = store.get("current", nil)
  if type(cur) == "table" then loadSong(cur)
  else
    song.name = TR("demo_name")
    song.notes = demoNotes()
  end
  songSel = clamp(math.tointeger(store.get("songSel", 0)) or 0, 0, #songs)
  saveCurrent()
end

function app.update(dt)
  if playing then
    local now = sys.time()
    if now - nextT > 0.25 then nextT = now end
    local guard = 0
    while now >= nextT and guard < 8 do
      guard = guard + 1
      step = (step + 1) % STEPS
      stepT0 = nextT
      for _, n in ipairs(song.notes) do
        if n[2] == step then
          playNote(n[1], n[3])
          glow[n] = 1
        end
      end
      nextT = nextT + stepDur()
    end
  end
  for n, g in pairs(glow) do
    g = g - dt * 2.5
    if g <= 0 then glow[n] = nil else glow[n] = g end
  end
end

local drag = nil   -- {mode = "new"/"move", note, dc, moved}
local hoverCell = nil

local function noteAt(p, s)
  for i = #song.notes, 1, -1 do
    local n = song.notes[i]
    if n[1] == p and s >= n[2] and s < n[2] + n[3] then return n, i end
  end
  return nil
end

local function removeNote(n)
  for i, m in ipairs(song.notes) do
    if m == n then table.remove(song.notes, i); return end
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  -- ---------------------------------------------------------------- toolbar
  gfx.rect(0, 0, w, 56, 0, theme.window)
  ui.separator(0, 56, w)
  if ui.button(playing and TR("stop") or TR("play"), 16, 11, 100, 34, playing and "destructive" or "primary", playing and "stop" or "play_arrow") then
    togglePlay()
  end
  gfx.color(theme.text3)
  gfx.text("BPM", 132, 21, 11, "semibold")
  if ui.iconButton("remove", 158, 13, 28, 30, nil, false, "bpm-") then song.bpm = max(60, song.bpm - 1); saveCurrent() end
  gfx.color(theme.text)
  gfx.text(tostring(song.bpm), 186, 17, 17, "bold", "center", 40)
  if ui.iconButton("add", 226, 13, 28, 30, nil, false, "bpm+") then song.bpm = min(200, song.bpm + 1); saveCurrent() end
  local nb = ui.slider("bpm", song.bpm, 60, 200, 260, 16, 96, 1)
  if floor(nb + 0.5) ~= song.bpm then song.bpm = floor(nb + 0.5); saveCurrent() end
  local items = {}
  for i, k in ipairs(WAVEKEY) do items[i] = TR(k) end
  local nw = ui.segmented("wave", items, song.wave, 372, 14, 260, 28)
  if nw ~= song.wave then song.wave = nw; saveCurrent(); preview(12) end
  gfx.color(theme.text3)
  gfx.text(TR("transpose"), 648, 21, 11, "semibold")
  local tw = gfx.textWidth(TR("transpose"), 11, "semibold")
  local tx = 654 + tw
  if ui.iconButton("remove", tx, 13, 28, 30, nil, false, "tr-") then song.transpose = max(-12, song.transpose - 1); saveCurrent() end
  gfx.color(song.transpose ~= 0 and theme.accent or theme.text)
  gfx.text((song.transpose > 0 and "+" or "") .. song.transpose, tx + 28, 17, 17, "bold", "center", 40)
  if ui.iconButton("add", tx + 68, 13, 28, 30, nil, false, "tr+") then song.transpose = min(12, song.transpose + 1); saveCurrent() end
  gfx.icon(song.volume > 0 and "volume_up" or "volume_off", tx + 112, 28, 18, theme.text2)
  local nv = ui.slider("vol", song.volume, 0, 1, tx + 124, 16, w - tx - 140)
  if nv ~= song.volume then song.volume = nv; saveCurrent() end

  -- ---------------------------------------------------------------- piano roll
  local kx, kw = 16, 58
  local gx = kx + kw + 4
  local gy = 68
  local bottomBar = 56
  local gw = w - gx - 16
  local gh = h - gy - bottomBar - 10
  local cw = gw / STEPS
  local rh = gh / ROWS
  local function rowY(p) return gy + (ROWS - 1 - p) * rh end

  -- keys
  for p = 0, ROWS - 1 do
    local midi = BASE + p + song.transpose
    local pc = (BASE + p) % 12
    local y = rowY(p)
    local black = BLACK[pc]
    local kh = ui.hit("key" .. p, kx, y, kw, rh)
    local lit = (previewKey == p and kh.held)
    gfx.rect(kx, y + 0.5, kw, rh - 1, 3, lit and theme.accent or (black and (theme.dark and "#2C2C2E" or "#3A3A3C") or (theme.dark and "#D1D1D6" or "#FFFFFF")))
    if not black then
      gfx.color(theme.dark and alpha("#000000", 0.3) or theme.separator)
      gfx.rectLine(kx, y + 0.5, kw, rh - 1, 3, 1)
    end
    if pc == 0 or kh.hovered then
      gfx.color(black and "#FFFFFF" or "#3A3A3C")
      gfx.text(noteName(midi), kx + 4, y + rh / 2 - 6, 9.5, "semibold")
    end
    if kh.pressed then preview(p) end
  end

  -- grid background
  for p = 0, ROWS - 1 do
    local y = rowY(p)
    local pc = (BASE + p) % 12
    gfx.rect(gx, y, gw, rh, 0, BLACK[pc] and alpha(theme.text, 0.06) or alpha(theme.text, 0.02))
    if pc == 0 then gfx.rect(gx, y + rh - 1, gw, 1, 0, alpha(theme.text, 0.18)) end
  end
  for s = 0, STEPS do
    local x = gx + s * cw
    local a = (s % 16 == 0) and 0.30 or ((s % 4 == 0) and 0.16 or 0.06)
    gfx.rect(x, gy, 1, gh, 0, alpha(theme.text, a))
  end

  -- interaction
  local mx, my = ui.mouse()
  local hit = ui.hit("roll", gx, gy, gw, gh)
  local function cellAt(px, py)
    local s = clamp(floor((px - gx) / cw), 0, STEPS - 1)
    local p = clamp(ROWS - 1 - floor((py - gy) / rh), 0, ROWS - 1)
    return p, s
  end
  hoverCell = nil
  if hit.hovered then
    local p, s = cellAt(mx, my)
    hoverCell = {p, s}
  end
  if hit.pressed then
    local p, s = cellAt(mx, my)
    local n = noteAt(p, s)
    if n then
      drag = {mode = "move", note = n, dc = s - n[2], moved = false, lastP = p}
    else
      n = {p, s, 1}
      song.notes[#song.notes + 1] = n
      drag = {mode = "new", note = n, moved = true}
      preview(p)
    end
  end
  if drag and hit.held then
    local p, s = cellAt(mx, my)
    local n = drag.note
    if drag.mode == "new" then
      n[3] = clamp(s - n[2] + 1, 1, STEPS - n[2])
    else
      local ns = clamp(s - drag.dc, 0, STEPS - n[3])
      if ns ~= n[2] or p ~= n[1] then
        drag.moved = true
        if p ~= n[1] then preview(p) end
        n[1], n[2] = p, ns
      end
    end
  elseif drag and not hit.held then
    if drag.mode == "move" and not drag.moved then
      removeNote(drag.note)
      audio.tone(220, 0.04, 0.15, "triangle")
    end
    drag = nil
    saveCurrent()
  end
  if hit.rightClicked then
    local p, s = cellAt(mx, my)
    local n = noteAt(p, s)
    if n then removeNote(n); saveCurrent(); audio.tone(220, 0.04, 0.15, "triangle") end
  end

  -- hover cell
  if hoverCell and not drag then
    gfx.rect(gx + hoverCell[2] * cw + 1, rowY(hoverCell[1]) + 1, cw - 2, rh - 2, 3, alpha(theme.accent, 0.15))
  end

  -- notes
  gfx.clip(gx, gy, gw, gh)
  for _, n in ipairs(song.notes) do
    local x = gx + n[2] * cw + 1
    local y = rowY(n[1]) + 1
    local nw2 = n[3] * cw - 2
    local col = PITCHCOL[(BASE + n[1] + song.transpose) % 12 + 1]
    local g = glow[n] or 0
    if g > 0 then gfx.rect(x - 2, y - 2, nw2 + 4, rh + 2, 5, alpha(col, 0.35 * g)) end
    gfx.rect(x, y, nw2, rh - 2, 4, (drag and drag.note == n) and mix(col, "#FFFFFF", 0.3) or col)
    gfx.rect(x + 2, y + 2, max(2, nw2 - 4), (rh - 6) / 2, 3, alpha("#FFFFFF", 0.22 + 0.3 * g))
    gfx.color(alpha("#000000", 0.25))
    gfx.rectLine(x, y, nw2, rh - 2, 4, 1)
  end
  gfx.unclip()

  -- playhead
  if playing and step >= 0 then
    local frac = clamp((sys.time() - stepT0) / stepDur(), 0, 1)
    local x = gx + (step + frac) * cw
    gfx.rect(gx + step * cw, gy, cw, gh, 0, alpha(theme.accent, 0.08))
    gfx.rect(x - 1, gy, 2, gh, 1, theme.accent)
    gfx.poly({x - 6, gy - 8, x + 6, gy - 8, x, gy}, theme.accent)
  end
  if #song.notes == 0 then
    gfx.color(theme.text3)
    gfx.text(TR("empty_hint"), gx, gy + gh / 2 - 8, 14, "medium", "center", gw)
  end

  -- ---------------------------------------------------------------- bottom bar
  local by = h - bottomBar + 10
  ui.separator(0, by - 8, w)
  local names = {TR("unsaved")}
  for i, s in ipairs(songs) do names[i + 1] = s.name end
  local ns = ui.dropdown("songsel", names, songSel + 1, 16, by + 2, 190, 30)
  if ns - 1 ~= songSel then
    if ns > 1 and songs[ns - 1] then loadSong(songs[ns - 1]); songSel = ns - 1; saveCurrent(); audio.play("click", 0.4)
    else songSel = 0; saveCurrent() end
  end
  local nn, sub = field("sname", song.name, 214, by + 2, 180, 30, TR("name_hint"))
  if nn ~= song.name then song.name = nn; saveCurrent() end
  if sub then saveSong(); editing = false end
  local bx = 402
  if ui.button(TR("save"), bx, by + 2, 90, 30, "default", "save") then saveSong() end
  if ui.button(TR("new"), bx + 96, by + 2, 80, 30, "default", "add") then newSong() end
  if ui.button(TR("delete"), bx + 182, by + 2, 90, 30, "destructive", "delete", songSel > 0) then
    local idx = songSel
    ui.alert(TR("delete_title"), TR("delete_msg", songs[idx] and songs[idx].name or ""), {TR("delete"), TR("cancel")}, function(k)
      if k == 1 and songs[idx] then
        table.remove(songs, idx)
        store.set("songs", songs)
        songSel = 0
        saveCurrent()
        audio.play("trash", 0.5)
      end
    end)
  end
  -- a narrow window (large interface scale) keeps only the icons of the last two buttons, so they do not overlap
  local exW = w - 112 >= bx + 278 + 150 + 6 and 150 or 40
  local clW = w - 16 - 96 >= bx + 278 + exW + 6 and 96 or 40
  if ui.button((exW > 40 and TR("export") or "") .. "##export", bx + 278, by + 2, exW, 30, "default", "ios_share") then exportScore() end
  if ui.button((clW > 40 and TR("clear") or "") .. "##clear", w - 16 - clW, by + 2, clW, 30, "default", "clear_all", #song.notes > 0) then
    ui.alert(TR("clear_title"), TR("clear_msg"), {TR("clear"), TR("cancel")}, function(k)
      if k == 1 then song.notes = {}; saveCurrent(); audio.play("trash", 0.4) end
    end)
  end

  if pressAt then editing = fieldHit; pressAt = nil; fieldHit = false end
end

function app.event(e)
  if e.type == "mousedown" then pressAt = {e.x, e.y} end
  if e.type ~= "keydown" then return end
  if e.key == "escape" then
    if editing then editing = false; return end
    if playing then togglePlay() end
    return
  end
  if editing then return end
  if e.key == "space" then togglePlay()
  elseif e.key == "up" then song.transpose = min(12, song.transpose + 1); saveCurrent()
  elseif e.key == "down" then song.transpose = max(-12, song.transpose - 1); saveCurrent()
  elseif e.key == "right" then song.bpm = min(200, song.bpm + 5); saveCurrent()
  elseif e.key == "left" then song.bpm = max(60, song.bpm - 5); saveCurrent()
  end
end

function app.menu()
  return {
    {title = TR("menu_song"), items = {
      {label = playing and TR("stop") or TR("play"), id = 1, shortcut = "Space"},
      "-",
      {label = TR("new"), id = 2},
      {label = TR("save"), id = 3},
      {label = TR("export"), id = 4},
      "-",
      {label = TR("load_demo"), id = 5},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then togglePlay()
  elseif id == 2 then newSong()
  elseif id == 3 then saveSong()
  elseif id == 4 then exportScore()
  elseif id == 5 then
    song.notes = demoNotes(); song.name = TR("demo_name"); songSel = 0; saveCurrent()
  end
end

function app.close()
  playing = false
  saveCurrent()
  return true
end

return app
