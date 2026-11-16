-- Isle Defense: the battle. Raiders walk the fixed route from the sea portal to the heart, towers on the pads shoot
-- them, waves come on a clock or when called early. Simulation and the 3D drawing of towers, raiders and shots.
local D = require("id_data")
local Wd = require("id_world")
local F = require("id_fx")
local G = {}
local sin, cos, sqrt, floor, min, max, abs, pi, random, atan = math.sin, math.cos, math.sqrt, math.floor, math.min, math.max, math.abs, math.pi, math.random, math.atan

G.emit = function() end      -- event sink (sound, messages); set by main
local S                      -- world scene
local path                   -- {pts = {{x, z, s}...}, len}
local enemies, shots, towers = {}, {}, {}
local pool = {}              -- model handles per foe model
G.enemies, G.towers = enemies, towers

-- ------------------------------------------------------------------ route
local function buildPath()
  local r = S.route
  local pts, s = {}, 0
  for k = 1, #r do
    if k > 1 then
      local dx, dz = r[k][1] - r[k - 1][1], r[k][3] - r[k - 1][3]
      s = s + sqrt(dx * dx + dz * dz)
    end
    pts[k] = {r[k][1], r[k][3], s}
  end
  path = {pts = pts, len = s}
  G.path = path
end

-- position, direction and lane-offset point at distance s along the route
local function along(s, lane)
  local p = path.pts
  if s <= 0 then s = 0 end
  local k = 1
  while k < #p - 1 and p[k + 1][3] < s do k = k + 1 end
  local a, b = p[k], p[k + 1]
  local seg = b[3] - a[3]
  local f = seg > 0 and min(1, (s - a[3]) / seg) or 0
  local dx, dz = (b[1] - a[1]) / max(seg, 1e-3), (b[2] - a[2]) / max(seg, 1e-3)
  local x, z = a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f
  -- round the corners a little: blend towards the next segment's direction near its end
  if k + 2 <= #p and seg - (s - a[3]) < 1.2 then
    local c = p[k + 2]
    local s2 = c[3] - b[3]
    local ex, ez = (c[1] - b[1]) / max(s2, 1e-3), (c[2] - b[2]) / max(s2, 1e-3)
    local w = 1 - (seg - (s - a[3])) / 1.2
    dx, dz = dx + (ex - dx) * w * 0.5, dz + (ez - dz) * w * 0.5
  end
  lane = lane or 0
  return x - dz * lane, z + dx * lane, dx, dz
end
G.along = along

-- ------------------------------------------------------------------ state
local st = {}
G.st = st

local function towerStat(tw, key)
  local d = D.TOWER[tw.id]
  local v = d[key]
  return v and v[tw.tier] or nil
end
G.towerStat = towerStat

function G.new(isleIndex, run)
  S = Wd.S
  buildPath()
  for k in pairs(st) do st[k] = nil end
  for i = #enemies, 1, -1 do enemies[i] = nil end
  for i = #shots, 1, -1 do shots[i] = nil end
  for k in pairs(towers) do towers[k] = nil end
  st.isle = isleIndex
  st.gold = D.ISLES[isleIndex].gold
  st.lives = D.LIVES
  st.wave = 0                   -- waves started
  st.waves = #D.WAVES[isleIndex]
  st.active = false             -- a wave is spawning or raiders are alive
  st.breakT = 22                -- seconds before the first wave
  st.spawns = {}
  st.time = 0
  st.kills = 0
  st.over = nil                 -- "win" | "lose"
  st.spent = 0
  if run then
    st.gold, st.lives, st.wave, st.time, st.kills = run.gold, run.lives, run.wave, run.time or 0, run.kills or 0
    st.breakT = D.BREAK
    for _, t in ipairs(run.towers or {}) do
      if S.pads[t.pad] and D.TOWER[t.id] then
        towers[t.pad] = {id = t.id, tier = t.tier, pad = t.pad, cd = 0, yaw = 0, spent = t.spent or D.TOWER[t.id].cost, built = 1}
      end
    end
  end
  G.recalcAura()
end

function G.snapshot()
  local list = {}
  for pad, t in pairs(towers) do list[#list + 1] = {pad = pad, id = t.id, tier = t.tier, spent = t.spent} end
  return {isle = st.isle, gold = st.gold, lives = st.lives, wave = st.wave, time = st.time, kills = st.kills, towers = list}
end

-- ------------------------------------------------------------------ towers
function G.recalcAura()
  for _, t in pairs(towers) do t.aura = 0 end
  for pad, s in pairs(towers) do
    if s.id == "shrine" then
      local p = S.pads[pad]
      local r = towerStat(s, "range")
      for pad2, t in pairs(towers) do
        if t.id ~= "shrine" then
          local q = S.pads[pad2]
          local dx, dz = q[1] - p[1], q[3] - p[3]
          if dx * dx + dz * dz <= r * r then t.aura = max(t.aura, towerStat(s, "aura")) end
        end
      end
    end
  end
end

function G.canBuild(pad, id)
  return not towers[pad] and st.gold >= D.TOWER[id].cost
end

function G.build(pad, id)
  local d = D.TOWER[id]
  if towers[pad] or st.gold < d.cost then G.emit("error"); return false end
  st.gold = st.gold - d.cost
  towers[pad] = {id = id, tier = 1, pad = pad, cd = 0.3, yaw = 0, spent = d.cost, built = 0, aura = 0}
  local p = S.pads[pad]
  F.burst("dust", p[1], p[2] + 0.2, p[3], 14, 3.5, 0.8, 0.9)
  G.emit("build", id, p)
  G.recalcAura()
  return true
end

function G.upgradeCost(pad)
  local t = towers[pad]
  if not t or t.tier >= 3 then return nil end
  return D.TOWER[t.id].up[t.tier]
end

function G.upgrade(pad)
  local t = towers[pad]
  local c = G.upgradeCost(pad)
  if not c or st.gold < c then G.emit("error"); return false end
  st.gold = st.gold - c
  t.spent = t.spent + c
  t.tier = t.tier + 1
  t.built = 0.4
  local p = S.pads[pad]
  F.burst("gold", p[1], p[2] + 1.5, p[3], 26, 3.5, 0.9, 0.25)
  G.emit("upgrade", t.id, p)
  G.recalcAura()
  return true
end

function G.sellValue(pad)
  local t = towers[pad]
  return t and floor(t.spent * D.SELL) or 0
end

function G.sell(pad)
  local t = towers[pad]
  if not t then return false end
  st.gold = st.gold + G.sellValue(pad)
  towers[pad] = nil
  local p = S.pads[pad]
  F.burst("gold", p[1], p[2] + 1, p[3], 18, 3, 0.8, 0.22)
  F.burst("dust", p[1], p[2] + 0.2, p[3], 12, 3, 0.8, 0.9)
  G.emit("sell", p)
  G.recalcAura()
  return true
end

-- ------------------------------------------------------------------ raiders
local function takeModel(name)
  local list = pool[name]
  if list and #list > 0 then return table.remove(list) end
  return g3d.model("bundle:/models/foes/" .. name .. ".glb")
end
local function giveModel(name, m)
  if not m then return end
  pool[name] = pool[name] or {}
  local list = pool[name]
  if #list < 24 then list[#list + 1] = m end
end

local CLIP = {hero = {"walk", 1.7, "run", 4.2}, creature = {"walk", 0.62, "run", 1.64}, drone = {"hover", 1.5, "hover", 4.0}}

local function spawnFoe(id, s, lane)
  local f = D.FOES[id]
  local hp = f.hp * D.hpScale(st.isle, max(1, st.wave))
  local m = takeModel(f.model)
  local e = {id = id, f = f, s = s or 0, lane = lane or (random() - 0.5) * 1.2, hp = hp, max = hp, slow = 0, slowT = 0, burn = 0,
             burnT = 0, flash = 0, m = m, dead = false, deadT = 0, healT = random(), y = 0, x = 0, z = 0, yaw = 0, bobP = random() * 6}
  if m then
    local c = CLIP[f.base]
    local fast = f.speed > 2.6 or f.base == "creature"
    local clip, cs = fast and c[3] or c[1], fast and c[4] or c[2]
    m:play(clip, {loop = true, speed = max(0.4, f.speed / (cs * f.scale)), fade = 0})
    m:time(random() * 0.8)
  end
  enemies[#enemies + 1] = e
  local x, z = along(e.s, e.lane)
  e.x, e.z = x, z
  if (s or 0) < 1 then
    F.splash(x, S.waterY, z, 8)
    if random() < 0.3 then G.emit("splash", x, z) end
  end
  return e
end
G.spawnFoe = spawnFoe

local function hurt(e, amount, kind)
  if e.dead then return end
  if kind == "phys" and e.f.armor then amount = amount * (1 - e.f.armor) end
  e.hp = e.hp - amount
  e.flash = 0.12
  if e.hp <= 0 then
    e.dead = true
    e.deadT = 0
    st.gold = st.gold + e.f.gold
    st.kills = st.kills + 1
    local y = e.y + (e.f.air and 0 or 0.8)
    F.burst("gold", e.x, y + 0.6, e.z, e.f.boss and 40 or 6, 2.5, 0.8, 0.18)
    if e.f.air then
      F.burst("spark", e.x, e.y, e.z, 14, 4, 0.6, 0.18)
      F.burst("smoke", e.x, e.y, e.z, 4, 1, 1.0, 0.8)
    else
      F.burst("dust", e.x, e.y + 0.3, e.z, 6, 1.6, 0.6, 0.6)
    end
    if e.m then
      local c = e.m:play("death", {loop = false, speed = 1.2, fade = 0.08})
      if not c then e.m:play("hit", {loop = false}) end
    end
    G.emit("kill", e)
    if e.f.split then
      for k = 1, e.f.split do
        local c = spawnFoe("splitling", max(0, e.s - (k - 1) * 0.7), (k - 2) * 0.55)
        c.hp, c.max = c.hp * 0.9, c.max * 0.9
      end
      F.burst("magic", e.x, e.y + 0.6, e.z, 14, 2.5, 0.5, 0.3)
      G.emit("split", e)
    end
  end
end
G.hurt = hurt

local function foePos(e)
  return e.x, e.y + (e.f.air and 0 or 0.9 * e.f.scale), e.z
end
G.foePos = foePos

-- ------------------------------------------------------------------ waves
function G.callWave()
  if st.over or st.wave >= st.waves then return false end
  if st.spawning then return false end
  local bonus = 0
  if st.wave > 0 and st.breakT > 0 then bonus = floor(st.breakT * D.EARLY_BONUS) end
  st.gold = st.gold + bonus
  st.wave = st.wave + 1
  st.spawning = true
  st.waveT = 0
  st.spawns = {}
  local boss = false
  for _, g in ipairs(D.WAVES[st.isle][st.wave]) do
    for i = 1, g.n do st.spawns[#st.spawns + 1] = {t = g.at + (i - 1) * g.gap, id = g.foe} end
    if D.FOES[g.foe].boss then boss = true end
  end
  table.sort(st.spawns, function(a, b) return a.t < b.t end)
  st.breakT = 0
  G.emit("wave", st.wave, boss, bonus)
  return true
end

function G.preview(w)
  local list = D.WAVES[st.isle][w or (st.wave + 1)]
  if not list then return nil end
  local counts, order = {}, {}
  for _, g in ipairs(list) do
    if not counts[g.foe] then order[#order + 1] = g.foe end
    counts[g.foe] = (counts[g.foe] or 0) + g.n
  end
  local out = {}
  for _, id in ipairs(order) do out[#out + 1] = {id = id, n = counts[id]} end
  return out
end

-- ------------------------------------------------------------------ targeting and shots
local function inRange(e, x, z, r)
  local dx, dz = e.x - x, e.z - z
  return dx * dx + dz * dz <= r * r
end

local function pickTarget(t, p, r, air)
  local best, bs = nil, -1
  for _, e in ipairs(enemies) do
    if not e.dead and (air or not e.f.air) and e.s > 0.5 and inRange(e, p[1], p[3], r) then
      if e.s > bs then best, bs = e, e.s end
    end
  end
  return best
end

local function towerTop(t, p)
  local h = ({archer = 4.3, cannon = 2.3, frost = 2.9, fire = 1.3, storm = 3.6, shrine = 2.4})[t.id] or 2
  return p[1], p[2] + h * (1.3 + (t.tier - 1) * 0.12), p[3]
end
G.towerTop = towerTop

local function fire(t, p, e, dt)
  local d = D.TOWER[t.id]
  local dmg = towerStat(t, "dmg") * (1 + (t.aura or 0))
  local x, y, z = towerTop(t, p)
  local ex, ey, ez = foePos(e)
  t.yaw = atan(ex - p[1], ez - p[3])
  if t.id == "archer" then
    shots[#shots + 1] = {kind = "arrow", x = x, y = y, z = z, e = e, sp = 30, dmg = dmg}
    if t.tier == 3 then
      -- volley: a second arrow at another raider in range
      local e2
      for _, o in ipairs(enemies) do
        if o ~= e and not o.dead and inRange(o, p[1], p[3], towerStat(t, "range")) then e2 = o break end
      end
      if e2 then shots[#shots + 1] = {kind = "arrow", x = x, y = y, z = z, e = e2, sp = 30, dmg = dmg * 0.8} end
    end
    G.emit("shot", "archer", p)
  elseif t.id == "cannon" then
    -- lead the target: where it will be when the ball lands
    local dist = sqrt((ex - x) ^ 2 + (ez - z) ^ 2)
    local tt = 0.45 + dist / 22
    local f = e.f.speed * (1 - e.slow)
    local lx, lz = along(e.s + f * tt, e.lane)
    shots[#shots + 1] = {kind = "ball", x0 = x, y0 = y, z0 = z, x1 = lx, y1 = Wd.heightAt(lx, lz), z1 = lz, t = 0, T = tt, dmg = dmg,
                         r = towerStat(t, "splash")}
    F.burst("smoke", x, y, z, 5, 1.6, 0.9, 0.7)
    F.burst("fire", x, y, z, 6, 2.5, 0.25, 0.5)
    t.recoil = 0.25
    G.emit("shot", "cannon", p)
  elseif t.id == "frost" then
    shots[#shots + 1] = {kind = "frost", x = x, y = y, z = z, e = e, sp = 18, dmg = dmg, slow = towerStat(t, "slow"), r = towerStat(t, "splash")}
    G.emit("shot", "frost", p)
  elseif t.id == "storm" then
    local hit, cur = {[e] = true}, e
    local n = towerStat(t, "chain")
    local cx, cy, cz = x, y, z
    local k = dmg
    for _ = 1, n do
      local tx, ty, tz = foePos(cur)
      F.bolt(cx, cy, cz, tx, ty, tz)
      hurt(cur, k, "magic")
      cx, cy, cz = tx, ty, tz
      k = k * 0.85
      local nxt, nd = nil, 4.8 * 4.8
      for _, o in ipairs(enemies) do
        if not o.dead and not hit[o] then
          local dx, dz = o.x - cur.x, o.z - cur.z
          local dd = dx * dx + dz * dz
          if dd < nd then nxt, nd = o, dd end
        end
      end
      if not nxt then break end
      hit[nxt] = true
      cur = nxt
    end
    G.emit("shot", "storm", p)
  end
end

local function updateShots(dt)
  local i = 1
  while i <= #shots do
    local s = shots[i]
    local done = false
    if s.kind == "ball" then
      s.t = s.t + dt
      local f = min(1, s.t / s.T)
      s.x = s.x0 + (s.x1 - s.x0) * f
      s.z = s.z0 + (s.z1 - s.z0) * f
      s.y = s.y0 + (s.y1 - s.y0) * f + sin(f * pi) * (2.5 + s.T * 3)
      if random() < 0.5 then F.spawn("smoke", s.x, s.y, s.z, 0, 0.2, 0, 0.5, 0.25, 0.5) end
      if f >= 1 then
        done = true
        F.explosion(s.x1, s.y1, s.z1, 0.6 + s.r * 0.25)
        G.emit("boom", s.x1, s.z1)
        for _, e in ipairs(enemies) do
          if not e.dead and not e.f.air and inRange(e, s.x1, s.z1, s.r) then hurt(e, s.dmg, "phys") end
        end
      end
    else
      local e = s.e
      local tx, ty, tz
      if e and not e.dead then tx, ty, tz = foePos(e); s.lx, s.ly, s.lz = tx, ty, tz else tx, ty, tz = s.lx, s.ly, s.lz end
      if not tx then done = true else
        local dx, dy, dz = tx - s.x, ty - s.y, tz - s.z
        local d = sqrt(dx * dx + dy * dy + dz * dz)
        local step = s.sp * dt
        if d <= step + 0.15 then
          done = true
          if e and not e.dead then
            if s.kind == "arrow" then
              hurt(e, s.dmg, "phys")
              G.emit("hit", e)
            elseif s.kind == "frost" then
              local function chill(o)
                hurt(o, s.dmg, "magic")
                if not o.dead then o.slow = max(o.slow, s.slow); o.slowT = D.TOWER.frost.slowT end
              end
              chill(e)
              if s.r and s.r > 0 then
                for _, o in ipairs(enemies) do
                  if o ~= e and not o.dead and inRange(o, e.x, e.z, s.r) then chill(o) end
                end
              end
              F.frostHit(tx, ty, tz, s.r)
            end
          end
        else
          s.x, s.y, s.z = s.x + dx / d * step, s.y + dy / d * step, s.z + dz / d * step
          s.dx, s.dy, s.dz = dx / d, dy / d, dz / d
          if s.kind == "frost" and random() < 0.7 then F.spawn("frost", s.x, s.y, s.z, 0, 0, 0, 0.3, 0.25, -0.4) end
        end
      end
    end
    if done then table.remove(shots, i) else i = i + 1 end
  end
end

-- ------------------------------------------------------------------ update
function G.update(dt)
  if st.over then
    for _, e in ipairs(enemies) do if e.m then e.m:update(dt) end end
    F.update(dt)
    return
  end
  st.time = st.time + dt
  -- waves
  if st.spawning then
    st.waveT = st.waveT + dt
    while #st.spawns > 0 and st.spawns[1].t <= st.waveT do
      local sp = table.remove(st.spawns, 1)
      spawnFoe(sp.id)
      if D.FOES[sp.id].boss then G.emit("boss") end
    end
    if #st.spawns == 0 then st.spawning = false end
  end
  local alive = 0
  for _, e in ipairs(enemies) do if not e.dead then alive = alive + 1 end end
  if not st.spawning and alive == 0 and st.wave > 0 and not st.cleared then
    st.cleared = true
    -- end of a wave: shrine income
    local inc = 0
    for _, t in pairs(towers) do if t.id == "shrine" then inc = inc + towerStat(t, "income") end end
    st.gold = st.gold + inc
    if st.wave >= st.waves then
      st.over = "win"
      G.emit("win", D.stars(st.lives))
      return
    end
    st.breakT = D.BREAK
    G.emit("cleared", st.wave, inc)
  end
  if st.wave == 0 or st.cleared then
    if st.breakT > 0 then
      st.breakT = st.breakT - dt
      if st.breakT <= 0 then st.cleared = false; G.callWave() end
    end
  end
  if st.spawning then st.cleared = false end
  -- raiders
  local i = 1
  while i <= #enemies do
    local e = enemies[i]
    local f = e.f
    if e.m then e.m:update(dt) end
    if e.dead then
      e.deadT = e.deadT + dt
      if e.deadT > (f.air and 0.5 or 1.4) then
        giveModel(f.model, e.m)
        table.remove(enemies, i)
      else
        if f.air then e.y = e.y - dt * 6 end
        i = i + 1
      end
    else
      if e.slowT > 0 then e.slowT = e.slowT - dt; if e.slowT <= 0 then e.slow = 0 end end
      if e.burnT > 0 then
        e.burnT = e.burnT - dt
        hurt(e, e.burn * dt, "magic")
        if random() < dt * 10 then F.spawn("fire", e.x, e.y + 0.8 * f.scale, e.z, 0, 1.2, 0, 0.35, 0.45, -0.4) end
      end
      e.flash = max(0, e.flash - dt)
      if f.heal then
        e.healT = e.healT - dt
        if e.healT <= 0 then
          e.healT = 1
          local any = false
          for _, o in ipairs(enemies) do
            if o ~= e and not o.dead and o.hp < o.max and inRange(o, e.x, e.z, f.healR) then
              o.hp = min(o.max, o.hp + f.heal)
              any = true
              F.burst("heal", o.x, o.y + 1.0, o.z, 3, 1.2, 0.6, 0.35)
            end
          end
          F.burst("heal", e.x, e.y + 1.6, e.z, any and 10 or 3, 1.6, 0.7, 0.4)
          if any then G.emit("heal", e) end
        end
      end
      if not e.dead then
        local sp = f.speed * (1 - e.slow)
        e.s = e.s + sp * dt
        if e.s >= path.len then
          -- at the heart
          e.dead, e.deadT, e.reached = true, 10, true
          st.lives = max(0, st.lives - f.lives)
          S.heartHit = 0.6
          F.burst("heart", S.heart[1], S.heart[2] + 2.2, S.heart[3], 24, 4, 0.7, 0.3)
          G.emit("leak", f.lives)
          if st.lives <= 0 then
            st.over = "lose"
            G.emit("lose")
          end
        else
          local x, z, dx, dz = along(e.s, e.lane)
          e.yaw = atan(dx, dz)
          e.x, e.z = x, z
          local gy = Wd.heightAt(x, z)
          if f.air then
            e.y = max(gy, S.waterY) + 3.4 + sin(st.time * 3 + e.bobP) * 0.25
          else
            e.y = gy
            if gy < S.waterY - 0.2 and random() < dt * 4 then F.splash(x, S.waterY, z, 2) end
          end
        end
      end
      i = i + 1
    end
  end
  if S.heartHit then S.heartHit = S.heartHit - dt end
  -- towers
  for pad, t in pairs(towers) do
    local p = S.pads[pad]
    t.built = min(1, t.built + dt * 2.5)
    t.cd = t.cd - dt
    if t.recoil then t.recoil = max(0, t.recoil - dt) end
    local d = D.TOWER[t.id]
    if t.id == "fire" then
      if t.cd <= 0 then
        local r = towerStat(t, "range")
        local any = false
        for _, e in ipairs(enemies) do
          if not e.dead and not e.f.air and inRange(e, p[1], p[3], r) then
            any = true
            hurt(e, towerStat(t, "dmg") * (1 + (t.aura or 0)), "magic")
            e.burn, e.burnT = towerStat(t, "burn"), 2
          end
        end
        if any then
          F.fireRing(p[1], p[2], p[3], r)
          G.emit("shot", "fire", p)
          t.cd = 1 / towerStat(t, "rate")
        else
          t.cd = 0.15
        end
      end
    elseif t.id ~= "shrine" then
      if t.cd <= 0 then
        local e = pickTarget(t, p, towerStat(t, "range"), d.air)
        if e then
          fire(t, p, e, dt)
          t.cd = 1 / towerStat(t, "rate")
        else
          t.cd = 0.1
        end
      end
    end
  end
  updateShots(dt)
  F.update(dt)
end

-- ------------------------------------------------------------------ draw
local TINT = {}
local function towerDraw(t, p, time, mesh)
  local M = Wd.model
  local x, y, z = p[1], p[2], p[3]
  local grow = t.built < 1 and (0.6 + 0.4 * t.built) or 1
  local k = (1.3 + (t.tier - 1) * 0.12) * grow
  local id = t.id
  if id == "archer" then
    local m = M("vk/WatchTower")
    if m then g3d.draw(m, x, y - 0.1, z, 0, 0.6, 0, 0.42 * k, 0.42 * k, 0.42 * k) end
  elseif id == "cannon" then
    local a, b = M("mc/TowerRound"), M("mc/TowerCap")
    if a then g3d.draw(a, x, y - 0.1, z, 0, 0, 0, 0.32 * k, 0.45 * k, 0.32 * k) end
    if b then g3d.draw(b, x, y + 1.7 * k, z, 0, 0.3, 0, 0.31 * k, 0.4 * k, 0.31 * k) end
    local r = t.recoil and t.recoil * 1.2 or 0
    g3d.draw(mesh.barrel, x + sin(t.yaw) * (0.35 - r), y + 2.15 * k, z + cos(t.yaw) * (0.35 - r), pi / 2 - 0.25, t.yaw, 0, k, k, k, "#2B2F36")
  elseif id == "frost" then
    local m = M("vk/RuneStone")
    if m then g3d.draw(m, x, y - 0.1, z, 0, 0.4, 0, 0.95 * k, 1.05 * k, 0.95 * k, "#C8E8FF") end
    local hy = y + 2.9 * k + sin(time * 2 + x) * 0.15
    g3d.draw(mesh.ice, x, hy, z, 0, time * 1.2, 0, k, k, k, "#BFF4FF")
    g3d.draw(mesh.ice, x, hy, z, 0, -time * 0.8, 0, 1.5 * k, 1.5 * k, 1.5 * k, "#3AB0FF40", "glow unlit nocull")
  elseif id == "fire" then
    local a, b = M("mc/TowerCap"), M("vk/Campfire")
    if a then g3d.draw(a, x, y - 0.15, z, 0, 0, 0, 0.3 * k, 0.6 * k, 0.3 * k) end
    if b then g3d.draw(b, x, y + 0.85 * k, z, 0, 0, 0, 1.1 * k, 1.1 * k, 1.1 * k) end
  elseif id == "storm" then
    local a = M("mc/TowerRound")
    if a then g3d.draw(a, x, y - 0.1, z, 0, 0, 0, 0.17 * k, 0.75 * k, 0.17 * k) end
    local oy = y + 3.6 * k + sin(time * 3 + z) * 0.1
    g3d.draw(mesh.torus, x, oy, z, time * 1.4, 0, time * 0.9, k, k, k, "#C8873A")
    g3d.draw(mesh.torus, x, oy, z, -time * 1.1, time, 0, 0.75 * k, 0.75 * k, 0.75 * k, "#C8873A")
    g3d.draw(mesh.orb, x, oy, z, 0, 0, 0, k, k, k)
    g3d.draw(mesh.soft, x, oy, z, pi / 2, 0, 0, 1.2 * k, 1, 1.2 * k, "#8A4AFF60", "glow unlit nocull")
  elseif id == "shrine" then
    local m = M("vk/StorageHouse")
    if m then g3d.draw(m, x, y - 0.1, z, 0, 0.5, 0, 0.42 * k, 0.42 * k, 0.42 * k) end
  end
  -- tier banners
  if t.tier >= 2 then
    local m = M("mc/Banner")
    if m then
      local by = id == "archer" and 3.7 or (id == "cannon" and 1.4 or 0.9)
      g3d.draw(m, x + 0.9, y + by * k - 0.2, z + 0.9, 0, 0.8, 0, 0.45, 0.45, 0.45)
      if t.tier == 3 then g3d.draw(m, x - 0.9, y + by * k - 0.2, z + 0.9, 0, -0.8, 0, 0.45, 0.45, 0.45) end
    end
  end
end

function G.draw(time, cam, dt, sel)
  local mesh = Wd.mesh
  -- pads: worn stone plinths; empty ones glow softly
  for i, p in ipairs(S.pads) do
    local t = towers[i]
    g3d.draw(mesh.plinth, p[1], p[2] - 0.1, p[3], 0, 0, 0, 1, 1, 1)
    if not t then
      local a = 0.5 + 0.5 * sin(time * 2 + i)
      local hot = sel and sel.pad == i
      g3d.draw(mesh.disc, p[1], p[2] + 0.12, p[3], 0, time * 0.3, 0, hot and 1.5 or 1.2, 1, hot and 1.5 or 1.2,
        hot and "#FFE08A" or string.format("#%02X%02X%02X", floor(70 + 60 * a), floor(60 + 50 * a), 30), "glow unlit nocull")
    end
  end
  for pad, t in pairs(towers) do
    local p = S.pads[pad]
    towerDraw(t, p, time, mesh)
    if t.id == "fire" then F.flame(p[1], p[2] + 1.35 * (1 + (t.tier - 1) * 0.1), p[3], 0.9 + t.tier * 0.2, dt, 14 + t.tier * 6) end
    if t.id == "shrine" and random() < dt * (2 + t.tier) then
      F.spawn("gold", p[1] + (random() - 0.5) * 1.6, p[2] + 1.0 + random(), p[3] + (random() - 0.5) * 1.6, 0, 0.8, 0, 1.2, 0.18, 0)
    end
    if t.id == "frost" and random() < dt * 4 then
      F.spawn("frost", p[1] + (random() - 0.5) * 1.2, p[2] + 2.6 + random(), p[3] + (random() - 0.5) * 1.2, 0, -0.4, 0, 1.2, 0.12, 0)
    end
  end
  -- raiders
  for _, e in ipairs(enemies) do
    if e.m and not e.reached then
      local s = e.f.scale
      local sink = e.dead and not e.f.air and max(0, e.deadT - 0.8) * 1.2 or 0
      local tint
      if e.flash > 0 then tint = "#FFB0B0"
      elseif e.slow > 0 then tint = "#9FD8FF"
      elseif e.burnT > 0 then tint = "#FFC090" end
      g3d.draw(e.m, e.x, e.y - sink, e.z, 0, e.yaw, 0, s, s, s, tint)
      if e.f.boss then
        g3d.draw(mesh.soft, e.x, e.y + 0.08, e.z, 0, 0, 0, 2.6, 1, 2.6, "#FF402040", "glow unlit nocull")
      end
      if e.f.air and not e.dead then
        -- shadow spot on the ground under a flyer
        local gy = max(Wd.heightAt(e.x, e.z), S.waterY)
        g3d.draw(mesh.soft, e.x, gy + 0.06, e.z, 0, 0, 0, 0.8, 1, 0.8, "#00000060", "unlit nocull")
      end
    end
  end
  -- shots
  for _, s in ipairs(shots) do
    if s.kind == "arrow" and s.dx then
      g3d.draw(mesh.arrow, s.x, s.y, s.z, -math.asin(max(-1, min(1, s.dy))), atan(s.dx, s.dz), 0)
    elseif s.kind == "ball" then
      g3d.draw(mesh.ball, s.x, s.y, s.z, 0, 0, 0, 1, 1, 1, "#24282E")
    elseif s.kind == "frost" then
      g3d.draw(mesh.ice, s.x, s.y, s.z, 0, time * 6, 0, 0.45, 0.45, 0.45, "#DFFAFF")
    end
  end
  -- selection: range ring of the chosen tower or the one being placed
  if sel and sel.pad and sel.range then
    local p = S.pads[sel.pad]
    local r = sel.range / 0.82
    g3d.draw(mesh.disc, p[1], p[2] + 0.25, p[3], 0, time * 0.2, 0, r, 1, r, sel.color or "#FFE6A0", "glow unlit nocull")
  end
end

-- screen positions of raiders and towers for the interface (call inside the frame, before g3d.finish)
function G.project()
  for _, e in ipairs(enemies) do
    if not e.dead then
      local top = e.f.air and 0.9 or (1.95 * e.f.scale)
      e.sx, e.sy = g3d.project(e.x, e.y + top, e.z)
    end
  end
  for pad, t in pairs(towers) do
    local x, y, z = towerTop(t, S.pads[pad])
    t.sx, t.sy = g3d.project(x, y + 0.6, z)
  end
end

return G
