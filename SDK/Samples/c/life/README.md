# Game of Life (C)

**English** · [Türkçe](README.tr.md)

Conway's Game of Life: paint cells, run, step; the board is saved when you close the app.

| | |
|---|---|
| Id | `com.sonerx7.sample.life` |
| Language | C (TinyCC, compiled on the console) |
| Min SDK | 1.5 |
| Permissions | none |
| Gamepad | cursor |
| Window | 720 × 520, resizable |

## What it teaches

- Static arrays and a neighbour count that wraps around the edges
- a fixed step in `app_update` (1-30 generations a second, `ui_slider`)
- painting with `ui_hit` + `ui_mouse`: the first cell decides between drawing and erasing
- returned strings live for 15 SDK calls: `theme_color` is copied with `snprintf` before the loop
- `app_menu`, `app_suspend`, `store_setStr` in `app_autosave` / `app_close`

**Controls:** Space: play / pause · N: step · R: random · C: clear · drag: draw / erase cells.

## Running it

- **On the console:** copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `life.nxvapp` (or `python SDK/Tools/nxv/nxv.py push SDK/Samples/c/life/source --host <console-ip>`) and open it from Launcher. You can also open the folder in Nexvyn OS Studio and press **Run** (Ctrl+R).
- **In Ryujinx:** copy the same folder to `NexvynOS/Applications/` in the emulator's SD card folder.
- **C:** no build step; the `.c` files are compiled on the console when the app opens. A C app installed from the SD card asks for consent once.

Files (lines): `main.c` (173).

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/c/life/source

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
