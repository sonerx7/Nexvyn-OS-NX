# Nexvyn OS SDK · App Dev

**English** · [Türkçe](README.tr.md)

Everything for people who make apps, games, themes and fonts for Nexvyn OS: the SDK reference, a quick start and a
template for each language, guides, working samples, prompts for AI assistants, the publishing guide and the `nxv`
command line. Every document exists in English (`NAME.en.md`, `README.md`) and Turkish (`NAME.tr.md`, `README.tr.md`).

## Start here

| Language | 1. Quick start | 2. Template | 3. Guide | 4. Samples |
|---|---|---|---|---|
| **Lua 5.4** (recommended) | [Languages/lua](Languages/lua/README.md) | [template](Languages/lua/template/) | [Developer guide](Guides/DEVELOPER_GUIDE.en.md), [game engine](Guides/GAME_ENGINE.en.md) | [Samples/lua](Samples/lua/) |
| **JavaScript** | [Languages/javascript](Languages/javascript/README.md) | [template](Languages/javascript/template/) | [Apps in JavaScript](Guides/JS_APPS.en.md) | [Samples/javascript](Samples/javascript/) |
| **Python** | [Languages/python](Languages/python/README.md) | [template](Languages/python/template/) | [Apps in Python](Guides/PY_APPS.en.md) | [Samples/python](Samples/python/) |
| **Squirrel** | [Languages/squirrel](Languages/squirrel/README.md) | [template](Languages/squirrel/template/) | [Apps in Squirrel](Guides/SQUIRREL_APPS.en.md) | [Samples/squirrel](Samples/squirrel/) |
| **C** | [Languages/c](Languages/c/README.md) | [template](Languages/c/template/) | [Apps in C](Guides/C_APPS.en.md) | [Samples/c](Samples/c/) |
| **Java** | [Languages/java](Languages/java/README.md) | [template](Languages/java/template/) | [Apps in Java](Guides/JAVA_APPS.en.md) | [Samples/java](Samples/java/) |

Then: the [SDK reference](Reference/SDK.en.md) for every function, the [package format](Guides/NXVAPP_FORMAT.en.md)
for `.nxvapp` / `.nxvtheme` / `.nxvfont`, and [Publishing](Publishing/README.md) to put your work in the App Market.

If in doubt, start with **Lua**: it has the most samples, the best performance and Studio's visual editors.

## What you can build

A Nexvyn OS app is a `.nxvapp` folder with `app.json`, an entry file and `icon.png` (or that folder zipped into one
file). Apps run in their own window and share one SDK:

- **Tools and productivity apps:** `ui` widgets (buttons, text fields, lists, scrolling, dialogs), persistent data
  with `store`, files with `fs`, HTTPS and JSON with `net`, notifications, sharing, Quick Search.
- **2D games:** the `nexvyn.game` engine (scenes, sprites, tilemaps, camera, physics, particles, tweens, touch
  controls) or plain `gfx` drawing; controller, keyboard, touch and motion sensors.
- **3D:** `g3d` on the GPU (lighting, fog, textures, `.obj` / `.stl` loading).
- **Sound:** synthesised tones, system sounds, `.wav` / `.ogg` / `.mp3` files and streamed music.
- **Themes** (`.nxvtheme`: colors, wallpaper, sounds) and **font packs** (`.nxvfont`), no code needed.

## Your first app in 10 minutes

**On the console (no PC needed):**

1. Open **Nexvyn OS Studio**, choose **New Project** and pick a template (e.g. *Blank Lua App*), or open **Samples**.
2. Name the app. The project is installed into `sdmc:/NexvynOS/Applications/` and opens in the editor.
3. Change the text in `main.lua` and press **Run** (Ctrl+R). `print()` output and errors appear in Studio's console.
4. When it is ready, **Export Package** (`~/Documents/<name>.nxvapp`) or follow **Publish to the App Market**.

**On a PC:**

1. Copy a template: `python SDK/Tools/nxv/nxv.py new lua "My App" --author yourname`.
2. Edit `id`, `name`, `description` and `permissions` in `app.json`; write the code.
3. Check it: `python SDK/Tools/nxv/nxv.py check MyApp.nxvapp --sdk <Nexvyn OS source checkout>`.
4. Send it to the console: start the FTP server in **Connect to PC**, then
   `python SDK/Tools/nxv/nxv.py push MyApp.nxvapp --host <console-ip>` (Ryujinx: `nxv install MyApp.nxvapp`).
5. Reopen the Launcher; the app is there. Errors show in the window with line numbers and are logged to
   `sdmc:/NexvynOS/System/Logs/Apps/<id>.log`.

## Contents

| Folder | What is in it |
|---|---|
| [Reference/](Reference/README.md) | The SDK reference (`SDK.en.md`, `SDK.tr.md`), the Java SDK sources, the C header, the SDK version history |
| [Languages/](Languages/README.md) | A quick start and a checked, ready-to-copy template for each language |
| [Guides/](Guides/README.md) | User and developer guides: language guides, package format, game engine, Game Workshop, native modules ... |
| [Samples/](Samples/README.md) | Working sample projects in six languages; [`samples.json`](samples.json) is what Studio's *Samples* reads |
| [AI/](AI/README.md) | Prompts and context packs for writing apps with AI assistants |
| [Publishing/](Publishing/README.md) | Publishing in the App Market: the flow, the review checklist, reports and takedowns |
| [Fonts/](Fonts/) | The system fonts (Inter, JetBrains Mono, the icon font with `Icons.codepoints`) for mock-ups and icons |
| [Tools/](Tools/README.md) | The `nxv` command line: new, check, build, pack, icon, install, push |
