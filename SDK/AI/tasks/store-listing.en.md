# Task: write store.json and the screenshot script

**English** · [Türkçe](store-listing.tr.md)

Send after `system-prompt.en.md` (section 10 describes `store.json`). Paste `app.json`, the main source file(s) and
`lang/en.json` below the prompt so the assistant knows what the app really does and where its buttons are.

```text
Write store.json for this Nexvyn OS app for the App Market.

{
  "kind": "app | game | demo | port | emulator | template",
  "features": ["3d | online | multiplayer | coop | offline | touch | controller | keyboard, only what the code really does"],
  "players": "2 or 1-4 (only when features has multiplayer or coop)",
  "tags": ["3-6 lower-case search words"],
  "subtitle": {"en": "...", "<other language code>": "..."},
  "description": {"en": "...", "<other language code>": "..."},
  "shots": [[...], [...], [...]]
}

Rules:
- subtitle: at most 45 characters, says the benefit, no app name, no ending period.
- description: one paragraph of 2-3 sentences on what the user can do, then "\n\n" and 4-6 bullets ("• ..."),
  each one real feature found in the code. No claims that are not in the code. No superlatives.
- English is required. Add exactly the other languages the app's lang/ folder has (<list them>), natural wording
  (not word-for-word), the same facts in each.
- shots: 3 or 4 shots; each shot is a list of steps run before that screenshot, and the state carries over to the
  next shot. Allowed steps only:
    wait <seconds>          e.g. "wait 1.5"
    wclick <fx> <fy>        click at a fraction 0..1 of the app window's content, e.g. "wclick 0.5 0.3"
    wmove <fx> <fy>         move the pointer there
    key <name>              enter, space, escape, tab, left, right, up, down, a..z, 0..9, pageup, pagedown...
    dpad <direction>        up, down, left, right
    text <string>           types text into the focused field
    dark 0 | dark 1         light or dark mode
  Compute fx/fy from the coordinates in the code (x / window width, y / window height of app.json "window").
  Start with "wait 3" so the app has loaded. Show the most important screens with realistic, non-personal data.
  End with a "dark 1" shot.

Also write README.md for the item folder: "# <name>", two or three sentences in English (more languages if I ask),
a table (Id, Language, Min SDK, Permissions, Gamepad, Window), a "What it teaches"/features list and a versions table.
```

Check the result with `python SDK/Tools/nxv/nxv.py check <item folder>`: it checks that English is there, `kind`, `tags`
and every `shots` step.
