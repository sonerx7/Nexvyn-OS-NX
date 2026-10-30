-- Pong for Nexvyn OS: first to 7 against the CPU (easy / normal / hard) or two players on one console,
-- angled returns, speeding rallies, rally callouts, a CPU-vs-CPU demo behind the title screen.
local K = require("arcade")
local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi
local random = math.random

local W, H = 800, 500
local PW, PH, BR = 14, 92, 9
local WIN = 7
local G = {icon = "sports_tennis", accent = "#30D5C8", optionsHeight = 74}

local S, OX, OY = 1, 0, 0
local mode, diff = 1, 2              -- mode 1 = vs CPU, 2 = two players; diff 1..3
local p1 = {y = H / 2, vy = 0, glow = 0, score = 0, aim = H / 2, think = 0}
local p2 = {y = H / 2, vy = 0, glow = 0, score = 0, aim = H / 2, think = 0}
local PADS = {p1, p2}
local ball = {x = W / 2, y = H / 2, vx = 0, vy = 0, sp = 380}
local trail = {}
for i = 1, 20 do trail[i] = 0 end
local ti = 0
local serveT, serveDir = 0, 1
local rally, longest = 0, 0
local pointerY, pointerSide = nil, 1
local scoreFlash1, scoreFlash2 = 0, 0
local CPU = {{speed = 250, err = 70, delay = 0.22}, {speed = 380, err = 34, delay = 0.12}, {speed = 540, err = 12, delay = 0.05}}

function G.load()
  mode = store.get("mode", 1)
  diff = store.get("diff", 2)
end
function G.bestKey() return "best_" .. diff end
function G.controls()
  return {TR("c_p1"), TR("c_p2"), TR("c_touch")}
end

function G.layout(w, h)
  S = min(w / W, (h - 50) / H)
  OX, OY = floor((w - W * S) / 2), floor(50 + (h - 50 - H * S) / 2)
end

local function serve(dir)
  ball.x, ball.y = W / 2, H / 2
  ball.vx, ball.vy = 0, 0
  ball.sp = 380 + (mode == 1 and (diff - 2) * 40 or 0)
  serveT, serveDir = 0.9, dir
  rally = 0
  for i = 1, 20, 2 do trail[i], trail[i + 1] = ball.x, ball.y end
end

function G.reset()
  K.noBest = mode == 2
  p1.y, p2.y, p1.score, p2.score = H / 2, H / 2, 0, 0
  p1.vy, p2.vy = 0, 0
  longest = 0
  pointerY = nil
  serve(random() < 0.5 and -1 or 1)
end

local function setMode(m)
  mode = m
  store.set("mode", m)
  K.noBest = mode == 2
end
local function setDiff(d)
  diff = d
  store.set("diff", d)
  K.loadBest()
end

function G.options(x, y, w)
  local m = ui.segmented("mode", {TR("vs_cpu"), TR("two_players")}, mode, x, y, w, 32)
  if m ~= mode then setMode(m) end
  if mode == 1 then
    local d = ui.segmented("diff", {TR("easy"), TR("normal"), TR("hard")}, diff, x, y + 42, w, 32)
    if d ~= diff then setDiff(d) end
  else
    K.color(theme.text2)
    gfx.text(TR("two_hint"), x, y + 48, 13, "sans", "center", w)
  end
end

function G.titlePress(act)
  if act == "up" or act == "down" then setMode(3 - mode); K.sfx("click")
  elseif mode == 1 and act == "left" then setDiff(max(1, diff - 1)); K.sfx("click")
  elseif mode == 1 and act == "right" then setDiff(min(3, diff + 1)); K.sfx("click") end
end

function G.pointer(e)
  if e.type == "mousedown" or e.type == "mousemove" then
    pointerY = (e.y - OY) / S
    if e.type == "mousedown" then pointerSide = (mode == 2 and e.x > OX + W * S / 2) and 2 or 1 end
  elseif e.type == "mouseup" then
    pointerY = nil
  end
end

local function hitPaddle(p, side)
  local off = K.clamp((ball.y - p.y) / (PH / 2 + BR), -1, 1)
  local a = off * 1.0
  ball.sp = min(940, ball.sp * 1.06)
  local dir = side == 1 and 1 or -1
  ball.vx, ball.vy = cos(a) * ball.sp * dir, sin(a) * ball.sp + p.vy * 0.15
  p.glow = 1
  rally = rally + 1
  if rally > longest then longest = rally end
  local playing = K.state == "play"
  if playing then
    K.chord({side == 1 and 440 or 330, side == 1 and 660 or 495}, 0.06, 0.12, "triangle")
    if mode == 1 and side == 1 then K.addScore(10 + rally * 2) end
    if rally % 10 == 0 then
      K.callout(TR("rally_n", rally), "#30D5C8", 32, "rally")
      K.sfx("power", 0.7)
    end
  end
  K.burst(ball.x, ball.y, 12, side == 1 and "#30D5C8" or "#FF6B9A", 220, 0.4, 3, 0, side == 1 and 0 or pi, 1.6)
  K.shake(2 + ball.sp / 400)
end

local function point(winner)
  local playing = K.state == "play"
  if winner == 1 then
    p1.score = p1.score + 1
    scoreFlash1 = 1
  else
    p2.score = p2.score + 1
    scoreFlash2 = 1
  end
  K.burst(ball.x, ball.y, 40, winner == 1 and "#30D5C8" or "#FF6B9A", 300, 0.8, 3.5)
  K.shake(10)
  if playing then
    K.vibrate(0.7, 140)
    if mode == 1 then
      if winner == 1 then K.addScore(100 * diff); K.sfx("coin") else K.sfx("hit"); K.flash("#FF375F30", 0.25) end
    else
      K.sfx("coin")
    end
    if p1.score >= WIN or p2.score >= WIN then
      local fin = p1.score .. " – " .. p2.score
      local stats = {{TR("final"), fin}, {TR("longest"), tostring(longest)}}
      if mode == 1 then
        stats[#stats + 1] = {TR("difficulty"), TR(diff == 1 and "easy" or diff == 2 and "normal" or "hard")}
        if winner == 1 then K.addScore(1000 * diff) end
        K.over({title = winner == 1 and TR("you_win") or TR("cpu_wins"), stats = stats, win = winner == 1})
      else
        K.score = max(p1.score, p2.score)
        K.over({title = winner == 1 and TR("p1_wins") or TR("p2_wins"), stats = stats, win = true})
      end
      return
    end
    K.callout(winner == 1 and (mode == 1 and TR("point_you") or TR("point_p1")) or (mode == 1 and TR("point_cpu") or TR("point_p2")),
      winner == 1 and "#30D5C8" or "#FF6B9A", 30, "point")
  elseif p1.score >= WIN or p2.score >= WIN then
    p1.score, p2.score = 0, 0
  end
  serve(winner == 1 and 1 or -1)
end

local function cpu(p, dt, level)
  local c = CPU[level]
  p.think = p.think - dt
  if p.think <= 0 then
    p.think = c.delay
    local towards = (p == p2 and ball.vx > 0) or (p == p1 and ball.vx < 0)
    if towards and ball.vx ~= 0 then
      -- predict where the ball crosses the paddle line, folding wall bounces
      local px = p == p2 and W - 40 or 40
      local tt = (px - ball.x) / ball.vx
      local y = ball.y + ball.vy * tt
      local span = H - 2 * BR
      y = (y - BR) % (2 * span)
      if y > span then y = 2 * span - y end
      p.aim = y + BR + (random() - 0.5) * c.err * 2
    else
      p.aim = H / 2 + sin(K.now) * 30
    end
  end
  local d = p.aim - p.y
  local target = K.clamp(d * 8, -c.speed, c.speed)
  p.vy = K.smooth(p.vy, target, 12, dt)
end

local function human(p, dt, up, down, stickY)
  local dir = (down and 1 or 0) - (up and 1 or 0)
  if abs(stickY) > 0.2 then dir = dir - stickY end
  dir = K.clamp(dir, -1, 1)
  p.vy = K.smooth(p.vy, dir * 620, 16, dt)
end

local function simulate(dt, demo)
  local R = K.raw
  if demo then
    cpu(p1, dt, 2)
    cpu(p2, dt, 2)
  else
    local _, ly = input.stick("left")
    local _, ry = input.stick("right")
    if mode == 1 then
      local up = R.k_w or R.k_up or R.p_up
      local down = R.k_s or R.k_down or R.p_down
      human(p1, dt, up, down, ly)
      cpu(p2, dt, diff)
    else
      human(p1, dt, R.k_w or R.p_up, R.k_s or R.p_down, ly)
      human(p2, dt, R.k_up or R.p_x, R.k_down or R.p_b, ry)
    end
    if pointerY then
      local p = pointerSide == 2 and p2 or p1
      p.vy = K.clamp((pointerY - p.y) * 14, -900, 900)
    end
  end
  for _, p in ipairs(PADS) do
    p.y = K.clamp(p.y + p.vy * dt, PH / 2 + 4, H - PH / 2 - 4)
    p.glow = max(0, p.glow - dt * 3)
  end
  scoreFlash1, scoreFlash2 = max(0, scoreFlash1 - dt * 1.5), max(0, scoreFlash2 - dt * 1.5)
  if serveT > 0 then
    serveT = serveT - dt
    if serveT <= 0 then
      local a = (random() - 0.5) * 0.7
      ball.vx, ball.vy = cos(a) * ball.sp * serveDir, sin(a) * ball.sp
      if not demo then K.sfx("high", 0.6) end
    end
  else
    local steps = max(1, floor(abs(ball.vx) * dt / 6) + 1)
    local sdt = dt / steps
    for _ = 1, steps do
      ball.x, ball.y = ball.x + ball.vx * sdt, ball.y + ball.vy * sdt
      if ball.y < BR then ball.y = BR; ball.vy = abs(ball.vy); if not demo then K.sfx("bounce", 0.35) end end
      if ball.y > H - BR then ball.y = H - BR; ball.vy = -abs(ball.vy); if not demo then K.sfx("bounce", 0.35) end end
      if ball.vx < 0 and ball.x - BR < 40 + PW / 2 and ball.x > 40 - PW and abs(ball.y - p1.y) < PH / 2 + BR then
        ball.x = 40 + PW / 2 + BR
        hitPaddle(p1, 1)
      elseif ball.vx > 0 and ball.x + BR > W - 40 - PW / 2 and ball.x < W - 40 + PW and abs(ball.y - p2.y) < PH / 2 + BR then
        ball.x = W - 40 - PW / 2 - BR
        hitPaddle(p2, 2)
      end
      if ball.x < -20 then point(2) return end
      if ball.x > W + 20 then point(1) return end
    end
  end
  ti = ti % 20 + 2
  trail[ti - 1], trail[ti] = ball.x, ball.y
end

function G.update(dt) simulate(dt, false) end
function G.idle(dt) if K.state == "title" then simulate(dt, true) end end

-- ------------------------------------------------------------------ drawing
local function paddle(ox, oy, x, p, col)
  local sq = p.glow
  K.color(col, 0.2 + 0.4 * sq)
  gfx.rect(ox + (x - PW / 2 - 6) * S, oy + (p.y - PH / 2 - 6) * S, (PW + 12) * S, (PH + 12) * S, 10 * S)
  K.color(col)
  gfx.rect(ox + (x - PW / 2 + sq * 2) * S, oy + (p.y - PH / 2) * S, (PW - sq * 4) * S, PH * S, 7 * S)
  K.color("#FFFFFF", 0.4)
  gfx.rect(ox + (x - 2) * S, oy + (p.y - PH / 2 + 8) * S, 4 * S, (PH - 16) * S, 2 * S)
end

function G.draw(w, h)
  local t = K.now
  gfx.gradient(0, 0, w, h, "#071A24", "#0D0E22")
  local sx, sy = K.shakeXY()
  local ox, oy = OX + sx, OY + sy
  K.color("#FFFFFF", 0.05)
  gfx.rect(ox, oy, W * S, H * S, 12 * S)
  K.color("#30D5C8", 0.35)
  gfx.rectLine(ox, oy, W * S, H * S, 12 * S, 2)
  -- big background scores
  local fs = floor(120 * S)
  K.color("#30D5C8", 0.10 + 0.4 * scoreFlash1)
  gfx.text(tostring(p1.score), ox, oy + H * S / 2 - fs * 0.6, fs, "bold", "center", W * S / 2)
  K.color("#FF6B9A", 0.10 + 0.4 * scoreFlash2)
  gfx.text(tostring(p2.score), ox + W * S / 2, oy + H * S / 2 - fs * 0.6, fs, "bold", "center", W * S / 2)
  -- center net
  K.color("#FFFFFF", 0.18)
  for y = 10, H - 20, 28 do gfx.rect(ox + (W / 2 - 2) * S, oy + y * S, 4 * S, 16 * S, 2 * S) end
  paddle(ox, oy, 40, p1, "#30D5C8")
  paddle(ox, oy, W - 40, p2, "#FF6B9A")
  -- ball
  if serveT > 0 then
    local a = 0.5 + 0.5 * sin(t * 12)
    K.color("#FFFFFF", a)
    gfx.circle(ox + ball.x * S, oy + ball.y * S, BR * S * (1 + serveT * 0.5))
    if K.state == "play" then K.banner(tostring(math.ceil(serveT * 3)), ox, oy + (H / 2 - 70) * S, W * S, 28, "#FFFFFF", 0.8) end
  else
    for k = 1, 10 do
      local j = (ti + (k - 1) * 2) % 20 + 1
      K.color("#FFFFFF", k / 30)
      gfx.circle(ox + trail[j] * S, oy + trail[j + 1] * S, (BR * 0.3 + k * 0.6) * S)
    end
    local hot = K.clamp((ball.sp - 380) / 500, 0, 1)
    K.mix("#FFFFFF", "#FF9F0A", hot, 0.3)
    gfx.circle(ox + ball.x * S, oy + ball.y * S, (BR + 6) * S)
    K.mix("#FFFFFF", "#FFD60A", hot)
    gfx.circle(ox + ball.x * S, oy + ball.y * S, BR * S)
  end
  K.drawParticles(S, ox, oy)
  -- HUD
  if mode == 1 then
    K.scorePill(12, 8)
    K.pill(w / 2, 8, "bolt", TR("rally_hud", rally), "#30D5C8", "center")
    K.bestPill(w - 60, 8)
  else
    K.pill(12, 8, "person", TR("p1"), "#30D5C8")
    K.pill(w / 2, 8, "bolt", TR("rally_hud", rally), "#FFFFFF", "center")
    K.pill(w - 60, 8, "person", TR("p2"), "#FF6B9A", "right")
  end
end

return K.run(G)
