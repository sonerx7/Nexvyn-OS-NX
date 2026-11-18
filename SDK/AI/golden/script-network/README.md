# script-network

An explicit HTTPS GET to https://example.com/; no credentials or uploads. Checks offline state, displays loading/result and discards late replies after suspend/close.

Created with the kit command below, then adapted as described above. It recreates the stock template, not these customizations. Use an absent destination. `<kit>` means `SDK/Languages/c/native-kit`; `<project>` is this project's absolute path.

```text
python SDK/Tools/nxv/nxv.py create script-network --profile network --runtime js --dir SDK/AI/golden/script-network
```

Files: `main.js`, `app.json`, `icon.png`, and eight complete `lang/*.json` tables (en, tr, de, es, fr, ja, ko, zh). Icons are the kit's generated gradient placeholders, not Store artwork.

Run from `<repo>`:

```text
python SDK/Tools/nxv/nxv.py check SDK/AI/golden/script-network
python SDK/Tools/nxv/nxv.py pack SDK/AI/golden/script-network -o SDK/AI/golden/.packages/script-network.nxvapp
```

Network responses, TLS, failure UI and callbacks were not executed. This is a connection probe, not an API client.

Native GL calls stay on the display-owning thread; defer Busy resize retries to later frames. Script surfaces are host-owned and layouts use draw dimensions. Review input held/pressed/released/cancelled states, focus/suspend, minimum size, docked and handheld modes on the runtime. These are validation tasks, not completed test claims.

See [RESULTS.md](../RESULTS.md) for exact executed commands and evidence. Build outputs were removed; rebuild before packaging. No device performance claim is made.
