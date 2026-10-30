-- BMI: body mass index in metric or imperial units, the WHO category on a colored gauge, the healthy weight range
-- for your height, and a saved history with a trend chart, sorting, undo and CSV export. Nexvyn OS Lua SDK.
local app = {}

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local isTR = false

-- ------------------------------------------------------------------ helpers
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end

-- reads "72.5", "72,5", "1.234,5" or "1,234.5"; nil when empty or not a number
local function parseNum(s)
  if type(s) ~= "string" then return nil end
  s = s:gsub("%s", "")
  if s == "" then return nil end
  local lastDot, lastComma = s:match(".*()%."), s:match(".*(),")
  if lastDot and lastComma then
    if lastComma > lastDot then s = s:gsub("%.", ""):gsub(",", ".") else s = s:gsub(",", "") end
  elseif lastComma then
    local _, n = s:gsub(",", "")
    if n > 1 then s = s:gsub(",", "") else s = s:gsub(",", ".") end
  else
    local _, n = s:gsub("%.", "")
    if n > 1 then s = s:gsub("%.", "") end
  end
  local v = tonumber(s)
  if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
  return v
end

local function fmtNum(v, dec)
  dec = dec or 1
  if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return "—" end
  local s = string.format("%." .. dec .. "f", v)
  if isTR then s = s:gsub("%.", ",") end
  return s
end

local function ease(cur, target, dt, speed)
  local n = cur + (target - cur) * min(1, dt * (speed or 9))
  if abs(target - n) < 0.002 then n = target end
  return n
end

local ccache = {}
local function withAlpha(c, a)
  local key = tostring(c) .. a
  local t = ccache[key]
  if not t then
    t = {tonumber(c:sub(2, 3), 16) or 0, tonumber(c:sub(4, 5), 16) or 0, tonumber(c:sub(6, 7), 16) or 0, floor(255 * a)}
    ccache[key] = t
  end
  return t
end

-- ------------------------------------------------------------------ BMI math
local KG_PER_LB, CM_PER_IN = 0.45359237, 2.54
local GMIN, GMAX = 12, 42   -- gauge range

-- WHO adult categories: upper bound (exclusive), key, theme color name
local CATS = {
  {18.5, "cat_under", "blue"},
  {25, "cat_normal", "green"},
  {30, "cat_over", "yellow"},
  {35, "cat_ob1", "orange"},
  {40, "cat_ob2", "red"},
  {1e9, "cat_ob3", "purple"},
}

local function category(b)
  local r = floor(b * 10 + 0.5) / 10   -- classify what the user sees (24.96 shows as 25.0 → overweight)
  for i, c in ipairs(CATS) do if r < c[1] then return i, c end end
  return #CATS, CATS[#CATS]
end

local function catName(i)
  if i == 1 then return TR("cat_under") elseif i == 2 then return TR("cat_normal") elseif i == 3 then return TR("cat_over")
  elseif i == 4 then return TR("cat_ob1") elseif i == 5 then return TR("cat_ob2") end
  return TR("cat_ob3")
end

local function catColor(i)
  local c = CATS[i] or CATS[2]
  return theme[c[3]] or theme.accent
end

-- ------------------------------------------------------------------ state
local tab, tabAnim = 1, 1          -- tabAnim eases toward tab for the slide transition
local units = 1                    -- 1 metric, 2 imperial
local inp = {cm = "", kg = "", ft = "", inch = "", lb = ""}
local hist = {}                    -- {d = "YYYY-MM-DD", t = epoch, w = kg, h = cm, b = bmi}, oldest first
local histVer = 0
local sortMode = 1                 -- 1 newest, 2 oldest, 3 highest BMI, 4 lowest BMI
local chartMode = 1                -- 1 BMI, 2 weight
local view, viewVer = {}, -1       -- sorted indices into hist
local shownBmi, shownMarker = 0, GMIN
local chartIn = 0
local flashT, flashAt = nil, -10   -- newly saved entry, highlighted for a moment
local deleted = nil                -- last deleted entry for undo
local toast, toastAt = nil, -10

local function say(text) toast, toastAt = text, sys.time() end

local function setInp(k, v)
  if inp[k] ~= v then inp[k] = v; store.set("inp", inp) end
end

local function saveHist()
  histVer = histVer + 1
  store.set("hist", hist)
end

-- current inputs → height (cm), weight (kg) or nil plus an error key
local function readInputs()
  local cm, kg
  if units == 1 then
    local c, k = parseNum(inp.cm), parseNum(inp.kg)
    if inp.cm == "" and inp.kg == "" then return nil, nil, nil end
    if not c or c < 50 or c > 250 then return nil, nil, "err_height_cm" end
    if not k or k < 10 or k > 400 then return nil, nil, "err_weight_kg" end
    cm, kg = c, k
  else
    if inp.ft == "" and inp.inch == "" and inp.lb == "" then return nil, nil, nil end
    local f = parseNum(inp.ft) or (inp.ft == "" and 0 or nil)
    local i = parseNum(inp.inch) or (inp.inch == "" and 0 or nil)
    local l = parseNum(inp.lb)
    if not f or not i or f < 0 or i < 0 or i >= 12 then return nil, nil, "err_height_in" end
    local total = f * 12 + i
    if total < 20 or total > 100 then return nil, nil, "err_height_in" end
    if not l or l < 22 or l > 880 then return nil, nil, "err_weight_lb" end
    cm, kg = total * CM_PER_IN, l * KG_PER_LB
  end
  return cm, kg, nil
end

local function bmiOf(cm, kg) local m = cm / 100; return kg / (m * m) end

local function weightText(kg)
  if units == 1 then return fmtNum(kg, 1) .. " kg" end
  return fmtNum(kg / KG_PER_LB, 1) .. " lb"
end

local function dateText(key)
  local y, m, d = tostring(key):match("^(%d+)-(%d+)-(%d+)$")
  if not y then return tostring(key) end
  if isTR then return d .. "." .. m .. "." .. y end
  return key
end

-- switching units converts whatever valid values are typed
local function setUnits(u)
  if u == units or (u ~= 1 and u ~= 2) then return end
  local cm, kg = readInputs()
  units = u
  store.set("units", units)
  if cm and kg then
    if units == 1 then
      setInp("cm", fmtNum(cm, 0)); setInp("kg", fmtNum(kg, 1))
    else
      local total = cm / CM_PER_IN
      local ft = floor(total / 12)
      local inch = floor((total - ft * 12) + 0.5)
      if inch >= 12 then ft, inch = ft + 1, 0 end
      setInp("ft", tostring(ft)); setInp("inch", tostring(inch)); setInp("lb", fmtNum(kg / KG_PER_LB, 1))
    end
  end
end

local function todayKey()
  local d = sys.date()
  return string.format("%04d-%02d-%02d", d.year, d.month, d.day)
end

local function saveMeasurement()
  local cm, kg = readInputs()
  if not cm then say(TR("err_save")); audio.play("error"); return end
  local key = todayKey()
  local e = {d = key, t = sys.epoch(), w = floor(kg * 10 + 0.5) / 10, h = floor(cm * 10 + 0.5) / 10, b = bmiOf(cm, kg)}
  local replaced = false
  for i, it in ipairs(hist) do
    if it.d == key then hist[i] = e; replaced = true; break end
  end
  if not replaced then
    hist[#hist + 1] = e
    while #hist > 500 do table.remove(hist, 1) end
  end
  saveHist()
  flashT, flashAt = e.t, sys.time()
  say(replaced and TR("updated_today") or TR("saved_entry"))
  audio.play("pop")
end

local function deleteEntry(i)
  local e = hist[i]
  if not e then return end
  table.remove(hist, i)
  deleted = {entry = e, index = i}
  saveHist()
  say(TR("deleted_undo"))
  audio.play("trash")
end

local function undoDelete()
  if not deleted then return end
  local i = clamp(deleted.index, 1, #hist + 1)
  table.insert(hist, i, deleted.entry)
  flashT, flashAt = deleted.entry.t, sys.time()
  deleted = nil
  saveHist()
  say(TR("restored"))
end

local function exportCsv()
  if #hist == 0 then say(TR("nothing_export")); return end
  local rows = {"date,height_cm,weight_kg,bmi,category"}
  for _, e in ipairs(hist) do
    local ci = category(e.b or 0)
    rows[#rows + 1] = string.format("%s,%.1f,%.1f,%.1f,%s", tostring(e.d), e.h or 0, e.w or 0, e.b or 0, catName(ci))
  end
  local text = table.concat(rows, "\n") .. "\n"
  ui.saveFile(function(path)
    if not path then return end
    if fs.write(path, text) then say(TR("exported")) else say(TR("save_failed")) end
  end, "bmi.csv", TR("export"))
end

-- sorted view, rebuilt only when the history or the sort changes
local function sortedView()
  local key = histVer * 10 + sortMode
  if viewVer == key then return view end
  view = {}
  for i = 1, #hist do view[i] = i end
  table.sort(view, function(a, b)
    local A, B = hist[a], hist[b]
    if sortMode == 2 then return (A.t or 0) < (B.t or 0)
    elseif sortMode == 3 then return (A.b or 0) > (B.b or 0)
    elseif sortMode == 4 then return (A.b or 0) < (B.b or 0) end
    return (A.t or 0) > (B.t or 0)
  end)
  viewVer = key
  return view
end

-- ------------------------------------------------------------------ lifecycle
function app.load(arg)
  isTR = sys.lang() == "tr"
  units = store.get("units", 1) == 2 and 2 or 1
  local s = store.get("inp", nil)
  if type(s) == "table" then
    for k in pairs(inp) do if type(s[k]) == "string" then inp[k] = s[k] end end
  end
  local h = store.get("hist", {})
  if type(h) == "table" then
    for _, e in ipairs(h) do
      if type(e) == "table" and tonumber(e.w) and tonumber(e.h) and tonumber(e.b) then
        hist[#hist + 1] = {d = tostring(e.d or "?"), t = tonumber(e.t) or 0, w = tonumber(e.w), h = tonumber(e.h), b = tonumber(e.b)}
      end
    end
  end
  sortMode = clamp(tonumber(store.get("sort", 1)) or 1, 1, 4)
  chartMode = store.get("chart", 1) == 2 and 2 or 1
  local cm, kg = readInputs()
  if cm then shownBmi = bmiOf(cm, kg); shownMarker = clamp(shownBmi, GMIN, GMAX) end
end

function app.update(dt)
  tabAnim = ease(tabAnim, tab, dt, 12)
  local cm, kg = readInputs()
  if cm then
    local b = bmiOf(cm, kg)
    shownBmi = ease(shownBmi, b, dt)
    shownMarker = ease(shownMarker, clamp(b, GMIN, GMAX), dt, 7)
  end
  chartIn = tab == 2 and min(1, chartIn + dt * 1.8) or 0
end

-- ------------------------------------------------------------------ calculator tab
local function label(text, x, y)
  gfx.color(theme.text2)
  gfx.text(text, x, y, 13, "semibold")
end

local function field(id, key, x, y, w, ph, unit)
  local nt = ui.textfield(id, inp[key], x, y, w - 36, 34, ph, "numeric")
  setInp(key, nt)
  gfx.color(theme.text2)
  gfx.text(unit, x + w - 30, y + 9, 13, "medium")
end

local function drawGauge(x, y, w, b)
  local function px(v) return x + (clamp(v, GMIN, GMAX) - GMIN) / (GMAX - GMIN) * w end
  local lo = GMIN
  for i, c in ipairs(CATS) do
    local hi = min(c[1], GMAX)
    local x0, x1 = px(lo), px(hi)
    local r = (i == 1 or i == #CATS) and 6 or 0
    gfx.rect(x0, y, max(1, x1 - x0), 12, r, catColor(i))
    lo = hi
  end
  gfx.color(theme.text3)
  for _, t in ipairs({18.5, 25, 30, 35, 40}) do
    local tx = px(t)
    gfx.text(fmtNum(t, t % 1 == 0 and 0 or 1), tx - 20, y + 18, 11, "sans", "center", 40)
  end
  if b then
    local mx = px(shownMarker)
    gfx.poly({mx - 8, y - 12, mx + 8, y - 12, mx, y - 2}, theme.text)
    gfx.circle(mx, y + 6, 8, theme.bg)
    gfx.circleLine(mx, y + 6, 8, 3)
  end
end

local function drawCalc(w, h)
  local m = 20
  local lw = max(220, floor((w - 3 * m) * 0.42))
  local x, y = m, 60
  local u = ui.segmented("units", {TR("metric"), TR("imperial")}, units, x, y, lw, 32)
  if u ~= units then setUnits(u) end
  y = y + 48
  label(TR("height"), x, y)
  if units == 1 then
    field("cm", "cm", x, y + 20, lw, "175", "cm")
  else
    local hw = (lw - 10) / 2
    field("ft", "ft", x, y + 20, hw, "5", "ft")
    field("inch", "inch", x + hw + 10, y + 20, hw, "9", "in")
  end
  y = y + 66
  label(TR("weight"), x, y)
  if units == 1 then field("kg", "kg", x, y + 20, lw, "70", "kg") else field("lb", "lb", x, y + 20, lw, "154", "lb") end
  local cm, kg, err = readInputs()
  y = y + 62
  if err then
    gfx.icon("error_outline", x + 8, y + 8, 16, theme.red)
    gfx.color(theme.red)
    gfx.wrap(TR(err), x + 22, y, lw - 22, 12)
  end
  local by = max(y + 40, h - m - 36)
  if ui.button(TR("save_measure"), x, by, lw, 36, "primary", "save", cm ~= nil) then saveMeasurement() end

  -- result panel
  local rx = x + lw + m
  local rw = w - rx - m
  local ry, rh = 60, h - 60 - m
  ui.group(rx, ry, rw, rh)
  local px, pw = rx + 20, rw - 40
  if not cm then
    local cx, cy = rx + rw / 2, ry + rh / 2 - 30
    gfx.circle(cx, cy, 44, withAlpha(theme.accent, 0.12))
    gfx.icon("monitor_weight", cx, cy, 48, theme.accent)
    gfx.color(theme.text)
    gfx.text(TR("empty_title"), rx, cy + 58, 15, "semibold", "center", rw)
    gfx.color(theme.text2)
    gfx.wrap(TR("empty_body"), px, cy + 82, pw, 13, "sans", "center")
    drawGauge(px, ry + rh - 60, pw, nil)
    return
  end
  local b = bmiOf(cm, kg)
  local ci = category(b)
  local col = catColor(ci)
  gfx.color(theme.text2)
  gfx.text(TR("your_bmi"), px, ry + 16, 13, "semibold")
  gfx.color(theme.text)
  local bw = gfx.text(fmtNum(shownBmi, 1), px, ry + 34, 44, "bold")
  -- category pill
  local name = catName(ci)
  local tw = gfx.textWidth(name, 13, "semibold") + 24
  local pillX = min(px + bw + 14, px + pw - tw)
  gfx.rect(pillX, ry + 50, tw, 26, 13, col)
  gfx.color(ci == 3 and "#3A3000" or "#FFFFFF")
  gfx.text(name, pillX, ry + 55, 13, "semibold", "center", tw)
  gfx.color(theme.text3)
  gfx.text(TR("bmi_prime", fmtNum(b / 25, 2)), px, ry + 94, 12)

  drawGauge(px, ry + 128, pw, b)

  -- healthy range and advice
  local m2 = (cm / 100) ^ 2
  local lo, hi = 18.5 * m2, 24.9 * m2
  local yy = ry + 174
  ui.separator(px, yy, px + pw)
  gfx.color(theme.text2)
  gfx.text(TR("healthy_range"), px, yy + 12, 13)
  gfx.color(theme.text)
  gfx.text(weightText(lo) .. " – " .. weightText(hi), px, yy + 11, 14, "semibold", "right", pw)
  local adv, acol
  if b < 18.5 then adv, acol = TR("adv_gain", weightText(lo - kg)), theme.blue
  elseif floor(b * 10 + 0.5) / 10 >= 25 then adv, acol = TR("adv_lose", weightText(kg - hi)), theme.orange
  else adv, acol = TR("adv_ok"), theme.green end
  gfx.icon(b < 18.5 and "trending_up" or (b >= 25 and "trending_down" or "check_circle"), px + 9, yy + 50, 18, acol)
  gfx.color(theme.text)
  gfx.wrap(adv, px + 26, yy + 41, pw - 26, 13)
  gfx.color(theme.text3)
  gfx.wrap(TR("disclaimer"), px, ry + rh - 40, pw, 11)
end

-- ------------------------------------------------------------------ history tab
local function drawChart(x, y, w, h)
  ui.group(x, y, w, h)
  local n = #hist
  local first = max(1, n - 59)        -- last 60 measurements
  local cnt = n - first + 1
  local vmin, vmax = math.huge, -math.huge
  for i = first, n do
    local v = chartMode == 1 and hist[i].b or hist[i].w
    if units == 2 and chartMode == 2 then v = v / KG_PER_LB end
    vmin, vmax = min(vmin, v), max(vmax, v)
  end
  if chartMode == 1 then vmin, vmax = min(vmin, 18), max(vmax, 26) end
  local pad = max(1, (vmax - vmin) * 0.12)
  vmin, vmax = vmin - pad, vmax + pad
  local cx, cy, cw, ch = x + 44, y + 14, w - 60, h - 40
  local function Y(v) return cy + ch - (v - vmin) / (vmax - vmin) * ch end
  -- healthy band
  if chartMode == 1 then
    local y1, y2 = Y(24.9), Y(18.5)
    gfx.rect(cx, y1, cw, y2 - y1, 0, withAlpha(theme.green, 0.14))
    gfx.color(theme.green)
    gfx.text(TR("healthy"), cx + 6, y1 + 3, 10, "semibold")
  end
  gfx.color(theme.separator)
  for k = 0, 3 do
    local gy = cy + ch * k / 3
    gfx.line(cx, gy, cx + cw, gy, 1)
  end
  gfx.color(theme.text3)
  for k = 0, 3 do
    local v = vmax - (vmax - vmin) * k / 3
    gfx.text(fmtNum(v, 1), x + 4, cy + ch * k / 3 - 7, 10, "sans", "right", 34)
  end
  if cnt >= 1 then
    gfx.color(theme.text3)
    gfx.text(dateText(hist[first].d), cx, cy + ch + 6, 10)
    gfx.text(dateText(hist[n].d), cx, cy + ch + 6, 10, "sans", "right", cw)
  end
  -- line, revealed left to right when the tab opens
  gfx.clip(cx - 6, y, (cw + 12) * chartIn, h)
  local step = cnt > 1 and cw / (cnt - 1) or 0
  local px, py
  gfx.color(theme.accent)
  for i = first, n do
    local v = chartMode == 1 and hist[i].b or hist[i].w
    if units == 2 and chartMode == 2 then v = v / KG_PER_LB end
    local xx = cnt > 1 and cx + (i - first) * step or cx + cw / 2
    local yy = Y(v)
    if px then gfx.line(px, py, xx, yy, 2.5) end
    px, py = xx, yy
  end
  for i = first, n do
    local v = chartMode == 1 and hist[i].b or hist[i].w
    if units == 2 and chartMode == 2 then v = v / KG_PER_LB end
    local xx = cnt > 1 and cx + (i - first) * step or cx + cw / 2
    gfx.circle(xx, Y(v), 4, catColor((category(hist[i].b))))
  end
  gfx.unclip()
end

local function drawHistory(w, h)
  local m = 20
  local y = 60
  if #hist == 0 then
    local cx, cy = w / 2, h / 2 - 20
    gfx.circle(cx, cy, 52, withAlpha(theme.accent, 0.12))
    gfx.icon("show_chart", cx, cy, 56, theme.accent)
    gfx.color(theme.text)
    gfx.text(TR("hist_empty"), 0, cy + 66, 16, "semibold", "center", w)
    gfx.color(theme.text2)
    gfx.wrap(TR("hist_empty_body"), w / 2 - 170, cy + 92, 340, 13, "sans", "center")
    if ui.button(TR("go_calc"), w / 2 - 90, cy + 136, 180, 34, "primary", "calculate") then tab = 1 end
    return
  end
  -- toolbar: chart metric, sort, export
  local cm = ui.segmented("chartmode", {TR("bmi"), TR("weight")}, chartMode, m, y, 180, 30)
  if cm ~= chartMode and (cm == 1 or cm == 2) then chartMode = cm; store.set("chart", cm) end
  local sm = ui.dropdown("sort", {TR("sort_new"), TR("sort_old"), TR("sort_high"), TR("sort_low")}, sortMode, w - m - 40 - 8 - 150, y, 150, 30)
  if sm ~= sortMode and sm >= 1 and sm <= 4 then sortMode = sm; store.set("sort", sm) end
  if ui.iconButton("ios_share", w - m - 40, y, 40, 30, theme.accent, false, "export") then exportCsv() end
  y = y + 42
  local chH = clamp(floor((h - y) * 0.42), 110, 220)
  drawChart(m, y, w - 2 * m, chH)
  y = y + chH + 12
  -- list
  local lh = h - y - 12
  local rowH = 44
  local list = sortedView()
  local lw = w - 2 * m
  local sy = ui.beginScroll("hist", m, y, lw, lh, #list * rowH)
  local a = max(1, floor(sy / rowH) + 1)
  local b = min(#list, floor((sy + lh) / rowH) + 1)
  local now = sys.time()
  for k = a, b do
    local idx = list[k]
    local e = hist[idx]
    if e then
      local ry = (k - 1) * rowH
      if k % 2 == 0 then gfx.rect(0, ry, lw, rowH, 8, theme.hover) end
      if flashT == e.t and now - flashAt < 1.5 then
        gfx.rect(0, ry, lw, rowH, 8, withAlpha(theme.accent, 0.25 * (1 - (now - flashAt) / 1.5)))
      end
      local ci = category(e.b)
      gfx.circle(16, ry + rowH / 2, 6, catColor(ci))
      gfx.color(theme.text)
      gfx.text(dateText(e.d), 32, ry + 13, 14, "medium")
      gfx.color(theme.text2)
      gfx.text(weightText(e.w), lw * 0.32, ry + 13, 14)
      gfx.color(theme.text)
      gfx.text(fmtNum(e.b, 1), lw * 0.52, ry + 13, 14, "semibold")
      gfx.color(catColor(ci))
      gfx.text(catName(ci), lw * 0.52 + 46, ry + 14, 12, "medium")
      if ui.iconButton("delete", lw - 40, ry + 6, 34, 32, theme.red, false, "del" .. idx) then deleteEntry(idx) end
    end
  end
  ui.endScroll()
end

-- ------------------------------------------------------------------ frame
local function drawToast(w, h)
  if not toast then return end
  local age = sys.time() - toastAt
  if age > 2.4 then toast = nil; return end
  local a = min(1, age * 6, (2.4 - age) * 3)
  local tw = gfx.textWidth(toast, 13) + 32
  local tx, ty = (w - tw) / 2, h - 60 - (1 - min(1, age * 6)) * 10
  gfx.alpha(a)
  gfx.shadow(tx, ty, tw, 32, 16, 10, 3)
  gfx.rect(tx, ty, tw, 32, 16, theme.dark and "#3A3A3C" or "#1C1C1E")
  gfx.color("#FFFFFF")
  gfx.text(toast, tx, ty + 8, 13, "medium", "center", tw)
  gfx.unalpha()
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local nt = ui.segmented("tabs", {TR("tab_calc"), TR("tab_history")}, tab, w / 2 - 140, 14, 280, 30)
  if nt == 1 or nt == 2 then tab = nt end
  -- slide the active page in from the side it comes from
  local off = (tab - tabAnim) * 40
  gfx.alpha(1 - min(1, abs(tab - tabAnim)) * 0.8)
  gfx.push(off, 0)
  if tab == 1 then drawCalc(w, h) else drawHistory(w, h) end
  gfx.pop()
  gfx.unalpha()
  drawToast(w, h)
end

function app.event(e)
  if e.type ~= "keydown" then return end
  if e.key == "enter" and tab == 1 then saveMeasurement()
  elseif e.key == "pageup" or (e.ctrl and e.key == "1") then tab = 1
  elseif e.key == "pagedown" or (e.ctrl and e.key == "2") then tab = 2
  elseif e.ctrl and e.key == "z" then undoDelete()
  elseif e.ctrl and e.key == "e" then exportCsv()
  elseif e.ctrl and e.key == "u" then setUnits(units == 1 and 2 or 1) end
end

function app.menu()
  return {
    {title = TR("app_name"), items = {
      {label = TR("save_measure"), id = 1, shortcut = "Enter"},
      {label = TR("toggle_units"), id = 2, shortcut = "Ctrl+U"},
      "-",
      {label = TR("tab_calc"), id = 3, shortcut = "Ctrl+1"},
      {label = TR("tab_history"), id = 4, shortcut = "Ctrl+2"},
    }},
    {title = TR("tab_history"), items = {
      {label = TR("export"), id = 5, shortcut = "Ctrl+E"},
      {label = TR("undo_delete"), id = 6, shortcut = "Ctrl+Z"},
      "-",
      {label = TR("clear_all"), id = 7},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then saveMeasurement()
  elseif id == 2 then setUnits(units == 1 and 2 or 1)
  elseif id == 3 then tab = 1
  elseif id == 4 then tab = 2
  elseif id == 5 then exportCsv()
  elseif id == 6 then undoDelete()
  elseif id == 7 and #hist > 0 then
    ui.alert(TR("clear_all"), TR("clear_msg", #hist), {TR("clear"), TR("common.cancel")}, function(b)
      if b == 1 then hist = {}; deleted = nil; saveHist(); audio.play("trash") end
    end)
  end
end

function app.close()
  store.save()
  return true
end

return app
