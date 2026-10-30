-- png.lua: a small PNG encoder in pure Lua (8-bit RGB or RGBA, no filtering).
-- The image data goes into "stored" (uncompressed) deflate blocks inside a zlib stream, so no compressor is needed:
-- the file is valid and opens everywhere, just larger than a compressed one. CRC-32 and Adler-32 are computed here.
--
--   local enc = png.new(w, h, alpha)   -- streaming: feed rows one by one (spread over frames if you like)
--   enc:row(bytes)                     -- one row: w*3 (or w*4) bytes, top row first
--   local data = enc:finish()          -- the whole .png file as a string (write it with fs.write)
--   png.encode(w, h, rows, alpha)      -- one-shot helper for a table of row strings
local P = {}

local byte, char, concat = string.byte, string.char, table.concat

local CRC = {}
for n = 0, 255 do
  local c = n
  for _ = 1, 8 do
    if c & 1 == 1 then c = 0xEDB88320 ~ (c >> 1) else c = c >> 1 end
  end
  CRC[n] = c
end

-- running CRC-32 (pass and get back the inverted register, start with 0xFFFFFFFF)
local function crcUpdate(crc, s)
  local T = CRC
  local n = #s
  local i = 1
  while i + 7 <= n do
    local a, b, c, d, e, f, g, h = byte(s, i, i + 7)
    crc = T[(crc ~ a) & 0xFF] ~ (crc >> 8)
    crc = T[(crc ~ b) & 0xFF] ~ (crc >> 8)
    crc = T[(crc ~ c) & 0xFF] ~ (crc >> 8)
    crc = T[(crc ~ d) & 0xFF] ~ (crc >> 8)
    crc = T[(crc ~ e) & 0xFF] ~ (crc >> 8)
    crc = T[(crc ~ f) & 0xFF] ~ (crc >> 8)
    crc = T[(crc ~ g) & 0xFF] ~ (crc >> 8)
    crc = T[(crc ~ h) & 0xFF] ~ (crc >> 8)
    i = i + 8
  end
  for k = i, n do crc = T[(crc ~ byte(s, k)) & 0xFF] ~ (crc >> 8) end
  return crc
end

-- running Adler-32 as two halves
local function adlerUpdate(a, b, s)
  local n = #s
  local i = 1
  while i <= n do
    local j = math.min(n, i + 3999)       -- reduce modulo well before the sums could get large
    for k = i, j - 7, 8 do
      local p, q, r, t, u, v, x, y = byte(s, k, k + 7)
      a = a + p; b = b + a; a = a + q; b = b + a; a = a + r; b = b + a; a = a + t; b = b + a
      a = a + u; b = b + a; a = a + v; b = b + a; a = a + x; b = b + a; a = a + y; b = b + a
    end
    local done = i + ((j - i + 1) // 8) * 8
    for k = done, j do a = a + byte(s, k); b = b + a end
    a, b = a % 65521, b % 65521
    i = j + 1
  end
  return a, b
end

local function be32(v)
  return char((v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF)
end

local function chunk(kind, data)
  local crc = crcUpdate(0xFFFFFFFF, kind)
  crc = crcUpdate(crc, data) ~ 0xFFFFFFFF
  return be32(#data) .. kind .. data .. be32(crc)
end

local MAXBLOCK = 65535

local Enc = {}
Enc.__index = Enc

function P.new(w, h, alpha)
  local e = setmetatable({w = w, h = h, bpp = alpha and 4 or 3, rows = 0, out = {"\120\1"}, pend = {}, plen = 0,
    a = 1, b = 0}, Enc)
  return e
end

-- write one stored block of exactly the pending bytes
function Enc:flush(final)
  local data = concat(self.pend)
  local len = #data
  self.out[#self.out + 1] = char(final and 1 or 0, len & 0xFF, (len >> 8) & 0xFF, (~len) & 0xFF, ((~len) >> 8) & 0xFF)
  self.out[#self.out + 1] = data
  self.a, self.b = adlerUpdate(self.a, self.b, data)
  self.pend, self.plen = {}, 0
end

function Enc:feed(s)
  while #s > 0 do
    local room = MAXBLOCK - self.plen
    if #s <= room then
      self.pend[#self.pend + 1] = s
      self.plen = self.plen + #s
      s = ""
    else
      self.pend[#self.pend + 1] = s:sub(1, room)
      self.plen = MAXBLOCK
      s = s:sub(room + 1)
    end
    if self.plen >= MAXBLOCK then self:flush(false) end
  end
end

function Enc:row(bytes)
  local need = self.w * self.bpp
  if #bytes < need then bytes = bytes .. string.rep("\0", need - #bytes)
  elseif #bytes > need then bytes = bytes:sub(1, need) end
  self:feed("\0" .. bytes)                 -- filter type 0 (none)
  self.rows = self.rows + 1
end

function Enc:finish()
  local blank = string.rep("\0", self.w * self.bpp)
  while self.rows < self.h do self:row(blank) end
  self:flush(true)
  self.out[#self.out + 1] = be32((self.b << 16) | self.a)
  local z = concat(self.out)
  local ihdr = be32(self.w) .. be32(self.h) .. char(8, self.bpp == 4 and 6 or 2, 0, 0, 0)
  return "\137PNG\r\n\26\n" .. chunk("IHDR", ihdr) .. chunk("IDAT", z) .. chunk("IEND", "")
end

function P.encode(w, h, rows, alpha)
  local e = P.new(w, h, alpha)
  for y = 1, h do e:row(rows[y] or "") end
  return e:finish()
end

return P
