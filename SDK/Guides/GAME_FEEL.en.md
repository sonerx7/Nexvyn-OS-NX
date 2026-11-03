# Graphics, UI and game feel for Nexvyn OS games

**English** · [Türkçe](GAME_FEEL.tr.md)

Most games made quickly (by people or by AI assistants) look alike in the same ways: a flat background colour,
default text at default size, rectangles that appear and disappear, nothing moving on the title screen, no reaction
when something is hit. This guide lists the building blocks that fix that and the **feel kit** that implements them:

- Lua: `SDK/Languages/lua/kits/juice.lua` · JavaScript: `SDK/Languages/javascript/kits/juice.js` (the same kit).
- The kits folders are runnable demo apps (`main.lua`: "Forge", `main.js`: "Signal"); two different art
  directions from the same blocks. Copy `juice.lua` / `juice.js` next to your `main` file.

The kit gives **blocks, not templates**: it has no menu layout, no title screen and no palette you must use. Your
game still needs its own art direction ([MAKE_A_GAME.en.md](MAKE_A_GAME.en.md), section 11). Sound has its own guide:
[SOUND_DESIGN.en.md](SOUND_DESIGN.en.md).

```lua
local J = require("juice")
function app.load() J.init() end                         -- makes the glow, vignette, grain, shadow, ray textures once
function app.update(dt) J.update(dt); world:update(J.dt(dt)) end   -- J.dt = 0 during a hit-stop
function app.event(e) J.event(e) end
function app.draw(w, h)
  local sx, sy = J.shakeOffset(14)
  gfx.push(sx, sy)  drawWorld()  J.drawParticles()  J.drawFloaters()  gfx.pop()
  J.vignette(w, h, 0.5)  drawHud()  J.overlay(w, h)  J.endFrame()
end
```

Each block below has a **before** (what a quick game does) and an **after** (what the block does).

## 1. Motion

| Block | Before | After |
|---|---|---|
| **Easing** `J.ease.outCubic`, `outBack`, `outElastic`, `inOutSine`... | a panel jumps from hidden to shown | it slides in fast and settles (`outCubic`), or overshoots a little (`outBack`) |
| **Tweens** `J.tween(obj, 0.3, {y = 40}, "outBack", {delay, done, loop, yoyo})` | values set directly | any field of any table animates, with delays and chains |
| **Damping** `x = J.damp(x, target, 10, dt)` | `x = target`, or `x = x + (target - x) * 0.1` (speed depends on the frame rate) | smooth follow that looks the same at 30 and 60 fps |
| **Springs** `J.spring(state, target, dt, 4, 0.5)` | buttons that switch colour | buttons, cursors and cards that bounce slightly and settle: alive |

Rule: nothing on screen pops. Every appear, disappear, move, value change and colour change takes 0.1-0.4 s with an
easing that suits your motion style (snappy: `outQuart`, 0.12 s; floaty: springs, 0.4 s; heavy: `outCubic` with a
short delay).

## 2. Impact (game feel)

| Block | Before | After |
|---|---|---|
| **Screen shake** `J.shake(0.4)` + `J.shakeOffset(px)` | the screen stays still when a bomb goes off | trauma-based shake (strength²) that decays smoothly, not random jitter |
| **Hit-stop** `J.hitstop(0.05)`, `J.dt(dt)` | hits slide through | the game freezes for 2-6 frames on a heavy hit: the hit *lands* |
| **Slow motion** `J.slowmo(0.3, 0.6)` | the last enemy just disappears | a moment of slow motion on the final blow |
| **Flash** `J.flash(color, 0.15, 0.4)` | | a full-screen colour that fades out: damage (red), pickup (gold), level up (white) |
| **Particles** `J.burst(x, y, "sparks" / "embers" / "dust" / "smoke" / "confetti" / "magic" / "hit")` | a coin vanishes | sparks fly, a ring expands, embers drift; soft glowing sprites, colours over life, gravity, drag |
| **Floating text** `J.floatText("+10", x, y, color)` | the score changes silently | the number pops (`outBack`) and drifts up and fades |
| **3D camera kick** `cam:kick(8)` | | the field of view widens for a moment on a dash or a hit |

Combine them: a heavy hit is `J.burst(x, y, "hit")` + `J.burst(x, y, "sparks")` + `J.shake(0.5)` + `J.hitstop(0.06)` +
`J.flash(...)` + a layered impact sound + a light `sys.vibrate(0.6, 80)`, **all on the same frame**. A pickup is
smaller: a few sparks, a soft chime, a floater, no shake. Scale the response with the event; if everything shakes,
nothing feels big.

## 3. Light and depth (2D)

| Block | Before | After |
|---|---|---|
| **Gradients** `J.gradient(x, y, w, h, {deep, bg, mid})` | `gfx.clear("#203040")` | a sky or a floor with depth; several stops |
| **Glow** `J.glow(x, y, r, color, alpha)` | a lamp is a yellow circle | a soft halo with a bright core (generated glow texture, tinted) |
| **Vignette** `J.vignette(w, h, 0.5)` | flat corners | darker edges pull the eye to the centre |
| **Grain** `J.grain(w, h, 0.04)` | clean digital flatness | a moving film grain at 3-5 %: texture without noise |
| **Soft shadows** `J.blob(x, y, w, h)`, `gfx.shadow` (used by `J.panel`) | characters float above the floor | a soft contact shadow under every character and object |
| **Light rays** `J.rays(x, y, len, count, color, alpha, t)` | | slow swaying light shafts from a window or the sky |
| **Palettes** `J.palettes.ember` (deep, bg, mid, ink, accent, accent2, light), `J.mix`, `J.shade`, `J.alpha` | ten random colours, OS colours (`theme.*`) | 4-6 colours with roles, mixed and shaded from each other so everything belongs together |

The palettes in the kit are starting points: shift their hues for your game. Check your palette in grey: the player,
the danger and the interactive things must still stand out.

## 4. Typography

The SDK draws text with the system fonts (`"sans"`, `"medium"`, `"semibold"`, `"bold"`, `"italic"`, `"mono"`,
`"monobold"`) at any size. A game title in `gfx.text(title, x, y)` at the default size is the clearest sign of an
unfinished game. With the kit:

| Block | Use |
|---|---|
| `J.scale(base, ratio)` | a type scale (`xs` ... `display`); use 3-4 of its steps for the whole game |
| `J.spaced(s, x, y, size, font, spacing, align, w)` | letter spacing (tracking): wide-spaced capitals for titles and labels |
| `J.title(s, x, y, size, {fill, fill2, outline, outlineW, shadow, glow, spacing, align, w})` | a logo-like title: two-tone vertical gradient, outline, layered drop shadow, glow behind |
| `J.fit(s, maxW, size, font)` | the size at which a (translated) text fits |

Before: `gfx.text("SKY HOP", 0, 40, 24, "bold", "center", w)`. After: `J.title("SKY HOP", 0, h * 0.12, h * 0.16,
{fill = P.light, fill2 = P.accent, outline = P.deep, shadow = "#00000099", glow = P.accent, align = "center", w = w,
spacing = 10})`, gently bobbing with `math.sin(t)`. A logo drawn as an image or a bitmap font
([MAKE_A_GAME.en.md](MAKE_A_GAME.en.md) section 7) is even better.

## 5. UI with depth

| Block | Before | After |
|---|---|---|
| **Panels** `J.panel(x, y, w, h, {shape, fill, fill2, border, shadow, depth, highlight})` | a flat rectangle | a panel with a soft shadow, a darker slab under it (`depth`), a light top edge (`highlight`), a gradient |
| **Shape language** `shape = "round" / "pill" / "cut" / "slant" / "tab"` | the OS's rounded buttons | one shape for the whole game: cut corners (sci-fi), slanted (action), pills (cosy), tabs |
| **Buttons** `J.button(id, label, x, y, w, h, {focused, activate, shape, fill, fillHover, ink, glow, depth})` | `ui.button` (the OS's look) or a rectangle that changes colour | hover lifts it, a press sinks it into its slab, controller focus draws a border and a glow, colours ease; `J.onUi` plays your hover and press sounds |
| **Transitions** `J.transition("fade" / "iris" / "wipe" / "blinds" / "pixels", 0.6, switchFn, color)` | screens replace each other | the screen is covered, switched in the middle and uncovered |

Game menus are never built from `ui.*` widgets (the OS's own controls). `J.button` only handles state and draws
with your colours and shape; the layout is yours (a row, cards, a column, objects in the world).

## 6. Cameras

- **2D:** `cam = J.camera{lag = 7, lead = 0.25, dead = {w = 80, h = 50}, bounds = {...}}`; every frame
  `cam:follow(px, py, vx, vy, dt)`, then `gfx.push(cam:offset(w, h, 14))`. Look-ahead in the direction of movement,
  a dead zone so small moves do not move the camera, smooth damping, bounds, shake included.
- **3D:** `cam = J.cam3d{dist = 6, height = 2.5, lookHeight = 1, lag = 6, fov = 55}`; `cam:follow(x, y, z, yaw, dt)`,
  `g3d.begin(0, 0, w, h, cam:fov())`, `cam:apply()`. The camera turns the shortest way behind the hero and eases.

## 7. 3D light, fog and sky

`J.looks.dusk / noon / night / toxic / frost / desert / abyss / synth` are complete moods: sky colours, horizon, fog
colour, light direction, ambient and light colour, a glow accent.

```lua
local L = J.looks.dusk
J.sky(w, h, L)                      -- gradient sky with a horizon glow (before g3d.begin)
g3d.begin(0, 0, w, h, cam:fov(), 0.1, 60)
J.light3d(L, 60)                    -- g3d.light + g3d.fog (fog from 35 % to 100 % of far, in the horizon colour)
-- draw; emissive parts and "glow unlit" meshes in L.glow
g3d.finish()
J.vignette(w, h, 0.45)
```

Before: grey fog, white light from straight above, a black background. After: fog that matches the sky so the far
plane disappears, warm key light from the side, coloured halos on lamps and pickups.

## 8. The quality bar

A game is ready for the store when all of these are true:

- [ ] **Feedback:** every player action has a sound and a visual response on the same frame (particles, a flash, a
      squash, a number); impacts scale (a pickup is small, a boss hit is huge).
- [ ] **Motion:** nothing pops; screens change with a transition; the title screen has something alive in it.
- [ ] **Colour:** a palette of 4-6 colours with roles (dark, light, accent for the player and actions, accent for
      danger and rewards); no flat single-colour backgrounds (gradients, light, texture, parallax); it reads in grey.
- [ ] **Type:** a type scale with 3-4 sizes; the title is a logo (styled with outline, shadow, two tones or glow, or
      an image), never default text at default size; labels are tracked, numbers in `mono` where they change.
- [ ] **UI:** one shape language everywhere; panels with depth (shadow, slab, highlight); buttons with hover, press,
      focus and disabled states; controller focus is always visible.
- [ ] **Light:** vignette or framing; soft shadows under characters; glow on things that emit light; in 3D, fog in
      the sky colour and a lit, coloured key light.
- [ ] **Camera:** smoothed follow (no rigid lock), shake only on impacts.
- [ ] **Sound:** see the checklist in [SOUND_DESIGN.en.md](SOUND_DESIGN.en.md): layered effects, music plus
      ambience, mixed levels, ducking.
- [ ] **Speed:** 60 fps on the console with all of the above: particles under a few hundred, textures made once
      (`J.init`), no tables or strings created per particle per frame (the kit reuses one colour table).
