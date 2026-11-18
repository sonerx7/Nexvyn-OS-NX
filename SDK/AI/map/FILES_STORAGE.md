# FILES_STORAGE

## Purpose
Covers app-scoped file paths (`nxn_fs_*`, `fs.*`), large read-only asset streaming (`nxn_stream_*`), folder grants, save data backups, and key-value `store`.

## Keys
| symbol/function | header or module | one-line meaning |
|---|---|---|
| `nxn_dir` (`NXN_DIR_DATA`/`CACHE`/`BUNDLE`) | `nxn_fs.h` | App-scoped folders: persistent data, clearable cache, read-only bundle |
| `nxn_fs_path` / `nxn_fs_mkdirs` | `nxn_fs.h` | Resolves full path for stdio/POSIX or creates subdirectories in writable dir |
| `nxn_fs_read` / `nxn_fs_write` | `nxn_fs.h` | Serialized whole-file read and recoverable replacement write (denied on bundle) |
| `nxn_stream_open` / `nxn_stream_close` | `nxn_stream.h` | Opens/closes read-only stream using shared system block cache (`NXN_CAP_STREAM`) |
| `nxn_stream_read` / `NXN_STREAM_NOWAIT` | `nxn_stream.h` | Reads `[offset, offset+len)`; `NOWAIT` returns `NXN_ERR_BUSY` if uncached |
| `nxn_stream_prefetch` | `nxn_stream.h` | Advisory background prefetch hint (`NXN_ERR_BUSY` if admission budget full) |
| `nxn_pick` / `NXN_PICK_REMEMBER` | `nxn_sys.h` | OS open/save/folder picker; `REMEMBER` persists folder grant (`NXN_CAP_PICKER`) |
| `nxn_grant_get` / `check` / `revoke` | `nxn_sys.h` | Enumerates, checks, and revokes persisted user-granted folders |
| `nxn_save_path` / `backup` / `restore` | `nxn_sys.h` | Per-user `<data>/save` folder and `Library/Backups/<id>/<slot>` (`NXN_CAP_SAVEDATA`) |
| `nxn_save_backup_get` / `delete` | `nxn_sys.h` | Lists (by index) and deletes named save backup slots (`1..48` chars) |
| `fs.*` (`read`, `readBytes`, `write`, `unzip`) | `fs` (Script) | Script file I/O, `"bundle:/..."` reads, background `fs.unzip`, and `fs.save*` |
| `store.get` / `store.set` / `store.save` | `store` (Script) | Auto-persisted JSON-like key-value store (flushed on suspend/autosave/close) |

## Rules
- Native `nxn_fs_*` and `nxn_stream_*` relative paths reject escaping the app directory (`..`, leading `/`, or drive prefixes return `NXN_ERR_DENIED`).
- Reserve `.tmp` and `.nxn-old~` siblings for `nxn_fs_write` recoverable replacement; do not assume power-loss fsync durability.
- Use `NXN_STREAM_NOWAIT` on render/audio threads and retry `NXN_ERR_BUSY` on a later frame; never spin on `BUSY`.
- `nxn_stream_prefetch` is advisory only, not a completion signal; keep the stream open until in-flight reads return before calling `nxn_stream_close`.
- Save backup slot names must be `1..48` characters of `A-Z a-z 0-9 . _ -` (not `.` or `..`); run `nxn_save_*` on a worker thread.
- Script `fs` paths outside app folders require `"files"` permission unless picked via `ui.openFile` / `ui.saveFile` / `ui.chooseFolder`.

## Pitfalls
- Treating `nxn_stream_prefetch` returning `NXN_OK` as meaning bytes are immediately cached, or loading the whole asset as a fallback on `NXN_ERR_BUSY`.
- Calling `nxn_fs_write` on `NXN_DIR_BUNDLE` (always returns `NXN_ERR_DENIED`).
- Mixing raw stdio access through `nxn_fs_path` concurrently with `nxn_fs_write` (raw readers bypass the helper serialization lock).

## See also
- [INDEX](INDEX.md)
- [SYSTEM](SYSTEM.md)
- [SCRIPT_SDK](SCRIPT_SDK.md)
- [PACKAGING](PACKAGING.md)
