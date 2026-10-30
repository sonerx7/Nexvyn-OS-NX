-- Yolu Geç / Road Crosser for Nexvyn OS: a Frogger-style game. Hop across five lanes of traffic, ride logs and
-- diving turtles over the river and fill all five lily-pad homes before the timer runs out.
local K = require("arcade")
local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi
local random = math.random

local COLS, ROWS = 13, 13
local PERIOD = COLS + 4
local HOMES = {1, 4, 6, 8, 11}
local LIFE_TIME = 30
local G = {icon = "traffic", accent = "#32D74B", stickPress = true, overIcon = "water",
  rep = {up = true, down = true, left = true, right = true}, repDelay = 0.28, repRate = 0.16}

-- lanes: row -> kind, speed (cells/s, sign = direction), object length, start positions
local LANES = {
  [1] = {kind = "river", speed = 1.6, len = 3, xs = {0, 5.5, 11}},
  [2] = {kind = "turtle", speed = -2.0, len = 2, xs = {0, 4.2, 8.5, 12.8}},
  [3] = {kind = "river", speed = 2.3, len = 4, xs = {0, 8}},
  [4] = {kind = "river", speed = 1.2, len = 2, xs = {1, 6.5, 12}},
  [5] = {kind = "turtle", speed = -1.5, len = 3, xs = {0, 5.7, 11.4}},
  [7] = {kind = "truck", speed = -1.3, len = 2, xs = {0, 6, 11.5}},
  [8] = {kind = "car", speed = 2.9, len = 1, xs = {2, 10}},
  [9] = {kind = "car", speed = -1.8, len = 1, xs = {0, 5, 10.5}},
  [10] = {kind = "car", speed = 1.5, len = 1, xs = {1, 6.5, 12}},
  [11] = {kind = "car", speed = -1.1, len = 1, xs = {0, 4.3, 8.6, 12.9}},
}
local CARCOL = {"#FF453A", "#FFD60A", "#BF5AF2", "#64D2FF", "#FF9F0A"}

local L = {cell = 44, x = 0, y = 0}
local lanePos = {}                 -- current offset per row
local frog = {x = 6, y = 12, fx = 6, fy = 12, hop = 1, face = 0, dead = false, deadT = 0, how = "road"}
local homes = {}
local fly = {home = 0, t = 0}
local level, lives, lifeT, furthest = 1, 4, LIFE_TIME, 12
local saved, totalSaved = 0, 0
local swipe = nil
local demoT = 0

function G.controls() return {TR("c_move"), TR("c_touch")} end

function G.layout(w, h)
  local top = 54
  L.cell = max(10, floor(min((w - 20) / COLS, (h - top - 34) / ROWS)))
  L.x = floor((w - L.cell * COLS) / 2)
  L.y = floor(top + (h - top - 34 - L.cell * ROWS) / 2)
end

local function speedOf(row) return LANES[row].speed * (1 + (level - 1) * 0.15) end

local function resetFrog()
  frog.x, frog.y, frog.fx, frog.fy, frog.hop, frog.face, frog.dead = 6, 12, 6, 12, 1, 0, false
  lifeT, furthest = LIFE_TIME, 12
end

function G.reset()
  level, lives, saved, totalSaved = 1, 4, 0, 0
  for r in pairs(LANES) do lanePos[r] = 0 end
  for i = 1, 5 do homes[i] = false end
  fly.home, fly.t = 0, 4
  resetFrog()
end

-- object left edges of a lane, iterated through a callback-free index
local function objX(row, i)
  local ln = LANES[row]
  return (ln.xs[i] + lanePos[row]) % PERIOD - 2
end

local function turtleUnder(row, i)
  -- the first group in each turtle lane dives every few seconds
  if LANES[row].kind ~= "turtle" or i ~= 1 then return 0 end
  local ph = (K.now * 0.9 + row) % 6
  if ph > 4.6 then return min(1, (ph - 4.6) / 0.4) * (ph > 5.6 and (6 - ph) / 0.4 or 1) end
  return 0
end

local function die(how)
  if frog.dead then return end
  frog.dead, frog.deadT, frog.how = true, 0, how
  local cx, cy = frog.x + 0.5, frog.y + 0.5
  if how == "water" then
    K.burst(cx, cy, 30, "#9EEBFF", 5, 0.7, 0.15, 6)
  else
    K.burst(cx, cy, 30, "#32D74B", 6, 0.7, 0.16, 6)
  end
  if K.state == "play" then
    K.sfx(how == "water" and "small" or "hit")
    K.sfx("lose", 0.6)
    K.shake(10)
    K.vibrate(0.9, 200)
    K.comboBreak()
    K.callout(how == "water" and TR("splash") or how == "time" and TR("time_out") or TR("squash"), "#FF453A", 30, "die")
  end
end

local function hop(dx, dy)
  if frog.dead or frog.hop < 1 then return end
  local nx, ny = frog.x + dx, frog.y + dy
  if nx < -0.4 or nx > COLS - 0.6 or ny > ROWS - 1 or ny < 0 then return end
  frog.fx, frog.fy = frog.x, frog.y
  frog.x, frog.y = nx, ny
  frog.hop = 0
  frog.face = dx > 0 and 1 or dx < 0 and 3 or dy > 0 and 2 or 0
  if K.state == "play" then K.chord({500, 750}, 0.04, 0.06, "square") end
end

function G.press(act)
  if act == "up" then hop(0, -1) elseif act == "down" then hop(0, 1)
  elseif act == "left" then hop(-1, 0) elseif act == "right" then hop(1, 0) end
end

function G.pointer(e)
  if e.type == "mousedown" then
    swipe = {x = e.x, y = e.y, moved = false}
  elseif e.type == "mousemove" and swipe then
    local dx, dy = e.x - swipe.x, e.y - swipe.y
    if abs(dx) > 30 or abs(dy) > 30 then
      if abs(dx) > abs(dy) then hop(dx > 0 and 1 or -1, 0) else hop(0, dy > 0 and 1 or -1) end
      swipe.x, swipe.y, swipe.moved = e.x, e.y, true
    end
  elseif e.type == "mouseup" and swipe then
    if not swipe.moved and not e.cancel then
      local fx, fy = L.x + (frog.x + 0.5) * L.cell, L.y + (frog.y + 0.5) * L.cell
      local dx, dy = e.x - fx, e.y - fy
      if abs(dx) > abs(dy) then hop(dx > 0 and 1 or -1, 0) else hop(0, dy > 0 and 1 or -1) end
    end
    swipe = nil
  end
end

local function landHome(playing)
  local col = floor(frog.x + 0.5)
  for i, hc in ipairs(HOMES) do
    if abs(frog.x - hc) < 0.45 and not homes[i] then
      homes[i] = true
      K.burst(hc + 0.5, 0.5, 30, "#FFD60A", 6, 0.8, 0.15)
      if playing then
        saved, totalSaved = saved + 1, totalSaved + 1
        local pts = 50 + floor(lifeT) * 10
        if fly.home == i then
          pts = pts + 200
          fly.home = 0
          K.callout(TR("fly_bonus"), "#BF5AF2", 30, "fly")
        end
        K.addScore(pts)
        K.popup(hc + 0.5, 0, "+" .. pts, "#FFD60A")
        K.comboHit(30, "#32D74B")
        K.sfx("coin")
        K.vibrate(0.4, 60)
      end
      if saved >= 5 or (not playing and totalSaved >= 5) then
        for k = 1, 5 do homes[k] = false end
        if playing then
          level = level + 1
          saved = 0
          K.addScore(1000)
          K.callout(TR("level_n", level), "#32D74B", 40, "level", 1.6)
          K.sfx("level")
          K.confetti(50)
        else
          totalSaved = 0
        end
      end
      resetFrog()
      return
    end
  end
  die("water")
end

local function simulate(dt, demo)
  local playing = not demo
  for r in pairs(LANES) do lanePos[r] = lanePos[r] + speedOf(r) * dt end
  fly.t = fly.t - dt
  if fly.t <= 0 then
    fly.t = 5 + random() * 4
    local i = random(1, 5)
    fly.home = homes[i] and 0 or i
  end
  if frog.dead then
    frog.deadT = frog.deadT + dt
    if frog.deadT > 1.1 then
      if playing then
        lives = lives - 1
        if lives <= 0 then
          K.over({stats = {{TR("level"), tostring(level)}, {TR("homes"), tostring(totalSaved)}}})
          return
        end
      end
      resetFrog()
    end
    return
  end
  if frog.hop < 1 then
    frog.hop = min(1, frog.hop + dt / 0.13)
    if frog.hop >= 1 then
      if frog.y < furthest then
        furthest = frog.y
        if playing then K.addScore(10) end
      end
      if frog.y == 0 then landHome(playing) return end
    end
  end
  if demo then
    demoT = demoT - dt
    if demoT <= 0 and frog.hop >= 1 then
      demoT = 0.35 + random() * 0.3
      local ahead = frog.y - 1
      local ln = LANES[ahead]
      local safe = true
      if ln and (ln.kind == "car" or ln.kind == "truck") then
        for i = 1, #ln.xs do
          local ox = objX(ahead, i)
          local fut = ox + speedOf(ahead) * 0.4
          if frog.x + 0.9 > min(ox, fut) - 0.3 and frog.x + 0.1 < max(ox, fut) + ln.len + 0.3 then safe = false end
        end
      end
      if safe then hop(0, -1) elseif random() < 0.3 then hop(random() < 0.5 and -1 or 1, 0) end
    end
  end
  lifeT = lifeT - dt
  if lifeT <= 0 and playing then die("time") return end
  if frog.hop < 1 then return end
  local row = frog.y
  local ln = LANES[row]
  if ln then
    if ln.kind == "car" or ln.kind == "truck" then
      for i = 1, #ln.xs do
        local ox = objX(row, i)
        if frog.x + 0.82 > ox + 0.05 and frog.x + 0.18 < ox + ln.len - 0.05 then die("road") return end
      end
    else
      local on = false
      for i = 1, #ln.xs do
        local ox = objX(row, i)
        if frog.x + 0.5 > ox and frog.x + 0.5 < ox + ln.len and turtleUnder(row, i) < 0.6 then on = true break end
      end
      if not on then die("water") return end
      frog.x = frog.x + speedOf(row) * dt
      frog.fx = frog.x
      if frog.x < -0.6 or frog.x > COLS - 0.4 then die("water") return end
    end
  end
end

function G.update(dt) simulate(dt, false) end
function G.idle(dt) if K.state == "title" then simulate(dt, true) end end

-- ------------------------------------------------------------------ drawing
local function drawFrog(ox, oy, c, t)
  local f = frog.hop
  local x = frog.fx + (frog.x - frog.fx) * f
  local y = frog.fy + (frog.y - frog.fy) * f
  local lift = sin(f * pi) * 0.25
  local X, Y = ox + (x + 0.5) * c, oy + (y + 0.5 - lift) * c
  local s = c / 44 * (1 + lift * 0.6)
  if frog.dead then
    local a = 1 - min(1, frog.deadT / 1.0)
    if frog.how == "water" then
      K.color("#FFFFFF", a)
      gfx.circleLine(X, Y, (8 + frog.deadT * 30) * s, 2)
    else
      K.color("#32D74B", a)
      gfx.rect(X - 18 * s, Y - 4 * s, 36 * s, 8 * s, 4 * s)
    end
    return
  end
  gfx.color(0, 0, 0, 60)
  gfx.circle(X, Y + (6 + lift * 20) * s, 14 * s)
  -- legs
  K.color("#1E8C3A")
  local spread = 4 + sin(f * pi) * 6
  gfx.circle(X - (13 + spread * 0.3) * s, Y + 8 * s, 6 * s)
  gfx.circle(X + (13 + spread * 0.3) * s, Y + 8 * s, 6 * s)
  gfx.circle(X - 12 * s, Y - 8 * s, 5 * s)
  gfx.circle(X + 12 * s, Y - 8 * s, 5 * s)
  K.color("#32D74B")
  gfx.circle(X, Y, 14 * s)
  K.color("#7CFC6A")
  gfx.circle(X, Y + 3 * s, 8 * s)
  -- eyes look where the frog faces
  local ex = frog.face == 1 and 4 or frog.face == 3 and -4 or 0
  local ey = frog.face == 2 and 4 or frog.face == 0 and -4 or 0
  for k = -1, 1, 2 do
    K.color("#FFFFFF")
    gfx.circle(X + k * 7 * s, Y - 9 * s, 5 * s)
    K.color("#1C1C1E")
    gfx.circle(X + k * 7 * s + ex * 0.4 * s, Y - 9 * s + ey * 0.4 * s, 2.5 * s)
  end
end

function G.draw(w, h)
  local t = K.now
  gfx.gradient(0, 0, w, h, "#0E2A1A", "#0B1A10")
  local sx, sy = K.shakeXY()
  local c = L.cell
  local ox, oy = L.x + sx, L.y + sy
  local fw = c * COLS
  gfx.clip(L.x, L.y - 4, fw, c * ROWS + 8)
  -- home row
  K.color("#1F6E30")
  gfx.rect(ox, oy, fw, c)
  for i, hc in ipairs(HOMES) do
    local X = ox + hc * c
    K.color("#1565C0")
    gfx.rect(X - c * 0.1, oy + c * 0.15, c * 1.2, c * 0.85, c * 0.2)
    K.color("#4CAF50")
    gfx.circle(X + c * 0.5, oy + c * 0.6, c * 0.36)
    if homes[i] then
      K.color("#32D74B")
      gfx.circle(X + c * 0.5, oy + c * 0.55, c * 0.3)
      K.color("#FFFFFF")
      gfx.circle(X + c * 0.38, oy + c * 0.4, c * 0.08)
      gfx.circle(X + c * 0.62, oy + c * 0.4, c * 0.08)
    elseif fly.home == i then
      gfx.icon("pest_control", X + c * 0.5, oy + c * 0.58 + sin(t * 8) * 2, c * 0.55, "#BF5AF2")
    end
  end
  -- river with moving wave lines
  gfx.gradient(ox, oy + c, fw, c * 5, "#0A4F9E", "#1976D2")
  K.color("#FFFFFF", 0.12)
  for r = 1, 5 do
    for k = 0, 5 do
      local wx = ((k * 3.1 + t * (r % 2 == 0 and -0.6 or 0.6)) % COLS) * c
      gfx.rect(ox + wx, oy + (r + 0.5) * c, c * 0.6, 2, 1)
    end
  end
  -- median and start rows
  K.color("#5E3FA8")
  gfx.rect(ox, oy + 6 * c, fw, c)
  gfx.rect(ox, oy + 12 * c, fw, c)
  K.color("#FFFFFF", 0.08)
  for k = 0, COLS - 1, 2 do
    gfx.rect(ox + k * c, oy + 6 * c, c, c)
    gfx.rect(ox + (k + 1) * c, oy + 12 * c, c, c)
  end
  -- road
  K.color("#2C2C34")
  gfx.rect(ox, oy + 7 * c, fw, c * 5)
  K.color("#FFFFFF", 0.35)
  for r = 8, 11 do
    for k = 0, COLS - 1 do gfx.rect(ox + (k + 0.25) * c, oy + r * c - 1, c * 0.5, 2) end
  end
  -- lane objects
  for row, ln in pairs(LANES) do
    for i = 1, #ln.xs do
      local X = ox + objX(row, i) * c
      local Y = oy + row * c
      local lw = ln.len * c
      if ln.kind == "river" then
        K.color("#6D4C2F")
        gfx.rect(X + 2, Y + c * 0.14, lw - 4, c * 0.72, c * 0.36)
        K.color("#8D6E4A")
        gfx.rect(X + 6, Y + c * 0.22, lw - 12, c * 0.16, c * 0.08)
        K.color("#A1887F")
        gfx.circle(X + lw - c * 0.3, Y + c * 0.5, c * 0.2)
        K.color("#6D4C2F")
        gfx.circleLine(X + lw - c * 0.3, Y + c * 0.5, c * 0.1, 2)
      elseif ln.kind == "turtle" then
        local under = turtleUnder(row, i)
        for k = 0, ln.len - 1 do
          local tx = X + (k + 0.5) * c
          local bob = sin(t * 4 + k) * 1.5
          K.color("#2E7D32", 1 - under * 0.8)
          gfx.circle(tx + (ln.speed > 0 and 0.36 or -0.36) * c, Y + c * 0.5 + bob, c * 0.14)
          K.color("#43A047", 1 - under * 0.8)
          gfx.circle(tx, Y + c * 0.5 + bob, c * 0.38)
          K.color("#1B5E20", 1 - under * 0.8)
          gfx.circleLine(tx, Y + c * 0.5 + bob, c * 0.22, 2)
        end
      else
        local col = ln.kind == "truck" and "#ECEFF1" or CARCOL[(row + i) % #CARCOL + 1]
        local dir = ln.speed > 0 and 1 or -1
        gfx.color(0, 0, 0, 70)
        gfx.rect(X + 4, Y + c * 0.22, lw - 4, c * 0.66, 8)
        K.color(col)
        gfx.rect(X + 2, Y + c * 0.16, lw - 4, c * 0.66, c * 0.16)
        K.color("#1C1C1E", 0.7)
        local wx = dir > 0 and X + lw - c * 0.45 or X + c * 0.15
        gfx.rect(wx, Y + c * 0.24, c * 0.28, c * 0.5, 3)
        K.color("#FFF4B3")
        local hx = dir > 0 and X + lw - 4 or X + 4
        gfx.circle(hx, Y + c * 0.28, c * 0.07)
        gfx.circle(hx, Y + c * 0.70, c * 0.07)
        K.color("#FFF4B3", 0.18)
        gfx.circle(hx + dir * c * 0.4, Y + c * 0.5, c * 0.4)
      end
    end
  end
  drawFrog(ox, oy, c, t)
  K.drawParticles(c, ox, oy)
  K.drawPopups(c, ox, oy, 16)
  gfx.unclip()
  -- timer bar under the field
  local f = K.clamp(lifeT / LIFE_TIME, 0, 1)
  local by = oy + ROWS * c + 10
  gfx.color(0, 0, 0, 110)
  gfx.rect(ox, by, fw, 14, 7)
  if f < 0.25 then K.color("#FF453A", 0.7 + 0.3 * sin(t * 10)) else K.mix("#FF9F0A", "#32D74B", f) end
  gfx.rect(ox + 2, by + 2, (fw - 4) * f, 10, 5)
  -- HUD
  local x = 12
  x = x + K.scorePill(x, 8) + 8
  x = x + K.pill(x, 8, "flag", TR("level_n", level), "#32D74B") + 8
  K.pill(x, 8, "favorite", tostring(max(0, lives)), "#FF375F")
  K.bestPill(w - 60, 8)
end

return K.run(G)
