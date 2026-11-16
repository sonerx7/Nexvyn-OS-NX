# Game Engine as an App Market module

The Game Engine (`source/apps/app_gamemaker.cpp`, `workshop_*.cpp`) is built twice from the same sources:

| Copy | App id | Where | Built by |
|------|--------|-------|----------|
| Built-in (fallback) | `gamemaker` | inside `NexvynOS.nro` | the normal NRO build |
| App Market module | `com.nexvyn.gameengine` | `build/modules/gameengine.nxvapp` | `tools/build_modules.py` (`tools/modules.json`, `"keepBuiltIn": true`) |

The module is an ordinary native module (`.nxvmod`, docs/NATIVE_MODULES.md): it links against the symbols
`NexvynOS.nro` exports and carries the module ABI id (`NEXVYN_MODULE_ABI_GEN`). It is not a Native SDK (ABI v1) app:
the editor uses the OS's immediate-mode UI, text, 3D preview, Studio editors and the package installer, which ABI v1
does not offer. Porting it to ABI v1 would be a rewrite with feature loss, so it stays an OS module.

## Core units it uses

The 3D collision core (`source/core/phys3d.*`, SDK 1.15 `phys`) is part of `NexvynOS.nro`. The module calls it like any
other NRO function: `tools/build_modules.py exports` adds every symbol the module imports to the NRO's export list, so
no ABI generation changes (`NEXVYN_MODULE_ABI_GEN` stays; it is raised only for an incompatible change of a shared
struct or calling convention). A module built for an older NRO that lacks a symbol is refused cleanly ("missing symbol").

The navigation core (`source/core/nav3d.*`, SDK 1.15 `nav`) is part of the NRO the same way: a walkable grid baked from a `phys3d`
world on a worker thread (`nav3d::BakeJob`, progress and cancel, byte budget), A* paths, blockers and cost areas, and `nav3d::Crowd` agents.
The editor bakes in the background so it never freezes; the baked grid is deterministic, so a level layout generator can check
reachability with it.

## Choosing the copy

Every entry point launches `gamemaker`: desktop shortcut, Dock, Start, Quick Search, file types, Tips, Studio, the tour.
`os::launch` asks `gameengine_route::target()` (`source/wm/gameengine_route.h`, implemented in `source/wm/shell.cpp`).
The module opens only when all of these hold:

- Setting `apps.gameengine.external` is `true` (default `false`: the built-in copy, the behaviour before this change).
- `com.nexvyn.gameengine` is installed, its module file exists and is trusted (App Market installs are trusted).
- Its ABI id equals this system's, and it was not turned off after repeated crashes (`nxvmod::disabled`).
- It did not fail to open earlier in this session, and the tour is not running.

Otherwise the built-in copy opens, without a question. Turning the setting off goes back at once.

The package's `app.json` is hidden and has no file types: users see one Game Engine, the built-in entry, and it opens
whichever copy is chosen. Both copies read and write the same project folders; nothing is moved or copied.

## Not done in this step

The built-in copy is **not** removed from the NRO. Removing it is a separate step, only after the module has been
tested on a console: drop `"keepBuiltIn"` from the `tools/modules.json` entry (the build then leaves the sources and the
bundle out of the NRO and lists the app in `System/Modules.json`, so users who had it get it back from the App Market),
and point `gameengine_route` at the package id.
