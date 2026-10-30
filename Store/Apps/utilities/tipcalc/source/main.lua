-- Tip Calculator: bill + tip % (quick chips, slider or custom), split between people, optional rounding up,
-- a currency symbol, and copy / save of the result. Every setting is remembered. Nexvyn OS Lua SDK.
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

-- grouped number in the UI language: 1.234,56 (tr) or 1,234.56 (en)
local function fmtNum(v, dec)
  dec = dec or 2
  if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return "—" end
  local neg = v < 0 and floor(abs(v) * 10 ^ dec + 0.5) > 0
  local s = string.format("%." .. dec .. "f", abs(v))
  local int, frac = s:match("^(%d+)%.?(%d*)$")
  if not int then return s end
  local grp = isTR and "." or ","
  int = int:reverse():gsub("(%d%d%d)", "%1" .. grp):reverse()
  if int:sub(1, 1) == grp then int = int:sub(2) end
  if dec > 0 and frac ~= "" then int = int .. (isTR and "," or ".") .. frac end
  return (neg and "-" or "") .. int
end

local function pct(v, dec)
  local s = fmtNum(v, dec or 0)
  return isTR and ("%" .. s) or (s .. "%")
end

local function ease(cur, target, dt, speed)
  local n = cur + (target - cur) * min(1, dt * (speed or 10))
  if abs(target - n) < 0.004 then n = target end
  return n
end

-- ------------------------------------------------------------------ state
local CURRENCIES = {"₺", "$", "€", "£"}
local CHIPS = {5, 10, 15, 18, 20, 25}
local MAX_BILL = 1e9

local billText = ""
local tip = 15        -- percent
local split = 1       -- people
local roundMode = 1   -- 1 none, 2 round total up, 3 round per person up
local cur = 1         -- index into CURRENCIES
local shown = {per = 0, tip = 0, total = 0, tipPer = 0, frac = 0}   -- eased values for the card
local cardIn = 0      -- 0..1 fade/slide of the result lines
local toast, toastAt = nil, -10
local undoState = nil -- settings before the last reset

local function money(v)
  local sym = CURRENCIES[cur] or "₺"
  if sym == "₺" then return fmtNum(v, 2) .. " ₺" end
  return sym .. fmtNum(v, 2)
end

local function say(text) toast, toastAt = text, sys.time() end

local function setTip(v)
  v = clamp(floor(v * 10 + 0.5) / 10, 0, 100)
  if v ~= tip then tip = v; store.set("tip", tip) end
end

local function setSplit(n)
  n = clamp(floor(n), 1, 50)
  if n ~= split then split = n; store.set("split", split); audio.play("click") end
end

local function setRound(r)
  if r >= 1 and r <= 3 and r ~= roundMode then roundMode = r; store.set("round", roundMode) end
end

local function setCurrency(i)
  if CURRENCIES[i] and i ~= cur then cur = i; store.set("cur", cur) end
end

local function setBill(t)
  if t ~= billText then billText = t; store.set("bill", billText) end
end

-- reset keeps a snapshot so it can be undone from the menu or with Ctrl+Z
local function resetAll()
  undoState = {bill = billText, tip = tip, split = split, round = roundMode}
  setBill(""); setTip(15); setSplit(1); setRound(1)
  say(TR("reset_done"))
end

local function undoReset()
  if not undoState then return end
  local u = undoState
  undoState = nil
  setBill(u.bill); setTip(u.tip); setSplit(u.split); setRound(u.round)
  say(TR("restored"))
end

-- bill validation: returns amount or nil, plus an error key when the text is not a usable amount
local function bill()
  if billText:gsub("%s", "") == "" then return nil, nil end
  local v = parseNum(billText)
  if not v then return nil, "err_number" end
  if v < 0 then return nil, "err_negative" end
  if v > MAX_BILL then return nil, "err_large" end
  return v, nil
end

-- the whole calculation: tip, total and per-person after the chosen rounding
local function compute()
  local b = bill()
  if not b then return nil end
  local n = max(1, split)
  local t = b * tip / 100
  local total = b + t
  local per = total / n
  if roundMode == 2 then
    total = math.ceil(total - 1e-9)
    per = total / n
  elseif roundMode == 3 then
    per = math.ceil(per - 1e-9)
    total = per * n
  end
  t = total - b
  return {bill = b, tip = t, total = total, per = per, tipPer = t / n, eff = b > 0 and t / b * 100 or 0}
end

-- plain-text summary for the clipboard and the saved file
local function summary()
  local r = compute()
  if not r then return nil end
  local lines = {
    TR("app_name"),
    TR("bill_line") .. ": " .. money(r.bill),
    TR("tip_line") .. " (" .. pct(tip, tip % 1 == 0 and 0 or 1) .. "): " .. money(r.tip),
    TR("total") .. ": " .. money(r.total),
  }
  if split > 1 then
    lines[#lines + 1] = TR("split") .. ": " .. TR("people", split)
    lines[#lines + 1] = TR("per_person") .. ": " .. money(r.per)
  end
  if roundMode ~= 1 then lines[#lines + 1] = TR("effective_tip") .. ": " .. pct(r.eff, 1) end
  return table.concat(lines, "\n") .. "\n"
end

local function copyResult()
  local s = summary()
  if not s then say(TR("enter_bill_short")); return end
  sys.clipboard(s)
  say(TR("copied"))
  audio.play("pop")
end

local function saveResult()
  local s = summary()
  if not s then say(TR("enter_bill_short")); return end
  ui.saveFile(function(path)
    if not path then return end
    if fs.write(path, s) then say(TR("saved")) else say(TR("save_failed")) end
  end, TR("file_name") .. ".txt", TR("save_title"))
end

-- ------------------------------------------------------------------ lifecycle
function app.load(arg)
  isTR = sys.lang() == "tr"
  billText = tostring(store.get("bill", ""))
  tip = clamp(tonumber(store.get("tip", 15)) or 15, 0, 100)
  split = clamp(floor(tonumber(store.get("split", 1)) or 1), 1, 50)
  roundMode = clamp(floor(tonumber(store.get("round", 1)) or 1), 1, 3)
  cur = clamp(floor(tonumber(store.get("cur", isTR and 1 or 2)) or 1), 1, #CURRENCIES)
  local r = compute()
  if r then
    shown.per, shown.tip, shown.total, shown.tipPer = r.per, r.tip, r.total, r.tipPer
    shown.frac = r.total > 0 and r.bill / r.total or 1
    cardIn = 1
  end
end

function app.update(dt)
  local r = compute()
  if r then
    shown.per = ease(shown.per, r.per, dt)
    shown.tip = ease(shown.tip, r.tip, dt)
    shown.total = ease(shown.total, r.total, dt)
    shown.tipPer = ease(shown.tipPer, r.tipPer, dt)
    shown.frac = ease(shown.frac, r.total > 0 and r.bill / r.total or 1, dt, 8)
  end
  cardIn = ease(cardIn, r and 1 or 0, dt, 8)
end

-- ------------------------------------------------------------------ drawing
local function label(text, x, y)
  gfx.color(theme.text2)
  gfx.text(text, x, y, 13, "semibold")
end

local function drawInputs(x, y, lw)
  -- bill amount with the currency symbol in a small badge
  label(TR("bill"), x, y)
  local fy = y + 20
  gfx.rect(x, fy, 40, 36, 8, theme.field)
  gfx.color(theme.separator)
  gfx.rectLine(x, fy, 40, 36, 8, 1)
  gfx.color(theme.accent)
  gfx.text(CURRENCIES[cur] or "", x, fy + 8, 17, "bold", "center", 40)
  local nt = ui.textfield("bill", billText, x + 46, fy, lw - 46, 36, "0", "numeric")
  setBill(nt)
  local _, err = bill()
  if err then
    gfx.color(theme.red)
    gfx.text(TR(err), x + 46, fy + 40, 12)
  end

  -- tip percent: chips, slider and a custom value
  y = fy + 64
  label(TR("tip"), x, y)
  gfx.color(theme.accent)
  gfx.text(pct(tip, tip % 1 == 0 and 0 or 1), x, y - 2, 16, "bold", "right", lw)
  local cy = y + 22
  local gap = 6
  local cw = (lw - gap * (#CHIPS - 1)) / #CHIPS
  for i, v in ipairs(CHIPS) do
    local sel = abs(tip - v) < 0.05
    if ui.button(pct(v) .. "##chip" .. i, x + (i - 1) * (cw + gap), cy, cw, 32, sel and "primary" or "default") then
      setTip(v); audio.play("click")
    end
  end
  local sy = cy + 42
  local bw = 92
  local sv = min(tip, 50)
  local nv = ui.slider("tipslider", sv, 0, 50, x, sy + 2, lw - bw - 10, 1)
  if type(nv) == "number" and nv ~= sv then setTip(nv) end
  if ui.button(TR("custom"), x + lw - bw, sy, bw, 32, "default", "edit") then
    ui.prompt(TR("custom_title"), TR("custom_msg"), fmtNum(tip, tip % 1 == 0 and 0 or 1), function(s)
      local v = parseNum(s or "")
      if v and v >= 0 and v <= 100 then setTip(v) else say(TR("err_tip")) end
    end)
  end

  -- split between people
  y = sy + 46
  label(TR("split"), x, y)
  local ry = y + 20
  if ui.iconButton("remove", x, ry, 36, 36, nil, false, "splitminus") then setSplit(split - 1) end
  gfx.color(theme.text)
  gfx.text(tostring(split), x + 40, ry + 6, 20, "bold", "center", 48)
  if ui.iconButton("add", x + 92, ry, 36, 36, nil, false, "splitplus") then setSplit(split + 1) end
  gfx.icon(split > 1 and "group" or "person", x + 150, ry + 18, 20, theme.text2)
  gfx.color(theme.text2)
  gfx.text(split == 1 and TR("one_person") or TR("people", split), x + 166, ry + 9, 14)

  -- rounding
  y = ry + 48
  label(TR("rounding"), x, y)
  setRound(ui.segmented("round", {TR("round_none"), TR("round_total"), TR("round_person")}, roundMode, x, y + 20, lw, 32))
end

-- one "label ...... value" line inside the result card
local function cardLine(text, value, x, y, w)
  gfx.color(255, 255, 255, 200)
  gfx.text(text, x, y, 13)
  gfx.color("#FFFFFF")
  gfx.text(value, x, y - 1, 15, "semibold", "right", w)
end

local function drawResult(x, y, w, h)
  gfx.shadow(x, y, w, h, 16, 14, 5)
  gfx.gradient(x, y, w, h, "#34C759", "#1E8E3E", false, 16)
  local r = compute()
  local px, pw = x + 18, w - 36
  gfx.color(255, 255, 255, 210)
  gfx.text(split > 1 and TR("per_person") or TR("total"), px, y + 18, 13, "semibold")
  -- the big number shrinks until it fits the card
  local big = r and money(shown.per) or "—"
  local size = 36
  while size > 16 and gfx.textWidth(big, size, "bold") > pw do size = size - 2 end
  gfx.color("#FFFFFF")
  gfx.text(big, px, y + 38, size, "bold")

  -- empty state: a receipt illustration that fades out as soon as there is a bill
  if cardIn < 0.99 then
    gfx.alpha(1 - cardIn)
    local cx, cy = x + w / 2, y + h / 2 + 4
    gfx.circle(cx, cy, 38, {255, 255, 255, 40})
    gfx.icon("receipt_long", cx, cy, 42, {255, 255, 255, 220})
    gfx.color(255, 255, 255, 220)
    gfx.wrap(TR("enter_bill"), px, cy + 50, pw, 13, "sans", "center")
    gfx.unalpha()
  end
  if not r or cardIn < 0.01 then return end

  gfx.alpha(cardIn)
  gfx.push(0, (1 - cardIn) * 14)
  -- bill vs tip proportion bar
  local by = y + 90
  gfx.rect(px, by, pw, 8, 4, {255, 255, 255, 70})
  local bwid = max(8, pw * clamp(shown.frac, 0, 1))
  gfx.rect(px, by, bwid, 8, 4, {255, 255, 255, 235})
  gfx.color(255, 255, 255, 190)
  gfx.text(TR("bill_line"), px, by + 12, 11)
  gfx.text(TR("tip_line"), px, by + 12, 11, "sans", "right", pw)

  local ly = by + 40
  cardLine(TR("tip_line"), money(shown.tip), px, ly, pw)
  cardLine(TR("total"), money(shown.total), px, ly + 28, pw)
  local yy = ly + 56
  if split > 1 then cardLine(TR("tip_per_person"), money(shown.tipPer), px, yy, pw); yy = yy + 28 end
  if roundMode ~= 1 then cardLine(TR("effective_tip"), pct(r.eff, 1), px, yy, pw) end
  gfx.pop()
  gfx.color(255, 255, 255, 170)
  local note = roundMode == 2 and TR("note_total") or roundMode == 3 and TR("note_person") or TR("note_none")
  gfx.wrap(note, px, y + h - 46, pw, 12)
  gfx.unalpha()
end

local function drawToast(w, h)
  if not toast then return end
  local age = sys.time() - toastAt
  if age > 2.2 then toast = nil; return end
  local a = min(1, age * 6, (2.2 - age) * 3)
  local tw = gfx.textWidth(toast, 13) + 32
  local tx, ty = (w - tw) / 2, h - 64 - (1 - min(1, age * 6)) * 10
  gfx.alpha(a)
  gfx.shadow(tx, ty, tw, 32, 16, 10, 3)
  gfx.rect(tx, ty, tw, 32, 16, theme.dark and "#3A3A3C" or "#1C1C1E")
  gfx.color("#FFFFFF")
  gfx.text(toast, tx, ty + 8, 13, "medium", "center", tw)
  gfx.unalpha()
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local m = 20
  local lw = floor((w - 3 * m) * 0.52)
  drawInputs(m, m, lw)
  local rx = m + lw + m
  local rw = w - rx - m
  drawResult(rx, m, rw, h - 2 * m - 44)
  -- bottom bar under the card: currency, copy, save, reset
  local by = h - m - 32
  local nc = ui.dropdown("currency", CURRENCIES, cur, rx, by, 70, 32)
  if nc ~= cur then setCurrency(nc) end
  local has = compute() ~= nil
  if ui.iconButton("content_copy", w - m - 116, by, 36, 32, has and theme.accent or theme.text3, false, "copy") then copyResult() end
  if ui.iconButton("save", w - m - 76, by, 36, 32, has and theme.accent or theme.text3, false, "save") then saveResult() end
  if ui.iconButton("restart_alt", w - m - 36, by, 36, 32, nil, false, "reset") then resetAll() end
  drawToast(w, h)
end

-- ------------------------------------------------------------------ input and menus
function app.event(e)
  if e.type ~= "keydown" then return end
  if e.key == "up" then setSplit(split + 1)
  elseif e.key == "down" then setSplit(split - 1)
  elseif e.key == "pageup" then setTip(floor(tip) + 1)
  elseif e.key == "pagedown" then setTip(math.ceil(tip) - 1)
  elseif e.ctrl and e.key == "r" then resetAll()
  elseif e.ctrl and e.key == "z" then undoReset()
  elseif e.ctrl and e.key == "c" then copyResult()
  elseif e.ctrl and e.key == "s" then saveResult() end
end

function app.menu()
  local cm = {}
  for i, c in ipairs(CURRENCIES) do cm[i] = {label = c, id = 10 + i} end
  return {
    {title = TR("app_name"), items = {
      {label = TR("copy"), id = 6, shortcut = "Ctrl+C"},
      {label = TR("save_as"), id = 7, shortcut = "Ctrl+S"},
      "-",
      {label = TR("add_person"), id = 1, shortcut = "Up"},
      {label = TR("remove_person"), id = 2, shortcut = "Down"},
      {label = TR("tip_up"), id = 3, shortcut = "PageUp"},
      {label = TR("tip_down"), id = 4, shortcut = "PageDown"},
      "-",
      {label = TR("reset"), id = 5, shortcut = "Ctrl+R"},
      {label = TR("undo_reset"), id = 8, shortcut = "Ctrl+Z"},
    }},
    {title = TR("currency"), items = cm},
  }
end

function app.onmenu(id)
  if id == 1 then setSplit(split + 1)
  elseif id == 2 then setSplit(split - 1)
  elseif id == 3 then setTip(floor(tip) + 1)
  elseif id == 4 then setTip(math.ceil(tip) - 1)
  elseif id == 5 then resetAll()
  elseif id == 6 then copyResult()
  elseif id == 7 then saveResult()
  elseif id == 8 then undoReset()
  elseif id > 10 and id <= 10 + #CURRENCIES then setCurrency(id - 10) end
end

function app.close()
  store.save()
  return true
end

return app
