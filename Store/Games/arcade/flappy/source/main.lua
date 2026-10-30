-- Kanatlı Kuş / Flappy Bird-style game for Nexvyn OS: tap or press A to flap through the gaps, perfect-pass
-- combos, golden coins, medals, a day-to-sunset sky with parallax layers and an autopilot demo on the title.
local K = require("arcade")
local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi
local random = math.random

local H = 600
local GROUND = 540
local PIPEW = 78
local G = {icon = "flutter_dash", accent = "#FFB020"}

local S, OX, OY, VW = 1, 0, 0, 900  -- scale, offsets and visible world width
local bird = {x = 200, y = 280, vy = 0, rot = 0, flap = 0}
local pipes = {}                     -- {x, gap (center y), size, passed, coin}
local CLOUDS = {}
for i = 1, 8 do CLOUDS[i] = {random() * 1400, 40 + random() * 220, 0.4 + random() * 0.6} end
local HILLS = {}
for i = 1, 14 do HILLS[i] = {i * 120 + random() * 60, 70 + random() * 80} end
local BEAK, WING = {0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0, 0, 0}
local scroll, speed, spacing = 0, 190, 270
local started, dying, deadAt = false, false, 0
local passed, perfects, coins = 0, 0, 0
local skyN, skyTop = -1, "#4FC3F7"

function G.controls() return {TR("c_flap"), TR("c_touch")} end

function G.layout(w, h)
  S = h / H
  VW = w / S
  OX, OY = 0, 0
  bird.x = min(260, VW * 0.3)
end

local function gapSize() return max(132, 175 - passed * 1.2) end

local function addPipe(x)
  local size = gapSize()
  local prev = pipes[#pipes]
  local cy = prev and K.clamp(prev.gap + (random() - 0.5) * 260, 120 + size / 2, GROUND - 60 - size / 2)
    or (GROUND / 2)
  pipes[#pipes + 1] = {x = x, gap = cy, size = size, passed = false, coin = random() < 0.25, got = false}
end

function G.reset()
  pipes = {}
  bird.y, bird.vy, bird.rot, bird.flap = 260, 0, 0, 0
  speed, spacing = 190, 270
  started, dying = false, false
  passed, perfects, coins = 0, 0, 0
  local x = VW + 120
  for _ = 1, 6 do addPipe(x); x = x + spacing end
end

local function flap()
  if dying then return end
  if not started then started = true end
  bird.vy = -470
  bird.flap = 1
  K.burst(bird.x - 12, bird.y + 6, 5, "#FFFFFF", 80, 0.35, 2.5, 0, pi * 0.8, 0.8)
  if K.state == "play" then K.chord({620, 930}, 0.05, 0.08, "triangle") end
end

function G.press(act)
  if act == "a" or act == "up" or act == "b" then flap() end
end

function G.pointer(e)
  if e.type == "mousedown" then flap() end
end

local function die()
  if dying then return end
  dying, deadAt = true, K.now
  bird.vy = min(bird.vy, -200)
  K.flash("#FFFFFF", 0.35)
  K.shake(12)
  K.sfx("hit")
  timer.after(0.12, function() K.sfx("lose", 0.8) end)
  K.vibrate(0.9, 200)
  K.burst(bird.x, bird.y, 30, "#FFD60A", 200, 0.7, 3)
  K.comboBreak()
end

local function finish()
  local medal = passed >= 100 and TR("platinum") or passed >= 50 and TR("gold") or passed >= 25 and TR("silver")
    or passed >= 10 and TR("bronze") or "—"
  K.over({stats = {{TR("pipes"), tostring(passed)}, {TR("perfects"), tostring(perfects)}, {TR("coins"), tostring(coins)},
    {TR("medal"), medal}}})
end

local function simulate(dt, demo)
  bird.flap = max(0, bird.flap - dt * 4)
  if not started and not demo then
    bird.y = 260 + sin(K.now * 3) * 10
    bird.rot = 0
    return
  end
  if demo then
    -- autopilot: flap when below the next gap center
    local nxt = nil
    for _, p in ipairs(pipes) do if p.x + PIPEW > bird.x - 10 then nxt = p break end end
    local target = nxt and nxt.gap + 18 or 280
    if bird.y > target and bird.vy > -50 then flap() end
  end
  bird.vy = min(720, bird.vy + 1500 * dt)
  bird.y = bird.y + bird.vy * dt
  local want = K.clamp(bird.vy / 600, -0.5, 1.35)
  bird.rot = K.smooth(bird.rot, want, bird.vy < 0 and 18 or 5, dt)
  if bird.y < 10 then bird.y, bird.vy = 10, 0 end
  if bird.y > GROUND - 14 then
    bird.y = GROUND - 14
    if demo then G.reset(); started = true return end
    if not dying then die() end
    if K.now - deadAt > 0.5 then finish() end
    return
  end
  if dying then return end
  local mv = speed * dt
  scroll = scroll + mv
  for _, p in ipairs(pipes) do
    p.x = p.x - mv
    -- collision with the two pipe rectangles (circle vs box)
    if bird.x + 13 > p.x and bird.x - 13 < p.x + PIPEW then
      if bird.y - 12 < p.gap - p.size / 2 or bird.y + 12 > p.gap + p.size / 2 then
        if demo then G.reset(); started = true return end
        die()
        return
      end
    end
    if p.coin and not p.got and abs(bird.x - (p.x + PIPEW / 2)) < 22 and abs(bird.y - p.gap) < 26 then
      p.got = true
      if not demo then
        coins = coins + 1
        K.addScore(3)
        K.popup(p.x + PIPEW / 2, p.gap - 30, "+3", "#FFD60A")
        K.sfx("coin")
      end
      K.burst(p.x + PIPEW / 2, p.gap, 18, "#FFD60A", 150, 0.5, 2.5)
    end
    if not p.passed and p.x + PIPEW < bird.x - 13 then
      p.passed = true
      if not demo then
        passed = passed + 1
        K.addScore(1)
        if abs(bird.y - p.gap) < 20 then
          perfects = perfects + 1
          local c = K.comboHit(4, "#7CFFB2")
          K.addScore(min(c, 5))
          K.popup(bird.x, bird.y - 30, TR("perfect"), "#7CFFB2")
          K.chord({784, 988, 1175}, 0.08, 0.07, "triangle")
        else
          K.comboBreak()
          K.sfx("eat", 0.7)
        end
        if passed % 10 == 0 then
          K.callout(TR("pipes_n", passed), "#FFD60A", 36, "milestone")
          K.sfx("level")
        end
        speed = min(265, 190 + passed * 1.5)
      end
    end
  end
  if pipes[1] and pipes[1].x < -PIPEW - 20 then table.remove(pipes, 1) end
  local last = pipes[#pipes]
  if last and last.x < VW + 60 then addPipe(last.x + spacing) end
end

function G.update(dt) simulate(dt, false) end
function G.idle(dt)
  if K.state == "title" then
    started = true
    simulate(dt, true)
  end
end

-- ------------------------------------------------------------------ drawing
local function drawBird(x, y, s)
  local r = bird.rot
  local c, sn = cos(r), sin(r)
  K.color("#000000", 0.2)
  gfx.circle(x + 3 * s, y + 4 * s, 17 * s)
  K.color("#FFC93C")
  gfx.circle(x, y, 17 * s)
  K.color("#FFE08A")
  gfx.circle(x - 3 * s * c + 6 * s * sn, y - 3 * s * sn - 6 * s * c, 9 * s)
  -- wing flaps with the flap timer
  local wy = -6 + bird.flap * 14 + sin(K.now * 18) * (started and 0 or 3)
  local function rp(lx, ly) return x + (lx * c - ly * sn) * s, y + (lx * sn + ly * c) * s end
  WING[1], WING[2] = rp(-14, 0)
  WING[3], WING[4] = rp(0, -2)
  WING[5], WING[6] = rp(-2, wy + 10)
  WING[7], WING[8] = rp(-12, wy + 8)
  K.color("#F29B1D")
  gfx.poly(WING)
  BEAK[1], BEAK[2] = rp(12, -4)
  BEAK[3], BEAK[4] = rp(26, 1)
  BEAK[5], BEAK[6] = rp(12, 6)
  K.color("#FF6B3D")
  gfx.poly(BEAK)
  local ex, ey = rp(7, -7)
  K.color("#FFFFFF")
  gfx.circle(ex, ey, 6 * s)
  K.color("#1A1A2E")
  local px, py = rp(9, -7)
  gfx.circle(px, py, dying and 1.5 * s or 3 * s)
end

function G.draw(w, h)
  local t = K.now
  -- sky shifts from day to sunset as the score climbs
  local f = min(1, passed / 60)
  if skyN ~= passed then
    skyN = passed
    local s1, s2 = K.rgba("#4FC3F7"), K.rgba("#FF8A65")
    skyTop = string.format("#%02X%02X%02X", floor(s1[1] + (s2[1] - s1[1]) * f * 0.6),
      floor(s1[2] + (s2[2] - s1[2]) * f * 0.6), floor(s1[3] + (s2[3] - s1[3]) * f * 0.6))
  end
  gfx.gradient(0, 0, w, h, skyTop, f > 0.5 and "#FFD3A5" or "#BDEBFF")
  local sx, sy = K.shakeXY()
  gfx.push(sx, sy)
  -- sun
  K.color("#FFF4C2", 0.8)
  gfx.circle(w * 0.78, (120 + f * 140) * S, 46 * S)
  K.color("#FFF4C2", 0.25)
  gfx.circle(w * 0.78, (120 + f * 140) * S, 70 * S)
  -- clouds (slow parallax)
  for i = 1, #CLOUDS do
    local c = CLOUDS[i]
    local x = ((c[1] - scroll * 0.15 * c[3]) % (VW + 300)) - 150
    K.color("#FFFFFF", 0.75)
    local cs = c[3] * S
    gfx.circle(x * S, c[2] * S, 26 * cs)
    gfx.circle((x + 28 * c[3]) * S, (c[2] - 10) * S, 32 * cs)
    gfx.circle((x + 60 * c[3]) * S, c[2] * S, 24 * cs)
  end
  -- hills
  K.color("#7CCB7A")
  for i = 1, #HILLS do
    local hl = HILLS[i]
    local x = ((hl[1] - scroll * 0.35) % (14 * 140)) - 120
    gfx.circle(x * S, (GROUND + 20) * S, hl[2] * 1.4 * S)
  end
  -- pipes
  for _, p in ipairs(pipes) do
    local x = p.x * S
    local gt, gb = (p.gap - p.size / 2) * S, (p.gap + p.size / 2) * S
    gfx.gradient(x, 0, PIPEW * S, gt, "#5BD15B", "#2E9E44", true)
    gfx.gradient(x, gb, PIPEW * S, GROUND * S - gb, "#5BD15B", "#2E9E44", true)
    K.color("#1F6E30")
    gfx.rectLine(x, -4, PIPEW * S, gt + 4, 0, 2)
    gfx.rectLine(x, gb, PIPEW * S, GROUND * S - gb, 0, 2)
    gfx.gradient(x - 6 * S, gt - 26 * S, (PIPEW + 12) * S, 26 * S, "#6EE36E", "#2E9E44", true, 4 * S)
    gfx.gradient(x - 6 * S, gb, (PIPEW + 12) * S, 26 * S, "#6EE36E", "#2E9E44", true, 4 * S)
    K.color("#FFFFFF", 0.25)
    gfx.rect(x + 8 * S, 0, 8 * S, gt - 26 * S)
    gfx.rect(x + 8 * S, gb + 26 * S, 8 * S, GROUND * S - gb - 26 * S)
    if p.coin and not p.got then
      local cx, cy = (p.x + PIPEW / 2) * S, (p.gap + sin(t * 4 + p.x) * 6) * S
      local wv = abs(cos(t * 3 + p.x))
      K.color("#FFD60A", 0.3)
      gfx.circle(cx, cy, 18 * S)
      K.color("#FFC300")
      gfx.rect(cx - 12 * S * wv, cy - 12 * S, 24 * S * wv, 24 * S, 12 * S * wv)
    end
  end
  -- ground
  K.color("#DED895")
  gfx.rect(0, GROUND * S, w, h - GROUND * S)
  K.color("#73BF2E")
  gfx.rect(0, GROUND * S, w, 14 * S)
  K.color("#5EA626")
  local off = (scroll % 40) * S
  for x = -off, w, 40 * S do gfx.rect(x, (GROUND + 2) * S, 20 * S, 10 * S, 3 * S) end
  drawBird(bird.x * S, bird.y * S, S)
  K.drawParticles(S, 0, 0)
  K.drawPopups(S, 0, 0, 18)
  gfx.pop()
  -- HUD: big centered score
  if K.state == "play" then
    local sc = tostring(floor(K.shown + 0.5))
    local bump = 1 + K.bump * 0.25
    local fs = floor(56 * bump / 2) * 2
    gfx.color(0, 0, 0, 90)
    gfx.text(sc, 3, 30 + 3, fs, "bold", "center", w)
    K.color("#FFFFFF")
    gfx.text(sc, 0, 30, fs, "bold", "center", w)
    if not started then
      K.banner(TR("get_ready"), 0, h * 0.3, w, 34, "#FFB020")
      K.banner(TR("tap_hint"), 0, h * 0.3 + 46, w, 18, "#FFFFFF", 0.6 + 0.4 * sin(t * 4))
    end
    K.bestPill(w - 60, 8)
  end
end

return K.run(G)
