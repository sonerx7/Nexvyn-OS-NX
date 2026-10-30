# UI Gallery

**English** · [Türkçe](README.tr.md)

Every `ui.*` widget of the SDK, live, with the Lua code that draws it beside it: buttons, switches, text fields, choices, feedback, lists, pointer and dialogs.

| | |
|---|---|
| Id | `com.sonerx7.demo.ui-gallery` |
| Language | Lua 5.4 |
| Min SDK | 1.0 |
| Permissions | none |
| Gamepad | drives the cursor |
| Window | 960 × 620, resizable |

## What it teaches

- Immediate mode: each widget is called every frame and returns what happened
- All `ui` functions: button (six styles, icon, disabled), iconButton, toggle, checkbox, radio, slider, textfield (flags, Enter), focus, keyboard, segmented, dropdown, label, progress, spinner, row, group, separator, beginScroll/endScroll (nested), hit, mouse, contextMenu, alert, prompt, openFile, saveFile
- Data-driven layout: a page is a list of cards {title, height, demo function, code}; the content height is the sum of the card heights
- Responsive layout: sidebar and code beside the widget on wide windows, a dropdown and code below on narrow ones

**APIs used:** `ui.*` (hepsi / all), `gfx.shadow/rect/text`, `fs.write` (kullanıcının seçtiği yol / a user-picked path), `store`

**Controls:** Pick a page in the sidebar or the dropdown · Page Up / Page Down: switch pages.

## Code excerpt

One card: the function that draws the live widget and the code shown beside it live in the same table.

```lua
{title = "ui.hit", desc = "desc_hit", h = 150, demo = function(x, y, w)
  local hit = ui.hit("box", x + S.boxX, y + S.boxY, 90, 60)
  if hit.held then                          -- dx, dy: how far the pointer moved this frame
    S.boxX = max(0, min(w - 90, S.boxX + hit.dx))
    S.boxY = max(0, min(80, S.boxY + hit.dy))
  end
  if hit.doubleClicked then S.boxX, S.boxY = 40, 20 end
  ...
end, code = 'local h = ui.hit("box", bx, by, 90, 60)\n...'},
```

## Running it

Copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `UIGallery.nxvapp`, or pack it into one file with `python tools/nxvapp_pack.py`. Files: `main.lua` (370 lines), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`.

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    python tools/lua_check.py <Nexvyn-OS-NX>/SDK/Samples/lua/ui-gallery/source --frames 900

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
