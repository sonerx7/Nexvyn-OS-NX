-- Mood Journal for Nexvyn OS: one entry per day (mood 1-5, tags, a note), a month calendar coloured by mood,
-- monthly statistics with a trend line and a distribution chart, CSV export and undo.
local app = {}

local floor, min, max, abs, sin, pi = math.floor, math.min, math.max, math.abs, math.sin, math.pi

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

-- ------------------------------------------------------------------ calendar math (pure arithmetic)
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
local keyCache = {}
local function keyOf(dn)
  local k = keyCache[dn]
  if not k then
    local y, m, d = civilFromDays(dn)
    k = string.format("%04d-%02d-%02d", y, m, d)
    keyCache[dn] = k
  end
  return k
end
local function todayNum()
  local d = sys.date()
  return daysFromCivil(d.year, d.month, d.day)
end

local MONTHS = {"m1", "m2", "m3", "m4", "m5", "m6", "m7", "m8", "m9", "m10", "m11", "m12"}
local WDAYS = {"wd1", "wd2", "wd3", "wd4", "wd5", "wd6", "wd0"}            -- Monday first
local WDAYS_LONG = {"wl0", "wl1", "wl2", "wl3", "wl4", "wl5", "wl6"}       -- index = weekday + 1, 0 = Sunday

-- ------------------------------------------------------------------ moods and tags
local MOODS = {
  {key = "mood1", icon = "sentiment_very_dissatisfied", color = "#FF453A"},
  {key = "mood2", icon = "sentiment_dissatisfied", color = "#FF9F0A"},
  {key = "mood3", icon = "sentiment_neutral", color = "#FFCC00"},
  {key = "mood4", icon = "sentiment_satisfied", color = "#8BD450"},
  {key = "mood5", icon = "sentiment_very_satisfied", color = "#30D158"},
}
local TAGS = {
  {id = "work", key = "tag_work", icon = "work"},
  {id = "family", key = "tag_family", icon = "family_restroom"},
  {id = "friends", key = "tag_friends", icon = "group"},
  {id = "sport", key = "tag_sport", icon = "fitness_center"},
  {id = "sleep", key = "tag_sleep", icon = "bedtime"},
  {id = "health", key = "tag_health", icon = "healing"},
  {id = "hobby", key = "tag_hobby", icon = "palette"},
  {id = "travel", key = "tag_travel", icon = "flight"},
  {id = "food", key = "tag_food", icon = "restaurant"},
  {id = "nature", key = "tag_nature", icon = "eco"},
}
local TAG_INDEX = {}
for i, t in ipairs(TAGS) do TAG_INDEX[t.id] = i end
local moodNames, tagNames = {}, {}

-- ------------------------------------------------------------------ state
local entries = {}       -- "YYYY-MM-DD" -> {m = 1..5, note = "", tags = {"work", ...}}
local version = 0
local tab = 1
local tabT = 1
local selDay = 0         -- selected day number (days since 1970-01-01)
local viewY, viewM = 2026, 1
local slide = 0          -- month change animation (-1..1 eased to 0)
local popT, popMood = -9, 0
local undoEntry = nil    -- {key, entry, t}
local message, messageT = "", 0
local shownDist = {0, 0, 0, 0, 0}
local shownAvg = 0

local function save()
  store.set("entries", entries)
  version = version + 1
end

local function say(s) message, messageT = s, sys.time() end

local function setMonth(y, m, dir)
  while m < 1 do m = m + 12; y = y - 1 end
  while m > 12 do m = m - 12; y = y + 1 end
  if y ~= viewY or m ~= viewM then slide = dir or 0 end
  viewY, viewM = y, m
end

local function selectDay(dn)
  local y, m = civilFromDays(dn)
  local dir = (y * 12 + m) > (viewY * 12 + viewM) and 1 or -1
  selDay = dn
  setMonth(y, m, dir)
  editing = false
end

local function entryOf(dn) return entries[keyOf(dn)] end

local function setMood(dn, m)
  if dn > todayNum() then audio.play("error"); say(TR("future_day")); return end
  local k = keyOf(dn)
  local e = entries[k]
  if e then e.m = m else entries[k] = {m = m, note = "", tags = {}} end
  popT, popMood = sys.time(), m
  undoEntry = nil
  save()
  audio.tone(330 + m * 90, 0.09, 0.3, "sine")
end

local function toggleTag(dn, id)
  local e = entryOf(dn)
  if not e then return end
  for i, t in ipairs(e.tags) do
    if t == id then table.remove(e.tags, i); save(); return end
  end
  e.tags[#e.tags + 1] = id
  save()
  audio.play("click")
end

local function deleteEntry(dn)
  local k = keyOf(dn)
  local e = entries[k]
  if not e then return end
  undoEntry = {key = k, entry = e, t = sys.time()}
  entries[k] = nil
  save()
  audio.play("trash")
end

local function undo()
  if not undoEntry then return end
  entries[undoEntry.key] = undoEntry.entry
  undoEntry = nil
  save()
  say(TR("restored"))
end

-- ------------------------------------------------------------------ month statistics (cached)
local stats = {ver = -1}
local function monthStats()
  local key = version .. ":" .. viewY .. ":" .. viewM .. ":" .. todayNum()
  if stats.ver == key then return stats end
  local s = {ver = key, sum = 0, n = 0, dist = {0, 0, 0, 0, 0}, vals = {}, tags = {}, nd = daysIn(viewY, viewM)}
  local first = daysFromCivil(viewY, viewM, 1)
  local tagCount = {}
  for d = 1, s.nd do
    local e = entries[keyOf(first + d - 1)]
    if e then
      s.sum, s.n = s.sum + e.m, s.n + 1
      s.dist[e.m] = s.dist[e.m] + 1
      s.vals[d] = e.m
      for _, t in ipairs(e.tags) do tagCount[t] = (tagCount[t] or 0) + 1 end
    end
  end
  s.avg = s.n > 0 and s.sum / s.n or 0
  -- tags ranked by use, with the average mood on the days they were used
  for id, c in pairs(tagCount) do
    if TAG_INDEX[id] then s.tags[#s.tags + 1] = {id = id, n = c} end
  end
  table.sort(s.tags, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.id < b.id end)
  for _, t in ipairs(s.tags) do
    local sum = 0
    for d = 1, s.nd do
      local e = entries[keyOf(first + d - 1)]
      if e then for _, x in ipairs(e.tags) do if x == t.id then sum = sum + e.m end end end
    end
    t.avg = sum / t.n
  end
  -- current logging streak (ends today or yesterday)
  local today = todayNum()
  local start = entries[keyOf(today)] and today or today - 1
  local streak = 0
  while streak < 3660 and entries[keyOf(start - streak)] do streak = streak + 1 end
  s.streak = streak
  local total = 0
  for _ in pairs(entries) do total = total + 1 end
  s.total = total
  stats = s
  return s
end

-- ------------------------------------------------------------------ export
local function csvField(s)
  s = tostring(s or "")
  if s:find('[,"\n]') then s = '"' .. s:gsub('"', '""') .. '"' end
  return s
end

local function exportCsv()
  local keys = {}
  for k in pairs(entries) do keys[#keys + 1] = k end
  table.sort(keys)
  local out = {"date,mood,label,tags,note"}
  for _, k in ipairs(keys) do
    local e = entries[k]
    out[#out + 1] = table.concat({k, tostring(e.m), csvField(moodNames[e.m]), csvField(table.concat(e.tags, " ")),
                                  csvField(e.note)}, ",")
  end
  local text = table.concat(out, "\n") .. "\n"
  ui.saveFile(function(path)
    if not path then return end
    if fs.write(path, text) then say(TR("saved")) else say(TR("save_failed")) end
  end, "mood.csv", TR("export_csv"))
end

local function copySummary()
  local s = monthStats()
  local lines = {TR("month_year", TR(MONTHS[viewM]), viewY)}
  if s.n == 0 then
    lines[#lines + 1] = TR("no_entries_month")
  else
    lines[#lines + 1] = TR("sum_avg", string.format("%.1f", s.avg), s.n, s.nd)
    for i = 5, 1, -1 do lines[#lines + 1] = "  " .. moodNames[i] .. ": " .. s.dist[i] end
    if #s.tags > 0 then
      local t = {}
      for i = 1, min(3, #s.tags) do t[i] = tagNames[TAG_INDEX[s.tags[i].id]] .. " (" .. s.tags[i].n .. ")" end
      lines[#lines + 1] = TR("top_tags") .. ": " .. table.concat(t, ", ")
    end
  end
  sys.clipboard(table.concat(lines, "\n"))
  say(TR("copied"))
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  for i, m in ipairs(MOODS) do moodNames[i] = TR(m.key) end
  for i, t in ipairs(TAGS) do tagNames[i] = TR(t.key) end
  entries = {}
  local raw = store.get("entries", {})
  if type(raw) == "table" then
    for k, e in pairs(raw) do
      if type(k) == "string" and k:match("^%d%d%d%d%-%d%d%-%d%d$") and type(e) == "table" then
        local m = floor(tonumber(e.m) or 0)
        if m >= 1 and m <= 5 then
          local tags = {}
          if type(e.tags) == "table" then
            for _, t in ipairs(e.tags) do if TAG_INDEX[t] then tags[#tags + 1] = t end end
          end
          entries[k] = {m = m, note = type(e.note) == "string" and e.note or "", tags = tags}
        end
      end
    end
  end
  tab = floor(tonumber(store.get("tab", 1)) or 1)
  if tab < 1 or tab > 2 then tab = 1 end
  selDay = todayNum()
  local y, m = civilFromDays(selDay)
  viewY, viewM = y, m
end

function app.update(dt)
  slide = approach(slide, 0, 12, dt)
  if abs(slide) < 0.01 then slide = 0 end
  tabT = approach(tabT, 1, 10, dt)
  if tab == 2 then
    local s = monthStats()
    local mx = 1
    for i = 1, 5 do mx = max(mx, s.dist[i]) end
    for i = 1, 5 do shownDist[i] = approach(shownDist[i], s.dist[i] / mx, 8, dt) end
    shownAvg = approach(shownAvg, s.avg, 8, dt)
  end
end

-- ------------------------------------------------------------------ drawing: shared
local function monthHeader(x, y, w, interactive)
  if interactive then
    if ui.iconButton("chevron_left", x, y, 34, 32, theme.text2, false, "mprev") then setMonth(viewY, viewM - 1, -1) end
    if ui.iconButton("chevron_right", x + 36, y, 34, 32, theme.text2, false, "mnext") then setMonth(viewY, viewM + 1, 1) end
  end
  gfx.color(theme.text)
  gfx.text(TR("month_year", TR(MONTHS[viewM]), viewY), x + 80, y + 6, 16, "semibold")
  local ty, tm = civilFromDays(todayNum())
  if interactive and (ty ~= viewY or tm ~= viewM) then
    if ui.button(TR("today") .. "##hdr", x + w - 90, y, 90, 32) then selectDay(todayNum()) end
  end
end

local function emptyIllustration(x, y, w, title, body)
  gfx.circle(x + w / 2, y + 40, 40, fade(theme.yellow, 0.16))
  gfx.icon("mood", x + w / 2, y + 40, 44, theme.orange)
  gfx.color(theme.text)
  gfx.text(title, x, y + 94, 17, "bold", "center", w)
  gfx.color(theme.text2)
  gfx.text(body, x, y + 120, 13, "sans", "center", w)
end

-- ------------------------------------------------------------------ calendar tab
local function drawCalendar(x, y, w, h, interactive)
  local today = todayNum()
  local cw = floor(w / 7)
  gfx.alpha(1 - abs(slide) * 0.8)
  gfx.push(slide * 30, 0)
  for i = 1, 7 do
    gfx.color(theme.text2)
    gfx.text(TR(WDAYS[i]), x + (i - 1) * cw, y, 12, "semibold", "center", cw - 4)
  end
  local gy = y + 22
  local ch = min(cw, floor((h - 22) / 6))
  local first = daysFromCivil(viewY, viewM, 1)
  local offset = (first + 3) % 7
  local nd = daysIn(viewY, viewM)
  for d = 1, nd do
    local dn = first + d - 1
    local idx = offset + d - 1
    local cx = x + (idx % 7) * cw
    local cy = gy + floor(idx / 7) * ch
    local e = entries[keyOf(dn)]
    local future = dn > today
    local hit = interactive and ui.hit("day" .. dn, cx, cy, cw - 4, ch - 4)
    if hit and hit.hovered then gfx.shadow(cx, cy, cw - 4, ch - 4, 8, 8, 2) end
    local bg
    if e then bg = MOODS[e.m].color else bg = theme.dark and "#FFFFFF0F" or "#0000000A" end
    gfx.alpha(future and 0.4 or 1)
    gfx.rect(cx, cy, cw - 4, ch - 4, 8, bg)
    if e and ch >= 40 then
      gfx.icon(MOODS[e.m].icon, cx + (cw - 4) / 2, cy + (ch - 4) / 2 + 6, min(26, ch * 0.42), {0, 0, 0, 120})
    end
    gfx.color(e and "#1C1C1E" or theme.text)
    gfx.text(tostring(d), cx + 6, cy + 4, 12, dn == today and "bold" or "medium")
    if e and #e.note > 0 then gfx.circle(cx + cw - 12, cy + 9, 3, {0, 0, 0, 110}) end
    gfx.unalpha()
    if dn == selDay then
      gfx.color(theme.accent)
      gfx.rectLine(cx - 2, cy - 2, cw, ch, 10, 2.5)
    elseif dn == today then
      gfx.color(theme.text2)
      gfx.rectLine(cx - 1, cy - 1, cw - 2, ch - 2, 9, 1)
    end
    if hit and hit.clicked then selDay = dn; editing = false; audio.play("click") end
  end
  gfx.pop()
  gfx.unalpha()
end

local function drawDayPanel(x, y, w, h, interactive)
  ui.group(x, y, w, h)
  local px, pw = x + 16, w - 32
  local yy, mm, dd = civilFromDays(selDay)
  local wd = (selDay + 4) % 7
  gfx.color(theme.text)
  gfx.text(TR("date_long", dd, TR(MONTHS[mm]), yy), px, y + 14, 16, "semibold")
  gfx.color(theme.text2)
  gfx.text(TR(WDAYS_LONG[wd + 1]), px, y + 36, 12)
  local e = entryOf(selDay)
  local future = selDay > todayNum()
  -- delete (or undo the last delete) in the header
  if interactive and undoEntry and sys.time() - undoEntry.t < 8 then
    if ui.button(TR("undo") .. "##ud", x + w - 112, y + 12, 96, 32, "default", "undo") then undo() end
  elseif interactive and e then
    if ui.iconButton("delete", x + w - 50, y + 12, 34, 32, theme.red, false, "de") then deleteEntry(selDay) end
  end
  -- mood faces
  local fy = y + 62
  local fw = pw / 5
  for i = 1, 5 do
    local m = MOODS[i]
    local cx = px + (i - 0.5) * fw
    local on = e and e.m == i
    local hit = interactive and not future and ui.hit("face" .. i, px + (i - 1) * fw, fy, fw, 58)
    local s = 1
    if on and popMood == i then
      local a = sys.time() - popT
      if a < 0.35 then s = 1 + 0.25 * sin(a / 0.35 * pi) end
    end
    if on then gfx.circle(cx, fy + 20, 20 * s, m.color)
    elseif hit and hit.hovered then gfx.circle(cx, fy + 20, 20, fade(m.color, 0.2)) end
    gfx.icon(m.icon, cx, fy + 20, 28 * s, on and "#1C1C1E" or (future and theme.text3 or m.color))
    gfx.color(on and theme.text or theme.text3)
    gfx.text(moodNames[i], px + (i - 1) * fw, fy + 44, 10, on and "semibold" or "sans", "center", fw)
    if hit and hit.clicked then setMood(selDay, i) end
  end
  -- tags
  local ty = fy + 70
  gfx.color(theme.text2)
  gfx.text(TR("tags"), px, ty, 12, "semibold")
  local cols = pw >= 300 and 3 or 2
  local tw = (pw - (cols - 1) * 6) / cols
  for i, t in ipairs(TAGS) do
    local c = (i - 1) % cols
    local r = (i - 1) // cols
    local bx, by = px + c * (tw + 6), ty + 18 + r * 34
    local on = false
    if e then for _, id in ipairs(e.tags) do if id == t.id then on = true break end end end
    local hit = interactive and e and ui.hit("tag" .. t.id, bx, by, tw, 30)
    gfx.rect(bx, by, tw, 30, 15, on and fade(theme.accent, 0.9) or (hit and hit.hovered and theme.hover or theme.field))
    if not on then gfx.color(theme.separator); gfx.rectLine(bx, by, tw, 30, 15, 1) end
    gfx.alpha(e and 1 or 0.4)
    gfx.icon(t.icon, bx + 16, by + 15, 15, on and "#FFFFFF" or theme.text2)
    gfx.clip(bx + 28, by, tw - 32, 30)
    gfx.color(on and "#FFFFFF" or theme.text)
    gfx.text(tagNames[i], bx + 30, by + 7, 12, on and "semibold" or "sans")
    gfx.unclip()
    gfx.unalpha()
    if hit and hit.clicked then toggleTag(selDay, t.id) end
  end
  -- note
  local rows = (#TAGS + cols - 1) // cols
  local ny = ty + 18 + rows * 34 + 8
  gfx.color(theme.text2)
  gfx.text(TR("note"), px, ny, 12, "semibold")
  if interactive then
    if e then
      local t = field("note", e.note, px, ny + 18, pw, 32, TR("note_ph"))
      if t ~= e.note then e.note = t:sub(1, 200); save() end
    else
      ui.textfield("note_off", "", px, ny + 18, pw, 32, future and TR("future_day") or TR("pick_first"), "readonly")
    end
  end
  -- status line under the note when there is room
  if message ~= "" and sys.time() - messageT < 3 and ny + 58 < y + h then
    gfx.color(theme.text2)
    gfx.text(message, px, ny + 58, 12)
  end
end

local function drawCalendarTab(w, h, interactive)
  local panelW = max(270, min(340, floor(w * 0.38)))
  local cx, cy = 20, 60
  local cw = w - panelW - 60
  monthHeader(cx, cy, cw, interactive)
  drawCalendar(cx, cy + 44, cw, h - cy - 44 - 16, interactive)
  drawDayPanel(w - panelW - 20, cy, panelW, h - cy - 16, interactive)
end

-- ------------------------------------------------------------------ statistics tab
local function card(x, y, w, h, icon, color, value, label)
  gfx.rect(x, y, w, h, 12, theme.dark and "#FFFFFF0F" or "#0000000A")
  gfx.circle(x + 26, y + 26, 15, fade(color, 0.18))
  gfx.icon(icon, x + 26, y + 26, 18, color)
  gfx.color(theme.text)
  gfx.text(value, x + 50, y + 12, 20, "bold")
  gfx.color(theme.text2)
  gfx.clip(x + 10, y, w - 20, h)
  gfx.text(label, x + 14, y + h - 24, 12)
  gfx.unclip()
end

local function drawStatsTab(w, h, interactive)
  local s = monthStats()
  monthHeader(20, 60, w - 40, interactive)
  local top = 104
  if s.n == 0 then
    emptyIllustration(20, top + 30, w - 40, TR("no_entries_month"), TR("no_entries_body"))
    if interactive and ui.button(TR("go_calendar") .. "##gc", w / 2 - 90, top + 180, 180, 34, "primary", "calendar_month") then
      tab = 1; tabT = 0
    end
    return
  end
  -- summary cards
  local gap = 12
  local cw = (w - 40 - gap * 3) / 4
  local ai = max(1, min(5, floor(s.avg + 0.5)))
  card(20, top, cw, 70, MOODS[ai].icon, MOODS[ai].color, string.format("%.1f", shownAvg), TR("avg_mood"))
  card(20 + (cw + gap), top, cw, 70, "event_note", theme.blue, s.n .. "/" .. s.nd, TR("logged_days"))
  card(20 + (cw + gap) * 2, top, cw, 70, "local_fire_department", theme.orange, tostring(s.streak), TR("streak"))
  card(20 + (cw + gap) * 3, top, cw, 70, "insights", theme.purple, tostring(s.total), TR("all_entries"))

  -- trend line for the month
  local ty = top + 86
  gfx.color(theme.text)
  gfx.text(TR("trend"), 20, ty, 14, "semibold")
  local gx, gy, gw = 50, ty + 26, w - 80
  local gh = max(80, min(150, h - ty - 26 - 190))
  for i = 1, 5 do
    local ly = gy + gh - (i - 1) / 4 * gh
    gfx.color(theme.separator)
    gfx.line(gx, ly, gx + gw, ly, 1)
    gfx.icon(MOODS[i].icon, 32, ly, 16, MOODS[i].color)
  end
  local step = gw / max(1, s.nd - 1)
  local px, py = nil, nil
  for d = 1, s.nd do
    local v = s.vals[d]
    local x = gx + (d - 1) * step
    if v then
      local y = gy + gh - (v - 1) / 4 * gh
      if px and s.vals[d - 1] then
        gfx.color(theme.accent)
        gfx.line(px, py, x, y, 2.5)
      end
      px, py = x, y
    else
      px = nil
    end
    if d == 1 or d % 5 == 0 then
      gfx.color(theme.text3)
      gfx.text(tostring(d), x - 12, gy + gh + 6, 10, "sans", "center", 24)
    end
  end
  for d = 1, s.nd do
    local v = s.vals[d]
    if v then
      local x = gx + (d - 1) * step
      local y = gy + gh - (v - 1) / 4 * gh
      gfx.circle(x, y, 5, theme.bg)
      gfx.circle(x, y, 4, MOODS[v].color)
    end
  end

  -- distribution bars (left) and tags (right)
  local by = gy + gh + 28
  local half = (w - 52) / 2
  gfx.color(theme.text)
  gfx.text(TR("distribution"), 20, by, 14, "semibold")
  local rh = max(22, min(28, (h - by - 30) / 5))
  for i = 5, 1, -1 do
    local yy = by + 22 + (5 - i) * rh
    gfx.icon(MOODS[i].icon, 30, yy + rh / 2 - 2, 16, MOODS[i].color)
    local bw = half - 90
    gfx.rect(46, yy + rh / 2 - 7, bw, 10, 5, theme.dark and "#FFFFFF12" or "#0000000F")
    local fw = bw * shownDist[i]
    if fw > 1 then gfx.rect(46, yy + rh / 2 - 7, max(10, fw), 10, 5, MOODS[i].color) end
    gfx.color(theme.text2)
    local pct = s.n > 0 and floor(s.dist[i] / s.n * 100 + 0.5) or 0
    gfx.text(s.dist[i] .. " · " .. pct .. "%", 46 + bw + 6, yy + rh / 2 - 9, 11, "medium")
  end
  local tx = 32 + half
  gfx.color(theme.text)
  gfx.text(TR("top_tags"), tx, by, 14, "semibold")
  if #s.tags == 0 then
    gfx.color(theme.text3)
    gfx.wrap(TR("no_tags"), tx, by + 26, half - 10, 12)
  end
  for i = 1, min(5, #s.tags) do
    local t = s.tags[i]
    local ti = TAG_INDEX[t.id]
    local yy = by + 22 + (i - 1) * rh
    gfx.icon(TAGS[ti].icon, tx + 10, yy + rh / 2 - 2, 15, theme.text2)
    gfx.color(theme.text)
    gfx.text(tagNames[ti] .. " ×" .. t.n, tx + 26, yy + rh / 2 - 10, 12, "medium")
    local mi = max(1, min(5, floor(t.avg + 0.5)))
    gfx.color(theme.text2)
    gfx.text(string.format("%.1f", t.avg), 0, yy + rh / 2 - 10, 12, "semibold", "right", w - 46)
    gfx.icon(MOODS[mi].icon, w - 32, yy + rh / 2 - 2, 16, MOODS[mi].color)
  end
end

-- ------------------------------------------------------------------ main draw
function app.draw(w, h)
  nFields = 0
  gfx.clear(theme.bg)
  gfx.color(theme.text)
  gfx.text(TR("title"), 20, 18, 20, "bold")
  local nt = ui.segmented("tabs", {TR("tab_calendar"), TR("tab_stats")}, tab, w - 260, 16, 240, 30)
  if nt ~= tab then tab = nt; tabT = 0; store.set("tab", tab); editing = false end
  gfx.alpha(0.3 + 0.7 * tabT)
  gfx.push(0, (1 - tabT) * 8)
  if tab == 1 then drawCalendarTab(w, h, true) else drawStatsTab(w, h, true) end
  gfx.pop()
  gfx.unalpha()
end

-- ------------------------------------------------------------------ input
function app.event(e)
  if e.type == "mousedown" then
    editing = pointInField(e.x, e.y)
    return
  end
  if e.type ~= "keydown" or type(e.key) ~= "string" then return end
  if e.ctrl then
    if e.key == "z" and not editing then undo()
    elseif e.key == "s" then exportCsv()
    elseif e.key == "c" and not editing then copySummary() end
    return
  end
  if editing then
    if e.key == "escape" or e.key == "enter" then editing = false end
    return
  end
  if e.key == "tab" then tab = tab % 2 + 1; tabT = 0; store.set("tab", tab)
  elseif e.key == "pageup" then setMonth(viewY, viewM - 1, -1)
  elseif e.key == "pagedown" then setMonth(viewY, viewM + 1, 1)
  elseif e.key == "t" then selectDay(todayNum())
  elseif tab == 1 then
    if e.key == "left" then selectDay(selDay - 1)
    elseif e.key == "right" then selectDay(selDay + 1)
    elseif e.key == "up" then selectDay(selDay - 7)
    elseif e.key == "down" then selectDay(selDay + 7)
    elseif e.key:match("^[1-5]$") then setMood(selDay, tonumber(e.key))
    elseif e.key == "delete" or e.key == "backspace" then deleteEntry(selDay) end
  else
    if e.key == "left" then setMonth(viewY, viewM - 1, -1)
    elseif e.key == "right" then setMonth(viewY, viewM + 1, 1) end
  end
end

function app.menu()
  return {
    {title = TR("menu_journal"), items = {
      {label = TR("today"), id = 1, shortcut = "T"},
      {label = TR("prev_month"), id = 2, shortcut = "PgUp"},
      {label = TR("next_month"), id = 3, shortcut = "PgDn"},
      "-",
      {label = TR("tab_calendar"), id = 4, checked = tab == 1},
      {label = TR("tab_stats"), id = 5, checked = tab == 2},
    }},
    {title = TR("menu_entry"), items = {
      {label = TR("set_mood_keys"), id = 10, shortcut = "1-5"},
      {label = TR("delete_entry"), id = 11, shortcut = "Delete"},
      {label = TR("undo"), id = 12, shortcut = "Ctrl+Z"},
      "-",
      {label = TR("copy_summary"), id = 13, shortcut = "Ctrl+C"},
      {label = TR("export_csv"), id = 14, shortcut = "Ctrl+S"},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then selectDay(todayNum())
  elseif id == 2 then setMonth(viewY, viewM - 1, -1)
  elseif id == 3 then setMonth(viewY, viewM + 1, 1)
  elseif id == 4 or id == 5 then tab = id - 3; tabT = 0; store.set("tab", tab)
  elseif id == 10 then tab = 1; say(TR("keys_hint"))
  elseif id == 11 then deleteEntry(selDay)
  elseif id == 12 then undo()
  elseif id == 13 then copySummary()
  elseif id == 14 then exportCsv() end
end

function app.close()
  store.set("entries", entries)
  store.save()
  return true
end

return app
