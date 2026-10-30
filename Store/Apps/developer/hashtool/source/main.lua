-- Base64 & Hash: encode/decode text (Base64, URL-safe Base64, Hex, URL) and compute checksums
-- (CRC32, Adler-32, FNV-1a, MD5, SHA-1, SHA-256) in pure Lua. Nexvyn OS Lua SDK.
local codec = require("codec")
local app = {}

local floor, min, max = math.floor, math.min, math.max
local M = 18                    -- outer margin
local MAX_INPUT = 1024 * 1024   -- bytes kept in the input / read from a file
local SHOW_BYTES = 6000         -- bytes drawn in the text views (the full text is still used)

-- ------------------------------------------------------------------ state
local tab = 1                   -- 1 encode/decode, 2 checksums
local fmtSel, dirSel = 1, 1     -- format (Base64, Base64URL, Hex, URL) and direction (encode, decode)
local upper = false
local text = ""
local undoText = nil            -- text before the last clear/replace (Ctrl+Z)
local focused, focusAnim = false, 0

local stats = {chars = 0, bytes = 0, lines = 0, utf8 = true}
local out, outErr, outBinary = "", nil, false
local outShow, outAnim = "", 0
local inShow = ""
local dirty = true

local fileData, fileName = nil, nil   -- a file picked for hashing (replaces the text as the hash source)
local ALGOS = {
  {name = "CRC32", fn = function(s) return string.format("%08x", codec.crc32(s)) end},
  {name = "Adler-32", fn = function(s) return string.format("%08x", codec.adler32(s)) end},
  {name = "FNV-1a 32", fn = function(s) return string.format("%08x", codec.fnv1a(s)) end},
  {name = "MD5", fn = codec.md5},
  {name = "SHA-1", fn = codec.sha1},
  {name = "SHA-256", fn = codec.sha256},
}
local hashes = {}               -- algorithm index -> lowercase hex
local hashNext = 1              -- next algorithm to compute (one per frame keeps big inputs smooth)
local compare = ""
local toast, toastT, toastUndo = "", 0, false

-- ------------------------------------------------------------------ helpers
local function utf8Cut(s, n)    -- first n bytes without splitting a UTF-8 sequence
  if #s <= n then return s end
  local i = n
  while i > 0 and (s:byte(i + 1) or 0) >= 0x80 and (s:byte(i + 1) or 0) < 0xC0 do i = i - 1 end
  return s:sub(1, i)
end

local function sizeText(n)
  if n < 1024 then return n .. " B" end
  if n < 1024 * 1024 then return string.format("%.1f KB", n / 1024) end
  return string.format("%.2f MB", n / 1048576)
end

local function showToast(msg, canUndo)
  toast, toastT, toastUndo = msg, 3.2, canUndo and true or false
end

local function source() return fileData or text end

local function errText(key)
  if key == "err_b64_char" then return TR("err_b64_char")
  elseif key == "err_b64_len" then return TR("err_b64_len")
  elseif key == "err_b64_pad" then return TR("err_b64_pad")
  elseif key == "err_hex_char" then return TR("err_hex_char")
  elseif key == "err_hex_len" then return TR("err_hex_len")
  elseif key == "err_url" then return TR("err_url") end
  return TR("err_generic")
end

-- recompute statistics, the transform result and restart the checksum queue
local function recompute()
  dirty = false
  local n, ok = codec.charCount(text)
  local _, nl = text:gsub("\n", "")
  stats.chars, stats.bytes, stats.utf8 = n, #text, ok
  stats.lines = #text == 0 and 0 or nl + 1
  inShow = utf8Cut(text, SHOW_BYTES)

  local res, err
  if fmtSel == 1 or fmtSel == 2 then
    if dirSel == 1 then res = codec.b64encode(text, fmtSel == 2) else res, err = codec.b64decode(text) end
  elseif fmtSel == 3 then
    if dirSel == 1 then res = codec.hexencode(text, upper) else res, err = codec.hexdecode(text) end
  else
    if dirSel == 1 then res = codec.urlencode(text) else res, err = codec.urldecode(text) end
  end
  out, outErr = res or "", err
  outBinary = res ~= nil and utf8.len(res) == nil
  if outBinary then
    outShow = codec.hexencode(out:sub(1, SHOW_BYTES // 3), upper):gsub("(%x%x)", "%1 ")
  else
    outShow = utf8Cut(out, SHOW_BYTES)
  end
  outAnim = 0
  hashes, hashNext = {}, 1
end

local function setText(s, keepUndo)
  s = s or ""
  if #s > MAX_INPUT then s = utf8Cut(s, MAX_INPUT); showToast(TR("truncated", sizeText(MAX_INPUT))) end
  if keepUndo and text ~= "" then undoText = text end
  text = s
  dirty = true
  if #text <= 64 * 1024 then store.set("text", text) else store.set("text", "") end
end

local function saveSettings()
  store.set("tab", tab); store.set("fmt", fmtSel); store.set("dir", dirSel); store.set("upper", upper)
end

local function hashValue(i)
  local v = hashes[i]
  if v and upper then return v:upper() end
  return v
end

-- ------------------------------------------------------------------ actions
local function paste()
  local c = sys.clipboard() or ""
  if c == "" then showToast(TR("clip_empty")); return end
  setText(c, true)
  showToast(TR("pasted", sizeText(#c)), true)
end

local function editKeyboard()
  ui.keyboard(text, function(s) if s then setText(s, true) end end, TR("input"))
end

local function clearText()
  if text == "" then return end
  setText("", true)
  showToast(TR("cleared"), true)
end

local function undo()
  if not undoText then return end
  local u = undoText
  undoText = nil
  setText(u, false)
  showToast(TR("restored"))
end

local function copyResult()
  local s
  if tab == 1 then
    if outErr or out == "" then return end
    s = outBinary and codec.hexencode(out, upper) or out
  else
    local parts = {}
    for i, a in ipairs(ALGOS) do
      if hashes[i] then parts[#parts + 1] = a.name .. ": " .. hashValue(i) end
    end
    if #parts == 0 then return end
    s = table.concat(parts, "\n")
  end
  sys.clipboard(s)
  audio.play("click", 0.5)
  showToast(TR("copied"))
end

local function useAsInput()
  if tab ~= 1 or outErr or out == "" then return end
  local o = out
  setText(o, true)
  dirSel = dirSel == 1 and 2 or 1      -- encode -> decode makes a quick round trip
  saveSettings()
  showToast(TR("swapped"), true)
end

local function saveResult()
  if tab ~= 1 or outErr or out == "" then return end
  local data = out
  ui.saveFile(function(p)
    if not p then return end
    if fs.write(p, data) then showToast(TR("saved")) else showToast(TR("save_failed")) end
  end, outBinary and "output.bin" or "output.txt", TR("save_result"))
end

local function openFile()
  ui.openFile(function(p)
    if not p then return end
    local d = fs.read(p)
    if not d then showToast(TR("open_failed")); return end
    if #d > MAX_INPUT then showToast(TR("file_too_big", sizeText(MAX_INPUT))); return end
    fileData, fileName = d, p:match("([^/\\]+)$") or p
    tab = 2
    hashes, hashNext = {}, 1
    saveSettings()
  end, {}, TR("open_file"))
end

local function closeFile()
  fileData, fileName = nil, nil
  hashes, hashNext = {}, 1
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  text = tostring(store.get("text", "") or "")
  tab = max(1, min(2, floor(tonumber(store.get("tab", 1)) or 1)))
  fmtSel = max(1, min(4, floor(tonumber(store.get("fmt", 1)) or 1)))
  dirSel = max(1, min(2, floor(tonumber(store.get("dir", 1)) or 1)))
  upper = store.get("upper", false) == true
  dirty = true
end

function app.update(dt)
  if dirty then recompute() end
  -- one checksum per frame, only while the checksum tab is visible
  if tab == 2 and hashNext <= #ALGOS then
    local a = ALGOS[hashNext]
    local ok, v = pcall(a.fn, source())
    hashes[hashNext] = ok and v or "?"
    hashNext = hashNext + 1
  end
  outAnim = min(1, outAnim + dt * 5)
  focusAnim = focusAnim + ((focused and 1 or 0) - focusAnim) * min(1, dt * 12)
  if toastT > 0 then toastT = toastT - dt end
end

-- ------------------------------------------------------------------ drawing
local function card(x, y, w, h)
  gfx.shadow(x, y, w, h, 12, 10, 3)
  gfx.color(theme.window)
  gfx.rect(x, y, w, h, 12)
  gfx.color(theme.separator)
  gfx.rectLine(x, y, w, h, 12, 1)
end

local function emptyState(icon, msg, x, y, w, h)
  local cy = y + h / 2
  gfx.color(theme.accent)
  gfx.alpha(0.14)
  gfx.circle(x + w / 2, cy - 14, 30)
  gfx.unalpha()
  gfx.icon(icon, x + w / 2, cy - 14, 32, theme.accent)
  gfx.color(theme.text2)
  gfx.text(msg, x + 12, cy + 24, 13, "sans", "center", w - 24)
end

-- the input text area: tap to focus (keyboard typing) or open the system keyboard on touch
local function drawInput(x, y, w, h)
  card(x, y, w, h)
  gfx.color(theme.text)
  gfx.text(TR("input"), x + 14, y + 11, 14, "semibold")
  gfx.color(theme.text3)
  local s = TR("stats", stats.chars, sizeText(stats.bytes), stats.lines)
  if not stats.utf8 then s = s .. " · " .. TR("not_utf8") end
  gfx.text(s, x + 20 + gfx.textWidth(TR("input"), 14, "semibold"), y + 13, 12)

  local bx = x + w - 10
  bx = bx - 34
  if ui.iconButton("delete", bx, y + 5, 32, 30, theme.text2, false, "clr") then clearText() end
  bx = bx - 36
  if ui.iconButton("keyboard", bx, y + 5, 32, 30, theme.text2, false, "kb") then editKeyboard() end
  bx = bx - 36
  if ui.iconButton("content_paste", bx, y + 5, 32, 30, theme.text2, false, "paste") then paste() end

  local ax, ay, aw, ah = x + 8, y + 40, w - 16, h - 48
  gfx.color(theme.field)
  gfx.rect(ax, ay, aw, ah, 8)
  if focusAnim > 0.02 then
    gfx.color(theme.accent)
    gfx.alpha(focusAnim)
    gfx.rectLine(ax, ay, aw, ah, 8, 2)
    gfx.unalpha()
  else
    gfx.color(theme.separator)
    gfx.rectLine(ax, ay, aw, ah, 8, 1)
  end
  local tw = aw - 24
  local shown = inShow
  if focused and (sys.time() * 2) % 2 < 1.2 then shown = shown .. "|" end
  local ch = gfx.measureWrap(shown == "" and " " or shown, tw, 13, "mono") + 16
  ui.beginScroll("in_scroll", ax, ay, aw, ah, max(ch, ah))
  local hit = ui.hit("in_area", 0, 0, aw, max(ch, ah))
  if text == "" and not focused then
    gfx.color(theme.text3)
    gfx.wrap(TR("placeholder"), 12, 9, tw, 13)
  elseif shown ~= "" then
    gfx.color(theme.text)
    gfx.wrap(shown, 12, 9, tw, 13, "mono")
  end
  if #text > SHOW_BYTES then
    gfx.color(theme.text3)
    gfx.text(TR("showing", sizeText(SHOW_BYTES), sizeText(#text)), 12, ch - 4, 11)
  end
  ui.endScroll()
  if hit.clicked then
    if input.touch() then editKeyboard() else focused = true end
  end
  if hit.doubleClicked then editKeyboard() end
end

local FORMATS = {"Base64", "Base64URL", "Hex", "URL"}

local function drawTransform(x, y, w, h)
  local dirs = {TR("encode"), TR("decode")}
  local dw = min(220, w * 0.34)
  local fw = w - dw - 12
  local f = ui.segmented("fmt", FORMATS, fmtSel, x, y, fw, 30)
  local d = ui.segmented("dir", dirs, dirSel, x + fw + 12, y, dw, 30)
  if f ~= fmtSel or d ~= dirSel then fmtSel, dirSel = f, d; dirty = true; saveSettings() end

  local cy, chh = y + 42, h - 42 - 46
  card(x, cy, w, chh)
  gfx.color(theme.text)
  gfx.text(TR("output"), x + 14, cy + 11, 14, "semibold")
  if not outErr and out ~= "" then
    gfx.color(theme.text3)
    local info = outBinary and TR("binary", sizeText(#out)) or TR("out_stats", (codec.charCount(out)), sizeText(#out))
    gfx.text(info, x + 20 + gfx.textWidth(TR("output"), 14, "semibold"), cy + 13, 12)
  end
  local ax, ay, aw, ah = x + 8, cy + 40, w - 16, chh - 48
  if text == "" then
    emptyState("swap_horiz", TR("empty_transform"), ax, ay, aw, ah)
  elseif outErr then
    gfx.color(theme.red)
    gfx.alpha(0.1)
    gfx.rect(ax, ay, aw, ah, 8)
    gfx.unalpha()
    gfx.icon("error", ax + aw / 2, ay + ah / 2 - 16, 30, theme.red)
    gfx.color(theme.red)
    gfx.text(errText(outErr), ax + 12, ay + ah / 2 + 10, 14, "semibold", "center", aw - 24)
  else
    local ch = gfx.measureWrap(outShow == "" and " " or outShow, aw - 24, 13, "mono") + 16
    gfx.alpha(0.35 + 0.65 * outAnim)
    ui.beginScroll("out_scroll", ax, ay, aw, ah, max(ch, ah))
    gfx.color(outBinary and theme.purple or theme.text)
    gfx.wrap(outShow, 12, 9 + (1 - outAnim) * 6, aw - 24, 13, "mono")
    if #out > SHOW_BYTES then
      gfx.color(theme.text3)
      gfx.text(TR("showing", sizeText(SHOW_BYTES), sizeText(#out)), 12, ch - 4, 11)
    end
    ui.endScroll()
    gfx.unalpha()
  end

  local ok = not outErr and out ~= ""
  local bw = min(170, (w - 24) / 3)
  local by = y + h - 34
  if ui.button(TR("copy"), x, by, bw, 34, "primary", "content_copy", ok) then copyResult() end
  if ui.button(TR("save"), x + bw + 12, by, bw, 34, "default", "save", ok) then saveResult() end
  if ui.button(TR("use_input"), x + 2 * (bw + 12), by, bw, 34, "default", "swap_vert", ok) then useAsInput() end
end

local function normHash(s)
  return (s or ""):lower():gsub("0x", ""):gsub("[^0-9a-f]", "")
end

local function drawChecksums(x, y, w, h)
  -- source line: the input text or a picked file
  gfx.color(theme.text2)
  local src = fileName and TR("src_file", fileName, sizeText(#fileData)) or TR("src_text", sizeText(#text))
  gfx.icon(fileName and "description" or "text_fields", x + 10, y + 15, 18, theme.text2)
  local bx = x + w
  local srcW = w - (fileName and 120 or 0) - 140 - 110 - 30
  gfx.clip(x + 26, y, max(10, srcW), 30)
  gfx.text(src, x + 26, y + 7, 13, "medium")
  gfx.unclip()
  if fileName then
    bx = bx - 120
    if ui.button(TR("use_text"), bx, y, 120, 30, "plain", "close") then closeFile() end
  end
  bx = bx - 140
  if ui.button(TR("open_file"), bx, y, 136, 30, "default", "folder_open") then openFile() end
  gfx.color(theme.text2)
  gfx.text("ABC", bx - 100, y + 8, 12, "semibold")
  local u = ui.toggle("upper", upper, bx - 64, y + 2)
  if u ~= upper then upper = u; dirty = true; saveSettings() end

  -- checksum rows
  local ly, lh = y + 40, h - 40 - 46
  card(x, ly, w, lh)
  local want = normHash(compare)
  local matched = nil
  local rowH = 40
  ui.beginScroll("hash_scroll", x + 1, ly + 4, w - 2, lh - 8, #ALGOS * rowH)
  for i, a in ipairs(ALGOS) do
    local ry = (i - 1) * rowH
    local v = hashValue(i)
    local match = v and #want >= 8 and want == hashes[i]
    if match then
      matched = a.name
      gfx.color(theme.green)
      gfx.alpha(0.14)
      gfx.rect(6, ry + 2, w - 14, rowH - 4, 8)
      gfx.unalpha()
    end
    if i > 1 then ui.separator(14, ry, w - 16) end
    gfx.color(theme.text2)
    gfx.text(a.name, 14, ry + 12, 13, "semibold")
    if v then
      gfx.color(match and theme.green or theme.text)
      gfx.text(v, 104, ry + 12, 13, "mono")
      if ui.iconButton(match and "check_circle" or "content_copy", w - 46, ry + 5, 34, 30, match and theme.green or theme.text2, false, "h" .. i) then
        sys.clipboard(v)
        showToast(TR("copied_one", a.name))
      end
    else
      ui.spinner(116, ry + 20, 7)
    end
  end
  ui.endScroll()

  -- compare with an expected value
  local cy = y + h - 34
  gfx.color(theme.text2)
  gfx.text(TR("compare"), x, cy + 9, 13, "semibold")
  local lw = gfx.textWidth(TR("compare"), 13, "semibold") + 10
  local fw = w - lw - 46
  compare = ui.textfield("compare", compare, x + lw, cy, fw, 34, TR("compare_hint"))
  if ui.iconButton("content_paste", x + lw + fw + 8, cy + 2, 36, 30, theme.text2, false, "cmp") then
    compare = sys.clipboard() or ""
  end
  if #want >= 8 then
    local done = hashNext > #ALGOS
    gfx.color(matched and theme.green or (done and theme.red or theme.text3))
    local msg = matched and TR("match", matched) or (done and TR("no_match") or TR("computing"))
    gfx.text(msg, x, cy - 20, 12, "semibold", "right", w)
  end
end

local function drawToast(w)
  if toastT <= 0 then return end
  local a = min(1, toastT * 3, (3.2 - toastT) * 6)
  local tw = gfx.textWidth(toast, 13, "medium") + 32 + (toastUndo and 70 or 0)
  local tx, ty = w - M - tw, 14 - (1 - a) * 10
  gfx.alpha(a)
  gfx.shadow(tx, ty, tw, 32, 16, 10, 3)
  gfx.color(theme.text)
  gfx.rect(tx, ty, tw, 32, 16)
  gfx.color(theme.bg)
  gfx.text(toast, tx + 16, ty + 8, 13, "medium")
  gfx.unalpha()
  if toastUndo and undoText and a > 0.5 then
    if ui.button(TR("undo") .. "##toast", tx + tw - 76, ty + 1, 70, 30, "link") then undo(); toastT = 0 end
  end
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local nt = ui.segmented("tabs", {TR("tab_transform"), TR("tab_checksums")}, tab, M, 14, min(320, w - 2 * M - 200), 30)
  if nt ~= tab then tab = nt; saveSettings() end

  local cw = w - 2 * M
  local ih = tab == 1 and max(130, floor((h - 60 - M) * 0.40)) or max(120, floor((h - 60 - M) * 0.34))
  drawInput(M, 56, cw, ih)
  local y = 56 + ih + 14
  if tab == 1 then drawTransform(M, y, cw, h - y - M) else drawChecksums(M, y, cw, h - y - M) end
  drawToast(w)
end

-- ------------------------------------------------------------------ input
local function backspace()
  if text == "" then return end
  local ok, off = pcall(utf8.offset, text, -1)
  if ok and off and off >= 1 then setText(text:sub(1, off - 1)) else setText(text:sub(1, -2)) end
end

function app.event(e)
  if e.type == "mousedown" and focused then
    -- clicking anywhere ends typing; a click on the input area refocuses it in draw
    focused = false
    return
  end
  if e.type == "text" and focused then
    if e.text and e.text ~= "" then setText(text .. e.text) end
    return
  end
  if e.type ~= "keydown" then return end
  local k = e.key
  if e.ctrl then
    if k == "v" then paste() elseif k == "c" then copyResult() elseif k == "l" then clearText()
    elseif k == "z" then undo() elseif k == "u" then useAsInput() elseif k == "s" then saveResult()
    elseif k == "o" then openFile() end
    return
  end
  if focused then
    if k == "backspace" then backspace()
    elseif k == "enter" then setText(text .. "\n")
    elseif k == "tab" then setText(text .. "\t")
    elseif k == "escape" then focused = false end
    return
  end
  if k == "tab" then tab = tab % 2 + 1; saveSettings()
  elseif k == "enter" then focused = true
  elseif k == "left" and tab == 1 then fmtSel = (fmtSel + 2) % 4 + 1; dirty = true; saveSettings()
  elseif k == "right" and tab == 1 then fmtSel = fmtSel % 4 + 1; dirty = true; saveSettings()
  elseif (k == "up" or k == "down") and tab == 1 then dirSel = dirSel % 2 + 1; dirty = true; saveSettings()
  elseif k == "backspace" then clearText() end
end

function app.menu()
  return {
    {title = TR("menu_edit"), items = {
      {label = TR("paste"), id = 1, shortcut = "Ctrl+V"},
      {label = TR("copy_result"), id = 2, shortcut = "Ctrl+C"},
      {label = TR("use_input"), id = 3, shortcut = "Ctrl+U"},
      {label = TR("save_result"), id = 4, shortcut = "Ctrl+S"},
      "-",
      {label = TR("undo"), id = 5, shortcut = "Ctrl+Z"},
      {label = TR("clear"), id = 6, shortcut = "Ctrl+L"},
      {label = TR("edit_keyboard"), id = 7, shortcut = "Enter"},
    }},
    {title = TR("menu_view"), items = {
      {label = TR("tab_transform"), id = 10, shortcut = "Tab"},
      {label = TR("tab_checksums"), id = 11, shortcut = "Tab"},
      {label = TR("open_file"), id = 12, shortcut = "Ctrl+O"},
      {label = TR("uppercase"), id = 13},
    }},
  }
end

function app.onmenu(id)
  if id == 1 then paste() elseif id == 2 then copyResult() elseif id == 3 then useAsInput()
  elseif id == 4 then saveResult() elseif id == 5 then undo() elseif id == 6 then clearText()
  elseif id == 7 then editKeyboard()
  elseif id == 10 then tab = 1; saveSettings() elseif id == 11 then tab = 2; saveSettings()
  elseif id == 12 then openFile()
  elseif id == 13 then upper = not upper; dirty = true; saveSettings() end
end

function app.close()
  store.save()
  return true
end

return app
