# Hello JS

**English** · [Türkçe](README.tr.md)

The built-in **Hello JS** app: a to-do list, an analog clock and live weather JSON.

| | |
|---|---|
| Id | `hellojs` |
| Language | JavaScript (QuickJS-ng) |
| Min SDK | 1.1 |
| Permissions | `network` |
| Gamepad | cursor |
| Window | 640 × 520, fixed |

> This is a copy of the sample that ships with Nexvyn OS (id `hellojs`); installed from the SD card it sits next to the built-in one as `ext.hellojs`.

## What it teaches

- ES modules: `todos.js` and `clock.js` loaded with `import`
- `await net.fetchJson(url)` with `try`/`catch` error handling (`network` permission)
- `ui.textfield` + `ui.submitted`, `ui.checkbox`, a `ui.beginScroll` list
- a toast with `setTimeout` / `clearTimeout`
- `app.menu` / `app.onmenu`, the `ui.alert` Promise

**Controls:** Switch tabs with the segmented control at the top.

## Running it

- **On the console:** copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `hello.nxvapp` (or `python SDK/Tools/nxv/nxv.py push SDK/Samples/javascript/hello/source --host <console-ip>`) and open it from Launcher. You can also open the folder in Nexvyn OS Studio and press **Run** (Ctrl+R).
- **In Ryujinx:** copy the same folder to `NexvynOS/Applications/` in the emulator's SD card folder.

Files (lines): `clock.js` (59), `main.js` (195), `todos.js` (47).

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    node tools/js_check.mjs <Nexvyn-OS-NX>/SDK/Samples/javascript/hello/source

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
