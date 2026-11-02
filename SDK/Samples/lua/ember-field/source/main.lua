-- Ember Field
-- Ember Field: a small, complete 3D game for Nexvyn OS SDK 1.8 (Lua). Walk a round courier bird across a floating
-- island at dusk, collect the embers and dodge the rolling stones. Three lamps, then it is over.
--
-- What it shows (the recipe is docs/MAKE_A_GAME.en.md, "Make a game", in the SDK guides):
--   * g3d.loadModel: the models load in the background while the title screen is already drawing
--   * a skinned .glb with three clips: "Idle" and "Run" loop, "Hop" plays once; crossfades with {fade = ...}
--   * an attachment: the glow halo follows the "Lamp" bone through model:nodeMatrix + g3d.drawMatrix
--   * a heightmap island built with g3d.custom; the same height function keeps the hero on the ground
--   * collision without a physics engine: circle vs circle (stones, embers, tree trunks) and the island edge
--   * states (title, play, pause, over), controller + keyboard + touch, pause on +, suspend and focus loss
--   * an art direction of its own: the palette, the letter-spaced titles with an offset print, the horizontal menu
--     and the wavy underline are this game's. Do not copy them into your game: pick your own (the guide shows how).
--
-- models/pip.glb and models/rock.glb were made with Blender from a script (art/make_models.py next to the sample; the icon is
-- rendered by art/make_keyart.py).

local app = {}

-- palette: dusk ink, a warm horizon, one hot accent
local INK, DUSK, PLUM, APRICOT, CORAL, CREAM = "#17142A", "#3A2C55", "#6B3E6E", "#F3B37A", "#FF6F59", "#FFF1DC"

local sqrt, sin, cos, min, max, abs, pi = math.sqrt, math.sin, math.cos, math.min, math.max, math.abs, math.pi
local floor, random = math.floor, math.random

local R = 10.5                      -- island radius in metres
local WALK = 9.4                    -- the hero stays inside this radius
local pip, rockModel, loadErr       -- models arrive from g3d.loadModel
local ground, ember, halo, crown, trunk, shadow
local trees = {}
local state = "title"               -- "title", "howto", "play", "pause", "over"
local sel = 1
local rects = {}                    -- menu hit boxes of the current frame
local held = {}                     -- keyboard keys held down
local hero = {x = 0, z = 0, vx = 0, vz = 0, yaw = 0, lamps = 3, hurt = 0, clip = ""}
local embers, rocks = {}, {}
local score, best, clock, shake, newBest = 0, 0, 0, 0, false
local cam = {x = 0, y = 7, z = 9}
local stick = {on = false, x0 = 0, y0 = 0, x = 0, y = 0}
local sparks = {}
local wave = {}
local W, H = 960, 540

-- ------------------------------------------------------------------ world
local function height(x, z)
    local d = sqrt(x * x + z * z) / R
    local h = 0.35 * sin(x * 0.45) * cos(z * 0.38) + 0.18 * sin((x + z) * 0.8)
    return h * max(0, 1 - d * d) - max(0, d - 0.92) * 6         -- the shore drops away: a floating island
end

local function buildGround()
    local N, size = 34, R * 2.3
    local V, I, C = {}, {}, {}
    local step = size / (N - 1)
    for j = 0, N - 1 do
        for i = 0, N - 1 do
            local x, z = -size / 2 + i * step, -size / 2 + j * step
            local y = height(x, z)
            V[#V + 1], V[#V + 2], V[#V + 3] = x, y, z
            local k = 0.5 + y * 0.9 + (((i * 7 + j * 13) % 5) - 2) * 0.03   -- a little noise breaks the bands
            if y < -0.3 then C[#C + 1] = {74, 46, 84}                       -- cliff
            else C[#C + 1] = {floor(48 + 40 * k), floor(92 + 50 * k), floor(80 + 24 * k)} end
        end
    end
    for j = 0, N - 2 do
        for i = 0, N - 2 do
            local a = j * N + i + 1
            local b, c, d = a + 1, a + N, a + N + 1
            I[#I + 1], I[#I + 2], I[#I + 3] = a, c, b
            I[#I + 1], I[#I + 2], I[#I + 3] = b, c, d
        end
    end
    return g3d.custom(V, I, C, true)                                         -- flat shading: a faceted look
end

local function spawnEmber(e)
    for _ = 1, 20 do                                                         -- not right under the hero
        local a, d = random() * 2 * pi, 1.5 + random() * 6.8
        e.x, e.z = cos(a) * d, sin(a) * d
        if (e.x - hero.x) ^ 2 + (e.z - hero.z) ^ 2 > 9 then break end
    end
    e.phase = random() * 6
    return e
end

local function spawnRock(r)
    local a = random() * 2 * pi
    r.x, r.z = cos(a) * R * 0.98, sin(a) * R * 0.98
    local tx, tz = (random() - 0.5) * 6, (random() - 0.5) * 6                -- roll across the middle
    local dx, dz = tx - r.x, tz - r.z
    local len = sqrt(dx * dx + dz * dz)
    local speed = min(5.2, 2.3 + clock * 0.035)
    r.vx, r.vz, r.spin = dx / len * speed, dz / len * speed, 0
    r.s = 0.8 + random() * 0.5                                               -- scale; the model is 0.9 m wide
    r.age = 0
    return r
end

local function reset()
    hero.x, hero.z, hero.vx, hero.vz, hero.yaw, hero.lamps, hero.hurt = 0, 0, 0, 0, 0, 3, 0
    score, clock, shake, newBest = 0, 0, 0, false
    for i = 1, 6 do embers[i] = spawnEmber(embers[i] or {}) end
    for i = #rocks, 1, -1 do rocks[i] = nil end
end

local function playClip(name, opts)
    if pip and hero.clip ~= name then
        hero.clip = name
        pip:play(name, opts)
    end
end

-- ------------------------------------------------------------------ sound and feel
local function chime()
    audio.tone(880, 0.08, 0.25, "triangle")
    timer.after(0.07, function() audio.tone(1318, 0.14, 0.22, "triangle") end)
    sys.vibrate(0.25, 40)
end

local function thud()
    audio.tone(96, 0.3, 0.45, "saw")
    audio.tone(60, 0.25, 0.35, "noise")
    sys.vibrate(0.85, 160)
end

-- ------------------------------------------------------------------ states
local function go(s)
    state, sel = s, 1
    if s == "play" then
        reset()
        playClip("Idle", {fade = 0.2})
    elseif s == "title" then
        playClip("Idle", {fade = 0.3})
    end
end

local function items()
    if state == "title" then return {"play", "howto", "leave"}
    elseif state == "pause" then return {"resume", "title"}
    elseif state == "over" then return {"again", "title"} end
    return {}
end

local function activate(id)
    if id == "play" or id == "again" then
        if pip and rockModel then go("play") end
    elseif id == "howto" then state = "howto"
    elseif id == "leave" then sys.exit()
    elseif id == "resume" then state = "play"
    elseif id == "title" then go("title") end
end

local function pause()
    if state == "play" then
        state, sel = "pause", 1
        stick.on = false
    end
end

-- ------------------------------------------------------------------ app callbacks
function app.load(arg)
    best = store.get("best", 0)
    g3d.loadModel("bundle:/models/pip.glb", function(m, err)                 -- the app keeps drawing meanwhile
        if m then pip = m; playClip("Idle") else loadErr = err end
    end)
    g3d.loadModel("bundle:/models/rock.glb", 0.9, function(m, err)           -- 0.9 m wide, standing on y = 0
        if m then rockModel = m else loadErr = err end
    end)
    ground = buildGround()
    ember = g3d.mesh("sphere", 0.16, 12, 8)
    ember:setColor("#FFD27A")
    halo = g3d.mesh("sphere", 0.45, 16, 10)
    halo:setColor("#5A3212")                                                 -- dark: "glow" adds it to the scene
    crown = g3d.mesh("cone", 0.7, 1.9, 7)
    crown:setColor("#24524A")
    trunk = g3d.mesh("cylinder", 0.12, 0.6, 6)
    trunk:setColor("#3B2A2A")
    shadow = g3d.mesh("cylinder", 0.4, 0.02, 14)
    shadow:setColor("#0B0A1666")                                             -- translucent blob shadow
    for i = 1, 16 do
        local a = i / 16 * 2 * pi + (i % 3) * 0.13
        local d = 8.6 + (i % 4) * 0.35
        local x, z = cos(a) * d, sin(a) * d
        trees[i] = {x = x, z = z, y = height(x, z), s = 0.8 + (i % 5) * 0.12}
    end
    for i = 1, 40 do
        sparks[i] = {x = random(), y = random(), v = 0.02 + random() * 0.05, r = 1 + random() * 2.5, p = random() * 6}
    end
    reset()
end

function app.update(dt)
    dt = min(dt, 0.05)
    for _, s in ipairs(sparks) do                                            -- title screen embers
        s.y = s.y - s.v * dt
        if s.y < -0.05 then s.y, s.x = 1.05, random() end
    end
    if state ~= "play" then
        if pip and state ~= "pause" then pip:update(dt) end
        return
    end
    clock = clock + dt
    shake = max(0, shake - dt * 2.5)
    hero.hurt = max(0, hero.hurt - dt)

    -- input: stick, d-pad, keys or the touch stick, as one vector (x right, z towards the camera)
    local mx, my = input.stick("left")
    local mz = -my
    if input.down("left") or held.left or held.a then mx = -1 end
    if input.down("right") or held.right or held.d then mx = 1 end
    if input.down("up") or held.up or held.w then mz = -1 end
    if input.down("down") or held.down or held.s then mz = 1 end
    if stick.on then
        local dx, dy = stick.x - stick.x0, stick.y - stick.y0
        local len = sqrt(dx * dx + dy * dy)
        if len > 8 then mx, mz = dx / max(len, 50), dy / max(len, 50) end
    end
    local len = sqrt(mx * mx + mz * mz)
    if len > 1 then mx, mz = mx / len, mz / len end

    -- movement with a little inertia
    local k = 1 - math.exp(-dt * 12)
    hero.vx = hero.vx + (mx * 4.4 - hero.vx) * k
    hero.vz = hero.vz + (mz * 4.4 - hero.vz) * k
    hero.x, hero.z = hero.x + hero.vx * dt, hero.z + hero.vz * dt
    -- collision: the island edge (a circle) and the tree trunks (circles): push the hero back out
    local d = sqrt(hero.x * hero.x + hero.z * hero.z)
    if d > WALK then hero.x, hero.z = hero.x / d * WALK, hero.z / d * WALK end
    for _, t in ipairs(trees) do
        local dx, dz = hero.x - t.x, hero.z - t.z
        local dd = sqrt(dx * dx + dz * dz)
        if dd < 0.6 and dd > 0.0001 then hero.x, hero.z = t.x + dx / dd * 0.6, t.z + dz / dd * 0.6 end
    end
    local speed = sqrt(hero.vx * hero.vx + hero.vz * hero.vz)
    if speed > 0.4 then                                                      -- turn towards the motion
        local target = math.atan(hero.vx, hero.vz)
        local diff = (target - hero.yaw + pi) % (2 * pi) - pi
        hero.yaw = hero.yaw + diff * min(1, dt * 14)
    end

    -- animation: Hop plays once, then back to Run or Idle
    if hero.clip == "Hop" then
        if not pip:playing() then hero.clip = "" end
    elseif speed > 0.8 then playClip("Run", {fade = 0.15, speed = 0.7 + speed * 0.12})
    else playClip("Idle", {fade = 0.25}) end
    pip:update(dt)

    -- embers
    for _, e in ipairs(embers) do
        if (e.x - hero.x) ^ 2 + (e.z - hero.z) ^ 2 < 0.75 * 0.75 then
            score = score + 1
            spawnEmber(e)
            chime()
            hero.clip = "Hop"
            pip:play("Hop", {loop = false, fade = 0.06})
        end
    end

    -- stones: more and faster over time
    local want = min(8, 2 + floor(clock / 12))
    if #rocks < want then rocks[#rocks + 1] = spawnRock({}) end
    for _, r in ipairs(rocks) do
        r.x, r.z = r.x + r.vx * dt, r.z + r.vz * dt
        r.spin = r.spin + sqrt(r.vx * r.vx + r.vz * r.vz) * dt / (0.4 * r.s)
        r.age = r.age + dt
        if r.age > 1 and r.x * r.x + r.z * r.z > R * R then spawnRock(r) end
        local reach = 0.35 + 0.4 * r.s                                       -- hero radius + stone radius
        if hero.hurt <= 0 and (r.x - hero.x) ^ 2 + (r.z - hero.z) ^ 2 < reach * reach then
            hero.lamps = hero.lamps - 1
            hero.hurt, shake = 1.4, 1
            thud()
            if hero.lamps <= 0 then
                newBest = score > best
                if newBest then best = score; store.set("best", best) end
                state, sel = "over", 1
                playClip("Idle", {fade = 0.4})
            end
        end
    end
end

-- ------------------------------------------------------------------ 2D helpers (this game's typography)
local function spacedWidth(s, size, font, track)
    local w = 0
    for _, c in utf8.codes(s) do w = w + gfx.textWidth(utf8.char(c), size, font) + track end
    return w - track
end

-- letter-spaced text; with `offset`, a second print in the accent colour sits under it (a misprinted poster)
local function spaced(s, x, y, size, font, track, color, offset)
    if offset then spaced(s, x + offset, y + offset * 0.7, size, font, track, CORAL) end
    gfx.color(color)
    for _, c in utf8.codes(s) do
        local ch = utf8.char(c)
        gfx.text(ch, x, y, size, font)
        x = x + gfx.textWidth(ch, size, font) + track
    end
end

local function wavy(x, y, w, t)
    for i = 0, 12 do
        wave[i * 2 + 1] = x + w * i / 12
        wave[i * 2 + 2] = y + sin(t * 6 + i * 1.3) * 2.5
    end
    gfx.lines(wave, 3)
end

-- a horizontal menu of words, right-aligned at (right, y); the selected word gets the wavy underline
local function menuRow(list, right, y, size)
    local gap = size * 1.6
    local total = 0
    for i, id in ipairs(list) do
        total = total + spacedWidth(TR(id), size, "bold", 2) + (i > 1 and gap or 0)
    end
    local x = right - total
    for i, id in ipairs(list) do
        local label = TR(id)
        local w = spacedWidth(label, size, "bold", 2)
        local ready = not ((id == "play" or id == "again") and not (pip and rockModel))
        local c = i == sel and CREAM or (ready and "#C9B8D8" or "#7D6F8F")
        spaced(label, x, y, size, "bold", 2, c)
        if i == sel then
            gfx.color(CORAL)
            wavy(x, y + size * 1.35, w, sys.time())
        end
        rects[i] = {x = x - 8, y = y - 8, w = w + 16, h = size * 1.6 + 16}
        x = x + w + gap
    end
    for i = #list + 1, #rects do rects[i] = nil end
end

local function sky(w, h)
    gfx.gradient(0, 0, w, h * 0.62, INK, DUSK)
    gfx.gradient(0, h * 0.62, w, h * 0.38, DUSK, PLUM)
    gfx.color("#F3B37A40")
    gfx.circle(w * 0.3, h * 0.66, h * 0.32)                                  -- the low sun behind the island
end

-- ------------------------------------------------------------------ 3D scene
local function scene(vx, vy, vw, vh, title)
    local t = sys.time()
    local hy = height(hero.x, hero.z)
    local ex, ey, ez, tx, ty, tz
    if title then                                                            -- slow orbit around the hero
        ex, ey, ez = sin(t * 0.15) * 4.2, 1.9, cos(t * 0.15) * 4.2
        tx, ty, tz = 0, 0.9, 0
    else                                                                     -- follow camera, smoothed
        local k = 0.12
        cam.x = cam.x + (hero.x - cam.x) * k
        cam.y = cam.y + (hy + 6.4 - cam.y) * k
        cam.z = cam.z + (hero.z + 7.6 - cam.z) * k
        local s = shake * 0.25
        ex, ey, ez = cam.x + (random() - 0.5) * s, cam.y + (random() - 0.5) * s, cam.z
        tx, ty, tz = cam.x, hy + 0.6, cam.z - 7.6
    end
    g3d.begin(vx, vy, vw, vh, title and 42 or 50, 0.1, 60)
    g3d.camera(ex, ey, ez, tx, ty, tz)
    g3d.light(-0.5, 1, 0.45, 0.38, "#FFD9B8")
    g3d.fog(DUSK, 13, 32)
    g3d.draw(ground, 0, 0, 0)
    for _, tr in ipairs(trees) do
        g3d.draw(trunk, tr.x, tr.y + 0.3 * tr.s, tr.z, 0, 0, 0, tr.s)
        g3d.draw(crown, tr.x, tr.y + (0.6 + 0.95) * tr.s, tr.z, 0, tr.x, 0, tr.s)
    end
    if not title then
        for _, e in ipairs(embers) do
            local y = height(e.x, e.z) + 0.55 + sin(t * 3 + e.phase) * 0.12
            g3d.draw(ember, e.x, y, e.z, 0, 0, 0, 1, 1, 1, nil, "unlit")
            g3d.draw(halo, e.x, y, e.z, 0, 0, 0, 0.8, 0.8, 0.8, nil, "glow unlit nocull")
        end
        if rockModel then
            for _, r in ipairs(rocks) do
                g3d.draw(rockModel, r.x, height(r.x, r.z) - 0.05, r.z, r.spin, math.atan(r.vx, r.vz), 0, r.s)
            end
        end
    end
    if pip then
        local x, z = title and 0 or hero.x, title and 0 or hero.z
        local y, yaw = height(x, z), title and 0.5 or hero.yaw
        g3d.draw(shadow, x, y + 0.02, z)
        local blink = hero.hurt > 0 and floor(t * 12) % 2 == 0
        if not blink then g3d.draw(pip, x, y, z, 0, yaw, 0) end
        local m = pip:nodeMatrix("Lamp", x, y, z, 0, yaw, 0)                 -- the halo rides on the "Lamp" bone
        if m then g3d.drawMatrix(halo, m, "#FFFFFF", "glow unlit nocull") end
    end
    g3d.finish()
end

-- ------------------------------------------------------------------ screens
local function drawTitle(w, h)
    sky(w, h)
    scene(0, 0, floor(w * 0.6), h, true)
    for _, s in ipairs(sparks) do
        gfx.color(sin(sys.time() * 3 + s.p) > 0 and "#FFC36ACC" or "#FF6F5988")
        gfx.circle(s.x * w, s.y * h, s.r)
    end
    local size = floor(h * 0.15)
    local x = floor(w * 0.52)
    spaced(TR("title_a"), x, floor(h * 0.16), size, "bold", floor(size * 0.12), CREAM, 5)
    spaced(TR("title_b"), x + size * 0.5, floor(h * 0.16) + size * 1.05, size, "bold", floor(size * 0.12), CREAM, 5)
    gfx.color("#E7D3C2")
    gfx.wrap(TR("tagline"), x + size * 0.5, floor(h * 0.16) + size * 2.35, w - x - size * 0.5 - 32, 15, "italic")
    if best > 0 then
        gfx.color(APRICOT)
        gfx.text(TR("best", best), w - 32, 26, 15, "monobold", "right", 0)
    end
    if loadErr then
        gfx.color(CORAL)
        gfx.wrap(TR("error", tostring(loadErr)), 32, h - 70, w * 0.5, 14)
    elseif not (pip and rockModel) then
        gfx.color("#C9B8D8")
        gfx.text(TR("loading"), 32, h - 44, 14, "mono")
    end
    menuRow(items(), w - 40, h - 64, floor(min(22, h * 0.04)))
end

local function drawHowto(w, h)
    sky(w, h)
    -- a slanted card: one convex polygon, the game's own shape
    local cx, cy, cw, ch = w * 0.5, h * 0.5, min(620, w - 60), min(330, h - 80)
    gfx.poly({cx - cw / 2 + 26, cy - ch / 2, cx + cw / 2, cy - ch / 2 + 10, cx + cw / 2 - 26, cy + ch / 2,
              cx - cw / 2, cy + ch / 2 - 10}, CREAM)
    spaced(TR("howto"), cx - cw / 2 + 48, cy - ch / 2 + 26, 24, "bold", 3, INK)
    gfx.color(INK)
    local y = cy - ch / 2 + 78
    for _, key in ipairs({"h_move", "h_goal", "h_rocks", "h_pause"}) do
        gfx.circle(cx - cw / 2 + 56, y + 9, 5, CORAL)
        gfx.color(INK)
        y = y + gfx.wrap(TR(key), cx - cw / 2 + 72, y, cw - 120, 16) + 12
    end
    gfx.color("#6B5A72")
    gfx.text(TR("h_back"), cx + cw / 2 - 48, cy + ch / 2 - 40, 13, "mono", "right", 0)
    for i = 1, #rects do rects[i] = nil end
end

local function drawHud(w, h)
    spaced(TR("embers"), 28, 20, 12, "monobold", 3, "#E7D3C2")
    gfx.color(CORAL)
    gfx.text(tostring(score), 31, 38, 46, "monobold")
    gfx.color(CREAM)
    gfx.text(tostring(score), 28, 35, 46, "monobold")
    for i = 1, 3 do                                                          -- the lamps
        local x = w - 150 + i * 30
        if i <= hero.lamps then
            gfx.color("#FFC36A55")
            gfx.circle(x, 34, 13)
            gfx.circle(x, 34, 7, APRICOT)
        else
            gfx.color("#C9B8D877")
            gfx.circleLine(x, 34, 7, 2)
        end
    end
    gfx.color(CREAM)                                                         -- pause button for touch
    gfx.rect(w - 44, 22, 5, 22, 2)
    gfx.rect(w - 34, 22, 5, 22, 2)
    if stick.on then
        gfx.color("#FFF1DC55")
        gfx.circleLine(stick.x0, stick.y0, 48, 2)
        local dx, dy = stick.x - stick.x0, stick.y - stick.y0
        local len = sqrt(dx * dx + dy * dy)
        if len > 48 then dx, dy = dx / len * 48, dy / len * 48 end
        gfx.circle(stick.x0 + dx, stick.y0 + dy, 18)
    end
end

function app.draw(w, h)
    W, H = w, h
    gfx.clear(INK)
    if state == "title" then drawTitle(w, h); return end
    if state == "howto" then drawHowto(w, h); return end
    sky(w, h)
    scene(0, 0, w, h, false)
    if state == "play" then drawHud(w, h); for i = 1, #rects do rects[i] = nil end; return end
    gfx.color("#17142ACC")
    gfx.rect(0, 0, w, h)
    local size = floor(min(64, h * 0.11))
    if state == "pause" then
        spaced(TR("paused"), 48, h * 0.3, size, "bold", floor(size * 0.15), CREAM, 4)
    else
        spaced(TR("over"), 48, h * 0.26, floor(size * 0.6), "bold", 4, "#E7D3C2")
        spaced(TR("score", score), 48, h * 0.26 + size, size, "bold", floor(size * 0.12), CREAM, 4)
        if newBest then
            gfx.poly({48, h * 0.26 + size * 2.4, 210, h * 0.26 + size * 2.25, 214, h * 0.26 + size * 2.25 + 34,
                      52, h * 0.26 + size * 2.4 + 34}, CORAL)
            spaced(TR("new_best"), 64, h * 0.26 + size * 2.4 + 6, 16, "bold", 3, INK)
        end
    end
    menuRow(items(), w - 40, h - 64, floor(min(22, h * 0.04)))
end

-- ------------------------------------------------------------------ input
local function inRect(r, x, y) return r and x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h end

-- keyboard keys mapped onto the controller's names, so menus and pause handle one set of buttons
local KEYS = {enter = "a", space = "a", escape = "back", backspace = "back", p = "plus", left = "left", right = "right"}

local function press(name)
    local list = items()
    if state == "play" then
        if name == "plus" or name == "back" then pause() end
    elseif state == "howto" then
        if name == "a" or name == "b" or name == "back" then state = "title" end
    elseif #list > 0 then
        if name == "left" then sel = (sel - 2) % #list + 1
        elseif name == "right" then sel = sel % #list + 1
        elseif name == "a" then activate(list[sel])
        elseif state == "pause" and (name == "plus" or name == "b" or name == "back") then state = "play"
        elseif state == "over" and (name == "b" or name == "back") then go("title") end
    end
end

function app.event(e)
    if e.type == "paddown" and e.pad then press(e.pad)
    elseif e.type == "keydown" and e.key then
        held[e.key] = true
        if KEYS[e.key] then press(KEYS[e.key]) end
    elseif e.type == "keyup" and e.key then held[e.key] = nil
    elseif e.type == "mousedown" then
        local x, y = e.x or 0, e.y or 0
        if state == "play" then
            if x > W - 60 and y < 60 then pause()
            else stick.on, stick.x0, stick.y0, stick.x, stick.y = true, x, y, x, y end
        elseif state == "howto" then state = "title"
        else
            for i, r in ipairs(rects) do
                if inRect(r, x, y) then sel = i; activate(items()[i]); break end
            end
        end
    elseif e.type == "mousemove" and stick.on then stick.x, stick.y = e.x or stick.x, e.y or stick.y
    elseif e.type == "mouseup" then stick.on = false end
end

function app.suspend() pause() end
function app.focus(focused) if not focused then pause() end end

return app
