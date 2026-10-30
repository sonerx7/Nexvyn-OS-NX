# The Nexvyn OS 2D game engine: `nexvyn.game`

[Türkçe](GAME_ENGINE.tr.md) · **English**

`nexvyn.game` is a small 2D game engine written for Nexvyn OS's Lua apps. Think of it as a lightweight cousin of LÖVE
or Phaser: scenes, sprites, animation, tilemaps, a camera, physics, collision, input mapping, tweens, particles,
sound, menus and saving come ready. The engine is written entirely in Lua and runs on top of the SDK's `gfx`, `input`,
`audio` and `store` APIs. It ships with the system in the `romfs:/System/Lua/nexvyn/` folder; any app can use it with
one line:

```lua
local game = require("nexvyn.game")
```

`require` looks in the app's own bundle first; if the module is not there, it loads it from the system library
(`romfs:/System/Lua/`). So if you copy one of the engine's files into your bundle and change it, your copy is used.

This document walks you through making a game step by step. For the list of all functions:
[`sdk/SDK.en.md`](../Reference/SDK.en.md), section 8c. Two working sample games ship with the system:

- **Pixel Koşu** (`romfs/Applications/pixelrun.nxvapp`): a platformer. Tilemap, gravity, coins, enemies you stomp,
  checkpoints, three levels, a sprite sheet and animation.
- **Uzay Arenası** (`romfs/Applications/spacearena.nxvapp`): a top-down shooter. Waves, particles, power-ups, a
  multiplier, a saved high score. All drawing is done with shapes.

## 1. Package

A game is an ordinary `.nxvapp` bundle:

```
Oyunum.nxvapp/
├── app.json
├── main.lua
├── icon.png
├── lang/tr.json, lang/en.json
└── img/ (optional images)
```

Two settings in `app.json` matter for games:

```json
{"id": "com.adiniz.oyunum", "name": {"tr": "Oyunum", "en": "My Game"}, "category": "games",
 "window": {"width": 960, "height": 560, "minWidth": 480, "minHeight": 300, "resizable": true},
 "gamepad": true}
```

- `"gamepad": true`: while the window is focused, the controller goes to the game (hold L+R for a second to get the
  cursor back).
- `"resizable": true`: the window can be resized. Resizable apps in the `games` category that use the controller open
  full screen.

## 2. A first game

`main.lua`:

```lua
local game = require("nexvyn.game")
local G, I, U = game.gfx, game.input, game.ui

local Oyun = {controls = true}    -- show a virtual stick on the touch screen

function Oyun:enter()
  self.puan = 0
  self.dunya = game.world{}
  self.top = self.dunya:add(game.sprite{x = 240, y = 135, r = 10, body = true, damping = 4})
  function self.top:render() G.circle(self.x, self.y, 10, "#FFCC00") end
  for i = 1, 8 do
    local a = self.dunya:add(game.sprite{x = math.random(20, 460), y = math.random(30, 250), r = 5}, "altinlar")
    function a:render() G.circle(self.x, self.y, 5, "#4CD964") end
  end
  self.dunya:collide(self.top, "altinlar", function(top, altin)
    altin.dead = true
    self.puan = self.puan + 1
    game.audio.play("coin")
  end)
end

function Oyun:update(dt)
  local mx, my = I.vector()            -- left stick, D-pad, WASD or the touch stick
  self.top.ax, self.top.ay = mx * 900, my * 900
  self.dunya:update(dt)
end

function Oyun:draw() self.dunya:draw() end
function Oyun:ui() U.text(TR("puan", self.puan), 8, 6, 14) end
function Oyun:restart() self:enter() end   -- adds "Restart" to the pause menu

return game.run{width = 480, height = 270, scene = Oyun, background = "#1B2A41"}
```

`lang/tr.json`: `{"puan": "Puan: {0}"}`, `lang/en.json`: `{"puan": "Score: {0}"}`.

What happens here:

- `game.run{...}` builds and returns the app table (load, update, draw, event...) itself; `main.lua` ends with it.
- `width = 480, height = 270` is the size of the **virtual screen**. The engine draws everything at this size and
  scales it to the window. When the window grows or goes full screen, the game grows too.
- The scene (`Oyun`) is a plain Lua table. Its methods such as `enter`, `update`, `draw`, `ui` are optional.
- `game.world` gathers entities, physics and collisions in one place.
- **+**, **Esc** or **P** opens the pause menu: Resume, Restart, Sound, Touch controls, Quit game. The game also pauses
  by itself when the window loses focus.

## 3. Virtual screen and scaling

The `scale` field in `game.run`:

| Value | What it does |
|---|---|
| `"expand"` (default) | The design size always fits; the longer side grows with the window. No black bars, more area visible in a wide window. `game.width` / `game.height` may change. |
| `"fit"` | Fixed size, bars at the edges (`border` color). |
| `"pixel"` | Like `fit`, but with a whole-number scale. |
| `"none"` | 1 unit = 1 pixel; the virtual screen is the window itself. |

Place the UI relative to `game.width` and `game.height` (e.g. `game.width - 8` for the top right corner). To convert
window pixels to virtual units, use `game.toVirtual(px, py)`.

## 4. Scenes

```lua
game.switch(Oyun, {bolum = 2})             -- replace the stack: fades out, the new scene enters, fades in
game.switch(Menu, nil, {fade = 0.5, color = "#FFFFFF"})
game.push(Envanter)                        -- open on top (e.g. a menu, a dialog)
game.pop(sonuc)                            -- close; the scene below gets resume(sonuc) called
```

Transition types are chosen with `transition`: `"fade"` (default), `"slide"` (`dir = "left"`, `"right"`, `"up"`,
`"down"`), `"wipe"`, `"circle"` (a shrinking circle), `"blinds"` and `"pixels"` (dissolving square by square).
`game.scene.defaultTransition = "circle"` changes the default for all transitions.

```lua
game.switch(Harita, nil, {transition = "circle", fade = 0.5, color = "#101020"})
game.switch(Oyun, nil, {transition = "slide", dir = "up"})
```

Scene fields: `transparent = true` (the scene below is drawn too), `updateBelow = true` (the one below is updated
too), `controls = true` (touch controls are visible), `pausable = false` (like a title screen; the pause menu does not
open). Every scene has its own tween manager; when the scene stops, its animations stop too.

## 5. Sprites, sprite sheets and animation

```lua
local sheet = game.sheet("bundle:/img/kahraman.png", 64, 64,
  {spacing = 4, scale = 0.25, flipped = "bundle:/img/kahraman_flip.png"})
local animler = game.animations{
  bekle = {frames = "1-2", fps = 3},
  kos = {frames = "3-6", fps = 12},
  zipla = {frames = {7}, loop = false},
}
local k = game.sprite{x = 40, y = 80, sheet = sheet, anims = animler, w = 9, h = 14, body = true}
k:play("kos")
k.flipX = true                 -- face left
k.rotation, k.sx, k.alpha, k.z = 0.2, 1.5, 0.8, 10
```

- `x, y` is the sprite's center and also the center of its hitbox (`w, h` or `r`). `ox, oy` tells which point of the
  image lands on `x, y` (0..1, default 0.5). `dx, dy` shifts the drawing (to set the feet on the ground).
- **Why `flipped`?** The SDK cannot mirror image regions. If you give a mirrored copy, the engine uses it while facing
  left. `tools/gen_game_art.py` shows how we produce that copy.
- **Why `scale = 0.25`?** Images are enlarged with linear filtering; a 16-pixel drawing blurs when enlarged 3 times.
  Saving pixel art 4 times larger and giving `scale = 0.25` keeps it sharp.
- If you do not want to use images, write a `render` method and draw shapes with `game.gfx` (Uzay Arenası does this):

```lua
local Gemi = game.class(game.Sprite)
function Gemi:render()
  game.gfx.polyT({14, 0, -9, -9, -5, 0, -9, 9}, self.x, self.y, self.angle, 1, 1, "#E8F4FF")
end
local gemi = Gemi{x = 100, y = 100, r = 8, body = true, damping = 3}
```

## 6. Tilemaps

The easiest way is to draw the level as text:

```lua
local satirlar = {
  "....................",
  "......ooo...........",
  ".....=====.......G..",
  "..P.......e.....####",
  "####################",
}
local harita = game.tilemap.fromStrings(satirlar, {
  ["#"] = 1, ["="] = 4,
  o = {object = "altin"}, e = {object = "dusman"}, P = {object = "oyuncu"}, G = {object = "bitis"},
}, {tileset = game.sheet("bundle:/img/tiles.png", 64, 64, {margin = 4, spacing = 8}),
    tiles = {[1] = {solid = true}, [4] = {oneway = true}, [5] = {hazard = true}}})

for _, o in ipairs(harita.objects) do
  if o.type == "altin" then ... end         -- o.x, o.y is the center of the tile
end
```

- Tile properties: `solid`, `oneway` (a platform you can pass through from below), `color` (a colored square when
  there is no image), `draw = function(map, id, x, y, size)` (your own drawing) and any other fields you like.
  `harita:findTile(x, y, w, h, "hazard")` finds a tile with that property inside a rectangle (for spikes).
- Only the tiles visible to the camera are drawn; the speed stays the same however large the map is.
- From JSON: `game.tilemap.fromJSON("bundle:/bolum1.json")`.
- If you drew it with **Tiled**, export it as JSON (layer format CSV) and load it with
  `game.tilemap.fromTiled("bundle:/maps/bolum1.json")`. The `solid` / `oneway` (bool) properties on tiles and the
  `collide` or `above` properties on layers are read; object layers become `harita.objects`.

## 7. World, physics and collision

```lua
self.dunya = game.world{gravity = 920, map = harita, camera = self.kamera}
self.kahraman = self.dunya:add(Kahraman{x = 40, y = 80}, "kahraman")
self.dunya:add(Dusman{x = 300, y = 80}, "dusmanlar")

self.dunya:collide(self.kahraman, "dusmanlar", function(k, d)
  if k.vy > 0 and k.y < d.y then d.dead = true; k.vy = -230   -- stomped on it
  else self:ol() end
end)
self.dunya:collide("mermiler", "dusmanlar", vur)           -- hundreds of objects: spatial hash
self.dunya:collide("kutular", "kutular", nil, true)        -- push each other apart
self.dunya:trigger{x = 400, y = 0, w = 32, h = 200, filter = "kahraman",
                   onEnter = function(k) game.toast("Kontrol noktası!") end}
```

Entities with `body = true` move on every step: `vx, vy` velocity, `ax, ay` acceleration, `gravity` gravity
multiplier, `dragX` (slowing down when there is no input), `damping` (friction for space games), `maxVx, maxVy`,
`bounce`. When they hit the map, `onFloor`, `onWall`, `onCeiling` are filled in. A typical jump for a platformer:

```lua
if self.onFloor then self.coyote = 0.1 else self.coyote = self.coyote - dt end
if game.input.pressed("jump") and self.coyote > 0 then self.vy = -320 end
if game.input.released("jump") and self.vy < -120 then self.vy = -120 end   -- low jump on a short press
```

`self.dropThrough = true` drops down through a one-way platform.

## 8. Camera

```lua
self.kamera = game.camera{lerp = 0.14, deadzone = {w = 36, h = 44}}
self.kamera:follow(self.kahraman)
self.kamera:setBounds(0, 0, harita.pixelWidth, harita.pixelHeight)
self.kamera:shake(4, 0.3)                    -- shake
self.kamera:attach(0.3) ... self.kamera:detach()   -- distant hills: parallax
local dx, dy = self.kamera:toWorld(game.input.pointer.x, game.input.pointer.y)
```

`world:draw()` uses the camera by itself; use `attach` / `detach` for your own drawing.

```lua
self.kamera:zoomTo(2, 0.6, "inOutSine")      -- smooth zoom
self.kamera:panTo(kapi.x, kapi.y, 1.2)       -- show the door (following pauses meanwhile, then continues)
self.kamera:kick(0, 3)                       -- recoil: a short push that springs back by itself
if self.kamera:visible(x, y, 16, 16) then ... end   -- skip off-screen work in your own drawing
game.flash("#FFFFFF", 0.15)                  -- a color over the whole screen that fades (hit, pickup, lightning)
```

## 8a. Lights

A torch, a lantern or magic light in a dark scene:

```lua
self.isiklar = game.lights{ambient = 0.85, color = "#05060F", cell = 8}
self.mesale = self.isiklar:add{x = kahraman.x, y = kahraman.y, radius = 80, flicker = 0.08}
function Oyun:draw()
  self.dunya:draw()
  self.mesale.x, self.mesale.y = self.kahraman.x, self.kahraman.y
  self.isiklar:draw(self.kamera)       -- after the world, before the UI
end
```

`ambient` is the darkness where there is no light (0 = none, 1 = pitch black). The screen is divided into cells of
`cell` units, each cell's darkness is rounded to a few levels, and neighbours on a row with the same level are drawn as
one rectangle; that is why a dark room with a few lights takes hundreds of rectangles, not thousands. Light fields:
`radius`, `intensity` (0..1), `flicker`, `on`. `isiklar:remove(isik)`, `isiklar:clear()`.

## 8b. Path finding (A*)

```lua
local yol = harita:path(dusman.x, dusman.y, kahraman.x, kahraman.y)   -- {x1, y1, x2, y2, ...} tile centers
local yol = harita:path(x0, y0, x1, y1, {diagonal = true, maxNodes = 2000,
                                          avoid = function(tx, ty) return kapiKapali(tx, ty) end})
local karolar = game.path.find(gen, yuk, function(tx, ty) return izgara[ty][tx] == 0 end, sx, sy, hx, hy)
```

Solid tiles block, one-way platforms can be passed. `cost(tx, ty)` gives the extra cost of entering a tile (mud,
danger). `maxNodes` limits the search; a long search gives up instead of freezing the frame. The working arrays are
reused; only the result table is created. For enemies, compute the path a few times per second, not every frame.
Example: the **Dungeon** template in Studio.

## 9. Input: actions

The game does not ask for "the A button" but for the "jump" action. Controller buttons, keyboard keys, stick
directions and touch buttons are bound to an action:

```lua
local I = game.input
I.bind("jump", {pad = {"a", "b"}, key = {"space", "up", "w"}, touch = {"button:jump", "stick:up"}})
I.bind("fire", {pad = "zr", key = "j", axis = "rx+"})
I.touchControls{stick = true, buttons = {{id = "jump", icon = "arrow_upward", action = "jump"}}}

if I.pressed("jump") then ... end     -- pressed this step
if I.down("fire") then ... end        -- held
local mx, my = I.vector()             -- -1..1 movement (y down)
local ax, ay, nisan = I.aim()         -- right stick
```

Built-in actions: `left`, `right`, `up`, `down` (D-pad, WASD, left stick, touch stick), `confirm` (A, Enter, Space),
`back` (B, Esc), `pause` (+, Esc, P).

**Touch:** when the screen is touched, a virtual stick appears on the left half, buttons at the bottom right and a
pause button at the top right; they hide when the controller or keyboard is used (as in the Retro app). The scene must
have `controls = true`. The SDK reports only one finger, so a button cannot be pressed while holding the stick. Binding
jump to `"stick:up"` as well solves this (pushing the stick up jumps). The "Touch controls" setting in the pause menu
switches between Automatic / On / Off; when On, it can be used with the mouse too.

**Key binding:** `game.run{controls = {"jump", "fire"}}` adds "Controls" to the pause menu: the player picks an action
and presses the new key or controller button (Esc cancels). The choices are saved in the engine settings and kept even
if the game binds the action again later. For your own screen: `I.listen(function(tur, deger) ... end)` (the next key
or button), `I.setBinding("jump", "key", "z")`, `I.binding("jump", "pad")`, `I.bindingLabel("jump")` (e.g.
`"Space / A"`, for hints), `I.resetBindings()`, `I.saveBindings(kayit)`, `I.loadBindings(kayit)`.

## 10. Tweens and timers

```lua
game.tween.to(altin, 0.35, {y = altin.y - 18, alpha = 0}, "outQuad")
  :oncomplete(function() altin.dead = true end)
game.tween.to(yazi, 0.3, {sx = 1.2}, "outBack"):after(yazi, 0.2, {sx = 1})   -- chain
game.tween.after(1.5, function() self:yeniDalga() end)
game.tween.every(0.5, yanipSon, 6)
```

Easing names: `linear`, `inQuad`, `outQuad`, `inOutQuad`, `outCubic`, `outBack`, `outElastic`, `outBounce` and others
(SDK.en.md 8c); `smoothstep`, `inOutBack`, `inOutElastic`, `inOutBounce`, `inCirc`/`outCirc` are there too.
`game.tween.steps(4)` gives a choppy four-step easing (retro movement, blinking).

```lua
game.tween.to(ok, 0.4, {y = ok.y - 6}, "inOutSine"):loop(0, true)   -- up and down forever (yoyo)
game.tween.to(isik, 0.2, {alpha = 0.3}):loop(3)                     -- 3 more times
game.tween.from(baslik, 0.6, {y = -40}, "outBack")                  -- flies in from -40 to where it is now
```

## 11. Particles

```lua
self.patlama = self.dunya:addEmitter(game.emitter{max = 400, life = {0.3, 0.9}, speed = {40, 260},
  size = {4, 0}, damping = 2.5, colors = {"#FFFFFF", "#FFC94D", "#FF4D6D00"}, shape = "square"})
self.patlama:emit(30, x, y)              -- all at once
self.iz.rate = 60; self.iz:start()       -- continuous
```

Ready-made effects: `"explosion"`, `"smoke"`, `"sparkle"`, `"rain"`, `"snow"`, `"fire"`, `"confetti"`, `"dust"`,
`"blood"`, `"magic"`.

```lua
local yagmur = self.dunya:addEmitter(game.particles.preset("rain", {x = game.width / 2, y = -10}))
yagmur:start()                                              -- spreads over the top of the screen with area
game.particles.burst(self.dunya, "explosion", x, y)        -- one-off: one shared emitter per world
game.particles.burst(self.dunya, "confetti", x, y, 80)
```

`area = {w, h}` spawns particles inside a box (rain, snow). Colors blend over the lifetime; if the last color's alpha
is 00, the particle fades out. Particles are kept in arrays and produce no garbage per frame. For many particles,
`"square"` is the fastest.

## 12. Sound and music

```lua
local A = game.audio
A.play("coin")                                            -- ready-made effects: jump, coin, hit, explode, power, win...
A.define("ez", {wave = "square", volume = 0.2, notes = "E5:0.04 E6:0.08"})
A.play("bundle:/ses/kapi.wav")
A.song{bpm = 140, wave = "triangle", volume = 0.05, notes = "E5 G5 A5 G5 E5 D5 C5 -", bass = "A2:2 E3:2"}
A.music("bundle:/muzik/tema.ogg")
```

`A.song` is a small synthesized tune that plays without any sound file. Sound can be turned off from the pause menu,
and the choice is saved.

## 13. UI and menus

```lua
U.text("Merhaba", 8, 6, 14)                                  -- text with a shadow
U.score(1234, game.width - 8, 6, 2, "#FFE066", 6, "right")   -- score in pixel font: 001234
U.pixelText("BÖLÜM 2", 0, 40, 3, "#FFFFFF", "center", game.width)
U.bar(8, 20, 60, 6, can / 100, "#FF5050")

self.menu = U.menu{width = 190, items = {
  {label = function() return TR("basla") end, action = function() game.switch(Oyun) end},
  {label = function() return TR("ses") end, action = sesiDegistir, left = sesiDegistir, right = sesiDegistir},
}}
function Baslik:update() self.menu:update() end            -- D-pad + A, or touch
function Baslik:ui() self.menu:draw(game.width / 2, 100) end
```

Menus work with the controller, keyboard, mouse and touch. `U.button(...)` is for a single button. `game.toast("...")`
shows a short notification at the top of the screen.

Other pieces:

```lua
U.hearts(can, 5, 8, 8, 12)                        -- full / empty hearts (2.5 draws a half heart; icon = "star" works too)
ses = U.slider(ses, 20, 60, 140, 14)              -- 0..1, dragged with a finger
acik = U.toggle(acik, 20, 90)                     -- switch
if U.iconButton("pause", game.width - 20, 20, 24) then game.pause() end
U.dialog{title = "Çıkılsın mı?", text = "İlerleme kaydedildi.", buttons = {"Çık", "Kal"},
         onClose = function(i) if i == 1 then sys.exit() end end}    -- a dialog that works with the controller too
self.konusma = U.dialogue{lines = {"Merhaba!", {who = "Tilki", text = "Beni izle."}}, speed = 40}
-- update: self.konusma:update(dt), self.konusma.done when finished; ui: self.konusma:draw()
```

`U.dialogue` types the text letter by letter in a box at the bottom; A or a tap first completes the line, then moves
to the next one.

## 14. Saving

```lua
local kayit = game.save.open("ilerleme")
kayit:set("bolum", 3)
local b = kayit:get("bolum", 1)
if kayit:best("rekor", puan) then game.toast("Yeni rekor!") end
kayit:best("sure1", sure, true)      -- the smaller one wins
```

Data is kept in the app's `store` and written to disk within a second.

Save slots ("Load game" screens):

```lua
local yuva = game.save.slot(2)
yuva:set("bolum", 4)
yuva:stamp("Bölüm 4 · 120 altın")            -- stores the time and a short summary
for _, bilgi in ipairs(game.save.slots(3)) do
  -- bilgi.index, bilgi.used, bilgi.summary, bilgi.when ("2 min ago"), bilgi.save
end
yuva:copyTo(3); game.save.slot(1):delete(); yuva:exists()
```

## 15. Debugging and speed

- **F3** (or `game.debug = true`): FPS, step count, update and draw time, the number of entities, bodies and particles;
  hitboxes are drawn in green, trigger zones in yellow.
- Under the overlay you see a graph of the last 90 frame times (green under 16.7 ms, orange under 33 ms, red above),
  the pointer's virtual and world coordinates and the values you watch: `game.watch("hiz", kahraman.vx)` (every
  frame), `game.unwatch("hiz")`.
- Updates run in fixed steps (60 per second); drawing happens once per frame.
- The tilemap draws same-colored tiles on a row as one rectangle; large maps with colored tiles make fewer draw calls.
- Do not create tables in hot loops: use `G.polyT` for shapes and local variables for comparisons. The engine itself
  creates no tables per frame (the world, the hash, particles and tween lists are reused).
- If many objects will collide, use `world:collide("grupA", "grupB", ...)`; it uses a spatial hash.

## 16. Known limits

- The SDK has no focus query. The engine guesses the focus: if a controller button is pressed but no event reaches the
  game, or the window is not drawn (minimized), the game pauses. Touching another window and then moving only the left
  stick is not detected.
- A single touch point (no multi-touch).
- Image regions cannot be mirrored or tinted (a `flipped` copy is needed; `tint` only on a single image, without
  rotation).
- Tilemap collision uses rectangular tiles; there are no sloped tiles. In Tiled, only the first tileset and CSV layers.
- No camera rotation.

---

## English summary

`nexvyn.game` is a pure-Lua 2D engine shipped in `romfs:/System/Lua/nexvyn/`. `require("nexvyn.game")` works from any app
because `require` now falls back to the system Lua library when a module is not in the app bundle (the bundle always
wins). `main.lua` ends with `return game.run{width, height, scene, ...}`, which builds the app table.

- **Loop:** fixed-step updates (1/60), one draw per frame, a virtual screen scaled to the window (`expand`, `fit`,
  `pixel`, `none`), automatic pause menu on + / Esc / P / touch pause button and when the window seems unfocused.
- **Scenes:** `game.switch/push/pop` with fade transitions; scene tables with `enter/leave/pause/resume/update/draw/ui/event`.
- **Entities:** `game.sprite`, `game.class(game.Sprite)`, sheets with mirrored copies for `flipX`, frame animations,
  origin, rotation, scale, alpha, tint, z-order, groups.
- **World:** physics bodies (velocity, acceleration, gravity, drag, damping, bounce), tile collision with one-way
  platforms, overlap callbacks through a spatial hash, trigger zones, emitters, camera-culled drawing, debug colliders.
- **Tilemaps:** from Lua tables, ASCII rows, a simple JSON format or Tiled JSON exports; collision flags; culled drawing.
- **Camera:** follow with deadzone and smoothing, bounds, zoom, shake, parallax, screen-to-world.
- **Input:** named actions over pad, keys, stick directions and on-screen touch controls (shown after a touch).
- **Also:** tweens with easing, chaining, loops/yoyo and `from`, timers, particle emitters with presets
  (`game.particles.preset/burst`), synth sound effects and tunes, music, HUD text, pixel-font scores, hearts,
  sliders, toggles, icon buttons, modal dialogs, a typewriter dialogue box, menus for pad and touch, key/value saves
  with numbered slots, F3 debug overlay with a frame-time graph and watched values.
- **Newer:** scene transitions (`fade`, `slide`, `wipe`, `circle`, `blinds`, `pixels`), camera `zoomTo`, `panTo`,
  `kick`, `visible`, `game.flash`, a darkness-and-lights overlay (`game.lights`), A* path finding (`map:path`,
  `game.path.find`), player key rebinding from the pause menu (`game.run{controls = {...}}`), `game.chance`,
  `game.randInt`, `game.weighted`.

Full API: `sdk/SDK.en.md` section 8c. Samples: `pixelrun.nxvapp` (platformer) and `spacearena.nxvapp` (arena shooter).
Known limits: focus is inferred (no SDK focus query), single touch point, no mirrored or tinted image regions in the
SDK, no slopes, first Tiled tileset only, no camera rotation.
