-- Isle Defense: the interface. A cartographer's table: parchment cards with burnt edges, carved wooden planks and
-- wax seals for buttons, ink text. Every clickable thing registers a hit box each frame; main.lua asks U.hitAt().
local D = require("id_data")
local U = {}
local sin, cos, pi, floor, min, max, abs = math.sin, math.cos, math.pi, math.floor, math.min, math.max, math.abs

local img = {}
local hits = {}
U.hits = hits
local INK, INK2, GOLD, CREAM = "#3A2414", "#6B4A2E", "#FFD45A", "#FFF4DC"

function U.init()
  img.parch = gfx.image("bundle:/tex/parchment.png")
  img.wood = gfx.image("bundle:/tex/wood.png")
  img.logo = gfx.image("bundle:/tex/logo.png")
end

function U.begin() for i = #hits, 1, -1 do hits[i] = nil end end
local function hit(id, x, y, w, h, data) hits[#hits + 1] = {id = id, x = x, y = y, w = w, h = h, data = data} end
U.hit = hit
function U.hitAt(x, y)
  for i = #hits, 1, -1 do
    local b = hits[i]
    if x >= b.x and y >= b.y and x <= b.x + b.w and y <= b.y + b.h then return b.id, b.data end
  end
end

-- ------------------------------------------------------------------ pieces
function U.parch(x, y, w, h, a)
  gfx.shadow(x, y, w, h, 10, 18, 6)
  if img.parch then gfx.draw(img.parch, x, y, w, h, 8, a and string.format("#FFFFFF%02X", floor(a * 255)) or nil)
  else gfx.rect(x, y, w, h, 8, "#ECD6A8") end
end

function U.plank(x, y, w, h)
  gfx.shadow(x, y, w, h, 8, 14, 5)
  if img.wood then gfx.draw(img.wood, x, y, w, h, 8) else gfx.rect(x, y, w, h, 8, "#7A4A28") end
  gfx.color(255, 230, 180, 40)
  gfx.rectLine(x + 2, y + 2, w - 4, h - 4, 7, 1.5)
  -- brass rivets
  for _, px in ipairs({x + 9, x + w - 9}) do
    for _, py in ipairs({y + 9, y + h - 9}) do
      gfx.circle(px, py, 3.2, "#C8A040")
      gfx.circle(px - 0.8, py - 0.8, 1.2, "#FFF0B0")
    end
  end
end

-- a wax seal: dark rim, coloured wax, a pressed icon; state "off" greys it, "hot" lifts it
function U.seal(cx, cy, r, col, icon, state, t)
  local lift = state == "hot" and (2 + sin((t or 0) * 6) * 1) or 0
  cy = cy - lift
  gfx.circle(cx + 2, cy + 3 + lift, r + 2, "#00000055")
  local c = state == "off" and "#7A7066" or col
  -- wavy wax edge
  local pts = {}
  for i = 0, 17 do
    local a = i / 18 * pi * 2
    local rr = r * (1 + 0.06 * sin(a * 5 + cx))
    pts[#pts + 1] = cx + cos(a) * rr
    pts[#pts + 1] = cy + sin(a) * rr
  end
  gfx.poly(pts, c)
  gfx.circle(cx, cy, r * 0.78, "#00000030")
  gfx.circle(cx - r * 0.12, cy - r * 0.14, r * 0.72, c)
  gfx.color(255, 255, 255, 60)
  gfx.arc(cx, cy, r * 0.62, pi * 1.05, pi * 1.6, 2)
  if icon then gfx.icon(icon, cx, cy, r * 0.95, state == "off" and "#D8CFC4" or CREAM) end
  if state == "hot" then
    gfx.color(255, 230, 140, 200)
    gfx.circleLine(cx, cy, r + 4, 2.5)
  end
end

local function ink(s, x, y, size, font, align, width, col)
  return gfx.text(s, x, y, size, font or "semibold", align, width, col)
end

local function textC(s, x, y, size, font, col)
  gfx.color(col or INK)
  return gfx.text(s, x, y, size, font or "semibold")
end

local function shadowText(s, x, y, size, font, col, align, width)
  gfx.color(0, 0, 0, 150)
  gfx.text(s, x + 1.5, y + 2, size, font, align, width)
  gfx.color(col or CREAM)
  gfx.text(s, x, y, size, font, align, width)
end
U.shadowText = shadowText

-- ------------------------------------------------------------------ HUD
-- ctx: {st, preview, speed, panel, ring, msg, t, touch, selTray, hover, cursorPad}
function U.hud(w, h, c)
  local u = h / 720
  local st = c.st
  local t = c.t
  -- resources plank
  local pw, ph = 380 * u, 58 * u
  local x0, y0 = 16 * u, 14 * u
  U.plank(x0, y0, pw, ph)
  local cy = y0 + ph / 2
  local hb = c.heartBeat or 0
  gfx.icon("favorite", x0 + 32 * u, cy, (28 + hb * 8) * u, st.lives <= 5 and "#FF5050" or "#FF7A7A")
  shadowText(tostring(st.lives), x0 + 52 * u, cy - 14 * u, 26 * u, "bold")
  gfx.circle(x0 + 128 * u, cy, 14 * u, "#E8B830")
  gfx.circle(x0 + 128 * u, cy, 10 * u, "#FFD45A")
  gfx.icon("paid", x0 + 128 * u, cy, 18 * u, "#8A5A10")
  shadowText(tostring(floor(st.gold)), x0 + 148 * u, cy - 14 * u, 26 * u, "bold", c.goldFlash and c.goldFlash > 0 and "#FFE680" or CREAM)
  shadowText(TR("hud_wave", math.max(1, st.wave), st.waves), x0 + 236 * u, cy - 12 * u, 21 * u, "semibold", CREAM)
  -- top right: speed and pause
  local sx = w - 50 * u
  U.seal(sx, 44 * u, 26 * u, "#5B3A22", "pause", c.hover == "pause" and "hot" or nil, t)
  hit("pause", sx - 28 * u, 16 * u, 56 * u, 56 * u)
  local spx = w - 116 * u
  U.seal(spx, 44 * u, 26 * u, c.speed > 1 and "#B5652A" or "#5B3A22", nil, c.hover == "speed" and "hot" or nil, t)
  shadowText(c.speed .. "x", spx - 30 * u, 30 * u, 24 * u, "bold", CREAM, "center", 60 * u)
  hit("speed", spx - 28 * u, 16 * u, 56 * u, 56 * u)
  -- next wave preview (parchment on the left)
  if c.preview and not st.over then
    local n = #c.preview
    local cw, chh = (128 + n * 58) * u, 64 * u
    local px, py = 16 * u, 84 * u
    U.parch(px, py, cw, chh, 0.97)
    gfx.color(INK2)
    gfx.text(TR(st.spawning and "hud_coming" or "hud_next"), px + 14 * u, py + 10 * u, 15 * u, "semibold")
    gfx.color(INK)
    gfx.text(TR("hud_wave_n", st.spawning and st.wave or st.wave + 1), px + 14 * u, py + 30 * u, 20 * u, "bold")
    for i, it in ipairs(c.preview) do
      local f = D.FOES[it.id]
      local mx, my = px + (128 + (i - 1) * 58 + 22) * u, py + chh / 2
      gfx.circle(mx, my, 20 * u, "#00000040")
      gfx.circle(mx, my - 1, 19 * u, f.color)
      gfx.icon(f.icon, mx, my - 1, 22 * u, f.air and INK or CREAM)
      if f.boss then gfx.color("#FFD45A"); gfx.circleLine(mx, my - 1, 21 * u, 2.5) end
      gfx.color(INK)
      gfx.text("x" .. it.n, mx + 6 * u, my + 8 * u, 15 * u, "bold")
    end
  end
  -- tower tray (bottom centre): seals on a plank
  local n = #D.TOWERS
  local sp = 86 * u
  local tw = n * sp + 24 * u
  local tx, ty = (w - tw) / 2, h - 104 * u
  U.plank(tx, ty + 16 * u, tw, 76 * u)
  for i, d in ipairs(D.TOWERS) do
    local cx, cyy = tx + 12 * u + (i - 0.5) * sp, ty + 40 * u
    local afford = st.gold >= d.cost
    local state = not afford and "off" or ((c.selTray == i or c.hover == "tray" .. i) and "hot" or nil)
    U.seal(cx, cyy, 28 * u, d.color, d.icon, state, t)
    -- price tag
    local tg = 56 * u
    gfx.rect(cx - tg / 2, cyy + 30 * u, tg, 22 * u, 6, afford and "#F2E2B8" or "#BFB4A2")
    gfx.color(afford and INK or "#6A5E50")
    gfx.text(tostring(d.cost), cx - tg / 2, cyy + 32 * u, 16 * u, "bold", "center", tg)
    hit("tray" .. i, cx - 32 * u, cyy - 32 * u, 64 * u, 86 * u, i)
  end
  -- call wave (bottom right): the horn
  if not st.over and st.wave < st.waves then
    local hx, hy, hr = w - 92 * u, h - 82 * u, 46 * u
    local ready = not st.spawning
    local hs = "off"
    if ready then hs = c.hover == "call" and "hot" or nil end
    U.seal(hx, hy, hr, ready and "#A23A2A" or "#6A4A3A", "campaign", hs, t)
    if ready and st.breakT and st.breakT > 0 then
      local f = st.breakT / (st.wave == 0 and 22 or D.BREAK)
      gfx.color(255, 220, 120, 230)
      gfx.arc(hx, hy, hr + 7 * u, -pi / 2, -pi / 2 + f * pi * 2, 4 * u)
      if st.wave > 0 then shadowText("+" .. floor(st.breakT * D.EARLY_BONUS), hx - 50 * u, hy - hr - 34 * u, 18 * u, "bold", "#FFE680", "center", 100 * u) end
    end
    shadowText(TR("hud_call"), hx - 80 * u, hy + hr + 4 * u, 16 * u, "bold", CREAM, "center", 160 * u)
    hit("call", hx - hr, hy - hr, hr * 2, hr * 2)
  end
  -- controller button hints (only without touch)
  if not c.touch and c.pad then
    gfx.color(255, 245, 220, 200)
    gfx.text(TR("hint_pad"), 16 * u, h - 30 * u, 15 * u, "semibold")
  end
end

-- hp bars over raiders that took damage
function U.bars(enemies, u)
  for _, e in ipairs(enemies) do
    if not e.dead and e.sx and (e.hp < e.max or e.f.boss) then
      local bw = (e.f.boss and 90 or 34) * u
      local x, y = e.sx - bw / 2, e.sy - 10 * u
      gfx.rect(x - 1, y - 1, bw + 2, 7 * u + 2, 3, "#1A0E08C0")
      local f = max(0, e.hp / e.max)
      gfx.rect(x, y, bw * f, 7 * u, 2, f > 0.5 and "#6EE05A" or (f > 0.25 and "#F2C230" or "#FF5040"))
      if e.slow > 0 then gfx.rect(x, y + 7 * u, bw, 2 * u, 1, "#7FD8FF") end
    end
  end
end

-- the build ring around an empty pad: six seals
function U.ring(w, h, c)
  local u = h / 720
  local cx, cy = c.x, c.y
  local R = 92 * u
  cx = max(R + 40 * u, min(w - R - 40 * u, cx))
  cy = max(R + 70 * u, min(h - R - 130 * u, cy))
  gfx.circle(cx, cy, R + 44 * u, "#1A0E0855")
  gfx.color(255, 230, 170, 120)
  gfx.circleLine(cx, cy, R, 2)
  for i, d in ipairs(D.TOWERS) do
    local a = -pi / 2 + (i - 1) / #D.TOWERS * pi * 2
    local x, y = cx + cos(a) * R, cy + sin(a) * R
    local afford = c.gold >= d.cost
    U.seal(x, y, 30 * u, d.color, d.icon, not afford and "off" or (c.sel == i and "hot" or nil), c.t)
    gfx.rect(x - 24 * u, y + 26 * u, 48 * u, 18 * u, 5, afford and "#F2E2B8" or "#BFB4A2")
    gfx.color(afford and INK or "#6A5E50")
    gfx.text(tostring(d.cost), x - 24 * u, y + 27 * u, 14 * u, "bold", "center", 48 * u)
    hit("ring" .. i, x - 32 * u, y - 32 * u, 64 * u, 78 * u, i)
  end
  -- name and line of the highlighted tower in the middle
  local d = D.TOWERS[c.sel or 1]
  shadowText(TR("t_" .. d.id), cx - 120 * u, cy - 22 * u, 20 * u, "bold", CREAM, "center", 240 * u)
  gfx.color(255, 236, 200, 230)
  gfx.text(TR("td_" .. d.id), cx - 70 * u, cy + 4 * u, 13 * u, "semibold", "center", 140 * u)
  hit("ringbg", cx - R - 44 * u, cy - R - 44 * u, (R + 44 * u) * 2, (R + 44 * u) * 2)
end

-- the card of a built tower: stats, upgrade, sell
function U.towerCard(w, h, c)
  local u = h / 720
  local t, d = c.tower, D.TOWER[c.tower.id]
  local cw, ch = 300 * u, 214 * u
  local x = max(16 * u, min(w - cw - 16 * u, c.x + 60 * u))
  local y = max(84 * u, min(h - ch - 120 * u, c.y - ch / 2))
  U.parch(x, y, cw, ch)
  hit("card", x, y, cw, ch)
  U.seal(x + 34 * u, y + 36 * u, 22 * u, d.color, d.icon, nil, c.t)
  gfx.color(INK)
  gfx.text(TR("t_" .. d.id), x + 64 * u, y + 16 * u, 21 * u, "bold")
  for k = 1, 3 do
    gfx.icon("star", x + 74 * u + (k - 1) * 22 * u, y + 52 * u, 20 * u, k <= t.tier and "#D9961E" or "#B8A88A")
  end
  local lines = {}
  local function stat(key, v) lines[#lines + 1] = TR(key, v) end
  local tier = t.tier
  if d.id == "shrine" then
    stat("st_income", d.income[tier])
    stat("st_aura", floor(d.aura[tier] * 100 + 0.5))
  else
    stat("st_dmg", floor(d.dmg[tier] * (1 + (t.aura or 0)) + 0.5))
    if d.id == "fire" then stat("st_burn", d.burn[tier]) end
    if d.rate then stat("st_rate", string.format("%.1f", d.rate[tier])) end
    if d.slow then stat("st_slow", floor(d.slow[tier] * 100)) end
    if d.chain then stat("st_chain", d.chain[tier]) end
    if d.splash and d.splash[tier] > 0 then stat("st_splash", string.format("%.1f", d.splash[tier])) end
  end
  stat("st_range", string.format("%.1f", d.range[tier]))
  gfx.color(INK2)
  for i, s in ipairs(lines) do
    local col, row = (i - 1) % 2, floor((i - 1) / 2)
    gfx.text(s, x + 18 * u + col * 140 * u, y + 76 * u + row * 22 * u, 15 * u, "semibold")
  end
  -- buttons
  local by = y + ch - 58 * u
  local up = c.upCost
  if up then
    local ok = c.gold >= up
    gfx.rect(x + 14 * u, by, 160 * u, 44 * u, 10, ok and "#3E8E41" or "#8C8478")
    gfx.color(CREAM)
    gfx.text(TR("b_upgrade", up), x + 14 * u, by + 5 * u, 16 * u, "bold", "center", 160 * u)
    gfx.text(c.pad and TR("hint_a") or "", x + 14 * u, by + 25 * u, 12 * u, "semibold", "center", 160 * u)
    hit("upgrade", x + 14 * u, by, 160 * u, 44 * u)
  else
    gfx.color(INK2)
    gfx.text(TR("b_maxed"), x + 14 * u, by + 12 * u, 16 * u, "bold", "center", 160 * u)
  end
  gfx.rect(x + 184 * u, by, 102 * u, 44 * u, 10, "#A23A2A")
  gfx.color(CREAM)
  gfx.text(TR("b_sell", c.sell), x + 184 * u, by + 5 * u, 16 * u, "bold", "center", 102 * u)
  gfx.text(c.pad and TR("hint_x") or "", x + 184 * u, by + 25 * u, 12 * u, "semibold", "center", 102 * u)
  hit("sell", x + 184 * u, by, 102 * u, 44 * u)
end

-- a ribbon message across the top
function U.banner(w, h, text, sub, a, boss)
  local u = h / 720
  local bw, bh = 560 * u, (sub and 82 or 56) * u
  local x, y = (w - bw) / 2, 92 * u
  gfx.alpha(a)
  -- ribbon tails
  gfx.poly({x - 30 * u, y + 10 * u, x + 10 * u, y + 10 * u, x + 10 * u, y + bh + 6 * u, x - 30 * u, y + bh + 6 * u, x - 14 * u, y + bh / 2 + 8 * u}, boss and "#5A1410" or "#6B3A1E")
  gfx.poly({x + bw + 30 * u, y + 10 * u, x + bw - 10 * u, y + 10 * u, x + bw - 10 * u, y + bh + 6 * u, x + bw + 30 * u, y + bh + 6 * u, x + bw + 14 * u, y + bh / 2 + 8 * u}, boss and "#5A1410" or "#6B3A1E")
  gfx.rect(x, y, bw, bh, 6, boss and "#A82A1E" or "#B5652A")
  gfx.color(255, 230, 180, 90)
  gfx.rectLine(x + 4, y + 4, bw - 8, bh - 8, 4, 1.5)
  shadowText(text, x, y + 10 * u, 26 * u, "bold", CREAM, "center", bw)
  if sub then
    gfx.color(255, 236, 200, 235)
    gfx.text(sub, x, y + 46 * u, 16 * u, "semibold", "center", bw)
  end
  gfx.unalpha()
end

-- ------------------------------------------------------------------ menus
-- items: {{label, id, value, off}}; returns nothing, registers hits "m<i>"
function U.menu(w, h, title, items, sel, t, opts)
  local u = h / 720
  opts = opts or {}
  local mw = (opts.width or 420) * u
  local rowH = 52 * u
  local mh = (opts.logo and 30 or 84) * u + #items * rowH + 26 * u
  local x = opts.left and 70 * u or (w - mw) / 2
  local y = opts.top or ((h - mh) / 2 + (opts.logo and 90 * u or 0))
  if opts.logo and img.logo then
    local lw = 640 * u
    local lh = lw * img.logo.height / img.logo.width
    local lx = opts.left and (x + mw / 2 - lw / 2) or (w - lw) / 2
    gfx.draw(img.logo, lx, y - lh - 10 * u + sin(t * 0.8) * 3 * u, lw, lh)
    if opts.tagline then shadowText(opts.tagline, lx, y - 26 * u, 17 * u, "semibold", "#FFF0D0", "center", lw) end
  end
  U.parch(x, y, mw, mh, 0.98)
  local yy = y + 20 * u
  if not opts.logo then
    gfx.color(INK)
    gfx.text(title, x, yy, 28 * u, "bold", "center", mw)
    yy = yy + 52 * u
    gfx.color(INK2)
    gfx.line(x + 40 * u, yy - 10 * u, x + mw - 40 * u, yy - 10 * u, 1.5)
  else
    yy = yy + 6 * u
  end
  for i, it in ipairs(items) do
    local ry = yy + (i - 1) * rowH
    local on = i == sel
    if on then
      gfx.rect(x + 22 * u, ry, mw - 44 * u, rowH - 8 * u, 10, "#B5652A")
      gfx.color(255, 236, 200, 90)
      gfx.rectLine(x + 24 * u, ry + 2, mw - 48 * u, rowH - 12 * u, 9, 1.5)
      U.seal(x + 44 * u, ry + (rowH - 8 * u) / 2, 12 * u, "#7A2A1E", nil, nil, t)
    end
    gfx.color(it.off and "#9A8A74" or (on and CREAM or INK))
    if it.value then
      gfx.text(it.label, x + 66 * u, ry + 9 * u, 20 * u, "semibold")
      gfx.text(it.value, x + mw - 230 * u, ry + 9 * u, 20 * u, "bold", "right", 180 * u)
    else
      gfx.text(it.label, x + 66 * u, ry + 9 * u, 20 * u, "semibold")
    end
    hit("m" .. i, x + 22 * u, ry, mw - 44 * u, rowH - 8 * u, i)
  end
  if opts.footer then
    gfx.color(255, 245, 220, 210)
    gfx.text(opts.footer, x, y + mh + 10 * u, 14 * u, "semibold", "center", mw)
  end
end

-- result card: victory with stars, or defeat
function U.result(w, h, c)
  local u = h / 720
  local cw, ch = 520 * u, 330 * u
  local x, y = (w - cw) / 2, (h - ch) / 2
  gfx.color(0, 0, 0, floor(120 * c.a))
  gfx.rect(0, 0, w, h)
  gfx.alpha(c.a)
  U.parch(x, y, cw, ch)
  gfx.color(c.win and "#2E6A2E" or "#8A2A1E")
  gfx.text(TR(c.win and "r_win" or "r_lose"), x, y + 22 * u, 34 * u, "bold", "center", cw)
  if c.win then
    for k = 1, 3 do
      local show = c.t > 0.5 + k * 0.35
      local s = show and min(1, (c.t - 0.5 - k * 0.35) * 5) or 0
      local sx = x + cw / 2 + (k - 2) * 78 * u
      gfx.icon("star", sx, y + 108 * u, 64 * u * (k == 2 and 1.15 or 1), "#B8A88A")
      if k <= c.stars and show then gfx.icon("star", sx, y + 108 * u, 64 * u * (k == 2 and 1.15 or 1) * (0.6 + 0.4 * s), "#F2B21E") end
    end
  else
    gfx.icon("heart_broken", x + cw / 2, y + 106 * u, 70 * u, "#A23A2A")
  end
  gfx.color(INK2)
  gfx.text(TR("r_stats", c.wave, c.waves, c.kills, c.lives), x, y + 160 * u, 17 * u, "semibold", "center", cw)
  -- buttons
  for i, b in ipairs(c.buttons) do
    local bw = 150 * u
    local bx = x + cw / 2 + (i - (#c.buttons + 1) / 2) * (bw + 14 * u) - bw / 2
    local by = y + ch - 74 * u
    gfx.rect(bx, by, bw, 48 * u, 10, i == c.sel and "#B5652A" or "#7A5034")
    gfx.color(CREAM)
    gfx.text(b.label, bx, by + 13 * u, 18 * u, "bold", "center", bw)
    hit("r" .. i, bx, by, bw, 48 * u, i)
  end
  gfx.unalpha()
end

-- loading card
function U.loading(w, h, frac, t)
  local u = h / 720
  gfx.gradient(0, 0, w, h, "#7FD0E6", "#F6D9A2")
  if img.logo then
    local lw = 560 * u
    local lh = lw * img.logo.height / img.logo.width
    gfx.draw(img.logo, (w - lw) / 2, h * 0.34 - lh / 2, lw, lh)
  end
  local bw = 360 * u
  local x, y = (w - bw) / 2, h * 0.62
  U.plank(x - 10 * u, y - 10 * u, bw + 20 * u, 34 * u)
  gfx.rect(x, y, bw * max(0.02, min(1, frac or 0)), 14 * u, 7, "#FFD45A")
  gfx.color(INK)
  gfx.text(TR("loading"), x, y + 34 * u, 16 * u, "semibold", "center", bw)
end

-- touch controls help strip during play
function U.touchHint(w, h)
  local u = h / 720
  gfx.color(255, 245, 220, 190)
  gfx.text(TR("hint_touch"), 16 * u, h - 30 * u, 15 * u, "semibold")
end

return U
