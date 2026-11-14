# Task: make a theme pack

Send after the context pack (`system-prompt.md`) and give the assistant `SDK/Guides/THEMES.md`.

```text
Write a complete Nexvyn OS theme pack (.nxvtheme).

Style: <the look in a few words, e.g. "calm blue taskbar desktop, glassy panels", "warm paper, serif feel", "green phosphor terminal">
Id: com.<yourname>.theme.<name>   Name: <a generic name>   Author: <name>
Appearance: <light | dark | auto>   Layout: <dock | taskbar>   Window chrome: <default | bevel | flat | glass | mono>
Extras: <more wallpapers, a dark wallpaper, an icon set, system sounds: which of them>

Requirements:
- Use only the fields and settings keys of SDK/Guides/THEMES.md. Do not invent keys.
- Everything is original: write a script (Python with Pillow and numpy, and the standard wave module for sounds) that draws
  the wallpapers (1280x720 JPG), restyles or draws the icons (128 px PNG named by the app id, only the ones you change) and
  synthesizes short sounds (startup, click, notify, error, pop, key; each under 2 s, startup under 4 s). Fixed random seeds.
- Do NOT copy, trace or imitate any existing product's logos, icons, wallpapers, window art, startup sounds or names.
  Take inspiration from an era or a mood only. Use a generic name and no brand words in the id, texts or file names.
- Choose colors with readable contrast: every text/background pair you set in "palette" is at least 4.5:1 (WCAG AA)
  (text on windowBg, contentBg and sidebarBg, menuText on menuBg, selectionText on selection). Say the ratios you measured.
- Set "full": true when the pack sets shell.layout or taskbar settings. Give name, subtitle and description in en and tr
  (more languages if asked).
- Keep the pack under the limits: 160 files, 32 MB, 12 MB per file, allowed extensions only.

Deliver: theme.json in full, the generator script in full, the folder layout, then the commands to check and pack it
(python SDK/Tools/theme/themecheck.py <folder> --pack) and to try it (open the .nxvtheme in Files, Install and Apply,
check light and dark appearance, Undo and Restore Defaults), and any assumption you made.
```

For the Store, also ask for `store.json` (8 languages), a 256x256 `icon.png` and a preview sound, and take five English-interface screenshots (see `SDK/Guides/THEMES.md` section 5).
