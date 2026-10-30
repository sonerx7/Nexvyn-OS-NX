-- XOX / Tic-Tac-Toe for Nexvyn OS: play an easy or an unbeatable (minimax) computer, or a friend.
local K = require("kit")
local F = require("frame")
local app = {}

local floor, max, min, sin, pi = math.floor, math.max, math.min, math.sin, math.pi
local random = math.random

local LINES = {{1, 2, 3}, {4, 5, 6}, {7, 8, 9}, {1, 4, 7}, {2, 5, 8}, {3, 6, 9}, {1, 5, 9}, {3, 5, 7}}
local MODES = {"easy", "hard", "pvp"}
local NUMPAD = {["7"] = 1, ["8"] = 2, ["9"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["1"] = 7, ["2"] = 8, ["3"] = 9}

local board = {}            -- [1..9] = "X" | "O" | nil
local placedAt = {}         -- animation start per cell
local turn = "X"
local mode = 2              -- index into MODES
local human = "X"           -- the human's mark against the computer
local history = {}
local result = nil          -- {winner = "X"|"O"|"D", line = {a,b,c}, t}
local cur = {x = 2, y = 2}
local aiAt = nil
local hintCell, hintT = nil, 0
local scores = {}           -- scores[mode] = {x, o, d}
local fx = K.particles()
local B = {x = 0, y = 0, s = 0}
local press = nil

local function scoreOf(m)
  local s = scores[MODES[m]]
  if type(s) ~= "table" then
    s = {x = 0, o = 0, d = 0}
    scores[MODES[m]] = s
  end
  return s
end

local function vsAI() return MODES[mode] ~= "pvp" end
local function aiMark() return human == "X" and "O" or "X" end
local function isAiTurn() return vsAI() and not result and turn == aiMark() end

-- ------------------------------------------------------------------ rules / AI
local function winnerOf(b)
  for _, l in ipairs(LINES) do
    local a = b[l[1]]
    if a and a == b[l[2]] and a == b[l[3]] then return a, l end
  end
  for i = 1, 9 do if not b[i] then return nil end end
  return "D"
end

local function minimax(b, side, me, alpha, beta, depth)
  local w = winnerOf(b)
  if w then
    if w == "D" then return 0 end
    return w == me and (10 - depth) or (depth - 10)
  end
  local other = side == "X" and "O" or "X"
  local maximizing = side == me
  local bestScore = maximizing and -100 or 100
  for i = 1, 9 do
    if not b[i] then
      b[i] = side
      local s = minimax(b, other, me, alpha, beta, depth + 1)
      b[i] = nil
      if maximizing then
        if s > bestScore then bestScore = s end
        if s > alpha then alpha = s end
      else
        if s < bestScore then bestScore = s end
        if s < beta then beta = s end
      end
      if beta <= alpha then break end
    end
  end
  return bestScore
end

-- best move for `side`; ties are broken randomly so games vary
local function bestMove(side)
  local other = side == "X" and "O" or "X"
  local bestS, list = -1000, {}
  for i = 1, 9 do
    if not board[i] then
      board[i] = side
      local s = minimax(board, other, side, -1000, 1000, 1)
      board[i] = nil
      if s > bestS then bestS, list = s, {i} elseif s == bestS then list[#list + 1] = i end
    end
  end
  if #list == 0 then return nil end
  return list[random(#list)]
end

local function easyMove(side)
  if random() < 0.35 then return bestMove(side) end
  local free = {}
  for i = 1, 9 do if not board[i] then free[#free + 1] = i end end
  if #free == 0 then return nil end
  return free[random(#free)]
end

-- ------------------------------------------------------------------ flow
local function saveAll()
  store.set("scores", scores)
  store.set("mode", mode)
  store.set("human", human)
end

local function scheduleAi()
  aiAt = isAiTurn() and (sys.time() + 0.45 + random() * 0.25) or nil
end

local function newGame()
  board, placedAt, history = {}, {}, {}
  turn = "X"
  result = nil
  hintCell = nil
  F.play()
  scheduleAi()
end

local function finish(w, line)
  result = {winner = w, line = line, t = sys.time()}
  local s = scoreOf(mode)
  if w == "X" then s.x = s.x + 1 elseif w == "O" then s.o = s.o + 1 else s.d = s.d + 1 end
  saveAll()
  if w == "D" then
    F.chord({440, 554, 659}, 0.4, 0.25)
  elseif vsAI() and w == aiMark() then
    F.loseSound()
    K.rumble(0.5, 90)
  else
    F.winSound()
    K.rumble(0.4, 60)
    timer.after(0.5, function() F.celebrate(fx, B.x, B.y, B.s, B.s) end)
  end
  timer.after(1.1, function()
    if result and F.scene == "play" then F.open("over") end
  end)
end

local function place(i)
  if result or board[i] then return false end
  board[i] = turn
  placedAt[i] = sys.time()
  history[#history + 1] = i
  hintCell = nil
  K.tone(turn == "X" and 520 or 390, 0.07, 0.22, "triangle")
  K.rumble(0.15, 15)
  local w, line = winnerOf(board)
  if w then finish(w, line) else turn = turn == "X" and "O" or "X" end
  scheduleAi()
  return true
end

local function humanPlace(i)
  if F.modal() or result or isAiTurn() then return end
  if board[i] then K.tone(160, 0.05, 0.12, "square"); return end
  place(i)
end

local function undo()
  local minLen = (vsAI() and human == "O") and 1 or 0
  if #history <= minLen or F.modal() then K.tone(160, 0.05, 0.12, "square"); return end
  if result then
    -- take the finished game's result back off the scoreboard
    local s = scoreOf(mode)
    local w = result.winner
    if w == "X" then s.x = max(0, s.x - 1) elseif w == "O" then s.o = max(0, s.o - 1) else s.d = max(0, s.d - 1) end
    result = nil
    saveAll()
  end
  repeat
    board[table.remove(history)] = nil
  until not vsAI() or #history <= minLen or ((#history % 2 == 0) == (human == "X"))
  turn = (#history % 2 == 0) and "X" or "O"
  hintCell = nil
  K.tone(600, 0.05, 0.16, "triangle")
  timer.after(0.05, function() K.tone(450, 0.06, 0.14, "triangle") end)
  scheduleAi()
end

local function hint()
  if result or isAiTurn() or F.modal() then return end
  hintCell = bestMove(turn)
  hintT = sys.time()
  if hintCell then
    cur.x, cur.y = (hintCell - 1) % 3 + 1, floor((hintCell - 1) / 3) + 1
    K.tone(880, 0.06, 0.18, "sine")
  end
end

local function setMode(m)
  if m == mode then return end
  mode = m
  saveAll()
  newGame()
  K.play("pop", 0.5)
end

local function setHuman(mk)
  if mk == human then return end
  human = mk
  saveAll()
  newGame()
  K.play("pop", 0.5)
end

local function askNew()
  if #history > 0 and not result then F.open("confirm") else newGame(); K.play("pop", 0.5) end
end

-- ------------------------------------------------------------------ app
function app.load()
  K.loadPrefs()
  local s = store.get("scores", {})
  scores = type(s) == "table" and s or {}
  mode = K.clamp(floor(tonumber(store.get("mode", 2)) or 2), 1, 3)
  human = store.get("human", "X") == "O" and "O" or "X"
  newGame()
  F.open("title")
end

function app.update(dt)
  fx:update(dt)
  if aiAt and sys.time() >= aiAt and not F.modal() then
    aiAt = nil
    if isAiTurn() then
      local m = MODES[mode] == "easy" and easyMove(turn) or bestMove(turn)
      if m then place(m) end
    end
  end
  local d = F.stick(dt)
  if d and not result then F.moveCursor(cur, F.DIRV[d][1], F.DIRV[d][2], 3, 3, true) end
end

-- ------------------------------------------------------------------ drawing
local function markColor(mk) return mk == "X" and theme.blue or theme.orange end

local function drawX(cx, cy, r, p, col, th)
  local a = K.easeOut(min(1, p * 2))
  local b = K.easeOut(max(0, p * 2 - 1))
  gfx.color(col)
  gfx.line(cx - r, cy - r, cx - r + 2 * r * a, cy - r + 2 * r * a, th)
  if b > 0 then gfx.line(cx + r, cy - r, cx + r - 2 * r * b, cy - r + 2 * r * b, th) end
  gfx.circle(cx - r, cy - r, th / 2, col)
  if a >= 1 then gfx.circle(cx + r, cy + r, th / 2, col) end
end

local function drawO(cx, cy, r, p, col, th)
  gfx.color(col)
  local e = K.easeOut(p)
  if e > 0.01 then gfx.arc(cx, cy, r, -pi / 2, -pi / 2 + 2 * pi * e, th) end
end

local function cellRect(i)
  local cs = B.s / 3
  return B.x + ((i - 1) % 3) * cs, B.y + floor((i - 1) / 3) * cs, cs
end

local function drawBoard(now)
  local s, cs = B.s, B.s / 3
  gfx.shadow(B.x, B.y, s, s, 18, 22, 5)
  gfx.rect(B.x, B.y, s, s, 18, theme.window)
  gfx.color(theme.separator)
  gfx.rectLine(B.x, B.y, s, s, 18, 1)
  local th = max(3, s * 0.014)
  gfx.color(K.col(theme.text, 0.18))
  for k = 1, 2 do
    gfx.line(B.x + cs * k, B.y + cs * 0.12, B.x + cs * k, B.y + s - cs * 0.12, th)
    gfx.line(B.x + cs * 0.12, B.y + cs * k, B.x + s - cs * 0.12, B.y + cs * k, th)
  end
  -- hover / hint
  if hintCell and now - hintT < 2.5 and not board[hintCell] then
    local x, y = cellRect(hintCell)
    local p = 0.5 + 0.5 * sin(now * 6)
    gfx.rect(x + 8, y + 8, cs - 16, cs - 16, 14, K.col(theme.green, 0.12 + 0.12 * p))
    gfx.alpha(0.35)
    if turn == "X" then drawX(x + cs / 2, y + cs / 2, cs * 0.26, 1, theme.green, cs * 0.09)
    else drawO(x + cs / 2, y + cs / 2, cs * 0.27, 1, theme.green, cs * 0.09) end
    gfx.unalpha()
  end
  local mth = cs * 0.1
  for i = 1, 9 do
    local mk = board[i]
    if mk then
      local x, y = cellRect(i)
      local p = min(1, (now - (placedAt[i] or 0)) / 0.28)
      local col = markColor(mk)
      if result and result.line and result.winner ~= "D" then
        local inLine = result.line[1] == i or result.line[2] == i or result.line[3] == i
        if not inLine then col = K.col(col, 0.35) end
      end
      if mk == "X" then drawX(x + cs / 2, y + cs / 2, cs * 0.26, p, col, mth)
      else drawO(x + cs / 2, y + cs / 2, cs * 0.27, p, col, mth) end
    end
  end
  -- winning line
  if result and result.line then
    local p = K.easeOut((now - result.t - 0.15) / 0.35)
    if p > 0 then
      local ax, ay = cellRect(result.line[1])
      local bx, by = cellRect(result.line[3])
      ax, ay, bx, by = ax + cs / 2, ay + cs / 2, bx + cs / 2, by + cs / 2
      local dx, dy = bx - ax, by - ay
      ax, ay = ax - dx * 0.12, ay - dy * 0.12
      bx, by = bx + dx * 0.12, by + dy * 0.12
      gfx.color(K.col(theme.text, 0.85))
      gfx.line(ax, ay, ax + (bx - ax) * p, ay + (by - ay) * p, mth * 0.55)
    end
  end
  -- cursor
  if not result and not F.modal() then
    local i = (cur.y - 1) * 3 + cur.x
    local x, y = cellRect(i)
    K.ring(x + 6, y + 6, cs - 12, cs - 12, 14, theme.accent, 3)
  end
  fx:draw()
end

local function statusText()
  if result then
    if result.winner == "D" then return TR("draw") end
    if vsAI() then return result.winner == human and TR("you_win") or TR("cpu_wins") end
    return TR("wins_mark", result.winner)
  end
  if vsAI() then return turn == human and TR("your_turn") or TR("thinking") end
  return TR("turn_mark", turn)
end

local function drawScores(w, y)
  local s = scoreOf(mode)
  local bw = min(120, floor((w - 48) / 3))
  local x0 = floor((w - bw * 3 - 16) / 2)
  local lx = vsAI() and (human == "X" and TR("you") or TR("cpu")) or "X"
  local lo = vsAI() and (human == "O" and TR("you") or TR("cpu")) or "O"
  K.stat(x0, y, bw, 50, "X · " .. lx, tostring(s.x), theme.blue)
  K.stat(x0 + bw + 8, y, bw, 50, TR("draws"), tostring(s.d))
  K.stat(x0 + 2 * (bw + 8), y, bw, 50, "O · " .. lo, tostring(s.o), theme.orange)
  if not result then
    local bx = turn == "X" and x0 or x0 + 2 * (bw + 8)
    gfx.color(markColor(turn))
    gfx.rectLine(bx - 2, y - 2, bw + 4, 54, 12, 2)
  end
end

local function drawHints(w, y)
  if K.lastInput == "pad" then
    K.hints({{"dpad", TR("h_move")}, {"A", TR("h_place")}, {"B", TR("h_undo")}, {"Y", TR("h_hint")},
             {"X", TR("h_new")}, {{"L", "R"}, TR("h_mode")}, {"+", TR("h_pause")}}, 0, y, w)
  elseif K.lastInput == "key" then
    K.hints({{TR("k_arrows"), TR("h_move")}, {"Enter", TR("h_place")}, {"1-9", TR("h_place")}, {"Z", TR("h_undo")},
             {"H", TR("h_hint")}, {"N", TR("h_new")}}, 0, y, w)
  else
    K.hints({{"touch", TR("h_tap_cell")}}, 0, y, w)
  end
end

local function drawTitle(w, h)
  local s = scoreOf(mode)
  F.titleScreen(w, h, {icon = "grid_3x3", c1 = "#FF8A80", c2 = "#E53935", title = TR("title"), subtitle = TR("tagline"),
    extraH = 92,
    extra = function(x, y, bw)
      local modes = {TR("mode_easy"), TR("mode_hard"), TR("mode_pvp")}
      local nm = ui.segmented("tmode", modes, mode, x, y, bw, 32)
      if nm ~= mode and F.scene == "title" then mode = nm; saveAll(); newGame(); F.open("title") end
      if vsAI() then
        local nh = ui.segmented("tmark", {TR("play_x"), TR("play_o")}, human == "X" and 1 or 2, x, y + 42, bw, 32)
        if nh ~= (human == "X" and 1 or 2) and F.scene == "title" then human = nh == 1 and "X" or "O"; saveAll(); newGame(); F.open("title") end
      end
    end,
    buttons = {{(#history > 0 and not result) and TR("continue") or TR("play"), function()
                  if result then newGame() else F.play(); scheduleAi() end
                end, "primary", "play_arrow"},
               {TR("new_game"), function() newGame(); K.play("pop", 0.5) end, "default", "refresh"},
               {TR("stats_title"), function() F.open("stats") end, "default", "bar_chart"}},
    footer = TR("score_line", s.x, s.d, s.o)})
end

local function drawDialogs(w, h)
  if F.scene == "pause" then
    F.pauseDialog(w, h, {onRestart = newGame, onMenu = function() F.open("title") end})
    return
  end
  if F.scene == "over" then
    local icon, col = "handshake", theme.text2
    if result and result.winner ~= "D" then
      if vsAI() and result.winner ~= human then icon, col = "smart_toy", theme.red
      else icon, col = "emoji_events", theme.yellow end
    end
    local s = scoreOf(mode)
    K.dialog(F.dlg, w, h, {icon = icon, iconColor = col, title = statusText(),
      lines = {{"X", tostring(s.x), theme.blue}, {TR("draws"), tostring(s.d)}, {"O", tostring(s.o), theme.orange}},
      buttons = {{TR("play_again"), function() newGame(); K.play("pop", 0.5) end},
                 {TR("close"), F.close}}})
    return
  end
  F.commonDialogs(w, h, {
    stats = function()
      local lines = {}
      for m = 1, 3 do
        local s = scoreOf(m)
        lines[#lines + 1] = {({TR("mode_easy"), TR("mode_hard"), TR("mode_pvp")})[m], TR("score_line", s.x, s.d, s.o)}
      end
      return lines
    end,
    onReset = function() scores = {}; saveAll() end,
    onNew = newGame,
  })
end

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  if F.scene == "title" or (F.scene ~= "play" and F.returnTo == "title") then
    drawTitle(w, h)
    if F.scene ~= "title" then drawDialogs(w, h) end
    return
  end
  F.title(TR("title"), statusText(), 16, 10)
  local hit = F.toolbar({{"pause", "pause"}, F.soundItem(), {"refresh", "new"}, {"lightbulb", "hint"},
                         {"undo", "undo"}}, w - 16, 14)
  if hit == "sound" then K.setMuted(not K.muted)
  elseif hit == "pause" then F.open("pause")
  elseif hit == "new" then askNew()
  elseif hit == "hint" then hint()
  elseif hit == "undo" then undo() end
  local y = 64
  local modes = {TR("mode_easy"), TR("mode_hard"), TR("mode_pvp")}
  local segW = min(420, w - 32 - (vsAI() and 120 or 0))
  local nm = ui.segmented("mode", modes, mode, 16, y, segW, 32)
  if nm ~= mode and not F.modal() then K.lastInput = "pointer"; setMode(nm) end
  if vsAI() then
    local nh = ui.segmented("mark", {"X", "O"}, human == "X" and 1 or 2, 16 + segW + 12, y, w - 44 - segW, 32)
    if nh ~= (human == "X" and 1 or 2) and not F.modal() then K.lastInput = "pointer"; setHuman(nh == 1 and "X" or "O") end
  end
  drawScores(w, y + 46)
  local top, bottom = y + 112, h - 36
  local s = floor(min(w - 32, bottom - top))
  B.s, B.x, B.y = s, floor((w - s) / 2), floor(top + (bottom - top - s) / 2)
  drawBoard(now)
  if isAiTurn() then
    gfx.icon("smart_toy", B.x + B.s - 18, B.y + 18, 20, K.col(theme.text2, 0.5 + 0.5 * sin(now * 5)))
  end
  drawHints(w, h - 28)
  drawDialogs(w, h)
end

-- ------------------------------------------------------------------ input
local function cellAt(x, y)
  if x < B.x or y < B.y or x >= B.x + B.s or y >= B.y + B.s then return nil end
  local cs = B.s / 3
  return floor((y - B.y) / cs) * 3 + floor((x - B.x) / cs) + 1
end

function app.event(e)
  K.track(e)
  local t = e.type
  if F.modal() then
    if F.scene == "over" and ((t == "paddown" and e.pad == "x") or (t == "keydown" and e.key == "n")) then
      newGame(); return
    end
    F.dialogEvent(e, function()
      if F.scene == "pause" then F.close() elseif F.scene ~= "title" then F.close() end
    end)
    return
  end
  if t == "paddown" then
    local p = e.pad
    local d = F.DIRV[p]
    if d then
      if not result then F.moveCursor(cur, d[1], d[2], 3, 3, true) end
    elseif p == "a" then
      if result then newGame() else humanPlace((cur.y - 1) * 3 + cur.x) end
    elseif p == "b" then undo()
    elseif p == "y" then hint()
    elseif p == "x" or p == "minus" then askNew()
    elseif p == "l" then setMode((mode - 2) % 3 + 1)
    elseif p == "r" then setMode(mode % 3 + 1)
    elseif p == "plus" then F.open("pause") end
  elseif t == "keydown" then
    local k = e.key
    local d = F.DIRV[k]
    if d then
      if not result then F.moveCursor(cur, d[1], d[2], 3, 3, true) end
    elseif k == "enter" or k == "space" then
      if result then newGame() else humanPlace((cur.y - 1) * 3 + cur.x) end
    elseif NUMPAD[k] then
      local i = NUMPAD[k]
      cur.x, cur.y = (i - 1) % 3 + 1, floor((i - 1) / 3) + 1
      humanPlace(i)
    elseif k == "z" or k == "backspace" then undo()
    elseif k == "h" then hint()
    elseif k == "n" or k == "f2" then askNew()
    elseif k == "escape" or k == "p" then F.open("pause") end
  elseif t == "mousedown" then
    press = cellAt(e.x, e.y)
  elseif t == "mouseup" then
    local i = cellAt(e.x, e.y)
    if i and i == press and not e.cancel then
      cur.x, cur.y = (i - 1) % 3 + 1, floor((i - 1) / 3) + 1
      if result then newGame() else humanPlace(i) end
    end
    press = nil
  end
end

function app.menu()
  return {{title = TR("menu_game"), items = {
    {label = TR("new_game"), id = 1, shortcut = "N"},
    {label = TR("undo"), id = 2, shortcut = "Z", enabled = #history > 0},
    {label = TR("hint"), id = 3, shortcut = "H"},
    "-",
    {label = TR("mode_easy"), id = 11, checked = mode == 1},
    {label = TR("mode_hard"), id = 12, checked = mode == 2},
    {label = TR("mode_pvp"), id = 13, checked = mode == 3},
    "-",
    {label = TR("play_x"), id = 21, checked = human == "X", enabled = vsAI()},
    {label = TR("play_o"), id = 22, checked = human == "O", enabled = vsAI()},
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
  elseif id >= 11 and id <= 13 then setMode(id - 10)
  elseif id == 21 then setHuman("X")
  elseif id == 22 then setHuman("O") end
end

function app.close()
  saveAll()
  return true
end

return app
