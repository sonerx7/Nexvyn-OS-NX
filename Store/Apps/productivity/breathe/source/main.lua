-- Breathe for Nexvyn OS: guided breathing with box, 4-7-8 and coherent patterns, soft cues and session history.
local app = {}

local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi
local TAU = pi * 2

-- ------------------------------------------------------------------ helpers
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
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
local function alpha(c, a)
  local t = rgba(c)
  return {t[1], t[2], t[3], clamp(floor(t[4] * a + 0.5), 0, 255)}
end
local function mix(c1, c2, k)
  local a, b = rgba(c1), rgba(c2)
  return {floor(a[1] + (b[1] - a[1]) * k + 0.5), floor(a[2] + (b[2] - a[2]) * k + 0.5),
          floor(a[3] + (b[3] - a[3]) * k + 0.5), floor(a[4] + (b[4] - a[4]) * k + 0.5)}
end
local function approach(cur, target, speed, dt) return cur + (target - cur) * (1 - math.exp(-speed * dt)) end
local function easeInOut(t) return 0.5 - 0.5 * cos(pi * clamp(t, 0, 1)) end
local function mmss(s)
  s = max(0, floor(s + 0.5))
  return string.format("%d:%02d", floor(s / 60), s % 60)
end

local queue = {}
local function later(dt, fn) queue[#queue + 1] = {t = sys.time() + dt, fn = fn} end
local function runQueue()
  local now = sys.time()
  local i = 1
  while i <= #queue do
    if now >= queue[i].t then
      local q = table.remove(queue, i)
      q.fn()
    else
      i = i + 1
    end
  end
end

-- ------------------------------------------------------------------ patterns
-- phase kinds: "in", "hold" (full lungs), "out", "rest" (empty lungs)
local PATTERNS = {
  {key = "pat_box", desc = "desc_box", color = "blue", phases = {{"in", 4}, {"hold", 4}, {"out", 4}, {"rest", 4}}},
  {key = "pat_478", desc = "desc_478", color = "purple", phases = {{"in", 4}, {"hold", 7}, {"out", 8}}},
  {key = "pat_coherent", desc = "desc_coherent", color = "green", phases = {{"in", 5}, {"out", 5}}},
}
local LENGTHS = {1, 3, 5, 10}
local PHASEKEY = {["in"] = "phase_in", hold = "phase_hold", out = "phase_out", rest = "phase_rest"}

local function cycleLen(p)
  local t = 0
  for _, ph in ipairs(PATTERNS[p].phases) do t = t + ph[2] end
  return t
end

-- ------------------------------------------------------------------ state
local tab = 1
local pattern = 1
local lengthIdx = 2
local soundOn, vibeOn = true, true
local state = "idle"          -- idle, ready, running, paused, done
local readyLeft = 0
local elapsed = 0
local sessionLen = 180
local phaseIdx, phaseT, phaseLen = 1, 0, 4
local lastPhaseKey = nil
local radius = 0              -- animated circle radius 0..1
local glow = 0
local idleT = 0
local doneT = 0
local history = {}
local lastCycles = 0
local particles = {}
for i = 1, 28 do particles[i] = {a = (i / 28) * TAU, r = 0.9 + math.random() * 0.5, s = 1.5 + math.random() * 2, sp = 0.05 + math.random() * 0.12} end

local function patColor(p) return theme[PATTERNS[p or pattern].color] end

local function saveSettings()
  store.set("pattern", pattern)
  store.set("length", lengthIdx)
  store.set("sound", soundOn)
  store.set("vibe", vibeOn)
end

local function cue(kind)
  if soundOn then
    if kind == "in" then
      audio.tone(392.0, 0.5, 0.12, "sine")
      later(0.18, function() audio.tone(523.25, 0.7, 0.10, "sine") end)
    elseif kind == "out" then
      audio.tone(392.0, 0.5, 0.12, "sine")
      later(0.18, function() audio.tone(293.66, 0.8, 0.10, "sine") end)
    else
      audio.tone(440.0, 0.35, 0.07, "sine")
    end
  end
  if vibeOn then
    if kind == "in" then
      sys.vibrate(0.30, 50)
      later(0.12, function() sys.vibrate(0.18, 40) end)
    elseif kind == "out" then
      sys.vibrate(0.25, 120)
    else
      sys.vibrate(0.15, 30)
    end
  end
end

local function dayKey(epoch)
  local d = sys.date(epoch)
  return string.format("%04d-%02d-%02d", d.year, d.month, d.day)
end

local function record(done)
  if elapsed < 15 then return end
  table.insert(history, 1, {at = sys.epoch(), p = pattern, secs = floor(elapsed + 0.5), done = done, cycles = lastCycles})
  while #history > 300 do table.remove(history) end
  store.set("history", history)
end

local function computePhase()
  local cl = cycleLen(pattern)
  local t = elapsed % cl
  lastCycles = floor(elapsed / cl)
  for i, ph in ipairs(PATTERNS[pattern].phases) do
    if t < ph[2] or i == #PATTERNS[pattern].phases then
      phaseIdx, phaseT, phaseLen = i, t, ph[2]
      return
    end
    t = t - ph[2]
  end
end

local function totalLen()
  local cl = cycleLen(pattern)
  return math.ceil(sessionLen / cl) * cl
end

local function start()
  sessionLen = LENGTHS[lengthIdx] * 60
  elapsed = 0
  state = "ready"
  readyLeft = 3
  lastPhaseKey = nil
  if soundOn then audio.tone(659.25, 0.12, 0.10, "sine") end
end

local function stop(done)
  if state == "running" or state == "paused" then record(done) end
  state = done and "done" or "idle"
  doneT = 0
  if done then
    if soundOn then
      local notes = {523.25, 659.25, 783.99, 1046.5}
      for i, f in ipairs(notes) do later((i - 1) * 0.22, function() audio.tone(f, 0.9, 0.10, "sine") end) end
    end
    if vibeOn then sys.vibrate(0.4, 200) end
  end
end

local function toggleRun()
  if state == "idle" or state == "done" then start()
  elseif state == "running" then state = "paused"
  elseif state == "paused" then state = "running"; lastPhaseKey = nil
  elseif state == "ready" then state = "idle" end
  audio.play("click", 0.4)
end

-- ------------------------------------------------------------------ app
function app.load()
  pattern = clamp(math.tointeger(store.get("pattern", 1)) or 1, 1, #PATTERNS)
  lengthIdx = clamp(math.tointeger(store.get("length", 2)) or 2, 1, #LENGTHS)
  soundOn = store.get("sound", true) ~= false
  vibeOn = store.get("vibe", true) ~= false
  local h = store.get("history", {})
  history = type(h) == "table" and h or {}
end

function app.update(dt)
  runQueue()
  idleT = idleT + dt
  local target = 0.35 + 0.08 * sin(idleT * 0.9)
  if state == "ready" then
    local before = math.ceil(readyLeft)
    readyLeft = readyLeft - dt
    if math.ceil(readyLeft) ~= before and readyLeft > 0 and soundOn then audio.tone(659.25, 0.08, 0.08, "sine") end
    target = 0
    if readyLeft <= 0 then state = "running"; elapsed = 0 end
  end
  if state == "running" then
    elapsed = elapsed + dt
    if elapsed >= totalLen() then
      elapsed = totalLen()
      stop(true)
    end
  end
  if state == "running" or state == "paused" then
    computePhase()
    local ph = PATTERNS[pattern].phases[phaseIdx]
    local key = lastCycles .. ":" .. phaseIdx
    if state == "running" and key ~= lastPhaseKey then
      lastPhaseKey = key
      cue(ph[1])
    end
    local p = phaseT / phaseLen
    if ph[1] == "in" then target = easeInOut(p)
    elseif ph[1] == "hold" then target = 1 + 0.015 * sin(idleT * 5)
    elseif ph[1] == "out" then target = 1 - easeInOut(p)
    else target = 0 end
    radius = state == "running" and target or approach(radius, target, 6, dt)
    glow = approach(glow, (ph[1] == "hold") and 1 or 0.4, 3, dt)
  else
    radius = approach(radius, target, 3, dt)
    glow = approach(glow, 0.3, 3, dt)
  end
  if state == "done" then doneT = min(1, doneT + dt * 1.5) end
  for _, pt in ipairs(particles) do pt.a = pt.a + pt.sp * dt * (state == "running" and 1.6 or 0.6) end
end

local function drawCircle(cx, cy, rMin, rMax)
  local col = patColor()
  local r = rMin + (rMax - rMin) * radius
  -- guide rings
  gfx.color(alpha(theme.text, 0.10))
  gfx.circleLine(cx, cy, rMax + 6, 1)
  gfx.color(alpha(theme.text, 0.06))
  gfx.circleLine(cx, cy, rMin, 1)
  -- particles drifting with the breath
  for _, pt in ipairs(particles) do
    local pr = r * (1.08 + 0.18 * pt.r) + 6
    gfx.circle(cx + cos(pt.a) * pr, cy + sin(pt.a) * pr, pt.s, alpha(col, 0.35))
  end
  -- glow
  for k = 4, 1, -1 do
    gfx.circle(cx, cy, r + k * 7 * (0.6 + glow * 0.6), alpha(col, 0.05 + 0.02 * glow))
  end
  gfx.circle(cx, cy, r, alpha(col, theme.dark and 0.85 or 0.9))
  gfx.circle(cx - r * 0.18, cy - r * 0.22, r * 0.62, alpha("#FFFFFF", 0.10))
  gfx.color(alpha("#FFFFFF", 0.35))
  gfx.circleLine(cx, cy, r, 1.5)
end

local function drawBreathe(w, h)
  local col = patColor()
  local active = state == "running" or state == "paused" or state == "ready"
  -- pattern selector / title
  if not active then
    local items = {}
    for i, p in ipairs(PATTERNS) do items[i] = TR(p.key) end
    local np = ui.segmented("pattern", items, pattern, 40, 58, w - 80, 30)
    if np ~= pattern then pattern = np; saveSettings(); audio.play("click", 0.4) end
    gfx.color(theme.text2)
    gfx.text(TR(PATTERNS[pattern].desc), 0, 98, 12, "sans", "center", w)
  else
    gfx.color(theme.text)
    gfx.text(TR(PATTERNS[pattern].key), 0, 60, 17, "bold", "center", w)
    gfx.color(theme.text2)
    gfx.text(TR("cycle_n", lastCycles + 1), 0, 84, 12, "medium", "center", w)
  end

  local cx, cy = w / 2, 268
  local rMin, rMax = 58, 112
  drawCircle(cx, cy, rMin, rMax)

  -- phase arc
  if state == "running" or state == "paused" then
    local p = clamp(phaseT / phaseLen, 0, 1)
    gfx.color(alpha(col, 0.25))
    gfx.arc(cx, cy, rMax + 18, 0, TAU, 3)
    gfx.color(col)
    gfx.arc(cx, cy, rMax + 18, -pi / 2, -pi / 2 + TAU * p, 4)
  end

  -- center text
  gfx.color("#FFFFFF")
  if state == "ready" then
    gfx.text(TR("get_ready"), 0, cy - 30, 14, "semibold", "center", w)
    gfx.text(tostring(max(1, math.ceil(readyLeft))), 0, cy - 12, 34, "bold", "center", w)
  elseif state == "running" or state == "paused" then
    local ph = PATTERNS[pattern].phases[phaseIdx]
    gfx.text(TR(PHASEKEY[ph[1]]), 0, cy - 28, 17, "bold", "center", w)
    gfx.text(tostring(max(1, math.ceil(phaseLen - phaseT))), 0, cy - 6, 32, "bold", "center", w)
    if state == "paused" then
      gfx.text(TR("paused"), 0, cy + 30, 11, "semibold", "center", w)
    end
  elseif state == "done" then
    gfx.alpha(doneT)
    gfx.icon("check_circle", cx, cy - 14, 40, "#FFFFFF")
    gfx.text(TR("well_done"), 0, cy + 12, 14, "semibold", "center", w)
    gfx.unalpha()
  else
    gfx.icon("air", cx, cy - 10, 34, "#FFFFFF")
    gfx.text(TR("ready_hint"), 0, cy + 14, 12, "semibold", "center", w)
  end

  -- session progress
  local py = 420
  if active or state == "done" then
    local tot = state == "done" and 1 or totalLen()
    local prog = state == "done" and 1 or (state == "ready" and 0 or elapsed / tot)
    gfx.rect(60, py, w - 120, 6, 3, alpha(theme.text, 0.08))
    gfx.rect(60, py, (w - 120) * clamp(prog, 0, 1), 6, 3, col)
    gfx.color(theme.text2)
    if state == "done" then
      gfx.text(TR("session_done", mmss(history[1] and history[1].secs or 0)), 0, py + 14, 12, "medium", "center", w)
    else
      gfx.text(mmss(elapsed) .. "  /  " .. mmss(tot), 0, py + 14, 12, "medium", "center", w)
    end
  end
  if not active then
    local items = {}
    for i, m in ipairs(LENGTHS) do items[i] = TR("minutes_short", m) end
    gfx.color(theme.text2)
    gfx.text(TR("session_length"), 0, py + 36, 11, "semibold", "center", w)
    local nl = ui.segmented("length", items, lengthIdx, w / 2 - 150, py + 54, 300, 28)
    if nl ~= lengthIdx then lengthIdx = nl; saveSettings(); audio.play("click", 0.4) end
  end

  -- controls
  local by = h - 52
  local label = (state == "running") and TR("pause") or ((state == "paused") and TR("resume") or TR("start"))
  local icon = (state == "running") and "pause" or "play_arrow"
  if state == "ready" then label = TR("cancel"); icon = "close" end
  local bw = 150
  local bx = w / 2 - bw / 2
  if ui.button(label, bx, by, bw, 38, "primary", icon) then toggleRun() end
  if (state == "running" or state == "paused") and ui.button(TR("stop"), bx + bw + 10, by, 90, 38, "default", "stop") then
    stop(false)
    audio.play("click", 0.4)
  end
  if ui.iconButton(soundOn and "volume_up" or "volume_off", 20, by + 3, 34, 32, soundOn and theme.accent or theme.text3, soundOn, "snd") then
    soundOn = not soundOn; saveSettings()
  end
  if ui.iconButton(vibeOn and "vibration" or "mobile_off", 58, by + 3, 34, 32, vibeOn and theme.accent or theme.text3, vibeOn, "vib") then
    vibeOn = not vibeOn; saveSettings()
    if vibeOn then sys.vibrate(0.3, 60) end
  end
end

local WD = {"wd_0", "wd_1", "wd_2", "wd_3", "wd_4", "wd_5", "wd_6"}

local function statCard(x, y, w, h, icon, color, value, label)
  ui.group(x, y, w, h)
  gfx.icon(icon, x + 22, y + h / 2, 22, color)
  gfx.color(theme.text)
  gfx.text(value, x + 42, y + 14, 20, "bold")
  gfx.color(theme.text2)
  gfx.text(label, x + 42, y + 42, 11, "medium")
end

local function drawHistory(w, h)
  -- stats
  local totalSecs, sessions = 0, #history
  local byDay = {}
  for _, s in ipairs(history) do
    totalSecs = totalSecs + (s.secs or 0)
    local k = dayKey(s.at or 0)
    byDay[k] = (byDay[k] or 0) + (s.secs or 0)
  end
  local streak = 0
  local now = sys.epoch()
  local startOff = byDay[dayKey(now)] and 0 or 1
  for i = startOff, 400 do
    if byDay[dayKey(now - i * 86400)] then streak = streak + 1 else break end
  end
  local cw = (w - 40 - 16) / 3
  statCard(20, 58, cw, 66, "self_improvement", theme.accent, tostring(sessions), TR("stat_sessions"))
  statCard(20 + cw + 8, 58, cw, 66, "schedule", theme.green, tostring(floor(totalSecs / 60)), TR("stat_minutes"))
  statCard(20 + (cw + 8) * 2, 58, cw, 66, "local_fire_department", theme.orange, tostring(streak), TR("stat_streak"))

  -- week chart
  local gy, gh = 136, 128
  ui.group(20, gy, w - 40, gh)
  gfx.color(theme.text)
  gfx.text(TR("this_week"), 34, gy + 10, 13, "semibold")
  local vals, maxV = {}, 60
  for i = 6, 0, -1 do
    local e = now - i * 86400
    local v = byDay[dayKey(e)] or 0
    vals[#vals + 1] = {v = v, wd = sys.date(e).wday, today = i == 0}
    maxV = max(maxV, v)
  end
  local bw = (w - 40 - 40) / 7
  for i, b in ipairs(vals) do
    local bx = 40 + (i - 1) * bw
    local bh = (gh - 64) * (b.v / maxV)
    local col = b.today and theme.accent or alpha(theme.accent, 0.45)
    gfx.rect(bx + bw * 0.25, gy + gh - 28 - (gh - 64), bw * 0.5, gh - 64, 4, alpha(theme.text, 0.05))
    if bh > 0 then gfx.rect(bx + bw * 0.25, gy + gh - 28 - bh, bw * 0.5, max(4, bh), 4, col) end
    gfx.color(b.today and theme.text or theme.text2)
    gfx.text(TR(WD[b.wd + 1]), bx, gy + gh - 22, 11, b.today and "semibold" or "sans", "center", bw)
    if b.v > 0 then
      gfx.color(theme.text3)
      gfx.text(tostring(math.ceil(b.v / 60)), bx, gy + gh - 42 - bh, 10, "medium", "center", bw)
    end
  end

  -- recent sessions
  local ly = gy + gh + 14
  gfx.color(theme.text)
  gfx.text(TR("recent"), 22, ly, 14, "bold")
  if #history > 0 and ui.iconButton("delete_outline", w - 52, ly - 6, 32, 28, theme.text2, false, "clr") then
    ui.alert(TR("clear_title"), TR("clear_msg"), {TR("clear"), TR("cancel")}, function(b)
      if b == 1 then history = {}; store.set("history", history); audio.play("trash", 0.5) end
    end)
  end
  local listY = ly + 28
  local listH = h - listY - 12
  local rowH = 50
  if #history == 0 then
    gfx.icon("spa", w / 2, listY + 40, 36, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("no_history"), 0, listY + 66, 13, "sans", "center", w)
    return
  end
  local n = min(#history, 100)
  ui.beginScroll("hist", 20, listY, w - 40, listH, n * rowH)
  local today, yesterday = dayKey(now), dayKey(now - 86400)
  for i = 1, n do
    local s = history[i]
    local y = (i - 1) * rowH
    local p = PATTERNS[clamp(s.p or 1, 1, #PATTERNS)]
    local pc = theme[p.color]
    gfx.circle(20, y + rowH / 2, 15, alpha(pc, 0.2))
    gfx.icon("air", 20, y + rowH / 2, 18, pc)
    gfx.color(theme.text)
    gfx.text(TR(p.key), 46, y + 8, 14, "semibold")
    local d = sys.date(s.at or 0)
    local k = dayKey(s.at or 0)
    local dayText = k == today and TR("today") or (k == yesterday and TR("yesterday") or string.format("%02d.%02d.%04d", d.day, d.month, d.year))
    gfx.color(theme.text2)
    gfx.text(dayText .. "  ·  " .. string.format("%02d:%02d", d.hour, d.min), 46, y + 27, 12)
    gfx.color(theme.text)
    gfx.text(mmss(s.secs or 0), 0, y + 10, 14, "semibold", "right", w - 40 - 44)
    if s.done then gfx.icon("check_circle", w - 40 - 22, y + rowH / 2, 20, theme.green)
    else gfx.icon("timelapse", w - 40 - 22, y + rowH / 2, 20, theme.text3) end
    if i < n then ui.separator(46, y + rowH - 1, w - 40 - 8) end
  end
  ui.endScroll()
end

function app.draw(w, h)
  local col = patColor()
  gfx.clear(theme.bg)
  gfx.gradient(0, 0, w, h, mix(theme.bg, col, theme.dark and 0.10 or 0.07), theme.bg)
  local nt = ui.segmented("tabs", {TR("tab_breathe"), TR("tab_history")}, tab, w / 2 - 130, 14, 260, 30)
  if nt ~= tab then tab = nt; audio.play("click", 0.3) end
  if tab == 1 then drawBreathe(w, h) else drawHistory(w, h) end
end

function app.event(e)
  if e.type ~= "keydown" then return end
  if e.key == "space" or e.key == "enter" then
    if tab == 1 then toggleRun() end
  elseif e.key == "escape" then
    if state == "running" or state == "paused" then stop(false)
    elseif state == "ready" or state == "done" then state = "idle" end
  elseif e.key == "tab" then
    tab = tab == 1 and 2 or 1
  elseif tab == 1 and (state == "idle" or state == "done") then
    if e.key == "left" then pattern = (pattern - 2) % #PATTERNS + 1; saveSettings()
    elseif e.key == "right" then pattern = pattern % #PATTERNS + 1; saveSettings()
    elseif e.key == "up" then lengthIdx = min(#LENGTHS, lengthIdx + 1); saveSettings()
    elseif e.key == "down" then lengthIdx = max(1, lengthIdx - 1); saveSettings() end
  end
end

function app.menu()
  return {
    {title = TR("menu_session"), items = {
      {label = (state == "running") and TR("pause") or TR("start"), id = 1, shortcut = "Space"},
      {label = TR("stop"), id = 2, enabled = state == "running" or state == "paused"},
      "-",
      {label = TR("sound"), id = 3, checked = soundOn},
      {label = TR("vibration"), id = 4, checked = vibeOn},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then toggleRun()
  elseif id == 2 then stop(false)
  elseif id == 3 then soundOn = not soundOn; saveSettings()
  elseif id == 4 then vibeOn = not vibeOn; saveSettings() end
end

function app.close()
  if state == "running" or state == "paused" then record(false) end
  saveSettings()
  return true
end

return app
