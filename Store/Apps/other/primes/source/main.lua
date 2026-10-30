-- Primes: three ways to look at prime numbers.
--   1. Sieve of Eratosthenes, animated step by step on a grid (100 / 400 / 1000 numbers).
--   2. Ulam spiral of up to 40 000 numbers with zoom, pan and twin-prime highlighting.
--   3. Factorization of any whole number up to 10^12: trial division in small slices per frame (never blocks the
--      window), Miller-Rabin for primality, divisors, sum of divisors, neighbouring primes and a factor tree.
-- Everything heavy (the 40 000-number sieve, the spiral coordinates) is computed once in app.load.

local app = {}
local floor, min, max, abs, sqrt, random = math.floor, math.min, math.max, math.abs, math.sqrt, math.random

-- ---------------------------------------------------------------- constants
local MAXN = 40000                       -- sieve / spiral cache size
local SIEVE_SIZES = {100, 400, 1000}
local SIEVE_COLS = {10, 20, 40}
local SPIRAL_SIZES = {2500, 10000, 40000}
local SPEEDS = {1, 2, 4, 8, 15, 30, 60, 120, 250, 500}   -- sieve steps per second
local LIMIT = 1000000000000                               -- 10^12
local BUDGET = 40000                                      -- trial divisions per frame
local PAL = {"#FF6B6B", "#FFA94D", "#F5C518", "#51CF66", "#20C997", "#339AF0", "#5C7CFA", "#9775FA", "#F06595",
             "#CC5DE8", "#94D82D", "#22B8CF"}
local KIND_KEYS = {perfect = "kind_perfect", abundant = "kind_abundant", deficient = "kind_deficient"}
local PAL_RGB = {}
for i, c in ipairs(PAL) do
  PAL_RGB[i] = {tonumber(c:sub(2, 3), 16), tonumber(c:sub(4, 5), 16), tonumber(c:sub(6, 7), 16)}
end

-- ---------------------------------------------------------------- state
local tab = 1
local tabFade = 1
local flash = nil                       -- {text, t} short status message
local isPrime, primeList = {}, {}       -- cache up to MAXN
local SX, SY, GRID = {}, {}, {}         -- spiral coordinates and (x, y) -> n map
local GR = 101                          -- grid half size
local GW = GR * 2 + 1
local NUMSTR = {}                       -- tostring cache for grid labels
local PI_COUNT = {}                     -- number of primes up to each spiral size

-- sieve animation
local sv = nil
local sieveSize, speedIdx, playing, acc = 3, 6, false, 0

-- spiral view
local spiralIdx, twins = 3, true
local zoom, zoomTarget, camX, camY = 0, 0, 0, 0
local needFit = true                    -- fit the whole spiral on the next frame (eased)
local drag = nil
local hoverN = nil

-- factorization
local numText = "360"
local job = nil                          -- running trial division
local res = nil                          -- finished result
local inputError = nil
local resAnim = 0
local editing = false
local fieldRect = {x = 0, y = 0, w = 0, h = 0}

-- ---------------------------------------------------------------- number helpers
local function group(n)
  local s = tostring(n)
  local sep = sys.lang() == "tr" and "." or ","
  local out = s:reverse():gsub("(%d%d%d)", "%1" .. sep):reverse()
  if out:sub(1, 1) == sep then out = out:sub(2) end
  return out
end

-- (a * b) % n without 64-bit overflow for n < 2^40: b is split into 20-bit halves
local function mulmod(a, b, n)
  local hi, lo = b >> 20, b & 0xFFFFF
  local r = (a * hi) % n
  r = ((r << 20) % n + (a * lo) % n) % n
  return r
end
local function powmod(b, e, n)
  local r = 1
  b = b % n
  while e > 0 do
    if e & 1 == 1 then r = mulmod(r, b, n) end
    b = mulmod(b, b, n)
    e = e >> 1
  end
  return r
end
-- deterministic Miller-Rabin for n < 3.4 * 10^12 (bases 2..13), plain lookup below the cache size
local function prime(n)
  if n < 2 then return false end
  if n <= MAXN then return isPrime[n] == true end
  for _, p in ipairs({2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37}) do if n % p == 0 then return n == p end end
  local d, s = n - 1, 0
  while d % 2 == 0 do d = d // 2; s = s + 1 end
  for _, a in ipairs({2, 3, 5, 7, 11, 13}) do
    local x = powmod(a, d, n)
    if x ~= 1 and x ~= n - 1 then
      local ok = false
      for _ = 1, s - 1 do
        x = mulmod(x, x, n)
        if x == n - 1 then ok = true; break end
      end
      if not ok then return false end
    end
  end
  return true
end
local function nextPrime(n)
  local k = n + 1
  while not prime(k) do k = k + 1 end
  return k
end
local function prevPrime(n)
  local k = n - 1
  while k >= 2 and not prime(k) do k = k - 1 end
  return k >= 2 and k or nil
end
-- small factorization for hover labels (n <= MAXN)
local function smallFactors(n)
  local parts = {}
  local d = 2
  while d * d <= n do
    while n % d == 0 do parts[#parts + 1] = tostring(d); n = n // d end
    d = d + 1
  end
  if n > 1 then parts[#parts + 1] = tostring(n) end
  return table.concat(parts, " × ")
end

local function say(text) flash = {text = text, t = 3.5} end

-- ---------------------------------------------------------------- caches (once)
local function buildCaches()
  for i = 2, MAXN do isPrime[i] = true end
  for i = 2, floor(sqrt(MAXN)) do
    if isPrime[i] then for j = i * i, MAXN, i do isPrime[j] = false end end
  end
  for i = 2, MAXN do if isPrime[i] then primeList[#primeList + 1] = i end end
  for i = 1, 1000 do NUMSTR[i] = tostring(i) end
  for k, N in ipairs(SPIRAL_SIZES) do
    local c = 0
    for _, p in ipairs(primeList) do if p > N then break end; c = c + 1 end
    PI_COUNT[k] = c
  end
  -- Ulam spiral: 1 in the centre, then right, up, left, down with growing run lengths
  local dirs = {{1, 0}, {0, -1}, {-1, 0}, {0, 1}}
  local x, y, n, len, d = 0, 0, 1, 1, 1
  SX[1], SY[1] = 0, 0
  GRID[GR * GW + GR + 1] = 1
  while n < MAXN do
    for _ = 1, 2 do
      for _ = 1, len do
        if n >= MAXN then break end
        x, y, n = x + dirs[d][1], y + dirs[d][2], n + 1
        SX[n], SY[n] = x, y
        GRID[(y + GR) * GW + x + GR + 1] = n
      end
      d = d % 4 + 1
    end
    len = len + 1
  end
end
local function gridAt(x, y)
  if x < -GR or x > GR or y < -GR or y > GR then return nil end
  return GRID[(y + GR) * GW + x + GR + 1]
end

-- ---------------------------------------------------------------- sieve animation
local function sieveReset()
  local N = SIEVE_SIZES[sieveSize]
  sv = {N = N, crossed = {}, pidx = {}, primes = {}, p = 1, m = nil, done = false, marked = {}, steps = 0,
        reveal = {}, revealN = 0, finishedAt = 0}
  playing = false
  acc = 0
end

-- one step: either find the next prime or cross out one multiple of the current prime
local function sieveStep()
  if not sv or sv.done then return false end
  local now = sys.time()
  sv.steps = sv.steps + 1
  if not sv.m then
    local p = sv.p + 1
    while p <= sv.N and sv.crossed[p] do p = p + 1 end
    if p > sv.N or p * p > sv.N then
      -- every number that is still standing is prime: reveal them one after another
      sv.done, sv.finishedAt, sv.m = true, now, nil
      local k = 0
      for n = 2, sv.N do
        if not sv.crossed[n] and not sv.pidx[n] then k = k + 1; sv.reveal[n] = now + k * 0.012 end
      end
      sv.revealN = #sv.primes + k
      playing = false
      audio.tone(880, 0.12, 0.12, "triangle")
      audio.tone(1320, 0.2, 0.08, "triangle")
      return false
    end
    sv.p = p
    sv.primes[#sv.primes + 1] = p
    sv.pidx[p] = #sv.primes
    sv.marked[p] = now
    sv.m = p * p
    if SPEEDS[speedIdx] <= 60 then audio.tone(440 + #sv.primes * 60, 0.06, 0.08, "sine") end
    return true
  end
  local m = sv.m
  if not sv.crossed[m] then sv.crossed[m] = sv.pidx[sv.p] end
  sv.marked[m] = now
  sv.m = m + sv.p
  if sv.m > sv.N then sv.m = nil end
  return true
end

local function primesUpTo(N)
  local out = {}
  for _, p in ipairs(primeList) do if p > N then break end; out[#out + 1] = p end
  return out
end

local function exportPrimes(N)
  local list = primesUpTo(N)
  ui.saveFile(function(path)
    if not path then return end
    local lines = {TR("export_primes_head", N, #list), ""}
    for i = 1, #list, 10 do
      local row = {}
      for j = i, min(#list, i + 9) do row[#row + 1] = tostring(list[j]) end
      lines[#lines + 1] = table.concat(row, "\t")
    end
    if fs.write(path, table.concat(lines, "\n") .. "\n") then say(TR("saved")) else say(TR("save_failed")) end
  end, "primes_" .. N .. ".txt", TR("export_primes"))
end

-- ---------------------------------------------------------------- factorization job
local function finishJob()
  local n = job.n
  local fac = job.factors
  local count, sigma = 1, 1
  for _, f in ipairs(fac) do
    count = count * (f[2] + 1)
    local s, pw = 0, 1
    for _ = 0, f[2] do s = s + pw; pw = pw * f[1] end
    sigma = sigma * s
  end
  -- every divisor (at most 6 720 below 10^12), sorted
  local divs = {1}
  for _, f in ipairs(fac) do
    local cur = #divs
    local pw = 1
    for _ = 1, f[2] do
      pw = pw * f[1]
      for i = 1, cur do divs[#divs + 1] = divs[i] * pw end
    end
  end
  table.sort(divs)
  -- flat list of prime factors for the tree
  local flat = {}
  for _, f in ipairs(fac) do for _ = 1, f[2] do flat[#flat + 1] = f[1] end end
  local proper = sigma - n
  res = {n = n, factors = fac, flat = flat, count = count, sigma = sigma, divs = divs,
         isPrime = #flat == 1, prev = prevPrime(n), next = nextPrime(n),
         kind = proper == n and "perfect" or (proper > n and "abundant" or "deficient")}
  job = nil
  resAnim = 0
  audio.tone(660, 0.08, 0.1, "sine")
  audio.tone(990, 0.14, 0.07, "sine")
end

local function addFactor(p, e)
  local fac = job.factors
  fac[#fac + 1] = {p, e}
end

-- runs a slice of trial division (6k +- 1 wheel); the rest goes into the next frames
local function stepJob()
  local j = job
  local m, d, inc = j.m, j.d, j.inc
  local budget = BUDGET
  while m > 1 and budget > 0 do
    if d * d > m then addFactor(m, 1); m = 1; break end
    if m % d == 0 then
      local e = 0
      while m % d == 0 do m = m // d; e = e + 1 end
      addFactor(d, e)
      if m > 1 and prime(m) then addFactor(m, 1); m = 1; break end
    end
    d = d + inc
    inc = 6 - inc
    budget = budget - 1
  end
  j.m, j.d, j.inc = m, d, inc
  if m == 1 then finishJob() end
end

local function startFactor(text)
  inputError = nil
  local s = tostring(text or ""):gsub("[%s%.,_']", "")
  if s == "" then inputError = TR("err_empty"); return end
  if not s:match("^%d+$") then inputError = TR("err_digits"); return end
  if #s > 13 then inputError = TR("err_big"); return end
  local n = math.tointeger(tonumber(s))
  if not n then inputError = TR("err_digits"); return end
  if n < 2 then inputError = TR("err_small"); return end
  if n > LIMIT then inputError = TR("err_big"); return end
  numText = tostring(n)
  store.set("number", numText)
  res = nil
  job = {n = n, m = n, d = 5, inc = 2, factors = {}}
  -- 2 and 3 first, then the wheel
  for _, p in ipairs({2, 3}) do
    local e = 0
    while job.m % p == 0 do job.m = job.m // p; e = e + 1 end
    if e > 0 then addFactor(p, e) end
  end
  if job.m > 1 and prime(job.m) then addFactor(job.m, 1); job.m = 1 end
  if job.m == 1 then finishJob() end
end

local function randomNumber()
  local n = random() < 0.5 and random(2, 1000000) or random(1000000, LIMIT)
  numText = tostring(n)
  startFactor(numText)
end

local function factorString(r)
  local parts = {}
  for _, f in ipairs(r.factors) do parts[#parts + 1] = f[2] > 1 and (f[1] .. "^" .. f[2]) or tostring(f[1]) end
  return table.concat(parts, " × ")
end

local function exportFactor()
  local r = res
  if not r then return end
  ui.saveFile(function(path)
    if not path then return end
    local L = {
      TR("export_number", r.n),
      TR("export_factors", factorString(r)),
      TR("export_prime", r.isPrime and TR("yes") or TR("no")),
      TR("export_count", r.count),
      TR("export_sigma", r.sigma),
      TR("export_prev", r.prev and tostring(r.prev) or "-"),
      TR("export_next", r.next),
      "",
      TR("export_divs"),
    }
    local row = {}
    for i, d in ipairs(r.divs) do
      row[#row + 1] = tostring(d)
      if #row == 8 or i == #r.divs then L[#L + 1] = table.concat(row, "\t"); row = {} end
    end
    if fs.write(path, table.concat(L, "\n") .. "\n") then say(TR("saved")) else say(TR("save_failed")) end
  end, "factors_" .. r.n .. ".txt", TR("save_result"))
end

-- ---------------------------------------------------------------- persistence
local function saveSettings()
  store.set("tab", tab)
  store.set("sieveSize", sieveSize)
  store.set("speed", speedIdx)
  store.set("spiral", spiralIdx)
  store.set("twins", twins)
end

local function setTab(t)
  if t ~= tab and t >= 1 and t <= 3 then
    tab = t
    tabFade = 0
    store.set("tab", tab)
  end
end

local function fitZoom(w, h)
  local side = sqrt(SPIRAL_SIZES[spiralIdx]) + 2
  return max(1, min(40, min(w, h) / side))
end

function app.load()
  buildCaches()
  tab = store.get("tab", 1)
  if tab ~= 1 and tab ~= 2 and tab ~= 3 then tab = 1 end
  sieveSize = store.get("sieveSize", 3)
  if not SIEVE_SIZES[sieveSize] then sieveSize = 3 end
  speedIdx = store.get("speed", 6)
  if not SPEEDS[speedIdx] then speedIdx = 6 end
  spiralIdx = store.get("spiral", 3)
  if not SPIRAL_SIZES[spiralIdx] then spiralIdx = 3 end
  twins = store.get("twins", true) and true or false
  numText = tostring(store.get("number", "360"))
  sieveReset()
  needFit = true              -- the spiral is fitted on its first frame
end

function app.update(dt)
  tabFade = min(1, tabFade + dt * 5)
  if flash then flash.t = flash.t - dt; if flash.t <= 0 then flash = nil end end
  if playing and sv and not sv.done then
    acc = acc + dt * SPEEDS[speedIdx]
    local n = 0
    while acc >= 1 and n < 2000 do
      acc = acc - 1
      n = n + 1
      if not sieveStep() then acc = 0; break end
    end
  end
  if zoomTarget > 0 then zoom = zoom + (zoomTarget - zoom) * min(1, dt * 10) end
  if job then stepJob() end
  if res then resAnim = min(1, resAnim + dt * 2.5) end
end

-- ---------------------------------------------------------------- drawing helpers
local function emptyState(icon, title, text, x, y, w, h)
  gfx.icon(icon, x + w / 2, y + h / 2 - 34, 48, theme.text3)
  gfx.color(theme.text2)
  gfx.text(title, x, y + h / 2 + 2, 16, "semibold", "center", w)
  gfx.color(theme.text3)
  gfx.wrap(text, x + 20, y + h / 2 + 26, w - 40, 13, "sans", "center")
end

local function drawFlash(w, h)
  if not flash then return end
  local a = min(1, flash.t * 2)
  gfx.alpha(a)
  local tw = gfx.textWidth(flash.text, 13, "medium") + 32
  gfx.shadow(w / 2 - tw / 2, h - 52, tw, 30, 15, 10, 3)
  gfx.rect(w / 2 - tw / 2, h - 52, tw, 30, 15, theme.dark and "#3A3A3C" or "#1C1C1E")
  gfx.color("#FFFFFF")
  gfx.text(flash.text, w / 2 - tw / 2, h - 45, 13, "medium", "center", tw)
  gfx.unalpha()
end

-- ---------------------------------------------------------------- tab 1: sieve
local function drawSieve(x0, y0, w, h)
  local N = SIEVE_SIZES[sieveSize]
  -- toolbar
  local ns = ui.dropdown("size", {"1 – 100", "1 – 400", "1 – 1000"}, sieveSize, x0, y0, 120, 32)
  if ns ~= sieveSize then sieveSize = ns; sieveReset(); saveSettings() end
  local bx = x0 + 132
  if ui.iconButton(playing and "pause" or "play_arrow", bx, y0, 36, 32, theme.accent, playing, "play") then
    if sv.done then sieveReset() end
    playing = not playing
  end
  if ui.iconButton("skip_next", bx + 40, y0, 36, 32, theme.text2, false, "step") then playing = false; sieveStep() end
  if ui.iconButton("restart_alt", bx + 80, y0, 36, 32, theme.text2, false, "reset") then sieveReset() end
  gfx.icon("speed", bx + 134, y0 + 16, 18, theme.text2)
  local sp = ui.slider("speed", speedIdx, 1, #SPEEDS, bx + 148, y0 + 6, max(70, min(170, w - 520)), 1)
  sp = floor(sp + 0.5)
  if sp ~= speedIdx and SPEEDS[sp] then speedIdx = sp; store.set("speed", speedIdx) end
  gfx.color(theme.text2)
  local sx = bx + 148 + max(70, min(170, w - 520)) + 8
  gfx.text(TR("per_sec", SPEEDS[speedIdx]), sx, y0 + 8, 12, "medium")
  if ui.button(TR("export") .. "##sieve", x0 + w - 110, y0, 110, 32, "default", "save") then exportPrimes(N) end
  -- grid
  local cols = SIEVE_COLS[sieveSize]
  local rows = math.ceil(N / cols)
  local gy = y0 + 44
  local gh = h - 44 - 58
  local cs = floor(min(w / cols, gh / rows))
  if cs < 4 then return end
  local gx = x0 + floor((w - cs * cols) / 2)
  local now = sys.time()
  local fs = min(14, floor(cs * 0.5))
  local showText = cs >= 18
  local pad = cs >= 12 and 1 or 0
  for n = 1, N do
    local c = (n - 1) % cols
    local r = (n - 1) // cols
    local x, y = gx + c * cs, gy + r * cs
    local k = sv.crossed[n]
    local pi = sv.pidx[n]
    local rv = sv.reveal[n]
    local txt = theme.text
    if n == 1 then
      gfx.color(theme.separator)
      gfx.rect(x + pad, y + pad, cs - pad * 2, cs - pad * 2, cs * 0.18)
      txt = theme.text3
    elseif pi then
      gfx.color(PAL[(pi - 1) % #PAL + 1])
      gfx.rect(x + pad, y + pad, cs - pad * 2, cs - pad * 2, cs * 0.18)
      txt = "#FFFFFF"
    elseif rv and now >= rv then
      local a = min(1, (now - rv) * 5)
      gfx.color(theme.field)
      gfx.rect(x + pad, y + pad, cs - pad * 2, cs - pad * 2, cs * 0.18)
      gfx.alpha(a)
      gfx.color(theme.accent)
      gfx.rect(x + pad, y + pad, cs - pad * 2, cs - pad * 2, cs * 0.18)
      gfx.unalpha()
      txt = "#FFFFFF"
    elseif k then
      local c3 = PAL_RGB[(k - 1) % #PAL + 1]
      gfx.color(c3[1], c3[2], c3[3], 60)
      gfx.rect(x + pad, y + pad, cs - pad * 2, cs - pad * 2, cs * 0.18)
      txt = theme.text3
    else
      gfx.color(theme.field)
      gfx.rect(x + pad, y + pad, cs - pad * 2, cs - pad * 2, cs * 0.18)
    end
    -- the most recent marks glow and fade out
    local mk = sv.marked[n]
    if mk and now - mk < 0.6 then
      local a = 1 - (now - mk) / 0.6
      local c3 = PAL_RGB[((k or pi or 1) - 1) % #PAL + 1]
      gfx.color(c3[1], c3[2], c3[3], floor(200 * a))
      gfx.rectLine(x + pad, y + pad, cs - pad * 2, cs - pad * 2, cs * 0.18, 2)
    end
    if showText then
      gfx.color(txt)
      gfx.text(NUMSTR[n], x, y + (cs - fs * 1.25) / 2, fs, pi and "semibold" or "sans", "center", cs)
      if k and not pi then
        gfx.color(theme.text3)
        gfx.line(x + cs * 0.25, y + cs * 0.75, x + cs * 0.75, y + cs * 0.25, 1)
      end
    end
  end
  -- current prime ring
  if not sv.done and sv.p > 1 and sv.p <= N then
    local c = (sv.p - 1) % cols
    local r = (sv.p - 1) // cols
    gfx.color(theme.text)
    gfx.rectLine(gx + c * cs - 1, gy + r * cs - 1, cs + 2, cs + 2, cs * 0.22, 2)
  end
  -- status and legend
  local ly = gy + rows * cs + 10
  gfx.color(theme.text2)
  local status
  if sv.done then status = TR("sieve_done", sv.revealN, N)
  elseif sv.m then status = TR("sieve_crossing", sv.p, sv.m)
  elseif sv.steps == 0 then status = TR("sieve_idle")
  else status = TR("sieve_next") end
  gfx.text(status, x0, ly, 13, "medium", "center", w)
  local lx = x0 + w / 2 - #sv.primes * 17
  for i, p in ipairs(sv.primes) do
    gfx.rect(lx + (i - 1) * 34, ly + 22, 30, 20, 10, PAL[(i - 1) % #PAL + 1])
    gfx.color("#FFFFFF")
    gfx.text(tostring(p), lx + (i - 1) * 34, ly + 25, 11, "semibold", "center", 30)
  end
end

-- ---------------------------------------------------------------- tab 2: Ulam spiral
local function drawSpiral(x0, y0, w, h)
  local N = SPIRAL_SIZES[spiralIdx]
  local ni = ui.dropdown("spiral", {"2 500", "10 000", "40 000"}, spiralIdx, x0, y0, 110, 32)
  local ch = h - 44 - 30
  if ni ~= spiralIdx then spiralIdx = ni; needFit = true; camX, camY = 0, 0; saveSettings() end
  if ui.iconButton("zoom_out", x0 + 122, y0, 36, 32, theme.text2, false, "zout") then zoomTarget = max(1, zoomTarget / 1.5) end
  if ui.iconButton("zoom_in", x0 + 162, y0, 36, 32, theme.text2, false, "zin") then zoomTarget = min(40, zoomTarget * 1.5) end
  if ui.iconButton("center_focus_strong", x0 + 202, y0, 36, 32, theme.text2, false, "zfit") then
    needFit = true; camX, camY = 0, 0
  end
  local nt = ui.checkbox(TR("twin_primes"), twins, x0 + 254, y0 + 7)
  if nt ~= twins then twins = nt; store.set("twins", twins) end
  -- canvas
  local cy0 = y0 + 44
  if needFit then
    zoomTarget = fitZoom(w, ch)
    if zoom <= 0 then zoom = zoomTarget end
    needFit = false
  end
  local bg = theme.dark and "#0B0F1A" or "#F7F8FB"
  gfx.rect(x0, cy0, w, ch, 10, bg)
  gfx.clip(x0, cy0, w, ch)
  local cs = zoom
  local ox, oy = x0 + w / 2, cy0 + ch / 2
  local size = cs >= 3 and cs * 0.84 or max(1, cs)
  local half = size / 2
  local accent, orange = theme.accent, theme.orange
  local lastColor = nil
  for i = 1, #primeList do
    local p = primeList[i]
    if p > N then break end
    local px = ox + (SX[p] - camX) * cs
    local py = oy + (SY[p] - camY) * cs
    if px > x0 - cs and px < x0 + w + cs and py > cy0 - cs and py < cy0 + ch + cs then
      local tw = twins and ((p > 2 and isPrime[p - 2]) or isPrime[p + 2])
      local col = tw and orange or accent
      if col ~= lastColor then gfx.color(col); lastColor = col end
      gfx.rect(px - half, py - half, size, size, cs >= 8 and cs * 0.2 or 0)
    end
  end
  -- the centre (n = 1)
  gfx.circle(ox + (0 - camX) * cs, oy + (0 - camY) * cs, max(2, cs * 0.35), theme.red)
  -- numbers once the cells are big enough (only the visible ones)
  if cs >= 24 then
    local gx0 = floor(camX - w / 2 / cs) - 1
    local gx1 = math.ceil(camX + w / 2 / cs) + 1
    local gy0 = floor(camY - ch / 2 / cs) - 1
    local gy1 = math.ceil(camY + ch / 2 / cs) + 1
    local fsz = min(13, cs * 0.34)
    for gy = gy0, gy1 do
      for gx = gx0, gx1 do
        local n = gridAt(gx, gy)
        if n and n <= N then
          gfx.color(isPrime[n] and "#FFFFFF" or theme.text3)
          gfx.text(tostring(n), ox + (gx - camX) * cs - cs / 2, oy + (gy - camY) * cs - fsz * 0.62, fsz, "medium", "center", cs)
        end
      end
    end
  end
  gfx.unclip()
  -- pan by dragging, hover read-out
  local hit = ui.hit("canvas", x0, cy0, w, ch)
  if hit.pressed then drag = {x = camX, y = camY} end
  if drag and hit.held then
    camX = drag.x - (hit.dx or 0) / max(0.5, cs)
    camY = drag.y - (hit.dy or 0) / max(0.5, cs)
  elseif drag and not hit.held then
    drag = nil
  end
  local mx, my = ui.mouse()
  hoverN = nil
  if mx and mx >= x0 and mx <= x0 + w and my >= cy0 and my <= cy0 + ch then
    local gx = floor((mx - ox) / cs + camX + 0.5)
    local gy = floor((my - oy) / cs + camY + 0.5)
    local n = gridAt(gx, gy)
    if n and n <= N then hoverN = n end
  end
  -- status line
  local count = PI_COUNT[spiralIdx] or 0
  gfx.color(theme.text2)
  local st
  if hoverN then
    if hoverN == 1 then st = TR("hover_one")
    elseif isPrime[hoverN] then st = TR("hover_prime", hoverN)
    else st = TR("hover_comp", hoverN, smallFactors(hoverN)) end
  else
    st = TR("spiral_info", count, group(N))
  end
  gfx.text(st, x0, cy0 + ch + 8, 13, "medium", "center", w)
end

-- ---------------------------------------------------------------- tab 3: factorization
local function drawExpr(r, x, y, maxW, size)
  -- p^e with raised exponents, wrapping to new lines
  local cx, cy = x, y
  local lineH = size * 1.5
  for i, f in ipairs(r.factors) do
    local ps = tostring(f[1])
    local es = f[2] > 1 and tostring(f[2]) or nil
    local pw = gfx.textWidth(ps, size, "semibold")
    local ew = es and gfx.textWidth(es, size * 0.6, "semibold") + 2 or 0
    local sw = i < #r.factors and gfx.textWidth(" × ", size, "sans") or 0
    if cx + pw + ew > x + maxW and cx > x then cx = x; cy = cy + lineH end
    gfx.color(theme.accent)
    gfx.text(ps, cx, cy, size, "semibold")
    cx = cx + pw
    if es then
      gfx.color(theme.orange)
      gfx.text(es, cx + 1, cy - size * 0.25, size * 0.6, "semibold")
      cx = cx + ew
    end
    if i < #r.factors then
      gfx.color(theme.text3)
      gfx.text(" × ", cx, cy, size, "sans")
      cx = cx + sw
    end
  end
  return cy + lineH - y
end

local function infoRow(label, value, x, y, w, color)
  gfx.color(theme.text2)
  gfx.text(label, x, y, 13, "sans")
  gfx.color(color or theme.text)
  gfx.text(value, x, y, 13, "semibold", "right", w)
end

local function drawTree(x0, y0, w, h)
  ui.group(x0, y0, w, h)
  local r = res
  if not r then
    if job then
      emptyState("account_tree", TR("working"), TR("working_text"), x0, y0, w, h)
    else
      emptyState("account_tree", TR("tree_empty"), TR("tree_empty_text"), x0, y0, w, h)
    end
    return
  end
  local k = #r.flat
  local dx, dy = 58, 54
  local x00 = 40 + gfx.textWidth(tostring(r.n), 14, "semibold") / 2
  local cw = max(w - 4, x00 + k * dx + 120)
  local chh = max(h - 4, k * dy + 70)
  gfx.color(theme.text2)
  gfx.text(TR("factor_tree"), x0 + 14, y0 + 10, 13, "semibold")
  ui.beginScroll("tree", x0 + 2, y0 + 32, w - 4, h - 34, chh, cw)
  local function node(label, x, y, primeNode, a)
    local tw = gfx.textWidth(label, 14, "semibold") + 18
    gfx.alpha(a)
    gfx.rect(x - tw / 2, y - 13, tw, 26, 13, primeNode and theme.accent or theme.field)
    if not primeNode then gfx.color(theme.separator); gfx.rectLine(x - tw / 2, y - 13, tw, 26, 13, 1) end
    gfx.color(primeNode and "#FFFFFF" or theme.text)
    gfx.text(label, x - tw / 2, y - 9, 14, "semibold", "center", tw)
    gfx.unalpha()
  end
  -- caterpillar tree: n -> (smallest prime, rest) -> ...
  local rest = r.n
  local x, y = x00, 24
  local reveal = resAnim * (k + 1)
  for i = 1, k - 1 do
    local p = r.flat[i]
    local nr = rest // p
    local a = max(0, min(1, reveal - i + 1))
    gfx.color(theme.separator)
    gfx.alpha(a)
    gfx.line(x, y + 13, x - dx * 0.6, y + dy - 13, 1.5)
    gfx.line(x, y + 13, x + dx, y + dy - 13, 1.5)
    gfx.unalpha()
    node(tostring(rest), x, y, false, max(0, min(1, reveal - i + 2)))
    node(tostring(p), x - dx * 0.6, y + dy, true, a)
    rest = nr
    x, y = x + dx, y + dy
  end
  node(tostring(rest), x, y, true, max(0, min(1, reveal - k + 1)))
  ui.endScroll()
end

local function drawFactor(x0, y0, w, h)
  local lw = min(330, floor(w * 0.45))
  -- input row
  gfx.color(theme.text2)
  gfx.text(TR("number_label"), x0, y0, 12, "medium")
  local fw = lw - 112
  fieldRect.x, fieldRect.y, fieldRect.w, fieldRect.h = x0, y0 + 18, fw, 34
  local t, submitted = ui.textfield("num", numText, x0, y0 + 18, fw, 34, TR("number_ph"), "numeric")
  if t ~= numText then numText = t; inputError = nil end
  if ui.button(TR("factor") .. "##go", x0 + fw + 6, y0 + 18, 68, 34, "primary") or submitted then startFactor(numText) end
  if ui.iconButton("casino", x0 + fw + 78, y0 + 18, 34, 34, theme.text2, false, "rand") then randomNumber() end
  local yy = y0 + 58
  if inputError then
    gfx.icon("error_outline", x0 + 9, yy + 8, 16, theme.red)
    gfx.color(theme.red)
    gfx.text(inputError, x0 + 22, yy, 12, "medium")
  else
    gfx.color(theme.text3)
    gfx.text(TR("number_hint"), x0, yy, 12, "sans")
  end
  -- result card
  local cy = y0 + 82
  local chh = h - 82
  ui.group(x0, cy, lw, chh)
  if job then
    local total = sqrt(job.m)
    local done = total > 0 and min(1, job.d / total) or 1
    gfx.color(theme.text)
    gfx.text(TR("working"), x0 + 16, cy + 18, 15, "semibold")
    ui.progress(done, x0 + 16, cy + 46, lw - 32, 6)
    gfx.color(theme.text2)
    gfx.text(TR("tested_up_to", group(job.d)), x0 + 16, cy + 60, 12, "sans")
    if ui.button(TR("cancel") .. "##job", x0 + 16, cy + 86, 100, 30) then job = nil end
  elseif not res then
    emptyState("calculate", TR("factor_empty"), TR("factor_empty_text"), x0, cy, lw, chh)
  else
    local r = res
    gfx.alpha(resAnim)
    local iy = 12 + (1 - resAnim) * 10
    local inner = lw - 32
    -- content height: header + factorization + rows + divisors + button
    local divText = {}
    for i = 1, min(#r.divs, 48) do divText[#divText + 1] = group(r.divs[i]) end
    local dstr = table.concat(divText, ", ") .. (#r.divs > 48 and (" … (+" .. (#r.divs - 48) .. ")") or "")
    local dh = gfx.measureWrap(dstr, inner, 12, "sans")
    local content = 300 + (r.eh or 54) + dh   -- r.eh: height of the factorization line, measured last frame
    ui.beginScroll("card", x0, cy + 2, lw, chh - 4, content)
    gfx.color(theme.text)
    gfx.text(group(r.n), 16, iy, 22, "bold")
    if r.isPrime then
      gfx.rect(16, iy + 34, 70, 22, 11, theme.green)
      gfx.color("#FFFFFF")
      gfx.text(TR("is_prime"), 16, iy + 37, 12, "semibold", "center", 70)
    else
      gfx.color(theme.text3)
      gfx.text("=", 16, iy + 34, 18, "sans")
    end
    local eh = 26
    if not r.isPrime then eh = drawExpr(r, 36, iy + 34, inner - 20, 18) end
    r.eh = max(26, eh)
    local ry = iy + 40 + max(26, eh)
    infoRow(TR("prime_q"), r.isPrime and TR("yes") or TR("no"), 16, ry, inner, r.isPrime and theme.green or theme.text)
    infoRow(TR("divisor_count"), group(r.count), 16, ry + 26, inner)
    infoRow(TR("divisor_sum"), group(r.sigma), 16, ry + 52, inner)
    infoRow(TR("kind"), TR(KIND_KEYS[r.kind] or "kind_deficient"), 16, ry + 78, inner, r.kind == "perfect" and theme.orange or theme.text)
    -- neighbouring primes: tap to factor them
    gfx.color(theme.text2)
    gfx.text(TR("prev_prime"), 16, ry + 104, 13, "sans")
    if r.prev then
      if ui.button(group(r.prev) .. "##prev", 16 + inner - 130, ry + 99, 130, 26, "plain", "chevron_left") then
        numText = tostring(r.prev); startFactor(numText)
      end
    else
      gfx.color(theme.text3)
      gfx.text("-", 16, ry + 104, 13, "semibold", "right", inner)
    end
    gfx.color(theme.text2)
    gfx.text(TR("next_prime"), 16, ry + 130, 13, "sans")
    if res and ui.button(group(r.next) .. "##next", 16 + inner - 130, ry + 125, 130, 26, "plain", "chevron_right") then
      numText = tostring(r.next); startFactor(numText)
    end
    ui.separator(16, ry + 160, 16 + inner)
    gfx.color(theme.text2)
    gfx.text(TR("divisors"), 16, ry + 168, 12, "semibold")
    gfx.color(theme.text)
    gfx.wrap(dstr, 16, ry + 186, inner, 12, "sans")
    if ui.button(TR("save_result") .. "##save", 16, ry + 196 + dh, inner, 32, "default", "save") then exportFactor() end
    ui.endScroll()
    gfx.unalpha()
  end
  drawTree(x0 + lw + 14, y0, w - lw - 14, h)
end

-- ---------------------------------------------------------------- main draw
function app.draw(w, h)
  gfx.clear(theme.bg)
  local items = {TR("tab_sieve"), TR("tab_spiral"), TR("tab_factor")}
  local sw = min(460, w - 32)
  local nt = ui.segmented("tabs", items, tab, (w - sw) / 2, 12, sw, 32)
  if nt ~= tab then setTab(nt) end
  local x0, y0 = 16, 58
  local cw, ch = w - 32, h - 58 - 14
  gfx.alpha(0.25 + 0.75 * tabFade)
  gfx.push(0, (1 - tabFade) * 8)
  if tab == 1 then drawSieve(x0, y0, cw, ch)
  elseif tab == 2 then drawSpiral(x0, y0, cw, ch)
  else drawFactor(x0, y0, cw, ch) end
  gfx.pop()
  gfx.unalpha()
  drawFlash(w, h)
end

-- ---------------------------------------------------------------- input
local function zoomBy(f)
  if zoomTarget <= 0 then return end
  zoomTarget = max(1, min(40, zoomTarget * f))
end

function app.event(e)
  if e.type == "mousedown" then
    editing = tab == 3 and e.x >= fieldRect.x and e.x <= fieldRect.x + fieldRect.w and e.y >= fieldRect.y and
      e.y <= fieldRect.y + fieldRect.h
    return
  end
  if tab == 2 and e.type == "scroll" and (e.dy or 0) ~= 0 then zoomBy(e.dy < 0 and 1.15 or 1 / 1.15); return end
  if tab == 2 and e.type == "pinch" and e.scale then zoomBy(e.scale); return end
  if e.type ~= "keydown" then return end
  if e.ctrl and (e.key == "1" or e.key == "2" or e.key == "3") then setTab(tonumber(e.key)); return end
  if tab == 1 then
    if e.key == "space" or e.key == "enter" then
      if sv.done then sieveReset() end
      playing = not playing
    elseif e.key == "right" then playing = false; sieveStep()
    elseif e.key == "r" then sieveReset()
    elseif e.key == "up" then speedIdx = min(#SPEEDS, speedIdx + 1); store.set("speed", speedIdx)
    elseif e.key == "down" then speedIdx = max(1, speedIdx - 1); store.set("speed", speedIdx) end
  elseif tab == 2 then
    local stepc = 40 / max(1, zoom)
    if e.key == "left" then camX = camX - stepc
    elseif e.key == "right" then camX = camX + stepc
    elseif e.key == "up" then camY = camY - stepc
    elseif e.key == "down" then camY = camY + stepc
    elseif e.key == "pageup" or e.key == "=" or e.key == "+" then zoomBy(1.5)
    elseif e.key == "pagedown" or e.key == "-" then zoomBy(1 / 1.5)
    elseif e.key == "0" or e.key == "home" then needFit = true; camX, camY = 0, 0
    elseif e.key == "t" then twins = not twins; store.set("twins", twins) end
  elseif tab == 3 then
    if e.key == "escape" then
      if job then job = nil end
      editing = false
    end
  end
end

function app.menu()
  return {
    {title = TR("menu_view"), items = {
      {label = TR("tab_sieve"), id = 1, shortcut = "Ctrl+1", checked = tab == 1},
      {label = TR("tab_spiral"), id = 2, shortcut = "Ctrl+2", checked = tab == 2},
      {label = TR("tab_factor"), id = 3, shortcut = "Ctrl+3", checked = tab == 3},
    }},
    {title = TR("menu_sieve"), items = {
      {label = playing and TR("pause") or TR("play"), id = 10, shortcut = "Space"},
      {label = TR("step"), id = 11, shortcut = "→"},
      {label = TR("reset"), id = 12, shortcut = "R"},
      "-",
      {label = TR("export_primes"), id = 13},
    }},
    {title = TR("menu_spiral"), items = {
      {label = TR("zoom_in"), id = 20, shortcut = "+"},
      {label = TR("zoom_out"), id = 21, shortcut = "-"},
      {label = TR("reset_view"), id = 22, shortcut = "0"},
      {label = TR("twin_primes"), id = 23, shortcut = "T", checked = twins},
    }},
    {title = TR("menu_factor"), items = {
      {label = TR("random_number"), id = 30},
      {label = TR("factor_next"), id = 31, enabled = res ~= nil},
      {label = TR("factor_prev"), id = 32, enabled = res ~= nil and res.prev ~= nil},
      "-",
      {label = TR("save_result"), id = 33, enabled = res ~= nil},
    }},
  }
end

function app.onmenu(id)
  if id >= 1 and id <= 3 then setTab(id)
  elseif id == 10 then setTab(1); if sv.done then sieveReset() end; playing = not playing
  elseif id == 11 then setTab(1); playing = false; sieveStep()
  elseif id == 12 then setTab(1); sieveReset()
  elseif id == 13 then exportPrimes(SIEVE_SIZES[sieveSize])
  elseif id == 20 then setTab(2); zoomBy(1.5)
  elseif id == 21 then setTab(2); zoomBy(1 / 1.5)
  elseif id == 22 then setTab(2); needFit = true; camX, camY = 0, 0
  elseif id == 23 then twins = not twins; store.set("twins", twins)
  elseif id == 30 then setTab(3); randomNumber()
  elseif id == 31 then if res then setTab(3); numText = tostring(res.next); startFactor(numText) end
  elseif id == 32 then if res and res.prev then setTab(3); numText = tostring(res.prev); startFactor(numText) end
  elseif id == 33 then exportFactor() end
end

function app.close()
  saveSettings()
  store.set("number", numText)
  store.save()
  return true
end

return app
