-- Moon Phase: the moon's phase, illumination and age for any date, the next new and full moon, and a monthly
-- calendar with a tiny moon per day. Pure date arithmetic: the mean synodic month from the new moon of
-- 2000-01-06 18:14 UTC, with the main periodic terms from Meeus (Astronomical Algorithms, ch. 49) for the
-- exact times of new moon, first quarter, full moon and last quarter.
local app = {}

local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi
local SYN = 29.530588853
local RAD = pi / 180

-- ------------------------------------------------------------------ calendar arithmetic
-- days since 1970-01-01 for a proleptic Gregorian date (H. Hinnant's algorithm)
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
  return (m <= 2) and y + 1 or y, m, d
end

local function daysInMonth(y, m)
  if m == 12 then return 31 end
  return daysFromCivil(y, m + 1, 1) - daysFromCivil(y, m, 1)
end

local function weekday(days) return (days + 4) % 7 end   -- 0 = Sunday (1970-01-01 was a Thursday)

local REF = daysFromCivil(2000, 1, 6) + (18 * 60 + 14) / 1440   -- a new moon, in Unix days (UTC)

-- time (Unix days, UTC) of lunar event k4: k4 / 4 lunations after the reference; k4 % 4 = 0 new, 1 first
-- quarter, 2 full, 3 last quarter. Mean lunation plus Meeus' largest correction terms.
local function eventTime(k4)
  local k = k4 / 4
  local q = k4 % 4
  local T = k / 1236.85
  local jde = 2451550.09766 + 29.530588861 * k + 0.00015437 * T * T
  local E = 1 - 0.002516 * T
  local M = (2.5534 + 29.10535670 * k) * RAD
  local Mp = (201.5643 + 385.81693528 * k) * RAD
  local F = (160.7108 + 390.67050284 * k) * RAD
  local c
  if q == 0 then
    c = -0.40720 * sin(Mp) + 0.17241 * E * sin(M) + 0.01608 * sin(2 * Mp) + 0.01039 * sin(2 * F)
      + 0.00739 * E * sin(Mp - M) - 0.00514 * E * sin(Mp + M) + 0.00208 * E * E * sin(2 * M)
  elseif q == 2 then
    c = -0.40614 * sin(Mp) + 0.17302 * E * sin(M) + 0.01614 * sin(2 * Mp) + 0.01043 * sin(2 * F)
      + 0.00734 * E * sin(Mp - M) - 0.00515 * E * sin(Mp + M) + 0.00209 * E * E * sin(2 * M)
  else
    c = -0.62801 * sin(Mp) + 0.17172 * E * sin(M) - 0.01183 * E * sin(Mp + M) + 0.00862 * sin(2 * Mp)
      + 0.00804 * sin(2 * F) + 0.00454 * E * sin(Mp - M) + 0.00204 * E * E * sin(2 * M)
    local W = 0.00306 - 0.00038 * E * cos(M) + 0.00026 * cos(Mp) - 0.00002 * cos(Mp - M) + 0.00002 * cos(Mp + M) + 0.00002 * cos(2 * F)
    c = c + (q == 1 and W or -W)
  end
  return jde + c - 2440587.5 - 0.0008   -- JDE -> Unix days, minus about 70 s of ΔT
end

-- the event index whose time is the last one at or before t
local function eventBefore(t)
  local k4 = floor((t - REF) / SYN * 4)
  while eventTime(k4) > t do k4 = k4 - 1 end          -- at most a step or two
  while eventTime(k4 + 1) <= t do k4 = k4 + 1 end
  return k4
end

-- phase at UTC time t: fraction of the lunation 0..1, age in days, illuminated fraction
local function phaseAt(t)
  local k4 = eventBefore(t)
  local n0 = k4 - k4 % 4                              -- the previous new moon
  local age = t - eventTime(n0)
  -- interpolate within the current quarter so that every event falls exactly on 0, 1/4, 1/2, 3/4
  local ta, tb = eventTime(k4), eventTime(k4 + 1)
  local f = ((k4 % 4) + (t - ta) / (tb - ta)) / 4
  return f, age, (1 - cos(2 * pi * f)) / 2
end

-- next event of kind q (0 new, 2 full) strictly after t
local function nextEvent(t, q)
  local k4 = eventBefore(t) + 1
  while k4 % 4 ~= q do k4 = k4 + 1 end
  return eventTime(k4)
end

-- ------------------------------------------------------------------ state
local tz = 0                         -- local offset from UTC, in days
local todayDays = 0                  -- local date of today, days since 1970
local selDays = 0                    -- selected local date
local viewY, viewM = 2026, 1          -- month shown in the calendar
local south = false                  -- southern hemisphere: the image is mirrored
local month = {}                     -- per-day cache of the shown month
local shownF, info = 0, {}           -- eased phase for the big moon, details of the selected day
local slide = 0                      -- month change animation (-1..1 -> 0)
local toast, toastT = "", 0
local MONTHS, WD_SHORT, WD_LONG, PHASES = {}, {}, {}, {}
local pts = {}
local CRATERS = {{-0.32, -0.28, 0.16}, {0.25, -0.38, 0.1}, {0.35, 0.15, 0.13}, {-0.15, 0.3, 0.11}, {-0.45, 0.12, 0.07}, {0.05, -0.05, 0.08}}

local function fmt(s, ...)
  local a = {...}
  return (s:gsub("{(%d)}", function(i) local v = a[tonumber(i) + 1]; if v ~= nil then return tostring(v) end end))
end

local function dateText(days, long)
  local y, m, d = civilFromDays(days)
  local s = d .. " " .. (MONTHS[m] or "") .. " " .. y
  if long then s = s .. ", " .. (WD_LONG[weekday(days) + 1] or "") end
  return s
end

-- local date and time of a UTC moment
local function localMoment(t)
  local lt = t + tz
  local days = floor(lt)
  local mins = floor((lt - days) * 1440 + 0.5)
  if mins >= 1440 then days, mins = days + 1, mins - 1440 end
  return days, string.format("%02d:%02d", mins // 60, mins % 60)
end

-- phase name index 1..8 for a local day: the exact event if one happens that day, otherwise the in-between phase
local function dayPhase(days)
  local t0, t1 = days - tz, days + 1 - tz
  local k4 = eventBefore(t1)
  if eventTime(k4) >= t0 then return (k4 % 4) * 2 + 1, k4 % 4 end
  local f = phaseAt(days + 0.5 - tz)
  if f < 0.25 then return 2 elseif f < 0.5 then return 4 elseif f < 0.75 then return 6 end
  return 8
end

local function buildMonth()
  month = {first = daysFromCivil(viewY, viewM, 1), n = daysInMonth(viewY, viewM), days = {}, events = {}}
  for d = 1, month.n do
    local days = month.first + d - 1
    local f, _, ill = phaseAt(days + 0.5 - tz)
    local name, ev = dayPhase(days)
    month.days[d] = {f = f, ill = ill, name = name, ev = ev}
    if ev then
      local t0 = days - tz
      local k4 = eventBefore(days + 1 - tz)
      local _, hm = localMoment(eventTime(k4))
      if eventTime(k4) >= t0 then month.events[#month.events + 1] = {day = d, ev = ev, time = hm} end
    end
  end
end

local function selectDay(days)
  selDays = days
  local t = (days == todayDays) and (sys.epoch() / 86400) or (days + 0.5 - tz)
  local f, age, ill = phaseAt(t)
  local nn, nf = nextEvent(t, 0), nextEvent(t, 2)
  local nnd, nnt = localMoment(nn)
  local nfd, nft = localMoment(nf)
  info = {f = f, age = age, ill = ill, name = dayPhase(days), newDays = nnd, newTime = nnt, fullDays = nfd, fullTime = nft,
          newIn = nn - t, fullIn = nf - t}
  local y, m = civilFromDays(days)
  if y ~= viewY or m ~= viewM then
    slide = (y * 12 + m > viewY * 12 + viewM) and 1 or -1
    viewY, viewM = y, m
    buildMonth()
  end
end

local function shiftMonth(d)
  local y, m, dd = civilFromDays(selDays)
  m = m + d
  while m > 12 do m, y = m - 12, y + 1 end
  while m < 1 do m, y = m + 12, y - 1 end
  y = max(1601, min(2399, y))
  selectDay(daysFromCivil(y, m, min(dd, daysInMonth(y, m))))
end

local function goToday()
  local d = sys.date()
  todayDays = daysFromCivil(d.year, d.month, d.day)
  selectDay(todayDays)
end

local function showToast(s) toast, toastT = s, 2 end

local function copyDay()
  local txt = dateText(selDays, true) .. "\n" .. (PHASES[info.name] or "") .. " · " ..
    fmt(TR("illum"), floor((info.ill or 0) * 100 + 0.5)) .. " · " .. fmt(TR("age"), string.format("%.1f", info.age or 0))
  sys.clipboard(txt)
  showToast(TR("copied"))
end

local function copyMonth()
  local lines = {(MONTHS[viewM] or "") .. " " .. viewY}
  for _, e in ipairs(month.events or {}) do
    lines[#lines + 1] = e.day .. " " .. (MONTHS[viewM] or "") .. " " .. e.time .. "  " .. (PHASES[e.ev * 2 + 1] or "")
  end
  sys.clipboard(table.concat(lines, "\n"))
  showToast(TR("copied_month"))
end

-- ------------------------------------------------------------------ drawing the moon
-- half disk / half ellipse on one side (side = 1 right, -1 left), drawn as a convex polygon
local function halfShape(cx, cy, rx, ry, side, n, color)
  for i = 0, n do
    local a = -pi / 2 + pi * i / n
    pts[i * 2 + 1] = cx + side * cos(a) * rx
    pts[i * 2 + 2] = cy + sin(a) * ry
  end
  for i = #pts, (n + 1) * 2 + 1, -1 do pts[i] = nil end
  gfx.poly(pts, color)
end

local DARK, LIT = "#2A2E38", "#F1E9CF"

local function drawMoon(cx, cy, r, f, detail)
  local n = detail and 28 or 10
  local theta = 2 * pi * (f % 1)
  local waxing = theta < pi
  local side = waxing and 1 or -1
  if south then side = -side end
  local k = cos(theta)                               -- 1 new, 0 quarter, -1 full
  local ill = (1 - k) / 2
  if detail then
    -- glow grows with the lit fraction
    for i = 3, 1, -1 do
      gfx.color(241, 233, 207, floor(10 * ill * (4 - i)))
      gfx.circle(cx, cy, r * (1 + i * 0.09))
    end
  end
  gfx.circle(cx, cy, r, DARK)
  if ill > 0.003 then
    halfShape(cx, cy, r, r, side, n, LIT)
    if k > 0 then halfShape(cx, cy, r * k, r, side, n, DARK)       -- crescent: cover the inner part
    else halfShape(cx, cy, r * -k, r, -side, n, LIT) end           -- gibbous: add to the other side
  end
  if detail then
    for _, c in ipairs(CRATERS) do
      gfx.color(0, 0, 0, 22)
      gfx.circle(cx + c[1] * r * (south and -1 or 1), cy + c[2] * r, c[3] * r)
    end
    gfx.color(255, 255, 255, 30)
    gfx.circleLine(cx, cy, r, 1.5)
  end
end

-- ------------------------------------------------------------------ app
function app.load(arg)
  MONTHS = {TR("m1"), TR("m2"), TR("m3"), TR("m4"), TR("m5"), TR("m6"), TR("m7"), TR("m8"), TR("m9"), TR("m10"), TR("m11"), TR("m12")}
  WD_SHORT = {TR("d0s"), TR("d1s"), TR("d2s"), TR("d3s"), TR("d4s"), TR("d5s"), TR("d6s")}
  WD_LONG = {TR("d0"), TR("d1"), TR("d2"), TR("d3"), TR("d4"), TR("d5"), TR("d6")}
  PHASES = {TR("p_new"), TR("p_wax_cres"), TR("p_first"), TR("p_wax_gib"), TR("p_full"), TR("p_wan_gib"), TR("p_last"), TR("p_wan_cres")}
  south = store.get("south", false) == true
  -- local offset from the clock: local date/time minus UTC, rounded to 15 minutes; ignored if implausible
  local d = sys.date()
  local localDays = daysFromCivil(d.year, d.month, d.day) + ((d.hour or 0) * 3600 + (d.min or 0) * 60 + (d.sec or 0)) / 86400
  local off = localDays - sys.epoch() / 86400
  off = floor(off * 96 + 0.5) / 96
  tz = abs(off) <= 14 / 24 and off or 0
  viewY, viewM = 0, 0
  goToday()
  shownF = info.f or 0
  slide = 0
end

function app.update(dt)
  toastT = max(0, toastT - dt)
  -- ease the big moon the short way round the cycle
  local d = ((info.f or 0) - shownF + 0.5) % 1 - 0.5
  shownF = (shownF + d * min(1, dt * 7)) % 1
  slide = slide * math.exp(-dt * 12)
  if abs(slide) < 0.01 then slide = 0 end
end

local function infoRow(x, y, w, label, value, sub)
  gfx.color(theme.text2)
  gfx.text(label, x, y, 13)
  gfx.color(theme.text)
  gfx.text(value, x, y, 13, "semibold", "right", w)
  if sub then
    gfx.color(theme.text3)
    gfx.text(sub, x, y + 17, 11, "sans", "right", w)
  end
end

local function inDays(dd)
  if dd < 1 then return TR("within_day") end
  return fmt(TR("in_days"), floor(dd + 0.5))
end

local function drawLeft(x, y, w, h)
  gfx.color(theme.field)
  gfx.rect(x, y, w, h, 16)
  local r = max(40, min(86, (h - 300) / 2, w / 2 - 40))
  local cx, cy = x + w / 2, y + 18 + r
  -- night sky behind the moon
  gfx.gradient(x + 8, y + 8, w - 16, r * 2 + 20, "#0B1026", "#1D2550", false, 12)
  drawMoon(cx, cy + 2, r, shownF, true)
  -- hemisphere switch: the southern hemisphere sees the moon mirrored
  local hl = south and TR("hemi_s") or TR("hemi_n")
  if ui.button(hl .. "##hemi", x + w - 16 - 70, y + 14, 70, 28, "default") then south = not south; store.set("south", south) end
  -- date with previous / next day
  local dy = y + r * 2 + 36
  if ui.iconButton("chevron_left", x + 8, dy, 34, 32, theme.text2, false, "pd") then selectDay(selDays - 1) end
  if ui.iconButton("chevron_right", x + w - 42, dy, 34, 32, theme.text2, false, "nd") then selectDay(selDays + 1) end
  gfx.color(theme.text)
  gfx.text(dateText(selDays), x + 42, dy + 2, 14, "semibold", "center", w - 84)
  gfx.color(theme.text3)
  gfx.text(WD_LONG[weekday(selDays) + 1] or "", x + 42, dy + 19, 11, "sans", "center", w - 84)
  -- phase name and details
  local py = dy + 44
  gfx.color(theme.text)
  gfx.text(PHASES[info.name] or "", x, py, 18, "bold", "center", w)
  local iy = py + 32
  local ix, iw = x + 16, w - 32
  local ill = info.ill or 0
  infoRow(ix, iy, iw, TR("illumination"), floor(ill * 100 + 0.5) .. "%")
  gfx.color(theme.separator)
  gfx.rect(ix, iy + 20, iw, 5, 2.5)
  gfx.color(LIT)
  gfx.rect(ix, iy + 20, max(5, iw * ill), 5, 2.5)
  infoRow(ix, iy + 34, iw, TR("moon_age"), fmt(TR("days_fmt"), string.format("%.1f", info.age or 0)))
  infoRow(ix, iy + 60, iw, TR("next_new"), dateText(info.newDays or 0) .. " " .. (info.newTime or ""), inDays(info.newIn or 0))
  infoRow(ix, iy + 100, iw, TR("next_full"), dateText(info.fullDays or 0) .. " " .. (info.fullTime or ""), inDays(info.fullIn or 0))
end

local function drawCalendar(x, y, w, h)
  -- header: month, arrows, today
  gfx.color(theme.text)
  gfx.text((MONTHS[viewM] or "") .. " " .. viewY, x, y + 4, 20, "bold")
  if ui.button(TR("today"), x + w - 168, y, 92, 32, "default", "today", selDays ~= todayDays) then goToday() end
  if ui.iconButton("chevron_left", x + w - 72, y, 34, 32, theme.text, false, "pm") then shiftMonth(-1) end
  if ui.iconButton("chevron_right", x + w - 34, y, 34, 32, theme.text, false, "nm") then shiftMonth(1) end
  local mondayFirst = sys.lang() ~= "en"
  local cw = w / 7
  local gy = y + 44
  for i = 0, 6 do
    local wd = mondayFirst and (i + 1) % 7 or i
    gfx.color((wd == 0 or wd == 6) and theme.text3 or theme.text2)
    gfx.text(WD_SHORT[wd + 1] or "", x + i * cw, gy, 11, "semibold", "center", cw)
  end
  local curveH = h >= 420 and 64 or 0
  local top = gy + 20
  local ch = (y + h - curveH - (curveH > 0 and 12 or 0) - top) / 6
  local lead = (weekday(month.first or 0) - (mondayFirst and 1 or 0)) % 7
  local off = slide * cw * 1.5
  gfx.clip(x - 2, top - 2, w + 4, ch * 6 + 4)
  gfx.alpha(1 - min(0.9, abs(slide)))
  for d = 1, month.n or 0 do
    local cell = lead + d - 1
    local col, row = cell % 7, cell // 7
    local cx0, cy0 = x + col * cw + off, top + row * ch
    local days = month.first + d - 1
    local md = month.days[d]
    if days == selDays then
      gfx.color(theme.accent)
      gfx.rectLine(cx0 + 2, cy0 + 2, cw - 4, ch - 4, 8, 2)
    end
    if days == todayDays then
      gfx.circle(cx0 + 13, cy0 + 13, 10, theme.accent)
      gfx.color("#FFFFFF")
    else
      gfx.color(theme.text)
    end
    gfx.text(tostring(d), cx0 + 3, cy0 + 6, 11, "semibold", "center", 20)
    local mr = max(5, min(cw, ch) * 0.2)
    local mx, my = cx0 + cw / 2 + 4, cy0 + ch / 2 + 6
    if md then
      if md.ev == 0 or md.ev == 2 then
        gfx.color(md.ev == 2 and theme.yellow or theme.blue)
        gfx.circleLine(mx, my, mr + 3, 2)
      end
      drawMoon(mx, my, mr, md.f, false)
    end
    if ui.hit("day" .. d, cx0, cy0, cw, ch).clicked then selectDay(days) end
  end
  gfx.unalpha()
  gfx.unclip()
  -- illumination over the month, with the selected day marked
  if curveH > 0 and (month.n or 0) > 1 then
    local py = y + h - curveH
    gfx.color(theme.field)
    gfx.rect(x, py, w, curveH, 10)
    gfx.color(theme.text3)
    gfx.text(TR("illum_curve"), x + 10, py + 6, 10, "semibold")
    local px, pw, ph, base = x + 10, w - 20, curveH - 28, py + curveH - 8
    local prevX, prevY
    gfx.color(theme.yellow)
    for d = 1, month.n do
      local ex = px + (d - 1) / (month.n - 1) * pw
      local ey = base - month.days[d].ill * ph
      if prevX then gfx.line(prevX, prevY, ex, ey, 2) end
      prevX, prevY = ex, ey
    end
    local sd = selDays - month.first + 1
    if month.days[sd] then
      local ex = px + (sd - 1) / (month.n - 1) * pw
      gfx.color(theme.accent)
      gfx.line(ex, py + 20, ex, base, 1)
      gfx.circle(ex, base - month.days[sd].ill * ph, 4)
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
  local lw = w >= 760 and 300 or 270
  drawLeft(16, 16, lw, h - 32)
  local rx = 16 + lw + 20
  drawCalendar(rx, 16, w - rx - 20, h - 32)
  drawToast(w, h)
end

function app.event(e)
  if e.type ~= "keydown" then return end
  local k = e.key
  if e.ctrl and k == "c" then copyDay(); return end
  if k == "left" then selectDay(selDays - 1)
  elseif k == "right" then selectDay(selDays + 1)
  elseif k == "up" then selectDay(selDays - 7)
  elseif k == "down" then selectDay(selDays + 7)
  elseif k == "pageup" then shiftMonth(-1)
  elseif k == "pagedown" then shiftMonth(1)
  elseif k == "t" or k == "home" then goToday() end
end

function app.menu()
  return {
    {title = TR("menu_go"), items = {
      {label = TR("today"), id = 1, shortcut = "T"},
      {label = TR("prev_month"), id = 2, shortcut = "PageUp"},
      {label = TR("next_month"), id = 3, shortcut = "PageDown"},
      {label = TR("prev_day"), id = 4, shortcut = "Left"},
      {label = TR("next_day"), id = 5, shortcut = "Right"},
    }},
    {title = TR("menu_moon"), items = {
      {label = TR("copy_day"), id = 10, shortcut = "Ctrl+C"},
      {label = TR("copy_month"), id = 11},
      "-",
      {label = south and TR("hemi_north") or TR("hemi_south"), id = 12},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then goToday() elseif id == 2 then shiftMonth(-1) elseif id == 3 then shiftMonth(1)
  elseif id == 4 then selectDay(selDays - 1) elseif id == 5 then selectDay(selDays + 1)
  elseif id == 10 then copyDay() elseif id == 11 then copyMonth()
  elseif id == 12 then south = not south; store.set("south", south) end
end

function app.close()
  store.save()
  return true
end

return app
