# Test demo

**English** · [Türkçe](README.tr.md)

Two tiny Lua apps and three scenarios for the automatic test tool [`nxvtest`](../../Tools/nxvtest/README.en.md).

| Path | What it is |
|---|---|
| `button-app/` | A window with a label, a button and a bar that grows with every tap. Every tap is printed to the app log. Id `nxvtest.button` |
| `logexit-app/` | Prints two lines and closes its own window after two seconds. Id `nxvtest.logexit` |
| `scenarios/button.json` | Launch, screenshot, two clicks, screenshot; checks the log line, both screenshots, that the clicks changed the picture, no crash, no "not responding". Expected: PASS |
| `scenarios/logexit.json` | Launch, wait; checks that the app logged and closed itself. Expected: PASS |
| `scenarios/fail-demo.json` | Expects a log line that never appears. Expected: FAIL, exit code 1 (shows what a failure looks like) |
| `ci/nxvtest.yml.example` | A GitHub Actions workflow as an example only (needs a self-hosted runner with an emulator) |

## Try it

```text
cd SDK/Tools/nxvtest
python nxvtest.py init --emulator-exe <your emulator> --os-nro latest --app ../../Samples/test-demo/button-app
python nxvtest.py setup
python nxvtest.py run ../../Samples/test-demo/scenarios/button.json
```

Add `logexit-app` to `"apps"` in `nxvtest.json` to run `logexit.json` too. Click positions in the scenarios are
fractions of the window (`wclick`), so they work at any window size.
