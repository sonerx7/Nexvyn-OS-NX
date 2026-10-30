-- Beatbox demo: a 16-step drum machine. Every drum sound is synthesised with audio.tone, no sample files.
--
-- What this file teaches:
--   1. drum synthesis from simple tones: a kick is a short high click plus a long low sine, a snare is noise plus
--      a body tone, a clap is three noise bursts in quick succession (timer.after)
--   2. a sequencer clock that does not drift: the next step time is advanced by exactly one step each time
--      (nextAt = nextAt + step) instead of being measured from "now"
--   3. swing: every second sixteenth note is played a little late
--   4. a grid of ui.hit pads, per-row mute, accents (tap cycles off -> on -> accent), presets and saving with store
--   5. visual feedback: playhead, flashing pads and decaying level bars, all sized from the window

local app = {}
local floor, min, max, sin, pi = math.floor, math.min, math.max, math.sin, math.pi

local STEPS = 16

-- ------------------------------------------------------------------ 1. the instruments
-- v is the volume 0..1 (accented steps are louder). Each function is one drum hit.
local function kick(v)
  audio.tone(160, 0.02, v * 0.7, "sine")                -- the click of the beater
  audio.tone(52, 0.24, v, "sine")                       -- the boom
end
local function snare(v)
  audio.tone(1000, 0.15, v * 0.45, "noise")             -- the wires (noise ignores the frequency)
  audio.tone(190, 0.07, v * 0.45, "triangle")           -- the drum body
end
local function clap(v)
  audio.tone(1000, 0.02, v * 0.5, "noise")
  timer.after(0.012, function() audio.tone(1000, 0.02, v * 0.5, "noise") end)
  timer.after(0.026, function() audio.tone(1000, 0.12, v * 0.35, "noise") end)
end
local function hat(v) audio.tone(1000, 0.03, v * 0.22, "noise") end
local function openHat(v) audio.tone(1000, 0.24, v * 0.18, "noise") end
local function tom(v)
  audio.tone(150, 0.025, v * 0.5, "sine")
  audio.tone(98, 0.2, v * 0.8, "sine")
end

local ROWS = {
  {key = "kick", play = kick, color = "#FF5E5B"},
  {key = "snare", play = snare, color = "#FFB84D"},
  {key = "clap", play = clap, color = "#FFE66D"},
  {key = "hat", play = hat, color = "#6BCB77"},
  {key = "open_hat", play = openHat, color = "#4D96FF"},
  {key = "tom", play = tom, color = "#B084FF"},
}

-- patterns: one string per row, "x" = hit, "X" = accent, "." = rest
local PRESETS = {
  {key = "preset_house", bpm = 124, rows = {"X...x...X...x...", "....x.......x...", "................",
                                             "..x...x...x...x.", "......x.......x.", "................"}},
  {key = "preset_break", bpm = 96, rows = {"X.........x.....", "....X.......X..x", "................",
                                            "x.x.x.x.x.x.x.x.", "..............x.", ".......x........"}},
  {key = "preset_hiphop", bpm = 88, rows = {"X......x..X.....", "....X.......X...", "....x.......x...",
                                             "x.xxx.x.x.xxx.x.", "................", "...............x"}},
  {key = "preset_bossa", bpm = 110, rows = {"X..x..x.X..x..x.", "..x..x....x..x..", "................",
                                             "xxxxxxxxxxxxxxxx", "................", "x.....x...x....."}},
}

-- ------------------------------------------------------------------ state
local grid = {}             -- grid[row][step] = 0 off, 1 on, 2 accent
local muted = {}
local bpm, swing = 120, 0.15
local playing = false
local step = 0              -- the step that sounded last (1..16), 0 before the start
local nextAt = 0            -- sys.time() of the next step
local flash = {}            -- per row 0..1, decays every frame
local preset = 1

local function loadPreset(i)
  preset = i
  local p = PRESETS[i]
  bpm = p.bpm
  for r = 1, #ROWS do
    grid[r] = {}
    local s = p.rows[r]
    for c = 1, STEPS do
      local ch = s:sub(c, c)
      grid[r][c] = ch == "X" and 2 or ch == "x" and 1 or 0
    end
  end
end

local function save()
  store.set("beat", {grid = grid, muted = muted, bpm = bpm, swing = swing, preset = preset})
end

function app.load()
  local b = store.get("beat", nil)
  loadPreset(1)
  if type(b) == "table" and type(b.grid) == "table" then
    for r = 1, #ROWS do
      for c = 1, STEPS do
        local v = b.grid[r] and b.grid[r][c]
        if type(v) == "number" then grid[r][c] = v end
      end
      if type(b.muted) == "table" then muted[r] = b.muted[r] == true end
    end
    bpm = tonumber(b.bpm) or bpm
    swing = tonumber(b.swing) or swing
    preset = tonumber(b.preset) or preset
  end
  for r = 1, #ROWS do flash[r] = 0 end
end

-- ------------------------------------------------------------------ 2. + 3. the clock
local function stepLength() return 60 / bpm / 4 end   -- a sixteenth note

local function playStep(s)
  for r, row in ipairs(ROWS) do
    local v = grid[r][s]
    if v > 0 and not muted[r] then
      row.play(v == 2 and 1 or 0.65)
      flash[r] = v == 2 and 1 or 0.7
    end
  end
end

local function start()
  playing, step = true, 0
  nextAt = sys.time()
end

function app.update(dt)
  for r = 1, #ROWS do flash[r] = max(0, flash[r] - dt * 4) end
  if not playing then return end
  local now = sys.time()
  -- after a long pause (window hidden) skip ahead instead of firing a burst of late steps
  if now - nextAt > 0.5 then nextAt = now end
  while now >= nextAt do
    step = step % STEPS + 1
    playStep(step)
    -- the even steps (the "and"s) come late by `swing` of a step; the next odd step comes early by the same,
    -- so every pair of steps still takes exactly two step lengths and the tempo never drifts
    local len = stepLength()
    if step % 2 == 1 then nextAt = nextAt + len * (1 + swing) else nextAt = nextAt + len * (1 - swing) end
  end
end

-- ------------------------------------------------------------------ input
function app.event(e)
  if e.type == "keydown" then
    if e.key == "space" then if playing then playing = false else start() end end
    local n = tonumber(e.key)
    if n and n >= 1 and n <= #ROWS then muted[n] = not muted[n]; save() end
  end
end

-- ------------------------------------------------------------------ drawing
local function pad(r, c, x, y, size)
  local v = grid[r][c]
  local hit = ui.hit("pad" .. r .. "_" .. c, x, y, size, size)
  if hit.clicked then
    grid[r][c] = (v + 1) % 3                    -- off -> on -> accent -> off
    if grid[r][c] > 0 and not playing then ROWS[r].play(grid[r][c] == 2 and 1 or 0.65); flash[r] = 0.8 end
    save()
  end
  local col = ROWS[r].color
  local beatShade = floor((c - 1) / 4) % 2 == 0 and "#2A2F45" or "#232739"
  local radius = size * 0.22
  if v == 0 then
    gfx.rect(x, y, size, size, radius, hit.hovered and "#3A4060" or beatShade)
  else
    gfx.rect(x, y, size, size, radius, col)
    if v == 1 then gfx.rect(x + size * 0.18, y + size * 0.18, size * 0.64, size * 0.64, radius * 0.6, "#00000055") end
  end
  if playing and c == step then
    gfx.color("#FFFFFF")
    gfx.rectLine(x - 1, y - 1, size + 2, size + 2, radius, 2)
  end
end

function app.draw(w, h)
  local beat = playing and (1 - ((sys.time() - nextAt) / stepLength() % 1)) or 0
  gfx.clear("#161927")
  -- a soft pulse behind everything on every kick
  if flash[1] > 0 then gfx.rect(0, 0, w, h, 0, string.format("#FF5E5B%02X", floor(flash[1] * 40))) end
  local m = 16

  -- controls
  if ui.button(playing and TR("stop") or TR("play"), m, 14, 110, 34, "primary", playing and "stop" or "play_arrow") then
    if playing then playing = false else start() end
  end
  if ui.button(TR("clear"), m + 120, 14, 90, 34, "default", "delete") then
    for r = 1, #ROWS do for c = 1, STEPS do grid[r][c] = 0 end end
    save()
  end
  local names = {}
  for i, p in ipairs(PRESETS) do names[i] = TR(p.key) end
  local np = ui.dropdown("preset", names, preset, m + 220, 14, min(170, w - m - 236), 34)
  if np ~= preset then loadPreset(np); save() end
  local sy = 60
  gfx.color("#FFFFFF")
  gfx.text(TR("tempo", floor(bpm + 0.5)), m, sy + 6, 13, "semibold")
  local half = (w - 2 * m) / 2
  local nb = ui.slider("bpm", bpm, 60, 180, m + 110, sy, half - 130, 1)
  if nb ~= bpm then bpm = nb; save() end
  gfx.color("#FFFFFF")
  gfx.text(TR("swing", floor(swing * 100 + 0.5)), m + half, sy + 6, 13, "semibold")
  local ns = ui.slider("swing", swing, 0, 0.5, m + half + 100, sy, half - 100)
  if ns ~= swing then swing = ns; save() end

  -- the grid: pad size from whatever space is left
  local top = 108
  local labelW = min(120, w * 0.18)
  local meterW = 40
  local size = min((w - 2 * m - labelW - meterW - STEPS * 4) / STEPS, (h - top - 50) / #ROWS - 6)
  size = max(16, size)
  local gap = 4
  for r, row in ipairs(ROWS) do
    local y = top + (r - 1) * (size + gap + 2)
    -- instrument name: tap to mute
    local hit = ui.hit("mute" .. r, m, y, labelW - 8, size)
    if hit.clicked then muted[r] = not muted[r]; save() end
    gfx.rect(m, y, labelW - 8, size, 8, muted[r] and "#2A2D3A" or "#262B40")
    gfx.rect(m, y, 5, size, 2, muted[r] and "#555A6E" or row.color)
    gfx.color(muted[r] and "#6E7387" or "#FFFFFF")
    gfx.text(TR(row.key), m + 12, y + size / 2 - 8, min(14, size * 0.45), "semibold")
    for c = 1, STEPS do
      pad(r, c, m + labelW + (c - 1) * (size + gap), y, size)
    end
    -- level bar: jumps up on a hit, falls back down
    local mx = m + labelW + STEPS * (size + gap) + 6
    gfx.rect(mx, y, 10, size, 5, "#00000060")
    local f = flash[r]
    if f > 0 then gfx.rect(mx, y + size * (1 - f), 10, size * f, 5, row.color) end
  end
  -- step numbers under the grid
  local ny = top + #ROWS * (size + gap + 2)
  for c = 1, STEPS do
    local x = m + labelW + (c - 1) * (size + gap)
    gfx.color(playing and c == step and "#FFFFFF" or "#FFFFFF50")
    gfx.text(tostring(c), x, ny, 11, "mono", "center", size)
  end
  gfx.color("#FFFFFF70")
  gfx.text(TR("hint"), m, h - 24, 12)
  -- beat light: shows the clock running between steps
  if playing then gfx.circle(w - m - 10, 31, 6 + beat * 4, step % 4 == 1 and "#FF5E5B" or "#FFFFFF80") end
end

function app.menu()
  return {{title = TR("menu_title"), items = {
    {label = TR("play") .. " / " .. TR("stop"), id = 1, shortcut = "Space"},
    {label = TR("clear"), id = 2},
    "-",
    {label = TR("unmute_all"), id = 3},
  }}}
end

function app.onmenu(id)
  if id == 1 then if playing then playing = false else start() end
  elseif id == 2 then for r = 1, #ROWS do for c = 1, STEPS do grid[r][c] = 0 end end
  elseif id == 3 then for r = 1, #ROWS do muted[r] = false end end
  save()
end

function app.close()
  save()
  return true
end

return app
