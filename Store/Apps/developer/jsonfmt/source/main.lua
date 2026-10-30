-- JSON Formatter: validate (line:column errors), format, minify, sort keys, browse as a tree and see statistics.
-- Uses its own order-keeping parser and serializer (jsonlib.lua). Nexvyn OS Lua SDK.
local J = require("jsonlib")
local app = {}

local floor, min, max, ceil = math.floor, math.min, math.max, math.ceil
local M = 18
local MAX_INPUT = 2 * 1024 * 1024
local LH = 18                 -- code view line height
local ROW = 30                -- tree row height
local LINE_SHOW = 400         -- bytes drawn per code line

-- ------------------------------------------------------------------ state
local tab = 1                 -- 1 input, 2 output, 3 tree, 4 stats
local text, lines = "", {}
local undoText = nil
local focused = false
local parseAt = nil           -- time when the pending parse runs (debounce while typing)
local clock = 0

local root, st, err = nil, nil, nil
local indentSel, sortKeys = 1, false
local output, outLines, formatPending = "", {}, false
local minSize = nil           -- minified size (computed on demand for the stats tab)

local expanded = setmetatable({}, {__mode = "k"})
local rows, rowsDirty = {}, true
local selRow = nil
local query, lastQuery, queryAt = "", "", nil
local results, resultsCapped = {}, false

local toast, toastT = "", 0
local statsAnim, tabAnim = 0, 1

local SAMPLE = '{"app":"Nexvyn OS","version":1.3,"features":["windows","dock","app store"],' ..
  '"settings":{"dark":true,"accent":"#0A84FF","scale":1.25,"tags":null},' ..
  '"users":[{"id":1,"name":"Ada","admin":true},{"id":2,"name":"Deniz","admin":false}]}'

-- ------------------------------------------------------------------ helpers
local function sizeText(n)
  if n < 1024 then return n .. " B" end
  if n < 1048576 then return string.format("%.1f KB", n / 1024) end
  return string.format("%.2f MB", n / 1048576)
end

local function utf8Cut(s, n)
  if #s <= n then return s end
  local i = n
  while i > 0 and (s:byte(i + 1) or 0) >= 0x80 and (s:byte(i + 1) or 0) < 0xC0 do i = i - 1 end
  return s:sub(1, i)
end

local function splitLines(s)
  local t = {}
  if s == "" then return t end
  for line in (s .. "\n"):gmatch("([^\n]*)\n") do t[#t + 1] = line end
  return t
end

local function showToast(msg) toast, toastT = msg, 2.6 end

local function errText(e)
  local c = e and e.code
  if c == "eof" then return TR("e_eof")
  elseif c == "char" then return TR("e_char", tostring(e.extra or "?"))
  elseif c == "colon" then return TR("e_colon")
  elseif c == "obj_sep" then return TR("e_obj_sep")
  elseif c == "arr_sep" then return TR("e_arr_sep")
  elseif c == "key" then return TR("e_key")
  elseif c == "number" then return TR("e_number")
  elseif c == "escape" then return TR("e_escape")
  elseif c == "control" then return TR("e_control")
  elseif c == "unterminated" then return TR("e_unterminated")
  elseif c == "trailing" then return TR("e_trailing")
  elseif c == "depth" then return TR("e_depth")
  elseif c == "empty" then return TR("e_empty")
  elseif c == "trailing_comma" then return TR("e_trailing_comma")
  elseif c == "comment" then return TR("e_comment")
  elseif c == "single_quote" then return TR("e_single_quote")
  elseif c == "word" then return TR("e_word", tostring(e.extra or "")) end
  return TR("e_char", "?")
end

local function indentUnit()
  if indentSel == 1 then return "  " elseif indentSel == 2 then return "    " elseif indentSel == 3 then return "\t" end
  return nil
end

local function saveSettings()
  store.set("tab", tab); store.set("indent", indentSel); store.set("sort", sortKeys)
end

-- ------------------------------------------------------------------ input and parsing
local function setText(s, immediate, keepUndo)
  s = tostring(s or ""):gsub("\r\n", "\n")
  if s:sub(1, 3) == "\239\187\191" then s = s:sub(4) end   -- UTF-8 byte order mark
  if #s > MAX_INPUT then showToast(TR("too_big", sizeText(MAX_INPUT))); return end
  if keepUndo and text ~= "" and text ~= s then undoText = text end
  text = s
  lines = splitLines(text)
  parseAt = immediate and clock or clock + 0.35
  if #text <= 256 * 1024 then store.set("text", text) else store.set("text", "") end
end

local function parseNow()
  parseAt = nil
  expanded = setmetatable({}, {__mode = "k"})
  rows, selRow, results, lastQuery = {}, nil, {}, ""
  minSize = nil
  if text:find("^%s*$") then
    root, st, err = nil, nil, nil
    output, outLines = "", {}
    return
  end
  local r, info = J.parse(text)
  if r then
    root, st, err = r, info, nil
    expanded[root] = true
    if J.count(root) <= 60 then          -- open the second level of small documents
      local kids = root.k == "o" and root.vals or root.items or {}
      for i = 1, #kids do if J.count(kids[i]) > 0 and J.count(kids[i]) <= 30 then expanded[kids[i]] = true end end
    end
    formatPending, rowsDirty = true, true
  else
    root, st, err = nil, nil, info
    output, outLines = "", {}
  end
end

local function formatNow()
  formatPending = false
  if not root then return end
  output = J.serialize(root, indentUnit(), sortKeys)
  outLines = splitLines(output)
end

-- ------------------------------------------------------------------ tree
local function isIdent(k) return k:find("^[A-Za-z_$][A-Za-z0-9_$]*$") ~= nil end

local function pathSeg(key, isIndex)
  if isIndex then return "[" .. key .. "]" end
  if isIdent(key) then return "." .. key end
  return '["' .. key:gsub('"', '\\"') .. '"]'
end

local function buildRows()
  rowsDirty = false
  rows = {}
  if not root then return end
  local function add(node, depth, key, isIndex, parent)
    local row = {n = node, d = depth, key = key, idx = isIndex, parent = parent}
    rows[#rows + 1] = row
    if #rows > 200000 then return end
    if expanded[node] then
      if node.k == "o" then
        for i = 1, #node.keys do add(node.vals[i], depth + 1, J.unescape(node.keys[i]), false, row) end
      elseif node.k == "a" then
        for i = 1, #node.items do add(node.items[i], depth + 1, tostring(i - 1), true, row) end
      end
    end
  end
  add(root, 0, nil, false, nil)
end

local function rowPath(row)
  local segs = {}
  while row and row.parent do
    table.insert(segs, 1, pathSeg(row.key, row.idx))
    row = row.parent
  end
  return "$" .. table.concat(segs)
end

local function setAll(open)
  if not root then return end
  expanded = setmetatable({}, {__mode = "k"})
  if open then
    local function walk(n)
      if n.k == "o" or n.k == "a" then
        expanded[n] = true
        local kids = n.k == "o" and n.vals or n.items
        for i = 1, #kids do walk(kids[i]) end
      end
    end
    walk(root)
  else
    expanded[root] = true
  end
  rowsDirty, selRow = true, nil
end

local function scalarText(n)
  if n.k == "s" then return J.unescape(n.r)
  elseif n.k == "n" then return n.r
  elseif n.k == "t" then return "true" elseif n.k == "f" then return "false" elseif n.k == "z" then return "null" end
  return ""
end

local function runSearch()
  lastQuery = query
  results, resultsCapped = {}, false
  local q = query:lower()
  if q == "" or not root then return end
  local segs = {}
  local function walk(n, key, isIndex)
    if #results >= 300 then resultsCapped = true; return end
    if key then segs[#segs + 1] = pathSeg(key, isIndex) end
    local hitKey = key and not isIndex and key:lower():find(q, 1, true)
    local hitVal = (n.k ~= "o" and n.k ~= "a") and scalarText(n):lower():find(q, 1, true)
    if hitKey or hitVal then
      results[#results + 1] = {n = n, d = 0, key = "$" .. table.concat(segs), path = "$" .. table.concat(segs)}
    end
    if n.k == "o" then
      for i = 1, #n.keys do walk(n.vals[i], J.unescape(n.keys[i]), false) end
    elseif n.k == "a" then
      for i = 1, #n.items do walk(n.items[i], tostring(i - 1), true) end
    end
    if key then segs[#segs] = nil end
  end
  walk(root, nil, false)
end

-- ------------------------------------------------------------------ actions
local function paste()
  local c = sys.clipboard() or ""
  if c == "" then showToast(TR("clip_empty")); return end
  setText(c, true, true)
  tab = 1
end

local function loadFile(p)
  if not p or p == "" then return end
  local d = fs.read(p)
  if not d then showToast(TR("open_failed")); return end
  setText(d, true, true)
  showToast(TR("opened", p:match("([^/\\]+)$") or p))
end

local function openFile()
  ui.openFile(function(p) loadFile(p) end, {".json", ".txt", ".geojson"}, TR("open"))
end

local function saveOutput()
  if not root then showToast(TR("nothing")); return end
  if formatPending then formatNow() end
  local data = output
  ui.saveFile(function(p)
    if not p then return end
    if fs.write(p, data) then showToast(TR("saved")) else showToast(TR("save_failed")) end
  end, indentSel == 4 and "data.min.json" or "data.json", TR("save"))
end

local function copyOutput()
  if not root then showToast(TR("nothing")); return end
  if formatPending then formatNow() end
  sys.clipboard(output)
  showToast(TR("copied"))
end

local function clearText()
  if text == "" then return end
  setText("", true, true)
  showToast(TR("cleared"))
end

local function undo()
  if not undoText then return end
  local u = undoText
  undoText = nil
  setText(u, true, false)
  showToast(TR("restored"))
end

local function editKeyboard()
  ui.keyboard(text, function(s) if s then setText(s, true, true) end end, TR("tab_input"))
end

local function replaceWithOutput()       -- "Apply": the formatted text becomes the input
  if not root then return end
  if formatPending then formatNow() end
  setText(output, true, true)
  tab = 1
  showToast(TR("applied"))
end

local function setTab(t)
  t = max(1, min(4, t))
  if t ~= tab then tab = t; tabAnim = 0; if t == 4 then statsAnim = 0 end; saveSettings() end
end

-- ------------------------------------------------------------------ lifecycle
function app.load(arg)
  tab = max(1, min(4, floor(tonumber(store.get("tab", 1)) or 1)))
  indentSel = max(1, min(4, floor(tonumber(store.get("indent", 1)) or 1)))
  sortKeys = store.get("sort", false) == true
  if type(arg) == "string" and arg ~= "" then loadFile(arg)
  else setText(tostring(store.get("text", "") or ""), true, false) end
end

function app.open(arg)
  if type(arg) == "string" and arg ~= "" then loadFile(arg); tab = 1 end
end

function app.update(dt)
  clock = clock + dt
  if parseAt and clock >= parseAt then parseNow()
  elseif formatPending then formatNow()
  elseif rowsDirty then buildRows() end
  if tab == 3 and query ~= lastQuery then
    if not queryAt then queryAt = clock + 0.25 elseif clock >= queryAt then queryAt = nil; runSearch() end
  end
  statsAnim = min(1, statsAnim + dt * 1.6)
  tabAnim = min(1, tabAnim + dt * 6)
  if toastT > 0 then toastT = toastT - dt end
end

-- ------------------------------------------------------------------ drawing helpers
local function card(x, y, w, h)
  gfx.color(theme.field)
  gfx.rect(x, y, w, h, 10)
  gfx.color(theme.separator)
  gfx.rectLine(x, y, w, h, 10, 1)
end

local function emptyState(icon, title, msg, x, y, w, h, color)
  local cx, cy = x + w / 2, y + h / 2 - 30
  local pulse = 1 + 0.04 * math.sin(clock * 2)
  gfx.color(color or theme.accent)
  gfx.alpha(0.13)
  gfx.circle(cx, cy, 44 * pulse)
  gfx.unalpha()
  gfx.icon(icon, cx, cy, 44, color or theme.accent)
  gfx.color(theme.text)
  gfx.text(title, x, cy + 56, 16, "semibold", "center", w)
  gfx.color(theme.text2)
  gfx.wrap(msg, x + 30, cy + 82, w - 60, 13, "sans", "center")
end

local function codeLine(s)
  s = utf8Cut(s, LINE_SHOW)
  if s:find("\t", 1, true) then s = s:gsub("\t", "    ") end
  return s
end

-- a read-only code view that only draws the visible lines
local function drawCode(id, ls, x, y, w, h, errLine, errCol)
  card(x, y, w, h)
  local digits = #tostring(max(1, #ls))
  local gut = 16 + digits * 8
  local contentH = #ls * LH + 16
  local sy = ui.beginScroll(id, x + 1, y + 1, w - 2, h - 2, max(contentH, h - 2))
  local hit = ui.hit(id .. "_hit", 0, 0, w - 2, max(contentH, h - 2))
  sy = tonumber(sy) or 0
  local first = max(1, floor((sy - 8) / LH) + 1)
  local last = min(#ls, first + ceil(h / LH) + 1)
  gfx.color(theme.window)
  gfx.rect(0, 0, gut - 6, max(contentH, h - 2), 0)
  for i = first, last do
    local ly = 8 + (i - 1) * LH
    if i == errLine then
      gfx.color(theme.red)
      gfx.alpha(0.14)
      gfx.rect(0, ly - 1, w - 2, LH, 0)
      gfx.unalpha()
    end
    gfx.color(i == errLine and theme.red or theme.text3)
    gfx.text(tostring(i), 4, ly + 1, 11, "mono", "right", gut - 14)
    gfx.color(theme.text)
    gfx.text(codeLine(ls[i] or ""), gut, ly, 13, "mono")
    if i == errLine and errCol then
      local pre = ls[i] or ""
      local cut = utf8.offset(pre, errCol) or (#pre + 1)
      local px = gut + gfx.textWidth(codeLine(pre:sub(1, cut - 1)), 13, "mono")
      gfx.color(theme.red)
      gfx.rect(px, ly + LH - 3, 9, 2, 1)
    end
  end
  ui.endScroll()
  return hit
end

local function statusPill(w)
  local label, color, icon
  if parseAt then label, color, icon = TR("checking"), theme.text3, "hourglass_empty"
  elseif err then label, color, icon = TR("pill_error", err.line, err.col), theme.red, "error"
  elseif root then label, color, icon = TR("pill_valid"), theme.green, "check_circle"
  else label, color, icon = TR("pill_empty"), theme.text3, "data_object" end
  local pw = gfx.textWidth(label, 13, "semibold") + 44
  local px = w - M - pw
  gfx.color(color)
  gfx.alpha(0.14)
  gfx.rect(px, 14, pw, 30, 15)
  gfx.unalpha()
  gfx.icon(icon, px + 18, 29, 17, color)
  gfx.color(color)
  gfx.text(label, px + 32, 21, 13, "semibold")
  return pw
end

-- ------------------------------------------------------------------ tabs
local function drawInputTab(x, y, w, h)
  local bw = min(118, (w - 4 * 8) / 5)
  if ui.button(TR("paste"), x, y, bw, 32, "default", "content_paste") then paste() end
  if ui.button(TR("open"), x + (bw + 8), y, bw, 32, "default", "folder_open") then openFile() end
  if ui.button(TR("keyboard"), x + 2 * (bw + 8), y, bw, 32, "default", "keyboard") then editKeyboard() end
  if ui.button(TR("sample"), x + 3 * (bw + 8), y, bw, 32, "default", "auto_awesome") then setText(SAMPLE, true, true) end
  if ui.button(TR("clear"), x + 4 * (bw + 8), y, bw, 32, "plain", "delete", text ~= "") then clearText() end

  local cy, ch = y + 44, h - 44 - 54
  if text == "" and not focused then
    card(x, cy, w, ch)
    emptyState("data_object", TR("empty_title"), TR("empty_msg"), x, cy, w, ch)
    local hit = ui.hit("empty_hit", x, cy, w, ch)
    if hit.clicked then if input.touch() then editKeyboard() else focused = true end end
  else
    local hit = drawCode("in_code", lines, x, cy, w, ch, err and err.line, err and err.col)
    if hit.clicked then if input.touch() then editKeyboard() else focused = true end end
    if focused then
      gfx.color(theme.accent)
      gfx.rectLine(x, cy, w, ch, 10, 2)
    end
  end

  -- status: the error with a snippet, or a summary
  local sy = y + h - 46
  if err then
    gfx.icon("error", x + 10, sy + 11, 18, theme.red)
    gfx.color(theme.red)
    gfx.text(TR("err_at", err.line, err.col) .. "  " .. errText(err), x + 26, sy + 2, 13, "semibold")
    local ln = lines[err.line] or ""
    local colByte = utf8.offset(ln, err.col) or (#ln + 1)
    local from = max(1, colByte - 40)
    while from > 1 and (ln:byte(from) or 0) >= 0x80 and (ln:byte(from) or 0) < 0xC0 do from = from - 1 end
    local snip = codeLine(ln:sub(from, colByte + 40))
    local pre = codeLine(ln:sub(from, colByte - 1))
    gfx.color(theme.text2)
    gfx.text(snip, x + 26, sy + 24, 12, "mono")
    gfx.color(theme.red)
    gfx.rect(x + 26 + gfx.textWidth(pre, 12, "mono"), sy + 40, 8, 2, 1)
  elseif root and st then
    gfx.icon("check_circle", x + 10, sy + 11, 18, theme.green)
    gfx.color(theme.text2)
    gfx.text(TR("summary", #lines, sizeText(#text), st.keys, st.depth), x + 26, sy + 2, 13)
    if st.dupes > 0 then
      gfx.color(theme.orange)
      gfx.text(TR("dupes", st.dupes), x + 26, sy + 22, 12, "semibold")
    end
  elseif focused then
    gfx.color(theme.text3)
    gfx.text(TR("typing_hint"), x, sy + 2, 12)
  end
end

local function invalidState(x, y, w, h)
  card(x, y, w, h)
  if err then
    emptyState("error", TR("fix_first"), TR("err_at", err.line, err.col) .. " " .. errText(err), x, y, w, h, theme.red)
    if ui.button(TR("show_error"), x + w / 2 - 80, y + h - 56, 160, 34, "default", "visibility") then setTab(1) end
  else
    emptyState("data_object", TR("empty_title"), TR("empty_msg"), x, y, w, h)
  end
end

local function drawOutputTab(x, y, w, h)
  local labels = {"2", "4", TR("tab_char"), TR("minify")}
  local sw = min(280, w * 0.36)
  local ni = ui.segmented("indent", labels, indentSel, x, y, sw, 32)
  if ni ~= indentSel then indentSel = ni; formatPending = true; minSize = nil; saveSettings() end
  local sk = ui.checkbox(TR("sort_keys"), sortKeys, x + sw + 14, y + 6)
  if sk ~= sortKeys then sortKeys = sk; formatPending = true; saveSettings() end
  local bw = 104
  local bx = x + w - bw
  if ui.button(TR("save"), bx, y, bw, 32, "default", "save", root ~= nil) then saveOutput() end
  if ui.button(TR("copy"), bx - bw - 8, y, bw, 32, "primary", "content_copy", root ~= nil) then copyOutput() end
  local cy, ch = y + 44, h - 44 - 40
  if not root then invalidState(x, cy, w, ch); return end
  gfx.alpha(0.4 + 0.6 * tabAnim)
  drawCode("out_code", outLines, x, cy, w, ch)
  gfx.unalpha()
  gfx.color(theme.text2)
  local saved = #text > 0 and floor((1 - #output / #text) * 100 + 0.5) or 0
  gfx.text(TR("out_summary", #outLines, sizeText(#output), saved), x, y + h - 28, 13)
  if ui.button(TR("apply"), x + w - 170, y + h - 34, 170, 32, "plain", "input") then replaceWithOutput() end
end

local function typeColor(n)
  if n.k == "s" then return theme.green elseif n.k == "n" then return theme.blue
  elseif n.k == "t" or n.k == "f" then return theme.purple elseif n.k == "z" then return theme.gray end
  return theme.text3
end

local function preview(row)
  if row.pv then return row.pv end
  local n = row.n
  local s
  if n.k == "o" then s = TR("n_keys", #n.keys)
  elseif n.k == "a" then s = TR("n_items", #n.items)
  elseif n.k == "s" then s = '"' .. utf8Cut(J.unescape(n.r), 160):gsub("[\n\r\t]", " ") .. '"'
  else s = scalarText(n) end
  row.pv = s
  return s
end

local function drawTreeTab(x, y, w, h)
  local fw = w - 2 * 128 - 16
  query = ui.textfield("search", query, x, y, fw, 32, TR("search_hint"), "search")
  if ui.button(TR("expand_all"), x + fw + 8, y, 124, 32, "default", "unfold_more", root ~= nil) then setAll(true) end
  if ui.button(TR("collapse_all"), x + fw + 140, y, 124, 32, "default", "unfold_less", root ~= nil) then setAll(false) end
  local cy, ch = y + 44, h - 44 - 46
  if not root then invalidState(x, cy, w, ch); return end
  local list = query ~= "" and results or rows
  card(x, cy, w, ch)
  if query ~= "" and #results == 0 then
    if lastQuery == query then emptyState("search_off", TR("no_results"), TR("no_results_msg", query), x, cy, w, ch, theme.gray) end
  else
    local contentH = #list * ROW + 8
    local sy = tonumber((ui.beginScroll("tree", x + 1, cy + 1, w - 2, ch - 2, max(contentH, ch - 2)))) or 0
    local first = max(1, floor(sy / ROW) + 1)
    local last = min(#list, first + ceil(ch / ROW) + 1)
    for i = first, last do
      local row = list[i]
      local ry = 4 + (i - 1) * ROW
      local selected = selRow == row
      if selected then
        gfx.color(theme.selection)
        gfx.alpha(0.18)
        gfx.rect(4, ry, w - 10, ROW, 6)
        gfx.unalpha()
      end
      local hit = ui.hit("r" .. i, 4, ry, w - 10, ROW)
      if hit.hovered and not selected then
        gfx.color(theme.hover)
        gfx.rect(4, ry, w - 10, ROW, 6)
      end
      local n = row.n
      local ix = 12 + min(row.d, 24) * 18
      local container = n.k == "o" or n.k == "a"
      if container and list == rows then
        gfx.icon(expanded[n] and "expand_more" or "chevron_right", ix + 8, ry + ROW / 2, 18, theme.text2)
      end
      local tx = ix + 22
      if row.key then
        gfx.color(list == rows and (row.idx and theme.text3 or theme.accent) or theme.text2)
        local kw = gfx.text(list == rows and row.key or utf8Cut(row.key, 120), tx, ry + 7, 13, list == rows and "semibold" or "mono")
        tx = tx + kw
        gfx.color(theme.text3)
        gfx.text(":", tx + 2, ry + 7, 13)
        tx = tx + 12
      end
      gfx.color(typeColor(n))
      gfx.text(preview(row), tx, ry + 7, 13, container and "sans" or "mono")
      if hit.clicked then
        selRow = row
        if container and list == rows then expanded[n] = not expanded[n] or nil; rowsDirty = true end
      end
    end
    ui.endScroll()
  end
  -- footer: the selected path, or the result count
  local fy = y + h - 34
  if selRow then
    local path = selRow.path or rowPath(selRow)
    gfx.color(theme.text2)
    gfx.clip(x, fy, w - 2 * 132, 34)
    gfx.text(path, x, fy + 8, 13, "mono")
    gfx.unclip()
    if ui.button(TR("copy_path"), x + w - 2 * 128 - 8, fy, 128, 32, "default", "link") then
      sys.clipboard(path); showToast(TR("copied"))
    end
    if ui.button(TR("copy_value"), x + w - 128, fy, 128, 32, "default", "content_copy") then
      local n = selRow.n
      sys.clipboard((n.k == "o" or n.k == "a") and J.serialize(n, indentUnit(), sortKeys) or scalarText(n))
      showToast(TR("copied"))
    end
  else
    gfx.color(theme.text3)
    local msg = query ~= "" and (resultsCapped and TR("results_capped", #results) or TR("results", #results))
      or TR("tree_hint", #rows)
    gfx.text(msg, x, fy + 8, 13)
  end
end

local STAT_ROWS = {
  {"st_strings", "strings", "#30D158"}, {"st_numbers", "numbers", "#0A84FF"}, {"st_bools", "bools", "#BF5AF2"},
  {"st_nulls", "nulls", "#8E8E93"}, {"st_objects", "objects", "#FF9F0A"}, {"st_arrays", "arrays", "#FF375F"},
}

local function statLabel(key)
  if key == "st_strings" then return TR("st_strings") elseif key == "st_numbers" then return TR("st_numbers")
  elseif key == "st_bools" then return TR("st_bools") elseif key == "st_nulls" then return TR("st_nulls")
  elseif key == "st_objects" then return TR("st_objects") end
  return TR("st_arrays")
end

local function drawStatsTab(x, y, w, h)
  if not root or not st then invalidState(x, y, w, h - 10); return end
  if not minSize then minSize = #J.serialize(root, nil, false) end
  local e = 1 - (1 - statsAnim) ^ 3
  -- headline numbers
  local tiles = {
    {TR("st_keys"), st.keys}, {TR("st_depth"), st.depth}, {TR("st_lines"), #lines}, {TR("st_size"), sizeText(#text)},
  }
  local tw = (w - 3 * 12) / 4
  for i, t in ipairs(tiles) do
    local tx = x + (i - 1) * (tw + 12)
    card(tx, y, tw, 72)
    gfx.color(theme.text2)
    gfx.text(t[1], tx + 14, y + 12, 12, "semibold")
    gfx.color(theme.text)
    local v = t[2]
    if type(v) == "number" then v = tostring(floor(v * e + 0.5)) end
    gfx.text(v, tx + 14, y + 32, 24, "bold")
  end
  -- value types as animated horizontal bars
  local by, bh = y + 88, h - 88 - 96
  card(x, by, w, bh)
  gfx.color(theme.text)
  gfx.text(TR("types"), x + 16, by + 12, 14, "semibold")
  local total = 0
  for _, r in ipairs(STAT_ROWS) do total = total + (st[r[2]] or 0) end
  local rowH = max(22, min(34, (bh - 46) / #STAT_ROWS))
  local lw = 110
  for i, r in ipairs(STAT_ROWS) do
    local v = st[r[2]] or 0
    local ry = by + 40 + (i - 1) * rowH
    gfx.color(theme.text2)
    gfx.text(statLabel(r[1]), x + 16, ry + rowH / 2 - 8, 13)
    local maxW = w - lw - 110
    gfx.color(theme.separator)
    gfx.rect(x + lw + 16, ry + rowH / 2 - 6, maxW, 12, 6)
    local bw = total > 0 and maxW * v / total * e or 0
    if bw > 1 then gfx.color(r[3]); gfx.rect(x + lw + 16, ry + rowH / 2 - 6, max(12, bw), 12, 6) end
    gfx.color(theme.text)
    local pct = total > 0 and floor(v * 100 / total + 0.5) or 0
    gfx.text(v .. "  (" .. pct .. "%)", x + w - 90, ry + rowH / 2 - 8, 12, "semibold")
  end
  -- sizes
  local sy = y + h - 84
  card(x, sy, w, 74)
  local fmtSize = #output
  local cols = {{TR("st_input"), #text}, {TR("st_formatted"), fmtSize}, {TR("st_minified"), minSize}}
  local cw = w / 3
  for i, c in ipairs(cols) do
    local cx = x + (i - 1) * cw
    gfx.color(theme.text2)
    gfx.text(c[1], cx + 16, sy + 12, 12, "semibold")
    gfx.color(theme.text)
    gfx.text(sizeText(c[2]), cx + 16, sy + 32, 18, "bold")
  end
  if st.dupes > 0 then
    gfx.color(theme.orange)
    gfx.text(TR("dupes", st.dupes), x + 16, sy + 56, 11, "semibold")
  elseif #text > 0 then
    gfx.color(theme.text3)
    gfx.text(TR("min_saves", floor((1 - minSize / #text) * 100 + 0.5)), x + 2 * cw + 16, sy + 56, 11)
  end
end

local function drawToast(w, h)
  if toastT <= 0 then return end
  local a = min(1, toastT * 3, (2.6 - toastT) * 6)
  local tw = gfx.textWidth(toast, 13, "medium") + 32
  local tx, ty = (w - tw) / 2, h - 60 + (1 - a) * 12
  gfx.alpha(a)
  gfx.shadow(tx, ty, tw, 34, 17, 10, 3)
  gfx.color(theme.text)
  gfx.rect(tx, ty, tw, 34, 17)
  gfx.color(theme.bg)
  gfx.text(toast, tx + 16, ty + 9, 13, "medium")
  gfx.unalpha()
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local pw = statusPill(w)
  local tabsW = min(460, w - 2 * M - pw - 16)
  local nt = ui.segmented("tabs", {TR("tab_input"), TR("tab_output"), TR("tab_tree"), TR("tab_stats")}, tab, M, 14, tabsW, 30)
  if nt ~= tab then setTab(nt) end
  local x, y, cw, ch = M, 58, w - 2 * M, h - 58 - M
  if tab == 1 then drawInputTab(x, y, cw, ch)
  elseif tab == 2 then drawOutputTab(x, y, cw, ch)
  elseif tab == 3 then drawTreeTab(x, y, cw, ch)
  else drawStatsTab(x, y, cw, ch) end
  drawToast(w, h)
end

-- ------------------------------------------------------------------ input
local function backspace()
  if text == "" then return end
  local ok, off = pcall(utf8.offset, text, -1)
  if ok and off and off >= 1 then setText(text:sub(1, off - 1)) else setText(text:sub(1, -2)) end
end

function app.event(e)
  if e.type == "mousedown" and focused then focused = false; return end
  if e.type == "text" and focused and tab == 1 then
    if e.text and e.text ~= "" then setText(text .. e.text) end
    return
  end
  if e.type ~= "keydown" then return end
  local k = e.key
  if e.ctrl then
    if k == "v" then paste() elseif k == "o" then openFile() elseif k == "s" then saveOutput()
    elseif k == "c" then copyOutput() elseif k == "z" then undo() elseif k == "l" then clearText()
    elseif k == "e" then setAll(true) elseif k == "f" then setTab(3); ui.focus("search")
    elseif k == "1" or k == "2" or k == "3" or k == "4" then setTab(tonumber(k)) end
    return
  end
  if focused and tab == 1 then
    if k == "backspace" then backspace()
    elseif k == "enter" then setText(text .. "\n")
    elseif k == "tab" then setText(text .. "  ")
    elseif k == "escape" then focused = false end
    return
  end
  if k == "tab" then setTab(tab % 4 + 1)
  elseif k == "enter" and tab == 1 then focused = true
  elseif k == "escape" then selRow = nil end
end

function app.menu()
  return {
    {title = TR("menu_file"), items = {
      {label = TR("open"), id = 1, shortcut = "Ctrl+O"},
      {label = TR("save"), id = 2, shortcut = "Ctrl+S"},
      "-",
      {label = TR("sample"), id = 3},
    }},
    {title = TR("menu_edit"), items = {
      {label = TR("paste"), id = 10, shortcut = "Ctrl+V"},
      {label = TR("copy"), id = 11, shortcut = "Ctrl+C"},
      {label = TR("apply"), id = 12},
      "-",
      {label = TR("undo"), id = 13, shortcut = "Ctrl+Z"},
      {label = TR("clear"), id = 14, shortcut = "Ctrl+L"},
      {label = TR("keyboard"), id = 15, shortcut = "Enter"},
    }},
    {title = TR("menu_view"), items = {
      {label = TR("tab_input"), id = 20, shortcut = "Ctrl+1"},
      {label = TR("tab_output"), id = 21, shortcut = "Ctrl+2"},
      {label = TR("tab_tree"), id = 22, shortcut = "Ctrl+3"},
      {label = TR("tab_stats"), id = 23, shortcut = "Ctrl+4"},
      "-",
      {label = TR("expand_all"), id = 24, shortcut = "Ctrl+E"},
      {label = TR("collapse_all"), id = 25},
      {label = TR("sort_keys"), id = 26},
      {label = TR("minify"), id = 27},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then openFile() elseif id == 2 then saveOutput() elseif id == 3 then setText(SAMPLE, true, true); setTab(1)
  elseif id == 10 then paste() elseif id == 11 then copyOutput() elseif id == 12 then replaceWithOutput()
  elseif id == 13 then undo() elseif id == 14 then clearText() elseif id == 15 then editKeyboard()
  elseif id >= 20 and id <= 23 then setTab(id - 19)
  elseif id == 24 then setAll(true); setTab(3) elseif id == 25 then setAll(false); setTab(3)
  elseif id == 26 then sortKeys = not sortKeys; formatPending = true; saveSettings()
  elseif id == 27 then indentSel = indentSel == 4 and 1 or 4; formatPending = true; saveSettings(); setTab(2) end
end

function app.close()
  store.save()
  return true
end

return app
