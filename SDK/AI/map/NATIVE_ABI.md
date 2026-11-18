# NATIVE_ABI

## Purpose
Defines the frozen C-only Native ABI v1 boundary, struct versioning, capability discovery, and manifest compatibility rules for `.nxvmod` native modules.

## Keys
| symbol/function | header or module | one-line meaning |
|---|---|---|
| `NXN_ABI_VERSION` | `nexvyn_native.h` | Frozen ABI family constant (`1`) |
| `NXN_ABI_GEN` | `nxn_base.h` | Binary ABI generation (`1`), raised only on incompatible changes |
| `NXN_VERSION_MAJOR` / `MINOR` | `nxn_base.h` | Native header version (`1.2`, `NXN_VERSION_STRING` `"1.2"`) |
| `NXN_STRUCT_INIT(type)` | `nxn_base.h` | Zero-initializes a versioned struct and sets its leading `size` field |
| `nxn_result` / `NXN_OK` | `nxn_base.h` | Status codes (`NXN_ERR_INVALID`..`NXN_ERR_LIMIT`, negative on error) |
| `nxn_init` / `nxn_shutdown` | `nxn_app.h` | Initializes/tears down native runtime (already called before `main` in `.nxvmod`) |
| `nxn_run` | `nxn_app.h` | Recommended entry wrapper with crash guard and clean shutdown |
| `nxn_should_quit` | `nxn_app.h` | Per-frame quit check; also signals liveness to watchdog |
| `nxn_request_return` | `nxn_app.h` | Sets return reason (`NXN_RETURN_*`) and triggers `nxn_should_quit()` |
| `nxn_caps_get` / `nxn_caps` | `nxn_app.h` | Queries `abi_gen`, native version, `features` (`NXN_CAP_*`), and GL/GLES ceilings |
| `nxn_capability_query` | `nxn_caps.h` | Header-only inline query (`NXN_QUERY_*` -> `NXN_OK` or `NXN_ERR_UNSUPPORTED`) |
| `nxn_info_get` / `nxn_info_string` | `nxn_app.h` | Reads hosted flag, theme, accent, confirm/cancel masks, and `NXN_INFO_*` strings |
| `nxn_last_error` | `nxn_app.h` | Per-thread error string for `NXN_ERR_SYSTEM` / `NXN_ERR_IO` |
| `nxn_app_exit` / `nxn_app_info` | `nxn_app_api.h` | Generated C module helpers (`nxn_app_language`, `nxn_app_theme`) |
| `minNative` | `app.json` | Minimum Native SDK version required by the module (separate from `minSdk`) |

## Rules
- C ABI boundary only; no C++ types, exceptions, or `thread_local` may cross `nxn_*` calls.
- Every versioned struct starts with `uint32_t size`; always initialize with `NXN_STRUCT_INIT(type)`.
- Handles (`nxn_display*`, `nxn_audio*`, `nxn_thread*`, `nxn_stream*`, `nxn_jit*`) are opaque; caller owns input buffers, library owns returned `const char*`.
- ABI v1 (`sdk/native/toolchain/nxn_abi_v1.json`) is append-only; new functions or struct fields (appended at the end, never into padding) require raising `minNative` in `app.json`.
- Check `nxn_caps_get` (`NXN_CAP_*`, `uint64_t` masks) or `nxn_capability_query` before optional calls and always provide a fallback.
- Windowed/fullscreen native apps are in-process `.nxvmod` modules with no kernel memory isolation.

## Pitfalls
- Confusing `minNative` (Native SDK version, e.g. `"1.2"`) with `minSdk` (script SDK version, e.g. `"1.10"`+ required for native packages).
- Treating `nxn_caps` flags or GL ceilings as hardware guarantees; they are runtime advertisements—always check actual operation results.
- Comparing `ngfx_*` (`NGFX_ERR_*`) return codes against `NXN_ERR_*` values (they are separate enums).
- Omitting `NXN_STRUCT_INIT` or passing `size = 0`, causing `NXN_ERR_INVALID` or fallback defaults.

## See also
- [INDEX](INDEX.md)
- [SYSTEM](SYSTEM.md)
- [LIFECYCLE_WINDOW](LIFECYCLE_WINDOW.md)
- [PACKAGING](PACKAGING.md)
