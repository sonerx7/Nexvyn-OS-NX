-- Köstebek Vur / Whack-a-Mole for Nexvyn OS: 60-second rounds, moles that pop up faster and faster, golden
-- moles, tough helmet moles, bombs to avoid, clocks for extra time and a combo multiplier for hit streaks.
-- Touch / mouse, controller cursor and number keys 1-9.
local K = require("arcade")
local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi
local random = math.random

local ROUND = 60
local G = {icon = "cruelty_free", accent = "#A0522D", stickPress = true, overIcon = "timer"}

local holes = {}
for i = 1, 9 do holes[i] = {state = "idle", t = 0, dur = 1, kind = "mole", hp = 1, x = 0, y = 0} end
local L = {cell = 150, x = 0, y = 0, r = 50}
local cur = 5
local timeLeft, spawnT, elapsed = ROUND, 0.6, 0
local hits, misses, golden, bombs = 0, 0, 0, 0
local hammer = {x = 0, y = 0, swing = 0, hole = 0}
local HAM = {0, 0, 0, 0, 0, 0, 0, 0}
local HEAD = {0, 0, 0, 0, 0, 0, 0, 0}
local lastTick = 0

function G.controls() return {TR("c_pad"), TR("c_keys"), TR("c_touch")} end

function G.layout(w, h)
  local top = 64
  local cs = floor(min((w - 40) / 3, (h - top - 20) / 3))
  L.cell = cs
  L.x = floor((w - cs * 3) / 2)
  L.y = floor(top + (h - top - 10 - cs * 3) / 2)
  L.r = cs * 0.36
  for i = 1, 9 do
    local c, r = (i - 1) % 3, floor((i - 1) / 3)
    holes[i].x = L.x + (c + 0.5) * cs
    holes[i].y = L.y + (r + 0.62) * cs
  end
end

function G.reset()
  for i = 1, 9 do holes[i].state, holes[i].t = "idle", 0 end
  cur = 5
  timeLeft, spawnT, elapsed = ROUND, 0.6, 0
  hits, misses, golden, bombs = 0, 0, 0, 0
  hammer.swing = 0
  lastTick = 0
end

local function difficulty() return min(1, elapsed / ROUND) end

local function spawn()
  local up = 0
  for i = 1, 9 do if holes[i].state ~= "idle" then up = up + 1 end end
  local d = difficulty()
  if up >= 1 + floor(d * 3) then return end
  for _ = 1, 12 do
    local hl = holes[random(1, 9)]
    if hl.state == "idle" then
      local r = random()
      hl.kind, hl.hp = "mole", 1
      if r < 0.08 then hl.kind = "gold"
      elseif r < 0.18 + d * 0.08 then hl.kind = "bomb"
      elseif r < 0.30 then hl.kind, hl.hp = "helmet", 2
      elseif r < 0.34 then hl.kind = "clock" end
      hl.state, hl.t = "up", 0
      hl.dur = (hl.kind == "gold" and 0.6 or 1.15) * (1 - d * 0.45)
      if K.state == "play" then K.tone(hl.kind == "bomb" and 220 or 520, 0.04, 0.05, "sine") end
      return
    end
  end
end

local function whack(i)
  local hl = holes[i]
  hammer.hole, hammer.swing = i, 1
  hammer.x, hammer.y = hl.x, hl.y - L.r * 0.4
  local playing = K.state == "play"
  if hl.state ~= "up" then
    if playing then
      misses = misses + 1
      K.comboBreak()
      K.sfx("drop", 0.6)
    end
    K.burst(hl.x, hl.y, 6, "#8B5A2B", 120, 0.4, 3, 300, -pi / 2, 1.2)
    return
  end
  hl.hp = hl.hp - 1
  if hl.hp > 0 then
    -- helmet knocked off
    K.burst(hl.x, hl.y - L.r * 0.8, 10, "#B0B0B8", 200, 0.5, 3, 400, -pi / 2, 1.5)
    if playing then K.chord({880, 1320}, 0.06, 0.1, "square") end
    hl.t = min(hl.t, 0.2)
    return
  end
  hl.state, hl.t = "hit", 0
  if hl.kind == "bomb" then
    K.burst(hl.x, hl.y - L.r * 0.4, 50, "#FF9F0A", 320, 0.8, 4)
    K.burst(hl.x, hl.y - L.r * 0.4, 20, "#3A3A3C", 200, 0.9, 5)
    if playing then
      bombs = bombs + 1
      K.addScore(-30)
      if K.score < 0 then K.score = 0 end
      K.popup(hl.x, hl.y - L.r, "-30", "#FF453A")
      K.comboBreak()
      K.sfx("boom")
      K.shake(16)
      K.flash("#FF453A60", 0.3)
      K.vibrate(1, 260)
      K.callout(TR("boom"), "#FF453A", 34, "boom")
    end
    return
  end
  if not playing then
    K.burst(hl.x, hl.y - L.r * 0.4, 10, "#FFD60A", 180, 0.4, 2.5)
    return
  end
  hits = hits + 1
  local combo = K.comboHit(1.6, "#FFD60A")
  local mult = 1 + floor(combo / 5)
  local base = hl.kind == "gold" and 50 or hl.kind == "helmet" and 30 or hl.kind == "clock" and 10 or 10
  local pts = base * mult
  K.addScore(pts)
  K.popup(hl.x, hl.y - L.r * 1.2, mult > 1 and ("+" .. pts .. "  x" .. mult) or ("+" .. pts),
    hl.kind == "gold" and "#FFD60A" or "#FFFFFF")
  if hl.kind == "gold" then
    golden = golden + 1
    K.sfx("coin")
    K.burst(hl.x, hl.y - L.r * 0.4, 30, "#FFD60A", 260, 0.7, 3)
  elseif hl.kind == "clock" then
    timeLeft = timeLeft + 3
    K.callout(TR("plus_time"), "#64D2FF", 30, "time")
    K.sfx("power")
  else
    K.chord({392 + min(combo, 12) * 30, 588 + min(combo, 12) * 45}, 0.07, 0.1, "square")
  end
  K.tone(120, 0.06, 0.2, "noise")
  K.burst(hl.x, hl.y - L.r * 0.4, 12, "#FFFFFF", 200, 0.35, 2.5)
  K.shake(4)
  K.vibrate(0.35, 40)
  if combo == 5 or combo == 10 or combo == 20 then K.callout(TR("mult_n", mult), "#FF9F0A", 38, "mult") end
end

function G.press(act)
  local c, r = (cur - 1) % 3, floor((cur - 1) / 3)
  if act == "left" then c = (c + 2) % 3
  elseif act == "right" then c = (c + 1) % 3
  elseif act == "up" then r = (r + 2) % 3
  elseif act == "down" then r = (r + 1) % 3
  elseif act == "a" or act == "b" then whack(cur) return end
  cur = r * 3 + c + 1
  K.sfx("move", 0.5)
end

-- number keys follow the numeric keypad layout: 7 8 9 on the top row
local KEYPAD = {["7"] = 1, ["8"] = 2, ["9"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["1"] = 7, ["2"] = 8, ["3"] = 9}
function G.key(k)
  local i = KEYPAD[k]
  if i then cur = i; whack(i) end
end

function G.pointer(e)
  if e.type == "mousedown" then
    local best, bd = nil, (L.cell * 0.55) ^ 2
    for i = 1, 9 do
      local hl = holes[i]
      local d = (e.x - hl.x) ^ 2 + (e.y - (hl.y - L.r * 0.5)) ^ 2
      if d < bd then best, bd = i, d end
    end
    if best then
      cur = best
      whack(best)
    else
      hammer.x, hammer.y, hammer.swing, hammer.hole = e.x, e.y, 1, 0
      K.sfx("drop", 0.4)
    end
  end
end

local function stepHoles(dt)
  for i = 1, 9 do
    local hl = holes[i]
    if hl.state ~= "idle" then
      hl.t = hl.t + dt
      if hl.state == "up" and hl.t > hl.dur + 0.18 then
        hl.state, hl.t = "down", 0
        if K.state == "play" and hl.kind ~= "bomb" and hl.kind ~= "clock" then
          K.comboBreak()
          misses = misses + 1
        end
      elseif hl.state == "hit" and hl.t > 0.45 then
        hl.state, hl.t = "down", 0.1
      elseif hl.state == "down" and hl.t > 0.18 then
        hl.state = "idle"
      end
    end
  end
  hammer.swing = max(0, hammer.swing - dt * 5)
end

function G.update(dt)
  elapsed = elapsed + dt
  timeLeft = timeLeft - dt
  local secs = math.ceil(timeLeft)
  if timeLeft <= 10 and secs ~= lastTick and secs > 0 then
    lastTick = secs
    K.chord({1200, 1800}, 0.03, 0.06, "square")
  end
  if timeLeft <= 0 then
    timeLeft = 0
    local acc = (hits + misses) > 0 and floor(hits / (hits + misses) * 100 + 0.5) or 0
    K.over({title = TR("times_up"), win = true, stats = {{TR("hits"), tostring(hits)}, {TR("accuracy"), acc .. "%"},
      {TR("golden"), tostring(golden)}, {TR("bombs"), tostring(bombs)}}})
    return
  end
  spawnT = spawnT - dt
  if spawnT <= 0 then
    spawn()
    spawnT = (0.75 - difficulty() * 0.4) * (0.6 + random() * 0.8)
  end
  stepHoles(dt)
end

function G.idle(dt)
  if K.state ~= "title" then
    if K.state == "over" then stepHoles(dt) end
    return
  end
  elapsed = 20
  spawnT = spawnT - dt
  if spawnT <= 0 then spawn(); spawnT = 0.5 + random() * 0.5 end
  stepHoles(dt)
  for i = 1, 9 do
    local hl = holes[i]
    if hl.state == "up" and hl.kind ~= "bomb" and hl.t > 0.35 and random() < 0.04 then whack(i) end
  end
end

-- ------------------------------------------------------------------ drawing
local function moleHeight(hl)
  if hl.state == "up" then return K.easeOutBack(hl.t / 0.18)
  elseif hl.state == "hit" then return 1 - K.easeIn(max(0, hl.t - 0.25) / 0.2) * 0.3
  elseif hl.state == "down" then return 0.95 * (1 - K.easeIn(hl.t / 0.18)) end
  return 0
end

local function drawMole(hl, t)
  local r = L.r
  local up = moleHeight(hl)
  if up <= 0.01 then return end
  local X, Y = hl.x, hl.y
  local bodyH = r * 1.5
  local top = Y - bodyH * up
  gfx.clip(X - r * 1.4, Y - r * 3, r * 2.8, r * 3)
  if hl.kind == "bomb" then
    local cy = top + r * 0.75
    K.color("#2C2C2E")
    gfx.circle(X, cy, r * 0.72)
    K.color("#FFFFFF", 0.2)
    gfx.circle(X - r * 0.25, cy - r * 0.25, r * 0.2)
    K.color("#8E8E93")
    gfx.rect(X - r * 0.15, cy - r * 0.9, r * 0.3, r * 0.25, 3)
    K.color(floor(t * 12) % 2 == 0 and "#FFD60A" or "#FF453A")
    gfx.circle(X + r * 0.15, cy - r * 1.0, r * 0.12)
    K.color("#FFFFFF")
    gfx.text("!", X - r, cy - r * 0.35, floor(r * 0.7), "bold", "center", r * 2)
  elseif hl.kind == "clock" then
    local cy = top + r * 0.75
    K.color("#64D2FF")
    gfx.circle(X, cy, r * 0.72)
    K.color("#FFFFFF")
    gfx.circle(X, cy, r * 0.58)
    K.color("#0A84FF")
    gfx.line(X, cy, X, cy - r * 0.4, 3)
    gfx.line(X, cy, X + cos(t * 4) * r * 0.35, cy + sin(t * 4) * r * 0.35, 3)
  else
    local fur = hl.kind == "gold" and "#FFC93C" or "#8B5A2B"
    local belly = hl.kind == "gold" and "#FFE9A6" or "#C89B6D"
    K.color(fur)
    gfx.rect(X - r * 0.75, top, r * 1.5, bodyH + 4, r * 0.7)
    K.color(belly)
    gfx.rect(X - r * 0.45, top + r * 0.75, r * 0.9, bodyH, r * 0.45)
    local hit = hl.state == "hit"
    -- eyes
    for k = -1, 1, 2 do
      local ex, ey = X + k * r * 0.28, top + r * 0.45
      if hit then
        K.color("#1C1C1E")
        gfx.line(ex - 5, ey - 5, ex + 5, ey + 5, 3)
        gfx.line(ex - 5, ey + 5, ex + 5, ey - 5, 3)
      else
        K.color("#FFFFFF")
        gfx.circle(ex, ey, r * 0.15)
        K.color("#1C1C1E")
        gfx.circle(ex, ey + 1, r * 0.08)
      end
    end
    K.color("#FF7AA2")
    gfx.circle(X, top + r * 0.7, r * 0.13)
    K.color("#FFFFFF")
    gfx.rect(X - r * 0.12, top + r * 0.82, r * 0.1, r * 0.16, 2)
    gfx.rect(X + r * 0.02, top + r * 0.82, r * 0.1, r * 0.16, 2)
    if hl.kind == "helmet" and hl.hp > 1 then
      K.color("#B0B0B8")
      gfx.pie(X, top + r * 0.32, r * 0.78, pi, 2 * pi)
      K.color("#E5E5EA")
      gfx.rect(X - r * 0.85, top + r * 0.26, r * 1.7, r * 0.12, 3)
    end
    if hl.kind == "gold" then
      K.color("#FFFFFF", 0.6 + 0.4 * sin(t * 10))
      gfx.icon("auto_awesome", X + r * 0.6, top + r * 0.1, r * 0.5, "#FFFFFF")
    end
  end
  gfx.unclip()
  -- dizzy stars after a hit
  if hl.state == "hit" and hl.kind ~= "bomb" then
    for k = 0, 2 do
      local a = t * 6 + k * 2.09
      gfx.icon("star", X + cos(a) * r * 0.7, top - r * 0.1 + sin(a) * r * 0.2, r * 0.32, "#FFD60A")
    end
  end
end

local function drawHammer(x, y, swing, s)
  -- rotate around the grip end; swing 1 = just hit (flat), 0 = raised
  local a = -0.2 - (1 - swing) * 0.7
  local c, sn = cos(a), sin(a)
  local gx, gy = x + 70 * s, y + 40 * s
  local function rp(lx, ly) return gx + lx * c - ly * sn, gy + lx * sn + ly * c end
  HAM[1], HAM[2] = rp(-70 * s, -5 * s)
  HAM[3], HAM[4] = rp(10 * s, -5 * s)
  HAM[5], HAM[6] = rp(10 * s, 5 * s)
  HAM[7], HAM[8] = rp(-70 * s, 5 * s)
  K.color("#C68642")
  gfx.poly(HAM)
  HEAD[1], HEAD[2] = rp(-92 * s, -22 * s)
  HEAD[3], HEAD[4] = rp(-58 * s, -22 * s)
  HEAD[5], HEAD[6] = rp(-58 * s, 22 * s)
  HEAD[7], HEAD[8] = rp(-92 * s, 22 * s)
  K.color("#FF453A")
  gfx.poly(HEAD)
end

function G.draw(w, h)
  local t = K.now
  gfx.gradient(0, 0, w, h, "#7BC96F", "#3E8E41")
  local sx, sy = K.shakeXY()
  gfx.push(sx, sy)
  -- grass tufts
  K.color("#2F7A34", 0.5)
  for i = 0, 24 do
    local gx = (i * 97) % w
    local gy = 70 + (i * 61) % max(1, h - 80)
    gfx.rect(gx, gy, 3, 10, 1)
    gfx.rect(gx + 5, gy - 3, 3, 13, 1)
  end
  for i = 1, 9 do
    local hl = holes[i]
    local r = L.r
    -- hole
    K.color("#2B1B10")
    gfx.rect(hl.x - r * 1.1, hl.y - r * 0.35, r * 2.2, r * 0.7, r * 0.35)
    K.color("#140C06")
    gfx.rect(hl.x - r * 0.95, hl.y - r * 0.28, r * 1.9, r * 0.5, r * 0.25)
    drawMole(hl, t)
    -- front lip of the hole hides the mole bottom
    K.color("#6B4423")
    gfx.rect(hl.x - r * 1.15, hl.y - 2, r * 2.3, r * 0.3, r * 0.15)
    -- selection ring for the controller cursor
    if K.state == "play" and i == cur and K.lastInput ~= "touch" then
      K.color("#FFFFFF", 0.6 + 0.3 * sin(t * 6))
      gfx.rectLine(hl.x - r * 1.3, hl.y - r * 1.9, r * 2.6, r * 2.3, 14, 3)
    end
  end
  if hammer.swing > 0 then drawHammer(hammer.x, hammer.y, hammer.swing, L.cell / 220) end
  K.drawParticles(1, 0, 0)
  K.drawPopups(1, 0, 0, 20)
  gfx.pop()
  -- HUD: score, timer bar, best
  K.scorePill(12, 10)
  local bw = min(360, w - 360)
  if bw > 80 then
    local bx = (w - bw) / 2
    gfx.color(0, 0, 0, 110)
    gfx.rect(bx, 16, bw, 22, 11)
    local f = K.clamp(timeLeft / ROUND, 0, 1)
    if timeLeft <= 10 then K.color("#FF453A", 0.75 + 0.25 * sin(t * 10)) else K.mix("#FF9F0A", "#32D74B", f) end
    gfx.rect(bx + 3, 19, (bw - 6) * f, 16, 8)
    K.color("#FFFFFF")
    gfx.text(tostring(math.ceil(timeLeft)), bx, 15, 18, "bold", "center", bw)
  end
  K.bestPill(w - 60, 10)
  if K.comboN >= 2 and K.state == "play" then
    K.pill(w / 2, 46, "bolt", "x" .. (1 + floor(K.comboN / 5)) .. "  ·  " .. K.comboN, "#FFD60A", "center")
  end
end

return K.run(G)
