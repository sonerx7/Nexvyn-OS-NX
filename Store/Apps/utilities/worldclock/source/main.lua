-- World Clock: cities with fixed UTC offsets and simple daylight-saving rules (EU, US, Australia, New Zealand,
-- Egypt), analog mini clocks, a "time travel" slider and a meeting planner (Nexvyn OS Lua SDK).
local app = {}

local CITIES = require("cities")   -- {slug, standard offset in minutes, dst rule, country code}
local BY_SLUG = {}
for _, c in ipairs(CITIES) do BY_SLUG[c[1]] = c end

-- ------------------------------------------------------------------ state
local list = {}          -- added city slugs in custom order
local order = {}         -- display order (rebuilt when list or sort changes)
local dirty = true
local tab = 1            -- 1 clocks, 2 planner
local use24 = true
local sortMode = 1       -- 1 custom, 2 by time, 3 by name
local shiftMin = 0       -- time travel
local editMode = false
local adding = false
local query = ""
local results = {}
local resultsFor = nil
local localOffMin = 0
local lastEpoch, epochAt = 0, 0
local selCol = -1        -- planner: selected local hour
local gridX, gridY, gridW, gridH, cellW = 0, 0, 0, 0, 0
local appear = {}
local msg, msgT = nil, 0
local undoItem, undoT = nil, 0
local NAMES, COUNTRIES = {}, {}
local SORTS = {}

-- ------------------------------------------------------------------ calendar arithmetic
local function daysFromCivil(y, m, d)
  if m <= 2 then y = y - 1 end
  local era = (y >= 0 and y or y - 399) // 400
  local yoe = y - era * 400
  local mp = (m + 9) % 12
  local doy = (153 * mp + 2) // 5 + d - 1
  local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
  return era * 146097 + doe - 719468
end

local function civilFromDays(z)
  z = z + 719468
  local era = (z >= 0 and z or z - 146096) // 146097
  local doe = z - era * 146097
  local yoe = (doe - doe // 1460 + doe // 36524 - doe // 146096) // 365
  local y = yoe + era * 400
  local doy = doe - (365 * yoe + yoe // 4 - yoe // 100)
  local mp = (5 * doy + 2) // 153
  local d = doy - (153 * mp + 2) // 5 + 1
  local m = mp < 10 and mp + 3 or mp - 9
  if m <= 2 then y = y + 1 end
  return y, m, d
end

local function daysInMonth(y, m)
  local dm = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
  if m == 2 and ((y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0) then return 29 end
  return dm[m]
end

local function wday(n) return (n + 4) % 7 end    -- 0 = Sunday
local function lastWeekday(y, m, wd)
  local n = daysFromCivil(y, m, daysInMonth(y, m))
  return n - ((wday(n) - wd) % 7)
end
local function nthSunday(y, m, k)
  local first = daysFromCivil(y, m, 1)
  return first + (7 - wday(first)) % 7 + 7 * (k - 1)
end

-- is daylight saving time active at UTC time t (seconds) for this rule and standard offset (minutes)?
local function dstActive(rule, t, std)
  if rule == "none" then return false end
  if rule == "eu" then                                 -- last Sunday of March/October, 01:00 UTC
    local y = civilFromDays(t // 86400)
    local s = lastWeekday(y, 3, 0) * 86400 + 3600
    local e = lastWeekday(y, 10, 0) * 86400 + 3600
    return t >= s and t < e
  end
  local ls = t + std * 60                              -- local standard time
  local y = civilFromDays(ls // 86400)
  if rule == "us" then                                 -- 2nd Sunday of March 02:00 .. 1st Sunday of November 02:00
    local s = nthSunday(y, 3, 2) * 86400 + 7200
    local e = nthSunday(y, 11, 1) * 86400 + 3600
    return ls >= s and ls < e
  elseif rule == "au" then                             -- 1st Sunday of October .. 1st Sunday of April
    return ls >= nthSunday(y, 10, 1) * 86400 + 7200 or ls < nthSunday(y, 4, 1) * 86400 + 7200
  elseif rule == "nz" then                             -- last Sunday of September .. 1st Sunday of April
    return ls >= lastWeekday(y, 9, 0) * 86400 + 7200 or ls < nthSunday(y, 4, 1) * 86400 + 7200
  elseif rule == "eg" then                             -- last Friday of April .. last Thursday of October
    return ls >= lastWeekday(y, 4, 5) * 86400 and ls < (lastWeekday(y, 10, 4) + 1) * 86400 - 3600
  end
  return false
end

local function cityOffset(c, t)
  local dst = dstActive(c[3], t, c[2])
  return c[2] + (dst and 60 or 0), dst
end

-- ------------------------------------------------------------------ formatting
local MONTHS, WDAYS = {}, {}

local function fmtTime(mins)   -- minutes of the day
  mins = mins % 1440
  local h, m = mins // 60, mins % 60
  if use24 then return string.format("%02d:%02d", h, m) end
  local ap = h < 12 and TR("am") or TR("pm")
  local h12 = h % 12
  if h12 == 0 then h12 = 12 end
  return string.format("%d:%02d %s", h12, m, ap)
end

local function fmtOffset(mins)   -- "UTC+5:30"
  local sign = mins < 0 and "−" or "+"
  mins = math.abs(mins)
  local h, m = mins // 60, mins % 60
  if m == 0 then return "UTC" .. sign .. h end
  return string.format("UTC%s%d:%02d", sign, h, m)
end

local function fmtDiff(mins)
  if mins == 0 then return TR("same_time") end
  local sign = mins < 0 and "−" or "+"
  local a = math.abs(mins)
  local h, m = a // 60, a % 60
  if m == 0 then return TR("diff_h", sign, h) end
  if h == 0 then return TR("diff_m", sign, m) end
  return TR("diff_hm", sign, h, m)
end

local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function fold(s)
  s = s:gsub("İ", "i"):gsub("ı", "i"):gsub("Ç", "ç"):gsub("Ğ", "ğ"):gsub("Ö", "ö"):gsub("Ş", "ş"):gsub("Ü", "ü")
  return s:lower()
end

local function flash(t) msg, msgT = t, 2.5 end
local function ease(t) t = math.max(0, math.min(1, t)); return 1 - (1 - t) ^ 3 end

-- current UTC time in seconds, with a smooth fraction for the second hands, plus the time-travel shift
local function nowT()
  local e = sys.epoch()
  local frac = math.min(0.999, math.max(0, sys.time() - epochAt))
  return e + frac + shiftMin * 60
end

-- ------------------------------------------------------------------ list management
local function save()
  store.set("cities", list)
  dirty = true
end

local function rebuild()
  dirty = false
  for i = #order, 1, -1 do order[i] = nil end
  for _, s in ipairs(list) do if BY_SLUG[s] then order[#order + 1] = s end end
  if sortMode == 2 then
    local t = sys.epoch()
    table.sort(order, function(a, b)
      local oa, ob = cityOffset(BY_SLUG[a], t), cityOffset(BY_SLUG[b], t)
      if oa ~= ob then return oa < ob end
      return (NAMES[a] or a) < (NAMES[b] or b)
    end)
  elseif sortMode == 3 then
    table.sort(order, function(a, b) return fold(NAMES[a] or a) < fold(NAMES[b] or b) end)
  end
end

local function hasCity(slug)
  for _, s in ipairs(list) do if s == slug then return true end end
  return false
end

local function addCity(slug)
  if hasCity(slug) or not BY_SLUG[slug] then return end
  list[#list + 1] = slug
  appear[slug] = 0
  save()
  flash(TR("added", NAMES[slug] or slug))
  audio.tone(784, 0.07, 0.2, "sine"); audio.tone(1175, 0.1, 0.12, "sine")
end

local function removeCity(slug)
  for i, s in ipairs(list) do
    if s == slug then
      table.remove(list, i)
      undoItem, undoT = {slug = slug, i = i}, 6
      break
    end
  end
  save()
  audio.play("trash")
end

local function undo()
  if not undoItem then return end
  if not hasCity(undoItem.slug) then
    table.insert(list, math.min(undoItem.i, #list + 1), undoItem.slug)
    appear[undoItem.slug] = 0
  end
  undoItem, undoT = nil, 0
  save()
  audio.play("pop")
end

local function move(slug, dir)
  for i, s in ipairs(list) do
    if s == slug then
      local j = i + dir
      if j >= 1 and j <= #list then list[i], list[j] = list[j], list[i]; save(); audio.play("click") end
      return
    end
  end
end

local function searchCities()
  resultsFor = query
  for i = #results, 1, -1 do results[i] = nil end
  local q = fold(trim(query))
  for _, c in ipairs(CITIES) do
    if not hasCity(c[1]) then
      local name, country = NAMES[c[1]] or c[1], COUNTRIES[c[4]] or c[4]
      if q == "" or fold(name):find(q, 1, true) or fold(country):find(q, 1, true) then results[#results + 1] = c end
    end
  end
  table.sort(results, function(a, b) return fold(NAMES[a[1]] or a[1]) < fold(NAMES[b[1]] or b[1]) end)
end

-- ------------------------------------------------------------------ lifecycle
local function updateLocal()
  local d = sys.date()
  local localSec = daysFromCivil(d.year, d.month, d.day) * 86400 + d.hour * 3600 + d.min * 60 + d.sec
  local off = (localSec - sys.epoch()) / 60
  localOffMin = math.floor(off / 15 + 0.5) * 15
end

function app.load()
  MONTHS = {TR("jan"), TR("feb"), TR("mar"), TR("apr"), TR("may"), TR("jun"), TR("jul"), TR("aug"), TR("sep"),
            TR("oct"), TR("nov"), TR("dec")}
  WDAYS = {TR("sun"), TR("mon"), TR("tue"), TR("wed"), TR("thu"), TR("fri"), TR("sat")}
  SORTS = {TR("sort_custom"), TR("sort_time"), TR("sort_name")}
  for _, c in ipairs(CITIES) do
    local nameKey, countryKey = "c_" .. c[1], "co_" .. c[4]   -- generated keys (cities.lua + lang files)
    NAMES[c[1]] = TR(nameKey)
    COUNTRIES[c[4]] = TR(countryKey)
  end
  local saved = store.get("cities", nil)
  if type(saved) == "table" then
    for _, s in ipairs(saved) do if BY_SLUG[s] and not hasCity(s) then list[#list + 1] = s end end
  else
    list = {"london", "newyork", "tokyo", "sydney"}
  end
  use24 = store.get("use24", sys.lang() ~= "en")
  sortMode = store.get("sort", 1)
  if not SORTS[sortMode] then sortMode = 1 end
  tab = store.get("tab", 1)
  if tab ~= 1 and tab ~= 2 then tab = 1 end
  updateLocal()
  lastEpoch, epochAt = sys.epoch(), sys.time()
end

function app.update(dt)
  local e = sys.epoch()
  if e ~= lastEpoch then
    lastEpoch, epochAt = e, sys.time()
    if e % 30 == 0 then updateLocal() end
  end
  if msgT > 0 then msgT = msgT - dt end
  if undoT > 0 then undoT = undoT - dt; if undoT <= 0 then undoItem = nil end end
  for k, v in pairs(appear) do
    v = v + dt * 3.5
    if v >= 1 then appear[k] = nil else appear[k] = v end
  end
  if dirty then rebuild() end
  if adding and resultsFor ~= query then searchCities() end
end

-- ------------------------------------------------------------------ drawing
local function analog(cx, cy, r, secOfDay, day)
  local night = not day
  gfx.circle(cx, cy, r, night and "#1C2333" or "#FFFFFF")
  gfx.color(night and "#3A4560" or "#D8DCE3")
  gfx.circleLine(cx, cy, r, 1.5)
  for i = 0, 11 do
    local a = i * math.pi / 6
    local inner = (i % 3 == 0) and r * 0.74 or r * 0.83
    gfx.color(night and "#8A96B3" or "#7A8290")
    gfx.line(cx + math.cos(a) * inner, cy + math.sin(a) * inner, cx + math.cos(a) * r * 0.92, cy + math.sin(a) * r * 0.92,
             i % 3 == 0 and 2 or 1)
  end
  local s = secOfDay % 60
  local m = (secOfDay / 60) % 60
  local h = (secOfDay / 3600) % 12
  local hand = night and "#E8ECF5" or "#1C1C1E"
  local ah = h / 12 * math.pi * 2 - math.pi / 2
  local am = m / 60 * math.pi * 2 - math.pi / 2
  local as = s / 60 * math.pi * 2 - math.pi / 2
  gfx.color(hand)
  gfx.line(cx, cy, cx + math.cos(ah) * r * 0.5, cy + math.sin(ah) * r * 0.5, 3.5)
  gfx.line(cx, cy, cx + math.cos(am) * r * 0.75, cy + math.sin(am) * r * 0.75, 2.2)
  gfx.color("#FF3B30")
  gfx.line(cx - math.cos(as) * r * 0.15, cy - math.sin(as) * r * 0.15, cx + math.cos(as) * r * 0.82, cy + math.sin(as) * r * 0.82, 1.2)
  gfx.circle(cx, cy, 3, "#FF3B30")
end

local function emptyState(x, y, w, h)
  local cy = y + h / 2 - 60
  local bob = math.sin(sys.time() * 2) * 3
  gfx.circle(x + w / 2, cy + bob, 42, theme.hover)
  gfx.icon("public", x + w / 2, cy + bob, 48, theme.text3)
  gfx.color(theme.text)
  gfx.text(TR("empty"), x, cy + 56, 16, "semibold", "center", w)
  gfx.color(theme.text2)
  gfx.text(TR("empty_sub"), x, cy + 80, 13, "sans", "center", w)
  if ui.button(TR("add_city"), x + w / 2 - 100, cy + 110, 200, 34, "primary", "add_location") then adding = true; query = ""; resultsFor = nil end
end

local function drawCard(slug, x, y, w, h, t, i)
  local c = BY_SLUG[slug]
  local off, dst = cityOffset(c, t)
  local lt = t + off * 60
  local day = math.floor(lt // 86400)
  local sod = lt - day * 86400
  local hour = sod / 3600
  local isDay = hour >= 7 and hour < 19
  local localDay = math.floor((t + localOffMin * 60) // 86400)
  local a = appear[slug]
  if a then gfx.alpha(ease(a)); y = y + (1 - ease(a)) * 20 end
  gfx.shadow(x, y, w, h, 14, 10, 3)
  if isDay then gfx.gradient(x, y, w, h, theme.dark and "#2B3A55" or "#EAF3FF", theme.dark and "#1F2A40" or "#FFFFFF", false, 14)
  else gfx.gradient(x, y, w, h, "#141B2D", "#22304D", false, 14) end
  local tc = isDay and theme.text or "#F2F4F8"
  local t2 = isDay and theme.text2 or "#A9B4CC"
  local r = math.min(42, h / 2 - 12)
  analog(x + 14 + r, y + h / 2, r, sod, isDay)
  local tx = x + 28 + r * 2
  local tw = w - (tx - x) - 12
  gfx.clip(tx, y, math.max(1, tw), h)
  gfx.color(tc)
  gfx.text(NAMES[slug] or slug, tx, y + 12, 16, "bold")
  gfx.color(t2)
  gfx.text(COUNTRIES[c[4]] or "", tx, y + 32, 12)
  gfx.color(tc)
  local dw = gfx.text(fmtTime(math.floor(sod / 60)), tx, y + 50, 26, "semibold")
  gfx.icon(isDay and "wb_sunny" or "bedtime", tx + dw + 16, y + 66, 18, isDay and "#FF9F0A" or "#9DB2FF")
  gfx.color(t2)
  local dd = day - localDay
  local rel = dd == 0 and TR("today") or (dd == 1 and TR("tomorrow") or (dd == -1 and TR("yesterday") or WDAYS[wday(day) + 1]))
  gfx.text(rel .. " · " .. fmtDiff(off - localOffMin), tx, y + h - 26, 12)
  gfx.unclip()
  if dst then
    local bw = gfx.textWidth(TR("dst"), 10, "bold") + 12
    gfx.rect(x + w - bw - 10, y + 10, bw, 18, 9, isDay and "#FF9F0A33" or "#FF9F0A55")
    gfx.color("#FF9F0A")
    gfx.text(TR("dst"), x + w - bw - 10, y + 12, 10, "bold", "center", bw)
  end
  if editMode then
    local bx = x + w - 120
    if ui.iconButton("arrow_upward", bx, y + h - 40, 34, 32, tc, false, "up" .. slug) then move(slug, -1) end
    if ui.iconButton("arrow_downward", bx + 38, y + h - 40, 34, 32, tc, false, "dn" .. slug) then move(slug, 1) end
    if ui.iconButton("delete", bx + 76, y + h - 40, 34, 32, "#FF453A", false, "rm" .. slug) then removeCity(slug) end
  else
    local hit = ui.hit("card" .. slug, x, y, w, h)
    if hit.rightClicked then
      ui.contextMenu({{label = TR("move_up"), id = 1, icon = "arrow_upward"}, {label = TR("move_down"), id = 2, icon = "arrow_downward"},
                      "-", {label = TR("remove"), id = 3, icon = "delete"}}, function(id)
        if id == 1 then move(slug, -1) elseif id == 2 then move(slug, 1) elseif id == 3 then removeCity(slug) end
      end)
    end
  end
  if a then gfx.unalpha() end
end

local function drawClocks(x, y, w, h, t)
  if #order == 0 then emptyState(x, y, w, h - y); return end
  local cols = math.max(1, math.floor((w + 12) / 290))
  local cw = (w - (cols - 1) * 12) / cols
  local ch = 112
  local rows = math.ceil(#order / cols)
  ui.beginScroll("cards", x - 6, y, w + 12, h - y - 6, rows * (ch + 12) + 12)
  for i, slug in ipairs(order) do
    local cx = 6 + ((i - 1) % cols) * (cw + 12)
    local cy = 6 + ((i - 1) // cols) * (ch + 12)
    drawCard(slug, cx, cy, cw, ch, t, i)
  end
  ui.endScroll()
end

local function hourColor(hh)
  if hh >= 9 and hh < 18 then return theme.green, true end
  if (hh >= 7 and hh < 9) or (hh >= 18 and hh < 22) then return theme.yellow, false end
  return theme.dark and "#2C3550" or "#AEB8D0", false
end

local overlap = {}

local function drawPlanner(x, y, w, h, t)
  if #order == 0 then emptyState(x, y, w, h - y); return end
  local labelW = math.min(170, w * 0.26)
  cellW = (w - labelW) / 24
  local rowH = math.max(26, math.min(38, (h - y - 140) / (#order + 1)))
  gridX, gridY, gridW = x + labelW, y, cellW * 24
  local nowLocalMin = math.floor(((t + localOffMin * 60) % 86400) / 60)
  local nowCol = nowLocalMin // 60
  if selCol < 0 then selCol = nowCol end
  -- header: your local hours
  gfx.color(theme.text2)
  gfx.text(TR("your_time"), x, y + 6, 12, "semibold")
  local step = cellW < 22 and 3 or (cellW < 30 and 2 or 1)
  for col = 0, 23 do
    if col % step == 0 then
      gfx.color(col == nowCol and theme.accent or theme.text2)
      gfx.text(tostring(col), gridX + col * cellW, y + 6, 11, col == nowCol and "bold" or "sans", "center", cellW)
    end
  end
  -- which local hours are working hours everywhere?
  for col = 0, 23 do overlap[col] = true end
  for _, slug in ipairs(order) do
    local off = cityOffset(BY_SLUG[slug], t)
    for col = 0, 23 do
      local hh = ((col * 60 + off - localOffMin) % 1440) // 60
      if not (hh >= 9 and hh < 18) then overlap[col] = false end
    end
  end
  local gy = y + 26
  gridH = (#order) * rowH
  -- selected column and the "now" column
  gfx.alpha(0.22)
  gfx.rect(gridX + selCol * cellW, gy - 4, cellW, gridH + 8, 6, theme.accent)
  gfx.unalpha()
  for i, slug in ipairs(order) do
    local c = BY_SLUG[slug]
    local off = cityOffset(c, t)
    local ry = gy + (i - 1) * rowH
    gfx.color(theme.text)
    gfx.clip(x, ry, labelW - 8, rowH)
    gfx.text(NAMES[slug] or slug, x, ry + rowH / 2 - 9, 13, "semibold")
    gfx.unclip()
    for col = 0, 23 do
      local m = (col * 60 + off - localOffMin) % 1440
      local hh = m // 60
      local colr = hourColor(hh)
      gfx.rect(gridX + col * cellW + 1, ry + 2, cellW - 2, rowH - 4, 4, colr)
      if cellW >= 26 then
        gfx.color(hh >= 7 and hh < 22 and "#1C1C1E" or "#E8ECF5")
        local label = m % 60 == 0 and tostring(hh) or (hh .. "½")
        gfx.text(label, gridX + col * cellW, ry + rowH / 2 - 7, 11, "semibold", "center", cellW)
      end
    end
  end
  gfx.color(theme.accent)
  gfx.rectLine(gridX + nowCol * cellW, gy - 4, cellW, gridH + 8, 6, 2)
  for col = 0, 23 do
    if overlap[col] then gfx.icon("star", gridX + col * cellW + cellW / 2, gy + gridH + 14, 14, theme.orange) end
  end
  -- legend + summary
  local ly = gy + gridH + 30
  local lx = x
  local legend = {{theme.green, TR("lg_work")}, {theme.yellow, TR("lg_edge")}, {hourColor(3), TR("lg_night")}}
  for _, l in ipairs(legend) do
    gfx.rect(lx, ly + 2, 14, 14, 4, l[1])
    gfx.color(theme.text2)
    lx = lx + 22 + gfx.text(l[2], lx + 20, ly + 1, 12) + 14
  end
  gfx.icon("star", lx + 7, ly + 9, 14, theme.orange)
  gfx.color(theme.text2)
  gfx.text(TR("lg_overlap"), lx + 18, ly + 1, 12)
  ly = ly + 30
  gfx.color(theme.text)
  gfx.text(TR("at_time", fmtTime(selCol * 60)), x, ly, 15, "bold")
  ly = ly + 24
  local chipX = x
  for _, slug in ipairs(order) do
    local off = cityOffset(BY_SLUG[slug], t)
    local m = (selCol * 60 + off - localOffMin) % 1440
    local s = (NAMES[slug] or slug) .. "  " .. fmtTime(m)
    local cw2 = gfx.textWidth(s, 13, "semibold") + 20
    if chipX + cw2 > x + w then chipX = x; ly = ly + 32 end
    local col = hourColor(m // 60)
    gfx.rect(chipX, ly, cw2, 26, 13, theme.hover)
    gfx.circle(chipX + 10, ly + 13, 4, col)
    gfx.color(theme.text)
    gfx.text(s, chipX + 6, ly + 5, 13, "semibold", "center", cw2)
    chipX = chipX + cw2 + 8
  end
  ly = ly + 36
  -- best overlap range
  local best, bestLen, run, runStart = -1, 0, 0, 0
  for col = 0, 24 do
    if col < 24 and overlap[col] then
      if run == 0 then runStart = col end
      run = run + 1
    else
      if run > bestLen then best, bestLen = runStart, run end
      run = 0
    end
  end
  gfx.color(bestLen > 0 and theme.green or theme.text2)
  if bestLen > 0 then
    gfx.text(TR("best_overlap", fmtTime(best * 60), fmtTime((best + bestLen) * 60)), x, ly, 13, "semibold")
  else
    gfx.text(TR("no_overlap"), x, ly, 13)
  end
end

local function drawAdd(w, h)
  if ui.button(TR("back"), 16, 12, 110, 32, "default", "arrow_back") then adding = false; return end
  gfx.color(theme.text)
  gfx.text(TR("add_city"), 140, 16, 20, "bold")
  local q = ui.textfield("search", query, 16, 54, w - 32, 34, TR("search_ph"), "search")
  query = q
  if resultsFor ~= query then searchCities() end
  local y = 98
  if #results == 0 then
    gfx.icon("search", w / 2, y + 80, 44, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("no_results"), 0, y + 116, 14, "semibold", "center", w)
    return
  end
  local t = sys.epoch()
  local rowH = 50
  ui.beginScroll("results", 16, y, w - 32, h - y - 8, #results * rowH)
  for i, c in ipairs(results) do
    local ry = (i - 1) * rowH
    if ui.row("res" .. c[1], 0, ry, w - 32, rowH - 4, false) then addCity(c[1]); adding = false end
    local off, dst = cityOffset(c, t)
    gfx.color(theme.text)
    gfx.text(NAMES[c[1]] or c[1], 14, ry + 6, 15, "semibold")
    gfx.color(theme.text2)
    gfx.text((COUNTRIES[c[4]] or "") .. " · " .. fmtOffset(off) .. (dst and (" · " .. TR("dst")) or ""), 14, ry + 26, 12)
    gfx.color(theme.text)
    local lt = (t + off * 60) % 86400
    gfx.text(fmtTime(math.floor(lt / 60)), 0, ry + 13, 16, "semibold", "right", w - 80)
    gfx.icon("add_circle", w - 54, ry + rowH / 2 - 2, 22, theme.accent)
  end
  ui.endScroll()
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  if dirty then rebuild() end
  if adding then
    drawAdd(w, h)
  else
    local t = nowT()
    -- header: local time
    local lt = t + localOffMin * 60
    local day = math.floor(lt // 86400)
    local sod = lt - day * 86400
    local y0, mo, d = civilFromDays(day)
    gfx.color(shiftMin ~= 0 and theme.orange or theme.text)
    local tw = gfx.text(fmtTime(math.floor(sod / 60)), 20, 10, 38, "bold")
    gfx.color(theme.text2)
    gfx.text(string.format(":%02d", math.floor(sod % 60)), 24 + tw, 30, 16, "semibold")
    gfx.text(TR("local_line", WDAYS[wday(day) + 1], d, MONTHS[mo], y0, fmtOffset(localOffMin)), 20, 56, 13)
    local segW = math.min(260, w * 0.36)
    local nt = ui.segmented("tab", {TR("tab_clocks"), TR("tab_planner")}, tab, w - segW - 16, 14, segW, 32)
    if nt ~= tab then tab = nt; store.set("tab", tab); audio.play("click") end
    -- time travel
    local sy = 84
    gfx.color(theme.text2)
    gfx.icon("more_time", 30, sy + 14, 20, shiftMin ~= 0 and theme.orange or theme.text2)
    local label = shiftMin == 0 and TR("now") or fmtDiff(shiftMin)
    gfx.color(shiftMin ~= 0 and theme.orange or theme.text2)
    gfx.text(label, 46, sy + 6, 13, "semibold")
    local sx = 150
    local sw = w - sx - 140
    local ns = ui.slider("shift", shiftMin, -720, 720, sx, sy + 2, math.max(80, sw), 15)
    ns = math.floor(ns / 15 + 0.5) * 15
    if ns ~= shiftMin then shiftMin = ns end
    if ui.button(TR("reset_now"), w - 126, sy, 110, 30, "default", "schedule", shiftMin ~= 0) then shiftMin = 0 end
    -- toolbar
    local by = 124
    if ui.button(TR("add_city"), 16, by, 150, 32, "primary", "add_location") then adding = true; query = ""; resultsFor = nil end
    if tab == 1 and ui.button(editMode and TR("done") or TR("edit"), 172, by, 100, 32, editMode and "primary" or "default",
                              editMode and "check" or "edit") then editMode = not editMode end
    local dw = math.min(180, (w - 470))
    if dw >= 120 then
      local s = ui.dropdown("sort", SORTS, sortMode, w - dw - 110, by, dw, 32)
      if s ~= sortMode then sortMode = s; store.set("sort", s); dirty = true end
    end
    local f24 = ui.segmented("fmt", {"24h", "12h"}, use24 and 1 or 2, w - 102, by, 86, 32)
    if (f24 == 1) ~= use24 then use24 = f24 == 1; store.set("use24", use24) end
    if tab == 1 then drawClocks(16, by + 44, w - 32, h, t) else drawPlanner(16, by + 48, w - 32, h, t) end
  end
  -- toasts
  if undoItem and undoT > 0 then
    local text = TR("removed", NAMES[undoItem.slug] or undoItem.slug)
    local tw = gfx.textWidth(text, 13, "semibold") + 140
    local tx, ty = (w - tw) / 2, h - 58
    gfx.alpha(math.min(1, undoT * 2))
    gfx.shadow(tx, ty, tw, 40, 20, 12, 4)
    gfx.rect(tx, ty, tw, 40, 20, theme.dark and "#3A3A3C" or "#1C1C1E")
    gfx.color("#FFFFFF")
    gfx.text(text, tx + 16, ty + 12, 13, "semibold")
    if ui.button(TR("undo"), tx + tw - 108, ty + 5, 96, 30, "primary", "undo") then undo() end
    gfx.unalpha()
  elseif msg and msgT > 0 then
    local tw = gfx.textWidth(msg, 13, "semibold") + 32
    gfx.alpha(math.min(1, msgT * 2))
    gfx.rect((w - tw) / 2, h - 52, tw, 32, 16, theme.dark and "#3A3A3C" or "#1C1C1E")
    gfx.color("#FFFFFF")
    gfx.text(msg, (w - tw) / 2, h - 44, 13, "semibold", "center", tw)
    gfx.unalpha()
  end
end

function app.event(e)
  if e.type == "mousedown" and tab == 2 and not adding and cellW > 0 then
    if e.x >= gridX and e.x < gridX + gridW and e.y >= gridY and e.y < gridY + gridH + 40 then
      selCol = math.max(0, math.min(23, math.floor((e.x - gridX) / cellW)))
      audio.play("click")
    end
    return
  end
  if e.type ~= "keydown" then return end
  if e.ctrl and e.key == "z" then undo(); return end
  if adding then
    if e.key == "escape" then adding = false
    elseif e.key == "enter" and results[1] then addCity(results[1][1]); adding = false end
    return
  end
  if e.ctrl and e.key == "n" then adding = true; query = ""; resultsFor = nil
  elseif tab == 2 and e.key == "left" then selCol = (math.max(0, selCol) - 1) % 24
  elseif tab == 2 and e.key == "right" then selCol = (math.max(0, selCol) + 1) % 24
  elseif tab == 1 and e.key == "left" then shiftMin = math.max(-720, shiftMin - 60)
  elseif tab == 1 and e.key == "right" then shiftMin = math.min(720, shiftMin + 60)
  elseif e.key == "home" or e.key == "escape" then shiftMin = 0; editMode = false
  elseif e.key == "tab" then tab = tab % 2 + 1; store.set("tab", tab)
  end
end

function app.menu()
  return {
    {title = TR("menu_clock"), items = {
      {label = TR("add_city"), id = 1, shortcut = "Ctrl+N"},
      {label = TR("edit"), id = 2},
      {label = TR("undo"), id = 3, shortcut = "Ctrl+Z"},
      "-",
      {label = TR("reset_now"), id = 4, shortcut = "Home"},
      {label = TR("toggle_24"), id = 5},
    }},
    {title = TR("menu_view"), items = {
      {label = TR("tab_clocks"), id = 10}, {label = TR("tab_planner"), id = 11},
      "-",
      {label = TR("sort_custom"), id = 12}, {label = TR("sort_time"), id = 13}, {label = TR("sort_name"), id = 14},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then adding = true; query = ""; resultsFor = nil
  elseif id == 2 then adding = false; tab = 1; editMode = not editMode
  elseif id == 3 then undo()
  elseif id == 4 then shiftMin = 0
  elseif id == 5 then use24 = not use24; store.set("use24", use24)
  elseif id == 10 or id == 11 then adding = false; tab = id - 9; store.set("tab", tab)
  elseif id >= 12 and id <= 14 then sortMode = id - 11; store.set("sort", sortMode); dirty = true end
end

function app.close()
  store.save()
  return true
end

return app
