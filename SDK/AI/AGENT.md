# AGENT.md: working with the Nexvyn OS SDK as an AI agent

You were asked to "make X" (a game, a port, an emulator port, an app, a tool) for Nexvyn OS using only this
repository. This file is your entry point. Follow it in order.

## 1. Read order (keep context small)

1. This file.
2. [CAPABILITIES.md](CAPABILITIES.md): what is supported, limited, unsupported; budgets. Decide feasibility first.
3. [recipes/README.md](recipes/README.md), then the one recipe that matches the request.
4. The matching golden project: script ones in [golden/](golden/), native ones in `SDK/Samples/c/golden/` (each builds with this kit).
5. Look up APIs by keyword in [map/](map/) (see section 2). Read a card section, not whole headers.
6. Deep reference only when the card is not enough: `SDK/Reference/SDK.md` (script runtimes),
   `SDK/Languages/c/native-kit/sdk/native/include/nexvyn/*.h` (native ABI v1), `SDK/Guides/*.md`.
7. Before you answer: [CHECK.md](CHECK.md) and [checklist.md](checklist.md).

Older context packs stay valid: [llms.txt](llms.txt), [system-prompt.md](system-prompt.md), [AI_RULES.md](AI_RULES.md),
[languages/](languages/), [tasks/](tasks/).

## 2. Look up by keyword, not by reading everything

```sh
grep -ri "<keyword>" SDK/AI/map            # about 1-10 lines: card + section
grep -n  "<symbol>" SDK/Languages/c/native-kit/sdk/native/include/nexvyn/*.h   # confirm in the header
grep -n  "<function>" SDK/Reference/SDK.md  # confirm a script API
```

The map is a starting point; the headers and `SDK.md` are the truth. If a symbol is not in a header or in `SDK.md`,
it does not exist: do not invent it. If the map is wrong, trust the header.

## 3. Choose the runtime

| Request | Runtime | Start command |
|---|---|---|
| Utility, settings panel, calculator, small tool | Lua | `python SDK/Tools/nxv/nxv.py create "Name" --profile utility` |
| Network / REST / feed app | JavaScript | `... create "Name" --profile network` |
| Data processing, scientific tool | Python 3.12 | `... create "Name" --profile data` |
| 2D game (casual, puzzle, arcade) | Lua (`nexvyn.game`) or native | `... create "Name" --profile game --runtime lua` |
| 3D game, heavy 2D, physics | Native C/C++ (GL / NexGFX) | `python tools/nxv_native new Name --template gl` (from the native kit) |
| Port of an existing C/C++ program | Native | `... new Name --template port` or `--template sdl2` |
| Emulator / VM / interpreter | Native (+ opt-in JIT) | `... new Name --template emu-skeleton` |

Use `nxv.py create --recommend-only` to print the profile's runtime, RAM budget and target fps. The `create`
command takes `--runtime lua|js|python|native`; there is no `--lang` flag. `nxv.py new <lang> <name>` creates from
the per-language templates in `SDK/Languages/` (use `--store --kind game` for a Store item layout).

Native kit commands run from `SDK/Languages/c/native-kit` and need devkitA64 (devkitPro) and CMake. Run
`python tools/nxv_native doctor` first.

## 4. Hard rules

- Use only APIs that exist in this SDK. No browser, Node.js, desktop GUI or POSIX-only APIs unless the native
  compat layer documents them.
- Native: ABI v1 is frozen (`NXN_ABI_VERSION` is `1`). Using a newer function requires the matching `minNative` in
  `app.json`. Optional features (`nxn_caps.h`) must have a fallback path.
- Every visible string goes through the translation table: `lang/en.json` plus `tr de es fr ja ko zh`, same keys,
  same placeholders. A package without all 8 locale tables fails the check.
- Window apps must handle resize: a resize that returns Busy keeps the old surface; retry on a later frame; update
  the viewport only after success. Never spin-wait on Busy in the render or audio loop.
- Handle suspend/resume and focus loss: pause audio and game time, save state, never block the frame.
- Input: read action states (pressed / held / released) per frame; support controller and touch where it makes
  sense; never assume a keyboard.
- Files: stay inside the app's own folders; paths that escape the app directory are rejected.
- GL: one context on the render thread. Worker-thread GL and shared contexts are unsupported.
- Performance is acceptance: 60 fps target (frame work P95 <= 16.7 ms), stay inside the profile RAM budget,
  no memory growth across open/close cycles. See CAPABILITIES.md.
- Public text: English docs. Do not use trademarked console or company names in app names, UI or Store text.
- Do not claim device testing you did not do. Emulator or PC numbers are not device numbers.

## 5. Test loop (run it every iteration)

Script apps:

```sh
python SDK/Tools/nxv/nxv.py check <bundle>      # manifest, permissions, icon, locales, sources
python SDK/Tools/nxv/nxv.py pack  <bundle>      # deterministic .nxvapp
python SDK/Tools/nxv/nxv.py install <bundle> --sd <SD root>   # optional: copy to an SD card folder
```

Native apps (from `SDK/Languages/c/native-kit`):

```sh
python tools/nxv_native build <project>          # CMake build to <name>.nxvmod (checked)
python tools/nxv_native check-win <module>       # identity, -fPIC, only imports the OS offers
python tools/nxv_native check-design <project>   # OS design rules for ImGui/NXUI apps
python tools/nxv_native package <project>        # .nxvapp with icon + app.json + lang/
```

A failing check is a bug in your output. Fix it and rerun; do not hand back a project that has not passed.
Full description: [CHECK.md](CHECK.md).

## 6. Deliverable

- Source project folder (app.json, icon, lang/*.json for 8 locales, sources), passing checks, packaged `.nxvapp`.
- A short README: what it does, controls, the commands you ran and their results, what is untested.
- For Store submission: `store.json` and listing text, see `SDK/Publishing/` and [tasks/store-listing.md](tasks/store-listing.md).
