-- 2048 for Nexvyn OS: slide and merge tiles on a 3x3 .. 6x6 board. Swipe, arrows/WASD, D-pad or stick;
-- undo, a saved game per board size, best score per size and statistics. Time Attack mode (three minutes per run,
-- its own saves and best scores) and a hint that looks two moves ahead (expectimax-style search over the spawns).
local K = require("kit")
local F = require("frame")
local app = {}

local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local random = math.random

local SIZES = {3, 4, 5, 6}
local SIZE_LABELS = {"3×3", "4×4", "5×5", "6×6"}
local SLIDE, POP, GROW = 0.11, 0.18, 0.14
local UNDO_MAX = 30
local DIRS = {left = true, right = true, up = true, down = true}
local KEYDIR = {left = "left", right = "right", up = "up", down = "down", a = "left", d = "right", w = "up", s = "down"}

local N, sizeIdx = 4, 2
local grid = {}             -- grid[(r - 1) * N + c] = tile {v, r, c, fr, fc, born, merge}
local ghosts = {}           -- tiles that slide into a merge and disappear
local score = 0
local won, keepGoing, over, started = false, false, false, false
local history = {}
local moveT0 = -10
local best = {}             -- best["4"] = score
local stats = {played = 0, wins = 0, top = 0, moves = 0}
local dirSt = {}
local fx = K.particles()
local popups = {}           -- {text, t}
local swipe = nil
local B = {x = 0, y = 0, s = 0, cell = 0, gap = 0}
local scoreBox = {x = 0, y = 0, w = 0}
local mode = 1              -- 1 classic, 2 time attack
local TA_TIME = 180
local timeLeft = TA_TIME
local hintDir, hintT = nil, -10
local ARROW = {left = "arrow_back", right = "arrow_forward", up = "arrow_upward", down = "arrow_downward"}

local function idx(r, c) return (r - 1) * N + c end

local function tile(v, r, c, born)
  return {v = v, r = r, c = c, fr = r, fc = c, born = born, merge = false}
end

-- ------------------------------------------------------------------ persistence
local function saveStats()
  store.set("best", best)
  store.set("stats", stats)
end

local function gkey(n) return (mode == 2 and "gta" or "game") .. n end
local function bkey() return (mode == 2 and "t" or "") .. tostring(N) end
local function saveGame()
  local cells = {}
  for i = 1, N * N do cells[i] = grid[i] and grid[i].v or 0 end
  store.set(gkey(N), {cells = cells, score = score, won = won, keep = keepGoing, over = over, started = started,
                      left = timeLeft})
end

local function spawn(at)
  local empty, n = {}, 0
  for i = 1, N * N do
    if not grid[i] then n = n + 1; empty[n] = i end
  end
  if n == 0 then return end
  local i = empty[random(n)]
  grid[i] = tile(random() < 0.9 and 2 or 4, floor((i - 1) / N) + 1, (i - 1) % N + 1, at)
end

local function newGame()
  grid, ghosts, history, popups = {}, {}, {}, {}
  score = 0
  won, keepGoing, over, started = false, false, false, false
  timeLeft, hintDir = TA_TIME, nil
  local now = sys.time()
  spawn(now)
  spawn(now + 0.05)
  F.play()
  saveGame()
end

local function loadGame(n)
  N = n
  for i, s in ipairs(SIZES) do if s == n then sizeIdx = i end end
  store.set("size", N)
  local g = store.get(gkey(N))
  grid, ghosts, history, popups = {}, {}, {}, {}
  hintDir = nil
  if type(g) == "table" and type(g.cells) == "table" and #g.cells == N * N then
    local now, any = sys.time(), false
    for i = 1, N * N do
      local v = tonumber(g.cells[i]) or 0
      if v > 0 then
        grid[i] = tile(v, floor((i - 1) / N) + 1, (i - 1) % N + 1, now + (i % 7) * 0.02)
        any = true
      end
    end
    if any then
      score = tonumber(g.score) or 0
      won, keepGoing, over, started = g.won == true, g.keep == true, g.over == true, g.started == true
      timeLeft = tonumber(g.left) or TA_TIME
      if over then F.open("over") else F.play() end
      return
    end
  end
  newGame()
end

-- ------------------------------------------------------------------ rules
local function canMove()
  for r = 1, N do
    for c = 1, N do
      local t = grid[idx(r, c)]
      if not t then return true end
      if c < N then local u = grid[idx(r, c + 1)]; if not u or u.v == t.v then return true end end
      if r < N then local u = grid[idx(r + 1, c)]; if not u or u.v == t.v then return true end end
    end
  end
  return false
end

-- position of the j-th cell of a line, counted from the edge the tiles move towards
local function linePos(dir, line, j)
  if dir == "left" then return line, j
  elseif dir == "right" then return line, N + 1 - j
  elseif dir == "up" then return j, line end
  return N + 1 - j, line
end

-- ------------------------------------------------------------------ hint search on plain value grids
local function slideVals(v, dir)
  local out, gained, moved = {}, 0, false
  for i = 1, N * N do out[i] = 0 end
  for line = 1, N do
    local k, last, lastMerged, lastPos = 0, 0, false, nil
    for j = 1, N do
      local r, c = linePos(dir, line, j)
      local x = v[idx(r, c)]
      if x > 0 then
        if last == x and not lastMerged then
          out[lastPos] = x * 2
          gained, moved, last, lastMerged = gained + x * 2, true, x * 2, true
        else
          k = k + 1
          local tr, tc = linePos(dir, line, k)
          local q = idx(tr, tc)
          out[q] = x
          if q ~= idx(r, c) then moved = true end
          last, lastMerged, lastPos = x, false, q
        end
      end
    end
  end
  return out, gained, moved
end

local LOG2 = {}
local function lg(x)
  if x <= 0 then return 0 end
  local l = LOG2[x]
  if not l then l = math.log(x, 2); LOG2[x] = l end
  return l
end

-- empty cells, monotonic rows / columns, smooth neighbours and the biggest tile in a corner
local function evalGrid(v)
  local empty, mono, smooth, maxv = 0, 0, 0, 0
  for i = 1, N * N do
    if v[i] == 0 then empty = empty + 1 elseif v[i] > maxv then maxv = v[i] end
  end
  for a = 1, N do
    local i1, d1, i2, d2 = 0, 0, 0, 0
    for b = 1, N - 1 do
      local x, y = lg(v[idx(a, b)]), lg(v[idx(a, b + 1)])
      if x > y then d1 = d1 + x - y else i1 = i1 + y - x end
      if x > 0 and y > 0 then smooth = smooth - abs(x - y) end
      local p, q = lg(v[idx(b, a)]), lg(v[idx(b + 1, a)])
      if p > q then d2 = d2 + p - q else i2 = i2 + q - p end
      if p > 0 and q > 0 then smooth = smooth - abs(p - q) end
    end
    mono = mono - min(i1, d1) - min(i2, d2)
  end
  local corner = 0
  for _, i in ipairs({1, N, N * N - N + 1, N * N}) do if v[i] == maxv then corner = lg(maxv) end end
  return empty * 2.7 + mono + smooth * 0.1 + corner * 1.5
end

local DLIST = {"up", "left", "right", "down"}
local function bestMove()
  local v = {}
  for i = 1, N * N do v[i] = grid[i] and grid[i].v or 0 end
  local bestD, bestS = nil, -1e9
  for _, d in ipairs(DLIST) do
    local a, gained, moved = slideVals(v, d)
    if moved then
      local empties = {}
      for i = 1, N * N do if a[i] == 0 then empties[#empties + 1] = i end end
      local total, n = 0, 0
      local step = max(1, floor(#empties / 6))
      for e = 1, #empties, step do
        local i = empties[e]
        a[i] = 2
        local best2 = evalGrid(a) - 50
        for _, d2 in ipairs(DLIST) do
          local b, g2, m2 = slideVals(a, d2)
          if m2 then best2 = max(best2, evalGrid(b) + lg(g2 + 1) * 0.3) end
        end
        a[i] = 0
        total, n = total + best2, n + 1
      end
      local sc = (n > 0 and total / n or evalGrid(a)) + lg(gained + 1) * 0.5
      if sc > bestS then bestD, bestS = d, sc end
    end
  end
  return bestD
end

local function showHint()
  if F.scene ~= "play" or over then return end
  hintDir, hintT = bestMove(), sys.time()
  if hintDir then K.tone(880, 0.06, 0.15, "sine") end
end

local function finishGame()
  over = true
  stats.top = max(stats.top, 0)
  saveStats()
  saveGame()
  F.loseSound()
  K.rumble(0.6, 120)
  timer.after(0.7, function()
    if over and F.scene == "play" then F.open("over") end
  end)
end

local function move(dir)
  if F.scene ~= "play" or over then return false end
  local now = sys.time()
  ghosts = {}
  local snap = {score = score, won = won, keep = keepGoing}
  for i = 1, N * N do snap[i] = grid[i] and grid[i].v or 0 end
  local ng = {}
  local moved, gained, topMerge = false, 0, 0
  for line = 1, N do
    local k, last, lastMerged = 0, nil, false
    for j = 1, N do
      local r, c = linePos(dir, line, j)
      local t = grid[idx(r, c)]
      if t then
        t.fr, t.fc = t.r, t.c
        if last and not lastMerged and last.v == t.v then
          t.r, t.c = last.r, last.c
          ghosts[#ghosts + 1] = last
          ghosts[#ghosts + 1] = t
          local m = tile(t.v * 2, t.r, t.c, now + SLIDE)
          m.merge = true
          ng[idx(t.r, t.c)] = m
          gained = gained + m.v
          topMerge = max(topMerge, m.v)
          moved = true
          last, lastMerged = m, true
        else
          k = k + 1
          local tr, tc = linePos(dir, line, k)
          t.r, t.c = tr, tc
          if tr ~= t.fr or tc ~= t.fc then moved = true end
          ng[idx(tr, tc)] = t
          last, lastMerged = t, false
        end
      end
    end
  end
  if not moved then
    K.tone(140, 0.05, 0.12, "triangle")
    return false
  end
  history[#history + 1] = snap
  if #history > UNDO_MAX then table.remove(history, 1) end
  hintDir = nil
  grid = ng
  moveT0 = now
  score = score + gained
  stats.moves = stats.moves + 1
  if not started then
    started = true
    stats.played = stats.played + 1
  end
  if gained > 0 then
    popups[#popups + 1] = {text = "+" .. gained, t = now}
    local step = 0
    local v = topMerge
    while v > 2 do v = v / 2; step = step + 1 end
    K.tone(300 + step * 55, 0.09, 0.22, "triangle")
    if topMerge >= 128 then K.rumble(0.25, 30) end
  else
    K.tone(520, 0.03, 0.08, "sine")
  end
  local key = bkey()
  if score > (best[key] or 0) then best[key] = score end
  if topMerge > stats.top then stats.top = topMerge end
  spawn(now + SLIDE)
  if topMerge >= 2048 and not won and mode == 1 then
    won = true
    stats.wins = stats.wins + 1
    F.winSound()
    timer.after(SLIDE + 0.3, function() F.celebrate(fx, B.x, B.y, B.s, B.s) end)
    timer.after(SLIDE + 0.45, function()
      if F.scene == "play" and won and not keepGoing then F.open("win") end
    end)
  end
  if not canMove() then finishGame() end
  saveStats()
  saveGame()
  return true
end

local function undo()
  if #history == 0 then
    K.tone(160, 0.06, 0.15, "square")
    return
  end
  local snap = table.remove(history)
  local now = sys.time()
  grid, ghosts = {}, {}
  for i = 1, N * N do
    if snap[i] > 0 then grid[i] = tile(snap[i], floor((i - 1) / N) + 1, (i - 1) % N + 1, now - 1) end
  end
  score, won, keepGoing = snap.score, snap.won, snap.keep
  over = false
  F.play()
  moveT0 = -10
  K.tone(660, 0.05, 0.18, "triangle")
  timer.after(0.05, function() K.tone(440, 0.06, 0.15, "triangle") end)
  saveGame()
end

local function askNew()
  if started and not over and score > 0 then
    F.open("confirm")
  else
    newGame()
    K.play("pop", 0.6)
  end
end

local function setSize(i)
  i = K.clamp(i, 1, #SIZES)
  if SIZES[i] == N then return end
  saveGame()
  loadGame(SIZES[i])
  K.play("pop", 0.5)
end

local function closeDialog()
  if F.scene == "win" then keepGoing = true; saveGame() end
  if F.scene ~= "over" and F.scene ~= "title" then F.close() end
end

-- ------------------------------------------------------------------ app
function app.load()
  K.loadPrefs()
  local b = store.get("best", {})
  best = type(b) == "table" and b or {}
  local s = store.get("stats", {})
  if type(s) == "table" then
    for k, v in pairs(stats) do stats[k] = tonumber(s[k]) or v end
  end
  mode = K.clamp(floor(tonumber(store.get("mode", 1)) or 1), 1, 2)
  local n = tonumber(store.get("size", 4)) or 4
  if n < 3 or n > 6 then n = 4 end
  loadGame(floor(n))
  F.open("title")
end

local function setMode(m)
  if m == mode then return end
  saveGame()
  mode = m
  store.set("mode", mode)
  loadGame(N)
end

function app.update(dt)
  local now = sys.time()
  if mode == 2 and F.scene == "play" and started and not over then
    local before = timeLeft
    timeLeft = timeLeft - dt
    if timeLeft <= 10 and floor(before) ~= floor(timeLeft) then K.tone(1500, 0.02, 0.08, "square") end
    if timeLeft <= 0 then
      timeLeft = 0
      finishGame()
    end
  end
  if #ghosts > 0 and now > moveT0 + SLIDE then ghosts = {} end
  fx:update(dt)
  for i = #popups, 1, -1 do
    if now - popups[i].t > 0.9 then table.remove(popups, i) end
  end
  local d = F.stick(dt, {rep = F.modal(), dpad = false})
  if d then move(d) end
end

-- ------------------------------------------------------------------ drawing
local TILE = {[2] = "#EEE4DA", [4] = "#EDE0C8", [8] = "#F2B179", [16] = "#F59563", [32] = "#F67C5F",
              [64] = "#F65E3B", [128] = "#EDCF72", [256] = "#EDCC61", [512] = "#EDC850", [1024] = "#EDC53F",
              [2048] = "#EDC22E"}
local SUPER = {"#B57EDC", "#8E5BC9", "#6C3FB5", "#4F2C9C", "#3C3A32"}

local function tileColor(v)
  local c = TILE[v]
  if c then return c end
  local k, x = 0, v
  while x > 2048 do x = x / 2; k = k + 1 end
  return SUPER[min(#SUPER, k)]
end

local function cellXY(r, c)
  return B.x + B.gap + (c - 1) * (B.cell + B.gap), B.y + B.gap + (r - 1) * (B.cell + B.gap)
end

local function drawTile(t, x, y, scale, now)
  local cs = B.cell
  local s = cs * scale
  local px, py = x + (cs - s) / 2, y + (cs - s) / 2
  local rad = max(4, cs * 0.08) * scale
  local col = tileColor(t.v)
  if t.v >= 128 then
    local glow = t.v >= 2048 and 0.55 or 0.25 + 0.05 * math.log(t.v / 128, 2)
    gfx.rect(px - 3, py - 3, s + 6, s + 6, rad + 3, K.col(col, glow * (0.7 + 0.3 * math.sin(now * 3))))
  end
  gfx.rect(px, py, s, s, rad, col)
  local txt = tostring(t.v)
  local d = #txt
  local fs = cs * (d <= 2 and 0.48 or d == 3 and 0.4 or d == 4 and 0.32 or 0.26) * scale
  gfx.color(t.v <= 4 and "#776E65" or "#F9F6F2")
  gfx.text(txt, px, py + (s - gfx.textHeight(fs, "bold")) / 2, fs, "bold", "center", s)
end

local function drawBoard(now)
  local dark = theme.dark
  gfx.shadow(B.x, B.y, B.s, B.s, 12, 18, 4)
  gfx.rect(B.x, B.y, B.s, B.s, max(8, B.gap * 1.5), dark and "#4A433C" or "#BBADA0")
  local empty = dark and "#5C544B" or "#CDC1B4"
  local rad = max(4, B.cell * 0.08)
  for r = 1, N do
    for c = 1, N do
      local x, y = cellXY(r, c)
      gfx.rect(x, y, B.cell, B.cell, rad, empty)
    end
  end
  local p = K.easeOut((now - moveT0) / SLIDE)
  for _, t in ipairs(ghosts) do
    local x0, y0 = cellXY(t.fr, t.fc)
    local x1, y1 = cellXY(t.r, t.c)
    drawTile(t, K.lerp(x0, x1, p), K.lerp(y0, y1, p), 1, now)
  end
  for i = 1, N * N do
    local t = grid[i]
    if t and now >= t.born then
      local x0, y0 = cellXY(t.fr, t.fc)
      local x1, y1 = cellXY(t.r, t.c)
      local scale = 1
      local age = now - t.born
      if t.merge then
        if age < POP then
          scale = 1 + 0.2 * math.sin(age / POP * math.pi)
        elseif not t.burst then
          t.burst = true
          if t.v >= 64 then
            local cx, cy = x1 + B.cell / 2, y1 + B.cell / 2
            fx:burst(cx, cy, min(30, 6 + t.v / 64), tileColor(t.v), B.cell * 3, 0.5, B.cell * 0.06, 0, 3)
          end
        end
      elseif age < GROW and t.born > moveT0 - 0.5 then
        scale = K.easeOutBack(age / GROW)
      end
      drawTile(t, K.lerp(x0, x1, p), K.lerp(y0, y1, p), scale, now)
    end
  end
  fx:draw()
end

local function drawHeader(w)
  local m = 16
  gfx.color(theme.text)
  gfx.text("2048", m, 8, 40, "bold")
  if mode == 2 then
    local low = timeLeft <= 10
    gfx.color(low and theme.red or theme.blue)
    gfx.icon("timer", m + 10, 62, 16, low and theme.red or theme.blue)
    gfx.text(K.fmtTime(math.ceil(timeLeft)) .. "  ·  " .. TR("time_attack"), m + 22, 54, 13, "semibold")
  else
    gfx.color(theme.text2)
    gfx.text(TR("tagline"), m + 2, 54, 12, "medium")
  end
  local sw = min(96, floor((w - 2 * m - 140) / 2))
  local bx = w - m - sw
  K.stat(bx, 12, sw, 50, TR("best"), tostring(best[bkey()] or 0))
  K.stat(bx - sw - 8, 12, sw, 50, TR("score"), tostring(score), theme.orange)
  scoreBox.x, scoreBox.y, scoreBox.w = bx - sw - 8, 12, sw
end

local function drawToolbar(w, y)
  local m = 16
  local bw = 40
  local segW = min(280, w - 2 * m - 5 * (bw + 6) - 8)
  local ns = ui.segmented("size", SIZE_LABELS, sizeIdx, m, y, segW, 34)
  if ns ~= sizeIdx and not F.modal() then K.lastInput = "pointer"; setSize(ns) end
  local x = w - m - bw
  if ui.iconButton(K.muted and "volume_off" or "volume_up", x, y, bw, 34, nil, false, "snd") then
    K.setMuted(not K.muted)
  end
  x = x - bw - 6
  if ui.iconButton("pause", x, y, bw, 34, nil, false, "pause") and not F.modal() then F.open("pause") end
  x = x - bw - 6
  if ui.iconButton("refresh", x, y, bw, 34, nil, false, "new") and not F.modal() then askNew() end
  x = x - bw - 6
  if ui.iconButton("undo", x, y, bw, 34, #history > 0 and theme.accent or nil, false, "undo") and not F.modal() then undo() end
  x = x - bw - 6
  if ui.iconButton("lightbulb", x, y, bw, 34, theme.yellow, false, "hint") and not F.modal() then showHint() end
end

local function drawPopups(now)
  for _, p in ipairs(popups) do
    local k = (now - p.t) / 0.9
    gfx.alpha(1 - k)
    gfx.color(theme.orange)
    gfx.text(p.text, scoreBox.x, scoreBox.y + 18 - k * 34, 18, "bold", "center", scoreBox.w)
    gfx.unalpha()
  end
end

local function drawHints(w, y)
  if K.lastInput == "pad" then
    K.hints({{"dpad", TR("h_move")}, {"B", TR("h_undo")}, {"Y", TR("hint")}, {"X", TR("h_new")},
             {{"L", "R"}, TR("h_size")}, {"+", TR("h_pause")}}, 0, y, w)
  elseif K.lastInput == "key" then
    K.hints({{TR("k_arrows"), TR("h_move")}, {"Z", TR("h_undo")}, {"H", TR("hint")}, {"N", TR("h_new")},
             {"1-4", TR("h_size")}}, 0, y, w)
  else
    K.hints({{"touch", TR("h_swipe")}}, 0, y, w)
  end
end

local function drawTitle(w, h)
  F.titleScreen(w, h, {icon = "grid_4x4", c1 = "#F7C873", c2 = "#E8913A", title = "2048", subtitle = TR("tagline"),
    extraH = 88,
    extra = function(x, y, bw)
      local nm = ui.segmented("tmode", {TR("classic"), TR("time_attack")}, mode, x, y, bw, 32)
      if nm ~= mode and F.scene == "title" then setMode(nm); F.open("title") end
      local ns = ui.segmented("tsize", SIZE_LABELS, sizeIdx, x, y + 42, bw, 32)
      if ns ~= sizeIdx and F.scene == "title" then setSize(ns); F.open("title") end
    end,
    buttons = {{started and not over and TR("continue") or TR("play"), function()
                  if over then newGame() else F.play() end
                end, "primary", "play_arrow"},
               {TR("new_game"), function() newGame(); K.play("pop", 0.6) end, "default", "refresh"},
               {TR("stats_title"), function() F.open("stats") end, "default", "bar_chart"}},
    footer = TR("best_size", SIZE_LABELS[sizeIdx]) .. ": " .. tostring(best[bkey()] or 0)})
end

local function drawDialogs(w, h)
  if F.scene == "pause" then
    F.pauseDialog(w, h, {onRestart = function() newGame(); K.play("pop", 0.6) end,
                         onMenu = function() F.open("title") end})
  elseif F.scene == "win" then
    K.dialog(F.dlg, w, h, {icon = "emoji_events", iconColor = theme.yellow, title = TR("win_title"),
      subtitle = TR("win_sub"), lines = {{TR("score"), tostring(score)}},
      buttons = {{TR("keep_going"), function() keepGoing = true; F.play(); saveGame() end},
                 {TR("new_game"), function() newGame(); K.play("pop", 0.6) end}}})
  elseif F.scene == "over" then
    local key = bkey()
    local timeUp = mode == 2 and timeLeft <= 0
    K.dialog(F.dlg, w, h, {icon = timeUp and "timer_off" or "sentiment_dissatisfied", iconColor = theme.red,
      title = timeUp and TR("times_up") or TR("over_title"), subtitle = timeUp and TR("time_attack") or TR("over_sub"),
      lines = {{TR("score"), tostring(score)}, {TR("best"), tostring(best[key] or 0)}},
      buttons = timeUp and {{TR("new_game"), function() newGame(); K.play("pop", 0.6) end}} or
                {{TR("new_game"), function() newGame(); K.play("pop", 0.6) end}, {TR("undo"), undo, "default", "undo"}}})
  elseif F.scene == "confirm" then
    K.dialog(F.dlg, w, h, {icon = "refresh", title = TR("confirm_title"), subtitle = TR("confirm_sub"),
      buttons = {{TR("new_game"), function() newGame(); K.play("pop", 0.6) end, "destructive"},
                 {TR("cancel"), F.close}}})
  elseif F.scene == "stats" then
    local lines = {{TR("played"), tostring(stats.played)}, {TR("wins"), tostring(stats.wins)},
                   {TR("top_tile"), tostring(stats.top)}, {TR("moves"), tostring(stats.moves)}}
    for _, s in ipairs(SIZES) do
      lines[#lines + 1] = {TR("best_size", s .. "×" .. s), tostring(best[tostring(s)] or 0) .. "  ·  " ..
        TR("time_attack") .. " " .. tostring(best["t" .. s] or 0)}
    end
    K.dialog(F.dlg, w, h, {icon = "bar_chart", title = TR("stats_title"), width = 380, lines = lines,
      buttons = {{TR("close"), F.close},
                 {TR("reset_stats"), function() F.open("reset", 2) end, "destructive"}}})
  elseif F.scene == "reset" then
    K.dialog(F.dlg, w, h, {icon = "delete", iconColor = theme.red, title = TR("reset_stats"),
      subtitle = TR("reset_sub"),
      buttons = {{TR("reset"), function()
                   best = {}
                   stats = {played = 0, wins = 0, top = 0, moves = 0}
                   saveStats()
                   F.close()
                 end, "destructive"},
                 {TR("cancel"), F.close}}})
  end
end

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  if F.scene == "title" or (F.scene ~= "play" and F.returnTo == "title") then
    drawTitle(w, h)
    if F.scene ~= "title" then drawDialogs(w, h) end
    return
  end
  drawHeader(w)
  local ty = 74
  drawToolbar(w, ty)
  local top, bottom = ty + 48, h - 36
  local s = floor(min(w - 32, bottom - top))
  B.s = s
  B.gap = max(5, floor(s * 0.12 / (N + 1)))
  B.cell = (s - B.gap * (N + 1)) / N
  B.x = floor((w - s) / 2)
  B.y = floor(top + (bottom - top - s) / 2)
  drawBoard(now)
  if hintDir and now - hintT < 1.6 then
    local a = min(1, (1.6 - (now - hintT)) / 0.4)
    local cx, cy = B.x + B.s / 2, B.y + B.s / 2
    gfx.alpha(a)
    gfx.circle(cx, cy, B.s * 0.16, K.col(theme.bg, 0.85))
    gfx.icon(ARROW[hintDir], cx, cy, B.s * 0.2, theme.accent)
    gfx.unalpha()
  end
  if over and F.scene == "play" then
    gfx.rect(B.x, B.y, B.s, B.s, 12, K.col(theme.bg, 0.35))
  end
  drawPopups(now)
  drawHints(w, h - 28)
  drawDialogs(w, h)
  K.drawToast(w, B.y + 12)
end

-- ------------------------------------------------------------------ input
function app.event(e)
  K.track(e)
  local t = e.type
  if F.modal() then
    F.dialogEvent(e, closeDialog)
    return
  end
  if t == "paddown" then
    local p = e.pad
    if DIRS[p] then move(p)
    elseif p == "b" then undo()
    elseif p == "y" then showHint()
    elseif p == "x" or p == "minus" then askNew()
    elseif p == "l" or p == "zl" then setSize(sizeIdx - 1)
    elseif p == "r" or p == "zr" then setSize(sizeIdx + 1)
    elseif p == "plus" then F.open("pause") end
  elseif t == "keydown" then
    local k = e.key
    if KEYDIR[k] and not e.ctrl then move(KEYDIR[k])
    elseif k == "z" or k == "u" or k == "backspace" then undo()
    elseif k == "h" then showHint()
    elseif k == "t" then setMode(3 - mode)
    elseif k == "n" or k == "f2" or k == "r" then askNew()
    elseif k == "1" or k == "2" or k == "3" or k == "4" then setSize(tonumber(k))
    elseif k == "escape" or k == "p" then F.open("pause") end
  elseif t == "mousedown" then
    if F.scene == "play" and e.y > 120 then swipe = {x = e.x, y = e.y, done = false} end
  elseif t == "mousemove" then
    if swipe and not swipe.done then
      local dx, dy = e.x - swipe.x, e.y - swipe.y
      local th = max(24, B.cell * 0.35)
      if abs(dx) > th or abs(dy) > th then
        swipe.done = true
        if abs(dx) > abs(dy) then move(dx > 0 and "right" or "left") else move(dy > 0 and "down" or "up") end
      end
    end
  elseif t == "mouseup" then
    if swipe and not swipe.done and not e.cancel then
      local dx, dy = e.x - swipe.x, e.y - swipe.y
      if abs(dx) > 18 or abs(dy) > 18 then
        if abs(dx) > abs(dy) then move(dx > 0 and "right" or "left") else move(dy > 0 and "down" or "up") end
      end
    end
    swipe = nil
  end
end

function app.menu()
  local sizes = {}
  for i, s in ipairs(SIZES) do
    sizes[i] = {label = SIZE_LABELS[i], id = 10 + i, checked = s == N, shortcut = tostring(i)}
  end
  local items = {{label = TR("new_game"), id = 1, shortcut = "N"}, {label = TR("undo"), id = 2, shortcut = "Z",
                 enabled = #history > 0}, "-"}
  for _, it in ipairs(sizes) do items[#items + 1] = it end
  items[#items + 1] = "-"
  items[#items + 1] = {label = TR("classic"), id = 21, checked = mode == 1}
  items[#items + 1] = {label = TR("time_attack"), id = 22, checked = mode == 2, shortcut = "T"}
  items[#items + 1] = {label = TR("hint"), id = 23, shortcut = "H"}
  items[#items + 1] = "-"
  items[#items + 1] = {label = TR("sound"), id = 3, checked = not K.muted}
  items[#items + 1] = {label = TR("stats_title"), id = 4}
  return {{title = TR("menu_game"), items = items}}
end

function app.onmenu(id)
  if id == 1 then askNew()
  elseif id == 2 then undo()
  elseif id == 3 then K.setMuted(not K.muted)
  elseif id == 4 then F.open("stats")
  elseif id == 21 or id == 22 then setMode(id - 20)
  elseif id == 23 then showHint()
  elseif id > 10 and id <= 10 + #SIZES then setSize(id - 10) end
end

function app.close()
  saveGame()
  saveStats()
  return true
end

return app
