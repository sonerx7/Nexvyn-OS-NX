# Hello Squirrel

**English** · [Türkçe](README.tr.md)

The built-in **Hello Squirrel** app: a to-do list, an analog clock and live weather JSON.

| | |
|---|---|
| Id | `hellosq` |
| Language | Squirrel 3.2 |
| Min SDK | 1.5 |
| Permissions | `network` |
| Gamepad | cursor |
| Window | 640 × 520, fixed |

> This is a copy of the sample that ships with Nexvyn OS (id `hellosq`); installed from the SD card it sits next to the built-in one as `ext.hellosq`.

## What it teaches

- `main.nut` returns a class instance; `import("clock")` loads the second file
- `net.json(url, function(data, err) {...})`; `this` is the app inside callbacks (`network` permission)
- `foreach`, lambdas (`@(i, t) !t.done`), `todos.filter`
- `timer.after` / `timer.cancel`, a menu, `ui.alert`

**Controls:** Switch tabs with the segmented control at the top.

## Running it

- **On the console:** copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `hello.nxvapp` (or `python SDK/Tools/nxv/nxv.py push SDK/Samples/squirrel/hello/source --host <console-ip>`) and open it from Launcher. You can also open the folder in Nexvyn OS Studio and press **Run** (Ctrl+R).
- **In Ryujinx:** copy the same folder to `NexvynOS/Applications/` in the emulator's SD card folder.

Files (lines): `clock.nut` (32), `main.nut` (179).

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/squirrel/hello/source

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
