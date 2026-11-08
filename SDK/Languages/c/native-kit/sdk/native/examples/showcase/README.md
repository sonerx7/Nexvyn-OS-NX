# Native SDK Showcase

One windowed app that shows every Native SDK 1.0 feature and self-tests it. The Status page lists each feature with
OK, FAIL (with the error text), `-` (not available here) or NOT IMPLEMENTED (the SDK has no API yet), and writes the same
table to `<app data>/showcase_report.txt`. UI: Dear ImGui (vendored) with its OpenGL3 renderer and a small platform glue
fed by `nxn_input` / `nxn_event` (no SDL2).

Pages: Status, Display & GL (rotating cube, fps, resize / focus events), Input (buttons, sticks, touch), Audio (tone, pan),
Files, System, Threads, Compat, Libraries (zstd, lz4, sqlite), UI tokens (the OS look from `nxn_ui_tokens_get`, system font and icons, `nxn_tr` with `lang/en.json` + `lang/tr.json`), Crash (confirm step first).
L / R switch pages, D-pad + A select, touch works.

Build and package (needs devkitPro; the sysroot is optional, without it the three library rows show `-`):

    python sdk/native/examples/showcase/package.py --sysroot <sysroot dir> [--out DIR]

This builds `build/showcase.nxvmod` and packs `com.nexvyn.example.showcase.nxvapp`. The compat layer (`libnexvyn_compat_pic.a`
is linked into the module) is tested in a window too: pipe, poll, eventfd, select, mmap, signals, fcntl, `/dev/*`,
coroutines, own environment + working directory and sockets (OK means the permission check answered as it should: `network`
in `app.json` allows them, without it the calls fail with `EACCES`). Rows for shared libraries and `dlopen` read
"not supported in a window yet" (W2). If `<app data>/autotest` exists the app runs
everything, writes the report and returns code 7. `showcase_stage.txt` names the test that is running (finds hangs).
