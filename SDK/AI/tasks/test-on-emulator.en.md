# Task: test my app in the emulator until it passes

**English** · [Türkçe](test-on-emulator.tr.md)

Send after `system-prompt.en.md` + the language pack, once the app files exist. The assistant needs a terminal on a PC that
has an emulator installation that already runs homebrew (the user provides it; never ask for, download or describe keys,
firmware or system files).

```text
Test my Nexvyn OS app automatically with SDK/Tools/nxvtest and fix what fails. Loop until the run is PASS.

Setup (once):
1. Read SDK/Tools/nxvtest/README.en.md and SDK/Guides/AutomatedTesting.en.md.
2. If nxvtest.json does not exist, ask me for the path of the emulator program and run:
   python SDK/Tools/nxvtest/nxvtest.py init --emulator-exe "<path>" --os-nro latest --app "<my app folder>"
   then: python SDK/Tools/nxvtest/nxvtest.py setup
   If setup says there is no emulator data to copy, ask me for the emulator's data folder (emulator_data_template).

Write the scenario (tests/start.json, then one more per feature):
- First step: {"launch": "<the app id from app.json>"}, then {"wait": 3}.
- After every important state take {"screenshot": "<name>"} and add {"expect_screenshot": "<name>"}.
- For every click, key or controller step that changes something visible: take a screenshot before and after and add
  {"expect_screenshots_differ": ["before", "after"]}. Prefer {"wclick": [fx, fy]} (a fraction of the window) over
  absolute pixels.
- Make the app print one clear line (print / sys.log) for each user action and for startup, and check each with
  {"expect_log": "<regex>"}. Do not add log lines only for the test if the app has no use for them; a short
  "ready" line at startup is fine.
- End with {"expect_no_crash": true} and {"max_not_responding": 0}.
- Keep every scenario under 60 seconds of waiting.

Run: python SDK/Tools/nxvtest/nxvtest.py run tests/start.json   (one emulator at a time; never run two runs in parallel)

Read the result:
- The exit code: 0 = PASS, 1 = FAIL, 2 = setup problem (fix the setup, it is not an app failure).
- nxvtest-work/runs/<name>-<time>/result.json: every entry of "checks" with "ok": false is a failure and "detail"
  says why; also read "app_errors", "not_responding", "crash_files".
- app.log (what the app printed, including runtime errors) and system.log next to it. Search them (grep for
  error, traceback, not responding), do not read them top to bottom.

Screenshot rules:
- Open at most two key screenshots per run, as images, and only to check what the checks cannot: layout, clipped or
  overlapping text, the right screen. Do not scan every file and do not try to read text out of pictures.
- A picture that passes "not blank" can still be wrong; if the screen looks wrong, fix the app, and add a log line or
  a screenshot comparison that would have caught it.

Fix and loop:
- Fix the cause in the app (not the test), unless the scenario itself is wrong (a wrong id, a click on the wrong spot,
  too short a wait).
- Never weaken a check to get a PASS: no deleting expectations, no raising max_not_responding, no
  app_error_ignore for a real error. A flaky wait may be made longer.
- After each fix run the same scenario again. Stop after the run is PASS twice in a row, or after 5 rounds without
  progress: then report what you tried and what still fails.

Finish with: the scenario files, the last result summary (PASS or FAIL per check), the screenshot names you looked
at, and what the tool cannot tell (looks, taste, console speed: say that a test on a real console is still needed).
```

Notes for the person using this prompt:

- Replace `<...>` before sending. An id equal to a built-in app's id is installed as `ext.<id>`; the assistant should
  check `system.log` of the first run (the line `launched <id>`).
- Emulator speed is not console speed. Never quote frame rates from the emulator.
