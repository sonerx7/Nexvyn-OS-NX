-- Fuel Calculator: consumption per 100 km, trip cost (with passengers and CO2) and a fill-up log with a chart
-- (Nexvyn OS Lua SDK).
local app = {}

-- ------------------------------------------------------------------ state
local tab = 1
local f = {km = "", liters = "", price = "", tripKm = "", tripCons = "", tripPrice = ""}
local passengers, roundTrip, fuelType = 1, false, 1
local log = {}           -- {id, day, km, liters, price (per litre, 0 = unknown)}
local nextId = 1
local cur = 1
local sortMode = 1       -- 1 newest, 2 oldest, 3 most efficient, 4 least efficient
local sorted = {}
local dirty = true
local stats = {n = 0, km = 0, liters = 0, cost = 0, avg = 0, best = 0, worst = 0}
local msg, msgT = nil, 0
local undoEntry, undoT = nil, 0
local appear = {}
local today = 0
local lang = "en"
local MONTHS = {}
local shown = {cons = 0, needle = 0, tripCost = 0}   -- animated values
local SORTS = {}

local CURRENCIES = {"₺", "$", "€", "£"}
local CO2 = {2.31, 2.68, 1.51}   -- kg CO2 per litre: petrol, diesel, LPG

-- ------------------------------------------------------------------ helpers
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

local function dateLabel(n)
  local y, m, d = civilFromDays(n)
  return d .. " " .. (MONTHS[m] or "") .. " " .. y
end

local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- "12,5" / "12.5" / "1.234,5" -> number or nil
local function num(s)
  s = trim(s):gsub("%s", "")
  if s == "" then return nil end
  local d, c = s:find("%.[^%.]*$"), s:find(",[^,]*$")
  if d and c then
    if c > d then s = s:gsub("%.", ""):gsub(",", ".") else s = s:gsub(",", "") end
  elseif c then s = s:gsub(",", ".") end
  if not s:match("^%d*%.?%d*$") then return nil end
  return tonumber(s)
end

local function fmtN(v, dec)
  local s = string.format("%." .. (dec or 2) .. "f", v)
  local int, frac = s:match("^(%-?%d+)%.?(%d*)$")
  if not int then return s end
  local ts, ds = ",", "."
  if lang == "tr" then ts, ds = ".", "," end
  local neg = int:sub(1, 1) == "-"
  if neg then int = int:sub(2) end
  int = int:reverse():gsub("(%d%d%d)", "%1" .. ts):reverse()
  if int:sub(1, 1) == ts then int = int:sub(2) end
  return (neg and "-" or "") .. int .. (frac ~= "" and (ds .. frac) or "")
end

local function money(v)
  local sym = CURRENCIES[cur] or "₺"
  if lang == "tr" then return fmtN(v, 2) .. " " .. sym end
  return sym .. fmtN(v, 2)
end

local function flash(t) msg, msgT = t, 2.5 end

local function ease(t) t = math.max(0, math.min(1, t)); return 1 - (1 - t) ^ 3 end

local function save()
  store.set("log", log)
  store.set("nextId", nextId)
  dirty = true
end

local function saveFields()
  store.set("fields", f)
  store.set("passengers", passengers)
  store.set("roundTrip", roundTrip)
  store.set("fuelType", fuelType)
end

-- validation: returns value or nil, error text
local function check(s, min, max, required)
  local v = num(s)
  if trim(s) == "" then return nil, required and "" or nil end
  if not v then return nil, TR("err_number") end
  if v < min then return nil, TR("err_min", fmtN(min, min < 1 and 1 or 0)) end
  if v > max then return nil, TR("err_max", fmtN(max, 0)) end
  return v
end

-- ------------------------------------------------------------------ log
local function rebuild()
  dirty = false
  local n = 0
  local km, l, cost = 0, 0, 0
  local best, worst = math.huge, 0
  for _, e in ipairs(log) do
    n = n + 1
    sorted[n] = e
    km, l = km + e.km, l + e.liters
    cost = cost + e.liters * (e.price or 0)
    local c = e.liters / e.km * 100
    if c < best then best = c end
    if c > worst then worst = c end
  end
  for i = #sorted, n + 1, -1 do sorted[i] = nil end
  table.sort(sorted, function(a, b)
    if sortMode == 2 then if a.day ~= b.day then return a.day < b.day end return a.id < b.id end
    local ca, cb = a.liters / a.km, b.liters / b.km
    if sortMode == 3 and ca ~= cb then return ca < cb end
    if sortMode == 4 and ca ~= cb then return ca > cb end
    if a.day ~= b.day then return a.day > b.day end
    return a.id > b.id
  end)
  stats.n, stats.km, stats.liters, stats.cost = n, km, l, cost
  stats.avg = km > 0 and l / km * 100 or 0
  stats.best, stats.worst = n > 0 and best or 0, worst
end

local function addEntry(km, liters, price)
  local e = {id = nextId, day = today, km = km, liters = liters, price = price or 0}
  nextId = nextId + 1
  log[#log + 1] = e
  appear[e.id] = 0
  save()
  flash(TR("logged"))
  audio.tone(523, 0.08, 0.2, "triangle"); audio.tone(659, 0.08, 0.15, "triangle")
  timer.after(0.09, function() audio.tone(784, 0.14, 0.2, "sine") end)
end

local function removeEntry(e)
  for i, x in ipairs(log) do
    if x == e then table.remove(log, i); undoEntry = {e = e, i = i}; undoT = 6 break end
  end
  save()
  audio.play("trash")
end

local function undo()
  if not undoEntry then return end
  table.insert(log, math.min(undoEntry.i, #log + 1), undoEntry.e)
  appear[undoEntry.e.id] = 0
  undoEntry, undoT = nil, 0
  save()
  audio.play("pop")
end

local function exportCsv()
  if #log == 0 then flash(TR("nothing")); return end
  ui.saveFile(function(path)
    if not path then return end
    local out = {"date,km,litres,price_per_litre,l_per_100km,cost"}
    local list = {}
    for i, e in ipairs(log) do list[i] = e end
    table.sort(list, function(a, b) return a.day < b.day end)
    for _, e in ipairs(list) do
      local y, m, d = civilFromDays(e.day)
      out[#out + 1] = string.format("%04d-%02d-%02d,%.1f,%.2f,%.3f,%.2f,%.2f", y, m, d, e.km, e.liters, e.price or 0,
                                    e.liters / e.km * 100, e.liters * (e.price or 0))
    end
    if fs.write(path, table.concat(out, "\n") .. "\n") then flash(TR("exported")) else flash(TR("export_fail")) end
  end, "fuel-log.csv", TR("export"))
end

local function clearLog()
  if #log == 0 then return end
  ui.alert(TR("clear_log"), TR("clear_log_msg", #log), {TR("delete"), TR("common.cancel")}, function(b)
    if b == 1 then log = {}; save(); audio.play("trash") end
  end)
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  lang = sys.lang()
  MONTHS = {TR("jan"), TR("feb"), TR("mar"), TR("apr"), TR("may"), TR("jun"), TR("jul"), TR("aug"), TR("sep"),
            TR("oct"), TR("nov"), TR("dec")}
  SORTS = {TR("sort_new"), TR("sort_old"), TR("sort_best"), TR("sort_worst")}
  local d = sys.date()
  today = daysFromCivil(d.year, d.month, d.day)
  log = store.get("log", {})
  if type(log) ~= "table" then log = {} end
  for i = #log, 1, -1 do
    local e = log[i]
    if type(e) ~= "table" or type(e.km) ~= "number" or e.km <= 0 or type(e.liters) ~= "number" or e.liters <= 0 then
      table.remove(log, i)
    end
  end
  nextId = store.get("nextId", 1)
  for _, e in ipairs(log) do if (e.id or 0) >= nextId then nextId = e.id + 1 end end
  local sf = store.get("fields", nil)
  if type(sf) == "table" then for k in pairs(f) do if type(sf[k]) == "string" then f[k] = sf[k] end end end
  passengers = store.get("passengers", 1)
  roundTrip = store.get("roundTrip", false)
  fuelType = store.get("fuelType", 1)
  if not CO2[fuelType] then fuelType = 1 end
  cur = store.get("cur", lang == "tr" and 1 or 2)
  if not CURRENCIES[cur] then cur = 1 end
  sortMode = store.get("sort", 1)
  if not SORTS[sortMode] then sortMode = 1 end
  tab = store.get("tab", 1)
  if tab < 1 or tab > 3 then tab = 1 end
end

function app.update(dt)
  if msgT > 0 then msgT = msgT - dt end
  if undoT > 0 then undoT = undoT - dt; if undoT <= 0 then undoEntry = nil end end
  for id, v in pairs(appear) do
    v = v + dt * 4
    if v >= 1 then appear[id] = nil else appear[id] = v end
  end
  if dirty then rebuild() end
end

-- ------------------------------------------------------------------ widgets
local function field(id, label, unit, x, y, w, minV, maxV, required)
  gfx.color(theme.text2)
  gfx.text(label, x, y, 12, "semibold")
  local v = f[id]
  local nv = ui.textfield(id, v, x, y + 18, w - 50, 34, "0", "numeric")
  if nv ~= v then f[id] = nv; saveFields() end
  gfx.color(theme.text3)
  gfx.text(unit, x + w - 44, y + 26, 13, "semibold")
  local val, err = check(f[id], minV, maxV, required)
  if err and err ~= "" then
    gfx.color(theme.red)
    gfx.text(err, x, y + 55, 11)
  end
  return val
end

local function smooth(key, target, dt)
  local v = shown[key] or 0
  v = v + (target - v) * (1 - 0.0008 ^ (dt or 1 / 60))
  if math.abs(v - target) < 0.001 then v = target end
  shown[key] = v
  return v
end

-- semicircle gauge: green (frugal) to red (thirsty)
local function gauge(cx, cy, r, value)
  local segs = {{3, theme.green}, {6, theme.green}, {8, theme.yellow}, {11, theme.orange}, {16, theme.red}}
  local lo, hi = 2, 16
  local a0 = math.pi
  for _, s in ipairs(segs) do
    local a1 = math.pi + (s[1] - lo) / (hi - lo) * math.pi
    gfx.color(s[2])
    if a1 > a0 then gfx.arc(cx, cy, r, a0 + 0.02, a1 - 0.02, 10) end
    a0 = a1
  end
  local t = math.max(0, math.min(1, (value - lo) / (hi - lo)))
  local a = math.pi + t * math.pi
  gfx.color(theme.text)
  gfx.line(cx, cy, cx + math.cos(a) * (r - 16), cy + math.sin(a) * (r - 16), 3)
  gfx.circle(cx, cy, 6, theme.text)
end

-- ------------------------------------------------------------------ tabs
local function drawConsumption(x, y, w, h, dt)
  local wide = w >= 620
  local fw = wide and (w - 24) / 2 - 10 or w
  local km = field("km", TR("distance"), "km", x, y, fw, 1, 100000, true)
  local liters = field("liters", TR("fuel_used"), "L", x, y + 74, fw, 0.1, 10000, true)
  local price = field("price", TR("price_l"), CURRENCIES[cur], x, y + 148, fw, 0.01, 1000, false)
  local rx = wide and x + fw + 30 or x
  local ry = wide and y or y + 228
  local rw = wide and w - fw - 30 or w
  local cons = (km and liters) and liters / km * 100 or nil
  local sc = smooth("cons", cons or 0, dt)
  ui.group(rx, ry, rw, 280)
  local gr = math.min(90, rw * 0.28)
  gauge(rx + rw / 2, ry + 26 + gr, gr, smooth("needle", cons or 2, dt))
  gfx.color(cons and theme.text or theme.text3)
  gfx.text(cons and fmtN(sc, 2) or "—", rx, ry + gr + 36, 30, "bold", "center", rw)
  gfx.color(theme.text2)
  gfx.text(TR("l_per_100"), rx, ry + gr + 72, 12, "semibold", "center", rw)
  local rows = {
    {TR("km_per_l"), cons and fmtN(km / liters, 2) or "—"},
    {TR("mpg"), cons and (fmtN(235.215 / cons, 1) .. " / " .. fmtN(282.481 / cons, 1)) or "—"},
    {TR("cost_km"), (cons and price) and money(liters * price / km) or "—"},
    {TR("total_cost"), (liters and price) and money(liters * price) or "—"},
  }
  local yy = ry + gr + 96
  for i, r in ipairs(rows) do
    gfx.color(theme.text2)
    gfx.text(r[1], rx + 14, yy, 13)
    gfx.color(theme.text)
    gfx.text(r[2], rx, yy, 13, "semibold", "right", rw - 14)
    yy = yy + 24
    if i < #rows then ui.separator(rx + 14, yy - 4, rx + rw - 14) end
  end
  local by = wide and y + 236 or ry + 290
  if ui.button(TR("save_log"), x, by, fw, 36, "primary", "history", cons ~= nil) and cons then
    addEntry(km, liters, price)
  end
  if ui.button(TR("use_trip"), x, by + 42, fw, 32, "default", "route", cons ~= nil) and cons then
    f.tripCons = fmtN(cons, 2):gsub(lang == "tr" and "%." or ",", "")
    if price then f.tripPrice = f.price end
    saveFields()
    tab = 2
    audio.play("click")
  end
  if not cons and trim(f.km) == "" and trim(f.liters) == "" then
    gfx.color(theme.text3)
    gfx.wrap(TR("hint_cons"), x, by + 84, fw, 12)
  end
end

local function drawTrip(x, y, w, h, dt)
  local wide = w >= 620
  local fw = wide and (w - 24) / 2 - 10 or w
  local km = field("tripKm", TR("trip_distance"), "km", x, y, fw, 1, 100000, true)
  local cons = field("tripCons", TR("consumption"), "L/100", x, y + 74, fw, 1, 50, true)
  if stats.n > 0 and ui.button(TR("use_avg", fmtN(stats.avg, 1)), x + fw - 170, y + 70, 120, 24, "link") then
    f.tripCons = fmtN(stats.avg, 2):gsub(lang == "tr" and "%." or ",", ""); saveFields()
  end
  local price = field("tripPrice", TR("price_l"), CURRENCIES[cur], x, y + 148, fw, 0.01, 1000, true)
  local oy = y + 226
  gfx.color(theme.text2)
  gfx.text(TR("passengers"), x, oy + 8, 13)
  if ui.button("−##p", x + fw - 120, oy, 36, 32, "default", nil, passengers > 1) then passengers = passengers - 1; saveFields() end
  gfx.color(theme.text)
  gfx.text(tostring(passengers), x + fw - 84, oy + 6, 17, "bold", "center", 48)
  if ui.button("+##p", x + fw - 36, oy, 36, 32, "default", nil, passengers < 9) then passengers = passengers + 1; saveFields() end
  local rt = ui.checkbox(TR("round_trip"), roundTrip, x, oy + 46)
  if rt ~= roundTrip then roundTrip = rt; saveFields() end
  local ft = ui.segmented("fuelType", {TR("petrol"), TR("diesel"), TR("lpg")}, fuelType, x, oy + 76, fw, 30)
  if ft ~= fuelType then fuelType = ft; saveFields() end
  -- results
  local rx = wide and x + fw + 30 or x
  local ry = wide and y or oy + 120
  local rw = wide and w - fw - 30 or w
  local dist = km and (roundTrip and km * 2 or km) or nil
  local need = (dist and cons) and dist * cons / 100 or nil
  local cost = (need and price) and need * price or nil
  local sc = smooth("tripCost", cost or 0, dt)
  ui.group(rx, ry, rw, 240)
  gfx.icon("directions_car", rx + rw / 2, ry + 34, 34, theme.accent)
  gfx.color(cost and theme.text or theme.text3)
  gfx.text(cost and money(sc) or "—", rx, ry + 58, 30, "bold", "center", rw)
  gfx.color(theme.text2)
  gfx.text(TR("trip_cost"), rx, ry + 96, 12, "semibold", "center", rw)
  local rows = {
    {TR("total_distance"), dist and (fmtN(dist, 0) .. " km") or "—"},
    {TR("fuel_needed"), need and (fmtN(need, 1) .. " L") or "—"},
    {TR("per_person"), cost and money(cost / passengers) or "—"},
    {TR("co2"), need and (fmtN(need * CO2[fuelType], 1) .. " kg") or "—"},
  }
  local yy = ry + 124
  for i, r in ipairs(rows) do
    gfx.color(theme.text2)
    gfx.text(r[1], rx + 14, yy, 13)
    gfx.color(i == 3 and theme.accent or theme.text)
    gfx.text(r[2], rx, yy, 13, "semibold", "right", rw - 14)
    yy = yy + 26
    if i < #rows then ui.separator(rx + 14, yy - 5, rx + rw - 14) end
  end
end

local function drawChart(x, y, w, h)
  ui.group(x, y, w, h)
  gfx.color(theme.text2)
  gfx.text(TR("chart_title"), x + 14, y + 10, 11, "semibold")
  -- last 12 entries in date order
  local pts = {}
  for _, e in ipairs(log) do pts[#pts + 1] = e end
  table.sort(pts, function(a, b) if a.day ~= b.day then return a.day < b.day end return a.id < b.id end)
  local first = math.max(1, #pts - 11)
  local n = #pts - first + 1
  if n <= 0 then return end
  local mx, mn = 0, math.huge
  for i = first, #pts do local c = pts[i].liters / pts[i].km * 100; mx = math.max(mx, c); mn = math.min(mn, c) end
  mx = math.max(mx * 1.15, stats.avg * 1.15, 1)
  local cx, cy, cw, ch = x + 14, y + 32, w - 28, h - 56
  local bw = cw / 12
  for i = first, #pts do
    local e = pts[i]
    local c = e.liters / e.km * 100
    local k = i - first
    local bh = ch * c / mx
    local bx = cx + k * bw + bw * 0.18
    local col = c <= stats.avg and theme.green or theme.orange
    local a = appear[e.id]
    if a then bh = bh * ease(a) end
    gfx.rect(bx, cy + ch - bh, bw * 0.64, bh, 4, col)
    gfx.color(theme.text3)
    gfx.text(fmtN(c, 1), bx - 10, cy + ch - bh - 15, 10, "sans", "center", bw * 0.64 + 20)
  end
  local ay = cy + ch - ch * stats.avg / mx
  gfx.color(theme.accent)
  for xx = cx, cx + cw - 8, 12 do gfx.line(xx, ay, xx + 6, ay, 1.5) end
  gfx.text(TR("avg_line", fmtN(stats.avg, 1)), x, ay - 16, 10, "semibold", "right", w - 14)
  gfx.color(theme.text3)
  gfx.text(TR("chart_hint"), cx, y + h - 20, 10)
end

local function drawLog(x, y, w, h)
  if #log == 0 then
    local cy = y + (h - y) / 2 - 60
    local bob = math.sin(sys.time() * 2) * 3
    gfx.circle(x + w / 2, cy + bob, 40, theme.hover)
    gfx.icon("local_gas_station", x + w / 2, cy + bob, 44, theme.text3)
    gfx.color(theme.text)
    gfx.text(TR("empty_log"), x, cy + 52, 16, "semibold", "center", w)
    gfx.color(theme.text2)
    gfx.text(TR("empty_log_sub"), x, cy + 76, 13, "sans", "center", w)
    if ui.button(TR("go_calc"), x + w / 2 - 110, cy + 106, 220, 34, "primary", "calculate") then tab = 1 end
    return
  end
  -- stat tiles
  local tiles = {
    {TR("avg"), fmtN(stats.avg, 2), "L/100"}, {TR("total_km"), fmtN(stats.km, 0), "km"},
    {TR("total_l"), fmtN(stats.liters, 1), "L"}, {TR("total_spent"), money(stats.cost), ""},
  }
  local cols = w >= 600 and 4 or 2
  local tw = (w - (cols - 1) * 8) / cols
  for i, t in ipairs(tiles) do
    local tx = x + ((i - 1) % cols) * (tw + 8)
    local ty = y + ((i - 1) // cols) * 64
    gfx.rect(tx, ty, tw, 56, 10, theme.hover)
    gfx.color(theme.text2)
    gfx.text(t[1], tx + 10, ty + 8, 11, "semibold")
    gfx.color(theme.text)
    local vw = gfx.text(t[2], tx + 10, ty + 24, 18, "bold")
    gfx.color(theme.text3)
    gfx.text(t[3], tx + 16 + vw, ty + 30, 11)
  end
  y = y + (cols == 4 and 64 or 128)
  drawChart(x, y, w, 150)
  y = y + 160
  -- list header
  local dw = math.min(190, w * 0.4)
  local s = ui.dropdown("sort", SORTS, sortMode, x, y, dw, 30)
  if s ~= sortMode then sortMode = s; store.set("sort", s); dirty = true end
  if ui.button(TR("export"), x + w - 150, y, 150, 30, "default", "save") then exportCsv() end
  y = y + 38
  local rowH = 46
  ui.beginScroll("log", x, y, w, h - y - 4, #sorted * rowH)
  for i, e in ipairs(sorted) do
    local a = appear[e.id]
    local ry = (i - 1) * rowH
    local ox = a and (1 - ease(a)) * 40 or 0
    if a then gfx.alpha(ease(a)) end
    local c = e.liters / e.km * 100
    gfx.rect(ox, ry, w, rowH - 6, 8, theme.hover)
    gfx.circle(ox + 18, ry + 20, 6, c <= stats.avg and theme.green or theme.orange)
    gfx.color(theme.text)
    gfx.text(dateLabel(e.day), ox + 32, ry + 4, 14, "semibold")
    gfx.color(theme.text2)
    local detail = fmtN(e.km, 0) .. " km · " .. fmtN(e.liters, 1) .. " L"
    if (e.price or 0) > 0 then detail = detail .. " · " .. money(e.liters * e.price) end
    gfx.text(detail, ox + 32, ry + 22, 12)
    gfx.color(theme.text)
    gfx.text(fmtN(c, 2) .. " L/100", ox, ry + 11, 14, "bold", "right", w - 52)
    if ui.iconButton("delete", ox + w - 42, ry + 4, 34, 32, theme.red, false, "dl" .. e.id) then removeEntry(e) end
    if a then gfx.unalpha() end
  end
  ui.endScroll()
end

-- ------------------------------------------------------------------ app
local lastT = 0

function app.draw(w, h)
  local now = sys.time()
  local dt = math.min(0.1, math.max(0, now - lastT))
  lastT = now
  gfx.clear(theme.bg)
  if dirty then rebuild() end
  local tw = math.min(460, w - 140)
  local nt = ui.segmented("tabs", {TR("tab_cons"), TR("tab_trip"), TR("tab_log", #log)}, tab, (w - tw) / 2 - 50, 12, tw, 32)
  if nt ~= tab then tab = nt; store.set("tab", tab); audio.play("click") end
  local nc = ui.dropdown("cur", CURRENCIES, cur, w - 96, 12, 80, 32)
  if nc ~= cur then cur = nc; store.set("cur", cur) end
  local cw = math.min(820, w - 40)
  local x = (w - cw) / 2
  if tab == 1 then
    ui.beginScroll("c1", 0, 56, w, h - 56, 560)
    drawConsumption(x, 8, cw, h, dt)
    ui.endScroll()
  elseif tab == 2 then
    ui.beginScroll("c2", 0, 56, w, h - 56, w >= 660 and 360 or 640)
    drawTrip(x, 8, cw, h, dt)
    ui.endScroll()
  else
    drawLog(x, 58, cw, h)
  end
  -- toasts
  if undoEntry and undoT > 0 then
    local text = TR("entry_deleted")
    local tw2 = gfx.textWidth(text, 13, "semibold") + 140
    local tx, ty = (w - tw2) / 2, h - 58
    gfx.alpha(math.min(1, undoT * 2))
    gfx.shadow(tx, ty, tw2, 40, 20, 12, 4)
    gfx.rect(tx, ty, tw2, 40, 20, theme.dark and "#3A3A3C" or "#1C1C1E")
    gfx.color("#FFFFFF")
    gfx.text(text, tx + 16, ty + 12, 13, "semibold")
    if ui.button(TR("undo"), tx + tw2 - 108, ty + 5, 96, 30, "primary", "undo") then undo() end
    gfx.unalpha()
  elseif msg and msgT > 0 then
    local tw2 = gfx.textWidth(msg, 13, "semibold") + 32
    gfx.alpha(math.min(1, msgT * 2))
    gfx.rect((w - tw2) / 2, h - 52, tw2, 32, 16, theme.dark and "#3A3A3C" or "#1C1C1E")
    gfx.color("#FFFFFF")
    gfx.text(msg, (w - tw2) / 2, h - 44, 13, "semibold", "center", tw2)
    gfx.unalpha()
  end
end

function app.event(e)
  if e.type ~= "keydown" then return end
  if e.ctrl and e.key == "z" then undo()
  elseif e.ctrl and (e.key == "right" or e.key == "tab") then tab = tab % 3 + 1; store.set("tab", tab)
  elseif e.ctrl and e.key == "left" then tab = (tab + 1) % 3 + 1; store.set("tab", tab)
  end
end

function app.menu()
  return {
    {title = TR("menu_fuel"), items = {
      {label = TR("tab_cons"), id = 1}, {label = TR("tab_trip"), id = 2}, {label = TR("tab_log", #log), id = 3},
      "-",
      {label = TR("clear_fields"), id = 4},
    }},
    {title = TR("menu_log"), items = {
      {label = TR("undo"), id = 10, shortcut = "Ctrl+Z"},
      {label = TR("export"), id = 11},
      "-",
      {label = TR("clear_log"), id = 12},
    }},
  }
end

function app.onmenu(id)
  if id >= 1 and id <= 3 then tab = id; store.set("tab", tab)
  elseif id == 4 then for k in pairs(f) do f[k] = "" end; saveFields()
  elseif id == 10 then undo() elseif id == 11 then exportCsv() elseif id == 12 then clearLog() end
end

function app.close()
  saveFields()
  store.save()
  return true
end

return app
