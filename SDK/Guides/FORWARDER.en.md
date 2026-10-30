# Nexvyn OS forwarder guide

**English** · [Türkçe](FORWARDER.tr.md)

When Nexvyn OS runs in applet mode, the **More info** button on the System Settings > About screen opens this document.

## In short

When Nexvyn OS is started from the Album it runs as an applet and gets little memory. Two ways give it full memory:

1. **Title takeover:** hold **R** while starting any game. The Homebrew menu opens instead of the game; start Nexvyn OS
   from there. Nothing to install, and it is the recommended way for most users.
2. **Forwarder:** installs a "Nexvyn OS" shortcut with its own icon on the HOME menu. Pressing the icon starts Nexvyn OS
   directly in application mode, with full memory.

## What is a forwarder?

A forwarder is a tiny NSP that does not contain Nexvyn OS itself. It only holds a loader (the forwarder build of
nx-hbloader) and the path of the `.nro` on the SD card. When it is opened from the HOME menu, the loader starts
`sdmc:/switch/NexvynOS.nro` as an application. When you update Nexvyn OS, the forwarder opens the new version by
itself.

## Three ways to run

| | Album (applet mode) | Title takeover (with R) | Forwarder |
|---|---|---|---|
| How it opens | Album > Homebrew menu | Hold R while starting a game | The Nexvyn OS icon on the HOME menu |
| Memory | Low (a few hundred MB, firmware dependent) | Full (about 3.2 GB) | Full (about 3.2 GB) |
| System web applet, launching games | No | Yes | Yes |
| Extra setup | None | None (Atmosphère default) | NSP install and patches that accept unsigned content |
| Needs an installed game | No | Yes | No |

Nexvyn OS shows the mode it runs in on the System Settings > About > **Launch mode** row. In applet mode the same
screen also shows the memory available in that session.

## Read first: safety and legal notes

- **Installing a forwarder is risky.** The console does not normally run NSPs that are not signed by its maker.
  Starting a forwarder you built yourself needs third-party patches that skip the signature check (usually called
  "sigpatches"). Atmosphère does not include them. Nexvyn OS does not provide or link them, and the tools in this
  repository touch neither them nor the firmware. Using these patches is your decision and your responsibility.
- **Ban risk.** A console with unsigned content installed can be banned from online services. Use emuMMC if you can and
  keep the CFW side offline.
- **Keys.** The PC tools that build NSPs need a `prod.keys` file. Take this file only from your own console (e.g. with
  Lockpick_RCM). Never share it, download it from the internet or upload it to any site. Nexvyn OS does not distribute
  keys. `tools/make_forwarder.py` does not download keys, copy them, put them into the NSP or print their values.
  Method A (sphaira) needs no key file at all.
- **Not for piracy.** This guide is only about starting Nexvyn OS on your own console.
- **If you are not comfortable, use title takeover.** It needs no patches, keys or NSP and gives the same memory.

## Requirements (Atmosphère side)

- A console that boots with Atmosphère. A current version and emuMMC are recommended.
- For title takeover: `atmosphere/hbl.nsp` from the Atmosphère package, `hbmenu.nro` at the root of the SD card and the
  default setting in `atmosphere/config/override_config.ini` (`override_any_app=true`, key **R**). If you did not
  change this setting, everything is ready.
- For a forwarder, in addition:
  - A homebrew that can install NSPs: [sphaira](https://github.com/ITotalJustice/sphaira) (GPL-3.0) or
    [Goldleaf](https://github.com/XorTroll/Goldleaf) (GPL-3.0).
  - A system that can run unsigned content (see the warning above). Without it the forwarder closes right away with
    "The software was closed because an error occurred."
  - Firmware 12.0.0 or later.
- According to the README, Nexvyn OS lives at `sdmc:/switch/NexvynOS.nro` on the SD card. The forwarder opens this
  file. If you put the file somewhere else (e.g. `sdmc:/switch/NexvynOS/NexvynOS.nro`), build the forwarder with that
  path.

## Nexvyn OS forwarder Title ID

**`054E5856594E0000`**

- It is "NXVYN" in hexadecimal. The leading `05` is the prefix commonly used for forwarders and does not collide with
  the ids of official software.
- `tools/make_forwarder.py` always uses this id. A forwarder reinstalled with the same id replaces the old one; no
  second icon appears on the HOME menu.
- With NTON, pass `--id 054E5856594E0000`.
- sphaira computes its own id from the `.nro` path (it also starts with `05`). As long as the path stays the same, the
  id stays the same, so reinstalling with sphaira also overwrites the old one. If you install both sphaira's forwarder
  and this repository's forwarder, you get two icons; delete one.

## Method A: sphaira on the console (easiest)

No PC and no key file needed; sphaira derives the needed key from the console itself.

1. Download the latest sphaira from its [Releases](https://github.com/ITotalJustice/sphaira/releases) page and copy it
   to the `switch` folder on the SD card.
2. Open sphaira from the Homebrew menu.
3. Select Nexvyn OS in the homebrew list, open the options with **X** (Options) and choose **Install Forwarder**. If
   installing is turned off in the settings, sphaira asks you to turn it on first.
4. In the form that opens, check the name (Nexvyn OS), the author and the icon. The icon is taken from the `.nro` file.
   **Profile Selection** can stay off. Press **Create Forwarder**.
5. The Nexvyn OS icon appears on the HOME menu.

Menu names may change between sphaira versions. These steps were written from the source code of sphaira 1.0.8; they
were not tried on a real console by the Nexvyn OS team.

## Method B: `tools/make_forwarder.py` on a PC (fixed title ID)

The script in the repository builds the NSP with hacBrewPack and a forwarder loader based on nx-hbloader. The name is
"Nexvyn OS"; the author and version come from the Makefile (`APP_AUTHOR`, `APP_VERSION`), the icon from
`docs/forwarder/icon.jpg`.

Requirements:

- Python 3.8 or later. Pillow is needed only if you give an icon that is not a 256×256 JPEG.
- A `prod.keys` taken from your own console (it must contain `header_key` and `key_area_key_application_00`).
- hacBrewPack. The original repository (The-4n/hacBrewPack) is no longer online. The source code is kept, under the
  GPL-2.0 license, in the [rlaphoenix/hacBrewPack](https://github.com/rlaphoenix/hacBrewPack) mirror. A ready-made
  `hacbrewpack.exe` for Windows ships inside the NTON package (`nton/bin/`); if you installed NTON with
  `pip install nton`, the script finds this file by itself.
- The forwarder loader (stub): `main` and `main.npdm`. By default the script downloads them from a pinned version of
  the NTON repository (commit `8e764dc`, Horizon 21 support) and verifies them with SHA-256. Their source is
  nx-hbloader and Forwarder-Mod (both ISC licensed). If you like, give a folder you built yourself or another address
  with `--stub`.

Command (PowerShell or Git Bash, at the root of the repository):

```
python tools/make_forwarder.py --keys "C:\Users\<you>\.switch\prod.keys" --hacbrewpack "C:\tools\hacbrewpack.exe"
```

Result: `dist/forwarder/Nexvyn OS v<version> [054E5856594E0000].nsp`.

| Option | What it does |
|---|---|
| `--nro-path` | If the `.nro` is somewhere else, e.g. `sdmc:/switch/NexvynOS/NexvynOS.nro` |
| `--stub` | The loader folder or address (with `main`, `main.npdm` inside) |
| `--icon` | Another icon (256×256 JPEG; other formats too when Pillow is installed) |
| `--profile-select` | Ask for a user at startup |
| `--out` | Output folder (default `dist/forwarder`) |
| `--dry-run` | Only prepares the files, does not run hacBrewPack, needs no keys |

What the script does:

- Writes `control.nacp` from scratch: the name "Nexvyn OS" in all 16 languages, no save data area (Nexvyn OS keeps its
  data on the SD card), screenshots on, video capture off.
- Cleans the icon. Extra information such as EXIF is removed; otherwise the HOME menu may show "?". The icon is
  written for each of the 16 languages.
- Writes the `.nro` path into the `romfs/nextNroPath` and `romfs/nextArgv` files.
- Sets the id in `main.npdm` (ACI0 and the ACID range) to the forwarder id.
- Runs hacBrewPack with `--nologo`. Because the console maker's boot logo cannot be redistributed, a short black screen
  shows at startup instead of the logo.

## Method C: NTON on a PC (with a GUI)

[NTON](https://github.com/rlaphoenix/NTON) (GPL-3.0; a Windows installer or `pip install nton`) does the same job with a
GUI. Use the fixed id for Nexvyn OS (D: is the drive letter of the SD card):

```
nton build "D:\switch\NexvynOS.nro" --id 054E5856594E0000 --name Nexvyn OS --publisher sonerx7 --version 0.2.0 --icon docs\forwarder\icon.jpg
```

If the `.nro` is on the PC, add `--sdmc /switch/NexvynOS.nro`. The key warning above applies equally to the
`prod.keys` NTON asks for.

## Installing the NSP

1. Copy the NSP to the SD card.
2. Select the NSP in sphaira's file browser or in Goldleaf and install it.
3. Press the Nexvyn OS icon on the HOME menu. Do not hold **R** while opening it; Atmosphère may trigger title takeover
   and open the Homebrew menu.
4. The System Settings > About > Launch mode row should read "Application (full memory)".

## Updating

- **You do not need to touch the forwarder to update Nexvyn OS.** The forwarder only opens
  `sdmc:/switch/NexvynOS.nro`. System Settings > Software Update overwrites this file; when updating by hand, copy it
  to the same place too.
- The version text on the HOME menu is the version at the moment you built the forwarder and does not change by
  itself. If you like, rebuild the forwarder with the new version and install it; since the id is the same, it
  overwrites the old one.
- Rebuild the forwarder when: you moved the `.nro` file, you want to change the icon or the name, or the forwarder
  does not start after a firmware update. In the last case a new version of the loader may be needed (this happened
  with firmware 19 and 21).

## Uninstalling

1. Select the Nexvyn OS icon on the HOME menu, open the options with **+** and delete the software (depending on the
   firmware the menu is called "Manage Software > Delete Software" or "Data Management"). Deleting the title with id
   `054E5856594E0000` in sphaira or Goldleaf works too.
2. This only deletes the forwarder. Nexvyn OS itself (`sdmc:/switch/NexvynOS.nro`) and your data (`sdmc:/NexvynOS/`)
   stay where they are; delete them by hand if you want to remove them too.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| "The software was closed because an error occurred." right after opening | The system does not accept unsigned content (see the warnings), or `prod.keys` is older than the firmware on the console. |
| Crashes after a black screen | The `.nro` path is wrong or the file is missing. Rebuild the forwarder with the right `--nro-path`. |
| The icon shows "?" | The icon is not a JPEG or contains EXIF. The script cleans this; with other tools give `docs/forwarder/icon.jpg`. |
| The Homebrew menu opens | R was held while pressing the icon. |
| Nexvyn OS is still in applet mode | You opened it from the Album instead of the forwarder. Look at the "Launch mode" row on the About screen. |

## What is verified and what was not tried

- **Verified (on a PC):** the script's `--dry-run` output (NACP layout, NPDM id patch, icon, `nextNroPath`) and the
  SHA-256 values of the default loader. Nexvyn OS's detection of applet mode and its notice passed the compiler check.
- **Not tried on a real console by the Nexvyn OS team:** building the NSP with hacBrewPack (needs real keys),
  installing and opening the NSP, the `--nologo` startup, the icon in every system language, the sphaira menu steps,
  launching games from the forwarder and exiting. If you try it, report the result in a GitHub issue.

## Why these tools?

- **sphaira:** actively developed (1.0.8, October 2026), GPL-3.0, runs on the console, needs no key file.
- **NTON:** actively developed (v3.0.1, September 2026), GPL-3.0; its loader was rebuilt for firmware 21.
- **hacBrewPack + nx-hbloader forwarder:** the well-known open-source (GPL-2.0 / ISC) classic method. Used in the
  script for a fixed id specific to Nexvyn OS and a reproducible build. hacBrewPack has not been updated since 2019 but
  is enough for this job. The script runs hacBrewPack as a separate program; no third-party binary was added to the
  Nexvyn OS repository.
- **Not recommended:** Switch Army Knife (SAK) is closed source and was archived in 2023. TooTallNate/switch-nsp-forwarder
  has visible source but no license file. Do not use web-based generators that ask for your keys.
