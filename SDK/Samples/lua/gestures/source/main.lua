-- Gestures demo: pinch, rotate and two-finger pan on the touch screen, the motion sensors and HD rumble.
--
-- What this file teaches:
--   1. the "pinch" (e.scale), "rotate" (e.angle) and two-finger "scroll" (e.dx, e.dy) events, and how to zoom and
--      rotate around the point between the fingers so the picture stays under them
--   2. the same view with a mouse or controller: drag to pan, wheel to zoom, Q / E to rotate, double click resets
--   3. drawing a rotated, scaled picture with gfx.poly by transforming corner points yourself
--   4. input.motion(): acceleration (G), angular velocity (rad/s) and accumulated rotation, shown live
--   5. a tilt-controlled marble that bounces off the walls, with sys.vibrate strength from the impact speed,
--      and haptic "detents" every 45 degrees while rotating
-- (Two fingers do not arrive as two pointers: the system turns them into these gesture events.)

local app = {}
local sin, cos, sqrt, floor, min, max, abs, pi = math.sin, math.cos, math.sqrt, math.floor, math.min, math.max,
  math.abs, math.pi

local tab = 1
local view = {zoom = 1, angle = 0, panX = 0, panY = 0}     -- picture transform, centre of the canvas = origin
local stats = {pinch = 0, rotate = 0, pan = 0}
local focus = {x = 0, y = 0, t = -10}                      -- last gesture centre, for the finger marker
local drag = nil
local canvas = {x = 0, y = 0, w = 0, h = 0}
local lastDetent = 0

-- ------------------------------------------------------------------ 1. + 2. view changes around a point
-- screen point of a picture point (px, py)
local function toScreen(px, py)
  local c, s = cos(view.angle), sin(view.angle)
  local x, y = px * view.zoom, py * view.zoom
  return canvas.x + canvas.w / 2 + view.panX + x * c - y * s, canvas.y + canvas.h / 2 + view.panY + x * s + y * c
end

-- zoom by factor k keeping screen point (sx, sy) fixed
local function zoomAt(k, sx, sy)
  local nz = max(0.3, min(6, view.zoom * k))
  k = nz / view.zoom
  if k == 1 then return end
  local ox, oy = sx - canvas.x - canvas.w / 2, sy - canvas.y - canvas.h / 2
  view.panX = ox + (view.panX - ox) * k                    -- the vector from the fixed point grows by k
  view.panY = oy + (view.panY - oy) * k
  view.zoom = nz
  if nz == 0.3 or nz == 6 then sys.vibrate(0.4, 30) end   -- bump at the limits
end

-- rotate by a radians around screen point (sx, sy)
local function rotateAt(a, sx, sy)
  local ox, oy = sx - canvas.x - canvas.w / 2, sy - canvas.y - canvas.h / 2
  local dx, dy = view.panX - ox, view.panY - oy
  local c, s = cos(a), sin(a)
  view.panX, view.panY = ox + dx * c - dy * s, oy + dx * s + dy * c
  view.angle = view.angle + a
  -- 5. a light tick each time the picture passes a multiple of 45 degrees
  local detent = floor(view.angle / (pi / 4) + 0.5)
  if detent ~= lastDetent then
    lastDetent = detent
    sys.vibrate(0.25, 15)
  end
end

local function resetView()
  view.zoom, view.angle, view.panX, view.panY = 1, 0, 0, 0
  lastDetent = 0
end

-- ------------------------------------------------------------------ 4. + 5. the marble
local marble = {x = 0, y = 0, vx = 0, vy = 0, r = 16}
local arena = {w = 400, h = 300}                         -- size of the marble's box, set while drawing
local star = {x = 0.3, y = -0.2, got = 0}
local calib = {ax = 0, ay = 0}
local keys = {}
local motion = {0, 0, 0, 0, 0, 0, 0, 0, 0}
local hasMotion = false

local function placeStar()
  star.x, star.y = math.random() * 1.6 - 0.8, math.random() * 1.6 - 0.8
end

local function updateMarble(dt)
  local ax, ay, az, gx, gy, gz, pitch, roll, yaw = input.motion()
  motion[1], motion[2], motion[3], motion[4], motion[5], motion[6], motion[7], motion[8], motion[9] =
    ax, ay, az, gx, gy, gz, pitch, roll, yaw
  if abs(ax) + abs(ay) + abs(az) > 0.01 then hasMotion = true end
  -- tilt: acceleration minus the calibrated rest value. Keys and the left stick work too (no sensor on a PC).
  local tx, ty = (ax - calib.ax), -(ay - calib.ay)
  local sx, sy = input.stick("left")
  tx, ty = tx + sx, ty - sy
  if keys.left then tx = tx - 1 end
  if keys.right then tx = tx + 1 end
  if keys.up then ty = ty - 1 end
  if keys.down then ty = ty + 1 end
  local hw, hh = arena.w / 2 - marble.r - 8, arena.h / 2 - marble.r - 8
  marble.vx = (marble.vx + tx * 900 * dt) * (1 - 0.6 * dt)
  marble.vy = (marble.vy + ty * 900 * dt) * (1 - 0.6 * dt)
  marble.x, marble.y = marble.x + marble.vx * dt, marble.y + marble.vy * dt
  -- walls: bounce, and rumble as hard as the hit
  local hit = 0
  if marble.x < -hw then marble.x = -hw; hit = abs(marble.vx); marble.vx = -marble.vx * 0.55 end
  if marble.x > hw then marble.x = hw; hit = abs(marble.vx); marble.vx = -marble.vx * 0.55 end
  if marble.y < -hh then marble.y = -hh; hit = max(hit, abs(marble.vy)); marble.vy = -marble.vy * 0.55 end
  if marble.y > hh then marble.y = hh; hit = max(hit, abs(marble.vy)); marble.vy = -marble.vy * 0.55 end
  if hit > 60 then sys.vibrate(min(1, hit / 700), 25 + floor(min(60, hit / 12))) end
  -- the star
  local dx, dy = marble.x - star.x * hw, marble.y - star.y * hh
  if dx * dx + dy * dy < (marble.r + 14) ^ 2 then
    star.got = star.got + 1
    audio.play("pop")
    sys.vibrate(0.6, 60)
    placeStar()
  end
end

-- ------------------------------------------------------------------ input
function app.event(e)
  if e.type == "keydown" then keys[e.key] = true elseif e.type == "keyup" then keys[e.key] = nil end
  if tab ~= 1 then return end
  local inside = e.x and e.x >= canvas.x and e.y >= canvas.y and e.x < canvas.x + canvas.w and e.y < canvas.y + canvas.h
  if e.type == "pinch" then
    zoomAt(e.scale, e.x, e.y)
    stats.pinch = stats.pinch + 1
    focus.x, focus.y, focus.t = e.x, e.y, sys.time()
  elseif e.type == "rotate" then
    rotateAt(e.angle, e.x, e.y)
    stats.rotate = stats.rotate + 1
    focus.x, focus.y, focus.t = e.x, e.y, sys.time()
  elseif e.type == "scroll" then
    if e.touch then
      -- two-finger pan: dx/dy are scroll amounts, the opposite of the finger movement
      view.panX, view.panY = view.panX - e.dx, view.panY - e.dy
      stats.pan = stats.pan + 1
    elseif inside then
      zoomAt(e.dy < 0 and 1.12 or 1 / 1.12, e.x, e.y)     -- mouse wheel / right stick
    end
  elseif e.type == "mousedown" and inside and e.button == "left" then
    if e.clicks == 2 then resetView() else drag = {x = e.x, y = e.y} end
  elseif e.type == "mousemove" and drag then
    view.panX, view.panY = view.panX + e.x - drag.x, view.panY + e.y - drag.y
    drag.x, drag.y = e.x, e.y
  elseif e.type == "mouseup" then
    drag = nil
  elseif e.type == "keydown" then
    local cx, cy = canvas.x + canvas.w / 2, canvas.y + canvas.h / 2
    if e.key == "q" then rotateAt(-pi / 12, cx, cy) end
    if e.key == "e" then rotateAt(pi / 12, cx, cy) end
    if e.key == "z" then zoomAt(1.2, cx, cy) end
    if e.key == "x" then zoomAt(1 / 1.2, cx, cy) end
    if e.key == "r" then resetView() end
  end
end

function app.update(dt)
  if tab == 2 then updateMarble(min(dt, 0.05)) else input.motion() end
end

-- ------------------------------------------------------------------ 3. drawing the transformed picture
local quad = {0, 0, 0, 0, 0, 0, 0, 0}                    -- reused polygon table
local TILE = 40
local COLORS = {"#FF6B6B", "#FFB84D", "#FFE66D", "#6BCB77", "#4D96FF", "#9B72FF"}

local function polyLocal(pts, color)
  for i = 1, #pts, 2 do quad[i], quad[i + 1] = toScreen(pts[i], pts[i + 1]) end
  gfx.poly(quad, color)
end

local tilePts = {0, 0, 0, 0, 0, 0, 0, 0}
local function drawPicture()
  -- a 7 x 7 board of tiles: each tile's 4 corners go through toScreen
  for j = -3, 3 do
    for i = -3, 3 do
      local x0, y0 = i * TILE - TILE / 2 + 2, j * TILE - TILE / 2 + 2
      local x1, y1 = x0 + TILE - 4, y0 + TILE - 4
      tilePts[1], tilePts[2], tilePts[3], tilePts[4] = x0, y0, x1, y0
      tilePts[5], tilePts[6], tilePts[7], tilePts[8] = x1, y1, x0, y1
      polyLocal(tilePts, COLORS[(i + j * 3) % #COLORS + 1])
    end
  end
  -- a compass arrow so rotation is obvious
  local nx, ny = toScreen(0, -TILE * 2.6)
  local lx, ly = toScreen(-TILE * 0.5, -TILE * 1.2)
  local rx, ry = toScreen(TILE * 0.5, -TILE * 1.2)
  gfx.poly({nx, ny, rx, ry, lx, ly}, "#FFFFFF")
  local cx, cy = toScreen(0, 0)
  gfx.circle(cx, cy, 10 * view.zoom, "#1B1E2B")
  gfx.color("#FFFFFF")
  gfx.circleLine(cx, cy, 10 * view.zoom, 2)
end

local function drawGestures(w, h, t)
  gfx.rect(canvas.x, canvas.y, canvas.w, canvas.h, 14, "#1B1E2B")
  gfx.clip(canvas.x, canvas.y, canvas.w, canvas.h)
  drawPicture()
  -- where the fingers were for the last pinch / rotate, fading out
  local age = t - focus.t
  if age < 0.6 then
    gfx.alpha(1 - age / 0.6)
    gfx.color("#FFFFFF")
    gfx.circleLine(focus.x, focus.y, 20 + age * 30, 2)
    gfx.unalpha()
  end
  gfx.unclip()
  -- readout
  gfx.color(theme.text2)
  local deg = floor(((view.angle * 180 / pi) % 360) + 0.5)
  gfx.text(TR("view_info", string.format("%.2f", view.zoom), deg, floor(view.panX), floor(view.panY)),
           canvas.x, canvas.y + canvas.h + 8, 13, "mono")
  gfx.text(TR("event_info", stats.pinch, stats.rotate, stats.pan), canvas.x, canvas.y + canvas.h + 28, 13, "mono")
end

local function bar(x, y, w, label, v, range)
  gfx.color(theme.text2)
  gfx.text(label, x, y, 12, "mono")
  local bx, bw = x + 70, w - 140
  gfx.rect(bx, y + 3, bw, 10, 5, theme.separator)
  local f = max(-1, min(1, v / range))
  local mid = bx + bw / 2
  if f >= 0 then gfx.rect(mid, y + 3, bw / 2 * f, 10, 5, theme.accent)
  else gfx.rect(mid + bw / 2 * f, y + 3, -bw / 2 * f, 10, 5, theme.orange) end
  gfx.color(theme.text)
  gfx.text(string.format("%6.2f", v), 0, y, 12, "mono", "right", x + w)
end

local function drawTilt(w, h, t)
  local side = w >= 760
  local cw = side and canvas.w - 300 or canvas.w
  local cnv = {x = canvas.x, y = canvas.y, w = cw, h = canvas.h}
  gfx.rect(cnv.x, cnv.y, cnv.w, cnv.h, 14, "#13261C")
  local cx, cy = cnv.x + cnv.w / 2, cnv.y + cnv.h / 2
  local hw, hh = cnv.w / 2 - marble.r - 8, cnv.h / 2 - marble.r - 8
  arena.w, arena.h = cnv.w, cnv.h                          -- the marble lives in the left part
  -- star
  local sx, sy = cx + star.x * hw, cy + star.y * hh
  gfx.icon("star", sx, sy, 30 + sin(t * 4) * 3, "#FFD84D")
  -- marble with a highlight and a shadow
  gfx.circle(cx + marble.x + 3, cy + marble.y + 5, marble.r, "#00000060")
  gfx.circle(cx + marble.x, cy + marble.y, marble.r, "#C9D6E8")
  gfx.circle(cx + marble.x - 5, cy + marble.y - 5, marble.r * 0.35, "#FFFFFF")
  gfx.color("#FFFFFFB0")
  gfx.text(TR("stars", star.got), cnv.x + 14, cnv.y + 12, 14, "semibold")
  if not hasMotion then
    gfx.color("#FFFFFF90")
    gfx.text(TR("no_motion"), cnv.x, cnv.y + cnv.h - 30, 12, "sans", "center", cnv.w)
  end
  -- sensor readout
  local rx, ry, rw = side and (cnv.x + cw + 16) or cnv.x, side and cnv.y or (cnv.y + cnv.h + 8), side and 284 or canvas.w
  if not side then return end
  local names = {"ax", "ay", "az", "gx", "gy", "gz", "pitch", "roll", "yaw"}
  local ranges = {1.5, 1.5, 1.5, 6, 6, 6, pi, pi, pi}
  gfx.color(theme.text)
  gfx.text(TR("motion_title"), rx, ry, 14, "semibold")
  for i = 1, 9 do
    bar(rx, ry + 26 + (i - 1) * 24 + (i > 3 and 10 or 0) + (i > 6 and 10 or 0), rw, names[i], motion[i], ranges[i])
  end
  -- artificial horizon from roll and pitch
  local hy = ry + 26 + 9 * 24 + 40
  local r = min(60, (canvas.y + canvas.h - hy) / 2 - 4)
  if r > 20 then
    local hcx, hcy = rx + rw / 2, hy + r
    gfx.circle(hcx, hcy, r, "#3B6EA8")
    local c, s = cos(motion[8]), sin(motion[8])
    local off = max(-r, min(r, motion[7] * r))
    gfx.color("#FFFFFF")
    gfx.line(hcx - c * r + s * off, hcy - s * r - c * off, hcx + c * r + s * off, hcy + s * r - c * off, 3)
    gfx.circleLine(hcx, hcy, r, 2)
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local nt = ui.segmented("tab", {TR("tab_gestures"), TR("tab_tilt")}, tab, 16, 14, min(320, w - 32), 32)
  if nt ~= tab then tab = nt; drag = nil end
  canvas.x, canvas.y, canvas.w, canvas.h = 16, 60, w - 32, h - 60 - 60
  local t = sys.time()
  if tab == 1 then
    drawGestures(w, h, t)
    if ui.button(TR("reset"), w - 126, 14, 110, 32, "default", "refresh") then resetView() end
    gfx.color(theme.text3)
    gfx.text(TR("hint_gestures"), 0, h - 22, 12, "sans", "right", w - 16)
  else
    drawTilt(w, h, t)
    if ui.button(TR("calibrate"), w - 146, 14, 130, 32, "default", "screen_rotation") then
      calib.ax, calib.ay = motion[1], motion[2]           -- the current tilt becomes "flat"
      marble.vx, marble.vy = 0, 0
      sys.vibrate(0.3, 40)
    end
    gfx.color(theme.text3)
    gfx.text(TR("hint_tilt"), 0, h - 22, 12, "sans", "right", w - 16)
  end
end

function app.menu()
  return {{title = TR("menu_title"), items = {
    {label = TR("reset"), id = 1, shortcut = "R"},
    {label = TR("calibrate"), id = 2},
    "-",
    {label = TR("test_rumble"), id = 3},
  }}}
end

function app.onmenu(id)
  if id == 1 then resetView()
  elseif id == 2 then calib.ax, calib.ay = motion[1], motion[2]
  elseif id == 3 then
    -- three pulses, stronger each time, scheduled with timers
    for i = 1, 3 do timer.after((i - 1) * 0.25, function() sys.vibrate(i / 3, 80) end) end
  end
end

return app
