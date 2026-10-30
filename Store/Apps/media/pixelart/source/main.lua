-- Pixel Art: draw 8×8, 16×16 or 32×32 sprites with pencil, eraser, fill, line, rectangle and eyedropper tools,
-- a PICO-8 style palette plus your own colours, mirror drawing, undo/redo, a gallery and real PNG export.
local png = require("png")
local app = {}

local PALETTE = {"#000000", "#1D2B53", "#7E2553", "#008751", "#AB5236", "#5F574F", "#C2C3C7", "#FFF1E8",
  "#FF004D", "#FFA300", "#FFEC27", "#00E436", "#29ADFF", "#83769C", "#FF77A8", "#FFCCAA"}
local TOOLS = {
  {id = "pencil", icon = "edit", key = "t_pencil", hot = "p"},
  {id = "eraser", icon = "auto_fix_normal", key = "t_eraser", hot = "e"},
  {id = "fill", icon = "format_color_fill", key = "t_fill", hot = "f"},
  {id = "line", icon = "horizontal_rule", key = "t_line", hot = "l"},
  {id = "rect", icon = "check_box_outline_blank", key = "t_rect", hot = "r"},
  {id = "picker", icon = "colorize", key = "t_picker", hot = "i"},
}
local SIZES = {8, 16, 32}

local N = 16
local px = {}                 -- N*N colours ("" = transparent)
local tool = "pencil"
local color = "#FF004D"
local custom = {}             -- user colours (max 8)
local grid, mirror = true, false
local undo, redo = {}, {}
local gallery = {}            -- {name, n, px}
local screen = "edit"         -- "edit", "gallery", "color"
local stroke = nil            -- {x0, y0, x1, y1} while dragging
local canvas = {x = 0, y = 0, cs = 10}
local runs, runsDirty = {}, true
local toast, toastT = "", 0
local hsv = {h = 0, s = 1, v = 1}
local exportScale = 16
local pendingDelete = nil

-- ------------------------------------------------------------------ helpers
local function showToast(s) toast, toastT = s, 2.4 end

local function blank(n)
  local t = {}
  for i = 1, n * n do t[i] = "" end
  return t
end

local function copy(t)
  local c = {}
  for i = 1, #t do c[i] = t[i] end
  return c
end

local function saveCurrent()
  store.set("current", {n = N, px = px})
  runsDirty = true
end

local function pushUndo()
  undo[#undo + 1] = {n = N, px = copy(px)}
  if #undo > 60 then table.remove(undo, 1) end
  redo = {}
end

local function restoreState(s)
  N, px = s.n, s.px
  saveCurrent()
end

local function doUndo()
  if #undo == 0 then return end
  redo[#redo + 1] = {n = N, px = copy(px)}
  restoreState(table.remove(undo))
end

local function doRedo()
  if #redo == 0 then return end
  undo[#undo + 1] = {n = N, px = copy(px)}
  restoreState(table.remove(redo))
end

local function get(x, y) if x < 0 or y < 0 or x >= N or y >= N then return nil end return px[y * N + x + 1] end
local function set(x, y, c)
  if x < 0 or y < 0 or x >= N or y >= N then return end
  px[y * N + x + 1] = c
  if mirror then px[y * N + (N - 1 - x) + 1] = c end
  runsDirty = true
end

local function floodFill(x, y, c)
  local target = get(x, y)
  if target == nil or target == c then return end
  local stack = {x, y}
  while #stack > 0 do
    local yy = table.remove(stack)
    local xx = table.remove(stack)
    if get(xx, yy) == target then
      px[yy * N + xx + 1] = c
      stack[#stack + 1] = xx + 1; stack[#stack + 1] = yy
      stack[#stack + 1] = xx - 1; stack[#stack + 1] = yy
      stack[#stack + 1] = xx; stack[#stack + 1] = yy + 1
      stack[#stack + 1] = xx; stack[#stack + 1] = yy - 1
    end
  end
  runsDirty = true
end

local function linePts(x0, y0, x1, y1, fn)
  local dx, dy = math.abs(x1 - x0), -math.abs(y1 - y0)
  local sx, sy = x0 < x1 and 1 or -1, y0 < y1 and 1 or -1
  local err = dx + dy
  for _ = 1, 200 do
    fn(x0, y0)
    if x0 == x1 and y0 == y1 then break end
    local e2 = 2 * err
    if e2 >= dy then err = err + dy; x0 = x0 + sx end
    if e2 <= dx then err = err + dx; y0 = y0 + sy end
  end
end

local function rectPts(x0, y0, x1, y1, fn)
  local ax, bx = math.min(x0, x1), math.max(x0, x1)
  local ay, by = math.min(y0, y1), math.max(y0, y1)
  for x = ax, bx do fn(x, ay); fn(x, by) end
  for y = ay + 1, by - 1 do fn(ax, y); fn(bx, y) end
end

local function newCanvas(n)
  pushUndo()
  N = n
  px = blank(n)
  saveCurrent()
end

local function hexToRgb(h)
  return tonumber(h:sub(2, 3), 16) or 0, tonumber(h:sub(4, 5), 16) or 0, tonumber(h:sub(6, 7), 16) or 0
end

local function hsvToHex(h, s, v)
  local i = math.floor(h * 6) % 6
  local f = h * 6 - math.floor(h * 6)
  local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
  local r, g, b
  if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
  return string.format("#%02X%02X%02X", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

-- ------------------------------------------------------------------ PNG export
local function encodePNG(data, n, scale)
  local enc = png.new(n * scale, n * scale, true)
  local cache = {}
  for y = 0, n - 1 do
    local parts = {}
    for x = 0, n - 1 do
      local c = data[y * n + x + 1] or ""
      local s = cache[c]
      if not s then
        if c == "" then s = string.rep("\0\0\0\0", scale)
        else local r, g, b = hexToRgb(c); s = string.rep(string.char(r, g, b, 255), scale) end
        cache[c] = s
      end
      parts[#parts + 1] = s
    end
    local row = table.concat(parts)
    for _ = 1, scale do enc:row(row) end
  end
  return enc:finish()
end

local function exportPNG()
  local data, n, scale = copy(px), N, exportScale
  ui.saveFile(function(path)
    if not path or path == "" then return end
    if not path:lower():match("%.png$") then path = path .. ".png" end
    local ok = fs.write(path, encodePNG(data, n, scale))
    showToast(ok and TR("exported", n * scale, n * scale) or TR("export_failed"))
    if ok then audio.play("shutter") end
  end, "pixel-art.png", TR("export"))
end

-- ------------------------------------------------------------------ gallery
local function saveToGallery(name)
  gallery[#gallery + 1] = {name = name, n = N, px = copy(px)}
  store.set("gallery", gallery)
  showToast(TR("saved_as", name))
  audio.play("pop")
end

-- ------------------------------------------------------------------ callbacks
function app.load()
  local c = store.get("current", nil)
  if type(c) == "table" and type(c.px) == "table" and (c.n == 8 or c.n == 16 or c.n == 32) and #c.px == c.n * c.n then
    N, px = c.n, c.px
  else
    N, px = 16, blank(16)
    -- first run: a small heart so the canvas is not empty
    local heart = {"..XX..XX..", ".XXXXXXXX.", "XXXXXXXXXX", "XXXXXXXXXX", ".XXXXXXXX.", "..XXXXXX..", "...XXXX...", "....XX...."}
    for r, row in ipairs(heart) do
      for k = 1, #row do if row:sub(k, k) == "X" then px[(r + 3) * 16 + k + 2] = "#FF004D" end end
    end
  end
  local g = store.get("gallery", {})
  gallery = type(g) == "table" and g or {}
  local cu = store.get("custom", {})
  custom = type(cu) == "table" and cu or {}
  color = store.get("color", "#FF004D")
  grid = store.get("grid", true) ~= false
  exportScale = store.get("scale", 16)
end

function app.update(dt)
  if toastT > 0 then toastT = toastT - dt end
end

local function cellAt(x, y)
  local cs = canvas.cs
  local cx, cy = math.floor((x - canvas.x) / cs), math.floor((y - canvas.y) / cs)
  if cx < 0 or cy < 0 or cx >= N or cy >= N then return nil end
  return cx, cy
end

local function rebuildRuns()
  runs = {}
  for y = 0, N - 1 do
    local start, cur = 0, px[y * N + 1]
    for x = 1, N do
      local v = x < N and px[y * N + x + 1] or false
      if v ~= cur then
        if cur ~= "" then runs[#runs + 1] = {start, y, x - start, cur} end
        start, cur = x, v
      end
    end
  end
  runsDirty = false
end

local function drawCanvas(x, y, size)
  local cs = math.floor(size / N)
  local s = cs * N
  canvas.x, canvas.y, canvas.cs = x, y, cs
  gfx.shadow(x, y, s, s, 6, 12, 3)
  -- checkerboard for transparency (2×2 cells per square)
  gfx.rect(x, y, s, s, 0, theme.dark and "#3A3A3C" or "#FFFFFF")
  gfx.color(theme.dark and "#2C2C2E" or "#E5E5EA")
  local q = cs * (N >= 32 and 2 or 1)
  for yy = 0, s - 1, q * 2 do
    for xx = 0, s - 1, q * 2 do
      gfx.rect(x + xx + q, y + yy, math.min(q, s - xx - q), math.min(q, s - yy))
      gfx.rect(x + xx, y + yy + q, math.min(q, s - xx), math.min(q, s - yy - q))
    end
  end
  if runsDirty then rebuildRuns() end
  for _, r in ipairs(runs) do gfx.rect(x + r[1] * cs, y + r[2] * cs, r[3] * cs, cs, 0, r[4]) end
  -- shape preview
  if stroke and (tool == "line" or tool == "rect") then
    gfx.alpha(0.8)
    gfx.color(tool == "eraser" and "#FFFFFF" or color)
    local f = function(px_, py_)
      if px_ >= 0 and py_ >= 0 and px_ < N and py_ < N then
        gfx.rect(x + px_ * cs, y + py_ * cs, cs, cs)
        if mirror then gfx.rect(x + (N - 1 - px_) * cs, y + py_ * cs, cs, cs) end
      end
    end
    if tool == "line" then linePts(stroke.x0, stroke.y0, stroke.x1, stroke.y1, f) else rectPts(stroke.x0, stroke.y0, stroke.x1, stroke.y1, f) end
    gfx.unalpha()
  end
  if grid and cs >= 6 then
    gfx.color(theme.dark and "#FFFFFF18" or "#00000018")
    for i = 1, N - 1 do
      gfx.line(x + i * cs, y, x + i * cs, y + s, 1)
      gfx.line(x, y + i * cs, x + s, y + i * cs, 1)
    end
  end
  if mirror then
    gfx.color(theme.accent .. "88")
    gfx.line(x + s / 2, y - 6, x + s / 2, y + s + 6, 2)
  end
  gfx.color(theme.separator)
  gfx.rectLine(x - 1, y - 1, s + 2, s + 2, 2, 1)
end

local function swatch(id, c, x, y, sz, selected)
  local hit = ui.hit(id, x, y, sz, sz)
  gfx.rect(x, y, sz, sz, 6, c)
  gfx.color(theme.separator)
  gfx.rectLine(x, y, sz, sz, 6, 1)
  if selected then
    gfx.color(theme.text)
    gfx.rectLine(x - 3, y - 3, sz + 6, sz + 6, 8, 2)
  end
  return hit.clicked
end

local function drawEditor(w, h)
  -- top bar
  local ns = ui.segmented("size", {"8×8", "16×16", "32×32"}, N == 8 and 1 or N == 16 and 2 or 3, 16, 12, 210, 32)
  if SIZES[ns] ~= N then
    local n = SIZES[ns]
    ui.alert(TR("new_size"), TR("new_size_msg", n), {TR("create"), TR("common.cancel")}, function(b) if b == 1 then newCanvas(n) end end)
  end
  local bx = 238
  if ui.iconButton("undo", bx, 12, 34, 32, nil, false, "u") and #undo > 0 then doUndo() end
  if ui.iconButton("redo", bx + 38, 12, 34, 32, nil, false, "r") and #redo > 0 then doRedo() end
  if ui.iconButton(grid and "grid_on" or "grid_off", bx + 84, 12, 34, 32, nil, grid, "g") then grid = not grid; store.set("grid", grid) end
  if ui.iconButton("flip", bx + 122, 12, 34, 32, nil, mirror, "m") then mirror = not mirror end
  if ui.button(TR("gallery"), w - 300, 12, 136, 32, "default", "photo_library") then screen = "gallery" end
  if ui.button(TR("export_short"), w - 156, 12, 140, 32, "primary", "ios_share") then exportPNG() end

  -- tools column
  local ty = 60
  for i, t in ipairs(TOOLS) do
    if ui.iconButton(t.icon, 16, ty + (i - 1) * 44, 40, 40, nil, tool == t.id, "tool" .. i) then tool = t.id end
  end
  gfx.color(theme.text3)
  local tname = ""
  for _, t in ipairs(TOOLS) do if t.id == tool then tname = TR(t.key) end end
  gfx.wrap(tname, 8, ty + #TOOLS * 44 + 4, 56, 11, "semibold", "center")

  -- palette column
  local pw = 176
  local pxp = w - pw - 16
  gfx.color(theme.text2)
  gfx.text(TR("colors"), pxp, 60, 13, "semibold")
  local sz = 36
  for i, c in ipairs(PALETTE) do
    local cx, cy = pxp + ((i - 1) % 4) * (sz + 10), 82 + ((i - 1) // 4) * (sz + 10)
    if swatch("pal" .. i, c, cx, cy, sz, c == color) then color = c; store.set("color", c); if tool == "eraser" then tool = "pencil" end end
  end
  local cy = 82 + 4 * (sz + 10) + 6
  gfx.color(theme.text2)
  gfx.text(TR("my_colors"), pxp, cy, 13, "semibold")
  cy = cy + 22
  for i = 1, 8 do
    local c = custom[i]
    local cx, yy = pxp + ((i - 1) % 4) * (sz + 10), cy + ((i - 1) // 4) * (sz + 10)
    if c then
      if swatch("cu" .. i, c, cx, yy, sz, c == color) then color = c; store.set("color", c) end
    else
      gfx.color(theme.separator)
      gfx.rectLine(cx, yy, sz, sz, 6, 1)
    end
  end
  cy = cy + 2 * (sz + 10)
  if ui.button(TR("new_color"), pxp, cy, pw - 8, 32, "default", "palette") then
    local r, g, b = hexToRgb(color)
    local mx, mn = math.max(r, g, b) / 255, math.min(r, g, b) / 255
    hsv.v = mx
    hsv.s = mx > 0 and (mx - mn) / mx or 0
    screen = "color"
  end
  -- current colour
  gfx.color(theme.text3)
  gfx.text(color, pxp, cy + 42, 12, "mono")

  -- canvas
  local left, right = 76, pxp - 20
  local size = math.min(right - left, h - 76)
  drawCanvas(left + (right - left - size) / 2, 60 + (h - 76 - size) / 2, size)
end

local function drawColorPicker(w, h)
  gfx.color(theme.text)
  gfx.text(TR("new_color"), 0, 20, 20, "bold", "center", w)
  local pw = math.min(420, w - 40)
  local x = (w - pw) / 2
  local c = hsvToHex(hsv.h, hsv.s, hsv.v)
  gfx.shadow(x, 60, pw, 90, 14, 10, 3)
  gfx.rect(x, 60, pw, 90, 14, c)
  gfx.color(hsv.v > 0.6 and "#000000" or "#FFFFFF")
  gfx.text(c, x, 92, 20, "monobold", "center", pw)
  local y = 170
  -- hue strip
  for i = 0, 35 do gfx.rect(x + i * pw / 36, y, pw / 36 + 1, 14, 0, hsvToHex(i / 36, 1, 1)) end
  hsv.h = ui.slider("h", hsv.h, 0, 0.999, x, y + 20, pw, 0.005)
  gfx.color(theme.text2)
  gfx.text(TR("saturation"), x, y + 60, 13)
  hsv.s = ui.slider("s", hsv.s, 0, 1, x, y + 80, pw, 0.01)
  gfx.text(TR("brightness"), x, y + 120, 13)
  hsv.v = ui.slider("v", hsv.v, 0, 1, x, y + 140, pw, 0.01)
  local by = y + 190
  if ui.button(TR("add_color"), x, by, pw / 2 - 6, 36, "primary", "add") then
    table.insert(custom, 1, c)
    while #custom > 8 do table.remove(custom) end
    store.set("custom", custom)
    color = c
    store.set("color", c)
    screen = "edit"
  end
  if ui.button(TR("common.cancel") .. "##cc", x + pw / 2 + 6, by, pw / 2 - 6, 36) then screen = "edit" end
end

local thumbRuns = setmetatable({}, {__mode = "k"})
local function drawThumb(d, x, y, size)
  gfx.rect(x, y, size, size, 8, theme.dark and "#3A3A3C" or "#FFFFFF")
  local n = tonumber(d.n) or 16
  local cs = size / n
  local list = thumbRuns[d]
  if not list then
    list = {}
    for yy = 0, n - 1 do
      local start, cur = 0, d.px[yy * n + 1]
      for xx = 1, n do
        local v = xx < n and d.px[yy * n + xx + 1] or false
        if v ~= cur then
          if cur and cur ~= "" then list[#list + 1] = {start, yy, xx - start, cur} end
          start, cur = xx, v
        end
      end
    end
    thumbRuns[d] = list
  end
  for _, r in ipairs(list) do gfx.rect(x + r[1] * cs, y + r[2] * cs, r[3] * cs, cs, 0, r[4]) end
end

local function drawGallery(w, h)
  if ui.button(TR("back"), 16, 12, 100, 32, "plain", "arrow_back") then screen = "edit"; return end
  gfx.color(theme.text)
  gfx.text(TR("gallery"), 0, 16, 20, "bold", "center", w)
  if ui.button(TR("save_current"), w - 196, 12, 180, 32, "primary", "save") then
    ui.prompt(TR("save_current"), TR("name_msg"), TR("drawing_n", #gallery + 1), function(s)
      s = s and s:gsub("^%s+", ""):gsub("%s+$", "") or ""
      if s ~= "" then saveToGallery(s:sub(1, 30)) end
    end)
  end
  if pendingDelete then
    if ui.button(TR("undo"), w - 330, 12, 120, 32, "default", "undo") then
      table.insert(gallery, math.min(pendingDelete[1], #gallery + 1), pendingDelete[2])
      store.set("gallery", gallery)
      pendingDelete = nil
    end
  end
  if #gallery == 0 then
    gfx.icon("photo_library", w / 2, h / 2 - 30, 56, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("gallery_empty"), 0, h / 2 + 10, 15, "sans", "center", w)
    return
  end
  local size = 128
  local cols = math.max(1, (w - 32 + 16) // (size + 16))
  local x0 = (w - (cols * (size + 16) - 16)) / 2
  local rows = math.ceil(#gallery / cols)
  local action = nil
  ui.beginScroll("gal", 0, 56, w, h - 56, rows * (size + 70) + 16)
  for i, d in ipairs(gallery) do
    local k = i - 1
    local x, y = x0 + (k % cols) * (size + 16), 8 + (k // cols) * (size + 70)
    if type(d.px) == "table" then
      local hit = ui.hit("gi" .. i, x, y, size, size)
      gfx.shadow(x, y, size, size, 8, 8, 2)
      drawThumb(d, x, y, size)
      if hit.hovered then gfx.color(theme.accent); gfx.rectLine(x, y, size, size, 8, 2) end
      if hit.clicked then action = {"open", i} end
      gfx.color(theme.text)
      gfx.text(tostring(d.name or "?"), x, y + size + 6, 13, "semibold", "center", size)
      if ui.button(TR("open") .. "##o" .. i, x, y + size + 28, size - 38, 30) then action = {"open", i} end
      if ui.iconButton("delete", x + size - 34, y + size + 28, 34, 30, theme.red, false, "gd" .. i) then action = {"del", i} end
    end
  end
  ui.endScroll()
  if action and action[1] == "open" and gallery[action[2]] then
    local d = gallery[action[2]]
    pushUndo()
    N, px = tonumber(d.n) or 16, copy(d.px)
    saveCurrent()
    screen = "edit"
  elseif action and action[1] == "del" and gallery[action[2]] then
    pendingDelete = {action[2], table.remove(gallery, action[2])}
    store.set("gallery", gallery)
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  if screen == "gallery" then drawGallery(w, h)
  elseif screen == "color" then drawColorPicker(w, h)
  else drawEditor(w, h) end
  if toastT > 0 then
    local tw = gfx.textWidth(toast, 13) + 32
    gfx.alpha(math.min(1, toastT * 3))
    gfx.rect(w / 2 - tw / 2, h - 52, tw, 32, 16, "#1C1C1EE6")
    gfx.color("#FFFFFF")
    gfx.text(toast, w / 2 - tw / 2, h - 44, 13, "semibold", "center", tw)
    gfx.unalpha()
  end
end

-- ------------------------------------------------------------------ input on the canvas
local function apply(cx, cy)
  if tool == "pencil" then set(cx, cy, color)
  elseif tool == "eraser" then set(cx, cy, "")
  elseif tool == "fill" then floodFill(cx, cy, color)
  elseif tool == "picker" then
    local c = get(cx, cy)
    if c and c ~= "" then color = c; store.set("color", c); tool = "pencil" end
  end
end

function app.event(e)
  if screen ~= "edit" then
    if e.type == "keydown" and e.key == "escape" then screen = "edit" end
    return
  end
  if e.type == "mousedown" and e.button == "left" then
    local cx, cy = cellAt(e.x, e.y)
    if not cx then return end
    if tool ~= "picker" then pushUndo() end
    stroke = {x0 = cx, y0 = cy, x1 = cx, y1 = cy}
    if tool ~= "line" and tool ~= "rect" then apply(cx, cy) end
  elseif e.type == "mousemove" and stroke then
    local cx, cy = cellAt(e.x, e.y)
    if not cx then return end
    if tool == "pencil" or tool == "eraser" then
      local c = tool == "pencil" and color or ""
      linePts(stroke.x1, stroke.y1, cx, cy, function(a, b) set(a, b, c) end)
    end
    stroke.x1, stroke.y1 = cx, cy
  elseif e.type == "mouseup" and stroke then
    if tool == "line" then linePts(stroke.x0, stroke.y0, stroke.x1, stroke.y1, function(a, b) set(a, b, color) end)
    elseif tool == "rect" then rectPts(stroke.x0, stroke.y0, stroke.x1, stroke.y1, function(a, b) set(a, b, color) end) end
    stroke = nil
    if tool ~= "picker" then saveCurrent() end
  elseif e.type == "keydown" then
    local k = e.key
    if e.ctrl and k == "z" then doUndo()
    elseif e.ctrl and k == "y" then doRedo()
    elseif k == "g" then grid = not grid; store.set("grid", grid)
    elseif k == "m" then mirror = not mirror
    else
      for _, t in ipairs(TOOLS) do if k == t.hot then tool = t.id end end
    end
  end
end

function app.menu()
  return {
    {title = TR("app_name"), items = {
      {label = TR("new_drawing"), id = 1},
      {label = TR("save_current"), id = 2},
      {label = TR("gallery"), id = 3},
      "-",
      {label = TR("export"), id = 4},
      {label = TR("scale_n", 1), id = 11}, {label = TR("scale_n", 8), id = 18}, {label = TR("scale_n", 16), id = 26},
    }},
    {title = TR("edit"), items = {
      {label = TR("undo"), id = 5, shortcut = "Ctrl+Z"},
      {label = TR("redo"), id = 6, shortcut = "Ctrl+Y"},
      "-",
      {label = TR("grid"), id = 7, shortcut = "G"},
      {label = TR("mirror"), id = 8, shortcut = "M"},
      {label = TR("flip_h"), id = 9},
      {label = TR("clear"), id = 10},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then newCanvas(N)
  elseif id == 2 then saveToGallery(TR("drawing_n", #gallery + 1))
  elseif id == 3 then screen = "gallery"
  elseif id == 4 then exportPNG()
  elseif id == 11 or id == 18 or id == 26 then
    exportScale = id == 11 and 1 or id == 18 and 8 or 16
    store.set("scale", exportScale)
    showToast(TR("scale_set", N * exportScale))
  elseif id == 5 then doUndo()
  elseif id == 6 then doRedo()
  elseif id == 7 then grid = not grid; store.set("grid", grid)
  elseif id == 8 then mirror = not mirror
  elseif id == 9 then
    pushUndo()
    local f = {}
    for y = 0, N - 1 do for x = 0, N - 1 do f[y * N + x + 1] = px[y * N + (N - 1 - x) + 1] end end
    px = f
    saveCurrent()
  elseif id == 10 then pushUndo(); px = blank(N); saveCurrent()
  end
end

function app.close()
  saveCurrent()
  store.save()
  return true
end

return app
