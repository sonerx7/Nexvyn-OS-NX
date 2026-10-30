-- Safe expression compiler for y = f(x): numbers, x, pi, e, + - * / ^, parentheses, implicit multiplication and
-- sin cos tan asin acos atan sqrt abs ln log exp floor ceil. Never uses load(); compiles to Lua closures.
local M = {}

local floor, ceil, abs, sqrt, exp, log = math.floor, math.ceil, math.abs, math.sqrt, math.exp, math.log
local NAN = 0 / 0

local FUNCS = {
  sin = math.sin, cos = math.cos, tan = math.tan,
  asin = function(v) if v < -1 or v > 1 then return NAN end return math.asin(v) end,
  acos = function(v) if v < -1 or v > 1 then return NAN end return math.acos(v) end,
  atan = math.atan,
  sqrt = function(v) if v < 0 then return NAN end return sqrt(v) end,
  abs = abs,
  ln = function(v) if v <= 0 then return v == 0 and -math.huge or NAN end return log(v) end,
  log = function(v) if v <= 0 then return v == 0 and -math.huge or NAN end return log(v, 10) end,
  exp = exp, floor = floor, ceil = ceil,
}
local CONSTS = {pi = math.pi, e = math.exp(1)}
-- longest names first so "exp" wins over "e" and "asin" over "sin"
local NAMES = {"floor", "asin", "acos", "atan", "sqrt", "ceil", "sin", "cos", "tan", "abs", "exp", "log", "ln", "pi", "x", "e"}

-- ------------------------------------------------------------------ tokenizer
local function tokenize(src)
  local s = src:gsub("π", "pi"):gsub("×", "*"):gsub("·", "*"):gsub("÷", "/"):gsub("−", "-"):gsub("²", "^2"):gsub("³", "^3")
  s = s:lower()
  local toks = {}
  local i, n = 1, #s
  while i <= n do
    local c = s:sub(i, i)
    if c:match("%s") then
      i = i + 1
    elseif c:match("[%d%.]") then
      local num = s:match("^%d*%.?%d*", i)
      if num == "." or num == "" then return nil, "err_number", i end
      local v = tonumber(num)
      if not v then return nil, "err_number", i end
      toks[#toks + 1] = {t = "num", v = v, pos = i}
      i = i + #num
    elseif c:match("%a") then
      local matched = nil
      for _, name in ipairs(NAMES) do
        if s:sub(i, i + #name - 1) == name then matched = name break end
      end
      if not matched then return nil, "err_name", i end
      if FUNCS[matched] then toks[#toks + 1] = {t = "fn", v = matched, pos = i}
      elseif matched == "x" then toks[#toks + 1] = {t = "x", pos = i}
      else toks[#toks + 1] = {t = "num", v = CONSTS[matched], pos = i} end
      i = i + #matched
    elseif c:match("[%+%-%*/%^%(%)|]") then
      toks[#toks + 1] = {t = c, pos = i}
      i = i + 1
    elseif c == "," then
      -- decimal comma, e.g. 0,5
      return nil, "err_comma", i
    else
      return nil, "err_char", i
    end
  end
  toks[#toks + 1] = {t = "end", pos = n + 1}
  return toks
end

-- ------------------------------------------------------------------ parser -> closures
function M.compile(src)
  if not src or src:match("^%s*$") then return nil, "err_empty" end
  local toks, err = tokenize(src)
  if not toks then return nil, err end
  local p = 1
  local function peek() return toks[p] end
  local function take() local t = toks[p]; p = p + 1; return t end

  local parseExpr, parseUnary, parsePower

  local function startsPrimary(t)
    return t.t == "num" or t.t == "x" or t.t == "fn" or t.t == "("
  end

  local function parsePrimary()
    local t = take()
    if t.t == "num" then
      local v = t.v
      return function() return v end
    elseif t.t == "x" then
      return function(x) return x end
    elseif t.t == "(" then
      local e = parseExpr()
      if peek().t ~= ")" then error({key = "err_paren"}) end
      take()
      return e
    elseif t.t == "|" then
      local e = parseExpr()
      if peek().t ~= "|" then error({key = "err_abs"}) end
      take()
      return function(x) return abs(e(x)) end
    elseif t.t == "fn" then
      local f = FUNCS[t.v]
      local arg
      if peek().t == "(" then
        take()
        arg = parseExpr()
        if peek().t ~= ")" then error({key = "err_paren"}) end
        take()
      elseif startsPrimary(peek()) or peek().t == "-" then
        -- sin x, sin 2x: the argument is an implicit product that stops at the next function name
        arg = parseUnary()
        while startsPrimary(peek()) and peek().t ~= "fn" do
          local r, l = parsePower(), arg
          arg = function(x) return l(x) * r(x) end
        end
      else
        error({key = "err_arg"})
      end
      return function(x) return f(arg(x)) end
    elseif t.t == "end" then
      error({key = "err_incomplete"})
    else
      error({key = "err_unexpected", ch = t.t})
    end
  end

  parsePower = function()
    local base = parsePrimary()
    if peek().t == "^" then
      take()
      local ex = parseUnary()       -- right associative: 2^3^2 = 2^(3^2), 2^-x allowed
      return function(x) return base(x) ^ ex(x) end
    end
    return base
  end

  parseUnary = function()
    local t = peek()
    if t.t == "-" then
      take()
      local e = parseUnary()
      return function(x) return -e(x) end
    elseif t.t == "+" then
      take()
      return parseUnary()
    end
    return parsePower()
  end

  local function parseTerm()
    local left = parseUnary()
    while true do
      local t = peek()
      if t.t == "*" or t.t == "/" then
        take()
        local right = parseUnary()
        local l = left
        if t.t == "*" then left = function(x) return l(x) * right(x) end
        else left = function(x) return l(x) / right(x) end end
      elseif startsPrimary(t) then
        -- implicit multiplication: 2x, 3sin(x), (x+1)(x-1), x pi
        local right = parsePower()
        local l = left
        left = function(x) return l(x) * right(x) end
      else
        break
      end
    end
    return left
  end

  parseExpr = function()
    local left = parseTerm()
    while true do
      local t = peek()
      if t.t == "+" or t.t == "-" then
        take()
        local right = parseTerm()
        local l = left
        if t.t == "+" then left = function(x) return l(x) + right(x) end
        else left = function(x) return l(x) - right(x) end end
      else
        break
      end
    end
    return left
  end

  local ok, res = pcall(function()
    local e = parseExpr()
    if peek().t ~= "end" then error({key = (peek().t == ")") and "err_paren" or "err_unexpected", ch = peek().t}) end
    return e
  end)
  if not ok then
    if type(res) == "table" then return nil, res.key end
    return nil, "err_syntax"
  end
  return res
end

return M
