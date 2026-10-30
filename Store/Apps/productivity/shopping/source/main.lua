-- Shopping List for Nexvyn OS: several lists, items with quantity and category, grouped by aisle,
-- check-off with a "in the cart" section, quick re-add from history and an item editor.
local app = {}

local floor, min, max = math.floor, math.min, math.max

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

local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

-- case-insensitive key that also folds the Turkish capitals (İ, I, ı all become i)
local FOLD = {["Ç"] = "ç", ["Ğ"] = "ğ", ["İ"] = "i", ["Ö"] = "ö", ["Ş"] = "ş", ["Ü"] = "ü", ["ı"] = "i"}
local function fold(s)
  s = trim(s):gsub("[\195\196\197][\128-\191]", function(ch) return FOLD[ch] or ch end)
  return s:lower()
end

-- quantity text -> number or nil ("1,5" is accepted as 1.5)
local function parseQty(s)
  local n = tonumber((trim(s):gsub(",", ".")))
  if not n or n ~= n or n <= 0 or n > 9999 then return nil end
  return floor(n * 100 + 0.5) / 100
end
local function fmtQty(q)
  if q == floor(q) then return string.format("%d", q) end
  return (string.format("%.2f", q):gsub("0+$", ""):gsub("%.$", ""))
end

-- text fields: remember their rectangles so typed keys are not taken as shortcuts
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

-- ------------------------------------------------------------------ categories and units
local CATS = {
  {key = "cat_produce", icon = "eco", color = "green"},
  {key = "cat_dairy", icon = "egg", color = "yellow"},
  {key = "cat_meat", icon = "set_meal", color = "red"},
  {key = "cat_bakery", icon = "bakery_dining", color = "orange"},
  {key = "cat_pantry", icon = "kitchen", color = "purple"},
  {key = "cat_drinks", icon = "local_cafe", color = "blue"},
  {key = "cat_cleaning", icon = "cleaning_services", color = "pink"},
  {key = "cat_other", icon = "shopping_basket", color = "gray"},
}
local UNITS = {"u_pcs", "u_kg", "u_g", "u_l", "u_pack"}
local catNames, unitNames = {}, {}

-- ------------------------------------------------------------------ data
local lists = {}          -- { {id, name, items = { {id, name, qty, unit, cat, done} } } }
local cur = 1
local history = {}        -- { {name, cat, unit, n} } most used first
local nextId = 1
local version = 0         -- bumped on every change; caches rebuild when it moves

local input, qtyText, addCat = "", "1", 1
local message, messageT = "", 0
local undoSnap, undoT = nil, 0   -- one level of undo for destructive actions
local pops = {}           -- item id -> time it was checked/added (animations)
local shownDone = 0       -- eased progress value
local sel = 0             -- selected row index (keyboard)
local sheet = nil         -- item editor

local function list() return lists[cur] end

local function save()
  store.set("lists", lists)
  store.set("cur", cur)
  store.set("history", history)
  store.set("nextId", nextId)
  version = version + 1
end

local function say(text)
  message, messageT = text, sys.time()
end

-- deep copy for the undo snapshot
local function copy(v)
  if type(v) ~= "table" then return v end
  local o = {}
  for k, x in pairs(v) do o[k] = copy(x) end
  return o
end

local function snapshot(text)
  undoSnap = {lists = copy(lists), cur = cur, text = text}
  undoT = sys.time()
end

local function newId()
  nextId = nextId + 1
  return nextId - 1
end

local function sanitizeItem(it)
  if type(it) ~= "table" or type(it.name) ~= "string" or trim(it.name) == "" then return nil end
  local cat = floor(tonumber(it.cat) or #CATS)
  local unit = floor(tonumber(it.unit) or 1)
  return {id = tonumber(it.id) or newId(), name = it.name, qty = parseQty(tostring(it.qty or 1)) or 1,
          unit = (unit >= 1 and unit <= #UNITS) and unit or 1, cat = (cat >= 1 and cat <= #CATS) and cat or #CATS,
          done = it.done == true}
end

local function remember(name, cat, unit)
  local k = fold(name)
  for i, h in ipairs(history) do
    if fold(h.name) == k then
      h.name, h.cat, h.unit, h.n = name, cat, unit, (tonumber(h.n) or 0) + 1
      -- keep the array ordered by use count
      while i > 1 and (tonumber(history[i - 1].n) or 0) < h.n do
        history[i - 1], history[i] = history[i], history[i - 1]
        i = i - 1
      end
      return
    end
  end
  history[#history + 1] = {name = name, cat = cat, unit = unit, n = 1}
  while #history > 200 do table.remove(history) end
end

local function findByName(l, name)
  local k = fold(name)
  for i, it in ipairs(l.items) do if fold(it.name) == k then return it, i end end
end

local function addItem(name, qty, unit, cat)
  local l = list()
  name = trim(name)
  if not l or name == "" then return false end
  if #name > 60 then name = name:sub(1, 60) end
  local it = findByName(l, name)
  if it then
    -- already on the list: add to the quantity (or bring it back from the cart)
    if it.done then it.done = false; it.qty = qty else it.qty = min(9999, it.qty + qty) end
    it.unit, it.cat = unit, cat
    say(TR("msg_merged", it.name))
  else
    local nid = newId()
    l.items[#l.items + 1] = {id = nid, name = name, qty = qty, unit = unit, cat = cat, done = false}
    pops[nid] = sys.time()
  end
  remember(name, cat, unit)
  undoSnap = nil
  save()
  audio.play("pop")
  return true
end

local function addFromInput()
  local name = trim(input)
  if name == "" then say(TR("err_name")); audio.play("error"); return end
  local q = parseQty(qtyText)
  if not q then say(TR("err_qty")); audio.play("error"); return end
  if addItem(name, q, 1, addCat) then input, qtyText = "", "1" end
end

local function toggleItem(it)
  it.done = not it.done
  pops[it.id] = sys.time()
  undoSnap = nil
  save()
  audio.tone(it.done and 880 or 520, 0.06, 0.25, "triangle")
end

local function deleteItem(it)
  local l = list()
  if not l then return end
  snapshot(TR("undo_delete", it.name))
  for i, x in ipairs(l.items) do
    if x == it then table.remove(l.items, i); break end
  end
  save()
  audio.play("trash")
end

local function clearChecked()
  local l = list()
  if not l then return end
  local keep, n = {}, 0
  for _, it in ipairs(l.items) do
    if it.done then n = n + 1 else keep[#keep + 1] = it end
  end
  if n == 0 then return end
  snapshot(TR("msg_cleared", n))
  l.items = keep
  save()
  say(TR("msg_cleared", n))
  audio.play("trash")
end

local function uncheckAll()
  local l = list()
  if not l then return end
  for _, it in ipairs(l.items) do it.done = false end
  undoSnap = nil
  save()
end

local function undo()
  if not undoSnap then return end
  lists, cur = undoSnap.lists, undoSnap.cur
  undoSnap = nil
  sel = 0
  save()
  say(TR("msg_undone"))
  audio.play("pop")
end

-- ------------------------------------------------------------------ export
local function listText()
  local l = lists[cur]
  if not l then return "" end
  local out = {l.name, ""}
  for c = 1, #CATS do
    local any = false
    for _, it in ipairs(l.items) do
      if it.cat == c and not it.done then
        if not any then out[#out + 1] = catNames[c] or ""; any = true end
        local q = (it.unit == 1 and it.qty == 1) and "" or ("  " .. fmtQty(it.qty) .. " " .. (unitNames[it.unit] or ""))
        out[#out + 1] = "[ ] " .. it.name .. q
      end
    end
    if any then out[#out + 1] = "" end
  end
  for _, it in ipairs(l.items) do
    if it.done then out[#out + 1] = "[x] " .. it.name end
  end
  return table.concat(out, "\n")
end

local function copyList()
  sys.clipboard(listText())
  say(TR("msg_copied"))
  audio.play("click")
end

local function exportList()
  local l = lists[cur]
  if not l then return end
  local fname = trim((l.name:gsub("[/\\:%*%?\"<>|]", ""))) .. ".txt"
  if fname == ".txt" then fname = "list.txt" end
  ui.saveFile(function(path)
    if not path then return end
    if fs.write(path, listText()) then say(TR("msg_saved")) else say(TR("msg_save_failed")) end
  end, fname, TR("export"))
end

-- ------------------------------------------------------------------ lists
local function ensureList()
  if #lists == 0 then
    lists[1] = {id = newId(), name = TR("default_list"), items = {}}
  end
  if cur < 1 or cur > #lists then cur = 1 end
end

local function newList()
  ui.prompt(TR("new_list"), TR("list_name_msg"), TR("default_list"), function(s)
    s = trim(s)
    if s == "" then return end
    lists[#lists + 1] = {id = newId(), name = s:sub(1, 40), items = {}}
    cur = #lists
    sel = 0
    save()
  end)
end

local function renameList()
  local l = list()
  if not l then return end
  ui.prompt(TR("rename_list"), TR("list_name_msg"), l.name, function(s)
    s = trim(s)
    if s == "" or not lists[cur] then return end
    lists[cur].name = s:sub(1, 40)
    save()
  end)
end

local function deleteList()
  local l = list()
  if not l then return end
  ui.alert(TR("delete_list"), TR("delete_list_msg", l.name), {TR("delete"), TR("cancel")}, function(b)
    if b ~= 1 then return end
    snapshot(TR("undo_list", l.name))
    for i, x in ipairs(lists) do if x == l then table.remove(lists, i); break end end
    ensureList()
    cur = min(cur, #lists)
    sel = 0
    save()
    audio.play("trash")
  end)
end

local function switchList(d)
  if #lists == 0 then return end
  cur = (cur - 1 + d) % #lists + 1
  sel = 0
  store.set("cur", cur)
  version = version + 1
end

-- ------------------------------------------------------------------ cached views
-- rows: {kind = "head", cat, n} | {kind = "cart", n} | {kind = "item", it}
local rows, rowsVer, rowsCur = {}, -1, -1
local counts = {total = 0, done = 0}
local function buildRows()
  if rowsVer == version and rowsCur == cur then return end
  rowsVer, rowsCur = version, cur
  rows = {}
  counts.total, counts.done = 0, 0
  local l = list()
  if not l then return end
  local byCat, checked = {}, {}
  for _, it in ipairs(l.items) do
    counts.total = counts.total + 1
    if it.done then
      counts.done = counts.done + 1
      checked[#checked + 1] = it
    else
      local b = byCat[it.cat]
      if not b then b = {}; byCat[it.cat] = b end
      b[#b + 1] = it
    end
  end
  local function byName(a, b) return fold(a.name) < fold(b.name) end
  for c = 1, #CATS do
    local b = byCat[c]
    if b then
      table.sort(b, byName)
      rows[#rows + 1] = {kind = "head", cat = c, n = #b}
      for _, it in ipairs(b) do rows[#rows + 1] = {kind = "item", it = it} end
    end
  end
  if #checked > 0 then
    table.sort(checked, byName)
    rows[#rows + 1] = {kind = "cart", n = #checked}
    for _, it in ipairs(checked) do rows[#rows + 1] = {kind = "item", it = it} end
  end
  if sel > #rows or (rows[sel] and rows[sel].kind ~= "item") then sel = 0 end
end

-- history suggestions for the current input (not already open on the list)
local sugs, sugKey = {}, ""
local function buildSugs()
  local key = input .. "\0" .. version .. "\0" .. cur
  if key == sugKey then return end
  sugKey = key
  sugs = {}
  local l = list()
  local q = fold(input)
  for _, h in ipairs(history) do
    local k = fold(h.name)
    if q == "" or k:find(q, 1, true) then
      local it = l and findByName(l, h.name)
      if not it or it.done then sugs[#sugs + 1] = h end
    end
    if #sugs >= 12 then break end
  end
end

-- ------------------------------------------------------------------ item editor
local function openEditor(it)
  sheet = {it = it, name = it.name, qty = fmtQty(it.qty), unit = it.unit, cat = it.cat, err = ""}
  editing = false
  audio.play("pop")
end

local function commitEditor()
  local s = sheet
  if not s then return end
  local name = trim(s.name)
  if name == "" then s.err = TR("err_name"); audio.play("error"); return end
  local q = parseQty(s.qty)
  if not q then s.err = TR("err_qty"); audio.play("error"); return end
  local l = list()
  local other = l and findByName(l, name)
  if other and other ~= s.it then s.err = TR("err_exists"); audio.play("error"); return end
  s.it.name, s.it.qty, s.it.unit, s.it.cat = name:sub(1, 60), q, s.unit, s.cat
  remember(s.it.name, s.cat, s.unit)
  sheet = nil
  editing = false
  undoSnap = nil
  save()
end

local function itemMenu(it)
  ui.contextMenu({
    {label = TR("edit"), id = 1, icon = "edit"},
    {label = it.done and TR("uncheck") or TR("check"), id = 2, icon = it.done and "remove_shopping_cart" or "add_shopping_cart"},
    "-",
    {label = TR("delete"), id = 3, icon = "delete"},
  }, function(id)
    if id == 1 then openEditor(it) elseif id == 2 then toggleItem(it) elseif id == 3 then deleteItem(it) end
  end)
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  for i, c in ipairs(CATS) do catNames[i] = TR(c.key) end
  for i, u in ipairs(UNITS) do unitNames[i] = TR(u) end
  nextId = floor(tonumber(store.get("nextId", 1)) or 1)
  lists = {}
  local raw = store.get("lists", {})
  if type(raw) == "table" then
    for _, l in ipairs(raw) do
      if type(l) == "table" and type(l.name) == "string" then
        local o = {id = tonumber(l.id) or newId(), name = l.name, items = {}}
        if type(l.items) == "table" then
          for _, it in ipairs(l.items) do
            local s = sanitizeItem(it)
            if s then o.items[#o.items + 1] = s end
          end
        end
        lists[#lists + 1] = o
      end
    end
  end
  history = {}
  local hr = store.get("history", {})
  if type(hr) == "table" then
    for _, h in ipairs(hr) do
      if type(h) == "table" and type(h.name) == "string" and trim(h.name) ~= "" then
        local c, u = floor(tonumber(h.cat) or #CATS), floor(tonumber(h.unit) or 1)
        history[#history + 1] = {name = h.name, cat = (c >= 1 and c <= #CATS) and c or #CATS,
                                  unit = (u >= 1 and u <= #UNITS) and u or 1, n = tonumber(h.n) or 1}
      end
    end
  end
  cur = floor(tonumber(store.get("cur", 1)) or 1)
  ensureList()
end

function app.update(dt)
  buildRows()
  local target = counts.total > 0 and counts.done / counts.total or 0
  shownDone = shownDone + (target - shownDone) * min(1, dt * 8)
end

-- ------------------------------------------------------------------ drawing
local function drawSidebar(sw, h, interactive)
  gfx.rect(0, 0, sw, h, 0, theme.sidebar)
  gfx.color(theme.separator)
  gfx.line(sw, 0, sw, h, 1)
  gfx.color(theme.text2)
  gfx.text(TR("lists"), 16, 18, 12, "semibold")
  local top, rh = 42, 36
  local areaH = h - top - 58
  ui.beginScroll("lists", 0, top, sw, areaH, #lists * rh + 4)
  for i, l in ipairs(lists) do
    local y = (i - 1) * rh
    local open = 0
    for _, it in ipairs(l.items) do if not it.done then open = open + 1 end end
    if interactive and ui.row("lst" .. l.id, 8, y, sw - 16, rh - 4, i == cur) then
      if cur ~= i then cur = i; sel = 0; store.set("cur", cur); version = version + 1 end
    elseif not interactive and i == cur then
      gfx.rect(8, y, sw - 16, rh - 4, 8, theme.selection)
    end
    local active = i == cur
    gfx.icon("shopping_cart", 26, y + (rh - 4) / 2, 16, active and theme.accent or theme.text2)
    gfx.clip(40, y, sw - 90, rh)
    gfx.color(theme.text)
    gfx.text(l.name, 42, y + 8, 13, active and "semibold" or "sans")
    gfx.unclip()
    if open > 0 then
      gfx.color(theme.text3)
      gfx.text(tostring(open), 0, y + 9, 12, "medium", "right", sw - 20)
    end
  end
  ui.endScroll()
  if interactive and ui.button(TR("new_list") .. "##side", 12, h - 46, sw - 24, 34, "default", "playlist_add") then newList() end
end

local function drawEmpty(x, y, w, h)
  local cy = y + h / 2 - 50
  gfx.circle(x + w / 2, cy, 36, fade(theme.accent, 0.12))
  gfx.icon("shopping_cart", x + w / 2, cy, 36, theme.accent)
  gfx.color(theme.text)
  gfx.text(TR("empty_title"), x, cy + 50, 17, "bold", "center", w)
  gfx.color(theme.text2)
  gfx.text(TR("empty_body"), x, cy + 76, 13, "sans", "center", w)
end

local function drawItemRow(r, i, x, y, w, rh, interactive)
  local it = r.it
  local cat = CATS[it.cat] or CATS[#CATS]
  local col = theme[cat.color] or theme.gray
  if i == sel then gfx.rect(x, y + 1, w, rh - 2, 8, fade(theme.accent, 0.14)) end
  local hc = interactive and ui.hit("chk" .. it.id, x, y, 40, rh)
  local hr = interactive and ui.hit("itm" .. it.id, x + 40, y, w - 40, rh)
  if hr and hr.hovered then gfx.rect(x + 40, y + 2, w - 40, rh - 4, 8, theme.hover) end
  -- checkbox circle
  local cx, cy = x + 20, y + rh / 2
  local pt = pops[it.id]
  local age = pt and (sys.time() - pt) or 9
  if age > 0.6 then pops[it.id] = nil end
  if age < 0.6 and not it.done then
    gfx.rect(x, y + 1, w, rh - 2, 8, fade(theme.accent, 0.22 * (1 - age / 0.6)))
  end
  if it.done then
    local sc = age < 0.3 and (1 + 0.3 * math.sin(age / 0.3 * math.pi)) or 1
    gfx.circle(cx, cy, 11 * sc, theme.green)
    gfx.icon("check", cx, cy, 15 * sc, "#FFFFFF")
  else
    if hc and hc.hovered then gfx.circle(cx, cy, 11, fade(col, 0.18)) end
    gfx.color(col)
    gfx.circleLine(cx, cy, 10, 2)
  end
  -- name and quantity
  gfx.alpha(it.done and 0.45 or 1)
  local qtxt = (it.unit == 1 and it.qty == 1) and "" or (fmtQty(it.qty) .. " " .. (unitNames[it.unit] or ""))
  local qw = qtxt ~= "" and gfx.textWidth(qtxt, 13, "medium") + 16 or 0
  gfx.clip(x + 42, y, w - 90 - qw, rh)
  gfx.color(theme.text)
  local tw = gfx.text(it.name, x + 44, y + (rh - 18) / 2, 14, "medium")
  gfx.unclip()
  if it.done then
    gfx.color(theme.text2)
    gfx.line(x + 42, y + rh / 2 + 1, x + 46 + min(tw, w - 92 - qw), y + rh / 2 + 1, 1.5)
  end
  if qtxt ~= "" then
    gfx.rect(x + w - 44 - qw, y + (rh - 24) / 2, qw, 24, 12, fade(col, 0.16))
    gfx.color(theme.text)
    gfx.text(qtxt, x + w - 44 - qw, y + (rh - 24) / 2 + 4, 13, "medium", "center", qw)
  end
  gfx.unalpha()
  if interactive and ui.iconButton("more_vert", x + w - 36, y + (rh - 30) / 2, 32, 30, theme.text3, false, "m" .. it.id) then
    sel = i
    itemMenu(it)
  end
  if hc and hc.clicked then sel = i; toggleItem(it) end
  if hr then
    if hr.clicked then sel = i; openEditor(it) end
    if hr.rightClicked then sel = i; itemMenu(it) end
  end
end

local function drawMain(x, w, h, interactive)
  local l = list()
  if not l then return end
  buildRows()
  buildSugs()
  -- header
  gfx.clip(x, 10, w - 84, 30)
  gfx.color(theme.text)
  gfx.text(l.name, x, 12, 20, "bold")
  gfx.unclip()
  if interactive then
    if ui.iconButton("edit", x + w - 72, 10, 34, 30, theme.text2, false, "ren") then renameList() end
    if ui.iconButton("delete", x + w - 36, 10, 34, 30, theme.red, false, "dell") then deleteList() end
  end
  gfx.color(theme.text2)
  local summary = counts.total == 0 and TR("sum_empty") or TR("summary", counts.total - counts.done, counts.done)
  gfx.text(summary, x, 40, 12)
  if counts.total > 0 then ui.progress(min(1, max(0, shownDone)), x + w - 140, 46, 140, 6) end

  -- add row: name, quantity, category, add
  local ay = 66
  local catW = min(170, max(120, floor(w * 0.26)))
  local addW = w >= 520 and 96 or 40
  local nameW = w - 64 - catW - addW - 24
  if interactive then
    local t, sub = field("add_name", input, x, ay, nameW, 32, TR("add_placeholder"))
    if t ~= input then input = t:sub(1, 60) end
    local qt, sub2 = field("add_qty", qtyText, x + nameW + 8, ay, 64, 32, "1", "numeric")
    if qt ~= qtyText then qtyText = qt:sub(1, 7) end
    addCat = ui.dropdown("add_cat", catNames, addCat, x + nameW + 80, ay, catW, 32)
    if ui.button((addW > 40 and TR("add") or "") .. "##add", x + w - addW, ay, addW, 32, "primary", "add") or sub or sub2 then
      addFromInput()
      ui.focus("add_name")
    end
  end
  -- history suggestions
  local sy = ay + 40
  if #sugs == 0 then
    gfx.color(theme.text3)
    gfx.text(#history == 0 and TR("hint_history") or TR("hint_nomatch"), x, sy + 7, 12)
  else
    gfx.icon("history", x + 9, sy + 14, 16, theme.text3)
    local cx = x + 24
    for i, sg in ipairs(sugs) do
      local bw = gfx.textWidth(sg.name, 13) + 26
      if cx + bw > x + w then break end
      if interactive and ui.button(sg.name .. "##sug" .. i, cx, sy, bw, 28, "default") then
        addItem(sg.name, 1, sg.unit, sg.cat)
        input = ""
      elseif not interactive then
        gfx.rect(cx, sy, bw, 28, 8, theme.control)
      end
      cx = cx + bw + 6
    end
  end

  -- grouped list
  local top = sy + 38
  local fh = 52
  local areaH = h - top - fh
  if #rows == 0 then
    drawEmpty(x, top, w, areaH)
  else
    local heads, itemsH = 0, 0
    for _, r in ipairs(rows) do if r.kind == "item" then itemsH = itemsH + 42 else heads = heads + 32 end end
    ui.beginScroll("items", x - 8, top, w + 16, areaH, heads + itemsH + 8)
    local y = 0
    for i, r in ipairs(rows) do
      if r.kind == "item" then
        drawItemRow(r, i, 8, y, w, 42, interactive)
        y = y + 42
      else
        local icon, col, label
        if r.kind == "head" then
          local c = CATS[r.cat] or CATS[#CATS]
          icon, col, label = c.icon, theme[c.color] or theme.gray, catNames[r.cat] or ""
        else
          icon, col, label = "shopping_cart", theme.green, TR("in_cart")
        end
        gfx.circle(20, y + 18, 11, fade(col, 0.18))
        gfx.icon(icon, 20, y + 18, 14, col)
        gfx.color(theme.text2)
        local lw = gfx.text(label, 38, y + 10, 12, "semibold")
        gfx.color(theme.text3)
        gfx.text(tostring(r.n), 46 + lw, y + 10, 12)
        y = y + 32
      end
    end
    ui.endScroll()
  end

  -- footer: clear / uncheck on the left, undo or the last message on the right
  local fy = h - 44
  ui.separator(x, fy - 8, x + w)
  local wide = w >= 600
  local fx = x
  if interactive then
    if ui.button(TR("clear_checked", counts.done) .. "##clr", fx, fy, 180, 32, "default", "delete_sweep", counts.done > 0) then
      clearChecked()
    end
    if wide and ui.button(TR("uncheck_all") .. "##unc", fx + 188, fy, 150, 32, "plain", "restart_alt", counts.done > 0) then
      uncheckAll()
    end
  end
  local mx = fx + (wide and 346 or 188)
  local showUndo = undoSnap and sys.time() - undoT < 8
  local text = showUndo and undoSnap.text or ((message ~= "" and sys.time() - messageT < 3) and message or "")
  local tw = x + w - mx - (showUndo and 104 or 0)
  if text ~= "" and tw > 20 then
    gfx.clip(mx, fy, tw, 32)
    gfx.color(theme.text2)
    gfx.text(text, mx, fy + 8, 12, "sans", "right", tw)
    gfx.unclip()
  end
  if showUndo and interactive and ui.button(TR("undo") .. "##undo", x + w - 96, fy, 96, 32, "default", "undo") then undo() end
end

local function drawSheet(w, h)
  local s = sheet
  gfx.rect(0, 0, w, h, 0, {0, 0, 0, 110})
  local sw, shh = min(440, w - 40), 296
  local sx, sy = floor((w - sw) / 2), floor((h - shh) / 2)
  gfx.shadow(sx, sy, sw, shh, 14, 30, 10)
  gfx.rect(sx, sy, sw, shh, 14, theme.dark and "#2C2C2E" or "#F6F6F6")
  gfx.color(theme.separator)
  gfx.rectLine(sx, sy, sw, shh, 14, 1)
  gfx.color(theme.text)
  gfx.text(TR("edit_item"), sx + 20, sy + 16, 17, "bold")
  local y = sy + 50
  gfx.color(theme.text2)
  gfx.text(TR("name"), sx + 20, y, 12, "semibold")
  local nm, sub = field("ed_name", s.name, sx + 20, y + 18, sw - 40, 32, TR("add_placeholder"))
  if nm ~= s.name then s.name = nm:sub(1, 60); s.err = "" end
  y = y + 62
  gfx.color(theme.text2)
  gfx.text(TR("quantity"), sx + 20, y, 12, "semibold")
  gfx.text(TR("unit"), sx + 196, y, 12, "semibold")
  if ui.iconButton("remove", sx + 20, y + 18, 32, 32, theme.text2, false, "qm") then
    local q = parseQty(s.qty) or 1
    s.qty = fmtQty(max(1, q - 1))
  end
  local qt, sub2 = field("ed_qty", s.qty, sx + 56, y + 18, 70, 32, "1", "numeric")
  if qt ~= s.qty then s.qty = qt:sub(1, 7); s.err = "" end
  if ui.iconButton("add", sx + 130, y + 18, 32, 32, theme.text2, false, "qp") then
    local q = parseQty(s.qty) or 0
    s.qty = fmtQty(min(9999, q + 1))
  end
  s.unit = ui.dropdown("ed_unit", unitNames, s.unit, sx + 196, y + 18, sw - 216, 32)
  y = y + 62
  gfx.color(theme.text2)
  gfx.text(TR("category"), sx + 20, y, 12, "semibold")
  s.cat = ui.dropdown("ed_cat", catNames, s.cat, sx + 20, y + 18, sw - 40, 32)
  if s.err ~= "" then
    gfx.color(theme.red)
    gfx.text(s.err, sx + 20, y + 56, 12)
  end
  local fy = sy + shh - 46
  if ui.button(TR("delete") .. "##ed", sx + 20, fy, 92, 32, "destructive") then
    local it = s.it
    sheet = nil
    deleteItem(it)
    return
  end
  if ui.button(TR("cancel") .. "##ed", sx + sw - 220, fy, 96, 32) then sheet = nil; return end
  if ui.button(TR("save") .. "##ed", sx + sw - 116, fy, 96, 32, "primary") or sub or sub2 then commitEditor() end
end

function app.draw(w, h)
  nFields = 0
  gfx.clear(theme.bg)
  ensureList()
  local interactive = sheet == nil
  local sw = w < 640 and 156 or 190
  drawSidebar(sw, h, interactive)
  drawMain(sw + 18, w - sw - 36, h, interactive)
  if sheet then drawSheet(w, h) end
end

-- ------------------------------------------------------------------ input
local function moveSel(d)
  buildRows()
  local i = sel
  for _ = 1, #rows do
    i = i + d
    if i < 1 or i > #rows then return end
    if rows[i].kind == "item" then sel = i; return end
  end
end

function app.event(e)
  if e.type == "mousedown" then
    editing = pointInField(e.x, e.y)
    return
  end
  if e.type ~= "keydown" then return end
  if sheet then
    if e.key == "escape" then sheet = nil; editing = false
    elseif e.key == "enter" and not editing then commitEditor() end
    return
  end
  if e.ctrl then
    if e.key == "n" then newList()
    elseif e.key == "l" then ui.focus("add_name"); editing = true
    elseif (e.key == "delete" or e.key == "backspace") and not editing then clearChecked()
    elseif e.key == "z" and not editing then undo()
    elseif e.key == "c" and not editing then copyList()
    elseif e.key == "s" then exportList() end
    return
  end
  if editing then
    if e.key == "escape" then editing = false end
    return
  end
  local r = rows[sel]
  if e.key == "down" then moveSel(1)
  elseif e.key == "up" then moveSel(-1)
  elseif e.key == "pagedown" then switchList(1)
  elseif e.key == "pageup" then switchList(-1)
  elseif (e.key == "space" or e.key == "enter") and r and r.kind == "item" then toggleItem(r.it)
  elseif e.key == "e" and r and r.kind == "item" then openEditor(r.it)
  elseif (e.key == "delete" or e.key == "backspace") and r and r.kind == "item" then deleteItem(r.it)
  elseif e.key == "escape" then sel = 0 end
end

function app.menu()
  return {
    {title = TR("menu_list"), items = {
      {label = TR("new_list"), id = 1, shortcut = "Ctrl+N"},
      {label = TR("rename_list"), id = 2},
      {label = TR("delete_list"), id = 3},
      "-",
      {label = TR("next_list"), id = 4, shortcut = "PgDn"},
      {label = TR("prev_list"), id = 5, shortcut = "PgUp"},
      "-",
      {label = TR("copy_list"), id = 6, shortcut = "Ctrl+C"},
      {label = TR("export"), id = 7, shortcut = "Ctrl+S"},
    }},
    {title = TR("menu_items"), items = {
      {label = TR("undo"), id = 9, shortcut = "Ctrl+Z"},
      "-",
      {label = TR("add_item"), id = 10, shortcut = "Ctrl+L"},
      {label = TR("toggle_selected"), id = 11, shortcut = "Space"},
      {label = TR("edit_selected"), id = 12, shortcut = "E"},
      {label = TR("delete_selected"), id = 13, shortcut = "Delete"},
      "-",
      {label = TR("clear_checked_menu"), id = 14, shortcut = "Ctrl+Delete"},
      {label = TR("uncheck_all"), id = 15},
      {label = TR("clear_history"), id = 16},
    }},
  }
end

function app.onmenu(id)
  ensureList()
  if sheet then return end
  buildRows()
  local r = rows[sel]
  if id == 1 then newList()
  elseif id == 2 then renameList()
  elseif id == 3 then deleteList()
  elseif id == 4 then switchList(1)
  elseif id == 5 then switchList(-1)
  elseif id == 6 then copyList()
  elseif id == 7 then exportList()
  elseif id == 9 then undo()
  elseif id == 10 then ui.focus("add_name"); editing = true
  elseif id == 11 and r and r.kind == "item" then toggleItem(r.it)
  elseif id == 12 and r and r.kind == "item" then openEditor(r.it)
  elseif id == 13 and r and r.kind == "item" then deleteItem(r.it)
  elseif id == 14 then clearChecked()
  elseif id == 15 then uncheckAll()
  elseif id == 16 then
    ui.alert(TR("clear_history"), TR("clear_history_msg"), {TR("delete"), TR("cancel")}, function(b)
      if b == 1 then history = {}; save() end
    end)
  end
end

function app.close()
  store.set("lists", lists)
  store.set("history", history)
  store.save()
  return true
end

return app
