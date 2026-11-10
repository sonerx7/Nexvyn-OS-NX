# Automated testing of your app

**English** · [Türkçe](AutomatedTesting.tr.md)

`SDK/Tools/nxvtest` runs your app in an emulator by itself and tells you PASS or FAIL: it installs Nexvyn OS on a fresh
virtual SD card, installs and launches your app, waits, takes screenshots, clicks, presses keys and controller buttons,
then reads the logs and screenshots and checks them against what you expect. It is built for app makers and for AI
coding assistants ([the prompt](../AI/tasks/test-on-emulator.en.md)), and its exit code fits a CI job. The manual loop
behind it is described in the TEST_WORKFLOW guide of Nexvyn OS; this tool automates it.

## 1. What you need

- Python 3.9 or newer (nothing else to install).
- An emulator installation **that already runs Switch homebrew**. You provide it, with whatever it needs to run; the tool
  only starts it. Nexvyn does not provide, link or support emulators, keys or firmware.
- A `NexvynOS.nro`: a local file, or `"latest"` to download the newest public release once.
- Your app: a folder with `app.json`, a `.nxvapp` / `.nxvmod`, or a single `.lua` / `.js` / `.py` file.

## 2. Install and set up

```text
cd SDK/Tools/nxvtest
python nxvtest.py init --emulator-exe "<path to the emulator program>" --os-nro latest --app "<your app>"
python nxvtest.py setup
```

`init` writes `nxvtest.json`. `setup` creates `nxvtest-work/data` (an isolated emulator data folder with an empty SD
card, so your own emulator data and saves are never touched), copies keys and firmware once from the folder named in
`emulator_data_template` (default: a `portable` folder next to the emulator program), puts `NexvynOS.nro` on the SD card and
copies your app into `NexvynOS/Applications/`. Run `setup` again after you change the app; it rebuilds the SD card each time.

The emulator is started as `emulator_exe` plus `emulator_args` (default `-r {data} {nro}`: `{data}` is the isolated
folder, `{nro}` the OS file). If your emulator takes other flags for a data folder and a program to open, change
`emulator_args`.

## 3. Write a scenario

A scenario is a JSON file with a list of `steps`. **Action** steps run inside the OS in order; **expectation** steps are
checked afterwards against the logs and screenshots. See the sample in `SDK/Samples/test-demo/` and the full list of
steps in the [tool README](../Tools/nxvtest/README.en.md).

```json
{
  "name": "start-and-click",
  "time_limit": 80,
  "steps": [
    { "launch": "nxvtest.button" },
    { "wait": 3 },
    { "screenshot": "start" },
    { "wclick": [0.5, 0.6] },
    { "wait": 1 },
    { "screenshot": "after" },
    { "expect_log": "button clicked" },
    { "expect_screenshot": "start" },
    { "expect_screenshots_differ": ["start", "after"] },
    { "expect_no_crash": true },
    { "max_not_responding": 0 }
  ]
}
```

Tips:

- `launch` takes the app id from `app.json`. An id that equals a built-in app's id is installed as `ext.<id>`; use a
  unique id, or check the line `launched <id>` in `system.log`.
- Put `wait 2` to `wait 4` after `launch` so the window exists before you click. Prefer `wclick` (a fraction of the
  window) over pixel clicks. Controller: `{"pad": "a"}`, `{"padhold": ["a", 1]}`; touch: `finger`.
- Make your app print a line for startup and for each action (`print` / `console.log` / `sys.log`); `expect_log` on those
  lines is the most reliable check. The app log is `System/Logs/Apps/<id>.log`.
- Any autorun command the OS knows can be written as `{"raw": "<line>"}`.
- Every run also fails on lines with `error`, `traceback`, `attempt to` or `exception` in the app log
  (`fail_on_app_error`); add regexes to `app_error_ignore` only for messages that are expected.

## 4. Run and read the result

```text
python nxvtest.py run my-scenario.json     (exit code 0 = PASS, 1 = FAIL, 2 = setup problem)
python nxvtest.py report                   (the last summary again)
```

The emulator starts minimized without taking the focus, has a hard time limit (`time_limit`, default 90 s) and is always
stopped afterwards. Results go to `nxvtest-work/runs/<name>-<time>/`:

| File | Content |
|---|---|
| `result.json` | `result` (PASS / FAIL), `checks` (each with `ok` and `detail`), `not_responding`, `crash_lines`, `crash_files`, `app_errors`, `screenshots` |
| `system.log`, `app.log` | The OS log from the start of the scenario, and what your app printed |
| `shots/` | Your screenshots (PNG) |
| `crash_*` | Crash reports, if any |

What the tool flags: "not responding" lines, crash reports and `crash` lines of your app, the emulator exiting before the
scenario ended, a run that hits the time limit (hang), error lines in the app log, missing, empty, all-black or unchanged
screenshots.

Look at one or two key screenshots yourself after each change; do not scan every file.

## 5. CI

`SDK/Samples/test-demo/ci/nxvtest.yml.example` is a GitHub Actions workflow to copy. A hosted runner has no emulator, so use
a self-hosted runner that has one. A FAIL exits with code 1 and fails the job; upload `nxvtest-work/runs/` as the artifact.

## 6. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `emulator_exe not found` | Fix the path in `nxvtest.json` |
| `no emulator data to copy` | Set `emulator_data_template` to the data folder of an emulator installation that already runs homebrew |
| `run_completed` fails: "emulator exited early" | The emulator rejected `emulator_args` or crashed at start. Run the emulator by hand with the same arguments and look at its message |
| `run_completed` fails: "hard time limit" | The scenario is longer than `time_limit`, or the OS hung. Raise `time_limit` or shorten the waits; check `system.log` |
| Screenshot missing | The emulator was too slow to reach that step; add `wait` before it |
| The click does nothing | The window was not there yet (wait longer) or another window had the focus; take a screenshot before the click to see |
| `expect_log` fails but the app logs | Wrong source: `app` is the default; use `"source": "system"` for OS lines. Check the regex against `app.log` |
| A second run starts but nothing happens | Another emulator session uses the same data folder; close it first |
| The download of `latest` fails | No network or API limit: set `os_nro` to a local file |

## 7. What it cannot do

- It cannot judge looks, layout or taste. It checks that screenshots are not blank and that they changed; you look at key pictures.
- Emulator timing is not console timing: it says nothing about frame rate on the console, and a PC is faster than the
  console. A final test on a real console is still needed.
- It does not provide or configure an emulator, keys or firmware.
- It tests one app session per run; there is no parallel run on the same data folder.
- Hardware-only features (real camera, Bluetooth, sleep with the real power state) are not available in an emulator.
