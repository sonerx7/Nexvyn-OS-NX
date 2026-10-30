# Samples

**English** · [Türkçe](README.tr.md)

**24** samples.

Working sample projects in six languages. Every folder has `source/` (a complete `.nxvapp` bundle), `README.md` (what it teaches, controls, how to run it), `icon.png`, `store.json` (title and description in five languages, kind, tags, screenshot script) and `screenshots/` where available. `Tools/build_store.py` builds a `<slug>.zip` of each sample and `SDK/samples.json`, which Nexvyn OS Studio's *Samples* section reads.

To try one, copy `source/` to `sdmc:/NexvynOS/Applications/<name>.nxvapp`, or run `python SDK/Tools/nxv/nxv.py push SDK/Samples/<lang>/<name> --host <console-ip>`.

## Lua

|  | Sample | Kind | SDK | Summary |
|---|---|---|---|---|
| <img src="lua/beatbox/icon.png" width="32"> | [Beatbox Demo](lua/beatbox/) | demo | 1.0 | A 16-step drum machine |
| <img src="lua/effects/icon.png" width="32"> | [Effects Demo](lua/effects/) | demo | 1.0 | Plasma, tunnel and starfield |
| <img src="lua/gestures/icon.png" width="32"> | [Gestures Demo](lua/gestures/) | demo | 1.0 | Pinch, rotate, pan, tilt and rumble |
| <img src="lua/hello/icon.png" width="32"> | [Hello SDK](lua/hello/) | demo | 1.0 | A tour of the Lua SDK |
| <img src="lua/particles/icon.png" width="32"> | [Particles Demo](lua/particles/) | demo | 1.2 | Emitters, bursts and gravity wells |
| <img src="lua/physics/icon.png" width="32"> | [Verlet Physics Demo](lua/physics/) | demo | 1.2 | Ropes, a bridge and tearable cloth |
| <img src="lua/platformer/icon.png" width="32"> | [Platformer Demo](lua/platformer/) | game | 1.2 | A complete platformer level with nexvyn.game |
| <img src="lua/scene3d/icon.png" width="32"> | [3D Scene Demo](lua/scene3d/) | demo | 1.0 | Textured 3D meshes, sun, fog and glow |
| <img src="lua/synth/icon.png" width="32"> | [Synth Demo](lua/synth/) | demo | 1.0 | Piano, waveforms and an ADSR envelope |
| <img src="lua/terrain/icon.png" width="32"> | [Terrain Demo](lua/terrain/) | demo | 1.0 | A procedural island to fly over |
| <img src="lua/ui-gallery/icon.png" width="32"> | [UI Gallery](lua/ui-gallery/) | demo | 1.0 | Every ui widget with its code |

## JavaScript

|  | Sample | Kind | SDK | Summary |
|---|---|---|---|---|
| <img src="javascript/hello/icon.png" width="32"> | [Hello JS](javascript/hello/) | demo | 1.1 | A tour of the JavaScript SDK |
| <img src="javascript/shapes-js/icon.png" width="32"> | [Shapes JS Demo](javascript/shapes-js/) | demo | 1.1 | Every g3d primitive in JavaScript |

## Python

|  | Sample | Kind | SDK | Summary |
|---|---|---|---|---|
| <img src="python/audio-py/icon.png" width="32"> | [Melody Player (Python)](python/audio-py/) | demo | 1.3 | A note-by-note melody player |
| <img src="python/hello/icon.png" width="32"> | [Hello Python](python/hello/) | demo | 1.3 | A tour of the Python SDK |

## Squirrel

|  | Sample | Kind | SDK | Summary |
|---|---|---|---|---|
| <img src="squirrel/hello/icon.png" width="32"> | [Hello Squirrel](squirrel/hello/) | demo | 1.5 | A tour of the Squirrel SDK |
| <img src="squirrel/snake/icon.png" width="32"> | [Snake (Squirrel)](squirrel/snake/) | game | 1.5 | The classic, with controller, keys and touch |
| <img src="squirrel/stopwatch/icon.png" width="32"> | [Stopwatch](squirrel/stopwatch/) | app | 1.5 | Laps, best and worst, kept between runs |

## C

|  | Sample | Kind | SDK | Summary |
|---|---|---|---|---|
| <img src="c/hello/icon.png" width="32"> | [Hello C](c/hello/) | demo | 1.5 | A tour of the C SDK |
| <img src="c/life/icon.png" width="32"> | [Game of Life (C)](c/life/) | demo | 1.5 | Conway's cellular automaton in C |
| <img src="c/tipcalc/icon.png" width="32"> | [Tip Splitter (C)](c/tipcalc/) | app | 1.5 | Split a bill and its tip fairly |

## Java

|  | Sample | Kind | SDK | Summary |
|---|---|---|---|---|
| <img src="java/dice/icon.png" width="32"> | [Dice Roller (Java)](java/dice/) | app | 1.5 | d4 to d20, hold dice, keep a history |
| <img src="java/hello/icon.png" width="32"> | [Hello Java](java/hello/) | demo | 1.5 | A tour of the Java SDK |
| <img src="java/pong/icon.png" width="32"> | [Pong (Java)](java/pong/) | game | 1.5 | You against the console, first to 7 |
