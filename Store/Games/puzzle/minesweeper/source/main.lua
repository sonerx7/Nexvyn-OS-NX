-- Minesweeper for Nexvyn OS: beginner / intermediate / expert, safe first click, flood reveal, flags, chords,
-- best times and full controller / keyboard / touch support.
local app = {}

local floor, min, max, abs, sin, cos, pi, sqrt = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi, math.sqrt
local random = math.random

-- ------------------------------------------------------------------ colors
local cache = {}
local function rgba(c)
  local t = cache[c]
  if not t then
    t = {tonumber(c:sub(2, 3), 16) or 0, tonumber(c:sub(4, 5), 16) or 0, tonumber(c:sub(6, 7), 16) or 0,
         #c >= 9 and (tonumber(c:sub(8, 9), 16) or 255) or 255}
    cache[c] = t
  end
  return t
end
local function alpha(c, a)
  local t = rgba(c)
  return {t[1], t[2], t[3], max(0, min(255, floor(t[4] * a + 0.5)))}
end

-- ------------------------------------------------------------------ game data
local DIFFS = {
  {cols = 9, rows = 9, mines = 10, key = "beginner"},
  {cols = 16, rows = 16, mines = 40, key = "intermediate"},
  {cols = 30, rows = 16, mines = 99, key = "expert"},
}

local diff = 1
local cols, rows, mines = 9, 9, 10
local cells = {}
local state = "ready"          -- ready, playing, won, lost
local paused = false
local startTime, elapsed, pausedAt = 0, 0, 0
local flags, opened = 0, 0
local cursorX, cursorY = 1, 1
local flagMode = false
local lastInput = "touch"
local endAt = 0
local best = {}
local wins, played = 0, 0
local newRecord = false
local shake = 0
local confetti = {}
local board = {x = 0, y = 0, cell = 24, w = 0, h = 0}
local press = nil              -- {x, y, t, sx, sy, long}
local held = {}
local repeatAt = 0
local stickAt = 0

local function idx(x, y) return (y - 1) * cols + x end
local function inside(x, y) return x >= 1 and y >= 1 and x <= cols and y <= rows end

local function newGame(d)
  if d then diff = d end
  local D = DIFFS[diff]
  cols, rows, mines = D.cols, D.rows, D.mines
  cells = {}
  for i = 1, cols * rows do
    cells[i] = {mine = false, n = 0, open = false, flag = false, openAt = 0, flagAt = -10, boom = false}
  end
  state = "ready"
  paused = false
  elapsed = 0
  flags, opened = 0, 0
  cursorX, cursorY = math.ceil(cols / 2), math.ceil(rows / 2)
  press = nil
  newRecord = false
  confetti = {}
  store.set("diff", diff)
end

local function placeMines(sx, sy)
  local safe = {}
  for dy = -1, 1 do
    for dx = -1, 1 do
      if inside(sx + dx, sy + dy) then safe[idx(sx + dx, sy + dy)] = true end
    end
  end
  local pool = {}
  for i = 1, cols * rows do
    if not safe[i] then pool[#pool + 1] = i end
  end
  if #pool < mines then   -- tiny boards: only protect the clicked cell
    pool = {}
    for i = 1, cols * rows do if i ~= idx(sx, sy) then pool[#pool + 1] = i end end
  end
  for i = 1, mines do
    local j = random(i, #pool)
    pool[i], pool[j] = pool[j], pool[i]
    cells[pool[i]].mine = true
  end
  for y = 1, rows do
    for x = 1, cols do
      local n = 0
      for dy = -1, 1 do
        for dx = -1, 1 do
          if (dx ~= 0 or dy ~= 0) and inside(x + dx, y + dy) and cells[idx(x + dx, y + dy)].mine then n = n + 1 end
        end
      end
      cells[idx(x, y)].n = n
    end
  end
end

local function saveStats()
  store.set("best", best)
  store.set("wins", wins)
  store.set("played", played)
end

local function win()
  state = "won"
  endAt = sys.time()
  elapsed = endAt - startTime
  for i = 1, cols * rows do
    local c = cells[i]
    if c.mine and not c.flag then c.flag = true; c.flagAt = endAt + random() * 0.4 end
  end
  flags = mines
  wins = wins + 1
  local key = DIFFS[diff].key
  local t = floor(elapsed * 10 + 0.5) / 10
  if not best[key] or t < best[key] then
    best[key] = t
    newRecord = true
  end
  saveStats()
  for k, f in ipairs({523.25, 659.25, 783.99, 1046.5, 1318.5}) do
    timer.after((k - 1) * 0.09, function() audio.tone(f, 0.16, 0.3, "triangle") end)
  end
  sys.vibrate(0.5, 120)
  for _ = 1, 120 do
    confetti[#confetti + 1] = {x = random() * board.w, y = -random() * 200, vx = (random() - 0.5) * 60,
      vy = 80 + random() * 120, rot = random() * pi, vr = (random() - 0.5) * 8, size = 4 + random() * 5,
      col = ({"red", "orange", "yellow", "green", "blue", "purple", "pink"})[random(1, 7)]}
  end
end

local function lose(bx, by)
  state = "lost"
  endAt = sys.time()
  elapsed = endAt - startTime
  local b = cells[idx(bx, by)]
  b.boom = true
  b.open = true
  b.openAt = endAt
  -- reveal the other mines outward from the explosion
  for y = 1, rows do
    for x = 1, cols do
      local c = cells[idx(x, y)]
      if c.mine and not c.open and not c.flag then
        c.open = true
        local d = sqrt((x - bx) ^ 2 + (y - by) ^ 2)
        c.openAt = endAt + 0.15 + d * 0.05 + random() * 0.05
      end
    end
  end
  saveStats()
  shake = 1
  audio.tone(70, 0.5, 0.6, "noise")
  audio.tone(55, 0.6, 0.5, "square")
  sys.vibrate(1.0, 300)
end

local function checkWin()
  if state == "playing" and opened >= cols * rows - mines then win() end
end

local function reveal(x0, y0)
  if state == "won" or state == "lost" or paused then return end
  local c = cells[idx(x0, y0)]
  if c.open or c.flag then return end
  local now = sys.time()
  if state == "ready" then
    placeMines(x0, y0)
    state = "playing"
    startTime = now
    played = played + 1
    saveStats()
  end
  if c.mine then lose(x0, y0); return end
  c.open = true
  c.openAt = now
  local queue = {{x0, y0, 0}}
  local head = 1
  while head <= #queue do
    local q = queue[head]
    head = head + 1
    opened = opened + 1
    local cc = cells[idx(q[1], q[2])]
    if cc.n == 0 then
      for dy = -1, 1 do
        for dx = -1, 1 do
          local nx, ny = q[1] + dx, q[2] + dy
          if (dx ~= 0 or dy ~= 0) and inside(nx, ny) then
            local nc = cells[idx(nx, ny)]
            if not nc.open and not nc.flag and not nc.mine then
              nc.open = true
              nc.openAt = now + (q[3] + 1) * 0.022
              queue[#queue + 1] = {nx, ny, q[3] + 1}
            end
          end
        end
      end
    end
  end
  if #queue > 1 then
    audio.tone(330, 0.06, 0.25, "triangle")
    timer.after(0.05, function() audio.tone(494, 0.08, 0.2, "triangle") end)
  else
    audio.tone(620 + c.n * 40, 0.04, 0.22, "triangle")
  end
  checkWin()
end

local function toggleFlag(x, y)
  if state == "won" or state == "lost" or paused then return end
  local c = cells[idx(x, y)]
  if c.open then return end
  c.flag = not c.flag
  c.flagAt = sys.time()
  flags = flags + (c.flag and 1 or -1)
  audio.tone(c.flag and 988 or 659, 0.05, 0.25, "square")
  sys.vibrate(0.3, 25)
end

local function chord(x, y)
  if state ~= "playing" or paused then return end
  local c = cells[idx(x, y)]
  if not c.open or c.n == 0 then return end
  local f = 0
  for dy = -1, 1 do
    for dx = -1, 1 do
      if inside(x + dx, y + dy) and cells[idx(x + dx, y + dy)].flag then f = f + 1 end
    end
  end
  if f ~= c.n then
    audio.tone(220, 0.05, 0.15, "sine")
    return
  end
  for dy = -1, 1 do
    for dx = -1, 1 do
      local nx, ny = x + dx, y + dy
      if inside(nx, ny) and state == "playing" then
        local nc = cells[idx(nx, ny)]
        if not nc.open and not nc.flag then reveal(nx, ny) end
      end
    end
  end
end

local function act(x, y, flagIt)
  if state == "won" or state == "lost" then return end
  local c = cells[idx(x, y)]
  if c.open then chord(x, y)
  elseif flagIt then toggleFlag(x, y)
  else reveal(x, y) end
end

local function setPaused(p)
  if state ~= "playing" then paused = false; return end
  if p == paused then return end
  paused = p
  local now = sys.time()
  if p then pausedAt = now else startTime = startTime + (now - pausedAt) end
  audio.play("click", 0.5)
end

function app.load()
  diff = max(1, min(3, floor(tonumber(store.get("diff", 1)) or 1)))
  best = store.get("best", {}) or {}
  wins = tonumber(store.get("wins", 0)) or 0
  played = tonumber(store.get("played", 0)) or 0
  flagMode = store.get("flagMode", false) == true
  newGame()
end

-- ------------------------------------------------------------------ update
local function moveCursor(dx, dy)
  cursorX = max(1, min(cols, cursorX + dx))
  cursorY = max(1, min(rows, cursorY + dy))
  audio.tone(1200, 0.012, 0.08, "sine")
end

local DIRS = {left = {-1, 0}, right = {1, 0}, up = {0, -1}, down = {0, 1}}

function app.update(dt)
  local now = sys.time()
  if state == "playing" and not paused then elapsed = now - startTime end
  shake = max(0, shake - dt * 2.5)
  -- long press = flag
  if press and not press.long and now - press.t > 0.45 then
    press.long = true
    if inside(press.x, press.y) then
      local c = cells[idx(press.x, press.y)]
      if not c.open then toggleFlag(press.x, press.y) end
    end
  end
  -- d-pad repeat
  for dir, t0 in pairs(held) do
    if now - t0 > 0.32 and now >= repeatAt then
      local d = DIRS[dir]
      if d then moveCursor(d[1], d[2]) end
      repeatAt = now + 0.07
    end
  end
  -- stick
  if lastInput == "pad" then
    local sx, sy = input.stick("left")
    if (abs(sx) > 0.55 or abs(sy) > 0.55) and now >= stickAt then
      local dx = abs(sx) > 0.55 and (sx > 0 and 1 or -1) or 0
      local dy = abs(sy) > 0.55 and (sy > 0 and -1 or 1) or 0
      moveCursor(dx, dy)
      stickAt = now + 0.12
    end
  end
  -- confetti
  for i = #confetti, 1, -1 do
    local p = confetti[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.rot = p.rot + p.vr * dt
    p.vx = p.vx + sin(now * 3 + i) * 20 * dt
    if p.y > board.h + 20 then table.remove(confetti, i) end
  end
end

-- ------------------------------------------------------------------ drawing
local NUMCOL = {"blue", "green", "red", "purple", "orange", "#30B0C7", "text", "gray"}
local function numColor(n)
  local c = NUMCOL[n]
  if c:sub(1, 1) == "#" then return c end
  return theme[c]
end

local function drawMine(cx, cy, r)
  gfx.color("#1C1C1E")
  for k = 0, 3 do
    local a = k * pi / 4
    gfx.line(cx - cos(a) * r * 1.45, cy - sin(a) * r * 1.45, cx + cos(a) * r * 1.45, cy + sin(a) * r * 1.45, max(1.5, r * 0.24))
  end
  gfx.circle(cx, cy, r)
  gfx.color(255, 255, 255, 200)
  gfx.circle(cx - r * 0.35, cy - r * 0.35, r * 0.24)
end

local function drawFlag(cx, cy, s, a)
  -- pole + triangular banner
  gfx.alpha(a or 1)
  gfx.color(theme.dark and "#D1D1D6" or "#3A3A3C")
  gfx.rect(cx - s * 0.05, cy - s * 0.32, s * 0.09, s * 0.62, 1)
  gfx.rect(cx - s * 0.22, cy + s * 0.26, s * 0.42, s * 0.08, 2)
  gfx.poly({cx + s * 0.04, cy - s * 0.34, cx + s * 0.04, cy + s * 0.04, cx - s * 0.36, cy - s * 0.15}, theme.red)
  gfx.unalpha()
end

local function counterPill(x, y, icon, text, col)
  local tw = gfx.textWidth(text, 18, "monobold") + 44
  gfx.color(theme.control)
  gfx.rect(x, y, tw, 34, 17)
  gfx.color(theme.separator)
  gfx.rectLine(x, y, tw, 34, 17, 1)
  gfx.icon(icon, x + 19, y + 17, 19, col)
  gfx.color(theme.text)
  gfx.text(text, x + 32, y + 6, 18, "monobold")
  return tw
end

local function padGlyph(label, x, y)
  gfx.color(theme.text2)
  gfx.circle(x + 9, y + 9, 9)
  gfx.color(theme.bg)
  gfx.text(label, x, y + 2, 11, "bold", "center", 18)
  return 18
end
local function keyCap(label, x, y)
  local tw = max(18, gfx.textWidth(label, 11, "semibold") + 10)
  gfx.color(theme.text3)
  gfx.rectLine(x, y, tw, 18, 4, 1)
  gfx.color(theme.text2)
  gfx.text(label, x, y + 2, 11, "semibold", "center", tw)
  return tw
end
local function drawHints(w, y)
  local items
  if lastInput == "pad" then
    items = {{"icon", "gamepad", TR("hint_move")}, {"pad", "A", TR("hint_reveal")}, {"pad", "X", TR("hint_flag")},
             {"pad", "Y", TR("hint_flagmode")}, {"pad", "+", TR("hint_pause")}, {"pad", "-", TR("hint_new")}}
  elseif lastInput == "key" then
    items = {{"icon", "keyboard", TR("hint_move")}, {"key", TR("key_space"), TR("hint_reveal")}, {"key", "F", TR("hint_flag")},
             {"key", "N", TR("hint_new")}, {"key", "Esc", TR("hint_pause")}}
  else
    items = {{"icon", "touch_app", TR("hint_tap")}, {"icon", "pan_tool", TR("hint_long")}, {"icon", "mouse", TR("hint_right")}}
  end
  local total = 0
  for _, it in ipairs(items) do
    local gw = it[1] == "key" and max(18, gfx.textWidth(it[2], 11, "semibold") + 10) or 18
    total = total + gw + 6 + gfx.textWidth(it[3], 12) + 16
  end
  local x = (w - total + 16) / 2
  for _, it in ipairs(items) do
    local gw
    if it[1] == "pad" then gw = padGlyph(it[2], x, y)
    elseif it[1] == "key" then gw = keyCap(it[2], x, y)
    else gfx.icon(it[2], x + 9, y + 9, 18, theme.text2); gw = 18 end
    gfx.color(theme.text2)
    local tw = gfx.text(it[3], x + gw + 6, y + 2, 12)
    x = x + gw + 6 + tw + 16
  end
end

local function fmtTime(t)
  return string.format("%03d", min(999, floor(t)))
end

local function pressedCells()
  -- cells visually pushed down by the current press (single cell or chord preview)
  if not press or press.long or state == "won" or state == "lost" or not inside(press.x, press.y) then return nil end
  local set = {}
  local c = cells[idx(press.x, press.y)]
  if c.open then
    if c.n > 0 then
      for dy = -1, 1 do
        for dx = -1, 1 do
          if inside(press.x + dx, press.y + dy) then set[idx(press.x + dx, press.y + dy)] = true end
        end
      end
    end
  elseif not c.flag and not flagMode then
    set[idx(press.x, press.y)] = true
  end
  return set
end

local function drawBoard(now)
  local b = board
  local cs = b.cell
  local gap = cs >= 30 and 2 or 1
  local rad = max(2, cs * 0.16)
  local closedTop = theme.dark and "#55555C" or "#E3E7EF"
  local closedBot = theme.dark and "#46464C" or "#CDD3DE"
  local openCol = theme.dark and "#2C2C30" or "#F5F6F9"
  local pset = pressedCells()
  local fontSize = floor(cs * 0.62)
  local fy = (cs - fontSize * 1.25) / 2
  gfx.shadow(b.x - 6, b.y - 6, b.w + 12, b.h + 12, 12, 14, 3)
  gfx.color(theme.dark and "#1E1E21" or "#B9C0CC")
  gfx.rect(b.x - 6, b.y - 6, b.w + 12, b.h + 12, 12)
  for y = 1, rows do
    for x = 1, cols do
      local c = cells[idx(x, y)]
      local px, py = b.x + (x - 1) * cs, b.y + (y - 1) * cs
      local s = cs - gap
      local visibleOpen = c.open and now >= c.openAt
      if visibleOpen then
        local k = min(1, (now - c.openAt) / 0.12)
        gfx.color(c.boom and theme.red or (c.mine and alpha(theme.red, 0.22) or openCol))
        gfx.rect(px, py, s, s, rad * 0.6)
        if c.mine then
          drawMine(px + s / 2, py + s / 2, s * 0.24 * (0.6 + 0.4 * k))
        elseif c.n > 0 then
          gfx.alpha(k)
          gfx.color(numColor(c.n))
          gfx.text(tostring(c.n), px, py + fy, fontSize, "bold", "center", s)
          gfx.unalpha()
        end
      elseif pset and pset[idx(x, y)] and not c.flag then
        gfx.color(openCol)
        gfx.rect(px, py, s, s, rad * 0.6)
      else
        gfx.gradient(px, py, s, s, closedTop, closedBot, false, rad)
        gfx.color(255, 255, 255, theme.dark and 18 or 120)
        gfx.rect(px + 1, py + 1, s - 2, max(1, s * 0.12), rad * 0.5)
        if c.flag then
          local a = min(1, (now - c.flagAt) / 0.15)
          if a > 0 then
            local wrong = state == "lost" and not c.mine
            local sc = 0.7 + 0.3 * a + (a < 1 and sin(a * pi) * 0.25 or 0)
            drawFlag(px + s / 2, py + s / 2, s * sc, a)
            if wrong then
              gfx.color(theme.red)
              gfx.line(px + s * 0.2, py + s * 0.2, px + s * 0.8, py + s * 0.8, 2)
              gfx.line(px + s * 0.8, py + s * 0.2, px + s * 0.2, py + s * 0.8, 2)
            end
          end
        end
      end
    end
  end
  -- cursor
  if (lastInput == "pad" or lastInput == "key") and state ~= "won" and state ~= "lost" then
    local px, py = b.x + (cursorX - 1) * cs, b.y + (cursorY - 1) * cs
    local pulse = 0.6 + 0.4 * sin(now * 6)
    gfx.color(alpha(theme.accent, pulse))
    gfx.rectLine(px - 2, py - 2, cs - gap + 4, cs - gap + 4, rad + 2, 3)
  end
end

local function drawOverlay(w, h, now)
  local b = board
  if paused then
    gfx.color(alpha(theme.bg, 0.92))
    gfx.rect(b.x - 6, b.y - 6, b.w + 12, b.h + 12, 12)
    gfx.icon("pause_circle", w / 2, b.y + b.h / 2 - 40, 64, theme.accent)
    gfx.color(theme.text)
    gfx.text(TR("paused"), 0, b.y + b.h / 2, 24, "bold", "center", w)
    if ui.button(TR("resume"), w / 2 - 70, b.y + b.h / 2 + 44, 140, 36, "primary", "play_arrow") then setPaused(false) end
    return
  end
  if state ~= "won" and state ~= "lost" then return end
  local delay = state == "lost" and 1.3 or 0.6
  local t = now - endAt - delay
  if t < 0 then return end
  local a = min(1, t / 0.25)
  local cw, ch = 300, 196
  local cx, cy = (w - cw) / 2, b.y + (b.h - ch) / 2 + (1 - a) * 20
  gfx.alpha(a)
  gfx.shadow(cx, cy, cw, ch, 16, 24, 6)
  gfx.color(theme.window)
  gfx.rect(cx, cy, cw, ch, 16)
  gfx.color(theme.separator)
  gfx.rectLine(cx, cy, cw, ch, 16, 1)
  local won = state == "won"
  gfx.icon(won and "emoji_events" or "sentiment_very_dissatisfied", w / 2, cy + 36, 40, won and theme.yellow or theme.red)
  gfx.color(theme.text)
  gfx.text(won and TR("you_win") or TR("game_over"), cx, cy + 62, 22, "bold", "center", cw)
  gfx.color(theme.text2)
  local key = DIFFS[diff].key
  local timeText = string.format("%.1f", elapsed)
  if won then
    gfx.text(TR("time_result", timeText), cx, cy + 94, 14, "medium", "center", cw)
    if newRecord then
      gfx.color(theme.orange)
      gfx.text(TR("new_record"), cx, cy + 114, 13, "semibold", "center", cw)
    elseif best[key] then
      gfx.text(TR("best_time", string.format("%.1f", best[key])), cx, cy + 114, 13, "sans", "center", cw)
    end
  else
    gfx.text(TR("lost_msg"), cx, cy + 94, 14, "sans", "center", cw)
    if best[key] then gfx.text(TR("best_time", string.format("%.1f", best[key])), cx, cy + 114, 13, "sans", "center", cw) end
  end
  if ui.button(TR("play_again"), cx + 40, cy + ch - 52, cw - 80, 36, "primary", "replay") then
    newGame()
    audio.play("pop", 0.6)
  end
  gfx.unalpha()
end

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)

  -- header
  local labels = {TR("beginner"), TR("intermediate"), TR("expert")}
  local nd = ui.segmented("diff", labels, diff, 16, 14, 300, 32)
  if nd ~= diff then newGame(nd); lastInput = "touch"; audio.play("pop", 0.5) end

  local rx = w - 16
  local tw = gfx.textWidth("000", 18, "monobold") + 44
  rx = rx - tw
  counterPill(rx, 13, "timer", fmtTime(elapsed), theme.blue)
  local left = mines - flags
  local mtxt = left < 0 and string.format("-%02d", min(99, -left)) or string.format("%03d", left)
  local mw = gfx.textWidth(mtxt, 18, "monobold") + 44
  counterPill(rx - mw - 8, 13, "flag", mtxt, theme.red)
  local fmx = rx - mw - 8 - 44
  if ui.iconButton("flag", fmx, 13, 36, 34, flagMode and theme.red or nil, flagMode, "mode") then
    flagMode = not flagMode
    store.set("flagMode", flagMode)
    audio.tone(flagMode and 880 or 660, 0.04, 0.2, "triangle")
    lastInput = "touch"
  end

  local face = "sentiment_satisfied_alt"
  if state == "lost" then face = "sentiment_very_dissatisfied"
  elseif state == "won" then face = "emoji_events"
  elseif press and not press.long then face = "sentiment_neutral" end
  local fx = floor((316 + fmx) / 2)
  local fh = ui.hit("face", fx - 20, 11, 40, 40)
  gfx.shadow(fx - 18, 13, 36, 36, 18, 8, 2)
  gfx.color(fh.held and theme.hover or theme.control)
  gfx.circle(fx, 31, 19)
  gfx.icon(face, fx, 31, 30, state == "lost" and theme.red or theme.yellow)
  if fh.clicked then newGame(); audio.play("pop", 0.6); lastInput = "touch" end

  -- board layout
  local top, bottom = 66, h - 40
  local cs = floor(min(48, (w - 40) / cols, (bottom - top - 12) / rows))
  board.cell = cs
  board.w, board.h = cs * cols, cs * rows
  board.x = floor((w - board.w) / 2)
  board.y = floor(top + 6 + (bottom - top - 12 - board.h) / 2)
  local sx = shake > 0 and sin(now * 60) * 6 * shake or 0
  gfx.push(sx, 0)
  drawBoard(now)
  gfx.pop()

  -- status line under the header
  if state == "ready" and not paused then
    gfx.color(theme.text3)
    gfx.text(TR("tap_to_start"), 0, board.y + board.h + 8, 12, "sans", "center", w)
  end

  -- confetti
  if #confetti > 0 then
    gfx.clip(0, 0, w, h)
    for _, p in ipairs(confetti) do
      local px, py = board.x + p.x, board.y + p.y
      local s = p.size
      local cr, sr = cos(p.rot), sin(p.rot)
      gfx.poly({px - cr * s, py - sr * s * 0.5, px + sr * s * 0.4, py - cr * s * 0.4,
                px + cr * s, py + sr * s * 0.5, px - sr * s * 0.4, py + cr * s * 0.4}, theme[p.col])
    end
    gfx.unclip()
  end

  drawOverlay(w, h, now)
  drawHints(w, h - 28)
end

-- ------------------------------------------------------------------ input
local function cellAt(x, y)
  local b = board
  if x < b.x or y < b.y or x >= b.x + b.w or y >= b.y + b.h then return nil end
  return floor((x - b.x) / b.cell) + 1, floor((y - b.y) / b.cell) + 1
end

function app.event(e)
  local t = e.type
  if t == "mousedown" then
    lastInput = "touch"
    if paused or state == "won" or state == "lost" then return end
    local cx, cy = cellAt(e.x, e.y)
    if not cx then return end
    cursorX, cursorY = cx, cy
    if e.button == "right" then
      act(cx, cy, true)
      press = nil
    else
      press = {x = cx, y = cy, t = sys.time(), sx = e.x, sy = e.y, long = false}
    end
  elseif t == "mousemove" then
    if press and not press.long then
      local cx, cy = cellAt(e.x, e.y)
      if e.touch and (abs(e.x - press.sx) > 12 or abs(e.y - press.sy) > 12) then
        press = nil
      elseif cx then
        if cx ~= press.x or cy ~= press.y then press.t = sys.time() end
        press.x, press.y = cx, cy
      end
    end
  elseif t == "mouseup" then
    if press and not press.long and not e.cancel and e.button ~= "right" then
      local cx, cy = cellAt(e.x, e.y)
      if cx and cx == press.x and cy == press.y then act(cx, cy, flagMode) end
    end
    press = nil
  elseif t == "paddown" then
    lastInput = "pad"
    local p = e.pad
    if DIRS[p] then
      if not paused then moveCursor(DIRS[p][1], DIRS[p][2]) end
      held[p] = sys.time()
      repeatAt = 0
    elseif p == "a" then
      if paused then setPaused(false)
      elseif state == "won" or state == "lost" then
        if sys.time() - endAt > 0.8 then newGame(); audio.play("pop", 0.6) end
      else act(cursorX, cursorY, flagMode) end
    elseif p == "x" then act(cursorX, cursorY, not flagMode)
    elseif p == "y" then
      flagMode = not flagMode
      store.set("flagMode", flagMode)
      audio.tone(flagMode and 880 or 660, 0.04, 0.2, "triangle")
    elseif p == "plus" or p == "b" then
      if state == "playing" then setPaused(not paused) end
    elseif p == "minus" then newGame(); audio.play("pop", 0.6)
    elseif p == "zl" then newGame((diff + 1) % 3 + 1)
    elseif p == "zr" then newGame(diff % 3 + 1)
    end
  elseif t == "padup" then
    held[e.pad] = nil
  elseif t == "keydown" then
    lastInput = "key"
    local k = e.key
    if DIRS[k] then
      if not paused then moveCursor(DIRS[k][1], DIRS[k][2]) end
    elseif k == "space" or k == "enter" then
      if paused then setPaused(false)
      elseif state == "won" or state == "lost" then newGame()
      else act(cursorX, cursorY, flagMode) end
    elseif k == "f" then act(cursorX, cursorY, not flagMode)
    elseif k == "n" or k == "f2" then newGame(); audio.play("pop", 0.6)
    elseif k == "escape" or k == "p" then
      if state == "playing" then setPaused(not paused) end
    elseif k == "1" or k == "2" or k == "3" then newGame(tonumber(k))
    elseif k == "m" then
      flagMode = not flagMode
      store.set("flagMode", flagMode)
    end
  end
end

function app.menu()
  return {
    {title = TR("menu_game"), items = {
      {label = TR("new_game"), id = 1, shortcut = "N"},
      {label = paused and TR("resume") or TR("pause"), id = 2, shortcut = "Esc", enabled = state == "playing"},
      {label = TR("flag_mode"), id = 3, checked = flagMode, shortcut = "M"},
      "-",
      {label = TR("beginner") .. "  (9×9, 10)", id = 11, checked = diff == 1, shortcut = "1"},
      {label = TR("intermediate") .. "  (16×16, 40)", id = 12, checked = diff == 2, shortcut = "2"},
      {label = TR("expert") .. "  (30×16, 99)", id = 13, checked = diff == 3, shortcut = "3"},
      "-",
      {label = TR("reset_stats"), id = 4},
    }},
    {title = TR("menu_records"), items = {
      {label = TR("best_line", TR("beginner"), best.beginner and string.format("%.1f", best.beginner) or "—"), id = 21},
      {label = TR("best_line", TR("intermediate"), best.intermediate and string.format("%.1f", best.intermediate) or "—"), id = 22},
      {label = TR("best_line", TR("expert"), best.expert and string.format("%.1f", best.expert) or "—"), id = 23},
      "-",
      {label = TR("wins_line", wins, played), id = 24},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then newGame()
  elseif id == 2 then setPaused(not paused)
  elseif id == 3 then flagMode = not flagMode; store.set("flagMode", flagMode)
  elseif id >= 11 and id <= 13 then newGame(id - 10)
  elseif id == 4 then
    ui.alert(TR("reset_stats"), TR("reset_stats_msg"), {TR("reset"), TR("cancel")}, function(b)
      if b == 1 then
        best, wins, played = {}, 0, 0
        saveStats()
      end
    end)
  end
end

function app.close()
  saveStats()
  return true
end

return app
