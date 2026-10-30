-- Birthdays for Nexvyn OS: people with day/month (and optional year), an upcoming list sorted by days left with
-- the age they turn, a "today!" banner, one notification per day for today/tomorrow, a month overview,
-- search, undo, clipboard summary and an iCalendar (.ics) export. Feb 29 birthdays fall on Feb 28 in common years.
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
local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local FOLD = {["Ç"] = "ç", ["Ğ"] = "ğ", ["İ"] = "i", ["Ö"] = "ö", ["Ş"] = "ş", ["Ü"] = "ü", ["ı"] = "i"}
local function fold(s)
  return (trim(s):gsub("[\195\196\197][\128-\191]", function(ch) return FOLD[ch] or ch end)):lower()
end

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

-- ------------------------------------------------------------------ dates (pure arithmetic)
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
local function today()
  local d = sys.date()
  return daysFromCivil(d.year, d.month, d.day), d.year, d.month, d.day
end
local MONTHS = {"m1", "m2", "m3", "m4", "m5", "m6", "m7", "m8", "m9", "m10", "m11", "m12"}
local WL = {"wl0", "wl1", "wl2", "wl3", "wl4", "wl5", "wl6"}   -- index = weekday + 1, 0 = Sunday

-- the day a birthday is celebrated in a given year (Feb 29 -> Feb 28 in common years)
local function occurrence(p, year)
  local d = p.d
  if p.m == 2 and d == 29 and not isLeap(year) then d = 28 end
  return daysFromCivil(year, p.m, d)
end

-- next birthday on or after today: day number, year, days left
local function nextBirthday(p, tn, ty)
  local dn, y = occurrence(p, ty), ty
  if dn < tn then y = ty + 1; dn = occurrence(p, y) end
  return dn, y, dn - tn
end

-- ------------------------------------------------------------------ state
local COLORS = {"#FF6B6B", "#FF9F0A", "#FFCC00", "#34C759", "#30B0C7", "#0A84FF", "#5E5CE6", "#AF52DE", "#FF375F"}
local monthNames, dayItems = {}, {}
local people = {}        -- { {id, name, d, m, y (0 = unknown), note} }
local nextId = 1
local version = 0
local tab, tabT = 1, 1
local search = ""
local sel = 0
local sheet, sheetT = nil, 0
local undoItem = nil
local message, messageT = "", 0
local flash = {}

local function save()
  store.set("people", people)
  store.set("nextId", nextId)
  version = version + 1
end
local function say(s) message, messageT = s, sys.time() end

local function colorOf(p)
  local h = 0
  for i = 1, #p.name do h = (h * 31 + p.name:byte(i)) % 9973 end
  return COLORS[h % #COLORS + 1]
end

local function initials(name)
  local out = {}
  for word in name:gmatch("%S+") do
    local ch = word:match("^[%z\1-\127\194-\244][\128-\191]*")
    if ch then out[#out + 1] = ch:upper() end
    if #out >= 2 then break end
  end
  return #out > 0 and table.concat(out) or "?"
end

local function dateText(p)
  return TR("day_month", p.d, monthNames[p.m] or "")
end

local function sanitize(p)
  if type(p) ~= "table" or type(p.name) ~= "string" or trim(p.name) == "" then return nil end
  local d, m, y = floor(tonumber(p.d) or 0), floor(tonumber(p.m) or 0), floor(tonumber(p.y) or 0)
  if m < 1 or m > 12 or d < 1 or d > daysIn(2000, m) then return nil end
  return {id = floor(tonumber(p.id) or 0), name = p.name, d = d, m = m, y = (y >= 1800 and y <= 3000) and y or 0,
          note = type(p.note) == "string" and p.note or ""}
end

-- ------------------------------------------------------------------ upcoming list (cached per change / day)
local upcoming, upKey = {}, ""
local todays = {}
local function buildUpcoming()
  local tn, ty = today()
  local key = version .. ":" .. tn .. ":" .. search
  if key == upKey then return end
  upKey = key
  upcoming, todays = {}, {}
  local q = fold(search)
  for _, p in ipairs(people) do
    local dn, y, left = nextBirthday(p, tn, ty)
    local row = {p = p, dn = dn, left = left, age = p.y > 0 and (y - p.y) or nil,
                 shifted = p.m == 2 and p.d == 29 and not isLeap(y)}
    if left == 0 then todays[#todays + 1] = row end
    if q == "" or fold(p.name):find(q, 1, true) then upcoming[#upcoming + 1] = row end
  end
  table.sort(upcoming, function(a, b)
    if a.left ~= b.left then return a.left < b.left end
    return fold(a.p.name) < fold(b.p.name)
  end)
  if sel > #upcoming then sel = #upcoming end
end

-- month overview: people per month sorted by day
local byMonth, bmKey = {}, ""
local function buildMonths()
  local key = tostring(version)
  if key == bmKey then return end
  bmKey = key
  byMonth = {}
  for m = 1, 12 do byMonth[m] = {} end
  for _, p in ipairs(people) do table.insert(byMonth[p.m], p) end
  for m = 1, 12 do table.sort(byMonth[m], function(a, b) if a.d ~= b.d then return a.d < b.d end return fold(a.name) < fold(b.name) end) end
end

-- ------------------------------------------------------------------ notification (once per day)
local function notifyIfDue()
  local tn, ty, tm, td = today()
  local key = string.format("%04d-%02d-%02d", ty, tm, td)
  if store.get("lastNotified", "") == key then return end
  local now, tomorrow = {}, {}
  for _, p in ipairs(people) do
    local _, _, left = nextBirthday(p, tn, ty)
    if left == 0 then now[#now + 1] = p.name elseif left == 1 then tomorrow[#tomorrow + 1] = p.name end
  end
  if #now == 0 and #tomorrow == 0 then return end
  store.set("lastNotified", key)
  if #now > 0 then sys.notify(TR("notify_today_title"), TR("notify_today", table.concat(now, ", "))) end
  if #tomorrow > 0 then sys.notify(TR("notify_tomorrow_title"), TR("notify_tomorrow", table.concat(tomorrow, ", "))) end
  audio.play("notify")
end

-- ------------------------------------------------------------------ actions
local function openEditor(p)
  local s = {isNew = p == nil, id = p and p.id}
  if p then
    s.name, s.d, s.m, s.year, s.note = p.name, p.d, p.m, p.y > 0 and tostring(p.y) or "", p.note
  else
    local _, _, tm, td = today()
    s.name, s.d, s.m, s.year, s.note = "", td, tm, "", ""
  end
  s.err = ""
  sheet, sheetT = s, 0
  editing = false
  audio.play("pop")
end

local function commitEditor()
  local s = sheet
  if not s then return end
  local name = trim(s.name)
  if name == "" then s.err = TR("err_name"); audio.play("error"); return end
  if s.d > daysIn(2000, s.m) then s.err = TR("err_day", daysIn(2000, s.m), monthNames[s.m]); audio.play("error"); return end
  local y = 0
  if trim(s.year) ~= "" then
    local tn, ty = today()
    y = tonumber(trim(s.year))
    if not y or y ~= floor(y) or y < 1900 or y > ty then s.err = TR("err_year", ty); audio.play("error"); return end
    if s.m == 2 and s.d == 29 and not isLeap(y) then s.err = TR("err_leap", y); audio.play("error"); return end
    if daysFromCivil(y, s.m, s.d) > tn then s.err = TR("err_future"); audio.play("error"); return end
  end
  local p
  for _, x in ipairs(people) do if x.id == s.id then p = x end end
  if not p then
    p = {id = nextId}
    nextId = nextId + 1
    people[#people + 1] = p
  end
  p.name, p.d, p.m, p.y, p.note = name:sub(1, 60), s.d, s.m, y, trim(s.note):sub(1, 200)
  flash[p.id] = sys.time()
  sheet = nil
  editing = false
  undoItem = nil
  save()
  audio.tone(880, 0.08, 0.25, "triangle")
end

local function deletePerson(p)
  for i, x in ipairs(people) do
    if x == p then
      table.remove(people, i)
      undoItem = {p = p, i = i, t = sys.time()}
      if sheet and sheet.id == p.id then sheet = nil end
      save()
      say(TR("deleted", p.name))
      audio.play("trash")
      return
    end
  end
end

local function undo()
  if not undoItem then return end
  table.insert(people, min(undoItem.i, #people + 1), undoItem.p)
  flash[undoItem.p.id] = sys.time()
  undoItem = nil
  save()
  say(TR("restored"))
end

local function leftText(r)
  if r.left == 0 then return TR("today_excl") elseif r.left == 1 then return TR("tomorrow") end
  return TR("in_days", r.left)
end

local function copyUpcoming()
  buildUpcoming()
  local out = {TR("upcoming_title")}
  for i = 1, min(15, #upcoming) do
    local r = upcoming[i]
    out[#out + 1] = "• " .. r.p.name .. " — " .. dateText(r.p) .. " (" .. leftText(r) ..
      (r.age and (", " .. TR("turns", r.age)) or "") .. ")"
  end
  sys.clipboard(table.concat(out, "\n"))
  say(TR("copied"))
end

-- iCalendar with one yearly all-day event per person
local function exportIcs()
  local _, ty = today()
  local out = {"BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//sonerx7//Nexvyn Birthdays//EN"}
  for _, p in ipairs(people) do
    local y = p.y > 0 and p.y or ty
    local d = p.d
    if p.m == 2 and d == 29 and not isLeap(y) then d = 28 end
    local name = p.name:gsub("[,;\\]", "\\%0")
    out[#out + 1] = "BEGIN:VEVENT"
    out[#out + 1] = "UID:birthday-" .. p.id .. "@nexvyn"
    out[#out + 1] = string.format("DTSTART;VALUE=DATE:%04d%02d%02d", y, p.m, d)
    out[#out + 1] = "RRULE:FREQ=YEARLY"
    out[#out + 1] = "SUMMARY:" .. TR("ics_summary", name)
    out[#out + 1] = "END:VEVENT"
  end
  out[#out + 1] = "END:VCALENDAR"
  local text = table.concat(out, "\r\n") .. "\r\n"
  ui.saveFile(function(path)
    if not path then return end
    if fs.write(path, text) then say(TR("ics_saved")) else say(TR("save_failed")) end
  end, "birthdays.ics", TR("export_ics"))
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  for i, k in ipairs(MONTHS) do monthNames[i] = TR(k) end
  for d = 1, 31 do dayItems[d] = tostring(d) end
  nextId = floor(tonumber(store.get("nextId", 1)) or 1)
  people = {}
  local raw = store.get("people", {})
  if type(raw) == "table" then
    for _, p in ipairs(raw) do
      local o = sanitize(p)
      if o then
        if o.id <= 0 then o.id = nextId end
        nextId = max(nextId, o.id + 1)
        people[#people + 1] = o
      end
    end
  end
  tab = floor(tonumber(store.get("tab", 1)) or 1)
  if tab < 1 or tab > 2 then tab = 1 end
  notifyIfDue()
  timer.every(600, notifyIfDue)     -- also catches midnight while the app stays open
end

function app.update(dt)
  tabT = approach(tabT, 1, 10, dt)
  if sheet then sheetT = approach(sheetT, 1, 14, dt) end
end

-- ------------------------------------------------------------------ drawing
local function avatar(p, cx, cy, r)
  local c = colorOf(p)
  gfx.gradient(cx - r, cy - r, r * 2, r * 2, c, fade(c, 0.75), false, r)
  gfx.color("#FFFFFF")
  gfx.text(initials(p.name), cx - r, cy - r * 0.55, r * 0.8, "bold", "center", r * 2)
end

local function drawBanner(x, y, w)
  local n = #todays
  local t = sys.time()
  gfx.gradient(x, y, w, 64, "#FF6B9A", "#FF9F0A", true, 14)
  -- floating sparkles
  for i = 1, 9 do
    local px = x + 20 + ((i * 97 + t * 18 * (1 + i % 3)) % (w - 40))
    local py = y + 32 + sin(t * 1.7 + i) * 20
    gfx.circle(px, py, 2 + i % 3, {255, 255, 255, 70 + (i * 23) % 80})
  end
  local s = 1 + 0.08 * sin(t * 4)
  gfx.icon("cake", x + 36, y + 32, 30 * s, "#FFFFFF")
  gfx.clip(x + 64, y, w - 80, 64)
  gfx.color("#FFFFFF")
  local r = todays[1]
  if n == 1 then
    gfx.text(TR("banner_one", r.p.name), x + 66, y + 12, 16, "bold")
    gfx.text(r.age and TR("banner_age", r.age) or TR("banner_wish"), x + 66, y + 35, 13)
  else
    gfx.text(TR("banner_many", n), x + 66, y + 12, 16, "bold")
    local names = {}
    for i = 1, min(4, n) do names[i] = todays[i].p.name end
    gfx.text(table.concat(names, ", ") .. (n > 4 and "…" or ""), x + 66, y + 35, 13)
  end
  gfx.unclip()
end

local function drawEmpty(w, y, h, searching)
  local cy = y + (h - y) / 2 - 70
  gfx.circle(w / 2, cy, 44, fade(theme.pink, 0.14))
  gfx.icon(searching and "search" or "cake", w / 2, cy, 46, theme.pink)
  gfx.color(theme.text)
  gfx.text(searching and TR("no_match") or TR("empty_title"), 0, cy + 60, 18, "bold", "center", w)
  gfx.color(theme.text2)
  gfx.text(searching and TR("no_match_body") or TR("empty_body"), 0, cy + 88, 13, "sans", "center", w)
end

local function personMenu(p)
  ui.contextMenu({
    {label = TR("edit"), id = 1, icon = "edit"},
    "-",
    {label = TR("delete"), id = 2, icon = "delete"},
  }, function(id)
    if id == 1 then openEditor(p) elseif id == 2 then deletePerson(p) end
  end)
end

local GROUPS = {{0, 0, "g_today"}, {1, 7, "g_week"}, {8, 31, "g_month"}, {32, 400, "g_later"}}
local function groupOf(left)
  for i, g in ipairs(GROUPS) do if left >= g[1] and left <= g[2] then return i end end
  return 4
end

local function drawUpcoming(w, h, interactive)
  local y = 60
  if #todays > 0 then
    drawBanner(20, y, w - 40)
    y = y + 76
  end
  if interactive and #people > 0 then
    local t = field("search", search, 20, y, w - 40, 32, TR("search_ph"), "search")
    if t ~= search then search = t:sub(1, 40); sel = 0 end
  end
  if #people > 0 then y = y + 42 end
  if #upcoming == 0 then drawEmpty(w, y, h, #people > 0) return end
  -- rows plus group headers
  local rh, hh = 58, 28
  local total, lastG = 0, 0
  for _, r in ipairs(upcoming) do
    local g = groupOf(r.left)
    if g ~= lastG then total = total + hh; lastG = g end
    total = total + rh
  end
  ui.beginScroll("upcoming", 0, y, w, h - y - 8, total + 8)
  local yy = 0
  lastG = 0
  for i, r in ipairs(upcoming) do
    local p = r.p
    local g = groupOf(r.left)
    if g ~= lastG then
      lastG = g
      gfx.color(theme.text2)
      gfx.text(TR(GROUPS[g][3]), 28, yy + 8, 12, "semibold")
      yy = yy + hh
    end
    local hit = interactive and ui.hit("p" .. p.id, 16, yy + 2, w - 32, rh - 4)
    local ft = flash[p.id]
    local fa = ft and max(0, 1 - (sys.time() - ft) / 0.8) or 0
    if fa <= 0 then flash[p.id] = nil end
    if r.left == 0 then gfx.rect(16, yy + 2, w - 32, rh - 4, 12, fade(theme.pink, 0.14)) end
    if i == sel then gfx.rect(16, yy + 2, w - 32, rh - 4, 12, fade(theme.accent, 0.14))
    elseif hit and hit.hovered then gfx.rect(16, yy + 2, w - 32, rh - 4, 12, theme.hover) end
    if fa > 0 then gfx.rect(16, yy + 2, w - 32, rh - 4, 12, fade(theme.accent, 0.25 * fa)) end
    avatar(p, 46, yy + rh / 2, 19)
    local tx, tw = 76, w - 76 - 150
    gfx.clip(tx, yy, tw, rh)
    gfx.color(theme.text)
    gfx.text(p.name, tx, yy + 10, 14, "semibold")
    gfx.color(theme.text2)
    local sub = dateText(p) .. " · " .. TR(WL[(r.dn + 4) % 7 + 1])
    if r.shifted then sub = sub .. " " .. TR("feb28") end
    if r.age then sub = sub .. " · " .. TR("turns", r.age) end
    gfx.text(sub, tx, yy + 31, 12)
    gfx.unclip()
    -- countdown chip
    local col = r.left == 0 and theme.pink or (r.left <= 7 and theme.orange or theme.text3)
    local txt = leftText(r)
    local cw = max(64, gfx.textWidth(txt, 12, "semibold") + 24)
    gfx.rect(w - 30 - cw, yy + rh / 2 - 13, cw, 26, 13, fade(col, r.left <= 7 and 0.18 or 0.12))
    gfx.color(r.left <= 7 and col or theme.text2)
    gfx.text(txt, w - 30 - cw, yy + rh / 2 - 8, 12, "semibold", "center", cw)
    if r.left == 0 then gfx.icon("celebration", w - 40 - cw, yy + rh / 2, 18, theme.pink) end
    if hit then
      if hit.clicked then sel = i; openEditor(p) end
      if hit.rightClicked then sel = i; personMenu(p) end
    end
    yy = yy + rh
  end
  ui.endScroll()
end

local function drawMonths(w, h, interactive)
  buildMonths()
  local _, _, tm = today()
  local cols = w >= 680 and 3 or 2
  local gap = 12
  local cw = (w - 40 - gap * (cols - 1)) / cols
  local lineH = 30
  -- row heights from the tallest card in each row
  local rowsH, total = {}, 0
  for r = 0, 12 // cols - 1 do
    local mx = 1
    for c = 1, cols do
      local m = r * cols + c
      if byMonth[m] then mx = max(mx, #byMonth[m]) end
    end
    rowsH[r] = 44 + mx * lineH + 8
    total = total + rowsH[r] + gap
  end
  ui.beginScroll("months", 0, 60, w, h - 68, total)
  local y = 0
  for r = 0, 12 // cols - 1 do
    for c = 1, cols do
      local m = r * cols + c
      local x = 20 + (c - 1) * (cw + gap)
      local list = byMonth[m] or {}
      local cur = m == tm
      gfx.rect(x, y, cw, rowsH[r], 12, cur and fade(theme.pink, 0.12) or (theme.dark and "#FFFFFF0A" or "#00000008"))
      if cur then gfx.color(theme.pink); gfx.rectLine(x, y, cw, rowsH[r], 12, 1.5) end
      gfx.color(cur and theme.pink or theme.text)
      gfx.text(monthNames[m], x + 14, y + 12, 14, "semibold")
      gfx.color(theme.text3)
      gfx.text(tostring(#list), 0, y + 13, 12, "medium", "right", x + cw - 14)
      if #list == 0 then
        gfx.color(theme.text3)
        gfx.text("—", x + 14, y + 44, 13)
      end
      for k, p in ipairs(list) do
        local ly = y + 40 + (k - 1) * lineH
        local hit = interactive and ui.hit("mp" .. p.id, x + 6, ly, cw - 12, lineH)
        if hit and hit.hovered then gfx.rect(x + 6, ly, cw - 12, lineH, 8, theme.hover) end
        gfx.circle(x + 26, ly + lineH / 2, 11, fade(colorOf(p), 0.85))
        gfx.color("#FFFFFF")
        gfx.text(tostring(p.d), x + 15, ly + lineH / 2 - 7, 11, "bold", "center", 22)
        gfx.clip(x + 42, ly, cw - 52, lineH)
        gfx.color(theme.text)
        gfx.text(p.name, x + 44, ly + 7, 13)
        gfx.unclip()
        if hit and hit.clicked then openEditor(p) end
        if hit and hit.rightClicked then personMenu(p) end
      end
    end
    y = y + rowsH[r] + gap
  end
  ui.endScroll()
end

local function drawSheet(w, h)
  local s = sheet
  gfx.rect(0, 0, w, h, 0, {0, 0, 0, floor(110 * sheetT)})
  local sw, shh = min(460, w - 40), 344
  local sx, sy = floor((w - sw) / 2), floor((h - shh) / 2 + (1 - sheetT) * 20)
  gfx.alpha(sheetT)
  gfx.shadow(sx, sy, sw, shh, 14, 30, 10)
  gfx.rect(sx, sy, sw, shh, 14, theme.dark and "#2C2C2E" or "#F6F6F6")
  gfx.color(theme.separator)
  gfx.rectLine(sx, sy, sw, shh, 14, 1)
  gfx.color(theme.text)
  gfx.text(s.isNew and TR("new_person") or TR("edit_person"), sx + 20, sy + 16, 17, "bold")
  local x, iw = sx + 20, sw - 40
  local y = sy + 50
  local function label(t, lx, ly) gfx.color(theme.text2); gfx.text(t, lx, ly, 12, "semibold") end
  label(TR("name"), x, y)
  local n, sub1 = field("ed_name", s.name, x, y + 18, iw, 32, TR("name_ph"))
  if n ~= s.name then s.name = n; s.err = "" end
  y = y + 60
  local dw, yw = 80, 110
  local mw = iw - dw - yw - 24
  label(TR("day"), x, y)
  label(TR("month"), x + dw + 12, y)
  label(TR("year_opt"), x + dw + mw + 24, y)
  local nd = ui.dropdown("ed_day", dayItems, s.d, x, y + 18, dw, 32)
  if nd ~= s.d then s.d = nd; s.err = "" end
  local nm = ui.dropdown("ed_month", monthNames, s.m, x + dw + 12, y + 18, mw, 32)
  if nm ~= s.m then s.m = nm; s.err = "" end
  local yr, sub2 = field("ed_year", s.year, x + dw + mw + 24, y + 18, yw, 32, "1990", "numeric")
  if yr ~= s.year then s.year = yr:sub(1, 4); s.err = "" end
  y = y + 60
  label(TR("note"), x, y)
  local nt, sub3 = field("ed_note", s.note, x, y + 18, iw, 32, TR("note_ph"))
  if nt ~= s.note then s.note = nt end
  y = y + 60
  if s.err ~= "" then
    gfx.color(theme.red)
    gfx.wrap(s.err, x, y, iw, 12)
  elseif s.m == 2 and s.d == 29 then
    gfx.color(theme.text3)
    gfx.wrap(TR("leap_hint"), x, y, iw, 12)
  end
  local fy = sy + shh - 46
  ui.separator(sx, fy - 10, sx + sw)
  if not s.isNew and ui.button(TR("delete") .. "##sh", x, fy, 92, 32, "destructive") then
    for _, p in ipairs(people) do if p.id == s.id then deletePerson(p) break end end
    sheet = nil
  end
  if sheet and ui.button(TR("cancel") .. "##sh", sx + sw - 220, fy, 96, 32) then sheet = nil; editing = false end
  if sheet and (ui.button(TR("save") .. "##sh", sx + sw - 116, fy, 96, 32, "primary") or sub1 or sub2 or sub3) then
    commitEditor()
  end
  gfx.unalpha()
end

function app.draw(w, h)
  nFields = 0
  gfx.clear(theme.bg)
  buildUpcoming()
  local interactive = sheet == nil
  gfx.color(theme.text)
  gfx.text(TR("title"), 20, 18, 20, "bold")
  if interactive then
    local segW = w >= 680 and 230 or 190
    local nt = ui.segmented("tabs", {TR("tab_upcoming"), TR("tab_months")}, tab, w - 176 - segW, 16, segW, 30)
    if nt ~= tab then tab = nt; tabT = 0; store.set("tab", tab) end
    if ui.button(TR("add_person") .. "##top", w - 164, 16, 144, 30, "primary", "person_add") then openEditor(nil) end
  end
  local undoOn = undoItem and sys.time() - undoItem.t < 8
  gfx.alpha(0.3 + 0.7 * tabT)
  gfx.push(0, (1 - tabT) * 8)
  if tab == 1 then drawUpcoming(w, h, interactive) else drawMonths(w, h, interactive) end
  gfx.pop()
  gfx.unalpha()
  if message ~= "" and sys.time() - messageT < 3 then
    local mw = gfx.textWidth(message, 12) + 28
    gfx.rect((w - mw) / 2, h - 46, mw, 28, 14, theme.dark and "#3A3A3C" or "#1C1C1E")
    gfx.color("#FFFFFF")
    gfx.text(message, (w - mw) / 2, h - 40, 12, "medium", "center", mw)
  end
  if undoOn and interactive then
    -- drawn last so it stays above the list
    if ui.button(TR("undo") .. "##undo", w - 120, h - 48, 100, 32, "default", "undo") then undo() end
  end
  if sheet then drawSheet(w, h) end
end

-- ------------------------------------------------------------------ input
function app.event(e)
  if e.type == "mousedown" then
    editing = pointInField(e.x, e.y)
    return
  end
  if e.type ~= "keydown" then return end
  if sheet then
    if e.key == "escape" then sheet = nil; editing = false
    elseif e.key == "enter" and not editing then commitEditor() end
    return
  end
  if e.ctrl then
    if e.key == "n" then openEditor(nil)
    elseif e.key == "f" then tab = 1; ui.focus("search"); editing = true
    elseif e.key == "z" and not editing then undo()
    elseif e.key == "c" and not editing then copyUpcoming()
    elseif e.key == "s" then exportIcs() end
    return
  end
  if editing then
    if e.key == "escape" or e.key == "enter" then editing = false end
    return
  end
  buildUpcoming()
  local r = upcoming[sel]
  if e.key == "tab" then tab = tab % 2 + 1; tabT = 0; store.set("tab", tab)
  elseif e.key == "down" then tab = 1; sel = min(#upcoming, sel + 1)
  elseif e.key == "up" then tab = 1; sel = max(#upcoming > 0 and 1 or 0, sel - 1)
  elseif e.key == "enter" and r and tab == 1 then openEditor(r.p)
  elseif (e.key == "delete" or e.key == "backspace") and r and tab == 1 then deletePerson(r.p)
  elseif e.key == "escape" then sel = 0 end
end

function app.menu()
  return {
    {title = TR("menu_people"), items = {
      {label = TR("add_person"), id = 1, shortcut = "Ctrl+N"},
      {label = TR("find"), id = 2, shortcut = "Ctrl+F"},
      {label = TR("edit"), id = 3, shortcut = "Enter"},
      {label = TR("delete"), id = 4, shortcut = "Delete"},
      {label = TR("undo"), id = 5, shortcut = "Ctrl+Z"},
    }},
    {title = TR("menu_view"), items = {
      {label = TR("tab_upcoming"), id = 10, checked = tab == 1},
      {label = TR("tab_months"), id = 11, checked = tab == 2, shortcut = "Tab"},
      "-",
      {label = TR("copy_upcoming"), id = 12, shortcut = "Ctrl+C"},
      {label = TR("export_ics"), id = 13, shortcut = "Ctrl+S"},
    }},
  }
end

function app.onmenu(id)
  if sheet then return end
  buildUpcoming()
  local r = upcoming[sel]
  if id == 1 then openEditor(nil)
  elseif id == 2 then tab = 1; ui.focus("search"); editing = true
  elseif id == 3 and r then openEditor(r.p)
  elseif id == 4 and r then deletePerson(r.p)
  elseif id == 5 then undo()
  elseif id == 10 or id == 11 then tab = id - 9; tabT = 0; store.set("tab", tab)
  elseif id == 12 then copyUpcoming()
  elseif id == 13 then exportIcs() end
end

function app.close()
  store.set("people", people)
  store.save()
  return true
end

return app
