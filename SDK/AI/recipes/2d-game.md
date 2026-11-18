# 2D game

Use for a small 2D game built from scripted simulation and drawing.

## Runtime choice

Lua for a small, bounded 2D simulation with no native dependencies. Choose native for heavy CPU work or large dependency graphs.

## Create

Run script commands from `<repo>`. Run native commands from `<kit>`, which means `SDK/Languages/c/native-kit`. `<project>` means an absolute project path and `<name>` its CMake project name. Create into an absent destination.

```text
python SDK/Tools/nxv/nxv.py create game-2d --profile game --runtime lua --dir SDK/AI/golden/game-2d
```

Golden source: `SDK/AI/golden/game-2d/`. Creation produces the stock template; the golden contains small documented adaptations. Read its README before using it as a starting point.

## File layout and APIs

`main.lua`, `app.json`, `icon.png`, `lang/*.json`. The example moves a target, supports pointer hits and timed confirm/Enter scoring, pauses, and saves the best score.

`gfx`, `input`, `store`, `TR`; lifecycle callbacks on `app`. `gfx.rect`/`gfx.text` render, `input.pressed` is a controller edge, `input.key` reads held keys. `nexvyn.game` is an optional Lua game module for larger games; this golden uses plain gfx/input.

## Performance budget

Game profile: 128 MB RAM budget, 60 fps, even with the explicit Lua override.

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

Allocating/loading assets per frame; treating held input as repeated clicks; replaying a stale press after suspend; scaling game speed by render count; assuming this tiny example meets a full game art/audio quality bar.

Verification evidence and limits: [golden results](../golden/RESULTS.md). The checklists above describe work to perform for a product; they are not claims of completed device or interactive testing.
