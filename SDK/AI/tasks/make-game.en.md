# Task: make a game

**English** · [Türkçe](make-game.tr.md)

Copy the prompt below, fill in the `<...>` parts and send it after the context pack (`system-prompt.en.md` + the language
pack). For Lua, the `nexvyn.game` engine (SDK.en.md section 8c) saves a lot of code: give the assistant that section too.

```text
Write a complete Nexvyn OS game.

Game: <genre and one-paragraph idea, e.g. "a one-screen arcade game where you dodge falling blocks">
Language: <Lua with nexvyn.game | Lua | JavaScript | Python | Squirrel | C | Java>
App id: com.<yourname>.<game>   Name: <English name> / <Turkish name>

Requirements:
- app.json: "category": "games", "gamepad": true, "window" resizable, the right "runtime"/"main"/"minSdk",
  "permissions": [] unless the game really needs one.
- Controls: D-pad / left stick + A/B on the controller, arrow keys / WASD + Space/Enter on a keyboard, and touch
  (on-screen buttons or tapping). Show the controls on the title screen.
- Screens: title, play, pause (on + / Escape / P, and in suspend / focus(false)), game over with restart.
- Fixed-step update (accumulate dt), drawing only in draw; no allocations or image loading per frame.
- A best score saved with store (or game.save with nexvyn.game).
- Sound effects with audio.tone or game.audio; light rumble with sys.vibrate on hits.
- Every visible text through TR() with lang/en.json and lang/tr.json (also de, fr, es if you can).
- Use theme colors for UI chrome so light and dark mode look right.

Deliver every file in full (app.json, source files, lang files), then a short list: how to check it on a PC with the
right checker, how to run it on the console, and what you are not sure about.
```

Follow-ups that work well: "add a second level", "make the difficulty ramp up over 2 minutes", "add a store.json
for the App Market" (see [store-listing.en.md](store-listing.en.md)).
