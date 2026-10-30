-- Spirograph: draw hypotrochoids and epitrochoids like the classic toy. Every layer has its own gear sizes, pen
-- offset, colour and line width; the pen traces the curve live with the rolling gear shown. Designs go to a gallery.
local app = {}

local COLORS = {"#FF375F", "#FF9F0A", "#FFD60A", "#30D158", "#64D2FF", "#0A84FF", "#5E5CE6", "#BF5AF2", "#FFFFFF", "#8E8E93"}
local PRESETS = {
  {key = "pre_flower", layers = {{epi = false, R = 120, r = 45, d = 70, c = 1, w = 2}, {epi = false, R = 120, r = 75, d = 40, c = 3, w = 2}}},
  {key = "pre_star", layers = {{epi = false, R = 125, r = 50, d = 95, c = 6, w = 2}}},
  {key = "pre_rose", layers = {{epi = true, R = 60, r = 15, d = 30, c = 1, w = 2}, {epi = true, R = 60, r = 20, d = 10, c = 8, w = 1}}},
  {key = "pre_galaxy", layers = {{epi = false, R = 140, r = 97, d = 120, c = 7, w = 1}, {epi = false, R = 140, r = 37, d = 30, c = 5, w = 2}}},
  {key = "pre_lace", layers = {{epi = true, R = 50, r = 21, d = 48, c = 4, w = 1}, {epi = true, R = 50, r = 7, d = 12, c = 2, w = 2}}},
}

local layers = {}
local cur = 1
local darkCanvas = true
local drawSpeed = 3          -- revolutions of the curve per second… (scaled below)
local animating = true
local screen = "edit"        -- "edit", "gallery"
local gallery = {}
local presetSel = 1
local toast, toastT = "", 0
local lastScale, lastCx, lastCy = 0, 0, 0
local pendingDelete = nil    -- {index, design} for undo in the gallery

local function gcd(a, b) while b ~= 0 do a, b = b, a % b end return a end

local function newLayer(src)
  src = src or {}
  return {epi = src.epi == true, R = src.R or 110, r = src.r or 42, d = src.d or 60, c = src.c or 1, w = src.w or 2,
    pts = nil, n = 0, shown = 0}
end

-- full point list of one curve (unit coordinates), closed after r/gcd(R,r) turns
local function points(L)
  local R, r, d = L.R, math.max(1, L.r), L.d
  if not L.epi and r >= R then r = R - 1 end
  local turns = r // gcd(R, r)
  local n = math.min(7000, math.max(200, turns * 140))
  local tmax = 2 * math.pi * turns
  local out = {}
  local k = L.epi and (R + r) / r or (R - r) / r
  for i = 0, n do
    local t = tmax * i / n
    local x, y
    if L.epi then
      x = (R + r) * math.cos(t) - d * math.cos(k * t)
      y = (R + r) * math.sin(t) - d * math.sin(k * t)
    else
      x = (R - r) * math.cos(t) + d * math.cos(k * t)
      y = (R - r) * math.sin(t) - d * math.sin(k * t)
    end
    out[#out + 1] = x
    out[#out + 1] = y
  end
  return out, n + 1
end

local function extent(L)
  return L.epi and (L.R + L.r + L.d) or (math.abs(L.R - L.r) + L.d)
end

-- screen-space chunks of 256 points so a partly drawn curve needs only one small table per frame
local function build(L, cx, cy, s)
  local raw, n = points(L)
  L.chunks = {}
  local chunk
  for i = 0, n - 1 do
    if i % 256 == 0 then
      chunk = {}
      if i > 0 then chunk[1], chunk[2] = cx + raw[i * 2 - 1] * s, cy + raw[i * 2] * s end
      L.chunks[#L.chunks + 1] = chunk
    end
    chunk[#chunk + 1] = cx + raw[i * 2 + 1] * s
    chunk[#chunk + 1] = cy + raw[i * 2 + 2] * s
  end
  L.n = n
  L.raw = raw
end

local function dirty(L, restart)
  L.chunks = nil
  if restart then L.shown = 0 end
end

local function saveWork()
  local out = {}
  for i, L in ipairs(layers) do out[i] = {epi = L.epi, R = L.R, r = L.r, d = L.d, c = L.c, w = L.w} end
  store.set("layers", out)
  return out
end

local function loadDesign(list, animate)
  layers = {}
  for i, l in ipairs(list or {}) do layers[i] = newLayer(l) end
  if #layers == 0 then layers[1] = newLayer() end
  cur = 1
  if not animate then for _, L in ipairs(layers) do L.shown = math.huge end end
  saveWork()
end

local function showToast(s) toast, toastT = s, 2 end

local function randomLayer()
  local L = layers[cur]
  if not L then return end
  L.epi = math.random() < 0.35
  L.R = math.random(60, 140)
  L.r = math.random(9, L.epi and 60 or L.R - 5)
  L.d = math.random(10, L.epi and 60 or 130)
  L.c = math.random(1, 8)
  dirty(L, true)
  saveWork()
end

function app.load()
  local saved = store.get("layers", nil)
  if type(saved) == "table" and #saved > 0 then loadDesign(saved, true) else loadDesign(PRESETS[1].layers, true) end
  local g = store.get("gallery", {})
  gallery = type(g) == "table" and g or {}
  darkCanvas = store.get("dark", true) ~= false
  drawSpeed = store.get("speedv", 3)
  math.randomseed(math.floor(sys.epoch()))
end

function app.update(dt)
  if toastT > 0 then toastT = toastT - dt end
  if not animating then return end
  for _, L in ipairs(layers) do
    if L.n > 0 and L.shown < L.n then L.shown = math.min(L.n, L.shown + dt * 60 * drawSpeed * 4) end
  end
end

-- ------------------------------------------------------------------ drawing
local function drawLayer(L, cx, cy, s, full)
  if not L.chunks then build(L, cx, cy, s) end
  gfx.color(COLORS[L.c] or COLORS[1])
  local limit = full and L.n or math.floor(L.shown)
  local drawn = 0
  for _, ch in ipairs(L.chunks) do
    local cnt = #ch // 2
    if drawn + cnt <= limit + 1 then
      gfx.lines(ch, L.w)
    else
      local left = limit - drawn
      if left >= 2 then
        local part = {}
        for i = 1, left * 2 do part[i] = ch[i] end
        gfx.lines(part, L.w)
      end
      break
    end
    drawn = drawn + cnt - 1
  end
  return limit
end

-- the gear and pen while a curve is being drawn
local function drawGear(L, cx, cy, s, idx)
  local n = L.n
  if idx >= n or idx < 1 or not L.raw then return end
  local R, r = L.R, math.max(1, L.r)
  local turns = r // gcd(R, r)
  local t = 2 * math.pi * turns * idx / math.max(1, n - 1)
  local gx = cx + (L.epi and (R + r) or (R - r)) * math.cos(t) * s
  local gy = cy + (L.epi and (R + r) or (R - r)) * math.sin(t) * s
  local px, py = cx + L.raw[idx * 2 + 1] * s, cy + L.raw[idx * 2 + 2] * s
  gfx.color(darkCanvas and "#FFFFFF30" or "#00000030")
  gfx.circleLine(cx, cy, R * s, 2)
  gfx.circleLine(gx, gy, r * s, 2)
  gfx.line(gx, gy, px, py, 1)
  gfx.color(COLORS[L.c] or COLORS[1])
  gfx.circle(px, py, 5)
end

local function canvasScale(cw, ch)
  local mx = 10
  for _, L in ipairs(layers) do mx = math.max(mx, extent(L)) end
  return (math.min(cw, ch) / 2 - 12) / mx
end

local function drawEditor(w, h)
  local pw = 250
  local cw, ch = w - pw - 36, h - 32
  local x0, y0 = 16, 16
  gfx.shadow(x0, y0, cw, ch, 14, 10, 3)
  gfx.rect(x0, y0, cw, ch, 14, darkCanvas and "#0B0B12" or "#FBFBFD")
  local cx, cy = x0 + cw / 2, y0 + ch / 2
  local s = canvasScale(cw, ch)
  if math.abs(s - lastScale) > 1e-6 or cx ~= lastCx or cy ~= lastCy then
    for _, L in ipairs(layers) do L.chunks = nil end
    lastScale, lastCx, lastCy = s, cx, cy
  end
  gfx.clip(x0, y0, cw, ch)
  local active = nil
  for i, L in ipairs(layers) do
    local shown = drawLayer(L, cx, cy, s, false)
    if shown < L.n and not active then active = {L, shown} end
  end
  if active and animating then drawGear(active[1], cx, cy, s, active[2]) end
  gfx.unclip()

  -- side panel
  local px = w - pw - 16
  local y = 16
  gfx.color(theme.text)
  gfx.text(TR("layer_n", cur, #layers), px, y + 6, 15, "semibold")
  if ui.iconButton("add", px + pw - 108, y, 32, 32, nil, false, "addl") and #layers < 8 then
    layers[#layers + 1] = newLayer({c = (#layers % 8) + 1, R = 100 + math.random(-20, 30), r = math.random(15, 60), d = math.random(20, 80)})
    cur = #layers
    saveWork()
  end
  if ui.iconButton("chevron_left", px + pw - 72, y, 32, 32, nil, false, "prevl") then cur = (cur - 2) % #layers + 1 end
  if ui.iconButton("chevron_right", px + pw - 36, y, 32, 32, nil, false, "nextl") then cur = cur % #layers + 1 end
  y = y + 42
  local L = layers[cur]
  if not L then cur = 1; return end
  local t = ui.segmented("type", {TR("hypo"), TR("epi")}, L.epi and 2 or 1, px, y, pw, 30)
  if (t == 2) ~= L.epi then L.epi = t == 2; dirty(L, true); saveWork() end
  y = y + 40
  local function slider(label, key, lo, hi)
    gfx.color(theme.text2)
    gfx.text(label, px, y, 13)
    gfx.text(tostring(L[key]), px, y, 13, "semibold", "right", pw)
    local v = ui.slider(key, L[key], lo, hi, px, y + 18, pw, 1)
    if v ~= L[key] then L[key] = v; dirty(L, true); saveWork() end
    y = y + 48
  end
  slider(TR("ring"), "R", 30, 150)
  slider(TR("wheel"), "r", 5, L.epi and 100 or math.max(6, L.R - 1))
  slider(TR("pen"), "d", 0, 150)
  gfx.color(theme.text2)
  gfx.text(TR("width"), px, y, 13)
  local nw = ui.segmented("lw", {"1", "2", "3", "5"}, L.w >= 5 and 4 or math.max(1, math.min(3, L.w)), px + 70, y - 6, pw - 70, 28)
  local wv = ({1, 2, 3, 5})[nw]
  if wv ~= L.w then L.w = wv; saveWork() end
  y = y + 34
  local sw = (pw - 9 * 4) / 10
  for i, c in ipairs(COLORS) do
    local sx = px + (i - 1) * (sw + 4)
    local hit = ui.hit("col" .. i, sx, y, sw, 28)
    gfx.rect(sx, y, sw, 28, 6, c)
    gfx.color(theme.separator)
    gfx.rectLine(sx, y, sw, 28, 6, 1)
    if L.c == i then gfx.icon("check", sx + sw / 2, y + 14, 16, i >= 9 and "#000000" or "#FFFFFF") end
    if hit.clicked then L.c = i; saveWork() end
  end
  y = y + 40
  local bw = (pw - 8) / 2
  if ui.button(TR("random"), px, y, bw, 32, "default", "shuffle") then randomLayer() end
  if ui.button(TR("delete"), px + bw + 8, y, bw, 32, "destructive", "delete", #layers > 1) and #layers > 1 then
    table.remove(layers, cur)
    cur = math.max(1, math.min(cur, #layers))
    saveWork()
  end
  y = y + 40
  if ui.button(animating and TR("pause") or TR("play"), px, y, bw, 32, "default", animating and "pause" or "play_arrow") then
    animating = not animating
  end
  if ui.button(TR("redraw"), px + bw + 8, y, bw, 32, "default", "replay") then
    for _, l in ipairs(layers) do l.shown = 0 end
    animating = true
  end
  y = y + 40
  gfx.color(theme.text2)
  gfx.text(TR("draw_speed"), px, y + 4, 13)
  local sp = ui.slider("speedv", drawSpeed, 1, 10, px + 90, y + 6, pw - 90, 1)
  if sp ~= drawSpeed then drawSpeed = sp; store.set("speedv", sp) end
  y = y + 34
  if y + 72 <= h then
    if ui.button(TR("save"), px, y, bw, 32, "primary", "save") then
      gallery[#gallery + 1] = saveWork()
      while #gallery > 24 do table.remove(gallery, 1) end
      store.set("gallery", gallery)
      showToast(TR("saved"))
      audio.play("pop")
    end
    if ui.button(TR("gallery"), px + bw + 8, y, bw, 32, "default", "photo_library") then screen = "gallery" end
  end
end

-- thumbnails are computed once per design and position (weak keys: forgotten when the design is deleted)
local thumbCache = setmetatable({}, {__mode = "k"})
local function drawThumb(design, x, y, size)
  gfx.rect(x, y, size, size, 10, darkCanvas and "#0B0B12" or "#FBFBFD")
  local key = x .. "," .. y .. "," .. size
  local c = thumbCache[design]
  if not c or c.key ~= key then
    local mx = 10
    for _, l in ipairs(design) do mx = math.max(mx, extent(newLayer(l))) end
    local s = (size / 2 - 6) / mx
    c = {key = key, lines = {}}
    for _, l in ipairs(design) do
      local L = newLayer(l)
      local raw, n = points(L)
      local pts = {}
      local stepN = math.max(1, n // 400)
      for i = 0, n - 1, stepN do
        pts[#pts + 1] = x + size / 2 + raw[i * 2 + 1] * s
        pts[#pts + 1] = y + size / 2 + raw[i * 2 + 2] * s
      end
      c.lines[#c.lines + 1] = {pts = pts, color = COLORS[L.c] or COLORS[1]}
    end
    thumbCache[design] = c
  end
  for _, l in ipairs(c.lines) do
    gfx.color(l.color)
    if #l.pts >= 4 then gfx.lines(l.pts, 1) end
  end
end

local function drawGallery(w, h)
  if ui.button(TR("back"), 16, 12, 100, 32, "plain", "arrow_back") then screen = "edit"; return end
  gfx.color(theme.text)
  gfx.text(TR("gallery"), 0, 16, 20, "bold", "center", w)
  if pendingDelete then
    if ui.button(TR("undo"), w - 136, 12, 120, 32, "default", "undo") then
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
  local size = 150
  local cols = math.max(1, (w - 32 + 12) // (size + 12))
  local rows = math.ceil(#gallery / cols)
  local x0 = (w - (cols * (size + 12) - 12)) / 2
  local action = nil
  ui.beginScroll("gal", 0, 56, w, h - 56, rows * (size + 52) + 16)
  for i = #gallery, 1, -1 do
    local k = #gallery - i
    local x, y = x0 + (k % cols) * (size + 12), 8 + (k // cols) * (size + 52)
    local hit = ui.hit("g" .. i, x, y, size, size)
    gfx.shadow(x, y, size, size, 10, 8, 2)
    drawThumb(gallery[i], x, y, size)
    if hit.hovered then gfx.color(theme.accent); gfx.rectLine(x, y, size, size, 10, 2) end
    if hit.clicked then action = {"open", i} end
    if ui.button(TR("open") .. "##o" .. i, x, y + size + 6, size - 40, 30, "default") then action = {"open", i} end
    if ui.iconButton("delete", x + size - 34, y + size + 6, 34, 30, theme.red, false, "d" .. i) then action = {"del", i} end
  end
  ui.endScroll()
  if action and action[1] == "open" and gallery[action[2]] then
    loadDesign(gallery[action[2]], true)
    screen = "edit"
  elseif action and action[1] == "del" and gallery[action[2]] then
    pendingDelete = {action[2], table.remove(gallery, action[2])}
    store.set("gallery", gallery)
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  if screen == "gallery" then drawGallery(w, h) else drawEditor(w, h) end
  if toastT > 0 then
    local tw = gfx.textWidth(toast, 13) + 32
    gfx.alpha(math.min(1, toastT * 3))
    gfx.rect(w / 2 - tw / 2, h - 56, tw, 32, 16, "#1C1C1EE6")
    gfx.color("#FFFFFF")
    gfx.text(toast, w / 2 - tw / 2, h - 48, 13, "semibold", "center", tw)
    gfx.unalpha()
  end
end

function app.event(e)
  if e.type ~= "keydown" then return end
  local k = e.key
  if k == "escape" then screen = "edit"
  elseif screen == "edit" then
    if k == "space" then animating = not animating
    elseif k == "r" then randomLayer()
    elseif k == "left" then cur = (cur - 2) % #layers + 1
    elseif k == "right" then cur = cur % #layers + 1
    elseif k == "enter" then for _, l in ipairs(layers) do l.shown = 0 end; animating = true end
  end
end

function app.menu()
  local pre = {}
  for i, p in ipairs(PRESETS) do pre[i] = {label = TR(p.key), id = 100 + i} end
  return {
    {title = TR("app_name"), items = {
      {label = TR("new_design"), id = 1},
      {label = TR("random"), id = 2, shortcut = "R"},
      {label = TR("redraw"), id = 3, shortcut = "Enter"},
      "-",
      {label = TR("save"), id = 4},
      {label = TR("gallery"), id = 5},
      {label = TR("copy_params"), id = 6},
      "-",
      {label = TR("dark_canvas"), id = 7},
    }},
    {title = TR("presets"), items = pre},
  }
end

function app.onmenu(id)
  if id == 1 then loadDesign({{}}, true)
  elseif id == 2 then randomLayer()
  elseif id == 3 then for _, l in ipairs(layers) do l.shown = 0 end; animating = true
  elseif id == 4 then
    gallery[#gallery + 1] = saveWork()
    while #gallery > 24 do table.remove(gallery, 1) end
    store.set("gallery", gallery)
    showToast(TR("saved"))
  elseif id == 5 then screen = "gallery"
  elseif id == 6 then
    local parts = {}
    for i, L in ipairs(layers) do
      parts[i] = string.format("%s R=%d r=%d d=%d", L.epi and "epi" or "hypo", L.R, L.r, L.d)
    end
    sys.clipboard(table.concat(parts, "; "))
    showToast(TR("copied"))
  elseif id == 7 then darkCanvas = not darkCanvas; store.set("dark", darkCanvas)
  elseif id > 100 and PRESETS[id - 100] then loadDesign(PRESETS[id - 100].layers, true); animating = true
  end
end

function app.close()
  saveWork()
  store.save()
  return true
end

return app
