# Native ports, launchers and integrated games

Use the existing native `.nxvmod` host, SDK capability queries, display, input, audio and file
services. Preserve the engine's renderer where supported. A native app shares the host process;
removing an extra launch warning does not add isolation. Package validation, install review,
permissions and compatibility checks still apply. No runtime should require a repetitive generic
“not sandboxed” confirmation just to open an installed application.

## Choose a real integration

Use `app` for an OS utility, `game` for a custom renderer, or a suitable port/SDL2 template for
an engine. Keep fullscreen/window mode distinct from handing off to a standalone executable.
An existing standalone handoff can remain a documented compatibility path, but it does not
prove an integrated windowed module, shared compositor or clean desktop return.

Confirm actual compiler/ABI imports, graphics version/extensions, audio formats, filesystem,
TLS/thread requirements and optional JIT needs. Headers and link success do not prove semantics.
Use a truthful unsupported-feature error and a usable fallback. SDK version, minimum OS,
target behavior and module identity are different fields. Do not require a fabricated SDK 2.0.

## Launcher experience

Avoid an unnecessary launcher for a game that can start directly. When content or engine setup
is required, use a small clear screen with content selection, Play/Continue, controls, settings,
help and safe Back. System-facing launcher chrome follows OS design tokens; the game may have
its own menu identity. Remember selection and per-game settings in app data without global CWD
changes. Validate selected files before starting and explain missing content without blocking
desktop input. Never scan the whole card each frame.

Show only effective options: render backend/quality, display mode, audio, input mode/remapping,
multitouch virtual controls where implemented, save/profile selection and reset. An option must
change real behavior and persist; disabled controls explain the missing capability. “Automatic”
must have a defined policy and a visible current choice. No decorative switches for future APIs.

Use the system file/folder picker and retained grants when appropriate. Missing or moved content
returns to a usable selection screen. Bundled assets, user-selected assets and saved game data
are separate namespaces. Keep previous saves through package updates; migrations need recovery.

## Controls and engine ownership

Build semantic actions, then map gamepad, touch, mouse/keyboard and engine input separately.
Offer a real touch/multitouch mode for games that need simultaneous movement and action; provide
a controller path in docked mode. Read native contact IDs through `nxn_input_touch`, rather than
assuming the first array slot always means the same finger. See [input contract](INPUT_CONTRACT.md).

Exactly one owner consumes an input stream. Do not poll HID independently in the port and the
host while also forwarding SDK events. Respect focus loss, dialog capture, suspend and reconnect.
Engine render calls stay on the owning graphics context/thread. Workers can load/prepare data;
they cannot manipulate WM or issue arbitrary GL calls from another context.

## Loading, pause and shutdown

Keep the shell responsive while preparing the engine. Display real phases/progress and provide
cooperative cancellation. `loadingHint` is not a substitute for event pumping or background I/O.
Bound decoded assets, thumbnails, pending jobs and audio queues; skip obsolete work.

On close: stop new work, release capture, request worker cancellation, drain/join registered work,
flush saves safely, stop audio and retire GPU surfaces only after completion. Do not terminate
arbitrary threads holding shared locks. No callback can outlive its app/engine generation.
Unsafe native faults cannot always be recovered in a shared process; report that limit honestly.

## Acceptance

Exercise fresh content selection, Play/Continue, resize/fullscreen, input-mode changes and
multitouch, pause/resume, lost focus, device disconnect, missing content, load cancellation,
normal quit and immediate reopen. Verify settings/save persistence, bounded warm caches and
no stuck audio/capture after close. Compare frame pacing under load with the desktop still usable.
Translate launcher and game-facing text into all eight locales. Ship license/source notices,
use actual English UI store screenshots and retain device evidence for supported modes.
