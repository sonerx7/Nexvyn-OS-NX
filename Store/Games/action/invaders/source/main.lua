-- Uzay İstilası / Space Invaders-style shooter for Nexvyn OS: a marching formation of three invader types,
-- destructible shields, a mystery saucer, waves that start lower and shoot faster, hit streaks and a demo
-- cannon behind the title.
local K = require("arcade")
local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi
local random = math.random

local W, H = 800, 600
local COLS, ROWS = 11, 5
local CW, CH = 50, 40
local PY = 550
local G = {icon = "pest_control", accent = "#32D74B", overIcon = "pest_control"}

local TYPES = {   -- row type: color, points
  {"#FF6BD6", 30}, {"#64D2FF", 20}, {"#64D2FF", 20}, {"#7CFF6B", 10}, {"#7CFF6B", 10},
}
local S, OX, OY = 1, 0, 0
local inv = {}                 -- inv[i] = {alive, hitT}
local fx, fy, fdir, fdrop = 0, 0, 1, 0
local stepT, legs = 0, 0
local cannon = {x = W / 2, vx = 0, alive = true, respawn = 0, inv = 0}
local PB, EB = {}, {}
for i = 1, 3 do PB[i] = {x = 0, y = 0, on = false} end
for i = 1, 6 do EB[i] = {x = 0, y = 0, on = false, k = 0} end
local ufo = {on = false, x = 0, dir = 1, t = 18}
local SH = {}                  -- shields: 4 x (12 x 8) cells
local SHX = {130, 310, 490, 670}
local SC, SWC, SHC, SHY = 6, 12, 8, 470
local STARS = {}
for i = 1, 70 do STARS[i] = {random() * W, random() * H, random() * 1.5 + 0.3} end
local wave, lives, alive = 1, 3, 0
local shots, hits, killed, ufos = 0, 0, 0, 0
local pointerX = nil
local fireCd = 0
local demoT = 0

function G.controls() return {TR("c_move"), TR("c_fire"), TR("c_touch")} end

function G.layout(w, h)
  S = min(w / W, h / H)
  OX, OY = floor((w - W * S) / 2), floor((h - H * S) / 2)
end

local function buildShields()
  for b = 1, 4 do
    SH[b] = SH[b] or {}
    for y = 0, SHC - 1 do
      for x = 0, SWC - 1 do
        local on = true
        if y == 0 and (x < 2 or x > SWC - 3) then on = false end       -- rounded top corners
        if y >= SHC - 3 and x >= 4 and x <= SWC - 5 then on = false end -- arch
        SH[b][y * SWC + x + 1] = on
      end
    end
  end
end

local function buildWave()
  alive = COLS * ROWS
  for i = 1, alive do
    inv[i] = inv[i] or {}
    inv[i].alive, inv[i].hitT = true, 0
  end
  fx, fy = 120, 90 + min(5, wave - 1) * 18
  fdir, fdrop = 1, 0
  for i = 1, #EB do EB[i].on = false end
end

function G.reset()
  wave, lives = 1, 3
  shots, hits, killed, ufos = 0, 0, 0, 0
  cannon.x, cannon.vx, cannon.alive, cannon.inv = W / 2, 0, true, 0
  for i = 1, #PB do PB[i].on = false end
  ufo.on, ufo.t = false, 18
  pointerX = nil
  buildShields()
  buildWave()
end

local function invPos(i)
  local c, r = (i - 1) % COLS, floor((i - 1) / COLS)
  return fx + c * CW, fy + r * CH, r + 1
end

local function shoot()
  if not cannon.alive or fireCd > 0 then return end
  local n = 0
  for i = 1, #PB do if PB[i].on then n = n + 1 end end
  if n >= 2 then return end
  for i = 1, #PB do
    local b = PB[i]
    if not b.on then
      b.on, b.x, b.y = true, cannon.x, PY - 18
      fireCd = 0.28
      if K.state == "play" then
        shots = shots + 1
        K.sfx("shoot", 0.6)
      end
      return
    end
  end
end

function G.press(act)
  if act == "a" or act == "b" or act == "up" then shoot() end
end

function G.pointer(e)
  if e.type == "mousedown" or e.type == "mousemove" then
    if e.type == "mousedown" or pointerX then pointerX = (e.x - OX) / S end
  elseif e.type == "mouseup" then
    pointerX = nil
  end
end

-- erode a shield at world point x, y; returns true when it hit something
local function shieldHit(x, y, radius)
  for b = 1, 4 do
    local bx = SHX[b] - SWC * SC / 2
    if x >= bx - radius and x < bx + SWC * SC + radius and y >= SHY - radius and y < SHY + SHC * SC + radius then
      local cx, cy = floor((x - bx) / SC), floor((y - SHY) / SC)
      local hit = false
      for dy = -1, 1 do
        for dx = -1, 1 do
          local xx, yy = cx + dx, cy + dy
          if xx >= 0 and xx < SWC and yy >= 0 and yy < SHC then
            local k = yy * SWC + xx + 1
            if SH[b][k] and (dx == 0 and dy == 0 or random() < 0.45 or radius > 6) then
              SH[b][k] = false
              hit = true
            end
          end
        end
      end
      if hit then
        K.burst(x, y, 6, "#32D74B", 80, 0.35, 2)
        return true
      end
    end
  end
  return false
end

local function killCannon()
  cannon.alive, cannon.respawn = false, 1.6
  K.burst(cannon.x, PY, 50, "#32D74B", 220, 1.0, 3.2)
  K.burst(cannon.x, PY, 20, "#FFFFFF", 140, 0.6, 2)
  K.shake(14)
  K.flash("#FF453A50", 0.3)
  K.sfx("boom")
  K.vibrate(1, 260)
  K.comboBreak()
  lives = lives - 1
end

local function gameOver()
  local acc = shots > 0 and floor(hits / shots * 100 + 0.5) or 0
  K.over({stats = {{TR("wave"), tostring(wave)}, {TR("killed"), tostring(killed)},
    {TR("accuracy"), acc .. "%"}, {TR("ufos"), tostring(ufos)}}})
end

local function simulate(dt, demo)
  local playing = not demo
  -- cannon
  if cannon.alive then
    if demo then
      demoT = demoT + dt
      local target = W / 2
      for i = 1, COLS * ROWS do
        if inv[i].alive then
          local x = invPos(i)
          if abs(x + 16 - cannon.x) < abs(target - cannon.x) or target == W / 2 then target = x + 16 end
        end
      end
      cannon.vx = K.smooth(cannon.vx, K.clamp((target + sin(demoT) * 40 - cannon.x) * 4, -300, 300), 8, dt)
      if random() < 0.04 then shoot() end
    elseif pointerX then
      cannon.vx = K.clamp((pointerX - cannon.x) * 10, -480, 480)
      shoot()
    else
      local ax = K.axis()
      cannon.vx = K.smooth(cannon.vx, ax * 380, 16, dt)
      if K.down.a then shoot() end
    end
    cannon.x = K.clamp(cannon.x + cannon.vx * dt, 30, W - 30)
    if cannon.inv > 0 then cannon.inv = cannon.inv - dt end
  else
    cannon.respawn = cannon.respawn - dt
    if cannon.respawn <= 0 then
      if lives <= 0 and playing then gameOver() return end
      cannon.alive, cannon.inv, cannon.x = true, 1.5, W / 2
    end
  end
  if fireCd > 0 then fireCd = fireCd - dt end
  -- formation: speed grows as invaders fall
  local speed = (18 + (COLS * ROWS - alive) * 2.2 + wave * 4) * (alive <= 1 and 2.2 or 1)
  local minx, maxx, maxy = 1e9, -1e9, -1e9
  for i = 1, COLS * ROWS do
    local v = inv[i]
    if v.hitT > 0 then v.hitT = v.hitT - dt end
    if v.alive then
      local x, y = invPos(i)
      minx, maxx, maxy = min(minx, x), max(maxx, x + 34), max(maxy, y + 26)
    end
  end
  if fdrop > 0 then
    local d = min(fdrop, 60 * dt)
    fy, fdrop = fy + d, fdrop - d
  else
    fx = fx + fdir * speed * dt
    if (fdir > 0 and maxx > W - 16) or (fdir < 0 and minx < 16) then
      fdir = -fdir
      fdrop = 18
    end
  end
  stepT = stepT + dt * speed / 40
  if stepT >= 1 then
    stepT = stepT - 1
    legs = 1 - legs
    if playing then K.tone(legs == 1 and 98 or 82, 0.07, 0.14, "square") end
  end
  -- invaders erode shields and land
  if maxy > SHY then
    for i = 1, COLS * ROWS do
      if inv[i].alive then
        local x, y = invPos(i)
        if y + 26 > SHY then shieldHit(x + 17, y + 22, 12) end
      end
    end
  end
  if maxy > PY - 14 and alive > 0 then
    if demo then G.reset() return end
    if cannon.alive then
      lives = 1
      killCannon()
      K.callout(TR("landed"), "#FF453A", 34, "landed", 1.4)
      cannon.respawn = 1.2
    end
    return
  end
  -- enemy fire from the lowest invader of a random column
  local rate = 0.6 + wave * 0.15
  if random() < rate * dt * 2 and alive > 0 then
    local col = random(0, COLS - 1)
    for r = ROWS, 1, -1 do
      local i = (r - 1) * COLS + col + 1
      if inv[i].alive then
        for k = 1, min(#EB, 2 + wave) do
          local b = EB[k]
          if not b.on then
            local x, y = invPos(i)
            b.on, b.x, b.y, b.k = true, x + 17, y + 26, random(1, 2)
            break
          end
        end
        break
      end
    end
  end
  -- player bullets
  for k = 1, #PB do
    local b = PB[k]
    if b.on then
      b.y = b.y - 640 * dt
      if b.y < 30 then
        b.on = false
        if playing then K.comboBreak() end
      elseif shieldHit(b.x, b.y, 2) then
        b.on = false
        if playing then K.comboBreak() end
      else
        for i = 1, COLS * ROWS do
          local v = inv[i]
          if v.alive then
            local x, y, row = invPos(i)
            if b.x > x and b.x < x + 34 and b.y > y and b.y < y + 26 then
              v.alive = false
              alive = alive - 1
              b.on = false
              local col, pts = TYPES[row][1], TYPES[row][2]
              K.burst(x + 17, y + 13, 18, col, 160, 0.55, 2.8)
              if playing then
                hits, killed = hits + 1, killed + 1
                local c = K.comboHit(2.2, col)
                local p = pts + (c > 1 and min(c, 10) * 5 or 0)
                K.addScore(p)
                K.popup(x + 17, y, "+" .. p, col)
                K.sfx("small", 0.8)
                K.tone(300 + row * 80, 0.05, 0.08, "square")
                K.shake(2.5)
              end
              break
            end
          end
        end
        if b.on and ufo.on and abs(b.x - ufo.x) < 28 and b.y < 70 and b.y > 30 then
          b.on, ufo.on = false, false
          ufo.t = 16 + random() * 10
          K.burst(ufo.x, 50, 40, "#FF453A", 220, 0.8, 3)
          if playing then
            hits, ufos = hits + 1, ufos + 1
            local p = ({50, 100, 150, 300})[random(1, 4)]
            K.addScore(p)
            K.popup(ufo.x, 40, "+" .. p, "#FF453A")
            K.callout(TR("mystery"), "#FF453A", 30, "ufo")
            K.sfx("boom", 0.8)
            K.shake(7)
          end
        end
      end
    end
  end
  -- enemy bullets
  local ebs = 210 + wave * 18
  for k = 1, #EB do
    local b = EB[k]
    if b.on then
      b.y = b.y + ebs * dt
      if b.y > H then
        b.on = false
      elseif shieldHit(b.x, b.y + 6, 3) then
        b.on = false
      elseif cannon.alive and cannon.inv <= 0 and abs(b.x - cannon.x) < 22 and b.y > PY - 12 and b.y < PY + 14 then
        b.on = false
        if not demo then killCannon() end
      end
    end
  end
  -- mystery saucer
  ufo.t = ufo.t - dt
  if not ufo.on and ufo.t <= 0 then
    ufo.on, ufo.dir = true, random() < 0.5 and 1 or -1
    ufo.x = ufo.dir > 0 and -30 or W + 30
  end
  if ufo.on then
    ufo.x = ufo.x + ufo.dir * 120 * dt
    if playing and floor(K.now * 8) ~= floor((K.now - dt) * 8) then K.tone(ufo.x % 2 < 1 and 1200 or 900, 0.06, 0.04, "sine") end
    if ufo.x < -40 or ufo.x > W + 40 then ufo.on, ufo.t = false, 18 + random() * 10 end
  end
  if alive <= 0 then
    wave = wave + 1
    if playing then
      K.addScore(200 * (wave - 1))
      K.callout(TR("wave_n", wave), "#32D74B", 40, "wave", 1.5)
      K.sfx("level")
      K.confetti(30)
    end
    buildWave()
    if wave % 2 == 1 then buildShields() end
  end
end

function G.update(dt) simulate(dt, false) end
function G.idle(dt) if K.state == "title" then simulate(dt, true) end end

-- ------------------------------------------------------------------ drawing
local function drawInvader(x, y, row, s, ox, oy, flash)
  local col = TYPES[row][1]
  local X, Y = ox + x * s, oy + y * s
  if flash then K.color("#FFFFFF") else K.color(col) end
  if row == 1 then
    gfx.rect(X + 9 * s, Y + 2 * s, 16 * s, 18 * s, 8 * s)
    gfx.rect(X + 5 * s, Y + 10 * s, 24 * s, 8 * s, 3 * s)
  elseif row <= 3 then
    gfx.rect(X + 4 * s, Y + 5 * s, 26 * s, 14 * s, 5 * s)
    gfx.rect(X + (legs == 1 and 0 or 2) * s, Y + 2 * s, 5 * s, 10 * s, 2 * s)
    gfx.rect(X + (legs == 1 and 29 or 27) * s, Y + 2 * s, 5 * s, 10 * s, 2 * s)
  else
    gfx.rect(X + 2 * s, Y + 4 * s, 30 * s, 14 * s, 7 * s)
  end
  -- legs
  local spread = legs == 1 and 3 or 0
  gfx.rect(X + (6 - spread) * s, Y + 18 * s, 5 * s, 6 * s, 2 * s)
  gfx.rect(X + (23 + spread) * s, Y + 18 * s, 5 * s, 6 * s, 2 * s)
  if row > 3 then gfx.rect(X + 14 * s, Y + 18 * s, 6 * s, 5 * s, 2 * s) end
  -- eyes
  K.color("#10101E")
  gfx.rect(X + 11 * s, Y + 9 * s, 4 * s, 5 * s, 1)
  gfx.rect(X + 19 * s, Y + 9 * s, 4 * s, 5 * s, 1)
end

function G.draw(w, h)
  local t = K.now
  gfx.gradient(0, 0, w, h, "#05060F", "#10132A")
  local sx, sy = K.shakeXY()
  local ox, oy = OX + sx, OY + sy
  for i = 1, #STARS do
    local st = STARS[i]
    K.color("#FFFFFF", 0.25 + 0.2 * sin(t * 2 + i))
    gfx.circle(ox + st[1] * S, oy + ((st[2] + t * 8 * st[3]) % H) * S, st[3] * S)
  end
  -- ground line
  K.color("#32D74B", 0.6)
  gfx.rect(ox, oy + (PY + 22) * S, W * S, 2 * S)
  -- shields
  K.color("#32D74B")
  for b = 1, 4 do
    local bx = SHX[b] - SWC * SC / 2
    local cells = SH[b]
    for y = 0, SHC - 1 do
      for x = 0, SWC - 1 do
        if cells[y * SWC + x + 1] then
          gfx.rect(ox + (bx + x * SC) * S, oy + (SHY + y * SC) * S, SC * S + 0.5, SC * S + 0.5)
        end
      end
    end
  end
  -- invaders (bob slightly while marching)
  for i = 1, COLS * ROWS do
    local v = inv[i]
    if v.alive then
      local x, y, row = invPos(i)
      drawInvader(x, y + sin(t * 4 + i) * 1.2, row, S, ox, oy, v.hitT > 0)
    end
  end
  -- saucer
  if ufo.on then
    local X, Y = ox + ufo.x * S, oy + 50 * S
    K.color("#FF453A", 0.25)
    gfx.circle(X, Y, 30 * S)
    K.color("#FF453A")
    gfx.rect(X - 26 * S, Y - 6 * S, 52 * S, 14 * S, 7 * S)
    K.color("#FFB3AD")
    gfx.circle(X, Y - 7 * S, 10 * S)
    K.color(floor(t * 10) % 2 == 0 and "#FFD60A" or "#FFFFFF")
    for k = -1, 1 do gfx.circle(X + k * 15 * S, Y + 1 * S, 2.5 * S) end
  end
  -- bullets
  for k = 1, #PB do
    local b = PB[k]
    if b.on then
      K.color("#7DF9FF", 0.3)
      gfx.rect(ox + (b.x - 4) * S, oy + (b.y - 4) * S, 8 * S, 22 * S, 4 * S)
      K.color("#FFFFFF")
      gfx.rect(ox + (b.x - 1.5) * S, oy + b.y * S, 3 * S, 14 * S, 1.5 * S)
    end
  end
  for k = 1, #EB do
    local b = EB[k]
    if b.on then
      K.color(b.k == 1 and "#FF6BD6" or "#FFD60A")
      local zig = sin(t * 30 + k) * 3
      gfx.line(ox + (b.x - zig) * S, oy + b.y * S, ox + (b.x + zig) * S, oy + (b.y + 7) * S, 2.5 * S)
      gfx.line(ox + (b.x + zig) * S, oy + (b.y + 7) * S, ox + (b.x - zig) * S, oy + (b.y + 14) * S, 2.5 * S)
    end
  end
  -- cannon
  if cannon.alive and (cannon.inv <= 0 or floor(t * 12) % 2 == 0) then
    local X, Y = ox + cannon.x * S, oy + PY * S
    K.color("#32D74B", 0.25)
    gfx.circle(X, Y, 28 * S)
    K.color("#32D74B")
    gfx.rect(X - 22 * S, Y - 2 * S, 44 * S, 16 * S, 4 * S)
    gfx.rect(X - 14 * S, Y - 8 * S, 28 * S, 8 * S, 3 * S)
    gfx.rect(X - 3 * S, Y - 16 * S, 6 * S, 10 * S, 2 * S)
    K.color("#FFFFFF", 0.4)
    gfx.rect(X - 18 * S, Y + 1 * S, 36 * S, 3 * S, 1.5 * S)
  end
  K.drawParticles(S, ox, oy)
  K.drawPopups(S, ox, oy, 16)
  -- HUD
  local x = 12
  x = x + K.scorePill(x, 8) + 8
  x = x + K.pill(x, 8, "flag", TR("wave_n", wave), "#32D74B") + 8
  K.pill(x, 8, "favorite", tostring(max(0, lives)), "#FF375F")
  K.bestPill(w - 60, 8)
end

return K.run(G)
