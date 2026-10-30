# Stopwatch

**English** · [Türkçe](README.tr.md)

A stopwatch with laps: the fastest lap green, the slowest red; time and laps survive closing the app.

| | |
|---|---|
| Id | `com.sonerx7.sample.stopwatch` |
| Language | Squirrel 3.2 |
| Min SDK | 1.5 |
| Permissions | none |
| Gamepad | cursor |
| Window | 480 × 520, resizable |

## What it teaches

- A class as the app; array fields are created in `load` (class defaults are shared)
- `update(dt)` exists only so the window is redrawn every frame while running
- an array of tables in `store` (`laps`)
- a `ui.beginScroll` list, menu items with `enabled` and `shortcut`
- sharing the lap list with `sys.share(text)`; `suspend`, `autosave`, `close`

**Controls:** Space / Enter: start-stop · L: lap · R: reset (when stopped).

## Running it

- **On the console:** copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `stopwatch.nxvapp` (or `python SDK/Tools/nxv/nxv.py push SDK/Samples/squirrel/stopwatch/source --host <console-ip>`) and open it from Launcher. You can also open the folder in Nexvyn OS Studio and press **Run** (Ctrl+R).
- **In Ryujinx:** copy the same folder to `NexvynOS/Applications/` in the emulator's SD card folder.

Files (lines): `main.nut` (146).

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/squirrel/stopwatch/source

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
