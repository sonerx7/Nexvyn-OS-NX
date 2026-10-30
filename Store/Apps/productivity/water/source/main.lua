-- Water: a daily water tracker. Sample app for the Nexvyn OS Lua SDK (store, timer, sys.notify, gfx, ui, menus).
local app = {}

local tab = 1
local goal, glass, remind, interval = 2000, 250, false, 60
local log = {}        -- "YYYY-MM-DD" -> ml
local adds = {}       -- today's additions, newest last (for undo)
local today = ""
local shown = 0       -- animated fill amount
local remindTimer = nil
local started = 0

local GLASSES = {150, 200, 250, 330, 500}

local function dayKey(epoch)
  local d = sys.date(epoch)
  return string.format("%04d-%02d-%02d", d.year, d.month, d.day)
end

local function save()
  store.set("log", log)
  store.set("adds", {day = today, list = adds})
end

local function rollDay()
  local k = dayKey()
  if k ~= today then
    today = k
    adds = {}
    save()
  end
end

local function amount() return log[today] or 0 end

local function add(ml)
  rollDay()
  local before = amount()
  log[today] = before + ml
  adds[#adds + 1] = ml
  save()
  audio.tone(520 + math.min(#adds, 12) * 30, 0.08, 0.35, "sine")
  if before < goal and log[today] >= goal then
    sys.notify(TR("app_name"), TR("goal_reached", goal))
    audio.play("notify")
  end
end

local function undo()
  if #adds == 0 then return end
  local ml = table.remove(adds)
  log[today] = math.max(0, amount() - ml)
  save()
  audio.play("pop")
end

local function setReminder()
  if remindTimer then timer.cancel(remindTimer); remindTimer = nil end
  if not remind then return end
  remindTimer = timer.every(interval * 60, function()
    rollDay()
    if amount() < goal then sys.notify(TR("app_name"), TR("remind_body", goal - amount())) end
  end)
end

function app.load(arg)
  goal = store.get("goal", 2000)
  glass = store.get("glass", 250)
  remind = store.get("remind", false)
  interval = store.get("interval", 60)
  log = store.get("log", {})
  today = dayKey()
  local a = store.get("adds", {})
  if a.day == today and type(a.list) == "table" then adds = a.list end
  shown = amount()
  started = sys.time()
  setReminder()
end

function app.update(dt)
  rollDay()
  shown = shown + (amount() - shown) * math.min(1, dt * 6)
end

-- the glass on the left: a rounded body that fills from the bottom with a moving water line
local function drawGlass(x, y, w, h)
  local frac = math.min(1, shown / math.max(1, goal))
  local t = sys.time() - started
  gfx.shadow(x, y, w, h, 18, 16, 6)
  gfx.color(theme.field)
  gfx.rect(x, y, w, h, 18)
  local fh = (h - 12) * frac
  if fh > 1 then
    gfx.clip(x + 6, y + 6, w - 12, h - 12)
    local top = y + h - 6 - fh
    gfx.gradient(x + 6, top, w - 12, fh, "#5AC8FA", "#0A84FF", false, 12)
    -- wave crests along the water line
    gfx.color(90, 200, 250, 255)
    for i = 0, 8 do
      local cx = x + 6 + i * (w - 12) / 8
      gfx.circle(cx, top + math.sin(t * 2.4 + i * 0.9) * 3, 7)
    end
    -- bubbles
    gfx.color(255, 255, 255, 90)
    for i = 1, 5 do
      local by = y + h - 10 - ((t * 28 + i * 47) % math.max(1, fh))
      gfx.circle(x + 18 + (i * 37) % (w - 36), by, 2 + i % 3)
    end
    gfx.unclip()
  end
  gfx.color(theme.separator)
  gfx.rectLine(x, y, w, h, 18, 2)
  -- the percentage sits near the top of the glass, white once the water has risen over it
  local ly = y + 22
  gfx.color(fh > h - 12 - 60 and "#FFFFFF" or theme.text)
  gfx.text(math.floor(frac * 100 + 0.5) .. "%", x, ly, 28, "bold", "center", w)
end

local function drawToday(w, h)
  local gx, gy, gw, gh = 28, 66, 170, h - 92
  drawGlass(gx, gy, gw, gh)

  local x = gx + gw + 32
  local cw = w - x - 24
  gfx.color(theme.text2)
  gfx.text(TR("today"), x, 70, 14, "semibold")
  gfx.color(theme.text)
  local used = gfx.text(tostring(amount()), x, 90, 40, "bold")
  gfx.color(theme.text2)
  gfx.text("/ " .. goal .. " ml", x + used + 8, 108, 17)
  ui.progress(math.min(1, amount() / goal), x, 146, cw, 8)
  local left = goal - amount()
  gfx.color(left > 0 and theme.text2 or theme.green)
  gfx.text(left > 0 and TR("left", left) or TR("done"), x, 162, 13)

  local bw = (cw - 12) / 2
  if ui.button(TR("add_glass", glass), x, 196, bw, 40, "primary", "local_drink") then add(glass) end
  if ui.button(TR("add_bottle"), x + bw + 12, 196, bw, 40, "default", "water_drop") then add(500) end
  if ui.button(TR("add_custom"), x, 246, bw, 34, "default", "edit") then
    ui.prompt(TR("add_custom"), TR("custom_msg"), tostring(glass), function(s)
      local n = tonumber(s or "")
      if n and n > 0 and n <= 3000 then add(math.floor(n)) end
    end)
  end
  if ui.button(TR("undo"), x + bw + 12, 246, bw, 34, "plain", "undo", #adds > 0) then undo() end

  gfx.color(theme.text3)
  gfx.text(TR("count_today", #adds), x, 296, 12)
  for i = 1, math.min(#adds, 12) do
    gfx.icon("water_drop", x + 8 + (i - 1) * 20, 326, 18, theme.blue)
  end
end

local function drawHistory(w, h)
  gfx.color(theme.text)
  gfx.text(TR("last7"), 24, 62, 17, "semibold")
  local cx, cy, cw, ch = 40, 104, w - 64, h - 176
  local mx = goal
  local days = {}
  local now = sys.epoch()
  for i = 6, 0, -1 do
    local e = now - i * 86400
    local v = log[dayKey(e)] or 0
    mx = math.max(mx, v)
    days[#days + 1] = {d = sys.date(e), v = v}
  end
  mx = mx * 1.1
  local gyLine = cy + ch - ch * goal / mx
  gfx.color(theme.separator)
  gfx.line(cx, cy + ch, cx + cw, cy + ch, 1)
  local bw = cw / 7
  local hit = 0
  for i, it in ipairs(days) do
    local bh = ch * it.v / mx
    local bx = cx + (i - 1) * bw + 10
    if bh > 0 then
      gfx.color(it.v >= goal and theme.green or theme.blue)
      gfx.rect(bx, cy + ch - bh, bw - 20, bh, 6)
    end
    if it.v >= goal then hit = hit + 1 end
    gfx.color(theme.text2)
    gfx.text(string.format("%02d.%02d", it.d.day, it.d.month), bx - 6, cy + ch + 8, 12, "sans", "center", bw - 8)
    if it.v > 0 then
      gfx.color(theme.text3)
      gfx.text(tostring(it.v), bx - 6, cy + ch - bh - 18, 11, "sans", "center", bw - 8)
    end
  end
  gfx.color(theme.orange)
  for xx = cx, cx + cw - 8, 14 do gfx.line(xx, gyLine, xx + 7, gyLine, 2) end
  gfx.text(TR("goal_line", goal), 0, gyLine - 18, 11, "semibold", "right", cx + cw)
  gfx.color(theme.text2)
  gfx.text(TR("streak", hit), 24, h - 32, 13)
end

local function drawSettings(w, h)
  local y = 64
  ui.group(20, y, w - 40, 196)
  gfx.color(theme.text)
  gfx.text(TR("daily_goal"), 36, y + 14, 14)
  gfx.color(theme.text2)
  gfx.text(goal .. " ml", 0, y + 14, 14, "sans", "right", w - 36)
  local g = ui.slider("goal", goal, 1000, 4000, 36, y + 40, w - 72, 250)
  if g ~= goal then goal = g; store.set("goal", goal) end
  ui.separator(36, y + 76, w - 36)
  gfx.color(theme.text)
  gfx.text(TR("glass_size"), 36, y + 90, 14)
  local labels, sel = {}, 3
  for i, v in ipairs(GLASSES) do labels[i] = v .. " ml"; if v == glass then sel = i end end
  local ns = ui.dropdown("glass", labels, sel, w - 176, y + 84, 140)
  if GLASSES[ns] ~= glass then glass = GLASSES[ns]; store.set("glass", glass) end
  ui.separator(36, y + 122, w - 36)
  gfx.color(theme.text)
  gfx.text(TR("reminders"), 36, y + 136, 14)
  local r = ui.toggle("remind", remind, w - 78, y + 132)
  if r ~= remind then remind = r; store.set("remind", remind); setReminder() end
  gfx.color(remind and theme.text2 or theme.text3)
  gfx.text(TR("every_min", interval), 36, y + 162, 12)
  if remind then
    local iv = ui.slider("interval", interval, 15, 180, 200, y + 158, w - 236, 15)
    if iv ~= interval then interval = iv; store.set("interval", interval); setReminder() end
  end
  if ui.button(TR("reset_today"), 20, y + 216, 180, 34, "destructive", "restart_alt", amount() > 0) then
    ui.alert(TR("reset_today"), TR("reset_msg"), {TR("reset"), TR("common.cancel")}, function(b)
      if b == 1 then log[today] = 0; adds = {}; save() end
    end)
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  tab = ui.segmented("tabs", {TR("tab_today"), TR("tab_history"), TR("tab_settings")}, tab, w / 2 - 170, 14, 340, 30)
  if tab == 1 then drawToday(w, h) elseif tab == 2 then drawHistory(w, h) else drawSettings(w, h) end
end

function app.event(e)
  if e.type ~= "keydown" then return end
  if e.key == "space" or e.key == "enter" then add(glass)
  elseif e.key == "backspace" then undo()
  elseif e.key == "right" then tab = tab % 3 + 1
  elseif e.key == "left" then tab = (tab + 1) % 3 + 1 end
end

function app.menu()
  return {{title = TR("app_name"), items = {
    {label = TR("add_glass", glass), id = 1, shortcut = "Space"},
    {label = TR("undo"), id = 2, shortcut = "Backspace"},
    "-",
    {label = TR("reset_today"), id = 3},
  }}}
end

function app.onmenu(id)
  if id == 1 then add(glass) elseif id == 2 then undo()
  elseif id == 3 then log[today] = 0; adds = {}; save() end
end

function app.close()
  if remindTimer then timer.cancel(remindTimer) end
  store.save()
  return true
end

return app
