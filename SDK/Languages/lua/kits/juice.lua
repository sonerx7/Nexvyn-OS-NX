-- juice.lua: graphics, UI and game-feel building blocks for Nexvyn OS games (Lua 5.4, no dependencies, SDK calls
-- only). Not a template: small pieces you combine in your own art direction.
--
--   easing and tweens, springs and frame-rate independent damping, screen shake (trauma), hit-stop and slow motion,
--   flashes, particles with soft glow sprites, generated textures (glow, vignette, grain, soft shadow, light ray),
--   multi-stop gradients, palettes and colour maths, typography (scale, letter spacing, outlined / two-tone /
--   glowing titles, fit to width), panels with depth in five shape languages, buttons with hover / press / focus
--   states, screen transitions (fade, iris, wipe, blinds, pixels), a smoothed 2D camera and a 3D follow camera,
--   3D lighting / fog / sky presets.
--
-- Copy this file next to main.lua, then:
--
--   local J = require("juice")
--   function app.load() J.init() end                     -- makes the textures once (cached in the folder "fx")
--   function app.update(dt)
--     J.update(dt)                                       -- tweens, shake, particles, transitions, floaters
--     local gdt = J.dt(dt)                               -- 0 during a hit-stop: use it for the game simulation
--   end
--   function app.event(e) J.event(e) end                 -- pointer for J.button
--   function app.draw(w, h)
--     local sx, sy = J.shakeOffset(14)
--     gfx.push(sx, sy) ... your world ... J.drawParticles() gfx.pop()
--     J.vignette(w, h, 0.55) ... HUD ... J.overlay(w, h)  -- flash and transitions on top of everything
--   end
--
-- Guide with before / after descriptions: SDK/Guides/GAME_FEEL.en.md.
local J = {}
J.folder = "fx"
J.version = 1

local floor, sqrt, sin, cos, exp, abs, min, max, pi = math.floor, math.sqrt, math.sin, math.cos, math.exp, math.abs,
  math.min, math.max, math.pi
local rnd = math.random
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
J.clamp = clamp
function J.lerp(a, b, t) return a + (b - a) * t end

-- ------------------------------------------------------------------ easing
local E = {}
J.ease = E
E.linear = function(t) return t end
E.inQuad = function(t) return t * t end
E.outQuad = function(t) return 1 - (1 - t) * (1 - t) end
E.inOutQuad = function(t) return t < 0.5 and 2 * t * t or 1 - (-2 * t + 2) ^ 2 / 2 end
E.outCubic = function(t) return 1 - (1 - t) ^ 3 end
E.inOutCubic = function(t) return t < 0.5 and 4 * t * t * t or 1 - (-2 * t + 2) ^ 3 / 2 end
E.outQuart = function(t) return 1 - (1 - t) ^ 4 end
E.outExpo = function(t) return t >= 1 and 1 or 1 - 2 ^ (-10 * t) end
E.inOutSine = function(t) return -(cos(pi * t) - 1) / 2 end
E.outBack = function(t) local c = 1.70158; return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2 end
E.outElastic = function(t)
  if t <= 0 or t >= 1 then return t end
  return 2 ^ (-10 * t) * sin((t * 10 - 0.75) * (2 * pi) / 3) + 1
end
E.outBounce = function(t)
  local n, d = 7.5625, 2.75
  if t < 1 / d then return n * t * t
  elseif t < 2 / d then t = t - 1.5 / d; return n * t * t + 0.75
  elseif t < 2.5 / d then t = t - 2.25 / d; return n * t * t + 0.9375 end
  t = t - 2.625 / d
  return n * t * t + 0.984375
end

-- ------------------------------------------------------------------ tweens, springs, damping
local tweens = {}
-- tween(target, seconds, {field = value}[, ease name or function[, {delay, done, loop, yoyo}]]) -> tween
function J.tween(obj, sec, props, ease, o)
  o = o or {}
  local tw = {obj = obj, sec = max(sec, 0.0001), to = props, from = {}, t = -(o.delay or 0),
    ease = type(ease) == "function" and ease or E[ease or "outCubic"] or E.outCubic, done = o.done, loop = o.loop,
    yoyo = o.yoyo}
  tweens[#tweens + 1] = tw
  return tw
end
function J.cancel(tw) if tw then tw.dead = true end end
local function updateTweens(dt)
  for i = #tweens, 1, -1 do
    local tw = tweens[i]
    if not tw.dead then
      tw.t = tw.t + dt
      if tw.t >= 0 then
        if not tw.started then
          tw.started = true
          for k in pairs(tw.to) do tw.from[k] = tw.obj[k] or 0 end
        end
        local p = min(1, tw.t / tw.sec)
        local e = tw.ease(p)
        for k, v in pairs(tw.to) do tw.obj[k] = tw.from[k] + (v - tw.from[k]) * e end
        if p >= 1 then
          if tw.loop then
            tw.t = 0
            if tw.yoyo then tw.from, tw.to = tw.to, tw.from end
          else
            tw.dead = true
            if tw.done then tw.done(tw.obj) end
          end
        end
      end
    end
    if tw.dead then table.remove(tweens, i) end
  end
end

-- damp(current, target, rate, dt): smooth follow that looks the same at 30 and 60 fps (rate ~ 4 slow .. 20 snappy)
function J.damp(a, b, rate, dt) return b + (a - b) * exp(-rate * dt) end
-- spring(state {x, v}, target, dt[, frequency Hz[, damping 0..1]]): overshoots a little when damping < 1
function J.spring(s, target, dt, freq, damping)
  local w = 2 * pi * (freq or 4)
  local z = damping or 0.5
  local steps = math.ceil(dt / (1 / 120))
  local h = dt / steps
  for _ = 1, steps do
    local acc = -2 * z * w * s.v - w * w * (s.x - target)
    s.v = s.v + acc * h
    s.x = s.x + s.v * h
  end
  return s.x
end

-- ------------------------------------------------------------------ time: hit-stop, slow motion
local freeze, slowScale, slowLeft = 0, 1, 0
-- hitstop(seconds): the game simulation stops for 2-6 frames on a heavy hit (0.03-0.1 s)
function J.hitstop(sec) freeze = max(freeze, sec) end
-- slowmo(scale, seconds): e.g. 0.3 for 0.6 s on the last enemy
function J.slowmo(scale, sec) slowScale, slowLeft = scale, sec end
-- dt for the game simulation
function J.dt(dt)
  if freeze > 0 then return 0 end
  return dt * (slowLeft > 0 and slowScale or 1)
end

-- ------------------------------------------------------------------ shake (trauma: shake = trauma^2)
local trauma, shakeT = 0, 0
local seedX, seedY = rnd() * 100, rnd() * 100
function J.shake(amount) trauma = min(1, trauma + amount) end
-- offset in pixels for gfx.push (maxPx: the shake at full trauma)
function J.shakeOffset(maxPx)
  local s = trauma * trauma * (maxPx or 12)
  if s <= 0.01 then return 0, 0 end
  local t = shakeT * 28
  local x = (sin(t + seedX) + sin(t * 2.3 + seedX * 1.7) * 0.5) / 1.5
  local y = (sin(t * 1.1 + seedY) + sin(t * 2.7 + seedY * 1.3) * 0.5) / 1.5
  return x * s, y * s
end
function J.trauma() return trauma end

-- ------------------------------------------------------------------ colour
local cache = {}
-- rgb("#RRGGBB" or "#RRGGBBAA") -> r, g, b, a (0..255), memoized
function J.rgb(c)
  local t = cache[c]
  if not t then
    if type(c) == "table" then return c[1], c[2], c[3], c[4] or 255 end
    local h = c:gsub("#", "")
    t = {tonumber(h:sub(1, 2), 16) or 0, tonumber(h:sub(3, 4), 16) or 0, tonumber(h:sub(5, 6), 16) or 0,
      #h >= 8 and tonumber(h:sub(7, 8), 16) or 255}
    cache[c] = t
  end
  return t[1], t[2], t[3], t[4]
end
local function hex(r, g, b, a)
  if a and a < 255 then
    return string.format("#%02X%02X%02X%02X", floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255)), floor(clamp(a, 0, 255)))
  end
  return string.format("#%02X%02X%02X", floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255)))
end
J.hex = hex
-- mix(c1, c2, t) -> "#RRGGBB(AA)"; shade(c, f): f < 1 darker, > 1 lighter; alpha(c, 0..1)
function J.mix(c1, c2, t)
  local r1, g1, b1, a1 = J.rgb(c1)
  local r2, g2, b2, a2 = J.rgb(c2)
  return hex(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t, a1 + (a2 - a1) * t)
end
function J.shade(c, f)
  local r, g, b, a = J.rgb(c)
  if f <= 1 then return hex(r * f, g * f, b * f, a) end
  local k = f - 1
  return hex(r + (255 - r) * k, g + (255 - g) * k, b + (255 - b) * k, a)
end
function J.alpha(c, a)
  local r, g, b = J.rgb(c)
  return hex(r, g, b, a * 255)
end
-- mixInto(out, c1, c2, t): the same into a reused table {r, g, b, a} (no garbage in draw loops)
function J.mixInto(out, c1, c2, t, alpha)
  local r1, g1, b1, a1 = J.rgb(c1)
  local r2, g2, b2, a2 = J.rgb(c2)
  -- whole numbers: colour tables must hold integers 0..255
  out[1] = floor(clamp(r1 + (r2 - r1) * t, 0, 255) + 0.5)
  out[2] = floor(clamp(g1 + (g2 - g1) * t, 0, 255) + 0.5)
  out[3] = floor(clamp(b1 + (b2 - b1) * t, 0, 255) + 0.5)
  out[4] = floor(clamp((a1 + (a2 - a1) * t) * (alpha or 1), 0, 255) + 0.5)
  return out
end

-- Palettes: 6 colours each, with roles. Use one as a starting point, then make it yours (move the hues).
-- deep: darkest background, bg: background, mid: shapes and panels, ink: text, accent: the player / actions,
-- accent2: danger / rewards, light: highlights and glows.
J.palettes = {
  ember = {deep = "#140C1C", bg = "#2A1630", mid = "#5B2A3C", ink = "#FFE9D2", accent = "#FF6B35", accent2 = "#FFC145", light = "#FFF3B0"},
  frost = {deep = "#06121F", bg = "#0E2A47", mid = "#2E5C8A", ink = "#E8F6FF", accent = "#5CE1E6", accent2 = "#FF7AA2", light = "#FFFFFF"},
  toxic = {deep = "#0A0F0A", bg = "#14261A", mid = "#2F4F2A", ink = "#E9FFD9", accent = "#9DFF3A", accent2 = "#FF3AC8", light = "#F4FFB0"},
  synth = {deep = "#0B0221", bg = "#1D0B45", mid = "#4C1D95", ink = "#FCEBFF", accent = "#FF2E88", accent2 = "#19E6FF", light = "#FFD166"},
  jungle = {deep = "#0C1A12", bg = "#183A26", mid = "#2F6B3E", ink = "#F2F7D9", accent = "#F2B134", accent2 = "#E8505B", light = "#FFF6C2"},
  paper = {deep = "#2B2118", bg = "#F4EAD5", mid = "#D8C3A0", ink = "#2B2118", accent = "#E9573F", accent2 = "#3F7CAC", light = "#FFFDF6"},
  noir = {deep = "#050505", bg = "#121212", mid = "#2B2B2B", ink = "#F2F2F2", accent = "#E63946", accent2 = "#F1FAEE", light = "#FFFFFF"},
  candy = {deep = "#2D1B4E", bg = "#FFB5D8", mid = "#FF7EB6", ink = "#2D1B4E", accent = "#7AE7C7", accent2 = "#FFE156", light = "#FFFFFF"},
}

-- gradient(x, y, w, h, {c1, c2, c3, ...}[, horizontal]): several stops, evenly spaced
function J.gradient(x, y, w, h, stops, horizontal)
  local n = #stops - 1
  if n < 1 then gfx.rect(x, y, w, h, 0, stops[1]) return end
  for i = 1, n do
    if horizontal then
      local x0, x1 = x + w * (i - 1) / n, x + w * i / n
      gfx.gradient(floor(x0), y, math.ceil(x1 - floor(x0)) + 1, h, stops[i], stops[i + 1], true)
    else
      local y0, y1 = y + h * (i - 1) / n, y + h * i / n
      gfx.gradient(x, floor(y0), w, math.ceil(y1 - floor(y0)) + 1, stops[i], stops[i + 1])
    end
  end
end

-- ------------------------------------------------------------------ generated textures (PNG, made once)
local CRC = {}
for i = 0, 255 do
  local c = i
  for _ = 1, 8 do
    if c & 1 == 1 then c = 0xEDB88320 ~ (c >> 1) else c = c >> 1 end
  end
  CRC[i] = c
end
local function crc32(s)
  local c = 0xffffffff
  for i = 1, #s do c = CRC[(c ~ s:byte(i)) & 0xff] ~ (c >> 8) end
  return c ~ 0xffffffff
end
local function adler32(s)
  local a, b = 1, 0
  for i = 1, #s do
    a = (a + s:byte(i)) % 65521
    b = (b + a) % 65521
  end
  return (b << 16) | a
end
local function chunk(kind, data)
  return string.pack(">I4", #data) .. kind .. data .. string.pack(">I4", crc32(kind .. data))
end
-- png(w, h, fn(x, y) -> r, g, b, a) -> PNG file contents (uncompressed deflate: simple and exact)
function J.png(w, h, fn)
  local rows = {}
  local px = {}
  for y = 0, h - 1 do
    px[1] = "\0"
    for x = 0, w - 1 do
      local r, g, b, a = fn(x, y)
      px[x + 2] = string.char(floor(clamp(r, 0, 255)), floor(clamp(g, 0, 255)), floor(clamp(b, 0, 255)), floor(clamp(a, 0, 255)))
    end
    rows[#rows + 1] = table.concat(px, "", 1, w + 1)
  end
  local raw = table.concat(rows)
  local blocks = {"\x78\x01"}
  local pos, n = 1, #raw
  repeat
    local len = min(65535, n - pos + 1)
    local final = pos + len > n and 1 or 0
    blocks[#blocks + 1] = string.pack("<BI2I2", final, len, len ~ 0xffff) .. raw:sub(pos, pos + len - 1)
    pos = pos + len
  until pos > n
  blocks[#blocks + 1] = string.pack(">I4", adler32(raw))
  return "\137PNG\r\n\26\n" .. chunk("IHDR", string.pack(">I4I4BBBBB", w, h, 8, 6, 0, 0, 0)) ..
    chunk("IDAT", table.concat(blocks)) .. chunk("IEND", "")
end
-- texture(name, w, h, fn) -> image: generated once into the data folder, then loaded from there
function J.texture(name, w, h, fn)
  local path = string.format("%s/%s_%d_%dx%d.png", J.folder, name, J.version, w, h)
  if not fs.exists(path) then fs.write(path, J.png(w, h, fn)) end
  return gfx.image(path)
end
local function smooth(a, b, x)
  local t = clamp((x - a) / (b - a), 0, 1)
  return t * t * (3 - 2 * t)
end
J.smoothstep = smooth

J.tex = {}
function J.init(o)
  o = o or {}
  J.folder = o.folder or J.folder
  fs.mkdir(J.folder)
  -- soft round light: white, alpha falls off like a real glow (tint it with any colour)
  J.tex.glow = J.texture("glow", 64, 64, function(x, y)
    local d = sqrt((x - 31.5) ^ 2 + (y - 31.5) ^ 2) / 32
    local a = (1 - smooth(0, 1, d)) ^ 2.2
    return 255, 255, 255, a * 255
  end)
  -- vignette: transparent centre, dark edges (draw stretched over the screen)
  J.tex.vignette = J.texture("vignette", 128, 128, function(x, y)
    local dx, dy = (x - 63.5) / 63.5, (y - 63.5) / 63.5
    local d = sqrt(dx * dx + dy * dy) / sqrt(2)
    return 0, 0, 0, smooth(0.35, 1.0, d) ^ 1.4 * 255
  end)
  -- film grain: grey noise (draw at 3-6 % alpha, moved every frame)
  local s = 12345
  J.tex.grain = J.texture("grain", 128, 128, function()
    s = (s * 1103515245 + 12345) & 0x7fffffff
    local v = s % 256
    return v, v, v, 255
  end)
  -- soft elliptical shadow for characters standing on the ground
  J.tex.shadow = J.texture("shadow", 64, 32, function(x, y)
    local dx, dy = (x - 31.5) / 32, (y - 15.5) / 16
    local d = sqrt(dx * dx + dy * dy)
    return 0, 0, 0, (1 - smooth(0.2, 1, d)) * 200
  end)
  -- light shaft: bright at the top, fading down and to the sides
  J.tex.ray = J.texture("ray", 32, 128, function(x, y)
    local dx = abs(x - 15.5) / 16
    return 255, 255, 255, (1 - smooth(0, 1, dx)) * (1 - y / 127) ^ 1.5 * 255
  end)
end

-- glow(x, y, radius, colour[, alpha]): a soft light (core + halo); bright colours on dark backgrounds read best
function J.glow(x, y, r, color, a)
  if not J.tex.glow then return end
  gfx.alpha(a or 1)
  gfx.draw(J.tex.glow, x - r, y - r, r * 2, r * 2, 0, color)
  gfx.draw(J.tex.glow, x - r * 0.45, y - r * 0.45, r * 0.9, r * 0.9, 0, color)
  gfx.unalpha()
end
-- vignette(w, h[, strength 0..1[, colour]])
function J.vignette(w, h, strength, color)
  if not J.tex.vignette then return end
  gfx.alpha(strength or 0.5)
  gfx.draw(J.tex.vignette, -2, -2, w + 4, h + 4, 0, color)
  gfx.unalpha()
end
-- grain(w, h[, alpha]): moving film grain (subtle: 0.03-0.06)
function J.grain(w, h, a)
  if not J.tex.grain then return end
  local ox, oy = -rnd(0, 127), -rnd(0, 127)
  gfx.alpha(a or 0.04)
  for y = oy, h, 128 do
    for x = ox, w, 128 do gfx.draw(J.tex.grain, x, y, 128, 128) end
  end
  gfx.unalpha()
end
-- blob(x, y, w, h[, alpha]): soft contact shadow centred at x, y
function J.blob(x, y, w, h, a)
  if not J.tex.shadow then return end
  gfx.alpha(a or 0.6)
  gfx.draw(J.tex.shadow, x - w / 2, y - h / 2, w, h)
  gfx.unalpha()
end
-- rays(x, y, length, count, colour[, alpha[, t[, width]]]): light shafts fanning down from (x, y), slowly swaying
function J.rays(x, y, len, count, color, a, t, wd)
  if not J.tex.ray then return end
  t = t or 0
  gfx.alpha(a or 0.18)
  for i = 1, count do
    local f = (i - 0.5) / count
    local sway = sin(t * 0.4 + i * 1.7) * 18
    local rw = (wd or 60) * (0.6 + 0.4 * sin(i * 2.1) ^ 2)
    gfx.draw(J.tex.ray, x + (f - 0.5) * len * 0.8 + sway - rw / 2, y, rw, len * (0.7 + 0.3 * sin(i * 1.3) ^ 2), 0, color)
  end
  gfx.unalpha()
end

-- ------------------------------------------------------------------ flash and floaters
local flash = nil
-- flash(colour, seconds[, alpha]): full-screen colour that fades out (hits, pickups, level up)
function J.flash(color, sec, a) flash = {c = color, t = 0, sec = sec or 0.2, a = a or 0.6} end

local floaters = {}
-- floatText(text, x, y[, colour[, size]]): a number or word that pops up and drifts away (damage, +10)
function J.floatText(s, x, y, color, size)
  floaters[#floaters + 1] = {s = s, x = x, y = y, c = color or "#FFFFFF", size = size or 20, t = 0, life = 0.9,
    vx = (rnd() - 0.5) * 30}
end
function J.drawFloaters()
  for _, f in ipairs(floaters) do
    local p = f.t / f.life
    local pop = p < 0.15 and E.outBack(p / 0.15) or 1
    gfx.alpha(1 - smooth(0.6, 1, p))
    gfx.color("#00000088")
    gfx.text(f.s, f.x + 2, f.y - p * 40 + 2, f.size * pop, "bold", "center", 0)
    gfx.color(f.c)
    gfx.text(f.s, f.x, f.y - p * 40, f.size * pop, "bold", "center", 0)
    gfx.unalpha()
  end
end

-- ------------------------------------------------------------------ particles
local parts = {}
local MAXP = 600
local C = {0, 0, 0, 0}
-- presets: what each field means: n (count), speed {min, max}, angle (rad, nil = all around), spread, life {min,max},
-- size {start, end}, colors {start, end}, gravity, drag, kind ("glow" soft light, "dot" circle, "spark" streak,
-- "square", "ring" expanding outline), up (extra upward drift), flicker
J.presets = {
  sparks = {n = 18, speed = {180, 420}, life = {0.18, 0.45}, size = {3, 0}, colors = {"#FFF3B0", "#FF6B35"}, gravity = 600, drag = 2, kind = "spark"},
  embers = {n = 10, speed = {20, 70}, life = {0.8, 1.8}, size = {6, 0}, colors = {"#FFC145", "#FF3B1F00"}, gravity = -40, drag = 0.5, kind = "glow", flicker = true},
  dust = {n = 8, speed = {20, 60}, angle = -pi / 2, spread = pi, life = {0.4, 0.8}, size = {5, 12}, colors = {"#D8C3A0AA", "#D8C3A000"}, gravity = -20, drag = 3, kind = "dot"},
  smoke = {n = 8, speed = {10, 40}, life = {0.8, 1.6}, size = {10, 34}, colors = {"#55555588", "#22222200"}, gravity = -50, drag = 1, kind = "glow"},
  confetti = {n = 30, speed = {150, 380}, angle = -pi / 2, spread = 1.2, life = {0.9, 1.6}, size = {6, 4}, colors = {"#FF2E88", "#19E6FF"}, gravity = 500, drag = 1.5, kind = "square", multi = {"#FF2E88", "#19E6FF", "#FFD166", "#7AE7C7"}},
  magic = {n = 16, speed = {30, 120}, life = {0.5, 1.1}, size = {8, 0}, colors = {"#B388FF", "#19E6FF00"}, gravity = -60, drag = 1.5, kind = "glow", flicker = true},
  hit = {n = 1, speed = {0, 0}, life = {0.25, 0.25}, size = {6, 46}, colors = {"#FFFFFF", "#FFFFFF00"}, gravity = 0, drag = 0, kind = "ring"},
}
-- burst(x, y, preset name or table[, overrides]): adds particles (a ring of "hit" plus "sparks" reads as an impact)
function J.burst(x, y, preset, o)
  local P = type(preset) == "table" and preset or J.presets[preset] or J.presets.sparks
  local n = (o and o.n) or P.n
  for i = 1, n do
    if #parts >= MAXP then table.remove(parts, 1) end
    local ang = (o and o.angle) or P.angle
    local a = ang and (ang + (rnd() - 0.5) * ((o and o.spread) or P.spread or 0.6)) or rnd() * 2 * pi
    local sp = P.speed[1] + rnd() * (P.speed[2] - P.speed[1])
    local life = P.life[1] + rnd() * (P.life[2] - P.life[1])
    local c0 = P.colors[1]
    if P.multi then c0 = P.multi[rnd(1, #P.multi)] end
    parts[#parts + 1] = {x = x, y = y, vx = cos(a) * sp, vy = sin(a) * sp, t = 0, life = life, s0 = P.size[1] * (0.7 + rnd() * 0.6),
      s1 = P.size[2], c0 = c0, c1 = P.multi and c0 or P.colors[2], g = P.gravity or 0, drag = P.drag or 0, kind = P.kind,
      flicker = P.flicker, ph = rnd() * 10}
  end
end
function J.drawParticles()
  for _, p in ipairs(parts) do
    local k = p.t / p.life
    local s = p.s0 + (p.s1 - p.s0) * k
    J.mixInto(C, p.c0, p.c1, k)
    if p.c0 == p.c1 then C[4] = floor(C[4] * (1 - k)) end
    if p.flicker then C[4] = floor(C[4] * (0.65 + 0.35 * sin(p.ph + p.t * 30))) end
    if p.kind == "glow" and J.tex.glow then
      gfx.draw(J.tex.glow, p.x - s * 2, p.y - s * 2, s * 4, s * 4, 0, C)
    elseif p.kind == "spark" then
      gfx.color(C)
      gfx.line(p.x, p.y, p.x - p.vx * 0.03, p.y - p.vy * 0.03, max(1, s))
    elseif p.kind == "square" then
      gfx.color(C)
      local w = s * (0.4 + 0.6 * abs(sin(p.ph + p.t * 9)))   -- flipping paper
      gfx.rect(p.x - w / 2, p.y - s / 2, w, s, 0)
    elseif p.kind == "ring" then
      gfx.color(C)
      gfx.circleLine(p.x, p.y, s, max(1, 4 * (1 - k)))
    else
      gfx.color(C)
      gfx.circle(p.x, p.y, max(0.5, s / 2))
    end
  end
end
function J.particleCount() return #parts end
function J.clearParticles() parts = {} end

-- ------------------------------------------------------------------ typography
-- scale(base, ratio): a type scale; use 3-4 of its steps, not ten sizes
function J.scale(base, ratio)
  base, ratio = base or 16, ratio or 1.333
  return {xs = base / ratio / ratio, sm = base / ratio, md = base, lg = base * ratio, xl = base * ratio ^ 2,
    xxl = base * ratio ^ 3, display = base * ratio ^ 5}
end
-- spacedWidth / spaced: text with letter spacing (tracking) in pixels; align within w
function J.spacedWidth(s, size, font, sp)
  local w, n = 0, 0
  for ch in s:gmatch(utf8.charpattern) do
    w = w + gfx.textWidth(ch, size, font)
    n = n + 1
  end
  return w + max(0, n - 1) * sp
end
function J.spaced(s, x, y, size, font, sp, align, w)
  local tw = J.spacedWidth(s, size, font, sp)
  if align == "center" then x = x + ((w or 0) - tw) / 2 elseif align == "right" then x = x + (w or 0) - tw end
  for ch in s:gmatch(utf8.charpattern) do
    gfx.text(ch, x, y, size, font)
    x = x + gfx.textWidth(ch, size, font) + sp
  end
  return tw
end
-- fit(text, maxWidth, size[, font[, minSize]]) -> a size at which the text fits (translations are longer)
function J.fit(s, maxW, size, font, minSize)
  local w = gfx.textWidth(s, size, font)
  if w <= maxW then return size end
  return max(minSize or 10, size * maxW / w)
end
-- title(text, x, y, size, {font, fill, fill2, outline, outlineW, shadow, shadowY, glow, spacing, align, w, bands})
-- fill2 gives a two-tone vertical gradient (the text is drawn in horizontal bands); x is the left edge, or the
-- left edge of the box `w` when align is "center" / "right".
function J.title(s, x, y, size, o)
  o = o or {}
  local font = o.font or "bold"
  local sp = o.spacing or size * 0.04
  local tw = J.spacedWidth(s, size, font, sp)
  local th = gfx.textHeight(size, font)
  local lx = x
  if o.align == "center" then lx = x + ((o.w or 0) - tw) / 2 elseif o.align == "right" then lx = x + (o.w or 0) - tw end
  local function put(dx, dy) J.spaced(s, lx + dx, y + dy, size, font, sp) end
  if o.glow then J.glow(lx + tw / 2, y + th / 2, max(tw, th) * 0.75, o.glow, o.glowAlpha or 0.5) end
  if o.shadow then
    local sy = o.shadowY or size * 0.08
    gfx.alpha(0.35); gfx.color(o.shadow); put(0, sy * 1.6); gfx.unalpha()
    gfx.color(o.shadow); put(0, sy)
  end
  if o.outline then
    local ow = o.outlineW or max(1, size * 0.05)
    gfx.color(o.outline)
    for i = 0, 7 do
      local a = i * pi / 4
      put(cos(a) * ow, sin(a) * ow)
    end
  end
  local fill = o.fill or "#FFFFFF"
  if o.fill2 then
    local n = o.bands or 10
    local top = y + th * 0.18
    local hgt = th * 0.7
    for i = 0, n - 1 do
      local y0 = i == 0 and y - size or top + hgt * i / n
      local y1 = i == n - 1 and y + th + size or top + hgt * (i + 1) / n
      gfx.clip(lx - size, y0, tw + size * 2, y1 - y0)
      gfx.color(J.mix(fill, o.fill2, i / (n - 1)))
      put(0, 0)
      gfx.unclip()
    end
  else
    gfx.color(fill)
    put(0, 0)
  end
  return tw, th
end

-- ------------------------------------------------------------------ panels
-- shape(x, y, w, h, shape, cut) -> points of a convex polygon: "cut" (corners cut), "slant" (parallelogram),
-- "tab" (one corner cut); nil for "round" / "pill" (drawn with radii)
local function shapePts(x, y, w, h, shape, cut)
  if shape == "cut" then
    return {x + cut, y, x + w - cut, y, x + w, y + cut, x + w, y + h - cut, x + w - cut, y + h, x + cut, y + h, x, y + h - cut, x, y + cut}
  elseif shape == "slant" then
    return {x + cut, y, x + w, y, x + w - cut, y + h, x, y + h}
  elseif shape == "tab" then
    return {x, y, x + w - cut, y, x + w, y + cut, x + w, y + h, x, y + h}
  end
end
J.shapePoints = shapePts
-- panel(x, y, w, h, {shape = "round" | "pill" | "cut" | "slant" | "tab", r, cut, fill, fill2 (round / pill:
--   vertical gradient), border, borderW, shadow (alpha 0..1, or false), depth (px of a darker slab below),
--   depthColor, highlight (a light line along the top edge)})
function J.panel(x, y, w, h, o)
  o = o or {}
  local shape = o.shape or "round"
  local r = shape == "pill" and h / 2 or (o.r or 10)
  local cut = o.cut or min(h * 0.3, 16)
  local fill = o.fill or "#2A2A3A"
  local depth = o.depth or 0
  if o.shadow ~= false then
    gfx.alpha(o.shadow or 0.5)
    gfx.shadow(x, y + depth, w, h, (shape == "round" or shape == "pill") and r or 4, o.blur or 16, o.shadowY or 6)
    gfx.unalpha()
  end
  local pts = shapePts(x, y, w, h, shape, cut)
  if depth > 0 then
    local dc = o.depthColor or J.shade(fill, 0.55)
    if pts then gfx.poly(shapePts(x, y + depth, w, h, shape, cut), dc) else gfx.rect(x, y + depth, w, h, r, dc) end
  end
  if pts then
    gfx.poly(pts, fill)
    if o.highlight then
      gfx.color(o.highlight)
      gfx.line(pts[1], pts[2] + 1, pts[3], pts[4] + 1, 1.5)
    end
    if o.border then
      gfx.color(o.border)
      gfx.lines(pts, o.borderW or 2, true)
    end
  else
    if o.fill2 then gfx.gradient(x, y, w, h, fill, o.fill2, false, r) else gfx.rect(x, y, w, h, r, fill) end
    if o.highlight then
      gfx.color(o.highlight)
      gfx.line(x + r, y + 1.5, x + w - r, y + 1.5, 1.5)
    end
    if o.border then
      gfx.color(o.border)
      gfx.rectLine(x, y, w, h, r, o.borderW or 2)
    end
  end
end

-- ------------------------------------------------------------------ pointer and buttons
J.pointer = {x = -1, y = -1, down = false, pressed = false, released = false}
function J.event(e)
  local P = J.pointer
  if e.type == "mousemove" or e.type == "mousedown" or e.type == "mouseup" then
    P.x, P.y = e.x or P.x, e.y or P.y
  end
  if e.type == "mousedown" then P.down, P.pressed, P.downX, P.downY = true, true, P.x, P.y end
  if e.type == "mouseup" then P.down, P.released = false, not e.cancel end
end
local states = {}
-- onUi(kind) is called on "hover" and "press": set it to play your UI sounds, e.g.
--   J.onUi = function(kind) sfx.play(kind == "press" and "confirm" or "tick") end
J.onUi = nil
-- button(id, label, x, y, w, h[, {focused, activate, enabled, shape, fill, fillHover, ink, inkHover, border, size,
--   font, depth, glow}]) -> clicked, state. Hover lifts it, press sinks it into its depth, focus (controller) glows.
-- `activate` is true on the frame the player presses confirm while it is focused.
function J.button(id, label, x, y, w, h, o)
  o = o or {}
  local st = states[id]
  if not st then st = {hover = {x = 0, v = 0}, press = {x = 0, v = 0}, wasHover = false}; states[id] = st end
  local P = J.pointer
  local inside = P.x >= x and P.x <= x + w and P.y >= y and P.y <= y + h
  local enabled = o.enabled ~= false
  local hot = enabled and (inside or o.focused)
  if hot and not st.wasHover and J.onUi then J.onUi("hover") end
  st.wasHover = hot
  local clicked = false
  if enabled and ((P.released and inside and P.downX and P.downX >= x and P.downX <= x + w and P.downY >= y and P.downY <= y + h)
      or (o.focused and o.activate)) then
    clicked = true
    st.kick = 1
    if J.onUi then J.onUi("press") end
  end
  st.kick = max(0, (st.kick or 0) - 0.12)
  local dt = 1 / 60
  local hv = J.spring(st.hover, hot and 1 or 0, dt, 5, 0.55)
  local pr = J.spring(st.press, ((P.down and inside) or st.kick > 0.5) and 1 or 0, dt, 9, 0.7)
  local depth = o.depth or 5
  local lift = -hv * 2 + pr * depth
  local fill = enabled and J.mix(o.fill or "#2E2A4A", o.fillHover or o.fill or "#4B3F8C", clamp(hv, 0, 1)) or "#55555566"
  if o.glow and hv > 0.05 then J.glow(x + w / 2, y + h / 2 + lift, max(w, h) * 0.65, o.glow, 0.35 * clamp(hv, 0, 1)) end
  J.panel(x, y + lift, w, h, {shape = o.shape or "round", r = o.r, cut = o.cut, fill = fill, depth = max(0, depth - pr * depth),
    border = (o.focused and enabled) and (o.focusColor or "#FFFFFF") or o.border, borderW = 2, highlight = o.highlight or "#FFFFFF33",
    shadow = 0.35 + hv * 0.2})
  local size = o.size or h * 0.42
  local font = o.font or "semibold"
  gfx.color(enabled and J.mix(o.ink or "#E8E6FF", o.inkHover or o.ink or "#FFFFFF", clamp(hv, 0, 1)) or "#FFFFFF77")
  local th = gfx.textHeight(size, font)
  gfx.text(label, x, y + lift + (h - th) / 2, J.fit(label, w - 16, size, font), font, "center", w)
  return clicked, st
end
-- call at the end of app.draw (after every J.button) so a press counts once
function J.endFrame() J.pointer.pressed, J.pointer.released = false, false end

-- ------------------------------------------------------------------ transitions
local tr = nil
local pixelOrder = nil
-- transition(kind, seconds, onMiddle[, colour]): cover the screen, call onMiddle (switch screens), uncover.
-- kinds: "fade", "iris", "wipe", "blinds", "pixels"
function J.transition(kind, sec, mid, color)
  tr = {kind = kind or "fade", sec = sec or 0.5, t = 0, mid = mid, c = color or "#000000", called = false}
end
function J.transitioning() return tr ~= nil end
local function drawTransition(w, h)
  if not tr then return end
  local half = tr.sec / 2
  local p = tr.t < half and E.inOutCubic(tr.t / half) or E.inOutCubic(1 - (tr.t - half) / half)
  local k = tr.kind
  gfx.color(tr.c)
  if k == "iris" then
    local far = sqrt(w * w + h * h)
    gfx.circleLine(w / 2, h / 2, far * (1 - p) + far / 2, far)
  elseif k == "wipe" then
    local x = (w + h * 0.5 + 20) * p - 10
    if tr.t >= half then x = w + 10 - (w + h * 0.5 + 20) * (1 - p) end
    if tr.t < half then gfx.poly({-10, -10, x, -10, x - h * 0.5, h + 10, -10, h + 10}, tr.c)
    else gfx.poly({x, -10, w + 10, -10, w + 10, h + 10, x - h * 0.5, h + 10}, tr.c) end
  elseif k == "blinds" then
    local n = 8
    local bh = h / n
    for i = 0, n - 1 do
      local q = clamp(p * 1.6 - i / n * 0.6, 0, 1)
      gfx.rect(0, i * bh + bh * (1 - q) / 2, w, bh * q + 1, 0)
    end
  elseif k == "pixels" then
    local cs = max(16, floor(min(w, h) / 12))
    local cols, rows = math.ceil(w / cs), math.ceil(h / cs)
    if not pixelOrder or #pixelOrder ~= cols * rows then
      pixelOrder = {}
      for i = 1, cols * rows do pixelOrder[i] = rnd() end
    end
    for i = 1, cols * rows do
      if pixelOrder[i] < p then
        local cx, cy = (i - 1) % cols, floor((i - 1) / cols)
        gfx.rect(cx * cs, cy * cs, cs + 1, cs + 1, 0)
      end
    end
  else
    gfx.alpha(p)
    gfx.rect(0, 0, w, h, 0)
    gfx.unalpha()
  end
end
-- overlay(w, h): the flash and the transition; draw it last
function J.overlay(w, h)
  if flash then
    local k = 1 - flash.t / flash.sec
    gfx.alpha(flash.a * k * k)
    gfx.rect(0, 0, w, h, 0, flash.c)
    gfx.unalpha()
  end
  drawTransition(w, h)
end

-- ------------------------------------------------------------------ cameras
-- 2D: camera{x, y, lag (damping rate), lead (seconds of look-ahead), dead = {w, h}, bounds = {x, y, w, h}}
function J.camera(o)
  o = o or {}
  local cam = {x = o.x or 0, y = o.y or 0, lag = o.lag or 7, lead = o.lead or 0.25, dead = o.dead, bounds = o.bounds,
    lx = 0, ly = 0}
  -- follow(targetX, targetY, velocityX, velocityY, dt)
  function cam:follow(tx, ty, vx, vy, dt)
    self.lx = J.damp(self.lx, (vx or 0) * self.lead, 3, dt)
    self.ly = J.damp(self.ly, (vy or 0) * self.lead * 0.5, 3, dt)
    local gx, gy = tx + self.lx, ty + self.ly
    if self.dead then
      local dx, dy = gx - self.x, gy - self.y
      local hw, hh = self.dead.w / 2, self.dead.h / 2
      gx = abs(dx) > hw and gx - (dx > 0 and hw or -hw) or self.x
      gy = abs(dy) > hh and gy - (dy > 0 and hh or -hh) or self.y
    end
    self.x = J.damp(self.x, gx, self.lag, dt)
    self.y = J.damp(self.y, gy, self.lag, dt)
  end
  -- offset(w, h[, shakePx]) -> dx, dy for gfx.push: world point (x, y) lands in the centre of the screen
  function cam:offset(w, h, shakePx)
    local x, y = self.x, self.y
    local b = self.bounds
    if b then
      x = clamp(x, b.x + w / 2, max(b.x + w / 2, b.x + b.w - w / 2))
      y = clamp(y, b.y + h / 2, max(b.y + h / 2, b.y + b.h - h / 2))
    end
    local sx, sy = J.shakeOffset(shakePx or 12)
    return floor(w / 2 - x + sx + 0.5), floor(h / 2 - y + sy + 0.5)
  end
  return cam
end

-- 3D follow camera: cam3d{dist, height, lookHeight, lag, fov}; follow(x, y, z, yaw, dt); apply() calls g3d.camera
function J.cam3d(o)
  o = o or {}
  local cam = {dist = o.dist or 6, height = o.height or 3, look = o.lookHeight or 1, lag = o.lag or 6, fov0 = o.fov or 55,
    kickV = 0, ex = 0, ey = 0, ez = 0, tx = 0, ty = 0, tz = 0, yaw = 0, init = false}
  function cam:follow(x, y, z, yaw, dt)
    if not self.init then
      self.yaw, self.tx, self.ty, self.tz, self.init = yaw, x, y, z, true
    end
    local dy = (yaw - self.yaw + pi) % (2 * pi) - pi       -- shortest way round
    self.yaw = self.yaw + dy * (1 - exp(-self.lag * 0.5 * dt))
    self.tx = J.damp(self.tx, x, self.lag, dt)
    self.ty = J.damp(self.ty, y, self.lag, dt)
    self.tz = J.damp(self.tz, z, self.lag, dt)
    self.kickV = J.damp(self.kickV, 0, 6, dt)
  end
  -- kick(degrees): widen the field of view for a moment (dash, boost, big hit)
  function cam:kick(deg) self.kickV = self.kickV + deg end
  function cam:fov() return self.fov0 + self.kickV end
  function cam:apply()
    local sx, sy = J.shakeOffset(0.25)
    self.ex = self.tx - math.sin(self.yaw) * self.dist
    self.ez = self.tz - math.cos(self.yaw) * self.dist
    self.ey = self.ty + self.height
    g3d.camera(self.ex + sx, self.ey + sy, self.ez, self.tx, self.ty + self.look, self.tz)
  end
  return cam
end

-- 3D looks: sky gradient, horizon, fog, light direction, ambient and light colour, a glow accent
J.looks = {
  dusk = {top = "#1B1036", horizon = "#FF7B54", bottom = "#2A1630", fog = "#5B2A4A", light = {-0.4, 0.5, 0.6}, ambient = 0.35, color = "#FFD2A8", glow = "#FFB070"},
  noon = {top = "#3A86FF", horizon = "#CDE7FF", bottom = "#9CC9FF", fog = "#BFDFFF", light = {0.3, 1, 0.4}, ambient = 0.45, color = "#FFFFFF", glow = "#FFF6C2"},
  night = {top = "#02040F", horizon = "#16315C", bottom = "#050A18", fog = "#0B1730", light = {0.2, 0.8, -0.5}, ambient = 0.22, color = "#9DB8FF", glow = "#7CC4FF"},
  toxic = {top = "#0B140B", horizon = "#6BFF3A", bottom = "#102010", fog = "#1F3A1A", light = {0.4, 0.7, 0.2}, ambient = 0.3, color = "#D8FFB0", glow = "#9DFF3A"},
  frost = {top = "#0B2545", horizon = "#BEE9FF", bottom = "#13315C", fog = "#8DB8D9", light = {-0.3, 0.9, 0.3}, ambient = 0.5, color = "#E8F6FF", glow = "#5CE1E6"},
  desert = {top = "#F28C28", horizon = "#FFE0A3", bottom = "#E7B072", fog = "#F2C48D", light = {0.6, 0.8, 0.2}, ambient = 0.45, color = "#FFF1D6", glow = "#FFD27A"},
  abyss = {top = "#000814", horizon = "#00507A", bottom = "#001D3D", fog = "#003049", light = {0, 1, 0.2}, ambient = 0.3, color = "#7FDBFF", glow = "#48CAE4"},
  synth = {top = "#0B0221", horizon = "#FF2E88", bottom = "#1D0B45", fog = "#3B0A45", light = {0.3, 0.6, 0.6}, ambient = 0.3, color = "#FFC2E2", glow = "#19E6FF"},
}
-- sky(w, h, look[, horizonY 0..1]): background for a 3D scene (draw before g3d.begin)
function J.sky(w, h, look, hz)
  hz = hz or 0.55
  gfx.gradient(0, 0, w, floor(h * hz) + 1, look.top, look.horizon)
  gfx.gradient(0, floor(h * hz), w, h - floor(h * hz), look.horizon, look.bottom)
  J.glow(w * 0.5, h * hz, w * 0.35, look.glow, 0.35)
end
-- light3d(look[, far]): g3d.light + g3d.fog for the look (fog from 35 % to 100 % of far); call after g3d.begin
function J.light3d(look, far)
  local l = look.light
  g3d.light(l[1], l[2], l[3], look.ambient, look.color)
  g3d.fog(look.fog, (far or 40) * 0.35, far or 40)
end

-- ------------------------------------------------------------------ update
function J.update(dt)
  shakeT = shakeT + dt
  trauma = max(0, trauma - dt * 1.4)
  if freeze > 0 then freeze = freeze - dt end
  if slowLeft > 0 then slowLeft = slowLeft - dt end
  updateTweens(dt)
  if flash then
    flash.t = flash.t + dt
    if flash.t >= flash.sec then flash = nil end
  end
  if tr then
    tr.t = tr.t + dt
    if not tr.called and tr.t >= tr.sec / 2 then
      tr.called = true
      if tr.mid then tr.mid() end
    end
    if tr.t >= tr.sec then tr = nil end
  end
  for i = #parts, 1, -1 do
    local p = parts[i]
    p.t = p.t + dt
    if p.t >= p.life then
      table.remove(parts, i)
    else
      local d = exp(-p.drag * dt)
      p.vx, p.vy = p.vx * d, p.vy * d + p.g * dt
      p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
    end
  end
  for i = #floaters, 1, -1 do
    local f = floaters[i]
    f.t = f.t + dt
    f.x = f.x + f.vx * dt
    if f.t >= f.life then table.remove(floaters, i) end
  end
end

return J
