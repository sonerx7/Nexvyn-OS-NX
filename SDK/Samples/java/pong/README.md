# Pong (Java)

**English** · [Türkçe](README.tr.md)

Pong against the console, first to 7, on a court that scales to any window size.

| | |
|---|---|
| Id | `com.sonerx7.sample.pong` |
| Language | Java 8 (miniJVM) |
| Min SDK | 1.5 |
| Permissions | none |
| Gamepad | goes to the app (L+R: cursor) |
| Window | 800 × 450, resizable |

## What it teaches

- `"gamepad": true`, `Input.stick("left")` and `Input.down("up")` every frame
- key state kept from `keydown` / `keyup` events
- dragging the paddle with `Ui.mouse()` and `Ui.hit`
- a 640×360 virtual court, `Gfx.push` and a scale factor
- pausing in `suspend()` and `focus(false)`, wins in `Store`

**Controls:** Stick / D-pad / arrows / W-S: paddle · A, Enter, Space, tap: serve · +, Esc, P: pause.

## Running it

- **On the console:** copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `pong.nxvapp` (or `python SDK/Tools/nxv/nxv.py push SDK/Samples/java/pong/source --host <console-ip>`) and open it from Launcher. You can also open the folder in Nexvyn OS Studio and press **Run** (Ctrl+R).
- **In Ryujinx:** copy the same folder to `NexvynOS/Applications/` in the emulator's SD card folder.
- **Java:** after changing `src/`, rebuild `app.jar` on a PC: `python tools/java_build.py app SDK/Samples/java/pong/source` (JDK 8+; or `python SDK/Tools/nxv/nxv.py build SDK/Samples/java/pong/source`).

Files (lines): `src/pong/PongApp.java` (202).

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/rt_check.py <Nexvyn-OS-NX>/SDK/Samples/java/pong/source

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
