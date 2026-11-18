# Validating AI-made apps (`nxv check` flow)

Run every step; a project is done only when all applicable steps pass. Paths are relative to the repository root
unless a step says otherwise.

## 1. Script apps (Lua, JavaScript, Python, C script, Squirrel, Java)

```sh
python SDK/Tools/nxv/nxv.py check <bundle> [--frames N] [-v]
python SDK/Tools/nxv/nxv.py pack  <bundle> [-o out.nxvapp]
```

`nxv check` verifies:

| Area | What fails |
|---|---|
| Manifest | `app.json` not an object; missing or bad `id` (reverse domain); missing `name`; `version` not dotted numbers; unknown `category` or `runtime`; missing `main`; wrong `minSdk` for the runtime; malformed `window` sizes or `shareTargets`. |
| Permissions | `permissions` not a list of known names (a missing list is a warning: users get asked for all). |
| Icon | missing or not a PNG (128x128 or 256x256 recommended). |
| Sources and size | API use that needs a permission the manifest does not declare; too many files; more than 1 GiB unpacked; compiled files the runtime will not load (warning). |
| Store item | `store.json` fields when the bundle is a Store item. |
| Locales | `lang/*.json` for all of `en tr de es fr ja ko zh`, same keys and placeholders as `en`. |
| Runtime checker | Maintainers only: in the Store review the language's own checker runs the app headless. App makers run the app on the console instead. |

`nxv pack` writes a deterministic `.nxvapp`. Native apps are not packed by `nxv pack`; use the native kit.

## 2. Native apps (C/C++, ABI v1)

From `SDK/Languages/c/native-kit`:

```sh
python tools/nxv_native doctor                 # toolchain present
python tools/nxv_native build <project>        # CMake build to <name>.nxvmod, checked
python tools/nxv_native check-win <module>     # identity, -fPIC, imports limited to what the OS offers
python tools/nxv_native check-design <project> # OS design rules (frame layer, nxn_os_* widgets, scaling)
python tools/nxv_native package <project>      # .nxvapp = module + icon + app.json + lang/
python tools/nxv_native check-lib <lib>        # shared libraries (.nxvlib) only
```

`package` prints design failures but still packages: treat any printed design failure as a failed step and run
`check-design` until it passes.

ABI checks: the module may only import functions in the frozen ABI v1 list
(`sdk/native/toolchain/nxn_abi_v1.json`, `nxwin_imports.txt`). Using a newer function needs `minNative` in
`app.json`; `check-win` reports imports the OS does not offer.

## 3. Size

- Keep packages small: no build folders, object files, debug ELF files or fetched upstream trees in the bundle.
- Compress large assets; stream them instead of loading all at start.
- Report the `.nxvapp` size in the README.

## 4. Behaviour checks you must do by hand (or state as untested)

- Resize the window repeatedly (window apps): no crash, no stretched frame, viewport updated after success.
- Suspend and resume: audio and time pause, state survives.
- Docked and handheld sizes: layout adapts; text readable.
- Controller only, then touch only: every action reachable.
- Open/close the app 10+ times: memory does not grow.
- Switch the system language: every visible string changes.

## 5. Report template

```
check:   PASS/FAIL  (decisive line)
build:   PASS/FAIL  (native only)
design:  PASS/FAIL
package: PASS/FAIL  size=<bytes>
locales: 8/8
untested: <list>
```
