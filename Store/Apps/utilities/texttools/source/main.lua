-- Text Tools: a small multi-line editor with case conversion (Turkish İ/ı rules), clean-up, line sorting,
-- duplicate removal and live statistics (Nexvyn OS Lua SDK).
local app = {}

-- ------------------------------------------------------------------ state
local lines = {""}            -- the text, one string per line
local cl, cc = 1, 0           -- caret line (1-based) and column (codepoints before the caret)
local focused = false         -- the editor has keyboard focus
local blink = 0
local undoStack, redoStack = {}, {}
local lastPush, lastKind = -10, ""
local trRules = true          -- Turkish case rules (i <-> İ, ı <-> I)
local ignoreCase = true       -- for sorting and duplicate removal
local panel = 1               -- 1 tools, 2 statistics
local addLine = ""
local msg, msgT = nil, 0
local flashT = 0              -- editor highlight after an operation
local saveT = -1              -- pending store write
local maxCols = 0             -- longest line in codepoints (content width)

-- editor geometry from the last draw (used by mouse events)
local ex, ey, ew, eh, scrollX, scrollY = 0, 0, 0, 0, 0, 0
local charW, LINE_H, FONT = 8.4, 21, 14
local PAD = 10

-- statistics (recomputed when the text changes)
local stats = {chars = 0, noSpace = 0, words = 0, lines = 1, sentences = 0, paras = 0, unique = 0, avgWord = 0,
               longest = ""}
local top = {}                -- {word, count} x5
local statsDirty = true

-- ------------------------------------------------------------------ utf-8 helpers
local function ulen(s) return utf8.len(s) or #s end

-- codepoints i..j (1-based, inclusive)
local function usub(s, i, j)
  local n = ulen(s)
  if j == nil or j > n then j = n end
  if i < 1 then i = 1 end
  if i > j then return "" end
  local a = utf8.offset(s, i) or (#s + 1)
  local b = utf8.offset(s, j + 1) or (#s + 1)
  return s:sub(a, b - 1)
end

-- replaces invalid UTF-8 bytes so utf8.* never fails
local function sanitize(s)
  if utf8.len(s) then return s end
  local out = {}
  local i, n = 1, #s
  while i <= n do
    local ok, cp = pcall(utf8.codepoint, s, i)
    if ok and cp then
      local ch = utf8.char(cp)
      out[#out + 1] = ch
      i = i + #ch
    else
      out[#out + 1] = "?"
      i = i + 1
    end
  end
  return table.concat(out)
end

-- ------------------------------------------------------------------ case mapping
local function upperCp(c)
  if c >= 97 and c <= 122 then
    if c == 105 and trRules then return 0x130 end        -- i -> İ
    return c - 32
  end
  if c < 0xB5 then return c end
  if c == 0x131 then return 73 end                       -- ı -> I
  if c == 0xFF then return 0x178 end
  if c >= 0xE0 and c <= 0xFE and c ~= 0xF7 then return c - 32 end
  if (c >= 0x100 and c <= 0x12F) or (c >= 0x132 and c <= 0x137) or (c >= 0x14A and c <= 0x177) then
    return c % 2 == 1 and c - 1 or c
  end
  if (c >= 0x139 and c <= 0x148) or (c >= 0x179 and c <= 0x17E) then return c % 2 == 0 and c - 1 or c end
  if c >= 0x3B1 and c <= 0x3C9 and c ~= 0x3C2 then return c - 32 end
  if c >= 0x430 and c <= 0x44F then return c - 32 end
  if c >= 0x450 and c <= 0x45F then return c - 80 end
  return c
end

local function lowerCp(c)
  if c >= 65 and c <= 90 then
    if c == 73 and trRules then return 0x131 end         -- I -> ı
    return c + 32
  end
  if c < 0xC0 then return c end
  if c == 0x130 then return 105 end                      -- İ -> i
  if c == 0x178 then return 0xFF end
  if c >= 0xC0 and c <= 0xDE and c ~= 0xD7 then return c + 32 end
  if (c >= 0x100 and c <= 0x12F) or (c >= 0x132 and c <= 0x137) or (c >= 0x14A and c <= 0x177) then
    return c % 2 == 0 and c + 1 or c
  end
  if (c >= 0x139 and c <= 0x148) or (c >= 0x179 and c <= 0x17E) then return c % 2 == 1 and c + 1 or c end
  if c >= 0x391 and c <= 0x3A9 and c ~= 0x3A2 then return c + 32 end
  if c >= 0x410 and c <= 0x42F then return c + 32 end
  if c >= 0x400 and c <= 0x40F then return c + 80 end
  return c
end

local function isLetter(c)
  if (c >= 65 and c <= 90) or (c >= 97 and c <= 122) then return true end
  if c < 0xC0 then return false end
  return c ~= 0xD7 and c ~= 0xF7
end
local function isWordCp(c) return isLetter(c) or (c >= 48 and c <= 57) or c == 39 or c == 0x2019 end

local buf = {}
local function mapString(s, fn)
  local n = 0
  for _, c in utf8.codes(s) do n = n + 1; buf[n] = utf8.char(fn(c)) end
  local r = table.concat(buf, "", 1, n)
  for i = n, 1, -1 do buf[i] = nil end
  return r
end

local function toUpper(s) return mapString(s, upperCp) end
local function toLower(s) return mapString(s, lowerCp) end

local function toTitle(s)
  local n, prevWord = 0, false
  for _, c in utf8.codes(s) do
    n = n + 1
    local w = isWordCp(c)
    buf[n] = utf8.char(w and (prevWord and lowerCp(c) or upperCp(c)) or c)
    prevWord = w
  end
  local r = table.concat(buf, "", 1, n)
  for i = n, 1, -1 do buf[i] = nil end
  return r
end

-- sentence case runs over the whole text so sentences may span lines
local function toSentence(s)
  local n, start = 0, true
  for _, c in utf8.codes(s) do
    n = n + 1
    if isLetter(c) then
      buf[n] = utf8.char(start and upperCp(c) or lowerCp(c))
      start = false
    else
      buf[n] = utf8.char(c)
      if c == 46 or c == 33 or c == 63 or (c == 10 and n > 1 and buf[n - 1] == "\n") then start = true end
    end
  end
  local r = table.concat(buf, "", 1, n)
  for i = n, 1, -1 do buf[i] = nil end
  return r
end

local function invertCase(s)
  return mapString(s, function(c)
    local u = upperCp(c)
    if u ~= c then return u end
    return lowerCp(c)
  end)
end

-- ------------------------------------------------------------------ collation (Turkish alphabet order)
local ORDER = {}
do
  local alpha = {"a", "b", "c", "ç", "d", "e", "f", "g", "ğ", "h", "ı", "i", "j", "k", "l", "m", "n", "o", "ö", "p",
                 "q", "r", "s", "ş", "t", "u", "ü", "v", "w", "x", "y", "z"}
  for i, ch in ipairs(alpha) do ORDER[utf8.codepoint(ch)] = 1000 + i * 2 end
end

local function sortKey(s)
  local k = {}
  for _, c in utf8.codes(s) do
    local lc = ignoreCase and lowerCp(c) or c
    local w = ORDER[lc]
    if not w then
      local base = ORDER[lowerCp(c)]
      if base then w = base + 1             -- upper case right after its lower case letter (case-sensitive mode)
      elseif lc >= 48 and lc <= 57 then w = 500 + lc
      elseif lc < 128 then w = lc
      else w = 2000 + lc end
    end
    k[#k + 1] = w
  end
  return k
end

local function keyLess(a, b)
  local n = math.min(#a, #b)
  for i = 1, n do if a[i] ~= b[i] then return a[i] < b[i] end end
  return #a < #b
end

-- ------------------------------------------------------------------ text model
local function getText() return table.concat(lines, "\n") end

local function recalcCols()
  maxCols = 0
  for _, l in ipairs(lines) do local n = ulen(l); if n > maxCols then maxCols = n end end
end

local function changed()
  statsDirty = true
  saveT = 0.4
  recalcCols()
end

local function setText(s)
  s = sanitize(s or ""):gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\t", "    ")
  lines = {}
  for l in (s .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
  if #lines == 0 then lines[1] = "" end
  cl = math.min(cl, #lines)
  cc = math.min(cc, ulen(lines[cl]))
  changed()
end

local function pushUndo(kind)
  local now = sys.time()
  if kind == "type" and lastKind == "type" and now - lastPush < 1.5 then lastPush = now; return end
  undoStack[#undoStack + 1] = {getText(), cl, cc}
  if #undoStack > 60 then table.remove(undoStack, 1) end
  for i = #redoStack, 1, -1 do redoStack[i] = nil end
  lastPush, lastKind = now, kind
end

local function restore(from, to)
  local s = table.remove(from)
  if not s then return false end
  to[#to + 1] = {getText(), cl, cc}
  setText(s[1])
  cl = math.max(1, math.min(s[2], #lines))
  cc = math.max(0, math.min(s[3], ulen(lines[cl])))
  lastKind = ""
  return true
end
local function undo() if restore(undoStack, redoStack) then audio.play("pop") end end
local function redo() if restore(redoStack, undoStack) then audio.play("pop") end end

local function insert(str)
  str = sanitize(str):gsub("\r\n", "\n"):gsub("\r", "\n"):gsub("\t", "    ")
  local line = lines[cl]
  local left, right = usub(line, 1, cc), usub(line, cc + 1)
  local parts = {}
  for p in (str .. "\n"):gmatch("(.-)\n") do parts[#parts + 1] = p end
  if #parts == 1 then
    lines[cl] = left .. parts[1] .. right
    cc = cc + ulen(parts[1])
  else
    lines[cl] = left .. parts[1]
    for i = 2, #parts do table.insert(lines, cl + i - 1, parts[i]) end
    cl = cl + #parts - 1
    cc = ulen(parts[#parts])
    lines[cl] = lines[cl] .. right
  end
  changed()
end

local function backspace()
  if cc > 0 then
    local line = lines[cl]
    lines[cl] = usub(line, 1, cc - 1) .. usub(line, cc + 1)
    cc = cc - 1
  elseif cl > 1 then
    cc = ulen(lines[cl - 1])
    lines[cl - 1] = lines[cl - 1] .. lines[cl]
    table.remove(lines, cl)
    cl = cl - 1
  end
  changed()
end

local function deleteFwd()
  local line = lines[cl]
  if cc < ulen(line) then
    lines[cl] = usub(line, 1, cc) .. usub(line, cc + 2)
  elseif cl < #lines then
    lines[cl] = line .. lines[cl + 1]
    table.remove(lines, cl + 1)
  end
  changed()
end

local function isEmpty() return #lines == 1 and lines[1] == "" end

local function flash(text) msg, msgT = text, 2.6 end

local function done(text)
  flash(text)
  flashT = 1
  audio.tone(660, 0.05, 0.2, "triangle")
  audio.tone(990, 0.08, 0.12, "sine")
end

-- ------------------------------------------------------------------ operations
local function needText()
  if isEmpty() then flash(TR("need_text")); audio.play("error"); return false end
  return true
end

local function mapLines(fn)
  for i, l in ipairs(lines) do lines[i] = fn(l) end
  cc = math.min(cc, ulen(lines[cl]))
  changed()
end

local OPS = {}
OPS.upper = function() pushUndo("op"); mapLines(toUpper); done(TR("done_upper")) end
OPS.lower = function() pushUndo("op"); mapLines(toLower); done(TR("done_lower")) end
OPS.title = function() pushUndo("op"); mapLines(toTitle); done(TR("done_title")) end
OPS.sentence = function() pushUndo("op"); setText(toSentence(getText())); done(TR("done_sentence")) end
OPS.invert = function() pushUndo("op"); mapLines(invertCase); done(TR("done_invert")) end

OPS.trim = function()
  pushUndo("op")
  local n = 0
  mapLines(function(l)
    local t = l:gsub("^%s+", ""):gsub("%s+$", ""):gsub("  +", " ")
    if t ~= l then n = n + 1 end
    return t
  end)
  done(TR("done_trim", n))
end

OPS.empty = function()
  pushUndo("op")
  local out, removed = {}, 0
  for _, l in ipairs(lines) do
    if l:match("^%s*$") then removed = removed + 1 else out[#out + 1] = l end
  end
  if #out == 0 then out[1] = "" end
  lines = out
  cl, cc = math.min(cl, #lines), 0
  changed()
  done(TR("done_empty", removed))
end

OPS.dedupe = function()
  pushUndo("op")
  local seen, out, removed = {}, {}, 0
  for _, l in ipairs(lines) do
    local key = l:gsub("^%s+", ""):gsub("%s+$", "")
    if ignoreCase then key = toLower(key) end
    if key ~= "" and seen[key] then removed = removed + 1
    else
      if key ~= "" then seen[key] = true end
      out[#out + 1] = l
    end
  end
  lines = out
  cl, cc = math.min(cl, #lines), 0
  changed()
  done(TR("done_dedupe", removed))
end

local function sortLines(desc, byLength)
  pushUndo("op")
  local items = {}
  for i, l in ipairs(lines) do items[i] = {l = l, k = sortKey(l), n = ulen(l), i = i} end
  table.sort(items, function(a, b)
    if byLength then
      if a.n ~= b.n then return a.n < b.n end
      return a.i < b.i
    end
    if desc then
      if keyLess(b.k, a.k) then return true end
      if keyLess(a.k, b.k) then return false end
    else
      if keyLess(a.k, b.k) then return true end
      if keyLess(b.k, a.k) then return false end
    end
    return a.i < b.i
  end)
  for i, it in ipairs(items) do lines[i] = it.l end
  cc = 0
  changed()
  done(TR("done_sort", #lines))
end
OPS.sortAZ = function() sortLines(false) end
OPS.sortZA = function() sortLines(true) end
OPS.sortLen = function() sortLines(false, true) end

OPS.reverse = function()
  pushUndo("op")
  local n = #lines
  for i = 1, n // 2 do lines[i], lines[n - i + 1] = lines[n - i + 1], lines[i] end
  changed()
  done(TR("done_reverse"))
end

OPS.shuffle = function()
  pushUndo("op")
  for i = #lines, 2, -1 do
    local j = math.random(i)
    lines[i], lines[j] = lines[j], lines[i]
  end
  changed()
  done(TR("done_shuffle"))
end

OPS.number = function()
  pushUndo("op")
  local width = #tostring(#lines)
  for i, l in ipairs(lines) do lines[i] = string.format("%" .. width .. "d. %s", i, l) end
  cc = 0
  changed()
  done(TR("done_number"))
end

OPS.join = function()
  pushUndo("op")
  local parts = {}
  for _, l in ipairs(lines) do
    local t = l:gsub("^%s+", ""):gsub("%s+$", "")
    if t ~= "" then parts[#parts + 1] = t end
  end
  lines = {table.concat(parts, " ")}
  cl, cc = 1, 0
  changed()
  done(TR("done_join"))
end

local function runOp(name)
  if not needText() then return end
  OPS[name]()
end

-- ------------------------------------------------------------------ statistics
local function computeStats()
  statsDirty = false
  local text = getText()
  stats.chars = ulen(text) - (#lines - 1)          -- newlines are not counted as characters
  local ns = text:gsub("%s", "")
  stats.noSpace = ulen(ns)
  stats.lines = isEmpty() and 0 or #lines
  local words, totalLen, counts, unique = 0, 0, {}, 0
  local longest, longestN = "", 0
  for w in text:gmatch("%S+") do
    local clean = w:gsub("^[%p]+", ""):gsub("[%p]+$", "")
    if clean ~= "" then
      words = words + 1
      local n = ulen(clean)
      totalLen = totalLen + n
      if n > longestN then longest, longestN = clean, n end
      local k = toLower(clean)
      if not counts[k] then counts[k] = 0; unique = unique + 1 end
      counts[k] = counts[k] + 1
    end
  end
  stats.words, stats.unique = words, unique
  stats.avgWord = words > 0 and totalLen / words or 0
  stats.longest = longest
  local sentences = 0
  for _ in text:gmatch("[%w\128-\255][%)\"']*[%.!%?]+") do sentences = sentences + 1 end
  if sentences == 0 and words > 0 then sentences = 1 end
  if words > 0 and not text:match("[%.!%?][%)\"'%s]*$") and sentences > 0 and text:find("[%.!%?]") then
    sentences = sentences + 1
  end
  stats.sentences = sentences
  local paras, inPara = 0, false
  for _, l in ipairs(lines) do
    if l:match("%S") then if not inPara then paras = paras + 1; inPara = true end else inPara = false end
  end
  stats.paras = paras
  -- the five most frequent words with at least 3 letters
  for i = #top, 1, -1 do top[i] = nil end
  for k, c in pairs(counts) do
    if ulen(k) >= 3 then
      local pos = #top + 1
      for i = 1, #top do if c > top[i][2] or (c == top[i][2] and k < top[i][1]) then pos = i break end end
      if pos <= 5 then
        table.insert(top, pos, {k, c})
        if #top > 5 then top[6] = nil end
      end
    end
  end
end

local function readingTime()
  local secs = math.floor(stats.words / 200 * 60 + 0.5)
  if stats.words == 0 then return "0" end
  if secs < 60 then return TR("secs", math.max(1, secs)) end
  return TR("mins", math.floor(secs / 60 + 0.5))
end

-- ------------------------------------------------------------------ files and clipboard
local function openFile()
  ui.openFile(function(path)
    if not path then return end
    local s = fs.read(path)
    if not s then flash(TR("open_fail")); audio.play("error"); return end
    if #s > 400000 then flash(TR("too_big")); audio.play("error"); return end
    pushUndo("op")
    cl, cc = 1, 0
    setText(s)
    done(TR("opened", #lines))
  end, {".txt", ".md", ".csv", ".log", ".json", ".lua", ".ini"}, TR("open"))
end

local function saveFile()
  if not needText() then return end
  ui.saveFile(function(path)
    if not path then return end
    if fs.write(path, getText() .. "\n") then done(TR("saved")) else flash(TR("save_fail")); audio.play("error") end
  end, "text.txt", TR("save"))
end

local function copyAll()
  if not needText() then return end
  sys.clipboard(getText())
  done(TR("copied"))
end

local function paste()
  local s = sys.clipboard()
  if not s or s == "" then flash(TR("clip_empty")); return end
  pushUndo("op")
  insert(s)
  done(TR("pasted"))
end

local function clearAll()
  if isEmpty() then return end
  pushUndo("op")
  lines = {""}
  cl, cc = 1, 0
  changed()
  flash(TR("cleared"))
  audio.play("trash")
end

local function sampleText()
  pushUndo("op")
  cl, cc = 1, 0
  setText(TR("sample"))
  done(TR("sample_loaded"))
end

-- ------------------------------------------------------------------ lifecycle
function app.load(arg)
  TOOLBAR = {
    {"open", "file_open", openFile, TR("tb_open")}, {"save", "save", saveFile, TR("tb_save")},
    {"copy", "content_copy", copyAll, TR("tb_copy")}, {"paste", "content_paste", paste, TR("tb_paste")},
    {"undo", "undo", undo, TR("tb_undo")}, {"redo", "redo", redo, TR("tb_redo")}, {"clear", "delete", clearAll, TR("tb_clear")},
  }
  trRules = store.get("trRules", sys.lang() == "tr")
  ignoreCase = store.get("ignoreCase", true)
  panel = store.get("panel", 1)
  if panel ~= 1 and panel ~= 2 then panel = 1 end
  local t = store.get("text", "")
  setText(type(t) == "string" and t or "")
  cl, cc = #lines, ulen(lines[#lines])
  if arg and arg ~= "" then app.open(arg) end
end

-- opened with a file ("Open With" in Files)
function app.open(arg)
  if not arg or arg == "" then return end
  local s = fs.read(arg)
  if not s or #s > 400000 then flash(TR("open_fail")); return end
  pushUndo("op")
  cl, cc = 1, 0
  setText(s)
  done(TR("opened", #lines))
end

function app.update(dt)
  blink = blink + dt
  if msgT > 0 then msgT = msgT - dt end
  if flashT > 0 then flashT = math.max(0, flashT - dt * 1.6) end
  if saveT >= 0 then
    saveT = saveT - dt
    if saveT < 0 then store.set("text", getText()) end
  end
  if statsDirty then computeStats() end
end

-- ------------------------------------------------------------------ drawing
local function drawEditor(x, y, w, h)
  ex, ey, ew, eh = x, y, w, h
  charW = gfx.textWidth("MMMMMMMMMM", FONT, "mono") / 10
  if charW <= 0 then charW = 8.4 end
  gfx.rect(x, y, w, h, 10, theme.field)
  gfx.color(focused and theme.accent or theme.separator)
  gfx.rectLine(x, y, w, h, 10, focused and 2 or 1)
  local gutter = 30 + #tostring(#lines) * 8
  local contentH = #lines * LINE_H + PAD * 2
  local contentW = maxCols * charW + gutter + PAD * 2 + 20
  scrollY, scrollX = ui.beginScroll("editor", x + 2, y + 2, w - 4, h - 4, contentH, contentW)
  scrollY, scrollX = scrollY or 0, scrollX or 0
  local first = math.max(1, math.floor((scrollY - PAD) / LINE_H) + 1)
  local last = math.min(#lines, first + math.ceil(h / LINE_H) + 1)
  if flashT > 0 then
    gfx.alpha(flashT * 0.35)
    gfx.rect(0, 0, math.max(w, contentW), math.max(h, contentH), 0, theme.accent)
    gfx.unalpha()
  end
  for i = first, last do
    local ly = PAD + (i - 1) * LINE_H
    if focused and i == cl then gfx.rect(scrollX, ly - 1, w, LINE_H, 0, theme.hover) end
    gfx.color(theme.text3)
    gfx.text(tostring(i), scrollX, ly + 2, 11, "mono", "right", gutter - 12)
    gfx.color(theme.text)
    gfx.text(lines[i], gutter + PAD, ly + 1, FONT, "mono")
  end
  if focused and blink % 1 < 0.6 then
    gfx.color(theme.accent)
    gfx.rect(gutter + PAD + cc * charW - 1, PAD + (cl - 1) * LINE_H, 2, LINE_H - 2)
  end
  gfx.color(theme.separator)
  gfx.line(scrollX + gutter - 4, 0, scrollX + gutter - 4, math.max(h, contentH), 1)
  ui.endScroll()
  if isEmpty() and not focused then
    gfx.icon("text_fields", x + w / 2, y + h / 2 - 40, 48, theme.text3)
    gfx.color(theme.text2)
    gfx.text(TR("empty_title"), x + 20, y + h / 2 - 6, 15, "semibold", "center", w - 40)
    gfx.color(theme.text3)
    gfx.text(TR("empty_sub"), x + 20, y + h / 2 + 16, 12, "sans", "center", w - 40)
  end
  return gutter
end

local editorGutter = 40
local panelH = 600

local function caretFromPoint(px, py)
  local line = math.floor((py - ey - 2 + scrollY - PAD) / LINE_H) + 1
  line = math.max(1, math.min(#lines, line))
  local col = math.floor((px - ex - 2 + scrollX - editorGutter - PAD) / charW + 0.5)
  col = math.max(0, math.min(ulen(lines[line]), col))
  cl, cc = line, col
  blink = 0
end

local function opButton(label, icon, op, x, y, w)
  if ui.button(label, x, y, w, 32, "default", icon) then runOp(op) end
end

local function drawTools(w)
  local y = 4
  local half = (w - 8) / 2
  local function header(text)
    gfx.color(theme.text2)
    gfx.text(text, 2, y, 11, "semibold")
    y = y + 20
  end
  header(TR("sec_case"))
  opButton(TR("op_upper"), "arrow_upward", "upper", 0, y, half)
  opButton(TR("op_lower"), "arrow_downward", "lower", half + 8, y, half); y = y + 38
  opButton(TR("op_title"), "text_fields", "title", 0, y, half)
  opButton(TR("op_sentence"), "format_size", "sentence", half + 8, y, half); y = y + 38
  opButton(TR("op_invert"), "swap_vert", "invert", 0, y, half)
  local r = ui.checkbox(TR("opt_tr"), trRules, half + 12, y + 7)
  if r ~= trRules then trRules = r; store.set("trRules", r) end
  y = y + 46
  header(TR("sec_clean"))
  opButton(TR("op_trim"), "cleaning_services", "trim", 0, y, half)
  opButton(TR("op_empty"), "filter_list", "empty", half + 8, y, half); y = y + 38
  opButton(TR("op_dedupe"), "content_copy", "dedupe", 0, y, half)
  opButton(TR("op_join"), "drag_handle", "join", half + 8, y, half); y = y + 46
  header(TR("sec_lines"))
  opButton(TR("op_sortaz"), "sort_by_alpha", "sortAZ", 0, y, half)
  opButton(TR("op_sortza"), "sort_by_alpha", "sortZA", half + 8, y, half); y = y + 38
  opButton(TR("op_sortlen"), "sort", "sortLen", 0, y, half)
  opButton(TR("op_reverse"), "swap_vert", "reverse", half + 8, y, half); y = y + 38
  opButton(TR("op_shuffle"), "shuffle", "shuffle", 0, y, half)
  opButton(TR("op_number"), "format_list_numbered", "number", half + 8, y, half); y = y + 40
  local ic = ui.checkbox(TR("opt_ignore"), ignoreCase, 2, y + 4)
  if ic ~= ignoreCase then ignoreCase = ic; store.set("ignoreCase", ic) end
  return y + 36
end

local function statRow(label, value, y, w)
  gfx.color(theme.text2)
  gfx.text(label, 12, y, 13)
  gfx.color(theme.text)
  gfx.text(value, 0, y, 13, "semibold", "right", w - 12)
end

local function fmtNum(n)
  local s = tostring(math.floor(n))
  local sep = sys.lang() == "tr" and "." or ","
  local out = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
  if out:sub(1, 1) == sep then out = out:sub(2) end
  return out
end

local function drawStats(w)
  local y = 4
  -- big counters
  local cw = (w - 16) / 3
  local big = {{TR("st_words"), stats.words}, {TR("st_chars"), stats.chars}, {TR("st_lines"), stats.lines}}
  for i, b in ipairs(big) do
    local bx = (i - 1) * (cw + 8)
    gfx.rect(bx, y, cw, 64, 10, theme.hover)
    gfx.color(theme.accent)
    gfx.text(fmtNum(b[2]), bx, y + 10, 22, "bold", "center", cw)
    gfx.color(theme.text2)
    gfx.text(b[1], bx, y + 40, 11, "semibold", "center", cw)
  end
  y = y + 76
  ui.group(0, y, w, 7 * 28 + 8)
  local rows = {
    {TR("st_nospace"), fmtNum(stats.noSpace)}, {TR("st_sentences"), fmtNum(stats.sentences)},
    {TR("st_paras"), fmtNum(stats.paras)}, {TR("st_unique"), fmtNum(stats.unique)},
    {TR("st_avg"), string.format("%.1f", stats.avgWord)}, {TR("st_read"), readingTime()},
    {TR("st_longest"), stats.longest ~= "" and stats.longest or "-"},
  }
  for i, r in ipairs(rows) do
    statRow(r[1], r[2], y + 10 + (i - 1) * 28, w)
    if i < #rows then ui.separator(12, y + 32 + (i - 1) * 28, w - 12) end
  end
  y = y + 7 * 28 + 20
  gfx.color(theme.text2)
  gfx.text(TR("st_top"), 2, y, 11, "semibold")
  y = y + 20
  if #top == 0 then
    gfx.color(theme.text3)
    gfx.text(TR("st_top_empty"), 2, y, 12)
    return y + 30
  end
  local mx = top[1][2]
  local colors = {theme.blue, theme.purple, theme.pink, theme.orange, theme.green}
  for i, t in ipairs(top) do
    local bw = math.max(6, (w - 130) * t[2] / mx)
    gfx.color(theme.text)
    gfx.clip(0, y, 96, 24)
    gfx.text(t[1], 2, y + 4, 13)
    gfx.unclip()
    gfx.rect(100, y + 3, bw, 18, 6, colors[i])
    gfx.color(theme.text2)
    gfx.text(tostring(t[2]), 106 + bw, y + 4, 12, "semibold")
    y = y + 28
  end
  return y + 10
end

local TOOLBAR = {}

local function toolbar(w)
  local items = TOOLBAR
  local labels = w >= 820
  local x = 12
  for _, it in ipairs(items) do
    local enabled = true
    if it[1] == "undo" then enabled = #undoStack > 0
    elseif it[1] == "redo" then enabled = #redoStack > 0 end
    if labels then
      local label = it[4]
      local bw = gfx.textWidth(label, 13) + 46
      if ui.button(label .. "##tb", x, 10, bw, 32, "toolbar", it[2], enabled) then it[3]() end
      x = x + bw + 4
    else
      if ui.iconButton(it[2], x, 10, 36, 32, enabled and theme.text or theme.text3, false, "tb" .. it[1]) and enabled then
        it[3]()
      end
      x = x + 40
    end
  end
  return x
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local tx = toolbar(w)
  -- live counter at the right of the toolbar
  if w - tx > 140 then
    gfx.color(theme.text2)
    gfx.text(TR("counter", fmtNum(stats.words), fmtNum(stats.chars)), tx, 18, 12, "sans", "right", w - tx - 14)
  end
  local wide = w >= 760
  local pw = wide and math.min(340, math.floor(w * 0.38)) or w - 24
  local top0 = 52
  local edW = wide and (w - pw - 36) or (w - 24)
  local edH = wide and (h - top0 - 56) or math.floor((h - top0) * 0.45)
  editorGutter = drawEditor(12, top0, edW, edH)
  -- single-line input that appends a line (works with the console's on-screen keyboard)
  local fy = top0 + edH + 8
  local nl, sub = ui.textfield("addline", addLine, 12, fy, edW - 112, 34, TR("add_ph"))
  addLine = nl
  if ui.button(TR("add_line"), 12 + edW - 104, fy, 104, 34, "primary", "add") or sub then
    if addLine ~= "" then
      pushUndo("op")
      if isEmpty() then lines[1] = addLine else lines[#lines + 1] = addLine end
      cl, cc = #lines, ulen(lines[#lines])
      changed()
      addLine = ""
      audio.play("key")
    else
      ui.keyboard(getText(), function(s)
        if s then pushUndo("op"); setText(s) end
      end, TR("kb_guide"))
    end
  end
  -- side / bottom panel
  local px = wide and (w - pw - 12) or 12
  local py = wide and top0 or (fy + 44)
  local ph = h - py - 8
  panel = ui.segmented("panel", {TR("tab_tools"), TR("tab_stats")}, panel, px, py, pw, 30)
  ui.beginScroll("panelscroll", px, py + 38, pw, ph - 38, panelH)
  if panel == 1 then panelH = drawTools(pw) else panelH = drawStats(pw) end
  ui.endScroll()
  -- toast
  if msg and msgT > 0 then
    local tw = gfx.textWidth(msg, 13, "semibold") + 32
    gfx.alpha(math.min(1, msgT * 2))
    gfx.shadow((w - tw) / 2, h - 54, tw, 34, 17, 10, 3)
    gfx.rect((w - tw) / 2, h - 54, tw, 34, 17, theme.dark and "#3A3A3C" or "#1C1C1E")
    gfx.color("#FFFFFF")
    gfx.text(msg, (w - tw) / 2, h - 45, 13, "semibold", "center", tw)
    gfx.unalpha()
  end
end

-- ------------------------------------------------------------------ input
function app.event(e)
  local t = e.type
  if t == "mousedown" then
    local inside = e.x >= ex and e.x < ex + ew and e.y >= ey and e.y < ey + eh
    focused = inside and e.button == "left" or (inside and focused)
    if inside and e.button == "left" then caretFromPoint(e.x, e.y) end
    if inside and e.button == "right" then
      ui.contextMenu({{label = TR("tb_copy"), id = 1, icon = "content_copy"}, {label = TR("tb_paste"), id = 2, icon = "content_paste"},
                      "-", {label = TR("tb_undo"), id = 3, icon = "undo"}, {label = TR("tb_clear"), id = 4, icon = "delete"}},
        function(id)
          if id == 1 then copyAll() elseif id == 2 then paste() elseif id == 3 then undo() elseif id == 4 then clearAll() end
        end)
    end
    return
  end
  if t == "keydown" and e.ctrl then
    local k = e.key
    if k == "z" then if e.shift then redo() else undo() end
    elseif k == "y" then redo()
    elseif k == "o" then openFile()
    elseif k == "s" then saveFile()
    elseif k == "c" and focused then copyAll()
    elseif k == "v" and focused then paste()
    elseif k == "u" then runOp("upper")
    elseif k == "l" then runOp("lower")
    end
    return
  end
  if not focused then return end
  if t == "text" and e.text and e.text ~= "" then
    pushUndo("type")
    insert(e.text)
    blink = 0
  elseif t == "keydown" then
    local k = e.key
    blink = 0
    if k == "enter" then pushUndo("op"); insert("\n")
    elseif k == "backspace" then pushUndo("type"); backspace()
    elseif k == "delete" then pushUndo("type"); deleteFwd()
    elseif k == "tab" then pushUndo("type"); insert("    ")
    elseif k == "left" then
      if cc > 0 then cc = cc - 1 elseif cl > 1 then cl = cl - 1; cc = ulen(lines[cl]) end
    elseif k == "right" then
      if cc < ulen(lines[cl]) then cc = cc + 1 elseif cl < #lines then cl = cl + 1; cc = 0 end
    elseif k == "up" then
      if cl > 1 then cl = cl - 1; cc = math.min(cc, ulen(lines[cl])) end
    elseif k == "down" then
      if cl < #lines then cl = cl + 1; cc = math.min(cc, ulen(lines[cl])) end
    elseif k == "home" then cc = 0
    elseif k == "end" then cc = ulen(lines[cl])
    elseif k == "pageup" then cl = math.max(1, cl - 15); cc = math.min(cc, ulen(lines[cl]))
    elseif k == "pagedown" then cl = math.min(#lines, cl + 15); cc = math.min(cc, ulen(lines[cl]))
    elseif k == "escape" then focused = false
    end
  end
end

function app.menu()
  return {
    {title = TR("menu_file"), items = {
      {label = TR("tb_open"), id = 1, shortcut = "Ctrl+O"},
      {label = TR("tb_save"), id = 2, shortcut = "Ctrl+S"},
      "-",
      {label = TR("sample_menu"), id = 3},
      {label = TR("tb_clear"), id = 4},
    }},
    {title = TR("menu_edit"), items = {
      {label = TR("tb_undo"), id = 10, shortcut = "Ctrl+Z"},
      {label = TR("tb_redo"), id = 11, shortcut = "Ctrl+Y"},
      "-",
      {label = TR("tb_copy"), id = 12, shortcut = "Ctrl+C"},
      {label = TR("tb_paste"), id = 13, shortcut = "Ctrl+V"},
    }},
    {title = TR("menu_convert"), items = {
      {label = TR("op_upper"), id = 20, shortcut = "Ctrl+U"}, {label = TR("op_lower"), id = 21, shortcut = "Ctrl+L"},
      {label = TR("op_title"), id = 22}, {label = TR("op_sentence"), id = 23}, "-",
      {label = TR("op_trim"), id = 24}, {label = TR("op_empty"), id = 25}, {label = TR("op_dedupe"), id = 26}, "-",
      {label = TR("op_sortaz"), id = 27}, {label = TR("op_sortza"), id = 28}, {label = TR("op_reverse"), id = 29},
    }},
  }
end

local MENU_OPS = {[20] = "upper", [21] = "lower", [22] = "title", [23] = "sentence", [24] = "trim", [25] = "empty",
                  [26] = "dedupe", [27] = "sortAZ", [28] = "sortZA", [29] = "reverse"}

function app.onmenu(id)
  if id == 1 then openFile() elseif id == 2 then saveFile() elseif id == 3 then sampleText()
  elseif id == 4 then clearAll() elseif id == 10 then undo() elseif id == 11 then redo()
  elseif id == 12 then copyAll() elseif id == 13 then paste()
  elseif MENU_OPS[id] then runOp(MENU_OPS[id]) end
end

function app.close()
  store.set("text", getText())
  store.set("panel", panel)
  store.save()
  return true
end

return app
