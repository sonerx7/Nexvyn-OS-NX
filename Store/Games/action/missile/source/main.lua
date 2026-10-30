-- Füze Savunması / Missile Defense for Nexvyn OS: a Missile Command-style game. Aim with the stick, d-pad,
-- mouse or touch and fire counter-missiles from three batteries; their blasts chain through the incoming
-- warheads. Splitting missiles, wave bonuses, rebuilt cities and an AI defender behind the title.
local K = require("arcade")
local floor, min, max, abs, sqrt, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sqrt, math.sin,
  math.cos, math.pi
local random = math.random

local W, H = 800, 600
local GROUND = 560
local G = {icon = "crisis_alert", accent = "#FF6A3D", overIcon = "location_city"}

local S, OX, OY = 1, 0, 0
local BASES = {{x = 60}, {x = 400}, {x = 740}}
local CITIES = {{x = 150}, {x = 225}, {x = 300}, {x = 500}, {x = 575}, {x = 650}}
local enemies, shots, blasts = {}, {}, {}
local cursor = {x = W / 2, y = 300, vx = 0, vy = 0}
local STARS = {}
for i = 1, 80 do STARS[i] = {random() * W, random() * 420, random() * 1.3 + 0.3, random() * 6} end
local wave, toLaunch, launchT, waveDone, bonusT = 1, 0, 0, false, 0
local killed, fired, nextCity = 0, 0, 10000
local aiT = 0
local HS = {18, 30, 24, 36, 20}
local PIPS = {}                       -- ammo pip layout: rows of 4, 3, 2, 1
for _, r in ipairs({{4, 0}, {3, 1}, {2, 2}, {1, 3}}) do
  for k = 1, r[1] do PIPS[#PIPS + 1] = {(k - (r[1] + 1) / 2) * 9, r[2] * 7} end
end

function G.controls() return {TR("c_aim"), TR("c_fire"), TR("c_base"), TR("c_touch")} end

function G.layout(w, h)
  S = min(w / W, h / H)
  OX, OY = floor((w - W * S) / 2), floor((h - H * S) / 2)
end

local function aliveCities()
  local n = 0
  for _, c in ipairs(CITIES) do if c.alive then n = n + 1 end end
  return n
end

local function startWave()
  for _, b in ipairs(BASES) do b.ammo, b.alive = 10, true end
  toLaunch = 8 + wave * 2
  launchT = 1.2
  waveDone = false
  enemies, shots = {}, {}
end

function G.reset()
  wave = 1
  killed, fired, nextCity = 0, 0, 10000
  for _, c in ipairs(CITIES) do c.alive, c.hitT = true, 0 end
  blasts = {}
  cursor.x, cursor.y = W / 2, 300
  startWave()
end

local function targets()
  -- a random living city or base
  local list = {}
  for _, c in ipairs(CITIES) do if c.alive then list[#list + 1] = c.x end end
  for _, b in ipairs(BASES) do if b.alive then list[#list + 1] = b.x end end
  if #list == 0 then return random() * W end
  return list[random(#list)]
end

local function launchEnemy(sx, sy, tx)
  local speed = 34 + wave * 7 + random() * 10
  local dx, dy = tx - sx, GROUND - sy
  local d = sqrt(dx * dx + dy * dy)
  enemies[#enemies + 1] = {sx = sx, sy = sy, x = sx, y = sy, vx = dx / d * speed, vy = dy / d * speed,
    split = wave >= 3 and random() < 0.18 and sy < 100}
end

local function fireFrom(bi, tx, ty)
  local b = BASES[bi]
  if not b or not b.alive or b.ammo <= 0 then return false end
  ty = min(ty, GROUND - 50)
  b.ammo = b.ammo - 1
  local speed = bi == 2 and 760 or 560
  local sx, sy = b.x, GROUND - 26
  local dx, dy = tx - sx, ty - sy
  local d = max(1, sqrt(dx * dx + dy * dy))
  shots[#shots + 1] = {sx = sx, sy = sy, x = sx, y = sy, tx = tx, ty = ty, vx = dx / d * speed, vy = dy / d * speed,
    left = d / speed}
  if K.state == "play" then
    fired = fired + 1
    K.chord({660, 990}, 0.06, 0.07, "saw")
  end
  return true
end

-- nearest battery with ammo
local function fireNearest(tx, ty)
  local best, bd = nil, 1e9
  for i, b in ipairs(BASES) do
    if b.alive and b.ammo > 0 then
      local d = abs(b.x - tx) + (i == 2 and -40 or 0)
      if d < bd then best, bd = i, d end
    end
  end
  if best then return fireFrom(best, tx, ty) end
  if K.state == "play" then K.tone(140, 0.08, 0.1, "square") end
  return false
end

function G.press(act)
  if act == "a" then fireNearest(cursor.x, cursor.y)
  elseif act == "l" or act == "zl" or act == "x" then fireFrom(1, cursor.x, cursor.y)
  elseif act == "b" or act == "y" then fireFrom(2, cursor.x, cursor.y)
  elseif act == "r" or act == "zr" then fireFrom(3, cursor.x, cursor.y) end
end

function G.pointer(e)
  local x, y = (e.x - OX) / S, (e.y - OY) / S
  if e.type == "mousemove" then
    cursor.x, cursor.y = K.clamp(x, 0, W), K.clamp(y, 0, GROUND - 50)
  elseif e.type == "mousedown" then
    cursor.x, cursor.y = K.clamp(x, 0, W), K.clamp(y, 0, GROUND - 50)
    if e.button == "right" then fireFrom(2, cursor.x, cursor.y) else fireNearest(cursor.x, cursor.y) end
  end
end

local function blast(x, y, big, mine)
  blasts[#blasts + 1] = {x = x, y = y, t = 0, r = big and 56 or 44, mine = mine, chain = 0}
  K.burst(x, y, mine and 10 or 16, mine and "#FFD60A" or "#FF6A3D", 120, 0.5, 2.5)
end

local function hitGround(e, playing)
  blast(e.x, e.y, false, false)
  K.shake(9)
  for _, c in ipairs(CITIES) do
    if c.alive and abs(c.x - e.x) < 34 then
      c.alive = false
      K.burst(c.x, GROUND - 12, 40, "#FF9F0A", 180, 1.0, 3, 120)
      if playing then
        K.sfx("boom")
        K.flash("#FF453A40", 0.3)
        K.vibrate(0.9, 200)
        K.callout(TR("city_lost"), "#FF453A", 30, "city")
      end
    end
  end
  for _, b in ipairs(BASES) do
    if b.alive and abs(b.x - e.x) < 34 then
      b.alive, b.ammo = false, 0
      K.burst(b.x, GROUND - 16, 30, "#64D2FF", 160, 0.8, 3, 120)
      if playing then K.sfx("boom", 0.8) end
    end
  end
end

local function simulate(dt, demo)
  local playing = not demo
  -- cursor
  if demo then
    aiT = aiT - dt
    local tgt = nil
    for _, e in ipairs(enemies) do if not tgt or e.y > tgt.y then tgt = e end end
    if tgt then
      local lead = 0.9
      cursor.x = K.smooth(cursor.x, tgt.x + tgt.vx * lead, 6, dt)
      cursor.y = K.smooth(cursor.y, min(GROUND - 60, tgt.y + tgt.vy * lead), 6, dt)
      if aiT <= 0 and tgt.y > 160 then
        aiT = 0.9
        fireNearest(cursor.x, cursor.y)
      end
    end
  else
    local ax, ay = K.axis()
    cursor.vx = K.smooth(cursor.vx, ax * 560, 14, dt)
    cursor.vy = K.smooth(cursor.vy, ay * 560, 14, dt)
    cursor.x = K.clamp(cursor.x + cursor.vx * dt, 0, W)
    cursor.y = K.clamp(cursor.y + cursor.vy * dt, 20, GROUND - 50)
  end
  -- launch
  if toLaunch > 0 then
    launchT = launchT - dt
    if launchT <= 0 then
      local n = min(toLaunch, random(1, min(4, 1 + floor(wave / 2))))
      for _ = 1, n do launchEnemy(random() * W, -5, targets()) end
      toLaunch = toLaunch - n
      launchT = max(0.8, 3.2 - wave * 0.2) * (0.6 + random() * 0.8)
    end
  end
  -- enemies
  local i = 1
  while i <= #enemies do
    local e = enemies[i]
    e.x, e.y = e.x + e.vx * dt, e.y + e.vy * dt
    local dead = false
    if e.split and e.y > 220 then
      e.split = false
      for _ = 1, 2 do launchEnemy(e.x, e.y, targets()) end
      enemies[#enemies].sx, enemies[#enemies].sy = e.x, e.y
      if playing then K.tone(1400, 0.05, 0.05, "square") end
    end
    if e.y >= GROUND - 6 then
      hitGround(e, playing)
      dead = true
    else
      for _, b in ipairs(blasts) do
        local r = b.cur or 0
        if (e.x - b.x) ^ 2 + (e.y - b.y) ^ 2 < r * r then
          dead = true
          b.chain = b.chain + 1
          blast(e.x, e.y, false, true)
          blasts[#blasts].chain = b.chain
          if playing then
            killed = killed + 1
            local c = K.comboHit(1.2, "#FFD60A")
            local pts = 25 * min(c, 8) * (1 + floor((wave - 1) / 2))
            K.addScore(pts)
            K.popup(e.x, e.y - 14, "+" .. pts, c > 1 and "#FFD60A" or "#FFFFFF")
            K.sfx("small", 0.7)
            K.shake(3)
          end
          break
        end
      end
    end
    if dead then table.remove(enemies, i) else i = i + 1 end
  end
  -- counter-missiles
  i = 1
  while i <= #shots do
    local s = shots[i]
    s.left = s.left - dt
    if s.left <= 0 then
      blast(s.tx, s.ty, false, true)
      if playing then K.sfx("boom", 0.35) end
      table.remove(shots, i)
    else
      s.x, s.y = s.x + s.vx * dt, s.y + s.vy * dt
      i = i + 1
    end
  end
  -- blasts grow and fade
  i = 1
  while i <= #blasts do
    local b = blasts[i]
    b.t = b.t + dt
    local f = b.t / 1.0
    if f < 0.45 then b.cur = b.r * K.easeOut(f / 0.45) else b.cur = b.r * (1 - K.easeIn((f - 0.45) / 0.55)) end
    if f >= 1 then table.remove(blasts, i) else i = i + 1 end
  end
  for _, c in ipairs(CITIES) do if c.hitT and c.hitT > 0 then c.hitT = c.hitT - dt end end
  -- wave end
  if toLaunch <= 0 and #enemies == 0 and #blasts == 0 and #shots == 0 and not waveDone then
    waveDone = true
    bonusT = 2.2
    if playing then
      local ammo = 0
      for _, b in ipairs(BASES) do ammo = ammo + b.ammo end
      local cities = aliveCities()
      local bonus = ammo * 5 + cities * 100
      K.addScore(bonus)
      K.callout(TR("bonus_n", bonus), "#FFD60A", 34, "bonus", 2)
      K.sfx("level")
      if cities == 0 then
        K.over({stats = {{TR("wave"), tostring(wave)}, {TR("destroyed"), tostring(killed)},
          {TR("accuracy"), (fired > 0 and floor(killed / fired * 100 + 0.5) or 0) .. "%"}}})
        return
      end
      if K.score >= nextCity then
        nextCity = nextCity + 10000
        for _, c in ipairs(CITIES) do
          if not c.alive then
            c.alive = true
            K.callout(TR("rebuilt"), "#32D74B", 30, "rebuilt", 2)
            break
          end
        end
      end
    end
  end
  if waveDone then
    bonusT = bonusT - dt
    if bonusT <= 0 then
      wave = wave + 1
      if demo then
        if aliveCities() == 0 or wave > 6 then G.reset() return end
      elseif playing then
        K.callout(TR("wave_n", wave), "#FF6A3D", 40, "wave", 1.4)
      end
      startWave()
    end
  end
  if playing and aliveCities() == 0 and #enemies > 0 and toLaunch >= 0 then
    -- every city gone: end as soon as the sky is clear
    toLaunch = 0
  end
end

function G.update(dt) simulate(dt, false) end
function G.idle(dt) if K.state == "title" then simulate(dt, true) end end

-- ------------------------------------------------------------------ drawing
local function city(x, ox, oy, alive, t)
  local X, Y = ox + x * S, oy + GROUND * S
  if not alive then
    K.color("#3A2A2A")
    gfx.rect(X - 26 * S, Y - 8 * S, 52 * S, 8 * S, 2 * S)
    K.color("#FF6A3D", 0.4 + 0.3 * sin(t * 6 + x))
    gfx.circle(X - 8 * S, Y - 8 * S, 3 * S)
    return
  end
  local hs = HS
  for k = 1, 5 do
    local bx = X + (k - 3) * 10 * S - 5 * S
    local bh = hs[k] * S
    K.color(k % 2 == 0 and "#3A6EA5" or "#2D5A8A")
    gfx.rect(bx, Y - bh, 10 * S, bh, 2 * S)
    K.color("#FFE08A", 0.85)
    for wy = 1, floor(hs[k] / 8) do
      if (k * 7 + wy * 3 + x) % 4 ~= 0 then gfx.rect(bx + 3 * S, Y - bh + wy * 7 * S - 3 * S, 3 * S, 3 * S) end
    end
  end
end

function G.draw(w, h)
  local t = K.now
  gfx.gradient(0, 0, w, h, "#060318", "#2A0F2E")
  local sx, sy = K.shakeXY()
  local ox, oy = OX + sx, OY + sy
  for i = 1, #STARS do
    local st = STARS[i]
    K.color("#FFFFFF", 0.2 + 0.25 * (0.5 + 0.5 * sin(t * 1.5 + st[4])))
    gfx.circle(ox + st[1] * S, oy + st[2] * S, st[3] * S)
  end
  -- ground
  K.color("#3B2A1A")
  gfx.rect(ox, oy + GROUND * S, W * S, (H - GROUND) * S + 40)
  K.color("#C98A3D")
  gfx.rect(ox, oy + GROUND * S, W * S, 4 * S)
  for _, c in ipairs(CITIES) do city(c.x, ox, oy, c.alive, t) end
  -- batteries with ammo pips
  for i, b in ipairs(BASES) do
    local X, Y = ox + b.x * S, oy + GROUND * S
    K.color(b.alive and "#8E6A3F" or "#3A2A2A")
    gfx.circle(X, Y, 30 * S)
    if b.alive then
      K.color("#64D2FF")
      gfx.rect(X - 4 * S, Y - 30 * S, 8 * S, 12 * S, 3 * S)
      K.color(i == 2 and "#FFD60A" or "#FFFFFF")
      for k = 1, b.ammo do
        local pp = PIPS[k]
        gfx.rect(X + (pp[1] - 2) * S, Y + (pp[2] - 6) * S, 4 * S, 5 * S, 1)
      end
      if b.ammo <= 3 then
        K.color("#FF453A", 0.6 + 0.4 * sin(t * 8))
        gfx.text(b.ammo == 0 and TR("out") or TR("low"), X - 40 * S, Y - 52 * S, max(10, floor(12 * S)), "bold", "center", 80 * S)
      end
    end
  end
  -- enemy trails
  for _, e in ipairs(enemies) do
    K.color("#FF453A", 0.55)
    gfx.line(ox + e.sx * S, oy + e.sy * S, ox + e.x * S, oy + e.y * S, 2 * S)
    K.color("#FFFFFF")
    gfx.circle(ox + e.x * S, oy + e.y * S, 2.5 * S)
    K.color("#FF453A", 0.4 + 0.4 * sin(t * 20))
    gfx.circle(ox + e.x * S, oy + e.y * S, 5 * S)
  end
  -- counter-missiles and their targets
  for _, s in ipairs(shots) do
    K.color("#64D2FF", 0.6)
    gfx.line(ox + s.sx * S, oy + s.sy * S, ox + s.x * S, oy + s.y * S, 2 * S)
    K.color("#FFFFFF")
    gfx.circle(ox + s.x * S, oy + s.y * S, 3 * S)
    K.color("#64D2FF", 0.8)
    local X, Y = ox + s.tx * S, oy + s.ty * S
    gfx.line(X - 6 * S, Y - 6 * S, X + 6 * S, Y + 6 * S, 2)
    gfx.line(X - 6 * S, Y + 6 * S, X + 6 * S, Y - 6 * S, 2)
  end
  -- blasts with a color cycle
  for _, b in ipairs(blasts) do
    local r = (b.cur or 0) * S
    if r > 0.5 then
      local f = b.t
      K.hsv((t * 3 + b.x * 0.01) % 1, 0.7, 1, 0.35 * (1 - f))
      gfx.circle(ox + b.x * S, oy + b.y * S, r * 1.15)
      K.hsv((t * 3 + 0.3 + b.x * 0.01) % 1, 0.5, 1, 0.9 * (1 - f * 0.6))
      gfx.circle(ox + b.x * S, oy + b.y * S, r)
      K.color("#FFFFFF", 0.8 * (1 - f))
      gfx.circle(ox + b.x * S, oy + b.y * S, r * 0.45)
    end
  end
  K.drawParticles(S, ox, oy)
  K.drawPopups(S, ox, oy, 16)
  -- crosshair
  if K.state == "play" then
    local X, Y = ox + cursor.x * S, oy + cursor.y * S
    local r = 14 * S + sin(t * 6) * 2
    K.color("#FFFFFF", 0.9)
    gfx.circleLine(X, Y, r, 2)
    gfx.line(X - r - 6, Y, X - r + 6, Y, 2)
    gfx.line(X + r - 6, Y, X + r + 6, Y, 2)
    gfx.line(X, Y - r - 6, X, Y - r + 6, 2)
    gfx.line(X, Y + r - 6, X, Y + r + 6, 2)
    gfx.circle(X, Y, 2)
  end
  -- HUD
  local x = 12
  x = x + K.scorePill(x, 8) + 8
  x = x + K.pill(x, 8, "flag", TR("wave_n", wave), "#FF6A3D") + 8
  K.pill(x, 8, "location_city", tostring(aliveCities()), "#64D2FF")
  K.bestPill(w - 60, 8)
end

return K.run(G)
