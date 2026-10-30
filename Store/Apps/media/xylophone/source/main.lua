-- Xylophone: colourful bars to tap, play with the keyboard, record and replay melodies, and learn songs in
-- "follow" mode where the next bar lights up. Sounds are synthesised with audio.tone (no sound files).
local app = {}

local NAMES = {"C", "D", "E", "F", "G", "A", "B"}
local SEMI = {0, 2, 4, 5, 7, 9, 11}
local COLORS = {"#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#00C7BE", "#32ADE6", "#007AFF", "#5856D6",
  "#AF52DE", "#FF2D55", "#FF6B3D", "#FFB800", "#7ED957", "#2BC0E4", "#6C5CE7"}
local KEYS8 = {"1", "2", "3", "4", "5", "6", "7", "8"}
local KEYS_HI = {"q", "w", "e", "r", "t", "y", "u"}

-- songs: {bar index (1 = C5 … 15 = C7), beats}
local SONGS = {
  {key = "song_twinkle", bpm = 110, notes = {{1,1},{1,1},{5,1},{5,1},{6,1},{6,1},{5,2},{4,1},{4,1},{3,1},{3,1},{2,1},{2,1},{1,2},
    {5,1},{5,1},{4,1},{4,1},{3,1},{3,1},{2,2},{5,1},{5,1},{4,1},{4,1},{3,1},{3,1},{2,2},
    {1,1},{1,1},{5,1},{5,1},{6,1},{6,1},{5,2},{4,1},{4,1},{3,1},{3,1},{2,1},{2,1},{1,2}}},
  {key = "song_ode", bpm = 120, notes = {{3,1},{3,1},{4,1},{5,1},{5,1},{4,1},{3,1},{2,1},{1,1},{1,1},{2,1},{3,1},{3,1.5},{2,0.5},{2,2},
    {3,1},{3,1},{4,1},{5,1},{5,1},{4,1},{3,1},{2,1},{1,1},{1,1},{2,1},{3,1},{2,1.5},{1,0.5},{1,2}}},
  {key = "song_farm", bpm = 126, notes = {{8,1},{8,1},{8,1},{5,1},{6,1},{6,1},{5,2},{10,1},{10,1},{9,1},{9,1},{8,3},{5,1},
    {8,1},{8,1},{8,1},{5,1},{6,1},{6,1},{5,2},{10,1},{10,1},{9,1},{9,1},{8,3}}},
  {key = "song_birthday", bpm = 100, notes = {{5,0.75},{5,0.25},{6,1},{5,1},{8,1},{7,2},{5,0.75},{5,0.25},{6,1},{5,1},{9,1},{8,2},
    {5,0.75},{5,0.25},{12,1},{10,1},{8,1},{7,1},{6,2},{11,0.75},{11,0.25},{10,1},{8,1},{9,1},{8,2}}},
  {key = "song_jacques", bpm = 120, notes = {{1,1},{2,1},{3,1},{1,1},{1,1},{2,1},{3,1},{1,1},{3,1},{4,1},{5,2},{3,1},{4,1},{5,2},
    {5,0.5},{6,0.5},{5,0.5},{4,0.5},{3,1},{1,1},{5,0.5},{6,0.5},{5,0.5},{4,0.5},{3,1},{1,1},{1,1},{-2,1},{1,2},{1,1},{-2,1},{1,2}}},
}

local bars = 15
local tempo = 1.0
local recs = {}                 -- saved recordings {name, events = {{t, n}, ...}}
local hitAnim = {}              -- [bar] = 0..1 bounce
local ripples = {}
local recording = nil           -- {start, events}
local player = nil              -- {events, i, t, follow = bool, name}
local follow = nil              -- {events, i, right, wrong, name}
local clock = 0
local toast, toastT = "", 0
local undoRec = nil             -- {index, rec}
local barRects = {}             -- last drawn rectangles for hit tests

-- ------------------------------------------------------------------ sound
local function freqOf(n)
  local i = n - 1
  local oct = 5 + i // 7
  local semi = SEMI[i % 7 + 1] + (oct - 4) * 12      -- semitones from C4
  return 261.6256 * 2 ^ (semi / 12)
end

local function noteName(n)
  if n < 1 then n = n + 7 end
  return NAMES[(n - 1) % 7 + 1] .. tostring(5 + (n - 1) // 7)
end

-- map a song note to the visible bars (8-bar mode folds the upper octave down; negative = lower octave up)
local function fold(n)
  if n < 1 then n = n + 7 end
  if bars == 8 and n > 8 then n = n - 7 end
  return math.max(1, math.min(bars, n))
end

local function strike(n, quiet)
  if n < 1 or n > bars then return end
  local f = math.floor(freqOf(n) * 10 + 0.5) / 10
  audio.tone(f, 0.55, 0.55, "triangle")
  audio.tone(math.floor(f * 40 + 0.5) / 10, 0.12, 0.12, "sine")   -- bright overtone of a wooden bar
  hitAnim[n] = 1
  local r = barRects[n]
  if r then ripples[#ripples + 1] = {x = r.x + r.w / 2, y = r.y + r.h / 2, t = 0, c = COLORS[n]} end
  if not quiet and recording then
    recording.events[#recording.events + 1] = {clock - recording.start, n}
  end
end

local function showToast(s) toast, toastT = s, 2.2 end

-- ------------------------------------------------------------------ songs, recordings
local songCache = {}
local function songEvents(s)
  if songCache[s] then return songCache[s][1], songCache[s][2] end
  local ev, t = {}, 0
  local beat = 60 / s.bpm
  for _, nb in ipairs(s.notes) do
    ev[#ev + 1] = {t, nb[1]}
    t = t + nb[2] * beat
  end
  songCache[s] = {ev, t}
  return ev, t
end

local function stopAll()
  player, follow = nil, nil
end

local function playEvents(events, name)
  if not events or #events == 0 then return end
  recording = nil
  follow = nil
  player = {events = events, i = 1, t = -0.3, name = name}
end

local function startFollow(events, name)
  if not events or #events == 0 then return end
  recording, player = nil, nil
  follow = {events = events, i = 1, right = 0, wrong = 0, name = name}
  showToast(TR("follow_hint"))
end

local function saveRecs() store.set("recordings", recs) end

local function toggleRecord()
  if recording then
    local ev = recording.events
    recording = nil
    if #ev == 0 then showToast(TR("rec_empty")) return end
    local name = TR("rec_name", #recs + 1)
    recs[#recs + 1] = {name = name, events = ev}
    saveRecs()
    showToast(TR("rec_saved", name))
    audio.play("pop")
  else
    stopAll()
    recording = {start = clock, events = {}}
    audio.tone(880, 0.08, 0.3, "sine")
  end
end

local function recDuration(r)
  local ev = r.events or {}
  return #ev > 0 and (ev[#ev][1] or 0) or 0
end

-- ------------------------------------------------------------------ callbacks
function app.load()
  bars = store.get("bars", 15) == 8 and 8 or 15
  tempo = math.max(0.5, math.min(2, tonumber(store.get("tempo", 1)) or 1))
  local r = store.get("recordings", {})
  recs = {}
  if type(r) == "table" then
    for _, x in ipairs(r) do
      if type(x) == "table" and type(x.events) == "table" then recs[#recs + 1] = {name = tostring(x.name or "?"), events = x.events} end
    end
  end
end

function app.update(dt)
  clock = clock + dt
  if toastT > 0 then toastT = toastT - dt end
  for n, v in pairs(hitAnim) do
    v = v - dt * 3
    hitAnim[n] = v > 0 and v or nil
  end
  for i = #ripples, 1, -1 do
    ripples[i].t = ripples[i].t + dt
    if ripples[i].t > 0.6 then table.remove(ripples, i) end
  end
  if player then
    player.t = player.t + dt * tempo
    local ev = player.events
    while player.i <= #ev and (ev[player.i][1] or 0) <= player.t do
      strike(fold(ev[player.i][2] or 1), true)
      player.i = player.i + 1
    end
    if player.i > #ev and player.t > (ev[#ev][1] or 0) + 0.6 then player = nil end
  end
end

local function hitBar(n)
  if follow then
    local want = fold(follow.events[follow.i][2] or 1)
    strike(n)
    if n == want then
      follow.right = follow.right + 1
      follow.i = follow.i + 1
      if follow.i > #follow.events then
        local total = follow.right + follow.wrong
        local acc = total > 0 and math.floor(follow.right * 100 / total + 0.5) or 0
        showToast(TR("follow_done", acc))
        audio.play("notify")
        follow = nil
      end
    else
      follow.wrong = follow.wrong + 1
      sys.vibrate(0.25, 40)
    end
  else
    strike(n)
  end
end

-- ------------------------------------------------------------------ drawing
local function drawXylophone(x, y, w, h)
  local n = bars
  local gap = n == 15 and 6 or 10
  local bw = (w - gap * (n - 1)) / n
  -- the frame rails
  gfx.color(theme.dark and "#5A3E2B" or "#8B5E3C")
  gfx.rect(x - 8, y + h * 0.18, w + 16, 10, 5)
  gfx.rect(x - 8, y + h * 0.78, w + 16, 10, 5)
  local want = follow and follow.events[follow.i] and fold(follow.events[follow.i][2] or 1) or nil
  for i = 1, n do
    local bh = h * (1 - (i - 1) / (n - 1) * 0.42)
    local bx = x + (i - 1) * (bw + gap)
    local by = y + (h - bh) / 2
    local a = hitAnim[i] or 0
    local bounce = math.sin(a * math.pi) * 6
    barRects[i] = {x = bx, y = by, w = bw, h = bh}
    local hit = ui.hit("bar" .. i, bx, by, bw, bh)
    if hit.pressed then hitBar(i) end
    gfx.shadow(bx, by + bounce, bw, bh, 10, 8, 3)
    gfx.gradient(bx, by + bounce, bw, bh, COLORS[i], COLORS[i] .. "B0", false, 10)
    if a > 0 then gfx.alpha(a * 0.6); gfx.rect(bx, by + bounce, bw, bh, 10, "#FFFFFF"); gfx.unalpha() end
    if want == i then
      local p = 0.5 + 0.5 * math.sin(clock * 8)
      gfx.color(theme.text)
      gfx.rectLine(bx - 3, by - 3 + bounce, bw + 6, bh + 6, 12, 2 + p * 2)
      gfx.icon("arrow_downward", bx + bw / 2, by - 16 - p * 4, 20, theme.text)
    end
    -- screws
    gfx.color("#00000040")
    gfx.circle(bx + bw / 2, by + bh * 0.12 + bounce, math.min(5, bw * 0.12))
    gfx.circle(bx + bw / 2, by + bh * 0.88 + bounce, math.min(5, bw * 0.12))
    gfx.color("#FFFFFF")
    gfx.text(noteName(i), bx, by + bh / 2 - 10 + bounce, bw > 34 and 15 or 12, "bold", "center", bw)
    gfx.color("#FFFFFFAA")
    local key = i <= 8 and KEYS8[i] or KEYS_HI[i - 8]
    if key then gfx.text(key:upper(), bx, by + bh / 2 + 10 + bounce, 11, "semibold", "center", bw) end
  end
  for _, r in ipairs(ripples) do
    gfx.alpha(1 - r.t / 0.6)
    gfx.color(r.c)
    gfx.circleLine(r.x, r.y, 10 + r.t * 90, 3)
    gfx.unalpha()
  end
end

local function drawList(x, y, w, h)
  ui.group(x, y, w, h)
  local rows = {}
  for i, s in ipairs(SONGS) do rows[#rows + 1] = {kind = "song", i = i} end
  for i = #recs, 1, -1 do rows[#rows + 1] = {kind = "rec", i = i} end
  local rh = 44
  local action = nil
  ui.beginScroll("list", x, y, w, h, #rows * rh + (#recs == 0 and 50 or 8))
  for k, r in ipairs(rows) do
    local ry = 4 + (k - 1) * rh
    local name, sub, icon, events
    if r.kind == "song" then
      local s = SONGS[r.i]
      local ev, len = songEvents(s)
      name, sub, icon, events = TR(s.key), TR("song_info", #s.notes, string.format("%.0f", len)), "music_note", ev
    else
      local rc = recs[r.i]
      name, sub, icon, events = rc.name, TR("rec_info", #rc.events, string.format("%.1f", recDuration(rc))), "mic", rc.events
    end
    local active = (player and player.name == name) or (follow and follow.name == name)
    gfx.icon(icon, 22, ry + rh / 2, 20, r.kind == "song" and theme.accent or theme.red)
    gfx.color(active and theme.accent or theme.text)
    gfx.text(name, 42, ry + 6, 14, "semibold")
    gfx.color(theme.text3)
    gfx.text(sub, 42, ry + 24, 11)
    local bx = w - 12
    if r.kind == "rec" then
      bx = bx - 34
      if ui.iconButton("delete", bx, ry + 6, 32, 32, theme.red, false, "del" .. r.i) then action = {"del", r.i} end
      bx = bx - 36
      if ui.iconButton("edit", bx, ry + 6, 32, 32, nil, false, "ren" .. r.i) then action = {"ren", r.i} end
    end
    bx = bx - 36
    if ui.iconButton("school", bx, ry + 6, 32, 32, nil, follow ~= nil and follow.name == name, "fol" .. k) then action = {"follow", events, name} end
    bx = bx - 36
    if ui.iconButton(player and player.name == name and "stop" or "play_arrow", bx, ry + 6, 32, 32, theme.green, false, "ply" .. k) then
      action = player and player.name == name and {"stop"} or {"play", events, name}
    end
    if k < #rows then ui.separator(42, ry + rh, w - 12) end
  end
  if #recs == 0 then
    local ey = 4 + #rows * rh + 6
    gfx.icon("mic_none", 22, ey + 14, 20, theme.text3)
    gfx.color(theme.text3)
    gfx.text(TR("no_recs"), 42, ey + 6, 13)
  end
  ui.endScroll()
  if not action then return end
  if action[1] == "play" then playEvents(action[2], action[3])
  elseif action[1] == "stop" then player = nil
  elseif action[1] == "follow" then startFollow(action[2], action[3])
  elseif action[1] == "del" and recs[action[2]] then
    undoRec = {action[2], table.remove(recs, action[2])}
    saveRecs()
    showToast(TR("deleted"))
  elseif action[1] == "ren" and recs[action[2]] then
    local i = action[2]
    ui.prompt(TR("rename"), TR("rename_msg"), recs[i].name, function(s)
      s = s and s:gsub("^%s+", ""):gsub("%s+$", "") or ""
      if s ~= "" and recs[i] then recs[i].name = s:sub(1, 40); saveRecs() end
    end)
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  -- toolbar
  local recLabel = recording and TR("stop_rec", string.format("%.1f", clock - recording.start)) or TR("record")
  if ui.button(recLabel .. "##rec", 16, 12, 150, 34, recording and "destructive" or "default", recording and "stop" or "fiber_manual_record") then
    toggleRecord()
  end
  if ui.button(TR("stop") .. "##stop", 174, 12, 100, 34, "default", "stop", player ~= nil or follow ~= nil) then stopAll() end
  local nb = ui.segmented("bars", {"8", "15"}, bars == 8 and 1 or 2, 284, 14, 100, 30)
  local nbars = nb == 1 and 8 or 15
  if nbars ~= bars then bars = nbars; store.set("bars", bars); hitAnim = {} end
  gfx.color(theme.text2)
  gfx.text(TR("tempo", string.format("%.2g", tempo)), 398, 21, 12)
  local sw = math.max(60, w - 500)
  local t = ui.slider("tempo", tempo, 0.5, 2, 484, 20, math.min(200, sw), 0.05)
  if t ~= tempo then tempo = t; store.set("tempo", tempo) end

  local listH = math.max(120, math.min(240, h * 0.36))
  local xh = h - 64 - listH - 24
  drawXylophone(28, 64, w - 56, xh)

  -- follow progress
  if follow then
    gfx.color(theme.text2)
    gfx.text(TR("follow_status", follow.name, follow.i - 1, #follow.events, follow.wrong), 0, h - listH - 30, 12, "semibold", "center", w)
  end
  drawList(16, h - listH - 12, w - 32, listH)

  if toastT > 0 then
    local tw = gfx.textWidth(toast, 13) + 32
    gfx.alpha(math.min(1, toastT * 3))
    gfx.rect(w / 2 - tw / 2, 54, tw, 32, 16, "#1C1C1EE6")
    gfx.color("#FFFFFF")
    gfx.text(toast, w / 2 - tw / 2, 62, 13, "semibold", "center", tw)
    gfx.unalpha()
  end
end

function app.event(e)
  if e.type ~= "keydown" then return end
  local k = e.key
  if e.ctrl and k == "z" and undoRec then
    table.insert(recs, math.min(undoRec[1], #recs + 1), undoRec[2])
    undoRec = nil
    saveRecs()
    return
  end
  for i, key in ipairs(KEYS8) do if k == key and i <= bars then hitBar(i) return end end
  for i, key in ipairs(KEYS_HI) do if k == key and i + 8 <= bars then hitBar(i + 8) return end end
  if k == "space" then toggleRecord()
  elseif k == "escape" then stopAll(); recording = nil end
end

function app.menu()
  local songs = {}
  for i, s in ipairs(SONGS) do songs[i] = {label = TR(s.key), id = 100 + i} end
  return {
    {title = TR("app_name"), items = {
      {label = TR("record"), id = 1, shortcut = "Space"},
      {label = TR("stop"), id = 2, shortcut = "Esc"},
      {label = TR("undo_delete"), id = 3, shortcut = "Ctrl+Z", enabled = undoRec ~= nil},
      "-",
      {label = TR("bars8"), id = 4},
      {label = TR("bars15"), id = 5},
    }},
    {title = TR("songs"), items = songs},
  }
end

function app.onmenu(id)
  if id == 1 then toggleRecord()
  elseif id == 2 then stopAll(); recording = nil
  elseif id == 3 and undoRec then
    table.insert(recs, math.min(undoRec[1], #recs + 1), undoRec[2]); undoRec = nil; saveRecs()
  elseif id == 4 then bars = 8; store.set("bars", 8)
  elseif id == 5 then bars = 15; store.set("bars", 15)
  elseif id > 100 and SONGS[id - 100] then
    local s = SONGS[id - 100]
    playEvents((songEvents(s)), TR(s.key))
  end
end

function app.close()
  store.save()
  return true
end

return app
