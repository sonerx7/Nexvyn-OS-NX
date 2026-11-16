# Build and deliver a Nexvyn product

Current contract: SDK 1.15, Native SDK 1.2, native ABI v1. Keep the downloaded
`SDK/` directory intact. This guide uses the public kit and does not require the
private OS repository.

## Start with the right ownership model

| Product | Starting point | Owner of the UI/render loop |
|---|---|---|
| Utility, editor panel, dashboard | Lua, JavaScript or CPython utility profile | Shared OS UI and lifecycle |
| Native application | Native `app` template | App-side ImGui with OS helpers |
| Original game | Game profile or native `game` template | Your art direction, game state and renderer |
| Existing engine/source port | Native `port` template | Existing engine, adapted input/storage/shutdown |

Lua, JavaScript, CPython and native C/C++ are the primary tracks. TinyCC C and
other frozen runtimes remain compatibility paths. Choose the actual runtime and
renderer explicitly; a `.c` filename alone does not identify the execution path.

## Create a working project

From the directory containing `SDK/`:

```text
python SDK/Tools/nxv/nxv.py create MyTool --profile utility --runtime lua --dir MyTool
python SDK/Tools/nxv/nxv.py check MyTool
python SDK/Tools/nxv/nxv.py pack MyTool -o MyTool.nxvapp
```

For native development, enter `SDK/Languages/c/native-kit`, install the toolchain
described in the [native guide](NATIVE_GUIDE.md), then run:

```text
python tools/nxv_native new mytool --template app --dir projects
python tools/nxv_native build projects/mytool
python tools/nxv_i18n.py --check projects/mytool
python tools/nxv_native package projects/mytool
```

Use `--template game` or `--template port` for their respective lifecycles.
Native projects do not use a web `start.bat` launcher. Build and packaging checks
do not establish that the program runs correctly on a console.

## Make the controls belong to the system

Follow [product quality](PRODUCT_QUALITY.md) and the [input contract](INPUT_CONTRACT.md).
Utility controls use shared typography, colors, spacing, focus and interaction
semantics. Games keep their own visual identity and share reliable input/lifecycle.

Support gamepad, touch and keyboard/mouse. Keep focus visible and reveal focused
controls inside scroll views. Sliders, nested scrolling and drag capture must work
with real input. Multitouch uses stable contact IDs and explicit ownership; do not
assume a single-pointer widget supports concurrent fingers. Cancel interactions
on focus loss, suspend and close without generating a click.

Use one event owner per input stream. In an SDL port, use the shared driver
before adding a second controller-to-mouse implementation. Avoid duplicate clicks
from simultaneous physical, synthetic and touch events. See the
[port and launcher guide](PORT_AND_LAUNCHER.md).

## Preserve data and compatibility

Keep original content and saves outside the replaceable package. Use persistent
app data or a user-chosen folder. Save atomically and preserve old settings during
updates. Import into a new destination; do not merge over or delete a user's files.
Keep recovery possible after interruption or insufficient space.

Declare minimum SDK/native/OS versions from the features actually required. A
`targetSdk` or `targetNative` is a tested behavior contract, not permission to use
unavailable APIs. Preserve ABI v1; query optional capabilities before using them.
Respect renderer, thread/interpreter and resource ownership. Close cooperatively
and retire GPU resources only after their work has completed.

## Localize and check visible milestones

All new apps, games, ports and launchers require complete `en tr de es fr ja ko zh`
dictionaries. The authoring checker validates keys, empty values, duplicates and
format tokens. Review actual translated layouts and text rendering too; see the
[localization contract](LOCALIZATION_CONTRACT.md). Markdown is English only.

Capture and inspect the initial problem, corrected result, important control
states, compact/wide layouts and relevant locale changes. Keep test emulator
windows minimized without activation; prefer guest-generated screenshots. Never
bring a window forward merely to capture it. Keep private user content out of
images and retain build/scenario identity with the evidence.

Check fresh installation, update preservation, offline behavior and close/reopen.
Record host, emulator and physical-device results separately. A screenshot does
not prove input correctness, and emulator frame rate is not console performance.

## Package for the App Market

Keep a stable app ID, original port identity and appropriate category/kind/genre.
Provide eight-language product metadata, an actual product icon and representative
English screenshots. Preserve license notices and source links. Original commercial
game files are not part of a port package. A beta stays in its beta channel until
its acceptance checks are met.

See [Publishing](../Publishing/PUBLISHING.md) and
[review requirements](../Publishing/REVIEW.md). The SDK provides building blocks;
production art, content, accessibility and measured device quality remain part of
your product work.
