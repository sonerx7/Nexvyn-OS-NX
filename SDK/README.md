# Nexvyn SDK: build complete applications and distinctive games

Current API: **SDK 1.16, Native SDK 1.3, native ABI v1**. Download the complete `SDK/` folder;
keep its directory layout. Documentation is English. Product interfaces must support English,
Turkish, German, Spanish, French, Japanese, Korean and Chinese.

This kit provides the APIs, native headers, templates, fonts, examples and developer tools used
by the system. High production quality also requires your own art direction, content, profiling,
accessibility and real-device testing. The SDK does not guarantee a game's frame rate or scope.

**AI coding agents: start with [AI_GUIDE.md](AI_GUIDE.md)**, an operational manual (runtime choice, toolchain setup,
`app.json`, build, package, test, localization, input, graphics, limits, debugging, Store submission, common errors).
[llms.txt](llms.txt) indexes every document and header; [CHANGELOG.md](CHANGELOG.md) lists SDK-facing changes.

## What's new in SDK 1.16 (Nexvyn OS 1.4.0)

- **Idle apps.** Return `false` from `update` when nothing moves: the app is drawn only on input, a timer or
  `ui.requestFrame()`. Lua, JavaScript, Python 3 (`"python3"`).
- **Multitouch for scripts.** `input.touches()` returns `{id, x, y, phase}` per finger; touch events carry
  `e.touches`. Lua, JavaScript, Python 3 (`"python3"`). Set `"minSdk": "1.16"` when you use these.
- **Python 3 apps start in the background** behind a "Loading" window, so the desktop does not freeze.
- **Script safety.** A faulty script app, including one with a runaway Lua pattern, is stopped alone.
- **Performance panel** (Ctrl+Alt+P, or L+R+ZL+ZR): frame time, skipped frames, RAM and GPU lock time, for tuning.

Details: [Reference/SDK.md](Reference/SDK.md) section 5 and [CHANGELOG.md](CHANGELOG.md).

## Choose a starting point

| Work | Start | Rendering and lifecycle |
|---|---|---|
| Utility, dashboard, editor panel | Lua, JavaScript or `python3` | Shared OS controls and theme; structured `nxui.*` or immediate `ui.*` |
| Native utility or heavy editor | Native app template | ImGui with `nxn_os_ui.h` and shared input backend |
| Original 2D/3D game | Game guide and game/native template | Custom art direction; SDK rendering/input/save/audio building blocks |
| Existing engine or source port | Native port/SDL2 template | Keep engine ownership; adapt window, input, storage and shutdown |
| Compatibility app | Existing frozen language template | Retain earlier contracts; use a primary track for new platform features |

Primary tracks: Lua, JavaScript, CPython (`"runtime": "python3"`) and native C/C++ (`.nxvmod`).
TinyCC C, PocketPy, Squirrel and Java remain compatibility paths. A `targetSdk` or `targetNative`
value is a behavior gate, not proof that a future API version exists. Set minimum versions from
the APIs actually used; never change ABI identity to match an OS release.

## Create, check, package

From the repository root (the folder containing `SDK`):

```text
python SDK/Tools/nxv/nxv.py create MyTool --profile utility --runtime lua --dir MyTool
python SDK/Tools/nxv/nxv.py check MyTool
python SDK/Tools/nxv/nxv.py pack MyTool -o MyTool.nxvapp
```

For native development, change into `SDK/Languages/c/native-kit`:

```text
python tools/nxv_native new mytool --template app --dir projects
python tools/nxv_native build projects/mytool
python tools/nxv_i18n.py --check projects/mytool
python tools/nxv_native package projects/mytool
```

Install the pinned native toolchain described in [the native guide](Guides/NATIVE_GUIDE.md).
The kit's normal creation/build/package commands do not require a private source checkout or
emulator tooling. A native `start.bat` is not part of the workflow. Language/runtime execution
checks and device measurements remain distinct from portable manifest/localization checks.

## Product contracts

1. [Product identity and quality](Guides/PRODUCT_QUALITY.md): system application styling,
   game art direction, responsive layout, performance, accessibility and acceptance.
2. [Input contract](Guides/INPUT_CONTRACT.md): gamepad, touch, mouse, keyboard, multitouch,
   nested scroll, focus and cancellation across all runtimes.
3. [Eight-language contract](Guides/LOCALIZATION_CONTRACT.md): complete dictionaries, tokens,
   native CJK fonts, layout validation and production checks.
4. [Ports and launchers](Guides/PORT_AND_LAUNCHER.md): an integrated engine path, content
   selection, safe settings, real capabilities, save data and reliable desktop return.

## Reference and practical recipes

| Need | Resource |
|---|---|
| Exact callable API | [Reference/SDK.md](Reference/SDK.md) and [API index](Reference/API_INDEX.md) |
| App lifecycle and services | [Developer guide](Guides/DEVELOPER_GUIDE.md) |
| Game composition | [Make a game](Guides/MAKE_A_GAME.md), [engine](Guides/GAME_ENGINE.md), [PBR recipe](Guides/PBR_GAME_RECIPE.md) |
| Art, motion and sound | [Game feel](Guides/GAME_FEEL.md), [sound design](Guides/SOUND_DESIGN.md), [Fonts](Fonts/) |
| Native API, SDL2 and module packaging | [Native guide](Guides/NATIVE_GUIDE.md), [kit](Guides/NATIVE_KIT.md), [compat](Guides/NATIVE_COMPAT.md) |
| State-changing interaction reference | InputLab under `Samples/lua`, `Samples/javascript`, `Samples/python`, `Samples/c`, and native-kit `sdk/native/examples/inputlab` |
| AI-assisted development | [AI rules](AI/AI_RULES.md), [prompt](AI/system-prompt.md), [acceptance checklist](AI/checklist.md) |
| Store delivery | [Publishing](Publishing/PUBLISHING.md) and [review](Publishing/REVIEW.md) |

Reference and diagnostic samples demonstrate APIs; do not submit an unchanged diagnostic panel
as a finished product. The native utility starter includes all eight translations. Translate your
own additions; a dictionary check cannot prove translation quality or find every hard-coded label.

Existing compiled apps continue to work. Rebuild to adopt updated header-only UI/input helpers.
Advanced GPU backends, universal foreign executable support and a native-code sandbox are not
promised by this SDK. Capability checks and actual behavior take precedence over marketing names.
