# Testing an app or the system without a console

You can test most of an app on a PC, with a scripted run that you can repeat. The real console is still the final
check, but this loop catches crashes, hangs, memory leaks and layout errors early. This guide is for app makers and
for AI coding assistants that run the loop for you (see [`AI/tasks/test-on-emulator.md`](../AI/tasks/test-on-emulator.md)).

## 1. Set up the PC emulator

1. Download the PC emulator of your choice that can run Switch homebrew, and set it up with your own keys and
   firmware. Nexvyn does not provide, link or support those files.
2. Start it once by hand and check that a homebrew `.nro` opens.
3. Pick a separate emulator folder for tests so your own save data stays untouched. Note where its virtual SD card
   folder is: that is the `<SD>` root in this guide.

## 2. Copy the files

- The system: copy `NexvynOS.nro` (one single, current file; old copies in the folder you open can be started by
  mistake) to `<SD>/switch/`, or open it directly from the emulator's menu.
- Your app: build and package it, then copy the `.nxvapp` to `<SD>/NexvynOS/Applications/` (or run
  `python SDK/Tools/nxv/nxv.py install <folder> --sd <SD>`; native apps: `python tools/nxv_native run <app> --sd <SD>`
  from the kit folder). An unsigned package installs with a warning.
- Wait until a large package has finished installing before you launch it (a 55 MB package takes a few seconds).

### The SD card folder

```
<SD>/NexvynOS/
├── autorun.txt             the script, run at every boot while the file exists (see below)
├── autoshots/<name>.png    screenshots taken by the script
├── System/Config/          settings.json
├── System/Logs/            system.log, Apps/<app id>.log, Crashes/
├── Applications/           installed apps (.nxvapp)
└── Users/<name>/           the user's files
```

Remove `autorun.txt` when you are done, or the next boot runs it again.

## 3. The autorun script

If `<SD>/NexvynOS/autorun.txt` exists, Nexvyn OS runs its commands one after another after boot. One command per line;
lines starting with `#` are comments. Typical script:

```text
setup en
wait 4
launch com.example.myapp
wait 6
shot myapp_start
click 640 360
wait 2
shot myapp_after_click
stats after_click
close
log done
exit
```

### Commands

| Command | What it does |
|---|---|
| `wait <seconds>` | pause the script |
| `setup <lang>` | run the first-run setup with defaults in a language (`setup <lang> tour` also starts the Welcome Tour) |
| `setupstep <lang> <step>` | stay on one step of the setup assistant (`intro`, `language`, ... `summary`) |
| `unlock` | pass the lock screen |
| `launch <appId> [arg]` | open an app |
| `close` / `closeall` | close the focused window / every window |
| `minimize` | minimize the focused window |
| `launcher`, `search <text>`, `overview` | open the launcher, search, the window overview |
| `shot <name>` | save a screenshot as `autoshots/<name>.png` |
| `click <x> <y>`, `rclick <x> <y>`, `mclick <x> <y>`, `move <x> <y>` | mouse input in screen pixels |
| `wclick <fx> <fy>`, `wmove <fx> <fy>` | click or point at a fraction (0..1) of the focused window's content |
| `drag`, `scroll` | drag and wheel input |
| `finger <n> down\|move\|up <x> <y>` | a touch contact; two at once make pinch, rotate or a two-finger pan |
| `key [ctrl+\|shift+\|alt+]<name>` | press and release a key |
| `hold <key> <seconds>` | hold a key |
| `text <string>` | type text |
| `dpad <button>` | a controller button, press and release |
| `padhold <button> [seconds]` | hold a controller button (leaving full screen: `minus`, 1.2 s) |
| `dark <0\|1\|2>`, `lang <code>`, `langreq <code>` | switch appearance or language (`langreq` works like the Settings app) |
| `sleep` / `wake` | the suspend and resume steps, without the system really suspending |
| `trust <appId>` / `untrust <appId>` | answer the "Run it?" question of a native app before it is asked, and take it back |
| `enableall` | add every optional app at once |
| `tour [start\|end]`, `tourwait <mode>` | drive the Welcome Tour and wait for a state |
| `winframe` | log the focused window's frame |
| `stats [label]` | one `stats` line in `system.log`: memory, windows, GL objects, mixer, stalls, frame time |
| `log <message>` | write your own line to the log, to mark steps |
| `exit` | end the run |

Notes:

- Older scripts that use `launchpad`, `spotlight` or `mission` keep working.
- The script is for development. Use a short `wait` after `launch` so the window exists before you click or take a shot.
- `trust` is only for your own test apps; run `untrust` at the end so the test leaves the settings as it found them.

## 4. Screenshots and logs

- Screenshots: `shot <name>` writes `<SD>/NexvynOS/autoshots/<name>.png`. Take one at each important step. Look at the
  one or two key pictures yourself; do not try to scan dozens of images.
- Take Store screenshots with the system language set to English (`lang en`).
- Logs: `<SD>/NexvynOS/System/Logs/system.log` (system and runtime lines, `stats`, `stall`, `perf`),
  `System/Logs/Apps/<app id>.log` (what your app printed) and `System/Logs/Crashes/` (crash reports with addresses).
- Lines worth searching for: `not responding`, `stopped` (a crash closed the window), `stall`, `fps`, `heap free`,
  `module load`, `FAIL`, `error`. Add your own `log` marks so you can cut the file by step.
- Read the log with a search (`grep` for the lines above), not from top to bottom.

## 5. The console profile (relative numbers only)

A modern PC is several times faster than the console, so a CPU problem can hide on the PC. A **console profile** makes
the emulator behave more like the console:

- limit the emulator to four CPU cores (different physical cores), put a CPU cap on them (for example 60 percent) and
  run at a lower priority;
- keep the GPU load at console level: 1x resolution, no extra anti-aliasing;
- measure handheld mode and docked mode separately.

On Windows a job object can hold the emulator's CPU limit and affinity; on other systems use the equivalent of
`taskset` and `nice`. The rules for numbers:

- Compare **before and after** a change under the same profile: a ratio, or a frame time in ms.
- **Never quote emulator frame rates as console frame rates.** Console numbers come only from the console.
- The emulated hardware is the console the app runs on. Newer hardware cannot be emulated, so such results are not valid there.
- Write each measurement down: profile (cap, cores, resolution, handheld or docked), version, and what changed.

## 6. The remote test kit (idea)

When the console is far away, a small test program can run a fixed script on the console and send the results to you:

- A special test build runs a script whose first line is `#remote_test`. Only a safe subset of commands is allowed
  (launch, close, click, key, `stats`, and result commands), and the file is deleted when it is read, so a crash can never
  loop it.
- The script marks progress before every step, measures frame rate, stalls, CPU per core and memory for each app, checks
  windows are open or gone, and writes a results table (PASS / FAIL / INFO) and a few small screenshots.
- The test program uploads the results and logs to a private place that the test owner controls; it needs no account of
  the console's user and never sends personal data.
- Keys and tokens are never written into scripts, documents or the repository.

You can build the same idea for your own app: a script that exercises it, a results file, and a person pressing one
button on the console.

## 7. Two user paths

Test both for every change:

1. **Updating user.** Start from a SD card profile that already has settings, installed apps, a theme and data, from
   the previous stable and the previous beta version. After the update, the settings, apps, themes and data must be
   there; a new default must not overwrite an old choice; one-time screens appear once.
2. **Fresh install.** A clean profile: the setup assistant, installing without a network, default theme and settings,
   recommended apps.

For an app: install it over the previous version (data kept, data version handled) and install it new.

## 8. The open / close test

After you add a thread, a timer, an allocation or a window feature, open and close the app ten times in a row:

```text
launch com.example.myapp
wait 3
close
wait 1
```

(repeat ten times, then `stats after_10`). Compare the `stats` line with one taken before: memory in use, windows and
resources must not grow. A hang or a growing number is a bug. Do it again in groups of ten if you still doubt.

## 9. Clean up and etiquette

- **Restore the SD.** Everything you changed in `<SD>` goes back: delete `autorun.txt`, remove test apps and test data,
  restore changed settings, empty `autoshots/` after you moved what you need. A test must leave the profile as it found it.
- **Keep sessions short** (under about 60 seconds each). Long sessions make the emulator's memory grow and hide real
  numbers.
- **Start the emulator minimized**, without taking window focus, so it never jumps in front of whatever you are doing.
- **One emulator at a time, one script at a time.** If several people or agents share a machine, take a lock first (a
  lock file next to the SD folder, with the owner and time), wait for it without spending effort, and release it in a
  `finally`. Kill a stuck emulator only if it is yours.
- Never use your real accounts, keys or save data in a test profile.

## 10. Public tools

| Tool | Use in the loop |
|---|---|
| [`SDK/Tools/nxv`](../Tools/nxv/README.md) | `new`, `check` (manifest, files, icon, translations, permissions), `pack`, `install` into the SD folder, `push` to the console |
| [`SDK/Languages/c/native-kit`](../Languages/c/native-kit/README.md) (`nxv-native`) | native build, `check`, `package`, `run --sd <SD>` |
| [`SDK/Tools/theme`](../Tools/theme/README.md) | `themecheck.py` for theme packs |
| [`SDK/Tools/textures`](../Tools/textures/README.md) | check and prepare PBR texture sets |
| [`SDK/Tools/icon`](../Tools/icon/README.md) | key-art Store icons |

Check first (`nxv check`), then the emulator loop, then the console.
