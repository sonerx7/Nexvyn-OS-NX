-- kit.lua: small helpers shared by this app's screens: colours, text-field focus, toasts, undo history,
-- modal sheets, a scroller, CSV and a few widgets that follow the system theme.
local K = {}
local floor, min, max, abs = math.floor, math.min, math.max, math.abs

-- ------------------------------------------------------------------ numbers and colours
function K.clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
function K.round(v) return floor(v + 0.5) end
function K.approach(cur, target, speed, dt) return cur + (target - cur) * (1 - math.exp(-speed * dt)) end

local ccache = {}
function K.rgba(c)
  if type(c) == "table" then return c end
  c = tostring(c or "#000000")
  local t = ccache[c]
  if not t then
    t = {tonumber(c:sub(2, 3), 16) or 0, tonumber(c:sub(4, 5), 16) or 0, tonumber(c:sub(6, 7), 16) or 0,
         #c >= 9 and (tonumber(c:sub(8, 9), 16) or 255) or 255}
    ccache[c] = t
  end
  return t
end
function K.alpha(c, a)
  local t = K.rgba(c)
  return {t[1], t[2], t[3], K.clamp(floor((t[4] or 255) * a + 0.5), 0, 255)}
end
function K.mix(c1, c2, k)
  local a, b = K.rgba(c1), K.rgba(c2)
  return {floor(a[1] + (b[1] - a[1]) * k + 0.5), floor(a[2] + (b[2] - a[2]) * k + 0.5),
          floor(a[3] + (b[3] - a[3]) * k + 0.5), floor((a[4] or 255) + ((b[4] or 255) - (a[4] or 255)) * k + 0.5)}
end
function K.hex(t)
  t = K.rgba(t)
  return string.format("#%02X%02X%02X", K.clamp(floor(t[1]), 0, 255), K.clamp(floor(t[2]), 0, 255), K.clamp(floor(t[3]), 0, 255))
end
-- readable text colour on top of a fill
function K.onColor(c)
  local t = K.rgba(c)
  return (t[1] * 0.299 + t[2] * 0.587 + t[3] * 0.114) > 165 and "#1C1C1E" or "#FFFFFF"
end

-- ------------------------------------------------------------------ strings and tables
function K.trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
function K.ulen(s) return utf8.len(s) or #s end
function K.ellipsize(s, size, font, maxW)
  s = tostring(s or "")
  if maxW <= 8 then return "" end
  if gfx.textWidth(s, size, font) <= maxW then return s end
  if not utf8.len(s) then s = s:gsub("[\128-\255]", "?") end
  local n = utf8.len(s)
  local lo, hi = 0, n
  while lo < hi do
    local mid = floor((lo + hi + 1) / 2)
    local cut = s:sub(1, (utf8.offset(s, mid + 1) or (#s + 1)) - 1)
    if gfx.textWidth(cut .. "…", size, font) <= maxW then lo = mid else hi = mid - 1 end
  end
  return s:sub(1, (utf8.offset(s, lo + 1) or (#s + 1)) - 1) .. "…"
end
function K.utf8sub(s, i, j)
  local n = utf8.len(s)
  if not n then return s:sub(i, j) end
  j = j or n
  if i < 1 then i = 1 end
  if j > n then j = n end
  if i > j then return "" end
  local a = utf8.offset(s, i)
  local b = utf8.offset(s, j + 1)
  return s:sub(a, (b or (#s + 1)) - 1)
end
local LOWER = {["Ç"] = "ç", ["Ğ"] = "ğ", ["İ"] = "i", ["Ö"] = "ö", ["Ş"] = "ş", ["Ü"] = "ü", ["Ä"] = "ä", ["É"] = "é",
               ["È"] = "è", ["Ê"] = "ê", ["À"] = "à", ["Â"] = "â", ["Ñ"] = "ñ", ["Á"] = "á", ["Í"] = "í", ["Ó"] = "ó",
               ["Ú"] = "ú", ["Ô"] = "ô", ["Î"] = "î", ["Û"] = "û", ["Ë"] = "ë", ["Ï"] = "ï", ["Œ"] = "œ"}
function K.lower(s)
  s = tostring(s or ""):lower()
  if s:find("[\195\196\197]") then s = s:gsub("[\195\196\197][\128-\191]", LOWER) end
  return s
end
function K.copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = K.copy(x) end
  return t
end
function K.num(v, d)
  v = tonumber(v)
  if v == nil or v ~= v or v == math.huge or v == -math.huge then return d end
  return v
end
function K.int(v, d) v = K.num(v, nil); if not v then return d end return floor(v) end
function K.str(v, d) if v == nil then return d or "" end return tostring(v) end
function K.fmtNum(v, dec)
  dec = dec or 2
  if v == floor(v) and abs(v) < 1e15 then return string.format("%d", v) end
  local s = string.format("%." .. dec .. "f", v)
  s = s:gsub("(%.%d-)0+$", "%1"):gsub("%.$", "")
  return s
end
function K.split(s, sep)
  local out = {}
  s = tostring(s or "")
  local i = 1
  while true do
    local a, b = s:find(sep, i, true)
    if not a then out[#out + 1] = s:sub(i); break end
    out[#out + 1] = s:sub(i, a - 1)
    i = b + 1
  end
  return out
end
-- a file name without folders and extension
function K.baseName(p)
  p = tostring(p or ""):gsub("\\", "/")
  return (p:match("([^/]+)$") or p):gsub("%.[^%.]+$", "")
end

-- ------------------------------------------------------------------ CSV
function K.csvField(s)
  s = tostring(s or "")
  if s:find('[,"\n\r;]') then return '"' .. s:gsub('"', '""') .. '"' end
  return s
end
function K.csvLine(fields)
  local out = {}
  for i, f in ipairs(fields) do out[i] = K.csvField(f) end
  return table.concat(out, ",")
end
-- parses CSV text (comma or semicolon, quoted fields, CRLF) into a list of rows
function K.csvParse(text)
  text = tostring(text or ""):gsub("^\239\187\191", "")
  local first = text:match("^[^\n]*") or ""
  local sep = ","
  local _, commas = first:gsub(",", "")
  local _, semis = first:gsub(";", "")
  if semis > commas then sep = ";" end
  local rows, row, field, i, n, quoted = {}, {}, {}, 1, #text, false
  while i <= n do
    local c = text:sub(i, i)
    if quoted then
      if c == '"' then
        if text:sub(i + 1, i + 1) == '"' then field[#field + 1] = '"'; i = i + 1 else quoted = false end
      else field[#field + 1] = c end
    else
      if c == '"' then quoted = true
      elseif c == sep then row[#row + 1] = table.concat(field); field = {}
      elseif c == "\n" or c == "\r" then
        if c == "\r" and text:sub(i + 1, i + 1) == "\n" then i = i + 1 end
        row[#row + 1] = table.concat(field); field = {}
        if #row > 1 or row[1] ~= "" then rows[#rows + 1] = row end
        row = {}
      else field[#field + 1] = c end
    end
    i = i + 1
  end
  if #field > 0 or #row > 0 then
    row[#row + 1] = table.concat(field)
    if #row > 1 or row[1] ~= "" then rows[#rows + 1] = row end
  end
  return rows
end

-- ------------------------------------------------------------------ dates (local time)
function K.dayKey(epoch)
  local d = sys.date(epoch)
  return string.format("%04d-%02d-%02d", d.year, d.month, d.day)
end
function K.noon(epoch)
  local d = sys.date(epoch)
  return epoch - d.hour * 3600 - d.min * 60 - d.sec + 12 * 3600
end

-- ------------------------------------------------------------------ text-field focus
-- ui.textfield keeps its own focus; the app only needs to know whether typing goes into a field, so that letters
-- and arrows are not taken as shortcuts. A press inside a field (drawn with K.field) means "editing".
K.editing = false
local pressAt, fieldHit = false, false
function K.press(e)
  if e.type == "mousedown" then pressAt, fieldHit = true, false end
  if e.type == "keydown" and e.key == "escape" and K.editing then K.editing = false; return true end
  return false
end
function K.field(id, text, x, y, w, h, ph, flags)
  local nt, sub = ui.textfield(id, tostring(text or ""), x, y, w, h or 32, ph, flags)
  if pressAt then
    local mx, my = ui.mouse()
    if mx >= x and mx <= x + w and my >= y and my <= y + (h or 32) then fieldHit = id end
  end
  return nt, sub
end
-- K.editing is false or the id of the field that has the keyboard
function K.focus(id) ui.focus(id); K.editing = id; pressAt, fieldHit = false, false end
function K.blur() K.editing = false end
function K.frameEnd() if pressAt then K.editing = fieldHit; pressAt, fieldHit = false, false end end

-- ------------------------------------------------------------------ toasts
local toastMsg, toastAt, toastIcon = nil, 0, nil
function K.toast(msg, icon) toastMsg, toastAt, toastIcon = tostring(msg), sys.time(), icon end
function K.drawToast(w, h)
  if not toastMsg then return end
  local age = sys.time() - toastAt
  if age > 2.4 then toastMsg = nil; return end
  local a = min(1, age * 8, (2.4 - age) * 4)
  local tw = gfx.textWidth(toastMsg, 14, "medium") + (toastIcon and 58 or 36)
  tw = min(tw, w - 24)
  local x, y = floor((w - tw) / 2), h - 62 + floor((1 - a) * 10)
  gfx.alpha(a)
  gfx.shadow(x, y, tw, 38, 19, 12, 4)
  gfx.rect(x, y, tw, 38, 19, theme.dark and "#48484A" or "#1C1C1E")
  local tx = x + 18
  if toastIcon then gfx.icon(toastIcon, x + 26, y + 19, 18, "#FFFFFF"); tx = x + 42 end
  gfx.color("#FFFFFF")
  gfx.text(K.ellipsize(toastMsg, 14, "medium", tw - (tx - x) - 16), tx, y + 10, 14, "medium")
  gfx.unalpha()
end

-- ------------------------------------------------------------------ undo / redo
function K.history(limit)
  local H = {u = {}, r = {}, limit = limit or 80}
  function H:push(snap)
    self.u[#self.u + 1] = snap
    if #self.u > self.limit then table.remove(self.u, 1) end
    self.r = {}
  end
  function H:undo(cur)
    if #self.u == 0 then return nil end
    self.r[#self.r + 1] = cur
    return table.remove(self.u)
  end
  function H:redo(cur)
    if #self.r == 0 then return nil end
    self.u[#self.u + 1] = cur
    return table.remove(self.r)
  end
  function H:canUndo() return #self.u > 0 end
  function H:canRedo() return #self.r > 0 end
  function H:clear() self.u, self.r = {}, {} end
  return H
end

-- ------------------------------------------------------------------ scrolling with jumps
-- ui.beginScroll cannot be moved from code; this scroller can (keyboard and controller navigation, "go to").
-- Wheel, right stick and two-finger scroll move it; one finger drags it on the touch screen.
function K.scroller()
  local S = {y = 0, max = 0, target = nil, drag = nil, moved = false, vel = 0}
  function S:setMax(m)
    self.max = max(0, m)
    if self.y > self.max then self.y = self.max end
    if self.target and self.target > self.max then self.target = self.max end
  end
  function S:to(y, instant)
    y = K.clamp(y, 0, self.max)
    if instant then self.y, self.target = y, nil else self.target = y end
  end
  function S:reveal(top, bottom, viewH)
    local cur = self.target or self.y
    if top < cur then self:to(top - 16) elseif bottom > cur + viewH then self:to(bottom - viewH + 16) end
  end
  -- r = {x, y, w, h}; returns true when the event was used
  function S:event(e, r)
    local inside = e.x and e.x >= r[1] and e.x <= r[1] + r[3] and e.y >= r[2] and e.y <= r[2] + r[4]
    if e.type == "scroll" and inside then
      self.y = K.clamp(self.y + (e.dy or 0), 0, self.max)
      self.target, self.vel = nil, 0
      return true
    elseif e.type == "mousedown" then
      self.moved = false
      if inside and e.touch then
        self.drag = {y0 = e.y, s0 = self.y, ly = e.y, lt = sys.time()}
        self.vel = 0
      end
    elseif e.type == "mousemove" and self.drag then
      local d = e.y - self.drag.y0
      if abs(d) > 10 then self.moved = true end
      if self.moved then
        local now = sys.time()
        local dt = max(1 / 120, now - self.drag.lt)
        self.vel = (self.drag.ly - e.y) / dt
        self.drag.ly, self.drag.lt = e.y, now
        self.y = K.clamp(self.drag.s0 - d, 0, self.max)
        self.target = nil
        return true
      end
    elseif e.type == "mouseup" and self.drag then
      self.drag = nil
      if not self.moved then self.vel = 0 end
    end
    return false
  end
  -- a click that ended a drag must not count
  function S:dragged() return self.moved end
  function S:update(dt)
    if self.drag then return end
    if self.target then
      self.y = K.approach(self.y, self.target, 14, dt)
      if abs(self.y - self.target) < 0.5 then self.y, self.target = self.target, nil end
    elseif abs(self.vel) > 20 then
      self.y = K.clamp(self.y + self.vel * dt, 0, self.max)
      self.vel = self.vel * math.exp(-4 * dt)
      if self.y <= 0 or self.y >= self.max then self.vel = 0 end
    else
      self.vel = 0
    end
  end
  function S:bar(x, y, h)
    if self.max <= 0 then return end
    local th = max(28, h * h / (h + self.max))
    local ty = y + (h - th) * (self.y / self.max)
    gfx.rect(x, ty, 4, th, 2, K.alpha(theme.text, 0.22))
  end
  return S
end

-- ------------------------------------------------------------------ modal sheets
-- Draw the screen, then K.modal(...) and the sheet's widgets: the full-window hit area drawn last before the sheet
-- takes the pointer, so nothing underneath reacts. Returns the card rectangle and whether the user tapped outside.
function K.modal(id, w, h, cw, ch, t)
  t = t or 1
  gfx.rect(0, 0, w, h, 0, {0, 0, 0, floor((theme.dark and 120 or 90) * t)})
  local hit = ui.hit(id .. "##modal", 0, 0, w, h)
  cw, ch = min(cw, w - 24), min(ch, h - 24)
  local x, y = floor((w - cw) / 2), floor((h - ch) / 2 + (1 - t) * 24)
  gfx.shadow(x, y, cw, ch, 16, 26, 8)
  gfx.rect(x, y, cw, ch, 16, theme.window)
  gfx.color(theme.separator)
  gfx.rectLine(x, y, cw, ch, 16, 1)
  local mx, my = ui.mouse()
  local outside = hit.clicked and not (mx >= x and mx <= x + cw and my >= y and my <= y + ch)
  return x, y, cw, ch, outside
end

-- ------------------------------------------------------------------ small widgets
-- a pill toggle/chip; returns clicked, width
function K.chip(id, label, x, y, h, active, color, icon)
  local tw = gfx.textWidth(label, 13, "medium") + 24 + (icon and 20 or 0)
  local hit = ui.hit(id, x, y, tw, h)
  local c = color or theme.accent
  if active then gfx.rect(x, y, tw, h, h / 2, c)
  else gfx.rect(x, y, tw, h, h / 2, hit.hovered and theme.hover or K.alpha(theme.text, 0.06)) end
  local fg = active and K.onColor(c) or theme.text
  local tx = x + 12
  if icon then gfx.icon(icon, x + 20, y + h / 2, 16, fg); tx = x + 30 end
  gfx.color(fg)
  gfx.text(label, tx, y + (h - 17) / 2, 13, "medium")
  return hit.clicked, tw
end
function K.chipWidth(label, icon) return gfx.textWidth(label, 13, "medium") + 24 + (icon and 20 or 0) end
-- a section heading in small capitals
function K.heading(s, x, y, w)
  s = tostring(s):upper()
  gfx.color(theme.text2)
  gfx.text(s, x, y, 11, "semibold")
  if w then
    gfx.color(theme.separator)
    local tw = gfx.textWidth(s, 11, "semibold")
    if tw + 8 < w then gfx.line(x + tw + 8, y + 7, x + w, y + 7, 1) end
  end
end
-- empty state: icon, title and hint in the middle of an area
function K.empty(icon, title, hint, x, y, w, h)
  local cy = y + h / 2 - 40
  gfx.icon(icon, x + w / 2, cy, 44, K.alpha(theme.text, 0.25))
  gfx.color(theme.text2)
  gfx.text(title, x, cy + 34, 16, "semibold", "center", w)
  if hint then
    gfx.color(theme.text3)
    gfx.wrap(hint, x + 24, cy + 58, w - 48, 13, "sans", "center")
  end
end
-- layout metrics: compact (handheld window) or roomy (TV / maximized)
function K.metrics(w, h)
  return {compact = w < 780, narrow = w < 600, tall = h > 760, pad = w < 780 and 12 or 18}
end
-- a stable colour for a name (tags, players, series)
local PAL = {"blue", "green", "orange", "purple", "pink", "red", "yellow", "gray"}
function K.colorFor(name)
  local hsum = 7
  name = tostring(name or "")
  for i = 1, #name do hsum = (hsum * 31 + name:byte(i)) % 1000003 end
  return theme[PAL[hsum % 7 + 1]] or theme.accent
end

return K
