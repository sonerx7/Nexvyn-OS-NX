-- codec.lua: encoders, decoders and checksums in pure Lua 5.4 (64-bit integers, masked to 32 bits).
-- Decoders return result or nil, errorKey (a lang key the app translates).
local M = {}

local byte, char, sub, concat, fmt = string.byte, string.char, string.sub, table.concat, string.format
local M32 = 0xFFFFFFFF

-- ------------------------------------------------------------------ Base64
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local ENC, DEC = {}, {}
for i = 1, 64 do
  local c = sub(B64, i, i)
  ENC[i - 1] = c
  DEC[byte(c)] = i - 1
end
DEC[byte("-")] = 62   -- URL-safe alphabet is accepted by both decoders
DEC[byte("_")] = 63

function M.b64encode(s, urlsafe)
  local out, n = {}, #s
  for i = 1, n, 3 do
    local a, b, c = byte(s, i, i + 2)
    local v = (a << 16) | ((b or 0) << 8) | (c or 0)
    out[#out + 1] = ENC[(v >> 18) & 63] .. ENC[(v >> 12) & 63] ..
      (b and ENC[(v >> 6) & 63] or "=") .. (c and ENC[v & 63] or "=")
  end
  local r = concat(out)
  if urlsafe then r = r:gsub("+", "-"):gsub("/", "_"):gsub("=", "") end
  return r
end

function M.b64decode(s)
  s = s:gsub("%s", "")
  if s == "" then return "" end
  local body, pad = s:match("^([^=]*)(=*)$")
  if not body then return nil, "err_b64_pad" end
  if #pad > 2 then return nil, "err_b64_pad" end
  if #pad > 0 and (#body + #pad) % 4 ~= 0 then return nil, "err_b64_pad" end
  if #body % 4 == 1 then return nil, "err_b64_len" end
  local out, acc, bits = {}, 0, 0
  for i = 1, #body do
    local v = DEC[byte(body, i)]
    if not v then return nil, "err_b64_char" end
    acc = ((acc << 6) | v) & 0xFFFFFF
    bits = bits + 6
    if bits >= 8 then
      bits = bits - 8
      out[#out + 1] = char((acc >> bits) & 255)
    end
  end
  return concat(out)
end

-- ------------------------------------------------------------------ Hex
function M.hexencode(s, upper)
  local f = upper and "%02X" or "%02x"
  return (s:gsub(".", function(c) return fmt(f, byte(c)) end))
end

function M.hexdecode(s)
  s = s:gsub("0[xX]", ""):gsub("[%s:,%-]", "")
  if s:find("[^0-9A-Fa-f]") then return nil, "err_hex_char" end
  if #s % 2 == 1 then return nil, "err_hex_len" end
  return (s:gsub("..", function(h) return char(tonumber(h, 16)) end))
end

-- ------------------------------------------------------------------ URL percent-encoding (RFC 3986)
function M.urlencode(s)
  return (s:gsub("[^A-Za-z0-9%-%._~]", function(c) return fmt("%%%02X", byte(c)) end))
end

function M.urldecode(s)
  if s:find("%%[0-9A-Fa-f]?[^0-9A-Fa-f]") or s:find("%%[0-9A-Fa-f]?$") then return nil, "err_url" end
  s = s:gsub("+", " ")
  return (s:gsub("%%([0-9A-Fa-f][0-9A-Fa-f])", function(h) return char(tonumber(h, 16)) end))
end

-- ------------------------------------------------------------------ checksums
local CRC = {}
for i = 0, 255 do
  local c = i
  for _ = 1, 8 do
    if c & 1 == 1 then c = 0xEDB88320 ~ (c >> 1) else c = c >> 1 end
  end
  CRC[i] = c
end

function M.crc32(s)
  local c = M32
  for i = 1, #s do c = CRC[(c ~ byte(s, i)) & 255] ~ (c >> 8) end
  return c ~ M32
end

function M.adler32(s)
  local a, b = 1, 0
  local i, n = 1, #s
  while i <= n do                     -- blocks of 3800 bytes keep the sums small before the modulo
    local e = math.min(n, i + 3799)
    for j = i, e do a = a + byte(s, j); b = b + a end
    a, b = a % 65521, b % 65521
    i = e + 1
  end
  return (b << 16) | a
end

function M.fnv1a(s)
  local h = 2166136261
  for i = 1, #s do h = ((h ~ byte(s, i)) * 16777619) & M32 end
  return h
end

local function rol(x, n) return ((x << n) | (x >> (32 - n))) & M32 end
local function ror(x, n) return ((x >> n) | (x << (32 - n))) & M32 end

-- MD5 (RFC 1321)
local MD5_K, MD5_S = {}, {7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
  5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
  4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
  6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21}
for i = 0, 63 do MD5_K[i] = math.floor(math.abs(math.sin(i + 1)) * 2 ^ 32) & M32 end

function M.md5(s)
  local n = #s
  local msg = s .. "\128" .. string.rep("\0", (55 - n) % 64) .. string.pack("<I8", (n * 8) & 0xFFFFFFFFFFFFFFFF)
  local a0, b0, c0, d0 = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476
  local X = {}
  for off = 1, #msg, 64 do
    for j = 0, 15 do X[j] = string.unpack("<I4", msg, off + j * 4) end
    local A, B, C, D = a0, b0, c0, d0
    for i = 0, 63 do
      local F, g
      if i < 16 then F = (B & C) | (~B & D); g = i
      elseif i < 32 then F = (D & B) | (~D & C); g = (5 * i + 1) % 16
      elseif i < 48 then F = B ~ C ~ D; g = (3 * i + 5) % 16
      else F = C ~ (B | (~D & M32)); g = (7 * i) % 16 end
      F = (F + A + MD5_K[i] + X[g]) & M32
      A, D, C = D, C, B
      B = (B + rol(F, MD5_S[i + 1])) & M32
    end
    a0, b0, c0, d0 = (a0 + A) & M32, (b0 + B) & M32, (c0 + C) & M32, (d0 + D) & M32
  end
  return M.hexencode(string.pack("<I4I4I4I4", a0, b0, c0, d0))
end

local function padBE(s)
  local n = #s
  return s .. "\128" .. string.rep("\0", (55 - n) % 64) .. string.pack(">I8", (n * 8) & 0xFFFFFFFFFFFFFFFF)
end

-- SHA-1 (FIPS 180-4)
function M.sha1(s)
  local msg = padBE(s)
  local h0, h1, h2, h3, h4 = 0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0
  local W = {}
  for off = 1, #msg, 64 do
    for j = 0, 15 do W[j] = string.unpack(">I4", msg, off + j * 4) end
    for j = 16, 79 do W[j] = rol(W[j - 3] ~ W[j - 8] ~ W[j - 14] ~ W[j - 16], 1) end
    local a, b, c, d, e = h0, h1, h2, h3, h4
    for j = 0, 79 do
      local f, k
      if j < 20 then f = (b & c) | ((~b & M32) & d); k = 0x5A827999
      elseif j < 40 then f = b ~ c ~ d; k = 0x6ED9EBA1
      elseif j < 60 then f = (b & c) | (b & d) | (c & d); k = 0x8F1BBCDC
      else f = b ~ c ~ d; k = 0xCA62C1D6 end
      local t = (rol(a, 5) + f + e + k + W[j]) & M32
      e, d, c, b, a = d, c, rol(b, 30), a, t
    end
    h0, h1, h2, h3, h4 = (h0 + a) & M32, (h1 + b) & M32, (h2 + c) & M32, (h3 + d) & M32, (h4 + e) & M32
  end
  return M.hexencode(string.pack(">I4I4I4I4I4", h0, h1, h2, h3, h4))
end

-- SHA-256 (FIPS 180-4)
local K256 = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2}

function M.sha256(s)
  local msg = padBE(s)
  local H = {0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19}
  local W = {}
  for off = 1, #msg, 64 do
    for j = 1, 16 do W[j] = string.unpack(">I4", msg, off + (j - 1) * 4) end
    for j = 17, 64 do
      local w15, w2 = W[j - 15], W[j - 2]
      local s0 = ror(w15, 7) ~ ror(w15, 18) ~ (w15 >> 3)
      local s1 = ror(w2, 17) ~ ror(w2, 19) ~ (w2 >> 10)
      W[j] = (W[j - 16] + s0 + W[j - 7] + s1) & M32
    end
    local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
    for j = 1, 64 do
      local S1 = ror(e, 6) ~ ror(e, 11) ~ ror(e, 25)
      local ch = (e & f) ~ ((~e & M32) & g)
      local t1 = (h + S1 + ch + K256[j] + W[j]) & M32
      local S0 = ror(a, 2) ~ ror(a, 13) ~ ror(a, 22)
      local maj = (a & b) ~ (a & c) ~ (b & c)
      local t2 = (S0 + maj) & M32
      h, g, f, e, d, c, b, a = g, f, e, (d + t1) & M32, c, b, a, (t1 + t2) & M32
    end
    H[1], H[2], H[3], H[4] = (H[1] + a) & M32, (H[2] + b) & M32, (H[3] + c) & M32, (H[4] + d) & M32
    H[5], H[6], H[7], H[8] = (H[5] + e) & M32, (H[6] + f) & M32, (H[7] + g) & M32, (H[8] + h) & M32
  end
  return M.hexencode(string.pack(">I4I4I4I4I4I4I4I4", H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]))
end

-- ------------------------------------------------------------------ helpers
-- character count and whether the text is valid UTF-8 (invalid text: lead bytes are counted)
function M.charCount(s)
  local n = utf8.len(s)
  if n then return n, true end
  local _, lead = s:gsub("[^\128-\191]", "")
  return lead, false
end

return M
