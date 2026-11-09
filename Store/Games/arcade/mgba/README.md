# mGBA

A fast, accurate GBA emulator running in a Nexvyn OS window (Native SDK 1.1). It is a separate program installed on its
own; it is not part of Nexvyn OS.

## What is inside

| Part | Licence | Source |
|---|---|---|
| mGBA 0.10.5 (emulation core, unmodified) | MPL-2.0 | https://github.com/mgba-emu/mgba (tag `0.10.5`, commit `26b7884bc25a`) |
| blip_buf (sound resampler, part of mGBA) | LGPL-2.1-or-later | https://github.com/mgba-emu/mgba/tree/0.10.5/src/third-party/blip_buf |
| inih (settings reader, part of mGBA) | BSD-3-Clause | https://github.com/benhoyt/inih |
| The window frontend (`main.c`) and the build files | MPL-2.0 | Nexvyn OS Native Kit sources of this port |

mGBA's own source files are not changed (0 patched lines). The package carries the licence texts in `data/licenses/`.

## Bring your own

**No games and no BIOS are included, and none is needed.** At the first start the app opens a file picker: choose your
own game file (`.gba`). A copy is kept as `rom.gba` in the app's data folder
(`Users/<user>/Library/Application Support/com.nexvyn.port.mgba`), with its battery save `rom.sav` and save state
`state.ss0`. To play another game, remove `rom.gba` and `rom.sav` from that folder; the picker opens again at the next
start. Only play games you legally own.

## Controls

`A` and `B`, `+` = Start, `-` = Select, D-pad, `L` and `R`; `X` writes a save state, `Y` loads it; hold `ZL` for 4x fast
forward.
