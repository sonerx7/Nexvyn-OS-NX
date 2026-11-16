# Game Engine sound (Sound 2.0)

Everything on this page is made on the device from small recipes and a seed. No sample files are needed and nothing is
downloaded. The code is pure and deterministic: the same recipe (or genre) and the same seed always give the same
samples.

| Part | Files |
|---|---|
| Recipe synthesizer, effects (C++ twin of the Python kit) | `source/core/ge_audio.{h,cpp}`, generated `source/core/ge_audio_recipes.inc` |
| Music composer | `source/core/ge_audio_music.cpp` |
| Bus mixer model | `source/core/ge_audio_mixer.cpp` |
| Runtime host for the mixer | `source/core/ge_audio_rt.{h,cpp}` |
| Editor tab "Sound Lab" | `source/apps/ge_sound_panel.{h,cpp}` (one `case` in `app_gamemaker.cpp`) |
| Python reference and recipe source | `tools/gen_sfx.py`, `tools/gen_ge_audio_recipes.py` |
| Tests | `tests/test_geaudio.cpp`, `tests/test_ge_audio_parity.py` |

## Recipes

A recipe is one or more synth parts mixed at time offsets, plus optional echo and reverb:

- Oscillator: square (duty and duty sweep), saw, sine, triangle, seeded noise.
- Envelope: attack, sustain (with `pu`, a punch that starts above the sustain level and settles) and decay.
- Pitch: start frequency, slide and slide acceleration, vibrato, one arpeggio step, a repeat period.
- Filters: one-pole low-pass (sweepable and wobbling) and high-pass; with `q` the low-pass becomes a two-pole resonant
  filter; `bp` is a resonant band-pass (sweepable).
- Modulation and colour: tremolo (`tr`, `trs`), bit-crusher (`bits`) and sample-and-hold (`ds`).
- Effects of the whole recipe: echo (delay, feedback, mix), a Schroeder reverb (mix, size), loop cross-fade with the
  effect tail folded into the start, peak normalisation to 0.85 x gain.

There are 105 recipes in 17 categories: the 67 of the built-in library and 38 new ones (weapons, magic, footstep
surfaces, water, cave drone, wind howl, thunder, whooshes, bell, alarm, jingles and more). Loop recipes repeat without a
click. `vary(recipe, seed, amount)` changes pitch, slide, vibrato, length, filters and duty by a seeded amount, which is
what Randomize in the editor uses.

### Parity with `gen_sfx.py`

The C++ code follows `tools/gen_sfx.py` operation by operation in double precision. `tests/test_ge_audio_parity.py`
renders every recipe twice (own seed, and varied with seed 12345 / amount 0.3) with both implementations and compares the
16-bit WAV data. Accepted difference: at most 2 LSB per sample and equal lengths; the two sides may call different
`sin`, `pow` and `exp` implementations, which can differ in the last bit of a double before the integer conversion. On
the development machine all 210 renders (3.3 million samples) are bit-exact. The test also checks that
`ge_audio_recipes.inc` is current. The recipe table is generated: edit `gen_sfx.py` (`CATALOG`, `EXTRA`), then run
`python tools/gen_ge_audio_recipes.py`.

The 67 built-in effects in `romfs/System/Workshop/sfx` are unchanged byte for byte (the new parameters default to off).

## Composer

`compose({genre, seed, bpm, bars})` returns four stems that loop seamlessly: bass, harmony, rhythm and melody.

- 12 genres: chiptune, ambient, orchestral (lite), synthwave, horror drone, jazz (lite), lo-fi, battle, victory sting,
  menu loop, town, dungeon. Each one sets tempo, length, scale (major, minor, dorian, phrygian, lydian, mixolydian,
  harmonic minor), chord progression, bass pattern, drum pattern, harmony style (pad, arpeggio, stabs, strum, cluster),
  melody style, swing, reverb and the voices.
- The seed changes the melody (phrases repeat with small changes and end on the tonic) and the noise of the drums.
- Gapless loop: notes and the reverb wrap around the end of the buffer and the mean of each stem is removed, so the end
  runs straight into the start. The tests check that the step from the last sample to the first is no bigger than the
  steepest step inside the song.
- The four stems together peak at 0.85. `mixSong(song, mask, danger)` mixes them with a soft limit above 0.9, so the sum
  never exceeds 1.0.
- Adaptive music: `layerGain(layer, danger)` opens the layers one by one as the danger value rises from 0 to 1: bass
  always, harmony from 0.2, rhythm from 0.45, melody from 0.7 (each fades in over 0.2). In the editor all four stems play
  as synchronized looping voices and their volumes follow the Danger slider (smoothed over 20 ms), so there is no restart.
  Each layer can also be switched on and off by hand.

## Mixer

`ge_audio::Mixer` is a stereo float block mixer:

- Buses: master, music, sfx, ambience, ui, voice. Per-bus volume (0 to 2) and mute; per-voice volume, equal-power pan,
  pitch and loop. Sounds of any sample rate are resampled with linear interpolation.
- Ducking: while the voice bus plays, music and ambience go down by an amount (default 55 %) with a 40 ms attack and a
  450 ms release.
- A peak limiter (ceiling 0.95, instant attack, 60 ms release) keeps the output below full scale.
- 32 voices. When all are busy the oldest voice of the least important bus is taken (order: sfx, ambience, music, ui,
  voice).

`ge_audio_rt` hosts one mixer as a stream source of the OS mixer (`audio::addStreamSource`). The sounds do not use an
SDL_mixer channel, so the 24-channel limit of the system is untouched. The audio thread never waits for the main thread: it
drains a short command queue when it can take it without blocking. No SDK function was added; the runtime is internal to
the editor for now.

## Sound Lab tab

The Game Engine editor has a new tab, "Sound Lab", with three pages:

- Effects: category and recipe lists (the preview plays at once), sliders for pitch, length, slide, vibrato,
  brightness, tremolo, crunch, echo, reverb and variation, a waveform view, Randomize (new seed and variation), Play, Stop
  and Save. Save writes `sounds/<name>.wav` (mono 16-bit 24 kHz) in the project and adds the usual `{name, file}` entry to
  the project's sound list; no other project field is touched.
- Music: genre list, tempo and bar sliders, layer buttons, Adaptive switch with the Danger slider, Randomize, Play, Stop
  and Save (the mix of the chosen layers as a loopable WAV).
- Mixer: bus volume and mute, the duck amount, output and duck meters and a test voice that ducks the music.

Heavy work (rendering a recipe, composing a song) runs in `bgjob`; the main thread only draws and sends commands. The
log (`gesound` lines) records each render and each play.

## Tests

- `tests/test_geaudio.cpp` (22 cases): determinism for all recipes, peak <= 0.85 x gain, DC offset <= 0.35, seamless loop
  recipes, distinct output per recipe, seed and variation effects, envelope, filter, tremolo, crusher and hold numbers,
  WAV header, time budget (a 3 s recipe in well under 150 ms on the host; all 105 in about 120 ms), composer (12 genres,
  determinism, no clipping, DC, seam, every layer present, adaptive layers, 20 s song in about 60 ms), mixer (gain, pan,
  mute, resampling, ducking, limiter, voice limit and stealing, smoothing) and the runtime host.
- `tests/test_ge_audio_parity.py`: the parity test above (also in `tools/n2_gate.py`).

## Known gaps

- Recipe names are shown from their ids in English (category and genre names are translated in 8 languages).
- Sound settings of the Sound Lab (bus volumes, last seeds) are not stored in the project yet; the project integration
  waits for the project format work of WP4.
- The mixer cannot change the pitch or filter of a sound that is already playing (sounds are pre-rendered).
- The module build must carry the new core files through the NRO exports (WP20).
