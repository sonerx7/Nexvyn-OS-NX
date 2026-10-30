-- Habits for Nexvyn OS: daily check-offs, streaks, a month heatmap, statistics and reminders.
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
local function mix(c1, c2, k)
  local a, b = rgba(c1), rgba(c2)
  return {floor(a[1] + (b[1] - a[1]) * k + 0.5), floor(a[2] + (b[2] - a[2]) * k + 0.5),
          floor(a[3] + (b[3] - a[3]) * k + 0.5), floor(a[4] + (b[4] - a[4]) * k + 0.5)}
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

-- ------------------------------------------------------------------ calendar math
local function daysFromCivil(y, m, d)
  y = (m <= 2) and (y - 1) or y
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
local function isLeap(y) return (y % 4 == 0 and y % 100 ~= 0) or y % 400 == 0 end
local MDAYS = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
local function daysIn(y, m) return (m == 2 and isLeap(y)) and 29 or MDAYS[m] end
local function keyOf(dn)
  local y, m, d = civilFromDays(dn)
  return string.format("%04d-%02d-%02d", y, m, d)
end
local function dayOfKey(k)
  local y, m, d = k:match("^(%d+)-(%d+)-(%d+)$")
  if not y then return nil end
  return daysFromCivil(tonumber(y), tonumber(m), tonumber(d))
end
local function todayNum()
  local d = sys.date()
  return daysFromCivil(d.year, d.month, d.day)
end
local function mondayOf(dn) return dn - ((dn + 3) % 7) end   -- (dn + 4) % 7 is the weekday, 0 = Sunday

local MONTH_KEYS = {"m1", "m2", "m3", "m4", "m5", "m6", "m7", "m8", "m9", "m10", "m11", "m12"}
local MONTH_SHORT = {"ms1", "ms2", "ms3", "ms4", "ms5", "ms6", "ms7", "ms8", "ms9", "ms10", "ms11", "ms12"}
local DAYN_KEYS = {"wdn1", "wdn2", "wdn3", "wdn4", "wdn5", "wdn6", "wdn0"}   -- Monday first

-- ------------------------------------------------------------------ data
local COLORS = {"green", "blue", "purple", "pink", "red", "orange", "yellow", "gray"}
local ICONS = {"check", "water_drop", "menu_book", "fitness_center", "self_improvement", "directions_run", "bedtime",
               "restaurant", "code", "brush", "music_note", "savings", "spa", "smoke_free", "pets", "eco", "language",
               "psychology"}
local SUGGESTIONS = {
  {"sug_water", "water_drop", "blue"}, {"sug_read", "menu_book", "orange"},
  {"sug_exercise", "fitness_center", "red"}, {"sug_meditate", "self_improvement", "purple"},
}

local habits = {}
local nextId = 1
local reminded = {}         -- habit id -> day key of the last reminder
local tab = 1
local weekOffset = 0        -- 0 = this week
local monthY, monthM = 2026, 1
local monthHabit = 1        -- dropdown index: 1 = all habits
local stats = {}            -- habit id -> {cur, best, total}
local pops = {}             -- "id:day" -> time of last toggle (animation)
local sheet = nil
local sheetT = 0
local cursor = {row = 0, col = 0}
local lastDay = 0
local tabT = 1

local function save()
  store.set("habits", habits)
  store.set("nextId", nextId)
  store.set("tab", tab)
end
local function saveNow()
  save()
  store.save()
end

local function hcolor(h) return theme[h.color] or theme.green end

local function computeStats(h)
  local today = todayNum()
  local days = {}
  local total = 0
  for k, v in pairs(h.done) do
    if v then
      local dn = dayOfKey(k)
      if dn then days[#days + 1] = dn; total = total + 1 end
    end
  end
  table.sort(days)
  local best, run, prev = 0, 0, nil
  for _, dn in ipairs(days) do
    if prev and dn == prev + 1 then run = run + 1 elseif prev ~= dn then run = 1 end
    prev = dn
    if run > best then best = run end
  end
  local cur = 0
  local start = h.done[keyOf(today)] and today or today - 1
  while h.done[keyOf(start - cur)] do cur = cur + 1 end
  stats[h.id] = {cur = cur, best = best, total = total}
end

local function recomputeAll()
  stats = {}
  for _, h in ipairs(habits) do computeStats(h) end
end

local function isDone(h, dn) return h.done[keyOf(dn)] == true end

local function toggle(h, dn)
  local today = todayNum()
  if dn > today then
    audio.play("error")
    return
  end
  local k = keyOf(dn)
  if h.done[k] then
    h.done[k] = nil
    audio.tone(392, 0.07, 0.25, "triangle")
  else
    h.done[k] = true
    computeStats(h)
    local s = stats[h.id].cur
    audio.tone(660 + min(12, s) * 30, 0.08, 0.3, "triangle")
    timer.after(0.07, function() audio.tone(990 + min(12, s) * 30, 0.1, 0.25, "triangle") end)
  end
  pops[h.id .. ":" .. dn] = sys.time()
  computeStats(h)
  saveNow()
end

local function sanitize(h)
  if type(h) ~= "table" then return nil end
  local o = {
    id = tostring(h.id or ""), name = type(h.name) == "string" and h.name or "",
    color = type(h.color) == "string" and h.color or "green", icon = type(h.icon) == "string" and h.icon or "check",
    remind = type(h.remind) == "string" and h.remind or "", done = {},
  }
  if type(h.done) == "table" then
    for k, v in pairs(h.done) do
      if type(k) == "string" and v == true and dayOfKey(k) then o.done[k] = true end
    end
  end
  if o.id == "" then o.id = "h" .. nextId; nextId = nextId + 1 end
  return o
end

local function findHabit(id)
  for i, h in ipairs(habits) do if h.id == id then return h, i end end
end

-- ------------------------------------------------------------------ reminders
local function parseTime(s)
  local hh, mm = (s or ""):match("^(%d%d?):(%d%d)$")
  if not hh then return nil end
  hh, mm = tonumber(hh), tonumber(mm)
  if hh > 23 or mm > 59 then return nil end
  return hh, mm
end

local function checkReminders()
  local d = sys.date()
  local nowMin = d.hour * 60 + d.min
  local tk = keyOf(todayNum())
  local changed = false
  for _, h in ipairs(habits) do
    local hh, mm = parseTime(h.remind)
    if hh and nowMin >= hh * 60 + mm and nowMin < hh * 60 + mm + 180 and not h.done[tk] and reminded[h.id] ~= tk then
      reminded[h.id] = tk
      changed = true
      sys.notify(TR("remind_title"), TR("remind_body", h.name))
      audio.play("notify")
    end
  end
  if changed then store.set("reminded", reminded) end
  local today = todayNum()
  if today ~= lastDay then
    lastDay = today
    recomputeAll()
  end
end

-- ------------------------------------------------------------------ editor sheet
local function openEditor(h, preset)
  local s = {isNew = h == nil, id = h and h.id}
  if h then
    s.name, s.color, s.icon = h.name, h.color, h.icon
    local hh, mm = parseTime(h.remind)
    s.remindOn = hh ~= nil
    s.hh, s.mm = hh or 20, mm or 0
  else
    s.name, s.color, s.icon = "", COLORS[(#habits % #COLORS) + 1], "check"
    s.remindOn, s.hh, s.mm = false, 20, 0
    if preset then
      s.name, s.icon, s.color = TR(preset[1]), preset[2], preset[3]
    end
  end
  s.hhText, s.mmText = string.format("%02d", s.hh), string.format("%02d", s.mm)
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
  local name = s.name:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then
    audio.play("error")
    ui.focus("hb_name")
    editing = true
    return
  end
  s.hh = max(0, min(23, floor(tonumber(s.hhText) or s.hh)))
  s.mm = max(0, min(59, floor(tonumber(s.mmText) or s.mm)))
  local h = s.id and findHabit(s.id)
  if not h then
    h = {id = "h" .. nextId, done = {}}
    nextId = nextId + 1
    habits[#habits + 1] = h
  end
  h.name, h.color, h.icon = name, s.color, s.icon
  local newRemind = s.remindOn and string.format("%02d:%02d", s.hh, s.mm) or ""
  if newRemind ~= h.remind then reminded[h.id] = nil; store.set("reminded", reminded) end
  h.remind = newRemind
  computeStats(h)
  closeEditor()
  saveNow()
  audio.play("click")
end

local function deleteHabit(id)
  local h = findHabit(id)
  if not h then return end
  ui.alert(TR("delete_title"), TR("delete_msg", h.name), {TR("delete"), TR("cancel")}, function(b)
    if b == 1 then
      local _, i = findHabit(id)
      if i then table.remove(habits, i) end
      stats[id] = nil
      reminded[id] = nil
      store.set("reminded", reminded)
      if sheet and sheet.id == id then closeEditor() end
      monthHabit = 1
      saveNow()
      audio.play("trash")
    end
  end)
end

local function moveHabit(id, dir)
  local _, i = findHabit(id)
  if not i then return end
  local j = i + dir
  if j < 1 or j > #habits then return end
  habits[i], habits[j] = habits[j], habits[i]
  saveNow()
end

local function habitMenu(h)
  ui.contextMenu({
    {label = TR("edit"), id = 1, icon = "edit"},
    {label = TR("move_up"), id = 2, icon = "arrow_upward"},
    {label = TR("move_down"), id = 3, icon = "arrow_downward"},
    "-",
    {label = TR("delete"), id = 4, icon = "delete"},
  }, function(id)
    if id == 1 then openEditor(h)
    elseif id == 2 then moveHabit(h.id, -1)
    elseif id == 3 then moveHabit(h.id, 1)
    elseif id == 4 then deleteHabit(h.id) end
  end)
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  nextId = tonumber(store.get("nextId", 1)) or 1
  local list = store.get("habits", {})
  habits = {}
  if type(list) == "table" then
    for _, h in ipairs(list) do
      local o = sanitize(h)
      if o then habits[#habits + 1] = o end
    end
  end
  local r = store.get("reminded", {})
  reminded = {}
  if type(r) == "table" then for k, v in pairs(r) do if type(v) == "string" then reminded[tostring(k)] = v end end end
  tab = tonumber(store.get("tab", 1)) or 1
  if tab < 1 or tab > 3 then tab = 1 end
  local d = sys.date()
  monthY, monthM = d.year, d.month
  lastDay = todayNum()
  recomputeAll()
  checkReminders()
  timer.every(20, checkReminders)
end

function app.update(dt)
  if sheet then sheetT = approach(sheetT, 1, 14, dt) end
  tabT = approach(tabT, 1, 10, dt)
end

-- ------------------------------------------------------------------ shared drawing
local function popScale(key)
  local t = pops[key]
  if not t then return 1 end
  local a = sys.time() - t
  if a > 0.35 then pops[key] = nil; return 1 end
  return 1 + 0.25 * sin(a / 0.35 * pi)
end

local function checkCircle(h, dn, cx, cy, r, today, interactive, focused)
  local done = isDone(h, dn)
  local future = dn > today
  local col = hcolor(h)
  local s = popScale(h.id .. ":" .. dn)
  local hit = interactive and not future and ui.hit("c" .. h.id .. ":" .. dn, cx - r - 4, cy - r - 4, r * 2 + 8, r * 2 + 8)
  if focused then
    gfx.color(theme.accent)
    gfx.circleLine(cx, cy, r + 5, 2)
  end
  if done then
    gfx.circle(cx, cy, r * s, col)
    gfx.icon("check", cx, cy, r * 1.2 * s, WHITE)
  elseif future then
    gfx.color(fade(theme.text3, 0.5))
    gfx.circleLine(cx, cy, r - 2, 1.5)
  else
    if hit and hit.hovered then gfx.circle(cx, cy, r, fade(col, 0.18)) end
    gfx.color(dn == today and col or theme.text3)
    gfx.circleLine(cx, cy, (r - 1) * s, 2)
  end
  if hit and hit.clicked then toggle(h, dn) end
end

local function sheetBackdrop(w, h)
  gfx.rect(0, 0, w, h, 0, {0, 0, 0, floor(110 * sheetT)})
end

-- ------------------------------------------------------------------ week view
local function weekLabel(mon)
  local y1, m1, d1 = civilFromDays(mon)
  local y2, m2, d2 = civilFromDays(mon + 6)
  if m1 == m2 then return TR("week_same", d1, d2, TR(MONTH_KEYS[m1]), y1) end
  return TR("week_span", d1, TR(MONTH_SHORT[m1]), d2, TR(MONTH_SHORT[m2]), y2)
end

local function drawEmpty(w, h, top)
  local cy = top + (h - top) / 2 - 70
  gfx.circle(w / 2, cy, 42, fade(theme.green, 0.14))
  gfx.icon("done_all", w / 2, cy, 42, theme.green)
  gfx.color(theme.text)
  gfx.text(TR("empty_title"), 0, cy + 58, 20, "bold", "center", w)
  gfx.color(theme.text2)
  gfx.text(TR("empty_body"), 0, cy + 86, 14, "sans", "center", w)
  local bw, gap = 160, 10
  local total = #SUGGESTIONS * bw + (#SUGGESTIONS - 1) * gap
  for i, s in ipairs(SUGGESTIONS) do
    if ui.button(TR(s[1]) .. "##sug", (w - total) / 2 + (i - 1) * (bw + gap), cy + 124, bw, 34, "default", s[2]) then
      openEditor(nil, s)
    end
  end
end

local function drawWeek(w, h, interactive)
  local today = todayNum()
  local mon = mondayOf(today) + weekOffset * 7
  -- header
  local hy = 62
  if interactive then
    if ui.iconButton("chevron_left", 20, hy, 32, 30, theme.text2, false, "wprev") then weekOffset = weekOffset - 1; audio.play("click") end
    if ui.iconButton("chevron_right", 54, hy, 32, 30, theme.text2, false, "wnext") then weekOffset = weekOffset + 1; audio.play("click") end
  end
  gfx.color(theme.text)
  gfx.text(weekOffset == 0 and TR("this_week") or weekLabel(mon), 96, hy + 5, 16, "semibold")
  if weekOffset ~= 0 then
    gfx.color(theme.text3)
    gfx.text(weekOffset == -1 and TR("last_week") or "", 96 + gfx.textWidth(weekLabel(mon), 16, "semibold") + 10, hy + 7, 13)
    if interactive and ui.button(TR("today") .. "##wk", w - 110, hy, 90, 30) then weekOffset = 0 end
  else
    gfx.color(theme.text2)
    gfx.text(weekLabel(mon), 0, hy + 7, 13, "sans", "right", w - 20)
  end
  if #habits == 0 then
    if interactive then drawEmpty(w, h, hy + 40) end
    return
  end
  -- column geometry
  local nameW = 250
  local countW = 76
  local tx = 20
  local colW = floor((w - 40 - nameW - countW) / 7)
  local headY = hy + 44
  for i = 0, 6 do
    local dn = mon + i
    local cx = tx + nameW + i * colW
    local _, _, d = civilFromDays(dn)
    local isToday = dn == today
    if isToday then
      local stripH = min(h - headY - 12, 46 + #habits * 58 + 8)
      gfx.rect(cx + 4, headY - 4, colW - 8, stripH, 10, fade(theme.accent, theme.dark and 0.14 or 0.08))
    end
    gfx.color(isToday and theme.accent or theme.text2)
    gfx.text(TR(DAYN_KEYS[i + 1]), cx, headY, 12, "semibold", "center", colW)
    gfx.color(isToday and theme.accent or theme.text)
    gfx.text(tostring(d), cx, headY + 16, 15, isToday and "bold" or "medium", "center", colW)
  end
  gfx.color(theme.text2)
  gfx.text(TR("week_col"), tx + nameW + 7 * colW, headY, 12, "semibold", "center", countW)
  -- rows
  local rowH = 58
  local top = headY + 46
  local contentH = #habits * rowH + 8
  if interactive then ui.beginScroll("weekrows", 0, top, w, h - top - 8, contentH)
  else gfx.clip(0, top, w, h - top - 8); gfx.push(0, top) end
  for r, hb in ipairs(habits) do
    local y = (r - 1) * rowH
    local col = hcolor(hb)
    local st = stats[hb.id] or {cur = 0, best = 0, total = 0}
    if r > 1 then ui.separator(tx + 8, y, w - 28) end
    -- name area (its own clickable region, separate from the day cells)
    local nh = interactive and ui.hit("name" .. hb.id, tx, y + 4, nameW - 8, rowH - 8)
    if nh and nh.hovered then gfx.rect(tx, y + 4, nameW - 8, rowH - 8, 10, theme.hover) end
    gfx.circle(tx + 26, y + rowH / 2, 18, fade(col, 0.16))
    gfx.icon(hb.icon, tx + 26, y + rowH / 2, 20, col)
    gfx.clip(tx + 52, y, nameW - 66, rowH)
    gfx.color(theme.text)
    gfx.text(hb.name, tx + 54, y + 11, 15, "semibold")
    gfx.unclip()
    if st.cur > 0 then
      gfx.icon("local_fire_department", tx + 61, y + 40, 15, theme.orange)
      gfx.color(theme.orange)
      gfx.text(TR("streak_days", st.cur), tx + 71, y + 32, 12, "semibold")
    else
      gfx.color(theme.text3)
      gfx.text(TR("no_streak"), tx + 54, y + 32, 12)
    end
    if hb.remind ~= "" then
      gfx.icon("notifications_none", tx + nameW - 24, y + rowH / 2, 15, theme.text3)
    end
    if nh then
      if nh.clicked then openEditor(hb) end
      if nh.rightClicked then habitMenu(hb) end
    end
    -- day cells
    local cnt = 0
    for i = 0, 6 do
      local dn = mon + i
      if isDone(hb, dn) then cnt = cnt + 1 end
      local cx = tx + nameW + i * colW + colW / 2
      checkCircle(hb, dn, cx, y + rowH / 2, 15, today, interactive, interactive and cursor.row == r and cursor.col == i + 1)
    end
    -- weekly count ring
    local rx = tx + nameW + 7 * colW + countW / 2
    local ry = y + rowH / 2
    gfx.color(fade(col, 0.2))
    gfx.arc(rx, ry, 17, 0, pi * 2, 4)
    if cnt > 0 then
      gfx.color(col)
      gfx.arc(rx, ry, 17, -pi / 2, -pi / 2 + pi * 2 * cnt / 7, 4)
    end
    gfx.color(theme.text)
    gfx.text(cnt .. "/7", rx - 20, ry - 8, 12, "semibold", "center", 40)
  end
  if interactive then ui.endScroll() else gfx.pop(); gfx.unclip() end
end

-- ------------------------------------------------------------------ month view
local function monthStats(hb, y, m)
  local today = todayNum()
  local first = daysFromCivil(y, m, 1)
  local nd = daysIn(y, m)
  local done, elapsed = 0, 0
  for d = 0, nd - 1 do
    local dn = first + d
    if dn <= today then
      elapsed = elapsed + 1
      if isDone(hb, dn) then done = done + 1 end
    end
  end
  return done, elapsed
end

local function statLine(icon, color, label, value, x, y, w)
  gfx.circle(x + 16, y + 16, 16, fade(color, 0.15))
  gfx.icon(icon, x + 16, y + 16, 17, color)
  gfx.color(theme.text2)
  gfx.text(label, x + 42, y + 1, 12)
  gfx.color(theme.text)
  gfx.text(value, x + 42, y + 15, 17, "bold")
end

local function drawMonth(w, h, interactive)
  local today = todayNum()
  local hy = 62
  local names = {TR("all_habits")}
  for _, hb in ipairs(habits) do names[#names + 1] = hb.name end
  if monthHabit > #names then monthHabit = 1 end
  if interactive then
    if ui.iconButton("chevron_left", 20, hy, 32, 30, theme.text2, false, "mprev") then
      monthM = monthM - 1
      if monthM < 1 then monthM, monthY = 12, monthY - 1 end
      audio.play("click")
    end
    if ui.iconButton("chevron_right", 54, hy, 32, 30, theme.text2, false, "mnext") then
      monthM = monthM + 1
      if monthM > 12 then monthM, monthY = 1, monthY + 1 end
      audio.play("click")
    end
    monthHabit = ui.dropdown("mhabit", names, monthHabit, w - 240, hy, 220, 30)
  end
  gfx.color(theme.text)
  gfx.text(TR("month_year", TR(MONTH_KEYS[monthM]), monthY), 96, hy + 5, 16, "semibold")
  if #habits == 0 then
    gfx.color(theme.text2)
    gfx.text(TR("empty_month"), 0, h / 2, 14, "sans", "center", w)
    return
  end
  local single = monthHabit > 1 and habits[monthHabit - 1] or nil
  local col = single and hcolor(single) or theme.green
  -- calendar
  local gx, gy = 20, hy + 46
  local cw, ch = 66, 54
  for i = 0, 6 do
    gfx.color(theme.text2)
    gfx.text(TR(DAYN_KEYS[i + 1]), gx + i * cw, gy, 12, "semibold", "center", cw - 6)
  end
  gy = gy + 22
  local first = daysFromCivil(monthY, monthM, 1)
  local offset = (first + 3) % 7      -- Monday = 0
  local nd = daysIn(monthY, monthM)
  for d = 1, nd do
    local dn = first + d - 1
    local idx = offset + d - 1
    local x = gx + (idx % 7) * cw
    local y = gy + floor(idx / 7) * ch
    local frac
    if single then
      frac = isDone(single, dn) and 1 or 0
    else
      local c = 0
      for _, hb in ipairs(habits) do if isDone(hb, dn) then c = c + 1 end end
      frac = c / #habits
    end
    local future = dn > today
    local bg
    if frac > 0 then bg = mix(fade(col, 0.18), col, frac) else bg = theme.dark and "#FFFFFF0F" or "#0000000A" end
    local hit = interactive and single and not future and ui.hit("md" .. dn, x, y, cw - 6, ch - 6)
    if hit and hit.hovered then gfx.shadow(x, y, cw - 6, ch - 6, 8, 8, 2) end
    gfx.alpha(future and 0.45 or 1)
    gfx.rect(x, y, cw - 6, ch - 6, 8, bg)
    if dn == today then
      gfx.color(theme.accent)
      gfx.rectLine(x - 1, y - 1, cw - 4, ch - 4, 9, 2)
    end
    gfx.color(frac > 0.5 and WHITE or theme.text)
    gfx.text(tostring(d), x + 8, y + 6, 13, "semibold")
    if single and frac >= 1 then gfx.icon("check", x + cw - 22, y + ch - 22, 16, WHITE) end
    if not single and frac > 0 then
      gfx.color(frac > 0.5 and WHITE or theme.text2)
      gfx.text(floor(frac * 100 + 0.5) .. "%", x, y + ch - 24, 11, "medium", "right", cw - 14)
    end
    gfx.unalpha()
    if hit and hit.clicked then toggle(single, dn) end
  end
  -- side panel
  local px = gx + 7 * cw + 14
  local pw = w - px - 20
  ui.group(px, gy - 22, pw, 7 * ch - 10)
  local sx = px + 16
  local sy = gy - 8
  gfx.color(theme.text)
  gfx.clip(sx, sy, pw - 32, 24)
  gfx.text(single and single.name or TR("all_habits"), sx, sy, 15, "semibold")
  gfx.unclip()
  sy = sy + 34
  if single then
    local done, elapsed = monthStats(single, monthY, monthM)
    local st = stats[single.id] or {cur = 0, best = 0, total = 0}
    statLine("check_circle", col, TR("done_this_month"), TR("n_days", done), sx, sy, pw)
    statLine("insights", theme.blue, TR("completion"), (elapsed > 0 and floor(done / elapsed * 100 + 0.5) or 0) .. "%", sx, sy + 50, pw)
    statLine("local_fire_department", theme.orange, TR("current_streak"), TR("n_days", st.cur), sx, sy + 100, pw)
    statLine("emoji_events", theme.yellow, TR("best_streak"), TR("n_days", st.best), sx, sy + 150, pw)
    gfx.color(theme.text3)
    gfx.wrap(TR("tap_to_toggle"), sx, sy + 206, pw - 32, 12)
  else
    local done, possible = 0, 0
    for _, hb in ipairs(habits) do
      local d, e = monthStats(hb, monthY, monthM)
      done, possible = done + d, possible + e
    end
    local perfect = 0
    for d = 1, nd do
      local dn = first + d - 1
      if dn <= today then
        local all = true
        for _, hb in ipairs(habits) do if not isDone(hb, dn) then all = false break end end
        if all then perfect = perfect + 1 end
      end
    end
    statLine("check_circle", theme.green, TR("checkins_month"), tostring(done), sx, sy, pw)
    statLine("insights", theme.blue, TR("completion"), (possible > 0 and floor(done / possible * 100 + 0.5) or 0) .. "%", sx, sy + 50, pw)
    statLine("emoji_events", theme.yellow, TR("perfect_days"), TR("n_days", perfect), sx, sy + 100, pw)
    gfx.color(theme.text3)
    gfx.wrap(TR("pick_habit_hint"), sx, sy + 156, pw - 32, 12)
  end
end

-- ------------------------------------------------------------------ stats view
local function summaryCard(x, y, w, h, icon, color, value, label)
  gfx.rect(x, y, w, h, 12, theme.dark and "#FFFFFF0F" or "#0000000A")
  gfx.circle(x + 26, y + 26, 15, fade(color, 0.16))
  gfx.icon(icon, x + 26, y + 26, 17, color)
  gfx.color(theme.text)
  gfx.text(value, x + 14, y + 46, 24, "bold")
  gfx.color(theme.text2)
  gfx.text(label, x + 14, y + 76, 12)
end

local function drawStats(w, h, interactive)
  local today = todayNum()
  if #habits == 0 then
    gfx.color(theme.text2)
    gfx.text(TR("empty_month"), 0, h / 2, 14, "sans", "center", w)
    return
  end
  local y = 62
  -- summary
  local doneToday, weekDone, weekPossible, best, total = 0, 0, 0, 0, 0
  local mon = mondayOf(today)
  for _, hb in ipairs(habits) do
    if isDone(hb, today) then doneToday = doneToday + 1 end
    for dn = mon, today do
      weekPossible = weekPossible + 1
      if isDone(hb, dn) then weekDone = weekDone + 1 end
    end
    local st = stats[hb.id]
    if st then
      best = max(best, st.best)
      total = total + st.total
    end
  end
  local cw = floor((w - 40 - 3 * 12) / 4)
  summaryCard(20, y, cw, 98, "today", theme.accent, doneToday .. "/" .. #habits, TR("sum_today"))
  summaryCard(20 + (cw + 12), y, cw, 98, "insights", theme.green,
    (weekPossible > 0 and floor(weekDone / weekPossible * 100 + 0.5) or 0) .. "%", TR("sum_week"))
  summaryCard(20 + (cw + 12) * 2, y, cw, 98, "emoji_events", theme.orange, TR("n_days", best), TR("sum_best"))
  summaryCard(20 + (cw + 12) * 3, y, cw, 98, "done_all", theme.purple, tostring(total), TR("sum_total"))
  -- 12 week overall heatmap
  local hy = y + 116
  gfx.color(theme.text)
  gfx.text(TR("last_12_weeks"), 20, hy, 14, "semibold")
  local cell, gap = 14, 3
  local startMon = mondayOf(today) - 11 * 7
  local gx = 20 + 30
  local gy = hy + 26
  for i = 0, 6, 2 do
    gfx.color(theme.text3)
    gfx.text(TR(DAYN_KEYS[i + 1]), 20, gy + i * (cell + gap) - 1, 10, "medium")
  end
  for wk = 0, 11 do
    for d = 0, 6 do
      local dn = startMon + wk * 7 + d
      local x = gx + wk * (cell + gap)
      local yy = gy + d * (cell + gap)
      if dn <= today then
        local c = 0
        for _, hb in ipairs(habits) do if isDone(hb, dn) then c = c + 1 end end
        local f = c / #habits
        local bg = f > 0 and mix(fade(theme.green, 0.22), theme.green, f) or (theme.dark and "#FFFFFF12" or "#0000000F")
        gfx.rect(x, yy, cell, cell, 3, bg)
        if dn == today then
          gfx.color(theme.text2)
          gfx.rectLine(x - 1, yy - 1, cell + 2, cell + 2, 4, 1)
        end
      end
    end
  end
  -- legend
  local lx = gx
  local ly = gy + 7 * (cell + gap) + 6
  gfx.color(theme.text3)
  local lw = gfx.text(TR("less"), lx, ly, 11)
  for i = 0, 4 do
    local f = i / 4
    local bg = f > 0 and mix(fade(theme.green, 0.22), theme.green, f) or (theme.dark and "#FFFFFF12" or "#0000000F")
    gfx.rect(lx + lw + 6 + i * (cell + 2), ly, cell, cell, 3, bg)
  end
  gfx.color(theme.text3)
  gfx.text(TR("more"), lx + lw + 12 + 5 * (cell + 2), ly, 11)
  -- per habit list (right side)
  local lx2 = gx + 12 * (cell + gap) + 30
  local lw2 = w - lx2 - 20
  gfx.color(theme.text)
  gfx.text(TR("last_30_days"), lx2, hy, 14, "semibold")
  local top = hy + 26
  local rowH = 52
  local listH = h - top - 16
  if interactive then ui.beginScroll("statlist", lx2 - 4, top, lw2 + 8, listH, #habits * rowH)
  else gfx.clip(lx2 - 4, top, lw2 + 8, listH); gfx.push(lx2 - 4, top) end
  for i, hb in ipairs(habits) do
    local yy = (i - 1) * rowH
    local col = hcolor(hb)
    local c = 0
    for dn = today - 29, today do if isDone(hb, dn) then c = c + 1 end end
    local st = stats[hb.id] or {cur = 0, best = 0}
    gfx.icon(hb.icon, 16, yy + 14, 18, col)
    gfx.clip(32, yy, lw2 - 150, 28)
    gfx.color(theme.text)
    gfx.text(hb.name, 32, yy + 5, 14, "medium")
    gfx.unclip()
    gfx.color(theme.text2)
    gfx.text(TR("streak_best", st.cur, st.best), 0, yy + 6, 12, "sans", "right", lw2)
    local bw = lw2 - 64
    gfx.rect(8, yy + 32, bw, 8, 4, fade(col, 0.18))
    gfx.rect(8, yy + 32, max(8, bw * c / 30), 8, 4, col)
    gfx.color(theme.text)
    gfx.text(floor(c / 30 * 100 + 0.5) .. "%", 0, yy + 28, 12, "semibold", "right", lw2)
  end
  if interactive then ui.endScroll() else gfx.pop(); gfx.unclip() end
end

-- ------------------------------------------------------------------ editor sheet drawing
local function drawSheet(w, h)
  local s = sheet
  sheetBackdrop(w, h)
  local sw, sh = 480, 430
  local sx, sy = floor((w - sw) / 2), floor((h - sh) / 2 + (1 - sheetT) * 24)
  gfx.alpha(sheetT)
  gfx.shadow(sx, sy, sw, sh, 14, 30, 10)
  gfx.rect(sx, sy, sw, sh, 14, theme.dark and "#2C2C2E" or "#F6F6F6")
  gfx.color(theme.separator)
  gfx.rectLine(sx, sy, sw, sh, 14, 1)
  gfx.color(theme.text)
  gfx.text(s.isNew and TR("new_habit") or TR("edit_habit"), sx + 20, sy + 18, 17, "bold")
  -- preview icon
  local col = theme[s.color] or theme.green
  gfx.circle(sx + sw - 40, sy + 30, 18, fade(col, 0.16))
  gfx.icon(s.icon, sx + sw - 40, sy + 30, 20, col)
  local nm = field("hb_name", s.name, sx + 20, sy + 60, sw - 40, 32, TR("name_placeholder"))
  if nm ~= s.name then s.name = nm end
  -- colors
  local y = sy + 108
  gfx.color(theme.text2)
  gfx.text(TR("color"), sx + 20, y, 12, "semibold")
  for i, c in ipairs(COLORS) do
    local px = sx + 20 + (i - 1) * 34
    local hh = ui.hit("hc" .. c, px, y + 18, 30, 30)
    gfx.circle(px + 15, y + 33, 12, theme[c])
    if s.color == c then
      gfx.color(theme[c])
      gfx.circleLine(px + 15, y + 33, 15, 2)
    end
    if hh.clicked then s.color = c; audio.play("click") end
  end
  -- icons
  y = y + 62
  gfx.color(theme.text2)
  gfx.text(TR("icon"), sx + 20, y, 12, "semibold")
  local perRow = 9
  local pitch = floor((sw - 40) / perRow)
  for i, ic in ipairs(ICONS) do
    local c = (i - 1) % perRow
    local r = floor((i - 1) / perRow)
    local px = sx + 20 + c * pitch
    local py = y + 18 + r * 40
    local sel = s.icon == ic
    local hh = ui.hit("hi" .. ic, px, py, pitch - 4, 36)
    if sel then gfx.rect(px, py, pitch - 4, 36, 8, fade(col, 0.2))
    elseif hh.hovered then gfx.rect(px, py, pitch - 4, 36, 8, theme.hover) end
    gfx.icon(ic, px + (pitch - 4) / 2, py + 18, 21, sel and col or theme.text2)
    if hh.clicked then s.icon = ic; audio.play("click") end
  end
  -- reminder
  y = y + 18 + 2 * 40 + 14
  ui.group(sx + 20, y, sw - 40, 52)
  gfx.icon(s.remindOn and "notifications_active" or "notifications_none", sx + 42, y + 26, 20, s.remindOn and theme.accent or theme.text2)
  gfx.color(theme.text)
  gfx.text(TR("remind_me"), sx + 60, y + 17, 14)
  local nv = ui.toggle("hb_rem", s.remindOn, sx + sw - 76, y + 15)
  if nv ~= s.remindOn then s.remindOn = nv; audio.play("click") end
  if s.remindOn then
    local fx = sx + sw - 76 - 150
    local nh = field("hb_hh", s.hhText, fx, y + 10, 52, 32, "20", "numeric")
    if nh ~= s.hhText then s.hhText = nh:sub(1, 2) end
    gfx.color(theme.text)
    gfx.text(":", fx + 58, y + 15, 17, "bold")
    local nm2 = field("hb_mm", s.mmText, fx + 70, y + 10, 52, 32, "00", "numeric")
    if nm2 ~= s.mmText then s.mmText = nm2:sub(1, 2) end
  end
  -- footer
  local fy = sy + sh - 50
  ui.separator(sx, fy - 12, sx + sw)
  if not s.isNew then
    if ui.button(TR("delete") .. "##sheet", sx + 20, fy, 96, 32, "destructive") then deleteHabit(s.id) end
  end
  if ui.button(TR("cancel") .. "##sheet", sx + sw - 232, fy, 100, 32) then closeEditor(); audio.play("click") end
  if ui.button(TR("save") .. "##sheet", sx + sw - 120, fy, 100, 32, "primary") then commitEditor() end
  gfx.unalpha()
end

-- ------------------------------------------------------------------ main draw
function app.draw(w, h)
  nFields = 0
  gfx.clear(theme.bg)
  local interactive = sheet == nil
  gfx.color(theme.text)
  gfx.text(TR("title"), 20, 18, 22, "bold")
  if interactive then
    local nt = ui.segmented("tabs", {TR("tab_week"), TR("tab_month"), TR("tab_stats")}, tab, w / 2 - 150, 16, 300, 30)
    if nt ~= tab then tab = nt; tabT = 0; save(); audio.play("click") end
    local bw = max(130, gfx.textWidth(TR("new_habit"), 14, "medium") + 48)
    if ui.button(TR("new_habit") .. "##top", w - 20 - bw, 16, bw, 30, "primary", "add") then openEditor(nil) end
  end
  gfx.alpha(0.3 + 0.7 * tabT)
  gfx.push(0, (1 - tabT) * 8)
  if tab == 1 then drawWeek(w, h, interactive)
  elseif tab == 2 then drawMonth(w, h, interactive)
  else drawStats(w, h, interactive) end
  gfx.pop()
  gfx.unalpha()
  if sheet then drawSheet(w, h) end
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
  if e.key == "tab" then
    tab = tab % 3 + 1
    tabT = 0
    save()
    return
  end
  if e.key == "n" then openEditor(nil) return end
  if tab == 1 and #habits > 0 then
    if cursor.row == 0 then
      if e.key == "up" or e.key == "down" or e.key == "left" or e.key == "right" then
        cursor.row = 1
        cursor.col = (todayNum() - mondayOf(todayNum())) + 1
        return
      end
    end
    if e.key == "up" then cursor.row = max(1, cursor.row - 1)
    elseif e.key == "down" then cursor.row = min(#habits, cursor.row + 1)
    elseif e.key == "left" then
      if cursor.col <= 1 then weekOffset = weekOffset - 1; cursor.col = 7 else cursor.col = cursor.col - 1 end
    elseif e.key == "right" then
      if cursor.col >= 7 then weekOffset = weekOffset + 1; cursor.col = 1 else cursor.col = cursor.col + 1 end
    elseif (e.key == "enter" or e.key == "space") and cursor.row > 0 then
      local hb = habits[cursor.row]
      if hb then toggle(hb, mondayOf(todayNum()) + weekOffset * 7 + cursor.col - 1) end
    elseif e.key == "e" and cursor.row > 0 then
      local hb = habits[cursor.row]
      if hb then openEditor(hb) end
    elseif e.key == "escape" then
      cursor.row, cursor.col = 0, 0
    end
  elseif tab == 2 then
    if e.key == "left" then
      monthM = monthM - 1
      if monthM < 1 then monthM, monthY = 12, monthY - 1 end
    elseif e.key == "right" then
      monthM = monthM + 1
      if monthM > 12 then monthM, monthY = 1, monthY + 1 end
    elseif e.key == "up" then monthHabit = max(1, monthHabit - 1)
    elseif e.key == "down" then monthHabit = min(#habits + 1, monthHabit + 1) end
  end
end

function app.menu()
  return {{title = TR("menu_habits"), items = {
    {label = TR("new_habit"), id = 1, shortcut = "N"},
    "-",
    {label = TR("tab_week"), id = 2, checked = tab == 1},
    {label = TR("tab_month"), id = 3, checked = tab == 2},
    {label = TR("tab_stats"), id = 4, checked = tab == 3},
    "-",
    {label = TR("this_week"), id = 5},
  }}}
end

function app.onmenu(id)
  if id == 1 then openEditor(nil)
  elseif id >= 2 and id <= 4 then tab = id - 1; tabT = 0; save()
  elseif id == 5 then tab = 1; weekOffset = 0 end
end

function app.close()
  saveNow()
  return true
end

return app
