-- 3D Surface: plots z = f(x, y [, t]) as a height-coloured mesh. Includes a small, safe expression parser
-- (numbers, x y t r, pi e, + - * / ^, parentheses, implicit multiplication, sin cos tan asin acos atan sqrt abs exp
-- log ln floor sign) that compiles to Lua closures. No load() is used.
local app = {}

local floor, min, max, abs, sqrt, sin, cos, pi, exp, huge = math.floor, math.min, math.max, math.abs, math.sqrt, math.sin, math.cos, math.pi, math.exp, math.huge

local PANEL_W = 268
local BOX = 2.0          -- half size of the plotted square in scene units
local HEIGHT = 2.4       -- height of the auto-scaled surface

local PRESETS = {
  {key = "p_sinc", expr = "sin(sqrt(x^2+y^2))/sqrt(x^2+y^2)", range = 10},
  {key = "p_saddle", expr = "x^2 - y^2", range = 2},
  {key = "p_ripple", expr = "cos(2*sqrt(x^2+y^2)) * exp(-sqrt(x^2+y^2)/4)", range = 8},
  {key = "p_peaks", expr = "3(1-x)^2 exp(-x^2-(y+1)^2) - 10(x/5-x^3-y^5) exp(-x^2-y^2) - exp(-(x+1)^2-y^2)/3", range = 3},
  {key = "p_waves", expr = "sin(x + t) * cos(y + 0.7t) + 0.3 sin(2x - 1.3t)", range = 6},
  {key = "p_egg", expr = "sin(x) * cos(y)", range = 6},
  {key = "p_custom", expr = nil, range = nil},
}
local CUSTOM = #PRESETS

-- expression compiler ----------------------------------------------------------------------
local FUNCS = {
  sin = math.sin, cos = math.cos, tan = math.tan, asin = math.asin, acos = math.acos,
  atan = function(v) return math.atan(v) end, sqrt = math.sqrt, abs = math.abs, exp = math.exp,
  log = math.log, ln = math.log, floor = math.floor,
  sign = function(v) if v > 0 then return 1 elseif v < 0 then return -1 end return 0 end,
}
local CONSTS = {pi = pi, e = exp(1)}
local VARS = {x = true, y = true, t = true, r = true}
local NAMES = {}
for k in pairs(FUNCS) do NAMES[#NAMES + 1] = k end
for k in pairs(CONSTS) do NAMES[#NAMES + 1] = k end
for k in pairs(VARS) do NAMES[#NAMES + 1] = k end
table.sort(NAMES, function(a, b) return #a > #b end)

local function tokenize(src)
  local toks = {}
  local s = src:lower()
  local i = 1
  while i <= #s do
    local c = s:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif c:match("[%d%.]") then
      local num = s:match("^%d*%.?%d*", i)
      local ex = s:match("^e[%+%-]?%d+", i + #num)
      if ex then num = num .. ex end
      local v = tonumber(num)
      if not v or s:sub(i + #num, i + #num) == "." then return nil, {"err_number", i} end
      toks[#toks + 1] = {k = "num", v = v, p = i}
      i = i + #num
    elseif c:match("%a") then
      local id = s:match("^%a+", i)
      -- split runs like "xy" or "pix" into known names (longest match first)
      local j = 1
      while j <= #id do
        local found = nil
        for _, n in ipairs(NAMES) do
          if id:sub(j, j + #n - 1) == n then found = n; break end
        end
        if not found then return nil, {"err_unknown", i + j - 1, id} end
        toks[#toks + 1] = {k = "id", v = found, p = i + j - 1}
        j = j + #found
      end
      i = i + #id
    elseif c:match("[%+%-%*/%^%(%)]") then
      toks[#toks + 1] = {k = "op", v = c, p = i}
      i = i + 1
    else
      return nil, {"err_char", i, c}
    end
  end
  if #toks == 0 then return nil, {"err_empty", 1} end
  return toks
end

local function compile(src)
  local toks, err = tokenize(src)
  if not toks then return nil, err end
  local pos = 1
  local usesT = false
  local function peek() return toks[pos] end
  local function isConst(n) return n.c ~= nil end
  local function const(v) return {c = v, f = function() return v end} end
  local expr

  local function startsAtom(t)
    if not t then return false end
    if t.k == "num" or t.k == "id" then return true end
    return t.k == "op" and t.v == "("
  end

  local function atom()
    local t = peek()
    if not t then error({"err_end", #src + 1}, 0) end
    if t.k == "num" then pos = pos + 1; return const(t.v) end
    if t.k == "op" and t.v == "(" then
      pos = pos + 1
      local e = expr()
      local c = peek()
      if not c or c.v ~= ")" then error({"err_paren", c and c.p or #src + 1}, 0) end
      pos = pos + 1
      return e
    end
    if t.k == "id" then
      pos = pos + 1
      if FUNCS[t.v] then
        local f = FUNCS[t.v]
        local o = peek()
        if not o or o.v ~= "(" then error({"err_call", t.p, t.v}, 0) end
        pos = pos + 1
        local a = expr()
        local c = peek()
        if not c or c.v ~= ")" then error({"err_paren", c and c.p or #src + 1}, 0) end
        pos = pos + 1
        if isConst(a) then return const(f(a.c)) end
        local af = a.f
        return {f = function(x, y, tt, r) return f(af(x, y, tt, r)) end}
      elseif CONSTS[t.v] then
        return const(CONSTS[t.v])
      elseif t.v == "x" then return {f = function(x) return x end}
      elseif t.v == "y" then return {f = function(x, y) return y end}
      elseif t.v == "t" then usesT = true; return {f = function(x, y, tt) return tt end}
      elseif t.v == "r" then return {f = function(x, y, tt, r) return r end}
      end
    end
    error({"err_unexpected", t.p, t.v}, 0)
  end

  local unary
  local function power()
    local a = atom()
    local t = peek()
    if t and t.k == "op" and t.v == "^" then
      pos = pos + 1
      local b = unary()
      if isConst(a) and isConst(b) then return const(a.c ^ b.c) end
      local af, bf = a.f, b.f
      return {f = function(x, y, tt, r) return af(x, y, tt, r) ^ bf(x, y, tt, r) end}
    end
    return a
  end

  unary = function()
    local t = peek()
    if t and t.k == "op" and (t.v == "-" or t.v == "+") then
      pos = pos + 1
      local a = unary()
      if t.v == "+" then return a end
      if isConst(a) then return const(-a.c) end
      local af = a.f
      return {f = function(x, y, tt, r) return -af(x, y, tt, r) end}
    end
    return power()
  end

  local function term()
    local a = unary()
    while true do
      local t = peek()
      local op
      if t and t.k == "op" and (t.v == "*" or t.v == "/") then op = t.v; pos = pos + 1
      elseif startsAtom(t) then op = "*"
      else break end
      local b = unary()
      if isConst(a) and isConst(b) then
        a = const(op == "*" and a.c * b.c or a.c / b.c)
      else
        local af, bf = a.f, b.f
        if op == "*" then a = {f = function(x, y, tt, r) return af(x, y, tt, r) * bf(x, y, tt, r) end}
        else a = {f = function(x, y, tt, r) return af(x, y, tt, r) / bf(x, y, tt, r) end} end
      end
    end
    return a
  end

  expr = function()
    local a = term()
    while true do
      local t = peek()
      if not (t and t.k == "op" and (t.v == "+" or t.v == "-")) then break end
      pos = pos + 1
      local b = term()
      if isConst(a) and isConst(b) then
        a = const(t.v == "+" and a.c + b.c or a.c - b.c)
      else
        local af, bf = a.f, b.f
        if t.v == "+" then a = {f = function(x, y, tt, r) return af(x, y, tt, r) + bf(x, y, tt, r) end}
        else a = {f = function(x, y, tt, r) return af(x, y, tt, r) - bf(x, y, tt, r) end} end
      end
    end
    return a
  end

  local ok, res = pcall(function()
    local e = expr()
    if pos <= #toks then error({"err_unexpected", toks[pos].p, toks[pos].v}, 0) end
    return e
  end)
  if not ok then
    if type(res) == "table" then return nil, res end
    return nil, {"err_unexpected", 1, ""}
  end
  return res.f, nil, usesT
end

-- colour maps --------------------------------------------------------------------------------
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function c3(r, g, b) return {clamp(floor(r + 0.5), 0, 254), clamp(floor(g + 0.5), 0, 254), clamp(floor(b + 0.5), 0, 254)} end
local function ramp(stops, t)
  local n = #stops - 1
  local f = clamp(t, 0, 1) * n
  local i = min(n - 1, floor(f))
  local k = f - i
  local a, b = stops[i + 1], stops[i + 2]
  return c3(a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k)
end
local MAPS = {
  {{48, 18, 120}, {40, 110, 230}, {30, 200, 200}, {120, 230, 80}, {250, 210, 40}, {240, 80, 40}, {170, 20, 30}},
  {{68, 1, 84}, {59, 82, 139}, {33, 145, 140}, {94, 201, 98}, {253, 231, 37}},
  {{20, 10, 10}, {140, 20, 20}, {230, 90, 20}, {250, 200, 60}, {254, 250, 220}},
}
local PALETTES = {}
for m, stops in ipairs(MAPS) do
  PALETTES[m] = {}
  for i = 0, 63 do PALETTES[m][i] = ramp(stops, i / 63) end
end
local BAD = {120, 120, 120}

-- state ----------------------------------------------------------------------------------------
local preset = 1
local exprText = PRESETS[1].expr   -- the applied expression
local editText = exprText           -- what is in the text field
local resetRange = true
local fn, usesT = nil, false
local errMsg = nil
local range = 10
local res = 32
local mode = 1           -- 1 solid, 2 wire, 3 both
local cmap = 1
local autoRotate, showAxes, animate = true, true, true
local t = 0
local mesh
local dirty = true
local zmin, zmax = -1, 1
local dmin, dmax = -1, 1  -- smoothed display range
local V, Z, OK, C = {}, {}, {}, {}
local IDX, idxRes = nil, -1
local yaw, pitch, dist = 0.7, 0.55, 8.2
local lastDx, lastDy = 0, 0
local held = {}
local lastTris = 0
local ROT_SPEED = 0.18
local frameNo = 0

local function applyExpr(text)
  local f, err, ut = compile(text)
  if not f then
    local code, p, extra = err[1], err[2], err[3]
    errMsg = TR(code, p or 1, extra or "")
    audio.play("error")
    return false
  end
  fn, usesT = f, ut
  errMsg = nil
  exprText = text
  editText = text
  dirty = true
  resetRange = true
  return true
end

local function choosePreset(i)
  preset = i
  local p = PRESETS[i]
  if p.expr then
    range = p.range
    applyExpr(p.expr)
    store.set("preset", i)
  end
end

local function buildIndices(n)
  local idx = {}
  local w = n + 1
  for j = 0, n - 1 do
    for i = 0, n - 1 do
      local a = j * w + i + 1
      local b, c, d = a + 1, a + w + 1, a + w
      idx[#idx + 1] = a; idx[#idx + 1] = b; idx[#idx + 1] = c
      idx[#idx + 1] = a; idx[#idx + 1] = c; idx[#idx + 1] = d
    end
  end
  IDX, idxRes = idx, n
end

local function call(f, x, y, tt, r) return true, f(x, y, tt, r) end

local function evaluate(safe)
  local n = res
  local w = n + 1
  local lo, hi = huge, -huge
  local f = fn
  local ev = safe and pcall or call   -- the fast path runs without a pcall per point
  for j = 0, n do
    local y = -range + 2 * range * j / n
    for i = 0, n do
      local x = -range + 2 * range * i / n
      local r = sqrt(x * x + y * y)
      local okv, z = ev(f, x, y, t, r)
      if okv and z ~= z then
        -- removable singularities such as sin(r)/r at the origin
        local x2, y2 = x + 1e-7, y + 1e-7
        okv, z = ev(f, x2, y2, t, sqrt(x2 * x2 + y2 * y2))
      end
      local k = j * w + i + 1
      if okv and type(z) == "number" and z == z and z > -1e12 and z < 1e12 then
        Z[k] = z
        OK[k] = true
        if z < lo then lo = z end
        if z > hi then hi = z end
      else
        Z[k] = 0
        OK[k] = false
      end
    end
  end
  for k = (n + 1) * (n + 1) + 1, #Z do Z[k] = nil; OK[k] = nil end
  if lo == huge then lo, hi = -1, 1 end
  zmin, zmax = lo, hi
end

local function rebuild(first)
  if not fn then return end
  if idxRes ~= res then buildIndices(res) end
  if not pcall(evaluate, false) then evaluate(true) end
  -- display range: expand at once, shrink slowly (keeps animations steady)
  if first then dmin, dmax = zmin, zmax
  else
    if zmin < dmin then dmin = zmin else dmin = dmin + (zmin - dmin) * 0.05 end
    if zmax > dmax then dmax = zmax else dmax = dmax + (zmax - dmax) * 0.05 end
  end
  local span = dmax - dmin
  local mid = (dmax + dmin) / 2
  local scale = span > 1e-9 and HEIGHT / span or 0
  local n = res
  local w = n + 1
  local pal = PALETTES[cmap]
  local nv = 0
  for j = 0, n do
    local zz = BOX - 2 * BOX * j / n
    for i = 0, n do
      local k = j * w + i + 1
      local xx = -BOX + 2 * BOX * i / n
      local h = (Z[k] - mid) * scale
      V[nv + 1] = xx; V[nv + 2] = h; V[nv + 3] = zz
      nv = nv + 3
      if OK[k] then
        local tt = span > 1e-9 and (Z[k] - dmin) / span or 0.5
        C[k] = pal[clamp(floor(tt * 63 + 0.5), 0, 63)]
      else
        C[k] = BAD
      end
    end
  end
  for k = nv + 1, #V do V[k] = nil end
  for k = w * w + 1, #C do C[k] = nil end
  mesh = g3d.custom(V, IDX, C)
  dirty = false
end

local function fmt(v)
  if v ~= v then return "?" end
  local a = abs(v)
  if a >= 1e4 or (a > 0 and a < 1e-3) then return string.format("%.2e", v) end
  if a >= 100 then return string.format("%.0f", v) end
  return string.format("%.2f", v)
end

-- app ----------------------------------------------------------------------------------------
function app.load(arg)
  preset = store.get("preset", 1)
  if preset < 1 or preset > #PRESETS then preset = 1 end
  res = store.get("res", 32)
  mode = store.get("mode", 1)
  cmap = store.get("cmap", 1)
  autoRotate = store.get("auto", true)
  showAxes = store.get("axes", true)
  if preset == CUSTOM then
    range = store.get("range", 5)
    if not applyExpr(store.get("custom", "sin(x)*cos(y)")) then applyExpr("sin(x)*cos(y)") end
  else
    choosePreset(preset)
  end
  rebuild(true)
end

function app.update(dt)
  dt = min(dt, 0.05)
  if animate and usesT then
    t = t + dt
    frameNo = frameNo + 1
    -- dense animated grids are refreshed at 30 Hz to keep the frame rate up
    if res <= 28 or frameNo % 2 == 0 then dirty = true end
  end
  local lx, ly = input.stick("left")
  local rx, ry = input.stick("right")
  if abs(lx) > 0.15 then yaw = yaw - lx * dt * 2 end
  if abs(ly) > 0.15 then pitch = pitch + ly * dt * 1.5 end
  if abs(rx) > 0.15 then yaw = yaw - rx * dt * 2 end
  if abs(ry) > 0.15 then dist = dist * exp(-ry * dt) end
  if held.left then yaw = yaw + dt * 1.6 end
  if held.right then yaw = yaw - dt * 1.6 end
  if held.up then pitch = pitch + dt * 1.2 end
  if held.down then pitch = pitch - dt * 1.2 end
  if input.down("zl") then dist = dist * exp(dt) end
  if input.down("zr") then dist = dist * exp(-dt) end
  if autoRotate then yaw = yaw + dt * ROT_SPEED end
  pitch = clamp(pitch, -1.4, 1.45)
  dist = clamp(dist, 3.5, 20)
end

local function drawWire(lineCol)
  local n = res
  local w = n + 1
  local step = math.ceil(n / 20)
  local lift = 0.012
  local pal = PALETTES[cmap]
  local function vtx(i, j)
    local k = j * w + i + 1
    return V[(k - 1) * 3 + 1], V[(k - 1) * 3 + 2] + lift, V[(k - 1) * 3 + 3], C[k]
  end
  local js = {}
  for j = 0, n, step do js[#js + 1] = j end
  if js[#js] ~= n then js[#js + 1] = n end
  local is = js
  -- lines along x for selected rows, and along y for selected columns, sampled on the same stride
  for _, j in ipairs(js) do
    local px, py, pz, pc = vtx(0, j)
    for k = 2, #is do
      local i = is[k]
      local x, y, z, c = vtx(i, j)
      g3d.line(px, py, pz, x, y, z, lineCol or c, 1.2)
      px, py, pz = x, y, z
    end
  end
  for _, i in ipairs(is) do
    local px, py, pz = vtx(i, 0)
    for k = 2, #js do
      local j = js[k]
      local x, y, z, c = vtx(i, j)
      g3d.line(px, py, pz, x, y, z, lineCol or c, 1.2)
      px, py, pz = x, y, z
    end
  end
end

local function drawAxes(labels)
  local b = BOX
  local y0, y1 = -HEIGHT / 2 - 0.15, HEIGHT / 2 + 0.15
  local frame = {150, 160, 175, 110}
  -- floor grid
  for k = 0, 8 do
    local v = -b + 2 * b * k / 8
    g3d.line(v, y0, -b, v, y0, b, {130, 140, 155, 55}, 1)
    g3d.line(-b, y0, v, b, y0, v, {130, 140, 155, 55}, 1)
  end
  -- vertical edges of the box
  for _, c in ipairs({{-b, -b}, {b, -b}, {b, b}, {-b, b}}) do g3d.line(c[1], y0, c[2], c[1], y1, c[2], frame, 1) end
  for _, yy in ipairs({y1}) do
    g3d.line(-b, yy, -b, b, yy, -b, frame, 1); g3d.line(b, yy, -b, b, yy, b, frame, 1)
    g3d.line(b, yy, b, -b, yy, b, frame, 1); g3d.line(-b, yy, b, -b, yy, -b, frame, 1)
  end
  -- axes: x (red) along the front edge, y (green) along the left edge, z (blue) up the back-left corner
  g3d.line(-b, y0, b, b + 0.4, y0, b, {240, 80, 70}, 2.5)
  g3d.line(-b, y0, b, -b, y0, -b - 0.4, {80, 200, 100}, 2.5)
  g3d.line(-b, y0, b, -b, y1 + 0.3, b, {80, 140, 250}, 2.5)
  local function lab(text, x, y, z, col)
    local sx, sy = g3d.project(x, y, z)
    if sx then labels[#labels + 1] = {text, sx, sy, col} end
  end
  lab("x", b + 0.6, y0, b, {240, 90, 80})
  lab("y", -b, y0, -b - 0.6, {90, 210, 110})
  lab("z", -b, y1 + 0.5, b, {100, 150, 255})
  lab(fmt(-range), -b, y0 - 0.2, b + 0.25, nil)
  lab(fmt(range), b, y0 - 0.2, b + 0.25, nil)
  lab(fmt(range), -b - 0.3, y0 - 0.2, -b, nil)
  lab(fmt(dmax), -b - 0.35, HEIGHT / 2, b, nil)
  lab(fmt(dmin), -b - 0.35, -HEIGHT / 2, b, nil)
end

local MODE_KEYS = {"m_solid", "m_wire", "m_both"}
local MAP_KEYS = {"cm_rainbow", "cm_viridis", "cm_heat"}

function app.draw(w, h)
  local dark = theme.dark
  -- 3D view
  local vx, vw = PANEL_W, w - PANEL_W
  gfx.gradient(vx, 0, vw, h, dark and "#1E2230" or "#F4F6FA", dark and "#0C0E14" or "#D5DBE6")
  local hit = ui.hit("view", vx, 0, vw, h)
  if hit.pressed then lastDx, lastDy = 0, 0 end
  if hit.held then
    yaw = yaw - (hit.dx - lastDx) * 0.01
    pitch = clamp(pitch + (hit.dy - lastDy) * 0.008, -1.4, 1.45)
    lastDx, lastDy = hit.dx, hit.dy
  end
  if dirty then
    local first = resetRange
    resetRange = false
    rebuild(first)
  end
  local cp = cos(pitch)
  local ex, ey, ez = dist * cp * sin(yaw), dist * sin(pitch), dist * cp * cos(yaw)
  local labels = {}
  g3d.begin(vx, 0, vw, h, 42)
  g3d.camera(ex, ey, ez, 0, -0.1, 0)
  g3d.light(0.4, 1, 0.55, 0.42)
  if showAxes then drawAxes(labels) end
  if mesh then
    if mode == 1 or mode == 3 then g3d.draw(mesh, 0, 0, 0, 0, 0, 0, 1, 1, 1, nil, "nocull") end
    if mode == 2 then drawWire(nil) elseif mode == 3 then drawWire(dark and {10, 12, 18, 110} or {20, 24, 32, 90}) end
  end
  lastTris = g3d.finish()
  for _, l in ipairs(labels) do
    gfx.color(l[4] or (dark and {200, 206, 220} or {60, 66, 80}))
    gfx.text(l[1], l[2] - 40, l[3] - 8, 12, l[4] and "bold" or "mono", "center", 80)
  end
  -- formula overlay
  gfx.color(dark and {255, 255, 255, 200} or {20, 24, 32, 200})
  gfx.text("z = " .. exprText, vx + 16, 14, 13, "mono")

  -- left panel
  gfx.color(theme.dark and "#16181E" or "#F2F3F6")
  gfx.rect(0, 0, PANEL_W, h)
  gfx.color(theme.separator)
  gfx.rect(PANEL_W - 1, 0, 1, h)
  local x, pw = 16, PANEL_W - 32
  local y = 14
  gfx.color(theme.text)
  gfx.text(TR("title"), x, y, 18, "bold")
  y = y + 34
  gfx.color(theme.text2)
  gfx.text(TR("function"), x, y, 12, "semibold")
  local names = {}
  for i, p in ipairs(PRESETS) do names[i] = TR(p.key) end
  y = y + 18
  local np = ui.dropdown("preset", names, preset, x, y, pw, 30)
  if np ~= preset then
    if np == CUSTOM then preset = CUSTOM; store.set("preset", CUSTOM); store.set("custom", exprText); store.set("range", range)
    else choosePreset(np) end
  end
  y = y + 40
  gfx.color(theme.text2)
  gfx.text("z =", x, y + 8, 13, "mono")
  local nt, submitted = ui.textfield("expr", editText, x + 30, y, pw - 30, 30, TR("expr_hint"))
  y = y + 38
  local apply = ui.button(TR("apply"), x, y, 100, 30, "primary", "check")
  if (submitted or apply) then
    if applyExpr(nt) then
      if preset ~= CUSTOM and nt ~= PRESETS[preset].expr then preset = CUSTOM end
      store.set("preset", preset)
      if preset == CUSTOM then store.set("custom", nt); store.set("range", range) end
      audio.play("pop")
    end
  else
    editText = nt
  end
  if ui.button(TR("reset_view"), x + 108, y, pw - 108, 30, "default", "center_focus_strong") then yaw, pitch, dist = 0.7, 0.55, 8.2 end
  y = y + 36
  if errMsg then
    gfx.color(theme.red)
    local eh = gfx.wrap(errMsg, x, y, pw, 12)
    y = y + max(18, eh) + 4
  else
    y = y + 6
  end
  gfx.color(theme.text2)
  gfx.text(TR("range"), x, y, 12, "semibold")
  gfx.color(theme.text)
  gfx.text("± " .. fmt(range), x, y, 12, "mono", "right", pw)
  local nr = ui.slider("range", range, 0.5, 20, x, y + 16, pw, 0.5)
  if nr ~= range then range = nr; dirty = true; resetRange = true; if preset == CUSTOM then store.set("range", range) end end
  y = y + 50
  gfx.color(theme.text2)
  gfx.text(TR("resolution"), x, y, 12, "semibold")
  gfx.color(theme.text)
  gfx.text(TR("grid_n", res, res), x, y, 12, "mono", "right", pw)
  local nres = ui.slider("res", res, 8, 40, x, y + 16, pw, 2)
  nres = floor(nres / 2 + 0.5) * 2
  if nres ~= res then res = nres; dirty = true; resetRange = true; store.set("res", res) end
  y = y + 50
  local mnames = {}
  for i, k in ipairs(MODE_KEYS) do mnames[i] = TR(k) end
  local nm = ui.segmented("mode", mnames, mode, x, y, pw, 30)
  if nm ~= mode then mode = nm; store.set("mode", mode) end
  y = y + 40
  local cnames = {}
  for i, k in ipairs(MAP_KEYS) do cnames[i] = TR(k) end
  local nc = ui.segmented("cmap", cnames, cmap, x, y, pw, 30)
  if nc ~= cmap then cmap = nc; dirty = true; store.set("cmap", cmap) end
  y = y + 42
  local function toggleRow(label, id, v)
    gfx.color(theme.text)
    gfx.text(label, x, y + 6, 13)
    local nv = ui.toggle(id, v, x + pw - 50, y)
    y = y + 34
    return nv
  end
  local na = toggleRow(TR("auto_rotate"), "auto", autoRotate)
  if na ~= autoRotate then autoRotate = na; store.set("auto", na) end
  local nx = toggleRow(TR("axes"), "axes", showAxes)
  if nx ~= showAxes then showAxes = nx; store.set("axes", nx) end
  local nn = toggleRow(TR("animate"), "anim", animate)
  if nn ~= animate then animate = nn end
  -- info
  gfx.color(theme.text2)
  gfx.text(TR("z_range", fmt(zmin), fmt(zmax)), x, y + 2, 12, "mono")
  gfx.text(TR("tris_n", mesh and mesh:triangles() or 0, lastTris, floor(sys.fps() + 0.5)), x, y + 20, 11)
  gfx.color(theme.text3)
  gfx.wrap(TR("help"), x, h - 54, pw, 11)
end

function app.event(e)
  if e.type == "keydown" then
    if e.key == "left" or e.key == "right" or e.key == "up" or e.key == "down" then held[e.key] = true end
  elseif e.type == "keyup" then
    held[e.key] = nil
  elseif e.type == "scroll" then
    if (e.x or 0) > PANEL_W then dist = clamp(dist * exp(-e.dy * 0.004), 3.5, 20) end
  elseif e.type == "paddown" then
    if e.pad == "r" then choosePreset(preset % (CUSTOM - 1) + 1)
    elseif e.pad == "l" then choosePreset((preset - 2) % (CUSTOM - 1) + 1)
    elseif e.pad == "a" then mode = mode % 3 + 1; store.set("mode", mode)
    elseif e.pad == "x" then showAxes = not showAxes; store.set("axes", showAxes)
    elseif e.pad == "y" then autoRotate = not autoRotate; store.set("auto", autoRotate)
    elseif e.pad == "b" then cmap = cmap % 3 + 1; dirty = true; store.set("cmap", cmap)
    elseif e.pad == "up" then res = min(40, res + 2); dirty = true; store.set("res", res)
    elseif e.pad == "down" then res = max(8, res - 2); dirty = true; store.set("res", res)
    elseif e.pad == "plus" then animate = not animate
    elseif e.pad == "minus" then ui.keyboard(exprText, function(txt)
      if txt and applyExpr(txt) then preset = CUSTOM; store.set("preset", CUSTOM); store.set("custom", txt); store.set("range", range) end
    end, TR("expr_hint"))
    end
  end
end

function app.menu()
  local items = {}
  for i = 1, CUSTOM - 1 do items[#items + 1] = {label = TR(PRESETS[i].key), id = i} end
  items[#items + 1] = "-"
  items[#items + 1] = {label = TR("toggle_wire"), id = 100}
  items[#items + 1] = {label = TR("toggle_axes"), id = 101}
  items[#items + 1] = {label = TR("reset_view"), id = 102}
  return {{title = TR("function"), items = items}}
end

function app.onmenu(id)
  if id >= 1 and id < CUSTOM then choosePreset(id)
  elseif id == 100 then mode = mode % 3 + 1; store.set("mode", mode)
  elseif id == 101 then showAxes = not showAxes; store.set("axes", showAxes)
  elseif id == 102 then yaw, pitch, dist = 0.7, 0.55, 8.2
  end
end

return app
