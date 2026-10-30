-- turkish.lua: Turkish letter helpers (UTF-8). string.upper/lower are not Turkish-aware, so the case mapping is
-- explicit: i <-> İ and ı <-> I.
local T = {}

local UP = {["i"] = "İ", ["ı"] = "I", ["ç"] = "Ç", ["ğ"] = "Ğ", ["ö"] = "Ö", ["ş"] = "Ş", ["ü"] = "Ü",
            ["â"] = "A", ["î"] = "İ", ["û"] = "U", ["Â"] = "A", ["Î"] = "İ", ["Û"] = "U"}
local LOW = {["İ"] = "i", ["I"] = "ı", ["Ç"] = "ç", ["Ğ"] = "ğ", ["Ö"] = "ö", ["Ş"] = "ş", ["Ü"] = "ü"}

T.ALPHABET = {"A", "B", "C", "Ç", "D", "E", "F", "G", "Ğ", "H", "I", "İ", "J", "K", "L", "M", "N", "O", "Ö", "P",
              "R", "S", "Ş", "T", "U", "Ü", "V", "Y", "Z"}
T.SET = {}
for _, l in ipairs(T.ALPHABET) do T.SET[l] = true end

-- one letter to uppercase (Turkish rules)
function T.upper(ch)
  if UP[ch] then return UP[ch] end
  if #ch == 1 then return ch:upper() end
  return ch
end

function T.lower(ch)
  if LOW[ch] then return LOW[ch] end
  if #ch == 1 then return ch:lower() end
  return ch
end

-- array of the UTF-8 characters of s
function T.letters(s)
  local out = {}
  for _, cp in utf8.codes(s) do out[#out + 1] = utf8.char(cp) end
  return out
end

-- uppercase a whole string
function T.upperStr(s)
  local out = {}
  for _, cp in utf8.codes(s) do out[#out + 1] = T.upper(utf8.char(cp)) end
  return table.concat(out)
end

-- a typed character (from a "text" event or a keydown letter) as an uppercase alphabet letter, or nil
function T.fromInput(s)
  if type(s) ~= "string" or s == "" then return nil end
  local ok, len = pcall(utf8.len, s)
  if not ok or len ~= 1 then return nil end
  local u = T.upper(s)
  if T.SET[u] then return u end
  return nil
end

return T
