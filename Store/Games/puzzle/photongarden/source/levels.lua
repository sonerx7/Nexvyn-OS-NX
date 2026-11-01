-- levels.lua: Photon Garden's rules and levels (no drawing here).
-- A board is a grid of cells; each cell holds at most one piece:
--   emit   {c = colour mask, d = direction}            a seed pod that shines a beam (blocks other beams)
--   target {need = colour mask}                         a crystal bud; blooms when exactly `need` reaches it
--   thorn  {}                                           nightshade: no beam may touch it
--   wall   {}                                           stone: stops beams
--   mirror {o = 0 "/" | 1 "\"}                          turns a beam by 90 degrees
--   split  {o = 0 | 1}                                  half mirror: the beam goes on and turns
--   filter {c = colour mask}                            lets only its colour through
--   portal {id = 1..3}                                  a beam entering one leaves its twin, same direction
-- Pieces carry lock = "fixed" (cannot be touched), "rot" (can be turned) or "free" (placed by the player).
-- Colours are bit masks: red 1, green 2, blue 4 (yellow 3, magenta 5, cyan 6, white 7).
local L = {}

L.DX = {[0] = 1, 0, -1, 0}
L.DY = {[0] = 0, 1, 0, -1}
L.WORLDS = 6
L.PER_WORLD = 20
L.COUNT = L.WORLDS * L.PER_WORLD

local floor = math.floor

-- ---------------------------------------------------------------- random numbers (same levels on every console)
function L.rng(seed)
  local s = floor(seed) % 2147483647
  if s <= 0 then s = s + 2147483646 end
  return function(a, b)
    s = s * 16807 % 2147483647
    local r = (s - 1) / 2147483646
    if a then return a + floor(r * (b - a + 1)) end
    return r
  end
end

-- ---------------------------------------------------------------- boards
function L.newBoard(w, h)
  local b = {w = w, h = h, cells = {}, inv = {}, sol = {}}
  for y = 0, h - 1 do b.cells[y] = {} end
  return b
end
function L.get(b, x, y)
  if x < 0 or y < 0 or x >= b.w or y >= b.h then return nil, true end
  return b.cells[y][x], false
end
function L.set(b, x, y, p) b.cells[y][x] = p end
function L.copyPiece(p)
  if not p then return nil end
  local q = {}
  for k, v in pairs(p) do q[k] = v end
  return q
end
function L.copyBoard(b)
  local c = L.newBoard(b.w, b.h)
  for y = 0, b.h - 1 do
    for x = 0, b.w - 1 do c.cells[y][x] = L.copyPiece(b.cells[y][x]) end
  end
  for i, it in ipairs(b.inv) do c.inv[i] = {t = it.t, c = it.c, n = it.n} end
  for i, s in ipairs(b.sol) do c.sol[i] = L.copyPiece(s) end
  c.name, c.par = b.name, b.par
  return c
end

local function reflect(d, o)
  -- "/" : right <-> up, left <-> down ; "\" : right <-> down, left <-> up
  if o == 0 then return ({[0] = 3, 2, 1, 0})[d] end
  return ({[0] = 1, 0, 3, 2})[d]
end
L.reflect = reflect

-- ---------------------------------------------------------------- beams
-- trace(b) -> {segs = {x1, y1, x2, y2, c, ...} in cell units (centre = x + 0.5), hits = {[piece] = mask},
--              thorn = piece hit or nil, solved = bool, lit = count of satisfied targets, targets = count}
function L.trace(b)
  local segs, n = {}, 0
  local hits = {}
  local seen = {}
  local thorn = nil
  local W, H = b.w, b.h
  local stack, sn = {}, 0
  local function seg(x1, y1, x2, y2, c)
    segs[n + 1], segs[n + 2], segs[n + 3], segs[n + 4], segs[n + 5] = x1, y1, x2, y2, c
    n = n + 5
  end
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local p = b.cells[y][x]
      if p and p.t == "emit" then
        sn = sn + 1
        stack[sn] = {x, y, p.d, p.c}
      end
    end
  end
  local guard = 0
  while sn > 0 do
    local s = stack[sn]
    stack[sn] = nil
    sn = sn - 1
    local x, y, d, c = s[1], s[2], s[3], s[4]
    local sx, sy = x + 0.5, y + 0.5
    while true do
      guard = guard + 1
      if guard > 20000 then break end
      local dx, dy = L.DX[d], L.DY[d]
      local nx, ny = x + dx, y + dy
      if nx < 0 or ny < 0 or nx >= W or ny >= H then
        seg(sx, sy, nx + 0.5 - dx * 0.5, ny + 0.5 - dy * 0.5, c)
        break
      end
      local key = ((ny * W + nx) * 4 + d) * 8 + c
      if seen[key] then seg(sx, sy, nx + 0.5, ny + 0.5, c) break end
      seen[key] = true
      local p = b.cells[ny][nx]
      local cx, cy = nx + 0.5, ny + 0.5
      x, y = nx, ny
      if p then
        local t = p.t
        if t == "wall" or t == "emit" then
          seg(sx, sy, cx - dx * 0.5, cy - dy * 0.5, c)
          break
        elseif t == "target" then
          seg(sx, sy, cx, cy, c)
          hits[p] = (hits[p] or 0) | c
          break
        elseif t == "thorn" then
          seg(sx, sy, cx, cy, c)
          thorn = thorn or p
          hits[p] = (hits[p] or 0) | c
          break
        elseif t == "mirror" then
          seg(sx, sy, cx, cy, c)
          d = reflect(d, p.o)
          sx, sy = cx, cy
        elseif t == "split" then
          seg(sx, sy, cx, cy, c)
          sn = sn + 1
          stack[sn] = {nx, ny, reflect(d, p.o), c}
          sx, sy = cx, cy
        elseif t == "filter" then
          local c2 = c & p.c
          if c2 == 0 then
            seg(sx, sy, cx - dx * 0.5, cy - dy * 0.5, c)
            hits[p] = (hits[p] or 0) | c
            break
          end
          seg(sx, sy, cx, cy, c)
          hits[p] = (hits[p] or 0) | c
          c = c2
          sx, sy = cx, cy
        elseif t == "portal" then
          seg(sx, sy, cx, cy, c)
          local ox, oy = L.twin(b, nx, ny, p.id)
          if not ox then break end
          x, y = ox, oy
          sx, sy = ox + 0.5, oy + 0.5
        end
      end
    end
  end
  local lit, total = 0, 0
  for yy = 0, H - 1 do
    for xx = 0, W - 1 do
      local p = b.cells[yy][xx]
      if p and p.t == "target" then
        total = total + 1
        if hits[p] == p.need then lit = lit + 1 end
      end
    end
  end
  return {segs = segs, n = n, hits = hits, thorn = thorn, lit = lit, targets = total,
          solved = total > 0 and lit == total and thorn == nil}
end

function L.twin(b, x, y, id)
  for yy = 0, b.h - 1 do
    for xx = 0, b.w - 1 do
      local p = b.cells[yy][xx]
      if p and p.t == "portal" and p.id == id and (xx ~= x or yy ~= y) then return xx, yy end
    end
  end
end

-- ---------------------------------------------------------------- level codes (handmade levels, editor, sharing)
-- One token per cell, rows separated by "/":  .. empty  ## wall  T* target  X! thorn
--   emitter: colour R G B Y M C W + direction > v < ^      mirror: "/" or "\" + f r i (fixed, turnable, in the bag)
--   splitter: S ("/") or Z ("\") + f r i                  filter: F + r g b ; with "i" after it in the bag: Fr Fi?
--   portal: P1 P2 P3
-- A level code is "PG1;<w>;<h>;<name>;<cells>" (the editor and the share button write it).
local CCHAR = {R = 1, G = 2, B = 4, Y = 3, M = 5, C = 6, W = 7}
local CNAME = {[1] = "R", [2] = "G", [4] = "B", [3] = "Y", [5] = "M", [6] = "C", [7] = "W"}
local DCHAR = {[">"] = 0, v = 1, ["<"] = 2, ["^"] = 3}
local DNAME = {[0] = ">", "v", "<", "^"}
local FCHAR = {r = 1, g = 2, b = 4}
local FNAME = {[1] = "r", [2] = "g", [4] = "b"}
local LOCKC = {f = "fixed", r = "rot", i = "bag"}
local LOCKN = {fixed = "f", rot = "r", bag = "i", free = "i"}
L.CNAME = CNAME

function L.parseToken(tok)
  local a, b2 = tok:sub(1, 1), tok:sub(2, 2)
  if tok == ".." or tok == "" then return nil end
  if tok == "##" then return {t = "wall", lock = "fixed"} end
  if tok == "T*" then return {t = "target", lock = "fixed"} end
  if tok == "X!" then return {t = "thorn", lock = "fixed"} end
  if CCHAR[a] and DCHAR[b2] then return {t = "emit", c = CCHAR[a], d = DCHAR[b2], lock = "fixed"} end
  if (a == "/" or a == "\\") and LOCKC[b2] then return {t = "mirror", o = a == "/" and 0 or 1, lock = LOCKC[b2]} end
  if (a == "S" or a == "Z") and LOCKC[b2] then return {t = "split", o = a == "S" and 0 or 1, lock = LOCKC[b2]} end
  if a == "F" and FCHAR[b2] then return {t = "filter", c = FCHAR[b2], lock = "fixed"} end
  if a == "f" and FCHAR[b2] then return {t = "filter", c = FCHAR[b2], lock = "bag"} end
  if a == "P" and tonumber(b2) then return {t = "portal", id = tonumber(b2), lock = "fixed"} end
  return nil
end
function L.token(p)
  if not p then return ".." end
  local t = p.t
  if t == "wall" then return "##" elseif t == "target" then return "T*" elseif t == "thorn" then return "X!" end
  if t == "emit" then return CNAME[p.c] .. DNAME[p.d] end
  if t == "mirror" then return (p.o == 0 and "/" or "\\") .. (LOCKN[p.lock] or "f") end
  if t == "split" then return (p.o == 0 and "S" or "Z") .. (LOCKN[p.lock] or "f") end
  if t == "filter" then return ((p.lock == "bag" or p.lock == "free") and "f" or "F") .. FNAME[p.c] end
  if t == "portal" then return "P" .. p.id end
  return ".."
end

-- solution rows -> a playable board: bag pieces go to the inventory, turnable ones are turned away
function L.fromRows(rows, name, rnd)
  local h = #rows
  local toks = {}
  local w = 0
  for y = 1, h do
    toks[y] = {}
    for tok in rows[y]:gmatch("%S+") do toks[y][#toks[y] + 1] = tok end
    w = math.max(w, #toks[y])
  end
  local sol = L.newBoard(w, h)
  for y = 0, h - 1 do
    for x = 0, w - 1 do L.set(sol, x, y, L.parseToken(toks[y + 1][x + 1] or "..")) end
  end
  sol.name = name
  return L.prepare(sol, rnd)
end

-- a solved board -> the puzzle: computes the targets' colours, empties the bag cells, turns the turnable pieces
function L.prepare(sol, rnd)
  rnd = rnd or L.rng(7)
  for y = 0, sol.h - 1 do
    for x = 0, sol.w - 1 do
      local p = sol.cells[y][x]
      if p and p.t == "target" then p.need = 7 end
    end
  end
  local r = L.trace(sol)
  for y = 0, sol.h - 1 do
    for x = 0, sol.w - 1 do
      local p = sol.cells[y][x]
      if p and p.t == "target" then p.need = r.hits[p] or 0 end
    end
  end
  local b = L.copyBoard(sol)
  b.inv, b.sol = {}, {}
  local par = 0
  local bag = {}
  for y = 0, b.h - 1 do
    for x = 0, b.w - 1 do
      local p = b.cells[y][x]
      if p and (p.lock == "bag" or p.lock == "free") then
        b.sol[#b.sol + 1] = {x = x, y = y, t = p.t, o = p.o, c = p.c, bag = true}
        local key = p.t .. (p.t == "filter" and p.c or "")
        if not bag[key] then
          bag[key] = {t = p.t, c = p.t == "filter" and p.c or nil, n = 0}
          b.inv[#b.inv + 1] = bag[key]
        end
        bag[key].n = bag[key].n + 1
        b.cells[y][x] = nil
        par = par + 1 + ((p.t == "mirror" or p.t == "split") and p.o ~= 0 and 1 or 0)
      elseif p and p.lock == "rot" then
        b.sol[#b.sol + 1] = {x = x, y = y, t = p.t, o = p.o, c = p.c}
        p.o = 1 - p.o
        par = par + 1
      end
    end
  end
  b.par = par
  b.ok = L.trace(sol).solved
  return b
end

function L.encode(sol, name)
  local rows = {}
  for y = 0, sol.h - 1 do
    local t = {}
    for x = 0, sol.w - 1 do t[#t + 1] = L.token(sol.cells[y][x]) end
    rows[#rows + 1] = table.concat(t, " ")
  end
  name = (name or ""):gsub("[;/]", " ")
  return "PG1;" .. sol.w .. ";" .. sol.h .. ";" .. name .. ";" .. table.concat(rows, "/")
end
-- code -> solution board (or nil, reason)
function L.decode(code)
  if type(code) ~= "string" then return nil end
  local w, h, name, cells = code:match("^%s*PG1;(%d+);(%d+);([^;]*);(.+)$")
  w, h = tonumber(w), tonumber(h)
  if not w or w < 3 or h < 3 or w > 12 or h > 9 then return nil end
  local rows = {}
  for r in (cells .. "/"):gmatch("([^/]*)/") do rows[#rows + 1] = r end
  if #rows ~= h then return nil end
  local sol = L.newBoard(w, h)
  for y = 0, h - 1 do
    local x = 0
    for tok in rows[y + 1]:gmatch("%S+") do
      if x < w then L.set(sol, x, y, L.parseToken(tok)) end
      x = x + 1
    end
  end
  sol.name = name
  return sol
end

-- ---------------------------------------------------------------- generator
-- Builds a solved board by walking beams from the emitters and dropping pieces where they turn, then hides some of
-- the pieces in the bag and turns some others away. Every generated level is solvable by construction and checked.
local function free(b, used, x, y)
  if x < 0 or y < 0 or x >= b.w or y >= b.h then return false end
  return b.cells[y][x] == nil and not used[y * b.w + x]
end

function L.generate(spec, seed)
  local rnd = L.rng(seed)
  for attempt = 1, 400 do
    local b = L.newBoard(spec.w, spec.h)
    local used = {}         -- cells a beam passes straight through (no piece may go there)
    local turns = {}        -- placed beam pieces (candidates for bag / turnable)
    local targets = {}
    local ok = true
    local portalId = 0
    local function mark(x, y) used[y * b.w + x] = true end

    local function walk(x, y, d, c, budget, depth)
      if depth > 6 then return false end
      for _ = 1, 60 do
        -- run straight for a few cells
        local run = rnd(spec.minRun or 1, spec.maxRun or 4)
        for step = 1, run do
          local nx, ny = x + L.DX[d], y + L.DY[d]
          local p = L.get(b, nx, ny)
          if nx < 0 or ny < 0 or nx >= b.w or ny >= b.h or p then return false end
          x, y = nx, ny
          if step < run then mark(x, y) end
        end
        -- the cell we stand on gets a piece (unless a beam already crosses it)
        if used[y * b.w + x] then
          -- crossing an earlier beam: keep running
        elseif budget <= 0 then
          -- end on a target already in line sometimes (colours mix there), else on a new target
          if spec.mix and rnd() < 0.7 then
            local tx, ty, path = x, y, {}
            while true do
              tx, ty = tx + L.DX[d], ty + L.DY[d]
              local p, out = L.get(b, tx, ty)
              if out then break end
              if p then
                if p.t == "target" then
                  mark(x, y)
                  for _, c2 in ipairs(path) do mark(c2[1], c2[2]) end
                  return true
                end
                break
              end
              path[#path + 1] = {tx, ty}
            end
          end
          b.cells[y][x] = {t = "target", lock = "fixed"}
          targets[#targets + 1] = {x = x, y = y}
          return true
        else
          local roll = rnd()
          if spec.portals and portalId < spec.portals and roll < 0.22 then
            -- portal: jump to a free cell somewhere else
            local ox, oy
            for _ = 1, 40 do
              local tx, ty = rnd(0, b.w - 1), rnd(0, b.h - 1)
              if free(b, used, tx, ty) and (math.abs(tx - x) + math.abs(ty - y)) > 2 and
                 free(b, used, tx + L.DX[d], ty + L.DY[d]) then ox, oy = tx, ty break end
            end
            if not ox then return false end
            portalId = portalId + 1
            b.cells[y][x] = {t = "portal", id = portalId, lock = "fixed"}
            b.cells[oy][ox] = {t = "portal", id = portalId, lock = "fixed"}
            x, y = ox, oy
            budget = budget - 1
          elseif spec.filters and c ~= 1 and c ~= 2 and c ~= 4 and roll < 0.45 then
            local bits = {}
            for _, bit in ipairs({1, 2, 4}) do if c & bit ~= 0 then bits[#bits + 1] = bit end end
            local keep = bits[rnd(1, #bits)]
            b.cells[y][x] = {t = "filter", c = keep, lock = "fixed"}
            turns[#turns + 1] = {x = x, y = y, filter = true}
            c = keep
            budget = budget - 1
          elseif spec.splits and roll < (spec.splitChance or 0.4) and depth < 3 then
            local o = rnd(0, 1)
            b.cells[y][x] = {t = "split", o = o, lock = "fixed"}
            turns[#turns + 1] = {x = x, y = y}
            local half = math.max(1, budget // 2)
            if not walk(x, y, reflect(d, o), c, half - 1, depth + 1) then return false end
            budget = budget - half
          else
            local o = rnd(0, 1)
            b.cells[y][x] = {t = "mirror", o = o, lock = "fixed"}
            turns[#turns + 1] = {x = x, y = y}
            d = reflect(d, o)
            budget = budget - 1
          end
        end
      end
      return false
    end

    -- emitters on cells with room ahead
    local colors = spec.colors or {1}
    for e = 1, spec.emitters or 1 do
      local placed = false
      for _ = 1, 60 do
        local x, y = rnd(0, b.w - 1), rnd(0, b.h - 1)
        local d = rnd(0, 3)
        -- prefer the rim, facing in
        if rnd() < 0.7 then
          local side = rnd(0, 3)
          if side == 0 then x, d = 0, 0 elseif side == 1 then x, d = b.w - 1, 2
          elseif side == 2 then y, d = 0, 1 else y, d = b.h - 1, 3 end
        end
        if free(b, used, x, y) and free(b, used, x + L.DX[d], y + L.DY[d]) then
          local c = colors[(e - 1) % #colors + 1]
          b.cells[y][x] = {t = "emit", c = c, d = d, lock = "fixed"}
          if walk(x, y, d, c, rnd(spec.minTurns or 1, spec.maxTurns or 2), 0) then placed = true end
          break
        end
      end
      if not placed then ok = false break end
    end

    if ok and #turns >= (spec.bag or 1) + (spec.rot or 0) then
      -- walls and thorns away from the beams, thorns next to them
      local nearBeam = {}
      for y = 0, b.h - 1 do
        for x = 0, b.w - 1 do
          if used[y * b.w + x] or b.cells[y][x] then
            for d = 0, 3 do nearBeam[(y + L.DY[d]) * b.w + x + L.DX[d]] = true end
          end
        end
      end
      local function drop(kind, n, near)
        for _ = 1, n do
          for _ = 1, 30 do
            local x, y = rnd(0, b.w - 1), rnd(0, b.h - 1)
            if free(b, used, x, y) and (not near or nearBeam[y * b.w + x]) then
              b.cells[y][x] = {t = kind, lock = "fixed"}
              break
            end
          end
        end
      end
      drop("thorn", spec.thorns or 0, true)
      drop("wall", spec.walls or 0, false)
      -- shuffle the beam pieces, then pick the bag and the turnable ones
      for i = #turns, 2, -1 do
        local j = rnd(1, i)
        turns[i], turns[j] = turns[j], turns[i]
      end
      local nb, nr = 0, 0
      for _, t in ipairs(turns) do
        local p = b.cells[t.y][t.x]
        if t.filter then
          if spec.bagFilters and nb < (spec.bag or 1) then p.lock = "bag"; nb = nb + 1 end
        elseif nb < (spec.bag or 1) then
          p.lock = "bag"; nb = nb + 1
        elseif nr < (spec.rot or 0) then
          p.lock = "rot"; nr = nr + 1
        end
      end
      local lvl = L.prepare(b, rnd)
      if lvl.ok and #lvl.inv > 0 and not L.trace(lvl).solved then
        lvl.seed = seed
        return lvl, b
      end
    end
  end
  return nil
end

-- ---------------------------------------------------------------- the campaign
-- Six gardens of twenty levels. The first levels of each garden are handmade and introduce its new piece; the rest
-- are generated from fixed seeds with a rising difficulty.
local HAND = {
  -- 1: mirrors
  {"..  ..  ..  ..  ..", "R>  ..  ..  \\i  ..", "..  ..  ..  ..  ..", "..  ..  ..  T*  .."},
  {"R>  ..  \\i  ..  ##  ..", "..  ..  ..  ..  ##  ..", "..  ..  \\i  ..  ..  T*", "..  ..  ..  ..  ..  .."},
  {"..  ..  ..  ..  ..  ..", "R>  ..  \\r  ..  ..  ##", "..  ..  ..  ..  ..  ..", "..  ..  \\i  ..  ..  T*", "..  ..  ..  ..  ..  .."},
  -- 2: thorns and walls
  {"..  ..  ..  ..  ..  ..", "G>  ..  ..  \\i  X!  ..", "..  ..  ..  ..  ..  ..", "..  X!  ..  \\i  ..  T*", "..  ..  ..  ..  ..  .."},
  {"..  ##  ..  ..  ..  ..  ..", "G>  ..  \\r  ..  X!  ..  ..", "..  ..  ..  ..  ..  ..  ..", "..  X!  \\i  ..  \\i  ..  ..", "..  ..  ..  ..  ..  ..  ..", "..  ..  ..  ..  T*  ..  .."},
  -- 3: splitters
  {"..  ..  ..  T*  ..  ..", "..  ..  ..  ..  ..  ..", "B>  ..  ..  Si  ..  T*", "..  ..  ..  ..  ..  ..", "..  ..  ..  ..  ..  .."},
  {"..  T*  ..  ..  ..  ..  ..", "..  ..  ..  ..  ..  ..  ..", "B>  Si  ..  ..  \\r  ..  ..", "..  ..  ..  ..  ..  ..  ..", "..  ..  ..  ..  T*  X!  .."},
  -- 4: colours
  {"..  ..  ..  ..  ..  ..", "R>  ..  \\i  ..  ..  ..", "..  ..  ..  ..  ..  ..", "G>  ..  T*  ..  ..  ..", "..  ..  ..  ..  ..  .."},
  {"..  ..  ..  ..  ..  ..", "R>  ..  \\i  ..  ..  ..", "..  ..  ..  ..  ..  ..", "..  ..  T*  ..  \\i  ..", "..  ..  ..  ..  ..  ..", "..  ..  ..  ..  B^  .."},
  -- 5: filters
  {"..  ..  ..  ..  ..  ..", "W>  ..  Fr  ..  \\i  ..", "..  ..  ..  ..  ..  ..", "..  ..  ..  ..  T*  ..", "..  ..  ..  ..  ..  .."},
  {"..  ..  ..  ..  T*  ..  ..", "..  ..  ..  ..  Fb  ..  ..", "W>  ..  ..  ..  Si  Fg  T*", "..  ..  ..  ..  ..  ..  ..", "..  ..  ..  ..  ..  ..  .."},
  -- 6: portals
  {"..  ..  ..  ..  ..  ..", "R>  ..  P1  ##  ..  ..", "..  ..  ..  ##  ..  ..", "..  ..  ..  ##  P1  \\i", "..  ..  ..  ##  ..  ..", "..  ..  ..  ##  ..  T*"},
  {"..  ..  ..  ##  ..  ..  ..", "Y>  P1  ..  ##  ..  X!  ..", "..  ..  ..  ##  ..  ..  ..", "..  ..  ..  ##  P1  Zi  T*", "..  ..  ..  ##  ..  ..  ..", "..  ..  ..  ##  ..  T*  .."}
}
-- where the handmade levels go in each garden
local HAND_AT = {{1, 2, 3}, {1, 2}, {1, 2}, {1, 2}, {1, 2}, {1, 2}}

local WORLD_SPEC = {
  {colors = {1}},
  {colors = {2}, thorns = 2, walls = 2},
  {colors = {4}, splits = true, thorns = 1, walls = 2},
  {colors = {1, 2, 4}, splits = true, thorns = 1, walls = 1, mix = true},
  {colors = {7, 7}, splits = true, filters = true, thorns = 1, walls = 1},
  {colors = {3, 6, 5}, splits = true, filters = true, portals = 1, thorns = 2, walls = 2, mix = true},
}

-- spec of generated level i (1..20) of garden g
local function specFor(g, i)
  local ws = WORLD_SPEC[g]
  local k = (i - 1) / 19                       -- 0..1 through the garden
  local s = {}
  for key, v in pairs(ws) do s[key] = v end
  s.w = math.min(10, 6 + floor(k * 4 + 0.5) + (g >= 4 and 1 or 0))
  s.h = math.min(7, 5 + floor(k * 2 + 0.5))
  s.emitters = math.min(#ws.colors + (g == 1 and k > 0.5 and 1 or 0), 1 + floor(k * 2.2))
  if g >= 4 then s.emitters = math.max(2, s.emitters) end
  s.minTurns, s.maxTurns = 1 + floor(k * 1.5), 2 + floor(k * 3)
  s.bag = 1 + floor(k * 3.6 + 0.3) + (g >= 4 and 1 or 0)
  s.rot = floor(k * 2.6 + (g >= 2 and 0.5 or 0))
  s.thorns = (ws.thorns or 0) + floor(k * 2)
  s.walls = (ws.walls or 0) + floor(k * 3)
  s.bagFilters = g >= 5 and k > 0.5
  s.splitChance = 0.45
  return s
end

local cache = {}
-- L.level(n) -> board (1..COUNT); generated levels are made once per run
function L.level(n)
  if cache[n] then return L.copyBoard(cache[n]) end
  local g = (n - 1) // L.PER_WORLD + 1
  local i = (n - 1) % L.PER_WORLD + 1
  local lvl
  local handIdx = 0
  for gg = 1, g - 1 do handIdx = handIdx + #HAND_AT[gg] end
  for k, at in ipairs(HAND_AT[g]) do
    if at == i then lvl = L.fromRows(HAND[handIdx + k], nil, L.rng(n * 31)) end
  end
  if not lvl then
    local spec = specFor(g, i)
    for tries = 0, 30 do
      lvl = L.generate(spec, 9001 + n * 7919 + tries * 104729)
      if lvl then break end
      spec.bag = math.max(1, spec.bag - 1)
      spec.rot = math.max(0, spec.rot - 1)
    end
  end
  lvl.index, lvl.world = n, g
  cache[n] = lvl
  return L.copyBoard(lvl)
end
function L.worldOf(n) return (n - 1) // L.PER_WORLD + 1 end

return L
