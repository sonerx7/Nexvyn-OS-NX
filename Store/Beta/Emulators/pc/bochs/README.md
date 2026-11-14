# Bochs x86 / x86-64 PC Emulator for Nexvyn OS

Native AArch64 windowed port (`runtime: "native"`, `mode: "window"`, Native SDK `1.2`, Store Beta channel `Store/Beta/Emulators/pc/bochs/` -> `Store/beta.json`, `kind: "emulator"`, `emuCategory: "pc"`) of **Bochs `REL_3_1_FINAL`**, featuring a Dear ImGui + OpenGL 4.3 Core frontend tuned for the console (`Cortex-A57`, `-O3 -fno-strict-aliasing`).

| Field | Value |
|---|---|
| App ID | `com.nexvyn.emu.bochs` |
| Version | `3.1.1` |
| Store Channel / Category | Beta (`Store/Beta/Emulators/pc/bochs/`, `emuCategory: "pc"`) |
| Workspace Location | `Beta/Emulators/pc/bochs/` |
| Runtime | `native` (`aarch64`, windowed / fullscreen `.nxvmod`) |
| Min Native / SDK | `1.2` / `1.10` (target `1.13`) |
| Permissions | `files` (open disk/ISO/floppy/.bxrc images, create virtual disks, and persist VM profiles/checkpoints), `network` (optional SLIRP user-mode guest networking) |
| Upstream | [bochs-emu/Bochs](https://github.com/bochs-emu/Bochs) (`REL_3_1_FINAL`, commit `30cfd566ecc8deb33e56e801e32b444a7041b6d2`) |
| License | LGPL-2.1-or-later (Bochs & LGPL VGABIOS), LGPL-3.0 / GPL-3.0 (SeaBIOS), MIT (Dear ImGui) |

## Features
- **x86 / x86-64 CPU emulation & console-tuned OS presets:** Configurable CPUs (`i386` .. `corei7_sandy_bridge_2600k`) with curated profiles for MS-DOS/FreeDOS, Win9x (`pentium`, PIIX3/ISA stability), WinXP (`p3_katmai`, `512 MB`, `fastboot`, `imps2`, ES1370/NE2000), ReactOS (`core_duo_t2400_yonah`), lightweight Linux (`core2_penryn_t9600`, E1000), and Win7/10 Lite (`corei7_sandy_bridge_2600k`, `640 MB`, E1000).
- **Bundled open-source firmware:** Ships open-source `BIOS-bochs-latest`, `BIOS-bochs-legacy`, `SeaBIOS 1.16` (`bios.bin-1.16.0`), and LGPL VGA BIOS ROMs (`VGABIOS-lgpl-latest.bin`, `Cirrus`, `Voodoo Banshee`) under `source/data/bios/`, plus custom ROM selection. No proprietary ROMs, commercial BIOS, or OS images are included.
- **Storage, growing disks & data protection:** Dual floppy drives (live swap), primary/secondary ATA disks and CD-ROMs with automatic CHS geometry, instant async Bochs `growing` disk creator up to `32 GiB` + cancellable buffered `flat` RAW creator up to `4095 MiB`, `.bochsrc` import/export, delete confirmations, and mirror backup + external persistent folder (`NXN_PICK_FOLDER | NXN_PICK_REMEMBER`) for VM profiles and checkpoints across OS/app updates.
- **Audio & Networking:** `Sound Blaster 16`, `Ensoniq ES1370`, and PC Speaker audio mixed through `nxn_audio_*`; `SLIRP` NAT and isolated `VNET` networking with `e1000`, `ne2000`, and `pcipnic`.
- **Nexvyn OS integration & input:** Native window menu bar (`nxn_menu_*`), dynamic OS light/dark tokens, bilingual EN/TR UI, OS file/folder picker (`nxn_pick`), full gamepad UI navigation (`L1`/`R1` tab switching, D-Pad/left stick focus, `A`/`B` confirm/cancel), direct touchscreen UI taps & canvas trackpad isolation, physical USB keyboard + mouse capture, and PC on-screen keyboard (`Minus` or toolbar toggle).

## Layout (`STORE_STRUCTURE.md`)
- `source/` — Store-ready `.nxvapp` bundle root (`app.json`, `bochs.nxvmod`, `icon.png`, `lang/`, `data/`)
- `port.json` & `store.json` — Pinned upstream recipe (`REL_3_1_FINAL`) and Store Beta metadata (`kind: "emulator"`, `emuCategory: "pc"`, `beta: true`)
- `src/`, `patches/`, `tests/` — Nexvyn OS frontend, upstream platform patch, and `nxvtest` automation scenario

## Build & Verify
```powershell
python Beta/Emulators/pc/bochs/fetch.py
python Beta/Emulators/pc/bochs/build.py
```

Outputs:
- `build/bochs.nxvmod` (+ `build/bochs.nxvmod.debug`)
- `source/bochs.nxvmod`
- `dist/bochs.nxvapp`
