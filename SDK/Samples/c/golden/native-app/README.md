# native-app

The stock file-picker/settings UI with deferred Busy resize retry, focus/suspend handling and pressed cancel. Uses the OS frame/widget layer and persisted settings.

Created with the kit command below, then adapted as described above. It recreates the stock template, not these customizations. Use an absent destination. `<kit>` means `SDK/Languages/c/native-kit`; `<project>` is this project's absolute path.

```text
python tools/nxv_native new native-app --template app --dir <repo>/SDK/AI/golden
```

Files: `src/main.cpp, src/imgui_gl_glue.cpp`, `app.json`, `icon.png`, and eight complete `lang/*.json` tables (en, tr, de, es, fr, ja, ko, zh). Icons are the kit's generated gradient placeholders, not Store artwork.

Run from `<kit>`:

```text
python tools/nxv_native build <project>
python tools/nxv_native check-win <project>/build/native-app.nxvmod
python tools/nxv_native check-design <project>
python tools/nxv_native package <project>
```

The native UI design checker applies here. Picker behavior, fonts, layout and persistence need interactive verification.

Native GL calls stay on the display-owning thread; defer Busy resize retries to later frames. Script surfaces are host-owned and layouts use draw dimensions. Review input held/pressed/released/cancelled states, focus/suspend, minimum size, docked and handheld modes on the runtime. These are validation tasks, not completed test claims.

See [RESULTS.md](../../../../AI/golden/RESULTS.md) for exact executed commands and evidence. Build outputs were removed; rebuild before packaging. No device performance claim is made.
