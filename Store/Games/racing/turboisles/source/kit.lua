-- kit.lua: the shared layer of the Nexvyn OS flagship games, on top of nexvyn.game.
-- Settings (music and effect volume, difficulty, screen shake, rumble, tips, touch controls, key rebinding,
-- performance overlay), looping music from pre-rendered tracks, sound effects with variations, one-time tutorial
-- tips, button glyphs for the device in use, a styled menu, a help sheet and the pause menu.
--
--   local K = require("kit")
--   K.track("theme", "bundle:/music/theme.ogg", 16)      -- loop length in seconds (the file carries a reverb tail)
--   K.sound("hit", {"bundle:/sfx/hit1.wav", "bundle:/sfx/hit2.wav"}, 0.8)
--   return K.run{width = 640, height = 360, scene = Title, title = Title, accent = "#FF7A30", ...}
local game = require("nexvyn.game")
local G, I, U, A = game.gfx, game.input, game.ui, game.audio
local floor, min, max, sin, abs = math.floor, math.min, math.max, math.sin, math.abs

local K = {}

-- The engine forgets every held action when the scene changes; a controller button that is still down would then
-- count as a new press on the next step (the pause button would close the pause menu it just opened). Actions whose
-- buttons or stick directions are still held stay "held" until they are released.
local engineReset = I.reset
I.reset = function()
  engineReset()
  local lx, ly, rx, ry = I.sticks()
  for _, a in pairs(I.actions) do
    for _, p in ipairs(a.pads) do
      if input.down(p) then a.held = true break end
    end
    if not a.held then
      for _, ax in ipairs(a.axes) do
        local v
        if ax.stick == "l" then v = ax.axis == "x" and lx or ly else v = ax.axis == "x" and rx or ry end
        if v * ax.sign > 0.5 then a.held = true break end
      end
    end
  end
end

local prefs = game.save.open("prefs")
K.prefs = prefs
K.accent, K.dark, K.panel = "#3A86FF", "#0A0E1A", "#0E1426EE"

local P = {music = 0.7, sfx = 0.85, difficulty = 2, shake = true, rumble = true, hints = true, perf = false}
for k in pairs(P) do
  local v = prefs:get(k)
  if v ~= nil then P[k] = v end
end
K.P = P
function K.set(k, v) P[k] = v; prefs:set(k, v) end
A.volume = P.sfx

local DIFF = {"k_easy", "k_normal", "k_hard"}
function K.difficultyName(d) return TR(DIFF[d or P.difficulty] or "k_normal") end
-- K.pick(easy, normal, hard) -> the value for the current difficulty
function K.pick(a, b, c) local d = P.difficulty return d == 1 and a or (d == 3 and c or b) end

local function clamp(v, a, b) return v < a and a or (v > b and b or v) end
K.clamp = clamp

-- ---------------------------------------------------------------- input device and glyphs
K.device = "pad"   -- "pad" | "key" | "touch": what the player used last
local PADL = {a = "A", b = "B", x = "X", y = "Y", l = "L", r = "R", zl = "ZL", zr = "ZR", plus = "+", minus = "−",
              up = "↑", down = "↓", left = "←", right = "→", lstick = "L3", rstick = "R3"}
local KEYL = {space = "Space", enter = "Enter", escape = "Esc", backspace = "⌫", shift = "Shift", tab = "Tab",
              left = "←", right = "→", up = "↑", down = "↓"}
-- the button for an action on the device in use ("A", "Space"), or nil on touch
function K.btn(action)
  if K.device == "touch" then return nil end
  if K.device == "key" then
    local k = I.binding(action, "key")
    return k and (KEYL[k] or k:upper())
  end
  local p = I.binding(action, "pad")
  return p and (PADL[p] or p:upper())
end
-- a key cap with a label; returns its width
function K.glyph(label, x, y, size, color)
  size = size or 12
  local w = max(size * 1.5, G.textWidth(label, size * 0.82, "bold") + size * 0.8)
  G.rect(x, y, w, size * 1.4, size * 0.45, color or "#FFFFFFE6")
  G.color("#0B1020")
  G.text(label, x, y + size * 0.2, size * 0.82, "bold", "center", w)
  return w
end
-- "[A] Jump" prompt, x is the left edge; returns the width used
function K.prompt(action, text, x, y, size, color)
  size = size or 12
  local b = K.btn(action)
  local w = 0
  if b then w = K.glyph(b, x, y, size) + size * 0.4 end
  U.text(text, x + w, y + size * 0.15, size, color or "#FFFFFF", nil, nil, "semibold")
  return w + G.textWidth(text, size, "semibold")
end
function K.promptWidth(action, text, size)
  size = size or 12
  local b = K.btn(action)
  local w = G.textWidth(text, size, "semibold")
  if b then w = w + max(size * 1.5, G.textWidth(b, size * 0.82, "bold") + size * 0.8) + size * 0.4 end
  return w
end
-- a row of prompts centred on cx: {{action, text}, ...}
function K.prompts(list, cx, y, size)
  size = size or 11
  local gap, total = size * 1.4, 0
  for i, p in ipairs(list) do total = total + K.promptWidth(p[1], p[2], size) + (i > 1 and gap or 0) end
  local x = cx - total / 2
  for _, p in ipairs(list) do x = x + K.prompt(p[1], p[2], x, y, size, "#FFFFFFD0") + gap end
end

-- ---------------------------------------------------------------- music (looping tracks)
-- Tracks are played as one-shot sounds and re-started every `len` seconds, so they stop by themselves if the app
-- ever goes away; the file is a little longer than `len` so its reverb tail rings into the next pass.
local tracks, cur = {}, nil
local suspended = false
function K.track(name, path, len) tracks[name] = {path = path, len = len} end
local function stopMusic()
  if not cur then return end
  local now = sys.time()
  for i = 1, 2 do
    local c = cur.ch[i]
    if c and c >= 0 and now - (cur.at[i] or 0) < tracks[cur.name].len + 2 then audio.stop(c) end
    cur.ch[i] = nil
  end
  cur.playing = false
end
-- K.music(name): switch to a track (nil = silence); the same track keeps playing
function K.music(name)
  if cur and cur.name == name then return end
  stopMusic()
  cur = (name and tracks[name]) and {name = name, ch = {}, at = {}, slot = 1, next = 0, playing = false} or nil
end
function K.restartMusic() stopMusic() end
function K.musicName() return cur and cur.name end
local function updateMusic()
  if not cur then return end
  local vol = A.muted and 0 or P.music
  if suspended or not game.focused or vol <= 0.001 then
    if cur.playing then stopMusic() end
    return
  end
  local now = sys.time()
  if cur.playing and now < cur.next - 0.004 then return end
  if not cur.playing or now - cur.next > 0.3 then cur.next = now end
  local tr = tracks[cur.name]
  cur.slot = 3 - cur.slot
  cur.ch[cur.slot] = audio.play(tr.path, min(1, vol * 0.85), 0)
  cur.at[cur.slot] = now
  cur.next = cur.next + tr.len
  cur.playing = true
end

-- ---------------------------------------------------------------- sound effects
-- Channels of recent effects are kept, so K.stopAll() can silence everything at once (quit, window close, HOME).
local sfx, lastPlay = {}, {}
local chans, chanN = {}, 0
local function keep(ch)
  if ch and ch >= 0 then
    chanN = chanN % 40 + 1
    chans[chanN] = ch
  end
  return ch
end
-- K.play(path, vol): a one-shot sound file whose channel is tracked
function K.play(path, vol)
  if A.muted or P.sfx <= 0 then return end
  return keep(audio.play(path, min(1, vol or 1)))
end
function K.stopSounds()
  for i, c in pairs(chans) do
    audio.stop(c)
    chans[i] = nil
  end
end
function K.sound(name, files, vol, gap)
  sfx[name] = {files = type(files) == "table" and files or {files}, vol = vol or 1, gap = gap or 0.035}
end
function K.sfx(name, vol)
  if A.muted or P.sfx <= 0 then return end
  local s = sfx[name]
  if not s then return A.play(name, vol) end
  local now = sys.time()
  if now - (lastPlay[name] or -1) < s.gap then return end
  lastPlay[name] = now
  local n = #s.files
  return keep(audio.play(s.files[n == 1 and 1 or math.random(n)], min(1, s.vol * (vol or 1) * P.sfx)))
end
-- the engine's menu sounds ("select", "confirm") and effects go through K.sfx when the game defines them
local enginePlay = A.play
A.play = function(name, vol)
  if sfx[name] then return K.sfx(name, vol) end
  return enginePlay(name, vol)
end

-- ---------------------------------------------------------------- feel: shake and rumble
function K.shake(cam, amount, sec)
  if P.shake and cam then cam:shake(amount, sec or 0.25) end
end
function K.shakeScale() return P.shake and 1 or 0 end
function K.rumble(strength, ms)
  if P.rumble and sys.vibrate and K.device ~= "key" then sys.vibrate(strength or 0.5, ms or 60) end
end

-- ---------------------------------------------------------------- tutorial tips (each shown once)
local seen = prefs:get("tips", {})
if type(seen) ~= "table" then seen = {} end
local tipQ, tip = {}, nil
-- K.tip(id, text[, icon[, seconds]]): queued; shown once per save unless tips are off
function K.tip(id, text, icon, seconds)
  if not P.hints or seen[id] or (tip and tip.id == id) then return end
  for _, q in ipairs(tipQ) do if q.id == id then return end end
  tipQ[#tipQ + 1] = {id = id, text = text, icon = icon or "lightbulb", dur = seconds or 6, t = 0}
end
-- the player did it: the tip goes away and never comes back
function K.tipDone(id)
  seen[id] = true
  prefs:set("tips", seen)
  if tip and tip.id == id then tip.t = max(tip.t, tip.dur - 0.25) end
  for i = #tipQ, 1, -1 do if tipQ[i].id == id then table.remove(tipQ, i) end end
end
function K.tipSeen(id) return seen[id] == true end
function K.resetTips() seen = {}; prefs:set("tips", seen) end
function K.clearTips() tipQ = {}; tip = nil end
local function updateTips(dt)
  if not tip and #tipQ > 0 and not game.paused then tip = table.remove(tipQ, 1) end
  if tip and not game.paused then
    tip.t = tip.t + dt
    if tip.t >= tip.dur then
      seen[tip.id] = true
      prefs:set("tips", seen)
      tip = nil
    end
  end
end
local function drawTip()
  if not tip or game.paused then return end
  local a = min(1, tip.t / 0.25, (tip.dur - tip.t) / 0.3)
  local w = min(game.width - 40, G.textWidth(tip.text, 12, "semibold") + 54)
  local x, y = (game.width - w) / 2, 10 - (1 - a) * 16
  G.alpha(max(0, a))
  G.rect(x, y, w, 30, 15, "#0B1020E0")
  G.color(K.accent)
  G.rectLine(x, y, w, 30, 15, 1.2)
  G.icon(tip.icon, x + 18, y + 15, 16, K.accent)
  U.text(tip.text, x + 32, y + 8, 12, "#FFFFFF", "left", w - 40, "semibold", false)
  G.unalpha()
end

-- ---------------------------------------------------------------- performance overlay and log
K.stats = {}
function K.stat(name, value) K.stats[name] = value end
local perfT, frames, fpsShown, fpsT = 0, 0, 60, 0
local function statLine()
  local parts = {}
  for k, v in pairs(K.stats) do parts[#parts + 1] = k .. "=" .. tostring(v) end
  table.sort(parts)
  return table.concat(parts, " ")
end
local function updatePerf(dt)
  frames = frames + 1
  fpsT = fpsT + dt
  if fpsT >= 0.5 then fpsShown, frames, fpsT = floor(frames / fpsT + 0.5), 0, 0 end
  perfT = perfT + dt
  if perfT >= 20 then   -- a line in the app log every 20 s: frame rate, update and draw time, game counters
    perfT = 0
    local D = game.debugOverlay
    sys.log(string.format("perf fps=%d update=%.2fms draw=%.2fms %s", fpsShown, D.updateMs or 0, D.drawMs or 0,
      statLine()))
  end
end
local function drawPerf()
  if not P.perf then return end
  local D = game.debugOverlay
  local line = string.format("%d fps  ·  %.1f ms update  ·  %.1f ms draw", fpsShown, D.updateMs or 0, D.drawMs or 0)
  local s = statLine()
  local w = max(G.textWidth(line, 10, "mono"), G.textWidth(s, 10, "mono")) + 16
  G.rect(6, game.height - 40, w, s ~= "" and 34 or 20, 6, "#000000B0")
  G.color(fpsShown >= 55 and "#7CFF9B" or (fpsShown >= 40 and "#FFD166" or "#FF6B6B"))
  G.text(line, 14, game.height - 36, 10, "mono")
  if s ~= "" then
    G.color("#FFFFFFB0")
    G.text(s, 14, game.height - 22, 10, "mono")
  end
end

-- ---------------------------------------------------------------- menu (pad, keys, pointer)
local Menu = {}
Menu.__index = Menu
-- K.menu{items = {{label, value = fn, action, left, right, enabled, icon}}, width, itemHeight, size, onBack, accent}
function K.menu(o)
  local m = setmetatable(o, Menu)
  m.selected = m.selected or 1
  m.width, m.itemHeight, m.size = m.width or 240, m.itemHeight or 30, m.size or 14
  m.rects, m.hy = {}, nil
  m:fix(1)
  return m
end
local function enabled(it)
  if it.enabled == nil then return true end
  if type(it.enabled) == "function" then return it.enabled() end
  return it.enabled
end
function Menu:fix(dir)
  local n = #self.items
  for _ = 1, n do
    if enabled(self.items[self.selected]) then return end
    self.selected = (self.selected - 1 + dir) % n + 1
  end
end
function Menu:move(dir)
  self.selected = (self.selected - 1 + dir) % #self.items + 1
  self:fix(dir)
  K.sfx("ui_move")
end
function Menu:activate(i)
  local it = self.items[i]
  if not it or not enabled(it) then K.sfx("ui_back") return end
  self.selected = i
  K.sfx("ui_ok")
  if it.action then it.action(it, self) elseif it.right then it.right(it, self) end
end
function Menu:update()
  if I.pressed("up") then self:move(-1) end
  if I.pressed("down") then self:move(1) end
  local it = self.items[self.selected]
  if it and enabled(it) then
    if I.pressed("left") and it.left then it.left(it, self); K.sfx("ui_move") end
    if I.pressed("right") and it.right then it.right(it, self); K.sfx("ui_move") end
  end
  if I.pressed("confirm") then self:activate(self.selected) end
  if I.pressed("back") and self.onBack then K.sfx("ui_back"); self.onBack(self) end
  local p = I.pointer
  for i, r in pairs(self.rects) do
    if r.w and p.x >= r.x and p.y >= r.y and p.x < r.x + r.w and p.y < r.y + r.h then
      if p.pressed or (p.down and not p.touch) then
        if self.selected ~= i and enabled(self.items[i]) then self.selected = i end
      end
      if p.released and p.downX >= r.x and p.downY >= r.y and p.downX < r.x + r.w and p.downY < r.y + r.h then
        local it2 = self.items[i]
        if it2.value and it2.right and not it2.action then
          -- tapping the left / right third of a value row steps it down / up
          if p.x < r.x + r.w * 0.35 and it2.left then it2.left(it2, self) else it2.right(it2, self) end
          K.sfx("ui_move")
        else
          self:activate(i)
        end
      end
    end
  end
end
function Menu:draw(cx, y)
  local w, ih, size = self.width, self.itemHeight, self.size
  local x = cx - w / 2
  local acc = self.accent or K.accent
  local ty = y + (self.selected - 1) * ih
  self.hy = self.hy and (self.hy + (ty - self.hy) * 0.35) or ty
  for i, it in ipairs(self.items) do
    local r = self.rects[i] or {}
    self.rects[i] = r
    r.x, r.y, r.w, r.h = x, y + (i - 1) * ih, w, ih - 4
    G.rect(x, r.y, w, ih - 4, (ih - 4) / 2, "#FFFFFF12")
  end
  G.rect(x - 2, self.hy - 2, w + 4, ih, ih / 2, acc .. "40")
  G.rect(x, self.hy, w, ih - 4, (ih - 4) / 2, acc)
  for i, it in ipairs(self.items) do
    local r = self.rects[i]
    local sel = i == self.selected
    local on = enabled(it)
    local label = type(it.label) == "function" and it.label(it) or it.label
    local col = on and "#FFFFFF" or "#FFFFFF55"
    local cy = r.y + (ih - 4) / 2
    local lx = x + 14
    if it.icon then
      G.icon(it.icon, x + 18, cy, size * 1.15, on and "#FFFFFFE0" or "#FFFFFF55")
      lx = x + 34
    end
    if it.value then
      U.text(label, lx, cy - size * 0.62, size, col, "left", w, "semibold", false)
      local v = it.value(it)
      U.text(v, x, cy - size * 0.62, size, sel and "#FFFFFF" or "#FFFFFFB0", "right", w - (sel and 28 or 14), "bold", false)
      if sel and on then
        G.icon("chevron_right", x + w - 14, cy, size * 1.2, "#FFFFFFC0")
        G.icon("chevron_left", x + w - 32 - G.textWidth(v, size, "bold"), cy, size * 1.2, "#FFFFFFC0")
      end
    elseif it.icon then
      U.text(label, lx, cy - size * 0.62, size, col, "left", w, "semibold", false)
    else
      U.text(label, x, cy - size * 0.62, size, col, "center", w, "semibold", false)
    end
  end
  for i = #self.items + 1, #self.rects do self.rects[i] = nil end
  return #self.items * ih
end

-- a framed panel with a title
function K.frame(x, y, w, h, title, acc)
  G.rect(x + 3, y + 5, w, h, 14, "#00000060")
  G.rect(x, y, w, h, 14, K.panel)
  G.color((acc or K.accent) .. "90")
  G.rectLine(x, y, w, h, 14, 1.2)
  if title then
    U.text(title, x, y + 12, 18, "#FFFFFF", "center", w, "bold")
    G.rect(x + w / 2 - 24, y + 36, 48, 3, 1.5, acc or K.accent)
  end
end

-- ---------------------------------------------------------------- settings
local Settings = {transparent = true, pausable = false}
K.SettingsScene = Settings
local function pct(v) return floor(v * 100 + 0.5) .. "%" end
local function onOff(v) return TR(v and "k_on" or "k_off") end
local TOUCH = {"auto", "on", "off"}
function Settings:enter(p)
  p = p or {}
  self.t = 0
  local items = {}
  local function add(it) items[#items + 1] = it end
  local function vol(key, d)
    K.set(key, clamp(floor((P[key] + d) * 10 + 0.5) / 10, 0, 1))
    if key == "music" then K.restartMusic() else A.volume = P.sfx; K.sfx("ui_ok") end
  end
  add{label = TR("k_music"), icon = "music_note", value = function() return pct(P.music) end,
      left = function() vol("music", -0.1) end, right = function() vol("music", 0.1) end}
  add{label = TR("k_sfx"), icon = "volume_up", value = function() return pct(P.sfx) end,
      left = function() vol("sfx", -0.1) end, right = function() vol("sfx", 0.1) end}
  if K.cfg.difficulty ~= false then
    local function diff(d)
      if p.inGame and K.cfg.lockDifficulty then return end
      K.set("difficulty", (P.difficulty - 1 + d) % 3 + 1)
      if K.cfg.onDifficulty then K.cfg.onDifficulty(P.difficulty) end
    end
    add{label = TR("k_difficulty"), icon = "speed", value = function() return K.difficultyName() end,
        left = function() diff(-1) end, right = function() diff(1) end,
        enabled = function() return not (p.inGame and K.cfg.lockDifficulty) end}
  end
  local function toggle(key) return function() K.set(key, not P[key]); if key == "rumble" and P.rumble then K.rumble(0.6, 80) end end end
  add{label = TR("k_shake"), icon = "vibration", value = function() return onOff(P.shake) end, left = toggle("shake"), right = toggle("shake")}
  add{label = TR("k_rumble"), icon = "sports_esports", value = function() return onOff(P.rumble) end, left = toggle("rumble"), right = toggle("rumble")}
  add{label = TR("k_hints"), icon = "lightbulb", value = function() return onOff(P.hints) end,
      left = toggle("hints"), right = function() K.set("hints", not P.hints); if P.hints then K.resetTips() end end}
  for _, e in ipairs(K.cfg.settings or {}) do add(e) end
  if I.touch.config then
    local function cyc(d)
      local i = 1
      for k, v in ipairs(TOUCH) do if v == I.touch.mode then i = k end end
      i = (i - 1 + d) % 3 + 1
      I.setTouchMode(TOUCH[i])
      game.save.open("settings"):set("touch", TOUCH[i])
    end
    add{label = TR("k_touch"), icon = "touch_app", value = function()
          local m = I.touch.mode
          return TR(m == "on" and "k_on" or (m == "off" and "k_off" or "k_auto"))
        end, left = function() cyc(-1) end, right = function() cyc(1) end}
  end
  if game.config.controls and #game.config.controls > 0 then
    add{label = TR("k_controls"), icon = "gamepad", action = function() game.push(game.ControlsScene) end}
  end
  add{label = TR("k_perf"), icon = "monitor_heart", value = function() return onOff(P.perf) end, left = toggle("perf"), right = toggle("perf")}
  if p.fromTitle and K.cfg.onReset then
    add{label = TR("k_reset"), icon = "delete_forever", action = function()
      U.dialog{title = TR("k_reset"), text = TR("k_reset_q"), buttons = {TR("k_yes"), TR("k_no")}, color = "#E5484D",
               onClose = function(i)
                 if i == 1 then K.cfg.onReset(); K.resetTips(); game.toast(TR("k_reset_done")) end
               end}
    end}
  end
  add{label = TR("k_back"), icon = "arrow_back", action = function() game.pop() end}
  self.menu = K.menu{items = items, width = 330, itemHeight = 27, size = 12, onBack = function() game.pop() end}
end
function Settings:update(dt)
  self.t = self.t + dt
  if game.current() ~= Settings then return end
  self.menu:update()
end
function Settings:draw()
  G.rect(0, 0, game.width, game.height, 0, "#000000A0")
  local h = #self.menu.items * 27 + 62
  local y = (game.height - h) / 2 + (1 - min(1, self.t / 0.2)) * 20
  K.frame(game.width / 2 - 185, y, 370, h, TR("k_settings"))
  self.menu:draw(game.width / 2, y + 50)
end

-- ---------------------------------------------------------------- help sheet
-- game.push(K.HelpScene, {title = "...", rows = {{action = "jump", text = "..."}, {icon = "star", text = "..."}}})
local Help = {transparent = true, pausable = false}
K.HelpScene = Help
function Help:enter(p) self.p, self.t = p or {}, 0 end
function Help:update(dt)
  self.t = self.t + dt
  if self.t > 0.15 and (I.pressed("back") or I.pressed("confirm") or I.pointer.released) then K.sfx("ui_back"); game.pop() end
end
function Help:draw()
  G.rect(0, 0, game.width, game.height, 0, "#000000A8")
  local rows = self.p.rows or {}
  local h = #rows * 24 + 92
  local w = min(game.width - 30, 520)
  local x, y = (game.width - w) / 2, (game.height - h) / 2 + (1 - min(1, self.t / 0.2)) * 20
  K.frame(x, y, w, h, self.p.title or TR("k_help"))
  local ry = y + 52
  for _, r in ipairs(rows) do
    local gx = x + 24
    if r.action then
      local b = K.btn(r.action)
      if b then gx = gx + K.glyph(b, gx, ry, 12) + 8 end
    elseif r.key then
      gx = gx + K.glyph(r.key, gx, ry, 12) + 8
    end
    if r.icon then G.icon(r.icon, gx + 8, ry + 8, 16, K.accent); gx = gx + 22 end
    U.text(r.text, gx, ry + 1, 12, "#FFFFFFE0", "left", x + w - gx - 20, "semibold", false)
    ry = ry + 24
  end
  G.color("#FFFFFF80")
  G.text(TR("k_close_hint"), x, y + h - 26, 11, "semibold", "center", w)
end

-- ---------------------------------------------------------------- pause menu (replaces the engine's)
local Pause = game.PauseScene
function Pause:enter()
  game.paused = true
  self.t = 0
  local st = game.scene.stack()
  local below = st[#st - 1]
  local items = {{label = TR("k_resume"), icon = "play_arrow", action = function() game.resume() end}}
  if below and below.restart then
    items[#items + 1] = {label = TR("k_restart"), icon = "replay", action = function() game.resume(); below:restart() end}
  end
  if below and below.pauseItems then
    for _, it in ipairs(below:pauseItems()) do items[#items + 1] = it end
  end
  items[#items + 1] = {label = TR("k_settings"), icon = "tune", action = function() game.push(Settings, {inGame = true}) end}
  if game.config.title and not (below and below == game.config.title) then
    items[#items + 1] = {label = TR("k_menu"), icon = "home", action = function()
      game.paused = false
      if below and below.leaveToMenu then below:leaveToMenu() end
      K.go(game.config.title)
    end}
  end
  items[#items + 1] = {label = TR("k_quit"), icon = "logout", action = function() K.quit() end}
  self.menu = K.menu{items = items, width = 230, itemHeight = 30, size = 13, onBack = function() game.resume() end}
end
function Pause:draw()
  G.rect(0, 0, game.width, game.height, 0, "#00000099")
  local h = #self.menu.items * 30 + 64
  local y = (game.height - h) / 2 + (1 - min(1, (self.t or 1) / 0.18)) * 16
  K.frame(game.width / 2 - 140, y, 280, h, TR("k_paused"))
  self.menu:draw(game.width / 2, y + 52)
end
local pauseUpdate = Pause.update
function Pause:update(dt)
  self.t = (self.t or 0) + dt
  pauseUpdate(self, dt)
end

-- ---------------------------------------------------------------- scenes
-- K.go(scene[, params[, transition]]): switch with the game's transition colour
function K.go(scene, params, kind, sec)
  game.switch(scene, params, {transition = kind or "fade", fade = sec or 0.3, color = K.dark})
end

-- silence: the music, every tracked effect and any streamed song
function K.stopAll()
  stopMusic()
  K.stopSounds()
  if audio.musicStop then pcall(audio.musicStop) end
end
K.stopAudio = K.stopAll
-- quit the game: stop all sound first, then close the window
function K.quit()
  K.stopAll()
  sys.exit()
end

-- ---------------------------------------------------------------- run
-- K.run(cfg): game.run plus the kit: cfg.accent, cfg.dark, cfg.settings (extra rows), cfg.difficulty = false,
-- cfg.lockDifficulty (no change during a run), cfg.onReset (erase progress), cfg.onDifficulty(d)
function K.run(cfg)
  K.cfg = cfg
  K.accent, K.dark = cfg.accent or K.accent, cfg.dark or K.dark
  if cfg.panel then K.panel = cfg.panel end
  local userUpdate = cfg.update
  cfg.update = function(dt)
    updateMusic()
    updateTips(dt)
    updatePerf(dt)
    if userUpdate then userUpdate(dt) end
  end
  local app = game.run(cfg)
  local draw, event, load, close = app.draw, app.event, app.load, app.close
  function app.load(arg)
    load(arg)
    A.volume = P.sfx
  end
  function app.draw(w, h)
    draw(w, h)
    drawTip()
    drawPerf()
    G.reset(0, 0, 1)
  end
  function app.event(e)
    local t = e.type
    if t == "paddown" then K.device = "pad"
    elseif t == "keydown" then K.device = "key"
    elseif t == "mousedown" and e.touch then K.device = "touch" end
    return event(e)
  end
  function app.suspend() suspended = true; K.stopAll(); store.save() end
  function app.resume() suspended = false end
  function app.focus(f) if not f then stopMusic() end end
  function app.autosave() store.save() end
  function app.close()
    local r = close()
    if r ~= false then K.stopAll() end
    return r
  end
  return app
end

return K
