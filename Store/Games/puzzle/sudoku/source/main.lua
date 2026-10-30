-- Sudoku for Nexvyn OS: generated puzzles with a unique solution in three difficulties, pencil notes, mistake
-- highlighting, highlights of the selected row / column / box / digit, hints, undo, a timer and records.
local K = require("kit")
local F = require("frame")
local S = require("gen")
local app = {}

local floor, max, min, sin = math.floor, math.max, math.min, math.sin

local DIFFS = {{key = "easy", givens = 38}, {key = "medium", givens = 30}, {key = "hard", givens = 25}}

local diff = 1
local grid, given, sol, notes = {}, {}, {}, {}
local history = {}
local cur = {x = 5, y = 5}
local digit = 1               -- current digit for the controller
local notesMode = false
local showMistakes = true
local mistakes, hints = 0, 0
local elapsed = 0
local state = "none"          -- none | gen | play | won
local genCo = nil
local placedAt = {}
local best = {}               -- best[key] = seconds
local stats = {}              -- stats[key] = {played, solved}
local fx = K.particles()
local B = {x = 0, y = 0, cs = 0}
local pad = {x = 0, y = 0, w = 0, h = 0, vertical = false}
local newRecord = false
local press = nil

local function st(key)
  local s = stats[key]
  if type(s) ~= "table" then s = {played = 0, solved = 0}; stats[key] = s end
  s.played, s.solved = tonumber(s.played) or 0, tonumber(s.solved) or 0
  return s
end

-- ------------------------------------------------------------------ persistence
local function saveStats()
  store.set("best", best)
  store.set("stats", stats)
  store.set("diff", diff)
  store.set("mistakes", showMistakes)
end

local function saveGame()
  if state ~= "play" and state ~= "won" then return end
  local gv = {}
  for i = 1, 81 do gv[i] = given[i] and 1 or 0 end
  store.set("game", {grid = grid, given = gv, sol = sol, notes = notes, time = elapsed, diff = diff,
                     mistakes = mistakes, hints = hints, state = state})
end

local function loadGame()
  local g = store.get("game")
  if type(g) ~= "table" or g.state ~= "play" then return false end
  for _, k in ipairs({"grid", "given", "sol", "notes"}) do
    if type(g[k]) ~= "table" or #g[k] ~= 81 then return false end
  end
  for i = 1, 81 do
    grid[i] = floor(tonumber(g.grid[i]) or 0)
    given[i] = g.given[i] == 1
    sol[i] = floor(tonumber(g.sol[i]) or 0)
    notes[i] = floor(tonumber(g.notes[i]) or 0)
    if sol[i] < 1 or sol[i] > 9 or grid[i] < 0 or grid[i] > 9 then return false end
  end
  diff = K.clamp(floor(tonumber(g.diff) or 1), 1, 3)
  elapsed = tonumber(g.time) or 0
  mistakes, hints = tonumber(g.mistakes) or 0, tonumber(g.hints) or 0
  state = "play"
  history = {}
  return true
end

-- ------------------------------------------------------------------ game
local function newGame(d)
  if d then diff = d end
  saveStats()
  state = "gen"
  genCo = coroutine.create(function() return S.generate(DIFFS[diff].givens) end)
  F.play()
end

local function startPuzzle(p, f)
  local now = sys.time()
  for i = 1, 81 do
    grid[i] = p[i]
    given[i] = p[i] ~= 0
    sol[i] = f[i]
    notes[i] = 0
    placedAt[i] = now + ((i - 1) % 9 + (i - 1) // 9) * 0.02
  end
  history, mistakes, hints, elapsed, newRecord = {}, 0, 0, 0, false
  state = "play"
  local s = st(DIFFS[diff].key)
  s.played = s.played + 1
  saveStats()
  saveGame()
  K.notes({392, 494, 587, 784}, 0.06, 0.14)
end

local function solved()
  for i = 1, 81 do if grid[i] ~= sol[i] then return false end end
  return true
end

local function onWin()
  state = "won"
  local key = DIFFS[diff].key
  local s = st(key)
  s.solved = s.solved + 1
  newRecord = not best[key] or elapsed < best[key]
  if newRecord then best[key] = elapsed end
  saveStats()
  store.set("game", {state = "done"})
  F.winSound()
  K.rumble(0.5, 90)
  local now = sys.time()
  for i = 1, 81 do placedAt[i] = now + ((i - 1) % 9 + (i - 1) // 9) * 0.03 end
  timer.after(0.3, function() F.celebrate(fx, B.x, B.y, B.cs * 9, B.cs * 9) end)
  timer.after(1.6, function() if state == "won" and F.scene == "play" then F.open("won") end end)
end

local function sel() return (cur.y - 1) * 9 + cur.x end

local function pushUndo(i)
  local snap = {}
  for k = 1, 81 do snap[k] = notes[k] end
  history[#history + 1] = {i = i, v = grid[i], notes = snap}
  if #history > 200 then table.remove(history, 1) end
end

local function digitDone(d)
  local n = 0
  for i = 1, 81 do if grid[i] == d and grid[i] == sol[i] then n = n + 1 end end
  return n >= 9, n
end

local function setValue(i, d)
  if state ~= "play" or F.modal() or given[i] then
    if given[i] then K.tone(150, 0.04, 0.1, "square") end
    return
  end
  if notesMode and d > 0 then
    if grid[i] ~= 0 then return end
    pushUndo(i)
    notes[i] = notes[i] ~ (1 << d)
    K.tone(900 + d * 30, 0.025, 0.1, "sine")
    saveGame()
    return
  end
  if grid[i] == d then return end
  pushUndo(i)
  grid[i] = d
  notes[i] = 0
  placedAt[i] = sys.time()
  if d > 0 then
    -- remove this digit from the notes of the peers
    local bit = 1 << d
    for _, p in ipairs(S.PEERS[i]) do notes[p] = notes[p] & ~bit end
    if d ~= sol[i] then
      mistakes = mistakes + 1
      if showMistakes then K.tone(170, 0.12, 0.2, "square"); K.rumble(0.3, 40) end
    else
      K.tone(500 + d * 40, 0.05, 0.18, "triangle")
      local done = digitDone(d)
      if done then F.chord({659, 784, 988}, 0.25, 0.2) end
    end
  else
    K.tone(300, 0.04, 0.12, "sine")
  end
  if solved() then onWin() else saveGame() end
end

local function undo()
  if state ~= "play" or F.modal() then return end
  local h = table.remove(history)
  if not h then K.tone(160, 0.05, 0.12, "square"); return end
  grid[h.i] = h.v
  for k = 1, 81 do notes[k] = h.notes[k] end
  cur.x, cur.y = (h.i - 1) % 9 + 1, (h.i - 1) // 9 + 1
  K.tone(600, 0.05, 0.16, "triangle")
  saveGame()
end

local function hint()
  if state ~= "play" or F.modal() then return end
  local i = sel()
  if given[i] or grid[i] == sol[i] then
    -- pick the empty or wrong cell with the fewest candidates
    local bestI, bestN = nil, 99
    for k = 1, 81 do
      if grid[k] ~= sol[k] then
        local m = 0
        for _, p in ipairs(S.PEERS[k]) do if grid[p] ~= 0 then m = m | (1 << grid[p]) end end
        local n = 0
        for d = 1, 9 do if m & (1 << d) == 0 then n = n + 1 end end
        if n < bestN then bestI, bestN = k, n end
      end
    end
    i = bestI
  end
  if not i then return end
  cur.x, cur.y = (i - 1) % 9 + 1, (i - 1) // 9 + 1
  hints = hints + 1
  local was = notesMode
  notesMode = false
  F.chord({660, 880, 1100}, 0.2, 0.2, "sine")
  setValue(i, sol[i])
  notesMode = was
end

local function askNew(d)
  if state == "play" and #history > 0 then
    F.open("confirm")
    F.pendingDiff = d
  else
    newGame(d)
  end
end

-- ------------------------------------------------------------------ app
function app.load()
  K.loadPrefs()
  local b = store.get("best", {})
  best = type(b) == "table" and b or {}
  local s = store.get("stats", {})
  stats = type(s) == "table" and s or {}
  diff = K.clamp(floor(tonumber(store.get("diff", 1)) or 1), 1, 3)
  showMistakes = store.get("mistakes", true) ~= false
  if not loadGame() then state = "none" end
  F.open("title")
end

local saveAcc = 0
function app.update(dt)
  fx:update(dt)
  if genCo then
    S.sliceEnd = os.clock() + 0.010
    local ok, p, f = coroutine.resume(genCo)
    if not ok then error(p) end
    if coroutine.status(genCo) == "dead" then
      genCo = nil
      S.sliceEnd = math.huge
      startPuzzle(p, f)
    end
  end
  if state == "play" and F.scene == "play" then
    elapsed = elapsed + dt
    saveAcc = saveAcc + dt
    if saveAcc > 5 then saveAcc = 0; saveGame() end
  end
  local d = F.stick(dt)
  if d and F.scene == "play" and state == "play" then F.moveCursor(cur, F.DIRV[d][1], F.DIRV[d][2], 9, 9, true) end
end

-- ------------------------------------------------------------------ drawing
local function drawBoard(now)
  local cs = B.cs
  local s = cs * 9
  local i0 = sel()
  local sv = grid[i0]
  gfx.shadow(B.x, B.y, s, s, 10, 18, 4)
  gfx.rect(B.x, B.y, s, s, 10, theme.window)
  local active = state == "play" and not F.modal()
  for i = 1, 81 do
    local x = B.x + ((i - 1) % 9) * cs
    local y = B.y + ((i - 1) // 9) * cs
    local bg = nil
    if active then
      if i == i0 then bg = K.col(theme.accent, 0.35)
      elseif sv ~= 0 and grid[i] == sv then bg = K.col(theme.accent, 0.2)
      elseif S.ROW[i] == S.ROW[i0] or S.COL[i] == S.COL[i0] or S.BOX[i] == S.BOX[i0] then bg = K.col(theme.accent, 0.08) end
    end
    if bg then gfx.rect(x, y, cs, cs, 0, bg) end
    local v = grid[i]
    if v ~= 0 then
      local p = K.easeOutBack((now - (placedAt[i] or 0)) / 0.22)
      if p > 0 then
        local wrong = showMistakes and v ~= sol[i]
        local col = given[i] and theme.text or (wrong and theme.red or theme.accent)
        if state == "won" then col = K.mix(col, theme.green, 0.6) end
        if wrong then gfx.rect(x + 2, y + 2, cs - 4, cs - 4, 4, K.col(theme.red, 0.12)) end
        gfx.color(col)
        local fs = cs * 0.62 * min(1.2, p)
        gfx.text(tostring(v), x, y + (cs - gfx.textHeight(fs, given[i] and "bold" or "semibold")) / 2, fs,
                 given[i] and "bold" or "semibold", "center", cs)
      end
    elseif notes[i] ~= 0 then
      local ns = cs / 3
      for d = 1, 9 do
        if notes[i] & (1 << d) ~= 0 then
          local nx, ny = x + ((d - 1) % 3) * ns, y + ((d - 1) // 3) * ns
          gfx.color(sv == d and theme.accent or theme.text2)
          gfx.text(tostring(d), nx, ny + (ns - gfx.textHeight(ns * 0.75, "medium")) / 2, ns * 0.75, "medium", "center", ns)
        end
      end
    end
  end
  -- grid lines
  for k = 1, 8 do
    local th = k % 3 == 0 and 2.5 or 1
    gfx.color(k % 3 == 0 and K.col(theme.text, 0.75) or K.col(theme.text, 0.18))
    gfx.line(B.x + k * cs, B.y, B.x + k * cs, B.y + s, th)
    gfx.line(B.x, B.y + k * cs, B.x + s, B.y + k * cs, th)
  end
  gfx.color(K.col(theme.text, 0.75))
  gfx.rectLine(B.x, B.y, s, s, 10, 2.5)
  if active then
    local x = B.x + (cur.x - 1) * cs
    local y = B.y + (cur.y - 1) * cs
    gfx.color(K.col(theme.accent, 0.7 + 0.3 * sin(now * 6)))
    gfx.rectLine(x + 1, y + 1, cs - 2, cs - 2, 4, 3)
  end
  fx:draw()
end

local function drawPad(now)
  local n = 12
  local cols = pad.vertical and 3 or 6
  local rows = pad.vertical and 4 or 2
  local g = 8
  local bw = (pad.w - g * (cols - 1)) / cols
  local bh = min(64, (pad.h - g * (rows - 1)) / rows)
  for k = 1, n do
    local c, r = (k - 1) % cols, (k - 1) // cols
    local x, y = pad.x + c * (bw + g), pad.y + r * (bh + g)
    local hit = ui.hit("pad" .. k, x, y, bw, bh)
    local bg = hit.held and theme.hover or theme.control
    if k <= 9 and digit == k and K.lastInput == "pad" then bg = K.col(theme.accent, 0.25) end
    if k == 11 and notesMode then bg = K.col(theme.accent, 0.3) end
    gfx.shadow(x, y, bw, bh, 10, 6, 2)
    gfx.rect(x, y + (hit.held and 1 or 0), bw, bh, 10, bg)
    gfx.color(theme.separator)
    gfx.rectLine(x, y, bw, bh, 10, 1)
    if k <= 9 then
      local done, cnt = digitDone(k)
      gfx.color(done and theme.text3 or theme.accent)
      F.ctext(tostring(k), x, y - bh * 0.08, bw, bh, bh * 0.5, "bold")
      gfx.color(theme.text3)
      gfx.text(tostring(9 - cnt), x, y + bh - 16, 10, "semibold", "center", bw)
    elseif k == 10 then
      gfx.icon("backspace", x + bw / 2, y + bh / 2, bh * 0.4, theme.text2)
    elseif k == 11 then
      gfx.icon("edit", x + bw / 2, y + bh / 2 - 6, bh * 0.36, notesMode and theme.accent or theme.text2)
      gfx.color(notesMode and theme.accent or theme.text2)
      gfx.text(notesMode and TR("on") or TR("off"), x, y + bh - 17, 10, "semibold", "center", bw)
    else
      gfx.icon("lightbulb", x + bw / 2, y + bh / 2, bh * 0.4, theme.yellow)
    end
    if hit.clicked and not F.modal() and state == "play" then
      K.lastInput = "pointer"
      if k <= 9 then digit = k; setValue(sel(), k)
      elseif k == 10 then setValue(sel(), 0)
      elseif k == 11 then notesMode = not notesMode; K.tone(notesMode and 880 or 660, 0.04, 0.15, "triangle")
      else hint() end
    end
  end
end

local function diffName(d) return ({TR("easy"), TR("medium"), TR("hard")})[d] end

local function drawHints(w, y)
  if K.lastInput == "pad" then
    K.hints({{"dpad", TR("h_move")}, {"A", TR("h_place", digit)}, {{"L", "R"}, TR("h_digit")}, {"X", TR("h_erase")},
             {"Y", TR("h_notes")}, {"B", TR("h_undo")}, {"-", TR("h_hint")}, {"+", TR("h_pause")}}, 0, y, w)
  elseif K.lastInput == "key" then
    K.hints({{"1-9", TR("h_digit")}, {"0", TR("h_erase")}, {"N", TR("h_notes")}, {"Z", TR("h_undo")}, {"H", TR("h_hint")},
             {"Esc", TR("h_pause")}}, 0, y, w)
  else
    K.hints({{"touch", TR("h_tap_cell")}}, 0, y, w)
  end
end

local function fmtBest(key) return best[key] and K.fmtTime(best[key]) or "—" end

local function drawDialogs(w, h)
  local s = F.scene
  if s == "pause" then
    F.pauseDialog(w, h, {onRestart = function() newGame() end, onMenu = function() F.open("title") end})
  elseif s == "won" then
    K.dialog(F.dlg, w, h, {icon = "emoji_events", iconColor = theme.yellow, title = TR("solved"),
      subtitle = newRecord and TR("new_record") or diffName(diff),
      lines = {{TR("time"), K.fmtTime(elapsed)}, {TR("best_time"), fmtBest(DIFFS[diff].key)},
               {TR("mistakes"), tostring(mistakes)}, {TR("hints_used"), tostring(hints)}},
      buttons = {{TR("new_game"), function() newGame() end, "primary", "refresh"}, {TR("close"), F.close}}})
  else
    F.commonDialogs(w, h, {
      stats = function()
        local lines = {}
        for d = 1, 3 do
          local k = DIFFS[d].key
          local ss = st(k)
          lines[#lines + 1] = {diffName(d), TR("stat_fmt", ss.solved, ss.played, fmtBest(k))}
        end
        return lines
      end,
      onReset = function() best = {}; stats = {}; saveStats() end,
      onNew = function() newGame(F.pendingDiff) end,
    })
  end
end

local function drawTitle(w, h)
  F.titleScreen(w, h, {icon = "grid_on", c1 = "#5AC8FA", c2 = "#2F6FDE", title = TR("title"), subtitle = TR("tagline"),
    extraH = 46,
    extra = function(x, y, bw)
      local nd = ui.segmented("tdiff", {TR("easy"), TR("medium"), TR("hard")}, diff, x, y, bw, 32)
      if nd ~= diff and F.scene == "title" then diff = nd; saveStats() end
    end,
    buttons = {{state == "play" and TR("continue") or TR("new_game"), function()
                  if state == "play" then F.play() else newGame() end
                end, "primary", "play_arrow"},
               {TR("new_puzzle_diff", diffName(diff)), function() newGame() end, "default", "refresh"},
               {TR("stats_title"), function() F.open("stats") end, "default", "bar_chart"}},
    footer = TR("best_time") .. " (" .. diffName(diff) .. "): " .. fmtBest(DIFFS[diff].key)})
end

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  if F.scene == "title" or (F.scene ~= "play" and F.returnTo == "title") then
    drawTitle(w, h)
    if F.scene ~= "title" then drawDialogs(w, h) end
    return
  end
  F.title(TR("title"), diffName(diff) .. " · " .. TR("mistakes_n", mistakes), 16, 10)
  local hit = F.toolbar({{"pause", "pause"}, F.soundItem(),
                         {"error_outline", "mist", showMistakes and theme.red or nil, showMistakes},
                         {"refresh", "new"}, {"undo", "undo"}}, w - 16, 14)
  if hit == "sound" then K.setMuted(not K.muted)
  elseif hit == "pause" then F.open("pause")
  elseif hit == "mist" then showMistakes = not showMistakes; saveStats()
  elseif hit == "new" then askNew()
  elseif hit == "undo" then undo() end
  gfx.color(theme.text)
  gfx.text(K.fmtTime(elapsed), w - 16 - 160, 60, 16, "monobold", "right", 160)
  local top, bottom = 84, h - 36
  local landscape = w > h * 1.05
  if landscape then
    local cs = floor(min((bottom - top) / 9, (w - 48) * 0.62 / 9))
    B.cs = cs
    B.x, B.y = 16, floor(top + (bottom - top - cs * 9) / 2)
    pad.vertical = true
    pad.x = B.x + cs * 9 + 20
    pad.w = w - pad.x - 16
    pad.h = min(cs * 9, 4 * 70)
    pad.y = B.y + (cs * 9 - pad.h) / 2
  else
    local padH = 2 * 58 + 8
    local cs = floor(min((w - 32) / 9, (bottom - top - padH - 14) / 9))
    B.cs = cs
    B.x, B.y = floor((w - cs * 9) / 2), top
    pad.vertical = false
    pad.x, pad.w = B.x, cs * 9
    pad.y, pad.h = B.y + cs * 9 + 14, padH
  end
  if state == "gen" or state == "none" then
    gfx.rect(B.x, B.y, B.cs * 9, B.cs * 9, 10, theme.window)
    ui.spinner(B.x + B.cs * 4.5, B.y + B.cs * 4.5 - 14, 14)
    gfx.color(theme.text2)
    gfx.text(TR("generating"), B.x, B.y + B.cs * 4.5 + 10, 14, "medium", "center", B.cs * 9)
    if state == "none" and not genCo then newGame() end
  else
    drawBoard(now)
    drawPad(now)
  end
  drawHints(w, h - 28)
  drawDialogs(w, h)
end

-- ------------------------------------------------------------------ input
function app.event(e)
  K.track(e)
  local t = e.type
  if F.modal() then F.dialogEvent(e); return end
  if state ~= "play" then
    if state == "won" and ((t == "paddown" and e.pad == "a") or (t == "keydown" and e.key == "enter")) then F.open("won") end
    if (t == "paddown" and e.pad == "plus") or (t == "keydown" and e.key == "escape") then F.open("pause") end
    return
  end
  if t == "paddown" then
    local p = e.pad
    local d = F.DIRV[p]
    if d then F.moveCursor(cur, d[1], d[2], 9, 9, true)
    elseif p == "a" then setValue(sel(), digit)
    elseif p == "l" then digit = (digit - 2) % 9 + 1; K.tone(1000, 0.02, 0.08)
    elseif p == "r" then digit = digit % 9 + 1; K.tone(1000, 0.02, 0.08)
    elseif p == "x" then setValue(sel(), 0)
    elseif p == "y" then notesMode = not notesMode; K.tone(notesMode and 880 or 660, 0.04, 0.15, "triangle")
    elseif p == "b" then undo()
    elseif p == "minus" or p == "zr" then hint()
    elseif p == "plus" then F.open("pause") end
  elseif t == "keydown" then
    local k = e.key
    local d = F.DIRV[k]
    local n = tonumber(k)
    if d then F.moveCursor(cur, d[1], d[2], 9, 9, true)
    elseif n and n >= 1 and n <= 9 then digit = n; setValue(sel(), n)
    elseif k == "0" or k == "backspace" or k == "delete" then setValue(sel(), 0)
    elseif k == "n" then notesMode = not notesMode
    elseif k == "z" then undo()
    elseif k == "h" then hint()
    elseif k == "escape" or k == "p" then F.open("pause") end
  elseif t == "mousedown" then
    local c, r = floor((e.x - B.x) / B.cs), floor((e.y - B.y) / B.cs)
    if B.cs > 0 and c >= 0 and r >= 0 and c < 9 and r < 9 then
      cur.x, cur.y = c + 1, r + 1
      K.tone(1100, 0.015, 0.06, "sine")
    end
  end
end

function app.menu()
  return {{title = TR("menu_game"), items = {
    {label = TR("new_puzzle_diff", TR("easy")), id = 11},
    {label = TR("new_puzzle_diff", TR("medium")), id = 12},
    {label = TR("new_puzzle_diff", TR("hard")), id = 13},
    "-",
    {label = TR("undo"), id = 1, shortcut = "Z", enabled = #history > 0},
    {label = TR("hint"), id = 2, shortcut = "H"},
    {label = TR("notes_mode"), id = 3, shortcut = "N", checked = notesMode},
    {label = TR("show_mistakes"), id = 4, checked = showMistakes},
    "-",
    {label = TR("sound"), id = 5, checked = not K.muted},
    {label = TR("stats_title"), id = 6},
  }}}
end

function app.onmenu(id)
  if id >= 11 and id <= 13 then askNew(id - 10)
  elseif id == 1 then undo()
  elseif id == 2 then hint()
  elseif id == 3 then notesMode = not notesMode
  elseif id == 4 then showMistakes = not showMistakes; saveStats()
  elseif id == 5 then K.setMuted(not K.muted)
  elseif id == 6 then F.open("stats") end
end

function app.close()
  saveGame()
  saveStats()
  return true
end

return app
