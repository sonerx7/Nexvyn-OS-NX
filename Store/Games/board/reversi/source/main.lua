-- Reversi for Nexvyn OS: Othello rules on 8x8, computer opponent with three levels (alpha-beta spread over frames,
-- see ai.lua) or two players, legal-move dots, flip animation, hints, undo, statistics and a saved game.
local K = require("kit")
local F = require("frame")
local R = require("ai")
local app = {}

local floor, max, min, abs, sin, cos, pi = math.floor, math.max, math.min, math.abs, math.sin, math.cos, math.pi

local LEVELS = {{depth = 1, time = 0.5, noise = 40}, {depth = 3, time = 1.2}, {depth = 8, time = 2.2}}
local MODE_KEYS = {"easy", "medium", "hard", "pvp"}
local FLIP = 0.3

local board = R.new()
local turn = 1
local mode = 2
local humanSide = 1
local history = {}            -- move indices, 0 = pass
local legal, nLegal = {}, 0
local legalSet = {}
local result = nil            -- {winner, b, w, t}
local cur = {x = 4, y = 3}
local anim = {}               -- anim[i] = {t0, from}
local lastMove = nil
local showDots = true
local aiCo, aiFor, aiAt = nil, nil, nil
local hintIdx, hintT = nil, -10
local stats = {}
local fx = K.particles()
local B = {x = 0, y = 0, cs = 0}
local press = nil
local hover = nil

local function vsAI() return mode <= 3 end
local function isAiTurn() return vsAI() and not result and turn ~= humanSide end
local function statOf(m)
  local s = stats[MODE_KEYS[m]]
  if type(s) ~= "table" then s = {a = 0, b = 0, d = 0}; stats[MODE_KEYS[m]] = s end
  return s
end

local function refreshLegal()
  legal, nLegal = R.moves(board, turn, legal)
  legalSet = {}
  for k = 1, nLegal do legalSet[legal[k]] = true end
end

-- ------------------------------------------------------------------ persistence
local function saveAll()
  store.set("stats", stats)
  store.set("mode", mode)
  store.set("human", humanSide)
  store.set("dots", showDots)
  store.set("game", {history = history, mode = mode, human = humanSide, over = result ~= nil})
end

local function scheduleAi()
  aiCo = nil
  aiAt = isAiTurn() and (sys.time() + 0.5) or nil
end

local function startAi(purpose)
  local snapshot = R.copy(board)
  local side = turn
  local lv = purpose == "hint" and {depth = 4, time = 1.0} or LEVELS[mode]
  aiFor = purpose
  aiCo = coroutine.create(function() return R.search(snapshot, side, lv) end)
end

local function busy()
  local now = sys.time()
  for _, a in pairs(anim) do if now - a[1] < FLIP + 0.1 then return true end end
  return false
end

local function finishGame(silent)
  local x, y = R.count(board)
  local winner = x > y and 1 or (y > x and 2 or 0)
  result = {winner = winner, b = x, w = y, t = sys.time()}
  if silent then return end
  local s = statOf(mode)
  if winner == 0 then s.d = s.d + 1
  elseif (vsAI() and winner == humanSide) or (not vsAI() and winner == 1) then s.a = s.a + 1
  else s.b = s.b + 1 end
  saveAll()
  timer.after(0.6, function()
    if not result then return end
    if winner == 0 then F.chord({392, 494, 587}, 0.4, 0.25)
    elseif vsAI() and winner ~= humanSide then F.loseSound(); K.rumble(0.6, 120)
    else F.winSound(); K.rumble(0.5, 90); F.celebrate(fx, B.x, B.y, B.cs * 8, B.cs * 8) end
  end)
  timer.after(1.6, function() if result and F.scene == "play" then F.open("over") end end)
end

-- next player; handles passes and the end of the game
local function advance(silent)
  turn = 3 - turn
  refreshLegal()
  if nLegal == 0 then
    turn = 3 - turn
    refreshLegal()
    if nLegal == 0 then
      finishGame(silent)
      return
    end
    history[#history + 1] = 0
    if not silent then
      local who = (3 - turn) == 1 and TR("black") or TR("white")
      K.toast(TR("pass_msg", who), 2.0)
      K.tone(300, 0.1, 0.15, "sine")
    end
  end
end

local function newGame()
  board = R.new()
  turn, history, result, anim, lastMove = 1, {}, nil, {}, nil
  hintIdx = nil
  refreshLegal()
  local now = sys.time()
  for _, i in ipairs({28, 29, 36, 37}) do anim[i] = {now, 0, pop = true} end
  F.play()
  scheduleAi()
  saveAll()
end

local function play(i)
  if result or not legalSet[i] then return false end
  local now = sys.time()
  local p = turn
  local flipped = R.play(board, i, p)
  anim[i] = {now, 0, pop = true}
  for k, j in ipairs(flipped) do
    local r1, c1 = (i - 1) // 8, (i - 1) % 8
    local r2, c2 = (j - 1) // 8, (j - 1) % 8
    local dist = max(abs(r1 - r2), abs(c1 - c2))
    anim[j] = {now + 0.06 * dist, 3 - p}
  end
  history[#history + 1] = i
  lastMove = i
  hintIdx = nil
  K.tone(p == 1 and 330 or 392, 0.06, 0.22, "triangle")
  for k = 1, min(6, #flipped) do
    timer.after(0.06 * k, function() K.tone(500 + k * 60, 0.03, 0.1, "sine") end)
  end
  K.rumble(0.15 + min(0.3, #flipped * 0.04), 20)
  advance(false)
  scheduleAi()
  saveAll()
  return true
end

local function humanPlay(i)
  if F.modal() or result or isAiTurn() or busy() then return end
  if not legalSet[i] then K.tone(150, 0.05, 0.12, "square"); return end
  play(i)
end

local function rebuild(list)
  board = R.new()
  turn, history, result, anim, lastMove = 1, {}, nil, {}, nil
  refreshLegal()
  for _, i in ipairs(list) do
    if i == 0 then
      -- passes are recreated by advance()
    elseif legalSet[i] then
      R.play(board, i, turn)
      history[#history + 1] = i
      lastMove = i
      advance(true)
      if result then break end
    end
  end
end

local function undo()
  if F.modal() then return end
  -- moves made by humans in this game (pass entries do not count)
  local real = {}
  for _, i in ipairs(history) do if i ~= 0 then real[#real + 1] = i end end
  if #real == 0 then K.tone(160, 0.05, 0.12, "square"); return end
  if result then
    local s = statOf(mode)
    local w = result.winner
    if w == 0 then s.d = max(0, s.d - 1)
    elseif (vsAI() and w == humanSide) or (not vsAI() and w == 1) then s.a = max(0, s.a - 1)
    else s.b = max(0, s.b - 1) end
  end
  -- remove moves until it is the human's turn again (vs computer) or one move (2 players)
  local n = #real
  repeat
    n = n - 1
    local list = {}
    for k = 1, n do list[k] = real[k] end
    rebuild(list)
  until not vsAI() or n == 0 or (turn == humanSide and not result)
  if vsAI() and turn ~= humanSide then
    -- the human plays white and only the computer's opening move is left
    rebuild({})
  end
  aiCo = nil
  hintIdx = nil
  K.tone(600, 0.05, 0.16, "triangle")
  scheduleAi()
  saveAll()
end

local function hint()
  if result or isAiTurn() or F.modal() or aiCo then return end
  startAi("hint")
end

local function setMode(m)
  m = K.clamp(m, 1, 4)
  if m == mode then return end
  mode = m
  newGame()
end

local function setHuman(s)
  if s == humanSide then return end
  humanSide = s
  newGame()
end

local function askNew()
  if #history > 0 and not result then F.open("confirm") else newGame() end
end

-- ------------------------------------------------------------------ app
function app.load()
  K.loadPrefs()
  local s = store.get("stats", {})
  stats = type(s) == "table" and s or {}
  mode = K.clamp(floor(tonumber(store.get("mode", 2)) or 2), 1, 4)
  humanSide = store.get("human", 1) == 2 and 2 or 1
  showDots = store.get("dots", true) ~= false
  local g = store.get("game")
  if type(g) == "table" and type(g.history) == "table" and not g.over and #g.history > 0 then
    mode = K.clamp(floor(tonumber(g.mode) or mode), 1, 4)
    humanSide = g.human == 2 and 2 or 1
    local list = {}
    for k, i in ipairs(g.history) do list[k] = K.clamp(floor(tonumber(i) or 0), 0, 64) end
    rebuild(list)
    if result then newGame() else scheduleAi() end
  else
    newGame()
  end
  F.open("title")
end

function app.update(dt)
  fx:update(dt)
  local now = sys.time()
  if aiAt and now >= aiAt and not F.modal() and not busy() then
    aiAt = nil
    if isAiTurn() then startAi("move") end
  end
  if aiCo and not F.modal() then
    R.sliceEnd = os.clock() + 0.010
    local ok, res = coroutine.resume(aiCo)
    if not ok then error(res) end
    if coroutine.status(aiCo) == "dead" then
      local purpose = aiFor
      aiCo, aiFor = nil, nil
      if purpose == "move" then
        if res and isAiTurn() and legalSet[res] then play(res) end
      elseif res then
        hintIdx, hintT = res, now
        cur.x, cur.y = (res - 1) % 8 + 1, (res - 1) // 8 + 1
        F.chord({660, 880}, 0.15, 0.2, "sine")
      end
    end
  end
  local d = F.stick(dt)
  if d and F.scene == "play" then F.moveCursor(cur, F.DIRV[d][1], F.DIRV[d][2], 8, 8, true) end
end

-- ------------------------------------------------------------------ drawing
local function discColors(p)
  if p == 1 then return "#2B2B2E", "#0E0E10" end
  return "#FFFFFF", "#D9D9DE"
end

local function drawDisc(cx, cy, r, p, sx, alpha)
  local c1, c2 = discColors(p)
  local w = r * sx
  gfx.alpha(alpha or 1)
  gfx.circle(cx + 1, cy + 2.5, r, K.col("#000000", 0.3))
  if sx > 0.98 then
    gfx.circle(cx, cy, r, c2)
    gfx.circle(cx, cy - r * 0.06, r * 0.9, c1)
    gfx.circle(cx - r * 0.3, cy - r * 0.35, r * 0.22, K.col("#FFFFFF", p == 1 and 0.18 or 0.6))
  else
    -- squeezed ellipse approximated by a rounded rect while flipping
    gfx.rect(cx - w, cy - r, w * 2, r * 2, w, c2)
    gfx.rect(cx - w * 0.9, cy - r * 0.96, w * 1.8, r * 1.8, w * 0.9, c1)
  end
  gfx.unalpha()
end

local function drawBoard(now)
  local cs = B.cs
  local s = cs * 8
  gfx.shadow(B.x - 10, B.y - 10, s + 20, s + 20, 14, 20, 5)
  gfx.rect(B.x - 10, B.y - 10, s + 20, s + 20, 14, theme.dark and "#3B2A1E" or "#6D4C33")
  gfx.gradient(B.x, B.y, s, s, "#2E9B57", "#1F7A43", false, 4)
  gfx.color(K.col("#000000", 0.35))
  for k = 1, 7 do
    gfx.line(B.x + k * cs, B.y, B.x + k * cs, B.y + s, 1.5)
    gfx.line(B.x, B.y + k * cs, B.x + s, B.y + k * cs, 1.5)
  end
  for _, pnt in ipairs({{2, 2}, {6, 2}, {2, 6}, {6, 6}}) do
    gfx.circle(B.x + pnt[1] * cs, B.y + pnt[2] * cs, max(2, cs * 0.06), K.col("#000000", 0.45))
  end
  local r = cs * 0.4
  for i = 1, 64 do
    local p = board[i]
    local cx = B.x + ((i - 1) % 8 + 0.5) * cs
    local cy = B.y + ((i - 1) // 8 + 0.5) * cs
    if p ~= 0 then
      local a = anim[i]
      if a then
        local k = (now - a[1]) / FLIP
        if a.pop then
          local sc = k < 0 and 0 or K.easeOutBack(min(1, k))
          drawDisc(cx, cy, r * sc, p, 1)
        elseif k < 0 then
          drawDisc(cx, cy, r, a[2], 1)
        elseif k < 1 then
          local sx = abs(cos(k * pi))
          drawDisc(cx, cy - sin(k * pi) * cs * 0.12, r, k < 0.5 and a[2] or p, sx)
        else
          drawDisc(cx, cy, r, p, 1)
        end
        if k >= 1.2 then anim[i] = nil end
      else
        drawDisc(cx, cy, r, p, 1)
      end
      if lastMove == i then gfx.circle(cx, cy, max(2, cs * 0.07), theme.red) end
    elseif legalSet[i] and not result and (showDots or hover == i) and not isAiTurn() then
      local c1 = discColors(turn)
      gfx.circle(cx, cy, cs * 0.12, K.col(c1, 0.45 + 0.1 * sin(now * 3 + i)))
      if hover == i then drawDisc(cx, cy, r, turn, 1, 0.45) end
    end
  end
  if hintIdx and now - hintT < 3 and not result then
    local cx = B.x + ((hintIdx - 1) % 8) * cs
    local cy = B.y + ((hintIdx - 1) // 8) * cs
    gfx.color(K.col(theme.yellow, 0.6 + 0.4 * sin(now * 8)))
    gfx.rectLine(cx + 2, cy + 2, cs - 4, cs - 4, 6, 4)
  end
  if not result and not F.modal() then
    K.ring(B.x + (cur.x - 1) * cs + 1, B.y + (cur.y - 1) * cs + 1, cs - 2, cs - 2, 6, "#FFFFFF", 3)
  end
  fx:draw()
end

local function modeName(m)
  return ({TR("mode_easy"), TR("mode_medium"), TR("mode_hard"), TR("mode_pvp")})[m]
end

local function statusText()
  if result then
    if result.winner == 0 then return TR("draw") end
    if vsAI() then return result.winner == humanSide and TR("you_win") or TR("cpu_wins") end
    return result.winner == 1 and TR("black_wins") or TR("white_wins")
  end
  if isAiTurn() then return TR("thinking") end
  if vsAI() then return TR("your_turn") end
  return turn == 1 and TR("black_turn") or TR("white_turn")
end

local function drawScore(w, y, now)
  local x, yy = R.count(board)
  local sw = min(150, floor((w - 48) / 2))
  local x0 = floor((w - sw * 2 - 12) / 2)
  for k = 1, 2 do
    local bx = x0 + (k - 1) * (sw + 12)
    local active = not result and turn == k
    gfx.rect(bx, y, sw, 46, 12, active and K.col(theme.accent, 0.16) or K.col(theme.text, 0.06))
    if active then
      gfx.color(theme.accent)
      gfx.rectLine(bx, y, sw, 46, 12, 2)
    end
    drawDisc(bx + 24, y + 23, 13, k, 1)
    local label = k == 1 and TR("black") or TR("white")
    if vsAI() then label = label .. " · " .. (k == humanSide and TR("you") or TR("cpu")) end
    gfx.color(theme.text2)
    gfx.text(label, bx + 44, y + 5, 11, "semibold")
    gfx.color(theme.text)
    gfx.text(tostring(k == 1 and x or yy), bx + 44, y + 19, 20, "bold")
    if active and isAiTurn() then ui.spinner(bx + sw - 18, y + 23, 7) end
  end
end

local function drawHints(w, y)
  if K.lastInput == "pad" then
    K.hints({{"dpad", TR("h_move")}, {"A", TR("h_place")}, {"B", TR("h_undo")}, {"Y", TR("h_hint")},
             {"X", TR("h_new")}, {"-", TR("h_dots")}, {"+", TR("h_pause")}}, 0, y, w)
  elseif K.lastInput == "key" then
    K.hints({{TR("k_arrows"), TR("h_move")}, {"Enter", TR("h_place")}, {"Z", TR("h_undo")}, {"H", TR("h_hint")},
             {"D", TR("h_dots")}, {"N", TR("h_new")}, {"Esc", TR("h_pause")}}, 0, y, w)
  else
    K.hints({{"touch", TR("h_tap_sq")}}, 0, y, w)
  end
end

local function drawDialogs(w, h)
  local s = F.scene
  if s == "pause" then
    F.pauseDialog(w, h, {onRestart = newGame, onMenu = function() F.open("title") end})
  elseif s == "over" then
    local icon, ic = "handshake", theme.text2
    if result and result.winner ~= 0 then
      if vsAI() and result.winner ~= humanSide then icon, ic = "smart_toy", theme.red else icon, ic = "emoji_events", theme.yellow end
    end
    local st = statOf(mode)
    K.dialog(F.dlg, w, h, {icon = icon, iconColor = ic, title = statusText(),
      subtitle = TR("final_score", result and result.b or 0, result and result.w or 0),
      lines = {{vsAI() and TR("you") or TR("black"), tostring(st.a)}, {TR("draws"), tostring(st.d)},
               {vsAI() and TR("cpu") or TR("white"), tostring(st.b)}},
      buttons = {{TR("play_again"), newGame, "primary", "replay"}, {TR("close"), F.close}}})
  else
    F.commonDialogs(w, h, {
      stats = function()
        local lines = {}
        for m = 1, 4 do
          local st = statOf(m)
          local total = st.a + st.b + st.d
          lines[#lines + 1] = {modeName(m), TR("stat_fmt", st.a, st.d, st.b) ..
            (m <= 3 and total > 0 and ("  (" .. floor(st.a / total * 100 + 0.5) .. "%)") or "")}
        end
        return lines
      end,
      onReset = function() stats = {}; saveAll() end,
      onNew = newGame,
    })
  end
end

local function drawTitle(w, h)
  F.titleScreen(w, h, {icon = "contrast", c1 = "#4CD964", c2 = "#1B7F3B", title = TR("title"), subtitle = TR("tagline"),
    extraH = 88,
    extra = function(x, y, bw)
      local nm = ui.segmented("tmode", {TR("mode_easy"), TR("mode_medium"), TR("mode_hard"), TR("mode_pvp")}, mode, x, y, bw, 32)
      if nm ~= mode and F.scene == "title" then setMode(nm); F.open("title") end
      if vsAI() then
        local ns = ui.segmented("tside", {TR("play_black"), TR("play_white")}, humanSide, x, y + 42, bw, 32)
        if ns ~= humanSide and F.scene == "title" then setHuman(ns); F.open("title") end
      end
    end,
    buttons = {{(#history > 0 and not result) and TR("continue") or TR("play"), function()
                  if result then newGame() else F.play(); scheduleAi() end
                end, "primary", "play_arrow"},
               {TR("new_game"), newGame, "default", "refresh"},
               {TR("stats_title"), function() F.open("stats") end, "default", "bar_chart"}}})
end

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  if F.scene == "title" or (F.scene ~= "play" and F.returnTo == "title") then
    drawTitle(w, h)
    if F.scene ~= "title" then drawDialogs(w, h) end
    return
  end
  F.title(TR("title"), modeName(mode) .. " · " .. statusText(), 16, 10)
  local hit = F.toolbar({{"pause", "pause"}, F.soundItem(), {"refresh", "new"},
                         {"scatter_plot", "dots", showDots and theme.accent or nil, showDots},
                         {"lightbulb", "hint"}, {"undo", "undo"}}, w - 16, 14)
  if hit == "sound" then K.setMuted(not K.muted)
  elseif hit == "pause" then F.open("pause")
  elseif hit == "new" then askNew()
  elseif hit == "dots" then showDots = not showDots; saveAll()
  elseif hit == "hint" then hint()
  elseif hit == "undo" then undo() end
  drawScore(w, 62, now)
  local top, bottom = 122, h - 36
  local cs = floor(min((w - 52) / 8, (bottom - top - 20) / 8))
  B.cs = cs
  B.x = floor((w - cs * 8) / 2)
  B.y = floor(top + 10 + (bottom - top - 20 - cs * 8) / 2)
  drawBoard(now)
  drawHints(w, h - 28)
  drawDialogs(w, h)
  K.drawToast(w, B.y + cs * 3.5)
end

-- ------------------------------------------------------------------ input
local function sqAt(x, y)
  if B.cs <= 0 then return nil end
  local c, r = floor((x - B.x) / B.cs), floor((y - B.y) / B.cs)
  if c < 0 or r < 0 or c > 7 or r > 7 then return nil end
  return r * 8 + c + 1
end

function app.event(e)
  K.track(e)
  local t = e.type
  if F.modal() then F.dialogEvent(e); return end
  if t == "paddown" then
    local p = e.pad
    local d = F.DIRV[p]
    if d then F.moveCursor(cur, d[1], d[2], 8, 8, true)
    elseif p == "a" then
      if result then F.open("over") else humanPlay((cur.y - 1) * 8 + cur.x) end
    elseif p == "b" then undo()
    elseif p == "y" then hint()
    elseif p == "x" then askNew()
    elseif p == "minus" then showDots = not showDots; saveAll()
    elseif p == "l" then setMode((mode - 2) % 4 + 1)
    elseif p == "r" then setMode(mode % 4 + 1)
    elseif p == "plus" then F.open("pause") end
  elseif t == "keydown" then
    local k = e.key
    local d = F.DIRV[k]
    hover = nil
    if d then F.moveCursor(cur, d[1], d[2], 8, 8, true)
    elseif k == "enter" or k == "space" then
      if result then F.open("over") else humanPlay((cur.y - 1) * 8 + cur.x) end
    elseif k == "z" or k == "backspace" then undo()
    elseif k == "h" then hint()
    elseif k == "d" then showDots = not showDots; saveAll()
    elseif k == "n" or k == "f2" then askNew()
    elseif k == "escape" or k == "p" then F.open("pause") end
  elseif t == "mousemove" then
    if not e.touch then hover = sqAt(e.x, e.y) end
  elseif t == "mousedown" then
    press = sqAt(e.x, e.y)
  elseif t == "mouseup" then
    local i = sqAt(e.x, e.y)
    if i and i == press and not e.cancel then
      cur.x, cur.y = (i - 1) % 8 + 1, (i - 1) // 8 + 1
      humanPlay(i)
    end
    press = nil
  end
end

function app.menu()
  local items = {{label = TR("new_game"), id = 1, shortcut = "N"},
                 {label = TR("undo"), id = 2, shortcut = "Z", enabled = #history > 0},
                 {label = TR("hint"), id = 3, shortcut = "H"},
                 {label = TR("show_moves"), id = 6, checked = showDots, shortcut = "D"}, "-"}
  for m = 1, 4 do items[#items + 1] = {label = modeName(m), id = 10 + m, checked = mode == m} end
  items[#items + 1] = "-"
  items[#items + 1] = {label = TR("play_black"), id = 21, checked = humanSide == 1, enabled = vsAI()}
  items[#items + 1] = {label = TR("play_white"), id = 22, checked = humanSide == 2, enabled = vsAI()}
  items[#items + 1] = "-"
  items[#items + 1] = {label = TR("sound"), id = 4, checked = not K.muted}
  items[#items + 1] = {label = TR("stats_title"), id = 5}
  return {{title = TR("menu_game"), items = items}}
end

function app.onmenu(id)
  if id == 1 then askNew()
  elseif id == 2 then undo()
  elseif id == 3 then hint()
  elseif id == 4 then K.setMuted(not K.muted)
  elseif id == 5 then F.open("stats")
  elseif id == 6 then showDots = not showDots; saveAll()
  elseif id > 10 and id <= 14 then setMode(id - 10)
  elseif id == 21 or id == 22 then setHuman(id - 20) end
end

function app.close()
  saveAll()
  return true
end

return app
