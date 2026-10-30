-- Budget for Nexvyn OS: income and expenses by category, monthly summaries, charts and CSV export.
local app = {}

local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi

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
local WHITE = "#FFFFFF"

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

-- ------------------------------------------------------------------ dates
local function daysFromCivil(y, m, d)
  y = (m <= 2) and (y - 1) or y
  local era = (y >= 0 and y or y - 399) // 400
  local yoe = y - era * 400
  local mp = (m + 9) % 12
  local doy = (153 * mp + 2) // 5 + d - 1
  local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
  return era * 146097 + doe - 719468
end
local function isLeap(y) return (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0 end
local MDAYS = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
local function daysIn(y, m) return (m == 2 and isLeap(y)) and 29 or MDAYS[m] end
local function dateKey(y, m, d) return string.format("%04d-%02d-%02d", y, m, d) end
local function parseKey(k)
  local y, m, d = (k or ""):match("^(%d+)-(%d+)-(%d+)$")
  return tonumber(y), tonumber(m), tonumber(d)
end
local MONTH_KEYS = {"m1", "m2", "m3", "m4", "m5", "m6", "m7", "m8", "m9", "m10", "m11", "m12"}
local MONTH_SHORT = {"ms1", "ms2", "ms3", "ms4", "ms5", "ms6", "ms7", "ms8", "ms9", "ms10", "ms11", "ms12"}
local DAY_KEYS = {"wd0", "wd1", "wd2", "wd3", "wd4", "wd5", "wd6"}
local DAYN_KEYS = {"wdn1", "wdn2", "wdn3", "wdn4", "wdn5", "wdn6", "wdn0"}
local function weekday(y, m, d) return (daysFromCivil(y, m, d) + 4) % 7 end

-- ------------------------------------------------------------------ categories
local CATS = {
  out = {
    {id = "food", icon = "restaurant", color = "orange"},
    {id = "groceries", icon = "shopping_cart", color = "green"},
    {id = "transport", icon = "directions_bus", color = "blue"},
    {id = "housing", icon = "home", color = "purple"},
    {id = "bills", icon = "receipt_long", color = "yellow"},
    {id = "shopping", icon = "shopping_bag", color = "pink"},
    {id = "health", icon = "local_hospital", color = "red"},
    {id = "fun", icon = "sports_esports", color = "indigo"},
    {id = "education", icon = "school", color = "teal"},
    {id = "other_out", icon = "more_horiz", color = "gray"},
  },
  ["in"] = {
    {id = "salary", icon = "payments", color = "green"},
    {id = "freelance", icon = "work", color = "blue"},
    {id = "gift", icon = "card_giftcard", color = "pink"},
    {id = "invest", icon = "trending_up", color = "purple"},
    {id = "other_in", icon = "more_horiz", color = "gray"},
  },
}
local CAT_KEYS = {food = "cat_food", groceries = "cat_groceries", transport = "cat_transport", housing = "cat_housing",
                  bills = "cat_bills", shopping = "cat_shopping", health = "cat_health", fun = "cat_fun",
                  education = "cat_education", other_out = "cat_other", salary = "cat_salary",
                  freelance = "cat_freelance", gift = "cat_gift", invest = "cat_invest", other_in = "cat_other"}
local CAT_BY_ID = {}
for kind, list in pairs(CATS) do
  for _, c in ipairs(list) do c.kind = kind; CAT_BY_ID[c.id] = c end
end
-- theme colors plus two blends so every expense category gets its own hue in both light and dark mode
local function colorOf(name)
  if name == "teal" then
    local a, b = rgba(theme.blue), rgba(theme.green)
    return {floor((a[1] + b[1]) / 2), floor((a[2] + b[2]) / 2), floor((a[3] + b[3]) / 2), 255}
  elseif name == "indigo" then
    local a, b = rgba(theme.blue), rgba(theme.purple)
    return {floor((a[1] + b[1]) / 2), floor((a[2] + b[2]) / 2), floor((a[3] + b[3]) / 2), 255}
  end
  return theme[name] or theme.gray
end
local function catName(id) return TR(CAT_KEYS[id] or "cat_other") end
local function catColor(id) local c = CAT_BY_ID[id]; return colorOf(c and c.color or "gray") end
local function catIcon(id) local c = CAT_BY_ID[id]; return c and c.icon or "more_horiz" end

-- ------------------------------------------------------------------ state
local entries = {}          -- {id, kind="in"/"out", cents, cat, date="YYYY-MM-DD", note}
local nextId = 1
local currencyIdx = 1
local CURRENCIES = {"₺", "$", "€", "£", "¥"}
local viewY, viewM = 2026, 1
local filterKind = 1        -- 1 all, 2 expenses, 3 income
local filterCat = nil
local sheet = nil
local sheetT = 0
local selIndex = 0
local dirty = true
local cache = {}
local anim = {pie = 0, bars = 0}
local toast, toastT = "", -10

local function saveNow()
  store.set("entries", entries)
  store.set("nextId", nextId)
  store.set("currency", currencyIdx)
  store.save()
  dirty = true
end

local function showToast(s) toast, toastT = s, sys.time() end

-- ------------------------------------------------------------------ money
local isTR = false
local function group3(intStr, sep)
  local out = intStr:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
  if out:sub(1, #sep) == sep then out = out:sub(#sep + 1) end
  return out
end
local function fmtMoney(cents, signed)
  local neg = cents < 0
  local a = abs(cents)
  local whole, frac = a // 100, a % 100
  local thou, dec = isTR and "." or ",", isTR and "," or "."
  local num = group3(tostring(whole), thou)
  if frac ~= 0 then num = num .. dec .. string.format("%02d", frac) end
  local sym = CURRENCIES[currencyIdx] or "₺"
  local s
  if sym == "₺" and isTR then s = num .. " " .. sym else s = sym .. num end
  if neg then s = "−" .. s elseif signed then s = "+" .. s end
  return s
end
local function fmtCompact(cents)
  local v = abs(cents) / 100
  local sym = CURRENCIES[currencyIdx] or "₺"
  local s
  if v >= 1e6 then s = string.format("%.1fM", v / 1e6)
  elseif v >= 1e4 then s = string.format("%.0fK", v / 1e3)
  elseif v >= 1e3 then s = string.format("%.1fK", v / 1e3)
  else s = string.format("%.0f", v) end
  if isTR then s = s:gsub("%.", ",") end
  return (sym == "₺" and isTR) and (s .. " " .. sym) or (sym .. s)
end

-- "1.234,56" / "1,234.56" / "12.5" / "12,5" / "1500" -> cents (nil when not a number)
local function parseAmount(s)
  s = (s or ""):gsub("%s", "")
  if s == "" or not s:match("^[%d%.,]+$") then return nil end
  local _, dots = s:gsub("%.", "")
  local _, commas = s:gsub(",", "")
  local decSep = nil
  if dots > 0 and commas > 0 then
    decSep = (s:match(".*()%.") > s:match(".*(),")) and "." or ","
  elseif commas == 1 then
    local after = s:match(",(%d*)$") or ""
    if #after ~= 3 or isTR then decSep = "," end
  elseif dots == 1 then
    local after = s:match("%.(%d*)$") or ""
    if #after ~= 3 or not isTR then decSep = "." end
  end
  local intPart, fracPart = s, ""
  if decSep then
    local p = decSep == "." and s:match(".*()%.") or s:match(".*(),")
    intPart, fracPart = s:sub(1, p - 1), s:sub(p + 1)
  end
  intPart = intPart:gsub("[%.,]", "")
  if fracPart:find("[%.,]") then return nil end
  if intPart == "" then intPart = "0" end
  if #fracPart > 2 then fracPart = fracPart:sub(1, 2) end
  fracPart = (fracPart .. "00"):sub(1, 2)
  local whole = tonumber(intPart)
  if not whole or whole > 1e12 then return nil end
  return floor(whole) * 100 + tonumber(fracPart)
end

local function centsToInput(cents)
  local a = abs(cents)
  local s = tostring(a // 100)
  if a % 100 ~= 0 then s = s .. (isTR and "," or ".") .. string.format("%02d", a % 100) end
  return s
end

-- ------------------------------------------------------------------ aggregates
local function monthKey(y, m) return string.format("%04d-%02d", y, m) end

local function rebuild()
  dirty = false
  local mk = monthKey(viewY, viewM)
  local inc, out = 0, 0
  local byCat = {}
  local list = {}
  local totalBalance = 0
  for _, e in ipairs(entries) do
    local sign = e.kind == "in" and 1 or -1
    totalBalance = totalBalance + sign * e.cents
    if e.date:sub(1, 7) == mk then
      if e.kind == "in" then inc = inc + e.cents else out = out + e.cents; byCat[e.cat] = (byCat[e.cat] or 0) + e.cents end
      local pass = (filterKind == 1) or (filterKind == 2 and e.kind == "out") or (filterKind == 3 and e.kind == "in")
      if pass and filterCat and e.cat ~= filterCat then pass = false end
      if pass then list[#list + 1] = e end
    end
  end
  table.sort(list, function(a, b)
    if a.date ~= b.date then return a.date > b.date end
    return a.id > b.id
  end)
  -- rows: day headers + entries
  local rows = {}
  local curDay, curRow = nil, nil
  for _, e in ipairs(list) do
    if e.date ~= curDay then
      curDay = e.date
      curRow = {day = e.date, total = 0}
      rows[#rows + 1] = curRow
    end
    curRow.total = curRow.total + (e.kind == "in" and e.cents or -e.cents)
    rows[#rows + 1] = {entry = e}
  end
  -- pie slices
  local slices = {}
  for i, c in ipairs(CATS.out) do
    if (byCat[c.id] or 0) > 0 then slices[#slices + 1] = {cat = c.id, cents = byCat[c.id]} end
  end
  table.sort(slices, function(a, b) return a.cents > b.cents end)
  -- last 6 months
  local months = {}
  for i = 5, 0, -1 do
    local y, m = viewY, viewM - i
    while m < 1 do m = m + 12; y = y - 1 end
    months[#months + 1] = {y = y, m = m, key = monthKey(y, m), inc = 0, out = 0}
  end
  local idx = {}
  for i, mo in ipairs(months) do idx[mo.key] = i end
  for _, e in ipairs(entries) do
    local i = idx[e.date:sub(1, 7)]
    if i then
      if e.kind == "in" then months[i].inc = months[i].inc + e.cents else months[i].out = months[i].out + e.cents end
    end
  end
  cache = {inc = inc, out = out, rows = rows, list = list, slices = slices, months = months, total = totalBalance}
  if selIndex > #list then selIndex = #list end
end

-- ------------------------------------------------------------------ CSV export
local function csvField(s)
  s = tostring(s or "")
  if s:find('[,"\n\r;]') then s = '"' .. s:gsub('"', '""') .. '"' end
  return s
end

local function exportCSV(all)
  local rows = {"date,type,category,amount,currency,note"}
  local list = {}
  local mk = monthKey(viewY, viewM)
  for _, e in ipairs(entries) do
    if all or e.date:sub(1, 7) == mk then list[#list + 1] = e end
  end
  table.sort(list, function(a, b) if a.date ~= b.date then return a.date < b.date end return a.id < b.id end)
  for _, e in ipairs(list) do
    local amt = string.format("%s%d.%02d", e.kind == "out" and "-" or "", e.cents // 100, e.cents % 100)
    rows[#rows + 1] = table.concat({e.date, e.kind == "in" and "income" or "expense", csvField(catName(e.cat)), amt,
                                    csvField(CURRENCIES[currencyIdx]), csvField(e.note)}, ",")
  end
  local dir = fs.dir("documents")
  if not fs.isdir(dir) then fs.mkdir(dir) end
  local name = all and "budget-all.csv" or ("budget-" .. mk .. ".csv")
  local path = dir .. "/" .. name
  local ok = fs.write(path, "\239\187\191" .. table.concat(rows, "\r\n") .. "\r\n")
  if ok then
    audio.play("shutter")
    sys.notify(TR("export_done"), TR("export_body", name, #list))
    ui.alert(TR("export_done"), TR("export_msg", name), {TR("open_file"), TR("ok")}, function(b)
      if b == 1 then sys.open(path) end
    end)
  else
    audio.play("error")
    ui.alert(TR("export_failed"), TR("export_failed_msg"), {TR("ok")})
  end
end

-- ------------------------------------------------------------------ editor sheet
local function openEditor(e, kind)
  local d = sys.date()
  local s = {isNew = e == nil, id = e and e.id}
  if e then
    s.kind, s.amount, s.cat, s.note = e.kind, centsToInput(e.cents), e.cat, e.note
    s.y, s.m, s.d = parseKey(e.date)
  else
    s.kind = kind or "out"
    s.amount, s.note = "", ""
    s.cat = s.kind == "in" and "salary" or "food"
    -- default date: today when viewing the current month, else the 1st of the viewed month
    if d.year == viewY and d.month == viewM then s.y, s.m, s.d = d.year, d.month, d.day
    else s.y, s.m, s.d = viewY, viewM, 1 end
  end
  s.calY, s.calM = s.y, s.m
  s.err = false
  sheet = s
  sheetT = 0
  editing = false
  audio.play("pop")
end

local function closeEditor()
  sheet = nil
  editing = false
end

local function commitEditor()
  local s = sheet
  if not s then return end
  local cents = parseAmount(s.amount)
  if not cents or cents <= 0 then
    s.err = true
    audio.play("error")
    ui.focus("bd_amount")
    editing = true
    return
  end
  local e
  if s.id then
    for _, x in ipairs(entries) do if x.id == s.id then e = x break end end
  end
  if not e then
    e = {id = nextId}
    nextId = nextId + 1
    entries[#entries + 1] = e
  end
  e.kind, e.cents, e.cat = s.kind, cents, s.cat
  e.date = dateKey(s.y, s.m, s.d)
  e.note = (s.note or ""):gsub("^%s+", ""):gsub("%s+$", "")
  -- jump to the month of the entry so it is visible
  viewY, viewM = s.y, s.m
  closeEditor()
  saveNow()
  audio.tone(e.kind == "in" and 880 or 520, 0.08, 0.25, "triangle")
end

local function deleteEntry(id)
  ui.alert(TR("delete_title"), TR("delete_msg"), {TR("delete"), TR("cancel")}, function(b)
    if b == 1 then
      for i, x in ipairs(entries) do
        if x.id == id then table.remove(entries, i) break end
      end
      if sheet and sheet.id == id then closeEditor() end
      saveNow()
      audio.play("trash")
    end
  end)
end

local function duplicateEntry(e)
  local d = sys.date()
  local c = {id = nextId, kind = e.kind, cents = e.cents, cat = e.cat, note = e.note, date = dateKey(d.year, d.month, d.day)}
  nextId = nextId + 1
  entries[#entries + 1] = c
  viewY, viewM = d.year, d.month
  saveNow()
  showToast(TR("duplicated"))
  audio.play("pop")
end

local function entryMenu(e)
  ui.contextMenu({
    {label = TR("edit"), id = 1, icon = "edit"},
    {label = TR("duplicate_today"), id = 2, icon = "content_copy"},
    "-",
    {label = TR("delete"), id = 3, icon = "delete"},
  }, function(id)
    if id == 1 then openEditor(e)
    elseif id == 2 then duplicateEntry(e)
    elseif id == 3 then deleteEntry(e.id) end
  end)
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  isTR = sys.lang() == "tr"
  local d = sys.date()
  viewY, viewM = d.year, d.month
  nextId = tonumber(store.get("nextId", 1)) or 1
  local list = store.get("entries", {})
  entries = {}
  if type(list) == "table" then
    for _, e in ipairs(list) do
      if type(e) == "table" and tonumber(e.cents) and type(e.date) == "string" and parseKey(e.date) then
        local o = {id = tonumber(e.id) or nextId, kind = e.kind == "in" and "in" or "out", cents = floor(tonumber(e.cents)),
                   cat = type(e.cat) == "string" and e.cat or "other_out", date = e.date,
                   note = type(e.note) == "string" and e.note or ""}
        if not CAT_BY_ID[o.cat] then o.cat = o.kind == "in" and "other_in" or "other_out" end
        if o.id >= nextId then nextId = o.id + 1 end
        entries[#entries + 1] = o
      end
    end
  end
  local cur = store.get("currency", nil)
  if type(cur) == "number" and CURRENCIES[cur] then currencyIdx = floor(cur)
  else currencyIdx = isTR and 1 or 2 end
  dirty = true
end

function app.update(dt)
  if sheet then sheetT = approach(sheetT, 1, 14, dt) end
  anim.pie = approach(anim.pie, 1, 5, dt)
  anim.bars = approach(anim.bars, 1, 6, dt)
end

local function changeMonth(d)
  viewM = viewM + d
  if viewM < 1 then viewM, viewY = 12, viewY - 1 end
  if viewM > 12 then viewM, viewY = 1, viewY + 1 end
  filterCat = nil
  selIndex = 0
  dirty = true
  anim.pie, anim.bars = 0, 0.4
  audio.play("click")
end

-- ------------------------------------------------------------------ drawing
local function card(x, y, w, h)
  gfx.rect(x, y, w, h, 12, theme.dark and "#FFFFFF0F" or "#0000000A")
end

local function summaryCard(x, y, w, h, icon, color, label, value, sub)
  card(x, y, w, h)
  gfx.circle(x + 28, y + 28, 16, fade(color, 0.16))
  gfx.icon(icon, x + 28, y + 28, 18, color)
  gfx.color(theme.text2)
  gfx.text(label, x + 52, y + 20, 13, "medium")
  gfx.color(theme.text)
  gfx.clip(x + 14, y + 46, w - 28, 34)
  gfx.text(value, x + 16, y + 48, 24, "bold")
  gfx.unclip()
  if sub then
    gfx.color(theme.text3)
    gfx.text(sub, x, y + 22, 12, "sans", "right", w - 14)
  end
end

local function fmtDay(key)
  local y, m, d = parseKey(key)
  if not y then return key end
  local now = sys.date()
  local today = daysFromCivil(now.year, now.month, now.day)
  local dn = daysFromCivil(y, m, d)
  if dn == today then return TR("today") end
  if dn == today - 1 then return TR("yesterday") end
  return TR("day_fmt", d, TR(MONTH_KEYS[m]), TR(DAY_KEYS[weekday(y, m, d) + 1]))
end

local function drawList(x, y, w, h, interactive)
  -- filter bar
  if interactive then
    local nk = ui.segmented("kindf", {TR("f_all"), TR("f_out"), TR("f_in")}, filterKind, x, y, 260, 28)
    if nk ~= filterKind then filterKind = nk; filterCat = nil; dirty = true; rebuild(); selIndex = 0 end
  end
  if filterCat then
    local lbl = catName(filterCat)
    local bw = gfx.textWidth(lbl, 12, "medium") + 40
    local bx = x + w - bw
    local hh = interactive and ui.hit("clearcat", bx, y + 2, bw, 24)
    gfx.rect(bx, y + 2, bw, 24, 12, fade(catColor(filterCat), 0.18))
    gfx.color(theme.text)
    gfx.text(lbl, bx + 12, y + 7, 12, "medium")
    gfx.icon("close", bx + bw - 14, y + 14, 14, theme.text2)
    if hh and hh.clicked then filterCat = nil; dirty = true; rebuild() end
  end
  local top = y + 40
  local lh = h - 40
  local rows = cache.rows
  if #rows == 0 then
    card(x, top, w, lh)
    gfx.icon("receipt_long", x + w / 2, top + lh / 2 - 24, 36, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("no_entries"), x, top + lh / 2 + 4, 14, "medium", "center", w)
    gfx.color(theme.text3)
    gfx.text(TR("no_entries_hint"), x, top + lh / 2 + 26, 12.5, "sans", "center", w)
    return
  end
  local headH, rowH = 30, 50
  local contentH = 0
  for _, r in ipairs(rows) do contentH = contentH + (r.day and headH or rowH) end
  if interactive then ui.beginScroll("list", x, top, w, lh, contentH + 8)
  else gfx.clip(x, top, w, lh); gfx.push(x, top) end
  local cy = 0
  local entryIdx = 0
  for _, r in ipairs(rows) do
    if r.day then
      gfx.color(theme.text2)
      gfx.text(fmtDay(r.day), 6, cy + 10, 12, "semibold")
      gfx.color(r.total >= 0 and theme.green or theme.text3)
      gfx.text(fmtMoney(r.total, true), 0, cy + 10, 12, "medium", "right", w - 14)
      cy = cy + headH
    else
      entryIdx = entryIdx + 1
      local e = r.entry
      local sel = entryIdx == selIndex
      local hit = interactive and ui.hit("row" .. e.id, 0, cy, w, rowH - 2)
      if sel then gfx.rect(0, cy, w, rowH - 2, 10, fade(theme.accent, 0.16))
      elseif hit and hit.hovered then gfx.rect(0, cy, w, rowH - 2, 10, theme.hover) end
      local col = catColor(e.cat)
      gfx.circle(24, cy + 24, 17, fade(col, 0.16))
      gfx.icon(catIcon(e.cat), 24, cy + 24, 19, col)
      gfx.clip(48, cy, w - 190, rowH)
      gfx.color(theme.text)
      gfx.text(catName(e.cat), 50, cy + (e.note ~= "" and 8 or 16), 14, "medium")
      if e.note ~= "" then
        gfx.color(theme.text2)
        gfx.text(e.note, 50, cy + 27, 12)
      end
      gfx.unclip()
      gfx.color(e.kind == "in" and theme.green or theme.text)
      gfx.text(fmtMoney(e.kind == "in" and e.cents or -e.cents, e.kind == "in"), 0, cy + 15, 15, "semibold", "right", w - 14)
      if hit then
        if hit.clicked then selIndex = entryIdx; openEditor(e) end
        if hit.rightClicked then selIndex = entryIdx; entryMenu(e) end
      end
      cy = cy + rowH
    end
  end
  if interactive then ui.endScroll() else gfx.pop(); gfx.unclip() end
end

local function drawPie(x, y, w, h, interactive)
  card(x, y, w, h)
  gfx.color(theme.text)
  gfx.text(TR("spending_by_cat"), x + 16, y + 14, 14, "semibold")
  local slices = cache.slices
  local total = cache.out
  local cx, cy, r = x + 86, y + 44 + 76, 70
  if total <= 0 then
    gfx.color(theme.dark and "#FFFFFF14" or "#0000000F")
    gfx.arc(cx, cy, r - 14, 0, pi * 2, 26)
    gfx.color(theme.text3)
    gfx.text(TR("no_spending"), x + 176, cy - 8, 13)
    return
  end
  local a0 = -pi / 2
  local sweep = pi * 2 * (1 - (1 - anim.pie) ^ 3)
  for _, s in ipairs(slices) do
    local frac = s.cents / total
    local a1 = a0 + frac * sweep
    local col = catColor(s.cat)
    local hl = filterCat == s.cat
    local rr = hl and r + 5 or r
    if not filterCat or hl then gfx.color(col) else gfx.color(fade(col, 0.35)) end
    if a1 - a0 > 0.001 then gfx.pie(cx, cy, rr, a0, a1) end
    a0 = a1
  end
  -- donut hole
  gfx.circle(cx, cy, r * 0.58, theme.dark and "#262628" or "#F7F7F7")
  gfx.color(theme.text2)
  gfx.text(TR("total"), cx - 50, cy - 18, 11, "medium", "center", 100)
  gfx.color(theme.text)
  gfx.text(fmtCompact(total), cx - 50, cy - 3, 14, "bold", "center", 100)
  -- legend
  local lx, ly = x + 176, y + 44
  local lw = w - 176 - 12
  local maxRows = floor((h - 52) / 26)
  for i, s in ipairs(slices) do
    if i > maxRows then break end
    local yy = ly + (i - 1) * 26
    local hh = interactive and ui.hit("leg" .. s.cat, lx - 6, yy - 2, lw + 6, 24)
    if filterCat == s.cat then gfx.rect(lx - 6, yy - 2, lw + 6, 24, 6, fade(catColor(s.cat), 0.16))
    elseif hh and hh.hovered then gfx.rect(lx - 6, yy - 2, lw + 6, 24, 6, theme.hover) end
    gfx.circle(lx + 5, yy + 10, 5, catColor(s.cat))
    gfx.color(theme.text)
    gfx.clip(lx, yy, lw - 52, 22)
    gfx.text(catName(s.cat), lx + 16, yy + 3, 12.5)
    gfx.unclip()
    gfx.color(theme.text2)
    gfx.text(floor(s.cents / total * 100 + 0.5) .. "%", lx, yy + 3, 12.5, "semibold", "right", lw - 4)
    if hh and hh.clicked then
      filterCat = filterCat ~= s.cat and s.cat or nil
      if filterCat and filterKind == 3 then filterKind = 1 end
      dirty = true
      selIndex = 0
      audio.play("click")
    end
  end
end

local function drawBars(x, y, w, h)
  card(x, y, w, h)
  gfx.color(theme.text)
  gfx.text(TR("last_6_months"), x + 16, y + 14, 14, "semibold")
  -- legend
  gfx.circle(x + w - 130, y + 22, 4, theme.green)
  gfx.color(theme.text2)
  gfx.text(TR("income"), x + w - 122, y + 15, 11.5)
  gfx.circle(x + w - 62, y + 22, 4, theme.red)
  gfx.text(TR("expense"), x + w - 54, y + 15, 11.5)
  local months = cache.months
  local peak = 1
  for _, m in ipairs(months) do peak = max(peak, m.inc, m.out) end
  local chartX, chartY = x + 16, y + 44
  local chartW, chartH = w - 32, h - 44 - 30
  -- grid lines
  for i = 0, 2 do
    local gy = chartY + chartH - chartH * i / 2
    gfx.color(theme.separator)
    gfx.line(chartX, gy, chartX + chartW, gy, 1)
  end
  gfx.color(theme.text3)
  gfx.text(fmtCompact(peak), chartX, chartY - 4, 10)
  local slot = chartW / #months
  local bw = min(16, slot / 3.2)
  local k = 1 - (1 - anim.bars) ^ 3
  for i, m in ipairs(months) do
    local sx = chartX + (i - 1) * slot + slot / 2
    local isCur = i == #months
    local hi = chartH * m.inc / peak * k
    local ho = chartH * m.out / peak * k
    if isCur then gfx.rect(sx - slot / 2 + 3, chartY - 6, slot - 6, chartH + 30, 8, fade(theme.accent, 0.08)) end
    if hi > 0 then gfx.rect(sx - bw - 1, chartY + chartH - hi, bw, hi, min(4, bw / 2), theme.green) end
    if ho > 0 then gfx.rect(sx + 1, chartY + chartH - ho, bw, ho, min(4, bw / 2), theme.red) end
    gfx.color(isCur and theme.accent or theme.text2)
    gfx.text(TR(MONTH_SHORT[m.m]), sx - slot / 2, chartY + chartH + 8, 11, isCur and "semibold" or "sans", "center", slot)
  end
end

-- ------------------------------------------------------------------ sheet
local function drawCalendar(s, x, y, w)
  local cell = floor(w / 7)
  gfx.color(theme.text)
  gfx.text(TR("month_year", TR(MONTH_KEYS[s.calM]), s.calY), x, y + 6, 14, "semibold")
  if ui.iconButton("chevron_left", x + w - 64, y, 30, 28, theme.text2, false, "calprev") then
    s.calM = s.calM - 1
    if s.calM < 1 then s.calM, s.calY = 12, s.calY - 1 end
  end
  if ui.iconButton("chevron_right", x + w - 32, y, 30, 28, theme.text2, false, "calnext") then
    s.calM = s.calM + 1
    if s.calM > 12 then s.calM, s.calY = 1, s.calY + 1 end
  end
  local wy = y + 34
  for i = 0, 6 do
    gfx.color(theme.text3)
    gfx.text(TR(DAYN_KEYS[i + 1]), x + i * cell, wy, 11, "semibold", "center", cell)
  end
  local first = weekday(s.calY, s.calM, 1)
  local offset = (first + 6) % 7
  local nd = daysIn(s.calY, s.calM)
  local today = sys.date()
  local col = s.kind == "in" and theme.green or theme.accent
  local gy = wy + 18
  for d = 1, nd do
    local idx = offset + d - 1
    local cx = x + (idx % 7) * cell
    local cy = gy + floor(idx / 7) * 28
    local sel = s.y == s.calY and s.m == s.calM and s.d == d
    local isToday = today.year == s.calY and today.month == s.calM and today.day == d
    local h = ui.hit("cal" .. d, cx, cy, cell, 28)
    if sel then gfx.circle(cx + cell / 2, cy + 14, 13, col)
    elseif h.hovered then gfx.circle(cx + cell / 2, cy + 14, 13, theme.hover) end
    if isToday and not sel then
      gfx.color(col)
      gfx.circleLine(cx + cell / 2, cy + 14, 13, 1.5)
    end
    gfx.color(sel and WHITE or theme.text)
    gfx.text(tostring(d), cx, cy + 6, 13, sel and "semibold" or "sans", "center", cell)
    if h.clicked then s.y, s.m, s.d = s.calY, s.calM, d; audio.play("click") end
  end
end

local function drawSheet(w, h)
  local s = sheet
  gfx.rect(0, 0, w, h, 0, {0, 0, 0, floor(110 * sheetT)})
  local sw, sh = 620, 450
  local sx, sy = floor((w - sw) / 2), floor((h - sh) / 2 + (1 - sheetT) * 24)
  gfx.alpha(sheetT)
  gfx.shadow(sx, sy, sw, sh, 14, 30, 10)
  gfx.rect(sx, sy, sw, sh, 14, theme.dark and "#2C2C2E" or "#F6F6F6")
  gfx.color(theme.separator)
  gfx.rectLine(sx, sy, sw, sh, 14, 1)
  gfx.color(theme.text)
  gfx.text(s.isNew and TR("new_entry") or TR("edit_entry"), sx + 20, sy + 18, 17, "bold")
  local nk = ui.segmented("bd_kind", {TR("expense"), TR("income")}, s.kind == "in" and 2 or 1, sx + sw - 240, sy + 14, 220, 28)
  local newKind = nk == 2 and "in" or "out"
  if newKind ~= s.kind then
    s.kind = newKind
    s.cat = newKind == "in" and "salary" or "food"
    audio.play("click")
  end
  -- amount
  local lx, lw = sx + 20, 300
  local y = sy + 60
  gfx.color(theme.text2)
  gfx.text(TR("amount"), lx, y, 12, "semibold")
  local na = field("bd_amount", s.amount, lx, y + 18, lw, 40, TR("amount_placeholder"), "numeric")
  if na ~= s.amount then s.amount = na; s.err = false end
  gfx.color(s.kind == "in" and theme.green or theme.text2)
  gfx.text(CURRENCIES[currencyIdx], lx, y + 26, 18, "semibold", "right", lw - 12)
  if s.err then
    gfx.color(theme.red)
    gfx.text(TR("amount_invalid"), lx, y + 62, 12)
  end
  -- categories
  y = y + 84
  gfx.color(theme.text2)
  gfx.text(TR("category"), lx, y, 12, "semibold")
  local list = CATS[s.kind]
  local perRow = 5
  local cw = floor(lw / perRow)
  for i, c in ipairs(list) do
    local col = (i - 1) % perRow
    local row = floor((i - 1) / perRow)
    local px, py = lx + col * cw, y + 18 + row * 62
    local sel = s.cat == c.id
    local hh = ui.hit("bcat" .. c.id, px, py, cw - 4, 58)
    local cc = colorOf(c.color)
    if sel then gfx.rect(px, py, cw - 4, 58, 10, fade(cc, 0.18))
    elseif hh.hovered then gfx.rect(px, py, cw - 4, 58, 10, theme.hover) end
    gfx.circle(px + (cw - 4) / 2, py + 20, 15, sel and cc or fade(cc, 0.16))
    gfx.icon(c.icon, px + (cw - 4) / 2, py + 20, 17, sel and WHITE or cc)
    gfx.color(sel and theme.text or theme.text2)
    gfx.text(catName(c.id), px, py + 40, 10.5, sel and "semibold" or "sans", "center", cw - 4)
    if hh.clicked then s.cat = c.id; audio.play("click") end
  end
  -- note
  y = y + 18 + 2 * 62 + 8
  gfx.color(theme.text2)
  gfx.text(TR("note"), lx, y, 12, "semibold")
  local nn = field("bd_note", s.note, lx, y + 18, sw - 40, 32, TR("note_placeholder"))
  if nn ~= s.note then s.note = nn end
  -- calendar on the right
  local cx = sx + 340
  ui.group(cx - 8, sy + 60, sw - 340 - 12, 244)
  drawCalendar(s, cx + 2, sy + 70, sw - 340 - 32)
  -- footer
  local fy = sy + sh - 50
  ui.separator(sx, fy - 12, sx + sw)
  if not s.isNew then
    if ui.button(TR("delete") .. "##sheet", sx + 20, fy, 96, 32, "destructive") then deleteEntry(s.id) end
  end
  if ui.button(TR("cancel") .. "##sheet", sx + sw - 232, fy, 100, 32) then closeEditor(); audio.play("click") end
  if ui.button(TR("save") .. "##sheet", sx + sw - 120, fy, 100, 32, "primary") then commitEditor() end
  gfx.unalpha()
end

local function drawToast(w, h)
  local age = sys.time() - toastT
  if age > 1.8 then return end
  local a = min(1, age / 0.12) * min(1, (1.8 - age) / 0.3)
  local tw = gfx.textWidth(toast, 13, "medium") + 44
  local tx, ty = (w - tw) / 2, h - 56
  gfx.alpha(a)
  gfx.shadow(tx, ty, tw, 32, 16, 12, 3)
  gfx.rect(tx, ty, tw, 32, 16, theme.dark and "#3A3A3C" or "#323236")
  gfx.icon("check_circle", tx + 18, ty + 16, 16, theme.green)
  gfx.color(WHITE)
  gfx.text(toast, tx + 32, ty + 8, 13, "medium")
  gfx.unalpha()
end

function app.draw(w, h)
  nFields = 0
  if dirty then rebuild() end
  gfx.clear(theme.bg)
  local interactive = sheet == nil
  -- toolbar
  gfx.color(theme.text)
  gfx.text(TR("title"), 20, 18, 22, "bold")
  local label = TR("month_year", TR(MONTH_KEYS[viewM]), viewY)
  local lw = 190
  local mx = floor(w / 2 - lw / 2)
  if interactive then
    if ui.iconButton("chevron_left", mx - 34, 16, 32, 30, theme.text2, false, "mprev") then changeMonth(-1) end
    if ui.iconButton("chevron_right", mx + lw + 2, 16, 32, 30, theme.text2, false, "mnext") then changeMonth(1) end
  end
  gfx.color(theme.text)
  gfx.text(label, mx, 22, 16, "semibold", "center", lw)
  if interactive then
    local cur = ui.dropdown("currency", CURRENCIES, currencyIdx, w - 286, 16, 64, 30)
    if cur ~= currencyIdx then currencyIdx = cur; saveNow() end
    if ui.iconButton("ios_share", w - 214, 16, 36, 30, theme.text2, false, "export") then
      ui.contextMenu({{label = TR("export_month"), id = 1, icon = "calendar_today"},
                      {label = TR("export_all"), id = 2, icon = "file_download"}}, function(id)
        exportCSV(id == 2)
      end)
    end
    if ui.button(TR("new_entry") .. "##top", w - 170, 16, 150, 30, "primary", "add") then openEditor(nil) end
  end
  -- summary
  local sy = 62
  local cw = floor((w - 40 - 24) / 3)
  local bal = cache.inc - cache.out
  summaryCard(20, sy, cw, 86, "south_west", theme.green, TR("income"), fmtMoney(cache.inc))
  summaryCard(20 + cw + 12, sy, cw, 86, "north_east", theme.red, TR("expense"), fmtMoney(cache.out))
  summaryCard(20 + (cw + 12) * 2, sy, cw, 86, "account_balance_wallet", bal >= 0 and theme.blue or theme.orange,
    TR("balance"), fmtMoney(bal), TR("total_balance", fmtMoney(cache.total)))
  -- content
  local top = sy + 86 + 18
  local listW = floor((w - 40) * 0.52)
  drawList(20, top, listW, h - top - 16, interactive)
  local rx = 20 + listW + 16
  local rw = w - rx - 20
  local pieH = 214
  drawPie(rx, top, rw, pieH, interactive)
  drawBars(rx, top + pieH + 12, rw, h - top - pieH - 12 - 16)
  if sheet then drawSheet(w, h) end
  drawToast(w, h)
end

-- ------------------------------------------------------------------ input
function app.event(e)
  if e.type == "mousedown" then
    editing = pointInField(e.x, e.y)
    return
  end
  if e.type ~= "keydown" then return end
  if editing then
    if e.key == "escape" then editing = false end
    return
  end
  if sheet then
    if e.key == "escape" then closeEditor()
    elseif e.key == "enter" then commitEditor() end
    return
  end
  local n = cache.list and #cache.list or 0
  if e.key == "left" then changeMonth(-1)
  elseif e.key == "right" then changeMonth(1)
  elseif e.key == "n" then openEditor(nil)
  elseif e.key == "i" then openEditor(nil, "in")
  elseif e.key == "down" then if n > 0 then selIndex = min(n, selIndex + 1) end
  elseif e.key == "up" then if n > 0 then selIndex = max(1, selIndex - 1) end
  elseif e.key == "enter" or e.key == "space" then
    local en = cache.list and cache.list[selIndex]
    if en then openEditor(en) end
  elseif e.key == "delete" or e.key == "backspace" then
    local en = cache.list and cache.list[selIndex]
    if en then deleteEntry(en.id) end
  elseif e.key == "escape" then
    selIndex = 0
    if filterCat then filterCat = nil; dirty = true end
  end
end

function app.menu()
  return {{title = TR("menu_budget"), items = {
    {label = TR("new_expense"), id = 1, shortcut = "N"},
    {label = TR("new_income"), id = 2, shortcut = "I"},
    "-",
    {label = TR("export_month"), id = 3},
    {label = TR("export_all"), id = 4},
  }}, {title = TR("menu_view"), items = {
    {label = TR("prev_month"), id = 5, shortcut = "←"},
    {label = TR("next_month"), id = 6, shortcut = "→"},
    {label = TR("this_month"), id = 7},
  }}}
end

function app.onmenu(id)
  if id == 1 then openEditor(nil, "out")
  elseif id == 2 then openEditor(nil, "in")
  elseif id == 3 then exportCSV(false)
  elseif id == 4 then exportCSV(true)
  elseif id == 5 then changeMonth(-1)
  elseif id == 6 then changeMonth(1)
  elseif id == 7 then
    local d = sys.date()
    viewY, viewM = d.year, d.month
    dirty = true
  end
end

function app.close()
  saveNow()
  return true
end

return app
