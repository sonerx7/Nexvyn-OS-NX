-- Loan Calculator: monthly payment of an annuity loan (also at 0% interest), total payment and interest, a principal
-- vs interest donut, and the full amortization table by month or by year with CSV export. The rate can be entered
-- as an annual or a monthly percentage (Turkish banks quote monthly rates). Nexvyn OS Lua SDK.
local app = {}

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local isTR = false

-- ------------------------------------------------------------------ helpers
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end

-- reads "250000", "1.250.000", "1,250,000.50" or "3,49"; nil when empty or not a number
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
  local s = fmtNum(v, dec or 2)
  return isTR and ("%" .. s) or (s .. "%")
end

-- TR() with arguments that may contain "%" (percent strings): fill the {n} slots with plain text
local function TRp(key, ...)
  local s, a = TR(key), {...}
  for i = 1, #a do
    local v = tostring(a[i])
    s = s:gsub("{" .. (i - 1) .. "}", function() return v end)
  end
  return s
end

local function ease(cur, target, dt, speed)
  local n = cur + (target - cur) * min(1, dt * (speed or 9))
  if abs(target - n) < math.max(0.005, abs(target) * 1e-6) then n = target end
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
-- Turkish banks quote a monthly rate; elsewhere an annual one is usual (filled in app.load)
local DEFAULTS = {principal = "250000", rate = "3.49", term = "36", rateMode = 2, termMode = 1, view = 1}
local V = {}
local version = 0
local calc, calcVer = nil, -1
local shown = {pay = 0, total = 0, interest = 0, frac = 1}
local donutIn = 0
local toast, toastAt = nil, -10
local undoState = nil
local MONTHS = {}

local function say(text) toast, toastAt = text, sys.time() end

local function set(key, val)
  if V[key] ~= val then
    V[key] = val
    store.set(key, val)
    version = version + 1
  end
end

-- the loan: validates inputs and builds the monthly schedule plus a yearly summary (cached until inputs change)
local function compute()
  if calcVer == version then return calc end
  calcVer = version
  local c = {ok = false}
  calc = c
  local P, R, T = parseNum(V.principal), parseNum(V.rate), parseNum(V.term)
  if V.principal == "" and V.rate == "" and V.term == "" then c.err = "empty"; return c end
  if not P or P <= 0 or P > 1e12 then c.err = "err_principal"; return c end
  local rmax = V.rateMode == 2 and 20 or 200
  if not R or R < 0 or R > rmax then c.err = V.rateMode == 2 and "err_rate_m" or "err_rate_y"; return c end
  local n
  if V.termMode == 2 then
    if not T or T < 1 or T > 50 then c.err = "err_years"; return c end
    n = floor(T * 12 + 0.5)
  else
    if not T or T < 1 or T > 600 then c.err = "err_months"; return c end
    n = floor(T + 0.5)
  end
  local r = V.rateMode == 2 and R / 100 or R / 100 / 12
  local pay
  if r == 0 then pay = P / n else pay = P * r / (1 - (1 + r) ^ (-n)) end
  local rows, years = {}, {}
  local bal, totalInt = P, 0
  for k = 1, n do
    local int = bal * r
    local princ = pay - int
    if k == n then princ = bal end
    local p = princ + int
    bal = max(0, bal - princ)
    totalInt = totalInt + int
    rows[k] = {k, p, princ, int, bal}
    local yi = floor((k - 1) / 12) + 1
    local y = years[yi]
    if not y then y = {yi, 0, 0, 0, 0}; years[yi] = y end
    y[2], y[3], y[4], y[5] = y[2] + p, y[3] + princ, y[4] + int, bal
  end
  c.ok, c.P, c.n, c.r, c.pay, c.rows, c.years = true, P, n, r, pay, rows, years
  c.interest = totalInt
  c.total = P + totalInt
  c.annualNominal = r * 12 * 100
  c.annualEffective = ((1 + r) ^ 12 - 1) * 100
  c.monthly = r * 100
  -- the month of the last payment, counted from next month
  local d = sys.date()
  local mm = (d.month - 1) + n
  c.lastMonth, c.lastYear = mm % 12 + 1, d.year + floor(mm / 12)
  return c
end

-- switching between an annual and a monthly rate keeps the same loan: the typed rate is converted
local function setRateMode(rm)
  if rm == V.rateMode or (rm ~= 1 and rm ~= 2) then return end
  local R = parseNum(V.rate)
  if R then
    local t = fmtNum(rm == 2 and R / 12 or R * 12, rm == 2 and 3 or 2)
    t = t:gsub("0+$", "")
    t = t:gsub("[,.]$", "")
    set("rate", t)
  end
  set("rateMode", rm)
end

local function resetAll()
  undoState = {}
  for k in pairs(DEFAULTS) do undoState[k] = V[k] end
  for k, v in pairs(DEFAULTS) do set(k, v) end
  say(TR("reset_done"))
end

local function undoReset()
  if not undoState then return end
  for k, v in pairs(undoState) do set(k, v) end
  undoState = nil
  say(TR("restored"))
end

local function summaryText()
  local c = compute()
  if not c.ok then return nil end
  local lines = {
    TR("app_name"),
    TR("principal") .. ": " .. fmtNum(c.P),
    TR("rate") .. ": " .. pct(c.monthly, 2) .. " " .. TR("per_month") .. " (" .. pct(c.annualNominal, 2) .. " " .. TR("per_year") .. ")",
    TR("term") .. ": " .. TR("n_months", c.n),
    TR("monthly_payment") .. ": " .. fmtNum(c.pay),
    TR("total_payment") .. ": " .. fmtNum(c.total),
    TR("total_interest") .. ": " .. fmtNum(c.interest),
  }
  return table.concat(lines, "\n") .. "\n"
end

local function copySummary()
  local s = summaryText()
  if not s then say(TR("fix_inputs")); return end
  sys.clipboard(s)
  say(TR("copied"))
  audio.play("pop")
end

local function exportCsv()
  local c = compute()
  if not c.ok then say(TR("fix_inputs")); return end
  local out = {(V.view == 2 and "year" or "month") .. ",payment,principal,interest,balance"}
  for _, r in ipairs(V.view == 2 and c.years or c.rows) do
    out[#out + 1] = string.format("%d,%.2f,%.2f,%.2f,%.2f", r[1], r[2], r[3], r[4], r[5])
  end
  local text = table.concat(out, "\n") .. "\n"
  ui.saveFile(function(path)
    if not path then return end
    if fs.write(path, text) then say(TR("exported")) else say(TR("save_failed")) end
  end, TR("file_name") .. ".csv", TR("export"))
end

-- ------------------------------------------------------------------ lifecycle
function app.load(arg)
  isTR = sys.lang() == "tr"
  if not isTR then DEFAULTS.rate, DEFAULTS.rateMode, DEFAULTS.term = "7.5", 1, "60" end
  for k, d in pairs(DEFAULTS) do
    local v = store.get(k, d)
    if type(v) ~= type(d) then v = d end
    V[k] = v
  end
  V.rateMode = V.rateMode == 1 and 1 or 2
  V.termMode = V.termMode == 2 and 2 or 1
  V.view = V.view == 2 and 2 or 1
  MONTHS = {TR("mon1"), TR("mon2"), TR("mon3"), TR("mon4"), TR("mon5"), TR("mon6"), TR("mon7"), TR("mon8"),
            TR("mon9"), TR("mon10"), TR("mon11"), TR("mon12")}
  local c = compute()
  if c.ok then
    shown.pay, shown.total, shown.interest = c.pay, c.total, c.interest
    shown.frac = c.total > 0 and c.P / c.total or 1
  end
end

function app.update(dt)
  local c = compute()
  if c.ok then
    shown.pay = ease(shown.pay, c.pay, dt)
    shown.total = ease(shown.total, c.total, dt)
    shown.interest = ease(shown.interest, c.interest, dt)
    shown.frac = ease(shown.frac, c.total > 0 and c.P / c.total or 1, dt, 6)
    donutIn = min(1, donutIn + dt * 1.6)
  else
    donutIn = 0
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

local function drawInputs(x, y, w)
  label(TR("principal"), x, y)
  local nt = ui.textfield("principal", V.principal, x, y + 18, w, 34, "250000", "numeric")
  set("principal", nt)

  y = y + 62
  label(TR("rate"), x, y)
  local sw = 128
  nt = ui.textfield("rate", V.rate, x, y + 18, w - sw - 8, 34, "3.49", "numeric")
  set("rate", nt)
  gfx.color(theme.text3)
  gfx.text("%", x + w - sw - 30, y + 27, 14, "semibold")
  local rm = ui.segmented("ratemode", {TR("yearly"), TR("monthly")}, V.rateMode, x + w - sw, y + 20, sw, 30)
  setRateMode(rm)

  y = y + 62
  label(TR("term"), x, y)
  nt = ui.textfield("term", V.term, x, y + 18, w - sw - 8, 34, "36", "numeric")
  set("term", nt)
  local tm = ui.segmented("termmode", {TR("months"), TR("years")}, V.termMode, x + w - sw, y + 20, sw, 30)
  if tm ~= V.termMode and (tm == 1 or tm == 2) then
    local T = parseNum(V.term)
    if T then set("term", tm == 2 and fmtNum(T / 12, (T % 12 == 0) and 0 or 1) or tostring(floor(T * 12 + 0.5))) end
    set("termMode", tm)
  end
  -- what the rate means in the other unit
  local c = compute()
  if c.ok then
    gfx.color(theme.text3)
    local s = V.rateMode == 2 and TRp("rate_info_y", pct(c.annualNominal, 2), pct(c.annualEffective, 2))
      or TRp("rate_info_m", pct(c.monthly, 3))
    gfx.text(s, x, y + 58, 12)
  end
end

local function drawSummary(x, y, w, h)
  card(x, y, w, h)
  local c = compute()
  if not c.ok then
    local cx, cy = x + w / 2, y + h / 2 - 16
    local err = c.err ~= "empty"
    gfx.circle(cx, cy, 30, withAlpha(err and theme.orange or theme.accent, 0.14))
    gfx.icon(err and "error_outline" or "request_quote", cx, cy, 34, err and theme.orange or theme.accent)
    gfx.color(err and theme.text or theme.text2)
    gfx.wrap(err and TR(c.err) or TR("empty_hint"), x + 16, cy + 40, w - 32, 13, "sans", "center")
    return
  end
  local dr = clamp(floor(h * 0.3), 34, 56)
  local tx, tw = x + 18, w - 36 - dr * 2 - 16
  label(TR("monthly_payment"), tx, y + 16)
  local s = fmtNum(shown.pay)
  local size = 30
  while size > 15 and gfx.textWidth(s, size, "bold") > tw do size = size - 1 end
  gfx.color(theme.accent)
  gfx.text(s, tx, y + 36, size, "bold")
  local ly = y + 82
  gfx.color(theme.text2)
  gfx.text(TR("total_payment"), tx, ly, 12)
  gfx.color(theme.text)
  gfx.text(fmtNum(shown.total), tx, ly + 15, 15, "semibold")
  gfx.color(theme.text2)
  gfx.text(TR("total_interest"), tx, ly + 40, 12)
  gfx.color(theme.orange)
  gfx.text(fmtNum(shown.interest), tx, ly + 55, 15, "semibold")
  if h > 170 then
    gfx.color(theme.text3)
    gfx.text(TR("last_payment", (MONTHS[c.lastMonth] or "") .. " " .. c.lastYear), tx, ly + 80, 12)
  end
  -- principal vs interest donut, sweeping in
  local cx, cy = x + w - 18 - dr, y + 16 + dr
  local a0 = -math.pi / 2
  local sweep = math.pi * 2 * donutIn
  local pa = sweep * clamp(shown.frac, 0, 1)
  local th = max(10, dr * 0.32)
  gfx.color(theme.separator)
  gfx.arc(cx, cy, dr - th / 2, 0, math.pi * 2, th)
  if pa > 0.001 then gfx.color(theme.accent); gfx.arc(cx, cy, dr - th / 2, a0, a0 + pa, th) end
  if sweep - pa > 0.001 then gfx.color(theme.orange); gfx.arc(cx, cy, dr - th / 2, a0 + pa, a0 + sweep, th) end
  gfx.color(theme.text)
  gfx.text(pct(clamp(1 - shown.frac, 0, 1) * 100, 0), cx - dr, cy - 9, 14, "bold", "center", dr * 2)
  -- legend
  local lg = cy + dr + 10
  gfx.circle(cx - dr + 5, lg + 7, 5, theme.accent)
  gfx.color(theme.text2)
  gfx.text(TR("legend_principal"), cx - dr + 14, lg, 11)
  gfx.circle(cx - dr + 5, lg + 25, 5, theme.orange)
  gfx.text(TR("legend_interest"), cx - dr + 14, lg + 18, 11)
end

local COLS = {0.12, 0.22, 0.22, 0.22, 0.22}
local function drawTable(x, y, w, h)
  local c = compute()
  local nv = ui.segmented("view", {TR("by_month"), TR("by_year")}, V.view, x, y, 220, 30)
  if nv ~= V.view and (nv == 1 or nv == 2) then set("view", nv) end
  if ui.button(TR("export_short"), x + w - 120, y, 120, 30, "default", "ios_share", c.ok) then exportCsv() end
  if ui.button(TR("copy_short"), x + w - 248, y, 120, 30, "default", "content_copy", c.ok) then copySummary() end
  local hy = y + 40
  gfx.rect(x, hy, w, 26, 6, theme.hover)
  local heads = {V.view == 2 and TR("col_year") or TR("col_month"), TR("col_payment"), TR("col_principal"),
                 TR("col_interest"), TR("col_balance")}
  local cx = x
  for i, hd in ipairs(heads) do
    local cw = w * COLS[i]
    gfx.color(theme.text2)
    if i == 1 then gfx.text(hd, cx + 10, hy + 6, 12, "semibold")
    else gfx.text(hd, cx, hy + 6, 12, "semibold", "right", cw - 10) end
    cx = cx + cw
  end
  local ly = hy + 30
  local lh = h - (ly - y)
  if not c.ok then
    gfx.icon("table_chart", x + w / 2, ly + lh / 2 - 12, 36, theme.text3)
    gfx.color(theme.text3)
    gfx.text(TR("table_empty"), x, ly + lh / 2 + 14, 13, "sans", "center", w)
    return
  end
  local rows = V.view == 2 and c.years or c.rows
  local rowH = 26
  local sy = ui.beginScroll("amort", x, ly, w, lh, #rows * rowH)
  local first = max(1, floor(sy / rowH) + 1)
  local last = min(#rows, floor((sy + lh) / rowH) + 1)
  for k = first, last do
    local r = rows[k]
    local ry = (k - 1) * rowH
    if k % 2 == 0 then gfx.rect(0, ry, w, rowH, 4, theme.hover) end
    -- a faint bar behind the row: share of principal in that payment
    local share = r[2] > 0 and r[3] / r[2] or 0
    gfx.rect(w * COLS[1] - 2, ry + rowH - 4, (w * (1 - COLS[1]) - 8) * share, 2, 1, withAlpha(theme.accent, 0.35))
    local cx2 = 0
    for i = 1, 5 do
      local cw = w * COLS[i]
      if i == 1 then
        gfx.color(theme.text2)
        gfx.text(tostring(r[1]), cx2 + 10, ry + 5, 13, "medium")
      else
        gfx.color(i == 4 and theme.orange or theme.text)
        gfx.text(fmtNum(r[i]), cx2, ry + 5, 13, "sans", "right", cw - 10)
      end
      cx2 = cx2 + cw
    end
  end
  ui.endScroll()
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
  local m = 20
  local lw = max(280, floor((w - 3 * m) * 0.46))
  drawInputs(m, 16, lw)
  local rx = m + lw + m
  local topH = 206
  drawSummary(rx, 16, w - rx - m, topH)
  drawTable(m, 16 + topH + 14, w - 2 * m, h - (16 + topH + 14) - 12)
  drawToast(w, h)
end

-- ------------------------------------------------------------------ input and menus
function app.event(e)
  if e.type ~= "keydown" then return end
  if e.key == "pageup" then set("view", 1)
  elseif e.key == "pagedown" then set("view", 2)
  elseif e.ctrl and e.key == "e" then exportCsv()
  elseif e.ctrl and e.key == "c" then copySummary()
  elseif e.ctrl and e.key == "r" then resetAll()
  elseif e.ctrl and e.key == "z" then undoReset() end
end

function app.menu()
  return {
    {title = TR("app_name"), items = {
      {label = TR("copy"), id = 1, shortcut = "Ctrl+C"},
      {label = TR("export"), id = 2, shortcut = "Ctrl+E"},
      "-",
      {label = TR("reset"), id = 3, shortcut = "Ctrl+R"},
      {label = TR("undo_reset"), id = 4, shortcut = "Ctrl+Z"},
    }},
    {title = TR("view_menu"), items = {
      {label = TR("by_month"), id = 5, shortcut = "PageUp"},
      {label = TR("by_year"), id = 6, shortcut = "PageDown"},
      "-",
      {label = TR("rate_yearly"), id = 7},
      {label = TR("rate_monthly"), id = 8},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then copySummary()
  elseif id == 2 then exportCsv()
  elseif id == 3 then resetAll()
  elseif id == 4 then undoReset()
  elseif id == 5 then set("view", 1)
  elseif id == 6 then set("view", 2)
  elseif id == 7 then setRateMode(1)
  elseif id == 8 then setRateMode(2) end
end

function app.close()
  store.save()
  return true
end

return app
