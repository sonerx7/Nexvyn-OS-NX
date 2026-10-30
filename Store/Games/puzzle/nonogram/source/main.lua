-- Resim Bulmaca / Nonogram for Nexvyn OS: 25 handcrafted picture puzzles (5x5 to 10x10, see levels.lua), fill and
-- cross modes, drag painting, hints, undo, a timer, best times and a level gallery that shows the solved pictures.
local K = require("kit")
local F = require("frame")
local LEVELS = require("levels")
local app = {}

local floor, max, min, abs, sin = math.floor, math.max, math.min, math.abs, math.sin

local level = 1
local W, H = 5, 5
local sol = {}               -- [1..W*H] booleans
local cells = {}             -- 0 empty, 1 filled, 2 cross
local rowClues, colClues = {}, {}
local rowDone, colDone = {}, {}
local history = {}
local crossMode = false
local cur = {x = 1, y = 1}
local elapsed, started, solved = 0, false, false
local solvedAt = 0
local hintsUsed = 0
local best = {}              -- best[name] = seconds
local done = {}              -- done[name] = true
local stats = {hints = 0}
local fx = K.particles()
local B = {x = 0, y = 0, cs = 0, cw = 0, ch = 0}
local drag = nil             -- {value, axis, x0, y0, batch}
local padPaint = nil         -- value painted while A / X is held
local pick = {x = 1, y = 1}
local newRecord = false

local function idx(x, y) return (y - 1) * W + x end

local function clueOf(get, n)
  local c, run = {}, 0
  for k = 1, n do
    if get(k) then run = run + 1 elseif run > 0 then c[#c + 1] = run; run = 0 end
  end
  if run > 0 then c[#c + 1] = run end
  return c
end

local function same(a, b)
  if #a ~= #b then return false end
  for k = 1, #a do if a[k] ~= b[k] then return false end end
  return true
end

local function refreshDone()
  for y = 1, H do
    rowDone[y] = same(clueOf(function(x) return cells[idx(x, y)] == 1 end, W), rowClues[y])
  end
  for x = 1, W do
    colDone[x] = same(clueOf(function(y) return cells[idx(x, y)] == 1 end, H), colClues[x])
  end
end

-- ------------------------------------------------------------------ persistence
local function saveProgress()
  store.set("best", best)
  store.set("done", done)
  store.set("stats", stats)
  store.set("level", level)
  store.set("cur", {level = level, cells = cells, time = elapsed, started = started, hints = hintsUsed, solved = solved})
end

local function loadLevel(n, resume)
  level = K.clamp(n, 1, #LEVELS)
  local L = LEVELS[level]
  H = #L.rows
  W = #L.rows[1]
  sol, cells, history = {}, {}, {}
  for y = 1, H do
    for x = 1, W do
      sol[idx(x, y)] = L.rows[y]:sub(x, x) == "#"
      cells[idx(x, y)] = 0
    end
  end
  rowClues, colClues = {}, {}
  for y = 1, H do rowClues[y] = clueOf(function(x) return sol[idx(x, y)] end, W) end
  for x = 1, W do colClues[x] = clueOf(function(y) return sol[idx(x, y)] end, H) end
  elapsed, started, solved, hintsUsed, newRecord = 0, false, false, 0, false
  if resume and type(resume.cells) == "table" and #resume.cells == W * H and not resume.solved then
    for i = 1, W * H do cells[i] = K.clamp(floor(tonumber(resume.cells[i]) or 0), 0, 2) end
    elapsed = tonumber(resume.time) or 0
    started = resume.started == true
    hintsUsed = tonumber(resume.hints) or 0
  end
  cur.x, cur.y = math.ceil(W / 2), math.ceil(H / 2)
  refreshDone()
  F.play()
  saveProgress()
end

-- ------------------------------------------------------------------ rules
local function checkWin()
  for y = 1, H do if not rowDone[y] then return false end end
  for x = 1, W do if not colDone[x] then return false end end
  return true
end

local function onSolved()
  solved = true
  solvedAt = sys.time()
  local name = LEVELS[level].name
  done[name] = true
  newRecord = not best[name] or elapsed < best[name]
  if newRecord then best[name] = elapsed end
  for i = 1, W * H do if cells[i] ~= 1 then cells[i] = 0 end end
  saveProgress()
  F.winSound()
  K.rumble(0.5, 90)
  timer.after(0.5, function() F.celebrate(fx, B.x, B.y, B.cw, B.ch) end)
  timer.after(2.0, function() if solved and F.scene == "play" then F.open("won") end end)
end

-- sets cell i to v, recording the old value in batch
local function setCell(i, v, batch)
  if cells[i] == v then return false end
  batch[#batch + 1] = {i, cells[i]}
  cells[i] = v
  return true
end

local function commit(batch)
  if #batch == 0 then return end
  history[#history + 1] = batch
  if #history > 300 then table.remove(history, 1) end
  if not started then started = true end
  refreshDone()
  if checkWin() then onSolved() else saveProgress() end
end

local function sound(v)
  if v == 1 then K.tone(520, 0.03, 0.14, "triangle") elseif v == 2 then K.tone(300, 0.03, 0.1, "square")
  else K.tone(400, 0.02, 0.08, "sine") end
end

local function undo()
  if solved or F.modal() then return end
  local b = table.remove(history)
  if not b then K.tone(160, 0.05, 0.12, "square"); return end
  for k = #b, 1, -1 do cells[b[k][1]] = b[k][2] end
  refreshDone()
  K.tone(600, 0.05, 0.16, "triangle")
  saveProgress()
end

local function hint()
  if solved or F.modal() then return end
  -- a wrong cell first, otherwise a missing one near the cursor
  local bestI, bestD = nil, 1e9
  for pass = 1, 2 do
    for i = 1, W * H do
      local wrong = (pass == 1 and cells[i] == 1 and not sol[i]) or (pass == 2 and sol[i] and cells[i] ~= 1)
      if wrong then
        local x, y = (i - 1) % W + 1, (i - 1) // W + 1
        local d = abs(x - cur.x) + abs(y - cur.y)
        if d < bestD then bestI, bestD = i, d end
      end
    end
    if bestI then break end
  end
  if not bestI then return end
  local b = {}
  setCell(bestI, sol[bestI] and 1 or 2, b)
  cur.x, cur.y = (bestI - 1) % W + 1, (bestI - 1) // W + 1
  hintsUsed = hintsUsed + 1
  stats.hints = stats.hints + 1
  F.chord({660, 880, 1100}, 0.2, 0.2, "sine")
  commit(b)
end

local function clearBoard()
  if solved or F.modal() then return end
  local b = {}
  for i = 1, W * H do setCell(i, 0, b) end
  if #b > 0 then history[#history + 1] = b; refreshDone(); saveProgress() end
  K.play("pop", 0.5)
end

-- ------------------------------------------------------------------ app
function app.load()
  K.loadPrefs()
  local b = store.get("best", {})
  best = type(b) == "table" and b or {}
  local d = store.get("done", {})
  done = type(d) == "table" and d or {}
  local s = store.get("stats", {})
  if type(s) == "table" then stats.hints = tonumber(s.hints) or 0 end
  local c = store.get("cur")
  if type(c) == "table" and tonumber(c.level) then loadLevel(floor(c.level), c)
  else loadLevel(1) end
  F.open("title")
end

local saveAcc = 0
function app.update(dt)
  fx:update(dt)
  if started and not solved and F.scene == "play" then
    elapsed = elapsed + dt
    saveAcc = saveAcc + dt
    if saveAcc > 5 then saveAcc = 0; saveProgress() end
  end
  local d = F.stick(dt)
  if d and F.scene == "play" and not solved then
    F.moveCursor(cur, F.DIRV[d][1], F.DIRV[d][2], W, H, false)
    if padPaint then
      local b = {}
      if setCell(idx(cur.x, cur.y), padPaint, b) then sound(padPaint) end
      commit(b)
    end
  elseif d and F.scene == "levels" then
    F.moveCursor(pick, F.DIRV[d][1], F.DIRV[d][2], 5, 5, true)
  end
end

-- ------------------------------------------------------------------ drawing
local function clueText(c) if #c == 0 then return {"0"} end return c end

local function drawBoard(now)
  local cs = B.cs
  local col = LEVELS[level].color
  local reveal = solved and K.clamp((now - solvedAt - 0.2) / 0.8, 0, 1) or 0
  -- clues
  local fsz = max(9, min(16, cs * 0.5))
  for y = 1, H do
    local c = clueText(rowClues[y])
    local yy = B.y + (y - 1) * cs
    if cur.y == y and not solved then gfx.rect(B.x - B.rw, yy, B.rw - 2, cs, 4, K.col(theme.accent, 0.1)) end
    gfx.color(rowDone[y] and theme.text3 or theme.text)
    local x = B.x - 6
    for k = #c, 1, -1 do
      local s = tostring(c[k])
      local tw = gfx.textWidth(s, fsz, "semibold")
      x = x - tw
      gfx.text(s, x, yy + (cs - gfx.textHeight(fsz, "semibold")) / 2, fsz, "semibold")
      x = x - fsz * 0.55
    end
  end
  for x = 1, W do
    local c = clueText(colClues[x])
    local xx = B.x + (x - 1) * cs
    if cur.x == x and not solved then gfx.rect(xx, B.y - B.ch2, cs, B.ch2 - 2, 4, K.col(theme.accent, 0.1)) end
    gfx.color(colDone[x] and theme.text3 or theme.text)
    local y = B.y - 4
    for k = #c, 1, -1 do
      y = y - fsz * 1.2
      gfx.text(tostring(c[k]), xx, y, fsz, "semibold", "center", cs)
    end
  end
  -- grid
  gfx.shadow(B.x, B.y, cs * W, cs * H, 6, 14, 3)
  gfx.rect(B.x, B.y, cs * W, cs * H, 4, theme.window)
  for y = 1, H do
    for x = 1, W do
      local i = idx(x, y)
      local px, py = B.x + (x - 1) * cs, B.y + (y - 1) * cs
      local v = cells[i]
      if v == 1 then
        local c = reveal > 0 and K.mix(theme.text, col, reveal) or (theme.dark and "#D0D4DC" or "#2D3340")
        local wave = 0
        if solved then
          local k = now - solvedAt - (x + y) * 0.04
          if k > 0 and k < 0.3 then wave = sin(k / 0.3 * math.pi) * 0.12 end
        end
        local inset = 1 - wave * cs * 0.5
        gfx.rect(px + inset, py + inset, cs - 2 * inset, cs - 2 * inset, 3, c)
      elseif v == 2 then
        gfx.color(K.col(theme.text, 0.35))
        local m = cs * 0.3
        gfx.line(px + m, py + m, px + cs - m, py + cs - m, 1.5)
        gfx.line(px + cs - m, py + m, px + m, py + cs - m, 1.5)
      end
    end
  end
  for k = 0, W do
    local th = (k % 5 == 0) and 2 or 1
    gfx.color(K.col(theme.text, k % 5 == 0 and 0.55 or 0.15))
    gfx.line(B.x + k * cs, B.y, B.x + k * cs, B.y + cs * H, th)
  end
  for k = 0, H do
    local th = (k % 5 == 0) and 2 or 1
    gfx.color(K.col(theme.text, k % 5 == 0 and 0.55 or 0.15))
    gfx.line(B.x, B.y + k * cs, B.x + cs * W, B.y + k * cs, th)
  end
  if not solved and not F.modal() then
    gfx.color(K.col(crossMode and theme.red or theme.accent, 0.7 + 0.3 * sin(now * 6)))
    gfx.rectLine(B.x + (cur.x - 1) * cs + 1, B.y + (cur.y - 1) * cs + 1, cs - 2, cs - 2, 3, 3)
  end
  fx:draw()
end

local function drawThumb(L, x, y, s, show)
  local h, w = #L.rows, #L.rows[1]
  local c = s / max(w, h)
  local ox, oy = x + (s - c * w) / 2, y + (s - c * h) / 2
  for yy = 1, h do
    for xx = 1, w do
      if L.rows[yy]:sub(xx, xx) == "#" then gfx.rect(ox + (xx - 1) * c, oy + (yy - 1) * c, c, c, 0, show and L.color or K.col(theme.text, 0.1)) end
    end
  end
end

local function picName(i)
  local n = LEVELS[i].name
  return ({heart = TR("pic_heart"), house = TR("pic_house"), arrow = TR("pic_arrow"), smile = TR("pic_smile"),
    snowflake = TR("pic_snowflake"), key = TR("pic_key"), tree = TR("pic_tree"), cat = TR("pic_cat"), boat = TR("pic_boat"),
    mushroom = TR("pic_mushroom"), star = TR("pic_star"), drop = TR("pic_drop"), ghost = TR("pic_ghost"),
    note = TR("pic_note"), cup = TR("pic_cup"), sun = TR("pic_sun"), apple = TR("pic_apple"), umbrella = TR("pic_umbrella"),
    fish = TR("pic_fish"), rocket = TR("pic_rocket"), car = TR("pic_car"), bell = TR("pic_bell"), flower = TR("pic_flower"),
    anchor = TR("pic_anchor"), castle = TR("pic_castle")})[n] or n
end

local function drawLevels(w, h, now)
  K.dim(w, h, 1)
  local cols = 5
  local rows = math.ceil(#LEVELS / cols)
  local cell = floor(min(92, (w - 70) / cols, (h - 150) / rows))
  local gw, gh = cell * cols, cell * rows
  local x0, y0 = floor((w - gw) / 2), floor((h - gh) / 2) + 6
  K.card(x0 - 16, y0 - 52, gw + 32, gh + 108, 16)
  gfx.color(theme.text)
  local cnt = 0
  for _ in pairs(done) do cnt = cnt + 1 end
  gfx.text(TR("gallery", cnt, #LEVELS), x0 - 16, y0 - 40, 18, "bold", "center", gw + 32)
  for i, L in ipairs(LEVELS) do
    local cx, cy = (i - 1) % cols, (i - 1) // cols
    local x, y = x0 + cx * cell + 4, y0 + cy * cell + 4
    local s = cell - 8
    local hit = ui.hit("lv" .. i, x, y, s, s)
    local isDone = done[L.name]
    gfx.rect(x, y, s, s, 10, hit.hovered and theme.hover or theme.control)
    gfx.color(i == level and theme.accent or theme.separator)
    gfx.rectLine(x, y, s, s, 10, i == level and 2 or 1)
    if isDone then
      drawThumb(L, x + s * 0.15, y + s * 0.08, s * 0.7, true)
    else
      gfx.color(theme.text3)
      F.ctext("?", x, y - s * 0.08, s, s, s * 0.4, "bold")
    end
    gfx.color(theme.text2)
    gfx.text(#L.rows[1] .. "×" .. #L.rows, x, y + s - 15, 10, "semibold", "center", s)
    if pick.x == cx + 1 and pick.y == cy + 1 then K.ring(x - 3, y - 3, s + 6, s + 6, 12) end
    if hit.clicked then loadLevel(i); K.play("pop", 0.5) end
  end
  if ui.button(TR("close") .. "##lv", x0 + gw / 2 - 70, y0 + gh + 12, 140, 34) then F.close() end
end

local function drawHints(w, y)
  if K.lastInput == "pad" then
    K.hints({{"dpad", TR("h_move")}, {"A", TR("h_fill")}, {"X", TR("h_cross")}, {"B", TR("h_undo")}, {"Y", TR("h_hint")},
             {"-", TR("levels")}, {"+", TR("h_pause")}}, 0, y, w)
  elseif K.lastInput == "key" then
    K.hints({{TR("k_arrows"), TR("h_move")}, {"Space", TR("h_fill")}, {"X", TR("h_cross")}, {"Z", TR("h_undo")},
             {"H", TR("h_hint")}, {"L", TR("levels")}, {"Esc", TR("h_pause")}}, 0, y, w)
  else
    K.hints({{"touch", TR("h_drag")}}, 0, y, w)
  end
end

local function drawDialogs(w, h, now)
  local s = F.scene
  if s == "pause" then
    F.pauseDialog(w, h, {onRestart = function() loadLevel(level) end, onMenu = function() F.open("title") end})
  elseif s == "levels" then
    drawLevels(w, h, now)
  elseif s == "won" then
    local name = LEVELS[level].name
    local buttons = {}
    if level < #LEVELS then buttons[1] = {TR("next_level"), function() loadLevel(level + 1) end, "primary", "arrow_forward"} end
    buttons[#buttons + 1] = {TR("levels"), function() F.open("levels") end, "default", "grid_view"}
    buttons[#buttons + 1] = {TR("close"), F.close}
    K.dialog(F.dlg, w, h, {icon = "emoji_events", iconColor = theme.yellow, title = picName(level),
      subtitle = newRecord and TR("new_record") or TR("solved"),
      lines = {{TR("time"), K.fmtTime(elapsed)}, {TR("best_time"), K.fmtTime(best[name] or elapsed)},
               {TR("hints_used"), tostring(hintsUsed)}},
      buttons = buttons})
  else
    F.commonDialogs(w, h, {
      stats = function()
        local cnt, total = 0, 0
        for _, L in ipairs(LEVELS) do
          if done[L.name] then cnt = cnt + 1; total = total + (best[L.name] or 0) end
        end
        return {{TR("solved_count"), cnt .. " / " .. #LEVELS}, {TR("total_time"), K.fmtTime(total)},
                {TR("hints_used"), tostring(stats.hints)}}
      end,
      onReset = function() best = {}; done = {}; stats.hints = 0; saveProgress() end,
      onNew = function() loadLevel(level) end,
    })
  end
end

local function drawTitle(w, h)
  local cnt = 0
  for _ in pairs(done) do cnt = cnt + 1 end
  F.titleScreen(w, h, {icon = "image", c1 = "#F9A8D4", c2 = "#BE185D", title = TR("title"), subtitle = TR("tagline"),
    buttons = {{(started and not solved) and TR("continue") or TR("play"), function()
                  if solved then loadLevel(level < #LEVELS and level + 1 or 1) else F.play() end
                end, "primary", "play_arrow"},
               {TR("levels"), function() pick.x, pick.y = (level - 1) % 5 + 1, (level - 1) // 5 + 1; F.open("levels") end, "default", "grid_view"},
               {TR("how_to"), function() F.open("help") end, "default", "help"},
               {TR("stats_title"), function() F.open("stats") end, "default", "bar_chart"}},
    footer = TR("gallery", cnt, #LEVELS)})
  if F.scene == "help" then
    K.dialog(F.dlg, w, h, {icon = "help", title = TR("how_to"), subtitle = TR("help_text"), width = 400,
      buttons = {{TR("close"), function() F.open("title") end}}})
  end
end

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  if F.scene == "title" or F.scene == "help" or (F.scene ~= "play" and F.returnTo == "title") then
    drawTitle(w, h)
    if F.scene ~= "title" and F.scene ~= "help" then drawDialogs(w, h, now) end
    return
  end
  F.title(TR("title"), TR("level_line", level, #LEVELS, W, H) .. " · " .. K.fmtTime(elapsed), 16, 10)
  local hit = F.toolbar({{"pause", "pause"}, F.soundItem(), {"grid_view", "levels"}, {"delete_sweep", "clear"},
                         {"lightbulb", "hint"}, {"undo", "undo"}}, w - 16, 14)
  if hit == "sound" then K.setMuted(not K.muted)
  elseif hit == "pause" then F.open("pause")
  elseif hit == "levels" then pick.x, pick.y = (level - 1) % 5 + 1, (level - 1) // 5 + 1; F.open("levels")
  elseif hit == "clear" then clearBoard()
  elseif hit == "hint" then hint()
  elseif hit == "undo" then undo() end
  local nm = ui.segmented("mode", {TR("mode_fill"), TR("mode_cross")}, crossMode and 2 or 1, 16, 62, min(260, w - 32), 32)
  if nm ~= (crossMode and 2 or 1) and not F.modal() then crossMode = nm == 2; K.lastInput = "pointer" end
  -- layout: clue space on the left and top
  local maxR, maxC = 1, 1
  for y = 1, H do maxR = max(maxR, #rowClues[y]) end
  for x = 1, W do maxC = max(maxC, #colClues[x]) end
  local top, bottom = 104, h - 36
  local cs = floor(min((w - 40) / (W + maxR * 0.8), (bottom - top) / (H + maxC * 0.75), 56))
  local fsz = max(9, min(16, cs * 0.5))
  B.rw = maxR * fsz * 1.2 + 10
  B.ch2 = maxC * fsz * 1.2 + 8
  B.cs = cs
  B.cw, B.ch = cs * W, cs * H
  local totalW, totalH = B.rw + cs * W, B.ch2 + cs * H
  B.x = floor((w - totalW) / 2 + B.rw)
  B.y = floor(top + (bottom - top - totalH) / 2 + B.ch2)
  drawBoard(now)
  drawHints(w, h - 28)
  drawDialogs(w, h, now)
end

-- ------------------------------------------------------------------ input
local function cellAt(x, y)
  if B.cs <= 0 then return nil end
  local cx, cy = floor((x - B.x) / B.cs) + 1, floor((y - B.y) / B.cs) + 1
  if cx < 1 or cy < 1 or cx > W or cy > H then return nil end
  return cx, cy
end

local function levelsEvent(e)
  local t = e.type
  local k = t == "paddown" and e.pad or (t == "keydown" and e.key) or nil
  if not k then return end
  local d = F.DIRV[k]
  if d then F.moveCursor(pick, d[1], d[2], 5, 5, true)
  elseif (t == "paddown" and k == "a") or (t == "keydown" and (k == "enter" or k == "space")) then
    local i = (pick.y - 1) * 5 + pick.x
    if LEVELS[i] then loadLevel(i); K.play("pop", 0.5) end
  elseif (t == "paddown" and (k == "b" or k == "minus")) or (t == "keydown" and k == "escape") then F.close() end
end

local function padAct(v)
  local i = idx(cur.x, cur.y)
  local target = cells[i] == v and 0 or v
  padPaint = target
  local b = {}
  if setCell(i, target, b) then sound(target) end
  commit(b)
end

function app.event(e)
  K.track(e)
  local t = e.type
  if F.scene == "levels" then levelsEvent(e); return end
  if F.scene == "help" then
    if (t == "paddown" and (e.pad == "a" or e.pad == "b")) or (t == "keydown" and (e.key == "enter" or e.key == "escape")) then
      F.open("title")
    end
    return
  end
  if F.modal() then F.dialogEvent(e); return end
  if t == "paddown" then
    local p = e.pad
    local d = F.DIRV[p]
    if solved then
      if p == "a" then F.open("won") elseif p == "minus" then F.open("levels") elseif p == "plus" then F.open("pause") end
      return
    end
    if d then
      F.moveCursor(cur, d[1], d[2], W, H, false)
      if padPaint then
        local b = {}
        if setCell(idx(cur.x, cur.y), padPaint, b) then sound(padPaint) end
        commit(b)
      end
    elseif p == "a" then padAct(crossMode and 2 or 1)
    elseif p == "x" then padAct(crossMode and 1 or 2)
    elseif p == "b" then undo()
    elseif p == "y" then hint()
    elseif p == "l" and level > 1 then loadLevel(level - 1)
    elseif p == "r" and level < #LEVELS then loadLevel(level + 1)
    elseif p == "minus" then pick.x, pick.y = (level - 1) % 5 + 1, (level - 1) // 5 + 1; F.open("levels")
    elseif p == "plus" then F.open("pause") end
  elseif t == "padup" then
    if e.pad == "a" or e.pad == "x" then padPaint = nil end
  elseif t == "keydown" then
    local k = e.key
    local d = F.DIRV[k]
    if solved then
      if k == "enter" or k == "space" then F.open("won") elseif k == "escape" then F.open("pause") end
      return
    end
    if d then F.moveCursor(cur, d[1], d[2], W, H, false)
    elseif k == "space" or k == "enter" then padAct(crossMode and 2 or 1); padPaint = nil
    elseif k == "x" then padAct(crossMode and 1 or 2); padPaint = nil
    elseif k == "z" or k == "backspace" then undo()
    elseif k == "h" then hint()
    elseif k == "m" then crossMode = not crossMode
    elseif k == "l" then F.open("levels")
    elseif k == "escape" or k == "p" then F.open("pause") end
  elseif t == "mousedown" then
    if solved then return end
    local cx, cy = cellAt(e.x, e.y)
    if cx then
      local i = idx(cx, cy)
      local mode = (e.button == "right") and (crossMode and 1 or 2) or (crossMode and 2 or 1)
      local v = cells[i] == mode and 0 or mode
      drag = {value = v, x0 = cx, y0 = cy, axis = nil, batch = {}}
      cur.x, cur.y = cx, cy
      if setCell(i, v, drag.batch) then sound(v) end
      refreshDone()
    end
  elseif t == "mousemove" then
    if drag then
      local cx, cy = cellAt(e.x, e.y)
      if cx then
        if not drag.axis and (cx ~= drag.x0 or cy ~= drag.y0) then drag.axis = (cx ~= drag.x0) and "x" or "y" end
        if drag.axis == "x" then cy = drag.y0 elseif drag.axis == "y" then cx = drag.x0 end
        -- fill every cell between the start and the pointer on the locked axis
        local x1, x2 = min(drag.x0, cx), max(drag.x0, cx)
        local y1, y2 = min(drag.y0, cy), max(drag.y0, cy)
        for yy = y1, y2 do
          for xx = x1, x2 do
            if setCell(idx(xx, yy), drag.value, drag.batch) then sound(drag.value) end
          end
        end
        cur.x, cur.y = cx, cy
        refreshDone()
      end
    end
  elseif t == "mouseup" then
    if drag then
      local b = drag.batch
      drag = nil
      commit(b)
    end
  end
end

function app.menu()
  return {{title = TR("menu_game"), items = {
    {label = TR("restart"), id = 1},
    {label = TR("levels"), id = 2, shortcut = "L"},
    {label = TR("undo"), id = 3, shortcut = "Z", enabled = #history > 0},
    {label = TR("hint"), id = 4, shortcut = "H"},
    {label = TR("mode_cross"), id = 5, checked = crossMode, shortcut = "M"},
    "-",
    {label = TR("sound"), id = 6, checked = not K.muted},
    {label = TR("stats_title"), id = 7},
  }}}
end

function app.onmenu(id)
  if id == 1 then loadLevel(level)
  elseif id == 2 then F.open("levels")
  elseif id == 3 then undo()
  elseif id == 4 then hint()
  elseif id == 5 then crossMode = not crossMode
  elseif id == 6 then K.setMuted(not K.muted)
  elseif id == 7 then F.open("stats") end
end

function app.close()
  saveProgress()
  return true
end

return app
