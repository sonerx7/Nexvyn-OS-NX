# Game Engine Logic 2.0

Logic 2.0 (work package WP10) is the no-code behaviour system of the Game Engine. A beginner picks ready-made behaviours
from a library of 70+, each described in one sentence in 8 languages with sliders and pickers for its settings. Anyone
who wants more draws a **state machine** for an object (boxes and arrows, touch friendly), sends **messages** between
objects, writes reusable **functions**, and, when ready, turns any behaviour into readable **Lua** with "Open as code".

Everything is data first: a behaviour is a state machine, the editor draws it, the Lua runtime
(`romfs/System/Lua/nexvyn/ge_logic.lua`) runs it, the host core (`source/core/ge_logic.*`) validates it. Projects and
templates made before Logic 2.0 run unchanged (a Logic 2.0 behaviour is just another entry in an object's `beh` list).

## 1. Using it in the editor

* **Inspector, Add behaviour:** the classic behaviours, then **Behaviour library** (9 categories), then **State machine**
  (a machine of the object's own). The Simple layout has an **Add behaviour** button under its check list for the library.
  Every behaviour card shows its one-sentence description and its settings (sliders, pickers, switches).
* **Logic tab (Advanced layout):** the state machine of the selected object. Library behaviours are shown read-only
  (settings change in the inspector); **Make my own copy** turns one into a machine you can edit.
  * States are boxes (drag to move, tap to select), transitions are arrows with a label (tap the label to select).
  * **State** adds a state, **Link** then tap the state to leave and the state to go to adds a transition. The side panel
    renames a state, sets the start state, deletes it and edits its *When entering*, *Every frame* and *When leaving* actions.
  * A transition has *After (s)*, *When message*, *Only if* conditions and *Then do* actions. Tap a block to change its
    values; conditions can be negated.
  * The *Problems* list at the bottom is the runtime validator: unreachable states, endless loops, bad targets.
* **Open as code:** writes `scripts/object<N>.lua` for the object (the behaviour entry is replaced by the script) and opens
  the code editor. The script is the same machine as readable Lua data, started with `ws.machine(self, {...})`.
  An object that already has a script keeps it (the button only says so). Your own Lua can also attach a machine
  (`ws.machine(self, def)`) or send a message (`ws.send("name", "@all")`).

## 2. Data

An object's `beh` list (the v1 object format, carried unchanged by format v2 `Behaviour` / `StateMachine` components):

```json
{"t": "lg_chase", "speed": 50, "range": 160}                 // library behaviour, settings by name
{"t": "sm", "sm": {"initial": "idle", "states": [ ... ]}}    // a machine of the object's own
{"t": "machine", "id": "sentry"}                              // a machine of the project (project.logic.machines)
```

Project-wide pieces live in the optional `logic` block of the project: `{"machines": [...], "functions": [{"id": "cheer",
"do": [actions]}]}`. Format v2 keeps it as written (the v1 migration bookkeeping already preserves unknown keys), and
`behaviors.stateMachines` of format v2 uses the same machine shape.

A **machine** is `{initial, states}`; a **state** is `{id, enter, update, exit, transitions, x, y}` (`x`, `y` are the editor
position); a **transition** is `{to, if, on, after, do}`:

* `after` seconds in the state, `on` a message, `if` conditions that all hold; the first transition whose parts all hold
  fires. A transition with none of the three fires at once.
* `enter` and `exit` run when a state is entered or left, `update` every frame, `do` when the transition fires
  (order: exit, do, enter).

### Conditions (`{t, ...}`, `neg: true` negates)

`var` (variable compare), `dist` (distance to `@player`, `@enemy`, `@item`, `@any`), `touch`, `input` (`jump`, `fire`,
`use`, `talk`, `dash`, `sprint`, `down`, `move`; `pressed` or `down`), `timer`, `chance` (percent per second), `hp`, `time` (in
this state), `count` (objects of a kind), `list` (items in a list), `msg`, `ground`, `blocked`, `home` (distance from the
remembered start), `flag`, `sender`, `always`.

### Actions

`move` (forward, back, left, right, toward, away, home, input), `stop`, `turn`, `rotate`, `face`, `randomdir`, `markhome`,
`jump`, `steer`, `setvar`, `addvar`, `score`, `life`, `say`, `sound`, `music`, `anim`, `shake`, `flash`, `confetti`, `spawn`,
`destroy`, `send`, `scene`, `next`, `restart`, `save`, `win`, `lose`, `hurt`, `heal`, `timer`, `stoptimer`, `wait`, `call`,
`goto`, `push`, `pop`, `clear`, `fire`, `set`, `camera`, `teleport`, `spin`, `if` / `else`, `repeat`.
Variables starting with a dot (`.count`) belong to the object, all others are project variables. Lists are project wide.
`wait` pauses the rest of its list (not the machine): waits of a state are dropped when the state changes, waits of a
transition's `do` list keep running.

### Messages, functions, lists, timers

* **Messages:** `send` queues a message (`to`: `@all`, `@self`, `@other`, `@player`, `@enemy`, `@item`, a kind). It is
  delivered at the start of the next frame; a sender never gets its own message unless it sends to `@self`.
  A transition with `on` consumes it. The queue holds 256 messages.
* **Functions:** `{"id", "do": [...]}` in `project.logic.functions`, run with the `call` action; calls nest 12 deep.
* **Timers:** `timer` starts a named timer of the object, the `timer` condition is true when it ran out.
* **Parameters:** inside a library behaviour `"$speed"`, `"-$speed"`, `"$dist/$speed"`, `"$a*$b"`, `"$index-1"` are replaced
  with the setting's value when the behaviour is built.

### Guards (nothing in a machine can freeze the game)

At most 8 state changes per machine and frame (after the first change only unconditional transitions may follow, so one
button press cannot drive two changes), 4000 actions per machine and frame, function calls 12 deep, 256 queued messages,
64 pending waits. The validator names endless loops of changes that need no time, message or condition (`zero_loop`),
function call circles (`cycle`), bad targets, unreachable states and unknown block names. A machine with errors is skipped
by the runtime, never run half.

## 3. Behaviour library

Settings default per mode (2D pixels, 3D metres); sliders are clamped to their range. Behaviours marked `needsPhys` use
approximations of ground checks and aiming until the 3D collision API (WP6) is connected; 2D uses the existing collision.

<!-- behaviours:start (made by tools/ge_logic_src.py) -->
### Movement

| Behaviour | What it does | Parameters |
|---|---|---|
| `lg_patrol_pause` Patrol and look around | Walks a set distance, stops to look around, then walks back. | `speed`, `dist`, `pause` |
| `lg_patrol_square` Walk a square | Walks along the four sides of a square, again and again. | `speed`, `side` |
| `lg_wander_rest` Wander and rest | Walks in a random direction for a while, rests, then picks a new direction. | `speed`, `walk`, `rest` |
| `lg_chase` Chase the player | Waits until the player comes close, runs after them and gives up when they get far away. | `speed`, `range`, `lose` |
| `lg_flee` Run away | Runs away from the player when they come close and calms down when safe. | `speed`, `range`, `safe` |
| `lg_leash_guard` Guard the spot | Guards its spot, chases the player nearby, and walks back home when the chase goes too far. | `speed`, `range`, `leash` |
| `lg_orbit_point` Circle around | Moves in a circle around the place where it starts. | `speed`, `turn` |
| `lg_dash_attack` Charge attack | Gets ready, then dashes fast toward where the player stood, and rests. | `range`, `windup`, `speed`, `dash`, `rest` |
| `lg_sweep_turret` Sweeping turret | Turns left and right and shoots all the time. | `sweep`, `every`, `k`, `speed` |
| `lg_follow_pet` Follow like a pet | Stays put until the player walks away, then follows and stops close by. | `speed`, `near`, `far` |
| `lg_wall_turn` Turn at walls | Walks straight and turns around when it hits a wall. (needs 3D collisions to be exact: `needsPhys`) | `speed` |

### Hero abilities

| Behaviour | What it does | Parameters |
|---|---|---|
| `lg_hero_walk` Walk with the stick | Walks where the stick or arrows point and switches between idle and walk. | `speed` |
| `lg_hero_jump` Jump button | Jumps when the jump button is pressed, only while standing on the ground. | `power`, `sound` |
| `lg_double_jump` Double jump | Jumps from the ground and again in the air, as many times as you allow. | `power`, `extra`, `sound` |
| `lg_dash_hero` Dash | Dashes forward fast for a moment when the dash button is pressed, then needs a short break. | `speed`, `time`, `cooldown` |
| `lg_sprint` Sprint | Runs faster while the button is held down. | `mult`, `b` |
| `lg_shoot_button` Shoot button | Fires a shot when the fire button is pressed, with a short wait between shots. | `k`, `cooldown`, `speed`, `mode`, `sound` |
| `lg_melee_hit` Close attack | Hits the nearest enemy in reach when the attack button is pressed. | `range`, `damage`, `cooldown`, `target` |
| `lg_charge_shot` Charge shot | Hold the button to charge, let go to shoot; a long hold fires a bigger shot. | `k`, `big`, `full`, `speed` |
| `lg_push_block` Pushable | Slides away for a moment when the player pushes against it. | `speed`, `time` |
| `lg_ground_pound` Ground pound | Press down in the air to slam into the ground and hurt enemies around. (needs 3D collisions to be exact: `needsPhys`) | `power`, `radius`, `damage` |

### Items, doors and traps

| Behaviour | What it does | Parameters |
|---|---|---|
| `lg_pickup_coin` Collectible | Gives points when the player touches it, plays a sound and disappears. | `points`, `life`, `sound` |
| `lg_pickup_key` Key | Adds a key when touched; a key opens a locked door. | `var`, `sound`, `text` |
| `lg_pickup_heal` Health pickup | Heals the player when touched, then disappears. | `amount`, `sound` |
| `lg_pickup_power` Power-up for a while | Switches a power on for some seconds when touched, then switches it off again. | `var`, `sec`, `sound` |
| `lg_pickup_magnet` Flies to the player | Floats toward the player when close and gives points when it arrives. | `range`, `speed`, `points` |
| `lg_door_key` Locked door | Stays shut until the player has a key and is close, then opens for good. | `var`, `need`, `near`, `sound` |
| `lg_door_switch` Door with a switch | Opens when it receives the open message and closes on the close message. | `open`, `close`, `sound` |
| `lg_pressure_plate` Pressure plate | Sends a message when stepped on and another when stepped off. | `on`, `off`, `who` |
| `lg_lever` Lever | Press the use button next to it to flip it on or off and send a message. | `on`, `off` |
| `lg_moving_platform` Moving platform | Slides back and forth and waits a moment at each end. | `speed`, `dist`, `pause` |
| `lg_blink_platform` Blinking platform | Is solid for a while, blinks as a warning, vanishes, and then comes back. | `on`, `off` |
| `lg_crumble_platform` Crumbling platform | Shakes when the player steps on it and falls apart a moment later. | `delay` |
| `lg_trap_spikes` Spike trap | Hides, warns, then pops up and hurts anyone who touches it. | `down`, `up`, `damage` |
| `lg_trap_drop` Falling trap | Hangs until the player comes close, then falls and crashes down. (needs 3D collisions to be exact: `needsPhys`) | `range`, `damage` |
| `lg_trampoline` Trampoline | Bounces the player high up when touched. | `power`, `sound` |
| `lg_teleporter` Teleporter | Sends the player to the object with the name you choose. | `target`, `cooldown`, `sound` |
| `lg_checkpoint_save` Checkpoint | Saves the spot when touched, shows a note and plays a sound. | `text`, `sound` |
| `lg_goal_win` Goal that needs all items | Wins the level when touched, but only after the items are collected. | `left`, `sound` |
| `lg_exit_when_clear` Exit opens when clear | Stays closed until there are no enemies left, then opens. | `k`, `text` |

### Health and damage

| Behaviour | What it does | Parameters |
|---|---|---|
| `lg_hp_damage` Health and damage | Has health, loses some when touched by enemies, is safe for a moment after, and dies at zero. | `hp`, `invuln`, `from`, `amount`, `lose` |
| `lg_hp_regen` Heal over time | Slowly gets health back, up to a limit. | `every`, `amount`, `max` |
| `lg_hurt_zone` Damage zone | Hurts the player again and again as long as they stand in it. | `damage`, `every` |
| `lg_death_loot` Drops loot | When its health runs out it drops items, gives points and vanishes. | `k`, `count`, `points` |
| `lg_boss_phases` Boss in phases | Gets faster and shoots more as its health drops, in three phases. | `hp`, `speed`, `k`, `fury` |
| `lg_lives_respawn` Lives and respawn | When it dies it loses a life and returns to its start; no lives left ends the game. | `hp` |

### Enemy brains

| Behaviour | What it does | Parameters |
|---|---|---|
| `lg_aim_fire` Aim and fire | Sees the player, takes aim, fires, then reloads before the next shot. | `range`, `cooldown`, `k`, `speed` |
| `lg_guard_alarm` Sound the alarm | Shouts an alert to all enemies when it sees the player. | `range`, `msg`, `calm` |
| `lg_guard_alert` Join the hunt | Waits quietly and hunts the player for a while when an alert arrives. | `speed`, `msg`, `time` |
| `lg_ambush` Ambush | Hides until the player gets close, then jumps out and attacks. | `range`, `speed`, `time` |
| `lg_kamikaze` Explodes on contact | Runs at the player and explodes on touch. | `range`, `speed`, `damage` |
| `lg_healer_ally` Friendly healer | Heals the player now and then while they stay close. | `range`, `every`, `amount` |

### Spawning

| Behaviour | What it does | Parameters |
|---|---|---|
| `lg_spawner_timed` Spawn every few seconds | Creates a new object every few seconds, up to a maximum. | `k`, `every`, `max` |
| `lg_spawner_waves` Enemy waves | Sends waves of enemies, each bigger than the last, with a rest in between. | `k`, `first`, `add`, `rest`, `waves` |
| `lg_spawner_near` Spawn when close | Creates objects only while the player is nearby. | `k`, `range`, `max`, `cool` |
| `lg_spawn_on_message` Spawn on message | Creates objects whenever it receives a message. | `k`, `msg`, `count` |

### Game flow

| Behaviour | What it does | Parameters |
|---|---|---|
| `lg_turn_based` Turn-based move | Waits for its turn, acts when the button is pressed or time runs out, and passes the turn on. | `order`, `count`, `time`, `b` |
| `lg_inventory_item` Goes in the bag | Is picked up into the player's bag when touched, if there is room. | `item`, `list`, `max`, `sound` |
| `lg_inventory_use` Use from the bag | Uses the first item in the bag when the use button is pressed. | `list`, `amount` |
| `lg_dialogue` Talk to it | Says up to three lines, one more each time the talk button is pressed near it. | `range`, `text1`, `text2`, `text3` |
| `lg_npc_routine` Townsperson routine | Stands, strolls, and waves at the player when they come close. | `speed`, `idle`, `walk`, `near` |
| `lg_quest_collect` Collect quest | Watches a counter and rewards the player when it reaches the goal. | `var`, `goal`, `reward`, `msg`, `text` |
| `lg_race_gate` Race gate | A numbered gate: gates must be passed in order, and enough laps win the race. | `index`, `count`, `laps` |
| `lg_time_limit` Time limit | Counts down and ends the game when the time is up. | `sec`, `text` |
| `lg_survive_score` Points for surviving | Gives points every second while it is alive. | `every`, `points` |
| `lg_relay_message` Pass a message on | Waits for one message and sends another one, maybe after a delay. | `in`, `out`, `to`, `delay` |
| `lg_timer_loop` Message every few seconds | Sends a message again and again at a fixed time step. | `every`, `msg`, `to` |
| `lg_chain_explode` Chain explosion | Explodes when touched or when a neighbour blows up, and sets off the others. | `fuse`, `radius`, `damage` |
| `lg_bomb_fuse` Bomb with a fuse | Blinks while the fuse burns, then explodes and hurts anyone close. | `fuse`, `radius`, `damage` |

### Vehicles and balls

| Behaviour | What it does | Parameters |
|---|---|---|
| `lg_car_drive` Drive a car | Hold the button to drive, steer left and right, coast to a stop, and boost on a boost pad. | `speed`, `steer`, `boost`, `b` |
| `lg_boost_pad` Boost pad | Gives the car that touches it a short burst of speed. | `msg`, `cool` |
| `lg_physics_ball` Rolling ball | Gets knocked away when touched and slows down as it rolls. (needs 3D collisions to be exact: `needsPhys`) | `speed` |

### Camera

| Behaviour | What it does | Parameters |
|---|---|---|
| `lg_cam_third` Third-person camera | The camera follows behind and above the player. (3D only) | `dist`, `height` |
| `lg_cam_top` Top-down camera | The camera looks down on the player from above. | `dist` |
| `lg_cam_side` Side-view camera | The camera follows the player from the side. | `dist` |
| `lg_cam_shake_on_hit` Shake when hurt | Shakes the screen whenever the player gets hurt. | `power` |

<!-- behaviours:end -->

## 4. Checks

* `python tools/ge_logic_check.py` (also `python tools/lua_check.py --logic` and the N2 gate): engine tests (state changes,
  messages, timers, waits, functions, loop guards), one deterministic test per behaviour in the real Lua runtime, the
  validator cases shared with the C++ test, the catalog rules (sentence, labels, icons, tests) and the generated Lua of
  "Open as code".
* `tests/test_gelogic.cpp`: validator (shared cases `tests/fixtures/ge_logic/validate.json`), library builds, parameters,
  message queue, timers, step guard, code generation.
* `python tools/ge_logic_src.py --check`: `behaviors.json`, the language files and this table match the source.
* `python tools/lua_check.py --workshop` plays every template and sample (including `logic_lab`) and reports any script or
  logic error the player would see as a red note.
