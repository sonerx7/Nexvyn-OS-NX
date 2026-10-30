-- Metronome for Nexvyn OS: 30-250 BPM, tap tempo, time signatures, accented downbeat, animated pendulum.
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

-- ------------------------------------------------------------------ state
local SIGS = {{2, 4, "2/4"}, {3, 4, "3/4"}, {4, 4, "4/4"}, {6, 8, "6/8"}}
local SIG_LABELS = {"2/4", "3/4", "4/4", "6/8"}
local SOUNDS = {"snd_beep", "snd_click", "snd_wood"}

local bpm = 100
local sig = 3
local soundType = 1
local accentOn = true
local running = false
local nextBeat = 0
local lastBeatAt = 0
local beatIndex = 0           -- 1-based beat inside the bar of the last played beat
local beatCount = 0           -- total beats since start (drives the pendulum)
local flash = 0
local angle = 0
local taps = {}
local tapFlash = 0
local lastInput = "touch"
local held = {}               -- d-pad / arrow repeat {dir = time pressed}
local repeatAt = {}
local bpmShown = 100

local function interval() return 60 / bpm end

local function save()
  store.set("bpm", bpm)
  store.set("sig", sig)
  store.set("sound", soundType)
  store.set("accent", accentOn)
end

local function setBpm(v)
  v = max(30, min(250, floor(v + 0.5)))
  if v ~= bpm then
    bpm = v
    save()
  end
end

local function tempoName(b)
  if b < 40 then return "tempo_grave"
  elseif b < 60 then return "tempo_largo"
  elseif b < 66 then return "tempo_larghetto"
  elseif b < 76 then return "tempo_adagio"
  elseif b < 108 then return "tempo_andante"
  elseif b < 120 then return "tempo_moderato"
  elseif b < 156 then return "tempo_allegro"
  elseif b < 176 then return "tempo_vivace"
  elseif b < 200 then return "tempo_presto"
  end
  return "tempo_prestissimo"
end

local function click(level)   -- level 2 = downbeat, 1 = secondary accent, 0 = normal
  local vol = level == 2 and 0.55 or (level == 1 and 0.42 or 0.32)
  if soundType == 1 then
    local f = level == 2 and 1760 or (level == 1 and 1480 or 1175)
    audio.tone(f, 0.05, vol, "sine")
  elseif soundType == 2 then
    local f = level == 2 and 2093 or (level == 1 and 1760 or 1397)
    audio.tone(f, 0.025, vol * 0.8, "square")
  else
    local f = level == 2 and 1046.5 or (level == 1 and 880 or 784)
    audio.tone(f, 0.03, vol, "triangle")
    audio.tone(f * 2, 0.015, vol * 0.5, "noise")
  end
end

local function playBeat()
  local beats = SIGS[sig][1]
  beatIndex = beatIndex % beats + 1
  beatCount = beatCount + 1
  local level = 0
  if accentOn and beatIndex == 1 then level = 2
  elseif accentOn and sig == 4 and beatIndex == 4 then level = 1 end
  click(level)
  flash = 1
  if level == 2 then sys.vibrate(0.25, 30) end
end

local function start()
  running = true
  beatIndex = 0
  beatCount = 0
  local now = sys.time()
  nextBeat = now
  lastBeatAt = now
end

local function stop()
  running = false
  beatIndex = 0
end

local function toggle()
  if running then stop() else start() end
end

local function tap()
  local now = sys.time()
  if #taps > 0 and now - taps[#taps] > 2.0 then taps = {} end
  taps[#taps + 1] = now
  while #taps > 6 do table.remove(taps, 1) end
  tapFlash = 1
  audio.tone(1318.5, 0.03, 0.3, "triangle")
  if #taps >= 2 then
    local sum = 0
    for i = 2, #taps do sum = sum + (taps[i] - taps[i - 1]) end
    local avg = sum / (#taps - 1)
    if avg > 0 then setBpm(60 / avg) end
  end
end

local function setSig(i)
  if i < 1 then i = #SIGS elseif i > #SIGS then i = 1 end
  sig = i
  beatIndex = 0
  save()
  audio.play("click", 0.5)
end

function app.load()
  bpm = max(30, min(250, floor(tonumber(store.get("bpm", 100)) or 100)))
  sig = max(1, min(#SIGS, floor(tonumber(store.get("sig", 3)) or 3)))
  soundType = max(1, min(#SOUNDS, floor(tonumber(store.get("sound", 1)) or 1)))
  accentOn = store.get("accent", true) ~= false
  bpmShown = bpm
end

-- ------------------------------------------------------------------ update
local function stepDir(dir)
  if dir == "left" then setBpm(bpm - 1)
  elseif dir == "right" then setBpm(bpm + 1)
  elseif dir == "up" then setBpm(bpm + 5)
  elseif dir == "down" then setBpm(bpm - 5) end
end

function app.update(dt)
  local now = sys.time()
  if running then
    if now - nextBeat > 0.25 then nextBeat = now end   -- we were suspended: don't burst
    while now >= nextBeat do
      playBeat()
      lastBeatAt = nextBeat
      nextBeat = nextBeat + interval()
    end
    local f = min(1, (now - lastBeatAt) / interval())
    local target = 0.5 * cos(pi * (beatCount - 1 + f))
    angle = target
  else
    angle = angle * max(0, 1 - dt * 5)
  end
  flash = max(0, flash - dt * 4)
  tapFlash = max(0, tapFlash - dt * 4)
  bpmShown = bpmShown + (bpm - bpmShown) * min(1, dt * 14)
  -- key / d-pad repeat
  for dir, t0 in pairs(held) do
    if now - t0 > 0.4 and now >= (repeatAt[dir] or 0) then
      stepDir(dir)
      repeatAt[dir] = now + 0.06
    end
  end
end

-- ------------------------------------------------------------------ drawing
local function rotPts(cx, cy, pts, a)
  local out = {}
  local ca, sa = cos(a), sin(a)
  for i = 1, #pts, 2 do
    local x, y = pts[i], pts[i + 1]
    out[#out + 1] = cx + x * ca - y * sa
    out[#out + 1] = cy + x * sa + y * ca
  end
  return out
end

local function drawPendulum(cx, top, bottom)
  local H = bottom - top
  local bw, tw = H * 0.46, H * 0.17
  -- shadow
  gfx.color(0, 0, 0, theme.dark and 70 or 28)
  gfx.rect(cx - bw / 2 - 6, bottom - 4, bw + 12, 10, 5)
  -- body
  gfx.poly({cx - bw / 2, bottom, cx + bw / 2, bottom, cx + tw / 2, top, cx - tw / 2, top}, "#7A4B2A")
  gfx.poly({cx - bw / 2 + 6, bottom - 4, cx + bw / 2 - 6, bottom - 4, cx + tw / 2 - 3, top + 6, cx - tw / 2 + 3, top + 6}, "#9A6236")
  -- face plate
  local fb, ft = bottom - H * 0.2, top + 16
  local fbw, ftw = bw * 0.62, tw * 0.7
  gfx.poly({cx - fbw / 2, fb, cx + fbw / 2, fb, cx + ftw / 2, ft, cx - ftw / 2, ft}, "#F3E7D3")
  -- scale marks on the face
  for i = 0, 10 do
    local y = ft + 8 + i * (fb - ft - 16) / 10
    local k = (y - ft) / (fb - ft)
    local half = (ftw + (fbw - ftw) * k) / 2 - 6
    gfx.color(0x7A, 0x4B, 0x2A, i % 5 == 0 and 200 or 110)
    gfx.line(cx - half * (i % 5 == 0 and 0.6 or 0.35), y, cx + half * (i % 5 == 0 and 0.6 or 0.35), y, 1)
  end
  -- base plate
  gfx.color("#5C3720")
  gfx.rect(cx - bw / 2 - 8, bottom - 12, bw + 16, 14, 4)

  -- pendulum arm (angle 0 = straight up)
  local maxA = 0.5
  local a = angle * maxA / 0.5
  local px, py = cx, bottom - H * 0.16
  local L = H * 0.95
  local tx, ty = px + sin(a) * L, py - cos(a) * L
  gfx.color(0, 0, 0, 40)
  gfx.line(px + 2, py + 2, tx + 2, ty + 2, 4)
  gfx.color("#D4D4D8")
  gfx.line(px, py, tx, ty, 4)
  gfx.color("#A1A1AA")
  gfx.line(px - 1, py, tx - 1, ty, 1)
  -- sliding weight: higher on the arm = slower tempo
  local k = 0.92 - 0.6 * (bpmShown - 30) / 220
  local wx, wy = px + sin(a) * L * k, py - cos(a) * L * k
  local body = rotPts(wx, wy, {-15, -11, 15, -11, 11, 11, -11, 11}, a)
  gfx.poly(body, flash > 0 and beatIndex == 1 and accentOn and theme.orange or "#3F3F46")
  local shine = rotPts(wx, wy, {-12, -9, 12, -9, 10, -3, -10, -3}, a)
  gfx.poly(shine, {255, 255, 255, 50})
  gfx.color("#E4E4E7")
  gfx.circle(px, py, 7)
  gfx.color("#71717A")
  gfx.circle(px, py, 3)
end

local function padGlyph(label, x, y)
  gfx.color(theme.text2)
  gfx.circle(x + 9, y + 9, 9)
  gfx.color(theme.bg)
  gfx.text(label, x, y + 2, 11, "bold", "center", 18)
  return 18
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
    items = {{"pad", "A", TR("hint_startstop")}, {"pad", "X", TR("hint_tap")}, {"pad", "Y", TR("hint_sig")},
             {"icon", "gamepad", TR("hint_tempo")}}
  elseif lastInput == "key" then
    items = {{"key", TR("key_space"), TR("hint_startstop")}, {"key", "T", TR("hint_tap")},
             {"key", "1-4", TR("hint_sig")}, {"icon", "keyboard", TR("hint_tempo_keys")}}
  else
    items = {{"icon", "touch_app", TR("hint_touch")}}
  end
  local total = 0
  for _, it in ipairs(items) do
    local gw = it[1] == "key" and max(18, gfx.textWidth(it[2], 11, "semibold") + 10) or 18
    total = total + gw + 6 + gfx.textWidth(it[3], 12) + 18
  end
  local x = (w - total + 18) / 2
  for _, it in ipairs(items) do
    local gw
    if it[1] == "pad" then gw = padGlyph(it[2], x, y)
    elseif it[1] == "key" then gw = keyCap(it[2], x, y)
    else gfx.icon(it[2], x + 9, y + 9, 18, theme.text2); gw = 18 end
    gfx.color(theme.text2)
    local tw = gfx.text(it[3], x + gw + 6, y + 2, 12)
    x = x + gw + 6 + tw + 18
  end
end

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  local cx = w / 2

  -- pendulum stage
  local stageH = min(230, h * 0.42)
  gfx.gradient(0, 0, w, stageH + 20, alpha(theme.accent, theme.dark and 0.10 or 0.06), alpha(theme.accent, 0))
  drawPendulum(cx, 26, stageH)
  local stage = ui.hit("stage", cx - 120, 10, 240, stageH)
  if stage.clicked then toggle(); lastInput = "touch" end

  -- BPM readout with -/+ buttons
  local by = stageH + 16
  local cardW = min(w - 40, 380)
  local cardX = cx - cardW / 2
  gfx.shadow(cardX, by, cardW, 92, 14, 12, 3)
  gfx.color(theme.control)
  gfx.rect(cardX, by, cardW, 92, 14)
  if flash > 0 then
    local acc = (beatIndex == 1 and accentOn) and theme.orange or theme.accent
    gfx.color(alpha(acc, flash * 0.18))
    gfx.rect(cardX, by, cardW, 92, 14)
  end
  gfx.color(theme.text)
  gfx.text(tostring(floor(bpmShown + 0.5)), cardX, by + 6, 52, "bold", "center", cardW)
  gfx.color(theme.text2)
  gfx.text(TR("bpm") .. " · " .. TR(tempoName(bpm)), cardX, by + 66, 13, "medium", "center", cardW)
  if ui.iconButton("remove", cardX + 14, by + 26, 40, 40, nil, false, "minus") then setBpm(bpm - 1); lastInput = "touch" end
  if ui.iconButton("add", cardX + cardW - 54, by + 26, 40, 40, nil, false, "plus") then setBpm(bpm + 1); lastInput = "touch" end

  -- slider
  local sy = by + 104
  local nv = ui.slider("bpm", bpm, 30, 250, cardX, sy, cardW, 1)
  if floor(nv + 0.5) ~= bpm then setBpm(nv) end
  gfx.color(theme.text3)
  gfx.text("30", cardX, sy + 24, 11)
  gfx.text("250", cardX, sy + 24, 11, "sans", "right", cardW)

  -- beat dots
  local beats = SIGS[sig][1]
  local dy = sy + 52
  local gap = min(34, (cardW - 20) / beats)
  local dx0 = cx - (beats - 1) * gap / 2
  for i = 1, beats do
    local x = dx0 + (i - 1) * gap
    local active = running and i == beatIndex
    local accent = accentOn and (i == 1 or (sig == 4 and i == 4))
    local col = (i == 1 and accentOn) and theme.orange or theme.accent
    local r = (accent and 9 or 7) + (active and 3 * flash or 0)
    if active then
      gfx.color(alpha(col, 0.25 * (0.4 + flash)))
      gfx.circle(x, dy, r + 7)
      gfx.color(col)
      gfx.circle(x, dy, r)
    else
      gfx.color(alpha(col, accent and 0.45 or 0.28))
      gfx.circle(x, dy, r)
    end
  end

  -- time signature
  local segY = dy + 24
  local ns = ui.segmented("sig", SIG_LABELS, sig, cardX, segY, cardW, 30)
  if ns ~= sig then setSig(ns); lastInput = "touch" end

  -- tap + start/stop
  local btnY = segY + 44
  local half = (cardW - 12) / 2
  if tapFlash > 0 then
    gfx.color(alpha(theme.accent, tapFlash * 0.3))
    gfx.rect(cardX - 3, btnY - 3, half + 6, 46, 10)
  end
  if ui.button(TR("tap") .. "##tap", cardX, btnY, half, 40, "default", "touch_app") then tap(); lastInput = "touch" end
  local label = running and TR("stop") or TR("start")
  if ui.button(label .. "##go", cardX + half + 12, btnY, half, 40, running and "destructive" or "primary",
      running and "stop" or "play_arrow") then toggle(); lastInput = "touch" end

  if #taps >= 1 and now - taps[#taps] < 2 then
    gfx.color(theme.text3)
    gfx.text(TR("tap_count", #taps), cardX, btnY + 44, 11, "sans", "left", half)
  end

  drawHints(w, h - 26)
end

-- ------------------------------------------------------------------ input
local PAD_DIRS = {left = true, right = true, up = true, down = true}

function app.event(e)
  local now = sys.time()
  if e.type == "paddown" then
    lastInput = "pad"
    local p = e.pad
    if p == "a" or p == "plus" then toggle()
    elseif p == "b" then if running then stop() end
    elseif p == "x" then tap()
    elseif p == "y" or p == "r" then setSig(sig + 1)
    elseif p == "l" then setSig(sig - 1)
    elseif p == "minus" then accentOn = not accentOn; save()
    elseif PAD_DIRS[p] then stepDir(p); held[p] = now; repeatAt[p] = 0
    end
  elseif e.type == "padup" then
    held[e.pad] = nil
  elseif e.type == "keydown" then
    lastInput = "key"
    local k = e.key
    if k == "space" or k == "enter" then toggle()
    elseif k == "escape" then if running then stop() end
    elseif k == "t" then tap()
    elseif k == "1" or k == "2" or k == "3" or k == "4" then setSig(tonumber(k))
    elseif k == "a" then accentOn = not accentOn; save()
    elseif PAD_DIRS[k] then
      if not held[k] then stepDir(k); held[k] = now; repeatAt[k] = 0 end
    end
  elseif e.type == "keyup" then
    if PAD_DIRS[e.key] then held[e.key] = nil end
  elseif e.type == "mousedown" then
    lastInput = "touch"
  end
end

function app.menu()
  local sigItems = {}
  for i, s in ipairs(SIGS) do sigItems[#sigItems + 1] = {label = s[3], id = 10 + i, checked = sig == i, shortcut = tostring(i)} end
  sigItems[#sigItems + 1] = "-"
  sigItems[#sigItems + 1] = {label = TR("accent_first"), id = 20, checked = accentOn}
  local snd = {}
  for i, k in ipairs(SOUNDS) do snd[#snd + 1] = {label = TR(k), id = 30 + i, checked = soundType == i} end
  return {
    {title = TR("menu_metronome"), items = {
      {label = running and TR("stop") or TR("start"), id = 1, shortcut = "Space"},
      {label = TR("tap"), id = 2, shortcut = "T"},
      "-",
      {label = TR("tempo_up"), id = 3, shortcut = "Right"},
      {label = TR("tempo_down"), id = 4, shortcut = "Left"},
      {label = TR("reset_tempo"), id = 5},
    }},
    {title = TR("menu_rhythm"), items = sigItems},
    {title = TR("menu_sound"), items = snd},
  }
end

function app.onmenu(id)
  if id == 1 then toggle()
  elseif id == 2 then tap()
  elseif id == 3 then setBpm(bpm + 1)
  elseif id == 4 then setBpm(bpm - 1)
  elseif id == 5 then setBpm(100)
  elseif id > 10 and id <= 10 + #SIGS then setSig(id - 10)
  elseif id == 20 then accentOn = not accentOn; save()
  elseif id > 30 and id <= 30 + #SOUNDS then
    soundType = id - 30
    save()
    click(2)
  end
end

function app.close()
  save()
  return true
end

return app
