# game-2d

A moving target hit by pointer/touch. Confirm/A or Enter scores when it crosses the center region; mistimed confirms reset the score. Escape/Plus pauses. Best score is saved.

Created with the kit command below, then adapted as described above. It recreates the stock template, not these customizations. Use an absent destination. `<kit>` means `SDK/Languages/c/native-kit`; `<project>` is this project's absolute path.

```text
python SDK/Tools/nxv/nxv.py create game-2d --profile game --runtime lua --dir SDK/AI/golden/game-2d
```

Files: `main.lua`, `app.json`, `icon.png`, and eight complete `lang/*.json` tables (en, tr, de, es, fr, ja, ko, zh). Icons are the kit's generated gradient placeholders, not Store artwork.

Run from `<repo>`:

```text
python SDK/Tools/nxv/nxv.py check SDK/AI/golden/game-2d
python SDK/Tools/nxv/nxv.py pack SDK/AI/golden/game-2d -o SDK/AI/golden/.packages/game-2d.nxvapp
```

A deliberately tiny mechanic: no title/game-over flow, audio, art assets, transitions or complete product polish. Input and resize need runtime review.

Native GL calls stay on the display-owning thread; defer Busy resize retries to later frames. Script surfaces are host-owned and layouts use draw dimensions. Review input held/pressed/released/cancelled states, focus/suspend, minimum size, docked and handheld modes on the runtime. These are validation tasks, not completed test claims.

See [RESULTS.md](../RESULTS.md) for exact executed commands and evidence. Build outputs were removed; rebuild before packaging. No device performance claim is made.
