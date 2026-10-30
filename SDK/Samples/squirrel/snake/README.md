# Snake (Squirrel)

**English** · [Türkçe](README.tr.md)

The classic snake game with controller, keyboard and touch; the walls wrap around and the best score is saved.

| | |
|---|---|
| Id | `com.sonerx7.sample.snake` |
| Language | Squirrel 3.2 |
| Min SDK | 1.5 |
| Permissions | none |
| Gamepad | goes to the app (L+R: cursor) |
| Window | 640 × 480, resizable |

## What it teaches

- `"gamepad": true` and `paddown` events; arrows and WASD on a keyboard
- a fixed-step game loop in `update(dt)`, queued turns
- `rand()` / `srand()`, `const`, a file-level `local` table
- steering by touch with `ui.hit` + `ui.mouse`
- `audio.tone`, `sys.vibrate`, pausing in `suspend` and `focus`

**Controls:** D-pad / arrows / WASD: steer · A, +, Enter, Space: start / continue · +, Esc, P: pause · touch: tap beside the head.

## Running it

- **On the console:** copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `snake.nxvapp` (or `python SDK/Tools/nxv/nxv.py push SDK/Samples/squirrel/snake/source --host <console-ip>`) and open it from Launcher. You can also open the folder in Nexvyn OS Studio and press **Run** (Ctrl+R).
- **In Ryujinx:** copy the same folder to `NexvynOS/Applications/` in the emulator's SD card folder.

Files (lines): `main.nut` (171).

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/squirrel/snake/source

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
