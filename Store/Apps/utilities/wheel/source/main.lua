-- Decision Wheel: saved wheels of options, a physics-ish spin with ticks, drag-to-spin, a winner banner with
-- confetti, optional removal of the winner and a results chart per wheel.
local app = {}

-- fills {0}, {1}… with plain text (user text may contain "%", which TR's own substitution must not see)
local function fmt(s, ...)
  local a = {...}
  return (s:gsub("{(%d)}", function(i) local v = a[tonumber(i) + 1]; if v ~= nil then return tostring(v) end end))
end

local floor, min, max, abs, sin, cos, pi, atan = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi, math.atan
local TAU = pi * 2
local POINTER = -pi / 2          -- the pointer sits at the top of the wheel

local PALETTE = {"#FF6B6B", "#FFA94D", "#FFD43B", "#69DB7C", "#38D9A9", "#4DABF7",
                 "#748FFC", "#9775FA", "#DA77F2", "#F783AC", "#20C997", "#FF922B"}
local MAX_ITEMS, MAX_LEN = 24, 32

local wheels = {}                -- {name, items = {...}, removeWinner, results = {name = count}}
local cur = 1
local tab = 1                    -- side panel: 1 options, 2 results
local rot, omega = 0, 0          -- wheel angle and angular speed (rad/s)
local spinning = false
local lastSeg = -1
local flick = 0                  -- pointer kick after each tick
local dragging, dragA, dragVel, dragMoved = false, 0, 0, 0
local winner, bannerT = nil, 0   -- winner text and banner age
local pendingRemove = nil
local lastDt = 1 / 60
local sound = true
local toast, toastT, undoItem = "", 0, nil
local confetti = {}
local pts = {}
local resultsCache, resultsDirty = {}, true

local function trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

local function utrunc(s, n)
  local len = utf8.len(s) or #s
  if len <= n then return s end
  local cut = utf8.offset(s, n + 1)
  return (cut and s:sub(1, cut - 1) or s) .. "…"
end

local function wheel()
  local w = wheels[cur]
  if not w then
    cur = 1
    w = wheels[1]
  end
  return w
end

local function save()
  store.set("wheels", wheels)
  store.set("cur", cur)
  resultsDirty = true
end

local function showToast(s, undo) toast, toastT, undoItem = s, undo and 5 or 2.2, undo end

local function defaults()
  local function split(s)
    local t = {}
    for part in s:gmatch("[^,]+") do t[#t + 1] = trim(part) end
    return t
  end
  return {
    {name = TR("def_food"), items = split(TR("def_food_items")), removeWinner = false, results = {}},
    {name = TR("def_who"), items = split(TR("def_who_items")), removeWinner = false, results = {}},
    {name = TR("def_yesno"), items = split(TR("def_yesno_items")), removeWinner = false, results = {}},
  }
end

local function segColor(i, n)
  local c = PALETTE[(i - 1) % #PALETTE + 1]
  if i == n and n > 1 and (n - 1) % #PALETTE == 0 then c = PALETTE[6] end  -- avoid two equal neighbours
  return c
end

-- index of the option under the pointer for the current rotation
local function segmentAt(n)
  if n <= 0 then return 0 end
  local seg = TAU / n
  local rel = (POINTER - rot) % TAU
  return floor(rel / seg) % n + 1
end

local function startSpin(speed)
  local w = wheel()
  if not w or #w.items < 2 or spinning then return end
  if pendingRemove then
    for i, it in ipairs(w.items) do
      if it == pendingRemove then
        if #w.items > 2 then table.remove(w.items, i) end
        break
      end
    end
    pendingRemove = nil
    save()
  end
  if #w.items < 2 then return end
  winner, bannerT = nil, 0
  omega = speed or ((math.random() * 8 + 14) * (math.random() < 0.15 and -1 or 1))
  spinning = true
  lastSeg = segmentAt(#w.items)
end

local function finishSpin()
  spinning, omega = false, 0
  local w = wheel()
  if not w or #w.items == 0 then return end
  local idx = segmentAt(#w.items)
  winner = w.items[idx]
  bannerT = 0
  if type(w.results) ~= "table" then w.results = {} end
  w.results[winner] = (tonumber(w.results[winner]) or 0) + 1
  if w.removeWinner and #w.items > 2 then pendingRemove = winner end
  save()
  -- confetti burst from the hub
  for i = 1, 70 do
    local a, s = math.random() * TAU, 120 + math.random() * 320
    confetti[i] = {x = 0, y = 0, vx = cos(a) * s, vy = sin(a) * s - 160, life = 1.4 + math.random() * 0.8,
                   c = PALETTE[math.random(#PALETTE)], r = 3 + math.random() * 3}
  end
  if sound then
    audio.tone(784, 0.1, 0.3, "triangle")
    timer.after(0.1, function() audio.tone(1047, 0.18, 0.3, "triangle") end)
  end
  sys.vibrate(0.5, 90)
end

-- ------------------------------------------------------------------ editing
local function addItem()
  local w = wheel()
  if not w then return end
  if #w.items >= MAX_ITEMS then showToast(TR("too_many", MAX_ITEMS)); return end
  ui.prompt(TR("add_option"), TR("add_msg"), "", function(s)
    s = trim(s)
    if s == "" then return end
    if (utf8.len(s) or #s) > MAX_LEN then showToast(TR("too_long", MAX_LEN)); return end
    if #w.items >= MAX_ITEMS then return end
    w.items[#w.items + 1] = s
    save()
  end)
end

local function renameItem(i)
  local w = wheel()
  if not w or not w.items[i] then return end
  ui.prompt(TR("rename_option"), TR("add_msg"), w.items[i], function(s)
    s = trim(s)
    if s == "" or not w.items[i] then return end
    if (utf8.len(s) or #s) > MAX_LEN then showToast(TR("too_long", MAX_LEN)); return end
    w.items[i] = s
    save()
  end)
end

local function deleteItem(i)
  local w = wheel()
  if not w or not w.items[i] or spinning then return end
  local text = table.remove(w.items, i)
  save()
  showToast(fmt(TR("deleted"), utrunc(text, 18)), {wheel = w, index = i, text = text})
end

local function undoDelete()
  local u = undoItem
  if not u or not u.wheel then return end
  local items = u.wheel.items
  if #items < MAX_ITEMS then
    table.insert(items, min(u.index, #items + 1), u.text)
    save()
  end
  undoItem, toastT = nil, 0
end

local function sortItems()
  local w = wheel()
  if not w or spinning then return end
  table.sort(w.items, function(a, b) return a:lower() < b:lower() end)
  save()
end

local function shuffleItems()
  local w = wheel()
  if not w or spinning then return end
  for i = #w.items, 2, -1 do
    local j = math.random(1, i)
    w.items[i], w.items[j] = w.items[j], w.items[i]
  end
  save()
end

local function newWheel()
  ui.prompt(TR("new_wheel"), TR("wheel_name_msg"), "", function(s)
    s = trim(s)
    if s == "" then return end
    wheels[#wheels + 1] = {name = utrunc(s, MAX_LEN), items = {}, removeWinner = false, results = {}}
    cur = #wheels
    winner, pendingRemove = nil, nil
    save()
  end)
end

local function renameWheel()
  local w = wheel()
  if not w then return end
  ui.prompt(TR("rename_wheel"), TR("wheel_name_msg"), w.name, function(s)
    s = trim(s)
    if s == "" then return end
    w.name = utrunc(s, MAX_LEN)
    save()
  end)
end

local function deleteWheel()
  if #wheels <= 1 or spinning then return end
  local w = wheel()
  ui.alert(TR("delete_wheel"), fmt(TR("delete_wheel_msg"), w and w.name or ""), {TR("delete"), TR("common.cancel")}, function(b)
    if b ~= 1 or #wheels <= 1 then return end
    table.remove(wheels, cur)
    cur = max(1, min(cur, #wheels))
    winner, pendingRemove = nil, nil
    save()
  end)
end

local function selectWheel(i)
  if spinning or not wheels[i] or i == cur then return end
  cur = i
  winner, pendingRemove = nil, nil
  store.set("cur", cur)
  resultsDirty = true
end

local function copyWinner()
  if not winner then showToast(TR("no_winner")); return end
  sys.clipboard(winner)
  showToast(fmt(TR("copied"), utrunc(winner, 20)))
end

-- results of the current wheel sorted by count, rebuilt only when they change
local function results()
  if resultsDirty then
    resultsCache = {}
    local w = wheel()
    if w and type(w.results) == "table" then
      for k, v in pairs(w.results) do resultsCache[#resultsCache + 1] = {name = tostring(k), n = tonumber(v) or 0} end
    end
    table.sort(resultsCache, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.name < b.name end)
    resultsDirty = false
  end
  return resultsCache
end

local function copyResults()
  local r = results()
  if #r == 0 then showToast(TR("no_results")); return end
  local lines = {(wheel() or {}).name or ""}
  for _, e in ipairs(r) do lines[#lines + 1] = e.name .. ": " .. e.n end
  sys.clipboard(table.concat(lines, "\n"))
  showToast(TR("results_copied"))
end

local function clearResults()
  local w = wheel()
  if not w then return end
  ui.alert(TR("clear_results"), TR("clear_results_msg"), {TR("clear"), TR("common.cancel")}, function(b)
    if b == 1 then w.results = {}; save() end
  end)
end

-- ------------------------------------------------------------------ app
function app.load(arg)
  local w = store.get("wheels", nil)
  wheels = {}
  if type(w) == "table" then
    for _, x in ipairs(w) do
      if type(x) == "table" and type(x.items) == "table" then
        local items = {}
        for _, it in ipairs(x.items) do if type(it) == "string" and it ~= "" then items[#items + 1] = it end end
        wheels[#wheels + 1] = {name = tostring(x.name or "?"), items = items, removeWinner = x.removeWinner == true,
                               results = type(x.results) == "table" and x.results or {}}
      end
    end
  end
  if #wheels == 0 then wheels = defaults() end
  cur = max(1, min(#wheels, floor(tonumber(store.get("cur", 1)) or 1)))
  sound = store.get("sound", true) ~= false
  rot = math.random() * TAU
end

function app.update(dt)
  lastDt = dt
  flick = flick * math.exp(-dt * 10)
  toastT = max(0, toastT - dt)
  if toastT == 0 then undoItem = nil end
  if winner then bannerT = bannerT + dt end
  local w = wheel()
  local n = w and #w.items or 0
  if spinning then
    rot = (rot + omega * dt) % TAU
    -- constant friction plus drag proportional to speed: long glide, gentle stop
    local s = abs(omega) - (0.9 + abs(omega) * 0.5) * dt
    if s <= 0.04 or n < 2 then finishSpin() else omega = s * (omega < 0 and -1 or 1) end
  end
  if n >= 2 and (spinning or dragging) then
    local sgi = segmentAt(n)
    if sgi ~= lastSeg then
      lastSeg = sgi
      flick = min(0.6, flick + 0.35)
      if sound then audio.tone(1400, 0.015, 0.14, "square") end
    end
  end
  for i = #confetti, 1, -1 do
    local p = confetti[i]
    p.life = p.life - dt
    if p.life <= 0 then table.remove(confetti, i)
    else
      p.vy = p.vy + 520 * dt
      p.vx = p.vx * (1 - dt * 1.5)
      p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
    end
  end
end

local function drawPointer(cx, top)
  -- a triangle hanging over the rim, rotated by the tick "flick"
  local a = flick * (omega >= 0 and -1 or 1)
  local ca, sa = cos(a), sin(a)
  local function p(i, x, y) pts[i] = cx + x * ca - y * sa; pts[i + 1] = top + x * sa + y * ca end
  p(1, -15, -6); p(3, 15, -6); p(5, 0, 26)
  for i = #pts, 7, -1 do pts[i] = nil end
  gfx.shadow(cx - 15, top - 6, 30, 24, 8, 8, 3)
  gfx.poly(pts, theme.red)
  gfx.circle(cx, top - 2, 6, "#FFFFFF")
end

local function drawWheel(cx, cy, R)
  local w = wheel()
  local items = w and w.items or {}
  local n = #items
  gfx.shadow(cx - R, cy - R, R * 2, R * 2, R, 24, 8)
  gfx.color(theme.dark and "#2C2C2E" or "#FFFFFF")
  gfx.circle(cx, cy, R + 8)
  if n < 2 then
    gfx.color(theme.field)
    gfx.circle(cx, cy, R)
    gfx.color(theme.separator)
    gfx.circleLine(cx, cy, R, 2)
    gfx.icon("donut_large", cx, cy - 26, 56, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("need_two"), cx - R * 0.8, cy + 14, 14, "semibold", "center", R * 1.6)
    gfx.color(theme.text3)
    gfx.wrap(TR("need_two_hint"), cx - R * 0.7, cy + 36, R * 1.4, 12, "sans", "center")
    return
  end
  local seg = TAU / n
  for i = 1, n do
    gfx.color(segColor(i, n))
    gfx.pie(cx, cy, R, rot + (i - 1) * seg, rot + i * seg)
  end
  -- separators between segments
  gfx.color("#FFFFFF66")
  for i = 1, n do
    local a = rot + (i - 1) * seg
    gfx.line(cx, cy, cx + cos(a) * R, cy + sin(a) * R, 1.5)
  end
  -- labels stay horizontal; fewer characters and an outer radius when segments get narrow
  local maxc = n <= 6 and 12 or (n <= 12 and 7 or 3)
  local lr = n <= 12 and R * 0.62 or R * 0.8
  local fsz = n <= 6 and max(12, min(17, R * 0.09)) or (n <= 12 and 12 or 11)
  for i = 1, n do
    local a = rot + (i - 0.5) * seg
    local lx, ly = cx + cos(a) * lr, cy + sin(a) * lr
    local label = utrunc(items[i], maxc)
    gfx.color("#00000059")
    gfx.text(label, lx - 70 + 1, ly - fsz * 0.62 + 1, fsz, "bold", "center", 140)
    gfx.color("#FFFFFF")
    gfx.text(label, lx - 70, ly - fsz * 0.62, fsz, "bold", "center", 140)
  end
  gfx.color("#FFFFFFAA")
  gfx.circleLine(cx, cy, R, 3)
  -- hub
  gfx.shadow(cx - R * 0.14, cy - R * 0.14, R * 0.28, R * 0.28, R * 0.14, 10, 3)
  gfx.circle(cx, cy, max(14, R * 0.14), "#FFFFFF")
  gfx.icon("rotate_right", cx, cy, max(16, R * 0.15), spinning and theme.text3 or "#3A3A3C")
end

local function drawBanner(cx, cy, R)
  if not winner then return end
  local t = min(1, bannerT / 0.45)
  local s = 1 + 2.70158 * (t - 1) ^ 3 + 1.70158 * (t - 1) ^ 2   -- ease out back
  local bw, bh = min(R * 1.9, 320) * s, 92 * s
  if bw < 10 then return end
  local x, y = cx - bw / 2, cy - bh / 2
  gfx.alpha(min(1, t * 2))
  gfx.shadow(x, y, bw, bh, 18, 20, 6)
  gfx.color(theme.dark and "#1C1C1EF0" or "#FFFFFFF2")
  gfx.rect(x, y, bw, bh, 18)
  if t >= 1 then
    gfx.color(theme.text2)
    gfx.text(TR("winner"), x, y + 12, 12, "semibold", "center", bw)
    gfx.color(theme.text)
    gfx.text(utrunc(winner, 22), x + 8, y + 32, 24, "bold", "center", bw - 16)
    if pendingRemove then
      gfx.color(theme.text3)
      gfx.text(TR("will_remove"), x, y + 66, 11, "sans", "center", bw)
    end
  end
  gfx.unalpha()
  if t >= 1 and ui.iconButton("content_copy", x + bw - 38, y + 6, 32, 30) then copyWinner() end
end

local function drawConfetti(cx, cy)
  for _, p in ipairs(confetti) do
    gfx.alpha(min(1, p.life))
    gfx.rect(cx + p.x - p.r, cy + p.y - p.r * 0.5, p.r * 2, p.r, 1, p.c)
    gfx.unalpha()
  end
end

local function wheelInput(cx, cy, R)
  local hit = ui.hit("wheel", cx - R, cy - R, R * 2, R * 2)
  local mx, my = ui.mouse()
  local a = atan((my or cy) - cy, (mx or cx) - cx)
  if hit.pressed and not spinning and not dragging then
    dragging, dragA, dragVel, dragMoved = true, a, 0, 0
  elseif dragging then
    if hit.held then
      local d = (a - dragA + pi) % TAU - pi
      rot = (rot + d) % TAU
      dragMoved = dragMoved + abs(d)
      dragVel = dragVel * 0.5 + (d / max(lastDt, 0.001)) * 0.5
      dragA = a
    else
      dragging = false
      if dragMoved > 0.25 and abs(dragVel) > 3 then
        local s = max(8, min(30, abs(dragVel) * 1.4))
        startSpin(dragVel < 0 and -s or s)
      elseif dragMoved < 0.05 then
        if winner and bannerT > 0.3 then winner = nil else startSpin() end
      end
    end
  end
end

local function drawOptions(px, py, pw, ph)
  local w = wheel()
  local items = w and w.items or {}
  local n = #items
  local by = py + ph - 36
  if ui.button(TR("add") .. "##add", px, by, pw - 80, 34, "default", "add", n < MAX_ITEMS and not spinning) then addItem() end
  if ui.iconButton("sort_by_alpha", px + pw - 74, by + 1, 34, 32) then sortItems() end
  if ui.iconButton("shuffle", px + pw - 36, by + 1, 34, 32) then shuffleItems() end
  local lh = ph - 44
  if n == 0 then
    gfx.icon("playlist_add", px + pw / 2, py + lh / 2 - 24, 48, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("no_options"), px, py + lh / 2 + 10, 14, "semibold", "center", pw)
    gfx.color(theme.text3)
    gfx.text(TR("no_options_hint"), px, py + lh / 2 + 32, 12, "sans", "center", pw)
    return
  end
  local rowH = 36
  local hl = (winner and not spinning) and winner or nil
  ui.beginScroll("opts", px, py, pw, lh, n * rowH)
  for i, it in ipairs(items) do
    local ry = (i - 1) * rowH
    if hl == it then
      gfx.alpha(0.2)
      gfx.rect(0, ry + 2, pw, rowH - 4, 8, theme.selection)
      gfx.unalpha()
    end
    gfx.circle(16, ry + rowH / 2, 7, segColor(i, n))
    gfx.color(theme.text)
    gfx.text(utrunc(it, 20), 32, ry + 9, 14)
    if ui.iconButton("edit", pw - 70, ry + 3, 32, 30, theme.text2, false, "e" .. i) then renameItem(i) end
    if ui.iconButton("close", pw - 36, ry + 3, 32, 30, theme.text2, false, "d" .. i) then deleteItem(i) end
  end
  ui.endScroll()
end

local function drawResults(px, py, pw, ph)
  local r = results()
  local by = py + ph - 36
  if ui.button(TR("copy") .. "##res", px, by, (pw - 8) / 2, 34, "default", "content_copy", #r > 0) then copyResults() end
  if ui.button(TR("clear") .. "##res", px + (pw + 8) / 2, by, (pw - 8) / 2, 34, "default", "delete", #r > 0) then clearResults() end
  local lh = ph - 44
  if #r == 0 then
    gfx.icon("bar_chart", px + pw / 2, py + lh / 2 - 24, 48, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("no_results"), px, py + lh / 2 + 10, 14, "semibold", "center", pw)
    gfx.color(theme.text3)
    gfx.text(TR("no_results_hint"), px, py + lh / 2 + 32, 12, "sans", "center", pw)
    return
  end
  local totalSpins, top = 0, r[1].n
  for _, e in ipairs(r) do totalSpins = totalSpins + e.n end
  gfx.color(theme.text2)
  gfx.text(TR("spins_total", totalSpins), px, py, 12, "semibold")
  local rowH = 40
  ui.beginScroll("res", px, py + 22, pw, lh - 22, #r * rowH)
  for i, e in ipairs(r) do
    local ry = (i - 1) * rowH
    gfx.color(theme.text)
    gfx.text(utrunc(e.name, 22), 0, ry + 2, 13)
    gfx.color(theme.text2)
    local pct = floor(e.n * 100 / max(1, totalSpins) + 0.5)
    gfx.text(e.n .. " · " .. pct .. "%", 0, ry + 2, 12, "sans", "right", pw - 4)
    gfx.color(theme.separator)
    gfx.rect(0, ry + 22, pw - 4, 8, 4)
    gfx.color(PALETTE[(i - 1) % #PALETTE + 1])
    gfx.rect(0, ry + 22, max(8, (pw - 4) * e.n / max(1, top)), 8, 4)
  end
  ui.endScroll()
end

local function drawToast(x, w, h)
  if toastT <= 0 then return end
  local a = min(1, toastT * 4)
  local tw = min(w - 40, gfx.textWidth(toast, 13, "semibold") + 36)
  local extra = undoItem and 76 or 0
  local tx, ty = x + (w - tw - extra) / 2, h - 58 + (1 - a) * 20
  gfx.alpha(a)
  gfx.shadow(tx, ty, tw + extra, 38, 19, 12, 4)
  gfx.color(theme.dark and "#3A3A3C" or "#1C1C1E")
  gfx.rect(tx, ty, tw + extra, 38, 19)
  gfx.color("#FFFFFF")
  gfx.text(toast, tx + 18, ty + 10, 13, "semibold")
  gfx.unalpha()
  if undoItem and ui.button(TR("undo"), tx + tw, ty + 4, 70, 30, "plain") then undoDelete() end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local pw = w >= 720 and 290 or 260
  local lw = w - 40 - pw - 20
  local wh = h - 16 - 66
  local R = max(60, min(lw, wh - 30) / 2 - 10)
  local cx, cy = 20 + lw / 2, 16 + 28 + R
  local wobj = wheel()

  drawWheel(cx, cy, R)
  drawPointer(cx, cy - R - 6)
  if wobj and #wobj.items >= 2 then wheelInput(cx, cy, R) end
  drawConfetti(cx, cy)
  drawBanner(cx, cy, R)

  -- under the wheel: remove-winner option and the spin button
  local by = h - 50
  if wobj then
    local rw = ui.checkbox(TR("remove_winner"), wobj.removeWinner == true, 20, by + 8)
    if rw ~= (wobj.removeWinner == true) then
      wobj.removeWinner = rw
      if not rw then pendingRemove = nil end
      save()
    end
  end
  local canSpin = wobj and #wobj.items >= 2 and not spinning
  if ui.button(TR("spin"), 20 + lw - 140, by, 140, 38, "primary", "rotate_right", canSpin) then startSpin() end

  -- side panel
  local px = w - 20 - pw
  gfx.color(theme.field)
  gfx.rect(px - 10, 12, pw + 20, h - 24, 14)
  local names = {}
  for i, x in ipairs(wheels) do names[i] = x.name end
  local ns = ui.dropdown("wheels", names, cur, px, 20, pw - 112, 32)
  if ns ~= cur then selectWheel(ns) end
  if ui.iconButton("add", px + pw - 106, 20, 34, 32) then newWheel() end
  if ui.iconButton("edit", px + pw - 70, 20, 34, 32, nil, false, "wheel") then renameWheel() end
  if ui.iconButton("delete", px + pw - 34, 20, 34, 32, #wheels > 1 and theme.red or theme.text3) then deleteWheel() end
  tab = ui.segmented("ptab", {TR("tab_options") .. " (" .. (wobj and #wobj.items or 0) .. ")", TR("tab_results")}, tab, px, 62, pw, 30)
  if tab == 1 then drawOptions(px, 104, pw, h - 104 - 20) else drawResults(px, 104, pw, h - 104 - 20) end

  drawToast(0, w, h)
end

function app.event(e)
  if e.type ~= "keydown" then return end
  local k = e.key
  if e.ctrl and k == "c" then copyWinner(); return end
  if e.ctrl and k == "z" then undoDelete(); return end
  if e.ctrl and k == "n" then newWheel(); return end
  if k == "space" or k == "enter" then startSpin()
  elseif k == "escape" then winner = nil
  elseif k == "a" or k == "n" then addItem()
  elseif k == "left" then selectWheel(cur - 1)
  elseif k == "right" then selectWheel(cur + 1)
  elseif k == "tab" then tab = 3 - tab end
end

function app.menu()
  return {
    {title = TR("app_name"), items = {
      {label = TR("spin"), id = 1, shortcut = "Space"},
      {label = TR("copy_winner"), id = 2, shortcut = "Ctrl+C"},
      "-",
      {label = sound and TR("sound_off") or TR("sound_on"), id = 3},
    }},
    {title = TR("menu_wheel"), items = {
      {label = TR("new_wheel"), id = 10, shortcut = "Ctrl+N"},
      {label = TR("rename_wheel"), id = 11},
      {label = TR("delete_wheel"), id = 12},
      "-",
      {label = TR("prev_wheel"), id = 13, shortcut = "Left"},
      {label = TR("next_wheel"), id = 14, shortcut = "Right"},
    }},
    {title = TR("menu_options"), items = {
      {label = TR("add_option"), id = 20, shortcut = "A"},
      {label = TR("sort"), id = 21},
      {label = TR("shuffle"), id = 22},
      {label = TR("undo_delete"), id = 23, shortcut = "Ctrl+Z"},
      "-",
      {label = TR("copy_results"), id = 24},
      {label = TR("clear_results"), id = 25},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then startSpin() elseif id == 2 then copyWinner()
  elseif id == 3 then sound = not sound; store.set("sound", sound)
  elseif id == 10 then newWheel() elseif id == 11 then renameWheel() elseif id == 12 then deleteWheel()
  elseif id == 13 then selectWheel(cur - 1) elseif id == 14 then selectWheel(cur + 1)
  elseif id == 20 then addItem() elseif id == 21 then sortItems() elseif id == 22 then shuffleItems()
  elseif id == 23 then undoDelete() elseif id == 24 then copyResults() elseif id == 25 then clearResults() end
end

function app.close()
  store.save()
  return true
end

return app
