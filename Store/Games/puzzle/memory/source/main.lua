-- Hafıza Kartları / Memory Cards for Nexvyn OS: find the pairs. Three board sizes, solo (timer, moves, records)
-- or two players taking turns, 3D-style card flips, hints and a saved game in progress.
local K = require("kit")
local F = require("frame")
local app = {}

local floor, max, min, abs, sin, cos, pi = math.floor, math.max, math.min, math.abs, math.sin, math.cos, math.pi
local random = math.random

local SIZES = {{4, 3}, {4, 4}, {6, 5}}
local SIZE_LABELS = {"4×3", "4×4", "6×5"}
local ICONS = {
  {"pets", "#FF8A65"}, {"star", "#FFC107"}, {"favorite", "#F44366"}, {"local_florist", "#E91E63"},
  {"wb_sunny", "#FF9800"}, {"nightlight", "#7E57C2"}, {"cloud", "#42A5F5"}, {"bolt", "#FDD835"},
  {"music_note", "#AB47BC"}, {"rocket_launch", "#EF5350"}, {"sports_soccer", "#546E7A"}, {"cake", "#EC407A"},
  {"eco", "#66BB6A"}, {"diamond", "#26C6DA"}, {"anchor", "#3949AB"}, {"icecream", "#F48FB1"},
  {"directions_car", "#E53935"}, {"flight", "#1E88E5"}, {"emoji_nature", "#7CB342"}, {"coffee", "#8D6E63"},
  {"beach_access", "#00ACC1"}, {"local_pizza", "#FB8C00"}, {"headphones", "#5C6BC0"}, {"spa", "#26A69A"},
}
local FLIP = 0.32

local sizeIdx = 2
local cols, rows = 4, 4
local cards = {}           -- {icon, up, matched, flipT, matchT, dealT}
local open = {}            -- indices of face-up unmatched cards (max 2)
local hideAt = nil         -- time when a mismatched pair flips back
local moves, elapsed, started, finished = 0, 0, false, false
local twoPlayer = false
local player, pscore = 1, {0, 0}
local cur = {x = 1, y = 1}
local hintIdx, hintT = nil, -10
local best = {}            -- best[tostring(sizeIdx)] = {time, moves}
local stats = {played = 0, solved = 0, hints = 0, p1 = 0, p2 = 0, ties = 0}
local fx = K.particles()
local B = {x = 0, y = 0, cw = 0, ch = 0, g = 0}
local press = nil
local newRecord = false
local combo = 0

-- ------------------------------------------------------------------ persistence
local function saveStats()
  store.set("best", best)
  store.set("stats", stats)
  store.set("two", twoPlayer)
end

local function saveGame()
  local list = {}
  for i, c in ipairs(cards) do list[i] = {c.icon, c.matched and 1 or 0, c.by or 0} end
  store.set("game", {size = sizeIdx, cards = list, moves = moves, time = elapsed, started = started,
                     finished = finished, two = twoPlayer, player = player, ps = pscore})
end

local function newGame()
  local sz = SIZES[sizeIdx]
  cols, rows = sz[1], sz[2]
  local npairs = cols * rows // 2
  local pool = {}
  for i = 1, #ICONS do pool[i] = i end
  for i = #pool, 2, -1 do local j = random(i); pool[i], pool[j] = pool[j], pool[i] end
  local deck = {}
  for i = 1, npairs do deck[#deck + 1] = pool[i]; deck[#deck + 1] = pool[i] end
  for i = #deck, 2, -1 do local j = random(i); deck[i], deck[j] = deck[j], deck[i] end
  cards = {}
  local now = sys.time()
  for i, ic in ipairs(deck) do
    cards[i] = {icon = ic, up = false, matched = false, flipT = -10, matchT = -10, dealT = now + i * 0.03}
  end
  open, hideAt = {}, nil
  moves, elapsed, started, finished, newRecord, combo = 0, 0, false, false, false, 0
  player, pscore = 1, {0, 0}
  cur.x, cur.y = 1, 1
  hintIdx = nil
  F.play()
  K.notes({330, 392, 494}, 0.05, 0.12)
  saveGame()
end

local function loadGame()
  local g = store.get("game")
  if type(g) ~= "table" or type(g.cards) ~= "table" or g.finished then return false end
  local si = floor(tonumber(g.size) or 0)
  if not SIZES[si] or #g.cards ~= SIZES[si][1] * SIZES[si][2] then return false end
  sizeIdx = si
  cols, rows = SIZES[si][1], SIZES[si][2]
  cards = {}
  local now = sys.time()
  for i, c in ipairs(g.cards) do
    if type(c) ~= "table" or not ICONS[tonumber(c[1]) or 0] then return false end
    local m = c[2] == 1
    cards[i] = {icon = floor(c[1]), up = m, matched = m, flipT = -10, matchT = -10, dealT = now + i * 0.02,
                by = tonumber(c[3]) or 0}
  end
  open, hideAt = {}, nil
  moves, elapsed = tonumber(g.moves) or 0, tonumber(g.time) or 0
  started, finished = g.started == true, false
  twoPlayer = g.two == true
  player = g.player == 2 and 2 or 1
  pscore = type(g.ps) == "table" and {tonumber(g.ps[1]) or 0, tonumber(g.ps[2]) or 0} or {0, 0}
  return true
end

-- ------------------------------------------------------------------ rules
local function hideOpen()
  local now = sys.time()
  for _, i in ipairs(open) do
    cards[i].up = false
    cards[i].flipT = now
  end
  open, hideAt = {}, nil
  if twoPlayer then player = 3 - player end
end

local function allMatched()
  for _, c in ipairs(cards) do if not c.matched then return false end end
  return true
end

local function finish()
  finished = true
  local key = tostring(sizeIdx)
  if twoPlayer then
    if pscore[1] > pscore[2] then stats.p1 = stats.p1 + 1
    elseif pscore[2] > pscore[1] then stats.p2 = stats.p2 + 1
    else stats.ties = stats.ties + 1 end
  else
    stats.solved = stats.solved + 1
    local b = type(best[key]) == "table" and best[key] or {}
    newRecord = false
    if not b.time or elapsed < b.time then b.time = elapsed; newRecord = true end
    if not b.moves or moves < b.moves then b.moves = moves; newRecord = true end
    best[key] = b
  end
  saveStats()
  saveGame()
  F.winSound()
  K.rumble(0.5, 90)
  timer.after(0.3, function() F.celebrate(fx, B.x, B.y, B.cw * cols, B.ch * rows) end)
  timer.after(1.2, function() if finished and F.scene == "play" then F.open("won") end end)
end

local function cardCenter(i)
  local c, r = (i - 1) % cols, (i - 1) // cols
  return B.x + c * (B.cw + B.g) + B.cw / 2, B.y + r * (B.ch + B.g) + B.ch / 2
end

local function flip(i)
  if finished or F.modal() then return end
  local c = cards[i]
  if not c or c.up or c.matched then return end
  if #open >= 2 then hideOpen() end
  local now = sys.time()
  if not started then
    started = true
    stats.played = stats.played + 1
    saveStats()
  end
  c.up = true
  c.flipT = now
  open[#open + 1] = i
  hintIdx = nil
  K.tone(700 + random(0, 60), 0.04, 0.16, "triangle")
  if #open == 2 then
    moves = moves + 1
    local a, b = cards[open[1]], cards[open[2]]
    if a.icon == b.icon then
      a.matched, b.matched = true, true
      a.matchT, b.matchT = now + FLIP, now + FLIP
      a.by, b.by = twoPlayer and player or 0, twoPlayer and player or 0
      combo = combo + 1
      if twoPlayer then pscore[player] = pscore[player] + 1 end
      local o1, o2 = open[1], open[2]
      open = {}
      timer.after(FLIP, function()
        local base = 523 * (1 + min(combo, 6) * 0.06)
        F.chord({base, base * 1.26, base * 1.5}, 0.25, 0.28)
        K.rumble(0.25, 25)
        local col = ICONS[a.icon][2]
        for _, k in ipairs({o1, o2}) do
          local x, y = cardCenter(k)
          fx:burst(x, y, 18, col, B.cw * 2.2, 0.6, 4, 0, 3)
        end
      end)
      if allMatched() then finish() end
    else
      combo = 0
      hideAt = now + 0.9
      timer.after(FLIP, function() K.tone(220, 0.08, 0.14, "sine") end)
    end
  end
  saveGame()
end

local function hint()
  if finished or F.modal() then return end
  if #open ~= 1 then K.toast(TR("hint_first")); return end
  local ic = cards[open[1]].icon
  for i, c in ipairs(cards) do
    if i ~= open[1] and c.icon == ic and not c.matched then
      hintIdx, hintT = i, sys.time()
      stats.hints = stats.hints + 1
      saveStats()
      F.chord({660, 880}, 0.15, 0.2, "sine")
      return
    end
  end
end

local function setSize(i)
  i = K.clamp(i, 1, #SIZES)
  if i == sizeIdx then return end
  sizeIdx = i
  store.set("size", sizeIdx)
  newGame()
end

local function setTwo(v)
  if v == twoPlayer then return end
  twoPlayer = v
  saveStats()
  newGame()
end

local function askNew()
  if started and not finished then F.open("confirm") else newGame() end
end

-- ------------------------------------------------------------------ app
function app.load()
  K.loadPrefs()
  local b = store.get("best", {})
  best = type(b) == "table" and b or {}
  local s = store.get("stats", {})
  if type(s) == "table" then for k, v in pairs(stats) do stats[k] = tonumber(s[k]) or v end end
  twoPlayer = store.get("two", false) == true
  sizeIdx = K.clamp(floor(tonumber(store.get("size", 2)) or 2), 1, #SIZES)
  if not loadGame() then newGame() end
  F.open("title")
end

function app.update(dt)
  fx:update(dt)
  if hideAt and sys.time() >= hideAt then hideOpen() end
  if started and not finished and F.scene == "play" then elapsed = elapsed + dt end
  local d = F.stick(dt)
  if d and F.scene == "play" then F.moveCursor(cur, F.DIRV[d][1], F.DIRV[d][2], cols, rows, true) end
end

-- ------------------------------------------------------------------ drawing
local function drawCard(i, now)
  local c = cards[i]
  local cx, cy = cardCenter(i)
  local w, h = B.cw, B.ch
  -- deal-in
  local d = (now - c.dealT) / 0.35
  if d < 0 then return end
  local dk = K.easeOutBack(min(1, d))
  local bx, by = B.x + cols * (B.cw + B.g) / 2, B.y + rows * (B.ch + B.g) / 2
  cx, cy = K.lerp(bx, cx, dk), K.lerp(by, cy, dk)
  -- flip: width follows |cos|, the face switches at the middle
  local p = min(1, (now - c.flipT) / FLIP)
  local showFace
  if p < 0.5 then showFace = not c.up else showFace = c.up end
  local sx = abs(cos(p * pi))
  if p >= 1 then sx = 1 end
  local lift = sin(p * pi) * h * 0.06
  local ww = max(2, w * sx)
  local x, y = cx - ww / 2, cy - h / 2 - lift
  local r = min(w, h) * 0.12
  local hov = press and press.i == i
  gfx.shadow(x, y, ww, h, r, 10 + lift, 3 + lift)
  if showFace then
    local col = ICONS[c.icon][2]
    gfx.rect(x, y, ww, h, r, theme.dark and "#2B2F38" or "#FFFFFF")
    gfx.color(K.col(col, 0.5))
    gfx.rectLine(x, y, ww, h, r, 2)
    if c.matched then
      local mk = (now - c.matchT)
      if mk > 0 then
        local glow = mk < 0.6 and (1 - mk / 0.6) or 0
        gfx.rect(x, y, ww, h, r, K.col(col, 0.14 + glow * 0.3))
      end
      if twoPlayer and c.by and c.by > 0 then
        gfx.circle(x + ww - 10, y + 10, 4, c.by == 1 and theme.blue or theme.orange)
      end
    end
    if sx > 0.15 then
      local pulse = 1
      if c.matched and now - c.matchT < 0.4 and now > c.matchT then pulse = 1 + 0.18 * sin((now - c.matchT) / 0.4 * pi) end
      gfx.icon(ICONS[c.icon][1], cx, y + h / 2, min(w, h) * 0.52 * sx * pulse, col)
    end
  else
    gfx.gradient(x, y, ww, h, hov and "#9D7BE8" or "#8A63E0", "#5B3CC4", false, r)
    gfx.color(K.col("#FFFFFF", 0.18))
    gfx.rectLine(x + 5, y + 5, max(1, ww - 10), h - 10, r * 0.7, 1.5)
    if sx > 0.3 then gfx.icon("psychology", cx, cy - lift, min(w, h) * 0.34 * sx, K.col("#FFFFFF", 0.5)) end
  end
  if hintIdx == i and now - hintT < 1.6 then
    gfx.color(K.col(theme.yellow, 0.6 + 0.4 * sin(now * 10)))
    gfx.rectLine(x - 3, y - 3, ww + 6, h + 6, r + 3, 4)
  end
end

local function drawBoard(now)
  for i = 1, #cards do drawCard(i, now) end
  if not finished and not F.modal() then
    local i = (cur.y - 1) * cols + cur.x
    local cx, cy = cardCenter(i)
    K.ring(cx - B.cw / 2 - 4, cy - B.ch / 2 - 4, B.cw + 8, B.ch + 8, min(B.cw, B.ch) * 0.12 + 4)
  end
  fx:draw()
end

local function bestText(si)
  local b = best[tostring(si)]
  if type(b) ~= "table" or not b.time then return "—" end
  return TR("best_fmt", K.fmtTime(b.time), b.moves or 0)
end

local function drawHints(w, y)
  if K.lastInput == "pad" then
    K.hints({{"dpad", TR("h_move")}, {"A", TR("h_flip")}, {"Y", TR("h_hint")}, {"X", TR("h_new")},
             {{"L", "R"}, TR("h_size")}, {"+", TR("h_pause")}}, 0, y, w)
  elseif K.lastInput == "key" then
    K.hints({{TR("k_arrows"), TR("h_move")}, {"Enter", TR("h_flip")}, {"H", TR("h_hint")}, {"N", TR("h_new")},
             {"1-3", TR("h_size")}, {"Esc", TR("h_pause")}}, 0, y, w)
  else
    K.hints({{"touch", TR("h_tap_card")}}, 0, y, w)
  end
end

local function drawDialogs(w, h)
  local s = F.scene
  if s == "pause" then
    F.pauseDialog(w, h, {onRestart = newGame, onMenu = function() F.open("title") end})
  elseif s == "won" then
    local title, lines = TR("all_found"), {}
    if twoPlayer then
      if pscore[1] > pscore[2] then title = TR("p_wins", 1) elseif pscore[2] > pscore[1] then title = TR("p_wins", 2)
      else title = TR("tie") end
      lines = {{TR("player_n", 1), tostring(pscore[1]), theme.blue}, {TR("player_n", 2), tostring(pscore[2]), theme.orange},
               {TR("moves"), tostring(moves)}}
    else
      lines = {{TR("time"), K.fmtTime(elapsed)}, {TR("moves"), tostring(moves)}, {TR("best"), bestText(sizeIdx)}}
    end
    K.dialog(F.dlg, w, h, {icon = "emoji_events", iconColor = theme.yellow, title = title,
      subtitle = (not twoPlayer and newRecord) and TR("new_record") or nil, lines = lines,
      buttons = {{TR("play_again"), newGame, "primary", "replay"}, {TR("close"), F.close}}})
  else
    F.commonDialogs(w, h, {
      stats = function()
        local lines = {{TR("played"), tostring(stats.played)}, {TR("solved_solo"), tostring(stats.solved)},
                       {TR("hints_used"), tostring(stats.hints)}}
        for i = 1, #SIZES do lines[#lines + 1] = {SIZE_LABELS[i], bestText(i)} end
        lines[#lines + 1] = {TR("duel_line"), TR("duel_fmt", stats.p1, stats.p2, stats.ties)}
        return lines
      end,
      onReset = function() best = {}; stats = {played = 0, solved = 0, hints = 0, p1 = 0, p2 = 0, ties = 0}; saveStats() end,
      onNew = newGame,
    })
  end
end

local function drawTitle(w, h)
  F.titleScreen(w, h, {icon = "style", c1 = "#FF9FD0", c2 = "#D63384", title = TR("title"), subtitle = TR("tagline"),
    extraH = 88,
    extra = function(x, y, bw)
      local ns = ui.segmented("tsize", SIZE_LABELS, sizeIdx, x, y, bw, 32)
      if ns ~= sizeIdx and F.scene == "title" then setSize(ns); F.open("title") end
      local nm = ui.segmented("tmode", {TR("solo"), TR("two_players")}, twoPlayer and 2 or 1, x, y + 42, bw, 32)
      if nm ~= (twoPlayer and 2 or 1) and F.scene == "title" then setTwo(nm == 2); F.open("title") end
    end,
    buttons = {{(started and not finished) and TR("continue") or TR("play"), function()
                  if finished then newGame() else F.play() end
                end, "primary", "play_arrow"},
               {TR("new_game"), newGame, "default", "shuffle"},
               {TR("stats_title"), function() F.open("stats") end, "default", "bar_chart"}},
    footer = TR("best") .. " " .. SIZE_LABELS[sizeIdx] .. ": " .. bestText(sizeIdx)})
end

function app.draw(w, h)
  local now = sys.time()
  gfx.clear(theme.bg)
  if F.scene == "title" or (F.scene ~= "play" and F.returnTo == "title") then
    drawTitle(w, h)
    if F.scene ~= "title" then drawDialogs(w, h) end
    return
  end
  F.title(TR("title"), twoPlayer and TR("turn_of", player) or TR("tagline"), 16, 10)
  local hit = F.toolbar({{"pause", "pause"}, F.soundItem(), {"shuffle", "new"}, {"lightbulb", "hint"}}, w - 16, 14)
  if hit == "sound" then K.setMuted(not K.muted)
  elseif hit == "pause" then F.open("pause")
  elseif hit == "new" then askNew()
  elseif hit == "hint" then hint() end
  local y = 62
  local sw = min(110, floor((w - 48) / 3))
  local x0 = floor((w - 3 * sw - 16) / 2)
  if twoPlayer then
    K.stat(x0, y, sw, 46, TR("player_n", 1), tostring(pscore[1]), theme.blue)
    K.stat(x0 + sw + 8, y, sw, 46, TR("moves_caps"), tostring(moves))
    K.stat(x0 + 2 * (sw + 8), y, sw, 46, TR("player_n", 2), tostring(pscore[2]), theme.orange)
    local px = player == 1 and x0 or x0 + 2 * (sw + 8)
    gfx.color(player == 1 and theme.blue or theme.orange)
    gfx.rectLine(px - 2, y - 2, sw + 4, 50, 12, 2)
  else
    local found = 0
    for _, c in ipairs(cards) do if c.matched then found = found + 1 end end
    K.stat(x0, y, sw, 46, TR("time_caps"), K.fmtTime(elapsed), theme.blue)
    K.stat(x0 + sw + 8, y, sw, 46, TR("moves_caps"), tostring(moves), theme.orange)
    K.stat(x0 + 2 * (sw + 8), y, sw, 46, TR("pairs_caps"), (found // 2) .. "/" .. (#cards // 2), theme.green)
  end
  -- board layout: cards are 3:4
  local top, bottom = y + 60, h - 36
  local aw, ah = w - 32, bottom - top
  local g = 10
  local cw = (aw - g * (cols - 1)) / cols
  local ch = (ah - g * (rows - 1)) / rows
  if ch > cw * 1.33 then ch = cw * 1.33 else cw = min(cw, ch / 1.1) end
  B.cw, B.ch, B.g = cw, ch, g
  B.x = floor((w - (cw * cols + g * (cols - 1))) / 2)
  B.y = floor(top + (ah - (ch * rows + g * (rows - 1))) / 2)
  drawBoard(now)
  drawHints(w, h - 28)
  drawDialogs(w, h)
  K.drawToast(w, h - 80)
end

-- ------------------------------------------------------------------ input
local function cardAt(x, y)
  if B.cw <= 0 then return nil end
  local c = floor((x - B.x) / (B.cw + B.g))
  local r = floor((y - B.y) / (B.ch + B.g))
  if c < 0 or r < 0 or c >= cols or r >= rows then return nil end
  if x - B.x - c * (B.cw + B.g) > B.cw or y - B.y - r * (B.ch + B.g) > B.ch then return nil end
  return r * cols + c + 1
end

function app.event(e)
  K.track(e)
  local t = e.type
  if F.modal() then F.dialogEvent(e); return end
  if t == "paddown" then
    local p = e.pad
    local d = F.DIRV[p]
    if d then F.moveCursor(cur, d[1], d[2], cols, rows, true)
    elseif p == "a" then
      if finished then F.open("won") else flip((cur.y - 1) * cols + cur.x) end
    elseif p == "y" then hint()
    elseif p == "x" or p == "minus" then askNew()
    elseif p == "l" then setSize(sizeIdx - 1)
    elseif p == "r" then setSize(sizeIdx + 1)
    elseif p == "plus" or p == "b" then F.open("pause") end
  elseif t == "keydown" then
    local k = e.key
    local d = F.DIRV[k]
    if d then F.moveCursor(cur, d[1], d[2], cols, rows, true)
    elseif k == "enter" or k == "space" then flip((cur.y - 1) * cols + cur.x)
    elseif k == "h" then hint()
    elseif k == "n" or k == "f2" then askNew()
    elseif k == "1" or k == "2" or k == "3" then setSize(tonumber(k))
    elseif k == "escape" or k == "p" then F.open("pause") end
  elseif t == "mousedown" then
    press = {i = cardAt(e.x, e.y)}
  elseif t == "mouseup" then
    local i = cardAt(e.x, e.y)
    if press and i and press.i == i and not e.cancel then
      cur.x, cur.y = (i - 1) % cols + 1, (i - 1) // cols + 1
      flip(i)
    end
    press = nil
  end
end

function app.menu()
  local items = {{label = TR("new_game"), id = 1, shortcut = "N"}, {label = TR("hint"), id = 2, shortcut = "H"}, "-"}
  for i = 1, #SIZES do items[#items + 1] = {label = SIZE_LABELS[i], id = 10 + i, checked = i == sizeIdx} end
  items[#items + 1] = "-"
  items[#items + 1] = {label = TR("solo"), id = 21, checked = not twoPlayer}
  items[#items + 1] = {label = TR("two_players"), id = 22, checked = twoPlayer}
  items[#items + 1] = "-"
  items[#items + 1] = {label = TR("sound"), id = 3, checked = not K.muted}
  items[#items + 1] = {label = TR("stats_title"), id = 4}
  return {{title = TR("menu_game"), items = items}}
end

function app.onmenu(id)
  if id == 1 then askNew()
  elseif id == 2 then hint()
  elseif id == 3 then K.setMuted(not K.muted)
  elseif id == 4 then F.open("stats")
  elseif id > 10 and id <= 10 + #SIZES then setSize(id - 10)
  elseif id == 21 then setTwo(false)
  elseif id == 22 then setTwo(true) end
end

function app.close()
  saveGame()
  saveStats()
  return true
end

return app
