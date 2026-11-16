-- Crypt Light: creatures. Hollows patrol and hunt along the navigation grid, hounds sleep until they hear or see
-- the player, wisps drift through walls towards the lantern and drink its oil. The lantern flare stuns them.
local AI = {}
local sin, cos, pi, sqrt, abs, min, max, random, atan = math.sin, math.cos, math.pi, math.sqrt, math.abs, math.min, math.max, math.random, math.atan
local G
local list = {}
AI.list = list
local wispMesh, eyeMesh

local function d2(ax, az, bx, bz) local dx, dz = ax - bx, az - bz; return dx * dx + dz * dz end

function AI.init()
  if wispMesh then return end
  wispMesh = g3d.mesh("sphere", 0.08, 12, 8)
  wispMesh:setColor("#9FE8FF")
  eyeMesh = g3d.mesh("sphere", 0.025, 6, 4)
  eyeMesh:setColor("#FF3020")
end

local SPEC = {
  hollow = {model = "bundle:/models/chars/hero.glb", scale = {0.92, 1.06, 0.92}, tint = "#2A2826", walk = 1.15, run = 3.35, sight = 13, hear = 9,
    attack = 1.45, dmg = 25, eye = "head", eyeUp = 0.06, eyeFwd = 0.11, eyeSep = 0.045},
  hound = {model = "bundle:/models/chars/creature.glb", scale = {1.35, 1.25, 1.55}, tint = "#3A3632", walk = 1.6, run = 5.0, sight = 7, hear = 11,
    attack = 1.35, dmg = 22, eye = "head", eyeUp = 0.06, eyeFwd = 0.16, eyeSep = 0.06},
}

local function setClip(e, clip, speed, fade)
  if e.model and e.clip ~= clip then
    e.model:play(clip, {loop = clip ~= "attack" and clip ~= "hit" and clip ~= "death", speed = speed or 1, fade = fade or 0.2})
    e.clip = clip
  end
end

function AI.build(L, game, N)
  G = game
  AI.init()
  for i = #list, 1, -1 do list[i] = nil end
  for _, d in ipairs(L.def.ents) do
    if d.t == "hollow" or d.t == "hound" or d.t == "wisp" then
      local e = {kind = d.t, x = d.c[1] * 4, z = d.c[2] * 4, y = 0, yaw = 0, state = "idle", t = 0, stun = 0, cool = 0}
      e.homeX, e.homeZ = e.x, e.z
      if d.t ~= "wisp" then
        local s = SPEC[d.t]
        e.spec = s
        e.model = g3d.model(s.model)
        if e.model then
          g3d.material(e.model, {roughness = 0.85, metallic = 0.05})
        end
        e.y = game.groundAt(e.x, e.z) or 0
        e.agent = nav.agent(N, e.x, e.y, e.z, {speed = s.walk, radius = 0.4, turn = 6})
        e.patrol = {}
        for _, p in ipairs(d.patrol or {}) do e.patrol[#e.patrol + 1] = {p[1] * 4, p[2] * 4} end
        e.pi = 1
        e.state = (d.t == "hound") and "sleep" or "patrol"
        setClip(e, "idle")
      else
        e.y = 1.4
        e.phase = random() * 10
      end
      list[#list + 1] = e
    end
  end
end

-- line of sight from a creature's eyes to the player's eyes (walls and closed gates block it)
local function sees(e, px, py, pz)
  local ex, ey, ez = e.x, e.y + 1.5, e.z
  local dx, dy, dz = px - ex, py - ey, pz - ez
  local d = sqrt(dx * dx + dy * dy + dz * dz)
  if d < 0.01 then return true end
  local h = phys.raycast(G.L.phys, ex, ey, ez, dx / d, dy / d, dz / d, d, 1)
  return not h or h.dist > d - 0.4
end

local function goTo(e, x, z, speed)
  local N = G.N
  if not N or not e.agent then return end
  if speed and speed ~= e.speedSet then
    -- nav agents keep their speed; replace the agent to change it (keeps position)
    nav.removeAgent(N, e.agent)
    e.agent = nav.agent(N, e.x, e.y, e.z, {speed = speed, radius = 0.4, turn = 7})
    e.speedSet = speed
  end
  nav.goTo(N, e.agent, x, G.groundAt(x, z) or e.y, z)
  e.goal = {x, z}
end

-- 0..1: how much danger the player is in (drives the music)
AI.danger = 0

function AI.stunAll(px, pz, r)
  local n = 0
  for _, e in ipairs(list) do
    if d2(e.x, e.z, px, pz) < r * r then
      if e.kind == "wisp" then
        e.state, e.t = "banished", 0
        G.fx.burst("wisp", e.x, e.y, e.z, 30, 2.5, 1.0, 0.08)
      else
        e.stun = 3.2
        e.state = "stunned"
        if e.agent then nav.stop(G.N, e.agent) end
        setClip(e, "hit", 0.6)
      end
      n = n + 1
    end
  end
  return n
end

-- every creature now knows where the player is (the seal gate opened)
function AI.hunt(px, pz)
  for _, e in ipairs(list) do
    if e.kind ~= "wisp" then e.state, e.t, e.lastX, e.lastZ = "chase", 0, px, pz end
  end
end

function AI.wake(x, z, r)
  for _, e in ipairs(list) do
    if e.kind ~= "wisp" and d2(e.x, e.z, x, z) < r * r and (e.state == "patrol" or e.state == "sleep" or e.state == "idle") then
      e.state, e.t, e.lastX, e.lastZ = "search", 0, x, z
    end
  end
end

function AI.update(dt, P)
  local N = G.N
  local px, py, pz = P.x, P.y + 1.55, P.z
  local danger = 0
  local loud = P.running and 1 or (P.moving and 0.4 or 0.15)
  local lightK = 0.45 + P.lantern * 0.55
  if N then nav.update(N, dt) end
  for _, e in ipairs(list) do
    e.t = e.t + dt
    e.cool = max(0, e.cool - dt)
    local dist = sqrt(d2(e.x, e.z, P.x, P.z))
    if e.kind == "wisp" then
      -- drift towards the light, through anything
      if e.state == "banished" then
        if e.t > 18 then e.state, e.x, e.z = "idle", e.homeX, e.homeZ end
      else
        local wantR = 10 * lightK + 2
        if dist < wantR then
          e.state = "drawn"
          local sp = 1.25 + (P.lantern < 0.3 and 0.6 or 0)
          e.x = e.x + (P.x - e.x) / max(dist, 0.1) * sp * dt
          e.z = e.z + (P.z - e.z) / max(dist, 0.1) * sp * dt
          e.y = e.y + ((P.y + 1.3) - e.y) * min(1, dt)
          if dist < 2.4 then
            G.drainOil(7 * dt)
            danger = max(danger, 0.75)
            if random() < dt * 3 then G.fx.spawn("wisp", P.x + (random() - 0.5), P.y + 1.3, P.z + (random() - 0.5), (e.x - P.x) * 0.5, 0.2, (e.z - P.z) * 0.5, 0.8, 0.07, 0) end
          else
            danger = max(danger, 0.4)
          end
        else
          e.state = "idle"
          e.x = e.x + (e.homeX + sin(e.t * 0.3 + e.phase) * 2 - e.x) * dt * 0.3
          e.z = e.z + (e.homeZ + cos(e.t * 0.27 + e.phase) * 2 - e.z) * dt * 0.3
          e.y = 1.3 + sin(e.t * 0.9 + e.phase) * 0.3
        end
        if random() < dt * 14 then
          G.fx.spawn("wisp", e.x + (random() - 0.5) * 0.15, e.y, e.z + (random() - 0.5) * 0.15, (random() - 0.5) * 0.2, 0.15, (random() - 0.5) * 0.2, 1.2, 0.09, -0.05)
        end
        if random() < dt * 0.25 and dist < 14 then G.sfxAt("whisper", e.x, e.z, 0.6) end
      end
    else
      local s = e.spec
      if e.agent and N then
        local a = nav.agentState(N, e.agent)
        if a then e.x, e.y, e.z = a.x, a.y, a.z; e.tyaw = a.yaw; e.navState = a.state end
      end
      -- perception: sight needs light on the player (or closeness), hearing depends on steps
      local canSee = false
      if dist < s.sight * lightK + 1.5 then
        local fx, fz = sin(e.yaw), cos(e.yaw)
        local ddx, ddz = (P.x - e.x) / max(dist, 0.01), (P.z - e.z) / max(dist, 0.01)
        if (fx * ddx + fz * ddz) > 0.2 or dist < 2.5 then canSee = sees(e, px, py, pz) end
      end
      local heard = dist < s.hear * loud
      if e.state == "stunned" then
        e.stun = e.stun - dt
        if e.stun <= 0 then e.state, e.t, e.lastX, e.lastZ = "search", 0, P.x, P.z end
      elseif e.state == "sleep" then
        setClip(e, "idle", 0.5)
        if dist < 4.5 or (heard and P.running) or (canSee and dist < 6) then
          e.state, e.t, e.lastX, e.lastZ = "chase", 0, P.x, P.z
          G.sfxAt("growl", e.x, e.z, 1)
        end
      elseif e.state == "patrol" or e.state == "idle" then
        if canSee or heard then
          e.state, e.t, e.lastX, e.lastZ = canSee and "chase" or "search", 0, P.x, P.z
          G.sfxAt(e.kind == "hound" and "growl" or "shriek", e.x, e.z, 1)
        elseif e.kind == "hollow" and #e.patrol > 0 then
          if e.navState ~= "moving" or not e.goal then
            if e.waitT and e.waitT > 0 then
              e.waitT = e.waitT - dt
              setClip(e, "idle", 0.8)
            else
              local p = e.patrol[e.pi]
              e.pi = e.pi % #e.patrol + 1
              goTo(e, p[1], p[2], s.walk)
              e.waitT = 1.2 + random() * 1.5
              setClip(e, "walk", 0.75)
            end
          end
          if random() < dt * 0.08 and dist < 16 then G.sfxAt("groan", e.x, e.z, 0.7) end
        elseif e.kind == "hound" then
          if d2(e.x, e.z, e.homeX, e.homeZ) > 1 and e.navState ~= "moving" then goTo(e, e.homeX, e.homeZ, s.walk) end
          if e.navState ~= "moving" then e.state = "sleep" end
        end
      elseif e.state == "chase" or e.state == "search" then
        if canSee then e.state, e.lastX, e.lastZ, e.lost = "chase", P.x, P.z, 0 end
        if heard then e.lastX, e.lastZ = P.x, P.z end
        local chasing = e.state == "chase"
        e.repath = (e.repath or 0) - dt
        if e.repath <= 0 then
          goTo(e, e.lastX, e.lastZ, chasing and s.run or s.walk * 1.4)
          e.repath = chasing and 0.35 or 1.0
        end
        setClip(e, chasing and "run" or "walk", chasing and 1.0 or 1.0)
        if chasing then danger = max(danger, dist < 18 and 1 or 0.5) else danger = max(danger, 0.5) end
        if not canSee then
          e.lost = (e.lost or 0) + dt
          if e.lost > 2.5 and chasing then e.state = "search" end
          if e.lost > (e.kind == "hound" and 7 or 12) then e.state, e.lost, e.goal = (e.kind == "hound") and "idle" or "patrol", 0, nil end
        end
        -- attack
        if dist < s.attack and e.cool <= 0 and canSee then
          e.state, e.t = "attack", 0
          if e.agent then nav.stop(N, e.agent) end
          setClip(e, "attack", 1.25)
          G.sfxAt(e.kind == "hound" and "bite" or "swing", e.x, e.z, 1)
        end
      elseif e.state == "attack" then
        danger = 1
        if e.t > 0.42 and not e.hit then
          e.hit = true
          if dist < s.attack + 0.4 then G.damage(s.dmg, e.x, e.z) end
        end
        if e.t > 0.9 then e.state, e.hit, e.cool = "chase", nil, 1.3 end
      end
      -- face the movement (or the player while attacking)
      local want = e.tyaw or e.yaw
      if e.state == "attack" or e.state == "stunned" then want = atan(P.x - e.x, P.z - e.z) end
      local dy = (want - e.yaw + pi) % (2 * pi) - pi
      e.yaw = e.yaw + dy * min(1, dt * 8)
      if e.model then e.model:update(dt) end
      if e.state ~= "patrol" and e.state ~= "sleep" and e.state ~= "idle" then danger = max(danger, dist < 14 and 0.45 or 0.3) end
      -- footsteps of creatures
      if e.navState == "moving" then
        e.stepT = (e.stepT or 0) - dt
        if e.stepT <= 0 then
          e.stepT = (e.state == "chase") and 0.3 or 0.6
          G.sfxAt(e.kind == "hound" and "pad" or "drag", e.x, e.z, e.state == "chase" and 0.8 or 0.45, 14)
        end
      end
    end
  end
  AI.danger = danger
end

function AI.draw(t, cx, cz, fx, fz)
  for _, e in ipairs(list) do
    local dx, dz = e.x - cx, e.z - cz
    if dx * dx + dz * dz < 28 * 28 then
      if e.kind == "wisp" then
        if e.state ~= "banished" then
          local p = 1 + sin(t * 6 + e.phase) * 0.15
          g3d.draw(wispMesh, e.x, e.y, e.z, 0, 0, 0, p, p, p, "#BFF4FF", "glow unlit")
          G.fx.spawn("wisp", e.x, e.y, e.z, 0, 0, 0, 0.12, 0.7 * p, 0)
        end
      elseif e.model then
        local s = e.spec.scale
        g3d.draw(e.model, e.x, e.y, e.z, 0, e.yaw, 0, s[1], s[2], s[3], e.spec.tint)
        -- glowing eyes at the head
        local hx, hy, hz = e.model:node(e.spec.eye, e.x, e.y, e.z, 0, e.yaw, 0, s[1], s[2], s[3])
        if hx then
          local fx2, fz2 = sin(e.yaw), cos(e.yaw)
          local rx, rz = fz2, -fx2
          local f, u, sp = e.spec.eyeFwd, e.spec.eyeUp, e.spec.eyeSep
          local col = e.state == "stunned" and "#402010" or "#FF3A1C"
          g3d.draw(eyeMesh, hx + fx2 * f + rx * sp, hy + u, hz + fz2 * f + rz * sp, 0, 0, 0, 1, 1, 1, col, "glow unlit")
          g3d.draw(eyeMesh, hx + fx2 * f - rx * sp, hy + u, hz + fz2 * f - rz * sp, 0, 0, 0, 1, 1, 1, col, "glow unlit")
        end
      end
    end
  end
end

-- wisps light the area around them
function AI.lights(out, px, pz)
  for _, e in ipairs(list) do
    if e.kind == "wisp" and e.state ~= "banished" then
      local dx, dz = e.x - px, e.z - pz
      out[#out + 1] = {x = e.x, y = e.y, z = e.z, color = "#7FD8FF", int = 2.6, range = 4.5, d2 = dx * dx + dz * dz}
    end
  end
end

return AI
