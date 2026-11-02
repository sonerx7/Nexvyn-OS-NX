# Task: make a 3D game with models

**English** · [Türkçe](make-3d-game.tr.md)

For a 3D game that uses `.glb` / `.fbx` models (SDK 1.8). Send it after the context pack (`system-prompt.en.md` + the
language pack). Give the assistant SDK.en.md section 8b (*3D* and *3D models*) and, if the context is large enough,
`SDK/Guides/MAKE_A_GAME.en.md` (the full recipe: export rules, loading, collision helpers, budgets, art direction).
Look at the sample `SDK/Samples/lua/ember-field` for a complete small game, but do not let the assistant copy its look.

Before you ask, check each model once in the game or in Studio's *3D Models* template and note what `model:info()`
reports (size, triangles, bones, clip names).

```text
Write a complete Nexvyn OS 3D game with SDK 1.8.

Game: <genre and one-paragraph idea>
Language: <Lua | JavaScript | Python>
App id: com.<yourname>.<game>   Name: <name>
Languages of the game: English<, plus any others>
Models in the bundle (from model:info()):
- models/<hero>.glb: <height> m, <triangles> triangles, clips <Idle, Run, Jump, ...>, sockets <hand_R, ...>
- models/<enemy>.glb: ...
- models/<prop>.glb: ...

Requirements:
- app.json: "category": "games", "gamepad": true, a resizable "window", "minSdk": "1.8", "targetSdk": "1.8",
  "permissions": [] unless needed.
- Load every model with g3d.loadModel in app.load (never g3d.model for big files) and show a loading screen drawn
  in the game's style until they arrive; handle a failed load with a message. No callback may come near 3 seconds
  (app.load near 10): split other long work (terrain, level building) into slices of a few milliseconds per frame.
- Animation: play clips by name, change them only when the state changes, crossfade with {fade = 0.1-0.3}, play
  one-shot clips with {loop = false} and return to the loop when model:playing() is false; call model:update(dt)
  every frame. Attach held objects or effects with model:nodeMatrix + g3d.drawMatrix.
- Camera: <follow / orbit / fixed / first person>, eased, with a short shake on impacts. Movement relative to the
  camera; a model faces +Z at yaw 0 (yaw = math.atan(vx, vz)).
- Collision: write small helpers (sphere vs sphere, sphere vs box with a push-out, ray vs box, ray vs triangle for a
  simple collision mesh, ground height from a heightmap); clamp dt; there is no physics engine for g3d scenes.
- Budget for 60 fps on the Switch: 30-60k triangles per frame, 8-16 skinned characters, about 150 draw calls, fog
  to hide the far plane, static props merged into one g3d.custom mesh where possible. No table creation or image
  loading in update/draw loops.
- Art direction first (a comment at the top of the main file: feeling, palette, typography, camera language, motion,
  sound palette, UI shape language). The title screen, HUD and pause screen are drawn with gfx / g3d in that
  direction; no ui.* widgets, no theme colors, and no copy of any sample's or game's menu layout or title.
- Controls: left stick / D-pad + buttons, right stick for the camera, keyboard (WASD + arrows + Space/Enter/Esc) and
  touch (a stick where the finger lands, taps for actions). Pause on +, in suspend and on focus(false).
- Saving with store: progress, best score and settings (music on/off, effects volume, rumble, invert camera Y).
- Every visible text through TR(): lang/en.json plus one lang/<code>.json per other language above.

Deliver every file in full, then: how to check it on a PC, how to run it on the console, the export settings I must
use for the models if they are wrong, how to make the store icon from these models (key art), and what you are not
sure about.
```

Follow-ups: "add an enemy that chases the player with a simple state machine", "add a collision mesh for the level
and use ray vs triangle for the ground", "measure: print the triangle count and fps every second", "write the
store.json" ([store-listing.en.md](store-listing.en.md)), "the icon prompt" ([store-icon.en.md](store-icon.en.md)).
