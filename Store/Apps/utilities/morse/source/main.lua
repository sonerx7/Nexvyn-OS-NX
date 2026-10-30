-- Morse Code for Nexvyn OS: two-way translator with audio and light playback, a key practice pad and a chart.
local app = {}

local floor, min, max, abs, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.pi

-- ------------------------------------------------------------------ helpers
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

local fieldRects, nFields, editing = {}, 0, false
local function field(id, text, x, y, w, h, ph, flags)
  nFields = nFields + 1
  local r = fieldRects[nFields]
  if not r then r = {}; fieldRects[nFields] = r end
  r[1], r[2], r[3], r[4] = x, y, w, h
  return ui.textfield(id, text, x, y, w, h, ph, flags)
end
local function pointInField(x, y)
  for i = 1, nFields do
    local r = fieldRects[i]
    if x >= r[1] and y >= r[2] and x <= r[1] + r[3] and y <= r[2] + r[4] then return true end
  end
  return false
end

-- ------------------------------------------------------------------ Morse tables
-- "I" is the international I (Turkish dotted İ/i); "ı" is the Turkish dotless I.
local CODE = {
  A = ".-", B = "-...", C = "-.-.", D = "-..", E = ".", F = "..-.", G = "--.", H = "....", I = "..", J = ".---",
  K = "-.-", L = ".-..", M = "--", N = "-.", O = "---", P = ".--.", Q = "--.-", R = ".-.", S = "...", T = "-",
  U = "..-", V = "...-", W = ".--", X = "-..-", Y = "-.--", Z = "--..",
  ["0"] = "-----", ["1"] = ".----", ["2"] = "..---", ["3"] = "...--", ["4"] = "....-",
  ["5"] = ".....", ["6"] = "-....", ["7"] = "--...", ["8"] = "---..", ["9"] = "----.",
  ["."] = ".-.-.-", [","] = "--..--", ["?"] = "..--..", ["'"] = ".----.", ["!"] = "-.-.--", ["/"] = "-..-.",
  ["("] = "-.--.", [")"] = "-.--.-", ["&"] = ".-...", [":"] = "---...", [";"] = "-.-.-.", ["="] = "-...-",
  ["+"] = ".-.-.", ["-"] = "-....-", ["_"] = "..--.-", ['"'] = ".-..-.", ["$"] = "...-..-", ["@"] = ".--.-.",
  ["Ç"] = "-.-..", ["Ğ"] = "--.-.", ["ı"] = ".-..-", ["Ö"] = "---.", ["Ş"] = ".--..", ["Ü"] = "..--",
}
local DECODE = {}
for ch, code in pairs(CODE) do DECODE[code] = ch end

local isTR = false
local LOWER_MAP = {["ç"] = "Ç", ["ğ"] = "Ğ", ["ı"] = "ı", ["i"] = "I", ["İ"] = "I", ["ö"] = "Ö", ["ş"] = "Ş", ["ü"] = "Ü",
                   ["Ç"] = "Ç", ["Ğ"] = "Ğ", ["Ö"] = "Ö", ["Ş"] = "Ş", ["Ü"] = "Ü"}

local function keyOf(ch)
  if ch == "I" then return isTR and "ı" or "I" end
  local m = LOWER_MAP[ch]
  if m then return m end
  if #ch == 1 then return ch:upper() end
  return ch
end

-- what to show for a table key
local function displayOf(key)
  if key == "ı" then return isTR and "I" or "ı" end
  if key == "I" then return isTR and "İ" or "I" end
  return key
end

-- ------------------------------------------------------------------ settings & state
local cfg = {wpm = 15, freq = 650, dir = 1, tab = 1, text = "SOS", morse = "... --- ..."}
local tokens = {}            -- {disp=, code=, space=bool, bad=bool}
local outText = ""
local lastSrc = nil

local P = {playing = false, els = {}, nextEl = 1, t0 = 0, dur = 0, chan = nil, cur = 0, on = false}
local lamp = 0

local K = {down = false, src = nil, t0 = 0, lastUp = 0, code = "", text = "", chan = nil, wordPending = false,
           segs = {}, dots = {}, target = nil, drill = false, hint = true, flash = 0, flashGood = true}
local DRILL_WORDS_EN = {"SOS", "HELLO", "CQ", "TEST", "MORSE", "RADIO", "HI", "73", "OK", "NAME"}
local DRILL_WORDS_TR = {"SOS", "MERHABA", "EVET", "HAYIR", "SU", "GÜN", "ŞEHİR", "ÇAY", "DOĞRU", "ÖĞLE"}

local function saveCfg() store.set("cfg", cfg) end

-- ------------------------------------------------------------------ translation
local function textToTokens(s)
  local out = {}
  local codes = {}
  local word = {}
  local function flushWord()
    if #word > 0 then
      codes[#codes + 1] = table.concat(word, " ")
      word = {}
    end
  end
  for _, c in utf8.codes(s) do
    local ch = utf8.char(c)
    if ch == " " or ch == "\t" or ch == "\n" then
      if #out > 0 and not out[#out].space then out[#out + 1] = {space = true} end
      flushWord()
    else
      local key = keyOf(ch)
      local code = CODE[key]
      if code then
        out[#out + 1] = {disp = displayOf(key), code = code}
        word[#word + 1] = code
      else
        out[#out + 1] = {disp = ch, code = nil, bad = true}
      end
    end
  end
  flushWord()
  return out, table.concat(codes, " / ")
end

local function normalizeMorse(s)
  s = s:gsub("•", "."):gsub("·", "."):gsub("–", "-"):gsub("—", "-"):gsub("−", "-"):gsub("_", "-")
  return s
end

local function morseToTokens(s)
  s = normalizeMorse(s)
  local out = {}
  local text = {}
  -- words: "/" or "|" or 3+ spaces
  s = s:gsub("%s*[/|]%s*", "   ")
  local first = true
  for wordStr in (s .. "   "):gmatch("(.-)%s%s%s+") do
    local w = wordStr:gsub("^%s+", "")
    if w ~= "" then
      if not first then
        out[#out + 1] = {space = true}
        text[#text + 1] = " "
      end
      first = false
      for code in w:gmatch("%S+") do
        local key = DECODE[code]
        if key then
          local d = displayOf(key)
          out[#out + 1] = {disp = d, code = code}
          text[#text + 1] = d
        else
          out[#out + 1] = {disp = "?", code = code, bad = true}
          text[#text + 1] = "?"
        end
      end
    end
  end
  return out, table.concat(text)
end

local function retranslate()
  local src = cfg.dir == 1 and cfg.text or cfg.morse
  local key = cfg.dir .. "|" .. src .. "|" .. tostring(isTR)
  if key == lastSrc then return end
  lastSrc = key
  if cfg.dir == 1 then tokens, outText = textToTokens(cfg.text)
  else tokens, outText = morseToTokens(cfg.morse) end
end

-- ------------------------------------------------------------------ playback
local function unit() return 1.2 / cfg.wpm end

local function stopPlayback()
  if P.chan then audio.stop(P.chan) end
  P.playing, P.chan, P.on, P.cur = false, nil, false, 0
end

local function playTokens(list)
  stopPlayback()
  local u = unit()
  local t = 0
  local els = {}
  for ti, tok in ipairs(list) do
    if tok.space then
      t = t + 4 * u           -- a word gap is 7 units: 3 already follow every letter
    elseif tok.code then
      for k = 1, #tok.code do
        local d = tok.code:sub(k, k) == "-" and 3 * u or u
        els[#els + 1] = {t = t, d = d, tok = ti}
        t = t + d + u
      end
      t = t + 2 * u
    end
  end
  if #els == 0 then
    audio.play("error")
    return
  end
  P.els, P.nextEl, P.t0, P.dur, P.playing, P.list = els, 1, sys.time() + 0.05, t, true, list
end

local function togglePlay()
  if P.playing then stopPlayback() else retranslate(); playTokens(tokens) end
end

local function updatePlayback()
  if not P.playing then return end
  local now = sys.time() - P.t0
  while P.nextEl <= #P.els and P.els[P.nextEl].t <= now do
    local e = P.els[P.nextEl]
    P.chan = audio.tone(cfg.freq, e.d, 0.4, "sine")
    P.cur = e.tok
    P.nextEl = P.nextEl + 1
  end
  local on = false
  local i = P.nextEl - 1
  if i >= 1 then
    local e = P.els[i]
    on = now >= e.t and now < e.t + e.d
  end
  P.on = on
  if now > P.dur then stopPlayback() end
end

-- ------------------------------------------------------------------ practice key
local function newTarget()
  local list = isTR and DRILL_WORDS_TR or DRILL_WORDS_EN
  if math.random() < 0.5 then
    local letters = "ABCDEFGHIJKLMNOPRSTUVYZ"
    local i = math.random(#letters)
    K.target = letters:sub(i, i)
  else
    K.target = list[math.random(#list)]
  end
end

local function keyDown(src)
  if K.down then return end
  K.down, K.src, K.t0 = true, src, sys.time()
  if K.chan then audio.stop(K.chan) end
  K.chan = audio.tone(cfg.freq, 6, 0.35, "sine")
  K.segs[#K.segs + 1] = {s = K.t0, e = nil}
end

local function decodeLetter(code)
  local key = DECODE[code]
  return key and displayOf(key) or "?"
end

local function checkDrill()
  if not K.drill or not K.target then return end
  local t = K.text:gsub("%s+$", "")
  if #t >= #K.target and t:sub(-#K.target) == K.target then
    K.flash, K.flashGood = 1, true
    audio.tone(880, 0.08, 0.25, "triangle")
    timer.after(0.08, function() audio.tone(1320, 0.12, 0.22, "triangle") end)
    K.text = ""
    newTarget()
  elseif (utf8.len(t) or 0) >= (utf8.len(K.target) or 0) + 3 then
    -- too many letters without a match: show the miss and start over
    K.flash, K.flashGood = 1, false
    audio.tone(260, 0.12, 0.22, "triangle")
    K.text = ""
  end
end

local function keyUp(src)
  if not K.down or (src and K.src ~= src) then return end
  local now = sys.time()
  local d = now - K.t0
  K.down = false
  if K.chan then audio.stop(K.chan); K.chan = nil end
  local seg = K.segs[#K.segs]
  if seg then seg.e = now end
  local u = unit()
  local sym = d < 2 * u and "." or "-"
  if sym == "." then
    K.dots[#K.dots + 1] = d
    if #K.dots > 12 then table.remove(K.dots, 1) end
  end
  if #K.code < 8 then K.code = K.code .. sym end
  K.lastUp = now
end

local function updateKey()
  local now = sys.time()
  local u = unit()
  if not K.down then
    if K.code ~= "" and now - K.lastUp > 2.5 * u then
      K.text = K.text .. decodeLetter(K.code)
      K.code = ""
      K.wordPending = true
      checkDrill()
    elseif K.wordPending and now - K.lastUp > 6 * u then
      if K.text ~= "" then K.text = K.text .. " " end
      K.wordPending = false
    end
  end
  -- keep the timeline short
  while #K.segs > 0 and K.segs[1].e and now - K.segs[1].e > 8 do table.remove(K.segs, 1) end
  if utf8.len(K.text) and utf8.len(K.text) > 120 then K.text = K.text:sub(utf8.offset(K.text, -100)) end
end

local function estimatedWPM()
  if #K.dots < 3 then return nil end
  local s = 0
  for _, d in ipairs(K.dots) do s = s + d end
  local avg = s / #K.dots
  return floor(1.2 / avg + 0.5)
end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  isTR = sys.lang() == "tr"
  local saved = store.get("cfg", nil)
  if type(saved) == "table" then
    for k, v in pairs(saved) do
      if cfg[k] ~= nil and type(v) == type(cfg[k]) then cfg[k] = v end
    end
  else
    cfg.text = isTR and "MERHABA DÜNYA" or "HELLO WORLD"
  end
  cfg.wpm = max(5, min(40, floor(cfg.wpm)))
  cfg.freq = max(400, min(1000, floor(cfg.freq)))
  if cfg.dir ~= 2 then cfg.dir = 1 end
  if cfg.tab < 1 or cfg.tab > 3 then cfg.tab = 1 end
  retranslate()
  newTarget()
end

function app.update(dt)
  updatePlayback()
  updateKey()
  local on = P.on or K.down
  lamp = approach(lamp, on and 1 or 0, on and 40 or 14, dt)
  K.flash = max(0, K.flash - dt * 1.5)
end

-- ------------------------------------------------------------------ drawing: shared
local function drawLamp(cx, cy, r)
  local glow = lamp
  local warm = theme.yellow
  for i = 3, 1, -1 do
    gfx.circle(cx, cy, r + i * 9 * glow, fade(warm, 0.10 * glow))
  end
  gfx.circle(cx, cy, r, theme.dark and "#3A3A3C" or "#E5E5EA")
  if glow > 0.01 then gfx.circle(cx, cy, r, fade(warm, glow)) end
  gfx.circle(cx - r * 0.3, cy - r * 0.3, r * 0.28, {255, 255, 255, floor(60 + 120 * glow)})
end

local function sliderRow(label, value, unitLabel, id, lo, hi, step, x, y, w)
  gfx.color(theme.text2)
  gfx.text(label, x, y + 4, 12.5, "medium")
  local nv = ui.slider(id, value, lo, hi, x + 70, y, w - 70 - 70, step)
  nv = floor(nv / step + 0.5) * step
  gfx.color(theme.text)
  gfx.text(tostring(nv) .. " " .. unitLabel, x + w - 64, y + 3, 13, "semibold", "right", 64)
  return nv
end

-- ------------------------------------------------------------------ translate tab
local function drawTokens(x, y, w, h)
  local chipW, chipH, gapX, gapY = 0, 54, 6, 10
  local cx, cy = 0, 0
  -- measure total height first
  local layout = {}
  for i, tok in ipairs(tokens) do
    if tok.space then
      cx = cx + 18
    else
      local cw = max(34, gfx.textWidth(tok.code or "", 13, "monobold") + 14, gfx.textWidth(tok.disp, 20, "bold") + 14)
      if cx + cw > w and cx > 0 then cx = 0; cy = cy + chipH + gapY end
      layout[i] = {cx, cy, cw}
      cx = cx + cw + gapX
    end
  end
  local contentH = cy + chipH + 4
  ui.beginScroll("tokens", x, y, w, h, contentH)
  for i, tok in ipairs(tokens) do
    local l = layout[i]
    if l then
      local active = P.playing and P.list == tokens and P.cur == i
      local bx, by, bw = l[1], l[2], l[3]
      local bg
      if active then bg = fade(theme.yellow, 0.25 + 0.55 * lamp)
      elseif tok.bad then bg = fade(theme.red, 0.12)
      else bg = theme.dark and "#FFFFFF0D" or "#0000000A" end
      gfx.rect(bx, by, bw, chipH, 9, bg)
      if active then
        gfx.color(theme.yellow)
        gfx.rectLine(bx, by, bw, chipH, 9, 2)
      end
      gfx.color(tok.bad and theme.red or theme.text)
      gfx.text(tok.disp, bx, by + 5, 20, "bold", "center", bw)
      gfx.color(tok.bad and theme.red or (active and theme.text or theme.accent))
      gfx.text(tok.code or "", bx, by + 32, 13, "monobold", "center", bw)
      local hh = ui.hit("tok" .. i, bx, by, bw, chipH)
      if hh.clicked and tok.code then playTokens({tok}) end
    end
  end
  ui.endScroll()
end

local function drawTranslate(w, h)
  local x0 = 20
  local y = 62
  local nd = ui.segmented("dir", {TR("dir_text"), TR("dir_morse")}, cfg.dir, x0, y, 300, 30)
  if nd ~= cfg.dir then
    stopPlayback()
    -- carry the current result over so switching direction keeps working on the same message
    if nd == 2 then cfg.morse = (select(2, textToTokens(cfg.text))) else cfg.text = (select(2, morseToTokens(cfg.morse))) end
    cfg.dir = nd
    saveCfg()
    retranslate()
    audio.play("click")
  end
  if ui.iconButton("swap_horiz", x0 + 306, y, 36, 30, theme.text2, false, "swap") then
    stopPlayback()
    if cfg.dir == 1 then cfg.morse = outText; cfg.dir = 2 else cfg.text = outText; cfg.dir = 1 end
    saveCfg()
    retranslate()
    audio.play("click")
  end
  drawLamp(w - 50, y + 16, 16)
  y = y + 44
  if cfg.dir == 1 then
    local nt = field("text", cfg.text, x0, y, w - 40, 36, TR("text_ph"))
    if nt ~= cfg.text then cfg.text = nt; saveCfg(); retranslate() end
  else
    local nm = field("morse", cfg.morse, x0, y, w - 40, 36, TR("morse_ph"))
    if nm ~= cfg.morse then cfg.morse = nm; saveCfg(); retranslate() end
    if ui.button(".##dot", x0, y + 42, 56, 30) then cfg.morse = cfg.morse .. "."; saveCfg(); retranslate() end
    if ui.button("-##dash", x0 + 62, y + 42, 56, 30) then cfg.morse = cfg.morse .. "-"; saveCfg(); retranslate() end
    if ui.button(TR("letter_gap") .. "##gap", x0 + 124, y + 42, 110, 30) then cfg.morse = cfg.morse .. " "; saveCfg(); retranslate() end
    if ui.button(TR("word_gap") .. "##wgap", x0 + 240, y + 42, 110, 30) then cfg.morse = cfg.morse .. " / "; saveCfg(); retranslate() end
    if ui.iconButton("backspace", x0 + 356, y + 42, 40, 30, theme.text2, false, "bs") then
      local n = utf8.len(cfg.morse) or 0
      if n > 0 then cfg.morse = cfg.morse:sub(1, (utf8.offset(cfg.morse, n) or 1) - 1) end
      saveCfg()
      retranslate()
    end
    y = y + 36
  end
  y = y + 50
  -- result card
  local cardH = h - y - 120
  gfx.rect(x0, y, w - 40, cardH, 12, theme.dark and "#FFFFFF0A" or "#00000008")
  gfx.color(lamp > 0.05 and fade(theme.yellow, 0.5 * lamp) or theme.separator)
  gfx.rectLine(x0, y, w - 40, cardH, 12, 1 + lamp)
  gfx.color(theme.text2)
  gfx.text(cfg.dir == 1 and TR("result_morse") or TR("result_text"), x0 + 14, y + 12, 12, "semibold")
  if ui.button(TR("copy") .. "##copy", w - 40 - 104, y + 6, 104, 26, "plain", "content_copy") then
    sys.clipboard(outText)
    audio.play("pop")
  end
  gfx.clip(x0 + 14, y + 34, w - 68, 22)
  gfx.color(theme.text)
  gfx.text(outText ~= "" and outText or "—", x0 + 14, y + 36, 14, cfg.dir == 1 and "mono" or "semibold")
  gfx.unclip()
  if #tokens > 0 then
    drawTokens(x0 + 12, y + 66, w - 64, cardH - 76)
  else
    gfx.color(theme.text3)
    gfx.text(TR("nothing"), x0, y + cardH / 2, 13, "sans", "center", w - 40)
  end
  -- controls
  local cy = h - 100
  local playing = P.playing
  local hh = ui.hit("playbtn", x0, cy + 6, 64, 64)
  gfx.circle(x0 + 32, cy + 38, 30, playing and theme.red or theme.accent)
  if hh.hovered then gfx.circle(x0 + 32, cy + 38, 30, {255, 255, 255, 30}) end
  gfx.icon(playing and "stop" or "play_arrow", x0 + 32, cy + 38, 32, "#FFFFFF")
  if hh.clicked then togglePlay() end
  local sx = x0 + 84
  local sw = w - sx - 20
  local nw = sliderRow(TR("speed"), cfg.wpm, TR("wpm"), "wpm", 5, 40, 1, sx, cy + 8, sw)
  if nw ~= cfg.wpm then cfg.wpm = nw; saveCfg() end
  local nf = sliderRow(TR("tone"), cfg.freq, "Hz", "freq", 400, 1000, 10, sx, cy + 44, sw)
  if nf ~= cfg.freq then cfg.freq = nf; saveCfg() end
end

-- ------------------------------------------------------------------ practice tab
local function drawPractice(w, h)
  local x0, y0 = 20, 62
  local padW, padH = 300, 250
  -- key pad
  local hit = ui.hit("keypad", x0, y0, padW, padH)
  if hit.pressed then keyDown("pad") end
  if K.down and K.src == "pad" and not hit.held then keyUp("pad") end
  local pressed = K.down
  local inset = pressed and 4 or 0
  gfx.shadow(x0 + inset, y0 + inset, padW - inset * 2, padH - inset * 2, 22, pressed and 8 or 20, pressed and 2 or 6)
  gfx.gradient(x0 + inset, y0 + inset, padW - inset * 2, padH - inset * 2,
    pressed and theme.accent or (theme.dark and "#3A3A3C" or "#FFFFFF"),
    pressed and theme.blue or (theme.dark and "#2C2C2E" or "#F0F0F3"), false, 22)
  gfx.color(theme.separator)
  gfx.rectLine(x0 + inset, y0 + inset, padW - inset * 2, padH - inset * 2, 22, 1)
  gfx.icon("touch_app", x0 + padW / 2, y0 + padH / 2 - 22, 46, pressed and "#FFFFFF" or theme.accent)
  gfx.color(pressed and "#FFFFFF" or theme.text2)
  gfx.text(TR("hold_to_key"), x0, y0 + padH / 2 + 18, 14, "semibold", "center", padW)
  gfx.color(pressed and "#FFFFFFB0" or theme.text3)
  gfx.text(TR("key_hint"), x0, y0 + padH / 2 + 40, 12, "sans", "center", padW)
  -- right panel
  local rx = x0 + padW + 20
  local rw = w - rx - 20
  drawLamp(rx + rw - 24, y0 + 22, 14)
  gfx.color(theme.text2)
  gfx.text(TR("keying"), rx, y0 + 4, 12, "semibold")
  gfx.color(theme.accent)
  local codeShown = K.code ~= "" and K.code or " "
  gfx.text(codeShown, rx, y0 + 22, 34, "monobold")
  if K.code ~= "" then
    gfx.color(theme.text3)
    gfx.text("→ " .. decodeLetter(K.code), rx + gfx.textWidth(codeShown, 34, "monobold") + 12, y0 + 32, 18, "semibold")
  end
  -- decoded text
  local ty = y0 + 78
  gfx.color(theme.text2)
  gfx.text(TR("decoded"), rx, ty, 12, "semibold")
  local boxH = 84
  local fl = K.flash
  local border = fl > 0 and fade(K.flashGood and theme.green or theme.red, fl) or theme.separator
  gfx.rect(rx, ty + 18, rw, boxH, 10, theme.dark and "#FFFFFF0A" or "#00000008")
  gfx.color(border)
  gfx.rectLine(rx, ty + 18, rw, boxH, 10, 1 + fl * 2)
  gfx.color(theme.text)
  gfx.clip(rx + 10, ty + 24, rw - 20, boxH - 12)
  if K.text == "" then
    gfx.color(theme.text3)
    gfx.text(TR("decoded_empty"), rx + 12, ty + 30, 14)
  else
    gfx.wrap(K.text, rx + 12, ty + 28, rw - 24, 20, "semibold")
  end
  gfx.unclip()
  local by = ty + 18 + boxH + 10
  if ui.button(TR("clear") .. "##pr", rx, by, 90, 30, "default", "delete_sweep") then
    K.text, K.code, K.wordPending = "", "", false
    audio.play("click")
  end
  if ui.button(TR("space") .. "##sp", rx + 96, by, 90, 30) then K.text = K.text .. " "; K.wordPending = false end
  local est = estimatedWPM()
  gfx.icon("speed", rx + 8, by + 46, 16, theme.text3)
  gfx.color(theme.text3)
  gfx.text(est and TR("your_speed", est) or TR("speed_unknown"), rx + 22, by + 38, 12)
  -- drill
  local dy = by + 64
  ui.group(rx, dy, rw, 74)
  gfx.color(theme.text)
  gfx.text(TR("drill"), rx + 14, dy + 12, 14, "semibold")
  local nd = ui.toggle("drill", K.drill, rx + rw - 54, dy + 10)
  if nd ~= K.drill then
    K.drill = nd
    K.text, K.code = "", ""
    if nd then newTarget() end
    audio.play("click")
  end
  if K.drill and K.target then
    gfx.color(theme.text2)
    gfx.text(TR("key_this"), rx + 14, dy + 44, 12.5)
    local tx = rx + 14 + gfx.textWidth(TR("key_this"), 12.5) + 8
    gfx.color(theme.accent)
    local tw = gfx.text(K.target, tx, dy + 40, 18, "bold")
    if K.hint then
      local _, code = textToTokens(K.target)
      gfx.color(theme.text3)
      gfx.clip(tx + tw + 10, dy + 36, rw - (tx - rx) - tw - 20, 28)
      gfx.text(code, tx + tw + 10, dy + 44, 12.5, "mono")
      gfx.unclip()
    end
  else
    gfx.color(theme.text3)
    gfx.text(TR("drill_hint"), rx + 14, dy + 44, 12.5)
  end
  -- timeline of the last 6 seconds
  local tlY = max(y0 + padH, dy + 74) + 18
  local tlH = 44
  gfx.color(theme.text2)
  gfx.text(TR("timeline"), x0, tlY, 12, "semibold")
  local tx0, tw0 = x0, w - 40
  gfx.rect(tx0, tlY + 18, tw0, tlH, 8, theme.dark and "#FFFFFF0A" or "#00000008")
  local now = sys.time()
  local span = 6
  gfx.clip(tx0, tlY + 18, tw0, tlH)
  for _, s in ipairs(K.segs) do
    local e = s.e or now
    local x1 = tx0 + tw0 - (now - s.s) / span * tw0
    local x2 = tx0 + tw0 - (now - e) / span * tw0
    if x2 > tx0 then
      local isDash = (e - s.s) >= 2 * unit()
      gfx.rect(x1, tlY + 18 + 10, max(2, x2 - x1), tlH - 20, 4, isDash and theme.orange or theme.accent)
    end
  end
  gfx.unclip()
  -- speed slider
  local sy = tlY + 18 + tlH + 14
  local nw = sliderRow(TR("speed"), cfg.wpm, TR("wpm"), "wpm2", 5, 40, 1, x0, sy, (w - 60) / 2)
  if nw ~= cfg.wpm then cfg.wpm = nw; saveCfg() end
  local nf = sliderRow(TR("tone"), cfg.freq, "Hz", "freq2", 400, 1000, 10, x0 + (w - 60) / 2 + 20, sy, (w - 60) / 2)
  if nf ~= cfg.freq then cfg.freq = nf; saveCfg() end
  gfx.color(theme.text3)
  gfx.text(TR("timing_hint", floor(unit() * 1000), floor(unit() * 2000)), x0, sy + 34, 12)
end

-- ------------------------------------------------------------------ chart tab
local CHART = {
  {"sec_letters", {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"}},
  {"sec_turkish", {"Ç", "Ğ", "ı", "Ö", "Ş", "Ü"}},
  {"sec_digits", {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}},
  {"sec_punct", {".", ",", "?", "'", "!", "/", "(", ")", "&", ":", ";", "=", "+", "-", "_", '"', "$", "@"}},
}

local function drawChart(w, h)
  local x0, top = 20, 62
  local cw, ch = 86, 58
  local cols = floor((w - 40 + 8) / (cw + 8))
  -- content height
  local total = 0
  for _, sec in ipairs(CHART) do total = total + 30 + math.ceil(#sec[2] / cols) * (ch + 8) + 8 end
  ui.beginScroll("chart", 0, top, w, h - top - 8, total)
  local y = 0
  for si, sec in ipairs(CHART) do
    gfx.color(theme.text2)
    gfx.text(TR(sec[1]), x0, y + 8, 12, "semibold")
    y = y + 30
    for i, key in ipairs(sec[2]) do
      local c = (i - 1) % cols
      local r = floor((i - 1) / cols)
      local bx, by = x0 + c * (cw + 8), y + r * (ch + 8)
      local active = P.playing and P.list and P.list.chartKey == key
      local hh = ui.hit("ch" .. si .. "_" .. i, bx, by, cw, ch)
      local bg = active and fade(theme.yellow, 0.3 + 0.5 * lamp) or (hh.hovered and theme.hover or (theme.dark and "#FFFFFF0D" or "#0000000A"))
      gfx.rect(bx, by, cw, ch, 10, bg)
      gfx.color(theme.text)
      gfx.text(displayOf(key), bx + 10, by + 8, 20, "bold")
      gfx.color(theme.accent)
      gfx.text(CODE[key], bx, by + 34, 14, "monobold", "right", cw - 10)
      if hh.clicked then
        local list = {{disp = displayOf(key), code = CODE[key]}}
        list.chartKey = key
        playTokens(list)
      end
    end
    y = y + math.ceil(#sec[2] / cols) * (ch + 8) + 8
  end
  ui.endScroll()
end

-- ------------------------------------------------------------------ main
function app.draw(w, h)
  nFields = 0
  gfx.clear(theme.bg)
  local nt = ui.segmented("tabs", {TR("tab_translate"), TR("tab_practice"), TR("tab_chart")}, cfg.tab, w / 2 - 190, 16, 380, 30)
  if nt ~= cfg.tab then
    cfg.tab = nt
    saveCfg()
    if K.down then keyUp() end
    stopPlayback()
    audio.play("click")
  end
  if cfg.tab == 1 then drawTranslate(w, h)
  elseif cfg.tab == 2 then drawPractice(w, h)
  else drawChart(w, h) end
end

function app.event(e)
  if e.type == "mousedown" then
    editing = pointInField(e.x, e.y)
    return
  end
  if editing and (e.type == "keydown" or e.type == "keyup" or e.type == "text") then
    if e.type == "keydown" and e.key == "escape" then editing = false end
    return
  end
  if cfg.tab == 2 then
    if e.type == "keydown" and (e.key == "space" or e.key == "enter") then keyDown("kb"); return end
    if e.type == "keyup" and (e.key == "space" or e.key == "enter") then keyUp("kb"); return end
    if e.type == "keydown" and (e.key == "backspace" or e.key == "delete") then
      if K.code ~= "" then K.code = "" else
        local n = utf8.len(K.text) or 0
        if n > 0 then K.text = K.text:sub(1, (utf8.offset(K.text, n) or 1) - 1) end
      end
      return
    end
    if e.type == "keydown" and e.key == "escape" then K.text, K.code = "", ""; return end
  end
  if e.type == "keydown" then
    if e.key == "tab" then cfg.tab = cfg.tab % 3 + 1; saveCfg()
    elseif (e.key == "space" or e.key == "p") and cfg.tab ~= 2 then togglePlay()
    elseif e.key == "escape" then stopPlayback()
    elseif e.key == "up" then cfg.wpm = min(40, cfg.wpm + 1); saveCfg()
    elseif e.key == "down" then cfg.wpm = max(5, cfg.wpm - 1); saveCfg() end
  end
end

function app.menu()
  return {{title = TR("menu_morse"), items = {
    {label = P.playing and TR("stop") or TR("play"), id = 1, shortcut = "Space"},
    {label = TR("copy_result"), id = 2},
    "-",
    {label = TR("tab_translate"), id = 3, checked = cfg.tab == 1},
    {label = TR("tab_practice"), id = 4, checked = cfg.tab == 2},
    {label = TR("tab_chart"), id = 5, checked = cfg.tab == 3},
  }}}
end

function app.onmenu(id)
  if id == 1 then togglePlay()
  elseif id == 2 then sys.clipboard(outText)
  elseif id >= 3 and id <= 5 then cfg.tab = id - 2; saveCfg() end
end

function app.close()
  stopPlayback()
  if K.chan then audio.stop(K.chan) end
  store.set("cfg", cfg)
  store.save()
  return true
end

return app
