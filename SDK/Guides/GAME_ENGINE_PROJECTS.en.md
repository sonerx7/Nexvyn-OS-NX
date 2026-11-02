# Game Engine (Oyun Motoru)

[Türkçe](GAME_ENGINE_PROJECTS.tr.md) · **English**

Game Engine (`gamemaker`, formerly Oyun Atölyesi / Game Workshop) is a separate app for making 2D and 3D games on
Nexvyn OS; it is in the **Developer** group in the Start menu and in Apps, next to Studio. It has an "Easy" mode for
children and an "Advanced" mode for those who want more; both open the same project. Games are played by a Lua runtime
that runs on top of the `nexvyn.game` engine and are shared as an ordinary `.nxvapp`. The app id (`gamemaker`), the
project format and the `Oyunlarım` (My Games) folder did not change; old projects open as they are.

## Using it

- **Home screen:** the first card is the **Game wizard**, followed by the "Make a new game" picture cards (Platformer,
  Forest Adventure, Maze, Key Puzzle, Space, Apple Race, Meteor Shower, Treasure Hunt, Racing 3D, Runner 3D, Ball
  Collecting 3D, Empty 2D, Empty 3D), "My Games" and "Sample games" (Cat Adventure, Penguin Adventure, Star Hunter,
  Golden Island, Robot Run). The samples are read-only; on the first change they are copied into the `Game Workshop`
  folder. The green ▶ button on My Games cards opens and starts a game with one tap. A long press on a game (or X /
  right click) opens a menu with Open, Rename, Duplicate, Move to Trash.
- **Game wizard:** three steps. 1) Genre: Platformer, Adventure (top-down), Space battle, Puzzle, Racing 3D, Runner 3D.
  2) World (theme): Forest, Snow, Desert, Cave, Space, Candy land, Ocean; every card shows that world's background and
  hero. 3) Name. "Build my game!" copies the genre's template, applies the theme (characters, enemies, collectibles,
  decorations, tiles, background, music; sky and ground color in 3D) and opens a game you can play right away.
- **Quick Game (Hızlı Oyun):** the first button on the home screen. Three steps with big cards: 1) Genre, 17 ready,
  playable games: Platformer, Runner 2D (runs by itself, you jump), Flap Flight (tap to fly through gaps), Brick Breaker,
  Space shooter, Arena (top-down, survive the waves), Adventure, Maze, Key Puzzle, Treasure Hunt, Catch Rush, Dodge,
  3D Runner, Racing 3D, Island Adventure 3D (platforms, key, door, portal), Collector 3D and Maze Escape 3D (first
  person). 2) World (theme). 3) Options: difficulty (Easy / Normal / Hard: speed of enemies and moving things, how
  often they shoot and spawn), lives (1/3/5/9), time limit (none, 60, 90, 120, 180 s or the template's own), controls
  where the genre has more than one (for example third or first person, auto-run or free run), and a name. "Play now"
  makes the game and starts it at once; "Open in editor" opens it for editing.
- **Guided tour:** on the first start, an eight-step tour shines a light on the palette, the scene, Undo / History, the
  mode button, Share and Play (it can be skipped with Skip; Esc closes it, Enter advances). The Help button and the
  Help menu start the tour again. With "Reduce motion" on, the light jumps instead of sliding and does not blink.
- **Toolbar:** words under the icons (only icons in a narrow window): Games, Undo, Redo, History; the game's name and
  the autosave status in the middle (Saving… / Saved); Help, Easy/Advanced, Share, Play on the right.
- **History:** a list of the latest changes (what was done and when). Tapping a step and confirming undoes everything
  done since then; Redo brings it all back.
- **Friendly warnings:** if nobody in the first level has player control, Play says "Your game needs a hero!" ("Add a
  hero" opens Characters, "Play anyway" starts it). Errors when opening, playing and packaging are shown in a sentence
  children understand; the technical detail stays in brackets at the end. If a script makes a mistake during the game,
  the game does not stop: a red note shows the error's line and that script is switched off.
- **Easy mode:** big category buttons on the left (Characters, Enemies, Collectibles, Blocks, Goals, Decorations, My
  drawings, Background / Sky, Music). Drag a picture into the scene, or tap the picture and then tap the scene (it
  works with the controller too). Blocks are painted like a brush, and there is an eraser too. Tapping an object opens
  the behaviour tiles on the right: movement (player control, walks left and right, wanders randomly, jumps, follows,
  spins, moves along), effect (points when collected, counts when collected, takes a life on touch, has lives, finish,
  says something, disappears after a while), physics (gravity, solid, trampoline), spawning (spawns, shoots). When a
  behaviour is turned on, what it does is shown in one sentence; turning on "Says something" asks for the words to
  say. The big green **▶ Play** opens the game at once; the red ■ button in the game goes back to editing. Undo / Redo
  are always visible; every screen has a big back button. On first use, bouncing yellow hints show the way.
- **Assets panel:** a search box and categories, including **Textures** (3D: tap one to put it on the selected object,
  or on the ground when nothing is selected; also from the inspector's Texture / Ground texture rows), **Ready setups**
  (one tap adds a configured object or rule set around the middle of the view: platform hero, third / first person
  camera, car, patrolling and chasing enemies, collectibles with a counter, key and door, checkpoint, lives, countdown,
  enemy waves, day and night (3D), moving platform) and **Recently used** (the last 12 objects placed). Sounds are
  grouped (jump, coins, pickups, power-ups, hits, hurt, explosions, shots, interface, footsteps, doors, vehicles,
  ambience, win and lose); a tap plays a preview.
- **Sound Maker (Ses Üretici):** from Sounds (or the first tile of the sound list): eight presets (coin, jump, laser,
  explosion, power-up, hit, blip, surprise), wave, pitch, length, slide, vibrato, note jump and brightness sliders,
  Random, Play and "Save to game" (`sounds/<name>.wav`; the entry keeps the parameters under `synth`).
- **Advanced mode:** tabs: Scene (an inspector with numbers, layers, behaviour parameters and a description of every
  behaviour, the object script), Events (Scratch-like blocks; every block in the palette has a line below it that
  explains what it does), Drawings (Studio's pixel editor), Tiles (Studio's tilemap editor), Sounds (music, effects,
  imported sounds), Code (Lua generated from the blocks; "Convert to code" turns it into `scripts/game.lua` and opens it
  in the Code Editor), Settings (name, the win and game-over messages, lives, time, view, gravity, camera; sky and fog
  in 3D).
- **Share:** three big buttons. "Share as app" writes `Documents/<Game>.nxvapp` (with `manifest.sha256`) and opens the
  package in the App Installer (details, Run, Install). "Add to desktop" installs the package and puts a shortcut on
  the desktop. "Open in Studio" installs the game (with the runtime, the library and the project inside) as a Lua app
  and opens it in Studio; from there you continue with code, and the project in Game Engine stays as it is.

## Files

| Path | Contents |
|---|---|
| `source/apps/app_gamemaker.cpp` | the app: home screen, 2D/3D scene, palette, behaviour tiles, inspector, tabs, Play/Share |
| `source/apps/workshop_doc.*` | library, behaviour and block catalogs, project files, package building, Lua generation, model import |
| `source/apps/workshop_blocks.cpp`, `workshop_ui.h` | the event block editor and shared UI pieces |
| `source/apps/workshop_sfx.*` | the effect synthesizer (port of `tools/gen_sfx.py`) and the Sound Maker panel |
| `romfs/System/Lua/nexvyn/workshop.lua` | runtime: project loading, events, API, 2D scene, title / end screen |
| `romfs/System/Lua/nexvyn/workshop3d.lua` | 3D scene (g3d) |
| `romfs/System/Workshop/` | `library.json` (including the wizard's `genres` and `themes` lists, `textures`, `setups`), `art/`, `tiles.png`, `bg/`, `sounds/`, `sfx/`, `textures/`, `Templates/`, `Samples/` |
| `tools/gen_workshop.py` | generates the whole library, the templates and the samples (Pillow); reads the catalogues of the two below |
| `tools/gen_textures.py` | 40 seamless 256×256 material textures in 7 groups (`textures/`, Pillow + numpy) |
| `tools/gen_sfx.py` | 67 sound effects in 14 groups (`sfx/`, numpy): our own retro synthesizer |
| `romfs/Applications/gamemaker.app/lang/{tr,en,de,fr,es}.json` | interface strings (`gamemaker.*`) |

Every picture and sound is generated by code with `tools/gen_workshop.py`, `tools/gen_textures.py` and
`tools/gen_sfx.py` (run the last two first: `gen_workshop.py` reads their files for the catalogue); there are no
ready-made external assets. The first 22 sound effects are 48 kHz stereo WAV (the mixer's format); the effect library
(`sfx/`) and Sound Maker sounds are mono 16-bit 24 kHz WAV, converted once when loaded (a quarter of the size).
Textures are 64-colour PNGs. Music is not files but synthesized tunes played with `game.audio.song`.

## Project format (`project.json`)

```json
{
  "format": "nexvyn-workshop", "version": 1,
  "title": "Kedi Macerası", "titleEn": "Cat Adventure", "id": "com.kullanici.kedimacerasi",
  "mode": "2d",
  "settings": {"view": "side", "lives": 3, "timeLimit": 0, "music": "adventure", "gravity": 900,
               "camera": "follow", "sky": "#9ED8FF", "fog": false},
  "vars": [{"name": "anahtar", "value": 0, "hud": true}],
  "events": [ {"on": {...}, "if": [...], "do": [...]} ],
  "levels": [ {...} ],
  "sprites": [{"name": "Çizimim", "file": "sprites/cizimim.png", "flip": "sprites/cizimim_flip.png", "w": 14, "h": 14}],
  "models": [{"name": "araba", "file": "models/araba.obj", "w": 1, "h": 0.4, "d": 0.6}],
  "sounds": [{"name": "kapi", "file": "sounds/kapi.wav"}],
  "layers": [{"name": "Arka"}, {"name": "Ana"}, {"name": "Ön"}],
  "script": "scripts/game.lua"
}
```

- `mode`: `"2d"` or `"3d"`. `settings.view` (2D): `"side"` (side view, gravity) or `"top"` (top-down).
  `settings.difficulty`: `"easy"`, `"normal"` (default) or `"hard"`: enemy and moving-object speeds × 0.75 / 1 / 1.3,
  shooting, spawning and jumping intervals ÷ the same. `settings.dayNight` (3D): seconds for a whole day, 0 = always
  day.
  `settings.camera`: `"follow"` or `"fixed"`. `settings.winText` / `settings.loseText`: the words shown under "You
  won!" / "Game over" on the end screen. Games made with the wizard also store `genre` and `theme` (for information).
- **2D level:** `{"name", "background": "sky", "cols": 60, "rows": 17, "tiles": ["....1111", ...], "objects": [...]}`.
  `tiles` is one string per row: `.` empty, `1`…`9`, `a`…`z` = tile number 1…35 (`library.json` "tiles": `solid`,
  `oneway`, `hazard`, `ice`). A tile is 16 units.
- **3D level:** `{"name", "ground": {"size": 30, "color": "#7FCB6A", "tex": "grass"}, "objects": [...]}`. The unit is
  meters, y is up, the ground is at y = 0. `tex` (optional) is a library texture repeated every `scale` metres; the
  colour is used where textures are not drawn.
- **Object:** `{"id": 7, "kind": "cat", "x": 40, "y": 200, "z": 0, "flip": false, "sx": 1, "s": 1, "rot": 0,
  "ry": 0, "layer": 1, "name": "kapi", "tex": "brick", "beh": [{"t": "player", "style": "platform"}], "scriptFile":
  "scripts/object7.lua"}`. `tex` (3D) puts a library texture on the object's model (box parts repeat it; a model part
  may name its own `tex`, the object's replaces it). `kind` is a library id, `spr:<name>` (your own drawing) or `obj:<name>` (an imported 3D
  model). Without `beh`, the default behaviours from the library are used. In 2D, x, y is the center of the picture.
- **Behaviours** (`t` and optional parameters): `player` (`style`: platform/top/ship/runner/flap/paddle, in 3D
  walk/fps/car/runner; the runner runs forward by itself (in 2D to the right, the player only jumps; in 3D the stick
  only shifts it left and right); flap flies right by itself and flaps up on each jump press, a wall, the floor or the
  ceiling costs a life and it starts again at the last checkpoint; paddle moves only left and right; `speed`, `jump`),
  `checkpoint` (the player's restart point after a fall or a crash), `ball` (2D, `speed`: bounces off walls, the player
  and breakables, waits on the player until jump or fire, falling out costs a life), `breakable` (2D, `points`: broken
  by a ball or a shot, with `health` after several hits), `patrol` (`speed`,
  `dist`), `wander` (`speed`; wanders in random directions), `jumper` (`every`, `power`), `follow` (`speed`, `range`),
  `spin` (`speed`), `move` (`vx`, `vy`; `vz` in 3D), `collect` (`points`, `life`, `sound`), `counter` (`var`; adds 1 to
  the variable when collected, and on its own also makes the object collectible), `hurt` (`stomp`, `damage` = lives
  taken), `health` (`hp`; defeated after that many hits, with a health bar above it), `goal`, `message` (`text`; says
  it when the player comes near), `lifetime` (`sec`; then disappears, blinking in the last second), `gravity`, `solid`,
  `bouncy` (`power`; a player who steps on it bounces), `spawn` (`what`, `every`, `max`), `shoot` (`every`, `aim`: when
  false, a turret that fires in the direction it faces without aiming at the player).
- **Event rule:** `{"on": event, "if": [conditions], "do": [actions]}`.
  - Events: `start`, `every {sec}`, `touch {a, b}`, `button {b}`, `score {n}`, `allgone {k}`, `var {name, n}` (once,
    when the variable reaches n), `timeup`, `lifelost`. Selectors: `@player`, `@enemy`, `@item`, `@goal`, `@brick`
    (breakables), `@any` or a `kind`.
  - Conditions: `cmp {a, op, b}` (a = score/lives/time/level or a variable name; op = `= != < > <= >=`),
    `count {k, op, n}`, `chance {p}`, `held {b}` (the button is being held).
  - Actions: `score {n}`, `life {n}`, `hurt {n}` (takes n lives from the player), `setvar {name, n}`,
    `addvar {name, n}`, `sound {s}`, `music {m}`,
    `say {text}`, `spawn {k, at}` (at = self/other/player/random), `destroy {w}`, `jump {w}` (w = self/other),
    `shake`, `flash` (a screen flash), `confetti {at}` (a burst of confetti), `teleport {w, at}` (moves the object
    there and stops it), `timer {n}`, `next`, `win`, `lose`, `restart`.
  - Their counterparts in the script API: `ws.held(action)`, `ws.flash([color])`, `ws.confetti(x, y[, z])`,
    `ws.teleport(object, x, y[, z])`, `ws.on("var", name, n, fn)`, `ws.hurt([n])`.
- **Library:** heroes (including Dog and Chick), enemies (including Caterpillar, Fish, Turtle and the Giant Jelly that
  takes five hits), collectibles (including Cherry, Banana, Cake, Potion and Clock), goals (including the Trophy) and
  decorations (including Cactus, Lantern, Jump Spring, Snowman, Palm Tree); Candy and Castle Stone tiles; Desert and
  Candy land backgrounds; in 3D, Snowman, Cactus, Barrel, Mushroom and Jump Spring; 22 synthesized sound effects
  (including Boing, Bell, Whoosh, Level up, Buzz, Splat, Click, Alarm). All of them are drawn by
  `tools/gen_workshop.py` and come out the same on every run.
- **Wizard data** (`library.json`): `genres` = `{"id", "template", "icon", "colors", "controls"}` (the template copied
  for the genre; `controls` = the player styles Quick Game offers, the first is the template's), `themes` = `{"id", "icon", "colors", "bg", "bgTop", "music", "sky", "ground", "kinds": {"cat": "penguin", ...},
  "tiles": {"grass": "snow", ...}}`. When a theme is applied (`ws::applyTheme`; its twin is `apply_theme` in
  `tools/lua_check.py`), a replaced object keeps the behaviours of its old kind; the kinds in `what` parameters and in
  event blocks (`a`, `b`, `k`) change too; in 2D the background is chosen by the view (`bg` for side view, `bgTop` for
  top-down); a theme's `groundTex` replaces the 3D ground's texture ("" removes it). Quick Game then applies its options
  (`ws::applyQuick`, twin `apply_quick`).
- **Textures** (`library.json` `textures`): `{"id", "cat", "name", "file", "scale", "color"}`, groups in `textureCats`.
  **Sounds** carry a `cat` (groups in `soundCats`) and `loop` for loops. **Ready setups** (`setups`): `{"id", "icon",
  "2d": {...}, "3d": {...}}`, each part with `objects` (`kind`, `dx`/`dy`/`dz` from the middle of the view, `beh`,
  `ifNoPlayer`), `player` (`style`, `kind` for every hero), `vars`, `events` (added when missing) and `settings`
  (merged); `ws::applySetup` and its twin `apply_setup` in `tools/lua_check.py` apply them.

## Runtime

Instead of generating code, the project JSON is interpreted directly (`nexvyn.workshop`):

- `ws.run{project = "bundle:/project.json", test = true|false}` returns the `game.run` app table. `test = true` (Play
  in the editor) skips the title screen and shows the red Stop button.
  The editor's play-test bundle wraps it in its `main.lua`: while the editor has the focus the game holds still (no
  pause menu), and each new `step` number the editor writes to `control.json` advances it by one frame (Step).
- 2D: the level becomes a `game.tilemap`; objects are a subclass of `game.Sprite` and join groups in `game.world`
  (`all`, `k:<kind>`, `player`, `enemy`, `item`, `goal`, `solid`, `body`). Behaviours add update functions and groups
  to the entity; collisions are set up with `world:collide` (event rules first, so a collected object also triggers
  the "touch" event).
- Textures: the runtime builds boxes and the ground with `g3d.custom` so the texture repeats (`mesh:setTexture`);
  `settings.dayNight` turns the sky, the fog and the light from day to night.
- 3D: `nexvyn.workshop3d` draws objects from the `library.json` "models" parts (g3d primitives) or from OBJ; there is
  gravity, axis-aligned box collision against solid objects, moving platforms that carry, a shadow disc, third-person /
  first-person / car control, fog and sky color.
- Event blocks compile to `ws.on(...)` calls. The same API is open to scripts too; the Code tab shows the Lua
  equivalent of the blocks. Object scripts can define `start()`, `update(dt)`, `touch(other)` and see `self`, `ws`,
  `game`. API: `ws.on`, `ws.score/addScore`, `ws.lives/addLife`, `ws.var/setVar/addVar`, `ws.time/addTime`,
  `ws.level`, `ws.say`, `ws.sound`, `ws.music`, `ws.spawn`, `ws.at`, `ws.destroy`, `ws.jump`, `ws.count`,
  `ws.player`, `ws.find`, `ws.shake`, `ws.chance`, `ws.win`, `ws.lose`, `ws.nextLevel`, `ws.restart`.
- The exported package contains: `app.json`, `main.lua` (3 lines), `project.json`, `icon.png`, the project's
  `sprites/ sounds/ models/ scripts/` folders, a copy of the runtime (`nexvyn/workshop*.lua`) and the library (`lib/`;
  of `sfx/` and `textures/` only the files the project names, plus the three effects the runtime plays itself).
  The copy in the package is loaded before the system's one, so the game runs the same on every Nexvyn OS.
- When a `.nxv3d` (or `.obj`) from 3D Modeling is imported, it is converted into an OBJ with vertex colors, its base
  at y = 0 and its longest side 1.

## Checking

`python tools/lua_check.py --workshop` runs every template and sample against the fake SDK both from the title screen
and in play-test mode; then it plays every genre of the wizard with every theme (17 × 7) in play-test mode, every genre
with Quick Game options (hard, one life, 60 s; easy with each other control style) and every Ready setup on the empty
2D / 3D templates and on a template that already has a hero.

---

## English summary

Game Engine (`gamemaker`, formerly Game Workshop) is a standalone game maker for 2D and 3D games, listed in the
**Developer** group next to Studio. The **Game wizard** builds a playable game in three steps: a genre (platformer,
top-down adventure, space shooter, puzzle, racing 3D, 3D runner), a theme (forest, snow, desert, cave, space, candy
land, ocean) that swaps the pictures, tiles, background, music and 3D colours of the genre's template, and a name. A
first-run guided tour (skippable, again from Help, Reduce motion respected), hints under every event block and on
every behaviour, a History panel that undoes everything since a chosen step, an autosave indicator, a check for a
missing hero before Play and kid-friendly error messages make it easier. Share offers "Share as app" (Documents
`.nxvapp` opened in the App Installer), "Add to Desktop" and "Open in Studio" (installed as a Lua app and opened in
Studio to go on in code). New behaviours: wander, counter (collect & count into a variable), health, message,
lifetime, trampoline; hurt has a damage, shoot a turret mode, the 3D player a runner style; new blocks: the "var"
event and the "take lives" action; end-screen win / lose texts; script mistakes show a red note instead of stopping
the game. **Easy** mode is touch-first: picture
template cards, a big-button library palette (drag or tap-to-place), tile painting, picture tiles that toggle
behaviours, a big green Play button, always-visible undo, animated first-use hints and a back button on every
screen. **Advanced** mode adds a numeric inspector, layers, behaviour parameters, Scratch-like event blocks
(events → conditions → actions, variables, timers), Studio's pixel sprite and tilemap editors, sounds, generated
Lua ("turn into code") and per-object Lua scripts.

**Quick Game** (the first home button) makes a ready, playable game from 17 genres (2D platformer, runner, flap
flight, brick breaker, space shooter, arena survival, adventure, maze, key puzzle, treasure hunt, catch rush, dodge; 3D
runner, racing, island adventure, collector, first-person maze escape) in a chosen world with difficulty, lives, time
limit and controls, and plays it in one tap. The Assets panel adds search, Textures (40 seamless materials for 3D
objects and the ground), Ready setups (14 one-tap bundles of objects and rules) and Recently used; the sound list is
grouped (89 effects, 67 of them from the new procedural effect library) and the Sound Maker synthesizes new effects
into the project. All of it is generated by our own scripts (`tools/gen_textures.py`, `tools/gen_sfx.py`).

Projects live in `~/Documents/Game Workshop/<name>/project.json` (format above). `<name>` is the title in plain letters
(`Yarış` → `Yaris`: the console's FAT driver reads parts of UTF-8 names as Shift-JIS and can not list or reach some of
them); the title in project.json keeps every letter and the files inside keep their names exactly. Games are not code-generated: the
`nexvyn.workshop` Lua runtime (on `nexvyn.game`; `nexvyn.workshop3d` for 3D on `g3d`) interprets the project JSON, and
event blocks compile to the same `ws.on(...)` API scripts use (newer blocks: `held` condition, `flash`, `confetti`
and `teleport` actions; templates Apple Race, Meteor Shower and Treasure Hunt). Play builds a portable bundle in
`Library/Caches/gamemaker/play` and launches it; Export writes a standalone `.nxvapp` (runtime and library copied in,
`manifest.sha256` included) to Documents; Add to Desktop installs it and drops a shortcut. All art and sounds are
generated by `tools/gen_workshop.py`. Five samples ship read-only (copied on first edit): *Kedi Macerası* (2D
platformer with a key/door event puzzle), *Penguen Macerası* (snowy platformer with trampolines, a crystal counter,
clocks and a giant slime that takes five stomps), *Yıldız Avcısı* (2D space shooter), *Altın Ada* (3D coin collector)
and *Robot Koşusu* (3D runner with turrets).
