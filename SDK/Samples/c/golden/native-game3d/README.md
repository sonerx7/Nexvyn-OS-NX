# native-game3d

The generated GL template adapted from its SDL frontend to the display ABI. Four tetrahedron faces rotate; confirm/Enter/touch while facing forward increments the score, otherwise resets it. Plus pauses; confirm resumes; Back exits.

Created with the kit command below, then adapted as described above. It recreates the stock template, not these customizations. Use an absent destination. `<kit>` means `SDK/Languages/c/native-kit`; `<project>` is this project's absolute path.

```text
python tools/nxv_native new native-game3d --template gl --dir <repo>/SDK/AI/golden
```

Files: `src/main.cpp, src/window.h`, `app.json`, `icon.png`, and eight complete `lang/*.json` tables (en, tr, de, es, fr, ja, ko, zh). Icons are the kit's generated gradient placeholders, not Store artwork.

Run from `<kit>`:

```text
python tools/nxv_native build <project>
python tools/nxv_native check-win <project>/build/native-game3d.nxvmod
python tools/nxv_native check-design <project>
python tools/nxv_native package <project>
```

A minimal 3D timing mechanic, not a model pipeline or finished game. Visual quality, depth, shader execution and input remain untested at runtime.

Native GL calls stay on the display-owning thread; defer Busy resize retries to later frames. Script surfaces are host-owned and layouts use draw dimensions. Review input held/pressed/released/cancelled states, focus/suspend, minimum size, docked and handheld modes on the runtime. These are validation tasks, not completed test claims.

See [RESULTS.md](../../../../AI/golden/RESULTS.md) for exact executed commands and evidence. Build outputs were removed; rebuild before packaging. No device performance claim is made.
