-- Sleep Tracker for Nexvyn OS: bedtime / wake time / quality per night, one-tap "going to bed" and "woke up"
-- buttons, a 7-night chart with a goal line, averages, bedtime consistency, sleep debt, CSV export and undo.
local app = {}

local floor, min, max, abs, sqrt, sin, pi = math.floor, math.min, math.max, math.abs, math.sqrt, math.sin, math.pi

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
local function keyOf(dn)
  local y, m, d = civilFromDays(dn)
  return string.format("%04d-%02d-%02d", y, m, d)
end
local function dayOfKey(k)
  local y, m, d = (k or ""):match("^(%d+)-(%d+)-(%d+)$")
  if not y then return nil end
  return daysFromCivil(tonumber(y), tonumber(m), tonumber(d))
end
local function todayNum()
  local d = sys.date()
  return daysFromCivil(d.year, d.month, d.day)
end
local function nowMin()
  local d = sys.date()
  return d.hour * 60 + d.min
end
local MONTHS = {"ms1", "ms2", "ms3", "ms4", "ms5", "ms6", "ms7", "ms8", "ms9", "ms10", "ms11", "ms12"}
local WD = {"wd0", "wd1", "wd2", "wd3", "wd4", "wd5", "wd6"}   -- index = weekday + 1, 0 = Sunday
local function weekday(dn) return (dn + 4) % 7 end

-- ------------------------------------------------------------------ formatting
local function hhmm(m)
  m = floor(m) % 1440
  return string.format("%02d:%02d", m // 60, m % 60)
end
local function durText(m)
  m = floor(m + 0.5)
  return TR("dur", m // 60, m % 60)
end
local function duration(bed, wake)
  return (wake - bed) % 1440
end
local function dayLabel(dn)
  local _, m, d = civilFromDays(dn)
  return TR(WD[weekday(dn) + 1]) .. " " .. d .. " " .. TR(MONTHS[m])
end

-- ------------------------------------------------------------------ state
local entries = {}        -- { {id, date = "YYYY-MM-DD" (morning you woke), bed = minutes, wake = minutes, q = 1..5} }
local nextId = 1
local goal = 480          -- minutes
local pending = nil       -- {epoch, min}: "going to bed" was pressed
local version = 0
local tab, tabT = 1, 1
local sheet, sheetT = nil, 0
local sel = 0             -- selected row in the log (keyboard)
local undoItem = nil      -- {entry, t}
local message, messageT = "", 0
local bars = {0, 0, 0, 0, 0, 0, 0}   -- eased bar heights (fraction of the chart)

local function save()
  table.sort(entries, function(a, b) return a.date > b.date end)
  store.set("entries", entries)
  store.set("nextId", nextId)
  version = version + 1
end
local function say(s) message, messageT = s, sys.time() end

local function findDate(date)
  for i, e in ipairs(entries) do if e.date == date then return e, i end end
end

-- ------------------------------------------------------------------ statistics (cached per change / day)
local st = {key = ""}
local function stats()
  local today = todayNum()
  local key = version .. ":" .. today .. ":" .. goal
  if st.key == key then return st end
  local s = {key = key, nights = {}, n = 0, sumDur = 0, sumQ = 0, debt = 0, hit = 0}
  local bedVals = {}
  for i = 1, 7 do
    local dn = today - 7 + i
    local e = findDate(keyOf(dn))
    local d = e and duration(e.bed, e.wake) or 0
    s.nights[i] = {dn = dn, e = e, dur = d}
    if e then
      s.n = s.n + 1
      s.sumDur = s.sumDur + d
      s.sumQ = s.sumQ + e.q
      s.debt = s.debt + (goal - d)
      if d >= goal then s.hit = s.hit + 1 end
      -- bedtime measured from noon so 23:30 and 00:30 average to midnight
      bedVals[#bedVals + 1] = (e.bed - 720) % 1440
    end
  end
  s.avgDur = s.n > 0 and s.sumDur / s.n or 0
  s.avgQ = s.n > 0 and s.sumQ / s.n or 0
  if #bedVals > 0 then
    local sum = 0
    for _, v in ipairs(bedVals) do sum = sum + v end
    local mean = sum / #bedVals
    local var = 0
    for _, v in ipairs(bedVals) do var = var + (v - mean) ^ 2 end
    s.avgBed = (mean + 720) % 1440
    s.spread = sqrt(var / #bedVals)
  end
  s.last = entries[1]
  st = s
  return s
end

-- ------------------------------------------------------------------ actions
local function openEditor(e, preset)
  local s = {isNew = e == nil, id = e and e.id}
  if e then
    s.dn, s.bed, s.wake, s.q = dayOfKey(e.date) or todayNum(), e.bed, e.wake, e.q
  else
    s.dn, s.bed, s.wake, s.q = todayNum(), (420 - goal) % 1440, 420, 3
    if preset then s.bed, s.wake = preset.bed, preset.wake end
  end
  s.err = ""
  sheet, sheetT = s, 0
  audio.play("pop")
end

local function commitEditor(force)
  local s = sheet
  if not s then return end
  local d = duration(s.bed, s.wake)
  if d < 30 then s.err = TR("err_short"); audio.play("error"); return end
  if d > 16 * 60 then s.err = TR("err_long"); audio.play("error"); return end
  if s.dn > todayNum() then s.err = TR("err_future"); audio.play("error"); return end
  local date = keyOf(s.dn)
  local other, oi = findDate(date)
  if other and other.id ~= s.id then
    if not force then
      ui.alert(TR("replace_title"), TR("replace_msg", dayLabel(s.dn)), {TR("replace"), TR("cancel")}, function(b)
        if b == 1 and sheet == s then commitEditor(true) end
      end)
      return
    end
    table.remove(entries, oi)
  end
  local e
  for _, x in ipairs(entries) do if x.id == s.id then e = x end end
  if not e then
    e = {id = nextId}
    nextId = nextId + 1
    entries[#entries + 1] = e
  end
  e.date, e.bed, e.wake, e.q = date, s.bed, s.wake, s.q
  if s.isNew and pending then pending = nil; store.set("pending", false) end
  sheet = nil
  undoItem = nil
  save()
  say(TR("saved_night", durText(d)))
  audio.tone(660, 0.08, 0.3, "sine")
end

local function deleteEntry(e)
  if not e then return end
  for i, x in ipairs(entries) do
    if x == e then
      table.remove(entries, i)
      undoItem = {entry = e, t = sys.time()}
      if sheet and sheet.id == e.id then sheet = nil end
      save()
      audio.play("trash")
      return
    end
  end
end

local function undo()
  if not undoItem then return end
  local e = undoItem.entry
  undoItem = nil
  local other, oi = findDate(e.date)
  if other then table.remove(entries, oi) end
  entries[#entries + 1] = e
  save()
  say(TR("restored"))
end

local function bedNow()
  pending = {epoch = sys.epoch(), min = nowMin()}
  store.set("pending", pending)
  say(TR("good_night"))
  audio.tone(392, 0.25, 0.25, "sine")
end

local function wokeNow()
  local wake = nowMin()
  local bed = (wake - goal) % 1440
  if pending and sys.epoch() - pending.epoch < 20 * 3600 then bed = pending.min end
  openEditor(nil, {bed = bed, wake = wake})
end

local function setGoal(m)
  goal = max(240, min(720, m))
  store.set("goal", goal)
end

-- ------------------------------------------------------------------ export
local function exportCsv()
  local out = {"date,bedtime,wake,minutes,quality"}
  for i = #entries, 1, -1 do
    local e = entries[i]
    out[#out + 1] = string.format("%s,%s,%s,%d,%d", e.date, hhmm(e.bed), hhmm(e.wake), duration(e.bed, e.wake), e.q)
  end
  local text = table.concat(out, "\n") .. "\n"
  ui.saveFile(function(path)
    if not path then return end
    if fs.write(path, text) then say(TR("csv_saved")) else say(TR("save_failed")) end
  end, "sleep.csv", TR("export_csv"))
end

local function copySummary()
  local s = stats()
  local lines = {TR("week_title")}
  for i = 1, 7 do
    local nt = s.nights[i]
    lines[#lines + 1] = dayLabel(nt.dn) .. ": " ..
      (nt.e and (hhmm(nt.e.bed) .. "–" .. hhmm(nt.e.wake) .. " (" .. durText(nt.dur) .. ")") or "—")
  end
  if s.n > 0 then lines[#lines + 1] = TR("avg_duration") .. ": " .. durText(s.avgDur) end
  sys.clipboard(table.concat(lines, "\n"))
  say(TR("copied"))
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  nextId = floor(tonumber(store.get("nextId", 1)) or 1)
  goal = floor(tonumber(store.get("goal", 480)) or 480)
  setGoal(goal)
  entries = {}
  local raw = store.get("entries", {})
  if type(raw) == "table" then
    for _, e in ipairs(raw) do
      if type(e) == "table" and dayOfKey(e.date) then
        local bed, wake, q = tonumber(e.bed), tonumber(e.wake), floor(tonumber(e.q) or 3)
        if bed and wake then
          entries[#entries + 1] = {id = tonumber(e.id) or nextId, date = e.date, bed = floor(bed) % 1440,
                                   wake = floor(wake) % 1440, q = max(1, min(5, q))}
          nextId = max(nextId, (tonumber(e.id) or 0) + 1)
        end
      end
    end
  end
  local p = store.get("pending", false)
  if type(p) == "table" and tonumber(p.epoch) and tonumber(p.min) then
    pending = {epoch = tonumber(p.epoch), min = floor(tonumber(p.min)) % 1440}
  end
  tab = floor(tonumber(store.get("tab", 1)) or 1)
  if tab < 1 or tab > 2 then tab = 1 end
  save()
end

function app.update(dt)
  tabT = approach(tabT, 1, 10, dt)
  if sheet then sheetT = approach(sheetT, 1, 14, dt) end
  local s = stats()
  local top = max(goal * 1.25, 600)
  for i = 1, 7 do bars[i] = approach(bars[i], min(1, s.nights[i].dur / top), 7, dt) end
end

-- ------------------------------------------------------------------ drawing helpers
local QCOL = {"#FF453A", "#FF9F0A", "#FFCC00", "#8BD450", "#30D158"}
local function stars(x, y, q, size, interactive, idp)
  local clicked = nil
  for i = 1, 5 do
    local cx = x + (i - 1) * (size + 6) + size / 2
    if interactive then
      local h = ui.hit(idp .. i, cx - size / 2 - 3, y - 2, size + 6, max(30, size + 4))
      if h.clicked then clicked = i end
    end
    gfx.icon(i <= q and "star" or "star_border", cx, y + size / 2, size, i <= q and theme.yellow or theme.text3)
  end
  return clicked
end

local function card(x, y, w, h, icon, color, value, label, sub)
  gfx.rect(x, y, w, h, 12, theme.dark and "#FFFFFF0F" or "#0000000A")
  gfx.circle(x + 24, y + 24, 14, fade(color, 0.18))
  gfx.icon(icon, x + 24, y + 24, 17, color)
  gfx.clip(x + 6, y, w - 12, h)
  gfx.color(theme.text2)
  gfx.text(label, x + 46, y + 16, 12, "medium")
  gfx.color(theme.text)
  gfx.text(value, x + 14, y + 40, 19, "bold")
  if sub then
    gfx.color(theme.text3)
    gfx.text(sub, x + 14, y + 66, 11)
  end
  gfx.unclip()
end

local function barColor(d)
  if d >= goal then return theme.green elseif d >= goal - 60 then return theme.orange end
  return theme.red
end

-- ------------------------------------------------------------------ overview tab
local function drawOverview(w, h, interactive)
  local s = stats()
  local y = 60
  -- quick buttons and the pending bedtime
  local bw = min(200, (w - 52) / 2)
  if interactive then
    if ui.button(TR("bed_now") .. "##bn", 20, y, bw, 40, "default", "bedtime") then bedNow() end
    if ui.button(TR("woke_now") .. "##wn", 32 + bw, y, bw, 40, "primary", "wb_sunny") then wokeNow() end
  end
  local px = 44 + bw * 2
  if pending and w - px > 120 then
    local ago = max(0, sys.epoch() - pending.epoch) // 60
    gfx.icon("nightlight", px + 10, y + 20, 18, theme.purple)
    gfx.clip(px + 24, y, w - px - 64, 40)
    gfx.color(theme.text)
    gfx.text(TR("in_bed_since", hhmm(pending.min)), px + 26, y + 4, 13, "semibold")
    gfx.color(theme.text2)
    gfx.text(TR("ago", durText(ago)), px + 26, y + 21, 11)
    gfx.unclip()
    if interactive and ui.iconButton("close", w - 54, y + 4, 34, 32, theme.text3, false, "pc") then
      pending = nil
      store.set("pending", false)
    end
  end
  -- summary cards
  y = y + 56
  local gap = 12
  local cw = (w - 40 - gap * 3) / 4
  local last = s.last
  card(20, y, cw, 88, "hotel", theme.purple, last and durText(duration(last.bed, last.wake)) or "—", TR("last_night"),
       last and (hhmm(last.bed) .. " → " .. hhmm(last.wake)) or nil)
  card(20 + (cw + gap), y, cw, 88, "schedule", theme.blue, s.n > 0 and durText(s.avgDur) or "—", TR("avg_duration"),
       TR("nights_logged", s.n))
  card(20 + (cw + gap) * 2, y, cw, 88, "bedtime", theme.orange, s.avgBed and hhmm(s.avgBed) or "—", TR("avg_bedtime"),
       s.spread and TR("consistency", floor(s.spread + 0.5)) or nil)
  card(20 + (cw + gap) * 3, y, cw, 88, "star", theme.yellow, s.n > 0 and string.format("%.1f / 5", s.avgQ) or "—",
       TR("avg_quality"), s.n > 0 and TR("goal_hit", s.hit, s.n) or nil)

  -- chart header with goal stepper
  y = y + 104
  gfx.color(theme.text)
  gfx.text(TR("last7"), 20, y + 6, 15, "semibold")
  if interactive then
    if ui.iconButton("remove", w - 170, y, 34, 30, theme.text2, false, "gm") then setGoal(goal - 30) end
    if ui.iconButton("add", w - 54, y, 34, 30, theme.text2, false, "gp") then setGoal(goal + 30) end
  end
  gfx.color(theme.text2)
  gfx.text(TR("goal", durText(goal)), w - 136, y + 7, 12, "semibold", "center", 82)
  if s.n > 0 then
    gfx.color(s.debt > 0 and theme.red or theme.green)
    local dtxt = s.debt > 0 and TR("debt", durText(s.debt)) or TR("surplus", durText(-s.debt))
    gfx.text(dtxt, 20 + gfx.textWidth(TR("last7"), 15) + 16, y + 8, 12, "medium")
  end

  -- bar chart
  local cx, cy = 40, y + 44
  local cwid, ch = w - 70, h - y - 44 - 40
  if ch < 60 then return end
  if #entries == 0 then
    -- first run: a friendly illustration instead of an empty chart
    local mx, my = w / 2, cy + ch / 2 - 30
    gfx.circle(mx, my, 38, fade(theme.purple, 0.14))
    gfx.icon("bedtime", mx, my, 40, theme.purple)
    gfx.color(theme.text)
    gfx.text(TR("empty_title"), 0, my + 50, 16, "bold", "center", w)
    gfx.color(theme.text2)
    gfx.text(TR("first_run"), 0, my + 74, 13, "sans", "center", w)
    return
  end
  local top = max(goal * 1.25, 600)
  gfx.color(theme.separator)
  gfx.line(cx, cy + ch, cx + cwid, cy + ch, 1)
  for hrs = 2, floor(top / 60), 2 do
    local ly = cy + ch - ch * hrs * 60 / top
    gfx.color(fade(theme.separator, 0.6))
    gfx.line(cx, ly, cx + cwid, ly, 1)
    gfx.color(theme.text3)
    gfx.text(hrs .. TR("h_short"), 0, ly - 7, 10, "sans", "right", cx - 6)
  end
  local slot = cwid / 7
  local bwid = min(56, slot - 16)
  local today = todayNum()
  for i = 1, 7 do
    local nt = s.nights[i]
    local bx = cx + (i - 1) * slot + (slot - bwid) / 2
    local bh = ch * bars[i]
    if nt.e and bh > 2 then
      gfx.gradient(bx, cy + ch - bh, bwid, bh, barColor(nt.dur), fade(barColor(nt.dur), 0.55), false, 8)
      gfx.color(theme.text2)
      gfx.text(durText(nt.dur), bx - 20, cy + ch - bh - 17, 10, "medium", "center", bwid + 40)
    elseif not nt.e then
      gfx.color(theme.text3)
      gfx.text("—", bx, cy + ch - 18, 12, "sans", "center", bwid)
    end
    local hit = interactive and ui.hit("bar" .. i, bx, cy, bwid, ch)
    if hit and hit.hovered then gfx.rect(bx - 4, cy, bwid + 8, ch, 8, theme.hover) end
    if hit and hit.clicked then
      if nt.e then openEditor(nt.e) else openEditor(nil); if sheet then sheet.dn = nt.dn end end
    end
    gfx.color(nt.dn == today and theme.accent or theme.text2)
    local _, _, d = civilFromDays(nt.dn)
    gfx.text(TR(WD[weekday(nt.dn) + 1]) .. " " .. d, cx + (i - 1) * slot, cy + ch + 6, 11,
             nt.dn == today and "semibold" or "sans", "center", slot)
  end
  -- dashed goal line
  local gy = cy + ch - ch * goal / top
  gfx.color(theme.purple)
  for xx = cx, cx + cwid - 8, 14 do gfx.line(xx, gy, xx + 7, gy, 2) end
end

-- ------------------------------------------------------------------ log tab
local function drawEmpty(w, h, y)
  local cy = y + (h - y) / 2 - 80
  gfx.circle(w / 2, cy, 44, fade(theme.purple, 0.14))
  gfx.icon("bedtime", w / 2, cy, 46, theme.purple)
  gfx.color(theme.text)
  gfx.text(TR("empty_title"), 0, cy + 60, 18, "bold", "center", w)
  gfx.color(theme.text2)
  gfx.text(TR("empty_body"), 0, cy + 88, 13, "sans", "center", w)
end

local function rowMenu(e)
  ui.contextMenu({
    {label = TR("edit"), id = 1, icon = "edit"},
    "-",
    {label = TR("delete"), id = 2, icon = "delete"},
  }, function(id)
    if id == 1 then openEditor(e) elseif id == 2 then deleteEntry(e) end
  end)
end

local function drawLog(w, h, interactive)
  local y = 60
  if interactive then
    if ui.button(TR("add_entry") .. "##add", 20, y, 160, 32, "primary", "add") then openEditor(nil) end
    if ui.button(TR("export_csv") .. "##csv", 188, y, 180, 32, "default", "save", #entries > 0) then exportCsv() end
    if undoItem and sys.time() - undoItem.t < 8 and ui.button(TR("undo") .. "##undo", w - 120, y, 100, 32, "default", "undo") then
      undo()
    end
  end
  local top = y + 44
  if #entries == 0 then drawEmpty(w, h, top) return end
  local rh = 56
  if sel > #entries then sel = #entries end
  ui.beginScroll("log", 0, top, w, h - top - 8, #entries * rh + 8)
  for i, e in ipairs(entries) do
    local ry = (i - 1) * rh
    local d = duration(e.bed, e.wake)
    local hit = interactive and ui.hit("row" .. e.id, 16, ry + 2, w - 32, rh - 4)
    if i == sel then gfx.rect(16, ry + 2, w - 32, rh - 4, 10, fade(theme.accent, 0.14))
    elseif hit and hit.hovered then gfx.rect(16, ry + 2, w - 32, rh - 4, 10, theme.hover) end
    if i > 1 then ui.separator(28, ry, w - 28) end
    local dn = dayOfKey(e.date) or 0
    gfx.circle(44, ry + rh / 2, 17, fade(barColor(d), 0.18))
    gfx.icon("bedtime", 44, ry + rh / 2, 18, barColor(d))
    gfx.color(theme.text)
    gfx.text(dayLabel(dn), 72, ry + 9, 14, "semibold")
    gfx.color(theme.text2)
    gfx.text(hhmm(e.bed) .. "  →  " .. hhmm(e.wake), 72, ry + 30, 12, "medium")
    -- duration bar against the goal
    local bx, bwid = max(250, w * 0.42), max(60, w * 0.22)
    gfx.rect(bx, ry + rh / 2 - 4, bwid, 8, 4, theme.dark and "#FFFFFF14" or "#0000000F")
    gfx.rect(bx, ry + rh / 2 - 4, max(8, bwid * min(1, d / max(1, goal))), 8, 4, barColor(d))
    gfx.color(theme.text)
    gfx.text(durText(d), bx + bwid + 10, ry + rh / 2 - 9, 13, "bold")
    stars(w - 130, ry + rh / 2 - 8, e.q, 16, false)
    if hit then
      if hit.clicked then sel = i; openEditor(e) end
      if hit.rightClicked then sel = i; rowMenu(e) end
    end
  end
  ui.endScroll()
end

-- ------------------------------------------------------------------ editor sheet
local function timeStepper(label, x, y, w, value, idp)
  gfx.color(theme.text2)
  gfx.text(label, x, y, 12, "semibold")
  local by = y + 18
  local nv = value
  if ui.button("-1" .. TR("h_short") .. "##" .. idp .. "a", x, by, 46, 32) then nv = value - 60 end
  if ui.button("-15##" .. idp .. "b", x + 50, by, 46, 32) then nv = value - 15 end
  gfx.color(theme.text)
  gfx.text(hhmm(value), x + 100, by + 2, 22, "bold", "center", w - 200)
  if ui.button("+15##" .. idp .. "c", x + w - 96, by, 46, 32) then nv = value + 15 end
  if ui.button("+1" .. TR("h_short") .. "##" .. idp .. "d", x + w - 46, by, 46, 32) then nv = value + 60 end
  return nv % 1440
end

local function drawSheet(w, h)
  local s = sheet
  gfx.rect(0, 0, w, h, 0, {0, 0, 0, floor(110 * sheetT)})
  local sw, shh = min(460, w - 40), 372
  local sx, sy = floor((w - sw) / 2), floor((h - shh) / 2 + (1 - sheetT) * 20)
  gfx.alpha(sheetT)
  gfx.shadow(sx, sy, sw, shh, 14, 30, 10)
  gfx.rect(sx, sy, sw, shh, 14, theme.dark and "#2C2C2E" or "#F6F6F6")
  gfx.color(theme.separator)
  gfx.rectLine(sx, sy, sw, shh, 14, 1)
  gfx.color(theme.text)
  gfx.text(s.isNew and TR("new_night") or TR("edit_night"), sx + 20, sy + 16, 17, "bold")
  -- date stepper
  local x, iw = sx + 20, sw - 40
  local y = sy + 50
  gfx.color(theme.text2)
  gfx.text(TR("woke_on"), x, y, 12, "semibold")
  if ui.iconButton("chevron_left", x, y + 18, 40, 32, theme.text2, false, "dprev") then s.dn = s.dn - 1; s.err = "" end
  gfx.color(theme.text)
  gfx.text(dayLabel(s.dn), x + 44, y + 24, 15, "semibold", "center", iw - 88)
  if ui.iconButton("chevron_right", x + iw - 40, y + 18, 40, 32, theme.text2, false, "dnext") then
    if s.dn < todayNum() then s.dn = s.dn + 1; s.err = "" end
  end
  y = y + 62
  local nb = timeStepper(TR("bedtime"), x, y, iw, s.bed, "bed")
  if nb ~= s.bed then s.bed = nb; s.err = "" end
  y = y + 62
  local nw = timeStepper(TR("wake_time"), x, y, iw, s.wake, "wake")
  if nw ~= s.wake then s.wake = nw; s.err = "" end
  y = y + 62
  gfx.color(theme.text2)
  gfx.text(TR("quality"), x, y, 12, "semibold")
  local q = stars(x, y + 20, s.q, 24, true, "q")
  if q then s.q = q; audio.play("click") end
  local d = duration(s.bed, s.wake)
  gfx.color(theme.text2)
  gfx.text(TR("total"), 0, y, 12, "semibold", "right", x + iw)
  gfx.color(barColor(d))
  gfx.text(durText(d), 0, y + 20, 20, "bold", "right", x + iw)
  if s.err ~= "" then
    gfx.color(theme.red)
    gfx.text(s.err, x, y + 52, 12)
  end
  local fy = sy + shh - 46
  ui.separator(sx, fy - 10, sx + sw)
  if not s.isNew and ui.button(TR("delete") .. "##sh", x, fy, 92, 32, "destructive") then
    for _, e in ipairs(entries) do if e.id == s.id then deleteEntry(e) break end end
    sheet = nil
  end
  if sheet and ui.button(TR("cancel") .. "##sh", sx + sw - 220, fy, 96, 32) then sheet = nil end
  if sheet and ui.button(TR("save") .. "##sh", sx + sw - 116, fy, 96, 32, "primary") then commitEditor() end
  gfx.unalpha()
end

-- ------------------------------------------------------------------ main draw
function app.draw(w, h)
  gfx.clear(theme.bg)
  local interactive = sheet == nil
  gfx.color(theme.text)
  gfx.text(TR("title"), 20, 18, 20, "bold")
  if interactive then
    local nt = ui.segmented("tabs", {TR("tab_overview"), TR("tab_log")}, tab, w - 260, 16, 240, 30)
    if nt ~= tab then tab = nt; tabT = 0; store.set("tab", tab) end
  end
  if message ~= "" and sys.time() - messageT < 3 and w > 620 then
    gfx.color(theme.text2)
    gfx.text(message, 180, 24, 12, "sans", "right", w - 460)
  end
  gfx.alpha(0.3 + 0.7 * tabT)
  gfx.push(0, (1 - tabT) * 8)
  if tab == 1 then drawOverview(w, h, interactive) else drawLog(w, h, interactive) end
  gfx.pop()
  gfx.unalpha()
  if sheet then drawSheet(w, h) end
end

-- ------------------------------------------------------------------ input
function app.event(e)
  if e.type ~= "keydown" then return end
  if sheet then
    if e.key == "escape" then sheet = nil
    elseif e.key == "enter" then commitEditor()
    elseif e.key == "left" then sheet.dn = sheet.dn - 1
    elseif e.key == "right" and sheet.dn < todayNum() then sheet.dn = sheet.dn + 1 end
    return
  end
  if e.ctrl then
    if e.key == "n" then openEditor(nil)
    elseif e.key == "z" then undo()
    elseif e.key == "s" then exportCsv()
    elseif e.key == "c" then copySummary() end
    return
  end
  if e.key == "tab" then tab = tab % 2 + 1; tabT = 0; store.set("tab", tab)
  elseif e.key == "b" then bedNow()
  elseif e.key == "w" then wokeNow()
  elseif e.key == "up" and tab == 2 then sel = max(1, sel - 1)
  elseif e.key == "down" and tab == 2 then sel = min(#entries, sel + 1)
  elseif e.key == "enter" and tab == 2 and entries[sel] then openEditor(entries[sel])
  elseif (e.key == "delete" or e.key == "backspace") and tab == 2 and entries[sel] then deleteEntry(entries[sel])
  elseif e.key == "escape" then sel = 0 end
end

function app.menu()
  return {
    {title = TR("menu_sleep"), items = {
      {label = TR("bed_now"), id = 1, shortcut = "B"},
      {label = TR("woke_now"), id = 2, shortcut = "W"},
      {label = TR("add_entry"), id = 3, shortcut = "Ctrl+N"},
      "-",
      {label = TR("goal_up"), id = 4},
      {label = TR("goal_down"), id = 5},
    }},
    {title = TR("menu_data"), items = {
      {label = TR("undo"), id = 10, shortcut = "Ctrl+Z"},
      {label = TR("copy_week"), id = 11, shortcut = "Ctrl+C"},
      {label = TR("export_csv"), id = 12, shortcut = "Ctrl+S"},
      "-",
      {label = TR("tab_overview"), id = 13, checked = tab == 1},
      {label = TR("tab_log"), id = 14, checked = tab == 2, shortcut = "Tab"},
    }},
  }
end

function app.onmenu(id)
  if sheet then return end
  if id == 1 then bedNow()
  elseif id == 2 then wokeNow()
  elseif id == 3 then openEditor(nil)
  elseif id == 4 then setGoal(goal + 30)
  elseif id == 5 then setGoal(goal - 30)
  elseif id == 10 then undo()
  elseif id == 11 then copySummary()
  elseif id == 12 then exportCsv()
  elseif id == 13 or id == 14 then tab = id - 12; tabT = 0; store.set("tab", tab) end
end

function app.close()
  store.set("entries", entries)
  store.save()
  return true
end

return app
