-- synth.lua: Chiptrack's offline renderer. Turns a song into 16-bit mono PCM (22050 Hz) with real envelopes,
-- effects (arpeggio, slides, vibrato, note cut, tempo) and drum voices, a slice at a time so the window keeps
-- drawing. Also writes WAV files.
local S = {}
local floor, min, max, sin, pi = math.floor, math.min, math.max, math.sin, math.pi

S.RATE = 22050
S.TICKS = 6
S.CH = 4

local SINE = {}
for i = 0, 255 do SINE[i] = sin(i / 256 * 2 * pi) end

function S.freq(n) return 440 * 2 ^ ((n - 69) / 12) end

-- an envelope level at time t (seconds since note on) and since release
local function envLevel(ins, t, relT, relFrom)
  local a, d, s = ins.a or 0.005, ins.d or 0.1, ins.s or 0.7
  local lvl
  if t < a then lvl = t / max(a, 1e-4)
  elseif t < a + d then lvl = 1 - (1 - s) * (t - a) / max(d, 1e-4)
  else lvl = s end
  if relT then
    local r = max(ins.r or 0.08, 1e-3)
    lvl = (relFrom or lvl) * max(0, 1 - relT / r)
  end
  return lvl
end
S.envLevel = envLevel

-- one voice: renders n samples into buf (adding) starting at index o
local function renderVoice(v, buf, o, n)
  local ins = v.ins
  local wave = ins.wave or "square"
  local rate = S.RATE
  local vol = (ins.vol or 0.6) * v.vol
  local ph = v.ph
  local inc = v.f / rate
  local seed = v.seed
  local nz = v.nz or 0
  local i = 0
  while i < n do
    local blk = min(32, n - i)
    local lvl
    if wave == "kick" or wave == "snare" or wave == "hat" then
      local dec = wave == "kick" and 0.22 or (wave == "snare" and 0.16 or 0.05)
      lvl = max(0, 1 - v.t / dec)
      lvl = lvl * lvl
      if v.relT then lvl = lvl * max(0, 1 - v.relT / 0.02) end
    else
      lvl = envLevel(ins, v.t, v.relT, v.relFrom)
    end
    local amp = lvl * vol
    if amp <= 0.0005 and (v.relT or v.t > 0.5) then
      if v.relT then v.dead = true end
    end
    for k = o + i, o + i + blk - 1 do
      local s
      if wave == "square" then s = ph < 0.5 and 0.55 or -0.55
      elseif wave == "pulse" then s = ph < 0.25 and 0.55 or -0.55
      elseif wave == "saw" then s = (2 * ph - 1) * 0.55
      elseif wave == "triangle" then s = (ph < 0.5 and (4 * ph - 1) or (3 - 4 * ph)) * 0.8
      elseif wave == "sine" then s = SINE[floor(ph * 256) % 256] * 0.8
      elseif wave == "noise" then s = nz * 0.5
      elseif wave == "kick" then
        local f = 45 + 110 * max(0, 1 - v.t / 0.08)
        inc = f / rate
        s = SINE[floor(ph * 256) % 256] * 1.1
      elseif wave == "snare" then
        seed = (seed * 1103515245 + 12345) % 2147483648
        s = ((seed / 1073741824) - 1) * 0.6 + (ph < 0.5 and (4 * ph - 1) or (3 - 4 * ph)) * 0.35 * max(0, 1 - v.t / 0.05)
        inc = 190 / rate
      elseif wave == "hat" then
        seed = (seed * 1103515245 + 12345) % 2147483648
        local r = (seed / 1073741824) - 1
        s = (r - nz) * 0.45
        nz = r
      else s = 0 end
      buf[k] = buf[k] + s * amp
      ph = ph + inc
      if ph >= 1 then
        ph = ph - floor(ph)
        if wave == "noise" then
          seed = (seed * 1103515245 + 12345) % 2147483648
          nz = (seed / 1073741824) - 1
        end
      end
    end
    v.t = v.t + blk / rate
    if v.relT then v.relT = v.relT + blk / rate end
    i = i + blk
  end
  v.ph, v.seed, v.nz = ph, seed, nz
end

-- the rows to play: list of {pattern, row}
function S.rowsOf(song, mode, pat)
  local out = {}
  if mode == "pattern" then
    local p = song.patterns[pat]
    for r = 1, p.rows do out[#out + 1] = {pat, r} end
  else
    for _, pi_ in ipairs(song.order) do
      local p = song.patterns[pi_]
      if p then for r = 1, p.rows do out[#out + 1] = {pi_, r} end end
    end
  end
  return out
end

-- a coroutine that renders the rows and finally returns the PCM samples (floats in a table)
function S.job(song, rows, mutes, loops)
  return coroutine.create(function()
    local rate = S.RATE
    local bpm = song.bpm or 120
    local lpb = song.lpb or 4
    local buf = {}
    local pos = 1
    local voices = {}
    local fx = {}
    for c = 1, S.CH do fx[c] = {} end
    local seedBase = 22222
    local total = #rows * (loops or 1)
    local done = 0
    for _ = 1, loops or 1 do
      for _, rr in ipairs(rows) do
        local p = song.patterns[rr[1]]
        local row = rr[2]
        local rowSec = 60 / (bpm * lpb)
        -- events of this row
        for c = 1, S.CH do
          local cell = p.cells[(row - 1) * S.CH + c]
          local F = fx[c]
          F.kind, F.p = nil, 0
          if type(cell) == "table" then
            local n, ii, vv, ef, ep = cell[1] or 0, cell[2] or 0, cell[3] or -1, cell[4] or 0, cell[5] or 0
            if ef == 6 and ep >= 32 then bpm = ep; rowSec = 60 / (bpm * lpb) end
            if n == -1 then
              local v = voices[c]
              if v and not v.relT then v.relFrom = envLevel(v.ins, v.t); v.relT = 0 end
            elseif n > 0 then
              local ins = song.instruments[ii > 0 and ii or (voices[c] and voices[c].insIdx or 1)] or song.instruments[1]
              local old = voices[c]
              seedBase = seedBase + 7919
              voices[c] = {ins = ins, insIdx = ii > 0 and ii or (old and old.insIdx or 1), note = n, base = n,
                           f = S.freq(n), ph = 0, t = 0, vol = vv >= 0 and vv / 64 or 1, seed = seedBase, nz = 0}
            elseif vv >= 0 and voices[c] then
              voices[c].vol = vv / 64
            end
            if n > 0 and vv >= 0 and voices[c] then voices[c].vol = vv / 64 end
            if ef > 0 and ef ~= 6 then F.kind, F.p = ef, ep end
          end
        end
        -- synthesize the row tick by tick (effects change per tick)
        local rowSamples = floor(rowSec * rate + 0.5)
        local tickSamples = floor(rowSamples / S.TICKS)
        for k = pos, pos + rowSamples - 1 do buf[k] = 0 end
        for c = 1, S.CH do
          local v = voices[c]
          if v and not v.dead and not (mutes and mutes[c]) then
            local F = fx[c]
            for t = 0, S.TICKS - 1 do
              local n = (t == S.TICKS - 1) and (rowSamples - tickSamples * (S.TICKS - 1)) or tickSamples
              if F.kind == 1 then           -- arpeggio: base, +x, +y semitones
                local x, y = floor(F.p / 16), F.p % 16
                local off = (t % 3 == 0) and 0 or ((t % 3 == 1) and x or y)
                v.f = S.freq(v.base + off)
              elseif F.kind == 2 then       -- slide up (1/16 semitone per tick per unit)
                v.note = v.note + F.p / 16
                v.f = S.freq(v.note)
              elseif F.kind == 3 then       -- slide down
                v.note = v.note - F.p / 16
                v.f = S.freq(v.note)
              elseif F.kind == 4 then       -- vibrato: x speed, y depth (1/8 semitones)
                local sp, dp = max(1, floor(F.p / 16)), F.p % 16
                v.vph = (v.vph or 0) + sp * 0.06
                v.f = S.freq(v.note + math.sin(v.vph * 2 * pi) * dp / 8)
              elseif F.kind == 5 and t == (F.p % 16) and not v.relT then   -- cut after x ticks
                v.relFrom = envLevel(v.ins, v.t); v.relT = 0
              elseif F.kind == nil and v.base and v.note == v.base then
                v.f = S.freq(v.note)
              end
              renderVoice(v, buf, pos, n)
              pos = pos + n
            end
            pos = pos - rowSamples
            if v.dead then voices[c] = nil end
          elseif v then
            -- muted or silent voices still age
            v.t = v.t + rowSec
            if v.relT then v.relT = v.relT + rowSec; if v.relT > (v.ins.r or 0.1) then voices[c] = nil end end
          end
        end
        pos = pos + rowSamples
        done = done + 1
        coroutine.yield(done / total)
      end
    end
    -- release tail
    local tail = floor(rate * 0.4)
    for k = pos, pos + tail - 1 do buf[k] = 0 end
    for c = 1, S.CH do
      local v = voices[c]
      if v and not (mutes and mutes[c]) then
        if not v.relT then v.relFrom = envLevel(v.ins, v.t); v.relT = 0 end
        renderVoice(v, buf, pos, tail)
      end
    end
    return buf
  end)
end

-- 16-bit little-endian mono WAV from float samples (soft-clipped)
function S.wav(buf)
  local n = #buf
  local parts = {}
  local chunk = {}
  local CH = 512
  local fmt = "<" .. string.rep("i2", CH)
  local peak = 0
  for i = 1, n do local a = buf[i]; if a < 0 then a = -a end; if a > peak then peak = a end end
  local gain = peak > 0.95 and 0.95 / peak or 1
  local j = 0
  for i = 1, n do
    local s = buf[i] * gain
    if s > 1 then s = 1 elseif s < -1 then s = -1 end
    j = j + 1
    chunk[j] = floor(s * 32000)
    if j == CH then
      parts[#parts + 1] = string.pack(fmt, table.unpack(chunk, 1, CH))
      j = 0
    end
  end
  if j > 0 then parts[#parts + 1] = string.pack("<" .. string.rep("i2", j), table.unpack(chunk, 1, j)) end
  local data = table.concat(parts)
  local header = "RIFF" .. string.pack("<I4", 36 + #data) .. "WAVE" .. "fmt " ..
                 string.pack("<I4I2I2I4I4I2I2", 16, 1, 1, S.RATE, S.RATE * 2, 2, 16) .. "data" .. string.pack("<I4", #data)
  return header .. data
end

return S
