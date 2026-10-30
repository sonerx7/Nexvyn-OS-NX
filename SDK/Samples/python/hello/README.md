# Hello Python

**English** · [Türkçe](README.tr.md)

The built-in **Hello Python** app: a to-do list, an analog clock and live weather JSON.

| | |
|---|---|
| Id | `hellopy` |
| Language | Python (pocketpy 2) |
| Min SDK | 1.3 |
| Permissions | `network` |
| Gamepad | cursor |
| Window | 640 × 520, fixed |

> This is a copy of the sample that ships with Nexvyn OS (id `hellopy`); installed from the SD card it sits next to the built-in one as `ext.hellopy`.

## What it teaches

- A class as the app object (`app = Hello()`), `from todos import TodoList`
- `net.json(url, callback)` with `(data, error)` (`network` permission)
- `store`, a toast with `timer.after`, a menu and a method passed as the `ui.alert` callback

**Controls:** Switch tabs with the segmented control at the top.

## Running it

- **On the console:** copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `hello.nxvapp` (or `python SDK/Tools/nxv/nxv.py push SDK/Samples/python/hello/source --host <console-ip>`) and open it from Launcher. You can also open the folder in Nexvyn OS Studio and press **Run** (Ctrl+R).
- **In Ryujinx:** copy the same folder to `NexvynOS/Applications/` in the emulator's SD card folder.

Files (lines): `clock.py` (63), `main.py` (216), `todos.py` (49).

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/py_check.py <Nexvyn-OS-NX>/SDK/Samples/python/hello/source

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
