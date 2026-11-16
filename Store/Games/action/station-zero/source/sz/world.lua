-- Station Zero: the station. Loads the kit pieces, builds a level from its map (kit-bashing: floors, walls, viewports,
-- ceilings, doors and props on a 2 m grid), answers collision / line-of-sight / path questions and draws the static
-- world with instancing and distance culling.
local S = require("sz.state")
local F = require("sz.fx")
local W = {}

local floor, sqrt, min, max, abs, pi, sin, cos = math.floor, math.sqrt, math.min, math.max, math.abs, math.pi, math.sin, math.cos
local CELL = S.CELL

-- ---------------------------------------------------------------- pieces
-- key = file in models/ (without .glb). Kit pieces have their origin at a corner (walls: x 0..len, floors: x 0..2,
-- z -2..0); props are centred.
W.FILES = {
  "floor", "grate", "ceil", "ceil_light", "wall", "wall_panel", "wall_vent", "viewport", "door_wall",
  "door_l", "door_r", "cable", "pipe", "elamp", "bunk", "bedding", "locker", "locker_door", "shelf", "crate",
  "bench", "terminal", "rack", "rack_bay", "rack_led", "spark_panel", "toolrack", "tank", "drone", "warden", "pod",
  "cradle", "reactor", "console", "rdesk", "hero",
}
W.models = {}
W.loaded, W.failed = 0, 0
-- the kit's painted panels are near white: a cold grey-blue tint keeps the station dark and lets the lights read
local PANEL, DECK = "#76828F", "#8A939D"
W.FLAGS = {shaft = "glow unlit nocull"}
W.TINT = {wall = PANEL, wall_panel = PANEL, wall_vent = PANEL, viewport = PANEL, door_wall = PANEL, ceil = "#5E6873",
          ceil_light = "#6C7782", floor = DECK, grate = DECK, cable = "#9AA3AD", pipe = "#9AA3AD", door_l = "#8A96A3",
          door_r = "#8A96A3"}

function W.load(done)
  local i = 0
  local function nextOne()
    i = i + 1
    local name = W.FILES[i]
    if not name then if done then done() end return end
    g3d.loadModel("bundle:/models/" .. name .. ".glb", function(m, err)
      if m then W.models[name] = m; W.loaded = W.loaded + 1 else W.failed = W.failed + 1 end
      nextOne()
    end)
  end
  nextOne()
end
function W.progress() return (W.loaded + W.failed) / #W.FILES end

-- ---------------------------------------------------------------- level build
local SOLID = {["#"] = true, V = true, R = true, E = true, o = true, b = true, k = true, s = true, w = true, t = true,
               W = true, x = true, T = true, l = true, c = true, n = true}
local LOSBLOCK = {["#"] = true, V = true, R = true, E = true, o = true, s = true, k = true, n = true}
local DOORS = {D = true, L = true, S = true, G = true, Q = true, Y = true, X = true}

local function cellCenter(c, r) return (c - 1) * CELL + CELL / 2, (r - 1) * CELL + CELL / 2 end
W.cellCenter = cellCenter
function W.cellAt(x, z) return floor(x / CELL) + 1, floor(z / CELL) + 1 end

-- rotate a local (x, z) by yaw (local +z turns to (sin ry, cos ry))
local function rot(lx, lz, ry)
  local c, s = cos(ry), sin(ry)
  return lx * c + lz * s, -lx * s + lz * c
end

function W.build(def)
  local lv = {def = def, rows = #def.map, cols = #def.map[1], g = {}, inst = {}, doors = {}, things = {}, lamps = {},
              emit = {}, holo = {}, glass = {}}
  for r = 1, lv.rows do
    lv.g[r] = {}
    local row = def.map[r]
    for c = 1, lv.cols do lv.g[r][c] = row:sub(c, c) end
  end
  local function ch(c, r)
    if r < 1 or r > lv.rows or c < 1 or c > lv.cols then return "#" end
    return lv.g[r][c]
  end
  lv.ch = ch
  local function put(key, x, y, z, ry, s, sy)
    local l = lv.inst[key]
    if not l then l = {}; lv.inst[key] = l end
    l[#l + 1] = {x = x, y = y, z = z, ry = ry or 0, s = s or 1, sy = sy}
  end
  -- a piece whose local origin is offset (ox, oz) from the point it should sit on
  local function putAt(key, cx, y, cz, ry, ox, oz, s)
    local dx, dz = rot(ox or 0, oz or 0, ry or 0)
    put(key, cx - dx * (s or 1), y, cz - dz * (s or 1), ry, s)
  end
  local isWall = function(k) return k == "#" or k == "V" end

  for r = 1, lv.rows do
    for c = 1, lv.cols do
      local k = ch(c, r)
      if not isWall(k) then
        local x, z = cellCenter(c, r)
        local x0, z1 = x - 1, z + 1
        -- floor (grates under steam vents, on ',' cells and as a checker in big rooms) and ceiling
        local grate = k == "," or k == "v" or k == "p"
        put(grate and "grate" or "floor", x0, 0, z1)
        local lit = (c % 3 == 1) and (r % 2 == 0) and k ~= "R"
        if k ~= "R" then put(lit and "ceil_light" or "ceil", x0, S.WALL_H, z1) end
        if lit and not (isWall(ch(c, r - 1)) and isWall(ch(c, r + 1))) and not (isWall(ch(c - 1, r)) and isWall(ch(c + 1, r))) then
          put("shaft", x, S.WALL_H - 0.08, z)
        end
        if lit then
          lv.lamps[#lv.lamps + 1] = F.addSource({x = x, y = S.WALL_H - 0.35, z = z, color = "#CFE4FF", intensity = 5.5,
                                                range = 6.5, kind = "lamp", flicker = (c * 7 + r * 3) % 11 == 0})
        end
        -- walls on the four edges that face something solid
        local edges = {{0, -1, 0}, {0, 1, pi}, {-1, 0, pi / 2}, {1, 0, -pi / 2}}  -- dc, dr, yaw that faces into the cell
        for ei, e in ipairs(edges) do
          local n = ch(c + e[1], r + e[2])
          if isWall(n) then
            local ex, ez = x + e[1] * CELL / 2, z + e[2] * CELL / 2
            if n == "V" then
              -- viewports are 4 m: pair this cell with the next one along the edge when that one also looks out
              local ac, ar = (ei <= 2) and 1 or 0, (ei <= 2) and 0 or 1
              lv.vp = lv.vp or {}
              if not lv.vp[c .. ":" .. r .. ":" .. ei] then
                local nc, nr = c + ac, r + ar
                if not isWall(ch(nc, nr)) and ch(nc + e[1], nr + e[2]) == "V" then
                  lv.vp[nc .. ":" .. nr .. ":" .. ei] = true
                  local mx, mz = ex + ac * CELL / 2, ez + ar * CELL / 2
                  -- drawn one by one (not instanced) so the glass can be transmissive
                  local gx, gz = rot(2, 0, e[3])
                  lv.glass[#lv.glass + 1] = {x = mx - gx, z = mz - gz, cx = mx, cz = mz, ry = e[3]}
                else
                  putAt("wall", ex, 0, ez, e[3], 1, 0)
                end
              end
            else
              local v = (c * 5 + r * 3 + ei) % 7
              putAt(v == 0 and "wall_vent" or (v <= 2 and "wall_panel" or "wall"), ex, 0, ez, e[3], 1, 0)
              -- neon strips: one at the foot of every wall, one under the ceiling on every other one
              put("neon", ex - e[1] * 0.19, 0.16, ez - e[2] * 0.19, e[3])
              if (c + r) % 2 == 0 then put("neon", ex - e[1] * 0.19, S.WALL_H - 0.22, ez - e[2] * 0.19, e[3]) end
              if (c * 3 + r * 5 + ei) % 9 == 0 then  -- red emergency lamp on the wall (pulses in an alarm)
                local lx, lz = ex - e[1] * 0.2, ez - e[2] * 0.2
                put("elamp", lx, 2.5, lz, e[3])
                lv.emit[#lv.emit + 1] = {x = lx, y = 2.5, z = lz, kind = "alarmlamp"}
                F.addSource({x = lx - e[1] * 0.4, y = 2.4, z = lz - e[2] * 0.4, color = "#FF2B3A", intensity = 7, range = 6,
                             kind = "alarm", boost = 40})
              end
            end
          end
        end
        -- doors
        if DOORS[k] then
          local ns = isWall(ch(c - 1, r)) or SOLID[ch(c - 1, r)]
          local yaw = ns and 0 or pi / 2  -- frame along x when the walls are left and right
          putAt("door_wall", x, 0, z, yaw, 1, 0)
          local d = {c = c, r = r, x = x, z = z, yaw = yaw, kind = k, open = 0, want = false, solid = true}
          lv.doors[#lv.doors + 1] = d
          lv.doorAt = lv.doorAt or {}
          lv.doorAt[r * 1000 + c] = d
        end
        -- props
        if k ~= "." and k ~= "," and k ~= "P" and not DOORS[k] then
          lv.things[#lv.things + 1] = {k = k, c = c, r = r, x = x, z = z}
        end
        if k == "P" then lv.start = {x = x, z = z} end
      end
    end
  end
  -- cable trays and pipes under the ceiling of long corridors (cells with walls on both sides)
  for r = 1, lv.rows do
    for c = 1, lv.cols do
      local k = ch(c, r)
      if not isWall(k) and not DOORS[k] then
        local x, z = cellCenter(c, r)
        if isWall(ch(c, r - 1)) and isWall(ch(c, r + 1)) then
          putAt("cable", x, S.WALL_H - 0.35, z - 0.55, 0, 1, 0)
          putAt("pipe", x, S.WALL_H - 0.5, z + 0.6, 0, 1, 0)
        elseif isWall(ch(c - 1, r)) and isWall(ch(c + 1, r)) then
          putAt("cable", x - 0.55, S.WALL_H - 0.35, z, pi / 2, 1, 0)
        end
      end
    end
  end
  -- props that face away from the nearest wall
  local function wallYaw(c, r)
    if isWall(ch(c, r - 1)) then return 0 end
    if isWall(ch(c, r + 1)) then return pi end
    if isWall(ch(c - 1, r)) then return pi / 2 end
    if isWall(ch(c + 1, r)) then return -pi / 2 end
    return 0
  end
  local function backOffset(c, r, d)
    local y = wallYaw(c, r)
    local fx, fz = sin(y), cos(y)
    return -fx * d, -fz * d, y
  end
  for _, t in ipairs(lv.things) do
    local x, z, k = t.x, t.z, t.k
    local bx, bz, yaw = backOffset(t.c, t.r, 0.55)
    t.yaw = yaw
    if k == "b" then put("bunk", x + bx * 0.4, 0, z + bz * 0.4, yaw + pi / 2); put("bedding", x + bx * 0.4, 0, z + bz * 0.4, yaw + pi / 2)
    elseif k == "k" then put("locker", x + bx, 0, z + bz, yaw); putAt("locker_door", x + bx, 0, z + bz, yaw, 0.29, -0.3)
    elseif k == "s" then put("shelf", x + bx, 0, z + bz, yaw)
    elseif k == "w" then put("bench", x + bx * 0.6, 0, z + bz * 0.6, yaw); put("toolrack", x + bx * 1.6, 0.2, z + bz * 1.6, yaw)
    elseif k == "o" then
      local ry = ((t.c * 7 + t.r) % 4) * 0.12
      put("crate", x, 0, z, ry, 2.7)
      put("crate", x + 0.08, 1.08, z - 0.05, ry + 0.3, 2.5)
    elseif k == "t" then put("tank", x + bx * 0.3, 0, z + bz * 0.3, yaw); lv.emit[#lv.emit + 1] = {x = x, y = 1.1, z = z, kind = "tank"}
      F.addSource({x = x, y = 1.2, z = z, color = "#4BFFC8", intensity = 3.5, range = 3.5, kind = "fixed"})
    elseif k == "x" then put("spark_panel", x + bx * 0.6, 0, z + bz * 0.6, yaw); t.spark = 0
      F.addSource({x = x, y = 0.9, z = z, color = "#FF9A3C", intensity = 3, range = 4, kind = "fixed", flicker = true})
    elseif k == "v" then t.steam = 0
    elseif k == "n" then put("console", x, 0, z, ((t.c + t.r) % 2) * pi)
      F.addSource({x = x, y = 1.5, z = z, color = S.C.cyan, intensity = 2.5, range = 3.5, kind = "fixed"})
    elseif k == "T" or k == "l" or k == "c" then
      put("rack", x, 0, z, yaw)
      if k == "c" then put("rack_bay", x, 0, z, yaw); put("rack_led", x, 0, z, yaw) end
      F.addSource({x = x + sin(yaw) * 0.8, y = 1.6, z = z + cos(yaw) * 0.8, color = k == "c" and "#7DFFB0" or S.C.cyan,
                   intensity = 4, range = 4.5, kind = "fixed", boost = 20})
    elseif k == "K" then F.addSource({x = x, y = 1.2, z = z, color = S.C.amber, intensity = 4, range = 4, kind = "fixed", boost = 10})
    elseif k == "H" then F.addSource({x = x, y = 1.6, z = z, color = S.C.cyan, intensity = 3, range = 4, kind = "fixed"})
    end
  end
  -- reactor and pod: the centre of their 3 x 3 block
  local function blockCentre(sym)
    local sx, sz, n = 0, 0, 0
    for r = 1, lv.rows do for c = 1, lv.cols do
      if lv.g[r][c] == sym then local x, z = cellCenter(c, r); sx, sz, n = sx + x, sz + z, n + 1 end
    end end
    if n == 0 then return nil end
    return {x = sx / n, z = sz / n}
  end
  lv.reactor = blockCentre("R")
  if lv.reactor then
    lv.coreLights = {
      F.addSource({x = lv.reactor.x + 2.6, y = 1.6, z = lv.reactor.z + 2.6, color = S.C.amber, intensity = 9, range = 9,
                   kind = "core", boost = 60}),
      F.addSource({x = lv.reactor.x - 2.6, y = 1.6, z = lv.reactor.z - 2.6, color = S.C.amber, intensity = 9, range = 9,
                   kind = "core", boost = 60}),
    }
  end
  lv.pod = blockCentre("E")
  if lv.pod then
    F.addSource({x = lv.pod.x, y = 2.6, z = lv.pod.z - 3.5, color = "#FFFFFF", intensity = 10, range = 9, kind = "fixed", boost = 25})
  end
  -- static instance lists as flat transform arrays per chunk (8 x 8 cells) for culling
  lv.chunks = {}
  local CH = 8 * CELL
  for key, list in pairs(lv.inst) do
    for _, it in ipairs(list) do
      local cx, cz = floor(it.x / CH), floor(it.z / CH)
      local id = cz * 100 + cx
      local chk = lv.chunks[id]
      if not chk then chk = {x = (cx + 0.5) * CH, z = (cz + 0.5) * CH, sets = {}}; lv.chunks[id] = chk end
      local set = chk.sets[key]
      if not set then set = {}; chk.sets[key] = set end
      local n = #set
      set[n + 1], set[n + 2], set[n + 3], set[n + 4], set[n + 5], set[n + 6], set[n + 7] = it.x, it.y, it.z, 0, it.ry, 0, it.s
    end
  end
  lv.chunkList = {}
  for _, chk in pairs(lv.chunks) do lv.chunkList[#lv.chunkList + 1] = chk end
  lv.dist = {}   -- flow field toward the player (BFS steps)
  return lv
end

-- ---------------------------------------------------------------- queries
function W.solidCell(lv, c, r, forDrone)
  local k = lv.ch(c, r)
  if lv.doorAt then
    local d = lv.doorAt[r * 1000 + c]
    if d then return d.solid end
  end
  if forDrone then return k == "#" or k == "V" or k == "R" or k == "E" or k == "s" or k == "k" end
  return SOLID[k] or false
end

function W.blocksSight(lv, c, r)
  local k = lv.ch(c, r)
  if lv.doorAt then
    local d = lv.doorAt[r * 1000 + c]
    if d then return d.open < 0.6 end
  end
  return LOSBLOCK[k] or false
end

-- line of sight on the grid (DDA through the cells)
function W.los(lv, x1, z1, x2, z2)
  local c, r = W.cellAt(x1, z1)
  local c2, r2 = W.cellAt(x2, z2)
  local dx, dz = x2 - x1, z2 - z1
  local stepC, stepR = dx > 0 and 1 or -1, dz > 0 and 1 or -1
  local tdx = dx ~= 0 and abs(CELL / dx) or 1e9
  local tdz = dz ~= 0 and abs(CELL / dz) or 1e9
  local nx = dx > 0 and (c * CELL - x1) or (x1 - (c - 1) * CELL)
  local nz = dz > 0 and (r * CELL - z1) or (z1 - (r - 1) * CELL)
  local tx = dx ~= 0 and abs(nx / dx) or 1e9
  local tz = dz ~= 0 and abs(nz / dz) or 1e9
  for _ = 1, 64 do
    if c == c2 and r == r2 then return true end
    if tx < tz then c, tx = c + stepC, tx + tdx else r, tz = r + stepR, tz + tdz end
    if (c ~= c2 or r ~= r2) and W.blocksSight(lv, c, r) then return false end
  end
  return true
end

-- circle (x, z, radius) against solid cells: returns the corrected position
function W.collide(lv, x, z, rad, forDrone)
  local c0, r0 = W.cellAt(x, z)
  for r = r0 - 1, r0 + 1 do
    for c = c0 - 1, c0 + 1 do
      if W.solidCell(lv, c, r, forDrone) then
        local bx0, bz0 = (c - 1) * CELL, (r - 1) * CELL
        local px, pz = max(bx0, min(x, bx0 + CELL)), max(bz0, min(z, bz0 + CELL))
        local dx, dz = x - px, z - pz
        local d2 = dx * dx + dz * dz
        if d2 < rad * rad then
          if d2 > 1e-8 then
            local d = sqrt(d2)
            x, z = px + dx / d * rad, pz + dz / d * rad
          else  -- inside the box: push out along the shortest axis
            local l, rr, t, b = x - bx0, bx0 + CELL - x, z - bz0, bz0 + CELL - z
            local m = min(l, rr, t, b)
            if m == l then x = bx0 - rad elseif m == rr then x = bx0 + CELL + rad
            elseif m == t then z = bz0 - rad else z = bz0 + CELL + rad end
          end
        end
      end
    end
  end
  return x, z
end

-- BFS from the player's cell; drones step to the neighbour with the smaller number
function W.flow(lv, px, pz)
  local pc, pr = W.cellAt(px, pz)
  if lv.flowKey == pr * 1000 + pc then return end
  lv.flowKey = pr * 1000 + pc
  local dist = {}
  local q, head = {pr * 1000 + pc}, 1
  dist[q[1]] = 0
  while head <= #q do
    local id = q[head]; head = head + 1
    local r, c = floor(id / 1000), id % 1000
    local d = dist[id]
    if d < 60 then
      for _, n in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
        local nc, nr = c + n[1], r + n[2]
        local nid = nr * 1000 + nc
        if not dist[nid] and nr >= 1 and nr <= lv.rows and nc >= 1 and nc <= lv.cols and not W.solidCell(lv, nc, nr, true) then
          dist[nid] = d + 1
          q[#q + 1] = nid
        end
      end
    end
  end
  lv.dist = dist
end

-- direction toward the player through the corridors: a point to steer at
function W.flowTarget(lv, x, z)
  local c, r = W.cellAt(x, z)
  local best, bc, br = lv.dist[r * 1000 + c], c, r
  if not best then return nil end
  for _, n in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
    local d = lv.dist[(r + n[2]) * 1000 + (c + n[1])]
    if d and d < best then best, bc, br = d, c + n[1], r + n[2] end
  end
  return cellCenter(bc, br)
end

-- ---------------------------------------------------------------- doors
function W.updateDoors(lv, dt, near)
  for _, d in ipairs(lv.doors) do
    local want = d.forced
    if want == nil then
      want = false
      if d.kind == "D" or d.kind == "X" then want = near(d.x, d.z, 2.7) end
    end
    if d.kind == "X" and d.lockedUntil then want = false end
    local target = want and 1 or 0
    local before = d.open
    if d.open < target then d.open = min(1, d.open + dt * 1.8) elseif d.open > target then d.open = max(0, d.open - dt * 1.4) end
    if (before == 0 and d.open > 0) or (before == 1 and d.open < 1) then F.sound3("door", d.x, d.z, 0.7) end
    d.solid = d.open < 0.75
  end
end

-- ---------------------------------------------------------------- drawing
local sky, planet, halo
-- the view outside the viewports: a star sphere around the camera and a planet below the ring (generated images,
-- tools/stationzero_space.py); unlit, so they read the same everywhere
function W.drawSpace(cx, cy, cz)
  if not sky then
    sky = g3d.mesh("sphere", 1, 32, 16)
    sky:setTexture("bundle:/img/space.jpg")
    planet = g3d.mesh("sphere", 1, 48, 28)
    planet:setTexture("bundle:/img/planet.jpg")
    halo = g3d.mesh("sphere", 1, 40, 24)
    halo:setColor("#163C70")
  end
  g3d.draw(sky, cx, cy, cz, 0, S.t * 0.002, 0, 180, 180, 180, nil, "unlit nocull")
  local px, py, pz = cx + 10, cy - 26, cz - 140
  g3d.draw(planet, px, py, pz, 0.35, S.t * 0.006, 0.2, 60, 60, 60, "#C8D8F0", "unlit")
  g3d.draw(halo, px, py, pz, 0, 0, 0, 63.5, 63.5, 63.5, nil, "glow unlit")
end

-- draws every chunk near the camera; viewDir (vx, vz) culls what is behind
function W.draw(lv, cx, cz, vx, vz, radius)
  radius = radius or 30
  local m = W.models
  local r2 = (radius + 12) ^ 2
  for _, chk in ipairs(lv.chunkList) do
    local dx, dz = chk.x - cx, chk.z - cz
    local d2 = dx * dx + dz * dz
    if d2 < r2 and (d2 < 400 or dx * vx + dz * vz > -12) then
      for key, set in pairs(chk.sets) do
        local mod = m[key]
        if mod then g3d.drawInstanced(mod, set, W.TINT[key], W.FLAGS[key]) end
      end
    end
  end
  -- viewports, and the view out of them: a panorama quad just behind each frame, its part of the picture chosen by
  -- the window's place along the wall so neighbouring windows show one continuous view
  local vp = m.viewport
  for _, g in ipairs(lv.glass) do
    local dx, dz = g.cx - cx, g.cz - cz
    if dx * dx + dz * dz < radius * radius then
      if vp then g3d.draw(vp, g.x, 0, g.z, 0, g.ry, 0, 1, 1, 1, W.TINT.viewport) end
      if not g.view then
        local u0 = ((g.cx + g.cz) / 64) % 1
        local u1 = u0 + 3.2 / 64
        local hw, y0, y1 = 1.6, 1.0, 2.5
        g.view = g3d.custom({-hw, y0, 0, hw, y0, 0, hw, y1, 0, -hw, y1, 0}, {1, 2, 3, 1, 3, 4}, nil, false,
                            {u1, 0.92, u0, 0.92, u0, 0.08, u1, 0.08})
        g.view:setTexture("bundle:/img/window.jpg")
      end
      g3d.draw(g.view, g.cx, 0, g.cz, 0, g.ry, 0, 1, 1, 1, nil, "unlit nocull")
    end
  end
  -- door leaves slide into the frame
  local dl, dr = m.door_l, m.door_r
  if dl and dr then
    for _, d in ipairs(lv.doors) do
      if (d.x - cx) ^ 2 + (d.z - cz) ^ 2 < radius * radius then
        local slide = d.open * 0.75
        local c, s = cos(d.yaw), sin(d.yaw)
        -- the leaves' origin is the frame's corner (x 0.2..1.8): centre the frame on the cell, then slide apart
        local ox, oz = d.x - c * 1, d.z + s * 1
        local tint = nil
        if d.kind == "L" or d.kind == "Y" or d.kind == "Q" then tint = d.open > 0 and nil or "#FFD0C8" end
        g3d.draw(dl, ox - c * slide, 0, oz + s * slide, 0, d.yaw, 0, 1, 1, 1, tint)
        g3d.draw(dr, ox + c * slide, 0, oz - s * slide, 0, d.yaw, 0, 1, 1, 1, tint)
      end
    end
  end
end

return W
