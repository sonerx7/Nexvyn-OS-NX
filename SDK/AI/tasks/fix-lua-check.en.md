# Task: fix a lua_check failure (or any checker failure)

**English** · [Türkçe](fix-lua-check.tr.md)

Send after `system-prompt.en.md` + the language pack. Paste the checker's full output and the files it names.

```text
The Nexvyn OS checker reports the problems below for my app. Fix them without changing what the app does.

Checker output:
<paste the whole output of python tools/lua_check.py ... (or js_check / py_check / rt_check / nxv check)>

Files:
<paste app.json, the files named in the output and lang/en.json + lang/tr.json>

How to read the output:
- "lang/en.json missing: <key>" / "TR(...) missing": add the key to lang/en.json AND lang/tr.json (and the other lang
  files), or fix a typo in the TR() call. The checker also scans comments: a TR("...") example in a comment counts.
- "unknown icon names (not in Icons.codepoints, nothing is drawn)": use a name from Material Icons Round
  (e.g. "settings", "delete", "add").
- "expected number for argument N": a gfx call got nil or a string; find which variable is nil on that frame.
- A Lua traceback ("main.lua:123: attempt to index a nil value"): the mock SDK ran your callbacks with random clicks,
  keys, pad presses, menus and lifecycle callbacks (suspend, resume, focus, autosave, unsaved, close). Make the code
  safe for every order of those calls (e.g. draw before data is loaded, onmenu with every id, close at any time).
- "uses net.* but app.json permissions has no network": add "network" to "permissions".
- "does not compile" (C) or "Java sources do not compile": fix the reported line; for Java, the API may not exist in
  miniJVM's class library.
- "app.jar missing" / "is not in app.jar": rebuild with python tools/java_build.py app <bundle>.

Return each changed file in full and one line per problem saying what caused it.
```

Then run the checker again. If the same error comes back, send the new output; do not ask the assistant to "just
skip" the check.
