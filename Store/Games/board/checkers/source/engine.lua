-- engine.lua: English draughts (checkers) rules and AI.
-- Board [1..64], index = row * 8 + col + 1 (row 0 at the top). Values: 0 empty, 1 man of player 1 (bottom, moves up),
-- 2 man of player 2 (top, moves down), 3 king of player 1, 4 king of player 2. Captures are forced, multi-jumps continue
-- with the same piece, a man reaching the far row is crowned and the move ends.
-- A move = {from, path = {squares landed on}, caps = {captured squares}, crown = bool}.
local E = {}

local BIG = 1000000

function E.owner(v) if v == 0 then return 0 end return (v - 1) % 2 + 1 end
function E.isKing(v) return v >= 3 end

function E.new()
  local b = {}
  for i = 1, 64 do
    local r, c = (i - 1) // 8, (i - 1) % 8
    b[i] = 0
    if (r + c) % 2 == 1 then
      if r <= 2 then b[i] = 2 elseif r >= 5 then b[i] = 1 end
    end
  end
  return b
end

function E.copy(b)
  local n = {}
  for i = 1, 64 do n[i] = b[i] end
  return n
end

local function dirsFor(v)
  if v >= 3 then return {{-1, -1}, {-1, 1}, {1, -1}, {1, 1}} end
  if v == 1 then return {{-1, -1}, {-1, 1}} end
  return {{1, -1}, {1, 1}}
end
local DIRS = {dirsFor(1), dirsFor(2), dirsFor(3), dirsFor(4)}

local function crownRow(v) return (v == 1) and 0 or ((v == 2) and 7 or -1) end

-- depth-first search of jump sequences from square i with piece v
local function jumps(b, from, i, v, path, caps, capSet, out)
  local r, c = (i - 1) // 8, (i - 1) % 8
  local me = E.owner(v)
  local found = false
  for _, d in ipairs(DIRS[v]) do
    local mr, mc, lr, lc = r + d[1], c + d[2], r + 2 * d[1], c + 2 * d[2]
    if lr >= 0 and lr < 8 and lc >= 0 and lc < 8 then
      local m, l = mr * 8 + mc + 1, lr * 8 + lc + 1
      local mv = b[m]
      if mv ~= 0 and E.owner(mv) ~= me and not capSet[m] and b[l] == 0 then
        found = true
        path[#path + 1] = l
        caps[#caps + 1] = m
        capSet[m] = true
        if lr == crownRow(v) then
          local pp, cc = {}, {}
          for k = 1, #path do pp[k] = path[k] end
          for k = 1, #caps do cc[k] = caps[k] end
          out[#out + 1] = {from = from, path = pp, caps = cc, crown = true}
        else
          jumps(b, from, l, v, path, caps, capSet, out)
        end
        path[#path] = nil
        caps[#caps] = nil
        capSet[m] = nil
      end
    end
  end
  if not found and #path > 0 then
    local pp, cc = {}, {}
    for k = 1, #path do pp[k] = path[k] end
    for k = 1, #caps do cc[k] = caps[k] end
    out[#out + 1] = {from = from, path = pp, caps = cc, crown = false}
  end
end

-- all legal moves for player p (captures only when any exist)
function E.moves(b, p)
  local caps = {}
  for i = 1, 64 do
    local v = b[i]
    if v ~= 0 and E.owner(v) == p then
      b[i] = 0
      jumps(b, i, i, v, {}, {}, {}, caps)
      b[i] = v
    end
  end
  if #caps > 0 then return caps, true end
  local out = {}
  for i = 1, 64 do
    local v = b[i]
    if v ~= 0 and E.owner(v) == p then
      local r, c = (i - 1) // 8, (i - 1) % 8
      for _, d in ipairs(DIRS[v]) do
        local nr, nc = r + d[1], c + d[2]
        if nr >= 0 and nr < 8 and nc >= 0 and nc < 8 then
          local j = nr * 8 + nc + 1
          if b[j] == 0 then out[#out + 1] = {from = i, path = {j}, caps = {}, crown = nr == crownRow(v)} end
        end
      end
    end
  end
  return out, false
end

-- applies m; returns the undo record
function E.apply(b, m)
  local v = b[m.from]
  local rec = {v = v, capv = {}}
  b[m.from] = 0
  for k, s in ipairs(m.caps) do rec.capv[k] = b[s]; b[s] = 0 end
  local to = m.path[#m.path]
  b[to] = m.crown and (v <= 2 and v + 2 or v) or v
  return rec
end

function E.undo(b, m, rec)
  b[m.path[#m.path]] = 0
  for k, s in ipairs(m.caps) do b[s] = rec.capv[k] end
  b[m.from] = rec.v
end

function E.count(b)
  local n = {0, 0}
  for i = 1, 64 do
    local v = b[i]
    if v ~= 0 then local o = E.owner(v); n[o] = n[o] + 1 end
  end
  return n[1], n[2]
end

local CENTER = {}
for i = 1, 64 do
  local r, c = (i - 1) // 8, (i - 1) % 8
  CENTER[i] = (r >= 2 and r <= 5 and c >= 2 and c <= 5) and 4 or 0
end

local function evaluate(b, p)
  local s = 0
  local n1, n2 = 0, 0
  for i = 1, 64 do
    local v = b[i]
    if v ~= 0 then
      local r = (i - 1) // 8
      local val
      if v == 1 then val = 100 + (7 - r) * 3 + (r == 7 and 6 or 0); n1 = n1 + 1
      elseif v == 2 then val = 100 + r * 3 + (r == 0 and 6 or 0); n2 = n2 + 1
      else val = 165; if v == 3 then n1 = n1 + 1 else n2 = n2 + 1 end end
      val = val + CENTER[i]
      if E.owner(v) == p then s = s + val else s = s - val end
    end
  end
  -- when ahead, trading pieces is good
  local mine, theirs = p == 1 and n1 or n2, p == 1 and n2 or n1
  if mine > theirs then s = s + (24 - mine - theirs) * 2 elseif theirs > mine then s = s - (24 - mine - theirs) * 2 end
  return s
end

E.sliceEnd = 0
local nodes, deadline, aborted = 0, 0, false

local function negamax(b, depth, alpha, beta, p, ply)
  nodes = nodes + 1
  if nodes % 8 == 0 then
    if sys.time() > deadline then aborted = true end
    if coroutine.isyieldable() and os.clock() > E.sliceEnd then coroutine.yield() end
  end
  if aborted then return 0 end
  local list, isCap = E.moves(b, p)
  if #list == 0 then return -BIG + ply end
  if depth <= 0 and not isCap then return evaluate(b, p) end
  if depth <= -6 then return evaluate(b, p) end   -- quiescence limit for long capture chains
  local best = -BIG * 2
  for k = 1, #list do
    local m = list[k]
    local rec = E.apply(b, m)
    local s = -negamax(b, depth - 1, -beta, -alpha, 3 - p, ply + 1)
    E.undo(b, m, rec)
    if s > best then best = s end
    if s > alpha then alpha = s end
    if alpha >= beta then break end
  end
  return best
end

-- best move for p (index into E.moves order is not kept; returns the move table) or nil
function E.search(board, p, opts)
  local b = E.copy(board)
  local list = E.moves(b, p)
  if #list == 0 then return nil end
  if #list == 1 then return list[1] end
  deadline = sys.time() + (opts.time or 2)
  aborted = false
  nodes = 0
  local bestMove = list[math.random(#list)]
  for depth = 1, opts.depth or 4 do
    local alpha, beta = -BIG * 3, BIG * 3
    local scores, bestS, bestM = {}, -BIG * 4, nil
    for _, m in ipairs(list) do
      local rec = E.apply(b, m)
      local s = -negamax(b, depth - 1, -beta, -alpha, 3 - p, 1)
      E.undo(b, m, rec)
      if aborted then break end
      if opts.noise then s = s + math.random(-opts.noise, opts.noise) end
      scores[m] = s
      if s > bestS then bestS, bestM = s, m end
      if not opts.noise and s > alpha then alpha = s end
    end
    if aborted then break end
    bestMove = bestM or bestMove
    E.lastDepth = depth
    table.sort(list, function(x, y) return (scores[x] or -BIG * 4) > (scores[y] or -BIG * 4) end)
    if bestS >= BIG - 100 then break end
  end
  return bestMove
end

-- same move? (from and full path)
function E.same(a, b)
  if a.from ~= b.from or #a.path ~= #b.path then return false end
  for k = 1, #a.path do if a.path[k] ~= b.path[k] then return false end end
  return true
end

return E
