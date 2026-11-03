# Sound design for Nexvyn OS games

**English** · [Türkçe](SOUND_DESIGN.tr.md)

Sound is half of how a game feels. A raw `audio.tone(440, 0.1, 1, "square")` on every action makes a game sound cheap
and tiring; the same game with layered, mixed, varied sounds feels finished. This guide explains how to get there with
the SDK, and the **sound kit** does the work for you:

- Lua: `SDK/Languages/lua/kits/sfx.lua` · JavaScript: `SDK/Languages/javascript/kits/sfx.js` (the same kit and recipes).
- Each kits folder is also a runnable demo app (`main.lua` / `main.js`) that uses the kit together with the feel kit
  (`juice.lua` / `juice.js`, see [GAME_FEEL.en.md](GAME_FEEL.en.md)). Copy the kit file next to your `main` file.

## 1. What the SDK gives you, and what the kit adds

| SDK call | What it does |
|---|---|
| `audio.play(path, volume, loops)` → channel | plays a `.wav` / `.ogg` / `.mp3` (decoded once, kept in memory); `loops = -1` repeats |
| `audio.tone(freq, seconds, volume, wave)` | one raw note: sine, square, saw, triangle or noise |
| `audio.music(path)`, `audio.musicPause`, `audio.musicStop` | one streamed song |
| `audio.stop(channel)` | stops one sound |

There is no pitch, filter or volume change for a sound that is already playing, and the mixer has 24 channels for
the whole system. So the kit **renders** each sound once from a recipe into a 16-bit WAV file in the app's data
folder, with everything a raw tone lacks, and plays it with `audio.play`:

- layers per sound (a body, a transient, a tail), each with its own oscillator (sine, triangle, band-limited saw and
  pulse, white / pink / brown noise, FM, unison detune), pitch sweep, vibrato, tremolo, ADSR envelope and
  low / high / band-pass filters with sweeps and LFOs;
- echo, a small room reverb, soft-clip drive, DC removal, peak normalising and click-free edges;
- **variants**: 3-4 slightly different renders of each sound (pitch, filter, level), picked at random without
  repeating the last one;
- **buses** `music`, `sfx`, `ui`, `amb` and `master` with volumes, **ducking** (a big hit lowers the music for a
  moment), a **voice limit** per sound and for the kit, a **cooldown** so ten pickups in one frame do not stack;
- **ambience**: seamless looping beds (wind, rain, night, cave, ocean, machine hum, fire) plus random one-shot details
  (birds, drips, crackles, crickets, creaks);
- **music**: short loops built from a chord progression in any scale (pad, bass, arpeggio, drums), voice-led, mixed
  with per-stem levels, echo and room; one gapless loop file, or one file per bar so the music can duck.

Rendering runs a few milliseconds per frame in `sfx.update(dt)` (never near the 3-second limit) and the files are
cached: the second start of the game loads them at once. Show `sfx.progress()` on your loading screen the first
time. Recipe changes make new files automatically (the file name contains a hash of the recipe).

## 2. Ten minutes to good sound

```lua
local sfx = require("sfx")
function app.load()
  sfx.init()
  local R = sfx.recipes
  sfx.define("jump", R.jump{weight = 0.3}, {variants = 3})
  sfx.define("coin", R.coin(), {variants = 3})
  sfx.define("hit", R.impact{weight = 0.8}, {variants = 4, duck = {"music", 0.45, 0.25}})
  sfx.define("boom", R.explosion{size = 0.7}, {duck = {"music", 0.3, 0.6}})
  sfx.define("step", R.footstep{surface = "grass"}, {variants = 4, vol = 0.5, cooldown = 0.08})
  sfx.define("tick", R.ui{kind = "tick"}, {bus = "ui"})
  sfx.define("ok", R.ui{kind = "confirm"}, {bus = "ui"})
  sfx.define("wind", R.ambience{kind = "wind"})
  sfx.define("bird", R.detail{kind = "bird"}, {bus = "amb", variants = 3})
  sfx.song("theme", R.song{bpm = 96, root = "A2", scale = "minor", chords = {1, 6, 3, 7}, drums = "soft"})
  sfx.ambience("wind", {details = {"bird"}, every = {3, 8}})
  sfx.music("theme")
end
function app.update(dt) sfx.update(dt) end
-- in the game: sfx.play("jump"), sfx.play("hit"); in the settings: sfx.setBus("music", value)
```

JavaScript is the same with objects and arrays: `sfx.define("hit", sfx.recipes.impact({ weight: 0.8 }), { variants: 4,
duck: ["music", 0.45, 0.25] })`.

## 3. How to make sounds feel good

1. **Layer every important sound.** A sound people remember has three parts: a **transient** (the first 5-20 ms: a
   click, a noise burst; it says *when*), a **body** (the pitch you hear; it says *what*) and a **tail** (echo, room,
   a low thump; it says *how big*). `R.impact` is a sine thump + a band-passed noise crack + a short high click + a
   little drive. Copy that pattern for your own recipes.
2. **No raw square waves at full volume.** Square and saw are bright and harsh. Filter them (`lp = {cut = 1800}`),
   lower them under a sine or triangle body, use a narrow `duty` for a thinner, nicer tone, or sweep the filter down
   (`lp = {cut = 4000, to = 900}`). Keep pure square for deliberate chiptune games, and even then filter the highs.
3. **Pitch moves.** Things that rise (jump, power-up, menu forward) sweep up; things that fall or end (hurt, back,
   game over) sweep down. A static pitch sounds like a beep, a sweep sounds like an event.
4. **Size is low end and length.** Small things: short, high, no tail. Big things: a sub thump (`sine` 110 → 30 Hz),
   longer noise with a falling low-pass, a room. Make the hero's sounds a little heavier than the enemies'.
5. **Variation.** Anything the player hears more than a few times a minute needs 3-4 variants (`variants = 4`):
   footsteps, shots, hits, pickups. The kit varies pitch about a semitone, the filter and the level.
6. **One family.** One set of waveforms, the same room, the same echo time for the whole game. A pixel game with
   triangle and pulse waves; a sci-fi game with FM and saws; a cosy game with sines and soft noise. Write the family
   into your art direction (section 11 of [MAKE_A_GAME.en.md](MAKE_A_GAME.en.md)).
7. **Every action answers.** Moving in a menu, confirming, going back, an error, jumping, landing, hitting, getting
   hit, picking up, opening a door, winning, losing: each has a sound, and the visual feedback happens on the same
   frame ([GAME_FEEL.en.md](GAME_FEEL.en.md)).
8. **Silence is a tool.** Not everything needs a sound. Drop the music before a boss, let the ambience carry quiet
   moments, and cut sounds that play constantly (a footstep every frame is noise: use a cooldown or play them on the
   step of the animation).

## 4. Levels and mixing

The kit normalises every file to -1 dB peak, so levels come from the definition volume and the buses.

| What | Bus | Start at | Notes |
|---|---|---|---|
| Player actions, hits, pickups | `sfx` | `vol` 0.8-1 | the loudest thing in the game |
| Enemies, world, footsteps | `sfx` | `vol` 0.4-0.7 | under the player's own sounds |
| Menu moves, clicks | `ui` | bus 0.7 | short and soft; a confirm a little louder than a tick |
| Ambience beds and details | `amb` | bus 0.5-0.6 | you notice it when it stops |
| Music | `music` | bus 0.45-0.55 | under the effects; duck it for big moments |

- **Duck** the music under the moments that matter: `duck = {"music", 0.45, 0.25}` on a heavy hit, deeper and longer
  on an explosion or a boss roar. Music in the default `"loop"` mode is one gapless file and does not duck (the SDK
  cannot change the volume of a playing sound); use `{mode = "bars"}` when you want ducking and volume changes during
  the song (they apply at the next bar).
- **Give the player** music, effects and ambience volumes in your settings (`sfx.setBus`), saved with `store`.
- **Limit voices**: `maxVoices` per sound (default 3) and `sfx.maxVoices` for the kit (default 12): the system has
  24 channels in total, and a wall of identical sounds is worse than a few.
- **Check on the console speakers and on headphones.** Small speakers lose everything below ~200 Hz: an impact needs
  its noise crack and mid-range body too, not only the sub thump.

## 5. Music

`sfx.recipes.song{...}` writes a loop from a chord progression:

| Option | Values |
|---|---|
| `bpm`, `root`, `scale` | tempo; the key (`"A2"`, `"D3"`...); `major`, `minor`, `dorian`, `phrygian`, `lydian`, `mixolydian`, `harmonic`, `pentatonic` |
| `chords` | scale degrees, one per bar: `{1, 6, 3, 7}` (sad, epic), `{1, 5, 6, 4}` (bright pop), `{1, 4, 6, 5}` (dorian, adventurous), `{1, 2, 6, 5}` (lydian, dreamy) |
| `pad`, `bass`, `arp`, `drums` | `bass` `"pulse"` / `"walk"` / `"simple"`; `arp` `"up"` / `"updown"` / `"random"` with `arpRate` 8 or 16; `drums` `"soft"` / `"drive"` / `"half"`; `false` turns a part off |
| `padGain`, `bassGain`, `arpGain`, `drumsGain` | stem levels in dB |
| `sevenths`, `seed` | richer chords; another random arpeggio |

Use 2-3 songs (title, play, tension) with the same instruments in different keys or tempos, and short jingles
(`R.jingle{notes = {"C5", "E5", "G5", "C6"}}`) for winning, losing and level-ups. A streamed `.ogg` made in a music
tool is still the best for a long soundtrack; master it quieter than the effects (about -14 LUFS).

## 6. Writing your own recipe

A recipe is a table of layers; times are seconds, frequencies Hz:

```lua
local zap = {layers = {
  {wave = "saw", freq = 1400, to = 300, glide = 0.15, len = 0.2, a = 0.001, d = 0.1, s = 0.2, r = 0.08,
   lp = {cut = 5000, to = 1200, q = 1.2}, vol = 0.6, fm = {ratio = 2, index = 1.5, to = 0}},   -- body
  {wave = "noise", len = 0.02, a = 0.0005, d = 0.015, s = 0, r = 0.003, hp = {cut = 4000}, vol = 0.4},  -- transient
  {wave = "sine", freq = 90, to = 50, at = 0.01, len = 0.12, a = 0.001, d = 0.08, s = 0, r = 0.03, vol = 0.5}}, -- weight
  echo = {time = 0.07, feedback = 0.25, mix = 0.2}, drive = 0.1}
sfx.define("zap", zap, {variants = 3})
```

Layer fields: `wave`, `freq`, `to`, `glide`, `at`, `len`, `a`, `d`, `s`, `r`, `vol`, `duty`, `unison`, `cents`,
`fm = {ratio, index, to}`, `vib = {rate, depth}` (semitones), `trem = {rate, depth}`, `lp` / `hp` / `bp =
{cut, to, q, lfo = {rate, depth}}` (octaves), `stem`. Recipe fields: `layers`, `len`, `echo = {time, feedback, mix}`,
`room = {size, mix, damp}`, `drive`, `peak` (dB), `gain` (dB), `tail`, `loop`, `crossfade`, `stems`.

## 7. Checklist

- [ ] Every player action and every menu action has a sound; important ones have 3-4 variants.
- [ ] No raw, unfiltered square or saw at full level; sounds have a transient, a body and (when big) a tail.
- [ ] One sound family; the same room and echo throughout.
- [ ] Music under the effects, ducked under big moments; an ambience bed where the scene is quiet.
- [ ] Music, effects and ambience volumes in the settings, saved.
- [ ] First start shows the baking progress; nothing blocks a frame.
- [ ] Listened to on the console speakers and on headphones.
