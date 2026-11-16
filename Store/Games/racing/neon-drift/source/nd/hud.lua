-- Neon Drift: the race HUD and shared 2D pieces (skewed slabs, minimap, touch controls).
-- Own building blocks: the stroke font (nd.font), slanted segment bars and skewed panels.
local F = require("nd.font")
local H = {}
local hexa = F.hexa

H.PINK, H.CYAN, H.VIOLET, H.AMBER, H.WHITE, H.INK = "#FF2E88", "#19E6FF", "#8A5BFF", "#FFB13B", "#F2F4FF", "#07060F"

-- parallelogram slab: x, y, w, h, skew (px), color
function H.slab(x, y, w, h, sk, c)
  gfx.poly({x + sk, y, x + w + sk, y, x + w, y + h, x, y + h}, c)
end

function H.fmtTime(t)
  if not t then return "-:--.--" end
  local m = math.floor(t / 60)
  local s = t - m * 60
  return string.format("%d:%05.2f", m, s)
end

function H.label(s, x, y, size, color, align, width)
  gfx.color(color or H.WHITE)
  return gfx.text(s, x, y, size, "bold", align, width)
end

-- segmented slanted bar (speed / nitro): n segments rising in height, f = 0..1 lit
function H.segBar(x, y, w, h, n, f, cols, rising)
  local gap = 3
  local sw = (w - gap * (n - 1)) / n
  local lit = f * n
  for k = 0, n - 1 do
    local sh = rising and h * (0.35 + 0.65 * (k + 1) / n) or h
    local sx = x + k * (sw + gap)
    local sy = y + (h - sh)
    local t = k / math.max(1, n - 1)
    local col
    if t < 0.5 then col = cols[1] elseif t < 0.8 then col = cols[2] else col = cols[3] end
    local on = k < lit
    local a = on and (k + 1 > lit and (lit - k) or 1) or 0
    H.slab(sx, sy, sw, sh, sh * 0.35, hexa("#FFFFFF", 0.06))
    if on then H.slab(sx, sy, sw, sh, sh * 0.35, hexa(col, 0.92 * a)) end
  end
end

-- minimap of a track in a box; cars drawn as dots
function H.minimap(tr, x, y, size, cars, player, alpha)
  alpha = alpha or 1
  if not tr.mm then
    local minx, maxx, minz, maxz = 1e9, -1e9, 1e9, -1e9
    for i = 1, tr.N do
      minx, maxx = math.min(minx, tr.x[i]), math.max(maxx, tr.x[i])
      minz, maxz = math.min(minz, tr.z[i]), math.max(maxz, tr.z[i])
    end
    local sc = 1 / math.max(maxx - minx, maxz - minz)
    tr.mm = {minx = minx, minz = minz, sc = sc, ox = (1 - (maxx - minx) * sc) / 2, oz = (1 - (maxz - minz) * sc) / 2}
  end
  local m = tr.mm
  local function P(px, pz) return x + ((px - m.minx) * m.sc + m.ox) * size, y + ((pz - m.minz) * m.sc + m.oz) * size end
  if not tr.mmPts or tr.mmSize ~= size or tr.mmX ~= x or tr.mmY ~= y then
    local pts = {}
    for i = 1, tr.N, 6 do local a, b = P(tr.x[i], tr.z[i]); pts[#pts + 1] = a; pts[#pts + 1] = b end
    local a, b = P(tr.x[1], tr.z[1]); pts[#pts + 1] = a; pts[#pts + 1] = b
    tr.mmPts, tr.mmSize, tr.mmX, tr.mmY = pts, size, x, y
  end
  gfx.color(hexa(H.CYAN, 0.25 * alpha)); gfx.lines(tr.mmPts, 6)
  gfx.color(hexa("#DFFBFF", 0.9 * alpha)); gfx.lines(tr.mmPts, 1.6)
  local sx, sy = P(tr.x[1], tr.z[1])
  gfx.color(hexa(H.WHITE, alpha)); gfx.rect(sx - 4, sy - 1.5, 8, 3)
  if cars then
    for _, c in ipairs(cars) do
      if c ~= player then
        local px, py = P(c.x, c.z)
        gfx.circle(px, py, 4.5, hexa(c.color, alpha))
      end
    end
    if player then
      local px, py = P(player.x, player.z)
      gfx.circle(px, py, 8, hexa(H.PINK, 0.35 * alpha))
      gfx.circle(px, py, 5, hexa(H.WHITE, alpha))
    end
  end
end

-- the race HUD; r = race state table from main.lua
function H.race(w, h, r, TR)
  local u = h / 720
  local p = r.player
  local n = #r.cars
  -- top-left: position
  H.slab(-20 * u, 18 * u, 250 * u, 118 * u, 26 * u, hexa(H.INK, 0.55))
  H.slab(-20 * u, 18 * u, 8 * u, 118 * u, 26 * u, hexa(H.PINK, 0.9))
  local pw = F.draw(tostring(p.rank), 30 * u, 30 * u, 80 * u, H.WHITE, {thick = 5 * u})
  F.draw("/" .. n, 30 * u + pw + 10 * u, 76 * u, 30 * u, H.PINK, {thick = 2.6 * u})
  H.label(string.upper(TR("hud_pos")), 150 * u, 34 * u, 16 * u, hexa(H.CYAN, 0.9))
  -- lap
  local lap = math.max(1, math.min(r.laps, p.lap + 1))
  H.label(string.upper(TR("hud_lap")), 150 * u, 64 * u, 16 * u, hexa(H.CYAN, 0.9))
  F.draw(lap .. "/" .. r.laps, 150 * u, 88 * u, 28 * u, H.WHITE, {thick = 2.6 * u})
  -- top-right: times
  local tx = w - 30 * u
  H.slab(w - 300 * u, 18 * u, 330 * u, 102 * u, 26 * u, hexa(H.INK, 0.55))
  F.draw(H.fmtTime(r.time), tx, 30 * u, 34 * u, H.WHITE, {align = "right", thick = 3 * u})
  local lt = r.time - (p.lapStart or 0)
  H.label(string.upper(TR("hud_lap_time")), w - 280 * u, 78 * u, 14 * u, hexa(H.CYAN, 0.85))
  F.draw(H.fmtTime(lt), tx, 76 * u, 18 * u, "#CFE9FF", {align = "right", thick = 1.8 * u})
  H.label(string.upper(TR("hud_best")), w - 280 * u, 100 * u, 14 * u, hexa(H.AMBER, 0.85))
  F.draw(H.fmtTime(p.best), tx, 98 * u, 18 * u, H.AMBER, {align = "right", thick = 1.8 * u})
  -- bottom-right: speed and revs, gear, nitro
  local bx, by = w - 380 * u, h - 176 * u
  H.slab(bx - 10 * u, by - 14 * u, 420 * u, 190 * u, 40 * u, hexa(H.INK, 0.5))
  H.segBar(bx + 20 * u, by, 340 * u, 54 * u, 22, math.min(1, p.speed / 76), {H.CYAN, H.VIOLET, H.PINK}, true)
  local kmh = math.floor(p.speed * 3.6 + 0.5)
  F.draw(tostring(kmh), w - 120 * u, by + 66 * u, 64 * u, H.WHITE, {align = "right", thick = 4.4 * u})
  H.label("KM/H", w - 110 * u, by + 104 * u, 18 * u, hexa(H.CYAN, 0.9))
  -- gear box
  H.slab(bx + 20 * u, by + 70 * u, 50 * u, 52 * u, 14 * u, hexa(H.PINK, 0.85))
  F.draw(p.speed < 0.5 and "N" or tostring(p.gear), bx + 33 * u, by + 80 * u, 32 * u, H.WHITE, {thick = 3 * u, glow = false})
  -- nitro
  local ny = by + 140 * u
  H.label(string.upper(TR("hud_nitro")), bx + 20 * u, ny - 2 * u, 14 * u, hexa(H.AMBER, 0.9))
  local full = p.nitro > 0.98
  local pulse = full and (0.6 + 0.4 * math.sin(r.clock * 10)) or 1
  H.segBar(bx + 96 * u, ny - 2 * u, 270 * u, 16 * u, 12, p.nitro,
           p.nitroOn and {"#7FB8FF", "#B8D8FF", "#FFFFFF"} or {H.AMBER, "#FF8A3B", H.PINK}, false)
  if full then
    gfx.color(hexa(H.AMBER, 0.3 * pulse)); gfx.rectLine(bx + 92 * u, ny - 6 * u, 282 * u, 24 * u, 4, 2)
  end
  -- drift charge meter
  if p.drifting then
    local c = math.min(1, p.driftT / 0.9)
    local cx, cy = w / 2, h * 0.70
    H.label(string.upper(TR("hud_drift")), cx - 100 * u, cy - 26 * u, 20 * u, c >= 1 and H.AMBER or H.CYAN, "center", 200 * u)
    gfx.color(hexa("#FFFFFF", 0.15)); gfx.rect(cx - 90 * u, cy, 180 * u, 6 * u, 3)
    gfx.color(c >= 1 and H.AMBER or H.CYAN); gfx.rect(cx - 90 * u, cy, 180 * u * c, 6 * u, 3)
  end
  -- minimap
  local ms = 190 * u
  H.slab(14 * u, h - ms - 30 * u, ms + 26 * u, ms + 16 * u, 18 * u, hexa(H.INK, 0.45))
  H.minimap(r.track, 26 * u, h - ms - 22 * u, ms, r.cars, p, 1)
  -- rival tags
  for _, c in ipairs(r.cars) do
    if c ~= p and c.sx and c.tagA and c.tagA > 0 then
      local a = c.tagA
      gfx.color(hexa(H.INK, 0.6 * a)); gfx.rect(c.sx - 18 * u, c.sy - 26 * u, 36 * u, 22 * u, 4)
      gfx.color(hexa(c.color, a)); gfx.rect(c.sx - 18 * u, c.sy - 6 * u, 36 * u, 3 * u)
      F.draw(tostring(c.rank), c.sx, c.sy - 23 * u, 16 * u, H.WHITE, {align = "center", thick = 1.8 * u, glow = false, alpha = a})
    end
  end
end

-- touch controls overlay: returns the button rects
function H.touchLayout(w, h)
  local u = h / 720
  local s = 120 * u
  return {
    left = {0, h * 0.3, w * 0.3, h * 0.7},
    right = {w * 0.3, h * 0.3, w * 0.25, h * 0.7},
    brake = {w - 3 * s - 40 * u, h - s - 220 * u, s, s},
    drift = {w - 2 * s - 26 * u, h - s - 220 * u, s, s},
    nitro = {w - s - 12 * u, h - s - 220 * u, s, s},
    pause = {w / 2 - 40 * u, 10 * u, 80 * u, 60 * u},
  }
end

function H.touchDraw(w, h, L, held, TR)
  local u = h / 720
  local function btn(r, label, col, on)
    local cx, cy = r[1] + r[3] / 2, r[2] + r[4] / 2
    gfx.circle(cx, cy, r[3] / 2, hexa(H.INK, on and 0.7 or 0.45))
    gfx.color(hexa(col, on and 1 or 0.6)); gfx.circleLine(cx, cy, r[3] / 2 - 3, 3)
    H.label(label, r[1], cy - 12 * u, 18 * u, col, "center", r[3])
  end
  btn(L.brake, string.upper(TR("touch_brake")), H.CYAN, held.brake)
  btn(L.drift, string.upper(TR("hud_drift")), H.VIOLET, held.drift)
  btn(L.nitro, string.upper(TR("hud_nitro")), H.AMBER, held.nitro)
  gfx.color(hexa(H.WHITE, 0.12))
  gfx.icon("chevron_left", 60 * u, h * 0.62, 70 * u, hexa(H.WHITE, held.left and 0.6 or 0.2))
  gfx.icon("chevron_right", w * 0.3 + 70 * u, h * 0.62, 70 * u, hexa(H.WHITE, held.right and 0.6 or 0.2))
  gfx.icon("pause", w / 2, 40 * u, 36 * u, hexa(H.WHITE, 0.6))
end

return H
