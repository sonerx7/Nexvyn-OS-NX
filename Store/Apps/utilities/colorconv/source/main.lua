-- Color Converter: edit one color as HEX, RGB, HSL or HSV (all kept in sync), read it as CMYK and CSS strings,
-- check its WCAG contrast against white and black, copy any format and keep a list of recent colors.
local app = {}

-- fills {0}, {1}… with plain text (user text may contain "%", which TR's own substitution must not see)
local function fmt(s, ...)
  local a = {...}
  return (s:gsub("{(%d)}", function(i) local v = a[tonumber(i) + 1]; if v ~= nil then return tostring(v) end end))
end

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local MAX_RECENT = 16

local r, g, b = 46, 134, 222              -- the color (0..255)
local hh, hs, hl = 210, 0.73, 0.53         -- HSL view (hue degrees, 0..1)
local vh, vs, vv = 210, 0.79, 0.87         -- HSV view
local model = 1                             -- slider set: 1 RGB, 2 HSL, 3 HSV
local field, fieldBad = "", false
local recent = {}
local changedAt, pendingRecent = 0, false
local shown = {46, 134, 222}                -- eased preview color
local toast, toastT = "", 0
local copiedKey, copiedT = "", 0
local now = 0
local cache = {}                            -- strings rebuilt only when the color changes

-- ------------------------------------------------------------------ color math
local function clamp(x, lo, hi) return max(lo, min(hi, x)) end
local function round(x) return floor(x + 0.5) end

local function hsl2rgb(h, s, l)
  local c = (1 - abs(2 * l - 1)) * s
  local hp = (h % 360) / 60
  local x = c * (1 - abs(hp % 2 - 1))
  local r1, g1, b1 = 0, 0, 0
  if hp < 1 then r1, g1 = c, x elseif hp < 2 then r1, g1 = x, c elseif hp < 3 then g1, b1 = c, x
  elseif hp < 4 then g1, b1 = x, c elseif hp < 5 then r1, b1 = x, c else r1, b1 = c, x end
  local m = l - c / 2
  return round((r1 + m) * 255), round((g1 + m) * 255), round((b1 + m) * 255)
end

local function hsv2rgb(h, s, v)
  local c = v * s
  local hp = (h % 360) / 60
  local x = c * (1 - abs(hp % 2 - 1))
  local r1, g1, b1 = 0, 0, 0
  if hp < 1 then r1, g1 = c, x elseif hp < 2 then r1, g1 = x, c elseif hp < 3 then g1, b1 = c, x
  elseif hp < 4 then g1, b1 = x, c elseif hp < 5 then r1, b1 = x, c else r1, b1 = c, x end
  local m = v - c
  return round((r1 + m) * 255), round((g1 + m) * 255), round((b1 + m) * 255)
end

-- hue (nil for greys), HSL saturation and lightness, HSV saturation and value
local function analyse(R, G, B)
  local rr, gg, bb = R / 255, G / 255, B / 255
  local mx, mn = max(rr, gg, bb), min(rr, gg, bb)
  local d = mx - mn
  local h = nil
  if d > 0 then
    if mx == rr then h = ((gg - bb) / d) % 6
    elseif mx == gg then h = (bb - rr) / d + 2
    else h = (rr - gg) / d + 4 end
    h = h * 60
  end
  local l = (mx + mn) / 2
  local sl = (d == 0) and 0 or d / (1 - abs(2 * l - 1))
  local sv = (mx == 0) and 0 or d / mx
  return h, clamp(sl, 0, 1), l, sv, mx
end

local function hex(R, G, B) return string.format("#%02X%02X%02X", R, G, B) end

local function luminance(R, G, B)
  local function lin(c) c = c / 255; return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4 end
  return 0.2126 * lin(R) + 0.7152 * lin(G) + 0.0722 * lin(B)
end

local function cmyk(R, G, B)
  local rr, gg, bb = R / 255, G / 255, B / 255
  local k = 1 - max(rr, gg, bb)
  if k >= 1 then return 0, 0, 0, 100 end
  return round((1 - rr - k) / (1 - k) * 100), round((1 - gg - k) / (1 - k) * 100), round((1 - bb - k) / (1 - k) * 100), round(k * 100)
end

-- accepts #RGB, #RRGGBB, rgb(r, g, b) and hsl(h, s%, l%)
local function parse(t)
  t = tostring(t or ""):lower():gsub("%s", "")
  local hx = t:gsub("^#", "")
  if hx:match("^%x%x%x$") then hx = hx:sub(1, 1):rep(2) .. hx:sub(2, 2):rep(2) .. hx:sub(3, 3):rep(2) end
  if hx:match("^%x%x%x%x%x%x$") then
    return tonumber(hx:sub(1, 2), 16), tonumber(hx:sub(3, 4), 16), tonumber(hx:sub(5, 6), 16)
  end
  local a, b2, c = t:match("^rgba?%((%d+%.?%d*),(%d+%.?%d*),(%d+%.?%d*)")
  if a then
    a, b2, c = tonumber(a), tonumber(b2), tonumber(c)
    if a and b2 and c and a <= 255 and b2 <= 255 and c <= 255 then return round(a), round(b2), round(c) end
    return nil
  end
  local h, s, l = t:match("^hsla?%((%d+%.?%d*),(%d+%.?%d*)%%?,(%d+%.?%d*)%%?")
  if h then
    h, s, l = tonumber(h), tonumber(s), tonumber(l)
    if h and s and l and s <= 100 and l <= 100 then return hsl2rgb(h, s / 100, l / 100) end
  end
  return nil
end

-- ------------------------------------------------------------------ state changes
local function refresh(keepField)
  local L = luminance(r, g, b)
  local c, m, y, k = cmyk(r, g, b)
  cache = {
    hex = hex(r, g, b),
    rgb = string.format("rgb(%d, %d, %d)", r, g, b),
    hsl = string.format("hsl(%d, %d%%, %d%%)", round(hh) % 360, round(hs * 100), round(hl * 100)),
    hsv = string.format("hsv(%d, %d%%, %d%%)", round(vh) % 360, round(vs * 100), round(vv * 100)),
    cmyk = string.format("cmyk(%d%%, %d%%, %d%%, %d%%)", c, m, y, k),
    white = 1.05 / (L + 0.05),
    black = (L + 0.05) / 0.05,
    light = L > 0.18,
  }
  if not keepField then field = cache.hex; fieldBad = false end
  changedAt, pendingRecent = now, true
  store.set("color", cache.hex)
end

local function setRGB(R, G, B, keepField)
  r, g, b = clamp(round(R), 0, 255), clamp(round(G), 0, 255), clamp(round(B), 0, 255)
  local h, sl, l, sv, v = analyse(r, g, b)
  hh, hs, hl = h or hh, sl, l
  vh, vs, vv = h or vh, sv, v
  refresh(keepField)
end

local function setHSL(h, s, l)
  hh, hs, hl = h % 360, clamp(s, 0, 1), clamp(l, 0, 1)
  r, g, b = hsl2rgb(hh, hs, hl)
  local _, _, _, sv, v = analyse(r, g, b)
  vh, vs, vv = hh, sv, v
  refresh()
end

local function setHSV(h, s, v)
  vh, vs, vv = h % 360, clamp(s, 0, 1), clamp(v, 0, 1)
  r, g, b = hsv2rgb(vh, vs, vv)
  local _, sl, l = analyse(r, g, b)
  hh, hs, hl = vh, sl, l
  refresh()
end

local function showToast(s) toast, toastT = s, 2 end

local function copy(key, text)
  sys.clipboard(text)
  copiedKey, copiedT = key, 1.2
  showToast(fmt(TR("copied"), text))
  audio.play("click")
end

local function pushRecent()
  local hx = cache.hex
  for i = #recent, 1, -1 do if recent[i] == hx then table.remove(recent, i) end end
  table.insert(recent, 1, hx)
  while #recent > MAX_RECENT do table.remove(recent) end
  store.set("recent", recent)
end

local function randomColor() setHSL(math.random(0, 359), 0.4 + math.random() * 0.5, 0.3 + math.random() * 0.4) end
local function invert() setRGB(255 - r, 255 - g, 255 - b) end
local function grayscale() local y = round(0.299 * r + 0.587 * g + 0.114 * b); setRGB(y, y, y) end
local function lighten(d) setHSL(hh, hs, hl + d) end

-- ------------------------------------------------------------------ app
function app.load(arg)
  local rc = store.get("recent", {})
  recent = {}
  if type(rc) == "table" then for _, x in ipairs(rc) do if parse(x) then recent[#recent + 1] = x end end end
  model = clamp(floor(tonumber(store.get("model", 1)) or 1), 1, 3)
  local R, G, B = parse(store.get("color", "#2E86DE"))
  setRGB(R or 46, G or 134, B or 222)
  shown = {r, g, b}
  pendingRecent = false
end

function app.update(dt)
  now = now + dt
  toastT = max(0, toastT - dt)
  copiedT = max(0, copiedT - dt)
  local k = min(1, dt * 12)
  shown[1], shown[2], shown[3] = shown[1] + (r - shown[1]) * k, shown[2] + (g - shown[2]) * k, shown[3] + (b - shown[3]) * k
  -- a color that stays unchanged for a moment goes into the recent list
  if pendingRecent and now - changedAt > 1.5 then pendingRecent = false; pushRecent() end
end

local function badge(x, y, label, ok)
  local w = gfx.textWidth(label, 11, "bold") + 14
  gfx.color(ok and theme.green or theme.separator)
  gfx.rect(x, y, w, 20, 10)
  gfx.color(ok and "#FFFFFF" or theme.text3)
  gfx.text(label, x + 7, y + 3, 11, "bold")
  return w + 6
end

-- a chip showing the color as text on white/black, the ratio and the WCAG levels it passes
local function contrastRow(x, y, w, label, ratio, sample)
  gfx.color(sample)
  gfx.rect(x, y + 1, 40, 28, 7)
  gfx.color(theme.separator)
  gfx.rectLine(x, y + 1, 40, 28, 7, 1)
  gfx.color(cache.hex or "#808080")
  gfx.text("Aa", x, y + 5, 15, "bold", "center", 40)
  local tx = x + 50
  if w > 330 then
    gfx.color(theme.text2)
    tx = tx + gfx.text(label, tx, y + 7, 13) + 10
  end
  gfx.color(theme.text)
  local rt = string.format("%.2f:1", ratio)
  local bx = x + w
  -- badges from the right: AAA, AA, AA large
  local labels = {{"AAA", ratio >= 7}, {"AA", ratio >= 4.5}, {TR("large"), ratio >= 3}}
  for i = 1, #labels do
    local wd = gfx.textWidth(labels[i][1], 11, "bold") + 20
    bx = bx - wd
    badge(bx, y + 5, labels[i][1], labels[i][2])
  end
  gfx.text(rt, tx, y + 7, 13, "monobold")
end

local function formatRow(x, y, w, key, label, value)
  gfx.color(theme.text3)
  gfx.text(label, x, y + 9, 11, "semibold")
  gfx.color(theme.text)
  gfx.text(value, x + 48, y + 9, 12, "mono")
  local done = copiedKey == key and copiedT > 0
  if ui.iconButton(done and "check" or "content_copy", x + w - 34, y + 1, 34, 30, done and theme.green or theme.text2, false, key) then
    copy(key, value)
  end
end

local function drawLeft(x, y, w, h)
  -- preview with sample text in white and black
  local ph = min(140, max(100, h * 0.26))
  gfx.shadow(x, y, w, ph, 14, 14, 5)
  gfx.color(round(shown[1]), round(shown[2]), round(shown[3]))
  gfx.rect(x, y, w, ph, 14)
  gfx.color("#FFFFFF")
  gfx.text("Aa", x + 18, y + 14, 34, "bold")
  gfx.text(TR("sample"), x + 18, y + 56, 13)
  gfx.color("#000000")
  gfx.text("Aa", x, y + 14, 34, "bold", "right", w - 18)
  gfx.text(TR("sample"), x, y + 56, 13, "sans", "right", w - 18)
  gfx.color(cache.light and "#000000B0" or "#FFFFFFD0")
  gfx.text(cache.hex or "", x + 18, y + ph - 30, 18, "monobold")
  -- contrast
  local cy = y + ph + 10
  contrastRow(x, cy, w, TR("on_white"), cache.white or 1, "#FFFFFF")
  contrastRow(x, cy + 32, w, TR("on_black"), cache.black or 1, "#000000")
  -- formats
  local fy = cy + 72
  ui.separator(x, fy - 4, x + w)
  formatRow(x, fy, w, "hex", "HEX", cache.hex or "")
  formatRow(x, fy + 32, w, "rgb", "RGB", cache.rgb or "")
  formatRow(x, fy + 64, w, "hsl", "HSL", cache.hsl or "")
  formatRow(x, fy + 96, w, "hsv", "HSV", cache.hsv or "")
  formatRow(x, fy + 128, w, "cmyk", "CMYK", cache.cmyk or "")
end

-- one slider row: label, value, colored track, -/+ buttons
local function channel(id, label, value, lo, hi, x, y, w, unit, c1, c2, c3)
  gfx.color(theme.text2)
  gfx.text(label, x, y, 13, "semibold")
  gfx.color(theme.text)
  gfx.text(value .. unit, x, y, 13, "mono", "right", w)
  local sx, sw = x + 36, w - 72
  if c3 == "rainbow" then
    local stops = {"#FF0000", "#FFFF00", "#00FF00", "#00FFFF", "#0000FF", "#FF00FF", "#FF0000"}
    local seg = sw / 6
    for i = 1, 6 do gfx.gradient(sx + (i - 1) * seg, y + 22, seg + 0.5, 6, stops[i], stops[i + 1], true) end
  elseif c3 then
    gfx.gradient(sx, y + 22, sw / 2 + 0.5, 6, c1, c2, true)
    gfx.gradient(sx + sw / 2, y + 22, sw / 2, 6, c2, c3, true)
  else
    gfx.gradient(sx, y + 22, sw, 6, c1, c2, true, 3)
  end
  local nv = ui.slider(id, value, lo, hi, sx, y + 26, sw, 1)
  if ui.iconButton("remove", x, y + 20, 30, 30, theme.text2, false, id .. "m") then nv = max(lo, value - 1) end
  if ui.iconButton("add", x + w - 30, y + 20, 30, 30, theme.text2, false, id .. "p") then nv = min(hi, value + 1) end
  return round(nv)
end

local function drawSliders(x, y, w)
  if model == 1 then
    local nr = channel("r", TR("red"), r, 0, 255, x, y, w, "", hex(0, g, b), hex(255, g, b))
    local ng = channel("g", TR("green"), g, 0, 255, x, y + 60, w, "", hex(r, 0, b), hex(r, 255, b))
    local nb = channel("b", TR("blue"), b, 0, 255, x, y + 120, w, "", hex(r, g, 0), hex(r, g, 255))
    if nr ~= r or ng ~= g or nb ~= b then setRGB(nr, ng, nb) end
  elseif model == 2 then
    local ih, is, il = round(hh) % 360, round(hs * 100), round(hl * 100)
    local nh = channel("hh", TR("hue"), ih, 0, 359, x, y, w, "°", nil, nil, "rainbow")
    local ns = channel("hs", TR("saturation"), is, 0, 100, x, y + 60, w, "%", hex(hsl2rgb(hh, 0, hl)), hex(hsl2rgb(hh, 1, hl)))
    local nl = channel("hl", TR("lightness"), il, 0, 100, x, y + 120, w, "%", "#000000", hex(hsl2rgb(hh, hs, 0.5)), "#FFFFFF")
    if nh ~= ih or ns ~= is or nl ~= il then
      setHSL(nh ~= ih and nh or hh, ns ~= is and ns / 100 or hs, nl ~= il and nl / 100 or hl)
    end
  else
    local ih, is, iv = round(vh) % 360, round(vs * 100), round(vv * 100)
    local nh = channel("vh", TR("hue"), ih, 0, 359, x, y, w, "°", nil, nil, "rainbow")
    local ns = channel("vs", TR("saturation"), is, 0, 100, x, y + 60, w, "%", hex(hsv2rgb(vh, 0, vv)), hex(hsv2rgb(vh, 1, vv)))
    local nv = channel("vv", TR("value"), iv, 0, 100, x, y + 120, w, "%", "#000000", hex(hsv2rgb(vh, vs, 1)))
    if nh ~= ih or ns ~= is or nv ~= iv then
      setHSV(nh ~= ih and nh or vh, ns ~= is and ns / 100 or vs, nv ~= iv and nv / 100 or vv)
    end
  end
end

local function drawRight(x, y, w, h)
  -- input accepting hex / rgb() / hsl()
  local nt, submitted = ui.textfield("input", field, x, y, w - 84, 32, TR("input_hint"))
  if nt ~= field then
    field = nt
    local R, G, B = parse(nt)
    fieldBad = R == nil
    if R then setRGB(R, G, B, true) end
  end
  if submitted then
    local R, G, B = parse(field)
    if R then setRGB(R, G, B); pushRecent(); pendingRecent = false else fieldBad = true end
  end
  if ui.iconButton("shuffle", x + w - 78, y, 36, 32, theme.accent, false, "rnd") then randomColor() end
  if ui.iconButton("content_copy", x + w - 38, y, 36, 32, theme.text2, false, "cpy") then copy("hex", cache.hex) end
  local sy = y + 42
  if fieldBad and field ~= "" then
    gfx.color(theme.red)
    gfx.text(TR("bad_input"), x, y + 36, 11)
    sy = sy + 12
  end
  local nm = ui.segmented("model", {"RGB", "HSL", "HSV"}, model, x, sy, w, 30)
  if nm ~= model then model = nm; store.set("model", model) end
  drawSliders(x, sy + 44, w)
  -- quick actions
  local ay = sy + 44 + 176
  local bw = (w - 18) / 4
  local acts = {{"invert", "invert_colors", invert}, {"gray", "filter_b_and_w", grayscale},
                {"lighter", "brightness_high", function() lighten(0.05) end}, {"darker", "brightness_low", function() lighten(-0.05) end}}
  for i, a in ipairs(acts) do
    local bx = x + (i - 1) * (bw + 6)
    local clicked
    -- labels only when the buttons are wide enough, icons always
    if bw >= 118 then clicked = ui.button(TR(a[1]) .. "##" .. a[1], bx, ay, bw, 32, "default", a[2])
    else clicked = ui.iconButton(a[2], bx, ay, bw, 32, theme.text, false, a[1]) end
    if clicked then a[3]() end
  end
  -- recent colors
  local ry = ay + 46
  gfx.color(theme.text)
  gfx.text(TR("recent"), x, ry, 14, "semibold")
  if #recent > 0 and ui.button(TR("clear") .. "##rec", x + w - 80, ry - 6, 80, 28, "plain") then
    ui.alert(TR("clear_recent"), TR("clear_recent_msg"), {TR("clear"), TR("common.cancel")}, function(i)
      if i == 1 then recent = {}; store.set("recent", recent) end
    end)
  end
  local cy = ry + 26
  if #recent == 0 then
    gfx.icon("history", x + 18, cy + 18, 28, theme.text3)
    gfx.color(theme.text3)
    gfx.wrap(TR("no_recent"), x + 42, cy + 6, w - 42, 12)
    return
  end
  local size = 34
  local per = max(1, floor((w + 8) / (size + 8)))
  for i, c in ipairs(recent) do
    local col, row = (i - 1) % per, floor((i - 1) / per)
    local cx, cyy = x + col * (size + 8), cy + row * (size + 8)
    if cyy + size > y + h then break end
    gfx.color(c)
    gfx.rect(cx, cyy, size, size, 9)
    gfx.color(theme.separator)
    gfx.rectLine(cx, cyy, size, size, 9, 1)
    if c == cache.hex then
      gfx.color(theme.accent)
      gfx.rectLine(cx - 3, cyy - 3, size + 6, size + 6, 11, 2)
    end
    if ui.hit("rec" .. i, cx, cyy, size, size).clicked then
      local R, G, B = parse(c)
      if R then setRGB(R, G, B); pendingRecent = false end
    end
  end
end

local function drawToast(w, h)
  if toastT <= 0 then return end
  local a = min(1, toastT * 4)
  local tw = min(w - 40, gfx.textWidth(toast, 13, "semibold") + 36)
  local tx, ty = (w - tw) / 2, h - 58 + (1 - a) * 20
  gfx.alpha(a)
  gfx.shadow(tx, ty, tw, 38, 19, 12, 4)
  gfx.color(theme.dark and "#3A3A3C" or "#1C1C1E")
  gfx.rect(tx, ty, tw, 38, 19)
  gfx.color("#FFFFFF")
  gfx.text(toast, tx + 18, ty + 10, 13, "semibold")
  gfx.unalpha()
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local lw = min(340, floor((w - 60) * 0.48))
  drawLeft(20, 16, lw, h - 32)
  local rx = 20 + lw + 20
  drawRight(rx, 16, w - rx - 20, h - 32)
  drawToast(w, h)
end

function app.event(e)
  if e.type ~= "keydown" or not e.ctrl then return end
  local k = e.key
  if k == "r" then randomColor()
  elseif k == "i" then invert()
  elseif k == "g" then grayscale()
  elseif k == "up" then lighten(0.05)
  elseif k == "down" then lighten(-0.05)
  elseif k == "1" or k == "2" or k == "3" then model = tonumber(k); store.set("model", model)
  elseif k == "c" and e.shift then copy("hex", cache.hex) end
end

function app.menu()
  return {
    {title = TR("menu_color"), items = {
      {label = TR("random"), id = 1, shortcut = "Ctrl+R"},
      {label = TR("invert"), id = 2, shortcut = "Ctrl+I"},
      {label = TR("gray"), id = 3, shortcut = "Ctrl+G"},
      {label = TR("lighter"), id = 4, shortcut = "Ctrl+Up"},
      {label = TR("darker"), id = 5, shortcut = "Ctrl+Down"},
      "-",
      {label = TR("clear_recent"), id = 6},
    }},
    {title = TR("menu_copy"), items = {
      {label = "HEX", id = 10, shortcut = "Ctrl+Shift+C"},
      {label = "rgb()", id = 11},
      {label = "hsl()", id = 12},
      {label = "hsv()", id = 13},
      {label = "cmyk()", id = 14},
    }},
    {title = TR("menu_view"), items = {
      {label = "RGB", id = 20, shortcut = "Ctrl+1"},
      {label = "HSL", id = 21, shortcut = "Ctrl+2"},
      {label = "HSV", id = 22, shortcut = "Ctrl+3"},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then randomColor() elseif id == 2 then invert() elseif id == 3 then grayscale()
  elseif id == 4 then lighten(0.05) elseif id == 5 then lighten(-0.05)
  elseif id == 6 then recent = {}; store.set("recent", recent)
  elseif id == 10 then copy("hex", cache.hex) elseif id == 11 then copy("rgb", cache.rgb)
  elseif id == 12 then copy("hsl", cache.hsl) elseif id == 13 then copy("hsv", cache.hsv)
  elseif id == 14 then copy("cmyk", cache.cmyk)
  elseif id >= 20 and id <= 22 then model = id - 19; store.set("model", model) end
end

function app.close()
  store.save()
  return true
end

return app
