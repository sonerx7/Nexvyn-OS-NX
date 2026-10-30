-- Roman Numerals: a live two-way converter (1–3999) with strict validation and a step-by-step breakdown, a
-- reference of the symbols and rules, and a quiz with three levels, streaks and a saved best. Nexvyn OS Lua SDK.
local app = {}

local floor, min, max, abs = math.floor, math.min, math.max, math.abs

-- ------------------------------------------------------------------ roman numerals
local PARTS = {{1000, "M"}, {900, "CM"}, {500, "D"}, {400, "CD"}, {100, "C"}, {90, "XC"},
               {50, "L"}, {40, "XL"}, {10, "X"}, {9, "IX"}, {5, "V"}, {4, "IV"}, {1, "I"}}
local VAL = {I = 1, V = 5, X = 10, L = 50, C = 100, D = 500, M = 1000}
local GOOD_SUB = {IV = true, IX = true, XL = true, XC = true, CD = true, CM = true}

local function toRoman(n)
  local out = {}
  for _, p in ipairs(PARTS) do
    while n >= p[1] do out[#out + 1] = p[2]; n = n - p[1] end
  end
  return table.concat(out)
end

-- one part per decimal place: 1994 → {1000,"M"}, {900,"CM"}, {90,"XC"}, {4,"IV"}; 3888 → MMM + DCCC + LXXX + VIII
local function breakdown(n)
  local out = {}
  for _, place in ipairs({1000, 100, 10, 1}) do
    local d = (n // place) % 10
    if d > 0 then out[#out + 1] = {d * place, toRoman(d * place)} end
  end
  return out
end

-- strict parser: returns value, or nil + error key + extra detail + suggestion
local function fromRoman(s)
  s = tostring(s or ""):gsub("%s", ""):upper()
  if s == "" then return nil, nil end
  local bad = s:match("[^IVXLCDM]")
  if bad then return nil, "err_chars", bad end
  -- additive/subtractive value, used for suggestions
  local v = 0
  for i = 1, #s do
    local a, b = VAL[s:sub(i, i)], VAL[s:sub(i + 1, i + 1)] or 0
    if a < b then v = v - a else v = v + a end
  end
  local canon = (v >= 1 and v <= 3999) and toRoman(v) or nil
  if canon == s then return v end
  -- explain what is wrong
  local err, detail = "err_order", nil
  local run = s:match("IIII") or s:match("XXXX") or s:match("CCCC") or s:match("MMMM")
  if run then err, detail = "err_repeat", run:sub(1, 1)
  else
    for _, c in ipairs({"V", "L", "D"}) do
      local _, n = s:gsub(c, "")
      if n > 1 then err, detail = "err_vld", c; break end
    end
    if err == "err_order" then
      for i = 1, #s - 1 do
        local pair = s:sub(i, i + 1)
        if VAL[pair:sub(1, 1)] < VAL[pair:sub(2, 2)] and not GOOD_SUB[pair] then err, detail = "err_sub", pair; break end
      end
    end
  end
  if v > 3999 then return nil, "err_range", nil, nil end
  return nil, err, detail, canon
end

-- ------------------------------------------------------------------ helpers
local function ease(cur, target, dt, speed)
  local n = cur + (target - cur) * min(1, dt * (speed or 10))
  if abs(target - n) < 0.002 then n = target end
  return n
end

local ccache = {}
local function withAlpha(c, a)
  local key = tostring(c) .. a
  local t = ccache[key]
  if not t then
    t = {tonumber(c:sub(2, 3), 16) or 0, tonumber(c:sub(4, 5), 16) or 0, tonumber(c:sub(6, 7), 16) or 0, floor(255 * a)}
    ccache[key] = t
  end
  return t
end

-- ------------------------------------------------------------------ state
local tab, tabAnim = 1, 1
local numText, romText = "1994", "MCMXCIV"
local value = 1994           -- the converter's current valid value (nil when the edited field is invalid)
local numErr, romErr = nil, nil
local parts = breakdown(1994)
local popAt = -10            -- when the breakdown last changed (chips animate in)
local toast, toastAt = nil, -10

-- quiz
local LEVELS = {50, 500, 3999}
local level = 1
local q = nil                -- {n = number, toRoman = bool}
local answer = ""
local result = nil           -- nil while answering, else {ok = bool, at = time}
local score, asked, streak, best = 0, 0, 0, 0
local lifeOk, lifeAll = 0, 0
local ring = 0               -- eased accuracy ring
local newBestAt = -10

local function say(text) toast, toastAt = text, sys.time() end

local function setTab(t)
  if t >= 1 and t <= 3 and t ~= tab then tab = t; store.set("tab", t) end
end

local function setValue(v)
  if v ~= value then
    value = v
    parts = v and breakdown(v) or {}
    popAt = sys.time()
  end
end

-- the user typed into one field: validate it and fill in the other
local function onNumber(t)
  numText = t
  store.set("num", t)
  local s = t:gsub("%s", "")
  if s == "" then numErr = nil; romErr = nil; romText = ""; setValue(nil); return end
  local v = tonumber(s)
  if not v or v ~= floor(v) then numErr = "err_whole"; setValue(nil); return end
  if v < 1 or v > 3999 then numErr = "err_range"; setValue(nil); return end
  numErr, romErr = nil, nil
  romText = toRoman(v)
  store.set("rom", romText)
  setValue(v)
end

local romDetail, romSuggest = nil, nil
local function onRoman(t)
  romText = t
  store.set("rom", t)
  local v, err, detail, sug = fromRoman(t)
  romDetail, romSuggest = detail, sug
  if not v then
    romErr = err
    if not err then numText = ""; numErr = nil end
    setValue(nil)
    return
  end
  romErr, numErr = nil, nil
  numText = tostring(v)
  store.set("num", numText)
  setValue(v)
end

local function copyResult()
  if not value then say(TR("nothing_copy")); return end
  local names = {}
  for i, p in ipairs(parts) do names[i] = p[2] end
  local nums = {}
  for i, p in ipairs(parts) do nums[i] = tostring(p[1]) end
  sys.clipboard(value .. " = " .. toRoman(value) .. "\n" .. value .. " = " .. table.concat(names, " + ") ..
                " = " .. table.concat(nums, " + ") .. "\n")
  say(TR("copied"))
  audio.play("pop")
end

-- quiz flow
local function newQuestion()
  local hi = LEVELS[level] or 50
  local n = math.random(1, hi)
  if q and n == q.n then n = n % hi + 1 end
  q = {n = n, toRoman = math.random() < 0.5}
  answer = ""
  result = nil
end

local function checkAnswer()
  if not q then newQuestion() end
  if result then return end
  local a = answer:gsub("%s", "")
  if a == "" then say(TR("type_answer")); return end
  local ok
  if q.toRoman then ok = a:upper() == toRoman(q.n) else ok = tonumber(a) == q.n end
  asked, lifeAll = asked + 1, lifeAll + 1
  if ok then
    score, streak, lifeOk = score + 1, streak + 1, lifeOk + 1
    audio.tone(660 + min(streak, 10) * 40, 0.12, 0.35, "sine")
    if streak > best then
      best = streak
      store.set("best", best)
      if best >= 3 then newBestAt = sys.time() end
    end
  else
    streak = 0
    audio.play("error")
  end
  store.set("lifeOk", lifeOk)
  store.set("lifeAll", lifeAll)
  result = {ok = ok, at = sys.time()}
end

local function resetScore()
  score, asked, streak = 0, 0, 0
  newQuestion()
end

-- ------------------------------------------------------------------ lifecycle
function app.load(arg)
  tab = min(3, max(1, floor(tonumber(store.get("tab", 1)) or 1)))
  tabAnim = tab
  level = min(3, max(1, floor(tonumber(store.get("level", 1)) or 1)))
  best = floor(tonumber(store.get("best", 0)) or 0)
  lifeOk = floor(tonumber(store.get("lifeOk", 0)) or 0)
  lifeAll = floor(tonumber(store.get("lifeAll", 0)) or 0)
  local n, r = store.get("num", "1994"), store.get("rom", "MCMXCIV")
  if type(n) == "string" and n ~= "" then onNumber(n)
  elseif type(r) == "string" then onRoman(r) end
  popAt = -10
  newQuestion()
end

function app.update(dt)
  tabAnim = ease(tabAnim, tab, dt, 12)
  ring = ease(ring, asked > 0 and score / asked or 0, dt, 6)
end

-- ------------------------------------------------------------------ drawing helpers
local function label(text, x, y)
  gfx.color(theme.text2)
  gfx.text(text, x, y, 13, "semibold")
end

local function card(x, y, w, h)
  gfx.shadow(x, y, w, h, 12, 10, 3)
  gfx.rect(x, y, w, h, 12, theme.control)
  gfx.color(theme.separator)
  gfx.rectLine(x, y, w, h, 12, 1)
end

local function errText(key, detail, sug)
  if key == "err_chars" then return TR("err_chars", detail or "?")
  elseif key == "err_repeat" then return TR("err_repeat", detail or "?")
  elseif key == "err_vld" then return TR("err_vld", detail or "?")
  elseif key == "err_sub" then return TR("err_sub", detail or "?")
  elseif key == "err_range" then return TR("err_range")
  elseif key == "err_whole" then return TR("err_whole") end
  return TR("err_order")
end

-- ------------------------------------------------------------------ converter
local function drawConvert(w, h)
  local m = 20
  local x, y, cw = m, 60, w - 2 * m
  local fw = (cw - 44) / 2
  label(TR("number"), x, y)
  label(TR("roman"), x + fw + 44, y)
  local nt = ui.textfield("num", numText, x, y + 20, fw, 40, "1994", "numeric")
  if nt ~= numText then onNumber(nt) end
  gfx.icon("swap_horiz", x + fw + 22, y + 40, 24, theme.text3)
  local rt = ui.textfield("rom", romText, x + fw + 44, y + 20, fw, 40, "MCMXCIV")
  if rt ~= romText then onRoman(rt) end
  -- errors under the field that is wrong
  if numErr then
    gfx.color(theme.red)
    gfx.wrap(errText(numErr), x, y + 66, fw, 12)
  end
  if romErr then
    gfx.color(theme.red)
    local eh = gfx.wrap(errText(romErr, romDetail), x + fw + 44, y + 66, fw, 12)
    if romSuggest then
      if ui.button(TR("did_you_mean", romSuggest) .. "##sug", x + fw + 44, y + 70 + eh, fw, 28, "link") then
        onRoman(romSuggest)
      end
    end
  end

  local cy = y + 128
  local ch = h - cy - m
  card(x, cy, cw, ch)
  if not value then
    local cx, cyy = x + cw / 2, cy + ch / 2 - 18
    gfx.circle(cx, cyy, 34, withAlpha(theme.accent, 0.12))
    gfx.icon("history_edu", cx, cyy, 38, theme.accent)
    gfx.color(theme.text2)
    gfx.wrap(TR("empty_hint"), x + 30, cyy + 46, cw - 60, 13, "sans", "center")
    return
  end
  local px, pw = x + 20, cw - 40
  gfx.color(theme.text2)
  gfx.text(TR("breakdown"), px, cy + 14, 13, "semibold")
  if ui.iconButton("content_copy", x + cw - 46, cy + 10, 34, 32, theme.accent, false, "copy") then copyResult() end
  -- one chip per part, popping in one after another
  local n = #parts
  local gap = 22
  local chipW = min(112, (pw - gap * (n - 1)) / max(1, n))
  local chipH = 64
  local total = n * chipW + (n - 1) * gap
  local sx = px + (pw - total) / 2
  local chy = cy + 46
  local t = sys.time() - popAt
  for i, p in ipairs(parts) do
    local k = min(1, max(0, (t - (i - 1) * 0.06) * 5))
    local e = 1 - (1 - k) ^ 3
    local cx = sx + (i - 1) * (chipW + gap)
    gfx.alpha(e)
    gfx.push(0, (1 - e) * 12)
    gfx.rect(cx, chy, chipW, chipH, 10, withAlpha(theme.accent, 0.14))
    gfx.color(theme.accent)
    local fs = chipW < 46 and 15 or 22
    gfx.text(p[2], cx, chy + 8, fs, "bold", "center", chipW)
    gfx.color(theme.text2)
    gfx.text(tostring(p[1]), cx, chy + 40, chipW < 46 and 11 or 13, "medium", "center", chipW)
    gfx.pop()
    gfx.unalpha()
    if i < n then
      gfx.color(theme.text3)
      gfx.text("+", cx + chipW, chy + 20, 16, "semibold", "center", gap)
    end
  end
  -- formula lines
  local fy = chy + chipH + 18
  local names, nums = {}, {}
  if fy + 40 < cy + ch then
    for i, p in ipairs(parts) do names[i] = p[2]; nums[i] = tostring(p[1]) end
    gfx.color(theme.text)
    gfx.wrap(value .. " = " .. table.concat(names, " + "), px, fy, pw, 15, "semibold", "center")
    gfx.color(theme.text2)
    gfx.wrap("= " .. table.concat(nums, " + "), px, fy + 26, pw, 13, "sans", "center")
  end
  if fy + 80 < cy + ch then
    gfx.color(theme.accent)
    local big = toRoman(value)
    local size = 34
    while size > 16 and gfx.textWidth(big, size, "bold") > pw do size = size - 2 end
    gfx.text(big, px, cy + ch - size - 22, size, "bold", "center", pw)
  end
end

-- ------------------------------------------------------------------ reference
local SYMBOLS = {{"I", 1}, {"V", 5}, {"X", 10}, {"L", 50}, {"C", 100}, {"D", 500}, {"M", 1000}}
local SUBS = {{"IV", 4}, {"IX", 9}, {"XL", 40}, {"XC", 90}, {"CD", 400}, {"CM", 900}}

local function tiles(list, x, y, cw, th, id, tint)
  local n = #list
  local tw = (cw - 8 * (n - 1)) / n
  for i, s in ipairs(list) do
    local tx = x + (i - 1) * (tw + 8)
    local hit = ui.hit(id .. i, tx, y, tw, th)
    gfx.rect(tx, y, tw, th, 10, hit.hovered and withAlpha(tint, 0.24) or withAlpha(tint, 0.13))
    gfx.color(tint)
    gfx.text(s[1], tx, y + 8, 22, "bold", "center", tw)
    gfx.color(theme.text2)
    gfx.text(tostring(s[2]), tx, y + th - 22, 13, "medium", "center", tw)
    if hit.clicked then onNumber(tostring(s[2])); setTab(1) end
  end
end

local function drawReference(w, h)
  local m = 20
  local x, y, cw = m, 60, w - 2 * m
  label(TR("symbols"), x, y)
  tiles(SYMBOLS, x, y + 20, cw, 64, "sym", theme.accent)
  y = y + 98
  label(TR("subtractive"), x, y)
  tiles(SUBS, x, y + 20, cw, 64, "sub", theme.purple)
  y = y + 98
  label(TR("rules"), x, y)
  local rh = h - y - 20 - m
  card(x, y + 20, cw, rh)
  -- the rules scroll when the window is short
  local rules = {TR("rule1"), TR("rule2"), TR("rule3"), TR("rule4")}
  local tw = cw - 60
  local total = 14
  for _, r in ipairs(rules) do total = total + max(22, gfx.measureWrap(r, tw, 13)) + 8 end
  ui.beginScroll("rules", x + 1, y + 21, cw - 2, rh - 2, total)
  local ry = 12
  for i, r in ipairs(rules) do
    gfx.circle(21, ry + 8, 9, withAlpha(theme.accent, 0.16))
    gfx.color(theme.accent)
    gfx.text(tostring(i), 12, ry + 1, 11, "bold", "center", 18)
    gfx.color(theme.text)
    local hh = gfx.wrap(r, 40, ry, tw, 13)
    ry = ry + max(22, hh) + 8
  end
  ui.endScroll()
end

-- ------------------------------------------------------------------ quiz
local function drawQuiz(w, h)
  local m = 20
  local x, y, cw = m, 60, w - 2 * m
  local nl = ui.segmented("level", {TR("easy"), TR("medium"), TR("hard")}, level, x, y, min(330, cw - 150), 30)
  if nl ~= level and nl >= 1 and nl <= 3 then level = nl; store.set("level", nl); newQuestion() end
  if ui.button(TR("skip"), x + cw - 120, y, 120, 30, "default", "skip_next") then
    if not result then streak = 0 end
    newQuestion()
  end
  y = y + 46
  -- score ring on the right, question card on the left
  local rw = 150
  local qw = cw - rw - 16
  local qh = h - y - m
  card(x, y, qw, qh)
  if not q then newQuestion() end
  local px, pw = x + 20, qw - 40
  gfx.color(theme.text2)
  gfx.text(q.toRoman and TR("q_to_roman") or TR("q_to_number"), px, y + 16, 13, "semibold")
  local qs = q.toRoman and tostring(q.n) or toRoman(q.n)
  local size = 40
  while size > 18 and gfx.textWidth(qs, size, "bold") > pw do size = size - 2 end
  gfx.color(theme.text)
  gfx.text(qs, px, y + 40, size, "bold", "center", pw)
  local ay = y + 104
  local nt = ui.textfield("answer", answer, px, ay, pw - 112, 38, q.toRoman and "XLII" or "42", not q.toRoman and "numeric" or nil)
  if not result then answer = nt end
  if not result then
    if ui.button(TR("check"), px + pw - 104, ay, 104, 38, "primary", "check") then checkAnswer() end
  else
    if ui.button(TR("next"), px + pw - 104, ay, 104, 38, "primary", "arrow_forward") then newQuestion() end
  end
  if result then
    local age = sys.time() - result.at
    local e = 1 - (1 - min(1, age * 5)) ^ 3
    local by = ay + 50
    gfx.alpha(e)
    gfx.push(0, (1 - e) * 10)
    local col = result.ok and theme.green or theme.red
    gfx.rect(px, by, pw, 44, 10, withAlpha(col, 0.15))
    gfx.icon(result.ok and "check_circle" or "cancel", px + 22, by + 22, 22, col)
    gfx.color(col)
    local ans = q.toRoman and toRoman(q.n) or tostring(q.n)
    local msg = result.ok and TR("correct") or TR("wrong", ans)
    if gfx.textWidth(msg, 13, "semibold") > pw - 52 then gfx.wrap(msg, px + 42, by + 5, pw - 52, 13, "semibold")
    else gfx.text(msg, px + 42, by + 13, 13, "semibold") end
    gfx.pop()
    gfx.unalpha()
  end
  gfx.color(theme.text3)
  gfx.wrap(TR("quiz_hint"), px, y + qh - 34, pw, 12)

  -- score panel
  local sx = x + qw + 16
  card(sx, y, rw, qh)
  local rcx, rcy, rr = sx + rw / 2, y + 64, 44
  gfx.color(theme.separator)
  gfx.arc(rcx, rcy, rr, 0, math.pi * 2, 9)
  if ring > 0.001 then
    gfx.color(theme.green)
    gfx.arc(rcx, rcy, rr, -math.pi / 2, -math.pi / 2 + math.pi * 2 * ring, 9)
  end
  gfx.color(theme.text)
  gfx.text(score .. "/" .. asked, sx, rcy - 12, 18, "bold", "center", rw)
  gfx.color(theme.text3)
  gfx.text(TR("accuracy"), sx, rcy + 10, 11, "sans", "center", rw)
  local ly = rcy + rr + 20
  local items = {{TR("streak"), tostring(streak), "local_fire_department"}, {TR("best"), tostring(best), "emoji_events"},
                 {TR("all_time"), lifeOk .. "/" .. lifeAll, "history"}}
  for i, it in ipairs(items) do
    local iy = ly + (i - 1) * 44
    if iy + 36 <= y + qh then
      gfx.icon(it[3], sx + 24, iy + 16, 20, i == 2 and theme.yellow or theme.accent)
      gfx.color(theme.text2)
      gfx.text(it[1], sx + 42, iy, 11)
      gfx.color(theme.text)
      gfx.text(it[2], sx + 42, iy + 14, 16, "semibold")
    end
  end
  -- a short celebration when a new best streak is set
  local ca = sys.time() - newBestAt
  if ca < 1.6 then
    local a = 1 - ca / 1.6
    for i = 1, 12 do
      local ang = i / 12 * math.pi * 2
      local d = 20 + ca * 90
      gfx.circle(rcx + math.cos(ang) * d, rcy + math.sin(ang) * d, 4 * a + 1,
        withAlpha(i % 3 == 0 and theme.yellow or (i % 3 == 1 and theme.green or theme.accent), a))
    end
    gfx.color(theme.yellow)
    gfx.text(TR("new_best"), sx, y + 8, 12, "bold", "center", rw)
  end
end

-- ------------------------------------------------------------------ frame
local function drawToast(w, h)
  if not toast then return end
  local age = sys.time() - toastAt
  if age > 2.2 then toast = nil; return end
  local a = min(1, age * 6, (2.2 - age) * 3)
  local tw = gfx.textWidth(toast, 13) + 32
  local tx, ty = (w - tw) / 2, h - 56 - (1 - min(1, age * 6)) * 10
  gfx.alpha(a)
  gfx.shadow(tx, ty, tw, 32, 16, 10, 3)
  gfx.rect(tx, ty, tw, 32, 16, theme.dark and "#3A3A3C" or "#1C1C1E")
  gfx.color("#FFFFFF")
  gfx.text(toast, tx, ty + 8, 13, "medium", "center", tw)
  gfx.unalpha()
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local sw = min(w - 40, 390)
  setTab(ui.segmented("tabs", {TR("tab_convert"), TR("tab_ref"), TR("tab_quiz")}, tab, (w - sw) / 2, 14, sw, 30))
  local off = (tab - tabAnim) * 40
  gfx.alpha(1 - min(1, abs(tab - tabAnim)) * 0.8)
  gfx.push(off, 0)
  if tab == 1 then drawConvert(w, h) elseif tab == 2 then drawReference(w, h) else drawQuiz(w, h) end
  gfx.pop()
  gfx.unalpha()
  drawToast(w, h)
end

function app.event(e)
  if e.type ~= "keydown" then return end
  if e.ctrl and (e.key == "1" or e.key == "2" or e.key == "3") then setTab(tonumber(e.key))
  elseif e.key == "pageup" then setTab(tab == 1 and 3 or tab - 1)
  elseif e.key == "pagedown" then setTab(tab % 3 + 1)
  elseif e.ctrl and e.key == "c" and tab == 1 then copyResult()
  elseif e.key == "enter" and tab == 3 then
    if result then newQuestion(); ui.focus("answer") else checkAnswer() end
  end
end

function app.menu()
  return {
    {title = TR("app_name"), items = {
      {label = TR("tab_convert"), id = 1, shortcut = "Ctrl+1"},
      {label = TR("tab_ref"), id = 2, shortcut = "Ctrl+2"},
      {label = TR("tab_quiz"), id = 3, shortcut = "Ctrl+3"},
      "-",
      {label = TR("copy"), id = 4, shortcut = "Ctrl+C"},
    }},
    {title = TR("tab_quiz"), items = {
      {label = TR("check_next"), id = 5, shortcut = "Enter"},
      {label = TR("skip"), id = 6},
      "-",
      {label = TR("reset_score"), id = 7},
    }},
  }
end

function app.onmenu(id)
  if id >= 1 and id <= 3 then setTab(id)
  elseif id == 4 then copyResult()
  elseif id == 5 then setTab(3); if result then newQuestion() else checkAnswer() end
  elseif id == 6 then setTab(3); newQuestion()
  elseif id == 7 then
    ui.alert(TR("reset_score"), TR("reset_msg"), {TR("reset"), TR("common.cancel")}, function(b)
      if b == 1 then
        resetScore()
        best, lifeOk, lifeAll = 0, 0, 0
        store.set("best", 0); store.set("lifeOk", 0); store.set("lifeAll", 0)
      end
    end)
  end
end

function app.close()
  store.save()
  return true
end

return app
