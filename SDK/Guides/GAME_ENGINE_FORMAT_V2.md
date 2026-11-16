# Game Engine project format v2 (`nexvyn-ge`)

Format v2 is the scene / entity-component project model of Game Engine 2 (plan: `docs/plans/GAME_ENGINE_2_PLAN.md`
section 2.2, work package WP4). v1 (`nexvyn-workshop`, `docs/GAME_ENGINE_PROJECTS.md`) keeps opening forever.

| Part | Where |
|---|---|
| Registry, validator, migration, lowering, prefabs, file migration | `source/core/ge_schema.{h,cpp}` |
| Python twin (same rules and issue codes; CLI) | `tools/ge_schema.py` |
| Format guard (refuses newer files) | `source/core/ge_guard.*` (`kGeVersion = 2`) |
| Editor and runtime hook | `ws::loadProject` / `ws::saveProject` / `ws::buildBundle` (`source/apps/workshop_doc.cpp`) |
| Shared fixtures | `tests/fixtures/ge_schema/` (`cases.json`, `registry.json`, `good_project/`) |
| Tests | `tests/test_geschema.cpp` (host), `tests/test_ge_schema.py` (`tools/n2_gate.py`), `lua_check.py --workshop` |

## 1. Files

```
<project>/
  project.json        format "nexvyn-ge", version 2
  project.v1.json     the v1 file as it was before the first migration (only in migrated projects; kept forever)
  project.json.bak    the previous good project.json (written by every save, as in v1)
  prefabs/<name>.json prefab files (format "nexvyn-ge-prefab", version 1)
  sprites/ sounds/ models/ scripts/   as in v1
```

Scenes stay inside `project.json` in this version, so a save is one atomic file write.

## 2. `project.json`

| Field | Type | Required | Meaning |
|---|---|---|---|
| `format` | string | yes | `"nexvyn-ge"` |
| `version` | int | yes | `2`. Raised by hand only when older v2 readers would damage a file; never derived from the OS or module version |
| `mode` | `"2d"` \| `"3d"` | yes | as in v1 |
| `title`, `titleEn`, `id`, `template`, `genre`, `theme`, `script` | string | no | as in v1 |
| `settings` | object | no | as in v1 (`view`, `lives`, `gravity`, `camera`, `sky`, `difficulty`, ...) |
| `vars` | array of `{name, value, hud}` | no | project variables (a duplicate name is a warning) |
| `layers` | array of `{name, nameEn}` | no | entity `layer` is an index into it |
| `assets` | object | no | `sprites`, `models`, `sounds`: the v1 lists of the project's own files (`{name, file, ...}`) |
| `packs` | array of `{id, version}` | no | asset packs the project uses (`docs/GAME_ENGINE_PACKS.md`); `id`: `a-z 0-9 . _ -`, `version`: text or int, ids unique |
| `behaviors` | object | no | extensible; `stateMachines` (below) |
| `scenes` | array | yes | the levels, in order |
| `audio`, `hud`, `inputMap`, `saveSchema` | object | no | defined placeholders for WP13 / WP14; kept as written |
| `wizard` | object | no | `{design, generator}` written by the offline wizard (`docs/GAME_ENGINE_WIZARD.md`): the design JSON the project was made from, kept as written |
| `v1extra`, `v1keys`, `v1omit` | object / string arrays | no | migration bookkeeping (section 5) |

### State machines (`behaviors.stateMachines[]`)

| Field | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | unique |
| `scope` | string | no | `"project"` for the project machine; entity machines are referenced by a `StateMachine` component |
| `initial` | string | no | must name a state |
| `states` | array of `{id, rules, enter, exit, transitions}` | yes | `id` unique; `rules` = v1 event rules (`{on, if, do}`); `transitions[].to` must name a state |

The v1 event rules become the project machine `{"id": "game", "scope": "project", "initial": "main", "states":
[{"id": "main", "rules": [...]}]}`.

Logic 2.0 (WP10, `docs/GAME_ENGINE_LOGIC.md`) machines use the same `states` / `transitions` shape with more fields:
a state may carry `enter`, `update` and `exit` action lists and editor coordinates `x`, `y`; a transition may carry `if`
(conditions), `on` (a message), `after` (seconds) and `do` (actions). A machine is checked by `ge_logic::validateMachine`
(same rules as the Lua runtime: duplicate or missing states, unreachable states, endless loops of changes that need no wait,
message or condition). Objects use library behaviours as `Behaviour` components with `id` `lg_<behaviour>` (the settings are
the `params`), their own machine as `{"t": "sm", "sm": {...}}`, project machines through the `StateMachine` component, and
project-wide functions through the `logic` block (`{"machines": [...], "functions": [{"id", "do"}]}`), which v1 <-> v2
migration keeps as written.

### Scenes (`scenes[]`)

| Field | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | unique (migration: `s1`, `s2`, ...) |
| `kind` | `"2d"` \| `"3d"` | no | the project mode at migration |
| `name`, `nameEn`, `background` | string | no | as in v1 |
| `ground` | object | no | 3D ground, as in v1 |
| `tilemap` | `{cols, rows, tiles}` | no | 2D tiles as in v1; `cols` / `rows` 1-4096, `tiles` strings |
| `entities` | array | yes | the scene's entities |

### Entities (`scenes[].entities[]`)

| Field | Type | Required | Meaning |
|---|---|---|---|
| `id` | int >= 0 or string | yes | unique in the scene (v1 object ids are kept) |
| `name` | string | no | |
| `parent` | entity id | no | must exist in the scene, no loops; the lowering adds the parents' positions (translation only for now) |
| `transform` | object | no | `position` [x, y] or [x, y, z]; `rotation` [x, y, z] degrees (v1 `ry` = y, `rot` = z); `scale` [x, y, z]; numbers within ±1e7 |
| `tags` | string array | no | |
| `layer` | int >= 0 | no | index into `layers` (an index past the list is a warning: v1 tolerates it) |
| `prefab` | string | no | name of `prefabs/<name>.json` |
| `overrides` | object | no | changes to the prefab (section 4) |
| `libBehaviours` | bool | no | `true`: the library's default behaviours of the kind apply (v1 object without `beh`) |
| `components` | array of `{type, ...}` | no | below; unknown types are a warning and are kept |
| `v1extra`, `v1keys`, `v1omit`, `v1raw` | | no | migration bookkeeping (section 5) |

Euler degrees instead of a quaternion keep v1 values exact and are what the controller gizmos edit; a quaternion can be
added as a new field later without a version bump.

### Component registry

Types and ranges are checked by `ge_schema::validate`; fields not listed are kept.

| Component | Fields (required in bold) |
|---|---|
| `Model` | **`kind`** string (library id, `obj:<name>` or `pack:` path), `tex` string, `color` `#RRGGBB` |
| `Sprite` | **`kind`** string, `flip` bool, `frame` int 0-1023 |
| `Collider` | **`shape`** box/sphere/capsule/mesh, `size` vec3 0-1e4, `offset` vec3 ±1e4, `trigger` bool |
| `Body` | **`mode`** static/kinematic/dynamic, `mass` 0-1e4 |
| `Controller` | **`style`** platform/top/ship/runner/flap/paddle/walk/fps/car/kart/flyer/thirdperson/pointclick, `speed` 0-1e3, `jump` 0-1e4 |
| `Behaviour` | **`id`** string (a v1 behaviour `t`), `params` object (the v1 parameters) |
| `StateMachine` | **`machine`** string (must name a `behaviors.stateMachines` id), `initial` string |
| `Script` | **`file`** string (v1 `scriptFile`) |
| `Light` | **`kind`** point/spot/directional, `color` `#RRGGBB`, `intensity` 0-100, `range` 0-1e4 |
| `Camera` | `fov` 1-179, `near` 0.001-1e3, `far` 0.01-1e6, `follow` bool |
| `AudioSource` | **`sound`** string, `volume` 0-1, `loop` bool, `spatial` bool |
| `Particles` | **`preset`** string, `rate` 0-1e4 |
| `Timeline` | `preset` string, `duration` 0.05-600 s, `loop` once/loop/pingpong, `autoplay` bool, `trigger` string, `onEnd` string, `speed` 0-20, `tracks` array, `events` array |
| `Animator` | `graph` string (preset), `initial` string, `params` object, `states` array, `transitions` array |
| `CameraRail` | `preset` string, `duration` 0.1-600 s, `ease` string, `play` enter/end/trigger/none, `trigger`, `onEnd`, `points` array |
| `Trigger` | **`shape`** box/sphere, `size` vec3 0-1e4, `once` bool |
| `Spawner` | **`what`** string, `every` 0-3600 s, `max` int 0-1000 |
| `Inventory` | `slots` int 0-256 |
| `Health` | **`hp`** 0-1e6, `regen` 0-1e4 |
| `Dialogue` | **`lines`** array |
| `NavAgent` | `speed` 0-100, `radius` 0-100 |
| `HudAnchor` | **`anchor`** topleft/top/topright/left/center/right/bottomleft/bottom/bottomright, `offset` vec3 ±1e4 |
| `SaveState` | **`key`** string |

`python tools/ge_schema.py registry` prints the registry; `tests/fixtures/ge_schema/registry.json` pins it for both
languages.

## 3. Validation

`ge_schema::validate(project, text, prefabs)` / `ge_schema.validate(...)` return issues `{severity, code, path, message,
line}`: `path` is a JSON pointer (`/scenes/0/entities/3/transform/position`), `line` the 1-based line in `text`.
Codes: `format`, `version`, `required`, `type`, `range`, `enum`, `duplicate_id`, `bad_ref`, `cycle`,
`unknown_component` (warning). Unknown fields are never an issue. Prefab files: `validatePrefab`. Broken input
(wrong types anywhere, deep nesting, prefab loops) returns issues and never crashes (fuzzed in both tests).

## 4. Prefabs

`prefabs/<name>.json`:

```json
{"format": "nexvyn-ge-prefab", "version": 1, "name": "door",
 "entities": [{"id": 1, "components": [{"type": "Model", "kind": "door", "tex": "wood"}]},
              {"id": 2, "parent": 1, "transform": {"position": [0.5, 1, 0]}, "components": [{"type": "Model", "kind": "handle"}]}]}
```

The first entity is the root; the others form its tree (`parent` ids inside the prefab). An instance in a scene:

```json
{"id": 10, "prefab": "door", "transform": {"position": [4, 0, 0]},
 "overrides": {"name": "front door", "components": {"Model": {"tex": "iron"}}}}
```

- The instance's own `id`, `name`, `parent`, `layer`, `tags` and `transform` win over the root's.
- `overrides` is a JSON merge patch (RFC 7386) on the root. `overrides.components` is either an array (replaces the
  list) or an object keyed by `"Type"` / `"Type#n"` (the n-th component of that type): an object patches it, `null`
  removes it, a type not present is added.
- The other prefab entities get new ids after the scene's highest id, in file order; nested prefabs (also as the root)
  expand up to 8 levels; a prefab that contains itself is an error, never a hang.
- Missing prefabs never stop opening: the issue is reported and the instance shows its own components, if any.

## 5. Migration v1 -> v2 and lowering v2 -> v1

`ge_schema::migrate(v1)` maps:

| v1 | v2 |
|---|---|
| `levels[]` | `scenes[]` (`id` `s<n>`, `kind` = mode) |
| level `cols`, `rows`, `tiles` | `tilemap` |
| object `id` | entity `id` (a missing or repeated id gets a new number; the v1 value is restored on lowering) |
| `x`, `y`, `z` | `transform.position` |
| `ry`, `rot` | `transform.rotation[1]`, `[2]` |
| `sx` (2D) / `s` or `sx` (3D) | `transform.scale` |
| `kind` (+ `flip` in 2D, `tex` in 3D) | `Sprite` (2D) / `Model` (3D) component |
| `beh` | one `Behaviour` component per item; no `beh` = `libBehaviours: true` |
| `scriptFile` | `Script` component |
| `events` | project state machine `game` |
| `sprites`, `models`, `sounds` | `assets` |
| everything else | copied as it is |

`ge_schema::lower(v2)` is the exact inverse and also expands prefabs and parents. **Lossless rule:**
`lower(migrate(v1)) == v1` with `format` / `version` set to `nexvyn-workshop` / 1, for any input. Values v2 cannot
hold yet are kept on the node they belong to: `v1extra` (fields and odd values, restored as written), `v1keys` (fields
v1 wrote with their default value, such as `"z": 0`), `v1omit` (fields v1 did not have), `v1raw` (an array item that
was not an object). The 19 templates and 7 samples migrate without any of them; the tests run odd v1 files (repeated
and missing ids, wrong types, unknown fields, 2D/3D scale variants) through the same round trip.

Proof that games play the same: every template and sample is migrated, validated, lowered and compared with the
original (`tests/test_geschema.cpp`: same document, same level and object count, same FNV-1a summary hash; 24/24),
and `lua_check.py --workshop` plays each lowered project in play-test mode (`<key>-v2-test`).

## 6. Reading and saving in the app

| On disk | Setting `gameengine.projectV2` | Load | Save |
|---|---|---|---|
| v1 | off (default) | as today | v1, as today |
| v1 | on | as today | first save: copy to `project.v1.json` (if missing), then v2 atomically |
| none (new project) | on | - | v2 (no backup needed) |
| v2 | any | lowered to the v1 view | v2: `migrate(view)` + everything only the old v2 file had (`ge_schema::carryOver`) |
| newer (`version` > 2 or unknown format) | any | refused (`gamemaker.err_newer`) | refused, file untouched |

`carryOver` matches scenes by index and entities by id. An entity the editor did not change is written back exactly;
a changed one takes the v1 fields from the editor and keeps its tags, parent (the position becomes local again),
prefab link (component edits go to `overrides`), hidden components and unknown fields. Children made by a prefab
instance are not written as separate entities (edit them in the prefab).

Power cuts: each step is an atomic write (`atomic_file`). Cut before the backup: nothing changed. Cut after the backup:
`project.json` is still v1 and opens as before; the next save migrates. `project.v1.json` is never overwritten or
deleted. Older builds refuse a v2 file through the WP0 guard (unknown format), so they cannot damage it.

**No export back to v1.** To return, copy `project.v1.json` over `project.json`; edits made after the migration are
lost. Exported games always contain the lowered v1 `project.json` and the embedded v1 runtime, so they run unchanged on
every Nexvyn OS.

## 7. Command line

```
python tools/ge_schema.py validate <project folder | project.json | prefab.json>
python tools/ge_schema.py migrate <v1 project.json> <out.json>
python tools/ge_schema.py lower <v2 project.json> <out.json>
python tools/ge_schema.py builtin          # templates and samples: migrate, validate, lower == original (24/24)
python tools/lua_check.py --workshop-project <folder>   # validate and play one project (v1 or v2)
```
