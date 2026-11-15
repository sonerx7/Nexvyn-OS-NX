# Task: make a utility app

Send after the context pack (`system-prompt.md` + the language pack).

```text
Write a complete Nexvyn OS utility app.

App: <what it does, who uses it, the 3-5 main features>
Language: <Lua | JavaScript | Python | Native C/C++>
App id: com.<yourname>.<app>   Name: <name>
Languages of the app: English<, plus any others>
Data: <what must be saved; e.g. "a list of entries with date and amount">
Network: <none | which public HTTPS API, no API keys>

Requirements:
- app.json with the right "runtime"/"main"/"minSdk", a suitable "category" and ONLY the permissions the code uses
  (network for net.*, notifications for sys.notify/sys.schedule, games for sys.games, launch for sys.launch
  or nxv:// links, files for paths outside the app's folders).
- Strict Nexvyn OS Design System Parity across all 4 runtimes (Lua, JS, Python, Native C/C++):
  - Window background cleared with `theme.window` (Script) or `nxn_os_clear_color(tok)` (Native C++).
  - 20 px outer window margin; 16 px horizontal / 13 px vertical card padding; 10 px card corner radius.
  - In Light mode: cards have 10px radius, 1px border (`theme.border`), and soft drop shadows (`gfx.shadow` / `nxn_os_card_begin_ex`).
  - Strict Typography Scale: App Title `19pt Bold`, Card Header `15pt Bold`, Body/Controls/Keys/Values `13.8pt Medium` (or `13pt Sans` for keys), Badges/Subtitles `12pt Medium`.
  - In Native C/C++: multiply points by `1.21f` (Inter FreeType EM factor) for `SizePixels`, use `NXN_UI_FONT_BOLD` for headers and `NXN_UI_FONT_MEDIUM` for body/controls, keep `io.FontGlobalScale = 1.0f`, and snap drawing with `floorf(v + 0.5f)`.
  - Component geometry: Action buttons 30 px tall (radius 6 px); segmented navigation tabs 32 px tall (track radius 7 px, pill 5.5 px); switches 38x22 px; dropdowns 30 px tall with trailing double chevron chip; status badges 22 px pill.
  - Hairlines: 1 px solid `theme.separator` / `tok.separator`.
- Unified OS UI components: in Lua/JS/Python use `ui.*` (ui.beginScroll, ui.group, ui.separator, ui.segmented, ui.toggle, ui.dropdown) or `nxui.*`; in Native C/C++ use `<nexvyn/nxn_os_ui.h>` + `<nexvyn/nxn_imgui.h>` driven live by `nxn_ui_tokens_get` (never raw unstyled ImGui).
- Save every change at once with store (or fs for documents); implement autosave and unsaved if there is a document.
- If it uses the network: check sys.online() first, show a spinner while loading and a friendly error message.
- A menu (app.menu / app.onmenu) with the main actions and keyboard shortcuts.
- Every visible text through TR() with lang/en.json, plus one lang/<code>.json for each other language above.
- Keep app.draw cheap: no file reads, image loads or big allocations per frame.

Deliver every file in full, then how to check it on a PC and run it on the console, and any assumption you made.
```
