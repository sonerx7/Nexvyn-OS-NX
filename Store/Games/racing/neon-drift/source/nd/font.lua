-- Neon Drift: own stroke font (neon tube look) for the logo, numbers and short Latin labels.
-- Glyphs live on a 4 x 6 grid; each glyph is a list of polylines. Localised sentences use the system font instead.
local F = {}

local G = {
  A = {{0,6, 0,1, 1,0, 3,0, 4,1, 4,6}, {0,3.2, 4,3.2}},
  B = {{0,0, 0,6, 3,6, 4,5, 4,4, 3,3, 0,3}, {0,0, 3,0, 4,1, 4,2, 3,3}},
  C = {{4,0.6, 3.4,0, 1,0, 0,1, 0,5, 1,6, 3.4,6, 4,5.4}},
  D = {{0,0, 0,6, 3,6, 4,5, 4,1, 3,0, 0,0}},
  E = {{4,0, 0,0, 0,6, 4,6}, {0,3, 3,3}},
  F = {{4,0, 0,0, 0,6}, {0,3, 3,3}},
  G = {{4,1, 3,0, 1,0, 0,1, 0,5, 1,6, 4,6, 4,3.2, 2.2,3.2}},
  H = {{0,0, 0,6}, {4,0, 4,6}, {0,3, 4,3}},
  I = {{2,0, 2,6}, {1,0, 3,0}, {1,6, 3,6}},
  J = {{4,0, 4,5, 3,6, 1,6, 0,5}},
  K = {{0,0, 0,6}, {4,0, 0,3.4}, {1.4,2.6, 4,6}},
  L = {{0,0, 0,6, 4,6}},
  M = {{0,6, 0,0, 2,3, 4,0, 4,6}},
  N = {{0,6, 0,0, 4,6, 4,0}},
  O = {{1,0, 3,0, 4,1, 4,5, 3,6, 1,6, 0,5, 0,1, 1,0}},
  P = {{0,6, 0,0, 3,0, 4,1, 4,2, 3,3, 0,3}},
  Q = {{1,0, 3,0, 4,1, 4,5, 3,6, 1,6, 0,5, 0,1, 1,0}, {2.6,4.6, 4,6.2}},
  R = {{0,6, 0,0, 3,0, 4,1, 4,2, 3,3, 0,3}, {2,3, 4,6}},
  S = {{4,1, 3,0, 1,0, 0,1, 0,2, 1,3, 3,3, 4,4, 4,5, 3,6, 1,6, 0,5}},
  T = {{0,0, 4,0}, {2,0, 2,6}},
  U = {{0,0, 0,5, 1,6, 3,6, 4,5, 4,0}},
  V = {{0,0, 2,6, 4,0}},
  W = {{0,0, 1,6, 2,3, 3,6, 4,0}},
  X = {{0,0, 4,6}, {4,0, 0,6}},
  Y = {{0,0, 2,3, 4,0}, {2,3, 2,6}},
  Z = {{0,0, 4,0, 0,6, 4,6}},
  ["0"] = {{1,0, 3,0, 4,1, 4,5, 3,6, 1,6, 0,5, 0,1, 1,0}, {3.4,1.2, 0.6,4.8}},
  ["1"] = {{0.8,1.2, 2.2,0, 2.2,6}, {0.8,6, 3.6,6}},
  ["2"] = {{0,1, 1,0, 3,0, 4,1, 4,2.2, 0,6, 4,6}},
  ["3"] = {{0,0.6, 1,0, 3,0, 4,1, 4,2, 3,3, 1.4,3}, {3,3, 4,4, 4,5, 3,6, 1,6, 0,5.4}},
  ["4"] = {{3,6, 3,0, 0,4, 4,4}},
  ["5"] = {{4,0, 0.4,0, 0,3, 3,2.6, 4,3.6, 4,5, 3,6, 1,6, 0,5.4}},
  ["6"] = {{3.6,0, 1.6,0, 0,2, 0,5, 1,6, 3,6, 4,5, 4,4, 3,3, 0.4,3}},
  ["7"] = {{0,0, 4,0, 1.4,6}},
  ["8"] = {{1,0, 3,0, 4,1, 4,2, 3,3, 1,3, 0,4, 0,5, 1,6, 3,6, 4,5, 4,4, 3,3}, {1,3, 0,2, 0,1, 1,0}},
  ["9"] = {{3.6,3, 1,3, 0,2, 0,1, 1,0, 3,0, 4,1, 4,4, 2.4,6, 0.4,6}},
  [":"] = {{2,1.6, 2,2.2}, {2,4, 2,4.6}},
  ["."] = {{2,5.4, 2,6}},
  ["'"] = {{2,0, 1.6,1.6}},
  ["/"] = {{4,0, 0,6}},
  ["-"] = {{1,3, 3,3}},
  ["+"] = {{2,1.6, 2,4.4}, {0.6,3, 3.4,3}},
  ["!"] = {{2,0, 2,4}, {2,5.4, 2,6}},
  ["?"] = {{0,1, 1,0, 3,0, 4,1, 4,2, 2,3.4, 2,4.2}, {2,5.4, 2,6}},
  ["#"] = {{1.3,0.6, 0.7,5.4}, {3.3,0.6, 2.7,5.4}, {0.2,2, 4,2}, {0,4, 3.8,4}},
  [" "] = {},
}
F.glyphs = G

local function hexa(c, a)
  -- "#RRGGBB" -> "#RRGGBBAA" with alpha 0..1
  return string.sub(c, 1, 7) .. string.format("%02X", math.floor(math.max(0, math.min(1, a)) * 255))
end
F.hexa = hexa

-- width of a string at size (glyph height in pixels)
function F.width(s, size, track)
  local u = size / 6
  local n = utf8.len(s) or #s
  return n * (4 + (track or 1.6)) * u - (track or 1.6) * u
end

-- draw: s, x, y (top-left), size (height px), color, opts {italic, thick, glow, align, track, alpha}
function F.draw(s, x, y, size, color, o)
  o = o or {}
  s = string.upper(s)
  local u = size / 6
  local track = o.track or 1.6
  local w = F.width(s, size, track)
  if o.align == "center" then x = x - w / 2 elseif o.align == "right" then x = x - w end
  local it = (o.italic or 0.22) * u
  local th = o.thick or math.max(1.5, size * 0.085)
  local a = o.alpha or 1
  local polys = {}
  local cx = x
  for _, cp in utf8.codes(s) do
    local ch = utf8.char(cp)
    local g = G[ch]
    if g then
      for _, st in ipairs(g) do
        local pts = {}
        for i = 1, #st, 2 do
          local gx, gy = st[i], st[i + 1]
          pts[#pts + 1] = cx + gx * u + (6 - gy) * it
          pts[#pts + 1] = y + gy * u
        end
        polys[#polys + 1] = pts
      end
    end
    cx = cx + (4 + track) * u
  end
  local glow = o.glow ~= false and size >= 26  -- small text: no halo passes (they cost more than they show)
  if glow then
    gfx.color(hexa(color, 0.16 * a))
    for _, p in ipairs(polys) do gfx.lines(p, th * 3.2) end
  end
  gfx.color(hexa(color, a))
  for _, p in ipairs(polys) do gfx.lines(p, th) end
  if o.core ~= false and glow then
    gfx.color(hexa("#FFFFFF", 0.75 * a))
    for _, p in ipairs(polys) do gfx.lines(p, math.max(1, th * 0.38)) end
  end
  return w
end

return F
