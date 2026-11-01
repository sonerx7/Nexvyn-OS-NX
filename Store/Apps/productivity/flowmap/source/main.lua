-- Flowmap for Nexvyn OS: flowcharts and mind maps. Flowcharts are free-form: shapes, connectors with arrows and
-- labels, straight or elbow routing, colours, snapping, align and distribute. Mind maps lay themselves out: Tab adds
-- a child, Enter a sibling. Both export to SVG, flowcharts also to Mermaid text; documents are kept in a gallery.
local K = require("kit")
local app = {}

local floor, min, max, abs, sqrt = math.floor, math.min, math.max, math.abs, math.sqrt
local clamp, alpha, mix = K.clamp, K.alpha, K.mix

-- ================================================================== constants
local SHAPES = {"rect", "round", "ellipse", "diamond", "para", "hex", "note", "cylinder", "text"}
local COLORS = {"text", "blue", "green", "yellow", "orange", "red", "pink", "purple", "gray"}
-- fixed colours for SVG export (light theme)
local EXPORT = {text = "#3A3A3C", blue = "#007AFF", green = "#28A745", yellow = "#E6B800", orange = "#FF9500",
                red = "#FF3B30", pink = "#FF2D55", purple = "#AF52DE", gray = "#8E8E93"}
local SIZES = {13, 15, 19}
local GRID = 20

-- ================================================================== state
local docs = {}
local doc = nil
local screen = "gallery"            -- "gallery" | "editor"
local hist = K.history(80)
local dirty, changedAt = false, 0
local sel = {}                      -- selected node ids -> true (flow), or {id} for mind
local selEdge = nil
local view = {ox = 0, oy = 0, w = 0, h = 0}
local drag = nil
local editing = nil                 -- {id, text, edge = bool}
local snap = true
local showGrid = true
local panelOpen = false             -- narrow windows: the properties panel floats
local clip = nil                    -- copied nodes and edges
local gQuery = ""
local frameDt = 1 / 60
local mindLayout, mindKey = nil, nil
local galleryScroll = K.scroller()
local galleryRect = {0, 0, 0, 0}
local pressShift = false            -- Shift held at the last press: add to the selection / draw a box
local boxMode = false               -- touch: dragging the background draws a selection box instead of panning

local function now() return sys.epoch() end
local function markDirty()
  dirty, changedAt = true, sys.time()
  if doc then doc.updated = now() end
  mindKey = nil
end
local function colorOf(i) return theme[COLORS[i] or "text"] or theme.text end

-- ================================================================== documents
local function snapshot() return K.copy({nodes = doc.nodes, edges = doc.edges, nextId = doc.nextId}) end
local function pushHist() if doc then hist:push(snapshot()) end end
local function applySnap(s) doc.nodes, doc.edges, doc.nextId = s.nodes, s.edges, s.nextId; markDirty() end

local function nodeById(id)
  for _, n in ipairs(doc.nodes) do if n.id == id then return n end end
  return nil
end
local function newId() local id = doc.nextId; doc.nextId = id + 1; return id end

local function addFlowNode(shape, x, y, text, color)
  local w, h = 150, 64
  if shape == "diamond" then w, h = 150, 90 elseif shape == "ellipse" then w, h = 140, 64
  elseif shape == "note" then w, h = 150, 100 elseif shape == "text" then w, h = 140, 40
  elseif shape == "cylinder" then w, h = 120, 84 end
  local n = {id = newId(), x = x, y = y, w = w, h = h, shape = shape, text = text or "", color = color or 1, size = 2}
  doc.nodes[#doc.nodes + 1] = n
  return n
end
local function addEdge(a, b, label)
  local e = {id = newId(), a = a, b = b, style = 1, route = 1, label = label or "", color = 1}
  doc.edges[#doc.edges + 1] = e
  return e
end

local function sampleFlow()
  local d = {id = 0, name = TR("sample_flow"), kind = "flow", nodes = {}, edges = {}, nextId = 1, updated = now(),
             view = {x = 0, y = 40, z = 0.85}}
  local prev = doc
  doc = d
  local s = addFlowNode("ellipse", 0, -200, TR("sf_start"), 3)
  local a = addFlowNode("round", 0, -90, TR("sf_receive"), 2)
  local q = addFlowNode("diamond", 0, 30, TR("sf_stock"), 4)
  local p = addFlowNode("round", 0, 160, TR("sf_pack"), 2)
  local o = addFlowNode("para", 260, 30, TR("sf_supplier"), 5)
  local e = addFlowNode("ellipse", 0, 270, TR("sf_done"), 6)
  local n = addFlowNode("note", -250, 40, TR("sf_note"), 4)
  n.w, n.h = 170, 96
  addEdge(s.id, a.id)
  addEdge(a.id, q.id)
  addEdge(q.id, p.id, TR("sf_yes"))
  local x = addEdge(q.id, o.id, TR("sf_no"))
  x.color = 6
  local back = addEdge(o.id, p.id)
  back.route = 2
  addEdge(p.id, e.id)
  doc = prev
  return d
end

local function sampleMind()
  local d = {id = 0, name = TR("sample_mind"), kind = "mind", nodes = {}, edges = {}, nextId = 1, updated = now() - 30,
             view = {x = 0, y = 0, z = 0.9}}
  local prev = doc
  doc = d
  local function m(text, parent, color)
    local n = {id = newId(), text = text, parent = parent, color = color or 1, collapsed = false}
    d.nodes[#d.nodes + 1] = n
    return n.id
  end
  local root = m(TR("sm_root"), nil, 1)
  local a = m(TR("sm_where"), root, 2)
  m(TR("sm_where1"), a); m(TR("sm_where2"), a)
  local b = m(TR("sm_pack"), root, 3)
  m(TR("sm_pack1"), b); m(TR("sm_pack2"), b); m(TR("sm_pack3"), b)
  local c = m(TR("sm_budget"), root, 5)
  m(TR("sm_budget1"), c); m(TR("sm_budget2"), c)
  local e = m(TR("sm_todo"), root, 8)
  m(TR("sm_todo1"), e); m(TR("sm_todo2"), e)
  doc = prev
  return d
end

local function saveNow()
  store.set("docs", docs)
  store.set("prefs", {snap = snap, grid = showGrid})
  dirty = false
end

local function loadDocs()
  local raw = store.get("docs", nil)
  docs = {}
  if type(raw) == "table" and #raw > 0 then
    for _, d in ipairs(raw) do
      if type(d) == "table" and type(d.nodes) == "table" then
        d.edges = type(d.edges) == "table" and d.edges or {}
        d.kind = d.kind == "mind" and "mind" or "flow"
        d.name = K.str(d.name, TR("untitled"))
        d.nextId = K.int(d.nextId, 1)
        d.view = type(d.view) == "table" and d.view or {x = 0, y = 0, z = 1}
        for _, n in ipairs(d.nodes) do if K.int(n.id, 0) >= d.nextId then d.nextId = n.id + 1 end end
        for _, e in ipairs(d.edges) do if K.int(e.id, 0) >= d.nextId then d.nextId = e.id + 1 end end
        docs[#docs + 1] = d
      end
    end
  end
  if #docs == 0 then
    docs[1] = sampleFlow()
    docs[2] = sampleMind()
  end
  for i, d in ipairs(docs) do d.id = i end
  local p = store.get("prefs", nil)
  if type(p) == "table" then snap = p.snap ~= false; showGrid = p.grid ~= false end
end

local function openDoc(d)
  doc = d
  screen = "editor"
  sel, selEdge, editing, drag = {}, nil, nil, nil
  hist:clear()
  mindKey = nil
  if d.kind == "mind" then for _, n in ipairs(d.nodes) do if not n.parent then sel = {[n.id] = true} end end end
end

local function newDoc(kind)
  local d = {id = #docs + 1, name = kind == "mind" and TR("new_mind") or TR("new_flow"), kind = kind, nodes = {}, edges = {},
             nextId = 1, updated = now(), view = {x = 0, y = 0, z = 1}}
  table.insert(docs, 1, d)
  openDoc(d)
  if kind == "mind" then
    d.nodes[1] = {id = newId(), text = TR("central_idea"), color = 1, collapsed = false}
    sel = {[d.nodes[1].id] = true}
    editing = {id = d.nodes[1].id, text = d.nodes[1].text}
    K.focus("ntext")
  end
  markDirty()
  audio.play("pop", 0.35)
end

-- ================================================================== geometry
local function toScreen(x, y) return view.ox + view.w / 2 + (x - doc.view.x) * doc.view.z, view.oy + view.h / 2 + (y - doc.view.y) * doc.view.z end
local function toWorld(sx, sy) return doc.view.x + (sx - view.ox - view.w / 2) / doc.view.z, doc.view.y + (sy - view.oy - view.h / 2) / doc.view.z end
local function snapV(v) if snap then return floor(v / GRID + 0.5) * GRID end return v end

-- where a ray from the centre of a node in direction (dx, dy) leaves its outline
local function boundary(n, dx, dy)
  local hw, hh = n.w / 2, n.h / 2
  local len = sqrt(dx * dx + dy * dy)
  if len < 1e-6 then return n.x, n.y end
  dx, dy = dx / len, dy / len
  local t
  if n.shape == "ellipse" then t = 1 / sqrt((dx / hw) ^ 2 + (dy / hh) ^ 2)
  elseif n.shape == "diamond" then t = 1 / (abs(dx) / hw + abs(dy) / hh)
  else t = min(abs(dx) > 1e-6 and hw / abs(dx) or 1e9, abs(dy) > 1e-6 and hh / abs(dy) or 1e9) end
  return n.x + dx * t, n.y + dy * t
end

-- the points of an edge in world coordinates
local function edgePoints(e)
  local a, b = nodeById(e.a), nodeById(e.b)
  if not a or not b then return nil end
  if e.route == 2 then
    local dx, dy = b.x - a.x, b.y - a.y
    if abs(dx) >= abs(dy) then
      local sx = a.x + (dx >= 0 and a.w / 2 or -a.w / 2)
      local ex = b.x - (dx >= 0 and b.w / 2 or -b.w / 2)
      local mx = (sx + ex) / 2
      return {sx, a.y, mx, a.y, mx, b.y, ex, b.y}
    else
      local sy = a.y + (dy >= 0 and a.h / 2 or -a.h / 2)
      local ey = b.y - (dy >= 0 and b.h / 2 or -b.h / 2)
      local my = (sy + ey) / 2
      return {a.x, sy, a.x, my, b.x, my, b.x, ey}
    end
  end
  local x1, y1 = boundary(a, b.x - a.x, b.y - a.y)
  local x2, y2 = boundary(b, a.x - b.x, a.y - b.y)
  return {x1, y1, x2, y2}
end

local function distSeg(px, py, x1, y1, x2, y2)
  local dx, dy = x2 - x1, y2 - y1
  local l2 = dx * dx + dy * dy
  local t = l2 > 0 and clamp(((px - x1) * dx + (py - y1) * dy) / l2, 0, 1) or 0
  local qx, qy = x1 + t * dx, y1 + t * dy
  return sqrt((px - qx) ^ 2 + (py - qy) ^ 2)
end

local function shapePoly(n, sx, sy, sw, sh)
  local x0, y0, x1, y1 = sx - sw / 2, sy - sh / 2, sx + sw / 2, sy + sh / 2
  if n.shape == "diamond" then return {sx, y0, x1, sy, sx, y1, x0, sy}
  elseif n.shape == "para" then local k = sw * 0.16; return {x0 + k, y0, x1, y0, x1 - k, y1, x0, y1}
  elseif n.shape == "hex" then local k = min(sw * 0.2, sh * 0.5); return {x0 + k, y0, x1 - k, y0, x1, sy, x1 - k, y1, x0 + k, y1, x0, sy}
  elseif n.shape == "ellipse" then
    local pts = {}
    for i = 0, 35 do
      local a = i / 36 * math.pi * 2
      pts[#pts + 1] = sx + math.cos(a) * sw / 2
      pts[#pts + 1] = sy + math.sin(a) * sh / 2
    end
    return pts
  end
  return nil
end

-- ================================================================== mind map layout
local function mindChildren(id)
  local out = {}
  for _, n in ipairs(doc.nodes) do if n.parent == id then out[#out + 1] = n end end
  return out
end
local function mindRoot()
  for _, n in ipairs(doc.nodes) do if not n.parent then return n end end
  return nil
end

local function layoutMind()
  local key = #doc.nodes .. ":" .. tostring(doc.updated) .. ":" .. tostring(theme.dark)
  if mindKey == key and mindLayout then return mindLayout end
  local L = {}
  local root = mindRoot()
  if not root then mindLayout, mindKey = L, key; return L end
  local kids = {}
  for _, n in ipairs(doc.nodes) do
    if n.parent then kids[n.parent] = kids[n.parent] or {}; table.insert(kids[n.parent], n) end
  end
  local function size(n, depth)
    local fs = depth == 0 and 18 or (depth == 1 and 15 or 13)
    local font = depth <= 1 and "semibold" or "medium"
    local tw = gfx.textWidth(n.text ~= "" and n.text or " ", fs, font)
    return min(260, tw + (depth == 0 and 44 or 28)), depth == 0 and 50 or (depth == 1 and 38 or 32), fs, font
  end
  local function measure(n, depth)
    local w, h, fs, font = size(n, depth)
    local e = {node = n, w = w, h = h, fs = fs, font = font, depth = depth, kids = {}}
    L[n.id] = e
    local sum = 0
    if not n.collapsed then
      for _, c in ipairs(kids[n.id] or {}) do
        local ce = measure(c, depth + 1)
        e.kids[#e.kids + 1] = ce
        sum = sum + ce.sh
      end
      sum = sum + max(0, #e.kids - 1) * 12
    end
    e.hidden = n.collapsed and #(kids[n.id] or {}) or 0
    e.sh = max(h, sum)
    return e
  end
  local function place(e, x, yc, dir, color)
    e.x, e.y, e.dir = x, yc, dir
    color = (e.node.color or 1) > 1 and e.node.color or color
    e.color = color
    local total = 0
    for _, c in ipairs(e.kids) do total = total + c.sh end
    total = total + max(0, #e.kids - 1) * 12
    local y = yc - total / 2
    for _, c in ipairs(e.kids) do
      local cx = x + dir * (e.w / 2 + 56 + c.w / 2)
      place(c, cx, y + c.sh / 2, dir, color)
      y = y + c.sh + 12
    end
  end
  local re = measure(root, 0)
  re.x, re.y, re.dir, re.color = 0, 0, 0, root.color
  local right, left = {}, {}
  for i, c in ipairs(re.kids) do if i <= math.ceil(#re.kids / 2) then right[#right + 1] = c else left[#left + 1] = c end end
  local function column(list, dir)
    local total = 0
    for _, c in ipairs(list) do total = total + c.sh end
    total = total + max(0, #list - 1) * 22
    local y = -total / 2
    for _, c in ipairs(list) do
      place(c, dir * (re.w / 2 + 70 + c.w / 2), y + c.sh / 2, dir, c.node.color > 1 and c.node.color or 2)
      y = y + c.sh + 22
    end
  end
  column(right, 1)
  column(left, -1)
  mindLayout, mindKey = L, key
  return L
end

-- ================================================================== selection helpers
local function selectedIds()
  local out = {}
  for _, n in ipairs(doc.nodes) do if sel[n.id] then out[#out + 1] = n.id end end
  return out
end
local function selCount() local c = 0; for _, n in ipairs(doc.nodes) do if sel[n.id] then c = c + 1 end end; return c end
local function firstSel()
  for _, n in ipairs(doc.nodes) do if sel[n.id] then return n end end
  return nil
end
local function nodeAtWorld(wx, wy)
  for i = #doc.nodes, 1, -1 do
    local n = doc.nodes[i]
    if abs(wx - n.x) <= n.w / 2 + 2 and abs(wy - n.y) <= n.h / 2 + 2 then return n end
  end
  return nil
end
local function edgeAtWorld(wx, wy)
  local tol = 8 / doc.view.z
  for i = #doc.edges, 1, -1 do
    local e = doc.edges[i]
    local p = edgePoints(e)
    if p then
      for k = 1, #p - 3, 2 do
        if distSeg(wx, wy, p[k], p[k + 1], p[k + 2], p[k + 3]) < tol then return e end
      end
    end
  end
  return nil
end
local function mindNodeAt(sx, sy)
  local L = layoutMind()
  for _, e in pairs(L) do
    if e.x then
      local px, py = toScreen(e.x, e.y)
      local z = doc.view.z
      if abs(sx - px) <= e.w * z / 2 + 3 and abs(sy - py) <= e.h * z / 2 + 3 then return e.node end
    end
  end
  return nil
end

-- ================================================================== editing operations
local function startEditing(id)
  local n = nodeById(id)
  if not n then return end
  editing = {id = id, text = n.text}
  K.focus("ntext")
end
local function startEditEdge(e)
  editing = {id = e.id, text = e.label or "", edge = true}
  K.focus("ntext")
end
local function commitEditing()
  if not editing then return end
  local ed = editing
  editing = nil
  if K.editing == "ntext" then K.blur() end
  if ed.edge then
    for _, e in ipairs(doc.edges) do
      if e.id == ed.id and e.label ~= ed.text then pushHist(); e.label = ed.text; markDirty() end
    end
    return
  end
  local n = nodeById(ed.id)
  if n and n.text ~= ed.text then pushHist(); n.text = ed.text; markDirty() end
end

local function deleteSelection()
  if doc.kind == "mind" then
    local n = firstSel()
    if not n or not n.parent then return end
    pushHist()
    local kill = {[n.id] = true}
    local changed = true
    while changed do
      changed = false
      for _, x in ipairs(doc.nodes) do
        if x.parent and kill[x.parent] and not kill[x.id] then kill[x.id] = true; changed = true end
      end
    end
    local parent = n.parent
    for i = #doc.nodes, 1, -1 do if kill[doc.nodes[i].id] then table.remove(doc.nodes, i) end end
    sel = {[parent] = true}
    markDirty()
    audio.play("trash", 0.3)
    return
  end
  if selEdge then
    pushHist()
    for i = #doc.edges, 1, -1 do if doc.edges[i].id == selEdge then table.remove(doc.edges, i) end end
    selEdge = nil
    markDirty()
    return
  end
  if selCount() == 0 then return end
  pushHist()
  for i = #doc.nodes, 1, -1 do if sel[doc.nodes[i].id] then table.remove(doc.nodes, i) end end
  for i = #doc.edges, 1, -1 do
    local e = doc.edges[i]
    if sel[e.a] or sel[e.b] then table.remove(doc.edges, i) end
  end
  sel = {}
  markDirty()
  audio.play("trash", 0.3)
end

local function copySelection()
  if doc.kind ~= "flow" or selCount() == 0 then return false end
  clip = {nodes = {}, edges = {}}
  for _, n in ipairs(doc.nodes) do if sel[n.id] then clip.nodes[#clip.nodes + 1] = K.copy(n) end end
  for _, e in ipairs(doc.edges) do if sel[e.a] and sel[e.b] then clip.edges[#clip.edges + 1] = K.copy(e) end end
  return true
end
local function paste(offset)
  if not clip or doc.kind ~= "flow" then return end
  pushHist()
  local map = {}
  sel = {}
  for _, n in ipairs(clip.nodes) do
    local c = K.copy(n)
    c.id = newId()
    c.x, c.y = c.x + (offset or 40), c.y + (offset or 40)
    map[n.id] = c.id
    doc.nodes[#doc.nodes + 1] = c
    sel[c.id] = true
  end
  for _, e in ipairs(clip.edges) do
    local c = K.copy(e)
    c.id = newId()
    c.a, c.b = map[e.a], map[e.b]
    if c.a and c.b then doc.edges[#doc.edges + 1] = c end
  end
  for _, n in ipairs(clip.nodes) do n.x, n.y = n.x + (offset or 40), n.y + (offset or 40) end
  selEdge = nil
  markDirty()
end
local function duplicate()
  if copySelection() then paste(40) end
end

local function undo()
  commitEditing()
  local s = hist:undo(snapshot())
  if s then applySnap(s); K.toast(TR("undone"), "undo") else K.toast(TR("nothing_undo"), "undo") end
end
local function redo()
  commitEditing()
  local s = hist:redo(snapshot())
  if s then applySnap(s); K.toast(TR("redone"), "redo") else K.toast(TR("nothing_redo"), "redo") end
end

-- place a new flow node near the middle of the view, avoiding others
local function addShape(shape)
  if doc.kind ~= "flow" then return end
  commitEditing()
  pushHist()
  local x, y = snapV(doc.view.x), snapV(doc.view.y)
  for _ = 1, 30 do
    local hit = false
    for _, n in ipairs(doc.nodes) do if abs(n.x - x) < 60 and abs(n.y - y) < 40 then hit = true end end
    if not hit then break end
    x, y = x + 40, y + 40
  end
  local n = addFlowNode(shape, x, y, "", 1)
  sel, selEdge = {[n.id] = true}, nil
  markDirty()
  startEditing(n.id)
end

-- a new node next to `from`, connected to it, in direction (dx, dy)
local function growFrom(from, dx, dy)
  pushHist()
  local gapX, gapY = from.w / 2 + 90, from.h / 2 + 70
  local n = addFlowNode(from.shape == "diamond" and "round" or from.shape, snapV(from.x + dx * (gapX + 60)), snapV(from.y + dy * (gapY + 30)), "", from.color)
  addEdge(from.id, n.id)
  sel, selEdge = {[n.id] = true}, nil
  markDirty()
  startEditing(n.id)
end

local function mindAdd(child)
  local cur = firstSel()
  if not cur then return end
  commitEditing()
  local parent = child and cur.id or cur.parent
  if not parent then parent = cur.id end
  pushHist()
  local n = {id = newId(), text = "", parent = parent, color = 1, collapsed = false}
  -- a sibling goes right after the current node
  if not child then
    local pos = #doc.nodes + 1
    for i, x in ipairs(doc.nodes) do if x == cur then pos = i + 1 end end
    table.insert(doc.nodes, pos, n)
  else
    cur.collapsed = false
    doc.nodes[#doc.nodes + 1] = n
  end
  sel = {[n.id] = true}
  markDirty()
  startEditing(n.id)
end

local function mindMove(dir)
  local cur = firstSel()
  if not cur then return end
  local L = layoutMind()
  local e = L[cur.id]
  if not e then return end
  local target = nil
  if dir == "left" or dir == "right" then
    local want = dir == "left" and -1 or 1
    if e.depth == 0 then
      for _, c in ipairs(e.kids) do if c.dir == want then target = c.node; break end end
    elseif e.dir == want then target = e.kids[1] and e.kids[1].node
    else target = nodeById(cur.parent) end
  else
    local best, bd = nil, math.huge
    for _, o in pairs(L) do
      if o ~= e and o.x and o.depth == e.depth and o.dir == e.dir then
        local d = o.y - e.y
        if (dir == "down" and d > 0 or dir == "up" and d < 0) and abs(d) < bd then best, bd = o, abs(d) end
      end
    end
    target = best and best.node
  end
  if target then sel = {[target.id] = true}; audio.play("click", 0.15) end
end

local function align(kind)
  local ids = selectedIds()
  if #ids < 2 then return end
  pushHist()
  local ns = {}
  for _, id in ipairs(ids) do ns[#ns + 1] = nodeById(id) end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, n in ipairs(ns) do
    x0, y0 = min(x0, n.x - n.w / 2), min(y0, n.y - n.h / 2)
    x1, y1 = max(x1, n.x + n.w / 2), max(y1, n.y + n.h / 2)
  end
  if kind == "left" then for _, n in ipairs(ns) do n.x = x0 + n.w / 2 end
  elseif kind == "hcenter" then for _, n in ipairs(ns) do n.x = (x0 + x1) / 2 end
  elseif kind == "right" then for _, n in ipairs(ns) do n.x = x1 - n.w / 2 end
  elseif kind == "top" then for _, n in ipairs(ns) do n.y = y0 + n.h / 2 end
  elseif kind == "vcenter" then for _, n in ipairs(ns) do n.y = (y0 + y1) / 2 end
  elseif kind == "bottom" then for _, n in ipairs(ns) do n.y = y1 - n.h / 2 end
  elseif kind == "hdist" and #ns >= 3 then
    table.sort(ns, function(a, b) return a.x < b.x end)
    local step = (ns[#ns].x - ns[1].x) / (#ns - 1)
    for i, n in ipairs(ns) do n.x = ns[1].x + (i - 1) * step end
  elseif kind == "vdist" and #ns >= 3 then
    table.sort(ns, function(a, b) return a.y < b.y end)
    local step = (ns[#ns].y - ns[1].y) / (#ns - 1)
    for i, n in ipairs(ns) do n.y = ns[1].y + (i - 1) * step end
  end
  markDirty()
end

local function toFront()
  if doc.kind ~= "flow" or selCount() == 0 then return end
  pushHist()
  local keep, front = {}, {}
  for _, n in ipairs(doc.nodes) do if sel[n.id] then front[#front + 1] = n else keep[#keep + 1] = n end end
  for _, n in ipairs(front) do keep[#keep + 1] = n end
  doc.nodes = keep
  markDirty()
end

local function fit()
  if not doc then return end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  if doc.kind == "mind" then
    for _, e in pairs(layoutMind()) do
      if e.x then x0, y0, x1, y1 = min(x0, e.x - e.w / 2), min(y0, e.y - e.h / 2), max(x1, e.x + e.w / 2), max(y1, e.y + e.h / 2) end
    end
  else
    for _, n in ipairs(doc.nodes) do
      x0, y0, x1, y1 = min(x0, n.x - n.w / 2), min(y0, n.y - n.h / 2), max(x1, n.x + n.w / 2), max(y1, n.y + n.h / 2)
    end
  end
  if x0 == math.huge then doc.view = {x = 0, y = 0, z = 1}; return end
  doc.view.x, doc.view.y = (x0 + x1) / 2, (y0 + y1) / 2
  doc.view.z = clamp(min((view.w - 60) / max(1, x1 - x0), (view.h - 60) / max(1, y1 - y0)), 0.25, 1.6)
end
local function zoomBy(f, sx, sy)
  sx, sy = sx or (view.ox + view.w / 2), sy or (view.oy + view.h / 2)
  local wx, wy = toWorld(sx, sy)
  doc.view.z = clamp(doc.view.z * f, 0.2, 3)
  local nx, ny = toWorld(sx, sy)
  doc.view.x, doc.view.y = doc.view.x + wx - nx, doc.view.y + wy - ny
end

-- ================================================================== export
local function xmlEsc(s) return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")) end

local function svgText(lines, cx, cy, fs, color, weight)
  local out = {}
  local lh = fs * 1.25
  local y0 = cy - (#lines - 1) * lh / 2 + fs * 0.35
  for i, l in ipairs(lines) do
    out[#out + 1] = string.format('<text x="%.1f" y="%.1f" font-family="sans-serif" font-size="%d" font-weight="%s" fill="%s" text-anchor="middle">%s</text>',
      cx, y0 + (i - 1) * lh, fs, weight or "normal", color, xmlEsc(l))
  end
  return table.concat(out, "\n")
end

-- naive word wrap by character count for the SVG (no font metrics outside the app)
local function wrapChars(s, width, fs)
  local maxc = max(4, floor(width / (fs * 0.56)))
  local lines, cur = {}, ""
  for word in tostring(s):gmatch("%S+") do
    if cur == "" then cur = word
    elseif K.ulen(cur) + 1 + K.ulen(word) <= maxc then cur = cur .. " " .. word
    else lines[#lines + 1] = cur; cur = word end
  end
  if cur ~= "" then lines[#lines + 1] = cur end
  return lines
end

local function exportSVG()
  if not doc then return end
  local parts = {}
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  local function grow(x, y, w, h) x0, y0, x1, y1 = min(x0, x - w / 2), min(y0, y - h / 2), max(x1, x + w / 2), max(y1, y + h / 2) end
  if doc.kind == "mind" then
    local L = layoutMind()
    for _, e in pairs(L) do if e.x then grow(e.x, e.y, e.w, e.h) end end
    for _, e in pairs(L) do
      if e.x then
        for _, c in ipairs(e.kids) do
          local sx, ex = e.x + (c.dir or 1) * e.w / 2, c.x - (c.dir or 1) * c.w / 2
          if e.depth == 0 then sx = e.x end
          local col = EXPORT[COLORS[c.color] or "blue"] or "#007AFF"
          parts[#parts + 1] = string.format('<path d="M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="%d"/>',
            sx, e.y, (sx + ex) / 2, e.y, (sx + ex) / 2, c.y, ex, c.y, col, e.depth == 0 and 4 or 2)
        end
      end
    end
    for _, e in pairs(L) do
      if e.x then
        local col = EXPORT[COLORS[e.depth == 0 and e.node.color or e.color] or "blue"] or "#007AFF"
        local fill = e.depth == 0 and col or "#FFFFFF"
        parts[#parts + 1] = string.format('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="%s" stroke="%s" stroke-width="2"/>',
          e.x - e.w / 2, e.y - e.h / 2, e.w, e.h, e.h / 2, fill, col)
        parts[#parts + 1] = svgText({e.node.text}, e.x, e.y, e.fs, e.depth == 0 and "#FFFFFF" or "#1C1C1E", e.depth <= 1 and "600" or "500")
      end
    end
  else
    for _, n in ipairs(doc.nodes) do grow(n.x, n.y, n.w, n.h) end
    parts[#parts + 1] = '<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M0 0 L10 5 L0 10 z" fill="context-stroke"/></marker></defs>'
    for _, e in ipairs(doc.edges) do
      local p = edgePoints(e)
      if p then
        local pts = {}
        for k = 1, #p, 2 do pts[#pts + 1] = string.format("%.1f,%.1f", p[k], p[k + 1]) end
        local col = EXPORT[COLORS[e.color] or "text"] or "#3A3A3C"
        local dash = e.style == 3 and ' stroke-dasharray="7 5"' or ""
        local mEnd = (e.style == 1 or e.style == 3 or e.style == 4) and ' marker-end="url(#a)"' or ""
        local mStart = e.style == 4 and ' marker-start="url(#a)"' or ""
        parts[#parts + 1] = string.format('<polyline points="%s" fill="none" stroke="%s" stroke-width="2"%s%s%s/>', table.concat(pts, " "), col, dash, mEnd, mStart)
        if e.label and e.label ~= "" then
          local mx, my = (p[3] + (p[5] or p[1])) / 2, (p[4] + (p[6] or p[2])) / 2
          if #p == 4 then mx, my = (p[1] + p[3]) / 2, (p[2] + p[4]) / 2 end
          parts[#parts + 1] = string.format('<rect x="%.1f" y="%.1f" width="%.1f" height="20" rx="6" fill="#FFFFFF"/>', mx - K.ulen(e.label) * 3.6 - 6, my - 10, K.ulen(e.label) * 7.2 + 12)
          parts[#parts + 1] = svgText({e.label}, mx, my, 12, col, "500")
        end
      end
    end
    for _, n in ipairs(doc.nodes) do
      local col = EXPORT[COLORS[n.color] or "text"] or "#3A3A3C"
      local fill = n.shape == "note" and "#FFF6C9" or (n.color == 1 and "#FFFFFF" or col .. "22")
      local x, y, w, h = n.x - n.w / 2, n.y - n.h / 2, n.w, n.h
      local poly = shapePoly(n, n.x, n.y, n.w, n.h)
      if n.shape == "text" then
      elseif poly then
        local pts = {}
        for k = 1, #poly, 2 do pts[#pts + 1] = string.format("%.1f,%.1f", poly[k], poly[k + 1]) end
        parts[#parts + 1] = string.format('<polygon points="%s" fill="%s" stroke="%s" stroke-width="2"/>', table.concat(pts, " "), fill, col)
      elseif n.shape == "cylinder" then
        local ry = min(12, h * 0.15)
        parts[#parts + 1] = string.format('<path d="M%.1f %.1f A%.1f %.1f 0 0 0 %.1f %.1f L%.1f %.1f A%.1f %.1f 0 0 1 %.1f %.1f Z" fill="%s" stroke="%s" stroke-width="2"/>',
          x, y + ry, w / 2, ry, x + w, y + ry, x + w, y + h - ry, w / 2, ry, x, y + h - ry, fill, col)
        parts[#parts + 1] = string.format('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" stroke="%s" stroke-width="2"/>', n.x, y + ry, w / 2, ry, fill, col)
      else
        local r = n.shape == "round" and min(18, h / 2) or (n.shape == "note" and 2 or 4)
        parts[#parts + 1] = string.format('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="%.1f" fill="%s" stroke="%s" stroke-width="2"/>', x, y, w, h, r, fill, col)
      end
      local fs = SIZES[n.size or 2] or 15
      parts[#parts + 1] = svgText(wrapChars(n.text, n.w - 20, fs), n.x, n.y, fs, "#1C1C1E", "500")
    end
  end
  if x0 == math.huge then x0, y0, x1, y1 = 0, 0, 100, 100 end
  local pad = 30
  local svg = string.format('<?xml version="1.0" encoding="UTF-8"?>\n<svg xmlns="http://www.w3.org/2000/svg" viewBox="%.1f %.1f %.1f %.1f" width="%d" height="%d">\n<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#FFFFFF"/>\n%s\n</svg>\n',
    x0 - pad, y0 - pad, x1 - x0 + pad * 2, y1 - y0 + pad * 2, floor(x1 - x0 + pad * 2), floor(y1 - y0 + pad * 2),
    x0 - pad, y0 - pad, x1 - x0 + pad * 2, y1 - y0 + pad * 2, table.concat(parts, "\n"))
  local fname = doc.name:gsub("[/\\:%*%?\"<>|]", "-") .. ".svg"
  ui.saveFile(function(p)
    if not p then return end
    if not p:lower():match("%.svg$") then p = p .. ".svg" end
    if fs.write(p, svg) then K.toast(TR("exported"), "ios_share") else K.toast(TR("write_failed"), "error") end
  end, fname, TR("export_svg"))
end

local function mermaid()
  if not doc then return end
  local out = {}
  if doc.kind == "mind" then
    out[1] = "mindmap"
    local function walk(id, depth)
      for _, n in ipairs(doc.nodes) do
        if n.parent == id then
          out[#out + 1] = string.rep("  ", depth) .. (n.text ~= "" and n.text or "?")
          walk(n.id, depth + 1)
        end
      end
    end
    local r = mindRoot()
    if r then out[#out + 1] = "  root((" .. r.text .. "))"; walk(r.id, 2) end
  else
    out[1] = "flowchart TD"
    local wrap = {rect = {"[", "]"}, round = {"(", ")"}, ellipse = {"([", "])"}, diamond = {"{", "}"}, para = {"[/", "/]"},
                  hex = {"{{", "}}"}, note = {"[", "]"}, cylinder = {"[(", ")]"}, text = {"[", "]"}}
    for _, n in ipairs(doc.nodes) do
      local w = wrap[n.shape] or wrap.rect
      out[#out + 1] = string.format('  n%d%s"%s"%s', n.id, w[1], tostring(n.text):gsub('"', "'"), w[2])
    end
    for _, e in ipairs(doc.edges) do
      local arrow = (e.style == 2) and "---" or (e.style == 3 and "-.->" or (e.style == 4 and "<-->" or "-->"))
      if e.label and e.label ~= "" then out[#out + 1] = string.format("  n%d %s|%s| n%d", e.a, arrow, e.label, e.b)
      else out[#out + 1] = string.format("  n%d %s n%d", e.a, arrow, e.b) end
    end
  end
  sys.clipboard(table.concat(out, "\n"))
  K.toast(TR("mermaid_copied"), "content_copy")
end

local function exportFile()
  if not doc then return end
  ui.saveFile(function(p)
    if not p then return end
    if not p:lower():match("%.flowmap$") and not p:lower():match("%.json$") then p = p .. ".flowmap" end
    local d = {app = "flowmap", version = 1, name = doc.name, kind = doc.kind, nodes = doc.nodes, edges = doc.edges, nextId = doc.nextId}
    if fs.write(p, json.encode(d, true)) then K.toast(TR("saved_file"), "save") else K.toast(TR("write_failed"), "error") end
  end, doc.name:gsub("[/\\:%*%?\"<>|]", "-") .. ".flowmap", TR("save_file"))
end

local function importPath(p)
  local text = fs.read(p)
  local d = text and json.decode(text)
  if type(d) ~= "table" or type(d.nodes) ~= "table" then K.toast(TR("not_flowmap"), "error"); return end
  local nd = {id = #docs + 1, name = K.str(d.name, K.baseName(p)), kind = d.kind == "mind" and "mind" or "flow",
              nodes = d.nodes, edges = type(d.edges) == "table" and d.edges or {}, nextId = K.int(d.nextId, 1),
              updated = now(), view = {x = 0, y = 0, z = 1}}
  for _, n in ipairs(nd.nodes) do if K.int(n.id, 0) >= nd.nextId then nd.nextId = n.id + 1 end end
  table.insert(docs, 1, nd)
  openDoc(nd)
  markDirty()
  K.toast(TR("opened", nd.name), "file_open")
end
local function importFile()
  ui.openFile(function(p) if p then importPath(p) end end, {".flowmap", ".json"}, TR("open_file"))
end

-- ================================================================== drawing: shapes
local function drawNodeShape(n, sx, sy, sw, sh, selected, z)
  local col = colorOf(n.color)
  local fill = n.color == 1 and theme.window or mix(theme.window, col, theme.dark and 0.28 or 0.16)
  if n.shape == "note" then fill = theme.dark and "#5C5124" or "#FFF3B8" end
  local stroke = selected and theme.accent or (n.color == 1 and alpha(theme.text, 0.55) or col)
  local lw = selected and 2.5 or 1.6
  local poly = shapePoly(n, sx, sy, sw, sh)
  if n.shape == "text" then
    if selected then gfx.color(alpha(theme.accent, 0.6)); gfx.rectLine(sx - sw / 2, sy - sh / 2, sw, sh, 6, 1.5) end
  elseif poly then
    gfx.poly(poly, fill)
    gfx.color(stroke)
    gfx.lines(poly, lw, true)
  elseif n.shape == "cylinder" then
    local ry = min(12 * z, sh * 0.15)
    gfx.rect(sx - sw / 2, sy - sh / 2 + ry, sw, sh - ry * 2, 0, fill)
    local top, bot = {}, {}
    for i = 0, 24 do
      local a = i / 24 * math.pi * 2
      top[#top + 1] = sx + math.cos(a) * sw / 2; top[#top + 1] = sy - sh / 2 + ry + math.sin(a) * ry
    end
    for i = 0, 12 do
      local a = i / 12 * math.pi
      bot[#bot + 1] = sx + math.cos(a) * sw / 2; bot[#bot + 1] = sy + sh / 2 - ry + math.sin(a) * ry
    end
    gfx.poly(bot, fill)
    gfx.poly(top, mix(fill, col, 0.15))
    gfx.color(stroke)
    gfx.lines(top, lw, true)
    gfx.lines(bot, lw, false)
    gfx.line(sx - sw / 2, sy - sh / 2 + ry, sx - sw / 2, sy + sh / 2 - ry, lw)
    gfx.line(sx + sw / 2, sy - sh / 2 + ry, sx + sw / 2, sy + sh / 2 - ry, lw)
  else
    local r = (n.shape == "round") and min(18 * z, sh / 2) or (n.shape == "note" and 3 or 5)
    if n.shape == "note" then gfx.shadow(sx - sw / 2, sy - sh / 2, sw, sh, r, 8, 3) end
    gfx.rect(sx - sw / 2, sy - sh / 2, sw, sh, r, fill)
    gfx.color(stroke)
    gfx.rectLine(sx - sw / 2, sy - sh / 2, sw, sh, r, lw)
    if n.shape == "note" then
      local k = 16 * z
      gfx.poly({sx + sw / 2 - k, sy + sh / 2, sx + sw / 2, sy + sh / 2 - k, sx + sw / 2, sy + sh / 2}, mix(fill, "#000000", 0.12))
    end
  end
end

local function drawArrowHead(x1, y1, x2, y2, size, color)
  local dx, dy = x2 - x1, y2 - y1
  local l = sqrt(dx * dx + dy * dy)
  if l < 1e-3 then return end
  dx, dy = dx / l, dy / l
  local bx, by = x2 - dx * size, y2 - dy * size
  gfx.poly({x2, y2, bx - dy * size * 0.5, by + dx * size * 0.5, bx + dy * size * 0.5, by - dx * size * 0.5}, color)
end

local function drawEdge(e, z)
  local p = edgePoints(e)
  if not p then return end
  local sp = {}
  for k = 1, #p, 2 do
    local x, y = toScreen(p[k], p[k + 1])
    sp[#sp + 1] = x; sp[#sp + 1] = y
  end
  local selected = selEdge == e.id
  local col = selected and theme.accent or (e.color == 1 and alpha(theme.text, 0.7) or colorOf(e.color))
  local lw = selected and 3 or 2
  if e.style == 3 then
    for k = 1, #sp - 3, 2 do
      local x1, y1, x2, y2 = sp[k], sp[k + 1], sp[k + 2], sp[k + 3]
      local l = sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
      local n = max(1, floor(l / 12))
      gfx.color(col)
      for i = 0, n - 1, 2 do
        local t0, t1 = i / n, min(1, (i + 1) / n)
        gfx.line(x1 + (x2 - x1) * t0, y1 + (y2 - y1) * t0, x1 + (x2 - x1) * t1, y1 + (y2 - y1) * t1, lw)
      end
    end
  else
    gfx.color(col)
    gfx.lines(sp, lw, false)
  end
  local hs = clamp(11 * z, 7, 16)
  if e.style ~= 2 then drawArrowHead(sp[#sp - 3], sp[#sp - 2], sp[#sp - 1], sp[#sp], hs, col) end
  if e.style == 4 then drawArrowHead(sp[3], sp[4], sp[1], sp[2], hs, col) end
  if e.label and e.label ~= "" then
    local mx, my
    if #sp == 4 then mx, my = (sp[1] + sp[3]) / 2, (sp[2] + sp[4]) / 2
    else mx, my = (sp[3] + sp[5]) / 2, (sp[4] + sp[6]) / 2 end
    local fs = clamp(floor(12 * z + 0.5), 9, 18)
    local tw = gfx.textWidth(e.label, fs, "medium")
    gfx.rect(mx - tw / 2 - 6, my - fs * 0.75, tw + 12, fs * 1.5, 6, theme.bg)
    gfx.color(col)
    gfx.text(e.label, mx - tw / 2, my - fs * 0.62, fs, "medium")
  end
end

local function nodeText(n, sx, sy, sw, sh, z, color)
  local fs = clamp(floor((SIZES[n.size or 2] or 15) * z + 0.5), 7, 40)
  if fs < 8 or n.text == "" then return end
  local font = (n.size or 2) == 3 and "semibold" or "medium"
  local tw = sw - 16 * z
  local th = gfx.measureWrap(n.text, tw, fs, font)
  gfx.color(color or theme.text)
  gfx.clip(sx - sw / 2, sy - sh / 2, sw, sh)
  gfx.wrap(n.text, sx - tw / 2, sy - min(th, sh) / 2, tw, fs, font, "center")
  gfx.unclip()
end

-- ================================================================== drawing: canvas
local function drawGrid(x, y, w, h)
  if not showGrid then return end
  local z = doc.view.z
  local step = GRID * z
  while step < 14 do step = step * 2 end
  local wx0, wy0 = toWorld(x, y)
  local sx0, sy0 = toScreen(floor(wx0 / GRID) * GRID, floor(wy0 / GRID) * GRID)
  gfx.color(alpha(theme.text, theme.dark and 0.09 or 0.07))
  local cols, rows = floor(w / step) + 2, floor(h / step) + 2
  if cols * rows > 6000 then return end
  for i = 0, cols do
    local gx = sx0 + i * step
    for j = 0, rows do gfx.rect(gx - 1, sy0 + j * step - 1, 2, 2) end
  end
end

local function drawFlow(x, y, w, h)
  local z = doc.view.z
  for _, e in ipairs(doc.edges) do drawEdge(e, z) end
  for _, n in ipairs(doc.nodes) do
    local sx, sy = toScreen(n.x, n.y)
    local sw, sh = n.w * z, n.h * z
    if sx + sw / 2 > x and sx - sw / 2 < x + w and sy + sh / 2 > y and sy - sh / 2 < y + h then
      drawNodeShape(n, sx, sy, sw, sh, sel[n.id], z)
      if not (editing and editing.id == n.id and not editing.edge) then nodeText(n, sx, sy, sw, sh, z) end
    end
  end
  -- handles of a single selected node: grow buttons and the resize corner
  if selCount() == 1 and not drag then
    local n = firstSel()
    if n then
      local sx, sy = toScreen(n.x, n.y)
      local sw, sh = n.w * z, n.h * z
      for _, d in ipairs({{1, 0}, {0, 1}, {-1, 0}, {0, -1}}) do
        local hx, hy = sx + d[1] * (sw / 2 + 18), sy + d[2] * (sh / 2 + 18)
        gfx.circle(hx, hy, 11, theme.accent)
        gfx.icon("add", hx, hy, 16, "#FFFFFF")
      end
      gfx.rect(sx + sw / 2 - 6, sy + sh / 2 - 6, 12, 12, 3, theme.window)
      gfx.color(theme.accent)
      gfx.rectLine(sx + sw / 2 - 6, sy + sh / 2 - 6, 12, 12, 3, 2)
    end
  end
end

local function drawMind(x, y, w, h)
  local L = layoutMind()
  local z = doc.view.z
  -- branches
  for _, e in pairs(L) do
    if e.x then
      for _, c in ipairs(e.kids) do
        local sx = e.depth == 0 and e.x or e.x + c.dir * e.w / 2
        local ex = c.x - c.dir * c.w / 2
        local pts = {}
        for i = 0, 16 do
          local t = i / 16
          local mt = 1 - t
          local bx = mt * mt * mt * sx + 3 * mt * mt * t * (sx + ex) / 2 + 3 * mt * t * t * (sx + ex) / 2 + t * t * t * ex
          local by = mt * mt * mt * e.y + 3 * mt * mt * t * e.y + 3 * mt * t * t * c.y + t * t * t * c.y
          local px, py = toScreen(bx, by)
          pts[#pts + 1] = px; pts[#pts + 1] = py
        end
        gfx.color(alpha(colorOf(c.color), 0.85))
        gfx.lines(pts, clamp((e.depth == 0 and 4 or 2.2) * z, 1, 6), false)
      end
    end
  end
  for _, e in pairs(L) do
    if e.x then
      local sx, sy = toScreen(e.x, e.y)
      local sw, sh = e.w * z, e.h * z
      local col = colorOf(e.depth == 0 and e.node.color or e.color)
      local selected = sel[e.node.id]
      if e.depth == 0 then
        gfx.shadow(sx - sw / 2, sy - sh / 2, sw, sh, sh / 2, 12, 4)
        gfx.rect(sx - sw / 2, sy - sh / 2, sw, sh, sh / 2, e.node.color == 1 and theme.accent or col)
      elseif e.depth == 1 then
        gfx.rect(sx - sw / 2, sy - sh / 2, sw, sh, sh / 2, mix(theme.window, col, theme.dark and 0.3 or 0.18))
        gfx.color(col); gfx.rectLine(sx - sw / 2, sy - sh / 2, sw, sh, sh / 2, 2)
      else
        gfx.rect(sx - sw / 2, sy - sh / 2, sw, sh, sh / 2, theme.window)
        gfx.color(alpha(col, 0.7)); gfx.rectLine(sx - sw / 2, sy - sh / 2, sw, sh, sh / 2, 1.4)
      end
      if selected then gfx.color(theme.accent); gfx.rectLine(sx - sw / 2 - 4, sy - sh / 2 - 4, sw + 8, sh + 8, sh / 2 + 4, 2.5) end
      if not (editing and editing.id == e.node.id) then
        local fs = clamp(floor(e.fs * z + 0.5), 7, 40)
        if fs >= 8 then
          gfx.color(e.depth == 0 and "#FFFFFF" or theme.text)
          local label = K.ellipsize(e.node.text ~= "" and e.node.text or "…", fs, e.font, sw - 16 * z)
          gfx.text(label, sx - sw / 2, sy - fs * 0.62, fs, e.font, "center", sw)
        end
      end
      if e.hidden > 0 then
        local bx = sx + (e.dir >= 0 and 1 or -1) * (sw / 2 + 14)
        gfx.circle(bx, sy, 11, col)
        gfx.color(K.onColor(col))
        gfx.text(tostring(e.hidden), bx - 11, sy - 8, 11, "bold", "center", 22)
      end
    end
  end
end

-- the text field over the node being edited
local function drawEditField()
  if not editing then return end
  local cx, cy, fw
  if editing.edge then
    local e
    for _, x in ipairs(doc.edges) do if x.id == editing.id then e = x end end
    local p = e and edgePoints(e)
    if not p then editing = nil; return end
    local mx, my = (p[1] + p[#p - 1]) / 2, (p[2] + p[#p]) / 2
    cx, cy = toScreen(mx, my)
    fw = 180
  elseif doc.kind == "mind" then
    local e = layoutMind()[editing.id]
    if not e or not e.x then editing = nil; return end
    cx, cy = toScreen(e.x, e.y)
    fw = max(180, e.w * doc.view.z + 40)
  else
    local n = nodeById(editing.id)
    if not n then editing = nil; return end
    cx, cy = toScreen(n.x, n.y)
    fw = max(180, n.w * doc.view.z)
  end
  fw = min(fw, view.w - 20)
  local fx = clamp(cx - fw / 2, view.ox + 10, view.ox + view.w - fw - 10)
  local fy = clamp(cy - 17, view.oy + 10, view.oy + view.h - 44)
  gfx.shadow(fx, fy, fw, 34, 8, 10, 3)
  local nt, sub = K.field("ntext", editing.text, fx, fy, fw, 34, TR("text_ph"))
  editing.text = nt
  if sub then
    local wasMind = doc.kind == "mind"
    commitEditing()
    if wasMind then audio.play("click", 0.2) end
  end
end

-- ================================================================== canvas interaction
local function canvasInput(x, y, w, h)
  local hit = ui.hit("canvas", x, y, w, h)
  local mx, my = ui.mouse()
  local z = doc.view.z
  if hit.pressed then
    commitEditing()
    local wx, wy = toWorld(mx, my)
    drag = {sx = mx, sy = my, moved = false, vx = doc.view.x, vy = doc.view.y}
    if doc.kind == "mind" then
      local n = mindNodeAt(mx, my)
      if n then drag.kind = "mindsel"; drag.node = n else drag.kind = "pan" end
    else
      -- handles of the single selected node first
      local one = selCount() == 1 and firstSel() or nil
      if one then
        local sx, sy = toScreen(one.x, one.y)
        local sw, sh = one.w * z, one.h * z
        if abs(mx - (sx + sw / 2)) < 12 and abs(my - (sy + sh / 2)) < 12 then
          drag.kind, drag.node, drag.w0, drag.h0 = "resize", one, one.w, one.h
        else
          for _, d in ipairs({{1, 0}, {0, 1}, {-1, 0}, {0, -1}}) do
            local hx, hy = sx + d[1] * (sw / 2 + 18), sy + d[2] * (sh / 2 + 18)
            if (mx - hx) ^ 2 + (my - hy) ^ 2 < 16 * 16 then drag.kind, drag.node, drag.dir = "connect", one, d end
          end
        end
      end
      if not drag.kind then
        local n = nodeAtWorld(wx, wy)
        if n then
          drag.wasOnly = sel[n.id] and selCount() == 1
          if pressShift or boxMode then
            if sel[n.id] then sel[n.id] = nil else sel[n.id] = true end
          elseif not sel[n.id] then
            sel = {[n.id] = true}
          end
          selEdge = nil
          drag.kind = "move"
          drag.orig = {}
          for _, m in ipairs(doc.nodes) do if sel[m.id] then drag.orig[m.id] = {m.x, m.y} end end
        else
          local e = edgeAtWorld(wx, wy)
          if e then selEdge, sel = e.id, {}; drag.kind = "edge"
          elseif pressShift or boxMode then drag.kind = "marquee"
          else drag.kind = "pan" end
        end
      end
    end
  end
  if hit.held and drag then
    local dx, dy = mx - drag.sx, my - drag.sy
    if not drag.moved and abs(dx) + abs(dy) > 6 then
      drag.moved = true
      if drag.kind == "move" or drag.kind == "resize" then pushHist() end
    end
    if drag.moved then
      if drag.kind == "pan" then
        doc.view.x, doc.view.y = drag.vx - dx / z, drag.vy - dy / z
      elseif drag.kind == "move" then
        for id, o in pairs(drag.orig) do
          local n = nodeById(id)
          if n then n.x, n.y = snapV(o[1] + dx / z), snapV(o[2] + dy / z) end
        end
        markDirty()
      elseif drag.kind == "resize" then
        local n = drag.node
        n.w = max(40, snapV(drag.w0 + dx * 2 / z))
        n.h = max(30, snapV(drag.h0 + dy * 2 / z))
        markDirty()
      elseif drag.kind == "marquee" then
        drag.mx, drag.my = mx, my
      end
    end
  end
  if drag and drag.kind == "connect" and hit.held then drag.cx, drag.cy = mx, my end
  if hit.clicked or (drag and not hit.held and not hit.pressed) then
    local d = drag
    drag = nil
    if d then
      if d.kind == "connect" then
        if d.moved then
          local wx, wy = toWorld(mx, my)
          local target = nodeAtWorld(wx, wy)
          if target and target ~= d.node then
            pushHist()
            addEdge(d.node.id, target.id)
            markDirty()
            audio.play("click", 0.3)
          elseif not target then
            pushHist()
            local n = addFlowNode(d.node.shape == "diamond" and "round" or d.node.shape, snapV(wx), snapV(wy), "", d.node.color)
            addEdge(d.node.id, n.id)
            sel, selEdge = {[n.id] = true}, nil
            markDirty()
            startEditing(n.id)
          end
        else
          growFrom(d.node, d.dir[1], d.dir[2])
        end
      elseif d.kind == "mindsel" and not d.moved then
        if sel[d.node.id] and hit.clicked then startEditing(d.node.id) else sel = {[d.node.id] = true} end
      elseif d.kind == "pan" and not d.moved then
        if doc.kind == "flow" and hit.doubleClicked then
          local wx, wy = toWorld(mx, my)
          pushHist()
          local n = addFlowNode("round", snapV(wx), snapV(wy), "", 1)
          sel, selEdge = {[n.id] = true}, nil
          markDirty()
          startEditing(n.id)
        elseif doc.kind == "flow" then sel, selEdge = {}, nil end
      elseif d.kind == "move" and not d.moved then
        -- a second tap on the only selected shape (or a double tap) edits its text
        if (hit.doubleClicked or (d.wasOnly and hit.clicked)) and selCount() == 1 then startEditing(firstSel().id) end
      elseif d.kind == "edge" and not d.moved and hit.doubleClicked then
        for _, e in ipairs(doc.edges) do if e.id == selEdge then startEditEdge(e) end end
      elseif d.kind == "marquee" and d.mx then
        local ax, ay = toWorld(min(d.sx, d.mx), min(d.sy, d.my))
        local bx, by = toWorld(max(d.sx, d.mx), max(d.sy, d.my))
        sel = {}
        for _, n in ipairs(doc.nodes) do
          if n.x >= ax and n.x <= bx and n.y >= ay and n.y <= by then sel[n.id] = true end
        end
      end
    end
  end
  if hit.rightClicked then
    local wx, wy = toWorld(mx, my)
    local n = doc.kind == "flow" and nodeAtWorld(wx, wy) or mindNodeAt(mx, my)
    if n then
      if not sel[n.id] then sel = {[n.id] = true} end
      local items = {{label = TR("edit_text"), id = 1, icon = "edit"}}
      if doc.kind == "flow" then
        items[#items + 1] = {label = TR("duplicate"), id = 2, icon = "content_copy"}
        items[#items + 1] = {label = TR("to_front"), id = 3, icon = "flip_to_front"}
      else
        items[#items + 1] = {label = TR("add_child"), id = 5, icon = "subdirectory_arrow_right"}
        items[#items + 1] = {label = n.collapsed and TR("expand") or TR("collapse"), id = 6, icon = "unfold_less"}
      end
      items[#items + 1] = "-"
      items[#items + 1] = {label = TR("delete"), id = 4, icon = "delete"}
      ui.contextMenu(items, function(id)
        if id == 1 then startEditing(n.id) elseif id == 2 then duplicate() elseif id == 3 then toFront()
        elseif id == 4 then deleteSelection() elseif id == 5 then mindAdd(true)
        elseif id == 6 then pushHist(); n.collapsed = not n.collapsed; markDirty() end
      end)
    end
  end
  -- live feedback of connect / marquee drags
  if drag and drag.kind == "connect" and drag.cx then
    local sx, sy = toScreen(drag.node.x, drag.node.y)
    gfx.color(alpha(theme.accent, 0.8))
    gfx.line(sx, sy, drag.cx, drag.cy, 2)
    gfx.circle(drag.cx, drag.cy, 6, theme.accent)
  elseif drag and drag.kind == "marquee" and drag.mx then
    local x0, y0 = min(drag.sx, drag.mx), min(drag.sy, drag.my)
    gfx.rect(x0, y0, abs(drag.mx - drag.sx), abs(drag.my - drag.sy), 4, alpha(theme.accent, 0.12))
    gfx.color(theme.accent)
    gfx.rectLine(x0, y0, abs(drag.mx - drag.sx), abs(drag.my - drag.sy), 4, 1.5)
  end
end

-- ================================================================== properties panel
local function swatches(x, y, w, current, fn)
  local s = 26
  local per = max(1, floor((w + 6) / (s + 6)))
  for i = 1, #COLORS do
    local cx = x + ((i - 1) % per) * (s + 6)
    local cy = y + floor((i - 1) / per) * (s + 6)
    local hit = ui.hit("sw" .. i, cx, cy, s, s)
    gfx.circle(cx + s / 2, cy + s / 2, s / 2 - 2, colorOf(i))
    if i == 1 then gfx.circle(cx + s / 2, cy + s / 2, s / 2 - 6, theme.window) end
    if current == i then gfx.color(theme.text); gfx.circleLine(cx + s / 2, cy + s / 2, s / 2, 2) end
    if hit.clicked then fn(i) end
  end
  return math.ceil(#COLORS / per) * (s + 6)
end

local function drawPanel(x, y, w, h)
  gfx.rect(x, y, w, h, 0, theme.sidebar)
  gfx.color(theme.separator); gfx.line(x, y, x, y + h, 1)
  local p = 14
  local yy = y + 14
  local iw = w - p * 2
  local function heading(s) K.heading(s, x + p, yy, iw); yy = yy + 22 end
  local n = firstSel()
  local count = selCount()
  if doc.kind == "mind" then
    if not n then K.empty("touch_app", TR("select_hint"), nil, x, y, w, h); return end
    heading(TR("p_topic"))
    if ui.button(TR("edit_text"), x + p, yy, iw, 32, "default", "edit") then startEditing(n.id) end
    yy = yy + 40
    if ui.button(TR("add_child"), x + p, yy, iw, 32, "primary", "subdirectory_arrow_right") then mindAdd(true) end
    yy = yy + 40
    if n.parent and ui.button(TR("add_sibling"), x + p, yy, iw, 32, "default", "add") then mindAdd(false) end
    if n.parent then yy = yy + 40 end
    if #mindChildren(n.id) > 0 then
      if ui.button(n.collapsed and TR("expand") or TR("collapse"), x + p, yy, iw, 32, "default", n.collapsed and "unfold_more" or "unfold_less") then
        pushHist(); n.collapsed = not n.collapsed; markDirty()
      end
      yy = yy + 40
    end
    yy = yy + 6
    heading(TR("p_color"))
    yy = yy + swatches(x + p, yy, iw, n.color, function(i) pushHist(); n.color = i; markDirty() end) + 8
    if n.parent and ui.button(TR("delete"), x + p, yy, iw, 32, "destructive", "delete") then deleteSelection() end
    return
  end
  if selEdge then
    local e
    for _, x2 in ipairs(doc.edges) do if x2.id == selEdge then e = x2 end end
    if not e then selEdge = nil; return end
    heading(TR("p_connector"))
    local st = ui.segmented("estyle", {"→", "—", "⇢", "↔"}, e.style, x + p, yy, iw, 30)
    if st ~= e.style then pushHist(); e.style = st; markDirty() end
    yy = yy + 40
    local rt = ui.segmented("eroute", {TR("straight"), TR("elbow")}, e.route, x + p, yy, iw, 30)
    if rt ~= e.route then pushHist(); e.route = rt; markDirty() end
    yy = yy + 44
    heading(TR("p_label"))
    if ui.button(e.label ~= "" and K.ellipsize(e.label, 13, "medium", iw - 50) or TR("add_label"), x + p, yy, iw, 32, "default", "label") then startEditEdge(e) end
    yy = yy + 44
    heading(TR("p_color"))
    yy = yy + swatches(x + p, yy, iw, e.color, function(i) pushHist(); e.color = i; markDirty() end) + 8
    if ui.button(TR("reverse"), x + p, yy, iw, 32, "default", "swap_horiz") then pushHist(); e.a, e.b = e.b, e.a; markDirty() end
    yy = yy + 40
    if ui.button(TR("delete"), x + p, yy, iw, 32, "destructive", "delete") then deleteSelection() end
    return
  end
  if count == 0 then
    K.empty("touch_app", TR("select_hint"), TR("select_hint2"), x, y, w, h)
    return
  end
  if count > 1 then
    heading(TR("p_selection", count))
    local tools = {{"align_horizontal_left", "left"}, {"align_horizontal_center", "hcenter"}, {"align_horizontal_right", "right"},
                   {"align_vertical_top", "top"}, {"align_vertical_center", "vcenter"}, {"align_vertical_bottom", "bottom"}}
    local bw = floor((iw - 10) / 3)
    for i, t in ipairs(tools) do
      local bx = x + p + ((i - 1) % 3) * (bw + 5)
      local by = yy + floor((i - 1) / 3) * 38
      if ui.iconButton(t[1], bx, by, bw, 34, theme.text2, false, "##al" .. i) then align(t[2]) end
    end
    yy = yy + 80
    if ui.button(TR("dist_h"), x + p, yy, iw, 32, "default", "horizontal_distribute") then align("hdist") end
    yy = yy + 38
    if ui.button(TR("dist_v"), x + p, yy, iw, 32, "default", "vertical_distribute") then align("vdist") end
    yy = yy + 46
    heading(TR("p_color"))
    yy = yy + swatches(x + p, yy, iw, 0, function(i)
      pushHist()
      for _, m in ipairs(doc.nodes) do if sel[m.id] then m.color = i end end
      markDirty()
    end) + 8
    if ui.button(TR("duplicate"), x + p, yy, iw, 32, "default", "content_copy") then duplicate() end
    yy = yy + 38
    if ui.button(TR("delete"), x + p, yy, iw, 32, "destructive", "delete") then deleteSelection() end
    return
  end
  heading(TR("p_shape"))
  if ui.button(n.text ~= "" and K.ellipsize(n.text, 13, "medium", iw - 50) or TR("add_text"), x + p, yy, iw, 32, "default", "edit") then startEditing(n.id) end
  yy = yy + 42
  local s = 36
  local per = max(1, floor((iw + 6) / (s + 6)))
  for i, shp in ipairs(SHAPES) do
    local cx = x + p + ((i - 1) % per) * (s + 6)
    local cy = yy + floor((i - 1) / per) * (s + 6)
    local hit = ui.hit("shp" .. i, cx, cy, s, s)
    gfx.rect(cx, cy, s, s, 8, n.shape == shp and alpha(theme.accent, 0.2) or (hit.hovered and theme.hover or alpha(theme.text, 0.05)))
    drawNodeShape({shape = shp, color = n.shape == shp and 2 or 1}, cx + s / 2, cy + s / 2, s - 12, (shp == "diamond" or shp == "note" or shp == "cylinder") and s - 10 or s - 18, false, 0.35)
    if shp == "text" then gfx.color(theme.text2); gfx.text("Aa", cx, cy + 9, 14, "semibold", "center", s) end
    if hit.clicked and n.shape ~= shp then pushHist(); n.shape = shp; markDirty() end
  end
  yy = yy + math.ceil(#SHAPES / per) * (s + 6) + 8
  heading(TR("p_color"))
  yy = yy + swatches(x + p, yy, iw, n.color, function(i) pushHist(); n.color = i; markDirty() end) + 6
  heading(TR("p_text_size"))
  local sz = ui.segmented("tsize", {"S", "M", "L"}, n.size or 2, x + p, yy, iw, 30)
  if sz ~= (n.size or 2) then pushHist(); n.size = sz; markDirty() end
  yy = yy + 42
  local bw = floor((iw - 6) / 2)
  if ui.button(TR("duplicate"), x + p, yy, bw, 32, "default", "content_copy") then duplicate() end
  if ui.button(TR("to_front"), x + p + bw + 6, yy, bw, 32, "default", "flip_to_front") then toFront() end
  yy = yy + 40
  if ui.button(TR("delete"), x + p, yy, iw, 32, "destructive", "delete") then deleteSelection() end
end

-- ================================================================== drawing: editor
local function drawEditor(w, h)
  local tb = 50
  -- toolbar
  gfx.rect(0, 0, w, tb, 0, theme.window)
  local bx = 10
  if ui.iconButton("grid_view", bx, 9, 34, 32, theme.text2, false, "##home") then commitEditing(); saveNow(); screen = "gallery" end
  bx = bx + 40
  local right = w - 10
  local function rb(icon, id, active, enabled)
    right = right - 36
    if enabled == false then gfx.icon(icon, right + 17, 25, 20, theme.text3); return false end
    return ui.iconButton(icon, right, 9, 34, 32, active and theme.accent or theme.text2, active, id)
  end
  local panelDocked = w >= 860
  if rb("more_horiz", "##more") then
    ui.contextMenu({{label = TR("export_svg"), id = 1, icon = "image"}, {label = TR("copy_mermaid"), id = 2, icon = "content_copy"},
                    {label = TR("save_file"), id = 3, icon = "save"}, {label = TR("open_file"), id = 4, icon = "folder_open"}, "-",
                    {label = TR("rename"), id = 5, icon = "edit"}, {label = snap and TR("snap_off") or TR("snap_on"), id = 6, icon = "grid_4x4"},
                    {label = showGrid and TR("grid_off") or TR("grid_on"), id = 7, icon = "grid_on"}}, function(id)
      if id == 1 then exportSVG() elseif id == 2 then mermaid() elseif id == 3 then exportFile() elseif id == 4 then importFile()
      elseif id == 5 then
        ui.prompt(TR("rename"), TR("rename_msg"), doc.name, function(t) if t and K.trim(t) ~= "" then doc.name = K.trim(t); markDirty() end end)
      elseif id == 6 then snap = not snap; saveNow() elseif id == 7 then showGrid = not showGrid; saveNow() end
    end)
  end
  if not panelDocked and rb("tune", "##panel", panelOpen) then panelOpen = not panelOpen end
  if rb("fit_screen", "##fit") then fit() end
  if doc.kind == "flow" and rb("highlight_alt", "##box", boxMode) then
    boxMode = not boxMode
    K.toast(boxMode and TR("box_on") or TR("box_off"), "highlight_alt")
  end
  if w > 620 then
    if rb("zoom_in", "##zin") then zoomBy(1.25) end
    gfx.color(theme.text2)
    right = right - 52
    gfx.text(floor(doc.view.z * 100 + 0.5) .. "%", right, 17, 13, "medium", "center", 52)
    if rb("zoom_out", "##zout") then zoomBy(0.8) end
  end
  if rb("redo", "##redo", false, hist:canRedo()) then redo() end
  if rb("undo", "##undo", false, hist:canUndo()) then undo() end
  -- title
  gfx.color(theme.text)
  local titleW = right - bx - 8
  local th = ui.hit("dtitle", bx, 8, min(titleW, gfx.textWidth(doc.name, 16, "bold") + 16), 34)
  if th.hovered then gfx.rect(bx, 8, min(titleW, gfx.textWidth(doc.name, 16, "bold") + 16), 34, 8, theme.hover) end
  gfx.text(K.ellipsize(doc.name, 16, "bold", titleW - 16), bx + 8, 16, 16, "bold")
  if th.clicked then
    ui.prompt(TR("rename"), TR("rename_msg"), doc.name, function(t) if t and K.trim(t) ~= "" then doc.name = K.trim(t); markDirty() end end)
  end
  gfx.color(theme.separator); gfx.line(0, tb, w, tb, 1)
  -- body: tool strip | canvas | panel
  local strip = doc.kind == "flow" and 52 or 0
  local hasSel = selCount() > 0 or selEdge ~= nil
  local pw = panelDocked and (hasSel and 250 or 0) or 0
  local cx, cy, cw, ch = strip, tb + 1, w - strip - pw, h - tb - 1
  view.ox, view.oy, view.w, view.h = cx, cy, cw, ch
  gfx.clip(cx, cy, cw, ch)
  gfx.rect(cx, cy, cw, ch, 0, theme.bg)
  drawGrid(cx, cy, cw, ch)
  canvasInput(cx, cy, cw, ch)
  if doc.kind == "flow" then drawFlow(cx, cy, cw, ch) else drawMind(cx, cy, cw, ch) end
  if #doc.nodes == 0 then K.empty("schema", TR("empty_doc"), TR("empty_doc_hint"), cx, cy, cw, ch) end
  -- bottom hint
  gfx.color(theme.text3)
  local hint = doc.kind == "mind" and TR("mind_hint") or TR("flow_hint")
  gfx.text(K.ellipsize(hint, 12, "sans", cw - 24), cx + 12, cy + ch - 24, 12)
  drawEditField()
  gfx.unclip()
  if strip > 0 then
    gfx.rect(0, tb + 1, strip, h - tb - 1, 0, theme.sidebar)
    gfx.color(theme.separator); gfx.line(strip, tb, strip, h, 1)
    local sy = tb + 10
    local avail = h - tb - 20
    local step = min(46, floor(avail / #SHAPES))
    for i, shp in ipairs(SHAPES) do
      local hit = ui.hit("add" .. i, 6, sy, 40, step - 4)
      if hit.hovered then gfx.rect(6, sy, 40, step - 4, 8, theme.hover) end
      local sz = min(30, step - 10)
      drawNodeShape({shape = shp, color = 1}, 26, sy + (step - 4) / 2, sz, (shp == "diamond" or shp == "note" or shp == "cylinder") and sz or sz * 0.62, false, 0.3)
      if shp == "text" then gfx.color(theme.text); gfx.text("T", 6, sy + (step - 4) / 2 - 9, 15, "bold", "center", 40) end
      if hit.clicked then addShape(shp) end
      sy = sy + step
    end
  end
  if panelDocked and pw > 0 then
    drawPanel(w - pw, tb + 1, pw, h - tb - 1)
  elseif not panelDocked and panelOpen then
    local fw = min(260, w - 40)
    gfx.shadow(w - fw - 8, tb + 8, fw, h - tb - 16, 12, 16, 4)
    gfx.clip(w - fw - 8, tb + 8, fw, h - tb - 16)
    ui.hit("panelblock", w - fw - 8, tb + 8, fw, h - tb - 16)
    drawPanel(w - fw - 8, tb + 8, fw, h - tb - 16)
    gfx.unclip()
  end
end

-- ================================================================== drawing: gallery
local function thumb(d, x, y, w, h)
  gfx.rect(x, y, w, h, 10, theme.bg)
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  local items = {}
  if d.kind == "mind" then
    local prev = doc
    doc = d
    mindKey = nil
    local L = layoutMind()
    for _, e in pairs(L) do if e.x then items[#items + 1] = {x = e.x, y = e.y, w = e.w, h = e.h, c = e.depth == 0 and 2 or e.color, r = true, kids = e.kids} end end
    doc = prev
    mindKey = nil
  else
    for _, n in ipairs(d.nodes) do items[#items + 1] = {x = n.x, y = n.y, w = n.w, h = n.h, c = n.color, shape = n.shape, id = n.id} end
  end
  for _, it in ipairs(items) do
    x0, y0, x1, y1 = min(x0, it.x - it.w / 2), min(y0, it.y - it.h / 2), max(x1, it.x + it.w / 2), max(y1, it.y + it.h / 2)
  end
  if x0 == math.huge then gfx.icon(d.kind == "mind" and "bubble_chart" or "schema", x + w / 2, y + h / 2, 36, theme.text3); return end
  local s = min((w - 20) / max(1, x1 - x0), (h - 20) / max(1, y1 - y0), 0.6)
  local ox, oy = x + w / 2 - (x0 + x1) / 2 * s, y + h / 2 - (y0 + y1) / 2 * s
  gfx.clip(x, y, w, h)
  if d.kind == "mind" then
    for _, it in ipairs(items) do
      for _, c in ipairs(it.kids or {}) do
        gfx.color(alpha(colorOf(c.color), 0.7))
        gfx.line(ox + it.x * s, oy + it.y * s, ox + c.x * s, oy + c.y * s, 1.5)
      end
    end
  else
    local pos = {}
    for _, it in ipairs(items) do pos[it.id] = it end
    gfx.color(alpha(theme.text, 0.35))
    for _, e in ipairs(d.edges) do
      local a, b = pos[e.a], pos[e.b]
      if a and b then gfx.line(ox + a.x * s, oy + a.y * s, ox + b.x * s, oy + b.y * s, 1.2) end
    end
  end
  for _, it in ipairs(items) do
    local c = colorOf(it.c)
    local fill = it.c == 1 and theme.window or mix(theme.window, c, 0.3)
    local rr = it.r and it.h * s / 2 or 3
    gfx.rect(ox + (it.x - it.w / 2) * s, oy + (it.y - it.h / 2) * s, it.w * s, it.h * s, rr, fill)
    gfx.color(it.c == 1 and alpha(theme.text, 0.5) or c)
    gfx.rectLine(ox + (it.x - it.w / 2) * s, oy + (it.y - it.h / 2) * s, it.w * s, it.h * s, rr, 1)
  end
  gfx.unclip()
end

local function drawGallery(w, h)
  local M = K.metrics(w, h)
  local p = M.pad + 6
  gfx.color(theme.text)
  gfx.text(TR("app_name"), p, 18, 22, "bold")
  local bw = M.narrow and 44 or 150
  if M.narrow then
    if ui.iconButton("bubble_chart", w - p - 44, 14, 40, 34, theme.accent, false, "##nm") then newDoc("mind") end
    if ui.iconButton("schema", w - p - 88, 14, 40, 34, theme.accent, false, "##nf") then newDoc("flow") end
  else
    if ui.button(TR("new_mind"), w - p - bw, 14, bw, 34, "default", "bubble_chart") then newDoc("mind") end
    if ui.button(TR("new_flow"), w - p - bw * 2 - 8, 14, bw, 34, "primary", "schema") then newDoc("flow") end
  end
  local sx = p + gfx.textWidth(TR("app_name"), 22, "bold") + 18
  local sw = (M.narrow and w - p - 96 or w - p - bw * 2 - 16) - sx - 8
  if sw > 120 then gQuery = K.field("gsearch", gQuery, sx, 15, min(320, sw), 32, TR("search_ph"), "search") end
  local list = {}
  local q = K.lower(K.trim(gQuery))
  for _, d in ipairs(docs) do
    if q == "" or K.lower(d.name):find(q, 1, true) then list[#list + 1] = d end
  end
  table.sort(list, function(a, b) return (a.updated or 0) > (b.updated or 0) end)
  local top = 64
  local cols = max(1, floor((w - p * 2 + 16) / 236))
  local cw = floor((w - p * 2 - (cols - 1) * 16) / cols)
  local chh = floor(cw * 0.62) + 58
  local rows = math.ceil(#list / cols)
  galleryRect = {0, top, w, h - top}
  galleryScroll:setMax(rows * (chh + 16) + 20 - (h - top))
  gfx.clip(0, top, w, h - top)
  if #list == 0 then K.empty("schema", TR("no_docs"), TR("no_docs_hint"), 0, top, w, h - top) end
  for i, d in ipairs(list) do
    local c, r = (i - 1) % cols, floor((i - 1) / cols)
    local x, y = p + c * (cw + 16), top + 6 + r * (chh + 16) - galleryScroll.y
    if y + chh > top and y < h then
      local hit = ui.hit("doc" .. i, x, y, cw, chh)
      gfx.shadow(x, y, cw, chh, 14, hit.hovered and 14 or 8, hit.hovered and 4 or 2)
      gfx.rect(x, y, cw, chh, 14, theme.window)
      thumb(d, x + 8, y + 8, cw - 16, chh - 66)
      gfx.icon(d.kind == "mind" and "bubble_chart" or "schema", x + 22, y + chh - 32, 18, d.kind == "mind" and theme.purple or theme.blue)
      gfx.color(theme.text)
      gfx.text(K.ellipsize(d.name, 14, "semibold", cw - 50), x + 38, y + chh - 50, 14, "semibold")
      gfx.color(theme.text3)
      gfx.text(TR(d.kind == "mind" and "kind_mind" or "kind_flow") .. " · " .. K.dayKey(d.updated or now()), x + 38, y + chh - 30, 12)
      if hit.clicked and not galleryScroll:dragged() then openDoc(d) end
      if hit.rightClicked then
        ui.contextMenu({{label = TR("open"), id = 1, icon = "open_in_new"}, {label = TR("rename"), id = 2, icon = "edit"},
                        {label = TR("duplicate"), id = 3, icon = "content_copy"}, "-", {label = TR("delete"), id = 4, icon = "delete"}}, function(id)
          if id == 1 then openDoc(d)
          elseif id == 2 then ui.prompt(TR("rename"), TR("rename_msg"), d.name, function(t) if t and K.trim(t) ~= "" then d.name = K.trim(t); d.updated = now(); dirty = true end end)
          elseif id == 3 then
            local c2 = K.copy(d)
            c2.name = TR("copy_of", d.name)
            c2.updated = now()
            table.insert(docs, 1, c2)
            dirty = true
          elseif id == 4 then
            ui.alert(TR("delete_doc"), TR("delete_doc_msg", d.name), {TR("delete"), TR("cancel")}, function(b)
              if b == 1 then
                for k, x2 in ipairs(docs) do if x2 == d then table.remove(docs, k) end end
                dirty = true
                audio.play("trash", 0.4)
              end
            end)
          end
        end)
      end
    end
  end
  gfx.unclip()
  galleryScroll:bar(w - 6, top + 4, h - top - 8)
end

-- ================================================================== app callbacks
function app.load(arg)
  loadDocs()
  if type(arg) == "string" and arg ~= "" then importPath(arg) end
end
function app.open(arg)
  if type(arg) == "string" and arg ~= "" then importPath(arg) end
end

function app.update(dt)
  frameDt = dt
  galleryScroll:update(dt)
  if dirty and sys.time() - changedAt > 1.2 then saveNow() end
  if editing and K.editing ~= "ntext" then commitEditing() end
  if screen == "editor" and doc and not editing then
    local sx, sy = input.stick("left")
    if abs(sx) > 0.25 or abs(sy) > 0.25 then
      doc.view.x = doc.view.x + sx * dt * 520 / doc.view.z
      doc.view.y = doc.view.y - sy * dt * 520 / doc.view.z
    end
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  if screen == "editor" and doc then drawEditor(w, h) else drawGallery(w, h) end
  K.drawToast(w, h)
  K.frameEnd()
end

local function nudge(dx, dy)
  if doc.kind ~= "flow" or selCount() == 0 then
    doc.view.x, doc.view.y = doc.view.x + dx * 40 / doc.view.z, doc.view.y + dy * 40 / doc.view.z
    return
  end
  pushHist()
  for _, n in ipairs(doc.nodes) do
    if sel[n.id] then n.x, n.y = n.x + dx * (snap and GRID or 4), n.y + dy * (snap and GRID or 4) end
  end
  markDirty()
end

function app.event(e)
  if K.press(e) then
    if editing then
      editing = nil
    end
    return
  end
  if screen == "gallery" then
    if galleryScroll:event(e, galleryRect) then return end
    if e.type == "keydown" and not K.editing then
      if e.ctrl and e.key == "n" then newDoc("flow")
      elseif e.ctrl and e.key == "m" then newDoc("mind")
      elseif e.ctrl and e.key == "o" then importFile()
      elseif e.key == "enter" and docs[1] then openDoc(docs[1]) end
    end
    return
  end
  if not doc then return end
  if e.type == "pinch" then zoomBy(e.scale or 1, e.x, e.y); return end
  if e.type == "scroll" then
    if e.ctrl or not e.touch then
      if (e.dy or 0) ~= 0 then zoomBy(math.exp(-(e.dy or 0) * 0.004), e.x, e.y) end
      if (e.dx or 0) ~= 0 then doc.view.x = doc.view.x + e.dx / doc.view.z end
    else
      doc.view.x, doc.view.y = doc.view.x + (e.dx or 0) / doc.view.z, doc.view.y + (e.dy or 0) / doc.view.z
    end
    return
  end
  if e.type == "mousedown" then pressShift = e.shift and true or false end
  if e.type ~= "keydown" then return end
  local k = e.key
  if K.editing then return end
  if e.ctrl then
    if k == "z" then if e.shift then redo() else undo() end
    elseif k == "y" then redo()
    elseif k == "c" then if copySelection() then K.toast(TR("copied"), "content_copy") end
    elseif k == "x" then if copySelection() then deleteSelection() end
    elseif k == "v" then paste(40)
    elseif k == "d" then duplicate()
    elseif k == "a" and doc.kind == "flow" then sel = {}; for _, n in ipairs(doc.nodes) do sel[n.id] = true end
    elseif k == "0" then fit()
    elseif k == "e" then exportSVG()
    elseif k == "s" then exportFile()
    elseif k == "o" then importFile() end
    return
  end
  if doc.kind == "mind" then
    if k == "tab" then mindAdd(true)
    elseif k == "enter" then mindAdd(false)
    elseif k == "f2" or k == "space" then local n = firstSel(); if n then startEditing(n.id) end
    elseif k == "delete" or k == "backspace" then deleteSelection()
    elseif k == "left" or k == "right" or k == "up" or k == "down" then mindMove(k)
    elseif k == "escape" then commitEditing(); saveNow(); screen = "gallery"
    elseif e.text == "+" or k == "=" then zoomBy(1.2) elseif k == "-" then zoomBy(1 / 1.2)
    elseif k == "f" then fit() end
    return
  end
  if k == "delete" or k == "backspace" then deleteSelection()
  elseif k == "enter" or k == "f2" then
    local n = firstSel()
    if n then startEditing(n.id)
    elseif selEdge then for _, x in ipairs(doc.edges) do if x.id == selEdge then startEditEdge(x) end end end
  elseif k == "tab" then
    if #doc.nodes > 0 then
      local cur = firstSel()
      local idx = 0
      for i, n in ipairs(doc.nodes) do if n == cur then idx = i end end
      idx = (e.shift and (idx - 2) or idx) % #doc.nodes + 1
      sel, selEdge = {[doc.nodes[idx].id] = true}, nil
    end
  elseif k == "left" then nudge(-1, 0) elseif k == "right" then nudge(1, 0)
  elseif k == "up" then nudge(0, -1) elseif k == "down" then nudge(0, 1)
  elseif k == "escape" then
    if selCount() > 0 or selEdge then sel, selEdge = {}, nil else saveNow(); screen = "gallery" end
  elseif k == "f" then fit()
  elseif k == "g" then snap = not snap; K.toast(snap and TR("snap_on_t") or TR("snap_off_t"), "grid_4x4")
  elseif k == "b" then boxMode = not boxMode; K.toast(boxMode and TR("box_on") or TR("box_off"), "highlight_alt")
  elseif e.text == "+" or k == "=" then zoomBy(1.2) elseif k == "-" then zoomBy(1 / 1.2)
  elseif k >= "1" and k <= "9" and #k == 1 then addShape(SHAPES[tonumber(k)]) end
end

function app.menu()
  return {
    {title = TR("m_file"), items = {
      {label = TR("new_flow"), id = 1, shortcut = "Ctrl+N"},
      {label = TR("new_mind"), id = 2, shortcut = "Ctrl+M"},
      {label = TR("open_file"), id = 3, shortcut = "Ctrl+O"},
      {label = TR("save_file"), id = 4, shortcut = "Ctrl+S"},
      "-",
      {label = TR("export_svg"), id = 5, shortcut = "Ctrl+E"},
      {label = TR("copy_mermaid"), id = 6},
      "-",
      {label = TR("all_docs"), id = 7, shortcut = "Esc"},
    }},
    {title = TR("m_edit"), items = {
      {label = TR("undo"), id = 10, shortcut = "Ctrl+Z"},
      {label = TR("redo"), id = 11, shortcut = "Ctrl+Y"},
      "-",
      {label = TR("copy"), id = 12, shortcut = "Ctrl+C"},
      {label = TR("paste"), id = 13, shortcut = "Ctrl+V"},
      {label = TR("duplicate"), id = 14, shortcut = "Ctrl+D"},
      {label = TR("delete"), id = 15, shortcut = "Del"},
      {label = TR("select_all"), id = 16, shortcut = "Ctrl+A"},
    }},
    {title = TR("m_view"), items = {
      {label = TR("zoom_in"), id = 20, shortcut = "+"},
      {label = TR("zoom_out"), id = 21, shortcut = "-"},
      {label = TR("fit"), id = 22, shortcut = "Ctrl+0"},
      "-",
      {label = TR("toggle_snap"), id = 23, shortcut = "G"},
      {label = TR("toggle_grid"), id = 24},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then newDoc("flow") elseif id == 2 then newDoc("mind") elseif id == 3 then importFile()
  elseif id == 7 then if doc then commitEditing() end; saveNow(); screen = "gallery"
  elseif not doc or screen ~= "editor" then return
  elseif id == 4 then exportFile() elseif id == 5 then exportSVG() elseif id == 6 then mermaid()
  elseif id == 10 then undo() elseif id == 11 then redo()
  elseif id == 12 then copySelection() elseif id == 13 then paste(40) elseif id == 14 then duplicate()
  elseif id == 15 then deleteSelection()
  elseif id == 16 then if doc.kind == "flow" then sel = {}; for _, n in ipairs(doc.nodes) do sel[n.id] = true end end
  elseif id == 20 then zoomBy(1.25) elseif id == 21 then zoomBy(0.8) elseif id == 22 then fit()
  elseif id == 23 then snap = not snap; saveNow() elseif id == 24 then showGrid = not showGrid; saveNow() end
end

function app.search(q)
  local out = {}
  q = K.lower(K.trim(q))
  if q == "" then return out end
  for i, d in ipairs(docs) do
    local hitText = K.lower(d.name):find(q, 1, true)
    if not hitText then
      for _, n in ipairs(d.nodes) do if K.lower(n.text or ""):find(q, 1, true) then hitText = true; break end end
    end
    if hitText then out[#out + 1] = {title = d.name, subtitle = TR("app_name"), icon = d.kind == "mind" and "bubble_chart" or "schema", arg = "doc:" .. i} end
    if #out >= 5 then break end
  end
  return out
end

local baseOpen = app.open
function app.open(arg)
  local i = type(arg) == "string" and tonumber(arg:match("^doc:(%d+)$"))
  if i then if docs[i] then openDoc(docs[i]) end; return end
  baseOpen(arg)
end
local baseLoad = app.load
function app.load(arg)
  local i = type(arg) == "string" and tonumber(arg:match("^doc:(%d+)$"))
  if i then baseLoad(""); if docs[i] then openDoc(docs[i]) end; return end
  baseLoad(arg)
end

function app.suspend() if dirty then saveNow() end end
function app.autosave() if dirty then saveNow() end end
function app.unsaved() return dirty end
function app.close()
  commitEditing()
  saveNow()
  store.save()
  return true
end

return app
