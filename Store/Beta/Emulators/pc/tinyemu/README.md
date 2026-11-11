# TinyEMU for Nexvyn OS

TinyEMU is Fabrice Bellard's compact RISC-V (32/64/128-bit) system emulator, ported as a Nexvyn OS windowed native application (`.nxvmod`, Native SDK 1.2).

| Field | Value |
|---|---|
| App ID | `com.nexvyn.emu.tinyemu` |
| Store Channel / Category | Beta (`Store/Beta/Emulators/pc/tinyemu` -> `Store/beta.json`, `emuCategory: "pc"`) |
| Runtime | `native` (`aarch64`, windowed / fullscreen `.nxvmod`) |
| Min Native / SDK | `1.2` / `1.10` (target `1.13`) |
| Permissions | `files` (open disk/kernel/config images and 9P shared folders), `network` (optional SLIRP user-mode guest networking) |
| Upstream | [https://bellard.org/tinyemu/](https://bellard.org/tinyemu/) (`tinyemu-2019-12-21.tar.gz`) |
| License | MIT (TinyEMU & Dear ImGui), BSD-2-Clause / BSD-3-Clause (SLIRP) |

## Features

- **RISC-V 32 / 64 / 128-bit ISA (`RV128IMAFDQC`)**: Full soft-float, compressed instructions, CLINT, PLIC, and HTIF.
- **Built-in VT100/ANSI Terminal**: 2000-line scrollback, 16/256-color SGR, alternate screen buffer (`vim`, `htop`, `nano`), copy/paste via OS clipboard, quick terminal keys, and on-screen keyboard support.
- **SimpleFB Graphical Output & VirtIO Input**: Hardware-accelerated OpenGL ES 3.2 display with aspect-ratio scaling, linear/nearest filtering, touch/mouse tablet pointer, and USB keyboard mapping.
- **VirtIO Devices**: Console, Block Device (`Snapshot`, `Read-Only`, `Read-Write`), 9P Host Directory Sharing, and optional SLIRP user-mode networking (gated by the `network` permission).
- **Non-blocking Worker Thread**: CPU emulation and disk/network I/O run on a dedicated `nxn_thread` worker while the UI stays responsive at 60 Hz.
- **No Proprietary Content**: Ships with zero BIOS, firmware, ROMs, or OS images. Users pick their own images or `.cfg` files from the SD card.

## Runtime Choice

`native` (`.nxvmod`, Native SDK 1.2) is required because TinyEMU is a C system emulator executing guest RISC-V instructions at high cycle rates (`__int128` 128-bit arithmetic, OpenGL ES 3.2 framebuffer upload, POSIX 9P/SLIRP compatibility via `libnexvyn_compat`).

## Controls

- **Touch / Mouse**: Navigate UI, tap quick keys, scroll terminal, or interact with SimpleFB graphical guests.
- **USB Keyboard**:
  - In **Console**: Sends printable UTF-8 text and VT100 control sequences (`Ctrl+A..Z`, `Esc`, `Tab`, `Arrows`, `F1..F12`, `Home/End/PgUp/PgDn`).
  - In **Display**: Translates USB HID keys to Linux `evdev` scancodes for `virtio-input`.
  - `F11`: Toggle fullscreen / windowed mode.
- **Controller / Joy-Con**: D-Pad + Confirm (`A`) / Cancel (`B`) navigate menus, buttons, and tabs.

## Building & Packaging

```powershell
python Beta/Emulators/pc/tinyemu/build.py
```

`fetch.py` downloads and verifies `tinyemu-2019-12-21.tar.gz` (SHA-256 pinned), applies `patches/*.patch`, compiles `tinyemu.nxvmod` inside `build/` using devkitA64 (without modifying `_NexvynSDK/`), checks ELF/TLS/host imports (`nxwin_imports.txt`), and produces `build/tinyemu.nxvapp`.
