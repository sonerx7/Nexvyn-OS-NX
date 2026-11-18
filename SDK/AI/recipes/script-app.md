# Script app

Use for utilities, network clients and data apps that fit SDK scripting.

## Runtime choice

Lua for small utilities (24 MB/60 fps); JavaScript for network/JSON work (32 MB/60 fps); Python for data/stdlib work (48 MB/60 fps). The two goldens show utility and network choices.

## Create

Run script commands from `<repo>`. Run native commands from `<kit>`, which means `SDK/Languages/c/native-kit`. `<project>` means an absolute project path and `<name>` its CMake project name. Create into an absent destination.

```text
python SDK/Tools/nxv/nxv.py create script-utility --profile utility --runtime lua --dir SDK/AI/golden/script-utility
python SDK/Tools/nxv/nxv.py create script-network --profile network --runtime js --dir SDK/AI/golden/script-network
```

Golden source: `SDK/AI/golden/script-utility/` and `SDK/AI/golden/script-network/`. Creation produces the stock template; the golden contains small documented adaptations. Read its README before using it as a starting point.

## File layout and APIs

`main.lua` or `main.js`, `app.json`, `icon.png`, `lang/*.json`. Utility persists a counter; network performs a user-initiated HTTPS probe with loading/offline/error states and stale-reply suppression.

Host globals `nxui`, `gfx`, `theme`, `TR`, `store`, `sys`, `net`; `app` lifecycle callbacks. JavaScript is an ES module using `export default`; use SDK `net.get`, not browser APIs. Check `sys.online()` and declare only the permissions actually used.

## Performance budget

Utility 24 MB, network 32 MB, data 48 MB; all 60 fps. Calculator profile is 16 MB if that narrower workload fits.

These are proposed device targets, not measurements: frame work P95 <= 16.667 ms at 60 Hz; late presents <= 1%; resize request-to-present P95 <= 50 ms; launch-to-window <= 50 ms; memory growth <= ~43 KB per open/close cycle after warm-up; GPU lock wait P95 <= 5 ms. There is no guaranteed RAM allocation per app. Host or emulator results are never device measurements.

## Checklist

- [ ] No compile step is needed for Lua/JavaScript. From `<repo>` run `python SDK/Tools/nxv/nxv.py check <project>`; require exit 0.
- [ ] Run the app on the console (Studio > Run, or copy it to `sdmc:/NexvynOS/Applications/`): the default PC-side check does not execute callbacks or prove language/runtime correctness.
- [ ] Design: inspect layout at minimum size, theme/accessibility changes, long text and all input methods. Native `check-design` is not applicable to scripts.
- [ ] Verify complete `lang/{en,tr,de,es,fr,ja,ko,zh}.json`, every TR key and identical placeholders; use UTF-8 and test CJK glyphs.
- [ ] Run `python SDK/Tools/nxv/nxv.py pack <project> -o <repo>/SDK/AI/golden/.packages/<name>.nxvapp`; output must be outside the source bundle. Store packages may be unsigned; signing covers the file manifest.
- [ ] Exercise `app.suspend`, `app.resume`, `app.focus` and `app.close`: save state, pause simulation/audio, ignore stale network replies and reset clocks after resume.
- [ ] Resize: derive layout from draw dimensions. Script rendering is host-owned; do not call native display APIs or spin while the host reports Busy. Verify recovery during resize transitions.
- [ ] Test action held, pressed, released and cancellation independently. Use edges for one-shot actions and cancel captures on focus loss/suspend; no phantom activation on resume.
- [ ] Test docked/handheld, keyboard, controller cursor/actions and touch, minimum-size windows and fullscreen changes.
- [ ] Measure the proposed device budget on hardware and remove package outputs after verification.

## Common mistakes

Using --lang with create (no such flag); assuming browser globals exist; ignoring Promise rejections; doing network/file work in draw; accepting a late reply after close; English-only locale dictionaries; expecting PC-side checks to execute the app.

Verification evidence and limits: [golden results](../golden/RESULTS.md). The checklists above describe work to perform for a product; they are not claims of completed device or interactive testing.
