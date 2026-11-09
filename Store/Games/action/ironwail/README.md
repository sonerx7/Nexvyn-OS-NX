# Ironwail

A fast, modern engine for the classic 1996 first-person shooter, running in a Nexvyn OS window (Native SDK 1.1).
It is a separate program installed on its own; it is not part of Nexvyn OS.

## What is inside

| Part | Licence | Source |
|---|---|---|
| Ironwail 0.8.0 (engine, commit `08d578136ff4`) | GPL-2.0-or-later | https://github.com/andrei-drexler/ironwail |
| LibreQuake v0.09-beta lite (levels, monsters, art, sound, music) | BSD-3-Clause (`progs.dat`, `pop.lmp`: GPL-2.0) | https://github.com/lavenderdotpet/LibreQuake |
| Tremor and libogg (Ogg Vorbis music, linked into this app only) | BSD-3-Clause | https://gitlab.xiph.org/xiph/tremor , https://gitlab.xiph.org/xiph/ogg |
| SDL2 (linked into this app only) | zlib | Nexvyn OS Native Kit, devkitPro portlibs |

The package carries the licence texts and credits in `data/licenses/` (`SOURCES.txt` lists the exact versions). Nexvyn OS
changes to the engine are small patches for the window (data and save folders, no `dlopen`, no network sockets, a
driver workaround); apply them to the upstream commit above to get the exact source of this build.

## Bring your own

LibreQuake is a free replacement game. **No commercial game data is included**, and none is needed to play.

## Notes

Gamepad and keyboard work; there is no network play. The engine needs OpenGL 4.3 with compute shaders (the console has
it); a graphics driver without compute shows the menu and HUD but not the 3D world.
