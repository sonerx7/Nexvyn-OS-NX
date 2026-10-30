-- Interval Timer: HIIT/Tabata workouts with warm-up, work, rest, rounds, sets, set rest and cool-down.
-- Big phase-colored ring, beeps in the last 3 seconds, vibration, custom presets and a weekly chart. Nexvyn OS Lua SDK.
local app = {}

local floor, min, max, ceil, pi, sin = math.floor, math.min, math.max, math.ceil, math.pi, math.sin
local M = 18

-- ------------------------------------------------------------------ configuration
local FIELDS = {
  {key = "warm", mn = 0, mx = 900, step = 5, time = true},
  {key = "work", mn = 5, mx = 900, step = 5, time = true},
  {key = "rest", mn = 0, mx = 600, step = 5, time = true},
  {key = "rounds", mn = 1, mx = 50, step = 1},
  {key = "sets", mn = 1, mx = 10, step = 1},
  {key = "setRest", mn = 0, mx = 600, step = 5, time = true},
  {key = "cool", mn = 0, mx = 900, step = 5, time = true},
}

local BUILTIN = {
  {id = "tabata", cfg = {warm = 10, work = 20, rest = 10, rounds = 8, sets = 1, setRest = 0, cool = 0}},
  {id = "hiit30", cfg = {warm = 60, work = 30, rest = 30, rounds = 10, sets = 1, setRest = 0, cool = 60}},
  {id = "hiit40", cfg = {warm = 60, work = 40, rest = 20, rounds = 8, sets = 3, setRest = 60, cool = 60}},
  {id = "sprint", cfg = {warm = 120, work = 15, rest = 45, rounds = 8, sets = 1, setRest = 0, cool = 120}},
  {id = "beginner", cfg = {warm = 60, work = 20, rest = 40, rounds = 6, sets = 2, setRest = 60, cool = 60}},
}

local COLORS = {warmup = "#FF9F0A", work = "#FF453A", rest = "#30D158", setrest = "#0A84FF", cooldown = "#BF5AF2"}

local cfg = {}
local custom = {}             -- {name, cfg}
local selected = 1            -- index in the combined preset list, 0 = modified
local soundOn, vibrateOn = true, true
local history = {}            -- "YYYY-MM-DD" -> {n = workouts, s = seconds}

-- ------------------------------------------------------------------ run state
local mode = "setup"          -- setup | run | done
local phases, total = {}, 0
local idx, elapsed, paused = 1, 0, false
local lastBeep = nil
local doneAt, doneSecs = 0, 0
local clock = 0
local ringFrom, ringTo, ringMix = "#FF9F0A", "#FF9F0A", 1
local confetti = {}
local toast, toastT = "", 0

-- ------------------------------------------------------------------ helpers
local cache = {}
local function rgb(c)
  local t = cache[c]
  if not t then
    t = {tonumber(c:sub(2, 3), 16) or 0, tonumber(c:sub(4, 5), 16) or 0, tonumber(c:sub(6, 7), 16) or 0}
    cache[c] = t
  end
  return t
end
local function mix(a, b, f)
  local x, y = rgb(a), rgb(b)
  return {floor(x[1] + (y[1] - x[1]) * f), floor(x[2] + (y[2] - x[2]) * f), floor(x[3] + (y[3] - x[3]) * f), 255}
end

local function mmss(s)
  s = max(0, ceil(s - 0.0001))
  local h = floor(s / 3600)
  if h > 0 then return string.format("%d:%02d:%02d", h, floor(s / 60) % 60, s % 60) end
  return string.format("%d:%02d", floor(s / 60), s % 60)
end

local function clampCfg(c)
  local out = {}
  for _, f in ipairs(FIELDS) do
    local v = floor(tonumber(c and c[f.key]) or f.mn)
    out[f.key] = max(f.mn, min(f.mx, v))
  end
  return out
end

local function presetCount() return #BUILTIN + #custom end
local function presetCfg(i)
  if i >= 1 and i <= #BUILTIN then return BUILTIN[i].cfg end
  local c = custom[i - #BUILTIN]
  return c and c.cfg
end

local function presetName(i)
  if i == 1 then return TR("preset_tabata") elseif i == 2 then return TR("preset_hiit30")
  elseif i == 3 then return TR("preset_hiit40") elseif i == 4 then return TR("preset_sprint")
  elseif i == 5 then return TR("preset_beginner") end
  local c = custom[i - #BUILTIN]
  return c and tostring(c.name) or ""
end

local function phaseName(k)
  if k == "warmup" then return TR("ph_warmup") elseif k == "work" then return TR("ph_work")
  elseif k == "rest" then return TR("ph_rest") elseif k == "setrest" then return TR("ph_setrest") end
  return TR("ph_cooldown")
end

-- days since 1970-01-01 for a civil date and back (Howard Hinnant's algorithms)
local function daysFromCivil(y, m, d)
  y = m <= 2 and y - 1 or y
  local era = (y >= 0 and y or y - 399) // 400
  local yoe = y - era * 400
  local doy = (153 * (m + (m > 2 and -3 or 9)) + 2) // 5 + d - 1
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
  return m <= 2 and y + 1 or y, m, d
end
local function todayNum()
  local t = sys.date()
  return daysFromCivil(t.year, t.month, t.day)
end
local function dayKey(n)
  local y, m, d = civilFromDays(n)
  return string.format("%04d-%02d-%02d", y, m, d)
end

-- ------------------------------------------------------------------ workout plan
local function buildPhases(c)
  local list = {}
  if c.warm > 0 then list[#list + 1] = {kind = "warmup", dur = c.warm} end
  for s = 1, c.sets do
    for r = 1, c.rounds do
      list[#list + 1] = {kind = "work", dur = c.work, round = r, set = s}
      local lastOfSet = r == c.rounds
      local skipRest = lastOfSet and ((s < c.sets and c.setRest > 0) or s == c.sets)
      if c.rest > 0 and not skipRest then list[#list + 1] = {kind = "rest", dur = c.rest, round = r, set = s} end
    end
    if s < c.sets and c.setRest > 0 then list[#list + 1] = {kind = "setrest", dur = c.setRest, set = s} end
  end
  if c.cool > 0 then list[#list + 1] = {kind = "cooldown", dur = c.cool} end
  local sum = 0
  for _, p in ipairs(list) do p.start = sum; sum = sum + p.dur end
  return list, sum
end

local planCache, planTotal = {}, 0
local function refreshPlan()
  planCache, planTotal = buildPhases(cfg)
end

local function saveCfg()
  store.set("cfg", cfg)
  store.set("selected", selected)
  refreshPlan()
end

local function showToast(m) toast, toastT = m, 2.4 end

-- ------------------------------------------------------------------ sounds
local function beep(kind)
  if soundOn then
    if kind == "count" then audio.tone(880, 0.12, 0.45, "sine")
    elseif kind == "work" then audio.tone(1320, 0.4, 0.55, "sine"); audio.tone(660, 0.4, 0.25, "triangle")
    elseif kind == "rest" then audio.tone(660, 0.45, 0.5, "sine")
    elseif kind == "done" then
      audio.tone(784, 0.18, 0.5, "sine")
      timer.after(0.18, function() audio.tone(988, 0.18, 0.5, "sine") end)
      timer.after(0.36, function() audio.tone(1319, 0.5, 0.55, "sine") end)
    end
  end
  if vibrateOn then
    if kind == "count" then sys.vibrate(0.25, 40) elseif kind == "done" then sys.vibrate(0.8, 400) else sys.vibrate(0.6, 180) end
  end
end

local function enterPhase(i)
  idx = i
  lastBeep = nil
  local p = phases[i]
  if not p then return end
  ringFrom = ringTo
  ringTo = COLORS[p.kind] or "#FF453A"
  ringMix = 0
  beep(p.kind == "work" and "work" or "rest")
end

local function recordWorkout(secs)
  local k = dayKey(todayNum())
  local e = history[k]
  if type(e) ~= "table" then e = {n = 0, s = 0} end
  e.n = (tonumber(e.n) or 0) + 1
  e.s = (tonumber(e.s) or 0) + floor(secs)
  history[k] = e
  store.set("history", history)
end

local function finish()
  mode = "done"
  doneAt = clock
  doneSecs = total
  recordWorkout(total)
  beep("done")
  confetti = {}
  for i = 1, 48 do
    confetti[i] = {x = math.random(), v = 0.3 + math.random() * 0.6, s = 4 + math.random() * 6,
      c = ({"#FF453A", "#FF9F0A", "#30D158", "#0A84FF", "#BF5AF2", "#FFD60A"})[i % 6 + 1], ph = math.random() * 6}
  end
end

local function start()
  phases, total = buildPhases(cfg)
  if #phases == 0 then return end
  mode, paused, elapsed = "run", false, 0
  ringTo = COLORS[phases[1].kind]
  enterPhase(1)
end

local function skip()
  if mode ~= "run" then return end
  elapsed = 0
  if idx >= #phases then finish() else enterPhase(idx + 1) end
end

local function stopNow() mode = "setup"; paused = false end

local function askStop()
  if mode ~= "run" then return end
  paused = true
  ui.alert(TR("stop_title"), TR("stop_msg"), {TR("stop"), TR("common.cancel")}, function(b)
    if b == 1 then stopNow() else paused = false end
  end)
end

local function togglePause()
  if mode == "run" then paused = not paused; audio.play("click", 0.4)
  elseif mode == "setup" then start()
  else mode = "setup" end
end

local function selectPreset(i)
  local c = presetCfg(i)
  if not c then return end
  selected = i
  cfg = clampCfg(c)
  saveCfg()
end

local function savePreset()
  ui.prompt(TR("save_preset"), TR("preset_name_msg"), "", function(s)
    if not s then return end
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    if s == "" then showToast(TR("name_empty")); return end
    if utf8.len(s) and utf8.len(s) > 24 then showToast(TR("name_long")); return end
    custom[#custom + 1] = {name = s, cfg = clampCfg(cfg)}
    store.set("custom", custom)
    selected = #BUILTIN + #custom
    store.set("selected", selected)
    showToast(TR("preset_saved", s))
  end)
end

local function deletePreset(ci)
  local c = custom[ci]
  if not c then return end
  ui.alert(TR("delete_title"), TR("delete_msg", tostring(c.name)), {TR("delete"), TR("common.cancel")}, function(b)
    if b ~= 1 or not custom[ci] then return end
    table.remove(custom, ci)
    store.set("custom", custom)
    if selected == #BUILTIN + ci then selected = 0 elseif selected > #BUILTIN + ci then selected = selected - 1 end
    store.set("selected", selected)
  end)
end

local function setField(f, v)
  v = max(f.mn, min(f.mx, floor(v)))
  if v ~= cfg[f.key] then cfg[f.key] = v; selected = 0; saveCfg() end
end

local function promptField(f, label)
  ui.prompt(label, f.time and TR("enter_time") or TR("enter_number", f.mn, f.mx), tostring(f.time and mmss(cfg[f.key]) or cfg[f.key]), function(s)
    if not s then return end
    s = s:gsub("%s", "")
    local v
    local mm, ss = s:match("^(%d+):(%d%d?)$")
    if mm and f.time then v = tonumber(mm) * 60 + tonumber(ss) else v = tonumber(s) end
    if not v or v ~= v then showToast(TR("bad_number")); return end
    if v < f.mn or v > f.mx then showToast(TR("out_of_range", f.mn, f.mx)); return end
    setField(f, v)
  end)
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  cfg = clampCfg(store.get("cfg", BUILTIN[1].cfg))
  local cu = store.get("custom", {})
  custom = {}
  if type(cu) == "table" then
    for _, c in ipairs(cu) do
      if type(c) == "table" and type(c.name) == "string" then custom[#custom + 1] = {name = c.name, cfg = clampCfg(c.cfg)} end
    end
  end
  selected = floor(tonumber(store.get("selected", 1)) or 1)
  if selected < 0 or selected > presetCount() then selected = 0 end
  soundOn = store.get("sound", true) ~= false
  vibrateOn = store.get("vibrate", true) ~= false
  local h = store.get("history", {})
  history = type(h) == "table" and h or {}
  refreshPlan()
end

function app.update(dt)
  clock = clock + dt
  ringMix = min(1, ringMix + dt * 3)
  if toastT > 0 then toastT = toastT - dt end
  if mode ~= "run" or paused then return end
  elapsed = elapsed + dt
  local p = phases[idx]
  if not p then finish(); return end
  local left = p.dur - elapsed
  local secLeft = ceil(left)
  if secLeft >= 1 and secLeft <= 3 and secLeft ~= lastBeep and p.dur > 3 then
    lastBeep = secLeft
    beep("count")
  end
  while mode == "run" and phases[idx] and elapsed >= phases[idx].dur do
    elapsed = elapsed - phases[idx].dur
    if idx >= #phases then finish() else enterPhase(idx + 1) end
  end
end

-- ------------------------------------------------------------------ drawing: shared
local function timeline(list, sum, x, y, w, h, progress)
  if sum <= 0 then return end
  gfx.clip(x, y, w, h)
  for _, p in ipairs(list) do
    local px = x + w * p.start / sum
    local pw = max(1, w * p.dur / sum - 1)
    gfx.color(COLORS[p.kind])
    gfx.rect(px, y, pw, h, 0)
  end
  if progress then
    gfx.color(0, 0, 0, 90)
    gfx.rect(x, y, w * progress, h, 0)
    gfx.color(theme.text)
    gfx.rect(x + w * progress - 1.5, y - 2, 3, h + 4, 1)
  end
  gfx.unclip()
  gfx.color(theme.separator)
  gfx.rectLine(x, y, w, h, 4, 1)
end

-- ------------------------------------------------------------------ drawing: setup
local function fieldLabel(f)
  if f.key == "warm" then return TR("f_warm") elseif f.key == "work" then return TR("f_work")
  elseif f.key == "rest" then return TR("f_rest") elseif f.key == "rounds" then return TR("f_rounds")
  elseif f.key == "sets" then return TR("f_sets") elseif f.key == "setRest" then return TR("f_setrest") end
  return TR("f_cool")
end

local function presetSummary(c)
  local s = c.work .. "/" .. c.rest .. " ×" .. c.rounds
  if c.sets > 1 then s = s .. " ×" .. c.sets end
  return s
end

local function drawWeek(x, y, w, h)
  gfx.color(theme.text)
  gfx.text(TR("this_week"), x, y, 13, "semibold")
  local today = todayNum()
  local vals, mx, totalN, totalS = {}, 1, 0, 0
  for i = 6, 0, -1 do
    local e = history[dayKey(today - i)]
    local s = type(e) == "table" and (tonumber(e.s) or 0) or 0
    local n = type(e) == "table" and (tonumber(e.n) or 0) or 0
    vals[#vals + 1] = s
    mx = max(mx, s)
    totalN, totalS = totalN + n, totalS + s
  end
  gfx.color(theme.text3)
  gfx.text(TR("week_sum", totalN, floor(totalS / 60 + 0.5)), x, y + 18, 11)
  local cy, chh = y + 38, h - 56
  local bw = w / 7
  local wdays = {"wd_su", "wd_mo", "wd_tu", "wd_we", "wd_th", "wd_fr", "wd_sa"}
  local dow = (today + 4) % 7      -- 1970-01-01 was a Thursday
  for i = 1, 7 do
    local v = vals[i]
    local bh = max(3, chh * v / mx)
    gfx.color(v > 0 and theme.red or theme.separator)
    gfx.rect(x + (i - 1) * bw + 4, cy + chh - bh, bw - 8, bh, 3)
    gfx.color(i == 7 and theme.text or theme.text3)
    local wd = wdays[(dow - (7 - i)) % 7 + 1]
    gfx.text(TR(wd), x + (i - 1) * bw, cy + chh + 3, 10, "sans", "center", bw)
  end
end

local function drawSetup(w, h)
  local lw = min(250, floor(w * 0.36))
  -- presets column
  gfx.color(theme.sidebar)
  gfx.rect(0, 0, lw, h, 0)
  gfx.color(theme.text)
  gfx.text(TR("presets"), M, 18, 15, "semibold")
  local listY, weekH = 48, 120
  local listH = h - listY - weekH - 52
  local n = presetCount()
  ui.beginScroll("presets", 8, listY, lw - 16, listH, n * 46 + 4)
  for i = 1, n do
    local c = presetCfg(i)
    local ry = (i - 1) * 46
    local sel = i == selected
    local custIdx = i > #BUILTIN and i - #BUILTIN or nil
    local rw = lw - 16 - (custIdx and 36 or 0)
    local hit = ui.hit("p" .. i, 0, ry + 2, rw, 42)
    if sel then gfx.color(theme.selection); gfx.alpha(0.2); gfx.rect(0, ry + 2, lw - 16, 42, 8); gfx.unalpha()
    elseif hit.hovered then gfx.color(theme.hover); gfx.rect(0, ry + 2, lw - 16, 42, 8) end
    gfx.icon(custIdx and "star" or "fitness_center", 20, ry + 23, 18, sel and theme.accent or theme.text2)
    gfx.color(theme.text)
    gfx.clip(36, ry, rw - 40, 46)
    gfx.text(presetName(i), 38, ry + 6, 13, "semibold")
    gfx.color(theme.text3)
    gfx.text(c and presetSummary(c) or "", 38, ry + 24, 11)
    gfx.unclip()
    if hit.clicked then selectPreset(i) end
    if custIdx and ui.iconButton("delete", lw - 16 - 34, ry + 8, 32, 30, theme.text3, false, "del" .. i) then deletePreset(custIdx) end
  end
  ui.endScroll()
  if ui.button(TR("save_preset"), M - 6, listY + listH + 8, lw - 2 * M + 12, 32, "default", "bookmark_add") then savePreset() end
  drawWeek(M, h - weekH, lw - 2 * M, weekH - 12)

  -- editor
  local x = lw + 24
  local cw = w - x - 24
  gfx.color(theme.text)
  gfx.text(selected > 0 and presetName(selected) or TR("custom"), x, 16, 20, "bold")
  gfx.color(theme.text3)
  gfx.text(TR("total", mmss(planTotal), #planCache), x, 44, 13)

  local rowH = max(34, min(42, floor((h - 70 - 150) / #FIELDS)))
  local y0 = 70
  ui.group(x, y0, cw, rowH * #FIELDS)
  for i, f in ipairs(FIELDS) do
    local ry = y0 + (i - 1) * rowH
    if i > 1 then ui.separator(x + 12, ry, x + cw - 12) end
    local label = fieldLabel(f)
    gfx.color(theme.text)
    gfx.text(label, x + 14, ry + rowH / 2 - 9, 14)
    local bx = x + cw - 12 - 34
    local vw = 76
    if ui.button("+##" .. f.key, bx, ry + (rowH - 30) / 2, 34, 30, "default", nil, cfg[f.key] < f.mx) then setField(f, cfg[f.key] + f.step) end
    local vx = bx - vw - 6
    local v = f.time and mmss(cfg[f.key]) or tostring(cfg[f.key])
    if f.time and cfg[f.key] == 0 then v = TR("off") end
    if ui.button(v .. "##v" .. f.key, vx, ry + (rowH - 30) / 2, vw, 30, "plain") then promptField(f, label) end
    if ui.button("−##" .. f.key, vx - 40, ry + (rowH - 30) / 2, 34, 30, "default", nil, cfg[f.key] > f.mn) then setField(f, cfg[f.key] - f.step) end
  end

  local ty = y0 + rowH * #FIELDS + 14
  timeline(planCache, planTotal, x, ty, cw, 14)
  local ly = ty + 22
  local lx = x
  for _, k in ipairs({"warmup", "work", "rest", "setrest", "cooldown"}) do
    local name = phaseName(k)
    local iw = 14 + gfx.textWidth(name, 11) + 14
    if lx + iw > x + cw + 14 then lx = x; ly = ly + 18 end   -- wrap the legend on narrow windows
    gfx.color(COLORS[k])
    gfx.circle(lx + 5, ly + 7, 5)
    gfx.color(theme.text2)
    gfx.text(name, lx + 14, ly, 11)
    lx = lx + iw
  end

  local by = h - 52
  local s = ui.checkbox(TR("sound"), soundOn, x, by + 8)
  if s ~= soundOn then soundOn = s; store.set("sound", s) end
  local v = ui.checkbox(TR("vibrate"), vibrateOn, x + 110, by + 8)
  if v ~= vibrateOn then vibrateOn = v; store.set("vibrate", v) end
  if ui.button(TR("start"), x + cw - 170, by, 170, 38, "primary", "play_arrow", #planCache > 0) then start() end
end

-- ------------------------------------------------------------------ drawing: run
local function drawRun(w, h)
  local p = phases[idx]
  if not p then return end
  local col = mix(ringFrom, ringTo, ringMix)
  -- soft phase-colored backdrop
  gfx.color(col[1], col[2], col[3], theme.dark and 34 or 26)
  gfx.rect(0, 0, w, h, 0)

  local left = max(0, p.dur - elapsed)
  local cx, cy = w / 2, 40 + (h - 190) / 2 + 10
  local r = max(60, min(w * 0.3, (h - 190) / 2))
  local frac = p.dur > 0 and elapsed / p.dur or 1
  local pulse = 1
  if left <= 3 and not paused then pulse = 1 + 0.035 * (1 - (left % 1)) end
  local rr = r * pulse
  gfx.color(theme.separator)
  gfx.circleLine(cx, cy, rr, 14)
  gfx.color(col)
  if frac < 0.999 then gfx.arc(cx, cy, rr, -pi / 2 + frac * 2 * pi, 3 * pi / 2, 14) end
  -- moving dot at the arc's end
  local a = -pi / 2 + frac * 2 * pi
  gfx.circle(cx + math.cos(a) * rr, cy + math.sin(a) * rr, 10)

  gfx.color(col)
  gfx.text(phaseName(p.kind):upper(), cx - r, cy - r * 0.55, max(14, r * 0.13), "bold", "center", 2 * r)
  gfx.color(theme.text)
  local ts = max(28, r * 0.42)
  gfx.text(mmss(left), cx - r, cy - ts * 0.62, ts, "bold", "center", 2 * r)
  gfx.color(theme.text2)
  local info = ""
  if p.round then info = TR("round_of", p.round, cfg.rounds) end
  if p.set and cfg.sets > 1 then info = (info ~= "" and info .. " · " or "") .. TR("set_of", p.set, cfg.sets) end
  gfx.text(info, cx - r, cy + ts * 0.62, max(12, r * 0.1), "semibold", "center", 2 * r)
  if paused then
    gfx.color(theme.text3)
    gfx.text(TR("paused"), cx - r, cy + r * 0.5, 13, "semibold", "center", 2 * r)
  end

  -- next phase preview (top right) and total remaining (top left)
  local nxt = phases[idx + 1]
  local pw = 200
  ui.group(w - M - pw, 16, pw, 56)
  gfx.color(theme.text3)
  gfx.text(TR("next"), w - M - pw + 14, 24, 11, "semibold")
  if nxt then
    gfx.color(COLORS[nxt.kind])
    gfx.circle(w - M - pw + 20, 52, 5)
    gfx.color(theme.text)
    gfx.text(phaseName(nxt.kind) .. "  " .. mmss(nxt.dur), w - M - pw + 32, 43, 14, "semibold")
  else
    gfx.color(theme.text)
    gfx.text(TR("finish_line"), w - M - pw + 14, 43, 14, "semibold")
  end
  local done = p.start + elapsed
  gfx.color(theme.text3)
  gfx.text(TR("total_left"), M, 24, 11, "semibold")
  gfx.color(theme.text)
  gfx.text(mmss(total - done), M, 40, 22, "bold")

  -- timeline and controls
  local by = h - 54
  timeline(phases, total, M, by - 34, w - 2 * M, 12, total > 0 and done / total or 0)
  local bw = min(150, (w - 2 * M - 24) / 3)
  local bx = w / 2 - (3 * bw + 24) / 2
  if ui.button(TR("stop") .. "##run", bx, by, bw, 38, "destructive", "stop") then askStop() end
  if ui.button(paused and TR("resume") or TR("pause"), bx + bw + 12, by, bw, 38, "primary", paused and "play_arrow" or "pause") then togglePause() end
  if ui.button(TR("skip"), bx + 2 * (bw + 12), by, bw, 38, "default", "skip_next") then skip() end
end

local function drawDone(w, h)
  local t = clock - doneAt
  for _, c in ipairs(confetti) do
    local yy = ((t * c.v * 0.5 + c.ph * 0.17) % 1.1) * h - 20
    local xx = c.x * w + sin(t * 2 + c.ph) * 18
    gfx.color(c.c)
    gfx.rect(xx, yy, c.s, c.s * 0.6, 1)
  end
  local e = min(1, t * 2.5)
  local s = 1 - (1 - e) ^ 3
  local cx, cy = w / 2, h / 2 - 60
  gfx.color(theme.green)
  gfx.alpha(0.18)
  gfx.circle(cx, cy, 60 * s)
  gfx.unalpha()
  gfx.icon("emoji_events", cx, cy, 64 * s, theme.green)
  gfx.color(theme.text)
  gfx.text(TR("done_title"), 0, cy + 76, 24, "bold", "center", w)
  gfx.color(theme.text2)
  gfx.text(TR("done_msg", mmss(doneSecs), #phases), 0, cy + 110, 14, "sans", "center", w)
  if ui.button(TR("again"), w / 2 - 166, cy + 150, 160, 38, "default", "replay") then start() end
  if ui.button(TR("finish"), w / 2 + 6, cy + 150, 160, 38, "primary", "check") then mode = "setup" end
end

local function drawToast(w, h)
  if toastT <= 0 then return end
  local a = min(1, toastT * 3, (2.4 - toastT) * 6)
  local tw = gfx.textWidth(toast, 13, "medium") + 32
  local tx, ty = (w - tw) / 2, h - 100 + (1 - a) * 10
  gfx.alpha(a)
  gfx.color(theme.text)
  gfx.rect(tx, ty, tw, 34, 17)
  gfx.color(theme.bg)
  gfx.text(toast, tx + 16, ty + 9, 13, "medium")
  gfx.unalpha()
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  if mode == "run" then drawRun(w, h) elseif mode == "done" then drawDone(w, h) else drawSetup(w, h) end
  drawToast(w, h)
end

function app.event(e)
  if e.type ~= "keydown" then return end
  local k = e.key
  if k == "space" or k == "enter" then togglePause()
  elseif mode == "run" then
    if k == "right" or k == "n" then skip() elseif k == "escape" or k == "backspace" then askStop() end
  elseif mode == "setup" then
    local n = presetCount()
    if n > 0 and k == "down" then selectPreset(selected % n + 1)
    elseif n > 0 and k == "up" then selectPreset((selected - 2) % n + 1) end
  elseif mode == "done" and k == "escape" then mode = "setup" end
end

function app.menu()
  return {{title = TR("menu_workout"), items = {
    {label = TR("start") .. " / " .. TR("pause"), id = 1, shortcut = "Space"},
    {label = TR("skip"), id = 2, shortcut = "→"},
    {label = TR("stop"), id = 3, shortcut = "Esc"},
    "-",
    {label = TR("save_preset"), id = 4},
    {label = TR("sound"), id = 5},
    {label = TR("vibrate"), id = 6},
  }}}
end

function app.onmenu(id)
  if id == 1 then togglePause() elseif id == 2 then skip() elseif id == 3 then askStop()
  elseif id == 4 then savePreset()
  elseif id == 5 then soundOn = not soundOn; store.set("sound", soundOn)
  elseif id == 6 then vibrateOn = not vibrateOn; store.set("vibrate", vibrateOn) end
end

function app.close()
  store.save()
  return true
end

return app
