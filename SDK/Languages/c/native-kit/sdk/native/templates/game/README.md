# Native game building blocks

This is a movement/jump demonstration, not a finished game or a reusable menu skin. Create your
own art direction, gameplay, menus, accessibility and production-quality assets.

- Gamepad: left stick/D-pad moves, A jumps, Plus pauses, Minus toggles multitouch.
- Keyboard: arrows/A-D move, Space jumps, Escape pauses, M toggles multitouch.
- Touch: the left two thirds steer; the right third jumps. Simultaneous contacts allow movement
  and jumping. The upper-left pause symbol pauses/resumes; the upper-right one/two-bar indicator
  toggles single-contact/multitouch mode.

The multitouch preference is saved with the jump count in the app data folder. Old one-field
saves remain readable. Turning the option off cancels captures; the primary contact cannot be
silently replaced by a second finger already held. Region ownership is assigned on contact-down;
dragging from steering into Jump never fires Jump. Focus loss/suspend cancels and pauses.

`actions.h` merges named gamepad/keyboard/touch actions; `touch_actions.h` tracks stable IDs and
cancellation. Replace these basic regions with your own visible virtual controls or gesture
canvas. Do not feed game touches into the ordinary ImGui primary pointer at the same time.

The creator supplies eight locale files. Use translation calls for every added menu/HUD/error
label; keep all locales complete. Run the SDK localization checker before packaging. Test actual
physical simultaneous contacts as well as host ownership fixtures.
