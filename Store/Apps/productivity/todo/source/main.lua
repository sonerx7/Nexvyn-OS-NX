-- To-Do: tasks in projects with priorities, due dates, overdue highlighting, search, sorting, undo and export
-- (Nexvyn OS Lua SDK).
local app = {}

-- ------------------------------------------------------------------ data
local projects = {}      -- {id, name, color}; id 1 is the Inbox and cannot be deleted
local tasks = {}         -- {id, title, note, project, prio 0..3, due = day number or nil, done, created, doneAt}
local nextId = 1
local view = "all"       -- "all" | "today" | "upcoming" | "overdue" | "done" | project id (number)
local showDone = false
local sortMode = 1       -- 1 smart, 2 due date, 3 priority, 4 name, 5 newest
local search, quick = "", ""
local editing = nil      -- task open in the editor
local isNew = false
local edTitle, edNote, edDue = "", "", ""
local selIdx = 0
local today = 0
local localOff = 0       -- seconds to add to a Unix time to get local time
local lastCheck = -1
local msg, msgT = nil, 0
local undoTask, undoIndex, undoT = nil, 0, 0

local visible = {}       -- filtered + sorted tasks (rebuilt only when something changes)
local nVisible = 0
local dirty = true
local counts = {all = 0, today = 0, upcoming = 0, overdue = 0, done = 0}
local projCount = {}
local ids = {}           -- cached widget ids per task id
local appear = {}        -- task id -> 0..1 slide-in animation
local pop = {}           -- task id -> 1..0 check pop animation
local leaving = {}       -- task id -> seconds it stays visible after being completed
local rowY = {}          -- task id -> animated row position
local week = {0, 0, 0, 0, 0, 0, 0}   -- completed per day, last 7 days
local MONTHS, WDAYS, WSHORT = {}, {}, {}
local PRIO_LABELS, SORT_LABELS = {}, {}
local frameDt = 1 / 60

local COLORS = {"#0A84FF", "#FF9F0A", "#30D158", "#BF5AF2", "#FF375F", "#64D2FF", "#FFD60A", "#AC8E68"}
local ROW_H = 50

-- ------------------------------------------------------------------ dates (pure arithmetic, days since 1970-01-01)
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

-- "2026-11-03" or "03.11.2026" (also "3/11/2026") -> day number, or nil
local function parseDate(s)
  s = (s or ""):match("^%s*(.-)%s*$")
  local y, m, d = s:match("^(%d%d%d%d)%-(%d%d?)%-(%d%d?)$")
  if not y then d, m, y = s:match("^(%d%d?)[%./](%d%d?)[%./](%d%d%d%d)$") end
  if not y then return nil end
  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  if y < 1970 or y > 2200 or m < 1 or m > 12 or d < 1 or d > daysInMonth(y, m) then return nil end
  return daysFromCivil(y, m, d)
end

local function isoDate(n)
  local y, m, d = civilFromDays(n)
  return string.format("%04d-%02d-%02d", y, m, d)
end

local function dueLabel(n)
  local diff = n - today
  if diff == 0 then return TR("today") end
  if diff == 1 then return TR("tomorrow") end
  if diff == -1 then return TR("yesterday") end
  if diff > 1 and diff < 7 then return WDAYS[(n + 4) % 7 + 1] end
  local y, m, d = civilFromDays(n)
  local ty = civilFromDays(today)
  if y == ty then return TR("date_short", d, MONTHS[m]) end
  return TR("date_long", d, MONTHS[m], y)
end

local function localDay(epoch) return (math.floor(epoch) + localOff) // 86400 end

-- ------------------------------------------------------------------ helpers
local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- case-folding for search and sorting that treats Turkish İ/I/ı/i alike
local function fold(s)
  s = s:gsub("İ", "i"):gsub("ı", "i"):gsub("Ç", "ç"):gsub("Ğ", "ğ"):gsub("Ö", "ö"):gsub("Ş", "ş"):gsub("Ü", "ü")
  return s:lower()
end

local function ease(t) t = math.max(0, math.min(1, t)); return 1 - (1 - t) ^ 3 end

local function save()
  store.set("tasks", tasks)
  store.set("projects", projects)
  store.set("nextId", nextId)
  dirty = true
end

local function projectById(id)
  for _, p in ipairs(projects) do if p.id == id then return p end end
  return projects[1]
end

local function idsFor(t)
  local c = ids[t.id]
  if not c then c = {"task" .. t.id, "chk" .. t.id}; ids[t.id] = c end
  return c
end

local function flash(text) msg, msgT = text, 2.5 end

-- ------------------------------------------------------------------ filtering / sorting
local function inView(t)
  if search ~= "" then
    local q = fold(trim(search))
    return fold(t.title):find(q, 1, true) ~= nil or fold(t.note or ""):find(q, 1, true) ~= nil
  end
  if view == "done" then return t.done end
  local keep = t.done and leaving[t.id] ~= nil
  if type(view) == "number" then return t.project == view and (showDone or not t.done or keep) end
  if t.done and not keep then return view == "all" and showDone end
  if view == "all" then return true end
  if not t.due then return false end
  if view == "today" then return t.due <= today end
  if view == "upcoming" then return t.due > today end
  if view == "overdue" then return t.due < today end
  return false
end

local function before(a, b)
  local la, lb = a.done and not leaving[a.id], b.done and not leaving[b.id]
  if la ~= lb then return not la end
  if a.done and b.done and view == "done" then return (a.doneAt or 0) > (b.doneAt or 0) end
  local pa, pb = a.prio or 0, b.prio or 0
  local da, db = a.due or 1e9, b.due or 1e9
  if sortMode == 3 then
    if pa ~= pb then return pa > pb end
    if da ~= db then return da < db end
  elseif sortMode == 4 then
    local fa, fb = fold(a.title), fold(b.title)
    if fa ~= fb then return fa < fb end
  elseif sortMode == 5 then
    if (a.created or 0) ~= (b.created or 0) then return (a.created or 0) > (b.created or 0) end
  elseif sortMode == 2 then
    if da ~= db then return da < db end
  else  -- smart: overdue/soonest first, then priority
    if da ~= db then return da < db end
    if pa ~= pb then return pa > pb end
  end
  return (a.id or 0) < (b.id or 0)
end

local function rebuild()
  dirty = false
  for k in pairs(counts) do counts[k] = 0 end
  for k in pairs(projCount) do projCount[k] = 0 end
  for i = 1, 7 do week[i] = 0 end
  nVisible = 0
  for _, t in ipairs(tasks) do
    if t.done then
      counts.done = counts.done + 1
      if t.doneAt then
        local back = today - localDay(t.doneAt)
        if back >= 0 and back < 7 then week[7 - back] = week[7 - back] + 1 end
      end
    else
      counts.all = counts.all + 1
      projCount[t.project] = (projCount[t.project] or 0) + 1
      if t.due then
        if t.due <= today then counts.today = counts.today + 1 end
        if t.due > today then counts.upcoming = counts.upcoming + 1 end
        if t.due < today then counts.overdue = counts.overdue + 1 end
      end
    end
    if inView(t) then nVisible = nVisible + 1; visible[nVisible] = t end
  end
  for i = #visible, nVisible + 1, -1 do visible[i] = nil end
  table.sort(visible, before)
  if selIdx > nVisible then selIdx = nVisible end
end

-- ------------------------------------------------------------------ actions
local function addTask(title)
  title = trim(title)
  if title == "" then flash(TR("err_empty")); audio.play("error"); return nil end
  if (utf8.len(title) or 0) > 120 then flash(TR("err_long")); audio.play("error"); return nil end
  local t = {id = nextId, title = title, note = "", project = type(view) == "number" and view or 1, prio = 0,
             done = false, created = sys.epoch()}
  if view == "today" or view == "overdue" then t.due = today elseif view == "upcoming" then t.due = today + 1 end
  nextId = nextId + 1
  tasks[#tasks + 1] = t
  appear[t.id] = 0
  save()
  audio.tone(660, 0.05, 0.25, "sine")
  timer.after(0.05, function() audio.tone(990, 0.08, 0.2, "sine") end)
  return t
end

local function toggleDone(t)
  t.done = not t.done
  t.doneAt = t.done and sys.epoch() or nil
  if t.done then
    pop[t.id] = 1
    leaving[t.id] = 0.9
    audio.tone(784, 0.07, 0.25, "sine")
    audio.tone(988, 0.07, 0.18, "sine")
    timer.after(0.08, function() audio.tone(1175, 0.12, 0.25, "sine"); audio.tone(1568, 0.12, 0.12, "triangle") end)
  else
    leaving[t.id] = nil
    audio.play("click")
  end
  save()
end

local function deleteTask(t)
  for i, x in ipairs(tasks) do
    if x == t then
      table.remove(tasks, i)
      undoTask, undoIndex, undoT = t, i, 6
      break
    end
  end
  ids[t.id], appear[t.id], pop[t.id], leaving[t.id], rowY[t.id] = nil, nil, nil, nil, nil
  if editing == t then editing = nil end
  save()
  audio.play("trash")
end

local function undoDelete()
  if not undoTask then return end
  local i = math.max(1, math.min(undoIndex, #tasks + 1))
  table.insert(tasks, i, undoTask)
  appear[undoTask.id] = 0
  undoTask, undoT = nil, 0
  save()
  audio.play("pop")
end

local function openEditor(t, new)
  editing, isNew = t, new or false
  edTitle, edNote = t.title, t.note or ""
  edDue = t.due and isoDate(t.due) or ""
end

local function closeEditor()
  local t = editing
  if not t then return end
  editing = nil
  if trim(edTitle) == "" and isNew then deleteTask(t); undoTask = nil end
  save()
end

local function newProject()
  ui.prompt(TR("new_project"), TR("project_name"), "", function(s)
    s = trim(s)
    if s == "" then return end
    if (utf8.len(s) or 0) > 40 then flash(TR("err_long")); return end
    local maxId = 1
    for _, p in ipairs(projects) do if p.id > maxId then maxId = p.id end end
    local p = {id = maxId + 1, name = s, color = COLORS[(#projects) % #COLORS + 1]}
    projects[#projects + 1] = p
    view = p.id
    search = ""
    store.set("view", view)
    save()
  end)
end

local function renameProject(p)
  if not p or p.id == 1 then return end
  ui.prompt(TR("rename_project"), TR("project_name"), p.name, function(s)
    s = trim(s)
    if s ~= "" and (utf8.len(s) or 0) <= 40 then p.name = s; save() end
  end)
end

local function recolorProject(p)
  if not p then return end
  local idx = 1
  for i, c in ipairs(COLORS) do if c == p.color then idx = i end end
  p.color = COLORS[idx % #COLORS + 1]
  save()
end

local function deleteProject(p)
  if not p or p.id == 1 then return end
  ui.alert(TR("delete_project"), TR("delete_project_msg", p.name), {TR("delete"), TR("common.cancel")}, function(b)
    if b ~= 1 then return end
    for _, t in ipairs(tasks) do if t.project == p.id then t.project = 1 end end
    for i, x in ipairs(projects) do if x == p then table.remove(projects, i) break end end
    if view == p.id then view = "all"; store.set("view", view) end
    save()
  end)
end

local function clearCompleted()
  if counts.done == 0 then return end
  ui.alert(TR("clear_done"), TR("clear_done_msg", counts.done), {TR("delete"), TR("common.cancel")}, function(b)
    if b ~= 1 then return end
    for i = #tasks, 1, -1 do if tasks[i].done then ids[tasks[i].id] = nil; table.remove(tasks, i) end end
    save()
    audio.play("trash")
  end)
end

local function setView(v)
  view = v
  search = ""
  selIdx = 0
  dirty = true
  store.set("view", v)
end

local function viewTitle()
  if search ~= "" then return TR("search_results") end
  if type(view) == "number" then local p = projectById(view); return p and p.name or "" end
  if view == "all" then return TR("all_tasks") elseif view == "today" then return TR("today")
  elseif view == "upcoming" then return TR("upcoming") elseif view == "overdue" then return TR("overdue") end
  return TR("completed")
end

-- export the current list as a Markdown checklist
local function exportList()
  if dirty then rebuild() end
  if nVisible == 0 then flash(TR("export_empty")); return end
  ui.saveFile(function(path)
    if not path then return end
    local out = {"# " .. viewTitle(), ""}
    for i = 1, nVisible do
      local t = visible[i]
      local line = "- [" .. (t.done and "x" or " ") .. "] " .. t.title
      local p = projectById(t.project)
      if p then line = line .. "  (" .. p.name .. ")" end
      if t.due then line = line .. "  " .. TR("export_due", isoDate(t.due)) end
      if (t.prio or 0) > 0 then line = line .. "  " .. string.rep("!", t.prio) end
      out[#out + 1] = line
      if t.note and t.note ~= "" then out[#out + 1] = "  " .. t.note end
    end
    if fs.write(path, table.concat(out, "\n") .. "\n") then flash(TR("exported")) else flash(TR("export_fail")) end
  end, "todo.md", TR("export"))
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  MONTHS = {TR("jan"), TR("feb"), TR("mar"), TR("apr"), TR("may"), TR("jun"), TR("jul"), TR("aug"), TR("sep"),
            TR("oct"), TR("nov"), TR("dec")}
  WDAYS = {TR("sun"), TR("mon"), TR("tue"), TR("wed"), TR("thu"), TR("fri"), TR("sat")}
  WSHORT = {TR("sun_s"), TR("mon_s"), TR("tue_s"), TR("wed_s"), TR("thu_s"), TR("fri_s"), TR("sat_s")}
  PRIO_LABELS = {TR("prio_none"), TR("prio_low"), TR("prio_med"), TR("prio_high")}
  SORT_LABELS = {TR("sort_smart"), TR("sort_due"), TR("sort_prio"), TR("sort_name"), TR("sort_new")}
  projects = store.get("projects", nil)
  if type(projects) ~= "table" or #projects == 0 then
    projects = {{id = 1, name = TR("inbox"), color = COLORS[1]}}
  end
  tasks = store.get("tasks", {})
  if type(tasks) ~= "table" then tasks = {} end
  nextId = store.get("nextId", 1)
  for _, t in ipairs(tasks) do if (t.id or 0) >= nextId then nextId = t.id + 1 end end
  showDone = store.get("showDone", false)
  sortMode = store.get("sort", 1)
  if type(sortMode) ~= "number" or sortMode < 1 or sortMode > 5 then sortMode = 1 end
  local v = store.get("view", "all")
  view = v
  if type(v) == "number" then
    local found = false
    for _, p in ipairs(projects) do if p.id == v then found = true end end
    if not found then view = "all" end
  end
  local d = sys.date()
  today = daysFromCivil(d.year, d.month, d.day)
  localOff = today * 86400 + d.hour * 3600 + d.min * 60 + d.sec - sys.epoch()
end

function app.update(dt)
  frameDt = dt
  if msgT > 0 then msgT = msgT - dt end
  if undoT > 0 then undoT = undoT - dt; if undoT <= 0 then undoTask = nil end end
  for id, v in pairs(appear) do
    v = v + dt * 3.5
    if v >= 1 then appear[id] = nil else appear[id] = v end
  end
  for id, v in pairs(pop) do
    v = v - dt * 2.5
    if v <= 0 then pop[id] = nil else pop[id] = v end
  end
  for id, v in pairs(leaving) do
    v = v - dt
    if v <= 0 then leaving[id] = nil; dirty = true else leaving[id] = v end
  end
  local t = sys.time()
  if t - lastCheck > 5 then         -- midnight rollover
    lastCheck = t
    local d = sys.date()
    local n = daysFromCivil(d.year, d.month, d.day)
    if n ~= today then today = n; dirty = true end
  end
  if dirty then rebuild() end
end

-- ------------------------------------------------------------------ drawing: sidebar
local SMART = {
  {"all", "inbox"}, {"today", "today"}, {"upcoming", "event"}, {"overdue", "warning"}, {"done", "task_alt"},
}

local function smartLabel(key)
  if key == "all" then return TR("all_tasks") elseif key == "today" then return TR("today")
  elseif key == "upcoming" then return TR("upcoming") elseif key == "overdue" then return TR("overdue") end
  return TR("completed")
end

local function drawSidebar(x, y, w, h)
  gfx.color(theme.sidebar)
  gfx.rect(x, y, w, h)
  local yy = y + 10
  for _, s in ipairs(SMART) do
    local key = s[1]
    local sel = view == key and search == ""
    if ui.row("smart_" .. key, x + 8, yy, w - 16, 32, sel) then setView(key) end
    local col = key == "overdue" and theme.red or (key == "today" and theme.blue or
                (key == "done" and theme.green or theme.accent))
    gfx.icon(s[2], x + 26, yy + 16, 18, col)
    gfx.color(theme.text)
    gfx.text(smartLabel(key), x + 44, yy + 8, 14)
    local c = counts[key] or 0
    if c > 0 then
      if key == "overdue" then
        local tw = gfx.textWidth(tostring(c), 12, "bold") + 14
        gfx.rect(x + w - 18 - tw, yy + 7, tw, 18, 9, theme.red)
        gfx.color("#FFFFFF")
        gfx.text(tostring(c), x + w - 18 - tw, yy + 9, 12, "bold", "center", tw)
      else
        gfx.color(theme.text3)
        gfx.text(tostring(c), x, yy + 8, 13, "semibold", "right", w - 20)
      end
    end
    yy = yy + 34
  end
  yy = yy + 10
  gfx.color(theme.text2)
  gfx.text(TR("projects"), x + 18, yy + 6, 12, "semibold")
  if ui.iconButton("add", x + w - 42, yy, 30, 28, theme.accent, false, "addproj") then newProject() end
  yy = yy + 34
  local listH = y + h - yy - 8
  ui.beginScroll("projlist", x, yy, w, listH, #projects * 34)
  for i, p in ipairs(projects) do
    local py = (i - 1) * 34
    local sel = view == p.id and search == ""
    if ui.row("proj" .. p.id, 8, py, w - 16, 32, sel) then setView(p.id) end
    local hit = ui.hit("projh" .. p.id, 8, py, w - 16, 32)
    if hit.rightClicked then
      ui.contextMenu({{label = TR("rename"), id = 1, icon = "edit"}, {label = TR("change_color"), id = 2, icon = "palette"},
                      "-", {label = TR("delete"), id = 3, icon = "delete"}}, function(id)
        if id == 1 then renameProject(p) elseif id == 2 then recolorProject(p) elseif id == 3 then deleteProject(p) end
      end)
    end
    gfx.circle(26, py + 16, 6, p.color or COLORS[1])
    gfx.color(theme.text)
    gfx.clip(40, py, math.max(1, w - 90), 32)
    gfx.text(p.name, 42, py + 8, 14)
    gfx.unclip()
    local c = projCount[p.id] or 0
    if c > 0 then
      gfx.color(theme.text3)
      gfx.text(tostring(c), 0, py + 8, 13, "semibold", "right", w - 20)
    end
  end
  ui.endScroll()
  gfx.color(theme.separator)
  gfx.line(x + w - 0.5, y, x + w - 0.5, y + h, 1)
end

-- ------------------------------------------------------------------ drawing: task list
local VIEWS = {"all", "today", "upcoming", "overdue", "done"}

local function drawTaskRow(t, x, y, w, i)
  local c = idsFor(t)
  local rh = ROW_H - 4
  local a = appear[t.id]
  local slide = a and (1 - ease(a)) or 0
  if a then gfx.alpha(ease(a)); x = x + slide * 40 end
  local lv = leaving[t.id]
  if lv and lv < 0.4 then gfx.alpha(lv / 0.4) end
  local rowClicked = ui.row(c[1], x, y, w, rh, i == selIdx)
  local chk = ui.hit(c[2], x + 4, y + 4, 36, rh - 8)
  local overdue = (not t.done) and t.due ~= nil and t.due < today
  if overdue then gfx.rect(x, y + 6, 3, rh - 12, 2, theme.red) end
  -- check circle (pops when completed)
  local pr = t.prio or 0
  local ring = pr == 3 and theme.red or pr == 2 and theme.orange or pr == 1 and theme.blue or theme.text3
  local cx, cy = x + 22, y + rh / 2
  if t.done then
    local p = pop[t.id] or 0
    local r = 10 + math.sin(p * math.pi) * 4
    if p > 0 then
      gfx.color(48, 209, 88, math.floor(120 * p))
      gfx.circleLine(cx, cy, 10 + (1 - p) * 16, 2)
    end
    gfx.circle(cx, cy, r, theme.green)
    gfx.icon("check", cx, cy, 16, "#FFFFFF")
  else
    gfx.color(ring)
    gfx.circleLine(cx, cy, 10, chk.hovered and 2.5 or 1.6)
  end
  -- title + meta line
  local tx = x + 44
  local tw = w - 44 - 30
  gfx.clip(tx, y, math.max(1, tw), rh)
  gfx.color(t.done and theme.text3 or theme.text)
  local titleW = gfx.text(t.title, tx, y + 6, 15, t.done and "sans" or "medium")
  if t.done then
    local p = 1 - (pop[t.id] or 0)
    gfx.line(tx, y + 15, tx + math.min(titleW, tw) * ease(p * 1.5), y + 15, 1)
  end
  local mx = tx
  local p = projectById(t.project)
  if p and (type(view) ~= "number" or search ~= "") then
    gfx.circle(mx + 4, y + 33, 4, p.color or COLORS[1])
    gfx.color(theme.text2)
    mx = mx + 24 + gfx.text(p.name, mx + 12, y + 26, 12)
  end
  if t.due then
    local col = t.done and theme.text3 or (overdue and theme.red or (t.due == today and theme.orange or theme.text2))
    gfx.icon(overdue and "event_busy" or "event", mx + 7, y + 33, 14, col)
    gfx.color(col)
    local label = overdue and TR("due_overdue", dueLabel(t.due), today - t.due) or dueLabel(t.due)
    mx = mx + 30 + gfx.text(label, mx + 17, y + 26, 12, overdue and "semibold" or "sans")
  end
  if t.note and t.note ~= "" then
    gfx.color(theme.text3)
    gfx.text(t.note, mx, y + 26, 12)
  end
  gfx.unclip()
  if pr > 0 and not t.done then gfx.icon("flag", x + w - 18, y + rh / 2, 18, ring) end
  if lv and lv < 0.4 then gfx.unalpha() end
  if a then gfx.unalpha() end
  if chk.clicked then
    toggleDone(t)
  elseif rowClicked then
    selIdx = i
    openEditor(t, false)
  end
end

-- bar chart of completed tasks over the last 7 days (Completed view)
local function drawWeekChart(x, y, w, h)
  ui.group(x, y, w, h)
  gfx.color(theme.text2)
  gfx.text(TR("chart_title"), x + 14, y + 10, 12, "semibold")
  local total = 0
  local mx = 1
  for i = 1, 7 do total = total + week[i]; if week[i] > mx then mx = week[i] end end
  gfx.color(theme.text)
  gfx.text(TR("chart_total", total), x, y + 10, 12, "semibold", "right", w - 14)
  local cx, cy, cw, ch = x + 14, y + 32, w - 28, h - 58
  local bw = cw / 7
  for i = 1, 7 do
    local bh = ch * week[i] / mx
    local bx = cx + (i - 1) * bw + bw * 0.2
    gfx.rect(bx, cy, bw * 0.6, ch, 5, theme.hover)
    if bh > 0 then gfx.rect(bx, cy + ch - bh, bw * 0.6, bh, 5, i == 7 and theme.green or theme.accent) end
    if week[i] > 0 then
      gfx.color(theme.text2)
      gfx.text(tostring(week[i]), bx - 8, cy + ch - bh - 16, 11, "semibold", "center", bw * 0.6 + 16)
    end
    gfx.color(i == 7 and theme.text or theme.text3)
    gfx.text(WSHORT[(today - 7 + i + 4) % 7 + 1], bx - 10, cy + ch + 6, 11, "sans", "center", bw * 0.6 + 20)
  end
end

local function drawList(x, y, w, h, narrow)
  -- header
  gfx.color(theme.text)
  local tx = x + 20
  if narrow then
    local labels, sel = {}, 1
    for i, k in ipairs(VIEWS) do labels[i] = smartLabel(k); if view == k then sel = i end end
    for _, p in ipairs(projects) do labels[#labels + 1] = p.name; if view == p.id then sel = #labels end end
    local ns = ui.dropdown("viewsel", labels, sel, tx, y + 12, math.min(200, w * 0.42), 30)
    if ns ~= sel then
      if ns <= #VIEWS then setView(VIEWS[ns]) else local p = projects[ns - #VIEWS]; if p then setView(p.id) end end
    end
  else
    gfx.text(viewTitle(), tx, y + 14, 22, "bold")
  end
  local sw = math.min(220, w * 0.36)
  local ns = ui.textfield("search", search, x + w - sw - 16, y + 12, sw, 30, TR("search_ph"), "search")
  if ns ~= search then search = ns; dirty = true; selIdx = 0 end
  -- tools row: project actions, show completed, sort
  local hy = y + 52
  local bx = x + 20
  if type(view) == "number" and search == "" then
    local p = projectById(view)
    if p and p.id ~= 1 then
      if ui.iconButton("edit", bx, hy, 30, 28, theme.text2, false, "prjren") then renameProject(p) end
      if ui.iconButton("palette", bx + 34, hy, 30, 28, p.color, false, "prjcol") then recolorProject(p) end
      if ui.iconButton("delete", bx + 68, hy, 30, 28, theme.red, false, "prjdel") then deleteProject(p) end
      bx = bx + 108
    end
  end
  if (view == "all" or type(view) == "number") and search == "" then
    local sd = ui.checkbox(TR("show_completed"), showDone, bx, hy + 5)
    if sd ~= showDone then showDone = sd; store.set("showDone", sd); dirty = true end
  end
  if view ~= "done" then
    local dw = math.min(170, w * 0.32)
    local s = ui.dropdown("sort", SORT_LABELS, sortMode, x + w - dw - 16, hy, dw, 28)
    if s ~= sortMode then sortMode = s; store.set("sort", s); dirty = true end
  end
  hy = hy + 36
  -- quick add
  if view ~= "done" and search == "" then
    local qw = w - 40 - 96
    local q, submitted = ui.textfield("quick", quick, x + 20, hy, qw, 32, TR("quick_ph"))
    quick = q
    if ui.button(TR("add"), x + 28 + qw, hy, 88, 32, "primary", "add") or submitted then
      if addTask(quick) then quick = "" end
    end
    hy = hy + 42
  end
  if view == "done" and search == "" then
    drawWeekChart(x + 20, hy, w - 40, 128)
    hy = hy + 138
    if counts.done > 0 then
      if ui.button(TR("clear_done"), x + 20, hy, 200, 30, "destructive", "delete") then clearCompleted() end
      hy = hy + 40
    end
  end
  -- list
  local listH = y + h - hy - 8
  if nVisible == 0 then
    local cy = hy + math.max(40, listH / 2 - 50)
    local bob = math.sin(sys.time() * 2) * 3
    gfx.circle(x + w / 2, cy + bob, 38, theme.hover)
    gfx.icon(search ~= "" and "search" or (view == "overdue" and "celebration" or "task_alt"), x + w / 2, cy + bob, 44,
             view == "overdue" and theme.green or theme.text3)
    gfx.color(theme.text)
    local m, sub
    if search ~= "" then m, sub = TR("empty_search", search), TR("empty_search_sub")
    elseif view == "overdue" then m, sub = TR("empty_overdue"), TR("empty_overdue_sub")
    elseif view == "done" then m, sub = TR("empty_done"), TR("empty_done_sub")
    elseif view == "today" then m, sub = TR("empty_today"), TR("empty_today_sub")
    else m, sub = TR("empty_list"), TR("empty_list_sub") end
    gfx.text(m, x + 20, cy + 50, 16, "semibold", "center", w - 40)
    gfx.color(theme.text2)
    gfx.text(sub, x + 20, cy + 74, 13, "sans", "center", w - 40)
    return
  end
  ui.beginScroll("tasks", x + 12, hy, w - 24, listH, nVisible * ROW_H + 8)
  local k = 1 - (0.0001) ^ frameDt     -- smooth row movement when the order changes
  for i = 1, nVisible do
    local t = visible[i]
    if t then
      local target = (i - 1) * ROW_H
      local ry = rowY[t.id]
      if not ry then ry = target else ry = ry + (target - ry) * math.min(1, k) end
      if math.abs(ry - target) < 0.5 then ry = target end
      rowY[t.id] = ry
      drawTaskRow(t, 0, ry, w - 24, i)
    end
  end
  ui.endScroll()
end

-- ------------------------------------------------------------------ drawing: editor
local function drawEditor(w, h)
  local t = editing
  local cw = math.min(640, w - 40)
  local x = (w - cw) / 2
  local y = 14
  if ui.button(TR("done_btn"), x, y, 110, 32, "primary", "arrow_back") then closeEditor(); return end
  local bw2 = math.min(210, (cw - 250))
  if ui.button(t.done and TR("mark_open") or TR("mark_done"), x + cw - 130 - bw2, y, bw2, 32, "default",
               t.done and "radio_button_unchecked" or "check_circle") then toggleDone(t) end
  if ui.button(TR("delete"), x + cw - 120, y, 120, 32, "destructive", "delete") then
    deleteTask(t)
    flash(TR("deleted"))
    return
  end
  y = y + 52
  gfx.color(theme.text2)
  gfx.text(TR("title"), x, y, 12, "semibold")
  local nt = ui.textfield("e_title", edTitle, x, y + 18, cw, 34, TR("title_ph"))
  if nt ~= edTitle then
    edTitle = nt
    local tt = trim(nt)
    if tt ~= "" and (utf8.len(tt) or 0) <= 120 then t.title = tt; save() end
  end
  if trim(edTitle) == "" then
    gfx.color(theme.red)
    gfx.text(TR("err_empty"), x, y + 56, 12)
  elseif (utf8.len(trim(edTitle)) or 0) > 120 then
    gfx.color(theme.red)
    gfx.text(TR("err_long"), x, y + 56, 12)
  end
  y = y + 76
  gfx.color(theme.text2)
  gfx.text(TR("note"), x, y, 12, "semibold")
  local nn = ui.textfield("e_note", edNote, x, y + 18, cw, 34, TR("note_ph"))
  if nn ~= edNote then edNote = nn; t.note = trim(nn); save() end
  y = y + 66
  -- project + priority
  local half = (cw - 16) / 2
  gfx.color(theme.text2)
  gfx.text(TR("project"), x, y, 12, "semibold")
  gfx.text(TR("priority"), x + half + 16, y, 12, "semibold")
  local names, sel = {}, 1
  for i, p in ipairs(projects) do names[i] = p.name; if p.id == t.project then sel = i end end
  local ns = ui.dropdown("e_proj", names, sel, x, y + 18, half, 32)
  if ns ~= sel and projects[ns] then t.project = projects[ns].id; save() end
  local np = ui.segmented("e_prio", PRIO_LABELS, (t.prio or 0) + 1, x + half + 16, y + 18, half, 32)
  if np - 1 ~= (t.prio or 0) then t.prio = np - 1; save() end
  y = y + 70
  -- due date
  gfx.color(theme.text2)
  gfx.text(TR("due"), x, y, 12, "semibold")
  local overdue = t.due and t.due < today and not t.done
  gfx.color(t.due and (overdue and theme.red or theme.text) or theme.text3)
  gfx.text(t.due and dueLabel(t.due) or TR("no_due"), x + 100, y - 1, 14, "semibold")
  local nd = ui.textfield("e_due", edDue, x, y + 18, 150, 32, "YYYY-MM-DD")
  if nd ~= edDue then
    edDue = nd
    local n = parseDate(nd)
    if n then t.due = n; save() elseif trim(nd) == "" then t.due = nil; save() end
  end
  if trim(edDue) ~= "" and not parseDate(edDue) then
    gfx.color(theme.red)
    gfx.text(TR("err_date"), x, y + 54, 12)
  end
  local bx = x + 158
  local bw = math.max(44, (cw - 158 - 5 * 6) / 6)
  local function setDue(n)
    t.due = n
    edDue = n and isoDate(n) or ""
    save()
    audio.play("click")
  end
  if ui.button(TR("today"), bx, y + 18, bw, 32) then setDue(today) end
  if ui.button(TR("tomorrow"), bx + (bw + 6), y + 18, bw, 32) then setDue(today + 1) end
  if ui.button(TR("next_week"), bx + (bw + 6) * 2, y + 18, bw, 32) then setDue(today + 7) end
  if ui.button("-1##dm", bx + (bw + 6) * 3, y + 18, bw, 32, "default", nil, t.due ~= nil) then setDue((t.due or today) - 1) end
  if ui.button("+1##dp", bx + (bw + 6) * 4, y + 18, bw, 32, "default", nil, t.due ~= nil) then setDue((t.due or today) + 1) end
  if ui.button(TR("clear"), bx + (bw + 6) * 5, y + 18, bw, 32, "plain", nil, t.due ~= nil) then setDue(nil) end
  y = y + 76
  gfx.color(theme.text3)
  gfx.text(TR("created_on", isoDate(localDay(t.created or sys.epoch()))), x, math.min(y, h - 26), 12)
end

-- ------------------------------------------------------------------ app
local function drawToast(w, h)
  if undoTask and undoT > 0 then
    local text = TR("deleted_named", undoTask.title)
    local tw = math.min(w - 40, gfx.textWidth(text, 13, "semibold") + 140)
    local x, y = (w - tw) / 2, h - 58
    gfx.alpha(math.min(1, undoT * 2))
    gfx.shadow(x, y, tw, 40, 20, 12, 4)
    gfx.rect(x, y, tw, 40, 20, theme.dark and "#3A3A3C" or "#1C1C1E")
    gfx.clip(x + 16, y, math.max(1, tw - 130), 40)
    gfx.color("#FFFFFF")
    gfx.text(text, x + 16, y + 12, 13, "semibold")
    gfx.unclip()
    if ui.button(TR("undo"), x + tw - 108, y + 5, 96, 30, "primary", "undo") then undoDelete() end
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

function app.draw(w, h)
  gfx.clear(theme.bg)
  if dirty then rebuild() end
  if editing then
    drawEditor(w, h)
  else
    local narrow = w < 640
    local sw = narrow and 0 or math.min(230, math.floor(w * 0.28))
    if not narrow then drawSidebar(0, 0, sw, h) end
    drawList(sw, 0, w - sw, h, narrow)
  end
  drawToast(w, h)
end

function app.event(e)
  if e.type ~= "keydown" then return end
  if e.ctrl and e.key == "z" then undoDelete(); return end
  if editing then
    if e.key == "escape" then closeEditor() end
    return
  end
  if e.ctrl and e.key == "n" then ui.focus("quick")
  elseif e.ctrl and e.key == "f" then ui.focus("search")
  elseif e.key == "escape" then
    if search ~= "" then search = ""; dirty = true end
  elseif e.key == "down" and nVisible > 0 then selIdx = math.min(nVisible, selIdx + 1)
  elseif e.key == "up" and nVisible > 0 then selIdx = math.max(1, selIdx - 1)
  elseif e.key == "enter" and selIdx > 0 and visible[selIdx] then openEditor(visible[selIdx], false)
  elseif e.key == "space" and e.ctrl and selIdx > 0 and visible[selIdx] then toggleDone(visible[selIdx])
  elseif e.key == "delete" and selIdx > 0 and visible[selIdx] then deleteTask(visible[selIdx])
  end
end

function app.menu()
  return {
    {title = TR("menu_task"), items = {
      {label = TR("new_task"), id = 1, shortcut = "Ctrl+N"},
      {label = TR("new_project"), id = 2},
      {label = TR("search_menu"), id = 3, shortcut = "Ctrl+F"},
      "-",
      {label = TR("toggle_done_menu"), id = 4, shortcut = "Ctrl+Space"},
      {label = TR("undo_delete"), id = 6, shortcut = "Ctrl+Z"},
      {label = TR("clear_done"), id = 5},
      "-",
      {label = TR("export"), id = 7},
    }},
    {title = TR("menu_view"), items = {
      {label = TR("all_tasks"), id = 10}, {label = TR("today"), id = 11}, {label = TR("upcoming"), id = 12},
      {label = TR("overdue"), id = 13}, {label = TR("completed"), id = 14},
      "-",
      {label = TR("show_completed"), id = 15},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then if editing then closeEditor() end; ui.focus("quick")
  elseif id == 2 then newProject()
  elseif id == 3 then if editing then closeEditor() end; ui.focus("search")
  elseif id == 4 then
    local t = editing or visible[selIdx]
    if t then toggleDone(t) end
  elseif id == 5 then clearCompleted()
  elseif id == 6 then undoDelete()
  elseif id == 7 then exportList()
  elseif id >= 10 and id <= 14 then if editing then closeEditor() end; setView(VIEWS[id - 9])
  elseif id == 15 then showDone = not showDone; store.set("showDone", showDone); dirty = true end
end

function app.close()
  if editing then closeEditor() end
  store.save()
  return true
end

return app
