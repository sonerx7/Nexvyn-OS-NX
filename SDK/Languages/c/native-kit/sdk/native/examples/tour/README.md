# Native Tour

One windowed app that shows the Native SDK 1.1 features and looks like part of Nexvyn OS. It is a demo and an end-to-end
acceptance test: every page checks what it needs and says "not available" instead of failing.

```
python tools/nxv_native build sdk/native/examples/tour
python tools/nxv_native package sdk/native/examples/tour      # -> build/tour.nxvapp (tourlib.nxvlib and the 3D scene inside)
```

Turn on, in Settings > Developer, `native.windowedTls`, `native.windowedEh`, `native.windowedLibs` and `native.windowMenu`
to see every row green. With them off the Runtime page says so, and the pages are picked from a tab bar instead of the
window menu. L / R (or the keys 1 to 5) switch pages too.

| Page | Shows | API |
|---|---|---|
| 3D | a baked PBR scene with a sun shadow, orbit camera, fps counter, drag or left stick to look around, right stick to move in and out | `ngfx_*` (`nexgfx_native.h`) |
| Sound | mixer, procedural tones, a melody, the user's button mapping plays notes | `nxn_sfx_play`, `nxn_tone`, `nxn_input_action_buttons` |
| System | notification, clipboard, rumble, file / folder dialogs (on a worker thread), save backups, permissions | `nxn_notify`, `nxn_clipboard_*`, `nxn_rumble`, `nxn_pick`, `nxn_save_*`, `nxn_perm_*` |
| Runtime | `thread_local` on 3 threads, C++ exceptions (also across a library), `nxn_lib_open` | `tourlib.nxvlib`, `src/tour_rt.cpp` |
| About | SDK version, capability bits, heap use | `nxn_caps_get`, `nxn_info_string` |

The look comes from the system: colours, sizes, the font and the icons (`nxn_ui_tokens_get`, `nxn_ui_font_get`,
`nxn_ui_icon_code`), the language from `lang/*.json` (`nxn_tr`: en, tr, de, ja, ko, zh). The font is loaded with `nxn_imgui.h`, which adds
the glyph ranges of the user's language. The window menu is `nxn_menu_set` (pages and view options).

## Self-test

The app writes `TOUR selftest <page> OK|NA|FAIL <detail>` lines to its log (`System/Logs/Apps/com.nexvyn.example.tour.log`), then
`TOUR selftest DONE ok=N na=N fail=N`, and `TOUR ended` when it closes. Quiet checks run always; when `<data>/autotest` exists
the calls that touch the user's things run once too (clipboard, a notification, a save backup / restore / delete round trip).
The file dialogs need a person.

## Content

`data/tour.nxsc` and `data/tour.nxtx` are made by `gen_scene.py` (procedural geometry and a generated floor texture; nothing
third-party) and baked with `tools/nxv_asset`; `icon.png` by `gen_icon.py`. Both scripts need Pillow and numpy.
