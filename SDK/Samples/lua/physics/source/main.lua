-- Physics demo: Verlet ropes, a rope bridge and a tearable cloth that you can grab, cut and pin.
--
-- What this file teaches:
--   1. Verlet integration: a point stores where it is and where it was; the difference is its velocity
--   2. distance constraints solved by relaxation (a few passes per step), with inverse masses
--      (0 = pinned, small = heavy) so heavy weights pull the light rope and not the other way round
--   3. tearing (a constraint stretched too far breaks) and cutting (a drag line crossing a link breaks it)
--   4. picking: grab the nearest point under the finger and move it with the pointer
--   5. cheap drawing: plain arrays instead of objects, one reused table for every triangle
-- The engine (nexvyn.game) provides the fixed 60 Hz step, the virtual screen, pointer input and buttons;
-- the physics is our own code.

local game = require("nexvyn.game")
local G, I, U = game.gfx, game.input, game.ui
local sqrt, min, max, floor, sin, abs = math.sqrt, math.min, math.max, math.floor, math.sin, math.abs

local BAR = 30
local GRAVITY = 700
local ITERATIONS = 6       -- more passes = stiffer links, more work

-- ------------------------------------------------------------------ 1. the simulation data
-- Struct of arrays: point i is x[i], y[i] (now), ox[i], oy[i] (previous step), im[i] (inverse mass).
local S

local function newSim()
  return {n = 0, x = {}, y = {}, ox = {}, oy = {}, im = {}, r = {},
          cn = 0, ca = {}, cb = {}, len = {}, on = {}, tear = {},   -- constraints (links)
          cells = {}, cellN = 0, cols = 0}                          -- cloth cells for drawing
end

local function point(x, y, im, radius)
  local s = S
  local i = s.n + 1
  s.n = i
  s.x[i], s.y[i], s.ox[i], s.oy[i], s.im[i], s.r[i] = x, y, x, y, im or 1, radius or 0
  return i
end

local function link(a, b, tearable)
  local s = S
  local c = s.cn + 1
  s.cn = c
  local dx, dy = s.x[b] - s.x[a], s.y[b] - s.y[a]
  s.ca[c], s.cb[c], s.len[c], s.on[c], s.tear[c] = a, b, sqrt(dx * dx + dy * dy), true, tearable or false
  return c
end

-- ------------------------------------------------------------------ the three scenes
local BUILD = {}

function BUILD.cloth(W, H)
  local cols, rows = 30, 16
  local sp = min((W - 60) / (cols - 1), (H - BAR * 2 - 40) / (rows - 1))
  local x0 = (W - sp * (cols - 1)) / 2
  local idx = {}
  for r = 0, rows - 1 do
    for c = 0, cols - 1 do
      -- pin every third point of the top row, like a curtain on hooks
      local pinned = r == 0 and (c % 3 == 0 or c == cols - 1)
      idx[r * cols + c] = point(x0 + c * sp, BAR + 24 + r * sp, pinned and 0 or 1)
    end
  end
  -- links, and per cell the 4 corners plus the 4 links around it (a cell is drawn while all 4 links hold)
  local right, down = {}, {}
  for r = 0, rows - 1 do
    for c = 0, cols - 1 do
      local i = idx[r * cols + c]
      if c < cols - 1 then right[r * cols + c] = link(i, idx[r * cols + c + 1], true) end
      if r < rows - 1 then down[r * cols + c] = link(i, idx[(r + 1) * cols + c], true) end
    end
  end
  local cells = S.cells
  for r = 0, rows - 2 do
    for c = 0, cols - 2 do
      local k = r * cols + c
      local n = S.cellN
      cells[n + 1], cells[n + 2] = idx[k], idx[k + 1]
      cells[n + 3], cells[n + 4] = idx[k + cols + 1], idx[k + cols]
      cells[n + 5], cells[n + 6] = right[k], down[k + 1]
      cells[n + 7], cells[n + 8] = right[k + cols], down[k]
      cells[n + 9] = r                                  -- row, for the stripes
      S.cellN = n + 9
    end
  end
end

function BUILD.ropes(W, H)
  local count = 6
  for k = 1, count do
    local ax = W * (k / (count + 1))
    local segs = 8 + k * 2
    local seg = (H - BAR * 2 - 60) / 22
    local prev = point(ax, BAR + 6, 0)
    for s = 1, segs do
      local last = s == segs
      -- the last point is a weight: inverse mass 0.1 means ten times heavier than a rope point
      local p = point(ax + s * 2, BAR + 6 + s * seg, last and 0.1 or 1, last and (7 + k) or 0)
      link(prev, p, false)
      prev = p
    end
  end
end

function BUILD.bridge(W, H)
  local y = H * 0.5
  local x0, x1 = 40, W - 40
  local n = 22
  local sp = (x1 - x0) / n * 1.04               -- 4 % slack, so it sags
  local top, deck = {}, {}
  for i = 0, n do
    local pin = i == 0 or i == n
    deck[i] = point(x0 + i * (x1 - x0) / n, y, pin and 0 or 0.6)
    top[i] = point(x0 + i * (x1 - x0) / n, y - 34, pin and 0 or 1)
    if i > 0 then
      link(deck[i - 1], deck[i], false)
      link(top[i - 1], top[i], false)
      S.len[S.cn - 1], S.len[S.cn] = sp, sp
    end
    if i > 0 and i < n then link(top[i], deck[i], false) end   -- hangers
  end
  -- three lanterns hanging under the deck
  for k = 1, 3 do
    local d = deck[floor(n * k / 4)]
    local prev = d
    for s = 1, 4 do
      local last = s == 4
      local p = point(S.x[d], S.y[d] + s * 10, last and 0.3 or 1, last and 6 or 0)
      link(prev, p, false)
      prev = p
    end
  end
  S.posts = {x0, x1, y}
end

local SCENES = {"cloth", "ropes", "bridge"}

-- ------------------------------------------------------------------ 2. one simulation step
local function step(dt, W, H, wind, tearOn)
  local s = S
  local x, y, ox, oy, im, r = s.x, s.y, s.ox, s.oy, s.im, s.r
  local gdt = GRAVITY * dt * dt
  local windX = wind and (40 + sin(game.time * 1.7) * 35 + sin(game.time * 5.3) * 15) * dt * dt or 0
  local top, bottom = BAR, H - BAR
  -- integrate: new = now + (now - previous) * damping + acceleration * dt^2
  for i = 1, s.n do
    if im[i] > 0 then
      local px, py = x[i], y[i]
      local vx, vy = (px - ox[i]) * 0.995, (py - oy[i]) * 0.995
      ox[i], oy[i] = px, py
      x[i] = px + vx + windX * (0.6 + 0.4 * sin(py * 0.05 + game.time * 3))
      y[i] = py + vy + gdt
    end
  end
  -- relax the links; then keep the points inside the window (the floor has friction)
  local ca, cb, len, on, tear = s.ca, s.cb, s.len, s.on, s.tear
  for _ = 1, ITERATIONS do
    for c = 1, s.cn do
      if on[c] then
        local a, b = ca[c], cb[c]
        local dx, dy = x[b] - x[a], y[b] - y[a]
        local d = sqrt(dx * dx + dy * dy)
        local wa, wb = im[a], im[b]
        local wsum = wa + wb
        if d > 0.0001 and wsum > 0 then
          if tearOn and tear[c] and d > len[c] * 2.6 then
            on[c] = false                                  -- 3. torn
          else
            local k = (d - len[c]) / (d * wsum)
            x[a], y[a] = x[a] + dx * k * wa, y[a] + dy * k * wa
            x[b], y[b] = x[b] - dx * k * wb, y[b] - dy * k * wb
          end
        end
      end
    end
  end
  for i = 1, s.n do
    if im[i] > 0 then
      local rad = r[i]
      if y[i] > bottom - rad then
        y[i] = bottom - rad
        ox[i] = x[i] - (x[i] - ox[i]) * 0.6               -- friction on the floor
      elseif y[i] < top + rad then y[i] = top + rad end
      if x[i] < rad then x[i] = rad elseif x[i] > W - rad then x[i] = W - rad end
    end
  end
end

-- does segment p1-p2 cross segment p3-p4?
local function crosses(x1, y1, x2, y2, x3, y3, x4, y4)
  local d = (x2 - x1) * (y4 - y3) - (y2 - y1) * (x4 - x3)
  if d == 0 then return false end
  local t = ((x3 - x1) * (y4 - y3) - (y3 - y1) * (x4 - x3)) / d
  local u = ((x3 - x1) * (y2 - y1) - (y3 - y1) * (x2 - x1)) / d
  return t >= 0 and t <= 1 and u >= 0 and u <= 1
end

-- ------------------------------------------------------------------ the scene
local Play = {}
local TOOLS = {"tool_drag", "tool_cut", "tool_pin"}

function Play:build(i)
  self.sceneIndex = i or self.sceneIndex or 1
  S = newSim()
  self.builtW, self.builtH = game.width, game.height
  BUILD[SCENES[self.sceneIndex]](game.width, game.height)
  self.grab, self.cutX = nil, nil
end

function Play:enter()
  self.tool, self.wind, self.tearOn = 1, false, true
  self:build(store.get("scene", 1))
end
function Play:restart() self:build() end

local function nearestPoint(px, py, radius)
  local best, bd = nil, radius * radius
  for i = 1, S.n do
    local dx, dy = S.x[i] - px, S.y[i] - py
    local d = dx * dx + dy * dy
    if d < bd then best, bd = i, d end
  end
  return best
end

function Play:update(dt)
  local W, H = game.width, game.height
  -- rebuild when the window size changed a lot, so the scene always fits
  if abs(W - self.builtW) > 40 or abs(H - self.builtH) > 40 then self:build() end
  local p = I.pointer
  local inField = p.downY > BAR and p.downY < H - BAR
  if p.pressed and inField then
    if self.tool == 1 then
      self.grab = nearestPoint(p.x, p.y, 22)
      if self.grab then
        self.grabIm = S.im[self.grab]
        S.im[self.grab] = 0                     -- 4. a held point acts as pinned: links pull on the rest
      end
    elseif self.tool == 2 then
      self.cutX, self.cutY = p.x, p.y
    else
      local i = nearestPoint(p.x, p.y, 22)      -- pin tool: toggle a point between pinned and free
      if i then
        S.im[i] = S.im[i] == 0 and 1 or 0
        audio.tone(S.im[i] == 0 and 660 or 440, 0.06, 0.25, "square")
      end
    end
  end
  if p.down and self.grab then
    local g = self.grab
    S.x[g], S.y[g] = p.x, max(BAR, min(H - BAR, p.y))
    S.ox[g], S.oy[g] = S.x[g], S.y[g]
  end
  if p.down and self.cutX then
    -- 3. cut every link crossed by the pointer's path since the last step
    local cut = 0
    for c = 1, S.cn do
      if S.on[c] then
        local a, b = S.ca[c], S.cb[c]
        if crosses(self.cutX, self.cutY, p.x, p.y, S.x[a], S.y[a], S.x[b], S.y[b]) then
          S.on[c] = false
          cut = cut + 1
        end
      end
    end
    if cut > 0 then audio.tone(1400 + cut * 40, 0.03, 0.15, "noise") end
    self.cutX, self.cutY = p.x, p.y
  end
  if p.released or not p.down then
    if self.grab then
      -- let go: give the point its mass back; its old position keeps the throw velocity
      S.im[self.grab] = self.grabIm
      self.grab = nil
    end
    self.cutX = nil
  end
  step(dt, W, H, self.wind, self.tearOn)
end

-- ------------------------------------------------------------------ 5. drawing
local tri = {0, 0, 0, 0, 0, 0}                  -- reused for every triangle: no garbage per frame
local STRIPES = {{232, 72, 85}, {245, 245, 240}, {58, 110, 165}}

function Play:draw()
  local W, H = game.width, game.height
  G.gradient(0, 0, W, H, "#1D2B44", "#0E1422")
  G.rect(0, H - BAR - 2, W, 2, 0, "#FFFFFF20")
  local s = S
  local x, y, on = s.x, s.y, s.on
  -- cloth cells as two triangles each, shaded by how much the cell is stretched
  local cells = s.cells
  for k = 1, s.cellN, 9 do
    if on[cells[k + 4]] and on[cells[k + 5]] and on[cells[k + 6]] and on[cells[k + 7]] then
      local a, b, c, d = cells[k], cells[k + 1], cells[k + 2], cells[k + 3]
      local col = STRIPES[floor(cells[k + 8] / 3) % 3 + 1]
      local diag = abs(x[c] - x[a]) + abs(y[c] - y[a])
      local shade = max(0.55, min(1.15, 1.25 - diag * 0.012))
      gfx.color(min(255, floor(col[1] * shade)), min(255, floor(col[2] * shade)), min(255, floor(col[3] * shade)))
      tri[1], tri[2], tri[3], tri[4], tri[5], tri[6] = x[a], y[a], x[b], y[b], x[c], y[c]
      G.poly(tri)
      tri[3], tri[4] = x[d], y[d]
      G.poly(tri)
    end
  end
  -- links that are not part of a cloth cell: ropes and the bridge
  if s.cellN == 0 then
    G.color("#D8C3A5")
    local ca, cb = s.ca, s.cb
    for c = 1, s.cn do
      if on[c] then G.line(x[ca[c]], y[ca[c]], x[cb[c]], y[cb[c]], 2) end
    end
  end
  if s.posts then
    G.rect(s.posts[1] - 8, s.posts[3] - 40, 8, H - BAR - s.posts[3] + 40, 2, "#6B4F3A")
    G.rect(s.posts[2], s.posts[3] - 40, 8, H - BAR - s.posts[3] + 40, 2, "#6B4F3A")
  end
  -- weights, pinned points and the grabbed point
  for i = 1, s.n do
    if s.r[i] > 0 then
      G.circle(x[i], y[i], s.r[i], "#FFB347")
      G.circle(x[i] - s.r[i] * 0.3, y[i] - s.r[i] * 0.3, s.r[i] * 0.35, "#FFE2B0")
    elseif s.im[i] == 0 then
      G.circle(x[i], y[i], 2.5, "#9FD0FF")
    end
  end
  if self.grab then
    G.color("#FFFFFF")
    G.circleLine(x[self.grab], y[self.grab], 8, 1.5)
  end
end

function Play:ui()
  local W, H = game.width, game.height
  G.rect(0, 0, W, BAR, 0, "#00000080")
  local bw = min(90, (W - 24) / 3)
  for i, name in ipairs(SCENES) do
    if U.button(TR(name), 8 + (i - 1) * (bw + 4), 5, bw, 20, self.sceneIndex == i) then
      store.set("scene", i)
      self:build(i)
    end
  end
  G.rect(0, H - BAR, W, BAR, 0, "#00000080")
  local tw = min(80, (W - 40) / 6)
  for i, name in ipairs(TOOLS) do
    if U.button(TR(name), 8 + (i - 1) * (tw + 4), H - BAR + 5, tw, 20, self.tool == i) then self.tool = i end
  end
  local x = 8 + 3 * (tw + 4) + 8
  if U.button(TR("wind"), x, H - BAR + 5, tw, 20, self.wind) then self.wind = not self.wind end
  if U.button(TR("tear"), x + tw + 4, H - BAR + 5, tw, 20, self.tearOn) then self.tearOn = not self.tearOn end
  if U.button(TR("reset"), x + 2 * (tw + 4), H - BAR + 5, tw, 20) then self:build() end
  local alive = 0
  for c = 1, S.cn do if S.on[c] then alive = alive + 1 end end
  U.text(TR("stats", S.n, alive, floor(sys.fps() + 0.5)), 8, BAR + 5, 9, "#FFFFFFA0", nil, nil, "semibold")
  if game.time < 6 then
    local hint = TR("hint")                     -- shrinks to fit narrow windows
    local size = min(10, 10 * (W - 16) / max(1, G.textWidth(hint, 10, "semibold")))
    U.text(hint, 0, H - BAR - 8 - size * 1.3, size, "#FFFFFFC8", "center", W, "semibold")
  end
end

function Play:event(e)
  if e.type == "keydown" then
    if e.key == "w" then self.wind = not self.wind end
    if e.key == "r" then self:build() end
    local k = tonumber(e.key)
    if k and TOOLS[k] then self.tool = k end
  end
end

return game.run{
  width = 480, height = 270, scale = "expand",
  gamepad = false,
  scene = Play,
  background = "#0E1422",
  menu = function()
    return {{title = TR("menu_title"), items = {
      {label = TR("reset"), id = 1, shortcut = "R"},
      {label = TR("wind"), id = 2, shortcut = "W"},
    }}}
  end,
  onmenu = function(id)
    if game.current() ~= Play then return end
    if id == 1 then Play:build() elseif id == 2 then Play.wind = not Play.wind end
  end,
}
