# C&C Generals: Zero Hour Port (Nexvyn OS)

A native AArch64 static recompilation port of *Command & Conquer Generals: Zero Hour* (SAGE Engine) for Nexvyn OS (Native SDK 1.1 / ABI v1).

| Field | Value |
|---|---|
| App ID | `com.sonerx7.cncgenerals` |
| Store Name | `C&C Generals: Zero Hour` |
| Channel / Category | Beta (`Beta/Ports/cncgenerals`, `kind: "port"`) |
| Runtime | `native` (`aarch64`, windowed `.nxvmod`) |
| Min SDK / Native | `1.10` / `1.1` (target `1.12`) |
| Permissions | `files` (SD card game data access) |
| Upstream | [sp00nznet/pcrecomp](https://github.com/sp00nznet/pcrecomp) (Win32 HLE + D3D8 -> GLES bridge) |
| License | MIT (Recompilation engine & host wrappers) |

---

## Important Notice (Bring Your Own Game Files)

This package contains **only** the open-source static recompilation engine and Nexvyn OS native host bridge (`cncgenerals.nxvmod`). **No proprietary or commercial game assets (`.big`, `game.dat`, `.dll`) are included.** You must provide your own legally owned copy of *Command & Conquer: Generals — Zero Hour* (v1.04).

---

## Installation Guide

### Required Game Files

From your PC Zero Hour 1.04 installation folder, locate the following files:

1. **Main Executable / Data:**
   - `game.dat` (PE Timestamp `0x4230C05B`, ImageBase `0x00400000`, v1.04)
2. **Core BIG Archives:**
   - `INIZH.big`, `MapsZH.big`, `MusicZH.big`
   - `Patch1.big` .. `Patch4.big`
   - `SpeechEnglishZH.big` (or localized speech)
   - `TerrainZH.big`, `TexturesZH.big`, `WindowZH.big`
   - `W3DZH.big`
3. **Data Folders:**
   - `Data/INI/`, `Data/English/` (or localized data)

### Installation Steps

1. Install **C&C Generals: Zero Hour** package on your Nexvyn OS system.
2. Connect your Nintendo Switch SD card to your computer, or open the Nexvyn OS Files app.
3. Open the installed application folder:
   ```text
   sdmc:/NexvynOS/Applications/com.sonerx7.cncgenerals.nxvapp/gamefiles/
   ```
   *(Alternative search path: `sdmc:/switch/cncgenerals/`)*
4. Copy all required `.big` archives and `game.dat` into this `gamefiles/` folder.
5. Launch the game from the Launcher or Desktop!

---

## Controls

- **Left Analog Stick:** Smooth mouse cursor emulation
- **A / ZR:** Left mouse click (select unit, issue order, place structure)
- **B / ZL:** Right mouse click (cancel order, deselect)
- **D-Pad:** Pan map viewport
- **Touch Screen:** Direct touch tap and drag
- **Plus (+):** Open in-game options menu / pause
