# native-tool

The generated C library probe retained, with a hosted status frontend, lifecycle/deferred resize handling and complete localized status. Green means load/call succeeded; red means failure. Back/Plus exits.

Created with the kit command below, then adapted as described above. It recreates the stock template, not these customizations. Use an absent destination. `<kit>` means `SDK/Languages/c/native-kit`; `<project>` is this project's absolute path.

```text
python tools/nxv_native new native-tool --template shared-lib --dir <repo>/SDK/AI/golden
```

Files: `src/main.c, lib/greet.c, lib/greet.h`, `app.json`, `icon.png`, and eight complete `lang/*.json` tables (en, tr, de, es, fr, ja, ko, zh). Icons are the kit's generated gradient placeholders, not Store artwork.

Run from `<kit>`:

```text
python tools/nxv_native build <project>
python tools/nxv_native check-win <project>/build/native-tool.nxvmod
python tools/nxv_native check-design <project>
python tools/nxv_native package <project>
```

Build/check/package passed, but dynamic loading was not executed. NXN_CAP_SHARED_LIBS can be unavailable; failure is logged and shown. native.windowedLibs is a system setting, not a native object in this manifest.

Native GL calls stay on the display-owning thread; defer Busy resize retries to later frames. Script surfaces are host-owned and layouts use draw dimensions. Review input held/pressed/released/cancelled states, focus/suspend, minimum size, docked and handheld modes on the runtime. These are validation tasks, not completed test claims.

See [RESULTS.md](../../../AI/golden/RESULTS.md) for exact executed commands and evidence. Build outputs were removed; rebuild before packaging. No device performance claim is made.
