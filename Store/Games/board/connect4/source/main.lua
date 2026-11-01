-- Dört Bağla / Four in a Row for Nexvyn OS: drop discs, connect four. Computer opponent with four levels
-- (alpha-beta search spread over frames, see ai.lua) or two players, drop animation, hints, undo and statistics.
local K = require("kit")
local F = require("frame")
local A = require("ai")
local app = {}

local floor, max, min, abs, sin, sqrt = math.floor, math.max, math.min, math.abs, math.sin, math.sqrt
local COLS, ROWS = A.COLS, A.ROWS

local LEVELS = {{depth = 2, time = 0.6, noise = 60}, {depth = 4, time = 1.2}, {depth = 10, time = 2.2}, {depth = 16, time = 3.5}}
local MODE_KEYS = {"easy", "medium", "hard", "expert", "pvp"}
local P_COL = {"#E53935", "#FDD835"}

local board = A.new()
local turn = 1
local mode = 2               -- 1..3 = vs computer level, 4 = two players
local humanSide = 1
local history = {}           -- columns
local result = nil           -- {winner = 0|1|2, line, t}
local col = 4
local drops = {}             -- drops[cellIndex] = start time of its fall
local aiCo, aiFor, aiAt = nil, nil, nil
local hintCol, hintT = nil, -10
local stats = {}             -- stats[mode] = {a, b, d}  (a = red/human wins, b = yellow/computer wins)
local fx = K.particles()
local B = {x = 0, y = 0, cs = 0}
local hoverCol = nil

local function vsAI() return mode <= 4 end
local function aiSide() return 3 - humanSide end
local function isAiTurn() return vsAI() and not result and turn == aiSide() end
local function statOf(m)
  local s = stats[MODE_KEYS[m]]
  if type(s) ~= "table" then s = {a = 0, b = 0, d = 0}; stats[MODE_KEYS[m]] = s end
  return s
end

-- ------------------------------------------------------------------ persistence
local function saveAll()
  store.set("stats", stats)
  store.set("mode", mode)
  store.set("human", humanSide)
  store.set("modever", 2)
  store.set("game", {v2 = true, history = history, mode = mode, human = humanSide, over = result ~= nil})
end

local function dropTime(r)
  local fallRows = ROWS - r + 1.05
  return sqrt(2 * fallRows / 60)
end

local function busy()
  local now = sys.time()
  for i, t in pairs(drops) do
    local r = (i - 1) // COLS + 1
    if now - t < dropTime(r) + 0.22 then return true end
  end
  return false
end

local function startAi(purpose)
  local lv = purpose == "hint" and {depth = 6, time = 1.0} or LEVELS[mode]
  local snapshot = A.copy(board)
  local side = turn
  aiFor = purpose
  aiCo = coroutine.create(function() return A.search(snapshot, side, lv) end)
end

local function scheduleAi()
  aiCo = nil
  aiAt = isAiTurn() and (sys.time() + 0.35) or nil
end

local function newGame()
  board = A.new()
  turn, history, result, drops = 1, {}, nil, {}
  hintCol = nil
  col = 4
  F.play()
  scheduleAi()
  saveAll()
end

local function finish(winner, line)
  result = {winner = winner, line = line, t = sys.time()}
  local s = statOf(mode)
  if winner == 0 then s.d = s.d + 1
  elseif (vsAI() and winner == humanSide) or (not vsAI() and winner == 1) then s.a = s.a + 1
  else s.b = s.b + 1 end
  saveAll()
  local delay = dropTime(line and ((line[1] - 1) // COLS + 1) or 1) + 0.2
  timer.after(delay, function()
    if not result then return end
    if winner == 0 then F.chord({392, 494, 587}, 0.4, 0.25)
    elseif vsAI() and winner ~= humanSide then F.loseSound(); K.rumble(0.6, 120)
    else
      F.winSound()
      K.rumble(0.5, 90)
      F.celebrate(fx, B.x, B.y, B.cs * COLS, B.cs * ROWS)
    end
  end)
  timer.after(delay + 1.2, function() if result and F.scene == "play" then F.open("over") end end)
end

local function play(c)
  if result or not A.canDrop(board, c) then return false end
  local r = A.drop(board, c, turn)
  local i = (r - 1) * COLS + c
  drops[i] = sys.time()
  history[#history + 1] = c
  hintCol = nil
  local p = turn
  timer.after(dropTime(r), function()
    K.tone(p == 1 and 300 or 360, 0.06, 0.25, "triangle")
    K.tone(120, 0.05, 0.2, "sine")
    K.rumble(0.2, 20)
  end)
  local line = A.winLine(board, c, r, p)
  if line then finish(p, line)
  elseif A.full(board) then finish(0, nil)
  else turn = 3 - turn end
  scheduleAi()
  saveAll()
  return true
end

local function humanPlay(c)
  if F.modal() or result or isAiTurn() or aiCo and aiFor == "move" then return end
  if not A.canDrop(board, c) then K.tone(150, 0.05, 0.12, "square"); return end
  play(c)
end

local function rebuild(list)
  board = A.new()
  turn, history, drops = 1, {}, {}
  for _, c in ipairs(list) do
    if A.canDrop(board, c) then
      A.drop(board, c, turn)
      history[#history + 1] = c
      turn = 3 - turn
    end
  end
end

local review = nil          -- {list, k, result} while stepping through a finished game
local function reviewTo(k)
  review.k = K.clamp(k, 0, #review.list)
  local sub = {}
  for i = 1, review.k do sub[i] = review.list[i] end
  rebuild(sub)
  result, aiCo, aiAt = nil, nil, nil
  K.tone(900, 0.02, 0.08, "sine")
end
local function startReview()
  if not result then return end
  local list = {}
  for i, mv in ipairs(history) do list[i] = mv end
  review = {list = list, k = #list, result = result}
  F.play()
  reviewTo(0)
end
local function endReview()
  if not review then return end
  local full, res = review.list, review.result
  review = nil
  rebuild(full)
  result, aiCo, aiAt = res, nil, nil
end

local function undo()
  if F.modal() then return end
  local minLen = (vsAI() and humanSide == 2) and 1 or 0
  if #history <= minLen then K.tone(160, 0.05, 0.12, "square"); return end
  if result then
    local s = statOf(mode)
    local w = result.winner
    if w == 0 then s.d = max(0, s.d - 1)
    elseif (vsAI() and w == humanSide) or (not vsAI() and w == 1) then s.a = max(0, s.a - 1)
    else s.b = max(0, s.b - 1) end
    result = nil
  end
  local list = {}
  for i = 1, #history do list[i] = history[i] end
  repeat
    table.remove(list)
  until not vsAI() or #list <= minLen or ((#list % 2 == 0) == (humanSide == 1))
  rebuild(list)
  aiCo = nil
  hintCol = nil
  K.tone(600, 0.05, 0.16, "triangle")
  timer.after(0.05, function() K.tone(450, 0.06, 0.14, "triangle") end)
  scheduleAi()
  saveAll()
end

local function hint()
  if result or isAiTurn() or F.modal() or aiCo then return end
  startAi("hint")
end

local function setMode(m)
  m = K.clamp(m, 1, 5)
  if m == mode then return end
  mode = m
  newGame()
  K.play("pop", 0.5)
end

local function setHuman(s)
  if s == humanSide then return end
  humanSide = s
  newGame()
  K.play("pop", 0.5)
end

local function askNew()
  if #history > 0 and not result then F.open("confirm") else newGame() end
end

-- ------------------------------------------------------------------ app
function app.load()
  K.loadPrefs()
  local s = store.get("stats", {})
  stats = type(s) == "table" and s or {}
  mode = K.clamp(floor(tonumber(store.get("mode", 2)) or 2), 1, 5)
  if (tonumber(store.get("modever", 1)) or 1) < 2 and mode == 4 then mode = 5 end
  humanSide = store.get("human", 1) == 2 and 2 or 1
  local g = store.get("game")
  if type(g) == "table" and type(g.history) == "table" and not g.over and #g.history > 0 then
    mode = K.clamp(floor(tonumber(g.mode) or mode), 1, 5)
    if not g.v2 and mode == 4 then mode = 5 end
    humanSide = g.human == 2 and 2 or 1
    local list = {}
    for i, c in ipairs(g.history) do list[i] = K.clamp(floor(tonumber(c) or 4), 1, COLS) end
    rebuild(list)
    result = nil
    scheduleAi()
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
    A.sliceEnd = os.clock() + 0.010
    local ok, res = coroutine.resume(aiCo)
    if not ok then error(res) end
    if coroutine.status(aiCo) == "dead" then
      local purpose = aiFor
      aiCo, aiFor = nil, nil
      if purpose == "move" then
        if res and isAiTurn() then col = res; play(res) end
      elseif res then
        hintCol, hintT, col = res, now, res
        F.chord({660, 880}, 0.15, 0.2, "sine")
      end
    end
  end
  local d = F.stick(dt)
  if d and F.scene == "play" then
    if d == "left" then col = (col - 2) % COLS + 1 elseif d == "right" then col = col % COLS + 1
    elseif d == "down" then humanPlay(col) end
  end
end

-- ------------------------------------------------------------------ drawing
local function drawDisc(cx, cy, r, p, alpha)
  local c = P_COL[p]
  gfx.alpha(alpha or 1)
  gfx.circle(cx, cy, r, K.mix(c, "#000000", 0.25))
  gfx.circle(cx, cy - r * 0.04, r * 0.92, c)
  gfx.color(K.col(K.mix(c, "#000000", 0.18), 1))
  gfx.circleLine(cx, cy, r * 0.62, max(1.5, r * 0.08))
  gfx.circle(cx - r * 0.35, cy - r * 0.38, r * 0.2, K.col("#FFFFFF", 0.35))
  gfx.unalpha()
end

local function cellCenter(c, r)
  return B.x + (c - 0.5) * B.cs, B.y + (ROWS - r + 0.5) * B.cs
end

local function drawBoard(now)
  local cs = B.cs
  local rad = cs * 0.38
  local bw, bh = cs * COLS, cs * ROWS
  -- column hover / cursor / ghost disc
  local showCol = hoverCol or col
  if not result and not F.modal() and not isAiTurn() then
    gfx.rect(B.x + (showCol - 1) * cs, B.y, cs, bh, cs * 0.2, K.col(theme.text, 0.06))
    local gx, gy = B.x + (showCol - 0.5) * cs, B.y - cs * 0.55
    drawDisc(gx, gy + sin(now * 4) * 3, rad, turn, A.canDrop(board, showCol) and 0.9 or 0.3)
    if K.lastInput ~= "pointer" then K.ring(B.x + (col - 1) * cs + 2, B.y - cs * 1.05, cs - 4, cs * 0.95, cs * 0.3) end
  end
  if hintCol and now - hintT < 3 and not result then
    gfx.color(K.col(theme.green, 0.6 + 0.4 * sin(now * 8)))
    gfx.rectLine(B.x + (hintCol - 1) * cs + 2, B.y + 2, cs - 4, bh - 4, cs * 0.25, 4)
    gfx.icon("arrow_downward", B.x + (hintCol - 0.5) * cs, B.y - cs * 1.2, cs * 0.5, theme.green)
  end
  -- board with holes, then the discs sitting in the holes
  local bc = theme.dark and "#1A47B8" or "#2563EB"
  gfx.shadow(B.x - cs * 0.12, B.y - cs * 0.12, bw + cs * 0.24, bh + cs * 0.24, cs * 0.25, 18, 5)
  gfx.gradient(B.x - cs * 0.12, B.y - cs * 0.12, bw + cs * 0.24, bh + cs * 0.24, K.mix(bc, "#FFFFFF", 0.12), bc, false, cs * 0.25)
  local holeCol = K.mix(theme.bg, "#000000", theme.dark and 0.25 or 0.08)
  for r = 1, ROWS do
    for c = 1, COLS do
      local cx, cy = cellCenter(c, r)
      gfx.circle(cx, cy + 1.5, cs * 0.41, K.col("#000000", 0.25))
      gfx.circle(cx, cy, cs * 0.4, holeCol)
    end
  end
  gfx.clip(B.x - cs * 0.5, B.y - cs * 1.2, bw + cs, bh + cs * 1.4)
  for r = 1, ROWS do
    for c = 1, COLS do
      local i = (r - 1) * COLS + c
      local p = board.cells[i]
      if p ~= 0 then
        local cx, cy = cellCenter(c, r)
        local t0 = drops[i]
        if t0 then
          local t = now - t0
          local tf = dropTime(r)
          if t < tf then
            cy = B.y - cs * 0.55 + 0.5 * 60 * cs * t * t
          elseif t < tf + 0.22 then
            local k = (t - tf) / 0.22
            cy = cy - abs(sin(k * math.pi)) * cs * 0.14 * (1 - k)
          else
            drops[i] = nil
          end
        end
        drawDisc(cx, cy, rad, p)
      end
    end
  end
  gfx.unclip()
  -- winning line
  if result and result.line then
    local p = (now - result.t - dropTime(1)) / 0.4
    if p > 0 then
      for k, i in ipairs(result.line) do
        local c, r = (i - 1) % COLS + 1, (i - 1) // COLS + 1
        local cx, cy = cellCenter(c, r)
        local a = min(1, p * 2 - k * 0.15)
        if a > 0 then
          gfx.color(K.col("#FFFFFF", (0.6 + 0.4 * sin(now * 6 + k)) * a))
          gfx.circleLine(cx, cy, rad * 0.8, 4)
        end
      end
    end
  end
  fx:draw()
end

local function statusText()
  if result then
    if result.winner == 0 then return TR("draw") end
    if vsAI() then return result.winner == humanSide and TR("you_win") or TR("cpu_wins") end
    return result.winner == 1 and TR("red_wins") or TR("yellow_wins")
  end
  if aiCo and aiFor == "move" or isAiTurn() then return TR("thinking") end
  if vsAI() then return TR("your_turn") end
  return turn == 1 and TR("red_turn") or TR("yellow_turn")
end

local function modeName(m)
  return ({TR("mode_easy"), TR("mode_medium"), TR("mode_hard"), TR("mode_expert"), TR("mode_pvp")})[m]
end

local function drawHints(w, y)
  if K.lastInput == "pad" then
    K.hints({{"dpad", TR("h_column")}, {"A", TR("h_drop")}, {"B", TR("h_undo")}, {"Y", TR("h_hint")},
             {"X", TR("h_new")}, {{"L", "R"}, TR("h_mode")}, {"+", TR("h_pause")}}, 0, y, w)
  elseif K.lastInput == "key" then
    K.hints({{"1-7", TR("h_drop")}, {TR("k_arrows"), TR("h_column")}, {"Enter", TR("h_drop")}, {"Z", TR("h_undo")},
             {"H", TR("h_hint")}, {"N", TR("h_new")}, {"Esc", TR("h_pause")}}, 0, y, w)
  else
    K.hints({{"touch", TR("h_tap_col")}}, 0, y, w)
  end
end

local function drawDialogs(w, h)
  local s = F.scene
  if s == "pause" then
    F.pauseDialog(w, h, {onRestart = newGame, onMenu = function() F.open("title") end})
  elseif s == "over" then
    local st = statOf(mode)
    local icon, ic = "handshake", theme.text2
    if result and result.winner ~= 0 then
      if vsAI() and result.winner ~= humanSide then icon, ic = "smart_toy", theme.red else icon, ic = "emoji_events", theme.yellow end
    end
    local la = vsAI() and TR("you") or TR("red")
    local lb = vsAI() and TR("cpu") or TR("yellow")
    K.dialog(F.dlg, w, h, {icon = icon, iconColor = ic, title = statusText(), subtitle = modeName(mode),
      lines = {{la, tostring(st.a)}, {TR("draws"), tostring(st.d)}, {lb, tostring(st.b)}},
      buttons = {{TR("play_again"), newGame, "primary", "replay"}, {TR("review"), startReview, "default", "history"},
                 {TR("close"), F.close}}})
  else
    F.commonDialogs(w, h, {
      stats = function()
        local lines = {}
        for m = 1, 5 do
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
  F.titleScreen(w, h, {icon = "radio_button_checked", c1 = "#FFD54F", c2 = "#F57C00", title = TR("title"),
    subtitle = TR("tagline"), extraH = 88,
    extra = function(x, y, bw)
      local nm = ui.segmented("tmode", {TR("mode_easy"), TR("mode_medium"), TR("mode_hard"), TR("mode_expert"), TR("mode_pvp")}, mode, x, y, bw, 32)
      if nm ~= mode and F.scene == "title" then setMode(nm); F.open("title") end
      if vsAI() then
        local ns = ui.segmented("tside", {TR("go_first"), TR("go_second")}, humanSide, x, y + 42, bw, 32)
        if ns ~= humanSide and F.scene == "title" then setHuman(ns); F.open("title") end
      end
    end,
    buttons = {{(#history > 0 and not result) and TR("continue") or TR("play"), function()
                  if result then newGame() else F.play(); scheduleAi() end
                end, "primary", "play_arrow"},
               {TR("new_game"), newGame, "default", "refresh"},
               {TR("stats_title"), function() F.open("stats") end, "default", "bar_chart"}}})
end

local function drawMain(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  if F.scene == "title" or (F.scene ~= "play" and F.returnTo == "title") then
    drawTitle(w, h)
    if F.scene ~= "title" then drawDialogs(w, h) end
    return
  end
  F.title(TR("title"), modeName(mode), 16, 10)
  local hit = F.toolbar({{"pause", "pause"}, F.soundItem(), {"refresh", "new"}, {"lightbulb", "hint"},
                         {"undo", "undo"}}, w - 16, 14)
  if review then hit = nil end
  if hit == "sound" then K.setMuted(not K.muted)
  elseif hit == "pause" then F.open("pause")
  elseif hit == "new" then askNew()
  elseif hit == "hint" then hint()
  elseif hit == "undo" then undo() end
  -- status pill
  local y = 64
  local txt = statusText()
  local tw = gfx.textWidth(txt, 15, "semibold") + 52
  local px = floor((w - tw) / 2)
  gfx.rect(px, y, tw, 34, 17, theme.control)
  gfx.color(theme.separator)
  gfx.rectLine(px, y, tw, 34, 17, 1)
  local pc = result and result.winner > 0 and result.winner or turn
  if not (result and result.winner == 0) then drawDisc(px + 20, y + 17, 10, pc) end
  gfx.color(theme.text)
  gfx.text(txt, px + 36, y + 8, 15, "semibold")
  if isAiTurn() or (aiCo and aiFor == "move") then ui.spinner(px + tw + 16, y + 17, 8) end
  local top, bottom = y + 50, h - 40
  local cs = floor(min((w - 40) / COLS, (bottom - top) / (ROWS + 1.1)))
  B.cs = cs
  B.x = floor((w - cs * COLS) / 2)
  B.y = floor(top + cs * 1.1 + (bottom - top - cs * (ROWS + 1.1)) / 2)
  drawBoard(now)
  drawHints(w, h - 28)
  drawDialogs(w, h)
end

-- ------------------------------------------------------------------ input
local function colAt(x, y)
  if B.cs <= 0 or y < B.y - B.cs * 1.2 or y > B.y + B.cs * ROWS then return nil end
  local c = floor((x - B.x) / B.cs) + 1
  if c < 1 or c > COLS then return nil end
  return c
end

function app.draw(w, h)
  drawMain(w, h)
  if not review then return end
  -- review bar: first / back / forward / last and done
  local bh = 52
  local y = h - bh - 6
  local bw = math.min(520, w - 24)
  local x = floor((w - bw) / 2)
  gfx.shadow(x, y, bw, bh, 14, 16, 4)
  gfx.rect(x, y, bw, bh, 14, theme.window)
  gfx.color(theme.separator)
  gfx.rectLine(x, y, bw, bh, 14, 1)
  local icons = {{"first_page", 0}, {"chevron_left", review.k - 1}, {"chevron_right", review.k + 1},
                 {"last_page", #review.list}}
  for i, ic in ipairs(icons) do
    if ui.iconButton(ic[1], x + 8 + (i - 1) * 46, y + 8, 40, 36, nil, false, "rv" .. i) then reviewTo(ic[2]) end
  end
  gfx.color(theme.text)
  gfx.text(TR("review_move", review.k, #review.list), x + 196, y + 16, 14, "semibold")
  if ui.button(TR("done") .. "##rv", x + bw - 108, y + 8, 100, 36, "primary") then endReview() end
end

function app.event(e)
  K.track(e)
  local t = e.type
  if review then
    local k = (t == "paddown" and e.pad) or (t == "keydown" and e.key) or nil
    if k == "left" or k == "l" then reviewTo(review.k - 1)
    elseif k == "right" or k == "r" then reviewTo(review.k + 1)
    elseif k == "up" or k == "home" or k == "zl" then reviewTo(0)
    elseif k == "down" or k == "end" or k == "zr" then reviewTo(#review.list)
    elseif k == "b" or k == "escape" or k == "a" or k == "enter" or k == "plus" then endReview() end
    return
  end
  if F.modal() then F.dialogEvent(e); return end
  if t == "paddown" then
    local p = e.pad
    if p == "left" then col = (col - 2) % COLS + 1; hoverCol = nil; K.tone(1000, 0.015, 0.06)
    elseif p == "right" then col = col % COLS + 1; hoverCol = nil; K.tone(1000, 0.015, 0.06)
    elseif p == "a" or p == "down" then
      if result then F.open("over") else humanPlay(col) end
    elseif p == "b" then undo()
    elseif p == "y" then hint()
    elseif p == "x" or p == "minus" then askNew()
    elseif p == "l" then setMode((mode - 2) % 5 + 1)
    elseif p == "r" then setMode(mode % 5 + 1)
    elseif p == "plus" then F.open("pause") end
  elseif t == "keydown" then
    local k = e.key
    local n = tonumber(k)
    hoverCol = nil
    if n and n >= 1 and n <= COLS then col = n; humanPlay(n)
    elseif k == "left" then col = (col - 2) % COLS + 1
    elseif k == "right" then col = col % COLS + 1
    elseif k == "enter" or k == "space" or k == "down" then
      if result then F.open("over") else humanPlay(col) end
    elseif k == "z" or k == "backspace" then undo()
    elseif k == "h" then hint()
    elseif k == "n" or k == "f2" then askNew()
    elseif k == "escape" or k == "p" then F.open("pause") end
  elseif t == "mousemove" then
    if not e.touch then hoverCol = colAt(e.x, e.y) end
  elseif t == "mousedown" then
    local c = colAt(e.x, e.y)
    if c then hoverCol = c end
  elseif t == "mouseup" then
    local c = colAt(e.x, e.y)
    if c and not e.cancel then
      col = c
      humanPlay(c)
    end
    if e.touch then hoverCol = nil end
  end
end

function app.menu()
  local items = {{label = TR("new_game"), id = 1, shortcut = "N"},
                 {label = TR("undo"), id = 2, shortcut = "Z", enabled = #history > 0},
                 {label = TR("hint"), id = 3, shortcut = "H"}, "-"}
  for m = 1, 5 do items[#items + 1] = {label = modeName(m), id = 10 + m, checked = mode == m} end
  items[#items + 1] = "-"
  items[#items + 1] = {label = TR("go_first"), id = 21, checked = humanSide == 1, enabled = vsAI()}
  items[#items + 1] = {label = TR("go_second"), id = 22, checked = humanSide == 2, enabled = vsAI()}
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
  elseif id > 10 and id <= 15 then setMode(id - 10)
  elseif id == 21 or id == 22 then setHuman(id - 20) end
end

function app.close()
  saveAll()
  return true
end

return app
