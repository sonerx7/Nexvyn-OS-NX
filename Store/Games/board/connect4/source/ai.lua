-- ai.lua: Connect Four engine. Board = {cells = [1..42] (0 empty, 1, 2), h = [1..7] column heights}.
-- Cell index = (row - 1) * 7 + col, row 1 is the bottom. Negamax alpha-beta with iterative deepening that runs inside a
-- coroutine and yields when the per-frame time slice (A.sliceEnd, os.clock) is used up.
local A = {COLS = 7, ROWS = 6}
local COLS, ROWS = 7, 6
local ORDER = {4, 3, 5, 2, 6, 1, 7}
local WIN = 1000000

-- every 4-in-a-row window, precomputed
local WINDOWS = {}
do
  local dirs = {{1, 0}, {0, 1}, {1, 1}, {1, -1}}
  for r = 1, ROWS do
    for c = 1, COLS do
      for _, d in ipairs(dirs) do
        local er, ec = r + d[2] * 3, c + d[1] * 3
        if er >= 1 and er <= ROWS and ec >= 1 and ec <= COLS then
          local w = {}
          for k = 0, 3 do w[k + 1] = (r + d[2] * k - 1) * COLS + (c + d[1] * k) end
          WINDOWS[#WINDOWS + 1] = w
        end
      end
    end
  end
end
local CENTER = {0, 1, 2, 3, 2, 1, 0}

function A.new()
  local b = {cells = {}, h = {}}
  for i = 1, COLS * ROWS do b.cells[i] = 0 end
  for c = 1, COLS do b.h[c] = 0 end
  return b
end

function A.copy(b)
  local n = {cells = {}, h = {}}
  for i = 1, COLS * ROWS do n.cells[i] = b.cells[i] end
  for c = 1, COLS do n.h[c] = b.h[c] end
  return n
end

function A.canDrop(b, c) return c >= 1 and c <= COLS and b.h[c] < ROWS end

function A.drop(b, c, p)
  local r = b.h[c] + 1
  b.h[c] = r
  b.cells[(r - 1) * COLS + c] = p
  return r
end

function A.undrop(b, c)
  local r = b.h[c]
  b.cells[(r - 1) * COLS + c] = 0
  b.h[c] = r - 1
end

function A.full(b)
  for c = 1, COLS do if b.h[c] < ROWS then return false end end
  return true
end

-- winning line through (c, r) for player p, or nil
function A.winLine(b, c, r, p)
  local cells = b.cells
  for _, d in ipairs({{1, 0}, {0, 1}, {1, 1}, {1, -1}}) do
    local line = {(r - 1) * COLS + c}
    for s = -1, 1, 2 do
      local cc, rr = c + d[1] * s, r + d[2] * s
      while cc >= 1 and cc <= COLS and rr >= 1 and rr <= ROWS and cells[(rr - 1) * COLS + cc] == p do
        line[#line + 1] = (rr - 1) * COLS + cc
        cc, rr = cc + d[1] * s, rr + d[2] * s
      end
    end
    if #line >= 4 then return line end
  end
  return nil
end

local function isWin(b, c, r, p)
  local cells = b.cells
  for _, d in ipairs({{1, 0}, {0, 1}, {1, 1}, {1, -1}}) do
    local n = 1
    for s = -1, 1, 2 do
      local cc, rr = c + d[1] * s, r + d[2] * s
      while cc >= 1 and cc <= COLS and rr >= 1 and rr <= ROWS and cells[(rr - 1) * COLS + cc] == p do
        n = n + 1
        cc, rr = cc + d[1] * s, rr + d[2] * s
      end
    end
    if n >= 4 then return true end
  end
  return false
end
A.isWin = isWin

local function evaluate(b, p)
  local cells = b.cells
  local o = 3 - p
  local s = 0
  for i = 1, #WINDOWS do
    local w = WINDOWS[i]
    local mine, theirs = 0, 0
    for k = 1, 4 do
      local v = cells[w[k]]
      if v == p then mine = mine + 1 elseif v == o then theirs = theirs + 1 end
    end
    if theirs == 0 then
      if mine == 3 then s = s + 40 elseif mine == 2 then s = s + 4 end
    elseif mine == 0 then
      if theirs == 3 then s = s - 40 elseif theirs == 2 then s = s - 4 end
    end
  end
  for r = 1, ROWS do
    local base = (r - 1) * COLS
    for c = 1, COLS do
      local v = cells[base + c]
      if v == p then s = s + CENTER[c] * 2 elseif v == o then s = s - CENTER[c] * 2 end
    end
  end
  return s
end

A.sliceEnd = 0
local nodes, deadline, aborted = 0, 0, false

local function negamax(b, depth, alpha, beta, p)
  nodes = nodes + 1
  if nodes % 128 == 0 then
    if sys.time() > deadline then aborted = true end
    if coroutine.isyieldable() and os.clock() > A.sliceEnd then coroutine.yield() end
  end
  if aborted then return 0 end
  local h = b.h
  for c = 1, COLS do
    if h[c] < ROWS then
      local r = A.drop(b, c, p)
      local w = isWin(b, c, r, p)
      A.undrop(b, c)
      if w then return WIN + depth end
    end
  end
  if depth <= 0 then return evaluate(b, p) end
  local best, any = -WIN * 2, false
  for i = 1, COLS do
    local c = ORDER[i]
    if h[c] < ROWS then
      any = true
      A.drop(b, c, p)
      local s = -negamax(b, depth - 1, -beta, -alpha, 3 - p)
      A.undrop(b, c)
      if s > best then best = s end
      if s > alpha then alpha = s end
      if alpha >= beta then break end
    end
  end
  if not any then return 0 end
  return best
end

-- Best column for player p. opts = {depth, time (seconds), noise}. Call inside a coroutine for time slicing.
function A.search(board, p, opts)
  local b = A.copy(board)
  local maxDepth = opts.depth or 6
  deadline = sys.time() + (opts.time or 2)
  aborted = false
  nodes = 0
  local order = {}
  for i = 1, COLS do if b.h[ORDER[i]] < ROWS then order[#order + 1] = ORDER[i] end end
  if #order == 0 then return nil end
  -- immediate win
  for _, c in ipairs(order) do
    local r = A.drop(b, c, p)
    local w = isWin(b, c, r, p)
    A.undrop(b, c)
    if w then return c end
  end
  local bestMove = order[1]
  for depth = 1, maxDepth do
    local alpha, beta = -WIN * 2, WIN * 2
    local scores, bestS, bestC = {}, -WIN * 3, nil
    for _, c in ipairs(order) do
      A.drop(b, c, p)
      local s = -negamax(b, depth - 1, -beta, -alpha, 3 - p)
      A.undrop(b, c)
      if aborted then break end
      if opts.noise then s = s + math.random(-opts.noise, opts.noise) end
      scores[c] = s
      if s > bestS then bestS, bestC = s, c end
      -- with noise every root move needs an exact score (full window), otherwise bounds would be compared
      if not opts.noise and s > alpha then alpha = s end
    end
    if aborted then break end
    bestMove = bestC or bestMove
    A.lastDepth = depth
    -- best move first on the next iteration
    table.sort(order, function(x, y) return (scores[x] or -WIN * 3) > (scores[y] or -WIN * 3) end)
    if bestS >= WIN then break end
  end
  return bestMove
end

return A
