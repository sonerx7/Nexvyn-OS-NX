-- Fractal Explorer: the Mandelbrot set and its Julia sets. Drag to pan, pinch / scroll / double-tap to zoom.
-- Rendering is progressive and time-boxed: every frame computes as many points as fit in ~5 ms, first as big blocks,
-- then finer, so the app stays at 60 fps however deep you zoom. Equal colours are merged into long rectangles.
local png = require("png")
local app = {}

local BUDGET = 0.005                    -- seconds of computing per frame
local LEVELS = {4, 2, 1}                -- block sizes (in cells) of the progressive passes
local QUALITY = {6, 4, 3}               -- pixels per cell: fast, normal, fine
local PAL_N = 128
local HOME = {mx = -0.6, my = 0, mscale = 3.2, jx = 0, jy = 0, jscale = 3.4}

local SCHEMES = {
  {key = "sc_fire", stops = {{0, 0, 0}, {120, 20, 10}, {230, 90, 20}, {255, 200, 60}, {255, 255, 220}}},
  {key = "sc_ocean", stops = {{2, 8, 30}, {10, 60, 140}, {40, 160, 220}, {200, 240, 255}, {20, 80, 160}}},
  {key = "sc_rainbow", rainbow = true},
  {key = "sc_twilight", stops = {{20, 10, 40}, {110, 30, 120}, {240, 90, 120}, {255, 190, 120}, {60, 20, 90}}},
  {key = "sc_mono", stops = {{0, 0, 0}, {90, 90, 90}, {230, 230, 230}, {120, 120, 120}}},
}
local BOOKMARKS = {
  {key = "bm_seahorse", x = -0.7436447860, y = 0.1318252536, s = 0.0045},
  {key = "bm_elephant", x = 0.2817, y = -0.0105, s = 0.012},
  {key = "bm_spiral", x = -0.0880, y = 0.6546, s = 0.012},
  {key = "bm_mini", x = -1.7497, y = 0.0, s = 0.02},
  {key = "bm_lightning", x = -0.170337, y = -1.06506, s = 0.006},
}

-- view
local julia = false
local cx, cy, scale = HOME.mx, HOME.my, HOME.mscale   -- centre and width of the view in the complex plane
local jcx, jcy = -0.8, 0.156                          -- Julia constant
local maxIter, scheme, quality = 200, 1, 2
local userMarks = {}

-- buffer
local GW, GH, cs = 0, 0, 4
local idx = {}                -- palette index per cell (0 = inside the set)
local rowDirty, rowRuns, rowSig = {}, {}, {}
local tasks = {}              -- progressive work: regions with their pass levels
local work, total = 0, 1      -- progress counters for the bar
local pal = {}
local canvas = {x = 0, y = 0, w = 0, h = 0}

-- interaction
local drag = nil              -- {x, y, ox, oy}
local toast, toastT = "", 0
local export = nil            -- {path, enc, row}
local lastW, lastH = 0, 0

-- ------------------------------------------------------------------ colours
local function buildPalette()
  pal = {}
  local sc = SCHEMES[scheme] or SCHEMES[1]
  for i = 1, PAL_N do
    local t = (i - 1) / PAL_N
    local r, g, b
    if sc.rainbow then
      local h = t * 6
      local k = math.floor(h) % 6
      local f = h - math.floor(h)
      local q, u = 1 - f, f
      local rr = ({1, q, 0, 0, u, 1})[k + 1]
      local gg = ({u, 1, 1, q, 0, 0})[k + 1]
      local bb = ({0, 0, u, 1, 1, q})[k + 1]
      r, g, b = rr * 255, gg * 255, bb * 255
    else
      local st = sc.stops
      local n = #st
      local p = t * n
      local a = math.floor(p) % n + 1
      local c = a % n + 1
      local f = p - math.floor(p)
      f = f * f * (3 - 2 * f)
      r = st[a][1] + (st[c][1] - st[a][1]) * f
      g = st[a][2] + (st[c][2] - st[a][2]) * f
      b = st[a][3] + (st[c][3] - st[a][3]) * f
    end
    pal[i] = string.format("#%02X%02X%02X", math.floor(r), math.floor(g), math.floor(b))
  end
  pal[0] = "#000000"
end

local function rgbOf(i)
  local h = pal[i] or "#000000"
  return tonumber(h:sub(2, 3), 16), tonumber(h:sub(4, 5), 16), tonumber(h:sub(6, 7), 16)
end

-- ------------------------------------------------------------------ fractal maths
local log, floor = math.log, math.floor
local LOG2 = log(2)

-- palette index for one point (0 = inside)
local function sample(re, im)
  local zr, zi, cr, ci
  if julia then zr, zi, cr, ci = re, im, jcx, jcy
  else
    zr, zi, cr, ci = 0, 0, re, im
    -- skip the main cardioid and the period-2 bulb (most of the black area)
    local q = (re - 0.25) * (re - 0.25) + im * im
    if q * (q + (re - 0.25)) <= 0.25 * im * im then return 0 end
    if (re + 1) * (re + 1) + im * im <= 0.0625 then return 0 end
  end
  local it = maxIter
  local zr2, zi2 = zr * zr, zi * zi
  for i = 1, it do
    zi = 2 * zr * zi + ci
    zr = zr2 - zi2 + cr
    zr2, zi2 = zr * zr, zi * zi
    if zr2 + zi2 > 256 then
      local mu = i + 1 - log(log(zr2 + zi2) / 2 / LOG2) / LOG2   -- smooth iteration count
      return floor(mu * 3) % PAL_N + 1
    end
  end
  return 0
end

-- ------------------------------------------------------------------ progressive work
local function cellToComplex(x, y)
  local px = scale / (GW * cs)                                  -- complex units per pixel
  return cx + ((x + 0.5) * cs - GW * cs / 2) * px, cy - ((y + 0.5) * cs - GH * cs / 2) * px
end

local function addTask(x0, y0, x1, y1, levels)
  if x1 < x0 or y1 < y0 then return end
  tasks[#tasks + 1] = {x0 = x0, y0 = y0, x1 = x1, y1 = y1, levels = levels, li = 1, x = x0, y = y0}
  for _, lv in ipairs(levels) do total = total + ((x1 - x0) // lv + 1) * ((y1 - y0) // lv + 1) end
end

local function restart()
  tasks, work, total = {}, 0, 1
  addTask(0, 0, GW - 1, GH - 1, LEVELS)
end

local function allocate(w, h)
  cs = QUALITY[quality] or 4
  GW, GH = math.max(1, math.ceil(w / cs)), math.max(1, math.ceil(h / cs))
  idx, rowDirty, rowRuns, rowSig = {}, {}, {}, {}
  for i = 1, GW * GH do idx[i] = 0 end
  for y = 0, GH - 1 do rowDirty[y] = true end
  restart()
end

-- shift the buffer after a pan by whole cells and compute only the uncovered strips
local function shiftBy(dx, dy)
  if math.abs(dx) >= GW or math.abs(dy) >= GH then restart() return end
  local old = idx
  local new = {}
  for y = 0, GH - 1 do
    local sy = y - dy
    for x = 0, GW - 1 do
      local sx = x - dx
      if sx >= 0 and sx < GW and sy >= 0 and sy < GH then new[y * GW + x + 1] = old[sy * GW + sx + 1]
      else new[y * GW + x + 1] = 0 end
    end
    rowDirty[y] = true
  end
  idx = new
  local wasBusy = #tasks > 0
  tasks, work, total = {}, 0, 1
  if wasBusy then addTask(0, 0, GW - 1, GH - 1, LEVELS) return end
  if dx > 0 then addTask(0, 0, dx - 1, GH - 1, {2, 1}) elseif dx < 0 then addTask(GW + dx, 0, GW - 1, GH - 1, {2, 1}) end
  if dy > 0 then addTask(0, 0, GW - 1, dy - 1, {2, 1}) elseif dy < 0 then addTask(0, GH + dy, GW - 1, GH - 1, {2, 1}) end
end

local function compute()
  local t0 = os.clock()
  local n = 0
  while #tasks > 0 do
    local t = tasks[1]
    local s = t.levels[t.li]
    local prev = t.levels[t.li - 1]
    local x, y = t.x, t.y
    -- skip points that the coarser pass already sampled
    if not (prev and (x - t.x0) % prev == 0 and (y - t.y0) % prev == 0) then
      local re, im = cellToComplex(x, y)
      local v = sample(re, im)
      local ye, xe = math.min(t.y1, y + s - 1), math.min(t.x1, x + s - 1)
      for yy = y, ye do
        local base = yy * GW + 1
        for xx = x, xe do idx[base + xx] = v end
        rowDirty[yy] = true
      end
    end
    work = work + 1
    -- advance
    x = x + s
    if x > t.x1 then
      x = t.x0
      y = y + s
      if y > t.y1 then
        t.li = t.li + 1
        x, y = t.x0, t.y0
        if t.li > #t.levels then table.remove(tasks, 1) end
      end
    end
    t.x, t.y = x, y
    n = n + 1
    if n % 32 == 0 and os.clock() - t0 > BUDGET then break end
  end
end

-- runs of equal colour in one row, as a flat list x, len, colour, … plus a signature for merging rows
local function rebuildRow(y)
  local runs = {}
  local base = y * GW
  local start, cur = 0, idx[base + 1]
  for x = 1, GW do
    local v = x < GW and idx[base + x + 1] or -1
    if v ~= cur then
      runs[#runs + 1] = start
      runs[#runs + 1] = x - start
      runs[#runs + 1] = cur
      start, cur = x, v
    end
  end
  rowRuns[y] = runs
  rowSig[y] = table.concat(runs, ",")
  rowDirty[y] = false
end

-- ------------------------------------------------------------------ view helpers
local function showToast(s) toast, toastT = s, 2.2 end

local function zoomAt(px, py, f)
  -- keep the point under the pointer fixed while zooming
  local upp = scale / (GW * cs)
  local re = cx + (px - canvas.x - GW * cs / 2) * upp
  local im = cy - (py - canvas.y - GH * cs / 2) * upp
  scale = math.max(1e-13, math.min(8, scale / f))
  local upp2 = scale / (GW * cs)
  cx = re - (px - canvas.x - GW * cs / 2) * upp2
  cy = im + (py - canvas.y - GH * cs / 2) * upp2
  restart()
end

local function saveView()
  store.set("view", {julia = julia, cx = cx, cy = cy, scale = scale, jx = jcx, jy = jcy})
end

local function resetView()
  if julia then cx, cy, scale = HOME.jx, HOME.jy, HOME.jscale else cx, cy, scale = HOME.mx, HOME.my, HOME.mscale end
  restart()
  saveView()
end

local function setJulia(on)
  if on == julia then return end
  if on then
    jcx, jcy = cx, cy                  -- the Julia constant is the centre of the Mandelbrot view
    julia = true
    cx, cy, scale = HOME.jx, HOME.jy, HOME.jscale
  else
    julia = false
    cx, cy, scale = jcx, jcy, 0.5
  end
  restart()
  saveView()
end

local function goBookmark(b)
  if julia then julia = false end
  cx, cy, scale = b.x, b.y, b.s
  restart()
  saveView()
end

local function zoomLabel()
  local z = (julia and HOME.jscale or HOME.mscale) / scale
  if z >= 1e6 then return string.format("%.2e×", z) end
  if z >= 100 then return string.format("%.0f×", z) end
  return string.format("%.1f×", z)
end

-- ------------------------------------------------------------------ export (PNG, spread over frames)
local function startExport(path)
  if not path or path == "" then return end
  export = {path = path, enc = png.new(GW * cs, GH * cs, false), row = 0, px = {}}
  for i = 0, PAL_N do
    local r, g, b = rgbOf(i)
    export.px[i] = string.rep(string.char(r, g, b), cs)    -- one cell = cs pixels, like on screen
  end
end

local function stepExport()
  local e = export
  local t0 = os.clock()
  while e.row < GH and os.clock() - t0 < 0.006 do
    local parts = {}
    local base = e.row * GW
    for x = 1, GW do parts[x] = e.px[idx[base + x]] or e.px[0] end
    local line = table.concat(parts)
    for _ = 1, cs do e.enc:row(line) end
    e.row = e.row + 1
  end
  if e.row >= GH then
    local ok = fs.write(e.path, e.enc:finish())
    export = nil
    showToast(ok and TR("exported") or TR("export_failed"))
    audio.play(ok and "shutter" or "error")
  end
end

-- ------------------------------------------------------------------ callbacks
function app.load()
  local v = store.get("view", nil)
  if type(v) == "table" and tonumber(v.scale) then
    julia = v.julia == true
    cx, cy, scale = tonumber(v.cx) or cx, tonumber(v.cy) or cy, math.max(1e-13, tonumber(v.scale))
    jcx, jcy = tonumber(v.jx) or jcx, tonumber(v.jy) or jcy
  end
  maxIter = math.max(50, math.min(2000, store.get("iter", 200)))
  scheme = math.max(1, math.min(#SCHEMES, store.get("scheme", 1)))
  quality = math.max(1, math.min(3, store.get("quality", 2)))
  local m = store.get("marks", {})
  userMarks = type(m) == "table" and m or {}
  buildPalette()
end

function app.update(dt)
  if toastT > 0 then toastT = toastT - dt end
  if export then stepExport() elseif GW > 0 and not drag then compute() end
end

local function drawBuffer()
  local ox, oy = canvas.x, canvas.y
  if drag then ox, oy = ox + drag.ox, oy + drag.oy end
  local y = 0
  while y < GH do
    if rowDirty[y] then rebuildRow(y) end
    local y2 = y + 1
    while y2 < GH do
      if rowDirty[y2] then rebuildRow(y2) end
      if rowSig[y2] ~= rowSig[y] then break end
      y2 = y2 + 1
    end
    local runs = rowRuns[y]
    local hh = (y2 - y) * cs
    for i = 1, #runs, 3 do
      gfx.rect(ox + runs[i] * cs, oy + y * cs, runs[i + 1] * cs, hh, 0, pal[runs[i + 2]] or "#000000")
    end
    y = y2
  end
end

function app.draw(w, h)
  gfx.clear("#000000")
  local top, bottom = 50, 30
  local ch = math.max(40, h - top - bottom)
  canvas.x, canvas.y, canvas.w, canvas.h = 0, top, w, ch
  if w ~= lastW or ch ~= lastH or cs ~= (QUALITY[quality] or 4) then
    lastW, lastH = w, ch
    allocate(w, ch)
  end
  gfx.clip(0, top, w, ch)
  drawBuffer()
  if not julia then   -- crosshair: the centre becomes the Julia constant
    gfx.color("#FFFFFF66")
    local mx, my = w / 2, top + ch / 2
    gfx.line(mx - 8, my, mx + 8, my, 1)
    gfx.line(mx, my - 8, mx, my + 8, 1)
  end
  gfx.unclip()

  -- toolbar
  gfx.rect(0, 0, w, top, 0, theme.window)
  ui.separator(0, top - 0.5, w)
  local mode = ui.segmented("mode", {"Mandelbrot", "Julia"}, julia and 2 or 1, 12, 9, 190, 32)
  if (mode == 2) ~= julia then setJulia(mode == 2) end
  local names = {}
  for i, s in ipairs(SCHEMES) do names[i] = TR(s.key) end
  local ns = ui.dropdown("scheme", names, scheme, 212, 9, 120, 32)
  if ns ~= scheme then scheme = ns; store.set("scheme", ns); buildPalette() end
  gfx.color(theme.text2)
  gfx.text(TR("iter", maxIter), 344, 17, 12)
  local sw = math.max(60, math.min(180, w - 344 - 70 - 210))
  local it = ui.slider("iter", maxIter, 50, 2000, 344 + 86, 15, sw, 50)
  if it ~= maxIter then maxIter = it; store.set("iter", it); restart() end
  local bx = w - 12 - 4 * 38
  if ui.iconButton("zoom_out", bx, 9, 34, 32, nil, false, "zo") then zoomAt(w / 2, top + ch / 2, 0.5) end
  if ui.iconButton("zoom_in", bx + 38, 9, 34, 32, nil, false, "zi") then zoomAt(w / 2, top + ch / 2, 2) end
  if ui.iconButton("home", bx + 76, 9, 34, 32, nil, false, "hm") then resetView() end
  if ui.iconButton("image", bx + 114, 9, 34, 32, nil, export ~= nil, "ex") and not export then
    ui.saveFile(function(p) startExport(p) end, "fractal.png", TR("export"))
  end

  -- status bar
  local sy = h - bottom
  gfx.rect(0, sy, w, bottom, 0, theme.window)
  gfx.color(theme.text2)
  local coord = string.format("%.10f %s %.10fi", cx, cy < 0 and "−" or "+", math.abs(cy))
  if julia then coord = "c = " .. string.format("%.5f %s %.5fi", jcx, jcy < 0 and "−" or "+", math.abs(jcy)) end
  gfx.text(coord, 12, sy + 8, 12, "mono")
  gfx.text(TR("zoom", zoomLabel()), 0, sy + 8, 12, "semibold", "right", w - 130)
  if export then
    ui.progress(export.row / math.max(1, GH), w - 118, sy + 12, 106, 6)
  elseif #tasks > 0 then
    ui.progress(math.min(1, work / total), w - 118, sy + 12, 106, 6)
  else
    gfx.icon("check_circle", w - 24, sy + 15, 16, theme.green)
  end

  if toastT > 0 then
    local tw = gfx.textWidth(toast, 13) + 32
    gfx.alpha(math.min(1, toastT * 3))
    gfx.rect(w / 2 - tw / 2, sy - 46, tw, 32, 16, "#1C1C1EE6")
    gfx.color("#FFFFFF")
    gfx.text(toast, w / 2 - tw / 2, sy - 38, 13, "semibold", "center", tw)
    gfx.unalpha()
  end
end

local function inCanvas(x, y) return y >= canvas.y and y < canvas.y + canvas.h end

local function commitDrag()
  if not drag then return end
  local dx, dy = math.floor(drag.ox / cs + 0.5), math.floor(drag.oy / cs + 0.5)
  drag = nil
  if dx == 0 and dy == 0 then return end
  local upp = scale / (GW * cs)
  cx = cx - dx * cs * upp
  cy = cy + dy * cs * upp
  shiftBy(dx, dy)
  saveView()
end

local function pan(dx, dy)   -- in cells
  local upp = scale / (GW * cs)
  cx = cx - dx * cs * upp
  cy = cy + dy * cs * upp
  shiftBy(dx, dy)
  saveView()
end

function app.event(e)
  local t = e.type
  if t == "mousedown" and e.button == "left" and inCanvas(e.x, e.y) then
    if (e.clicks or 1) >= 2 then
      drag = nil
      zoomAt(e.x, e.y, 2)
      saveView()
    else
      drag = {x = e.x, y = e.y, ox = 0, oy = 0}
    end
  elseif t == "mousemove" and drag then
    drag.ox, drag.oy = e.x - drag.x, e.y - drag.y
  elseif t == "mouseup" then
    if drag and not e.cancel then commitDrag() else drag = nil end
  elseif t == "scroll" and inCanvas(e.x, e.y) and not e.touch then
    if (e.dy or 0) ~= 0 then zoomAt(e.x, e.y, e.dy > 0 and 1.25 or 0.8); saveView() end
  elseif t == "pinch" and (e.scale or 1) ~= 1 then
    drag = nil
    zoomAt(e.x, e.y, e.scale)
    saveView()
  elseif t == "keydown" then
    local k = e.key
    local step = math.max(1, GW // 8)
    if k == "left" then pan(step, 0) elseif k == "right" then pan(-step, 0)
    elseif k == "up" then pan(0, step) elseif k == "down" then pan(0, -step)
    elseif k == "z" or k == "pageup" then zoomAt(canvas.x + canvas.w / 2, canvas.y + canvas.h / 2, 2); saveView()
    elseif k == "x" or k == "pagedown" then zoomAt(canvas.x + canvas.w / 2, canvas.y + canvas.h / 2, 0.5); saveView()
    elseif k == "r" or k == "home" then resetView()
    elseif k == "j" then setJulia(not julia)
    elseif k == "c" then scheme = scheme % #SCHEMES + 1; store.set("scheme", scheme); buildPalette() end
  end
end

function app.menu()
  local marks = {}
  for i, b in ipairs(BOOKMARKS) do marks[#marks + 1] = {label = TR(b.key), id = 100 + i} end
  if #userMarks > 0 then marks[#marks + 1] = "-" end
  for i, b in ipairs(userMarks) do
    marks[#marks + 1] = {label = TR("my_place", i) .. "  (" .. string.format("%.3g", tonumber(b.s) or 1) .. ")", id = 200 + i}
  end
  marks[#marks + 1] = "-"
  marks[#marks + 1] = {label = TR("add_bookmark"), id = 2, enabled = not julia}
  marks[#marks + 1] = {label = TR("clear_bookmarks"), id = 3, enabled = #userMarks > 0}
  return {
    {title = TR("app_name"), items = {
      {label = TR("reset"), id = 1, shortcut = "R"},
      {label = TR("toggle_julia"), id = 4, shortcut = "J"},
      {label = TR("export"), id = 5},
      {label = TR("copy_coords"), id = 6},
      "-",
      {label = TR("q_fast"), id = 11}, {label = TR("q_normal"), id = 12}, {label = TR("q_fine"), id = 13},
    }},
    {title = TR("bookmarks"), items = marks},
  }
end

function app.onmenu(id)
  if id == 1 then resetView()
  elseif id == 2 and not julia then
    userMarks[#userMarks + 1] = {x = cx, y = cy, s = scale}
    while #userMarks > 12 do table.remove(userMarks, 1) end
    store.set("marks", userMarks)
    showToast(TR("bookmarked"))
  elseif id == 3 then
    ui.alert(TR("clear_bookmarks"), TR("clear_msg"), {TR("clear"), TR("common.cancel")}, function(b)
      if b == 1 then userMarks = {}; store.set("marks", userMarks) end
    end)
  elseif id == 4 then setJulia(not julia)
  elseif id == 5 and not export then ui.saveFile(function(p) startExport(p) end, "fractal.png", TR("export"))
  elseif id == 6 then
    local s = julia and string.format("Julia c = %.12f %+.12fi", jcx, jcy)
      or string.format("Mandelbrot %.14f %+.14fi, %s", cx, cy, zoomLabel())
    sys.clipboard(s)
    showToast(TR("copied"))
  elseif id >= 11 and id <= 13 then quality = id - 10; store.set("quality", quality); lastW = 0
  elseif id > 100 and id < 200 and BOOKMARKS[id - 100] then goBookmark(BOOKMARKS[id - 100])
  elseif id > 200 and userMarks[id - 200] then
    local b = userMarks[id - 200]
    goBookmark({x = tonumber(b.x) or 0, y = tonumber(b.y) or 0, s = tonumber(b.s) or 1})
  end
end

function app.close()
  saveView()
  store.save()
  return true
end

return app
