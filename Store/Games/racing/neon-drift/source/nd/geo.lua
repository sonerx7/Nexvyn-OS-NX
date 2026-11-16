-- Neon Drift: a small geometry builder on top of g3d.custom (quads, strips, boxes with tiling UVs).
local Geo = {}
Geo.__index = Geo

function Geo.new()
  return setmetatable({v = {}, i = {}, uv = {}, n = 0}, Geo)
end

function Geo:vert(x, y, z, u, v)
  local vv, uu = self.v, self.uv
  vv[#vv + 1] = x; vv[#vv + 1] = y; vv[#vv + 1] = z
  uu[#uu + 1] = u; uu[#uu + 1] = v
  self.n = self.n + 1
  return self.n
end

function Geo:tri(a, b, c)
  local ii = self.i
  ii[#ii + 1] = a; ii[#ii + 1] = b; ii[#ii + 1] = c
end

-- quad a-b-c-d counter-clockwise seen from the front
function Geo:quad(ax, ay, az, bx, by, bz, cx, cy, cz, dx, dy, dz, u0, v0, u1, v1)
  u0, v0, u1, v1 = u0 or 0, v0 or 0, u1 or 1, v1 or 1
  local a = self:vert(ax, ay, az, u0, v1)
  local b = self:vert(bx, by, bz, u1, v1)
  local c = self:vert(cx, cy, cz, u1, v0)
  local d = self:vert(dx, dy, dz, u0, v0)
  self:tri(a, b, c)
  self:tri(a, c, d)
end

-- an upright rectangle facing direction (fx, fz) (unit), centred at x, z, bottom at y
function Geo:panel(x, y, z, fx, fz, w, h, u0, v0, u1, v1)
  local rx, rz = fz, -fx  -- right of the viewer looking at the panel's front
  local hw = w / 2
  self:quad(x - rx * hw, y, z - rz * hw, x + rx * hw, y, z + rz * hw, x + rx * hw, y + h, z + rz * hw,
            x - rx * hw, y + h, z - rz * hw, u0, v0, u1, v1)
end

-- an oriented box: centre x, z, bottom y, size w (along local x) d (along local z) h, yaw; uv tiles every `tile` m
function Geo:box(x, y, z, w, h, d, yaw, tile, vsel0, vsel1, skipBottom)
  local c, s = math.cos(yaw), math.sin(yaw)
  local function P(lx, ly, lz) return x + lx * c + lz * s, y + ly, z - lx * s + lz * c end
  local hw, hd = w / 2, d / 2
  tile = tile or 4
  local v0, v1 = vsel0 or 0, vsel1
  local function face(p1, p2, p3, p4, du, dv)
    local ax, ay, az = P(p1[1], p1[2], p1[3]); local bx, by, bz = P(p2[1], p2[2], p2[3])
    local cx, cy, cz = P(p3[1], p3[2], p3[3]); local dx, dy, dz = P(p4[1], p4[2], p4[3])
    self:quad(ax, ay, az, bx, by, bz, cx, cy, cz, dx, dy, dz, 0, v0, du / tile, v1 or (v0 + dv / tile))
  end
  face({-hw, 0, hd}, {hw, 0, hd}, {hw, h, hd}, {-hw, h, hd}, w, h)       -- +z
  face({hw, 0, -hd}, {-hw, 0, -hd}, {-hw, h, -hd}, {hw, h, -hd}, w, h)   -- -z
  face({hw, 0, hd}, {hw, 0, -hd}, {hw, h, -hd}, {hw, h, hd}, d, h)       -- +x
  face({-hw, 0, -hd}, {-hw, 0, hd}, {-hw, h, hd}, {-hw, h, -hd}, d, h)   -- -x
  face({-hw, h, hd}, {hw, h, hd}, {hw, h, -hd}, {-hw, h, -hd}, w, d)     -- top
  if not skipBottom then face({-hw, 0, -hd}, {hw, 0, -hd}, {hw, 0, hd}, {-hw, 0, hd}, w, d) end
end

function Geo:mesh(flat)
  if self.n == 0 then return nil end
  return g3d.custom(self.v, self.i, nil, flat or false, self.uv)
end

return Geo
