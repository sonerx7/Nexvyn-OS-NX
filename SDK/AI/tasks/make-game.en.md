# Task: make a game

**English** · [Türkçe](make-game.tr.md)

Copy the prompt below, fill in the `<...>` parts and send it after the context pack (`system-prompt.en.md` + the language
pack). For a 2D game in Lua the `nexvyn.game` engine (SDK.en.md section 8c) saves a lot of code: give the assistant
that section too. For a 3D game with models use [make-3d-game.en.md](make-3d-game.en.md). The full recipe for people
and assistants is `SDK/Guides/MAKE_A_GAME.en.md`.

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
- Sound effects with audio.tone, game.audio or sound files, one consistent sound family; light rumble with
  sys.vibrate on hits, with a setting to turn it off.
- Every visible text through TR() with lang/en.json, plus one lang/<code>.json for each other language above.
- Polish: eased motion, a short hit pause or camera shake on impacts, particles on pickups, something alive on the
  title screen.

Deliver every file in full (app.json, source files, lang files), then a short list: how to check it on a PC with the
right checker, how to run it on the console, how to make the store icon (key art of this game, see
store-icon.en.md), and what you are not sure about.
```

Follow-ups that work well: "add a second level", "make the difficulty ramp up over 2 minutes", "add a settings
screen (music, effects volume, rumble)", "add a store.json for the App Market" (see
[store-listing.en.md](store-listing.en.md)), "write the key-art prompt for the icon" (see
[store-icon.en.md](store-icon.en.md)).
