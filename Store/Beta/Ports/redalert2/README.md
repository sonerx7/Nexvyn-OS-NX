# RA2 Yuri Port (Command & Conquer: Red Alert 2 & Yuri's Revenge)

A native AArch64 static recompilation port of *Command & Conquer: Red Alert 2* and *Yuri's Revenge* for Nexvyn OS (Native SDK 1.1 / ABI v1).

| Field | Value |
|---|---|
| App ID | `com.sonerx7.redalert2` |
| Store Name | `RA2 Yuri Port` |
| Channel / Category | Beta (`Store/Beta/Ports/redalert2` -> `Store/beta.json`, `kind: "port"`) |
| Runtime | `native` (`aarch64`, windowed `.nxvmod`) |
| Min SDK / Native | `1.10` / `1.1` (target `1.13`) |
| Permissions | `files` (SD card game data access) |
| Upstream | [sp00nznet/redalert2-recomp](https://github.com/sp00nznet/redalert2-recomp) & [pcrecomp](https://github.com/sp00nznet/pcrecomp) |
| License | MIT (Recompilation engine & host wrappers) |

---

## Important Notice (Bring Your Own Game Files)

This package contains **only** the open-source static recompilation engine and Nexvyn OS native host bridge (`ra2.nxvmod`). **No proprietary or commercial game assets (`.mix`, `.exe`, `.dll`) are included.** You must provide your own legally owned copy of *Command & Conquer: Red Alert 2 - Yuri's Revenge* (v1.001, e.g., from EA App or Steam).

---

## Installation Guide

### Required Game Files

From your PC Yuri's Revenge installation folder, locate the following files:

1. **Main Executable:**
   - `gamemd.exe` (PE Timestamp `0x3BDF544E`, version 1.001)
2. **Core MIX Archives:**
   - `ra2md.mix`, `ra2.mix`
   - `language.mix`, `langmd.mix` (or `langmd_eng.mix`)
   - `theme.mix`, `thememd.mix`
   - `multimd.mix`, `multi.mix`
   - `mapsmd03.mix`, `maps01.mix`, `maps02.mix`
   - `expandmd01.mix`
3. **Configuration & Support:**
   - `ra2md.ini`, `ra2.ini`
   - `Blowfish.dll`, `Binkw32.dll`

### Installation Steps

1. Install **RA2 Yuri Port** from the Nexvyn OS App Market (Beta tab).
2. Connect your Nintendo Switch SD card to your computer, or open the Nexvyn OS Files app.
3. Open the installed application folder:
   ```text
   sdmc:/NexvynOS/Applications/com.sonerx7.redalert2.nxvapp/game/
   ```
   *(Alternative search path: `sdmc:/switch/openra2/`)*
4. Copy all required game files listed above into this `game/` folder.
5. Launch **RA2 Yuri Port** from the Launcher or Desktop!

---

## Controls

- **Left Analog Stick:** Smooth mouse cursor emulation
- **A / ZR:** Left mouse click (select unit, issue order, place structure)
- **B / ZL:** Right mouse click (cancel order, deselect)
- **D-Pad:** Pan map viewport
- **Touch Screen:** Direct touch tap and drag
- **Plus (+):** Open in-game options menu / pause
