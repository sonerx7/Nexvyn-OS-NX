# script-utility

A counter saved immediately through store. Uses semantic nxui controls and theme colors.

Created with the kit command below, then adapted as described above. It recreates the stock template, not these customizations. Use an absent destination. `<kit>` means `SDK/Languages/c/native-kit`; `<project>` is this project's absolute path.

```text
python SDK/Tools/nxv/nxv.py create script-utility --profile utility --runtime lua --dir SDK/AI/golden/script-utility
```

Files: `main.lua`, `app.json`, `icon.png`, and eight complete `lang/*.json` tables (en, tr, de, es, fr, ja, ko, zh). Icons are the kit's generated gradient placeholders, not Store artwork.

Run from `<repo>`:

```text
python SDK/Tools/nxv/nxv.py check SDK/AI/golden/script-utility
python SDK/Tools/nxv/nxv.py pack SDK/AI/golden/script-utility -o SDK/AI/golden/.packages/script-utility.nxvapp
```

Only PC-side manifest/locale/package checks were available; UI and lifecycle callbacks were not executed.

Native GL calls stay on the display-owning thread; defer Busy resize retries to later frames. Script surfaces are host-owned and layouts use draw dimensions. Review input held/pressed/released/cancelled states, focus/suspend, minimum size, docked and handheld modes on the runtime. These are validation tasks, not completed test claims.

See [RESULTS.md](../RESULTS.md) for exact executed commands and evidence. Build outputs were removed; rebuild before packaging. No device performance claim is made.
