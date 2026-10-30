-- Finance Calculator for Nexvyn OS: loan/mortgage with amortization, compound interest with monthly contributions
-- and a growth chart, percentage tools and a VAT (KDV) calculator. Currency-free math.
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
local function approach(cur, target, speed, dt) return cur + (target - cur) * (1 - math.exp(-speed * dt)) end

local editing, pressAt, fieldHit = false, nil, false
local function field(id, text, x, y, w, h, ph, flags, ox, oy)
  local nt, sub = ui.textfield(id, text, x, y, w, h, ph, flags)
  if pressAt then
    local px, py = pressAt[1], pressAt[2]
    local ax, ay = x + (ox or 0), y + (oy or 0)
    if px >= ax and px <= ax + w and py >= ay and py <= ay + h then fieldHit = true end
  end
  return nt, sub
end

-- ------------------------------------------------------------------ numbers
local isTR = false
local DEC, GRP = ".", ","

-- accepts "1234.5", "1234,5", "1.234,56", "1,234.56", "-12"
local function parse(s)
  if type(s) ~= "string" then return nil end
  s = s:gsub("%s", "")
  if s == "" or s == "-" then return nil end
  local lastDot, lastComma = s:match(".*()%."), s:match(".*(),")
  local _, dots = s:gsub("%.", "")
  local _, commas = s:gsub(",", "")
  if dots > 0 and commas > 0 then
    if lastComma > lastDot then s = s:gsub("%.", ""):gsub(",", ".") else s = s:gsub(",", "") end
  elseif commas > 0 then
    local after = #s - lastComma
    if commas > 1 or (not isTR and after == 3) then s = s:gsub(",", "") else s = s:gsub(",", ".") end
  elseif dots > 1 or (dots == 1 and isTR and #s - lastDot == 3) then
    s = s:gsub("%.", "")
  end
  return tonumber(s)
end

local function fmt(v, dec)
  dec = dec or 2
  if not v or v ~= v or v == math.huge or v == -math.huge then return "—" end
  local neg = v < 0 and floor(abs(v) * 10 ^ dec + 0.5) > 0
  local s = string.format("%." .. dec .. "f", abs(v))
  local int, frac = s:match("^(%d+)%.?(%d*)$")
  if not int then return s end
  int = int:reverse():gsub("(%d%d%d)", "%1" .. GRP):reverse()
  if int:sub(1, 1) == GRP then int = int:sub(2) end
  local out = int
  if dec > 0 and frac and frac ~= "" then out = out .. DEC .. frac end
  return (neg and "−" or "") .. out
end
local function fmtPct(v, dec) return "%" .. fmt(v, dec or 2) end
local function pctText(v, dec)
  if isTR then return fmtPct(v, dec) end
  return fmt(v, dec or 2) .. "%"
end

-- ------------------------------------------------------------------ inputs (stored as text so typing is preserved)
local DEFAULTS = {
  loan_amount = "250000", loan_rate = "3.5", loan_years = "20", loan_unit = 1, loan_view = 1,
  sav_initial = "10000", sav_monthly = "500", sav_rate = "6", sav_years = "15",
  p1_x = "15", p1_y = "240", p2_x = "45", p2_y = "180", p3_x = "80", p3_y = "100", p4_x = "20", p4_y = "1500",
  vat_amount = "1000", vat_rate = 3, vat_custom = "18", vat_mode = 1,
}
local V = {}
local tab = 1
local version = 0

local function set(key, val)
  if V[key] ~= val then
    V[key] = val
    store.set("in_" .. key, val)
    version = version + 1
  end
end

local function input(key, x, y, w, ph, ox, oy)
  local nt = field(key, V[key], x, y, w, 30, ph or "0", "numeric", ox, oy)
  if nt ~= V[key] then set(key, nt) end
  return parse(V[key])
end

-- row: label on the left, field on the right, optional unit after the field
local function inputRow(label, key, x, y, w, unit, ph)
  gfx.color(theme.text)
  gfx.text(label, x + 14, y + 12, 13)
  local fw = 130
  local fx = x + w - fw - 14 - (unit and 34 or 0)
  local v = input(key, fx, y + 5, fw, ph)
  if unit then
    gfx.color(theme.text2)
    gfx.text(unit, fx + fw + 6, y + 12, 13, "medium")
  end
  return v
end

local function resultLine(label, value, x, y, w, color, big)
  gfx.color(theme.text2)
  gfx.text(label, x, y, big and 12 or 12, big and "semibold" or "sans")
  gfx.color(color or theme.text)
  if big then gfx.text(value, x, y + 16, 26, "bold")
  else gfx.text(value, x, y, 13, "semibold", "right", w) end
end

local function copyButton(id, text, x, y)
  if ui.iconButton("content_copy", x, y, 28, 26, theme.text3, false, id) then
    sys.clipboard(text)
    audio.play("pop", 0.4)
  end
end

-- ------------------------------------------------------------------ loan
local loanCache = {v = -1}
local function computeLoan()
  if loanCache.v == version then return loanCache end
  local P = parse(V.loan_amount)
  local rate = parse(V.loan_rate)
  local term = parse(V.loan_years)
  local c = {v = version, ok = false}
  if P and rate and term and P > 0 and rate >= 0 and term > 0 then
    local n = V.loan_unit == 1 and floor(term * 12 + 0.5) or floor(term + 0.5)
    if n >= 1 and n <= 1200 then
      local r = rate / 100 / 12
      local pay = r == 0 and P / n or P * r / (1 - (1 + r) ^ (-n))
      local rows, yearly = {}, {}
      local bal = P
      local totInt = 0
      for k = 1, n do
        local int = bal * r
        local prin = pay - int
        if k == n then prin = bal end
        bal = max(0, bal - prin)
        totInt = totInt + int
        rows[k] = {k, prin + int, prin, int, bal}
        local yk = floor((k - 1) / 12) + 1
        local yr = yearly[yk] or {yk, 0, 0, 0, 0}
        yr[2], yr[3], yr[4], yr[5] = yr[2] + prin + int, yr[3] + prin, yr[4] + int, bal
        yearly[yk] = yr
      end
      c.ok, c.pay, c.n, c.total, c.interest, c.P, c.rows, c.yearly = true, pay, n, P + totInt, totInt, P, rows, yearly
    end
  end
  loanCache = c
  return c
end

local donutT = 0
local function drawLoan(w, h)
  local x, y = 16, 56
  local lw = 300
  ui.group(x, y, lw, 132)
  inputRow(TR("loan_amount"), "loan_amount", x, y + 2, lw, nil, "250000")
  ui.separator(x + 14, y + 44, x + lw - 14)
  inputRow(TR("annual_rate"), "loan_rate", x, y + 46, lw, "%", "3.5")
  ui.separator(x + 14, y + 88, x + lw - 14)
  gfx.color(theme.text)
  gfx.text(TR("term"), x + 14, y + 102, 13)
  local nu = ui.segmented("loan_unit", {TR("years"), TR("months")}, V.loan_unit, x + 64, y + 96, 100, 28)
  if nu ~= V.loan_unit then set("loan_unit", nu) end
  input("loan_years", x + lw - 14 - 110, y + 95, 110, "20")

  -- results card
  local rx, rw = x + lw + 12, w - (x + lw + 12) - 16
  ui.group(rx, y, rw, 132)
  local c = computeLoan()
  if not c.ok then
    gfx.icon("info", rx + rw / 2, y + 48, 26, theme.text3)
    gfx.color(theme.text2)
    gfx.wrap(TR("enter_values"), rx + 20, y + 70, rw - 40, 13, "sans", "center")
  else
    resultLine(TR("monthly_payment"), fmt(c.pay), rx + 16, y + 12, rw, theme.accent, true)
    copyButton("cp_pay", fmt(c.pay), rx + 16 + gfx.textWidth(fmt(c.pay), 26, "bold") + 6, y + 30)
    local ly = y + 70
    gfx.color(theme.text2)
    gfx.text(TR("total_payment"), rx + 16, ly, 12)
    gfx.color(theme.text)
    gfx.text(fmt(c.total), rx + 16, ly + 15, 14, "semibold")
    gfx.color(theme.text2)
    gfx.text(TR("total_interest"), rx + 16, ly + 34, 12)
    gfx.color(theme.orange)
    gfx.text(fmt(c.interest), rx + 16, ly + 49, 14, "semibold")
    -- donut: principal vs interest
    local cx, cy, R = rx + rw - 62, y + 66, 46
    local frac = c.total > 0 and c.P / c.total or 1
    donutT = approach(donutT, frac, 8, 1 / 60)
    local a0 = -math.pi / 2
    local a1 = a0 + math.pi * 2 * donutT
    gfx.color(theme.accent)
    gfx.pie(cx, cy, R, a0, a1)
    gfx.color(theme.orange)
    gfx.pie(cx, cy, R, a1, a0 + math.pi * 2)
    gfx.circle(cx, cy, R - 14, theme.dark and theme.window or theme.bg)
    gfx.color(theme.text)
    gfx.text(pctText(c.interest / c.total * 100, 0), cx - 30, cy - 9, 12, "bold", "center", 60)
    gfx.color(theme.text3)
    gfx.text(TR("interest_short"), cx - 30, cy + 5, 9, "medium", "center", 60)
  end

  -- amortization table
  local ty = y + 146
  gfx.color(theme.text)
  gfx.text(TR("amortization"), x, ty + 6, 15, "bold")
  local nv = ui.segmented("loan_view", {TR("monthly"), TR("yearly")}, V.loan_view, w - 16 - 180, ty, 180, 28)
  if nv ~= V.loan_view then set("loan_view", nv) end
  local hy = ty + 38
  local cols = {0.10, 0.225, 0.225, 0.225, 0.225}
  local heads = {V.loan_view == 1 and TR("col_month") or TR("col_year"), TR("col_payment"), TR("col_principal"), TR("col_interest"), TR("col_balance")}
  local tw = w - 32
  gfx.rect(x, hy, tw, 26, 6, alpha(theme.text, 0.05))
  local cx = x
  for i, hd in ipairs(heads) do
    local cw = tw * cols[i]
    gfx.color(theme.text2)
    if i == 1 then gfx.text(hd, cx + 8, hy + 6, 11, "semibold")
    else gfx.text(hd, cx, hy + 6, 11, "semibold", "right", cw - 8) end
    cx = cx + cw
  end
  local listY = hy + 28
  local listH = h - listY - 12
  if not c.ok then return end
  local rows = V.loan_view == 1 and c.rows or c.yearly
  local rowH = 26
  local sy = ui.beginScroll("amort", x, listY, tw, listH, #rows * rowH)
  local first = max(1, floor(sy / rowH) + 1)
  local last = min(#rows, floor((sy + listH) / rowH) + 1)
  for k = first, last do
    local r = rows[k]
    local ry = (k - 1) * rowH
    if k % 2 == 0 then gfx.rect(0, ry, tw, rowH, 4, alpha(theme.text, 0.03)) end
    local cx2 = 0
    for i = 1, 5 do
      local cw = tw * cols[i]
      local txt = i == 1 and tostring(r[1]) or fmt(r[i])
      gfx.color(i == 4 and theme.orange or (i == 1 and theme.text2 or theme.text))
      if i == 1 then gfx.text(txt, cx2 + 8, ry + 6, 12, "medium")
      else gfx.text(txt, cx2, ry + 6, 12, "sans", "right", cw - 8) end
      cx2 = cx2 + cw
    end
  end
  ui.endScroll()
end

-- ------------------------------------------------------------------ savings
local savCache = {v = -1}
local function computeSavings()
  if savCache.v == version then return savCache end
  local P = parse(V.sav_initial) or 0
  local M = parse(V.sav_monthly) or 0
  local rate = parse(V.sav_rate)
  local years = parse(V.sav_years)
  local c = {v = version, ok = false}
  if rate and years and years >= 1 and years <= 100 and (P > 0 or M > 0) and P >= 0 and M >= 0 then
    years = floor(years + 0.5)
    local r = rate / 100 / 12
    local bal, contrib = P, P
    local yearsData = {}
    for yv = 1, years do
      for _ = 1, 12 do
        bal = bal * (1 + r) + M
        contrib = contrib + M
      end
      yearsData[yv] = {contrib = contrib, balance = bal}
    end
    c.ok, c.balance, c.contrib, c.interest, c.years, c.data = true, bal, contrib, bal - contrib, years, yearsData
  end
  savCache = c
  return c
end

local barAnim = 0
local lastSavVersion = -1
local function drawSavings(w, h)
  local x, y = 16, 56
  local lw = 300
  ui.group(x, y, lw, 176)
  inputRow(TR("initial_deposit"), "sav_initial", x, y + 2, lw, nil, "10000")
  ui.separator(x + 14, y + 44, x + lw - 14)
  inputRow(TR("monthly_contribution"), "sav_monthly", x, y + 46, lw, nil, "500")
  ui.separator(x + 14, y + 88, x + lw - 14)
  inputRow(TR("annual_return"), "sav_rate", x, y + 90, lw, "%", "6")
  ui.separator(x + 14, y + 132, x + lw - 14)
  inputRow(TR("years_label"), "sav_years", x, y + 134, lw, TR("years_unit"), "15")

  local rx, rw = x + lw + 12, w - (x + lw + 12) - 16
  ui.group(rx, y, rw, 176)
  local c = computeSavings()
  if not c.ok then
    gfx.icon("info", rx + rw / 2, y + 60, 26, theme.text3)
    gfx.color(theme.text2)
    gfx.wrap(TR("enter_values"), rx + 20, y + 84, rw - 40, 13, "sans", "center")
    return
  end
  resultLine(TR("final_balance"), fmt(c.balance), rx + 16, y + 14, rw, theme.green, true)
  copyButton("cp_bal", fmt(c.balance), rx + 16 + gfx.textWidth(fmt(c.balance), 26, "bold") + 6, y + 32)
  local ly = y + 76
  gfx.rect(rx + 16, ly + 3, 10, 10, 3, theme.accent)
  gfx.color(theme.text2)
  gfx.text(TR("total_contributions"), rx + 32, ly, 12)
  gfx.color(theme.text)
  gfx.text(fmt(c.contrib), rx + 32, ly + 15, 14, "semibold")
  gfx.rect(rx + 16, ly + 43, 10, 10, 3, theme.green)
  gfx.color(theme.text2)
  gfx.text(TR("interest_earned"), rx + 32, ly + 40, 12)
  gfx.color(theme.green)
  gfx.text(fmt(c.interest), rx + 32, ly + 55, 14, "semibold")
  gfx.color(theme.text3)
  gfx.text(TR("monthly_compounding"), rx + 16, y + 154, 11)

  -- growth chart (stacked bars: contributions + interest per year)
  if lastSavVersion ~= version then lastSavVersion = version; barAnim = 0 end
  barAnim = min(1, barAnim + 1 / 60 * 2.2)
  local e = 1 - (1 - barAnim) ^ 3
  local gy = y + 190
  local gh = h - gy - 16
  ui.group(x, gy, w - 32, gh)
  gfx.color(theme.text)
  gfx.text(TR("growth"), x + 14, gy + 10, 13, "semibold")
  local cx, cy, cw, ch = x + 70, gy + 36, w - 32 - 70 - 16, gh - 36 - 28
  local maxV = c.balance > 0 and c.balance or 1
  -- grid lines
  for i = 0, 4 do
    local yy = cy + ch - ch * i / 4
    gfx.rect(cx, yy, cw, 1, 0, alpha(theme.text, i == 0 and 0.2 or 0.07))
    gfx.color(theme.text3)
    gfx.text(fmt(maxV * i / 4, 0), x + 4, yy - 7, 10, "sans", "right", 60)
  end
  local n = c.years
  local slot = cw / n
  local bw = max(2, min(26, slot * 0.7))
  local hoverY = nil
  for i = 1, n do
    local d = c.data[i]
    local bx = cx + (i - 1) * slot + (slot - bw) / 2
    local hc = ch * (d.contrib / maxV) * e
    local hb = ch * (d.balance / maxV) * e
    local hit = ui.hit("bar" .. i, cx + (i - 1) * slot, cy, slot, ch)
    if hit.hovered then hoverY = i end
    local hi = hoverY == i
    gfx.rect(bx, cy + ch - hb, bw, hb, min(4, bw / 2), alpha(theme.green, hi and 1 or 0.85))
    gfx.rect(bx, cy + ch - hc, bw, hc, min(4, bw / 2), alpha(theme.accent, hi and 1 or 0.85))
    local every = n <= 12 and 1 or (n <= 25 and 2 or (n <= 50 and 5 or 10))
    if i % every == 0 or i == 1 then
      gfx.color(theme.text3)
      gfx.text(tostring(i), cx + (i - 1) * slot, cy + ch + 6, 10, "sans", "center", slot)
    end
  end
  if hoverY then
    local d = c.data[hoverY]
    local tx = clamp(cx + (hoverY - 0.5) * slot - 90, cx, cx + cw - 180)
    local ty = cy + 4
    gfx.shadow(tx, ty, 180, 62, 8, 10, 3)
    gfx.rect(tx, ty, 180, 62, 8, theme.window)
    gfx.color(theme.text)
    gfx.text(TR("year_n", hoverY), tx + 10, ty + 6, 12, "bold")
    gfx.color(theme.text2)
    gfx.text(TR("balance_short") .. "  " .. fmt(d.balance), tx + 10, ty + 24, 11)
    gfx.color(theme.green)
    gfx.text(TR("interest_short") .. "  " .. fmt(d.balance - d.contrib), tx + 10, ty + 40, 11)
  end
end

-- ------------------------------------------------------------------ percentages
local function drawPercent(w, h)
  local x, y = 16, 56
  local cw = (w - 32 - 12) / 2
  local chh = (h - y - 16 - 12) / 2
  local cards = {
    {title = "p1_title", a = "p1_x", b = "p1_y", la = "p1_la", lb = "p1_lb"},
    {title = "p2_title", a = "p2_x", b = "p2_y", la = "p2_la", lb = "p2_lb"},
    {title = "p3_title", a = "p3_x", b = "p3_y", la = "p3_la", lb = "p3_lb"},
    {title = "p4_title", a = "p4_x", b = "p4_y", la = "p4_la", lb = "p4_lb"},
  }
  for i, cd in ipairs(cards) do
    local cx = x + ((i - 1) % 2) * (cw + 12)
    local cy = y + floor((i - 1) / 2) * (chh + 12)
    ui.group(cx, cy, cw, chh)
    gfx.color(theme.text)
    gfx.text(TR(cd.title), cx + 14, cy + 12, 14, "bold")
    gfx.color(theme.text2)
    gfx.text(TR(cd.la), cx + 14, cy + 48, 12)
    local a = input(cd.a, cx + cw - 14 - 120, cy + 41, 120)
    gfx.color(theme.text2)
    gfx.text(TR(cd.lb), cx + 14, cy + 88, 12)
    local b = input(cd.b, cx + cw - 14 - 120, cy + 81, 120)
    ui.separator(cx + 14, cy + 124, cx + cw - 14)
    local res, col, sub = nil, theme.accent, nil
    if a and b then
      if i == 1 then res = fmt(a / 100 * b)
      elseif i == 2 then if b ~= 0 then res = pctText(a / b * 100) end
      elseif i == 3 then
        if a ~= 0 then
          local ch2 = (b - a) / abs(a) * 100
          res = (ch2 > 0 and "+" or "") .. pctText(ch2)
          col = ch2 > 0 and theme.green or (ch2 < 0 and theme.red or theme.text)
          sub = TR(ch2 >= 0 and "increase" or "decrease", fmt(abs(b - a)))
        end
      else
        res = fmt(b * (1 + a / 100))
        sub = TR("p4_minus", fmt(b * (1 - a / 100)))
      end
    end
    gfx.color(theme.text3)
    gfx.text(TR("result"), cx + 14, cy + 134, 11, "semibold")
    gfx.color(res and col or theme.text3)
    gfx.text(res or "—", cx + 14, cy + 150, 22, "bold")
    if res then copyButton("cp_p" .. i, res, cx + cw - 14 - 28, cy + 150) end
    if sub then
      gfx.color(theme.text2)
      gfx.text(sub, cx + 14, cy + 180, 11)
    end
  end
end

-- ------------------------------------------------------------------ VAT / KDV
local RATES = {1, 10, 20}
local vatAnim = 0
local function drawVat(w, h)
  local x, y = 16, 56
  local gw = w - 32
  local custom = V.vat_rate == 4
  local gh = custom and 192 or 144
  ui.group(x, y, gw, gh)
  gfx.color(theme.text)
  gfx.text(TR("amount"), x + 14, y + 16, 13)
  local amount = input("vat_amount", x + gw - 14 - 200, y + 9, 200, "1000")
  ui.separator(x + 14, y + 48, x + gw - 14)
  gfx.color(theme.text)
  gfx.text(TR("vat_rate"), x + 14, y + 64, 13)
  local items = isTR and {"%1", "%10", "%20", TR("custom")} or {"1%", "10%", "20%", TR("custom")}
  local nr = ui.segmented("vat_rate", items, V.vat_rate, x + gw - 14 - 280, y + 58, 280, 28)
  if nr ~= V.vat_rate then set("vat_rate", nr); audio.play("click", 0.3) end
  ui.separator(x + 14, y + 96, x + gw - 14)
  local rowY = y + 98
  local rate
  if custom then
    gfx.color(theme.text)
    gfx.text(TR("custom_rate"), x + 14, rowY + 14, 13)
    rate = input("vat_custom", x + gw - 14 - 34 - 100, rowY + 7, 100, "18")
    gfx.color(theme.text2)
    gfx.text("%", x + gw - 14 - 26, rowY + 14, 13, "medium")
    ui.separator(x + 14, rowY + 46, x + gw - 14)
    rowY = rowY + 48
  else
    rate = RATES[V.vat_rate]
  end
  gfx.color(theme.text)
  gfx.text(TR("mode"), x + 14, rowY + 14, 13)
  local nm = ui.segmented("vat_mode", {TR("add_vat"), TR("remove_vat")}, V.vat_mode, x + gw - 14 - 320, rowY + 8, 320, 28)
  if nm ~= V.vat_mode then set("vat_mode", nm) end
  local ry = y + gh + 12

  local ok = amount and rate and rate >= 0 and amount >= 0
  local net, vat, gross
  if ok then
    if V.vat_mode == 1 then net = amount; vat = amount * rate / 100; gross = net + vat
    else gross = amount; net = amount / (1 + rate / 100); vat = gross - net end
  end
  local rh = h - ry - 16
  ui.group(x, ry, gw, rh)
  if not ok then
    gfx.icon("info", x + gw / 2, ry + rh / 2 - 12, 26, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("enter_values"), x, ry + rh / 2 + 6, 13, "sans", "center", gw)
    return
  end
  local col3 = (gw - 28) / 3
  local vals = {
    {TR("net"), net, theme.text},
    {TR("vat_amount") .. " (" .. pctText(rate, rate == floor(rate) and 0 or 2) .. ")", vat, theme.orange},
    {TR("gross"), gross, theme.accent},
  }
  for i, v in ipairs(vals) do
    local vx = x + 14 + (i - 1) * col3
    gfx.color(theme.text2)
    gfx.text(v[1], vx, ry + 16, 12, "semibold")
    gfx.color(v[3])
    local s = fmt(v[2])
    local size = 24
    while size > 14 and gfx.textWidth(s, size, "bold") > col3 - 40 do size = size - 1 end
    gfx.text(s, vx, ry + 36, size, "bold")
    copyButton("cp_v" .. i, s, vx + gfx.textWidth(s, size, "bold") + 4, ry + 38)
  end
  -- proportion bar
  local frac = gross > 0 and net / gross or 1
  vatAnim = approach(vatAnim, frac, 8, 1 / 60)
  local by = ry + 86
  local bw = gw - 28
  gfx.rect(x + 14, by, bw, 14, 7, theme.orange)
  gfx.rect(x + 14, by, max(14, bw * vatAnim), 14, 7, theme.accent)
  gfx.color(theme.text3)
  gfx.text(TR("net_share") .. " " .. pctText(frac * 100, 1), x + 14, by + 22, 11)
  gfx.text(TR("vat_share") .. " " .. pctText((1 - frac) * 100, 1), x + 14, by + 22, 11, "sans", "right", bw)
  -- explanation
  gfx.color(theme.text2)
  local formula = V.vat_mode == 1 and TR("formula_add") or TR("formula_remove")
  gfx.wrap(formula, x + 14, by + 48, bw, 12)
end

-- ------------------------------------------------------------------ app
function app.load()
  isTR = sys.lang() == "tr"
  if isTR then DEC, GRP = ",", "." end
  for k, d in pairs(DEFAULTS) do
    local v = store.get("in_" .. k, d)
    if type(d) == "number" then v = math.tointeger(v) or d else v = tostring(v) end
    V[k] = v
  end
  tab = clamp(math.tointeger(store.get("tab", 1)) or 1, 1, 4)
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local nt = ui.segmented("tabs", {TR("tab_loan"), TR("tab_savings"), TR("tab_percent"), TR("tab_vat")}, tab, 16, 12, w - 32, 30)
  if nt ~= tab then tab = nt; store.set("tab", tab); audio.play("click", 0.3) end
  if tab == 1 then drawLoan(w, h)
  elseif tab == 2 then drawSavings(w, h)
  elseif tab == 3 then drawPercent(w, h)
  else drawVat(w, h) end
  if pressAt then editing = fieldHit; pressAt = nil; fieldHit = false end
end

function app.event(e)
  if e.type == "mousedown" then pressAt = {e.x, e.y} end
  if e.type ~= "keydown" then return end
  if e.key == "escape" then editing = false; return end
  if editing then return end
  local n = tonumber(e.key)
  if n and n >= 1 and n <= 4 then tab = n; store.set("tab", tab)
  elseif e.key == "left" then tab = (tab - 2) % 4 + 1; store.set("tab", tab)
  elseif e.key == "right" then tab = tab % 4 + 1; store.set("tab", tab) end
end

function app.menu()
  return {
    {title = TR("menu_calc"), items = {
      {label = TR("tab_loan"), id = 1, shortcut = "1", checked = tab == 1},
      {label = TR("tab_savings"), id = 2, shortcut = "2", checked = tab == 2},
      {label = TR("tab_percent"), id = 3, shortcut = "3", checked = tab == 3},
      {label = TR("tab_vat"), id = 4, shortcut = "4", checked = tab == 4},
      "-",
      {label = TR("reset"), id = 5},
    }},
  }
end

function app.onmenu(id)
  if id >= 1 and id <= 4 then tab = id; store.set("tab", tab)
  elseif id == 5 then
    for k, d in pairs(DEFAULTS) do set(k, d) end
  end
end

return app
