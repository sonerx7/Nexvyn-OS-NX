-- Logic Lab for Nexvyn OS: build digital circuits and watch them run. Switches, buttons and clocks drive AND, OR,
-- NOT, NAND, NOR, XOR and XNOR gates, D flip-flops, LEDs and a hex display; wires light up with the signal. Truth
-- tables are generated for you. Ready-made circuits: half and full adder, a latch and a counter.
local K = require("kit")
local app = {}

local floor, min, max, abs, sqrt = math.floor, math.min, math.max, math.abs, math.sqrt
local clamp, alpha, mix = K.clamp, K.alpha, K.mix
local G = 20   -- grid step in world units

-- ================================================================== component types
-- w, h in grid steps; ins / outs = number of pins
local T = {
  switch = {ins = 0, outs = 1, w = 3, h = 2, key = "c_switch"},
  button = {ins = 0, outs = 1, w = 3, h = 2, key = "c_button"},
  clock  = {ins = 0, outs = 1, w = 3, h = 2, key = "c_clock"},
  led    = {ins = 1, outs = 0, w = 2, h = 2, key = "c_led"},
  seg7   = {ins = 4, outs = 0, w = 3, h = 5, key = "c_seg7"},
  ["and"] = {ins = 2, outs = 1, w = 3, h = 3, key = "c_and", sym = "&"},
  ["or"]  = {ins = 2, outs = 1, w = 3, h = 3, key = "c_or", sym = "≥1"},
  ["not"] = {ins = 1, outs = 1, w = 3, h = 2, key = "c_not", sym = "1", neg = true},
  nand   = {ins = 2, outs = 1, w = 3, h = 3, key = "c_nand", sym = "&", neg = true},
  nor    = {ins = 2, outs = 1, w = 3, h = 3, key = "c_nor", sym = "≥1", neg = true},
  xor    = {ins = 2, outs = 1, w = 3, h = 3, key = "c_xor", sym = "=1"},
  xnor   = {ins = 2, outs = 1, w = 3, h = 3, key = "c_xnor", sym = "=1", neg = true},
  dff    = {ins = 2, outs = 2, w = 4, h = 4, key = "c_dff"},
}
local PALETTE = {"switch", "button", "clock", "led", "seg7", "and", "or", "not", "nand", "nor", "xor", "xnor", "dff"}

-- ================================================================== state
local circuits, cur = {}, nil
local hist = K.history(80)
local dirty, changedAt = false, 0
local view = {ox = 0, oy = 0, w = 0, h = 0}
local sel, selWire = {}, nil
local drag = nil
local running = true
local clockHz = 1
local simT = 0
local truth = nil              -- the truth-table sheet
local listOpen = false
local pressShift = false
local frameDt = 1 / 60
local listScroll = K.scroller()
local listRect = {0, 0, 0, 0}

local function markDirty() dirty, changedAt = true, sys.time() end
local function compById(id) for _, c in ipairs(cur.comps) do if c.id == id then return c end end return nil end
local function newId() local i = cur.nextId; cur.nextId = i + 1; return i end

-- ================================================================== circuits and samples
local function addComp(c, typ, gx, gy, extra)
  local comp = {id = c.nextId, type = typ, x = gx * G, y = gy * G, on = false, out = {}, prev = false}
  c.nextId = c.nextId + 1
  if extra then for k, v in pairs(extra) do comp[k] = v end end
  c.comps[#c.comps + 1] = comp
  return comp
end
local function wire(c, a, ao, b, bi) c.wires[#c.wires + 1] = {a = a.id, ao = ao, b = b.id, bi = bi} end
local function blank(name) return {name = name, comps = {}, wires = {}, nextId = 1, view = {x = 0, y = 0, z = 1}} end

local function sampleHalfAdder()
  local c = blank(TR("s_half"))
  local a = addComp(c, "switch", -12, -5, {label = "A", on = true})
  local b = addComp(c, "switch", -12, 2, {label = "B"})
  local x = addComp(c, "xor", -2, -6)
  local n = addComp(c, "and", -2, 1)
  local s = addComp(c, "led", 7, -5, {label = TR("sum")})
  local k = addComp(c, "led", 7, 2, {label = TR("carry")})
  wire(c, a, 1, x, 1); wire(c, b, 1, x, 2); wire(c, a, 1, n, 1); wire(c, b, 1, n, 2)
  wire(c, x, 1, s, 1); wire(c, n, 1, k, 1)
  c.view = {x = -20, y = 0, z = 1}
  return c
end
local function sampleFullAdder()
  local c = blank(TR("s_full"))
  local a = addComp(c, "switch", -18, -8, {label = "A", on = true})
  local b = addComp(c, "switch", -18, -2, {label = "B", on = true})
  local ci = addComp(c, "switch", -18, 5, {label = "Cin"})
  local x1 = addComp(c, "xor", -10, -7)
  local x2 = addComp(c, "xor", 0, -3)
  local a1 = addComp(c, "and", -10, 1)
  local a2 = addComp(c, "and", 0, 4)
  local o = addComp(c, "or", 8, 2)
  local s = addComp(c, "led", 14, -3, {label = TR("sum")})
  local co = addComp(c, "led", 14, 3, {label = "Cout"})
  wire(c, a, 1, x1, 1); wire(c, b, 1, x1, 2)
  wire(c, x1, 1, x2, 1); wire(c, ci, 1, x2, 2)
  wire(c, a, 1, a1, 1); wire(c, b, 1, a1, 2)
  wire(c, x1, 1, a2, 1); wire(c, ci, 1, a2, 2)
  wire(c, a2, 1, o, 1); wire(c, a1, 1, o, 2)
  wire(c, x2, 1, s, 1); wire(c, o, 1, co, 1)
  c.view = {x = -40, y = 0, z = 0.85}
  return c
end
local function sampleLatch()
  local c = blank(TR("s_latch"))
  local s = addComp(c, "button", -12, -5, {label = "S"})
  local r = addComp(c, "button", -12, 3, {label = "R"})
  local n1 = addComp(c, "nor", -3, -5)
  local n2 = addComp(c, "nor", -3, 3)
  local q = addComp(c, "led", 6, -4, {label = "Q"})
  local nq = addComp(c, "led", 6, 4, {label = "Q̄"})
  wire(c, r, 1, n1, 1); wire(c, n2, 1, n1, 2)
  wire(c, s, 1, n2, 2); wire(c, n1, 1, n2, 1)
  wire(c, n1, 1, q, 1); wire(c, n2, 1, nq, 1)
  c.view = {x = -20, y = 10, z = 1}
  return c
end
local function sampleCounter()
  local c = blank(TR("s_counter"))
  local clk = addComp(c, "clock", -18, -1, {label = "CLK"})
  local d1 = addComp(c, "dff", -9, -9)
  local d2 = addComp(c, "dff", -1, -9)
  local d3 = addComp(c, "dff", 7, -9)
  local seg = addComp(c, "seg7", 16, -2)
  local l1 = addComp(c, "led", -8, 2, {label = "1"})
  local l2 = addComp(c, "led", 0, 2, {label = "2"})
  local l3 = addComp(c, "led", 8, 2, {label = "4"})
  -- ripple counter: each flip-flop toggles (D = not Q) on the falling edge of the previous one
  wire(c, d1, 2, d1, 1); wire(c, clk, 1, d1, 2)
  wire(c, d2, 2, d2, 1); wire(c, d1, 2, d2, 2)
  wire(c, d3, 2, d3, 1); wire(c, d2, 2, d3, 2)
  wire(c, d1, 1, l1, 1); wire(c, d2, 1, l2, 1); wire(c, d3, 1, l3, 1)
  wire(c, d1, 1, seg, 1); wire(c, d2, 1, seg, 2); wire(c, d3, 1, seg, 3)
  c.view = {x = 0, y = -30, z = 0.85}
  return c
end

local function sanitize(c)
  if type(c) ~= "table" or type(c.comps) ~= "table" then return nil end
  local o = {name = K.str(c.name, TR("untitled")), comps = {}, wires = {}, nextId = 1, view = type(c.view) == "table" and c.view or {x = 0, y = 0, z = 1}}
  local ids = {}
  for _, x in ipairs(c.comps) do
    if type(x) == "table" and T[x.type] then
      local id = K.int(x.id, 0)
      o.comps[#o.comps + 1] = {id = id, type = x.type, x = K.num(x.x, 0), y = K.num(x.y, 0), on = x.on == true, label = x.label and tostring(x.label) or nil,
                               out = {}, prev = false}
      ids[id] = true
      if id >= o.nextId then o.nextId = id + 1 end
    end
  end
  for _, w in ipairs(type(c.wires) == "table" and c.wires or {}) do
    if type(w) == "table" and ids[K.int(w.a, -1)] and ids[K.int(w.b, -1)] then
      o.wires[#o.wires + 1] = {a = K.int(w.a, 0), ao = K.int(w.ao, 1), b = K.int(w.b, 0), bi = K.int(w.bi, 1)}
    end
  end
  return o
end

local function plain(c)
  local o = {name = c.name, comps = {}, wires = c.wires, nextId = c.nextId, view = c.view}
  for i, x in ipairs(c.comps) do o.comps[i] = {id = x.id, type = x.type, x = x.x, y = x.y, on = x.on, label = x.label} end
  return o
end
local function saveNow()
  local out = {}
  for i, c in ipairs(circuits) do out[i] = plain(c) end
  store.set("circuits", out)
  for i, c in ipairs(circuits) do if c == cur then store.set("cur", i) end end
  store.set("prefs", {hz = clockHz})
  dirty = false
end
local function loadAll()
  circuits = {}
  local raw = store.get("circuits", nil)
  if type(raw) == "table" then for _, c in ipairs(raw) do local s = sanitize(c); if s then circuits[#circuits + 1] = s end end end
  if #circuits == 0 then circuits = {sampleFullAdder(), sampleHalfAdder(), sampleLatch(), sampleCounter()} end
  cur = circuits[clamp(K.int(store.get("cur", 1), 1), 1, #circuits)]
  local p = store.get("prefs", nil)
  if type(p) == "table" then clockHz = clamp(K.num(p.hz, 1), 0.25, 8) end
end

-- ================================================================== undo
local function snapshot() return K.copy(plain(cur)) end
local function pushHist() hist:push(snapshot()) end
local function restore(s)
  local keepView = cur.view
  local n = sanitize(s)
  cur.comps, cur.wires, cur.nextId = n.comps, n.wires, n.nextId
  cur.view = keepView
  sel, selWire = {}, nil
  markDirty()
end
local function undo() local s = hist:undo(snapshot()); if s then restore(s); K.toast(TR("undone"), "undo") else K.toast(TR("nothing_undo"), "undo") end end
local function redo() local s = hist:redo(snapshot()); if s then restore(s); K.toast(TR("redone"), "redo") else K.toast(TR("nothing_redo"), "redo") end end

-- ================================================================== geometry
local function size(c) local t = T[c.type]; return t.w * G, t.h * G end
local function inPin(c, i)
  local t = T[c.type]
  local w, h = size(c)
  if c.type == "dff" then return c.x, c.y + (i == 1 and G or 3 * G) end
  if c.type == "seg7" then return c.x, c.y + i * G end
  return c.x, c.y + h * i / (t.ins + 1)
end
local function outPin(c, i)
  local t = T[c.type]
  local w, h = size(c)
  if c.type == "dff" then return c.x + w, c.y + (i == 1 and G or 3 * G) end
  return c.x + w, c.y + h * i / (t.outs + 1)
end
local function toScreen(x, y) local v = cur.view; return view.ox + view.w / 2 + (x - v.x) * v.z, view.oy + view.h / 2 + (y - v.y) * v.z end
local function toWorld(sx, sy) local v = cur.view; return v.x + (sx - view.ox - view.w / 2) / v.z, v.y + (sy - view.oy - view.h / 2) / v.z end
local function snapG(v) return floor(v / G + 0.5) * G end
local function wirePath(w)
  local a, b = compById(w.a), compById(w.b)
  if not a or not b then return nil end
  local x1, y1 = outPin(a, w.ao)
  local x2, y2 = inPin(b, w.bi)
  if x2 >= x1 + G then
    local mx = snapG((x1 + x2) / 2)
    return {x1, y1, mx, y1, mx, y2, x2, y2}
  end
  -- loop back around, below both parts
  local _, ah = size(a)
  local _, bh = size(b)
  local mid = max(a.y + ah, b.y + bh) + G
  return {x1, y1, x1 + G, y1, x1 + G, mid, x2 - G, mid, x2 - G, y2, x2, y2}
end

-- ================================================================== simulation
local function buildInputs()
  local map = {}
  for _, w in ipairs(cur.wires) do map[w.b .. ":" .. w.bi] = w end
  return map
end
local inputMap, mapKey = {}, nil
local function getIn(c, i, byId)
  local w = inputMap[c.id .. ":" .. i]
  if not w then return false end
  local s = byId[w.a]
  return s and s.out[w.ao] == true or false
end
local function evalComp(c, byId, clockOn)
  local t = c.type
  local a, b = getIn(c, 1, byId), getIn(c, 2, byId)
  if t == "switch" then return {c.on}
  elseif t == "button" then return {c.held == true}
  elseif t == "clock" then return {clockOn}
  elseif t == "and" then return {a and b}
  elseif t == "or" then return {a or b}
  elseif t == "not" then return {not a}
  elseif t == "nand" then return {not (a and b)}
  elseif t == "nor" then return {not (a or b)}
  elseif t == "xor" then return {a ~= b}
  elseif t == "xnor" then return {a == b}
  elseif t == "dff" then
    local q = c.q == true
    if b and not c.prev then q = a end
    c.prev = b
    c.q = q
    return {q, not q}
  end
  return {}
end
local function step(clockOn, iterations)
  local key = #cur.wires .. ":" .. #cur.comps .. ":" .. tostring(cur)
  if mapKey ~= key or dirty then inputMap = buildInputs(); mapKey = key end
  local byId = {}
  for _, c in ipairs(cur.comps) do byId[c.id] = c end
  for _ = 1, iterations or 6 do
    local outs = {}
    for i, c in ipairs(cur.comps) do outs[i] = evalComp(c, byId, clockOn) end
    for i, c in ipairs(cur.comps) do c.out = outs[i] end
  end
end
local function inputsOf(c)
  local v = {}
  for i = 1, T[c.type].ins do
    local w = inputMap[c.id .. ":" .. i]
    local s = w and compById(w.a)
    v[i] = s and s.out[w.ao] == true or false
  end
  return v
end

-- truth table: every combination of switches and buttons, LEDs as outputs
local function buildTruth()
  local ins, outs = {}, {}
  for _, c in ipairs(cur.comps) do
    if c.type == "switch" or c.type == "button" then ins[#ins + 1] = c
    elseif c.type == "led" then outs[#outs + 1] = c end
  end
  table.sort(ins, function(a, b) return a.y < b.y end)
  table.sort(outs, function(a, b) return a.y < b.y end)
  if #ins == 0 or #outs == 0 then return {err = TR("truth_need")} end
  if #ins > 6 then return {err = TR("truth_many")} end
  local saved = {}
  for _, c in ipairs(cur.comps) do saved[c] = {on = c.on, held = c.held, out = c.out, q = c.q, prev = c.prev} end
  local rows = {}
  inputMap = buildInputs()
  for m = 0, 2 ^ #ins - 1 do
    for i, c in ipairs(ins) do
      local bit = (m >> (#ins - i)) & 1 == 1
      c.on, c.held = bit, bit
    end
    for _, c in ipairs(cur.comps) do if c.type ~= "dff" then c.out = {} end end
    step(false, 24)
    local row = {ins = {}, outs = {}}
    for i, c in ipairs(ins) do row.ins[i] = c.on end
    for i, c in ipairs(outs) do row.outs[i] = (inputsOf(c)[1]) == true end
    rows[#rows + 1] = row
  end
  for c, s in pairs(saved) do c.on, c.held, c.out, c.q, c.prev = s.on, s.held, s.out, s.q, s.prev end
  local names = {}
  for i, c in ipairs(ins) do names[i] = c.label or string.char(64 + i) end
  local onames = {}
  for i, c in ipairs(outs) do onames[i] = c.label or ("Y" .. i) end
  return {ins = names, outs = onames, rows = rows, t = 0}
end

-- ================================================================== editing
local function addPart(typ)
  pushHist()
  local v = cur.view
  local gx, gy = floor(v.x / G), floor(v.y / G)
  for _ = 1, 40 do
    local busy = false
    for _, c in ipairs(cur.comps) do if abs(c.x - gx * G) < G * 4 and abs(c.y - gy * G) < G * 3 then busy = true end end
    if not busy then break end
    gx, gy = gx + 2, gy + 2
  end
  local extra = nil
  if typ == "switch" or typ == "button" then
    local n = 0
    for _, c in ipairs(cur.comps) do if c.type == "switch" or c.type == "button" then n = n + 1 end end
    extra = {label = string.char(65 + n % 26)}
  elseif typ == "led" then
    local n = 0
    for _, c in ipairs(cur.comps) do if c.type == "led" then n = n + 1 end end
    extra = {label = "Y" .. (n + 1)}
  end
  local c = addComp(cur, typ, gx, gy, extra)
  sel, selWire = {[c.id] = true}, nil
  markDirty()
  audio.play("pop", 0.3)
end
local function deleteSel()
  if selWire then
    pushHist()
    table.remove(cur.wires, selWire)
    selWire = nil
    markDirty()
    return
  end
  local any = false
  for _ in pairs(sel) do any = true end
  if not any then return end
  pushHist()
  for i = #cur.comps, 1, -1 do if sel[cur.comps[i].id] then table.remove(cur.comps, i) end end
  for i = #cur.wires, 1, -1 do
    local w = cur.wires[i]
    if sel[w.a] or sel[w.b] then table.remove(cur.wires, i) end
  end
  sel = {}
  markDirty()
  audio.play("trash", 0.3)
end
local function rename()
  local one = nil
  for _, c in ipairs(cur.comps) do if sel[c.id] then one = c end end
  if one then
    ui.prompt(TR("label"), TR("label_msg"), one.label or "", function(t)
      if t then pushHist(); one.label = K.trim(t) ~= "" and K.utf8sub(K.trim(t), 1, 8) or nil; markDirty() end
    end)
  else
    ui.prompt(TR("rename"), TR("rename_msg"), cur.name, function(t) if t and K.trim(t) ~= "" then cur.name = K.trim(t); markDirty() end end)
  end
end
local function fit()
  if #cur.comps == 0 then cur.view = {x = 0, y = 0, z = 1}; return end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, c in ipairs(cur.comps) do
    local w, h = size(c)
    x0, y0, x1, y1 = min(x0, c.x), min(y0, c.y - 16), max(x1, c.x + w), max(y1, c.y + h + 16)
  end
  cur.view.x, cur.view.y = (x0 + x1) / 2, (y0 + y1) / 2
  cur.view.z = clamp(min((view.w - 80) / max(1, x1 - x0), (view.h - 80) / max(1, y1 - y0)), 0.4, 1.8)
end
local function zoomBy(f, sx, sy)
  sx, sy = sx or (view.ox + view.w / 2), sy or (view.oy + view.h / 2)
  local wx, wy = toWorld(sx, sy)
  cur.view.z = clamp(cur.view.z * f, 0.3, 3)
  local nx, ny = toWorld(sx, sy)
  cur.view.x, cur.view.y = cur.view.x + wx - nx, cur.view.y + wy - ny
end

-- ================================================================== drawing parts
local SEGS = {  -- a b c d e f g for hex digits
  [0] = "abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg", "acdefg", "abc", "abcdefg", "abcdfg", "abcefg", "cdefg", "adef", "bcdeg", "adefg", "aefg"}
local function drawSeg7(x, y, w, h, value, z)
  gfx.rect(x, y, w, h, 6 * z, "#1C1C1E")
  local on = SEGS[value] or ""
  local pad, t = 9 * z, 5 * z
  local sw, sh = w - pad * 2, (h - pad * 2) / 2
  local segs = {a = {x + pad + t, y + pad, sw - t * 2, t}, g = {x + pad + t, y + pad + sh - t / 2, sw - t * 2, t},
                d = {x + pad + t, y + h - pad - t, sw - t * 2, t}, f = {x + pad, y + pad + t, t, sh - t * 1.5},
                b = {x + w - pad - t, y + pad + t, t, sh - t * 1.5}, e = {x + pad, y + pad + sh + t / 2, t, sh - t * 1.5},
                c = {x + w - pad - t, y + pad + sh + t / 2, t, sh - t * 1.5}}
  for k, r in pairs(segs) do
    local lit = on:find(k, 1, true) ~= nil
    gfx.rect(r[1], r[2], r[3], r[4], t / 2, lit and "#FF453A" or "#3A2A2A")
  end
end

local function drawComp(c, z)
  local t = T[c.type]
  local w, h = size(c)
  local sx, sy = toScreen(c.x, c.y)
  local sw, sh = w * z, h * z
  local selected = sel[c.id]
  local outOn = c.out[1] == true
  -- pins
  for i = 1, t.ins do
    local px, py = toScreen(inPin(c, i))
    gfx.line(px - 6 * z, py, px, py, 2)
    gfx.circle(px - 6 * z, py, 3.5 * z, theme.text3)
  end
  for i = 1, t.outs do
    local px, py = toScreen(outPin(c, i))
    gfx.color(c.out[i] and theme.green or theme.text3)
    gfx.line(px, py, px + 6 * z, py, 2)
    gfx.circle(px + 6 * z, py, 3.5 * z, c.out[i] and theme.green or theme.text3)
  end
  if selected then gfx.rect(sx - 5, sy - 5, sw + 10, sh + 10, 10 * z, alpha(theme.accent, 0.18)) end
  local fs = clamp(floor(14 * z + 0.5), 8, 28)
  if c.type == "switch" then
    gfx.rect(sx, sy, sw, sh, 8 * z, theme.window)
    gfx.color(selected and theme.accent or alpha(theme.text, 0.35)); gfx.rectLine(sx, sy, sw, sh, 8 * z, 1.5)
    local tw, th = sw * 0.55, sh * 0.42
    local tx, ty = sx + sw * 0.32, sy + sh / 2 - th / 2
    gfx.rect(tx, ty, tw, th, th / 2, c.on and theme.green or alpha(theme.text, 0.2))
    gfx.circle(c.on and (tx + tw - th / 2) or (tx + th / 2), ty + th / 2, th / 2 - 2, "#FFFFFF")
  elseif c.type == "button" then
    gfx.rect(sx, sy, sw, sh, 8 * z, theme.window)
    gfx.color(selected and theme.accent or alpha(theme.text, 0.35)); gfx.rectLine(sx, sy, sw, sh, 8 * z, 1.5)
    gfx.circle(sx + sw * 0.6, sy + sh / 2, sh * 0.3, c.held and theme.orange or mix(theme.window, theme.orange, 0.35))
  elseif c.type == "clock" then
    gfx.rect(sx, sy, sw, sh, 8 * z, theme.window)
    gfx.color(selected and theme.accent or alpha(theme.text, 0.35)); gfx.rectLine(sx, sy, sw, sh, 8 * z, 1.5)
    local wx, wy, ww, wh = sx + sw * 0.25, sy + sh * 0.3, sw * 0.55, sh * 0.4
    gfx.color(outOn and theme.green or theme.text2)
    gfx.lines({wx, wy + wh, wx + ww * 0.25, wy + wh, wx + ww * 0.25, wy, wx + ww * 0.5, wy, wx + ww * 0.5, wy + wh, wx + ww * 0.75, wy + wh, wx + ww * 0.75, wy, wx + ww, wy}, 2)
  elseif c.type == "led" then
    local v = inputsOf(c)[1]
    local col = theme.red
    if v then gfx.circle(sx + sw / 2, sy + sh / 2, sw * 0.62, alpha(col, 0.25)) end
    gfx.circle(sx + sw / 2, sy + sh / 2, sw * 0.42, v and col or mix(theme.window, col, 0.18))
    gfx.color(alpha(theme.text, 0.35)); gfx.circleLine(sx + sw / 2, sy + sh / 2, sw * 0.42, 1.5)
    if v then gfx.circle(sx + sw * 0.4, sy + sh * 0.4, sw * 0.1, alpha("#FFFFFF", 0.7)) end
  elseif c.type == "seg7" then
    local v = inputsOf(c)
    local n = (v[1] and 1 or 0) + (v[2] and 2 or 0) + (v[3] and 4 or 0) + (v[4] and 8 or 0)
    drawSeg7(sx, sy, sw, sh, n, z)
    gfx.color(theme.text3)
    for i = 1, 4 do
      local px, py = toScreen(inPin(c, i))
      gfx.text(string.format("%d", 2 ^ (i - 1)), px - 30 * z, py - 7 * z, clamp(floor(10 * z), 7, 16), "mono", "right", 20 * z)
    end
  elseif c.type == "dff" then
    gfx.rect(sx, sy, sw, sh, 6 * z, theme.window)
    gfx.color(selected and theme.accent or alpha(theme.text, 0.6)); gfx.rectLine(sx, sy, sw, sh, 6 * z, 2)
    gfx.color(theme.text)
    local small = clamp(floor(11 * z), 7, 20)
    local _, p1 = inPin(c, 1)
    local _, p2 = inPin(c, 2)
    local _, q1 = outPin(c, 1)
    local _, q2 = outPin(c, 2)
    local _, y1 = toScreen(0, p1)
    local _, y2 = toScreen(0, p2)
    local _, y3 = toScreen(0, q1)
    local _, y4 = toScreen(0, q2)
    gfx.text("D", sx + 5 * z, y1 - small * 0.6, small, "semibold")
    gfx.lines({sx, y2 - 5 * z, sx + 7 * z, y2, sx, y2 + 5 * z}, 1.5)
    gfx.text("Q", sx + sw - 16 * z, y3 - small * 0.6, small, "semibold")
    gfx.text("Q̄", sx + sw - 16 * z, y4 - small * 0.6, small, "semibold")
    gfx.text("FF", sx, sy + sh / 2 - fs * 0.6, fs, "bold", "center", sw)
  else
    gfx.rect(sx, sy, sw, sh, 6 * z, theme.window)
    gfx.color(selected and theme.accent or alpha(theme.text, 0.6)); gfx.rectLine(sx, sy, sw, sh, 6 * z, 2)
    gfx.color(theme.text)
    gfx.text(t.sym, sx, sy + sh / 2 - fs * 0.62, fs, "bold", "center", sw)
    if t.neg then
      local px, py = toScreen(outPin(c, 1))
      gfx.circle(px + 1 * z, py, 4.5 * z, theme.window)
      gfx.color(alpha(theme.text, 0.7)); gfx.circleLine(px + 1 * z, py, 4.5 * z, 1.5)
    end
  end
  -- label
  local label = c.label
  if not label and t.sym then label = TR(t.key) end
  if label and z > 0.45 then
    gfx.color(theme.text2)
    local ls = clamp(floor(11 * z + 0.5), 8, 18)
    gfx.text(label, sx - 10, sy - ls - 6, ls, "medium", "center", sw + 20)
  end
end

-- ================================================================== canvas input
local function compAt(wx, wy)
  for i = #cur.comps, 1, -1 do
    local c = cur.comps[i]
    local w, h = size(c)
    if wx >= c.x - 4 and wx <= c.x + w + 4 and wy >= c.y - 4 and wy <= c.y + h + 4 then return c end
  end
  return nil
end
local function pinAt(sx, sy)
  local z = cur.view.z
  local best, bd = nil, (14) ^ 2
  for _, c in ipairs(cur.comps) do
    local t = T[c.type]
    for i = 1, t.outs do
      local px, py = toScreen(outPin(c, i))
      px = px + 6 * z
      local d = (px - sx) ^ 2 + (py - sy) ^ 2
      if d < bd then best, bd = {c = c, out = i}, d end
    end
    for i = 1, t.ins do
      local px, py = toScreen(inPin(c, i))
      px = px - 6 * z
      local d = (px - sx) ^ 2 + (py - sy) ^ 2
      if d < bd then best, bd = {c = c, ["in"] = i}, d end
    end
  end
  return best
end
local function wireAt(wx, wy)
  local tol = 7 / cur.view.z
  for i = #cur.wires, 1, -1 do
    local p = wirePath(cur.wires[i])
    if p then
      for k = 1, #p - 3, 2 do
        local x1, y1, x2, y2 = p[k], p[k + 1], p[k + 2], p[k + 3]
        local dx, dy = x2 - x1, y2 - y1
        local l2 = dx * dx + dy * dy
        local tt = l2 > 0 and clamp(((wx - x1) * dx + (wy - y1) * dy) / l2, 0, 1) or 0
        if sqrt((wx - x1 - tt * dx) ^ 2 + (wy - y1 - tt * dy) ^ 2) < tol then return i end
      end
    end
  end
  return nil
end
local function connect(p1, p2)
  local o, i = p1.out and p1 or p2, p1["in"] and p1 or p2
  if not (o.out and i["in"]) then return false end
  pushHist()
  for k = #cur.wires, 1, -1 do
    local w = cur.wires[k]
    if w.b == i.c.id and w.bi == i["in"] then table.remove(cur.wires, k) end   -- one driver per input
  end
  cur.wires[#cur.wires + 1] = {a = o.c.id, ao = o.out, b = i.c.id, bi = i["in"]}
  markDirty()
  audio.play("click", 0.3)
  return true
end

local function canvas(x, y, w, h)
  local hit = ui.hit("canvas", x, y, w, h)
  local mx, my = ui.mouse()
  local z = cur.view.z
  if hit.pressed then
    local wx, wy = toWorld(mx, my)
    drag = {sx = mx, sy = my, vx = cur.view.x, vy = cur.view.y, moved = false}
    local pin = pinAt(mx, my)
    local c = compAt(wx, wy)
    if pin then drag.kind, drag.pin = "wire", pin
    elseif c then
      drag.kind, drag.comp = "move", c
      if c.type == "button" then c.held = true end
      if not sel[c.id] then if not pressShift then sel = {} end; sel[c.id] = true end
      selWire = nil
      drag.orig = {}
      for _, o in ipairs(cur.comps) do if sel[o.id] then drag.orig[o.id] = {o.x, o.y} end end
    else
      local wi = wireAt(wx, wy)
      if wi then drag.kind = "wiresel"; selWire, sel = wi, {}
      else drag.kind = "pan" end
    end
  end
  if hit.held and drag then
    local dx, dy = mx - drag.sx, my - drag.sy
    if not drag.moved and abs(dx) + abs(dy) > 7 then
      drag.moved = true
      if drag.kind == "move" then pushHist(); if drag.comp.type == "button" then drag.comp.held = false end end
    end
    if drag.moved then
      if drag.kind == "pan" then cur.view.x, cur.view.y = drag.vx - dx / z, drag.vy - dy / z
      elseif drag.kind == "move" then
        for id, o in pairs(drag.orig) do
          local c = compById(id)
          if c then c.x, c.y = snapG(o[1] + dx / z), snapG(o[2] + dy / z) end
        end
        markDirty()
      elseif drag.kind == "wire" then drag.cx, drag.cy = mx, my end
    end
  end
  if drag and not hit.held and not hit.pressed then
    local d = drag
    drag = nil
    for _, c in ipairs(cur.comps) do c.held = false end
    if d.kind == "wire" and d.moved then
      local p2 = pinAt(mx, my)
      if p2 and not connect(d.pin, p2) then K.toast(TR("wire_hint"), "info") end
    elseif d.kind == "move" and not d.moved then
      local c = d.comp
      if c.type == "switch" then c.on = not c.on; markDirty(); audio.play("click", 0.25) end
      if hit.doubleClicked then rename() end
    elseif d.kind == "pan" and not d.moved then sel, selWire = {}, nil end
  end
  if drag and drag.kind == "move" and drag.comp and drag.comp.type == "button" and not drag.moved then drag.comp.held = true end
  if hit.rightClicked then
    local wx, wy = toWorld(mx, my)
    local c = compAt(wx, wy)
    if c then
      sel = {[c.id] = true}
      ui.contextMenu({{label = TR("label"), id = 1, icon = "label"}, {label = TR("duplicate"), id = 2, icon = "content_copy"}, "-",
                      {label = TR("delete"), id = 3, icon = "delete"}}, function(id)
        if id == 1 then rename()
        elseif id == 2 then pushHist(); local n = addComp(cur, c.type, c.x / G + 2, c.y / G + 2, {label = c.label}); sel = {[n.id] = true}; markDirty()
        elseif id == 3 then deleteSel() end
      end)
    end
  end
  return hit
end

-- ================================================================== drawing screens
local function drawWires(z)
  for i, w in ipairs(cur.wires) do
    local p = wirePath(w)
    if p then
      local a = compById(w.a)
      local on = a and a.out[w.ao] == true
      local pts = {}
      for k = 1, #p, 2 do local sx, sy = toScreen(p[k], p[k + 1]); pts[#pts + 1] = sx; pts[#pts + 1] = sy end
      if selWire == i then gfx.color(alpha(theme.accent, 0.35)); gfx.lines(pts, 8, false) end
      gfx.color(on and theme.green or alpha(theme.text, 0.35))
      gfx.lines(pts, on and 3 or 2, false)
    end
  end
end

local function drawPalette(x, y, w, h)
  gfx.rect(x, y, w, h, 0, theme.sidebar)
  gfx.color(theme.separator); gfx.line(x + w, y, x + w, y + h, 1)
  local per = w >= 120 and 2 or 1
  local bw = floor((w - 12 - (per - 1) * 4) / per)
  local bh = min(52, floor((h - 12) / math.ceil(#PALETTE / per)) - 4)
  for i, typ in ipairs(PALETTE) do
    local col, row = (i - 1) % per, floor((i - 1) / per)
    local bx, by = x + 6 + col * (bw + 4), y + 6 + row * (bh + 4)
    local hit = ui.hit("pal" .. typ, bx, by, bw, bh)
    gfx.rect(bx, by, bw, bh, 8, hit.hovered and theme.hover or alpha(theme.text, 0.04))
    local t = T[typ]
    local cx, cy = bx + bw / 2, by + bh / 2 - 7
    if t.sym then
      gfx.rect(cx - 13, cy - 10, 26, 20, 4, theme.window)
      gfx.color(alpha(theme.text, 0.6)); gfx.rectLine(cx - 13, cy - 10, 26, 20, 4, 1.5)
      gfx.color(theme.text); gfx.text(t.sym, cx - 13, cy - 7, 11, "bold", "center", 26)
      if t.neg then gfx.circle(cx + 15, cy, 3, theme.window); gfx.color(theme.text2); gfx.circleLine(cx + 15, cy, 3, 1.2) end
    else
      local icons = {switch = "toggle_on", button = "radio_button_checked", clock = "schedule", led = "lightbulb", seg7 = "looks_one", dff = "memory"}
      gfx.icon(icons[typ] or "memory", cx, cy, 22, theme.accent)
    end
    gfx.color(theme.text2)
    gfx.text(K.ellipsize(TR(t.key), 10, "medium", bw - 4), bx, by + bh - 15, 10, "medium", "center", bw)
    if hit.clicked then addPart(typ) end
  end
end

local function drawList(w, h)
  if not listOpen then return end
  local mx, my, cw, ch, outside = K.modal("list", w, h, 460, 460, 1)
  gfx.color(theme.text)
  gfx.text(TR("circuits"), mx + 18, my + 16, 18, "bold")
  if ui.iconButton("close", mx + cw - 46, my + 10, 34, 32, theme.text2, false, "##lc") or outside then listOpen = false; return end
  if ui.button(TR("new_circuit"), mx + cw - 186, my + 10, 132, 32, "primary", "add") then
    local c = blank(TR("new_circuit"))
    table.insert(circuits, 1, c); cur = c; hist:clear(); sel = {}; listOpen = false; markDirty()
    return
  end
  local ly, lh = my + 58, ch - 68
  listRect = {mx, ly, cw, lh}
  listScroll:setMax(#circuits * 52 - lh)
  gfx.clip(mx, ly, cw, lh)
  for i, c in ipairs(circuits) do
    local ry = ly + (i - 1) * 52 - listScroll.y
    local hit = ui.hit("ci" .. i, mx + 10, ry, cw - 64, 46)
    gfx.rect(mx + 10, ry, cw - 20, 46, 10, c == cur and alpha(theme.accent, 0.16) or (hit.hovered and theme.hover or alpha(theme.text, 0.04)))
    gfx.icon("memory", mx + 32, ry + 23, 20, theme.accent)
    gfx.color(theme.text)
    gfx.text(K.ellipsize(c.name, 14, "semibold", cw - 140), mx + 52, ry + 6, 14, "semibold")
    gfx.color(theme.text3)
    gfx.text(TR("parts_n", #c.comps, #c.wires), mx + 52, ry + 25, 12)
    if hit.clicked and not listScroll:dragged() then cur = c; hist:clear(); sel, selWire = {}, nil; listOpen = false; saveNow() end
    if ui.iconButton("delete", mx + cw - 52, ry + 7, 34, 32, theme.text3, false, "##cd" .. i) then
      ui.alert(TR("delete_circuit"), TR("delete_circuit_msg", c.name), {TR("delete"), TR("cancel")}, function(b)
        if b ~= 1 then return end
        for k, x in ipairs(circuits) do if x == c then table.remove(circuits, k) end end
        if #circuits == 0 then circuits[1] = blank(TR("new_circuit")) end
        if c == cur then cur = circuits[1]; hist:clear() end
        markDirty()
      end)
    end
  end
  gfx.unclip()
end

local function drawTruth(w, h)
  if not truth then return end
  truth.t = min(1, (truth.t or 0) + frameDt * 8)
  local cols = truth.ins and (#truth.ins + #truth.outs) or 2
  local mx, my, cw, ch, outside = K.modal("truth", w, h, max(320, cols * 58 + 60), 500, truth.t)
  gfx.color(theme.text)
  gfx.text(TR("truth_table"), mx + 18, my + 16, 18, "bold")
  if ui.iconButton("close", mx + cw - 46, my + 10, 34, 32, theme.text2, false, "##tc") or outside then truth = nil; return end
  if truth.err then
    gfx.color(theme.text2)
    gfx.wrap(truth.err, mx + 20, my + 70, cw - 40, 14)
    return
  end
  local cwid = floor((cw - 40) / cols)
  local ty = my + 60
  for i, n in ipairs(truth.ins) do gfx.color(theme.text2); gfx.text(K.ellipsize(n, 13, "bold", cwid - 4), mx + 20 + (i - 1) * cwid, ty, 13, "bold", "center", cwid) end
  for i, n in ipairs(truth.outs) do gfx.color(theme.accent); gfx.text(K.ellipsize(n, 13, "bold", cwid - 4), mx + 20 + (#truth.ins + i - 1) * cwid, ty, 13, "bold", "center", cwid) end
  gfx.color(theme.separator)
  gfx.line(mx + 16, ty + 22, mx + cw - 16, ty + 22, 1)
  gfx.line(mx + 20 + #truth.ins * cwid, ty - 4, mx + 20 + #truth.ins * cwid, my + ch - 16, 1)
  local rh = min(28, floor((ch - 110) / max(1, #truth.rows)))
  for r, row in ipairs(truth.rows) do
    local ry = ty + 28 + (r - 1) * rh
    if r % 2 == 0 then gfx.rect(mx + 16, ry - 2, cw - 32, rh, 4, alpha(theme.text, 0.04)) end
    for i, v in ipairs(row.ins) do
      gfx.color(v and theme.text or theme.text3)
      gfx.text(v and "1" or "0", mx + 20 + (i - 1) * cwid, ry + (rh - 18) / 2, min(15, rh - 4), "mono", "center", cwid)
    end
    for i, v in ipairs(row.outs) do
      gfx.color(v and theme.green or theme.text3)
      gfx.text(v and "1" or "0", mx + 20 + (#truth.ins + i - 1) * cwid, ry + (rh - 18) / 2, min(15, rh - 4), "monobold", "center", cwid)
    end
  end
end

local function drawTop(w)
  gfx.rect(0, 0, w, 50, 0, theme.window)
  local bx = 10
  if ui.iconButton("folder_open", bx, 9, 36, 32, theme.text2, false, "##list") then listOpen = true end
  bx = bx + 42
  local right = w - 10
  local function rb(icon, id, tint, active, enabled)
    right = right - 38
    if enabled == false then gfx.icon(icon, right + 18, 25, 20, theme.text3); return false end
    return ui.iconButton(icon, right, 9, 36, 32, tint or theme.text2, active, id)
  end
  if rb("more_horiz", "##more") then
    ui.contextMenu({{label = TR("rename"), id = 1, icon = "edit"}, {label = TR("save_file"), id = 2, icon = "save"},
                    {label = TR("open_file"), id = 3, icon = "folder_open"}, "-", {label = TR("add_samples"), id = 4, icon = "auto_awesome"},
                    {label = TR("clear_all"), id = 5, icon = "delete_sweep"}}, function(id) app.onmenu(100 + id) end)
  end
  if rb("fit_screen", "##fit") then fit() end
  if rb("table_chart", "##truth", theme.accent) then truth = buildTruth() end
  local anySel = selWire ~= nil
  for _ in pairs(sel) do anySel = true end
  if rb("delete", "##del", theme.red, false, anySel) then deleteSel() end
  if rb("redo", "##redo", nil, false, hist:canRedo()) then redo() end
  if rb("undo", "##undo", nil, false, hist:canUndo()) then undo() end
  if rb(running and "pause" or "play_arrow", "##run", running and theme.text2 or theme.green, not running) then running = not running end
  -- clock speed
  if right - bx > 330 then
    right = right - 150
    gfx.color(theme.text2)
    gfx.text(TR("hz", K.fmtNum(clockHz, 2)), right, 8, 11, "medium", "center", 140)
    local nv = ui.slider("hz", clockHz, 0.25, 8, right + 6, 24, 132, 0.25)
    if nv ~= clockHz then clockHz = nv; markDirty() end
  end
  gfx.color(theme.text)
  local th = ui.hit("ctitle", bx, 9, min(right - bx - 8, gfx.textWidth(cur.name, 16, "bold") + 16), 32)
  if th.hovered then gfx.rect(bx, 9, min(right - bx - 8, gfx.textWidth(cur.name, 16, "bold") + 16), 32, 8, theme.hover) end
  gfx.text(K.ellipsize(cur.name, 16, "bold", right - bx - 24), bx + 8, 16, 16, "bold")
  if th.clicked then listOpen = true end
  gfx.color(theme.separator); gfx.line(0, 50, w, 50, 1)
end

-- ================================================================== app callbacks
function app.load(arg)
  loadAll()
  if type(arg) == "string" and arg ~= "" then app.open(arg) end
end
function app.open(arg)
  if type(arg) ~= "string" or arg == "" then return end
  local data = fs.read(arg)
  local c = data and sanitize(json.decode(data))
  if c then table.insert(circuits, 1, c); cur = c; hist:clear(); markDirty(); K.toast(TR("opened", c.name), "folder_open")
  else K.toast(TR("not_circuit"), "error") end
end

function app.update(dt)
  frameDt = dt
  listScroll:update(dt)
  if running then simT = simT + dt end
  local clockOn = (floor(simT * clockHz * 2) % 2) == 1
  step(clockOn, 6)
  if dirty and sys.time() - changedAt > 1.5 then saveNow() end
  local sx, sy = input.stick("left")
  if not listOpen and not truth and (abs(sx) > 0.25 or abs(sy) > 0.25) then
    cur.view.x = cur.view.x + sx * dt * 500 / cur.view.z
    cur.view.y = cur.view.y - sy * dt * 500 / cur.view.z
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  drawTop(w)
  local pw = w >= 700 and 132 or 70
  local cx, cy, cw, ch = pw, 51, w - pw, h - 51
  view.ox, view.oy, view.w, view.h = cx, cy, cw, ch
  gfx.clip(cx, cy, cw, ch)
  gfx.rect(cx, cy, cw, ch, 0, theme.bg)
  -- grid dots
  local z = cur.view.z
  local stp = G * z
  if stp >= 10 then
    local wx0, wy0 = toWorld(cx, cy)
    local sx0, sy0 = toScreen(floor(wx0 / G) * G, floor(wy0 / G) * G)
    gfx.color(alpha(theme.text, theme.dark and 0.1 or 0.08))
    local nx, ny = floor(cw / stp) + 2, floor(ch / stp) + 2
    if nx * ny < 5000 then for i = 0, nx do for j = 0, ny do gfx.rect(sx0 + i * stp - 1, sy0 + j * stp - 1, 2, 2) end end end
  end
  canvas(cx, cy, cw, ch)
  drawWires(z)
  for _, c in ipairs(cur.comps) do drawComp(c, z) end
  if drag and drag.kind == "wire" and drag.cx then
    local p = drag.pin
    local px, py
    if p.out then px, py = toScreen(outPin(p.c, p.out)) else px, py = toScreen(inPin(p.c, p["in"])) end
    gfx.color(theme.accent)
    gfx.line(px, py, drag.cx, drag.cy, 2.5)
    gfx.circle(drag.cx, drag.cy, 5, theme.accent)
  end
  if #cur.comps == 0 then K.empty("memory", TR("empty"), TR("empty_hint"), cx, cy, cw, ch) end
  gfx.color(theme.text3)
  gfx.text(K.ellipsize(TR("hint"), 12, "sans", cw - 24), cx + 12, cy + ch - 24, 12)
  gfx.unclip()
  drawPalette(0, 51, pw, h - 51)
  drawTruth(w, h)
  drawList(w, h)
  K.drawToast(w, h)
  K.frameEnd()
end

function app.event(e)
  if K.press(e) then return end
  if listOpen then
    if listScroll:event(e, listRect) then return end
    if e.type == "keydown" and e.key == "escape" then listOpen = false end
    return
  end
  if truth then if e.type == "keydown" and (e.key == "escape" or e.key == "t") then truth = nil end; return end
  if e.type == "mousedown" then pressShift = e.shift and true or false end
  if e.type == "pinch" then zoomBy(e.scale or 1, e.x, e.y); return end
  if e.type == "scroll" then
    if not e.touch then zoomBy(math.exp(-(e.dy or 0) * 0.004), e.x, e.y)
    else cur.view.x, cur.view.y = cur.view.x + (e.dx or 0) / cur.view.z, cur.view.y + (e.dy or 0) / cur.view.z end
    return
  end
  if e.type ~= "keydown" or K.editing then return end
  local k = e.key
  if e.ctrl then
    if k == "z" then if e.shift then redo() else undo() end
    elseif k == "y" then redo()
    elseif k == "a" then sel = {}; for _, c in ipairs(cur.comps) do sel[c.id] = true end
    elseif k == "s" then app.onmenu(102)
    elseif k == "o" then app.onmenu(103)
    elseif k == "0" then fit() end
    return
  end
  if k == "delete" or k == "backspace" then deleteSel()
  elseif k == "t" then truth = buildTruth()
  elseif k == "space" or k == "enter" then
    local any = false
    for _, c in ipairs(cur.comps) do if sel[c.id] and c.type == "switch" then c.on = not c.on; any = true end end
    if any then audio.play("click", 0.25); markDirty() elseif k == "space" then running = not running end
  elseif k == "tab" then
    if #cur.comps > 0 then
      local idx = 0
      for i, c in ipairs(cur.comps) do if sel[c.id] then idx = i end end
      idx = idx % #cur.comps + 1
      sel, selWire = {[cur.comps[idx].id] = true}, nil
    end
  elseif k == "left" or k == "right" or k == "up" or k == "down" then
    local dx = k == "left" and -1 or (k == "right" and 1 or 0)
    local dy = k == "up" and -1 or (k == "down" and 1 or 0)
    local any = false
    for _ in pairs(sel) do any = true end
    if any then
      pushHist()
      for _, c in ipairs(cur.comps) do if sel[c.id] then c.x, c.y = c.x + dx * G, c.y + dy * G end end
      markDirty()
    else cur.view.x, cur.view.y = cur.view.x + dx * 60 / cur.view.z, cur.view.y + dy * 60 / cur.view.z end
  elseif k == "f" then fit()
  elseif k == "l" then listOpen = true
  elseif k == "escape" then sel, selWire = {}, nil
  elseif e.text == "+" or k == "=" then zoomBy(1.2) elseif k == "-" then zoomBy(1 / 1.2)
  elseif k >= "1" and k <= "9" and #k == 1 then addPart(PALETTE[tonumber(k)]) end
end

function app.menu()
  return {
    {title = TR("m_file"), items = {
      {label = TR("circuits"), id = 1, shortcut = "L"},
      {label = TR("new_circuit"), id = 2},
      {label = TR("open_file"), id = 103, shortcut = "Ctrl+O"},
      {label = TR("save_file"), id = 102, shortcut = "Ctrl+S"},
      "-",
      {label = TR("add_samples"), id = 104},
    }},
    {title = TR("m_edit"), items = {
      {label = TR("undo"), id = 10, shortcut = "Ctrl+Z"},
      {label = TR("redo"), id = 11, shortcut = "Ctrl+Y"},
      "-",
      {label = TR("label"), id = 101},
      {label = TR("delete"), id = 12, shortcut = "Del"},
      {label = TR("clear_all"), id = 105},
    }},
    {title = TR("m_sim"), items = {
      {label = TR("run_pause"), id = 20, shortcut = "Space"},
      {label = TR("truth_table"), id = 21, shortcut = "T"},
      {label = TR("fit"), id = 22, shortcut = "Ctrl+0"},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then listOpen = true
  elseif id == 2 then local c = blank(TR("new_circuit")); table.insert(circuits, 1, c); cur = c; hist:clear(); markDirty()
  elseif id == 10 then undo() elseif id == 11 then redo() elseif id == 12 then deleteSel()
  elseif id == 20 then running = not running elseif id == 21 then truth = buildTruth() elseif id == 22 then fit()
  elseif id == 101 then rename()
  elseif id == 102 then
    ui.saveFile(function(p)
      if not p then return end
      if not p:lower():match("%.logic$") then p = p .. ".logic" end
      local d = plain(cur)
      d.app = "logiclab"
      if fs.write(p, json.encode(d, true)) then K.toast(TR("saved"), "save") else K.toast(TR("write_failed"), "error") end
    end, cur.name:gsub("[/\\:%*%?\"<>|]", "-") .. ".logic", TR("save_file"))
  elseif id == 103 then ui.openFile(function(p) if p then app.open(p) end end, {".logic", ".json"}, TR("open_file"))
  elseif id == 104 then
    for _, c in ipairs({sampleFullAdder(), sampleHalfAdder(), sampleLatch(), sampleCounter()}) do circuits[#circuits + 1] = c end
    markDirty(); K.toast(TR("samples_added"), "auto_awesome")
  elseif id == 105 then
    if #cur.comps > 0 then pushHist(); cur.comps, cur.wires = {}, {}; sel, selWire = {}, nil; markDirty() end
  end
end

function app.search(q)
  local out = {}
  q = K.lower(K.trim(q))
  if q == "" then return out end
  for i, c in ipairs(circuits) do
    if K.lower(c.name):find(q, 1, true) and #out < 5 then out[#out + 1] = {title = c.name, subtitle = TR("app_name"), icon = "memory", arg = "circuit:" .. i} end
  end
  return out
end
local baseOpen = app.open
function app.open(arg)
  local i = type(arg) == "string" and tonumber(arg:match("^circuit:(%d+)$"))
  if i then if circuits[i] then cur = circuits[i]; hist:clear(); sel = {} end; return end
  baseOpen(arg)
end
function app.suspend() if dirty then saveNow() end end
function app.autosave() if dirty then saveNow() end end
function app.unsaved() return dirty end
function app.close() saveNow(); store.save(); return true end

return app
