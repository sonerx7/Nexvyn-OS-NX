# Input Lab

A native C++ interaction panel using the canonical OS widget kit and shared `nxn_imgui_input` backend. Build and package with `python tools/nxv_native build <project>` and `python tools/nxv_native package <project>` from the kit root.

Drag the slider outside its bounds, type in the field, choose a mode, swipe inside the inner and outer frames, navigate with keyboard/gamepad and scroll with the right stick. Two fingers demonstrate pinch and rotation using stable IDs. The standard UI stays a single-pointer interface; a game or canvas can interpret multiple contacts independently. The displayed values are also written to the app log when they change.

The script and interpreted C variants use the same OS controls and interaction inventory. UI applications follow OS tokens and control rules; games keep their own visual direction.

The panel switches to a stacked form below 620 logical pixels. Resize it to the 360 px minimum and back: edits, slider value, gesture state and pane offsets remain intact. Each geometry change records `Layout compact|wide width height` so automation verifies content reflow rather than only the window border. Lifecycle events go through `nxn_imgui_input_event`; touch fling uses `nxn_scroll_physics.h`.

The panel ships complete `en tr de es fr ja ko zh` dictionaries and translates
visible controls with `nxn_tr`; the script variants use their `TR` binding. Numeric
interaction diagnostics keep a stable English schema and never log the text field.
Rebuild to adopt fractional touch-fling distance and programmatic-scroll interruption
from the current OS helper. The helper preserves subpixel motion until rasterization;
this does not claim a new physical-console frame rate.
