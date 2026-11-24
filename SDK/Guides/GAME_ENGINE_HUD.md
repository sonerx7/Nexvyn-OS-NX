# Game Engine: HUD, menus, controls and save slots (WP14)

The HUD tab of the Game Engine edits three optional sections of a project: `hud`, `inputMap` and `saveSchema` (project
format v2, `docs/GAME_ENGINE_FORMAT_V2.md`; a v1 project file may carry them too). A project without them runs exactly as
before: the built-in HUD, the built-in title and end screens, the built-in controls. Nothing here adds an SDK surface:
the runtime uses `game.input.bind` (the OS input router), `fs` and `json`.

Code: `source/core/ge_hud.{h,cpp}`, `ge_inputmap.{h,cpp}`, `ge_save.{h,cpp}` (pure logic), `source/apps/ge_hud_panel.{h,cpp}`
(the tab), `romfs/System/Lua/nexvyn/ge_hud.lua` (runtime, same maths as the C++ core), thin hooks in `workshop.lua`,
`workshop3d.lua` and `ge_logic.lua`. Python twin of the validators: `tools/ge_hud.py` (called by `tools/ge_schema.py`).

## Units and screens

All HUD sizes are **units**: the pixels of the game surface before it is scaled to the window (480x270 in 2D projects,
640x360 in 3D). One unit is `scale` window pixels. Handheld (1280x720) and docked (1920x1080) show the same surface at a
different scale, so an anchored layout cannot break between them; a wider window (21:9) grows the surface and anchors
follow the edges. Everything is placed inside a **safe area** (`hud.safe`, a fraction of the shorter side, default 0.035,
0..0.15). A box never leaves the surface, whatever the offsets say.

Touch targets are at least 44 points (window pixels): `minTouch = 44 / scale` units, enforced for interactive elements
(inventory), menu buttons and list rows, and for every touch control (radius never below 22 pixels).

## HUD elements (`hud.elements`)

`{id, type, anchor, x, y, w, h, bind, max, label, text, color, icon, size, cols, rows, visible}`.

| type | shows | bind / max |
|---|---|---|
| `healthbar` | bar, turns to the warning colour under 25% | variable / number or variable (default 100) |
| `score` | icon and number | variable |
| `timer` | `m:ss`, warning colour in the last 5 seconds | variable (`@timeleft`) |
| `ammo` | `value/max` | variable / number |
| `minimap` | level outline, player and enemy dots (2D and 3D) | none |
| `objective`, `dialogue`, `hint`, `text` | text, `{name}` is replaced by a variable's value | none |
| `inventory` | `cols` x `rows` grid (max 12x12), cells fit inside the box | none |
| `progress` | bar | variable / max |

`anchor` is one of `tl t tr l c r bl b br`; `x` and `y` are offsets inward from the anchored edge (from the centre for `c`).
`bind` names a project variable or one of `@score @lives @health @timeleft @time @level`. NaN, infinite or missing
values draw as 0; a bar's fraction is clamped to 0..1. A bad element is skipped (a note in the play test), never fatal.
Scripts can use the inventory: `ws.give(name[, n])`, `ws.take(name[, n])`, `ws.has(name[, n])`, `ws.items()`.

## Menus (`hud.screens`)

Screens `main`, `pause`, `gameover`, `settings`, `levels`: `{align: left|center|right, transition: none|fade|slide|pop,
blocks: [...]}`. Blocks are building blocks, **not a finished menu**: `title`, `text`, `button {label, action}`, `list
{source: levels|slots, rows}`, `panel`, `spacer`. The "start with a few blocks" button creates a title and a few buttons
in the editor's language; the maker (or the AI) changes the words, order, look and layout. Button actions: `play resume
restart menu controls settings levels save load back quit save:N load:N level:N`. The blocks stack top to bottom; the
stack shrinks (spacing, then text, never below 60%) until it fits the safe area, buttons keep the 44 pt minimum while there is
room. In the game, `main` replaces the title screen, `gameover` the end screen and `pause` the engine's pause list; the
`controls` action opens the engine's re-map screen (the player picks an action and presses the new key or button; the
choice is saved with the engine settings).

**Style presets** (`hud.style`) are starting points: palette, font, corner radius, border and animation. `pixel`, `neon`,
`paper`, `military`, `fantasy`, `minimal`, `noir`. Any of `palette {bg, panel, text, accent, warn}`, `font` (sans, serif,
mono, pixel), `size`, `corner` overrides the preset. Games should not look alike: pick or build your own look.

## Controls (`inputMap`)

`{version, deadzone (0..0.9), sensitivity (0.1..4), actions: {<name>: {kind, pad[], key[], mouse[], touch[]}}, touch:
{opacity, items: [{id, kind: stick|button, action, x, y, scale}]}}`. Built-in actions: `move`, `look` (axes), `jump`,
`attack` (runtime name `fire`), `interact` (`use`), `dash`, `pause`. Other names are allowed. Tokens: pad `a b x y l r zl zr
plus minus up down left right lstick rstick dpad`; keys one character or `space enter escape backspace tab lshift ...`,
`wasd`, `arrows`; mouse `left right middle`; touch `button:<id>`, `stick:left|right|up|down|move`.

* **Conflicts**: the same physical input on two actions of one device (`wasd` counts as four keys) is reported as the
  warning `conflict`; the editor's add-a-binding menu moves the input instead of creating one.
* **Dead zone / sensitivity**: radial dead zone, the rest of the range stretched to 0..1, then sensitivity, length clamped.
* **Touch layout**: positions are fractions of the window, so handheld and docked share one layout. Drag a control in the
  preview; it stays on screen, overlaps are marked. The runtime reads optional `fx`, `fy`, `scale` on the OS touch buttons
  and `stickFx`, `stickFy`, `stickScale`, `opacity` on the control set (`game/input.lua`, additive).
* **Script access**: `ws.action("jump")` (held), `ws.action("jump", "pressed")`, `"released"`, `ws.action("move", "axis")` -> x, y.
  Without an input map the same call answers the built-in names, so v1 templates run unchanged. Multiple pads and the
  relative mouse come from the OS input router (`input.padCount`, `input.padDown`, SDK 1.13); the map names inputs
  of "a pad", the router decides which one.

## Saving (`saveSchema`)

`{version, slots (1..9), autosave, allVars, vars[], scene, position, inventory, documentsCopy, migrate}`. Files:
`~/Library/Application Support/<app id>/Game Engine/Saves/<game>/auto.json` and `slot1.json` ... `slotN.json`
(`<game>` = the project id, made safe). That is the game's own data folder: always writable, no permission needed.

* The editor's play test runs as `workshop.playtest`, the exported game under its own id, so their saves never mix.
  The Save page of the HUD tab lists the play test's slots and has **Reset test saves**.
* `documentsCopy: true` also writes each save to `Documents/Game Engine/Saves/<game>/`. The exported game then declares
  the `files` permission; if the user says no, the copy is skipped and saving still works. The copy is never read back.
* The main menu shows **Continue** while a usable save exists: it loads the newest one (menu action `continue`; a project
  screen that places its own `continue` button keeps it where it is).

```
{"format": "nexvyn-ge-save", "version": 1, "game": "...", "schema": 1, "slot": 1, "savedAt": 1700000000,
 "data": {"vars": {...}, "scene": 2, "pos": {"x": 0, "y": 0, "z": 0}, "inventory": [{"name": "key", "count": 1}]}}
```

* `vars` lists what is saved (`@score` and `@lives` are allowed); `allVars` saves every project variable.
* **Atomic**: step 1 keeps the current file (when it parses) as `.bak`, step 2 replaces the slot file (`fs.write` writes a
  temp file and renames it). A power cut before any step leaves the old slot; a damaged file loads from `.bak`; a damaged
  file never replaces a good `.bak`.
* **Versions**: `schema` is the project's `saveSchema.version`. A save of a newer schema or file format is refused
  (`Newer`) and left untouched; an older one is migrated by `migrate["<from>"] = {rename: {old: new}, drop: [...],
  defaults: {name: value}}` one version at a time, or refused (`Stale`) when a step has no rule. Saves of another game are refused.
* **Behaviour blocks**: the Logic action `save` (slot: `checkpoint` (the old behaviour), `auto`, `1`..`3`) and the new action
  `load` (slot `auto`, `1`..`3`). Scripts: `ws.save(slot)`, `ws.load(slot)` (slot 0 = auto). Autosave runs at the start of each level.
* A broken, empty or foreign slot shows a note ("Empty slot", "This save cannot be used") and the game goes on.

## Validation

`ge_schema` issue codes for the three sections (same in C++ and Python, cases in `tests/fixtures/ge_hud/cases.json`):
`type`, `range`, `enum`, `required`, `duplicate_id`, `too_many`, and the warnings `bad_ref` (a variable the project lacks),
`unknown_type`, `unknown_action`, `unknown_input`, `conflict`, `version` (made by a newer engine). Unknown fields are kept.
v1 round trip: `lower()` writes non-empty sections into the v1 view, `migrate()` reads them back, `carryOver()` keeps the
file's own when the editor's view has none; odd values (a number instead of an object) come back exactly.

## Tests

`tests/test_gehud.cpp` (layout on handheld, dock, wide and 3D surfaces; bindings; inventory grid fuzz; menu fit for every
preset; conflicts, re-map, dead zone, touch layout; save round trip, a power cut before every step, torn files, migration,
newer / foreign saves, random corruption; validation cases), `tests/test_ge_hud.py`, `tools/ge_hud_check.py` (the Lua module
in lupa: the same layout fixture `tests/fixtures/ge_hud/layout.json`, saves with a simulated file system that fails at
every step, a runtime smoke test of the HUD, menus, action map, inventory and slots).
