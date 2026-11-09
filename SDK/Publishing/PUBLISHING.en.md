# Publishing in the App Market

**English** · [Türkçe](PUBLISHING.tr.md)

The Nexvyn OS App Market is fed from this repository. Every item is a folder under `Store/`; `Tools/build_store.py`
builds the packages and `Store/catalog.json`, and the App Market on the console reads that catalog from
`https://raw.githubusercontent.com/sonerx7/Nexvyn-OS-NX/main/Store/catalog.json`.

**Publishing = a pull request that the maintainer approves.** Nothing reaches the App Market without that review:
every new item and every update is checked by hand against the [review checklist](REVIEW.en.md) before it is merged.

## The flow at a glance

```
fork  →  add Store/<Apps|Games|Themes|Fonts>/<category>/<slug>/  →  run the checks  →  pull request (template)
      →  automatic checks  →  review by the maintainer (sonerx7)  →  merge = published  →  "New" in the App Market
```

1. **Fork** `sonerx7/Nexvyn-OS-NX` on GitHub, clone your fork and create a branch `app/<slug>`.
2. **Add your item** in its folder (section 1). Only your folder: the package, the catalog and the listings are
   generated.
3. **Run the checks** (section 7): `nxv check`, the language checker, `Tools/build_store.py --check`.
4. **Open a pull request** to `main`. GitHub fills in the [pull request template](../../.github/PULL_REQUEST_TEMPLATE.md):
   what it is, why each permission is needed, which checks you ran, where you tested it.
5. **Automatic checks** run on the pull request (catalog, packages, `catalog_check.py`, the Lua / JavaScript / Python
   checkers). Fix what they report; push to the same branch and they run again.
6. **Review.** The maintainer (`sonerx7`, see [CODEOWNERS](../../.github/CODEOWNERS)) installs and tries the item,
   goes through the [review checklist](REVIEW.en.md) and either approves it, asks for changes or closes the pull
   request with the reason. A first review usually takes a few days.
7. **Merge = published.** The maintainer runs `build_store.py` and merges. The App Market fetches the catalog when it
   opens and every 6 hours, so the item shows up on every console within hours, with a **New** badge for 14 days.

## 1. Folder layout

```
Store/
├── Apps/<category>/<slug>/     apps: productivity, utilities, media, internet, developer, system, switch, other
├── Games/<genre>/<slug>/       games: action, arcade, board, cards, casual, puzzle, racing, sports, strategy, word
│   ├── source/                 the bundle: app.json, main.*, icon.png, lang/*.json, other files
│   ├── store.json              store texts, kind, tags, screenshot script
│   ├── README.md               a description for people browsing GitHub (English; more languages optional)
│   ├── screenshots/1.png ...   5 screenshots recommended, 3 at least (a maintainer can make them, section 6)
│   ├── icon.png                copied from source/icon.png by build_store.py
│   └── <slug>.nxvapp           written by build_store.py, do not add it by hand
├── Themes/<slug>/              source/ (theme.json, wallpaper [, sounds/]), store.json, icon.png → <slug>.nxvtheme
└── Fonts/<slug>/               font files, LICENSE, font.json, store.json, icon.png, screenshots/ → <slug>.nxvfont
```

`<slug>` is lower-case letters, digits and `-` (`water-tracker`). To start an app folder:
`python SDK/Tools/nxv/nxv.py new lua "Water Tracker" --store --dir Store/Apps/productivity`.

- **Themes** follow the theme format (`.nxvtheme`, section 9 of the [package format](../Guides/NXVAPP_FORMAT.en.md));
  `Store/Themes/tools/gen_themes.py` shows how the official themes are made.
- **Font packs** follow section 10 of the [package format](../Guides/NXVAPP_FORMAT.en.md): `font.json`
  (`id`, `name`, `family`, `version`, `license`, `styles`, `scripts`, `languages`), the `.ttf` / `.otf` files and the
  license text. Only fonts whose license allows redistribution (SIL OFL, Apache 2.0, ...).
- Apps that ship inside Nexvyn OS have store pages too: a folder with `app.json` and no `source/`. Those are
  maintained by the Nexvyn OS project only.

## 2. app.json

| Field | Rule |
|---|---|
| `id` | Unique, reverse domain: `com.yourname.app` (letters, digits, `.`, `-`, `_`; at most 128). Updates match it: **never change it**. |
| `name`, `description` | `{"en": ..., "de": ...}` tables: English required, any other language optional. `description` is one short sentence; the long text goes into `store.json`. |
| `version` | `"1.0"`, `"1.2.3"`: dotted numbers (`1.10` > `1.9`). Raise it with every update. |
| `author`, `homepage` | Shown in the About window and in the App Market. |
| `category` | `productivity`, `utilities`, `media`, `internet`, `developer`, `system`, `switch`, `other`, `games`. |
| `runtime`, `main`, `mainClass` | The language (see [Languages](../Languages/README.md)). |
| `minSdk` | The SDK version of the newest feature you use. |
| `window`, `gamepad` | Games: `"gamepad": true`, `"resizable": true`. |
| `permissions` | Below. `[]` when nothing is needed. |
| `license` | Optional SPDX id of your code (`MIT`, `GPL-3.0-or-later` ...); shown on the store page. |

## 3. Permissions (enforced)

Every permission is **enforced** for apps installed from the SD card: one that is not in `app.json` is never granted
and the call fails. `build_store.py` stops when the code makes a call that needs a permission the manifest does not
declare.

| Permission | Needed for |
|---|---|
| `network` | `net.*` (JS `net.fetch`, C `net_*`, Java `Net.*`) |
| `files` | paths outside the app's own folders |
| `launch` | `sys.launch(otherId)`, `sys.open("nxv://...")` |
| `notifications` | `sys.notify`, `sys.schedule` |
| `games` | `sys.games` (SDK 1.6) |

Ask only for what you use and say why in the pull request: users confirm the permissions on install, and the review
rejects unexplained ones. Files picked with `ui.openFile` / `ui.saveFile` need no permission. C and Java apps are not
sandboxed, so users are asked once more.

## 4. Icon and README

- `source/icon.png`: 256×256 PNG. For games and apps made with the SDK the icon is **key art of the item itself**:
  it shows the game or app itself (its hero, main object or world), readable at 64 px, filled edge to edge with the
  subject inside the central 80 %. The style is the maker's choice (calm or flashy, with or without the name). A flat
  placeholder glyph on a gradient is not accepted (`nxv icon` makes those only while you work). Make it from your own
  model with the icon tool `Tools/icon` (Blender + Pillow, styles clean / bold / loud, examples in
  `Tools/icon/examples/`) or with the image-generator prompt in `AI/tasks/store-icon.en.md`; the recipe is in
  `Guides/MAKE_A_GAME.en.md` (*Store icon and key art*).
- `README.md`: a `# Name` title, a few sentences in English (more languages optional), an id / language / SDK /
  permissions table, controls, a versions table and the licenses of anything you did not make yourself.

## 5. store.json

```json
{
  "kind": "app",
  "features": ["offline", "touch", "controller"],
  "tags": ["water", "health", "reminders"],
  "subtitle": {"en": "Drink enough every day", "de": "..."},
  "description": {"en": "Two or three sentences.\n\n• Bullet\n• Bullet", "de": "..."},
  "age": "everyone",
  "shots": [["wait 3"], ["wclick 0.5 0.3", "wait 1.5"], ["key right", "wait 1"], ["dark 1", "wait 1.5"]]
}
```

- `subtitle` (at most 45 characters) and `description`: **English is required**; add any other language you
  like (Turkish, German, French, Spanish, Japanese, Chinese, Korean). Missing languages fall back to English.
- `kind`: `app`, `game`, `demo`, `port`, `emulator` or `template`. `tags`: lower-case search words. `featured` is set by the maintainer.
- Store metadata (all optional; the App Market uses it for its tabs, sorting and filters, and an older App Market ignores it):
  `features` is a list of `3d`, `online`, `multiplayer`, `coop`, `offline`, `touch`, `controller`, `keyboard`;
  `players` is `"2"` or `"1-4"` (games that list `multiplayer` or `coop` should set it); `tech` is `lua`, `javascript`,
  `python` or `native`; `themeStyle` (themes) is `retro`, `modern`, `phone`, `dark`, `light`, `nature` or `minimal`.
  `Tools/build_store.py` derives what it can (tech from the runtime, `3d` when the code calls `g3d.*`, `online` when it
  uses `net.*`, otherwise `offline`, input from the input calls); a value you write always wins, and a game that lists
  no `features` gets a warning. `python tools/catalog_check.py --strict` rejects unknown values. Games are filtered by
  these in the store (online, local multiplayer, single player, co-op), so state them truthfully.
- `age`: a content note. `everyone` (default) or `teen` (mild violence, scary themes, user-generated web content).
  Content for adults only is not accepted.
- `shots`: 3-5 shots, 5 recommended; each is a list of steps that run before that picture (`wait <s>`,
  `wclick <fx> <fy>`, `wmove <fx> <fy>`, `key <name>`, `hold <key> <s>`, `dpad <dir>`, `text <string>`, `dark 0|1`).

## 6. Screenshots

`screenshots/1.png` ... are cropped to the app's window, with the interface in English. **Recommended: five
screenshots** from the best moments: the first screen, the main feature in use, a busy or exciting moment, a second
feature or level, and dark mode (games: the best moments of play, not menus). Take them yourself (on the console or
in an emulator), or give a `shots` script and the maintainer runs `python tools/store_shots.py --only <slug>` in the
Nexvyn OS source repository. Without a script the system takes five on its own: a game is started and played for a
few seconds with the D-pad, A and the arrow keys, an app is clicked and scrolled, the last one in dark mode. Your own
screenshots are never replaced by automatic ones. Show no personal data, real names or API keys.

## 7. Checks

```
python SDK/Tools/nxv/nxv.py check Store/Apps/productivity/water --sdk <source checkout>   # manifest, permissions, translations, store.json + the language checker
python Tools/build_store.py            # packages, catalog and listings (optional for you; the maintainer runs it)
python Tools/build_store.py --check    # is everything up to date (CI runs this)
```

The language checkers are in the source repository: `tools/lua_check.py`, `tools/js_check.mjs`, `tools/py_check.py`,
`tools/rt_check.py` (Squirrel, C, Java), and `tools/catalog_check.py` for the catalog. For Java, rebuild `app.jar`
(`nxv build`).

## 8. Content and quality rules

The full list is the [review checklist](REVIEW.en.md). In short, an item is **not accepted** when it:

- does not work, crashes, or is a copy of an existing item with a new name;
- contains malware, hides what it does, downloads and runs code that was not reviewed, or touches system files;
- tracks users, collects personal data, API keys or passwords, or uploads anything without telling the user;
- shows ads that harm the experience (full-screen, deceptive, or for scams, gambling or adult content);
- needs a permission it does not explain;
- uses code, art, music, fonts or trademarks you do not have the rights to: **you must own the item or have a license
  that allows publishing it**, and third-party parts are listed with their licenses in the README (like the YamaNX
  notes for Turkish patches: who made it, where it comes from, under which license);
- is adult-only, hateful, or encourages illegal activity, including piracy;
- has no English text;
- is a game that copies a sample's or another game's menu layout and title, or has a flat placeholder glyph
  icon instead of a picture of the game, or clearly misses the quality bar (no sound or visual feedback on actions, raw unfiltered
  beeps, default text as the title, flat single-colour screens; see the review checklist and
  `Guides/GAME_FEEL.en.md`).

Recommended before you submit (not a rule): the app or game works with touch only and with a controller only, in handheld
and docked mode, in a window and full screen, with moderate sound that pauses on focus loss and sleep. The checklist is
`Guides/INPUT_AND_PLAY_MODES.en.md`.

## 9. Updates

An update is a pull request too: the same `id`, a higher `version`, a line in the README's versions table and,
ideally, a `changelog` in `store.json` (`{"en": "What changed"}`, shown as "What's New"). It is reviewed like a new
item. The App Market shows **Update** when the catalog version is higher than the installed one; the install happens in
place and the app's data is kept. An update that adds a permission asks the user about the new one only. Raise
`minSdk` when you use a newer SDK feature. `Tools/build_store.py` records every published version with its date
(`Store/dates.json`), and the store page shows that version history.

## 10. Reports and takedowns

- Anyone can report an item with **Report This App** on its store page or the
  [report form](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=report-app.yml).
- The maintainer looks at every report. An item that breaks the rules is removed from the catalog (or the faulty
  version is replaced by the previous one); for malware or a legal problem at once, otherwise after the developer had a
  chance to fix it (usually 14 days).
- Developers can take their own item down any time with a pull request that deletes the folder, or by asking in an
  issue.
- A rights holder who believes an item infringes their rights can open a report with the details; the item is hidden
  while it is looked at.

## 11. Signing (optional)

The App Market compares every download with the catalog's `sha256`, and store packages are rebuilt from source by
`build_store.py`, so they need no signature. If you also distribute the package yourself (a website, your own
catalog), sign it with your nxvapp key from the source repository:

```
python tools/nxvapp_keygen.py mykey.pem                              # once; keep the key secret and backed up
python tools/nxvapp_pack.py MyApp.nxvapp --sign mykey.pem            # manifest.sha256 + manifest.sig
python tools/nxvapp_pack.py --verify MyApp.nxvapp                    # the check Nexvyn OS makes
```

(or `python SDK/Tools/nxv/nxv.py pack <folder> --sign mykey.pem --sdk <source checkout>`). The install sheet shows
"Signed by AB12:CD34:EF56:7890" and warns when a later update is signed with another key: sign every update with the
same key. When your key's fingerprint is in the catalog entry (`signer`, ask in the pull request), the App Market only
installs packages signed with it.

## See also

- [Review checklist](REVIEW.en.md): what the maintainer checks before approving
- [Pull request template](../../.github/PULL_REQUEST_TEMPLATE.md)
- [Package format](../Guides/NXVAPP_FORMAT.en.md) · [Developer guide](../Guides/DEVELOPER_GUIDE.en.md) ·
  [SDK reference](../Reference/SDK.en.md)
