-- Flashcards for Nexvyn OS: decks of cards studied with a Leitner spaced-repetition schedule.
local app = {}

local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi
local STARTER = require("starter")

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
local function mix(c1, c2, k)
  local a, b = rgba(c1), rgba(c2)
  return {floor(a[1] + (b[1] - a[1]) * k + 0.5), floor(a[2] + (b[2] - a[2]) * k + 0.5),
          floor(a[3] + (b[3] - a[3]) * k + 0.5), floor(a[4] + (b[4] - a[4]) * k + 0.5)}
end
local function approach(v, target, speed, dt) return v + (target - v) * min(1, dt * speed) end
local WHITE = "#FFFFFF"

local fieldRects, nFields, editing = {}, 0, false
local function field(id, text, x, y, w, h, ph, flags)
  nFields = nFields + 1
  local r = fieldRects[nFields]
  if not r then r = {}; fieldRects[nFields] = r end
  r[1], r[2], r[3], r[4] = x, y, w, h
  return ui.textfield(id, text, x, y, w, h, ph, flags)
end
local function pointInField(x, y)
  for i = 1, nFields do
    local r = fieldRects[i]
    if x >= r[1] and y >= r[2] and x <= r[1] + r[3] and y <= r[2] + r[4] then return true end
  end
  return false
end

local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

-- Turkish-aware lower case for searching
local TR_LOWER = {["I"] = "ı", ["İ"] = "i", ["Ç"] = "ç", ["Ğ"] = "ğ", ["Ö"] = "ö", ["Ş"] = "ş", ["Ü"] = "ü"}
local function lower(s)
  local out = {}
  for _, c in utf8.codes(s) do
    local ch = utf8.char(c)
    out[#out + 1] = TR_LOWER[ch] or (#ch == 1 and ch:lower() or ch)
  end
  return table.concat(out)
end

local function daysFromCivil(y, m, d)
  y = (m <= 2) and (y - 1) or y
  local era = (y >= 0 and y or y - 399) // 400
  local yoe = y - era * 400
  local mp = (m + 9) % 12
  local doy = (153 * mp + 2) // 5 + d - 1
  local doe = yoe * 365 + yoe // 4 - yoe // 100 + doy
  return era * 146097 + doe - 719468
end
local function today()
  local d = sys.date()
  return daysFromCivil(d.year, d.month, d.day)
end

-- ------------------------------------------------------------------ Leitner
local INTERVAL = {1, 2, 4, 7, 14}      -- days until the next review after a correct answer, boxes 1..5
local BOX_COLORS = {"red", "orange", "yellow", "blue", "green"}
local DECK_COLORS = {"blue", "purple", "pink", "orange", "green", "red", "yellow", "gray"}

-- ------------------------------------------------------------------ state
local decks = {}
local nextId = 1
local view = "decks"         -- decks | deck | study | summary
local curDeck = nil
local deckSel = 0
local search = ""
local sheet = nil
local sheetT = 0
local viewT = 1

-- study session
local S = nil

local function save()
  store.set("decks", decks)
  store.set("nextId", nextId)
end
local function saveNow()
  save()
  store.save()
end

local function newId()
  local id = "x" .. nextId
  nextId = nextId + 1
  return id
end

local function dueCount(deck, t)
  t = t or today()
  local n = 0
  for _, c in ipairs(deck.cards) do if c.due <= t then n = n + 1 end end
  return n
end

local function boxCounts(deck)
  local b = {0, 0, 0, 0, 0}
  for _, c in ipairs(deck.cards) do b[c.box] = b[c.box] + 1 end
  return b
end

local function makeStarter()
  local tr = sys.lang() == "tr"
  local deck = {id = newId(), name = TR("starter_name"), color = "blue", dir = 1, cards = {}}
  local t = today()
  for _, p in ipairs(STARTER) do
    local f, b = p[1], p[2]
    if not tr then f, b = p[2], p[1] end
    deck.cards[#deck.cards + 1] = {id = newId(), f = f, b = b, box = 1, due = t}
  end
  return deck
end

local function sanitizeDeck(d)
  if type(d) ~= "table" then return nil end
  local o = {id = tostring(d.id or newId()), name = type(d.name) == "string" and d.name or TR("untitled"),
             color = type(d.color) == "string" and d.color or "blue", dir = tonumber(d.dir) or 1, cards = {}}
  if o.dir < 1 or o.dir > 3 then o.dir = 1 end
  if type(d.cards) == "table" then
    for _, c in ipairs(d.cards) do
      if type(c) == "table" and type(c.f) == "string" and type(c.b) == "string" then
        o.cards[#o.cards + 1] = {id = tostring(c.id or newId()), f = c.f, b = c.b,
                                 box = max(1, min(5, floor(tonumber(c.box) or 1))), due = floor(tonumber(c.due) or today())}
      end
    end
  end
  return o
end

local function findDeck(id)
  for i, d in ipairs(decks) do if d.id == id then return d, i end end
end

-- ------------------------------------------------------------------ navigation
local function go(v)
  view = v
  viewT = 0
  editing = false
end

local function openDeck(d)
  curDeck = d
  search = ""
  go("deck")
  audio.play("click")
end

local function shuffle(t)
  for i = #t, 2, -1 do
    local j = math.random(i)
    t[i], t[j] = t[j], t[i]
  end
end

local function startStudy(d, practice)
  local t = today()
  local queue = {}
  for _, c in ipairs(d.cards) do
    if practice or c.due <= t then queue[#queue + 1] = c end
  end
  if #queue == 0 then
    audio.play("error")
    return
  end
  shuffle(queue)
  -- lowest boxes first (stable after the shuffle), at most 20 cards per session
  for i, c in ipairs(queue) do c._r = i end
  table.sort(queue, function(a, b) if a.box ~= b.box then return a.box < b.box end return a._r < b._r end)
  for _, c in ipairs(queue) do c._r = nil end
  while #queue > 20 do table.remove(queue) end
  S = {deck = d, queue = queue, pos = 1, total = #queue, right = 0, wrong = 0, practice = practice, flipped = false,
       flipT = 0, outT = 0, outDir = 0, seen = {}, reverse = {}, startedAt = sys.time()}
  for i, c in ipairs(queue) do
    if d.dir == 2 then S.reverse[c.id] = true
    elseif d.dir == 3 then S.reverse[c.id] = math.random() < 0.5 end
  end
  curDeck = d
  go("study")
  audio.play("pop")
end

local function flip()
  if not S or S.outDir ~= 0 then return end
  S.flipped = not S.flipped
  audio.tone(S.flipped and 720 or 600, 0.05, 0.18, "sine")
end

local function answer(correct)
  if not S or not S.flipped or S.outDir ~= 0 then return end
  local c = S.queue[S.pos]
  local first = not S.seen[c.id]
  S.seen[c.id] = true
  if first then
    if correct then S.right = S.right + 1 else S.wrong = S.wrong + 1 end
  end
  if not S.practice then
    local t = today()
    if correct then
      if first then c.box = min(5, c.box + 1) end
      c.due = t + INTERVAL[c.box]
    else
      c.box = 1
      c.due = t
    end
    saveNow()
  end
  if not correct then
    -- see the card again at the end of this session
    S.queue[#S.queue + 1] = c
  end
  S.outDir = correct and 1 or -1
  S.outT = 0
  if correct then
    audio.tone(660, 0.07, 0.25, "triangle")
    timer.after(0.07, function() audio.tone(990, 0.1, 0.22, "triangle") end)
  else
    audio.tone(300, 0.14, 0.25, "triangle")
  end
end

local function advance()
  S.pos = S.pos + 1
  S.flipped = false
  S.flipT = 0
  S.outDir = 0
  S.outT = 0
  if S.pos > #S.queue then
    go("summary")
    audio.play("notify")
  end
end

-- ------------------------------------------------------------------ sheets
local function openCardSheet(card)
  sheet = {kind = "card", card = card, f = card and card.f or "", b = card and card.b or "", err = false, added = 0}
  sheetT = 0
  editing = false
  audio.play("pop")
end

local function openDeckSheet(deck)
  sheet = {kind = "deck", deck = deck, name = deck and deck.name or "",
           color = deck and deck.color or DECK_COLORS[(#decks % #DECK_COLORS) + 1], err = false}
  sheetT = 0
  editing = false
  audio.play("pop")
end

local function closeSheet()
  sheet = nil
  editing = false
end

local function commitSheet(keepOpen)
  local s = sheet
  if not s then return end
  if s.kind == "card" then
    local f, b = trim(s.f), trim(s.b)
    if f == "" or b == "" then
      s.err = true
      audio.play("error")
      return
    end
    if s.card then
      s.card.f, s.card.b = f, b
    else
      curDeck.cards[#curDeck.cards + 1] = {id = newId(), f = f, b = b, box = 1, due = today()}
      s.added = s.added + 1
    end
    saveNow()
    audio.play("click")
    if keepOpen and not s.card then
      s.f, s.b, s.err = "", "", false
      ui.focus("fc_front")
      editing = true
    else
      closeSheet()
    end
  else
    local name = trim(s.name)
    if name == "" then
      s.err = true
      audio.play("error")
      return
    end
    if s.deck then
      s.deck.name, s.deck.color = name, s.color
    else
      local d = {id = newId(), name = name, color = s.color, dir = 1, cards = {}}
      decks[#decks + 1] = d
      closeSheet()
      saveNow()
      openDeck(d)
      return
    end
    saveNow()
    closeSheet()
    audio.play("click")
  end
end

local function deleteCard(card)
  ui.alert(TR("delete_card_title"), TR("delete_card_msg", card.f), {TR("delete"), TR("cancel")}, function(b)
    if b == 1 and curDeck then
      for i, c in ipairs(curDeck.cards) do
        if c == card then table.remove(curDeck.cards, i) break end
      end
      if sheet and sheet.card == card then closeSheet() end
      saveNow()
      audio.play("trash")
    end
  end)
end

local function deleteDeck(deck)
  ui.alert(TR("delete_deck_title"), TR("delete_deck_msg", deck.name, #deck.cards), {TR("delete"), TR("cancel")}, function(b)
    if b == 1 then
      local _, i = findDeck(deck.id)
      if i then table.remove(decks, i) end
      if curDeck == deck then curDeck = nil; go("decks") end
      if sheet and sheet.deck == deck then closeSheet() end
      deckSel = 0
      saveNow()
      audio.play("trash")
    end
  end)
end

local function resetDeck(deck)
  ui.alert(TR("reset_title"), TR("reset_msg"), {TR("reset"), TR("cancel")}, function(b)
    if b == 1 then
      local t = today()
      for _, c in ipairs(deck.cards) do c.box, c.due = 1, t end
      saveNow()
      audio.play("trash")
    end
  end)
end

local function deckMenu(deck)
  ui.contextMenu({
    {label = TR("study"), id = 1, icon = "school"},
    {label = TR("practice_all"), id = 2, icon = "replay"},
    "-",
    {label = TR("rename"), id = 3, icon = "edit"},
    {label = TR("reset_progress"), id = 4, icon = "restart_alt"},
    "-",
    {label = TR("delete"), id = 5, icon = "delete"},
  }, function(id)
    if id == 1 then startStudy(deck, dueCount(deck) == 0)
    elseif id == 2 then startStudy(deck, true)
    elseif id == 3 then openDeckSheet(deck)
    elseif id == 4 then resetDeck(deck)
    elseif id == 5 then deleteDeck(deck) end
  end)
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  nextId = tonumber(store.get("nextId", 1)) or 1
  local list = store.get("decks", nil)
  decks = {}
  if type(list) == "table" then
    for _, d in ipairs(list) do
      local o = sanitizeDeck(d)
      if o then decks[#decks + 1] = o end
    end
  end
  if list == nil then
    decks[1] = makeStarter()
    saveNow()
  end
end

function app.update(dt)
  viewT = approach(viewT, 1, 10, dt)
  if sheet then sheetT = approach(sheetT, 1, 14, dt) end
  if S and view == "study" then
    S.flipT = approach(S.flipT, S.flipped and 1 or 0, 9, dt)
    if S.outDir ~= 0 then
      S.outT = S.outT + dt / 0.32
      if S.outT >= 1 then advance() end
    end
  end
end

-- ------------------------------------------------------------------ drawing helpers
local function boxBar(deck, x, y, w, h)
  local b = boxCounts(deck)
  local n = #deck.cards
  if n == 0 then
    gfx.rect(x, y, w, h, h / 2, theme.dark and "#FFFFFF14" or "#0000000F")
    return
  end
  gfx.clip(x, y, w, h)
  local cx = x
  for i = 1, 5 do
    local bw = w * b[i] / n
    if bw > 0 then
      gfx.rect(cx, y, bw + 1, h, 0, theme[BOX_COLORS[i]])
      cx = cx + bw
    end
  end
  gfx.unclip()
end

local function header(title, w, interactive, backFn)
  local x = 20
  if backFn then
    if interactive and ui.iconButton("arrow_back", 14, 16, 34, 32, theme.text2, false, "back") then backFn() end
    x = 54
  end
  gfx.color(theme.text)
  gfx.clip(x, 14, w - x - 372, 36)
  gfx.text(title, x, 18, 22, "bold")
  gfx.unclip()
end

-- ------------------------------------------------------------------ decks view
local function drawDecks(w, h, interactive)
  header(TR("title"), w, interactive)
  if interactive and ui.button(TR("new_deck") .. "##top", w - 160, 16, 140, 30, "primary", "add") then openDeckSheet(nil) end
  -- summary strip
  local t = today()
  local total, due, mastered = 0, 0, 0
  for _, d in ipairs(decks) do
    total = total + #d.cards
    for _, c in ipairs(d.cards) do
      if c.due <= t then due = due + 1 end
      if c.box == 5 then mastered = mastered + 1 end
    end
  end
  local y = 62
  local items = {{"style", theme.blue, TR("stat_cards"), total}, {"schedule", theme.orange, TR("stat_due"), due},
                 {"emoji_events", theme.green, TR("stat_mastered"), mastered}}
  local cw = floor((w - 40 - 24) / 3)
  for i, it in ipairs(items) do
    local x = 20 + (i - 1) * (cw + 12)
    gfx.rect(x, y, cw, 58, 12, theme.dark and "#FFFFFF0F" or "#0000000A")
    gfx.circle(x + 28, y + 29, 16, fade(it[2], 0.16))
    gfx.icon(it[1], x + 28, y + 29, 18, it[2])
    gfx.color(theme.text)
    gfx.text(tostring(it[4]), x + 54, y + 9, 20, "bold")
    gfx.color(theme.text2)
    gfx.text(it[3], x + 54, y + 34, 12)
  end
  local top = y + 76
  if #decks == 0 then
    gfx.icon("collections_bookmark", w / 2, top + 90, 44, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("no_decks"), 0, top + 126, 15, "medium", "center", w)
    if interactive and ui.button(TR("add_starter") .. "##empty", w / 2 - 110, top + 160, 220, 34) then
      decks[#decks + 1] = makeStarter()
      saveNow()
    end
    return
  end
  local rowH = 92
  local contentH = #decks * (rowH + 10)
  if interactive then ui.beginScroll("decks", 0, top, w, h - top - 8, contentH)
  else gfx.clip(0, top, w, h - top - 8); gfx.push(0, top) end
  for i, d in ipairs(decks) do
    local x, yy, cw2 = 20, (i - 1) * (rowH + 10), w - 40
    local col = theme[d.color] or theme.blue
    local dueN = dueCount(d, t)
    local btnW = 128
    local hit = interactive and ui.hit("deck" .. d.id, x, yy, cw2 - btnW - 24, rowH)
    if hit and hit.hovered then gfx.shadow(x, yy, cw2, rowH, 12, 12, 3) end
    gfx.rect(x, yy, cw2, rowH, 12, theme.dark and "#2A2A2D" or "#FFFFFF")
    gfx.color(deckSel == i and theme.accent or theme.separator)
    gfx.rectLine(x, yy, cw2, rowH, 12, deckSel == i and 2 or 1)
    gfx.rect(x, yy + 14, 5, rowH - 28, 2.5, col)
    gfx.circle(x + 40, yy + 34, 18, fade(col, 0.16))
    gfx.icon("style", x + 40, yy + 34, 20, col)
    gfx.clip(x + 68, yy + 10, cw2 - btnW - 100, 50)
    gfx.color(theme.text)
    gfx.text(d.name, x + 68, yy + 14, 16, "semibold")
    gfx.color(theme.text2)
    gfx.text(TR("deck_counts", #d.cards, dueN), x + 68, yy + 37, 12.5)
    gfx.unclip()
    boxBar(d, x + 68, yy + 64, cw2 - btnW - 100, 8)
    local bx = x + cw2 - btnW - 16
    if interactive then
      if dueN > 0 then
        if ui.button(TR("study_n", dueN) .. "##" .. d.id, bx, yy + 28, btnW, 34, "primary", "school") then startStudy(d, false) end
      else
        if ui.button(TR("practice") .. "##" .. d.id, bx, yy + 28, btnW, 34, "default", "replay", #d.cards > 0) then startStudy(d, true) end
      end
    end
    if hit then
      if hit.clicked then deckSel = i; openDeck(d) end
      if hit.rightClicked then deckSel = i; deckMenu(d) end
    end
  end
  if interactive then ui.endScroll() else gfx.pop(); gfx.unclip() end
end

-- ------------------------------------------------------------------ deck view
local DIRS = {"dir_fb", "dir_bf", "dir_mixed"}
local function drawDeck(w, h, interactive)
  local d = curDeck
  header(d.name, w, interactive, function() go("decks"); audio.play("click") end)
  local dueN = dueCount(d)
  if interactive then
    if ui.iconButton("more_horiz", w - 56, 16, 36, 30, theme.text2, false, "deckmore") then deckMenu(d) end
    if ui.button(TR("add_card") .. "##top", w - 210, 16, 146, 30, "default", "add") then openCardSheet(nil) end
    local lbl = dueN > 0 and TR("study_n", dueN) or TR("practice")
    if ui.button(lbl .. "##deck", w - 350, 16, 132, 30, "primary", dueN > 0 and "school" or "replay", #d.cards > 0) then
      startStudy(d, dueN == 0)
    end
  end
  -- box distribution
  local y = 62
  local b = boxCounts(d)
  local bw = floor((w - 40 - 4 * 8) / 5)
  for i = 1, 5 do
    local x = 20 + (i - 1) * (bw + 8)
    local col = theme[BOX_COLORS[i]]
    gfx.rect(x, y, bw, 52, 10, fade(col, 0.12))
    gfx.color(col)
    gfx.text(tostring(b[i]), x + 12, y + 7, 18, "bold")
    gfx.color(theme.text2)
    gfx.text(TR("box_n", i), x + 12, y + 31, 11.5, "medium")
    gfx.color(theme.text3)
    gfx.text(i == 1 and TR("every_day") or TR("every_n_days", INTERVAL[i]), x, y + 31, 11, "sans", "right", bw - 10)
  end
  -- toolbar: direction + search
  y = y + 66
  if interactive then
    local nd = ui.segmented("dir", {TR(DIRS[1]), TR(DIRS[2]), TR(DIRS[3])}, d.dir, 20, y, 330, 28)
    if nd ~= d.dir then d.dir = nd; saveNow(); audio.play("click") end
    local ns = field("search", search, w - 240, y - 1, 220, 30, TR("search"), "search")
    if ns ~= search then search = ns end
  end
  local top = y + 40
  local q = lower(trim(search))
  local list = {}
  for _, c in ipairs(d.cards) do
    if q == "" or lower(c.f):find(q, 1, true) or lower(c.b):find(q, 1, true) then list[#list + 1] = c end
  end
  if #list == 0 then
    gfx.icon(#d.cards == 0 and "style" or "search", w / 2, top + 70, 40, theme.text3)
    gfx.color(theme.text2)
    gfx.text(#d.cards == 0 and TR("no_cards") or TR("no_match"), 0, top + 104, 14, "medium", "center", w)
    if #d.cards == 0 and interactive and ui.button(TR("add_card") .. "##empty", w / 2 - 80, top + 134, 160, 34, "primary", "add") then
      openCardSheet(nil)
    end
    return
  end
  local rowH = 46
  local lh = h - top - 10
  ui.group(20, top, w - 40, lh)
  if interactive then ui.beginScroll("cards", 20, top, w - 40, lh, #list * rowH + 4)
  else gfx.clip(20, top, w - 40, lh); gfx.push(20, top) end
  local t = today()
  local iw = w - 40
  for i, c in ipairs(list) do
    local yy = (i - 1) * rowH + 2
    local hit = interactive and ui.hit("card" .. c.id, 4, yy, iw - 8, rowH - 2)
    if hit and hit.hovered then gfx.rect(4, yy, iw - 8, rowH - 2, 8, theme.hover) end
    if i > 1 then ui.separator(16, yy - 1, iw - 16) end
    local half = floor((iw - 190) / 2)
    gfx.clip(16, yy, half - 10, rowH)
    gfx.color(theme.text)
    gfx.text(c.f, 16, yy + 13, 14, "medium")
    gfx.unclip()
    gfx.clip(16 + half, yy, half - 10, rowH)
    gfx.color(theme.text2)
    gfx.text(c.b, 16 + half, yy + 13, 14)
    gfx.unclip()
    local col = theme[BOX_COLORS[c.box]]
    local bx = iw - 172
    gfx.rect(bx, yy + 12, 62, 20, 10, fade(col, 0.16))
    gfx.color(col)
    gfx.text(TR("box_n", c.box), bx, yy + 14, 11.5, "semibold", "center", 62)
    gfx.color(c.due <= t and theme.orange or theme.text3)
    local dueTxt = c.due <= t and TR("due_now") or (c.due - t == 1 and TR("due_tomorrow") or TR("due_in", c.due - t))
    gfx.text(dueTxt, bx + 66, yy + 14, 11.5, "medium", "right", 90)
    if hit then
      if hit.clicked then openCardSheet(c) end
      if hit.rightClicked then
        ui.contextMenu({{label = TR("edit"), id = 1, icon = "edit"}, "-", {label = TR("delete"), id = 2, icon = "delete"}},
          function(id)
            if id == 1 then openCardSheet(c) elseif id == 2 then deleteCard(c) end
          end)
      end
    end
  end
  if interactive then ui.endScroll() else gfx.pop(); gfx.unclip() end
end

-- ------------------------------------------------------------------ study view
local function drawFace(text, label, x, y, w, h, col, sub)
  gfx.color(theme.text3)
  gfx.text(label, x, y + 18, 12, "semibold", "center", w)
  local size = 30
  local tw = gfx.textWidth(text, size, "bold")
  while tw > w - 60 and size > 18 do
    size = size - 2
    tw = gfx.textWidth(text, size, "bold")
  end
  gfx.color(col)
  local th = gfx.measureWrap(text, w - 60, size, "bold")
  local ty = y + (h - th) / 2
  if sub then ty = ty + 10 end
  gfx.wrap(text, x + 30, ty, w - 60, size, "bold", "center")
  if sub then
    gfx.color(theme.text3)
    gfx.text(sub, x + 20, ty - 26, 14, "medium", "center", w - 40)
  end
end

local function drawStudy(w, h, interactive)
  local c = S.queue[S.pos]
  if not c then return end
  header(S.deck.name, w, interactive, function() go("deck"); audio.play("click") end)
  -- progress
  local doneN = min(S.total, S.right + S.wrong)
  gfx.color(theme.text2)
  gfx.text(TR("progress", doneN, S.total), 0, 24, 13, "medium", "right", w - 20)
  ui.progress(doneN / max(1, S.total), 20, 58, w - 40, 6)
  if S.practice then
    gfx.color(theme.text3)
    gfx.text(TR("practice_mode"), 0, 70, 12, "sans", "center", w)
  end
  -- card geometry with flip + slide
  local cw, ch = min(520, w - 80), 270
  local cx, cy = w / 2, 96 + ch / 2
  local f = S.flipT
  local sx = abs(cos(f * pi))
  local showBack = f >= 0.5
  local slide = 0
  local a = 1
  if S.outDir ~= 0 then
    local e = S.outT * S.outT
    slide = S.outDir * e * (w * 0.7)
    a = 1 - S.outT
  end
  local rw = max(4, cw * sx)
  local x = cx - rw / 2 + slide
  local y = cy - ch / 2 - (1 - sx) * 10
  local rev = S.reverse[c.id]
  local q, ans = c.f, c.b
  if rev then q, ans = c.b, c.f end
  local tint = theme.dark and "#2C2C2E" or "#FFFFFF"
  if S.outDir ~= 0 then tint = mix(tint, S.outDir > 0 and theme.green or theme.red, 0.25 * (1 - S.outT) + 0.1) end
  gfx.alpha(a)
  -- next card peeking behind
  if S.pos < #S.queue then
    gfx.rect(cx - cw / 2 + 14, cy - ch / 2 + 12, cw - 28, ch, 18, theme.dark and "#FFFFFF0A" or "#0000000A")
  end
  gfx.shadow(x, y, rw, ch, 18, 26 + (1 - sx) * 12, 8)
  gfx.rect(x, y, rw, ch, 18, tint)
  gfx.color(theme.separator)
  gfx.rectLine(x, y, rw, ch, 18, 1)
  local boxCol = theme[BOX_COLORS[c.box]]
  gfx.clip(x, y, rw, ch)
  gfx.alpha(min(1, sx * 1.6))
  gfx.rect(cx - cw / 2 + slide + 18, y + 16, 58, 20, 10, fade(boxCol, 0.16))
  gfx.color(boxCol)
  gfx.text(TR("box_n", c.box), cx - cw / 2 + slide + 18, y + 18, 11.5, "semibold", "center", 58)
  if showBack then
    drawFace(ans, TR("answer"), cx - cw / 2 + slide, y, cw, ch, theme.accent, q)
  else
    drawFace(q, TR("question"), cx - cw / 2 + slide, y, cw, ch, theme.text)
    gfx.icon("flip", cx + slide, y + ch - 26, 18, theme.text3)
  end
  gfx.unalpha()
  gfx.unclip()
  gfx.unalpha()
  -- tap the card to flip
  if interactive and S.outDir == 0 then
    local hit = ui.hit("studycard", cx - cw / 2, cy - ch / 2, cw, ch)
    if hit.clicked then flip() end
  end
  -- controls
  local by = cy + ch / 2 + 30
  if interactive then
    if not S.flipped then
      if ui.button(TR("show_answer") .. "##show", w / 2 - 120, by, 240, 40, "primary", "flip") then flip() end
      gfx.color(theme.text3)
      gfx.text(TR("hint_flip"), 0, by + 50, 12, "sans", "center", w)
    else
      if ui.button(TR("didnt_know") .. "##no", w / 2 - 250, by, 240, 40, "destructive", "thumb_down") then answer(false) end
      if ui.button(TR("knew_it") .. "##yes", w / 2 + 10, by, 240, 40, "primary", "thumb_up") then answer(true) end
      gfx.color(theme.text3)
      gfx.text(TR("hint_answer"), 0, by + 50, 12, "sans", "center", w)
    end
  end
end

local function drawSummary(w, h, interactive)
  header(S.deck.name, w, interactive, function() go("deck"); audio.play("click") end)
  local total = S.right + S.wrong
  local pct = total > 0 and S.right / total or 0
  local cx, cy = w / 2, 190
  local k = min(1, viewT * 1.1)
  gfx.color(fade(theme.green, 0.18))
  gfx.arc(cx, cy, 70, 0, pi * 2, 12)
  if pct > 0 then
    gfx.color(theme.green)
    gfx.arc(cx, cy, 70, -pi / 2, -pi / 2 + pi * 2 * pct * k, 12)
  end
  gfx.color(theme.text)
  gfx.text(floor(pct * 100 * k + 0.5) .. "%", cx - 60, cy - 18, 30, "bold", "center", 120)
  gfx.color(theme.text)
  gfx.text(pct >= 0.8 and TR("summary_great") or (pct >= 0.5 and TR("summary_good") or TR("summary_keep")), 0, cy + 92, 20, "bold", "center", w)
  gfx.color(theme.text2)
  gfx.text(TR("summary_counts", S.right, S.wrong), 0, cy + 122, 14, "sans", "center", w)
  local mins = floor((sys.time() - S.startedAt) / 60)
  local secs = floor(sys.time() - S.startedAt) % 60
  gfx.color(theme.text3)
  gfx.text(TR("summary_time", string.format("%d:%02d", mins, secs)), 0, cy + 144, 12.5, "sans", "center", w)
  if interactive then
    local dueN = dueCount(S.deck)
    if ui.button(TR("back_to_deck") .. "##sum", w / 2 - 250, cy + 186, 240, 38) then go("deck") end
    if dueN > 0 then
      if ui.button(TR("study_n", dueN) .. "##sum", w / 2 + 10, cy + 186, 240, 38, "primary", "school") then startStudy(S.deck, false) end
    else
      if ui.button(TR("practice_again") .. "##sum", w / 2 + 10, cy + 186, 240, 38, "primary", "replay") then startStudy(S.deck, true) end
    end
  end
end

-- ------------------------------------------------------------------ sheets drawing
local function drawSheet(w, h)
  local s = sheet
  gfx.rect(0, 0, w, h, 0, {0, 0, 0, floor(110 * sheetT)})
  local sw = 480
  local sh = s.kind == "card" and 300 or 230
  local sx, sy = floor((w - sw) / 2), floor((h - sh) / 2 + (1 - sheetT) * 24)
  gfx.alpha(sheetT)
  gfx.shadow(sx, sy, sw, sh, 14, 30, 10)
  gfx.rect(sx, sy, sw, sh, 14, theme.dark and "#2C2C2E" or "#F6F6F6")
  gfx.color(theme.separator)
  gfx.rectLine(sx, sy, sw, sh, 14, 1)
  gfx.color(theme.text)
  local fy = sy + sh - 50
  if s.kind == "card" then
    gfx.text(s.card and TR("edit_card") or TR("new_card"), sx + 20, sy + 18, 17, "bold")
    if s.added > 0 then
      gfx.color(theme.green)
      gfx.text(TR("added_n", s.added), sx, sy + 22, 12.5, "medium", "right", sw - 20)
    end
    gfx.color(theme.text2)
    gfx.text(TR("front"), sx + 20, sy + 58, 12, "semibold")
    local nf = field("fc_front", s.f, sx + 20, sy + 76, sw - 40, 34, TR("front_ph"))
    if nf ~= s.f then s.f = nf; s.err = false end
    gfx.color(theme.text2)
    gfx.text(TR("back"), sx + 20, sy + 124, 12, "semibold")
    local nb, sub = field("fc_back", s.b, sx + 20, sy + 142, sw - 40, 34, TR("back_ph"))
    if nb ~= s.b then s.b = nb; s.err = false end
    if sub then commitSheet(true) end
    if s.err then
      gfx.color(theme.red)
      gfx.text(TR("both_sides"), sx + 20, sy + 186, 12)
    end
    ui.separator(sx, fy - 12, sx + sw)
    if s.card then
      if ui.button(TR("delete") .. "##sheet", sx + 20, fy, 96, 32, "destructive") then deleteCard(s.card) end
    else
      if ui.button(TR("save_add") .. "##sheet", sx + 20, fy, 150, 32) then commitSheet(true) end
    end
  else
    gfx.text(s.deck and TR("rename_deck") or TR("new_deck"), sx + 20, sy + 18, 17, "bold")
    local nn, sub = field("fc_deck", s.name, sx + 20, sy + 60, sw - 40, 34, TR("deck_ph"))
    if nn ~= s.name then s.name = nn; s.err = false end
    if sub then commitSheet(false); gfx.unalpha(); return end
    for i, c in ipairs(DECK_COLORS) do
      local px = sx + 20 + (i - 1) * 34
      local hh = ui.hit("dc" .. c, px, sy + 108, 30, 30)
      gfx.circle(px + 15, sy + 123, 12, theme[c])
      if s.color == c then
        gfx.color(theme[c])
        gfx.circleLine(px + 15, sy + 123, 15, 2)
      end
      if hh.clicked then s.color = c; audio.play("click") end
    end
    ui.separator(sx, fy - 12, sx + sw)
  end
  if ui.button(TR("cancel") .. "##sheet", sx + sw - 232, fy, 100, 32) then closeSheet(); audio.play("click") end
  if ui.button((s.kind == "card" and not s.card and TR("add") or TR("save")) .. "##sheetok", sx + sw - 120, fy, 100, 32, "primary") then
    commitSheet(false)
  end
  gfx.unalpha()
end

-- ------------------------------------------------------------------ draw / input
function app.draw(w, h)
  nFields = 0
  gfx.clear(theme.bg)
  local interactive = sheet == nil
  if (view == "deck" or view == "study" or view == "summary") and not curDeck then view = "decks" end
  if (view == "study" or view == "summary") and not S then view = "deck" end
  gfx.alpha(0.25 + 0.75 * viewT)
  gfx.push((1 - viewT) * 14, 0)
  if view == "decks" then drawDecks(w, h, interactive)
  elseif view == "deck" then drawDeck(w, h, interactive)
  elseif view == "study" then drawStudy(w, h, interactive)
  else drawSummary(w, h, interactive) end
  gfx.pop()
  gfx.unalpha()
  if sheet then drawSheet(w, h) end
end

function app.event(e)
  if e.type == "mousedown" then
    editing = pointInField(e.x, e.y)
    return
  end
  if e.type ~= "keydown" then return end
  if editing then
    if e.key == "escape" then editing = false end
    return
  end
  if sheet then
    if e.key == "escape" then closeSheet()
    elseif e.key == "enter" then commitSheet(false) end
    return
  end
  if view == "decks" then
    if e.key == "down" then deckSel = min(#decks, deckSel + 1)
    elseif e.key == "up" then deckSel = max(1, deckSel - 1)
    elseif e.key == "enter" and decks[deckSel] then openDeck(decks[deckSel])
    elseif e.key == "s" and decks[deckSel] then startStudy(decks[deckSel], dueCount(decks[deckSel]) == 0)
    elseif e.key == "n" then openDeckSheet(nil) end
  elseif view == "deck" then
    if e.key == "escape" or e.key == "backspace" then go("decks")
    elseif e.key == "n" or e.key == "a" then openCardSheet(nil)
    elseif e.key == "s" or e.key == "enter" then
      if #curDeck.cards > 0 then startStudy(curDeck, dueCount(curDeck) == 0) end
    end
  elseif view == "study" then
    if e.key == "escape" then go("deck")
    elseif e.key == "space" or e.key == "enter" or e.key == "up" or e.key == "down" then
      if not S.flipped then flip() end
    elseif e.key == "left" or e.key == "1" then answer(false)
    elseif e.key == "right" or e.key == "2" then answer(true) end
  elseif view == "summary" then
    if e.key == "escape" or e.key == "enter" then go("deck") end
  end
end

function app.menu()
  local inDeck = curDeck ~= nil and view ~= "decks"
  return {{title = TR("menu_cards"), items = {
    {label = TR("new_deck"), id = 1},
    {label = TR("add_card"), id = 2, enabled = inDeck},
    "-",
    {label = TR("study"), id = 3, enabled = inDeck},
    {label = TR("practice_all"), id = 4, enabled = inDeck},
    "-",
    {label = TR("add_starter"), id = 5},
  }}}
end

function app.onmenu(id)
  if id == 1 then openDeckSheet(nil)
  elseif id == 2 and curDeck then go("deck"); openCardSheet(nil)
  elseif id == 3 and curDeck then startStudy(curDeck, dueCount(curDeck) == 0)
  elseif id == 4 and curDeck then startStudy(curDeck, true)
  elseif id == 5 then
    decks[#decks + 1] = makeStarter()
    saveNow()
  end
end

function app.close()
  saveNow()
  return true
end

return app
