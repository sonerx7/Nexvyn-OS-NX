-- Tuğla Kır / Breakout for Nexvyn OS: paddle and ball, tough bricks, power-ups (wide paddle, multi-ball,
-- slow ball, extra life), endless generated levels, brick combos, an AI demo behind the title screen and
-- stick / d-pad / touch-drag / keyboard controls.
local K = require("arcade")
local floor, min, max, abs, sqrt, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sqrt, math.sin,
  math.cos, math.pi
local random = math.random

local W, H = 640, 480
local COLS, ROWS = 10, 7
local BW, BH, BX0, BY0 = 58, 20, 25, 64
local PADY = 440
local G = {icon = "grid_view", accent = "#FF9F0A"}

local S, OX, OY = 1, 0, 0
local bricks = {}               -- {x, y, hp, max, col, hitT, delay}
local balls = {}                -- {x, y, vx, vy, stuck, trail, ti}
local drops = {}                -- falling power-ups {x, y, kind, t}
local pad = {x = W / 2, w = 96, wideT = 0, squash = 0}
local level, lives, left, speed = 1, 3, 0, 330
local slowT, levelAt = 0, 0
local broken, powers = 0, 0
local pointerX = nil
local ROWCOL = {"#FF453A", "#FF9F0A", "#FFD60A", "#32D74B", "#64D2FF", "#0A84FF", "#BF5AF2"}
local POW = {wide = {"open_in_full", "#32D74B"}, multi = {"scatter_plot", "#64D2FF"},
  slow = {"speed", "#FFD60A"}, life = {"favorite", "#FF375F"}}
local POWKEYS = {"wide", "multi", "multi", "slow", "wide", "life"}

function G.controls() return {TR("c_move"), TR("c_launch"), TR("c_touch")} end

function G.layout(w, h)
  S = min(w / W, h / H)
  OX, OY = floor((w - W * S) / 2), floor((h - H * S) / 2)
end

local function pattern(lv, c, r)
  local p = (lv - 1) % 5
  if p == 0 then return true
  elseif p == 1 then return c >= r - 1 and c <= COLS - r
  elseif p == 2 then return (c + r) % 2 == 0
  elseif p == 3 then return (c ~= 4 and c ~= 5) or r > 5
  else return r % 2 == 1 or c == 0 or c == COLS - 1 end
end

local function buildLevel()
  bricks = {}
  left = 0
  levelAt = K.now
  for r = 0, ROWS - 1 do
    for c = 0, COLS - 1 do
      if pattern(level, c, r) then
        local hp = 1
        if level >= 2 and r < 2 then hp = 2 end
        if level >= 4 and r == 0 then hp = 3 end
        bricks[#bricks + 1] = {x = BX0 + c * BW, y = BY0 + r * BH, hp = hp, max = hp, col = ROWCOL[r + 1], hitT = 0,
          delay = (ROWS - r) * 0.05 + c * 0.02}
        left = left + 1
      end
    end
  end
end

local function newBall(x, y, vx, vy, stuck)
  local tr = {}
  for i = 1, 12, 2 do tr[i], tr[i + 1] = x, y end
  local b = {x = x, y = y, vx = vx, vy = vy, stuck = stuck, trail = tr, ti = 0}
  balls[#balls + 1] = b
  return b
end

local function serve()
  balls, drops = {}, {}
  newBall(pad.x, PADY - 10, 0, 0, true)
end

function G.reset()
  level, lives, speed = 1, 3, 330
  pad.x, pad.w, pad.wideT = W / 2, 96, 0
  slowT, broken, powers = 0, 0, 0
  pointerX = nil
  buildLevel()
  serve()
end

local function launch()
  for _, b in ipairs(balls) do
    if b.stuck then
      b.stuck = false
      local a = -pi / 2 + (random() - 0.5) * 0.6
      b.vx, b.vy = cos(a) * speed, sin(a) * speed
      if K.state == "play" then K.sfx("high") end
    end
  end
end

function G.press(act)
  if act == "a" or act == "up" then launch() end
end

function G.pointer(e)
  if e.type == "mousedown" or e.type == "mousemove" then
    pointerX = (e.x - OX) / S
    if e.type == "mousedown" and balls[1] and balls[1].stuck then launch() end
  elseif e.type == "mouseup" then
    pointerX = nil
  end
end

local function hitBrick(br)
  local playing = K.state == "play"
  br.hp = br.hp - 1
  br.hitT = 0.18
  if br.hp <= 0 then
    left = left - 1
    broken = broken + 1
    local combo = playing and K.comboHit(2.5, br.col) or 1
    local pts = 10 * br.max * level * min(combo, 8)
    if playing then
      K.addScore(pts)
      if combo > 1 then K.popup(br.x + BW / 2, br.y, "+" .. pts, br.col) end
      K.sfx("pop", 0.8)
      K.tone(500 + min(combo, 12) * 70, 0.05, 0.08, "triangle")
    end
    K.burst(br.x + BW / 2, br.y + BH / 2, 14, br.col, 170, 0.6, 3.2, 380)
    K.burst(br.x + BW / 2, br.y + BH / 2, 5, "#FFFFFF", 120, 0.3, 2)
    K.shake(2 + min(combo, 6) * 0.5)
    if random() < 0.13 then
      drops[#drops + 1] = {x = br.x + BW / 2, y = br.y + BH / 2, kind = POWKEYS[random(#POWKEYS)], t = 0}
    end
  else
    if playing then K.addScore(5); K.sfx("hit", 0.7) end
    K.burst(br.x + BW / 2, br.y + BH / 2, 5, "#FFFFFF", 90, 0.25, 2)
  end
end

-- circle vs bricks: reflect on the axis with the smallest overlap
local function collideBricks(b)
  for i = 1, #bricks do
    local br = bricks[i]
    if br.hp > 0 then
      local cx = max(br.x, min(b.x, br.x + BW - 2))
      local cy = max(br.y, min(b.y, br.y + BH - 2))
      local ddx, ddy = b.x - cx, b.y - cy
      if ddx * ddx + ddy * ddy < 49 then
        local ox = min(b.x + 7 - br.x, br.x + BW - 2 - (b.x - 7))
        local oy = min(b.y + 7 - br.y, br.y + BH - 2 - (b.y - 7))
        if ox < oy then
          b.vx = (b.x < br.x + BW / 2) and -abs(b.vx) or abs(b.vx)
        else
          b.vy = (b.y < br.y + BH / 2) and -abs(b.vy) or abs(b.vy)
        end
        hitBrick(br)
        return
      end
    end
  end
end

local function applyPower(kind)
  powers = powers + 1
  local p = POW[kind]
  if kind == "wide" then
    pad.wideT = 12
    K.callout(TR("p_wide"), p[2], 30, "pow")
  elseif kind == "multi" then
    local n = #balls
    for i = 1, n do
      local b = balls[i]
      if not b.stuck and #balls < 9 then
        local sp = sqrt(b.vx * b.vx + b.vy * b.vy)
        local a0 = math.atan(b.vy, b.vx)
        for k = -1, 1, 2 do newBall(b.x, b.y, cos(a0 + k * 0.45) * sp, sin(a0 + k * 0.45) * sp, false) end
      end
    end
    K.callout(TR("p_multi"), p[2], 30, "pow")
  elseif kind == "slow" then
    slowT = 8
    K.callout(TR("p_slow"), p[2], 30, "pow")
  else
    lives = min(6, lives + 1)
    K.callout(TR("p_life"), p[2], 30, "pow")
  end
  K.burst(pad.x, PADY, 24, p[2], 200, 0.6, 3, 0, -pi / 2, 2.2)
  K.sfx("power")
  K.vibrate(0.4, 70)
end

-- the AI paddle behind the title card follows the lowest falling ball
local function aiTarget()
  local best, by = W / 2, -1
  for _, b in ipairs(balls) do
    if b.vy > 0 and b.y > by then best, by = b.x + sin(K.now * 1.3) * 30, b.y end
  end
  return best
end

local function simulate(dt, demo)
  if demo then
    pad.x = K.smooth(pad.x, aiTarget(), 7, dt)
    if balls[1] and balls[1].stuck and K.now - levelAt > 1 then launch() end
  elseif pointerX then
    pad.x = K.smooth(pad.x, pointerX, 22, dt)
  else
    local ax = K.axis()
    pad.vx = K.smooth(pad.vx or 0, ax * 680, 18, dt)
    pad.x = pad.x + pad.vx * dt
  end
  if pad.wideT > 0 then pad.wideT = pad.wideT - dt end
  if slowT > 0 then slowT = slowT - dt end
  pad.w = K.smooth(pad.w, pad.wideT > 0 and 150 or 96, 10, dt)
  pad.x = K.clamp(pad.x, pad.w / 2 + 4, W - pad.w / 2 - 4)
  pad.squash = max(0, pad.squash - dt * 5)
  for i = 1, #bricks do
    local br = bricks[i]
    if br.hitT > 0 then br.hitT = br.hitT - dt end
  end
  local factor = slowT > 0 and 0.65 or 1
  local i = 1
  while i <= #balls do
    local b = balls[i]
    local lost = false
    if b.stuck then
      b.x, b.y = pad.x, PADY - 10
    else
      local sp = sqrt(b.vx * b.vx + b.vy * b.vy) * factor
      local steps = max(1, floor(sp * dt / 4) + 1)
      local sdt = dt * factor / steps
      for _ = 1, steps do
        b.x, b.y = b.x + b.vx * sdt, b.y + b.vy * sdt
        local wall = false
        if b.x < 7 then b.x = 7; b.vx = abs(b.vx); wall = true end
        if b.x > W - 7 then b.x = W - 7; b.vx = -abs(b.vx); wall = true end
        if b.y < 47 then b.y = 47; b.vy = abs(b.vy); wall = true end
        if wall then
          if not demo then K.sfx("bounce", 0.4) end
          K.burst(b.x, b.y, 4, "#B9A8FF", 70, 0.25, 1.6)
        end
        if b.vy > 0 and b.y + 7 >= PADY and b.y < PADY + 12 and abs(b.x - pad.x) <= pad.w / 2 + 7 then
          local off = K.clamp((b.x - pad.x) / (pad.w / 2), -1, 1)
          local a = -pi / 2 + off * 1.05
          local sp2 = min(560, sqrt(b.vx * b.vx + b.vy * b.vy) + 4)
          b.vx, b.vy = cos(a) * sp2, sin(a) * sp2
          b.y = PADY - 7
          pad.squash = 1
          if not demo then
            K.sfx("bounce", 0.8)
            K.comboBreak()
          end
          K.burst(b.x, PADY, 6, "#FFFFFF", 90, 0.3, 2, 0, -pi / 2, 1.5)
        end
        collideBricks(b)
        if b.y > H + 12 then lost = true break end
      end
      if not lost and abs(b.vy) < 90 then b.vy = (b.vy < 0 and -90 or 90) end
    end
    b.ti = b.ti % 12 + 2
    b.trail[b.ti - 1], b.trail[b.ti] = b.x, b.y
    if lost then table.remove(balls, i) else i = i + 1 end
  end
  if #balls == 0 then
    if demo then serve() return end
    lives = lives - 1
    K.comboBreak()
    K.shake(10)
    K.flash("#FF453A50", 0.3)
    K.vibrate(0.8, 160)
    if lives <= 0 then
      K.over({stats = {{TR("level"), tostring(level)}, {TR("bricks"), tostring(broken)},
        {TR("powerups"), tostring(powers)}}})
      return
    end
    K.sfx("lose", 0.7)
    K.callout(TR("ball_lost"), "#FF453A", 30, "lost")
    pad.wideT, slowT = 0, 0
    serve()
  end
  i = 1
  while i <= #drops do
    local d = drops[i]
    d.y = d.y + 130 * dt
    d.t = d.t + dt
    if d.y > PADY - 12 and d.y < PADY + 16 and abs(d.x - pad.x) < pad.w / 2 + 12 then
      if demo then table.remove(drops, i) else applyPower(d.kind); table.remove(drops, i) end
    elseif d.y > H + 20 then
      table.remove(drops, i)
    else
      i = i + 1
    end
  end
  if left <= 0 then
    level = level + 1
    if not demo then
      K.addScore(100 * (level - 1))
      K.callout(TR("level_n", level), "#FFD60A", 40, "level", 1.6)
      K.sfx("level")
      K.confetti(40)
    end
    speed = min(470, 330 + (level - 1) * 22)
    buildLevel()
    serve()
  end
end

function G.update(dt) simulate(dt, false) end
function G.idle(dt) if K.state == "title" then simulate(dt, true) end end

-- ------------------------------------------------------------------ drawing
function G.draw(w, h)
  local t = K.now
  gfx.gradient(0, 0, w, h, "#1A1033", "#0B0A1A")
  local sx, sy = K.shakeXY()
  local ox, oy = OX + sx, OY + sy
  -- playfield frame with a slow moving glow line
  K.color("#FFFFFF", 0.04)
  gfx.rect(ox, oy + 40 * S, W * S, (H - 40) * S, 10 * S)
  K.color("#7D5BFF", 0.5)
  gfx.rectLine(ox, oy + 40 * S, W * S, (H - 40) * S, 10 * S, 2)
  K.color("#7D5BFF", 0.08)
  for k = 0, 5 do
    local gy = oy + (60 + ((t * 30 + k * 80) % 400)) * S
    gfx.rect(ox + 2, gy, W * S - 4, 1)
  end
  -- bricks drop in row by row when a level starts
  for i = 1, #bricks do
    local br = bricks[i]
    if br.hp > 0 then
      local e = K.easeOutBack((t - levelAt - br.delay) / 0.45)
      if e > 0 then
        local x, y, bw, bh = ox + br.x * S, oy + (br.y - (1 - e) * 120) * S, (BW - 4) * S, (BH - 4) * S
        local a = 0.55 + 0.45 * br.hp / br.max
        if br.hitT > 0 then K.color("#FFFFFF") else K.color(br.col, a * K.clamp(e, 0, 1)) end
        gfx.rect(x, y, bw, bh, 4 * S)
        K.color("#FFFFFF", 0.28)
        gfx.rect(x + 3 * S, y + 2 * S, bw - 6 * S, 4 * S, 2 * S)
        if br.max > 1 then
          K.color("#000000", 0.35)
          for k = 1, br.hp do gfx.circle(x + bw / 2 + (k - (br.hp + 1) / 2) * 9 * S, y + bh * 0.62, 2.2 * S) end
        end
      end
    end
  end
  -- power-up capsules wobble as they fall
  for _, d in ipairs(drops) do
    local p = POW[d.kind]
    local wob = sin(d.t * 8) * 3
    K.color(p[2], 0.3)
    gfx.rect(ox + (d.x - 20 + wob) * S, oy + (d.y - 14) * S, 40 * S, 28 * S, 14 * S)
    K.color(p[2])
    gfx.rect(ox + (d.x - 16 + wob) * S, oy + (d.y - 11) * S, 32 * S, 22 * S, 11 * S)
    gfx.icon(p[1], ox + (d.x + wob) * S, oy + d.y * S, 17 * S, "#101018")
  end
  -- paddle squashes a little on every hit
  local sq = pad.squash
  local pw, ph = pad.w + sq * 10, 12 - sq * 4
  local px = ox + (pad.x - pw / 2) * S
  local pc = pad.wideT > 0 and "#32D74B" or "#7D5BFF"
  K.color(pc, 0.25 + 0.15 * sin(t * 5))
  gfx.rect(px - 5 * S, oy + (PADY - 5 + sq * 2) * S, (pw + 10) * S, (ph + 10) * S, 10 * S)
  gfx.gradient(px, oy + (PADY + sq * 2) * S, pw * S, ph * S, "#E5DEFF", pc, false, 6 * S)
  -- balls with trails
  for _, b in ipairs(balls) do
    local tr = b.trail
    for k = 1, 6 do
      local j = (b.ti + (k - 1) * 2) % 12 + 1
      K.color(slowT > 0 and "#FFD60A" or "#B9A8FF", k / 14)
      gfx.circle(ox + tr[j] * S, oy + tr[j + 1] * S, (3 + k * 0.6) * S)
    end
    K.color("#FFFFFF", 0.25)
    gfx.circle(ox + b.x * S, oy + b.y * S, 11 * S)
    K.color("#FFFFFF")
    gfx.circle(ox + b.x * S, oy + b.y * S, 7 * S)
  end
  K.drawParticles(S, ox, oy)
  K.drawPopups(S, ox, oy, 18)
  -- HUD
  local x = 12
  x = x + K.scorePill(x, 8) + 8
  x = x + K.pill(x, 8, "flag", TR("level_n", level), "#64D2FF") + 8
  K.pill(x, 8, "favorite", tostring(lives), "#FF375F")
  K.bestPill(w - 60, 8)
  if K.state == "play" and balls[1] and balls[1].stuck then
    K.banner(TR("launch_hint"), ox, oy + 340 * S, W * S, 18, "#FFFFFF", 0.6 + 0.4 * sin(t * 4))
  end
end

return K.run(G)
