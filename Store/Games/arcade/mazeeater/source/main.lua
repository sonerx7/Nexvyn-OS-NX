-- Labirent Yiyici / Maze Eater for Nexvyn OS: a Pac-Man-like maze game with dots, power pellets, fruit,
-- a side tunnel and three ghosts that scatter, chase (each with its own targeting), flee and return as eyes.
local K = require("arcade")
local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi
local random = math.random

-- left half of the maze (the right half is mirrored). # wall, . dot, o power pellet, - ghost door, space empty
local HALF = {
  "##########", "#........#", "#o##.###.#", "#.........", "#.##.#.###", "#....#...#", "####.### #",
  "####.#    ", "####.# ##-", "    .  #  ", "####.# ###", "####.#    ", "####.# ###", "#........#",
  "#.##.###.#", "#o.#....  ", "##.#.#.###", "#....#...#", "#.######.#", "#.........", "##########",
}
local COLS, ROWS = 19, #HALF
local MAP = {}
for y = 1, ROWS do
  local left = HALF[y]
  MAP[y] = left .. left:sub(1, 9):reverse()
end
local PSTART_X, PSTART_Y = 9, 15
local DOOR_X, DOOR_Y = 9, 7          -- tile above the door (outside the house)
local HOUSE_Y = 9
local G = {icon = "catching_pokemon", accent = "#FFD60A", stickPress = true, overIcon = "sentiment_dissatisfied"}

local GCOL = {"#FF453A", "#FF8AD8", "#30D5FF"}
local cells, dotsLeft, dotsTotal = {}, 0, 0
local runs = {}
local L = {cell = 22, x = 0, y = 0}
local pac = {tx = PSTART_X, ty = PSTART_Y, dx = -1, dy = 0, p = 0, wx = -1, wy = 0, mouth = 0, speed = 7.5}
local ghosts = {}
local level, lives = 1, 3
local frightT, chain, modeT, scatter = 0, 0, 0, true
local fruit = {on = false, t = 0, spawned = 0}
local dying, deathT, clearT, readyT = false, 0, 0, 0
local eatenDots, eatenGhosts, fruits = 0, 0, 0
local swipe = nil

local function cell(x, y)
  if y < 0 or y >= ROWS then return "#" end
  return cells[y * COLS + (x % COLS) + 1]
end
local function setCell(x, y, c) cells[y * COLS + (x % COLS) + 1] = c end
local function open(x, y, ghost)
  local c = cell(x, y)
  if c == "#" then return false end
  if c == "-" then return ghost == true end
  return true
end

local function buildMaze()
  cells, runs = {}, {}
  dotsLeft = 0
  for y = 0, ROWS - 1 do
    local row = MAP[y + 1]
    local start = nil
    for x = 0, COLS - 1 do
      local c = row:sub(x + 1, x + 1)
      cells[y * COLS + x + 1] = c
      if c == "." or c == "o" then dotsLeft = dotsLeft + 1 end
      if c == "#" then
        start = start or x
      elseif start then
        runs[#runs + 1] = {start, x - 1, y}
        start = nil
      end
    end
    if start then runs[#runs + 1] = {start, COLS - 1, y} end
  end
  setCell(PSTART_X, PSTART_Y, " ")
  dotsTotal = dotsLeft
end

local function placeActors()
  pac.tx, pac.ty, pac.dx, pac.dy, pac.p, pac.wx, pac.wy = PSTART_X, PSTART_Y, -1, 0, 0, -1, 0
  ghosts = {}
  for i = 1, 3 do
    local g = {i = i, tx = DOOR_X, ty = DOOR_Y, dx = -1, dy = 0, p = 0, state = "out", release = 0, x = 0, y = 0}
    if i > 1 then
      g.state = "house"
      g.x, g.y = DOOR_X + (i == 2 and -1 or 1), HOUSE_Y
      g.release = i == 2 and 2.5 or 6
    end
    ghosts[i] = g
  end
  frightT, chain, modeT, scatter = 0, 0, 0, true
  dying = false
  readyT = 1.6
end

function G.controls() return {TR("c_move"), TR("c_touch")} end

function G.layout(w, h)
  local top = 52
  L.cell = max(8, floor(min((w - 24) / COLS, (h - top - 10) / ROWS)))
  L.x = floor((w - L.cell * COLS) / 2)
  L.y = floor(top + (h - top - 10 - L.cell * ROWS) / 2)
end

function G.reset()
  level, lives = 1, 3
  eatenDots, eatenGhosts, fruits = 0, 0, 0
  fruit.on, fruit.spawned = false, 0
  clearT = 0
  buildMaze()
  placeActors()
  if K.state ~= "play" then readyT = 0 end
end

local function want(dx, dy) pac.wx, pac.wy = dx, dy end

function G.press(act)
  if act == "up" then want(0, -1) elseif act == "down" then want(0, 1)
  elseif act == "left" then want(-1, 0) elseif act == "right" then want(1, 0) end
end

function G.pointer(e)
  if e.type == "mousedown" then
    swipe = {x = e.x, y = e.y, moved = false}
  elseif e.type == "mousemove" and swipe then
    local ddx, ddy = e.x - swipe.x, e.y - swipe.y
    if abs(ddx) > 24 or abs(ddy) > 24 then
      if abs(ddx) > abs(ddy) then want(ddx > 0 and 1 or -1, 0) else want(0, ddy > 0 and 1 or -1) end
      swipe.x, swipe.y, swipe.moved = e.x, e.y, true
    end
  elseif e.type == "mouseup" and swipe then
    if not swipe.moved and not e.cancel then
      local px, py = L.x + (pac.tx + pac.dx * pac.p + 0.5) * L.cell, L.y + (pac.ty + pac.dy * pac.p + 0.5) * L.cell
      local ddx, ddy = e.x - px, e.y - py
      if abs(ddx) > abs(ddy) then want(ddx > 0 and 1 or -1, 0) else want(0, ddy > 0 and 1 or -1) end
    end
    swipe = nil
  end
end

-- ------------------------------------------------------------------ movement
local DIRS = {0, -1, -1, 0, 0, 1, 1, 0}   -- up, left, down, right (ghost tie-break order)

local function ghostTarget(g)
  if g.state == "eyes" then return DOOR_X, DOOR_Y end
  if scatter then
    if g.i == 1 then return COLS - 2, -2 elseif g.i == 2 then return 1, -2 else return COLS - 1, ROWS + 1 end
  end
  if g.i == 1 then return pac.tx, pac.ty end
  if g.i == 2 then return pac.tx + pac.dx * 4, pac.ty + pac.dy * 4 end
  local d = abs(g.tx - pac.tx) + abs(g.ty - pac.ty)
  if d > 7 then return pac.tx, pac.ty end
  return 0, ROWS + 1
end

local function chooseGhostDir(g)
  local best, bdx, bdy = 1e9, -g.dx, -g.dy
  local fright = g.state == "fright"
  local txg, tyg = ghostTarget(g)
  local opts = 0
  for k = 1, 7, 2 do
    local dx, dy = DIRS[k], DIRS[k + 1]
    if not (dx == -g.dx and dy == -g.dy) and open(g.tx + dx, g.ty + dy, g.state == "eyes") then
      opts = opts + 1
      local score
      if fright then score = random() else
        local nx, ny = g.tx + dx, g.ty + dy
        score = (nx - txg) ^ 2 + (ny - tyg) ^ 2
      end
      if score < best then best, bdx, bdy = score, dx, dy end
    end
  end
  g.dx, g.dy = bdx, bdy
end

local function ghostSpeed(g)
  if g.state == "eyes" then return 14 end
  if g.state == "fright" then return 4.2 end
  local s = 6.6 + min(level - 1, 6) * 0.35
  if g.ty == 9 and (g.tx < 4 or g.tx > COLS - 5) then s = s * 0.55 end   -- tunnel
  return s
end

local function stepGhost(g, dt)
  if g.state == "house" then
    g.release = g.release - dt
    g.y = HOUSE_Y + sin(K.now * 5 + g.i) * 0.25
    if g.release <= 0 then g.state = "leave" end
    return
  elseif g.state == "leave" or g.state == "enter" then
    local tx, ty
    if g.state == "leave" then
      tx = DOOR_X
      ty = abs(g.x - DOOR_X) < 0.05 and DOOR_Y or HOUSE_Y
    else
      tx, ty = DOOR_X, HOUSE_Y
    end
    local sp = (g.state == "enter" and 8 or 4) * dt
    if abs(g.x - tx) > 0.01 then g.x = K.approach(g.x, tx, sp) else g.y = K.approach(g.y, ty, sp) end
    if g.state == "leave" and abs(g.x - DOOR_X) < 0.01 and abs(g.y - DOOR_Y) < 0.01 then
      g.state = frightT > 0 and "fright" or "out"
      g.tx, g.ty, g.p, g.dx, g.dy = DOOR_X, DOOR_Y, 0, random() < 0.5 and -1 or 1, 0
    elseif g.state == "enter" and abs(g.y - HOUSE_Y) < 0.01 and abs(g.x - DOOR_X) < 0.01 then
      g.state = "leave"
    end
    return
  end
  g.p = g.p + ghostSpeed(g) * dt
  local guard = 0
  while g.p >= 1 and guard < 4 do
    guard = guard + 1
    g.p = g.p - 1
    g.tx, g.ty = (g.tx + g.dx) % COLS, g.ty + g.dy
    if g.state == "eyes" and g.tx == DOOR_X and g.ty == DOOR_Y then
      g.state, g.x, g.y, g.p = "enter", DOOR_X, DOOR_Y, 0
      return
    end
    chooseGhostDir(g)
  end
  if not open(g.tx + g.dx, g.ty + g.dy, g.state == "eyes") then
    g.p = 0
    chooseGhostDir(g)
  end
  g.x, g.y = g.tx + g.dx * g.p, g.ty + g.dy * g.p
end

local function eatAt(x, y, playing)
  local c = cell(x, y)
  if c == "." or c == "o" then
    setCell(x, y, " ")
    dotsLeft = dotsLeft - 1
    if playing then
      eatenDots = eatenDots + 1
      K.addScore(c == "o" and 50 or 10)
      K.tone(c == "o" and 300 or (eatenDots % 2 == 0 and 520 or 440), 0.04, 0.07, "triangle")
    end
    if c == "o" then
      frightT = max(2.5, 7 - level * 0.6)
      chain = 0
      for _, g in ipairs(ghosts) do
        if g.state == "out" then
          g.state = "fright"
          g.dx, g.dy = -g.dx, -g.dy
          if not open(g.tx + g.dx, g.ty + g.dy) then g.dx, g.dy = -g.dx, -g.dy end
          g.p = 1 - g.p
          g.tx, g.ty = (g.tx - g.dx) % COLS, g.ty - g.dy
        end
      end
      K.burst(x + 0.5, y + 0.5, 20, "#FFD60A", 6, 0.6, 0.18)
      if playing then
        K.sfx("power")
        K.callout(TR("power"), "#64D2FF", 30, "power")
        K.vibrate(0.4, 80)
      end
    end
    if eatenDots == 70 or eatenDots == 170 then
      fruit.on, fruit.t = true, 9
    end
  end
end

local function stepPac(dt, demo)
  if demo and pac.p == 0 then
    -- demo: random turns at junctions, prefer continuing
    if random() < 0.3 or not open(pac.tx + pac.dx, pac.ty + pac.dy) then
      local k = random(0, 3) * 2 + 1
      pac.wx, pac.wy = DIRS[k], DIRS[k + 1]
    end
  end
  -- instant reverse
  if pac.wx == -pac.dx and pac.wy == -pac.dy and (pac.dx ~= 0 or pac.dy ~= 0) and pac.p > 0 then
    pac.tx, pac.ty = (pac.tx + pac.dx) % COLS, pac.ty + pac.dy
    pac.dx, pac.dy = pac.wx, pac.wy
    pac.p = 1 - pac.p
  end
  if pac.p == 0 then
    if (pac.wx ~= 0 or pac.wy ~= 0) and open(pac.tx + pac.wx, pac.ty + pac.wy) then
      pac.dx, pac.dy = pac.wx, pac.wy
    end
    if not open(pac.tx + pac.dx, pac.ty + pac.dy) then return end
  end
  pac.p = pac.p + pac.speed * dt
  pac.mouth = pac.mouth + dt * 14
  local guard = 0
  while pac.p >= 1 and guard < 4 do
    guard = guard + 1
    pac.p = pac.p - 1
    pac.tx, pac.ty = (pac.tx + pac.dx) % COLS, pac.ty + pac.dy
    eatAt(pac.tx, pac.ty, not demo)
    if (pac.wx ~= 0 or pac.wy ~= 0) and open(pac.tx + pac.wx, pac.ty + pac.wy) then
      pac.dx, pac.dy = pac.wx, pac.wy
    end
    if not open(pac.tx + pac.dx, pac.ty + pac.dy) then
      pac.p = 0
      break
    end
  end
end

local function loseLife()
  dying, deathT = true, 0
  K.sfx("lose")
  K.shake(8)
  K.vibrate(0.9, 240)
  K.comboBreak()
end

local function simulate(dt, demo)
  local playing = not demo
  if clearT > 0 then
    clearT = clearT - dt
    if clearT <= 0 then
      level = level + 1
      buildMaze()
      placeActors()
      fruit.on = false
      eatenDots = 0
      if playing then K.callout(TR("level_n", level), "#FFD60A", 40, "level", 1.5) end
    end
    return
  end
  if dying then
    deathT = deathT + dt
    if deathT > 1.6 then
      lives = lives - 1
      if lives <= 0 and playing then
        K.over({stats = {{TR("level"), tostring(level)}, {TR("dots"), tostring(eatenDots)},
          {TR("ghosts"), tostring(eatenGhosts)}, {TR("fruits"), tostring(fruits)}}})
        return
      end
      placeActors()
    end
    return
  end
  if readyT > 0 then
    readyT = readyT - dt
    return
  end
  pac.speed = 7.4 + min(level - 1, 6) * 0.3
  stepPac(dt, demo)
  -- modes
  if frightT > 0 then
    frightT = frightT - dt
    if frightT <= 0 then
      for _, g in ipairs(ghosts) do if g.state == "fright" then g.state = "out" end end
    end
  else
    modeT = modeT + dt
    local limit = scatter and 6 or 20
    if modeT > limit then
      modeT, scatter = 0, not scatter
      for _, g in ipairs(ghosts) do
        if g.state == "out" and open(g.tx - g.dx, g.ty - g.dy) and g.p == 0 then g.dx, g.dy = -g.dx, -g.dy end
      end
    end
  end
  local px, py = pac.tx + pac.dx * pac.p, pac.ty + pac.dy * pac.p
  for _, g in ipairs(ghosts) do
    stepGhost(g, dt)
    if g.state == "out" or g.state == "fright" then
      local ddx = abs(g.x - px)
      if ddx > COLS / 2 then ddx = COLS - ddx end
      if ddx < 0.6 and abs(g.y - py) < 0.6 then
        if g.state == "fright" then
          g.state = "eyes"
          chain = chain + 1
          local pts = 100 * 2 ^ chain
          K.burst(g.x + 0.5, g.y + 0.5, 24, GCOL[g.i], 7, 0.7, 0.2)
          if playing then
            eatenGhosts = eatenGhosts + 1
            K.comboHit(frightT + 0.5, GCOL[g.i])
            K.addScore(pts)
            K.popup(g.x + 0.5, g.y, "+" .. pts, "#64D2FF")
            K.chord({880, 1320, 1760}, 0.12, 0.08, "square")
            K.shake(5)
          end
        elseif not demo then
          loseLife()
          return
        end
      end
    end
  end
  -- fruit
  if fruit.on then
    fruit.t = fruit.t - dt
    if fruit.t <= 0 then fruit.on = false end
    if abs(px - PSTART_X) < 0.5 and abs(py - PSTART_Y) < 0.5 then
      fruit.on = false
      K.burst(PSTART_X + 0.5, PSTART_Y + 0.5, 22, "#FF453A", 6, 0.6, 0.2)
      if playing then
        fruits = fruits + 1
        K.addScore(100 * level)
        K.popup(PSTART_X + 0.5, PSTART_Y, "+" .. 100 * level, "#FF453A")
        K.sfx("coin")
      end
    end
  end
  if dotsLeft <= 0 then
    clearT = 1.8
    if playing then
      K.addScore(500 * level)
      K.sfx("level")
      K.confetti(40)
      K.callout(TR("clear"), "#FFD60A", 40, "clear", 1.6)
    end
  end
end

function G.update(dt) simulate(dt, false) end
function G.idle(dt)
  if K.state == "title" then
    simulate(dt, true)
    if dotsLeft < dotsTotal - 120 then buildMaze() end
  end
end

-- ------------------------------------------------------------------ drawing
local function drawGhost(g, c, ox, oy, t)
  local X, Y = ox + (g.x + 0.5) * c, oy + (g.y + 0.5) * c
  local r = c * 0.46
  if g.state ~= "eyes" then
    local col = GCOL[g.i]
    if g.state == "fright" then
      col = (frightT < 2 and floor(t * 8) % 2 == 0) and "#F2F2F7" or "#3A4BFF"
    end
    K.color(col, 0.25)
    gfx.circle(X, Y, r * 1.35)
    K.color(col)
    gfx.circle(X, Y - r * 0.15, r)
    gfx.rect(X - r, Y - r * 0.15, r * 2, r * 0.95)
    local wv = sin(t * 14) * r * 0.12
    for k = -1, 1 do gfx.circle(X + k * r * 0.66, Y + r * 0.8 + (k == 0 and wv or -wv), r * 0.34) end
  end
  if g.state == "fright" then
    K.color("#FFFFFF")
    gfx.circle(X - r * 0.35, Y - r * 0.25, r * 0.14)
    gfx.circle(X + r * 0.35, Y - r * 0.25, r * 0.14)
    gfx.line(X - r * 0.5, Y + r * 0.35, X + r * 0.5, Y + r * 0.35, max(1, r * 0.12))
  else
    for k = -1, 1, 2 do
      K.color("#FFFFFF")
      gfx.circle(X + k * r * 0.38, Y - r * 0.25, r * 0.28)
      K.color("#1A2BFF")
      gfx.circle(X + k * r * 0.38 + g.dx * r * 0.12, Y - r * 0.25 + g.dy * r * 0.12, r * 0.14)
    end
  end
end

function G.draw(w, h)
  local t = K.now
  gfx.gradient(0, 0, w, h, "#05051A", "#0C0C26")
  local sx, sy = K.shakeXY()
  local c = L.cell
  local ox, oy = L.x + sx, L.y + sy
  -- walls (flash white when the level is cleared)
  local flash = clearT > 0 and floor(clearT * 6) % 2 == 0
  for i = 1, #runs do
    local r = runs[i]
    K.color(flash and "#FFFFFF" or "#1D2E9E")
    gfx.rect(ox + r[1] * c, oy + r[3] * c, (r[2] - r[1] + 1) * c, c)
  end
  K.color(flash and "#FFFFFF" or "#3D6BFF", 0.55)
  for i = 1, #runs do
    local r = runs[i]
    gfx.rect(ox + r[1] * c + c * 0.3, oy + r[3] * c + c * 0.38, (r[2] - r[1] + 1) * c - c * 0.6, c * 0.24, c * 0.12)
  end
  -- door
  K.color("#FF8AD8")
  gfx.rect(ox + DOOR_X * c, oy + (DOOR_Y + 1) * c + c * 0.4, c, c * 0.2)
  -- dots
  for y = 0, ROWS - 1 do
    for x = 0, COLS - 1 do
      local ch = cells[y * COLS + x + 1]
      if ch == "." then
        K.color("#FFE3B3")
        gfx.circle(ox + (x + 0.5) * c, oy + (y + 0.5) * c, c * 0.1)
      elseif ch == "o" then
        local pr = c * (0.26 + 0.06 * sin(t * 8))
        K.color("#FFD60A", 0.3)
        gfx.circle(ox + (x + 0.5) * c, oy + (y + 0.5) * c, pr * 1.6)
        K.color("#FFE3B3")
        gfx.circle(ox + (x + 0.5) * c, oy + (y + 0.5) * c, pr)
      end
    end
  end
  -- fruit (a cherry)
  if fruit.on then
    local X, Y = ox + (PSTART_X + 0.5) * c, oy + (PSTART_Y + 0.5) * c + sin(t * 4) * 2
    K.color("#4CD964")
    gfx.line(X - c * 0.15, Y, X + c * 0.1, Y - c * 0.4, 2)
    gfx.line(X + c * 0.2, Y + c * 0.05, X + c * 0.1, Y - c * 0.4, 2)
    K.color("#FF453A")
    gfx.circle(X - c * 0.18, Y + c * 0.1, c * 0.2)
    gfx.circle(X + c * 0.2, Y + c * 0.12, c * 0.2)
  end
  -- ghosts
  if not dying or deathT < 0.3 then
    for _, g in ipairs(ghosts) do
      if g.state == "out" or g.state == "fright" or g.state == "eyes" then
        g.x, g.y = g.tx + g.dx * g.p, g.ty + g.dy * g.p
      end
      drawGhost(g, c, ox, oy, t)
    end
  end
  -- pac
  local px, py = pac.tx + pac.dx * pac.p, pac.ty + pac.dy * pac.p
  local X, Y = ox + (px + 0.5) * c, oy + (py + 0.5) * c
  local r = c * 0.47
  local ang = math.atan(pac.dy, pac.dx)
  if dying then
    local f = min(1, deathT / 1.2)
    local m = 0.2 + f * (pi - 0.2)
    K.color("#FFD60A", 1 - max(0, (deathT - 1.2) / 0.4))
    if m < pi - 0.01 then gfx.pie(X, Y, r, -pi / 2 + m, -pi / 2 + 2 * pi - m) end
  else
    local m = 0.05 + 0.4 * abs(sin(pac.mouth))
    K.color("#FFD60A", 0.2)
    gfx.circle(X, Y, r * 1.3)
    K.color("#FFD60A")
    gfx.pie(X, Y, r, ang + m, ang + 2 * pi - m)
  end
  K.drawParticles(c, ox, oy)
  K.drawPopups(c, ox, oy, 16)
  if K.state == "play" and readyT > 0 then
    K.banner(TR("ready"), ox, oy + (HOUSE_Y + 2.1) * c, c * COLS, max(16, floor(c * 0.9)), "#FFD60A")
  end
  -- HUD
  local x = 12
  x = x + K.scorePill(x, 8) + 8
  x = x + K.pill(x, 8, "flag", TR("level_n", level), "#FFD60A") + 8
  gfx.color(0, 0, 0, 120)
  gfx.rect(x, 8, 18 + max(1, lives) * 24, 34, 17)
  K.color("#FFD60A")
  for i = 1, lives do gfx.pie(x + i * 24 - 2, 25, 9, 0.6, 2 * pi - 0.6) end
  K.bestPill(w - 60, 8)
end

return K.run(G)
