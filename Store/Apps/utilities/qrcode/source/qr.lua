-- QR Code encoder (ISO/IEC 18004): byte mode, versions 1-10, error correction L/M/Q/H.
-- Reed-Solomon over GF(256) with the 0x11D polynomial, block interleaving, all 8 masks scored with the four
-- penalty rules, BCH-coded format information and version information for version 7 and up.
local Q = {}

-- {EC codewords per block, blocks in group 1, data codewords per block in group 1, blocks in group 2, data per block}
local BLOCKS = {
  {L = {7, 1, 19, 0, 0}, M = {10, 1, 16, 0, 0}, Q = {13, 1, 13, 0, 0}, H = {17, 1, 9, 0, 0}},
  {L = {10, 1, 34, 0, 0}, M = {16, 1, 28, 0, 0}, Q = {22, 1, 22, 0, 0}, H = {28, 1, 16, 0, 0}},
  {L = {15, 1, 55, 0, 0}, M = {26, 1, 44, 0, 0}, Q = {18, 2, 17, 0, 0}, H = {22, 2, 13, 0, 0}},
  {L = {20, 1, 80, 0, 0}, M = {18, 2, 32, 0, 0}, Q = {26, 2, 24, 0, 0}, H = {16, 4, 9, 0, 0}},
  {L = {26, 1, 108, 0, 0}, M = {24, 2, 43, 0, 0}, Q = {18, 2, 15, 2, 16}, H = {22, 2, 11, 2, 12}},
  {L = {18, 2, 68, 0, 0}, M = {16, 4, 27, 0, 0}, Q = {24, 4, 19, 0, 0}, H = {28, 4, 15, 0, 0}},
  {L = {20, 2, 78, 0, 0}, M = {18, 4, 31, 0, 0}, Q = {18, 2, 14, 4, 15}, H = {26, 4, 13, 1, 14}},
  {L = {24, 2, 97, 0, 0}, M = {22, 2, 38, 2, 39}, Q = {22, 4, 18, 2, 19}, H = {26, 4, 14, 2, 15}},
  {L = {30, 2, 116, 0, 0}, M = {22, 3, 36, 2, 37}, Q = {20, 4, 16, 4, 17}, H = {24, 4, 12, 4, 13}},
  {L = {18, 2, 68, 2, 69}, M = {26, 4, 43, 1, 44}, Q = {24, 6, 19, 2, 20}, H = {28, 6, 15, 2, 16}},
}
local ALIGN = {{}, {6, 18}, {6, 22}, {6, 26}, {6, 30}, {6, 34}, {6, 22, 38}, {6, 24, 42}, {6, 26, 46}, {6, 28, 50}}
local ECL_BITS = {L = 1, M = 0, Q = 3, H = 2}
Q.MAX_VERSION = 10

-- ------------------------------------------------------------------ GF(256)
local EXP, LOG = {}, {}
do
  local x = 1
  for i = 0, 254 do
    EXP[i] = x
    LOG[x] = i
    x = x << 1
    if x & 0x100 ~= 0 then x = x ~ 0x11D end
  end
  for i = 255, 511 do EXP[i] = EXP[i - 255] end
end
local function gmul(a, b)
  if a == 0 or b == 0 then return 0 end
  return EXP[LOG[a] + LOG[b]]
end

local genCache = {}
local function rsDivisor(degree)
  if genCache[degree] then return genCache[degree] end
  local res = {}
  for i = 1, degree do res[i] = 0 end
  res[degree] = 1
  local root = 1
  for _ = 1, degree do
    for j = 1, degree do
      res[j] = gmul(res[j], root)
      if j < degree then res[j] = res[j] ~ res[j + 1] end
    end
    root = gmul(root, 2)
  end
  genCache[degree] = res
  return res
end

local function rsRemainder(data, divisor)
  local n = #divisor
  local res = {}
  for i = 1, n do res[i] = 0 end
  for _, b in ipairs(data) do
    local factor = b ~ res[1]
    for i = 1, n - 1 do res[i] = res[i + 1] end
    res[n] = 0
    for i = 1, n do res[i] = res[i] ~ gmul(divisor[i], factor) end
  end
  return res
end

-- ------------------------------------------------------------------ capacity
local function dataCodewords(v, ecl)
  local b = BLOCKS[v][ecl]
  return b[2] * b[3] + b[4] * b[5]
end
local function countBits(v) return v <= 9 and 8 or 16 end

-- largest byte count that fits each version
function Q.capacity(v, ecl)
  return (dataCodewords(v, ecl) * 8 - 4 - countBits(v)) // 8
end

function Q.fitVersion(n, ecl)
  for v = 1, Q.MAX_VERSION do
    if 4 + countBits(v) + 8 * n <= dataCodewords(v, ecl) * 8 then return v end
  end
  return nil
end

-- ------------------------------------------------------------------ codewords
local function buildCodewords(data, v, ecl)
  local bits = {}
  local function put(val, len)
    for i = len - 1, 0, -1 do bits[#bits + 1] = (val >> i) & 1 end
  end
  put(4, 4)                         -- byte mode 0100
  put(#data, countBits(v))
  for i = 1, #data do put(data:byte(i), 8) end
  local cap = dataCodewords(v, ecl) * 8
  put(0, math.min(4, cap - #bits))  -- terminator
  while #bits % 8 ~= 0 do bits[#bits + 1] = 0 end
  local pad = 0xEC
  while #bits < cap do
    put(pad, 8)
    pad = pad == 0xEC and 0x11 or 0xEC
  end
  local bytes = {}
  for i = 1, #bits, 8 do
    local b = 0
    for k = 0, 7 do b = (b << 1) | bits[i + k] end
    bytes[#bytes + 1] = b
  end
  -- split into blocks, add error correction, interleave
  local spec = BLOCKS[v][ecl]
  local ecLen = spec[1]
  local divisor = rsDivisor(ecLen)
  local blocks, ecs = {}, {}
  local pos = 1
  for g = 0, 1 do
    local count, len = spec[2 + g * 2], spec[3 + g * 2]
    for _ = 1, count do
      local blk = {}
      for k = 0, len - 1 do blk[#blk + 1] = bytes[pos + k] end
      pos = pos + len
      blocks[#blocks + 1] = blk
      ecs[#ecs + 1] = rsRemainder(blk, divisor)
    end
  end
  local out = {}
  local maxLen = 0
  for _, b in ipairs(blocks) do if #b > maxLen then maxLen = #b end end
  for i = 1, maxLen do
    for _, b in ipairs(blocks) do if b[i] then out[#out + 1] = b[i] end end
  end
  for i = 1, ecLen do
    for _, e in ipairs(ecs) do out[#out + 1] = e[i] end
  end
  return out
end

-- ------------------------------------------------------------------ matrix
local function newGrid(size, val)
  local g = {}
  for y = 0, size - 1 do
    local row = {}
    for x = 0, size - 1 do row[x] = val end
    g[y] = row
  end
  return g
end

local function formatBits(ecl, mask)
  local data = (ECL_BITS[ecl] << 3) | mask
  local rem = data
  for _ = 1, 10 do rem = (rem << 1) ~ ((rem >> 9) * 0x537) end
  return ((data << 10) | rem) ~ 0x5412
end
Q.formatBits = formatBits

local function versionBits(v)
  local rem = v
  for _ = 1, 12 do rem = (rem << 1) ~ ((rem >> 11) * 0x1F25) end
  return (v << 12) | rem
end
Q.versionBits = versionBits

local function build(v, ecl, codewords)
  local size = 17 + 4 * v
  local M = newGrid(size, false)
  local F = newGrid(size, false)
  local function setF(x, y, dark)
    M[y][x] = dark
    F[y][x] = true
  end
  -- timing patterns
  for i = 0, size - 1 do
    setF(6, i, i % 2 == 0)
    setF(i, 6, i % 2 == 0)
  end
  -- finder patterns with separators
  local function finder(cx, cy)
    for dy = -4, 4 do
      for dx = -4, 4 do
        local xx, yy = cx + dx, cy + dy
        if xx >= 0 and xx < size and yy >= 0 and yy < size then
          local d = math.max(math.abs(dx), math.abs(dy))
          setF(xx, yy, d ~= 2 and d ~= 4)
        end
      end
    end
  end
  finder(3, 3)
  finder(size - 4, 3)
  finder(3, size - 4)
  -- alignment patterns
  local pos = ALIGN[v]
  local n = #pos
  for i = 1, n do
    for j = 1, n do
      if not ((i == 1 and j == 1) or (i == 1 and j == n) or (i == n and j == 1)) then
        for dy = -2, 2 do
          for dx = -2, 2 do
            setF(pos[i] + dx, pos[j] + dy, math.max(math.abs(dx), math.abs(dy)) ~= 1)
          end
        end
      end
    end
  end
  -- format area (reserved now, written per mask) and version information
  local function drawFormat(mask)
    local bits = formatBits(ecl, mask)
    local function bit(i) return (bits >> i) & 1 == 1 end
    for i = 0, 5 do setF(8, i, bit(i)) end
    setF(8, 7, bit(6))
    setF(8, 8, bit(7))
    setF(7, 8, bit(8))
    for i = 9, 14 do setF(14 - i, 8, bit(i)) end
    for i = 0, 7 do setF(size - 1 - i, 8, bit(i)) end
    for i = 8, 14 do setF(8, size - 15 + i, bit(i)) end
    setF(8, size - 8, true)        -- dark module
  end
  drawFormat(0)
  if v >= 7 then
    local bits = versionBits(v)
    for i = 0, 17 do
      local b = (bits >> i) & 1 == 1
      local a, c = size - 11 + i % 3, i // 3
      setF(a, c, b)
      setF(c, a, b)
    end
  end
  -- data placement: two-column zigzag from the bottom right, skipping the vertical timing column
  local total = #codewords * 8
  local i = 0
  local right = size - 1
  while right >= 1 do
    if right == 6 then right = 5 end
    for vert = 0, size - 1 do
      for j = 0, 1 do
        local x = right - j
        local upward = ((right + 1) & 2) == 0
        local y = upward and (size - 1 - vert) or vert
        if not F[y][x] and i < total then
          local byte = codewords[(i >> 3) + 1]
          M[y][x] = ((byte >> (7 - (i & 7))) & 1) == 1
          i = i + 1
        end
      end
    end
    right = right - 2
  end
  return M, F, size, drawFormat
end

local MASKS = {
  [0] = function(x, y) return (x + y) % 2 == 0 end,
  function(x, y) return y % 2 == 0 end,
  function(x, y) return x % 3 == 0 end,
  function(x, y) return (x + y) % 3 == 0 end,
  function(x, y) return (x // 3 + y // 2) % 2 == 0 end,
  function(x, y) return x * y % 2 + x * y % 3 == 0 end,
  function(x, y) return (x * y % 2 + x * y % 3) % 2 == 0 end,
  function(x, y) return ((x + y) % 2 + x * y % 3) % 2 == 0 end,
}

local function applyMask(M, F, size, m)
  local f = MASKS[m]
  for y = 0, size - 1 do
    local row, frow = M[y], F[y]
    for x = 0, size - 1 do
      if not frow[x] and f(x, y) then row[x] = not row[x] end
    end
  end
end

local function penalty(M, size)
  local score = 0
  -- rule 1: runs of five or more in rows and columns
  for y = 0, size - 1 do
    local run, prev = 0, nil
    for x = 0, size - 1 do
      local c = M[y][x]
      if c == prev then run = run + 1 else
        if run >= 5 then score = score + 3 + run - 5 end
        run, prev = 1, c
      end
    end
    if run >= 5 then score = score + 3 + run - 5 end
  end
  for x = 0, size - 1 do
    local run, prev = 0, nil
    for y = 0, size - 1 do
      local c = M[y][x]
      if c == prev then run = run + 1 else
        if run >= 5 then score = score + 3 + run - 5 end
        run, prev = 1, c
      end
    end
    if run >= 5 then score = score + 3 + run - 5 end
  end
  -- rule 2: 2x2 blocks of one color
  for y = 0, size - 2 do
    for x = 0, size - 2 do
      local c = M[y][x]
      if M[y][x + 1] == c and M[y + 1][x] == c and M[y + 1][x + 1] == c then score = score + 3 end
    end
  end
  -- rule 3: finder-like 1011101 with four light modules on one side (outside the symbol counts as light)
  local function lightH(y, a, b)
    for x = math.max(0, a), math.min(size, b) - 1 do if M[y][x] then return false end end
    return true
  end
  local function lightV(x, a, b)
    for y = math.max(0, a), math.min(size, b) - 1 do if M[y][x] then return false end end
    return true
  end
  for y = 0, size - 1 do
    for x = 0, size - 7 do
      local r = M[y]
      if r[x] and not r[x + 1] and r[x + 2] and r[x + 3] and r[x + 4] and not r[x + 5] and r[x + 6]
         and (lightH(y, x - 4, x) or lightH(y, x + 7, x + 11)) then
        score = score + 40
      end
    end
  end
  for x = 0, size - 1 do
    for y = 0, size - 7 do
      if M[y][x] and not M[y + 1][x] and M[y + 2][x] and M[y + 3][x] and M[y + 4][x] and not M[y + 5][x] and M[y + 6][x]
         and (lightV(x, y - 4, y) or lightV(x, y + 7, y + 11)) then
        score = score + 40
      end
    end
  end
  -- rule 4: balance of dark modules
  local dark = 0
  for y = 0, size - 1 do for x = 0, size - 1 do if M[y][x] then dark = dark + 1 end end end
  local total = size * size
  score = score + (math.abs(dark * 2 - total) * 10 // total) * 10
  return score
end

-- data: byte string. Returns {size, version, ecl, mask, modules[y][x] (0-based, true = dark)} or nil, "too_long".
function Q.encode(data, ecl, forceVersion, forceMask)
  ecl = ecl or "M"
  local v = forceVersion or Q.fitVersion(#data, ecl)
  if not v or v > Q.MAX_VERSION or Q.capacity(v, ecl) < #data then return nil, "too_long" end
  local codewords = buildCodewords(data, v, ecl)
  local M, F, size, drawFormat = build(v, ecl, codewords)
  local best, bestScore = 0, math.huge
  if forceMask then
    best = forceMask
  else
    for m = 0, 7 do
      applyMask(M, F, size, m)
      drawFormat(m)
      local s = penalty(M, size)
      if s < bestScore then best, bestScore = m, s end
      applyMask(M, F, size, m)  -- XOR again to undo
    end
  end
  applyMask(M, F, size, best)
  drawFormat(best)
  return {size = size, version = v, ecl = ecl, mask = best, modules = M}
end

return Q
