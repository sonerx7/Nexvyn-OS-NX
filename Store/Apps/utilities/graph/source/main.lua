-- Grapher for Nexvyn OS: plot several y = f(x) functions, pan and zoom, trace, roots, intersections and a value table.
local app = {}

local floor, ceil, min, max, abs, log, exp = math.floor, math.ceil, math.min, math.max, math.abs, math.log, math.exp
local Expr = require("expr")

-- ------------------------------------------------------------------ helpers
local ccache = {}
local function rgba(c)
  if type(c) == "table" then return c end
  local t = ccache[c]
  if not t then
    t = {tonumber(c:sub(2, 3), 16) or 0, tonumber(c:sub(4, 5), 16) or 0, tonumber(c:sub(6, 7), 16) or 0,
         #c >= 9 and (tonumber(c:sub(8, 9), 16) or 255) or 255}
    ccache[c] = t
  end
  return t
end
local function fade(c, a)
  local t = rgba(c)
  return {t[1], t[2], t[3], max(0, min(255, floor(t[4] * a + 0.5)))}
end
local function approach(v, target, speed, dt) return v + (target - v) * min(1, dt * speed) end

local fieldRects, nFields, editing = {}, 0, false
local function field(id, text, x, y, w, h, ph, flags)
  nFields = nFields + 1
  local r = fieldRects[nFields]
  if not r then r = {}; fieldRects[nFields] = r end
  r[1], r[2], r[3], r[4] = x, y, w, h
  return ui.textfield(id, text, x, y, w, h, ph, flags)
end
local function pointInField(x, y)
  for i = 1, nFields do
    local r = fieldRects[i]
    if x >= r[1] and y >= r[2] and x <= r[1] + r[3] and y <= r[2] + r[4] then return true end
  end
  return false
end

local function finite(v) return v == v and v > -1e300 and v < 1e300 end

local function fmt(v)
  if v ~= v then return "—" end
  if v == math.huge then return "∞" end
  if v == -math.huge then return "−∞" end
  if abs(v) < 1e-12 then v = 0 end
  local a = abs(v)
  if a ~= 0 and (a >= 1e6 or a < 1e-4) then return string.format("%.3e", v) end
  local s = string.format("%.4f", v):gsub("0+$", ""):gsub("%.$", "")
  if s == "-0" then s = "0" end
  return s
end

local SUB = {"₁", "₂", "₃", "₄", "₅", "₆", "₇", "₈"}
local function fname(i) return "f" .. (SUB[i] or tostring(i)) end

-- ------------------------------------------------------------------ state
local PALETTE = {"blue", "red", "green", "purple", "orange", "pink", "yellow", "gray"}
local MAXF = 6
local funcs = {}            -- {expr, color, visible, fn, err}
local view = {cx = 0, cy = 0, scale = 60}
local showTrace = true
local showTable = false
local tableStart, tableStep = "-5", "1"
local results = {}
local resultsKey = ""
local resultsAt = 0
local viewDirtyAt = nil
local drag = nil
local focusPoint = nil       -- {x, y, t} pulse after clicking a result
local canvas = {x = 300, y = 0, w = 600, h = 600}
local zoomAnim = nil

local function compileF(f)
  local fn, err = Expr.compile(f.expr)
  f.fn = fn
  f.err = (f.expr:match("^%s*$") and nil) or err
end

local function saveFuncs()
  local out = {}
  for i, f in ipairs(funcs) do out[i] = {expr = f.expr, color = f.color, visible = f.visible} end
  store.set("funcs", out)
end
local function saveView()
  store.set("view", {cx = view.cx, cy = view.cy, scale = view.scale})
  store.set("opts", {trace = showTrace, tbl = showTable, start = tableStart, step = tableStep})
end

local function addFunction(expr)
  if #funcs >= MAXF then return end
  local used = {}
  for _, f in ipairs(funcs) do used[f.color] = true end
  local col = PALETTE[1]
  for _, c in ipairs(PALETTE) do if not used[c] then col = c break end end
  local f = {expr = expr or "", color = col, visible = true}
  compileF(f)
  funcs[#funcs + 1] = f
  saveFuncs()
end

-- ------------------------------------------------------------------ coordinates
local function toSX(x) return canvas.x + canvas.w / 2 + (x - view.cx) * view.scale end
local function toSY(y) return canvas.y + canvas.h / 2 - (y - view.cy) * view.scale end
local function toWX(sx) return view.cx + (sx - canvas.x - canvas.w / 2) / view.scale end
local function toWY(sy) return view.cy - (sy - canvas.y - canvas.h / 2) / view.scale end

local function zoomAt(factor, sx, sy)
  local ns = max(1e-4, min(1e7, view.scale * factor))
  if sx then
    local wx, wy = toWX(sx), toWY(sy)
    view.scale = ns
    view.cx = wx - (sx - canvas.x - canvas.w / 2) / ns
    view.cy = wy + (sy - canvas.y - canvas.h / 2) / ns
  else
    view.scale = ns
  end
  viewDirtyAt = sys.time()
end

local function resetView()
  view.cx, view.cy, view.scale = 0, 0, 60
  viewDirtyAt = sys.time()
  audio.play("click")
end

-- ------------------------------------------------------------------ analysis
local function bisect(h, a, b, fa)
  for _ = 1, 60 do
    local m = (a + b) / 2
    local fm = h(m)
    if not finite(fm) then return nil end
    if (fm < 0) == (fa < 0) then a, fa = m, fm else b = m end
  end
  return (a + b) / 2
end

local function minimizeAbs(h, a, b)
  for _ = 1, 50 do
    local m1 = a + (b - a) / 3
    local m2 = b - (b - a) / 3
    local f1, f2 = abs(h(m1)), abs(h(m2))
    if not finite(f1) or not finite(f2) then return nil end
    if f1 < f2 then b = m2 else a = m1 end
  end
  return (a + b) / 2
end

local function zerosOf(h, x0, x1, out, tag)
  local N = 500
  local dx = (x1 - x0) / N
  local tol = max(1e-9, 1e-7 * (abs(x0) + abs(x1)))
  local prevX, prevV = x0, h(x0)
  local vals = {prevV}
  for i = 1, N do
    local x = x0 + i * dx
    local v = h(x)
    vals[#vals + 1] = v
    if finite(v) and finite(prevV) then
      if v == 0 then
        out[#out + 1] = {x = x, tag = tag}
      elseif prevV ~= 0 and (v < 0) ~= (prevV < 0) then
        local r = bisect(h, prevX, x, prevV)
        if r then
          local hr = h(r)
          -- reject sign changes across asymptotes (tan, 1/x): a real zero ends near 0
          if finite(hr) and abs(hr) < 1e-6 then
            out[#out + 1] = {x = r, tag = tag}
          end
        end
      end
    end
    prevX, prevV = x, v
  end
  -- touching zeros (x^2 at 0): local minima of |h| that come very close to zero
  for i = 2, #vals - 1 do
    local a, b, c = vals[i - 1], vals[i], vals[i + 1]
    if finite(a) and finite(b) and finite(c) and b ~= 0 and (a < 0) == (b < 0) and (b < 0) == (c < 0)
       and abs(b) < abs(a) and abs(b) <= abs(c) and abs(b) < 0.05 * max(1, 60 / view.scale) then
      local r = minimizeAbs(h, x0 + (i - 2) * dx, x0 + i * dx)
      if r and abs(h(r)) < 1e-7 then out[#out + 1] = {x = r, tag = tag} end
    end
  end
  return tol
end

local function computeResults()
  local x0, x1 = toWX(canvas.x), toWX(canvas.x + canvas.w)
  local out = {}
  for i, f in ipairs(funcs) do
    if f.visible and f.fn then
      local list = {}
      local fn = f.fn
      zerosOf(fn, x0, x1, list, i)
      for _, r in ipairs(list) do out[#out + 1] = {kind = "root", a = i, x = r.x, y = 0} end
    end
  end
  for i = 1, #funcs do
    for j = i + 1, #funcs do
      local fa, fb = funcs[i], funcs[j]
      if fa.visible and fb.visible and fa.fn and fb.fn then
        local g1, g2 = fa.fn, fb.fn
        local list = {}
        zerosOf(function(x) return g1(x) - g2(x) end, x0, x1, list, 0)
        for _, r in ipairs(list) do
          local y = g1(r.x)
          if finite(y) then out[#out + 1] = {kind = "int", a = i, b = j, x = r.x, y = y} end
        end
      end
    end
  end
  -- de-duplicate close hits
  table.sort(out, function(p, q) if p.kind ~= q.kind then return p.kind < q.kind end return p.x < q.x end)
  local dedup = {}
  local eps = 2 / view.scale
  for _, r in ipairs(out) do
    local last = dedup[#dedup]
    if not (last and last.kind == r.kind and last.a == r.a and last.b == r.b and abs(last.x - r.x) < eps) then
      dedup[#dedup + 1] = r
    end
    if #dedup >= 40 then break end
  end
  results = dedup
end

local function resultsSignature()
  local parts = {string.format("%.6g|%.6g|%.6g|%d", view.cx, view.cy, view.scale, floor(canvas.w))}
  for _, f in ipairs(funcs) do parts[#parts + 1] = (f.visible and "1" or "0") .. f.expr end
  return table.concat(parts, ";")
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  local saved = store.get("funcs", nil)
  funcs = {}
  if type(saved) == "table" then
    for _, s in ipairs(saved) do
      if type(s) == "table" and type(s.expr) == "string" and #funcs < MAXF then
        local f = {expr = s.expr, color = type(s.color) == "string" and s.color or PALETTE[#funcs + 1],
                   visible = s.visible ~= false}
        compileF(f)
        funcs[#funcs + 1] = f
      end
    end
  end
  if saved == nil then
    addFunction("sin(x)")
    addFunction("x^2/4 - 1")
  end
  if #funcs == 0 then addFunction("") end
  local v = store.get("view", nil)
  if type(v) == "table" and tonumber(v.scale) and tonumber(v.cx) and tonumber(v.cy) then
    view.cx, view.cy, view.scale = tonumber(v.cx), tonumber(v.cy), max(1e-4, min(1e7, tonumber(v.scale)))
  end
  local o = store.get("opts", nil)
  if type(o) == "table" then
    showTrace = o.trace ~= false
    showTable = o.tbl == true
    if type(o.start) == "string" then tableStart = o.start end
    if type(o.step) == "string" then tableStep = o.step end
  end
end

function app.update(dt)
  if viewDirtyAt and sys.time() - viewDirtyAt > 0.6 then
    viewDirtyAt = nil
    saveView()
  end
  if zoomAnim then
    local t = min(1, (sys.time() - zoomAnim.t0) / 0.22)
    local k = 1 - (1 - t) ^ 3
    view.scale = zoomAnim.s0 * (zoomAnim.s1 / zoomAnim.s0) ^ k
    view.cx = zoomAnim.cx0 + (zoomAnim.cx1 - zoomAnim.cx0) * k
    view.cy = zoomAnim.cy0 + (zoomAnim.cy1 - zoomAnim.cy0) * k
    if t >= 1 then zoomAnim = nil; viewDirtyAt = sys.time() end
  end
end

local function animateTo(scale, cx, cy)
  zoomAnim = {t0 = sys.time(), s0 = view.scale, s1 = max(1e-4, min(1e7, scale)),
              cx0 = view.cx, cx1 = cx or view.cx, cy0 = view.cy, cy1 = cy or view.cy}
end

-- ------------------------------------------------------------------ drawing: canvas
local function niceStep(raw)
  local mag = 10 ^ floor(log(raw, 10))
  local n = raw / mag
  local s
  if n < 1.5 then s = 1 elseif n < 3.5 then s = 2 elseif n < 7.5 then s = 5 else s = 10 end
  return s * mag, (s == 2) and 4 or 5
end

local function labelFmt(v, step)
  if abs(v) < step * 1e-6 then return "0" end
  local a = abs(v)
  if a >= 1e5 or a < 1e-3 then return string.format("%.0e", v) end
  local d = max(0, -floor(log(step, 10) + 1e-9))
  return string.format("%." .. d .. "f", v)
end

local ptsBuf = {}
local function drawCurve(f, col)
  local cx0, cw = canvas.x, canvas.w
  local top, bot = canvas.y - 2000, canvas.y + canvas.h + 2000
  local n = 0
  local prevSY = nil
  local fn = f.fn
  local function flush()
    if n >= 4 then
      for i = n + 1, #ptsBuf do ptsBuf[i] = nil end
      gfx.color(col)
      gfx.lines(ptsBuf, 2.4)
    elseif n == 2 then
      gfx.circle(ptsBuf[1], ptsBuf[2], 1.4, col)
    end
    n = 0
  end
  local step = 1
  local px = cx0
  while px <= cx0 + cw do
    local y = fn(toWX(px))
    if finite(y) then
      local sy = toSY(y)
      if sy < top then sy = top elseif sy > bot then sy = bot end
      if prevSY and abs(sy - prevSY) > canvas.h * 1.5 then flush() end
      ptsBuf[n + 1], ptsBuf[n + 2] = px, sy
      n = n + 2
      prevSY = sy
    else
      flush()
      prevSY = nil
    end
    px = px + step
  end
  flush()
end

local function drawGrid()
  local x0, y0, w, h = canvas.x, canvas.y, canvas.w, canvas.h
  local step, sub = niceStep(80 / view.scale)
  local minor = step / sub
  local wx0, wx1 = toWX(x0), toWX(x0 + w)
  local wy1, wy0 = toWY(y0), toWY(y0 + h)
  local minorCol = theme.dark and "#FFFFFF0A" or "#00000009"
  local majorCol = theme.dark and "#FFFFFF1C" or "#00000018"
  -- minor
  if minor * view.scale >= 10 then
    gfx.color(minorCol)
    for i = ceil(wx0 / minor), floor(wx1 / minor) do local sx = toSX(i * minor); gfx.line(sx, y0, sx, y0 + h, 1) end
    for i = ceil(wy0 / minor), floor(wy1 / minor) do local sy = toSY(i * minor); gfx.line(x0, sy, x0 + w, sy, 1) end
  end
  gfx.color(majorCol)
  for i = ceil(wx0 / step), floor(wx1 / step) do local sx = toSX(i * step); gfx.line(sx, y0, sx, y0 + h, 1) end
  for i = ceil(wy0 / step), floor(wy1 / step) do local sy = toSY(i * step); gfx.line(x0, sy, x0 + w, sy, 1) end
  -- axes
  local ax = toSX(0)
  local ay = toSY(0)
  gfx.color(theme.text2)
  if ax >= x0 and ax <= x0 + w then gfx.line(ax, y0, ax, y0 + h, 1.5) end
  if ay >= y0 and ay <= y0 + h then gfx.line(x0, ay, x0 + w, ay, 1.5) end
  -- labels
  local ly = min(max(ay + 5, y0 + 4), y0 + h - 18)
  local lx = min(max(ax - 6, x0 + 40), x0 + w - 6)
  gfx.color(theme.text2)
  for i = ceil(wx0 / step), floor(wx1 / step) do
    local v = i * step
    if i ~= 0 then
      local sx = toSX(v)
      if sx > x0 + 14 and sx < x0 + w - 14 then
        gfx.text(labelFmt(v, step), sx - 40, ly, 11, "sans", "center", 80)
      end
    end
  end
  for i = ceil(wy0 / step), floor(wy1 / step) do
    local v = i * step
    if i ~= 0 then
      local sy = toSY(v)
      if sy > y0 + 10 and sy < y0 + h - 22 then
        gfx.text(labelFmt(v, step), lx - 100, sy - 7, 11, "sans", "right", 100)
      end
    end
  end
  if ax >= x0 and ax <= x0 + w and ay >= y0 and ay <= y0 + h then
    gfx.text("0", ax - 12, ay + 4, 11)
  end
end

local function nearestTrace(mx, my)
  local wx = toWX(mx)
  local best, bestD, bestY = nil, 1e9, nil
  for i, f in ipairs(funcs) do
    if f.visible and f.fn then
      local y = f.fn(wx)
      if finite(y) then
        local d = abs(toSY(y) - my)
        if d < bestD then best, bestD, bestY = i, d, y end
      end
    end
  end
  return best, wx, bestY
end

local function drawTraceBox(i, wx, wy)
  local f = funcs[i]
  local col = theme[f.color] or theme.blue
  local sx, sy = toSX(wx), toSY(wy)
  gfx.color(fade(col, 0.5))
  gfx.line(sx, canvas.y, sx, canvas.y + canvas.h, 1)
  gfx.circle(sx, sy, 9, fade(col, 0.25))
  gfx.circle(sx, sy, 5, col)
  gfx.circle(sx, sy, 2.2, "#FFFFFF")
  local label = fname(i) .. "  (" .. fmt(wx) .. ", " .. fmt(wy) .. ")"
  local tw = gfx.textWidth(label, 12.5, "medium") + 20
  local bx = sx + 14
  local by = sy - 36
  if bx + tw > canvas.x + canvas.w - 6 then bx = sx - 14 - tw end
  if by < canvas.y + 6 then by = sy + 14 end
  gfx.shadow(bx, by, tw, 26, 8, 10, 2)
  gfx.rect(bx, by, tw, 26, 8, theme.dark and "#3A3A3C" or "#FFFFFF")
  gfx.color(col)
  gfx.rect(bx, by, 4, 26, 2)
  gfx.color(theme.text)
  gfx.text(label, bx + 12, by + 6, 12.5, "medium")
end

local function drawCanvas()
  local x0, y0, w, h = canvas.x, canvas.y, canvas.w, canvas.h
  gfx.clip(x0, y0, w, h)
  gfx.rect(x0, y0, w, h, 0, theme.bg)
  drawGrid()
  for i, f in ipairs(funcs) do
    if f.visible and f.fn then drawCurve(f, theme[f.color] or theme.blue) end
  end
  -- roots and intersections
  for _, r in ipairs(results) do
    local sx, sy = toSX(r.x), toSY(r.y)
    local col = theme[funcs[r.a] and funcs[r.a].color or "gray"] or theme.gray
    gfx.circle(sx, sy, 5.5, theme.bg)
    gfx.color(r.kind == "int" and theme.text or col)
    gfx.circleLine(sx, sy, 5, 2)
  end
  if focusPoint then
    local age = sys.time() - focusPoint.t
    if age < 1.2 then
      local k = age / 1.2
      gfx.color(fade(theme.accent, 1 - k))
      gfx.circleLine(toSX(focusPoint.x), toSY(focusPoint.y), 8 + k * 24, 2.5)
    else
      focusPoint = nil
    end
  end
  -- interaction
  local hit = ui.hit("canvas", x0, y0, w, h)
  local mx, my, down, hov = ui.mouse()
  local inside = mx >= x0 and mx <= x0 + w and my >= y0 and my <= y0 + h
  if showTrace then
    if inside and (hov or hit.held) then
      local i, wx, wy = nearestTrace(mx, my)
      if i then drawTraceBox(i, wx, wy) end
    end
  else
    if hit.pressed then drag = {cx = view.cx, cy = view.cy} end
    if drag and hit.held then
      view.cx = drag.cx - hit.dx / view.scale
      view.cy = drag.cy + hit.dy / view.scale
      viewDirtyAt = sys.time()
    elseif drag and not hit.held then
      drag = nil
    end
  end
  if hit.doubleClicked then animateTo(view.scale * 2, toWX(mx), toWY(my)) end
  -- pointer coordinates
  if inside and hov then
    local s = "x = " .. fmt(toWX(mx)) .. "   y = " .. fmt(toWY(my))
    local tw = gfx.textWidth(s, 11.5, "mono") + 16
    gfx.rect(x0 + 10, y0 + h - 32, tw, 22, 6, theme.dark and "#2C2C2ECC" or "#FFFFFFCC")
    gfx.color(theme.text2)
    gfx.text(s, x0 + 18, y0 + h - 28, 11.5, "mono")
  end
  gfx.unclip()
  -- mode hint chip
  local hint = showTrace and TR("hint_trace") or TR("hint_pan")
  local tw = gfx.textWidth(hint, 11.5) + 18
  gfx.rect(x0 + w - tw - 10, y0 + 10, tw, 22, 11, theme.dark and "#2C2C2ECC" or "#FFFFFFCC")
  gfx.color(theme.text3)
  gfx.text(hint, x0 + w - tw - 1, y0 + 14, 11.5)
end

-- ------------------------------------------------------------------ drawing: table
local function parseNum(s)
  s = (s or ""):gsub(",", "."):gsub("%s", "")
  return tonumber(s)
end

local function drawTable(x, y, w, h)
  gfx.rect(x, y, w, h, 0, theme.sidebar)
  gfx.color(theme.separator)
  gfx.line(x, y, x, y + h, 1)
  gfx.color(theme.text)
  gfx.text(TR("table"), x + 16, y + 16, 15, "semibold")
  gfx.color(theme.text2)
  gfx.text(TR("start"), x + 16, y + 52, 12, "medium")
  local ns = field("tstart", tableStart, x + 60, y + 46, 70, 28, "-5", "numeric")
  if ns ~= tableStart then tableStart = ns; viewDirtyAt = sys.time() end
  gfx.color(theme.text2)
  gfx.text(TR("step"), x + 144, y + 52, 12, "medium")
  local np = field("tstep", tableStep, x + 186, y + 46, 70, 28, "1", "numeric")
  if np ~= tableStep then tableStep = np; viewDirtyAt = sys.time() end
  local start = parseNum(tableStart) or 0
  local step = parseNum(tableStep) or 1
  if step == 0 then step = 1 end
  local cols = {}
  for i, f in ipairs(funcs) do
    if f.visible and f.fn and #cols < 3 then cols[#cols + 1] = i end
  end
  local top = y + 88
  local colW = (w - 24 - 70) / max(1, #cols)
  gfx.color(theme.text2)
  gfx.text("x", x + 12, top, 12, "semibold", "center", 70)
  for k, i in ipairs(cols) do
    gfx.color(theme[funcs[i].color] or theme.text)
    gfx.text(fname(i), x + 12 + 70 + (k - 1) * colW, top, 12, "semibold", "center", colW)
  end
  local rowH = 26
  local rows = 60
  local ly = top + 20
  ui.beginScroll("table", x, ly, w, h - (ly - y) - 8, rows * rowH)
  for r = 0, rows - 1 do
    local xv = start + r * step
    local yy = r * rowH
    if r % 2 == 0 then gfx.rect(8, yy, w - 16, rowH, 6, theme.dark and "#FFFFFF08" or "#00000006") end
    gfx.color(theme.text)
    gfx.text(fmt(xv), 12, yy + 6, 12, "mono", "center", 70)
    for k, i in ipairs(cols) do
      local v = funcs[i].fn(xv)
      gfx.color(finite(v) and theme.text or theme.text3)
      gfx.text(fmt(v), 12 + 70 + (k - 1) * colW, yy + 6, 12, "mono", "center", colW)
    end
  end
  ui.endScroll()
end

-- ------------------------------------------------------------------ drawing: sidebar
local function drawSidebar(w, h)
  local sw = 300
  gfx.rect(0, 0, sw, h, 0, theme.sidebar)
  gfx.color(theme.separator)
  gfx.line(sw - 1, 0, sw - 1, h, 1)
  gfx.color(theme.text)
  gfx.text(TR("title"), 16, 16, 20, "bold")
  local y = 56
  local rowH = 58
  local removeIdx = nil
  for i, f in ipairs(funcs) do
    local col = theme[f.color] or theme.blue
    local dh = ui.hit("dot" .. i, 10, y, 30, 34)
    gfx.circle(25, y + 17, 9, f.visible and col or fade(col, 0.3))
    if dh.hovered then
      gfx.color(col)
      gfx.circleLine(25, y + 17, 12, 1.5)
    end
    if dh.clicked then
      local idx = 1
      for k, c in ipairs(PALETTE) do if c == f.color then idx = k end end
      f.color = PALETTE[idx % #PALETTE + 1]
      saveFuncs()
      audio.play("click")
    end
    gfx.color(theme.text3)
    gfx.text(fname(i), 44, y + 9, 12, "semibold")
    local ne = field("f" .. i, f.expr, 66, y, 160, 34, TR("expr_ph"))
    if ne ~= f.expr then
      f.expr = ne
      compileF(f)
      saveFuncs()
    end
    if ui.iconButton(f.visible and "visibility" or "visibility_off", 230, y + 2, 32, 30, f.visible and theme.text2 or theme.text3, false, "vis" .. i) then
      f.visible = not f.visible
      saveFuncs()
      audio.play("click")
    end
    if ui.iconButton("close", 262, y + 2, 30, 30, theme.text3, false, "del" .. i) then removeIdx = i end
    if f.err then
      gfx.icon("error_outline", 74, y + 45, 13, theme.red)
      gfx.color(theme.red)
      gfx.text(TR(f.err), 84, y + 38, 11.5)
    end
    y = y + rowH
  end
  if removeIdx then
    table.remove(funcs, removeIdx)
    if #funcs == 0 then addFunction("") end
    saveFuncs()
    audio.play("trash")
  end
  if #funcs < MAXF then
    if ui.button(TR("add_function") .. "##add", 16, y, 268, 32, "default", "add") then
      addFunction("")
      ui.focus("f" .. #funcs)
      editing = true
      audio.play("pop")
    end
    y = y + 44
  end
  -- view controls
  ui.separator(16, y, sw - 16)
  y = y + 12
  if ui.iconButton("zoom_out", 16, y, 40, 34, theme.text2, false, "zout") then
    animateTo(view.scale / 1.6)
    audio.play("click")
  end
  if ui.iconButton("zoom_in", 60, y, 40, 34, theme.text2, false, "zin") then
    animateTo(view.scale * 1.6)
    audio.play("click")
  end
  if ui.iconButton("center_focus_strong", 104, y, 40, 34, theme.text2, false, "zreset") then
    animateTo(60, 0, 0)
    audio.play("click")
  end
  local nt = ui.toggle("trace", showTrace, sw - 58, y + 6)
  gfx.color(theme.text2)
  gfx.text(TR("trace"), sw - 64 - gfx.textWidth(TR("trace"), 13), y + 9, 13)
  if nt ~= showTrace then showTrace = nt; saveView(); audio.play("click") end
  y = y + 44
  local tb = ui.toggle("tbl", showTable, sw - 58, y + 2)
  gfx.icon("table_chart", 26, y + 13, 18, theme.text2)
  gfx.color(theme.text)
  gfx.text(TR("show_table"), 44, y + 5, 13.5)
  if tb ~= showTable then showTable = tb; saveView(); audio.play("click") end
  y = y + 36
  -- analysis
  ui.separator(16, y, sw - 16)
  y = y + 10
  gfx.color(theme.text2)
  gfx.text(TR("analysis"), 16, y + 2, 12, "semibold")
  gfx.color(theme.text3)
  gfx.text(TR("in_view"), 0, y + 3, 11, "sans", "right", sw - 16)
  y = y + 22
  local lh = h - y - 8
  if #results == 0 then
    gfx.color(theme.text3)
    gfx.text(TR("no_results"), 16, y + 6, 12.5)
    return
  end
  local rowH2 = 30
  ui.beginScroll("results", 0, y, sw, lh, #results * rowH2)
  for k, r in ipairs(results) do
    local yy = (k - 1) * rowH2
    local hh = ui.hit("res" .. k, 8, yy, sw - 16, rowH2 - 2)
    if hh.hovered then gfx.rect(8, yy, sw - 16, rowH2 - 2, 6, theme.hover) end
    local ca = theme[funcs[r.a] and funcs[r.a].color or "gray"] or theme.gray
    gfx.circle(22, yy + 14, 4.5, ca)
    if r.kind == "int" then
      local cb = theme[funcs[r.b] and funcs[r.b].color or "gray"] or theme.gray
      gfx.circle(32, yy + 14, 4.5, cb)
    end
    gfx.color(theme.text)
    local label
    if r.kind == "root" then label = TR("root_fmt", fname(r.a), fmt(r.x))
    else label = TR("int_fmt", fname(r.a), fname(r.b), fmt(r.x), fmt(r.y)) end
    gfx.clip(42, yy, sw - 56, rowH2)
    gfx.text(label, 42, yy + 7, 12, "mono")
    gfx.unclip()
    if hh.clicked then
      animateTo(view.scale, r.x, r.y)
      focusPoint = {x = r.x, y = r.y, t = sys.time() + 0.2}
      audio.play("click")
    end
  end
  ui.endScroll()
end

-- ------------------------------------------------------------------ main draw
function app.draw(w, h)
  nFields = 0
  gfx.clear(theme.bg)
  local tableW = showTable and 300 or 0
  canvas.x, canvas.y, canvas.w, canvas.h = 300, 0, w - 300 - tableW, h
  -- refresh analysis when the view or the functions change (debounced)
  local sig = resultsSignature()
  if sig ~= resultsKey and sys.time() - resultsAt > 0.2 and not drag and not zoomAnim then
    resultsKey = sig
    resultsAt = sys.time()
    computeResults()
  end
  drawCanvas()
  if showTable then drawTable(w - tableW, 0, tableW, h) end
  drawSidebar(w, h)
end

-- ------------------------------------------------------------------ input
function app.event(e)
  if e.type == "mousedown" then
    editing = pointInField(e.x, e.y)
    return
  end
  if e.type == "scroll" then
    if e.x >= canvas.x and e.x <= canvas.x + canvas.w and e.y >= canvas.y and e.y <= canvas.y + canvas.h then
      if e.dy ~= 0 then zoomAt(exp(-e.dy * 0.0035), e.x, e.y) end
      if e.dx ~= 0 then view.cx = view.cx + e.dx / view.scale; viewDirtyAt = sys.time() end
    end
    return
  end
  if e.type ~= "keydown" then return end
  if editing then
    if e.key == "escape" then editing = false end
    return
  end
  local panX = canvas.w * 0.1 / view.scale
  local panY = canvas.h * 0.1 / view.scale
  if e.key == "left" then animateTo(view.scale, view.cx - panX, view.cy)
  elseif e.key == "right" then animateTo(view.scale, view.cx + panX, view.cy)
  elseif e.key == "up" then animateTo(view.scale, view.cx, view.cy + panY)
  elseif e.key == "down" then animateTo(view.scale, view.cx, view.cy - panY)
  elseif e.key == "=" or e.key == "+" or e.key == "pageup" then animateTo(view.scale * 1.6)
  elseif e.key == "-" or e.key == "pagedown" then animateTo(view.scale / 1.6)
  elseif e.key == "0" or e.key == "home" then animateTo(60, 0, 0)
  elseif e.key == "t" then showTrace = not showTrace; saveView()
  elseif e.key == "n" then
    if #funcs < MAXF then addFunction(""); ui.focus("f" .. #funcs); editing = true end
  end
end

function app.menu()
  return {{title = TR("menu_graph"), items = {
    {label = TR("add_function"), id = 1, shortcut = "N", enabled = #funcs < MAXF},
    "-",
    {label = TR("zoom_in"), id = 2, shortcut = "+"},
    {label = TR("zoom_out"), id = 3, shortcut = "-"},
    {label = TR("reset_view"), id = 4, shortcut = "0"},
    "-",
    {label = TR("trace"), id = 5, checked = showTrace},
    {label = TR("show_table"), id = 6, checked = showTable},
  }}}
end

function app.onmenu(id)
  if id == 1 then addFunction("")
  elseif id == 2 then animateTo(view.scale * 1.6)
  elseif id == 3 then animateTo(view.scale / 1.6)
  elseif id == 4 then animateTo(60, 0, 0)
  elseif id == 5 then showTrace = not showTrace; saveView()
  elseif id == 6 then showTable = not showTable; saveView() end
end

function app.close()
  saveFuncs()
  saveView()
  store.save()
  return true
end

return app
