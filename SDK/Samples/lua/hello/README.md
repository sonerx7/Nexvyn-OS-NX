# Hello SDK

**English** · [Türkçe](README.tr.md)

The built-in **Hello SDK** app: live widgets, animated drawing and system information on three tabs.

| | |
|---|---|
| Id | `hello` |
| Language | Lua 5.4 |
| Min SDK | 1.0 |
| Permissions | `notifications`, `launch` |
| Gamepad | cursor |
| Window | 560 × 420, fixed |

> This is a copy of the sample that ships with Nexvyn OS (id `hello`); installed from the SD card it sits next to the built-in one as `ext.hello`.

## What it teaches

- `ui.textfield` (Enter = submitted), `ui.slider`, `ui.toggle`, `ui.segmented`, `ui.button`
- an `ui.alert` callback and `sys.notify` (`notifications` permission)
- drawing animated every frame with `gfx.gradient`, `gfx.shadow`, `gfx.arc`, `gfx.icon`
- `sys.date`, `sys.battery`, `sys.online`, `sys.model`, `sys.firmware`, `sys.lang`
- clicks and the name kept with `store`; `sys.launch` from the menu (`launch` permission)

**Controls:** Left / right arrow: switch tabs.

## Running it

- **On the console:** copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `hello.nxvapp` (or `python SDK/Tools/nxv/nxv.py push SDK/Samples/lua/hello/source --host <console-ip>`) and open it from Launcher. You can also open the folder in Nexvyn OS Studio and press **Run** (Ctrl+R).
- **In Ryujinx:** copy the same folder to `NexvynOS/Applications/` in the emulator's SD card folder.

Files (lines): `main.lua` (122).

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/hello/source

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
