-- Color Palette: pick a base color (hex, HSL sliders, hue wheel or random) and get harmonies, copy any swatch,
-- save favorite palettes and export them as text, CSS variables or a GIMP palette file.
local app = {}

-- fills {0}, {1}… with plain text (user text may contain "%", which TR's own substitution must not see)
local function fmt(s, ...)
  local a = {...}
  return (s:gsub("{(%d)}", function(i) local v = a[tonumber(i) + 1]; if v ~= nil then return tostring(v) end end))
end

local floor, min, max, abs, sin, cos, pi, atan = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi, math.atan
local MAX_FAVS = 40

local h, s, l = 210, 0.75, 0.55       -- base color (hue degrees, saturation and lightness 0..1)
local hexText, hexBad = "", false
local mode = 1                         -- harmony index into MODES
local tab = 1                          -- 1 harmonies, 2 favorites
local swatches = {}                    -- current palette: {hex, r, g, b, light}
local shown = {}                       -- eased swatch colors {r, g, b}
local favs = {}                        -- {base = "#...", mode = n, colors = {...}}
local toast, toastT, undoFav = "", 0, nil
local wheelDrag = false
local copiedIdx, copiedT = 0, 0

-- ------------------------------------------------------------------ color math
local function clamp01(x) return max(0, min(1, x)) end

local function hsl2rgb(hh, ss, ll)
  hh = (hh % 360) / 360
  local function f(p, q, t)
    if t < 0 then t = t + 1 elseif t > 1 then t = t - 1 end
    if t < 1 / 6 then return p + (q - p) * 6 * t end
    if t < 1 / 2 then return q end
    if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
    return p
  end
  if ss <= 0 then local v = floor(ll * 255 + 0.5); return v, v, v end
  local q = ll < 0.5 and ll * (1 + ss) or ll + ss - ll * ss
  local p = 2 * ll - q
  return floor(f(p, q, hh + 1 / 3) * 255 + 0.5), floor(f(p, q, hh) * 255 + 0.5), floor(f(p, q, hh - 1 / 3) * 255 + 0.5)
end

local function rgb2hsl(r, g, b)
  r, g, b = r / 255, g / 255, b / 255
  local mx, mn = max(r, g, b), min(r, g, b)
  local ll = (mx + mn) / 2
  if mx == mn then return nil, 0, ll end   -- grey: hue undefined
  local d = mx - mn
  local ss = ll > 0.5 and d / (2 - mx - mn) or d / (mx + mn)
  local hh
  if mx == r then hh = (g - b) / d + (g < b and 6 or 0)
  elseif mx == g then hh = (b - r) / d + 2
  else hh = (r - g) / d + 4 end
  return hh * 60, ss, ll
end

local function toHex(r, g, b) return string.format("#%02X%02X%02X", r, g, b) end

local function parseHex(t)
  t = tostring(t or ""):gsub("%s", ""):gsub("^#", "")
  if t:match("^%x%x%x$") then t = t:sub(1, 1):rep(2) .. t:sub(2, 2):rep(2) .. t:sub(3, 3):rep(2) end
  if not t:match("^%x%x%x%x%x%x$") then return nil end
  return tonumber(t:sub(1, 2), 16), tonumber(t:sub(3, 4), 16), tonumber(t:sub(5, 6), 16)
end

-- relative luminance decides black or white text on a swatch
local function isLight(r, g, b) return (0.299 * r + 0.587 * g + 0.114 * b) > 150 end

local function baseHex() return toHex(hsl2rgb(h, s, l)) end

-- ------------------------------------------------------------------ harmonies
local MODES = {
  {key = "complementary", hues = {0, 180}},
  {key = "analogous", hues = {-40, -20, 0, 20, 40}},
  {key = "triadic", hues = {0, 120, 240}},
  {key = "tetradic", hues = {0, 90, 180, 270}},
  {key = "split", hues = {0, 150, 210}},
  {key = "mono"},
  {key = "shades"},
}

local function modeName(i)
  local k = MODES[i] and MODES[i].key
  if k == "complementary" then return TR("complementary")
  elseif k == "analogous" then return TR("analogous")
  elseif k == "triadic" then return TR("triadic")
  elseif k == "tetradic" then return TR("tetradic")
  elseif k == "split" then return TR("split")
  elseif k == "mono" then return TR("mono") end
  return TR("shades")
end

local function modeDesc(i)
  local k = MODES[i] and MODES[i].key
  if k == "complementary" then return TR("complementary_desc")
  elseif k == "analogous" then return TR("analogous_desc")
  elseif k == "triadic" then return TR("triadic_desc")
  elseif k == "tetradic" then return TR("tetradic_desc")
  elseif k == "split" then return TR("split_desc")
  elseif k == "mono" then return TR("mono_desc") end
  return TR("shades_desc")
end

local MODE_NAMES = {}

local function addSwatch(r, g, b)
  swatches[#swatches + 1] = {hex = toHex(r, g, b), r = r, g = g, b = b, light = isLight(r, g, b)}
end

-- rebuilds the palette; called only when the base color or the mode changes
local function rebuild()
  swatches = {}
  local m = MODES[mode] or MODES[1]
  if m.hues then
    for _, d in ipairs(m.hues) do addSwatch(hsl2rgb(h + d, s, l)) end
  elseif m.key == "mono" then
    for _, d in ipairs({-0.3, -0.15, 0, 0.15, 0.3}) do addSwatch(hsl2rgb(h, s, max(0.06, min(0.94, l + d)))) end
  else
    local r, g, b = hsl2rgb(h, s, l)
    for _, k in ipairs({-0.6, -0.4, -0.2, 0, 0.2, 0.4, 0.6}) do
      if k < 0 then addSwatch(floor(r * (1 + k) + 0.5), floor(g * (1 + k) + 0.5), floor(b * (1 + k) + 0.5))
      else addSwatch(floor(r + (255 - r) * k + 0.5), floor(g + (255 - g) * k + 0.5), floor(b + (255 - b) * k + 0.5)) end
    end
  end
  for i, sw in ipairs(swatches) do
    if not shown[i] then shown[i] = {sw.r, sw.g, sw.b} end
  end
  for i = #shown, #swatches + 1, -1 do shown[i] = nil end
  store.set("base", baseHex())
  store.set("mode", mode)
end

local satLo, satHi = "#808080", "#FF0000"   -- saturation track colors for the current hue/lightness

local function setHSL(nh, ns, nl, keepText)
  h, s, l = nh % 360, clamp01(ns), clamp01(nl)
  satLo, satHi = toHex(hsl2rgb(h, 0, l)), toHex(hsl2rgb(h, 1, l))
  if not keepText then hexText = baseHex(); hexBad = false end
  rebuild()
end

local function setHex(t)
  local r, g, b = parseHex(t)
  if not r then return false end
  local nh, ns, nl = rgb2hsl(r, g, b)
  setHSL(nh or h, ns, nl, true)
  return true
end

local function randomColor()
  setHSL(math.random(0, 359), 0.45 + math.random() * 0.45, 0.35 + math.random() * 0.3)
end

local function showToast(t, undo) toast, toastT, undoFav = t, undo and 5 or 2, undo end

local function copy(text, idx)
  sys.clipboard(text)
  copiedIdx, copiedT = idx or 0, 1.2
  showToast(fmt(TR("copied"), text))
  audio.play("click")
end

local function paletteHexes(colors)
  local t = {}
  for i, c in ipairs(colors) do t[i] = type(c) == "table" and c.hex or tostring(c) end
  return t
end

local function copyPalette() copy(table.concat(paletteHexes(swatches), ", ")) end

local function copyCss()
  local lines = {":root {"}
  for i, c in ipairs(paletteHexes(swatches)) do lines[#lines + 1] = "  --color-" .. i .. ": " .. c .. ";" end
  lines[#lines + 1] = "}"
  sys.clipboard(table.concat(lines, "\n"))
  showToast(TR("css_copied"))
end

-- GIMP / Inkscape palette file
local function savePalette()
  ui.saveFile(function(path)
    if not path then return end
    local lines = {"GIMP Palette", "Name: " .. modeName(mode) .. " " .. baseHex(), "Columns: " .. #swatches, "#"}
    for _, c in ipairs(swatches) do lines[#lines + 1] = string.format("%3d %3d %3d\t%s", c.r, c.g, c.b, c.hex) end
    if fs.write(path, table.concat(lines, "\n") .. "\n") then showToast(TR("saved")) else showToast(TR("save_failed")) end
  end, "palette.gpl", TR("save_file"))
end

local function saveFav()
  local base = baseHex()
  for _, f in ipairs(favs) do
    if f.base == base and f.mode == mode then showToast(TR("already_saved")); return end
  end
  if #favs >= MAX_FAVS then showToast(TR("too_many", MAX_FAVS)); return end
  table.insert(favs, 1, {base = base, mode = mode, colors = paletteHexes(swatches)})
  store.set("favs", favs)
  showToast(TR("fav_saved"))
  audio.play("pop")
end

local function deleteFav(i)
  local f = table.remove(favs, i)
  if not f then return end
  store.set("favs", favs)
  showToast(TR("fav_deleted"), {f = f, i = i})
end

local function undoDelete()
  if not undoFav then return end
  table.insert(favs, min(undoFav.i, #favs + 1), undoFav.f)
  store.set("favs", favs)
  undoFav, toastT = nil, 0
end

local function loadFav(i)
  local f = favs[i]
  if not f then return end
  mode = max(1, min(#MODES, floor(tonumber(f.mode) or 1)))
  setHex(f.base)
  hexText = baseHex()
  tab = 1
end

-- ------------------------------------------------------------------ app
function app.load(arg)
  for i = 1, #MODES do MODE_NAMES[i] = modeName(i) end
  mode = max(1, min(#MODES, floor(tonumber(store.get("mode", 1)) or 1)))
  local fv = store.get("favs", {})
  favs = {}
  if type(fv) == "table" then
    for _, f in ipairs(fv) do
      if type(f) == "table" and parseHex(f.base) and type(f.colors) == "table" then favs[#favs + 1] = f end
    end
  end
  if not setHex(store.get("base", "#2E86DE")) then setHSL(210, 0.75, 0.55) end
  hexText = baseHex()
end

function app.update(dt)
  toastT = max(0, toastT - dt)
  if toastT == 0 then undoFav = nil end
  copiedT = max(0, copiedT - dt)
  local k = min(1, dt * 10)
  for i, sw in ipairs(swatches) do
    local c = shown[i]
    if c then c[1], c[2], c[3] = c[1] + (sw.r - c[1]) * k, c[2] + (sw.g - c[2]) * k, c[3] + (sw.b - c[3]) * k end
  end
end

-- a slider row with a colored track drawn under the label
local function slider(id, label, value, lo, hi, x, y, w, unit, c1, c2, rainbow)
  gfx.color(theme.text2)
  gfx.text(label, x, y, 12, "semibold")
  gfx.text(floor(value + 0.5) .. unit, x, y, 12, "mono", "right", w)
  if rainbow then
    local seg = w / 6
    local stops = {"#FF0000", "#FFFF00", "#00FF00", "#00FFFF", "#0000FF", "#FF00FF", "#FF0000"}
    for i = 1, 6 do gfx.gradient(x + (i - 1) * seg, y + 17, seg + 0.5, 5, stops[i], stops[i + 1], true) end
  else
    gfx.gradient(x, y + 17, w, 5, c1, c2, true, 2)
  end
  return ui.slider(id, value, lo, hi, x, y + 20, w, 1)
end

local WHEEL = {}
for i = 0, 35 do WHEEL[i + 1] = toHex(hsl2rgb(i * 10, 0.85, 0.55)) end

local function drawHueWheel(cx, cy, r)
  -- 36 hue sectors, then a hole, then one dot per harmony color
  for i = 0, 35 do
    local a0 = (i * 10 - 90 - 5) * pi / 180
    gfx.color(WHEEL[i + 1])
    gfx.pie(cx, cy, r, a0, a0 + 10.5 * pi / 180)
  end
  gfx.color(theme.field)
  gfx.circle(cx, cy, r * 0.58)
  local m = MODES[mode]
  local hues = m and m.hues or {0}
  for _, d in ipairs(hues) do
    local a = ((h + d) % 360 - 90) * pi / 180
    local px, py = cx + cos(a) * r * 0.79, cy + sin(a) * r * 0.79
    gfx.color(theme.dark and "#000000" or "#FFFFFF")
    gfx.line(cx, cy, px, py, 1.5)
    gfx.circle(px, py, d == 0 and 8 or 6, "#FFFFFF")
    gfx.circle(px, py, d == 0 and 6 or 4, toHex(hsl2rgb(h + d, s, l)))
  end
  gfx.circle(cx, cy, r * 0.3, baseHex())
  -- tap or drag on the ring to pick the hue
  local hit = ui.hit("huewheel", cx - r, cy - r, r * 2, r * 2)
  if hit.pressed then wheelDrag = true end
  if wheelDrag and not hit.held and not hit.pressed then wheelDrag = false end
  if hit.pressed or (wheelDrag and hit.held) then
    local mx, my = ui.mouse()
    local dx, dy = (mx or cx) - cx, (my or cy) - cy
    if dx * dx + dy * dy > (r * 0.3) ^ 2 then
      local deg = (atan(dy, dx) * 180 / pi + 90) % 360
      setHSL(floor(deg + 0.5), s, l)
    end
  end
end

local function drawLeft(x, y, w, hh)
  -- base preview
  local r, g, b = hsl2rgb(h, s, l)
  local light = isLight(r, g, b)
  gfx.shadow(x, y, w, 84, 14, 12, 4)
  gfx.color(baseHex())
  gfx.rect(x, y, w, 84, 14)
  gfx.color(light and "#000000B0" or "#FFFFFFE0")
  gfx.text(TR("base"), x + 14, y + 12, 12, "semibold")
  gfx.text(baseHex(), x + 14, y + 34, 26, "monobold")
  if ui.iconButton("content_copy", x + w - 44, y + 8, 36, 32, light and "#000000" or "#FFFFFF", false, "base") then copy(baseHex()) end
  -- hex field and random
  local fy = y + 96
  local nt, submitted = ui.textfield("hex", hexText, x, fy, w - 84, 32, "#RRGGBB")
  if nt ~= hexText then
    hexText = nt
    hexBad = not setHex(nt)
  end
  if submitted then
    if setHex(hexText) then hexText = baseHex(); hexBad = false else hexBad = true end
  end
  if ui.iconButton("shuffle", x + w - 78, fy, 36, 32, theme.accent, false, "rnd") then randomColor() end
  if ui.iconButton("favorite_border", x + w - 38, fy, 36, 32, theme.pink, false, "fav") then saveFav() end
  local sy = fy + 40
  if hexBad and hexText ~= "" then
    gfx.color(theme.red)
    gfx.text(TR("bad_hex"), x, fy + 36, 11)
    sy = sy + 12
  end
  -- HSL sliders
  -- sliders work on whole numbers; only a real move changes the color (a hex value keeps its precision)
  local ih, is, il = floor(h + 0.5) % 360, floor(s * 100 + 0.5), floor(l * 100 + 0.5)
  local nh = slider("h", TR("hue"), ih, 0, 359, x, sy, w, "°", nil, nil, true)
  local ns = slider("s", TR("saturation"), is, 0, 100, x, sy + 46, w, "%", satLo, satHi)
  local nl = slider("l", TR("lightness"), il, 0, 100, x, sy + 92, w, "%", "#000000", "#FFFFFF")
  if nh ~= ih or ns ~= is or nl ~= il then
    setHSL(nh ~= ih and nh or h, ns ~= is and ns / 100 or s, nl ~= il and nl / 100 or l)
  end
  -- hue wheel fills the rest
  local wy = sy + 140
  local wr = min(w / 2 - 6, (y + hh - wy) / 2 - 4)
  if wr >= 34 then drawHueWheel(x + w / 2, wy + wr + 2, wr) end
end

local function drawHarmonies(x, y, w, hh)
  local nm = ui.dropdown("mode", MODE_NAMES, mode, x, y, min(w, 240), 32)
  if nm ~= mode then mode = nm; rebuild() end
  gfx.color(theme.text2)
  gfx.wrap(modeDesc(mode), x, y + 40, w, 12)
  -- the strip: every swatch as a tall color block
  local sy, sh = y + 70, min(110, max(60, hh * 0.28))
  local n = max(1, #swatches)
  local bw = w / n
  gfx.shadow(x, sy, w, sh, 14, 12, 4)
  gfx.clip(x, sy, w, sh)
  for i, sw in ipairs(swatches) do
    local c = shown[i] or {sw.r, sw.g, sw.b}
    gfx.color(floor(c[1] + 0.5), floor(c[2] + 0.5), floor(c[3] + 0.5))
    gfx.rect(x + (i - 1) * bw, sy, bw + 1, sh)
    if copiedIdx == i and copiedT > 0 then
      gfx.icon("check", x + (i - 0.5) * bw, sy + sh / 2, 28, sw.light and "#000000" or "#FFFFFF")
    end
    if ui.hit("strip" .. i, x + (i - 1) * bw, sy, bw, sh).clicked then copy(sw.hex, i) end
  end
  gfx.unclip()
  gfx.color(theme.separator)
  gfx.rectLine(x, sy, w, sh, 14, 1)
  -- one row per swatch with values and a copy button
  local ly = sy + sh + 12
  local rowH = 40
  ui.beginScroll("rows", x, ly, w, y + hh - ly, #swatches * rowH)
  for i, sw in ipairs(swatches) do
    local ry = (i - 1) * rowH
    gfx.color(sw.hex)
    gfx.rect(0, ry + 5, 30, 30, 8)
    gfx.color(theme.separator)
    gfx.rectLine(0, ry + 5, 30, 30, 8, 1)
    gfx.color(theme.text)
    gfx.text(sw.hex, 42, ry + 4, 14, "monobold")
    local hh2, ss2, ll2 = rgb2hsl(sw.r, sw.g, sw.b)
    gfx.color(theme.text3)
    local info = string.format("rgb(%d, %d, %d)", sw.r, sw.g, sw.b)
    if w > 420 then
      info = info .. string.format(" · hsl(%d, %d%%, %d%%)", floor((hh2 or 0) + 0.5) % 360, floor(ss2 * 100 + 0.5), floor(ll2 * 100 + 0.5))
    end
    gfx.text(info, 42, ry + 22, 11, "mono")
    if ui.iconButton(copiedIdx == i and copiedT > 0 and "check" or "content_copy", w - 38, ry + 4, 34, 32,
        theme.text2, false, "c" .. i) then copy(sw.hex, i) end
  end
  ui.endScroll()
end

local function drawFavorites(x, y, w, hh)
  if #favs == 0 then
    local cy = y + hh / 2
    gfx.icon("palette", x + w / 2, cy - 50, 64, theme.text3)
    gfx.color(theme.text)
    gfx.text(TR("no_favs"), x, cy - 4, 16, "semibold", "center", w)
    gfx.color(theme.text2)
    gfx.wrap(TR("no_favs_hint"), x + 20, cy + 20, w - 40, 13, "sans", "center")
    return
  end
  local rowH = 70
  ui.beginScroll("favs", x, y, w, hh, #favs * rowH)
  for i, f in ipairs(favs) do
    local ry = (i - 1) * rowH
    local cols = f.colors
    local n = max(1, #cols)
    local sw = (w - 90) / n
    gfx.clip(0, ry + 6, w - 90, 40)
    for k, c in ipairs(cols) do
      gfx.color(parseHex(c) and c or "#808080")
      gfx.rect((k - 1) * sw, ry + 6, sw + 1, 40)
    end
    gfx.unclip()
    gfx.color(theme.separator)
    gfx.rectLine(0, ry + 6, w - 90, 40, 10, 1)
    gfx.color(theme.text3)
    local mi = max(1, min(#MODES, floor(tonumber(f.mode) or 1)))
    gfx.text(MODE_NAMES[mi] .. " · " .. tostring(f.base), 2, ry + 50, 11)
    if ui.hit("fav" .. i, 0, ry + 6, w - 90, 40).clicked then loadFav(i) end
    if ui.iconButton("content_copy", w - 82, ry + 10, 36, 32, theme.text2, false, "fc" .. i) then
      copy(table.concat(paletteHexes(cols), ", "))
    end
    if ui.iconButton("delete", w - 42, ry + 10, 36, 32, theme.red, false, "fd" .. i) then deleteFav(i) end
  end
  ui.endScroll()
end

local function drawToast(w, hh)
  if toastT <= 0 then return end
  local a = min(1, toastT * 4)
  local tw = min(w - 40, gfx.textWidth(toast, 13, "semibold") + 36)
  local extra = undoFav and 76 or 0
  local tx, ty = (w - tw - extra) / 2, hh - 58 + (1 - a) * 20
  gfx.alpha(a)
  gfx.shadow(tx, ty, tw + extra, 38, 19, 12, 4)
  gfx.color(theme.dark and "#3A3A3C" or "#1C1C1E")
  gfx.rect(tx, ty, tw + extra, 38, 19)
  gfx.color("#FFFFFF")
  gfx.text(toast, tx + 18, ty + 10, 13, "semibold")
  gfx.unalpha()
  if undoFav and ui.button(TR("undo"), tx + tw, ty + 4, 70, 30, "plain") then undoDelete() end
end

function app.draw(w, hh)
  gfx.clear(theme.bg)
  local lw = w >= 760 and 280 or 250
  drawLeft(20, 16, lw, hh - 32)
  local rx = 20 + lw + 24
  local rw = w - rx - 20
  tab = ui.segmented("tab", {TR("tab_harmonies"), TR("tab_favorites") .. " (" .. #favs .. ")"}, tab, rx, 16, min(rw, 300), 30)
  if rw > 340 and tab == 1 then
    if ui.iconButton("ios_share", rx + rw - 36, 16, 36, 30, theme.text2, false, "exp") then savePalette() end
  end
  if tab == 1 then drawHarmonies(rx, 58, rw, hh - 58 - 16) else drawFavorites(rx, 58, rw, hh - 58 - 16) end
  drawToast(w, hh)
end

function app.event(e)
  if e.type ~= "keydown" or not e.ctrl then return end
  local k = e.key
  if k == "r" then randomColor()
  elseif k == "s" then saveFav()
  elseif k == "e" then copyPalette()
  elseif k == "z" then undoDelete()
  elseif k == "right" then mode = mode % #MODES + 1; rebuild()
  elseif k == "left" then mode = (mode - 2) % #MODES + 1; rebuild()
  elseif k == "tab" then tab = 3 - tab end
end

function app.menu()
  return {
    {title = TR("menu_color"), items = {
      {label = TR("random"), id = 1, shortcut = "Ctrl+R"},
      {label = TR("copy_base"), id = 2},
      "-",
      {label = TR("next_harmony"), id = 3, shortcut = "Ctrl+Right"},
      {label = TR("prev_harmony"), id = 4, shortcut = "Ctrl+Left"},
    }},
    {title = TR("menu_palette"), items = {
      {label = TR("save_fav"), id = 10, shortcut = "Ctrl+S"},
      {label = TR("copy_palette"), id = 11, shortcut = "Ctrl+E"},
      {label = TR("copy_css"), id = 12},
      {label = TR("save_file"), id = 13},
      "-",
      {label = TR("undo_delete"), id = 14, shortcut = "Ctrl+Z"},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then randomColor() elseif id == 2 then copy(baseHex())
  elseif id == 3 then mode = mode % #MODES + 1; rebuild()
  elseif id == 4 then mode = (mode - 2) % #MODES + 1; rebuild()
  elseif id == 10 then saveFav() elseif id == 11 then copyPalette() elseif id == 12 then copyCss()
  elseif id == 13 then savePalette() elseif id == 14 then undoDelete() end
end

function app.close()
  store.save()
  return true
end

return app
