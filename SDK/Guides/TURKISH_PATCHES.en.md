# Turkish Patches: research and design

[Türkçe](TURKISH_PATCHES.tr.md) · **English**

This document describes the research for the user's request "port YamaNX to this system so we can install Turkish
patches" and why the `turkceyama` app works the way it does. Research date: 27 October 2026.

## 1. What is YamaNX today?

- **What:** an SDL2-based Turkish patch installer written by SertAy (a homebrew `.nro`, an `.nsp` shortcut for the home
  menu, an `.exe` for PC emulators, an `.apk` for mobile emulators). The archive has more than 650 games. Most of
  the patches belong to Swatalk (more than 470 free patches), the rest to translators such as Soner Çakır, Profesör
  Pikachu, Dede00, emre, davetsiz57. The developer clearly states that he did not make the patches himself.
  - Source: <https://github.com/sertay1/YamaNX> (README, releases: v2.1.0 is the latest)
  - Announcement thread: <https://forum.donanimarsivi.com/posts/11130968/>
  - The developer's links: <https://linktr.ee/yamanx>
- **Is the source code open?** The code can be read on GitHub, but the license is **not a free software license**
  (`LICENSE`, "Copyright (c) 2026 SertAy. All Rights Reserved." + special terms):
  1. Attribution is required, claiming it as your own is forbidden.
  2. Changes must be documented, and SertAy must be credited with a link.
  3. **Non-commercial use:** the software and the source code may not be sold or distributed for money without written
     permission.

  The third term adds a restriction on top of GPL-3.0; therefore **YamaNX code cannot be taken into Nexvyn OS
  (GPL-3.0-or-later).** Nexvyn OS's own code has no code from YamaNX (the YamaNX port is a
  separately licensed app, see 3b).
- **Catalog / API:** there is no official API. The app reads the patch list from a public gist of the developer
  (`yamalar.txt`, one `Name|TitleID|URL|Maker|Version|Size` per line); the files are in the `YamaNX_Sertay` item on the
  Internet Archive. Neither the gist nor the archive item has a license or terms of use; there is no statement allowing
  other clients to use this list either. These files are YamaNX's own internal data source; not a documented, stable
  interface or one opened to others.
- **Installation format:** the patches are Atmosphère LayeredFS mods. The zip is extracted into
  `sdmc:/atmosphere/contents/` (`<TID>/romfs/...` inside the zip). YamaNX writes the full path of every file it
  installs, line by line, to `atmosphere/contents/<TID>/YamaNX_manifest.txt`; it uses this list when uninstalling.
  The version information is just a label (e.g. `V1.0.4`); it is not compared with the game version.
- **The consent question in the community:** in the forum thread there are discussions about translators' patches
  being shared in bulk archives (e.g. <https://forum.donanimarsivi.com/posts/11238902/>). Some translators allow it,
  some teams distribute their patches only through their own channels.

## 2. Other Turkish patch sources

| Source | Link | Note |
| --- | --- | --- |
| Swatalk | <https://discord.com/invite/xshWw2jBK6> | Hundreds of free patches, a request channel |
| Soner Çakır | <https://discord.com/invite/tB93ZUsRYE> | Translator community server |
| SinnerClown Çeviri | <https://sinnerclownceviri.com/forumlar/nintendo-tuerkce-yama.74/> | The console patch section of the team's forum ([source](https://forum.donanimhaber.com/nintendo-switch-turkce-yama-arsivi-ariyorum--156348798)) |
| Techolay guide | <https://techolay.net/sosyal/konu/guvenilir-turkce-yama-ekipleri-ve-siteler.147247/> | A list of trustworthy teams (general) |

None of them publishes a public API or terms that allow third-party clients.

## 3. The chosen path and why

The decision rule in the task: if there is an open-source client **and/or** an API that allows third-party clients,
write a native client; otherwise write a general installer without scraping/bypassing.

- The client is not open source (non-commercial restriction, incompatible with the GPL) → it cannot be ported.
- There is no public API with clear terms. Reading the gist is technically possible, but it is an undocumented
  internal data file; there is no permission, and the patches belong to the translators, not to YamaNX. The consent
  discussion is also still going on.

**Result: path 3.** `turkceyama` does not fetch a list from any patch site, and does not download, copy or host files.

### 3b. Update (2026-10-29): the YamaNX port

By the project owner's decision YamaNX was ported to Nexvyn OS in Lua: `romfs/Applications/yamanx.app` (Switch Tools).
It uses YamaNX's own patch list and download sources the way YamaNX does. The source and its author are named on every
screen and on the About page: **YamaNX by SertAy**, <https://github.com/sertay1/YamaNX>. The app ships under the YamaNX
license (non-commercial, attribution) as a separate program and is not linked into Nexvyn OS's GPL code; the license
text and the list of modifications are in `yamanx.app/LICENSE` and `yamanx.app/NOTICE.md`, a short note is in
`THIRD_PARTY_NOTICES.md`. `turkceyama` stays as it is: it installs a zip you pick and fetches no list.

## 4. The app (`source/apps/app_turkceyama.cpp`)

- **Install from zip:** the user downloads the patch from the team's site (Browser, PC, cable) and picks it in the app.
  - Layout detection: `[anything/]<TID>/romfs|exefs/...` (including `atmosphere/contents/<TID>`, `contents/<TID>`),
    only `romfs/` or `exefs/` (the game is picked from a list or the title id is entered),
    `exefs_patches/<name>/...`. Every other file (readme, `YamaNX_manifest.txt`) is skipped and their count is shown.
  - Path safety: every entry is normalized; entries with an absolute path, a drive letter, `..`, `.` or control
    characters are not written. The target is always under `sdmc:/atmosphere/...`.
  - Backup: every file that would be overwritten is first copied under
    `sdmc:/NexvynOS/Backups/TurkcePatches/<id>/<path>`. If the backup cannot be made, the installation stops. On a
    write error the installation is rolled back.
  - Update: if a new zip is installed for the same game, the old patch is removed first (its backups are put back),
    then the new one is installed.
  - Version check: the target version is read from the catalog, or else from a `V1.2.3` pattern in the zip name; it is
    compared with the game version on the console (ns, `games_lib`). An orange warning if they do not match, a gray
    note if unknown.
- **Installed patches:** enable/disable (while disabled, the files are moved under
  `sdmc:/NexvynOS/System/TurkcePatches/disabled/<id>/` and the original files are put back from the backup), remove
  (the backups are put back, empty folders are deleted). Patches installed with YamaNX are recognized through
  `YamaNX_manifest.txt` and can be removed (only the files in that title's folder).
- **YamaNX card:** at the top of the Installed Patches page. YamaNX is installed as a separate program, without copying
  its code, from the homebrew package catalog (`romfs/System/Packages/catalog.json`, package `yamanx`: repository
  `sertay1/YamaNX`, asset `YamaNX.nro`, target `switch/YamaNX/YamaNX.nro`, NACP name "YamaNX"); the license field
  reads "SertAy — all rights reserved (non-commercial use)", and the warnings say it is third-party and that the patches
  belong to the translators.
  - If it is not installed, **Install YamaNX**: the package manager's confirmation dialog (size, warnings), download
    progress on the card.
  - If it is installed, **Open YamaNX**: chain-loading with hbloader, the same way the package manager opens NROs
    (Nexvyn OS closes, YamaNX starts). In applet (Album) mode an extra note is shown because memory is limited.
  - "Project page" opens the GitHub page in the Browser. Patches installed by YamaNX keep appearing in the list below.
- **Records:** `sdmc:/NexvynOS/System/TurkcePatches/installed.json`
  ```json
  {"format": 1, "patches": [{"id": "0100ABCD12345000-1761600000", "tid": "0100ABCD12345000", "name": "Oyun",
    "version": "1.2", "gameVersion": "1.0.4", "team": "Ekip", "page": "https://...", "source": "dosya.zip",
    "installed": 1761600000, "enabled": true, "bytes": 123456,
    "files": ["atmosphere/contents/0100ABCD12345000/romfs/..."], "backedUp": ["atmosphere/..."]}]}
  ```
  `files` are relative to the SD root. Tools such as Mod Manager can recognize these files as "belonging to Turkish
  Patches".
- **Patch sites:** the sources in the catalog; "Open" opens the Browser. The team's name and page are highlighted on
  the cards.
- **How it works:** a short summary of this section inside the app.

## 5. Catalog format

`romfs:/System/TurkcePatches/catalog.json`; to refresh it with a system update:
`sdmc:/NexvynOS/System/Overlay/TurkcePatches/catalog.json`.

```json
{
  "format": 1,
  "revision": 2,
  "sources": [
    {"name": "Ekip adı", "kind": "web|chat|code", "url": "https://...",
     "about": {"tr": "Kısa tanıtım", "en": "Short intro"}}
  ],
  "patches": [
    {"tid": "0100ABCD12345000", "game": "Oyun adı", "team": "Ekip adı",
     "patchVersion": "1.2", "gameVersion": "1.0.4", "page": "https://ekibin-yama-sayfasi",
     "credits": {"tr": "Çeviri: A, B · Test: C", "en": "Translation: A, B · Testing: C"},
     "notes": {"tr": "DLC gerekir", "en": "Requires the DLC"}}
  ]
}
```

Rules:
- Add only information the team allows. **There is no download link field**: `page` is the team's own page.
- `gameVersion` is the game version the patch was made for (the version the console shows, e.g. `1.0.4`).
- `url` / `page` may only be `https://` (`http://` is accepted for a page too); others are ignored.

## 6. Later

- If a patch project publishes an API and terms open to third-party clients (or SertAy and the translators give
  written permission), the catalog can be filled from that source; the installation and backup logic stays the same.
- Teams can open a PR to add their own entries to `catalog.json`.
