# RA2 Yuri Port: beta 1.0.1

Native Yuri's Revenge recompilation runtime for Nexvyn OS, with a system-themed
setup launcher. This is a beta; full gameplay/device acceptance remains pending.
The original name, icon, app ID and native ABI v1 are retained.

| Field | Value |
|---|---|
| App ID | `com.sonerx7.redalert2` |
| Channel | App Market Beta; `kind: port`, strategy |
| Runtime | Native `.nxvmod`, Native SDK 1.2; minimum general SDK 1.10 |
| Target | General SDK 1.15, Native SDK 1.2 |
| Launcher languages | English, Turkish, German, Spanish, French, Japanese, Korean, Chinese |
| Upstream | [redalert2-recomp](https://github.com/sp00nznet/redalert2-recomp), [pcrecomp](https://github.com/sp00nznet/pcrecomp) |
| License | MIT for the recompilation engine and host wrappers; original game files are not included |

## Set up without putting game data in the app package

Open the launcher and choose your complete game installation folder. It must
contain the supported `gamemd.exe`, `ra2.mix`, `ra2md.mix` and the remaining data
from your own installation. The current engine targets Yuri's Revenge; a standalone
base-game `game.exe` or a different executable build is not silently accepted.
The executable timestamp is checked before the engine runs. Do not substitute
empty files to bypass setup: presence checks do not establish data integrity.

The chosen folder and optional multitouch setting are saved atomically in the
app's persistent data. Your external game files remain in place. By default the
launcher offers the persistent `game/` directory reported on screen; its full path
includes your user profile and is not hardcoded in this guide.

## Updating an older beta safely

Before updating, back up your original game files and saves, especially if you
placed them inside `Applications/com.sonerx7.redalert2.nxvapp/game/`. Keep Previous
Version must remain enabled until those files are safely outside the app package.
An app package is replaceable; it is not a permanent game-data directory.

The launcher detects legacy package data, a retained `.prev-` package and the old
`sdmc:/switch/openra2/` location. Before playing from an application package it
asks to copy the files into a new persistent app-data directory. It never merges
into an existing directory, deletes originals or changes the saved path before a
successful copy. Allow enough free space. Closing cancels the copy; incomplete
copies remain available for inspection. Data already deleted before this update
cannot be recovered by this launcher. Prefer an external permanent game folder.

## Controls

- Left stick: time-based pointer movement, clamped to the current window.
- A/ZR: select and drag; X/ZL: right click.
- D-pad: map arrow keys; B/Plus: Escape; Minus: Tab; Y: system keyboard.
- Physical keyboard/mouse retain normal input. Touch supports direct tap and drag.
- Controls in the launcher offer a saved multitouch toggle, off by default. It
  enables shared SDL two-finger/long-press gestures. Actual in-game zoom support
  is not claimed; the original engine determines which actions it supports.

Only the launcher/setup/help supports all eight languages. Original in-game text,
movies and voices follow the installed game files. Native code runs in the OS
process; this package does not introduce a sandbox or guaranteed fault recovery.

## Validation scope

The setup layer is rebuilt against the current kit and linked with retained
engine objects. Package hashes, all eight launcher dictionaries and bounded
no-overwrite data copying are checked. Short emulator setup evidence is recorded
in the private QA report. This is not a clean rebuild or physical-console gameplay
certification, and performance is not guaranteed.
