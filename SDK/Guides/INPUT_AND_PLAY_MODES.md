# Fitting into Nexvyn: input, play modes, window and full screen, sound

Every app, game and port made with the SDK should work the way the user holds the console: touch, a controller
(Joy-Con pair attached or detached, a single Joy-Con where it makes sense, Pro Controller), handheld or docked.
This page lists what to support and which existing API gives it. It adds no API.`.

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


## Native UI interaction backend

Native ImGui utilities should include `nxn_os_ui.h` and use one shared input backend. After `nxn_input_poll`, call `nxn_imgui_input(backend, state, dt)` before `nxn_os_frame_begin`. Keep `nxn_imgui_input_state backend` alive for the lifetime of the ImGui context. Do not feed another platform backend or consume mouse/key/text queues a second time. The helper is header-only; it adds no host ABI imports beyond existing Native 1.1 USB input functions (use `minNative: 1.1` or newer).

```cpp
static nxn_imgui_input_state backend;
nxn_input_state state = NXN_STRUCT_INIT(nxn_input_state);
nxn_input_poll(&state);
nxn_imgui_input(backend, state, dt);
nxn_os_frame_begin(&tokens, width, height);
// nxn_os_slider, nxn_os_input, nxn_os_dropdown, buttons, child frames ...
nxn_os_frame_end();
```

The backend handles HID keyboard events, UTF-8 text, the system keyboard request, mouse buttons including short taps, wheels, mapped confirm/cancel, D-pad and left-stick focus navigation, and right-stick scrolling. Standalone libraries that do not provide USB input keep touch/gamepad input. Keyboard/gamepad sliders use normal ImGui activation and arrow adjustment; custom OS switches, tabs and list controls participate in navigation.

The frame layer supports finger dragging in the innermost scrollable child window (including raw `ImGui::BeginChild`). A drag becomes scrolling after a small movement threshold. It cancels a pending row click. Sliders and text editing retain capture. Mouse dragging keeps its usual control behavior. Existing compiled modules keep their existing headers and behavior; rebuild with the updated kit to adopt this backend.

Multi-touch UI capture follows the original finger ID, even if array indices change. Releasing that finger does not transfer its drag to a second finger. Games and gesture canvases should read all `nxn_input_touch` contacts by stable `id`; never treat the array index as identity. Reset pinch/rotation baselines when either participating ID changes. The regular UI remains a single-pointer interface; this does not make two independent ImGui widgets concurrently editable.

Script and interpreted C apps use the shared OS `ui.beginScroll` / `ui_beginScroll`, sliders and text fields. Lua, JavaScript, Python and C receive `pinch` and `rotate` events with `scale`, `angle`, local `x`/`y`, and `touch`; apply these only in a canvas or document that supports gestures. Pairing the OS renderer and a native OpenGL ImGui renderer is not supported in one frame.



## Interaction contract for every app language

An OS application uses the same theme tokens, text roles, scaled dimensions and control behavior in Lua, JavaScript, Python, interpreted C and native C++. Native utilities use `nxn_os_ui.h` with its shared input backend. Games may choose their own visual style; controls still obey capture, cancellation and stable contact identity.

| Control | Touch / mouse | Keyboard / gamepad |
|---|---|---|
| Button, switch, list row | Activate on release inside the target; a scroll drag cancels the click | Reach by focus navigation, activate with confirm |
| Slider | Keep the initial pointer until release, including outside bounds; preserve capture inside a scroll pane | Focus, activate, adjust left/right; cancel exits editing |
| Text field | Focus opens the system keyboard when needed; typing is UTF-8 | Tab/Shift+Tab focus, text and editing keys, modifiers and shortcuts |
| Scroll pane | Drag inside the deepest eligible pane; inner movement leaves the outer pane in place; mouse wheel scrolls the hovered pane | Right stick scrolls the hovered or focused pane, left stick/D-pad navigates controls |
| Gesture canvas | Pinch/rotate only where supported; track stable IDs and reset the baseline when a contact changes | Provide a reachable control for the same operation |

C source packages must pass the real-header compilation check as well as manifest/design validation. Compiler skips are reported explicitly. Native OS-look source projects that omit the shared input backend fail the design check. Rebuilding an existing native module adopts the new app-side backend; previously compiled modules keep their existing widget code. The native host supplies one coherent touch snapshot per `nxn_input_poll` and clears access while unfocused.

## Responsive interaction quality

Native ImGui OS apps forward every polled lifecycle event to `nxn_imgui_input_event(event)`
before the next frame, in addition to calling `nxn_imgui_input` once per frame. Focus loss
releases held keys and cancels touch motion. The frame layer supplies kinetic touch scrolling;
a new press stops a fast list without activating a moving row. Mouse-wheel and gamepad input
remain direct. All UI adapters use the shared header-only `nxn_scroll_physics.h` finite-stop
model; frame-rate-independent integration avoids a longer fling at a lower refresh rate.

Native apps targeting Native 2.0, or explicitly opting in with `liveResize: true`, receive coalesced live resize events on shell draws by default. Legacy targets retain their default. Existing
`native.liveResize: false` settings and manifest opt-outs are respected; legacy apps keep the
settled path. Handle the newest size, keep UI state, and call `nxn_display_resize`; do not
recreate the ImGui context or font atlas just because the window dimensions changed. Follow
OS UI scale and text scale separately from viewport size. Native resize diagnostics report
build and request-to-compose distributions; these are not input-to-photon measurements.

OS apps preserve common tokens, typography, focus, control states and behavior across languages.
Use a compact layout when rows no longer fit; do not shrink every control to fit the window.
The Input Lab samples in all five runtime lanes stack their fields below 620 logical pixels.
Test nested scrolling, fast release/stop, keyboard focus reveal, focus loss, pinch contact
changes and resize while controls contain user input. Existing compiled app-side UI code
requires rebuilding to receive new header helpers. Games retain their own visual direction.
