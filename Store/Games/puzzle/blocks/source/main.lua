-- Blok Düşür / Falling Blocks for Nexvyn OS: seven tetrominoes from a shuffled bag, rotation with wall kicks,
-- hold, three-piece preview, ghost piece, lock delay, soft / hard drop, line clear animation, combos and levels.
local K = require("arcade")
local floor, min, max, abs, sin = math.floor, math.min, math.max, math.abs, math.sin
local random = math.random

local BW, BH, HID = 10, 22, 2         -- board width, height incl. hidden rows
local G = {icon = "view_module", accent = "#BF5AF2", stickPress = true,
  rep = {left = true, right = true, down = true}, repDelay = 0.16, repRate = 0.045}

local COLORS = {"#30D5FF", "#FFD60A", "#BF5AF2", "#32D74B", "#FF453A", "#0A84FF", "#FF9F0A"}
local DEFS = {   -- size of the rotation box, cells of rotation 0
  {4, {0, 1, 1, 1, 2, 1, 3, 1}},     -- I
  {2, {0, 0, 1, 0, 0, 1, 1, 1}},     -- O
  {3, {1, 0, 0, 1, 1, 1, 2, 1}},     -- T
  {3, {1, 0, 2, 0, 0, 1, 1, 1}},     -- S
  {3, {0, 0, 1, 0, 1, 1, 2, 1}},     -- Z
  {3, {0, 0, 0, 1, 1, 1, 2, 1}},     -- J
  {3, {2, 0, 0, 1, 1, 1, 2, 1}},     -- L
}
local ROT = {}                        -- ROT[kind][r] = {x1, y1, ...}
for k, d in ipairs(DEFS) do
  ROT[k] = {}
  local n, cur = d[1], d[2]
  for r = 1, 4 do
    ROT[k][r] = cur
    local nx = {}
    for i = 1, 8, 2 do nx[i], nx[i + 1] = n - 1 - cur[i + 1], cur[i] end
    cur = nx
  end
end
local KICKS = {0, 0, -1, 0, 1, 0, 0, -1, -2, 0, 2, 0, -1, -1, 1, -1}

local grid = {}
local bag, queue = {}, {}
local cur = {k = 1, r = 1, x = 4, y = 1, vx = 4, vy = 1}
local hold, holdUsed = 0, false
local fallT, lockT, lockMoves = 0, 0, 0
local level, lines, tetris, pieces = 1, 0, 0, 0
local clearing, clearT = {}, 0
local L = {cell = 24, x = 0, y = 0}
local drag = nil
local demoT = 0
local alive = true

local function idx(x, y) return (y - 1) * BW + x end

local function nextFromBag()
  if #bag == 0 then
    for i = 1, 7 do bag[i] = i end
    for i = 7, 2, -1 do
      local j = random(i)
      bag[i], bag[j] = bag[j], bag[i]
    end
  end
  return table.remove(bag)
end

local function fits(k, r, x, y)
  local c = ROT[k][r]
  for i = 1, 8, 2 do
    local gx, gy = x + c[i], y + c[i + 1]
    if gx < 1 or gx > BW or gy > BH then return false end
    if gy >= 1 and grid[idx(gx, gy)] ~= 0 then return false end
  end
  return true
end

local function gravity() return max(0.04, 0.85 * 0.84 ^ (level - 1)) end

local function spawn(k)
  cur.k = k or table.remove(queue, 1)
  if not k then queue[#queue + 1] = nextFromBag() end
  cur.r = 1
  cur.x = cur.k == 2 and 5 or 4
  cur.y = 1
  cur.vx, cur.vy = cur.x, cur.y - 1.5
  fallT, lockT, lockMoves = 0, 0, 0
  pieces = pieces + 1
  if not fits(cur.k, cur.r, cur.x, cur.y) then
    alive = false
    if K.state == "play" then
      K.shake(12)
      K.sfx("boom")
      K.over({stats = {{TR("lines"), tostring(lines)}, {TR("level"), tostring(level)},
        {TR("tetrises"), tostring(tetris)}, {TR("pieces"), tostring(pieces)}}})
    end
  end
end

function G.controls() return {TR("c_move"), TR("c_rotate"), TR("c_drop"), TR("c_hold"), TR("c_touch")} end

function G.layout(w, h)
  local cs = floor(min((h - 30) / (BH - HID), (w - 340) / BW))
  L.cell = max(10, cs)
  L.x = floor((w - L.cell * BW) / 2)
  L.y = floor((h - L.cell * (BH - HID)) / 2) + 6
end

function G.reset()
  grid = {}
  for i = 1, BW * BH do grid[i] = 0 end
  bag, queue = {}, {}
  for i = 1, 4 do queue[i] = nextFromBag() end
  hold, holdUsed = 0, false
  level, lines, tetris, pieces = 1, 0, 0, 0
  clearing, clearT = {}, 0
  alive = true
  drag = nil
  spawn()
  pieces = 1
end

local function lockPiece()
  local c = ROT[cur.k][cur.r]
  for i = 1, 8, 2 do
    local gx, gy = cur.x + c[i], cur.y + c[i + 1]
    if gy >= 1 then grid[idx(gx, gy)] = cur.k end
  end
  holdUsed = false
  local playing = K.state == "play"
  if playing then K.sfx("drop", 0.7) end
  -- full rows
  clearing = {}
  for y = 1, BH do
    local full = true
    for x = 1, BW do if grid[idx(x, y)] == 0 then full = false break end end
    if full then clearing[#clearing + 1] = y end
  end
  local n = #clearing
  if n > 0 then
    clearT = 0.32
    for _, y in ipairs(clearing) do
      for x = 1, BW do K.burst(x - 0.5, y - HID - 0.5, 2, COLORS[grid[idx(x, y)]], 9, 0.7, 0.18, 12) end
    end
    if playing then
      local combo = K.comboHit(12, "#FFD60A")
      local pts = ({100, 300, 500, 800})[n] * level + (combo > 1 and 50 * (combo - 1) * level or 0)
      K.addScore(pts)
      K.popup(BW / 2, clearing[1] - HID - 1, "+" .. pts, "#FFFFFF")
      if n == 4 then
        tetris = tetris + 1
        K.callout(TR("four_lines"), "#30D5FF", 42, "clear", 1.4)
        K.sfx("best")
        K.shake(9)
        K.flash("#30D5FF40", 0.3)
        K.vibrate(0.8, 160)
      else
        K.callout(TR(n == 1 and "single" or n == 2 and "double" or "triple"), "#FFFFFF", 30, "clear")
        K.sfx(n >= 2 and "coin" or "eat")
        K.shake(2 + n)
      end
    end
  else
    if playing then K.comboBreak() end
    spawn()
  end
end

local function finishClear()
  local n = #clearing
  -- remove rows from the bottom up
  local keep = {}
  for y = BH, 1, -1 do
    local full = false
    for _, cy in ipairs(clearing) do if cy == y then full = true end end
    if not full then keep[#keep + 1] = y end
  end
  local ng = {}
  for i = 1, BW * BH do ng[i] = 0 end
  local dst = BH
  for _, y in ipairs(keep) do
    for x = 1, BW do ng[idx(x, dst)] = grid[idx(x, y)] end
    dst = dst - 1
  end
  grid = ng
  lines = lines + n
  clearing = {}
  local nl = 1 + floor(lines / 10)
  if nl > level then
    level = nl
    if K.state == "play" then
      K.callout(TR("level_n", level), "#BF5AF2", 40, "level", 1.5)
      K.sfx("level")
      K.confetti(30)
    end
  end
  spawn()
end

local function move(ddx)
  if not alive or #clearing > 0 then return false end
  if fits(cur.k, cur.r, cur.x + ddx, cur.y) then
    cur.x = cur.x + ddx
    if lockMoves < 15 and not fits(cur.k, cur.r, cur.x, cur.y + 1) then lockT, lockMoves = 0, lockMoves + 1 end
    if K.state == "play" then K.sfx("move", 0.6) end
    return true
  end
  return false
end

local function rotate(dir)
  if not alive or #clearing > 0 or cur.k == 2 then return end
  local nr = (cur.r - 1 + dir) % 4 + 1
  for i = 1, #KICKS, 2 do
    local nx, ny = cur.x + KICKS[i], cur.y + KICKS[i + 1]
    if fits(cur.k, nr, nx, ny) then
      cur.r, cur.x, cur.y = nr, nx, ny
      if lockMoves < 15 then lockT, lockMoves = 0, lockMoves + 1 end
      if K.state == "play" then K.sfx("turn", 0.7) end
      return
    end
  end
end

local function softDrop()
  if not alive or #clearing > 0 then return end
  if fits(cur.k, cur.r, cur.x, cur.y + 1) then
    cur.y = cur.y + 1
    fallT = 0
    if K.state == "play" then K.addScore(1) end
  end
end

local function hardDrop()
  if not alive or #clearing > 0 then return end
  local n = 0
  local y0 = cur.y
  while fits(cur.k, cur.r, cur.x, cur.y + 1) do
    cur.y = cur.y + 1
    n = n + 1
  end
  cur.vy = cur.y
  local c = ROT[cur.k][cur.r]
  for i = 1, 8, 2 do
    K.burst(cur.x + c[i] - 0.5, cur.y + c[i + 1] - HID - 0.5, 3, COLORS[cur.k], 6, 0.45, 0.15, 0, -math.pi / 2, 0.6)
  end
  if K.state == "play" then
    K.addScore(2 * n)
    K.shake(3 + min(4, (cur.y - y0) / 4))
    K.vibrate(0.3, 40)
  end
  lockPiece()
end

local function doHold()
  if not alive or holdUsed or #clearing > 0 then return end
  local k = cur.k
  if hold == 0 then
    hold = k
    spawn()
  else
    local h2 = hold
    hold = k
    spawn(h2)
  end
  pieces = pieces - 1
  holdUsed = true
  if K.state == "play" then K.sfx("click") end
end

function G.press(act, e)
  local key = e and e.key
  if act == "left" then move(-1)
  elseif act == "right" then move(1)
  elseif act == "down" then softDrop()
  elseif act == "up" then
    if key == "up" or key == "w" then rotate(1) elseif e then hardDrop() end
  elseif act == "a" then
    if key == "space" then hardDrop() else rotate(1) end
  elseif act == "b" or act == "zl" then rotate(-1)
  elseif act == "x" or act == "y" or act == "l" or act == "r" or act == "zr" then doHold() end
end

function G.pointer(e)
  if e.type == "mousedown" then
    -- the hold box is a button
    local hx = L.x - L.cell * 4.6 - 16
    if e.x >= hx and e.x <= hx + L.cell * 4.6 and e.y >= L.y and e.y <= L.y + L.cell * 4 + 30 then
      doHold()
      return
    end
    drag = {x = e.x, y = e.y, t = K.now, moved = false, sy = e.y}
  elseif e.type == "mousemove" and drag then
    local c = L.cell
    while e.x - drag.x > c do drag.x = drag.x + c; move(1); drag.moved = true end
    while drag.x - e.x > c do drag.x = drag.x - c; move(-1); drag.moved = true end
    while e.y - drag.y > c do drag.y = drag.y + c; softDrop(); drag.moved = true end
  elseif e.type == "mouseup" and drag then
    local dt = K.now - drag.t
    if not e.cancel then
      if e.y - drag.sy > L.cell * 3 and dt < 0.3 then hardDrop()
      elseif not drag.moved and dt < 0.35 then rotate(e.x < L.x + L.cell * BW / 2 and -1 or 1) end
    end
    drag = nil
  end
end

local function tick(dt)
  if not alive then return end
  if #clearing > 0 then
    clearT = clearT - dt
    if clearT <= 0 then finishClear() end
    return
  end
  local grounded = not fits(cur.k, cur.r, cur.x, cur.y + 1)
  if grounded then
    lockT = lockT + dt
    if lockT >= 0.5 then lockPiece() end
  else
    fallT = fallT + dt
    local gi = gravity()
    while fallT >= gi do
      fallT = fallT - gi
      if fits(cur.k, cur.r, cur.x, cur.y + 1) then cur.y = cur.y + 1 else break end
    end
  end
end

function G.update(dt)
  tick(dt)
  cur.vx = K.smooth(cur.vx, cur.x, 30, dt)
  cur.vy = K.smooth(cur.vy, cur.y, 26, dt)
end

-- demo behind the title: random moves and quick drops; restarts when the stack tops out
function G.idle(dt)
  if K.state ~= "title" then return end
  cur.vx = K.smooth(cur.vx, cur.x, 30, dt)
  cur.vy = K.smooth(cur.vy, cur.y, 26, dt)
  if not alive then G.reset() return end
  if #clearing > 0 then tick(dt) return end
  demoT = demoT + dt
  if demoT > 0.12 then
    demoT = 0
    local r = random()
    if r < 0.3 then move(random() < 0.5 and -1 or 1)
    elseif r < 0.4 then rotate(1)
    elseif r < 0.48 then hardDrop()
    else softDrop() end
  end
  tick(dt)
end

-- ------------------------------------------------------------------ drawing
local function block(x, y, c, k, a)
  K.color(COLORS[k], a)
  gfx.rect(x + 1, y + 1, c - 2, c - 2, max(2, c * 0.18))
  K.color("#FFFFFF", 0.3 * (a or 1))
  gfx.rect(x + 3, y + 3, c - 6, max(2, c * 0.18), 2)
  K.color("#000000", 0.18 * (a or 1))
  gfx.rect(x + 3, y + c - 3 - max(2, c * 0.14), c - 6, max(2, c * 0.14), 2)
end

local function mini(k, cx, cy, c, a)
  if k == 0 then return end
  local d = ROT[k][1]
  local minx, maxx, miny, maxy = 9, -9, 9, -9
  for i = 1, 8, 2 do
    minx, maxx = min(minx, d[i]), max(maxx, d[i])
    miny, maxy = min(miny, d[i + 1]), max(maxy, d[i + 1])
  end
  local ox = cx - (maxx - minx + 1) * c / 2 - minx * c
  local oy = cy - (maxy - miny + 1) * c / 2 - miny * c
  for i = 1, 8, 2 do block(ox + d[i] * c, oy + d[i + 1] * c, c, k, a) end
end

local function panel(x, y, w, h, title)
  gfx.color(0, 0, 0, 110)
  gfx.rect(x, y, w, h, 12)
  K.color("#FFFFFF", 0.7)
  gfx.text(title, x, y + 8, 13, "semibold", "center", w)
end

function G.draw(w, h)
  local t = K.now
  gfx.gradient(0, 0, w, h, "#1B1030", "#0A1426")
  local c = L.cell
  local sx, sy = K.shakeXY()
  local bx, by = L.x + sx, L.y + sy
  local bw, bh = c * BW, c * (BH - HID)
  -- board
  K.color("#BF5AF2", 0.25 + 0.1 * sin(t * 2))
  gfx.rect(bx - 5, by - 5, bw + 10, bh + 10, 10)
  K.color("#0B0B18")
  gfx.rect(bx, by, bw, bh, 6)
  K.color("#FFFFFF", 0.04)
  for x = 1, BW - 1 do gfx.rect(bx + x * c, by, 1, bh) end
  for y = 1, BH - HID - 1 do gfx.rect(bx, by + y * c, bw, 1) end
  for y = HID + 1, BH do
    local clearRow = false
    for _, cy in ipairs(clearing) do if cy == y then clearRow = true end end
    for x = 1, BW do
      local k = grid[idx(x, y)]
      if k ~= 0 then
        local px, py = bx + (x - 1) * c, by + (y - HID - 1) * c
        if clearRow then
          local f = clearT / 0.32
          K.color("#FFFFFF", f)
          gfx.rect(px + (1 - f) * c / 2, py, c * f, c, 3)
        else
          block(px, py, c, k)
        end
      end
    end
  end
  -- ghost and active piece (drawn at its eased position)
  if alive and #clearing == 0 then
    local gy = cur.y
    while fits(cur.k, cur.r, cur.x, gy + 1) do gy = gy + 1 end
    local d = ROT[cur.k][cur.r]
    for i = 1, 8, 2 do
      local yy = gy + d[i + 1]
      if yy > HID then
        K.color(COLORS[cur.k], 0.35)
        gfx.rectLine(bx + (cur.x + d[i] - 1) * c + 2, by + (yy - HID - 1) * c + 2, c - 4, c - 4, 4, 2)
      end
    end
    gfx.clip(bx, by, bw, bh)
    for i = 1, 8, 2 do
      block(bx + (cur.vx + d[i] - 1) * c, by + (cur.vy + d[i + 1] - HID - 1) * c, c, cur.k)
    end
    gfx.unclip()
    if lockT > 0 then
      K.color("#FFFFFF", 0.25 * lockT / 0.5)
      for i = 1, 8, 2 do
        gfx.rect(bx + (cur.x + d[i] - 1) * c + 1, by + (cur.y + d[i + 1] - HID - 1) * c + 1, c - 2, c - 2, 3)
      end
    end
  end
  K.drawParticles(c, bx, by)
  K.drawPopups(c, bx, by, 20)
  -- side panels
  local pw = c * 4.6
  local lx = bx - pw - 16
  panel(lx, by, pw, c * 4 + 30, TR("hold"))
  mini(hold, lx + pw / 2, by + 30 + c * 1.8, c * 0.9, holdUsed and 0.4 or 1)
  local rx = bx + bw + 16
  panel(rx, by, pw, c * 9.6 + 30, TR("next"))
  for i = 1, 3 do
    local s = i == 1 and 0.9 or 0.65
    mini(queue[i] or 0, rx + pw / 2, by + 30 + c * 1.6 + (i - 1) * c * 3.1, c * s, i == 1 and 1 or 0.7)
  end
  -- stats under the hold box
  local sy2 = by + c * 4 + 46
  panel(lx, sy2, pw, 150, TR("stats"))
  K.color("#FFFFFF", 0.6)
  gfx.text(TR("level"), lx + 12, sy2 + 34, 13, "medium")
  gfx.text(TR("lines"), lx + 12, sy2 + 74, 13, "medium")
  gfx.text(TR("best"), lx + 12, sy2 + 114, 13, "medium")
  K.color("#FFFFFF")
  gfx.text(tostring(level), lx + 12, sy2 + 30, 22, "bold", "right", pw - 24)
  gfx.text(tostring(lines), lx + 12, sy2 + 70, 22, "bold", "right", pw - 24)
  K.color("#FF9F0A")
  gfx.text(tostring(max(K.best, K.score)), lx + 12, sy2 + 110, 22, "bold", "right", pw - 24)
  -- score above the next box
  K.scorePill(12, 10)
  K.color("#FFFFFF", 0.5)
  gfx.rect(rx, by + c * 9.6 + 42, pw * min(1, (lines % 10) / 10), 6, 3)
  K.color("#FFFFFF", 0.12)
  gfx.rect(rx, by + c * 9.6 + 42, pw, 6, 3)
end

return K.run(G)
