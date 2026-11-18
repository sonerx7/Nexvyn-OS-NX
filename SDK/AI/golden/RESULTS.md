# Golden project verification

Each golden project was checked with this kit on a PC (2026-11-18). Script projects ran the PC-side checks only
(the headless runtime checker needs `--sdk`). No project was run on a device in this round.

| Project | Recipe | Commands | Result |
|---|---|---|---|
| script-utility | script-app, productivity-app | `nxv.py check`, `nxv.py pack` | PASS (`ok ... (lua)`, packed) |
| script-network | script-app | `nxv.py check`, `nxv.py pack` | PASS (`ok ... (javascript)`, packed) |
| game-2d | 2d-game | `nxv.py check`, `nxv.py pack` | PASS (`ok ... (lua)`, packed) |
| native-app | productivity-app | `nxv_native build`, `check-win`, `check-design`, `package` | PASS (965336-byte module, design 0 FAIL 0 WARN) |
| native-game3d | 3d-game | same | PASS (135352 bytes, design ok) |
| native-port | port | same | PASS (6712 bytes, design ok) |
| native-emu | emulator-port | same | PASS (272992 bytes, design ok) |
| native-tool | tool | same | PASS (7952 bytes, design ok) |

Script projects live in `SDK/AI/golden/`; native projects live in `SDK/Samples/c/golden/` (C/C++ sources stay in the C SDK subtree).

All projects ship complete `lang/` tables for `en tr de es fr ja ko zh`.

Commands (native ones from `SDK/Languages/c/native-kit`):

```sh
python SDK/Tools/nxv/nxv.py check SDK/AI/golden/<project>
python SDK/Tools/nxv/nxv.py pack  SDK/AI/golden/<project> -o <out>.nxvapp
python tools/nxv_native build        <abs>/SDK/AI/golden/<project>
python tools/nxv_native check-win    <abs>/SDK/AI/golden/<project>/build/<project>.nxvmod
python tools/nxv_native check-design <abs>/SDK/AI/golden/<project>
python tools/nxv_native package      <abs>/SDK/AI/golden/<project>
```

Build outputs are not committed; rebuild with the commands above.
