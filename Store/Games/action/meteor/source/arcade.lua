-- arcade.lua: shared runtime for the Nexvyn OS arcade pack (bundled with every game, SDK 1.0 only).
-- Title / play / pause / game-over flow with animated cards and transitions, normalized controller + keyboard
-- input with stick repeat, layered synthesized sound effects, pooled particles / confetti / score popups,
-- callouts and combos, screen shake, flashes, sound + vibration settings and saved best scores.
--
-- A game calls K.run(game) and returns the app table. game fields (all optional except reset/draw):
--   icon, accent              title card badge and highlight color
--   load()                    once, before the first layout
--   controls()                list of control lines (TR strings) shown on the title and pause cards
--   layout(w, h)              window size changed (also called once at start)
--   reset()                   new round (also used for the attract screen behind the title card)
--   update(dt)                while playing and not paused
--   idle(dt)                  every frame unless paused (animations, attract mode behind the title card)
--   draw(w, h)                draw the field every frame
--   press(act, e) / release(act)   normalized buttons: up down left right a b x y l r zl zr
--   pointer(e)                mouse / touch events while playing
--   titlePress(act)           buttons on the title card (change options)
--   key(name)                 keyboard keys without a normalized action (digits, letters) while playing
--   options(x, y, w), optionsHeight   extra widgets on the title card
--   bestKey()                 store key for the best score (per mode)
--   stickPress, rep = {left = true}, repDelay, repRate   d-pad style stick and auto repeat
local K = {}

local floor, min, max, abs, sin, cos, sqrt, exp, random, pi = math.floor, math.min, math.max, math.abs, math.sin,
  math.cos, math.sqrt, math.exp, math.random, math.pi

K.state = "title"     -- "title" | "play" | "over"
K.paused = false
K.score, K.best, K.newBest, K.noBest = 0, 0, false, false
K.shown = 0           -- displayed score (counts up smoothly)
K.bump = 0            -- 1 right after the score changed
K.muted, K.rumble = false, true
K.down = {}
K.raw = {}            -- raw held state: K.raw["k_up"], K.raw["p_x"]
K.now = 0
K.w, K.h = 800, 560
K.stateAt, K.pauseAt, K.overAt = 0, 0, 0
K.playTime = 0
K.comboN, K.comboT, K.maxCombo = 0, 0, 0
K.lastInput = "pad"

local G = {}
local bestKeyStr = "best"
local stickDir = nil
local repAt = {}
local shakeAmt, flashT, flashCol = 0, 0, nil
local fadeT = 0
local EMPTY = {}
local QUAD = {0, 0, 0, 0, 0, 0, 0, 0}

-- ------------------------------------------------------------------ math / easing
function K.clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
function K.lerp(a, b, t) return a + (b - a) * t end
function K.rand(a, b) return a + random() * (b - a) end
function K.approach(v, target, step)
  if v < target then return min(target, v + step) end
  return max(target, v - step)
end
-- frame-rate independent exponential smoothing towards target
function K.smooth(v, target, rate, dt) return v + (target - v) * (1 - exp(-rate * dt)) end
function K.easeOut(t)
  t = K.clamp(t, 0, 1)
  local u = 1 - t
  return 1 - u * u * u
end
function K.easeIn(t)
  t = K.clamp(t, 0, 1)
  return t * t * t
end
function K.easeInOut(t)
  t = K.clamp(t, 0, 1)
  if t < 0.5 then return 4 * t * t * t end
  local u = -2 * t + 2
  return 1 - u * u * u / 2
end
function K.easeOutBack(t)
  t = K.clamp(t, 0, 1) - 1
  return 1 + 2.70158 * t * t * t + 1.70158 * t * t
end
function K.fmtTime(s)
  s = floor(s)
  return string.format("%d:%02d", floor(s / 60), s % 60)
end

-- ------------------------------------------------------------------ colors
local cache = {}
function K.rgba(c)
  if type(c) == "table" then return c end
  local t = cache[c]
  if not t then
    t = {tonumber(c:sub(2, 3), 16) or 0, tonumber(c:sub(4, 5), 16) or 0, tonumber(c:sub(6, 7), 16) or 0,
         #c >= 9 and (tonumber(c:sub(8, 9), 16) or 255) or 255}
    cache[c] = t
  end
  return t
end
-- set the current color with an opacity multiplier (no allocation)
function K.color(c, a)
  local t = K.rgba(c)
  gfx.color(t[1], t[2], t[3], floor(t[4] * K.clamp(a or 1, 0, 1) + 0.5))
end
-- blend of two colors, f = 0..1
function K.mix(c1, c2, f, a)
  local p, q = K.rgba(c1), K.rgba(c2)
  f = K.clamp(f, 0, 1)
  gfx.color(floor(p[1] + (q[1] - p[1]) * f), floor(p[2] + (q[2] - p[2]) * f), floor(p[3] + (q[3] - p[3]) * f),
    floor(255 * K.clamp(a or 1, 0, 1)))
end
function K.hsv(h, s, v, a)
  h = (h % 1) * 6
  local i = floor(h)
  local f = h - i
  local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
  local r, g, b
  if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
  gfx.color(floor(r * 255), floor(g * 255), floor(b * 255), floor(255 * K.clamp(a or 1, 0, 1)))
end

-- ------------------------------------------------------------------ sound (layered: notes without a delay sound together)
local SFX = {
  click  = {{880, 0.03, 0.10, "square"}, {1760, 0.03, 0.05, "sine"}},
  move   = {{520, 0.02, 0.06, "square"}, {1040, 0.02, 0.03, "sine"}},
  turn   = {{700, 0.03, 0.08, "triangle"}, {1400, 0.03, 0.04, "sine"}},
  eat    = {{660, 0.05, 0.12, "square"}, {990, 0.08, 0.10, "triangle"}, {1320, 0.08, 0.10, "triangle", 0.05},
            {1980, 0.06, 0.05, "sine", 0.05}},
  coin   = {{988, 0.05, 0.12, "square"}, {1976, 0.08, 0.06, "sine"}, {1319, 0.14, 0.12, "square", 0.05},
            {2637, 0.14, 0.05, "sine", 0.05}},
  hit    = {{220, 0.07, 0.16, "square"}, {110, 0.10, 0.18, "triangle"}, {900, 0.03, 0.08, "noise"}},
  bounce = {{440, 0.05, 0.14, "triangle"}, {880, 0.04, 0.05, "sine"}},
  high   = {{880, 0.05, 0.14, "triangle"}, {1320, 0.05, 0.06, "sine"}},
  shoot  = {{1100, 0.05, 0.08, "saw"}, {2200, 0.03, 0.03, "sine"}, {550, 0.06, 0.07, "saw", 0.03}},
  boom   = {{90, 0.40, 0.40, "noise"}, {55, 0.35, 0.25, "square"}, {110, 0.30, 0.20, "triangle"},
            {40, 0.45, 0.20, "sine", 0.05}},
  small  = {{180, 0.14, 0.26, "noise"}, {120, 0.10, 0.12, "square"}},
  pop    = {{1200, 0.03, 0.14, "sine"}, {1800, 0.03, 0.06, "triangle"}, {600, 0.06, 0.12, "sine", 0.02}},
  jump   = {{400, 0.05, 0.10, "square"}, {800, 0.06, 0.06, "triangle"}, {600, 0.05, 0.10, "square", 0.03},
            {1200, 0.06, 0.05, "triangle", 0.03}},
  drop   = {{160, 0.07, 0.18, "square"}, {80, 0.10, 0.16, "triangle"}, {400, 0.03, 0.06, "noise"}},
  power  = {{523, 0.07, 0.12, "triangle"}, {1047, 0.07, 0.05, "sine"}, {659, 0.07, 0.12, "triangle", 0.06},
            {1319, 0.07, 0.05, "sine", 0.06}, {784, 0.07, 0.12, "triangle", 0.12}, {1568, 0.07, 0.05, "sine", 0.12},
            {1047, 0.18, 0.12, "triangle", 0.18}, {1319, 0.18, 0.08, "triangle", 0.18}, {1568, 0.18, 0.08, "triangle", 0.18}},
  level  = {{392, 0.08, 0.12, "square"}, {196, 0.08, 0.10, "triangle"}, {523, 0.08, 0.12, "square", 0.08},
            {262, 0.08, 0.10, "triangle", 0.08}, {659, 0.08, 0.12, "square", 0.16}, {330, 0.08, 0.10, "triangle", 0.16},
            {784, 0.28, 0.12, "square", 0.24}, {523, 0.28, 0.10, "triangle", 0.24}, {659, 0.28, 0.08, "triangle", 0.24}},
  lose   = {{392, 0.16, 0.14, "triangle"}, {196, 0.16, 0.12, "square"}, {330, 0.16, 0.14, "triangle", 0.16},
            {165, 0.16, 0.12, "square", 0.16}, {262, 0.45, 0.14, "triangle", 0.32}, {311, 0.45, 0.10, "triangle", 0.32},
            {131, 0.45, 0.12, "square", 0.32}},
  best   = {{523, 0.10, 0.12, "triangle"}, {262, 0.10, 0.10, "square"}, {659, 0.10, 0.12, "triangle", 0.10},
            {784, 0.10, 0.12, "triangle", 0.20}, {1047, 0.55, 0.12, "triangle", 0.30}, {784, 0.55, 0.10, "triangle", 0.30},
            {659, 0.55, 0.10, "triangle", 0.30}, {523, 0.55, 0.10, "square", 0.30}, {2093, 0.30, 0.04, "sine", 0.45}},
  win    = {{523, 0.10, 0.12, "triangle"}, {659, 0.10, 0.12, "triangle", 0.10}, {784, 0.10, 0.12, "triangle", 0.20},
            {1047, 0.45, 0.12, "triangle", 0.30}, {659, 0.45, 0.10, "triangle", 0.30}, {392, 0.45, 0.10, "square", 0.30}},
  start  = {{440, 0.07, 0.10, "triangle"}, {659, 0.07, 0.08, "triangle"}, {880, 0.14, 0.10, "triangle", 0.07},
            {1319, 0.14, 0.07, "triangle", 0.07}, {1760, 0.10, 0.04, "sine", 0.07}},
  tick   = {{1500, 0.015, 0.05, "square"}},
}
function K.addSfx(name, notes) SFX[name] = notes end
function K.tone(f, d, v, w) if not K.muted then audio.tone(f, d, v, w) end end
-- several tones at once: K.chord({262, 330, 392}, 0.3, 0.1, "triangle")
function K.chord(freqs, d, v, w)
  if K.muted then return end
  for i = 1, #freqs do audio.tone(freqs[i], d, v, w) end
end
function K.sfx(name, vol)
  if K.muted then return end
  local s = SFX[name]
  if not s then return end
  local v = vol or 1
  for i = 1, #s do
    local n = s[i]
    if n[5] then
      timer.after(n[5], function() if not K.muted then audio.tone(n[1], n[2], n[3] * v, n[4]) end end)
    else
      audio.tone(n[1], n[2], n[3] * v, n[4])
    end
  end
end
function K.vibrate(s, ms) if K.rumble then sys.vibrate(s, ms) end end
function K.setMuted(m)
  K.muted = m
  store.set("muted", m)
end

-- ------------------------------------------------------------------ particles (world space, pooled)
local PMAX = 480
local P, PN = {}, 0
for i = 1, PMAX do P[i] = {x = 0, y = 0, vx = 0, vy = 0, life = 0, max = 1, r = 255, g = 255, b = 255, size = 3, grav = 0} end
function K.burst(x, y, n, c, speed, life, size, grav, angle, spread)
  local t = K.rgba(c)
  for _ = 1, n do
    if PN >= PMAX then return end
    PN = PN + 1
    local p = P[PN]
    local a = angle and (angle + (random() - 0.5) * (spread or 1)) or random() * 2 * pi
    local s = (speed or 120) * (0.25 + random() * 0.75)
    p.x, p.y, p.vx, p.vy = x, y, cos(a) * s, sin(a) * s
    p.life = (life or 0.6) * (0.5 + random() * 0.5)
    p.max = p.life
    p.r, p.g, p.b = t[1], t[2], t[3]
    p.size = (size or 3) * (0.6 + random() * 0.6)
    p.grav = grav or 0
  end
end
local function updateParticles(dt)
  local i = 1
  local drag = 1 - min(1, dt * 1.5)
  while i <= PN do
    local p = P[i]
    p.life = p.life - dt
    if p.life <= 0 then
      P[i], P[PN] = P[PN], p
      PN = PN - 1
    else
      p.vx, p.vy = p.vx * drag, (p.vy + p.grav * dt) * drag
      p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
      i = i + 1
    end
  end
end
-- draw particles mapped through scale s and offset ox, oy
function K.drawParticles(s, ox, oy)
  s, ox, oy = s or 1, ox or 0, oy or 0
  for i = 1, PN do
    local p = P[i]
    local f = p.life / p.max
    gfx.color(p.r, p.g, p.b, floor(255 * f))
    gfx.circle(ox + p.x * s, oy + p.y * s, max(0.8, p.size * s * (0.4 + 0.6 * f)))
  end
end

-- ------------------------------------------------------------------ score popups (world space)
local POPS = {}
for i = 1, 24 do POPS[i] = {t = 0, x = 0, y = 0, s = "", c = "#FFFFFF"} end
local popNext = 1
function K.popup(x, y, s, c)
  local p = POPS[popNext]
  popNext = popNext % #POPS + 1
  p.t, p.x, p.y, p.s, p.c = 1, x, y, s, c or "#FFFFFF"
end
function K.drawPopups(s, ox, oy, size)
  s, ox, oy = s or 1, ox or 0, oy or 0
  local fs = size or 16
  for i = 1, #POPS do
    local p = POPS[i]
    if p.t > 0 then
      local rise = K.easeOut(1 - p.t) * 44
      local px, py = ox + p.x * s, oy + p.y * s - rise
      local a = min(1, p.t * 2.5)
      gfx.color(0, 0, 0, floor(160 * a))
      gfx.text(p.s, px - 99, py - fs / 2 + 2, fs, "bold", "center", 200)
      K.color(p.c, a)
      gfx.text(p.s, px - 100, py - fs / 2, fs, "bold", "center", 200)
    end
  end
end

-- ------------------------------------------------------------------ callouts (screen space, big animated text)
local CALL = {}
for i = 1, 3 do CALL[i] = {t = 0, dur = 1, s = "", c = "#FFFFFF", size = 34, key = nil} end
function K.callout(s, c, size, key, dur)
  local slot
  if key then
    for i = 1, #CALL do if CALL[i].key == key and CALL[i].t > 0 then slot = CALL[i] end end
  end
  if not slot then
    slot = CALL[1]
    for i = 2, #CALL do if CALL[i].t < slot.t then slot = CALL[i] end end
  end
  slot.s, slot.c, slot.size, slot.key = s, c or "#FFFFFF", size or 34, key
  slot.dur = dur or 1.1
  slot.t = slot.dur
end
local function drawCallouts(w, h)
  local y = h * 0.3
  for i = 1, #CALL do
    local c = CALL[i]
    if c.t > 0 then
      local age = c.dur - c.t
      local sc = 0.55 + 0.45 * K.easeOutBack(age / 0.28)
      local fs = floor(c.size * sc / 2 + 0.5) * 2
      local a = min(1, c.t / 0.3)
      local yy = y - K.easeIn(1 - c.t / c.dur) * 16 - fs / 2
      gfx.color(0, 0, 0, floor(150 * a))
      gfx.text(c.s, 3, yy + 3, fs, "bold", "center", w)
      K.color(c.c, a)
      gfx.text(c.s, 0, yy, fs, "bold", "center", w)
      y = y + c.size + 10
    end
  end
end

-- ------------------------------------------------------------------ combos
-- register a hit inside the combo window; returns the combo count (1 = no combo yet)
function K.comboHit(window, color)
  K.comboN = K.comboN + 1
  K.comboT = window or 1.5
  if K.comboN > K.maxCombo then K.maxCombo = K.comboN end
  if K.comboN >= 2 then
    K.callout(TR("combo_n", K.comboN), color or "#FFD60A", 30 + min(16, K.comboN * 2), "combo", 0.9)
    K.tone(600 + min(12, K.comboN) * 60, 0.06, 0.08, "triangle")
  end
  return K.comboN
end
function K.comboBreak() K.comboN, K.comboT = 0, 0 end

-- ------------------------------------------------------------------ confetti and title motes (screen space)
local CONF, CN = {}, 0
for i = 1, 90 do CONF[i] = {x = 0, y = 0, vx = 0, vy = 0, rot = 0, vr = 0, size = 5, hue = 0, life = 0} end
function K.confetti(n)
  for _ = 1, n or 70 do
    if CN >= #CONF then return end
    CN = CN + 1
    local c = CONF[CN]
    c.x, c.y = random() * K.w, -10 - random() * K.h * 0.4
    c.vx, c.vy = (random() - 0.5) * 120, 90 + random() * 160
    c.rot, c.vr = random() * pi, (random() - 0.5) * 10
    c.size, c.hue, c.life = 4 + random() * 5, random(), 3.5
  end
end
local MOTES = {}
for i = 1, 26 do MOTES[i] = {x = random(), y = random(), s = 1 + random() * 3, v = 0.02 + random() * 0.05, ph = random() * 6} end

local function clearFx()
  PN = 0
  for i = 1, #POPS do POPS[i].t = 0 end
  for i = 1, #CALL do CALL[i].t = 0 end
  shakeAmt, flashT = 0, 0
end

function K.shake(a) shakeAmt = max(shakeAmt, a) end
function K.shakeXY()
  if shakeAmt <= 0.05 then return 0, 0 end
  return (random() * 2 - 1) * shakeAmt, (random() * 2 - 1) * shakeAmt
end
function K.flash(c, t) flashCol, flashT = c, t or 0.25 end

-- ------------------------------------------------------------------ input
local PADMAP = {up = "up", down = "down", left = "left", right = "right", a = "a", b = "b", x = "x", y = "y",
  plus = "pause", minus = "restart", l = "l", r = "r", zl = "zl", zr = "zr"}
local KEYMAP = {up = "up", down = "down", left = "left", right = "right", w = "up", s = "down", a = "left",
  d = "right", space = "a", enter = "a", z = "a", x = "b", c = "x", v = "y", escape = "pause", p = "pause",
  r = "restart", n = "restart", m = "mute", q = "l", e = "r"}

-- analog move vector from the stick and the held directions; y grows downwards
function K.axis()
  local x, y = 0, 0
  if K.down.left then x = x - 1 end
  if K.down.right then x = x + 1 end
  if K.down.up then y = y - 1 end
  if K.down.down then y = y + 1 end
  local sx, sy = input.stick("left")
  if abs(sx) > 0.2 then x = x + sx end
  if abs(sy) > 0.2 then y = y - sy end
  return K.clamp(x, -1, 1), K.clamp(y, -1, 1)
end
function K.held(act) return K.down[act] == true or stickDir == act end

-- ------------------------------------------------------------------ flow
function K.loadBest()
  bestKeyStr = G.bestKey and G.bestKey() or "best"
  K.best = store.get(bestKeyStr, 0)
end
function K.addScore(n)
  K.score = K.score + n
  K.bump = 1
end
function K.start()
  K.state, K.paused = "play", false
  K.score, K.shown, K.newBest = 0, 0, false
  K.overTitle, K.overStats, K.overWin = nil, nil, false
  K.playTime, K.comboN, K.comboT, K.maxCombo = 0, 0, 0, 0
  K.down = {}
  repAt = {}
  clearFx()
  CN = 0
  K.loadBest()
  G.reset()
  K.stateAt = K.now
  fadeT = 1
  K.sfx("start")
  K.callout(TR("go"), G.accent or "#FFFFFF", 44, "go", 0.9)
end
function K.toTitle()
  K.state, K.paused = "title", false
  clearFx()
  CN = 0
  K.loadBest()
  G.reset()
  K.stateAt = K.now
  fadeT = 0.6
end
function K.setPaused(p)
  if K.state ~= "play" or K.paused == p then return end
  K.paused = p
  K.pauseAt = K.now
  K.sfx("click", 0.8)
end
-- end of a round: opts.title, opts.stats = {{label, value}, ...}, opts.win
function K.over(opts)
  if K.state ~= "play" then return end
  opts = opts or EMPTY
  K.state, K.paused, K.overAt, K.stateAt = "over", false, K.now, K.now
  K.overTitle, K.overWin = opts.title, opts.win
  local stats = {}
  for i, s in ipairs(opts.stats or EMPTY) do stats[i] = s end
  stats[#stats + 1] = {TR("time_played"), K.fmtTime(K.playTime)}
  if K.maxCombo >= 2 then stats[#stats + 1] = {TR("max_combo"), "x" .. K.maxCombo} end
  K.overStats = stats
  if not K.noBest and K.score > K.best then
    K.best = K.score
    K.newBest = true
    store.set(bestKeyStr, K.best)
  end
  if K.newBest then
    K.sfx("best")
    timer.after(0.5, function() if K.state == "over" then K.confetti(80) end end)
  elseif opts.win then
    K.sfx("win")
  else
    K.sfx("lose")
  end
  K.vibrate(0.6, 180)
end

function K.press(act, e)
  if act == "mute" then K.setMuted(not K.muted) return end
  if K.state == "title" then
    if K.now - K.stateAt < 0.25 then return end
    if act == "a" or act == "pause" then K.start()
    elseif G.titlePress then G.titlePress(act) end
  elseif K.state == "over" then
    if K.now - K.overAt < 0.8 then return end
    if act == "a" or act == "restart" or act == "pause" then K.start()
    elseif act == "b" then K.toTitle() end
  elseif K.paused then
    if act == "a" or act == "pause" or act == "b" then K.setPaused(false)
    elseif act == "restart" then K.start()
    elseif act == "y" then K.toTitle() end
  elseif act == "pause" then
    K.setPaused(true)
  elseif act ~= "restart" then
    if G.rep and G.rep[act] then repAt[act] = K.now + (G.repDelay or 0.18) end
    if G.press then G.press(act, e) end
  end
end

-- ------------------------------------------------------------------ cards
local function card(w, h, cw, ch, t)
  -- t = 0..1 entrance progress: slide up with a little overshoot and fade in
  local x = floor((w - cw) / 2)
  local y = floor((h - ch) / 2 + (1 - K.easeOutBack(t)) * 70)
  gfx.shadow(x, y, cw, ch, 18, 30, 10)
  K.color(theme.window)
  gfx.rect(x, y, cw, ch, 18)
  K.color(theme.separator)
  gfx.rectLine(x, y, cw, ch, 18, 1)
  K.color(G.accent or theme.accent)
  gfx.rect(x + 24, y, cw - 48, 3, 2)
  return x, y
end

local function badge(cx, cy, icon, col, t)
  local bob = sin(t * 2.2) * 4
  cy = cy + bob
  K.color(col, 0.18)
  gfx.circle(cx, cy, 38 + sin(t * 3) * 2)
  K.color(col)
  gfx.circle(cx, cy, 30)
  K.color(col, 0.9)
  gfx.arc(cx, cy, 42, t * 1.6, t * 1.6 + 1.4, 3)
  gfx.arc(cx, cy, 42, t * 1.6 + pi, t * 1.6 + pi + 1.4, 3)
  K.color("#FFFFFF", 0.25)
  gfx.circle(cx - 8, cy - 9, 12)
  gfx.icon(icon, cx, cy, 36, "#FFFFFF")
end

-- the game name, letter by letter with a wave and a shimmer
local glyphs, glyphW = nil, 0
local function waveTitle(x, y, cw, t)
  if not glyphs then
    glyphs, glyphW = {}, 0
    for _, cp in utf8.codes(TR("title")) do
      local ch = utf8.char(cp)
      local gw = gfx.textWidth(ch, 30, "bold")
      glyphs[#glyphs + 1] = {ch, gw}
      glyphW = glyphW + gw
    end
  end
  local gx = x + (cw - glyphW) / 2
  local acc = G.accent or theme.accent
  for i = 1, #glyphs do
    local g = glyphs[i]
    local wy = sin(t * 3 - i * 0.5) * 3
    K.mix(theme.text, acc, 0.5 + 0.5 * sin(t * 2 - i * 0.35), 1)
    gfx.text(g[1], gx, y + wy, 30, "bold")
    gx = gx + g[2]
  end
end

local function settingsRow(x, y, cw)
  local half = floor(cw / 2)
  K.color(theme.text2)
  gfx.icon(K.muted and "volume_off" or "volume_up", x + 24, y + 14, 20, theme.text2)
  gfx.text(TR("sound"), x + 40, y + 5, 14, "medium")
  local s = ui.toggle("snd", not K.muted, x + half - 64, y + 2, 46, 26)
  if s == K.muted then K.setMuted(not s); K.sfx("click") end
  gfx.icon("vibration", x + half + 24, y + 14, 20, theme.text2)
  K.color(theme.text2)
  gfx.text(TR("vibration"), x + half + 40, y + 5, 14, "medium")
  local r = ui.toggle("rmb", K.rumble, x + cw - 64, y + 2, 46, 26)
  if r ~= K.rumble then
    K.rumble = r
    store.set("rumble", r)
    K.vibrate(0.5, 80)
  end
end

local function controlLines(x, y, cw, n)
  K.color(theme.text2)
  local list = K.controls or EMPTY
  for i = 1, min(n, #list) do
    gfx.text(list[i], x + 16, y, 13, "sans", "center", cw - 32)
    y = y + 20
  end
  gfx.text(TR("c_pause"), x + 16, y, 13, "sans", "center", cw - 32)
  return y + 20
end

local function drawMotes(w, h, t, a)
  for i = 1, #MOTES do
    local m = MOTES[i]
    local yy = (m.y - t * m.v) % 1
    K.color(G.accent or "#FFFFFF", a * (0.25 + 0.25 * sin(t * 2 + m.ph)))
    gfx.circle(m.x * w + sin(t + m.ph) * 12, yy * h, m.s)
  end
end

local function drawTitle(w, h)
  local t = K.now
  local e = K.easeOut((t - K.stateAt) / 0.5)
  K.color("#000000", 0.38 * e)
  gfx.rect(0, 0, w, h)
  drawMotes(w, h, t, e)
  local nctl = #(K.controls or EMPTY)
  local optH = G.optionsHeight or 0
  local cw = min(520, w - 24)
  local base = 18 + 96 + 40 + 26 + (optH > 0 and optH + 14 or 0) + 26 + 58 + 40 + 24 + 22
  if base + (nctl + 1) * 20 > h - 12 then nctl = max(0, floor((h - 12 - base) / 20) - 1) end
  local ch = base + (nctl + 1) * 20
  gfx.alpha(e)
  local x, y = card(w, h, cw, ch, (t - K.stateAt) / 0.55)
  local cy = y + 18
  badge(x + cw / 2, cy + 44, G.icon or "sports_esports", G.accent or theme.accent, t)
  cy = cy + 96
  waveTitle(x, cy, cw, t)
  cy = cy + 40
  K.color(theme.text2)
  gfx.text(TR("tagline"), x + 16, cy, 14, "sans", "center", cw - 32)
  cy = cy + 26
  if optH > 0 then
    G.options(x + 28, cy, cw - 56)
    cy = cy + optH + 14
  end
  if not K.noBest then
    K.color(G.accent or theme.accent)
    gfx.text(TR("best_n", K.best), x, cy, 15, "semibold", "center", cw)
  end
  cy = cy + 26
  local glow = 0.5 + 0.5 * sin(t * 4)
  K.color(G.accent or theme.accent, 0.12 + 0.18 * glow)
  gfx.rect(x + 44, cy - 4, cw - 88, 52, 14)
  if ui.button(TR("start"), x + 50, cy, cw - 100, 44, "primary", "play_arrow") and t - K.stateAt > 0.25 then K.start() end
  cy = cy + 58
  settingsRow(x + 24, cy, cw - 48)
  cy = cy + 40
  cy = controlLines(x, cy, cw, nctl)
  K.color(theme.text3)
  gfx.text(TR("title_hint"), x, cy + 4, 12, "sans", "center", cw)
  gfx.unalpha()
end

local function drawPause(w, h)
  local p = K.easeOut((K.now - K.pauseAt) / 0.25)
  K.color("#000000", 0.5 * p)
  gfx.rect(0, 0, w, h)
  local nctl = #(K.controls or EMPTY)
  local cw = min(460, w - 24)
  local base = 22 + 46 + 52 + 52 + 52 + 40 + 8 + 26
  if base + (nctl + 1) * 20 > h - 12 then nctl = max(0, floor((h - 12 - base) / 20) - 1) end
  local ch = base + (nctl + 1) * 20
  gfx.alpha(p)
  local x, y = card(w, h, cw, ch, (K.now - K.pauseAt) / 0.35)
  local cy = y + 22
  K.color(theme.text)
  gfx.text(TR("paused"), x, cy, 26, "bold", "center", cw)
  cy = cy + 46
  if ui.button(TR("resume"), x + 40, cy, cw - 80, 42, "primary", "play_arrow") then K.setPaused(false) end
  cy = cy + 52
  if ui.button(TR("restart"), x + 40, cy, cw - 80, 40, "default", "replay") then K.start() end
  cy = cy + 52
  local bw = floor((cw - 92) / 2)
  if ui.button(TR("menu"), x + 40, cy, bw, 40, "default", "home") then K.toTitle() end
  if ui.button(TR("quit"), x + 52 + bw, cy, bw, 40, "destructive", "logout") then sys.exit() end
  cy = cy + 52
  settingsRow(x + 24, cy, cw - 48)
  cy = cy + 48
  cy = controlLines(x, cy, cw, nctl)
  K.color(theme.text3)
  gfx.text(TR("pause_hint"), x, cy + 2, 12, "sans", "center", cw)
  gfx.unalpha()
end

local function drawConfetti()
  for i = 1, CN do
    local c = CONF[i]
    local s, cr, sr = c.size, cos(c.rot), sin(c.rot)
    QUAD[1], QUAD[2] = c.x - cr * s, c.y - sr * s * 0.5
    QUAD[3], QUAD[4] = c.x + sr * s * 0.4, c.y - cr * s * 0.4
    QUAD[5], QUAD[6] = c.x + cr * s, c.y + sr * s * 0.5
    QUAD[7], QUAD[8] = c.x - sr * s * 0.4, c.y + cr * s * 0.4
    K.hsv(c.hue, 0.75, 1, min(1, c.life))
    gfx.poly(QUAD)
  end
end

local function updateConfetti(dt)
  local i = 1
  while i <= CN do
    local c = CONF[i]
    c.life = c.life - dt
    if c.life <= 0 or c.y > K.h + 20 then
      CONF[i], CONF[CN] = CONF[CN], c
      CN = CN - 1
    else
      c.x = c.x + (c.vx + sin(c.rot * 0.7) * 30) * dt
      c.y = c.y + c.vy * dt
      c.rot = c.rot + c.vr * dt
      i = i + 1
    end
  end
end

local function drawOver(w, h)
  local t = K.now
  local a = K.easeOut((t - K.overAt) / 0.4)
  K.color("#000000", 0.5 * a)
  gfx.rect(0, 0, w, h)
  local stats = K.overStats or EMPTY
  local rows = floor((#stats + 1) / 2)
  local cw = min(460, w - 24)
  local ch = 18 + 96 + 36 + 18 + 54 + 30 + rows * 42 + 10 + 54 + 24
  local compact = ch > h - 12          -- small window: drop the badge
  if compact then ch = ch - 84 end
  gfx.alpha(a)
  local x, y = card(w, h, cw, ch, (t - K.overAt) / 0.55)
  local cy = y + 18
  local good = K.newBest or K.overWin
  if not compact then
    badge(x + cw / 2, cy + 44, good and "emoji_events" or (G.overIcon or "sentiment_dissatisfied"),
      good and "#FF9F0A" or (G.accent or theme.accent), t)
    cy = cy + 96
  else
    cy = cy + 12
  end
  K.color(theme.text)
  gfx.text(K.overTitle or TR("game_over"), x, cy, 26, "bold", "center", cw)
  cy = cy + 36
  K.color(theme.text2)
  gfx.text(TR("score"), x, cy, 13, "medium", "center", cw)
  cy = cy + 18
  local cnt = K.score * K.easeOut((t - K.overAt - 0.2) / 0.9)
  K.color(G.accent or theme.accent)
  gfx.text(tostring(floor(cnt + 0.5)), x, cy, 42, "bold", "center", cw)
  cy = cy + 54
  if not K.noBest then
    if K.newBest then
      local pulse = 0.5 + 0.5 * sin(t * 6)
      K.hsv(t * 0.5, 0.65, 1, 0.25 + 0.25 * pulse)
      gfx.rect(x + cw / 2 - 110, cy - 3, 220, 26, 13)
      K.hsv(t * 0.5, 0.8, 1)
      gfx.text(TR("new_best"), x, cy, 16, "bold", "center", cw)
    else
      K.color(theme.text2)
      gfx.text(TR("best_n", K.best), x, cy, 15, "medium", "center", cw)
    end
  end
  cy = cy + 30
  -- stats grid
  local colw = floor((cw - 48 - 10) / 2)
  for i = 1, #stats do
    local col, row = (i - 1) % 2, floor((i - 1) / 2)
    local sx, sy = x + 24 + col * (colw + 10), cy + row * 42
    local st = K.easeOut((t - K.overAt - 0.3 - i * 0.08) / 0.3)
    K.color(theme.hover, 1)
    gfx.rect(sx, sy, colw, 36, 10)
    K.color(theme.text2, st)
    gfx.text(stats[i][1], sx + 12, sy + 10, 13, "medium")
    K.color(theme.text, st)
    gfx.text(stats[i][2], sx + 12, sy + 8, 16, "bold", "right", colw - 24)
  end
  cy = cy + rows * 42 + 10
  local bw = floor((cw - 60) / 2)
  local ready = t - K.overAt > 0.8
  if ui.button(TR("play_again"), x + 20, cy, bw, 42, "primary", "replay") and ready then K.start() end
  if ui.button(TR("menu"), x + 40 + bw, cy, bw, 42, "default", "home") and ready then K.toTitle() end
  cy = cy + 54
  K.color(theme.text3)
  gfx.text(TR("over_hint"), x, cy, 12, "sans", "center", cw)
  gfx.unalpha()
end

-- small HUD chip: dark glass pill with an icon and text; align "right" puts its right edge at x. Returns width.
function K.pill(x, y, icon, text, col, align, glow)
  local tw = gfx.textWidth(text, 17, "bold")
  local pw = tw + (icon and 44 or 24)
  if align == "right" then x = x - pw elseif align == "center" then x = x - pw / 2 end
  if glow and glow > 0 then
    K.color(col or "#FFFFFF", 0.35 * glow)
    gfx.rect(x - 4 * glow, y - 4 * glow, pw + 8 * glow, 34 + 8 * glow, 17 + 4 * glow)
  end
  gfx.color(0, 0, 0, 120)
  gfx.rect(x, y, pw, 34, 17)
  if icon then
    gfx.icon(icon, x + 20, y + 17, 20, col or "#FFFFFF")
    gfx.color(255, 255, 255, 240)
    gfx.text(text, x + 34, y + 6, 17, "bold")
  else
    gfx.color(255, 255, 255, 240)
    gfx.text(text, x + 12, y + 6, 17, "bold")
  end
  return pw
end
-- the score pill: counts up smoothly and glows when points arrive
function K.scorePill(x, y, align)
  return K.pill(x, y, "star", tostring(floor(K.shown + 0.5)), "#FFD60A", align, K.bump)
end
function K.bestPill(x, y)
  return K.pill(x, y, "emoji_events", tostring(max(K.best, K.score)), "#FF9F0A", "right")
end

-- centered banner text with a soft shadow (e.g. "Get ready")
function K.banner(s, x, y, w, size, c, a)
  size = size or 24
  a = a or 1
  gfx.color(0, 0, 0, floor(140 * a))
  gfx.text(s, x + 2, y + 2, size, "bold", "center", w)
  K.color(c or "#FFFFFF", a)
  gfx.text(s, x, y, size, "bold", "center", w)
end

-- ------------------------------------------------------------------ app
function K.run(game)
  G = game
  local app = {}

  function app.load()
    K.muted = store.get("muted", false) == true
    K.rumble = store.get("rumble", true) ~= false
    local w, h = gfx.size()
    if w and w > 0 and h and h > 0 then K.w, K.h = w, h end
    K.now = sys.time()
    if G.load then G.load() end
    K.controls = G.controls and G.controls() or EMPTY
    if G.layout then G.layout(K.w, K.h) end
    K.loadBest()
    G.reset()
    K.stateAt = K.now
  end

  function app.update(dt)
    if dt > 0.05 then dt = 0.05 end
    K.now = sys.time()
    if K.state == "play" and not K.paused then
      K.playTime = K.playTime + dt
      if K.comboT > 0 then
        K.comboT = K.comboT - dt
        if K.comboT <= 0 then K.comboN = 0 end
      end
      if G.stickPress or G.rep then
        local sx, sy = input.stick("left")
        local dir = nil
        if abs(sx) > 0.55 or abs(sy) > 0.55 then
          if abs(sx) > abs(sy) then dir = sx > 0 and "right" or "left" else dir = sy > 0 and "up" or "down" end
        end
        if dir ~= stickDir then
          stickDir = dir
          if dir and G.stickPress then K.press(dir) end
        end
      end
      if G.rep then
        for act in pairs(G.rep) do
          if K.held(act) then
            if repAt[act] and K.now >= repAt[act] then
              repAt[act] = K.now + (G.repRate or 0.05)
              if G.press then G.press(act) end
            elseif not repAt[act] then
              repAt[act] = K.now + (G.repDelay or 0.18)
            end
          else
            repAt[act] = nil
          end
        end
      end
      G.update(dt)
    end
    if not K.paused then
      updateParticles(dt)
      for i = 1, #POPS do
        local p = POPS[i]
        if p.t > 0 then p.t = p.t - dt * 1.1 end
      end
      for i = 1, #CALL do
        if CALL[i].t > 0 then CALL[i].t = CALL[i].t - dt end
      end
      shakeAmt = shakeAmt * (1 - min(1, dt * 9))
      if flashT > 0 then flashT = flashT - dt end
      if G.idle then G.idle(dt) end
    end
    if fadeT > 0 then fadeT = fadeT - dt * 2.2 end
    if K.bump > 0 then K.bump = max(0, K.bump - dt * 3) end
    if K.shown < K.score then
      K.shown = min(K.score, K.shown + max(1, (K.score - K.shown) * 12 * dt))
    elseif K.shown > K.score then
      K.shown = K.score
    end
    updateConfetti(dt)
  end

  function app.draw(w, h)
    if w ~= K.w or h ~= K.h then
      K.w, K.h = w, h
      if G.layout then G.layout(w, h) end
    end
    G.draw(w, h)
    if flashT > 0 and flashCol then
      K.color(flashCol, min(1, flashT * 3))
      gfx.rect(0, 0, w, h)
    end
    drawCallouts(w, h)
    if K.state == "play" then
      if K.paused then
        drawPause(w, h)
      else
        local hit = ui.hit("pausebtn", w - 52, 6, 46, 46)
        gfx.color(0, 0, 0, hit.hovered and 150 or 100)
        gfx.circle(w - 29, 29, 19)
        gfx.icon("pause", w - 29, 29, 24, "#FFFFFF")
        if hit.clicked then K.setPaused(true) end
      end
    elseif K.state == "title" then
      drawTitle(w, h)
    else
      drawOver(w, h)
    end
    drawConfetti()
    if fadeT > 0 then
      gfx.color(0, 0, 0, floor(255 * K.easeIn(min(1, fadeT))))
      gfx.rect(0, 0, w, h)
    end
  end

  function app.event(e)
    local t = e.type
    local act
    if t == "paddown" or t == "padup" then K.raw["p_" .. tostring(e.pad)] = t == "paddown"
    elseif t == "keydown" or t == "keyup" then K.raw["k_" .. tostring(e.key)] = t == "keydown" end
    if t == "paddown" then
      K.lastInput = "pad"
      act = PADMAP[e.pad]
    elseif t == "keydown" then
      K.lastInput = "key"
      act = KEYMAP[e.key]
    elseif t == "padup" or t == "keyup" then
      local a = (t == "padup") and PADMAP[e.pad] or KEYMAP[e.key]
      if a then
        K.down[a] = false
        if G.release and K.state == "play" and not K.paused then G.release(a, e) end
      end
      return
    elseif t == "mousedown" or t == "mouseup" or t == "mousemove" or t == "scroll" then
      if t == "mousedown" then K.lastInput = "touch" end
      if K.state == "play" and not K.paused and G.pointer then
        if t == "mousedown" and e.x > K.w - 56 and e.y < 56 then return end
        G.pointer(e)
      end
      return
    end
    if not act then
      if t == "keydown" and G.key and K.state == "play" and not K.paused then G.key(e.key) end
      return
    end
    local was = K.down[act]
    K.down[act] = true
    -- keyboard auto-repeat of a key the game already repeats itself
    if was and t == "keydown" and G.rep and G.rep[act] and K.state == "play" then return end
    K.press(act, e)
  end

  function app.menu()
    local items = {
      {label = TR("new_game"), id = 1, shortcut = "N"},
      {label = K.paused and TR("resume") or TR("pause"), id = 2, shortcut = "P", enabled = K.state == "play"},
      "-",
      {label = TR("sound"), id = 3, checked = not K.muted, shortcut = "M"},
      {label = TR("vibration"), id = 5, checked = K.rumble},
      "-",
      {label = TR("reset_best"), id = 4},
    }
    if G.menu then G.menu(items) end
    return {{title = TR("menu_game"), items = items}}
  end

  function app.onmenu(id)
    if id == 1 then K.start()
    elseif id == 2 then K.setPaused(not K.paused)
    elseif id == 3 then K.setMuted(not K.muted)
    elseif id == 5 then K.rumble = not K.rumble; store.set("rumble", K.rumble)
    elseif id == 4 then
      ui.alert(TR("reset_best"), TR("reset_best_msg"), {TR("reset"), TR("cancel")}, function(b)
        if b == 1 then
          if G.resetBest then G.resetBest() else store.set(bestKeyStr, 0) end
          K.loadBest()
        end
      end)
    elseif G.onmenu then G.onmenu(id) end
  end

  function app.close()
    return true
  end

  return app
end

return K
