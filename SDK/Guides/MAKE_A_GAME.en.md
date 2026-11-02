# Make a game: the complete recipe (SDK 1.8)

**English** · [Türkçe](MAKE_A_GAME.tr.md)

This guide takes you, or an AI assistant working for you, from an empty folder to a finished game in the App Market:
project, 3D models, sound, game structure, collision, speed on the Switch, an art direction of your own, the store
icon, languages and publishing. Every code block here was run through the SDK checkers (`lua_check.py`,
`js_check.mjs`, `py_check.py`); every function is in the [SDK reference](../Reference/SDK.en.md). If something is not in
the reference, it does not exist.

A complete small game made exactly this way ships with the SDK: **Ember Field** (Studio template *3D Game: Ember
Field*, `SDK/Samples/lua/ember-field` in the public repository). Read its `main.lua` next to this guide. Do not copy its
look: section 11 explains why and how to find your own.

## Contents

1. [Choose the path](#1-choose-the-path)
2. [Set up the project](#2-set-up-the-project)
3. [Run and test](#3-run-and-test)
4. [3D models: make, export, check](#4-3d-models-make-export-check)
5. [Loading without freezing](#5-loading-without-freezing)
6. [Animation and attachments](#6-animation-and-attachments)
7. [Images and fonts](#7-images-and-fonts)
8. [Sound and rumble](#8-sound-and-rumble)
9. [Game structure: scenes, input, camera, collision, saving, pause](#9-game-structure)
10. [Speed and memory on the Switch](#10-speed-and-memory-on-the-switch)
11. [Make it yours: art direction](#11-make-it-yours-art-direction)
12. [Store icon and key art](#12-store-icon-and-key-art)
13. [Languages](#13-languages)
14. [Publish](#14-publish)
15. [The same loop in JavaScript and Python](#15-the-same-loop-in-javascript-and-python)

## 1. Choose the path

| You want | Use | Start from |
|---|---|---|
| A 2D game (platformer, shooter, puzzle) | Lua + the `nexvyn.game` engine: scenes, sprites, tilemaps, physics, particles, tweens | [GAME_ENGINE.en.md](GAME_ENGINE.en.md), Studio templates *Platform Game*, *Arena Shooter* |
| A 3D game with models made in a 3D tool | Lua (or JavaScript, Python) + `g3d` and `g3d.loadModel` | this guide, template *3D Game: Ember Field* |
| A block world | JavaScript + `g3d.voxels` (chunks, light, ray casts, box physics) | SDK reference 8b, *Voxel worlds* |

**Languages.** New APIs come to Lua, JavaScript, Python and C. Squirrel and Java are frozen at SDK 1.8: their apps
keep working, but nothing new is added to them, so do not start a new game in them. Lua has the most samples and
Studio's editors; JavaScript has Promises (`await g3d.loadModel(...)`); Python (pocketpy) is slower. C is compiled on
the console and runs without the script safety net (no time limit, no sandbox), so it is for experts only.

## 2. Set up the project

**On the console:** open *Nexvyn OS Studio*, *New Project*, pick a template, name it, press **Run** (Ctrl+R).
**On a PC:** `python SDK/Tools/nxv/nxv.py new lua "Sky Hop" --author yourname` makes a folder from the Lua template.

Folder layout of a 3D game:

```
SkyHop.nxvapp/
├── app.json
├── main.lua              entry point; more modules next to it (require("collide") loads collide.lua)
├── icon.png              256 x 256 key art (section 12)
├── lang/en.json          English: required
├── lang/de.json ...      any other languages you want (section 13)
├── models/hero.glb       3D models (section 4)
├── img/                  2D images, sprite sheets, a bitmap font
└── sfx/ music/           .wav / .ogg / .mp3
```

`app.json` for a game made today:

```json
{
  "id": "com.yourname.skyhop",
  "name": {"en": "Sky Hop"},
  "description": {"en": "Hop across floating islands"},
  "version": "1.0",
  "author": "Your Name",
  "category": "games",
  "icon": "icon.png",
  "main": "main.lua",
  "window": {"width": 1280, "height": 720, "minWidth": 640, "minHeight": 360, "resizable": true},
  "gamepad": true,
  "minSdk": "1.8",
  "targetSdk": "1.8",
  "permissions": []
}
```

- `"gamepad": true` sends the controller to the game (the player holds L+R to get the cursor back) and
  `"resizable": true` opens a game full screen.
- `minSdk` is the newest SDK feature you use: `g3d.model` / `g3d.loadModel` need **1.8**. `targetSdk` is the SDK you
  tested on: with 1.8, a callback that runs too long ends the game with the error screen (section 5).
- `permissions`: `[]` unless you really use `net.*` (`"network"`) or another gated call. Every permission is
  enforced, and the store review asks why you need each one.
- `name` and `description` can carry more languages (`{"en": "Sky Hop", "es": "Salto Celeste"}`); English is enough.

## 3. Run and test

1. **In Studio:** Run (Ctrl+R) restarts the app with your changes; `print()` and errors show in Studio's console.
2. **On the PC, before every upload:** `python SDK/Tools/nxv/nxv.py check SkyHop.nxvapp` checks the manifest,
   permissions, translations and store files. With `--sdk <Nexvyn OS checkout>` it also runs the language checker,
   which plays the game for hundreds of frames against a mock SDK with random input, in English and in every
   language you ship.
3. **On the console:** start the FTP server in *Connect to PC*, then
   `python SDK/Tools/nxv/nxv.py push SkyHop.nxvapp --host <console-ip>`. Errors show in the window with the line
   number and go to `sdmc:/NexvynOS/System/Logs/Apps/<id>.log`.
4. **In the Ryujinx emulator:** `python SDK/Tools/nxv/nxv.py install SkyHop.nxvapp` copies the game into the
   emulator's SD card. To replay a test without touching anything, put `sdmc:/NexvynOS/autorun.txt` there:

   ```
   wait 2
   launch com.yourname.skyhop
   wait 4
   shot title
   dpad a
   wait 3
   shot play
   ```

   Screenshots land in `sdmc:/NexvynOS/autoshots/`. Delete `autorun.txt` afterwards, it runs at every start.
   Ryujinx is fine for logic and looks; measure speed on a real console (section 10).

## 4. 3D models: make, export, check

**Tools.** Any 3D program that exports glTF 2.0 or FBX works, and so do AI model generators. Model, rig and animate
there; the game only loads the result. `.glb` (binary glTF) is the best format: one file with the mesh, the
skeleton, the clips and the textures. `.fbx` works too (its axes and units are converted when it loads); `.obj` and
`.stl` have no animation.

**Export checklist**

| Item | Rule |
|---|---|
| Units and scale | 1 unit = 1 metre. A person is about 1.7 m. Apply scale and rotation before you export |
| Axes | glTF: +Y up (the exporter's default). The model looks along **+Z** in the game, towards the default camera; in a Z-up tool that is "front" (-Y) |
| Pivot | At the feet, in the middle: the model's origin is where it stands. `g3d.model(path, size)` also scales a model and stands it on y = 0 |
| Clip names | Short and clear: `Idle`, `Run`, `Jump`, `Attack`. A clip is found by name without case and without the armature prefix FBX adds (`"Rig|Run"` matches `"run"`) |
| Bone names | Name the bones you attach things to: `hand_R`, `head`, a bone without vertices as a socket (`Lamp`, `Muzzle`) |
| Textures | Embed them in the `.glb` (or keep them next to the file). Only the **base colour** texture is drawn; normal, metallic, roughness and emissive maps are ignored. An emissive *colour* (without a map) draws the material unlit and bright: visors, lamps, lava |
| Texture size | 512 x 512 for props, 1024 x 1024 for the hero, 2048 at most; powers of two. Bake lighting and detail into the colour map |
| Triangles | Hero 3 000 - 8 000, enemies 1 000 - 4 000, props 50 - 1 500, a level 20 000 - 50 000 in total (section 10) |
| Bones | Up to 32 bones are skinned in one draw on the GPU; a bigger skeleton is split into several draws. 20 - 40 bones is plenty for a character; 4 weights per vertex |
| Not supported | Morph targets (blend shapes), cameras and lights in the file. Cubic spline keys play linearly. Bake constraints and IK into the clips |

**AI-generated models** usually come with too many triangles, a messy pivot and no clean skeleton. Decimate to the
budget above, set the pivot at the feet, rig and name the clips in a 3D tool, then export `.glb`. Use a generator
whose terms let you publish its output, and keep a note of it for your store README (section 14).

**A model made from a script.** Ember Field's hero was built and animated in Blender by a script:
`art/make_models.py` next to the sample (`tools/gen_ember_models.py` in the source repository). It shows the whole
recipe in about 150 lines: parts at real size, each part weighted to one bone, an extra bone as a socket, three
actions, and the export call:

```python
bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                          export_animations=True, export_animation_mode="ACTIONS", export_texcoords=False)
```

Run it headless: `blender -b --factory-startup -P make_models.py -- <out folder>`.

**Check the model in the game** before you build anything around it. `model:info()` tells you what was loaded:

```lua
local m, err = g3d.model("bundle:/models/hero.glb")
if not m then print(err) else
  local i = m:info()
  print(i.format, i.triangles, i.bones, i.skinning, i.size.w, i.size.h, i.size.d)
  for _, a in ipairs(i.animations) do print(a.name, a.duration) end
end
```

`skinning` is `"gpu"` when the skeleton is skinned on the GPU. If the model is huge, tiny or lying down, fix the
export (scale, +Y up) instead of patching it in code. Studio's *3D Models* template is a quick viewer for your files.

## 5. Loading without freezing

Nexvyn OS stops a callback that runs for more than **3 seconds**; the main file's top level and `app.load` get **10
seconds**. With `"targetSdk": "1.8"` the game then ends with the error screen; an older app gets the *"…" is not
responding* question (Wait / Close). Neither is a state you want a player to see, so:

- **Load models with `g3d.loadModel`.** It reads and parses the file on a background thread (one model at a time)
  and calls you back like a timer. The window keeps drawing your loading screen. `g3d.model` does the same work while
  the game waits: fine for a tiny file, wrong for a level.
- **Split your own long work into slices.** A coroutine that yields, resumed for a few milliseconds per frame.
- Load images once (`gfx.image` caches them), never in `draw`.

A loader with a queue, a loading scene and a time-sliced job (all from the guide's tested bundle):

```lua
local assets = {}
local queue = {
  {name = "hero", path = "bundle:/models/hero.glb"},
  {name = "rock", path = "bundle:/models/rock.glb", size = 1.0},
}
local loaded, failed = 0, nil

local function loadAll(done)
  for _, item in ipairs(queue) do
    local function finish(m, err)
      if m then assets[item.name] = m else failed = item.path .. ": " .. tostring(err) end
      loaded = loaded + 1
      if loaded == #queue and done then done() end
    end
    if item.size then g3d.loadModel(item.path, item.size, finish)
    else g3d.loadModel(item.path, finish) end
  end
end

-- long work in small slices: a coroutine that yields, resumed for at most 4 ms per frame
local job
local function startJob(fn) job = coroutine.create(fn) end
local function runJob()
  if not job then return end
  local stop = os.clock() + 0.004
  while job and os.clock() < stop do
    local ok, err = coroutine.resume(job)
    if not ok then print("job failed: " .. tostring(err)); job = nil
    elseif coroutine.status(job) == "dead" then job = nil end
  end
end
```

```lua
scenes.loading = {}
function scenes.loading:enter()
  loadAll(function() if not failed then go("title") end end)
  startJob(buildTerrain)              -- buildTerrain calls coroutine.yield() after every row
end
function scenes.loading:draw(w, h)
  gfx.clear("#101014")
  gfx.color("#FFFFFF")
  if failed then gfx.wrap(TR("load_failed", failed), 40, 40, w - 80, 16)
  else gfx.text(TR("loading", loaded, #queue), 40, h - 60, 16, "mono") end
end
```

Call `runJob()` at the top of `app.update`. Ember Field goes further: its title screen is already playing while the
models load, and *Play* stays grey until they arrive.

## 6. Animation and attachments

```lua
hero:play("Run", {loop = true, speed = 1.2, fade = 0.2})   -- crossfade from the current pose in 0.2 s
hero:update(dt)                                             -- once per frame, for every model you animate
```

- Change clips only when the state changes, not every frame (calling `play` again restarts the fade).
- A one-shot clip: `hero:play("Hop", {loop = false, fade = 0.06})`; when `hero:playing()` turns false it stopped at
  its last frame, so pick the next clip then (Ember Field's `Hop`).
- `speed` follows the movement: `{speed = 0.7 + speed * 0.12}` keeps the feet from sliding.
- Each `g3d.model()` / `g3d.loadModel()` handle animates on its own and shares the file's data, so ten enemies from
  one file cost one load.

**Attachments.** `model:nodeMatrix(bone, x, y, z, rx, ry, rz, sx, sy, sz)` gives the bone's matrix in the world when
the model is drawn with that placement; draw anything there with `g3d.drawMatrix`:

```lua
g3d.draw(assets.hero, player.x, player.y, player.z, 0, player.yaw, 0)
local m = assets.hero:nodeMatrix("hand_R", player.x, player.y, player.z, 0, player.yaw, 0)
if m and assets.rock then g3d.drawMatrix(assets.rock, m) end
```

`model:node(name, ...)` returns just the position: spawn a projectile at the muzzle, a dust puff at a foot.

## 7. Images and fonts

- `gfx.image("bundle:/img/sky.png")` loads PNG, JPG, WEBP, BMP or GIF once and caches it; `gfx.draw(img, x, y, w, h)`
  draws it, `gfx.drawRegion(img, sx, sy, sw, sh, x, y, w, h[, angleDeg])` draws a part (sprite sheets).
- On 3D meshes: `mesh:setTexture("bundle:/img/wood.png")` with the mesh's UVs; pixels below 50 % alpha are cut out.
- 2D games: `nexvyn.game` sheets and animations ([GAME_ENGINE.en.md](GAME_ENGINE.en.md)).

**Fonts.** Scripts draw text with the system fonts: `"sans"`, `"medium"`, `"semibold"`, `"bold"`, `"italic"`,
`"mono"`, `"monobold"`, at any size. There is no call that loads a `.ttf` from your bundle. For a typeface of your
own: make your logo an image (it is part of your key art anyway), and draw other text with a **bitmap font**, a PNG
with the characters 32-127 in rows of 16 cells:

```lua
-- a bitmap font: a PNG with the characters 32..127 in rows of 16 cells (cw x ch pixels each)
function T.bitmapText(img, s, x, y, cw, ch, scale)
  scale = scale or 1
  for i = 1, #s do
    local c = s:byte(i) - 32
    if c >= 0 and c < 96 then
      gfx.drawRegion(img, (c % 16) * cw, math.floor(c / 16) * ch, cw, ch, x, y, cw * scale, ch * scale)
    end
    x = x + cw * scale
  end
end
```

The system fonts also go a long way with letter spacing, case and an offset second print (see Ember Field's
`spaced`); `nexvyn.game` adds a 3x5 pixel font (`game.ui.pixelText`). Bitmap fonts cover only the characters you
drew: keep translated text in a system font, or draw the letters every language needs.

## 8. Sound and rumble

| Call | Use |
|---|---|
| `audio.play("bundle:/sfx/jump.wav", volume, loops)` → channel | effects; `loops = -1` repeats (engine hum, rain) until `audio.stop(channel)` |
| `audio.tone(freq, seconds, volume, wave)` | synthesized notes: `"sine"`, `"square"`, `"saw"`, `"triangle"`, `"noise"`; a whole retro sound set without files |
| `audio.music("bundle:/music/theme.ogg")` | one streamed song; `audio.musicPause(true/false)`, `audio.musicStop()` |
| `game.audio` (`nexvyn.game`) | named effects from notes, a looping synth tune (`song`), mute |

- The mixer runs at 48 kHz stereo with 24 channels. Effects are decoded once and kept in memory: short `.wav` or
  `.ogg` files (mono is enough), 48 kHz so nothing is resampled. Music is streamed: `.ogg` (or `.mp3`).
- **Loops:** cut music loops on a zero crossing with no silence at the ends, or the seam clicks.
- **Mixing:** there is no volume call for a song that is already playing, so master the music file quieter than
  the effects (about -14 LUFS for music, effects peaking near -3 dB) and give the player *music on / off*
  (`audio.musicPause`) plus an effects volume you pass to every `audio.play`.
- One sound family per game: the same instrument, the same room. Several sounds of one action, picked at random,
  keep repeats from sounding mechanical.
- Everything a game plays stops when its window closes.

**Rumble:** `sys.vibrate(strength 0..1, ms)`, at most 2000 ms, only while the window has focus; `sys.vibrate(0)`
stops it. There are no frequency patterns. Short and light for pickups (0.2-0.3, 40 ms), strong for hits (0.8, 150
ms), and an off switch in your settings.

## 9. Game structure

### Scenes (states)

A table per scene and one `go` function; each scene has `enter`, `update`, `draw`:

```lua
local scenes, current = {}, nil
local function go(name, params)
  if current and current.leave then current:leave() end
  current = scenes[name]
  if current.enter then current:enter(params) end
end
```

```lua
function app.update(dt)
  dt = math.min(dt, 1 / 20)                              -- a long frame must not tunnel through walls
  runJob()
  if current.update then current:update(dt) end
  A.endFrame()
end

function app.draw(w, h) current:draw(w, h) end
function app.event(e) A.event(e, gfx.size()) end
function app.suspend() paused = true; saveSettings(); store.set("save", save) end
function app.focus(focused) if not focused then paused = true end end
```

Typical scenes: loading, title, play, pause (an overlay inside play), game over, settings. `nexvyn.game` has this
built in for 2D games (`game.switch`, `game.push`, `game.pop`, transitions).

### Input: actions, not buttons

Players use the Joy-Con, a Pro Controller, the touch screen or a keyboard. Read actions, never raw buttons, so every
one of them works and can be remapped. `actions.lua`:

```lua
-- actions.lua: one input layer for the controller, the keyboard and touch (needs "gamepad": true in app.json)
local A = {}

-- each action lists the pad buttons and keys that trigger it; let the player change these in your settings
A.bind = {
  confirm = {pad = {"a"}, key = {"enter", "space"}},
  back    = {pad = {"b"}, key = {"escape", "backspace"}},
  pause   = {pad = {"plus"}, key = {"escape", "p"}},
  jump    = {pad = {"b", "a"}, key = {"space", "k"}},
  dash    = {pad = {"zr", "r"}, key = {"j", "l"}},
}

local held, hit = {}, {}            -- "pad:a" / "key:space" -> true
local touch = {on = false, x0 = 0, y0 = 0, x = 0, y = 0, tap = false}
A.touch = touch

function A.event(e, w)
  if e.type == "paddown" and e.pad then held["pad:" .. e.pad] = true; hit["pad:" .. e.pad] = true
  elseif e.type == "padup" and e.pad then held["pad:" .. e.pad] = nil
  elseif e.type == "keydown" and e.key then held["key:" .. e.key] = true; hit["key:" .. e.key] = true
  elseif e.type == "keyup" and e.key then held["key:" .. e.key] = nil
  elseif e.type == "mousedown" and e.x then
    if e.x < (w or 1280) / 2 then           -- left half: a stick that starts where the finger lands
      touch.on, touch.x0, touch.y0, touch.x, touch.y = true, e.x, e.y, e.x, e.y
    else touch.tap = true end               -- right half: a tap is "jump"
  elseif e.type == "mousemove" and touch.on and e.x then touch.x, touch.y = e.x, e.y
  elseif e.type == "mouseup" then touch.on = false end
end

local function any(tbl, name)
  local b = A.bind[name]
  if not b then return false end
  for _, p in ipairs(b.pad or {}) do if tbl["pad:" .. p] then return true end end
  for _, k in ipairs(b.key or {}) do if tbl["key:" .. k] then return true end end
  return false
end

function A.down(name) return any(held, name) end
function A.pressed(name) return any(hit, name) or (name == "jump" and touch.tap) end

-- the move vector: left stick, D-pad, WASD / arrows or the touch stick; x right, y down (screen), length <= 1
function A.move()
  local x, y = input.stick("left")
  y = -y                                    -- the stick reports up as positive
  if held["pad:left"] or held["key:left"] or held["key:a"] then x = -1 end
  if held["pad:right"] or held["key:right"] or held["key:d"] then x = 1 end
  if held["pad:up"] or held["key:up"] or held["key:w"] then y = -1 end
  if held["pad:down"] or held["key:down"] or held["key:s"] then y = 1 end
  if touch.on then
    local dx, dy = touch.x - touch.x0, touch.y - touch.y0
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 8 then x, y = dx / math.max(len, 60), dy / math.max(len, 60) end
  end
  local len = math.sqrt(x * x + y * y)
  if len > 1 then x, y = x / len, y / len end
  return x, y
end

-- call at the end of app.update: "pressed" lasts one update
function A.endFrame()
  for k in pairs(hit) do hit[k] = nil end
  touch.tap = false
end

return A
```

Show the controls in the game (on the title screen or a first-play hint), draw touch controls only after the screen
was touched, and keep **+** for pause. `input.motion()` gives the gyroscope for aiming or steering.

### Camera and movement

A third-person camera that the right stick turns, with movement relative to it and gravity onto a heightmap:

```lua
function scenes.play:update(dt)
  if A.pressed("pause") then paused = not paused end
  if paused then return end
  -- camera: right stick turns it (invert Y is a setting)
  local rx, ry = input.stick("right")
  camYaw = camYaw - rx * 2.2 * dt
  camPitch = math.max(0.1, math.min(1.2, camPitch + (settings.invertY and ry or -ry) * 1.5 * dt))
  -- move relative to the camera: forward is away from it
  local mx, my = A.move()
  local fx, fz = -math.sin(camYaw), -math.cos(camYaw)
  local rxv, rzv = -fz, fx
  local vx, vz = (rxv * mx - fx * my) * 5, (rzv * mx - fz * my) * 5
  player.x, player.z = player.x + vx * dt, player.z + vz * dt
  if vx * vx + vz * vz > 0.1 then player.yaw = math.atan(vx, vz) end
  -- gravity and the ground
  if player.onGround and A.pressed("jump") then player.vy = 6; player.onGround = false; rumble(0.2, 40) end
  player.vy = player.vy - 18 * dt
  player.y = player.y + player.vy * dt
  local g = C.groundHeight(hm, player.x, player.z) or 0
  if player.y <= g then player.y, player.vy, player.onGround = g, 0, true end
  -- animation follows the state
  local hero = assets.hero
  if hero then
    local want = not player.onGround and "Jump" or (vx * vx + vz * vz > 0.5 and "Run" or "Idle")
    if want ~= player.clip then
      player.clip = want
      hero:play(want, {loop = want ~= "Jump", fade = 0.15})
    end
    hero:update(dt)
  end
end
function scenes.play:draw(w, h)
  gfx.clear("#9CC3D5")
  local cx = player.x + math.sin(camYaw) * math.cos(camPitch) * camDist
  local cz = player.z + math.cos(camYaw) * math.cos(camPitch) * camDist
  local cy = player.y + math.sin(camPitch) * camDist
  g3d.begin(0, 0, w, h, 60, 0.1, 80)
  g3d.camera(cx, cy, cz, player.x, player.y + 1, player.z)
  g3d.light(-0.4, 1, 0.3, 0.4)
  g3d.fog("#9CC3D5", 25, 70)
  if terrain then g3d.draw(terrain, 0, 0, 0) end
  if assets.hero then
    g3d.draw(assets.hero, player.x, player.y, player.z, 0, player.yaw, 0)
    local m = assets.hero:nodeMatrix("hand_R", player.x, player.y, player.z, 0, player.yaw, 0)
    if m and assets.rock then g3d.drawMatrix(assets.rock, m) end
  end
  g3d.finish()
  if paused then
    gfx.color("#000000AA")
    gfx.rect(0, 0, w, h)
    gfx.color("#FFFFFF")
    gfx.text(TR("paused"), w / 2, h / 2 - 20, 32, "bold", "center", 0)
  end
end
```

`math.atan(vx, vz)` turns a direction into the yaw for `g3d.draw` (a model looks along +Z at yaw 0). A follow
camera that eases towards its target (`cam.x = cam.x + (target - cam.x) * 0.12`) and a short shake on hits give most
of the "feel"; Ember Field uses both.

### Collision

What the SDK has: box physics and ray casts in `g3d.voxels` (JavaScript block worlds); bodies, tile collision,
groups, triggers and `game.physics` helpers in `nexvyn.game` (2D). For a 3D game with `g3d` you write a few
functions; that is enough for most games. Use spheres for characters, boxes for crates and walls (`model:info()`
gives a model's `min` / `max`), and a heightmap for the ground. `collide.lua`:

```lua
-- collide.lua: simple 3D collision for g3d games (no physics engine needed)
local C = {}

-- sphere vs sphere: true when they overlap
function C.spheres(ax, ay, az, ar, bx, by, bz, br)
  local dx, dy, dz = ax - bx, ay - by, az - bz
  local r = ar + br
  return dx * dx + dy * dy + dz * dz < r * r
end

-- box vs box; a box is {x0, y0, z0, x1, y1, z1} (min and max corners)
function C.boxes(a, b)
  return a[1] < b[4] and a[4] > b[1] and a[2] < b[5] and a[5] > b[2] and a[3] < b[6] and a[6] > b[3]
end

-- a model's box at a position (model:info() gives min / max in model space; no rotation)
function C.modelBox(info, x, y, z, s)
  s = s or 1
  return {x + info.min.x * s, y + info.min.y * s, z + info.min.z * s,
          x + info.max.x * s, y + info.max.y * s, z + info.max.z * s}
end

-- sphere vs box: returns the push (dx, dy, dz) that moves the sphere out, or nil
function C.sphereBox(x, y, z, r, b)
  local cx = math.max(b[1], math.min(x, b[4]))
  local cy = math.max(b[2], math.min(y, b[5]))
  local cz = math.max(b[3], math.min(z, b[6]))
  local dx, dy, dz = x - cx, y - cy, z - cz
  local d2 = dx * dx + dy * dy + dz * dz
  if d2 >= r * r then return nil end
  if d2 < 1e-9 then return 0, r, 0 end              -- centre inside the box: push up
  local d = math.sqrt(d2)
  return dx / d * (r - d), dy / d * (r - d), dz / d * (r - d)
end

-- ray vs box (slab test): distance along the ray to the first hit, or nil. (dx, dy, dz) need not be normalised.
function C.rayBox(ox, oy, oz, dx, dy, dz, b)
  local t0, t1 = 0, math.huge
  local o, d = {ox, oy, oz}, {dx, dy, dz}
  for i = 1, 3 do
    if math.abs(d[i]) < 1e-9 then
      if o[i] < b[i] or o[i] > b[i + 3] then return nil end
    else
      local ta, tb = (b[i] - o[i]) / d[i], (b[i + 3] - o[i]) / d[i]
      if ta > tb then ta, tb = tb, ta end
      t0, t1 = math.max(t0, ta), math.min(t1, tb)
      if t0 > t1 then return nil end
    end
  end
  return t0
end

-- ray vs triangle (Moller-Trumbore): distance t, or nil. v = {x1,y1,z1, x2,y2,z2, x3,y3,z3}
function C.rayTriangle(ox, oy, oz, dx, dy, dz, v)
  local e1x, e1y, e1z = v[4] - v[1], v[5] - v[2], v[6] - v[3]
  local e2x, e2y, e2z = v[7] - v[1], v[8] - v[2], v[9] - v[3]
  local px, py, pz = dy * e2z - dz * e2y, dz * e2x - dx * e2z, dx * e2y - dy * e2x
  local det = e1x * px + e1y * py + e1z * pz
  if math.abs(det) < 1e-9 then return nil end
  local inv = 1 / det
  local tx, ty, tz = ox - v[1], oy - v[2], oz - v[3]
  local u = (tx * px + ty * py + tz * pz) * inv
  if u < 0 or u > 1 then return nil end
  local qx, qy, qz = ty * e1z - tz * e1y, tz * e1x - tx * e1z, tx * e1y - ty * e1x
  local w = (dx * qx + dy * qy + dz * qz) * inv
  if w < 0 or u + w > 1 then return nil end
  local t = (e2x * qx + e2y * qy + e2z * qz) * inv
  return t >= 0 and t or nil
end

-- heightmap: heights[j * n + i + 1] on an n x n grid of `step` metres starting at (x0, z0) (the same grid you gave
-- g3d.custom). Returns the ground height under (x, z), interpolated inside the cell's two triangles.
function C.groundHeight(hm, x, z)
  local fx, fz = (x - hm.x0) / hm.step, (z - hm.z0) / hm.step
  local i, j = math.floor(fx), math.floor(fz)
  if i < 0 or j < 0 or i >= hm.n - 1 or j >= hm.n - 1 then return nil end
  local u, v = fx - i, fz - j
  local function h(a, b) return hm.heights[(j + b) * hm.n + (i + a) + 1] end
  if u + v <= 1 then                                 -- triangle (a, b, c) of the cell
    return h(0, 0) + (h(1, 0) - h(0, 0)) * u + (h(0, 1) - h(0, 0)) * v
  end
  return h(1, 1) + (h(0, 1) - h(1, 1)) * (1 - u) + (h(1, 0) - h(1, 1)) * (1 - v)
end

-- ray vs heightmap: march in small steps, then refine; returns the hit point or nil
function C.rayGround(hm, ox, oy, oz, dx, dy, dz, maxDist)
  local len = math.sqrt(dx * dx + dy * dy + dz * dz)
  dx, dy, dz = dx / len, dy / len, dz / len
  local step, prev = hm.step * 0.5, 0
  for t = step, maxDist, step do
    local x, y, z = ox + dx * t, oy + dy * t, oz + dz * t
    local g = C.groundHeight(hm, x, z)
    if g and y <= g then
      local lo, hi = prev, t                         -- binary search between the last two steps
      for _ = 1, 8 do
        local mid = (lo + hi) / 2
        local gm = C.groundHeight(hm, ox + dx * mid, oz + dz * mid)
        if gm and oy + dy * mid <= gm then hi = mid else lo = mid end
      end
      return ox + dx * hi, oy + dy * hi, oz + dz * hi
    end
    prev = t
  end
  return nil
end

return C
```

The heightmap is the same grid you turn into the ground mesh, built in slices so loading never stalls:

```lua
local hm = {n = 48, step = 0.5, x0 = -12, z0 = -12, heights = {}}
local terrain
local function buildTerrain()
  local V, I, CC = {}, {}, {}
  for j = 0, hm.n - 1 do
    for i = 0, hm.n - 1 do
      local x, z = hm.x0 + i * hm.step, hm.z0 + j * hm.step
      local y = math.sin(x * 0.4) * math.cos(z * 0.3) * 0.8
      hm.heights[j * hm.n + i + 1] = y
      V[#V + 1], V[#V + 2], V[#V + 3] = x, y, z
      CC[#CC + 1] = {60, 120 + math.floor(y * 40), 80}
    end
    coroutine.yield()                                    -- one row per slice
  end
  for j = 0, hm.n - 2 do
    for i = 0, hm.n - 2 do
      local a = j * hm.n + i + 1
      local b, c, d = a + 1, a + hm.n, a + hm.n + 1
      I[#I + 1], I[#I + 2], I[#I + 3] = a, c, b
      I[#I + 1], I[#I + 2], I[#I + 3] = b, c, d
    end
  end
  terrain = g3d.custom(V, I, CC, true)
end
```

Rules that keep collision solid: clamp `dt` (a slow frame must not move things through a wall), resolve by pushing
out along the shortest way (`sphereBox` returns that push), test fast bullets with a ray from the old to the new
position, and keep a broad check first (a distance test before the triangle tests). For level geometry you made in a
3D tool, export a second, simple collision mesh (boxes, a low-poly ground) and keep its triangles in a Lua table for
`rayTriangle`: the drawn model's vertices are not readable from scripts.

### Saving and settings

`store` saves JSON-like values within a second and when the game suspends or closes:

```lua
local settings = store.get("settings", {music = 0.6, sfx = 0.8, rumble = true, invertY = false})
local function saveSettings() store.set("settings", settings) end
local save = store.get("save", {level = 1, best = 0, unlocked = {1}})

local function rumble(strength, ms)
  if settings.rumble then sys.vibrate(strength, ms) end
end
```

Save progress at checkpoints and in `app.suspend` / `app.autosave`. `nexvyn.game` has numbered save slots
(`game.save.slot(i)`). A settings screen worth having: music on/off, effects volume, rumble, invert camera Y, button
mapping (change `A.bind`), language follows the system.

### Pause

Pause on **+** (and Esc / P), when the console goes to the HOME menu or sleeps (`app.suspend`) and when the window
loses focus (`app.focus(false)`). In pause, stop the clock and the animations, keep drawing the frozen scene under
your pause screen. Never resume by itself.

## 10. Speed and memory on the Switch

**Measured** (SDK 1.8, GPU path, skinned models of 5 600 triangles with a 49 000-triangle statue in the scene): 16
animated models at 60 fps; 64 of them at about 33 fps in an emulator. On a console, aim for 60 fps with headroom.

| Budget per frame (guidelines for 60 fps) | |
|---|---|
| Triangles drawn | 30 000 - 60 000 in total (`g3d.finish()` returns the count) |
| Draw calls | keep them to about 150: every mesh of a model, every material and every 32-bone piece of a skeleton is one |
| Skinned characters on screen | 8 - 16 |
| Textures | 512 - 1024 px, 2048 at most; few large ones beat many small ones |
| Lights | one sun (`g3d.light`) and fog; fake the rest with emissive colours and `"glow"` halos |

- **Draw less.** Merge static props into one `g3d.custom` mesh, skip what is behind the camera or far away, use fog
  to hide the far clip plane, keep `far` as small as the scene allows.
- **Allocate less.** No new tables or strings in `update` / `draw` loops when you can reuse them; no image loading
  in `draw`. Lua's garbage collector is fast, but a thousand tables per frame show up as hitches.
- **Memory.** Each window's script heap (Lua, JavaScript, Python) may use up to **64 MB**; `sys.memory()` tells how
  close you are. Model and texture data live outside it, in the console's memory that Nexvyn OS and the other open
  apps share: keep the game's models and textures to tens of MB, not hundreds. A model file may be up to 96 MB.
- **Measure.** `sys.fps()`, the triangle count from `g3d.finish()`, `nexvyn.game`'s F3 overlay, and on a console a
  `stats` line in `autorun.txt`. Test with the most enemies your game ever spawns.

## 11. Make it yours: art direction

Two games made with this kit must not look alike, and no game should look like the Nexvyn OS desktop. The kit gives
you building blocks, not a menu template:

- Drawing: gradients, polygons (convex), lines and polylines, arcs, circles, images, sprite sheets, clipping, alpha.
- Type: seven system font styles at any size, letter spacing you draw yourself, bitmap fonts, the 3x5 pixel font,
  your logo as an image.
- 3D: lighting colour and direction, fog, vertex colours, textures, `"unlit"`, `"wire"`, additive `"glow"` halos,
  emissive materials, `g3d.project` for labels over 3D points.
- Motion: your own easing in Lua, or `game.tween` with 30+ easings, scene transitions (`fade`, `slide`, `wipe`,
  `circle`, `blinds`, `pixels`) and `game.flash`, camera shake and kick in `nexvyn.game`.
- Particles: `game.emitter` and ten presets in `nexvyn.game`, or a small pool of your own (Ember Field's sparks).
- Sound: five waveforms, files, streamed music.

There are no custom shaders or post-processing passes for scripts: the look comes from palette, light, shape, type
and motion.

### The method: seven decisions before the first menu

Write them as a comment at the top of `main.lua`. Ember Field's are in brackets.

1. **The feeling in one line**, plus three adjectives. ("Dusk errand on a floating island": warm, small, hurried.)
2. **Palette:** one dark, one light, one or two accents; about 60 % / 30 % / 10 %. Check it in greyscale: the
   player and the danger must still stand out. Do not use `theme.*` (the OS colours) in a game. (Ink `#17142A`,
   cream `#FFF1DC`, coral `#FF6F59`, apricot.)
3. **Typography:** which font style, case, size steps, spacing; where the logo image is used. (Bold capitals with
   wide spacing and a coral print offset, italics for the tagline, monospace numbers.)
4. **Camera language:** angle, field of view, distance, how it moves (eased follow, orbit, fixed rooms, shake).
   (High three-quarter follow at 50 degrees; a slow orbit on the title.)
5. **Motion style:** snappy or floaty; durations; overshoot or none. (Short and soft: 0.15-0.3 s fades.)
6. **Sound palette:** one family of instruments and effects. (Two triangle-wave notes for embers, a low saw and
   noise thud for hits.)
7. **UI shape language:** corners (sharp, round, slanted, torn), line weight, where menus sit and how they are laid
   out: a single prompt, a horizontal row, cards, a numbered column, objects in the 3D world. (A horizontal row of
   words at the bottom right with a wavy underline; slanted cards.)

**Rules.** Do not reuse a sample's or another game's menu layout, colours or title composition: the store review
rejects games that copy them. Do not build game menus from `ui.*` widgets: they are the OS's own controls. The
menu, the HUD and the pause screen belong to your game's world.

### Four title screens from the same blocks

The same three menu entries, four directions. All four are plain functions in `titles.lua` (tested in the guide's
bundle); compare their decisions, then make your own.

```lua
-- A. "Night circuit": black and electric, a perspective grid, the logo split into two colours, no list at all
function T.circuit(w, h, t)
  gfx.clear("#05060B")
  local hy = h * 0.58                                          -- horizon
  gfx.gradient(0, hy - 120, w, 120, "#05060B", "#3B0A45")
  gfx.color("#FF2E88")
  for i = -12, 12 do                                           -- lines that run to the vanishing point
    gfx.line(w / 2 + i * 18, hy, w / 2 + i * w * 0.18, h, 1.5)
  end
  for k = 0, 9 do                                              -- cross lines that scroll towards the player
    local f = ((k + t * 0.8) % 10) / 10
    local y = hy + (h - hy) * f * f
    gfx.line(0, y, w, y, 1 + f * 2)
  end
  local size = math.floor(h * 0.14)
  gfx.color("#19E6FF")
  gfx.text(TR("logo"), w / 2 - 3, h * 0.2, size, "monobold", "center", 0)
  gfx.color("#FF2E88")
  gfx.text(TR("logo"), w / 2 + 3, h * 0.2 + 2, size, "monobold", "center", 0)
  gfx.color("#FFFFFF")
  gfx.text(TR("logo"), w / 2, h * 0.2, size, "monobold", "center", 0)
  if math.floor(t * 2) % 2 == 0 then                           -- one prompt; the options come after it
    gfx.text(TR("press_start"), w / 2, h * 0.86, 18, "mono", "center", 0)
  end
end

-- B. "Paper diorama": warm paper, a torn edge, the menu as three cards lying at angles
function T.paper(w, h, t, sel)
  gfx.clear("#F4EAD5")
  local pts = {0, h * 0.62}
  for i = 0, 16 do pts[#pts + 1] = w * i / 16; pts[#pts + 1] = h * 0.62 + ((i * 37) % 11) - 5 end
  pts[#pts + 1] = w; pts[#pts + 1] = h
  gfx.color("#2E4A3F")
  gfx.lines(pts, 3)                                            -- the torn hill line
  gfx.color("#2B2118")
  gfx.text(TR("logo"), 48, h * 0.12, math.floor(h * 0.12), "italic")
  local labels = {TR("play"), TR("options"), TR("quit")}
  for i, label in ipairs(labels) do
    local cx, cy = w * (0.3 + i * 0.16), h * 0.78 + (i == sel and -10 - math.sin(t * 4) * 3 or 0)
    local tilt = (i - 2) * 6
    gfx.poly({cx - 70, cy - 40 + tilt, cx + 70, cy - 40 - tilt, cx + 70, cy + 40 - tilt, cx - 70, cy + 40 + tilt},
             i == sel and "#E9573F" or "#FFFDF6")
    gfx.color(i == sel and "#FFFDF6" or "#2B2118")
    gfx.text(label, cx, cy - 10, 18, "semibold", "center", 0)
  end
end

-- C. "Swiss grid": white, one red block, huge numerals, a numbered column on the left
function T.swiss(w, h, t, sel)
  gfx.clear("#FAFAF7")
  gfx.rect(w * 0.62, 0, w * 0.38, h * 0.55, 0, "#E2231A")
  gfx.color("#111111")
  gfx.text("08", w * 0.6, h * 0.5, math.floor(h * 0.42), "bold")
  gfx.text(TR("logo"), 40, 36, 28, "bold")
  gfx.color("#11111133")
  for x = 40, w, 80 do gfx.line(x, 0, x, h, 1) end             -- the visible grid is part of the look
  local items = {"play", "options", "quit"}
  for i, key in ipairs(items) do
    local y = h * 0.42 + (i - 1) * 46
    gfx.color(i == sel and "#E2231A" or "#111111")
    gfx.text(string.format("%02d", i), 40, y, 16, "monobold")
    gfx.text(TR(key), 90, y - 4, 26, i == sel and "bold" or "medium")
  end
end

-- D. "Diegetic": no 2D menu; three lit doors in the 3D scene, the camera turns to the chosen one
function T.doors(w, h, t, sel, door)
  gfx.clear("#0E1116")
  local angle = (sel - 2) * 0.5
  g3d.begin(0, 0, w, h, 55, 0.1, 40)
  g3d.camera(math.sin(angle) * 0.5, 1.6, 4, math.sin(angle) * 3, 1.4, 0)
  g3d.light(0.2, 1, 0.6, 0.25)
  g3d.fog("#0E1116", 4, 14)
  local labels = {"play", "options", "quit"}
  for i = 1, 3 do
    local x = (i - 2) * 2.4
    g3d.draw(door, x, 1.1, 0, 0, 0, 0, 1, 1, 1, i == sel and "#FFC870" or "#4A5568", i == sel and "glow unlit" or nil)
  end
  local sx = {}
  for i = 1, 3 do sx[i] = {g3d.project((i - 2) * 2.4, 2.6, 0)} end   -- labels above the doors (before finish)
  g3d.finish()
  for i = 1, 3 do
    if sx[i][1] then
      gfx.color(i == sel and "#FFC870" or "#8A94A6")
      gfx.text(TR(labels[i]), sx[i][1], sx[i][2], 18, "semibold", "center", 0)
    end
  end
end
```

(`door` is `g3d.mesh("box", 1.2, 2.2, 0.2)`, made once in `app.load`.) A fifth direction is Ember Field itself: the
3D hero orbiting on the left, a misprinted poster title, a row of words with a wavy underline. These are examples of
decisions, not templates: if your game ends up looking like one of them, go back to the seven decisions.

**Transitions** you can draw on top of anything; `p` runs from 0 to 1, you switch scenes at 1 and run it back:

```lua
-- transitions: draw on top of everything; p goes 0 -> 1 (cover) then you switch screens and run 1 -> 0
function T.iris(w, h, p, cx, cy)                -- a closing circle (a very thick ring around a shrinking hole)
  local far = math.sqrt(w * w + h * h)
  local r = far * (1 - p)
  gfx.color("#000000")
  gfx.circleLine(cx or w / 2, cy or h / 2, r + far / 2, far)
end

function T.wipe(w, h, p, color)                 -- a slanted bar sweeping across
  local x = (w + h * 0.5 + 10) * p - 10
  gfx.poly({-10, 0, x, 0, math.max(-10, x - h * 0.5), h, -10, h}, color or "#111111")
end
```

**Polish that reads as "expensive":** a fixed palette everywhere (HUD included), eased motion on every change (no
popping), a 2-4 frame hit pause and a camera kick on impacts, particles on pickups, sound on every action, a title
screen with something alive in it (the hero idling, embers rising), and nothing on screen that the player does not
need.

## 12. Store icon and key art

The icon is the first thing a player sees in the App Market. For games and apps made with the SDK it must be **key
art of the game itself**: its hero, its world, its lighting, its name or logo; bold, readable at 64 px, and unlike
any other icon in the store. A flat symbol on a gradient (`nxv icon` makes those, for placeholders only) is not
accepted for a game.

| | |
|---|---|
| File | `icon.png` in the bundle (and next to `source/` in the store folder) |
| Size | 256 x 256 PNG. Make it at 1024 x 1024 and scale it down with a good filter |
| Safe area | Keep the face, the hero's silhouette and the logo inside the central 80 %: corners may be rounded or cut |
| Fill | Fill the square edge to edge (an opaque background is fine) |
| Read at 64 px | One subject, big; strong value contrast between the hero and the background; at most one or two words |

**How to make one**

1. **Render it from your own models** in a 3D tool: pose the hero (a frame of a clip), a low camera close to it,
   a warm key light and a strong rim light in a contrasting colour, your game's sky colours behind, the logo in front.
   Ember Field's icon is rendered this way by a script (`art/make_keyart.py` next to the sample,
   `tools/gen_ember_keyart.py` in the source repository):
   `blender -b --factory-startup -P make_keyart.py -- models/pip.glb keyart.png 1024`.
2. **Or compose it in the game:** add a hidden key-art mode that draws the hero large with your best lighting and the
   logo, take a screenshot (Ryujinx, or `shot` in `autorun.txt`), crop it square and finish it in an image editor.
3. **Or paint it,** or have it painted: it must match the game's real look.

**AI prompt for key art** (for an image generator whose terms let you publish the result; paste a render or a
screenshot of your hero as the reference image so the icon matches the game):

```text
Square video game key art, 1:1, for a game called "<NAME>". Subject: <your hero, from the reference image>,
<pose / action>, large in the frame, three-quarter view, seen from slightly below. Setting: <your world in a few
words>. Lighting: <key light colour> key light, strong <contrasting colour> rim light, <time of day>. Palette:
<your 3-4 palette colours>. Style: <your art direction words, e.g. low-poly faceted, painterly, pixel art>.
Bold silhouette, high contrast, readable at small size, subject and logo inside the central 80 %. Title "<NAME>"
in a <your typography> logo at the bottom. No other text, no frame, no watermark.
```

Then check: is it clearly your game? Does it read at 64 px? Is it different from every icon on the store page?

## 13. Languages

- **English is required**: `lang/en.json` with every key you use, and `"en"` in `app.json` `name` / `description`
  and in `store.json`.
- Add any other language with one more file, `lang/<code>.json` (`de`, `es`, `fr`, `ja`, `ko`, `tr`, `zh`: the interface languages of Nexvyn OS).
  `TR("key", ...)` uses the console's language and falls back to English for missing keys, so a partial translation
  never shows a raw key.
- `{0}`, `{1}` in a text are replaced by the extra arguments: `TR("score", 42)` with `"score": "Score: {0}"`.
- Measure translated text (`gfx.textWidth`) and wrap it (`gfx.wrap`); German and Turkish words are long.
- Bitmap fonts only have the characters you drew: use them for numbers and English-only logos, a system font for
  translated text.

## 14. Publish

1. **Item folder** in the public repository: `Store/Games/<genre>/<slug>/` with `source/` (your bundle),
   `store.json`, `README.md`, `screenshots/` (3-4 PNGs, or a `shots` script the maintainer plays).
2. **`store.json`:**

   ```json
   {
     "kind": "game",
     "tags": ["3d", "action", "arcade"],
     "subtitle": {"en": "Collect embers, dodge rolling stones"},
     "description": {"en": "Two or three sentences about the game.\n\n• What makes it fun\n• Controls"},
     "age": "everyone",
     "shots": [["wait 4"], ["dpad a", "wait 3"], ["wait 6"]]
   }
   ```

   English is required; add more languages as more keys (`"de": "..."`). Subtitle at most 45 characters.
3. **README.md:** what the game is, the controls, the languages, a versions table and the licence of every part you
   did not make yourself (models, music, fonts, generator terms).
4. **Pull request.** The maintainer reviews it (checklist: `SDK/Publishing/REVIEW.en.md`) and runs the checkers.

**What reviewers check:** it starts and runs without errors on a console; no callback comes near the time limits
(load big files with `g3d.loadModel`); it works with the controller, touch and keyboard and pauses on **+** and
suspend; `minSdk` / `targetSdk` are right; permissions are explained; English text is complete; the icon is key art
of the game; the look is the game's own (no copied sample menus, no OS widgets as game UI); you own or may publish
every asset; nothing collects data.

## 15. The same loop in JavaScript and Python

**JavaScript** (`main.js`, `"main": "main.js"`): `g3d.loadModel` returns a Promise; the window keeps drawing while
it resolves.

```js
// The JavaScript version of the guide's 3D loop: async loading, input, a follow camera, sphere collision
let hero = null, rock = null, error = "";
const player = { x: 0, z: 0, yaw: 0, clip: "" };
const rocks = [{ x: 3, z: -2, r: 0.5 }, { x: -4, z: 1, r: 0.7 }];
const held = new Set();

async function loadAssets() {
  try {
    [hero, rock] = await Promise.all([
      g3d.loadModel("bundle:/models/hero.glb"),
      g3d.loadModel("bundle:/models/rock.glb", 1.0),
    ]);
    hero.play("Idle");
  } catch (e) {
    error = String(e.message || e);          // the reason the file could not be loaded
  }
}

function moveVector() {
  let [x, y] = input.stick("left");
  y = -y;                                   // up on the stick is positive
  if (input.down("left") || held.has("left") || held.has("a")) x = -1;
  if (input.down("right") || held.has("right") || held.has("d")) x = 1;
  if (input.down("up") || held.has("up") || held.has("w")) y = -1;
  if (input.down("down") || held.has("down") || held.has("s")) y = 1;
  const len = Math.hypot(x, y);
  return len > 1 ? [x / len, y / len] : [x, y];
}

app.load = () => { loadAssets(); };          // returns at once; the window keeps drawing

app.update = (dt) => {
  dt = Math.min(dt, 1 / 20);
  if (!hero) return;
  const [mx, my] = moveVector();
  const nx = player.x + mx * 5 * dt, nz = player.z + my * 5 * dt;
  // sphere vs sphere against every rock: refuse the step that would overlap
  const blocked = rocks.some((r) => (nx - r.x) ** 2 + (nz - r.z) ** 2 < (0.4 + r.r) ** 2);
  if (!blocked) { player.x = nx; player.z = nz; }
  const moving = Math.hypot(mx, my) > 0.2;
  if (moving) player.yaw = Math.atan2(mx, my);
  const want = moving ? "Run" : "Idle";
  if (want !== player.clip) { player.clip = want; hero.play(want, { fade: 0.2 }); }
  hero.update(dt);
};

app.draw = (w, h) => {
  gfx.clear("#20242C");
  if (!hero) {
    gfx.color("#FFFFFF");
    gfx.text(error ? TR("load_failed", error) : TR("loading"), 24, h - 48, 16, "mono");
    return;
  }
  g3d.begin(0, 0, w, h, 55, 0.1, 60);
  g3d.camera(player.x, 5, player.z + 7, player.x, 0.8, player.z);
  g3d.light(-0.4, 1, 0.3, 0.4);
  g3d.draw(hero, player.x, 0, player.z, 0, player.yaw, 0);
  for (const r of rocks) g3d.draw(rock, r.x, 0, r.z, 0, 0, 0, r.r * 2);
  const m = hero.nodeMatrix("Lamp", player.x, 0, player.z, 0, player.yaw, 0);
  if (m) g3d.drawMatrix(rock, m, "#FFB45A", "glow unlit");
  g3d.finish();
};

app.event = (e) => {
  if (e.type === "keydown" && e.key) held.add(e.key);
  if (e.type === "keyup" && e.key) held.delete(e.key);
};
```

**Python** (`main.py`): `g3d.loadModel(path, size=None, callback=None)` calls `callback(model, err)`;
`model.play(clip, loop, speed, fade)`.

```python
class Game:
    def load(self, arg):
        self.hero = None
        self.error = ""
        self.x = 0.0
        self.yaw = 0.0
        g3d.loadModel("bundle:/models/hero.glb", None, self.on_hero)   # parsed in the background

    def on_hero(self, model, err):
        if model:
            self.hero = model
            model.play("Idle", True, 1.0, 0.0)
        else:
            self.error = str(err)

    def update(self, dt):
        if self.hero:
            sx, sy = input.stick("left")
            self.x += sx * 4 * dt
            self.hero.update(dt)

    def draw(self, w, h):
        gfx.clear("#1B1F27")
        if not self.hero:
            gfx.color("#FFFFFF")
            gfx.text(TR("loading") if not self.error else self.error, 24, h - 48, 16, "mono")
            return
        g3d.begin(0, 0, w, h, 55, 0.1, 60)
        g3d.camera(self.x, 4, 7, self.x, 0.8, 0)
        g3d.light(-0.4, 1, 0.3, 0.4)
        g3d.draw(self.hero, self.x, 0, 0, 0, self.yaw, 0)
        g3d.finish()


app = Game()
```

Python on the console (pocketpy) is the slowest of the three: keep per-frame work small, or use Lua for a 3D game.

## See also

[SDK reference](../Reference/SDK.en.md) (8b *3D models*, 8c *2D game engine*) · [Game engine guide](GAME_ENGINE.en.md) ·
[Developer guide](DEVELOPER_GUIDE.en.md) · [Compatibility](COMPATIBILITY.en.md) ·
App Market publishing: `SDK/Publishing/PUBLISHING.en.md` and `SDK/Publishing/REVIEW.en.md` in the public repository ·
AI prompts: `SDK/AI/tasks/make-3d-game.en.md` and `SDK/AI/tasks/store-icon.en.md`.
