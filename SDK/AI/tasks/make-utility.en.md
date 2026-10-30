# Task: make a utility app

**English** · [Türkçe](make-utility.tr.md)

Send after the context pack (`system-prompt.en.md` + the language pack).

```text
Write a complete Nexvyn OS utility app.

App: <what it does, who uses it, the 3-5 main features>
Language: <Lua | JavaScript | Python | Squirrel | C | Java>
App id: com.<yourname>.<app>   Name: <English name> / <Turkish name>
Data: <what must be saved; e.g. "a list of entries with date and amount">
Network: <none | which public HTTPS API, no API keys>

Requirements:
- app.json with the right "runtime"/"main"/"minSdk", a suitable "category" and ONLY the permissions the code uses
  (network for net.*, notifications for sys.notify/sys.schedule, games for sys.games, launch for sys.launch
  or nxv:// links, files for paths outside the app's folders).
- Layout that works from the minimum window size up (set "minWidth"/"minHeight"), 16-20 px margins, controls at
  least 28 px tall, theme colors only, works with touch, the controller cursor and a keyboard.
- Lists with ui.beginScroll / ui.endScroll; settings-style sections with ui.group and ui.separator.
- Save every change at once with store (or fs for documents); implement autosave and unsaved if there is a document.
- If it uses the network: check sys.online() first, show a spinner while loading and a friendly error message.
- A menu (app.menu / app.onmenu) with the main actions and keyboard shortcuts.
- Every visible text through TR() with lang/en.json and lang/tr.json (de, fr, es if you can).
- Keep app.draw cheap: no file reads, image loads or big allocations per frame.

Deliver every file in full, then how to check it on a PC and run it on the console, and any assumption you made.
```
