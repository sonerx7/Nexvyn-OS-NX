# Game kits for Lua

**English** · [Türkçe](README.tr.md)

Two dependency-free files to copy next to your game's `main.lua`, and a demo app ("Forge") that uses both. Run this
folder as an app to see and hear them (Studio: open the folder, **Run**; or copy it to
`sdmc:/NexvynOS/Applications/KitDemo.nxvapp/`).

| File | What it gives | Guide |
|---|---|---|
| [`sfx.lua`](sfx.lua) | Sound design: layered procedural recipes (impact, coin, jump, laser, explosion, power-up, hurt, whoosh, UI clicks, footsteps on five surfaces, jingles, ambience beds and details, music loops from a chord progression) rendered once into WAV files in the data folder; variants, buses, ducking, voice limits, cooldowns | [SOUND_DESIGN.en.md](../../../Guides/SOUND_DESIGN.en.md) |
| [`juice.lua`](juice.lua) | Graphics, UI and feel: easing and tweens, springs, damping, screen shake, hit-stop, slow motion, flashes, glowing particles, floating text, generated glow / vignette / grain / shadow / ray textures, multi-stop gradients, palettes, styled titles and letter spacing, panels with depth, buttons with states, transitions, 2D and 3D cameras, 3D light moods | [GAME_FEEL.en.md](../../../Guides/GAME_FEEL.en.md) |
| `main.lua`, `app.json`, `lang/`, `icon.png` | the demo | |

```lua
local sfx = require("sfx")
local J = require("juice")
function app.load()
  J.init(); sfx.init()
  sfx.define("hit", sfx.recipes.impact{weight = 0.7}, {variants = 4, duck = {"music", 0.45, 0.25}})
end
function app.update(dt) sfx.update(dt); J.update(dt) end
-- on a hit: sfx.play("hit"); J.burst(x, y, "sparks"); J.shake(0.4); J.hitstop(0.05)
```

Both need SDK 1.0 calls only (`minSdk` stays what your game needs). They write their generated files into the app's
data folder (`sfx/`, `fx/`) and make them again when a recipe changes. Check your game as usual:
`python tools/lua_check.py MyGame.nxvapp` in the Nexvyn OS source repository, or `nxv check --sdk`.

The demo is an example of the blocks, not a menu to copy: give your game its own art direction.
