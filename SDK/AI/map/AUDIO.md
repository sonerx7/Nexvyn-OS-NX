# AUDIO

## Purpose
Documents native PCM audio streams (`nxn_audio_*`), the OS sound mixer (`nxn_sfx_*` / `nxn_tone`), and script `audio.*` / `sfx` kit APIs.

## Keys
| symbol/function | header or module | one-line meaning |
|---|---|---|
| `nxn_audio_open` / `nxn_audio_close` | `nxn_audio.h` | Opens/closes a paused PCM stream (default 48 kHz stereo `NXN_AUDIO_S16`, 1024 frames) |
| `nxn_audio_params` / `NXN_AUDIO_S16` / `F32` | `nxn_audio.h` | Stream config; `callback = NULL` selects push mode |
| `nxn_audio_pause` | `nxn_audio.h` | Pauses (`1`) or resumes (`0`) stream playback |
| `nxn_audio_queue` / `nxn_audio_queued_bytes` | `nxn_audio.h` | Push-mode sample append (waits up to ~250 ms if full, else `NXN_ERR_TOO_SMALL`) |
| `nxn_audio_clear` | `nxn_audio.h` | Drops queued unplayed push samples (`NXN_CAP_AUDIO_CLEAR`, Native 1.1) |
| `nxn_sfx_play` | `nxn_audio.h` | Queues system sound name or `.wav`/`.ogg`/`.mp3` on OS mixer (`NXN_CAP_MIXER`) |
| `nxn_tone` | `nxn_audio.h` | Queues synthesized tone (`20..20000` Hz, `0.01..10` s, wave `0..4`, `NXN_CAP_MIXER`) |
| `nxn_sfx_stop_all` | `nxn_audio.h` | Stops all sounds started by this app via `nxn_sfx_play` / `nxn_tone` (`NXN_CAP_MIXER`) |
| `audio.tone` / `audio.play` / `audio.stop` | `audio` (Script) | Plays synth notes, system SFX, or audio files (`loops = -1` repeats) |
| `audio.music` / `musicPause` / `musicStop` | `audio` (Script) | Streams background music owned by the app |
| `audio.stopAll` | `audio` (Script) | Stops all app-started SFX/tones without stopping music (`SDK 1.12`) |
| `sfx.*` (`init`, `define`, `play`, `song`, `duck`) | `kits/sfx.*` | Game audio kit for layered recipes, variants, ambience, and bus ducking |

## Rules
- Up to 8 `nxn_audio` streams per app in Nexvyn OS; in push mode only one producer thread at a time may call `nxn_audio_queue` / `nxn_audio_clear`.
- In pull mode (`nxn_audio_callback`), keep the callback short, perform no file or network I/O, and never call `nxn_audio_close` inside it.
- Never spin on `NXN_ERR_BUSY` or full-buffer conditions in audio loops.
- `nxn_sfx_play` and `nxn_tone` are non-blocking and fire-and-forget; playback errors are logged rather than returned.
- On `NXN_EVENT_SUSPEND`, Nexvyn OS mutes app audio; `NXN_EVENT_RESUME` drops queued pre-suspend audio buffers.

## Pitfalls
- Calling `nxn_audio_clear` without checking `NXN_CAP_AUDIO_CLEAR` (`NXN_ERR_UNSUPPORTED` on 1.0 hosts).
- Expecting `nxn_sfx_stop_all` / `audio.stopAll()` to stop `audio.music()` (it only stops SFX and tones).
- Calling `nxn_audio_close` from within `nxn_audio_callback`.

## See also
- [INDEX](INDEX.md)
- [LIFECYCLE_WINDOW](LIFECYCLE_WINDOW.md)
- [SCRIPT_SDK](SCRIPT_SDK.md)
- [NATIVE_ABI](NATIVE_ABI.md)
