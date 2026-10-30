-- Date Calculator: the difference between two dates (days, weeks, years/months/days, working days), adding or
-- subtracting years/months/weeks/days, and facts about one date (weekday, day of year, ISO week, leap year) with a
-- month calendar. All calendar math is pure arithmetic on day numbers (days since 1970-01-01, proleptic
-- Gregorian); sys.date() is only used to find today. Nexvyn OS Lua SDK.
local app = {}

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local isTR = false

-- ------------------------------------------------------------------ calendar math
-- days_from_civil / civil_from_days (Howard Hinnant), valid for any year
local function daysFromCivil(y, m, d)
  if m <= 2 then y = y - 1 end
  local era = y // 400
  local yoe = y - era * 400
  local mp = (m + 9) % 12
  local doy = (153 * mp + 2) // 5 + d - 1
  local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
  return era * 146097 + doe - 719468
end

local function civilFromDays(z)
  z = z + 719468
  local era = z // 146097
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
local DIM = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
local function daysIn(y, m) if m == 2 and isLeap(y) then return 29 end return DIM[m] or 30 end

-- 1970-01-01 was a Thursday; ISO weekday 1 = Monday … 7 = Sunday
local function isoWeekday(z) return (z + 3) % 7 + 1 end

local MIN_Z, MAX_Z = daysFromCivil(1, 1, 1), daysFromCivil(9999, 12, 31)
local function clampZ(z) if z < MIN_Z then return MIN_Z elseif z > MAX_Z then return MAX_Z end return z end

local function isoWeek(z)
  local th = z + (4 - isoWeekday(z))           -- Thursday of the same ISO week decides the year
  local wy = civilFromDays(th)
  return (th - daysFromCivil(wy, 1, 1)) // 7 + 1, wy
end

-- Monday–Friday days among the n days starting at z
local function workDays(z, n)
  if n <= 0 then return 0 end
  local c = (n // 7) * 5
  local wd = isoWeekday(z)
  for i = 0, n % 7 - 1 do
    if (wd - 1 + i) % 7 + 1 <= 5 then c = c + 1 end
  end
  return c
end

-- calendar difference a <= b as years, months, days: the most whole months that fit (day clamped to the month's
-- length, so Jan 31 + 1 month = Feb 28/29), then the remaining days
local function monthsAfter(z, months)
  local y, m, d = civilFromDays(z)
  local total = y * 12 + (m - 1) + months
  local ny, nm = total // 12, total % 12 + 1
  return daysFromCivil(ny, nm, min(d, daysIn(ny, nm)))
end

local function ymd(a, b)
  local y1, m1, d1 = civilFromDays(a)
  local y2, m2, d2 = civilFromDays(b)
  local mt = (y2 - y1) * 12 + (m2 - m1)
  if d2 < d1 then mt = mt - 1 end
  if mt < 0 then mt = 0 end
  local c = monthsAfter(a, mt)
  if c > b and mt > 0 then mt = mt - 1; c = monthsAfter(a, mt) end
  return mt // 12, mt % 12, b - c
end

-- add years and months (day clamped to the month's length), then days
local function addTo(z, years, months, days)
  local y, m, d = civilFromDays(z)
  local total = y * 12 + (m - 1) + years * 12 + months
  local ny, nm = total // 12, total % 12 + 1
  if ny < 1 or ny > 9999 then return nil end
  local r = daysFromCivil(ny, nm, min(d, daysIn(ny, nm))) + days
  if r < MIN_Z or r > MAX_Z then return nil end
  return r
end

-- ------------------------------------------------------------------ text helpers
local MONTHS, WEEKDAYS, WD_SHORT = {}, {}, {}

local function grp(n)
  local s = tostring(floor(abs(n)))
  local sep = isTR and "." or ","
  s = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
  if s:sub(1, 1) == sep then s = s:sub(2) end
  return (n < 0 and "-" or "") .. s
end

local function fmtDate(z)
  local y, m, d = civilFromDays(z)
  if isTR then return d .. " " .. (MONTHS[m] or "") .. " " .. y end
  return (MONTHS[m] or "") .. " " .. d .. ", " .. y
end

local function fmtDateLong(z) return fmtDate(z) .. ", " .. (WEEKDAYS[isoWeekday(z)] or "") end

local function ease(cur, target, dt, speed)
  local n = cur + (target - cur) * min(1, dt * (speed or 10))
  if abs(target - n) < 0.01 then n = target end
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

-- ------------------------------------------------------------------ state
local tab, tabAnim = 1, 1
local today = 0
local A, B, inclEnd = 0, 0, false        -- difference tab
local base, op = 0, 1                    -- add/subtract tab (op 1 add, 2 subtract)
local amt = {y = "", m = "", w = "", d = "30"}
local info = 0                           -- date info tab
local shownDays, selX, selY = 0, nil, nil
local toast, toastAt = nil, -10

local function say(text) toast, toastAt = text, sys.time() end

local function todayZ()
  local d = sys.date()
  return daysFromCivil(d.year, d.month, d.day)
end

local function setDate(key, z)
  z = clampZ(z)
  if key == "A" then if z ~= A then A = z; store.set("A", z) end
  elseif key == "B" then if z ~= B then B = z; store.set("B", z) end
  elseif key == "base" then if z ~= base then base = z; store.set("base", z) end
  elseif key == "info" then if z ~= info then info = z; store.set("info", z) end end
end

local function getDate(key)
  if key == "A" then return A elseif key == "B" then return B elseif key == "base" then return base end
  return info
end

local function setTab(t)
  if t >= 1 and t <= 3 and t ~= tab then tab = t; store.set("tab", t) end
end

-- whole number from a field: "" counts as 0, anything else must be an integer within the limit
local function intField(s, limit)
  s = (s or ""):gsub("%s", "")
  if s == "" then return 0 end
  local v = tonumber(s)
  if not v or v ~= floor(v) or abs(v) > limit then return nil end
  return v
end

local function addResult()
  local y, m, w, d = intField(amt.y, 9999), intField(amt.m, 120000), intField(amt.w, 500000), intField(amt.d, 3650000)
  if not (y and m and w and d) then return nil, "err_whole" end
  local s = op == 2 and -1 or 1
  local r = addTo(base, s * y, s * m, s * (w * 7 + d))
  if not r then return nil, "err_range" end
  return r
end

-- parses "26.10.2026", "26/10/2026" or "2026-10-26"
local function parseDate(s)
  s = tostring(s or "")
  local y, m, d = s:match("^%s*(%d%d%d?%d?)%-(%d%d?)%-(%d%d?)%s*$")
  if not y then d, m, y = s:match("^%s*(%d%d?)[%./](%d%d?)[%./](%d%d?%d?%d?)%s*$") end
  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  if not (y and m and d) or y < 1 or y > 9999 or m < 1 or m > 12 or d < 1 or d > daysIn(y, m) then return nil end
  return daysFromCivil(y, m, d)
end

-- ------------------------------------------------------------------ text summaries (clipboard)
local function diffSummary()
  local a, b = min(A, B), max(A, B)
  local n = b - a + (inclEnd and 1 or 0)
  local y, m, d = ymd(a, b + (inclEnd and 1 or 0))
  return table.concat({
    fmtDate(A) .. " → " .. fmtDate(B),
    TR("n_days", grp(n)),
    TR("weeks_days", grp(n // 7), n % 7),
    TR("ymd", y, m, d),
    TR("work_days") .. ": " .. grp(workDays(a, n)),
  }, "\n") .. "\n"
end

local function copyText()
  local s
  if tab == 1 then s = diffSummary()
  elseif tab == 2 then
    local r = addResult()
    if not r then say(TR("err_whole")); return end
    s = fmtDateLong(base) .. (op == 2 and " − " or " + ") .. "… = " .. fmtDateLong(r) .. "\n"
  else
    local wk, wy = isoWeek(info)
    local y = civilFromDays(info)
    s = fmtDateLong(info) .. "\n" .. TR("iso_week") .. ": " .. wk .. " (" .. wy .. ")\n" ..
        TR("day_of_year") .. ": " .. (info - daysFromCivil(y, 1, 1) + 1) .. "\n"
  end
  sys.clipboard(s)
  say(TR("copied"))
  audio.play("pop")
end

-- ------------------------------------------------------------------ lifecycle
function app.load(arg)
  isTR = sys.lang() == "tr"
  MONTHS = {TR("m1"), TR("m2"), TR("m3"), TR("m4"), TR("m5"), TR("m6"), TR("m7"), TR("m8"), TR("m9"), TR("m10"), TR("m11"), TR("m12")}
  WEEKDAYS = {TR("wd1"), TR("wd2"), TR("wd3"), TR("wd4"), TR("wd5"), TR("wd6"), TR("wd7")}
  WD_SHORT = {TR("ws1"), TR("ws2"), TR("ws3"), TR("ws4"), TR("ws5"), TR("ws6"), TR("ws7")}
  today = todayZ()
  local function num(k, d) local v = tonumber(store.get(k, d)); if not v then return d end return clampZ(floor(v)) end
  A = num("A", today)
  B = num("B", (addTo(today, 0, 0, 100) or today))
  base = num("base", today)
  info = num("info", today)
  inclEnd = store.get("incl", false) == true
  op = store.get("op", 1) == 2 and 2 or 1
  local s = store.get("amt", nil)
  if type(s) == "table" then for k in pairs(amt) do if type(s[k]) == "string" then amt[k] = s[k] end end end
  tab = min(3, max(1, floor(tonumber(store.get("tab", 1)) or 1)))
  tabAnim = tab
  shownDays = B - A
end

function app.update(dt)
  today = todayZ()
  tabAnim = ease(tabAnim, tab, dt, 12)
  if abs(tabAnim - tab) < 0.002 then tabAnim = tab end
  local target = (B - A) + (inclEnd and (B >= A and 1 or -1) or 0)
  shownDays = ease(shownDays, target, dt, 8)
end

-- ------------------------------------------------------------------ widgets
local function label(text, x, y)
  gfx.color(theme.text2)
  gfx.text(text, x, y, 13, "semibold")
end

local function card(x, y, w, h)
  gfx.shadow(x, y, w, h, 12, 10, 3)
  gfx.rect(x, y, w, h, 12, theme.control)
  gfx.color(theme.separator)
  gfx.rectLine(x, y, w, h, 12, 1)
end

-- a number box between − and + buttons; tapping the number lets you type it
local function stepper(id, value, text, x, y, bw, onStep, onTap)
  if ui.iconButton("remove", x, y, 32, 34, nil, false, id .. "m") then onStep(-1) end
  local hit = ui.hit(id .. "v", x + 34, y, bw, 34)
  gfx.rect(x + 34, y, bw, 34, 8, hit.hovered and theme.hover or theme.field)
  gfx.color(theme.separator)
  gfx.rectLine(x + 34, y, bw, 34, 8, 1)
  gfx.color(theme.text)
  gfx.text(text, x + 34, y + 8, 15, "semibold", "center", bw)
  if hit.clicked then onTap() end
  if ui.iconButton("add", x + 36 + bw, y, 32, 34, nil, false, id .. "p") then onStep(1) end
  return x + 68 + bw
end

-- date picker: day stepper, month dropdown, year stepper, Today; the weekday is shown under it
local function datePicker(key, x, y, w)
  local z = getDate(key)
  local yy, mm, dd = civilFromDays(z)
  local nx = stepper(key .. "d", dd, tostring(dd), x, y, 36,
    function(s) setDate(key, z + s) end,
    function()
      ui.prompt(TR("type_date"), TR("type_date_msg"), string.format("%02d.%02d.%04d", dd, mm, yy), function(s)
        local nz = parseDate(s)
        if nz then setDate(key, nz) else say(TR("err_date")) end
      end)
    end)
  local mw = max(96, min(140, w - (nx - x) - 8 - 120 - 8 - 76))
  local nm = ui.dropdown(key .. "mon", MONTHS, mm, nx + 8, y, mw, 34)
  if nm ~= mm and nm >= 1 and nm <= 12 then setDate(key, daysFromCivil(yy, nm, min(dd, daysIn(yy, nm)))) end
  nx = nx + 8 + mw + 8
  nx = stepper(key .. "y", yy, tostring(yy), nx, y, 52,
    function(s)
      local ny = min(9999, max(1, yy + s))
      setDate(key, daysFromCivil(ny, mm, min(dd, daysIn(ny, mm))))
    end,
    function()
      ui.prompt(TR("type_year"), TR("type_year_msg"), tostring(yy), function(s)
        local v = tonumber(s or "")
        if v and v == floor(v) and v >= 1 and v <= 9999 then setDate(key, daysFromCivil(v, mm, min(dd, daysIn(v, mm))))
        else say(TR("err_year")) end
      end)
    end)
  local tw = min(96, x + w - nx - 8)
  if tw >= 34 then
    if ui.button((tw >= 80 and TR("today") or "") .. "##" .. key .. "today", nx + 8, y, tw, 34, z == today and "default" or "plain", "today") then
      setDate(key, today)
    end
  end
  gfx.color(theme.text3)
  gfx.text(WEEKDAYS[isoWeekday(z)] or "", x, y + 38, 12)
end

local function stat(title, value, x, y, w, color)
  gfx.color(theme.text2)
  gfx.text(title, x, y, 12)
  gfx.color(color or theme.text)
  gfx.text(value, x, y + 16, 17, "semibold")
end

-- ------------------------------------------------------------------ tab 1: difference
local function drawDiff(w, h)
  local m = 20
  local x, y, cw = m, 60, w - 2 * m
  label(TR("start_date"), x, y)
  datePicker("A", x, y + 20, cw - 44)
  if ui.iconButton("swap_vert", x + cw - 36, y + 46, 36, 34, theme.accent, false, "swap") then
    local a = A; setDate("A", B); setDate("B", a); audio.play("click")
  end
  y = y + 76
  label(TR("end_date"), x, y)
  datePicker("B", x, y + 20, cw - 44)
  y = y + 78
  local ni = ui.checkbox(TR("include_end"), inclEnd, x, y)
  if ni ~= inclEnd then inclEnd = ni; store.set("incl", ni) end

  local cy = y + 36
  local ch = h - cy - m
  card(x, cy, cw, ch)
  local a, b = min(A, B), max(A, B)
  local n = b - a + (inclEnd and 1 or 0)
  local px = x + 20
  gfx.color(theme.text2)
  gfx.text(A <= B and TR("difference") or TR("before_note"), px, cy + 14, 13, "semibold")
  gfx.color(theme.accent)
  local dw = gfx.text(grp(floor(shownDays + (shownDays >= 0 and 0.5 or -0.5))), px, cy + 32, 34, "bold")
  gfx.color(theme.text2)
  gfx.text(abs(B - A) == 1 and not inclEnd and TR("day_word") or TR("days_word"), px + dw + 8, cy + 48, 15)
  if ui.iconButton("content_copy", x + cw - 46, cy + 12, 34, 32, theme.accent, false, "copy1") then copyText() end
  -- four stat tiles in two rows (one row on wide windows)
  local tiles = 4
  local cols = cw >= 640 and 4 or 2
  local tw = (cw - 40) / cols
  local ty = cy + 80
  local yy, mo, dd = ymd(a, b + (inclEnd and 1 or 0))
  for i = 1, tiles do
    local tx = px + ((i - 1) % cols) * tw
    local tyy = ty + ((i - 1) // cols) * 44
    if tyy + 40 <= cy + ch then
      if i == 1 then stat(TR("weeks"), TR("weeks_days", grp(n // 7), n % 7), tx, tyy, tw)
      elseif i == 2 then stat(TR("ymd_title"), TR("ymd", yy, mo, dd), tx, tyy, tw)
      elseif i == 3 then stat(TR("work_days"), grp(workDays(a, n)), tx, tyy, tw, theme.green)
      else stat(TR("hours"), grp(n * 24), tx, tyy, tw) end
    end
  end
end

-- ------------------------------------------------------------------ tab 2: add / subtract
local function drawAdd(w, h)
  local m = 20
  local x, y, cw = m, 60, w - 2 * m
  label(TR("base_date"), x, y)
  datePicker("base", x, y + 20, cw)
  y = y + 78
  local no = ui.segmented("op", {TR("add"), TR("subtract")}, op, x, y, 240, 32)
  if no ~= op and (no == 1 or no == 2) then op = no; store.set("op", op) end
  y = y + 46
  local fw = (cw - 30) / 4
  local keys = {"y", "m", "w", "d"}
  for i, k in ipairs(keys) do
    local fx = x + (i - 1) * (fw + 10)
    gfx.color(theme.text2)
    gfx.text(i == 1 and TR("years") or i == 2 and TR("months") or i == 3 and TR("weeks") or TR("days"), fx, y, 12, "semibold")
    local nt = ui.textfield("amt" .. k, amt[k], fx, y + 18, fw, 34, "0", "numeric")
    if nt ~= amt[k] then amt[k] = nt; store.set("amt", amt) end
  end
  y = y + 66
  local ch = h - y - m
  card(x, y, cw, ch)
  local r, err = addResult()
  local px = x + 20
  if not r then
    gfx.icon("error_outline", x + cw / 2, y + ch / 2 - 14, 32, theme.orange)
    gfx.color(theme.text)
    gfx.text(TR(err or "err_whole"), x, y + ch / 2 + 10, 14, "sans", "center", cw)
    return
  end
  gfx.color(theme.text2)
  gfx.text(TR("result_date"), px, y + 14, 13, "semibold")
  local s = fmtDate(r)
  local size = 30
  while size > 16 and gfx.textWidth(s, size, "bold") > cw - 90 do size = size - 2 end
  gfx.color(theme.accent)
  gfx.text(s, px, y + 34, size, "bold")
  gfx.color(theme.text)
  gfx.text(WEEKDAYS[isoWeekday(r)] or "", px, y + 40 + size, 15, "medium")
  gfx.color(theme.text2)
  local diff = r - base
  gfx.text(diff == 0 and TR("same_day") or diff > 0 and TR("days_after", grp(diff)) or TR("days_before", grp(-diff)), px, y + 64 + size, 13)
  local rt = r - today
  gfx.color(theme.text3)
  gfx.text(rt == 0 and TR("is_today") or rt > 0 and TR("in_days", grp(rt)) or TR("days_ago", grp(-rt)), px, y + 84 + size, 12)
  if ui.iconButton("content_copy", x + cw - 46, y + 12, 34, 32, theme.accent, false, "copy2") then copyText() end
  if ch >= 150 and ui.button(TR("show_info"), x + cw - 172, y + ch - 46, 156, 32, "default", "event_note") then
    setDate("info", r); setTab(3)
  end
end

-- ------------------------------------------------------------------ tab 3: date info + calendar
local function drawCalendar(x, y, w, h)
  local yy, mm = civilFromDays(info)
  local cell = min(floor(w / 7), floor((h - 30) / 7))
  local gx = x + (w - cell * 7) / 2
  gfx.color(theme.text)
  gfx.text((MONTHS[mm] or "") .. " " .. yy, gx, y, 15, "semibold")
  if ui.iconButton("chevron_left", gx + cell * 7 - 68, y - 6, 32, 30, nil, false, "calprev") then
    local ny, nm = yy, mm - 1
    if nm == 0 then ny, nm = yy - 1, 12 end
    if ny >= 1 then local _, _, dd = civilFromDays(info); setDate("info", daysFromCivil(ny, nm, min(dd, daysIn(ny, nm)))) end
  end
  if ui.iconButton("chevron_right", gx + cell * 7 - 32, y - 6, 32, 30, nil, false, "calnext") then
    local ny, nm = yy, mm + 1
    if nm == 13 then ny, nm = yy + 1, 1 end
    if ny <= 9999 then local _, _, dd = civilFromDays(info); setDate("info", daysFromCivil(ny, nm, min(dd, daysIn(ny, nm)))) end
  end
  local top = y + 30
  for i = 1, 7 do
    gfx.color(i >= 6 and theme.red or theme.text3)
    gfx.text(WD_SHORT[i] or "", gx + (i - 1) * cell, top, 11, "semibold", "center", cell)
  end
  local first = daysFromCivil(yy, mm, 1)
  local off = isoWeekday(first) - 1
  local n = daysIn(yy, mm)
  local gy = top + 18
  -- the selection bubble glides to the chosen day
  local _, _, sd = civilFromDays(info)
  local si = off + sd - 1
  local tx, ty = gx + (si % 7) * cell + cell / 2, gy + (si // 7) * cell + cell / 2
  if not selX then selX, selY = tx, ty end
  gfx.circle(selX, selY, cell / 2 - 2, theme.accent)
  for d = 1, n do
    local i = off + d - 1
    local cx, cy = gx + (i % 7) * cell, gy + (i // 7) * cell
    local z = first + d - 1
    local hit = ui.hit("day" .. d, cx, cy, cell, cell)
    if hit.hovered and z ~= info then gfx.circle(cx + cell / 2, cy + cell / 2, cell / 2 - 2, theme.hover) end
    if z == today then gfx.color(theme.accent); gfx.circleLine(cx + cell / 2, cy + cell / 2, cell / 2 - 2, 1.5) end
    local sel = z == info and abs(selX - tx) < 2 and abs(selY - ty) < 2
    gfx.color(sel and "#FFFFFF" or ((i % 7) >= 5 and theme.red or theme.text))
    gfx.text(tostring(d), cx, cy + cell / 2 - 8, 13, sel and "bold" or "sans", "center", cell)
    if hit.clicked then setDate("info", z) end
  end
  return tx, ty
end

local function drawInfo(w, h, dt)
  local m = 20
  local x, y, cw = m, 60, w - 2 * m
  label(TR("pick_date"), x, y)
  datePicker("info", x, y + 20, cw)
  y = y + 80
  local lw = floor((cw - 16) * 0.5)
  card(x, y, lw, h - y - m)
  local yy, mm, dd = civilFromDays(info)
  local px, pw = x + 16, lw - 32
  gfx.color(theme.accent)
  gfx.text(WEEKDAYS[isoWeekday(info)] or "", px, y + 14, 22, "bold")
  if ui.iconButton("content_copy", x + lw - 44, y + 10, 34, 32, theme.accent, false, "copy3") then copyText() end
  local doy = info - daysFromCivil(yy, 1, 1) + 1
  local ylen = isLeap(yy) and 366 or 365
  local wk, wy = isoWeek(info)
  local rel = info - today
  local rows = {
    {TR("day_of_year"), doy .. " / " .. ylen},
    {TR("iso_week"), wy ~= yy and (wk .. " (" .. wy .. ")") or tostring(wk)},
    {TR("leap_year"), isLeap(yy) and TR("yes") or TR("no")},
    {TR("days_in_month"), tostring(daysIn(yy, mm))},
    {TR("quarter"), TR("q", (mm - 1) // 3 + 1)},
    {TR("left_in_year"), grp(ylen - doy)},
    {TR("from_today"), rel == 0 and TR("is_today") or rel > 0 and TR("in_days", grp(rel)) or TR("days_ago", grp(-rel))},
  }
  local ry = y + 50
  local rowH = 26
  for i, r in ipairs(rows) do
    if ry + rowH > y + (h - y - m) - 4 then break end
    if i > 1 then ui.separator(px, ry - 3, px + pw) end
    gfx.color(theme.text2)
    gfx.text(r[1], px, ry + 3, 13)
    gfx.color(theme.text)
    gfx.text(r[2], px, ry + 3, 13, "semibold", "right", pw)
    ry = ry + rowH
  end
  local cx = x + lw + 16
  card(cx, y, cw - lw - 16, h - y - m)
  local tx, ty = drawCalendar(cx + 10, y + 14, cw - lw - 36, h - y - m - 20)
  selX = ease(selX or tx, tx, dt, 14)
  selY = ease(selY or ty, ty, dt, 14)
end

-- ------------------------------------------------------------------ frame
local lastT = nil
local function drawToast(w, h)
  if not toast then return end
  local age = sys.time() - toastAt
  if age > 2.2 then toast = nil; return end
  local a = min(1, age * 6, (2.2 - age) * 3)
  local tw = gfx.textWidth(toast, 13) + 32
  local tx, ty = (w - tw) / 2, h - 56 - (1 - min(1, age * 6)) * 10
  gfx.alpha(a)
  gfx.shadow(tx, ty, tw, 32, 16, 10, 3)
  gfx.rect(tx, ty, tw, 32, 16, theme.dark and "#3A3A3C" or "#1C1C1E")
  gfx.color("#FFFFFF")
  gfx.text(toast, tx, ty + 8, 13, "medium", "center", tw)
  gfx.unalpha()
end

function app.draw(w, h)
  local t = sys.time()
  local dt = lastT and min(0.1, t - lastT) or 0
  lastT = t
  gfx.clear(theme.bg)
  local sw = min(w - 40, 420)
  local nt = ui.segmented("tabs", {TR("tab_diff"), TR("tab_add"), TR("tab_info")}, tab, (w - sw) / 2, 14, sw, 30)
  setTab(nt)
  local off = (tab - tabAnim) * 40
  gfx.alpha(1 - min(1, abs(tab - tabAnim)) * 0.8)
  gfx.push(off, 0)
  if tab == 1 then drawDiff(w, h) elseif tab == 2 then drawAdd(w, h) else drawInfo(w, h, dt) end
  gfx.pop()
  gfx.unalpha()
  if tab ~= 3 then selX, selY = nil, nil end
  drawToast(w, h)
end

function app.event(e)
  if e.type ~= "keydown" then return end
  if e.ctrl and (e.key == "1" or e.key == "2" or e.key == "3") then setTab(tonumber(e.key))
  elseif e.key == "pageup" then setTab(tab == 1 and 3 or tab - 1)
  elseif e.key == "pagedown" then setTab(tab % 3 + 1)
  elseif e.ctrl and e.key == "t" then
    if tab == 1 then setDate("A", today) elseif tab == 2 then setDate("base", today) else setDate("info", today) end
  elseif e.ctrl and e.key == "c" then copyText()
  elseif tab == 3 and not e.ctrl then
    -- the info tab has no text fields, so the arrows (and the D-pad) move the date
    if e.key == "left" then setDate("info", info - 1)
    elseif e.key == "right" then setDate("info", info + 1)
    elseif e.key == "up" then setDate("info", info - 7)
    elseif e.key == "down" then setDate("info", info + 7) end
  end
end

function app.menu()
  return {
    {title = TR("app_name"), items = {
      {label = TR("tab_diff"), id = 1, shortcut = "Ctrl+1"},
      {label = TR("tab_add"), id = 2, shortcut = "Ctrl+2"},
      {label = TR("tab_info"), id = 3, shortcut = "Ctrl+3"},
      "-",
      {label = TR("copy"), id = 4, shortcut = "Ctrl+C"},
      {label = TR("go_today"), id = 5, shortcut = "Ctrl+T"},
      {label = TR("swap"), id = 6},
    }},
  }
end

function app.onmenu(id)
  if id >= 1 and id <= 3 then setTab(id)
  elseif id == 4 then copyText()
  elseif id == 5 then
    if tab == 1 then setDate("A", today) elseif tab == 2 then setDate("base", today) else setDate("info", today) end
  elseif id == 6 then local a = A; setDate("A", B); setDate("B", a) end
end

function app.close()
  store.save()
  return true
end

return app
