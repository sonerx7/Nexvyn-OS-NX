-- Işıkları Söndür / Lights Out for Nexvyn OS: 5x5, pressing a light toggles it and its four neighbours.
-- 60 generated levels (always solvable, par = optimal solution found with GF(2) elimination), random puzzles,
-- undo, hints from the solver, stars and best moves per level.
local K = require("kit")
local F = require("frame")
local app = {}

local floor, max, min, sin, pi = math.floor, math.max, math.min, math.sin, math.pi

local N = 5
local CELLS = N * N
local LEVELS = 60
local FULL = (1 << CELLS) - 1

local level = 1
local randomMode = false
local bits = 0                 -- lit cells, bit i-1 = cell i
local par = 0
local moves = 0
local history = {}
local toggledAt = {}           -- per cell: last toggle time (ripple)
local cur = {x = 3, y = 3}
local solved = false
local hintCell, hintT = nil, -10
local hintsUsed = false
local best = {}                -- best[tostring(level)] = moves
local stats = {randomSolved = 0, hints = 0, presses = 0}
local fx = K.particles()
local B = {x = 0, y = 0, s = 0, cs = 0}
local press = nil
local levelPick = {x = 1, y = 1}
local masks = {}               -- masks[i] = bits toggled by pressing cell i

for i = 1, CELLS do
  local r, c = (i - 1) // N, (i - 1) % N
  local m = 1 << (i - 1)
  if r > 0 then m = m | (1 << (i - 1 - N)) end
  if r < N - 1 then m = m | (1 << (i - 1 + N)) end
  if c > 0 then m = m | (1 << (i - 2)) end
  if c < N - 1 then m = m | (1 << i) end
  masks[i] = m
end

local function popcount(x)
  local n = 0
  while x ~= 0 do x = x & (x - 1); n = n + 1 end
  return n
end

-- ------------------------------------------------------------------ solver (GF(2))
-- Returns a bitmask of cells to press (fewest presses) that turns every light off, or nil.
local function solve(state)
  local rows = {}
  for i = 1, CELLS do
    local m = 0
    for j = 1, CELLS do
      if masks[j] & (1 << (i - 1)) ~= 0 then m = m | (1 << (j - 1)) end
    end
    if state & (1 << (i - 1)) ~= 0 then m = m | (1 << CELLS) end
    rows[i] = m
  end
  local pivots = {}           -- {col, row}
  local r = 1
  local isPivot = {}
  for c = 0, CELLS - 1 do
    local p
    for k = r, CELLS do
      if rows[k] & (1 << c) ~= 0 then p = k; break end
    end
    if p then
      rows[r], rows[p] = rows[p], rows[r]
      for k = 1, CELLS do
        if k ~= r and rows[k] & (1 << c) ~= 0 then rows[k] = rows[k] ~ rows[r] end
      end
      pivots[#pivots + 1] = {c, r}
      isPivot[c] = true
      r = r + 1
    end
  end
  for k = r, CELLS do
    if rows[k] == (1 << CELLS) then return nil end
  end
  local free = {}
  for c = 0, CELLS - 1 do if not isPivot[c] then free[#free + 1] = c end end
  local bestX, bestN = nil, 99
  for combo = 0, (1 << #free) - 1 do
    local x = 0
    for k, c in ipairs(free) do
      if combo & (1 << (k - 1)) ~= 0 then x = x | (1 << c) end
    end
    for _, pv in ipairs(pivots) do
      local row = rows[pv[2]]
      local v = (row >> CELLS) & 1
      v = v ~ (popcount(row & x & FULL) & 1)
      if v == 1 then x = x | (1 << pv[1]) end
    end
    local n = popcount(x)
    if n < bestN then bestX, bestN = x, n end
  end
  return bestX, bestN
end

-- ------------------------------------------------------------------ levels
local function rng(seed)
  local s = seed % 2147483647
  if s <= 0 then s = s + 2147483646 end
  return function(n)
    s = (s * 48271) % 2147483647
    return s % n + 1
  end
end

local function generate(lv, seed)
  local rand = rng(seed)
  local k = lv and min(14, 2 + (lv + 1) // 2) or (8 + rand(7))
  for _ = 1, 50 do
    local b, used, n = 0, {}, 0
    while n < k do
      local i = rand(CELLS)
      if not used[i] then used[i] = true; n = n + 1; b = b ~ masks[i] end
    end
    if b ~= 0 then
      local _, p = solve(b)
      if p and p >= min(k, 3) then return b, p end
    end
  end
  return masks[13], 1
end

local parCache = {}
local function levelPar(lv)
  local p = parCache[lv]
  if not p then
    local _, q = generate(lv, lv * 7919 + 13)
    p = q
    parCache[lv] = p
  end
  return p
end

local function saveProgress()
  store.set("best", best)
  store.set("stats", stats)
  store.set("cur", {level = level, random = randomMode, bits = bits, par = par, moves = moves, history = history,
                    hints = hintsUsed})
end

local function startLevel(lv)
  level = K.clamp(lv, 1, LEVELS)
  randomMode = false
  bits, par = generate(level, level * 7919 + 13)
  moves, history, solved, hintCell, hintsUsed = 0, {}, false, nil, false
  local now = sys.time()
  for i = 1, CELLS do toggledAt[i] = now + ((i - 1) % N + (i - 1) // N) * 0.03 end
  F.play()
  saveProgress()
end

local function startRandom()
  randomMode = true
  bits, par = generate(nil, floor(sys.epoch() + sys.time() * 1000) % 2000000000 + 1)
  moves, history, solved, hintCell, hintsUsed = 0, {}, false, nil, false
  local now = sys.time()
  for i = 1, CELLS do toggledAt[i] = now + ((i - 1) % N + (i - 1) // N) * 0.03 end
  F.play()
  saveProgress()
end

local function restart()
  if randomMode then
    while #history > 0 do bits = bits ~ masks[table.remove(history)] end
    moves, solved, hintCell = 0, false, nil
    F.play()
    saveProgress()
  else
    startLevel(level)
  end
  K.play("pop", 0.5)
end

local function starsFor(m, p)
  if m <= p then return 3 elseif m <= p + 4 then return 2 end
  return 1
end

local function unlocked()
  local n = 1
  for lv = 1, LEVELS do
    if best[tostring(lv)] then n = max(n, lv + 1) end
  end
  return min(LEVELS, n)
end

local function onSolved()
  solved = true
  local now = sys.time()
  if randomMode then
    stats.randomSolved = stats.randomSolved + 1
  else
    local key = tostring(level)
    if not best[key] or moves < best[key] then best[key] = moves end
  end
  saveProgress()
  F.winSound()
  K.rumble(0.5, 80)
  timer.after(0.25, function() F.celebrate(fx, B.x, B.y, B.s, B.s) end)
  timer.after(1.0, function()
    if solved and F.scene == "play" then F.open("won") end
  end)
  for i = 1, CELLS do toggledAt[i] = now + ((i - 1) % N + (i - 1) // N) * 0.04 end
end

local function pressCell(i, fromUndo)
  if solved or F.modal() then return end
  bits = bits ~ masks[i]
  local now = sys.time()
  local m = masks[i]
  for j = 1, CELLS do
    if m & (1 << (j - 1)) ~= 0 then toggledAt[j] = now + (j == i and 0 or 0.04) end
  end
  if fromUndo then
    moves = max(0, moves - 1)
  else
    history[#history + 1] = i
    moves = moves + 1
    stats.presses = stats.presses + 1
  end
  hintCell = nil
  local lit = popcount(bits)
  K.tone(300 + (CELLS - lit) * 22, 0.06, 0.2, "triangle")
  K.tone(600 + (CELLS - lit) * 44, 0.04, 0.08, "sine")
  K.rumble(0.12, 12)
  if bits == 0 then onSolved() else saveProgress() end
end

local function undo()
  if solved or #history == 0 or F.modal() then K.tone(160, 0.05, 0.12, "square"); return end
  pressCell(table.remove(history), true)
end

local function hint()
  if solved or F.modal() then return end
  local x = solve(bits)
  if not x or x == 0 then return end
  -- prefer the solution cell nearest to the cursor
  local ci = (cur.y - 1) * N + cur.x
  local bestI, bestD = nil, 1e9
  for i = 1, CELLS do
    if x & (1 << (i - 1)) ~= 0 then
      local d = math.abs((i - 1) % N - (ci - 1) % N) + math.abs((i - 1) // N - (ci - 1) // N)
      if d < bestD then bestI, bestD = i, d end
    end
  end
  hintCell, hintT = bestI, sys.time()
  cur.x, cur.y = (bestI - 1) % N + 1, (bestI - 1) // N + 1
  if not hintsUsed then hintsUsed = true; stats.hints = stats.hints + 1 end
  F.chord({660, 880}, 0.15, 0.2, "sine")
  saveProgress()
end

-- ------------------------------------------------------------------ app
function app.load()
  K.loadPrefs()
  local b = store.get("best", {})
  best = type(b) == "table" and b or {}
  local s = store.get("stats", {})
  if type(s) == "table" then for k, v in pairs(stats) do stats[k] = tonumber(s[k]) or v end end
  local c = store.get("cur")
  if type(c) == "table" and tonumber(c.bits) and tonumber(c.bits) > 0 then
    level = K.clamp(floor(tonumber(c.level) or 1), 1, LEVELS)
    randomMode = c.random == true
    bits = floor(tonumber(c.bits)) & FULL
    par = tonumber(c.par) or 1
    moves = tonumber(c.moves) or 0
    history = {}
    if type(c.history) == "table" then
      for i, v in ipairs(c.history) do history[i] = K.clamp(floor(tonumber(v) or 1), 1, CELLS) end
    end
    hintsUsed = c.hints == true
    local now = sys.time()
    for i = 1, CELLS do toggledAt[i] = now - 1 end
  else
    startLevel(unlocked())
  end
  F.open("title")
end

function app.update(dt)
  fx:update(dt)
  local d = F.stick(dt)
  if d then
    if F.scene == "play" and not solved then F.moveCursor(cur, F.DIRV[d][1], F.DIRV[d][2], N, N, true) end
  end
end

-- ------------------------------------------------------------------ drawing
local function drawCell(i, x, y, s, now)
  local on = bits & (1 << (i - 1)) ~= 0
  local t = now - (toggledAt[i] or 0)
  local k = t < 0 and 0 or min(1, t / 0.22)
  local lit = on and K.easeOut(k) or (1 - K.easeOut(k))
  if t < 0 then lit = on and 0 or 1 end
  local r = s * 0.18
  local offTop = theme.dark and "#2E3440" or "#D9DEE7"
  local offBot = theme.dark and "#232831" or "#C5CCD8"
  gfx.gradient(x, y, s, s, offTop, offBot, false, r)
  if lit > 0.01 then
    local glow = 0.75 + 0.25 * sin(now * 3 + i)
    gfx.rect(x - 4, y - 4, s + 8, s + 8, r + 4, K.col("#FFD54F", 0.28 * lit * glow))
    gfx.alpha(lit)
    gfx.gradient(x, y, s, s, "#FFF3B0", "#FFC107", false, r)
    gfx.circle(x + s * 0.5, y + s * 0.45, s * 0.22, K.col("#FFFFFF", 0.55))
    gfx.unalpha()
  end
  -- press ring ripple
  if t >= 0 and t < 0.35 then
    local p = t / 0.35
    gfx.color(K.col(on and "#FFD54F" or theme.accent, 1 - p))
    gfx.rectLine(x - p * 8, y - p * 8, s + p * 16, s + p * 16, r + p * 8, 2)
  end
  gfx.color(K.col(theme.text, 0.08))
  gfx.rectLine(x, y, s, s, r, 1)
end

local function drawBoard(now)
  local gap = max(6, floor(B.s * 0.025))
  local s = (B.s - gap * (N + 1)) / N
  B.cs, B.gap = s, gap
  gfx.shadow(B.x, B.y, B.s, B.s, 18, 22, 5)
  gfx.rect(B.x, B.y, B.s, B.s, 18, theme.dark and "#151820" or "#AEB6C4")
  for i = 1, CELLS do
    local x = B.x + gap + ((i - 1) % N) * (s + gap)
    local y = B.y + gap + ((i - 1) // N) * (s + gap)
    drawCell(i, x, y, s, now)
    if hintCell == i and now - hintT < 3 then
      local p = 0.5 + 0.5 * sin(now * 8)
      gfx.color(K.col(theme.green, 0.6 + 0.4 * p))
      gfx.rectLine(x - 3, y - 3, s + 6, s + 6, s * 0.18 + 3, 4)
      gfx.icon("touch_app", x + s / 2, y + s / 2, s * 0.45, K.col(theme.green, 0.8))
    end
  end
  if not solved and not F.modal() then
    local x = B.x + gap + (cur.x - 1) * (s + gap)
    local y = B.y + gap + (cur.y - 1) * (s + gap)
    K.ring(x - 4, y - 4, s + 8, s + 8, s * 0.18 + 4, theme.accent, 3)
  end
  fx:draw()
end

local function drawStars(cx, y, n, size)
  for k = 1, 3 do
    gfx.icon(k <= n and "star" or "star_border", cx + (k - 2) * size * 1.1, y, size, k <= n and theme.yellow or theme.text3)
  end
end

local function drawHints(w, y)
  if K.lastInput == "pad" then
    K.hints({{"dpad", TR("h_move")}, {"A", TR("h_press")}, {"B", TR("h_undo")}, {"Y", TR("h_hint")},
             {"X", TR("restart")}, {{"L", "R"}, TR("level")}, {"+", TR("h_pause")}}, 0, y, w)
  elseif K.lastInput == "key" then
    K.hints({{TR("k_arrows"), TR("h_move")}, {"Enter", TR("h_press")}, {"Z", TR("h_undo")}, {"H", TR("h_hint")},
             {"R", TR("restart")}, {"Esc", TR("h_pause")}}, 0, y, w)
  else
    K.hints({{"touch", TR("h_tap_light")}}, 0, y, w)
  end
end

local function drawLevels(w, h)
  local n = unlocked()
  K.dim(w, h, 1)
  local cols = 10
  local cell = floor(min(58, (w - 60) / cols, (h - 170) / 6))
  local gw = cell * cols
  local x0, y0 = floor((w - gw) / 2), floor((h - cell * 6) / 2) + 10
  K.card(x0 - 18, y0 - 64, gw + 36, cell * 6 + 128, 16)
  gfx.color(theme.text)
  gfx.text(TR("levels"), x0 - 18, y0 - 50, 20, "bold", "center", gw + 36)
  gfx.color(theme.text2)
  local stars = 0
  for lv = 1, LEVELS do
    local b = best[tostring(lv)]
    if b then stars = stars + starsFor(b, levelPar(lv)) end
  end
  gfx.text(TR("stars_total", stars, LEVELS * 3), x0 - 18, y0 - 24, 13, "medium", "center", gw + 36)
  for lv = 1, LEVELS do
    local cx, cy = (lv - 1) % cols, (lv - 1) // cols
    local x, y = x0 + cx * cell + 3, y0 + cy * cell + 3
    local s = cell - 6
    local open = lv <= n
    local done = best[tostring(lv)] ~= nil
    local hit = ui.hit("lv" .. lv, x, y, s, s)
    local bg = done and K.col(theme.yellow, 0.25) or (open and theme.control or K.col(theme.text, 0.05))
    if hit.hovered and open then bg = theme.hover end
    gfx.rect(x, y, s, s, 10, bg)
    gfx.color(theme.separator)
    gfx.rectLine(x, y, s, s, 10, 1)
    if open then
      gfx.color(theme.text)
      gfx.text(tostring(lv), x, y + s * 0.18, s * 0.34, "bold", "center", s)
      if done then
        local b = best[tostring(lv)]
        local st = starsFor(b, levelPar(lv))
        for k = 1, 3 do
          gfx.icon("star", x + s / 2 + (k - 2) * s * 0.24, y + s * 0.76, s * 0.22, k <= st and theme.yellow or theme.text3)
        end
      end
    else
      gfx.icon("lock", x + s / 2, y + s / 2, s * 0.36, theme.text3)
    end
    if levelPick.x == cx + 1 and levelPick.y == cy + 1 then K.ring(x - 3, y - 3, s + 6, s + 6, 12) end
    if hit.clicked and open then startLevel(lv); K.play("pop", 0.5) end
  end
  if ui.button(TR("close") .. "##lv", x0 + gw / 2 - 70, y0 + cell * 6 + 14, 140, 34) then F.close() end
end

local function drawDialogs(w, h)
  local s = F.scene
  if s == "pause" then
    F.pauseDialog(w, h, {onRestart = restart, onMenu = function() F.open("title") end})
  elseif s == "levels" then
    drawLevels(w, h)
  elseif s == "won" then
    local st = starsFor(moves, par)
    local lines = {{TR("moves"), tostring(moves)}, {TR("par"), tostring(par)}}
    if not randomMode then lines[#lines + 1] = {TR("best"), tostring(best[tostring(level)] or moves)} end
    local buttons = {}
    if randomMode then
      buttons[1] = {TR("new_random"), startRandom, "primary", "shuffle"}
    elseif level < LEVELS then
      buttons[1] = {TR("next_level"), function() startLevel(level + 1); K.play("pop", 0.5) end, "primary", "arrow_forward"}
    end
    buttons[#buttons + 1] = {TR("restart"), restart, "default", "replay"}
    buttons[#buttons + 1] = {TR("levels"), function() F.open("levels") end, "default", "grid_view"}
    K.dialog(F.dlg, w, h, {icon = "emoji_events", iconColor = theme.yellow, title = TR("solved"),
      subtitle = randomMode and TR("random_puzzle") or TR("level_n", level), lines = lines, extraH = 34,
      extra = function(x, y, ww) drawStars(x + ww / 2, y + 14, st, 28) end, buttons = buttons})
  else
    F.commonDialogs(w, h, {
      stats = function()
        local done, stars = 0, 0
        for lv = 1, LEVELS do
          local b = best[tostring(lv)]
          if b then
            done = done + 1
            stars = stars + starsFor(b, levelPar(lv))
          end
        end
        return {{TR("levels_done"), done .. " / " .. LEVELS}, {TR("stars"), stars .. " / " .. LEVELS * 3},
                {TR("random_done"), tostring(stats.randomSolved)}, {TR("total_presses"), tostring(stats.presses)},
                {TR("hints_used"), tostring(stats.hints)}}
      end,
      onReset = function()
        best = {}
        stats = {randomSolved = 0, hints = 0, presses = 0}
        saveProgress()
      end,
      onNew = startRandom,
    })
  end
end

local function drawTitle(w, h)
  local done = 0
  for lv = 1, LEVELS do if best[tostring(lv)] then done = done + 1 end end
  F.titleScreen(w, h, {icon = "lightbulb", c1 = "#FFE066", c2 = "#F4A300", title = TR("title"), subtitle = TR("tagline"),
    buttons = {{(moves > 0 and not solved) and TR("continue") or TR("play"), function()
                  if solved then startLevel(randomMode and unlocked() or min(LEVELS, level + 1)) else F.play() end
                end, "primary", "play_arrow"},
               {TR("levels"), function() F.open("levels") end, "default", "grid_view"},
               {TR("random_puzzle"), startRandom, "default", "shuffle"},
               {TR("stats_title"), function() F.open("stats") end, "default", "bar_chart"}},
    footer = TR("levels_done") .. ": " .. done .. " / " .. LEVELS})
end

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  if F.scene == "title" or (F.scene ~= "play" and F.returnTo == "title") then
    drawTitle(w, h)
    if F.scene ~= "title" then drawDialogs(w, h) end
    return
  end
  local sub = (randomMode and TR("random_puzzle") or TR("level_n", level)) .. " · " .. TR("moves_par", moves, par)
  F.title(TR("title"), sub, 16, 10)
  local hit = F.toolbar({{"pause", "pause"}, F.soundItem(), {"grid_view", "levels"}, {"replay", "restart"},
                         {"lightbulb", "hint"}, {"undo", "undo"}}, w - 16, 14)
  if hit == "sound" then K.setMuted(not K.muted)
  elseif hit == "pause" then F.open("pause")
  elseif hit == "levels" then F.open("levels")
  elseif hit == "restart" then restart()
  elseif hit == "hint" then hint()
  elseif hit == "undo" then undo() end
  -- lights left meter
  local lit = popcount(bits)
  local my = 64
  gfx.color(theme.text2)
  gfx.text(TR("lights_left", lit), 16, my, 13, "semibold")
  ui.progress(1 - lit / CELLS, 16, my + 22, w - 32, 6)
  local top, bottom = my + 40, h - 36
  local s = floor(min(w - 32, bottom - top))
  B.s, B.x, B.y = s, floor((w - s) / 2), floor(top + (bottom - top - s) / 2)
  drawBoard(now)
  drawHints(w, h - 28)
  drawDialogs(w, h)
end

-- ------------------------------------------------------------------ input
local function cellAt(x, y)
  if not B.cs or B.cs <= 0 then return nil end
  local cx = floor((x - B.x - B.gap / 2) / (B.cs + B.gap))
  local cy = floor((y - B.y - B.gap / 2) / (B.cs + B.gap))
  if cx < 0 or cy < 0 or cx >= N or cy >= N then return nil end
  return cy * N + cx + 1
end

local function levelsEvent(e)
  local t = e.type
  local k = t == "paddown" and e.pad or (t == "keydown" and e.key) or nil
  if not k then return end
  local d = F.DIRV[k]
  if d then
    F.moveCursor(levelPick, d[1], d[2], 10, 6, false)
  elseif (t == "paddown" and k == "a") or (t == "keydown" and (k == "enter" or k == "space")) then
    local lv = (levelPick.y - 1) * 10 + levelPick.x
    if lv <= unlocked() then startLevel(lv); K.play("pop", 0.5) else K.tone(160, 0.05, 0.12, "square") end
  elseif (t == "paddown" and (k == "b" or k == "minus")) or (t == "keydown" and k == "escape") then
    F.close()
  end
end

function app.event(e)
  K.track(e)
  local t = e.type
  if F.scene == "levels" then levelsEvent(e); return end
  if F.modal() then F.dialogEvent(e); return end
  if t == "paddown" then
    local p = e.pad
    local d = F.DIRV[p]
    if d then if not solved then F.moveCursor(cur, d[1], d[2], N, N, true) end
    elseif p == "a" then
      if solved then F.open("won") else pressCell((cur.y - 1) * N + cur.x) end
    elseif p == "b" then undo()
    elseif p == "y" then hint()
    elseif p == "x" then restart()
    elseif p == "l" and not randomMode and level > 1 then startLevel(level - 1)
    elseif p == "r" and not randomMode and level < unlocked() then startLevel(level + 1)
    elseif p == "minus" then levelPick.x, levelPick.y = (level - 1) % 10 + 1, (level - 1) // 10 + 1; F.open("levels")
    elseif p == "plus" then F.open("pause") end
  elseif t == "keydown" then
    local k = e.key
    local d = F.DIRV[k]
    if d then if not solved then F.moveCursor(cur, d[1], d[2], N, N, true) end
    elseif k == "enter" or k == "space" then
      if solved then F.open("won") else pressCell((cur.y - 1) * N + cur.x) end
    elseif k == "z" or k == "backspace" then undo()
    elseif k == "h" then hint()
    elseif k == "r" then restart()
    elseif k == "n" then startRandom()
    elseif k == "l" then F.open("levels")
    elseif k == "escape" or k == "p" then F.open("pause") end
  elseif t == "mousedown" then
    press = cellAt(e.x, e.y)
  elseif t == "mouseup" then
    local i = cellAt(e.x, e.y)
    if i and i == press and not e.cancel then
      cur.x, cur.y = (i - 1) % N + 1, (i - 1) // N + 1
      pressCell(i)
    end
    press = nil
  end
end

function app.menu()
  return {{title = TR("menu_game"), items = {
    {label = TR("restart"), id = 1, shortcut = "R"},
    {label = TR("random_puzzle"), id = 2, shortcut = "N"},
    {label = TR("levels"), id = 3, shortcut = "L"},
    {label = TR("undo"), id = 4, shortcut = "Z", enabled = #history > 0},
    {label = TR("hint"), id = 5, shortcut = "H"},
    "-",
    {label = TR("sound"), id = 6, checked = not K.muted},
    {label = TR("stats_title"), id = 7},
  }}}
end

function app.onmenu(id)
  if id == 1 then restart()
  elseif id == 2 then startRandom()
  elseif id == 3 then F.open("levels")
  elseif id == 4 then undo()
  elseif id == 5 then hint()
  elseif id == 6 then K.setMuted(not K.muted)
  elseif id == 7 then F.open("stats") end
end

function app.close()
  saveProgress()
  return true
end

return app
