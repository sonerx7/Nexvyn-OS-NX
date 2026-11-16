# Game Engine: the offline wizard and the level generators (WP16)

"Describe and create" lets someone who has never made a game write one to three sentences in their own language (or tap a few
question cards) and get a playable project. Nothing here uses AI or the network: a dictionary and rules turn the words into a
**design**, and twelve genre packs plus eight seeded level generators turn the design into a **project v2**
(`docs/GAME_ENGINE_FORMAT_V2.md`). The AI bridge of WP17 (`docs/GAME_ENGINE_AI.md`, "Create with AI") fills the same design schema, so both ways make the same kind of project.

| Part | Where |
|---|---|
| Dictionary (8 languages), intent extraction, question cards, design JSON | `source/core/ge_wizard.{h,cpp}`, `ge_wizard_lex.inc` |
| Genre packs (design -> project v2) | `source/core/ge_wizard_build.cpp` |
| Level generators and their reachability checks | `source/core/ge_gen.{h,cpp}` |
| Editor: "Describe and create" on the home screen | `source/apps/ge_wizard_panel.{h,cpp}` (one call in `app_gamemaker.cpp`) |
| Unit tests | `tests/test_gewizard.cpp`, shared sentences `tests/fixtures/ge_wizard/intents.json` |
| Gate check (builds `tests/ge_wizard_cli.cpp`) | `tools/ge_wizard_check.py` (in `tools/n2_gate.py`) |

Everything is pure and deterministic: the same text, answers and seed give the same project on every run (no clock, no threads).

## 1. From words to a design

`parseText(text, uiLang, seed)` folds the text (lower case, accents removed, punctuation is a space, full-width letters become plain
ones) and looks for dictionary words. A dictionary row is a **concept** (`genre=racing`, `setting=snow`, `goal=laps`, ...) with a word
list in each of the 8 languages (`en tr de es fr ja ko zh`, about 60 concepts and 700 words in all).

- A Latin word has to start a word, so `playa` (beach) is not found inside `toplayan`. A word ending in a space has to end one.
  Chinese, Japanese and Korean words match anywhere.
- Every hit adds its length to its concept. For each category the concept with the largest sum wins. The language with the largest
  sum of hits is the language of the text (the UI language wins a tie); it becomes the language of the texts inside the game.
- Numbers: a number followed by a minute or second word is the time limit (`2 dakika`, `90 seconds`, `2分`); followed by a lap word
  it is the lap count (`3 tur`, `3周`); any other number (1..999) is the goal count.
- When no genre word is found the other words choose one (a first person camera means FPS, a city setting means city builder, ...).
- The rules then fix what the genre cannot do and say so in `notes` ("racing cannot use the side camera: third is used").
  `confidence` is 0..100: how much of the design came from the text and not from defaults. Empty or unreadable text gives the
  default design with confidence 0. Only the first 2000 bytes are read; invalid UTF-8 is treated as spaces.

**Question cards** (`cards()`): `genre camera setting enemy goal time difficulty mood style length`. `fromAnswers(map)` builds the same
design from the chosen values; missing keys keep the genre's defaults. The UI shows the lang key `wiz_opt_<key>_<value>` for each value.

## 2. The design JSON (the schema the AI writes too)

```json
{"format": "nexvyn-ge-design", "version": 1, "title": "Snow Rally", "genre": "racing", "mode": "3d", "camera": "third",
 "setting": "snow", "enemy": "none", "goal": {"type": "laps", "count": 3}, "timeLimit": 120, "difficulty": "normal",
 "mood": "tense", "style": "minimal", "length": "medium", "powerups": true, "seed": 7, "lang": "en"}
```

| Field | Values |
|---|---|
| `genre` | `platformer shooter racing fps td rpg puzzle runner city horror novel rhythm` |
| `mode` | `2d` or `3d`. The genre decides; only `rpg`, `puzzle` and `city` have both |
| `camera` | `side top third first fixed`, restricted by genre and mode (below) |
| `setting` | `meadow forest snow desert sea city cave castle space night candy` (look, sky, ground, wall tiles, decoration, particles) |
| `enemy` | `none slime ghost bat robot alien spider snake crab` |
| `goal.type` | `collect exit survive defeat laps score story`, restricted by genre; `goal.count`: coins, kills (points x 10), seconds, laps, points or characters |
| `timeLimit` | seconds, 0..3600 (`survive` goals set it themselves: the clock is the goal) |
| `difficulty` | `easy normal hard`: lives 5 / 3 / 2, enemy count, speed |
| `mood` | `calm happy tense adventure horror battle space race`: music |
| `style` | `pixel neon paper military fantasy minimal noir`: HUD and menu art direction (`hud.style`) |
| `length` | `short medium long`: 1 / 2 / 3 levels |
| `powerups` | bool |
| `seed` | 1..4294967295: the level generators and the pack's random choices |
| `lang` | `en tr de es fr ja ko zh`: language of the texts inside the game |

`designFromJson` / `validateDesign` accept what an AI writes: unknown fields are dropped (warning `unknown_field`), a value outside its
list or range is replaced by the genre's default (warning `enum` / `range`), a wrong type is ignored (error `type`), a newer `version`
warns. The result is always a usable design; nothing crashes (fuzzed in `tests/test_gewizard.cpp`).
The project keeps its design under `wizard.design`, so "change and regenerate" and the AI bridge read it back.

| Genre | 2D / 3D | Cameras | Goals | Levels from |
|---|---|---|---|---|
| platformer | 2D | side | exit collect score | side scroller (jump model) |
| shooter | 2D | fixed top | defeat score survive | hand-placed arena, waves |
| racing | 3D | third | laps score | closed track |
| fps | 3D | first third | defeat survive score | arena |
| td | 2D | top | survive defeat | enemy path |
| rpg | 2D / 3D | top third first | exit collect defeat | dungeon, or island when the setting is `sea` in 3D |
| puzzle | 2D / 3D | top fixed third first | exit collect | maze |
| runner | 3D | third | score survive | lanes |
| city | 3D / 2D | third top | collect score | city blocks |
| horror | 3D | first third | exit survive collect | dark dungeon |
| novel | 2D | fixed | story | stage with characters |
| rhythm | 2D | fixed | score | lanes on the tempo |

## 3. The level generators (`ge_gen`)

`generate(kind, seed, params)` gives a tile grid (`#` wall or solid, `.` floor, `=` road / track / path, `~` water, `,` decoration) and
**spots** (`player goal coin enemy check key door boost tower base spawn prop npc chest boss pad heal lot`). Parameters are clamped
(sizes, counts, density); nothing is an error. Every generator checks what a player must reach, repairs what is not reachable and
counts the repairs in `Level::repaired`. `verify(level)` re-checks a finished level on its own (it does not trust the generator).

| Kind | Layout | Reachability check | Repair |
|---|---|---|---|
| `dungeon` | rooms joined by L corridors, one loop, a locked door before the goal room | BFS: everything reachable; the key is reachable with the door shut | carve a corridor to the spot |
| `arena` | border walls, cover blocks away from the middle, spawn points at walking distance | BFS from the middle | wall off pockets that cannot be reached |
| `track` | closed loop (three sine terms), 3 cells wide, checkpoints in loop order | loop is 8-connected and closed, every spot on the road | the line is drawn cell by cell, so there is no gap |
| `island` | WP7 `ge_terrain` island, spots on land | BFS over a 32 x 32 grid of the real terrain (water level and slope) | flatten a ramp from the nearest reachable cell, else move the spot |
| `side` | ground with pits (at most 3 wide), +-1 height steps, platforms 2 up | jump model: up 2, across 4 (3 when 2 up), falling, head room | move the spot to the nearest reachable standing cell |
| `maze` | recursive backtracker plus loops | BFS: keys, coins, enemies, goal | carve |
| `city` | 6-cell blocks, some inner streets dropped | roads connected, every lot has a street on its block | re-lay the street in front of the lot |
| `td` | monotone random walk from the left edge to the base, tower pads next to the path | path from spawn to base, every pad touches the path | none needed (built as one path) |

Test: 50 seeds per generator must all verify (`tests/test_gewizard.cpp`, `tools/ge_wizard_check.py`: 8 x 50 = 400 levels), and
`gegen_verify_is_not_vacuous` breaks levels on purpose and expects a "no".

## 4. The genre packs (`ge_wizard_build.cpp`)

`build(design)` returns the project (`Built::project`), extra files (island terrain `terrain/tN.bin` and `tN.rt.json`), a preview
(summary line, map of the first level) and the three systems of the pack. Each pack starts from its own structure; they are the
skeleton of the WP18 templates. Library behaviours are `lg_*` ids of `docs/GAME_ENGINE_LOGIC.md`.

| Genre | Core loop | The three systems |
|---|---|---|
| platformer | run and jump over pits | jump-model level (pits, platforms, springs); patrolling enemies that pause (`lg_patrol_pause`); checkpoints, collectibles, goal flag |
| shooter | survive and shoot from a ship | waves that grow (`lg_spawner_waves`); timed power-up drops (`lg_spawner_timed`, `lg_pickup_power`); boss with phases (`lg_boss_phases`) |
| racing | laps on a closed track | checkpoint gates and laps (`lg_race_gate`); countdown clock and crossing obstacles (`lg_patrol_pause`); gems on the racing line |
| fps | clear an arena | wave towers (`lg_spawner_waves`); shoot button (`lg_shoot_button`); heal pickups (`lg_pickup_heal`) |
| td | defend a base | enemies that walk the generated path (a per-enemy state machine of straight legs); towers on pads that hurt the nearest enemy in range (a state machine per tower; a library `fire` from a non-player makes hostile bullets); a hero with a shoot button |
| rpg | explore, find the key, beat the boss | rooms or island; key and locked door (`lg_pickup_key`, `lg_door_key`); guards (`lg_leash_guard`), boss, guide (`lg_dialogue`) |
| puzzle | maze with keys | seeded maze; keys and a sealed goal; pressure plate and gate (`lg_pressure_plate`, `lg_door_switch`) |
| runner | auto-run three lanes | rows that always keep a free lane; score over time (`lg_survive_score`); dash (`lg_dash_hero`) |
| city | grow and run a town | blocks and streets; income per house (`lg_survive_score`); traffic (`lg_patrol_square`) and a quest (`lg_quest_collect`) |
| horror | escape in the dark | dark dungeon with fog and particles; ambushing ghosts (`lg_ambush`), alarm (`lg_guard_alarm`); key, door, exit |
| novel | talk to everyone | characters with three-line dialogues (a custom state machine per character); story progress in a variable; stage per level |
| rhythm | catch gems on the beat | lane spawners timed to the tempo (`lg_spawner_timed`); tempo from the mood; lanes from the seed |

The project also gets: `settings` (lives, music id, time limit, difficulty, win and lose texts), `vars`, the project rules (objective
message, goal rule), a HUD with elements and `main` / `pause` screens in the language of the text, `audio.music` (the composer
genre, seed, tempo) and a `sfx` list of recipe names (a suggestion for the sound tab), and ambient particles in 3D.
Goal counts are clamped to what the level offers, so a collect goal is always winnable.

Known limits, stated plainly: defeat goals in the shooter and FPS count score (every kill is worth 10 points in the library), the
novel pack has no branching choices, the rhythm pack uses timed pickups instead of falling notes, and the combat balance is
a starting point that the maker is expected to tune.

## 5. In the editor

Home screen -> **Describe and create** (next to Quick Game): a text box, or the question cards; a preview card (summary, small map of
the first level, the three systems, confidence and notes); **Change and regenerate** (a new seed), **Create** and **Create and play**.
The project is written as a v2 project in the projects folder and opened. All texts are lang keys `gamemaker.wiz_*` in 8 languages.

## 6. Tests

- `tests/test_gewizard.cpp` (host): dictionary size per language, 55 sentences (8 languages) from the shared fixture, notes and
  confidence, odd input (empty, binary, invalid UTF-8, 100 KB, numbers), cards, design JSON round trip and validation, every genre
  x mode x difficulty x length builds a valid project (schema, behaviour ids exist, state machines valid, lowering works), a player
  exists and a collect goal is winnable, the packs differ, determinism and seeds, texts in 8 languages, preview, island files, AI
  style designs, 8 generators x 50 seeds, clamping, verifier not vacuous, closed tracks, island terrain, jump model.
- `tools/ge_wizard_check.py`: the same from outside: Python v2 validator, the Lua runtime on the mock SDK, recipe differences, the
  shared sentences, 400 generated levels, 8 languages, banned words. `python tools/n2_gate.py` runs it.
