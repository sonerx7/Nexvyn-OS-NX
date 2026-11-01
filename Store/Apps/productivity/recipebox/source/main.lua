-- Recipe Box for Nexvyn OS: your recipes with servings scaling and unit conversion, a hands-free cooking mode with
-- big text, read-aloud steps and timers found in the text, a shopping list built from recipes, search and tags,
-- text and backup import/export. Made for the kitchen counter: everything works by touch, controller or keyboard.
local K = require("kit")
local app = {}

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local clamp, alpha, mix = K.clamp, K.alpha, K.mix

-- ================================================================== state
local recipes, nextId = {}, 1
local cur = nil
local mode = "view"                 -- view | edit | cook | shop
local narrowPane = "list"
local query, tagFilter, favOnly = "", nil, false
local servings = nil                -- servings shown (scaling)
local metric = true
local shop = {}                     -- {text, done}
local timers = {}                   -- {label, ends, total, done}
local cookStep = 1
local doneSteps = {}
local hist = K.history(80)
local editSnap = nil
local dirty, changedAt = false, 0
local listScroll, bodyScroll = K.scroller(), K.scroller()
local listRect, bodyRect = {0, 0, 0, 0}, {0, 0, 0, 0}
local listSel = 1
local frameDt = 1 / 60
local shopDraft = ""

local function now() return sys.epoch() end
local function markDirty() dirty, changedAt = true, sys.time(); if cur then cur.updated = now() end end
local function byId(id) for _, r in ipairs(recipes) do if r.id == id then return r end end return nil end

-- ================================================================== quantities and units
local UNITS = {g = "mass", kg = "mass", oz = "mass", lb = "mass", ml = "vol", l = "vol", tsp = "vol", tbsp = "vol", cup = "vol",
               ["fl oz"] = "vol", pinch = "other", pc = "other", clove = "other", slice = "other", can = "other"}
local ALIASES = {gram = "g", grams = "g", gr = "g", kilogram = "kg", kilo = "kg", ounce = "oz", ounces = "oz", pound = "lb", pounds = "lb",
                 lbs = "lb", milliliter = "ml", millilitre = "ml", ml = "ml", liter = "l", litre = "l", liters = "l", litres = "l",
                 teaspoon = "tsp", teaspoons = "tsp", tablespoon = "tbsp", tablespoons = "tbsp", tbs = "tbsp", cups = "cup",
                 pinches = "pinch", pcs = "pc", piece = "pc", pieces = "pc", cloves = "clove", slices = "slice", cans = "can",
                 ["su bardağı"] = "cup", ["yemek kaşığı"] = "tbsp", ["tatlı kaşığı"] = "tsp", ["çay kaşığı"] = "tsp",
                 EL = "tbsp", TL = "tsp", ["c. à s."] = "tbsp", ["c. à c."] = "tsp", cda = "tbsp", cdta = "tsp"}
local TO_BASE = {g = 1, kg = 1000, oz = 28.3495, lb = 453.592, ml = 1, l = 1000, tsp = 4.92892, tbsp = 14.7868, cup = 236.588, ["fl oz"] = 29.5735}
local FRACS = {["½"] = 0.5, ["¼"] = 0.25, ["¾"] = 0.75, ["⅓"] = 1 / 3, ["⅔"] = 2 / 3, ["⅛"] = 0.125}

-- "200 g flour", "1 1/2 cups milk", "2 eggs", "½ tsp salt"
local function parseIngredient(s)
  s = K.trim(s)
  local qty, rest = nil, s
  for sym, v in pairs(FRACS) do
    local a, b = rest:find(sym, 1, true)
    if a and a <= 4 then
      local whole = tonumber(rest:sub(1, a - 1)) or 0
      qty, rest = whole + v, K.trim(rest:sub(b + 1))
      break
    end
  end
  if not qty then
    local w, n, d, r2 = rest:match("^(%d+)%s+(%d+)/(%d+)%s*(.*)$")
    if w then qty, rest = tonumber(w) + tonumber(n) / tonumber(d), r2
    else
      local n2, d2, r3 = rest:match("^(%d+)/(%d+)%s*(.*)$")
      if n2 then qty, rest = tonumber(n2) / tonumber(d2), r3
      else
        local num, r4 = rest:match("^(%d+[%.,]?%d*)%s*(.*)$")
        if num then qty, rest = tonumber((num:gsub(",", "."))), r4 end
      end
    end
  end
  local unit = nil
  if qty then
    local lower = K.lower(rest)
    for alias, u in pairs(ALIASES) do
      if lower:sub(1, #alias) == K.lower(alias) and (lower:sub(#alias + 1, #alias + 1) == " " or #lower == #alias) then
        unit, rest = u, K.trim(rest:sub(#alias + 1))
        break
      end
    end
    if not unit then
      local u, r5 = rest:match("^(%S+)%s+(.*)$")
      if u and UNITS[K.lower(u)] then unit, rest = K.lower(u), r5 end
      if u == "fl" and r5 and r5:match("^oz%s") then unit, rest = "fl oz", r5:sub(4) end
    end
  end
  return {qty = qty, unit = unit, name = rest}
end

local function fmtQty(q, frac)
  if not q then return "" end
  if frac then
    local whole = floor(q + 1e-6)
    local part = q - whole
    local best, bd = "", 0.06
    for sym, v in pairs(FRACS) do if abs(part - v) < bd then best, bd = sym, abs(part - v) end end
    if part < 0.06 then return tostring(whole) end
    if best ~= "" then return (whole > 0 and tostring(whole) or "") .. best end
  end
  if q >= 100 then return tostring(floor(q + 0.5)) end
  return K.fmtNum(floor(q * 100 + 0.5) / 100, 2)
end

-- an ingredient for display, scaled and converted
local function showIngredient(line, factor)
  local p = parseIngredient(line)
  if not p.qty then return line end
  local q, u = p.qty * factor, p.unit
  if u and TO_BASE[u] then
    local base = q * TO_BASE[u]
    if metric then
      if UNITS[u] == "mass" then if base >= 1000 then q, u = base / 1000, "kg" else q, u = base, "g" end
      elseif u == "tsp" or u == "tbsp" then -- small spoons stay spoons
      else if base >= 1000 then q, u = base / 1000, "l" else q, u = base, "ml" end end
    else
      if UNITS[u] == "mass" then if base >= 453 then q, u = base / 453.592, "lb" else q, u = base / 28.3495, "oz" end
      elseif u == "ml" or u == "l" then
        if base >= 59 then q, u = base / 236.588, "cup" elseif base >= 14 then q, u = base / 14.7868, "tbsp" else q, u = base / 4.92892, "tsp" end
      end
    end
  end
  local frac = not metric or u == "cup" or u == "tsp" or u == "tbsp" or not u
  return fmtQty(q, frac) .. (u and (" " .. u) or "") .. " " .. p.name
end

-- minutes mentioned in a step ("bake 25 min", "1 hour", "10 dakika", "5 Minuten")
local function stepMinutes(s)
  local l = K.lower(s)
  local h = l:match("(%d+)%s*h[oa]?[uo]?r?s?%f[%A]") or l:match("(%d+)%s*saat") or l:match("(%d+)%s*stunde") or l:match("(%d+)%s*heure")
  local m = l:match("(%d+)%s*min") or l:match("(%d+)%s*dak") or l:match("(%d+)%s*分")
  local total = (tonumber(h) or 0) * 60 + (tonumber(m) or 0)
  return total > 0 and total or nil
end

-- ================================================================== data
local function newRecipe(t)
  local r = {id = nextId, title = t or TR("new_recipe"), tags = {}, servings = 4, prep = 10, cook = 20, ingredients = {}, steps = {},
             notes = "", fav = false, created = now(), updated = now()}
  nextId = nextId + 1
  return r
end
local function samples()
  local out = {}
  local function mk(title, tags, serv, prep, cook, ings, steps, fav)
    local r = newRecipe(title)
    r.tags, r.servings, r.prep, r.cook, r.ingredients, r.steps, r.fav = tags, serv, prep, cook, ings, steps, fav or false
    out[#out + 1] = r
  end
  mk(TR("r1_title"), {TR("tag_breakfast"), TR("tag_quick")}, 4, 10, 15, K.split(TR("r1_ing"), "\n"), K.split(TR("r1_steps"), "\n"), true)
  mk(TR("r2_title"), {TR("tag_soup"), TR("tag_veggie")}, 4, 15, 30, K.split(TR("r2_ing"), "\n"), K.split(TR("r2_steps"), "\n"))
  mk(TR("r3_title"), {TR("tag_drink"), TR("tag_quick")}, 6, 10, 0, K.split(TR("r3_ing"), "\n"), K.split(TR("r3_steps"), "\n"))
  return out
end
local function sanitize(r)
  if type(r) ~= "table" then return nil end
  local function list(t) local o = {}; if type(t) == "table" then for _, x in ipairs(t) do o[#o + 1] = tostring(x) end end; return o end
  local o = {id = K.int(r.id, 0), title = K.str(r.title, TR("new_recipe")), tags = list(r.tags), servings = clamp(K.int(r.servings, 4), 1, 99),
             prep = clamp(K.int(r.prep, 0), 0, 999), cook = clamp(K.int(r.cook, 0), 0, 999), ingredients = list(r.ingredients),
             steps = list(r.steps), notes = K.str(r.notes, ""), fav = r.fav == true, created = K.int(r.created, now()), updated = K.int(r.updated, now())}
  return o
end
local function saveNow()
  store.set("recipes", recipes)
  store.set("nextId", nextId)
  store.set("shop", shop)
  store.set("prefs", {metric = metric, cur = cur and cur.id or 0})
  dirty = false
end
local function loadAll()
  nextId = K.int(store.get("nextId", 1), 1)
  recipes = {}
  local raw = store.get("recipes", nil)
  if type(raw) == "table" and #raw > 0 then
    for _, r in ipairs(raw) do
      local s = sanitize(r)
      if s then
        if s.id <= 0 or byId(s.id) then s.id = nextId end
        nextId = max(nextId, s.id + 1)
        recipes[#recipes + 1] = s
      end
    end
  else
    recipes = samples()
  end
  local sh = store.get("shop", {})
  shop = {}
  if type(sh) == "table" then for _, x in ipairs(sh) do if type(x) == "table" then shop[#shop + 1] = {text = K.str(x.text), done = x.done == true} end end end
  local p = store.get("prefs", nil)
  if type(p) == "table" then metric = p.metric ~= false; cur = byId(K.int(p.cur, 0)) end
  cur = cur or recipes[1]
end

local function filtered()
  local out = {}
  local q = K.lower(K.trim(query))
  for _, r in ipairs(recipes) do
    local ok = (not favOnly or r.fav)
    if ok and tagFilter then
      ok = false
      for _, t in ipairs(r.tags) do if K.lower(t) == tagFilter then ok = true end end
    end
    if ok and q ~= "" then
      ok = K.lower(r.title):find(q, 1, true) ~= nil
      if not ok then for _, i in ipairs(r.ingredients) do if K.lower(i):find(q, 1, true) then ok = true; break end end end
      if not ok then for _, t in ipairs(r.tags) do if K.lower(t):find(q, 1, true) then ok = true; break end end end
    end
    if ok then out[#out + 1] = r end
  end
  table.sort(out, function(a, b)
    if a.fav ~= b.fav then return a.fav end
    return K.lower(a.title) < K.lower(b.title)
  end)
  return out
end
local function allTags()
  local seen, out = {}, {}
  for _, r in ipairs(recipes) do
    for _, t in ipairs(r.tags) do
      local k = K.lower(t)
      if not seen[k] then seen[k] = true; out[#out + 1] = {name = t, key = k} end
    end
  end
  table.sort(out, function(a, b) return a.key < b.key end)
  return out
end

-- ================================================================== actions
local function openRecipe(r)
  if not r then return end
  cur, servings, mode = r, nil, "view"
  doneSteps, cookStep = {}, 1
  bodyScroll:to(0, true)
  narrowPane = "detail"
end
local function snapshot() return cur and K.copy(cur) or nil end
local function beginEdit() if not editSnap then editSnap = snapshot() end end
local function commitSnap() if editSnap then hist:push(editSnap); editSnap = nil end end
local function restoreRecipe(s)
  for i, r in ipairs(recipes) do if r.id == s.id then recipes[i] = s; cur = s end end
  markDirty()
end
local function undo()
  commitSnap()
  if not cur then return end
  local s = hist:undo(snapshot())
  if s then restoreRecipe(s); K.toast(TR("undone"), "undo") else K.toast(TR("nothing_undo"), "undo") end
end
local function redo()
  if not cur then return end
  local s = hist:redo(snapshot())
  if s then restoreRecipe(s); K.toast(TR("redone"), "redo") else K.toast(TR("nothing_redo"), "redo") end
end

local function addRecipe()
  local r = newRecipe()
  r.ingredients, r.steps = {""}, {""}
  table.insert(recipes, 1, r)
  openRecipe(r)
  mode = "edit"
  hist:clear()
  markDirty()
  K.focus("title")
end
local function deleteRecipe()
  if not cur then return end
  local r = cur
  ui.alert(TR("delete_title"), TR("delete_msg", r.title), {TR("delete"), TR("cancel")}, function(b)
    if b ~= 1 then return end
    for i, x in ipairs(recipes) do if x == r then table.remove(recipes, i) end end
    cur = filtered()[1] or recipes[1]
    mode, narrowPane = "view", "list"
    hist:clear()
    markDirty()
    audio.play("trash", 0.4)
  end)
end
local function factor() return (servings or cur.servings) / max(1, cur.servings) end
local function addToShop()
  if not cur then return end
  local f = factor()
  local n = 0
  for _, line in ipairs(cur.ingredients) do
    if K.trim(line) ~= "" then shop[#shop + 1] = {text = showIngredient(line, f), done = false}; n = n + 1 end
  end
  markDirty()
  K.toast(TR("added_shop", n), "shopping_cart")
end
local function startTimer(label, minutes)
  timers[#timers + 1] = {label = label, ends = sys.time() + minutes * 60, total = minutes * 60}
  K.toast(TR("timer_started", minutes), "timer")
end
local function speak(text) sys.stopSpeaking(); sys.speak(text, sys.lang()) end

local function recipeText(r)
  local out = {"# " .. r.title, ""}
  out[#out + 1] = TR("meta_line", r.servings, r.prep, r.cook)
  if #r.tags > 0 then out[#out + 1] = "#" .. table.concat(r.tags, " #") end
  out[#out + 1] = ""
  out[#out + 1] = "## " .. TR("ingredients")
  for _, i in ipairs(r.ingredients) do if K.trim(i) ~= "" then out[#out + 1] = "- " .. i end end
  out[#out + 1] = ""
  out[#out + 1] = "## " .. TR("steps")
  local n = 0
  for _, s in ipairs(r.steps) do if K.trim(s) ~= "" then n = n + 1; out[#out + 1] = n .. ". " .. s end end
  if K.trim(r.notes) ~= "" then out[#out + 1] = ""; out[#out + 1] = "## " .. TR("notes"); out[#out + 1] = r.notes end
  return table.concat(out, "\n") .. "\n"
end
local function importText(text, name)
  text = tostring(text or ""):gsub("\r", "")
  local r = newRecipe(text:match("^#%s*([^\n]+)") or name or TR("imported"))
  local section = nil
  for line in (text .. "\n"):gmatch("(.-)\n") do
    local l = K.trim(line)
    local ll = K.lower(l)
    if l:match("^##") or ll:match("^ingredients") or ll:match("^malzemeler") or ll:match("^zutaten") or ll:match("^ingrédients") or ll:match("^ingredientes") then
      if ll:find("ingred", 1, true) or ll:find("malzeme", 1, true) or ll:find("zutat", 1, true) then section = "i"
      elseif ll:find("note", 1, true) or ll:find("not", 1, true) then section = "n"
      else section = "s" end
    elseif l ~= "" and not l:match("^#%s") then
      local item = l:gsub("^[-*•]%s*", ""):gsub("^%d+[.)]%s*", "")
      if section == "i" then r.ingredients[#r.ingredients + 1] = item
      elseif section == "s" then r.steps[#r.steps + 1] = item
      elseif section == "n" then r.notes = (r.notes ~= "" and r.notes .. "\n" or "") .. l
      elseif l:match("^[-*•]") or l:match("^%d") then r.ingredients[#r.ingredients + 1] = item
      else r.steps[#r.steps + 1] = item end
    end
  end
  table.insert(recipes, 1, r)
  openRecipe(r)
  markDirty()
  return r
end
local function importPath(p)
  local t = fs.read(p)
  if not t then K.toast(TR("read_failed"), "error"); return end
  if p:lower():match("%.json$") then
    local d = json.decode(t)
    local n = 0
    if type(d) == "table" and type(d.recipes) == "table" then
      for _, x in ipairs(d.recipes) do
        local s = sanitize(x)
        if s then s.id = nextId; nextId = nextId + 1; recipes[#recipes + 1] = s; n = n + 1 end
      end
    end
    if n > 0 then markDirty(); K.toast(TR("imported_n", n), "file_download") else K.toast(TR("not_backup"), "error") end
  else
    local r = importText(t, K.baseName(p))
    K.toast(TR("imported_one", r.title), "file_download")
  end
end

-- ================================================================== drawing: list
local function drawList(x, y, w, h)
  gfx.rect(x, y, w, h, 0, theme.sidebar)
  local p = 12
  gfx.color(theme.text)
  gfx.text(TR("app_name"), x + p, y + 14, 18, "bold")
  if ui.iconButton("add", x + w - p - 34, y + 9, 34, 34, theme.accent, false, "##new") then addRecipe() end
  if ui.iconButton("shopping_cart", x + w - p - 72, y + 9, 34, 34, mode == "shop" and theme.accent or theme.text2, mode == "shop", "##shop") then
    mode = mode == "shop" and "view" or "shop"; narrowPane = "detail"
  end
  if ui.iconButton(favOnly and "favorite" or "favorite_border", x + w - p - 110, y + 9, 34, 34, favOnly and theme.pink or theme.text2, favOnly, "##fav") then favOnly = not favOnly end
  query = K.field("search", query, x + p, y + 50, w - p * 2, 32, TR("search_ph"), "search")
  local yy = y + 90
  local tags = allTags()
  if #tags > 0 then
    local cx = x + p
    local rows = 1
    local c0, w0 = K.chip("tg_all", TR("all"), cx, yy, 26, tagFilter == nil)
    if c0 then tagFilter = nil end
    cx = cx + w0 + 6
    for i, t in ipairs(tags) do
      local cw = K.chipWidth(t.name)
      if cx + cw > x + w - p then rows = rows + 1; if rows > 2 then break end; cx = x + p; yy = yy + 32 end
      local c, ww = K.chip("tg" .. i, t.name, cx, yy, 26, tagFilter == t.key, K.colorFor(t.key))
      if c then tagFilter = tagFilter == t.key and nil or t.key end
      cx = cx + ww + 6
    end
    yy = yy + 36
  end
  local list = filtered()
  local rh = 64
  local lh = y + h - yy
  listRect = {x, yy, w, lh}
  listScroll:setMax(#list * rh + 8 - lh)
  gfx.clip(x, yy, w, lh)
  if #list == 0 then K.empty("restaurant", TR("no_recipes"), TR("no_recipes_hint"), x, yy, w, lh) end
  for i, r in ipairs(list) do
    local ry = yy + 4 + (i - 1) * rh - listScroll.y
    if ry > yy - rh and ry < yy + lh then
      local hit = ui.hit("rc" .. r.id, x + 6, ry, w - 12, rh - 6)
      local selected = cur == r
      gfx.rect(x + 6, ry, w - 12, rh - 6, 12, selected and alpha(theme.accent, theme.dark and 0.3 or 0.15) or ((hit.hovered or i == listSel) and theme.hover or alpha(theme.text, 0.0)))
      local col = K.colorFor(K.lower(r.tags[1] or r.title))
      gfx.rect(x + 14, ry + 8, 42, 42, 10, alpha(col, 0.2))
      gfx.icon((r.tags[1] and K.lower(r.tags[1]) == K.lower(TR("tag_drink"))) and "local_bar" or "restaurant", x + 35, ry + 29, 22, col)
      gfx.color(theme.text)
      gfx.text(K.ellipsize(r.title, 14, "semibold", w - 100), x + 66, ry + 10, 14, "semibold")
      gfx.color(theme.text3)
      gfx.text(K.ellipsize(TR("card_meta", r.prep + r.cook, #r.ingredients), 12, "sans", w - 100), x + 66, ry + 32, 12)
      if r.fav then gfx.icon("favorite", x + w - 24, ry + 16, 14, theme.pink) end
      if hit.clicked and not listScroll:dragged() then openRecipe(r); listSel = i end
    end
  end
  gfx.unclip()
  listScroll:bar(x + w - 6, yy + 4, lh - 8)
  gfx.color(theme.separator); gfx.line(x + w - 1, y, x + w - 1, y + h, 1)
end

-- ================================================================== drawing: recipe
local function stepperRow(id, label, value, x, y, w, onChange)
  gfx.color(theme.text2)
  gfx.text(label, x, y + 8, 13, "medium")
  local bx = x + w - 120
  if ui.iconButton("remove", bx, y, 34, 32, theme.text2, false, "##m" .. id) then onChange(-1) end
  gfx.color(theme.text)
  gfx.text(value, bx + 34, y + 7, 15, "semibold", "center", 52)
  if ui.iconButton("add", bx + 86, y, 34, 32, theme.text2, false, "##p" .. id) then onChange(1) end
end

local function drawView(x, y, w, h)
  local r = cur
  local p = 20
  local cw = min(w - p * 2, 720)
  local cx = x + floor((w - cw) / 2)
  local oy = y - bodyScroll.y
  local yy = oy + 16
  gfx.color(theme.text)
  yy = yy + gfx.wrap(r.title, cx, yy, cw - 60, 26, "bold") + 6
  if ui.iconButton(r.fav and "favorite" or "favorite_border", cx + cw - 40, oy + 12, 40, 36, r.fav and theme.pink or theme.text2, r.fav, "##rfav") then
    beginEdit(); r.fav = not r.fav; commitSnap(); markDirty()
  end
  -- tags
  local tx = cx
  for i, t in ipairs(r.tags) do
    local c, ww = K.chip("vt" .. i, t, tx, yy, 24, false, K.colorFor(K.lower(t)))
    if c then tagFilter = K.lower(t); narrowPane = "list" end
    tx = tx + ww + 6
  end
  if #r.tags > 0 then yy = yy + 34 end
  -- facts
  local facts = {{"schedule", TR("prep_n", r.prep)}, {"local_fire_department", TR("cook_n", r.cook)}, {"people", TR("serves_n", servings or r.servings)}}
  local fx = cx
  for _, f in ipairs(facts) do
    gfx.icon(f[1], fx + 10, yy + 12, 18, theme.accent)
    gfx.color(theme.text2)
    gfx.text(f[2], fx + 24, yy + 3, 13, "medium")
    fx = fx + gfx.textWidth(f[2], 13, "medium") + 46
  end
  yy = yy + 36
  -- actions
  local bw = 0
  local function act(label, icon, style, fn)
    local ww = gfx.textWidth(label, 13, "medium") + 50
    if cx + bw + ww > cx + cw then yy = yy + 40; bw = 0 end
    if ui.button(label, cx + bw, yy, ww, 34, style, icon) then fn() end
    bw = bw + ww + 8
  end
  act(TR("cook"), "soup_kitchen", "primary", function() mode, cookStep = "cook", 1 end)
  act(TR("edit"), "edit", "default", function() mode = "edit" end)
  act(TR("to_shop"), "add_shopping_cart", "default", addToShop)
  yy = yy + 50
  -- servings and units
  K.heading(TR("ingredients"), cx, yy, cw)
  yy = yy + 22
  local sv = servings or r.servings
  stepperRow("serv", TR("servings"), tostring(sv), cx, yy, min(cw, 300), function(d) servings = clamp(sv + d, 1, 99) end)
  local seg = ui.segmented("units", {TR("metric"), TR("us")}, metric and 1 or 2, cx + min(cw, 300) + 16, yy, min(200, cw - min(cw, 300) - 16), 32)
  if (seg == 1) ~= metric then metric = seg == 1; markDirty() end
  yy = yy + 44
  local f = sv / max(1, r.servings)
  for i, line in ipairs(r.ingredients) do
    if K.trim(line) ~= "" then
      gfx.circle(cx + 8, yy + 10, 3.5, theme.accent)
      gfx.color(theme.text)
      local hh = gfx.wrap(showIngredient(line, f), cx + 22, yy, cw - 22, 15)
      yy = yy + max(24, hh + 6)
    end
  end
  if #r.ingredients == 0 then gfx.color(theme.text3); gfx.text(TR("no_ingredients"), cx, yy, 14, "italic"); yy = yy + 26 end
  yy = yy + 14
  K.heading(TR("steps"), cx, yy, cw)
  yy = yy + 24
  local n = 0
  for i, s in ipairs(r.steps) do
    if K.trim(s) ~= "" then
      n = n + 1
      local th = gfx.measureWrap(s, cw - 50, 15)
      local hit = ui.hit("st" .. i, cx, yy - 4, cw, th + 14)
      local done = doneSteps[i]
      gfx.circle(cx + 14, yy + 10, 13, done and theme.green or alpha(theme.accent, 0.15))
      if done then gfx.icon("check", cx + 14, yy + 10, 16, "#FFFFFF")
      else gfx.color(theme.accent); gfx.text(tostring(n), cx + 1, yy + 1, 13, "bold", "center", 26) end
      gfx.color(done and theme.text3 or theme.text)
      gfx.wrap(s, cx + 40, yy, cw - 50, 15)
      local mins = stepMinutes(s)
      if mins then
        local lw = gfx.measureWrap(s, cw - 50, 15)
        if ui.button(TR("timer_n", mins), cx + 40, yy + lw + 4, 110, 28, "default", "timer") then startTimer(r.title .. " · " .. n, mins) end
        th = th + 34
      end
      if hit.clicked and not bodyScroll:dragged() then doneSteps[i] = not doneSteps[i] end
      yy = yy + th + 16
    end
  end
  if K.trim(r.notes) ~= "" then
    yy = yy + 6
    K.heading(TR("notes"), cx, yy, cw)
    yy = yy + 22
    gfx.color(theme.text2)
    yy = yy + gfx.wrap(r.notes, cx, yy, cw, 14) + 10
  end
  bodyScroll:setMax(yy + bodyScroll.y - y + 40 - h)
end

local function listEditor(id, list, x, y, w, ph, numbered)
  local yy = y
  for i = 1, #list do
    if numbered then gfx.color(theme.text3); gfx.text(tostring(i), x, yy + 8, 13, "mono", "right", 20) end
    local fx = x + (numbered and 28 or 0)
    local nt = K.field(id .. i, list[i], fx, yy, w - (fx - x) - 40, 34, ph)
    if nt ~= list[i] then beginEdit(); list[i] = nt; markDirty() end
    if ui.iconButton("close", x + w - 36, yy + 1, 34, 32, theme.text3, false, "##" .. id .. "x" .. i) then
      commitSnap(); hist:push(snapshot()); table.remove(list, i); markDirty()
      break
    end
    yy = yy + 40
  end
  return yy
end

local function drawEdit(x, y, w, h)
  local r = cur
  local p = 20
  local cw = min(w - p * 2, 720)
  local cx = x + floor((w - cw) / 2)
  local oy = y - bodyScroll.y
  local yy = oy + 14
  gfx.color(theme.text2); gfx.text(TR("title_label"), cx, yy, 12, "medium"); yy = yy + 18
  local nt = K.field("title", r.title, cx, yy, cw, 36, TR("title_ph"))
  if nt ~= r.title then beginEdit(); r.title = nt; markDirty() end
  yy = yy + 46
  gfx.color(theme.text2); gfx.text(TR("tags_label"), cx, yy, 12, "medium"); yy = yy + 18
  local tagStr = table.concat(r.tags, ", ")
  local nts = K.field("tags", tagStr, cx, yy, cw, 34, TR("tags_ph"))
  if nts ~= tagStr then
    beginEdit()
    r.tags = {}
    for t in nts:gmatch("[^,]+") do if K.trim(t) ~= "" then r.tags[#r.tags + 1] = K.trim(t) end end
    markDirty()
  end
  yy = yy + 46
  local half = min(cw, 340)
  stepperRow("es", TR("servings"), tostring(r.servings), cx, yy, half, function(d) commitSnap(); hist:push(snapshot()); r.servings = clamp(r.servings + d, 1, 99); servings = nil; markDirty() end)
  yy = yy + 40
  stepperRow("ep", TR("prep_min"), tostring(r.prep), cx, yy, half, function(d) commitSnap(); hist:push(snapshot()); r.prep = clamp(r.prep + d * 5, 0, 995); markDirty() end)
  yy = yy + 40
  stepperRow("ec", TR("cook_min"), tostring(r.cook), cx, yy, half, function(d) commitSnap(); hist:push(snapshot()); r.cook = clamp(r.cook + d * 5, 0, 995); markDirty() end)
  yy = yy + 50
  K.heading(TR("ingredients"), cx, yy, cw); yy = yy + 22
  gfx.color(theme.text3); gfx.text(TR("ing_hint"), cx, yy, 12); yy = yy + 20
  yy = listEditor("ing", r.ingredients, cx, yy, cw, TR("ing_ph"), false)
  if ui.button(TR("add_ingredient"), cx, yy, 190, 32, "default", "add") then commitSnap(); hist:push(snapshot()); r.ingredients[#r.ingredients + 1] = ""; markDirty(); K.focus("ing" .. #r.ingredients) end
  yy = yy + 48
  K.heading(TR("steps"), cx, yy, cw); yy = yy + 24
  yy = listEditor("stp", r.steps, cx, yy, cw, TR("step_ph"), true)
  if ui.button(TR("add_step"), cx, yy, 190, 32, "default", "add") then commitSnap(); hist:push(snapshot()); r.steps[#r.steps + 1] = ""; markDirty(); K.focus("stp" .. #r.steps) end
  yy = yy + 48
  K.heading(TR("notes"), cx, yy, cw); yy = yy + 22
  local nn = K.field("notes", r.notes, cx, yy, cw, 34, TR("notes_ph"))
  if nn ~= r.notes then beginEdit(); r.notes = nn; markDirty() end
  yy = yy + 50
  if ui.button(TR("done"), cx, yy, 140, 36, "primary", "check") then commitSnap(); mode = "view"; K.blur() end
  if ui.button(TR("delete_recipe"), cx + cw - 180, yy, 180, 36, "destructive", "delete") then deleteRecipe() end
  yy = yy + 60
  bodyScroll:setMax(yy + bodyScroll.y - y - h)
end

local function cookSteps()
  local out = {}
  for _, s in ipairs(cur.steps) do if K.trim(s) ~= "" then out[#out + 1] = s end end
  return out
end
local function drawCook(x, y, w, h)
  local steps = cookSteps()
  gfx.rect(x, y, w, h, 0, theme.dark and "#101012" or "#FFFBF2")
  local p = 24
  if #steps == 0 then K.empty("soup_kitchen", TR("no_steps"), nil, x, y, w, h); return end
  cookStep = clamp(cookStep, 1, #steps)
  gfx.color(theme.text2)
  gfx.text(TR("step_of", cookStep, #steps), x + p, y + 18, 15, "semibold")
  gfx.color(theme.text3)
  gfx.text(cur.title, x + p, y + 18, 14, "medium", "right", w - p * 2 - 50)
  if ui.iconButton("close", x + w - p - 40, y + 10, 40, 36, theme.text2, false, "##cclose") then mode = "view"; sys.stopSpeaking() end
  -- progress
  gfx.rect(x + p, y + 50, w - p * 2, 6, 3, alpha(theme.text, 0.1))
  gfx.rect(x + p, y + 50, (w - p * 2) * cookStep / #steps, 6, 3, theme.accent)
  local s = steps[cookStep]
  local fs = w > 900 and 30 or (w > 600 and 26 or 21)
  local tw = w - p * 4
  local th = gfx.measureWrap(s, tw, fs, "medium")
  while th > h - 230 and fs > 15 do fs = fs - 2; th = gfx.measureWrap(s, tw, fs, "medium") end
  gfx.color(theme.text)
  gfx.wrap(s, x + p * 2, y + 80 + max(0, (h - 230 - th) / 2), tw, fs, "medium", "center")
  -- controls
  local by = y + h - 70
  local bw = min(170, (w - p * 2 - 24) / 4)
  local bx = x + (w - (bw * 4 + 24)) / 2
  if ui.button(TR("prev"), bx, by, bw, 48, "default", "arrow_back") then cookStep = max(1, cookStep - 1) end
  if ui.button(TR("read_aloud"), bx + bw + 8, by, bw, 48, "default", "record_voice_over") then speak(s) end
  local mins = stepMinutes(s)
  if ui.button(mins and TR("timer_n", mins) or TR("timer"), bx + (bw + 8) * 2, by, bw, 48, "default", "timer") then
    if mins then startTimer(cur.title .. " · " .. cookStep, mins)
    else ui.prompt(TR("timer"), TR("timer_msg"), "10", function(t) local m = tonumber(t); if m and m > 0 then startTimer(cur.title, m) end end) end
  end
  if cookStep < #steps then
    if ui.button(TR("next"), bx + (bw + 8) * 3, by, bw, 48, "primary", "arrow_forward") then cookStep = cookStep + 1 end
  else
    if ui.button(TR("finish"), bx + (bw + 8) * 3, by, bw, 48, "primary", "check") then mode = "view"; audio.play("notify", 0.5); K.toast(TR("enjoy"), "restaurant") end
  end
end

local function drawShop(x, y, w, h)
  local p = 20
  local cw = min(w - p * 2, 640)
  local cx = x + floor((w - cw) / 2)
  local oy = y - bodyScroll.y
  local yy = oy + 16
  gfx.color(theme.text)
  gfx.text(TR("shopping_list"), cx, yy, 24, "bold")
  yy = yy + 44
  local bwd = floor((cw - 16) / 3)
  if ui.button(TR("copy_list"), cx, yy, bwd, 32, "default", "content_copy") then
    local out = {}
    for _, it in ipairs(shop) do if not it.done then out[#out + 1] = "• " .. it.text end end
    sys.clipboard(table.concat(out, "\n"))
    K.toast(TR("copied"), "content_copy")
  end
  if ui.button(TR("clear_done"), cx + bwd + 8, yy, bwd, 32, "default", "done_all") then
    local keep = {}
    for _, it in ipairs(shop) do if not it.done then keep[#keep + 1] = it end end
    shop = keep; markDirty()
  end
  if ui.button(TR("clear_all"), cx + (bwd + 8) * 2, yy, bwd, 32, "destructive", "delete_sweep") then shop = {}; markDirty() end
  yy = yy + 44
  local nt, sub = K.field("shopadd", shopDraft, cx, yy, cw - 50, 34, TR("add_item_ph"))
  shopDraft = nt
  local addHit = ui.iconButton("add", cx + cw - 44, yy, 44, 34, theme.accent, false, "##sadd")
  if (sub or addHit) and K.trim(shopDraft) ~= "" then
    shop[#shop + 1] = {text = K.trim(shopDraft), done = false}; shopDraft = ""; markDirty()
  end
  yy = yy + 46
  if #shop == 0 then gfx.color(theme.text3); gfx.wrap(TR("shop_empty"), cx, yy, cw, 14); yy = yy + 40 end
  for i, it in ipairs(shop) do
    local hit = ui.hit("sh" .. i, cx, yy, cw - 44, 40)
    gfx.rect(cx, yy, cw, 40, 10, hit.hovered and theme.hover or alpha(theme.text, 0.04))
    gfx.icon(it.done and "check_box" or "check_box_outline_blank", cx + 20, yy + 20, 20, it.done and theme.green or theme.text3)
    gfx.color(it.done and theme.text3 or theme.text)
    gfx.text(K.ellipsize(it.text, 15, "sans", cw - 90), cx + 40, yy + 10, 15)
    if it.done then gfx.line(cx + 40, yy + 20, cx + 40 + min(cw - 90, gfx.textWidth(it.text, 15)), yy + 20, 1) end
    if hit.clicked and not bodyScroll:dragged() then it.done = not it.done; markDirty() end
    if ui.iconButton("close", cx + cw - 40, yy + 4, 34, 32, theme.text3, false, "##shx" .. i) then table.remove(shop, i); markDirty(); break end
    yy = yy + 44
  end
  bodyScroll:setMax(yy + bodyScroll.y - y + 30 - h)
end

local function drawTimers(x, y, w)
  if #timers == 0 then return 0 end
  local t = sys.time()
  local bx = x + 10
  for i, tm in ipairs(timers) do
    local left = tm.ends - t
    local label = left > 0 and string.format("%d:%02d", floor(left / 60), floor(left % 60)) or TR("timer_done")
    local cw = gfx.textWidth(label, 14, "monobold") + 70
    if bx + cw > x + w then break end
    gfx.rect(bx, y + 6, cw, 32, 16, left > 0 and alpha(theme.orange, 0.18) or theme.red)
    gfx.icon("timer", bx + 18, y + 22, 16, left > 0 and theme.orange or "#FFFFFF")
    gfx.color(left > 0 and theme.text or "#FFFFFF")
    gfx.text(label, bx + 32, y + 13, 14, "monobold")
    if ui.iconButton("close", bx + cw - 30, y + 8, 28, 28, left > 0 and theme.text2 or "#FFFFFF", false, "##tm" .. i) then table.remove(timers, i); break end
    bx = bx + cw + 8
  end
  return 44
end

-- ================================================================== app callbacks
function app.load(arg)
  loadAll()
  if type(arg) == "string" and arg ~= "" then app.open(arg) end
end
function app.open(arg)
  if type(arg) ~= "string" or arg == "" then return end
  local id = arg:match("^recipe:(%d+)$")
  if id then openRecipe(byId(tonumber(id))); return end
  if arg:find(":/", 1, true) then importPath(arg)
  else local r = importText(arg, TR("shared")); K.toast(TR("imported_one", r.title), "note_add") end
end

function app.update(dt)
  frameDt = dt
  listScroll:update(dt)
  bodyScroll:update(dt)
  local t = sys.time()
  for _, tm in ipairs(timers) do
    if not tm.done and t >= tm.ends then
      tm.done = true
      audio.play("alarm", 0.8)
      sys.vibrate(0.6, 400)
      K.toast(TR("timer_finished", tm.label), "alarm")
    end
  end
  if editSnap and not K.editing then commitSnap() end
  if dirty and t - changedAt > 1.2 then saveNow() end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local narrow = w < 720
  local lw = narrow and w or clamp(floor(w * 0.32), 260, 340)
  if not narrow or narrowPane == "list" then drawList(0, 0, lw, h) end
  if not narrow or narrowPane == "detail" then
    local x = narrow and 0 or lw
    local dw = w - x
    local top = 0
    if mode ~= "cook" then
      -- toolbar
      gfx.rect(x, 0, dw, 50, 0, theme.window)
      local bx = x + 10
      if narrow and ui.iconButton("arrow_back", bx, 8, 36, 34, theme.text2, false, "##back") then narrowPane = "list"; mode = mode == "edit" and "view" or mode; K.blur() end
      if narrow then bx = bx + 40 end
      local th = drawTimers(bx, 3, dw - (bx - x) - 170)
      local right = x + dw - 10
      local function rb(icon, id, enabled)
        right = right - 38
        if enabled == false then gfx.icon(icon, right + 18, 25, 20, theme.text3); return false end
        return ui.iconButton(icon, right, 8, 36, 34, theme.text2, false, id)
      end
      if rb("more_horiz", "##more") then
        ui.contextMenu({{label = TR("export_recipe"), id = 1, icon = "ios_share"}, {label = TR("copy_recipe"), id = 2, icon = "content_copy"},
                        {label = TR("import"), id = 3, icon = "file_download"}, {label = TR("backup"), id = 4, icon = "save"}, "-",
                        {label = TR("delete_recipe"), id = 5, icon = "delete"}}, function(id) app.onmenu(100 + id) end)
      end
      if rb("redo", "##redo", hist:canRedo()) then redo() end
      if rb("undo", "##undo", hist:canUndo() or editSnap ~= nil) then undo() end
      if mode == "view" and cur and rb("soup_kitchen", "##cook") then mode, cookStep = "cook", 1 end
      gfx.color(theme.separator); gfx.line(x, 50, x + dw, 50, 1)
      top = 51
    end
    bodyRect = {x, top, dw, h - top}
    gfx.clip(x, top, dw, h - top)
    if mode == "shop" then drawShop(x, top, dw, h - top)
    elseif not cur then K.empty("restaurant", TR("no_recipes"), TR("no_recipes_hint"), x, top, dw, h - top)
    elseif mode == "edit" then drawEdit(x, top, dw, h - top)
    elseif mode == "cook" then drawCook(x, 0, dw, h)
    else drawView(x, top, dw, h - top) end
    gfx.unclip()
    if mode ~= "cook" then bodyScroll:bar(x + dw - 6, top + 4, h - top - 8) end
  end
  K.drawToast(w, h)
  K.frameEnd()
end

function app.event(e)
  if K.press(e) then return end
  if listScroll:event(e, listRect) then return end
  if mode ~= "cook" and bodyScroll:event(e, bodyRect) then return end
  if e.type ~= "keydown" or K.editing then return end
  local k = e.key
  if e.ctrl then
    if k == "n" then addRecipe() elseif k == "z" then if e.shift then redo() else undo() end elseif k == "y" then redo()
    elseif k == "f" then narrowPane = "list"; K.focus("search") elseif k == "e" then if cur then mode = "edit" end
    elseif k == "l" then mode = "shop"; narrowPane = "detail" elseif k == "o" then app.onmenu(103) elseif k == "s" then saveNow(); K.toast(TR("saved"), "save") end
    return
  end
  if mode == "cook" then
    if k == "right" or k == "space" or k == "enter" then local n = #cookSteps(); if cookStep < n then cookStep = cookStep + 1 else mode = "view" end
    elseif k == "left" then cookStep = max(1, cookStep - 1)
    elseif k == "r" then local st = cookSteps()[cookStep]; if st then speak(st) end
    elseif k == "escape" then mode = "view"; sys.stopSpeaking() end
    return
  end
  local list = filtered()
  if k == "down" or k == "up" then
    listSel = clamp(listSel + (k == "down" and 1 or -1), 1, max(1, #list))
    if list[listSel] then openRecipe(list[listSel]); listScroll:reveal((listSel - 1) * 64, listSel * 64, listRect[4]) end
  elseif k == "c" then if cur then mode, cookStep = "cook", 1 end
  elseif k == "e" then if cur then mode = "edit" end
  elseif k == "s" then mode = mode == "shop" and "view" or "shop"
  elseif k == "f" then if cur then cur.fav = not cur.fav; markDirty() end
  elseif k == "u" then metric = not metric; markDirty()
  elseif k == "=" or k == "right" then if cur then servings = clamp((servings or cur.servings) + 1, 1, 99) end
  elseif k == "-" or k == "left" then if cur then servings = clamp((servings or cur.servings) - 1, 1, 99) end
  elseif k == "escape" then if mode ~= "view" then mode = "view" else narrowPane = "list" end
  elseif k == "delete" then deleteRecipe() end
end

function app.menu()
  return {
    {title = TR("m_file"), items = {
      {label = TR("new_recipe"), id = 1, shortcut = "Ctrl+N"},
      {label = TR("import"), id = 103, shortcut = "Ctrl+O"},
      {label = TR("export_recipe"), id = 101},
      {label = TR("backup"), id = 104},
      "-",
      {label = TR("delete_recipe"), id = 105, shortcut = "Del"},
    }},
    {title = TR("m_edit"), items = {
      {label = TR("undo"), id = 10, shortcut = "Ctrl+Z"},
      {label = TR("redo"), id = 11, shortcut = "Ctrl+Y"},
      "-",
      {label = TR("edit"), id = 12, shortcut = "Ctrl+E"},
      {label = TR("copy_recipe"), id = 102},
    }},
    {title = TR("m_kitchen"), items = {
      {label = TR("cook"), id = 20, shortcut = "C"},
      {label = TR("shopping_list"), id = 21, shortcut = "Ctrl+L"},
      {label = TR("to_shop"), id = 22},
      {label = TR("toggle_units"), id = 23, shortcut = "U"},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then addRecipe()
  elseif id == 10 then undo() elseif id == 11 then redo()
  elseif id == 12 then if cur then mode = "edit" end
  elseif id == 20 then if cur then mode, cookStep = "cook", 1 end
  elseif id == 21 then mode = "shop"; narrowPane = "detail"
  elseif id == 22 then addToShop()
  elseif id == 23 then metric = not metric; markDirty()
  elseif id == 101 then
    if not cur then return end
    local r = cur
    ui.saveFile(function(p)
      if not p then return end
      if not p:lower():match("%.md$") and not p:lower():match("%.txt$") then p = p .. ".md" end
      if fs.write(p, recipeText(r)) then K.toast(TR("exported"), "ios_share") else K.toast(TR("write_failed"), "error") end
    end, r.title:gsub("[/\\:%*%?\"<>|]", "-") .. ".md", TR("export_recipe"))
  elseif id == 102 then if cur then sys.clipboard(recipeText(cur)); K.toast(TR("copied"), "content_copy") end
  elseif id == 103 then ui.openFile(function(p) if p then importPath(p) end end, {".md", ".txt", ".json"}, TR("import"))
  elseif id == 104 then
    ui.saveFile(function(p)
      if not p then return end
      if not p:lower():match("%.json$") then p = p .. ".json" end
      if fs.write(p, json.encode({app = "recipebox", version = 1, recipes = recipes}, true)) then K.toast(TR("backup_done", #recipes), "save")
      else K.toast(TR("write_failed"), "error") end
    end, "recipes-" .. K.dayKey(now()) .. ".json", TR("backup"))
  elseif id == 105 then deleteRecipe() end
end

function app.search(q)
  local out = {}
  q = K.lower(K.trim(q))
  if q == "" then return out end
  for _, r in ipairs(recipes) do
    if #out >= 5 then break end
    local hitText = K.lower(r.title):find(q, 1, true)
    if not hitText then for _, i in ipairs(r.ingredients) do if K.lower(i):find(q, 1, true) then hitText = true; break end end end
    if hitText then out[#out + 1] = {title = r.title, subtitle = TR("app_name"), icon = "restaurant", arg = "recipe:" .. r.id} end
  end
  return out
end
function app.suspend() sys.stopSpeaking(); if dirty then saveNow() end end
function app.autosave() if dirty then saveNow() end end
function app.unsaved() return dirty end
function app.close() commitSnap(); saveNow(); store.save(); return true end

return app
