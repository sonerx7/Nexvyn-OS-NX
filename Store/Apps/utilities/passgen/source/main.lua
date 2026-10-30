-- Password Generator for Nexvyn OS: random passwords and passphrases with an entropy meter and a masked history.
local app = {}

local floor, min, max, abs, log = math.floor, math.min, math.max, math.abs, math.log
local words = require("words")

-- ------------------------------------------------------------------ color helpers
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
local function fade(c, a)
  local t = rgba(c)
  return {t[1], t[2], t[3], max(0, min(255, floor(t[4] * a + 0.5)))}
end
local function approach(v, target, speed, dt) return v + (target - v) * min(1, dt * speed) end

-- ------------------------------------------------------------------ character sets
local SETS = {
  upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
  lower = "abcdefghijklmnopqrstuvwxyz",
  digits = "0123456789",
  symbols = "!@#$%^&*()-_=+[]{};:,.<>?/~|`'\"",
}
local AMBIGUOUS = "Il1O0o|`'\""
local SEPARATORS = {"-", ".", "_", " ", ""}

local cfg = {mode = 1, length = 20, upper = true, lower = true, digits = true, symbols = true, avoid = false,
             words = 5, wlang = 1, sep = 1, cap = true, num = true, ascii = false}

local history = {}          -- { {pw=, t=epoch, bits=} } newest first, max 10
local revealed = {}         -- [index] = true (not persisted)
local current = ""
local currentChars = {}     -- array of utf8 chars of `current`
local currentBits = 0
local genTime = -10
local shownStrength = 0
local toast, toastT = "", -10
local copiedFlash = -10

-- ------------------------------------------------------------------ randomness
local entropyMix = 0
local function stir()
  -- fold timing jitter into the generator so sequences are not reproducible from the boot seed alone
  entropyMix = (entropyMix * 31 + floor((os.clock() * 1e6) % 1e6) + floor((sys.time() * 1e6) % 1e6)) % 2147483647
  math.randomseed(math.random(1, 2147483646) ~ entropyMix)
end
local function rnd(n) return math.random(1, n) end

local function charsOf(s)
  local t = {}
  for _, c in utf8.codes(s) do t[#t + 1] = utf8.char(c) end
  return t
end

local function filtered(set)
  if not cfg.avoid then return set end
  local out = {}
  for i = 1, #set do
    local ch = set:sub(i, i)
    if not AMBIGUOUS:find(ch, 1, true) then out[#out + 1] = ch end
  end
  return table.concat(out)
end

local function activeSets()
  local list = {}
  for _, k in ipairs({"upper", "lower", "digits", "symbols"}) do
    if cfg[k] then list[#list + 1] = filtered(SETS[k]) end
  end
  return list
end

local function log2(x) return log(x) / log(2) end

-- ------------------------------------------------------------------ Turkish helpers for passphrases
local TR_UP = {["i"] = "İ", ["ı"] = "I", ["ç"] = "Ç", ["ğ"] = "Ğ", ["ö"] = "Ö", ["ş"] = "Ş", ["ü"] = "Ü"}
local TR_ASCII = {["ç"] = "c", ["ğ"] = "g", ["ı"] = "i", ["ö"] = "o", ["ş"] = "s", ["ü"] = "u", ["â"] = "a",
                  ["Ç"] = "C", ["Ğ"] = "G", ["İ"] = "I", ["Ö"] = "O", ["Ş"] = "S", ["Ü"] = "U"}

local function capitalize(wd)
  local first = utf8.offset(wd, 2) or (#wd + 1)
  local head, rest = wd:sub(1, first - 1), wd:sub(first)
  return (TR_UP[head] or (#head == 1 and head:upper() or head)) .. rest
end

local function toAscii(s)
  local out = {}
  for _, c in utf8.codes(s) do
    local ch = utf8.char(c)
    out[#out + 1] = TR_ASCII[ch] or ch
  end
  return table.concat(out)
end

local function wordList()
  return cfg.wlang == 1 and words.tr or words.en
end

-- ------------------------------------------------------------------ generation
local function computeBits()
  if cfg.mode == 1 then
    local pool = table.concat(activeSets())
    if #pool == 0 then return 0 end
    return cfg.length * log2(#pool)
  else
    local list = wordList()
    local b = cfg.words * log2(#list)
    if cfg.num then b = b + log2(10) + log2(cfg.words) end
    return b
  end
end

local function generate()
  stir()
  if cfg.mode == 1 then
    local sets = activeSets()
    if #sets == 0 then
      current = ""
    else
      local pool = table.concat(sets)
      local out = {}
      -- one guaranteed character from every enabled set, the rest from the whole pool
      for _, s in ipairs(sets) do
        if #out < cfg.length then
          local i = rnd(#s)
          out[#out + 1] = s:sub(i, i)
        end
      end
      while #out < cfg.length do
        local i = rnd(#pool)
        out[#out + 1] = pool:sub(i, i)
      end
      for i = #out, 2, -1 do
        local j = rnd(i)
        out[i], out[j] = out[j], out[i]
      end
      current = table.concat(out)
    end
  else
    local list = wordList()
    local parts = {}
    for i = 1, cfg.words do
      local wd = list[rnd(#list)]
      if cfg.cap then wd = capitalize(wd) end
      if cfg.ascii then wd = toAscii(wd) end
      parts[i] = wd
    end
    if cfg.num then
      local k = rnd(#parts)
      parts[k] = parts[k] .. tostring(rnd(10) - 1)
    end
    current = table.concat(parts, SEPARATORS[cfg.sep] or "-")
  end
  currentChars = charsOf(current)
  currentBits = computeBits()
  genTime = sys.time()
end

local function saveCfg()
  store.set("cfg", cfg)
end

local function saveHistory()
  store.set("history", history)
  store.save()
end

local function showToast(s)
  toast, toastT = s, sys.time()
end

local function addHistory(pw)
  if pw == "" then return end
  if history[1] and history[1].pw == pw then return end
  table.insert(history, 1, {pw = pw, t = sys.epoch(), bits = floor(currentBits + 0.5)})
  while #history > 10 do table.remove(history) end
  -- shift reveal flags with the list
  local nr = {}
  for i, v in pairs(revealed) do if v and i + 1 <= 10 then nr[i + 1] = true end end
  revealed = nr
  saveHistory()
end

local function copyCurrent()
  if current == "" then
    audio.play("error")
    return
  end
  sys.clipboard(current)
  addHistory(current)
  copiedFlash = sys.time()
  audio.play("pop")
  showToast(TR("copied"))
end

-- ------------------------------------------------------------------ strength
local STRENGTH = {
  {28, "very_weak", "red"},
  {36, "weak", "orange"},
  {60, "fair", "yellow"},
  {100, "strong", "green"},
  {1e9, "very_strong", "blue"},
}
local function strengthOf(bits)
  for i, s in ipairs(STRENGTH) do
    if bits < s[1] then return i, s end
  end
  return #STRENGTH, STRENGTH[#STRENGTH]
end

-- time to search half the key space at 10 billion guesses per second
local function crackTime(bits)
  if bits <= 0 then return TR("instant") end
  local secs = (2 ^ bits) / 2 / 1e10
  if secs < 1 then return TR("instant") end
  if secs < 60 then return TR("t_seconds", floor(secs)) end
  if secs < 3600 then return TR("t_minutes", floor(secs / 60)) end
  if secs < 86400 then return TR("t_hours", floor(secs / 3600)) end
  if secs < 86400 * 365 then return TR("t_days", floor(secs / 86400)) end
  local years = secs / (86400 * 365)
  if years < 1000 then return TR("t_years", floor(years)) end
  if years < 1e6 then return TR("t_millennia") end
  return TR("t_forever")
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  local saved = store.get("cfg", nil)
  if type(saved) == "table" then
    for k, v in pairs(saved) do
      if cfg[k] ~= nil and type(v) == type(cfg[k]) then cfg[k] = v end
    end
  else
    cfg.wlang = sys.lang() == "tr" and 1 or 2
  end
  cfg.length = max(4, min(64, floor(cfg.length)))
  cfg.words = max(3, min(10, floor(cfg.words)))
  cfg.mode = (cfg.mode == 2) and 2 or 1
  cfg.wlang = (cfg.wlang == 2) and 2 or 1
  cfg.sep = max(1, min(#SEPARATORS, floor(cfg.sep)))
  local h = store.get("history", {})
  history = {}
  if type(h) == "table" then
    for _, e in ipairs(h) do
      if type(e) == "table" and type(e.pw) == "string" then history[#history + 1] = e end
      if #history >= 10 then break end
    end
  end
  generate()
end

function app.update(dt)
  shownStrength = approach(shownStrength, currentBits, 10, dt)
end

-- ------------------------------------------------------------------ drawing
local function classColor(ch)
  if ch:match("%d") then return theme.blue end
  if ch:match("[%a]") or #ch > 1 then return theme.text end
  if ch == " " then return theme.text end
  return theme.orange
end

local scramblePool = SETS.upper .. SETS.lower .. SETS.digits

local function drawPassword(x, y, w, h)
  local n = #currentChars
  if n == 0 then
    gfx.color(theme.text3)
    gfx.text(TR("no_sets"), x, y + h / 2 - 10, 15, "medium", "center", w)
    return
  end
  local font = "mono"
  -- pick a size that fits on one or two lines
  local size = 30
  local cw = gfx.textWidth("M", size, font)
  local lines = 1
  while cw * n > w and size > 18 do
    size = size - 1
    cw = gfx.textWidth("M", size, font)
  end
  local perLine = n
  if cw * n > w then
    lines = 2
    perLine = math.ceil(n / 2)
    size = 26
    cw = gfx.textWidth("M", size, font)
    while cw * perLine > w and size > 11 do
      size = size - 1
      cw = gfx.textWidth("M", size, font)
    end
    if cw * perLine > w then
      lines = 3
      perLine = math.ceil(n / 3)
    end
  end
  local lh = gfx.textHeight(size, font)
  local totalH = lh * lines
  local y0 = y + (h - totalH) / 2
  local age = sys.time() - genTime
  for li = 0, lines - 1 do
    local first = li * perLine + 1
    local last = min(n, first + perLine - 1)
    local count = last - first + 1
    local x0 = x + (w - count * cw) / 2
    for i = first, last do
      local ch = currentChars[i]
      local settle = 0.04 + (i - 1) * 0.008
      local px = x0 + (i - first) * cw
      if age < settle then
        local k = rnd(#scramblePool)
        gfx.color(theme.text3)
        gfx.text(scramblePool:sub(k, k), px, y0 + li * lh, size, font)
      else
        local pop = max(0, 1 - (age - settle) / 0.15)
        gfx.color(classColor(ch))
        gfx.text(ch, px, y0 + li * lh - pop * 3, size, font)
      end
    end
  end
end

local function drawCard(x, y, w)
  local h = 138
  gfx.shadow(x, y, w, h, 12, 14, 3)
  gfx.rect(x, y, w, h, 12, theme.dark and "#2A2A2D" or "#FFFFFF")
  gfx.color(theme.separator)
  gfx.rectLine(x, y, w, h, 12, 1)
  -- copied flash
  local fl = 1 - (sys.time() - copiedFlash) / 0.6
  if fl > 0 then
    gfx.rect(x, y, w, h, 12, fade(theme.green, 0.18 * fl))
  end
  local btnW = 44
  drawPassword(x + 16, y + 8, w - 32 - btnW * 2 - 16, 82)
  -- buttons
  local bx = x + w - 16 - btnW * 2 - 8
  local by = y + 26
  if ui.iconButton("refresh", bx, by, btnW, 40, theme.text2, false, "gen") then
    generate()
    audio.tone(880, 0.05, 0.25, "triangle")
  end
  if ui.iconButton("content_copy", bx + btnW + 8, by, btnW, 40, theme.accent, false, "copy") then
    copyCurrent()
  end
  -- strength meter
  local idx, s = strengthOf(currentBits)
  local col = theme[s[3]]
  local my = y + 98
  local segW = (w - 32 - 4 * 6) / 5
  local fillTo = 0
  for i, st in ipairs(STRENGTH) do
    local lo = i == 1 and 0 or STRENGTH[i - 1][1]
    local hi = i == #STRENGTH and 128 or st[1]
    local f = (shownStrength - lo) / (hi - lo)
    f = max(0, min(1, f))
    local sx = x + 16 + (i - 1) * (segW + 6)
    gfx.rect(sx, my, segW, 6, 3, theme.dark and "#FFFFFF1A" or "#0000000F")
    if f > 0 then gfx.rect(sx, my, max(6, segW * f), 6, 3, col) end
    if f >= 1 then fillTo = i end
  end
  if s[3] == "yellow" and not theme.dark then
    local a = rgba(col)
    gfx.color(floor(a[1] * 0.75), floor(a[2] * 0.75), floor(a[3] * 0.75), 255)
  else
    gfx.color(col)
  end
  local lw = gfx.text(TR(s[2]), x + 16, my + 14, 13, "semibold")
  gfx.color(theme.text2)
  gfx.text("  ·  " .. TR("bits", floor(currentBits + 0.5)), x + 16 + lw, my + 14, 13)
  gfx.color(theme.text2)
  gfx.text(TR("crack_time", crackTime(currentBits)), x, my + 14, 12.5, "sans", "right", w - 16)
  return h
end

local function toggleRow(label, hint, key, x, y, w)
  gfx.color(theme.text)
  local tw = gfx.text(label, x, y + 12, 14)
  if hint then
    gfx.color(theme.text3)
    gfx.text(hint, x + tw + 8, y + 13, 12.5, "mono")
  end
  local nv = ui.toggle("t_" .. key, cfg[key], x + w - 40, y + 9)
  if nv ~= cfg[key] then
    cfg[key] = nv
    saveCfg()
    generate()
    audio.play("click")
  end
end

local function drawPasswordOptions(x, y, w)
  local rh = 44
  ui.group(x, y, w, rh * 4)
  local ix, iw = x + 16, w - 32
  -- length
  gfx.color(theme.text)
  gfx.text(TR("length"), ix, y + 13, 14)
  local sx = ix + 110
  local nv = ui.slider("len", cfg.length, 4, 64, sx, y + 10, iw - 110 - 50, 1)
  nv = floor(nv + 0.5)
  if nv ~= cfg.length then
    cfg.length = nv
    saveCfg()
    generate()
    audio.tone(500 + nv * 12, 0.02, 0.12, "sine")
  end
  gfx.color(theme.accent)
  gfx.text(tostring(cfg.length), ix + iw - 40, y + 12, 15, "semibold", "right", 40)
  ui.separator(ix, y + rh, x + w - 16)
  local half = (iw - 24) / 2
  toggleRow(TR("uppercase"), "A-Z", "upper", ix, y + rh, half)
  toggleRow(TR("lowercase"), "a-z", "lower", ix + half + 24, y + rh, half)
  ui.separator(ix, y + rh * 2, x + w - 16)
  toggleRow(TR("digits"), "0-9", "digits", ix, y + rh * 2, half)
  toggleRow(TR("symbols"), "!@#", "symbols", ix + half + 24, y + rh * 2, half)
  ui.separator(ix, y + rh * 3, x + w - 16)
  toggleRow(TR("avoid_ambiguous"), "I l 1 O 0", "avoid", ix, y + rh * 3, iw)
  return rh * 4
end

local function drawPhraseOptions(x, y, w)
  local rh = 44
  ui.group(x, y, w, rh * 4)
  local ix, iw = x + 16, w - 32
  gfx.color(theme.text)
  gfx.text(TR("word_count"), ix, y + 13, 14)
  local sx = ix + 110
  local nv = ui.slider("words", cfg.words, 3, 10, sx, y + 10, iw - 110 - 50, 1)
  nv = floor(nv + 0.5)
  if nv ~= cfg.words then
    cfg.words = nv
    saveCfg()
    generate()
    audio.tone(500 + nv * 40, 0.02, 0.12, "sine")
  end
  gfx.color(theme.accent)
  gfx.text(tostring(cfg.words), ix + iw - 40, y + 12, 15, "semibold", "right", 40)
  ui.separator(ix, y + rh, x + w - 16)
  local half = (iw - 24) / 2
  -- language
  gfx.color(theme.text)
  gfx.text(TR("language"), ix, y + rh + 12, 14)
  local nl = ui.segmented("wlang", {TR("lang_tr"), TR("lang_en")}, cfg.wlang, ix + half - 150, y + rh + 8, 150, 28)
  if nl ~= cfg.wlang then
    cfg.wlang = nl
    saveCfg()
    generate()
    audio.play("click")
  end
  -- separator
  local rx = ix + half + 24
  gfx.color(theme.text)
  gfx.text(TR("separator"), rx, y + rh + 12, 14)
  local sepNames = {"-", ".", "_", TR("sep_space"), TR("sep_none")}
  local ns = ui.dropdown("sep", sepNames, cfg.sep, rx + half - 110, y + rh + 8, 110, 28)
  if ns ~= cfg.sep then
    cfg.sep = ns
    saveCfg()
    generate()
  end
  ui.separator(ix, y + rh * 2, x + w - 16)
  toggleRow(TR("capitalize"), nil, "cap", ix, y + rh * 2, half)
  toggleRow(TR("add_number"), "0-9", "num", rx, y + rh * 2, half)
  ui.separator(ix, y + rh * 3, x + w - 16)
  toggleRow(TR("ascii_only"), "ç → c", "ascii", ix, y + rh * 3, iw)
  return rh * 4
end

local function fmtDate(epoch)
  local d = sys.date(epoch)
  return string.format("%02d.%02d.%04d  %02d:%02d", d.day, d.month, d.year, d.hour, d.min)
end

local function drawHistory(x, y, w, h)
  gfx.color(theme.text)
  gfx.text(TR("history"), x, y, 15, "semibold")
  gfx.color(theme.text3)
  gfx.text(TR("history_hint"), x + gfx.textWidth(TR("history"), 15, "semibold") + 10, y + 2, 12.5)
  if #history > 0 then
    if ui.button(TR("clear") .. "##hist", x + w - 70, y - 4, 70, 26, "link") then
      ui.alert(TR("clear_title"), TR("clear_msg"), {TR("clear"), TR("cancel")}, function(b)
        if b == 1 then
          history = {}
          revealed = {}
          saveHistory()
          audio.play("trash")
        end
      end)
    end
  end
  local ly = y + 26
  local lh = h - 26
  if #history == 0 then
    ui.group(x, ly, w, lh)
    gfx.icon("history", x + w / 2, ly + lh / 2 - 14, 30, theme.text3)
    gfx.color(theme.text3)
    gfx.text(TR("history_empty"), x, ly + lh / 2 + 8, 13, "sans", "center", w)
    return
  end
  ui.group(x, ly, w, lh)
  local rowH = 40
  local contentH = #history * rowH
  ui.beginScroll("histscroll", x, ly, w, lh, contentH)
  for i, e in ipairs(history) do
    local ry = (i - 1) * rowH
    if i > 1 then ui.separator(16, ry, w - 16) end
    local shown = revealed[i]
    local txt
    if shown then
      txt = e.pw
    else
      txt = string.rep("•", min(24, utf8.len(e.pw) or #e.pw))
    end
    gfx.clip(16, ry, w - 200, rowH)
    gfx.color(shown and theme.text or theme.text2)
    gfx.text(txt, 16, ry + 11, 14, "mono")
    gfx.unclip()
    gfx.color(theme.text3)
    gfx.text(fmtDate(e.t or 0), w - 190, ry + 13, 11.5, "sans", "right", 96)
    if ui.iconButton(shown and "visibility_off" or "visibility", w - 88, ry + 5, 32, 30, theme.text2, false, "eye" .. i) then
      revealed[i] = not shown
      audio.play("click")
    end
    if ui.iconButton("content_copy", w - 50, ry + 5, 32, 30, theme.accent, false, "hc" .. i) then
      sys.clipboard(e.pw)
      audio.play("pop")
      showToast(TR("copied"))
    end
  end
  ui.endScroll()
end

local function drawToast(w, h)
  local age = sys.time() - toastT
  if age > 1.6 then return end
  local a = min(1, age / 0.12) * min(1, (1.6 - age) / 0.3)
  local tw = gfx.textWidth(toast, 13, "medium") + 44
  local tx, ty = (w - tw) / 2, h - 52 + (1 - min(1, age / 0.15)) * 10
  gfx.alpha(a)
  gfx.shadow(tx, ty, tw, 32, 16, 12, 3)
  gfx.rect(tx, ty, tw, 32, 16, theme.dark and "#3A3A3C" or "#323236")
  gfx.icon("check_circle", tx + 18, ty + 16, 16, theme.green)
  gfx.color("#FFFFFF")
  gfx.text(toast, tx + 32, ty + 8, 13, "medium")
  gfx.unalpha()
end

function app.draw(w, h)
  gfx.clear(theme.bg)
  local m = 20
  local nm = ui.segmented("mode", {TR("mode_password"), TR("mode_phrase")}, cfg.mode, w / 2 - 150, 14, 300, 30)
  if nm ~= cfg.mode then
    cfg.mode = nm
    saveCfg()
    generate()
    audio.play("click")
  end
  local y = 60
  y = y + drawCard(m, y, w - m * 2) + 16
  if cfg.mode == 1 then
    y = y + drawPasswordOptions(m, y, w - m * 2) + 18
  else
    y = y + drawPhraseOptions(m, y, w - m * 2) + 18
  end
  drawHistory(m, y, w - m * 2, h - y - 16)
  drawToast(w, h)
end

function app.event(e)
  if e.type == "keydown" then
    if e.ctrl and e.key == "c" then
      copyCurrent()
    elseif e.key == "space" or e.key == "enter" or e.key == "r" or e.key == "g" then
      generate()
      audio.tone(880, 0.05, 0.25, "triangle")
    elseif e.key == "c" then
      copyCurrent()
    elseif e.key == "tab" then
      cfg.mode = cfg.mode == 1 and 2 or 1
      saveCfg()
      generate()
    elseif e.key == "left" or e.key == "right" then
      local d = e.key == "left" and -1 or 1
      if cfg.mode == 1 then
        cfg.length = max(4, min(64, cfg.length + d))
      else
        cfg.words = max(3, min(10, cfg.words + d))
      end
      saveCfg()
      generate()
    end
  end
end

function app.menu()
  return {{title = TR("menu_title"), items = {
    {label = TR("generate"), id = 1, shortcut = "Space"},
    {label = TR("copy"), id = 2, shortcut = "Ctrl+C"},
    "-",
    {label = TR("mode_password"), id = 3, checked = cfg.mode == 1},
    {label = TR("mode_phrase"), id = 4, checked = cfg.mode == 2},
    "-",
    {label = TR("clear_history"), id = 5, enabled = #history > 0},
  }}}
end

function app.onmenu(id)
  if id == 1 then generate()
  elseif id == 2 then copyCurrent()
  elseif id == 3 or id == 4 then
    cfg.mode = id - 2
    saveCfg()
    generate()
  elseif id == 5 then
    history = {}
    revealed = {}
    saveHistory()
  end
end

function app.close()
  store.save()
  return true
end

return app
