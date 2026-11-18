# Input, gestures and focus contract

Use one semantic action map for gameplay and navigation, with adapters for gamepad, keyboard,
mouse and touch. Keep “held”, “pressed” and “released” distinct. Confirm/Cancel follow the user's
system mapping; do not hard-code physical A/B as universal meaning. A docked session must remain
usable without a touchscreen. Unsupported device actions need a visible alternative.

Shared router query policy3: a pressed query is non-consuming and lasts for one
shell frame; it clears before that frame's input producers run. Held queries
combine independent keyboard, pad, touch and mouse sources, so releasing one does
not release another. Enter/Space aliases retain Confirm until both are released.
Keyboard repeat keeps queued navigation behavior, but does not invent a fresh
physical query edge. Queued events retain their independent window/consumer
lifetime across frames; querying or starting a frame does not consume them.
Synthetic semantic injection contributes a one-frame query pulse. This private
router policy changes neither frozen SDK layouts nor the app-side native snapshot
API. Focus ownership, cancellation, physical disconnect and native snapshot thread
ownership still require their own validation; a raw held mask is not gesture capture.

Native semantic action exports read this app's mutex-protected copy of the shared
action state. The main owner publishes it with the existing input snapshot; app
threads never traverse the live Router for these queries. Focus loss, suspend,
quit and stopping suppress both held and pressed answers. Null/unknown names and
missing app context return false. These queries are non-consuming and describe
the shell input frame; they are not latched per app frame. Native loops needing
every button edge use `nxn_input_poll`, whose existing latches remain unchanged.
Physical remapping, disconnect and blocked-focus pad behavior still require their
own complete runtime matrix; snapshot ownership alone does not prove those cases.

Script foreground query policy1: shared NXUI semantic held/pressed and touch-count
queries, raw held buttons, sticks and multi-controller held queries require an
actual calling-window context that owns usable foreground input. Background,
minimized, closing, faulted, other-desktop, overview and shell-modal callbacks return
neutral activation values. A missing callback context does not borrow the focused
window. Lua, QuickJS, legacy PocketPy and the shared CPython/interpreted-C adapter
use the same WM eligibility check. Connected-controller count remains topology
information and is readable without focus. This boundary does not consume queued events or alter
physical button mappings. Focus handoff while buttons remain held, same-frame
semantic provenance, per-app queued/latching cancellation and actual runtime/device
coverage remain separate requirements; foreground eligibility alone is not gesture
capture or complete focus isolation.

Script frame-cancellation policy1: Lua, QuickJS, legacy PocketPy and nxvrt-based
CPython/interpreted-C/frozen adapters share per-app `FrameInput` bookkeeping.
Focus loss and suspend clear pending pad press/release and key-press queries before
persistence, language callbacks or callback job pumping. Cancellation also occurs
when the VM is unloaded or in an error state. Focus gain alone preserves new input;
loss/regain without a draw cannot replay the previous frame's pending edges.
This does not synthesize release/click events, clear another app's state or reset
the application's own cached controls. Router/NXUI queues, capture, held-button
rearming, modality transitions and actual VM/device coverage remain separately gated.

Shared gamepad semantic policy1 reads the existing system button map for Select,
Back, Context and four navigation directions. Raw controller slots and button
masks stay physical. A mapping edit updates semantic held state without emitting
a new activation or rewriting already queued presses. Press provenance keeps the
physical contributors for each semantic action until the next shell frame; native
focus-blocked pad bits can therefore be suppressed without deleting independent
keyboard/touch/mouse input. The WM also synchronizes physical held state without
adding events, including releases routed to shell surfaces after capture ends.
Native `nxn_input_poll` Confirm/Cancel masks refresh with the same existing app
action-map snapshot after settings change. Synthetic coverage is not physical
remap/handoff certification; same-frame mixed-modality focus transitions and
disconnect/suspend still require the runtime/device matrix.

Native lifecycle snapshot cancellation (host fix; no ABI layout change): focus loss,
suspend and quit discard app-owned pending activations before publishing their event. WM focus
callbacks are observed even when loss and restoration occur between frame updates.
App-owned keyboard/text, pointer deltas, contacts, semantic presses and pad press latches do not
replay after that boundary. Previously observed pad holds can report one release so
apps can end held controls. A focused short press between polls remains latched.
`nxn_input_poll` suppresses new presses while unfocused, suspended or stopping.
Apps still handle lifecycle events and cancel their own captures/jobs; release alone
must not be treated as a successful click after cancellation. This host correction
also applies to existing modules; the legacy lifecycle-event opt-in remains intact.
Physical multitouch, driver/device timing and complete lifecycle behavior require
separate runtime/device evidence.

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
Forward every lifecycle event to the shared helper, including suspend/resume and quit. A short
focus loss/regain still cancels edits, pressed controls and scroll inertia; cancellation never
becomes a click. Existing held contacts/mouse buttons must lift before a new primary press. Resume
does not grant focus to an unfocused window. Rebuild app-side helpers to adopt these semantics;
host event delivery alone cannot update helpers compiled into an older module.

Shared retained UI dispatch consumes only events targeted at that window. Pending
events for another window remain queued in order; drawing one tree does not
reproduce another window's keyboard events. Unscoped events keep first-consumer
semantics and must not be treated as a broadcast to every window.

When the shared retained router cannot replace a motion event at capacity, its
private overflow policy discards the incomplete backlog and invalidates captures
for every live tree through a bounded reset generation. Queued actions can be
lost; they are not replayed as fresh presses. Each tree cancels even without its
own pending event. Pointer cancellation closes transient dropdowns without a
selection and retains keyboard/gamepad focus. This policy does not discard
admitted native menu commands from their separate host queue.

Scripts receive normal UI input and gesture events; `pinch` provides `e.scale`, and `rotate`
provides `e.angle`. Verify the exact runtime event shape in the reference/InputLab. Do not invent
`input.touches()` or a manifest `multitouch` flag because another platform uses those names.

## Native simultaneous contacts

Windowed native keyboard events normally use a 64-transition FIFO. If an app
stops polling long enough to overflow it, the host repairs current held state:
releases first, then fresh downs. Intermediate taps/repeats during that overflow
are not recoverable. Keep polling on one consumer thread and retain a bounded
per-frame work budget; a large repair can span several frames. Focus loss and
suspend preserve releases owed to that consumer instead of leaving keys held.
The host repair does not reconstruct typed text or replace normal focus/capture
cancellation in the UI adapter.

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

Native per-controller snapshot ownership: `nxn_input_pad_poll` derives edges from
this application's observed focused snapshots and latches them until its own poll.
It never drains shared pending edges from a previous owner. On focus acquisition or
controller connection, already-held physical bits are suppressed until release;
a fresh press then works normally, including on non-primary controllers. Disconnect
cancels the slot and discards its old pending edges. Apps cancel that controller's
held actions/captures when polling returns `NXN_ERR_NOT_FOUND`. Raw router masks and
other adapters' consumers are unchanged. No semantic remapping is applied to these
physical bits. This is a host ownership fix, not a new frozen ABI or hardware claim.

## Verification scenarios

The shell drops the previous window's queued events when focus moves away and
increments a private cancellation generation. Main-thread retained NXUI observes
that generation before routing, so loss/regain between draws still cancels pointer
capture, open popups and inertia without converting cancellation into activation.
An ineligible owner drops only its own queue and skips routing. Keyboard/gamepad
focus selection is preserved. New input works after eligibility returns.

This host path does not establish native app-thread or legacy unscoped NXUI
isolation or held-button rearming for all adapters. WM content capture now detaches
on focus loss before one cancelled release; closing/unstarted owners receive no
event callback. Relative requests/deltas drop before loss callbacks and camera
queries require an eligible callback owner. See content evidence.
Actual raw input-pump/device lifecycle still needs separate evidence.
See the focused results.

Touch: drag a slider to both ends, swipe nested lists, stop a fling, scroll beside a text field,
use two controls simultaneously, pinch/rotate, lift fingers in either order and resize mid-gesture.
Pad: navigate and reveal offscreen focus, adjust values, open/close a modal, disconnect/reconnect,
switch to touch and back without losing state. Mouse/keyboard: wheel, short click, drag outside,
Tab/Shift+Tab, arrows, Escape, UTF-8 text, selection and clipboard where supported.

Repeat focus loss, suspend and close with controls held. State must recover with no stuck movement,
duplicate click or callback into a closed app. Use actual hardware for physical simultaneous-touch
and disconnect acceptance. A scripted gesture or screenshot does not establish hardware coverage.
