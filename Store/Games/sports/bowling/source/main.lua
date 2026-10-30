-- Bowling: ten-pin bowling seen from above, built on the nexvyn.game engine (romfs:/System/Lua/nexvyn/game).
-- Ten frames with real scoring (strikes, spares, the 10th-frame bonus balls), aim/position/spin/power, ten pins with
-- ball-pin and pin-pin collisions, a "pin cam" close-up and a saved best game. All art is drawn with shapes.

local game = require("nexvyn.game")
local fx = require("fx")

local G, I, U, A = game.gfx, game.input, game.ui, game.audio
local floor, sqrt, min, max, abs = math.floor, math.sqrt, math.min, math.max, math.abs
local cos, sin, atan, pi, random = math.cos, math.sin, math.atan, math.pi, math.random

local save = game.save.open("bowling")

-- ---------------------------------------------------------------- lane geometry (world units)
-- x runs down the lane (0 = foul line), y across it (0..100 = lane, beyond that the gutters)
local LANE_W, GUT = 100, 14
local HEAD_X, ROW_DX, PIN_DY = 470, 25.1, 29
local PIT_X = 572
local PIN_R, BALL_R = 6, 10.5
local MB, MP = 7, 1.6                       -- ball and pin mass
local HOOK, HOOK_START = 95, 160            -- sideways acceleration per unit of spin, where the hook starts
local BALL_X0 = -22                         -- the ball waits on the approach
local VIEW_X0, VIEW_X1 = -44, 600           -- what the lane view shows
local AIM_MAX = 0.1                         -- radians
local LYING = 2.5                             -- extra reach of a fallen pin

-- ---------------------------------------------------------------- input
I.bind("throw", {pad = {"a"}, key = {"space", "enter"}})
I.bind("cancel", {pad = {"b"}, key = {"backspace", "c"}})
I.bind("spinL", {pad = {"l", "zl"}, key = {"q"}})
I.bind("spinR", {pad = {"r", "zr"}, key = {"e"}})
I.touchControls{stick = false, pause = true}

-- ---------------------------------------------------------------- sounds
A.define("clack", {wave = "square", volume = 0.09, notes = {{1100, 0.025}, {700, 0.04}}})
A.define("crash", {wave = "noise", volume = 0.22, notes = {{300, 0.08}, {150, 0.16}}})
A.define("release", {wave = "triangle", volume = 0.25, notes = {{110, 0.05}, {82, 0.08}}})
A.define("gutter", {wave = "triangle", volume = 0.2, notes = "E4:0.12 C4:0.12 A3:0.3"})
A.define("tick", {wave = "sine", volume = 0.05, notes = {{520, 0.02}}})

local function strikeFanfare()
  fx.chord("C5 E5 G5", 0.14, 0.08, "square")
  game.tween.after(0.14, function() fx.chord("E5 G5 C6", 0.14, 0.08, "square") end)
  game.tween.after(0.28, function() fx.chord("G5 C6 E6", 0.4, 0.08, "triangle") end)
end
local function spareChime() fx.chord("G5 B5 D6", 0.35, 0.08, "triangle") end

-- ---------------------------------------------------------------- the lane simulation
local Lane = {}
Lane.__index = Lane

function Lane.new()
  local l = setmetatable({pins = {}, ev = {imp = 0, x = 0, y = 0, newDown = 0, gutter = false}}, Lane)
  local n = 0
  for k = 0, 3 do
    for j = 0, k do
      n = n + 1
      l.pins[n] = {num = n, sx = HEAD_X + k * ROW_DX, sy = LANE_W / 2 + (j - k / 2) * PIN_DY, x = 0, y = 0,
                   vx = 0, vy = 0, down = false, gone = false, pit = false, rot = 0, spin = 0}
    end
  end
  l.ball = {x = BALL_X0, y = LANE_W / 2, vx = 0, vy = 0, spin = 0, roll = 0, rolling = false, gutter = false,
            pit = false}
  l:rack()
  return l
end

-- a full set of ten pins
function Lane:rack()
  for _, p in ipairs(self.pins) do
    p.x, p.y, p.vx, p.vy, p.down, p.gone, p.pit, p.rot, p.spin = p.sx, p.sy, 0, 0, false, false, false, 0, 0
  end
end

-- clear the fallen pins, put the standing ones back on their spots
function Lane:sweep()
  for _, p in ipairs(self.pins) do
    if p.down then p.gone = true
    elseif not p.gone then p.x, p.y, p.vx, p.vy = p.sx, p.sy, 0, 0 end
  end
end

function Lane:placeBall(y)
  local b = self.ball
  b.x, b.y, b.vx, b.vy, b.rolling, b.gutter, b.pit = BALL_X0, y, 0, 0, false, false, false
end

-- power 0..1, angle in radians (negative = towards the top of the screen), spin -1..1
function Lane:throw(y, angle, spin, power)
  local b = self.ball
  local sp = 300 + 340 * power
  b.x, b.y, b.vx, b.vy, b.spin = BALL_X0, y, cos(angle) * sp, sin(angle) * sp, spin
  b.rolling, b.gutter, b.pit = true, false, false
end

function Lane:standing()
  local n = 0
  for _, p in ipairs(self.pins) do if not p.gone and not p.down then n = n + 1 end end
  return n
end

function Lane:knocked()
  local n = 0
  for _, p in ipairs(self.pins) do if not p.gone and p.down then n = n + 1 end end
  return n
end

-- is anything still moving?
function Lane:busy()
  if self.ball.rolling then return true end
  for _, p in ipairs(self.pins) do
    if not p.gone and not p.pit and (p.vx ~= 0 or p.vy ~= 0) then return true end
  end
  return false
end

-- elastic push between two circles with masses; returns the closing speed (0 = no contact)
local function bump(a, b, ma, mb, rad, e)
  local dx, dy = b.x - a.x, b.y - a.y
  local d2 = dx * dx + dy * dy
  if d2 >= rad * rad or d2 < 1e-9 then return 0 end
  local d = sqrt(d2)
  local nx, ny = dx / d, dy / d
  local ia, ib = 1 / ma, 1 / mb
  local tot = ia + ib
  local pen = rad - d
  a.x, a.y = a.x - nx * pen * ia / tot, a.y - ny * pen * ia / tot
  b.x, b.y = b.x + nx * pen * ib / tot, b.y + ny * pen * ib / tot
  local rv = (b.vx - a.vx) * nx + (b.vy - a.vy) * ny
  if rv >= 0 then return 0 end
  local j = -(1 + e) * rv / tot
  a.vx, a.vy = a.vx - j * nx * ia, a.vy - j * ny * ia
  b.vx, b.vy = b.vx + j * nx * ib, b.vy + j * ny * ib
  return -rv
end

function Lane:knock(p, imp)
  if p.down then return end
  p.down = true
  p.rot = atan(p.vy, p.vx)
  p.spin = (random() - 0.5) * 16
  self.ev.newDown = self.ev.newDown + 1
  if imp > self.ev.imp then self.ev.imp, self.ev.x, self.ev.y = imp, p.x, p.y end
end

-- one fixed step (10 sub-steps so nothing tunnels)
function Lane:step(dt)
  local b, pins, ev = self.ball, self.pins, self.ev
  ev.imp, ev.newDown, ev.gutter = 0, 0, false
  local n = 10
  local h = dt / n
  for _ = 1, n do
    if b.rolling then
      if not b.gutter and b.x > HOOK_START and b.x < HEAD_X + 40 then b.vy = b.vy + b.spin * HOOK * h end
      b.x, b.y = b.x + b.vx * h, b.y + b.vy * h
      b.roll = b.roll + sqrt(b.vx * b.vx + b.vy * b.vy) * h / BALL_R
      if not b.gutter and b.x < HEAD_X - 14 and (b.y < 1 or b.y > LANE_W - 1) then
        b.gutter, ev.gutter = true, true
        b.y, b.vy = b.y < LANE_W / 2 and -GUT / 2 or LANE_W + GUT / 2, 0
      end
      -- walls beside the pin deck
      if b.y < -GUT + BALL_R * 0.5 then b.y, b.vy = -GUT + BALL_R * 0.5, abs(b.vy) * 0.3 end
      if b.y > LANE_W + GUT - BALL_R * 0.5 then b.y, b.vy = LANE_W + GUT - BALL_R * 0.5, -abs(b.vy) * 0.3 end
      if b.x > PIT_X + BALL_R then b.pit, b.rolling = true, false end
    end
    for i = 1, 10 do
      local p = pins[i]
      if not p.gone and not p.pit and (p.vx ~= 0 or p.vy ~= 0) then
        p.x, p.y = p.x + p.vx * h, p.y + p.vy * h
        if p.down then p.rot = p.rot + p.spin * h end
        local sp = sqrt(p.vx * p.vx + p.vy * p.vy)
        local dec = (p.down and (140 + 1.3 * sp) or (420 + 6 * sp)) * h
        if sp <= dec then p.vx, p.vy = 0, 0 else p.vx, p.vy = p.vx * (1 - dec / sp), p.vy * (1 - dec / sp) end
        -- kickback walls send pins back into the deck
        if p.y < -GUT + PIN_R then p.y, p.vy = -GUT + PIN_R, abs(p.vy) * 0.55; self:knock(p, sp) end
        if p.y > LANE_W + GUT - PIN_R then p.y, p.vy = LANE_W + GUT - PIN_R, -abs(p.vy) * 0.55; self:knock(p, sp) end
        if p.y < -1 or p.y > LANE_W + 1 then self:knock(p, sp) end
        if p.x > PIT_X then p.pit = true; p.vx, p.vy = 0, 0; self:knock(p, sp) end
        if p.x < HEAD_X - 90 then p.vx = abs(p.vx) end
        if not p.down then
          local dx, dy = p.x - p.sx, p.y - p.sy
          if dx * dx + dy * dy > 16 then self:knock(p, sp) end
        end
      end
    end
    if b.rolling and not b.gutter then
      for i = 1, 10 do
        local p = pins[i]
        if not p.gone and not p.pit then
          local imp = bump(b, p, MB, MP, BALL_R + PIN_R, 0.55)
          if imp > 12 then self:knock(p, imp) end
        end
      end
    end
    for i = 1, 9 do
      local p = pins[i]
      if not p.gone and not p.pit then
        for j = i + 1, 10 do
          local q = pins[j]
          if not q.gone and not q.pit then
            -- a toppling pin sweeps a wider area than a standing one
            local rad = PIN_R * 2 + (p.down and LYING or 0) + (q.down and LYING or 0)
            local imp = bump(p, q, MP, MP, rad, 0.6)
            if imp > 15 then self:knock(p, imp); self:knock(q, imp) end
          end
        end
      end
    end
  end
  if b.rolling then
    local k = 1 - 0.05 * dt
    b.vx, b.vy = b.vx * k, b.vy * k
    if b.vx * b.vx + b.vy * b.vy < 64 then b.rolling, b.vx, b.vy = false, 0, 0 end
  end
end

-- ---------------------------------------------------------------- lane drawing (world units)
local BOARD = {}
local function drawLane(lane, t)
  -- approach, lane bed, gutters, deck, pit
  G.rect(VIEW_X0, -GUT - 6, -VIEW_X0, LANE_W + GUT * 2 + 12, 0, "#C8955A")
  G.gradient(0, 0, PIT_X, LANE_W, "#E8C08A", "#D9A86C")
  G.color(120, 70, 30, 40)
  for i = 1, 12 do
    local y = i * LANE_W / 13
    G.line(0, y, PIT_X, y, 0.6)
  end
  G.rect(HEAD_X - 22, 0, PIT_X - HEAD_X + 22, LANE_W, 0, "#FFFFFF18")
  -- foul line, approach dots and target arrows
  G.rect(-1.5, -GUT, 3, LANE_W + GUT * 2, 0, "#C0392B")
  for i = -2, 2 do G.circle(-14, LANE_W / 2 + i * 15, 1.2, "#6B4A2A") end
  for i = -3, 3 do
    local ax, ay = 110 + abs(i) * 9, LANE_W / 2 + i * 12.5
    BOARD[1], BOARD[2], BOARD[3], BOARD[4], BOARD[5], BOARD[6] = ax + 7, ay, ax - 3, ay - 3, ax - 3, ay + 3
    G.poly(BOARD, "#7A4A20")
  end
  G.rect(0, -GUT, PIT_X, GUT, 7, "#4A4E57")
  G.rect(0, LANE_W, PIT_X, GUT, 7, "#4A4E57")
  G.rect(0, -GUT + 4, PIT_X, GUT - 8, 4, "#3A3E46")
  G.rect(0, LANE_W + 4, PIT_X, GUT - 8, 4, "#3A3E46")
  G.rect(HEAD_X - 22, -GUT - 5, PIT_X - HEAD_X + 22, 5, 0, "#2B2E35")
  G.rect(HEAD_X - 22, LANE_W + GUT, PIT_X - HEAD_X + 22, 5, 0, "#2B2E35")
  G.rect(PIT_X, -GUT - 5, VIEW_X1 - PIT_X, LANE_W + GUT * 2 + 10, 0, "#14161B")
  G.color(255, 255, 255, 30)
  G.line(PIT_X + 4, -GUT, PIT_X + 4, LANE_W + GUT, 1)
  -- pin spots
  for _, p in ipairs(lane.pins) do G.circle(p.sx, p.sy, 2, "#B8875088") end
  -- pins: fallen ones lie on their side, standing ones are seen from above
  for _, p in ipairs(lane.pins) do
    if not p.gone and not p.pit and p.down then
      local c, s = cos(p.rot) * 8, sin(p.rot) * 8
      G.color(0, 0, 0, 60)
      G.line(p.x - c + 1.5, p.y - s + 2, p.x + c + 1.5, p.y + s + 2, 9)
      G.color("#F2F2F2")
      G.line(p.x - c, p.y - s, p.x + c, p.y + s, 9)
      G.color("#D63031")
      G.line(p.x + c * 0.25, p.y + s * 0.25, p.x + c * 0.45, p.y + s * 0.45, 9)
    end
  end
  for _, p in ipairs(lane.pins) do
    if not p.gone and not p.pit and not p.down then
      G.circle(p.x + 1.5, p.y + 2, PIN_R, "#00000050")
      G.circle(p.x, p.y, PIN_R, "#F7F7F7")
      G.color("#D63031")
      G.circleLine(p.x, p.y, PIN_R * 0.62, 1.4)
      G.circle(p.x - 1.2, p.y - 1.2, 1.6, "#FFFFFF")
    end
  end
  -- ball
  local b = lane.ball
  if not b.pit then
    G.circle(b.x + 2, b.y + 3, BALL_R, "#00000055")
    G.circle(b.x, b.y, BALL_R, "#3B2C9E")
    G.circle(b.x - 3, b.y - 3, BALL_R * 0.55, "#5B4CC8")
    for k = 0, 2 do
      local a = b.roll + k * 0.55
      G.circle(b.x + cos(a) * 4.5, b.y + sin(a) * 4.5, 1.6, "#120C33")
    end
  end
end

-- ---------------------------------------------------------------- scoring
-- frames[f] = list of pins per ball; returns the running totals (nil where not decided yet) and the total so far
local function scoreGame(frames, out)
  local rolls, start = {}, {}
  for f = 1, 10 do
    start[f] = #rolls + 1
    for _, v in ipairs(frames[f] or {}) do rolls[#rolls + 1] = v end
  end
  local cum, ok = 0, true
  for f = 1, 10 do
    local r, i = frames[f] or {}, start[f]
    local val
    if f < 10 then
      if r[1] == 10 then
        if rolls[i + 1] and rolls[i + 2] then val = 10 + rolls[i + 1] + rolls[i + 2] end
      elseif r[1] and r[2] then
        if r[1] + r[2] == 10 then
          if rolls[i + 2] then val = 10 + rolls[i + 2] end
        else
          val = r[1] + r[2]
        end
      end
    elseif r[1] and r[2] then
      if r[1] == 10 or r[1] + r[2] == 10 then
        if r[3] then val = r[1] + r[2] + r[3] end
      else
        val = r[1] + r[2]
      end
    end
    if ok and val then cum = cum + val; out[f] = cum else ok = false; out[f] = nil end
  end
  return cum
end

local function num(v) if v == 10 then return "X" elseif v == 0 then return "-" end return tostring(v) end

-- marks shown in the small boxes of a frame
local function frameMarks(f, r, m)
  m[1], m[2], m[3] = "", "", ""
  if f < 10 then
    if r[1] == 10 then
      m[2] = "X"
    else
      if r[1] then m[1] = r[1] == 0 and "-" or tostring(r[1]) end
      if r[2] then m[2] = (r[1] + r[2] == 10) and "/" or (r[2] == 0 and "-" or tostring(r[2])) end
    end
  else
    if r[1] then m[1] = num(r[1]) end
    if r[2] then
      if r[1] == 10 then m[2] = num(r[2])
      elseif r[1] + r[2] == 10 then m[2] = "/"
      else m[2] = r[2] == 0 and "-" or tostring(r[2]) end
    end
    if r[3] then
      if r[1] == 10 and r[2] ~= 10 then
        m[3] = (r[2] + r[3] == 10) and "/" or (r[3] == 0 and "-" or tostring(r[3]))
      else
        m[3] = num(r[3])
      end
    end
  end
end

-- scoreboard across the top: 10 frames and the total
local MARKS = {"", "", ""}
local function drawBoard(x, y, w, frames, totals, cur, total)
  local fw = w / 11.6
  local h = 40
  U.panel(x - 3, y - 3, w + 6, h + 6, 6, "#0B1020D0")
  for f = 1, 10 do
    local bx = x + (f - 1) * fw
    local bw = f == 10 and fw * 1.4 or fw
    local active = f == cur
    G.rect(bx + 0.5, y, bw - 1, h, 3, active and "#2D3E7A" or "#1A2238")
    U.text(tostring(f), bx, y + 1, 7, active and "#FFE27A" or "#FFFFFF80", "center", bw, "semibold", false)
    local r = frames[f] or {}
    frameMarks(f, r, MARKS)
    local boxes = f == 10 and 3 or 2
    local sw = min(13, bw / boxes - 1)
    for k = 1, boxes do
      local sx = bx + bw - (boxes - k + 1) * sw - 1
      G.rect(sx, y + 10, sw, 12, 2, "#FFFFFF14")
      local mk = MARKS[k]
      if mk ~= "" then
        local col = mk == "X" and "#FF6B6B" or (mk == "/" and "#7CC4FF" or "#FFFFFF")
        U.text(mk, sx, y + 11, 9, col, "center", sw, "bold", false)
      end
    end
    if totals[f] then U.text(tostring(totals[f]), bx, y + 25, 11, "#FFFFFF", "center", bw, "bold", false) end
  end
  local tx = x + fw * 10.4
  G.rect(tx + 0.5, y, fw * 1.2 - 1, h, 3, "#3A2D12")
  U.text(TR("total"), tx, y + 1, 7, "#FFE27A", "center", fw * 1.2, "semibold", false)
  U.text(tostring(total), tx, y + 15, 15, "#FFE27A", "center", fw * 1.2, "bold", false)
end

-- standing pins as a little triangle (pin 1 nearest the bowler)
local function drawRack(lane, cx, y, s)
  for _, p in ipairs(lane.pins) do
    local k = floor((p.sx - HEAD_X) / ROW_DX + 0.5)
    local px = cx + (p.sy - LANE_W / 2) / PIN_DY * s
    local py = y - k * s * 0.87
    local up = not p.gone and not p.down
    G.circle(px, py, s * 0.36, up and "#FFFFFF" or "#FFFFFF26")
    if up then G.circle(px, py, s * 0.16, "#D63031") end
  end
end

-- ---------------------------------------------------------------- layout
-- main lane view and the pin cam, recomputed from the virtual screen size
local L = {ox = 0, oy = 0, s = 1, camX = 0, camY = 0, camS = 1, camW = 0, camH = 0, bottom = 0}
local function layout(boardH)
  local W, H = game.width, game.height
  local top = boardH + 10
  local s = min((W - 16) / (VIEW_X1 - VIEW_X0), (H - top - 110) / (LANE_W + GUT * 2 + 12))
  L.s = s
  L.ox = (W - (VIEW_X1 - VIEW_X0) * s) / 2 - VIEW_X0 * s
  L.oy = top + (GUT + 6) * s
  L.bottom = top + (LANE_W + GUT * 2 + 12) * s
  local avail = H - L.bottom - 22
  local size = max(60, min(avail, 150))
  L.camW, L.camH = size * 0.82, size
  L.camX, L.camY = W - 8 - L.camW, L.bottom + 6
  L.camS = L.camH / (LANE_W + GUT * 2 + 10)
end

local function toWorld(vx, vy) return (vx - L.ox) / L.s, (vy - L.oy) / L.s end

local function drawPinCam(lane, emitter, t)
  local x, y, w, h = L.camX, L.camY, L.camW, L.camH
  U.panel(x - 3, y - 3, w + 6, h + 6, 6, "#0B1020")
  G.clip(x, y, w, h)
  local cs = L.camS
  G.push(x - (HEAD_X - 28) * cs, y + (GUT + 5) * cs, cs)
  drawLane(lane, t)
  if emitter then emitter:draw() end
  G.pop()
  G.unclip()
  U.text(TR("pin_cam"), x + 4, y + 3, 8, "#FFFFFFA0", nil, nil, "semibold")
end

-- ---------------------------------------------------------------- scenes
local Title, Play, Over = {pausable = false}, {controls = true}, {transparent = true, pausable = false}

-- title: an attract-mode lane bowls by itself behind the menu
function Title:enter()
  self.t, self.demoT = 0, 0
  self.lane = Lane.new()
  self.logo = {y = -40, a = 0}
  self.tweens:to(self.logo, 0.9, {y = 0, a = 1}, "outBack")
  self.menu = U.menu{width = 190, items = {
    {label = function() return TR("play") end, action = function() game.switch(Play) end},
    fx.soundItem(),
    {label = function() return TR("quit") end, action = function() sys.exit() end},
  }}
end
function Title:update(dt)
  self.t = self.t + dt
  self.menu:update()
  self.demoT = self.demoT - dt
  if self.demoT <= 0 then
    self.demoT = 4.5
    self.lane:rack()
    self.lane:throw(LANE_W / 2 + (random() - 0.5) * 30, (random() - 0.5) * 0.04, (random() - 0.5) * 1.6,
                    0.6 + random() * 0.4)
  end
  self.lane:step(dt)
end
function Title:draw()
  G.gradient(0, 0, game.width, game.height, "#1B1F3A", "#0A0C18")
  layout(0)
  G.alpha(0.5)
  G.push(L.ox, game.height * 0.62 - (LANE_W / 2) * L.s, L.s)
  drawLane(self.lane, self.t)
  G.pop()
  G.unalpha()
end
function Title:ui()
  local y = game.height * 0.08 + self.logo.y
  G.alpha(max(0, min(1, self.logo.a)))
  U.text(TR("logo"), 0, y, 32, "#FFFFFF", "center", game.width, "bold", "#3B2C9E")
  G.unalpha()
  local best = save:get("best", nil)
  U.text(best and TR("best_game", best) or TR("no_best"), 0, y + 42, 12, "#FFE27A", "center", game.width)
  self.menu:draw(game.width / 2, y + 64)
  fx.fitLine(TR("controls"), game.height - 16, 9)
end

-- play -----------------------------------------------------------------------------------------------
function Play:enter()
  self.pop = fx.popups(6)
  self.shake = fx.shake()
  self.confetti = fx.confetti(50)
  self.dust = game.emitter{max = 120, life = {0.3, 0.8}, speed = {30, 140}, damping = 3, size = {4, 0},
                           colors = {"#FFFFFF", "#FFE9B0AA", "#FFFFFF00"}}
  self.lane = Lane.new()
  self.totals = {}
  self.btn = {x1 = 0, y1 = 0, x2 = 0, y2 = 0}
  self:newGame()
end

function Play:newGame()
  self.frames = {}
  for f = 1, 10 do self.frames[f] = {} end
  self.frame, self.total = 1, 0
  self.strikes, self.spares, self.gutters, self.firstSum, self.firstN = 0, 0, 0, 0, 0
  for f = 1, 10 do self.totals[f] = nil end
  self.lane:rack()
  self.posY = LANE_W / 2
  self.aim, self.spin = 0, 0
  self.pop:clear()
  self.confetti:clear()
  self:ready()
end
function Play:restart() self.tweens:clear(); self:newGame() end

function Play:ready()
  self.state = "aim"
  self.power, self.charging, self.chargeDir, self.drag = 0, false, 1, nil
  self.lane:placeBall(self.posY)
  self.timer, self.rumble, self.hitCool = 0, 0, 0
end

function Play:ballInFrame() return #self.frames[self.frame] + 1 end

function Play:throw()
  local p = min(1, max(0, self.power))
  self.lane:throw(self.posY, self.aim, self.spin, p)
  self.state, self.timer, self.settle = "roll", 0, 0
  self.power, self.charging, self.drag = 0, false, nil
  A.play("release")
  self.shake:add(1.5, 0.15)
end

-- after the pins settle: record the ball, score, popups, then sweep
function Play:finishBall()
  local lane = self.lane
  local k = lane:knocked()
  local f = self.frame
  local r = self.frames[f]
  local ball = #r + 1
  local before = lane:standing() + k
  r[ball] = k
  self.total = scoreGame(self.frames, self.totals)
  if ball == 1 or (f == 10 and (r[ball - 1] == 10 or (ball == 3 and r[1] + r[2] == 10))) then
    self.firstSum, self.firstN = self.firstSum + k, self.firstN + 1
  end
  -- feedback
  local cx = game.width / 2
  local cy = L.oy + LANE_W * 0.5 * L.s
  if k == before and before == 10 then
    self.strikes = self.strikes + 1
    self.pop:add(TR("strike"), cx, cy, "#FF6B6B", 34, 1.6, 30)
    self.confetti:burst(60, cx, cy + 20, -pi / 2, 2.2)
    self.shake:add(5, 0.4)
    strikeFanfare()
    sys.vibrate(0.7, 160)
  elseif k == before and k > 0 then
    self.spares = self.spares + 1
    self.pop:add(TR("spare"), cx, cy, "#7CC4FF", 30, 1.5, 28)
    self.confetti:burst(24, cx, cy + 20, -pi / 2, 1.6)
    spareChime()
  elseif lane.ball.gutter and k == 0 then
    self.gutters = self.gutters + 1
    self.pop:add(TR("gutter"), cx, cy, "#B0B6C8", 24, 1.4)
    A.play("gutter")
  else
    self.pop:add(TR("pins_n", k), cx, cy, "#FFFFFF", 24, 1.3)
    if k == 0 then A.play("gutter") end
  end
  -- what happens next
  local nextFrame, reset, over = false, false, false
  if f < 10 then
    if (ball == 1 and k == 10) or ball == 2 then nextFrame = true end
  elseif ball == 1 then
    reset = k == 10
  elseif ball == 2 then
    if r[1] == 10 or r[1] + r[2] == 10 then reset = r[2] == 10 or r[1] ~= 10 else over = true end
  else
    over = true
  end
  self.state = "result"
  game.tween.after(1.3, function()
    if self.state ~= "result" then return end
    if over then
      self.state = "over"
      local record = self.total > 0 and save:best("best", self.total)
      save:inc("games", 1)
      game.push(Over, {play = self, record = record})
      return
    end
    if nextFrame then
      self.frame = f + 1
      lane:rack()
      self.pop:add(TR("frame_n", self.frame), game.width / 2, L.oy + LANE_W * 0.5 * L.s, "#FFE27A", 16, 1.0, 14)
    elseif reset then
      lane:rack()
    else
      lane:sweep()
    end
    self:ready()
  end)
end

function Play:updateAim(dt)
  -- position, aim and spin
  local mx = I.axis("left", "right")
  local lx = I.sticks()
  if abs(lx) > 0.2 then mx = lx end
  self.posY = max(BALL_R - 2, min(LANE_W - BALL_R + 2, self.posY + mx * 55 * dt))
  local ay = I.axis("up", "down")
  self.aim = max(-AIM_MAX, min(AIM_MAX, self.aim + ay * 0.1 * dt))
  if I.pressed("spinL") then self.spin = max(-1, self.spin - 0.25); A.play("tick") end
  if I.pressed("spinR") then self.spin = min(1, self.spin + 0.25); A.play("tick") end
  self.lane:placeBall(self.posY)
  -- hold to charge the power meter, release to bowl
  if not self.drag then
    if I.pressed("throw") then self.charging, self.power, self.chargeDir = true, 0, 1 end
    if self.charging then
      if I.pressed("cancel") then
        self.charging, self.power = false, 0
      elseif I.down("throw") then
        self.power = self.power + self.chargeDir * dt * 0.9
        if self.power >= 1 then self.power, self.chargeDir = 1, -1 elseif self.power <= 0 then self.power, self.chargeDir = 0, 1 end
      else
        self.charging = false
        if self.power > 0.02 then self:throw() end
        return
      end
    end
  end
  -- touch / mouse: drag the ball to move it, or drag back from anywhere else and release
  if self.charging then return end
  local p = I.pointer
  if p.pressed then
    local bt = self.btn
    if p.x >= bt.x1 and p.x <= bt.x2 and p.y >= bt.y1 and p.y <= bt.y2 then
      self.drag = nil
    else
      local wx, wy = toWorld(p.x, p.y)
      local b = self.lane.ball
      self.drag = ((wx - b.x) ^ 2 + (wy - b.y) ^ 2 < 26 * 26) and "move" or "aim"
    end
  end
  if self.drag == "move" then
    local _, wy = toWorld(p.x, p.y)
    self.posY = max(BALL_R - 2, min(LANE_W - BALL_R + 2, wy))
    if not p.down then self.drag = nil end
  elseif self.drag == "aim" then
    local dx, dy = p.downX - p.x, p.downY - p.y
    local len = sqrt(dx * dx + dy * dy)
    self.power = min(1, len / 120)
    if len > 6 and dx > 0 then self.aim = max(-AIM_MAX, min(AIM_MAX, atan(dy, dx) * 0.3)) end
    if p.released or not p.down then
      self.drag = nil
      if p.released and self.power > 0.08 and dx > 0 then self:throw() else self.power = 0 end
    end
  end
end

function Play:update(dt)
  local lane = self.lane
  if self.state == "aim" then
    self:updateAim(dt)
  elseif self.state == "roll" then
    self.timer = self.timer + dt
    lane:step(dt)
    local ev = lane.ev
    local b = lane.ball
    -- rumble while the ball rolls, crash when pins fly
    self.rumble = self.rumble - dt
    if b.rolling and self.rumble <= 0 then
      self.rumble = 0.11
      A.tone(52 + b.x * 0.02, 0.14, 0.05, "triangle")
    end
    self.hitCool = self.hitCool - dt
    if ev.imp > 0 then
      self.dust:emit(min(16, 3 + floor(ev.imp / 30)), ev.x, ev.y)
      self.shake:add(min(5, ev.imp / 90), 0.25)
      if self.hitCool <= 0 then
        self.hitCool = 0.05
        A.play("clack", min(1.4, 0.4 + ev.imp / 300))
        if ev.newDown > 1 then A.play("crash", min(1.3, 0.3 + ev.newDown * 0.15)) end
      end
    end
    if ev.gutter then A.tone(70, 0.3, 0.06, "triangle") end
    if lane:busy() and self.timer < 8 then
      self.settle = 0
    else
      self.settle = self.settle + dt
      if self.settle > 0.45 or self.timer >= 8 then self:finishBall() end
    end
  else
    lane:step(dt)
  end
  self.shake:update(dt)
  self.pop:update(dt)
  self.dust:update(dt)
  self.confetti:update(dt)
end

-- dotted preview of the ball's path (same equations as the simulation, coarse steps)
function Play:drawPath()
  local sp = 300 + 340 * max(0.35, self.power)
  local x, y = BALL_X0, self.posY
  local vx, vy = cos(self.aim) * sp, sin(self.aim) * sp
  local dt = 0.04
  for i = 1, 40 do
    if x > HEAD_X - 20 then break end
    if x > HOOK_START then vy = vy + self.spin * HOOK * dt end
    x, y = x + vx * dt, y + vy * dt
    if y < 0 or y > LANE_W then break end
    if i % 2 == 0 then
      gfx.color(255, 255, 255, floor(200 * (1 - x / HEAD_X)))
      G.circle(x, y, 1.8)
    end
  end
end

function Play:draw()
  G.gradient(0, 0, game.width, game.height, "#1B1F3A", "#0A0C18")
  layout(44)
  G.push(L.ox + self.shake.x, L.oy + self.shake.y, L.s)
  drawLane(self.lane, game.time)
  if self.state == "aim" then self:drawPath() end
  self.dust:draw()
  G.pop()
  drawPinCam(self.lane, self.dust, game.time)
end

function Play:ui()
  local W = game.width
  drawBoard(8, 4, W - 16 - (I.touchVisible() and 40 or 0), self.frames, self.totals, self.frame, self.total)
  -- status panel bottom left
  local x, y = 8, L.bottom + 6
  local pw = L.camX - 16
  local ph = L.camH
  U.panel(x - 3, y - 3, pw + 6, ph + 6, 6, "#0B1020C0")
  local ballN = min(3, self:ballInFrame())
  U.text(TR("frame_ball", self.frame, ballN), x + 4, y + 2, 11, "#FFFFFF")
  drawRack(self.lane, x + pw - 26, y + 34, 10)
  -- spin meter
  local ly = y + 20
  U.text(TR("spin"), x + 4, ly, 9, "#FFFFFFB0", nil, nil, "semibold")
  local bw = min(110, pw - 90)
  local bx = x + 44
  G.rect(bx, ly + 4, bw, 4, 2, "#FFFFFF30")
  G.rect(bx + bw / 2 - 0.5, ly + 1, 1, 10, 0, "#FFFFFF60")
  G.circle(bx + bw / 2 + self.spin * bw / 2, ly + 6, 4, self.spin == 0 and "#FFFFFF" or "#FFD166")
  -- touch buttons for spin
  local by = ly + 14
  local bh = 18
  if by + bh < y + ph then
    if U.button(TR("hook_left"), bx, by, bw / 2 - 2, bh) then self.spin = max(-1, self.spin - 0.25); A.play("tick") end
    if U.button(TR("hook_right"), bx + bw / 2 + 2, by, bw / 2 - 2, bh) then self.spin = min(1, self.spin + 0.25); A.play("tick") end
    self.btn.x1, self.btn.y1, self.btn.x2, self.btn.y2 = bx, by, bx + bw, by + bh
  end
  -- power meter
  local py = by + bh + 8
  if py + 8 < y + ph then
    U.text(TR("power"), x + 4, py - 3, 9, "#FFFFFFB0", nil, nil, "semibold")
    local col = self.power > 0.8 and "#FF6B6B" or (self.power > 0.45 and "#FFD166" or "#7CFFB2")
    U.bar(bx, py, bw, 6, self.power, col)
  end
  fx.fitLine(TR("hint"), game.height - 14, 9, "#FFFFFFB0")
  self.pop:draw()
  self.confetti:draw()
end

-- game over -------------------------------------------------------------------------------------------
function Over:enter(p)
  self.p = p
  self.anim = {k = 0, score = 0}
  self.tweens:to(self.anim, 0.5, {k = 1}, "outBack")
  self.tweens:to(self.anim, 1.2, {score = p.play.total}, "outCubic")
  self.confetti = fx.confetti(70)
  self.party = p.record and 2.5 or 0
  self.labels = {TR("stat_strikes"), TR("stat_spares"), TR("stat_gutters"), TR("stat_first")}
  self.values = {0, 0, 0, "-"}
  self.menu = U.menu{width = 180, items = {
    {label = function() return TR("again") end, action = function() game.switch(Play) end},
    {label = function() return TR("main_menu") end, action = function() game.switch(Title) end},
  }}
  if p.record then
    A.play("win")
    game.tween.after(0.35, function() fx.chord("C5 E5 G5 C6", 0.6, 0.08, "triangle") end)
  else
    fx.chord("C4 G4 C5", 0.5, 0.07, "triangle")
  end
end
function Over:update(dt)
  self.menu:update()
  if self.party > 0 then
    local before = self.party
    self.party = self.party - dt
    if floor(before * 4) ~= floor(self.party * 4) then
      self.confetti:burst(20, game.width * (0.15 + random() * 0.7), game.height, -pi / 2, 1.0)
    end
  end
  self.confetti:update(dt)
end
function Over:ui()
  local p, pl = self.p, self.p.play
  local k = max(0, min(1, self.anim.k))
  G.rect(0, 0, game.width, game.height, 0, "#000000A0")
  local w, h = min(game.width - 16, 300), 200
  local x, y = (game.width - w) / 2, (game.height - h) / 2 + (1 - k) * 40
  G.alpha(k)
  U.panel(x, y, w, h, 12, "#141A30F0")
  U.text(TR("game_over"), x, y + 10, 16, "#FFFFFF", "center", w)
  U.text(tostring(floor(self.anim.score + 0.5)), x, y + 30, 34, "#FFE27A", "center", w)
  if p.record then
    local pulse = 1 + sin(game.realTime * 8) * 0.06
    U.text(TR("new_best"), x, y + 72, 13 * pulse, "#7CFFB2", "center", w)
  else
    U.text(TR("best_game", save:get("best", 0)), x, y + 72, 12, "#FFFFFFB0", "center", w, "semibold")
  end
  local avg = pl.firstN > 0 and string.format("%.1f", pl.firstSum / pl.firstN) or "-"
  local sw = w / 4
  local labels, values = self.labels, self.values
  values[1], values[2], values[3], values[4] = pl.strikes, pl.spares, pl.gutters, avg
  for i = 1, 4 do
    local sx = x + (i - 1) * sw
    U.text(tostring(values[i]), sx, y + 92, 14, "#FFFFFF", "center", sw)
    U.text(labels[i], sx, y + 110, 8, "#FFFFFF90", "center", sw, "semibold", false)
  end
  self.menu:draw(game.width / 2, y + 130)
  G.unalpha()
  self.confetti:draw()
end

-- ---------------------------------------------------------------- run
return game.run{
  width = 480, height = 270, scale = "expand",
  scene = Title, title = Title,
  background = "#0A0C18",
  menu = function()
    return {{title = TR("game_menu"), items = {
      {label = TR("pause_menu"), id = 1, shortcut = "Esc"},
      {label = TR("new_game"), id = 2},
      {label = TR("main_menu"), id = 3},
      "-",
      {label = TR("reset_best"), id = 4},
    }}}
  end,
  onmenu = function(id)
    if id == 1 then game.pause()
    elseif id == 2 then game.switch(Play)
    elseif id == 3 then game.switch(Title)
    elseif id == 4 then save:reset(); U.toast(TR("best_reset"))
    end
  end,
}
