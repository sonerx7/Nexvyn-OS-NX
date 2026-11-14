# Game kits for JavaScript

Two dependency-free ES modules to copy next to your game's `main.js`, and a demo app ("Signal") that uses both. Run
this folder as an app to see and hear them (Studio: open the folder, **Run**; or copy it to
`sdmc:/NexvynOS/Applications/KitDemoJS.nxvapp/`). They are the same kits as the Lua ones in
[`../../lua/kits`](../../lua/kits/README.md); functions that return two values in Lua return an array here.

| File | What it gives | Guide |
|---|---|---|
| [`sfx.js`](sfx.js) | Sound design: layered procedural recipes rendered once into WAV files in the data folder (written as a `Uint8Array`), variants, buses, ducking, ambience, music loops | [SOUND_DESIGN.md](../../../Guides/SOUND_DESIGN.md) |
| [`juice.js`](juice.js) | Graphics, UI and feel: tweens, springs, shake, hit-stop, particles, generated textures, gradients, palettes, titles, panels, buttons, transitions, cameras, 3D light moods | [GAME_FEEL.md](../../../Guides/GAME_FEEL.md) |
| `main.js`, `app.json`, `lang/`, `icon.png` | the demo | |

```js
import sfx from "./sfx.js";
import J from "./juice.js";
app.load = () => {
  J.init(); sfx.init();
  sfx.define("hit", sfx.recipes.impact({ weight: 0.7 }), { variants: 4, duck: ["music", 0.45, 0.25] });
};
app.update = (dt) => { sfx.update(dt); J.update(dt); };
// on a hit: sfx.play("hit"); J.burst(x, y, "sparks"); J.shake(0.4); J.hitstop(0.05);
```

`minSdk` 1.1 (JavaScript). Check your game with `node tools/js_check.mjs MyGame.nxvapp` in the Nexvyn OS source
repository, or `nxv check --sdk`. The demo is an example of the blocks, not a menu to copy.
