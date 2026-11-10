# nxvtest: automatic app tests in an emulator

**English** · [Türkçe](README.tr.md)

`nxvtest.py` starts Nexvyn OS in an emulator, installs and launches your app, runs a scripted session (waits, clicks,
keys, controller buttons, screenshots), reads the logs afterwards and prints **PASS** or **FAIL**. One file, Python
3.9+, standard library only, Windows first (Linux works with the same config). Exit code `0` = PASS, `1` = FAIL,
`2` = setup or usage problem, so it fits CI. The full guide: [AutomatedTesting](../../Guides/AutomatedTesting.en.md).

## Quick start

You need an emulator installation **that already runs homebrew** (you provide it; this tool does not ship, set up or
configure one) and a Nexvyn OS `NexvynOS.nro` (or let the tool download the latest release).

```text
python nxvtest.py init --emulator-exe <path to the emulator> --os-nro latest --app <your app>
python nxvtest.py setup
python nxvtest.py run ../../Samples/test-demo/scenarios/button.json
python nxvtest.py report
```

| Command | What it does |
|---|---|
| `init` | Writes `nxvtest.json` (emulator path, OS file or `latest`, work folder, your apps) |
| `setup` | Builds an isolated emulator data folder with an **empty SD card** in the work folder, copies keys and firmware once from `emulator_data_template` (default: a `portable` folder next to the emulator), installs the OS and your app(s). `--fresh` rebuilds everything |
| `run <scenario.json>` | Runs one scenario with the emulator minimized (it never takes the focus), a hard time limit, stops the emulator afterwards, writes `result.json` |
| `report [path]` | Prints the summary of the last run again |

`your app` can be a folder with `app.json`, a `.nxvapp`, a `.nxvmod`, or a single `.lua`, `.js` or `.py` file (the
tool then writes a minimal `app.json`). Several apps: list them in `"apps"`.

## The config (`nxvtest.json`)

| Key | Meaning |
|---|---|
| `emulator_exe` | The emulator program |
| `emulator_args` | Its arguments; `{data}` = the isolated data folder, `{nro}` = the OS file on the test SD card. Default `["-r", "{data}", "{nro}"]`; change it if your emulator uses other flags |
| `emulator_data_template` | An existing emulator data folder to take keys and firmware from (copied once) |
| `os_nro` | Path to `NexvynOS.nro`, or `"latest"` (the newest public release, downloaded once) |
| `work_dir` | Where data, results and screenshots go (default `nxvtest-work`) |
| `apps` | Your app(s) |

## A scenario

```json
{
  "name": "my-app",
  "time_limit": 80,
  "steps": [
    { "launch": "com.me.myapp" },
    { "wait": 3 },
    { "screenshot": "start" },
    { "wclick": [0.5, 0.6] },
    { "wait": 1 },
    { "screenshot": "after_click" },
    { "expect_log": "button clicked" },
    { "expect_screenshot": { "name": "start", "min_size": [640, 360] } },
    { "expect_screenshots_differ": ["start", "after_click"] },
    { "expect_no_crash": true },
    { "max_not_responding": 0 }
  ]
}
```

Each step has exactly one key. **Actions** run inside Nexvyn OS in order: `launch` (app id, or `true` for the first
installed app; an id equal to a built-in app's id is installed as `ext.<id>`, check `system.log`), `wait` (seconds),
`screenshot` (name), `click` / `rclick` / `move` (`[x, y]` screen pixels), `wclick` (`[fx, fy]` fraction of the
focused window), `finger` (`[n, "down|move|up", x, y]`), `key` (`"enter"`, `"ctrl+s"`), `hold` (`[key, seconds]`),
`pad` (`"a"`, `"up"` ...), `padhold` (`[button, seconds]`), `text`, `close`, `closeall`, `log`, `stats`, and `raw`
(any autorun line, see the TEST_WORKFLOW guide of Nexvyn OS). **Expectations** are checked after the run:

| Step | Passes when |
|---|---|
| `expect_log` | a line matches the regex (`"pat"` or `{"pattern": ..., "source": "app", "absent": false}`; `source` is `app`, `system` or `any`; default: the app log) |
| `expect_no_log` | no line matches |
| `expect_screenshot` | the PNG exists; options `min_size`, `not_blank` (default on), `not_black` (default on) |
| `expect_screenshots_differ` | two screenshots are not identical (a click changed something) |
| `expect_closed` | the OS logged the app's window as closed (by the app itself or by a `close` step) |
| `expect_no_crash` | no crash report, no `crash` line for your app, the emulator did not exit early (also checked implicitly) |
| `max_not_responding` | at most N "not responding" lines (default 0) |

Top-level options: `time_limit` (hard limit in seconds, default 90), `boot` (replace the start lines), `fail_on_app_error`
(default true: lines with `error`, `traceback`, `attempt to`, `exception` in the app log fail the run),
`app_error_patterns`, `app_error_ignore` (regexes), `implicit_crash_check`.

## Results

Each run writes `<work_dir>/runs/<name>-<time>/` with `result.json` (machine-readable: every check with `ok` and
`detail`, `not_responding`, `crash_files`, `app_errors`, `screenshots`), `system.log`, `app.log` and `shots/`.
Look at one or two key screenshots yourself; the tool only proves that a picture exists, is not blank and changed.

## What it cannot do

- It cannot judge looks, layout or taste. It checks that a picture is not empty and that it changed.
- Emulator speed is not console speed: do not quote frame rates from it. A final test on a real console is still needed.
- It does not provide an emulator, keys or firmware, and it does not run on hosted CI machines without one.
- Only one emulator session at a time per data folder; close other sessions that use the same emulator folder first.
