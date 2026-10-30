-- Dice & Coin: roll one to six dice (d4–d20) or flip a coin, with tumbling animations, totals, a history,
-- all-time statistics and export to the clipboard or a CSV file.
local app = {}

-- fills {0}, {1}… with plain text (user text may contain "%", which TR's own substitution must not see)
local function fmt(s, ...)
  local a = {...}
  return (s:gsub("{(%d)}", function(i) local v = a[tonumber(i) + 1]; if v ~= nil then return tostring(v) end end))
end

local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi

local SIDES = {4, 6, 8, 10, 12, 20}
local SIDE_LABELS = {"d4", "d6", "d8", "d10", "d12", "d20"}
-- shape per die type: vertex count and start angle (d6 is drawn as a square with pips)
local SHAPES = {[4] = {3, -pi / 2}, [8] = {4, -pi / 2}, [10] = {5, -pi / 2}, [12] = {5, pi / 2}, [20] = {6, 0}}
local COLORS = {[4] = "#E5484D", [6] = "#3E63DD", [8] = "#30A46C", [10] = "#8E4EC6", [12] = "#F76B15", [20] = "#0090FF"}
-- pip layout of a d6 face in -1..1 units
local PIPS = {
  {{0, 0}},
  {{-1, -1}, {1, 1}},
  {{-1, -1}, {0, 0}, {1, 1}},
  {{-1, -1}, {1, -1}, {-1, 1}, {1, 1}},
  {{-1, -1}, {1, -1}, {0, 0}, {-1, 1}, {1, 1}},
  {{-1, -1}, {-1, 0}, {-1, 1}, {1, -1}, {1, 0}, {1, 1}},
}
local COUNT_COLS = {1, 2, 3, 2, 3, 3}
local ROLL_TIME, FLIP_TIME = 0.9, 1.25

local tab = 1                     -- 1 dice, 2 coin, 3 statistics
local count, sidesIdx = 2, 2
local sound, vibrate = true, true
local values, held, spin = {}, {}, {}
local rolling, rollT, nextFace = false, 0, 0
local flipping, flipT, flipStart, flipTurns, lastHalf = false, 0, 1, 6, 0
local coinSide = 1                -- face shown when idle: 1 heads (Tura), 2 tails (Yazı)
local heads, tails = 0, 0
local history = {}                -- newest first: {k="d", s=sides, v={...}, t=total} or {k="c", r=1|2}
local faces = {}                  -- "d6" -> {count of 1, count of 2, ...}: all-time face distribution
local flash = 0                   -- "pop" of the result after a roll/flip (1 -> 0)
local shownTotal = 0              -- eased total
local tabFade = 1                 -- 0 -> 1 after switching tabs
local toast, toastT = "", 0
local pts = {}                    -- reused polygon buffer
local undoClear = nil             -- snapshot kept for a few seconds after clearing the history

local function sides() return SIDES[sidesIdx] or 6 end

local function save()
  store.set("history", history)
  store.set("stats", {heads = heads, tails = tails})
  store.set("values", values)
  store.set("faces", faces)
end

local function faceTable(n)
  local key = "d" .. n
  local t = faces[key]
  if type(t) ~= "table" then t = {}; faces[key] = t end
  for i = 1, n do t[i] = tonumber(t[i]) or 0 end
  return t
end

local function showToast(s) toast, toastT = s, 2.2 end

local function setTab(t)
  if t ~= tab then tab = t; tabFade = 0 end
end

local function pushHistory(e)
  table.insert(history, 1, e)
  while #history > 50 do table.remove(history) end
  save()
end

local function total()
  local s = 0
  for i = 1, count do s = s + (values[i] or 0) end
  return s
end

local function setCount(n)
  if rolling then return end
  n = max(1, min(6, n))
  if n == count then return end
  count = n
  for i = 1, count do if not values[i] then values[i] = math.random(1, sides()) end end
  store.set("count", count)
  if sound then audio.play("click") end
end

local function setSides(i)
  if rolling or not SIDES[i] or i == sidesIdx then return end
  sidesIdx = i
  held = {}
  for k = 1, 6 do values[k] = math.random(1, sides()) end
  store.set("sides", sidesIdx)
end

local function roll()
  if rolling or flipping then return end
  setTab(1)
  rolling, rollT, nextFace = true, 0, 0
  for i = 1, count do spin[i] = (math.random() < 0.5 and -1 or 1) * (0.6 + math.random() * 0.8) end
end

local function finishRoll()
  rolling = false
  local n, v = sides(), {}
  local ft = faceTable(n)
  for i = 1, count do
    if not held[i] or not values[i] then values[i] = math.random(1, n) end
    v[i] = values[i]
    ft[v[i]] = (ft[v[i]] or 0) + 1
  end
  pushHistory({k = "d", s = n, v = v, t = total()})
  flash = 1
  if sound then audio.tone(660, 0.08, 0.3, "triangle") end
  if vibrate then sys.vibrate(0.5, 80) end
end

local function flip()
  if rolling or flipping then return end
  setTab(2)
  local result = math.random(1, 2)
  flipStart = coinSide
  -- an even number of half turns shows the start face again, an odd number the other face
  flipTurns = (result == flipStart) and 8 or 9
  flipping, flipT, lastHalf = true, 0, 0
end

local function finishFlip()
  flipping = false
  coinSide = (flipTurns % 2 == 0) and flipStart or (3 - flipStart)
  if coinSide == 1 then heads = heads + 1 else tails = tails + 1 end
  pushHistory({k = "c", r = coinSide})
  flash = 1
  if sound then
    audio.tone(880, 0.1, 0.3, "sine")
    timer.after(0.08, function() audio.tone(1320, 0.14, 0.25, "sine") end)
  end
  if vibrate then sys.vibrate(0.4, 60) end
end

local function clearHistory()
  if #history == 0 and heads + tails == 0 then return end
  undoClear = {history = history, heads = heads, tails = tails, faces = faces, t = 6}
  history, heads, tails, faces = {}, 0, 0, {}
  save()
  showToast(TR("cleared"))
end

local function undoClearHistory()
  if not undoClear then return end
  history, heads, tails, faces = undoClear.history, undoClear.heads, undoClear.tails, undoClear.faces
  undoClear = nil
  save()
  showToast(TR("restored"))
end

-- one line describing the latest result, for the clipboard
local function resultText()
  local e = history[1]
  if not e then return nil end
  if e.k == "c" then return e.r == 1 and TR("heads") or TR("tails") end
  local vs = type(e.v) == "table" and e.v or {}
  return #vs .. "d" .. tostring(e.s or 6) .. ": " .. table.concat(vs, " + ") .. " = " .. tostring(e.t or 0)
end

local function copyResult()
  local s = resultText()
  if not s then showToast(TR("no_history")); return end
  sys.clipboard(s)
  showToast(fmt(TR("copied"), s))
end

-- the whole history as CSV, written to a file the user picks
local function exportHistory()
  if #history == 0 then showToast(TR("no_history")); return end
  ui.saveFile(function(path)
    if not path then return end
    local lines = {"type,dice,values,total"}
    for i = #history, 1, -1 do
      local e = history[i]
      if e.k == "c" then
        lines[#lines + 1] = "coin,1," .. (e.r == 1 and "heads" or "tails") .. ","
      else
        local vs = type(e.v) == "table" and e.v or {}
        lines[#lines + 1] = "dice," .. #vs .. "d" .. tostring(e.s or 6) .. "," .. table.concat(vs, " ") .. "," .. tostring(e.t or 0)
      end
    end
    if fs.write(path, table.concat(lines, "\n") .. "\n") then showToast(TR("saved")) else showToast(TR("save_failed")) end
  end, "dice-history.csv", TR("export"))
end

function app.load(arg)
  count = max(1, min(6, floor(tonumber(store.get("count", 2)) or 2)))
  sidesIdx = max(1, min(#SIDES, floor(tonumber(store.get("sides", 2)) or 2)))
  sound = store.get("sound", true) ~= false
  vibrate = store.get("vibrate", true) ~= false
  local h = store.get("history", {})
  history = type(h) == "table" and h or {}
  local st = store.get("stats", {})
  if type(st) == "table" then heads, tails = tonumber(st.heads) or 0, tonumber(st.tails) or 0 end
  local f = store.get("faces", {})
  faces = type(f) == "table" and f or {}
  local v = store.get("values", {})
  for i = 1, 6 do
    local n = type(v) == "table" and tonumber(v[i]) or nil
    values[i] = (n and n >= 1 and n <= sides()) and floor(n) or math.random(1, sides())
  end
  shownTotal = total()
end

function app.update(dt)
  flash = max(0, flash - dt * 2.5)
  tabFade = min(1, tabFade + dt * 5)
  toastT = max(0, toastT - dt)
  if undoClear then
    undoClear.t = undoClear.t - dt
    if undoClear.t <= 0 then undoClear = nil end
  end
  if not rolling then shownTotal = shownTotal + (total() - shownTotal) * min(1, dt * 10) end
  if rolling then
    rollT = rollT + dt
    nextFace = nextFace - dt
    if nextFace <= 0 then
      -- faces change quickly at first and slow down as the dice settle
      for i = 1, count do if not held[i] then values[i] = math.random(1, sides()) end end
      nextFace = 0.04 + rollT * 0.1
      if sound then audio.tone(200, 0.03, 0.18, "noise") end
    end
    if rollT >= ROLL_TIME then finishRoll() end
  end
  if flipping then
    flipT = flipT + dt
    local p = min(1, flipT / FLIP_TIME)
    local half = floor((1 - (1 - p) ^ 3) * flipTurns)
    if half ~= lastHalf then lastHalf = half; if sound then audio.tone(1200, 0.02, 0.12, "sine") end end
    if flipT >= FLIP_TIME then finishFlip() end
  end
end

-- fills pts with k points around (cx, cy) and draws the convex shape
local function polygon(cx, cy, rx, ry, k, a0, color)
  for i = 0, k - 1 do
    local a = a0 + i * 2 * pi / k
    pts[i * 2 + 1] = cx + cos(a) * rx
    pts[i * 2 + 2] = cy + sin(a) * ry
  end
  for i = #pts, k * 2 + 1, -1 do pts[i] = nil end
  gfx.poly(pts, color)
end

local function drawD6(cx, cy, size, angle, v)
  local half = size / 2
  if angle == 0 then
    gfx.shadow(cx - half, cy - half, size, size, size * 0.18, 10, 4)
    gfx.color("#FBFBF8")
    gfx.rect(cx - half, cy - half, size, size, size * 0.18)
    gfx.color("#00000022")
    gfx.rectLine(cx - half, cy - half, size, size, size * 0.18, 1)
  else
    polygon(cx + 3, cy + 5, half * 1.38, half * 1.38, 4, angle + pi / 4, "#00000040")
    polygon(cx, cy, half * 1.38, half * 1.38, 4, angle + pi / 4, "#FBFBF8")
  end
  local ca, sa, d, pr = cos(angle), sin(angle), size * 0.27, size * 0.085
  gfx.color("#1C1C1E")
  for _, p in ipairs(PIPS[v] or PIPS[1]) do
    local px, py = p[1] * d, p[2] * d
    gfx.circle(cx + px * ca - py * sa, cy + px * sa + py * ca, pr)
  end
end

local function drawPoly(cx, cy, size, angle, v, n)
  local s = SHAPES[n] or SHAPES[20]
  local r = size * 0.62
  polygon(cx + 3, cy + 5, r, r, s[1], s[2] + angle, "#00000040")
  polygon(cx, cy, r, r, s[1], s[2] + angle, COLORS[n] or theme.accent)
  polygon(cx, cy, r * 0.72, r * 0.72, s[1], s[2] + angle, "#FFFFFF26")
  gfx.color("#FFFFFF")
  local fs = size * (n == 4 and 0.3 or 0.36)
  gfx.text(tostring(v), cx - size, cy - fs * 0.62 + (n == 4 and size * 0.08 or 0), fs, "bold", "center", size * 2)
end

-- draws the dice on the felt; returns true when a die was tapped (hold/release)
local function drawDice(ax, fy, aw, fh)
  local cols = COUNT_COLS[count] or 3
  local rows = math.ceil(count / cols)
  local cellW, cellH = (aw - 20) / cols, (fh - 20) / rows
  local size = min(110, min(cellW, cellH) * 0.62)
  local sx, sy = min(cellW, size * 1.7), min(cellH, size * 1.6)
  local n = sides()
  local p = rolling and min(1, rollT / ROLL_TIME) or 1
  local hitAny = false
  for i = 1, count do
    local c, r = (i - 1) % cols, floor((i - 1) / cols)
    local inRow = min(cols, count - r * cols)
    local cx = ax + aw / 2 + (c - (inRow - 1) / 2) * sx
    local cy = fy + fh / 2 + (r - (rows - 1) / 2) * sy
    local angle, bounce = 0, 0
    if rolling and not held[i] then
      angle = (spin[i] or 1) * rollT * 12 * (1 - p)
      bounce = -abs(sin(rollT * 14 + i)) * size * 0.18 * (1 - p)
    end
    local scale = (not rolling and flash > 0 and not held[i]) and (1 + sin(flash * pi) * 0.1) or 1
    if held[i] then
      gfx.color(theme.yellow)
      gfx.circle(cx, cy, size * 0.84)
      gfx.color("#1E5F42")
      gfx.circle(cx, cy, size * 0.79)
    end
    if n == 6 then drawD6(cx, cy + bounce, size * scale, angle, values[i] or 1)
    else drawPoly(cx, cy + bounce, size * scale, angle, values[i] or 1, n) end
    if held[i] then gfx.icon("lock", cx + size * 0.62, cy - size * 0.62, 18, theme.yellow) end
    local hit = ui.hit("die" .. i, cx - size / 2, cy - size / 2, size, size)
    if hit.clicked and not rolling and count > 1 then
      held[i] = not held[i]
      hitAny = true
      if sound then audio.play("click") end
    end
  end
  return hitAny
end

local function drawDiceTab(ax, ay, aw, ah)
  -- controls: dice count and type
  if ui.iconButton("remove", ax, ay, 32, 32) then setCount(count - 1) end
  gfx.color(theme.text)
  gfx.text(tostring(count), ax + 32, ay + 6, 17, "semibold", "center", 32)
  if ui.iconButton("add", ax + 64, ay, 32, 32) then setCount(count + 1) end
  local ns = ui.dropdown("sides", SIDE_LABELS, sidesIdx, ax + 106, ay, 92, 32)
  if ns ~= sidesIdx then setSides(ns) end
  if aw > 340 and count > 1 then
    gfx.color(theme.text3)
    gfx.text(TR("hold_hint"), ax + 210, ay + 9, 12, "sans", "right", aw - 210)
  end

  local fy, fh = ay + 44, ah - 44 - 56
  gfx.gradient(ax, fy, aw, fh, "#2A7A55", "#1E5F42", false, 14)
  gfx.color("#FFFFFF14")
  gfx.rectLine(ax + 6, fy + 6, aw - 12, fh - 12, 10, 1)
  local diceHit = drawDice(ax, fy, aw, fh)
  local hf = ui.hit("table", ax, fy, aw, fh)
  if hf.clicked and not diceHit then roll() end

  local by = ay + ah - 42
  gfx.color(theme.text2)
  gfx.text(TR("total"), ax, by, 12, "semibold")
  gfx.color(theme.text)
  local tsz = 24 + sin(flash * pi) * 6
  local tw = gfx.text(rolling and "…" or tostring(floor(shownTotal + 0.5)), ax, by + 14, tsz, "bold")
  if count > 1 and not rolling then
    gfx.color(theme.text3)
    gfx.text(TR("min_max", count, count * sides()), ax + max(46, tw + 12), by + 22, 12)
  end
  if ui.button(TR("roll"), ax + aw - 150, by + 2, 150, 38, "primary", "casino", not rolling) then roll() end
end

local function drawCoin(cx, cy, r)
  local sx, face, lift = 1, coinSide, 0
  if flipping then
    local p = min(1, flipT / FLIP_TIME)
    local a = (1 - (1 - p) ^ 3) * flipTurns * pi
    sx = cos(a)
    face = sx >= 0 and flipStart or (3 - flipStart)
    lift = -sin(p * pi) * r * 1.1
  end
  local ax = max(0.04, abs(sx))
  -- shadow shrinks while the coin is in the air
  polygon(cx, cy + r + 12, r * 0.8 * (1 + lift / (r * 3)), 8, 36, 0, "#00000032")
  cy = cy + lift
  polygon(cx + 3 * ax, cy + 3, r * ax, r, 36, 0, "#8A6212")
  polygon(cx, cy, r * ax, r, 36, 0, "#D4A017")
  polygon(cx, cy, r * 0.84 * ax, r * 0.84, 36, 0, face == 1 and "#F4C430" or "#EBC046")
  if ax > 0.35 then
    gfx.color("#8A6212")
    if face == 1 then
      gfx.icon("star", cx, cy - r * 0.12, r * 0.75 * ax, "#9C7012")
      gfx.text(TR("heads_short"), cx - r, cy + r * 0.34, r * 0.2, "bold", "center", r * 2)
    else
      gfx.text("1", cx - r, cy - r * 0.48, r * 0.75, "bold", "center", r * 2)
      gfx.text(TR("tails_short"), cx - r, cy + r * 0.34, r * 0.2, "bold", "center", r * 2)
    end
  end
end

local function drawCoinTab(ax, ay, aw, ah)
  local fy, fh = ay, ah - 100
  gfx.color(theme.field)
  gfx.rect(ax, fy, aw, fh, 14)
  local r = max(30, min(90, min(aw, fh) * 0.28))
  drawCoin(ax + aw / 2, fy + fh / 2 + r * 0.25, r)
  local hc = ui.hit("coin", ax, fy, aw, fh)
  if hc.clicked then flip() end

  local ty = fy + fh + 12
  gfx.color(theme.text)
  local res = flipping and "…" or (coinSide == 1 and TR("heads") or TR("tails"))
  gfx.text(heads + tails > 0 and res or TR("tap_to_flip"), ax, ty, 20 + sin(flash * pi) * 5, "bold")
  local n = heads + tails
  local hp = n > 0 and floor(heads * 100 / n + 0.5) or 0
  gfx.color(theme.text2)
  gfx.text(TR("coin_stats", heads, hp, tails, n > 0 and 100 - hp or 0), ax, ty + 30, 13)
  if ui.button(TR("flip"), ax + aw - 150, ay + ah - 38, 150, 38, "primary", "toll", not flipping) then flip() end
end

-- all-time face distribution of the selected die type, plus the coin ratio
local function drawStatsTab(ax, ay, aw, ah)
  local n = sides()
  local ft = faceTable(n)
  local rolls = 0
  for i = 1, n do rolls = rolls + ft[i] end
  local ns = ui.dropdown("sides2", SIDE_LABELS, sidesIdx, ax, ay, 92, 32)
  if ns ~= sidesIdx then setSides(ns) end
  gfx.color(theme.text2)
  gfx.text(TR("faces_rolled", rolls), ax + 104, ay + 8, 13)
  local grow = 1 - (1 - tabFade) ^ 3
  local cy, ch = ay + 44, ah - 44 - 86
  gfx.color(theme.field)
  gfx.rect(ax, cy, aw, ch, 14)
  if rolls == 0 then
    gfx.icon("bar_chart", ax + aw / 2, cy + ch / 2 - 22, 52, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("no_stats"), ax + 10, cy + ch / 2 + 12, 14, "semibold", "center", aw - 20)
  else
    local mx = 1
    for i = 1, n do mx = max(mx, ft[i]) end
    local expected = rolls / n
    mx = max(mx, expected)
    local px, py, pw, ph = ax + 14, cy + 26, aw - 28, ch - 54
    local bw = pw / n
    for i = 1, n do
      local bh = ph * ft[i] / mx * grow
      local bx = px + (i - 1) * bw
      gfx.color(COLORS[n] or theme.accent)
      if bh > 0.5 then gfx.rect(bx + bw * 0.15, py + ph - bh, bw * 0.7, bh, min(6, bw * 0.2)) end
      gfx.color(theme.text2)
      gfx.text(tostring(i), bx, py + ph + 6, n > 12 and 10 or 12, "sans", "center", bw)
      if bw > 24 then
        gfx.color(theme.text3)
        gfx.text(tostring(ft[i]), bx, py + ph - bh - 15, 10, "sans", "center", bw)
      end
    end
    -- dashed line at the count a fair die would give
    local ey = py + ph - ph * expected / mx * grow
    gfx.color(theme.orange)
    for xx = px, px + pw - 6, 12 do gfx.line(xx, ey, xx + 6, ey, 2) end
    gfx.text(TR("expected"), px, ey - 16, 10, "semibold", "right", pw)
  end
  -- coin ratio bar
  local by = cy + ch + 14
  local tot = heads + tails
  gfx.color(theme.text)
  gfx.text(TR("tab_coin"), ax, by, 14, "semibold")
  gfx.color(theme.text2)
  gfx.text(TR("flips_total", tot), ax, by, 12, "sans", "right", aw)
  local k = tot > 0 and heads / tot or 0.5
  gfx.color(theme.separator)
  gfx.rect(ax, by + 24, aw, 14, 7)
  if tot > 0 then
    gfx.color("#D4A017")
    gfx.rect(ax, by + 24, max(14, aw * k * grow), 14, 7)
  end
  gfx.color(theme.text2)
  local hp = floor(k * 100 + 0.5)
  gfx.text(TR("heads") .. " " .. (tot > 0 and hp or 0) .. "%", ax, by + 44, 12)
  gfx.text(TR("tails") .. " " .. (tot > 0 and 100 - hp or 0) .. "%", ax, by + 44, 12, "sans", "right", aw)
end

local function drawHistory(x, y, w, h)
  gfx.color(theme.field)
  gfx.rect(x, y, w, h, 12)
  gfx.color(theme.text)
  gfx.text(TR("history"), x + 12, y + 11, 14, "semibold")
  if ui.iconButton("content_copy", x + w - 72, y + 4, 32, 30) then copyResult() end
  if ui.iconButton("delete", x + w - 38, y + 4, 32, 30) then
    if #history > 0 then
      ui.alert(TR("clear_history"), TR("clear_msg"), {TR("clear"), TR("common.cancel")}, function(b)
        if b == 1 then clearHistory() end
      end)
    end
  end
  local ly, lh = y + 40, h - 44
  if #history == 0 then
    gfx.icon("casino", x + w / 2, ly + lh / 2 - 30, 52, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("no_history"), x + 8, ly + lh / 2 + 4, 13, "semibold", "center", w - 16)
    gfx.color(theme.text3)
    gfx.wrap(TR("no_history_hint"), x + 12, ly + lh / 2 + 24, w - 24, 11, "sans", "center")
    return
  end
  local rowH = 40
  -- a new result slides in at the top and pushes the older rows down
  local ease = flash * flash
  ui.beginScroll("hist", x, ly, w, lh, #history * rowH + 6)
  for i, e in ipairs(history) do
    local ry = (i - 1) * rowH - (i > 1 and ease * rowH or 0)
    if i == 1 then gfx.alpha(1 - ease) end
    if i > 1 then ui.separator(10, ry, w - 10) end
    if e.k == "c" then
      gfx.icon("toll", 22, ry + rowH / 2, 18, "#D4A017")
      gfx.color(theme.text)
      gfx.text(e.r == 1 and TR("heads") or TR("tails"), 40, ry + 11, 13, "semibold")
    else
      local vs = type(e.v) == "table" and e.v or {}
      gfx.color(theme.text)
      gfx.text(#vs .. "d" .. tostring(e.s or 6), 12, ry + 4, 13, "semibold")
      gfx.text(tostring(e.t or 0), 0, ry + 4, 15, "bold", "right", w - 12)
      gfx.color(theme.text3)
      gfx.text(table.concat(vs, " · "), 12, ry + 22, 11, "sans")
    end
    if i == 1 then gfx.unalpha() end
  end
  ui.endScroll()
end

local function drawToast(w, h)
  if toastT <= 0 then return end
  local a = min(1, toastT * 4)
  local tw = min(w - 40, gfx.textWidth(toast, 13, "semibold") + 36)
  local extra = undoClear and 76 or 0
  local x, y = (w - tw - extra) / 2, h - 58 + (1 - a) * 20
  gfx.alpha(a)
  gfx.shadow(x, y, tw + extra, 38, 19, 12, 4)
  gfx.color(theme.dark and "#3A3A3C" or "#1C1C1E")
  gfx.rect(x, y, tw + extra, 38, 19)
  gfx.color("#FFFFFF")
  gfx.text(toast, x + 18, y + 10, 13, "semibold")
  gfx.unalpha()
  if undoClear and ui.button(TR("undo"), x + tw, y + 4, 70, 30, "plain") then undoClearHistory() end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local histW = w >= 620 and 200 or 172
  local nt = ui.segmented("tabs", {TR("tab_dice"), TR("tab_coin"), TR("tab_stats")}, tab, 20, 14, 300, 30)
  if not rolling and not flipping then setTab(nt) end
  if ui.iconButton(sound and "volume_up" or "volume_off", w - 56, 13, 36, 32, sound and theme.accent or theme.text3) then
    sound = not sound; store.set("sound", sound)
  end
  if ui.iconButton("vibration", w - 96, 13, 36, 32, vibrate and theme.accent or theme.text3) then
    vibrate = not vibrate; store.set("vibrate", vibrate)
    if vibrate then sys.vibrate(0.4, 60) end
  end
  if w >= 600 and ui.iconButton("ios_share", w - 136, 13, 36, 32) then exportHistory() end
  local ax, ay = 20, 58
  local aw, ah = w - 40 - histW - 14, h - 58 - 18
  -- tabs fade and slide in
  local e = 1 - (1 - tabFade) ^ 3
  gfx.alpha(0.2 + 0.8 * e)
  gfx.push(0, (1 - e) * 12)
  if tab == 1 then drawDiceTab(ax, ay, aw, ah)
  elseif tab == 2 then drawCoinTab(ax, ay, aw, ah)
  else drawStatsTab(ax, ay, aw, ah) end
  gfx.pop()
  gfx.unalpha()
  drawHistory(w - 20 - histW, ay, histW, ah)
  drawToast(w, h)
end

function app.event(e)
  if e.type ~= "keydown" then return end
  local k = e.key
  if e.ctrl and k == "c" then copyResult(); return end
  if e.ctrl and k == "s" then exportHistory(); return end
  if e.ctrl and k == "z" then undoClearHistory(); return end
  if k == "space" or k == "enter" then
    if tab == 2 then flip() else roll() end
  elseif k == "c" then flip()
  elseif k == "r" then roll()
  elseif k == "up" then setCount(count + 1)
  elseif k == "down" then setCount(count - 1)
  elseif k == "right" and not rolling and not flipping then setTab(tab % 3 + 1)
  elseif k == "left" and not rolling and not flipping then setTab((tab + 1) % 3 + 1)
  elseif k == "escape" then held = {} end
end

function app.menu()
  return {
    {title = TR("app_name"), items = {
      {label = TR("roll"), id = 1, shortcut = "Space"},
      {label = TR("flip"), id = 2, shortcut = "C"},
      "-",
      {label = TR("more_dice"), id = 3, shortcut = "Up"},
      {label = TR("fewer_dice"), id = 4, shortcut = "Down"},
      {label = TR("release_all"), id = 5, shortcut = "Esc"},
      "-",
      {label = sound and TR("sound_off") or TR("sound_on"), id = 6},
      {label = vibrate and TR("vibrate_off") or TR("vibrate_on"), id = 7},
    }},
    {title = TR("history"), items = {
      {label = TR("copy_result"), id = 9, shortcut = "Ctrl+C"},
      {label = TR("export"), id = 10, shortcut = "Ctrl+S"},
      "-",
      {label = TR("clear_history"), id = 8},
      {label = TR("undo_clear"), id = 11, shortcut = "Ctrl+Z"},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then roll() elseif id == 2 then flip()
  elseif id == 3 then setCount(count + 1) elseif id == 4 then setCount(count - 1)
  elseif id == 5 then held = {}
  elseif id == 6 then sound = not sound; store.set("sound", sound)
  elseif id == 7 then vibrate = not vibrate; store.set("vibrate", vibrate)
  elseif id == 8 then clearHistory()
  elseif id == 9 then copyResult()
  elseif id == 10 then exportHistory()
  elseif id == 11 then undoClearHistory() end
end

function app.close()
  store.save()
  return true
end

return app
