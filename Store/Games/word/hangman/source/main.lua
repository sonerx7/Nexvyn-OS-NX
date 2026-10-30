-- Adam Asmaca / Hangman for Nexvyn OS: guess the Turkish word letter by letter before the figure is complete.
-- Eight categories (40+ words each), an on-screen Turkish keyboard, one hint per word, streaks and statistics.
local K = require("kit")
local F = require("frame")
local T = require("turkish")
local CATS = require("words")
local app = {}

local floor, max, min, sin, cos, pi = math.floor, math.max, math.min, math.sin, math.cos, math.pi
local random = math.random

local MAXWRONG = 6
local ROWS = {{"A", "B", "C", "Ç", "D", "E", "F", "G", "Ğ", "H"}, {"I", "İ", "J", "K", "L", "M", "N", "O", "Ö", "P"},
              {"R", "S", "Ş", "T", "U", "Ü", "V", "Y", "Z"}}

local cat = 0                -- 0 = random category each word
local wordCat = 1
local word, letters = "", {}
local guessed = {}           -- guessed[letter] = "hit" | "miss"
local revealedAt = {}        -- per position: reveal time
local wrong, partT = 0, {}
local state = "play"         -- play | won | lost
local endT = 0
local hintUsed = false
local streak, bestStreak, score = 0, 0, 0
local stats = {}             -- stats[key] = {played, won}
local bags = {}
local cur = {x = 1, y = 1}
local catCur = {x = 1, y = 1}
local fx = K.particles()
local G = {x = 0, y = 0, w = 0, h = 0}
local keyRects = {}
local shakeT = -10
local lastGuess, lastGuessT = nil, -10

local function catStat(key)
  local s = stats[key]
  if type(s) ~= "table" then s = {played = 0, won = 0}; stats[key] = s end
  s.played, s.won = tonumber(s.played) or 0, tonumber(s.won) or 0
  return s
end

local function catName(i)
  local key = CATS[i] and CATS[i].key or "random"
  return ({animals = TR("cat_animals"), cities = TR("cat_cities"), fruits = TR("cat_fruits"),
           vegetables = TR("cat_vegetables"), jobs = TR("cat_jobs"), countries = TR("cat_countries"),
           home = TR("cat_home"), sports = TR("cat_sports"), random = TR("cat_random")})[key]
end

-- ------------------------------------------------------------------ persistence
local function saveStats()
  store.set("stats", stats)
  store.set("streak", streak)
  store.set("bestStreak", bestStreak)
  store.set("score", score)
  store.set("cat", cat)
end

local function saveGame()
  local g = {}
  for l, v in pairs(guessed) do g[#g + 1] = {l, v} end
  store.set("game", {word = word, cat = wordCat, guessed = g, wrong = wrong, hint = hintUsed, state = state})
end

local function drawWord(i)
  local bag = bags[i]
  if not bag or #bag == 0 then
    bag = {}
    for k = 1, #CATS[i].words do bag[k] = k end
    for k = #bag, 2, -1 do local j = random(k); bag[k], bag[j] = bag[j], bag[k] end
    bags[i] = bag
  end
  return CATS[i].words[table.remove(bag)]
end

local function newWord()
  wordCat = cat > 0 and cat or random(#CATS)
  word = drawWord(wordCat)
  letters = T.letters(word)
  guessed, revealedAt, partT = {}, {}, {}
  wrong, state, hintUsed = 0, "play", false
  cur.x, cur.y = 1, 1
  F.play()
  K.notes({392, 494, 587}, 0.06, 0.14)
  saveGame()
end

local function loadGame()
  local g = store.get("game")
  if type(g) ~= "table" or g.state ~= "play" or type(g.word) ~= "string" or g.word == "" then return false end
  local ci = floor(tonumber(g.cat) or 0)
  if not CATS[ci] then return false end
  wordCat, word = ci, g.word
  letters = T.letters(word)
  guessed, revealedAt, partT = {}, {}, {}
  if type(g.guessed) == "table" then
    for _, e in ipairs(g.guessed) do
      if type(e) == "table" and T.SET[e[1]] then guessed[e[1]] = e[2] == "hit" and "hit" or "miss" end
    end
  end
  wrong = K.clamp(floor(tonumber(g.wrong) or 0), 0, MAXWRONG - 1)
  for k = 1, wrong do partT[k] = -10 end
  hintUsed = g.hint == true
  state = "play"
  return true
end

-- ------------------------------------------------------------------ rules
local function solved()
  for _, l in ipairs(letters) do if guessed[l] ~= "hit" then return false end end
  return true
end

local function finish(won)
  state = won and "won" or "lost"
  endT = sys.time()
  local s = catStat(CATS[wordCat].key)
  s.played = s.played + 1
  if won then
    s.won = s.won + 1
    streak = streak + 1
    bestStreak = max(bestStreak, streak)
    score = score + (MAXWRONG - wrong) * 10 + #letters * 2 + (hintUsed and 0 or 10)
    F.winSound()
    K.rumble(0.5, 90)
    timer.after(0.2, function() F.celebrate(fx, G.x, G.y, G.w, G.h) end)
  else
    streak = 0
    F.loseSound()
    K.rumble(0.8, 200)
    local now = sys.time()
    for i = 1, #letters do if guessed[letters[i]] ~= "hit" then revealedAt[i] = now + i * 0.06 end end
  end
  saveStats()
  saveGame()
  timer.after(1.5, function() if state ~= "play" and F.scene == "play" then F.open("over") end end)
end

local function guess(l)
  if state ~= "play" or F.modal() or not T.SET[l] then return end
  local now = sys.time()
  if guessed[l] then
    -- a physical key sends both keydown and text: ignore the twin silently
    if not (lastGuess == l and now - lastGuessT < 0.2) then K.tone(200, 0.04, 0.1, "square") end
    return
  end
  lastGuess, lastGuessT = l, now
  local hit = false
  for i, x in ipairs(letters) do
    if x == l then hit = true; revealedAt[i] = now + (i % 5) * 0.05 end
  end
  if hit then
    guessed[l] = "hit"
    F.chord({523, 659}, 0.12, 0.22)
    if solved() then finish(true) end
  else
    guessed[l] = "miss"
    wrong = wrong + 1
    partT[wrong] = now
    shakeT = now
    K.tone(160, 0.18, 0.25, "square")
    K.rumble(0.35, 60)
    if wrong >= MAXWRONG then finish(false) end
  end
  saveGame()
end

local function hint()
  if state ~= "play" or F.modal() then return end
  if hintUsed then K.toast(TR("hint_used")); return end
  local pool = {}
  for _, l in ipairs(letters) do if not guessed[l] then pool[#pool + 1] = l end end
  if #pool <= 1 then K.toast(TR("hint_none")); return end
  hintUsed = true
  F.chord({660, 880, 1100}, 0.2, 0.2, "sine")
  guess(pool[random(#pool)])
end

local function setCat(i)
  cat = K.clamp(i, 0, #CATS)
  saveStats()
  newWord()
end

-- ------------------------------------------------------------------ app
function app.load()
  K.loadPrefs()
  local s = store.get("stats", {})
  stats = type(s) == "table" and s or {}
  streak = tonumber(store.get("streak", 0)) or 0
  bestStreak = tonumber(store.get("bestStreak", 0)) or 0
  score = tonumber(store.get("score", 0)) or 0
  cat = K.clamp(floor(tonumber(store.get("cat", 0)) or 0), 0, #CATS)
  if not loadGame() then newWord() end
  F.open("title")
end

function app.update(dt)
  fx:update(dt)
  local d = F.stick(dt)
  if d and F.scene == "play" and state == "play" then
    F.moveCursor(cur, F.DIRV[d][1], F.DIRV[d][2], #ROWS[1], #ROWS, true)
    cur.x = min(cur.x, #ROWS[cur.y])
  elseif d and F.scene == "cats" then
    F.moveCursor(catCur, F.DIRV[d][1], F.DIRV[d][2], 3, 3, true)
  end
end

-- ------------------------------------------------------------------ drawing
local function stroke(x1, y1, x2, y2, t0, now, th)
  local p = K.easeOut((now - t0) / 0.35)
  if p <= 0 then return end
  gfx.line(x1, y1, x1 + (x2 - x1) * p, y1 + (y2 - y1) * p, th)
end

local function drawGallows(x, y, w, h, now)
  local th = max(4, w * 0.035)
  local wood = theme.dark and "#A1887F" or "#6D4C41"
  gfx.color(wood)
  gfx.line(x + w * 0.1, y + h * 0.95, x + w * 0.7, y + h * 0.95, th)
  gfx.line(x + w * 0.25, y + h * 0.95, x + w * 0.25, y + h * 0.06, th)
  gfx.line(x + w * 0.25, y + h * 0.06, x + w * 0.68, y + h * 0.06, th)
  gfx.line(x + w * 0.25, y + h * 0.2, x + w * 0.39, y + h * 0.06, th * 0.8)
  gfx.color(theme.dark and "#D7CCC8" or "#8D6E63")
  gfx.line(x + w * 0.68, y + h * 0.06, x + w * 0.68, y + h * 0.18, th * 0.5)
  local sway = state == "lost" and sin((now - endT) * 3) * 0.05 * max(0, 1 - (now - endT) / 4) or 0
  local cx, top = x + w * 0.68, y + h * 0.18
  local hr = h * 0.08
  local col = state == "lost" and theme.red or theme.text
  gfx.push(sway * w, 0)
  gfx.color(col)
  local lw = max(3, w * 0.022)
  if wrong >= 1 then
    local p = K.easeOut((now - partT[1]) / 0.35)
    if p > 0 then gfx.arc(cx, top + hr, hr, -pi / 2, -pi / 2 + 2 * pi * p, lw) end
    if state == "lost" and now - endT > 0.4 then
      for s = -1, 1, 2 do
        local ex, ey = cx + s * hr * 0.4, top + hr * 0.9
        gfx.line(ex - 4, ey - 4, ex + 4, ey + 4, 2)
        gfx.line(ex + 4, ey - 4, ex - 4, ey + 4, 2)
      end
    elseif state == "won" then
      gfx.arc(cx, top + hr * 1.1, hr * 0.5, 0.2, pi - 0.2, 2)
    end
  end
  local neck, hip = top + hr * 2, top + hr * 2 + h * 0.25
  if wrong >= 2 then stroke(cx, neck, cx, hip, partT[2], now, lw) end
  if wrong >= 3 then stroke(cx, neck + h * 0.05, cx - w * 0.12, neck + h * 0.15, partT[3], now, lw) end
  if wrong >= 4 then stroke(cx, neck + h * 0.05, cx + w * 0.12, neck + h * 0.15, partT[4], now, lw) end
  if wrong >= 5 then stroke(cx, hip, cx - w * 0.1, hip + h * 0.2, partT[5], now, lw) end
  if wrong >= 6 then stroke(cx, hip, cx + w * 0.1, hip + h * 0.2, partT[6], now, lw) end
  gfx.pop()
  -- lives as hearts
  for k = 1, MAXWRONG do
    gfx.icon(k <= MAXWRONG - wrong and "favorite" or "favorite_border", x + w * 0.1 + (k - 1) * w * 0.14, y + h + 14,
             min(22, w * 0.11), k <= MAXWRONG - wrong and theme.red or theme.text3)
  end
end

local function drawWordBoxes(x, y, w, now)
  local n = #letters
  local bw = min(46, (w - (n - 1) * 6) / n)
  local total = n * bw + (n - 1) * 6
  local sx = 0
  if now - shakeT < 0.3 then sx = sin((now - shakeT) * 70) * 6 * (1 - (now - shakeT) / 0.3) end
  local x0 = x + (w - total) / 2 + sx
  for i, l in ipairs(letters) do
    local bx = x0 + (i - 1) * (bw + 6)
    local shown = guessed[l] == "hit" or state == "lost"
    gfx.rect(bx, y + bw * 1.1, bw, 4, 2, state == "won" and theme.green or theme.text2)
    if shown then
      local t0 = revealedAt[i] or -10
      local p = K.easeOutBack((now - t0) / 0.3)
      if p > 0 then
        local missed = state == "lost" and guessed[l] ~= "hit"
        local bounce = state == "won" and -math.abs(sin((now - endT) * 6 - i * 0.5)) * 6 * max(0, 1 - (now - endT) / 2) or 0
        gfx.color(missed and theme.red or theme.text)
        local fs = bw * 0.8 * min(1, p)
        gfx.text(l, bx, y + bw * 1.05 - gfx.textHeight(fs, "bold") + bounce, fs, "bold", "center", bw)
      end
    end
  end
end

local function drawKeyboard(x, y, w, h, now)
  local kw = min(56, (w - 9 * 6) / 10)
  local kh = min(52, (h - 2 * 8) / 3)
  for r, row in ipairs(ROWS) do
    local rw = #row * kw + (#row - 1) * 6
    local rx = x + (w - rw) / 2
    for c, l in ipairs(row) do
      local kx, ky = rx + (c - 1) * (kw + 6), y + (r - 1) * (kh + 8)
      local st = guessed[l]
      local hit = ui.hit("key" .. l, kx, ky, kw, kh)
      local bg = st == "hit" and theme.green or (st == "miss" and K.col(theme.text, 0.12) or theme.control)
      if not st and hit.hovered then bg = theme.hover end
      if hit.held and not st then ky = ky + 2 end
      gfx.shadow(kx, ky, kw, kh, 8, 4, st and 0 or 2)
      gfx.rect(kx, ky, kw, kh, 8, bg)
      gfx.color(theme.separator)
      gfx.rectLine(kx, ky, kw, kh, 8, 1)
      gfx.color(st == "hit" and "#FFFFFF" or (st == "miss" and theme.text3 or theme.text))
      F.ctext(l, kx, ky, kw, kh, kh * 0.42, "bold")
      if cur.x == c and cur.y == r and state == "play" and not F.modal() then K.ring(kx - 3, ky - 3, kw + 6, kh + 6, 10) end
      if hit.clicked and not F.modal() and state == "play" then
        K.lastInput = "pointer"
        cur.x, cur.y = c, r
        guess(l)
      end
    end
  end
end

local function drawHints(w, y)
  if K.lastInput == "pad" then
    K.hints({{"dpad", TR("h_move")}, {"A", TR("h_guess")}, {"Y", TR("h_hint")}, {"X", TR("h_new_word")},
             {"-", TR("h_cats")}, {"+", TR("h_pause")}}, 0, y, w)
  elseif K.lastInput == "key" then
    K.hints({{"A-Z", TR("h_guess")}, {"Ç Ğ İ Ö Ş Ü", TR("h_turkish")}, {"1", TR("h_hint")}, {"Esc", TR("h_pause")}}, 0, y, w)
  else
    K.hints({{"touch", TR("h_tap_letter")}}, 0, y, w)
  end
end

local function drawCats(w, h, now)
  K.dim(w, h, 1)
  local cols = 3
  local n = #CATS + 1
  local cw = floor(min(170, (w - 80) / cols))
  local ch = floor(min(84, (h - 200) / 3))
  local gw, gh = cols * cw + (cols - 1) * 10, 3 * ch + 2 * 10
  local x0, y0 = floor((w - gw) / 2), floor((h - gh) / 2) + 10
  K.card(x0 - 20, y0 - 60, gw + 40, gh + 124, 16)
  gfx.color(theme.text)
  gfx.text(TR("choose_cat"), x0 - 20, y0 - 44, 20, "bold", "center", gw + 40)
  for i = 0, n - 1 do
    local cx, cy = i % cols, i // cols
    local x, y = x0 + cx * (cw + 10), y0 + cy * (ch + 10)
    local c = CATS[i] -- i = 0: random
    local hit = ui.hit("cat" .. i, x, y, cw, ch)
    local col = c and c.color or theme.accent
    gfx.rect(x, y, cw, ch, 12, hit.hovered and K.col(col, 0.28) or K.col(col, 0.16))
    if cat == i then gfx.color(col); gfx.rectLine(x, y, cw, ch, 12, 2) end
    gfx.icon(c and c.icon or "shuffle", x + 26, y + ch / 2, 26, col)
    gfx.color(theme.text)
    gfx.text(catName(i), x + 46, y + ch / 2 - 18, 14, "semibold")
    gfx.color(theme.text2)
    local sub = c and TR("cat_wins", catStat(c.key).won, #c.words) or TR("cat_mix")
    gfx.text(sub, x + 46, y + ch / 2 + 2, 11, "medium")
    if catCur.x == cx + 1 and catCur.y == cy + 1 then K.ring(x - 3, y - 3, cw + 6, ch + 6, 14) end
    if hit.clicked then setCat(i); K.play("pop", 0.5) end
  end
  if ui.button(TR("close") .. "##cats", x0 + gw / 2 - 70, y0 + gh + 14, 140, 34) then F.close() end
end

local function statLines()
  local tp, tw = 0, 0
  local lines = {}
  for i, c in ipairs(CATS) do
    local s = catStat(c.key)
    tp, tw = tp + s.played, tw + s.won
    lines[#lines + 1] = {catName(i), TR("won_of", s.won, s.played)}
  end
  table.insert(lines, 1, {TR("score"), tostring(score)})
  table.insert(lines, 2, {TR("win_rate"), tp > 0 and (floor(tw / tp * 100 + 0.5) .. "%") or "—"})
  table.insert(lines, 3, {TR("best_streak"), tostring(bestStreak)})
  return lines
end

local function drawDialogs(w, h, now)
  local s = F.scene
  if s == "pause" then
    F.pauseDialog(w, h, {onRestart = newWord, onMenu = function() F.open("title") end})
  elseif s == "cats" then
    drawCats(w, h, now)
  elseif s == "over" then
    local won = state == "won"
    K.dialog(F.dlg, w, h, {icon = won and "emoji_events" or "sentiment_very_dissatisfied",
      iconColor = won and theme.yellow or theme.red, title = won and TR("you_found") or TR("you_lost"),
      subtitle = TR("the_word", word),
      lines = {{TR("streak"), tostring(streak)}, {TR("score"), tostring(score)}},
      buttons = {{TR("next_word"), newWord, "primary", "arrow_forward"},
                 {TR("categories"), function() F.open("cats") end, "default", "category"},
                 {TR("close"), F.close}}})
  else
    F.commonDialogs(w, h, {stats = statLines,
      onReset = function() stats = {}; streak, bestStreak, score = 0, 0, 0; saveStats() end,
      onNew = newWord})
  end
end

local function drawTitle(w, h)
  F.titleScreen(w, h, {icon = "text_fields", c1 = "#94A3B8", c2 = "#334155", title = TR("title"), subtitle = TR("tagline"),
    buttons = {{state == "play" and next(guessed) and TR("continue") or TR("play"), function()
                  if state ~= "play" then newWord() else F.play() end
                end, "primary", "play_arrow"},
               {TR("categories"), function() F.open("cats") end, "default", "category"},
               {TR("stats_title"), function() F.open("stats") end, "default", "bar_chart"}},
    footer = TR("title_footer", catName(cat), streak)})
end

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  if F.scene == "title" or (F.scene ~= "play" and F.returnTo == "title") then
    drawTitle(w, h)
    if F.scene ~= "title" then drawDialogs(w, h, now) end
    return
  end
  F.title(TR("title"), TR("cat_line", catName(wordCat), #letters), 16, 10)
  local hit = F.toolbar({{"pause", "pause"}, F.soundItem(), {"category", "cats"}, {"skip_next", "new"},
                         {"lightbulb", "hint", hintUsed and theme.text3 or nil}}, w - 16, 14)
  if hit == "sound" then K.setMuted(not K.muted)
  elseif hit == "pause" then F.open("pause")
  elseif hit == "cats" then F.open("cats")
  elseif hit == "new" then newWord()
  elseif hit == "hint" then hint() end
  -- streak pill
  gfx.color(theme.text2)
  gfx.text(TR("streak_line", streak, score), 16, 60, 12, "semibold")
  local kbH = min(190, h * 0.32)
  local kbY = h - 36 - kbH
  local wordY = kbY - 80
  local gh = wordY - 90 - 30
  local gw = min(w - 32, gh * 1.0)
  G.x, G.y, G.w, G.h = floor((w - gw) / 2), 84, gw, gh
  drawGallows(G.x, G.y, G.w, G.h, now)
  drawWordBoxes(16, wordY, w - 32, now)
  drawKeyboard(16, kbY, w - 32, kbH, now)
  fx:draw()
  drawHints(w, h - 28)
  drawDialogs(w, h, now)
  K.drawToast(w, kbY - 50)
end

-- ------------------------------------------------------------------ input
local function catsEvent(e)
  local t = e.type
  local k = t == "paddown" and e.pad or (t == "keydown" and e.key) or nil
  if not k then return end
  local d = F.DIRV[k]
  if d then F.moveCursor(catCur, d[1], d[2], 3, 3, true)
  elseif (t == "paddown" and k == "a") or (t == "keydown" and (k == "enter" or k == "space")) then
    local i = (catCur.y - 1) * 3 + catCur.x - 1
    if i <= #CATS then setCat(i); K.play("pop", 0.5) end
  elseif (t == "paddown" and (k == "b" or k == "minus")) or (t == "keydown" and k == "escape") then
    F.close()
  end
end

function app.event(e)
  K.track(e)
  local t = e.type
  if F.scene == "cats" then catsEvent(e); return end
  if F.modal() then F.dialogEvent(e); return end
  if t == "paddown" then
    local p = e.pad
    local d = F.DIRV[p]
    if state ~= "play" then
      if p == "a" then F.open("over") elseif p == "x" then newWord() elseif p == "plus" then F.open("pause") end
      return
    end
    if d then
      F.moveCursor(cur, d[1], d[2], #ROWS[1], #ROWS, true)
      cur.x = min(cur.x, #ROWS[cur.y])
    elseif p == "a" then guess(ROWS[cur.y][cur.x])
    elseif p == "y" then hint()
    elseif p == "x" then newWord()
    elseif p == "minus" then F.open("cats")
    elseif p == "plus" or p == "b" then F.open("pause") end
  elseif t == "text" then
    local l = T.fromInput(e.text)
    if l and state == "play" then guess(l) end
  elseif t == "keydown" then
    local k = e.key
    if state ~= "play" then
      if k == "enter" or k == "space" then F.open("over") elseif k == "escape" then F.open("pause") end
      return
    end
    if k == "escape" then F.open("pause")
    elseif k == "1" then hint()
    elseif k == "enter" then guess(ROWS[cur.y][cur.x])
    elseif F.DIRV[k] then
      F.moveCursor(cur, F.DIRV[k][1], F.DIRV[k][2], #ROWS[1], #ROWS, true)
      cur.x = min(cur.x, #ROWS[cur.y])
    elseif #k == 1 and k:match("%a") then
      -- a physical key without a text event: 'i' is the dotted İ on Turkish keyboards
      local l = T.fromInput(k)
      if l then guess(l) end
    end
  end
end

function app.menu()
  local items = {{label = TR("next_word"), id = 1, shortcut = "X"}, {label = TR("hint"), id = 2}, "-",
                 {label = catName(0), id = 10, checked = cat == 0}}
  for i = 1, #CATS do items[#items + 1] = {label = catName(i), id = 10 + i, checked = cat == i} end
  items[#items + 1] = "-"
  items[#items + 1] = {label = TR("sound"), id = 3, checked = not K.muted}
  items[#items + 1] = {label = TR("stats_title"), id = 4}
  return {{title = TR("menu_game"), items = items}}
end

function app.onmenu(id)
  if id == 1 then newWord()
  elseif id == 2 then hint()
  elseif id == 3 then K.setMuted(not K.muted)
  elseif id == 4 then F.open("stats")
  elseif id >= 10 and id <= 10 + #CATS then setCat(id - 10) end
end

function app.close()
  saveGame()
  saveStats()
  return true
end

return app
