-- b3d.lua: merges simple shapes into one g3d.custom mesh with per-vertex colours and texture coordinates (one draw
-- call per chunk and texture). Every triangle is wound so that it faces a hint direction (up for ground, outwards
-- for boxes), because the GPU path culls back faces.
--
-- Texture coordinates: shapes take an optional rectangle {u0, v0, u1, v1} (or explicit corners) inside the mesh's
-- texture. Without one, a vertex gets the builder's default (u, v), normally a plain white texel, so the vertex colour
-- shows. B.textured() tells whether textures render (GPU path); on the CPU fallback callers keep their flat colours.
local B = {}
B.__index = B

local sqrt, sin, cos, pi = math.sqrt, math.sin, math.cos, math.pi

local TEX
-- true when textures render (GPU path)
function B.textured()
  if TEX == nil then
    TEX = (g3d.gpu == nil) or (g3d.gpu() == true)
  end
  return TEX
end
-- the colour for a face: `tint` (default white) when it is textured, its flat colour `col` otherwise
function B.col(col, tint)
  if B.textured() then return tint or "#FFFFFF" end
  return col
end

function B.new(du, dv) return setmetatable({v = {}, i = {}, c = {}, uv = {}, n = 0, du = du or 0, dv = dv or 0}, B) end

function B:count() return #self.i // 3 end

local function push(self, x, y, z, col, u, v)
  local vv = self.v
  local k = #vv
  vv[k + 1], vv[k + 2], vv[k + 3] = x, y, z
  self.c[#self.c + 1] = col
  local uv = self.uv
  local m = #uv
  uv[m + 1], uv[m + 2] = u or self.du, v or self.dv
  self.n = self.n + 1
  return self.n
end

-- triangle; (hx, hy, hz) = the direction it should face; optional texture coordinates per corner
function B:tri(ax, ay, az, bx, by, bz, cx, cy, cz, col, hx, hy, hz, ua, va, ub, vb, uc, vc)
  if hx then
    local ux, uy, uz = bx - ax, by - ay, bz - az
    local vx, vy, vz = cx - ax, cy - ay, cz - az
    local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    if nx * hx + ny * hy + nz * hz < 0 then
      bx, by, bz, cx, cy, cz = cx, cy, cz, bx, by, bz
      ub, vb, uc, vc = uc, vc, ub, vb
    end
  end
  local i = self.i
  local a = push(self, ax, ay, az, col, ua, va)
  local b = push(self, bx, by, bz, col, ub, vb)
  local c = push(self, cx, cy, cz, col, uc, vc)
  local k = #i
  i[k + 1], i[k + 2], i[k + 3] = a, b, c
end

-- quad with explicit texture coordinates per corner
function B:quadUV(a, b, c, d, col, hx, hy, hz, ua, va, ub, vb, uc, vc, ud, vd)
  self:tri(a[1], a[2], a[3], b[1], b[2], b[3], c[1], c[2], c[3], col, hx, hy, hz, ua, va, ub, vb, uc, vc)
  self:tri(a[1], a[2], a[3], c[1], c[2], c[3], d[1], d[2], d[3], col, hx, hy, hz, ua, va, uc, vc, ud, vd)
end
-- quad a b c d (in order around the edge), facing the hint; r = {u0, v0, u1, v1}: a = (u0, v0), b = (u1, v0),
-- c = (u1, v1), d = (u0, v1)
function B:quad(a, b, c, d, col, hx, hy, hz, r)
  if r then
    self:quadUV(a, b, c, d, col, hx, hy, hz, r[1], r[2], r[3], r[2], r[3], r[4], r[1], r[4])
  else
    self:tri(a[1], a[2], a[3], b[1], b[2], b[3], c[1], c[2], c[3], col, hx, hy, hz)
    self:tri(a[1], a[2], a[3], c[1], c[2], c[3], d[1], d[2], d[3], col, hx, hy, hz)
  end
end
-- the same, seen from both sides (leaves, flags, signs)
function B:quad2(a, b, c, d, col, ua, va, ub, vb, uc, vc, ud, vd)
  self:tri(a[1], a[2], a[3], b[1], b[2], b[3], c[1], c[2], c[3], col, nil, nil, nil, ua, va, ub, vb, uc, vc)
  self:tri(a[1], a[2], a[3], c[1], c[2], c[3], d[1], d[2], d[3], col, nil, nil, nil, ua, va, uc, vc, ud, vd)
  self:tri(a[1], a[2], a[3], c[1], c[2], c[3], b[1], b[2], b[3], col, nil, nil, nil, ua, va, uc, vc, ub, vb)
  self:tri(a[1], a[2], a[3], d[1], d[2], d[3], c[1], c[2], c[3], col, nil, nil, nil, ua, va, ud, vd, uc, vc)
end

-- oriented box: centre, half sizes along the box axes (yaw around y), face colours top / sides / front / bottom.
-- uv (optional) = {top =, bottom =, nz =, pz =, nx =, px =} rectangles {u0, v0, u1, v1}: on the side faces u runs
-- along the face (from -x to +x on the z faces, from -z to +z on the x faces) and v from the top edge down; on the top
-- u runs along x and v along z. A rectangle with u0 > u1 mirrors it.
function B:box(cx, cy, cz, hx, hy, hz, yaw, top, side, front, bottom, uv)
  local c, s = cos(yaw or 0), sin(yaw or 0)
  local function P(x, y, z) return {cx + x * c + z * s, cy + y, cz - x * s + z * c} end
  local p = {P(-hx, -hy, -hz), P(hx, -hy, -hz), P(hx, -hy, hz), P(-hx, -hy, hz),
             P(-hx, hy, -hz), P(hx, hy, -hz), P(hx, hy, hz), P(-hx, hy, hz)}
  local function face(a, b, cc, d, col, r)
    local mx = (a[1] + b[1] + cc[1] + d[1]) / 4 - cx
    local my = (a[2] + b[2] + cc[2] + d[2]) / 4 - cy
    local mz = (a[3] + b[3] + cc[3] + d[3]) / 4 - cz
    if r then
      -- a, b = bottom edge (u0 -> u1), c, d = top edge
      self:quadUV(a, b, cc, d, col, mx, my, mz, r[1], r[4], r[3], r[4], r[3], r[2], r[1], r[2])
    else
      self:quad(a, b, cc, d, col, mx, my, mz)
    end
  end
  uv = uv or {}
  -- top: p5 (-x,-z) p6 (+x,-z) p7 (+x,+z) p8 (-x,+z); u along x, v along z
  if uv.top then
    local r = uv.top
    self:quadUV(p[5], p[6], p[7], p[8], top, 0, 1, 0, r[1], r[2], r[3], r[2], r[3], r[4], r[1], r[4])
  else
    face(p[5], p[6], p[7], p[8], top)
  end
  if bottom then face(p[1], p[2], p[3], p[4], bottom, uv.bottom) end
  face(p[1], p[2], p[6], p[5], front or side, uv.nz)   -- -z face
  face(p[4], p[3], p[7], p[8], side, uv.pz)            -- +z face
  face(p[1], p[4], p[8], p[5], side, uv.nx)            -- -x face
  face(p[2], p[3], p[7], p[6], side, uv.px)            -- +x face
end

-- a prism with n sides between two rings (trunks, posts); r = texture rectangle wrapped once around the sides,
-- v from the top (v0) to the bottom (v1); topR = rectangle for the cap
function B:column(x, y0, z, r0, y1, r1, n, col, topCol, lean, r, topR)
  lean = lean or 0
  for k = 0, n - 1 do
    local a0, a1 = k / n * 2 * pi, (k + 1) / n * 2 * pi
    local ax, az = cos(a0), sin(a0)
    local bx, bz = cos(a1), sin(a1)
    local q = {{x + ax * r0, y0, z + az * r0}, {x + bx * r0, y0, z + bz * r0},
               {x + lean + bx * r1, y1, z + bz * r1}, {x + lean + ax * r1, y1, z + az * r1}}
    if r then
      local u0, u1 = r[1] + (r[3] - r[1]) * k / n, r[1] + (r[3] - r[1]) * (k + 1) / n
      self:quadUV(q[1], q[2], q[3], q[4], col, (ax + bx), 0, (az + bz), u0, r[4], u1, r[4], u1, r[2], u0, r[2])
    else
      self:quad(q[1], q[2], q[3], q[4], col, (ax + bx), 0, (az + bz))
    end
    if topCol then
      local tx, tz = x + lean, z
      if topR then
        local mu, mv = (topR[1] + topR[3]) / 2, (topR[2] + topR[4]) / 2
        local hu, hv = (topR[3] - topR[1]) / 2, (topR[4] - topR[2]) / 2
        self:tri(tx, y1, tz, tx + ax * r1, y1, tz + az * r1, tx + bx * r1, y1, tz + bz * r1, topCol, 0, 1, 0,
                 mu, mv, mu + ax * hu, mv + az * hv, mu + bx * hu, mv + bz * hv)
      else
        self:tri(tx, y1, tz, tx + ax * r1, y1, tz + az * r1, tx + bx * r1, y1, tz + bz * r1, topCol, 0, 1, 0)
      end
    end
  end
end

local function max1(v) return v < 0.001 and 0.001 or v end

-- a cone / pyramid (rocks, roofs, umbrellas); r = rectangle wrapped once around, rim at v1, apex at v0
function B:cone(x, y0, z, rad, y1, n, col, rot, r)
  rot = rot or 0
  for k = 0, n - 1 do
    local a0, a1 = rot + k / n * 2 * pi, rot + (k + 1) / n * 2 * pi
    local ax, az, bx, bz = cos(a0) * rad, sin(a0) * rad, cos(a1) * rad, sin(a1) * rad
    local hy = (rad * rad) / max1(y1 - y0)
    if r then
      local u0, u1 = r[1] + (r[3] - r[1]) * k / n, r[1] + (r[3] - r[1]) * (k + 1) / n
      self:tri(x + ax, y0, z + az, x + bx, y0, z + bz, x, y1, z, col, ax + bx, hy, az + bz,
               u0, r[4], u1, r[4], (u0 + u1) / 2, r[2])
    else
      self:tri(x + ax, y0, z + az, x + bx, y0, z + bz, x, y1, z, col, ax + bx, hy, az + bz)
    end
  end
end

function B:mesh(flat)
  if #self.i == 0 then return nil end
  return g3d.custom(self.v, self.i, self.c, flat ~= false, self.uv)
end

-- a texture rectangle for tile (col, row) of a grid of n x n tiles, inset by `pad` texels of a `size` px texture
function B.tile(col, row, n, size, pad)
  local t = 1 / n
  local e = (pad or 2) / size
  return {col * t + e, row * t + e, (col + 1) * t - e, (row + 1) * t - e}
end

B.sqrt = sqrt
return B
