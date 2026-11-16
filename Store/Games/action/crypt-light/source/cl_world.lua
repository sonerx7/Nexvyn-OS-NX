-- Crypt Light: builds a level from cl_levels data (kit-bashed pieces, collision, navigation) and draws it.
local W = {}
local CELL = 4
local sin, cos, pi, sqrt, abs, floor, max, min = math.sin, math.cos, math.pi, math.sqrt, math.abs, math.floor, math.max, math.min

local cache = {}
-- "kit/GEO_Name" -> model (loaded once, shared by every level)
function W.model(key)
  local m = cache[key]
  if m == nil then
    local kit, name = key:match("^(%w+)/(.+)$")
    m = g3d.model("bundle:/models/" .. kit .. "/" .. name .. ".glb") or false
    if not m then print("cryptlight: model missing " .. key) end
    cache[key] = m
  end
  return m or nil
end
function W.loaded(key) return cache[key] ~= nil end

W.TEX = function(kit, name) return "bundle:/models/" .. kit .. "/" .. name .. ".ktx" end

-- direction vectors of the sides; n = towards -z (up on the map)
local SIDE = {n = {0, -1}, s = {0, 1}, e = {1, 0}, w = {-1, 0}}
W.SIDE = SIDE

-- rotation about y that maps local +z to (dx, dz)
local function yawTo(dx, dz) return math.atan(dx, dz) end
W.yawTo = yawTo

-- ------------------------------------------------------------------ grid
local function makeGrid(def)
  local g = {w = def.w, h = def.h, c = {}}
  for y = 0, def.h - 1 do
    for x = 0, def.w - 1 do g.c[y * def.w + x] = "#" end
  end
  if def.map then
    for y, row in ipairs(def.map) do
      for x = 1, #row do g.c[(y - 1) * def.w + (x - 1)] = row:sub(x, x) end
    end
  end
  for _, op in ipairs(def.carve or {}) do
    for y = op[3], op[5] do
      for x = op[2], op[4] do g.c[y * def.w + x] = op[1] end
    end
  end
  function g.at(x, y)
    if x < 0 or y < 0 or x >= g.w or y >= g.h then return "#" end
    return g.c[y * g.w + x]
  end
  return g
end

local function isOpen(ch) return ch ~= "#" end

-- the piece list: {key, x, y, z, ry, s, sx, sy, sz, tint, r}
local function piece(L, key, x, y, z, ry, s, extra)
  local p = {key = key, x = x, y = y or 0, z = z, ry = ry or 0, s = s or 1}
  if extra then for k, v in pairs(extra) do p[k] = v end end
  p.r = p.r or 6
  L.pieces[#L.pieces + 1] = p
  return p
end
W.piece = piece

local function box(L, cx, cy, cz, hx, hy, hz)
  local id = phys.addBox(L.phys, cx, cy, cz, hx, hy, hz)
  return id
end

-- corner-origin wall (castle): runs along local +x from its origin, thickness towards local -z
local function cornerWall(L, key, xc, zc, side, y)
  local n = SIDE[side]
  local ry, ox, oz
  if side == "n" then ry, ox, oz = 0, xc - 2, zc - 2
  elseif side == "s" then ry, ox, oz = pi, xc + 2, zc + 2
  elseif side == "e" then ry, ox, oz = -pi / 2, xc + 2, zc - 2
  else ry, ox, oz = pi / 2, xc - 2, zc + 2 end
  return piece(L, key, ox, y or 0, oz, ry, 1, {r = 4})
end

-- ------------------------------------------------------------------ sewer tunnels
local TUN = {
  -- base open sides of each piece (directions as dx, dz)
  dead = {"sewer/GEO_TunnelDeadEnd", {{0, 1}}},
  outlet = {"sewer/GEO_TunnelOutletEnd", {{0, 1}}},
  straight = {"sewer/GEO_TunnelStraight", {{0, 1}, {0, -1}}},
  shaft = {"sewer/GEO_TunnelShaft", {{0, 1}, {0, -1}}},
  corner = {"sewer/GEO_TunnelCorner", {{1, 0}, {0, 1}}},
  tee = {"sewer/GEO_TunnelTJunction", {{1, 0}, {0, 1}, {0, -1}}},
  cross = {"sewer/GEO_TunnelCross", {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}},
}
local function rotDir(d, a)
  local c, s = cos(a), sin(a)
  return floor(d[1] * c + d[2] * s + 0.5), floor(-d[1] * s + d[2] * c + 0.5)
end
local function fitRotation(base, need)
  for k = 0, 3 do
    local a = k * pi / 2
    local ok = #base == #need
    if ok then
      for _, d in ipairs(base) do
        local x, z = rotDir(d, a)
        local found = false
        for _, n in ipairs(need) do if n[1] == x and n[2] == z then found = true end end
        if not found then ok = false break end
      end
    end
    if ok then return a end
  end
  return nil
end

local function sewerOpenSides(g, x, y)
  local out = {}
  for _, d in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
    local nx, ny = x + d[1], y + d[2]
    local ch = g.at(nx, ny)
    if ch == "h" then
      -- a chamber cell joins only in the middle of the chamber side
      if g.at(nx + d[1], ny + d[2]) == "H" then out[#out + 1] = d end
    elseif ch ~= "#" and ch ~= "H" then
      out[#out + 1] = d
    end
  end
  return out
end

local function buildSewer(L, g)
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      local ch = g.at(x, y)
      local xc, zc = x * CELL, y * CELL
      if ch == "H" then
        local p = piece(L, "sewer/GEO_ChamberHall", xc, 0, zc, 0, 1, {r = 9, col = "mesh"})
        piece(L, "sewer/GEO_ChamberHallWater", xc, 0, zc, 0, 1, {r = 9, water = true})
      elseif ch == "." or ch == "S" or ch == "E" then
        local need = sewerOpenSides(g, x, y)
        local kind
        if #need == 1 then kind = ch == "E" and "outlet" or "dead"
        elseif #need == 2 then
          local a, b = need[1], need[2]
          if a[1] == -b[1] and a[2] == -b[2] then kind = ch == "S" and "shaft" or "straight" else kind = "corner" end
        elseif #need == 3 then kind = "tee"
        elseif #need == 4 then kind = "cross" end
        if kind then
          local t = TUN[kind]
          local a = fitRotation(t[2], need) or 0
          piece(L, t[1], xc, 0, zc, a, 1, {r = 4, col = "mesh"})
          piece(L, t[1] .. "Water", xc, 0, zc, a, 1, {r = 4, water = true})
          L.cells[#L.cells + 1] = {x = xc, z = zc, kind = kind, ry = a}
        end
      end
    end
  end
end

-- ------------------------------------------------------------------ masonry (castle / temple)
local function buildMasonry(L, g, def)
  local castle = def.style == "castle"
  local floorKey = castle and "castle/GEO_FloorTile" or "temple/GEO_FloorSlab"
  L.floorY = castle and 0.1 or 0.3
  for y = 0, g.h - 1 do
    for x = 0, g.w - 1 do
      local ch = g.at(x, y)
      if isOpen(ch) then
        local xc, zc = x * CELL, y * CELL
        if castle then
          piece(L, floorKey, xc - 2, 0, zc + 2, 0, 1, {r = 3.5})
          if ch == "." then piece(L, floorKey, xc - 2, def.roof, zc + 2, 0, 1, {r = 3.5, ceil = true}) end
        else
          local broken = ((x * 7 + y * 13) % 5 == 0)
          piece(L, broken and "temple/GEO_FloorSlabBroken" or floorKey, xc, 0, zc, ((x + y) % 4) * pi / 2, 1, {r = 3.5})
          if ch == "." then piece(L, floorKey, xc, def.roof, zc, 0, 1, {r = 3.5, ceil = true}) end
        end
        box(L, xc, L.floorY - 0.5, zc, 2, 0.5, 2)
        for side, d in pairs(SIDE) do
          if not isOpen(g.at(x + d[1], y + d[2])) then
            if castle then
              local slit = (ch == "o") and ((x + y) % 3 == 0)
              cornerWall(L, slit and "castle/GEO_WallArrowSlit" or "castle/GEO_WallStraight", xc, zc, side, 0)
              if ch == "o" then cornerWall(L, "castle/GEO_Battlement", xc, zc, side, 4) end
            else
              local ry = (side == "n" or side == "s") and 0 or pi / 2
              local relief = ((x * 3 + y) % 3 == 0)
              local key = relief and "temple/GEO_ReliefWall" or "temple/GEO_WallStraight"
              local wx, wz = xc + d[1] * 2.7, zc + d[2] * 2.7
              piece(L, key, wx, 0, wz, ry, 1, {r = 4})
              if ch == "o" then piece(L, "temple/GEO_WallStraight", wx, 4.2, wz, ry, 1, {r = 4}) end
            end
            -- wall collision: a slab just outside the cell edge
            local hx, hz = (d[1] ~= 0) and 0.5 or 2.2, (d[2] ~= 0) and 0.5 or 2.2
            box(L, xc + d[1] * 2.5, 2.5, zc + d[2] * 2.5, hx, 3, hz)
          end
        end
      end
    end
  end
end

-- ------------------------------------------------------------------ public
-- Collects the model keys a level needs (pieces are built afterwards with the models loaded).
function W.new(def)
  local L = {def = def, pieces = {}, cells = {}, floorY = 0.0}
  L.grid = makeGrid(def)
  L.phys = phys.world({budget = 96})
  if def.style == "sewer" then
    buildSewer(L, L.grid)
  else
    buildMasonry(L, L.grid, def)
  end
  return L
end

-- every model key of the pieces built so far
function W.keys(L)
  local seen, out = {}, {}
  for _, p in ipairs(L.pieces) do
    if not seen[p.key] then seen[p.key] = true; out[#out + 1] = p.key end
  end
  return out
end

-- collision of mesh pieces (sewer) once their models are loaded
function W.finishCollision(L)
  for _, p in ipairs(L.pieces) do
    if p.col == "mesh" then
      local m = W.model(p.key)
      if m then phys.addModel(L.phys, m, {x = p.x, y = p.y, z = p.z, ry = p.ry, scale = p.s, maxTriangles = 6000}) end
    end
  end
end

-- the floor height under a point (nil when none)
function W.ground(L, x, z, fromY)
  local h = phys.raycast(L.phys, x, fromY or 3.0, z, 0, -1, 0, 8, 1)
  return h and h.y or nil
end

-- groups pieces by model for drawing; pieces with a non-uniform scale or a tint draw one by one
function W.prepareDraw(L)
  local groups, singles = {}, {}
  for _, p in ipairs(L.pieces) do
    p.m = W.model(p.key)
    if p.m then
      if p.sx or p.tint then
        singles[#singles + 1] = p
      else
        local gk = p.key
        local gr = groups[gk]
        if not gr then gr = {m = p.m, list = {}, buf = {}}; groups[gk] = gr end
        gr.list[#gr.list + 1] = p
      end
    end
  end
  L.groups, L.singles = {}, singles
  for _, gr in pairs(groups) do L.groups[#L.groups + 1] = gr end
end

-- draws the visible pieces: within `far` of the camera and not behind it
function W.draw(L, cx, cy, cz, fx, fz, far)
  local tris = 0
  for _, gr in ipairs(L.groups) do
    local buf, n = gr.buf, 0
    for _, p in ipairs(gr.list) do
      local dx, dz = p.x - cx, p.z - cz
      local r = p.r * p.s
      local d2 = dx * dx + dz * dz
      local lim = far + r
      -- inside the view: in front, within about 62 degrees of the view direction (radius widens it)
      if d2 < lim * lim and (d2 < (r + 3) * (r + 3) or (dx * fx + dz * fz) > 0.47 * sqrt(d2) - r) then
        buf[n + 1], buf[n + 2], buf[n + 3], buf[n + 4], buf[n + 5], buf[n + 6], buf[n + 7] = p.x, p.y, p.z, 0, p.ry, 0, p.s
        n = n + 7
      end
    end
    for i = #buf, n + 1, -1 do buf[i] = nil end
    if n > 0 then g3d.drawInstanced(gr.m, buf) end
  end
  for _, p in ipairs(L.singles) do
    local dx, dz = p.x - cx, p.z - cz
    local r = p.r * (p.s or 1)
    local lim = far + r
    local d2 = dx * dx + dz * dz
    if d2 < lim * lim and (d2 < (r + 3) * (r + 3) or (dx * fx + dz * fz) > 0.47 * sqrt(d2) - r) then
      local s = p.s or 1
      g3d.draw(p.m, p.x, p.y, p.z, 0, p.ry, 0, (p.sx or 1) * s, (p.sy or 1) * s, (p.sz or 1) * s, p.tint)
    end
  end
  return tris
end

function W.free(L)
  if L and L.phys then phys.free(L.phys) end
end

return W
