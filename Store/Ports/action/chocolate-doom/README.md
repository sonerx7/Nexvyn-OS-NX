# Chocolate Doom

A faithful source port of the classic 1993 first-person shooter engine, running in a Nexvyn OS window (Native SDK 1.1).
It is a separate program installed on its own; it is not part of Nexvyn OS.

## What is inside

| Part | Licence | Source |
|---|---|---|
| Chocolate Doom 3.1.0 (engine) | GPL-2.0-or-later | https://github.com/chocolate-doom/chocolate-doom (tag `chocolate-doom-3.1.0`) |
| Freedoom 0.13.0, `freedoom1.wad` (levels, art, music) | BSD-3-Clause | https://github.com/freedoom/freedoom (release v0.13.0) |
| SDL2 and SDL2_mixer (linked into this app only) | zlib | Nexvyn OS Native Kit, devkitPro portlibs |

The package carries the licence texts and credits in `data/licenses/`. Nexvyn OS changes to the engine are the patch
files in `data/licenses/patches/` (apply them to the tag above to get the exact source of this build): the IWAD is also
searched in the app's data folder and in the package, the window close button quits at once, the gamepad is on by
default, and the music file is written to the app data folder.

## Bring your own

Freedoom is a free replacement game, so the app starts right away. **No commercial game data is included.** To play
the original game, put your own IWAD (`doom.wad`, `doom2.wad`, `plutonia.wad`, ...) into the app's data folder
(`Users/<user>/Library/Application Support/com.nexvyn.port.chocolatedoom`); an IWAD you add is used first.

## Controls

Gamepad (on by default): left stick moves, right stick turns, `ZR` fires, `A` uses, `+` opens the menu. Keyboard and
mouse work as in Chocolate Doom (more options are in the game's own Setup menu). No network play.
