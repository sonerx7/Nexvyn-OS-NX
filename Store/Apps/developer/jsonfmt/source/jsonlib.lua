-- jsonlib.lua: a strict JSON parser that keeps key order and reports line:column errors, and a serializer
-- (pretty with any indent, or minified, optional key sorting). Strings and numbers keep their exact source text.
--
-- Nodes: {k="o", keys={raw...}, vals={node...}}  {k="a", items={node...}}  {k="s", r=raw}  {k="n", r=raw}
--        TRUE / FALSE / NULL singletons ({k="t"}, {k="f"}, {k="z"}).
local M = {}

local byte, sub, find, match, concat, char = string.byte, string.sub, string.find, string.match, table.concat, string.char

M.TRUE, M.FALSE, M.NULL = {k = "t"}, {k = "f"}, {k = "z"}
M.MAX_DEPTH = 800

local B_QUOTE, B_BSLASH, B_LBRACE, B_RBRACE, B_LBRACK, B_RBRACK = 34, 92, 123, 125, 91, 93
local B_COMMA, B_COLON, B_MINUS = 44, 58, 45
local STR_STOP = '["\\\0-\31]'        -- end of a run of plain string characters
local ESC_OK = {[34] = true, [92] = true, [47] = true, [98] = true, [102] = true, [110] = true, [114] = true, [116] = true}

-- error codes (the app translates them): eof, char, colon, obj_sep, arr_sep, key, number, escape, control,
-- unterminated, trailing, depth, empty, trailing_comma, comment, single_quote, word
local function fail(code, pos, extra) error({code = code, pos = pos, extra = extra}, 0) end

function M.parse(s)
  local n = #s
  local pos = 1
  local st = {objects = 0, arrays = 0, strings = 0, numbers = 0, bools = 0, nulls = 0, keys = 0, depth = 0, dupes = 0}

  local function ws()
    pos = find(s, "[^ \t\n\r]", pos) or n + 1
  end

  local function badChar(p)
    local b = byte(s, p)
    if not b then fail("eof", p) end
    if b == 47 then fail("comment", p) end                 -- '/'
    if b == 39 then fail("single_quote", p) end            -- "'"
    if find(s, "^[A-Za-z_]", p) then
      local w = match(s, "^[A-Za-z0-9_]+", p)
      fail("word", p, w)
    end
    fail("char", p, match(s, "^[\0-\127\194-\244][\128-\191]*", p) or sub(s, p, p))
  end

  local function str()      -- pos is at the opening quote; returns the raw content
    local start = pos + 1
    local p = start
    while true do
      local q = find(s, STR_STOP, p)
      if not q then fail("unterminated", pos) end
      local b = byte(s, q)
      if b == B_QUOTE then
        pos = q + 1
        return sub(s, start, q - 1)
      elseif b == B_BSLASH then
        local e = byte(s, q + 1)
        if e == 117 then                                   -- \uXXXX
          if not find(s, "^[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]", q + 2) then fail("escape", q) end
          p = q + 6
        elseif e and ESC_OK[e] then
          p = q + 2
        elseif not e then fail("unterminated", pos)
        else fail("escape", q) end
      else
        fail("control", q)
      end
    end
  end

  local function num()
    local int = match(s, "^-?%d+", pos)
    if not int then fail("number", pos) end
    if find(int, "^-?0%d") then fail("number", pos) end
    local p = pos + #int
    if byte(s, p) == 46 then
      local frac = match(s, "^%.%d+", p)
      if not frac then fail("number", pos) end
      p = p + #frac
    end
    local b = byte(s, p)
    if b == 101 or b == 69 then
      local ex = match(s, "^[eE][-+]?%d+", p)
      if not ex then fail("number", pos) end
      p = p + #ex
    end
    local raw = sub(s, pos, p - 1)
    pos = p
    return raw
  end

  local value
  function value(depth)
    if depth > st.depth then st.depth = depth end
    if depth > M.MAX_DEPTH then fail("depth", pos) end
    ws()
    local b = byte(s, pos)
    if b == B_LBRACE then
      st.objects = st.objects + 1
      local node = {k = "o", keys = {}, vals = {}}
      local keys, vals, seen = node.keys, node.vals, {}
      pos = pos + 1
      ws()
      if byte(s, pos) == B_RBRACE then pos = pos + 1; return node end
      while true do
        ws()
        local c = byte(s, pos)
        if c ~= B_QUOTE then
          if c == B_RBRACE and #keys > 0 then fail("trailing_comma", pos) end
          if c == nil then fail("eof", pos) end
          if c == 39 then fail("single_quote", pos) end
          if c == 47 then fail("comment", pos) end
          fail("key", pos)
        end
        local k = str()
        st.strings = st.strings + 1
        st.keys = st.keys + 1
        if seen[k] then st.dupes = st.dupes + 1 else seen[k] = true end
        ws()
        if byte(s, pos) ~= B_COLON then
          if pos > n then fail("eof", pos) end
          fail("colon", pos)
        end
        pos = pos + 1
        local v = value(depth + 1)
        keys[#keys + 1] = k
        vals[#vals + 1] = v
        ws()
        c = byte(s, pos)
        if c == B_COMMA then pos = pos + 1
        elseif c == B_RBRACE then pos = pos + 1; return node
        elseif c == nil then fail("eof", pos)
        elseif c == 47 then fail("comment", pos)
        else fail("obj_sep", pos) end
      end
    elseif b == B_LBRACK then
      st.arrays = st.arrays + 1
      local node = {k = "a", items = {}}
      local items = node.items
      pos = pos + 1
      ws()
      if byte(s, pos) == B_RBRACK then pos = pos + 1; return node end
      while true do
        ws()
        if byte(s, pos) == B_RBRACK and #items > 0 then fail("trailing_comma", pos) end
        items[#items + 1] = value(depth + 1)
        ws()
        local c = byte(s, pos)
        if c == B_COMMA then pos = pos + 1
        elseif c == B_RBRACK then pos = pos + 1; return node
        elseif c == nil then fail("eof", pos)
        elseif c == 47 then fail("comment", pos)
        else fail("arr_sep", pos) end
      end
    elseif b == B_QUOTE then
      st.strings = st.strings + 1
      return {k = "s", r = str()}
    elseif b == B_MINUS or (b and b >= 48 and b <= 57) then
      st.numbers = st.numbers + 1
      return {k = "n", r = num()}
    elseif b == 116 and sub(s, pos, pos + 3) == "true" then
      pos = pos + 4; st.bools = st.bools + 1; return M.TRUE
    elseif b == 102 and sub(s, pos, pos + 4) == "false" then
      pos = pos + 5; st.bools = st.bools + 1; return M.FALSE
    elseif b == 110 and sub(s, pos, pos + 3) == "null" then
      pos = pos + 4; st.nulls = st.nulls + 1; return M.NULL
    end
    badChar(pos)
  end

  local ok, res = pcall(function()
    ws()
    if pos > n then fail("empty", 1) end
    local root = value(1)
    ws()
    if pos <= n then fail("trailing", pos) end
    return root
  end)
  if ok then return res, st end
  if type(res) ~= "table" then res = {code = "depth", pos = pos} end   -- e.g. a Lua stack overflow
  -- line and column (in characters) of the error
  local p = math.max(1, math.min(res.pos or 1, n + 1))
  local before = sub(s, 1, p - 1)
  local _, nl = before:gsub("\n", "")
  local ls = 1
  local lastNl = before:match(".*()\n")
  if lastNl then ls = lastNl + 1 end
  local seg = sub(s, ls, p - 1)
  res.line = nl + 1
  res.col = (utf8.len(seg) or #seg) + 1
  res.lineStart = ls
  return nil, res
end

-- ------------------------------------------------------------------ strings
local SIMPLE = {['"'] = '"', ["\\"] = "\\", ["/"] = "/", b = "\b", f = "\f", n = "\n", r = "\r", t = "\t"}

-- raw (escaped) JSON string content -> UTF-8 text
function M.unescape(raw)
  if not find(raw, "\\", 1, true) then return raw end
  local out, i, n = {}, 1, #raw
  while i <= n do
    local q = find(raw, "\\", i, true)
    if not q then out[#out + 1] = sub(raw, i); break end
    if q > i then out[#out + 1] = sub(raw, i, q - 1) end
    local e = sub(raw, q + 1, q + 1)
    if e == "u" then
      local cp = tonumber(sub(raw, q + 2, q + 5), 16) or 63
      local nxt = q + 6
      if cp >= 0xD800 and cp <= 0xDBFF and sub(raw, nxt, nxt + 1) == "\\u" then
        local lo = tonumber(sub(raw, nxt + 2, nxt + 5), 16) or 0
        if lo >= 0xDC00 and lo <= 0xDFFF then
          cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00)
          nxt = nxt + 6
        end
      end
      if cp >= 0xD800 and cp <= 0xDFFF then cp = 0xFFFD end
      out[#out + 1] = utf8.char(cp)
      i = nxt
    else
      out[#out + 1] = SIMPLE[e] or e
      i = q + 2
    end
  end
  return concat(out)
end

-- ------------------------------------------------------------------ serializer
-- indent: nil = minified, otherwise the indent unit ("  ", "    " or "\t")
function M.serialize(root, indent, sortKeys)
  local buf, nb = {}, 0
  local pads = {[0] = ""}
  local colon = indent and ": " or ":"
  local function pad(d)
    local p = pads[d]
    if not p then p = string.rep(indent, d); pads[d] = p end
    return p
  end
  local keyCache = {}
  local function sortedOrder(node)
    local keys = node.keys
    local order = {}
    for i = 1, #keys do order[i] = i end
    local dec = {}
    for i = 1, #keys do
      local k = keys[i]
      local d = keyCache[k]
      if not d then d = M.unescape(k); keyCache[k] = d end
      dec[i] = d
    end
    table.sort(order, function(a, b)
      if dec[a] == dec[b] then return a < b end
      return dec[a] < dec[b]
    end)
    return order
  end
  local function emit(node, d)
    local k = node.k
    if k == "s" then nb = nb + 1; buf[nb] = '"' .. node.r .. '"'
    elseif k == "n" then nb = nb + 1; buf[nb] = node.r
    elseif k == "t" then nb = nb + 1; buf[nb] = "true"
    elseif k == "f" then nb = nb + 1; buf[nb] = "false"
    elseif k == "z" then nb = nb + 1; buf[nb] = "null"
    elseif k == "a" then
      local items = node.items
      if #items == 0 then nb = nb + 1; buf[nb] = "[]"; return end
      nb = nb + 1; buf[nb] = "["
      for i = 1, #items do
        if indent then nb = nb + 1; buf[nb] = (i > 1 and ",\n" or "\n") .. pad(d + 1)
        elseif i > 1 then nb = nb + 1; buf[nb] = "," end
        emit(items[i], d + 1)
      end
      nb = nb + 1; buf[nb] = indent and ("\n" .. pad(d) .. "]") or "]"
    elseif k == "o" then
      local keys, vals = node.keys, node.vals
      if #keys == 0 then nb = nb + 1; buf[nb] = "{}"; return end
      local order = sortKeys and #keys > 1 and sortedOrder(node) or nil
      nb = nb + 1; buf[nb] = "{"
      for j = 1, #keys do
        local i = order and order[j] or j
        if indent then nb = nb + 1; buf[nb] = (j > 1 and ",\n" or "\n") .. pad(d + 1)
        elseif j > 1 then nb = nb + 1; buf[nb] = "," end
        nb = nb + 1; buf[nb] = '"' .. keys[i] .. '"' .. colon
        emit(vals[i], d + 1)
      end
      nb = nb + 1; buf[nb] = indent and ("\n" .. pad(d) .. "}") or "}"
    end
  end
  emit(root, 0)
  return concat(buf, "", 1, nb)
end

-- number of children of a container node (0 for scalars)
function M.count(node)
  if node.k == "o" then return #node.keys elseif node.k == "a" then return #node.items end
  return 0
end

return M
