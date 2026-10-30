-- builder.lua: helpers that merge simple shapes into one g3d.custom mesh with per-vertex colours.
-- Convex parts (boxes, prisms, cones, spheres) fix their own winding against their centre; lathe and tube surfaces
-- share vertices so they can be smooth-shaded.
local B = {}
B.__index = B

local sqrt, sin, cos, pi, floor = math.sqrt, math.sin, math.cos, math.pi, math.floor

local function new()
  return setmetatable({v = {}, i = {}, c = {}}, B)
end

function B:vert(x, y, z, col)
  local v = self.v
  v[#v + 1] = x; v[#v + 1] = y; v[#v + 1] = z
  self.c[#self.c + 1] = col
  return #v // 3
end

function B:face(a, b, c)
  local i = self.i
  i[#i + 1] = a; i[#i + 1] = b; i[#i + 1] = c
end

-- triangle from three {x,y,z} points; with a centre it is wound so its normal points away from the centre
function B:tri(a, b, c, col, cx, cy, cz)
  if cx then
    local ux, uy, uz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
    local vx, vy, vz = c[1] - a[1], c[2] - a[2], c[3] - a[3]
    local nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    local mx = (a[1] + b[1] + c[1]) / 3 - cx
    local my = (a[2] + b[2] + c[2]) / 3 - cy
    local mz = (a[3] + b[3] + c[3]) / 3 - cz
    if nx * mx + ny * my + nz * mz < 0 then b, c = c, b end
  end
  local i1 = self:vert(a[1], a[2], a[3], col)
  local i2 = self:vert(b[1], b[2], b[3], col)
  local i3 = self:vert(c[1], c[2], c[3], col)
  self:face(i1, i2, i3)
end

function B:quad(a, b, c, d, col, cx, cy, cz)
  self:tri(a, b, c, col, cx, cy, cz)
  self:tri(a, c, d, col, cx, cy, cz)
end

-- axis-aligned box; topCol optionally colours the +y face, faceCols = {px,nx,py,ny,pz,nz} overrides all
function B:box(cx, cy, cz, sx, sy, sz, col, topCol, faceCols)
  local x0, x1 = cx - sx / 2, cx + sx / 2
  local y0, y1 = cy - sy / 2, cy + sy / 2
  local z0, z1 = cz - sz / 2, cz + sz / 2
  local fc = faceCols or {col, col, topCol or col, col, col, col}
  self:quad({x1, y0, z0}, {x1, y1, z0}, {x1, y1, z1}, {x1, y0, z1}, fc[1], cx, cy, cz)
  self:quad({x0, y0, z0}, {x0, y0, z1}, {x0, y1, z1}, {x0, y1, z0}, fc[2], cx, cy, cz)
  self:quad({x0, y1, z0}, {x0, y1, z1}, {x1, y1, z1}, {x1, y1, z0}, fc[3], cx, cy, cz)
  self:quad({x0, y0, z0}, {x1, y0, z0}, {x1, y0, z1}, {x0, y0, z1}, fc[4], cx, cy, cz)
  self:quad({x0, y0, z1}, {x1, y0, z1}, {x1, y1, z1}, {x0, y1, z1}, fc[5], cx, cy, cz)
  self:quad({x0, y0, z0}, {x0, y1, z0}, {x1, y1, z0}, {x1, y0, z0}, fc[6], cx, cy, cz)
end

local function axisPoint(axis, cx, cy, cz, along, a, b)
  if axis == "x" then return {cx + along, cy + a, cz + b}
  elseif axis == "y" then return {cx + a, cy + along, cz + b}
  else return {cx + a, cy + b, cz + along} end
end

-- prism / frustum / cone along an axis: radius r at -len/2, r2 at +len/2 (r2 = 0 gives a cone)
function B:prism(axis, cx, cy, cz, r, len, sides, col, capCol, r2, rot)
  r2 = r2 or r
  rot = rot or 0
  local h = len / 2
  for k = 0, sides - 1 do
    local a0, a1 = rot + k / sides * 2 * pi, rot + (k + 1) / sides * 2 * pi
    local p0 = axisPoint(axis, cx, cy, cz, -h, cos(a0) * r, sin(a0) * r)
    local p1 = axisPoint(axis, cx, cy, cz, -h, cos(a1) * r, sin(a1) * r)
    local q0 = axisPoint(axis, cx, cy, cz, h, cos(a0) * r2, sin(a0) * r2)
    local q1 = axisPoint(axis, cx, cy, cz, h, cos(a1) * r2, sin(a1) * r2)
    if r2 > 0 then self:quad(p0, p1, q1, q0, col, cx, cy, cz) else self:tri(p0, p1, q0, col, cx, cy, cz) end
    if r > 0 then self:tri(axisPoint(axis, cx, cy, cz, -h, 0, 0), p0, p1, capCol or col, cx, cy, cz) end
    if r2 > 0 then self:tri(axisPoint(axis, cx, cy, cz, h, 0, 0), q0, q1, capCol or col, cx, cy, cz) end
  end
end

-- low-poly sphere (faceted); jitter > 0 makes it rock-like (deterministic per call via rnd function)
function B:sphere(cx, cy, cz, r, seg, rings, col, jitter, rnd, sy)
  sy = sy or 1
  local pts = {}
  for i = 0, rings do
    local th = pi * i / rings
    pts[i] = {}
    for j = 0, seg - 1 do
      local ph = 2 * pi * j / seg
      local rr = r
      if jitter and jitter > 0 and i > 0 and i < rings then rr = r * (1 + (rnd() - 0.5) * 2 * jitter) end
      pts[i][j] = {cx + sin(th) * cos(ph) * rr, cy + cos(th) * rr * sy, cz + sin(th) * sin(ph) * rr}
    end
  end
  for i = 0, rings - 1 do
    for j = 0, seg - 1 do
      local j2 = (j + 1) % seg
      local c = type(col) == "function" and col(i, j) or col
      if i == 0 then self:tri(pts[0][j], pts[1][j], pts[1][j2], c, cx, cy, cz)
      elseif i == rings - 1 then self:tri(pts[i][j], pts[i + 1][j], pts[i][j2], c, cx, cy, cz)
      else self:quad(pts[i][j], pts[i + 1][j], pts[i + 1][j2], pts[i][j2], c, cx, cy, cz) end
    end
  end
end

-- smooth surface of revolution around the y axis through (cx, cz). profile = {{r, y}, ...} bottom to top.
-- colfn(k, j) or a colour.
function B:lathe(cx, cz, profile, seg, col)
  local idx = {}
  for k, p in ipairs(profile) do
    idx[k] = {}
    for j = 0, seg - 1 do
      local a = 2 * pi * j / seg
      local c = type(col) == "function" and col(k, j) or col
      idx[k][j] = self:vert(cx + p[1] * cos(a), p[2], cz + p[1] * sin(a), c)
    end
  end
  for k = 1, #profile - 1 do
    for j = 0, seg - 1 do
      local j2 = (j + 1) % seg
      local a, b, c, d = idx[k][j], idx[k + 1][j], idx[k + 1][j2], idx[k][j2]
      if profile[k][1] > 1e-6 or profile[k + 1][1] > 1e-6 then
        if profile[k + 1][1] <= 1e-6 then self:face(a, b, d)
        elseif profile[k][1] <= 1e-6 then self:face(a, b, c)
        else self:face(a, b, c); self:face(a, c, d) end
      end
    end
  end
end

local function norm(x, y, z)
  local l = sqrt(x * x + y * y + z * z)
  if l < 1e-9 then return 0, 0, 0 end
  return x / l, y / l, z / l
end
local function cross(ax, ay, az, bx, by, bz) return ay * bz - az * by, az * bx - ax * bz, ax * by - ay * bx end

-- smooth tube along points {{x,y,z},...}; radius may be a number or function(i, n) -> r
function B:tube(points, radius, sides, col, closed)
  local n = #points
  local T = {}
  for i = 1, n do
    local p0 = points[i > 1 and i - 1 or (closed and n or 1)]
    local p1 = points[i < n and i + 1 or (closed and 1 or n)]
    T[i] = {norm(p1[1] - p0[1], p1[2] - p0[2], p1[3] - p0[3])}
  end
  -- parallel transport frame
  local t = T[1]
  local ux, uy, uz = 0, 1, 0
  if math.abs(t[2]) > 0.9 then ux, uy, uz = 1, 0, 0 end
  local nx, ny, nz = norm(cross(t[1], t[2], t[3], ux, uy, uz))
  local N = {}
  for i = 1, n do
    local ti = T[i]
    local d = nx * ti[1] + ny * ti[2] + nz * ti[3]
    nx, ny, nz = norm(nx - ti[1] * d, ny - ti[2] * d, nz - ti[3] * d)
    N[i] = {nx, ny, nz}
  end
  local twist = 0
  if closed then
    -- spread the frame mismatch at the seam over the whole loop
    local t1, n1, nn = T[1], N[1], N[n]
    local d = nn[1] * t1[1] + nn[2] * t1[2] + nn[3] * t1[3]
    local ex, ey, ez = norm(nn[1] - t1[1] * d, nn[2] - t1[2] * d, nn[3] - t1[3] * d)
    local bx, by, bz = cross(t1[1], t1[2], t1[3], n1[1], n1[2], n1[3])
    twist = math.atan(ex * bx + ey * by + ez * bz, ex * n1[1] + ey * n1[2] + ez * n1[3])
  end
  local ring = {}
  for i = 1, n do
    local p, ti, ni = points[i], T[i], N[i]
    local bx, by, bz = cross(ti[1], ti[2], ti[3], ni[1], ni[2], ni[3])
    local r = type(radius) == "function" and radius(i, n) or radius
    local off = closed and -twist * (i - 1) / n or 0
    ring[i] = {}
    for j = 0, sides - 1 do
      local a = 2 * pi * j / sides + off
      local ca, sa = cos(a), sin(a)
      local c = type(col) == "function" and col(i, j, n) or col
      ring[i][j] = self:vert(p[1] + r * (ca * ni[1] + sa * bx), p[2] + r * (ca * ni[2] + sa * by), p[3] + r * (ca * ni[3] + sa * bz), c)
    end
  end
  local last = closed and n or n - 1
  for i = 1, last do
    local i2 = i < n and i + 1 or 1
    for j = 0, sides - 1 do
      local j2 = (j + 1) % sides
      local a, b, c, d = ring[i][j], ring[i][j2], ring[i2][j2], ring[i2][j]
      self:face(a, b, c)
      self:face(a, c, d)
    end
  end
  return ring
end

function B:count() return #self.i // 3 end

function B:mesh(flat)
  return g3d.custom(self.v, self.i, self.c, flat == true)
end

return {new = new}
