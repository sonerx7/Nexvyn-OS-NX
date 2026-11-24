# Checklist for the assistant (run through it before answering)

## Current authoring contract

Use SDK 1.16 / Native SDK 1.2 / ABI v1. For all new apps, games, ports and launchers:
- Ship complete en, tr, de, es, fr, ja, ko and zh dictionaries; check keys and placeholders with `nxv_i18n.py --check`.
- Keep SDK Markdown English only. Store screenshots may use English UI.
- OS apps use shared theme/typography/controls; games require their own art direction.
- Native ImGui UI uses `nxn_os_ui.h`, `nxn_imgui_input` before the frame and `nxn_imgui_input_event` for lifecycle events.
- Use stable contact IDs for real game/canvas multitouch; ordinary widgets use one primary pointer.
- Include compact/wide resize, nested scroll, keyboard/pad focus, focus-loss cancellation, loading, save/reopen and clean exit.
- Read exact signatures from the installed reference/headers. Do not invent APIs, multitouch manifest flags, a sandbox, a future backend or a guaranteed frame rate.
- Complete one polished playable/useful vertical slice, then profile actual hardware and review all eight translations.

See the Product Quality, Input Contract, Localization Contract and Port and Launcher guides.

Give this file to the assistant together with `system-prompt.md`, or paste it at the end of a request:
"Before you answer, go through checklist.md and fix anything that fails."

## API

- [ ] Every function, module, field, event type, key name and app.json key I used is in SDK.md / system-prompt.md.
      Nothing is invented (no `fetch`, `localStorage`, `io.open`, `os.listdir`, `ui.image`, `gfx.sprite`,
      `gfx.font`, custom shaders...).
- [ ] The language rules are applied: index base (Lua 1, others 0), several results (Lua multiple returns, JS arrays,
      Python tuples, Squirrel arrays, C pointers, Java `double[]`/`List`), `ui.textfield` / `ui.submitted`, `ui.row`.
- [ ] Async: Lua/Python/Squirrel callbacks; JS Promises with `try`/`catch`; C function pointers with `void* user`;
      Java `(Callback)` lambdas.
- [ ] `minSdk` matches the newest feature used and the language (JS 1.1, Python 1.3, Squirrel/C/Java 1.5,
      `nexvyn.game` 1.2, share/schedule/permission API/lifecycle callbacks 1.4, `fs.unzip`/`sys.games`/`sys.speak`
      1.6, `g3d.voxels` 1.7, `g3d.model`/`g3d.loadModel`/`g3d.drawMatrix` 1.8, the pbr renderer, `net.request` options, `net.ws`,
      `net.oauth`, `gfx.imageUrl`, `media.*`, `ui.beginFeed`/`ui.pager`/`ui.richText` 1.9; Native `.nxvmod` 1.10; `ui.chooseFolder`, `fs.folderGrants`, `fs.saveBackup` and friends 1.11; `ui.tokens`, `audio.stopAll` 1.12; `nxui.*`, `loadingHint` 1.13 / 2.0; `phys.*`/`nav.*` 1.15; idle frame pacing, `input.touches` 1.16). New apps set
      `"targetSdk": "1.16"` (the current SDK; `"2.0"` is only a target marker, see `SDK/AI_GUIDE.md` section 1).
- [ ] New apps use one of the **4 Official Primary Runtimes** (**Lua 5.4.7**, **JavaScript ES2023**, **CPython 3.12**, or **Native C/C++ ABI v1**) unless the user explicitly requested a compatibility runtime.
- [ ] Language fits the job: a UI-heavy tool / utility / productivity app is Lua, JavaScript or Python with `nxui.*`;
      Native C/C++ only for heavy computation (LLM inference, emulator, 3D, codecs). No native-engine + script-UI hybrid
      (not possible yet).
- [ ] Native ImGui UI: `nxn_os_frame_begin` / `nxn_os_frame_end` every frame; only `nxn_os_*` widgets (no raw
      `ImGui::Button`, `Combo`, `Checkbox`, `SliderFloat`, `InputText`); text with `nxn_os_text(NXN_OS_TEXT_*)`; every
      pixel number as `NXN_S(px)`, `nxn_os_sp()` or `nxn_os_fill()`; no `FontGlobalScale`, `SetWindowFontScale` or
      own fonts; `python tools/nxv_native check-design <dir>` passes.

## app.json

- [ ] Valid JSON; `id` reverse-domain (`com.name.app`); `name` and `description` with at least `en` (other languages
      only when the user wants them).
- [ ] `runtime` / `main` (and `mainClass` for Java) match the files I delivered.
- [ ] `permissions` lists exactly what the code uses (`network`, `files`, `launch`, `notifications`, `games`);
      `[]` when nothing.
- [ ] `category` is one of system, productivity, office, utilities, media, internet, games, switch, developer, emulator, showcase, education, themes, fonts, runtimes, other (the packer rejects any other value). Games have
      `"gamepad": true` and a resizable window.

## Behaviour

- [ ] No callback can run near 3 seconds (`app.load` and the top level near 10): no unbounded loops; models load
      with `g3d.loadModel`; long work is split across frames, timers or a coroutine. C code has bounded loops (it
      is not stopped by the system).
- [ ] `draw` is cheap: no image or model loading, file reading, network calls or big allocations per frame; meshes,
      models and images are created once.
- [ ] Data is saved with `store` / `fs` when it changes; nothing is lost on `suspend` or close.
- [ ] Network: `sys.online()` checked, loading and error states shown, no API keys or secrets in the code.
- [ ] SDK 1.9 feeds and media: long lists use `ui.beginFeed` (never a loop over every item), web pictures use
      `gfx.imageUrl` with a `maxSize` and a placeholder while loading, at most 3 `media` players are open (the
      current and the next), players pause in `suspend`, sockets are polled every frame, sign-in has a fallback.
- [ ] Works with touch, the controller cursor and a keyboard; games also with the controller, pause on + and in
      `suspend` / `focus(false)`.
- [ ] Input and play modes (`Guides/INPUT_AND_PLAY_MODES.md`): works with touch only and with a controller only (docked has
      no touch), handheld and docked sizes, window and full screen, moderate sound that pauses on focus loss and sleep.
- [ ] Every visible string goes through `TR()`; every key exists in `lang/en.json` (and in each other lang file I
      delivered, or it falls back to English); placeholders `{0}` match the arguments.
- [ ] Apps: `theme` colors (light and dark mode); controls ≥ 28 px; the layout fits the minimum window size.
- [ ] Widget ids are unique in the window (`"Delete##" + i` in lists).

## Games: look and identity

- [ ] I wrote the art direction down (feeling, palette, typography, camera, motion, sound, UI shapes) and the title
      screen, HUD and pause screen follow it.
- [ ] The game UI is drawn with `gfx` / `g3d`, not with `ui.*` widgets or `theme` colors, and it does not copy a
      sample's or another game's menu layout, colours or title composition.
- [ ] 3D models: `.glb` (or `.fbx`), metres, +Y up, facing +Z, pivot at the feet, named clips; triangle budget kept
      (hero 3-8k, 30-60k per frame).
- [ ] The store icon is 256x256 key art that shows the game itself (hero, object or world), not a placeholder glyph
      on a gradient; it follows the style the maker asked for, or the clean default (no text, restrained effects)
      when nothing was said; I said how to make it (`SDK/Tools/icon` or the image-generator prompt).

## Games: quality bar (SDK/Guides/GAME_FEEL.md section 8)

- [ ] Every player and menu action has a sound and a visual response on the same frame, scaled to the event (a pickup
      is small; a heavy hit has particles, a flash, shake and a short hit-stop).
- [ ] Sound: layered effects with variants (the `sfx` kit or my own recipes), no raw unfiltered square / saw at full
      volume, music and an ambience bed, music mixed under the effects and ducked on big moments, volume settings.
- [ ] Colour: a palette of 4-6 colours with roles; no flat single-colour background (gradient, glow, vignette, light,
      texture or parallax); the player and dangers stand out in grey.
- [ ] Type: 3-4 sizes from one scale; the title is a styled logo, not default text at default size.
- [ ] UI: one shape language; panels with depth; buttons with hover, press, focus and disabled states; a transition
      between every pair of screens; something alive on the title screen.
- [ ] Camera: smoothed; in 3D fog in the sky colour and a coloured key light.
- [ ] pbr renderer (SDK 1.9): `g3d.renderer("pbr")` is called in `app.load` and the game also works when it returns
      `"basic"`; lights, shadows, exposure and bloom follow the art direction; repeated props use
      `g3d.drawInstanced`; the budget starts at msaa 0, shadows "medium", textures up to 1024 px.
- [ ] Where the kits fit, I used them (`sfx`, `juice` copied into the bundle) instead of inventing weaker versions,
      and only with the functions they really have.

## Answer

- [ ] Every file is complete (no "..." or "rest unchanged"), with its path in the bundle.
- [ ] I answered in the user's language; the app's texts are in English plus the languages the user asked for.
- [ ] I said how to check it (`python SDK/Tools/nxv/nxv.py check <folder>`) and
      how to run it (copy to `sdmc:/NexvynOS/Applications/<Name>.nxvapp/`, or Studio → Run).
- [ ] I listed what I am unsure about instead of guessing silently.
- [ ] For a store submission: `store.json` with `subtitle` / `description` in English at least (more languages when
      wanted), `kind`, `tags` and `shots` (5 recommended) using only `wait`, `wclick`, `wmove`, `key`, `hold`, `dpad`, `text`, `dark`.

- [ ] Native OS-look app calls `nxn_imgui_input` once per frame before the frame layer; no second input feeder.
- [ ] Drag a slider outside its bounds, swipe the inner frame without moving the outer frame, type text, and use keyboard/gamepad focus. Test one additional finger joining/leaving.
- [ ] Interpreted C bundle passes `nxv check` with its real SDK header compile check (compiler skips do not count as device validation).

- [ ] Forward focus events with `nxn_imgui_input_event(event)`; test losing focus while a key or touch is held.
- [ ] Resize from wide to compact and back without losing edits, selection or scroll position. New touch stops a fling without activating its moving row; keyboard focus remains visible inside scroll views.
