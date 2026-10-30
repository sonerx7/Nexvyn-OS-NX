# The .nxvapp package format (v2)

[Türkçe](NXVAPP_FORMAT.tr.md) · **English**

> **Summary.** A `.nxvapp` v2 package is a zip file with `app.json` at its root (a single top-level folder
> holding `app.json` is accepted too). An optional `manifest.sha256` lists the SHA-256 of every other file
> (`sha256sum` format); Nexvyn OS shows *Intact* when every file matches and nothing is unlisted, *Modified* when not,
> *Unsigned* when there is no manifest. An optional `manifest.sig` (SDK 1.4) is the developer's ECDSA P-256
> signature of `manifest.sha256`: the install sheet then shows *Signed by AB12:CD34:EF56:7890*, refuses a broken
> signature and warns when an update is signed with a different key than the installed version (trust on first use).
> `app.json` may declare `minSdk` (Nexvyn OS refuses apps that need a newer SDK; `sys.sdkVersion()` reports the
> current one), `permissions` (`network`, `files`, `launch`, `notifications` and `games` are enforced for apps installed
> on the SD card; one decision per app at install time, `sys.requestPermission` is the only runtime prompt) and `shareTargets` (what
> `sys.share` may hand the app). Packages over 20000 files or 1 GiB unpacked are refused. Opening a package in
> Files shows an install sheet with **Run** (unpacked into `Library/Caches/nxvinstall/<id>`, nothing installed) and
> **Install** (atomic install into `sdmc:/NexvynOS/Applications`; same id = update in place, app data kept).
> The App Market lists a JSON repository index (URL in *System Settings > Apps*) and checks each download's
> `sha256` (and `signer`, when given). Pack a folder with `python tools/nxvapp_pack.py <folder> [-o out.nxvapp]
> [--sign key.pem] [--index]`; create a key with `tools/nxvapp_keygen.py`; check a package with `--verify`;
> validate a catalog with `tools/catalog_check.py`.
> Updatable system files: anything under `sdmc:/NexvynOS/System/Overlay/` replaces the romfs file with the same
> relative path (`Overlay/Languages/tr/shell.json`, `Overlay/Applications/notes.nxvapp/`).

This document is the complete description of the `.nxvapp` package, for developers and AI tools alike. The API itself
is in `sdk/SDK.en.md`.

## 1. Package

An app can be distributed in two forms:

- **Folder:** `Name.nxvapp/` (during development, Studio projects).
- **Single file (v2):** the zipped contents of the same folder, with the `.nxvapp` extension.

```
Name.nxvapp  (zip)
├── app.json            required, at the root of the zip
├── main.lua | main.js | main.py | main.nut | main.c | app.jar   entry file (the "main" field)
├── icon.png            128×128 or 256×256, transparent PNG
├── lang/tr.json        translations (optional)
├── lang/en.json
├── ...                 images, sounds, modules
├── manifest.sha256     file list and SHA-256 values (optional, recommended)
└── manifest.sig        developer signature (optional, SDK 1.4; section 4b)
```

Rules:

- `app.json` must be at the root. For older packages, being inside a single top-level folder is accepted too
  (`Name/app.json`).
- Hidden files (whose name starts with `.`: `.git`, `.DS_Store`) are not put in the package; the packer skips them.
- Paths that contain `..`, are absolute, or contain `:` or `\` are ignored when extracting (zip-slip protection).
- At most 20000 files and 1 GiB unpacked: larger packages are refused before anything is extracted (zip-bomb
  protection).
- `"native": true` is only for the C++ apps that ship with the system. A C++ app package carries a compiled native
  module: `"native": "<id>.nxvmod"` and `"abi"` (section 2, `docs/NATIVE_MODULES.en.md`). This is an internal mechanism for
  Nexvyn OS's own apps only; third-party apps are written in Lua, JavaScript or Python.

## 2. app.json

| Field | Type | Description |
|------|-----|----------|
| `id` | string, required | Unique id in reverse-domain form: `com.adiniz.uygulama`. Letters, digits, `.`, `-`, `_`; at most 128 characters. Updates are matched by this id. |
| `name` | string or `{"en","tr",...}` | Display name. |
| `description` | string or language table | Short description (on the install sheet and in the Store). |
| `version` | string | Like `"1.4.2"`; compared as dotted numbers (`1.10` > `1.9`). |
| `author` | string | Developer name. |
| `category` | string | `system`, `productivity`, `utilities`, `media`, `internet`, `games`, `developer`, `other`. |
| `icon` | string | Default `icon.png`. |
| `main` | string | Entry file; without it, the runtime's default (table below). Its extension also selects the runtime. |
| `runtime` | `"lua"`, `"js"`, `"python"`, `"squirrel"`, `"c"`, `"java"` | Selects the runtime explicitly (takes precedence over the extension). |
| `mainClass` | string | Java only: the class that extends `nexvyn.App` (`"hello.HelloApp"`); without it, `Main-Class` from the jar's manifest. |
| `window` | object | `width`, `height`, `minWidth`, `minHeight`, `resizable`. |
| `singleInstance`, `gamepad`, `dpadArrows`, `hidden` | boolean | See `sdk/SDK.en.md`. |
| `fileTypes` | string array | Extensions it can open (`[".txt"]`). |
| `minSdk` | string | The minimum SDK version required (`"1.2"`). Without it, the app runs on every version. |
| `permissions` | string array | Requested permissions (section 3). Without it, the package counts as an old package. |
| `native` | string | C++ apps only: the native module file in the package (`"news.nxvmod"`); replaces `main`. Produced by `tools/build_modules.py`. |
| `abi` | string | C++ apps only: the ABI id of the Nexvyn OS build the module was compiled against (16 hex characters). Not installed if it differs. |
| `shareTargets` | string array | What it can receive through `sys.share` (SDK 1.4): `"text"`, `"url"`, `"file"`, `"image"` or an extension (`".txt"`). The shared item arrives through `app.load(arg)` / `app.open(arg)`. |

Runtimes (`runtimes/runtime_kind.h`):

| `runtime` | Extension | Default `main` | Language | Minimum SDK |
|---|---|---|---|---|
| `"lua"` (default) | `.lua` | `main.lua` | Lua 5.4 | 1.0 |
| `"js"` | `.js`, `.mjs` | `main.js` | JavaScript (QuickJS-ng) | 1.1 |
| `"python"` | `.py` | `main.py` | Python (pocketpy 2) | 1.3 |
| `"squirrel"` | `.nut` | `main.nut` | Squirrel 3.2 | 1.5 |
| `"c"` | `.c` | `main.c` | C, compiled on the console with TinyCC; every `.c` file in the package | 1.5 |
| `"java"` | `.jar` | `app.jar` | Java 8 class files (miniJVM); the jar is built on the PC with `tools/java_build.py` | 1.5 |
| `"native"` | `.nxvmod` | the `"native"` field | C++ native module, compiled with the same compiler as the NRO; runs only on a system with the same ABI (`docs/NATIVE_MODULES.en.md`) | ABI id instead of SDK |

Because `"c"`, `"java"` and `"native"` apps do not run sandboxed, those installed from the SD card ask the user once on
their first launch (`apps.trustedC`, `apps.trustedJava`, `apps.trustedNative`).

### SDK versions

The system carries the `NEXVYN_SDK_VERSION` value (`source/core/sdk_version.h`); apps read it with
`sys.sdkVersion()`. If `minSdk` is greater than this value:

- the registry does not list the app, and installation is refused;
- the install sheet and the Store say "This app requires a newer version of Nexvyn OS".

| SDK | Additions |
|-----|------------|
| 1.0 | Lua runtime: `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `TR`, `g3d` |
| 1.1 | JavaScript runtime (the same modules, Promises); `g3d` textures on the GPU |
| 1.2 | the `nexvyn.game` engine, `sys.sdkVersion()`, `minSdk`, `permissions`, single-file `.nxvapp` v2 and `manifest.sha256` |
| 1.3 | Python runtime (pocketpy) |
| 1.4 | all permissions enforced, `sys.share`, `sys.schedule`, `sys.hasPermission` / `requestPermission`, `sys.memory`, `sys.appUrl`, `nxv://` links, `app.search` and the lifecycle callbacks, `shareTargets`, `manifest.sig` |
| 1.5 | Squirrel (`"squirrel"`), C (`"c"`, TinyCC) and Java (`"java"`, miniJVM) runtimes, `mainClass`; Python system library (`itertools`, `string`, `textwrap`, `copy`, `statistics`, `base64`, `colorsys`) |

A minor version (1.x) only adds things; if something is removed or changes meaning, the major version goes up.

## 3. Permissions

| Permission | API covered | Without the permission |
|------|---------------|------------|
| `network` | `net.get/post/json/download/request`, JS `fetch` | the request returns with the error `"permission denied: network"` |
| `files` | Paths outside the app's own folders (bundle, `Application Support/<id>`, `Caches/<id>`) | the path becomes empty |
| `launch` | `sys.launch` (another app), `sys.open("nxv://...")` | `nil, "permission denied: launch"` (JS/Python: `false`) |
| `notifications` | `sys.notify`, `sys.schedule` (scheduled notifications are not posted either) | `nil, "permission denied: notifications"` |
| `games` | `sys.games` (SDK 1.6) | the call fails (`nil`; JS `null`, Python `None`) |

**Every permission is enforced** for apps installed on the SD card. `clipboard` is no longer a permission:
`sys.clipboard` and the user's own copy/paste in text fields need none.

How it works:

- Apps that ship with the system are not checked. Every app on the SD card (`sdmc:/NexvynOS/Applications`) is checked.
- **One decision per app, at install time.** The install sheet lists the requested permissions; **Install** allows
  them all, **Customize** lets the user turn single permissions off. The answer is stored in
  `sdmc:/NexvynOS/System/Config/permissions.json`. Only when there is no stored answer (for example a bundle copied
  into `Applications` by hand) is the user asked once, at first launch. Given answers are kept across updates.
- A permission that is **not** in `permissions` is never granted. Old packages without a `permissions` field are
  asked about all permissions on their first launch.
- `sys.hasPermission(name)` tells whether the permission is granted right now; `sys.requestPermission(name, fn)` asks
  again, once per session, for a declared permission the user refused; it is the only prompt at run time.
- A refused network request returns as an error on the next frame: `res.ok == false`,
  `res.error == "permission denied: network"`.
- A refused file path becomes an empty path: `fs.read` → `nil`, `fs.list` → empty, `fs.path("sdmc:/...")` → `""`,
  `net.download` fails.
- Files the user picked with `ui.openFile` / `ui.saveFile`, the file the app was opened with ("Open With") and files
  shared with the app can be used without the permission. `romfs:/` is readable. An argument that comes from shared
  **text** or an `nxv://` link, however, opens no file permission.
- **Protected folders.** Some folders stay closed to apps from the SD card even with `files`: Nexvyn OS's own data
  (`sdmc:/NexvynOS/System`, except the add-on folders `System/Library` and `System/Fonts`), other apps' bundles in
  `sdmc:/NexvynOS/Applications`, the user's `~/Library` outside the app's own `Application Support/<id>` and
  `Caches/<id>` (other apps' data: the Browser's cookies and passwords, the AI Chat, FTP and Tube keys, the words the
  keyboard learned) and every other user's `Library`. Another user's home opens only for a file the user picked.
  Paths are compared the way the SD card does (letter case, `..`, `\`), so another spelling does not get around it.
  The app's log says `protected path: <path>` once. Details: [APP_GUARD.en.md](APP_GUARD.en.md).
- Every refused permission is written once, with the reason, to the app's log:
  `sdmc:/NexvynOS/System/Logs/Apps/<id>.log` ("declare it in app.json" = not declared, "the user did not allow it" =
  refused by the user).
- The stored answers are deleted when the app is uninstalled.

## 4. Verification file (manifest.sha256)

Plain text in the same format as `sha256sum` output; every line has a 64-digit lowercase hex value, two spaces and the
path relative to the package (with `/`):

```
3f2a...9c1e  app.json
b81d...04aa  icon.png
77c0...1f3b  lang/tr.json
e4a9...5d20  main.lua
```

- `manifest.sha256` does not list itself. Hidden files are not listed and not put in the package.
- When opening the package, Nexvyn OS computes the value of every file:
  - all match and there is no unlisted file → **Verified**;
  - a value differs, a listed file is missing or there is an unlisted file → **Modified** (the install sheet shows
    which file);
  - no file → **Unsigned**.
- On its own this is an integrity check: someone who changes the package can regenerate the list too. To prove who
  made it, sign the list (section 4b); the Store also compares every download with its `sha256` value (section 6).
- `manifest.sha256` and `manifest.sig` are not in the list.

## 4b. Developer signature (manifest.sig, SDK 1.4)

`manifest.sig` is an ECDSA (NIST P-256, SHA-256) signature over the bytes of the `manifest.sha256` file:

```json
{"alg": "ECDSA-P256-SHA256",
 "key": "<base64 of the 65-byte uncompressed public key (04||X||Y)>",
 "sig": "<base64 of the DER signature>"}
```

- The **fingerprint** is the first 8 bytes of the SHA-256 of the public key: `AB12:CD34:EF56:7890`. The install sheet
  shows "Signed by: AB12:CD34:EF56:7890".
- If the signature does not verify, or files changed after signing, the package is marked **Invalid signature** and
  cannot be installed/run.
- **Trust on first use (TOFU):** when an app is installed signed, the key's fingerprint is written to
  `sdmc:/NexvynOS/System/Config/signers.json`. If a later update is signed with another key (or unsigned), the install
  sheet and the Store show a "Signed by a different developer" warning and ask for confirmation.
- Creating a key: `python tools/nxvapp_keygen.py anahtarim.pem` (prints the fingerprint; `--show` shows an existing
  key). OpenSSL keys work too (`openssl ecparam -name prime256v1 -genkey -noout -out k.pem`). Keep the key secret and
  back it up: updates must be signed with the same key.

## 5. Installing, updating, uninstalling

- **Opening in Files:** a `.nxvapp` file opens the install sheet: icon, name, author, version, size, runtime, required
  SDK, verification status and permissions.
  - **Run:** the package is extracted into `~/Library/Caches/nxvinstall/<id>` and run once; it is not added to
    the Launcher. (The package is extracted first because the Lua/JS runtimes do not read files directly from the zip.)
  - **Install / Update / Reinstall:** the package is installed into `sdmc:/NexvynOS/Applications`.
- **Atomic installation:** the package is first extracted to a hidden temporary folder (`Applications/.staging-<id>`)
  and checked; then the old copy is moved aside as `.old-<id>`, the new one is moved into place, and finally the old one
  is deleted. If a step fails, the old copy is put back.
- **Update:** a package installed with the same `id` is written into the installed copy's folder. The app's data
  (`~/Library/Application Support/<id>`) does not change at all.
- **Uninstalling:** right-click the icon in the Launcher → Uninstall, System Settings > Apps, or the Store. "Uninstall with
  data" also deletes the `Application Support/<id>` and `Caches/<id>` folders.
- A package that carries the same id as an app that ships with the system is installed side by side with the id
  `ext.<id>`.

## 6. Community repository (index.json)

The Store lists a JSON file whose address is in the "Community app repository" field of System Settings > Apps (when
empty, the default: `https://raw.githubusercontent.com/sonerx7/Nexvyn-OS-NX/main/Store/catalog.json`; while that
address returns 404, the older `AppStore/catalog.json` and `store/catalog.json` are tried in turn). If the file cannot be reached, the Store shows the
last copy or says "offline". The catalog is refreshed when the Store opens and in the background at most every 6
hours (while online).

```json
{
  "apps": [
    {
      "id": "com.ornek.notlar",
      "name": {"en": "Notes Plus", "tr": "Notlar Plus"},
      "description": {"en": "...", "tr": "..."},
      "version": "1.3",
      "author": "Örnek",
      "category": "productivity",
      "icon": "https://.../icon.png",
      "download": "https://.../NotlarPlus.nxvapp",
      "size": 48213,
      "sha256": "9b1c...e0",
      "minSdk": "1.2",
      "permissions": ["network"],
      "screenshots": ["https://.../1.png"],
      "featured": false,
      "added": "2026-09-20",
      "updated": "2026-10-01",
      "changelog": {"en": "Faster search.", "tr": "Daha hızlı arama."},
      "signer": "AB12:CD34:EF56:7890",
      "runtime": "lua",
      "tags": ["not", "metin"],
      "subtitle": {"en": "Notes with tags and search", "tr": "Etiketli, aranabilir notlar"}
    }
  ]
}
```

- `download` (the old name `url` is accepted too) is the address of the `.nxvapp` file.
- `sha256` is the value of the downloaded **package file**; on a mismatch nothing is installed.
- If `minSdk` is newer than the system, the app is listed but the "Get" button is disabled.
- If `version` is greater than the installed version, "Update" appears. Installation is the same as with the installer
  in Files.
- If `added` (`YYYY-MM-DD`, first release) is within the last 14 days, the entry gets a "New" badge and appears on the
  "New" shelf at the top of Discover; new entries the user has not seen yet are counted on the Discover tab and
  notified at most once a day (not while Do Not Disturb is on; an unread notification is a Dock badge). Entries
  (that are not new) `updated` in the last 14 days get an "Updated" badge.
- `updated` (`YYYY-MM-DD`, `added` when not given) is used in the "Newest" sort order and on the detail page,
  `changelog` in the "What's New" section, `tags` in search, and `runtime` (`lua`, `js`, `python`, `squirrel`, `c`,
  `java`) on the detail page.
- If `signer` is given, the downloaded package must be signed with this key; otherwise it is not installed.
- `subtitle` (at most 45 characters, language table) is shown as a single line under the name on cards, in lists and
  on the detail page; `name`, `subtitle` and `description` are shown in the interface language, or in English if
  missing.
- `"builtin": true`: an optional app that ships with the system (no `download`, `sha256`, `size`). "Get" adds it to
  the lists, "Remove" takes it out without touching its data; it is not updated separately. If the running system has
  no app with that id, the entry is hidden. For optional apps not in the catalog, the Store builds a local page from
  `app.json`.
- `"runtime": "native"` + `"abi"`: a C++ native module package. Only entries that match the running system's ABI are
  listed; if the installed module's ABI differs, "Update" appears.
- `"kind": "theme"` + `"category": "themes"`: a `.nxvtheme` theme package (`download` + `sha256` required, section 9).
  "Get" downloads it, checks the SHA-256 and installs it under `~/Library/Themes/<id>`; then "Apply" / "Remove". The
  entry's `id` must be the same as the theme's `theme.json` id. The sidebar always has a Themes category
  (`os::launch("appstore", "themes")` opens it).
- `"kind": "font"` + `"category": "fonts"`: a `.nxvfont` font pack (section 10) with its `styles` and `license`.
  "Get" installs it into `System/Fonts/User/<id>`; then "Installed" / "Remove". The sidebar always has a Fonts
  category (`os::launch("appstore", "fonts")`).
- `license` (SPDX id such as `MIT`, `OFL-1.1`), `source` (https link to the code) and `history` (every published
  version, `[{"version", "date"}]`, newest first) fill the detail page: the license, a "Source code" link and the
  version history. Every page also has "Report This App" (the report form of the release repository).
- Download counts and star ratings come from the Nexvyn OS store statistics service (`/NexvynOS/api/store` on the project server) (setting
  `store.statsUrl`): `GET /stats` → `{"updated", "apps": {id: {"downloads", "ratings", "rating"}}}`,
  `POST /download {"app","client"}` after the first install, `POST /rate {"app","client","stars"}` when rating.
  `client` is a random id generated once just for this (`store.clientId`, not the telemetry id). Sending can be turned
  off with `store.shareStats`; if the service cannot be reached, counts and stars are not shown.
- If the same `id` appears twice, only the first is used. The `games` category is shown first in the sidebar.
- Store links: `nxv://store/<id>` opens the app's page; `os::launch("appstore", "<id>")` does the same.
- Catalog check: `python tools/catalog_check.py Store/catalog.json` (schema, unique ids, https addresses, `sha256`,
  `minSdk`, `signer`, date format, `security.blocklist`; `--strict` also treats warnings as errors).

### security: App Guard's blocklist

```json
{
  "apps": [ ... ],
  "security": {
    "blocklist": [
      {"sha256": "5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8",
       "reason": "Sends saved passwords to a remote server"}
    ]
  }
}
```

- Optional. Each entry names a known-bad package by the SHA-256 of its `.nxvapp` file (the same kind of value as an
  app's `sha256`) and says why in `reason` (shown to the user as written).
- App Guard reads the list from the catalog the App Market cached last. A package whose hash is listed is
  **Dangerous** on the install sheets and in *System Settings > Privacy & Permissions > App Guard*; installed apps are
  matched by the hash of the package they were installed from.
- It only warns. Nexvyn OS never disables, removes or blocks an app because of this list: the user decides.
- `tools/catalog_check.py` checks the format (not 64 hex digits is an error; a missing `reason` or a repeated hash is
  a warning). The release repository's `Tools/build_store.py` can carry the list into `Store/catalog.json`.

## 7. Packaging

```
python tools/nxvapp_pack.py Uygulamam.nxvapp              # Uygulamam.nxvapp (zip) next to the folder
python tools/nxvapp_pack.py Uygulamam.nxvapp -o dist/x.nxvapp
python tools/nxvapp_pack.py Uygulamam.nxvapp --index      # also prints the repository entry (size, sha256, signer ...)
python tools/nxvapp_keygen.py anahtarim.pem                 # signing key (once)
python tools/nxvapp_pack.py Uygulamam.nxvapp --sign anahtarim.pem
python tools/nxvapp_pack.py --verify Uygulamam.nxvapp       # the check Nexvyn OS will do: list, values, signature
```

The packer checks `app.json` (id, name, entry file, `minSdk` format, unknown permissions and share targets, size
limits) and adds `manifest.sha256` (and `manifest.sig` with `--sign`). The **Export** command in Nexvyn OS Studio
produces the same format (`~/Documents/<name>.nxvapp`).

## 8. Updatable system folder (Overlay)

A file in `sdmc:/NexvynOS/System/Overlay/` is used instead of the file at the same relative path in `romfs`:

| Overlay path | Replaces |
|--------------|----------------|
| `Overlay/Languages/tr/shell.json` | `romfs:/System/Languages/tr/shell.json` |
| `Overlay/Wallpapers/x.jpg` | `romfs:/System/Wallpapers/x.jpg` |
| `Overlay/Applications/notes.nxvapp/` (with `app.json` inside) | `romfs:/Applications/notes.nxvapp/` (the whole bundle) |
| `Overlay/Applications/notes.nxvapp/lang/tr.json` (a single file) | only that file |

- File reads (`fsx::readFile`), images, fonts, sounds, language files and the app scan follow this rule.
- The existence of each path is checked once per session; if there is no Overlay folder, the cost is just a prefix
  comparison. Changes take full effect when Nexvyn OS restarts.
- The status is visible in System Settings > About. "Reset system updates" moves the folder aside as `Overlay.off`
  (it does not delete it).

## 9. Themes (.nxvtheme)

> **Summary.** A `.nxvtheme` is a zip with `theme.json` at its root (or in one top-level folder) plus the
> pictures it names and, optionally, UI sounds. `theme.json`: `id` (reverse-domain, must contain a dot), `name` and
> `description` (string or `{"en","tr","de","fr","es"}` map), `version`, `author`, `appearance` (`light` | `dark` |
> `auto`), `accent` (`#RRGGBB`), `wallpaper` (required, `.jpg`/`.png`/`.webp`, 1280×720), optional `wallpaperDark`
> (shown while the dark appearance is on), optional `sounds` (a folder of `<name>.wav` files replacing the system
> sounds) and optional `settings` with only these keys: `appearance.reduceTransparency`, `appearance.darkFrom`,
> `appearance.darkTo`, `dock.size`, `dock.magnify`, `dock.magnification`, `desktop.iconSize`, `screensaver.style`
> (other keys are ignored, values are clamped). Limits: 64 files, 32 MB, 12 MB per file; only `.json .jpg .jpeg .png
> .webp .wav .md .txt` (+ `manifest.sha256`/`.sig`); unsafe paths refuse the package. Themes install into
> `~/Library/Themes/<id>/` (same id = update in place). Opening one in Files shows a sheet with **Install** and
> **Install and Apply**; *System Settings > Appearance > Themes* applies, removes and restores the default look.

A theme gathers the appearance (light/dark/automatic), the accent color, the wallpaper (with an optional dark
version), optional UI sounds and a few desktop settings in one package. It contains no code; only `theme.json` and
image/sound files.

```
Aurora.nxvtheme  (zip)
├── theme.json          required, at the root of the zip (or inside a single top-level folder)
├── wallpaper.jpg       required, 1280×720 JPG/PNG/WebP
├── wallpaper-dark.jpg  optional: shown while the dark appearance is on
├── sounds/click.wav    optional: replace the system sounds (click, pop, notify, alarm, trash, shutter, error,
│                       key, volume, startup; missing ones play the system's)
└── README.md           optional
```

```json
{
  "id": "com.sonerx7.theme.aurora",
  "name": {"en": "Aurora", "tr": "Kutup Işıkları", "de": "Polarlicht", "fr": "Aurore", "es": "Aurora"},
  "description": {"en": "Northern lights over a dark sky.", "tr": "Koyu gökyüzünde kuzey ışıkları."},
  "version": "1.0",
  "author": "Soner Çakır (sonerx7)",
  "appearance": "dark",
  "accent": "#3DDC97",
  "wallpaper": "wallpaper.jpg",
  "wallpaperDark": "wallpaper-dark.jpg",
  "sounds": "sounds",
  "settings": {"appearance.reduceTransparency": false, "dock.size": 56, "desktop.iconSize": 1}
}
```

| Field | Type | Description |
|------|-----|----------|
| `id` | string, required | Reverse domain (`com.adiniz.tema`), at least one dot; the same character rules as the `app.json` id. Updates are matched by this id. |
| `name`, `description` | string or language table | `en`, `tr`, `de`, `fr`, `es` recommended; a missing language falls back to English. |
| `version`, `author` | string | The version is compared as a dotted number (Update / Reinstall). |
| `appearance` | `"light"` \| `"dark"` \| `"auto"` | `appearance.mode` (0/1/2). Without it, the user's own stays unchanged. |
| `accent` | `"#RRGGBB"` | If it is one of the eight system colors, its index; otherwise a custom color (`appearance.accent` = 8, `appearance.accentCustom`). |
| `wallpaper` | file, required | A picture in the package; the `wallpaper` setting points directly at this file (it is not copied). |
| `wallpaperDark` | file | Shown while the dark appearance is on (the `wallpaperDark` setting). Forgotten when the user picks another wallpaper. |
| `sounds` | folder | `<name>.wav` files; the `sound.theme` setting points at this folder. |
| `settings` | object | Only the keys below; others are ignored, numbers are clamped to their range. |

| `settings` key | Type | Range (default) |
|---------------------|-----|----------------------|
| `appearance.reduceTransparency` | bool | Dock, menu bar and menus opaque (`false`) |
| `appearance.darkFrom`, `appearance.darkTo` | integer | 0–23; the dark hours of the `auto` appearance (19, 7) |
| `dock.size` | integer | 40–80 pixels (54) |
| `dock.magnify` | bool | Dock magnification (`true`) |
| `dock.magnification` | number | 1.0–2.0 (1.6) |
| `desktop.iconSize` | integer | 0 small, 1 medium, 2 large (1) |
| `screensaver.style` | integer | 0 shapes, 1 star voyage, 2 clock (0) |

Rules and behaviour:

- At most 64 files, 32 MB in total, 12 MB per file; allowed extensions `.json .jpg .jpeg .png .webp .wav .md .txt` (and
  `manifest.sha256`, `manifest.sig`). `__MACOSX/` and hidden files are ignored. A path that is absolute or contains
  `..`, `:` or `\` makes the package be refused (zip-slip protection). The limits are checked before anything is
  extracted.
- The install location is `~/Library/Themes/<id>/` (`sdmc:/NexvynOS/Users/<name>/Library/Themes/`). It is first
  extracted into a hidden temporary folder, verified again there and then moved into place. Same id = update in place;
  if an applied theme is updated, it is applied again immediately.
- Opening a `.nxvtheme` in Files shows a small sheet (Theme Installer) with the preview, appearance, accent color and
  size: **Install** or **Install and Apply**.
- *System Settings > Appearance > Themes*: clicking a card applies it, right click (X) removes it; **Restore Defaults**
  returns the appearance, accent color, wallpaper, sounds and the settings above to their defaults (themes are not
  deleted). The themes' pictures are also listed under a separate heading in the *Wallpaper* pane.
- If a removed theme is in use, the wallpaper and sounds return to the defaults; the colors stay as they are.
- The App Market installs themes the same way (`themes::installPackage`, `themes::apply`).

## 10. Font packs (.nxvfont)

> **Summary.** A `.nxvfont` is a zip (the same deterministic pack as `.nxvapp`, with `manifest.sha256`) holding
> `font.json`, the font files and the license. The App Market installs it into
> `sdmc:/NexvynOS/System/Fonts/User/<id>/`; the Fonts app and the font menus of the apps list it at once.

```
Nunito.nxvfont  (zip)
├── font.json
├── Nunito-Regular.ttf
├── Nunito-Bold.ttf
├── Nunito-Italic.ttf
├── LICENSE            (required: OFL, Apache 2.0 or another license that allows redistribution)
└── manifest.sha256
```

```json
{
  "id": "nunito",
  "name": {"en": "Nunito"},
  "family": "Nunito",
  "version": "3.600",
  "license": "OFL-1.1",
  "styles": {"regular": "Nunito-Regular.ttf", "bold": "Nunito-Bold.ttf", "italic": "Nunito-Italic.ttf"},
  "scripts": ["Latn", "Cyrl"],
  "languages": ["en", "tr", "de", "fr", "es"],
  "cjk": "ja"
}
```

- `styles` maps `regular` (required), `bold`, `italic` and `semibold` to files next to `font.json` (`.ttf`, `.otf`,
  `.ttc`, `.otc`). A pack holds only fonts, `font.json`, `LICENSE*` / `OFL.txt` and a readme: nothing that runs.
  At most 40 files, 40 MB per file, 64 MB in total.
- `cjk` (`ja`, `ko`, `zh`) marks a CJK pack: its regular font draws the characters the system fonts lack
  (`text::setPackFallbacks`), which matters on consoles and emulators without the system's shared fonts.
- Catalog entry: `"kind": "font"`, `"category": "fonts"`, `download` (the `.nxvfont`), `sha256`, `size`, `license`
  and `styles` (the style names, e.g. `["regular", "bold"]`). "Get" downloads, checks the SHA-256 and installs; then
  "Installed" (opens the Fonts app on it) and "Remove".
- Apps pick an installed family by name: `fontpacks::font("Nunito", fontpacks::BOLD)` gives a `text::` font id
  (`source/core/fontpacks.h`). The Text Editor lists installed families in its font menu.
- In the release repository a pack lives in `Store/Fonts/<slug>/` (font files, `LICENSE`, `font.json`, `store.json`,
  `icon.png`, `screenshots/`); `Tools/build_store.py` writes `<slug>.nxvfont` and the catalog entry.
