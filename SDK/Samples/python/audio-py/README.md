# Melody Player (Python)

**English** · [Türkçe](README.tr.md)

A note-by-note melody player in Python: piano roll, tempo, waveform, loop, writing your own melody and a live log that shows when each callback runs.

| | |
|---|---|
| Id | `com.sonerx7.demo.audio-py` |
| Language | Python (pocketpy) |
| Min SDK | 1.3 |
| Permissions | none |
| Gamepad | drives the cursor |
| Window | 900 × 560, resizable |

## What it teaches

- `timer.after(seconds, fn)` chains: every note schedules the next one; `timer.cancel(id)` stops the chain
- Bound methods, lambdas and nested functions as callbacks (no async/await in the console's Python)
- Typing a melody with `ui.prompt(..., callback)`, and `ui.alert(..., callback)` on bad input (button index starts at 0)
- A log that shows callbacks always run on a later frame
- A piano roll from the note list and a smooth playhead between callbacks with `update` + `sys.time`
- `import` of another `.py` file (melody.py) and pocketpy limits (no `re`: a hand-written parser)

**APIs used:** `timer.after/cancel`, `audio.tone` (anahtar kelimelerle / with keywords), `ui.prompt/alert/dropdown/segmented/slider/checkbox/button/group`, `gfx.clip/rect/line/text`, `store`

**Controls:** Space: play/stop · E: write your own melody (e.g. `C4 E4 G4:2 R:0.5 F#4:0.5`).

## Code excerpt

One link of the chain: play the note, schedule the next one with `timer.after` and keep its id so `stop()` can cancel it.

```python
def next_note(self):
    self.pending = None
    self.index += 1
    if self.index >= len(self.notes):
        ...                                   # end, or start again when looping
    midi, beats = self.notes[self.index]
    seconds = beats * 60.0 / self.bpm
    if midi is not None:
        audio.tone(melody.freq(midi), sec=seconds * 0.92, volume=0.45, wave=WAVES[self.wave])
    self.note_at = sys.time()
    self.pending = timer.after(seconds, self.next_note)   # a bound method is a fine callback

def stop(self):
    if self.pending is not None:
        timer.cancel(self.pending)            # the scheduled callback never runs
```

## Running it

Copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `MelodyPlayerPython.nxvapp`, or pack it into one file with `python tools/nxvapp_pack.py`. Files: `main.py` (302 lines), `melody.py` (53 lines), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/py_check.py <Nexvyn-OS-NX>/SDK/Samples/python/audio-py/source --frames 900

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
