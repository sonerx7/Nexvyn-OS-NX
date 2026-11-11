# DOSBox for Nexvyn OS

Native MS-DOS PC emulator port for Nexvyn OS (`1.3.5+`), powered by **DOSBox Pure** (`1.0-preview8`) and Nexvyn Native SDK `1.2` (`ABI v1`).

| Field | Value |
|---|---|
| App ID | `com.nexvyn.emu.dosbox` |
| Version | `1.0.0` |
| Store Channel / Category | Beta (`Store/Beta/Emulators/pc/dosbox/` → `Store/beta.json`, `kind: "emulator"`, `emuCategory: "pc"`) |
| Runtime | `native` (`aarch64`, windowed / fullscreen `.nxvmod`, Native SDK `1.2`, `ABI v1`) |
| Min Native / SDK | `1.2` / `1.13` (target `1.13`) |
| Permissions | `files` (open DOS files, disc images, and folders via OS file picker or command line) |
| Upstream | [https://codeberg.org/schelling/dosbox-pure](https://codeberg.org/schelling/dosbox-pure) (`1.0-preview8`, commit `519226d15dea41c146048ae43e40bac772b923c4`) |
| License | GNU General Public License v2.0 or later (`GPL-2.0-or-later`) |

## Bring your own DOS software

**No games, BIOS, or proprietary software are included.** Copy your DOS files or packages into `sdmc:/NexvynOS/Roms/dos/` (or any SD card folder), pick a package via **Open Game / Package**, or click **Start MS-DOS Prompt (C:\>)** to launch directly into an interactive command prompt.

- **Supported Formats:** `.zip`, `.dosz`, `.exe`, `.com`, `.bat`, `.iso`, `.cue`, `.chd`, `.img`, `.ima`, `.vhd`, `.jrc`, and `.conf`.
- **Direct Archive Mounting:** ZIP and DOSZ packages are mounted automatically as virtual drives without unpacking.
- **Save States:** 5 independent save state slots with fast save/load from the Pause Overlay or window menu.
- **Multi-Disk Control:** Swap floppy or CD disc images on the fly via the Pause Drawer.

## Features & Nexvyn OS Integration

- **Hardware Emulation:** Cycle-exact Sound Blaster 16, AdLib/OPL3, Gravis Ultrasound, PC Speaker, and MIDI audio mixing at 44.1 kHz via `nxn_audio`.
- **Dynamic Recompiler & Fallback:** Uses `nxn_jit_*` when dynamic code execution is available on Nexvyn OS, with automatic seamless fallback to the Normal x86 interpreter core when JIT is disabled.
- **Native Desktop Window:** OpenGL ES 3.2 rendering with configurable Aspect Fit (4:3), Pixel-Perfect Integer Scaling, Fill Window, Sharp (Nearest) and Smooth (Bilinear) texture filters, full system theme integration (`nxn_ui_tokens`), and Turkish/English translations (`nxn_tr`).
- **Input & Touch:**
  - Controller / Joy-Con automatic button mapping via DOSBox Pure core mapper.
  - Touch mouse with Direct Touch and Trackpad modes.
  - On-Screen Keyboard (DOSBox Pure built-in) and top Quick Touch Bar (`Menu`, `Pause`, `Keyboard`, `Quick Keys`, `Fast Forward`).
  - USB HID Keyboard & Mouse passthrough (`F11` toggles fullscreen, `Ctrl+O` opens file picker).

## Controls

| Input | Launcher | In MS-DOS Session |
|---|---|---|
| **Touch / Mouse** | Click buttons and recent items | Direct touch or trackpad mouse emulation; top Quick Touch Bar |
| **Minus (`-`) / Menu** | Open Settings | Toggle Pause Overlay (Save/Load states 1–5, CD swap, Settings, Exit) |
| **Plus (`+`)** | Open About | Toggle On-Screen Keyboard |
| **Controller Sticks / Buttons** | Navigate UI | Gamepad-to-DOS mapping (arrows, Enter, Space, fire buttons) |
| **USB Keyboard** | Standard navigation | Full 101/104-key DOS keyboard; `F11` toggles fullscreen, `Ctrl+O` opens picker |

## Licence and credits

| Part | Licence | Source |
|---|---|---|
| DOSBox Pure 1.0-preview8 (emulation core) | GPL-2.0-or-later | https://codeberg.org/schelling/dosbox-pure (commit `519226d15dea41c146048ae43e40bac772b923c4`) |
| DOSBox (base core) | GPL-2.0-or-later | https://www.dosbox.com/ (The DOSBox Team) |
| Dear ImGui 1.91.5 (interface) | MIT | https://github.com/ocornut/imgui |
| Icon | GPL-2.0-or-later | Original DOSBox Pure project icon (`images/logo.png`) |
| Frontend and Nexvyn OS window port | GPL-2.0-or-later | Nexvyn OS Native Kit sources of this port |

Full licence texts are bundled in `data/licenses/` (`DOSBOX_PURE_LICENSE.txt`, `DOSBOX-AUTHORS.txt`, `DOSBOX-THANKS.txt`, `IMGUI_LICENSE.txt`, `THIRD_PARTY_NOTICES.md`).

## Versions

| Version | Date | Changes |
|---|---|---|
| `1.0.0` | 2026-11-11 | Initial release in the Beta channel: windowed native port, JIT recompiler + interpreter fallback, Touch Bar & Quick Keys, Save States, multi-disk switcher, and authentic DOSBox Pure icon. |
