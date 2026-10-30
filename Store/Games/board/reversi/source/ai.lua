-- ai.lua: Reversi (Othello) rules and engine. Board = array [1..64] of 0 / 1 (black) / 2 (white); index = row*8+col+1
-- with row, col in 0..7. Negamax alpha-beta with iterative deepening, positional weights + mobility, run inside a
-- coroutine that yields when the per-frame slice (R.sliceEnd, os.clock) is used up.
local R = {}

local DIRS = {{-1, -1}, {-1, 0}, {-1, 1}, {0, -1}, {0, 1}, {1, -1}, {1, 0}, {1, 1}}
local W = {
  100, -20, 10, 5, 5, 10, -20, 100,
  -20, -50, -2, -2, -2, -2, -50, -20,
  10, -2, 1, 1, 1, 1, -2, 10,
  5, -2, 1, 0, 0, 1, -2, 5,
  5, -2, 1, 0, 0, 1, -2, 5,
  10, -2, 1, 1, 1, 1, -2, 10,
  -20, -50, -2, -2, -2, -2, -50, -20,
  100, -20, 10, 5, 5, 10, -20, 100,
}
R.WEIGHTS = W
local BIG = 1000000

function R.new()
  local b = {}
  for i = 1, 64 do b[i] = 0 end
  b[28], b[37] = 2, 2      -- d4, e5 white
  b[29], b[36] = 1, 1      -- e4, d5 black
  return b
end

function R.copy(b)
  local n = {}
  for i = 1, 64 do n[i] = b[i] end
  return n
end

-- number of discs flipped by playing i (0 = illegal)
local function countFlips(b, i, p)
  if b[i] ~= 0 then return 0 end
  local o = 3 - p
  local r, c = (i - 1) // 8, (i - 1) % 8
  local total = 0
  for d = 1, 8 do
    local dr, dc = DIRS[d][1], DIRS[d][2]
    local rr, cc, n = r + dr, c + dc, 0
    while rr >= 0 and rr < 8 and cc >= 0 and cc < 8 and b[rr * 8 + cc + 1] == o do
      rr, cc, n = rr + dr, cc + dc, n + 1
    end
    if n > 0 and rr >= 0 and rr < 8 and cc >= 0 and cc < 8 and b[rr * 8 + cc + 1] == p then total = total + n end
  end
  return total
end
R.countFlips = countFlips

function R.moves(b, p, out)
  out = out or {}
  local n = 0
  for i = 1, 64 do
    if b[i] == 0 and countFlips(b, i, p) > 0 then n = n + 1; out[n] = i end
  end
  for k = n + 1, #out do out[k] = nil end
  return out, n
end

local function mobility(b, p)
  local n = 0
  for i = 1, 64 do
    if b[i] == 0 and countFlips(b, i, p) > 0 then n = n + 1 end
  end
  return n
end
R.mobility = mobility

-- plays i for p; returns the list of flipped indices
function R.play(b, i, p)
  local o = 3 - p
  local r, c = (i - 1) // 8, (i - 1) % 8
  local flipped = {}
  for d = 1, 8 do
    local dr, dc = DIRS[d][1], DIRS[d][2]
    local rr, cc, n = r + dr, c + dc, 0
    while rr >= 0 and rr < 8 and cc >= 0 and cc < 8 and b[rr * 8 + cc + 1] == o do
      rr, cc, n = rr + dr, cc + dc, n + 1
    end
    if n > 0 and rr >= 0 and rr < 8 and cc >= 0 and cc < 8 and b[rr * 8 + cc + 1] == p then
      for k = 1, n do
        local j = (r + dr * k) * 8 + (c + dc * k) + 1
        b[j] = p
        flipped[#flipped + 1] = j
      end
    end
  end
  b[i] = p
  return flipped
end

function R.unplay(b, i, p, flipped)
  b[i] = 0
  local o = 3 - p
  for k = 1, #flipped do b[flipped[k]] = o end
end

function R.count(b)
  local x, y = 0, 0
  for i = 1, 64 do
    if b[i] == 1 then x = x + 1 elseif b[i] == 2 then y = y + 1 end
  end
  return x, y
end

local function evaluate(b, p)
  local o = 3 - p
  local s, empty, mine, theirs = 0, 0, 0, 0
  for i = 1, 64 do
    local v = b[i]
    if v == p then s = s + W[i]; mine = mine + 1
    elseif v == o then s = s - W[i]; theirs = theirs + 1
    else empty = empty + 1 end
  end
  -- once a corner is taken the squares next to it are no longer dangerous
  for _, cn in ipairs({{1, 2, 9, 10}, {8, 7, 16, 15}, {57, 58, 49, 50}, {64, 63, 56, 55}}) do
    local owner = b[cn[1]]
    if owner ~= 0 then
      for k = 2, 4 do
        local v = b[cn[k]]
        if v == p then s = s - W[cn[k]] + 5 elseif v == o then s = s + W[cn[k]] - 5 end
      end
    end
  end
  s = s + (mobility(b, p) - mobility(b, o)) * 6
  if empty < 12 then s = s + (mine - theirs) * (12 - empty) end
  return s
end

R.sliceEnd = 0
local nodes, deadline, aborted = 0, 0, false

local function negamax(b, depth, alpha, beta, p, passed)
  nodes = nodes + 1
  if nodes % 8 == 0 then
    if sys.time() > deadline then aborted = true end
    if coroutine.isyieldable() and os.clock() > R.sliceEnd then coroutine.yield() end
  end
  if aborted then return 0 end
  if depth <= 0 then return evaluate(b, p) end
  local list, n = R.moves(b, p, {})
  if n == 0 then
    if passed then
      local x, y = R.count(b)
      local d = p == 1 and x - y or y - x
      return d > 0 and BIG + d or (d < 0 and -BIG + d or 0)
    end
    return -negamax(b, depth - 1, -beta, -alpha, 3 - p, true)
  end
  -- order: best squares first
  table.sort(list, function(x, y) return W[x] > W[y] end)
  local best = -BIG * 2
  for k = 1, n do
    local i = list[k]
    local f = R.play(b, i, p)
    local s = -negamax(b, depth - 1, -beta, -alpha, 3 - p, false)
    R.unplay(b, i, p, f)
    if s > best then best = s end
    if s > alpha then alpha = s end
    if alpha >= beta then break end
  end
  return best
end

-- Best move (index) for p, or nil when p has to pass. opts = {depth, time, noise}
function R.search(board, p, opts)
  local b = R.copy(board)
  local order, n = R.moves(b, p, {})
  if n == 0 then return nil end
  if n == 1 then return order[1] end
  deadline = sys.time() + (opts.time or 2)
  aborted = false
  nodes = 0
  table.sort(order, function(x, y) return W[x] > W[y] end)
  local bestMove = order[1]
  for depth = 1, opts.depth or 4 do
    local alpha, beta = -BIG * 3, BIG * 3
    local scores, bestS, bestI = {}, -BIG * 4, nil
    for _, i in ipairs(order) do
      local f = R.play(b, i, p)
      local s = -negamax(b, depth - 1, -beta, -alpha, 3 - p, false)
      R.unplay(b, i, p, f)
      if aborted then break end
      if opts.noise then s = s + math.random(-opts.noise, opts.noise) end
      scores[i] = s
      if s > bestS then bestS, bestI = s, i end
      if not opts.noise and s > alpha then alpha = s end
    end
    if aborted then break end
    bestMove = bestI or bestMove
    R.lastDepth = depth
    table.sort(order, function(x, y) return (scores[x] or -BIG * 4) > (scores[y] or -BIG * 4) end)
    if bestS >= BIG then break end
  end
  return bestMove
end

return R
