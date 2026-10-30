-- kit.lua: small shared toolkit for the bundled Nexvyn OS games.
-- Colors, easing, sound helpers, particles, dialogs, control hints and controller input helpers.
-- Only uses the documented Nexvyn OS SDK (gfx, ui, input, audio, sys, store, timer, theme).
local K = {}

local floor, max, min, abs, exp, sin, cos, pi = math.floor, math.max, math.min, math.abs, math.exp, math.sin, math.cos, math.pi

K.lastInput = "pointer" -- "pointer" | "pad" | "key": decides whether focus rings are shown
K.padLive = true        -- false while the controller drives the system cursor (L+R released the pad)
K.muted = false

-- ------------------------------------------------------------------ math / easing
function K.clamp(v, a, b)
  if v < a then return a elseif v > b then return b end
  return v
end
function K.lerp(a, b, t) return a + (b - a) * t end
function K.easeOut(t)
  t = K.clamp(t, 0, 1)
  local u = 1 - t
  return 1 - u * u * u
end
function K.easeIn(t)
  t = K.clamp(t, 0, 1)
  return t * t * t
end
function K.easeInOut(t)
  t = K.clamp(t, 0, 1)
  if t < 0.5 then return 4 * t * t * t end
  local u = -2 * t + 2
  return 1 - u * u * u / 2
end
function K.easeOutBack(t)
  t = K.clamp(t, 0, 1)
  local c1, c3 = 1.70158, 2.70158
  local u = t - 1
  return 1 + c3 * u * u * u + c1 * u * u
end
-- frame-rate independent exponential smoothing towards target
function K.approach(cur, target, rate, dt)
  return target + (cur - target) * exp(-rate * dt)
end

-- ------------------------------------------------------------------ colors
local cache = {}
local function byte(v)
  v = floor(v + 0.5)
  if v < 0 then return 0 elseif v > 255 then return 255 end
  return v
end
K.byte = byte

-- "#RRGGBB" / "#RRGGBBAA" / {r,g,b,a} -> {r,g,b,a} (integers, cached for strings)
function K.rgba(c)
  if type(c) == "table" then return c end
  c = c or "#000000"
  local t = cache[c]
  if t then return t end
  local s = tostring(c):gsub("^#", "")
  if #s == 3 then s = s:sub(1, 1):rep(2) .. s:sub(2, 2):rep(2) .. s:sub(3, 3):rep(2) end
  t = {tonumber(s:sub(1, 2), 16) or 0, tonumber(s:sub(3, 4), 16) or 0, tonumber(s:sub(5, 6), 16) or 0,
       #s >= 8 and (tonumber(s:sub(7, 8), 16) or 255) or 255}
  cache[c] = t
  return t
end

-- color with its alpha multiplied by a (0..1)
function K.col(c, a)
  local t = K.rgba(c)
  return {byte(t[1]), byte(t[2]), byte(t[3]), byte((t[4] or 255) * (a or 1))}
end

-- blend c1 -> c2 by t, optional alpha multiplier
function K.mix(c1, c2, t, a)
  local x, y = K.rgba(c1), K.rgba(c2)
  t = K.clamp(t, 0, 1)
  local xa, ya = x[4] or 255, y[4] or 255
  return {byte(x[1] + (y[1] - x[1]) * t), byte(x[2] + (y[2] - x[2]) * t), byte(x[3] + (y[3] - x[3]) * t),
          byte((xa + (ya - xa) * t) * (a or 1))}
end

function K.luma(c)
  local t = K.rgba(c)
  return (0.299 * t[1] + 0.587 * t[2] + 0.114 * t[3]) / 255
end

-- HSV (h 0..360, s,v 0..1) -> color table
function K.hsv(h, s, v, a)
  h = (h % 360) / 60
  local i = floor(h)
  local f = h - i
  local p, q, r = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
  local R, G, B
  if i == 0 then R, G, B = v, r, p elseif i == 1 then R, G, B = q, v, p elseif i == 2 then R, G, B = p, v, r
  elseif i == 3 then R, G, B = p, q, v elseif i == 4 then R, G, B = r, p, v else R, G, B = v, p, q end
  return {byte(R * 255), byte(G * 255), byte(B * 255), byte(255 * (a or 1))}
end

-- ------------------------------------------------------------------ sound
function K.loadPrefs()
  K.muted = store.get("muted", false) == true
end
function K.setMuted(v)
  K.muted = v and true or false
  store.set("muted", K.muted)
end
function K.tone(f, d, v, w)
  if K.muted then return end
  audio.tone(f, d or 0.1, v or 0.3, w or "sine")
end
function K.play(name, v)
  if K.muted then return end
  audio.play(name, v or 1)
end
-- quick arpeggio: list of frequencies played one after another
function K.notes(list, step, vol, wave)
  if K.muted then return end
  step = step or 0.08
  for i, f in ipairs(list) do
    if i == 1 then
      audio.tone(f, step * 1.6, vol or 0.25, wave or "triangle")
    else
      timer.after((i - 1) * step, function()
        if not K.muted then audio.tone(f, step * 1.6, vol or 0.25, wave or "triangle") end
      end)
    end
  end
end
function K.rumble(s, ms)
  sys.vibrate(s or 0.4, ms or 40)
end

-- ------------------------------------------------------------------ text helpers
function K.fmtTime(s)
  s = floor(s or 0)
  local h, m, sec = floor(s / 3600), floor(s / 60) % 60, s % 60
  if h > 0 then return string.format("%d:%02d:%02d", h, m, sec) end
  return string.format("%d:%02d", m, sec)
end

-- ------------------------------------------------------------------ input
local arrows = {up = true, down = true, left = true, right = true}

-- call first in app.event: remembers the last input device
function K.track(e)
  local t = e.type
  if t == "mousedown" or t == "scroll" then
    K.lastInput = "pointer"
  elseif t == "keydown" then
    K.lastInput = "key"
    -- D-pad/B produce arrow/escape keys only while the system cursor owns the controller
    if (arrows[e.key] and input.down(e.key)) or (e.key == "escape" and input.down("b")) then
      K.padLive = false
      K.lastInput = "pad"
    end
  elseif t == "paddown" then
    K.lastInput = "pad"
    K.padLive = true
  end
end

-- Polls D-pad + left stick and returns a direction on press and (with repeat) while held.
-- st: persistent table; opts: {rep=false, delay=0.3, rate=0.1, stick="left", dpad=true}
function K.dirInput(st, dt, opts)
  opts = opts or {}
  if not K.padLive then st.dir = nil; return nil end
  local dir
  if opts.dpad ~= false then
    if input.down("up") then dir = "up"
    elseif input.down("down") then dir = "down"
    elseif input.down("left") then dir = "left"
    elseif input.down("right") then dir = "right" end
  end
  if not dir and opts.stick ~= false then
    local x, y = input.stick(opts.stick or "left")
    local ax, ay = abs(x), abs(y)
    local th = (st.dir and st.fromStick) and 0.35 or 0.6
    if ax > th or ay > th then
      if ax > ay then dir = x > 0 and "right" or "left" else dir = y > 0 and "up" or "down" end
      st.fromStick = true
    else
      st.fromStick = false
    end
  else
    st.fromStick = false
  end
  if dir ~= st.dir then
    st.dir = dir
    st.t = opts.delay or 0.3
    if dir then K.lastInput = "pad" end
    return dir
  end
  if dir and opts.rep ~= false then
    st.t = (st.t or 0) - dt
    if st.t <= 0 then
      st.t = opts.rate or 0.1
      return dir
    end
  end
  return nil
end

-- ------------------------------------------------------------------ drawing helpers
function K.dim(w, h, a)
  gfx.rect(0, 0, w, h, 0, {0, 0, 0, byte(115 * (a or 1))})
end

function K.card(x, y, w, h, r)
  r = r or 14
  gfx.shadow(x, y, w, h, r, 26, 10)
  gfx.rect(x, y, w, h, r, theme.window)
  gfx.color(theme.separator)
  gfx.rectLine(x, y, w, h, r, 1)
end

-- pulsing focus ring, shown only for pad/keyboard users unless force is true
function K.ring(x, y, w, h, r, c, th, force)
  if K.lastInput == "pointer" and not force then return end
  local p = 0.5 + 0.5 * sin(sys.time() * 6)
  gfx.color(K.col(c or theme.accent, 0.6 + 0.4 * p))
  gfx.rectLine(x, y, w, h, r or 8, th or 3)
end

-- small labelled value box (score / best / time)
function K.stat(x, y, w, h, label, value, accent)
  gfx.rect(x, y, w, h, 10, accent and K.col(accent, 0.16) or K.col(theme.text, theme.dark and 0.09 or 0.06))
  gfx.color(accent or theme.text2)
  gfx.text(label, x, y + 5, 11, "semibold", "center", w)
  gfx.color(theme.text)
  gfx.text(value, x, y + h * 0.36, min(22, h * 0.42), "bold", "center", w)
end

-- ------------------------------------------------------------------ toasts
local toastMsg, toastT, toastDur = nil, 0, 1.6
function K.toast(msg, dur)
  toastMsg, toastT, toastDur = msg, sys.time(), dur or 1.6
end
function K.drawToast(w, y)
  if not toastMsg then return end
  local el = sys.time() - toastT
  if el > toastDur then toastMsg = nil; return end
  local a = K.clamp(min(el / 0.15, (toastDur - el) / 0.3), 0, 1)
  local tw = gfx.textWidth(toastMsg, 14, "semibold") + 36
  local x = (w - tw) / 2
  local yy = y - (1 - K.easeOut(min(1, el / 0.2))) * 10
  gfx.alpha(a)
  gfx.shadow(x, yy, tw, 34, 17, 14, 4)
  gfx.rect(x, yy, tw, 34, 17, theme.window)
  gfx.color(theme.separator)
  gfx.rectLine(x, yy, tw, 34, 17, 1)
  gfx.color(theme.text)
  gfx.text(toastMsg, x, yy + 8, 14, "semibold", "center", tw)
  gfx.unalpha()
end

-- ------------------------------------------------------------------ control hints
local function glyph(g, x, cy, fg, bg)
  if g == "A" or g == "B" or g == "X" or g == "Y" or g == "+" or g == "-" then
    gfx.circle(x + 9, cy, 9, fg)
    gfx.color(bg)
    if g == "+" then
      gfx.rect(x + 5, cy - 1, 8, 2, 1, bg); gfx.rect(x + 8, cy - 4, 2, 8, 1, bg)
    elseif g == "-" then
      gfx.rect(x + 5, cy - 1, 8, 2, 1, bg)
    else
      gfx.text(g, x, cy - 8, 12, "bold", "center", 18)
    end
    return 18
  elseif g == "dpad" then
    gfx.rect(x + 6, cy - 9, 6, 18, 1.5, fg)
    gfx.rect(x, cy - 3, 18, 6, 1.5, fg)
    return 18
  elseif g == "lstick" or g == "rstick" then
    gfx.circle(x + 9, cy, 9, fg)
    gfx.circle(x + 9, cy, 6, bg)
    gfx.color(fg)
    gfx.text(g == "lstick" and "L" or "R", x, cy - 6, 9, "bold", "center", 18)
    return 18
  elseif g == "touch" then
    gfx.icon("touch_app", x + 9, cy, 18, fg)
    return 18
  else
    local tw = max(20, gfx.textWidth(g, 11, "bold") + 10)
    gfx.rect(x, cy - 9, tw, 18, 5, fg)
    gfx.color(bg)
    gfx.text(g, x, cy - 7, 11, "bold", "center", tw)
    return tw
  end
end

local function glyphWidth(g)
  if g == "A" or g == "B" or g == "X" or g == "Y" or g == "+" or g == "-" or g == "dpad" or g == "lstick"
    or g == "rstick" or g == "touch" then return 18 end
  return max(20, gfx.textWidth(g, 11, "bold") + 10)
end

-- items: { {glyph or {glyph,...}, label}, ... } drawn as one centered row inside [x, x+w]
function K.hints(items, x, y, w, fg, bg)
  fg = fg and K.rgba(fg) or K.col(theme.text, 0.62)
  bg = bg or theme.bg
  local total, gap = 0, 16
  local widths = {}
  for i, it in ipairs(items) do
    local gs = type(it[1]) == "table" and it[1] or {it[1]}
    local gw = 0
    for j, g in ipairs(gs) do gw = gw + glyphWidth(g) + (j > 1 and 3 or 0) end
    local lw = gfx.textWidth(it[2], 12, "medium")
    widths[i] = gw + 6 + lw
    total = total + widths[i] + (i > 1 and gap or 0)
  end
  if total > w and #items > 1 then
    gap = max(6, gap - (total - w) / (#items - 1))
    total = 0
    for i = 1, #items do total = total + widths[i] + (i > 1 and gap or 0) end
  end
  local cx = x + (w - total) / 2
  local cy = y + 9
  for i, it in ipairs(items) do
    local gs = type(it[1]) == "table" and it[1] or {it[1]}
    local px = cx
    for j, g in ipairs(gs) do
      if j > 1 then px = px + 3 end
      px = px + glyph(g, px, cy, fg, bg)
    end
    gfx.color(fg)
    gfx.text(it[2], px + 6, cy - 8, 12, "medium")
    cx = cx + widths[i] + gap
  end
end

-- ------------------------------------------------------------------ dialogs
-- st: persistent table per dialog. K.open(st) restarts its appear animation and focus.
function K.open(st, sel)
  st.sel = sel or 1
  st.t0 = sys.time()
  st.buttons = nil
end

-- opts: {title, subtitle, icon, iconColor, width, lines = {...}, extraH, extra = function(x, y, w),
--        buttons = { {label, fn, style}, ... }, dim}
function K.dialog(st, w, h, opts)
  local a = K.easeOut((sys.time() - (st.t0 or 0)) / 0.25)
  K.dim(w, h, a * (opts.dim or 1))
  local bw = opts.width or 300
  local pad = 22
  local ch = pad
  if opts.icon then ch = ch + 56 end
  if opts.title then ch = ch + 32 end
  if opts.subtitle then ch = ch + gfx.measureWrap(opts.subtitle, bw - 2 * pad, 14) + 6 end
  local lines = opts.lines or {}
  ch = ch + #lines * 22
  if #lines > 0 then ch = ch + 8 end
  if opts.extraH then ch = ch + opts.extraH end
  local buttons = opts.buttons or {}
  ch = ch + #buttons * 46 + 8
  local x = floor((w - bw) / 2)
  local y = floor((h - ch) / 2 + (1 - a) * 24)
  gfx.alpha(a)
  K.card(x, y, bw, ch, 16)
  local cy = y + pad
  if opts.icon then
    local ic = opts.iconColor or theme.accent
    gfx.circle(x + bw / 2, cy + 22, 25, K.col(ic, 0.16))
    gfx.icon(opts.icon, x + bw / 2, cy + 22, 30, ic)
    cy = cy + 56
  end
  if opts.title then
    gfx.color(theme.text)
    gfx.text(opts.title, x, cy, 22, "bold", "center", bw)
    cy = cy + 32
  end
  if opts.subtitle then
    gfx.color(theme.text2)
    cy = cy + gfx.wrap(opts.subtitle, x + pad, cy, bw - 2 * pad, 14, "sans", "center") + 6
  end
  for _, l in ipairs(lines) do
    if type(l) == "table" then
      gfx.color(theme.text2)
      gfx.text(l[1], x + pad + 8, cy + 2, 14)
      gfx.color(l[3] or theme.text)
      gfx.text(l[2], x, cy + 2, 14, "semibold", "right", bw - pad - 8)
    else
      gfx.color(theme.text2)
      gfx.text(l, x, cy + 2, 14, "sans", "center", bw)
    end
    cy = cy + 22
  end
  if #lines > 0 then cy = cy + 8 end
  if opts.extra then
    opts.extra(x + pad, cy, bw - 2 * pad)
    cy = cy + (opts.extraH or 0)
  end
  cy = cy + 4
  st.sel = K.clamp(st.sel or 1, 1, max(1, #buttons))
  for i, b in ipairs(buttons) do
    local bx, by, bww = x + pad, cy, bw - 2 * pad
    if st.sel == i then K.ring(bx - 3, by - 3, bww + 6, 42, 10) end
    if ui.button(b[1] .. "##dlg" .. i, bx, by, bww, 36, b[3] or (i == 1 and "primary" or "default"), b[4]) then
      st.sel = i
      if a > 0.6 then b[2]() end
    end
    cy = cy + 46
  end
  gfx.unalpha()
  st.buttons = buttons
  st.rect = {x, y, bw, ch}
end

-- act: "up"/"down" move focus, "ok" activates. Returns true when consumed.
function K.dialogInput(st, act)
  local bs = st.buttons
  if not bs or #bs == 0 then return false end
  local n = #bs
  if act == "up" then
    st.sel = (K.clamp(st.sel or 1, 1, n) - 2) % n + 1
    K.tone(880, 0.03, 0.12, "triangle")
    return true
  elseif act == "down" then
    st.sel = K.clamp(st.sel or 1, 1, n) % n + 1
    K.tone(880, 0.03, 0.12, "triangle")
    return true
  elseif act == "ok" then
    if sys.time() - (st.t0 or 0) < 0.15 then return true end
    local b = bs[K.clamp(st.sel or 1, 1, n)]
    if b then
      K.tone(660, 0.05, 0.2, "triangle")
      b[2]()
    end
    return true
  end
  return false
end

-- ------------------------------------------------------------------ particles
function K.particles()
  local P = {list = {}}
  function P:emit(x, y, vx, vy, life, size, color, grav, drag)
    local L = self.list
    if #L > 600 then return end
    L[#L + 1] = {x = x, y = y, vx = vx, vy = vy, life = life, max = life, size = size, c = K.rgba(color),
                 g = grav or 0, drag = drag or 0}
  end
  function P:burst(x, y, n, color, speed, life, size, grav, drag)
    for _ = 1, n do
      local ang = math.random() * pi * 2
      local s = speed * (0.25 + math.random() * 0.75)
      self:emit(x, y, cos(ang) * s, sin(ang) * s, life * (0.6 + math.random() * 0.4),
                size * (0.6 + math.random() * 0.6), color, grav, drag)
    end
  end
  function P:update(dt)
    local L = self.list
    local j = 0
    local n = #L
    for i = 1, n do
      local p = L[i]
      p.life = p.life - dt
      if p.life > 0 then
        p.vy = p.vy + p.g * dt
        if p.drag > 0 then
          local f = exp(-p.drag * dt)
          p.vx, p.vy = p.vx * f, p.vy * f
        end
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        j = j + 1
        L[j] = p
      end
    end
    for i = j + 1, n do L[i] = nil end
  end
  function P:draw()
    for _, p in ipairs(self.list) do
      local k = p.life / p.max
      local c = p.c
      gfx.circle(p.x, p.y, max(0.6, p.size * (0.35 + 0.65 * k)), {c[1], c[2], c[3], byte((c[4] or 255) * min(1, k * 1.4))})
    end
  end
  function P:clear() self.list = {} end
  return P
end

return K
