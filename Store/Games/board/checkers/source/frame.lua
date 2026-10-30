-- frame.lua: shared screen helpers for these games: modal scenes and dialog routing, a right-aligned icon toolbar,
-- the title block, a grid cursor and the common dialogs (statistics, reset statistics, confirm new game).
local K = require("kit")
local F = {scene = "play", dlg = {}, stickSt = {}}

local floor, max, min = math.floor, math.max, math.min

-- Sub-dialogs (statistics, reset, confirm) opened from the title screen or the pause menu return there on close.
local SUB = {stats = true, reset = true, confirm = true}
function F.open(scene, sel)
  if SUB[scene] then
    if F.scene == "title" or F.scene == "pause" then F.returnTo = F.scene end
  else
    F.returnTo = nil
  end
  F.scene = scene
  K.open(F.dlg, sel)
end
function F.close()
  local r = F.returnTo
  F.returnTo = nil
  if r then
    F.scene = r
    K.open(F.dlg)
  else
    F.scene = "play"
  end
end
-- Leaves every menu and goes straight to the game.
function F.play()
  F.returnTo = nil
  F.scene = "play"
end
function F.modal() return F.scene ~= "play" end

-- Routes a paddown/keydown event to the open dialog. back() runs on B / Esc. Returns true when consumed.
function F.dialogEvent(e, back)
  local pad = e.type == "paddown"
  local k = pad and e.pad or (e.type == "keydown" and e.key) or nil
  if not k then return false end
  if k == "up" or k == "left" then K.dialogInput(F.dlg, "up")
  elseif k == "down" or k == "right" or k == "tab" then K.dialogInput(F.dlg, "down")
  elseif (pad and k == "a") or (not pad and (k == "enter" or k == "space")) then K.dialogInput(F.dlg, "ok")
  elseif (pad and k == "b") or (not pad and k == "escape") then
    if back then back() else F.close() end
  end
  return true
end

-- Stick / D-pad polling. While a dialog is open the direction moves the dialog focus and nil is returned.
function F.stick(dt, opts)
  local d = K.dirInput(F.stickSt, dt, opts)
  if d and F.modal() then
    K.dialogInput(F.dlg, (d == "up" or d == "left") and "up" or "down")
    return nil
  end
  return d
end

-- Title + subtitle at the top left.
function F.title(title, sub, x, y, size)
  size = size or 26
  gfx.color(theme.text)
  gfx.text(title, x, y, size, "bold")
  if sub then
    gfx.color(theme.text2)
    gfx.text(sub, x + 1, y + size * 1.25, 12, "medium")
  end
end

-- Right-aligned row of icon buttons. items = { {icon, id[, tint[, active]]}, ... } drawn from the right edge
-- leftwards. Returns the id of the clicked button (or nil) and the x where the row starts.
function F.toolbar(items, right, y, bw, bh)
  bw, bh = bw or 40, bh or 34
  local x, hit = right, nil
  for i = 1, #items do
    local it = items[i]
    x = x - bw
    if ui.iconButton(it[1], x, y, bw, bh, it[3], it[4] or false, "tb" .. tostring(it[2])) and not F.modal() then
      hit = it[2]
    end
    x = x - 6
  end
  return hit, x
end

-- The sound toggle used in every toolbar.
function F.soundItem() return {K.muted and "volume_off" or "volume_up", "sound"} end

-- Moves a grid cursor (1-based) by dx, dy inside cols x rows; wraps when wrap is true.
function F.moveCursor(cur, dx, dy, cols, rows, wrap)
  local x, y = cur.x + dx, cur.y + dy
  if wrap then
    x = (x - 1) % cols + 1
    y = (y - 1) % rows + 1
  else
    x = K.clamp(x, 1, cols)
    y = K.clamp(y, 1, rows)
  end
  if x ~= cur.x or y ~= cur.y then
    cur.x, cur.y = x, y
    K.tone(1100, 0.015, 0.07, "sine")
    return true
  end
  return false
end

local DIRV = {up = {0, -1}, down = {0, 1}, left = {-1, 0}, right = {1, 0}}
F.DIRV = DIRV

-- Common dialogs. opts = {stats = function() return lines end, onReset = fn, onNew = fn}
-- Handles scenes "stats", "reset" and "confirm". Returns true when one of them was drawn.
function F.commonDialogs(w, h, opts)
  local s = F.scene
  if s == "stats" then
    K.dialog(F.dlg, w, h, {icon = "bar_chart", title = TR("stats_title"), width = 340, lines = opts.stats(),
      buttons = {{TR("close"), F.close},
                 {TR("reset_stats"), function() F.open("reset", 2) end, "destructive"}}})
    return true
  elseif s == "reset" then
    K.dialog(F.dlg, w, h, {icon = "delete", iconColor = theme.red, title = TR("reset_stats"),
      subtitle = TR("reset_sub"),
      buttons = {{TR("reset"), function() opts.onReset(); F.close() end, "destructive"},
                 {TR("cancel"), F.close}}})
    return true
  elseif s == "confirm" then
    K.dialog(F.dlg, w, h, {icon = "refresh", title = TR("confirm_title"), subtitle = TR("confirm_sub"),
      buttons = {{TR("new_game"), function() F.close(); opts.onNew() end, "destructive"},
                 {TR("cancel"), F.close}}})
    return true
  end
  return false
end

-- Pause-free animated value helper: returns 0..1 progress of an animation that started at t0 and lasts dur.
function F.prog(t0, dur)
  if not t0 then return 1 end
  return K.clamp((sys.time() - t0) / dur, 0, 1)
end

-- Confetti-like celebration with kit particles over a rectangle.
function F.celebrate(fx, x, y, w, h)
  local cols = {theme.red, theme.orange, theme.yellow, theme.green, theme.blue, theme.purple, theme.pink}
  for i = 1, 7 do
    fx:burst(x + w * (0.15 + 0.7 * math.random()), y + h * (0.2 + 0.5 * math.random()), 14, cols[i],
             max(w, h) * 0.9, 1.1, 4, 500, 1.5)
  end
end

-- Text centered vertically in a box.
function F.ctext(s, x, y, w, h, size, font)
  gfx.text(s, x, y + (h - gfx.textHeight(size, font)) / 2, size, font, "center", w)
end

-- ------------------------------------------------------------------ title screen
-- Animated title / main menu. opts = {icon, c1, c2, title, subtitle, buttons = { {label, fn[, style[, icon]]} },
--   extra = function(x, y, w) (mode pickers), extraH, footer = "text"}
-- Uses F.dlg so K.dialogInput / F.dialogEvent drive the focus.
local floaters = nil
local function initFloaters()
  floaters = {}
  for i = 1, 18 do
    floaters[i] = {x = math.random(), y = math.random(), s = 0.6 + math.random() * 1.4, v = 0.015 + math.random() * 0.03,
                   ph = math.random() * 6.28, r = math.random() * 0.6 - 0.3}
  end
end

function F.titleScreen(w, h, opts)
  if not floaters then initFloaters() end
  local now = sys.time()
  local t = now - (F.dlg.t0 or 0)
  local c1, c2 = opts.c1 or theme.accent, opts.c2 or theme.purple
  gfx.gradient(0, 0, w, h, K.mix(theme.bg, c1, theme.dark and 0.18 or 0.12), K.mix(theme.bg, c2, theme.dark and 0.22 or 0.16))
  -- drifting glyphs
  for i, f in ipairs(floaters) do
    local y = ((f.y - now * f.v) % 1.2 - 0.1) * h
    local x = f.x * w + math.sin(now * 0.6 + f.ph) * 18
    gfx.icon(opts.icon, x, y, 22 * f.s + 10, K.col(i % 2 == 0 and c1 or c2, theme.dark and 0.16 or 0.13))
  end
  local buttons = opts.buttons or {}
  local bw = min(300, w - 48)
  local blockH = 128 + 70 + (opts.extraH or 0) + #buttons * 50
  local y = max(16, floor((h - blockH) / 2 - 10))
  -- icon tile
  local a = K.easeOutBack(t / 0.5)
  local s = 96 * a
  local bob = math.sin(now * 2) * 4
  local ix, iy = w / 2 - s / 2, y + 48 - s / 2 + bob
  if s > 4 then
    gfx.shadow(ix, iy, s, s, s * 0.24, 20, 6)
    gfx.gradient(ix, iy, s, s, c1, c2, false, s * 0.24)
    gfx.icon(opts.icon, w / 2, iy + s / 2, s * 0.56, "#FFFFFF")
  end
  y = y + 110
  local ta = K.easeOut((t - 0.15) / 0.4)
  gfx.alpha(ta)
  gfx.color(theme.text)
  gfx.text(opts.title, 0, y + (1 - ta) * 12, 34, "bold", "center", w)
  if opts.subtitle then
    gfx.color(theme.text2)
    gfx.text(opts.subtitle, 0, y + 46, 14, "medium", "center", w)
  end
  gfx.unalpha()
  y = y + 80
  if opts.extra then
    opts.extra(floor((w - bw) / 2), y, bw)
    y = y + (opts.extraH or 0)
  end
  local active = F.scene == "title"
  if active then F.dlg.sel = K.clamp(F.dlg.sel or 1, 1, max(1, #buttons)) end
  for i, b in ipairs(buttons) do
    local ba = K.easeOut((t - 0.25 - i * 0.07) / 0.35)
    local bx = floor((w - bw) / 2 + (1 - ba) * 40)
    gfx.alpha(ba)
    if active and F.dlg.sel == i then K.ring(bx - 3, y - 3, bw + 6, 46, 12) end
    if ui.button(b[1] .. "##title" .. i, bx, y, bw, 40, b[3] or (i == 1 and "primary" or "default"), b[4]) and active then
      F.dlg.sel = i
      if ba > 0.5 then K.tone(660, 0.05, 0.2, "triangle"); b[2]() end
    end
    gfx.unalpha()
    y = y + 50
  end
  if active then F.dlg.buttons = buttons end
  if opts.footer then
    gfx.color(theme.text3)
    gfx.text(opts.footer, 0, h - 54, 12, "medium", "center", w)
  end
end

-- Pause menu. opts = {onRestart = fn, onMenu = fn}
function F.pauseDialog(w, h, opts)
  K.dialog(F.dlg, w, h, {icon = "pause_circle", title = TR("paused"),
    buttons = {{TR("resume"), F.close, "primary", "play_arrow"},
               {TR("restart"), function() F.close(); opts.onRestart() end, "default", "replay"},
               {TR("stats_title"), function() F.open("stats") end, "default", "bar_chart"},
               {TR("main_menu"), function() opts.onMenu() end, "default", "home"}}})
end

-- A pleasant chord (several tones at once).
function F.chord(freqs, dur, vol, wave)
  for _, f in ipairs(freqs) do K.tone(f, dur or 0.3, (vol or 0.3) / #freqs * 1.6, wave or "triangle") end
end
-- Major arpeggio + final chord for wins, minor descent for losses.
function F.winSound()
  K.notes({523, 659, 784, 1047}, 0.08, 0.24)
  timer.after(0.34, function() F.chord({523, 659, 784, 1047}, 0.6, 0.3) end)
end
function F.loseSound()
  K.notes({392, 349, 311, 262}, 0.12, 0.22)
  timer.after(0.5, function() F.chord({196, 233, 294}, 0.6, 0.25, "sine") end)
end

return F
