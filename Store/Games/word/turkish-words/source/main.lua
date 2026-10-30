-- Kelime Bul / Word Finder for Nexvyn OS: guess the 5-letter Turkish word in six tries. Daily word (the same for
-- everyone on a date) and unlimited mode, an on-screen Turkish Q keyboard, flip animations, streaks and statistics.
-- The interface is Turkish or English; the word list is always Turkish (words.lua).
local K = require("kit")
local F = require("frame")
local T = require("turkish")
local W = require("words")
local app = {}

local floor, max, min, abs, sin, cos, pi = math.floor, math.max, math.min, math.abs, math.sin, math.cos, math.pi
local random = math.random

local LEN, TRIES = 5, 6
local FLIP = 0.32
local KB = {{"E", "R", "T", "Y", "U", "I", "O", "P", "Ğ", "Ü"},
            {"A", "S", "D", "F", "G", "H", "J", "K", "L", "Ş", "İ"},
            {"ENTER", "Z", "C", "V", "B", "N", "M", "Ö", "Ç", "BACK"}}
local RANK = {absent = 1, present = 2, correct = 3}

local answers = {}           -- uppercase letter arrays
local dict = {}              -- uppercase word -> true
local mode = "daily"         -- daily | free
local target = {}
local targetWord = ""
local rows = {}              -- rows[r] = {letters = {...}, marks = {...}, t = reveal start}
local input = {}
local state = "play"         -- play | won | lost
local endT = 0
local dayNo = 0
local keyState = {}
local hintPos = {}           -- hintPos[i] = letter revealed by a hint (unlimited mode)
local stats = {daily = {}, free = {}}
local lastDailyWin = -1
local cur = {x = 1, y = 1}
local fx = K.particles()
local G = {x = 0, y = 0, s = 0}
local shakeT, popT = -10, {}

-- ------------------------------------------------------------------ words
local function upperWord(w)
  local l = T.letters(w)
  for i = 1, #l do l[i] = T.upper(l[i]) end
  return l
end

local function buildDict()
  for i, w in ipairs(W.ANSWERS) do
    local l = upperWord(w)
    answers[i] = l
    dict[table.concat(l)] = true
  end
  for _, w in ipairs(W.EXTRA) do dict[table.concat(upperWord(w))] = true end
end

-- days since 1970-01-01 for a civil date (Howard Hinnant's algorithm)
local function daysFromCivil(y, m, d)
  y = m <= 2 and y - 1 or y
  local era = (y >= 0 and y or y - 399) // 400
  local yoe = y - era * 400
  local doy = (153 * (m + (m > 2 and -3 or 9)) + 2) // 5 + d - 1
  local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
  return era * 146097 + doe - 719468
end

local function today()
  local d = sys.date()
  return daysFromCivil(d.year, d.month, d.day)
end

local function dailyIndex(day)
  -- a fixed pseudo-random walk through the list so consecutive days differ a lot
  return (day * 7919 + 104729) % #answers + 1
end

local function modeStats()
  local s = stats[mode]
  s.played, s.wins = tonumber(s.played) or 0, tonumber(s.wins) or 0
  s.streak, s.best = tonumber(s.streak) or 0, tonumber(s.best) or 0
  if type(s.dist) ~= "table" then s.dist = {} end
  for i = 1, TRIES do s.dist[i] = tonumber(s.dist[i]) or 0 end
  return s
end

-- ------------------------------------------------------------------ persistence
local function saveStats()
  store.set("stats", stats)
  store.set("lastDailyWin", lastDailyWin)
  store.set("mode", mode)
end

local function saveGame()
  local rs = {}
  for i, r in ipairs(rows) do rs[i] = table.concat(r.letters) end
  local data = {word = targetWord, rows = rs, state = state, day = dayNo}
  store.set(mode == "daily" and "daily" or "free", data)
end

-- ------------------------------------------------------------------ scoring
local function score(guess)
  local marks, left = {}, {}
  for i = 1, LEN do
    if guess[i] == target[i] then marks[i] = "correct"
    else left[target[i]] = (left[target[i]] or 0) + 1 end
  end
  for i = 1, LEN do
    if not marks[i] then
      local l = guess[i]
      if (left[l] or 0) > 0 then marks[i] = "present"; left[l] = left[l] - 1 else marks[i] = "absent" end
    end
  end
  return marks
end

local function rebuildKeys()
  keyState = {}
  for _, r in ipairs(rows) do
    for i = 1, LEN do
      local l, m = r.letters[i], r.marks[i]
      if not keyState[l] or RANK[m] > RANK[keyState[l]] then keyState[l] = m end
    end
  end
end

local function setTarget(letters)
  target = letters
  targetWord = table.concat(letters)
end

local function restoreRows(list, instant)
  rows = {}
  for _, s in ipairs(list) do
    local l = T.letters(s)
    if #l == LEN then
      rows[#rows + 1] = {letters = l, marks = score(l), t = instant and -10 or sys.time()}
    end
  end
  rebuildKeys()
end

local function startDaily()
  mode = "daily"
  dayNo = today()
  setTarget(answers[dailyIndex(dayNo)])
  input, hintPos = {}, {}
  state = "play"
  local g = store.get("daily")
  if type(g) == "table" and g.day == dayNo and g.word == targetWord and type(g.rows) == "table" then
    restoreRows(g.rows, true)
    state = (g.state == "won" or g.state == "lost") and g.state or "play"
  else
    rows = {}
    rebuildKeys()
  end
  saveStats()
  saveGame()
  F.play()
end

local function startFree(forceNew)
  mode = "free"
  input, hintPos = {}, {}
  local g = store.get("free")
  if not forceNew and type(g) == "table" and g.state == "play" and type(g.word) == "string" and dict[g.word] then
    setTarget(T.letters(g.word))
    restoreRows(type(g.rows) == "table" and g.rows or {}, true)
    state = "play"
  else
    setTarget(answers[random(#answers)])
    rows = {}
    rebuildKeys()
    state = "play"
  end
  saveStats()
  saveGame()
  F.play()
  K.notes({392, 494, 587}, 0.06, 0.14)
end

-- ------------------------------------------------------------------ actions
local function finish(won)
  state = won and "won" or "lost"
  endT = sys.time() + LEN * FLIP * 0.5 + 0.3
  local s = modeStats()
  s.played = s.played + 1
  if won then
    s.wins = s.wins + 1
    s.dist[#rows] = s.dist[#rows] + 1
    if mode == "daily" then
      s.streak = (lastDailyWin == dayNo - 1) and s.streak + 1 or 1
      lastDailyWin = dayNo
    else
      s.streak = s.streak + 1
    end
    s.best = max(s.best, s.streak)
  else
    s.streak = 0
  end
  saveStats()
  saveGame()
  timer.after(LEN * FLIP * 0.5 + 0.3, function()
    if won then
      F.winSound()
      K.rumble(0.5, 90)
      F.celebrate(fx, G.x, G.y, G.s * LEN, G.s * TRIES)
    else
      F.loseSound()
      K.rumble(0.6, 140)
    end
  end)
  timer.after(LEN * FLIP * 0.5 + 1.6, function() if state ~= "play" and F.scene == "play" then F.open("over") end end)
end

local function typeLetter(l)
  if state ~= "play" or F.modal() or #input >= LEN then return end
  input[#input + 1] = l
  popT[#input] = sys.time()
  K.tone(700 + #input * 40, 0.03, 0.12, "triangle")
end

local function backspace()
  if state ~= "play" or F.modal() or #input == 0 then return end
  input[#input] = nil
  K.tone(420, 0.03, 0.1, "sine")
end

local function submit()
  if state ~= "play" or F.modal() then return end
  if #input < LEN then
    shakeT = sys.time()
    K.toast(TR("too_short"))
    K.tone(150, 0.1, 0.15, "square")
    return
  end
  local word = table.concat(input)
  if not dict[word] then
    shakeT = sys.time()
    K.toast(TR("not_in_list"))
    K.tone(150, 0.1, 0.15, "square")
    K.rumble(0.3, 40)
    return
  end
  local letters = {}
  for i = 1, LEN do letters[i] = input[i] end
  local marks = score(letters)
  rows[#rows + 1] = {letters = letters, marks = marks, t = sys.time()}
  input = {}
  for i = 1, LEN do
    timer.after((i - 1) * FLIP * 0.5 + FLIP * 0.5, function()
      local m = marks[i]
      K.tone(m == "correct" and 880 or (m == "present" and 660 or 330), 0.06, 0.18, "triangle")
    end)
  end
  timer.after(LEN * FLIP * 0.5 + FLIP * 0.5, rebuildKeys)
  if word == targetWord then finish(true)
  elseif #rows >= TRIES then finish(false)
  else saveGame() end
end

local function hint()
  if mode ~= "free" or state ~= "play" or F.modal() then
    K.toast(TR("hint_free_only"))
    return
  end
  local known = {}
  for _, r in ipairs(rows) do
    for i = 1, LEN do if r.marks[i] == "correct" then known[i] = true end end
  end
  local pool = {}
  for i = 1, LEN do if not known[i] and not hintPos[i] then pool[#pool + 1] = i end end
  if #pool <= 1 then K.toast(TR("no_hint")); return end
  local i = pool[random(#pool)]
  hintPos[i] = target[i]
  F.chord({660, 880, 1100}, 0.2, 0.2, "sine")
end

local function pressKey(k)
  if k == "ENTER" then submit() elseif k == "BACK" then backspace() else typeLetter(k) end
end

-- ------------------------------------------------------------------ app
function app.load()
  K.loadPrefs()
  buildDict()
  local s = store.get("stats", {})
  if type(s) == "table" then
    stats.daily = type(s.daily) == "table" and s.daily or {}
    stats.free = type(s.free) == "table" and s.free or {}
  end
  lastDailyWin = tonumber(store.get("lastDailyWin", -1)) or -1
  if store.get("mode", "daily") == "free" then startFree(false) else startDaily() end
  F.open("title")
end

function app.update(dt)
  fx:update(dt)
  local d = F.stick(dt)
  if d and F.scene == "play" and state == "play" then
    F.moveCursor(cur, F.DIRV[d][1], F.DIRV[d][2], #KB[cur.y], #KB, true)
    cur.x = min(cur.x, #KB[cur.y])
  end
  -- a new day while the window is open
  if mode == "daily" and F.scene ~= "play" and today() ~= dayNo and state ~= "play" then startDaily(); F.open("title") end
end

-- ------------------------------------------------------------------ drawing
local function markColor(m)
  if m == "correct" then return "#4CAF50" elseif m == "present" then return "#E6B422" end
  return theme.dark and "#3A3A3F" or "#787C7E"
end

local function drawTile(x, y, s, l, m, flipP, pop, hintL)
  local r = s * 0.12
  if m and flipP and flipP > 0 then
    local p = min(1, flipP)
    local sy = abs(cos(p * pi))
    local showMark = p >= 0.5
    local hh = s * (p >= 1 and 1 or sy)
    local yy = y + (s - hh) / 2
    if showMark then
      gfx.rect(x, yy, s, hh, r, markColor(m))
      gfx.color("#FFFFFF")
    else
      gfx.rect(x, yy, s, hh, r, theme.window)
      gfx.color(theme.text3)
      gfx.rectLine(x, yy, s, hh, r, 2)
      gfx.color(theme.text)
    end
    if hh > s * 0.35 then F.ctext(l, x, yy, s, hh, s * 0.5 * (hh / s), "bold") end
    return
  end
  local sc = pop or 1
  local ss = s * sc
  local xx, yy = x + (s - ss) / 2, y + (s - ss) / 2
  gfx.rect(xx, yy, ss, ss, r, theme.window)
  gfx.color(l and K.col(theme.text, 0.55) or K.col(theme.text, 0.18))
  gfx.rectLine(xx, yy, ss, ss, r, 2)
  if l then
    gfx.color(theme.text)
    F.ctext(l, xx, yy, ss, ss, ss * 0.5, "bold")
  elseif hintL then
    gfx.color(K.col("#4CAF50", 0.55))
    F.ctext(hintL, xx, yy, ss, ss, ss * 0.5, "bold")
  end
end

local function drawGrid(now)
  local s, gap = G.s, G.gap
  for r = 1, TRIES do
    local y = G.y + (r - 1) * (s + gap)
    local row = rows[r]
    local isCur = r == #rows + 1 and state == "play"
    local sx = 0
    if isCur and now - shakeT < 0.35 then sx = sin((now - shakeT) * 70) * 8 * (1 - (now - shakeT) / 0.35) end
    for i = 1, LEN do
      local x = G.x + (i - 1) * (s + gap) + sx
      if row then
        local p = (now - row.t - (i - 1) * FLIP * 0.5) / FLIP
        if row.t < 0 then p = 1 end
        local by = 0
        if state == "won" and r == #rows then
          local k = now - endT - i * 0.08
          if k > 0 and k < 0.5 then by = -sin(k / 0.5 * pi) * s * 0.3 end
        end
        drawTile(x, y + by, s, row.letters[i], row.marks[i], max(0.0001, p))
      elseif isCur then
        local pop = 1
        if input[i] and popT[i] and now - popT[i] < 0.12 then pop = 1 + 0.12 * sin((now - popT[i]) / 0.12 * pi) end
        drawTile(x, y, s, input[i], nil, nil, pop, hintPos[i])
      else
        drawTile(x, y, s, nil)
      end
    end
  end
end

local function drawKeyboard(x, y, w, h)
  local rowsN = #KB
  local kh = min(54, (h - (rowsN - 1) * 7) / rowsN)
  local unit = min(50, (w - 10 * 6) / 11)
  for r, row in ipairs(KB) do
    local widths, total = {}, 0
    for c, k in ipairs(row) do
      widths[c] = (k == "ENTER" or k == "BACK") and unit * 1.55 or unit
      total = total + widths[c] + (c > 1 and 6 or 0)
    end
    local kx = x + (w - total) / 2
    local ky = y + (r - 1) * (kh + 7)
    for c, k in ipairs(row) do
      local kw = widths[c]
      local hit = ui.hit("k" .. k, kx, ky, kw, kh)
      local st = keyState[k]
      local bg = st and markColor(st) or (theme.dark and "#5A5A60" or "#D3D6DA")
      if hit.hovered and not st then bg = K.mix(bg, theme.text, 0.1) end
      local yy = ky + (hit.held and 2 or 0)
      gfx.rect(kx, yy, kw, kh, 7, bg)
      gfx.color(st and "#FFFFFF" or theme.text)
      if k == "ENTER" then gfx.icon("keyboard_return", kx + kw / 2, yy + kh / 2, kh * 0.5, st and "#FFFFFF" or theme.text)
      elseif k == "BACK" then gfx.icon("backspace", kx + kw / 2, yy + kh / 2, kh * 0.45, theme.text)
      else F.ctext(k, kx, yy, kw, kh, kh * 0.4, "bold") end
      if cur.x == c and cur.y == r and state == "play" and not F.modal() then K.ring(kx - 3, ky - 3, kw + 6, kh + 6, 9) end
      if hit.clicked and not F.modal() then
        K.lastInput = "pointer"
        cur.x, cur.y = c, r
        pressKey(k)
      end
      kx = kx + kw + 6
    end
  end
end

local function countdown()
  local d = sys.date()
  local left = max(0, 86400 - (d.hour * 3600 + d.min * 60 + d.sec))
  return string.format("%02d:%02d:%02d", left // 3600, (left // 60) % 60, left % 60)
end

local function statLines()
  local s = modeStats()
  return {{TR("played"), tostring(s.played)},
          {TR("win_rate"), s.played > 0 and (floor(s.wins / s.played * 100 + 0.5) .. "%") or "—"},
          {TR("streak"), tostring(s.streak)}, {TR("best_streak"), tostring(s.best)}}
end

local function drawDist(x, y, w)
  local s = modeStats()
  local mx = 1
  for i = 1, TRIES do mx = max(mx, s.dist[i]) end
  for i = 1, TRIES do
    local yy = y + (i - 1) * 19
    gfx.color(theme.text2)
    gfx.text(tostring(i), x, yy, 12, "semibold", "right", 14)
    local bw = max(22, (w - 26) * s.dist[i] / mx)
    local hl = state == "won" and #rows == i
    gfx.rect(x + 22, yy, bw, 16, 4, hl and "#4CAF50" or K.col(theme.text, 0.25))
    gfx.color("#FFFFFF")
    gfx.text(tostring(s.dist[i]), x + 22, yy + 1, 11, "bold", "right", bw - 5)
  end
end

local function drawDialogs(w, h)
  local s = F.scene
  if s == "pause" then
    F.pauseDialog(w, h, {onRestart = function() if mode == "free" then startFree(true) else F.close() end end,
                         onMenu = function() F.open("title") end})
  elseif s == "over" or s == "stats" then
    local won = state == "won"
    local title, sub
    if s == "over" then
      title = won and TR("solved_in", #rows) or TR("not_solved")
      sub = TR("the_word", T.upperStr(targetWord))
    else
      title, sub = TR("stats_title"), mode == "daily" and TR("mode_daily") or TR("mode_free")
    end
    local lines = statLines()
    if mode == "daily" and state ~= "play" then lines[#lines + 1] = {TR("next_daily"), countdown()} end
    local buttons = {}
    if mode == "free" and s == "over" then buttons[1] = {TR("next_word"), function() startFree(true) end, "primary", "arrow_forward"} end
    if mode == "daily" and s == "over" then buttons[1] = {TR("play_free"), function() startFree(true) end, "primary", "all_inclusive"} end
    buttons[#buttons + 1] = {TR("close"), F.close}
    if s == "stats" then buttons[#buttons + 1] = {TR("reset_stats"), function() F.open("reset", 2) end, "destructive"} end
    K.dialog(F.dlg, w, h, {icon = s == "over" and (won and "emoji_events" or "sentiment_dissatisfied") or "bar_chart",
      iconColor = s == "over" and (won and theme.yellow or theme.red) or nil, title = title, subtitle = sub, width = 340,
      lines = lines, extraH = TRIES * 19 + 6, extra = drawDist, buttons = buttons})
  elseif s == "help" then
    K.dialog(F.dlg, w, h, {icon = "help", title = TR("how_to"), subtitle = TR("help_text"), width = 400, extraH = 52,
      extra = function(x, y, ww)
        local ex = {{"K", "correct"}, {"A", "present"}, {"L", "absent"}, {"E"}, {"M"}}
        for i, e in ipairs(ex) do
          drawTile(x + ww / 2 + (i - 3) * 48 - 21, y + 4, 42, e[1], e[2], e[2] and 1 or nil)
        end
      end,
      buttons = {{TR("close"), F.close}}})
  else
    F.commonDialogs(w, h, {stats = statLines,
      onReset = function() stats = {daily = {}, free = {}}; lastDailyWin = -1; saveStats() end,
      onNew = function() startFree(true) end})
  end
end

local function drawTitle(w, h)
  local dailyDone = false
  local g = store.get("daily")
  if type(g) == "table" and g.day == today() and (g.state == "won" or g.state == "lost") then dailyDone = true end
  F.titleScreen(w, h, {icon = "spellcheck", c1 = "#6EE7B7", c2 = "#059669", title = TR("title"), subtitle = TR("tagline"),
    buttons = {{dailyDone and TR("daily_done") or TR("play_daily"), function() startDaily() end, "primary", "today"},
               {TR("play_free"), function() startFree(false) end, "default", "all_inclusive"},
               {TR("how_to"), function() F.open("help"); F.returnTo = "title" end, "default", "help"},
               {TR("stats_title"), function() F.open("stats") end, "default", "bar_chart"}},
    footer = TR("list_note", #answers)})
end

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  if F.scene == "title" or (F.scene ~= "play" and F.returnTo == "title") then
    drawTitle(w, h)
    if F.scene ~= "title" then drawDialogs(w, h) end
    return
  end
  local sub = mode == "daily" and TR("daily_line", dayNo - 20000) or TR("mode_free")
  F.title(TR("title"), sub, 16, 10)
  local hit = F.toolbar({{"pause", "pause"}, F.soundItem(), {"bar_chart", "stats"}, {"help", "help"},
                         {mode == "daily" and "all_inclusive" or "today", "mode"},
                         {"lightbulb", "hint", mode == "free" and nil or theme.text3}}, w - 16, 14)
  if hit == "sound" then K.setMuted(not K.muted)
  elseif hit == "pause" then F.open("pause")
  elseif hit == "stats" then F.open("stats")
  elseif hit == "help" then F.open("help")
  elseif hit == "mode" then if mode == "daily" then startFree(false) else startDaily() end
  elseif hit == "hint" then hint() end
  local kbH = min(190, h * 0.3)
  local kbY = h - 36 - kbH
  local top = 64
  local gridH = kbY - 14 - top
  local gap = 6
  local s = floor(min(64, (gridH - (TRIES - 1) * gap) / TRIES, (w - 32 - (LEN - 1) * gap) / LEN))
  G.s, G.gap = s, gap
  G.x = floor((w - (s * LEN + gap * (LEN - 1))) / 2)
  G.y = floor(top + (gridH - (s * TRIES + gap * (TRIES - 1))) / 2)
  drawGrid(now)
  if mode == "daily" and state ~= "play" then
    gfx.color(theme.text2)
    gfx.text(TR("next_in", countdown()), 0, kbY - 26, 12, "semibold", "center", w)
  end
  drawKeyboard(16, kbY, w - 32, kbH)
  fx:draw()
  if K.lastInput == "pad" then
    K.hints({{"dpad", TR("h_move")}, {"A", TR("h_key")}, {"B", TR("h_delete")}, {"+", TR("h_enter")},
             {"Y", TR("h_hint")}, {"-", TR("h_pause")}}, 0, h - 28, w)
  elseif K.lastInput == "key" then
    K.hints({{"A-Z", TR("h_type")}, {"Enter", TR("h_enter")}, {"Backspace", TR("h_delete")}, {"Esc", TR("h_pause")}}, 0, h - 28, w)
  else
    K.hints({{"touch", TR("h_tap_keys")}}, 0, h - 28, w)
  end
  drawDialogs(w, h)
  K.drawToast(w, G.y + s * 2)
end

-- ------------------------------------------------------------------ input
function app.event(e)
  K.track(e)
  local t = e.type
  if F.modal() then F.dialogEvent(e); return end
  if t == "paddown" then
    local p = e.pad
    local d = F.DIRV[p]
    if state ~= "play" then
      if p == "a" then F.open("over") elseif p == "minus" then F.open("pause") elseif p == "x" and mode == "free" then startFree(true) end
      return
    end
    if d then
      F.moveCursor(cur, d[1], d[2], #KB[cur.y], #KB, true)
      cur.x = min(cur.x, #KB[cur.y])
    elseif p == "a" then pressKey(KB[cur.y][cur.x])
    elseif p == "b" or p == "x" then backspace()
    elseif p == "plus" then submit()
    elseif p == "y" then hint()
    elseif p == "minus" then F.open("pause") end
  elseif t == "text" then
    local l = T.fromInput(e.text)
    if l then typeLetter(l) end
  elseif t == "keydown" then
    local k = e.key
    if state ~= "play" then
      if k == "enter" or k == "space" then F.open("over") elseif k == "escape" then F.open("pause") end
      return
    end
    if k == "enter" then submit()
    elseif k == "backspace" then backspace()
    elseif k == "escape" then F.open("pause")
    elseif F.DIRV[k] then
      F.moveCursor(cur, F.DIRV[k][1], F.DIRV[k][2], #KB[cur.y], #KB, true)
      cur.x = min(cur.x, #KB[cur.y])
    end
  end
end

function app.menu()
  return {{title = TR("menu_game"), items = {
    {label = TR("play_daily"), id = 1, checked = mode == "daily"},
    {label = TR("play_free"), id = 2, checked = mode == "free"},
    {label = TR("next_word"), id = 3, enabled = mode == "free"},
    {label = TR("hint"), id = 4, enabled = mode == "free"},
    "-",
    {label = TR("how_to"), id = 5},
    {label = TR("sound"), id = 6, checked = not K.muted},
    {label = TR("stats_title"), id = 7},
  }}}
end

function app.onmenu(id)
  if id == 1 then startDaily()
  elseif id == 2 then startFree(false)
  elseif id == 3 then startFree(true)
  elseif id == 4 then hint()
  elseif id == 5 then F.open("help")
  elseif id == 6 then K.setMuted(not K.muted)
  elseif id == 7 then F.open("stats") end
end

function app.close()
  saveGame()
  saveStats()
  return true
end

return app
