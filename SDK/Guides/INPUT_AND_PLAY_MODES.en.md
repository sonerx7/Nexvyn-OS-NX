# Fitting into Nexvyn: input, play modes, window and full screen, sound

Every app, game and port made with the SDK should work the way the user holds the console: touch, a controller
(Joy-Con pair attached or detached, a single Joy-Con where it makes sense, Pro Controller), handheld or docked.
This page lists what to support and which existing API gives it. It adds no API. Turkish: `INPUT_AND_PLAY_MODES.tr.md`.

## 1. Input: support all of it

| Input | Script apps (Lua, JavaScript, Python) | C (`nexvyn.h`) | Native (`nxn_*`) and SDL2 |
|---|---|---|---|
| Pointer and touch | events `"mousedown"`, `"mouseup"`, `"mousemove"`, `e.touch` is true for a finger; `input.touch()` says the user is on the touch screen | same events and `input_touch()` | `nxn_input_touch(i, &t)` for `i < nxn_input_state.touch_count` (up to 16 fingers); in SDL2 `SDL_FINGERDOWN` / `MOTION` / `UP` |
| Finger identity | a finger drag is one pointer; two fingers are a gesture | same | each finger has a stable `t.id` (0, 1, 2 ...; one finger is always 0), in SDL2 `SDL_FingerID` |
| Gestures | events `"scroll"` (also two-finger pan), `"pinch"` (`e.scale`), `"rotate"` (`e.angle`) | same events | read two `nxn_touch` points and compute distance / angle yourself (touch ids stay stable) |
| Buttons and sticks | events `"paddown"` / `"padup"` (`e.pad`), `input.stick("left"\|"right")`, `input.action(name)` for the user's own button mapping | `input_*` | `nxn_input_poll` (`buttons`, `pressed`, `lx, ly, rx, ry`, `NXN_ACT_CONFIRM` / `NXN_ACT_CANCEL`); SDL2 joystick or game controller |
| Keyboard, mouse | events `"keydown"`, `"text"`, mouse events | same | `nxn_input_key_held`, `nxn_input_mouse` |
| Handheld or docked | no query or event in scripts yet (parity gap, below): use `gfx.size()` each frame and lay out for the size you get | no query yet (same gap) | `NXN_EVENT_DOCK` (`docked` 1 or 0, `NXN_CAP_POWER_EVENTS`), `NXN_EVENT_RESIZE` (`width`, `height`, `docked`) |

What to do:

- **Touch.** Every control reachable with a finger: targets at least 44 px, no hover-only actions, drag and tap must
  not need two buttons. Multi-touch games read every finger by id, not "the first touch".
- **Controller.** Every action reachable with the pad too. A single Joy-Con held sideways has no second stick: keep
  the core of the game on one stick and four buttons, put the rest in menus. Use `input.action("select")` /
  `NXN_ACT_CONFIRM` / `NXN_ACT_CANCEL` for confirm and back so the user's own mapping works. Do not assume a pad
  exists: the console can be docked with no controller connected, or handheld with the Joy-Con attached.
- **No touch in docked mode.** On a TV the user has no touch screen: nothing may need a touch (no "tap to start",
  no touch-only close or back button), and the controller must work from the first screen. Show button glyphs
  (`A`, `B`) when `input.touch()` is false and tap hints when it is true.
- **Handheld and docked.** The output is 1280x720 handheld and 1920x1080 docked. Native apps get
  `NXN_EVENT_DOCK` / `NXN_EVENT_RESIZE`; follow with `nxn_display_resize` or keep your size and let the system scale.
  Lay out in relative units (a fraction of `gfx.size()` / the surface size), scale text by the OS text scale
  (`ui.tokens().textScale`, `nxn_ui_tokens_get`), keep important things inside a 5 % safe margin on a TV, and never
  hard-code 1280x720.

## 2. Window and full screen

- Games open full screen, apps open maximized. Support both a window and full screen: the app can be resized at any
  time (`NXN_EVENT_RESIZE`; `gfx.size()` changes in scripts). Keep your aspect ratio, bars or an adapted layout, never a
  stretched picture. Live resize while the user drags an edge is opt-in (`native.liveResize`, or `"liveResize": true` in
  `app.json` for older native apps).
- Never trap input. In full screen the user leaves by holding - for one second (`wm.fullscreenExitHold`); a short
  press of - still reaches the app, so do not use a held - for anything. Do not swallow HOME, the menu bar edge swipe
  or L + R (hold): they stay with Nexvyn OS.
- Touch from the top edge shows the **Exit full screen** button: do not draw your own controls under that edge that
  need a swipe from the top.

## 3. Sound

- Use the system mixer: `audio.play`, `audio.tone`, `audio.music` in scripts, `nxn_audio_*` / SDL2 audio in native
  apps. The system volume applies; do not add a second master volume at full by default.
- Any sample format and any rate from 11 025 to 48 000 Hz works in the SDL2 kit (rebuild with the current kit if an old
  build crackled).
- No loud defaults: start music and effects at moderate volume, never above what the user last set, and offer a
  volume or mute control in your own settings.
- Pause on focus loss and sleep. Native: stop your music on `NXN_EVENT_FOCUS` (`focused` 0) and `NXN_EVENT_SUSPEND`;
  after `SUSPEND` the system plays no sound of the app until `RESUME` and drops what was queued. Scripts: pause in
  `app.focus(false)` and `app.suspend()` (`audio.musicPause(true)`), resume in `app.focus(true)` / `app.resume()`.

## 4. System navigation and a clean exit

- HOME, the menu bar or taskbar, the App Switcher and sleep belong to Nexvyn OS. The app only reacts.
- Quit: native apps get `NXN_EVENT_QUIT` (close button or system exit): save and return from the entry soon. Scripts: `app.close()` (return `false` to keep
  the window open, e.g. to ask to save) and `app.suspend()`; also write progress as it happens (level end, pause).
- Sleep and resume: native apps get `NXN_EVENT_SUSPEND` and `NXN_EVENT_RESUME`, scripts `app.suspend()` and
  `app.resume()`: save on suspend, do not assume a network connection survived the resume.
- Do not block the main loop: a callback that holds the system for 12 seconds brings the Force Quit / Wait question
  (older apps are only asked, never ended). Load in the background and keep drawing.

## 5. Performance

- Keep frame time under 16.6 ms and let the system pace the frame: do not busy-wait or sleep-loop for timing.
- `native.frameAhead` stays 0 for games unless you measured a gain (it costs up to a frame of latency).
  `gfx.dynamicRes` (`auto`, `on`, `off`) lowers the render size towards 60 fps; `auto` is on only for apps that target
  an SDK newer than 1.12. Do not fight it with your own resolution scaler.
- Benchmarks run uncapped (no vsync wait, no frame limiter) and report the average and the worst frame; leave the cap
  on in the shipped game.

## Parity gaps (nothing is invented here)

| Missing for | Where | Workaround |
|---|---|---|
| Lua, JavaScript, Python, C scripts | handheld / docked query or event | read `gfx.size()` each frame |
| Lua, JavaScript, Python, C scripts | raw finger list with ids | use `"pinch"`, `"rotate"`, `"scroll"` events |

## Checklist

- [ ] Works with touch only (handheld, Joy-Con attached) and with a controller only (docked, no touch).
- [ ] Works with detached Joy-Con (both) and, where sensible, one Joy-Con; confirm / back follow the user's mapping.
- [ ] No hard-coded resolution: handheld 1280x720, docked 1920x1080, window and full screen resize cleanly.
- [ ] Text scales with the OS text scale; touch targets at least 44 px; TV safe margin.
- [ ] Hold - leaves full screen; the app swallows no system gesture.
- [ ] Sound starts moderate, follows the system volume, pauses on focus loss and sleep.
- [ ] Saves on quit and sleep (`NXN_EVENT_QUIT` / `SUSPEND`, `app.close` / `app.suspend`).
- [ ] No frame over 16.6 ms in normal play; benchmarks are uncapped, the shipped build is not.

## Testing tips

- Run the app in a window, in full screen, then resize the window to a small and a large size.
- Test handheld and docked in turn: undock while the app runs (native: you should see `NXN_EVENT_DOCK`).
- Play a full round with the touch screen only, then a full round with the pad only and the touch screen untouched.
- Native apps get every finger with its id only when `app.json` says `"minNative": "1.1"` or later; a 1.0 app keeps the
  old single-pointer touch exactly as before.
- Two fingers at once: the autorun test command `finger <n> down|move|up <x> <y>` injects them (two ids make
  pinch, rotate and two-finger pan); the SDL2 check example prints the most fingers down at once.
- Put the console to sleep during play and wake it: sound and saved state must be right.
