# Making themes

**English** · [Türkçe](THEMES.tr.md)

A theme pack (`.nxvtheme`) changes the whole desktop: colors and accent, wallpapers, window chrome, desktop layout
(dock or taskbar), the icon set, and the system sounds. It holds no code, only `theme.json`, pictures and sounds.
The byte-level rules of the package are in [NXVAPP_FORMAT.en.md](NXVAPP_FORMAT.en.md) section 9; this guide is the
how-to. A ready folder to copy is in `SDK/Samples/themes/template/`; the checker and packer is
`SDK/Tools/theme/themecheck.py`.

## 1. Folder

```
MyTheme/                  (zipped as MyTheme.nxvtheme; theme.json at the zip root or in one top-level folder)
├── theme.json            required
├── wallpaper.jpg         required, 1280x720 JPG / PNG / WebP
├── wallpaper2.jpg ...    optional extra choices
├── wallpaper-dark.jpg    optional, shown while the dark appearance is on
├── icons/<app id>.png    optional, 128 px; an app without a file keeps its own icon (up to 160 files)
├── sounds/*.wav          optional: startup click notify error pop key
├── preview.jpg           optional, 480x270 picture of the finished desktop (cards, installer)
└── README.md
```

Limits: at most 160 files, 32 MB in total, 12 MB per file; only the extensions `.json .jpg .jpeg .png .webp .wav .md
.txt`; an absolute path, or one with `..`, `:` or `\`, makes the whole package be refused. The limits are checked
before anything is extracted.

## 2. theme.json

```json
{
  "id": "com.yourname.theme.harbor",
  "name": {"en": "Harbor", "tr": "Liman"},
  "subtitle": {"en": "Calm blue-grey desktop with a bottom taskbar"},
  "description": {"en": "A quiet desktop in cool blues."},
  "version": "1.0",
  "author": "Your Name",
  "full": true,
  "appearance": "dark",
  "accent": "#3C8DBC",
  "wallpaper": "wallpaper.jpg",
  "wallpapers": ["wallpaper.jpg", "wallpaper2.jpg"],
  "sounds": "sounds",
  "icons": "icons",
  "preview": "preview.jpg",
  "settings": {"shell.layout": "taskbar", "taskbar.size": "medium", "start.sidePanel": true, "window.chrome": "flat"},
  "palette": {"windowBg": "1B2430", "text": "ECF1F6", "selection": "3C8DBC", "selectionText": "FFFFFF"}
}
```

| Field | Meaning |
|---|---|
| `id` | Reverse domain with at least one dot (`com.you.theme.name`). Updates are matched by it; the Store entry uses the same id. |
| `name`, `description`, `subtitle` | A string or a language map (`en` is the fallback; Store texts in 8 languages are recommended). |
| `version`, `author` | Dotted version (compared for Update / Reinstall) and your name. |
| `full` | `true`: the pack owns layout and bar settings too. Applying it resets them first, so switching packs leaves nothing behind. Use it for packs that set `shell.layout`. |
| `appearance` | `light`, `dark` or `auto`. Without it the user's own choice stays. |
| `accent` | `#RRGGBB`. One of the eight system colors maps to its index; anything else is a custom color. |
| `wallpaper`, `wallpapers`, `wallpaperDark` | The required first wallpaper, extra choices (the first is `wallpaper`; picked in Settings > Appearance > Customize) and the dark-mode picture. |
| `sounds`, `icons`, `preview` | Folder names and the preview file inside the pack. |

### Settings keys

Only these keys are read. Others are ignored and numbers are clamped.

| Key | Values |
|---|---|
| `shell.layout` | `dock` (dock and menu bar) or `taskbar` (bottom bar with a start menu) |
| `taskbar.size` | `small`, `medium`, `large` |
| `start.sidePanel` | `true` or `false` (taskbar layout) |
| `window.chrome` | `default`, `bevel`, `flat`, `glass`, `mono` (window frame and buttons) |
| `appearance.themeBold` | `true` or `false` (bold system text) |
| `appearance.themeScale` | 0.85 to 1.2 (interface scale) |
| `appearance.reduceTransparency` | `true` or `false` |
| `appearance.darkFrom`, `appearance.darkTo` | 0 to 23, the dark hours of `auto` |
| `dock.size` | 40 to 80 |
| `dock.magnify`, `dock.magnification` | `true` or `false`; 1.0 to 2.0 |
| `desktop.iconSize` | 0 small, 1 medium, 2 large |
| `screensaver.style` | 0 shapes, 1 star voyage, 2 clock |

### Palette

`palette` overrides single colors as `RRGGBB` or `RRGGBBAA`. Unknown names are ignored. Names: `windowBg titlebar
titlebarInactive contentBg sidebarBg text text2 text3 controlBg controlBorder controlHover fieldBg fieldBorder
selection selectionText menuBg menuText panelTint menubarTint menubarText separator accentText`. Set as few as you
need; the rest follows the appearance and the accent.

### Icon set

`icons/<app id>.png`: 128 px PNG files named by the app's id (`appstore.png`, `aichat.png`, ...). Restyle only the
icons you want to change; the others keep the system look. Make them with your own artwork and tools (pixelate,
bevel, flatten, duotone, frames). Never trace or edit another product's icons.

### Sounds

`sounds/` may hold `startup`, `click`, `notify`, `error`, `pop` and `key` as `.wav` files. A missing one plays the
system sound. Keep each file short (under 2 seconds, the startup sound under 4) and not louder than the defaults.

## 3. Rules

1. **Original assets only.** Wallpapers, icons and sounds are made by you (drawn, rendered, synthesized) or are CC0.
   Do not copy another system's wallpapers, icons, logos, startup sounds or window art. A look can be inspired by an
   era or a mood ("90s beige", "glassy 2000s"), but every file is your own work.
2. **No brand names.** Do not use another product's name, logo or slogan in the id, name, texts or pictures. Use
   generic names ("Classic", "Glass", "Terminal Blue").
3. **Readable colors (WCAG AA).** Text needs a contrast ratio of at least 4.5:1 against its background (3:1 for
   large text and icons). This applies to `text` on `windowBg`, `contentBg` and `sidebarBg`, `menuText` on `menuBg`,
   `selectionText` on `selection`, and `accentText` on the surfaces where it appears. `themecheck.py` measures it.
4. **Wallpapers must not hide the interface.** Desktop icon labels stay readable on the busy areas.
5. **No personal data** and no pictures or text you do not have the rights to.
6. A pack must work with apps it does not know: leave everything you do not set to the defaults.

## 4. Test

1. `python SDK/Tools/theme/themecheck.py MyTheme` lists errors and warnings (format, limits, contrast).
2. `python SDK/Tools/theme/themecheck.py MyTheme --pack` writes `MyTheme.nxvtheme` next to the folder.
3. Copy the `.nxvtheme` to the console's SD card, open it in Files and choose **Install and Apply**.
4. In *System Settings > Appearance > Themes* the card must look right, and **Undo** and **Restore Defaults** must
   work. Open a few apps in light and dark appearance, a text field, a menu, the start menu or dock, and play the
   sounds.
5. If the look ever breaks the desktop, hold L + R + ZL + ZR while Nexvyn OS starts: the default look returns.

## 5. Publish to the Store

Themes go to the App Market like apps: a pull request that adds `Store/Themes/<slug>/` (see
[Publishing](../Publishing/PUBLISHING.en.md)).

```
Store/Themes/<slug>/
├── source/               the pack folder above (theme.json, wallpaper, icons/, sounds/, preview.jpg)
├── store.json            {"subtitle": {...}, "description": {...}}  (8 languages recommended: en tr de fr es ja zh ko)
├── icon.png              256x256 card icon (a rounded crop of the desktop works well)
├── preview.wav           optional short sound sample: the Store field "audio" is filled from it and drives the
│                         "Preview sounds" button
└── screenshots/          5 screenshots recommended (3 at least), English interface
```

Screenshots: five, from the best angles (the desktop, a window, the start menu or dock, the icon set, one more), taken
with the system language set to English. No signing step is needed for a pull request: the maintainers build the
package, its SHA-256 and the catalog entry (`Tools/build_store.py`). A theme with copied assets or brand names is
rejected.

## 6. Many looks

`Store/Themes/*/source` holds the shipped packs; open one as a working example. A whole set of packs can be made by
script (procedural wallpapers, per-theme icon transforms, synthesized sounds, fixed seeds), so the result is
reproducible and every asset is yours.
