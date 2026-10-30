-- QR Code for Nexvyn OS: text, link and Wi-Fi QR codes encoded in Lua, with a live preview and text-art export.
local app = {}

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local QR = require("qr")

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

-- ------------------------------------------------------------------ state
local ECLS = {"L", "M", "Q", "H"}
local ECL_PCT = {7, 15, 25, 30}
local SECURITY = {"WPA", "WEP", "nopass"}
local st = {mode = 1, text = "", url = "", ssid = "", pass = "", sec = 1, hidden = false, ecl = 2}
local showPass = false
local cur = nil              -- current encoded symbol
local prev = nil             -- previous symbol for the crossfade
local fadeT = 1
local lastPayload, lastEcl = nil, nil
local errKey = nil
local toast, toastT = "", -10

local function saveState() store.set("state", st) end

local function escWifi(s) return (s:gsub('([\\;,:"])', "\\%1")) end

local function payload()
  if st.mode == 1 then
    return st.text
  elseif st.mode == 2 then
    local u = st.url:gsub("^%s+", ""):gsub("%s+$", "")
    if u ~= "" and not u:find("^%a[%w%+%.%-]*:") then u = "https://" .. u end
    return u
  else
    if st.ssid == "" then return "" end
    local t = SECURITY[st.sec] or "WPA"
    local s = "WIFI:T:" .. t .. ";S:" .. escWifi(st.ssid) .. ";"
    if t ~= "nopass" then s = s .. "P:" .. escWifi(st.pass) .. ";" end
    if st.hidden then s = s .. "H:true;" end
    return s .. ";"
  end
end

local function refresh()
  local p = payload()
  local ecl = ECLS[st.ecl] or "M"
  if p == lastPayload and ecl == lastEcl then return end
  lastPayload, lastEcl = p, ecl
  if p == "" then
    if cur then prev, fadeT = cur, 0 end
    cur, errKey = nil, "empty"
    return
  end
  local sym = QR.encode(p, ecl)
  if not sym then
    if cur then prev, fadeT = cur, 0 end
    cur, errKey = nil, "too_long"
    return
  end
  prev, cur, fadeT, errKey = cur, sym, 0, nil
end

-- ------------------------------------------------------------------ export
local function textArt(sym)
  local q = 4
  local n = sym.size
  local function dark(x, y)
    if x < 0 or y < 0 or x >= n or y >= n then return false end
    return sym.modules[y][x]
  end
  local lines = {}
  for y = -q, n + q - 1, 2 do
    local row = {}
    for x = -q, n + q - 1 do
      local a, b = dark(x, y), dark(x, y + 1)
      row[#row + 1] = (a and b) and "█" or (a and "▀" or (b and "▄" or " "))
    end
    lines[#lines + 1] = table.concat(row)
  end
  return table.concat(lines, "\n")
end

local function saveTextArt()
  if not cur then
    audio.play("error")
    return
  end
  local d = sys.date()
  local name = string.format("QR %04d-%02d-%02d %02d.%02d.%02d.txt", d.year, d.month, d.day, d.hour, d.min, d.sec)
  local dir = fs.dir("documents")
  if not fs.isdir(dir) then fs.mkdir(dir) end
  local path = dir .. "/" .. name
  local body = textArt(cur) .. "\n\n" .. TR("art_content") .. " " .. lastPayload .. "\n" ..
    TR("art_info", cur.version, cur.ecl, cur.size) .. "\n" .. TR("art_note") .. "\n"
  if fs.write(path, body) then
    audio.play("shutter")
    sys.notify(TR("saved_title"), name)
    ui.alert(TR("saved_title"), TR("saved_msg", name), {TR("open_file"), TR("ok")}, function(b)
      if b == 1 then sys.open(path) end
    end)
  else
    audio.play("error")
    ui.alert(TR("save_failed"), TR("save_failed_msg"), {TR("ok")})
  end
end

local function showToast(s) toast, toastT = s, sys.time() end

-- ------------------------------------------------------------------ lifecycle
function app.load()
  local s = store.get("state", nil)
  if type(s) == "table" then
    for k, v in pairs(s) do
      if st[k] ~= nil and type(v) == type(st[k]) then st[k] = v end
    end
  else
    st.text = TR("sample_text")
    st.url = "https://github.com/sonerx7"
  end
  if st.mode < 1 or st.mode > 3 then st.mode = 1 end
  if st.ecl < 1 or st.ecl > 4 then st.ecl = 2 end
  if st.sec < 1 or st.sec > 3 then st.sec = 1 end
  refresh()
  fadeT = 1
  prev = nil
end

function app.update(dt)
  fadeT = min(1, fadeT + dt / 0.25)
  if fadeT >= 1 then prev = nil end
end

-- ------------------------------------------------------------------ drawing
local function drawSymbol(sym, x, y, cell, alpha)
  if not sym then return end
  local n = sym.size
  gfx.alpha(alpha)
  gfx.color("#111114")
  for yy = 0, n - 1 do
    local row = sym.modules[yy]
    local xx = 0
    while xx < n do
      if row[xx] then
        local start = xx
        while xx < n and row[xx] do xx = xx + 1 end
        gfx.rect(x + start * cell, y + yy * cell, (xx - start) * cell, cell)
      else
        xx = xx + 1
      end
    end
  end
  gfx.unalpha()
end

local function drawPreview(x, y, w, h)
  local cardS = min(w, h - 60)
  local cx = x + (w - cardS) / 2
  gfx.shadow(cx, y, cardS, cardS, 18, 24, 6)
  gfx.rect(cx, y, cardS, cardS, 18, "#FFFFFF")
  if theme.dark then
    gfx.color("#FFFFFF33")
    gfx.rectLine(cx, y, cardS, cardS, 18, 1)
  end
  local function place(sym)
    if not sym then return 0, 0, 0 end
    local total = sym.size + 8
    local cell = floor((cardS - 16) / total)
    if cell < 1 then cell = (cardS - 16) / total end
    local qs = cell * sym.size
    return cell, cx + (cardS - qs) / 2, y + (cardS - qs) / 2
  end
  if prev and fadeT < 1 then
    local c, px, py = place(prev)
    drawSymbol(prev, px, py, c, 1 - fadeT)
  end
  if cur then
    local c, px, py = place(cur)
    drawSymbol(cur, px, py, c, fadeT)
  else
    local icon = errKey == "too_long" and "error_outline" or "qr_code_2"
    gfx.icon(icon, cx + cardS / 2, y + cardS / 2 - 26, 56, errKey == "too_long" and "#FF3B30" or "#C7C7CC")
    gfx.color(errKey == "too_long" and "#FF3B30" or "#8E8E93")
    gfx.wrap(errKey == "too_long" and TR("too_long", ECLS[st.ecl]) or TR("empty_hint"), cx + 30, y + cardS / 2 + 14,
      cardS - 60, 13.5, "medium", "center")
  end
  -- caption
  local cy = y + cardS + 16
  if cur then
    gfx.color(theme.text2)
    gfx.text(TR("caption", cur.version, cur.size, cur.size, cur.ecl), x, cy, 13, "medium", "center", w)
    gfx.color(theme.text3)
    gfx.clip(x, cy + 20, w, 20)
    local p = lastPayload or ""
    if utf8.len(p) and utf8.len(p) > 60 then p = p:sub(1, utf8.offset(p, 58) - 1) .. "…" end
    gfx.text(p, x, cy + 22, 12, "sans", "center", w)
    gfx.unclip()
  end
end

local function label(s, x, y)
  gfx.color(theme.text2)
  gfx.text(s, x, y, 12, "semibold")
end

local function drawForm(x, y, w)
  local nm = ui.segmented("mode", {TR("mode_text"), TR("mode_link"), TR("mode_wifi")}, st.mode, x, y, w, 30)
  if nm ~= st.mode then st.mode = nm; saveState(); audio.play("click") end
  y = y + 46
  if st.mode == 1 then
    label(TR("text_label"), x, y)
    local nt = field("qr_text", st.text, x, y + 18, w, 36, TR("text_ph"))
    if nt ~= st.text then st.text = nt; saveState() end
    y = y + 66
  elseif st.mode == 2 then
    label(TR("url_label"), x, y)
    local nu = field("qr_url", st.url, x, y + 18, w, 36, "https://example.com")
    if nu ~= st.url then st.url = nu; saveState() end
    gfx.color(theme.text3)
    gfx.text(TR("url_hint"), x, y + 60, 11.5)
    y = y + 84
  else
    label(TR("ssid_label"), x, y)
    local ns = field("qr_ssid", st.ssid, x, y + 18, w, 36, TR("ssid_ph"))
    if ns ~= st.ssid then st.ssid = ns; saveState() end
    y = y + 64
    label(TR("security_label"), x, y)
    local nsec = ui.segmented("sec", {"WPA/WPA2", "WEP", TR("sec_none")}, st.sec, x, y + 18, w, 30)
    if nsec ~= st.sec then st.sec = nsec; saveState(); audio.play("click") end
    y = y + 60
    if st.sec ~= 3 then
      label(TR("pass_label"), x, y)
      local np = field("qr_pass", st.pass, x, y + 18, w - 44, 36, TR("pass_ph"), showPass and "" or "password")
      if np ~= st.pass then st.pass = np; saveState() end
      if ui.iconButton(showPass and "visibility_off" or "visibility", x + w - 38, y + 20, 36, 32, theme.text2, false, "eye") then
        showPass = not showPass
      end
      y = y + 64
    end
    gfx.color(theme.text)
    gfx.text(TR("hidden_net"), x, y + 4, 14)
    local nh = ui.toggle("hidden", st.hidden, x + w - 40, y + 2)
    if nh ~= st.hidden then st.hidden = nh; saveState(); audio.play("click") end
    y = y + 38
  end
  -- error correction
  label(TR("ecl_label"), x, y)
  local ne = ui.segmented("ecl", {"L", "M", "Q", "H"}, st.ecl, x, y + 18, w, 30)
  if ne ~= st.ecl then st.ecl = ne; saveState(); audio.play("click") end
  gfx.color(theme.text3)
  gfx.text(TR("ecl_hint", ECL_PCT[st.ecl]), x, y + 54, 11.5)
  y = y + 80
  -- info
  ui.group(x, y, w, 76)
  local p = lastPayload or ""
  local used = #p
  local ecl = ECLS[st.ecl]
  local cap = QR.capacity(QR.MAX_VERSION, ecl)
  local capNow = cur and QR.capacity(cur.version, ecl) or cap
  local rows = {
    {TR("info_version"), cur and TR("version_fmt", cur.version, cur.size) or "—"},
    {TR("info_bytes"), TR("bytes_fmt", used, capNow)},
  }
  for i, r in ipairs(rows) do
    local ry = y + 10 + (i - 1) * 30
    gfx.color(theme.text2)
    gfx.text(r[1], x + 14, ry + 4, 13)
    gfx.color(used > cap and theme.red or theme.text)
    gfx.text(r[2], x, ry + 4, 13, "semibold", "right", w - 14)
  end
  ui.progress(min(1, used / max(1, cap)), x + 14, y + 66, w - 28, 3)
  y = y + 92
  -- actions
  if ui.button(TR("save_art") .. "##save", x, y, w, 36, "primary", "save_alt", cur ~= nil) then saveTextArt() end
  y = y + 44
  if ui.button(TR("copy_content") .. "##copy", x, y, w, 32, "default", "content_copy", (lastPayload or "") ~= "") then
    sys.clipboard(lastPayload)
    audio.play("pop")
    showToast(TR("copied"))
  end
end

local function drawToast(w, h)
  local age = sys.time() - toastT
  if age > 1.6 then return end
  local a = min(1, age / 0.12) * min(1, (1.6 - age) / 0.3)
  local tw = gfx.textWidth(toast, 13, "medium") + 44
  local tx, ty = (w - tw) / 2, h - 52
  gfx.alpha(a)
  gfx.shadow(tx, ty, tw, 32, 16, 12, 3)
  gfx.rect(tx, ty, tw, 32, 16, theme.dark and "#3A3A3C" or "#323236")
  gfx.icon("check_circle", tx + 18, ty + 16, 16, theme.green)
  gfx.color("#FFFFFF")
  gfx.text(toast, tx + 32, ty + 8, 13, "medium")
  gfx.unalpha()
end

function app.draw(w, h)
  nFields = 0
  refresh()
  gfx.clear(theme.bg)
  gfx.color(theme.text)
  gfx.text(TR("title"), 20, 18, 22, "bold")
  local formW = 360
  drawForm(20, 60, formW)
  local px = 20 + formW + 30
  drawPreview(px, 60, w - px - 20, h - 80)
  drawToast(w, h)
end

function app.event(e)
  if e.type == "mousedown" then
    editing = pointInField(e.x, e.y)
    return
  end
  if e.type ~= "keydown" then return end
  if editing then
    if e.key == "escape" then editing = false end
    return
  end
  if e.key == "left" then st.ecl = max(1, st.ecl - 1); saveState()
  elseif e.key == "right" then st.ecl = min(4, st.ecl + 1); saveState()
  elseif e.key == "tab" then st.mode = st.mode % 3 + 1; saveState()
  elseif e.key == "s" then saveTextArt() end
end

function app.menu()
  return {{title = TR("menu_qr"), items = {
    {label = TR("save_art"), id = 1, shortcut = "S", enabled = cur ~= nil},
    {label = TR("copy_content"), id = 2},
    "-",
    {label = TR("mode_text"), id = 3, checked = st.mode == 1},
    {label = TR("mode_link"), id = 4, checked = st.mode == 2},
    {label = TR("mode_wifi"), id = 5, checked = st.mode == 3},
  }}}
end

function app.onmenu(id)
  if id == 1 then saveTextArt()
  elseif id == 2 then sys.clipboard(lastPayload or ""); showToast(TR("copied"))
  elseif id >= 3 and id <= 5 then st.mode = id - 2; saveState() end
end

function app.close()
  saveState()
  store.save()
  return true
end

return app
