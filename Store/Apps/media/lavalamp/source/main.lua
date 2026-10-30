-- Lava Lamp: a relaxing lava lamp. Wax blobs warm up at the bottom, rise, cool at the top and sink again; blobs that
-- come close melt together. Colour themes, speed and blob count, soft bubbling sounds and a night-light mode.
local app = {}

local THEMES = {
  {key = "th_classic", top = "#FF8A00", bottom = "#FFD200", wax = "#E8222B", wax2 = "#FF5A3C", glow = "#FF6A00"},
  {key = "th_ocean", top = "#00375F", bottom = "#0AB3C9", wax = "#7CF0FF", wax2 = "#D6FBFF", glow = "#18B7D6"},
  {key = "th_lime", top = "#0F3D1E", bottom = "#2E8B57", wax = "#B6FF3B", wax2 = "#E9FF9A", glow = "#7BD82F"},
  {key = "th_purple", top = "#22073D", bottom = "#6A1B9A", wax = "#FF4FD8", wax2 = "#FFA3EE", glow = "#C13BE0"},
  {key = "th_rainbow", rainbow = true, top = "#141428", bottom = "#2A2A55", wax = "#FF4040", wax2 = "#FFFFFF", glow = "#8080FF"},
}

local themeSel, speed, count = 1, 1.0, 7
local sound, night = false, false
local blobs = {}
local lamp = {x = 0, y = 0, w = 0, h = 0}       -- glass area of the last frame
local idle = 0
local bubbleT = 2
local hue = 0

local function hsv(h, s, v)
  local i = math.floor(h * 6) % 6
  local f = h * 6 - math.floor(h * 6)
  local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
  local r, g, b
  if i == 0 then r, g, b = v, t, p elseif i == 1 then r, g, b = q, v, p elseif i == 2 then r, g, b = p, v, t
  elseif i == 3 then r, g, b = p, q, v elseif i == 4 then r, g, b = t, p, v else r, g, b = v, p, q end
  return string.format("#%02X%02X%02X", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))
end

local function makeBlobs()
  blobs = {}
  for i = 1, count do
    blobs[i] = {u = math.random() * 0.8 + 0.1, v = math.random(), vu = 0, vv = 0, temp = math.random(),
      r = 0.06 + math.random() * 0.06, phase = math.random() * 6.28, hue = i / count}
  end
end

-- half width of the glass (in 0..1 of the lamp width) at height v (0 = top, 1 = bottom)
local function halfWidth(v) return 0.22 + 0.13 * v end

function app.load()
  themeSel = math.max(1, math.min(#THEMES, store.get("theme", 1)))
  speed = store.get("speed", 1.0)
  count = math.max(3, math.min(12, store.get("count", 7)))
  sound = store.get("sound", false) == true
  math.randomseed(math.floor(sys.epoch()))
  makeBlobs()
end

function app.update(dt)
  idle = idle + dt
  hue = (hue + dt * 0.02) % 1
  local k = dt * speed
  for _, b in ipairs(blobs) do
    -- heat near the bottom, cool near the top
    if b.v > 0.82 then b.temp = math.min(1, b.temp + k * 0.35)
    elseif b.v < 0.15 then b.temp = math.max(0, b.temp - k * 0.35)
    else b.temp = b.temp + (0.5 - b.temp) * k * 0.02 end
    b.vv = b.vv - (b.temp - 0.5) * k * 0.09
    b.vu = b.vu + math.sin(sys.time() * 0.3 + b.phase) * k * 0.004
    b.vv, b.vu = b.vv * (1 - k * 0.6), b.vu * (1 - k * 0.9)
    b.u, b.v = b.u + b.vu * k * 4, b.v + b.vv * k * 4
    local hw = halfWidth(b.v) - b.r * 0.5
    if b.u < 0.5 - hw then b.u, b.vu = 0.5 - hw, math.abs(b.vu) end
    if b.u > 0.5 + hw then b.u, b.vu = 0.5 + hw, -math.abs(b.vu) end
    if b.v < 0.04 then b.v, b.vv = 0.04, 0 end
    if b.v > 0.96 then b.v, b.vv = 0.96, 0 end
  end
  if sound then
    bubbleT = bubbleT - dt
    if bubbleT <= 0 then
      bubbleT = 1.2 + math.random() * 2.5
      audio.tone(110 + math.random(0, 6) * 18, 0.18, 0.07, "sine")
    end
  end
end

local function waxColor(b, th, alt)
  if th.rainbow then return hsv((b.hue + hue) % 1, alt and 0.35 or 0.85, 1) end
  return alt and th.wax2 or th.wax
end

local function drawLamp(cx, top, lw, lh)
  local th = THEMES[themeSel]
  local capH, baseH = lh * 0.12, lh * 0.2
  local gy, gh = top + capH, lh - capH - baseH
  lamp.x, lamp.y, lamp.w, lamp.h = cx - lw / 2, gy, lw, gh
  -- halo behind the lamp
  local glow = th.rainbow and hsv(hue, 0.6, 1) or th.glow
  for i = 6, 1, -1 do
    gfx.alpha(0.05)
    gfx.circle(cx, gy + gh * 0.55, lw * (0.35 + i * 0.16), glow)
    gfx.unalpha()
  end
  -- glass: a convex trapezoid filled with the liquid, then the wax on top
  local tw, bw = lw * halfWidth(0) * 2, lw * halfWidth(1) * 2
  gfx.poly({cx - tw / 2, gy, cx + tw / 2, gy, cx + bw / 2, gy + gh, cx - bw / 2, gy + gh}, th.bottom)
  -- liquid gradient in horizontal bands clipped to the trapezoid
  local bands = 24
  for i = 0, bands - 1 do
    local v0, v1 = i / bands, (i + 1) / bands
    local w0, w1 = lw * halfWidth(v0) * 2, lw * halfWidth(v1) * 2
    local y0, y1 = gy + gh * v0, gy + gh * v1
    gfx.alpha(1 - (i + 0.5) / bands)
    gfx.poly({cx - w0 / 2, y0, cx + w0 / 2, y0, cx + w1 / 2, y1 + 0.5, cx - w1 / 2, y1 + 0.5}, th.top)
    gfx.unalpha()
  end
  -- wax: necks between nearby blobs first, then the blobs themselves
  local scale = lw
  for i = 1, #blobs do
    local a = blobs[i]
    local ax, ay, ar = lamp.x + a.u * lw, gy + a.v * gh, a.r * scale * (1 + math.sin(sys.time() * 0.8 + a.phase) * 0.05)
    for j = i + 1, #blobs do
      local b = blobs[j]
      local bx, by, br = lamp.x + b.u * lw, gy + b.v * gh, b.r * scale
      local dx, dy = bx - ax, by - ay
      local d = math.sqrt(dx * dx + dy * dy)
      local reach = (ar + br) * 1.35
      if d < reach and d > 0.001 then
        local f = 1 - d / reach
        local nr = math.min(ar, br) * (0.35 + 0.65 * f)
        gfx.color(waxColor(a, THEMES[themeSel]))
        for s = 1, 7 do
          local t = s / 8
          local bulge = math.sin(t * math.pi) * (1 - f)
          gfx.circle(ax + dx * t, ay + dy * t, math.max(1, (ar + (br - ar) * t) * (1 - bulge * 0.75) * 0.5 + nr * 0.5))
        end
      end
    end
  end
  for _, b in ipairs(blobs) do
    local bx, by = lamp.x + b.u * lw, gy + b.v * gh
    local r = b.r * scale * (1 + math.sin(sys.time() * 0.8 + b.phase) * 0.05)
    gfx.color(waxColor(b, th))
    gfx.circle(bx, by, r)
    gfx.alpha(0.35)
    gfx.color(waxColor(b, th, true))
    gfx.circle(bx - r * 0.3, by - r * 0.35, r * 0.45)
    gfx.unalpha()
  end
  -- glass shine
  gfx.alpha(0.18)
  gfx.poly({cx - tw / 2 + 8, gy + 6, cx - tw / 2 + 18, gy + 6, cx - bw / 2 + 26, gy + gh - 10, cx - bw / 2 + 14, gy + gh - 10}, "#FFFFFF")
  gfx.unalpha()
  -- cap and base (metal)
  gfx.poly({cx - tw * 0.32, top, cx + tw * 0.32, top, cx + tw / 2, gy, cx - tw / 2, gy}, "#8E8E99")
  gfx.gradient(cx - tw / 2, gy - 4, tw, 6, "#C7C7CC", "#6E6E78", false, 2)
  gfx.poly({cx - bw / 2, gy + gh, cx + bw / 2, gy + gh, cx + bw * 0.34, gy + gh + baseH * 0.5, cx - bw * 0.34, gy + gh + baseH * 0.5}, "#7C7C88")
  gfx.poly({cx - bw * 0.34, gy + gh + baseH * 0.5, cx + bw * 0.34, gy + gh + baseH * 0.5, cx + bw / 2, gy + gh + baseH, cx - bw / 2, gy + gh + baseH}, "#5A5A66")
  gfx.gradient(cx - bw / 2, gy + gh - 3, bw, 6, "#D1D1D6", "#76767F", false, 2)
end

function app.draw(w, h)
  local th = THEMES[themeSel]
  gfx.gradient(0, 0, w, h, "#07070C", "#151522")
  local barH = 56
  local showUI = not night or idle < 4
  local availH = h - (showUI and barH or 0) - 24
  local lh = math.max(160, availH)
  local lw = math.min(w * 0.6, lh * 0.55)
  drawLamp(w / 2, 12, lw, lh)

  if night then
    local d = sys.date()
    gfx.alpha(0.45)
    gfx.color("#FFFFFF")
    gfx.text(string.format("%02d:%02d", d.hour, d.min), 0, 16, 22, "semibold", "right", w - 20)
    gfx.unalpha()
  end
  if not showUI then return end
  local a = night and math.min(1, (4 - idle) * 2) or 1
  gfx.alpha(a)
  local y = h - barH
  gfx.rect(12, y, w - 24, barH - 10, 14, theme.dark and "#1C1C1EE6" or "#FFFFFFE6")
  local x = 24
  for i, t in ipairs(THEMES) do
    local hit = ui.hit("th" .. i, x, y + 9, 28, 28)
    if t.rainbow then
      for k = 0, 5 do gfx.color(hsv(k / 6, 0.8, 1)); gfx.pie(x + 14, y + 23, 13, k * math.pi / 3, (k + 1) * math.pi / 3) end
    else
      gfx.gradient(x, y + 9, 28, 28, t.wax, t.bottom, false, 14)
    end
    if i == themeSel then gfx.color(theme.accent); gfx.circleLine(x + 14, y + 23, 16, 2) end
    if hit.clicked then themeSel = i; store.set("theme", i); idle = 0 end
    x = x + 36
  end
  x = x + 8
  local rest = w - 24 - x - 120
  local sw = math.max(60, rest / 2 - 50)
  gfx.color(theme.text2)
  gfx.text(TR("speed"), x, y + 16, 12)
  local ns = ui.slider("speed", speed, 0.3, 3, x + 44, y + 16, sw, 0.1)
  if ns ~= speed then speed = ns; store.set("speed", speed); idle = 0 end
  x = x + 44 + sw + 14
  gfx.color(theme.text2)
  gfx.text(TR("blobs"), x, y + 16, 12)
  local nc = ui.slider("count", count, 3, 12, x + 44, y + 16, sw, 1)
  if nc ~= count then count = nc; store.set("count", count); makeBlobs(); idle = 0 end
  if ui.iconButton(sound and "volume_up" or "volume_off", w - 100, y + 7, 34, 32, nil, sound, "snd") then
    sound = not sound; store.set("sound", sound); idle = 0
  end
  if ui.iconButton(night and "fullscreen_exit" or "nightlight", w - 60, y + 7, 34, 32, nil, night, "ngt") then
    night = not night; idle = 0
  end
  gfx.unalpha()
end

function app.event(e)
  if e.type == "mousedown" or e.type == "mousemove" or e.type == "keydown" or e.type == "scroll" then idle = 0 end
  if e.type ~= "keydown" then return end
  local k = e.key
  if k == "space" or k == "n" then night = not night
  elseif k == "escape" then night = false
  elseif k == "left" then themeSel = (themeSel - 2) % #THEMES + 1; store.set("theme", themeSel)
  elseif k == "right" then themeSel = themeSel % #THEMES + 1; store.set("theme", themeSel)
  elseif k == "up" then speed = math.min(3, speed + 0.2); store.set("speed", speed)
  elseif k == "down" then speed = math.max(0.3, speed - 0.2); store.set("speed", speed) end
end

function app.menu()
  local th = {}
  for i, t in ipairs(THEMES) do th[i] = {label = TR(t.key), id = 10 + i} end
  return {
    {title = TR("app_name"), items = {
      {label = TR("night_mode"), id = 1, shortcut = "Space"},
      {label = TR("sound"), id = 2},
      {label = TR("shake"), id = 3},
    }},
    {title = TR("themes"), items = th},
  }
end

function app.onmenu(id)
  if id == 1 then night = not night; idle = 0
  elseif id == 2 then sound = not sound; store.set("sound", sound)
  elseif id == 3 then makeBlobs()
  elseif id > 10 and THEMES[id - 10] then themeSel = id - 10; store.set("theme", themeSel) end
end

function app.close()
  store.save()
  return true
end

return app
