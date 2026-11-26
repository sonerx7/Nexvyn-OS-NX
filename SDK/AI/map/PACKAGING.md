# PACKAGING

## Purpose
Summarizes `.nxvapp` bundle layout, `app.json` and `store.json` fields, icon rules, the 8 required locales, optional signing, and SDK CLI packaging/checking tools.

## Keys
| symbol/function | header or module | one-line meaning |
|---|---|---|
| `id` / `version` / `category` | `app.json` | Reverse-domain ID, version string, and store category (`utilities`, `games`, etc.) |
| `name` / `description` | `app.json` | String or locale map (`"en"` required; all 8 locales required for new products) |
| `runtime` / `main` / `mode` | `app.json` | `"lua"`, `"js"`, `"python3"`/`"python"`, `"native"` (`.nxvmod`, `"mode": "window"`/`"fullscreen"`) |
| `minSdk` / `targetSdk` / `minNative` | `app.json` | Script SDK floor/target (current SDK `"1.16"`; `"2.0"` is only a target marker) and Native SDK floor (use `"1.3"` for 1.3 imports, requires `minSdk >= "1.10"`) |
| `window` (`width`, `height`, `resizable`) | `app.json` | Initial content dimensions, `minWidth`/`minHeight`, and resize flag |
| `gamepad` / `loadingHint` / `liveResize` | `app.json` | Gamepad routing (`L+R` returns cursor), 120 s load grace, and live resize opt-in |
| `fullscreenPause` | `app.json` | `true`: pause the shell compositor while this native app is fullscreen and focused (same as `native.compositorPause`, per app) |
| `permissions` / `fileTypes` / `shareTargets` | `app.json` | Enforced perms (`network`, `files`, `launch`, `notifications`, `games`), open-with, share types |
| `memory` | `app.json` | Optional native heap pre-check in MB (`1..16384`) |
| `kind` / `features` / `players` / `tech` | `store.json` | Optional App Market catalog metadata (`app`/`game`/`port`/`emulator`, input/3d tags) |
| `icon.png` | Bundle root | `256x256` PNG key art (readable at 64 px, subject in central 80%, no flat placeholder) |
| `lang/<code>.json` | Bundle `lang/` | Required 8 locales for new apps: `en`, `tr`, `de`, `es`, `fr`, `ja`, `ko`, `zh` |
| `nxv.py` (`create`, `check`, `pack`) | `SDK/Tools/nxv/` | Creates, validates, and packs `.nxvapp` bundles (optional `--sign key.pem` / `--delta`) |
| `nxv_native` (`new`, `build`, `package`) | `native-kit` | Builds `.nxvmod`/`.nxvlib` (devkitA64 + CMake), runs `check-win`, `check-design`, `package` |
| `nxv_i18n.py --check` | SDK Tools | Validates all 8 locale files for matching keys and `{0}` placeholders |

## Rules
- New packaged apps, games, ports, and launchers must ship complete `lang/{en,tr,de,es,fr,ja,ko,zh}.json` with identical keys and placeholder counts (`nxv_i18n.py --check`).
- Signing (`nxvapp_pack.py --sign key.pem`) covers `manifest.sha256` and is optional for Store packages (unsigned packages are accepted by the Store).
- `nxv create` profiles and RAM budgets: `calculator` (`lua`, 16 MB), `utility` (`lua`, 24 MB), `network` (`js`, 32 MB), `data` (`python`, 48 MB), `game` (`native`, 128 MB), `port` (`native`, 192 MB), `emulator`/`qemu` (`native`, 256 MB); all target 60 fps.
- Command: `python SDK/Tools/nxv/nxv.py create "Name" --profile <p> [--runtime lua|js|python|native] [--dir D] [--recommend-only]` (there is no `--lang` flag; `nxv new <lang> <name>` uses `SDK/Languages` templates).

## Pitfalls
- Omitting `"minSdk": "1.10"`+ in a native `app.json` (the packer refuses native packages without it).
- Passing `--lang` to `nxv.py create` (that flag does not exist; use `--runtime` or `nxv new`).
- Shipping a placeholder flat-glyph icon instead of 256x256 key art for games/store apps.

## See also
- [INDEX](INDEX.md)
- [NATIVE_ABI](NATIVE_ABI.md)
- [SCRIPT_SDK](SCRIPT_SDK.md)
- [SYSTEM](SYSTEM.md)
