-- Station Zero: the terminal consoles. Two puzzles drawn as a full-screen terminal of the game's own look:
--   "power": route the reactor feed by rotating conduit tiles (4 x 3)
--   "code":  the bridge lockdown code, four digits from the log holograms
local S = require("sz.state")
local F = require("sz.fx")
local T = {}

local floor, min, max, sin = math.floor, math.min, math.max, math.sin
local C = S.C
local N, E, SO, WE = 1, 2, 4, 8
local BASE = {I = N + SO, L = N + E, T = N + E + SO}

local function rotm(m, r)
  for _ = 1, r % 4 do m = ((m << 1) | (m >> 3)) & 15 end
  return m
end

T.open, T.kind, T.done = false, nil, false
local tiles, cur, flash, entry, msg, msgT, lock, rects = {}, 1, 0, "", "", 0, 0, {}

-- solution: the feed enters tile (row 2, col 1) from the west and leaves tile (row 2, col 4) to the east
local SOLVED = {
  {{"L", 1}, {"I", 1}, {"L", 2}, {"L", 3}},
  {{"L", 3}, {"T", 0}, {"L", 0}, {"I", 1}},
  {{"T", 2}, {"L", 1}, {"I", 0}, {"L", 2}},
}

function T.start(kind, code)
  T.open, T.kind, T.done = true, kind, false
  cur, flash, entry, msg, msgT, lock = 1, 0, "", "", 0, 0
  T.code = code
  if kind == "power" then
    tiles = {}
    local seed = 7
    for r = 1, 3 do
      tiles[r] = {}
      for c = 1, 4 do
        seed = (seed * 37 + 11) % 97
        local s = SOLVED[r][c]
        tiles[r][c] = {shape = s[1], rot = (s[2] + 1 + seed % 3) % 4}
      end
    end
  end
  F.sound("beep", 0.7)
end

local function mask(t) return rotm(BASE[t.shape], t.rot) end

-- which tiles carry power from the feed
local function powered()
  local on = {}
  local function visit(r, c, from)
    if r < 1 or r > 3 or c < 1 or c > 4 then return false end
    local m = mask(tiles[r][c])
    if m & from == 0 then return false end
    local key = r * 10 + c
    if on[key] then return false end
    on[key] = true
    local out = false
    if m & N ~= 0 and from ~= N then out = visit(r - 1, c, SO) or out end
    if m & SO ~= 0 and from ~= SO then out = visit(r + 1, c, N) or out end
    if m & WE ~= 0 and from ~= WE then out = visit(r, c - 1, E) or out end
    if m & E ~= 0 and from ~= E then
      if r == 2 and c == 4 then out = true else out = visit(r, c + 1, WE) or out end
    end
    return out
  end
  local ok = visit(2, 1, WE)
  return on, ok
end

local function finish()
  T.done = true
  flash = 1.2
  F.sound("power", 1)
end

local function press(i)
  if T.done then return end
  if T.kind == "power" then
    local r, c = floor((i - 1) / 4) + 1, (i - 1) % 4 + 1
    tiles[r][c].rot = (tiles[r][c].rot + 1) % 4
    F.sound("tick", 0.6)
    local _, ok = powered()
    if ok then finish() end
  else
    if lock > 0 then return end
    local keys = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "clr", "0", "ok"}
    local k = keys[i]
    if k == "clr" then entry = ""; F.sound("tick", 0.6)
    elseif k == "ok" then
      if entry == T.code then finish() else
        F.sound("err", 0.9); msg, msgT, lock, entry = "term_wrong", 2, 1.2, ""
      end
    elseif #entry < 4 then entry = entry .. k; F.sound("tick", 0.6) end
  end
end

-- for the self test: put the conduits one turn away from the solution and turn the last one by a press, or press a
-- keypad key by its index (12 = OK)
function T.testSolve()
  if T.kind ~= "power" then return end
  for r = 1, 3 do for c = 1, 4 do tiles[r][c].rot = SOLVED[r][c][2] end end
  tiles[2][1].rot = (SOLVED[2][1][2] + 3) % 4
  press(5)
end
function T.testPress(i) press(i) end

-- returns true while the console stays open
function T.update(dt)
  flash = max(0, flash - dt)
  msgT = max(0, msgT - dt)
  lock = max(0, lock - dt)
  if T.done and flash <= 0 then T.open = false end
  return T.open
end

function T.input(name)
  if not T.open then return end
  local cols = T.kind == "power" and 4 or 3
  local count = T.kind == "power" and 12 or 12
  if name == "b" or name == "back" then T.open = false; F.sound("tick", 0.5); return end
  if name == "left" then cur = (cur - 2) % count + 1
  elseif name == "right" then cur = cur % count + 1
  elseif name == "up" then cur = (cur - 1 - cols) % count + 1
  elseif name == "down" then cur = (cur - 1 + cols) % count + 1
  elseif name == "a" then press(cur)
  elseif T.kind == "code" and name:match("^%d$") then
    local map = {["1"] = 1, ["2"] = 2, ["3"] = 3, ["4"] = 4, ["5"] = 5, ["6"] = 6, ["7"] = 7, ["8"] = 8, ["9"] = 9, ["0"] = 11}
    press(map[name])
  end
end

function T.tap(x, y)
  for i, r in pairs(rects) do
    if x >= r[1] and y >= r[2] and x <= r[1] + r[3] and y <= r[2] + r[4] then
      cur = i
      press(i)
      return
    end
  end
  if rects.close and x >= rects.close[1] and y >= rects.close[2] and x <= rects.close[1] + rects.close[3]
     and y <= rects.close[2] + rects.close[4] then T.open = false end
end

-- ---------------------------------------------------------------- drawing
local function frame(x, y, w, h, col)
  gfx.color(col)
  local k = 14
  gfx.lines({x, y + k, x, y, x + k, y}, 2)
  gfx.lines({x + w - k, y, x + w, y, x + w, y + k}, 2)
  gfx.lines({x + w, y + h - k, x + w, y + h, x + w - k, y + h}, 2)
  gfx.lines({x + k, y + h, x, y + h, x, y + h - k}, 2)
end
T.frame = frame

local function conduit(x, y, s, m, on)
  local cx, cy = x + s / 2, y + s / 2
  local col = on and C.cyan or "#2C4650"
  local th = on and 7 or 5
  gfx.color(col)
  if m & N ~= 0 then gfx.line(cx, cy, cx, y + 4, th) end
  if m & SO ~= 0 then gfx.line(cx, cy, cx, y + s - 4, th) end
  if m & WE ~= 0 then gfx.line(cx, cy, x + 4, cy, th) end
  if m & E ~= 0 then gfx.line(cx, cy, x + s - 4, cy, th) end
  gfx.circle(cx, cy, th * 0.9, col)
end

function T.draw(w, h, digits)
  local t = S.t
  gfx.color("#020509E6")
  gfx.rect(0, 0, w, h)
  local pw, ph = min(w - 40, 760), min(h - 40, 500)
  local x0, y0 = floor((w - pw) / 2), floor((h - ph) / 2)
  gfx.color("#06141BF2")
  gfx.rect(x0, y0, pw, ph)
  frame(x0, y0, pw, ph, C.cyan)
  -- scan line
  gfx.color("#3FE6FF14")
  gfx.rect(x0, y0 + (t * 90) % ph, pw, 3)
  gfx.color(C.dim)
  gfx.text("KEPLER//RING-0  TERMINAL " .. (T.kind == "power" and "PWR-07" or "BRG-01"), x0 + 22, y0 + 16, 13, "mono")
  gfx.color(C.cyan)
  gfx.text(TR(T.kind == "power" and "term_power" or "term_code"), x0 + 22, y0 + 38, 22, "monobold")
  gfx.color(C.text)
  gfx.wrap(TR(T.kind == "power" and "term_power_help" or "term_code_help"), x0 + 22, y0 + 70, pw - 44, 14, "mono")
  for k in pairs(rects) do rects[k] = nil end
  if T.kind == "power" then
    local on, ok = powered()
    local s = floor(min((pw - 180) / 4, (ph - 170) / 3))
    local gx, gy = x0 + floor((pw - s * 4) / 2), y0 + 118
    -- feed and output
    gfx.color(C.amber)
    gfx.rect(gx - 40, gy + s + s / 2 - 5, 36, 10)
    gfx.text("FEED", gx - 82, gy + s + s / 2 - 8, 12, "monobold")
    gfx.color(ok and C.cyan or "#2C4650")
    gfx.rect(gx + s * 4 + 4, gy + s + s / 2 - 5, 36, 10)
    gfx.text("CORE", gx + s * 4 + 46, gy + s + s / 2 - 8, 12, "monobold")
    for r = 1, 3 do
      for c = 1, 4 do
        local i = (r - 1) * 4 + c
        local x, y = gx + (c - 1) * s, gy + (r - 1) * s
        gfx.color(i == cur and "#0F2A33" or "#081A21")
        gfx.rect(x + 3, y + 3, s - 6, s - 6)
        if i == cur then frame(x + 3, y + 3, s - 6, s - 6, C.amber) end
        conduit(x + 3, y + 3, s - 6, mask(tiles[r][c]), on[r * 10 + c])
        rects[i] = {x, y, s, s}
      end
    end
  else
    -- what the logs gave
    local hint = ""
    for i = 1, 4 do hint = hint .. ((digits and digits[i]) and T.code:sub(i, i) or "_") .. " " end
    gfx.color(C.dim)
    gfx.text(TR("term_logs") .. "  " .. hint, x0 + 22, y0 + 104, 14, "mono")
    -- entry
    local ex = x0 + 22
    for i = 1, 4 do
      local bx = ex + (i - 1) * 54
      gfx.color("#081A21")
      gfx.rect(bx, y0 + 134, 46, 58)
      frame(bx, y0 + 134, 46, 58, i == #entry + 1 and C.amber or "#2C4650")
      gfx.color(C.cyan)
      gfx.text(entry:sub(i, i), bx, y0 + 146, 32, "monobold", "center", 46)
    end
    if msgT > 0 then
      gfx.color(C.red)
      gfx.text(TR(msg), ex, y0 + 210, 16, "monobold")
    end
    local keys = {"1", "2", "3", "4", "5", "6", "7", "8", "9", "CLR", "0", "OK"}
    local s = floor(min(76, (ph - 150) / 4))
    local kx, ky = x0 + pw - 3 * s - 30, y0 + 120
    for i, k in ipairs(keys) do
      local c, r = (i - 1) % 3, floor((i - 1) / 3)
      local x, y = kx + c * s, ky + r * s
      gfx.color(i == cur and "#12313B" or "#081A21")
      gfx.rect(x + 3, y + 3, s - 6, s - 6)
      frame(x + 3, y + 3, s - 6, s - 6, i == cur and C.amber or "#2C4650")
      gfx.color(k == "OK" and C.amber or C.text)
      gfx.text(k, x, y + s / 2 - 10, 20, "monobold", "center", s)
      rects[i] = {x, y, s, s}
    end
  end
  if flash > 0 then
    gfx.color(C.cyan)
    gfx.text(TR("term_ok"), x0, y0 + ph - 60, 26, "monobold", "center", pw)
  end
  gfx.color(C.dim)
  gfx.text(TR("term_keys"), x0 + 22, y0 + ph - 26, 12, "mono")
  rects.close = {x0 + pw - 50, y0 + 6, 44, 30}
  gfx.color(C.text)
  gfx.text("X", x0 + pw - 50, y0 + 10, 18, "monobold", "center", 44)
end

return T
