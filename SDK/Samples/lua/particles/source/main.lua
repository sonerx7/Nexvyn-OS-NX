-- Particles demo: game.emitter presets, gravity wells you place by touch, and bursts where you tap.
--
-- What this file teaches:
--   1. game.emitter options (rate, life, speed, angle, spread, gravity, damping, size, colors, shape, offset)
--   2. continuous emitters (rate + start/moveTo) versus bursts (emit(n, x, y))
--   3. adding your own forces: an emitter stores its particles in plain arrays (px, py, vx, vy, t, life),
--      so a loop over them can pull particles into gravity wells without creating any tables
--   4. pointer input in virtual units (game.input.pointer): tap, drag, and grabbing things
--   5. touch-friendly buttons (game.ui.button) laid out from game.width / game.height, so any window size works

local game = require("nexvyn.game")
local G, I, U = game.gfx, game.input, game.ui
local pi, sqrt, sin, cos, min, max, floor = math.pi, math.sqrt, math.sin, math.cos, math.min, math.max, math.floor
local random = math.random

-- ------------------------------------------------------------------ 1. presets
-- Every preset is a table of emitter options plus where its "ambient" source sits.
-- colors are interpolated over each particle's life; the last one usually has alpha 00 to fade out.
local PRESETS = {
  {key = "fire", source = "bottom", opts = {
    max = 700, rate = 220, life = {0.4, 1.0}, speed = {30, 100}, angle = -pi / 2, spread = 0.8, gravity = -140,
    damping = 1.2, size = {11, 2}, sizeVar = 0.4, offset = 8,
    colors = {"#FFF6C8", "#FFB547", "#FF5A1FB0", "#5A141400"}}},
  {key = "fountain", source = "bottom", opts = {
    max = 900, rate = 200, life = {1.3, 1.9}, speed = {200, 260}, angle = -pi / 2, spread = 0.32, gravity = 320,
    size = {4, 2}, colors = {"#E4FAFF", "#5CB8FF", "#2463FF00"}}},
  {key = "sparks", source = "center", opts = {
    max = 600, rate = 140, life = {0.3, 0.9}, speed = {140, 330}, spread = pi * 2, gravity = 260, damping = 1.4,
    shape = "line", lineScale = 0.045, size = {2.5, 1}, colors = {"#FFFFFF", "#FFD25E", "#FF5F1F00"}}},
  {key = "snow", source = "top", opts = {
    max = 600, rate = 70, life = {4, 6}, speed = {8, 28}, angle = pi / 2, spread = 1.2, gravity = 14, gravityX = 6,
    size = {4, 3}, sizeVar = 0.6, shape = "square", colors = {"#FFFFFF", "#DDEBFF", "#FFFFFF00"}}},
  {key = "magic", source = "orbit", opts = {
    max = 700, rate = 240, life = {0.6, 1.5}, speed = {4, 30}, spread = pi * 2, damping = 0.6,
    size = {7, 0}, sizeVar = 0.5, colors = {"#FFFFFF", "#D49BFF", "#5A6BFF80", "#20206000"}}},
}

-- tools for the pointer
local TOOLS = {{key = "tool_spawn"}, {key = "tool_attract"},
               {key = "tool_repel"}}

local BAR = 30            -- height of the top and bottom button bars (virtual units)
local WELL_POWER = 1.6e6  -- strength of a gravity well
local MAX_WELLS = 6

local Play = {}

-- creates the two emitters of a preset: the ambient source and the brush that follows the pointer
function Play:usePreset(i)
  self.preset = i
  local p = PRESETS[i]
  self.ambient = game.emitter(p.opts)
  self.ambient:start()
  self.brush = game.emitter(p.opts)            -- same look; it only emits while the pointer is held
  -- bursts get their own emitter so a big tap explosion never starves the stream of particles
  local burst = {}
  for k, v in pairs(p.opts) do burst[k] = v end
  burst.max, burst.rate, burst.spread = 900, 0, pi * 2
  self.burst = game.emitter(burst)
  self.emitters = {self.ambient, self.brush, self.burst}
end

function Play:enter()
  self.wells = {}
  self.tool = 1
  self.t = 0
  self:usePreset(1)
  self.grab = nil
end

-- ------------------------------------------------------------------ 3. gravity wells
-- a = power / distance^2, pointing to the well (or away from it for a negative power).
-- The +300 "softening" keeps the force finite in the middle; particles that reach an attracting well are absorbed:
-- setting t = life makes the emitter recycle them on its next update.
local function applyWells(em, wells, dt)
  local n = em.count
  if n == 0 then return end
  local px, py, vx, vy, t, life = em.px, em.py, em.vx, em.vy, em.t, em.life
  for w = 1, #wells do
    local well = wells[w]
    local wx, wy, k = well.x, well.y, well.power * dt
    for i = 1, n do
      local dx, dy = wx - px[i], wy - py[i]
      local d2 = dx * dx + dy * dy + 300
      local s = k / (d2 * sqrt(d2))               -- k / d^2, times the unit vector (dx, dy) / d
      vx[i], vy[i] = vx[i] + dx * s, vy[i] + dy * s
      if well.power > 0 and d2 < 340 then t[i] = life[i] end
    end
  end
end

-- ------------------------------------------------------------------ update
local function nearestWell(wells, x, y, radius)
  for i = #wells, 1, -1 do
    local w = wells[i]
    local dx, dy = w.x - x, w.y - y
    if dx * dx + dy * dy < radius * radius then return i end
  end
end

function Play:update(dt)
  self.t = self.t + dt
  local W, H = game.width, game.height

  -- 2. move the ambient source; snow uses a random point along the top edge every step
  local src = PRESETS[self.preset].source
  local amb = self.ambient
  if src == "bottom" then amb:moveTo(W / 2, H - BAR - 6)
  elseif src == "center" then amb:moveTo(W / 2, H / 2)
  elseif src == "top" then amb:moveTo(random() * W, BAR - 4)
  else amb:moveTo(W / 2 + cos(self.t * 1.3) * W * 0.25, H / 2 + sin(self.t * 2.1) * H * 0.18) end

  -- 4. pointer: press on a well to drag it; otherwise the current tool acts
  local p = I.pointer
  local inField = p.downY > BAR and p.downY < H - BAR      -- presses that started on a bar belong to the buttons
  if p.pressed and inField then
    self.grab = nearestWell(self.wells, p.x, p.y, 16)
    self.moved = false
    if not self.grab then
      if self.tool == 1 then
        self.burst:emit(60, p.x, p.y)                     -- tap: a burst in every direction
      elseif #self.wells < MAX_WELLS then
        self.wells[#self.wells + 1] = {x = p.x, y = p.y, power = self.tool == 2 and WELL_POWER or -WELL_POWER,
                                       born = self.t}
        audio.tone(self.tool == 2 and 330 or 520, 0.08, 0.25, "triangle")
      else
        game.toast(TR("wells_full", MAX_WELLS), 1.2)
      end
    end
  end
  if p.down and inField then
    if self.grab and self.wells[self.grab] then
      local w = self.wells[self.grab]
      if math.abs(p.x - w.x) + math.abs(p.y - w.y) > 1 then self.moved = true end
      w.x, w.y = p.x, max(BAR, min(H - BAR, p.y))
    elseif self.tool == 1 then
      self.brush:moveTo(p.x, p.y)                         -- drag: a stream that follows the finger
      self.brush.rate = PRESETS[self.preset].opts.rate * 1.5
      self.brush:start()
    end
  else
    self.brush:stop()
  end
  if p.released then
    -- tapping a well without moving it removes it
    if self.grab and not self.moved then table.remove(self.wells, self.grab) end
    self.grab = nil
  end

  -- physics: our forces first, then the emitters integrate and age their particles
  for _, em in ipairs(self.emitters) do
    applyWells(em, self.wells, dt)
    em:update(dt)
  end
end

-- ------------------------------------------------------------------ drawing
function Play:draw()
  local W, H = game.width, game.height
  G.gradient(0, 0, W, H, "#0B1020", "#1A1035")
  -- wells: pulsing rings, blue pulls in, orange pushes out
  for _, w in ipairs(self.wells) do
    local attract = w.power > 0
    local pulse = (self.t * (attract and -0.8 or 0.8)) % 1
    G.color(attract and "#4FA3FF" or "#FF9A4F")
    for k = 0, 2 do
      local f = (pulse + k / 3) % 1
      gfx.alpha(1 - f)
      G.circleLine(w.x, w.y, 6 + f * 34, 1.5)
      gfx.unalpha()
    end
    G.circle(w.x, w.y, 6, attract and "#0A1A40" or "#40200A")
    G.color(attract and "#9FD0FF" or "#FFD0A0")
    G.circleLine(w.x, w.y, 6, 2)
  end
  for _, em in ipairs(self.emitters) do em:draw() end
end

function Play:ui()
  local W, H = game.width, game.height
  -- top bar: presets
  G.rect(0, 0, W, BAR, 0, "#00000080")
  local n = #PRESETS
  local bw = min(84, (W - 16 - (n - 1) * 4) / n)
  for i, pr in ipairs(PRESETS) do
    local x = 8 + (i - 1) * (bw + 4)
    if U.button(TR(pr.key), x, 5, bw, 20, self.preset == i) then
      self:usePreset(i)
      audio.play("click")
    end
  end
  -- bottom bar: tools, clear, counter
  G.rect(0, H - BAR, W, BAR, 0, "#00000080")
  local tw = min(96, (W - 120) / 4)
  for i, tl in ipairs(TOOLS) do
    if U.button(TR(tl.key), 8 + (i - 1) * (tw + 4), H - BAR + 5, tw, 20, self.tool == i) then self.tool = i end
  end
  if U.button(TR("clear"), 8 + 3 * (tw + 4), H - BAR + 5, tw, 20) then
    self.wells = {}
    for _, em in ipairs(self.emitters) do em:clear() end
  end
  local count = 0
  for _, em in ipairs(self.emitters) do count = count + em.count end
  U.text(TR("stats", count, #self.wells, floor(sys.fps() + 0.5)), 8, BAR + 5, 9, "#FFFFFFB0", nil, nil, "semibold")
  if self.t < 6 then
    -- long sentences shrink to fit narrow windows instead of running off the edges
    local hint = TR("hint")
    local size = min(10, 10 * (W - 16) / max(1, G.textWidth(hint, 10, "semibold")))
    U.text(hint, 0, H - BAR - 8 - size * 1.3, size, "#FFFFFFC8", "center", W, "semibold")
  end
end

function Play:event(e)
  -- keyboard shortcuts: 1-5 presets, C clears
  if e.type == "keydown" then
    local k = tonumber(e.key)
    if k and PRESETS[k] then self:usePreset(k) end
    if e.key == "c" then self.wells = {} end
  end
end

return game.run{
  width = 480, height = 270, scale = "expand",
  gamepad = false,           -- matches app.json: the controller moves the system cursor, A taps
  scene = Play,
  background = "#0B1020",
  menu = function()
    return {{title = TR("menu_title"), items = {
      {label = TR("clear"), id = 1, shortcut = "C"},
      {label = TR("debug"), id = 2, shortcut = "F3"},
    }}}
  end,
  onmenu = function(id)
    local s = game.current()
    if id == 1 and s == Play then Play.wells = {} end
    if id == 2 then game.debug = not game.debug end
  end,
}
