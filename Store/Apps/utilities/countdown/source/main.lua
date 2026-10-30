-- Countdown for Nexvyn OS: big ticking cards counting down to the events that matter.
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

-- text-field focus tracking: app.event also receives keys typed into a focused field
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

-- ------------------------------------------------------------------ calendar math (local time)
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
local function weekday(y, m, d) return (daysFromCivil(y, m, d) + 4) % 7 end  -- 0 = Sunday

local function localOffset()
  local d = sys.date()
  local civ = daysFromCivil(d.year, d.month, d.day) * 86400 + d.hour * 3600 + d.min * 60 + d.sec
  return civ - sys.epoch()
end
local function toEpoch(y, m, d, hh, mm)
  return daysFromCivil(y, m, d) * 86400 + (hh or 0) * 3600 + (mm or 0) * 60 - localOffset()
end

-- ------------------------------------------------------------------ data
local COLORS = {"blue", "purple", "pink", "red", "orange", "yellow", "green", "gray"}
local ICONS = {"event", "celebration", "cake", "beach_access", "flight", "favorite", "school", "work",
               "sports_soccer", "music_note", "card_giftcard", "rocket_launch", "home", "star", "restaurant"}

local events = {}
local sortMode = 1          -- 1 soonest, 2 name, 3 newest
local selectedId = nil
local nextId = 1
local anim = {}             -- per event+unit digit animation state
local confetti = {}
local celebrateT = {}
local heroT = 0
local kbIndex = 0           -- keyboard focus in the grid (0 = none)
local sheet = nil           -- editor state when open
local sheetT = 0
local lastSecond = -1

local function save()
  store.set("events", events)
  store.set("sort", sortMode)
  store.set("selected", selectedId or "")
  store.set("nextId", nextId)
end
local function saveNow()
  save()
  store.save()
end

local function targetOf(e) return toEpoch(e.y, e.mo, e.d, e.hh, e.mm) end

local function sanitize(e)
  if type(e) ~= "table" then return nil end
  local now = sys.date()
  local o = {
    id = tostring(e.id or ""),
    name = type(e.name) == "string" and e.name or "",
    y = tonumber(e.y) or now.year, mo = tonumber(e.mo) or now.month, d = tonumber(e.d) or now.day,
    hh = tonumber(e.hh) or 0, mm = tonumber(e.mm) or 0,
    color = type(e.color) == "string" and e.color or "blue",
    icon = type(e.icon) == "string" and e.icon or "event",
    yearly = e.yearly == true,
    created = tonumber(e.created) or sys.epoch(),
    notified = e.notified == true,
  }
  o.mo = max(1, min(12, floor(o.mo)))
  o.d = max(1, min(daysIn(o.y, o.mo), floor(o.d)))
  o.hh = max(0, min(23, floor(o.hh)))
  o.mm = max(0, min(59, floor(o.mm)))
  if o.id == "" then o.id = "e" .. nextId; nextId = nextId + 1 end
  return o
end

local function sorted()
  local now = sys.epoch()
  local list = {}
  for i, e in ipairs(events) do list[i] = e end
  if sortMode == 1 then
    table.sort(list, function(a, b)
      local ta, tb = targetOf(a), targetOf(b)
      local pa, pb = ta < now - 86400, tb < now - 86400
      if pa ~= pb then return not pa end
      if pa then return ta > tb end
      return ta < tb
    end)
  elseif sortMode == 2 then
    table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
  else
    table.sort(list, function(a, b) return (a.created or 0) > (b.created or 0) end)
  end
  return list
end

local function findEvent(id)
  for i, e in ipairs(events) do if e.id == id then return e, i end end
  return nil
end

-- ------------------------------------------------------------------ formatting
local MONTH_KEYS = {"m1", "m2", "m3", "m4", "m5", "m6", "m7", "m8", "m9", "m10", "m11", "m12"}
local DAY_KEYS = {"wd0", "wd1", "wd2", "wd3", "wd4", "wd5", "wd6"}
local DAYN_KEYS = {"wdn0", "wdn1", "wdn2", "wdn3", "wdn4", "wdn5", "wdn6"}
local function monthName(m) return TR(MONTH_KEYS[m]) end
local function dayName(wd) return TR(DAY_KEYS[wd + 1]) end
local function dateLong(e)
  local wd = weekday(e.y, e.mo, e.d)
  return TR("date_long", e.d, monthName(e.mo), e.y, dayName(wd), string.format("%02d:%02d", e.hh, e.mm))
end
local function humanSpan(secs)
  secs = abs(secs)
  if secs < 3600 then return TR("span_min", max(1, floor(secs / 60))) end
  if secs < 86400 then return TR("span_hours", floor(secs / 3600)) end
  if secs < 86400 * 60 then return TR("span_days", floor(secs / 86400)) end
  if secs < 86400 * 730 then return TR("span_months", floor(secs / (86400 * 30.44))) end
  return TR("span_years", floor(secs / (86400 * 365.25)))
end

-- ------------------------------------------------------------------ confetti
local function celebrate(x, y, w, h)
  local cols = {"red", "orange", "yellow", "green", "blue", "purple", "pink"}
  for i = 1, 70 do
    confetti[#confetti + 1] = {
      x = x + math.random() * w, y = y + h * 0.3 + math.random() * h * 0.3,
      vx = (math.random() - 0.5) * 260, vy = -120 - math.random() * 260,
      r = math.random() * pi, vr = (math.random() - 0.5) * 10,
      c = cols[math.random(#cols)], life = 2.2 + math.random() * 1.2, s = 4 + math.random() * 4,
    }
  end
end

-- ------------------------------------------------------------------ reaching events
local heroRect = {20, 64, 680, 186}
local function checkEvents()
  local now = sys.epoch()
  local changed = false
  for _, e in ipairs(events) do
    local t = targetOf(e)
    if not e.notified and t <= now then
      e.notified = true
      changed = true
      if now - t < 86400 then
        sys.notify(TR("reached_title", e.name ~= "" and e.name or TR("untitled")), TR("reached_body"))
        audio.play("alarm")
        sys.vibrate(0.6, 200)
        celebrateT[e.id] = sys.time()
        if e.id == selectedId or not selectedId then
          celebrate(heroRect[1], heroRect[2], heroRect[3], heroRect[4])
        end
      end
    end
    if e.yearly and t + 86400 <= now then
      -- the day has passed: roll the yearly event forward
      local guard = 0
      repeat
        e.y = e.y + 1
        e.d = min(e.d, daysIn(e.y, e.mo))
        guard = guard + 1
      until targetOf(e) + 86400 > now or guard > 200
      e.notified = targetOf(e) <= now
      changed = true
    end
  end
  if changed then saveNow() end
end

-- ------------------------------------------------------------------ editor sheet
local function openEditor(e, preset)
  local d = sys.date()
  local s = {isNew = e == nil, id = e and e.id or nil}
  if e then
    s.name, s.y, s.mo, s.d, s.hh, s.mm = e.name, e.y, e.mo, e.d, e.hh, e.mm
    s.color, s.icon, s.yearly = e.color, e.icon, e.yearly
  else
    local tomorrow = sys.date(sys.epoch() + 86400)
    s.name, s.y, s.mo, s.d, s.hh, s.mm = "", tomorrow.year, tomorrow.month, tomorrow.day, 9, 0
    s.color, s.icon, s.yearly = COLORS[(#events % #COLORS) + 1], "event", false
    if preset == "newyear" then
      s.name, s.y, s.mo, s.d, s.hh, s.mm = TR("preset_newyear_name", d.year + 1), d.year + 1, 1, 1, 0, 0
      s.color, s.icon = "purple", "celebration"
    elseif preset == "birthday" then
      s.name, s.color, s.icon, s.yearly, s.hh, s.mm = TR("preset_birthday_name"), "pink", "cake", true, 0, 0
    elseif preset == "summer" then
      local y = (d.month > 6 or (d.month == 6 and d.day >= 21)) and d.year + 1 or d.year
      s.name, s.y, s.mo, s.d, s.hh, s.mm = TR("preset_summer_name"), y, 6, 21, 0, 0
      s.color, s.icon = "orange", "beach_access"
    elseif preset == "weekend" then
      local add = (6 - d.wday) % 7
      if add == 0 then add = 7 end  -- it is Saturday already: count to next weekend
      local sat = sys.date(sys.epoch() + add * 86400)
      s.name, s.y, s.mo, s.d, s.hh, s.mm = TR("preset_weekend_name"), sat.year, sat.month, sat.day, 0, 0
      s.color, s.icon = "green", "weekend"
    end
  end
  s.calY, s.calM = s.y, s.mo
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
  if name == "" then name = TR("untitled") end
  s.hh = max(0, min(23, tonumber(s.hhText) or s.hh))
  s.mm = max(0, min(59, tonumber(s.mmText) or s.mm))
  local e = s.id and findEvent(s.id) or nil
  if not e then
    e = {id = "e" .. nextId, created = sys.epoch()}
    nextId = nextId + 1
    events[#events + 1] = e
  end
  e.name, e.y, e.mo, e.d, e.hh, e.mm = name, s.y, s.mo, s.d, floor(s.hh), floor(s.mm)
  e.color, e.icon, e.yearly = s.color, s.icon, s.yearly
  e.notified = targetOf(e) <= sys.epoch()
  selectedId = e.id
  heroT = 0
  closeEditor()
  saveNow()
  audio.play("click")
end

local function deleteEvent(id)
  local e, i = findEvent(id)
  if not e then return end
  ui.alert(TR("delete_title"), TR("delete_msg", e.name), {TR("delete"), TR("cancel")}, function(b)
    if b == 1 then
      local _, idx = findEvent(id)
      if idx then table.remove(events, idx) end
      if selectedId == id then selectedId = nil end
      if sheet and sheet.id == id then closeEditor() end
      saveNow()
      audio.play("trash")
    end
  end)
end

local function duplicateEvent(id)
  local e = findEvent(id)
  if not e then return end
  local c = {}
  for k, v in pairs(e) do c[k] = v end
  c.id = "e" .. nextId
  nextId = nextId + 1
  c.created = sys.epoch()
  c.name = TR("copy_of", e.name)
  events[#events + 1] = c
  saveNow()
  audio.play("pop")
end

local function showPresets()
  ui.contextMenu({
    {label = TR("new_event"), id = 1, icon = "add"},
    "-",
    {label = TR("preset_newyear"), id = 2, icon = "celebration"},
    {label = TR("preset_birthday"), id = 3, icon = "cake"},
    {label = TR("preset_summer"), id = 4, icon = "beach_access"},
    {label = TR("preset_weekend"), id = 5, icon = "weekend"},
  }, function(id)
    if id == 1 then openEditor(nil)
    elseif id == 2 then openEditor(nil, "newyear")
    elseif id == 3 then openEditor(nil, "birthday")
    elseif id == 4 then openEditor(nil, "summer")
    elseif id == 5 then openEditor(nil, "weekend") end
  end)
end

local function eventMenu(e)
  ui.contextMenu({
    {label = TR("edit"), id = 1, icon = "edit"},
    {label = TR("duplicate"), id = 2, icon = "content_copy"},
    "-",
    {label = TR("delete"), id = 3, icon = "delete"},
  }, function(id)
    if id == 1 then openEditor(e)
    elseif id == 2 then duplicateEvent(e.id)
    elseif id == 3 then deleteEvent(e.id) end
  end)
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  nextId = tonumber(store.get("nextId", 1)) or 1
  local list = store.get("events", {})
  events = {}
  if type(list) == "table" then
    for _, e in ipairs(list) do
      local o = sanitize(e)
      if o then events[#events + 1] = o end
    end
  end
  sortMode = tonumber(store.get("sort", 1)) or 1
  if sortMode < 1 or sortMode > 3 then sortMode = 1 end
  local sel = store.get("selected", "")
  selectedId = (type(sel) == "string" and sel ~= "") and sel or nil
  -- events that passed while the app was closed: mark silently unless it was very recent
  checkEvents()
  timer.every(1, checkEvents)
end

function app.update(dt)
  heroT = approach(heroT, 1, 8, dt)
  if sheet then sheetT = approach(sheetT, 1, 14, dt) end
  local g = 520
  local i = 1
  while i <= #confetti do
    local p = confetti[i]
    p.vy = p.vy + g * dt
    p.vx = p.vx * (1 - 0.6 * dt)
    p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
    p.r = p.r + p.vr * dt
    p.life = p.life - dt
    if p.life <= 0 then
      confetti[i] = confetti[#confetti]
      confetti[#confetti] = nil
    else
      i = i + 1
    end
  end
  local s = floor(sys.time())
  if s ~= lastSecond then lastSecond = s end
end

-- ------------------------------------------------------------------ drawing: digits
local function rolling(key, value, x, y, w, size, font, color)
  local a = anim[key]
  local now = sys.time()
  if not a then
    a = {cur = value, prev = value, t = -10}
    anim[key] = a
  elseif a.cur ~= value then
    a.prev, a.cur, a.t = a.cur, value, now
  end
  local p = min(1, (now - a.t) / 0.32)
  local e = 1 - (1 - p) ^ 3
  local lh = size * 1.2
  if p >= 1 then
    gfx.color(color)
    gfx.text(a.cur, x, y, size, font, "center", w)
    return
  end
  gfx.clip(x - 4, y - 2, w + 8, lh + 4)
  local c = rgba(color)
  gfx.color(c[1], c[2], c[3], floor(c[4] * (1 - e)))
  gfx.text(a.prev, x, y - e * lh * 0.7, size, font, "center", w)
  gfx.color(c[1], c[2], c[3], floor(c[4] * e))
  gfx.text(a.cur, x, y + (1 - e) * lh * 0.7, size, font, "center", w)
  gfx.unclip()
end

local function parts(rem)
  rem = max(0, rem)
  local d = floor(rem / 86400)
  local h = floor(rem % 86400 / 3600)
  local m = floor(rem % 3600 / 60)
  local s = floor(rem % 60)
  return d, h, m, s
end

local function progressOf(e, target, now)
  local start = e.created or now
  if e.yearly then start = target - 365 * 86400 end
  if target <= start then return 1 end
  return max(0, min(1, (now - start) / (target - start)))
end

-- ------------------------------------------------------------------ drawing: hero card
local function drawHero(e, x, y, w, h, interactive)
  local now = sys.epoch()
  local target = targetOf(e)
  local rem = target - now
  local col = theme[e.color] or theme.blue
  local top = mix(col, WHITE, 0.12)
  local bottom = mix(col, "#000000", 0.28)
  local slide = (1 - heroT) * 14
  gfx.alpha(0.4 + 0.6 * heroT)
  gfx.push(0, slide)
  gfx.shadow(x, y, w, h, 16, 22, 6)
  gfx.gradient(x, y, w, h, top, bottom, false, 16)
  -- soft decorative circles
  gfx.circle(x + w - 70, y + 30, 90, {255, 255, 255, 16})
  gfx.circle(x + w - 20, y + h - 10, 60, {255, 255, 255, 12})
  -- icon + title
  gfx.circle(x + 40, y + 40, 22, {255, 255, 255, 46})
  gfx.icon(e.icon, x + 40, y + 40, 26, WHITE)
  gfx.color(WHITE)
  gfx.clip(x + 74, y + 16, w - 74 - 150, 60)
  gfx.text(e.name, x + 74, y + 18, 22, "bold")
  gfx.color(255, 255, 255, 200)
  gfx.text(dateLong(e) .. (e.yearly and ("  ·  " .. TR("yearly")) or ""), x + 74, y + 48, 13, "medium")
  gfx.unclip()
  -- edit buttons (top right)
  if interactive then
    if ui.iconButton("edit", x + w - 84, y + 14, 32, 32, WHITE, false, "hero_edit") then openEditor(e) end
    if ui.iconButton("more_horiz", x + w - 46, y + 14, 32, 32, WHITE, false, "hero_more") then eventMenu(e) end
  end
  -- body
  local by = y + 88
  if rem > 0 then
    local d, hh, mm, ss = parts(rem)
    local units = {{tostring(d), "days"}, {string.format("%02d", hh), "hours"}, {string.format("%02d", mm), "minutes"},
                   {string.format("%02d", ss), "seconds"}}
    local bw, gap = 112, 10
    for i, u in ipairs(units) do
      local bx = x + 24 + (i - 1) * (bw + gap)
      gfx.rect(bx, by, bw, 78, 12, {255, 255, 255, 38})
      rolling(e.id .. "u" .. i, u[1], bx, by + 6, bw, 38, "bold", WHITE)
      gfx.color(255, 255, 255, 210)
      gfx.text(TR(u[2]), bx, by + 56, 12, "semibold", "center", bw)
    end
  else
    local today = rem > -86400
    gfx.icon(today and "celebration" or "check_circle", x + 48, by + 38, 36, WHITE)
    gfx.color(WHITE)
    gfx.text(today and TR("today_is_day") or TR("reached"), x + 80, by + 14, 26, "bold")
    gfx.color(255, 255, 255, 210)
    gfx.text(TR("reached_ago", humanSpan(rem)), x + 80, by + 48, 14, "medium")
  end
  -- progress ring
  local p = progressOf(e, target, now)
  local rx, ry, rr = x + w - 70, by + 38, 36
  gfx.color(255, 255, 255, 50)
  gfx.arc(rx, ry, rr, 0, pi * 2, 7)
  gfx.color(WHITE)
  if p > 0.002 then gfx.arc(rx, ry, rr, -pi / 2, -pi / 2 + pi * 2 * p, 7) end
  gfx.text(floor(p * 100) .. "%", rx - 40, ry - 10, 16, "bold", "center", 80)
  gfx.pop()
  gfx.unalpha()
end

-- ------------------------------------------------------------------ drawing: small cards
-- A card's clickable area that leaves out its top-right button, so the button wins with touch and cursor alike.
local NOHIT = {hovered = false, clicked = false, doubleClicked = false, rightClicked = false}
local function cardHit(id, x, y, w, h, ew, eh)
  local a = ui.hit(id .. "a", x, y, w - ew, h)
  local b = ui.hit(id .. "b", x + w - ew, y + eh, ew, h - eh)
  return {hovered = a.hovered or b.hovered, clicked = a.clicked or b.clicked,
          doubleClicked = a.doubleClicked or b.doubleClicked, rightClicked = a.rightClicked or b.rightClicked}
end

local function drawSmall(e, idx, x, y, w, h, focused, interactive)
  local now = sys.epoch()
  local target = targetOf(e)
  local rem = target - now
  local col = theme[e.color] or theme.blue
  local hit = interactive and cardHit("card" .. e.id, x, y, w, h, 44, 44) or NOHIT
  local isSel = e.id == selectedId
  if hit.hovered then gfx.shadow(x, y, w, h, 12, 14, 4) end
  gfx.rect(x, y, w, h, 12, theme.dark and "#2A2A2D" or "#FFFFFF")
  gfx.color(isSel and col or theme.separator)
  gfx.rectLine(x, y, w, h, 12, isSel and 2 or 1)
  if focused then
    gfx.color(theme.accent)
    gfx.rectLine(x - 3, y - 3, w + 6, h + 6, 14, 2)
  end
  gfx.rect(x, y + 14, 4, h - 28, 2, col)
  gfx.circle(x + 34, y + 32, 18, fade(col, 0.16))
  gfx.icon(e.icon, x + 34, y + 32, 20, col)
  gfx.clip(x + 60, y + 10, w - 100, 50)
  gfx.color(theme.text)
  gfx.text(e.name, x + 60, y + 14, 15, "semibold")
  gfx.color(theme.text2)
  gfx.text(string.format("%02d.%02d.%04d  %02d:%02d", e.d, e.mo, e.y, e.hh, e.mm), x + 60, y + 34, 12)
  gfx.unclip()
  if interactive and ui.iconButton("more_horiz", x + w - 38, y + 10, 30, 30, theme.text2, false, "more" .. e.id) then
    eventMenu(e)
  elseif not interactive then
    gfx.icon("more_horiz", x + w - 23, y + 25, 20, theme.text2)
  end
  if rem > 0 then
    local d, hh, mm, ss = parts(rem)
    gfx.color(col)
    local dw = gfx.text(tostring(d), x + 18, y + 62, 26, "bold")
    gfx.color(theme.text2)
    gfx.text(TR("days_short"), x + 22 + dw, y + 74, 12, "semibold")
    gfx.color(theme.text)
    gfx.text(string.format("%02d:%02d:%02d", hh, mm, ss), x + w - 150, y + 66, 20, "mono", "right", 132)
  else
    gfx.color(theme.text2)
    gfx.icon("check_circle", x + 30, y + 78, 18, theme.green)
    gfx.text(rem > -86400 and TR("today_is_day") or TR("reached_ago", humanSpan(rem)), x + 46, y + 70, 13, "medium")
  end
  local p = progressOf(e, target, now)
  gfx.rect(x + 18, y + h - 14, w - 36, 4, 2, fade(col, 0.18))
  gfx.rect(x + 18, y + h - 14, max(4, (w - 36) * p), 4, 2, col)
  if hit.clicked then
    if selectedId ~= e.id then
      selectedId = e.id
      heroT = 0
      save()
      audio.play("click")
    end
    kbIndex = idx
  end
  if hit.doubleClicked then openEditor(e) end
  if hit.rightClicked then eventMenu(e) end
end

-- ------------------------------------------------------------------ drawing: editor sheet
local function stepper(id, x, y, value, onChange)
  if ui.iconButton("keyboard_arrow_up", x, y, 28, 18, theme.text2, false, id .. "u") then onChange(1) end
  if ui.iconButton("keyboard_arrow_down", x, y + 20, 28, 18, theme.text2, false, id .. "d") then onChange(-1) end
end

local function drawCalendar(s, x, y, w)
  local cell = floor(w / 7)
  -- header
  gfx.color(theme.text)
  gfx.text(TR("month_year", monthName(s.calM), s.calY), x, y + 6, 14, "semibold")
  if ui.iconButton("chevron_left", x + w - 64, y, 30, 28, theme.text2, false, "calprev") then
    s.calM = s.calM - 1
    if s.calM < 1 then s.calM, s.calY = 12, s.calY - 1 end
    audio.play("click")
  end
  if ui.iconButton("chevron_right", x + w - 32, y, 30, 28, theme.text2, false, "calnext") then
    s.calM = s.calM + 1
    if s.calM > 12 then s.calM, s.calY = 1, s.calY + 1 end
    audio.play("click")
  end
  -- weekday labels, Monday first
  local wy = y + 34
  for i = 0, 6 do
    local wd = (i + 1) % 7
    gfx.color(theme.text3)
    gfx.text(TR(DAYN_KEYS[wd + 1]), x + i * cell, wy, 11, "semibold", "center", cell)
  end
  local first = weekday(s.calY, s.calM, 1)
  local offset = (first + 6) % 7
  local nd = daysIn(s.calY, s.calM)
  local today = sys.date()
  local col = theme[s.color] or theme.accent
  local gy = wy + 18
  for d = 1, nd do
    local idx = offset + d - 1
    local cx = x + (idx % 7) * cell
    local cy = gy + floor(idx / 7) * 28
    local sel = s.y == s.calY and s.mo == s.calM and s.d == d
    local isToday = today.year == s.calY and today.month == s.calM and today.day == d
    local h = ui.hit("cal" .. d, cx, cy, cell, 28)
    if sel then
      gfx.circle(cx + cell / 2, cy + 14, 13, col)
    elseif h.hovered then
      gfx.circle(cx + cell / 2, cy + 14, 13, theme.hover)
    end
    if isToday and not sel then
      gfx.color(col)
      gfx.circleLine(cx + cell / 2, cy + 14, 13, 1.5)
    end
    gfx.color(sel and WHITE or theme.text)
    gfx.text(tostring(d), cx, cy + 6, 13, sel and "semibold" or "sans", "center", cell)
    if h.clicked then
      s.y, s.mo, s.d = s.calY, s.calM, d
      audio.play("click")
    end
  end
  return gy + 6 * 28 - y
end

local function drawSheet(w, h)
  local s = sheet
  -- dim backdrop (non-interactive)
  gfx.rect(0, 0, w, h, 0, {0, 0, 0, floor(110 * sheetT)})
  local sw, sh = 560, 452
  local sx, sy = floor((w - sw) / 2), floor((h - sh) / 2 + (1 - sheetT) * 24)
  gfx.alpha(sheetT)
  gfx.shadow(sx, sy, sw, sh, 14, 30, 10)
  gfx.rect(sx, sy, sw, sh, 14, theme.dark and "#2C2C2E" or "#F6F6F6")
  gfx.color(theme.separator)
  gfx.rectLine(sx, sy, sw, sh, 14, 1)
  gfx.color(theme.text)
  gfx.text(s.isNew and TR("new_event") or TR("edit_event"), sx + 20, sy + 18, 17, "bold")
  -- name
  local nm = field("ev_name", s.name, sx + 20, sy + 54, sw - 40, 32, TR("name_placeholder"))
  if nm ~= s.name then s.name = nm end
  -- calendar (left)
  local cx, cy = sx + 20, sy + 102
  ui.group(cx - 8, cy - 8, 268, 246)
  drawCalendar(s, cx + 2, cy, 248)
  -- right column
  local rx, rw = sx + 300, sw - 320
  local ry = cy
  gfx.color(theme.text2)
  gfx.text(TR("time"), rx, ry + 2, 12, "semibold")
  local hy = ry + 22
  local nh = field("ev_hh", s.hhText, rx, hy, 54, 34, "00", "numeric")
  if nh ~= s.hhText then
    s.hhText = nh:sub(1, 2)
    local v = tonumber(s.hhText)
    if v then s.hh = max(0, min(23, floor(v))) end
  end
  stepper("hh", rx + 56, hy - 2, s.hh, function(dv)
    s.hh = (s.hh + dv) % 24
    s.hhText = string.format("%02d", s.hh)
  end)
  gfx.color(theme.text)
  gfx.text(":", rx + 90, hy + 5, 18, "bold")
  local nmm = field("ev_mm", s.mmText, rx + 104, hy, 54, 34, "00", "numeric")
  if nmm ~= s.mmText then
    s.mmText = nmm:sub(1, 2)
    local v = tonumber(s.mmText)
    if v then s.mm = max(0, min(59, floor(v))) end
  end
  stepper("mm", rx + 160, hy - 2, s.mm, function(dv)
    local base = (s.mm // 5) * 5
    if dv < 0 and base ~= s.mm then base = base + 5 end
    s.mm = (base + dv * 5) % 60
    s.mmText = string.format("%02d", s.mm)
  end)
  -- yearly
  local yy = hy + 50
  gfx.color(theme.text)
  gfx.text(TR("repeat_yearly"), rx, yy + 3, 14)
  s.yearly = ui.toggle("ev_yearly", s.yearly, rx + rw - 40, yy)
  -- colors
  local cly = yy + 38
  gfx.color(theme.text2)
  gfx.text(TR("color"), rx, cly, 12, "semibold")
  for i, c in ipairs(COLORS) do
    local px = rx + (i - 1) * 30
    local py = cly + 18
    local hh = ui.hit("col" .. c, px, py, 28, 28)
    gfx.circle(px + 14, py + 14, 11, theme[c])
    if s.color == c then
      gfx.color(theme[c])
      gfx.circleLine(px + 14, py + 14, 14, 2)
    end
    if hh.clicked then s.color = c; audio.play("click") end
  end
  -- icons
  local iy = cly + 58
  gfx.color(theme.text2)
  gfx.text(TR("icon"), rx, iy, 12, "semibold")
  for i, ic in ipairs(ICONS) do
    local col = (i - 1) % 8
    local row = floor((i - 1) / 8)
    local px = rx + col * 30
    local py = iy + 18 + row * 34
    local sel = s.icon == ic
    local hh = ui.hit("ic" .. ic, px, py, 29, 32)
    if sel then gfx.rect(px, py, 29, 32, 7, fade(theme[s.color] or theme.accent, 0.2))
    elseif hh.hovered then gfx.rect(px, py, 29, 32, 7, theme.hover) end
    gfx.icon(ic, px + 14.5, py + 16, 19, sel and (theme[s.color] or theme.accent) or theme.text2)
    if hh.clicked then s.icon = ic; audio.play("click") end
  end
  -- footer
  local fy = sy + sh - 50
  ui.separator(sx, fy - 12, sx + sw)
  if not s.isNew then
    if ui.button(TR("delete") .. "##sheet", sx + 20, fy, 100, 32, "destructive") then deleteEvent(s.id) end
  end
  if ui.button(TR("cancel") .. "##sheet", sx + sw - 240, fy, 100, 32) then
    closeEditor()
    audio.play("click")
  end
  if ui.button(TR("save") .. "##sheet", sx + sw - 128, fy, 108, 32, "primary") then commitEditor() end
  gfx.unalpha()
end

-- ------------------------------------------------------------------ drawing: main
local SORTS = {"sort_soonest", "sort_name", "sort_newest"}
local cardRects = {}

local function drawEmpty(w, h)
  local cx, cy = w / 2, h / 2 - 40
  gfx.circle(cx, cy - 20, 44, fade(theme.accent, 0.12))
  gfx.icon("hourglass_top", cx, cy - 20, 44, theme.accent)
  gfx.color(theme.text)
  gfx.text(TR("empty_title"), 0, cy + 38, 20, "bold", "center", w)
  gfx.color(theme.text2)
  gfx.text(TR("empty_body"), 0, cy + 66, 14, "sans", "center", w)
  local presets = {{"preset_newyear", "celebration", "newyear"}, {"preset_birthday", "cake", "birthday"},
                   {"preset_summer", "beach_access", "summer"}}
  local bw = 170
  local total = #presets * bw + (#presets - 1) * 12
  for i, p in ipairs(presets) do
    if ui.button(TR(p[1]) .. "##empty", (w - total) / 2 + (i - 1) * (bw + 12), cy + 104, bw, 34, "default", p[2]) then
      openEditor(nil, p[3])
    end
  end
  if ui.button(TR("new_event") .. "##empty", w / 2 - 90, cy + 150, 180, 34, "primary", "add") then openEditor(nil) end
end

function app.draw(w, h)
  nFields = 0
  gfx.clear(theme.bg)
  -- toolbar
  gfx.color(theme.text)
  gfx.text(TR("title"), 20, 18, 22, "bold")
  local interactive = sheet == nil
  if interactive then
    local ns = ui.dropdown("sort", {TR(SORTS[1]), TR(SORTS[2]), TR(SORTS[3])}, sortMode, w - 262, 16, 160, 30)
    if ns ~= sortMode then sortMode = ns; save() end
    if ui.button(TR("add") .. "##top", w - 92, 16, 72, 30, "primary", "add") then showPresets() end
  end
  if #events == 0 then
    if interactive then drawEmpty(w, h) end
  else
    local list = sorted()
    local hero = selectedId and findEvent(selectedId) or nil
    if not hero then hero = list[1]; selectedId = hero.id end
    heroRect[1], heroRect[2], heroRect[3], heroRect[4] = 20, 64, w - 40, 186
    drawHero(hero, 20, 64, w - 40, 186, interactive)
    -- grid
    local gy = 268
    gfx.color(theme.text2)
    gfx.text(TR("all_events", #list), 20, gy, 13, "semibold")
    local top = gy + 24
    local cols = 2
    local gap = 14
    local cw = floor((w - 40 - gap) / cols)
    local ch = 104
    local rows = math.ceil(#list / cols)
    local contentH = rows * (ch + gap) + 6
    if interactive then
      ui.beginScroll("grid", 16, top, w - 32, h - top, contentH)
    else
      gfx.clip(16, top, w - 32, h - top)
      gfx.push(16, top)
    end
    for i, e in ipairs(list) do
      local c = (i - 1) % cols
      local r = floor((i - 1) / cols)
      drawSmall(e, i, 4 + c * (cw + gap), 4 + r * (ch + gap), cw, ch, interactive and kbIndex == i, interactive)
    end
    if interactive then
      ui.endScroll()
    else
      gfx.pop()
      gfx.unclip()
    end
  end
  if sheet then drawSheet(w, h) end
  -- confetti on top
  for _, p in ipairs(confetti) do
    local a = min(1, p.life / 0.6)
    local c = rgba(theme[p.c])
    gfx.color(c[1], c[2], c[3], floor(255 * a))
    local s = p.s
    local dx, dy = cos(p.r) * s, sin(p.r) * s * 0.5
    gfx.poly({p.x - dx, p.y - dy, p.x + dy, p.y - dx * 0.5, p.x + dx, p.y + dy, p.x - dy, p.y + dx * 0.5})
  end
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
  local list = sorted()
  local n = #list
  if e.key == "n" then showPresets(); return end
  if n == 0 then return end
  if e.key == "right" or e.key == "down" then
    local step = e.key == "down" and 2 or 1
    kbIndex = kbIndex == 0 and 1 or min(n, kbIndex + step)
  elseif e.key == "left" or e.key == "up" then
    local step = e.key == "up" and 2 or 1
    kbIndex = kbIndex == 0 and 1 or max(1, kbIndex - step)
  elseif e.key == "enter" or e.key == "space" then
    local ev = list[kbIndex] or list[1]
    if ev then
      if selectedId == ev.id and e.key == "enter" then openEditor(ev)
      else selectedId = ev.id; heroT = 0; save() end
    end
    return
  elseif e.key == "delete" or e.key == "backspace" then
    local ev = list[kbIndex]
    if ev then deleteEvent(ev.id) end
    return
  elseif e.key == "escape" then
    kbIndex = 0
    return
  else
    return
  end
  local ev = list[kbIndex]
  if ev and ev.id ~= selectedId then
    selectedId = ev.id
    heroT = 0
    save()
  end
  audio.play("click")
end

function app.menu()
  return {{title = TR("menu_events"), items = {
    {label = TR("new_event"), id = 1, shortcut = "N"},
    {label = TR("preset_newyear"), id = 2},
    {label = TR("preset_birthday"), id = 3},
    {label = TR("preset_summer"), id = 4},
    {label = TR("preset_weekend"), id = 5},
    "-",
    {label = TR("edit"), id = 6, enabled = selectedId ~= nil},
    {label = TR("delete"), id = 7, enabled = selectedId ~= nil},
  }}, {title = TR("menu_sort"), items = {
    {label = TR("sort_soonest"), id = 11, checked = sortMode == 1},
    {label = TR("sort_name"), id = 12, checked = sortMode == 2},
    {label = TR("sort_newest"), id = 13, checked = sortMode == 3},
  }}}
end

function app.onmenu(id)
  if id == 1 then openEditor(nil)
  elseif id == 2 then openEditor(nil, "newyear")
  elseif id == 3 then openEditor(nil, "birthday")
  elseif id == 4 then openEditor(nil, "summer")
  elseif id == 5 then openEditor(nil, "weekend")
  elseif id == 6 then
    local e = selectedId and findEvent(selectedId)
    if e then openEditor(e) end
  elseif id == 7 then
    if selectedId then deleteEvent(selectedId) end
  elseif id >= 11 and id <= 13 then
    sortMode = id - 10
    save()
  end
end

function app.close()
  saveNow()
  return true
end

return app
