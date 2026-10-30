-- Typing Tutor for Nexvyn OS: row drills, Turkish characters and real sentences with live WPM and accuracy.
local app = {}

local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi
local LES = require("lessons")

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
local WHITE = "#FFFFFF"

local function chars(s)
  local t = {}
  for _, c in utf8.codes(s) do t[#t + 1] = utf8.char(c) end
  return t
end

local TR_LOWER = {["I"] = "ı", ["İ"] = "i", ["Ç"] = "ç", ["Ğ"] = "ğ", ["Ö"] = "ö", ["Ş"] = "ş", ["Ü"] = "ü"}
local TR_UPPER = {["i"] = "İ", ["ı"] = "I", ["ç"] = "Ç", ["ğ"] = "Ğ", ["ö"] = "Ö", ["ş"] = "Ş", ["ü"] = "Ü"}
local function upperChar(ch, tr) return (tr and TR_UPPER[ch]) or (#ch == 1 and ch:upper() or ch) end

local function lowerChar(ch, tr)
  if tr and TR_LOWER[ch] then return TR_LOWER[ch] end
  if not tr and (ch == "İ") then return "i" end
  return #ch == 1 and ch:lower() or ch
end

-- ------------------------------------------------------------------ lessons
local lang = "en"
local LESSONS = {
  {id = "home", name = "les_home", desc = "les_home_d", icon = "keyboard", color = "blue"},
  {id = "top", name = "les_top", desc = "les_top_d", icon = "keyboard_arrow_up", color = "purple"},
  {id = "bottom", name = "les_bottom", desc = "les_bottom_d", icon = "keyboard_arrow_down", color = "pink"},
  {id = "numbers", name = "les_numbers", desc = "les_numbers_d", icon = "pin", color = "orange"},
  {id = "turkish", name = "les_turkish", desc = "les_turkish_d", icon = "translate", color = "red"},
  {id = "sent_tr", name = "les_sent_tr", desc = "les_sent_tr_d", icon = "notes", color = "green"},
  {id = "sent_en", name = "les_sent_en", desc = "les_sent_en_d", icon = "short_text", color = "yellow"},
}

local function drill(letters, groups, lo, hi)
  local set = chars(letters)
  local out = {}
  for i = 1, groups do
    local n = math.random(lo, hi)
    local w = {}
    for j = 1, n do w[j] = set[math.random(#set)] end
    out[i] = table.concat(w)
  end
  return table.concat(out, " ")
end

local function pick(list, n)
  local idx = {}
  for i = 1, #list do idx[i] = i end
  for i = #idx, 2, -1 do
    local j = math.random(i)
    idx[i], idx[j] = idx[j], idx[i]
  end
  local out = {}
  for i = 1, min(n, #list) do out[i] = list[idx[i]] end
  return out
end

local function lessonText(id)
  local rows = LES.rows[lang]
  if id == "home" or id == "top" or id == "bottom" then return drill(rows[id], 12, 3, 5)
  elseif id == "numbers" then return drill(rows.numbers, 12, 2, 4)
  elseif id == "turkish" then return table.concat(pick(LES.turkishWords, 10), " ")
  elseif id == "sent_tr" then return table.concat(pick(LES.sentences.tr, 2), " ")
  else return table.concat(pick(LES.sentences.en, 2), " ") end
end

-- ------------------------------------------------------------------ state
local view = "home"          -- home | run
local tab = 1                -- home tabs: lessons / results
local history = {}           -- {lesson, wpm, acc, secs, t}
local best = {}              -- lesson id -> {wpm, acc}
local run = nil
local viewT = 1
local gotText = false
local editing = false
local fieldRect = {0, 0, 0, 0}
local homeSel = 0

local function saveAll()
  store.set("history", history)
  store.set("best", best)
  store.save()
end

local function lessonById(id)
  for i, l in ipairs(LESSONS) do if l.id == id then return l, i end end
end

local function startLesson(id)
  local text = lessonText(id)
  run = {id = id, chars = chars(text), typed = {}, errAt = {}, keys = 0, errors = 0, startT = nil, endT = nil,
         done = false, caretX = 0, caretY = 0, shake = 0, newBest = false}
  view = "run"
  viewT = 0
  audio.play("pop")
end

local function elapsed()
  if not run or not run.startT then return 0 end
  return (run.endT or sys.time()) - run.startT
end

local function correctCount()
  local c = 0
  for i, ch in ipairs(run.typed) do if ch == run.chars[i] then c = c + 1 end end
  return c
end

local function liveWPM()
  local t = elapsed()
  if t < 1 then return 0 end
  return floor(correctCount() / 5 / (t / 60) + 0.5)
end

local function liveAcc()
  if run.keys == 0 then return 100 end
  return floor((run.keys - run.errors) / run.keys * 100 + 0.5)
end

local function finish()
  run.done = true
  run.endT = sys.time()
  local wpm, acc = liveWPM(), liveAcc()
  run.wpm, run.acc = wpm, acc
  local b = best[run.id]
  if not b or wpm > (b.wpm or 0) or (wpm == (b.wpm or 0) and acc > (b.acc or 0)) then
    best[run.id] = {wpm = wpm, acc = acc}
    run.newBest = b ~= nil
  end
  table.insert(history, 1, {lesson = run.id, wpm = wpm, acc = acc, secs = floor(elapsed() + 0.5), t = sys.epoch()})
  while #history > 60 do table.remove(history) end
  saveAll()
  audio.play("notify")
end

local function typeChar(ch)
  if not run or run.done then return end
  local pos = #run.typed + 1
  local target = run.chars[pos]
  if not target then return end
  if not run.startT then run.startT = sys.time() end
  run.keys = run.keys + 1
  if ch ~= target then
    run.errors = run.errors + 1
    run.errAt[pos] = true
    run.shake = 1
    audio.tone(220, 0.06, 0.18, "square")
  else
    audio.play("key", 0.35)
  end
  run.typed[pos] = ch
  if pos == #run.chars then finish() end
end

local function backspace()
  if not run or run.done or #run.typed == 0 then return end
  run.typed[#run.typed] = nil
end

local function feed(s)
  for _, c in utf8.codes(s) do
    local ch = utf8.char(c)
    if ch ~= "\n" and ch ~= "\r" then typeChar(ch) end
  end
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  lang = sys.lang() == "tr" and "tr" or "en"
  local h = store.get("history", {})
  history = {}
  if type(h) == "table" then
    for _, e in ipairs(h) do
      if type(e) == "table" and tonumber(e.wpm) and type(e.lesson) == "string" then history[#history + 1] = e end
    end
  end
  local b = store.get("best", {})
  best = {}
  if type(b) == "table" then
    for k, v in pairs(b) do if type(v) == "table" then best[tostring(k)] = v end end
  end
end

function app.update(dt)
  viewT = approach(viewT, 1, 10, dt)
  if run then run.shake = max(0, run.shake - dt * 5) end
end

-- ------------------------------------------------------------------ drawing: home
local function statCard(x, y, w, h, icon, color, value, label)
  gfx.rect(x, y, w, h, 12, theme.dark and "#FFFFFF0F" or "#0000000A")
  gfx.circle(x + 26, y + h / 2, 16, fade(color, 0.16))
  gfx.icon(icon, x + 26, y + h / 2, 18, color)
  gfx.color(theme.text)
  gfx.text(value, x + 52, y + h / 2 - 17, 20, "bold")
  gfx.color(theme.text2)
  gfx.text(label, x + 52, y + h / 2 + 6, 12)
end

local function drawLessons(w, h)
  local top = 64
  local cols = 2
  local gap = 14
  local cw = floor((w - 40 - gap) / cols)
  local ch = 92
  local rows = math.ceil(#LESSONS / cols)
  ui.beginScroll("lessons", 0, top, w, h - top - 8, rows * (ch + gap) + 4)
  for i, l in ipairs(LESSONS) do
    local c = (i - 1) % cols
    local r = floor((i - 1) / cols)
    local x, y = 20 + c * (cw + gap), 2 + r * (ch + gap)
    local col = theme[l.color]
    local hit = ui.hit("les" .. l.id, x, y, cw, ch)
    if hit.hovered then gfx.shadow(x, y, cw, ch, 12, 12, 3) end
    gfx.rect(x, y, cw, ch, 12, theme.dark and "#2A2A2D" or "#FFFFFF")
    gfx.color(homeSel == i and theme.accent or theme.separator)
    gfx.rectLine(x, y, cw, ch, 12, homeSel == i and 2 or 1)
    gfx.rect(x + 16, y + 18, 44, 44, 11, fade(col, 0.16))
    gfx.icon(l.icon, x + 38, y + 40, 24, col)
    gfx.color(theme.text)
    gfx.text(TR(l.name), x + 74, y + 16, 15, "semibold")
    gfx.color(theme.text2)
    gfx.clip(x + 74, y + 36, cw - 90, 20)
    gfx.text(TR(l.desc), x + 74, y + 38, 12)
    gfx.unclip()
    local b = best[l.id]
    if b then
      gfx.icon("emoji_events", x + 82, y + 70, 14, theme.orange)
      gfx.color(theme.text2)
      gfx.text(TR("best_fmt", b.wpm, b.acc), x + 94, y + 63, 12, "medium")
    else
      gfx.color(theme.text3)
      gfx.text(TR("not_tried"), x + 74, y + 63, 12)
    end
    gfx.icon("chevron_right", x + cw - 22, y + ch / 2, 22, theme.text3)
    if hit.clicked then homeSel = i; startLesson(l.id) end
  end
  ui.endScroll()
end

local function fmtDate(e)
  local d = sys.date(e)
  return string.format("%02d.%02d.%04d %02d:%02d", d.day, d.month, d.year, d.hour, d.min)
end

local function drawResults(w, h)
  local y = 64
  if #history == 0 then
    gfx.icon("insights", w / 2, h / 2 - 30, 44, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("no_results"), 0, h / 2 + 4, 15, "medium", "center", w)
    gfx.color(theme.text3)
    gfx.text(TR("no_results_hint"), 0, h / 2 + 28, 13, "sans", "center", w)
    return
  end
  local bestW, sumAcc, n = 0, 0, #history
  for _, e in ipairs(history) do
    bestW = max(bestW, e.wpm or 0)
    sumAcc = sumAcc + (e.acc or 0)
  end
  local cw = floor((w - 40 - 24) / 3)
  statCard(20, y, cw, 64, "speed", theme.blue, TR("wpm_n", bestW), TR("best_speed"))
  statCard(20 + cw + 12, y, cw, 64, "gps_fixed", theme.green, "%" .. floor(sumAcc / n + 0.5), TR("avg_accuracy"))
  statCard(20 + (cw + 12) * 2, y, cw, 64, "history", theme.purple, tostring(n), TR("sessions"))
  -- WPM trend (oldest left)
  local gy = y + 80
  local gh = 120
  gfx.rect(20, gy, w - 40, gh, 12, theme.dark and "#FFFFFF0A" or "#00000008")
  gfx.color(theme.text2)
  gfx.text(TR("trend"), 34, gy + 10, 12, "semibold")
  local cnt = min(20, n)
  if cnt >= 2 then
    local maxW, minW = 0, 1e9
    for i = 1, cnt do
      maxW = max(maxW, history[i].wpm or 0)
      minW = min(minW, history[i].wpm or 0)
    end
    local lo = max(0, minW - 5)
    maxW = max(maxW + 2, lo + 10)
    local px, pw = 40, w - 80
    local py, ph = gy + 34, gh - 46
    local pts = {}
    for i = cnt, 1, -1 do
      local k = (cnt - i) / (cnt - 1)
      local v = history[i].wpm or 0
      pts[#pts + 1] = px + k * pw
      pts[#pts + 1] = py + ph - ph * (v - lo) / (maxW - lo)
    end
    gfx.color(theme.accent)
    gfx.lines(pts, 2.5)
    for i = 1, #pts, 2 do gfx.circle(pts[i], pts[i + 1], 3.5, theme.accent) end
    gfx.color(theme.text3)
    gfx.text(tostring(maxW), 0, py - 6, 10, "sans", "right", px - 6)
    gfx.text(tostring(lo), 0, py + ph - 6, 10, "sans", "right", px - 6)
  end
  -- list
  local ly = gy + gh + 14
  local rowH = 38
  ui.beginScroll("hist", 20, ly, w - 40, h - ly - 10, #history * rowH)
  for i, e in ipairs(history) do
    local yy = (i - 1) * rowH
    if i > 1 then ui.separator(10, yy, w - 50) end
    local l = lessonById(e.lesson)
    if l then gfx.icon(l.icon, 18, yy + rowH / 2, 18, theme[l.color]) end
    gfx.color(theme.text)
    gfx.text(l and TR(l.name) or e.lesson, 38, yy + 11, 13.5, "medium")
    gfx.color(theme.text3)
    gfx.text(fmtDate(e.t or 0), 260, yy + 12, 12)
    gfx.color(theme.text)
    gfx.text(TR("wpm_n", e.wpm or 0), w - 260, yy + 11, 13.5, "semibold", "right", 80)
    gfx.color((e.acc or 0) >= 95 and theme.green or ((e.acc or 0) >= 85 and theme.orange or theme.red))
    gfx.text("%" .. (e.acc or 0), w - 170, yy + 11, 13.5, "semibold", "right", 60)
    gfx.color(theme.text2)
    gfx.text(string.format("%d:%02d", (e.secs or 0) // 60, (e.secs or 0) % 60), w - 100, yy + 11, 13, "mono", "right", 50)
  end
  ui.endScroll()
end

local function drawHome(w, h)
  gfx.color(theme.text)
  gfx.text(TR("title"), 20, 18, 22, "bold")
  local nt = ui.segmented("hometab", {TR("tab_lessons"), TR("tab_results")}, tab, w - 280, 16, 260, 30)
  if nt ~= tab then tab = nt; audio.play("click") end
  if tab == 1 then drawLessons(w, h) else drawResults(w, h) end
end

-- ------------------------------------------------------------------ drawing: run
local FONT, SIZE = "mono", 24

local function layoutLines(cs, maxChars)
  local lines = {}
  local i = 1
  local n = #cs
  while i <= n do
    local last = min(n, i + maxChars - 1)
    if last < n then
      -- break after the last space within the line
      local brk = nil
      for k = last, i, -1 do if cs[k] == " " then brk = k break end end
      if brk then last = brk end
    end
    lines[#lines + 1] = {i, last}
    i = last + 1
  end
  return lines
end

local function drawKeyboard(x, y, w, nextCh)
  local rows = LES.keyboard[lang]
  local key = nextCh and lowerChar(nextCh, lang == "tr") or nil
  local needShift = nextCh and nextCh ~= key and nextCh ~= " "
  local kw = floor((w - 13 * 4) / 13.5)
  local kh = 30
  for r, row in ipairs(rows) do
    local cs = chars(row)
    local ox = x + (r - 1) * kw * 0.45
    local yy = y + (r - 1) * (kh + 4)
    for i, ch in ipairs(cs) do
      local kx = ox + (i - 1) * (kw + 4)
      local hl = key == ch
      gfx.rect(kx, yy, kw, kh, 6, hl and theme.accent or (theme.dark and "#FFFFFF14" or "#0000000D"))
      gfx.color(hl and WHITE or theme.text2)
      gfx.text(upperChar(ch, lang == "tr"), kx, yy + 7, 13, "medium", "center", kw)
    end
    if r == 4 then
      local sx = ox - kw * 1.4 - 4
      gfx.rect(sx, yy, kw * 1.4, kh, 6, needShift and theme.accent or (theme.dark and "#FFFFFF14" or "#0000000D"))
      gfx.icon("arrow_upward", sx + kw * 0.7, yy + kh / 2, 16, needShift and WHITE or theme.text3)
    end
  end
  local sy = y + 4 * (kh + 4)
  local sw = kw * 6
  local sx = x + (w - sw) / 2 - kw
  local hl = nextCh == " "
  gfx.rect(sx, sy, sw, kh, 6, hl and theme.accent or (theme.dark and "#FFFFFF14" or "#0000000D"))
  gfx.color(hl and WHITE or theme.text3)
  gfx.text(TR("space_key"), sx, sy + 7, 12, "medium", "center", sw)
end

local function drawRun(w, h)
  local l = lessonById(run.id)
  if ui.iconButton("arrow_back", 14, 16, 34, 32, theme.text2, false, "back") then view = "home"; viewT = 0; audio.play("click") end
  gfx.color(theme.text)
  gfx.text(l and TR(l.name) or "", 54, 18, 20, "bold")
  if ui.button(TR("restart") .. "##r", w - 150, 16, 130, 30, "default", "restart_alt") then startLesson(run.id) end
  -- live stats
  local y = 62
  local cw = floor((w - 40 - 36) / 4)
  local progress = #run.typed / max(1, #run.chars)
  statCard(20, y, cw, 56, "speed", theme.blue, TR("wpm_n", run.done and run.wpm or liveWPM()), TR("speed"))
  statCard(20 + (cw + 12), y, cw, 56, "gps_fixed", theme.green, "%" .. (run.done and run.acc or liveAcc()), TR("accuracy"))
  local t = floor(elapsed())
  statCard(20 + (cw + 12) * 2, y, cw, 56, "timer", theme.orange, string.format("%d:%02d", t // 60, t % 60), TR("time"))
  statCard(20 + (cw + 12) * 3, y, cw, 56, "error_outline", theme.red, tostring(run.errors), TR("errors"))
  ui.progress(progress, 20, y + 66, w - 40, 4)
  -- text panel
  local py = y + 84
  local panelH = 170
  local shake = run.shake > 0 and sin(run.shake * 30) * 4 * run.shake or 0
  gfx.rect(20, py, w - 40, panelH, 14, theme.dark and "#2A2A2D" or "#FAFAFC")
  gfx.color(theme.separator)
  gfx.rectLine(20, py, w - 40, panelH, 14, 1)
  local cwid = gfx.textWidth("M", SIZE, FONT)
  local lh = SIZE * 1.6
  local maxChars = floor((w - 80) / cwid)
  local lines = layoutLines(run.chars, maxChars)
  local pos = #run.typed + 1
  -- scroll so the current line stays in view (3 visible lines)
  local curLine = 1
  for li, ln in ipairs(lines) do if pos >= ln[1] and pos <= ln[2] then curLine = li end end
  if pos > #run.chars then curLine = #lines end
  local firstLine = max(1, min(curLine - 1, #lines - 2))
  gfx.clip(24, py + 6, w - 48, panelH - 12)
  local tx0 = 40 + shake
  local ty0 = py + 22
  for li = firstLine, min(#lines, firstLine + 2) do
    local ln = lines[li]
    local yy = ty0 + (li - firstLine) * lh
    for i = ln[1], ln[2] do
      local ch = run.chars[i]
      local xx = tx0 + (i - ln[1]) * cwid
      if i == pos and not run.done then
        run.caretX = run.caretX == 0 and xx or approach(run.caretX, xx, 30, 1 / 60)
        run.caretY = run.caretY == 0 and yy or approach(run.caretY, yy, 30, 1 / 60)
        gfx.rect(run.caretX - 1, run.caretY - 2, cwid + 2, SIZE * 1.3, 4, fade(theme.accent, 0.22))
        gfx.rect(run.caretX, run.caretY + SIZE * 1.3 - 1, cwid, 3, 1.5, theme.accent)
      end
      local typed = run.typed[i]
      local col
      if typed then
        if typed == ch then
          col = run.errAt[i] and theme.orange or theme.text
        else
          col = theme.red
          gfx.rect(xx, yy - 1, cwid, SIZE * 1.25, 3, fade(theme.red, 0.16))
        end
      else
        col = theme.text3
      end
      gfx.color(col)
      if ch == " " then
        if typed and typed ~= ch then gfx.text("·", xx, yy, SIZE, FONT) end
      else
        gfx.text(ch, xx, yy, SIZE, FONT)
      end
    end
  end
  gfx.unclip()
  -- input field: only here to bring up the on-screen keyboard; typing is read from app.event
  local fy = py + panelH + 12
  fieldRect[1], fieldRect[2], fieldRect[3], fieldRect[4] = 20, fy, w - 40, 34
  local got = ui.textfield("typing_input", "", 20, fy, w - 40, 34, TR("tap_to_type"))
  if got ~= "" and not gotText then feed(got) end
  gfx.color(theme.text3)
  gfx.text(TR("kb_hint"), 0, fy + 40, 11.5, "sans", "center", w)
  -- keyboard diagram
  local nextCh = (not run.done) and run.chars[pos] or nil
  local kwid = min(w - 40, 620)
  drawKeyboard((w - kwid) / 2 + 30, fy + 62, kwid - 30, nextCh)
  -- results overlay
  if run.done then
    gfx.rect(0, 0, w, h, 0, {0, 0, 0, 90})
    local rw, rh = 420, 300
    local rx, ry = (w - rw) / 2, (h - rh) / 2
    gfx.shadow(rx, ry, rw, rh, 16, 30, 10)
    gfx.rect(rx, ry, rw, rh, 16, theme.dark and "#2C2C2E" or "#FFFFFF")
    gfx.icon(run.acc >= 95 and "emoji_events" or "check_circle", w / 2, ry + 44, 40, run.acc >= 95 and theme.orange or theme.green)
    gfx.color(theme.text)
    gfx.text(TR("finished"), rx, ry + 74, 20, "bold", "center", rw)
    if run.newBest then
      gfx.color(theme.orange)
      gfx.text(TR("new_record"), rx, ry + 102, 13, "semibold", "center", rw)
    end
    local items = {{TR("wpm_n", run.wpm), TR("speed")}, {"%" .. run.acc, TR("accuracy")},
                   {string.format("%d:%02d", floor(elapsed()) // 60, floor(elapsed()) % 60), TR("time")}}
    for i, it in ipairs(items) do
      local ix = rx + 20 + (i - 1) * ((rw - 40) / 3)
      gfx.color(theme.text)
      gfx.text(it[1], ix, ry + 132, 24, "bold", "center", (rw - 40) / 3)
      gfx.color(theme.text2)
      gfx.text(it[2], ix, ry + 164, 12, "sans", "center", (rw - 40) / 3)
    end
    if ui.button(TR("lessons") .. "##res", rx + 20, ry + rh - 56, 120, 36) then view = "home"; viewT = 0 end
    if ui.button(TR("again") .. "##res", rx + 150, ry + rh - 56, 120, 36, "default", "replay") then startLesson(run.id) end
    local _, idx = lessonById(run.id)
    local nextL = LESSONS[(idx or 0) % #LESSONS + 1]
    if ui.button(TR("next") .. "##res", rx + 280, ry + rh - 56, 120, 36, "primary") then startLesson(nextL.id) end
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  gfx.alpha(0.3 + 0.7 * viewT)
  gfx.push((1 - viewT) * 12, 0)
  if view == "run" and run then drawRun(w, h) else drawHome(w, h) end
  gfx.pop()
  gfx.unalpha()
  gotText = false
end

-- ------------------------------------------------------------------ input
local function inFieldRect(x, y)
  return x >= fieldRect[1] and y >= fieldRect[2] and x <= fieldRect[1] + fieldRect[3] and y <= fieldRect[2] + fieldRect[4]
end

function app.event(e)
  if e.type == "mousedown" then
    editing = view == "run" and inFieldRect(e.x, e.y)
    return
  end
  if view == "run" and run then
    if e.type == "text" then
      gotText = true
      feed(e.text)
      return
    end
    if e.type == "keydown" then
      if e.key == "backspace" then backspace()
      elseif e.key == "escape" then
        if editing then editing = false
        else view = "home"; viewT = 0 end
      elseif e.key == "tab" then startLesson(run.id)
      elseif e.key == "enter" and run.done then startLesson(run.id) end
    end
    return
  end
  if e.type == "keydown" then
    if tab == 1 then
      if e.key == "right" then homeSel = min(#LESSONS, homeSel + 1)
      elseif e.key == "left" then homeSel = max(1, homeSel - 1)
      elseif e.key == "down" then homeSel = min(#LESSONS, homeSel + 2)
      elseif e.key == "up" then homeSel = max(1, homeSel - 2)
      elseif (e.key == "enter" or e.key == "space") and LESSONS[homeSel] then startLesson(LESSONS[homeSel].id) end
    end
    if e.key == "tab" then tab = tab % 2 + 1 end
  end
end

function app.menu()
  local items = {}
  for i, l in ipairs(LESSONS) do items[#items + 1] = {label = TR(l.name), id = i} end
  items[#items + 1] = "-"
  items[#items + 1] = {label = TR("clear_results"), id = 100, enabled = #history > 0}
  return {{title = TR("menu_lessons"), items = items}}
end

function app.onmenu(id)
  if LESSONS[id] then startLesson(LESSONS[id].id)
  elseif id == 100 then
    ui.alert(TR("clear_title"), TR("clear_msg"), {TR("clear"), TR("cancel")}, function(b)
      if b == 1 then
        history, best = {}, {}
        saveAll()
        audio.play("trash")
      end
    end)
  end
end

function app.close()
  saveAll()
  return true
end

return app
