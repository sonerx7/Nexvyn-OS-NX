# RA2 Yuri Port — Beta 1.2.0

Native Command & Conquer: Red Alert 2 & Yuri's Revenge static recompilation port for Nexvyn OS (Native SDK 1.2), featuring a full system-themed native launcher, fast MIX I/O caching, Auto system language + Turkish RA2.CSF overlay, Auto Dock/Handheld resolution, live FPS HUD, customizable RTS camera controls, and an in-game OS menu bar.

| Field | Value |
|---|---|
| App ID | com.sonerx7.redalert2 |
| Version | 1.2.0 |
| Channel | App Market Beta (kind: port, strategy) |
| Runtime | Native .nxvmod, Native SDK 1.2 (	argetSdk: 1.15, minOs: 1.3.26) |
| Launcher Languages | English, Turkish, German, Spanish, French, Japanese, Korean, Chinese |
| Upstream | [redalert2-recomp](https://github.com/sp00nznet/redalert2-recomp), [pcrecomp](https://github.com/sp00nznet/pcrecomp) |
| License | MIT (original game files are not included) |

## Setup
Open the launcher and select your installed Yuri's Revenge game folder (gamemd.exe, 
a2.mix, 
a2md.mix, langmd.mix / langmd_eng.mix, and remaining game files). The launcher validates required files and PE timestamp before launching.

## What's New in 1.2.0
- **Fast MIX I/O Cache:** In-RAM caching for small files (<= 8 MB), 256 KB read-ahead window for large .mix archives, and 0-syscall seek/size to reduce Switch loading times.
- **Auto System Language & Turkish Patch:** Defaults to Nexvyn OS language; redirects English/Turkish modes to langmd_eng.mix / language_eng.mix when present and overlays bundled RA2.CSF without modifying original files.
- **Auto Dock / Handheld Resolution:** Optional toggle (off by default) switching between 1920x1080 (Docked) and 1280x720 (Handheld).
- **Live FPS Counter (HUD):** Toggleable from Launcher or in-game OS menu bar (View -> Show FPS Counter (HUD)).
- **3-Tab Controls & In-Game OS Menu Bar:** Full Gamepad (Y/L/R/L3/R3 remapping, Right Stick & D-Pad pan), Touchscreen (2-finger drag pan), and Keyboard & Mouse (WASD pan, confine pointer) configuration plus tactical actions and live I/O cache stats in the OS menu bar.
