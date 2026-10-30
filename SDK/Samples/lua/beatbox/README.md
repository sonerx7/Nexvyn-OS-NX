# Beatbox Demo

**English** · [Türkçe](README.tr.md)

A 16-step drum machine: six synthesised drums, tempo, swing, accents, mutes, preset beats and automatic saving.

| | |
|---|---|
| Id | `com.sonerx7.demo.beatbox` |
| Language | Lua 5.4 |
| Min SDK | 1.0 |
| Permissions | none |
| Gamepad | drives the cursor |
| Window | 900 × 560, resizable |

## What it teaches

- Drum synthesis from simple tones: kick = short high click + long low sine, snare = noise + body tone, clap = three noise bursts with `timer.after`
- A sequencer clock that does not drift: the next step time is advanced by exactly one step (`nextAt = nextAt + step`) instead of measured from "now"
- Swing: every second sixteenth plays a little late while each pair of steps keeps its length
- A `ui.hit` pad grid, row mutes, accents (off → on → accent), presets and saving with `store`
- Playhead, flashing pads and decaying level bars; sizes come from the window

**APIs used:** `audio.tone` (sine, triangle, noise), `timer.after`, `sys.time`, `ui.hit/button/dropdown/slider`, `store`

**Controls:** Tap a pad: on → accent → off · tap an instrument name: mute · Space: play/stop · 1-6: mute a row.

## Code excerpt

A drift-free clock with swing: a long gap after an odd step, a short one after an even step; each pair is always two steps long.

```lua
function app.update(dt)
  if not playing then return end
  local now = sys.time()
  if now - nextAt > 0.5 then nextAt = now end      -- after a long pause: skip, do not burst
  while now >= nextAt do
    step = step % STEPS + 1
    playStep(step)
    local len = 60 / bpm / 4                       -- one sixteenth note
    if step % 2 == 1 then nextAt = nextAt + len * (1 + swing)
    else nextAt = nextAt + len * (1 - swing) end
  end
end
```

## Running it

Copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `BeatboxDemo.nxvapp`, or pack it into one file with `python tools/nxvapp_pack.py`. Files: `main.lua` (262 lines), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/beatbox/source --frames 900

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
