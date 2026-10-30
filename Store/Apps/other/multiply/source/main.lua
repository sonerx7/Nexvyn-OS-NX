-- Times Tables: learn the multiplication tables 1-10, then earn up to three stars per level in a timed quiz.
-- Two answer modes: four big choices, or typing the answer on an on-screen number pad.
local app = {}

local LEVELS = 12            -- 1..10 = one table each, 11 = mixed 1-5, 12 = mixed 1-10
local QUESTIONS = 10
local TIME_PER_Q = 12        -- seconds

local screen = "map"         -- "map", "learn", "quiz", "result"
local stars = {}             -- ["level"] = 0..3
local typed = false          -- answer mode: false = choices, true = number pad
local learnTable = 2
local revealed = {}          -- learn view: [row] = true
local q = nil                -- current quiz state
local flash, flashColor = 0, nil
local streakBest = 0
local acc = {}               -- ["7"] = {right, asked}: how well each number is known
local parts = {}             -- confetti
local anim = 0               -- screen fade-in 0..1

local COLORS = {"#FF6B6B", "#FF9F43", "#FECA57", "#1DD1A1", "#48DBFB", "#54A0FF", "#5F27CD", "#FF9FF3",
  "#00D2D3", "#EE5253", "#10AC84", "#341F97"}

local function starsOf(l) return stars[tostring(l)] or 0 end
local function unlocked(l) return l == 1 or starsOf(l - 1) > 0 end
local function totalStars()
  local s = 0
  for l = 1, LEVELS do s = s + starsOf(l) end
  return s
end

local function levelName(l)
  if l <= 10 then return TR("table_n", l) elseif l == 11 then return TR("mixed_small") end
  return TR("mixed_all")
end

-- one question: a × b, plus four distinct choices around the answer
local function makeQuestion(level)
  local a, b
  if level <= 10 then a, b = level, math.random(1, 10)
  elseif level == 11 then a, b = math.random(1, 5), math.random(1, 10)
  else a, b = math.random(2, 10), math.random(2, 10) end
  if math.random() < 0.5 then a, b = b, a end
  local ans = a * b
  local choices, seen = {ans}, {[ans] = true}
  local tries = 0
  while #choices < 4 and tries < 50 do
    tries = tries + 1
    local c
    local r = math.random(1, 3)
    if r == 1 then c = ans + math.random(-3, 3)
    elseif r == 2 then c = (a + math.random(-1, 1)) * b
    else c = a * (b + math.random(-1, 1)) end
    if c > 0 and not seen[c] then seen[c] = true; choices[#choices + 1] = c end
  end
  local n = ans + 1
  while #choices < 4 do if not seen[n] then seen[n] = true; choices[#choices + 1] = n end; n = n + 1 end
  for i = #choices, 2, -1 do local j = math.random(1, i); choices[i], choices[j] = choices[j], choices[i] end
  return {a = a, b = b, ans = ans, choices = choices}
end

local function startQuiz(level)
  if not level or level < 1 or level > LEVELS or not unlocked(level) then return end
  q = {level = level, n = 1, correct = 0, streak = 0, best = 0, cur = makeQuestion(level), input = "",
    left = TIME_PER_Q, feedback = 0, last = nil, picked = nil, slide = 0, improved = false}
  screen, anim = "quiz", 0
end

local function finishQuiz()
  local c = q.correct
  local s = c >= 10 and 3 or c >= 8 and 2 or c >= 6 and 1 or 0
  q.stars = s
  if s > starsOf(q.level) then stars[tostring(q.level)] = s; store.set("stars", stars); q.improved = true end
  if q.best > streakBest then streakBest = q.best; store.set("streakBest", streakBest) end
  screen, anim = "result", 0
  if s > 0 then audio.play("notify") else audio.play("error") end
  if s == 3 or q.improved then
    local w, h = gfx.size()
    local cols = {"#FF6B6B", "#FECA57", "#1DD1A1", "#54A0FF", "#FF9FF3"}
    for i = 1, 80 do
      parts[i] = {x = w / 2, y = h * 0.25, vx = math.random(-280, 280), vy = math.random(-460, -140),
        r = math.random() * 6.28, c = cols[i % 5 + 1], life = 2 + math.random()}
    end
  end
end

local function nextQuestion()
  if q.n >= QUESTIONS then finishQuiz() return end
  q.n = q.n + 1
  q.cur = makeQuestion(q.level)
  q.input, q.left, q.feedback, q.picked, q.slide = "", TIME_PER_Q, 0, nil, 0
end

-- value = the answer given (nil = time ran out)
local function answer(value)
  if not q or q.feedback > 0 then return end
  local ok = value == q.cur.ans
  q.last, q.picked, q.feedback = ok, value, ok and 0.7 or 1.6
  for _, f in ipairs({q.cur.a, q.cur.b}) do
    local k = tostring(f)
    local e = acc[k] or {0, 0}
    acc[k] = {(e[1] or 0) + (ok and 1 or 0), (e[2] or 0) + 1}
  end
  store.set("acc", acc)
  if ok then
    q.correct = q.correct + 1
    q.streak = q.streak + 1
    q.best = math.max(q.best, q.streak)
    audio.tone(660 + math.min(q.streak, 8) * 40, 0.12, 0.4, "triangle")
    flash, flashColor = 0.4, theme.green
  else
    q.streak = 0
    audio.tone(180, 0.25, 0.4, "square")
    sys.vibrate(0.4, 80)
    flash, flashColor = 0.4, theme.red
  end
end

local function typeDigit(d)
  if screen ~= "quiz" or not typed or q.feedback > 0 then return end
  if #q.input < 3 then q.input = q.input .. d; audio.play("key") end
end
local function backspace()
  if screen == "quiz" and typed and #q.input > 0 then q.input = q.input:sub(1, -2) end
end
local function submitTyped()
  if screen == "quiz" and typed and q.feedback == 0 and q.input ~= "" then answer(tonumber(q.input)) end
end

function app.load()
  local s = store.get("stars", {})
  stars = type(s) == "table" and s or {}
  typed = store.get("typed", false) == true
  streakBest = store.get("streakBest", 0)
  learnTable = store.get("learnTable", 2)
  local a = store.get("acc", {})
  acc = type(a) == "table" and a or {}
  math.randomseed(math.floor(sys.epoch()))
end

function app.update(dt)
  if flash > 0 then flash = math.max(0, flash - dt) end
  anim = math.min(1, anim + dt * 4)
  for i = #parts, 1, -1 do
    local p = parts[i]
    p.vy = p.vy + 560 * dt
    p.x, p.y, p.r, p.life = p.x + p.vx * dt, p.y + p.vy * dt, p.r + dt * 6, p.life - dt
    if p.life <= 0 then table.remove(parts, i) end
  end
  if q then q.slide = math.min(1, (q.slide or 1) + dt * 5) end
  if screen ~= "quiz" or not q then return end
  if q.feedback > 0 then
    q.feedback = q.feedback - dt
    if q.feedback <= 0 then q.feedback = 0; nextQuestion() end
  else
    q.left = q.left - dt
    if q.left <= 0 then q.left = 0; answer(nil) end
  end
end

-- ------------------------------------------------------------------ screens
local function header(w, title, back)
  if back and ui.button(TR("back"), 16, 12, 100, 32, "plain", "arrow_back") then screen = "map" end
  gfx.color(theme.text)
  gfx.text(title, 0, 16, 22, "bold", "center", w)
end

local function drawMap(w, h)
  gfx.color(theme.text)
  gfx.text(TR("app_name"), 20, 16, 24, "bold")
  gfx.color(theme.text2)
  gfx.text(TR("stars_total", totalStars(), LEVELS * 3), 20, 48, 13)
  local mode = ui.segmented("mode", {TR("mode_choice"), TR("mode_typed")}, typed and 2 or 1, w - 276, 16, 256, 30)
  if (mode == 2) ~= typed then typed = mode == 2; store.set("typed", typed) end

  local cols = w >= 600 and 4 or 3
  local gap = 12
  local top = 80
  local cw = (w - 40 - gap * (cols - 1)) / cols
  local rows = math.ceil(LEVELS / cols)
  local ch = math.max(56, math.min(92, (h - top - 64 - gap * (rows - 1)) / rows))
  for l = 1, LEVELS do
    local c = (l - 1) % cols
    local r = (l - 1) // cols
    local x, y = 20 + c * (cw + gap), top + r * (ch + gap)
    local open = unlocked(l)
    local hit = ui.hit("lvl" .. l, x, y, cw, ch)
    gfx.shadow(x, y, cw, ch, 14, 8, 2)
    if open then gfx.gradient(x, y, cw, ch, COLORS[l], COLORS[(l % #COLORS) + 1], true, 14)
    else gfx.rect(x, y, cw, ch, 14, theme.field) end
    if hit.hovered and open then gfx.color(255, 255, 255, 40); gfx.rect(x, y, cw, ch, 14) end
    gfx.color(open and "#FFFFFF" or theme.text3)
    gfx.text(levelName(l), x, y + 8, ch > 70 and 18 or 15, "bold", "center", cw)
    if open then
      local s = starsOf(l)
      for i = 1, 3 do gfx.icon(i <= s and "star" or "star_border", x + cw / 2 + (i - 2) * 24, y + ch - 20, 22, "#FFFFFF") end
    else
      gfx.icon("lock", x + cw / 2, y + ch - 22, 22, theme.text3)
    end
    if hit.clicked and open then startQuiz(l) end
  end
  local by = h - 50
  if ui.button(TR("learn"), 20, by, 150, 36, "primary", "school") then screen, anim = "learn", 0; revealed = {} end
  if ui.button(TR("stats"), 180, by, 150, 36, "default", "insights") then screen, anim = "stats", 0 end
  gfx.color(theme.text3)
  gfx.text(TR("best_streak", streakBest), 0, by + 10, 13, "sans", "right", w - 20)
end

local function drawLearn(w, h)
  header(w, TR("learn_title"), true)
  -- table picker
  local bw = math.min(46, (w - 40 - 9 * 6) / 10)
  local x0 = (w - (bw * 10 + 54)) / 2
  for i = 1, 10 do
    if ui.button(tostring(i) .. "##t" .. i, x0 + (i - 1) * (bw + 6), 56, bw, 34, i == learnTable and "primary" or "default") then
      learnTable = i; revealed = {}; store.set("learnTable", i)
    end
  end
  gfx.color(theme.text3)
  gfx.text(TR("learn_hint"), 0, 98, 13, "sans", "center", w)
  local top, bottom = 122, h - 16
  local rh = (bottom - top) / 10
  local colw = math.min(360, w - 40)
  local x = (w - colw) / 2
  for r = 1, 10 do
    local y = top + (r - 1) * rh
    local hit = ui.hit("row" .. r, x, y + 1, colw, rh - 2)
    gfx.color(hit.hovered and theme.hover or (r % 2 == 0 and theme.field or theme.bg))
    gfx.rect(x, y + 1, colw, rh - 2, 8)
    local size = math.max(13, math.min(22, rh * 0.55))
    gfx.color(theme.text)
    gfx.text(learnTable .. " × " .. r .. " =", x + 16, y + (rh - size * 1.25) / 2, size, "semibold")
    if revealed[r] then
      gfx.color(COLORS[learnTable])
      gfx.text(tostring(learnTable * r), x, y + (rh - size * 1.25) / 2, size, "bold", "right", colw - 16)
    else
      gfx.icon("visibility", x + colw - 28, y + rh / 2, size + 2, theme.text3)
    end
    if hit.clicked then revealed[r] = not revealed[r]; audio.play("click") end
  end
end

-- how well each number 1-10 is known, as a bar chart
local function drawStats(w, h)
  header(w, TR("stats"), true)
  local asked, right = 0, 0
  for n = 1, 10 do local e = acc[tostring(n)]; if e then right, asked = right + (e[1] or 0), asked + (e[2] or 0) end end
  local top, bottom = 70, h - 70
  if asked == 0 then
    gfx.icon("insights", w / 2, h / 2 - 30, 56, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("stats_empty"), 0, h / 2 + 10, 15, "sans", "center", w)
    return
  end
  gfx.color(theme.text2)
  gfx.text(TR("stats_hint"), 0, top, 13, "sans", "center", w)
  top = top + 30
  local ch = bottom - top - 22
  local bw = (w - 40) / 10
  local e3 = 1 - (1 - anim) ^ 3
  local weakest, weakV = nil, 2
  for n = 1, 10 do
    local e = acc[tostring(n)]
    local x = 20 + (n - 1) * bw
    gfx.rect(x + bw * 0.18, top, bw * 0.64, ch, 8, theme.field)
    if e and (e[2] or 0) > 0 then
      local v = (e[1] or 0) / e[2]
      if v < weakV then weakV, weakest = v, n end
      local bh = math.max(4, ch * v * e3)
      gfx.gradient(x + bw * 0.18, top + ch - bh, bw * 0.64, bh, COLORS[n], COLORS[n % #COLORS + 1], false, 8)
      gfx.color(theme.text2)
      gfx.text(math.floor(v * 100 + 0.5) .. "%", x, top + ch - bh - 18, 11, "semibold", "center", bw)
    end
    gfx.color(theme.text)
    gfx.text(tostring(n), x, top + ch + 6, 15, "bold", "center", bw)
  end
  gfx.color(theme.text2)
  local msg = TR("stats_total", asked, math.floor(right * 100 / asked + 0.5))
  if weakest and weakV < 0.9 then msg = msg .. "  ·  " .. TR("stats_weak", weakest) end
  gfx.text(msg, 0, h - 40, 14, "semibold", "center", w)
end

local function drawPad(x, y, w, h)
  local keys = {"7", "8", "9", "4", "5", "6", "1", "2", "3", "del", "0", "ok"}
  local gap = 8
  local kw, kh = (w - gap * 2) / 3, (h - gap * 3) / 4
  for i, k in ipairs(keys) do
    local c, r = (i - 1) % 3, (i - 1) // 3
    local bx, by = x + c * (kw + gap), y + r * (kh + gap)
    if k == "del" then
      if ui.button("##del", bx, by, kw, kh, "default", "backspace") then backspace() end
    elseif k == "ok" then
      if ui.button(TR("ok") .. "##ok", bx, by, kw, kh, "primary", "check", q.input ~= "" and q.feedback == 0) then submitTyped() end
    elseif ui.button(k .. "##k" .. k, bx, by, kw, kh) then typeDigit(k) end
  end
end

local function drawQuiz(w, h)
  header(w, levelName(q.level), true)
  gfx.color(theme.text2)
  gfx.text(TR("question_n", q.n, QUESTIONS), 0, 20, 14, "sans", "right", w - 20)
  ui.progress(q.left / TIME_PER_Q, 20, 54, w - 40, 6)
  -- the question card
  local cardH = math.max(90, math.min(130, h * 0.24))
  local cy = 72
  local sl = 1 - (1 - (q.slide or 1)) ^ 3
  gfx.alpha(sl)
  gfx.push((1 - sl) * 50, 0)
  gfx.shadow(20, cy, w - 40, cardH, 16, 10, 3)
  gfx.gradient(20, cy, w - 40, cardH, COLORS[q.level], COLORS[(q.level % #COLORS) + 1], true, 16)
  local shown = q.cur.a .. " × " .. q.cur.b .. " = " .. (typed and (q.input ~= "" and q.input or "?") or "?")
  if q.feedback > 0 then shown = q.cur.a .. " × " .. q.cur.b .. " = " .. q.cur.ans end
  gfx.color("#FFFFFF")
  gfx.text(shown, 20, cy + cardH / 2 - 26, math.min(44, cardH * 0.4), "bold", "center", w - 40)
  gfx.pop()
  gfx.unalpha()
  -- streak dots
  for i = 1, QUESTIONS do
    gfx.color(i < q.n and theme.green or i == q.n and theme.accent or theme.separator)
    gfx.circle(w / 2 + (i - (QUESTIONS + 1) / 2) * 16, cy + cardH + 14, 4)
  end
  local top = cy + cardH + 30
  local bottom = h - 34
  if typed then
    local pw = math.min(330, w - 40)
    drawPad((w - pw) / 2, top, pw, bottom - top)
  else
    local gap = 12
    local bw, bh = (w - 40 - gap) / 2, math.min(80, (bottom - top - gap) / 2)
    for i, c in ipairs(q.cur.choices) do
      local x = 20 + ((i - 1) % 2) * (bw + gap)
      local y = top + ((i - 1) // 2) * (bh + gap)
      local hit = ui.hit("ch" .. i, x, y, bw, bh)
      local col = theme.field
      if q.feedback > 0 then
        if c == q.cur.ans then col = theme.green elseif c == q.picked then col = theme.red end
      elseif hit.hovered then col = theme.hover end
      gfx.shadow(x, y, bw, bh, 12, 6, 2)
      gfx.rect(x, y, bw, bh, 12, col)
      gfx.color(theme.separator)
      gfx.rectLine(x, y, bw, bh, 12, 1)
      gfx.color((q.feedback > 0 and (c == q.cur.ans or c == q.picked)) and "#FFFFFF" or theme.text)
      gfx.text(tostring(c), x, y + bh / 2 - 17, 28, "bold", "center", bw)
      gfx.color(theme.text3)
      gfx.text(tostring(i), x + 10, y + 6, 11)
      if hit.clicked then answer(c) end
    end
  end
  gfx.color(theme.text2)
  local msg = TR("score_now", q.correct)
  if q.feedback > 0 then msg = q.last and TR("right") or TR("wrong", q.cur.ans) end
  if q.streak >= 3 then msg = msg .. "  ·  " .. TR("streak", q.streak) end
  gfx.text(msg, 0, h - 26, 14, "semibold", "center", w)
end

local function drawResult(w, h)
  header(w, levelName(q.level), true)
  local cx = w / 2
  local y = math.max(70, h / 2 - 130)
  for i = 1, 3 do
    local t = math.max(0, math.min(1, anim * 3 - (i - 1) * 0.5))
    local pop = t < 1 and (1 + math.sin(t * math.pi) * 0.35) * t or 1
    gfx.icon(i <= q.stars and "star" or "star_border", cx + (i - 2) * 70, y + 40, math.max(1, (i == 2 and 70 or 56) * pop),
      i <= q.stars and theme.yellow or theme.text3)
  end
  if q.improved then
    gfx.color(theme.orange)
    gfx.text(TR("new_stars"), 0, y + 76, 13, "bold", "center", w)
  end
  gfx.color(theme.text)
  gfx.text(TR("result", q.correct, QUESTIONS), 0, y + 96, 26, "bold", "center", w)
  gfx.color(theme.text2)
  local msg = q.stars == 3 and TR("perfect") or q.stars > 0 and TR("good") or TR("try_again")
  gfx.text(msg, 0, y + 134, 15, "sans", "center", w)
  gfx.text(TR("best_streak", q.best), 0, y + 158, 13, "sans", "center", w)
  local bw = 170
  if ui.button(TR("again"), cx - bw - 8, y + 196, bw, 38, "default", "refresh") then startQuiz(q.level) end
  local nextOk = q.level < LEVELS and unlocked(q.level + 1)
  if ui.button(TR("next_level"), cx + 8, y + 196, bw, 38, "primary", "skip_next", nextOk) then startQuiz(q.level + 1) end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  if screen == "learn" then drawLearn(w, h)
  elseif screen == "quiz" and q then drawQuiz(w, h)
  elseif screen == "result" and q then drawResult(w, h)
  elseif screen == "stats" then drawStats(w, h)
  else screen = "map"; drawMap(w, h) end
  for _, p in ipairs(parts) do
    gfx.color(p.c)
    gfx.poly({p.x + math.cos(p.r) * 5, p.y + math.sin(p.r) * 5, p.x + math.cos(p.r + 2.1) * 5, p.y + math.sin(p.r + 2.1) * 5,
      p.x + math.cos(p.r + 3.8) * 5, p.y + math.sin(p.r + 3.8) * 5})
  end
  if flash > 0 and flashColor then
    gfx.alpha(flash)
    gfx.color(flashColor)
    gfx.rectLine(2, 2, w - 4, h - 4, 12, 6)
    gfx.unalpha()
  end
end

function app.event(e)
  if e.type == "keydown" then
    local k = e.key
    if k == "escape" then screen = "map"
    elseif screen == "quiz" and q then
      if typed then
        if #k == 1 and k:match("%d") then typeDigit(k)
        elseif k == "backspace" then backspace()
        elseif k == "enter" then submitTyped() end
      else
        local n = tonumber(k)
        if n and n >= 1 and n <= 4 and q.cur.choices[n] then answer(q.cur.choices[n]) end
      end
    elseif screen == "learn" then
      if k == "left" then learnTable = math.max(1, learnTable - 1); revealed = {}
      elseif k == "right" then learnTable = math.min(10, learnTable + 1); revealed = {}
      elseif k == "space" or k == "enter" then for r = 1, 10 do revealed[r] = true end end
    elseif screen == "result" and q then
      if k == "enter" then startQuiz(q.level) end
    end
  end
end

function app.menu()
  return {{title = TR("app_name"), items = {
    {label = TR("levels"), id = 1, shortcut = "Esc"},
    {label = TR("learn"), id = 2},
    {label = TR("stats"), id = 6},
    "-",
    {label = TR("mode_choice"), id = 3},
    {label = TR("mode_typed"), id = 4},
    "-",
    {label = TR("reset_progress"), id = 5},
  }}}
end

function app.onmenu(id)
  if id == 1 then screen = "map"
  elseif id == 2 then screen = "learn"; revealed = {}
  elseif id == 6 then screen, anim = "stats", 0
  elseif id == 3 then typed = false; store.set("typed", false)
  elseif id == 4 then typed = true; store.set("typed", true)
  elseif id == 5 then
    ui.alert(TR("reset_progress"), TR("reset_msg"), {TR("reset"), TR("common.cancel")}, function(b)
      if b == 1 then
        stars, acc, streakBest = {}, {}, 0
        store.set("stars", stars); store.set("acc", acc); store.set("streakBest", 0); screen = "map"
      end
    end)
  end
end

function app.close()
  store.save()
  return true
end

return app
