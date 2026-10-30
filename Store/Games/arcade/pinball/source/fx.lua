-- fx.lua: polish helpers shared by this game's scenes. Floating text popups, screen shake, confetti, chords, the
-- sound toggle for menus and a hint line that shrinks to fit. Everything is pre-allocated: no tables per frame.

local game = require("nexvyn.game")
local G, U, A = game.gfx, game.ui, game.audio
local E = game.tween.ease
local random, min, max, ceil, pi = math.random, math.min, math.max, math.ceil, math.pi

local fx = {}

-- ---------------------------------------------------------------- popups ("+500", "Birdie!")
local Popups = {}
Popups.__index = Popups

function fx.popups(n)
  local p = setmetatable({n = n or 10, items = {}}, Popups)
  for i = 1, p.n do
    p.items[i] = {t = 0, life = 0, text = "", x = 0, y = 0, color = "#FFFFFF", size = 12, rise = 24}
  end
  return p
end

-- add(text, x, y[, color[, size[, life[, rise]]]]) reuses the slot that is closest to finishing
function Popups:add(text, x, y, color, size, life, rise)
  local slot, bk = self.items[1], -1
  for i = 1, self.n do
    local it = self.items[i]
    local k = it.life > 0 and it.t / it.life or 2
    if k > bk then slot, bk = it, k end
  end
  slot.text, slot.x, slot.y, slot.color = tostring(text), x, y, color or "#FFFFFF"
  slot.size, slot.life, slot.t, slot.rise = size or 12, life or 1.1, 0, rise or 26
end

function Popups:update(dt)
  for i = 1, self.n do
    local it = self.items[i]
    if it.t < it.life then it.t = it.t + dt end
  end
end

function Popups:clear()
  for i = 1, self.n do self.items[i].life, self.items[i].t = 0, 0 end
end

-- pops in with outBack, rises with outCubic and fades out
function Popups:draw()
  for i = 1, self.n do
    local it = self.items[i]
    if it.life > 0 and it.t < it.life then
      local k = it.t / it.life
      local s = E.outBack(min(1, k * 4))
      local a = k < 0.65 and 1 or max(0, 1 - (k - 0.65) / 0.35)
      local size = it.size * (0.35 + 0.65 * s)
      local y = it.y - it.rise * E.outCubic(k)
      G.alpha(a)
      U.text(it.text, it.x - 160, y - size * 0.62, size, it.color, "center", 320)
      G.unalpha()
    end
  end
end

-- ---------------------------------------------------------------- screen shake
local Shake = {}
Shake.__index = Shake

function fx.shake() return setmetatable({amp = 0, t = 0, dur = 1, x = 0, y = 0}, Shake) end

function Shake:add(amp, dur)
  local cur = self.t > 0 and self.amp * (self.t / self.dur) or 0
  if amp >= cur then self.amp, self.dur, self.t = amp, max(0.01, dur or 0.3), max(0.01, dur or 0.3) end
end

function Shake:update(dt)
  if self.t > 0 then
    self.t = max(0, self.t - dt)
    local k = self.t / self.dur
    local a = self.amp * k * k
    self.x, self.y = (random() * 2 - 1) * a, (random() * 2 - 1) * a
  else
    self.x, self.y = 0, 0
  end
end

-- ---------------------------------------------------------------- confetti (one emitter per colour)
local CONF = {"#FF4D6D", "#FFD166", "#06D6A0", "#4CC9F0", "#B388FF"}
local Confetti = {}
Confetti.__index = Confetti

function fx.confetti(perColor)
  local c = setmetatable({ems = {}}, Confetti)
  for i, col in ipairs(CONF) do
    c.ems[i] = game.emitter{max = perColor or 60, life = {1.3, 2.6}, speed = {90, 300}, angle = -pi / 2, spread = 1.6,
                            gravity = 320, damping = 1.3, size = {5, 3}, sizeVar = 0.5, shape = "square",
                            colors = {col, col, col .. "00"}}
  end
  return c
end

function Confetti:burst(n, x, y, angle, spread)
  local per = ceil(n / #self.ems)
  for i = 1, #self.ems do
    local em = self.ems[i]
    if spread then em.spread = spread end
    em:emit(per, x, y, angle or -pi / 2)
  end
end

function Confetti:update(dt) for i = 1, #self.ems do self.ems[i]:update(dt) end end
function Confetti:draw() for i = 1, #self.ems do self.ems[i]:draw() end end
function Confetti:clear() for i = 1, #self.ems do self.ems[i]:clear() end end

-- ---------------------------------------------------------------- sound
-- several tones at once: fx.chord("C5 E5 G5", 0.4, 0.12, "triangle")
function fx.chord(notes, dur, vol, wave)
  if A.muted then return end
  for name in notes:gmatch("%S+") do A.tone(name, dur, vol, wave) end
end

local function toggleSound()
  A.setMuted(not A.muted)
  game.save.open("settings"):set("muted", A.muted)
end

-- a menu row that shows and toggles the sound (left/right toggle it too)
function fx.soundItem()
  return {label = function() return TR("sound", A.muted and TR("off") or TR("on")) end,
          action = toggleSound, left = toggleSound, right = toggleSound}
end

-- ---------------------------------------------------------------- text
-- a centred line at y that gets smaller instead of running off the screen; returns the size used
function fx.fitLine(s, y, size, color, font)
  font = font or "semibold"
  local w = G.textWidth(s, size, font)
  local sz = min(size, size * (game.width - 16) / max(1, w))
  U.text(s, 0, y, sz, color or "#FFFFFFC0", "center", game.width, font)
  return sz
end

-- ease value for intros: fx.ease("outBack", k)
function fx.ease(name, k)
  local f = E[name] or E.linear
  if k < 0 then k = 0 elseif k > 1 then k = 1 end
  return f(k)
end

return fx
