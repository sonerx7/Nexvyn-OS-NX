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
  Golden Island, Robot Run). The samples are read-only; on the first change they are copied into the `Oyunlarım`
  folder. The green ▶ button on My Games cards opens and starts a game with one tap. A long press on a game (or X /
  right click) opens a menu with Open, Rename, Duplicate, Move to Trash.
- **Game wizard:** three steps. 1) Genre: Platformer, Adventure (top-down), Space battle, Puzzle, Racing 3D, Runner 3D.
  2) World (theme): Forest, Snow, Desert, Cave, Space, Candy land, Ocean; every card shows that world's background and
  hero. 3) Name. "Build my game!" copies the genre's template, applies the theme (characters, enemies, collectibles,
  decorations, tiles, background, music; sky and ground color in 3D) and opens a game you can play right away.
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
| `romfs/System/Lua/nexvyn/workshop.lua` | runtime: project loading, events, API, 2D scene, title / end screen |
| `romfs/System/Lua/nexvyn/workshop3d.lua` | 3D scene (g3d) |
| `romfs/System/Workshop/` | `library.json` (including the wizard's `genres` and `themes` lists), `art/`, `tiles.png`, `bg/`, `sounds/`, `Templates/`, `Samples/` |
| `tools/gen_workshop.py` | generates the whole library, the templates and the samples (Pillow) |
| `romfs/Applications/gamemaker.app/lang/{tr,en,de,fr,es}.json` | interface strings (`gamemaker.*`) |

Every picture and sound is generated by code with `tools/gen_workshop.py`; there are no ready-made external assets.
Sound effects are 48 kHz stereo WAV (the mixer's format; no conversion needed). Music is not files but synthesized
tunes played with `game.audio.song`.

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
  `settings.camera`: `"follow"` or `"fixed"`. `settings.winText` / `settings.loseText`: the words shown under "You
  won!" / "Game over" on the end screen. Games made with the wizard also store `genre` and `theme` (for information).
- **2D level:** `{"name", "background": "sky", "cols": 60, "rows": 17, "tiles": ["....1111", ...], "objects": [...]}`.
  `tiles` is one string per row: `.` empty, `1`…`9`, `a`…`z` = tile number 1…35 (`library.json` "tiles": `solid`,
  `oneway`, `hazard`, `ice`). A tile is 16 units.
- **3D level:** `{"name", "ground": {"size": 30, "color": "#7FCB6A"}, "objects": [...]}`. The unit is meters, y is up,
  the ground is at y = 0.
- **Object:** `{"id": 7, "kind": "cat", "x": 40, "y": 200, "z": 0, "flip": false, "sx": 1, "s": 1, "rot": 0,
  "ry": 0, "layer": 1, "name": "kapi", "beh": [{"t": "player", "style": "platform"}], "scriptFile":
  "scripts/object7.lua"}`. `kind` is a library id, `spr:<name>` (your own drawing) or `obj:<name>` (an imported 3D
  model). Without `beh`, the default behaviours from the library are used. In 2D, x, y is the center of the picture.
- **Behaviours** (`t` and optional parameters): `player` (`style`: platform/top/ship, in 3D walk/fps/car/runner; the
  runner runs forward by itself and the stick only shifts it left and right; `speed`, `jump`), `patrol` (`speed`,
  `dist`), `wander` (`speed`; wanders in random directions), `jumper` (`every`, `power`), `follow` (`speed`, `range`),
  `spin` (`speed`), `move` (`vx`, `vy`; `vz` in 3D), `collect` (`points`, `life`, `sound`), `counter` (`var`; adds 1 to
  the variable when collected, and on its own also makes the object collectible), `hurt` (`stomp`, `damage` = lives
  taken), `health` (`hp`; defeated after that many hits, with a health bar above it), `goal`, `message` (`text`; says
  it when the player comes near), `lifetime` (`sec`; then disappears, blinking in the last second), `gravity`, `solid`,
  `bouncy` (`power`; a player who steps on it bounces), `spawn` (`what`, `every`, `max`), `shoot` (`every`, `aim`: when
  false, a turret that fires in the direction it faces without aiming at the player).
- **Event rule:** `{"on": event, "if": [conditions], "do": [actions]}`.
  - Events: `start`, `every {sec}`, `touch {a, b}`, `button {b}`, `score {n}`, `allgone {k}`, `var {name, n}` (once,
    when the variable reaches n), `timeup`, `lifelost`. Selectors: `@player`, `@enemy`, `@item`, `@goal`, `@any` or a
    `kind`.
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
- **Wizard data** (`library.json`): `genres` = `{"id", "template", "icon", "colors"}` (the template copied for the
  genre), `themes` = `{"id", "icon", "colors", "bg", "bgTop", "music", "sky", "ground", "kinds": {"cat": "penguin", ...},
  "tiles": {"grass": "snow", ...}}`. When a theme is applied (`ws::applyTheme`; its twin is `apply_theme` in
  `tools/lua_check.py`), a replaced object keeps the behaviours of its old kind; the kinds in `what` parameters and in
  event blocks (`a`, `b`, `k`) change too; in 2D the background is chosen by the view (`bg` for side view, `bgTop` for
  top-down).

## Runtime

Instead of generating code, the project JSON is interpreted directly (`nexvyn.workshop`):

- `ws.run{project = "bundle:/project.json", test = true|false}` returns the `game.run` app table. `test = true` (Play
  in the editor) skips the title screen and shows the red Stop button.
- 2D: the level becomes a `game.tilemap`; objects are a subclass of `game.Sprite` and join groups in `game.world`
  (`all`, `k:<kind>`, `player`, `enemy`, `item`, `goal`, `solid`, `body`). Behaviours add update functions and groups
  to the entity; collisions are set up with `world:collide` (event rules first, so a collected object also triggers
  the "touch" event).
- 3D: `nexvyn.workshop3d` draws objects from the `library.json` "models" parts (g3d primitives) or from OBJ; there is
  gravity, axis-aligned box collision against solid objects, moving platforms that carry, a shadow disc, third-person /
  first-person / car control, fog and sky color.
- Event blocks compile to `ws.on(...)` calls. The same API is open to scripts too; the Code tab shows the Lua
  equivalent of the blocks. Object scripts can define `start()`, `update(dt)`, `touch(other)` and see `self`, `ws`,
  `game`. API: `ws.on`, `ws.score/addScore`, `ws.lives/addLife`, `ws.var/setVar/addVar`, `ws.time/addTime`,
  `ws.level`, `ws.say`, `ws.sound`, `ws.music`, `ws.spawn`, `ws.at`, `ws.destroy`, `ws.jump`, `ws.count`,
  `ws.player`, `ws.find`, `ws.shake`, `ws.chance`, `ws.win`, `ws.lose`, `ws.nextLevel`, `ws.restart`.
- The exported package contains: `app.json`, `main.lua` (3 lines), `project.json`, `icon.png`, the project's
  `sprites/ sounds/ models/ scripts/` folders, a copy of the runtime (`nexvyn/workshop*.lua`) and the library (`lib/`).
  The copy in the package is loaded before the system's one, so the game runs the same on every Nexvyn OS.
- When a `.nxv3d` (or `.obj`) from 3D Modeling is imported, it is converted into an OBJ with vertex colors, its base
  at y = 0 and its longest side 1.

## Checking

`python tools/lua_check.py --workshop` runs every template and sample against the fake SDK both from the title screen
and in play-test mode; then it plays every genre of the wizard with every theme (6 × 7) in play-test mode.

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

Projects live in `~/Documents/Oyunlarım/<name>/project.json` (format above). Games are not code-generated: the
`nexvyn.workshop` Lua runtime (on `nexvyn.game`; `nexvyn.workshop3d` for 3D on `g3d`) interprets the project JSON, and
event blocks compile to the same `ws.on(...)` API scripts use (newer blocks: `held` condition, `flash`, `confetti`
and `teleport` actions; templates Apple Race, Meteor Shower and Treasure Hunt). Play builds a portable bundle in
`Library/Caches/gamemaker/play` and launches it; Export writes a standalone `.nxvapp` (runtime and library copied in,
`manifest.sha256` included) to Documents; Add to Desktop installs it and drops a shortcut. All art and sounds are
generated by `tools/gen_workshop.py`. Five samples ship read-only (copied on first edit): *Kedi Macerası* (2D
platformer with a key/door event puzzle), *Penguen Macerası* (snowy platformer with trampolines, a crystal counter,
clocks and a giant slime that takes five stomps), *Yıldız Avcısı* (2D space shooter), *Altın Ada* (3D coin collector)
and *Robot Koşusu* (3D runner with turrets).
