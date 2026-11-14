# Task: make a game

Copy the prompt below, fill in the `<...>` parts and send it after the context pack (`system-prompt.md` + the language
pack). For a 2D game in Lua the `nexvyn.game` engine (SDK.md section 8c) saves a lot of code: give the assistant
that section too. For a 3D game with models use [make-3d-game.md](make-3d-game.md). The full recipe for people
and assistants is `SDK/Guides/MAKE_A_GAME.md`. Give the assistant the kit files too (`SDK/Languages/lua/kits/sfx.lua`
and `juice.lua`, or the `.js` versions) when the context allows: it then uses them exactly as they are.

```text
Write a complete Nexvyn OS game.

Game: <genre and one-paragraph idea, e.g. "a one-screen arcade game where you dodge falling blocks">
Language: <Lua with nexvyn.game | Lua | JavaScript | Python>
App id: com.<yourname>.<game>   Name: <name>
Languages of the game: English<, plus any others, e.g. Spanish, German>

Requirements:
- app.json: "category": "games", "gamepad": true, "window" resizable, the right "runtime"/"main",
  "minSdk" for the newest feature used, "targetSdk": "1.8", "permissions": [] unless the game really needs one.
- Art direction first: before any code, write a short art direction as a comment at the top of the main file
  (the feeling in one line, a palette of 3-4 colours, typography, camera or framing, motion style, sound palette,
  UI shape language). Everything on screen follows it. Draw the title screen, HUD and pause screen yourself with
  gfx (and g3d); do not use ui.* widgets or theme colors for game UI, and do not copy the menu layout, colours or
  title composition of any sample or other game. Pick a menu form that suits this game (a single prompt, a row,
  cards, a numbered column, objects in the world...).
- Controls: D-pad / left stick + A/B on the controller, arrow keys / WASD + Space/Enter on a keyboard, and touch
  (on-screen controls that appear after a touch, or tapping). Show the controls in the game.
- Screens: title, play, pause (on + / Escape / P, and in suspend / focus(false)), game over with restart.
- Fixed-step or clamped dt update, drawing only in draw; no allocations or image loading per frame; no callback near
  3 seconds (app.load near 10).
- A best score saved with store (or game.save with nexvyn.game).
- Sound with the sfx kit (or sound files), one consistent sound family; light rumble with sys.vibrate on hits,
  with a setting to turn it off.
- Every visible text through TR() with lang/en.json, plus one lang/<code>.json for each other language above.
- Quality bar (SDK/Guides/GAME_FEEL.md section 8 and SOUND_DESIGN.md; mandatory):
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

Deliver every file in full (app.json, source files, lang files), then a short list: how to check it on a PC with the
right checker, how to run it on the console, how to make the store icon (key art of this game with
SDK/Tools/icon, see store-icon.md), which quality-bar items you could not meet, and what you are not sure about.
```

Follow-ups that work well: "add a second level", "make the difficulty ramp up over 2 minutes", "add a settings
screen (music, effects volume, rumble)", "add a store.json for the App Market" (see
[store-listing.md](store-listing.md)), "write the key-art prompt for the icon" (see
[store-icon.md](store-icon.md)).
