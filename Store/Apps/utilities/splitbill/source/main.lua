-- Split Bill: people, items (who shared what, who paid), tip and service, and who owes whom with the fewest
-- transfers. All money is kept in whole cents so totals always add up (Nexvyn OS Lua SDK).
local app = {}

-- ------------------------------------------------------------------ state
local people = {}        -- {id, name, color}
local items = {}         -- {id, name, cents, qty, payer = person id, shared = {person ids} (empty = everyone)}
local tipPct, taxPct = 10, 0
local cur = 1
local nextId = 1
local tab = 1            -- 1 people, 2 items, 3 result
local editing = nil      -- item open in the editor
local edName, edPrice = "", ""
local newPerson, newItem, newPrice = "", "", ""
local errPerson, errItem = nil, nil
local msg, msgT = nil, 0
local undoSnap, undoT, undoText = nil, 0, ""
local appear = {}        -- id -> 0..1 slide-in
local pieA = {}          -- animated pie fractions per person id
local dirty = true
local lang = "en"

local CURRENCIES = {"₺", "$", "€", "£"}
local COLORS = {"#0A84FF", "#FF9F0A", "#30D158", "#BF5AF2", "#FF375F", "#64D2FF", "#FFD60A", "#AC8E68",
                "#5E5CE6", "#FF6482", "#32ADE6", "#A2845E"}
local MAX_PEOPLE = 12

-- results
local R = {subtotal = 0, extra = 0, total = 0, owes = {}, paid = {}, cons = {}, transfers = {}, nTransfers = 0}

-- ------------------------------------------------------------------ helpers
local function trim(s) return ((s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function fmt(c)
  local neg = c < 0
  c = math.abs(math.floor(c + 0.5))
  local whole, frac = c // 100, c % 100
  local ts, ds = ",", "."
  if lang == "tr" then ts, ds = ".", "," end
  local s = tostring(whole):reverse():gsub("(%d%d%d)", "%1" .. ts):reverse()
  if s:sub(1, 1) == ts then s = s:sub(2) end
  s = s .. ds .. string.format("%02d", frac)
  local sym = CURRENCIES[cur] or "₺"
  if lang == "tr" then s = s .. " " .. sym else s = sym .. s end
  return (neg and "−" or "") .. s
end

-- "12,50" "12.50" "1.234,50" "1,234.50" -> cents or nil
local function parseMoney(s)
  s = trim(s):gsub("%s", ""):gsub("[₺$€£]", "")
  if s == "" then return nil end
  local lastDot, lastComma = s:find("%.[^%.]*$"), s:find(",[^,]*$")
  if lastDot and lastComma then
    if lastComma > lastDot then s = s:gsub("%.", ""):gsub(",", ".") else s = s:gsub(",", "") end
  elseif lastComma then
    s = s:gsub(",", ".")
  end
  if not s:match("^%d*%.?%d*$") then return nil end
  local v = tonumber(s)
  if not v then return nil end
  return math.floor(v * 100 + 0.5)
end

local function deepcopy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = deepcopy(v) end
  return r
end

local function personById(id)
  for _, p in ipairs(people) do if p.id == id then return p end end
  return nil
end

local function flash(text) msg, msgT = text, 2.5 end

local function save()
  store.set("people", people)
  store.set("items", items)
  store.set("nextId", nextId)
  store.set("tip", tipPct)
  store.set("tax", taxPct)
  store.set("cur", cur)
  dirty = true
end

local function snapshot(text)
  undoSnap = {people = deepcopy(people), items = deepcopy(items)}
  undoT, undoText = 6, text
end

local function undo()
  if not undoSnap then return end
  people, items = undoSnap.people, undoSnap.items
  undoSnap, undoT = nil, 0
  save()
  audio.play("pop")
end

local function sharesOf(it)
  if type(it.shared) ~= "table" or #it.shared == 0 then return nil end
  return it.shared
end

local function isSharer(it, pid)
  local s = sharesOf(it)
  if not s then return true end
  for _, id in ipairs(s) do if id == pid then return true end end
  return false
end

-- distributes `amount` cents over `weights` (table id -> weight) with the largest-remainder method
local function distribute(amount, ids, weights, out)
  local total = 0
  for _, id in ipairs(ids) do total = total + (weights[id] or 0) end
  if total <= 0 or amount == 0 then return end
  local given, rem = 0, {}
  for i, id in ipairs(ids) do
    local exact = amount * (weights[id] or 0) / total
    local f = math.floor(exact)
    out[id] = (out[id] or 0) + f
    given = given + f
    rem[i] = {id = id, r = exact - f}
  end
  table.sort(rem, function(a, b) if a.r ~= b.r then return a.r > b.r end return a.id < b.id end)
  local left = amount - given
  local i = 1
  while left > 0 and #rem > 0 do
    local id = rem[(i - 1) % #rem + 1].id
    out[id] = out[id] + 1
    left = left - 1
    i = i + 1
  end
end

-- ------------------------------------------------------------------ calculation
local function compute()
  dirty = false
  local cons, paidBase, owes, paid = {}, {}, {}, {}
  local ids = {}
  for i, p in ipairs(people) do ids[i] = p.id; cons[p.id], paidBase[p.id], owes[p.id], paid[p.id] = 0, 0, 0, 0 end
  local subtotal = 0
  if #people > 0 then
    for _, it in ipairs(items) do
      local line = (it.cents or 0) * (it.qty or 1)
      subtotal = subtotal + line
      local sharers = {}
      for _, p in ipairs(people) do if isSharer(it, p.id) then sharers[#sharers + 1] = p.id end end
      if #sharers == 0 then for _, p in ipairs(people) do sharers[#sharers + 1] = p.id end end
      local w = {}
      for _, id in ipairs(sharers) do w[id] = 1 end
      distribute(line, sharers, w, cons)
      local payer = personById(it.payer) and it.payer or people[1].id
      paidBase[payer] = paidBase[payer] + line
    end
  end
  local extra = math.floor(subtotal * (tipPct + taxPct) / 100 + 0.5)
  for _, id in ipairs(ids) do owes[id], paid[id] = cons[id], paidBase[id] end
  distribute(extra, ids, cons, owes)
  distribute(extra, ids, paidBase, paid)
  R.subtotal, R.extra, R.total, R.owes, R.paid, R.cons = subtotal, extra, subtotal + extra, owes, paid, cons
  -- settle: biggest debtor pays biggest creditor until everything is zero
  local debt, cred = {}, {}
  for _, id in ipairs(ids) do
    local b = paid[id] - owes[id]
    if b < 0 then debt[#debt + 1] = {id = id, v = -b} elseif b > 0 then cred[#cred + 1] = {id = id, v = b} end
  end
  local tr = R.transfers
  for i = #tr, 1, -1 do tr[i] = nil end
  local guard = 0
  while #debt > 0 and #cred > 0 and guard < 200 do
    guard = guard + 1
    table.sort(debt, function(a, b) return a.v > b.v end)
    table.sort(cred, function(a, b) return a.v > b.v end)
    local d, c = debt[1], cred[1]
    local v = math.min(d.v, c.v)
    tr[#tr + 1] = {from = d.id, to = c.id, v = v}
    d.v, c.v = d.v - v, c.v - v
    if d.v == 0 then table.remove(debt, 1) end
    if c.v == 0 then table.remove(cred, 1) end
  end
  R.nTransfers = #tr
end

-- ------------------------------------------------------------------ actions
local function addPerson()
  local name = trim(newPerson)
  errPerson = nil
  if name == "" then errPerson = TR("err_name"); audio.play("error"); return end
  if (utf8.len(name) or 0) > 24 then errPerson = TR("err_long"); audio.play("error"); return end
  if #people >= MAX_PEOPLE then errPerson = TR("err_max", MAX_PEOPLE); audio.play("error"); return end
  for _, p in ipairs(people) do
    if p.name:lower() == name:lower() then errPerson = TR("err_dup"); audio.play("error"); return end
  end
  local used = {}
  for _, p in ipairs(people) do used[p.color] = true end
  local color = COLORS[(#people % #COLORS) + 1]
  for _, c in ipairs(COLORS) do if not used[c] then color = c break end end
  local p = {id = nextId, name = name, color = color}
  nextId = nextId + 1
  people[#people + 1] = p
  appear[p.id] = 0
  newPerson = ""
  save()
  audio.tone(523, 0.06, 0.2, "triangle"); audio.tone(784, 0.1, 0.15, "sine")
end

local function removePerson(p)
  snapshot(TR("removed", p.name))
  for i, x in ipairs(people) do if x == p then table.remove(people, i) break end end
  for _, it in ipairs(items) do
    if type(it.shared) == "table" then
      for i = #it.shared, 1, -1 do if it.shared[i] == p.id then table.remove(it.shared, i) end end
    end
    if it.payer == p.id then it.payer = people[1] and people[1].id or nil end
  end
  save()
  audio.play("trash")
end

local function renamePerson(p)
  ui.prompt(TR("rename"), TR("person_name"), p.name, function(s)
    s = trim(s)
    if s == "" or (utf8.len(s) or 0) > 24 then return end
    for _, x in ipairs(people) do if x ~= p and x.name:lower() == s:lower() then flash(TR("err_dup")); return end end
    p.name = s
    save()
  end)
end

local function addItem()
  errItem = nil
  local name = trim(newItem)
  local c = parseMoney(newPrice)
  if #people == 0 then errItem = TR("err_nopeople"); tab = 1; audio.play("error"); return end
  if name == "" then errItem = TR("err_itemname"); audio.play("error"); return end
  if (utf8.len(name) or 0) > 40 then errItem = TR("err_long"); audio.play("error"); return end
  if not c or c <= 0 then errItem = TR("err_price"); audio.play("error"); return end
  if c > 100000000 then errItem = TR("err_big"); audio.play("error"); return end
  local it = {id = nextId, name = name, cents = c, qty = 1, payer = people[1].id, shared = {}}
  nextId = nextId + 1
  items[#items + 1] = it
  appear[it.id] = 0
  newItem, newPrice = "", ""
  save()
  audio.tone(659, 0.06, 0.2, "triangle"); audio.tone(988, 0.1, 0.15, "sine")
end

local function removeItem(it)
  snapshot(TR("removed", it.name))
  for i, x in ipairs(items) do if x == it then table.remove(items, i) break end end
  if editing == it then editing = nil end
  save()
  audio.play("trash")
end

local function openItem(it)
  editing = it
  edName = it.name
  edPrice = string.format("%d.%02d", it.cents // 100, it.cents % 100)
  if lang == "tr" then edPrice = edPrice:gsub("%.", ",") end
end

local function summaryText()
  if dirty then compute() end
  local out = {TR("app_name"), ""}
  for _, it in ipairs(items) do
    local q = (it.qty or 1) > 1 and (it.qty .. " × ") or ""
    out[#out + 1] = "• " .. q .. it.name .. ": " .. fmt(it.cents * (it.qty or 1))
  end
  out[#out + 1] = ""
  out[#out + 1] = TR("subtotal") .. ": " .. fmt(R.subtotal)
  if R.extra > 0 then out[#out + 1] = TR("tip_service", tipPct + taxPct) .. ": " .. fmt(R.extra) end
  out[#out + 1] = TR("total") .. ": " .. fmt(R.total)
  out[#out + 1] = ""
  for _, p in ipairs(people) do
    out[#out + 1] = p.name .. ": " .. TR("share_line", fmt(R.owes[p.id] or 0), fmt(R.paid[p.id] or 0))
  end
  out[#out + 1] = ""
  if R.nTransfers == 0 then out[#out + 1] = TR("settled") end
  for _, t in ipairs(R.transfers) do
    local a, b = personById(t.from), personById(t.to)
    if a and b then out[#out + 1] = TR("pays", a.name, b.name, fmt(t.v)) end
  end
  return table.concat(out, "\n") .. "\n"
end

local function copySummary()
  if #items == 0 then flash(TR("nothing")); return end
  sys.clipboard(summaryText())
  flash(TR("copied"))
  audio.play("pop")
end

local function exportSummary()
  if #items == 0 then flash(TR("nothing")); return end
  ui.saveFile(function(path)
    if not path then return end
    if fs.write(path, summaryText()) then flash(TR("exported")) else flash(TR("export_fail")) end
  end, "bill.txt", TR("export"))
end

local function newBill()
  if #items == 0 then return end
  ui.alert(TR("new_bill"), TR("new_bill_msg"), {TR("new_bill"), TR("common.cancel")}, function(b)
    if b ~= 1 then return end
    snapshot(TR("bill_cleared"))
    items = {}
    editing = nil
    tab = 2
    save()
  end)
end

local function resetAll()
  if #items == 0 and #people == 0 then return end
  ui.alert(TR("reset_all"), TR("reset_all_msg"), {TR("reset"), TR("common.cancel")}, function(b)
    if b ~= 1 then return end
    snapshot(TR("all_cleared"))
    items, people = {}, {}
    editing = nil
    tab = 1
    save()
  end)
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  lang = sys.lang()
  people = store.get("people", {})
  items = store.get("items", {})
  if type(people) ~= "table" then people = {} end
  if type(items) ~= "table" then items = {} end
  nextId = store.get("nextId", 1)
  for _, p in ipairs(people) do if p.id >= nextId then nextId = p.id + 1 end end
  for _, it in ipairs(items) do if it.id >= nextId then nextId = it.id + 1 end; if type(it.shared) ~= "table" then it.shared = {} end end
  tipPct = store.get("tip", 10)
  taxPct = store.get("tax", 0)
  cur = store.get("cur", lang == "tr" and 1 or 2)
  if not CURRENCIES[cur] then cur = 1 end
  tab = #people == 0 and 1 or (#items == 0 and 2 or 3)
end

function app.update(dt)
  if msgT > 0 then msgT = msgT - dt end
  if undoT > 0 then undoT = undoT - dt; if undoT <= 0 then undoSnap = nil end end
  for id, v in pairs(appear) do
    v = v + dt * 4
    if v >= 1 then appear[id] = nil else appear[id] = v end
  end
  if dirty then compute() end
  local k = 1 - 0.0005 ^ dt
  for _, p in ipairs(people) do
    local target = R.total > 0 and (R.owes[p.id] or 0) / R.total or 0
    pieA[p.id] = (pieA[p.id] or 0) + (target - (pieA[p.id] or 0)) * k
  end
end

-- ------------------------------------------------------------------ drawing helpers
local function ease(t) t = math.max(0, math.min(1, t)); return 1 - (1 - t) ^ 3 end

-- first letter, upper-cased (Turkish-aware for i)
local function initialOf(s)
  local a = utf8.offset(s, 2)
  local ch = a and s:sub(1, a - 1) or s
  if ch == "i" then return "İ" end
  local up = {["ç"] = "Ç", ["ğ"] = "Ğ", ["ı"] = "I", ["ö"] = "Ö", ["ş"] = "Ş", ["ü"] = "Ü"}
  return up[ch] or ch:upper()
end

local function avatar(p, x, y, r)
  gfx.circle(x, y, r, p.color or COLORS[1])
  gfx.color("#FFFFFF")
  gfx.text(initialOf(p.name), x - r, y - r * 0.62, r * 1.1, "bold", "center", r * 2)
end

local function emptyState(icon, title, sub, x, y, w, h)
  local cy = y + h / 2 - 50
  local bob = math.sin(sys.time() * 2) * 3
  gfx.circle(x + w / 2, cy + bob, 40, theme.hover)
  gfx.icon(icon, x + w / 2, cy + bob, 44, theme.text3)
  gfx.color(theme.text)
  gfx.text(title, x + 20, cy + 52, 16, "semibold", "center", w - 40)
  gfx.color(theme.text2)
  gfx.text(sub, x + 20, cy + 76, 13, "sans", "center", w - 40)
end

-- ------------------------------------------------------------------ tabs
local function drawPeople(x, y, w, h)
  local fw = w - 120
  local np, sub = ui.textfield("newperson", newPerson, x, y, fw, 34, TR("person_ph"))
  if np ~= newPerson then newPerson = np; errPerson = nil end
  if ui.button(TR("add"), x + fw + 8, y, 112, 34, "primary", "person_add") or sub then addPerson() end
  y = y + 40
  if errPerson then gfx.color(theme.red); gfx.text(errPerson, x + 4, y, 12); end
  y = y + 20
  if #people == 0 then
    emptyState("group", TR("empty_people"), TR("empty_people_sub"), x, y, w, h - y)
    return
  end
  local rowH = 52
  ui.beginScroll("people", x, y, w, h - y - 4, #people * rowH)
  for i, p in ipairs(people) do
    local a = appear[p.id]
    local ry = (i - 1) * rowH
    local ox = a and (1 - ease(a)) * 40 or 0
    if a then gfx.alpha(ease(a)) end
    gfx.rect(ox, ry, w, rowH - 6, 10, theme.hover)
    avatar(p, ox + 26, ry + 23, 16)
    if ui.hit("pname" .. p.id, ox + 48, ry, w - 160, rowH - 6).clicked then renamePerson(p) end
    gfx.color(theme.text)
    gfx.text(p.name, ox + 52, ry + 6, 15, "semibold")
    gfx.color(theme.text2)
    local cnt = 0
    for _, it in ipairs(items) do if isSharer(it, p.id) then cnt = cnt + 1 end end
    gfx.text(TR("person_meta", cnt, fmt(R.owes[p.id] or 0)), ox + 52, ry + 25, 12)
    if ui.iconButton("edit", ox + w - 82, ry + 7, 34, 32, theme.text2, false, "ren" .. p.id) then renamePerson(p) end
    if ui.iconButton("delete", ox + w - 44, ry + 7, 34, 32, theme.red, false, "del" .. p.id) then removePerson(p) end
    if a then gfx.unalpha() end
  end
  ui.endScroll()
end

local function drawItems(x, y, w, h)
  local pw = math.min(150, w * 0.28)
  local fw = w - pw - 120 - 8
  local ni, s1 = ui.textfield("newitem", newItem, x, y, fw, 34, TR("item_ph"))
  local npz, s2 = ui.textfield("newprice", newPrice, x + fw + 8, y, pw, 34, TR("price_ph"), "numeric")
  if ni ~= newItem or npz ~= newPrice then errItem = nil end
  newItem, newPrice = ni, npz
  if ui.button(TR("add"), x + w - 112, y, 112, 34, "primary", "add") or s1 or s2 then addItem() end
  y = y + 40
  if errItem then gfx.color(theme.red); gfx.text(errItem, x + 4, y, 12) end
  y = y + 20
  if #items == 0 then
    emptyState("receipt_long", TR("empty_items"), #people == 0 and TR("empty_items_nop") or TR("empty_items_sub"), x, y, w, h - y)
    return
  end
  local rowH = 60
  ui.beginScroll("items", x, y, w, h - y - 40, #items * rowH)
  for i, it in ipairs(items) do
    local a = appear[it.id]
    local ry = (i - 1) * rowH
    local ox = a and (1 - ease(a)) * 40 or 0
    if a then gfx.alpha(ease(a)) end
    if ui.row("item" .. it.id, ox, ry, w, rowH - 6, false) then openItem(it) end
    gfx.color(theme.text)
    gfx.clip(ox + 12, ry, math.max(1, w - 170), rowH)
    local q = (it.qty or 1) > 1 and ((it.qty or 1) .. " × ") or ""
    gfx.text(q .. it.name, ox + 14, ry + 7, 15, "semibold")
    gfx.unclip()
    gfx.color(theme.text)
    gfx.text(fmt(it.cents * (it.qty or 1)), ox, ry + 7, 15, "semibold", "right", w - 50)
    -- payer and sharers
    local payer = personById(it.payer) or people[1]
    local mx = ox + 14
    if payer then
      gfx.icon("payments", mx + 7, ry + 37, 14, theme.green)
      gfx.color(theme.text2)
      mx = mx + 20 + gfx.text(payer.name, mx + 17, ry + 30, 12)
    end
    gfx.color(theme.text3)
    if not sharesOf(it) then
      gfx.text(TR("shared_all"), mx + 8, ry + 30, 12)
    else
      local ax = mx + 18
      for _, pid in ipairs(it.shared) do
        local p = personById(pid)
        if p and ax < ox + w - 60 then avatar(p, ax, ry + 37, 9); ax = ax + 20 end
      end
    end
    gfx.icon("chevron_right", ox + w - 22, ry + rowH / 2 - 3, 20, theme.text3)
    if a then gfx.unalpha() end
  end
  ui.endScroll()
  gfx.color(theme.text2)
  gfx.text(TR("items_total", #items, fmt(R.subtotal)), x, h - 30, 13, "semibold", "right", w)
end

local function drawPie(cx, cy, r)
  local a0 = -math.pi / 2
  local sum = 0
  for _, p in ipairs(people) do sum = sum + (pieA[p.id] or 0) end
  if sum <= 0.001 then
    gfx.color(theme.hover)
    gfx.circle(cx, cy, r)
  else
    for _, p in ipairs(people) do
      local f = (pieA[p.id] or 0) / sum
      if f > 0.001 then
        local a1 = a0 + f * math.pi * 2
        gfx.color(p.color or COLORS[1])
        gfx.pie(cx, cy, r, a0, a1)
        a0 = a1
      end
    end
  end
  gfx.circle(cx, cy, r * 0.58, theme.bg)
  gfx.color(theme.text2)
  gfx.text(TR("total"), cx - r, cy - 18, 11, "semibold", "center", r * 2)
  gfx.color(theme.text)
  gfx.text(fmt(R.total), cx - r, cy - 3, r > 70 and 15 or 12, "bold", "center", r * 2)
end

local function drawResult(x, y, w, h)
  if #items == 0 or #people == 0 then
    emptyState("calculate", TR("empty_result"), TR("empty_result_sub"), x, y, w, h - y)
    return
  end
  local contentH = 330 + #people * 30 + math.max(1, R.nTransfers) * 40 + 80
  ui.beginScroll("result", x, y, w, h - y, contentH)
  -- tip and service
  local cw = w
  ui.group(0, 0, cw, 116)
  gfx.color(theme.text)
  gfx.text(TR("tip"), 14, 12, 14)
  gfx.color(theme.text2)
  gfx.text("%" .. tipPct, 0, 12, 14, "semibold", "right", 70)
  local nt = ui.slider("tip", tipPct, 0, 25, 84, 10, cw - 98 - 230, 1)
  nt = math.floor(nt + 0.5)
  local qx = cw - 236
  for i, v in ipairs({0, 5, 10, 15, 20}) do
    if ui.button("%" .. v .. "##tip", qx + (i - 1) * 46, 6, 42, 30, tipPct == v and "primary" or "default") then nt = v end
  end
  if nt ~= tipPct then tipPct = nt; save() end
  ui.separator(14, 58, cw - 14)
  gfx.color(theme.text)
  gfx.text(TR("service"), 14, 70, 14)
  gfx.color(theme.text2)
  gfx.text("%" .. taxPct, 0, 70, 14, "semibold", "right", 70)
  local nx = ui.slider("tax", taxPct, 0, 20, 84, 68, cw - 98 - 120, 1)
  nx = math.floor(nx + 0.5)
  if nx ~= taxPct then taxPct = nx; save() end
  local nc = ui.dropdown("cur", CURRENCIES, cur, cw - 104, 64, 90, 30)
  if nc ~= cur then cur = nc; save() end
  -- totals + pie
  local y2 = 130
  local r = math.max(50, math.min(90, (cw - 40) * 0.18))
  drawPie(r + 10, y2 + r + 6, r)
  local tx = r * 2 + 36
  local lines = {{TR("subtotal"), fmt(R.subtotal)}, {TR("tip_service", tipPct + taxPct), fmt(R.extra)}, {TR("total"), fmt(R.total)}}
  for i, l in ipairs(lines) do
    gfx.color(i == 3 and theme.text or theme.text2)
    gfx.text(l[1], tx, y2 + 6 + (i - 1) * 26, i == 3 and 16 or 14, i == 3 and "bold" or "sans")
    gfx.text(l[2], tx, y2 + 6 + (i - 1) * 26, i == 3 and 16 or 14, i == 3 and "bold" or "semibold", "right", cw - tx)
  end
  gfx.color(theme.text3)
  gfx.text(TR("per_head", fmt(#people > 0 and R.total / #people or 0)), tx, y2 + 88, 12)
  y2 = y2 + math.max(r * 2 + 24, 120)
  -- per person table
  gfx.color(theme.text2)
  gfx.text(TR("col_person"), 6, y2, 11, "semibold")
  local c1, c2, c3 = cw * 0.45, cw * 0.66, cw - 6
  gfx.text(TR("col_share"), 0, y2, 11, "semibold", "right", c1)
  gfx.text(TR("col_paid"), 0, y2, 11, "semibold", "right", c2)
  gfx.text(TR("col_balance"), 0, y2, 11, "semibold", "right", c3)
  y2 = y2 + 20
  for _, p in ipairs(people) do
    local o, pd = R.owes[p.id] or 0, R.paid[p.id] or 0
    local b = pd - o
    gfx.circle(14, y2 + 10, 6, p.color)
    gfx.color(theme.text)
    gfx.text(p.name, 28, y2 + 2, 14)
    gfx.text(fmt(o), 0, y2 + 2, 14, "sans", "right", c1)
    gfx.text(fmt(pd), 0, y2 + 2, 14, "sans", "right", c2)
    gfx.color(b > 0 and theme.green or (b < 0 and theme.red or theme.text3))
    gfx.text((b > 0 and "+" or "") .. fmt(b), 0, y2 + 2, 14, "semibold", "right", c3)
    y2 = y2 + 30
  end
  -- transfers
  y2 = y2 + 10
  gfx.color(theme.text2)
  gfx.text(TR("who_pays"), 6, y2, 11, "semibold")
  y2 = y2 + 22
  if R.nTransfers == 0 then
    gfx.icon("check_circle", 20, y2 + 14, 22, theme.green)
    gfx.color(theme.text)
    gfx.text(TR("settled"), 40, y2 + 5, 14)
    y2 = y2 + 40
  end
  for _, t in ipairs(R.transfers) do
    local a, b = personById(t.from), personById(t.to)
    if a and b then
      gfx.rect(0, y2, cw, 34, 10, theme.hover)
      avatar(a, 20, y2 + 17, 11)
      gfx.color(theme.text)
      local nw = gfx.text(a.name, 38, y2 + 8, 14, "semibold")
      gfx.icon("arrow_forward", 52 + nw, y2 + 17, 18, theme.accent)
      avatar(b, 76 + nw, y2 + 17, 11)
      gfx.color(theme.text)
      gfx.text(b.name, 94 + nw, y2 + 8, 14, "semibold")
      gfx.color(theme.accent)
      gfx.text(fmt(t.v), 0, y2 + 8, 15, "bold", "right", cw - 12)
      y2 = y2 + 40
    end
  end
  y2 = y2 + 8
  local bw = (cw - 8) / 2
  if ui.button(TR("copy"), 0, y2, bw, 34, "default", "content_copy") then copySummary() end
  if ui.button(TR("export"), bw + 8, y2, bw, 34, "default", "save") then exportSummary() end
  ui.endScroll()
end

local function drawEditor(w, h)
  local it = editing
  local cw = math.min(560, w - 40)
  local x = (w - cw) / 2
  local y = 14
  if ui.button(TR("done"), x, y, 110, 32, "primary", "arrow_back") then editing = nil; return end
  if ui.button(TR("delete"), x + cw - 120, y, 120, 32, "destructive", "delete") then removeItem(it); return end
  y = y + 50
  gfx.color(theme.text2)
  gfx.text(TR("item_name"), x, y, 12, "semibold")
  local nn = ui.textfield("e_name", edName, x, y + 18, cw, 34, TR("item_ph"))
  if nn ~= edName then
    edName = nn
    local t = trim(nn)
    if t ~= "" and (utf8.len(t) or 0) <= 40 then it.name = t; save() end
  end
  if trim(edName) == "" then gfx.color(theme.red); gfx.text(TR("err_itemname"), x, y + 55, 12) end
  y = y + 74
  local half = (cw - 16) / 2
  gfx.color(theme.text2)
  gfx.text(TR("unit_price"), x, y, 12, "semibold")
  gfx.text(TR("quantity"), x + half + 16, y, 12, "semibold")
  local np = ui.textfield("e_price", edPrice, x, y + 18, half, 34, TR("price_ph"), "numeric")
  if np ~= edPrice then
    edPrice = np
    local c = parseMoney(np)
    if c and c > 0 and c <= 100000000 then it.cents = c; save() end
  end
  local pc = parseMoney(edPrice)
  if not pc or pc <= 0 then gfx.color(theme.red); gfx.text(TR("err_price"), x, y + 55, 12) end
  local qx = x + half + 16
  if ui.button("−##q", qx, y + 18, 40, 34, "default", nil, (it.qty or 1) > 1) then it.qty = math.max(1, (it.qty or 1) - 1); save() end
  gfx.color(theme.text)
  gfx.text(tostring(it.qty or 1), qx + 40, y + 25, 17, "bold", "center", half - 80)
  if ui.button("+##q", qx + half - 40, y + 18, 40, 34, "default", nil, (it.qty or 1) < 99) then it.qty = math.min(99, (it.qty or 1) + 1); save() end
  y = y + 76
  gfx.color(theme.text2)
  gfx.text(TR("paid_by"), x, y, 12, "semibold")
  local names, sel = {}, 1
  for i, p in ipairs(people) do names[i] = p.name; if p.id == it.payer then sel = i end end
  if #names > 0 then
    local ns = ui.dropdown("e_payer", names, sel, x, y + 18, half, 32)
    if ns ~= sel and people[ns] then it.payer = people[ns].id; save() end
  end
  gfx.color(theme.text)
  gfx.text(TR("line_total", fmt((it.cents or 0) * (it.qty or 1))), qx, y + 26, 15, "semibold")
  y = y + 66
  gfx.color(theme.text2)
  gfx.text(TR("shared_by"), x, y, 12, "semibold")
  if ui.button(TR("everyone"), x + cw - 220, y - 8, 106, 28, sharesOf(it) and "default" or "primary") then it.shared = {}; save() end
  local nsel = sharesOf(it) and #it.shared or #people
  gfx.color(theme.text3)
  gfx.text(TR("n_people", nsel), x + cw - 108, y - 2, 12, "sans", "right", 108)
  y = y + 26
  local cols = math.max(1, math.floor(cw / 170))
  local colW = cw / cols
  for i, p in ipairs(people) do
    local cx = x + ((i - 1) % cols) * colW
    local cy = y + ((i - 1) // cols) * 36
    if cy + 30 > h then break end
    local on = isSharer(it, p.id)
    local nv = ui.checkbox(p.name .. "##sh" .. p.id, on, cx + 4, cy + 6)
    if nv ~= on then
      local list = {}
      for _, q in ipairs(people) do
        local want = (q.id == p.id) and nv or isSharer(it, q.id)
        if want then list[#list + 1] = q.id end
      end
      if #list == 0 then flash(TR("err_noone"))
      elseif #list == #people then it.shared = {}
      else it.shared = list end
      save()
    end
  end
end

-- ------------------------------------------------------------------ app
function app.draw(w, h)
  gfx.clear(theme.bg)
  if dirty then compute() end
  if editing then
    drawEditor(w, h)
  else
    local tw = math.min(420, w - 40)
    local nt = ui.segmented("tabs", {TR("tab_people", #people), TR("tab_items", #items), TR("tab_result")}, tab,
                            (w - tw) / 2, 12, tw, 32)
    if nt ~= tab then tab = nt; audio.play("click") end
    local cw = math.min(760, w - 40)
    local x = (w - cw) / 2
    if tab == 1 then drawPeople(x, 58, cw, h)
    elseif tab == 2 then drawItems(x, 58, cw, h)
    else drawResult(x, 58, cw, h) end
  end
  -- toasts
  if undoSnap and undoT > 0 then
    local text = undoText
    local tw = math.min(w - 40, gfx.textWidth(text, 13, "semibold") + 140)
    local tx, ty = (w - tw) / 2, h - 58
    gfx.alpha(math.min(1, undoT * 2))
    gfx.shadow(tx, ty, tw, 40, 20, 12, 4)
    gfx.rect(tx, ty, tw, 40, 20, theme.dark and "#3A3A3C" or "#1C1C1E")
    gfx.color("#FFFFFF")
    gfx.text(text, tx + 16, ty + 12, 13, "semibold")
    if ui.button(TR("undo"), tx + tw - 108, ty + 5, 96, 30, "primary", "undo") then undo() end
    gfx.unalpha()
  elseif msg and msgT > 0 then
    local tw = gfx.textWidth(msg, 13, "semibold") + 32
    gfx.alpha(math.min(1, msgT * 2))
    gfx.rect((w - tw) / 2, h - 52, tw, 32, 16, theme.dark and "#3A3A3C" or "#1C1C1E")
    gfx.color("#FFFFFF")
    gfx.text(msg, (w - tw) / 2, h - 44, 13, "semibold", "center", tw)
    gfx.unalpha()
  end
end

function app.event(e)
  if e.type ~= "keydown" then return end
  if e.ctrl and e.key == "z" then undo(); return end
  if editing then
    if e.key == "escape" then editing = nil end
    return
  end
  if e.ctrl and e.key == "c" and tab == 3 then copySummary()
  elseif e.key == "tab" or (e.ctrl and e.key == "right") then tab = tab % 3 + 1
  elseif e.ctrl and e.key == "left" then tab = (tab + 1) % 3 + 1
  end
end

function app.menu()
  return {
    {title = TR("menu_bill"), items = {
      {label = TR("new_bill"), id = 1},
      {label = TR("reset_all"), id = 2},
      "-",
      {label = TR("undo"), id = 3, shortcut = "Ctrl+Z"},
      "-",
      {label = TR("copy"), id = 4, shortcut = "Ctrl+C"},
      {label = TR("export"), id = 5},
    }},
    {title = TR("menu_view"), items = {
      {label = TR("tab_people", #people), id = 10}, {label = TR("tab_items", #items), id = 11},
      {label = TR("tab_result"), id = 12, shortcut = "Tab"},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then newBill() elseif id == 2 then resetAll() elseif id == 3 then undo()
  elseif id == 4 then copySummary() elseif id == 5 then exportSummary()
  elseif id >= 10 and id <= 12 then editing = nil; tab = id - 9 end
end

function app.close()
  store.save()
  return true
end

return app
