-- Math Race: answer as many arithmetic questions as you can in 60 seconds. Every correct answer drives your car
-- down the track; streaks raise the score multiplier. Three difficulties, best scores and a history chart.
local app = {}

local ROUND = 60
local TRACK_GOAL = 30           -- correct answers to reach the finish flag
local DIFFS = {"easy", "medium", "hard"}
local DIFF_COLORS = {"#34C759", "#FF9F0A", "#FF375F"}

local screen = "title"          -- "title", "play", "result"
local diff = 1
local best = {0, 0, 0}
local history = {{}, {}, {}}    -- last scores per difficulty
local g = nil                   -- current round
local paused = false
local parts = {}
local anim, shake = 0, 0

local function pickOp()
  if diff == 1 then return math.random() < 0.5 and "+" or "-" end
  if diff == 2 then return ({"+", "-", "×", "×"})[math.random(1, 4)] end
  return ({"+", "-", "×", "÷"})[math.random(1, 4)]
end

local function newQuestion()
  local op = pickOp()
  local a, b, ans
  local big = diff == 1 and 20 or diff == 2 and 50 or 100
  if op == "+" then a, b = math.random(1, big), math.random(1, big); ans = a + b
  elseif op == "-" then a, b = math.random(1, big), math.random(1, big); if b > a then a, b = b, a end; ans = a - b
  elseif op == "×" then
    local m = diff == 2 and 10 or 12
    a, b = math.random(2, m), math.random(2, diff == 3 and 15 or 10); ans = a * b
  else
    b, ans = math.random(2, 12), math.random(2, 12); a = b * ans
  end
  return {a = a, b = b, op = op, ans = ans, t0 = sys.time()}
end

local function burst(x, y, color, n)
  for i = 1, n do
    local ang, sp = math.random() * 6.283, 60 + math.random() * 200
    parts[#parts + 1] = {x = x, y = y, vx = math.cos(ang) * sp, vy = math.sin(ang) * sp - 60, life = 0.6 + math.random() * 0.5,
      c = color, s = 2 + math.random() * 3}
  end
end

local function start(d)
  diff = d or diff
  store.set("diff", diff)
  g = {left = ROUND, score = 0, correct = 0, wrong = 0, combo = 0, mult = 1, q = newQuestion(), input = "",
    carX = 0, flash = 0, flashOk = true, times = 0, count = 3, done = false}
  paused = false
  screen, anim = "play", 0
  audio.tone(523, 0.12, 0.4, "triangle")
end

local function finish()
  g.done = true
  g.newBest = g.score > (best[diff] or 0)
  if g.newBest then best[diff] = g.score; store.set("best", best) end
  local hst = history[diff]
  hst[#hst + 1] = g.score
  while #hst > 12 do table.remove(hst, 1) end
  store.set("history", history)
  screen, anim = "result", 0
  if g.newBest and g.score > 0 then
    local w, h = gfx.size()
    for _ = 1, 3 do burst(w * (0.25 + math.random() * 0.5), h * 0.3, DIFF_COLORS[math.random(1, 3)], 40) end
    audio.play("notify")
  else
    audio.tone(392, 0.3, 0.4, "triangle")
  end
end

local function judge()
  local q = g.q
  local v = tonumber(g.input)
  local w, h = gfx.size()
  if v == q.ans then
    g.correct = g.correct + 1
    g.combo = g.combo + 1
    g.mult = math.min(5, 1 + g.combo // 3)
    g.score = g.score + 10 * g.mult
    g.times = g.times + (sys.time() - q.t0)
    g.flash, g.flashOk = 0.35, true
    audio.tone(660 + g.mult * 80, 0.08, 0.35, "square")
    burst(20 + (w - 80) * math.min(1, g.correct / TRACK_GOAL) + 20, 66, DIFF_COLORS[diff], 14)
    if g.correct == TRACK_GOAL then audio.play("notify") end
  else
    g.wrong = g.wrong + 1
    g.combo, g.mult = 0, 1
    g.flash, g.flashOk = 0.45, false
    shake = 0.3
    audio.tone(150, 0.2, 0.4, "saw")
    sys.vibrate(0.4, 80)
  end
  g.q = newQuestion()
  g.input = ""
end

-- answers are checked automatically once enough digits are typed
local function typeDigit(d)
  if screen ~= "play" or paused or g.count > 0 then return end
  if #g.input >= 4 then return end
  g.input = g.input .. d
  if g.input == tostring(g.q.ans) or #g.input >= #tostring(g.q.ans) then judge() end
end

function app.load()
  local b = store.get("best", {0, 0, 0})
  best = {tonumber(b[1]) or 0, tonumber(b[2]) or 0, tonumber(b[3]) or 0}
  local hs = store.get("history", {})
  history = {{}, {}, {}}
  if type(hs) == "table" then for i = 1, 3 do if type(hs[i]) == "table" then history[i] = hs[i] end end end
  diff = math.max(1, math.min(3, store.get("diff", 1)))
  math.randomseed(math.floor(sys.epoch()))
end

function app.update(dt)
  anim = math.min(1, anim + dt * 3)
  shake = math.max(0, shake - dt)
  for i = #parts, 1, -1 do
    local p = parts[i]
    p.vy = p.vy + 400 * dt
    p.x, p.y, p.life = p.x + p.vx * dt, p.y + p.vy * dt, p.life - dt
    if p.life <= 0 then table.remove(parts, i) end
  end
  if screen ~= "play" or not g or paused then return end
  if g.count > 0 then
    local before = math.ceil(g.count)
    g.count = g.count - dt
    if math.ceil(g.count) ~= before then audio.tone(g.count <= 0 and 880 or 523, 0.1, 0.4, "triangle") end
    if g.count <= 0 then g.count = 0; g.q = newQuestion() end
    return
  end
  g.left = g.left - dt
  g.flash = math.max(0, g.flash - dt)
  g.carX = g.carX + (math.min(1, g.correct / TRACK_GOAL) - g.carX) * math.min(1, dt * 6)
  if g.left <= 5 and math.ceil(g.left) ~= math.ceil(g.left + dt) then audio.tone(1000, 0.05, 0.3, "sine") end
  if g.left <= 0 then g.left = 0; finish() end
end

-- ------------------------------------------------------------------ drawing
local function drawParts()
  for _, p in ipairs(parts) do
    gfx.alpha(math.min(1, p.life * 2))
    gfx.color(p.c)
    gfx.circle(p.x, p.y, p.s)
    gfx.unalpha()
  end
end

local function drawTitle(w, h)
  local t = sys.time()
  gfx.gradient(0, 0, w, h * 0.42, DIFF_COLORS[diff], theme.bg, false)
  gfx.color("#FFFFFF")
  gfx.text(TR("app_name"), 0, 34, 34, "bold", "center", w)
  gfx.color("#FFFFFFCC")
  gfx.text(TR("tagline", ROUND), 0, 78, 14, "sans", "center", w)
  -- a car idling on a little road
  local ry = h * 0.42 - 26
  gfx.color(theme.dark and "#2C2C2E" or "#3A3A3C")
  gfx.rect(40, ry, w - 80, 22, 11)
  gfx.color("#FFFFFF88")
  for x = 60 + (t * 60) % 40, w - 60, 40 do gfx.rect(x, ry + 10, 18, 2, 1) end
  gfx.icon("directions_car", w / 2 + math.sin(t * 2) * 6, ry + 4 + math.sin(t * 9) * 1.2, 40, "#FFFFFF")

  local cw = math.min(200, (w - 64) / 3)
  local x0 = (w - (cw * 3 + 24)) / 2
  local y = h * 0.42 + 20
  for i = 1, 3 do
    local x = x0 + (i - 1) * (cw + 12)
    local hit = ui.hit("diff" .. i, x, y, cw, 120)
    local sel = i == diff
    gfx.shadow(x, y, cw, 120, 14, 10, 3)
    gfx.rect(x, y, cw, 120, 14, sel and DIFF_COLORS[i] or theme.field)
    if hit.hovered and not sel then gfx.color(theme.hover); gfx.rect(x, y, cw, 120, 14) end
    gfx.color(sel and "#FFFFFF" or theme.text)
    gfx.text(TR(DIFFS[i]), x, y + 14, 18, "bold", "center", cw)
    gfx.color(sel and "#FFFFFFCC" or theme.text2)
    gfx.text(TR(DIFFS[i] .. "_ops"), x, y + 42, 13, "sans", "center", cw)
    gfx.icon("emoji_events", x + cw / 2 - 30, y + 88, 18, sel and "#FFFFFF" or theme.yellow)
    gfx.text(tostring(best[i]), x + cw / 2 - 18, y + 79, 16, "semibold")
    if hit.clicked then if sel then start(i) else diff = i; store.set("diff", i); audio.play("click") end end
  end
  if ui.button(TR("start"), w / 2 - 100, y + 140, 200, 40, "primary", "play_arrow") then start(diff) end
  gfx.color(theme.text3)
  gfx.text(TR("keys_hint"), 0, h - 28, 12, "sans", "center", w)
end

local function drawPad(x, y, w, h)
  local keys = {"7", "8", "9", "4", "5", "6", "1", "2", "3", "C", "0", "<"}
  local gap = 8
  local kw, kh = (w - gap * 2) / 3, (h - gap * 3) / 4
  for i, k in ipairs(keys) do
    local bx, by = x + ((i - 1) % 3) * (kw + gap), y + ((i - 1) // 3) * (kh + gap)
    if k == "<" then
      if ui.button("##bs", bx, by, kw, kh, "default", "backspace") then g.input = g.input:sub(1, -2) end
    elseif k == "C" then
      if ui.button("C##clr", bx, by, kw, kh) then g.input = "" end
    elseif ui.button(k .. "##n" .. k, bx, by, kw, kh) then typeDigit(k) end
  end
end

local function drawPlay(w, h)
  local sx = shake > 0 and math.random(-4, 4) * shake * 3 or 0
  gfx.push(sx, 0)
  -- HUD
  gfx.color(theme.text)
  gfx.text(TR("score", g.score), 20, 14, 18, "bold")
  gfx.color(g.left <= 10 and theme.red or theme.text)
  gfx.text(string.format("%d", math.ceil(g.left)), 0, 10, 26, "bold", "center", w)
  if g.mult > 1 then
    gfx.color(DIFF_COLORS[diff])
    gfx.text("×" .. g.mult, 0, 16, 18, "bold", "right", w - 64)
  end
  if ui.iconButton("pause", w - 52, 10, 34, 34) then paused = true end
  -- race track
  local ty = 52
  gfx.color(theme.dark and "#2C2C2E" or "#3A3A3C")
  gfx.rect(20, ty, w - 40, 30, 15)
  gfx.color("#FFFFFF55")
  for x = 34, w - 60, 28 do gfx.rect(x, ty + 14, 14, 2, 1) end
  local fx = w - 46
  for i = 0, 5 do
    gfx.color(i % 2 == 0 and "#FFFFFF" or "#000000")
    gfx.rect(fx + (i % 2) * 6, ty + i * 5, 6, 5)
    gfx.color(i % 2 == 1 and "#FFFFFF" or "#000000")
    gfx.rect(fx + ((i + 1) % 2) * 6, ty + i * 5, 6, 5)
  end
  gfx.icon("directions_car", 40 + (w - 100) * g.carX, ty + 15, 30, DIFF_COLORS[diff])
  ui.progress(g.left / ROUND, 20, ty + 38, w - 40, 4)

  local top = ty + 54
  if g.count > 0 then
    gfx.color(DIFF_COLORS[diff])
    local n = math.ceil(g.count)
    local f = g.count - math.floor(g.count)
    gfx.text(tostring(n), 0, h / 2 - 50 - f * 10, 80 + f * 30, "bold", "center", w)
    gfx.pop()
    return
  end
  -- question card + pad side by side (or stacked when narrow)
  local wide = w >= 620
  local cw = wide and (w - 60) * 0.55 or w - 40
  local chh = wide and h - top - 20 or math.min(130, (h - top) * 0.36)
  local fl = g.flash > 0 and (g.flashOk and theme.green or theme.red) or nil
  gfx.shadow(20, top, cw, chh, 16, 10, 3)
  gfx.rect(20, top, cw, chh, 16, theme.field)
  if fl then gfx.alpha(g.flash * 1.5); gfx.color(fl); gfx.rectLine(20, top, cw, chh, 16, 4); gfx.unalpha() end
  local q = g.q
  local size = math.min(48, chh * 0.32, cw / 9)
  gfx.color(theme.text)
  gfx.text(q.a .. " " .. q.op .. " " .. q.b .. " =", 20, top + chh / 2 - size * 0.95, size, "bold", "center", cw)
  gfx.color(g.input == "" and theme.text3 or theme.accent)
  gfx.text(g.input == "" and "?" or g.input, 20, top + chh / 2 + size * 0.1, size, "bold", "center", cw)
  if wide then drawPad(40 + cw, top, w - 60 - cw, h - top - 20)
  else drawPad(20, top + chh + 12, w - 40, h - top - chh - 24) end
  gfx.pop()

  if paused then
    gfx.color(0, 0, 0, 140)
    gfx.rect(0, 0, w, h)
    local pw, ph = 280, 170
    local px, py = (w - pw) / 2, (h - ph) / 2
    gfx.shadow(px, py, pw, ph, 16, 18, 4)
    gfx.rect(px, py, pw, ph, 16, theme.window)
    gfx.color(theme.text)
    gfx.text(TR("paused"), px, py + 18, 20, "bold", "center", pw)
    if ui.button(TR("resume"), px + 30, py + 60, pw - 60, 36, "primary", "play_arrow") then paused = false end
    if ui.button(TR("quit"), px + 30, py + 108, pw - 60, 36, "default", "close") then paused = false; screen = "title" end
  end
end

local function drawResult(w, h)
  local a = 1 - (1 - anim) ^ 3
  gfx.color(theme.text)
  gfx.text(TR("finished"), 0, 20, 22, "bold", "center", w)
  gfx.color(g.newBest and theme.orange or DIFF_COLORS[diff])
  gfx.text(tostring(math.floor(g.score * a + 0.5)), 0, 50, 54, "bold", "center", w)
  gfx.color(g.newBest and theme.orange or theme.text2)
  gfx.text(g.newBest and TR("new_best") or TR("best_is", best[diff]), 0, 118, 14, g.newBest and "bold" or "sans", "center", w)
  local total = g.correct + g.wrong
  local accp = total > 0 and math.floor(g.correct * 100 / total + 0.5) or 0
  local avg = g.correct > 0 and string.format("%.1f", g.times / g.correct) or "–"
  local stats = {{TR("correct"), tostring(g.correct)}, {TR("wrong"), tostring(g.wrong)}, {TR("accuracy"), accp .. "%"},
    {TR("avg_time"), avg .. " s"}}
  local sw = (w - 40 - 36) / 4
  for i, s in ipairs(stats) do
    local x = 20 + (i - 1) * (sw + 12)
    ui.group(x, 146, sw, 58)
    gfx.color(theme.text)
    gfx.text(s[2], x, 154, 20, "bold", "center", sw)
    gfx.color(theme.text2)
    gfx.text(s[1], x, 182, 12, "sans", "center", sw)
  end
  -- recent scores chart
  local hst = history[diff]
  local top, bottom = 230, h - 66
  if bottom - top > 50 and #hst > 0 then
    gfx.color(theme.text2)
    gfx.text(TR("recent", TR(DIFFS[diff])), 20, top, 13, "semibold")
    local mx = 10
    for _, v in ipairs(hst) do mx = math.max(mx, v) end
    local cy0, ch = top + 24, bottom - top - 30
    local bw = (w - 40) / 12
    for i, v in ipairs(hst) do
      local bh = math.max(3, ch * v / mx * a)
      local last = i == #hst
      gfx.rect(20 + (i - 1) * bw + bw * 0.15, cy0 + ch - bh, bw * 0.7, bh, 5, last and DIFF_COLORS[diff] or theme.separator)
      gfx.color(theme.text3)
      gfx.text(tostring(v), 20 + (i - 1) * bw, cy0 + ch - bh - 15, 10, "sans", "center", bw)
    end
  end
  local bw = math.min(160, (w - 64) / 3)
  local x0 = (w - bw * 3 - 24) / 2
  if ui.button(TR("again"), x0, h - 50, bw, 36, "primary", "refresh") then start(diff) end
  if ui.button(TR("menu"), x0 + bw + 12, h - 50, bw, 36, "default", "home") then screen = "title" end
  if ui.button(TR("copy"), x0 + (bw + 12) * 2, h - 50, bw, 36, "default", "content_copy") then
    sys.clipboard(TR("share", g.score, TR(DIFFS[diff]), g.correct, accp))
    audio.play("pop")
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  if screen == "play" and g then drawPlay(w, h)
  elseif screen == "result" and g then drawResult(w, h)
  else screen = "title"; drawTitle(w, h) end
  drawParts()
end

function app.event(e)
  if e.type ~= "keydown" then return end
  local k = e.key
  if screen == "play" and g then
    if k == "escape" or k == "p" then paused = not paused
    elseif paused then if k == "enter" then paused = false end
    elseif #k == 1 and k:match("%d") then typeDigit(k)
    elseif k == "backspace" then g.input = g.input:sub(1, -2)
    elseif k == "enter" and g.input ~= "" and g.count <= 0 then judge() end
  elseif screen == "result" then
    if k == "enter" or k == "space" then start(diff) elseif k == "escape" then screen = "title" end
  else
    if k == "left" then diff = math.max(1, diff - 1)
    elseif k == "right" then diff = math.min(3, diff + 1)
    elseif k == "enter" or k == "space" then start(diff) end
  end
end

function app.menu()
  return {{title = TR("app_name"), items = {
    {label = TR("start"), id = 1, shortcut = "Enter"},
    {label = TR("pause"), id = 2, shortcut = "Esc"},
    "-",
    {label = TR("reset_scores"), id = 3},
  }}}
end

function app.onmenu(id)
  if id == 1 then start(diff)
  elseif id == 2 then if screen == "play" then paused = not paused end
  elseif id == 3 then
    ui.alert(TR("reset_scores"), TR("reset_msg"), {TR("reset"), TR("common.cancel")}, function(b)
      if b == 1 then best, history = {0, 0, 0}, {{}, {}, {}}; store.set("best", best); store.set("history", history) end
    end)
  end
end

function app.close()
  store.save()
  return true
end

return app
