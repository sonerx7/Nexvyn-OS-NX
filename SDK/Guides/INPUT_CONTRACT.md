# Input, gestures and focus contract

Use one semantic action map for gameplay and navigation, with adapters for gamepad, keyboard,
mouse and touch. Keep “held”, “pressed” and “released” distinct. Confirm/Cancel follow the user's
system mapping; do not hard-code physical A/B as universal meaning. A docked session must remain
usable without a touchscreen. Unsupported device actions need a visible alternative.

## System UI and native frame order

Use shared controls for forms and lists. Sliders capture their drag, text inputs capture editing,
and scroll frames own background/row swipes only after drag slop. The deepest eligible nested
pane owns the drag. A new touch stops inertia without activating the moving row. Do not feed
the same physical action to both the cursor backend and a second widget activator.

For a native ImGui utility, follow the app template:

1. Poll and process lifecycle/window events; forward each to `nxn_imgui_input_event`.
2. Poll `nxn_input_state` once per frame on one consumer thread.
3. Feed `nxn_imgui_input` before starting the ImGui frame, with elapsed seconds.
4. Use the OS frame layer and `nxn_os_*` controls, then render/swap.

The helper handles keyboard text/events, mouse buttons/wheel, stable primary touch and gamepad
navigation. It does not give every ordinary ImGui widget independent simultaneous fingers.
Keep direct-contact game/canvas interaction separate from the primary-pointer UI adapter.

Scripts receive normal UI input and gesture events; `pinch` provides `e.scale`, and `rotate`
provides `e.angle`. Verify the exact runtime event shape in the reference/InputLab. Do not invent
`input.touches()` or a manifest `multitouch` flag because another platform uses those names.

## Native simultaneous contacts

Native modules targeting at least Native 1.1 receive multiple focused contacts. Read
`nxn_input_state.touch_count` after polling and call `nxn_input_touch(index, &touch)` for each.
Initialize each struct with `NXN_STRUCT_INIT`. Contact `id` is stable while held; array index is
not a persistent identity. Positions are window-surface pixels and must be transformed through
the visible viewport to engine/canvas coordinates. Check every return value.

```c
nxn_input_state state = NXN_STRUCT_INIT(nxn_input_state);
if (nxn_input_poll(&state) == NXN_OK) {
    for (uint32_t i = 0; i < state.touch_count; ++i) {
        nxn_touch contact = NXN_STRUCT_INIT(nxn_touch);
        if (nxn_input_touch(i, &contact) != NXN_OK) continue;
        /* Route contact.id and contact.x/y to the owning control or game action. */
    }
}
```

Maintain a bounded previous/current ID map. An ID disappearing is release/cancel; clear all
captures on focus loss, suspend, close or input reset. Do not synthesize a click after a pinch.
Two fingers starting on separate game controls can drive movement and fire concurrently. Two
fingers starting on a canvas can drive pinch/rotation. A second canvas contact must not steal
a slider/text edit. Declare gesture ownership and restart behavior explicitly.

## User-selectable game/port controls

Offer the modes the product can actually implement: Auto, Gamepad, Touch and Keyboard/Mouse.
For suitable gameplay add a persisted multitouch option for independent virtual stick/buttons
or a gesture canvas. It is an app setting, not a new system permission or a fake capability.
Turning it off cancels active contacts and selects the defined primary-pointer fallback.

Separate pointer absolute position, relative mouse/camera motion, virtual gamepad axes and text
input. Apply dead zones/response curves consistently, show current button hints and permit rebinding
where useful. Keep keyboard composition separate from gameplay shortcuts. Avoid requiring a
physical keyboard for basic pause, settings or content selection.

## Verification scenarios

Touch: drag a slider to both ends, swipe nested lists, stop a fling, scroll beside a text field,
use two controls simultaneously, pinch/rotate, lift fingers in either order and resize mid-gesture.
Pad: navigate and reveal offscreen focus, adjust values, open/close a modal, disconnect/reconnect,
switch to touch and back without losing state. Mouse/keyboard: wheel, short click, drag outside,
Tab/Shift+Tab, arrows, Escape, UTF-8 text, selection and clipboard where supported.

Repeat focus loss, suspend and close with controls held. State must recover with no stuck movement,
duplicate click or callback into a closed app. Use actual hardware for physical simultaneous-touch
and disconnect acceptance. A scripted gesture or screenshot does not establish hardware coverage.
