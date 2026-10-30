-- 15 Bulmaca / 15 Puzzle for Nexvyn OS: sliding tiles on 3x3, 4x4 and 5x5 boards. Always solvable shuffles,
-- multi-tile slides, swipe, undo, hints (optimal on 3x3, a look-ahead suggestion on bigger boards), a saved game per
-- size, best moves and best time per size.
local K = require("kit")
local F = require("frame")
local app = {}

local floor, max, min, abs, sin = math.floor, math.max, math.min, math.abs, math.sin
local random = math.random

local SIZES = {3, 4, 5}
local SIZE_LABELS = {"3×3", "4×4", "5×5"}
local SLIDE = 0.09

local N, sizeIdx = 4, 2
local tiles = {}              -- tiles[i] = number, 0 = gap
local gap = 16
local moves, elapsed, started, solved = 0, 0, false, false
local history = {}            -- gap positions before each single move
local anim = {}               -- anim[value] = {fromIndex, t0}
local cur = {x = 1, y = 1}
local hintIdx, hintT = nil, -10
local colorMode = false
local best = {}               -- best[tostring(N)] = {moves, time}
local stats = {solved = 0, hints = 0}
local fx = K.particles()
local B = {x = 0, y = 0, s = 0, cs = 0, g = 0}
local press = nil
local newRecord = false

local function rc(i) return (i - 1) // N + 1, (i - 1) % N + 1 end
local function idx(r, c) return (r - 1) * N + c end

local function isSolved()
  for i = 1, N * N - 1 do if tiles[i] ~= i then return false end end
  return true
end

-- ------------------------------------------------------------------ persistence
local function saveGame()
  store.set("game" .. N, {tiles = tiles, moves = moves, time = elapsed, started = started, solved = solved,
                          history = history})
end
local function saveStats()
  store.set("best", best)
  store.set("stats", stats)
  store.set("color", colorMode)
end

local function neighbours(i)
  local r, c = rc(i)
  local t = {}
  if r > 1 then t[#t + 1] = i - N end
  if r < N then t[#t + 1] = i + N end
  if c > 1 then t[#t + 1] = i - 1 end
  if c < N then t[#t + 1] = i + 1 end
  return t
end

local function shuffle()
  tiles = {}
  for i = 1, N * N - 1 do tiles[i] = i end
  tiles[N * N] = 0
  gap = N * N
  local last = nil
  local count = N * N * 30
  repeat
    for _ = 1, count do
      local nb = neighbours(gap)
      local j
      repeat j = nb[random(#nb)] until j ~= last
      tiles[gap], tiles[j] = tiles[j], 0
      last, gap = gap, j
    end
  until not isSolved()
end

local function newGame()
  shuffle()
  moves, elapsed, started, solved, newRecord = 0, 0, false, false, false
  history, anim = {}, {}
  hintIdx = nil
  local now = sys.time()
  for i = 1, N * N do if tiles[i] > 0 then anim[tiles[i]] = {i, now - SLIDE + (i - 1) * 0.015, pop = true} end end
  cur.x, cur.y = rc(gap)
  F.play()
  saveGame()
end

local function loadGame(n)
  N = n
  for i, s in ipairs(SIZES) do if s == n then sizeIdx = i end end
  store.set("size", N)
  local g = store.get("game" .. N)
  anim, hintIdx = {}, nil
  if type(g) == "table" and type(g.tiles) == "table" and #g.tiles == N * N then
    local seen, okv = {}, true
    for i = 1, N * N do
      local v = tonumber(g.tiles[i])
      if not v or v < 0 or v >= N * N or seen[v] then okv = false; break end
      seen[v] = true
    end
    if okv and not g.solved then
      tiles = {}
      for i = 1, N * N do
        tiles[i] = floor(tonumber(g.tiles[i]))
        if tiles[i] == 0 then gap = i end
      end
      moves, elapsed = tonumber(g.moves) or 0, tonumber(g.time) or 0
      started, solved = g.started == true, false
      history = {}
      if type(g.history) == "table" then
        for i, v in ipairs(g.history) do history[i] = floor(tonumber(v) or 1) end
      end
      cur.x, cur.y = rc(gap)
      return
    end
  end
  newGame()
end

-- ------------------------------------------------------------------ moves
-- moves the tile at j (adjacent to the gap) into the gap
local function single(j, now, recordHistory)
  local v = tiles[j]
  tiles[gap], tiles[j] = v, 0
  anim[v] = {j, now}
  if recordHistory then history[#history + 1] = gap end
  gap = j
end

local function onSolved()
  solved = true
  stats.solved = stats.solved + 1
  local key = tostring(N)
  local b = best[key]
  if type(b) ~= "table" then b = {} end
  newRecord = false
  if not b.moves or moves < b.moves then b.moves = moves; newRecord = true end
  if not b.time or elapsed < b.time then b.time = elapsed; newRecord = true end
  best[key] = b
  saveStats()
  saveGame()
  F.winSound()
  K.rumble(0.5, 90)
  timer.after(0.2, function() F.celebrate(fx, B.x, B.y, B.s, B.s) end)
  timer.after(1.0, function() if solved and F.scene == "play" then F.open("won") end end)
end

-- slides every tile between position i and the gap (same row or column) towards the gap
local function slideFrom(i)
  if solved or F.modal() or i == gap then return false end
  local r, c = rc(i)
  local gr, gc = rc(gap)
  if r ~= gr and c ~= gc then K.tone(150, 0.05, 0.12, "square"); return false end
  local now = sys.time()
  local count = 0
  while gap ~= i do
    local grr, gcc = rc(gap)
    local j
    if r == grr then j = idx(grr, gcc + (c > gcc and 1 or -1)) else j = idx(grr + (r > grr and 1 or -1), gcc) end
    single(j, now + count * 0.03, true)
    count = count + 1
    moves = moves + 1
  end
  if not started then started = true end
  hintIdx = nil
  K.tone(420 + count * 30, 0.05, 0.18, "triangle")
  K.tone(840, 0.02, 0.05, "sine")
  if isSolved() then onSolved() else saveGame() end
  return true
end

-- direction = the way the tile travels
local function slideDir(d)
  local gr, gc = rc(gap)
  local r, c = gr - F.DIRV[d][2], gc - F.DIRV[d][1]
  if r < 1 or r > N or c < 1 or c > N then K.tone(150, 0.04, 0.1, "square"); return end
  slideFrom(idx(r, c))
end

local function undo()
  if solved or #history == 0 or F.modal() then K.tone(160, 0.05, 0.12, "square"); return end
  local p = table.remove(history)
  single(p, sys.time(), false)
  moves = max(0, moves - 1)
  hintIdx = nil
  K.tone(520, 0.05, 0.15, "triangle")
  saveGame()
end

-- ------------------------------------------------------------------ hints
local function manhattan(t)
  local h = 0
  for i = 1, N * N do
    local v = t[i]
    if v > 0 then
      local r, c = (i - 1) // N, (i - 1) % N
      local tr, tc = (v - 1) // N, (v - 1) % N
      h = h + abs(r - tr) + abs(c - tc)
    end
  end
  return h
end

local nodes = 0
local function ida(t, g, bound, h, gp, prev)
  local f = g + h
  if f > bound then return f end
  if h == 0 then return true end
  nodes = nodes + 1
  if nodes > 150000 then return 1e9 end
  local minNext = 1e9
  local gr, gc = (gp - 1) // N, (gp - 1) % N
  for _, j in ipairs(neighbours(gp)) do
    if j ~= prev then
      local v = t[j]
      local tr, tc = (v - 1) // N, (v - 1) % N
      local jr, jc = (j - 1) // N, (j - 1) % N
      local dh = (abs(gr - tr) + abs(gc - tc)) - (abs(jr - tr) + abs(jc - tc))
      t[gp], t[j] = v, 0
      local res = ida(t, g + 1, bound, h + dh, j, gp)
      t[j], t[gp] = v, 0
      if res == true then return true end
      if res < minNext then minNext = res end
    end
  end
  return minNext
end

-- best first move for 3x3 (optimal), nil when the search budget runs out
local function optimalMove()
  local t = {}
  for i = 1, N * N do t[i] = tiles[i] end
  local h = manhattan(t)
  if h == 0 then return nil end
  nodes = 0
  local bound = h
  while bound < 60 do
    local bestJ, nextBound = nil, 1e9
    for _, j in ipairs(neighbours(gap)) do
      local v = t[j]
      t[gap], t[j] = v, 0
      local res = ida(t, 1, bound, manhattan(t), j, gap)
      t[j], t[gap] = v, 0
      if res == true then bestJ = j; break end
      if res < nextBound then nextBound = res end
    end
    if bestJ then return bestJ end
    if nodes > 150000 then return nil end
    bound = nextBound
  end
  return nil
end

-- look-ahead suggestion for bigger boards: the first move of the best short sequence
local function lookahead(t, gp, prev, depth)
  local h = manhattan(t)
  if depth == 0 or h == 0 then return h end
  local bestH = 1e9
  for _, j in ipairs(neighbours(gp)) do
    if j ~= prev then
      local v = t[j]
      t[gp], t[j] = v, 0
      local s = lookahead(t, j, gp, depth - 1) + 0.01 * depth
      t[j], t[gp] = v, 0
      if s < bestH then bestH = s end
    end
  end
  return bestH
end

local function suggestMove()
  local t = {}
  for i = 1, N * N do t[i] = tiles[i] end
  local prev = history[#history]
  local bestJ, bestS = nil, 1e9
  for _, j in ipairs(neighbours(gap)) do
    local v = t[j]
    t[gap], t[j] = v, 0
    local s = lookahead(t, j, gap, N == 4 and 7 or 6) + (j == prev and 3 or 0) + random() * 0.5
    t[j], t[gap] = v, 0
    if s < bestS then bestJ, bestS = j, s end
  end
  return bestJ
end

local function hint()
  if solved or F.modal() then return end
  local j = N == 3 and optimalMove() or nil
  if not j then j = suggestMove() end
  if not j then return end
  hintIdx, hintT = j, sys.time()
  cur.x, cur.y = select(2, rc(j)), (rc(j))
  stats.hints = stats.hints + 1
  F.chord({660, 880}, 0.15, 0.2, "sine")
  saveStats()
end

local function setSize(i)
  i = K.clamp(i, 1, #SIZES)
  if SIZES[i] == N then return end
  saveGame()
  loadGame(SIZES[i])
  K.play("pop", 0.5)
end

local function askNew()
  if started and not solved then F.open("confirm") else newGame(); K.play("pop", 0.5) end
end

-- ------------------------------------------------------------------ app
function app.load()
  K.loadPrefs()
  local b = store.get("best", {})
  best = type(b) == "table" and b or {}
  local s = store.get("stats", {})
  if type(s) == "table" then for k, v in pairs(stats) do stats[k] = tonumber(s[k]) or v end end
  colorMode = store.get("color", false) == true
  local n = tonumber(store.get("size", 4)) or 4
  if n < 3 or n > 5 then n = 4 end
  loadGame(floor(n))
  F.open("title")
end

local saveAcc = 0
function app.update(dt)
  fx:update(dt)
  if started and not solved and F.scene == "play" then
    elapsed = elapsed + dt
    saveAcc = saveAcc + dt
    if saveAcc > 5 then saveAcc = 0; saveGame() end
  end
  local d = F.stick(dt)
  if d and F.scene == "play" then F.moveCursor(cur, F.DIRV[d][1], F.DIRV[d][2], N, N, false) end
end

-- ------------------------------------------------------------------ drawing
local ROWCOL = {"#FF6B6B", "#FFA94D", "#FFD43B", "#69DB7C", "#4DABF7"}

local function cellXY(i)
  local r, c = rc(i)
  return B.x + B.g + (c - 1) * (B.cs + B.g), B.y + B.g + (r - 1) * (B.cs + B.g)
end

local function drawBoard(now)
  local g = max(4, floor(B.s * 0.12 / (N + 1)))
  B.g = g
  B.cs = (B.s - g * (N + 1)) / N
  local cs = B.cs
  gfx.shadow(B.x, B.y, B.s, B.s, 16, 20, 4)
  gfx.rect(B.x, B.y, B.s, B.s, 16, theme.dark and "#1D2129" or "#C9D1DD")
  for i = 1, N * N do
    local x, y = cellXY(i)
    gfx.rect(x, y, cs, cs, cs * 0.14, K.col(theme.text, theme.dark and 0.05 or 0.07))
  end
  local fs = cs * (N == 5 and 0.4 or 0.44)
  for i = 1, N * N do
    local v = tiles[i]
    if v > 0 then
      local x, y = cellXY(i)
      local a = anim[v]
      local scale = 1
      if a then
        local p = (now - a[2]) / SLIDE
        if a.pop then
          scale = p < 0 and 0 or K.easeOutBack(min(1, p))
        else
          p = K.easeOut(max(0, min(1, p)))
          local fx0, fy0 = cellXY(a[1])
          x, y = K.lerp(fx0, x, p), K.lerp(fy0, y, p)
        end
        if p >= 1 then anim[v] = nil end
      end
      local s = cs * scale
      local px, py = x + (cs - s) / 2, y + (cs - s) / 2
      local right = v == i
      local base
      if colorMode then base = ROWCOL[((v - 1) // N) % 5 + 1] else base = right and theme.green or theme.accent end
      local top = K.mix(base, "#FFFFFF", theme.dark and 0.08 or 0.22)
      gfx.gradient(px, py, s, s, top, K.mix(base, "#000000", 0.12), false, s * 0.14)
      gfx.color(K.col("#FFFFFF", 0.22))
      gfx.rect(px + 3, py + 3, s - 6, max(2, s * 0.08), s * 0.1)
      if solved then
        local glow = 0.5 + 0.5 * sin(now * 4 - i * 0.4)
        gfx.color(K.col("#FFFFFF", 0.25 * glow))
        gfx.rect(px, py, s, s, s * 0.14)
      end
      gfx.color(colorMode and "#1C1C1E" or "#FFFFFF")
      gfx.text(tostring(v), px, py + (s - gfx.textHeight(fs * scale, "bold")) / 2, fs * scale, "bold", "center", s)
      if right and colorMode then gfx.circle(px + s - 10, py + 10, 4, "#1C1C1E") end
    end
  end
  if hintIdx and now - hintT < 3 and not solved then
    local x, y = cellXY(hintIdx)
    local p = 0.5 + 0.5 * sin(now * 8)
    gfx.color(K.col(theme.yellow, 0.6 + 0.4 * p))
    gfx.rectLine(x - 3, y - 3, cs + 6, cs + 6, cs * 0.14 + 3, 4)
  end
  if not solved and not F.modal() then
    local x, y = cellXY(idx(cur.y, cur.x))
    K.ring(x - 3, y - 3, cs + 6, cs + 6, cs * 0.14 + 3)
  end
  fx:draw()
end

local function drawHints(w, y)
  if K.lastInput == "pad" then
    K.hints({{"dpad", TR("h_move")}, {"A", TR("h_slide")}, {"B", TR("h_undo")}, {"Y", TR("h_hint")}, {"X", TR("h_new")},
             {{"L", "R"}, TR("h_size")}, {"+", TR("h_pause")}}, 0, y, w)
  elseif K.lastInput == "key" then
    K.hints({{TR("k_arrows"), TR("h_arrows")}, {"Z", TR("h_undo")}, {"H", TR("h_hint")}, {"N", TR("h_new")},
             {"1-3", TR("h_size")}, {"Esc", TR("h_pause")}}, 0, y, w)
  else
    K.hints({{"touch", TR("h_tap_tile")}}, 0, y, w)
  end
end

local function bestText(n)
  local b = best[tostring(n)]
  if type(b) ~= "table" or not b.moves then return "—" end
  return TR("best_fmt", b.moves, K.fmtTime(b.time or 0))
end

local function drawDialogs(w, h)
  local s = F.scene
  if s == "pause" then
    F.pauseDialog(w, h, {onRestart = newGame, onMenu = function() F.open("title") end})
  elseif s == "won" then
    K.dialog(F.dlg, w, h, {icon = "emoji_events", iconColor = theme.yellow, title = TR("solved"),
      subtitle = newRecord and TR("new_record") or nil,
      lines = {{TR("moves"), tostring(moves)}, {TR("time"), K.fmtTime(elapsed)}, {TR("best"), bestText(N)}},
      buttons = {{TR("play_again"), function() newGame(); K.play("pop", 0.5) end, "primary", "replay"},
                 {TR("close"), F.close}}})
  else
    F.commonDialogs(w, h, {
      stats = function()
        local lines = {{TR("solved_count"), tostring(stats.solved)}, {TR("hints_used"), tostring(stats.hints)}}
        for i, n in ipairs(SIZES) do lines[#lines + 1] = {SIZE_LABELS[i], bestText(n)} end
        return lines
      end,
      onReset = function() best = {}; stats = {solved = 0, hints = 0}; saveStats() end,
      onNew = newGame,
    })
  end
end

local function drawTitle(w, h)
  F.titleScreen(w, h, {icon = "apps", c1 = "#A0E06B", c2 = "#3FA34D", title = TR("title"), subtitle = TR("tagline"),
    extraH = 46,
    extra = function(x, y, bw)
      local ns = ui.segmented("tsize", SIZE_LABELS, sizeIdx, x, y, bw, 32)
      if ns ~= sizeIdx and F.scene == "title" then setSize(ns); F.open("title") end
    end,
    buttons = {{(started and not solved) and TR("continue") or TR("play"), function()
                  if solved then newGame() else F.play() end
                end, "primary", "play_arrow"},
               {TR("new_game"), function() newGame(); K.play("pop", 0.5) end, "default", "shuffle"},
               {TR("stats_title"), function() F.open("stats") end, "default", "bar_chart"}},
    footer = TR("best") .. " " .. SIZE_LABELS[sizeIdx] .. ": " .. bestText(N)})
end

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  if F.scene == "title" or (F.scene ~= "play" and F.returnTo == "title") then
    drawTitle(w, h)
    if F.scene ~= "title" then drawDialogs(w, h) end
    return
  end
  F.title(TR("title"), TR("tagline"), 16, 10)
  local hit = F.toolbar({{"pause", "pause"}, F.soundItem(), {"palette", "color", colorMode and theme.accent or nil, colorMode},
                         {"shuffle", "new"}, {"lightbulb", "hint"}, {"undo", "undo"}}, w - 16, 14)
  if hit == "sound" then K.setMuted(not K.muted)
  elseif hit == "pause" then F.open("pause")
  elseif hit == "color" then colorMode = not colorMode; saveStats()
  elseif hit == "new" then askNew()
  elseif hit == "hint" then hint()
  elseif hit == "undo" then undo() end
  local y = 64
  local segW = min(240, w - 32 - 2 * 96 - 16)
  local ns = ui.segmented("size", SIZE_LABELS, sizeIdx, 16, y, segW, 34)
  if ns ~= sizeIdx and not F.modal() then K.lastInput = "pointer"; setSize(ns) end
  local sw = 92
  K.stat(w - 16 - sw, y - 6, sw, 46, TR("time_caps"), K.fmtTime(elapsed), theme.blue)
  K.stat(w - 16 - 2 * sw - 8, y - 6, sw, 46, TR("moves_caps"), tostring(moves), theme.orange)
  local top, bottom = y + 52, h - 36
  local s = floor(min(w - 32, bottom - top))
  B.s, B.x, B.y = s, floor((w - s) / 2), floor(top + (bottom - top - s) / 2)
  drawBoard(now)
  drawHints(w, h - 28)
  drawDialogs(w, h)
end

-- ------------------------------------------------------------------ input
local function cellAt(x, y)
  if B.cs <= 0 then return nil end
  local c = floor((x - B.x - B.g / 2) / (B.cs + B.g))
  local r = floor((y - B.y - B.g / 2) / (B.cs + B.g))
  if c < 0 or r < 0 or c >= N or r >= N then return nil end
  return r * N + c + 1
end

function app.event(e)
  K.track(e)
  local t = e.type
  if F.modal() then F.dialogEvent(e); return end
  if t == "paddown" then
    local p = e.pad
    local d = F.DIRV[p]
    if d then F.moveCursor(cur, d[1], d[2], N, N, false)
    elseif p == "a" then
      if solved then F.open("won") else slideFrom(idx(cur.y, cur.x)) end
    elseif p == "b" then undo()
    elseif p == "y" then hint()
    elseif p == "x" or p == "minus" then askNew()
    elseif p == "l" or p == "zl" then setSize(sizeIdx - 1)
    elseif p == "r" or p == "zr" then setSize(sizeIdx + 1)
    elseif p == "plus" then F.open("pause") end
  elseif t == "keydown" then
    local k = e.key
    if F.DIRV[k] then slideDir(k)
    elseif k == "w" then slideDir("up") elseif k == "s" then slideDir("down")
    elseif k == "a" then slideDir("left") elseif k == "d" then slideDir("right")
    elseif k == "enter" or k == "space" then slideFrom(idx(cur.y, cur.x))
    elseif k == "z" or k == "backspace" then undo()
    elseif k == "h" then hint()
    elseif k == "n" or k == "f2" then askNew()
    elseif k == "c" then colorMode = not colorMode; saveStats()
    elseif k == "1" or k == "2" or k == "3" then setSize(tonumber(k))
    elseif k == "escape" or k == "p" then F.open("pause") end
  elseif t == "mousedown" then
    press = {i = cellAt(e.x, e.y), x = e.x, y = e.y}
  elseif t == "mouseup" then
    if press and not e.cancel then
      local dx, dy = e.x - press.x, e.y - press.y
      local th = max(20, B.cs * 0.3)
      if abs(dx) > th or abs(dy) > th then
        if abs(dx) > abs(dy) then slideDir(dx > 0 and "right" or "left") else slideDir(dy > 0 and "down" or "up") end
      elseif press.i and press.i == cellAt(e.x, e.y) then
        cur.x, cur.y = select(2, rc(press.i)), (rc(press.i))
        slideFrom(press.i)
      end
    end
    press = nil
  end
end

function app.menu()
  local items = {{label = TR("new_game"), id = 1, shortcut = "N"},
                 {label = TR("undo"), id = 2, shortcut = "Z", enabled = #history > 0},
                 {label = TR("hint"), id = 3, shortcut = "H"}, "-"}
  for i, n in ipairs(SIZES) do items[#items + 1] = {label = SIZE_LABELS[i], id = 10 + i, checked = n == N} end
  items[#items + 1] = "-"
  items[#items + 1] = {label = TR("color_mode"), id = 4, checked = colorMode, shortcut = "C"}
  items[#items + 1] = {label = TR("sound"), id = 5, checked = not K.muted}
  items[#items + 1] = {label = TR("stats_title"), id = 6}
  return {{title = TR("menu_game"), items = items}}
end

function app.onmenu(id)
  if id == 1 then askNew()
  elseif id == 2 then undo()
  elseif id == 3 then hint()
  elseif id == 4 then colorMode = not colorMode; saveStats()
  elseif id == 5 then K.setMuted(not K.muted)
  elseif id == 6 then F.open("stats")
  elseif id > 10 and id <= 13 then setSize(id - 10) end
end

function app.close()
  saveGame()
  saveStats()
  return true
end

return app
