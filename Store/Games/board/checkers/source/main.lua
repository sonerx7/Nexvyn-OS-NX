-- Dama / Checkers for Nexvyn OS: English draughts (forced captures, multi-jumps, kings) against a three-level
-- computer (alpha-beta spread over frames, see engine.lua) or a friend, with hints, undo, statistics and a saved game.
local K = require("kit")
local F = require("frame")
local E = require("engine")
local app = {}

local floor, max, min, abs, sin, pi = math.floor, math.max, math.min, math.abs, math.sin, math.pi

local LEVELS = {{depth = 2, time = 0.6, noise = 40}, {depth = 4, time = 1.2}, {depth = 9, time = 2.2}}
local MODE_KEYS = {"easy", "medium", "hard", "pvp"}
local STEP = 0.17
local DRAW_PLIES = 80

local board = E.new()
local turn = 1
local mode = 2
local humanSide = 1
local history = {}           -- {m, rec, quiet}
local legal, mustCap = {}, false
local quiet = 0
local result = nil           -- {winner = 0|1|2, reason, t}
local sel, partial = nil, {}
local cur = {x = 1, y = 6}
local anim = nil             -- {m, v, capv, t0}
local lastMove = nil
local aiCo, aiFor, aiAt = nil, nil, nil
local hintMove, hintT = nil, -10
local stats = {}
local fx = K.particles()
local B = {x = 0, y = 0, cs = 0}
local press = nil

local function vsAI() return mode <= 3 end
local function isAiTurn() return vsAI() and not result and turn ~= humanSide end
local function statOf(m)
  local s = stats[MODE_KEYS[m]]
  if type(s) ~= "table" then s = {a = 0, b = 0, d = 0}; stats[MODE_KEYS[m]] = s end
  return s
end
local function sqRC(i) return (i - 1) // 8, (i - 1) % 8 end

-- the board is drawn from the human's side: in 2-player mode player 1 is at the bottom
local function flipped() return vsAI() and humanSide == 2 end
local function sqXY(i)
  local r, c = sqRC(i)
  if flipped() then r, c = 7 - r, 7 - c end
  return B.x + c * B.cs, B.y + r * B.cs
end

-- ------------------------------------------------------------------ persistence
local function saveAll()
  store.set("stats", stats)
  store.set("mode", mode)
  store.set("human", humanSide)
  local list = {}
  for k, h in ipairs(history) do list[k] = {h.m.from, h.m.path} end
  store.set("game", {moves = list, mode = mode, human = humanSide, over = result ~= nil})
end

local function refresh()
  legal, mustCap = E.moves(board, turn)
  sel, partial = nil, {}
end

local function scheduleAi()
  aiCo = nil
  aiAt = isAiTurn() and (sys.time() + 0.45) or nil
end

local function startAi(purpose)
  local snapshot = E.copy(board)
  local side = turn
  local lv = purpose == "hint" and {depth = 5, time = 1.0} or LEVELS[mode]
  aiFor = purpose
  aiCo = coroutine.create(function() return E.search(snapshot, side, lv) end)
end

local function finishGame(winner, reason, silent)
  result = {winner = winner, reason = reason, t = sys.time()}
  if silent then return end
  local s = statOf(mode)
  if winner == 0 then s.d = s.d + 1
  elseif (vsAI() and winner == humanSide) or (not vsAI() and winner == 1) then s.a = s.a + 1
  else s.b = s.b + 1 end
  saveAll()
  local delay = anim and (#anim.m.path * STEP + 0.2) or 0.2
  timer.after(delay, function()
    if not result then return end
    if winner == 0 then F.chord({392, 494, 587}, 0.4, 0.25)
    elseif vsAI() and winner ~= humanSide then F.loseSound(); K.rumble(0.6, 120)
    else F.winSound(); K.rumble(0.5, 90); F.celebrate(fx, B.x, B.y, B.cs * 8, B.cs * 8) end
  end)
  timer.after(delay + 1.2, function() if result and F.scene == "play" then F.open("over") end end)
end

local function commit(m, silent)
  local v = board[m.from]
  local rec = E.apply(board, m)
  history[#history + 1] = {m = m, rec = rec, quiet = quiet}
  if #m.caps > 0 or v <= 2 then quiet = 0 else quiet = quiet + 1 end
  lastMove = m
  hintMove = nil
  if not silent then
    anim = {m = m, v = v, capv = rec.capv, t0 = sys.time()}
    for k = 1, #m.path do
      timer.after((k - 1) * STEP, function()
        K.tone(#m.caps > 0 and 420 + k * 70 or 360, 0.06, 0.22, "triangle")
        if #m.caps > 0 then K.rumble(0.25, 25) end
      end)
    end
    if m.crown then
      timer.after(#m.path * STEP, function() F.chord({784, 988, 1175}, 0.3, 0.25) end)
    end
  end
  turn = 3 - turn
  refresh()
  if #legal == 0 then finishGame(3 - turn, "nomoves", silent)
  elseif quiet >= DRAW_PLIES then finishGame(0, "quiet", silent) end
end

local function newGame()
  board = E.new()
  turn, history, result, anim, lastMove, quiet = 1, {}, nil, nil, nil, 0
  hintMove = nil
  refresh()
  F.play()
  scheduleAi()
  saveAll()
end

local function busy() return anim ~= nil end

local function play(m)
  commit(m, false)
  scheduleAi()
  saveAll()
end

local function rebuild(list)
  board = E.new()
  turn, history, result, anim, lastMove, quiet = 1, {}, nil, nil, nil, 0
  refresh()
  for _, mv in ipairs(list) do
    local found = nil
    for _, m in ipairs(legal) do if E.same(m, mv) then found = m; break end end
    if not found or result then break end
    commit(found, true)
  end
end

local function undo()
  if F.modal() or busy() then return end
  if #history == 0 then K.tone(160, 0.05, 0.12, "square"); return end
  if vsAI() and humanSide == 2 and #history <= 1 then K.tone(160, 0.05, 0.12, "square"); return end
  if result then
    local s = statOf(mode)
    local w = result.winner
    if w == 0 then s.d = max(0, s.d - 1)
    elseif (vsAI() and w == humanSide) or (not vsAI() and w == 1) then s.a = max(0, s.a - 1)
    else s.b = max(0, s.b - 1) end
    result = nil
  end
  repeat
    local h = table.remove(history)
    E.undo(board, h.m, h.rec)
    quiet = h.quiet
    turn = 3 - turn
  until not vsAI() or #history == 0 or turn == humanSide
  lastMove = #history > 0 and history[#history].m or nil
  refresh()
  aiCo = nil
  hintMove = nil
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

-- ------------------------------------------------------------------ selection
local function candidates()
  local out = {}
  if not sel then return out end
  for _, m in ipairs(legal) do
    if m.from == sel and #m.path > #partial then
      local ok = true
      for k = 1, #partial do if m.path[k] ~= partial[k] then ok = false; break end end
      if ok then out[#out + 1] = m end
    end
  end
  return out
end

local function movable(i)
  for _, m in ipairs(legal) do if m.from == i then return true end end
  return false
end

local function clickSquare(i)
  if F.modal() or result or isAiTurn() or busy() then return end
  local v = board[i]
  if #partial == 0 and v ~= 0 and E.owner(v) == turn then
    if movable(i) then
      sel = (sel == i) and nil or i
      K.tone(880, 0.03, 0.12, "triangle")
    else
      sel = nil
      K.tone(150, 0.05, 0.12, "square")
      if mustCap then K.toast(TR("must_capture")) end
    end
    return
  end
  if not sel then return end
  local cands = candidates()
  local nextOk = false
  for _, m in ipairs(cands) do if m.path[#partial + 1] == i then nextOk = true; break end end
  if not nextOk then
    K.tone(150, 0.05, 0.12, "square")
    return
  end
  partial[#partial + 1] = i
  for _, m in ipairs(cands) do
    if #m.path == #partial and m.path[#partial] == i then
      local ok = true
      for k = 1, #partial do if m.path[k] ~= partial[k] then ok = false end end
      if ok then play(m); return end
    end
  end
  K.tone(700, 0.04, 0.15, "triangle")
end

local function cancelSel()
  if #partial > 0 then table.remove(partial) elseif sel then sel = nil else undo() end
end

-- ------------------------------------------------------------------ app
function app.load()
  K.loadPrefs()
  local s = store.get("stats", {})
  stats = type(s) == "table" and s or {}
  mode = K.clamp(floor(tonumber(store.get("mode", 2)) or 2), 1, 4)
  humanSide = store.get("human", 1) == 2 and 2 or 1
  local g = store.get("game")
  if type(g) == "table" and type(g.moves) == "table" and not g.over and #g.moves > 0 then
    mode = K.clamp(floor(tonumber(g.mode) or mode), 1, 4)
    humanSide = g.human == 2 and 2 or 1
    local list = {}
    for k, mv in ipairs(g.moves) do
      if type(mv) == "table" and type(mv[2]) == "table" then
        local path = {}
        for j, s2 in ipairs(mv[2]) do path[j] = floor(tonumber(s2) or 0) end
        list[k] = {from = floor(tonumber(mv[1]) or 0), path = path}
      end
    end
    rebuild(list)
    if result then newGame() else scheduleAi() end
  else
    newGame()
  end
  if flipped() then cur.x, cur.y = 2, 6 end
  F.open("title")
end

function app.update(dt)
  fx:update(dt)
  local now = sys.time()
  if anim and now - anim.t0 > #anim.m.path * STEP + 0.05 then
    for k, s in ipairs(anim.m.caps) do
      local x, y = sqXY(s)
      fx:burst(x + B.cs / 2, y + B.cs / 2, 10, E.owner(anim.capv[k]) == 1 and "#E53935" or "#555555", B.cs * 2, 0.4, 3, 0, 3)
    end
    anim = nil
  end
  if aiAt and now >= aiAt and not F.modal() and not busy() then
    aiAt = nil
    if isAiTurn() then startAi("move") end
  end
  if aiCo and not F.modal() then
    E.sliceEnd = os.clock() + 0.010
    local ok, res = coroutine.resume(aiCo)
    if not ok then error(res) end
    if coroutine.status(aiCo) == "dead" then
      local purpose = aiFor
      aiCo, aiFor = nil, nil
      if res then
        local found = nil
        for _, m in ipairs(legal) do if E.same(m, res) then found = m; break end end
        if found then
          if purpose == "move" then
            if isAiTurn() and not busy() then play(found) else scheduleAi() end
          else
            hintMove, hintT = found, now
            F.chord({660, 880}, 0.15, 0.2, "sine")
          end
        end
      end
    end
  end
  local d = F.stick(dt)
  if d and F.scene == "play" then F.moveCursor(cur, F.DIRV[d][1], F.DIRV[d][2], 8, 8, false) end
end

-- ------------------------------------------------------------------ drawing
local function pieceColors(owner)
  if owner == 1 then return "#E53935", "#9E1F1B" end
  return theme.dark and "#E8E8EC" or "#2B2B2E", theme.dark and "#A8A8B0" or "#0E0E10"
end

local function drawPiece(cx, cy, r, v, alpha, lift)
  local c1, c2 = pieceColors(E.owner(v))
  lift = lift or 0
  gfx.alpha(alpha or 1)
  gfx.circle(cx + 1, cy + 3 + lift * 0.5, r, K.col("#000000", 0.35))
  gfx.circle(cx, cy - lift, r, c2)
  gfx.circle(cx, cy - lift - r * 0.1, r * 0.92, c1)
  gfx.color(K.col("#000000", 0.18))
  gfx.circleLine(cx, cy - lift - r * 0.1, r * 0.66, max(1.5, r * 0.08))
  gfx.circle(cx - r * 0.32, cy - lift - r * 0.42, r * 0.18, K.col("#FFFFFF", 0.3))
  if E.isKing(v) then gfx.icon("workspace_premium", cx, cy - lift - r * 0.1, r * 1.05, "#FFD54F") end
  gfx.unalpha()
end

local function drawBoard(now)
  local cs = B.cs
  local s = cs * 8
  gfx.shadow(B.x - 10, B.y - 10, s + 20, s + 20, 14, 20, 5)
  gfx.rect(B.x - 10, B.y - 10, s + 20, s + 20, 14, theme.dark and "#3B2A1E" or "#6D4C33")
  local light, dark = "#F0D9B5", "#9C6B43"
  for i = 1, 64 do
    local r, c = sqRC(i)
    local x, y = sqXY(i)
    gfx.rect(x, y, cs, cs, 0, (r + c) % 2 == 1 and dark or light)
  end
  -- last move
  if lastMove and not anim then
    for _, s2 in ipairs({lastMove.from, lastMove.path[#lastMove.path]}) do
      local x, y = sqXY(s2)
      gfx.rect(x, y, cs, cs, 0, K.col("#FFEB3B", 0.28))
    end
  end
  local yourTurn = not result and not isAiTurn() and not busy()
  -- forced capture / movable pieces
  if yourTurn and not sel then
    for _, m in ipairs(legal) do
      if mustCap then
        local x, y = sqXY(m.from)
        gfx.color(K.col(theme.orange, 0.6 + 0.4 * sin(now * 5)))
        gfx.rectLine(x + 2, y + 2, cs - 4, cs - 4, 6, 3)
      end
    end
  end
  if sel then
    local x, y = sqXY(sel)
    gfx.rect(x, y, cs, cs, 0, K.col(theme.accent, 0.4))
    for _, m in ipairs(candidates()) do
      local tx, ty = sqXY(m.path[#partial + 1])
      gfx.circle(tx + cs / 2, ty + cs / 2, cs * 0.16, K.col(theme.green, 0.75 + 0.25 * sin(now * 5)))
    end
    for k, s2 in ipairs(partial) do
      local px, py = sqXY(s2)
      gfx.circleLine(px + cs / 2, py + cs / 2, cs * 0.3, 2)
    end
  end
  if hintMove and now - hintT < 3 and not result then
    local a = 0.6 + 0.4 * sin(now * 8)
    gfx.color(K.col(theme.yellow, a))
    local fx0, fy0 = sqXY(hintMove.from)
    gfx.rectLine(fx0 + 2, fy0 + 2, cs - 4, cs - 4, 6, 4)
    local px, py = fx0, fy0
    for _, s2 in ipairs(hintMove.path) do
      local x, y = sqXY(s2)
      gfx.line(px + cs / 2, py + cs / 2, x + cs / 2, y + cs / 2, 4)
      px, py = x, y
    end
    gfx.circle(px + cs / 2, py + cs / 2, cs * 0.14, K.col(theme.yellow, a))
  end
  local r = cs * 0.38
  local animTo = anim and anim.m.path[#anim.m.path]
  for i = 1, 64 do
    local v = board[i]
    if v ~= 0 and i ~= animTo then
      local x, y = sqXY(i)
      local hidden = sel == i and #partial > 0
      drawPiece(x + cs / 2, y + cs / 2, r, v, hidden and 0.35 or 1, sel == i and 3 or 0)
    end
  end
  -- partial path ghost
  if sel and #partial > 0 then
    local x, y = sqXY(partial[#partial])
    drawPiece(x + cs / 2, y + cs / 2, r, board[sel], 0.85, 4)
  end
  -- move animation along the path; captured pieces fade as they are jumped
  if anim then
    local t = now - anim.t0
    local m = anim.m
    for k, s2 in ipairs(m.caps) do
      local fade = 1 - K.clamp((t - (k - 0.5) * STEP) / (STEP * 0.8), 0, 1)
      if fade > 0 then
        local x, y = sqXY(s2)
        drawPiece(x + cs / 2, y + cs / 2, r * (0.7 + 0.3 * fade), anim.capv[k], fade)
      end
    end
    local seg = min(#m.path, floor(t / STEP) + 1)
    local p = K.easeInOut(min(1, (t - (seg - 1) * STEP) / STEP))
    local a = seg == 1 and m.from or m.path[seg - 1]
    local bq = m.path[seg]
    local ax, ay = sqXY(a)
    local bx, by = sqXY(bq)
    local v = anim.v
    if seg == #m.path and p >= 1 and m.crown then v = v + 2 end
    drawPiece(K.lerp(ax, bx, p) + cs / 2, K.lerp(ay, by, p) + cs / 2, r, v, 1, sin(p * pi) * cs * 0.25)
  end
  -- cursor
  if not result and not F.modal() then
    local i = (cur.y - 1) * 8 + cur.x
    if flipped() then i = (7 - (cur.y - 1)) * 8 + (7 - (cur.x - 1)) + 1 end
    local x, y = sqXY(i)
    K.ring(x + 1, y + 1, cs - 2, cs - 2, 6, "#FFFFFF", 3)
  end
  fx:draw()
end

local function modeName(m)
  return ({TR("mode_easy"), TR("mode_medium"), TR("mode_hard"), TR("mode_pvp")})[m]
end
local function sideName(p) return p == 1 and TR("red") or TR("black") end

local function statusText()
  if result then
    if result.winner == 0 then return TR("draw") end
    if vsAI() then return result.winner == humanSide and TR("you_win") or TR("cpu_wins") end
    return TR("side_wins", sideName(result.winner))
  end
  if isAiTurn() then return TR("thinking") end
  if mustCap then return TR("must_capture") end
  if vsAI() then return TR("your_turn") end
  return TR("side_turn", sideName(turn))
end

local function drawScore(w, y)
  local n1, n2 = E.count(board)
  local sw = min(150, floor((w - 48) / 2))
  local x0 = floor((w - sw * 2 - 12) / 2)
  for k = 1, 2 do
    local bx = x0 + (k - 1) * (sw + 12)
    local active = not result and turn == k
    gfx.rect(bx, y, sw, 46, 12, active and K.col(theme.accent, 0.16) or K.col(theme.text, 0.06))
    if active then gfx.color(theme.accent); gfx.rectLine(bx, y, sw, 46, 12, 2) end
    drawPiece(bx + 24, y + 23, 13, k, 1)
    local label = sideName(k)
    if vsAI() then label = label .. " · " .. (k == humanSide and TR("you") or TR("cpu")) end
    gfx.color(theme.text2)
    gfx.text(label, bx + 44, y + 5, 11, "semibold")
    gfx.color(theme.text)
    gfx.text(TR("pieces_n", k == 1 and n1 or n2), bx + 44, y + 20, 16, "bold")
    if active and isAiTurn() then ui.spinner(bx + sw - 18, y + 23, 7) end
  end
end

local function drawHints(w, y)
  if K.lastInput == "pad" then
    K.hints({{"dpad", TR("h_move")}, {"A", TR("h_select")}, {"B", TR("h_cancel")}, {"Y", TR("h_hint")},
             {"X", TR("h_new")}, {"-", TR("h_undo")}, {"+", TR("h_pause")}}, 0, y, w)
  elseif K.lastInput == "key" then
    K.hints({{TR("k_arrows"), TR("h_move")}, {"Enter", TR("h_select")}, {"Esc", TR("h_cancel")}, {"Z", TR("h_undo")},
             {"H", TR("h_hint")}, {"N", TR("h_new")}, {"P", TR("h_pause")}}, 0, y, w)
  else
    K.hints({{"touch", TR("h_tap_piece")}}, 0, y, w)
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
    local sub = result and (result.reason == "quiet" and TR("draw_quiet") or TR("no_moves_left")) or ""
    K.dialog(F.dlg, w, h, {icon = icon, iconColor = ic, title = statusText(), subtitle = sub,
      lines = {{vsAI() and TR("you") or TR("red"), tostring(st.a)}, {TR("draws"), tostring(st.d)},
               {vsAI() and TR("cpu") or TR("black"), tostring(st.b)}},
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
  F.titleScreen(w, h, {icon = "workspaces", c1 = "#FF7A59", c2 = "#9C2A10", title = TR("title"), subtitle = TR("tagline"),
    extraH = 88,
    extra = function(x, y, bw)
      local nm = ui.segmented("tmode", {TR("mode_easy"), TR("mode_medium"), TR("mode_hard"), TR("mode_pvp")}, mode, x, y, bw, 32)
      if nm ~= mode and F.scene == "title" then setMode(nm); F.open("title") end
      if vsAI() then
        local ns = ui.segmented("tside", {TR("play_red"), TR("play_black")}, humanSide, x, y + 42, bw, 32)
        if ns ~= humanSide and F.scene == "title" then setHuman(ns); F.open("title") end
      end
    end,
    buttons = {{(#history > 0 and not result) and TR("continue") or TR("play"), function()
                  if result then newGame() else F.play(); scheduleAi() end
                end, "primary", "play_arrow"},
               {TR("new_game"), newGame, "default", "refresh"},
               {TR("rules"), function() F.open("rules") end, "default", "help"},
               {TR("stats_title"), function() F.open("stats") end, "default", "bar_chart"}}})
  if F.scene == "rules" then
    K.dialog(F.dlg, w, h, {icon = "help", title = TR("rules"), subtitle = TR("rules_text"), width = 400,
      buttons = {{TR("close"), function() F.open("title") end}}})
  end
end

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  if F.scene == "title" or F.scene == "rules" or (F.scene ~= "play" and F.returnTo == "title") then
    drawTitle(w, h)
    if F.scene ~= "title" and F.scene ~= "rules" then drawDialogs(w, h) end
    return
  end
  F.title(TR("title"), modeName(mode) .. " · " .. statusText(), 16, 10)
  local hit = F.toolbar({{"pause", "pause"}, F.soundItem(), {"refresh", "new"}, {"lightbulb", "hint"},
                         {"undo", "undo"}}, w - 16, 14)
  if hit == "sound" then K.setMuted(not K.muted)
  elseif hit == "pause" then F.open("pause")
  elseif hit == "new" then askNew()
  elseif hit == "hint" then hint()
  elseif hit == "undo" then undo() end
  drawScore(w, 62)
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
  if flipped() then r, c = 7 - r, 7 - c end
  return r * 8 + c + 1
end

local function cursorSquare()
  local r, c = cur.y - 1, cur.x - 1
  if flipped() then r, c = 7 - r, 7 - c end
  return r * 8 + c + 1
end

function app.event(e)
  K.track(e)
  local t = e.type
  if F.scene == "rules" then
    if (t == "paddown" and (e.pad == "a" or e.pad == "b")) or (t == "keydown" and (e.key == "enter" or e.key == "escape")) then
      F.open("title")
    end
    return
  end
  if F.modal() then F.dialogEvent(e); return end
  if t == "paddown" then
    local p = e.pad
    local d = F.DIRV[p]
    if d then F.moveCursor(cur, d[1], d[2], 8, 8, false)
    elseif p == "a" then
      if result then F.open("over") else clickSquare(cursorSquare()) end
    elseif p == "b" then cancelSel()
    elseif p == "y" then hint()
    elseif p == "x" then askNew()
    elseif p == "minus" then undo()
    elseif p == "l" then setMode((mode - 2) % 4 + 1)
    elseif p == "r" then setMode(mode % 4 + 1)
    elseif p == "plus" then F.open("pause") end
  elseif t == "keydown" then
    local k = e.key
    local d = F.DIRV[k]
    if d then F.moveCursor(cur, d[1], d[2], 8, 8, false)
    elseif k == "enter" or k == "space" then
      if result then F.open("over") else clickSquare(cursorSquare()) end
    elseif k == "escape" then
      if sel then cancelSel() else F.open("pause") end
    elseif k == "z" or k == "backspace" then undo()
    elseif k == "h" then hint()
    elseif k == "n" or k == "f2" then askNew()
    elseif k == "p" then F.open("pause") end
  elseif t == "mousedown" then
    press = sqAt(e.x, e.y)
    if press and sel ~= press and #partial == 0 and board[press] ~= 0 and E.owner(board[press]) == turn then
      clickSquare(press)
      press = -1
    end
  elseif t == "mouseup" then
    local i = sqAt(e.x, e.y)
    if i and not e.cancel and press ~= -1 then
      if i == press then clickSquare(i)
      elseif sel and press == sel then clickSquare(i) end   -- drag a piece to its destination
    elseif i and press == -1 and sel and i ~= sel then
      clickSquare(i)
    end
    if i then
      local r, c = sqRC(i)
      if flipped() then r, c = 7 - r, 7 - c end
      cur.x, cur.y = c + 1, r + 1
    end
    press = nil
  end
end

function app.menu()
  local items = {{label = TR("new_game"), id = 1, shortcut = "N"},
                 {label = TR("undo"), id = 2, shortcut = "Z", enabled = #history > 0},
                 {label = TR("hint"), id = 3, shortcut = "H"}, "-"}
  for m = 1, 4 do items[#items + 1] = {label = modeName(m), id = 10 + m, checked = mode == m} end
  items[#items + 1] = "-"
  items[#items + 1] = {label = TR("play_red"), id = 21, checked = humanSide == 1, enabled = vsAI()}
  items[#items + 1] = {label = TR("play_black"), id = 22, checked = humanSide == 2, enabled = vsAI()}
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
  elseif id > 10 and id <= 14 then setMode(id - 10)
  elseif id == 21 or id == 22 then setHuman(id - 20) end
end

function app.close()
  saveAll()
  return true
end

return app
