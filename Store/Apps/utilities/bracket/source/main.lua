-- Bracket for Nexvyn OS: run tournaments for game nights and clubs. Single elimination with seeding and byes, round
-- robin with a full schedule, and Swiss rounds paired by score. Enter scores by touch, controller or keyboard; the
-- bracket advances, standings update with tiebreaks, and the champion gets a moment. Undo, export and backups.
local K = require("kit")
local app = {}

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local clamp, alpha, mix = K.clamp, K.alpha, K.mix

-- ================================================================== state
local tours, cur = {}, nil
local screen = "home"                -- home | setup | play
local hist = K.history(80)
local dirty, changedAt = false, 0
local sheet = nil                    -- score entry {m, sa, sb, row, t}
local selMatch = 1
local pan = {x = 0, y = 0}
local dragPan = nil
local panelTab = 1                   -- round robin / swiss: 1 matches, 2 standings
local confetti = nil
local homeScroll, listScroll = K.scroller(), K.scroller()
local homeRect, listRect = {0, 0, 0, 0}, {0, 0, 0, 0}
local newName = ""
local frameDt = 1 / 60
local FORMATS = {"single", "round", "swiss"}

local function now() return sys.epoch() end
local function markDirty() dirty, changedAt = true, sys.time(); if cur then cur.updated = now() end end
local function playerName(id)
  if not id then return nil end
  for _, p in ipairs(cur.players) do if p.id == id then return p.name end end
  return "?"
end
local function matchById(id) for _, m in ipairs(cur.matches) do if m.id == id then return m end end return nil end

-- ================================================================== generators
local function seedOrder(size)
  local order = {1}
  while #order < size do
    local n = #order * 2
    local nxt = {}
    for _, s in ipairs(order) do nxt[#nxt + 1] = s; nxt[#nxt + 1] = n + 1 - s end
    order = nxt
  end
  return order
end

local function propagate(t, m)
  -- a decided match sends its winner on; a bye (one side empty in round 1) decides itself
  if t.format ~= "single" then return end
  if not m.next then return end
  local nm
  for _, x in ipairs(t.matches) do if x.id == m.next then nm = x end end
  if not nm then return end
  local val = m.winner
  if m.slot == 1 then nm.a = val else nm.b = val end
end

local function genSingle(t)
  local n = #t.players
  local size = 1
  while size < n do size = size * 2 end
  local order = seedOrder(size)
  local rounds = floor(math.log(size, 2) + 0.5)
  t.rounds = rounds
  t.matches = {}
  local id = 1
  local byRound = {}
  for r = 1, rounds do
    byRound[r] = {}
    local count = size / 2 ^ r
    for i = 1, count do
      local m = {id = id, round = r, idx = i, sa = 0, sb = 0}
      id = id + 1
      t.matches[#t.matches + 1] = m
      byRound[r][i] = m
    end
  end
  for r = 1, rounds - 1 do
    for i, m in ipairs(byRound[r]) do
      m.next = byRound[r + 1][floor((i + 1) / 2)].id
      m.slot = (i % 2 == 1) and 1 or 2
    end
  end
  for i, m in ipairs(byRound[1]) do
    local sa, sb = order[i * 2 - 1], order[i * 2]
    m.a = t.players[sa] and t.players[sa].id or nil
    m.b = t.players[sb] and t.players[sb].id or nil
  end
  -- byes
  for _, m in ipairs(byRound[1]) do
    if m.a and not m.b then m.winner, m.bye = m.a, true; propagate(t, m)
    elseif m.b and not m.a then m.winner, m.bye = m.b, true; propagate(t, m) end
  end
end

local function genRound(t)
  local ids = {}
  for _, p in ipairs(t.players) do ids[#ids + 1] = p.id end
  if #ids % 2 == 1 then ids[#ids + 1] = false end
  local n = #ids
  t.matches = {}
  t.rounds = n - 1
  local id = 1
  for r = 1, n - 1 do
    for i = 1, n / 2 do
      local a, b = ids[i], ids[n + 1 - i]
      if a and b then
        if r % 2 == 0 and i == 1 then a, b = b, a end
        t.matches[#t.matches + 1] = {id = id, round = r, a = a, b = b, sa = 0, sb = 0}
        id = id + 1
      end
    end
    -- rotate all but the first
    local last = table.remove(ids)
    table.insert(ids, 2, last)
  end
end

local function standings(t)
  local rows, by = {}, {}
  for _, p in ipairs(t.players) do
    local r = {id = p.id, name = p.name, p = 0, w = 0, d = 0, l = 0, pts = 0, diff = 0, opp = {}, buch = 0}
    rows[#rows + 1] = r
    by[p.id] = r
  end
  for _, m in ipairs(t.matches) do
    if m.done and m.a and m.b then
      local A, B = by[m.a], by[m.b]
      if A and B then
        A.p, B.p = A.p + 1, B.p + 1
        A.diff, B.diff = A.diff + m.sa - m.sb, B.diff + m.sb - m.sa
        A.opp[#A.opp + 1], B.opp[#B.opp + 1] = m.b, m.a
        if m.sa > m.sb then A.w, B.l, A.pts = A.w + 1, B.l + 1, A.pts + 3
        elseif m.sb > m.sa then B.w, A.l, B.pts = B.w + 1, A.l + 1, B.pts + 3
        else A.d, B.d, A.pts, B.pts = A.d + 1, B.d + 1, A.pts + 1, B.pts + 1 end
      end
    elseif m.done and m.a and not m.b and by[m.a] then
      by[m.a].pts = by[m.a].pts + 3; by[m.a].w = by[m.a].w + 1; by[m.a].bye = true
    end
  end
  for _, r in ipairs(rows) do for _, o in ipairs(r.opp) do r.buch = r.buch + (by[o] and by[o].pts or 0) end end
  table.sort(rows, function(a, b)
    if a.pts ~= b.pts then return a.pts > b.pts end
    if t.format == "swiss" and a.buch ~= b.buch then return a.buch > b.buch end
    if a.diff ~= b.diff then return a.diff > b.diff end
    return a.name < b.name
  end)
  return rows
end

local function swissNext(t)
  local round = 0
  for _, m in ipairs(t.matches) do round = max(round, m.round) end
  for _, m in ipairs(t.matches) do if m.round == round and not m.done then return false end end
  if round >= t.rounds then return false end
  local rows = standings(t)
  local played = {}
  for _, m in ipairs(t.matches) do
    if m.a and m.b then played[m.a .. ":" .. m.b] = true; played[m.b .. ":" .. m.a] = true end
  end
  local pool = {}
  for _, r in ipairs(rows) do pool[#pool + 1] = r end
  local nextId = #t.matches + 1
  local out = {}
  -- the lowest player without a bye sits out on odd counts
  if #pool % 2 == 1 then
    for i = #pool, 1, -1 do
      if not pool[i].bye then
        out[#out + 1] = {id = nextId, round = round + 1, a = pool[i].id, b = nil, sa = 0, sb = 0, done = true, bye = true, winner = pool[i].id}
        nextId = nextId + 1
        table.remove(pool, i)
        break
      end
    end
    if #pool % 2 == 1 then table.remove(pool) end
  end
  local function pair(list)
    if #list == 0 then return {} end
    local a = list[1]
    for j = 2, #list do
      if not played[a.id .. ":" .. list[j].id] then
        local rest = {}
        for k = 2, #list do if k ~= j then rest[#rest + 1] = list[k] end end
        local sub = pair(rest)
        if sub then table.insert(sub, 1, {a, list[j]}); return sub end
      end
    end
    return nil
  end
  local pairs_ = pair(pool)
  if not pairs_ then
    pairs_ = {}
    for i = 1, #pool - 1, 2 do pairs_[#pairs_ + 1] = {pool[i], pool[i + 1]} end
  end
  for _, pr in ipairs(pairs_) do
    out[#out + 1] = {id = nextId, round = round + 1, a = pr[1].id, b = pr[2].id, sa = 0, sb = 0}
    nextId = nextId + 1
  end
  for _, m in ipairs(out) do t.matches[#t.matches + 1] = m end
  return true
end

local function genSwiss(t)
  t.matches = {}
  t.rounds = max(1, math.ceil(math.log(max(2, #t.players), 2)))
  swissNext(t)
end

local function generate(t)
  t.matches = {}
  t.champion = nil
  if #t.players < 2 then return end
  if t.format == "single" then genSingle(t) elseif t.format == "round" then genRound(t) else genSwiss(t) end
end

-- ================================================================== results
local function clearDownstream(t, m)
  if t.format ~= "single" or not m.next then return end
  local nm = matchById(m.next)
  if not nm then return end
  if nm.done then nm.done, nm.winner, nm.sa, nm.sb = false, nil, 0, 0; clearDownstream(t, nm) end
end

local function finalWinner(t)
  if t.format == "single" then
    for _, m in ipairs(t.matches) do if m.round == t.rounds and m.done then return m.winner end end
    return nil
  end
  for _, m in ipairs(t.matches) do if not m.done then return nil end end
  if t.format == "swiss" then
    local maxR = 0
    for _, m in ipairs(t.matches) do maxR = max(maxR, m.round) end
    if maxR < t.rounds then return nil end
  end
  local s = standings(t)
  return s[1] and s[1].id
end

local function setResult(m, sa, sb)
  if cur.format == "single" and sa == sb then K.toast(TR("no_draws"), "info"); return false end
  hist:push(K.copy(cur))
  local before = m.winner
  m.sa, m.sb = sa, sb
  m.done = true
  m.winner = sa > sb and m.a or (sb > sa and m.b or nil)
  if cur.format == "single" then
    if before ~= m.winner then clearDownstream(cur, m) end
    propagate(cur, m)
  elseif cur.format == "swiss" then
    swissNext(cur)
  end
  local champ = finalWinner(cur)
  if champ and champ ~= cur.champion then
    cur.champion = champ
    confetti = {t = 0, parts = {}}
    for i = 1, 90 do
      confetti.parts[i] = {x = math.random(), y = -math.random() * 0.4, vx = (math.random() - 0.5) * 0.3, vy = 0.2 + math.random() * 0.5,
                           c = ({theme.red, theme.orange, theme.yellow, theme.green, theme.blue, theme.purple, theme.pink})[i % 7 + 1], r = math.random() * 6}
    end
    audio.play("notify", 0.7)
  elseif not champ then cur.champion = nil end
  markDirty()
  return true
end

local function undo() local s = hist:undo(K.copy(cur)); if s then for i, t in ipairs(tours) do if t == cur then tours[i] = s end end; cur = s; markDirty(); K.toast(TR("undone"), "undo") end end
local function redo() local s = hist:redo(K.copy(cur)); if s then for i, t in ipairs(tours) do if t == cur then tours[i] = s end end; cur = s; markDirty(); K.toast(TR("redone"), "redo") end end

-- ================================================================== tournaments
local function newTour(name, format, names)
  local t = {id = now() + math.random(1000), name = name, format = format, players = {}, matches = {}, rounds = 0, created = now(), updated = now(), started = false}
  for i, nm in ipairs(names or {}) do t.players[i] = {id = i, name = nm} end
  t.nextPid = #t.players + 1
  return t
end
local function demo()
  local t = newTour(TR("demo_name"), "single", {"Ada", "Bora", "Cem", "Defne", "Ece", "Firat", "Gaia", "Hiro"})
  t.started = true
  generate(t)
  local prev = cur
  cur = t
  local r1 = {}
  for _, m in ipairs(t.matches) do if m.round == 1 then r1[#r1 + 1] = m end end
  local scores = {{3, 1}, {2, 3}, {3, 0}, {1, 3}}
  for i, m in ipairs(r1) do
    m.sa, m.sb, m.done = scores[i][1], scores[i][2], true
    m.winner = m.sa > m.sb and m.a or m.b
    propagate(t, m)
  end
  for _, m in ipairs(t.matches) do
    if m.round == 2 and m.idx == 1 then m.sa, m.sb, m.done = 3, 2, true; m.winner = m.a; propagate(t, m) end
  end
  cur = prev
  local t2 = newTour(TR("demo_league"), "round", {"Lions", "Owls", "Foxes", "Bears", "Wolves"})
  t2.started = true
  generate(t2)
  local s2 = {{2, 1}, {0, 0}, {3, 1}, {1, 2}}
  for i = 1, 4 do local m = t2.matches[i]; if m then m.sa, m.sb, m.done = s2[i][1], s2[i][2], true; m.winner = m.sa > m.sb and m.a or (m.sb > m.sa and m.b or nil) end end
  t2.updated = now() - 100
  return {t, t2}
end

local function saveNow()
  store.set("tours", tours)
  store.set("cur", cur and cur.id or 0)
  dirty = false
end
local function loadAll()
  tours = {}
  local raw = store.get("tours", nil)
  if type(raw) == "table" then
    for _, t in ipairs(raw) do
      if type(t) == "table" and type(t.players) == "table" and type(t.matches) == "table" then
        t.format = (t.format == "round" or t.format == "swiss") and t.format or "single"
        t.name = K.str(t.name, TR("untitled"))
        t.nextPid = K.int(t.nextPid, #t.players + 1)
        tours[#tours + 1] = t
      end
    end
  end
  if #tours == 0 then tours = demo() end
  local id = store.get("cur", 0)
  for _, t in ipairs(tours) do if t.id == id then cur = t end end
  if cur then screen = cur.started and "play" or "setup" end
end

local function openTour(t)
  cur = t
  screen = t.started and "play" or "setup"
  hist:clear()
  pan = {x = 0, y = 0}
  selMatch = 1
  confetti = nil
  saveNow()
end

local function resultsText(t)
  local out = {t.name, string.rep("=", 24)}
  if t.format == "single" then
    for r = 1, t.rounds do
      out[#out + 1] = ""
      out[#out + 1] = (r == t.rounds and TR("final")) or (r == t.rounds - 1 and TR("semifinals")) or TR("round_n", r)
      for _, m in ipairs(t.matches) do
        if m.round == r and (m.a or m.b) then
          out[#out + 1] = string.format("  %s %s – %s %s", playerName(m.a) or TR("bye"), m.done and m.sa or "", m.done and m.sb or "", playerName(m.b) or TR("bye"))
        end
      end
    end
  else
    out[#out + 1] = ""
    for i, r in ipairs(standings(t)) do
      out[#out + 1] = string.format("%2d. %-16s %2d %s  %d-%d-%d  %+d", i, r.name, r.pts, TR("pts"), r.w, r.d, r.l, r.diff)
    end
  end
  if t.champion then out[#out + 1] = ""; out[#out + 1] = TR("champion_is", playerName(t.champion)) end
  return table.concat(out, "\n") .. "\n"
end

-- ================================================================== drawing: home
local function drawHome(w, h)
  local M = K.metrics(w, h)
  local p = M.pad + 6
  gfx.color(theme.text)
  gfx.text(TR("app_name"), p, 18, 22, "bold")
  if ui.button(TR("new_tour"), w - p - 170, 14, 170, 36, "primary", "add") then
    local t = newTour(TR("tour_n", #tours + 1), "single", {})
    table.insert(tours, 1, t)
    openTour(t)
    markDirty()
    return
  end
  local top = 66
  local cols = max(1, floor((w - p * 2 + 16) / 300))
  local cw = floor((w - p * 2 - (cols - 1) * 16) / cols)
  local chh = 120
  homeRect = {0, top, w, h - top}
  homeScroll:setMax(math.ceil(#tours / cols) * (chh + 16) + 20 - (h - top))
  gfx.clip(0, top, w, h - top)
  if #tours == 0 then K.empty("emoji_events", TR("no_tours"), TR("no_tours_hint"), 0, top, w, h - top) end
  for i, t in ipairs(tours) do
    local c, r = (i - 1) % cols, floor((i - 1) / cols)
    local x, y = p + c * (cw + 16), top + 6 + r * (chh + 16) - homeScroll.y
    if y + chh > top and y < h then
      local hit = ui.hit("tc" .. i, x, y, cw, chh)
      gfx.shadow(x, y, cw, chh, 14, hit.hovered and 14 or 8, 3)
      gfx.rect(x, y, cw, chh, 14, theme.window)
      local col = t.format == "single" and theme.orange or (t.format == "round" and theme.blue or theme.purple)
      gfx.rect(x, y, 6, chh, 3, col)
      gfx.icon(t.format == "single" and "account_tree" or (t.format == "round" and "grid_view" or "swap_horiz"), x + 32, y + 30, 24, col)
      gfx.color(theme.text)
      gfx.text(K.ellipsize(t.name, 16, "semibold", cw - 70), x + 56, y + 18, 16, "semibold")
      gfx.color(theme.text2)
      local fmt = t.format == "single" and TR("f_single") or (t.format == "round" and TR("f_round") or TR("f_swiss"))
      gfx.text(fmt .. " · " .. TR("players_n", #t.players), x + 56, y + 42, 13)
      local done, total = 0, 0
      for _, m in ipairs(t.matches) do if m.a and m.b then total = total + 1; if m.done then done = done + 1 end end end
      if t.champion then
        gfx.icon("emoji_events", x + 30, y + chh - 28, 20, theme.yellow)
        gfx.color(theme.text)
        gfx.text(K.ellipsize(TR("champion_is", (function() for _, pl in ipairs(t.players) do if pl.id == t.champion then return pl.name end end return "?" end)()), 13, "semibold", cw - 60), x + 46, y + chh - 37, 13, "semibold")
      elseif t.started and total > 0 then
        ui.progress(done / total, x + 20, y + chh - 30, cw - 40, 6)
        gfx.color(theme.text3)
        gfx.text(TR("matches_done", done, total), x + 20, y + chh - 50, 12)
      else
        gfx.color(theme.text3)
        gfx.text(TR("not_started"), x + 20, y + chh - 40, 12, "italic")
      end
      if hit.clicked and not homeScroll:dragged() then openTour(t) end
      if hit.rightClicked then
        ui.contextMenu({{label = TR("rename"), id = 1, icon = "edit"}, {label = TR("duplicate"), id = 2, icon = "content_copy"}, "-",
                        {label = TR("delete"), id = 3, icon = "delete"}}, function(id)
          if id == 1 then ui.prompt(TR("rename"), TR("tour_name"), t.name, function(s) if s and K.trim(s) ~= "" then t.name = K.trim(s); markDirty() end end)
          elseif id == 2 then local c2 = K.copy(t); c2.id = now() + math.random(100000); c2.name = TR("copy_of", t.name); table.insert(tours, 1, c2); markDirty()
          elseif id == 3 then
            ui.alert(TR("delete_tour"), TR("delete_tour_msg", t.name), {TR("delete"), TR("cancel")}, function(b)
              if b == 1 then for k, x2 in ipairs(tours) do if x2 == t then table.remove(tours, k) end end; if cur == t then cur = nil end; markDirty() end
            end)
          end
        end)
      end
    end
  end
  gfx.unclip()
end

-- ================================================================== drawing: setup
local function drawSetup(w, h)
  local t = cur
  local p = 20
  local cw = min(w - p * 2, 700)
  local cx = floor((w - cw) / 2)
  local yy = 14
  if ui.iconButton("arrow_back", 10, 10, 36, 34, theme.text2, false, "##home") then screen = "home"; saveNow(); return end
  gfx.color(theme.text)
  gfx.text(TR("setup"), 54, 18, 18, "bold")
  yy = 60
  gfx.color(theme.text2); gfx.text(TR("tour_name"), cx, yy, 12, "medium")
  local nn = K.field("tname", t.name, cx, yy + 18, cw, 34)
  if nn ~= t.name then t.name = nn; markDirty() end
  yy = yy + 64
  gfx.color(theme.text2); gfx.text(TR("format"), cx, yy, 12, "medium")
  local fi = 1
  for i, f in ipairs(FORMATS) do if f == t.format then fi = i end end
  local nf = ui.segmented("fmt", {TR("f_single"), TR("f_round"), TR("f_swiss")}, fi, cx, yy + 18, cw, 32)
  if nf ~= fi then t.format = FORMATS[nf]; markDirty() end
  yy = yy + 56
  gfx.color(theme.text3)
  local FDESC = {single = "fdesc_single", round = "fdesc_round", swiss = "fdesc_swiss"}
  yy = yy + gfx.wrap(TR(FDESC[t.format]), cx, yy, cw, 13) + 12
  K.heading(TR("players_n", #t.players), cx, yy, cw)
  yy = yy + 22
  local addW = cw - 50
  local np, sub = K.field("newp", newName, cx, yy, addW, 34, TR("add_player_ph"))
  newName = np
  local addHit = ui.iconButton("person_add", cx + cw - 44, yy, 44, 34, theme.accent, false, "##padd")
  if (sub or addHit) and K.trim(newName) ~= "" then
    t.players[#t.players + 1] = {id = t.nextPid, name = K.trim(newName)}
    t.nextPid = t.nextPid + 1
    newName = ""
    markDirty()
    K.focus("newp")
  end
  yy = yy + 44
  local listH = h - yy - 70
  listRect = {cx, yy, cw, listH}
  listScroll:setMax(#t.players * 40 - listH)
  gfx.clip(cx - 4, yy, cw + 8, listH)
  for i, pl in ipairs(t.players) do
    local ry = yy + (i - 1) * 40 - listScroll.y
    if ry > yy - 40 and ry < yy + listH then
      gfx.rect(cx, ry, cw, 36, 8, alpha(theme.text, 0.04))
      gfx.color(theme.text3)
      gfx.text(tostring(i), cx + 8, ry + 9, 13, "mono", "right", 22)
      gfx.color(theme.text)
      gfx.text(K.ellipsize(pl.name, 14, "medium", cw - 170), cx + 40, ry + 9, 14, "medium")
      if ui.iconButton("arrow_upward", cx + cw - 116, ry + 2, 36, 32, theme.text3, false, "##pu" .. i) and i > 1 then
        t.players[i], t.players[i - 1] = t.players[i - 1], t.players[i]; markDirty()
      end
      if ui.iconButton("edit", cx + cw - 78, ry + 2, 36, 32, theme.text3, false, "##pe" .. i) then
        ui.prompt(TR("rename"), TR("player_name"), pl.name, function(s) if s and K.trim(s) ~= "" then pl.name = K.trim(s); markDirty() end end)
      end
      if ui.iconButton("close", cx + cw - 40, ry + 2, 36, 32, theme.text3, false, "##px" .. i) then table.remove(t.players, i); markDirty(); break end
    end
  end
  gfx.unclip()
  if #t.players == 0 then gfx.color(theme.text3); gfx.wrap(TR("players_hint"), cx, yy + 8, cw, 13) end
  local by = h - 56
  local bw = floor((cw - 12) / 3)
  if ui.button(TR("shuffle"), cx, by, bw, 38, "default", "shuffle") then
    for i = #t.players, 2, -1 do local j = math.random(i); t.players[i], t.players[j] = t.players[j], t.players[i] end
    markDirty()
  end
  if ui.button(TR("paste_names"), cx + bw + 6, by, bw, 38, "default", "content_paste") then
    local clip = sys.clipboard() or ""
    local n = 0
    for line in (clip .. "\n"):gmatch("(.-)\r?\n") do
      local nm = K.trim(line:gsub("^%d+[.)]%s*", ""))
      if nm ~= "" and #t.players < 64 then t.players[#t.players + 1] = {id = t.nextPid, name = K.utf8sub(nm, 1, 32)}; t.nextPid = t.nextPid + 1; n = n + 1 end
    end
    K.toast(TR("added_n", n), "person_add")
    markDirty()
  end
  if ui.button(TR("start"), cx + (bw + 6) * 2, by, bw, 38, "primary", "play_arrow", #t.players >= 2) then
    if #t.players >= 2 then
      t.started = true
      generate(t)
      hist:clear()
      screen = "play"
      pan = {x = 0, y = 0}
      markDirty()
      audio.play("pop", 0.4)
    end
  end
end

-- ================================================================== drawing: play
local BOX_W, BOX_H, GAP_X = 200, 62, 56
local function matchLayout(t)
  local L = {}
  local r1 = 0
  for _, m in ipairs(t.matches) do if m.round == 1 then r1 = r1 + 1 end end
  local slotH = BOX_H + 18
  for _, m in ipairs(t.matches) do
    local count = r1 / 2 ^ (m.round - 1)
    local span = (r1 * slotH) / count
    L[m.id] = {x = (m.round - 1) * (BOX_W + GAP_X), y = (m.idx - 1) * span + span / 2 - BOX_H / 2}
  end
  return L, r1 * slotH, t.rounds * (BOX_W + GAP_X)
end

local function drawMatchBox(m, x, y, w, selected)
  local hit = ui.hit("mb" .. m.id, x, y, w, BOX_H)
  gfx.shadow(x, y, w, BOX_H, 10, selected and 14 or 6, 2)
  gfx.rect(x, y, w, BOX_H, 10, theme.window)
  if selected then gfx.color(theme.accent); gfx.rectLine(x, y, w, BOX_H, 10, 2.5) end
  local rows = {{m.a, m.sa}, {m.b, m.sb}}
  for i, r in ipairs(rows) do
    local ry = y + (i - 1) * (BOX_H / 2)
    local name = playerName(r[1])
    local isW = m.done and m.winner and m.winner == r[1]
    if isW then gfx.rect(x + 2, ry + 2, w - 4, BOX_H / 2 - 4, 8, alpha(theme.green, 0.14)) end
    gfx.color(name and (isW and theme.text or (m.done and theme.text3 or theme.text)) or theme.text3)
    gfx.text(K.ellipsize(name or (m.bye and TR("bye") or TR("tbd")), 14, isW and "bold" or "medium", w - 60), x + 12, ry + 7, 14, isW and "bold" or (name and "medium" or "italic"))
    if m.done and not m.bye then
      gfx.color(isW and theme.green or theme.text2)
      gfx.text(tostring(r[2]), x + w - 40, ry + 7, 15, "monobold", "right", 30)
    end
  end
  gfx.color(theme.separator)
  gfx.line(x + 8, y + BOX_H / 2, x + w - 8, y + BOX_H / 2, 1)
  return hit
end

local function openSheet(m)
  if not m or not m.a or not m.b then return end
  sheet = {m = m, sa = m.done and m.sa or 0, sb = m.done and m.sb or 0, row = 1, t = 0}
end

local function playable(t)
  local out = {}
  for _, m in ipairs(t.matches) do if m.a and m.b then out[#out + 1] = m end end
  return out
end

local function drawBracket(x, y, w, h)
  local t = cur
  local L, totalH, totalW = matchLayout(t)
  local ox, oy = x + 30 + pan.x, y + 40 + pan.y
  local bg = ui.hit("bracketbg", x, y, w, h)
  if bg.pressed then local mx, my = ui.mouse(); dragPan = {mx = mx, my = my, px = pan.x, py = pan.y} end
  if bg.held and dragPan then local mx, my = ui.mouse(); pan.x, pan.y = dragPan.px + mx - dragPan.mx, dragPan.py + my - dragPan.my end
  if not bg.held then dragPan = nil end
  -- round titles
  for r = 1, t.rounds do
    local title = (r == t.rounds and TR("final")) or (r == t.rounds - 1 and TR("semifinals")) or (r == t.rounds - 2 and t.rounds >= 4 and TR("quarterfinals")) or TR("round_n", r)
    gfx.color(theme.text2)
    gfx.text(title:upper(), ox + (r - 1) * (BOX_W + GAP_X), oy - 30, 11, "semibold", "center", BOX_W)
  end
  -- connectors
  gfx.color(alpha(theme.text, 0.3))
  for _, m in ipairs(t.matches) do
    if m.next then
      local a, b = L[m.id], L[m.next]
      local x1, y1 = ox + a.x + BOX_W, oy + a.y + BOX_H / 2
      local x2, y2 = ox + b.x, oy + b.y + (m.slot == 1 and BOX_H / 4 or BOX_H * 3 / 4)
      local mx = x1 + GAP_X / 2
      gfx.color(m.done and alpha(theme.green, 0.7) or alpha(theme.text, 0.3))
      gfx.lines({x1, y1, mx, y1, mx, y2, x2, y2}, 2, false)
    end
  end
  local pl = playable(t)
  local selId = pl[selMatch] and pl[selMatch].id
  for _, m in ipairs(t.matches) do
    local p = L[m.id]
    local bx, by = ox + p.x, oy + p.y
    if bx + BOX_W > x and bx < x + w and by + BOX_H > y and by < y + h then
      local hit = drawMatchBox(m, bx, by, BOX_W, m.id == selId)
      if hit.clicked and not (dragPan and (abs(pan.x - dragPan.px) > 6 or abs(pan.y - dragPan.py) > 6)) then
        for i, x2 in ipairs(pl) do if x2 == m then selMatch = i end end
        openSheet(m)
      end
    end
  end
  -- champion trophy at the end of the bracket
  if t.champion then
    local fx = ox + t.rounds * (BOX_W + GAP_X) - GAP_X + 30
    local final = nil
    for _, m in ipairs(t.matches) do if m.round == t.rounds then final = m end end
    local fy = oy + (final and L[final.id].y or 0) + BOX_H / 2
    gfx.circle(fx + 40, fy, 34, alpha(theme.yellow, 0.25))
    gfx.icon("emoji_events", fx + 40, fy, 40, theme.yellow)
    gfx.color(theme.text)
    gfx.text(playerName(t.champion), fx - 20, fy + 40, 15, "bold", "center", 120)
  end
end

local function drawTable(x, y, w, h)
  local t = cur
  local rows = standings(t)
  local p = 16
  local cols = {{TR("c_pos"), 36}, {TR("c_player"), 0}, {TR("c_p"), 44}, {TR("c_w"), 40}, {TR("c_d"), 40}, {TR("c_l"), 40}, {"±", 52}, {TR("c_pts"), 56}}
  if t.format == "swiss" then table.insert(cols, 8, {TR("c_buch"), 56}) end
  local fixed = 0
  for _, c in ipairs(cols) do fixed = fixed + c[2] end
  local nameW = max(100, w - p * 2 - fixed)
  local yy = y + 10
  local cx = x + p
  for _, c in ipairs(cols) do
    gfx.color(theme.text2)
    local cwid = c[2] > 0 and c[2] or nameW
    gfx.text(c[1], cx, yy, 12, "semibold", c[2] > 0 and "center" or "left", cwid)
    cx = cx + cwid
  end
  yy = yy + 24
  for i, r in ipairs(rows) do
    if i % 2 == 1 then gfx.rect(x + p - 6, yy - 4, w - p * 2 + 12, 30, 6, alpha(theme.text, 0.04)) end
    if t.champion == r.id then gfx.icon("emoji_events", x + p + 18, yy + 11, 16, theme.yellow)
    else gfx.color(theme.text2); gfx.text(tostring(i), x + p, yy + 3, 14, "mono", "center", 36) end
    cx = x + p + 36
    gfx.color(theme.text)
    gfx.text(K.ellipsize(r.name, 14, "semibold", nameW - 10), cx, yy + 3, 14, "semibold")
    cx = cx + nameW
    local vals = {r.p, r.w, r.d, r.l, (r.diff > 0 and "+" or "") .. r.diff}
    if t.format == "swiss" then vals[#vals + 1] = r.buch end
    vals[#vals + 1] = r.pts
    for k, v in ipairs(vals) do
      local cwid = cols[k + 2][2]
      gfx.color(k == #vals and theme.accent or theme.text)
      gfx.text(tostring(v), cx, yy + 3, 14, k == #vals and "monobold" or "mono", "center", cwid)
      cx = cx + cwid
    end
    yy = yy + 32
  end
end

local function drawRounds(x, y, w, h)
  local t = cur
  local pl = playable(t)
  local selId = pl[selMatch] and pl[selMatch].id
  local yy = y + 10 - listScroll.y
  local p = 16
  listRect = {x, y, w, h}
  local start = yy
  gfx.clip(x, y, w, h)
  local maxR = 0
  for _, m in ipairs(t.matches) do maxR = max(maxR, m.round) end
  local colsN = max(1, floor((w - p * 2 + 12) / 300))
  local bw = floor((w - p * 2 - (colsN - 1) * 12) / colsN)
  for r = 1, maxR do
    K.heading(TR("round_n", r), x + p, yy, w - p * 2)
    yy = yy + 24
    local k = 0
    for _, m in ipairs(t.matches) do
      if m.round == r then
        local c = k % colsN
        local bx = x + p + c * (bw + 12)
        if m.b then
          local hit = drawMatchBox(m, bx, yy, bw, m.id == selId)
          if hit.clicked and not listScroll:dragged() then for i, x2 in ipairs(pl) do if x2 == m then selMatch = i end end; openSheet(m) end
        else
          gfx.rect(bx, yy, bw, BOX_H, 10, alpha(theme.text, 0.04))
          gfx.color(theme.text2)
          gfx.text(TR("has_bye", playerName(m.a) or "?"), bx + 12, yy + 22, 13, "italic")
        end
        k = k + 1
        if k % colsN == 0 then yy = yy + BOX_H + 12 end
      end
    end
    if k % colsN ~= 0 then yy = yy + BOX_H + 12 end
    yy = yy + 8
  end
  if t.format == "swiss" and maxR < t.rounds then
    gfx.color(theme.text3)
    gfx.text(TR("next_round_hint", maxR + 1, t.rounds), x + p, yy, 13, "italic")
    yy = yy + 30
  end
  gfx.unclip()
  listScroll:setMax(yy - start + 20 - h)
  listScroll:bar(x + w - 6, y + 4, h - 8)
end

local function drawSheet(w, h)
  if not sheet then return end
  sheet.t = min(1, sheet.t + frameDt * 8)
  local m = sheet.m
  local mx, my, cw, ch, outside = K.modal("score", w, h, 440, 300, sheet.t)
  gfx.color(theme.text)
  gfx.text(TR("enter_score"), mx + 20, my + 18, 18, "bold")
  if outside then sheet = nil; return end
  local rows = {{m.a, "sa"}, {m.b, "sb"}}
  for i, r in ipairs(rows) do
    local ry = my + 62 + (i - 1) * 64
    gfx.rect(mx + 16, ry, cw - 32, 56, 12, sheet.row == i and alpha(theme.accent, 0.12) or alpha(theme.text, 0.04))
    gfx.color(theme.text)
    gfx.text(K.ellipsize(playerName(r[1]) or "?", 16, "semibold", cw - 210), mx + 30, ry + 17, 16, "semibold")
    if ui.iconButton("remove", mx + cw - 170, ry + 10, 44, 36, theme.text2, false, "##sm" .. i) then sheet[r[2]] = max(0, sheet[r[2]] - 1); sheet.row = i end
    gfx.color(theme.text)
    gfx.text(tostring(sheet[r[2]]), mx + cw - 124, ry + 12, 24, "monobold", "center", 60)
    if ui.iconButton("add", mx + cw - 62, ry + 10, 44, 36, theme.accent, false, "##sp" .. i) then sheet[r[2]] = min(999, sheet[r[2]] + 1); sheet.row = i end
  end
  local by = my + ch - 56
  if ui.button(TR("cancel"), mx + 16, by, 110, 38, "default") then sheet = nil; return end
  if m.done and ui.button(TR("clear_result"), mx + 134, by, 130, 38, "default") then
    hist:push(K.copy(cur))
    m.done, m.sa, m.sb = false, 0, 0
    if cur.format == "single" then clearDownstream(cur, m); m.winner = nil; propagate(cur, m) else m.winner = nil end
    cur.champion = finalWinner(cur)
    markDirty()
    sheet = nil
    return
  end
  if ui.button(TR("save"), mx + cw - 126, by, 110, 38, "primary", "check") then
    if setResult(m, sheet.sa, sheet.sb) then sheet = nil end
  end
end

local function drawPlay(w, h)
  local t = cur
  gfx.rect(0, 0, w, 52, 0, theme.window)
  if ui.iconButton("arrow_back", 10, 9, 36, 34, theme.text2, false, "##back") then screen = "home"; saveNow(); return end
  gfx.color(theme.text)
  local right = w - 10
  local function rb(icon, id, enabled)
    right = right - 38
    if enabled == false then gfx.icon(icon, right + 18, 26, 20, theme.text3); return false end
    return ui.iconButton(icon, right, 9, 36, 34, theme.text2, false, id)
  end
  if rb("more_horiz", "##more") then
    ui.contextMenu({{label = TR("copy_results"), id = 1, icon = "content_copy"}, {label = TR("export_results"), id = 2, icon = "ios_share"},
                    {label = TR("edit_players"), id = 3, icon = "group"}, {label = TR("restart"), id = 4, icon = "restart_alt"}, "-",
                    {label = TR("backup"), id = 5, icon = "save"}}, function(id) app.onmenu(100 + id) end)
  end
  if rb("redo", "##redo", hist:canRedo()) then redo() end
  if rb("undo", "##undo", hist:canUndo()) then undo() end
  if t.format == "single" and rb("center_focus_strong", "##center") then pan = {x = 0, y = 0} end
  gfx.text(K.ellipsize(t.name, 17, "bold", right - 70), 54, 16, 17, "bold")
  gfx.color(theme.separator); gfx.line(0, 52, w, 52, 1)
  local y0 = 53
  if t.format == "single" then
    gfx.clip(0, y0, w, h - y0)
    drawBracket(0, y0, w, h - y0)
    gfx.unclip()
  else
    local wide = w >= 900
    if wide then
      local tw = floor(w * 0.44)
      drawRounds(0, y0, w - tw, h - y0)
      gfx.rect(w - tw, y0, tw, h - y0, 0, theme.sidebar)
      gfx.color(theme.separator); gfx.line(w - tw, y0, w - tw, h, 1)
      drawTable(w - tw, y0, tw, h - y0)
    else
      panelTab = ui.segmented("ptab", {TR("matches"), TR("standings")}, panelTab, 10, y0 + 8, w - 20, 30)
      if panelTab == 1 then drawRounds(0, y0 + 44, w, h - y0 - 44) else drawTable(0, y0 + 44, w, h - y0 - 44) end
    end
  end
  -- champion banner
  if t.champion and confetti then
    confetti.t = confetti.t + frameDt
    for _, c in ipairs(confetti.parts) do
      c.x, c.y = c.x + c.vx * frameDt, c.y + c.vy * frameDt
      gfx.rect(c.x * w, c.y * h, 7, 4 + c.r, 2, c.c)
    end
    local a = min(1, confetti.t * 3, max(0, (4 - confetti.t)))
    if a > 0 then
      gfx.alpha(a)
      local bw2 = min(420, w - 40)
      gfx.shadow((w - bw2) / 2, h / 2 - 60, bw2, 120, 20, 20, 6)
      gfx.rect((w - bw2) / 2, h / 2 - 60, bw2, 120, 20, theme.window)
      gfx.icon("emoji_events", w / 2, h / 2 - 22, 44, theme.yellow)
      gfx.color(theme.text)
      gfx.text(TR("champion_is", playerName(t.champion)), (w - bw2) / 2, h / 2 + 12, 20, "bold", "center", bw2)
      gfx.unalpha()
    end
    if confetti.t > 5 then confetti = nil end
  end
end

-- ================================================================== app callbacks
function app.load(arg)
  loadAll()
  if type(arg) == "string" and arg:match("^tour:") then app.open(arg) end
end
function app.open(arg)
  local id = type(arg) == "string" and tonumber(arg:match("^tour:(%d+)$"))
  if id then for _, t in ipairs(tours) do if t.id == id then openTour(t) end end; return end
  if type(arg) == "string" and arg:find(":/", 1, true) then
    local d = json.decode(fs.read(arg) or "")
    if type(d) == "table" and type(d.tours) == "table" then
      local n = 0
      for _, t in ipairs(d.tours) do if type(t) == "table" and type(t.players) == "table" then t.id = now() + math.random(100000); tours[#tours + 1] = t; n = n + 1 end end
      markDirty()
      K.toast(TR("imported_n", n), "file_download")
    else K.toast(TR("not_backup"), "error") end
  end
end

function app.update(dt)
  frameDt = dt
  homeScroll:update(dt)
  listScroll:update(dt)
  if dirty and sys.time() - changedAt > 1.2 then saveNow() end
  if screen == "play" and cur and cur.format == "single" and not sheet then
    local sx, sy = input.stick("left")
    if abs(sx) > 0.25 or abs(sy) > 0.25 then pan.x, pan.y = pan.x - sx * dt * 600, pan.y + sy * dt * 600 end
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  if screen == "home" or not cur then drawHome(w, h)
  elseif screen == "setup" then drawSetup(w, h)
  else drawPlay(w, h) end
  drawSheet(w, h)
  K.drawToast(w, h)
  K.frameEnd()
end

local function focusSel()
  local pl = playable(cur)
  local m = pl[selMatch]
  if not m or cur.format ~= "single" then return end
  local L = matchLayout(cur)
  local p = L[m.id]
  pan.x = -(p.x - 200)
  pan.y = -(p.y - 150)
end

function app.event(e)
  if K.press(e) then return end
  if sheet then
    if e.type == "keydown" then
      local k = sheet.row == 1 and "sa" or "sb"
      if e.key == "escape" then sheet = nil
      elseif e.key == "up" then sheet.row = 1 elseif e.key == "down" then sheet.row = 2
      elseif e.key == "right" then sheet[k] = sheet[k] + 1 elseif e.key == "left" then sheet[k] = max(0, sheet[k] - 1)
      elseif e.key:match("^%d$") then sheet[k] = tonumber(e.key)
      elseif e.key == "enter" then if setResult(sheet.m, sheet.sa, sheet.sb) then sheet = nil end end
    end
    return
  end
  if screen == "home" then if homeScroll:event(e, homeRect) then return end end
  if screen ~= "home" and listScroll:event(e, listRect) then return end
  if screen == "play" and cur and cur.format == "single" and e.type == "scroll" then pan.x, pan.y = pan.x - (e.dx or 0), pan.y - (e.dy or 0); return end
  if e.type ~= "keydown" or K.editing then return end
  local k = e.key
  if e.ctrl then
    if k == "z" then if e.shift then redo() else undo() end elseif k == "y" then redo()
    elseif k == "n" then app.onmenu(1) elseif k == "c" then if cur then app.onmenu(101) end end
    return
  end
  if screen == "play" and cur then
    local pl = playable(cur)
    if k == "right" or k == "down" or k == "tab" then selMatch = selMatch % max(1, #pl) + 1; focusSel()
    elseif k == "left" or k == "up" then selMatch = (selMatch - 2) % max(1, #pl) + 1; focusSel()
    elseif k == "enter" or k == "space" then openSheet(pl[selMatch])
    elseif k == "escape" then screen = "home"; saveNow()
    elseif k == "s" then panelTab = 3 - panelTab end
  elseif screen == "setup" and k == "escape" then screen = "home"
  elseif screen == "home" and k == "enter" and tours[1] then openTour(tours[1]) end
end

function app.menu()
  return {
    {title = TR("m_file"), items = {
      {label = TR("new_tour"), id = 1, shortcut = "Ctrl+N"},
      {label = TR("all_tours"), id = 2, shortcut = "Esc"},
      "-",
      {label = TR("backup"), id = 105},
      {label = TR("restore"), id = 3},
    }},
    {title = TR("m_tour"), items = {
      {label = TR("undo"), id = 10, shortcut = "Ctrl+Z"},
      {label = TR("redo"), id = 11, shortcut = "Ctrl+Y"},
      "-",
      {label = TR("copy_results"), id = 101, shortcut = "Ctrl+C"},
      {label = TR("export_results"), id = 102},
      {label = TR("edit_players"), id = 103},
      {label = TR("restart"), id = 104},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then
    local t = newTour(TR("tour_n", #tours + 1), "single", {})
    table.insert(tours, 1, t); openTour(t); markDirty()
  elseif id == 2 then screen = "home"; saveNow()
  elseif id == 3 then ui.openFile(function(p) if p then app.open(p) end end, {".json"}, TR("restore"))
  elseif id == 10 then undo() elseif id == 11 then redo()
  elseif not cur then return
  elseif id == 101 then sys.clipboard(resultsText(cur)); K.toast(TR("copied"), "content_copy")
  elseif id == 102 then
    local t = cur
    ui.saveFile(function(p)
      if not p then return end
      if not p:lower():match("%.txt$") then p = p .. ".txt" end
      if fs.write(p, resultsText(t)) then K.toast(TR("exported"), "ios_share") else K.toast(TR("write_failed"), "error") end
    end, t.name:gsub("[/\\:%*%?\"<>|]", "-") .. ".txt", TR("export_results"))
  elseif id == 103 or id == 104 then
    ui.alert(TR("restart_title"), TR("restart_msg"), {TR("restart"), TR("cancel")}, function(b)
      if b ~= 1 then return end
      hist:push(K.copy(cur))
      cur.started, cur.matches, cur.champion = false, {}, nil
      screen = "setup"
      markDirty()
    end)
  elseif id == 105 then
    ui.saveFile(function(p)
      if not p then return end
      if not p:lower():match("%.json$") then p = p .. ".json" end
      if fs.write(p, json.encode({app = "bracket", version = 1, tours = tours}, true)) then K.toast(TR("exported"), "save") else K.toast(TR("write_failed"), "error") end
    end, "tournaments.json", TR("backup"))
  end
end

function app.search(q)
  local out = {}
  q = K.lower(K.trim(q))
  if q == "" then return out end
  for _, t in ipairs(tours) do
    local hitText = K.lower(t.name):find(q, 1, true)
    if not hitText then for _, p in ipairs(t.players) do if K.lower(p.name):find(q, 1, true) then hitText = true; break end end end
    if hitText and #out < 5 then out[#out + 1] = {title = t.name, subtitle = TR("app_name"), icon = "emoji_events", arg = "tour:" .. t.id} end
  end
  return out
end
function app.suspend() if dirty then saveNow() end end
function app.autosave() if dirty then saveNow() end end
function app.unsaved() return dirty end
function app.close() saveNow(); store.save(); return true end

return app
