-- Exam Countdown: several exams with days/hours left, a study timer and log, a daily goal, a study streak and a
-- 12-week heatmap (Nexvyn OS Lua SDK).
local app = {}

-- ------------------------------------------------------------------ state
local exams = {}         -- {id, name, day (days since 1970), mins (minute of day), color, created (epoch)}
local sessions = {}      -- {day, exam (id, 0 = general), min}
local nextId = 1
local goal = 60          -- daily study goal in minutes
local timerStart = nil   -- epoch when the study timer started (survives restarts)
local timerExam = 0
local tab = 1
local editing, isNew = nil, false
local edName, edDate, edTime = "", "", ""
local today, localOff = 0, 0
local lastLocal = -100
local dayMin = {}        -- day -> minutes studied
local examMin = {}       -- exam id -> minutes
local streak, bestStreak, todayMin = 0, 0, 0
local upcoming, past = {}, {}
local dirty = true
local appear = {}
local msg, msgT = nil, 0
local undoSnap, undoT, undoText = nil, 0, ""
local MONTHS, WSHORT = {}, {}
local examNames = {}

local COLORS = {"#0A84FF", "#FF375F", "#30D158", "#FF9F0A", "#BF5AF2", "#64D2FF", "#FFD60A", "#AC8E68"}

-- confetti for reaching the daily goal (pre-allocated pool)
local CONF = 90
local cx_, cy_, cvx, cvy, crot, ccol, clife = {}, {}, {}, {}, {}, {}, {}
for i = 1, CONF do cx_[i], cy_[i], cvx[i], cvy[i], crot[i], ccol[i], clife[i] = 0, 0, 0, 0, 0, 1, 0 end
local confettiOn = false

-- ------------------------------------------------------------------ dates
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

local function parseDate(s)
  s = (s or ""):match("^%s*(.-)%s*$")
  local y, m, d = s:match("^(%d%d%d%d)%-(%d%d?)%-(%d%d?)$")
  if not y then d, m, y = s:match("^(%d%d?)[%./](%d%d?)[%./](%d%d%d%d)$") end
  if not y then return nil end
  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  if y < 2000 or y > 2200 or m < 1 or m > 12 or d < 1 or d > daysInMonth(y, m) then return nil end
  return daysFromCivil(y, m, d)
end

local function parseTime(s)
  local h, m = (s or ""):match("^%s*(%d%d?)[:%.](%d%d)%s*$")
  h, m = tonumber(h), tonumber(m)
  if not h or h > 23 or m > 59 then return nil end
  return h * 60 + m
end

local function isoDate(n) local y, m, d = civilFromDays(n); return string.format("%04d-%02d-%02d", y, m, d) end
local function hhmm(mins) return string.format("%02d:%02d", mins // 60, mins % 60) end
local function niceDate(n) local y, m, d = civilFromDays(n); return d .. " " .. (MONTHS[m] or "") .. " " .. y end
local function wday(n) return (n + 4) % 7 end

local function examEpoch(e) return e.day * 86400 + (e.mins or 0) * 60 - localOff end

-- ------------------------------------------------------------------ helpers
local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
local function flash(t) msg, msgT = t, 2.5 end
local function ease(t) t = math.max(0, math.min(1, t)); return 1 - (1 - t) ^ 3 end

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = deepcopy(v) end
  return r
end

local function save()
  store.set("exams", exams)
  store.set("sessions", sessions)
  store.set("nextId", nextId)
  dirty = true
end

local function snapshot(text)
  undoSnap = {exams = deepcopy(exams), sessions = deepcopy(sessions)}
  undoT, undoText = 6, text
end

local function undo()
  if not undoSnap then return end
  exams, sessions = undoSnap.exams, undoSnap.sessions
  undoSnap, undoT = nil, 0
  save()
  audio.play("pop")
end

local function examById(id)
  for _, e in ipairs(exams) do if e.id == id then return e end end
  return nil
end

local function chord(notes, len, vol)
  for _, f in ipairs(notes) do audio.tone(f, len, vol, "sine") end
end

local function celebrate(w)
  confettiOn = true
  for i = 1, CONF do
    cx_[i], cy_[i] = w / 2 + (math.random() - 0.5) * 80, -10 - math.random() * 40
    local a = math.random() * math.pi
    local sp = 160 + math.random() * 320
    cvx[i], cvy[i] = math.cos(a) * sp * (math.random() < 0.5 and -1 or 1), math.random() * 120
    crot[i], ccol[i], clife[i] = math.random() * 6, (i % #COLORS) + 1, 2.2 + math.random() * 1.2
  end
  chord({523, 659, 784}, 0.18, 0.18)
  timer.after(0.18, function() chord({659, 784, 1047}, 0.35, 0.18) end)
end

-- ------------------------------------------------------------------ aggregation
local function rebuild()
  dirty = false
  for k in pairs(dayMin) do dayMin[k] = nil end
  for k in pairs(examMin) do examMin[k] = nil end
  for _, s in ipairs(sessions) do
    dayMin[s.day] = (dayMin[s.day] or 0) + s.min
    examMin[s.exam or 0] = (examMin[s.exam or 0] or 0) + s.min
  end
  todayMin = dayMin[today] or 0
  -- current streak: today counts once something is logged, otherwise it starts from yesterday
  streak = 0
  local d = (dayMin[today] or 0) > 0 and today or today - 1
  while (dayMin[d] or 0) > 0 do streak = streak + 1; d = d - 1 end
  -- best streak over all days
  local days = {}
  for k in pairs(dayMin) do days[#days + 1] = k end
  table.sort(days)
  bestStreak = 0
  local run, prev = 0, nil
  for _, k in ipairs(days) do
    if prev and k == prev + 1 then run = run + 1 else run = 1 end
    if run > bestStreak then bestStreak = run end
    prev = k
  end
  -- exams split into upcoming (soonest first) and past
  for i = #upcoming, 1, -1 do upcoming[i] = nil end
  for i = #past, 1, -1 do past[i] = nil end
  local now = sys.epoch()
  for _, e in ipairs(exams) do
    if examEpoch(e) > now then upcoming[#upcoming + 1] = e else past[#past + 1] = e end
  end
  table.sort(upcoming, function(a, b) return examEpoch(a) < examEpoch(b) end)
  table.sort(past, function(a, b) return examEpoch(a) > examEpoch(b) end)
  examNames = {TR("general")}
  for _, e in ipairs(upcoming) do examNames[#examNames + 1] = e.name end
end

-- ------------------------------------------------------------------ actions
local function newExam()
  local e = {id = nextId, name = "", day = today + 14, mins = 9 * 60 + 30, color = COLORS[(#exams % #COLORS) + 1],
             created = sys.epoch()}
  nextId = nextId + 1
  editing, isNew = e, true
  edName, edDate, edTime = "", isoDate(e.day), hhmm(e.mins)
end

local function openExam(e)
  editing, isNew = e, false
  edName, edDate, edTime = e.name, isoDate(e.day), hhmm(e.mins or 0)
end

local function closeEditor(saveIt)
  local e = editing
  if not e then return end
  if saveIt then
    local name = trim(edName)
    local d, m = parseDate(edDate), parseTime(edTime)
    if name == "" then flash(TR("err_name")); audio.play("error"); return end
    if (utf8.len(name) or 0) > 40 then flash(TR("err_long")); audio.play("error"); return end
    if not d then flash(TR("err_date")); audio.play("error"); return end
    if not m then flash(TR("err_time")); audio.play("error"); return end
    e.name, e.day, e.mins = name, d, m
    if isNew then
      exams[#exams + 1] = e
      appear[e.id] = 0
      chord({587, 880}, 0.12, 0.15)
    end
    save()
  end
  editing = nil
end

local function deleteExam(e)
  snapshot(TR("deleted", e.name))
  for i, x in ipairs(exams) do if x == e then table.remove(exams, i) break end end
  editing = nil
  save()
  audio.play("trash")
end

local function logStudy(mins, exam)
  if mins <= 0 then return end
  local before = todayMin
  sessions[#sessions + 1] = {day = today, exam = exam or 0, min = mins}
  save()
  rebuild()
  flash(TR("logged", mins))
  if before < goal and todayMin >= goal then
    celebrate(gfx.size())
    flash(TR("goal_hit"))
  else
    chord({660, 990}, 0.08, 0.15)
  end
end

local function undoLastSession()
  if #sessions == 0 then return end
  snapshot(TR("session_removed"))
  table.remove(sessions)
  save()
  audio.play("pop")
end

local function selectedExamId()
  if timerExam <= 1 then return 0 end
  local e = upcoming[timerExam - 1]
  return e and e.id or 0
end

local function toggleTimer()
  if timerStart then
    local mins = math.floor((sys.epoch() - timerStart) / 60 + 0.5)
    local exam = selectedExamId()
    timerStart = nil
    store.set("timerStart", false)
    if mins >= 1 then logStudy(math.min(mins, 600), exam) else flash(TR("too_short")) end
  else
    timerStart = sys.epoch()
    store.set("timerStart", timerStart)
    chord({440, 660}, 0.1, 0.15)
  end
end

local function updateLocal()
  local d = sys.date()
  local n = daysFromCivil(d.year, d.month, d.day)
  localOff = n * 86400 + d.hour * 3600 + d.min * 60 + d.sec - sys.epoch()
  if n ~= today then today = n; dirty = true end
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  MONTHS = {TR("jan"), TR("feb"), TR("mar"), TR("apr"), TR("may"), TR("jun"), TR("jul"), TR("aug"), TR("sep"),
            TR("oct"), TR("nov"), TR("dec")}
  WSHORT = {TR("mon_s"), TR("tue_s"), TR("wed_s"), TR("thu_s"), TR("fri_s"), TR("sat_s"), TR("sun_s")}
  exams = store.get("exams", {})
  sessions = store.get("sessions", {})
  if type(exams) ~= "table" then exams = {} end
  if type(sessions) ~= "table" then sessions = {} end
  nextId = store.get("nextId", 1)
  for _, e in ipairs(exams) do if (e.id or 0) >= nextId then nextId = e.id + 1 end end
  goal = store.get("goal", 60)
  local ts = store.get("timerStart", false)
  timerStart = type(ts) == "number" and ts or nil
  tab = store.get("tab", 1)
  if tab ~= 1 and tab ~= 2 then tab = 1 end
  updateLocal()
end

function app.update(dt)
  local t = sys.time()
  if t - lastLocal > 20 then lastLocal = t; updateLocal(); dirty = true end
  if msgT > 0 then msgT = msgT - dt end
  if undoT > 0 then undoT = undoT - dt; if undoT <= 0 then undoSnap = nil end end
  for k, v in pairs(appear) do
    v = v + dt * 3.5
    if v >= 1 then appear[k] = nil else appear[k] = v end
  end
  if confettiOn then
    local alive = false
    for i = 1, CONF do
      if clife[i] > 0 then
        alive = true
        clife[i] = clife[i] - dt
        cvy[i] = cvy[i] + 520 * dt
        cvx[i] = cvx[i] * (1 - 1.5 * dt)
        cx_[i], cy_[i] = cx_[i] + cvx[i] * dt, cy_[i] + cvy[i] * dt
        crot[i] = crot[i] + dt * 8
      end
    end
    confettiOn = alive
  end
  if dirty then rebuild() end
end

-- ------------------------------------------------------------------ drawing
local function emptyState(icon, title, sub, x, y, w, h)
  local cy = y + h / 2 - 60
  local bob = math.sin(sys.time() * 2) * 3
  gfx.circle(x + w / 2, cy + bob, 42, theme.hover)
  gfx.icon(icon, x + w / 2, cy + bob, 48, theme.text3)
  gfx.color(theme.text)
  gfx.text(title, x, cy + 56, 16, "semibold", "center", w)
  gfx.color(theme.text2)
  gfx.text(sub, x, cy + 80, 13, "sans", "center", w)
end

local function urgency(e, secs)
  local days = secs / 86400
  if days <= 3 then return theme.red end
  if days <= 7 then return theme.orange end
  return e.color or theme.accent
end

local function ring(cx, cy, r, frac, color)
  gfx.color(theme.hover)
  gfx.arc(cx, cy, r, 0, math.pi * 2, 8)
  if frac > 0.002 then
    gfx.color(color)
    gfx.arc(cx, cy, r, -math.pi / 2, -math.pi / 2 + math.pi * 2 * math.min(1, frac), 8)
  end
end

local function drawHero(e, x, y, w, h)
  local now = sys.epoch()
  local secs = math.max(0, examEpoch(e) - now)
  local col = urgency(e, secs)
  gfx.shadow(x, y, w, h, 16, 14, 4)
  gfx.rect(x, y, w, h, 16, theme.field)
  gfx.rect(x, y, 6, h, 3, col)
  if ui.hit("hero", x, y, w, h).clicked then openExam(e) end
  local total = math.max(1, examEpoch(e) - (e.created or now))
  local frac = 1 - secs / total
  local r = math.min(56, h / 2 - 18)
  ring(x + 24 + r, y + h / 2, r, frac, col)
  gfx.color(theme.text)
  gfx.text(tostring(math.floor(secs / 86400)), x + 24, y + h / 2 - 20, 30, "bold", "center", r * 2)
  gfx.color(theme.text2)
  gfx.text(TR("days"), x + 24, y + h / 2 + 14, 11, "semibold", "center", r * 2)
  local tx = x + 48 + r * 2
  local tw = w - (tx - x) - 16
  gfx.color(theme.text2)
  gfx.text(TR("next_exam"), tx, y + 16, 11, "semibold")
  gfx.color(theme.text)
  gfx.clip(tx, y, math.max(1, tw), h)
  gfx.text(e.name, tx, y + 32, 22, "bold")
  gfx.color(theme.text2)
  gfx.text(niceDate(e.day) .. " · " .. hhmm(e.mins or 0), tx, y + 60, 13)
  gfx.unclip()
  -- d / h / m / s tiles
  local parts = {math.floor(secs / 86400), math.floor(secs % 86400 / 3600), math.floor(secs % 3600 / 60), math.floor(secs % 60)}
  local labels = {TR("u_days"), TR("u_hours"), TR("u_mins"), TR("u_secs")}
  local bw = math.min(78, (tw - 24) / 4)
  for i = 1, 4 do
    local bx = tx + (i - 1) * (bw + 8)
    gfx.rect(bx, y + h - 70, bw, 54, 10, theme.hover)
    gfx.color(i == 4 and col or theme.text)
    gfx.text(string.format(i == 1 and "%d" or "%02d", parts[i]), bx, y + h - 64, 22, "bold", "center", bw)
    gfx.color(theme.text2)
    gfx.text(labels[i], bx, y + h - 36, 10, "semibold", "center", bw)
  end
  if secs < 86400 then
    gfx.color(theme.red)
    gfx.text(TR("good_luck"), tx, y + 80, 13, "bold")
  end
end

local function drawExams(x, y, w, h)
  if ui.button(TR("add_exam"), x, y, 150, 32, "primary", "add") then newExam() end
  y = y + 44
  if #exams == 0 then
    emptyState("school", TR("empty"), TR("empty_sub"), x, y, w, h - y)
    return
  end
  local contentH = 0
  local heroH = 190
  local rowH = 66
  if #upcoming > 0 then contentH = heroH + 16 end
  contentH = contentH + math.max(0, #upcoming - 1) * rowH + (#past > 0 and (30 + #past * rowH) or 0) + 20
  ui.beginScroll("exams", x - 6, y, w + 12, h - y - 4, contentH)
  local yy = 4
  local now = sys.epoch()
  if #upcoming > 0 then
    drawHero(upcoming[1], 6, yy, w, heroH)
    yy = yy + heroH + 16
  else
    gfx.color(theme.text2)
    gfx.text(TR("no_upcoming"), 6, yy, 14)
    yy = yy + 30
  end
  local function row(e, dim)
    local a = appear[e.id]
    if a then gfx.alpha(ease(a)) end
    if dim then gfx.alpha(0.55) end
    local ox = a and (1 - ease(a)) * 30 or 0
    if ui.row("ex" .. e.id, 6 + ox, yy, w, rowH - 8, false) then openExam(e) end
    local secs = examEpoch(e) - now
    local col = dim and theme.text3 or urgency(e, secs)
    gfx.rect(10 + ox, yy + 8, 5, rowH - 24, 3, e.color or theme.accent)
    gfx.color(theme.text)
    gfx.clip(24 + ox, yy, math.max(1, w - 170), rowH)
    gfx.text(e.name, 26 + ox, yy + 8, 15, "semibold")
    gfx.color(theme.text2)
    gfx.text(niceDate(e.day) .. " · " .. hhmm(e.mins or 0), 26 + ox, yy + 30, 12)
    gfx.unclip()
    gfx.color(col)
    if dim then
      gfx.text(TR("finished"), 0, yy + 18, 14, "semibold", "right", w - 10 + ox)
    else
      local d = math.floor(secs / 86400)
      gfx.text(d > 0 and TR("in_days", d) or TR("in_hours", math.max(0, math.floor(secs / 3600))), 0, yy + 8, 17, "bold",
               "right", w - 10 + ox)
      local m = examMin[e.id] or 0
      gfx.color(theme.text3)
      gfx.text(TR("studied", m // 60, m % 60), 0, yy + 32, 11, "sans", "right", w - 10 + ox)
    end
    if dim then gfx.unalpha() end
    if a then gfx.unalpha() end
    yy = yy + rowH
  end
  for i = 2, #upcoming do row(upcoming[i], false) end
  if #past > 0 then
    gfx.color(theme.text2)
    gfx.text(TR("past"), 8, yy + 6, 11, "semibold")
    yy = yy + 30
    for _, e in ipairs(past) do row(e, true) end
  end
  ui.endScroll()
end

local function heatColor(m)
  if m <= 0 then return theme.hover end
  if m < goal * 0.5 then return "#9BE9A8" end
  if m < goal then return "#40C463" end
  if m < goal * 2 then return "#30A14E" end
  return "#216E39"
end

local function drawStudy(x, y, w, h)
  local contentH = 720 + #upcoming * 30
  ui.beginScroll("study", x - 6, y, w + 12, h - y - 4, contentH)
  local cx = 6
  local yy = 4
  local wide = w >= 640
  local cw = wide and (w - 12) / 2 or w
  -- streak card
  gfx.shadow(cx, yy, cw, 150, 14, 12, 3)
  gfx.gradient(cx, yy, cw, 150, "#FF9F0A", "#FF375F", false, 14)
  local flame = 1 + math.sin(sys.time() * 6) * 0.06
  gfx.icon("local_fire_department", cx + 56, yy + 66, 64 * flame, "#FFFFFF")
  gfx.color("#FFFFFF")
  gfx.text(tostring(streak), cx + 104, yy + 26, 44, "bold")
  gfx.text(TR("streak_days"), cx + 104, yy + 80, 14, "semibold")
  gfx.color("#FFFFFFCC")
  gfx.text(TR("best_streak", bestStreak), cx + 104, yy + 104, 12)
  if streak > 0 and todayMin == 0 then gfx.text(TR("keep_it"), cx + 16, yy + 126, 11, "semibold") end
  -- today card
  local tx = wide and cx + cw + 12 or cx
  local ty = wide and yy or yy + 162
  ui.group(tx, ty, cw, 150)
  gfx.color(theme.text2)
  gfx.text(TR("today"), tx + 14, ty + 12, 11, "semibold")
  gfx.color(theme.text)
  local tw = gfx.text(TR("min_value", todayMin), tx + 14, ty + 28, 28, "bold")
  gfx.color(theme.text2)
  gfx.text(TR("of_goal", goal), tx + 20 + tw, ty + 40, 13)
  ui.progress(math.min(1, todayMin / math.max(1, goal)), tx + 14, ty + 70, cw - 28, 8)
  gfx.color(theme.text2)
  gfx.text(TR("daily_goal"), tx + 14, ty + 92, 12)
  local g = ui.slider("goal", goal, 15, 300, tx + 120, ty + 88, cw - 134, 15)
  g = math.floor(g / 15 + 0.5) * 15
  if g ~= goal then goal = g; store.set("goal", goal) end
  gfx.color(todayMin >= goal and theme.green or theme.text3)
  gfx.text(todayMin >= goal and TR("goal_done") or TR("goal_left", goal - todayMin), tx + 14, ty + 120, 12, "semibold")
  yy = (wide and yy + 162 or ty + 162)
  -- log study
  ui.group(cx, yy, w, 132)
  gfx.color(theme.text2)
  gfx.text(TR("log_study"), cx + 14, yy + 12, 11, "semibold")
  if timerExam > #examNames then timerExam = 1 end
  if timerExam < 1 then timerExam = 1 end
  timerExam = ui.dropdown("logexam", examNames, timerExam, cx + w - 214, yy + 6, 200, 30)
  local bx = cx + 14
  local qb = math.max(54, (w - 28 - 24 - 170) / 4)
  for i, m in ipairs({15, 30, 45, 60}) do
    if ui.button("+" .. m .. "##q", bx + (i - 1) * (qb + 8), yy + 46, qb, 34) then logStudy(m, selectedExamId()) end
  end
  local running = timerStart ~= nil
  local label
  if running then
    local el = math.max(0, sys.epoch() - timerStart)
    label = TR("stop_timer", string.format("%d:%02d:%02d", el // 3600, el % 3600 // 60, el % 60))
  else
    label = TR("start_timer")
  end
  if ui.button(label .. "##timer", cx + w - 184, yy + 46, 170, 34, running and "destructive" or "primary",
               running and "pause" or "play_arrow") then toggleTimer() end
  if ui.button(TR("undo_last"), cx + 14, yy + 90, 160, 30, "plain", "undo", #sessions > 0) then undoLastSession() end
  gfx.color(theme.text3)
  gfx.text(TR("total_all", #sessions), cx, yy + 98, 12, "sans", "right", w - 14)
  yy = yy + 146
  -- heatmap of the last 12 weeks (Monday first)
  gfx.color(theme.text2)
  gfx.text(TR("heatmap"), cx + 2, yy, 11, "semibold")
  yy = yy + 20
  local weekStart = today - ((wday(today) + 6) % 7)
  local start = weekStart - 77
  local cell = math.min(26, (w - 40) / 12 - 4)
  for r = 0, 6 do
    gfx.color(theme.text3)
    gfx.text(WSHORT[r + 1], cx, yy + r * (cell + 4) + cell / 2 - 7, 10)
  end
  for c = 0, 11 do
    for r = 0, 6 do
      local d = start + c * 7 + r
      if d <= today then
        local m = dayMin[d] or 0
        local px, py = cx + 30 + c * (cell + 4), yy + r * (cell + 4)
        gfx.rect(px, py, cell, cell, 4, heatColor(m))
        if d == today then gfx.color(theme.accent); gfx.rectLine(px, py, cell, cell, 4, 2) end
      end
    end
  end
  local lx = cx + 30 + 12 * (cell + 4) + 10
  if lx + 110 < cx + w then
    gfx.color(theme.text3)
    gfx.text(TR("less"), lx, yy + 4, 10)
    for i, m in ipairs({0, goal * 0.25, goal * 0.75, goal * 1.5, goal * 3}) do
      gfx.rect(lx + (i - 1) * 16, yy + 20, 12, 12, 3, heatColor(m))
    end
    gfx.text(TR("more"), lx, yy + 38, 10)
  end
  yy = yy + 7 * (cell + 4) + 16
  -- minutes per exam
  gfx.color(theme.text2)
  gfx.text(TR("per_exam"), cx + 2, yy, 11, "semibold")
  yy = yy + 22
  local rows = {}
  for _, e in ipairs(upcoming) do rows[#rows + 1] = {e.name, examMin[e.id] or 0, e.color} end
  rows[#rows + 1] = {TR("general"), examMin[0] or 0, theme.gray}
  local mx = 1
  for _, r in ipairs(rows) do if r[2] > mx then mx = r[2] end end
  for _, r in ipairs(rows) do
    gfx.color(theme.text)
    gfx.clip(cx, yy, 130, 26)
    gfx.text(r[1], cx + 2, yy + 4, 13)
    gfx.unclip()
    local bw = math.max(4, (w - 220) * r[2] / mx)
    gfx.rect(cx + 136, yy + 4, w - 220, 18, 6, theme.hover)
    gfx.rect(cx + 136, yy + 4, bw, 18, 6, r[3] or theme.accent)
    gfx.color(theme.text2)
    gfx.text(TR("hm", r[2] // 60, r[2] % 60), cx, yy + 4, 12, "semibold", "right", w - 4)
    yy = yy + 30
  end
  ui.endScroll()
end

local function drawEditor(w, h)
  local e = editing
  local cw = math.min(560, w - 40)
  local x = (w - cw) / 2
  local y = 14
  if ui.button(TR("cancel"), x, y, 110, 32, "default", "close") then editing = nil; return end
  if ui.button(TR("save"), x + cw - 110, y, 110, 32, "primary", "check") then closeEditor(true); return end
  gfx.color(theme.text)
  gfx.text(isNew and TR("new_exam") or TR("edit_exam"), x, y + 4, 18, "bold", "center", cw)
  y = y + 52
  gfx.color(theme.text2)
  gfx.text(TR("exam_name"), x, y, 12, "semibold")
  edName = ui.textfield("e_name", edName, x, y + 18, cw, 34, TR("name_ph"))
  y = y + 66
  local half = (cw - 16) / 2
  gfx.color(theme.text2)
  gfx.text(TR("date"), x, y, 12, "semibold")
  gfx.text(TR("time"), x + half + 16, y, 12, "semibold")
  edDate = ui.textfield("e_date", edDate, x, y + 18, half, 34, "YYYY-MM-DD")
  edTime = ui.textfield("e_time", edTime, x + half + 16, y + 18, half, 34, "09:30")
  local d, m = parseDate(edDate), parseTime(edTime)
  gfx.color(d and theme.text2 or theme.red)
  gfx.text(d and niceDate(d) or TR("err_date"), x, y + 56, 12)
  gfx.color(m and theme.text2 or theme.red)
  gfx.text(m and "" or TR("err_time"), x + half + 16, y + 56, 12)
  y = y + 78
  local base = d or today
  local qb = (cw - 5 * 6) / 6
  local quick = {{"-1##d", -1}, {"+1##d", 1}, {TR("plus_week"), 7}, {TR("plus_month"), 30}}
  for i, q in ipairs(quick) do
    if ui.button(q[1], x + (i - 1) * (qb + 6), y, qb, 32) then edDate = isoDate(base + q[2]); audio.play("click") end
  end
  if ui.button("09:00##t", x + 4 * (qb + 6), y, qb, 32) then edTime = "09:00" end
  if ui.button("13:30##t", x + 5 * (qb + 6), y, qb, 32) then edTime = "13:30" end
  y = y + 48
  gfx.color(theme.text2)
  gfx.text(TR("color"), x, y, 12, "semibold")
  y = y + 20
  for i, c in ipairs(COLORS) do
    local bx = x + (i - 1) * 44
    if ui.hit("col" .. i, bx, y, 36, 36).clicked then e.color = c; audio.play("click") end
    gfx.circle(bx + 18, y + 18, 15, c)
    if e.color == c then gfx.color(theme.text); gfx.circleLine(bx + 18, y + 18, 18, 2) end
  end
  y = y + 56
  if d and m then
    local secs = d * 86400 + m * 60 - localOff - sys.epoch()
    gfx.color(secs > 0 and theme.text or theme.orange)
    gfx.text(secs > 0 and TR("preview", math.floor(secs / 86400), math.floor(secs % 86400 / 3600)) or TR("in_past"), x, y, 14,
             "semibold")
  end
  if not isNew then
    if ui.button(TR("delete"), x, h - 50, 140, 34, "destructive", "delete") then deleteExam(e) end
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  if dirty then rebuild() end
  if editing then
    drawEditor(w, h)
  else
    local tw = math.min(360, w - 40)
    local nt = ui.segmented("tab", {TR("tab_exams"), TR("tab_study")}, tab, (w - tw) / 2, 12, tw, 32)
    if nt ~= tab then tab = nt; store.set("tab", tab); audio.play("click") end
    local cw = math.min(860, w - 40)
    local x = (w - cw) / 2
    if tab == 1 then drawExams(x, 56, cw, h) else drawStudy(x, 56, cw, h) end
  end
  if confettiOn then
    for i = 1, CONF do
      if clife[i] > 0 then
        gfx.alpha(math.min(1, clife[i]))
        local s = 4 + math.abs(math.sin(crot[i])) * 4
        gfx.rect(cx_[i] - s / 2, cy_[i] - 3, s, 6, 1, COLORS[ccol[i]])
        gfx.unalpha()
      end
    end
  end
  if undoSnap and undoT > 0 then
    local text = undoText
    local tw = math.min(w - 40, gfx.textWidth(text, 13, "semibold") + 140)
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
  if e.type ~= "keydown" then return end
  if e.ctrl and e.key == "z" then undo(); return end
  if editing then
    if e.key == "escape" then editing = nil elseif e.key == "enter" then closeEditor(true) end
    return
  end
  if e.ctrl and e.key == "n" then newExam()
  elseif e.key == "tab" then tab = tab % 2 + 1; store.set("tab", tab)
  elseif e.key == "space" and tab == 2 then toggleTimer()
  end
end

function app.menu()
  return {
    {title = TR("menu_exams"), items = {
      {label = TR("add_exam"), id = 1, shortcut = "Ctrl+N"},
      {label = TR("remove_past"), id = 2},
      "-",
      {label = TR("undo"), id = 3, shortcut = "Ctrl+Z"},
    }},
    {title = TR("menu_study"), items = {
      {label = TR("start_stop"), id = 10, shortcut = "Space"},
      {label = TR("log15"), id = 11},
      {label = TR("undo_last"), id = 12},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then newExam()
  elseif id == 2 then
    if #past > 0 then
      snapshot(TR("past_removed", #past))
      local keep = {}
      for _, e in ipairs(exams) do if examEpoch(e) > sys.epoch() then keep[#keep + 1] = e end end
      exams = keep
      save()
      audio.play("trash")
    end
  elseif id == 3 then undo()
  elseif id == 10 then tab = 2; toggleTimer()
  elseif id == 11 then logStudy(15, selectedExamId())
  elseif id == 12 then undoLastSession() end
end

function app.close()
  store.save()
  return true
end

return app
