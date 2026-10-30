-- Rhythm: a four-lane rhythm game built with the nexvyn.game engine.
-- Notes fall toward the hit line; every note you hit plays its melody note, so the song is only complete when you
-- play it well. A bass line and a soft beat run on the song clock, which is driven by game time, so pausing freezes
-- the music and the chart together. Three built-in songs, Easy and Hard charts derived from the same melody.

local game = require("nexvyn.game")
local G, I, U, A = game.gfx, game.input, game.ui, game.audio
local floor, min, max, abs, sin, cos, pi, random = math.floor, math.min, math.max, math.abs, math.sin, math.cos,
  math.pi, math.random

local save = game.save.open("rhythm")

-- ---------------------------------------------------------------- tuning
local PERFECT, GREAT, GOOD = 0.045, 0.090, 0.135    -- timing windows in seconds (either side)
local LEAD = 2.4                                    -- seconds of count-in before the first beat
local SPEEDS = {0.75, 1, 1.25, 1.5, 1.75, 2}         -- note scroll speed multipliers
local LANE_COLORS = {"#FF5C8A", "#4FC3FF", "#FFD24F", "#6CFF8E"}
local LANE_ICONS = {"arrow_back", "arrow_downward", "arrow_upward", "arrow_forward"}
local LANE_PADS = {"Y", "B", "X", "A"}
local LANE_KEYS = {"D", "F", "J", "K"}
local LANE_ACTIONS = {"lane1", "lane2", "lane3", "lane4"}
local JUDGE_KEYS = {"perfect", "great", "good", "miss"}
local JUDGE_COLORS = {"#7CF7FF", "#7CFF9B", "#FFD86B", "#FF6B81"}
local JUDGE_SCORE = {300, 200, 100, 0}
local JUDGE_ACC = {1, 0.7, 0.4, 0}
local DIFF_KEYS = {"easy", "hard"}

-- ---------------------------------------------------------------- input
-- The lanes follow the arrow layout on both sides of the controller: D-pad left/down/up/right and the face buttons
-- Y/B/X/A sit in the same places. Shoulders ZL L R ZR, keyboard D F J K or the arrow keys, or tap a lane.
I.bind("lane1", {pad = {"left", "y", "zl"}, key = {"d", "left"}})
I.bind("lane2", {pad = {"down", "b", "l"}, key = {"f", "down"}})
I.bind("lane3", {pad = {"up", "x", "r"}, key = {"j", "up"}})
I.bind("lane4", {pad = {"right", "a", "zr"}, key = {"k", "right"}})
I.touchControls{stick = false, pause = true}

A.define("fanfare", {wave = "square", volume = 0.12, notes = "C5:0.09 E5:0.09 G5:0.09 C6:0.32"})
A.define("tick", {wave = "square", volume = 0.08, notes = {{1320, 0.03}}})

-- ---------------------------------------------------------------- songs
-- Melodies are written in eighth-note steps: "E5:2" is a quarter note, "-:1" an eighth rest.
local function bounce(roots)   -- driving octave bass: lo hi lo hi ... per bar
  local out = {}
  for _, r in ipairs(roots) do
    for _ = 1, 4 do out[#out + 1] = r[1] .. ":1 " .. r[2] .. ":1" end
  end
  return table.concat(out, " ")
end
local function synco(roots)    -- syncopated bass: lo lo hi lo - lo hi(2)
  local out = {}
  for _, r in ipairs(roots) do
    out[#out + 1] = string.format("%s:1 %s:1 %s:1 %s:1 -:1 %s:1 %s:2", r[1], r[1], r[2], r[1], r[1], r[2])
  end
  return table.concat(out, " ")
end

local ODE_A = "E5:2 E5:2 F5:2 G5:2 G5:2 F5:2 E5:2 D5:2 C5:2 C5:2 D5:2 E5:2 E5:3 D5:1 D5:4 "
local ODE_A2 = "E5:2 E5:2 F5:2 G5:2 G5:2 F5:2 E5:2 D5:2 C5:2 C5:2 D5:2 E5:2 D5:3 C5:1 C5:4 "
local ODE_B = "D5:2 D5:2 E5:2 C5:2 D5:2 E5:1 F5:1 E5:2 C5:2 D5:2 E5:1 F5:1 E5:2 D5:2 C5:2 D5:2 G4:4 "
local ODE_BA = "C3:4 E3:4 G2:4 B2:4 C3:4 E3:4 G2:4 G2:4 "
local ODE_BA2 = "C3:4 E3:4 G2:4 B2:4 C3:4 E3:4 G2:4 C3:4 "
local ODE_BB = "G2:4 B2:4 G2:4 C3:4 G2:4 B2:4 C3:4 G2:4 "

local KOR_A = "E5:2 B4:1 C5:1 D5:2 C5:1 B4:1 A4:2 A4:1 C5:1 E5:2 D5:1 C5:1 B4:3 C5:1 D5:2 E5:2 C5:2 A4:2 A4:4 "
local KOR_B = "-:1 D5:2 F5:1 A5:2 G5:1 F5:1 E5:3 C5:1 E5:2 D5:1 C5:1 B4:2 B4:1 C5:1 D5:2 E5:2 C5:2 A4:2 A4:4 "
local KOR_BASS_A = {{"E2", "E3"}, {"A2", "A3"}, {"E2", "E3"}, {"A2", "A3"}}
local KOR_BASS_B = {{"D2", "D3"}, {"C2", "C3"}, {"E2", "E3"}, {"A2", "A3"}}

local NEON = "E5:1 G5:1 A5:1 B5:1 A5:2 G5:2 E5:1 D5:1 E5:2 G5:2 E5:2 B4:1 D5:1 E5:1 G5:1 A5:2 B5:1 A5:1 " ..
             "G5:2 E5:1 D5:1 E5:4 B5:2 D6:2 B5:1 A5:1 G5:2 A5:2 G5:1 E5:1 D5:2 E5:2 " ..
             "G5:1 A5:1 B5:1 D6:1 E6:2 D6:1 B5:1 A5:2 B5:2 E5:4 "
local NEON_BASS = {{"E2", "E3"}, {"E2", "E3"}, {"C2", "C3"}, {"D2", "D3"},
                   {"G2", "G3"}, {"D2", "D3"}, {"C2", "C3"}, {"E2", "E3"}}

local SONGS = {
  {id = "ode", name = "song_ode", info = "song_ode_info", bpm = 112, wave = "triangle", color = "#4FC3FF",
   melody = ODE_A .. ODE_A2 .. ODE_B .. ODE_A2, bass = ODE_BA .. ODE_BA2 .. ODE_BB .. ODE_BA2},
  {id = "korobeiniki", name = "song_kor", info = "song_kor_info", bpm = 150, wave = "square", color = "#FF5C8A",
   melody = KOR_A .. KOR_B .. KOR_A .. KOR_B,
   bass = bounce(KOR_BASS_A) .. " " .. bounce(KOR_BASS_B) .. " " .. bounce(KOR_BASS_A) .. " " .. bounce(KOR_BASS_B)},
  {id = "neon", name = "song_neon", info = "song_neon_info", bpm = 140, wave = "square", color = "#6CFF8E",
   melody = NEON .. NEON, bass = synco(NEON_BASS) .. " " .. synco(NEON_BASS)},
}

local SEMI = {C = 0, D = 2, E = 4, F = 5, G = 7, A = 9, B = 11}
local function midi(name)
  local l, acc, oct = name:match("^([A-G])([#b]?)(%d)$")
  if not l then return nil end
  return 12 * (tonumber(oct) + 1) + SEMI[l] + (acc == "#" and 1 or (acc == "b" and -1 or 0))
end
local function hz(m) return 440 * 2 ^ ((m - 69) / 12) end

-- "E5:2 -:1 D5" -> {{step, midi, len}, ...}, total steps
local function parse(str)
  local out, t = {}, 0
  for tok in str:gmatch("%S+") do
    local name, len = tok:match("^([^:]+):?(%d*)$")
    len = tonumber(len) or 1
    if name and name ~= "-" then
      local m = midi(name)
      if m then out[#out + 1] = {t, m, len} end
    end
    t = t + len
  end
  return out, t
end

-- charts[song][diff] = {notes = {{t, lane, f, d}}, auto = {{t, f, d}}, bass = {{t, f, d}}, endT, count}
-- Built once at start-up: Hard uses every melody note, Easy keeps the notes on the half-note grid (and long notes on
-- beats) at least a quarter apart; the left-out melody notes then play by themselves, softly.
local charts = {}
local function buildCharts()
  for si, s in ipairs(SONGS) do
    local mel, total = parse(s.melody)
    local bass = parse(s.bass)
    local step = 60 / s.bpm / 2
    s.step, s.beat, s.length = step, step * 2, total * step
    -- lanes by pitch rank: low notes left, high notes right
    local seen, pitches = {}, {}
    for _, n in ipairs(mel) do if not seen[n[2]] then seen[n[2]] = true; pitches[#pitches + 1] = n[2] end end
    table.sort(pitches)
    local rank = {}
    for i, m in ipairs(pitches) do rank[m] = min(4, floor((i - 1) * 4 / #pitches) + 1) end
    local bassEv = {}
    for _, b in ipairs(bass) do bassEv[#bassEv + 1] = {b[1] * step, hz(b[2]), min(1.2, b[3] * step * 0.92)} end
    charts[si] = {}
    for d = 1, 2 do
      local notes, auto, last = {}, {}, -99
      for _, n in ipairs(mel) do
        local st, m, len = n[1], n[2], n[3]
        local keep = d == 2 or ((st % 4 == 0 or (st % 2 == 0 and len >= 3)) and st - last >= 2)
        local t, f, dur = st * step, hz(m), min(1.0, len * step * 0.95)
        if keep then
          notes[#notes + 1] = {t, rank[m], f, dur}
          last = st
        else
          auto[#auto + 1] = {t, f, dur}
        end
      end
      charts[si][d] = {notes = notes, auto = auto, bass = bassEv, endT = total * step + 1.6, count = #notes}
    end
  end
end
buildCharts()

local function gradeOf(acc)
  if acc >= 95 then return "S" elseif acc >= 88 then return "A" elseif acc >= 78 then return "B"
  elseif acc >= 65 then return "C" end
  return "D"
end
local GRADE_COLORS = {S = "#FFE45C", A = "#6CFF8E", B = "#4FC3FF", C = "#C59BFF", D = "#FF6B81"}

local function recordKey(si, d) return SONGS[si].id .. "_" .. DIFF_KEYS[d] end
local function speedIndex()
  local i = save:get("speed", 2)
  if type(i) ~= "number" or not SPEEDS[i] then i = 2 end
  return i
end

local function inside(px, py, x, y, w, h) return px >= x and py >= y and px < x + w and py < y + h end

-- a short major chord: several tones at once (layered sound)
local function chord(root, len, vol)
  A.tone(root, len, vol, "triangle")
  A.tone(root * 1.26, len, vol * 0.8, "triangle")
  A.tone(root * 1.5, len, vol * 0.7, "triangle")
end

-- ---------------------------------------------------------------- shared background
local bgNotes = {}
for i = 1, 18 do bgNotes[i] = {lane = random(4), y = random() * 300, v = 40 + random() * 70, w = 0.6 + random() * 0.4} end

local function drawBackdrop(t, pulse)
  local W, H = game.width, game.height
  G.gradient(0, 0, W, H, "#120A2A", "#2A0E43")
  -- soft rings that breathe with the beat
  for i = 1, 3 do
    local r = (H * 0.25 + i * 38) * (1 + pulse * 0.05)
    gfx.color(140, 90, 255, floor(18 + pulse * 22) - i * 4)
    G.circleLine(W / 2, H * 0.48, r, 2)
  end
  -- floor grid in perspective
  gfx.color(120, 80, 255, 40)
  local hy = H * 0.72
  for i = 0, 6 do
    local k = ((i + (t * 0.8) % 1) / 6)
    local y = hy + (H - hy) * k * k
    G.line(0, y, W, y, 1)
  end
  for i = -6, 6 do G.line(W / 2 + i * 20, hy, W / 2 + i * 90, H, 1) end
end

-- ---------------------------------------------------------------- scenes
local Title = {pausable = false}
local Select = {pausable = false}
local Play = {controls = true, background = "#120A2A"}
local Results = {pausable = false}

local TITLE_SONG = {bpm = 140, div = 2, wave = "triangle", volume = 0.035, notes = NEON, bass = synco(NEON_BASS)}
local menuMusic = false    -- the menu tune keeps playing between the title and song select
local function startMenuMusic()
  if not menuMusic then A.song(TITLE_SONG); menuMusic = true end
end
local function stopMenuMusic() A.stopSong(); menuMusic = false end

-- title ---------------------------------------------------------------------------------------------
function Title:enter()
  self.t = 0
  self.logo = {s = 0.6, a = 0}
  game.tween.to(self.logo, 0.8, {s = 1, a = 1}, "outBack")
  self.menu = U.menu{width = 200, items = {
    {label = function() return TR("play") end, action = function() game.switch(Select) end},
    {label = function() return TR("speed", string.format("%.2fx", SPEEDS[speedIndex()])) end,
     action = function() self:speed(1) end, left = function() self:speed(-1) end, right = function() self:speed(1) end},
    {label = function() return TR("sound", A.muted and TR("off") or TR("on")) end,
     action = function() A.setMuted(not A.muted); game.save.open("settings"):set("muted", A.muted) end,
     left = function() A.setMuted(not A.muted); game.save.open("settings"):set("muted", A.muted) end,
     right = function() A.setMuted(not A.muted); game.save.open("settings"):set("muted", A.muted) end},
    {label = function() return TR("quit") end, action = function() sys.exit() end},
  }}
  startMenuMusic()
end
function Title:speed(dir)
  local i = speedIndex() + dir
  if i < 1 then i = #SPEEDS elseif i > #SPEEDS then i = 1 end
  save:set("speed", i)
end
function Title:update(dt)
  self.t = self.t + dt
  for _, n in ipairs(bgNotes) do
    n.y = n.y + n.v * dt
    if n.y > game.height + 20 then n.y = -20 - random() * 60; n.lane = random(4) end
  end
  self.menu:update()
end
function Title:draw()
  local beat = 60 / 140
  local pulse = (1 - (self.t % beat) / beat) ^ 3
  drawBackdrop(self.t, pulse)
  local W, H = game.width, game.height
  local lw = 46
  local x0 = (W - lw * 4) / 2
  gfx.color(0, 0, 0, 70)
  G.rect(x0, 0, lw * 4, H, 0)
  for _, n in ipairs(bgNotes) do
    local x = x0 + (n.lane - 1) * lw + 5
    gfx.color(LANE_COLORS[n.lane])
    G.alpha(0.35 * n.w)
    G.rect(x, n.y, lw - 10, 10, 5)
    G.unalpha()
  end
end
function Title:ui()
  local W, H = game.width, game.height
  local L = self.logo
  local beat = 60 / 140
  local pulse = (1 - (self.t % beat) / beat) ^ 3
  local size = 42 * L.s * (1 + pulse * 0.04)
  G.alpha(L.a)
  U.text(TR("logo"), 0, H * 0.1 + (42 - size) / 2, size, "#FFFFFF", "center", W, "bold", "#7A2CFF")
  G.unalpha()
  U.text(TR("tagline"), 0, H * 0.1 + 50, 11, "#D9C8FFD0", "center", W, "semibold")
  self.menu:draw(W / 2, H * 0.1 + 74)
  local cs = TR("hint_title")
  local sz = min(9, 9 * (W - 16) / max(1, G.textWidth(cs, 9, "semibold")))
  U.text(cs, 0, H - 8 - sz * 1.3, sz, "#FFFFFFB0", "center", W, "semibold")
end

-- song select ---------------------------------------------------------------------------------------
function Select:enter(p)
  self.sel = (p and p.song) or save:get("lastSong", 1)
  if type(self.sel) ~= "number" or not SONGS[self.sel] then self.sel = 1 end
  self.diff = (p and p.diff) or save:get("lastDiff", 1)
  if self.diff ~= 1 and self.diff ~= 2 then self.diff = 1 end
  self.t = 0
  self.hl = {y = 0}
  self.slide = {x = 30, a = 0}
  game.tween.to(self.slide, 0.4, {x = 0, a = 1}, "outCubic")
  startMenuMusic()
end
function Select:layout()
  local W, H = game.width, game.height
  local cw = min(380, W - 32)
  local x = (W - cw) / 2
  local ch, gap = 46, 7
  local top = 44
  return x, top, cw, ch, gap
end
function Select:move(d)
  self.sel = (self.sel - 1 + d) % #SONGS + 1
  A.play("select")
end
function Select:setDiff(d)
  if d ~= self.diff then self.diff = d; A.play("select") end
end
function Select:start()
  save:set("lastSong", self.sel)
  save:set("lastDiff", self.diff)
  A.play("confirm")
  game.switch(Play, {song = self.sel, diff = self.diff}, {fade = 0.4})
end
function Select:update(dt)
  self.t = self.t + dt
  if I.pressed("up") then self:move(-1) end
  if I.pressed("down") then self:move(1) end
  if I.pressed("left") then self:setDiff(1) end
  if I.pressed("right") then self:setDiff(2) end
  if I.pressed("confirm") then self:start(); return end
  if I.pressed("back") then game.switch(Title); return end
  local x, top, cw, ch, gap = self:layout()
  local p = I.pointer
  if p.released then
    for i = 1, #SONGS do
      local y = top + (i - 1) * (ch + gap)
      if inside(p.x, p.y, x, y, cw, ch) and inside(p.downX, p.downY, x, y, cw, ch) then
        if self.sel == i then self:start(); return end
        self.sel = i
        A.play("select")
      end
    end
  end
  local target = (self.sel - 1) * (ch + gap)
  self.hl.y = self.hl.y + (target - self.hl.y) * game.smooth(0.25, dt)
end
function Select:draw()
  local beat = 60 / 140
  drawBackdrop(self.t, (1 - (self.t % beat) / beat) ^ 3)
end
function Select:ui()
  local W, H = game.width, game.height
  local x, top, cw, ch, gap = self:layout()
  x = x + self.slide.x
  G.alpha(self.slide.a)
  U.text(TR("choose_song"), 0, 14, 17, "#FFFFFF", "center", W)
  -- highlight that glides between the cards
  local s = SONGS[self.sel]
  G.rect(x - 3, top + self.hl.y - 3, cw + 6, ch + 6, 12, s.color)
  for i, song in ipairs(SONGS) do
    local y = top + (i - 1) * (ch + gap)
    G.rect(x, y, cw, ch, 10, i == self.sel and "#1C1238" or "#1C1238D8")
    G.rect(x + 8, y + 9, 4, ch - 18, 2, song.color)
    U.text(TR(song.name), x + 20, y + 7, 14, "#FFFFFF", nil, nil, "bold")
    U.text(TR(song.info, song.bpm), x + 20, y + 26, 9, "#CBBEF0", nil, nil, "semibold", false)
    -- best score and grade for each difficulty
    for d = 1, 2 do
      local key = recordKey(i, d)
      local best = save:get("best_" .. key, nil)
      local bx = x + cw - 128 + (d - 1) * 62
      G.rect(bx, y + 8, 58, ch - 16, 7, d == self.diff and "#FFFFFF1E" or "#00000040")
      U.text(TR(DIFF_KEYS[d]), bx, y + 10, 8, "#FFFFFFA0", "center", 58, "semibold", false)
      if best then
        local gr = save:get("grade_" .. key, "D")
        U.text(tostring(gr), bx + 4, y + 21, 13, GRADE_COLORS[gr] or "#FFFFFF", nil, nil, "bold", false)
        U.text(tostring(best), bx + 18, y + 24, 9, "#FFFFFF", "right", 36, "semibold", false)
      else
        U.text("-", bx, y + 21, 12, "#FFFFFF60", "center", 58, "bold", false)
      end
    end
  end
  local by = top + #SONGS * (ch + gap) + 4
  local bw = 86
  if U.button(TR("easy"), W / 2 - bw - 50, by, bw, 26, self.diff == 1, "#2FA86A") then self:setDiff(1) end
  if U.button(TR("hard"), W / 2 - 50 + 6, by, bw, 26, self.diff == 2, "#D8436E") then self:setDiff(2) end
  if U.button(TR("start"), W / 2 + 50 + 4, by, bw + 10, 26, true, s.color == "#6CFF8E" and "#2FA86A" or "#7A2CFF") then
    self:start()
  end
  local ch2 = charts[self.sel][self.diff]
  U.text(TR("notes_count", ch2.count, string.format("%d:%02d", floor(s.length / 60), floor(s.length % 60))),
         0, by + 32, 9, "#FFFFFFB0", "center", W, "semibold")
  local cs = TR("hint_select")
  local sz = min(9, 9 * (W - 16) / max(1, G.textWidth(cs, 9, "semibold")))
  U.text(cs, 0, H - 8 - sz * 1.3, sz, "#FFFFFFB0", "center", W, "semibold")
  G.unalpha()
end

-- play ----------------------------------------------------------------------------------------------
local POPS = 12
function Play:enter(p)
  self.si = (p and p.song) or 1
  if not SONGS[self.si] then self.si = 1 end
  self.diff = (p and p.diff) == 2 and 2 or 1
  stopMenuMusic()
  -- particle pools, one per lane colour, allocated once per visit
  self.sparks = {}
  for l = 1, 4 do
    self.sparks[l] = game.emitter{max = 120, life = {0.25, 0.55}, speed = {70, 220}, angle = -pi / 2, spread = pi * 1.1,
      gravity = 380, size = {3.5, 0}, damping = 1.5, colors = {"#FFFFFF", LANE_COLORS[l], LANE_COLORS[l] .. "00"},
      shape = "square"}
  end
  self.pops = {}
  for i = 1, POPS do self.pops[i] = {t = 0, text = "", x = 0, y = 0, color = "#FFFFFF"} end
  self:start()
end

function Play:start()
  local s = SONGS[self.si]
  local ch = charts[self.si][self.diff]
  self.song, self.chart = s, ch
  self.notes = {}
  for i, n in ipairs(ch.notes) do self.notes[i] = {t = n[1], lane = n[2], f = n[3], d = n[4], j = nil} end
  self.clock = -LEAD
  self.first, self.ai, self.bi = 1, 1, 1
  self.beatN = -floor(LEAD / s.beat)
  self.score, self.combo, self.maxCombo, self.accSum = 0, 0, 0, 0
  self.counts = {0, 0, 0, 0}
  self.hold, self.done, self.shake = 0, false, 0
  self.flash = {0, 0, 0, 0}
  self.bump = {0, 0, 0, 0}
  self.judge = {k = 0, t = 0, s = 1}
  self.comboPop = 0
  self.speed = SPEEDS[speedIndex()]
  for i = 1, POPS do self.pops[i].t = 0 end
  for l = 1, 4 do self.sparks[l]:clear() end
end
function Play:restart() self:start() end

-- the engine calls resume() when the pause menu closes: a short count-down before the song continues
function Play:resume()
  if not self.done then self.hold = 1.5 end
end

function Play:layout()
  local W, H = game.width, game.height
  local lw = min(60, (W - 40) / 4)
  local x0 = (W - lw * 4) / 2
  local hitY = H - 54
  local pxs = hitY * 0.72 * self.speed       -- scroll speed: virtual units per second
  return lw, x0, hitY, pxs
end

function Play:pop(text, x, y, color)
  local best, bt = self.pops[1], 99
  for i = 1, POPS do
    local p = self.pops[i]
    if p.t <= 0 then best = p; break end
    if p.t < bt then best, bt = p, p.t end
  end
  best.text, best.x, best.y, best.color, best.t = text, x, y, color, 0.7
end

function Play:hit(n, err)
  local e = abs(err)
  local k = e <= PERFECT and 1 or (e <= GREAT and 2 or 3)
  n.j = k
  self.counts[k] = self.counts[k] + 1
  self.accSum = self.accSum + JUDGE_ACC[k]
  self.combo = self.combo + 1
  self.maxCombo = max(self.maxCombo, self.combo)
  local mult = 1 + floor(min(self.combo, 40) / 10) * 0.25
  local gain = floor(JUDGE_SCORE[k] * mult)
  self.score = self.score + gain
  self.judge.k, self.judge.t, self.judge.s = k, 0.6, 1.35
  game.tween.to(self.judge, 0.18, {s = 1}, "outBack")
  -- the melody note itself, with a soft octave on top for a perfect
  local s = self.song
  A.tone(n.f, n.d, 0.2, s.wave == "square" and "square" or "triangle")
  A.tone(n.f, n.d, 0.12, "sine")
  if k == 1 then A.tone(n.f * 2, n.d * 0.5, 0.05, "sine") end
  local lw, x0, hitY = self:layout()
  local cx = x0 + (n.lane - 0.5) * lw
  self.sparks[n.lane]:emit(k == 1 and 16 or 9, cx, hitY)
  self.bump[n.lane] = 1
  self:pop("+" .. gain, cx, hitY - 26, JUDGE_COLORS[k])
  if self.combo > 0 and self.combo % 25 == 0 then
    chord(hz(72), 0.35, 0.08)
    self.comboPop = 1
    self.shake = max(self.shake, 2)
  end
end

function Play:miss(n)
  n.j = 4
  self.counts[4] = self.counts[4] + 1
  if self.combo >= 10 then A.tone(98, 0.25, 0.18, "saw") end
  self.combo = 0
  self.judge.k, self.judge.t, self.judge.s = 4, 0.6, 1.2
  game.tween.to(self.judge, 0.2, {s = 1}, "outQuad")
  A.tone(140, 0.08, 0.12, "noise")
  self.shake = max(self.shake, 3)
end

function Play:press(l)
  self.flash[l] = 1
  local c = self.clock
  local notes = self.notes
  for i = self.first, #notes do
    local n = notes[i]
    if n.t > c + GOOD then break end
    if not n.j and n.lane == l and abs(n.t - c) <= GOOD then
      self:hit(n, n.t - c)
      return
    end
  end
end

function Play:laneAt(px)
  local lw, x0 = self:layout()
  local l = floor((px - x0) / lw) + 1
  -- taps beside the lanes count for the nearest lane
  if l < 1 then l = 1 elseif l > 4 then l = 4 end
  return l
end

function Play:finish()
  self.done = true
  local total = #self.notes
  local acc = total > 0 and self.accSum / total * 100 or 0
  local grade = gradeOf(acc)
  local key = recordKey(self.si, self.diff)
  local record = save:best("best_" .. key, self.score)
  if record then save:set("grade_" .. key, grade) end
  save:best("acc_" .. key, floor(acc * 10 + 0.5) / 10)
  local data = {song = self.si, diff = self.diff, score = self.score, acc = acc, grade = grade, record = record,
                counts = {self.counts[1], self.counts[2], self.counts[3], self.counts[4]},
                maxCombo = self.maxCombo, total = total, full = self.counts[4] == 0 and total > 0}
  game.tween.after(1.2, function() game.switch(Results, data, {fade = 0.5, color = "#120A2A"}) end)
end

function Play:update(dt)
  -- effects keep running during the count-down
  for l = 1, 4 do
    self.flash[l] = max(0, self.flash[l] - dt * 6)
    self.bump[l] = max(0, self.bump[l] - dt * 7)
    self.sparks[l]:update(dt)
  end
  for i = 1, POPS do local p = self.pops[i]; if p.t > 0 then p.t = p.t - dt; p.y = p.y - dt * 40 end end
  self.judge.t = max(0, self.judge.t - dt)
  self.comboPop = max(0, self.comboPop - dt * 2)
  self.shake = max(0, self.shake - dt * 14)
  if self.done then return end
  if self.hold > 0 then
    local before = math.ceil(self.hold)
    self.hold = self.hold - dt
    if math.ceil(self.hold) ~= before and self.hold > 0 then A.play("tick") end
    return
  end
  self.clock = self.clock + dt
  local c, s, ch = self.clock, self.song, self.chart
  -- accompaniment on the song clock: bass, beat, and the melody notes Easy leaves out
  local bass = ch.bass
  while self.bi <= #bass and bass[self.bi][1] <= c do
    local b = bass[self.bi]
    A.tone(b[2], b[3], 0.15, "triangle")
    self.bi = self.bi + 1
  end
  while self.beatN * s.beat <= c and self.beatN * s.beat < s.length do
    local k = self.beatN
    if k >= 0 and k % 2 == 0 then A.tone(58, 0.1, 0.38, "sine") end
    A.tone(9000, 0.025, k < 0 and 0.06 or 0.035, "noise")
    self.beatN = k + 1
  end
  local auto = ch.auto
  while self.ai <= #auto and auto[self.ai][1] <= c do
    local n = auto[self.ai]
    A.tone(n[2], n[3], 0.07, "triangle")
    self.ai = self.ai + 1
  end
  -- input
  for l = 1, 4 do if I.pressed(LANE_ACTIONS[l]) then self:press(l) end end
  local p = I.pointer
  if p.pressed then self:press(self:laneAt(p.x)) end
  -- notes that passed the window are misses
  local notes, i = self.notes, self.first
  while i <= #notes do
    local n = notes[i]
    if n.j then i = i + 1
    elseif c - n.t > GOOD then self:miss(n); i = i + 1
    else break end
  end
  self.first = i
  if c >= ch.endT then self:finish() end
end

function Play:draw()
  local W, H = game.width, game.height
  local s = self.song
  local lw, x0, hitY, pxs = self:layout()
  local c = self.clock
  local ph = (c / s.beat) % 1
  local pulse = c >= 0 and (1 - ph) ^ 3 or 0
  local sx, sy = 0, 0
  if self.shake > 0 then sx, sy = (random() - 0.5) * self.shake, (random() - 0.5) * self.shake end
  G.push(sx, sy)
  drawBackdrop(c, pulse)
  -- equalizer bars beside the lanes, driven by the beat and lane flashes
  for side = 0, 1 do
    for b = 1, 7 do
      local l = (b + side) % 4 + 1
      local hgt = 10 + (pulse * 0.6 + self.flash[l] * 0.8) * (24 + ((b * 37) % 30))
      local bx = side == 0 and (x0 - 16 - b * 12) or (x0 + lw * 4 + 6 + b * 12)
      if bx > 0 and bx < W - 8 then
        gfx.color(LANE_COLORS[l])
        G.alpha(0.35)
        G.rect(bx, hitY - hgt, 8, hgt, 3)
        G.unalpha()
      end
    end
  end
  -- lanes
  gfx.color(8, 4, 20, 200)
  G.rect(x0 - 4, 0, lw * 4 + 8, H, 0)
  for l = 1, 4 do
    local lx = x0 + (l - 1) * lw
    if self.flash[l] > 0 then
      local r, g, b = game.rgba(LANE_COLORS[l])
      gfx.color(r, g, b, floor(70 * self.flash[l]))
      G.rect(lx + 1, hitY - 110, lw - 2, 110, 0)
    end
    if l > 1 then gfx.color(255, 255, 255, 22); G.line(lx, 0, lx, H, 1) end
  end
  -- beat lines scrolling with the notes (bars brighter)
  local k = math.ceil((c - 0.2) / s.beat)
  for _ = 1, 40 do
    local y = hitY - (k * s.beat - c) * pxs
    if y < -4 then break end
    if y < H then
      gfx.color(255, 255, 255, k % 4 == 0 and 40 or 16)
      G.line(x0, y, x0 + lw * 4, y, 1)
    end
    k = k + 1
  end
  -- notes
  local notes = self.notes
  for i = self.first, #notes do
    local n = notes[i]
    local y = hitY - (n.t - c) * pxs
    if y < -20 then break end
    if not n.j and y < H + 20 then
      local nx = x0 + (n.lane - 1) * lw + 4
      gfx.color(LANE_COLORS[n.lane])
      G.rect(nx, y - 7, lw - 8, 14, 7)
      gfx.color(255, 255, 255, 170)
      G.rect(nx + 5, y - 4, lw - 18, 3, 1.5)
    end
  end
  -- hit line and receptors
  gfx.color(255, 255, 255, 110 + floor(pulse * 80))
  G.rect(x0, hitY - 1, lw * 4, 2, 1)
  for l = 1, 4 do
    local cx = x0 + (l - 0.5) * lw
    local sz = (lw - 12) * (1 + self.bump[l] * 0.12)
    local r, g, b = game.rgba(LANE_COLORS[l])
    gfx.color(r, g, b, 60 + floor(self.flash[l] * 150))
    G.rect(cx - sz / 2, hitY - 13, sz, 26, 9)
    gfx.color(r, g, b, 220)
    G.rectLine(cx - sz / 2, hitY - 13, sz, 26, 9, 2)
    G.icon(LANE_ICONS[l], cx, hitY, 16, self.flash[l] > 0.3 and "#FFFFFF" or LANE_COLORS[l])
    -- control hints under each lane: controller button and keyboard key
    gfx.color(255, 255, 255, 150)
    G.text(LANE_PADS[l] .. "  " .. LANE_KEYS[l], cx - lw / 2, hitY + 20, 9, "semibold", "center", lw)
  end
  for l = 1, 4 do self.sparks[l]:draw() end
  G.pop()
end

function Play:ui()
  local W, H = game.width, game.height
  local s = self.song
  local lw, x0, hitY = self:layout()
  local total = #self.notes
  local judged = self.counts[1] + self.counts[2] + self.counts[3] + self.counts[4]
  local acc = judged > 0 and self.accSum / judged * 100 or 100
  -- song progress along the top edge
  U.bar(0, 0, W, 3, max(0, self.clock) / max(0.1, s.length), s.color, "#FFFFFF20")
  U.score(self.score, 10, 10, 2, "#FFFFFF", 7)
  U.text(TR(s.name) .. " · " .. TR(DIFF_KEYS[self.diff]), 10, 24, 9, "#D9C8FFC0", nil, nil, "semibold")
  local right = W - 10 - (I.touchVisible() and 40 or 0)
  U.text(string.format("%.1f%%", acc), right - 80, 8, 14, "#FFFFFF", "right", 80, "bold")
  U.text(TR("notes_left", total - judged), right - 120, 26, 9, "#D9C8FFC0", "right", 120, "semibold")
  -- combo and multiplier
  if self.combo >= 3 then
    local cs = 26 * (1 + self.comboPop * 0.35)
    U.text(tostring(self.combo), 0, H * 0.28 - cs / 2, cs, "#FFFFFF", "center", W, "bold")
    U.text(TR("combo"), 0, H * 0.28 + cs / 2 - 2, 9, "#D9C8FFD0", "center", W, "semibold")
    local mult = 1 + floor(min(self.combo, 40) / 10) * 0.25
    if mult > 1 then U.text("x" .. string.format("%.2f", mult), 0, H * 0.28 + cs / 2 + 10, 9, "#FFE45C", "center", W) end
  end
  -- judgement
  local j = self.judge
  if j.t > 0 and j.k > 0 then
    G.alpha(min(1, j.t * 3))
    local sz = 18 * j.s
    U.text(TR(JUDGE_KEYS[j.k]), 0, hitY - 92 - sz / 2, sz, JUDGE_COLORS[j.k], "center", W, "bold")
    G.unalpha()
  end
  -- floating score popups
  for i = 1, POPS do
    local p = self.pops[i]
    if p.t > 0 then
      G.alpha(min(1, p.t * 2.5))
      U.text(p.text, p.x - 30, p.y, 10, p.color, "center", 60, "bold")
      G.unalpha()
    end
  end
  -- count-in / resume count-down
  if self.hold > 0 then
    U.text(tostring(math.ceil(self.hold)), 0, H * 0.42, 40, "#FFFFFF", "center", W, "bold")
  elseif self.clock < -0.3 then
    local a = min(1, (-self.clock - 0.3) * 2)
    G.alpha(a)
    U.text(TR("ready"), 0, H * 0.42, 26, "#FFFFFF", "center", W, "bold")
    U.text(TR("hint_play"), 0, H * 0.42 + 34, 10, "#D9C8FFD0", "center", W, "semibold")
    G.unalpha()
  elseif self.clock < 0.5 and self.clock >= 0 then
    G.alpha(1 - self.clock * 2)
    U.text(TR("go"), 0, H * 0.42, 30, "#6CFF8E", "center", W, "bold")
    G.unalpha()
  end
  if self.done then
    U.text(self.counts[4] == 0 and TR("full_combo") or TR("cleared"), 0, H * 0.42, 26,
           self.counts[4] == 0 and "#FFE45C" or "#FFFFFF", "center", W, "bold")
  end
end

-- results -------------------------------------------------------------------------------------------
function Results:enter(p)
  self.p = p
  self.t = 0
  self.shown = {score = 0, acc = 0}
  self.gradeFx = {s = 3, a = 0}
  game.tween.to(self.shown, 1.2, {score = p.score, acc = p.acc}, "outCubic")
  game.tween.to(self.gradeFx, 0.6, {s = 1, a = 1}, {ease = "outBack", delay = 0.9,
    onComplete = function() A.play(p.record and "fanfare" or "confirm"); self.shake = 4 end})
  self.shake = 0
  self.confetti = game.emitter{max = 260, life = {1.6, 2.8}, speed = {60, 200}, angle = pi / 2, spread = 1.2,
    gravity = 90, damping = 0.6, size = {5, 3}, sizeVar = 0.5, shape = "square",
    colors = {"#FF5C8A", "#FFD24F", "#6CFF8E", "#4FC3FF", "#C59BFF00"}}
  if p.record then
    game.tween.after(1.0, function() chord(hz(72), 0.6, 0.09); chord(hz(79), 0.8, 0.06) end)
  end
  self.menu = U.menu{width = 170, itemHeight = 27, size = 12, items = {
    {label = function() return TR("retry") end,
     action = function() game.switch(Play, {song = p.song, diff = p.diff}, {fade = 0.4}) end},
    {label = function() return TR("song_select") end, action = function() game.switch(Select, {song = p.song, diff = p.diff}) end},
    {label = function() return TR("main_menu") end, action = function() game.switch(Title) end},
  }, onBack = function() game.switch(Select, {song = p.song, diff = p.diff}) end}
end
function Results:update(dt)
  self.t = self.t + dt
  self.shake = max(0, self.shake - dt * 12)
  if self.p.record and self.t > 1.4 and self.t < 4 then
    self.confetti:emit(3, random() * game.width, -8)
  end
  self.confetti:update(dt)
  self.menu:update()
end
function Results:draw()
  drawBackdrop(self.t, 0.3 + sin(self.t * 3) * 0.2)
end
function Results:ui()
  local W, H = game.width, game.height
  local p = self.p
  local sx = self.shake > 0 and (random() - 0.5) * self.shake or 0
  local pw, ph = min(420, W - 24), 170
  local px, py = (W - pw) / 2 + sx, max(6, (H - ph - 90) / 2)
  U.panel(px, py, pw, ph, 14, "#140C2CE8")
  U.text(TR(SONGS[p.song].name) .. " · " .. TR(DIFF_KEYS[p.diff]), px, py + 10, 13, "#D9C8FF", "center", pw, "semibold")
  -- grade
  local gx = px + pw * 0.24
  local g = self.gradeFx
  G.alpha(g.a)
  U.text(p.grade, gx - 60, py + 62 - 30 * g.s, 60 * g.s, GRADE_COLORS[p.grade] or "#FFFFFF", "center", 120, "bold")
  G.unalpha()
  if p.full then U.text(TR("full_combo"), gx - 70, py + 100, 11, "#FFE45C", "center", 140, "bold") end
  -- numbers
  local nx = px + pw * 0.48
  local cw = pw * 0.48
  U.text(TR("score"), nx, py + 34, 10, "#D9C8FFC0", nil, nil, "semibold")
  U.text(tostring(floor(self.shown.score)), nx, py + 46, 22, "#FFFFFF", nil, nil, "bold")
  U.text(TR("accuracy"), nx, py + 76, 10, "#D9C8FFC0", nil, nil, "semibold")
  U.text(string.format("%.1f%%", self.shown.acc), nx, py + 88, 16, "#FFFFFF", nil, nil, "bold")
  U.text(TR("max_combo"), nx + cw * 0.55, py + 76, 10, "#D9C8FFC0", nil, nil, "semibold")
  U.text(p.maxCombo .. " / " .. p.total, nx + cw * 0.55, py + 88, 16, "#FFFFFF", nil, nil, "bold")
  for k = 1, 4 do
    local cx = px + 14 + (k - 1) * (pw - 28) / 4
    U.text(TR(JUDGE_KEYS[k]), cx, py + 118, 9, JUDGE_COLORS[k], "center", (pw - 28) / 4, "bold")
    U.text(tostring(p.counts[k]), cx, py + 130, 14, "#FFFFFF", "center", (pw - 28) / 4, "bold")
  end
  if p.record then
    local a = 0.6 + sin(self.t * 6) * 0.4
    G.alpha(self.t > 1.4 and a or 0)
    U.text(TR("new_best"), px, py + 150, 14, "#FFE45C", "center", pw, "bold")
    G.unalpha()
  else
    local best = save:get("best_" .. recordKey(p.song, p.diff), 0)
    U.text(TR("best_is", best), px, py + 152, 11, "#D9C8FFC0", "center", pw, "semibold")
  end
  self.menu:draw(W / 2, py + ph + 6)
  self.confetti:draw()
end

-- ---------------------------------------------------------------- run
return game.run{
  width = 480, height = 270, scale = "expand",
  scene = Title, title = Title,
  background = "#120A2A",
  menu = function()
    return {{title = TR("game_menu"), items = {
      {label = TR("pause_menu"), id = 1, shortcut = "Esc"},
      {label = TR("song_select"), id = 2},
      {label = TR("main_menu"), id = 3},
      "-",
      {label = TR("reset_records"), id = 4},
    }}}
  end,
  onmenu = function(id)
    if id == 1 then game.pause()
    elseif id == 2 then game.switch(Select)
    elseif id == 3 then game.switch(Title)
    elseif id == 4 then
      local sp = save:get("speed", 2)
      save:reset()
      save:set("speed", sp)
      U.toast(TR("records_reset"))
    end
  end,
}
