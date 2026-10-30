-- Unit Converter for Nexvyn OS
-- 11 categories, live two-way conversion, swap, common conversions and copy to clipboard.
local app = {}

local floor, abs, min, max, pi = math.floor, math.abs, math.min, math.max, math.pi

-- ------------------------------------------------------------------ colors
local cache = {}
local function rgba(c)
  local t = cache[c]
  if not t then
    t = {tonumber(c:sub(2, 3), 16) or 0, tonumber(c:sub(4, 5), 16) or 0, tonumber(c:sub(6, 7), 16) or 0,
         #c >= 9 and (tonumber(c:sub(8, 9), 16) or 255) or 255}
    cache[c] = t
  end
  return t
end
local function alpha(c, a)
  local t = rgba(c)
  return {t[1], t[2], t[3], max(0, min(255, floor(t[4] * a + 0.5)))}
end

-- ------------------------------------------------------------------ unit data
-- unit = {id, factor to base unit, symbol, symbolKey (translated symbol, optional)}
local CATS = {
  {id = "length", icon = "straighten", color = "blue", units = {
    {"um", 1e-6, "µm"}, {"mm", 0.001, "mm"}, {"cm", 0.01, "cm"}, {"m", 1, "m"}, {"km", 1000, "km"},
    {"in", 0.0254, "in"}, {"ft", 0.3048, "ft"}, {"yd", 0.9144, "yd"}, {"mi", 1609.344, "mi"}, {"nmi", 1852, "nmi"}},
    def = {"km", "mi"},
    common = {{"km", "mi"}, {"mi", "km"}, {"m", "ft"}, {"ft", "m"}, {"cm", "in"}, {"in", "cm"}, {"yd", "m"}, {"nmi", "km"}}},
  {id = "mass", icon = "fitness_center", color = "orange", units = {
    {"mg", 1e-6, "mg"}, {"g", 0.001, "g"}, {"kg", 1, "kg"}, {"t", 1000, "t"}, {"oz", 0.028349523125, "oz"},
    {"lb", 0.45359237, "lb"}, {"st", 6.35029318, "st"}, {"ct", 0.0002, "ct"}},
    def = {"kg", "lb"},
    common = {{"kg", "lb"}, {"lb", "kg"}, {"g", "oz"}, {"oz", "g"}, {"st", "kg"}, {"t", "lb"}, {"ct", "g"}}},
  {id = "temp", icon = "thermostat", color = "red", units = {
    {"c", 0, "°C"}, {"f", 0, "°F"}, {"k", 0, "K"}, {"r", 0, "°R"}},
    def = {"c", "f"},
    common = {{"c", "f"}, {"f", "c"}, {"c", "k"}, {"k", "c"}, {"f", "k"}, {"r", "f"}}},
  {id = "volume", icon = "water_drop", color = "blue", units = {
    {"ml", 0.001, "mL"}, {"l", 1, "L"}, {"m3", 1000, "m³"}, {"tsp", 0.00492892159375, "tsp"},
    {"tbsp", 0.01478676478125, "tbsp"}, {"floz", 0.0295735295625, "fl oz"}, {"cup", 0.2365882365, "cup"},
    {"pt", 0.473176473, "pt"}, {"qt", 0.946352946, "qt"}, {"gal", 3.785411784, "gal"}, {"impgal", 4.54609, "imp gal"}},
    def = {"l", "gal"},
    common = {{"l", "gal"}, {"gal", "l"}, {"ml", "floz"}, {"cup", "ml"}, {"tbsp", "ml"}, {"tsp", "ml"}, {"m3", "l"}, {"impgal", "l"}}},
  {id = "area", icon = "square_foot", color = "green", units = {
    {"mm2", 1e-6, "mm²"}, {"cm2", 1e-4, "cm²"}, {"m2", 1, "m²"}, {"ha", 1e4, "ha"}, {"km2", 1e6, "km²"},
    {"in2", 0.00064516, "in²"}, {"ft2", 0.09290304, "ft²"}, {"yd2", 0.83612736, "yd²"}, {"ac", 4046.8564224, "ac"},
    {"mi2", 2589988.110336, "mi²"}},
    def = {"m2", "ft2"},
    common = {{"m2", "ft2"}, {"ft2", "m2"}, {"ha", "ac"}, {"ac", "ha"}, {"km2", "mi2"}, {"mi2", "km2"}, {"cm2", "in2"}}},
  {id = "speed", icon = "speed", color = "purple", units = {
    {"mps", 1, "m/s"}, {"kmh", 1 / 3.6, "km/h"}, {"mph", 0.44704, "mph"}, {"kn", 1852 / 3600, "kn"},
    {"fps", 0.3048, "ft/s"}, {"mach", 340.29, "Mach"}},
    def = {"kmh", "mph"},
    common = {{"kmh", "mph"}, {"mph", "kmh"}, {"mps", "kmh"}, {"kn", "kmh"}, {"mach", "kmh"}, {"fps", "mps"}}},
  {id = "time", icon = "schedule", color = "pink", units = {
    {"ns", 1e-9, "ns"}, {"us", 1e-6, "µs"}, {"ms", 1e-3, "ms"}, {"s", 1, "s", "sym_s"}, {"min", 60, "min", "sym_min"},
    {"h", 3600, "h", "sym_h"}, {"d", 86400, "d", "sym_d"}, {"wk", 604800, "wk", "sym_wk"},
    {"mo", 2629746, "mo", "sym_mo"}, {"yr", 31556952, "yr", "sym_yr"}},
    def = {"h", "min"},
    common = {{"h", "min"}, {"min", "s"}, {"d", "h"}, {"wk", "d"}, {"yr", "d"}, {"s", "ms"}, {"mo", "wk"}}},
  {id = "data", icon = "storage", color = "gray", units = {
    {"bit", 0.125, "bit"}, {"byte", 1, "B"}, {"kb", 1e3, "KB"}, {"mb", 1e6, "MB"}, {"gb", 1e9, "GB"}, {"tb", 1e12, "TB"},
    {"kib", 1024, "KiB"}, {"mib", 1048576, "MiB"}, {"gib", 1073741824, "GiB"}, {"tib", 1099511627776, "TiB"}},
    def = {"gb", "mb"},
    common = {{"gb", "mb"}, {"mb", "kb"}, {"tb", "gb"}, {"gb", "gib"}, {"mib", "mb"}, {"byte", "bit"}, {"tb", "tib"}}},
  {id = "energy", icon = "bolt", color = "yellow", units = {
    {"j", 1, "J"}, {"kj", 1e3, "kJ"}, {"mj", 1e6, "MJ"}, {"cal", 4.184, "cal"}, {"kcal", 4184, "kcal"},
    {"wh", 3600, "Wh"}, {"kwh", 3.6e6, "kWh"}, {"ev", 1.602176634e-19, "eV"}, {"btu", 1055.05585262, "BTU"}},
    def = {"kcal", "kj"},
    common = {{"kcal", "kj"}, {"kj", "kcal"}, {"kwh", "mj"}, {"j", "cal"}, {"btu", "kj"}, {"wh", "j"}}},
  {id = "pressure", icon = "compress", color = "orange", units = {
    {"pa", 1, "Pa"}, {"kpa", 1e3, "kPa"}, {"mpa", 1e6, "MPa"}, {"bar", 1e5, "bar"}, {"mbar", 100, "mbar"},
    {"atm", 101325, "atm"}, {"psi", 6894.757293168, "psi"}, {"mmhg", 133.322387415, "mmHg"}, {"inhg", 3386.389, "inHg"}},
    def = {"bar", "psi"},
    common = {{"bar", "psi"}, {"psi", "bar"}, {"atm", "kpa"}, {"kpa", "psi"}, {"mmhg", "kpa"}, {"mbar", "inhg"}}},
  {id = "angle", icon = "architecture", color = "green", units = {
    {"deg", pi / 180, "°"}, {"rad", 1, "rad"}, {"grad", pi / 200, "grad"}, {"arcmin", pi / 10800, "′"},
    {"arcsec", pi / 648000, "″"}, {"turn", 2 * pi, "turn", "sym_turn"}},
    def = {"deg", "rad"},
    common = {{"deg", "rad"}, {"rad", "deg"}, {"turn", "deg"}, {"deg", "grad"}, {"deg", "arcmin"}, {"arcmin", "arcsec"}}},
}

local function unitIndex(cat, id)
  for i, u in ipairs(cat.units) do if u[1] == id then return i end end
  return 1
end

local function sym(u)
  if u[4] then return TR(u[4]) end
  return u[3]
end

local function toKelvin(id, v)
  if id == "c" then return v + 273.15 end
  if id == "f" then return (v - 32) * 5 / 9 + 273.15 end
  if id == "r" then return v * 5 / 9 end
  return v
end
local function fromKelvin(id, k)
  if id == "c" then return k - 273.15 end
  if id == "f" then return (k - 273.15) * 9 / 5 + 32 end
  if id == "r" then return k * 9 / 5 end
  return k
end

local function convert(cat, from, to, v)
  if cat.id == "temp" then return fromKelvin(to[1], toKelvin(from[1], v)) end
  return v * from[2] / to[2]
end

-- ------------------------------------------------------------------ number formatting
local function decimalSep() return sys.lang() == "tr" and "," or "." end

local function fmt(v)
  if v ~= v then return "" end
  if v == math.huge or v == -math.huge then return v > 0 and "∞" or "-∞" end
  local a = abs(v)
  local s
  if a == 0 then
    s = "0"
  elseif a >= 1e15 or a < 1e-6 then
    s = string.format("%.6e", v)
    local m, e = s:match("^(.-)e(.*)$")
    if m:find("%.") then m = m:gsub("0+$", ""):gsub("%.$", "") end
    s = m .. "e" .. tostring(tonumber(e))
  else
    local mag = floor(math.log(a, 10))
    local dec = max(0, min(10, 7 - mag))
    s = string.format("%." .. dec .. "f", v)
    if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
    if s == "-0" then s = "0" end
  end
  if decimalSep() == "," then s = s:gsub("%.", ",") end
  return s
end

local function parse(s)
  if not s then return nil end
  s = s:gsub("%s", ""):gsub(",", ".")
  if s == "" or s == "-" or s == "." then return nil end
  return tonumber(s)
end

-- ------------------------------------------------------------------ state
local cat = 1
local ua, ub = 1, 2
local textA, textB = "1", ""
local side = 1              -- which field the user typed in last
local editing = nil         -- "A"/"B" while a field (probably) has focus
local toastText, toastAt = nil, -10
local swapAt = -10
local lastLang = nil
local unitLists = {}        -- cached translated dropdown lists per category
local catNames = {}
local fieldRects = {}
local saved = {}            -- per-category unit choice {a, b}

local function C() return CATS[cat] end

local function rebuildNames()
  lastLang = sys.lang()
  unitLists = {}
  catNames = {}
  for i, c in ipairs(CATS) do
    local ck = "cat_" .. c.id
    catNames[i] = TR(ck)
    local l = {}
    for j, u in ipairs(c.units) do local uk = "u_" .. u[1]; l[j] = TR(uk) end
    unitLists[i] = l
  end
end

local function recompute()
  local c = C()
  local from, to = c.units[ua], c.units[ub]
  if side == 1 then
    local v = parse(textA)
    textB = v and fmt(convert(c, from, to, v)) or ""
  else
    local v = parse(textB)
    textA = v and fmt(convert(c, to, from, v)) or ""
  end
end

local function persist()
  saved[CATS[cat].id] = {CATS[cat].units[ua][1], CATS[cat].units[ub][1]}
  store.set("units", saved)
  store.set("cat", CATS[cat].id)
  store.set("value", side == 1 and textA or textB)
  store.set("side", side)
end

local function selectCategory(i)
  if i < 1 then i = #CATS elseif i > #CATS then i = 1 end
  if i == cat then return end
  cat = i
  local c = C()
  local s = saved[c.id] or c.def
  ua, ub = unitIndex(c, s[1]), unitIndex(c, s[2])
  if ua == ub then ub = (ua % #c.units) + 1 end
  if side == 1 then
    if parse(textA) == nil then textA = "1" end
  else
    if parse(textB) == nil then textB = "1" end
  end
  recompute()
  persist()
end

local function swap()
  ua, ub = ub, ua
  textA, textB = textB, textA
  side = side == 1 and 2 or 1
  if editing then editing = editing == "A" and "B" or "A" end
  swapAt = sys.time()
  audio.tone(660, 0.05, 0.25, "triangle")
  persist()
end

local function toast(s)
  toastText, toastAt = s, sys.time()
end

local function copyResult()
  local c = C()
  local text, u
  if side == 1 then text, u = textB, c.units[ub] else text, u = textA, c.units[ua] end
  if text == "" then
    audio.play("error")
    return
  end
  sys.clipboard(text .. " " .. sym(u))
  toast(TR("copied", text .. " " .. sym(u)))
  audio.play("pop", 0.6)
end

local function useCommon(pair, value)
  local c = C()
  ua, ub = unitIndex(c, pair[1]), unitIndex(c, pair[2])
  textA = value or "1"
  side = 1
  editing = nil
  recompute()
  persist()
  audio.tone(880, 0.04, 0.2, "triangle")
end

function app.load()
  saved = store.get("units", {}) or {}
  local cid = store.get("cat", "length")
  cat = 1
  for i, c in ipairs(CATS) do if c.id == cid then cat = i end end
  local c = C()
  local s = saved[c.id] or c.def
  ua, ub = unitIndex(c, s[1]), unitIndex(c, s[2])
  if ua == ub then ub = (ua % #c.units) + 1 end
  side = store.get("side", 1) == 2 and 2 or 1
  local v = store.get("value", "1")
  if type(v) ~= "string" then v = "1" end
  if side == 1 then textA = v else textB = v end
  rebuildNames()
  recompute()
end

-- ------------------------------------------------------------------ drawing
local SIDEBAR = 184

local function tile(x, y, s, colorName, icon, iconSize)
  local col = theme[colorName] or theme.accent
  gfx.gradient(x, y, s, s, col, col, false, s * 0.26)
  gfx.color(255, 255, 255, 40)
  gfx.rect(x, y, s, s * 0.5, s * 0.26)
  gfx.icon(icon, x + s / 2, y + s / 2, iconSize or s * 0.62, "#FFFFFF")
end

local function drawSidebar(h)
  gfx.color(theme.sidebar)
  gfx.rect(0, 0, SIDEBAR, h)
  gfx.color(theme.separator)
  gfx.rect(SIDEBAR - 1, 0, 1, h)
  gfx.color(theme.text2)
  gfx.text(TR("categories"), 18, 14, 12, "semibold")
  local y = 36
  local rowH = min(36, floor((h - y - 10) / #CATS))
  for i, c in ipairs(CATS) do
    local hit = ui.hit("cat" .. i, 8, y, SIDEBAR - 16, rowH - 2)
    local sel = i == cat
    if sel then
      gfx.color(theme.accent)
      gfx.rect(8, y, SIDEBAR - 16, rowH - 2, 7)
    elseif hit.hovered then
      gfx.color(theme.hover)
      gfx.rect(8, y, SIDEBAR - 16, rowH - 2, 7)
    end
    local cy = y + (rowH - 2) / 2
    if sel then
      gfx.color(255, 255, 255, 60)
      gfx.rect(16, cy - 11, 22, 22, 6)
      gfx.icon(c.icon, 27, cy, 15, "#FFFFFF")
    else
      tile(16, cy - 11, 22, c.color, c.icon, 15)
    end
    gfx.color(sel and "#FFFFFF" or theme.text)
    gfx.text(catNames[i], 46, cy - 9, 14, sel and "medium" or "sans")
    if hit.clicked then
      editing = nil
      selectCategory(i)
    end
    y = y + rowH
  end
end

local function drawField(id, label, text, unitSel, x, y, w, now, slide)
  local c = C()
  ui.group(x, y, w, 82)
  gfx.push(0, slide)
  gfx.color(theme.text2)
  gfx.text(label, x + 14, y + 10, 12, "semibold")
  local ddW = min(210, floor(w * 0.46))
  local fw = w - 28 - ddW - 10
  fieldRects[id] = {x + 14, y + 34 + slide, fw, 34}
  local newText, submitted = ui.textfield("field" .. id, text, x + 14, y + 34, fw, 34, "0", "numeric")
  local sel = ui.dropdown("unit" .. id, unitLists[cat], unitSel, x + w - 14 - ddW, y + 36, ddW, 30)
  gfx.color(theme.text3)
  gfx.text(sym(c.units[unitSel]), x + 14 + fw - 6, y + 12, 12, "medium", "right", 0)
  gfx.pop()
  return newText, sel, submitted
end

local function drawContent(w, h, now)
  local c = C()
  local x0 = SIDEBAR + 22
  local cw = w - x0 - 22

  -- header
  tile(x0, 18, 40, c.color, c.icon, 26)
  gfx.color(theme.text)
  gfx.text(catNames[cat], x0 + 54, 18, 21, "bold")
  gfx.color(theme.text2)
  gfx.text(TR("units_count", #c.units), x0 + 54, 44, 12)

  -- two value cards
  local st = min(1, (now - swapAt) / 0.28)
  local ease = 1 - (1 - st) ^ 3
  local slideA, slideB = (1 - ease) * 18, -(1 - ease) * 18
  local yA, yB = 74, 182
  if st < 1 then gfx.alpha(0.35 + 0.65 * ease) end
  local nA, selA, subA = drawField("A", TR("from"), textA, ua, x0, yA, cw, now, slideA)
  local nB, selB, subB = drawField("B", TR("to"), textB, ub, x0, yB, cw, now, slideB)
  if st < 1 then gfx.unalpha() end
  if nA ~= textA then textA = nA; side = 1; editing = "A"; recompute(); persist() end
  if nB ~= textB then textB = nB; side = 2; editing = "B"; recompute(); persist() end
  if selA ~= ua then ua = selA; recompute(); persist(); audio.tone(740, 0.04, 0.2, "triangle") end
  if selB ~= ub then ub = selB; recompute(); persist(); audio.tone(740, 0.04, 0.2, "triangle") end
  if subA or subB then audio.tone(990, 0.04, 0.2, "triangle") end

  -- swap button between the cards
  local sx, sy = x0 + cw / 2, (yA + 82 + yB) / 2
  local sh = ui.hit("swap", sx - 19, sy - 19, 38, 38)
  gfx.shadow(sx - 17, sy - 17, 34, 34, 17, 8, 2)
  gfx.color(sh.held and theme.hover or theme.control)
  gfx.circle(sx, sy, 17)
  gfx.color(theme.separator)
  gfx.circleLine(sx, sy, 17, 1)
  local bounce = st < 1 and math.sin(st * pi) * 3 or 0
  gfx.icon("swap_vert", sx, sy - bounce, 22, sh.hovered and theme.accent or theme.text)
  if sh.clicked then swap() end

  -- formula + copy
  local from, to = c.units[ua], c.units[ub]
  local one = convert(c, from, to, 1)
  local formula
  if c.id == "temp" then
    formula = TR("formula_one", "0 " .. sym(from), fmt(convert(c, from, to, 0)) .. " " .. sym(to))
  else
    formula = TR("formula_one", "1 " .. sym(from), fmt(one) .. " " .. sym(to))
  end
  gfx.color(theme.text2)
  gfx.icon("info", x0 + 9, 284, 16, theme.text3)
  gfx.text(formula, x0 + 22, 275, 13)
  if ui.button(TR("copy"), x0 + cw - 112, 270, 112, 28, "default", "content_copy") then copyResult() end

  -- common conversions
  gfx.color(theme.text)
  gfx.text(TR("common"), x0, 312, 14, "semibold")
  local ly = 336
  local lh = h - ly - 14
  ui.group(x0, ly, cw, lh)
  local rowH = 34
  local n = #c.common
  ui.beginScroll("common", x0, ly, cw, lh, n * rowH + 8)
  for i, pr in ipairs(c.common) do
    local y = 4 + (i - 1) * rowH
    local fu, tu = c.units[unitIndex(c, pr[1])], c.units[unitIndex(c, pr[2])]
    local base = (c.id == "temp") and 100 or 1
    local val = convert(c, fu, tu, base)
    local clicked = ui.row("crow" .. i, 0, y, cw, rowH, false)
    gfx.color(theme.text)
    gfx.text(fmt(base) .. " " .. sym(fu), 16, y + 9, 14, "medium")
    gfx.icon("arrow_forward", cw * 0.42, y + rowH / 2, 16, theme.text3)
    gfx.color(theme.accent)
    gfx.text(fmt(val) .. " " .. sym(tu), cw * 0.42 + 18, y + 9, 14, "semibold")
    gfx.color(theme.text3)
    gfx.text(unitLists[cat][unitIndex(c, pr[2])], 0, y + 10, 12, "sans", "right", cw - 14)
    if i < n then ui.separator(14, y + rowH, cw - 14) end
    if clicked then useCommon(pr, fmt(base)) end
  end
  ui.endScroll()
end

local function drawToast(w, h, now)
  local age = now - toastAt
  if not toastText or age > 1.8 then return end
  local a = min(1, age / 0.15, (1.8 - age) / 0.3)
  local tw = gfx.textWidth(toastText, 13, "medium") + 46
  local x = SIDEBAR + (w - SIDEBAR - tw) / 2
  local y = h - 58 + (1 - min(1, age / 0.2)) * 10
  gfx.alpha(a)
  gfx.shadow(x, y, tw, 34, 17, 12, 3)
  gfx.color(theme.dark and "#3A3A3C" or "#1C1C1E")
  gfx.rect(x, y, tw, 34, 17)
  gfx.icon("check_circle", x + 18, y + 17, 18, theme.green)
  gfx.color("#FFFFFF")
  gfx.text(toastText, x + 32, y + 9, 13, "medium")
  gfx.unalpha()
end

function app.draw(w, h)
  if lastLang ~= sys.lang() then rebuildNames(); recompute() end
  local now = sys.time()
  gfx.clear(theme.bg)
  drawSidebar(h)
  drawContent(w, h, now)
  drawToast(w, h, now)
end

-- ------------------------------------------------------------------ input
local function inRect(r, x, y)
  return r and x >= r[1] and y >= r[2] and x <= r[1] + r[3] and y <= r[2] + r[4]
end

function app.event(e)
  if e.type == "mousedown" then
    if inRect(fieldRects.A, e.x, e.y) then editing = "A"
    elseif inRect(fieldRects.B, e.x, e.y) then editing = "B"
    else editing = nil end
  elseif e.type == "keydown" then
    local k = e.key
    if e.ctrl and k == "r" then swap()
    elseif e.ctrl and e.shift and k == "c" then copyResult()
    elseif k == "tab" then
      editing = (editing == "A") and "B" or "A"
      ui.focus("field" .. editing)
    elseif k == "pagedown" then editing = nil; selectCategory(cat + 1)
    elseif k == "pageup" then editing = nil; selectCategory(cat - 1)
    elseif k == "escape" then editing = nil
    elseif not editing then
      if k == "down" then selectCategory(cat + 1)
      elseif k == "up" then selectCategory(cat - 1)
      elseif k == "enter" or k == "space" then
        editing = "A"
        ui.focus("fieldA")
      end
    end
  end
end

function app.menu()
  local cats = {}
  for i, c in ipairs(CATS) do
    cats[#cats + 1] = {label = catNames[i] or c.id, id = 100 + i, checked = i == cat}
  end
  return {
    {title = TR("menu_convert"), items = {
      {label = TR("swap"), id = 1, shortcut = "Ctrl+R"},
      {label = TR("copy_result"), id = 2, shortcut = "Ctrl+Shift+C"},
      "-",
      {label = TR("reset_value"), id = 3},
    }},
    {title = TR("menu_category"), items = cats},
  }
end

function app.onmenu(id)
  if id == 1 then swap()
  elseif id == 2 then copyResult()
  elseif id == 3 then textA = "1"; side = 1; recompute(); persist()
  elseif id > 100 and id <= 100 + #CATS then selectCategory(id - 100)
  end
end

function app.close()
  persist()
  return true
end

return app
