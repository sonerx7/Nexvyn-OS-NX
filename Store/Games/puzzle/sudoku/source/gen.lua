-- gen.lua: Sudoku solver and generator. Grids are arrays [1..81] of 0..9 (0 = empty), index = row * 9 + col + 1.
-- The generator makes a random full grid, then removes cells (in symmetric pairs) while the puzzle still has exactly
-- one solution. Call S.generate inside a coroutine: it yields whenever the frame slice (S.sliceEnd, os.clock) is used.
local S = {}

local ROW, COL, BOX = {}, {}, {}
for i = 1, 81 do
  local r, c = (i - 1) // 9, (i - 1) % 9
  ROW[i], COL[i], BOX[i] = r + 1, c + 1, (r // 3) * 3 + c // 3 + 1
end
S.ROW, S.COL, S.BOX = ROW, COL, BOX

-- peers[i] = the 20 cells sharing a row, column or box with i
local PEERS = {}
for i = 1, 81 do
  local p = {}
  for j = 1, 81 do
    if j ~= i and (ROW[j] == ROW[i] or COL[j] == COL[i] or BOX[j] == BOX[i]) then p[#p + 1] = j end
  end
  PEERS[i] = p
end
S.PEERS = PEERS

local FULL = 0x3FE   -- bits 1..9
local POP = {}
for m = 0, 1023 do
  local n, x = 0, m
  while x ~= 0 do x = x & (x - 1); n = n + 1 end
  POP[m] = n
end

S.sliceEnd = math.huge
local function maybeYield()
  if coroutine.isyieldable() and os.clock() > S.sliceEnd then coroutine.yield() end
end

-- counts solutions up to `limit`; rows/cols/boxes are used-digit masks. Fills g with the first solution if fill.
local function search(g, rm, cm, bm, limit, count, rand, steps)
  steps[1] = steps[1] + 1
  if steps[1] % 64 == 0 then maybeYield() end
  -- pick the empty cell with the fewest candidates
  local best, bestMask, bestN = nil, 0, 10
  for i = 1, 81 do
    if g[i] == 0 then
      local m = FULL & ~(rm[ROW[i]] | cm[COL[i]] | bm[BOX[i]])
      local n = POP[m]
      if n < bestN then
        best, bestMask, bestN = i, m, n
        if n <= 1 then break end
      end
    end
  end
  if not best then return count + 1 end
  if bestN == 0 then return count end
  local digits = {}
  for d = 1, 9 do if bestMask & (1 << d) ~= 0 then digits[#digits + 1] = d end end
  if rand then
    for k = #digits, 2, -1 do local j = math.random(k); digits[k], digits[j] = digits[j], digits[k] end
  end
  local r, c, b = ROW[best], COL[best], BOX[best]
  for _, d in ipairs(digits) do
    local bit = 1 << d
    g[best] = d
    rm[r], cm[c], bm[b] = rm[r] | bit, cm[c] | bit, bm[b] | bit
    count = search(g, rm, cm, bm, limit, count, rand, steps)
    rm[r], cm[c], bm[b] = rm[r] & ~bit, cm[c] & ~bit, bm[b] & ~bit
    if count >= limit then
      if rand then return count end   -- keep the filled grid
      g[best] = 0
      return count
    end
    g[best] = 0
  end
  return count
end

local function masks(g)
  local rm, cm, bm = {}, {}, {}
  for k = 1, 9 do rm[k], cm[k], bm[k] = 0, 0, 0 end
  for i = 1, 81 do
    local d = g[i]
    if d ~= 0 then
      local bit = 1 << d
      if (rm[ROW[i]] | cm[COL[i]] | bm[BOX[i]]) & bit ~= 0 then return nil end
      rm[ROW[i]], cm[COL[i]], bm[BOX[i]] = rm[ROW[i]] | bit, cm[COL[i]] | bit, bm[BOX[i]] | bit
    end
  end
  return rm, cm, bm
end

-- number of solutions (stops at limit)
function S.count(g, limit)
  local c = {}
  for i = 1, 81 do c[i] = g[i] end
  local rm, cm, bm = masks(c)
  if not rm then return 0 end
  return search(c, rm, cm, bm, limit or 2, 0, false, {0})
end

-- a solved copy of g, or nil
function S.solve(g)
  local c = {}
  for i = 1, 81 do c[i] = g[i] end
  local rm, cm, bm = masks(c)
  if not rm then return nil end
  if search(c, rm, cm, bm, 1, 0, true, {0}) < 1 then return nil end
  return c
end

-- givens: target number of clues (the result can have a few more when no further cell can be removed)
function S.generate(givens)
  local full = {}
  for i = 1, 81 do full[i] = 0 end
  local rm, cm, bm = masks(full)
  search(full, rm, cm, bm, 1, 0, true, {0})
  local puzzle = {}
  for i = 1, 81 do puzzle[i] = full[i] end
  local order = {}
  for i = 1, 41 do order[i] = i end
  for k = #order, 2, -1 do local j = math.random(k); order[k], order[j] = order[j], order[k] end
  local filled = 81
  for _, i in ipairs(order) do
    if filled <= givens then break end
    local j = 82 - i
    local a, b = puzzle[i], puzzle[j]
    puzzle[i], puzzle[j] = 0, 0
    if S.count(puzzle, 2) ~= 1 then
      puzzle[i], puzzle[j] = a, b
    else
      filled = filled - (i == j and 1 or 2)
    end
    maybeYield()
  end
  -- second pass with single cells to get closer to the target
  if filled > givens then
    local singles = {}
    for i = 1, 81 do if puzzle[i] ~= 0 then singles[#singles + 1] = i end end
    for k = #singles, 2, -1 do local j = math.random(k); singles[k], singles[j] = singles[j], singles[k] end
    for _, i in ipairs(singles) do
      if filled <= givens then break end
      local a = puzzle[i]
      puzzle[i] = 0
      if S.count(puzzle, 2) ~= 1 then puzzle[i] = a else filled = filled - 1 end
      maybeYield()
    end
  end
  return puzzle, full
end

return S
