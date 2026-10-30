-- Şifre Kır / Code Breaker for Nexvyn OS: Mastermind. Crack a secret colour code in 10 tries. Classic (4 pegs,
-- 6 colours) or hard (5 pegs, 8 colours), duplicates on/off, numbered pegs for colour-blind players, hints,
-- undo of the current entry and full statistics with a guess distribution.
local K = require("kit")
local F = require("frame")
local app = {}

local floor, max, min, sin, pi = math.floor, math.max, math.min, math.sin, math.pi
local random = math.random

local TRIES = 10
local COLORS = {"#F44336", "#FF9800", "#FFEB3B", "#4CAF50", "#29B6F6", "#7E57C2", "#EC407A", "#8D6E63"}
local DIFFS = {{pegs = 4, colors = 6}, {pegs = 5, colors = 8}}

local diff = 1
local dupes = true
local pegs, ncol = 4, 6
local secret = {}
local rows = {}              -- rows[r] = {guess = {...}, black, white, t}
local entry = {}             -- current guess, entry[i] = colour or nil
local locked = {}            -- locked[i] = colour revealed by a hint
local entryLog = {}          -- slot indices in the order they were filled (undo)
local slot = 1
local state = "play"         -- play | won | lost
local endT = 0
local hints = 0
local stats = {}             -- stats[diff] = {played, wins, dist = {..10}, hints}
local fx = K.particles()
local L = {x = 0, y = 0, rowH = 0, peg = 0, w = 0, palY = 0, palX = 0, palS = 0}
local shakeT = -10

local function st()
  local s = stats[diff]
  if type(s) ~= "table" then s = {} ; stats[diff] = s end
  s.played = tonumber(s.played) or 0
  s.wins = tonumber(s.wins) or 0
  s.hints = tonumber(s.hints) or 0
  if type(s.dist) ~= "table" then s.dist = {} end
  for i = 1, TRIES do s.dist[i] = tonumber(s.dist[i]) or 0 end
  return s
end

-- ------------------------------------------------------------------ persistence
local function saveStats()
  store.set("stats", stats)
  store.set("diff", diff)
  store.set("dupes", dupes)
end

local function saveGame()
  local rs = {}
  for i, r in ipairs(rows) do rs[i] = r.guess end
  local en = {}
  for i = 1, pegs do en[i] = entry[i] or 0 end
  local lk = {}
  for i = 1, pegs do lk[i] = locked[i] or 0 end
  store.set("game", {diff = diff, dupes = dupes, secret = secret, rows = rs, entry = en, locked = lk, hints = hints,
                     state = state})
end

local function score(guess)
  local black, white = 0, 0
  local sc, gc = {}, {}
  for i = 1, pegs do
    if guess[i] == secret[i] then black = black + 1
    else
      sc[secret[i]] = (sc[secret[i]] or 0) + 1
      gc[guess[i]] = (gc[guess[i]] or 0) + 1
    end
  end
  for c, n in pairs(gc) do white = white + min(n, sc[c] or 0) end
  return black, white
end

local function newGame()
  pegs, ncol = DIFFS[diff].pegs, DIFFS[diff].colors
  secret = {}
  local pool = {}
  for c = 1, ncol do pool[c] = c end
  for i = 1, pegs do
    if dupes then secret[i] = random(ncol)
    else
      local j = random(i, ncol)
      pool[i], pool[j] = pool[j], pool[i]
      secret[i] = pool[i]
    end
  end
  rows, entry, locked, entryLog = {}, {}, {}, {}
  slot, state, hints = 1, "play", 0
  F.play()
  K.notes({392, 494, 587}, 0.06, 0.14)
  saveGame()
end

local function loadGame()
  local g = store.get("game")
  if type(g) ~= "table" or g.state ~= "play" or not DIFFS[tonumber(g.diff) or 0] then return false end
  diff = floor(g.diff)
  dupes = g.dupes ~= false
  pegs, ncol = DIFFS[diff].pegs, DIFFS[diff].colors
  local function valid(t, allowZero)
    if type(t) ~= "table" or #t ~= pegs then return false end
    for i = 1, pegs do
      local v = tonumber(t[i])
      if not v or v > ncol or v < (allowZero and 0 or 1) then return false end
    end
    return true
  end
  if not valid(g.secret) then return false end
  secret, rows, entry, locked, entryLog = {}, {}, {}, {}, {}
  for i = 1, pegs do secret[i] = floor(g.secret[i]) end
  if type(g.rows) == "table" then
    for _, gs in ipairs(g.rows) do
      if valid(gs) and #rows < TRIES then
        local gu = {}
        for i = 1, pegs do gu[i] = floor(gs[i]) end
        local b, w = score(gu)
        rows[#rows + 1] = {guess = gu, black = b, white = w, t = -10}
      end
    end
  end
  if valid(g.locked, true) then
    for i = 1, pegs do if g.locked[i] > 0 then locked[i] = floor(g.locked[i]) end end
  end
  if valid(g.entry, true) then
    for i = 1, pegs do if g.entry[i] > 0 then entry[i] = floor(g.entry[i]) end end
  end
  for i = 1, pegs do if locked[i] then entry[i] = locked[i] end end
  hints = tonumber(g.hints) or 0
  state, slot = "play", 1
  return true
end

-- ------------------------------------------------------------------ actions
local function nextFree(from)
  for k = 0, pegs - 1 do
    local i = (from - 1 + k) % pegs + 1
    if not entry[i] then return i end
  end
  return from
end

local function setColor(c)
  if state ~= "play" or F.modal() then return end
  if locked[slot] then slot = nextFree(slot) end
  if locked[slot] then return end
  entry[slot] = c
  entryLog[#entryLog + 1] = slot
  K.tone(330 + c * 45, 0.05, 0.18, "triangle")
  slot = nextFree(slot % pegs + 1)
  saveGame()
end

local function cycle(dir)
  if state ~= "play" or locked[slot] then return end
  local c = entry[slot] or (dir > 0 and 0 or 1)
  c = (c - 1 + dir) % ncol + 1
  entry[slot] = c
  entryLog[#entryLog + 1] = slot
  K.tone(330 + c * 45, 0.03, 0.12, "triangle")
end

local function clearSlot()
  if state ~= "play" or locked[slot] or not entry[slot] then return end
  entry[slot] = nil
  K.tone(260, 0.04, 0.12, "sine")
end

local function undo()
  if state ~= "play" or F.modal() then return end
  while #entryLog > 0 do
    local i = table.remove(entryLog)
    if entry[i] and not locked[i] then
      entry[i] = nil
      slot = i
      K.tone(500, 0.04, 0.14, "triangle")
      saveGame()
      return
    end
  end
  K.tone(160, 0.05, 0.12, "square")
end

local function finish(won)
  state = won and "won" or "lost"
  endT = sys.time()
  local s = st()
  s.played = s.played + 1
  if won then
    s.wins = s.wins + 1
    s.dist[#rows] = s.dist[#rows] + 1
  end
  s.hints = s.hints + hints
  saveStats()
  saveGame()
  if won then
    F.winSound()
    K.rumble(0.5, 90)
    timer.after(0.4, function() F.celebrate(fx, L.x, L.y, L.w, L.rowH * 4) end)
  else
    F.loseSound()
    K.rumble(0.6, 140)
  end
  timer.after(1.4, function() if state ~= "play" and F.scene == "play" then F.open("over") end end)
end

local function submit()
  if state ~= "play" or F.modal() then return end
  for i = 1, pegs do
    if not entry[i] then
      shakeT = sys.time()
      slot = i
      K.tone(150, 0.08, 0.15, "square")
      K.toast(TR("fill_all"))
      return
    end
  end
  if not dupes then
    local seen = {}
    for i = 1, pegs do
      if seen[entry[i]] then
        shakeT = sys.time()
        K.tone(150, 0.08, 0.15, "square")
        K.toast(TR("no_dupes"))
        return
      end
      seen[entry[i]] = true
    end
  end
  local g = {}
  for i = 1, pegs do g[i] = entry[i] end
  local b, w = score(g)
  rows[#rows + 1] = {guess = g, black = b, white = w, t = sys.time()}
  for k = 1, b + w do
    timer.after(0.12 * k, function() K.tone(k <= b and 880 or 660, 0.05, 0.16, "sine") end)
  end
  entry, entryLog = {}, {}
  for i = 1, pegs do if locked[i] then entry[i] = locked[i] end end
  slot = nextFree(1)
  if b == pegs then finish(true)
  elseif #rows >= TRIES then finish(false)
  else saveGame() end
end

local function hint()
  if state ~= "play" or F.modal() then return end
  local free = {}
  for i = 1, pegs do if not locked[i] then free[#free + 1] = i end end
  if #free <= 1 then K.toast(TR("no_more_hints")); return end
  local i = free[random(#free)]
  locked[i] = secret[i]
  entry[i] = secret[i]
  hints = hints + 1
  F.chord({660, 880, 1100}, 0.2, 0.2, "sine")
  slot = nextFree(slot)
  saveGame()
end

local function setDiff(d)
  d = K.clamp(d, 1, #DIFFS)
  if d == diff then return end
  diff = d
  saveStats()
  newGame()
end

local function setDupes(v)
  if v == dupes then return end
  dupes = v
  saveStats()
  newGame()
end

local function askNew()
  if state == "play" and (#rows > 0 or next(entry) ~= nil) then F.open("confirm") else newGame() end
end

-- ------------------------------------------------------------------ app
function app.load()
  K.loadPrefs()
  local s = store.get("stats", {})
  stats = type(s) == "table" and s or {}
  diff = K.clamp(floor(tonumber(store.get("diff", 1)) or 1), 1, #DIFFS)
  dupes = store.get("dupes", true) ~= false
  if not loadGame() then newGame() end
  F.open("title")
end

function app.update(dt)
  fx:update(dt)
  local d = F.stick(dt)
  if d and F.scene == "play" and state == "play" then
    if d == "left" then slot = (slot - 2) % pegs + 1
    elseif d == "right" then slot = slot % pegs + 1
    elseif d == "up" then cycle(1)
    elseif d == "down" then cycle(-1) end
  end
end

-- ------------------------------------------------------------------ drawing
local function drawPeg(cx, cy, r, c, alpha)
  if not c then
    gfx.circle(cx, cy, r * 0.42, K.col(theme.text, 0.14))
    return
  end
  local col = COLORS[c]
  gfx.alpha(alpha or 1)
  gfx.circle(cx, cy + r * 0.12, r, K.col("#000000", 0.18))
  gfx.circle(cx, cy, r, col)
  gfx.circle(cx - r * 0.3, cy - r * 0.32, r * 0.3, K.col("#FFFFFF", 0.45))
  gfx.color(c == 3 and "#5D4300" or K.col("#FFFFFF", 0.85))
  gfx.text(tostring(c), cx - r, cy - gfx.textHeight(r * 0.8, "bold") / 2 + r * 0.1, r * 0.8, "bold", "center", r * 2)
  gfx.unalpha()
end

local function drawFeedback(x, y, size, b, w, t, now)
  local per = pegs == 4 and 2 or 3
  local s = size / per
  for k = 1, pegs do
    local cx = x + ((k - 1) % per) * s + s / 2
    local cy = y + ((k - 1) // per) * s + s / 2
    local show = now - t > 0.12 * k
    if k <= b + w and show then
      local black = k <= b
      gfx.circle(cx, cy, s * 0.32, black and (theme.dark and "#F5F5F5" or "#1C1C1E") or theme.window)
      gfx.color(K.col(theme.text, 0.6))
      gfx.circleLine(cx, cy, s * 0.32, 1.5)
      if black then gfx.circle(cx, cy, s * 0.12, theme.dark and "#1C1C1E" or "#F5F5F5") end
    else
      gfx.circle(cx, cy, s * 0.14, K.col(theme.text, 0.15))
    end
  end
end

local function drawBoard(w, h, now)
  local rowH, peg = L.rowH, L.peg
  local x0, y0 = L.x, L.y
  local bw = L.w
  gfx.shadow(x0, y0, bw, rowH * (TRIES + 1) + 12, 14, 18, 4)
  gfx.rect(x0, y0, bw, rowH * (TRIES + 1) + 12, 14, theme.dark and "#2A2522" or "#E9DCCB")
  -- secret row
  local sy = y0 + 6
  gfx.rect(x0 + 6, sy, bw - 12, rowH - 4, 10, theme.dark and "#1C1916" or "#D6C4AC")
  local reveal = state ~= "play"
  for i = 1, pegs do
    local cx = x0 + 40 + (i - 0.5) * peg * 2.4
    local cy = sy + (rowH - 4) / 2
    if reveal then
      local p = K.easeOutBack((now - endT - i * 0.12) / 0.3)
      if p > 0 then drawPeg(cx, cy, peg * 0.9 * p, secret[i]) end
    elseif locked[i] then
      drawPeg(cx, cy, peg * 0.9, secret[i], 0.85)
    else
      gfx.circle(cx, cy, peg * 0.9, K.col(theme.text, 0.18))
      gfx.color(K.col(theme.text, 0.5))
      gfx.text("?", cx - peg, cy - gfx.textHeight(peg, "bold") / 2, peg, "bold", "center", peg * 2)
    end
  end
  gfx.icon(reveal and "lock_open" or "lock", x0 + 22, sy + (rowH - 4) / 2, peg * 1.1, theme.text2)
  -- guess rows: row 1 at the bottom (classic board)
  local cr = #rows + 1
  for r = 1, TRIES do
    local y = y0 + 6 + rowH * (TRIES - r + 1) + 2
    local isCur = r == cr and state == "play"
    if isCur then
      local sx = 0
      if now - shakeT < 0.35 then sx = sin((now - shakeT) * 60) * 6 * (1 - (now - shakeT) / 0.35) end
      gfx.push(sx, 0)
      gfx.rect(x0 + 6, y, bw - 12, rowH - 4, 10, K.col(theme.accent, 0.14))
    end
    gfx.color(isCur and theme.accent or theme.text3)
    gfx.text(tostring(r), x0 + 6, y + (rowH - 4 - gfx.textHeight(12, "semibold")) / 2, 12, "semibold", "center", 32)
    for i = 1, pegs do
      local cx = x0 + 40 + (i - 0.5) * peg * 2.4
      local cy = y + (rowH - 4) / 2
      if r <= #rows then
        local p = K.easeOutBack((now - rows[r].t + i * 0.0) / 0.25)
        drawPeg(cx, cy, peg * min(1, max(0.01, p)), rows[r].guess[i])
      elseif isCur then
        drawPeg(cx, cy, peg, entry[i], locked[i] and 0.9 or 1)
        if locked[i] then gfx.icon("lock", cx + peg * 0.8, cy - peg * 0.8, peg * 0.6, theme.yellow) end
        if i == slot and not F.modal() then
          local pulse = 0.6 + 0.4 * sin(now * 6)
          gfx.color(K.col(theme.accent, pulse))
          gfx.circleLine(cx, cy, peg + 4, 3)
        end
      else
        drawPeg(cx, cy, peg, nil)
      end
    end
    local fbs = rowH - 10
    local fx0 = x0 + bw - fbs - 14
    if r <= #rows then drawFeedback(fx0, y + 3, fbs, rows[r].black, rows[r].white, rows[r].t, now)
    elseif isCur then
      local full = true
      for i = 1, pegs do if not entry[i] then full = false end end
      if ui.iconButton("check", fx0 - 4, y + 2, fbs + 8, rowH - 8, full and theme.green or nil, false, "submit") and not F.modal() then
        submit()
      end
    end
    if isCur then gfx.pop() end
  end
end

local function drawPalette(w, now)
  local n = ncol
  local s = L.palS
  local x = L.palX
  for c = 1, n do
    local cx = x + (c - 1) * (s + 8) + s / 2
    local cy = L.palY + s / 2
    local hit = ui.hit("pal" .. c, cx - s / 2, L.palY, s, s)
    local r = s * 0.4 * (hit.held and 0.9 or (hit.hovered and 1.06 or 1))
    drawPeg(cx, cy, r, c)
    if hit.clicked and not F.modal() then K.lastInput = "pointer"; setColor(c) end
  end
end

local function drawHints(w, y)
  if K.lastInput == "pad" then
    K.hints({{{"dpad"}, TR("h_slot_color")}, {"A", TR("h_check")}, {"X", TR("h_clear")}, {"B", TR("h_undo")},
             {"Y", TR("h_hint")}, {"+", TR("h_pause")}}, 0, y, w)
  elseif K.lastInput == "key" then
    K.hints({{"1-" .. ncol, TR("h_color")}, {TR("k_arrows"), TR("h_slot_color")}, {"Enter", TR("h_check")},
             {"Backspace", TR("h_undo")}, {"H", TR("h_hint")}, {"Esc", TR("h_pause")}}, 0, y, w)
  else
    K.hints({{"touch", TR("h_tap_palette")}}, 0, y, w)
  end
end

local function distLines()
  local s = st()
  local avg, n = 0, 0
  for i = 1, TRIES do avg = avg + i * s.dist[i]; n = n + s.dist[i] end
  return {{TR("played"), tostring(s.played)},
          {TR("win_rate"), s.played > 0 and (floor(s.wins / s.played * 100 + 0.5) .. "%") or "—"},
          {TR("avg_tries"), n > 0 and string.format("%.1f", avg / n) or "—"},
          {TR("hints_used"), tostring(s.hints)}}
end

local function drawDist(x, y, w)
  local s = st()
  local mx = 1
  for i = 1, TRIES do mx = max(mx, s.dist[i]) end
  local bh = 13
  for i = 1, TRIES do
    local yy = y + (i - 1) * (bh + 3)
    gfx.color(theme.text2)
    gfx.text(tostring(i), x, yy - 1, 11, "semibold", "right", 16)
    local bw = max(18, (w - 30) * s.dist[i] / mx)
    gfx.rect(x + 22, yy, bw, bh, 4, s.dist[i] > 0 and theme.green or K.col(theme.text, 0.15))
    gfx.color("#FFFFFF")
    gfx.text(tostring(s.dist[i]), x + 22, yy, 10, "bold", "right", bw - 4)
  end
end

local function drawDialogs(w, h)
  local s = F.scene
  if s == "pause" then
    F.pauseDialog(w, h, {onRestart = newGame, onMenu = function() F.open("title") end})
  elseif s == "over" then
    local won = state == "won"
    K.dialog(F.dlg, w, h, {icon = won and "emoji_events" or "lock", iconColor = won and theme.yellow or theme.red,
      title = won and TR("cracked") or TR("not_cracked"),
      subtitle = won and TR("cracked_in", #rows) or TR("secret_was"), extraH = won and 0 or 44,
      extra = (not won) and function(x, y, ww)
        for i = 1, pegs do drawPeg(x + ww / 2 + (i - (pegs + 1) / 2) * 40, y + 20, 15, secret[i]) end
      end or nil,
      lines = {{TR("win_rate"), distLines()[2][2]}},
      buttons = {{TR("play_again"), newGame, "primary", "replay"}, {TR("close"), F.close}}})
  elseif s == "stats" then
    K.dialog(F.dlg, w, h, {icon = "bar_chart", title = TR("stats_title"), subtitle = TR(diff == 1 and "classic" or "hard"),
      width = 340, lines = distLines(), extraH = TRIES * 16 + 8, extra = drawDist,
      buttons = {{TR("close"), F.close}, {TR("reset_stats"), function() F.open("reset", 2) end, "destructive"}}})
  else
    F.commonDialogs(w, h, {stats = distLines, onReset = function() stats = {}; saveStats() end, onNew = newGame})
  end
end

local function drawTitle(w, h)
  F.titleScreen(w, h, {icon = "password", c1 = "#B39DDB", c2 = "#5E35B1", title = TR("title"), subtitle = TR("tagline"),
    extraH = 88,
    extra = function(x, y, bw)
      local nd = ui.segmented("tdiff", {TR("classic"), TR("hard")}, diff, x, y, bw, 32)
      if nd ~= diff and F.scene == "title" then setDiff(nd); F.open("title") end
      local nu = ui.segmented("tdup", {TR("dupes_on"), TR("dupes_off")}, dupes and 1 or 2, x, y + 42, bw, 32)
      if nu ~= (dupes and 1 or 2) and F.scene == "title" then setDupes(nu == 1); F.open("title") end
    end,
    buttons = {{(state == "play" and #rows > 0) and TR("continue") or TR("play"), function()
                  if state ~= "play" then newGame() else F.play() end
                end, "primary", "play_arrow"},
               {TR("new_game"), newGame, "default", "refresh"},
               {TR("how_to"), function() F.open("help") end, "default", "help"},
               {TR("stats_title"), function() F.open("stats") end, "default", "bar_chart"}},
    footer = TR("title_footer", pegs, ncol)})
  if F.scene == "help" then
    K.dialog(F.dlg, w, h, {icon = "help", title = TR("how_to"), subtitle = TR("help_text", pegs, ncol, TRIES), width = 380,
      buttons = {{TR("close"), function() F.open("title") end}}})
  end
end

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  if F.scene == "title" or F.scene == "help" or (F.scene ~= "play" and F.returnTo == "title") then
    drawTitle(w, h)
    if F.scene ~= "title" and F.scene ~= "help" then drawDialogs(w, h) end
    return
  end
  F.title(TR("title"), TR("tries_left", TRIES - #rows), 16, 10)
  local hit = F.toolbar({{"pause", "pause"}, F.soundItem(), {"refresh", "new"}, {"lightbulb", "hint"},
                         {"backspace", "undo"}}, w - 16, 14)
  if hit == "sound" then K.setMuted(not K.muted)
  elseif hit == "pause" then F.open("pause")
  elseif hit == "new" then askNew()
  elseif hit == "hint" then hint()
  elseif hit == "undo" then undo() end
  -- layout
  local top = 62
  local palH = min(56, (w - 32) / ncol - 8)
  local bottom = h - 36 - palH - 16
  local rowH = floor(min(46, (bottom - top - 12) / (TRIES + 1)))
  local peg = rowH * 0.34
  local bw = min(w - 32, 40 + pegs * peg * 2.4 + rowH + 40)
  L.rowH, L.peg, L.w = rowH, peg, bw
  L.x = floor((w - bw) / 2)
  L.y = top
  L.palS = palH
  L.palX = floor((w - (ncol * (palH + 8) - 8)) / 2)
  L.palY = top + rowH * (TRIES + 1) + 24
  drawBoard(w, h, now)
  drawPalette(w, now)
  fx:draw()
  drawHints(w, h - 28)
  drawDialogs(w, h)
  K.drawToast(w, h - 90)
end

-- ------------------------------------------------------------------ input
function app.event(e)
  K.track(e)
  local t = e.type
  if F.scene == "help" then
    if t == "paddown" or t == "keydown" or t == "mouseup" then
      if (t == "paddown" and (e.pad == "a" or e.pad == "b")) or (t == "keydown" and (e.key == "enter" or e.key == "escape")) then
        F.open("title")
      end
    end
    return
  end
  if F.modal() then F.dialogEvent(e); return end
  if t == "paddown" then
    local p = e.pad
    if state ~= "play" then
      if p == "a" then F.open("over") elseif p == "x" or p == "minus" then newGame() elseif p == "plus" then F.open("pause") end
      return
    end
    if p == "left" then slot = (slot - 2) % pegs + 1; K.tone(1000, 0.015, 0.06)
    elseif p == "right" then slot = slot % pegs + 1; K.tone(1000, 0.015, 0.06)
    elseif p == "up" then cycle(1)
    elseif p == "down" then cycle(-1)
    elseif p == "a" then submit()
    elseif p == "x" then clearSlot()
    elseif p == "b" then undo()
    elseif p == "y" then hint()
    elseif p == "minus" then askNew()
    elseif p == "plus" then F.open("pause") end
  elseif t == "keydown" then
    local k = e.key
    if state ~= "play" then
      if k == "enter" or k == "space" then F.open("over") elseif k == "n" then newGame() elseif k == "escape" then F.open("pause") end
      return
    end
    local n = tonumber(k)
    if n and n >= 1 and n <= ncol then setColor(n)
    elseif k == "left" then slot = (slot - 2) % pegs + 1
    elseif k == "right" then slot = slot % pegs + 1
    elseif k == "up" then cycle(1)
    elseif k == "down" then cycle(-1)
    elseif k == "enter" or k == "space" then submit()
    elseif k == "backspace" or k == "z" then undo()
    elseif k == "delete" then clearSlot()
    elseif k == "h" then hint()
    elseif k == "n" or k == "f2" then askNew()
    elseif k == "escape" or k == "p" then F.open("pause") end
  elseif t == "mousedown" then
    -- tap a slot of the current row to select it
    if state == "play" then
      local r = #rows + 1
      local y = L.y + 6 + L.rowH * (TRIES - r + 1) + 2
      if e.y >= y and e.y <= y + L.rowH then
        for i = 1, pegs do
          local cx = L.x + 40 + (i - 0.5) * L.peg * 2.4
          if math.abs(e.x - cx) < L.peg * 1.2 then
            if slot == i and entry[i] and not locked[i] then clearSlot() end
            slot = i
          end
        end
      end
    end
  end
end

function app.menu()
  return {{title = TR("menu_game"), items = {
    {label = TR("new_game"), id = 1, shortcut = "N"},
    {label = TR("undo"), id = 2, shortcut = "Z"},
    {label = TR("hint"), id = 3, shortcut = "H"},
    "-",
    {label = TR("classic"), id = 11, checked = diff == 1},
    {label = TR("hard"), id = 12, checked = diff == 2},
    {label = TR("dupes_on"), id = 13, checked = dupes},
    "-",
    {label = TR("sound"), id = 4, checked = not K.muted},
    {label = TR("stats_title"), id = 5},
  }}}
end

function app.onmenu(id)
  if id == 1 then askNew()
  elseif id == 2 then undo()
  elseif id == 3 then hint()
  elseif id == 4 then K.setMuted(not K.muted)
  elseif id == 5 then F.open("stats")
  elseif id == 11 or id == 12 then setDiff(id - 10)
  elseif id == 13 then setDupes(not dupes) end
end

function app.close()
  saveGame()
  saveStats()
  return true
end

return app
