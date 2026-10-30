-- Kanban for Nexvyn OS: multiple boards, editable columns, cards with description, due date and color label,
-- drag & drop between columns, move buttons for controller users and a card detail sheet.
local app = {}

local floor, min, max, abs = math.floor, math.min, math.max, math.abs

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
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function ellipsize(s, size, font, maxW)
  if gfx.textWidth(s, size, font) <= maxW then return s end
  while utf8.len(s) > 1 and gfx.textWidth(s .. "…", size, font) > maxW do
    s = s:sub(1, utf8.offset(s, -1) - 1)
  end
  return s .. "…"
end

-- text-field focus tracking (typing must never trigger shortcuts)
local editing, pressAt, fieldHit = false, nil, false
local function field(id, text, x, y, w, h, ph, flags)
  local nt, sub = ui.textfield(id, text, x, y, w, h, ph, flags)
  if pressAt then
    local mx, my = ui.mouse()
    if mx >= x and mx <= x + w and my >= y and my <= y + h then fieldHit = true end
  end
  return nt, sub
end
-- focus a field from code (the click that caused it must not cancel the editing state)
local function focusNow(id)
  ui.focus(id)
  editing = true
  pressAt, fieldHit = nil, false
end

-- dates are stored as local-noon epochs (0 = none)
local function noonOf(epoch)
  local d = sys.date(epoch)
  return epoch - d.hour * 3600 - d.min * 60 - d.sec + 12 * 3600
end
local function dayNum(epoch)
  local d = sys.date(epoch)
  return d.year * 10000 + d.month * 100 + d.day
end

-- ------------------------------------------------------------------ data
local LABELS = {"red", "orange", "yellow", "green", "blue", "purple"}
local boards = {}
local cur = 1
local nextId = 1
local frameDt = 1 / 60

local function B() return boards[cur] end

local function save()
  store.set("boards", boards)
  store.set("cur", cur)
  store.set("nextId", nextId)
end

local function newCard(title, desc, color, due)
  local c = {id = nextId, title = title or "", desc = desc or "", color = color or 0, due = due or 0, created = sys.epoch()}
  nextId = nextId + 1
  return c
end

local function defaultBoard()
  local today = noonOf(sys.epoch())
  return {name = TR("def_board"), columns = {
    {title = TR("col_todo"), cards = {
      newCard(TR("def_card1"), TR("def_card1_desc"), 5, today + 86400),
      newCard(TR("def_card2"), "", 2, 0),
    }},
    {title = TR("col_doing"), cards = {newCard(TR("def_card3"), TR("def_card3_desc"), 3, today)}},
    {title = TR("col_done"), cards = {newCard(TR("def_card4"), "", 4, 0)}},
  }}
end

local function sanitize(raw)
  local out = {}
  if type(raw) ~= "table" then return out end
  for _, b in ipairs(raw) do
    if type(b) == "table" then
      local nb = {name = tostring(b.name or ""), columns = {}}
      if type(b.columns) == "table" then
        for _, col in ipairs(b.columns) do
          if type(col) == "table" then
            local nc = {title = tostring(col.title or ""), cards = {}}
            if type(col.cards) == "table" then
              for _, c in ipairs(col.cards) do
                if type(c) == "table" then
                  local id = math.tointeger(c.id) or 0
                  nc.cards[#nc.cards + 1] = {id = id, title = tostring(c.title or ""), desc = tostring(c.desc or ""),
                                             color = clamp(math.tointeger(c.color) or 0, 0, #LABELS),
                                             due = math.tointeger(c.due) or 0, created = math.tointeger(c.created) or 0}
                  if id >= nextId then nextId = id + 1 end
                end
              end
            end
            nb.columns[#nb.columns + 1] = nc
          end
        end
      end
      out[#out + 1] = nb
    end
  end
  return out
end

local function findCard(id)
  local b = B()
  for ci, col in ipairs(b.columns) do
    for i, c in ipairs(col.cards) do
      if c.id == id then return c, ci, i end
    end
  end
  return nil
end

-- ------------------------------------------------------------------ state
local boardX = 0
local colScroll = {}
local drag = nil            -- {id, col, idx, ox, oy, w, h, active}
local dropCol, dropIdx = nil, nil
local sheet = nil           -- {id, isNew, t}
local sheetT = 0
local selId = nil           -- keyboard selection
local hoverId = nil
local yAnim = {}            -- animated card y positions
local renameCol = nil
local renameText = ""
local colRects = {}         -- [ci] = {x, y, w, h, bodyY, bodyH, maxS}
local colDragStart = {}
local todayNoon = 0

local function moveCard(id, toCol, toIdx)
  local c, ci, i = findCard(id)
  if not c then return end
  local b = B()
  toCol = clamp(toCol, 1, #b.columns)
  table.remove(b.columns[ci].cards, i)
  local list = b.columns[toCol].cards
  toIdx = clamp(toIdx or (#list + 1), 1, #list + 1)
  table.insert(list, toIdx, c)
  save()
end

local function deleteCard(id)
  local c, ci, i = findCard(id)
  if not c then return end
  table.remove(B().columns[ci].cards, i)
  if selId == id then selId = nil end
  save()
end

local function openSheet(id, isNew)
  sheet = {id = id, isNew = isNew}
  sheetT = 0
  editing = false
  if isNew then focusNow("c_title") end
end

local function closeSheet()
  if not sheet then return end
  local c = findCard(sheet.id)
  if c and trim(c.title) == "" and trim(c.desc) == "" then
    deleteCard(sheet.id)
  elseif c then
    c.title = trim(c.title)
    save()
  end
  sheet = nil
  editing = false
end

local function addCard(ci)
  local b = B()
  if not b.columns[ci] then return end
  local c = newCard("", "", 0, 0)
  table.insert(b.columns[ci].cards, c)
  selId = c.id
  save()
  openSheet(c.id, true)
  audio.play("pop", 0.4)
end

local function addColumn()
  local b = B()
  if #b.columns >= 8 then audio.play("error", 0.5); return end
  b.columns[#b.columns + 1] = {title = TR("new_column"), cards = {}}
  renameCol = #b.columns
  renameText = b.columns[#b.columns].title
  save()
end

local function deleteColumn(ci)
  local b = B()
  local col = b.columns[ci]
  if not col then return end
  local function doIt()
    table.remove(b.columns, ci)
    if #b.columns == 0 then b.columns[1] = {title = TR("col_todo"), cards = {}} end
    save()
    audio.play("trash", 0.5)
  end
  if #col.cards > 0 then
    ui.alert(TR("delete_col_title"), TR("delete_col_msg", col.title, #col.cards), {TR("delete"), TR("cancel")}, function(k)
      if k == 1 then doIt() end
    end)
  else
    doIt()
  end
end

local function newBoard()
  boards[#boards + 1] = {name = TR("board_n", #boards + 1), columns = {
    {title = TR("col_todo"), cards = {}}, {title = TR("col_doing"), cards = {}}, {title = TR("col_done"), cards = {}}}}
  cur = #boards
  boardX, colScroll, selId = 0, {}, nil
  save()
  audio.play("pop", 0.4)
end

local function deleteBoard()
  ui.alert(TR("delete_board_title"), TR("delete_board_msg", B().name), {TR("delete"), TR("cancel")}, function(k)
    if k ~= 1 then return end
    table.remove(boards, cur)
    if #boards == 0 then boards[1] = defaultBoard() end
    cur = clamp(cur, 1, #boards)
    boardX, colScroll, selId = 0, {}, nil
    save()
    audio.play("trash", 0.5)
  end)
end

-- ------------------------------------------------------------------ card metrics
local CARD_PAD = 10
local function cardHeight(c, w)
  local tw = w - CARD_PAD * 2
  local th = min(gfx.measureWrap(c.title ~= "" and c.title or TR("untitled"), tw, 13, "semibold"), 36)
  local h = CARD_PAD + th
  if c.color > 0 then h = h + 9 end
  if c.desc ~= "" then h = h + 4 + min(gfx.measureWrap(c.desc, tw, 12), 32) end
  if c.due ~= 0 then h = h + 28 end
  return floor(h + CARD_PAD)
end

local function dueStyle(due)
  if due == 0 then return nil end
  local dn, tn = dayNum(due), dayNum(todayNoon)
  if dn < tn then return theme.red, TR("overdue") end
  if dn == tn then return theme.orange, TR("today") end
  if dn == dayNum(todayNoon + 86400) then return theme.blue, TR("tomorrow") end
  return theme.text2, nil
end

local function dueText(due)
  local d = sys.date(due)
  local k = "ms_" .. d.month
  return TR("due_fmt", d.day, TR(k))
end

local function drawCardBody(c, x, y, w, h, lifted, highlight)
  if lifted then gfx.shadow(x, y, w, h, 10, 18, 8) else gfx.shadow(x, y, w, h, 10, 4, 1) end
  gfx.rect(x, y, w, h, 10, theme.dark and "#3A3A3C" or "#FFFFFF")
  gfx.color(highlight and theme.accent or theme.separator)
  gfx.rectLine(x, y, w, h, 10, highlight and 2 or 1)
  local yy = y + CARD_PAD
  local tw = w - CARD_PAD * 2
  if c.color > 0 then
    gfx.rect(x + CARD_PAD, yy, 36, 5, 3, theme[LABELS[c.color]])
    yy = yy + 9
  end
  local title = c.title ~= "" and c.title or TR("untitled")
  local th = min(gfx.measureWrap(title, tw, 13, "semibold"), 36)
  gfx.clip(x + CARD_PAD, yy, tw, th + 2)
  gfx.color(c.title ~= "" and theme.text or theme.text3)
  gfx.wrap(title, x + CARD_PAD, yy, tw, 13, "semibold")
  gfx.unclip()
  yy = yy + th
  if c.desc ~= "" then
    local dh = min(gfx.measureWrap(c.desc, tw, 12), 32)
    gfx.clip(x + CARD_PAD, yy + 4, tw, dh + 1)
    gfx.color(theme.text2)
    gfx.wrap(c.desc, x + CARD_PAD, yy + 4, tw, 12)
    gfx.unclip()
    yy = yy + 4 + dh
  end
  if c.due ~= 0 then
    local col, label = dueStyle(c.due)
    local txt = dueText(c.due) .. (label and ("  ·  " .. label) or "")
    local cw = gfx.textWidth(txt, 11, "semibold") + 30
    local cy = yy + 6
    gfx.rect(x + CARD_PAD, cy, cw, 20, 6, alpha(col, 0.14))
    gfx.icon("event", x + CARD_PAD + 11, cy + 10, 13, col)
    gfx.color(col)
    gfx.text(txt, x + CARD_PAD + 21, cy + 3, 11, "semibold")
  end
end

-- ------------------------------------------------------------------ sheet (card details)
local function drawSheet(w, h)
  local c, ci = findCard(sheet.id)
  if not c then sheet = nil; return end
  local e = 1 - (1 - sheetT) ^ 3
  gfx.rect(0, 0, w, h, 0, {0, 0, 0, floor(100 * e)})
  local bgHit = ui.hit("sheet_bg", 0, 0, w, h)
  local sw, sh = 560, 420
  local sx, sy = (w - sw) / 2, (h - sh) / 2 + (1 - e) * 40
  if bgHit.clicked then
    local mx, my = ui.mouse()
    if mx < sx or mx > sx + sw or my < sy or my > sy + sh then closeSheet(); return end
  end
  gfx.alpha(e)
  gfx.shadow(sx, sy, sw, sh, 14, 30, 10)
  gfx.rect(sx, sy, sw, sh, 14, theme.window)
  ui.hit("sheet_card", sx, sy, sw, sh)
  local x0, iw = sx + 24, sw - 48
  gfx.color(theme.text)
  gfx.text(sheet.isNew and TR("new_card") or TR("edit_card"), x0, sy + 18, 17, "bold")
  if ui.iconButton("close", sx + sw - 50, sy + 12, 34, 30, theme.text2, false, "sheetclose") then closeSheet(); gfx.unalpha(); return end

  local y = sy + 56
  gfx.color(theme.text3)
  gfx.text(TR("title_label"), x0, y, 11, "semibold")
  local nt = field("c_title", c.title, x0, y + 16, iw, 32, TR("title_hint"))
  if nt ~= c.title then c.title = nt; save() end
  y = y + 58
  gfx.color(theme.text3)
  gfx.text(TR("desc_label"), x0, y, 11, "semibold")
  local nd = field("c_desc", c.desc, x0, y + 16, iw, 32, TR("desc_hint"))
  if nd ~= c.desc then c.desc = nd; save() end

  -- column + color
  y = y + 58
  gfx.color(theme.text3)
  gfx.text(TR("column_label"), x0, y, 11, "semibold")
  local names = {}
  for i, col in ipairs(B().columns) do names[i] = col.title ~= "" and col.title or TR("untitled_col") end
  local nc = ui.dropdown("c_col", names, ci, x0, y + 16, 220, 30)
  if nc ~= ci then moveCard(c.id, nc, nil); audio.play("pop", 0.4) end
  gfx.color(theme.text3)
  gfx.text(TR("color_label"), x0 + 250, y, 11, "semibold")
  for i = 0, #LABELS do
    local cx = x0 + 250 + 14 + i * 36
    local cy2 = y + 31
    local hit = ui.hit("lbl" .. i, cx - 15, cy2 - 15, 30, 30)
    if i == 0 then
      gfx.color(theme.text3)
      gfx.circleLine(cx, cy2, 11, 1.5)
      gfx.line(cx - 7, cy2 + 7, cx + 7, cy2 - 7, 1.5)
    else
      gfx.circle(cx, cy2, 11, theme[LABELS[i]])
    end
    if c.color == i then
      gfx.color(theme.accent)
      gfx.circleLine(cx, cy2, 15, 2)
    elseif hit.hovered then
      gfx.color(theme.text3)
      gfx.circleLine(cx, cy2, 15, 1)
    end
    if hit.clicked then c.color = i; save(); audio.play("click", 0.4) end
  end

  -- due date
  y = y + 62
  gfx.color(theme.text3)
  gfx.text(TR("due_label"), x0, y, 11, "semibold")
  local dueStr = c.due ~= 0 and dueText(c.due) or TR("no_due")
  local col, label = dueStyle(c.due)
  if c.due ~= 0 then
    local d = sys.date(c.due)
    local wk = "wd_" .. d.wday
    dueStr = TR(wk) .. ", " .. dueStr .. " " .. d.year .. (label and ("  ·  " .. label) or "")
  end
  gfx.icon("event", x0 + 10, y + 31, 18, col or theme.text3)
  gfx.color(col or theme.text2)
  gfx.text(dueStr, x0 + 26, y + 23, 14, "semibold")
  local bx = x0
  local by = y + 48
  local function dbtn(lbl, id, wd)
    local r = ui.button(lbl .. "##" .. id, bx, by, wd, 30)
    bx = bx + wd + 6
    return r
  end
  if dbtn(TR("today"), "dt", 74) then c.due = todayNoon; save() end
  if dbtn(TR("tomorrow"), "dtm", 84) then c.due = todayNoon + 86400; save() end
  if dbtn(TR("next_week"), "dnw", 96) then c.due = todayNoon + 7 * 86400; save() end
  if dbtn("−1", "dm1", 44) and c.due ~= 0 then c.due = noonOf(c.due - 86400); save() end
  if dbtn("+1", "dp1", 44) then c.due = noonOf((c.due ~= 0 and c.due or todayNoon) + 86400); save() end
  if dbtn(TR("clear"), "dcl", 80) then c.due = 0; save() end

  -- footer
  local fy = sy + sh - 54
  ui.separator(sx, fy - 10, sx + sw)
  if ui.button(TR("delete_card"), x0, fy, 130, 34, "destructive", "delete") then
    local id = c.id
    sheet = nil
    editing = false
    deleteCard(id)
    audio.play("trash", 0.5)
    gfx.unalpha()
    return
  end
  if ui.button(TR("done"), sx + sw - 24 - 120, fy, 120, 34, "primary") then closeSheet() end
  gfx.unalpha()
end

-- ------------------------------------------------------------------ app
function app.load()
  boards = sanitize(store.get("boards", nil))
  nextId = max(nextId, math.tointeger(store.get("nextId", 1)) or 1)
  if #boards == 0 then boards = {defaultBoard()} end
  cur = clamp(math.tointeger(store.get("cur", 1)) or 1, 1, #boards)
  todayNoon = noonOf(sys.epoch())
  save()
end

function app.update(dt)
  frameDt = dt
  todayNoon = noonOf(sys.epoch())
  if sheet then sheetT = min(1, sheetT + dt * 4) end
end

local function drawToolbar(w)
  gfx.rect(0, 0, w, 52, 0, theme.window)
  ui.separator(0, 52, w)
  local names = {}
  for i, b in ipairs(boards) do names[i] = b.name ~= "" and b.name or TR("untitled_board") end
  gfx.icon("view_kanban", 28, 26, 22, theme.accent)
  local nb = ui.dropdown("boardsel", names, cur, 46, 11, 200, 30)
  if nb ~= cur then cur = nb; boardX, colScroll, selId = 0, {}, nil; save() end
  if ui.iconButton("add", 252, 11, 32, 30, nil, false, "nb") then newBoard() end
  gfx.color(theme.text3)
  gfx.text(TR("board_name"), 300, 18, 11, "semibold")
  local lw = gfx.textWidth(TR("board_name"), 11, "semibold")
  local nn = field("bname", B().name, 308 + lw, 11, 220, 30, TR("untitled_board"))
  if nn ~= B().name then B().name = nn; save() end
  if ui.iconButton("delete_outline", 308 + lw + 228, 11, 32, 30, theme.text2, false, "db") then deleteBoard() end
  if ui.button(TR("add_column"), w - 290, 11, 130, 30, "default", "view_week") then addColumn() end
  if ui.button(TR("add_card"), w - 150, 11, 134, 30, "primary", "add") then addCard(1) end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  drawToolbar(w)
  local b = B()
  local n = #b.columns
  local top, bottom = 64, h - 12
  local gap = 12
  local avail = w - 32
  local colW = max(236, (avail - (n - 1) * gap) / n)
  local totalW = n * colW + (n - 1) * gap
  local maxX = max(0, totalW - avail)
  -- auto-scroll the board horizontally while dragging near an edge
  local mx, my = ui.mouse()
  if drag and drag.active then
    if mx < 50 then boardX = boardX - 600 * frameDt elseif mx > w - 50 then boardX = boardX + 600 * frameDt end
  end
  boardX = clamp(boardX, 0, maxX)

  hoverId = nil
  dropCol, dropIdx = nil, nil
  local dragCard = drag and drag.active and findCard(drag.id) or nil
  if drag and not dragCard and drag.active then drag = nil end

  gfx.clip(16, top - 4, avail, bottom - top + 8)
  for ci, col in ipairs(b.columns) do
    local x = 16 + (ci - 1) * (colW + gap) - boardX
    local y, hh = top, bottom - top
    local bodyY = y + 48
    local bodyH = hh - 48 - 6
    colRects[ci] = {x = x, y = y, w = colW, h = hh, bodyY = bodyY, bodyH = bodyH}
    -- column background
    gfx.rect(x, y, colW, hh, 12, theme.dark and alpha("#FFFFFF", 0.05) or alpha("#000000", 0.04))
    local isTarget = dragCard and mx >= x and mx < x + colW + gap
    if isTarget then
      gfx.color(alpha(theme.accent, 0.6))
      gfx.rectLine(x, y, colW, hh, 12, 2)
    end
    -- header
    if renameCol == ci then
      local nt, sub = field("colname", renameText, x + 10, y + 9, colW - 20, 30)
      if nt ~= renameText then
        renameText = nt
        if trim(nt) ~= "" then col.title = trim(nt); save() end
      end
      if sub then renameCol = nil; editing = false end
    else
      gfx.color(theme.text)
      local title = col.title ~= "" and col.title or TR("untitled_col")
      local maxT = colW - 110
      title = ellipsize(title, 14, "bold", maxT)
      gfx.text(title, x + 14, y + 15, 14, "bold")
      local tw = gfx.textWidth(title, 14, "bold")
      local cnt = tostring(#col.cards)
      local bw = gfx.textWidth(cnt, 11, "semibold") + 14
      gfx.rect(x + 20 + tw, y + 15, bw, 18, 9, alpha(theme.text, 0.08))
      gfx.color(theme.text2)
      gfx.text(cnt, x + 20 + tw, y + 17, 11, "semibold", "center", bw)
      if ui.iconButton("add", x + colW - 74, y + 9, 30, 30, theme.text2, false, "ac" .. ci) then addCard(ci) end
      if ui.iconButton("more_horiz", x + colW - 40, y + 9, 30, 30, theme.text2, false, "cm" .. ci) then
        local cc = ci
        ui.contextMenu({
          {label = TR("rename"), id = 1, icon = "edit"},
          {label = TR("move_left"), id = 2, icon = "chevron_left"},
          {label = TR("move_right"), id = 3, icon = "chevron_right"},
          "-",
          {label = TR("delete_column"), id = 4, icon = "delete"},
        }, function(id)
          local bb = B()
          if id == 1 then renameCol = cc; renameText = bb.columns[cc].title; focusNow("colname")
          elseif id == 2 and cc > 1 then bb.columns[cc], bb.columns[cc - 1] = bb.columns[cc - 1], bb.columns[cc]; save()
          elseif id == 3 and cc < #bb.columns then bb.columns[cc], bb.columns[cc + 1] = bb.columns[cc + 1], bb.columns[cc]; save()
          elseif id == 4 then deleteColumn(cc) end
        end)
      end
      local hh2 = ui.hit("colhead" .. ci, x, y, colW - 80, 44)
      if hh2.doubleClicked then renameCol = ci; renameText = col.title; focusNow("colname") end
    end

    -- layout cards (excluding the one being dragged), with a gap where it would drop
    local cw = colW - 20
    local list = {}
    local insertAt, phY = nil, 0
    if isTarget then
      local py = my - bodyY + (colScroll[ci] or 0)
      local k, yy0 = 0, 0
      for _, c in ipairs(col.cards) do
        if c.id ~= drag.id then
          k = k + 1
          local chh = cardHeight(c, cw)
          if not insertAt and py < yy0 + chh / 2 then insertAt = k end
          yy0 = yy0 + chh + 8
        end
      end
      insertAt = insertAt or (k + 1)
      dropCol, dropIdx = ci, insertAt
    end
    local yy = 0
    local k = 0
    for _, c in ipairs(col.cards) do
      if not (dragCard and c.id == drag.id) then
        k = k + 1
        if insertAt and k == insertAt then phY = yy; yy = yy + drag.h + 8 end
        local chh = cardHeight(c, cw)
        list[#list + 1] = {c = c, y = yy, h = chh}
        yy = yy + chh + 8
      end
    end
    if insertAt and insertAt > k then phY = yy; yy = yy + drag.h + 8 end
    local contentH = yy + 4
    local maxS = max(0, contentH - bodyH)
    local sc = clamp(colScroll[ci] or 0, 0, maxS)
    if dragCard and isTarget then
      if my > bodyY + bodyH - 40 then sc = min(maxS, sc + 400 * frameDt) elseif my < bodyY + 40 then sc = max(0, sc - 400 * frameDt) end
    end
    -- drag on the empty column body scrolls it
    local bodyHit = ui.hit("colbody" .. ci, x, bodyY, colW, bodyH)
    if bodyHit.pressed then colDragStart[ci] = sc; selId = nil end
    if bodyHit.held and colDragStart[ci] then
      sc = clamp(colDragStart[ci] - bodyHit.dy, 0, maxS)
    elseif not bodyHit.held then
      colDragStart[ci] = nil
    end
    colScroll[ci] = sc
    colRects[ci].maxS = maxS

    gfx.clip(x, bodyY, colW, bodyH)
    -- drop placeholder
    if insertAt then
      local px, ppy = x + 10, bodyY + phY - sc
      gfx.rect(px, ppy, cw, drag.h, 10, alpha(theme.accent, 0.10))
      gfx.color(alpha(theme.accent, 0.5))
      gfx.rectLine(px, ppy, cw, drag.h, 10, 1.5)
    end
    for _, it in ipairs(list) do
      local c = it.c
      local target = bodyY + it.y - sc
      local ay = yAnim[c.id]
      if not ay or abs(ay - target) > 600 then ay = target end
      ay = approach(ay, target, 18, frameDt)
      yAnim[c.id] = ay
      local cx = x + 10
      if ay + it.h >= bodyY - 4 and ay <= bodyY + bodyH + 4 then
        local hit = ui.hit("card" .. c.id, cx, ay, cw, it.h)
        if hit.hovered and my >= bodyY and my <= bodyY + bodyH then hoverId = c.id end
        if hit.pressed and not sheet then
          drag = {id = c.id, col = ci, ox = mx - cx, oy = my - ay, w = cw, h = it.h, active = false}
        end
        if drag and drag.id == c.id and hit.held and not drag.active and (abs(hit.dx) > 7 or abs(hit.dy) > 7) then
          drag.active = true
          selId = c.id
          audio.tone(660, 0.03, 0.12, "triangle")
        end
        if hit.clicked and not (drag and drag.active) then
          selId = c.id
          openSheet(c.id, false)
          audio.play("click", 0.4)
        end
        if hit.rightClicked then
          local id = c.id
          selId = id
          local items = {{label = TR("open"), id = 100, icon = "edit"}, "-"}
          for i2, col2 in ipairs(b.columns) do
            if i2 ~= ci then items[#items + 1] = {label = TR("move_to", col2.title), id = i2, icon = "arrow_forward"} end
          end
          items[#items + 1] = "-"
          items[#items + 1] = {label = TR("delete_card"), id = 200, icon = "delete"}
          ui.contextMenu(items, function(sel)
            if sel == 100 then openSheet(id, false)
            elseif sel == 200 then deleteCard(id); audio.play("trash", 0.5)
            else moveCard(id, sel, nil); audio.play("pop", 0.4) end
          end)
        end
        if drag and drag.id == c.id and not hit.held then
          drag = nil
        end
        drawCardBody(c, cx, ay, cw, it.h, false, selId == c.id)
        -- move buttons (hover / keyboard selection) for controller users
        if (hoverId == c.id or selId == c.id) and not drag then
          local bw2, bh2 = 28, 26
          local bx = cx + cw - (bw2 * 4 + 6) - 6
          local by = ay + 6
          gfx.rect(bx - 3, by - 3, bw2 * 4 + 12, bh2 + 6, 8, theme.dark and "#48484A" or "#F2F2F7")
          local id = c.id
          local _, cci, idx = findCard(id)
          if ui.iconButton("chevron_left", bx, by, bw2, bh2, theme.text2, false, "ml" .. id) and cci > 1 then
            moveCard(id, cci - 1, nil); audio.play("pop", 0.3)
          end
          if ui.iconButton("keyboard_arrow_up", bx + bw2 + 2, by, bw2, bh2, theme.text2, false, "mu" .. id) and idx > 1 then
            moveCard(id, cci, idx - 1); audio.play("pop", 0.3)
          end
          if ui.iconButton("keyboard_arrow_down", bx + (bw2 + 2) * 2, by, bw2, bh2, theme.text2, false, "md" .. id) and idx < #b.columns[cci].cards then
            moveCard(id, cci, idx + 1); audio.play("pop", 0.3)
          end
          if ui.iconButton("chevron_right", bx + (bw2 + 2) * 3, by, bw2, bh2, theme.text2, false, "mr" .. id) and cci < #b.columns then
            moveCard(id, cci + 1, nil); audio.play("pop", 0.3)
          end
        end
      end
    end
    if #list == 0 and not insertAt then
      gfx.color(theme.text3)
      gfx.text(TR("empty_col"), x, bodyY + 18, 12, "sans", "center", colW)
    end
    gfx.unclip()
    -- scroll indicator
    if maxS > 0 then
      local th = max(24, bodyH * bodyH / contentH)
      gfx.rect(x + colW - 5, bodyY + (bodyH - th) * (sc / maxS), 3, th, 2, alpha(theme.text, 0.2))
    end
  end
  gfx.unclip()

  -- the dragged card follows the pointer (its hit area must keep being called while held)
  if dragCard then
    local gx, gy = mx - drag.ox, my - drag.oy
    local hit = ui.hit("card" .. drag.id, gx, gy, drag.w, drag.h)
    drawCardBody(dragCard, gx - 2, gy - 2, drag.w + 4, drag.h + 2, true, true)
    if not hit.held then
      if dropCol then
        local _, fromCol, fromIdx = findCard(drag.id)
        local toIdx = dropIdx
        moveCard(drag.id, dropCol, toIdx)
        if fromCol ~= dropCol or fromIdx ~= toIdx then audio.tone(520, 0.05, 0.15, "triangle") end
        sys.vibrate(0.2, 30)
      end
      drag = nil
    end
  end

  -- horizontal scroll bar for many columns
  if maxX > 0 then
    local bw = avail * avail / totalW
    gfx.rect(16 + (avail - bw) * (boardX / maxX), h - 8, bw, 4, 2, alpha(theme.text, 0.2))
  end

  if sheet then drawSheet(w, h) end

  if pressAt then editing = fieldHit; pressAt = nil; fieldHit = false end
  if renameCol and not editing then renameCol = nil end
end

-- keyboard navigation of the selection
local function selPos()
  if not selId then return nil end
  local _, ci, i = findCard(selId)
  return ci, i
end

local function selectAt(ci, i)
  local col = B().columns[ci]
  if col and col.cards[i] then selId = col.cards[i].id; return true end
  return false
end

function app.event(e)
  if e.type == "mousedown" then pressAt = {e.x, e.y} end
  if e.type == "scroll" then
    if sheet then return end
    for ci, r in pairs(colRects) do
      if r.x and e.x >= r.x and e.x <= r.x + r.w and e.y >= r.y and e.y <= r.y + r.h then
        if e.y < r.bodyY then boardX = boardX + e.dy + e.dx
        else colScroll[ci] = clamp((colScroll[ci] or 0) + e.dy, 0, r.maxS or 0); boardX = boardX + e.dx end
        return
      end
    end
    boardX = boardX + e.dx + e.dy
    return
  end
  if e.type ~= "keydown" then return end
  if e.key == "escape" then
    if editing then editing = false; if renameCol then renameCol = nil end; return end
    if sheet then closeSheet() elseif renameCol then renameCol = nil else selId = nil end
    return
  end
  if editing or sheet then return end
  local b = B()
  local ci, i = selPos()
  if not ci then
    if e.key == "left" or e.key == "right" or e.key == "up" or e.key == "down" then
      for c2 = 1, #b.columns do if selectAt(c2, 1) then break end end
    elseif e.key == "n" then addCard(1) end
    return
  end
  if e.shift then
    if e.key == "left" and ci > 1 then moveCard(selId, ci - 1, nil)
    elseif e.key == "right" and ci < #b.columns then moveCard(selId, ci + 1, nil)
    elseif e.key == "up" and i > 1 then moveCard(selId, ci, i - 1)
    elseif e.key == "down" and i < #b.columns[ci].cards then moveCard(selId, ci, i + 1) end
    return
  end
  if e.key == "up" then selectAt(ci, max(1, i - 1))
  elseif e.key == "down" then selectAt(ci, min(#b.columns[ci].cards, i + 1))
  elseif e.key == "left" or e.key == "right" then
    local d = e.key == "left" and -1 or 1
    local c2 = ci + d
    while b.columns[c2] do
      if selectAt(c2, min(i, #b.columns[c2].cards)) then break end
      c2 = c2 + d
    end
  elseif e.key == "enter" or e.key == "space" then openSheet(selId, false)
  elseif e.key == "delete" or e.key == "backspace" then
    local id = selId
    ui.alert(TR("delete_card"), TR("delete_card_msg"), {TR("delete"), TR("cancel")}, function(k)
      if k == 1 then deleteCard(id); audio.play("trash", 0.5) end
    end)
  elseif e.key == "n" then addCard(ci) end
end

function app.menu()
  return {
    {title = TR("menu_board"), items = {
      {label = TR("add_card"), id = 1, shortcut = "N"},
      {label = TR("add_column"), id = 2},
      "-",
      {label = TR("new_board"), id = 3},
      {label = TR("delete_board_title"), id = 4},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then addCard(1)
  elseif id == 2 then addColumn()
  elseif id == 3 then newBoard()
  elseif id == 4 then deleteBoard() end
end

function app.close()
  if sheet then closeSheet() end
  save()
  return true
end

return app
