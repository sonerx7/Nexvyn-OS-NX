-- Tally Counter: several named counters with colors, step sizes and targets (progress rings), a per-counter
-- history with undo and a chart, search and sorting, and export to the clipboard or a CSV file.
local app = {}

-- fills {0}, {1}… with plain text (user text may contain "%", which TR's own substitution must not see)
local function fmt(s, ...)
  local a = {...}
  return (s:gsub("{(%d)}", function(i) local v = a[tonumber(i) + 1]; if v ~= nil then return tostring(v) end end))
end

local floor, min, max, abs, pi = math.floor, math.min, math.max, math.abs, math.pi

local COLORS = {"#0A84FF", "#30D158", "#FF9F0A", "#FF375F", "#BF5AF2", "#64D2FF", "#FFD60A", "#AC8E68"}
local STEPS = {1, 2, 5, 10, 25, 50, 100}
local STEP_LABELS = {"+1", "+2", "+5", "+10", "+25", "+50", "+100"}
local MAX_COUNTERS, MAX_HIST, MAX_NAME = 60, 60, 24
local MAX_VALUE = 999999999

local counters = {}          -- {id, name, value, color, step, target, hist = {{d, v, t}, ...}}
local nextId = 1
local sel = 1                -- index into counters
local search = ""
local sortMode = 1           -- 1 manual, 2 name, 3 value
local view, viewDirty = {}, true
local anim = {}              -- id -> {shown = eased value, bump = 0..1, ring = eased fraction}
local toast, toastT, undoDel = "", 0, nil
local editing = false        -- the search field has the keyboard
local fieldRect = {0, 0, 0, 0}
local shake = 0

local function clampInt(n, lo, hi) return max(lo, min(hi, floor(n))) end

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function utrunc(s, n)
  local len = utf8.len(s) or #s
  if len <= n then return s end
  local cut = utf8.offset(s, n + 1)
  return (cut and s:sub(1, cut - 1) or s) .. "…"
end

local function save()
  store.set("counters", counters)
  store.set("nextId", nextId)
  store.set("sel", sel)
  viewDirty = true
end

local function showToast(s, undo) toast, toastT, undoDel = s, undo and 5 or 2.2, undo end

local function current() return counters[sel] end

local function A(c)
  local a = anim[c.id]
  if not a then
    a = {shown = c.value, bump = 0, ring = 0}
    anim[c.id] = a
  end
  return a
end

-- the order the grid shows: search filter + sort mode
local function buildView()
  view = {}
  local q = search:lower()
  for i, c in ipairs(counters) do
    if q == "" or c.name:lower():find(q, 1, true) then view[#view + 1] = i end
  end
  if sortMode == 2 then
    table.sort(view, function(a, b) return counters[a].name:lower() < counters[b].name:lower() end)
  elseif sortMode == 3 then
    table.sort(view, function(a, b)
      if counters[a].value ~= counters[b].value then return counters[a].value > counters[b].value end
      return a < b
    end)
  end
  viewDirty = false
end

local function total()
  local s = 0
  for _, c in ipairs(counters) do s = s + c.value end
  return s
end

-- changes a counter by delta, records it for undo and celebrates a reached target
local function change(i, delta, silent)
  local c = counters[i]
  if not c or delta == 0 then return end
  local before = c.value
  local after = clampInt(before + delta, 0, MAX_VALUE)
  if after == before then
    shake = 1
    audio.play("error")
    return
  end
  c.value = after
  c.hist[#c.hist + 1] = {d = after - before, v = after, t = sys.epoch()}
  while #c.hist > MAX_HIST do table.remove(c.hist, 1) end
  sel = i
  A(c).bump = 1
  save()
  if not silent then audio.tone(after > before and 880 or 520, 0.04, 0.25, "sine") end
  if c.target and c.target > 0 and before < c.target and after >= c.target then
    showToast(fmt(TR("target_reached"), utrunc(c.name, 16), c.target))
    audio.play("notify")
    sys.vibrate(0.6, 120)
  end
end

local function inc(i) local c = counters[i]; if c then change(i, c.step) end end
local function dec(i) local c = counters[i]; if c then change(i, -c.step) end end

local function undoLast(i)
  local c = counters[i]
  if not c or #c.hist == 0 then return end
  local h = table.remove(c.hist)
  c.value = clampInt(c.value - (tonumber(h.d) or 0), 0, MAX_VALUE)
  A(c).bump = 1
  save()
  audio.play("pop")
end

local function addCounter()
  if #counters >= MAX_COUNTERS then showToast(TR("too_many", MAX_COUNTERS)); return end
  ui.prompt(TR("new_counter"), TR("name_msg"), TR("default_name", #counters + 1), function(s)
    s = trim(s)
    if s == "" then return end
    if #counters >= MAX_COUNTERS then return end
    counters[#counters + 1] = {id = nextId, name = utrunc(s, MAX_NAME), value = 0,
                               color = (#counters % #COLORS) + 1, step = 1, target = 0, hist = {}}
    nextId = nextId + 1
    sel = #counters
    search = ""
    save()
  end)
end

local function renameCounter(i)
  local c = counters[i]
  if not c then return end
  ui.prompt(TR("rename"), TR("name_msg"), c.name, function(s)
    s = trim(s)
    if s ~= "" and counters[i] == c then c.name = utrunc(s, MAX_NAME); save() end
  end)
end

local function setTarget(i)
  local c = counters[i]
  if not c then return end
  ui.prompt(TR("target"), TR("target_msg"), c.target > 0 and tostring(c.target) or "", function(s)
    s = trim(s)
    if counters[i] ~= c then return end
    if s == "" or s == "0" then c.target = 0; save(); return end
    local n = tonumber(s)
    if not n or n < 1 or n > MAX_VALUE or n ~= floor(n) then showToast(TR("bad_number")); return end
    c.target = floor(n)
    save()
  end)
end

local function resetCounter(i)
  local c = counters[i]
  if not c or c.value == 0 then return end
  ui.alert(TR("reset"), fmt(TR("reset_msg"), c.name), {TR("reset"), TR("common.cancel")}, function(b)
    if b == 1 and counters[i] == c then change(i, -c.value, true) end
  end)
end

local function resetAll()
  if total() == 0 then return end
  ui.alert(TR("reset_all"), TR("reset_all_msg"), {TR("reset"), TR("common.cancel")}, function(b)
    if b ~= 1 then return end
    for i, c in ipairs(counters) do if c.value > 0 then change(i, -c.value, true) end end
  end)
end

local function deleteCounter(i)
  local c = counters[i]
  if not c then return end
  ui.alert(TR("delete"), fmt(TR("delete_msg"), c.name), {TR("delete"), TR("common.cancel")}, function(b)
    if b ~= 1 or counters[i] ~= c then return end
    table.remove(counters, i)
    sel = max(1, min(sel, #counters))
    save()
    showToast(fmt(TR("deleted"), utrunc(c.name, 16)), {c = c, i = i})
  end)
end

local function undoDelete()
  local u = undoDel
  if not u then return end
  table.insert(counters, min(u.i, #counters + 1), u.c)
  sel = min(u.i, #counters)
  undoDel, toastT = nil, 0
  save()
end

local function move(i, d)
  local j = i + d
  if not counters[i] or not counters[j] then return end
  counters[i], counters[j] = counters[j], counters[i]
  sel = j
  sortMode = 1
  store.set("sort", sortMode)
  save()
end

local function exportText()
  if #counters == 0 then showToast(TR("empty_title")); return end
  local lines = {}
  for _, c in ipairs(counters) do
    lines[#lines + 1] = c.name .. ": " .. c.value .. (c.target > 0 and (" / " .. c.target) or "")
  end
  lines[#lines + 1] = TR("total") .. ": " .. total()
  sys.clipboard(table.concat(lines, "\n"))
  showToast(TR("copied"))
end

local function exportCsv()
  if #counters == 0 then showToast(TR("empty_title")); return end
  ui.saveFile(function(path)
    if not path then return end
    local lines = {"name,value,target,step"}
    for _, c in ipairs(counters) do
      lines[#lines + 1] = '"' .. c.name:gsub('"', '""') .. '",' .. c.value .. "," .. c.target .. "," .. c.step
    end
    if fs.write(path, table.concat(lines, "\n") .. "\n") then showToast(TR("saved")) else showToast(TR("save_failed")) end
  end, "tally.csv", TR("export_csv"))
end

-- ------------------------------------------------------------------ app
function app.load(arg)
  counters = {}
  local saved = store.get("counters", nil)
  nextId = floor(tonumber(store.get("nextId", 1)) or 1)
  if type(saved) == "table" then
    for _, c in ipairs(saved) do
      if type(c) == "table" then
        local hist = {}
        if type(c.hist) == "table" then
          for _, h in ipairs(c.hist) do
            if type(h) == "table" and tonumber(h.d) then hist[#hist + 1] = {d = tonumber(h.d), v = tonumber(h.v) or 0, t = tonumber(h.t) or 0} end
          end
        end
        local id = floor(tonumber(c.id) or nextId)
        nextId = max(nextId, id + 1)
        counters[#counters + 1] = {id = id, name = tostring(c.name or "?"), value = clampInt(tonumber(c.value) or 0, 0, MAX_VALUE),
          color = clampInt(tonumber(c.color) or 1, 1, #COLORS), step = clampInt(tonumber(c.step) or 1, 1, 100),
          target = clampInt(tonumber(c.target) or 0, 0, MAX_VALUE), hist = hist}
      end
    end
  else
    -- first run: two example counters
    counters = {
      {id = 1, name = TR("example1"), value = 0, color = 1, step = 1, target = 8, hist = {}},
      {id = 2, name = TR("example2"), value = 0, color = 2, step = 1, target = 0, hist = {}},
    }
    nextId = 3
  end
  sel = clampInt(tonumber(store.get("sel", 1)) or 1, 1, max(1, #counters))
  sortMode = clampInt(tonumber(store.get("sort", 1)) or 1, 1, 3)
end

function app.update(dt)
  toastT = max(0, toastT - dt)
  if toastT == 0 then undoDel = nil end
  shake = max(0, shake - dt * 4)
  for _, c in ipairs(counters) do
    local a = A(c)
    a.shown = a.shown + (c.value - a.shown) * min(1, dt * 12)
    if abs(a.shown - c.value) < 0.01 then a.shown = c.value end
    a.bump = max(0, a.bump - dt * 4)
    local f = (c.target > 0) and min(1, c.value / c.target) or 0
    a.ring = a.ring + (f - a.ring) * min(1, dt * 8)
  end
end

local function ring(cx, cy, r, frac, color, thick)
  gfx.color(theme.separator)
  gfx.arc(cx, cy, r, 0, pi * 2, thick)
  if frac > 0.002 then
    gfx.color(color)
    gfx.arc(cx, cy, r, -pi / 2, -pi / 2 + pi * 2 * min(1, frac), thick)
  end
end

local function drawCard(i, x, y, cw, ch)
  local c = counters[i]
  local a = A(c)
  local col = COLORS[c.color] or COLORS[1]
  gfx.color(theme.field)
  gfx.rect(x, y, cw, ch, 12)
  gfx.color(col)
  gfx.rect(x, y + 12, 5, ch - 24, 2)
  if i == sel then
    gfx.color(theme.accent)
    gfx.rectLine(x, y, cw, ch, 12, 2)
  end
  local hasRing = c.target > 0 and cw >= 170
  local tw = cw - 28 - (hasRing and 64 or 0)
  gfx.color(theme.text2)
  gfx.text(utrunc(c.name, max(4, floor(tw / 8))), x + 16, y + 12, 13, "semibold")
  gfx.color(theme.text)
  local sz = 34 + a.bump * 6
  local dx = (i == sel and shake > 0) and math.sin(shake * 30) * 6 * shake or 0
  gfx.text(tostring(floor(a.shown + 0.5)), x + 16 + dx, y + 30 - a.bump * 3, sz, "bold")
  if hasRing then
    local rx, ry = x + cw - 40, y + 44
    ring(rx, ry, 24, a.ring, c.value >= c.target and theme.green or col, 5)
    gfx.color(theme.text2)
    gfx.text(floor(a.ring * 100 + 0.5) .. "%", rx - 24, ry - 7, 11, "semibold", "center", 48)
  elseif c.target > 0 then
    gfx.color(theme.text3)
    gfx.text("/ " .. c.target, x + 16, y + 68, 11)
  end
  local hit = ui.hit("card" .. c.id, x, y, cw, 76)
  if hit.clicked then sel = i; inc(i) end
  local bw = (cw - 32 - 8) / 2
  if ui.button("##m" .. c.id, x + 16, y + ch - 42, bw, 32, "default", "remove", c.value > 0) then dec(i) end
  if ui.button("##p" .. c.id, x + 24 + bw, y + ch - 42, bw, 32, "primary", "add") then inc(i) end
end

local function drawGrid(gx, gy, gw, gh)
  if viewDirty then buildView() end
  if #counters == 0 then
    local cy = gy + gh / 2
    gfx.icon("exposure_plus_1", gx + gw / 2, cy - 60, 64, theme.text3)
    gfx.color(theme.text)
    gfx.text(TR("empty_title"), gx, cy - 16, 17, "semibold", "center", gw)
    gfx.color(theme.text2)
    gfx.text(TR("empty_hint"), gx, cy + 8, 13, "sans", "center", gw)
    if ui.button(TR("new_counter") .. "##empty", gx + gw / 2 - 90, cy + 40, 180, 36, "primary", "add") then addCounter() end
    return
  end
  if #view == 0 then
    gfx.icon("search_off", gx + gw / 2, gy + gh / 2 - 30, 48, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("no_match"), gx, gy + gh / 2 + 4, 14, "semibold", "center", gw)
    return
  end
  local cols = max(1, floor((gw + 12) / (176 + 12)))
  local cw = (gw - (cols - 1) * 12) / cols
  local ch = 124
  local rows = math.ceil(#view / cols)
  ui.beginScroll("grid", gx, gy, gw, gh, rows * (ch + 12))
  for k, i in ipairs(view) do
    if counters[i] then
      local col, row = (k - 1) % cols, floor((k - 1) / cols)
      drawCard(i, col * (cw + 12), row * (ch + 12), cw, ch)
    end
  end
  ui.endScroll()
end

-- small chart of the counter's value over its recorded changes
local function drawChart(c, x, y, w, h)
  gfx.color(theme.bg)
  gfx.rect(x, y, w, h, 8)
  local n = #c.hist
  if n < 2 then
    gfx.color(theme.text3)
    gfx.text(TR("chart_empty"), x, y + h / 2 - 8, 12, "sans", "center", w)
    return
  end
  local mx = max(1, c.target)
  for _, e in ipairs(c.hist) do mx = max(mx, e.v) end
  local px, py, pw, ph = x + 8, y + 8, w - 16, h - 16
  gfx.color(COLORS[c.color] or theme.accent)
  local prevX, prevY
  for k, e in ipairs(c.hist) do
    local ex = px + (k - 1) / (n - 1) * pw
    local ey = py + ph - ph * e.v / mx
    if prevX then gfx.line(prevX, prevY, ex, ey, 2) end
    prevX, prevY = ex, ey
  end
  gfx.circle(prevX, prevY, 3.5)
  if c.target > 0 then
    local ty = py + ph - ph * c.target / mx
    gfx.color(theme.orange)
    for xx = px, px + pw - 6, 10 do gfx.line(xx, ty, xx + 5, ty, 1.5) end
  end
end

local function drawPanel(px, py, pw, ph)
  gfx.color(theme.field)
  gfx.rect(px, py, pw, ph, 14)
  local c = current()
  local x, w = px + 14, pw - 28
  if not c then
    gfx.icon("touch_app", px + pw / 2, py + ph / 2 - 20, 44, theme.text3)
    gfx.color(theme.text3)
    gfx.text(TR("select_hint"), px + 10, py + ph / 2 + 12, 13, "sans", "center", pw - 20)
    return
  end
  local i = sel
  local a = A(c)
  local col = COLORS[c.color] or COLORS[1]
  -- header
  gfx.circle(x + 7, py + 26, 7, col)
  gfx.color(theme.text)
  gfx.text(utrunc(c.name, 18), x + 22, py + 16, 16, "semibold")
  if ui.iconButton("edit", px + pw - 46, py + 10, 32, 30, theme.text2, false, "ren") then renameCounter(i) end
  -- value with big -/+ buttons
  local vy = py + 52
  if ui.button("##bigm", x, vy, 50, 46, "default", "remove", c.value > 0) then dec(i) end
  if ui.button("##bigp", x + w - 50, vy, 50, 46, "primary", "add") then inc(i) end
  gfx.color(theme.text)
  gfx.text(tostring(floor(a.shown + 0.5)), x + 50, vy + 4 - a.bump * 3, 32 + a.bump * 6, "bold", "center", w - 100)
  -- step and target
  local ry = vy + 60
  gfx.color(theme.text2)
  gfx.text(TR("step"), x, ry + 8, 13)
  local si = 1
  for k, s in ipairs(STEPS) do if s == c.step then si = k end end
  local ns = ui.dropdown("step", STEP_LABELS, si, x + w - 100, ry, 100, 30)
  if STEPS[ns] and STEPS[ns] ~= c.step then c.step = STEPS[ns]; save() end
  ry = ry + 38
  gfx.color(theme.text2)
  gfx.text(TR("target"), x, ry + 8, 13)
  local tl = c.target > 0 and tostring(c.target) or TR("none")
  if ui.button(tl .. "##target", x + w - 100, ry, 100, 30, "default", "flag") then setTarget(i) end
  -- colors
  ry = ry + 40
  local sw = w / #COLORS
  for k, cc in ipairs(COLORS) do
    local cx = x + (k - 0.5) * sw
    if k == c.color then
      gfx.color(theme.text)
      gfx.circleLine(cx, ry + 14, 13, 2)
    end
    gfx.circle(cx, ry + 14, 10, cc)
    if ui.hit("col" .. k, cx - 14, ry, 28, 28).clicked and c.color ~= k then c.color = k; save() end
  end
  -- chart
  ry = ry + 36
  local chH = max(40, min(80, ph - (ry - py) - 96))
  drawChart(c, x, ry, w, chH)
  ry = ry + chH + 8
  -- actions
  local bw = (w - 16) / 5
  if ui.iconButton("undo", x, ry, bw, 32, #c.hist > 0 and theme.text or theme.text3, false, "u") then undoLast(i) end
  if ui.iconButton("arrow_upward", x + (bw + 4), ry, bw, 32, theme.text2, false, "up") then move(i, -1) end
  if ui.iconButton("arrow_downward", x + (bw + 4) * 2, ry, bw, 32, theme.text2, false, "dn") then move(i, 1) end
  if ui.iconButton("restart_alt", x + (bw + 4) * 3, ry, bw, 32, theme.orange, false, "rs") then resetCounter(i) end
  if ui.iconButton("delete", x + (bw + 4) * 4, ry, bw, 32, theme.red, false, "del") then deleteCounter(i) end
  -- last change
  ry = ry + 40
  local h = c.hist[#c.hist]
  gfx.color(theme.text3)
  if h then
    local d = sys.date(h.t)
    local sign = h.d > 0 and "+" or ""
    gfx.text(TR("last_change", sign .. h.d, string.format("%02d:%02d", d.hour or 0, d.min or 0)), x, ry, 12)
  else
    gfx.text(TR("no_changes"), x, ry, 12)
  end
end

local function drawToast(w, h)
  if toastT <= 0 then return end
  local a = min(1, toastT * 4)
  local tw = min(w - 40, gfx.textWidth(toast, 13, "semibold") + 36)
  local extra = undoDel and 76 or 0
  local tx, ty = (w - tw - extra) / 2, h - 58 + (1 - a) * 20
  gfx.alpha(a)
  gfx.shadow(tx, ty, tw + extra, 38, 19, 12, 4)
  gfx.color(theme.dark and "#3A3A3C" or "#1C1C1E")
  gfx.rect(tx, ty, tw + extra, 38, 19)
  gfx.color("#FFFFFF")
  gfx.text(toast, tx + 18, ty + 10, 13, "semibold")
  gfx.unalpha()
  if undoDel and ui.button(TR("undo"), tx + tw, ty + 4, 70, 30, "plain") then undoDelete() end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local pw = w >= 720 and 260 or 240
  local gx, gw = 20, w - 40 - pw - 16
  -- toolbar: title + total, search, sort, add
  gfx.color(theme.text)
  gfx.text(TR("app_name"), gx, 16, 18, "bold")
  gfx.color(theme.text2)
  gfx.text(TR("total") .. ": " .. total(), gx, 18, 14, "semibold", "right", gw)
  local ty = 48
  local sw = gw - 44 - 104
  fieldRect[1], fieldRect[2], fieldRect[3], fieldRect[4] = gx, ty, sw, 32
  local ns = ui.textfield("search", search, gx, ty, sw, 32, TR("search"), "search")
  if ns ~= search then search = ns; viewDirty = true end
  local sm = ui.dropdown("sort", {TR("sort_manual"), TR("sort_name"), TR("sort_value")}, sortMode, gx + sw + 6, ty, 98, 32)
  if sm ~= sortMode then sortMode = sm; store.set("sort", sortMode); viewDirty = true end
  if ui.iconButton("add", gx + gw - 36, ty, 36, 32, theme.accent) then addCounter() end
  drawGrid(gx, ty + 44, gw, h - ty - 44 - 16)
  drawPanel(w - 20 - pw, 16, pw, h - 32)
  drawToast(w, h)
end

function app.event(e)
  if e.type == "mousedown" then
    local r = fieldRect
    editing = e.x >= r[1] and e.y >= r[2] and e.x <= r[1] + r[3] and e.y <= r[2] + r[4]
    return
  end
  if e.type ~= "keydown" then return end
  local k = e.key
  if k == "escape" or k == "enter" then
    if editing then editing = false; return end
  end
  if e.ctrl and k == "n" then addCounter(); return end
  if e.ctrl and k == "z" then if undoDel then undoDelete() else undoLast(sel) end; return end
  if editing then return end
  if k == "up" or k == "space" then inc(sel)
  elseif k == "down" then dec(sel)
  elseif k == "backspace" then undoLast(sel)
  elseif k == "right" or k == "left" then
    if viewDirty then buildView() end
    local pos = 1
    for p, i in ipairs(view) do if i == sel then pos = p end end
    pos = pos + (k == "right" and 1 or -1)
    if view[pos] then sel = view[pos]; store.set("sel", sel) end
  elseif k == "delete" then deleteCounter(sel)
  elseif k == "r" then resetCounter(sel) end
end

function app.menu()
  return {
    {title = TR("app_name"), items = {
      {label = TR("new_counter"), id = 1, shortcut = "Ctrl+N"},
      "-",
      {label = TR("copy_all"), id = 2},
      {label = TR("export_csv"), id = 3},
      "-",
      {label = TR("reset_all"), id = 4},
    }},
    {title = TR("menu_counter"), items = {
      {label = TR("increment"), id = 10, shortcut = "Space"},
      {label = TR("decrement"), id = 11, shortcut = "Down"},
      {label = TR("undo"), id = 12, shortcut = "Backspace"},
      "-",
      {label = TR("rename"), id = 13},
      {label = TR("target"), id = 14},
      {label = TR("move_up"), id = 15},
      {label = TR("move_down"), id = 16},
      "-",
      {label = TR("reset"), id = 17, shortcut = "R"},
      {label = TR("delete"), id = 18, shortcut = "Delete"},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then addCounter() elseif id == 2 then exportText() elseif id == 3 then exportCsv()
  elseif id == 4 then resetAll()
  elseif id == 10 then inc(sel) elseif id == 11 then dec(sel) elseif id == 12 then undoLast(sel)
  elseif id == 13 then renameCounter(sel) elseif id == 14 then setTarget(sel)
  elseif id == 15 then move(sel, -1) elseif id == 16 then move(sel, 1)
  elseif id == 17 then resetCounter(sel) elseif id == 18 then deleteCounter(sel) end
end

function app.close()
  store.save()
  return true
end

return app
