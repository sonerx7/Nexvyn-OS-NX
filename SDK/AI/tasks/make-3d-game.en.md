# Task: make a 3D game with models

**English** · [Türkçe](make-3d-game.tr.md)

For a 3D game that uses `.glb` / `.fbx` models (SDK 1.8) and the pbr renderer (SDK 1.9). Send it after the context pack (`system-prompt.en.md` + the
language pack). Give the assistant SDK.en.md section 8b (*3D*, *3D models* and *Modern rendering*) and, if the context is large enough,
`SDK/Guides/MAKE_A_GAME.en.md` (the full recipe: export rules, loading, collision helpers, budgets, art direction).
Look at the sample `SDK/Samples/lua/ember-field` for a complete small game, but do not let the assistant copy its look.

Before you ask, check each model once in the game or in Studio's *3D Models* template and note what `model:info()`
reports (size, triangles, bones, clip names).

```text
Write a complete Nexvyn OS 3D game with SDK 1.9.

Game: <genre and one-paragraph idea>
Language: <Lua | JavaScript | Python>
App id: com.<yourname>.<game>   Name: <name>
Languages of the game: English<, plus any others>
Models in the bundle (from model:info()):
- models/<hero>.glb: <height> m, <triangles> triangles, clips <Idle, Run, Jump, ...>, sockets <hand_R, ...>
- models/<enemy>.glb: ...
- models/<prop>.glb: ...

Requirements:
- app.json: "category": "games", "gamepad": true, a resizable "window", "minSdk": "1.9", "targetSdk": "1.9",
  "permissions": [] unless needed.
- Load every model with g3d.loadModel in app.load (never g3d.model for big files) and show a loading screen drawn
  in the game's style until they arrive; handle a failed load with a message. No callback may come near 3 seconds
  (app.load near 10): split other long work (terrain, level building) into slices of a few milliseconds per frame.
- Animation: play clips by name, change them only when the state changes, crossfade with {fade = 0.1-0.3}, play
  one-shot clips with {loop = false} and return to the loop when model:playing() is false; call model:update(dt)
  every frame. Attach held objects or effects with model:nodeMatrix + g3d.drawMatrix.
- Modern look (SDK 1.9): in app.load call g3d.renderer("pbr") and keep the game correct when it returns "basic".
  Pick the light of the art direction: the sun (g3d.light direction and colour), sky / ground or a cube map
  (g3d.environment), 1-4 coloured point or spot lights with ids (g3d.addLight, moved with g3d.updateLight).
  g3d.shadows({quality = "medium", distance = <visible play area>}); g3d.postfx({exposure, tonemap = "aces" or
  "filmic", bloom = 0.03-0.1}); emissive parts above 1 glow. Models keep their PBR maps (glTF base colour, normal,
  ORM, emissive; FBX with its texture folder next to it); plain meshes get g3d.material(mesh, {metallic, roughness,
  ...}); glass gets {transmission = 0.9, roughness = 0.05}. Repeated props (grass, pillars, crates) use
  g3d.drawInstanced. Show the renderer and fps in a debug line I can turn off.
- Camera: <follow / orbit / fixed / first person>, eased, with a short shake on impacts. Movement relative to the
  camera; a model faces +Z at yaw 0 (yaw = math.atan(vx, vz)).
- Collision: write small helpers (sphere vs sphere, sphere vs box with a push-out, ray vs box, ray vs triangle for a
  simple collision mesh, ground height from a heightmap); clamp dt; there is no physics engine for g3d scenes.
- Budget for 60 fps on the console (pbr: start with msaa 0, shadows "medium", textures up to 1024 px): 30-60k triangles per frame, 8-16 skinned characters, about 150 draw calls, fog
  to hide the far plane, static props merged into one g3d.custom mesh where possible. No table creation or image
  loading in update/draw loops.
- Art direction first (a comment at the top of the main file: feeling, palette, typography, camera language, motion,
  sound palette, UI shape language). The title screen, HUD and pause screen are drawn with gfx / g3d in that
  direction; no ui.* widgets, no theme colors, and no copy of any sample's or game's menu layout or title.
- Controls: left stick / D-pad + buttons, right stick for the camera, keyboard (WASD + arrows + Space/Enter/Esc) and
  touch (a stick where the finger lands, taps for actions). Pause on +, in suspend and on focus(false).
- Saving with store: progress, best score and settings (music, effects and ambience volume, rumble, invert camera Y).
- Quality bar (SDK/Guides/GAME_FEEL.en.md section 8 and SOUND_DESIGN.en.md; mandatory):
  * Use the kits: copy SDK/Languages/<lua|javascript>/kits/sfx and juice into the bundle and use them for sound,
    particles, shake, hit-stop, flashes, transitions, titles, panels and buttons (other languages: the same blocks
    from SDK calls). Use only functions the kits really have (system prompt section 7a).
  * Every player and menu action has a sound and a visual response on the same frame, scaled to the event.
  * Sound: layered recipes with 3-4 variants, no raw unfiltered square or saw at full volume, a music loop and an
    ambience bed, music mixed under the effects and ducked on big hits, music / effects / ambience volume settings.
  * Colour: a palette of 4-6 colours with roles; no flat single-colour backgrounds (gradients, glow, vignette, light,
    parallax); readable in grey.
  * Type: 3-4 sizes from one type scale; the title is a styled logo (outline, shadow, two tones or glow), never
    default text at default size.
  * UI: one shape language, panels with depth, buttons with hover / press / focus / disabled states, a transition
    between screens, something alive on the title screen.
  * 3D: a sky gradient behind the scene, fog in the sky colour, a coloured key light (juice J.looks / J.sky /
    J.light3d or your own), glow on emissive parts, a soft contact shadow under characters, a smoothed follow
    camera (J.cam3d) with a field-of-view kick on dashes and hits.
- Every visible text through TR(): lang/en.json plus one lang/<code>.json per other language above.

Deliver every file in full, then: how to check it on a PC, how to run it on the console, the export settings I must
use for the models if they are wrong, how to make the store icon from these models (key art with SDK/Tools/icon: the hero_render.py and
finish_icon.py commands for my hero), which quality-bar items you could not meet, and what you are not
sure about.
```

Follow-ups: "add an enemy that chases the player with a simple state machine", "add a collision mesh for the level
and use ray vs triangle for the ground", "measure: print the triangle count and fps every second", "write the
store.json" ([store-listing.en.md](store-listing.en.md)), "the icon prompt" ([store-icon.en.md](store-icon.en.md)).
