# INPUT

## Purpose
Maps unified input polling, semantic actions, multi-touch contacts, USB keyboard/mouse, port input adapters, and Dear ImGui input integration.

## Keys
| symbol/function | header or module | one-line meaning |
|---|---|---|
| `nxn_input_poll` / `nxn_input_state` | `nxn_input.h` | Polls buttons (`NXN_BTN_*`), sticks, `actions` (`NXN_ACT_CONFIRM`/`CANCEL`), and `touch_count` |
| `nxn_input_touch` / `nxn_touch` | `nxn_input.h` | Reads active finger `index` with stable contact `id` and surface pixel `(x, y)` |
| `nxn_input_key_poll` / `nxn_input_key_held` | `nxn_input.h` | 64-deep HID key event FIFO and modifier/key held query (`NXN_CAP_USB_INPUT`) |
| `nxn_input_text` / `nxn_input_text_request` | `nxn_input.h` | UTF-8 typed text drain and on-screen keyboard request (`NXN_CAP_TEXT_REQUEST`) |
| `nxn_input_mouse` / `nxn_mouse` | `nxn_input.h` | Pointer as mouse (separates pointer from touch 0 once called) |
| `nxn_input_relative_mouse` / `mouse_delta` | `nxn_input.h` | Relative mouse look mode and delta motion (`NXN_CAP_INPUT_ROUTER`) |
| `nxn_input_pad_count` / `nxn_input_pad_poll` | `nxn_input.h` | Multi-controller count and per-pad state/edges (`0..7`, `NXN_CAP_INPUT_ROUTER`) |
| `nxn_input_action_buttons` | `nxn_input.h` | Maps OS action name (`"select"`, `"back"`, `"nav_up"`, etc.) to `NXN_BTN_*` mask |
| `nxn_input_action_down` / `action_pressed` | `nxn_app_api.h` | Non-consuming semantic action held/pressed queries from app snapshot |
| `nxn_pi_init` / `nxn_pi_update` / `poll_event` | `nxn_port_input.h` | Port helper: pinch/pan/2-finger-tap gestures + RTS/CRPG/FPS/Gamepad profiles |
| `nxn_imgui_input` / `nxn_imgui_input_event` | `nxn_imgui_input.h` | Feeds `nxn_input_state` and lifecycle events to ImGui before `NewFrame` |
| `nxn_nxui_move_focus` / `activate_focused` | `nxn_nxui.h` | Moves spatial UI focus (`0..3`) and activates focused widget (`nxui.moveFocus` in scripts) |
| `input.*` (`down`, `pressed`, `stick`, `motion`) | `input` (Script) | Script polling API plus `app.event(e)` (`pinch`, `rotate`, `paddown`, `keydown`, `text`) |

## Rules
- Poll `nxn_input_poll` on one consumer thread once per frame; focus loss, suspend, and quit suppress new presses and cancel pending activations.
- For ImGui utilities, forward all `nxn_event` lifecycle events to `nxn_imgui_input_event` and call `nxn_imgui_input` once per frame before `NewFrame`—never feed a second input backend.
- Use stable `nxn_touch.id` (not array index) to track simultaneous game/canvas contacts; clear all captures on focus loss, suspend, or `NXN_ERR_NOT_FOUND` on pad disconnect.
- Support docked mode (no touch) on every screen; use `NXN_ACT_CONFIRM` / `NXN_ACT_CANCEL` or `nxn_input_action_buttons` instead of hardcoding physical A/B.
- Do not mix `nxn_input_poll` with SDL joystick/gamecontroller polling in the same app.

## Pitfalls
- Confusing `nxn_nav.h` (`nxn_nav_*`, which is 3D pathfinding/navmesh) with UI focus navigation (`nxui.moveFocus` / `nxn_nxui_move_focus` / `nxn_input_action_buttons("nav_*")`).
- Treating a button release after focus-loss cancellation as a completed click.
- Inventing `input.touches()` or a manifest `multitouch` flag in scripts (neither exists).

## See also
- [INDEX](INDEX.md)
- [UI_NXUI](UI_NXUI.md)
- [LIFECYCLE_WINDOW](LIFECYCLE_WINDOW.md)
- [SCRIPT_SDK](SCRIPT_SDK.md)
