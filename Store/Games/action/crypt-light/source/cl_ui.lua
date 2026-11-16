-- Crypt Light: title and pause menus, the near-invisible HUD and the touch controls. Drawn with gfx over the 3D frame.
local U = {}
local sin, cos, pi, min, max, floor, abs, sqrt = math.sin, math.cos, math.pi, math.min, math.max, math.floor, math.abs, math.sqrt

local WARM, DIM, FAINT, WARD, BLOOD = "#FFD9A0", "#8C929C", "#4A505A", "#5FD4C8", "#B0262B"
U.colors = {warm = WARM, dim = DIM, ward = WARD}

local img = {}
function U.init()
  img.title = gfx.image("bundle:/tex/title.png")
  img.vig = gfx.image("bundle:/tex/vignette.png")
  img.hurt = gfx.image("bundle:/tex/hurt.png")
end

-- wide tracking for Latin text (menus); other scripts as they are
local function track(s)
  if s:find("[\128-\255]") then return s end
  return (s:upper():gsub("(.)", "%1\u{2009}")):sub(1, -4)
end
U.track = track

local function S(h) return h / 720 end   -- scale of a 720 p layout

-- ------------------------------------------------------------------ menus
-- items: {{label, id, value = "On"}}; sel: index. Returns the hit index for a touch at (tx, ty) or nil.
function U.menu(w, h, title, items, sel, t, opts)
  opts = opts or {}
  local k = S(h)
  -- a dark band on the left so the 3D scene stays visible on the right
  gfx.gradient(0, 0, w * 0.62, h, "#000000E6", "#00000000", true)
  local x = floor(84 * k)
  local y = floor(h * 0.18)
  if title == "logo" then
    if img.title then
      local iw = 520 * k
      local ih = iw * img.title.height / img.title.width
      gfx.draw(img.title, x - 12 * k, y - 20 * k, iw, ih)
      y = y + ih + 6 * k
    end
    gfx.text(track(TR("tagline")), x, y, floor(15 * k), "medium")
    y = y + 70 * k
  elseif title then
    gfx.text(track(title), x, y, floor(30 * k), "semibold")
    gfx.color(WARM)
    gfx.rect(x, y + 46 * k, 46 * k, 2 * k)
    y = y + 92 * k
  end
  local rows = {}
  local fs = floor(23 * k)
  for i, it in ipairs(items) do
    local on = i == sel
    local tx = x + (on and 30 * k or 0)
    if on then
      -- a small flame marks the choice
      local fy = y + fs * 0.62
      local fl = 1 + sin(t * 9) * 0.08 + sin(t * 23) * 0.04
      gfx.circle(x + 9 * k, fy, 9 * k * fl, "#FF7A2E30")
      gfx.circle(x + 9 * k, fy, 4.5 * k * fl, "#FFB25A")
      gfx.circle(x + 9 * k, fy - 2 * k, 2.2 * k, "#FFF2D0")
    end
    gfx.color(it.disabled and FAINT or (on and WARM or DIM))
    gfx.text(track(it.label), tx, y, fs, on and "semibold" or "medium")
    if it.value then
      gfx.color(on and WARD or FAINT)
      gfx.text(it.value, x + 420 * k, y + 2 * k, floor(19 * k), "medium")
    end
    if it.sub then
      gfx.color(FAINT)
      gfx.text(it.sub, tx, y + fs + 6 * k, floor(14 * k), "sans")
    end
    rows[i] = {y = y - 8 * k, h = (it.sub and 62 or 46) * k}
    y = y + (it.sub and 66 or 50) * k
  end
  -- button hints at the bottom
  gfx.color(FAINT)
  local hint = opts.touch and TR("hint_touch") or TR("hint_pad")
  gfx.text(hint, x, h - 52 * k, floor(14 * k), "sans")
  U.rows = rows
  U.menuX = x
end

function U.hitMenu(tx, ty)
  for i, r in ipairs(U.rows or {}) do
    if ty >= r.y and ty <= r.y + r.h and tx < (U.menuX or 0) + 600 then return i end
  end
end

-- ------------------------------------------------------------------ HUD
function U.hud(w, h, G, P, t)
  local k = S(h)
  -- vignette: tighter with less oil, red with damage
  if img.vig then
    local a = 0.55 + (1 - P.lantern) * 0.4
    gfx.alpha(min(1, a))
    gfx.draw(img.vig, 0, 0, w, h)
    gfx.unalpha()
  end
  local hurt = max(G.hurtFlash, (1 - P.hp / 100) * 0.6)
  if img.hurt and hurt > 0.02 then
    local pulse = (P.hp < 40) and (0.75 + 0.25 * sin(t * 6)) or 1
    gfx.alpha(min(1, hurt * pulse))
    gfx.draw(img.hurt, 0, 0, w, h)
    gfx.unalpha()
  end
  -- oil gauge: a thin arc low on the right, only when it matters
  local show = G.oilShow
  if show > 0.01 then
    local cx, cy, r = w - 92 * k, h - 92 * k, 34 * k
    gfx.alpha(min(1, show))
    gfx.color("#00000080")
    gfx.arc(cx, cy, r, pi * 0.75, pi * 2.25, 6 * k)
    local f = P.oil / 100
    local low = P.oil < 25
    gfx.color(low and ((sin(t * 8) > 0) and "#FF5A2A" or "#B03A1A") or "#FFB25A")
    if f > 0.005 then gfx.arc(cx, cy, r, pi * 0.75, pi * 0.75 + pi * 1.5 * f, 4 * k) end
    gfx.circle(cx, cy, 7 * k * (0.6 + P.lantern * 0.4), low and "#FF6A3A" or "#FFC27A")
    gfx.color("#FFD9A080")
    gfx.text(TR("oil"), cx - 40 * k, cy + 26 * k, floor(12 * k), "medium", "center", 80 * k)
    gfx.unalpha()
  end
  -- keys carried
  if (G.vars.key or 0) > 0 then
    gfx.color("#E8B850")
    gfx.icon("key", 50 * k, h - 60 * k, 26 * k, "#E8B850")
  end
  -- message line
  if G.msgT > 0 and G.msg then
    local a = min(1, G.msgT, (G.msgDur - G.msgT + 0.3) * 3)
    gfx.alpha(max(0, a))
    gfx.color("#000000A0")
    local fs = floor(19 * k)
    local tw = gfx.textWidth(G.msg, fs, "medium")
    gfx.rect(w / 2 - tw / 2 - 20 * k, h * 0.74 - 8 * k, tw + 40 * k, fs + 18 * k, 6 * k)
    gfx.color(WARM)
    gfx.text(G.msg, 0, h * 0.74, fs, "medium", "center", w)
    gfx.unalpha()
  end
  -- objective (fades)
  if G.objT > 0 and G.objective then
    gfx.alpha(min(1, G.objT))
    gfx.color(DIM)
    gfx.text(track(TR("objective")), 0, h * 0.12, floor(13 * k), "medium", "center", w)
    gfx.color(WARM)
    gfx.text(TR(G.objective), 0, h * 0.12 + 22 * k, floor(21 * k), "medium", "center", w)
    gfx.unalpha()
  end
  -- interaction prompt
  if G.focus and G.focus.prompt and not G.focus.dead then
    local fs = floor(17 * k)
    local glyph = G.touch and "" or (TR("btn_use") .. "  ")
    local s = glyph .. TR(G.focus.prompt)
    gfx.color("#00000090")
    local tw = gfx.textWidth(s, fs, "semibold")
    gfx.rect(w / 2 - tw / 2 - 14 * k, h * 0.58, tw + 28 * k, fs + 14 * k, 5 * k)
    gfx.color(WARM)
    gfx.text(s, 0, h * 0.58 + 7 * k, fs, "semibold", "center", w)
  end
  -- a dot in the middle while something is in reach
  if G.focus then gfx.circle(w / 2, h / 2, 2.5 * k, "#FFD9A0A0") end
end

-- ------------------------------------------------------------------ touch controls
U.touchBtns = {}
function U.touchLayout(w, h)
  local k = S(h)
  local b = U.touchBtns
  b.use = {x = w - 120 * k, y = h - 150 * k, r = 46 * k, label = "act_use_short"}
  b.flare = {x = w - 225 * k, y = h - 95 * k, r = 38 * k, label = "act_flare_short"}
  b.run = {x = w - 110 * k, y = h - 265 * k, r = 36 * k, label = "act_run_short"}
  b.pause = {x = w - 60 * k, y = 80 * k, r = 28 * k, icon = "pause"}
  b.stick = {x = 150 * k, y = h - 160 * k, r = 90 * k}
  return b
end

function U.drawTouch(w, h, T)
  local k = S(h)
  local b = U.touchLayout(w, h)
  local s = b.stick
  gfx.color("#FFFFFF30")
  gfx.circleLine(s.x, s.y, s.r, 2 * k)
  gfx.circle(s.x, s.y, s.r, "#FFFFFF10")
  local kx, ky = s.x + (T.sx or 0) * s.r * 0.6, s.y - (T.sy or 0) * s.r * 0.6
  gfx.circle(kx, ky, 30 * k, "#FFFFFF30")
  for name, bt in pairs(b) do
    if name ~= "stick" then
      local on = (name == "run" and T.runToggle)
      gfx.circle(bt.x, bt.y, bt.r, on and "#FFB25A50" or "#00000060")
      gfx.color(on and WARM or "#FFFFFF90")
      gfx.circleLine(bt.x, bt.y, bt.r, 2 * k)
      if bt.icon then
        gfx.icon(bt.icon, bt.x, bt.y, bt.r, "#FFFFFFB0")
      else
        gfx.text(TR(bt.label), bt.x - bt.r, bt.y - 9 * k, floor(15 * k), "semibold", "center", bt.r * 2)
      end
    end
  end
end

function U.hitTouch(x, y)
  for name, bt in pairs(U.touchBtns) do
    if name ~= "stick" then
      local dx, dy = x - bt.x, y - bt.y
      if dx * dx + dy * dy < (bt.r * 1.25) ^ 2 then return name end
    end
  end
end

-- ------------------------------------------------------------------ full-screen cards
function U.card(w, h, lines, a)
  local k = S(h)
  gfx.alpha(a or 1)
  local y = h * 0.4 - (#lines * 24 * k)
  for i, l in ipairs(lines) do
    gfx.color(i == 1 and WARM or DIM)
    local fs = floor((i == 1 and 30 or 18) * k)
    gfx.text(i == 1 and track(l) or l, 0, y, fs, i == 1 and "semibold" or "medium", "center", w)
    y = y + (i == 1 and 64 or 34) * k
  end
  gfx.unalpha()
end

function U.loading(w, h, frac, label, t)
  local k = S(h)
  gfx.clear("#05070A")
  local cx, cy = w / 2, h / 2
  local fl = 1 + sin(t * 9) * 0.08 + sin(t * 23) * 0.04
  gfx.circle(cx, cy - 20 * k, 26 * k * fl, "#FF7A2E18")
  gfx.circle(cx, cy - 20 * k, 9 * k * fl, "#FFB25A")
  gfx.circle(cx, cy - 23 * k, 4 * k, "#FFF2D0")
  gfx.color(DIM)
  gfx.text(track(label or TR("loading")), 0, cy + 30 * k, floor(16 * k), "medium", "center", w)
  gfx.color("#1A1E24")
  gfx.rect(cx - 120 * k, cy + 64 * k, 240 * k, 3 * k)
  gfx.color("#FFB25A")
  gfx.rect(cx - 120 * k, cy + 64 * k, 240 * k * max(0, min(1, frac)), 3 * k)
end

return U
