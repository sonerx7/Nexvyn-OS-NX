# native-emu

The generated toy CPU retained, with overflow-safe memory bounds, a hosted frontend and 500-instruction frame slices. Expected result is 500500; status appears in the window title and log. Confirm resets; Plus pauses; Back exits.

Created with the kit command below, then adapted as described above. It recreates the stock template, not these customizations. Use an absent destination. `<kit>` means `SDK/Languages/c/native-kit`; `<project>` is this project's absolute path.

```text
python tools/nxv_native new native-emu --template emu-skeleton --dir <repo>/SDK/AI/golden
```

Files: `src/cpu.h, src/cpu.cpp, src/main.cpp, src/window.h`, `app.json`, `icon.png`, and eight complete `lang/*.json` tables (en, tr, de, es, fr, ja, ko, zh). Icons are the kit's generated gradient placeholders, not Store artwork.

Run from `<kit>`:

```text
python tools/nxv_native build <project>
python tools/nxv_native check-win <project>/build/native-emu.nxvmod
python tools/nxv_native check-design <project>
python tools/nxv_native package <project>
```

Interpreter only. The obsolete platform JIT placeholder was removed, not enabled. No real machine, guest software, JIT, guard or fault-handler functionality is claimed.

Native GL calls stay on the display-owning thread; defer Busy resize retries to later frames. Script surfaces are host-owned and layouts use draw dimensions. Review input held/pressed/released/cancelled states, focus/suspend, minimum size, docked and handheld modes on the runtime. These are validation tasks, not completed test claims.

See [RESULTS.md](../../../../AI/golden/RESULTS.md) for exact executed commands and evidence. Build outputs were removed; rebuild before packaging. No device performance claim is made.
