# UI_NXUI

## Purpose
Covers UI frameworks and OS design system parity across script `nxui.*`, native `nxn_nxui_*`, Dear ImGui `nxn_os_ui.h`, `nxn_ui.h` tokens/fonts, and OS menus/dialogs.

## Keys
| symbol/function | header or module | one-line meaning |
|---|---|---|
| `nxui.begin` / `nxui.endFrame` | `nxui` (Lua/JS/Py) | Starts and commits a retained auto-layout UI frame |
| `nxui.row` / `column` / `card` / `scrollBegin` | `nxui` (Lua/JS/Py) | Flexbox-like containers and clipped scrollable regions |
| `nxui.button` / `toggle` / `slider` / `textfield` | `nxui` (Lua/JS/Py) | Semantic OS-styled interactive controls with stable IDs |
| `nxui.table` / `virtuallist` / `dialog` | `nxui` (Lua/JS/Py) | Data tables, virtualized lists, and modal sheets |
| `nxn_nxui_begin` / `nxn_nxui_end_ex` | `nxn_nxui.h` | Native retained UI tree; `end_ex` returns `NXN_ERR_UNSUPPORTED` in GL windows |
| `nxn_os_frame_begin` / `nxn_os_frame_end` | `nxn_os_ui.h` | Required Dear ImGui frame layer (owns scale, fonts, style, min sizes) |
| `nxn_os_clear_color` / `NXN_S(px)` | `nxn_os_ui.h` | Theme clear color and scaled pixel macro (replaces bare pixel literals) |
| `nxn_os_button` / `select` / `switch` / `card_begin` | `nxn_os_ui.h` | OS-styled ImGui widgets driven live by `nxn_ui_tokens` |
| `nxn_ui_tokens_get` / `nxn_ui_tokens` | `nxn_ui.h` | Live palette, spacing, radii, `text_scale`, `ui_scale`, and `revision` |
| `nxn_ui_font_get` / `nxn_ui_icon_code` | `nxn_ui.h` | System TTF/OTF bytes (`NXN_UI_FONT_*`) and Material icon codepoints |
| `nxn_tr` / `nxn_tr_format` | `nxn_ui.h` | Native localized string lookup and `{0}` formatting from `lang/*.json` |
| `nxn_imgui_add_font` / `nxn_imgui_enable_gamepad` | `nxn_imgui.h` | Language-aware glyph ranges (incl. CJK) and ImGui gamepad nav flags |
| `nxn_menu_set` / `nxn_menu_clear` | `nxn_menu.h` | OS menu bar items (`NXN_CAP_MENU`, `NXN_EVENT_MENU` on pick) |
| `nxn_dialog` / `nxn_prompt` | `nxn_dialog.h` | Blocking OS modal alert and text prompt (`NXN_CAP_DIALOG`) |

## Rules
- Utility/tool apps must match the OS Design System (`theme.*` or `nxn_os_ui.h`); games must build their own art direction and never use `ui.*` / `nxn_os_*`.
- Native ImGui utility apps MUST use `nxn_os_frame_begin` / `nxn_os_frame_end`, `nxn_os_clear_color(tok)`, `nxn_os_*` widgets, and `NXN_S()` for pixel sizes (`design_check.py` enforces this).
- Never use `io.FontGlobalScale` or `SetWindowFontScale` in ImGui apps; the frame layer bakes fonts at `floor(pt * 1.21 * scale + 0.5)`.
- Minimum touch target is 44 px for icon buttons, rail items, and list rows; text controls are at least 30 px tall.
- Call `nxn_dialog` / `nxn_prompt` from a worker thread if the main render loop must keep running while waiting for the user.

## Pitfalls
- Calling `nxn_nxui_*` expecting it to paint inside a Native GL window: it only lays out/routes input and never paints in a native GL FBO (`nxn_nxui_end_ex` returns `NXN_ERR_UNSUPPORTED`).
- Using raw `ImGui::Button`, `ImGui::Combo`, or bare pixel literals in a utility app—fails `nxv check` / `design_check.py`.
- Calling `nxn_dialog` when another dialog is already open returns `NXN_ERR_BUSY`.

## See also
- [INDEX](INDEX.md)
- [SCRIPT_SDK](SCRIPT_SDK.md)
- [INPUT](INPUT.md)
- [GRAPHICS](GRAPHICS.md)
