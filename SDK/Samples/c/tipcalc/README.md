# Tip Splitter (C)

**English** · [Türkçe](README.tr.md)

A small tool that works out the tip, the total and each person's share of a bill, and shares the result.

| | |
|---|---|
| Id | `com.sonerx7.sample.tipcalc` |
| Language | C (TinyCC, compiled on the console) |
| Min SDK | 1.5 |
| Permissions | none |
| Gamepad | cursor |
| Window | 520 × 410, fixed |

## What it teaches

- `ui_textfield` editing a `char` buffer in place with the `numeric` flag; a decimal comma and `strtod`
- `ui_segmented` with labels built in a loop, `ui_slider`, `ui_toggle`, `ui_iconButton`
- settings-style rows with `ui_group` + `ui_separator`, `ceil` from `math.h`
- the last values with `store_setStr/Num/Bool`, `TR3` + `sys_share`

**Controls:** Touch, cursor or keyboard.

## Running it

- **On the console:** copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `tipcalc.nxvapp` (or `python SDK/Tools/nxv/nxv.py push SDK/Samples/c/tipcalc/source --host <console-ip>`) and open it from Launcher. You can also open the folder in Nexvyn OS Studio and press **Run** (Ctrl+R).
- **In Ryujinx:** copy the same folder to `NexvynOS/Applications/` in the emulator's SD card folder.
- **C:** no build step; the `.c` files are compiled on the console when the app opens. A C app installed from the SD card asks for consent once.

Files (lines): `main.c` (139).

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/c/tipcalc/source

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
