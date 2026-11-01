-- b3d.lua: merges simple shapes into one g3d.custom mesh with per-vertex colours (one draw call per chunk).
-- Every triangle is wound so that it faces a hint direction (up for ground, outwards for boxes), because the GPU
-- path culls back faces.
local B = {}
B.__index = B

local sqrt, sin, cos, pi = math.sqrt, math.sin, math.cos, math.pi

function B.new() return setmetatable({v = {}, i = {}, c = {}, n = 0}, B) end

function B:count() return #self.i // 3 end

local function push(self, x, y, z, col)
  local v = self.v
  local k = #v
  v[k + 1], v[k + 2], v[k + 3] = x, y, z
  self.c[#self.c + 1] = col
  self.n = self.n + 1
  return self.n
end

-- triangle; (hx, hy, hz) = the direction it should face
function B:tri(ax, ay, az, bx, by, bz, cx, cy, cz, col, hx, hy, hz)
  if hx then
    local ux, uy, uz = bx - ax, by - ay, bz - az
    local vx, vy, vz = cx - ax, cy - ay, cz - az
    local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    if nx * hx + ny * hy + nz * hz < 0 then bx, by, bz, cx, cy, cz = cx, cy, cz, bx, by, bz end
  end
  local i = self.i
  local a = push(self, ax, ay, az, col)
  local b = push(self, bx, by, bz, col)
  local c = push(self, cx, cy, cz, col)
  local k = #i
  i[k + 1], i[k + 2], i[k + 3] = a, b, c
end

-- quad a b c d (in order around the edge), facing the hint
function B:quad(a, b, c, d, col, hx, hy, hz)
  self:tri(a[1], a[2], a[3], b[1], b[2], b[3], c[1], c[2], c[3], col, hx, hy, hz)
  self:tri(a[1], a[2], a[3], c[1], c[2], c[3], d[1], d[2], d[3], col, hx, hy, hz)
end
-- the same, seen from both sides (leaves, flags, signs)
function B:quad2(a, b, c, d, col)
  self:tri(a[1], a[2], a[3], b[1], b[2], b[3], c[1], c[2], c[3], col)
  self:tri(a[1], a[2], a[3], c[1], c[2], c[3], d[1], d[2], d[3], col)
  self:tri(a[1], a[2], a[3], c[1], c[2], c[3], b[1], b[2], b[3], col)
  self:tri(a[1], a[2], a[3], d[1], d[2], d[3], c[1], c[2], c[3], col)
end

-- oriented box: centre, half sizes along the box axes (yaw around y), face colours top / sides / front
function B:box(cx, cy, cz, hx, hy, hz, yaw, top, side, front, bottom)
  local c, s = cos(yaw or 0), sin(yaw or 0)
  local function P(x, y, z) return {cx + x * c + z * s, cy + y, cz - x * s + z * c} end
  local p = {P(-hx, -hy, -hz), P(hx, -hy, -hz), P(hx, -hy, hz), P(-hx, -hy, hz),
             P(-hx, hy, -hz), P(hx, hy, -hz), P(hx, hy, hz), P(-hx, hy, hz)}
  local function face(a, b, cc, d, col)
    local mx = (a[1] + b[1] + cc[1] + d[1]) / 4 - cx
    local my = (a[2] + b[2] + cc[2] + d[2]) / 4 - cy
    local mz = (a[3] + b[3] + cc[3] + d[3]) / 4 - cz
    self:quad(a, b, cc, d, col, mx, my, mz)
  end
  face(p[5], p[6], p[7], p[8], top)
  if bottom then face(p[1], p[2], p[3], p[4], bottom) end
  face(p[1], p[2], p[6], p[5], front or side)
  face(p[4], p[3], p[7], p[8], side)
  face(p[1], p[4], p[8], p[5], side)
  face(p[2], p[3], p[7], p[6], side)
end

-- a prism with n sides between two rings (trunks, posts, wheels lying on their side use cylinderX)
function B:column(x, y0, z, r0, y1, r1, n, col, topCol, lean)
  lean = lean or 0
  for k = 0, n - 1 do
    local a0, a1 = k / n * 2 * pi, (k + 1) / n * 2 * pi
    local ax, az = cos(a0), sin(a0)
    local bx, bz = cos(a1), sin(a1)
    local q = {{x + ax * r0, y0, z + az * r0}, {x + bx * r0, y0, z + bz * r0},
               {x + lean + bx * r1, y1, z + bz * r1}, {x + lean + ax * r1, y1, z + az * r1}}
    self:quad(q[1], q[2], q[3], q[4], col, (ax + bx), 0, (az + bz))
    if topCol then
      self:tri(x + lean, y1, z, x + lean + ax * r1, y1, z + az * r1, x + lean + bx * r1, y1, z + bz * r1, topCol, 0, 1, 0)
    end
  end
end

local function max1(v) return v < 0.001 and 0.001 or v end

-- a cone / pyramid (rocks, roofs, trees)
function B:cone(x, y0, z, r, y1, n, col, rot)
  rot = rot or 0
  for k = 0, n - 1 do
    local a0, a1 = rot + k / n * 2 * pi, rot + (k + 1) / n * 2 * pi
    local ax, az, bx, bz = cos(a0) * r, sin(a0) * r, cos(a1) * r, sin(a1) * r
    self:tri(x + ax, y0, z + az, x + bx, y0, z + bz, x, y1, z, col, ax + bx, (r * r) / max1(y1 - y0), az + bz)
  end
end
-- a wheel: cylinder along the local x axis of a car (yaw 0 = car facing -z)
function B:wheel(cx, cy, cz, r, w, n, col, hub)
  for k = 0, n - 1 do
    local a0, a1 = k / n * 2 * pi, (k + 1) / n * 2 * pi
    local y0, z0, y1, z1 = cos(a0) * r, sin(a0) * r, cos(a1) * r, sin(a1) * r
    local q = {{cx - w, cy + y0, cz + z0}, {cx - w, cy + y1, cz + z1}, {cx + w, cy + y1, cz + z1}, {cx + w, cy + y0, cz + z0}}
    self:quad(q[1], q[2], q[3], q[4], col, 0, y0 + y1, z0 + z1)
    self:tri(cx + w, cy, cz, cx + w, cy + y0, cz + z0, cx + w, cy + y1, cz + z1, hub or col, 1, 0, 0)
    self:tri(cx - w, cy, cz, cx - w, cy + y0, cz + z0, cx - w, cy + y1, cz + z1, hub or col, -1, 0, 0)
  end
end

function B:mesh(flat)
  if #self.i == 0 then return nil end
  return g3d.custom(self.v, self.i, self.c, flat ~= false)
end

B.sqrt = sqrt
return B
