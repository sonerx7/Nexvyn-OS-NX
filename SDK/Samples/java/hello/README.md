# Hello Java

**English** · [Türkçe](README.tr.md)

The built-in **Hello Java** app: a to-do list, an analog clock and live weather JSON.

| | |
|---|---|
| Id | `hellojava` |
| Language | Java 8 (miniJVM) |
| Min SDK | 1.5 |
| Permissions | `network` |
| Gamepad | cursor |
| Window | 640 × 520, fixed |

> This is a copy of the sample that ships with Nexvyn OS (id `hellojava`); installed from the SD card it sits next to the built-in one as `ext.hellojava`.

## What it teaches

- `hello.HelloApp` extends `nexvyn.App`; sources in `src/`, compiled into `app.jar`
- `Net.json(url, (Callback) a -> ...)` (`network` permission)
- `Record` (`str`, `num`, `integer`, `bool`, `rec`), a `List` in `Store`
- `Menu.bar(new Menu(...).item(...).separator())`, `Timer.after`, `Ui.alert`

**Controls:** Switch tabs with the segmented control at the top.

## Running it

- **On the console:** copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `hello.nxvapp` (or `python SDK/Tools/nxv/nxv.py push SDK/Samples/java/hello/source --host <console-ip>`) and open it from Launcher. You can also open the folder in Nexvyn OS Studio and press **Run** (Ctrl+R).
- **In Ryujinx:** copy the same folder to `NexvynOS/Applications/` in the emulator's SD card folder.
- **Java:** after changing `src/`, rebuild `app.jar` on a PC: `python tools/java_build.py app SDK/Samples/java/hello/source` (JDK 8+; or `python SDK/Tools/nxv/nxv.py build SDK/Samples/java/hello/source`).

Files (lines): `src/hello/HelloApp.java` (238).

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/java/hello/source

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
