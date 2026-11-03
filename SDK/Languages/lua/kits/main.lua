-- Kit demo: the sound kit (sfx.lua) and the feel kit (juice.lua) working together. Run this folder as an app
-- (Studio: open the folder, Run; or copy it to sdmc:/NexvynOS/Applications/KitDemo.nxvapp/). Then copy sfx.lua and
-- juice.lua into your own game. This screen shows the blocks; it is not a menu to copy.
--
-- Art direction of this demo: "a forge at night". Warm and heavy. Palette ember (deep #140C1C, ink #FFE9D2,
-- accent #FF6B35, accent2 #FFC145). Bold capitals with tracking, a two-tone title with an outline and a glow.
-- Slanted panels with a dark slab under them. Snappy motion with a small overshoot. Sound: low thumps, bright
-- sparks, a dorian loop, wind and crackles.
local sfx = require("sfx")
local J = require("juice")

local app = {}
local P = J.palettes.ember
local t = 0
local sel = 1
local activate = false
local scene = "title"
local orb = {x = 0, y = 0, r = 40}
local hp = {x = 1}

function app.load()
  J.init()
  sfx.init()
  local R = sfx.recipes
  sfx.define("tick", R.ui{kind = "tick"}, {bus = "ui"})
  sfx.define("confirm", R.ui{kind = "confirm"}, {bus = "ui"})
  sfx.define("back", R.ui{kind = "back"}, {bus = "ui"})
  sfx.define("hit", R.impact{weight = 0.8, bright = 0.6}, {variants = 4, duck = {"music", 0.45, 0.2}})
  sfx.define("boom", R.explosion{size = 0.7}, {duck = {"music", 0.3, 0.6}})
  sfx.define("coin", R.coin(), {variants = 3})
  sfx.define("step", R.footstep{surface = "stone"}, {variants = 4, vol = 0.6})
  sfx.define("wind", R.ambience{kind = "wind"})
  sfx.define("crackle", R.detail{kind = "crackle"}, {bus = "amb"})
  sfx.song("theme", R.song{bpm = 92, root = "D3", scale = "dorian", chords = {1, 4, 6, 5}, drums = "half"}, {mode = "bars"})
  J.onUi = function(kind) sfx.play(kind == "press" and "confirm" or "tick") end
  sfx.ambience("wind", {details = {"crackle"}, every = {1.5, 4}})
  sfx.music("theme")
end

function app.update(dt)
  t = t + dt
  sfx.update(dt)
  J.update(dt)
  local gdt = J.dt(dt)
  hp.x = J.damp(hp.x, 1, 0.4, gdt)
end

local function hit(x, y, big)
  J.burst(x, y, "hit")
  J.burst(x, y, "sparks", {n = big and 34 or 16})
  J.shake(big and 0.7 or 0.35)
  J.hitstop(big and 0.09 or 0.04)
  J.flash(big and P.light or P.accent, big and 0.25 or 0.12, big and 0.5 or 0.25)
  sfx.play(big and "boom" or "hit")
  J.floatText(big and "999" or tostring(math.random(12, 48)), x, y - 30, P.accent2, big and 34 or 22)
  hp.x = math.max(0, hp.x - (big and 0.3 or 0.08))
end

local function drawBackground(w, h)
  J.gradient(0, 0, w, h, {P.deep, P.bg, P.mid})
  J.rays(w * 0.7, -20, h * 1.1, 5, P.accent2, 0.1, t, w * 0.08)
  J.glow(w * 0.5, h * 0.95, w * 0.5, P.accent, 0.35)
end

local function drawTitle(w, h)
  local s = math.floor(math.min(w * 0.11, h * 0.2))
  J.title(TR("title"), 0, h * 0.12 + math.sin(t * 1.3) * 3, s, {font = "bold", fill = P.light, fill2 = P.accent,
    outline = P.deep, outlineW = s * 0.06, shadow = "#00000099", glow = P.accent, align = "center", w = w, spacing = s * 0.08})
  gfx.color(P.ink)
  J.spaced(TR("tagline"), 0, h * 0.12 + s * 1.25, s * 0.2, "semibold", s * 0.05, "center", w)
  local items = {{"play", TR("play")}, {"sound", TR("sound")}, {"quit", TR("quit")}}
  local bw, bh = math.min(300, w * 0.4), math.max(44, h * 0.08)
  for i, item in ipairs(items) do
    local key = item[1]
    local x = w / 2 - bw / 2 + (i - 2) * 14
    local y = h * 0.52 + (i - 1) * (bh + 16)
    local clicked = J.button("menu" .. i, item[2],x, y, bw, bh, {shape = "slant", cut = bh * 0.4, fill = P.mid,
      fillHover = P.accent, ink = P.ink, inkHover = P.deep, focused = sel == i, activate = activate, glow = P.accent2,
      depth = 6, font = "bold"})
    if clicked then
      if key == "play" then J.transition("wipe", 0.6, function() scene = "play" end, P.deep)
      elseif key == "sound" then sfx.setBus("music", sfx.bus("music") > 0 and 0 or 0.55)
      else sys.exit() end
    end
  end
end

local function drawPlay(w, h)
  orb.x, orb.y = w / 2, h * 0.55
  J.blob(orb.x, orb.y + orb.r + 18, orb.r * 2.6, orb.r * 0.7, 0.7)
  J.glow(orb.x, orb.y, orb.r * 2.4, P.accent, 0.6 + 0.2 * math.sin(t * 3))
  gfx.circle(orb.x, orb.y, orb.r, P.accent2)
  gfx.circle(orb.x - orb.r * 0.3, orb.y - orb.r * 0.3, orb.r * 0.35, P.light)
  -- HUD: a slanted bar with a dark slab, the value eases instead of jumping
  J.panel(24, 24, 260, 26, {shape = "slant", cut = 12, fill = P.deep, depth = 4, shadow = 0.4})
  gfx.clip(30, 24, 248 * hp.x, 26)
  J.panel(24, 24, 260, 26, {shape = "slant", cut = 12, fill = P.accent, shadow = false, highlight = "#FFFFFF66"})
  gfx.unclip()
  gfx.color(P.ink)
  J.spaced(TR("hint"), 0, h - 48, 16, "semibold", 2, "center", w)
end

function app.draw(w, h)
  drawBackground(w, h)
  if not sfx.ready() then   -- first start: the sounds are being made (later starts load them from the data folder)
    local p = sfx.progress()
    J.panel(w / 2 - 160, h - 60, 320, 10, {shape = "pill", fill = P.deep, shadow = false})
    J.panel(w / 2 - 160, h - 60, 320 * p, 10, {shape = "pill", fill = P.accent2, shadow = false})
  end
  local sx, sy = J.shakeOffset(16)
  gfx.push(sx, sy)
  if scene == "title" then drawTitle(w, h) else drawPlay(w, h) end
  J.drawParticles()
  J.drawFloaters()
  gfx.pop()
  J.vignette(w, h, 0.6)
  J.grain(w, h, 0.035)
  J.overlay(w, h)
  J.endFrame()
  activate = false
end

function app.event(e)
  J.event(e)
  if e.type == "paddown" or e.type == "keydown" then
    local k = e.pad or e.key
    if scene == "title" then
      if k == "up" or k == "down" then
        sel = (sel - 1 + (k == "down" and 1 or -1)) % 3 + 1
      elseif k == "a" or k == "enter" or k == "space" then
        activate = true
      end
    else
      if k == "a" or k == "space" then hit(orb.x, orb.y, false)
      elseif k == "x" or k == "enter" then hit(orb.x, orb.y, true)
      elseif k == "y" then sfx.play("coin"); J.burst(orb.x, orb.y - orb.r, "embers")
      elseif k == "left" or k == "right" then sfx.play("step")
      elseif k == "b" or k == "escape" then
        sfx.play("back")
        J.transition("iris", 0.6, function() scene = "title" end, P.deep)
      end
    end
  elseif e.type == "mousedown" and scene == "play" then
    local dx, dy = (e.x or 0) - orb.x, (e.y or 0) - orb.y
    if dx * dx + dy * dy < orb.r * orb.r * 4 then hit(orb.x, orb.y, e.clicks == 2) end
  end
end

return app
