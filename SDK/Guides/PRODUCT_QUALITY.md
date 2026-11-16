# Product identity and production quality

This contract applies to new applications, games, ports and launchers. Use it with the exact
[SDK reference](../Reference/SDK.md), [input contract](INPUT_CONTRACT.md),
[localization contract](LOCALIZATION_CONTRACT.md) and [port guide](PORT_AND_LAUNCHER.md).

## System applications

Follow the live system palette, text roles, spacing, density, radii, focus/pressed/disabled
states and motion preferences. Respect accent, light/dark mode and enlarged text. Use real
controls: a painted slider or switch without keyboard/pad/edit semantics is not equivalent.

Lua/JS/Python use the shared `ui.*` or `nxui.*` controls. Native ImGui utilities use
`nxn_os_frame_begin`/`nxn_os_frame_end`, `nxn_os_*` widgets and the shared input backend in
`nxn_os_ui.h`. Check signatures in the installed headers. Native GL windows cannot obtain a
visible UI simply by building an OS-side NXUI tree; use the native drawing helpers.

Do not substitute raw ImGui controls, a private font atlas or arbitrary color/size literals for
the system's form controls. Custom charts/canvases are appropriate inside those controls.
System typography and scale must remain sharp; scaling a completed screenshot is not reflow.

Match behavior across languages: control values, focus, gesture ownership, loading feedback,
errors and cancellation. Matching screenshots alone do not establish interaction parity.

## Games and creative experiences

Create an art direction: reference scene, palette, material language, lighting, camera, HUD,
animation, sound and transitions. Menus and games should have their own coherent identity.
Avoid cloning a utility panel or reusing the same game menu as every other product. Share input,
file/save dialogs and lifecycle rules without imposing OS decoration on the actual game world.

Build one polished vertical slice before increasing content volume. Include a meaningful start,
playable objective, feedback, failure/recovery, pause, save/checkpoint where appropriate and clean
exit. A generated level, static preview or benchmark is not a complete game.

Use asset licenses and budgets deliberately. Models need suitable topology/LODs, collision proxies,
texture sizes and material setup. Use instancing, visibility culling and asset streaming where
the selected API supports them. PBR effects do not repair weak composition or missing gameplay.
Use music, ambience and responsive action sounds with sensible mixing; avoid clipping and stalls.

## Responsive layout and state

Test the minimum supported viewport, narrow/compact, wide, maximize/restore and fullscreen.
Base layout on the current logical content dimensions. Reflow controls and wrap/ellipsis text;
do not hide required actions offscreen. Preserve edits, slider values, selection, scroll position
and game state through resize/theme changes. Avoid blocking layout on asset decoding or I/O.

Native utilities opt into responsive resize with explicit `"liveResize": true` in new manifests;
saved system opt-outs remain authoritative. Recreate expensive surfaces only when required and
always follow actual displayed dimensions for hit testing. Keep old-frame continuity and never
reuse a GPU image before the relevant work completes. Libraries cannot promise that every port
can cheaply resize each frame; document a necessary limitation.

## Interaction and accessibility

System controls use the shared sizing/hit-target metrics. Make primary touch actions comfortable
without shrinking labels to fit. Provide visible pad/keyboard focus, consistent Back/Escape,
controller remapping where needed, focus reveal inside scroll regions and meaningful empty/error
states. Respect reduced motion; pressing an action must not wait for a decorative animation.

Review eight locales, CJK glyphs, text entry and 100/150/200% text scale. Keep information encoded
in labels or shapes as well as color. Native font coverage does not prove shaping/IME correctness;
test actual input and editing. Readability and cancellation matter more than visual effects.

## Performance and perceived speed

Declare target scene, refresh mode, device mode and quality settings before profiling. Record
frame distributions and slow frames, not just average FPS. Native/script engine versions and
real hardware must be named honestly. Desktop preview and emulator measurements are not device
performance promises. Treat 60 Hz as a target that must be measured, never a template guarantee.

Show pressed/loading feedback immediately. Keep input, audio and shell progress alive during
loading; support cancellation. `loadingHint` extends tolerance for genuinely heavy startup; it
does not make blocking work responsive. Bound queues/caches, reject stale completions and avoid
logs/files/network work in hot frame paths. Virtualize large lists rather than constructing
10,000 complete controls each frame. Hidden/paused windows should avoid unnecessary rendering.

Measure warm-up and repeated open/close batches. Distinguish cache retention from lost ownership.
No fixed per-app RAM limit is implied by a manifest memory hint. Actual resource availability
and allocation failures still matter. Prevent a heavy app from starving desktop interaction.

## Finished-product evidence

- All essential actions work with the supported input modes; focus loss/suspend/disconnect cancels held input.
- Nested scroll, slider drag, dropdown/text entry, resize and compact/wide state transitions are exercised.
- The eight translations have equal complete keys and placeholders, plus visual and linguistic review.
- Save/load/reopen, interrupted loading, offline/error cases and clean exit preserve user data.
- A representative physical-device scene has measured frame/memory/audio behavior and known limits.
- Store screenshots show the actual product. English UI screenshots are accepted; screenshots need not be
  repeated in all eight languages. Prefer five useful views for a game rather than five near duplicates.
- Installation and update preserve IDs, settings, saves and grants. Permissions match actual behavior.

Automated checks are a necessary baseline. Art quality, gameplay and real-world interaction still
need review. “AAA quality” is a production ambition supported by this workflow, not a result that
can be certified by a manifest, a renderer name or an AI prompt alone.
