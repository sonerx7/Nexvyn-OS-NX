-- Neon Drift: a night-city arcade racer. Three circuits, rivals, drift-charged nitro, rain and neon.
local Track = require("nd.track")
local Car = require("nd.car")
local World = require("nd.world")
local Hud = require("nd.hud")
local F = require("nd.font")
local Snd = require("nd.sound")

local app = {}
local hexa = F.hexa
local PINK, CYAN, VIOLET, AMBER, WHITE, INK = Hud.PINK, Hud.CYAN, Hud.VIOLET, Hud.AMBER, Hud.WHITE, Hud.INK

local PAINTS = {"#FF2E88", "#19E6FF", "#FFB13B", "#8A5BFF", "#F2F4FF", "#3CFF8A"}
local GLOWS = {"#19E6FF", "#FF2E88", "#FF2E88", "#19E6FF", "#8A5BFF", "#19E6FF"}
local RIVAL_COLORS = {"#E8E8F0", "#2A64FF", "#FF5A2A", "#20D0A0", "#C83CFF", "#FFD23C", "#FF3C5A"}

---------------------------------------------------------------------------------------------- state
local S = {
  state = "load", t = 0, clock = 0, tracks = {}, trackIx = 1, sel = 1, keys = {},
  laps = 3, rivals = 5, diff = "normal", paint = 1,
  settings = {quality = "quality", rain = true, music = true, sfx = true, vibe = true, cam = 1},
  records = {}, wipe = 0, wipeTo = nil, msg = nil, msgT = 0, touch = {}, usingTouch = false,
  perf = {n = 0, sum = 0, max = 0, t0 = 0, cpu = 0},
}
local race

local function save()
  store.set("nd_v1", {settings = S.settings, records = S.records, laps = S.laps, rivals = S.rivals, diff = S.diff,
                      paint = S.paint, track = S.trackIx})
end
local function loadSave()
  local d = store.get("nd_v1")
  if type(d) == "table" then
    for k, v in pairs(d.settings or {}) do S.settings[k] = v end
    S.records = d.records or {}
    S.laps = d.laps or S.laps; S.rivals = d.rivals or S.rivals; S.diff = d.diff or S.diff
    S.paint = d.paint or S.paint; S.trackIx = d.track or S.trackIx
  end
end

local function vibe(strength, ms)
  if S.settings.vibe then sys.vibrate(math.min(1, strength), ms or 120) end
end

---------------------------------------------------------------------------------------------- loading
local loader
local function loadAll()
  World.loadPieces()
  for k, def in ipairs(Track.defs) do
    local tr = Track.sample(def)
    Track.yield()
    S.tracks[k] = tr
  end
  -- wait for the pack pieces (their sizes drive the placement)
  while not World.loadNext() do Track.yield() end
  print("nd: models loaded")
  for k, tr in ipairs(S.tracks) do
    Track.build(tr, World.pieces)
    Track.finalize(tr)
    S.loadStep = k
    print("nd: track built " .. tr.def.id .. " " .. tr.N .. " samples")
  end
end

---------------------------------------------------------------------------------------------- race setup
local function makeRace(trIx, opts)
  opts = opts or {}
  local tr = S.tracks[trIx]
  World.setTrack(tr)
  World.clearParticles()
  local cars = {}
  local n = opts.demo and 6 or (S.rivals + 1)
  local grid = {}
  for k = 1, n do
    local row = math.floor((k - 1) / 2)
    grid[k] = {s = (tr.L * (S.startAt or 1)) - 10 - row * 9, lat = ((k % 2 == 1) and -3.3 or 3.3)}
  end
  local player
  for k = 1, n do
    local isPlayer = (not opts.demo) and k == n
    local g = grid[k]
    local col = isPlayer and PAINTS[S.paint] or RIVAL_COLORS[(k - 1) % #RIVAL_COLORS + 1]
    local glow = isPlayer and GLOWS[S.paint] or ((k % 2 == 0) and CYAN or PINK)
    local c = Car.new(tr, g.s, g.lat, {ai = not isPlayer, color = col, glow = glow,
      skill = 0.97 + 0.05 * ((k * 37) % 7) / 6 - (opts.demo and 0 or 0.02 * (n - k) / n),
      laneBias = ((k * 53) % 5 - 2) * 0.9})
    c.prevS = g.s
    c.lap = -1  -- the grid is behind the line: crossing it starts lap 1
    c.sectorOk = {true, true}
    World.makeCarModel(c)
    c.num = k
    cars[#cars + 1] = c
    if isPlayer then player = c end
  end
  race = {track = tr, trIx = trIx, cars = cars, player = player, laps = opts.laps or S.laps, time = 0, clock = 0,
          phase = opts.demo and "demo" or "count", count = 0, demo = opts.demo, auto = opts.auto, doneT = 0,
          camMode = S.settings.cam, results = nil, finishOrder = {}, lastRank = n}
  if player then World.cam.x, World.cam.y, World.cam.z = player.x, player.y + 3, player.z + 8; World.cam.reset = true end
  return race
end

local function startRace(trIx)
  makeRace(trIx, {})
  Snd.stopAll()
  Snd.music_play(nil)
  Snd.rain(S.settings.rain)
  S.state = "race"
  S.paused = false
end

local function startDemo()
  makeRace(S.trackIx, {demo = true, laps = 99})
  Snd.stopAll()
  Snd.music_play("menu")
end

---------------------------------------------------------------------------------------------- race logic
local function rankCars()
  local list = {}
  for _, c in ipairs(race.cars) do list[#list + 1] = c end
  table.sort(list, function(a, b)
    if a.finished and b.finished then return a.finishTime < b.finishTime end
    if a.finished ~= b.finished then return a.finished end
    return a.progress > b.progress
  end)
  for k, c in ipairs(list) do c.rank = k end
  return list
end

local function emitFx(c, dt, near)
  local s, co = math.sin(c.yaw), math.cos(c.yaw)
  local bx, bz = c.x + s * 1.6, c.z + co * 1.6
  if (c.drifting or c.slip > 6) and c.speed > 8 and math.random() < dt * (near and 18 or 4) then
    for k = -1, 1, 2 do
      World.emit("smoke", bx + co * 0.8 * k, c.y + 0.3, bz - s * 0.8 * k, c.vx * 0.2 + (math.random() - 0.5), 0.6,
                 c.vz * 0.2 + (math.random() - 0.5), 1.4, 0.9, "#B8B4D0")
    end
  end
  if near and c.speed > 18 and math.random() < dt * 10 then
    for k = -1, 1, 2 do
      World.emit("spray", bx + co * 0.8 * k, c.y + 0.25, bz - s * 0.8 * k, c.vx * 0.55 + (math.random() - 0.5) * 2,
                 1.2 + math.random(), c.vz * 0.55 + (math.random() - 0.5) * 2, 0.45, 0.5, "#9CB4E0")
    end
  end
end

local function sparks(x, y, z, n, vx, vz, col)
  for _ = 1, n do
    World.emit("spark", x, y, z, vx * 0.4 + (math.random() - 0.5) * 12, math.random() * 6, vz * 0.4 + (math.random() - 0.5) * 12,
               0.35 + math.random() * 0.4, 0.1, col or "#FFB040")
  end
end

local function playerInput(c, dt)
  local inp = c.input
  local k = S.keys
  local sx = input.stick("left")
  local steer = sx
  if math.abs(steer) < 0.12 then steer = 0 end
  if k.left or k.a or input.down("left") then steer = -1 end
  if k.right or k.d or input.down("right") then steer = 1 end
  local gas = (input.down("zr") or k.up or k.w) and 1 or 0
  local brake = (input.down("zl") or k.down or k.s) and 1 or 0
  local drift = input.down("r") or input.down("b") or k.space
  local nitro = input.down("a") or k.e
  local T = S.touch
  if S.usingTouch then
    if T.left then steer = -1 elseif T.right then steer = 1 end
    gas = T.brake and 0 or 1
    brake = T.brake and 1 or brake
    drift = drift or T.drift
    nitro = nitro or T.nitro
  end
  -- light steering smoothing for keys / buttons
  inp.steer = inp.steer + (steer - inp.steer) * math.min(1, dt * (math.abs(steer) > math.abs(inp.steer) and 9 or 14))
  inp.gas, inp.brake, inp.drift, inp.nitro = gas, brake, drift, nitro
end

local function finishRace()
  local r = race
  local order = rankCars()
  -- rivals still racing get a time from their remaining distance
  for _, c in ipairs(order) do
    if not c.finished then
      local remain = (r.laps * r.track.L) - c.progress
      c.finishTime = r.time + math.max(0, remain) / math.max(20, c.speed)
      c.finished = true
      c.estimated = true
    end
  end
  order = rankCars()
  local p = r.player
  local key = r.track.def.id
  local rec = S.records[key] or {}
  local newLap = p.best and (not rec.bestLap or p.best < rec.bestLap)
  if newLap then rec.bestLap = p.best end
  local rkey = "race" .. r.laps
  local newRace = (not rec[rkey] or p.finishTime < rec[rkey])
  if newRace then rec[rkey] = p.finishTime end
  if p.rank == 1 then rec.wins = (rec.wins or 0) + 1 end
  rec.races = (rec.races or 0) + 1
  S.records[key] = rec
  save()
  r.results = {order = order, newLap = newLap, newRace = newRace}
  Snd.play(p.rank <= 3 and "finish" or "lose", 0.9)
end

local function showMsg(text, col, t)
  S.msg, S.msgCol, S.msgT = text, col or WHITE, t or 1.6
end

local function updateRace(dt)
  local r = race
  r.clock = r.clock + dt
  local tr = r.track
  if r.phase == "count" then
    r.count = r.count + dt
    if not r.ranked then rankCars(); r.ranked = true end
    local lit = math.min(5, math.floor(r.count / 0.65))
    if lit > (r.lit or 0) then r.lit = lit; Snd.play("beep", 0.7) end
    if r.count > 0.65 * 5 + 0.5 + 0.4 then
      r.phase = "run"
      r.goT = 0
      Snd.play("go", 0.9)
      Snd.music_play("race")
      vibe(0.4, 120)
    end
    -- revving on the grid
    if r.player then
      playerInput(r.player, dt)
      r.player.rpm = r.player.input.gas > 0 and 0.85 or 0.25
    end
  end
  local running = r.phase == "run" or r.phase == "done" or r.phase == "demo"
  if running then
    r.time = r.time + (r.phase == "run" and dt or 0)
    for _, c in ipairs(r.cars) do
      if c == r.player and r.phase == "run" and not r.auto then
        playerInput(c, dt)
      else
        Car.drive(c, tr, r.cars, r.player, r.demo and "hard" or S.diff, dt, r.clock, c == r.player and r.auto)
        if c == r.player and c.finished then c.input.gas = 0.35; c.input.nitro = false end
      end
      local impact = Car.step(c, tr, World.phys, dt, true)
      if impact > 4 then
        local s, co = math.sin(c.yaw), math.cos(c.yaw)
        sparks(c.x - s * 1.5, c.y + 0.5, c.z - co * 1.5, math.min(30, math.floor(impact * 1.5)), c.vx, c.vz)
        if c == r.player then
          World.cam.shake = math.min(1.2, impact * 0.05)
          Snd.play(impact > 12 and "hit" or "bump", math.min(1, 0.3 + impact / 25))
          vibe(impact / 25, 140)
        end
      end
      -- laps
      if c.lapCrossed then
        c.lapCrossed = false
        if c.lap >= 1 then
          local lt = r.time - c.lapStart
          c.lapTimes[#c.lapTimes + 1] = lt
          if not c.best or lt < c.best then
            c.best = lt
            if c == r.player and c.lap >= 1 and r.phase == "run" then
              local rec = S.records[tr.def.id]
              if rec and rec.bestLap and lt < rec.bestLap then showMsg(TR("new_best"), AMBER, 2) end
            end
          end
        end
        c.lapStart = r.time
        if c.lap >= r.laps and not c.finished and r.phase ~= "demo" then
          c.finished = true
          c.finishTime = r.time
        elseif c == r.player and r.phase == "run" then
          if c.lap == r.laps - 1 then showMsg(TR("final_lap"), PINK, 2); Snd.play("final", 0.9)
          elseif c.lap >= 1 then Snd.play("lap", 0.8) end
        end
      end
      emitFx(c, dt, c == r.player or (r.demo and c == r.cars[1]))
    end
    for _, ct in ipairs(Car.contacts(r.cars)) do
      if ct[3] > 3 then
        local A, B = ct[1], ct[2]
        sparks((A.x + B.x) / 2, (A.y + B.y) / 2 + 0.5, (A.z + B.z) / 2, 8, A.vx, A.vz, "#FFE080")
        if A == r.player or B == r.player then Snd.play("bump", math.min(1, ct[3] / 10)); vibe(ct[3] / 15, 90) end
      end
    end
    rankCars()
    local p = r.player
    if p and r.phase == "run" then
      if p.rank < r.lastRank and r.clock > 6 then Snd.play("whoosh", 0.4) end
      r.lastRank = p.rank
      if p.nitro > 0.98 and not r.nitroReady then r.nitroReady = true; Snd.play("boost_ready", 0.6) end
      if p.nitro < 0.9 then r.nitroReady = false end
      if p.nitroOn and not r.nitroWas then Snd.play("nitro", 0.8); vibe(0.35, 160) end
      r.nitroWas = p.nitroOn
      if p.finished then
        r.phase = "done"
        r.doneT = 0
        finishRace()
      end
    elseif r.phase == "done" then
      r.doneT = r.doneT + dt
    end
  end
  World.updateParticles(dt)
  -- camera
  if r.demo then
    -- cinematic fly-over around the leading car, a new angle every 7 s
    local c = r.cars[1]
    for _, o in ipairs(r.cars) do if o.progress > c.progress then c = o end end
    local shot = math.floor(r.clock / 7) % 4
    local s, co = math.sin(c.yaw), math.cos(c.yaw)
    local tt = r.clock % 7
    local ex, ey, ez, tx, ty, tz
    if shot == 0 then ex, ey, ez = c.x + co * 7 - s * (tt - 3), c.y + 1.2, c.z - s * 7 - co * (tt - 3); tx, ty, tz = c.x, c.y + 0.8, c.z
    elseif shot == 1 then ex, ey, ez = c.x + s * 12, c.y + 5 + tt * 0.6, c.z + co * 12; tx, ty, tz = c.x - s * 10, c.y, c.z - co * 10
    elseif shot == 2 then ex, ey, ez = c.x - s * 9, c.y + 1.0, c.z - co * 9; tx, ty, tz = c.x, c.y + 0.9, c.z
    else ex, ey, ez = c.x - co * 18, c.y + 14, c.z + s * 18; tx, ty, tz = c.x, c.y, c.z end
    local k = math.min(1, dt * 4)
    local cm = World.cam
    if tt < dt * 1.5 then k = 1 end
    World.setCamera(cm.x + (ex - cm.x) * k, cm.y + (ey - cm.y) * k, cm.z + (ez - cm.z) * k, tx, ty, tz, 58)
  elseif r.player then
    World.updateCamera(r.player, dt, r.camMode, r.player.nitroOn, 0)
  end
  -- sound
  local p = r.player
  Snd.engine(p, p ~= nil and (r.phase == "run" or r.phase == "count" or r.phase == "done") and not S.paused, dt)
  Snd.intensity(p ~= nil and r.phase == "run" and (p.speed > 45 or p.nitroOn))
  if S.msgT > 0 then S.msgT = S.msgT - dt end
end

---------------------------------------------------------------------------------------------- menus
local screens = {}
local function go(state, sel)
  S.wipeTo = state
  S.wipe = 0.001
  S.wipeSel = sel or 1
  Snd.play("ui_ok", 0.6)
end

local function item(label, action, value, left, right)
  return {label = label, action = action, value = value, left = left, right = right}
end

local function cycle(list, cur, d)
  for k, v in ipairs(list) do if v == cur then return list[(k - 1 + d) % #list + 1] end end
  return list[1]
end

function screens.menu()
  return {
    title = nil,
    items = {
      item(TR("menu_race"), function() go("setup") end),
      item(TR("menu_records"), function() go("records") end),
      item(TR("menu_settings"), function() go("settings") end),
      item(TR("menu_help"), function() go("help") end),
    },
  }
end

local function trackName(ix) return TR(Track.defs[ix].key) end
local DIFFS = {"easy", "normal", "hard"}

function screens.setup()
  local function setTrack(d)
    S.trackIx = (S.trackIx - 1 + d) % #Track.defs + 1
    startDemo()
  end
  return {
    title = TR("menu_race"),
    items = {
      item(TR("opt_track"), nil, function() return trackName(S.trackIx) end, function() setTrack(-1) end, function() setTrack(1) end),
      item(TR("opt_laps"), nil, function() return tostring(S.laps) end,
           function() S.laps = cycle({2, 3, 5}, S.laps, -1) end, function() S.laps = cycle({2, 3, 5}, S.laps, 1) end),
      item(TR("opt_rivals"), nil, function() return tostring(S.rivals) end,
           function() S.rivals = cycle({3, 4, 5}, S.rivals, -1) end, function() S.rivals = cycle({3, 4, 5}, S.rivals, 1) end),
      item(TR("opt_diff"), nil, function() return TR("diff_" .. S.diff) end,
           function() S.diff = cycle(DIFFS, S.diff, -1) end, function() S.diff = cycle(DIFFS, S.diff, 1) end),
      item(TR("opt_paint"), nil, function() return "paint" end,
           function() S.paint = (S.paint - 2) % #PAINTS + 1 end, function() S.paint = S.paint % #PAINTS + 1 end),
      item(TR("start"), function() save(); go("race") end),
      item(TR("back"), function() go("menu") end),
    },
    back = function() go("menu") end,
  }
end

local function onoff(v) return v and TR("on") or TR("off") end
function screens.settings()
  local st = S.settings
  local function tog(k) return function() st[k] = not st[k]; if k == "music" then Snd.setMusic(st.music); if st.music then Snd.music_play("menu") end end; save() end end
  return {
    title = TR("menu_settings"),
    items = {
      item(TR("set_quality"), nil, function() return TR(st.quality == "quality" and "q_quality" or "q_perf") end,
           function() st.quality = st.quality == "quality" and "performance" or "quality"; World.quality = st.quality; World.applyQuality(); save() end,
           function() st.quality = st.quality == "quality" and "performance" or "quality"; World.quality = st.quality; World.applyQuality(); save() end),
      item(TR("set_camera"), nil, function() return TR("cam_" .. st.cam) end,
           function() st.cam = (st.cam - 2) % 3 + 1; save() end, function() st.cam = st.cam % 3 + 1; save() end),
      item(TR("set_rain"), nil, function() return onoff(st.rain) end, tog("rain"), tog("rain")),
      item(TR("set_music"), nil, function() return onoff(st.music) end, tog("music"), tog("music")),
      item(TR("set_sfx"), nil, function() return onoff(st.sfx) end, function() st.sfx = not st.sfx; Snd.sfx = st.sfx; save() end,
           function() st.sfx = not st.sfx; Snd.sfx = st.sfx; save() end),
      item(TR("set_vibe"), nil, function() return onoff(st.vibe) end, tog("vibe"), tog("vibe")),
      item(TR("back"), function() go("menu", 3) end),
    },
    back = function() go("menu", 3) end,
  }
end

function screens.records()
  return {title = TR("menu_records"), items = {item(TR("back"), function() go("menu", 2) end)}, back = function() go("menu", 2) end, panel = "records"}
end
function screens.help()
  return {title = TR("menu_help"), items = {item(TR("back"), function() go("menu", 4) end)}, back = function() go("menu", 4) end, panel = "help"}
end
function screens.pause()
  return {
    title = TR("pause"),
    items = {
      item(TR("resume"), function() S.paused = false; audio.musicPause(false); Snd.play("ui_ok", 0.5) end),
      item(TR("restart"), function() S.paused = false; Snd.stopAll(); startRace(race.trIx) end),
      item(TR("set_camera"), nil, function() return TR("cam_" .. race.camMode) end,
           function() race.camMode = (race.camMode - 2) % 3 + 1 end, function() race.camMode = race.camMode % 3 + 1 end),
      item(TR("quit_menu"), function() S.paused = false; Snd.stopAll(); go("menu") end),
    },
    back = function() S.paused = false; audio.musicPause(false) end,
  }
end
function screens.results()
  return {
    items = {
      item(TR("restart"), function() Snd.stopAll(); startRace(race.trIx) end),
      item(TR("next_track"), function() S.trackIx = race.trIx % #Track.defs + 1; save(); Snd.stopAll(); startRace(S.trackIx) end),
      item(TR("quit_menu"), function() Snd.stopAll(); go("menu") end),
    },
    back = function() Snd.stopAll(); go("menu") end,
    panel = "results",
  }
end

local cur  -- current screen table
local function openScreen(name, sel)
  S.state = name
  if name == "race" then startRace(S.trackIx); cur = nil; return end
  if name == "title" or name == "menu" or name == "setup" or name == "records" or name == "settings" or name == "help" then
    if not race or not race.demo or race.trIx ~= S.trackIx then startDemo() end
    Snd.rain(false)
    Snd.engine(nil, false)
    Snd.music_play("menu")
  end
  cur = screens[name] and screens[name]() or nil
  S.sel = sel or 1
  S.enterT = 0
end

local function menuInput(scr, ev)
  if not scr then return end
  local n = #scr.items
  local it = scr.items[S.sel]
  if ev == "up" then S.sel = (S.sel - 2) % n + 1; Snd.play("ui_move", 0.5)
  elseif ev == "down" then S.sel = S.sel % n + 1; Snd.play("ui_move", 0.5)
  elseif ev == "left" and it.left then it.left(); Snd.play("ui_move", 0.5)
  elseif ev == "right" and it.right then it.right(); Snd.play("ui_move", 0.5)
  elseif ev == "ok" then
    if it.action then it.action() elseif it.right then it.right(); Snd.play("ui_move", 0.5) end
  elseif ev == "back" and scr.back then Snd.play("ui_back", 0.6); scr.back() end
end

---------------------------------------------------------------------------------------------- drawing: menus
-- localised headline: system font (every script) with a neon glow made of offset copies
local function bigText(s, x, y, size, col, align, width, a)
  a = a or 1
  for k = 3, 1, -1 do
    gfx.color(hexa(col, 0.10 * a))
    gfx.text(s, x - k * 1.5, y, size, "bold", align, width)
    gfx.text(s, x + k * 1.5, y, size, "bold", align, width)
  end
  gfx.color(hexa(col, a))
  gfx.text(s, x, y, size, "bold", align, width)
end

local function drawLogo(x, y, size, t)
  -- tube ignition: flicker during the first second on screen
  local fl = 1
  if t < 1.2 then fl = (math.sin(t * 61) > 0.2 or t > 0.9) and 1 or 0.25 end
  F.draw("NEON", x, y, size, PINK, {thick = size * 0.07, alpha = fl, track = 1.9})
  F.draw("DRIFT", x + size * 0.55, y + size * 1.12, size * 1.08, CYAN, {thick = size * 0.075, alpha = math.min(1, fl + 0.2), track = 1.9})
end

local function drawItems(w, h, scr, x0, y0)
  local u = h / 720
  S.hits = {}
  for k, it in ipairs(scr.items) do
    local sel = k == S.sel
    local appear = math.min(1, math.max(0, (S.enterT or 1) * 5 - k * 0.35))
    local ix = x0 - (1 - appear) * 260 * u
    local iy = y0 + (k - 1) * 58 * u
    local iw, ih = 470 * u, 46 * u
    if sel then
      Hud.slab(ix - 6 * u, iy - 4 * u, iw + 12 * u, ih + 8 * u, 16 * u, hexa(PINK, 0.25 + 0.1 * math.sin(S.clock * 6)))
      Hud.slab(ix, iy, iw, ih, 14 * u, hexa(PINK, 0.92))
      Hud.slab(ix - 18 * u, iy, 8 * u, ih, 14 * u, CYAN)
    else
      Hud.slab(ix, iy, iw, ih, 14 * u, hexa(INK, 0.62 * appear))
    end
    gfx.alpha(appear)
    Hud.label(it.label, ix + 24 * u, iy + 10 * u, 22 * u, sel and WHITE or "#C9CCE6")
    if it.value then
      local v = it.value()
      local vx = ix + iw - 40 * u
      if v == "paint" then
        for pk, pc in ipairs(PAINTS) do
          local px = vx - (#PAINTS - pk) * 30 * u - 6 * u
          gfx.circle(px, iy + ih / 2, (pk == S.paint) and 11 * u or 8 * u, pc)
          if pk == S.paint then gfx.color(WHITE); gfx.circleLine(px, iy + ih / 2, 14 * u, 2) end
        end
      else
        Hud.label(v, ix + iw * 0.42, iy + 10 * u, 22 * u, sel and WHITE or CYAN, "right", iw * 0.5)
      end
      if sel and it.left then
        gfx.icon("chevron_left", ix + iw * 0.42 + 8 * u, iy + ih / 2, 26 * u, WHITE)
        gfx.icon("chevron_right", ix + iw - 10 * u, iy + ih / 2, 26 * u, WHITE)
      end
    end
    gfx.unalpha()
    S.hits[k] = {ix, iy, iw, ih}
  end
end

local function hintBar(w, h, text)
  local u = h / 720
  Hud.slab(-20 * u, h - 44 * u, w + 40 * u, 44 * u, 0, hexa(INK, 0.7))
  gfx.color(hexa(PINK, 0.9)); gfx.rect(0, h - 44 * u, w, 2 * u)
  Hud.label(text, 30 * u, h - 34 * u, 16 * u, "#AEB4D6")
end

local function drawRecords(w, h, x, y)
  local u = h / 720
  local cw = 260 * u
  for k, def in ipairs(Track.defs) do
    local cx = x + (k - 1) * (cw + 20 * u)
    local rec = S.records[def.id] or {}
    Hud.slab(cx, y, cw, 300 * u, 18 * u, hexa(INK, 0.7))
    Hud.slab(cx, y, cw, 6 * u, 0, k == 1 and PINK or (k == 2 and AMBER or VIOLET))
    Hud.label(TR(def.key), cx + 18 * u, y + 16 * u, 20 * u, WHITE)
    Hud.minimap(S.tracks[k], cx + 70 * u, y + 46 * u, 120 * u, nil, nil, 0.8)
    local ly = y + 180 * u
    local function row(lbl, val)
      Hud.label(lbl, cx + 18 * u, ly, 15 * u, "#AEB4D6")
      F.draw(val, cx + cw - 20 * u, ly, 16 * u, CYAN, {align = "right", thick = 1.6 * u})
      ly = ly + 26 * u
    end
    row(TR("rec_best_lap"), Hud.fmtTime(rec.bestLap))
    row(TR("rec_best_race") .. " (3)", Hud.fmtTime(rec.race3))
    row(TR("rec_wins"), tostring(rec.wins or 0))
    row(TR("rec_races"), tostring(rec.races or 0))
  end
end

local function drawHelp(w, h, x, y)
  local u = h / 720
  Hud.slab(x, y, 640 * u, 380 * u, 20 * u, hexa(INK, 0.72))
  local ly = y + 18 * u
  for k = 1, 9 do
    local s = TR("help_" .. k)
    if s ~= "help_" .. k then
      local hh = gfx.wrap(s, x + 28 * u, ly, 590 * u, 17 * u, "medium")
      ly = ly + hh + 9 * u
    end
  end
end

local function drawResults(w, h)
  local u = h / 720
  local r = race
  local x, y = w - 620 * u, 90 * u
  Hud.slab(x, y, 640 * u, 470 * u, 30 * u, hexa(INK, 0.78))
  Hud.slab(x, y, 640 * u, 6 * u, 0, PINK)
  bigText(TR("results_word"), x + 40 * u, y + 22 * u, 34 * u, WHITE)
  Hud.label(TR(r.track.def.key), x + 40 * u, y + 70 * u, 18 * u, CYAN)
  local ly = y + 110 * u
  for k, c in ipairs(r.results.order) do
    local me = c == r.player
    if me then Hud.slab(x + 20 * u, ly - 4 * u, 580 * u, 36 * u, 10 * u, hexa(PINK, 0.35)) end
    F.draw(tostring(k), x + 40 * u, ly + 2 * u, 24 * u, me and PINK or WHITE, {thick = 2.4 * u})
    gfx.circle(x + 100 * u, ly + 14 * u, 8 * u, c.color)
    Hud.label(me and TR("you") or (TR("rival") .. " " .. (c.num or k)), x + 120 * u, ly + 4 * u, 18 * u, me and WHITE or "#C9CCE6")
    F.draw(Hud.fmtTime(c.finishTime), x + 560 * u, ly + 4 * u, 18 * u, c.estimated and "#8890B0" or CYAN, {align = "right", thick = 1.8 * u})
    ly = ly + 42 * u
  end
  local p = r.player
  Hud.label(TR("hud_best") .. "  " .. Hud.fmtTime(p.best), x + 40 * u, y + 420 * u, 18 * u, AMBER)
  if r.results.newLap or r.results.newRace then
    local a = 0.6 + 0.4 * math.sin(S.clock * 6)
    Hud.label(TR("record_new"), x + 330 * u, y + 420 * u, 18 * u, hexa(AMBER, a))
  end
end

local function drawMenu(w, h)
  local u = h / 720
  -- left vignette for legibility
  gfx.gradient(0, 0, w * 0.55, h, hexa(INK, 0.0), hexa(INK, 0.0), true)
  for k = 0, 5 do
    gfx.color(hexa(INK, 0.13)); gfx.rect(0, 0, w * (0.62 - k * 0.07), h)
  end
  local scr = cur
  if S.state == "title" then
    drawLogo(70 * u, 150 * u, 110 * u, S.enterT or 0)
    local a = 0.7 + 0.3 * math.sin(S.clock * 3)
    Hud.slab(60 * u, 470 * u, 300 * u, 42 * u, 12 * u, hexa(PINK, 0.85 * a))
    Hud.label(S.usingTouch and TR("title_tap") or TR("title_press"), 80 * u, 480 * u, 22 * u, WHITE)
    return
  end
  if S.state == "menu" then
    drawLogo(60 * u, 60 * u, 64 * u, 2)
    drawItems(w, h, scr, 70 * u, 290 * u)
  else
    if scr.title then bigText(scr.title, 60 * u, 46 * u, 40 * u, WHITE) end
    local y0 = scr.panel and (h - 44 * u - 70 * u * #scr.items) or 140 * u
    drawItems(w, h, scr, 70 * u, y0)
    if S.state == "setup" then
      -- track card on the right
      local tr = S.tracks[S.trackIx]
      local cx, cy = w - 420 * u, 120 * u
      Hud.slab(cx, cy, 380 * u, 400 * u, 24 * u, hexa(INK, 0.7))
      Hud.slab(cx, cy, 380 * u, 6 * u, 0, PINK)
      Hud.label(TR(tr.def.key), cx + 26 * u, cy + 20 * u, 24 * u, WHITE)
      gfx.color("#AEB4D6"); gfx.wrap(TR(tr.def.key .. "_d"), cx + 26 * u, cy + 54 * u, 330 * u, 15 * u, "medium")
      Hud.minimap(tr, cx + 80 * u, cy + 100 * u, 220 * u, nil, nil, 1)
      local rec = S.records[tr.def.id] or {}
      Hud.label(string.format("%.1f km", tr.L / 1000), cx + 26 * u, cy + 330 * u, 16 * u, CYAN)
      Hud.label(TR("rec_best_lap"), cx + 26 * u, cy + 358 * u, 15 * u, "#AEB4D6")
      F.draw(Hud.fmtTime(rec.bestLap), cx + 350 * u, cy + 356 * u, 18 * u, AMBER, {align = "right", thick = 1.8 * u})
    elseif scr.panel == "records" then
      drawRecords(w, h, 70 * u, 130 * u)
    elseif scr.panel == "help" then
      drawHelp(w, h, 70 * u, 120 * u)
    end
  end
end

---------------------------------------------------------------------------------------------- callbacks
function app.load(arg)
  math.randomseed(7)
  loadSave()
  print(string.format("nd: save loaded (rain %s, quality %s, records %d)", tostring(S.settings.rain), S.settings.quality,
    (function() local n = 0; for _ in pairs(S.records) do n = n + 1 end; return n end)()))
  Snd.sfx = S.settings.sfx
  Snd.music = S.settings.music
  World.init(S.settings.quality)
  loader = coroutine.create(loadAll)
  S.arg = arg or ""
end

local function wipeDraw(w, h)
  if S.wipe <= 0 then return end
  local t = S.wipe
  local cols = {PINK, VIOLET, INK}
  for k = 1, 3 do
    local p = math.max(0, math.min(1, t * 2.4 - (k - 1) * 0.18))
    local q = math.max(0, math.min(1, (t - 0.42) * 2.4 - (3 - k) * 0.18))
    local x0 = -w * 0.4 + (w * 1.8) * q
    local x1 = -w * 0.4 + (w * 1.8) * p
    if x1 > x0 then
      gfx.poly({x0 + h * 0.35, 0, x1 + h * 0.35, 0, x1, h, x0, h}, cols[k])
    end
  end
end

-- self test (launch argument "selftest"): physics directions, drift and nitro, and rivals lapping every circuit.
-- Prints "nd-test:" lines to the app log; runs as a coroutine so frames keep coming.
local function selftest()
  local dt = 1 / 60
  for k, tr in ipairs(S.tracks) do
    World.setTrack(tr)
    -- player physics on the straight before the line
    local c = Car.new(tr, tr.L - 120, 0, {})
    c.input.gas = 1
    for _ = 1, 180 do Car.step(c, tr, World.phys, dt, false) end
    local v1 = c.speed
    local yaw0 = c.yaw
    c.input.steer = 1
    for _ = 1, 20 do Car.step(c, tr, World.phys, dt, false) end
    local fx, fz = -math.sin(yaw0), -math.cos(yaw0)
    local nfx, nfz = -math.sin(c.yaw), -math.cos(c.yaw)
    local cross = fx * nfz - fz * nfx  -- > 0: turned towards +right (x right, z towards the viewer)
    c.input.drift = true
    local n0 = c.nitro
    for _ = 1, 60 do Car.step(c, tr, World.phys, dt, false) end
    print(string.format("nd-test: %s speed3s=%.1f turnRight=%s drifting=%s nitroGain=%.2f", tr.def.id, v1,
      tostring(cross > 0), tostring(c.drifting), c.nitro - n0))
    Track.yield()
    -- six rivals, 150 s of racing
    local cars = {}
    for i = 1, 6 do
      local cc = Car.new(tr, tr.L - 10 - math.floor((i - 1) / 2) * 9, (i % 2 == 1) and -3.3 or 3.3,
                         {ai = true, skill = 0.97 + 0.01 * i, laneBias = (i % 5 - 2) * 0.9})
      cc.lap, cc.sectorOk = -1, {true, true}
      cars[i] = cc
    end
    local hits, t = 0, 0
    for step = 1, 150 * 60 do
      t = t + dt
      for _, cc in ipairs(cars) do
        Car.drive(cc, tr, cars, nil, "normal", dt, t)
        if Car.step(cc, tr, World.phys, dt, true) > 6 then hits = hits + 1 end
        cc.lapCrossed = false
      end
      Car.contacts(cars)
      if step % 600 == 0 then Track.yield() end
    end
    local minLap, maxLap = 99, 0
    for _, cc in ipairs(cars) do minLap = math.min(minLap, cc.lap); maxLap = math.max(maxLap, cc.lap) end
    print(string.format("nd-test: %s length=%.0fm rivals150s laps min=%d max=%d wallHits=%d", tr.def.id, tr.L, minLap, maxLap, hits))
    Track.yield()
  end
  print("nd-test: done")
end

local function applyArg()
  -- test hooks for screenshots and measurements: "race=<id>;auto;cam=<n>;demo;rain=0;q=perf;t=<s>"
  local a = S.arg
  if a == "" then return false end
  local opts = {}
  for tok in string.gmatch(a, "[^;]+") do
    local k, v = string.match(tok, "([^=]+)=?(.*)")
    opts[k] = v
  end
  World.dbg = {hdr = opts.hdr ~= "0", msaa = tonumber(opts.msaa), bloom = tonumber(opts.bloom), exposure = tonumber(opts.exp)}
  World.applyQuality()
  S.debug = opts.dbg ~= nil
  S.noHud = opts.nohud ~= nil
  if opts.q == "perf" then S.settings.quality = "performance"; World.quality = "performance"; World.applyQuality() end
  if opts.rain == "0" then S.settings.rain = false end
  if opts.laps then S.laps = tonumber(opts.laps) or S.laps end
  if opts.at then S.startAt = tonumber(opts.at) end
  if opts.paint then S.paint = tonumber(opts.paint) or S.paint end
  for k, d in ipairs(Track.defs) do if d.id == opts.race or d.id == opts.demo then S.trackIx = k end end
  if opts.selftest then
    S.state = "selftest"
    loader = coroutine.create(selftest)
    return true
  end
  if opts.race then
    S.state = "race"; startRace(S.trackIx)
    race.auto = opts.auto ~= nil
    if opts.cam then race.camMode = tonumber(opts.cam) or 1 end
    if opts.skip then race.count = 10 end
    return true
  elseif opts.demo then
    openScreen("menu")
    return true
  elseif opts.screen then
    openScreen(opts.screen)
    return true
  end
  return false
end

function app.update(dt)
  dt = math.min(dt, 1 / 20)
  S.clock = S.clock + dt
  S.t = S.t + dt
  Snd.update()
  if S.state == "load" then
    local t0 = sys.time()
    while loader and coroutine.status(loader) ~= "dead" and sys.time() - t0 < 0.05 do
      local ok, err = coroutine.resume(loader)
      if not ok then error(err) end
    end
    if coroutine.status(loader) == "dead" then
      if not applyArg() then
        openScreen("title")
      end
    end
    return
  end
  if S.state == "selftest" then
    if coroutine.status(loader) ~= "dead" then
      local ok, err = coroutine.resume(loader)
      if not ok then print("nd-test: error " .. tostring(err)) end
    end
    return
  end
  if S.wipe > 0 then
    S.wipe = S.wipe + dt * 1.6
    if S.wipe > 0.42 and S.wipeTo then
      openScreen(S.wipeTo, S.wipeSel)
      S.wipeTo = nil
    end
    if S.wipe > 1 then S.wipe = 0 end
  end
  S.enterT = (S.enterT or 0) + dt
  if S.state == "race" then
    if not S.paused and not S.freeze then updateRace(dt) end
    if race.phase == "done" and race.doneT > 3.5 and S.state == "race" then
      S.state = "results"
      cur = screens.results()
      S.sel = 1
      S.enterT = 0
    end
  elseif race then
    updateRace(dt)
  end
  -- performance log (relative frame cost, every 5 s)
  local pf = S.perf
  pf.n = pf.n + 1
  pf.sum = pf.sum + dt
  pf.max = math.max(pf.max, dt)
  if S.clock - pf.t0 > 4 then
    print(string.format("nd-perf: state=%s track=%s q=%s frame=%.2fms max=%.1fms cpu=%.2fms tris=%d mem=%.1fMB",
      S.state, race and race.track.def.id or "-", S.settings.quality, pf.sum / pf.n * 1000, pf.max * 1000,
      pf.cpu / pf.n * 1000, World.tris or 0, (sys.memory() or 0) / 1048576))
    local tm = World.tm
    if tm and tm.n > 0 then
      print(string.format("nd-perf: lua-scene=%.2fms finish=%.2fms", tm.pre / tm.n * 1000, tm.fin / tm.n * 1000))
      tm.pre, tm.fin, tm.n = 0, 0, 0
    end
    pf.n, pf.sum, pf.max, pf.t0, pf.cpu = 0, 0, 0, S.clock, 0
  end
end

local function drawLoading(w, h)
  local u = h / 720
  gfx.clear("#07060F")
  drawLogo(w / 2 - 300 * u, h / 2 - 150 * u, 90 * u, S.clock)
  local p = World.progress() * 0.4 + ((S.loadStep or 0) / 3) * 0.6
  gfx.color(hexa(WHITE, 0.1)); gfx.rect(w / 2 - 240 * u, h * 0.72, 480 * u, 6 * u, 3)
  gfx.color(PINK); gfx.rect(w / 2 - 240 * u, h * 0.72, 480 * u * p, 6 * u, 3)
  Hud.label(TR("loading"), w / 2 - 240 * u, h * 0.72 + 18 * u, 16 * u, "#AEB4D6", "center", 480 * u)
end

local function drawCountdown(w, h)
  local r = race
  local u = h / 720
  if r.phase == "count" then
    local lit = math.min(5, math.floor(r.count / 0.65))
    for k = 1, 5 do
      local cx = w / 2 + (k - 3) * 54 * u
      gfx.circle(cx, 110 * u, 20 * u, hexa(INK, 0.7))
      if k <= lit then
        gfx.circle(cx, 110 * u, 26 * u, hexa("#FF1A2A", 0.3))
        gfx.circle(cx, 110 * u, 18 * u, "#FF2A3A")
      else
        gfx.color(hexa(WHITE, 0.3)); gfx.circleLine(cx, 110 * u, 18 * u, 2)
      end
    end
  elseif r.phase == "run" and r.time < 1.2 then
    local a = 1 - r.time / 1.2
    local s = 120 * u * (1 + r.time * 0.6)
    F.draw("GO", w / 2, h * 0.36 - s / 2, s, "#3CFF8A", {align = "center", thick = s * 0.08, alpha = a})
  end
end

function app.draw(w, h)
  local t0 = sys.time()
  local dt = 1 / 60
  if S.state == "load" or S.state == "selftest" then drawLoading(w, h); return end
  local u = h / 720
  if race then
    local opts = {rain = (S.settings.rain and race.track.def.rain or 0), wet = 1,
                  lamps = race.phase == "count" and math.min(5, math.floor(race.count / 0.65)) or 0,
                  green = race.phase == "run" and race.time < 3}
    gfx.clear(race.track.def.sky)
    World.draw(w, h, race.cars, (not race.demo) and race.player or nil, dt, opts)
  else
    gfx.clear("#07060F")
  end
  if S.state == "race" or S.state == "results" then
    if race.player and S.state == "race" and not S.paused and not S.noHud then
      Hud.race(w, h, race, TR)
      drawCountdown(w, h)
      if S.msgT > 0 and S.msg then
        local a = math.min(1, S.msgT * 2)
        bigText(S.msg, 0, h * 0.2, 40 * u, S.msgCol, "center", w, a)
      end
      if race.player.wrongT > 1.2 then
        local a = 0.5 + 0.5 * math.sin(S.clock * 8)
        Hud.label(string.upper(TR("wrong_way")), 0, h * 0.3, 34 * u, hexa("#FF3040", a), "center", w)
      end
      if S.usingTouch then Hud.touchDraw(w, h, Hud.touchLayout(w, h), S.touch, TR) end
    end
    if S.paused and cur then
      gfx.color(hexa(INK, 0.55)); gfx.rect(0, 0, w, h)
      bigText(cur.title, 70 * u, 116 * u, 44 * u, WHITE)
      drawItems(w, h, cur, 70 * u, 220 * u)
      hintBar(w, h, TR("hint_menu"))
    elseif S.state == "results" and cur then
      gfx.color(hexa(INK, 0.35)); gfx.rect(0, 0, w, h)
      drawResults(w, h)
      drawItems(w, h, cur, 70 * u, h - 260 * u)
      hintBar(w, h, TR("hint_menu"))
    end
  else
    drawMenu(w, h)
    if S.state ~= "title" then hintBar(w, h, TR("hint_menu")) end
  end
  wipeDraw(w, h)
  S.perf.cpu = S.perf.cpu + (sys.time() - t0)
end

---------------------------------------------------------------------------------------------- input
local function pauseNow()
  if S.state == "race" and not S.paused and race.phase ~= "done" then
    S.paused = true
    audio.musicPause(true)
    Snd.engine(nil, false)
    cur = screens.pause()
    S.sel = 1
    S.enterT = 0
    Snd.play("ui_back", 0.6)
  end
end

local function menuActive()
  return (S.state ~= "race" and S.state ~= "load" and S.state ~= "title") or (S.state == "race" and S.paused)
end

local function navEvent(ev)
  if S.wipe > 0 then return end
  if S.state == "title" then
    if ev == "ok" then go("menu") end
    return
  end
  if menuActive() and cur then menuInput(cur, ev) end
end

local KEYNAV = {up = "up", down = "down", left = "left", right = "right", enter = "ok", space = "ok", escape = "back", backspace = "back"}
local PADNAV = {up = "up", down = "down", left = "left", right = "right", a = "ok", b = "back"}

function app.event(e)
  if e.type == "keydown" then
    S.keys[e.key] = true
    if S.debug then  -- test hooks (launch argument "dbg"): look-development toggles
      local d = World.dbg
      if e.key == "1" then d.bloom = 0 elseif e.key == "2" then d.hdr = false elseif e.key == "3" then World.hideModels = not World.hideModels
      elseif e.key == "4" then World.hideEmis = not World.hideEmis elseif e.key == "5" then d.bloom = nil; d.hdr = true
      elseif e.key == "6" then S.freeze = not S.freeze
      elseif e.key == "7" then World.hideFx = not World.hideFx
      elseif e.key == "8" then World.hideCars = not World.hideCars
      elseif e.key == "9" then World.hideRain = not World.hideRain
      elseif e.key == "0" then World.hideParts = not World.hideParts end
      S.perf.n, S.perf.sum, S.perf.max, S.perf.cpu, S.perf.t0 = 0, 0, 0, 0, S.clock - 1
      if World.tm then World.tm.pre, World.tm.fin, World.tm.n = 0, 0, 0 end
      World.applyQuality()
      print("nd-dbg: key " .. e.key)
    end
    S.usingTouch = false
    if S.state == "race" and not S.paused then
      if e.key == "escape" then pauseNow() elseif e.key == "c" then race.camMode = race.camMode % 3 + 1 end
    else
      local ev = KEYNAV[e.key]
      if e.key == "w" then ev = "up" elseif e.key == "s" then ev = "down" elseif e.key == "a" then ev = "left" elseif e.key == "d" then ev = "right" end
      if ev then navEvent(ev) end
    end
  elseif e.type == "keyup" then
    S.keys[e.key] = false
  elseif e.type == "paddown" then
    S.usingTouch = false
    if S.state == "race" and not S.paused then
      if e.pad == "plus" then pauseNow() elseif e.pad == "y" or e.pad == "x" then race.camMode = race.camMode % 3 + 1 end
    else
      if e.pad == "plus" and S.state == "race" and S.paused then cur.back(); return end
      local ev = PADNAV[e.pad]
      if ev then navEvent(ev) end
    end
  elseif e.type == "mousedown" or e.type == "mousemove" or e.type == "mouseup" then
    if e.touch then S.usingTouch = true end
    local w, h = gfx.size()
    if S.state == "race" and not S.paused and S.usingTouch then
      local L = Hud.touchLayout(w, h)
      local function inside(r) return e.x >= r[1] and e.x <= r[1] + r[3] and e.y >= r[2] and e.y <= r[2] + r[4] end
      local down = e.type ~= "mouseup"
      if e.type == "mousedown" and inside(L.pause) then pauseNow(); return end
      S.touch.left = down and inside(L.left)
      S.touch.right = down and inside(L.right)
      S.touch.brake = down and inside(L.brake)
      S.touch.drift = down and inside(L.drift)
      if e.type == "mousedown" and inside(L.nitro) then S.touch.nitro = true end
      if not down then S.touch.nitro = false end
      return
    end
    if e.type == "mouseup" and not e.cancel then
      if S.state == "title" then navEvent("ok"); return end
      if menuActive() and S.hits then
        for k, r in ipairs(S.hits) do
          if e.x >= r[1] and e.x <= r[1] + r[3] and e.y >= r[2] and e.y <= r[2] + r[4] then
            local it = cur.items[k]
            if S.sel == k or not it.right then
              S.sel = k
              if it.right and e.x > r[1] + r[3] * 0.5 then menuInput(cur, "right")
              elseif it.left then menuInput(cur, "left")
              else menuInput(cur, "ok") end
            else
              S.sel = k
              Snd.play("ui_move", 0.5)
            end
            return
          end
        end
      end
    end
  end
end

function app.suspend()
  save()
  pauseNow()
end
function app.focus(f)
  if not f then pauseNow() end
end
function app.autosave() save() end
function app.close() save(); Snd.stopAll(); return true end

return app
