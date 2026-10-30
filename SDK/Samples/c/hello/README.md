# Hello C

**English** · [Türkçe](README.tr.md)

The built-in **Hello C** app: a counter, bouncing balls and live JSON, compiled on the console by TinyCC.

| | |
|---|---|
| Id | `helloc` |
| Language | C (TinyCC, compiled on the console) |
| Min SDK | 1.5 |
| Permissions | `network` |
| Gamepad | cursor |
| Window | 640 × 520, fixed |

> This is a copy of the sample that ships with Nexvyn OS (id `helloc`); installed from the SD card it sits next to the built-in one as `ext.helloc`.

## What it teaches

- Two `.c` files (`main.c`, `balls.c`) and a header (`balls.h`): all compiled when the app opens
- a `char` buffer with `ui_textfield`, `store_getStr` / `store_setStr`
- `net_json(url, NULL, on_weather, NULL)` and `json_pretty` (`network` permission)
- `nxv_fmt` + `TR1`, `ui_segmented`, a function-pointer callback with `ui_alert`

**Controls:** Counter tab: Space = +1 · Balls tab: click to push the balls.

## Running it

- **On the console:** copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `hello.nxvapp` (or `python SDK/Tools/nxv/nxv.py push SDK/Samples/c/hello/source --host <console-ip>`) and open it from Launcher. You can also open the folder in Nexvyn OS Studio and press **Run** (Ctrl+R).
- **In Ryujinx:** copy the same folder to `NexvynOS/Applications/` in the emulator's SD card folder.
- **C:** no build step; the `.c` files are compiled on the console when the app opens. A C app installed from the SD card asks for consent once.

Files (lines): `balls.c` (62), `balls.h` (8), `main.c` (124).

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/c/hello/source

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
