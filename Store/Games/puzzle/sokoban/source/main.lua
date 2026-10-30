-- Sokoban for Nexvyn OS: push every crate onto a goal. 20 solver-verified levels, unlimited undo, restart, level
-- select with records, smooth movement, hold-to-repeat, tap-to-walk path finding and swipes.
local K = require("kit")
local F = require("frame")
local LEVELS = require("levels")
local app = {}

local floor, max, min, abs, sin = math.floor, math.max, math.min, math.abs, math.sin

local STEP = 0.085
local DIRS = {up = {0, -1}, down = {0, 1}, left = {-1, 0}, right = {1, 0}}
local KEYDIR = {up = "up", down = "down", left = "left", right = "right", w = "up", s = "down", a = "left", d = "right"}

local level = 1
local W, H = 0, 0
local tile = {}              -- tile[i]: 0 void, 1 floor, 2 wall
local goal = {}
local boxAt = {}             -- boxAt[i] = box id
local boxes = {}             -- boxes[id] = {i, from, t}
local player = {i = 1, from = 1, t = -10, face = "down"}
local history = {}           -- {dir, pushedBoxId}
local moves, pushes = 0, 0
local solved = false
local solvedAt = 0
local best = {}              -- best[level] = {moves, pushes}
local walkQueue = {}
local held, nextRep = nil, 0
local fx = K.particles()
local B = {x = 0, y = 0, cs = 0}
local press = nil
local pick = {x = 1, y = 1}
local stickSt = {}
local newRecord = false

local function idx(x, y) return (y - 1) * W + x end
local function xy(i) return (i - 1) % W + 1, (i - 1) // W + 1 end
local function step(i, d)
  local x, y = xy(i)
  x, y = x + DIRS[d][1], y + DIRS[d][2]
  if x < 1 or y < 1 or x > W or y > H then return nil end
  return idx(x, y)
end

-- ------------------------------------------------------------------ levels
local function parse(n)
  local L = LEVELS[n]
  H = #L.rows
  W = 0
  for _, r in ipairs(L.rows) do W = max(W, #r) end
  tile, goal, boxAt, boxes = {}, {}, {}, {}
  local start
  for y = 1, H do
    local r = L.rows[y]
    for x = 1, W do
      local ch = r:sub(x, x)
      local i = idx(x, y)
      tile[i] = ch == "#" and 2 or 0
      if ch == "." or ch == "*" or ch == "+" then goal[i] = true end
      if ch == "$" or ch == "*" then boxes[#boxes + 1] = {i = i, from = i, t = -10}; boxAt[i] = #boxes end
      if ch == "@" or ch == "+" then start = i end
    end
  end
  -- floor = everything reachable from the player without crossing walls (the rest is outside)
  local q, head = {start}, 1
  tile[start] = 1
  while head <= #q do
    local c = q[head]
    head = head + 1
    for d in pairs(DIRS) do
      local n2 = step(c, d)
      if n2 and tile[n2] == 0 then tile[n2] = 1; q[#q + 1] = n2 end
    end
  end
  player = {i = start, from = start, t = -10, face = "down"}
end

local function saveProgress()
  local hs = {}
  for k, h in ipairs(history) do hs[k] = h.d end
  store.set("best", best)
  store.set("cur", {level = level, moves = hs})
end

local function bestOf(n)
  local b = best[tostring(n)]
  if type(b) == "table" and tonumber(b.moves) then return b end
  return nil
end

local function isSolved()
  for _, b in ipairs(boxes) do if not goal[b.i] then return false end end
  return true
end

local function onSolved()
  solved = true
  solvedAt = sys.time()
  local b = bestOf(level)
  newRecord = not b or moves < b.moves
  if newRecord then best[tostring(level)] = {moves = moves, pushes = pushes} end
  saveProgress()
  F.winSound()
  K.rumble(0.5, 90)
  timer.after(0.15, function() F.celebrate(fx, B.x, B.y, B.cs * W, B.cs * H) end)
  timer.after(1.3, function() if solved and F.scene == "play" then F.open("won") end end)
end

-- one step in direction d; silent = replaying a saved game
local function move(d, silent)
  if solved then return false end
  local n = step(player.i, d)
  player.face = d
  if not n or tile[n] ~= 1 then
    if not silent then K.tone(120, 0.04, 0.1, "square") end
    return false
  end
  local now = silent and -10 or sys.time()
  local pushed = nil
  local bid = boxAt[n]
  if bid then
    local n2 = step(n, d)
    if not n2 or tile[n2] ~= 1 or boxAt[n2] then
      if not silent then K.tone(140, 0.05, 0.12, "square"); K.rumble(0.15, 15) end
      return false
    end
    local bx = boxes[bid]
    boxAt[n] = nil
    boxAt[n2] = bid
    bx.from, bx.i, bx.t = n, n2, now
    pushed = bid
    pushes = pushes + 1
    if not silent then
      if goal[n2] then
        F.chord({659, 880}, 0.15, 0.22)
        local x, y = xy(n2)
        fx:burst(B.x + (x - 0.5) * B.cs, B.y + (y - 0.5) * B.cs, 14, theme.green, B.cs * 2, 0.5, 3, 0, 3)
      else
        K.tone(200, 0.06, 0.2, "triangle")
      end
      K.rumble(0.12, 12)
    end
  elseif not silent then
    K.tone(700 + (moves % 2) * 60, 0.015, 0.05, "sine")
  end
  player.from, player.i, player.t = player.i, n, now
  history[#history + 1] = {d = d, box = pushed}
  moves = moves + 1
  if not silent then
    if isSolved() then onSolved() elseif moves % 10 == 0 then saveProgress() end
  end
  return true
end

local function loadLevel(n, replay)
  level = K.clamp(n, 1, #LEVELS)
  parse(level)
  history, moves, pushes, solved, walkQueue, newRecord = {}, 0, 0, false, {}, false
  if type(replay) == "table" then
    for _, d in ipairs(replay) do if DIRS[d] then move(d, true) end end
    if isSolved() then parse(level); history, moves, pushes = {}, 0, 0 end
  end
  F.play()
  saveProgress()
end

local function undo()
  if solved or F.modal() then return end
  walkQueue = {}
  local h = table.remove(history)
  if not h then K.tone(160, 0.05, 0.12, "square"); return end
  local d = h.d
  local back = d == "up" and "down" or d == "down" and "up" or d == "left" and "right" or "left"
  local now = sys.time()
  local prev = step(player.i, back)
  if h.box then
    local bx = boxes[h.box]
    boxAt[bx.i] = nil
    boxAt[player.i] = h.box
    bx.from, bx.i, bx.t = bx.i, player.i, now
    pushes = pushes - 1
  end
  player.from, player.i, player.t = player.i, prev, now
  player.face = d
  moves = moves - 1
  K.tone(500, 0.04, 0.12, "triangle")
end

local function restart()
  loadLevel(level)
  K.play("pop", 0.5)
end

-- shortest walk to target (boxes block), as a list of directions
local function pathTo(target)
  if tile[target] ~= 1 or boxAt[target] then return nil end
  local prev, q, head = {[player.i] = false}, {player.i}, 1
  while head <= #q do
    local c = q[head]
    head = head + 1
    if c == target then break end
    for d in pairs(DIRS) do
      local n = step(c, d)
      if n and tile[n] == 1 and not boxAt[n] and prev[n] == nil then prev[n] = {c, d}; q[#q + 1] = n end
    end
  end
  if prev[target] == nil then return nil end
  local path = {}
  local c = target
  while prev[c] do
    table.insert(path, 1, prev[c][2])
    c = prev[c][1]
  end
  return path
end

-- ------------------------------------------------------------------ app
function app.load()
  K.loadPrefs()
  local b = store.get("best", {})
  best = type(b) == "table" and b or {}
  local c = store.get("cur")
  if type(c) == "table" and tonumber(c.level) then loadLevel(floor(c.level), c.moves) else loadLevel(1) end
  F.open("title")
end

local function busy() return sys.time() - player.t < STEP end

function app.update(dt)
  fx:update(dt)
  local now = sys.time()
  if F.scene == "play" and not solved then
    if #walkQueue > 0 and not busy() then
      local d = table.remove(walkQueue, 1)
      if not move(d) then walkQueue = {} end
    end
    if held and now >= nextRep and not busy() then
      move(held)
      nextRep = now + 0.11
    end
    local d = K.dirInput(stickSt, dt, {dpad = false, rate = 0.13, delay = 0.25})
    if d then walkQueue = {}; move(d) end
  elseif F.scene == "levels" then
    local d = F.stick(dt)
    if d then F.moveCursor(pick, F.DIRV[d][1], F.DIRV[d][2], 5, 4, true) end
  else
    F.stick(dt)
  end
end

-- ------------------------------------------------------------------ drawing
local function lerpPos(from, to, t, now)
  local p = K.easeOut(min(1, (now - t) / STEP))
  local fx0, fy0 = xy(from)
  local tx, ty = xy(to)
  return K.lerp(fx0, tx, p), K.lerp(fy0, ty, p)
end

local function drawLevel(now)
  local cs = B.cs
  local dark = theme.dark
  local floorA, floorB = dark and "#2B2F36" or "#E9E3D5", dark and "#272A31" or "#E1DACA"
  local wallTop, wallSide = dark and "#59606C" or "#8C7A68", dark and "#3C424C" or "#6B5A4A"
  for y = 1, H do
    for x = 1, W do
      local i = idx(x, y)
      local px, py = B.x + (x - 1) * cs, B.y + (y - 1) * cs
      if tile[i] == 1 then
        gfx.rect(px, py, cs, cs, 0, (x + y) % 2 == 0 and floorA or floorB)
        if goal[i] then
          local pulse = 0.75 + 0.25 * sin(now * 3 + i)
          gfx.circle(px + cs / 2, py + cs / 2, cs * 0.22, K.col(theme.green, 0.25 * pulse))
          gfx.color(K.col(theme.green, 0.8))
          gfx.circleLine(px + cs / 2, py + cs / 2, cs * 0.2, 2)
        end
      elseif tile[i] == 2 then
        -- only draw walls that touch the floor
        local near = false
        for dy = -1, 1 do
          for dx = -1, 1 do
            local nx, ny = x + dx, y + dy
            if nx >= 1 and ny >= 1 and nx <= W and ny <= H and tile[idx(nx, ny)] == 1 then near = true end
          end
        end
        if near then
          gfx.rect(px, py, cs, cs, cs * 0.12, wallSide)
          gfx.rect(px + 1, py + 1, cs - 2, cs * 0.78, cs * 0.12, wallTop)
          gfx.color(K.col("#FFFFFF", 0.12))
          gfx.line(px + cs * 0.15, py + cs * 0.22, px + cs * 0.85, py + cs * 0.22, 1)
        end
      end
    end
  end
  -- boxes
  for _, b in ipairs(boxes) do
    local x, y = lerpPos(b.from, b.i, b.t, now)
    local px, py = B.x + (x - 1) * cs, B.y + (y - 1) * cs
    local onGoal = goal[b.i] and now - b.t >= STEP
    local m = cs * 0.08
    local s = cs - 2 * m
    gfx.shadow(px + m, py + m, s, s, cs * 0.1, 6, 2)
    local c1 = onGoal and "#66BB6A" or "#D7A35F"
    local c2 = onGoal and "#388E3C" or "#A86F32"
    gfx.gradient(px + m, py + m, s, s, c1, c2, false, cs * 0.1)
    gfx.color(K.col("#000000", 0.25))
    gfx.rectLine(px + m + cs * 0.1, py + m + cs * 0.1, s - cs * 0.2, s - cs * 0.2, cs * 0.05, max(1.5, cs * 0.05))
    gfx.line(px + m + cs * 0.12, py + m + cs * 0.12, px + m + s - cs * 0.12, py + m + s - cs * 0.12, max(1.5, cs * 0.05))
    gfx.line(px + m + s - cs * 0.12, py + m + cs * 0.12, px + m + cs * 0.12, py + m + s - cs * 0.12, max(1.5, cs * 0.05))
    if onGoal then gfx.icon("check", px + cs / 2, py + cs / 2, cs * 0.4, "#FFFFFF") end
  end
  -- player
  local x, y = lerpPos(player.from, player.i, player.t, now)
  local cx, cy = B.x + (x - 0.5) * cs, B.y + (y - 0.5) * cs
  local bob = (now - player.t < STEP) and -sin((now - player.t) / STEP * math.pi) * cs * 0.06 or 0
  if solved then bob = -abs(sin((now - solvedAt) * 8)) * cs * 0.12 end
  gfx.circle(cx, cy + cs * 0.3, cs * 0.26, K.col("#000000", 0.2))
  gfx.circle(cx, cy + bob, cs * 0.34, theme.accent)
  gfx.circle(cx, cy + bob - cs * 0.04, cs * 0.3, K.mix(theme.accent, "#FFFFFF", 0.15))
  local fdx, fdy = DIRS[player.face][1], DIRS[player.face][2]
  for s = -1, 1, 2 do
    local ex = cx + fdx * cs * 0.12 + (fdy ~= 0 and s * cs * 0.1 or 0)
    local ey = cy + bob - cs * 0.06 + fdy * cs * 0.1 + (fdx ~= 0 and s * cs * 0.06 or 0)
    gfx.circle(ex, ey, cs * 0.07, "#FFFFFF")
    gfx.circle(ex + fdx * cs * 0.025, ey + fdy * cs * 0.025, cs * 0.035, "#1C1C1E")
  end
  fx:draw()
end

local function drawHints(w, y)
  if K.lastInput == "pad" then
    K.hints({{"dpad", TR("h_move")}, {"B", TR("h_undo")}, {"X", TR("restart")}, {{"L", "R"}, TR("level")},
             {"-", TR("levels")}, {"+", TR("h_pause")}}, 0, y, w)
  elseif K.lastInput == "key" then
    K.hints({{TR("k_arrows"), TR("h_move")}, {"Z", TR("h_undo")}, {"R", TR("restart")}, {"L", TR("levels")},
             {"Esc", TR("h_pause")}}, 0, y, w)
  else
    K.hints({{"touch", TR("h_tap_walk")}}, 0, y, w)
  end
end

local function drawLevels(w, h)
  K.dim(w, h, 1)
  local cols, rows = 5, 4
  local cell = floor(min(84, (w - 70) / cols, (h - 160) / rows))
  local gw, gh = cell * cols, cell * rows
  local x0, y0 = floor((w - gw) / 2), floor((h - gh) / 2) + 6
  K.card(x0 - 16, y0 - 52, gw + 32, gh + 108, 16)
  local cnt = 0
  for n = 1, #LEVELS do if bestOf(n) then cnt = cnt + 1 end end
  gfx.color(theme.text)
  gfx.text(TR("levels_done", cnt, #LEVELS), x0 - 16, y0 - 40, 18, "bold", "center", gw + 32)
  for n = 1, #LEVELS do
    local cx, cy = (n - 1) % cols, (n - 1) // cols
    local x, y = x0 + cx * cell + 4, y0 + cy * cell + 4
    local s = cell - 8
    local hit = ui.hit("lv" .. n, x, y, s, s)
    local b = bestOf(n)
    gfx.rect(x, y, s, s, 10, b and K.col(theme.green, hit.hovered and 0.3 or 0.18) or (hit.hovered and theme.hover or theme.control))
    gfx.color(n == level and theme.accent or theme.separator)
    gfx.rectLine(x, y, s, s, 10, n == level and 2 or 1)
    gfx.color(theme.text)
    gfx.text(tostring(n), x, y + s * 0.14, s * 0.32, "bold", "center", s)
    gfx.color(theme.text2)
    gfx.text(b and TR("moves_short", b.moves) or TR("par_short", LEVELS[n].par), x, y + s * 0.62, 10, "semibold", "center", s)
    if b then gfx.icon("check_circle", x + s - 11, y + 11, 14, theme.green) end
    if pick.x == cx + 1 and pick.y == cy + 1 then K.ring(x - 3, y - 3, s + 6, s + 6, 12) end
    if hit.clicked then loadLevel(n); K.play("pop", 0.5) end
  end
  if ui.button(TR("close") .. "##lv", x0 + gw / 2 - 70, y0 + gh + 12, 140, 34) then F.close() end
end

local function drawDialogs(w, h)
  local s = F.scene
  if s == "pause" then
    F.pauseDialog(w, h, {onRestart = restart, onMenu = function() F.open("title") end})
  elseif s == "levels" then
    drawLevels(w, h)
  elseif s == "won" then
    local b = bestOf(level)
    local buttons = {}
    if level < #LEVELS then buttons[1] = {TR("next_level"), function() loadLevel(level + 1) end, "primary", "arrow_forward"} end
    buttons[#buttons + 1] = {TR("restart"), restart, "default", "replay"}
    buttons[#buttons + 1] = {TR("levels"), function() F.open("levels") end, "default", "grid_view"}
    K.dialog(F.dlg, w, h, {icon = "emoji_events", iconColor = theme.yellow, title = TR("level_done", level),
      subtitle = newRecord and TR("new_record") or nil,
      lines = {{TR("moves"), tostring(moves)}, {TR("pushes"), tostring(pushes) .. "  (" .. TR("par_short", LEVELS[level].par) .. ")"},
               {TR("best"), b and TR("moves_short", b.moves) or "—"}},
      buttons = buttons})
  else
    F.commonDialogs(w, h, {
      stats = function()
        local cnt, total = 0, 0
        for n = 1, #LEVELS do
          local b = bestOf(n)
          if b then cnt = cnt + 1; total = total + b.moves end
        end
        return {{TR("levels_solved"), cnt .. " / " .. #LEVELS}, {TR("total_moves"), tostring(total)}}
      end,
      onReset = function() best = {}; saveProgress() end,
      onNew = restart,
    })
  end
end

local function drawTitle(w, h)
  local cnt = 0
  for n = 1, #LEVELS do if bestOf(n) then cnt = cnt + 1 end end
  F.titleScreen(w, h, {icon = "inventory_2", c1 = "#D2A679", c2 = "#8B5A2B", title = TR("title"), subtitle = TR("tagline"),
    buttons = {{moves > 0 and not solved and TR("continue") or TR("play"), function()
                  if solved then loadLevel(min(#LEVELS, level + 1)) else F.play() end
                end, "primary", "play_arrow"},
               {TR("levels"), function() pick.x, pick.y = (level - 1) % 5 + 1, (level - 1) // 5 + 1; F.open("levels") end, "default", "grid_view"},
               {TR("stats_title"), function() F.open("stats") end, "default", "bar_chart"}},
    footer = TR("levels_done", cnt, #LEVELS)})
end

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  if F.scene == "title" or (F.scene ~= "play" and F.returnTo == "title") then
    drawTitle(w, h)
    if F.scene ~= "title" then drawDialogs(w, h) end
    return
  end
  local left = 0
  for _, b in ipairs(boxes) do if not goal[b.i] then left = left + 1 end end
  F.title(TR("level_n", level, #LEVELS), TR("status", moves, pushes, left), 16, 10)
  local hit = F.toolbar({{"pause", "pause"}, F.soundItem(), {"grid_view", "levels"}, {"replay", "restart"},
                         {"undo", "undo"}}, w - 16, 14)
  if hit == "sound" then K.setMuted(not K.muted)
  elseif hit == "pause" then F.open("pause")
  elseif hit == "levels" then pick.x, pick.y = (level - 1) % 5 + 1, (level - 1) // 5 + 1; F.open("levels")
  elseif hit == "restart" then restart()
  elseif hit == "undo" then undo() end
  local top, bottom = 64, h - 36
  local cs = floor(min((w - 32) / W, (bottom - top) / H, 72))
  B.cs = cs
  B.x = floor((w - cs * W) / 2)
  B.y = floor(top + (bottom - top - cs * H) / 2)
  drawLevel(now)
  drawHints(w, h - 28)
  drawDialogs(w, h)
end

-- ------------------------------------------------------------------ input
local function levelsEvent(e)
  local t = e.type
  local k = t == "paddown" and e.pad or (t == "keydown" and e.key) or nil
  if not k then return end
  local d = F.DIRV[k]
  if d then F.moveCursor(pick, d[1], d[2], 5, 4, true)
  elseif (t == "paddown" and k == "a") or (t == "keydown" and (k == "enter" or k == "space")) then
    local n = (pick.y - 1) * 5 + pick.x
    if LEVELS[n] then loadLevel(n); K.play("pop", 0.5) end
  elseif (t == "paddown" and (k == "b" or k == "minus")) or (t == "keydown" and k == "escape") then F.close() end
end

function app.event(e)
  K.track(e)
  local t = e.type
  if F.scene == "levels" then levelsEvent(e); return end
  if F.modal() then held = nil; F.dialogEvent(e); return end
  if t == "paddown" then
    local p = e.pad
    if solved then
      if p == "a" then F.open("won") elseif p == "plus" then F.open("pause") end
      return
    end
    if DIRS[p] then
      walkQueue = {}
      move(p)
      held, nextRep = p, sys.time() + 0.25
    elseif p == "b" or p == "y" then undo()
    elseif p == "x" then restart()
    elseif p == "l" and level > 1 then loadLevel(level - 1)
    elseif p == "r" and level < #LEVELS then loadLevel(level + 1)
    elseif p == "minus" then pick.x, pick.y = (level - 1) % 5 + 1, (level - 1) // 5 + 1; F.open("levels")
    elseif p == "plus" then F.open("pause") end
  elseif t == "padup" then
    if e.pad == held then held = nil end
  elseif t == "keydown" then
    local k = e.key
    if solved then
      if k == "enter" or k == "space" then F.open("won") elseif k == "escape" then F.open("pause") end
      return
    end
    if KEYDIR[k] and not e.ctrl then walkQueue = {}; move(KEYDIR[k])
    elseif k == "z" or k == "u" or k == "backspace" then undo()
    elseif k == "r" then restart()
    elseif k == "l" then F.open("levels")
    elseif k == "escape" or k == "p" then F.open("pause") end
  elseif t == "mousedown" then
    press = {x = e.x, y = e.y}
  elseif t == "mouseup" then
    if press and not e.cancel and not solved and B.cs > 0 then
      local dx, dy = e.x - press.x, e.y - press.y
      if abs(dx) > B.cs * 0.6 or abs(dy) > B.cs * 0.6 then
        walkQueue = {}
        if abs(dx) > abs(dy) then move(dx > 0 and "right" or "left") else move(dy > 0 and "down" or "up") end
      else
        local cx, cy = floor((e.x - B.x) / B.cs) + 1, floor((e.y - B.y) / B.cs) + 1
        if cx >= 1 and cy >= 1 and cx <= W and cy <= H then
          local i = idx(cx, cy)
          local px, py = xy(player.i)
          if boxAt[i] and abs(px - cx) + abs(py - cy) == 1 then
            local d = cx > px and "right" or cx < px and "left" or cy > py and "down" or "up"
            walkQueue = {}
            move(d)
          else
            local path = pathTo(i)
            if path then walkQueue = path else K.tone(140, 0.04, 0.1, "square") end
          end
        end
      end
    end
    press = nil
  end
end

function app.menu()
  return {{title = TR("menu_game"), items = {
    {label = TR("restart"), id = 1, shortcut = "R"},
    {label = TR("undo"), id = 2, shortcut = "Z", enabled = #history > 0},
    {label = TR("levels"), id = 3, shortcut = "L"},
    "-",
    {label = TR("sound"), id = 4, checked = not K.muted},
    {label = TR("stats_title"), id = 5},
  }}}
end

function app.onmenu(id)
  if id == 1 then restart()
  elseif id == 2 then undo()
  elseif id == 3 then F.open("levels")
  elseif id == 4 then K.setMuted(not K.muted)
  elseif id == 5 then F.open("stats") end
end

function app.close()
  saveProgress()
  return true
end

return app
