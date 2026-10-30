-- Game of Life: Conway's cellular automaton on a wrap-around grid. Draw cells with touch or the cursor, place classic
-- patterns, switch rules (Life, HighLife, Seeds, Day & Night), watch the population chart and keep three save slots.
local app = {}

local SIZES = {{48, 30}, {64, 40}, {96, 60}, {128, 80}}
local RULES = {
  {name = "Conway (B3/S23)", b = {3}, s = {2, 3}},
  {name = "HighLife (B36/S23)", b = {3, 6}, s = {2, 3}},
  {name = "Seeds (B2/S)", b = {2}, s = {}},
  {name = "Day & Night (B3678/S34678)", b = {3, 6, 7, 8}, s = {3, 4, 6, 7, 8}},
}
local PATTERNS = {
  {key = "pat_glider", rows = {".O.", "..O", "OOO"}},
  {key = "pat_lwss", rows = {".O..O", "O....", "O...O", "OOOO."}},
  {key = "pat_pulsar", rows = {"..OOO...OOO..", ".............", "O....O.O....O", "O....O.O....O", "O....O.O....O",
    "..OOO...OOO..", ".............", "..OOO...OOO..", "O....O.O....O", "O....O.O....O", "O....O.O....O",
    ".............", "..OOO...OOO.."}},
  {key = "pat_penta", rows = {"..O....O..", "OO.OOOO.OO", "..O....O.."}},
  {key = "pat_gun", rows = {"........................O...........", "......................O.O...........",
    "............OO......OO............OO", "...........O...O....OO............OO",
    "OO........O.....O...OO..............", "OO........O...O.OO....O.O...........",
    "..........O.....O.......O...........", "...........O...O....................",
    "............OO......................"}},
  {key = "pat_rpent", rows = {".OO", "OO.", ".O."}},
  {key = "pat_acorn", rows = {".O.....", "...O...", "OO..OOO"}},
  {key = "pat_diehard", rows = {"......O.", "OO......", ".O...OOO"}},
}
-- cell colors by age: newborn, young, adult, old
local AGE_COLORS = {"#FFD60A", "#30D158", "#0A84FF", "#5E5CE6"}

local W, H = 64, 40
local cells, nxt, age = {}, {}, {}
local birth, survive = {}, {}
local sizeSel, ruleSel, patSel = 2, 1, 1
local running, speed, acc = false, 10, 0
local gen, pop, peak = 0, 0, 0
local hist, histN = {}, 0          -- population history ring (last 160 generations)
local undoBoard = nil
local canvas = {x = 0, y = 0, cs = 8}
local painting, paintValue = false, 1
local toast, toastT = "", 0

-- ------------------------------------------------------------------ board
local function alloc()
  cells, nxt, age = {}, {}, {}
  for i = 1, W * H do cells[i], nxt[i], age[i] = 0, 0, 0 end
end

local function setRule(i)
  ruleSel = i
  birth, survive = {}, {}
  for n = 0, 8 do birth[n], survive[n] = 0, 0 end
  for _, n in ipairs(RULES[i].b) do birth[n] = 1 end
  for _, n in ipairs(RULES[i].s) do survive[n] = 1 end
end

local function recount()
  pop = 0
  for i = 1, W * H do pop = pop + cells[i] end
end

local function resetStats()
  gen, peak, hist, histN = 0, pop, {}, 0
end

local function snapshot()
  local live = {}
  for i = 1, W * H do if cells[i] == 1 then live[#live + 1] = i end end
  return {w = W, h = H, live = live, gen = gen}
end

local function restore(b)
  if type(b) ~= "table" or type(b.live) ~= "table" then return false end
  local found = 1
  for i, s in ipairs(SIZES) do if s[1] == b.w and s[2] == b.h then found = i end end
  sizeSel = found
  W, H = SIZES[found][1], SIZES[found][2]
  alloc()
  for _, i in ipairs(b.live) do
    i = tonumber(i)
    if i and i >= 1 and i <= W * H then cells[i], age[i] = 1, 3 end
  end
  recount()
  resetStats()
  gen = tonumber(b.gen) or 0
  return true
end

local function saveBoard() store.set("board", snapshot()) end

local function remember() undoBoard = snapshot() end

local function step()
  local c, n, a = cells, nxt, age
  local bw, sv = birth, survive
  local p = 0
  for y = 0, H - 1 do
    local ym, y0, yp = ((y - 1) % H) * W + 1, y * W + 1, ((y + 1) % H) * W + 1
    for x = 0, W - 1 do
      local xm, xp = (x - 1) % W, (x + 1) % W
      local k = c[ym + xm] + c[ym + x] + c[ym + xp] + c[y0 + xm] + c[y0 + xp] + c[yp + xm] + c[yp + x] + c[yp + xp]
      local i = y0 + x
      local v = c[i] == 1 and sv[k] or bw[k]
      n[i] = v
      if v == 1 then a[i] = a[i] + 1; p = p + 1 else a[i] = 0 end
    end
  end
  cells, nxt = n, c
  gen, pop = gen + 1, p
  if p > peak then peak = p end
  histN = histN + 1
  hist[(histN - 1) % 160 + 1] = p
end

local function clearBoard()
  remember()
  running = false
  for i = 1, W * H do cells[i], age[i] = 0, 0 end
  pop = 0
  resetStats()
  saveBoard()
end

local function randomize()
  remember()
  for i = 1, W * H do
    local v = math.random() < 0.28 and 1 or 0
    cells[i], age[i] = v, v
  end
  recount()
  resetStats()
  saveBoard()
end

local function placePattern(idx)
  local p = PATTERNS[idx]
  if not p then return end
  remember()
  local ph, pw = #p.rows, #p.rows[1]
  local ox, oy = (W - pw) // 2, (H - ph) // 2
  for r, row in ipairs(p.rows) do
    for col = 1, #row do
      if row:sub(col, col) == "O" then
        local x, y = (ox + col - 1) % W, (oy + r - 1) % H
        local i = y * W + x + 1
        cells[i], age[i] = 1, 1
      end
    end
  end
  recount()
  saveBoard()
  audio.play("pop")
end

local function setSize(i)
  if i == sizeSel and #cells == W * H then return end
  remember()
  sizeSel = i
  W, H = SIZES[i][1], SIZES[i][2]
  alloc()
  pop = 0
  resetStats()
  store.set("size", i)
  saveBoard()
end

local function undo()
  if not undoBoard then return end
  local b = undoBoard
  undoBoard = nil
  restore(b)
  running = false
  saveBoard()
end

local function showToast(s) toast, toastT = s, 2 end

-- ------------------------------------------------------------------ callbacks
function app.load()
  math.randomseed(math.floor(sys.epoch()))
  setRule(math.max(1, math.min(#RULES, store.get("rule", 1))))
  speed = math.max(1, math.min(60, store.get("speed", 10)))
  sizeSel = math.max(1, math.min(#SIZES, store.get("size", 2)))
  W, H = SIZES[sizeSel][1], SIZES[sizeSel][2]
  if not restore(store.get("board", nil)) then
    W, H = SIZES[sizeSel][1], SIZES[sizeSel][2]
    alloc()
    placePattern(5)      -- first run: the glider gun shows what the app does
    undoBoard = nil
  end
end

function app.update(dt)
  if toastT > 0 then toastT = toastT - dt end
  if not running then return end
  acc = acc + dt
  local stepT = 1 / speed
  local n = 0
  while acc >= stepT and n < 2 do acc = acc - stepT; step(); n = n + 1 end
  if acc > stepT then acc = 0 end
  if pop == 0 then running = false; showToast(TR("extinct", gen)) end
end

local function cellAt(px, py)
  local cs = canvas.cs
  local x, y = math.floor((px - canvas.x) / cs), math.floor((py - canvas.y) / cs)
  if x < 0 or y < 0 or x >= W or y >= H then return nil end
  return y * W + x + 1
end

local function paintAt(px, py)
  local i = cellAt(px, py)
  if not i then return end
  if cells[i] ~= paintValue then
    cells[i] = paintValue
    age[i] = paintValue
    pop = pop + (paintValue == 1 and 1 or -1)
    if pop > peak then peak = pop end
  end
end

local function drawBoard(x0, y0, cw, ch)
  local cs = math.max(2, math.floor(math.min(cw / W, ch / H)))
  local bw, bh = cs * W, cs * H
  local x, y = x0 + (cw - bw) // 2, y0 + (ch - bh) // 2
  canvas.x, canvas.y, canvas.cs = x, y, cs
  gfx.rect(x - 4, y - 4, bw + 8, bh + 8, 10, theme.dark and "#0E0E10" or "#F4F4F7")
  if cs >= 6 then
    gfx.color(theme.dark and "#FFFFFF10" or "#00000010")
    for gx = 0, W do gfx.line(x + gx * cs, y, x + gx * cs, y + bh, 1) end
    for gy = 0, H do gfx.line(x, y + gy * cs, x + bw, y + gy * cs, 1) end
  end
  local pad = cs >= 6 and 1 or 0
  local rad = cs >= 8 and 2 or 0
  -- merge horizontal runs of cells with the same age color into one rectangle
  for row = 0, H - 1 do
    local base = row * W
    local runStart, runCol = nil, 0
    for col = 0, W do
      local bucket = 0
      if col < W and cells[base + col + 1] == 1 then
        local a = age[base + col + 1]
        bucket = a <= 1 and 1 or a <= 4 and 2 or a <= 15 and 3 or 4
      end
      if bucket ~= runCol then
        if runCol > 0 then
          gfx.rect(x + runStart * cs + pad, y + row * cs + pad, (col - runStart) * cs - pad * 2, cs - pad * 2, rad, AGE_COLORS[runCol])
        end
        runStart, runCol = col, bucket
      end
    end
  end
  if pop == 0 and not running then
    gfx.icon("grid_on", x + bw / 2, y + bh / 2 - 22, 44, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("empty"), x, y + bh / 2 + 6, 14, "sans", "center", bw)
  end
end

local function drawChart(x, y, w, h)
  ui.group(x, y, w, h)
  local n = math.min(histN, 160)
  if n < 2 then return end
  local mx = 1
  for i = 1, n do mx = math.max(mx, hist[i] or 0) end
  local pts = {}
  for k = 0, n - 1 do
    local idx = (histN - n + k) % 160 + 1
    pts[#pts + 1] = x + 6 + k * (w - 12) / 159
    pts[#pts + 1] = y + h - 5 - (hist[idx] or 0) / mx * (h - 10)
  end
  gfx.color(theme.accent)
  gfx.lines(pts, 2)
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  -- top bar: controls, speed, stats
  local bx = 16
  if ui.iconButton(running and "pause" or "play_arrow", bx, 10, 36, 34, running and theme.orange or theme.green, running) then
    running = not running
    if not running then saveBoard() end
  end
  if ui.iconButton("skip_next", bx + 40, 10, 36, 34) then running = false; step(); saveBoard() end
  if ui.iconButton("shuffle", bx + 80, 10, 36, 34) then randomize() end
  if ui.iconButton("delete", bx + 120, 10, 36, 34, theme.red) then clearBoard() end
  if ui.iconButton("undo", bx + 160, 10, 36, 34, nil, false, "und") then undo() end
  gfx.color(theme.text2)
  gfx.text(TR("speed", speed), bx + 208, 19, 12)
  local sw = math.max(80, math.min(200, w - 520))
  local sp = ui.slider("speed", speed, 1, 60, bx + 278, 18, sw, 1)
  if sp ~= speed then speed = sp; store.set("speed", speed) end
  gfx.color(theme.text)
  gfx.text(TR("gen", gen) .. "   " .. TR("pop", pop), 0, 12, 13, "semibold", "right", w - 16)
  gfx.color(theme.text3)
  gfx.text(TR("peak", peak), 0, 30, 11, "sans", "right", w - 16)

  -- board
  local by = 56
  local bottomH = 50
  drawBoard(16, by, w - 32, h - by - bottomH - 12)

  -- bottom bar: pattern, rule, size, population chart
  local y = h - bottomH
  local labels = {}
  for i, p in ipairs(PATTERNS) do labels[i] = TR(p.key) end
  patSel = ui.dropdown("pat", labels, patSel, 16, y + 8, 150, 32)
  if ui.button(TR("place"), 172, y + 8, 80, 32, "default", "add") then placePattern(patSel) end
  local rl = {}
  for i, r in ipairs(RULES) do rl[i] = r.name end
  local nr = ui.dropdown("rule", rl, ruleSel, 262, y + 8, 150, 32)
  if nr ~= ruleSel then setRule(nr); store.set("rule", nr) end
  local sl = {}
  for i, s in ipairs(SIZES) do sl[i] = s[1] .. "×" .. s[2] end
  local ns = ui.dropdown("size", sl, sizeSel, 420, y + 8, 100, 32)
  if ns ~= sizeSel then setSize(ns) end
  if w - 16 - 530 >= 60 then drawChart(530, y + 8, w - 16 - 530, 32) end

  if toastT > 0 then
    local tw = gfx.textWidth(toast, 13) + 32
    gfx.alpha(math.min(1, toastT * 3))
    gfx.rect(w / 2 - tw / 2, h - bottomH - 46, tw, 32, 16, "#1C1C1EE6")
    gfx.color("#FFFFFF")
    gfx.text(toast, w / 2 - tw / 2, h - bottomH - 38, 13, "semibold", "center", tw)
    gfx.unalpha()
  end
end

function app.event(e)
  if e.type == "mousedown" and e.button == "left" then
    local i = cellAt(e.x, e.y)
    if i then
      remember()
      painting = true
      paintValue = cells[i] == 1 and 0 or 1
      paintAt(e.x, e.y)
    end
  elseif e.type == "mousemove" and painting then
    paintAt(e.x, e.y)
  elseif e.type == "mouseup" then
    if painting then painting = false; saveBoard() end
  elseif e.type == "keydown" then
    local k = e.key
    if k == "space" then running = not running; if not running then saveBoard() end
    elseif k == "n" or k == "right" then running = false; step()
    elseif k == "r" then randomize()
    elseif k == "c" or k == "delete" then clearBoard()
    elseif k == "z" and e.ctrl then undo()
    elseif k == "up" then speed = math.min(60, speed + 1); store.set("speed", speed)
    elseif k == "down" then speed = math.max(1, speed - 1); store.set("speed", speed)
    elseif k == "enter" then placePattern(patSel) end
  end
end

function app.menu()
  local slots, loads = {}, {}
  for i = 1, 3 do
    slots[i] = {label = TR("save_slot", i), id = 10 + i}
    loads[i] = {label = TR("load_slot", i), id = 20 + i, enabled = store.get("slot" .. i, nil) ~= nil}
  end
  return {
    {title = TR("app_name"), items = {
      {label = TR("play_pause"), id = 1, shortcut = "Space"},
      {label = TR("step"), id = 2, shortcut = "N"},
      {label = TR("random"), id = 3, shortcut = "R"},
      {label = TR("clear"), id = 4, shortcut = "C"},
      {label = TR("undo"), id = 5, shortcut = "Ctrl+Z"},
    }},
    {title = TR("slots"), items = {slots[1], slots[2], slots[3], "-", loads[1], loads[2], loads[3]}},
  }
end

function app.onmenu(id)
  if id == 1 then running = not running
  elseif id == 2 then running = false; step()
  elseif id == 3 then randomize()
  elseif id == 4 then clearBoard()
  elseif id == 5 then undo()
  elseif id > 10 and id < 14 then
    store.set("slot" .. (id - 10), snapshot())
    showToast(TR("saved", id - 10))
  elseif id > 20 and id < 24 then
    local b = store.get("slot" .. (id - 20), nil)
    if b then remember(); running = false; restore(b); saveBoard(); showToast(TR("loaded", id - 20)) end
  end
end

function app.close()
  saveBoard()
  store.save()
  return true
end

return app
