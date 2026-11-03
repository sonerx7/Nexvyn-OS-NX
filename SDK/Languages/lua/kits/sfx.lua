-- sfx.lua: a small sound design kit for Nexvyn OS games (Lua 5.4, no dependencies, only SDK 1.0 calls).
--
-- Sounds are described as layered recipes (oscillators, noise, pitch and filter sweeps, envelopes, echo, room),
-- rendered once into 16-bit WAV files in the app's data folder (a few milliseconds per frame, never a long call),
-- cached across runs, and played with audio.play. On top: buses (music / sfx / ui / amb) with volumes, ducking,
-- random variants, voice limits and cooldowns, looping ambience with random details, and short music loops built
-- from a chord progression (pad, bass, arpeggio, drums).
--
-- Copy this file next to main.lua, then:
--
--   local sfx = require("sfx")
--   function app.load()
--     sfx.init()                                                    -- 22050 Hz mono WAVs in the folder "sfx"
--     sfx.define("coin", sfx.recipes.coin(), {variants = 3})
--     sfx.define("hit", sfx.recipes.impact{weight = 0.7}, {variants = 4, duck = {"music", 0.45, 0.25}})
--     sfx.define("click", sfx.recipes.ui{kind = "tick"}, {bus = "ui"})
--     sfx.define("wind", sfx.recipes.ambience{kind = "wind"}, {bus = "amb"})
--     sfx.song("theme", sfx.recipes.song{bpm = 92, root = "D3", scale = "dorian", chords = {1, 4, 6, 5}})
--   end
--   function app.update(dt) sfx.update(dt) end                     -- bakes, runs the music, ducking, ambience
--   -- sfx.ready() / sfx.progress() for a loading screen; then sfx.play("coin"), sfx.music("theme"),
--   -- sfx.ambience("wind"), sfx.setBus("music", 0.4)
--
-- Guide (how to make sounds feel good, levels, variation): SDK/Guides/SOUND_DESIGN.en.md.
local S = {}

S.rate = 22050          -- samples per second of the files (the mixer resamples to 48 kHz)
S.folder = "sfx"        -- in the app's data folder
S.version = 1           -- bump to force every file to be made again
S.budget = 0.004        -- seconds of baking per frame
S.maxUnits = 60000      -- and at most this many layer-samples per frame (also bounds the work when time stands still)
S.maxVoices = 12        -- sounds of this kit playing at once (the console has 24 channels for everything)

S.buses = {master = {vol = 1}, music = {vol = 0.55}, sfx = {vol = 0.9}, ui = {vol = 0.7}, amb = {vol = 0.6}}

local defs, order, jobs = {}, {}, {}
local voices = {}
local now = 0
local music, amb = nil, nil
local units, tickStart = 0, 0
local inited = false
local rnd = math.random

-- ------------------------------------------------------------------ small helpers
local NOTE = {c = 0, d = 2, e = 4, f = 5, g = 7, a = 9, b = 11}
-- "A4", "C#3", "Eb5" or a MIDI number -> frequency in Hz
function S.note(n)
  if type(n) == "number" then return 440 * 2 ^ ((n - 69) / 12) end
  return 440 * 2 ^ ((S.midi(n) - 69) / 12)
end
function S.midi(n)
  if type(n) == "number" then return n end
  local l, acc, o = n:match("^(%a)([#b]?)(%-?%d)$")
  assert(l, "sfx.note: use names like A4, C#3, Eb5")
  local m = NOTE[l:lower()] + (acc == "#" and 1 or acc == "b" and -1 or 0)
  return m + (tonumber(o) + 1) * 12
end
function S.db(d) return 10 ^ (d / 20) end

local function copy(t)
  if type(t) ~= "table" then return t end
  local c = {}
  for k, v in pairs(t) do c[k] = copy(v) end
  return c
end

-- deterministic text of a recipe (sorted keys): the cache key of its files
local function serialize(v, out)
  local tv = type(v)
  if tv == "table" then
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do
      out[#out + 1] = tostring(k)
      out[#out + 1] = "="
      serialize(v[k], out)
      out[#out + 1] = ","
    end
    out[#out + 1] = "}"
  elseif tv == "number" then
    out[#out + 1] = string.format("%.5g", v)
  else
    out[#out + 1] = tostring(v)
  end
  return out
end
local function hash(s)
  local h = 2166136261
  for i = 1, #s do h = ((h ~ s:byte(i)) * 16777619) & 0xffffffff end
  return string.format("%08x", h)
end

-- the baking budget: true when this frame's share is used up
local function spent()
  if units > S.maxUnits then return true end
  return sys.time() - tickStart > S.budget
end
local function step(n)
  units = units + n
  if spent() then coroutine.yield() end
end

-- ------------------------------------------------------------------ synthesis
-- one layer added into buffer `buf` (1-based samples) starting at sample `base`
local function renderLayer(L, buf, base, total, seed)
  local rate = S.rate
  local len = L.len or 0.2
  local n = math.floor(len * rate)
  local first = base + math.floor((L.at or 0) * rate)
  if first > total then return end
  if first + n - 1 > total then n = total - first + 1 end
  if n <= 0 then return end
  local wave = L.wave or "sine"
  local vol = L.vol or 1
  -- envelope (attack linear, decay exponential to sustain, hold, release exponential, last 32 samples linear)
  local a = math.max(1, math.floor((L.a or 0.004) * rate))
  local d = math.max(1, math.floor((L.d or 0.08) * rate))
  local s = L.s or 0.5
  local r = math.max(1, math.floor((L.r or 0.08) * rate))
  local relAt = math.max(a + 1, n - r)
  local dk = math.exp(-5 / d)
  local rk = math.exp(-6.9 / r)
  -- pitch: exponential glide from freq to `to` over `glide` seconds, vibrato in semitones
  local f = L.freq or 440
  local fTo = L.to or f
  local glideN = math.max(1, math.floor((L.glide or len) * rate))
  local fStep = (fTo / f) ^ (1 / glideN)
  local vib = L.vib
  local vibW = vib and 2 * math.pi * (vib.rate or 5) / rate or 0
  local vibD = vib and (vib.depth or 0.3) / 12 or 0
  local trem = L.trem
  local tremW = trem and 2 * math.pi * (trem.rate or 4) / rate or 0
  local tremD = trem and (trem.depth or 0.5) or 0
  local duty = L.duty or 0.5
  -- unison: extra detuned copies (saw / pulse pads)
  local uni = L.unison or 1
  local cents = L.cents or 10
  local ph, mul = {}, {}
  for u = 1, uni do
    ph[u] = ((seed * 0.618 + u * 0.37) % 1)
    mul[u] = uni == 1 and 1 or 2 ^ (((u - 1) / (uni - 1) - 0.5) * cents / 1200)
  end
  -- FM (phase modulation by a sine at ratio * freq)
  local fm = L.fm
  local fmRatio = fm and (fm.ratio or 2) or 0
  local fmIdx = fm and (fm.index or 2) or 0
  local fmStep = fm and ((fm.to or fmIdx) - fmIdx) / n or 0
  local mph = 0
  -- noise state
  local ns = (seed * 7919 + 12345) & 0x7fffffff
  local b0, b1, b2, br = 0, 0, 0, 0
  -- filters: state variable (TPT), low / band / high pass, cutoff sweep `to` and LFO in octaves
  local flt = {}
  for _, kind in ipairs({"hp", "lp", "bp"}) do
    local F = L[kind]
    if F then
      local cut = F.cut or 1000
      flt[#flt + 1] = {kind = kind, cut = cut, step = ((F.to or cut) / cut) ^ (1 / n), k = 1 / (F.q or 0.707),
        lfoW = F.lfo and 2 * math.pi * (F.lfo.rate or 0.5) / rate or 0, lfoD = F.lfo and (F.lfo.depth or 1) or 0,
        ic1 = 0, ic2 = 0, a1 = 0, a2 = 0, a3 = 0}
    end
  end
  local nf = #flt
  local e = 0
  local twoPi = 2 * math.pi
  local sin, abs, tan, pi = math.sin, math.abs, math.tan, math.pi
  local nyq = rate * 0.45
  for i = 0, n - 1 do
    -- envelope
    if i < a then e = i / a
    elseif i < relAt then e = s + (e - s) * dk
    else e = e * rk end
    if i > n - 33 then e = e * (n - 1 - i) / 32 end
    local fi = f
    if vib then fi = fi * 2 ^ (vibD * sin(vibW * i)) end
    -- oscillator
    local v = 0
    if wave == "noise" or wave == "pink" or wave == "brown" then
      ns = (ns * 1103515245 + 12345) & 0x7fffffff
      local w = ns / 1073741824 - 1
      if wave == "noise" then v = w
      elseif wave == "pink" then
        b0 = 0.99765 * b0 + w * 0.0990460
        b1 = 0.96300 * b1 + w * 0.2965164
        b2 = 0.57000 * b2 + w * 1.0526913
        v = (b0 + b1 + b2 + w * 0.1848) * 0.22
      else
        br = (br + 0.02 * w) / 1.02
        v = br * 3.5
      end
    else
      local dt = fi / rate
      if fm then
        mph = (mph + dt * fmRatio) % 1
      end
      for u = 1, uni do
        local du = dt * mul[u]
        local p = (ph[u] + du) % 1
        ph[u] = p
        local x
        if fm then p = (p + (fmIdx + fmStep * i) * sin(twoPi * mph) / twoPi) % 1 end
        if wave == "sine" then x = sin(twoPi * p)
        elseif wave == "triangle" then x = 4 * abs(p - 0.5) - 1
        elseif wave == "saw" then
          x = 2 * p - 1
          if p < du then local t = p / du; x = x - (t + t - t * t - 1)
          elseif p > 1 - du then local t = (p - 1) / du; x = x - (t * t + t + t + 1) end
        else -- square / pulse with duty, band-limited edges
          x = p < duty and 1 or -1
          if p < du then local t = p / du; x = x + (t + t - t * t - 1)
          elseif p > 1 - du then local t = (p - 1) / du; x = x + (t * t + t + t + 1) end
          local q = (p - duty) % 1
          if q < du then local t = q / du; x = x - (t + t - t * t - 1)
          elseif q > 1 - du then local t = (q - 1) / du; x = x - (t * t + t + t + 1) end
        end
        v = v + x
      end
      if uni > 1 then v = v / math.sqrt(uni) end
    end
    if i < glideN then f = f * fStep end
    -- filters (coefficients every 8 samples)
    for j = 1, nf do
      local F = flt[j]
      if i % 8 == 0 then
        local c = F.cut
        if F.lfoD ~= 0 then c = c * 2 ^ (F.lfoD * sin(F.lfoW * i)) end
        if c > nyq then c = nyq elseif c < 20 then c = 20 end
        local g = tan(pi * c / rate)
        F.a1 = 1 / (1 + g * (g + F.k))
        F.a2 = g * F.a1
        F.a3 = g * F.a2
      end
      local v3 = v - F.ic2
      local v1 = F.a1 * F.ic1 + F.a2 * v3
      local v2 = F.ic2 + F.a2 * F.ic1 + F.a3 * v3
      F.ic1 = 2 * v1 - F.ic1
      F.ic2 = 2 * v2 - F.ic2
      if F.kind == "lp" then v = v2 elseif F.kind == "bp" then v = v1 else v = v - F.k * v1 - v2 end
      F.cut = F.cut * F.step
    end
    if trem then v = v * (1 - tremD * 0.5 * (1 + sin(tremW * i))) end
    local k = first + i
    buf[k] = buf[k] + v * e * vol
    if i % 512 == 511 then step(512 * (uni + nf)) end
  end
end

local function zeros(n)
  local b = {}
  for i = 1, n do
    b[i] = 0
    if i % 8192 == 0 then step(2048) end
  end
  return b
end

-- echo (feedback delay) in place
local function echo(buf, E)
  local d = math.max(1, math.floor((E.time or 0.15) * S.rate))
  local fb, mix = E.feedback or 0.35, E.mix or 0.3
  local line, pos = {}, 1
  for i = 1, d do line[i] = 0 end
  for i = 1, #buf do
    local x = buf[i]
    local y = line[pos]
    line[pos] = x + y * fb
    pos = pos % d + 1
    buf[i] = x + y * mix
    if i % 2048 == 0 then step(1024) end
  end
end

-- a small Schroeder room (4 combs, 2 allpasses), mixed in place
local function room(buf, R)
  local sc = S.rate / 44100 * (0.6 + (R.size or 0.5) * 0.8)
  local fb = 0.72 + (R.size or 0.5) * 0.12
  local damp = R.damp or 0.35
  local mix = R.mix or 0.18
  local combs = {}
  for _, len in ipairs({1116, 1188, 1277, 1356}) do
    local n = math.max(1, math.floor(len * sc))
    local line = {}
    for i = 1, n do line[i] = 0 end
    combs[#combs + 1] = {line = line, n = n, pos = 1, lp = 0}
  end
  local aps = {}
  for _, len in ipairs({556, 441}) do
    local n = math.max(1, math.floor(len * sc))
    local line = {}
    for i = 1, n do line[i] = 0 end
    aps[#aps + 1] = {line = line, n = n, pos = 1}
  end
  for i = 1, #buf do
    local x = buf[i] * 0.25
    local y = 0
    for c = 1, 4 do
      local C = combs[c]
      local o = C.line[C.pos]
      C.lp = o * (1 - damp) + C.lp * damp
      C.line[C.pos] = x + C.lp * fb
      C.pos = C.pos % C.n + 1
      y = y + o
    end
    for c = 1, 2 do
      local A = aps[c]
      local o = A.line[A.pos]
      A.line[A.pos] = y + o * 0.5
      A.pos = A.pos % A.n + 1
      y = o - y * 0.5
    end
    buf[i] = buf[i] + y * mix
    if i % 1024 == 0 then step(1024) end
  end
end

-- mono master: drive, DC block, normalize to `peak` dB, gain, edge fades
local function master(buf, R, loop)
  local drive = R.drive or 0
  local x1, y1 = 0, 0
  local peak = 0
  for i = 1, #buf do
    local x = buf[i]
    if drive > 0 then
      x = x * (1 + drive * 3)
      if x > 3 then x = 3 elseif x < -3 then x = -3 end
      x = x * (27 + x * x) / (27 + 9 * x * x)
    end
    local y = x - x1 + 0.995 * y1
    x1, y1 = x, y
    buf[i] = y
    local m = y < 0 and -y or y
    if m > peak then peak = m end
    if i % 4096 == 0 then step(1024) end
  end
  local g = peak > 0 and S.db(R.peak or -1) / peak * S.db(R.gain or 0) or 0
  local n = #buf
  local fadeIn = loop and 0 or math.floor(S.rate * 0.001)
  local fadeOut = loop and 0 or math.floor(S.rate * 0.005)
  for i = 1, n do
    local v = buf[i] * g
    if i <= fadeIn then v = v * i / fadeIn end
    if i > n - fadeOut then v = v * (n - i) / fadeOut end
    buf[i] = v
    if i % 4096 == 0 then step(1024) end
  end
end

-- WAV file: 16-bit PCM mono
local PACK = "<" .. string.rep("i2", 256)
local function wav(buf)
  local n = #buf
  local parts = {string.pack("<c4I4c4c4I4I2I2I4I4I2I2c4I4", "RIFF", 36 + n * 2, "WAVE", "fmt ", 16, 1, 1, S.rate,
    S.rate * 2, 2, 16, "data", n * 2)}
  local tmp = {}
  local floor = math.floor
  for i = 1, n, 256 do
    local m = math.min(256, n - i + 1)
    for j = 1, m do
      local v = floor(buf[i + j - 1] * 32767 + 0.5)
      if v > 32767 then v = 32767 elseif v < -32768 then v = -32768 end
      tmp[j] = v
    end
    if m == 256 then parts[#parts + 1] = string.pack(PACK, table.unpack(tmp, 1, 256))
    else parts[#parts + 1] = string.pack("<" .. string.rep("i2", m), table.unpack(tmp, 1, m)) end
    if i % 8192 == 1 then step(2048) end
  end
  return table.concat(parts)
end

-- renders a recipe (or the part of it between t0 and t1, for music bars) to a sample buffer
local function render(R, seed, t0, t1)
  local rate = S.rate
  local loop = R.loop and not t0
  local len = R.len
  if not len then
    len = 0
    for _, L in ipairs(R.layers) do len = math.max(len, (L.at or 0) + (L.len or 0.2)) end
    len = len + 0.02
  end
  local tail = (R.echo or R.room or R.stems) and (R.tail or 0.6) or 0
  if loop and R.crossfade then tail = R.crossfade end
  local span = t0 and (t1 - t0) or len
  local total = math.floor((span + tail) * rate)
  local out = zeros(total)
  -- stems: each rendered alone, its echo applied, then added to the mix with its gain
  local stems = {}
  for _, L in ipairs(R.layers) do
    local at = L.at or 0
    if not t0 or (at >= t0 and at < t1) then
      local name = L.stem or "main"
      if not stems[name] then stems[name] = {}; stems[#stems + 1] = name end
      table.insert(stems[name], L)
    end
  end
  local tmp = #stems > 1 and zeros(total) or nil
  for si, name in ipairs(stems) do
    local cfg = R.stems and R.stems[name] or {}
    local dst = tmp or out
    if tmp and si > 1 then
      for i = 1, total do
        tmp[i] = 0
        if i % 8192 == 0 then step(2048) end
      end
    end
    for li, L in ipairs(stems[name]) do
      local Lr = L
      if t0 then Lr = copy(L); Lr.at = (L.at or 0) - t0 end
      renderLayer(Lr, dst, 1, total, seed * 31 + li + si * 1000)
    end
    if cfg.echo then echo(dst, cfg.echo) end
    if tmp then
      local g = S.db(cfg.gain or 0)
      for i = 1, total do
        out[i] = out[i] + tmp[i] * g
        if i % 8192 == 0 then step(2048) end
      end
    end
  end
  if R.echo then echo(out, R.echo) end
  if R.room then room(out, R.room) end
  -- a loop: fold what rings past the end into the start (notes), or crossfade the ends (beds)
  if loop then
    local n = math.floor(len * rate)
    local t = total - n
    if R.crossfade then
      for i = 1, t do
        local k = i / t
        out[i] = out[i] * math.sqrt(k) + out[n + i] * math.sqrt(1 - k)
      end
    else
      for i = 1, t do out[i] = out[i] + out[n + i] end
    end
    for i = total, n + 1, -1 do out[i] = nil end
  end
  master(out, R, loop)
  return out
end

-- random variation of a recipe: pitch, filter and level, a few percent each
local function vary(R, seed, amount)
  if seed == 1 or amount <= 0 then return R end
  local s = (seed * 2654435761) & 0x7fffffff
  local function r()
    s = (s * 1103515245 + 12345) & 0x7fffffff
    return s / 1073741824 - 1
  end
  local V = copy(R)
  local pf = 2 ^ (r() * amount * 1.5 / 12)        -- up to +-1.5 semitones at amount 1
  local ff = 2 ^ (r() * amount * 0.4)
  for _, L in ipairs(V.layers) do
    if L.freq then L.freq = L.freq * pf end
    if L.to then L.to = L.to * pf end
    for _, k in ipairs({"lp", "hp", "bp"}) do
      if L[k] then
        L[k].cut = (L[k].cut or 1000) * ff
        if L[k].to then L[k].to = L[k].to * ff end
      end
    end
    L.vol = (L.vol or 1) * (1 + r() * amount * 0.12)
    if L.at and L.at > 0 then L.at = L.at * (1 + r() * amount * 0.08) end
  end
  return V
end

-- ------------------------------------------------------------------ definitions and baking
function S.init(o)
  o = o or {}
  for _, k in ipairs({"rate", "folder", "version", "budget", "maxUnits", "maxVoices"}) do
    if o[k] ~= nil then S[k] = o[k] end
  end
  fs.mkdir(S.folder)
  inited = true
end

local function enqueue(d)
  local key = hash(table.concat(serialize({d.recipe, d.variants, d.vary, d.mode, S.rate, S.version}, {})))
  d.files = {}
  local count = d.kind == "song" and d.mode == "bars" and d.recipe.bars or d.variants
  local missing = false
  for v = 1, count do
    d.files[v] = string.format("%s/%s_%s_%d.wav", S.folder, d.name, key, v)
    if not fs.exists(d.files[v]) then missing = true end
  end
  d.ready = not missing
  if missing then
    local job = {def = d}
    job.co = coroutine.create(function()
      for v = 1, count do
        if not fs.exists(d.files[v]) then
          local buf
          if d.kind == "song" and d.mode == "bars" then
            local bar = d.recipe.bar
            buf = render(d.recipe, v, (v - 1) * bar, v * bar)
          else
            buf = render(vary(d.recipe, v, d.vary), v)
          end
          if not fs.write(d.files[v], wav(buf)) then error("cannot write " .. d.files[v]) end
        end
        d.done = v
      end
      d.ready = true
    end)
    -- one-shots first, then ambience, then music
    local pri = d.kind == "song" and 3 or d.bus == "amb" and 2 or 1
    job.pri = pri
    local at = #jobs + 1
    for i, j in ipairs(jobs) do
      if j.pri > pri then at = i; break end
    end
    table.insert(jobs, at, job)
  end
  d.lengths = d.lengths or {}
end

-- define(name, recipe[, {bus, vol (0..1), variants, vary (0..1), maxVoices, cooldown (s), duck = {bus, level, sec}}])
function S.define(name, recipe, o)
  assert(inited, "sfx.define: call sfx.init() first")
  o = o or {}
  local d = {name = name, recipe = recipe, kind = "sfx", bus = o.bus or (recipe.loop and "amb" or "sfx"),
    vol = o.vol or 1, variants = recipe.loop and 1 or (o.variants or 1), vary = o.vary or 0.5,
    maxVoices = o.maxVoices or 3, cooldown = o.cooldown or 0.04, duck = o.duck, last = -1, lastVariant = 0}
  defs[name] = d
  order[#order + 1] = name
  enqueue(d)
  return d
end

-- song(name, songRecipe[, {vol, mode = "loop" | "bars"}]): "loop" is one gapless file (best quality, no ducking),
-- "bars" is one file per bar played in time by sfx.update (ducking and volume changes apply at every bar)
function S.song(name, recipe, o)
  assert(inited, "sfx.song: call sfx.init() first")
  o = o or {}
  local d = {name = name, recipe = recipe, kind = "song", bus = "music", vol = o.vol or 1, variants = 1, vary = 0,
    mode = o.mode or "loop"}
  defs[name] = d
  order[#order + 1] = name
  enqueue(d)
  return d
end

function S.ready(name)
  if name then return defs[name] ~= nil and defs[name].ready == true end
  return #jobs == 0
end
-- 0..1 over everything defined so far (for a loading bar)
function S.progress()
  local total, done = 0, 0
  for _, n in ipairs(order) do
    local d = defs[n]
    local c = #d.files
    total = total + c
    done = done + (d.ready and c or (d.done or 0))
  end
  return total == 0 and 1 or done / total
end

-- ------------------------------------------------------------------ buses and ducking
function S.setBus(name, vol)
  S.buses[name] = S.buses[name] or {vol = 1}
  S.buses[name].vol = vol
end
function S.bus(name) return S.buses[name] and S.buses[name].vol or 1 end
-- duck(bus, level 0..1, seconds): the bus plays at `level` for `seconds`, then comes back over 0.3 s
function S.duck(bus, level, sec)
  local b = S.buses[bus]
  if not b then return end
  b.duckLevel = math.min(b.duckLevel or 1, level)
  b.duckUntil = math.max(b.duckUntil or 0, now + (sec or 0.25))
end
local function busGain(name)
  local b = S.buses[name] or {vol = 1}
  local g = b.vol * S.buses.master.vol
  if b.duckLevel then g = g * b.duckLevel end
  return g
end

-- ------------------------------------------------------------------ playing
local function voiceEnd(d)
  if not d.dur then
    local len = d.recipe.len or 0
    for _, L in ipairs(d.recipe.layers) do len = math.max(len, (L.at or 0) + (L.len or 0.2)) end
    d.dur = len + ((d.recipe.echo or d.recipe.room) and (d.recipe.tail or 0.6) or 0.02)
  end
  return now + d.dur
end

-- play(name[, {vol, bus}]) -> channel or nil
function S.play(name, o)
  local d = defs[name]
  if not d or not d.ready or d.kind ~= "sfx" then return nil end
  if now - d.last < d.cooldown then return nil end
  d.last = now
  local v = 1
  if d.variants > 1 then
    v = rnd(1, d.variants)
    if v == d.lastVariant then v = v % d.variants + 1 end
  end
  d.lastVariant = v
  -- voice limits: this sound, then the whole kit
  local mine, oldest = 0, nil
  for _, vc in ipairs(voices) do
    if vc.def == d then
      mine = mine + 1
      if not oldest or vc.t < oldest.t then oldest = vc end
    end
  end
  if mine >= d.maxVoices and oldest then audio.stop(oldest.ch); oldest.dead = true end
  if #voices >= S.maxVoices then audio.stop(voices[1].ch); voices[1].dead = true end
  local vol = (o and o.vol or 1) * d.vol * busGain(o and o.bus or d.bus)
  local ch = audio.play(d.files[v], math.min(1, vol), 0)
  if d.duck then S.duck(d.duck[1], d.duck[2], d.duck[3]) end
  if not ch or ch < 0 then return nil end
  voices[#voices + 1] = {ch = ch, def = d, t = now, ends = voiceEnd(d)}
  return ch
end

-- music(name): starts a song made with sfx.song (stops the one playing)
function S.music(name)
  S.stopMusic()
  local d = defs[name]
  if not d or d.kind ~= "song" then return false end
  music = {def = d, bar = 0, next = now, wait = not d.ready}
  return true
end
function S.stopMusic()
  if music and music.ch then audio.stop(music.ch) end
  music = nil
end
function S.musicPlaying() return music ~= nil end

-- ambience(name[, {details = {"drip", ...}, every = {min, max}, vol}]): a looping bed plus random one-shots
function S.ambience(name, o)
  S.stopAmbience()
  o = o or {}
  amb = {name = name, details = o.details or {}, every = o.every or {2, 6}, vol = o.vol or 1, next = now + 1}
end
function S.stopAmbience()
  if amb and amb.ch then audio.stop(amb.ch) end
  amb = nil
end

-- update(dt): call every frame
function S.update(dt)
  now = now + (dt or 1 / 60)
  -- baking
  units, tickStart = 0, sys.time()
  while #jobs > 0 and not spent() do
    local j = jobs[1]
    local ok, err = coroutine.resume(j.co)
    if not ok then
      sys.log("sfx: " .. j.def.name .. ": " .. tostring(err))
      j.def.failed = true
      table.remove(jobs, 1)
    elseif coroutine.status(j.co) == "dead" then
      table.remove(jobs, 1)
    end
  end
  -- ducking recovers
  for _, b in pairs(S.buses) do
    if b.duckLevel and now > (b.duckUntil or 0) then
      b.duckLevel = b.duckLevel + (dt or 1 / 60) / 0.3
      if b.duckLevel >= 1 then b.duckLevel = nil end
    end
  end
  -- voices that ended
  for i = #voices, 1, -1 do
    if voices[i].dead or now > voices[i].ends then table.remove(voices, i) end
  end
  -- music
  if music then
    local d = music.def
    if d.ready then
      if d.mode == "bars" then
        if now >= music.next - 0.004 then
          music.bar = music.bar % #d.files + 1
          audio.play(d.files[music.bar], math.min(1, d.vol * busGain("music")), 0)
          if music.next < now - 0.1 then music.next = now end   -- after a hitch, start again from here
          music.next = music.next + d.recipe.bar
        end
      elseif not music.ch then
        music.ch = audio.play(d.files[1], math.min(1, d.vol * busGain("music")), -1)
      end
    end
  end
  -- ambience bed and details
  if amb then
    local d = defs[amb.name]
    if d and d.ready and not amb.ch then
      amb.ch = audio.play(d.files[1], math.min(1, d.vol * amb.vol * busGain(d.bus)), -1)
    end
    if now >= amb.next and #amb.details > 0 then
      local name = amb.details[rnd(1, #amb.details)]
      S.play(name, {vol = amb.vol * (0.35 + rnd() * 0.65), bus = "amb"})
      amb.next = now + amb.every[1] + rnd() * (amb.every[2] - amb.every[1])
    end
  end
end

-- removes files of this kit's folder that no current definition uses (after a change of recipes)
function S.clean()
  local keep = {}
  for _, n in ipairs(order) do
    for _, f in ipairs(defs[n].files) do keep[f] = true end
  end
  for _, e in ipairs(fs.list(S.folder) or {}) do
    local p = S.folder .. "/" .. e.name
    if not e.dir and e.name:match("%.wav$") and not keep[p] then fs.remove(p, true) end
  end
end

-- ------------------------------------------------------------------ recipes
-- Each returns a recipe table; pass options to shape it. Read them as examples of layering: a body (the pitch you
-- hear), a transient (the attack: a click or a noise burst), and a tail (echo, room, a low thump).
local R = {}
S.recipes = R

-- UI: kind = "tick" (move), "confirm", "back", "error", "open"
function R.ui(o)
  o = o or {}
  local p = o.pitch or 1
  local k = o.kind or "tick"
  if k == "confirm" then
    return {layers = {
      {wave = "triangle", freq = 660 * p, len = 0.07, a = 0.002, d = 0.05, s = 0.2, r = 0.03, vol = 0.8},
      {wave = "triangle", freq = 990 * p, at = 0.055, len = 0.12, a = 0.002, d = 0.08, s = 0.2, r = 0.05, vol = 0.8},
      {wave = "noise", len = 0.012, a = 0.001, d = 0.01, s = 0, r = 0.002, hp = {cut = 4000}, vol = 0.25}},
      room = {size = 0.2, mix = 0.12}}
  elseif k == "back" then
    return {layers = {
      {wave = "triangle", freq = 520 * p, to = 380 * p, len = 0.09, a = 0.002, d = 0.07, s = 0.1, r = 0.02, vol = 0.8},
      {wave = "noise", len = 0.01, a = 0.001, d = 0.008, s = 0, r = 0.002, hp = {cut = 3000}, vol = 0.2}}}
  elseif k == "error" then
    return {layers = {
      {wave = "square", duty = 0.3, freq = 180 * p, len = 0.09, a = 0.002, d = 0.06, s = 0.4, r = 0.03, lp = {cut = 1200}, vol = 0.6},
      {wave = "square", duty = 0.3, freq = 150 * p, at = 0.1, len = 0.14, a = 0.002, d = 0.08, s = 0.4, r = 0.05, lp = {cut = 1000}, vol = 0.6}}}
  elseif k == "open" then
    return {layers = {
      {wave = "noise", len = 0.18, a = 0.05, d = 0.1, s = 0.2, r = 0.05, bp = {cut = 900, to = 3500, q = 1.2}, vol = 0.5},
      {wave = "sine", freq = 440 * p, to = 880 * p, len = 0.16, a = 0.02, d = 0.1, s = 0.3, r = 0.05, vol = 0.4}},
      room = {size = 0.3, mix = 0.15}}
  end
  return {layers = {   -- tick: a short, soft, mid-high blip with a tiny click on top
    {wave = "sine", freq = 1250 * p, to = 1100 * p, len = 0.035, a = 0.001, d = 0.025, s = 0, r = 0.01, vol = 0.7},
    {wave = "noise", len = 0.006, a = 0.0005, d = 0.005, s = 0, r = 0.001, bp = {cut = 5000, q = 1.5}, vol = 0.3}}}
end

-- a bright two-note chime with a sparkle and echo
function R.coin(o)
  o = o or {}
  local p = o.pitch or 1
  return {layers = {
    {wave = "triangle", freq = 988 * p, len = 0.08, a = 0.001, d = 0.06, s = 0.3, r = 0.02, vol = 0.7},
    {wave = "sine", freq = 1319 * p, at = 0.06, len = 0.32, a = 0.001, d = 0.12, s = 0.25, r = 0.18, vol = 0.8,
      fm = {ratio = 3, index = 0.6, to = 0}},
    {wave = "noise", at = 0.06, len = 0.05, a = 0.001, d = 0.04, s = 0, r = 0.01, hp = {cut = 7000}, vol = 0.15}},
    echo = {time = 0.085, feedback = 0.25, mix = 0.2}}
end

-- an upward springy sweep; weight 0 (light) .. 1 (heavy)
function R.jump(o)
  o = o or {}
  local p = (o.pitch or 1) * (1.3 - (o.weight or 0.4) * 0.6)
  return {layers = {
    {wave = "triangle", freq = 220 * p, to = 520 * p, glide = 0.12, len = 0.18, a = 0.003, d = 0.12, s = 0.2, r = 0.05, vol = 0.8},
    {wave = "square", duty = 0.25, freq = 220 * p, to = 520 * p, glide = 0.12, len = 0.14, a = 0.003, d = 0.08, s = 0.1, r = 0.04,
      lp = {cut = 2200, to = 900}, vol = 0.25},
    {wave = "noise", len = 0.07, a = 0.002, d = 0.05, s = 0, r = 0.01, bp = {cut = 1200, to = 3000, q = 1}, vol = 0.25}}}
end

-- a laser / shot: fast downward sweep, FM bite, short echo; length in seconds
function R.laser(o)
  o = o or {}
  local p = o.pitch or 1
  local len = o.length or 0.22
  return {layers = {
    {wave = "saw", freq = 1800 * p, to = 220 * p, glide = len * 0.8, len = len, a = 0.001, d = len * 0.6, s = 0.2, r = len * 0.3,
      lp = {cut = 6000, to = 1200, q = 1.4}, vol = 0.55, fm = {ratio = 1.5, index = 1.2, to = 0}},
    {wave = "sine", freq = 900 * p, to = 120 * p, glide = len * 0.7, len = len, a = 0.001, d = len * 0.5, s = 0.1, r = len * 0.3, vol = 0.5},
    {wave = "noise", len = 0.02, a = 0.0005, d = 0.015, s = 0, r = 0.003, hp = {cut = 3000}, vol = 0.35}},
    echo = {time = 0.06, feedback = 0.2, mix = 0.18}}
end

-- an impact: low thump (body), noise crack (transient), crunch (drive); weight 0..1, bright 0..1
function R.impact(o)
  o = o or {}
  local w = o.weight or 0.5
  local b = o.bright or 0.5
  return {layers = {
    {wave = "sine", freq = 160 - w * 60, to = 42, glide = 0.09 + w * 0.08, len = 0.2 + w * 0.25, a = 0.001, d = 0.12 + w * 0.15, s = 0, r = 0.06, vol = 1},
    {wave = "noise", len = 0.08, a = 0.0005, d = 0.05, s = 0, r = 0.02, bp = {cut = 1500 + b * 2500, to = 700, q = 0.9}, vol = 0.7},
    {wave = "noise", len = 0.012, a = 0.0003, d = 0.01, s = 0, r = 0.002, hp = {cut = 5000}, vol = 0.4 * b},
    {wave = "square", duty = 0.4, freq = 90, to = 55, len = 0.1, a = 0.001, d = 0.07, s = 0, r = 0.02, lp = {cut = 600}, vol = 0.25 * w}},
    drive = 0.25 + w * 0.3, room = {size = 0.25, mix = 0.1}}
end

-- an explosion: sub boom, rumbling noise with a falling filter, crackles; size 0..1
function R.explosion(o)
  o = o or {}
  local sz = o.size or 0.6
  local len = 0.7 + sz * 1.0
  local layers = {
    {wave = "sine", freq = 110, to = 30, glide = 0.4, len = 0.5 + sz * 0.4, a = 0.001, d = 0.3, s = 0.3, r = 0.2, vol = 1},
    {wave = "brown", len = len, a = 0.002, d = len * 0.4, s = 0.35, r = len * 0.5, lp = {cut = 2400, to = 180, q = 0.8}, vol = 1},
    {wave = "noise", len = 0.15, a = 0.0005, d = 0.1, s = 0, r = 0.04, bp = {cut = 2000, to = 600, q = 0.7}, vol = 0.6}}
  for i = 1, 6 + math.floor(sz * 8) do   -- crackles
    layers[#layers + 1] = {wave = "noise", at = 0.05 + (i * 0.61803 % 1) * len * 0.6, len = 0.015, a = 0.0005, d = 0.012,
      s = 0, r = 0.002, hp = {cut = 2500}, vol = 0.25}
  end
  return {layers = layers, drive = 0.45, room = {size = 0.7, mix = 0.2}, tail = 0.8}
end

-- a power-up: rising arpeggio with shimmer
function R.powerup(o)
  o = o or {}
  local root = S.midi(o.root or "C5")
  local layers = {}
  for i, st in ipairs({0, 4, 7, 12, 16}) do
    layers[#layers + 1] = {wave = "triangle", freq = S.note(root + st), at = (i - 1) * 0.06, len = 0.16, a = 0.002, d = 0.1,
      s = 0.3, r = 0.05, vol = 0.7, vib = {rate = 7, depth = 0.08}}
    layers[#layers + 1] = {wave = "sine", freq = S.note(root + st + 12), at = (i - 1) * 0.06, len = 0.12, a = 0.002,
      d = 0.08, s = 0.2, r = 0.04, vol = 0.25}
  end
  return {layers = layers, echo = {time = 0.11, feedback = 0.3, mix = 0.25}}
end

-- getting hurt: a dull hit plus a falling, slightly detuned tone
function R.hurt(o)
  o = o or {}
  local p = o.pitch or 1
  return {layers = {
    {wave = "saw", freq = 420 * p, to = 160 * p, len = 0.25, a = 0.002, d = 0.15, s = 0.3, r = 0.08, unison = 2, cents = 30,
      lp = {cut = 1800, to = 500}, vol = 0.55},
    {wave = "noise", len = 0.07, a = 0.001, d = 0.05, s = 0, r = 0.015, bp = {cut = 900, q = 0.8}, vol = 0.6},
    {wave = "sine", freq = 120, to = 60, len = 0.14, a = 0.001, d = 0.1, s = 0, r = 0.03, vol = 0.7}},
    drive = 0.2}
end

-- a whoosh (swing, dash): band-passed noise sweeping up then down; length in seconds
function R.whoosh(o)
  o = o or {}
  local len = o.length or 0.3
  return {layers = {
    {wave = "pink", len = len, a = len * 0.45, d = len * 0.3, s = 0.3, r = len * 0.25,
      bp = {cut = 500 * (o.pitch or 1), to = 2600 * (o.pitch or 1), q = 1.6}, vol = 1}}}
end

-- footsteps on a surface: "grass", "stone", "wood", "snow", "metal"
function R.footstep(o)
  o = o or {}
  local sfc = o.surface or "stone"
  if sfc == "grass" then
    return {layers = {
      {wave = "noise", len = 0.09, a = 0.004, d = 0.06, s = 0, r = 0.02, hp = {cut = 1800}, lp = {cut = 6000}, vol = 0.6},
      {wave = "brown", len = 0.06, a = 0.002, d = 0.04, s = 0, r = 0.01, lp = {cut = 300}, vol = 0.5}}}
  elseif sfc == "wood" then
    return {layers = {
      {wave = "sine", freq = 210, to = 170, len = 0.09, a = 0.001, d = 0.06, s = 0, r = 0.02, vol = 0.8},
      {wave = "noise", len = 0.03, a = 0.0005, d = 0.02, s = 0, r = 0.005, bp = {cut = 1400, q = 2}, vol = 0.5}}}
  elseif sfc == "snow" then
    local layers = {}
    for i = 1, 5 do
      layers[#layers + 1] = {wave = "noise", at = (i - 1) * 0.018, len = 0.03, a = 0.002, d = 0.02, s = 0, r = 0.005,
        bp = {cut = 2500 + i * 300, q = 1.2}, vol = 0.45}
    end
    return {layers = layers}
  elseif sfc == "metal" then
    return {layers = {
      {wave = "noise", len = 0.02, a = 0.0005, d = 0.015, s = 0, r = 0.004, hp = {cut = 2000}, vol = 0.5},
      {wave = "sine", freq = 1180, len = 0.25, a = 0.001, d = 0.2, s = 0, r = 0.04, vol = 0.2, fm = {ratio = 1.41, index = 1.5, to = 0.2}},
      {wave = "sine", freq = 260, to = 220, len = 0.08, a = 0.001, d = 0.05, s = 0, r = 0.02, vol = 0.6}}}
  end
  return {layers = {   -- stone
    {wave = "noise", len = 0.05, a = 0.001, d = 0.035, s = 0, r = 0.01, bp = {cut = 2200, q = 1.1}, vol = 0.6},
    {wave = "sine", freq = 140, to = 90, len = 0.07, a = 0.001, d = 0.05, s = 0, r = 0.015, vol = 0.7}}}
end

-- a short jingle from notes (win, lose, level up): notes = {"C5", "E5", "G5"}, step in seconds
function R.jingle(o)
  o = o or {}
  local notes = o.notes or {"C5", "E5", "G5", "C6"}
  local stp = o.step or 0.1
  local layers = {}
  for i, n in ipairs(notes) do
    local last = i == #notes
    local f = S.note(n)
    layers[#layers + 1] = {wave = o.wave or "triangle", freq = f, at = (i - 1) * stp, len = last and 0.6 or stp * 1.6,
      a = 0.003, d = 0.1, s = 0.45, r = last and 0.35 or 0.06, vol = 0.7, vib = last and {rate = 5.5, depth = 0.12} or nil}
    layers[#layers + 1] = {wave = "sine", freq = f * 2, at = (i - 1) * stp, len = stp * 1.2, a = 0.003, d = 0.06, s = 0.1,
      r = 0.04, vol = 0.18}
  end
  return {layers = layers, echo = {time = stp * 1.5, feedback = 0.25, mix = 0.2}, room = {size = 0.5, mix = 0.15}}
end

-- random details for ambience: "bird", "drip", "crackle", "cricket", "creak"
function R.detail(o)
  o = o or {}
  local k = o.kind or "drip"
  if k == "bird" then
    local f = o.pitch and 2800 * o.pitch or 2800
    return {layers = {
      {wave = "sine", freq = f, to = f * 1.5, glide = 0.06, len = 0.08, a = 0.004, d = 0.05, s = 0.3, r = 0.02, vol = 0.6},
      {wave = "sine", freq = f * 1.2, to = f * 0.9, at = 0.1, len = 0.1, a = 0.004, d = 0.06, s = 0.3, r = 0.03, vol = 0.5,
        vib = {rate = 28, depth = 1.2}}},
      room = {size = 0.6, mix = 0.25}}
  elseif k == "crackle" then
    local layers = {}
    for i = 1, 4 do
      layers[#layers + 1] = {wave = "noise", at = (i * 0.37 % 1) * 0.12, len = 0.008, a = 0.0003, d = 0.006, s = 0, r = 0.001,
        hp = {cut = 2000 + i * 500}, vol = 0.6}
    end
    return {layers = layers}
  elseif k == "cricket" then
    local layers = {}
    for i = 1, 3 do
      layers[#layers + 1] = {wave = "sine", freq = 4300, at = (i - 1) * 0.07, len = 0.05, a = 0.005, d = 0.03, s = 0.5, r = 0.01,
        trem = {rate = 90, depth = 1}, vol = 0.4}
    end
    return {layers = layers}
  elseif k == "creak" then
    return {layers = {
      {wave = "saw", freq = 95, to = 70, len = 0.45, a = 0.08, d = 0.2, s = 0.5, r = 0.1, trem = {rate = 32, depth = 0.8},
        bp = {cut = 700, q = 3}, vol = 0.6}}}
  end
  return {layers = {   -- drip
    {wave = "sine", freq = 700, to = 1700, glide = 0.03, len = 0.07, a = 0.001, d = 0.05, s = 0, r = 0.015, vol = 0.7}},
    echo = {time = 0.13, feedback = 0.45, mix = 0.35}, room = {size = 0.8, mix = 0.3}}
end

-- a seamless ambience bed: kind = "wind", "rain", "night", "cave", "ocean", "hum", "fire"; length in seconds
function R.ambience(o)
  o = o or {}
  local k = o.kind or "wind"
  local len = o.length or 8
  local L = {}
  if k == "wind" then
    L = {{wave = "brown", len = len + 1, a = 0.5, d = 0.1, s = 1, r = 0.5, bp = {cut = 380, q = 1.3, lfo = {rate = 2 / len, depth = 1.1}}, vol = 1},
      {wave = "pink", len = len + 1, a = 0.5, d = 0.1, s = 1, r = 0.5, bp = {cut = 1600, q = 6, lfo = {rate = 3 / len, depth = 0.6}},
        trem = {rate = 1 / len, depth = 0.7}, vol = 0.25}}
  elseif k == "rain" then
    L = {{wave = "pink", len = len + 1, a = 0.3, d = 0.1, s = 1, r = 0.3, hp = {cut = 1200}, lp = {cut = 7000}, vol = 0.8},
      {wave = "brown", len = len + 1, a = 0.3, d = 0.1, s = 1, r = 0.3, lp = {cut = 400}, vol = 0.5}}
    for i = 1, math.floor(len * 14) do
      L[#L + 1] = {wave = "sine", freq = 2500 + (i * 977 % 2500), at = (i * 0.618034 % 1) * len, len = 0.012, a = 0.0005,
        d = 0.009, s = 0, r = 0.002, vol = 0.12}
    end
  elseif k == "night" then
    L = {{wave = "pink", len = len + 1, a = 0.5, d = 0.1, s = 1, r = 0.5, lp = {cut = 500}, vol = 0.5}}
    for i = 0, math.floor(len / 0.9) - 1 do
      for j = 0, 2 do
        L[#L + 1] = {wave = "sine", freq = 4300, at = i * 0.9 + j * 0.07, len = 0.05, a = 0.005, d = 0.03, s = 0.5, r = 0.01,
          trem = {rate = 90, depth = 1}, vol = 0.12}
      end
    end
  elseif k == "cave" then
    L = {{wave = "brown", len = len + 1, a = 0.5, d = 0.1, s = 1, r = 0.5, lp = {cut = 220, lfo = {rate = 1 / len, depth = 0.5}}, vol = 1},
      {wave = "sine", freq = 55, len = len + 1, a = 0.5, d = 0.1, s = 1, r = 0.5, trem = {rate = 2 / len, depth = 0.6}, vol = 0.25}}
  elseif k == "ocean" then
    L = {{wave = "pink", len = len + 1, a = 0.5, d = 0.1, s = 1, r = 0.5, lp = {cut = 700, lfo = {rate = 2 / len, depth = 1.2}},
      trem = {rate = 2 / len, depth = 0.8}, vol = 1},
      {wave = "brown", len = len + 1, a = 0.5, d = 0.1, s = 1, r = 0.5, lp = {cut = 250}, vol = 0.6}}
  elseif k == "fire" then
    L = {{wave = "brown", len = len + 1, a = 0.3, d = 0.1, s = 1, r = 0.3, lp = {cut = 900}, trem = {rate = 3 / len, depth = 0.4}, vol = 0.9}}
    for i = 1, math.floor(len * 6) do
      L[#L + 1] = {wave = "noise", at = (i * 0.618034 % 1) * len, len = 0.01, a = 0.0003, d = 0.008, s = 0, r = 0.001,
        hp = {cut = 1800 + (i * 331 % 2000)}, vol = 0.35}
    end
  else -- hum: a machine room
    L = {{wave = "saw", freq = 55, len = len + 1, a = 0.5, d = 0.1, s = 1, r = 0.5, lp = {cut = 260}, vol = 0.5, unison = 2, cents = 6},
      {wave = "sine", freq = 110, len = len + 1, a = 0.5, d = 0.1, s = 1, r = 0.5, trem = {rate = 4 / len, depth = 0.4}, vol = 0.3},
      {wave = "noise", len = len + 1, a = 0.5, d = 0.1, s = 1, r = 0.5, hp = {cut = 5000}, vol = 0.04}}
  end
  return {layers = L, len = len, loop = true, crossfade = 1.0, peak = -3}
end

-- ------------------------------------------------------------------ music
local SCALES = {
  major = {0, 2, 4, 5, 7, 9, 11}, minor = {0, 2, 3, 5, 7, 8, 10}, dorian = {0, 2, 3, 5, 7, 9, 10},
  phrygian = {0, 1, 3, 5, 7, 8, 10}, lydian = {0, 2, 4, 6, 7, 9, 11}, mixolydian = {0, 2, 4, 5, 7, 9, 10},
  harmonic = {0, 2, 3, 5, 7, 8, 11}, pentatonic = {0, 3, 5, 7, 10}}
S.scales = SCALES

-- song{bpm, root ("A2"), scale, chords = {1, 6, 3, 7} (scale degrees, one per bar), bars (repeats the chords),
--      pad, bass ("pulse" | "walk" | "simple" | false), arp ("up" | "updown" | "random" | false), arpRate (8 | 16),
--      drums ("soft" | "drive" | "half" | false), sevenths, seed}
function R.song(o)
  o = o or {}
  local bpm = o.bpm or 100
  local beat = 60 / bpm
  local bar = beat * 4
  local root = S.midi(o.root or "A2")
  local sc = SCALES[o.scale or "minor"] or SCALES.minor
  local chords = o.chords or {1, 6, 3, 7}
  local nb = o.bars or #chords
  local seed = o.seed or 7
  local function deg(dg, oct)
    local i = dg - 1
    return root + sc[i % #sc + 1] + 12 * (math.floor(i / #sc) + oct)
  end
  local function hz(m) return 440 * 2 ^ ((m - 69) / 12) end
  local L = {}
  local prev = nil
  local arpMode = o.arp == nil and "up" or o.arp
  local bassMode = o.bass == nil and "pulse" or o.bass
  local drums = o.drums == nil and "soft" or o.drums
  local rs = seed
  local function r01()
    rs = (rs * 1103515245 + 12345) & 0x7fffffff
    return rs / 2147483648
  end
  for b = 1, nb do
    local dg = chords[(b - 1) % #chords + 1]
    local t0 = (b - 1) * bar
    local tones = {deg(dg, 1), deg(dg + 2, 1), deg(dg + 4, 1)}
    if o.sevenths then tones[4] = deg(dg + 6, 1) end
    -- voice leading: move each tone by octaves to stay close to the previous chord (smooth pads)
    if prev then
      for i, m in ipairs(tones) do
        local best, bd = m, 99
        for _, cand in ipairs({m - 12, m, m + 12}) do
          for _, pm in ipairs(prev) do
            local dd = math.abs(cand - pm)
            if dd < bd then best, bd = cand, dd end
          end
        end
        tones[i] = best
      end
    end
    prev = tones
    if o.pad ~= false then
      for _, m in ipairs(tones) do
        L[#L + 1] = {stem = "pad", wave = "saw", unison = 3, cents = 14, freq = hz(m), at = t0, len = bar + 0.5,
          a = math.min(0.35, bar * 0.2), d = 0.4, s = 0.75, r = 0.5, lp = {cut = 900, to = 1500, q = 0.6}, vol = 0.22}
      end
    end
    if bassMode then
      local bm = deg(dg, 0)
      local hits
      if bassMode == "pulse" then hits = {0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5}
      elseif bassMode == "walk" then hits = {0, 1, 2, 3}
      else hits = {0, 2, 3.5} end
      for i, hb in ipairs(hits) do
        local m = bm
        if bassMode == "walk" and i == 4 then m = deg(dg + 4, 0) end
        if bassMode == "simple" and i == 3 then m = deg(dg + 4, 0) end
        local acc = (hb % 1 == 0) and 1 or 0.7
        L[#L + 1] = {stem = "bass", wave = "triangle", freq = hz(m), at = t0 + hb * beat, len = beat * (bassMode == "pulse" and 0.45 or 0.9),
          a = 0.004, d = 0.15, s = 0.5, r = 0.06, vol = 0.8 * acc}
        L[#L + 1] = {stem = "bass", wave = "saw", freq = hz(m), at = t0 + hb * beat, len = beat * 0.3, a = 0.003, d = 0.08,
          s = 0.2, r = 0.04, lp = {cut = 900, to = 300}, vol = 0.25 * acc}
      end
    end
    if arpMode then
      local rate = o.arpRate or 8
      local stp = bar / rate
      local seq = {tones[1], tones[2], tones[3], tones[1] + 12, tones[2] + 12}
      for i = 0, rate - 1 do
        local m
        if arpMode == "random" then m = seq[math.floor(r01() * #seq) + 1]
        elseif arpMode == "updown" then
          local cyc = #seq * 2 - 2
          local k = i % cyc
          m = seq[k < #seq and k + 1 or cyc - k + 1]
        else m = seq[i % #seq + 1] end
        L[#L + 1] = {stem = "arp", wave = "square", duty = 0.25, freq = hz(m + 12), at = t0 + i * stp, len = stp * 0.9,
          a = 0.002, d = stp * 0.5, s = 0.15, r = 0.04, lp = {cut = 2800, to = 1400}, vol = 0.32 * (i % 2 == 0 and 1 or 0.75)}
      end
    end
    if drums then
      local kick, snare, hat = {}, {}, {}
      if drums == "drive" then kick = {0, 1, 2, 3}; snare = {1, 3}; hat = {0.5, 1.5, 2.5, 3.5, 0, 1, 2, 3}
      elseif drums == "half" then kick = {0, 2.5}; snare = {2}; hat = {0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5}
      else kick = {0, 2}; snare = {1, 3}; hat = {0.5, 1.5, 2.5, 3.5} end
      for _, hb in ipairs(kick) do
        L[#L + 1] = {stem = "drums", wave = "sine", freq = 150, to = 45, glide = 0.08, at = t0 + hb * beat, len = 0.3, a = 0.001,
          d = 0.2, s = 0, r = 0.06, vol = 1}
        L[#L + 1] = {stem = "drums", wave = "noise", at = t0 + hb * beat, len = 0.008, a = 0.0003, d = 0.006, s = 0, r = 0.001,
          hp = {cut = 2500}, vol = 0.25}
      end
      for _, hb in ipairs(snare) do
        L[#L + 1] = {stem = "drums", wave = "noise", at = t0 + hb * beat, len = 0.2, a = 0.001, d = 0.12, s = 0, r = 0.05,
          bp = {cut = 1900, q = 0.8}, vol = drums == "soft" and 0.35 or 0.6}
        L[#L + 1] = {stem = "drums", wave = "triangle", freq = 200, to = 160, at = t0 + hb * beat, len = 0.1, a = 0.001,
          d = 0.07, s = 0, r = 0.02, vol = 0.4}
      end
      for i, hb in ipairs(hat) do
        L[#L + 1] = {stem = "drums", wave = "noise", at = t0 + hb * beat, len = 0.04, a = 0.0005, d = 0.025, s = 0, r = 0.008,
          hp = {cut = 7500}, vol = (0.16 + 0.08 * ((i * 7) % 3) / 2)}
      end
    end
  end
  return {layers = L, len = nb * bar, bar = bar, bars = nb, loop = true, tail = 1.0, peak = -1,
    stems = {pad = {gain = o.padGain or -2}, bass = {gain = o.bassGain or 0},
      arp = {gain = o.arpGain or -5, echo = {time = beat * 0.75, feedback = 0.35, mix = 0.35}},
      drums = {gain = o.drumsGain or -3}},
    room = {size = 0.6, mix = 0.16}}
end

return S
