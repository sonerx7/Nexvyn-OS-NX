-- Percentage Calculator: five calculators with live results and the formula behind them — X% of Y, X is what %
-- of Y, % change from A to B, adding/subtracting a % (VAT/KDV, discounts) and finding the original price before a
-- % was added or taken off. Every input is remembered. Nexvyn OS Lua SDK.
local app = {}

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local isTR = false

-- ------------------------------------------------------------------ helpers
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end

-- reads "1234.5", "1234,5", "1.234,56" or "1,234.56"; nil when empty or not a number
local function parseNum(s)
  if type(s) ~= "string" then return nil end
  s = s:gsub("%s", "")
  if s == "" then return nil end
  local lastDot, lastComma = s:match(".*()%."), s:match(".*(),")
  if lastDot and lastComma then
    if lastComma > lastDot then s = s:gsub("%.", ""):gsub(",", ".") else s = s:gsub(",", "") end
  elseif lastComma then
    local _, n = s:gsub(",", "")
    if n > 1 then s = s:gsub(",", "") else s = s:gsub(",", ".") end
  else
    local _, n = s:gsub("%.", "")
    if n > 1 then s = s:gsub("%.", "") end
  end
  local v = tonumber(s)
  if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
  return v
end

-- grouped number with up to `dec` decimals, trailing zeros dropped: 1.234,5 (tr) / 1,234.5 (en)
local function num(v, dec)
  dec = dec or 4
  if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return "—" end
  if abs(v) >= 1e15 then return string.format("%.4g", v) end
  local neg = v < 0 and floor(abs(v) * 10 ^ dec + 0.5) > 0
  local s = string.format("%." .. dec .. "f", abs(v))
  local int, frac = s:match("^(%d+)%.?(%d*)$")
  if not int then return s end
  frac = frac:gsub("0+$", "")
  local g = isTR and "." or ","
  int = int:reverse():gsub("(%d%d%d)", "%1" .. g):reverse()
  if int:sub(1, 1) == g then int = int:sub(2) end
  if frac ~= "" then int = int .. (isTR and "," or ".") .. frac end
  return (neg and "-" or "") .. int
end

local function pct(v, dec)
  local s = num(v, dec or 2)
  return isTR and ("%" .. s) or (s .. "%")
end

-- TR() whose arguments may contain "%": fills the {n} slots with plain text
local function TRp(key, ...)
  local s, a = TR(key), {...}
  for i = 1, #a do
    local v = tostring(a[i])
    s = s:gsub("{" .. (i - 1) .. "}", function() return v end)
  end
  return s
end

local function ease(cur, target, dt, speed)
  local n = cur + (target - cur) * min(1, dt * (speed or 10))
  if abs(target - n) < max(1e-4, abs(target) * 1e-5) then n = target end
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
local CALCS = {
  {icon = "percent", title = "c1_title", desc = "c1_desc"},
  {icon = "pie_chart", title = "c2_title", desc = "c2_desc"},
  {icon = "trending_up", title = "c3_title", desc = "c3_desc"},
  {icon = "sell", title = "c4_title", desc = "c4_desc"},
  {icon = "replay", title = "c5_title", desc = "c5_desc"},
}
local RATES = {1, 10, 18, 20}
local DEFAULTS = {c1x = "15", c1y = "240", c2x = "36", c2y = "240", c3a = "240", c3b = "276",
                  c4p = "1000", c4r = "20", c4m = 1, c5f = "1200", c5r = "20", c5m = 1}
local V = {}
local sel = 1
local paneIn = 1                 -- 0..1 slide-in of the detail pane after switching calculators
local shown, shownSel = 0, 0     -- eased main result
local shownBar = 0               -- eased bar/ring fraction
local toast, toastAt = nil, -10
local undo = nil                 -- inputs before the last "clear"

local function say(text) toast, toastAt = text, sys.time() end

local function set(k, v)
  if V[k] ~= v then V[k] = v; store.set(k, v) end
end

local function selectCalc(i)
  if i >= 1 and i <= #CALCS and i ~= sel then
    sel = i
    store.set("sel", i)
    paneIn = 0
    audio.play("click")
  end
end

-- ------------------------------------------------------------------ the calculators
-- each returns a result table {ok, main (number), mainText, lines = {...}, formula, bar (0..1 or nil), color, icon}
-- or {ok = false, err = key, field = which input is wrong}; empty inputs give {ok = false, empty = true}
local function need(k)
  local s = V[k] or ""
  if s:gsub("%s", "") == "" then return nil, "empty" end
  local v = parseNum(s)
  if not v then return nil, "err_number" end
  if abs(v) > 1e13 then return nil, "err_large" end
  return v
end

local function fail(err, field)
  if err == "empty" then return {ok = false, empty = true} end
  return {ok = false, err = err, field = field}
end

local function calc1()
  local x, e1 = need("c1x"); if not x then return fail(e1, "c1x") end
  local y, e2 = need("c1y"); if not y then return fail(e2, "c1y") end
  local r = x * y / 100
  return {ok = true, main = r, fmt = num,
    lines = {TRp("c1_plus", num(y), pct(x), num(y + r)), TRp("c1_minus", num(y), pct(x), num(y - r))},
    formula = num(y) .. " × " .. num(x) .. " ÷ 100 = " .. num(r),
    bar = clamp(abs(x) / 100, 0, 1)}
end

local function calc2()
  local x, e1 = need("c2x"); if not x then return fail(e1, "c2x") end
  local y, e2 = need("c2y"); if not y then return fail(e2, "c2y") end
  if y == 0 then return fail("err_zero", "c2y") end
  local r = x / y * 100
  return {ok = true, main = r, fmt = pct,
    lines = {TRp("c2_line", num(x), num(y), pct(r))},
    formula = num(x) .. " ÷ " .. num(y) .. " × 100 = " .. pct(r),
    bar = clamp(r / 100, 0, 1)}
end

local function calc3()
  local a, e1 = need("c3a"); if not a then return fail(e1, "c3a") end
  local b, e2 = need("c3b"); if not b then return fail(e2, "c3b") end
  if a == 0 then return fail("err_zero_from", "c3a") end
  local r = (b - a) / abs(a) * 100
  local up = r > 0
  return {ok = true, main = abs(r), fmt = pct,
    caption = r == 0 and TR("no_change") or up and TR("increase") or TR("decrease"),
    color = r == 0 and theme.text2 or up and theme.green or theme.red,
    icon = r == 0 and "trending_flat" or up and "trending_up" or "trending_down",
    lines = {TRp("c3_diff", num(b - a)), TRp("c3_ratio", num(b), pct(b / a * 100), num(a))},
    formula = "(" .. num(b) .. " − " .. num(a) .. ") ÷ " .. num(abs(a)) .. " × 100 = " .. pct(r)}
end

local function calc4()
  local p, e1 = need("c4p"); if not p then return fail(e1, "c4p") end
  local r, e2 = need("c4r"); if not r then return fail(e2, "c4r") end
  if r < 0 or r > 1000 then return fail("err_rate", "c4r") end
  local part = p * r / 100
  local add = V.c4m ~= 2
  local final = add and p + part or p - part
  return {ok = true, main = final, fmt = num,
    caption = add and TRp("c4_with", pct(r)) or TRp("c4_minus", pct(r)),
    lines = {TRp("c4_part", pct(r), num(part)), TRp("c4_net", num(p))},
    formula = num(p) .. (add and " + " or " − ") .. num(p) .. " × " .. pct(r) .. " = " .. num(final),
    bar = final ~= 0 and clamp(abs(p) / max(abs(final), abs(p)), 0, 1) or 0}
end

local function calc5()
  local f, e1 = need("c5f"); if not f then return fail(e1, "c5f") end
  local r, e2 = need("c5r"); if not r then return fail(e2, "c5r") end
  local added = V.c5m ~= 2
  if r < 0 or r > 1000 or (not added and r >= 100) then return fail(added and "err_rate" or "err_discount", "c5r") end
  local k = added and (1 + r / 100) or (1 - r / 100)
  local orig = f / k
  return {ok = true, main = orig, fmt = num,
    caption = TR("original"),
    lines = {TRp(added and "c5_added" or "c5_taken", pct(r), num(abs(f - orig)))},
    formula = num(f) .. " ÷ " .. num(k) .. " = " .. num(orig),
    bar = clamp(added and orig / max(f, 1e-12) or f / max(orig, 1e-12), 0, 1)}
end

local FUNCS = {calc1, calc2, calc3, calc4, calc5}
local function current() return FUNCS[sel]() end

local KEYS = {{"c1x", "c1y"}, {"c2x", "c2y"}, {"c3a", "c3b"}, {"c4p", "c4r", "c4m"}, {"c5f", "c5r", "c5m"}}

local function clearCalc()
  undo = {sel = sel}
  for _, k in ipairs(KEYS[sel]) do
    undo[k] = V[k]
    if type(V[k]) == "string" then set(k, "") end
  end
  say(TR("cleared"))
end

local function undoClear()
  if not undo then return end
  for k, v in pairs(undo) do if k ~= "sel" then set(k, v) end end
  selectCalc(undo.sel or sel)
  undo = nil
  say(TR("restored"))
end

local function copyResult()
  local r = current()
  if not r.ok then say(TR("nothing_copy")); return end
  local lines = {TR(CALCS[sel].title), (r.caption and (r.caption .. ": ") or "") .. r.fmt(r.main), r.formula}
  for _, l in ipairs(r.lines) do lines[#lines + 1] = l end
  sys.clipboard(table.concat(lines, "\n") .. "\n")
  say(TR("copied"))
  audio.play("pop")
end

-- ------------------------------------------------------------------ lifecycle
function app.load(arg)
  isTR = sys.lang() == "tr"
  for k, d in pairs(DEFAULTS) do
    local v = store.get(k, d)
    if type(v) ~= type(d) then v = d end
    V[k] = v
  end
  V.c4m = V.c4m == 2 and 2 or 1
  V.c5m = V.c5m == 2 and 2 or 1
  sel = clamp(floor(tonumber(store.get("sel", 1)) or 1), 1, #CALCS)
  local r = current()
  if r.ok then shown = r.main; shownBar = r.bar or 0 end
  shownSel = sel
end

function app.update(dt)
  paneIn = min(1, paneIn + dt * 5)
  local r = current()
  if r.ok then
    if shownSel ~= sel then shown = 0; shownSel = sel end
    shown = ease(shown, r.main, dt, 9)
    shownBar = ease(shownBar, r.bar or 0, dt, 7)
  end
end

-- ------------------------------------------------------------------ drawing
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

-- a labelled numeric field; the error text appears under the field that is wrong
local function field(key, text, x, y, w, ph, unit, res)
  label(text, x, y)
  local fw = unit and w - 30 or w
  local nt = ui.textfield(key, V[key], x, y + 20, fw, 36, ph, "numeric")
  set(key, nt)
  if unit then
    gfx.color(theme.text2)
    gfx.text(unit, x + fw + 8, y + 29, 15, "semibold")
  end
  if res and not res.ok and res.field == key and res.err then
    gfx.color(theme.red)
    gfx.text(TR(res.err), x, y + 60, 12)
  end
end

local function rateChips(key, x, y, w)
  local cw = min(64, (w - 6 * (#RATES - 1)) / #RATES)
  for i, r in ipairs(RATES) do
    local on = parseNum(V[key]) == r
    if ui.button(pct(r, 0) .. "##" .. key .. i, x + (i - 1) * (cw + 6), y, cw, 30, on and "primary" or "default") then
      set(key, tostring(r))
    end
  end
end

local function drawInputs(x, y, w, res)
  local hw = (w - 16) / 2
  if sel == 1 then
    field("c1x", TR("c1_x"), x, y, hw, "15", "%", res)
    field("c1y", TR("c1_y"), x + hw + 16, y, hw, "240", nil, res)
  elseif sel == 2 then
    field("c2x", TR("c2_x"), x, y, hw, "36", nil, res)
    field("c2y", TR("c2_y"), x + hw + 16, y, hw, "240", nil, res)
  elseif sel == 3 then
    field("c3a", TR("c3_a"), x, y, hw, "240", nil, res)
    field("c3b", TR("c3_b"), x + hw + 16, y, hw, "276", nil, res)
  elseif sel == 4 then
    field("c4p", TR("c4_p"), x, y, hw, "1000", nil, res)
    field("c4r", TR("rate"), x + hw + 16, y, hw, "20", "%", res)
    local m = ui.segmented("c4m", {TR("add_pct"), TR("sub_pct")}, V.c4m, x, y + 80, hw, 30)
    if m == 1 or m == 2 then set("c4m", m) end
    rateChips("c4r", x + hw + 16, y + 80, hw)
  else
    field("c5f", TR("c5_f"), x, y, hw, "1200", nil, res)
    field("c5r", TR("rate"), x + hw + 16, y, hw, "20", "%", res)
    local m = ui.segmented("c5m", {TR("was_added"), TR("was_taken")}, V.c5m, x, y + 80, hw, 30)
    if m == 1 or m == 2 then set("c5m", m) end
    rateChips("c5r", x + hw + 16, y + 80, hw)
  end
end

local function drawResult(x, y, w, h, res)
  card(x, y, w, h)
  local px, pw = x + 20, w - 40
  if not res.ok then
    local cx, cy = x + w / 2, y + h / 2 - 14
    local err = not res.empty
    gfx.circle(cx, cy, 32, withAlpha(err and theme.orange or theme.accent, 0.13))
    gfx.icon(err and "error_outline" or CALCS[sel].icon, cx, cy, 34, err and theme.orange or theme.accent)
    gfx.color(theme.text2)
    gfx.wrap(err and TR("fix_hint") or TR("empty_hint"), px, cy + 42, pw, 13, "sans", "center")
    return
  end
  gfx.color(theme.text2)
  gfx.text(res.caption or TR("result"), px, y + 16, 13, "semibold")
  if ui.iconButton("content_copy", x + w - 46, y + 10, 34, 32, theme.accent, false, "copy") then copyResult() end
  local s = res.fmt(shown)
  local size = 38
  local avail = pw - (res.icon and 40 or 0) - 40
  while size > 16 and gfx.textWidth(s, size, "bold") > avail do size = size - 2 end
  if res.icon then gfx.icon(res.icon, px + 16, y + 40 + size / 2, 30, res.color) end
  gfx.color(res.color or theme.accent)
  gfx.text(s, px + (res.icon and 40 or 0), y + 38, size, "bold")
  local ly = y + 46 + size
  -- proportion bar (share of the whole, net vs gross …)
  if res.bar then
    gfx.rect(px, ly, pw, 10, 5, theme.hover)
    gfx.rect(px, ly, max(10, pw * clamp(shownBar, 0, 1)), 10, 5, res.color or theme.accent)
    ly = ly + 22
  end
  gfx.color(theme.text)
  for _, l in ipairs(res.lines) do
    if ly + 18 > y + h - 40 then break end
    gfx.text(l, px, ly, 14)
    ly = ly + 22
  end
  -- formula
  gfx.rect(px, y + h - 40, pw, 28, 8, theme.hover)
  gfx.color(theme.text2)
  local f = res.formula
  local fs = 13
  while fs > 10 and gfx.textWidth(f, fs, "mono") > pw - 20 do fs = fs - 1 end
  gfx.text(f, px + 10, y + h - 40 + (28 - fs * 1.25) / 2, fs, "mono")
end

local function drawSidebar(w, h)
  local sw = 210
  gfx.rect(0, 0, sw, h, 0, theme.sidebar)
  gfx.color(theme.separator)
  gfx.line(sw, 0, sw, h, 1)
  gfx.color(theme.text3)
  gfx.text(TR("calculators"), 18, 16, 12, "semibold")
  for i, c in ipairs(CALCS) do
    local ry = 40 + (i - 1) * 50
    if ui.row("row" .. i, 8, ry, sw - 16, 46, i == sel) then selectCalc(i) end
    gfx.icon(c.icon, 30, ry + 23, 20, i == sel and theme.accent or theme.text2)
    gfx.color(theme.text)
    gfx.wrap(TR(c.title), 50, ry + (gfx.measureWrap(TR(c.title), sw - 72, 13) > 20 and 6 or 14), sw - 72, 13,
      i == sel and "semibold" or "sans")
  end
  return sw
end

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
  local sw = drawSidebar(w, h)
  local x, pw = sw + 20, w - sw - 40
  local e = 1 - (1 - paneIn) ^ 3
  gfx.alpha(0.3 + 0.7 * e)
  gfx.push((1 - e) * 24, 0)
  local c = CALCS[sel]
  gfx.color(theme.text)
  gfx.text(TR(c.title), x, 16, 18, "bold")
  gfx.color(theme.text2)
  gfx.wrap(TR(c.desc), x, 42, pw, 13)
  local res = current()
  local iy = 82
  drawInputs(x, iy, pw, res)
  local ry = iy + ((sel >= 4) and 128 or 84)
  drawResult(x, ry, pw, h - ry - 20, res)
  gfx.pop()
  gfx.unalpha()
  drawToast(w, h)
end

-- ------------------------------------------------------------------ input and menus
function app.event(e)
  if e.type ~= "keydown" then return end
  if e.ctrl and e.key >= "1" and e.key <= "5" and #e.key == 1 then selectCalc(tonumber(e.key))
  elseif e.key == "up" or e.key == "pageup" then selectCalc(sel == 1 and #CALCS or sel - 1)
  elseif e.key == "down" or e.key == "pagedown" then selectCalc(sel % #CALCS + 1)
  elseif e.ctrl and e.key == "c" then copyResult()
  elseif e.ctrl and e.key == "r" then clearCalc()
  elseif e.ctrl and e.key == "z" then undoClear() end
end

function app.menu()
  local items = {}
  for i, c in ipairs(CALCS) do items[i] = {label = TR(c.title), id = i, shortcut = "Ctrl+" .. i} end
  return {
    {title = TR("app_name"), items = {
      {label = TR("copy"), id = 10, shortcut = "Ctrl+C"},
      "-",
      {label = TR("clear"), id = 11, shortcut = "Ctrl+R"},
      {label = TR("undo_clear"), id = 12, shortcut = "Ctrl+Z"},
    }},
    {title = TR("calculators"), items = items},
  }
end

function app.onmenu(id)
  if id >= 1 and id <= #CALCS then selectCalc(id)
  elseif id == 10 then copyResult()
  elseif id == 11 then clearCalc()
  elseif id == 12 then undoClear() end
end

function app.close()
  store.save()
  return true
end

return app
