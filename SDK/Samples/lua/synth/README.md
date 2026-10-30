# Synth Demo

**English** · [Türkçe](README.tr.md)

An on-screen piano (2-3 octaves), four waveforms, an ADSR envelope made with timers, chords and strumming, an envelope graph and a scope.

| | |
|---|---|
| Id | `com.sonerx7.demo.synth` |
| Language | Lua 5.4 |
| Min SDK | 1.0 |
| Permissions | none |
| Gamepad | drives the cursor |
| Window | 900 × 640, resizable |

## What it teaches

- `audio.tone(freq, seconds, volume, wave)` and note frequencies: f = 440 · 2^((n − 69) / 12)
- ADSR with `timer.every`: `audio.tone`'s volume is fixed when it starts, so a held note plays as short overlapping "grains" at the envelope's current level
- Strummed chords with `timer.after` (each note a few milliseconds after the previous one)
- Polyphony with a voice list, and glides across keys (mousedown / mousemove / mouseup)
- Drawing data: the envelope curve, where each voice is on it, and an oscilloscope with `gfx.lines`

**APIs used:** `audio.tone`, `timer.every/after`, `ui.segmented/slider/checkbox/button/group`, `gfx.lines/circle/rect`, `store`

**Controls:** Touch / click / drag: play · A W S E D F T G Y H U J K O L: piano keys · Z / X: octave · Esc: stop all notes.

Note: the envelope moves in 50 ms steps; because grains overlap the sound can be slightly "grainy". It is the closest approximation possible with `audio.tone`, whose volume cannot change while it plays.

## Code excerpt

The envelope clock: 20 times a second every voice advances and plays one grain at the envelope's current level.

```lua
local function level(v)
  if v.held then
    if v.t < set.a then return v.t / max(set.a, 0.001) end                   -- attack
    local dt = v.t - set.a
    if dt < set.d then return 1 - (1 - set.s) * dt / max(set.d, 0.001) end  -- decay
    return set.s                                                             -- sustain
  end
  return v.relFrom * max(0, 1 - v.relT / max(set.r, 0.001))                  -- release
end
local function playGrain(v)
  local l = level(v)
  if l > 0.005 then audio.tone(v.freq, GRAIN_LEN, l * l * set.vol, WAVES[set.wave]) end
end
timer.every(GRAIN, tick)   -- tick() advances every voice and calls playGrain
```

## Running it

Copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `SynthDemo.nxvapp`, or pack it into one file with `python tools/nxvapp_pack.py`. Files: `main.lua` (345 lines), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/synth/source --frames 900

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
