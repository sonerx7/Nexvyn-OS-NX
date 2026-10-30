-- Benchmark: escalating 3D scenes measure frame rate and frame time, compute a score and keep a history.
local app = {}
local Builder = require("builder")

local floor, min, max, abs, sqrt, sin, cos, pi = math.floor, math.min, math.max, math.abs, math.sqrt, math.sin, math.cos, math.pi

local STAGE_TIME = 5.0
local WARMUP = 0.8

local state = "home"   -- home | run | results
local stageIdx = 1
local stageT = 0
local results = {}
local frameLog = {}
local history = {}
local best = 0
local lastScore = 0
local isBest = false
local cube, sphere, torus, knot
local terrainIdx, terrainN = nil, 40
local particles = {}
local lastTris = 0
local runStart = 0

local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function c3(r, g, b) return {clamp(floor(r + 0.5), 0, 254), clamp(floor(g + 0.5), 0, 254), clamp(floor(b + 0.5), 0, 254)} end
local function hsv(h, s, v)
  h = (h % 360) / 60
  local i = floor(h)
  local f = h - i
  local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
  local r, g, b
  if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
  return c3(r * 255, g * 255, b * 255)
end

-- scenes ---------------------------------------------------------------------------------------
local PALETTE = {}
for i = 1, 24 do PALETTE[i] = hsv(i * 15, 0.6, 0.95) end

local function sceneCubes(t)
  for i = 0, 49 do
    local a = i / 50 * 2 * pi + t * 0.3
    local r = 3 + (i % 5) * 0.9
    g3d.draw(cube, cos(a) * r, sin(i * 1.7 + t) * 1.2, sin(a) * r, t + i, t * 0.7 + i, 0, 0.7, 0.7, 0.7, PALETTE[i % 24 + 1])
  end
end

local function sceneSpheres(t)
  for i = 0, 9 do
    local a = i / 10 * 2 * pi + t * 0.5
    g3d.draw(sphere, cos(a) * 3.5, sin(t * 2 + i) * 0.8, sin(a) * 3.5, 0, t, 0, 1, 1, 1, PALETTE[(i * 2) % 24 + 1])
  end
  g3d.draw(sphere, 0, 0, 0, 0, -t, 0, 1.8, 1.8, 1.8, {240, 240, 245})
end

local function sceneTori(t)
  for i = 0, 11 do
    local a = i / 12 * 2 * pi
    local d = 4 + (i % 3) * 2.5
    g3d.draw(torus, cos(a + t * 0.2) * d, (i % 4 - 1.5) * 1.2, sin(a + t * 0.2) * d, t + i, t * 1.3, i, 1, 1, 1, PALETTE[(i * 5) % 24 + 1])
  end
end

local function sceneParticles(t)
  for i, p in ipairs(particles) do
    local a = p[1] + t * p[4]
    local r = p[2]
    g3d.point(cos(a) * r, p[3] + sin(t * 1.5 + i) * 0.3, sin(a) * r, 3, PALETTE[i % 24 + 1])
  end
end

local terrainV, terrainC = {}, {}
local function sceneTerrain(t)
  local n = terrainN
  local w = n + 1
  local k = 0
  for j = 0, n do
    for i = 0, n do
      local x, z = -6 + 12 * i / n, -6 + 12 * j / n
      local y = sin(x * 0.9 + t * 1.6) * 0.6 + cos(z * 0.8 - t * 1.1) * 0.6 + sin((x + z) * 0.5 + t) * 0.3
      terrainV[k * 3 + 1] = x; terrainV[k * 3 + 2] = y; terrainV[k * 3 + 3] = z
      terrainC[k + 1] = PALETTE[clamp(floor((y + 1.5) / 3 * 23), 0, 23) + 1]
      k = k + 1
    end
  end
  local m = g3d.custom(terrainV, terrainIdx, terrainC)
  g3d.draw(m, 0, -1, 0)
end

local function sceneStress(t)
  for i = 0, 2 do
    local a = i / 3 * 2 * pi + t * 0.4
    g3d.draw(knot, cos(a) * 3.2, 0, sin(a) * 3.2, t * 0.5 + i, t * 0.8, 0, 1, 1, 1, PALETTE[(i * 8) % 24 + 1])
  end
  sceneCubes(t)
end

local STAGES = {
  {key = "s_cubes", fn = sceneCubes, fog = false},
  {key = "s_spheres", fn = sceneSpheres, fog = false},
  {key = "s_tori", fn = sceneTori, fog = true},
  {key = "s_particles", fn = sceneParticles, fog = true},
  {key = "s_terrain", fn = sceneTerrain, fog = true},
  {key = "s_stress", fn = sceneStress, fog = true},
}

-- run control --------------------------------------------------------------------------------------
local function startRun()
  results = {}
  for i = 1, #STAGES do results[i] = {frames = 0, time = 0, worst = 0, tris = 0, trisN = 0} end
  stageIdx, stageT = 1, 0
  frameLog = {}
  state = "run"
  runStart = sys.time()
  audio.play("pop")
end

local function finishRun()
  local score = 0
  for i, r in ipairs(results) do
    r.fps = r.time > 0 and r.frames / r.time or 0
    r.ms = r.frames > 0 and r.time / r.frames * 1000 or 0
    r.minFps = r.worst > 0 and 1 / r.worst or 0
    r.avgTris = r.trisN > 0 and r.tris / r.trisN or 0
    r.score = r.fps * r.avgTris / 1000
    score = score + r.score
  end
  lastScore = floor(score + 0.5)
  isBest = lastScore > best
  if isBest then best = lastScore; store.set("best", best) end
  local d = sys.date()
  table.insert(history, 1, {score = lastScore, date = string.format("%04d-%02d-%02d %02d:%02d", d.year, d.month, d.day, d.hour, d.min),
    fw = sys.firmware(), fps = {}})
  for i, r in ipairs(results) do history[1].fps[i] = floor(r.fps * 10 + 0.5) / 10 end
  while #history > 10 do table.remove(history) end
  store.set("history", history)
  state = "results"
  audio.tone(660, 0.12, 0.3, "triangle")
  timer.after(0.12, function() audio.tone(990, 0.2, 0.3, "triangle") end)
end

function app.load(arg)
  cube = g3d.mesh("cube", 1)
  sphere = g3d.mesh("sphere", 0.55, 12, 8)
  torus = g3d.mesh("torus", 0.8, 0.28, 16, 8)
  -- (2,3) torus knot tube
  local pts = {}
  for k = 0, 159 do
    local a = k / 160 * 2 * pi
    local r = 1.0 + 0.42 * cos(3 * a)
    pts[#pts + 1] = {r * cos(2 * a), 0.42 * sin(3 * a), r * sin(2 * a)}
  end
  local b = Builder.new()
  b:tube(pts, 0.2, 10, {230, 230, 235}, true)
  knot = b:mesh(false)
  -- terrain indices
  terrainIdx = {}
  local w = terrainN + 1
  for j = 0, terrainN - 1 do
    for i = 0, terrainN - 1 do
      local a = j * w + i + 1
      terrainIdx[#terrainIdx + 1] = a; terrainIdx[#terrainIdx + 1] = a + w; terrainIdx[#terrainIdx + 1] = a + w + 1
      terrainIdx[#terrainIdx + 1] = a; terrainIdx[#terrainIdx + 1] = a + w + 1; terrainIdx[#terrainIdx + 1] = a + 1
    end
  end
  for i = 1, 1200 do
    particles[i] = {math.random() * 2 * pi, 1 + math.random() * 6, (math.random() - 0.5) * 4, 0.2 + math.random() * 0.8}
  end
  history = store.get("history", {})
  if type(history) ~= "table" then history = {} end
  best = store.get("best", 0)
end

function app.update(dt)
  if state ~= "run" then return end
  stageT = stageT + dt
  frameLog[#frameLog + 1] = dt
  if #frameLog > 150 then table.remove(frameLog, 1) end
  local r = results[stageIdx]
  if stageT > WARMUP then
    r.frames = r.frames + 1
    r.time = r.time + dt
    if dt > r.worst then r.worst = dt end
  end
  if stageT >= STAGE_TIME then
    stageIdx = stageIdx + 1
    stageT = 0
    if stageIdx > #STAGES then finishRun() else audio.tone(520 + stageIdx * 60, 0.06, 0.2, "sine") end
  end
end

-- drawing --------------------------------------------------------------------------------------------
local function card(x, y, w, h, title, icon)
  gfx.shadow(x, y, w, h, 12, 14, 3)
  gfx.color(theme.window)
  gfx.rect(x, y, w, h, 12)
  if title then
    gfx.icon(icon or "info", x + 26, y + 24, 20, theme.accent)
    gfx.color(theme.text)
    gfx.text(title, x + 44, y + 14, 15, "semibold")
  end
end

local function infoRow(label, value, x, y, w)
  gfx.color(theme.text2)
  gfx.text(label, x, y, 13)
  gfx.color(theme.text)
  gfx.text(value, x, y, 13, "semibold", "right", w)
end

local function drawRun(w, h)
  local st = STAGES[stageIdx]
  if not st then return end
  local t = sys.time() - runStart
  gfx.gradient(0, 0, w, h, "#141A2A", "#06080E")
  local a = t * 0.25
  g3d.begin(0, 0, w, h, 55)
  g3d.camera(sin(a) * 11, 4.5, cos(a) * 11, 0, 0, 0)
  g3d.light(0.5, 1, 0.4, 0.35)
  if st.fog then g3d.fog("#06080E", 10, 22) end
  st.fn(t)
  lastTris = g3d.finish()
  local r = results[stageIdx]
  if stageT > WARMUP then r.tris = r.tris + lastTris; r.trisN = r.trisN + 1 end
  -- HUD
  gfx.color(0, 0, 0, 150)
  gfx.rect(16, 16, 300, 112, 12)
  gfx.color("#FFFFFF")
  gfx.text(TR("stage_n", stageIdx, #STAGES), 30, 26, 12, "semibold")
  gfx.text(TR(st.key), 30, 42, 18, "bold")
  gfx.color(255, 255, 255, 190)
  gfx.text(TR("live", floor(sys.fps() + 0.5), lastTris), 30, 70, 13, "mono")
  ui.progress(((stageIdx - 1) + min(1, stageT / STAGE_TIME)) / #STAGES, 30, 100, 272, 6)
  -- frame time graph
  local gx, gy, gw, gh = w - 266, 16, 250, 90
  gfx.color(0, 0, 0, 150)
  gfx.rect(gx, gy, gw, gh, 10)
  gfx.color(255, 255, 255, 50)
  local y60 = gy + gh - (1 / 60) / (1 / 20) * (gh - 12) - 6
  gfx.line(gx + 8, y60, gx + gw - 8, y60, 1)
  gfx.color(255, 255, 255, 140)
  gfx.text(TR("graph"), gx + 10, gy + 6, 11, "semibold")
  if #frameLog >= 2 then
    local pts = {}
    for i, d in ipairs(frameLog) do
      pts[#pts + 1] = gx + 8 + (i - 1) / 149 * (gw - 16)
      pts[#pts + 1] = gy + gh - 6 - clamp(d / (1 / 20), 0, 1) * (gh - 12)
    end
    gfx.color(110, 220, 140)
    gfx.lines(pts, 1.5)
  end
  if ui.button(TR("stop"), w - 120, h - 56, 104, 36, "destructive", "stop") then state = "home" end
end

local function drawHome(w, h)
  gfx.clear(theme.bg)
  gfx.color(theme.text)
  gfx.text(TR("title"), 24, 20, 26, "bold")
  gfx.color(theme.text2)
  gfx.text(TR("subtitle", #STAGES, floor(#STAGES * STAGE_TIME)), 24, 56, 13)
  -- device
  local cw = (w - 64) / 2
  card(24, 90, cw, 214, TR("device"), "memory")
  local y = 132
  local pct, charging = sys.battery()
  local rows = {
    {TR("model"), sys.model()},
    {TR("firmware"), sys.firmware()},
    {TR("battery"), tostring(pct) .. "%" .. (charging and ("  " .. TR("charging")) or "")},
    {TR("runtime"), _VERSION or "Lua"},
    {TR("best_score"), best > 0 and tostring(best) or "—"},
  }
  for _, r in ipairs(rows) do
    infoRow(r[1], r[2], 40, y, cw - 32)
    y = y + 32
  end
  -- stages
  card(40 + cw, 90, cw, 214, TR("stages"), "layers")
  y = 132
  for i, s in ipairs(STAGES) do
    gfx.color(theme.text2)
    gfx.text(tostring(i) .. ".", 56 + cw, y, 13, "mono")
    gfx.color(theme.text)
    gfx.text(TR(s.key), 80 + cw, y, 13)
    y = y + 26
  end
  -- history
  card(24, 318, w - 48, h - 318 - 80, TR("history"), "history")
  if #history == 0 then
    gfx.color(theme.text3)
    gfx.text(TR("no_history"), 24, 380, 13, "sans", "center", w - 48)
  else
    local hy = 354
    local maxS = 1
    for _, e in ipairs(history) do maxS = max(maxS, e.score or 0) end
    local rowsFit = floor((h - 80 - hy - 10) / 24)
    for i = 1, min(#history, rowsFit) do
      local e = history[i]
      gfx.color(theme.text2)
      gfx.text(e.date or "", 40, hy, 12, "mono")
      local bx, bw = 200, w - 48 - 200 - 90
      gfx.color(theme.separator)
      gfx.rect(bx, hy + 4, bw, 10, 5)
      gfx.color(i == 1 and theme.accent or theme.gray)
      gfx.rect(bx, hy + 4, max(6, bw * (e.score or 0) / maxS), 10, 5)
      gfx.color(theme.text)
      gfx.text(tostring(e.score or 0), 0, hy, 13, "semibold", "right", w - 40)
      hy = hy + 24
    end
  end
  if ui.button(TR("start"), w / 2 - 110, h - 62, 220, 42, "primary", "speed") then startRun() end
end

local function drawResults(w, h)
  gfx.clear(theme.bg)
  gfx.color(theme.text)
  gfx.text(TR("results"), 24, 20, 26, "bold")
  gfx.color(isBest and theme.green or theme.text2)
  gfx.text(isBest and TR("new_best") or TR("best_is", best), 24, 56, 13, "semibold")
  -- score
  card(24, 88, 220, 150, nil)
  gfx.color(theme.text2)
  gfx.text(TR("score"), 24, 104, 13, "semibold", "center", 220)
  gfx.color(theme.accent)
  gfx.text(tostring(lastScore), 24, 128, 48, "bold", "center", 220)
  gfx.color(theme.text3)
  gfx.text(sys.model(), 24, 200, 11, "sans", "center", 220)
  -- table
  local tx, tw = 262, w - 262 - 24
  card(tx, 88, tw, 44 + #results * 34, nil)
  local cols = {TR("col_stage"), TR("col_tris"), TR("col_fps"), TR("col_min"), TR("col_ms")}
  local cx = {tx + 16, tx + tw * 0.42, tx + tw * 0.58, tx + tw * 0.72, tx + tw * 0.86}
  for i, c in ipairs(cols) do
    gfx.color(theme.text2)
    gfx.text(c, cx[i], 102, 12, "semibold")
  end
  for i, r in ipairs(results) do
    local y = 132 + (i - 1) * 34
    ui.separator(tx + 12, y - 6, tx + tw - 12)
    gfx.color(theme.text)
    gfx.text(TR(STAGES[i].key), cx[1], y + 2, 13)
    gfx.text(tostring(floor(r.avgTris or 0)), cx[2], y + 2, 13, "mono")
    local fps = r.fps or 0
    gfx.color(fps >= 55 and theme.green or (fps >= 30 and theme.orange or theme.red))
    gfx.text(string.format("%.1f", fps), cx[3], y + 2, 13, "monobold")
    gfx.color(theme.text2)
    gfx.text(string.format("%.0f", r.minFps or 0), cx[4], y + 2, 13, "mono")
    gfx.text(string.format("%.1f", r.ms or 0), cx[5], y + 2, 13, "mono")
  end
  gfx.color(theme.text3)
  gfx.wrap(TR("score_help"), 24, 256, 220, 11)
  if ui.button(TR("run_again"), w / 2 - 230, h - 62, 220, 42, "primary", "refresh") then startRun() end
  if ui.button(TR("done"), w / 2 + 10, h - 62, 220, 42, "default", "check") then state = "home" end
end

function app.draw(w, h)
  if state == "run" then drawRun(w, h)
  elseif state == "results" then drawResults(w, h)
  else drawHome(w, h) end
end

function app.event(e)
  if e.type == "keydown" then
    if e.key == "escape" and state == "run" then state = "home"
    elseif (e.key == "enter" or e.key == "space") and state ~= "run" then startRun() end
  end
end

function app.menu()
  return {{title = TR("benchmark"), items = {
    {label = TR("start"), id = 1, shortcut = "Enter"},
    {label = TR("stop"), id = 2, shortcut = "Esc"},
    "-",
    {label = TR("clear_history"), id = 3},
  }}}
end

function app.onmenu(id)
  if id == 1 then startRun()
  elseif id == 2 then if state == "run" then state = "home" end
  elseif id == 3 then
    ui.alert(TR("clear_history"), TR("clear_q"), {TR("clear"), TR("cancel")}, function(b)
      if b == 1 then history = {}; best = 0; store.set("history", {}); store.set("best", 0) end
    end)
  end
end

return app
