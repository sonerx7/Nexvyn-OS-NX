# nxv

**English** · [Türkçe](README.tr.md)

A single-file command line tool for Nexvyn OS app developers. Python 3.8+ is enough, no extra packages. Given the
path of a Nexvyn OS source checkout with `--sdk` (or the `NEXVYN_SDK` environment variable) it also calls the official
checkers, the Java compiler, the icon painter and the signer.

```
python SDK/Tools/nxv/nxv.py <command> ...          # from the root of this repository
```

## Commands

| Command | Description |
|---|---|
| `new <lang> <name> [--id ID] [--author NAME] [--dir DIR] [--store]` | Copies `SDK/Languages/<lang>/template` as `<Name>.nxvapp` and fills in the `id` (default `com.<author>.<name>`), the name and the author. `--store`: the App Market layout `<slug>/source/` + an empty `store.json`, `README.md`, `screenshots/`. Languages: `lua`, `js`, `py`, `sq`, `c`, `java`. |
| `check <bundle>... [--sdk PATH] [--frames N] [-v]` | `app.json` (id, names, version, category, runtime, `minSdk`, permissions, `shareTargets`, window), the main file, the icon (PNG, 128/256), the Java jar and main class, `lang/*.json`, `TR()` keys, permissions used but not declared, file limits, and, when the bundle is a `source/` folder, `store.json` (five languages, `kind`, `tags`, `shots` steps) and `README.md` / `screenshots/`. With `--sdk` it also runs the language's official checker. |
| `build <bundle> --sdk PATH` | Java: `src/**/*.java` → `app.jar`. The other languages have no build step. |
| `pack <bundle> [-o OUT] [--sign KEY.pem --sdk PATH]` | The same deterministic `.nxvapp` as `Tools/build_store.py` (sorted entries, fixed timestamps, `manifest.sha256`). Default output: `dist/MyApp.nxvapp` next to `MyApp.nxvapp/`, or `<item>/<slug>.nxvapp` for `<item>/source/`. `--sign` calls the checkout's `nxvapp_pack.py`. |
| `icon <glyph> <top color> <bottom color> <out.png> --sdk PATH` | An icon in the built-in style (`make_icon.py`; needs Pillow and numpy). |
| `install <bundle> [--sd ROOT] [--autorun]` | Copies into an SD card folder, by default Ryujinx's (`%APPDATA%/Ryujinx/sdcard`, `~/.config/Ryujinx/sdcard` on Linux/macOS). `--autorun` writes a `NexvynOS/autorun.txt` that opens the app at boot; delete it after testing. |
| `push <bundle> --host IP [--port 5000] [--user U --password P] [--remote /NexvynOS/Applications] [--name NAME] [--packed] [--dry-run]` | Uploads to the FTP server of the console's **Connect to PC** app. Default: the folder as `/NexvynOS/Applications/<slug>.nxvapp/`. `--packed`: one `.nxvapp` file (Nexvyn OS unpacks it at the next start, or install it from Files). If the FTP access area is "home folder only", give the path with `--remote`. `--dry-run` lists without connecting. |

Exit code: 0 success, 1 problems found, 2 wrong usage.

## Notes

- `check` errs on the safe side: a used but undeclared permission is an error, a declared but unused one a warning.
  Dotted keys such as `"common.ok"` may be system strings, so they are only warnings; the official checker run with
  `--sdk` has the final word.
- FTP is not encrypted; use it only on a network you trust. `push` overwrites existing files and does not delete
  extra remote files.
- Tested in this version: `new` (six languages, `--store`), `check` (24 samples + 6 templates, with and without
  `--sdk`), `build` (Java), `pack` (deterministic, the same bytes as `build_store.py`; `--sign`, then `--verify`), `icon`, `install` (into a
  temporary SD folder) and `push --dry-run`. `push` to a real console has not been tested.
