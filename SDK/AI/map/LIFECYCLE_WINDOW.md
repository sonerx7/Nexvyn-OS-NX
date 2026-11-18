# LIFECYCLE_WINDOW

## Purpose
Covers native event polling (`nxn_event_poll`), suspend/resume, focus loss, window/fullscreen modes (`nxn_window.h`), `liveResize`, and `NXN_ERR_BUSY` handling.

## Keys
| symbol/function | header or module | one-line meaning |
|---|---|---|
| `nxn_event_poll` / `nxn_event` | `nxn_event.h` | Drains queued OS events (`RESIZE`, `QUIT`, `FOCUS`, `DOCK`, `SUSPEND`, `RESUME`, `THEME`, `MENU`, `POWER`, `LANGUAGE`) |
| `NXN_EVENT_RESIZE` | `nxn_event.h` | Content size changed (window resize, fullscreen toggle, or dock); same-type events merge |
| `NXN_EVENT_QUIT` | `nxn_event.h` | Close requested; `nxn_should_quit()` becomes true—save and exit within 5 s |
| `NXN_EVENT_FOCUS` | `nxn_event.h` | Window gained (`focused = 1`) or lost (`0`, incl. minimized) focus; cancel captures on loss |
| `NXN_EVENT_SUSPEND` / `RESUME` | `nxn_event.h` | Sleep/background (`NXN_CAP_POWER_EVENTS`): pause work/audio; on resume check clocks/net |
| `NXN_EVENT_DOCK` / `POWER` | `nxn_event.h` | Docked/handheld output change (`DOCK`) and battery/online change (`POWER`, `minNative` 1.2) |
| `NXN_EVENT_THEME` / `LANGUAGE` | `nxn_event.h` | Appearance or locale changed; re-read `nxn_ui_tokens_get` / `nxn_app_language` |
| `nxn_window_set_title` | `nxn_window.h` | Sets `"title - subtitle"` (`NXN_CAP_WINDOW_CTL`, max `NXN_WINDOW_TITLE_MAX` 200 bytes) |
| `nxn_window_set_mode` | `nxn_window.h` | Requests `NXN_WIN_NORMAL`, `MAXIMIZED`, or `FULLSCREEN` (`NXN_EVENT_RESIZE` follows) |
| `nxn_window_set_modified` | `nxn_window.h` | Sets/clears OS unsaved-work indicator and quit confirmation prompt |
| `liveResize` | `app.json` | Native 2.0 default or opt-in (`"liveResize": true`) for coalesced live resize events |
| `NXN_ERR_BUSY` | `nxn_base.h` | Resource temporarily busy (e.g. `nxn_display_resize`, `nxn_dialog`, `nxn_stream_*`) |

## Rules
- Initialize `nxn_event e = NXN_STRUCT_INIT(nxn_event)` before every `nxn_event_poll(&e)` call and drain the queue once per frame on one consumer thread.
- Call `nxn_should_quit()` every frame (processes OS/applet messages and signals liveness); return from `app_main` within 5 s of `NXN_EVENT_QUIT`.
- On `NXN_EVENT_SUSPEND`: save state and stop heavy work; Nexvyn OS mutes app audio and skips `nxn_display_swap` readback until `NXN_EVENT_RESUME`.
- On `NXN_EVENT_RESIZE` (including `liveResize`): call `nxn_display_resize`, keep UI state, and do not recreate the ImGui context or font atlas on dimension changes.
- Never spin on `NXN_ERR_BUSY` in render or audio loops; defer and retry on a later frame.
- Use actual `e.width` / `e.height` from `NXN_EVENT_RESIZE` / `DOCK` rather than inferring dimensions from `e.docked`.

## Pitfalls
- Forgetting `NXN_EVENT_MENU` requires `"minNative": "1.1"`+, and `NXN_EVENT_POWER` requires `"minNative": "1.2"`+.
- Not forwarding `NXN_EVENT_FOCUS` / `SUSPEND` / `RESUME` / `QUIT` to `nxn_imgui_input_event` in ImGui apps, leaving keys/edits stuck.
- Assuming `nxn_window_set_mode(NXN_WIN_MAXIMIZED)` works when `app.json` sets `"resizable": false` (it is ignored).

## See also
- [INDEX](INDEX.md)
- [GRAPHICS](GRAPHICS.md)
- [INPUT](INPUT.md)
- [PACKAGING](PACKAGING.md)
