# mGBA with a game library

A fast, accurate Game Boy Advance emulator in a Nexvyn OS window (Native SDK 1.1), with its own game library: a grid or list of
your games with covers, details, favourites, search, settings, save states and touch buttons. It is a separate program installed on
its own; it is not part of Nexvyn OS.

## Bring your own games

**No games and no BIOS are included, and none is needed.** Copy your own `.gba` files into
`sdmc:/NexvynOS/Roms/gba/` (from a computer, or with a file manager), or pick another folder in Settings > Library, or pick a
single file from the empty-library screen. Only play games you legally own. A fresh install shows the empty library with this
help. Your games are never copied or changed.

- **Covers:** a generated title card at first; after you play a game, a picture of its own first frame. Optional box art from the
  public libretro thumbnail server is **asked about on first run (Yes / No / Later) and can be changed in Settings > Library**; when on, the app asks that server for the
  box art, an in-game picture and the title picture of each game (matched by the file's CRC32 against the built-in list, else by file name) (one request every 2 seconds, in the background; the server sees the game's name), keeps the
  pictures on the SD card, uses no account or key, and shows a message when there is no network.
- **Names and details:** games are recognised by their CRC32 against a small bundled index built from the libretro-database
  (name, year, publisher, genre); unknown files use the cleaned file name. You can edit a game's name and description.
- **Home page:** a left rail (All, Favourites, Recent, then the systems with their game counts), a grid or list of bigger covers with
  search and sort (name, last played, play time), and a detail pane for the selected game: cover, title, system, play time, last
  played, file size, description, a big Play button, favourite, game settings, edit info and the game's in-game screenshots (click
  one to enlarge it, delete it, or set it as the cover).
- **Controls:** D-pad moves, `A` plays, `Y` favourite, `X` game settings, `L` / `R` library view, `ZL` / `ZR` flip through screenshots,
  `-` sort, `R3` rescan, `+` settings. In a game (all combinations can be changed in Settings > Controls, for every game or one game):
  `+` and `-` together open the menu (resume, save state, load state, screenshot, restart, quit to the list); `ZL` + `-` quick save,
  `ZR` + `-` quick load, `L3` + `-` screenshot, a click on the right stick toggles fast forward. Touch buttons appear when you touch the screen.
- **Screenshots:** the hotkey or the pause menu saves the picture the game shows as a small PNG (`.library/shots/<game>/NN.png`,
  at most 12 per game, the oldest one is replaced when you allow it); they stay on the SD card and are never sent anywhere.
- **Settings:** Video (size, filter, shape, screen effect, overscan crop, frame skip, handheld / dock presets), Audio, Controls (layout, dead
  zone, turbo, button mapping, hotkeys), Saves (slots, automatic state, screenshot limit), Emulation (BIOS, fast forward speed, region where
  the core has one) and Library. Every game can override each of them (Game settings).

## Updating from the earlier mGBA package

The game you chose before (`rom.gba`) appears in the library as "Game from the earlier version", with its `rom.sav` battery save.
Your saves are kept.

## Licence and credits

- **Core:** mGBA 0.10.5, source https://github.com/mgba-emu/mgba at commit `26b7884bc25a`, licence **MPL-2.0**; copyright holders and the
  full licence text are in the app (Settings > About > Licence text) and in `data/licenses/`.
- **Frontend and port:** sonerx7 (https://github.com/sonerx7), GPL-3.0-or-later.
- **Icon:** the original mGBA project icon (`res/mgba-1024.png` of the mGBA source, MPL-2.0, unchanged apart from scaling and a background glow).
- **No BIOS, firmware or commercial games are included; add your own legally obtained files.**

## What is inside

| Part | Licence | Source |
|---|---|---|
| mGBA 0.10.5 (emulation core, unmodified) | MPL-2.0 | https://github.com/mgba-emu/mgba (tag `0.10.5`, commit `26b7884bc25a`) |
| blip_buf (sound resampler, part of mGBA) | LGPL-2.1-or-later | https://github.com/mgba-emu/mgba/tree/0.10.5/src/third-party/blip_buf |
| inih (settings reader, part of mGBA) | BSD-3-Clause | https://github.com/benhoyt/inih |
| Dear ImGui (interface) | MIT | https://github.com/ocornut/imgui |
| stb_image (PNG decoder for the optional box art) | MIT / public domain | https://github.com/nothings/stb |
| The frontend, the core interface and the build files | MPL-2.0 | Nexvyn OS Native Kit sources of this port |

mGBA's own source files are not changed (0 patched lines). The package carries the licence texts in `data/licenses/`. The name
index lists names, years, publishers and genres from the libretro-database; no cover art is bundled or redistributed.
