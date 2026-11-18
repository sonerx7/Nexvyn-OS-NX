# NETWORK

## Purpose
Maps asynchronous HTTPS requests, WebSockets, OAuth browser sign-in, web image caching, connectivity checks, and native BSD socket permission rules.

## Keys
| symbol/function | header or module | one-line meaning |
|---|---|---|
| `net.get` / `net.post` / `net.json` | `net` (Script) | Async HTTPS GET/POST and GET+JSON decode (`"network"` permission required) |
| `net.download` / `net.encode` | `net` (Script) | Async file download with progress callback and URL percent-encoding |
| `net.request` / `net.cancel` | `net` (Script `1.9+`) | Configurable HTTP (`json`/`form`/`multipart`/`file`/`saveTo`/`cache`/`retry`/`cookies`) |
| `net.clearCookies` / `net.clearCache` | `net` (Script `1.9+`) | Clears app's persistent cookie jar and 32 MB offline HTTP/image disk cache |
| `net.ws` / `wsSend` / `wsPoll` | `net` (Script `1.9+`) | Async WebSocket client (`wsClose`, `wsState`; poll `wsPoll` every frame) |
| `net.oauth` | `net` (Script `1.9+`) | Opens OS browser tab for OAuth 2.0 + PKCE (`http://localhost/...` or `nxv://app/...`) |
| `gfx.imageUrl` / `gfx.imageState` | `gfx` (Script `1.9+`) | Cached async web image loader (call every frame; pass drawn `maxSize`) |
| `sys.online()` | `sys` (Script) | Returns `true` when internet connection is available |
| `nxn_power_get` (`online` field) | `nxn_power.h` | Native connectivity snapshot (`NXN_CAP_POWER_STATE`, `NXN_EVENT_POWER` on change) |
| `nxn_perm_query` / `nxn_perm_request` | `nxn_sys.h` | Checks or re-prompts `"network"` permission (`NXN_CAP_PERMISSIONS`) |
| BSD sockets (`nexvyn_use_compat`) | Native compat | Native sockets gated by `"network"` in `app.json` (returns `EACCES` without it) |

## Rules
- Declare `"network"` in `app.json` `permissions` for both script `net.*` and native BSD sockets; without it, script callbacks get `"permission denied: network"` and native sockets fail with `EACCES`.
- Always check `sys.online()` (or `nxn_power.online`) before network requests and present a friendly offline message.
- Never call `net.*` inside `app.draw`.
- Poll `net.wsPoll(id)` every frame (unread backlog > 16 MB closes the socket; max 4 sockets, 4 MB messages, 64 concurrent `net.request` calls).
- Never embed OAuth client secrets in an app bundle; use `net.oauth` with `pkce = true`.

## Pitfalls
- Expecting WebSockets or in-flight requests to survive sleep/suspend: sockets emit a `close` event after sleep, and `NXN_EVENT_RESUME` notes connections may have dropped.
- Requesting full-resolution `gfx.imageUrl(url)` without `maxSize` for small thumbnails, wasting the shared memory/disk cache.
- Calling `net.request` without `"minSdk": "1.9"` (or `"1.9"` features in C via `net_fetch` JSON options).

## See also
- [INDEX](INDEX.md)
- [SCRIPT_SDK](SCRIPT_SDK.md)
- [SYSTEM](SYSTEM.md)
- [PACKAGING](PACKAGING.md)
