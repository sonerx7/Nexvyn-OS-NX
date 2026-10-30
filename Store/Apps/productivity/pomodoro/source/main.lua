-- Pomodoro for Nexvyn OS: focus / short break / long break cycle with statistics.
local app = {}

local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi

-- ------------------------------------------------------------------ colors
local cache = {}
local function rgba(c)
  local t = cache[c]
  if not t then
    t = {tonumber(c:sub(2, 3), 16) or 0, tonumber(c:sub(4, 5), 16) or 0, tonumber(c:sub(6, 7), 16) or 0,
         #c >= 9 and (tonumber(c:sub(8, 9), 16) or 255) or 255}
    cache[c] = t
  end
  return t
end
local function alpha(c, a)
  local t = rgba(c)
  return {t[1], t[2], t[3], max(0, min(255, floor(t[4] * a + 0.5)))}
end
local function mix(c1, c2, k)
  local a, b = rgba(c1), rgba(c2)
  return {floor(a[1] + (b[1] - a[1]) * k + 0.5), floor(a[2] + (b[2] - a[2]) * k + 0.5),
          floor(a[3] + (b[3] - a[3]) * k + 0.5), floor(a[4] + (b[4] - a[4]) * k + 0.5)}
end

-- ------------------------------------------------------------------ settings & state
local cfg = {focus = 25, short = 5, long = 15, rounds = 4, autoBreak = true, autoFocus = false, sound = true, ticks = true}

local PHASES = {
  focus = {key = "phase_focus", icon = "work", color = "red"},
  short = {key = "phase_short", icon = "coffee", color = "green"},
  long = {key = "phase_long", icon = "self_improvement", color = "blue"},
}

local tab = 1
local phase = "focus"
local cycle = 1                -- focus session number within the current set
local running = false
local remaining = 25 * 60
local endAt = 0
local shownFrac = 1
local pulse = 0                -- flash after a phase change
local lastSecond = -1
local days = {}                -- ["YYYY-MM-DD"] = {s = sessions, m = minutes}
local total = 0
local lastTitle = ""

local function phaseLen(p) return (cfg[p] or 25) * 60 end
local function phaseColor(p) return theme[PHASES[p or phase].color] end

local function dayKey(epoch)
  local d = sys.date(epoch)
  return string.format("%04d-%02d-%02d", d.year, d.month, d.day)
end

local function today()
  local k = dayKey()
  local d = days[k]
  if not d then d = {s = 0, m = 0}; days[k] = d end
  return d
end

local function pruneDays()
  local keep = {}
  local now = sys.epoch()
  for i = 0, 40 do
    local k = dayKey(now - i * 86400)
    if days[k] then keep[k] = days[k] end
  end
  days = keep
end

local function saveState()
  store.set("cfg", cfg)
  store.set("days", days)
  store.set("total", total)
  store.set("timer", {phase = phase, cycle = cycle, remaining = remaining, running = running,
                      endEpoch = running and (sys.epoch() + remaining) or 0})
end

local function setTitle()
  local m = floor(max(0, remaining) / 60)
  local s = floor(max(0, remaining)) % 60
  local t = string.format("%02d:%02d", m, s) .. " · " .. TR(PHASES[phase].key)
  if t ~= lastTitle then
    lastTitle = t
    sys.title(t)
  end
end

local function nextPhase(silent)
  if phase == "focus" then
    local d = today()
    d.s = d.s + 1
    d.m = d.m + cfg.focus
    total = total + 1
    if cycle >= cfg.rounds then phase = "long" else phase = "short" end
  else
    if phase == "long" then cycle = 1 else cycle = cycle + 1 end
    phase = "focus"
  end
  remaining = phaseLen(phase)
  local auto = (phase == "focus") and cfg.autoFocus or (phase ~= "focus" and cfg.autoBreak)
  running = auto and not silent
  if running then endAt = sys.time() + remaining end
  pulse = 1
  saveState()
end

local function finishPhase()
  local finished = phase
  nextPhase(false)
  if cfg.sound then audio.play("alarm") end
  sys.vibrate(0.6, 250)
  if finished == "focus" then
    sys.notify(TR("notify_focus_title"), phase == "long" and TR("notify_focus_long", cfg.long) or TR("notify_focus_short", cfg.short))
  else
    sys.notify(TR("notify_break_title"), TR("notify_break_body", cfg.focus))
  end
end

local function startPause()
  running = not running
  if running then
    endAt = sys.time() + remaining
    if cfg.sound then
      audio.tone(523.25, 0.08, 0.3, "triangle")
      timer.after(0.08, function() audio.tone(783.99, 0.12, 0.3, "triangle") end)
    end
  else
    remaining = max(0, endAt - sys.time())
    if cfg.sound then
      audio.tone(783.99, 0.08, 0.3, "triangle")
      timer.after(0.08, function() audio.tone(523.25, 0.12, 0.3, "triangle") end)
    end
  end
  saveState()
end

local function reset()
  running = false
  remaining = phaseLen(phase)
  if cfg.sound then audio.tone(392, 0.08, 0.25, "sine") end
  saveState()
end

local function skip()
  -- skipping a focus session does not count it in the statistics
  if phase == "focus" then
    if cycle >= cfg.rounds then phase = "long" else phase = "short" end
  else
    if phase == "long" then cycle = 1 else cycle = cycle + 1 end
    phase = "focus"
  end
  running = false
  remaining = phaseLen(phase)
  pulse = 1
  if cfg.sound then audio.play("pop", 0.6) end
  saveState()
end

function app.load()
  local c = store.get("cfg", nil)
  if type(c) == "table" then for k, v in pairs(c) do if cfg[k] ~= nil and type(v) == type(cfg[k]) then cfg[k] = v end end end
  days = store.get("days", {}) or {}
  total = store.get("total", 0) or 0
  pruneDays()
  local t = store.get("timer", nil)
  if type(t) == "table" and PHASES[t.phase] then
    phase = t.phase
    cycle = max(1, min(cfg.rounds, tonumber(t.cycle) or 1))
    remaining = tonumber(t.remaining) or phaseLen(phase)
    if remaining > phaseLen(phase) then remaining = phaseLen(phase) end
    if t.running and (t.endEpoch or 0) > 0 then
      local left = t.endEpoch - sys.epoch()
      if left > 0 then
        remaining = left
        running = true
        endAt = sys.time() + left
      else
        nextPhase(true)
      end
    end
  else
    remaining = phaseLen(phase)
  end
  shownFrac = remaining / phaseLen(phase)
end

function app.update(dt)
  if running then
    local left = endAt - sys.time()
    local prev = remaining
    remaining = max(0, left)
    if cfg.ticks and cfg.sound and remaining <= 3.0 and remaining > 0 and floor(prev) ~= floor(remaining) then
      audio.tone(1046.5, 0.03, 0.15, "sine")
    end
    if left <= 0 then finishPhase() end
  end
  local target = remaining / phaseLen(phase)
  shownFrac = shownFrac + (target - shownFrac) * min(1, dt * 10)
  pulse = max(0, pulse - dt * 1.5)
  local sec = floor(remaining)
  if sec ~= lastSecond then
    lastSecond = sec
    setTitle()
  end
end

-- ------------------------------------------------------------------ drawing helpers
local function digits(s, cx, y, size, font)
  local slot = gfx.textWidth("0", size, font)
  local colon = gfx.textWidth(":", size, font)
  local wTotal = 0
  for i = 1, #s do wTotal = wTotal + (s:sub(i, i) == ":" and colon or slot) end
  local x = cx - wTotal / 2
  for i = 1, #s do
    local ch = s:sub(i, i)
    local cw = ch == ":" and colon or slot
    gfx.text(ch, x, y, size, font, "center", cw)
    x = x + cw
  end
end

local function circleButton(id, icon, cx, cy, r, fill, fg, label)
  local hit = ui.hit(id, cx - r, cy - r, r * 2, r * 2)
  local s = hit.held and 0.94 or 1
  local rr = r * s
  gfx.shadow(cx - rr, cy - rr, rr * 2, rr * 2, rr, 10, 3)
  gfx.color(fill)
  gfx.circle(cx, cy, rr)
  if hit.hovered then
    gfx.color(255, 255, 255, 30)
    gfx.circle(cx, cy, rr)
  end
  gfx.icon(icon, cx, cy, rr * 1.05, fg)
  if label then
    gfx.color(theme.text2)
    gfx.text(label, cx - 60, cy + r + 8, 12, "medium", "center", 120)
  end
  return hit.clicked
end

local function fmtMinutes(m)
  m = floor(m)
  if m >= 60 then return TR("hours_minutes", floor(m / 60), m % 60) end
  return TR("minutes_short", m)
end

-- ------------------------------------------------------------------ timer tab
local function drawTimer(w, h, now)
  local col = phaseColor()
  local P = PHASES[phase]

  -- phase pill
  local label = TR(P.key)
  local pw = gfx.textWidth(label, 14, "semibold") + 46
  local px, py = (w - pw) / 2, 60
  gfx.color(alpha(col, 0.16))
  gfx.rect(px, py, pw, 30, 15)
  gfx.icon(P.icon, px + 19, py + 15, 17, col)
  gfx.color(col)
  gfx.text(label, px + 32, py + 6, 14, "semibold")

  -- ring
  local cx, cy = w / 2, 106 + min(126, (h - 290) / 2)
  local R = min(124, (h - 300) / 2 + 20, w / 2 - 50)
  local th = 14
  -- tick marks
  for i = 0, 59 do
    local a = -pi / 2 + i / 60 * 2 * pi
    local long = i % 5 == 0
    local r1, r2 = R + th / 2 + 6, R + th / 2 + (long and 13 or 9)
    gfx.color(long and theme.text3 or alpha(theme.text3, 0.5))
    gfx.line(cx + cos(a) * r1, cy + sin(a) * r1, cx + cos(a) * r2, cy + sin(a) * r2, long and 2 or 1)
  end
  gfx.color(alpha(col, 0.07 + pulse * 0.15))
  gfx.circle(cx, cy, R - th / 2 - 4)
  gfx.color(alpha(col, 0.16))
  gfx.circleLine(cx, cy, R, th)
  local frac = max(0, min(1, shownFrac))
  if frac > 0.001 then
    local a0 = -pi / 2
    local a1 = a0 + frac * 2 * pi
    gfx.color(col)
    gfx.arc(cx, cy, R, a0, a1, th)
    gfx.circle(cx + cos(a0) * R, cy + sin(a0) * R, th / 2)
    local ex, ey = cx + cos(a1) * R, cy + sin(a1) * R
    local glow = running and (0.35 + 0.25 * sin(now * 4)) or 0.25
    gfx.color(alpha(col, glow))
    gfx.circle(ex, ey, th / 2 + 6)
    gfx.color(col)
    gfx.circle(ex, ey, th / 2)
    gfx.color("#FFFFFF")
    gfx.circle(ex, ey, th / 2 - 4)
  end

  -- time text
  local secs = running and math.ceil(remaining - 0.001) or floor(remaining + 0.5)
  local s = string.format("%02d:%02d", floor(secs / 60), secs % 60)
  gfx.color(theme.text)
  -- the digits follow the ring: a short window (large interface scale) has a smaller ring
  local k = max(0.45, min(1, R / 124))
  digits(s, cx, cy - 40 * k, floor(56 * k), "semibold")
  gfx.color(theme.text2)
  local sub = running and TR("running") or (remaining < phaseLen(phase) - 0.5 and TR("paused") or TR("ready"))
  gfx.text(sub, cx - 100, cy + 30 * k, 13, "medium", "center", 200)
  -- cycle dots
  local n = cfg.rounds
  local dw = 14
  local dx = cx - (n - 1) * dw / 2
  for i = 1, n do
    local done = i < cycle or (i == cycle and phase ~= "focus")
    local cur = i == cycle and phase == "focus"
    if done then
      gfx.color(theme.red)
      gfx.circle(dx + (i - 1) * dw, cy + 30 * k + 30, 4.5)
    elseif cur then
      gfx.color(alpha(theme.red, 0.35 + 0.35 * (running and (0.5 + 0.5 * sin(now * 3)) or 1)))
      gfx.circle(dx + (i - 1) * dw, cy + 30 * k + 30, 4.5)
    else
      gfx.color(theme.text3)
      gfx.circleLine(dx + (i - 1) * dw, cy + 30 * k + 30, 4, 1.5)
    end
  end

  -- controls
  local by = cy + R + 54
  if circleButton("reset", "refresh", cx - 92, by, 24, theme.control, theme.text, TR("reset")) then reset() end
  if circleButton("start", running and "pause" or "play_arrow", cx, by, 34, col, "#FFFFFF",
      running and TR("pause") or TR("start")) then startPause() end
  if circleButton("skip", "skip_next", cx + 92, by, 24, theme.control, theme.text, TR("skip")) then skip() end

  -- today summary
  local d = today()
  local y = h - 34
  gfx.color(theme.separator)
  gfx.rect(24, y - 12, w - 48, 1)
  local txt = TR("today_summary", d.s, fmtMinutes(d.m))
  local tw = gfx.textWidth(txt, 13) + 24
  gfx.icon("local_fire_department", (w - tw) / 2 + 8, y + 9, 17, theme.orange)
  gfx.color(theme.text2)
  gfx.text(txt, (w - tw) / 2 + 22, y + 1, 13)
end

-- ------------------------------------------------------------------ stats tab
local function streak()
  local now = sys.epoch()
  local n = 0
  local start = 0
  local t = days[dayKey(now)]
  if not t or t.s == 0 then start = 1 end
  for i = start, 40 do
    local d = days[dayKey(now - i * 86400)]
    if d and d.s > 0 then n = n + 1 else break end
  end
  return n
end

local function statCard(x, y, w, hh, icon, color, value, label)
  ui.group(x, y, w, hh)
  gfx.color(alpha(color, 0.16))
  gfx.circle(x + 26, y + hh / 2, 16)
  gfx.icon(icon, x + 26, y + hh / 2, 18, color)
  gfx.color(theme.text)
  gfx.text(value, x + 50, y + 10, 20, "bold")
  gfx.color(theme.text2)
  gfx.text(label, x + 50, y + 36, 12)
end

local function drawStats(w, h)
  local d = today()
  local x0, cw = 20, w - 40
  local half = (cw - 12) / 2
  statCard(x0, 60, half, 60, "check_circle", theme.red, tostring(d.s), TR("stat_sessions_today"))
  statCard(x0 + half + 12, 60, half, 60, "schedule", theme.blue, fmtMinutes(d.m), TR("stat_focus_today"))
  statCard(x0, 130, half, 60, "local_fire_department", theme.orange, TR("days_count", streak()), TR("stat_streak"))
  statCard(x0 + half + 12, 130, half, 60, "emoji_events", theme.yellow, tostring(total), TR("stat_total"))

  -- last 7 days chart
  local gy = 204
  local gh = h - gy - 64
  ui.group(x0, gy, cw, gh)
  gfx.color(theme.text)
  gfx.text(TR("last_7_days"), x0 + 14, gy + 12, 14, "semibold")
  local now = sys.epoch()
  local vals, maxV, sum = {}, 60, 0
  for i = 6, 0, -1 do
    local ep = now - i * 86400
    local dd = days[dayKey(ep)]
    local v = dd and dd.m or 0
    vals[#vals + 1] = {v = v, wd = sys.date(ep).wday, today = i == 0}
    maxV = max(maxV, v)
    sum = sum + v
  end
  gfx.color(theme.text2)
  gfx.text(TR("week_total", fmtMinutes(sum)), x0, gy + 14, 12, "sans", "right", cw - 14)
  local chartTop, chartBottom = gy + 44, gy + gh - 30
  local bw = (cw - 28) / 7
  for i, b in ipairs(vals) do
    local bx = x0 + 14 + (i - 1) * bw
    local full = chartBottom - chartTop
    local bh = max(4, full * b.v / maxV)
    gfx.color(alpha(theme.text3, 0.35))
    gfx.rect(bx + bw * 0.22, chartTop, bw * 0.56, full, 6)
    if b.v > 0 then
      local c = b.today and theme.red or alpha(theme.red, 0.55)
      gfx.color(c)
      gfx.rect(bx + bw * 0.22, chartBottom - bh, bw * 0.56, bh, 6)
      gfx.color(theme.text2)
      gfx.text(tostring(b.v), bx, chartBottom - bh - 16, 11, "medium", "center", bw)
    end
    local wk = "wd" .. b.wd
    gfx.color(b.today and theme.text or theme.text2)
    gfx.text(TR(wk), bx, chartBottom + 8, 12, b.today and "semibold" or "sans", "center", bw)
  end

  if ui.button(TR("reset_stats"), w / 2 - 90, h - 50, 180, 32, "default", "delete") then
    ui.alert(TR("reset_stats_title"), TR("reset_stats_msg"), {TR("reset_stats_confirm"), TR("cancel")}, function(b)
      if b == 1 then
        days = {}
        total = 0
        saveState()
        audio.play("trash")
      end
    end)
  end
end

-- ------------------------------------------------------------------ settings tab
local function sliderRow(id, label, value, mn, mx, x, y, w, unit)
  gfx.color(theme.text)
  gfx.text(label, x + 14, y + 10, 14)
  gfx.color(theme.accent)
  gfx.text(unit and TR(unit, floor(value)) or tostring(floor(value)), x, y + 10, 14, "semibold", "right", w - 14)
  local nv = ui.slider(id, value, mn, mx, x + 12, y + 34, w - 24, 1)
  return floor(nv + 0.5)
end

local function toggleRow(id, label, value, x, y, w)
  gfx.color(theme.text)
  gfx.text(label, x + 14, y + 11, 14)
  return ui.toggle(id, value, x + w - 54, y + 9)
end

local function drawSettings(w, h)
  local x0, cw = 20, w - 40
  local y = 58
  ui.group(x0, y, cw, 4 * 64)
  local old = {cfg.focus, cfg.short, cfg.long, cfg.rounds}
  cfg.focus = sliderRow("s_focus", TR("set_focus"), cfg.focus, 5, 90, x0, y, cw, "minutes_short")
  ui.separator(x0 + 14, y + 64, x0 + cw - 14)
  cfg.short = sliderRow("s_short", TR("set_short"), cfg.short, 1, 30, x0, y + 64, cw, "minutes_short")
  ui.separator(x0 + 14, y + 128, x0 + cw - 14)
  cfg.long = sliderRow("s_long", TR("set_long"), cfg.long, 5, 60, x0, y + 128, cw, "minutes_short")
  ui.separator(x0 + 14, y + 192, x0 + cw - 14)
  cfg.rounds = sliderRow("s_rounds", TR("set_rounds"), cfg.rounds, 2, 8, x0, y + 192, cw, nil)
  local changed = old[1] ~= cfg.focus or old[2] ~= cfg.short or old[3] ~= cfg.long or old[4] ~= cfg.rounds
  if changed then
    if not running then remaining = phaseLen(phase) end
    if cycle > cfg.rounds then cycle = cfg.rounds end
    saveState()
  end

  y = y + 4 * 64 + 14
  ui.group(x0, y, cw, 4 * 40)
  local o = {cfg.autoBreak, cfg.autoFocus, cfg.sound, cfg.ticks}
  cfg.autoBreak = toggleRow("t_ab", TR("set_auto_break"), cfg.autoBreak, x0, y, cw)
  ui.separator(x0 + 14, y + 40, x0 + cw - 14)
  cfg.autoFocus = toggleRow("t_af", TR("set_auto_focus"), cfg.autoFocus, x0, y + 40, cw)
  ui.separator(x0 + 14, y + 80, x0 + cw - 14)
  cfg.sound = toggleRow("t_snd", TR("set_sound"), cfg.sound, x0, y + 80, cw)
  ui.separator(x0 + 14, y + 120, x0 + cw - 14)
  cfg.ticks = toggleRow("t_tick", TR("set_ticks"), cfg.ticks, x0, y + 120, cw)
  if o[1] ~= cfg.autoBreak or o[2] ~= cfg.autoFocus or o[3] ~= cfg.sound or o[4] ~= cfg.ticks then
    audio.play("click", 0.5)
    saveState()
  end

  if ui.button(TR("restore_defaults"), w / 2 - 90, min(h - 46, y + 176), 180, 30, "link") then
    cfg.focus, cfg.short, cfg.long, cfg.rounds = 25, 5, 15, 4
    if not running then remaining = phaseLen(phase) end
    if cycle > cfg.rounds then cycle = cfg.rounds end
    saveState()
  end
end

-- ------------------------------------------------------------------ main
function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  -- soft phase tint at the top
  gfx.gradient(0, 0, w, 160, alpha(phaseColor(), theme.dark and 0.12 or 0.08), alpha(phaseColor(), 0))
  tab = ui.segmented("tabs", {TR("tab_timer"), TR("tab_stats"), TR("tab_settings")}, tab, w / 2 - 150, 14, 300, 30)
  if tab == 1 then drawTimer(w, h, now)
  elseif tab == 2 then drawStats(w, h)
  else drawSettings(w, h) end
end

function app.event(e)
  if e.type == "keydown" then
    local k = e.key
    if k == "space" or k == "enter" then startPause()
    elseif k == "r" then reset()
    elseif k == "n" or k == "s" then skip()
    elseif k == "escape" then if running then startPause() end
    elseif k == "1" or k == "2" or k == "3" then tab = tonumber(k)
    elseif k == "right" or k == "tab" then tab = tab % 3 + 1
    elseif k == "left" then tab = (tab + 1) % 3 + 1
    end
  end
end

function app.menu()
  return {
    {title = TR("menu_timer"), items = {
      {label = running and TR("pause") or TR("start"), id = 1, shortcut = "Space"},
      {label = TR("reset"), id = 2, shortcut = "R"},
      {label = TR("skip"), id = 3, shortcut = "N"},
      "-",
      {label = TR("phase_focus"), id = 11, checked = phase == "focus"},
      {label = TR("phase_short"), id = 12, checked = phase == "short"},
      {label = TR("phase_long"), id = 13, checked = phase == "long"},
    }},
    {title = TR("menu_view"), items = {
      {label = TR("tab_timer"), id = 21, shortcut = "1", checked = tab == 1},
      {label = TR("tab_stats"), id = 22, shortcut = "2", checked = tab == 2},
      {label = TR("tab_settings"), id = 23, shortcut = "3", checked = tab == 3},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then startPause()
  elseif id == 2 then reset()
  elseif id == 3 then skip()
  elseif id >= 11 and id <= 13 then
    phase = ({"focus", "short", "long"})[id - 10]
    running = false
    remaining = phaseLen(phase)
    saveState()
  elseif id >= 21 and id <= 23 then tab = id - 20
  end
end

function app.close()
  if running then remaining = max(0, endAt - sys.time()) end
  saveState()
  store.save()
  return true
end

return app
