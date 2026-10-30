# Dice Roller (Java)

**English** · [Türkçe](README.tr.md)

Roll one to six dice from d4 to d20, hold some, see your last twelve rolls.

| | |
|---|---|
| Id | `com.sonerx7.sample.dice` |
| Language | Java 8 (miniJVM) |
| Min SDK | 1.5 |
| Permissions | none |
| Gamepad | cursor |
| Window | 560 × 520, resizable |

## What it teaches

- `update()` only does work during the roll animation
- `java.util.Random`, arrays, `Ui.segmented` with a `String[]`
- `Ui.hit(...)` → `Record`; `hit.bool("clicked")`
- a list of `Record`s in `Store` (the history)
- `Menu.bar` with a disabled item, `Audio.tone`, `Sys.vibrate`

**Controls:** Space / Enter: roll · tap a die: hold / release.

## Running it

- **On the console:** copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `dice.nxvapp` (or `python SDK/Tools/nxv/nxv.py push SDK/Samples/java/dice/source --host <console-ip>`) and open it from Launcher. You can also open the folder in Nexvyn OS Studio and press **Run** (Ctrl+R).
- **In Ryujinx:** copy the same folder to `NexvynOS/Applications/` in the emulator's SD card folder.
- **Java:** after changing `src/`, rebuild `app.jar` on a PC: `python tools/java_build.py app SDK/Samples/java/dice/source` (JDK 8+; or `python SDK/Tools/nxv/nxv.py build SDK/Samples/java/dice/source`).

Files (lines): `src/dice/DiceApp.java` (175).

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/java/dice/source

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
