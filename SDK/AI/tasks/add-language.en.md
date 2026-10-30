# Task: add a user-interface language to an app

**English** · [Türkçe](add-language.tr.md)

Nexvyn OS apps read their texts from `lang/<code>.json` through `TR("key", ...)`; the system's languages include
English (`en`), Turkish (`tr`), German (`de`), French (`fr`) and Spanish (`es`). `TR` falls back to English, then
to system strings, then to the key. Send the prompt with `lang/en.json` (and `lang/tr.json` for context) pasted
below it. No SDK context pack is needed for this task.

```text
Translate this Nexvyn OS app's lang/en.json into <language name> (code "<xx>") and return lang/<xx>.json.

Rules:
- Same keys, same order, valid JSON (UTF-8, no comments, no trailing commas).
- Keep placeholders exactly: {0}, {1}, ... may move inside the sentence but must all stay. Keep "\n" line breaks.
- Keep the length close to the English text: these strings sit on buttons and in narrow panels of a 1280x720 screen.
  If a translation must be much longer, give a shorter wording.
- Keep app names, brand names, units and keyboard keys (Ctrl+R, A, B, ZL) as they are unless the language has a
  standard form.
- Use the tone of a modern console/desktop UI: short imperative labels ("Save", "Delete"), sentence case.
- Keys that start with "game." override the nexvyn.game engine texts; translate them too.

Also give the "name" and "description" texts for app.json in that language, and, if I paste store.json, its
"subtitle" and "description" in that language.
```

Afterwards: put the file into `lang/`, add the language to `app.json` `name` / `description` and to `store.json`,
and run the checker of the app's language (it validates every lang file it reads).
