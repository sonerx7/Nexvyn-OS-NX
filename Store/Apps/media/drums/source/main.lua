-- Drum Machine for Nexvyn OS: 16-step sequencer, 8 synthesized drum tracks, BPM, swing, mute/volume, presets
-- and saved patterns.
local app = {}

local floor, min, max, abs = math.floor, math.min, math.max, math.abs

-- ------------------------------------------------------------------ helpers
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
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
local function alpha(c, a)
  local t = rgba(c)
  return {t[1], t[2], t[3], clamp(floor(t[4] * a + 0.5), 0, 255)}
end
local function mix(c1, c2, k)
  local a, b = rgba(c1), rgba(c2)
  return {floor(a[1] + (b[1] - a[1]) * k + 0.5), floor(a[2] + (b[2] - a[2]) * k + 0.5),
          floor(a[3] + (b[3] - a[3]) * k + 0.5), floor(a[4] + (b[4] - a[4]) * k + 0.5)}
end
local function approach(cur, target, speed, dt) return cur + (target - cur) * (1 - math.exp(-speed * dt)) end
local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
local function ellipsize(s, size, font, maxW)
  if gfx.textWidth(s, size, font) <= maxW then return s end
  while utf8.len(s) > 1 and gfx.textWidth(s .. "…", size, font) > maxW do
    s = s:sub(1, utf8.offset(s, -1) - 1)
  end
  return s .. "…"
end

local editing, pressAt, fieldHit = false, nil, false
local function field(id, text, x, y, w, h, ph, flags)
  local nt, sub = ui.textfield(id, text, x, y, w, h, ph, flags)
  if pressAt then
    local mx, my = ui.mouse()
    if mx >= x and mx <= x + w and my >= y and my <= y + h then fieldHit = true end
  end
  return nt, sub
end

-- frame-accurate scheduler for multi-part sounds
local queue = {}
local function later(dt, fn) queue[#queue + 1] = {t = sys.time() + dt, fn = fn} end
local function runQueue()
  local now = sys.time()
  local i = 1
  while i <= #queue do
    if now >= queue[i].t then
      local q = table.remove(queue, i)
      q.fn()
    else
      i = i + 1
    end
  end
end

-- ------------------------------------------------------------------ sounds
local master = 0.85
local openHatCh = -1
local NOISE = 1000   -- noise ignores pitch; one value keeps the synth cache small

local SYNTH = {
  function(v) -- kick: short pitched sine "sweep" plus a click
    audio.tone(1200, 0.01, v * 0.25, "triangle")
    audio.tone(150, 0.035, v, "sine")
    later(0.016, function() audio.tone(95, 0.05, v, "sine") end)
    later(0.033, function() audio.tone(58, 0.24, v, "sine") end)
  end,
  function(v) -- snare: noise burst + body
    audio.tone(NOISE, 0.15, v * 0.55, "noise")
    audio.tone(185, 0.07, v * 0.6, "triangle")
    later(0.016, function() audio.tone(160, 0.06, v * 0.4, "sine") end)
  end,
  function(v) -- closed hat (chokes the open hat)
    if openHatCh >= 0 then audio.stop(openHatCh); openHatCh = -1 end
    audio.tone(NOISE, 0.035, v * 0.32, "noise")
  end,
  function(v) -- open hat
    openHatCh = audio.tone(NOISE, 0.32, v * 0.28, "noise") or -1
  end,
  function(v) -- clap: three quick bursts and a tail
    audio.tone(NOISE, 0.015, v * 0.5, "noise")
    later(0.016, function() audio.tone(NOISE, 0.015, v * 0.5, "noise") end)
    later(0.033, function() audio.tone(NOISE, 0.12, v * 0.45, "noise") end)
  end,
  function(v) -- low tom
    audio.tone(135, 0.04, v * 0.9, "sine")
    later(0.016, function() audio.tone(105, 0.22, v * 0.9, "sine") end)
  end,
  function(v) -- high tom
    audio.tone(220, 0.04, v * 0.85, "sine")
    later(0.016, function() audio.tone(180, 0.18, v * 0.85, "sine") end)
  end,
  function(v) -- rim shot
    audio.tone(1700, 0.012, v * 0.45, "square")
    audio.tone(820, 0.03, v * 0.45, "triangle")
  end,
}

local TRACKS = {
  {key = "tr_kick", color = "red"}, {key = "tr_snare", color = "orange"}, {key = "tr_chat", color = "yellow"},
  {key = "tr_ohat", color = "green"}, {key = "tr_clap", color = "pink"}, {key = "tr_tomlo", color = "purple"},
  {key = "tr_tomhi", color = "blue"}, {key = "tr_rim", color = "gray"},
}
local NT, NS = 8, 16

-- ------------------------------------------------------------------ patterns
local function emptySteps()
  local s = {}
  for t = 1, NT do
    s[t] = {}
    for i = 1, NS do s[t][i] = 0 end
  end
  return s
end
local function fromList(list)
  local s = emptySteps()
  for t, steps in pairs(list) do for _, i in ipairs(steps) do s[t][i] = 1 end end
  return s
end

local PRESETS = {
  {key = "pre_rock", bpm = 110, swing = 0, steps = fromList({
    [1] = {1, 9, 11}, [2] = {5, 13}, [3] = {1, 3, 5, 7, 9, 11, 13, 15}, [4] = {15}, [6] = {14}, [7] = {16}})},
  {key = "pre_hiphop", bpm = 90, swing = 45, steps = fromList({
    [1] = {1, 8, 11, 12}, [2] = {5, 13}, [3] = {1, 3, 5, 7, 9, 11, 13, 14, 15}, [4] = {16}, [5] = {13}, [8] = {7}})},
  {key = "pre_house", bpm = 124, swing = 10, steps = fromList({
    [1] = {1, 5, 9, 13}, [3] = {2, 4, 6, 8, 10, 12, 14, 16}, [4] = {3, 7, 11, 15}, [5] = {5, 13}, [8] = {12}})},
  {key = "pre_empty", bpm = 100, swing = 0, steps = emptySteps()},
}

local pat = {bpm = 110, swing = 0, steps = emptySteps(), vol = {}, mute = {}}
for t = 1, NT do pat.vol[t] = 0.8; pat.mute[t] = false end
local saved = {}
local patSel = 1
local saveName = ""

local function copySteps(s)
  local o = emptySteps()
  for t = 1, NT do for i = 1, NS do o[t][i] = (s[t] and s[t][i] == 1) and 1 or 0 end end
  return o
end

local function saveCurrent()
  store.set("current", pat)
  store.set("patSel", patSel)
  store.set("master", master)
end

local function loadPattern(p, keepMix)
  pat.bpm = clamp(math.tointeger(p.bpm) or floor(tonumber(p.bpm) or 110), 60, 200)
  pat.swing = clamp(tonumber(p.swing) or 0, 0, 100)
  pat.steps = copySteps(p.steps or {})
  if not keepMix then
    for t = 1, NT do
      pat.vol[t] = clamp(tonumber(p.vol and p.vol[t]) or 0.8, 0, 1)
      pat.mute[t] = (p.mute and p.mute[t]) == true
    end
  end
  saveCurrent()
end

local function dropdownItems()
  local items = {}
  for i, p in ipairs(PRESETS) do items[i] = TR(p.key) end
  for _, s in ipairs(saved) do items[#items + 1] = "★ " .. s.name end
  return items
end

local function selectPattern(i)
  patSel = i
  if i <= #PRESETS then
    loadPattern(PRESETS[i], true)
  else
    local s = saved[i - #PRESETS]
    if s then loadPattern(s, false); saveName = s.name end
  end
end

local function savePattern()
  local name = trim(saveName)
  if name == "" then name = TR("pattern_n", #saved + 1) end
  local entry = {name = name, bpm = pat.bpm, swing = pat.swing, steps = copySteps(pat.steps), vol = {}, mute = {}}
  for t = 1, NT do entry.vol[t] = pat.vol[t]; entry.mute[t] = pat.mute[t] end
  local idx = nil
  for i, s in ipairs(saved) do if s.name == name then idx = i end end
  if idx then saved[idx] = entry else saved[#saved + 1] = entry; idx = #saved end
  patSel = #PRESETS + idx
  saveName = name
  store.set("saved", saved)
  saveCurrent()
  audio.play("pop", 0.5)
  sys.notify(TR("saved_title"), TR("saved_msg", name))
end

-- ------------------------------------------------------------------ transport
local playing = false
local step = 0                 -- last triggered step (1..16), 0 = none
local gridT, nextT = 0, 0
local flash = {}
for t = 1, NT do flash[t] = 0 end
local padPop = {}
local cursor = {t = 1, s = 1}
local showCursor = false

local function stepDur() return 60 / pat.bpm / 4 end
local function swingOff() return pat.swing / 100 * stepDur() / 3 end

local function trigger(t, v)
  SYNTH[t](clamp((v or pat.vol[t]) * master, 0, 1))
  flash[t] = 1
end

local function playStep(s)
  for t = 1, NT do
    if pat.steps[t][s] == 1 and not pat.mute[t] then
      trigger(t)
      padPop[t * 100 + s] = 1
    end
  end
end

local function togglePlay()
  playing = not playing
  if playing then
    step = 0
    gridT = sys.time() + 0.05
    nextT = gridT
  else
    step = 0
  end
end

-- ------------------------------------------------------------------ app
function app.load()
  local sv = store.get("saved", {})
  saved = {}
  if type(sv) == "table" then
    for _, s in ipairs(sv) do
      if type(s) == "table" and s.name then saved[#saved + 1] = s end
    end
  end
  master = clamp(tonumber(store.get("master", 0.85)) or 0.85, 0, 1)
  local cur = store.get("current", nil)
  patSel = clamp(math.tointeger(store.get("patSel", 1)) or 1, 1, #PRESETS + #saved)
  if type(cur) == "table" then loadPattern(cur, false) else loadPattern(PRESETS[1], false) end
  if patSel > #PRESETS then saveName = saved[patSel - #PRESETS].name end
end

function app.update(dt)
  runQueue()
  if playing then
    local now = sys.time()
    if now - nextT > 0.25 then gridT = now; nextT = now end
    local guard = 0
    while now >= nextT and guard < 8 do
      guard = guard + 1
      step = step % NS + 1
      playStep(step)
      gridT = gridT + stepDur()
      local ns = step % NS + 1
      nextT = gridT + ((ns % 2 == 0) and swingOff() or 0)
    end
  end
  for t = 1, NT do flash[t] = approach(flash[t], 0, 9, dt) end
  for k, v in pairs(padPop) do
    v = v - dt * 5
    if v <= 0 then padPop[k] = nil else padPop[k] = v end
  end
end

local painting = nil

function app.draw(w, h)
  gfx.clear(theme.bg)
  -- ---------------------------------------------------------------- toolbar
  gfx.rect(0, 0, w, 56, 0, theme.window)
  ui.separator(0, 56, w)
  if ui.button(playing and TR("stop") or TR("play"), 16, 11, 104, 34, playing and "destructive" or "primary", playing and "stop" or "play_arrow") then
    togglePlay()
  end
  gfx.color(theme.text3)
  gfx.text("BPM", 136, 21, 11, "semibold")
  if ui.iconButton("remove", 164, 13, 28, 30, nil, false, "bpm-") then pat.bpm = max(60, pat.bpm - 1); saveCurrent() end
  gfx.color(theme.text)
  gfx.text(tostring(pat.bpm), 192, 17, 17, "bold", "center", 44)
  if ui.iconButton("add", 236, 13, 28, 30, nil, false, "bpm+") then pat.bpm = min(200, pat.bpm + 1); saveCurrent() end
  local nb = ui.slider("bpm", pat.bpm, 60, 200, 270, 16, 120, 1)
  if floor(nb + 0.5) ~= pat.bpm then pat.bpm = floor(nb + 0.5); saveCurrent() end
  gfx.color(theme.text3)
  gfx.text(TR("swing"), 406, 21, 11, "semibold")
  local sw = gfx.textWidth(TR("swing"), 11, "semibold")
  local nsw = ui.slider("swing", pat.swing, 0, 100, 412 + sw, 16, 100, 1)
  if floor(nsw + 0.5) ~= pat.swing then pat.swing = floor(nsw + 0.5); saveCurrent() end
  gfx.color(theme.text)
  gfx.text(pat.swing .. "%", 518 + sw, 19, 13, "semibold")
  local items = dropdownItems()
  patSel = clamp(patSel, 1, #items)
  -- the pattern menu gets narrower before it runs into the swing value (narrow window, large interface scale)
  local ddW = max(120, min(242, w - 16 - (560 + sw) - 26))
  gfx.icon("library_music", w - 16 - ddW - 16, 28, 18, theme.text2)
  local np = ui.dropdown("patsel", items, patSel, w - 16 - ddW, 13, ddW, 30)
  if np ~= patSel then selectPattern(np); audio.play("click", 0.4) end

  -- ---------------------------------------------------------------- grid
  local hx, hw = 16, 232
  local gx = hx + hw + 10
  local gw = w - gx - 16
  local pitch = gw / NS
  local gy = 84
  -- rows shrink so all tracks stay above the bottom bar in a short window (large interface scale)
  local rowH = max(30, min(44, floor((h - 58 - gy) / NT)))
  local padW, padH = pitch - 6, rowH - 8

  -- step numbers + playhead
  for s = 1, NS do
    local x = gx + (s - 1) * pitch
    local on = playing and s == step
    gfx.color(on and theme.accent or ((s - 1) % 4 == 0 and theme.text2 or theme.text3))
    gfx.text(tostring(s), x, 64, 11, ((s - 1) % 4 == 0 or on) and "bold" or "sans", "center", pitch - 6)
  end
  if playing and step > 0 then
    local x = gx + (step - 1) * pitch - 2
    gfx.rect(x, gy - 4, pitch - 2, NT * rowH, 8, alpha(theme.accent, 0.10))
  end

  for t = 1, NT do
    local tr = TRACKS[t]
    local col = theme[tr.color]
    local y = gy + (t - 1) * rowH
    -- track header
    local muted = pat.mute[t]
    local hh = ui.hit("trk" .. t, hx, y, 122, rowH - 8)
    gfx.rect(hx, y, hw, rowH - 8, 8, hh.hovered and theme.hover or alpha(theme.text, 0.04))
    gfx.circle(hx + 14, y + (rowH - 8) / 2, 5 + flash[t] * 3, muted and theme.text3 or col)
    gfx.color(muted and theme.text3 or theme.text)
    gfx.text(ellipsize(TR(tr.key), 12.5, "semibold", 96), hx + 26, y + (rowH - 8) / 2 - 8, 12.5, "semibold")
    if hh.clicked then trigger(t) end
    if ui.iconButton(muted and "volume_off" or "volume_up", hx + 124, y + (rowH - 8) / 2 - min(15, (rowH - 6) / 2), 30, min(30, rowH - 6), muted and theme.red or theme.text2, muted, "m" .. t) then
      pat.mute[t] = not pat.mute[t]
      saveCurrent()
    end
    local nv = ui.slider("vol" .. t, pat.vol[t], 0, 1, hx + 158, y + (rowH - 8) / 2 - 12, hw - 164)
    if nv ~= pat.vol[t] then pat.vol[t] = nv; saveCurrent() end
  end

  -- pads: one hit area for the whole grid so a drag paints across pads
  local gh = NT * rowH
  local hit = ui.hit("grid", gx, gy, NS * pitch, gh)
  local mx, my = ui.mouse()
  local function padAt(px, py)
    local s = floor((px - gx) / pitch) + 1
    local t = floor((py - gy) / rowH) + 1
    if s >= 1 and s <= NS and t >= 1 and t <= NT then return t, s end
    return nil
  end
  if hit.pressed then
    local t, s = padAt(mx, my)
    if t then
      painting = pat.steps[t][s] == 1 and 0 or 1
      pat.steps[t][s] = painting
      if painting == 1 and not playing then trigger(t) end
      padPop[t * 100 + s] = 1
      cursor = {t = t, s = s}
      saveCurrent()
    end
  end
  if painting and hit.held then
    local t, s = padAt(mx, my)
    if t and pat.steps[t][s] ~= painting then
      pat.steps[t][s] = painting
      padPop[t * 100 + s] = 1
      saveCurrent()
    end
  elseif not hit.held then
    painting = nil
  end
  for t = 1, NT do
    local col = theme[TRACKS[t].color]
    local y = gy + (t - 1) * rowH
    for s = 1, NS do
      local x = gx + (s - 1) * pitch
      local on = pat.steps[t][s] == 1
      local pop = padPop[t * 100 + s] or 0
      local g = pop * 2
      local beat = floor((s - 1) / 4) % 2 == 0
      if on then
        local c = pat.mute[t] and alpha(col, 0.35) or col
        if playing and s == step and not pat.mute[t] then c = mix(col, "#FFFFFF", 0.35) end
        gfx.rect(x - g, y - g, padW + g * 2, padH + g * 2, 7, c)
        gfx.rect(x + 3 - g, y + 3 - g, padW - 6 + g * 2, (padH - 6) / 2, 5, alpha("#FFFFFF", 0.16))
      else
        gfx.rect(x, y, padW, padH, 7, alpha(theme.text, beat and 0.08 or 0.05))
        if playing and s == step then gfx.rect(x, y, padW, padH, 7, alpha(col, 0.12)) end
      end
      if showCursor and cursor.t == t and cursor.s == s then
        gfx.color(theme.accent)
        gfx.rectLine(x - 2, y - 2, padW + 4, padH + 4, 8, 2)
      end
    end
  end

  -- ---------------------------------------------------------------- bottom bar
  local by = h - 50
  ui.separator(0, by - 10, w)
  gfx.color(theme.text3)
  gfx.text(TR("name"), 16, by + 9, 11, "semibold")
  local lw = gfx.textWidth(TR("name"), 11, "semibold")
  local nn, sub = field("pname", saveName, 24 + lw, by + 2, 200, 30, TR("name_hint"))
  saveName = nn
  if sub then savePattern(); editing = false end
  local bx = 24 + lw + 210
  if ui.button(TR("save"), bx, by + 2, 96, 30, "default", "save") then savePattern() end
  local isSaved = patSel > #PRESETS
  if ui.button(TR("delete"), bx + 104, by + 2, 96, 30, "destructive", "delete", isSaved) then
    local idx = patSel - #PRESETS
    local name = saved[idx] and saved[idx].name or ""
    ui.alert(TR("delete_title"), TR("delete_msg", name), {TR("delete"), TR("cancel")}, function(k)
      if k == 1 and saved[idx] then
        table.remove(saved, idx)
        store.set("saved", saved)
        patSel = 1
        saveCurrent()
        audio.play("trash", 0.5)
      end
    end)
  end
  if ui.button(TR("clear"), bx + 208, by + 2, 90, 30, "default", "clear_all") then
    pat.steps = emptySteps()
    saveCurrent()
    audio.play("trash", 0.4)
  end
  gfx.icon(master > 0 and "volume_up" or "volume_off", w - 200, by + 17, 18, theme.text2)
  local nm = ui.slider("master", master, 0, 1, w - 184, by + 5, 168)
  if nm ~= master then master = nm; saveCurrent() end

  if pressAt then editing = fieldHit; pressAt = nil; fieldHit = false end
end

function app.event(e)
  if e.type == "mousedown" then pressAt = {e.x, e.y}; showCursor = false end
  if e.type ~= "keydown" then return end
  if e.key == "escape" then
    if editing then editing = false; return end
    if playing then togglePlay() end
    showCursor = false
    return
  end
  if editing then return end
  if e.key == "space" then togglePlay()
  elseif e.key == "left" then showCursor = true; cursor.s = (cursor.s - 2) % NS + 1
  elseif e.key == "right" then showCursor = true; cursor.s = cursor.s % NS + 1
  elseif e.key == "up" then showCursor = true; cursor.t = (cursor.t - 2) % NT + 1
  elseif e.key == "down" then showCursor = true; cursor.t = cursor.t % NT + 1
  elseif e.key == "enter" then
    showCursor = true
    local t, s = cursor.t, cursor.s
    pat.steps[t][s] = pat.steps[t][s] == 1 and 0 or 1
    if pat.steps[t][s] == 1 and not playing then trigger(t) end
    padPop[t * 100 + s] = 1
    saveCurrent()
  elseif e.key == "m" then pat.mute[cursor.t] = not pat.mute[cursor.t]; saveCurrent()
  else
    local n = tonumber(e.key)
    if n and n >= 1 and n <= NT then trigger(n) end
  end
end

function app.menu()
  local presets = {}
  for i, p in ipairs(PRESETS) do presets[#presets + 1] = {label = TR(p.key), id = 10 + i, checked = patSel == i} end
  return {
    {title = TR("menu_transport"), items = {
      {label = playing and TR("stop") or TR("play"), id = 1, shortcut = "Space"},
      "-",
      {label = TR("clear"), id = 2},
      {label = TR("save"), id = 3},
    }},
    {title = TR("menu_presets"), items = presets},
  }
end

function app.onmenu(id)
  if id == 1 then togglePlay()
  elseif id == 2 then pat.steps = emptySteps(); saveCurrent()
  elseif id == 3 then savePattern()
  elseif id > 10 and id <= 10 + #PRESETS then selectPattern(id - 10) end
end

function app.close()
  playing = false
  saveCurrent()
  return true
end

return app
