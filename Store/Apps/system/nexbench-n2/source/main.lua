-- NexBench N2: Deterministic System Benchmark & 440K-Polygon NexGFX PBR 3D Showcase
local app = {}

local PHASES = {
  { id = 1, key = "phase_1", dur = 6.0  }, -- CPU & Lua 5.4.7 GenGC
  { id = 2, key = "phase_2", dur = 5.0  }, -- Storage, JSON & Memory I/O
  { id = 3, key = "phase_3", dur = 8.0  }, -- 2D NexGFX & NXUI Stress
  { id = 4, key = "phase_4", dur = 8.0  }, -- 3D Instanced Geometry
  { id = 5, key = "phase_5", dur = 25.0 }, -- 440K-Poly PBR Lights & Shadows
}

local TOTAL_DUR = 52.0
local mode = "home"          -- "home", "bench", "showcase"
local activeTab = 0          -- 0-based in nxui.tabs: 0: Benchmark, 1: Scoreboard, 2: History
local selectedHistRow = 0
local muted = false
local paused = false

local activeRenderer = "basic"
local modelsLoaded = 0
local droneModel = nil

-- Procedural meshes for Phase 4 & PBR arena
local floorMesh, pillarMesh, coreMesh, bulbMesh
local pillarTransforms = {}
local droneTransforms = {}
local lightWarm, lightCool, lightSpot

-- Telemetry & benchmark state
local phaseIdx = 1
local phaseTime = 0
local totalElapsed = 0
local tAnim = 0
local lastTris = 0
local lastPolys = 0
local lastFrameMs = 16.6

local phaseWork = { 0, 0, 0, 0, 0 }
local phaseFrames = { 0, 0, 0, 0, 0 }
local history = {}
local currentRun = nil

local function playCue(freq, dur)
  if not muted then
    audio.tone(freq, dur or 0.08, 0.20, "sine")
  end
end

local function buildInstancedLayouts()
  -- 64 outer arena monolithic pillars
  pillarTransforms = {}
  for i = 0, 63 do
    local a = (i / 64) * math.pi * 2
    local ring = (i % 2 == 0) and 16.5 or 21.0
    local x = math.cos(a) * ring
    local z = math.sin(a) * ring
    local sc = (i % 2 == 0) and 1.0 or 1.45
    local list = { x, 2.2 * sc, z, 0, -a, 0, sc }
    for _, v in ipairs(list) do pillarTransforms[#pillarTransforms + 1] = v end
  end

  -- 64 MaintenanceDrone_A units (64 * 6,872 polys = 439,808 polys / 785,152 tris)
  droneTransforms = {}
  for i = 0, 63 do
    local ringIdx = math.floor(i / 16)
    local idxInRing = i % 16
    local radius = 3.6 + ringIdx * 2.8
    local a = (idxInRing / 16) * math.pi * 2 + ringIdx * 0.2
    local x = math.cos(a) * radius
    local z = math.sin(a) * radius
    local y = 1.6 + ringIdx * 0.9
    local list = { x, y, z, 0, -a + math.pi * 0.5, 0, 1.0 }
    for _, v in ipairs(list) do droneTransforms[#droneTransforms + 1] = v end
  end
end

local function applyPbrSettings()
  activeRenderer = g3d.renderer("pbr")
  g3d.shadows({ enabled = true, quality = "medium", distance = 38 })
  g3d.postfx({ exposure = 1.08, tonemap = "aces", bloom = 0.12, threshold = 0.95 })
  g3d.environment({ sky = "#182438", ground = "#10141C", intensity = 1.05, sun = 2.8 })
end

function app.load(arg)
  history = store.get("history", {})
  muted = store.get("muted", false)

  floorMesh = g3d.mesh("plane", 64, 64, 1)
  floorMesh:setColor("#2C333E")
  g3d.material(floorMesh, { metallic = 0.35, roughness = 0.42 })

  pillarMesh = g3d.mesh("box", 0.7, 4.4, 0.7)
  pillarMesh:setColor("#586374")
  g3d.material(pillarMesh, { metallic = 0.65, roughness = 0.35 })

  coreMesh = g3d.mesh("sphere", 1.15, 32, 24)
  coreMesh:setColor("#D8A24A")
  g3d.material(coreMesh, { metallic = 0.9, roughness = 0.18 })

  bulbMesh = g3d.mesh("sphere", 0.14, 14, 10)
  bulbMesh:setColor("#48C9FF")
  g3d.material(bulbMesh, { emissive = "#48C9FF", emissiveStrength = 8.0 })

  lightWarm = g3d.addLight({ type = "point", x = 4, y = 4.0, z = 4, color = "#FF9A3C", intensity = 16, range = 20 })
  lightCool = g3d.addLight({ type = "point", x = -4, y = 4.0, z = -4, color = "#3CC8FF", intensity = 16, range = 20 })
  lightSpot = g3d.addLight({
    type = "spot", x = 0, y = 13, z = 0, dx = 0, dy = -1, dz = 0,
    color = "#FFFFFF", intensity = 60, range = 30, inner = 16, outer = 28, shadow = true
  })

  buildInstancedLayouts()
  applyPbrSettings()

  g3d.loadModel("bundle:/models/drone.glb", 1.15, function(m, err)
    if m then droneModel = m end
    modelsLoaded = modelsLoaded + 1
  end)

  if arg and arg.autostart then
    mode = "bench"
    phaseIdx = 1
    phaseTime = 0
    totalElapsed = 0
  end
end

local function startBenchmark()
  mode = "bench"
  phaseIdx = 1
  phaseTime = 0
  totalElapsed = 0
  phaseWork = { 0, 0, 0, 0, 0 }
  phaseFrames = { 0, 0, 0, 0, 0 }
  playCue(523.25, 0.10)
end

local function finishBenchmark()
  local cpuScore = math.floor(phaseWork[1] * 0.12 + phaseFrames[1] * 18)
  local memScore = math.floor(phaseWork[2] * 1.4 + phaseFrames[2] * 14)
  local gfx2dScore = math.floor(phaseFrames[3] * 32)
  local g3dBasicScore = math.floor(phaseFrames[4] * 36)
  local g3dPbrScore = math.floor(phaseFrames[5] * 28 + (activeRenderer == "pbr" and 2500 or 0))
  local total = cpuScore + memScore + gfx2dScore + g3dBasicScore + g3dPbrScore

  local totalFrames = phaseFrames[1] + phaseFrames[2] + phaseFrames[3] + phaseFrames[4] + phaseFrames[5]
  local avgFps = math.floor((totalFrames / TOTAL_DUR) * 10 + 0.5) / 10

  local d = sys.date()
  local dateStr = string.format("%04d-%02d-%02d %02d:%02d", d.year or 2026, d.month or 1, d.day or 1, d.hour or 0, d.min or 0)

  currentRun = {
    date = dateStr,
    os = sys.firmware(),
    sdk = sys.sdkVersion(),
    renderer = activeRenderer,
    total = total,
    cpu = cpuScore,
    mem = memScore,
    gfx2d = gfx2dScore,
    g3dBasic = g3dBasicScore,
    g3dPbr = g3dPbrScore,
    avgFps = avgFps,
    peakTris = lastTris,
  }

  table.insert(history, 1, currentRun)
  while #history > 25 do table.remove(history) end
  store.set("history", history)
  store.save()
  fs.write("nexbench_results.json", json.encode(history))

  mode = "home"
  activeTab = 1 -- Scoreboard tab (0-based)
  playCue(659.25, 0.12)
end

local function stepCpuWorkload()
  local sum = 0
  local tmp = {}
  for i = 1, 220 do
    local x = math.sin(i * 0.13 + tAnim) * math.cos(i * 0.07)
    tmp[i] = { x = x, y = x * x, z = math.sqrt(math.abs(x) + 1.0) }
    sum = sum + tmp[i].z
  end
  phaseWork[1] = phaseWork[1] + 220 + math.floor(sum * 0.01)
end

local function stepIoWorkload()
  local payload = json.encode({
    tick = phaseFrames[2],
    samples = { 101, 202, 303, 404, 505, 606, 707, 808 },
    tag = "nexbench_io_probe"
  })
  fs.write("nexbench_io_tmp.json", payload)
  local readBack = fs.read("nexbench_io_tmp.json")
  if readBack then
    local decoded = json.decode(readBack)
    if decoded and decoded.tick then
      phaseWork[2] = phaseWork[2] + #readBack
    end
  end
  if phaseTime + 0.05 >= PHASES[2].dur then
    fs.remove("nexbench_io_tmp.json")
  end
end

function app.update(dt)
  if paused then return end
  if dt > 0.1 then dt = 0.1 end
  tAnim = tAnim + dt
  lastFrameMs = dt * 1000.0

  if mode == "bench" then
    phaseTime = phaseTime + dt
    totalElapsed = totalElapsed + dt
    phaseFrames[phaseIdx] = phaseFrames[phaseIdx] + 1

    if phaseIdx == 1 then
      stepCpuWorkload()
    elseif phaseIdx == 2 then
      stepIoWorkload()
    end

    if phaseTime >= PHASES[phaseIdx].dur then
      phaseIdx = phaseIdx + 1
      phaseTime = 0
      if phaseIdx > #PHASES then
        finishBenchmark()
        return
      end
      playCue(440 + phaseIdx * 55, 0.07)
    end
  end

  if mode == "showcase" or (mode == "bench" and phaseIdx >= 4) then
    g3d.updateLight(lightWarm, {
      x = math.cos(tAnim * 0.9) * 8.5,
      y = 4.0 + math.sin(tAnim * 1.5) * 0.8,
      z = math.sin(tAnim * 0.9) * 8.5
    })
    g3d.updateLight(lightCool, {
      x = math.cos(tAnim * 0.7 + 3.14) * 8.5,
      y = 3.6 + math.cos(tAnim * 1.3) * 0.8,
      z = math.sin(tAnim * 0.7 + 3.14) * 8.5
    })
    g3d.updateLight(lightSpot, {
      dx = math.sin(tAnim * 0.6) * 0.35,
      dy = -1.0,
      dz = math.cos(tAnim * 0.45) * 0.35
    })
  end
end

local function drawLiveHud(w, h, labelText, progress)
  gfx.rect(0, 0, w, 46, 0, "#0A0E17CC")
  gfx.color("#FFFFFF")
  gfx.text(labelText, 16, 10, 15, "bold")

  local fpsVal = math.floor(sys.fps() + 0.5)
  local memVal = math.floor((sys.memory() / 1024) * 10 + 0.5) / 10
  local stats = string.format(
    "%s | %s | %s | %s | %s",
    TR("hud_fps", fpsVal),
    TR("hud_ms", string.format("%.1f", lastFrameMs)),
    TR("hud_tris", lastTris),
    TR("hud_mem", memVal),
    TR("hud_ren", activeRenderer)
  )
  gfx.color("#7AD7FF")
  gfx.text(stats, 16, 28, 12)

  if progress then
    local bw = w - 32
    gfx.rect(16, h - 22, bw, 8, 4, "#1C2434")
    gfx.rect(16, h - 22, bw * math.max(0, math.min(1, progress)), 8, 4, "#3AA0FF")
  end

  if ui.button(TR("btn_stop"), w - 106, 8, 90, 30, "danger") then
    mode = "home"
    playCue(330, 0.07)
  end
end

local function drawPhase1Or2Scene(w, h, title)
  gfx.gradient(0, 0, w, h, "#0D1320", "#17223B", "vertical")
  local cx, cy = w * 0.5, h * 0.52
  for i = 1, 24 do
    local a = tAnim * (0.7 + i * 0.04) + i * 0.26
    local r = 36 + i * 7.5
    gfx.color(i % 2 == 0 and "#3AA0FF88" or "#FF9A3C88")
    gfx.circle(cx + math.cos(a) * r, cy + math.sin(a) * r * 0.6, 6 + (i % 5) * 2)
  end
  gfx.color("#FFFFFF")
  gfx.text(title, 0, h * 0.5 - 12, 22, "bold", "center", w)
end

local function drawPhase3_2dStress(w, h)
  gfx.gradient(0, 0, w, h, "#101624", "#1B2845", "vertical")
  for i = 1, 140 do
    local a = tAnim * 1.4 + i * 0.41
    local rad = (i * 4.5) % (math.min(w, h) * 0.44)
    local px = w * 0.5 + math.cos(a) * rad
    local py = h * 0.52 + math.sin(a * 1.3) * rad * 0.72
    local col = (i % 3 == 0) and "#38BDF8AA" or ((i % 3 == 1) and "#F472B6AA" or "#FBBF24AA")
    gfx.color(col)
    gfx.circle(px, py, 5 + (i % 7) * 2)
  end
  for r = 1, 8 do
    local y = 68 + r * 44
    gfx.rect(40, y, (w - 80) * (0.4 + 0.5 * math.abs(math.sin(tAnim + r))), 16, 8, "#2563EBAA")
  end
end

local function draw3dArena(w, h, pbrHeavy)
  gfx.clear("#0B0F17")
  g3d.begin(0, 0, w, h, 55, 0.1, 140)
  local camDist = pbrHeavy and (13.5 + math.sin(tAnim * 0.35) * 3.0) or 19.0
  local camH = pbrHeavy and (5.5 + math.sin(tAnim * 0.25) * 1.6) or 7.5
  g3d.camera(math.sin(tAnim * 0.28) * camDist, camH, math.cos(tAnim * 0.28) * camDist, 0, 1.8, 0)
  g3d.light(0.45, 0.85, 0.35, 0.28, "#FFF1DD")
  g3d.fog("#0B0F17", 28, 85)

  g3d.draw(floorMesh, 0, 0, 0)
  g3d.drawInstanced(pillarMesh, pillarTransforms)
  g3d.draw(coreMesh, 0, 2.2 + math.sin(tAnim * 2.0) * 0.3, 0, 0, tAnim * 0.9, 0)

  if pbrHeavy and droneModel then
    for i = 0, 63 do
      local ringIdx = math.floor(i / 16)
      droneTransforms[i * 7 + 2] = 1.6 + ringIdx * 0.9 + math.sin(tAnim * 2.2 + i * 0.4) * 0.45
      droneTransforms[i * 7 + 5] = droneTransforms[i * 7 + 5] + 0.01
    end
    g3d.drawInstanced(droneModel, droneTransforms)
    lastPolys = 64 * 6872 + 64 * 6
  else
    if droneModel then
      -- Warm up droneModel GPU upload during Phase 4 so Phase 5 stays smooth
      g3d.draw(droneModel, 0, -40, 0, 0, 0, 0, 0.01)
    end
    g3d.drawInstanced(coreMesh, droneTransforms)
    lastPolys = 64 * 1500 + 64 * 6
  end

  local lx = math.cos(tAnim * 0.9) * 8.5
  local lz = math.sin(tAnim * 0.9) * 8.5
  g3d.draw(bulbMesh, lx, 4.0, lz, 0, 0, 0, 1, 1, 1, nil, activeRenderer == "pbr" and "" or "unlit")
  lastTris = g3d.finish()
end

local function drawHomeDashboard(w, h)
  local t = nxui.tokens()
  gfx.clear(t.windowBg)
  nxui.begin(w, h)
  nxui.column("root", t.space3)

  nxui.card("hdr_card")
    nxui.label("t_main", TR("title"), "title")
    nxui.label("t_sub", TR("subtitle"), "caption")
  nxui.cardEnd()

  activeTab = nxui.tabs("tabs", { TR("tab_run"), TR("tab_results"), TR("tab_history") }, activeTab)

  if activeTab == 0 then
    nxui.card("run_card")
      if modelsLoaded < 1 then
        nxui.label("load_st", TR("loading_models", modelsLoaded), "headline")
      else
        nxui.label("ready_st", TR("ready_msg"), "headline")
      end
      nxui.label("sys_st", TR("sys_info", sys.firmware(), sys.sdkVersion(), activeRenderer), "caption")
      nxui.spacer(t.space2)
      nxui.row("actions", t.space3)
        if nxui.button("btn_run", TR("btn_start"), "primary") then
          startBenchmark()
        end
        if nxui.button("btn_show", TR("btn_showcase"), "default") then
          mode = "showcase"
          playCue(587.33, 0.08)
        end
        if nxui.button("btn_mute", muted and TR("btn_unmute") or TR("btn_mute"), "default") then
          muted = not muted
          store.set("muted", muted)
          if muted then audio.stopAll() end
        end
      nxui.rowEnd()
    nxui.cardEnd()
  elseif activeTab == 1 then
    local run = currentRun or history[1]
    if not run then
      nxui.card("empty_res")
        nxui.label("no_h", TR("no_history"), "body")
      nxui.cardEnd()
    else
      nxui.card("res_card")
        nxui.label("tot_lbl", TR("score_total") .. ": " .. tostring(run.total), "largeTitle")
        if history[2] and history[2].total > 0 then
          local pct = math.floor(((run.total - history[2].total) / history[2].total) * 1000 + 0.5) / 10
          local sign = pct >= 0 and "+" or ""
          nxui.badge("delta_b", TR("prev_delta", sign .. tostring(pct) .. "%"), pct >= 0 and "#16A34AFF" or "#DC2626FF")
        end
        nxui.spacer(t.space2)
        local rows = {
          { TR("score_cpu"), tostring(run.cpu) },
          { TR("score_mem"), tostring(run.mem) },
          { TR("score_2d"), tostring(run.gfx2d) },
          { TR("score_3d_basic"), tostring(run.g3dBasic) },
          { TR("score_3d_pbr"), tostring(run.g3dPbr) },
          { TR("col_fps"), tostring(run.avgFps) .. " (" .. tostring(run.renderer) .. ")" },
        }
        nxui.table("res_tbl", { "Subsystem", "Score" }, rows, 0)
      nxui.cardEnd()
    end
  else
    if #history == 0 then
      nxui.card("empty_h")
        nxui.label("no_h2", TR("no_history"), "body")
      nxui.cardEnd()
    else
      local rows = {}
      for i = 1, #history do
        local r = history[i]
        rows[i] = { r.date, r.os, tostring(r.total), tostring(r.g3dPbr), tostring(r.avgFps) }
      end
      selectedHistRow = nxui.table("hist_tbl", { TR("col_date"), TR("col_os"), TR("col_total"), TR("col_pbr"), TR("col_fps") }, rows, selectedHistRow)
    end
  end

  nxui.columnEnd()
  nxui.endFrame()
end

function app.draw(w, h)
  if mode == "bench" then
    local ph = PHASES[phaseIdx]
    if phaseIdx == 1 or phaseIdx == 2 then
      drawPhase1Or2Scene(w, h, TR(ph.key))
    elseif phaseIdx == 3 then
      drawPhase3_2dStress(w, h)
    elseif phaseIdx == 4 then
      draw3dArena(w, h, false)
    else
      draw3dArena(w, h, true)
    end
    drawLiveHud(w, h, TR(ph.key), totalElapsed / TOTAL_DUR)
  elseif mode == "showcase" then
    draw3dArena(w, h, true)
    drawLiveHud(w, h, TR("phase_5") .. " (" .. TR("hud_polys", lastPolys) .. ")", nil)
  else
    drawHomeDashboard(w, h)
  end
end

function app.event(e)
  if e.type == "paddown" then
    if e.pad == "up" then nxui.moveFocus(0)
    elseif e.pad == "down" then nxui.moveFocus(1)
    elseif e.pad == "left" then nxui.moveFocus(2)
    elseif e.pad == "right" then nxui.moveFocus(3)
    elseif e.pad == "a" then
      if mode == "home" and activeTab == 0 then
        startBenchmark()
      else
        nxui.activateFocused()
      end
    elseif e.pad == "b" and mode ~= "home" then
      mode = "home"
    end
  elseif e.type == "keydown" then
    if (e.key == "enter" or e.key == "space") and mode == "home" then
      startBenchmark()
    elseif e.key == "escape" and mode ~= "home" then
      mode = "home"
    end
  end
end

function app.suspend()
  paused = true
  audio.stopAll()
end

function app.resume()
  paused = false
end

function app.focus(focused)
  paused = not focused
  if not focused then audio.stopAll() end
end

return app
