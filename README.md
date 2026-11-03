<p align="center"><img src=".github/assets/nexvyn-1.2-teaser.webp" width="100%" alt="Nexvyn OS 1.2 in motion: windows, a Quick Game, the 3D Modeler, a 3D game with an animated hero and animated FBX models"></p>

<h1 align="center"><img src="icon.jpg" width="40" alt=""> Nexvyn OS</h1>

<p align="center"><b>English</b> · <a href="README.tr.md">Türkçe</a></p>

<p align="center"><b>A complete desktop operating system shell for the Nintendo Switch, and a place to make games on it.</b><br>
Real windows, two desktop layouts, a web browser, video, office apps, a game engine, a 3D modeler, a code studio and an
App Market, all in one <code>.nro</code> that you open from the Homebrew Menu. No reboot, no partitioning.</p>

<p align="center">
<a href="https://github.com/sonerx7/Nexvyn-OS-NX/releases/latest"><img src="https://img.shields.io/github/v/release/sonerx7/Nexvyn-OS-NX?label=latest%20release&color=2f7cf6" alt="Latest release"></a>
<a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0--or--later-blue" alt="License: GPL-3.0-or-later"></a>
<a href="SDK/README.md"><img src="https://img.shields.io/badge/SDK-1.8-8a5cf6" alt="SDK 1.8"></a>
<a href="#accessibility-and-languages"><img src="https://img.shields.io/badge/languages-8-22a55e" alt="8 languages"></a>
</p>

<p align="center">
<a href="https://github.com/sonerx7/Nexvyn-OS-NX/releases/latest"><b>⬇ Download NexvynOS.nro</b></a> ·
<a href="#whats-new-in-120">What's new</a> ·
<a href="#sdk-18-make-3d-games-on-the-console">SDK 1.8</a> ·
<a href="SDK/Guides/MAKE_A_GAME.en.md">Make a game</a> ·
<a href="SDK/Guides/USER_GUIDE.en.md">User guide</a> ·
<a href="Store/README.md">App Market</a> ·
<a href="CHANGELOG.md">Release notes</a> ·
<a href="ROADMAP.md">Roadmap</a>
</p>

<p align="center"><img src=".github/assets/desktop-dock.webp" width="100%" alt="The Nexvyn OS desktop in the Dock layout with clock, calendar and world clock widgets"></p>

## At a glance

- **A real desktop.** Overlapping, resizable windows, snapping, virtual desktops, Window Overview, a Launcher, Quick
  Search, Control Center, Notification Center, desktop widgets and right-click menus everywhere.
- **Two layouts.** The **Dock layout** (menu bar on top, Dock below) or the **taskbar layout** (taskbar with a Start
  menu, menus inside each window). Switch any time.
- **More than 70 built-in apps.** Browser, YousTube, Live TV, Radio, Music, Photos, Video Player, Writer, Spreadsheet,
  Presenter, Files, Terminal, Weather, Maps, Calendar, Notes and many more.
- **Make games and apps on the console.** A Game Engine with a three-tap **Quick Game**, a **3D Modeler** with
  professional tools, and **Nexvyn OS Studio** for code in six languages. **SDK 1.8** loads animated `.glb`, `.gltf`
  and `.fbx` models.
- **App Market.** Apps, games, themes and font packs, each one reviewed before it is published.
- **Switch Tools.** Mods, cheats, overlays, clock profiles, system modules, save backups and Turkish patches.
- **For everyone.** 8 languages, a Screen Reader, touch, controller, USB keyboard and mouse, handheld and TV layouts.

---

## What's new in 1.2.0

| | |
|:---:|:---:|
| <img src=".github/assets/quick-game.webp" alt="Quick Game: pick a genre and a world in the Game Engine, press Play now and drive a 3D race car"> | <img src=".github/assets/fbx-walk.webp" alt="Eight animated FBX robots with skinned walk cycles"> |
| **Quick Game:** genre, world, Play now. A 3D race in a few seconds | **3D models with animation:** skinned `.fbx` models walking, drawn on the GPU |
| <img src=".github/assets/modeler-bevel.webp" alt="3D Modeler: loop cut and bevel on a cube"> | <img src=".github/assets/ember-field.webp" alt="Ember Field: a small 3D game with an animated .glb hero"> |
| **3D Modeler:** loop cut and bevel with segments | **Ember Field:** a complete 3D game template with an animated `.glb` hero |

- **SDK 1.8: 3D model files.** `g3d.model` and `g3d.loadModel` open `.glb`, `.gltf` and `.fbx` (also `.obj` and
  `.stl`) with their node tree, materials, embedded textures, skins and animation clips. Skinning runs on the GPU;
  clips play, loop and crossfade, and you can attach objects to bones. Models load in the background, so the game
  keeps drawing.
- **Quick Game in the Game Engine.** Pick a genre (17, six of them new: Runner 2D, Flap Flight, Brick Breaker, Arena,
  Island Adventure 3D, Maze Escape 3D), a world (7) and a few options, and the game is ready to play or to open in the
  editor. New ready-made pieces (cars, enemies that patrol or chase, keys and doors, checkpoints, waves, day and night,
  moving platforms), 40 textures and 67 sound effects made for Nexvyn OS.
- **3D Modeler, professional tools.** Bevel, loop cut, knife, bridge, fill, dissolve, spin and mirror; loop, ring,
  grow, shrink and linked selection; proportional editing, vertex snapping and typed values. A modifier stack (mirror,
  array, subdivision surface, solidify, bevel, smooth, decimate), UV unwrapping, material slots per face, a quad view
  and `.glb` export.
- **Ember Field and the Make-a-Game guide.** A new Studio template and sample game, and
  [Make a game](SDK/Guides/MAKE_A_GAME.en.md): the complete recipe from an empty project to the App Market.
- **A frozen app no longer freezes the desktop.** A Lua, JavaScript or Python callback that runs too long is stopped;
  apps made for SDK 1.8 show *Not responding: Reload / Close*, and older apps are never closed for you: Nexvyn OS asks
  *Wait / Close*. Hold **+** and **−** for 2 seconds to leave a stuck native app.
- **Smoother on real consoles.** Settings, state and logs are written on a background thread, the desktop no longer
  rescans folders every 3 seconds, and 3D apps give their GPU memory back when they close. Slow frames are logged
  with the part that took the time.
- **Native modules work again**, matched to the system build, and switched off after three crashes.

The full list is in the [release notes](CHANGELOG.md).

## SDK 1.8: make 3D games on the console

Nexvyn OS is also a game studio you can hold in your hands. Everything below runs on the console itself; a PC is
optional.

| | |
|:---:|:---:|
| <img src=".github/assets/quick-game-wizard.webp" alt="Quick Game wizard: the genre step with Platformer, Adventure, Space shooter, Puzzle, Racing 3D, 3D Runner, Runner 2D and Flap Flight"> | <img src=".github/assets/quick-game-play.webp" alt="A Racing 3D quick game running: a red car on a track lined with cones and trees"> |
| **Quick Game, step 1:** pick one of 17 genres | **Play now:** the game runs full screen right away |
| <img src=".github/assets/game-engine-3d-editor.webp" alt="Game Engine editor with a 3D Runner level on sand: hierarchy, assets, scene and inspector with the ground texture"> | <img src=".github/assets/studio-ember-field.webp" alt="Nexvyn OS Studio with the Ember Field template open: main.lua and the console"> |
| **Open in editor:** textured 3D levels, hierarchy, assets and inspector | **Studio:** the Ember Field template, ready to run with Ctrl+R |
| <img src=".github/assets/modeler-edit-tools.webp" alt="3D Modeler in Edit Mode: a beveled cube with loop cuts and the Operations panel"> | <img src=".github/assets/modeler-modifiers.webp" alt="3D Modeler: the Add Modifier menu with Mirror, Array, Subdivision Surface, Solidify, Bevel, Smooth and Decimate"> |
| **3D Modeler, Edit Mode:** every operation one tap away | **Modifiers:** a non-destructive stack, applied when you are ready |
| <img src=".github/assets/modeler-quad-view.webp" alt="3D Modeler quad view: top, front, right and perspective views of a car"> | <img src=".github/assets/ember-field-title.webp" alt="Ember Field title screen: the round courier bird with its lamp on a dusk island"> |
| **Quad view:** top, front, right and perspective | **Ember Field:** its own art direction, not a menu template |

**Load and animate a model (Lua):**

```lua
local hero

function app.load()
  -- loads in the background; the title screen keeps drawing
  g3d.loadModel("bundle:/models/hero.glb", 1.6, function(m, err)
    hero = m
    if hero then hero:play("Run", {loop = true, fade = 0.2}) end
  end)
end

function app.update(dt)
  if hero then hero:update(dt) end
end

function app.draw(w, h)
  g3d.begin(0, 0, w, h, 60, 0.1, 200)
  g3d.camera(0, 3, 8, 0, 1, 0)
  if hero then g3d.draw(hero, 0, 0, 0) end
  g3d.finish()
end
```

- **Models:** `.glb` / `.gltf` and `.fbx` (binary and text), plus `.obj` and `.stl`. Embedded or neighbouring textures,
  alpha modes, double-sided and unlit materials. FBX files are converted to Y-up and metres while they load.
- **Animation:** `play` by name or index, loop, speed, reverse, crossfade from the current pose, `stop` with a fade,
  `setTime`; two handles of one file share the data but animate on their own. `model:nodeMatrix` with
  `g3d.drawMatrix` attaches a sword, a lamp or a halo to a bone.
- **Safe by design:** size, vertex, bone and key limits with clear error messages. A broken file only makes that
  `g3d.model` call fail, never the app or the system.
- **Every active runtime:** the same API in Lua, JavaScript, Python and C (`nexvyn.h`). Apps made for SDK 1.0 to 1.7
  keep running unchanged.
- **Start here:** [Make a game](SDK/Guides/MAKE_A_GAME.en.md) (project, models, loading, input, collision, speed on the
  console, art direction, key-art icon, publishing), the [SDK reference](SDK/Reference/SDK.en.md), the
  [Ember Field sample](SDK/Samples/lua/ember-field/) and the prompts in [SDK/AI](SDK/AI/README.md) for AI assistants
  (a context pack plus task prompts such as *make a 3D game with models* and *the store icon*).

## The desktop

Nexvyn OS is not a launcher with a skin. Its windows are real: drag them, resize them from any edge, snap them to half or a
quarter of the screen, maximize them, go full screen or keep one always on top. Every window reopens where you left it.
Virtual desktops switch with a 3D cube, and a crashing app never takes the system down with it.

<p align="center"><img src=".github/assets/windows.webp" width="80%" alt="Opening Photos, Files and Calculator, then Window Overview and minimizing a window"></p>

| | |
|:---:|:---:|
| <img src=".github/assets/desktop-taskbar.webp" alt="The taskbar layout with an aurora wallpaper and widgets"> | <img src=".github/assets/start-menu.webp" alt="The Start menu: search, categories, pinned apps and all apps"> |
| **Taskbar layout:** taskbar, widgets, desktop icons | **Start menu:** pinned apps, all apps, search |
| <img src=".github/assets/launcher-1.2.webp" alt="Launcher with recently used apps and every app by category"> | <img src=".github/assets/window-overview.jpg" alt="Window Overview"> |
| **Launcher:** recently used, then every app by category | **Window Overview:** every window and every desktop at a glance |
| <img src=".github/assets/quick-search.jpg" alt="Quick Search"> | <img src=".github/assets/control-center.jpg" alt="Control Center"> |
| **Quick Search:** apps, files, settings, actions, a calculator and the web | **Control Center:** Wi-Fi, Do Not Disturb, Dark Mode, volume, Now Playing |
| <img src=".github/assets/context-menu.jpg" alt="Desktop right-click menu"> | <img src=".github/assets/files.jpg" alt="Files"> |
| **Right-click menus** on the desktop, icons, files and the Dock | **Files:** sidebar, tabs, list and grid views, Trash, USB drives |

- **Dock layout:** a menu bar with the app's menus, battery, Wi-Fi, clock and search, and a Dock with magnification,
  running-app dots, pinning and auto-hide.
- **Taskbar layout:** a centered or left-aligned taskbar, the Start menu with pinned apps, all apps by category and
  recommendations, live window thumbnails, and minimize, maximize and close buttons on every window.
- **Desktop:** icons, folders with their own icons, shortcuts, rubber-band selection, keyboard navigation and widgets
  (clock, calendar, weather, battery, system, notes, reminders, world clock, radio).
- **Shortcuts:** Ctrl+Space for Quick Search, F3 for Window Overview, F4 for the Launcher, Alt+Tab to switch apps,
  Ctrl+Left/Right for desktops. With a controller, + opens the apps, ZR opens search, L and R switch windows.

### Welcome Tour

Right after setup, a live tour shows the system **on your real desktop**: windows snapping into place, both layouts,
Quick Search, an app built and run in Studio in 20 seconds, a game made in three taps. Every step has *Show me* and
*Let me try*. Replay it any time from **Help > Take the Tour**.

<p align="center"><img src=".github/assets/welcome-tour.jpg" width="80%" alt="Welcome Tour"></p>

## Nexvyn OS Studio: build apps on the console

A complete code studio that runs on the console itself. Write an app, press **Run** and it opens in its own window next
to the code, with its output streaming into the console. Change a line, press **Restart** and the change is live. No PC,
no build step.

| | |
|:---:|:---:|
| <img src=".github/assets/studio-autocomplete.jpg" alt="Nexvyn OS Studio: SDK autocomplete with the SDK reference beside the code"> | <img src=".github/assets/studio-python.jpg" alt="A CPython 3.12 app running next to its code in Nexvyn OS Studio"> |
| **Autocomplete for the whole SDK**, with the reference open at the function | **Real CPython 3.12:** dataclasses, statistics and `print()` in the console |
| <img src=".github/assets/studio-javascript.jpg" alt="A JavaScript app running next to its code in Nexvyn OS Studio"> | <img src=".github/assets/studio-error.jpg" alt="A runtime error with its line number in the console and in the editor"> |
| **JavaScript:** press Run and the app opens beside the code | **Errors with line numbers:** click one, or press F8, to jump to the line |
| <img src=".github/assets/studio-templates.jpg" alt="New Project: templates in Lua, JavaScript, Python, Squirrel, C and Java"> | <img src=".github/assets/studio-samples.jpg" alt="Online samples: a sample page with screenshots and Download and Open"> |
| **20 templates** in six languages, every one runs as is | **Samples:** download a ready-made project and open it in one tap |

- **Six languages:** **Lua 5.4**, **JavaScript**, **Python** (the light runtime or real **CPython 3.12** with its
  standard library), **Squirrel**, **C** compiled on the console by TinyCC, and **Java 8** on miniJVM. New SDK
  features come to Lua, JavaScript, Python and C; Squirrel and Java apps keep working as they are.
- **Autocomplete for the whole SDK:** type `gfx.` and every function appears with its parameters; F1 opens the SDK
  reference right at that function. Syntax errors are marked while you type.
- **Run with a live console:** F5 or Ctrl+R starts the app in its own window, and `print()` and `sys.log()` output
  appears in the console as it happens. **Restart** picks up your changes, or let **Restart on Save** do it for you.
- **Errors you can click:** a runtime error shows its file and line in the console, in the editor and in the app's
  window. Click it or press F8 to jump straight to the line.
- **Templates and samples:** 20 templates (blank apps, platformer, shooter, puzzle, 3D scene, **3D models**,
  **Ember Field**, network, to-do list…) or a sample from the online catalog.
- **Everything around the code:** find and replace across the project, Quick Open, sprite, tilemap and scene editors,
  snapshots, and an **Ask AI** panel that uses the provider and key you set up in AI Chat.
- **Publish to the App Market:** **Export** makes a `.nxvapp` you can share right away, and the **Publish** wizard walks
  you through adding your project to this repository with a pull request; the maintainer reviews it before it appears
  in the App Market.

## Game Engine and 3D Modeler

- **Game Engine:** a 2D and 3D game maker that children can use too. **Quick Game** builds a playable game in three
  steps (17 genres, 7 worlds, difficulty, lives, time limit and controls). Easy mode uses picture cards and drag and
  drop; Advanced mode adds an inspector, layers, event blocks, pixel and tile editors and the generated Lua code.
  19 templates and 5 sample games; share the result as an app or keep going in Studio.
- **3D Modeler:** a scene tree, primitives, move, rotate and scale handles, vertex, edge and face editing with the tools
  above, a modifier stack, UV unwrapping, per-face materials, 64 steps of undo, the quad view, OBJ and STL import and
  export, and `.glb` export for your games.
- **Showcase:** real-time scenes (an island, a night city, a galaxy and more) that show what the renderer can do.

| | |
|:---:|:---:|
| <img src=".github/assets/models-fbx-scene.webp" alt="Animated FBX robots walking in a ring on a dark plane"> | <img src=".github/assets/showcase-3d.jpg" alt="Showcase: Procedural Island"> |
| **SDK 1.8 models:** eight skinned `.fbx` robots in one scene | **Showcase:** a 56,000-triangle island drawn on the GPU |

## Internet and media

| | |
|:---:|:---:|
| <img src=".github/assets/browser.jpg" alt="Browser"> | <img src=".github/assets/youstube.jpg" alt="YousTube"> |
| **Browser** with its own HTML, CSS and JavaScript engine | **YousTube:** search and watch videos |
| <img src=".github/assets/live-tv.jpg" alt="Live TV"> | <img src=".github/assets/radio.jpg" alt="Radio"> |
| **Live TV:** M3U playlists and ready-made channel lists | **Radio:** stations from around the world |

- **Browser:** its own layout engine with JavaScript (DOM, events, fetch, localStorage), CSS transforms, transitions
  and animations, tabs, bookmarks, history, reader mode, downloads and an encrypted password store.
- **YousTube:** search and watch online videos, short videos, comments, chapters, a mini player, playback speed,
  subtitles and quality up to 1080p or 2160p where the stream offers it. Optional sign-in (with your own API client) for
  subscriptions, playlists and comments.
- **Live TV:** your own M3U playlists or the ready-made lists by country, with groups, favorites and recently watched.
- **Radio:** browse stations by country and genre, see what is playing, keep favorites and set a sleep timer. It keeps
  playing after you close the window.
- **Music, Photos and Video Player:** tags, cover art and playlists; your pictures and the console's Album captures;
  MP4, MKV, WebM and more, including HTTPS and HLS streams.
- Also: **Camera** (the controller's IR camera), **Weather**, **Maps**, **News**, **Currency** and **Dictionary**.

<p align="center"><img src=".github/assets/photos.jpg" width="80%" alt="Photos"></p>

### Game Library

Your installed console games with covers, play time and Album captures, launched with one tap (title mode), plus your
PC games through the PC Library. *(Shown here in demo mode, as the emulator has no installed titles.)*

<p align="center"><img src=".github/assets/game-library.jpg" width="80%" alt="Game Library"></p>

## Productivity

| | |
|:---:|:---:|
| <img src=".github/assets/writer.jpg" alt="Writer"> | <img src=".github/assets/spreadsheet.jpg" alt="Spreadsheet"> |
| **Writer:** templates, styles and formatting | **Spreadsheet:** formulas, charts and CSV |

- **Writer, Spreadsheet and Presenter:** documents from templates (letter, report, résumé, meeting notes), formulas
  and charts, presentation themes, transitions and a presentation mode.
- **Files:** drag and drop, copy and move, compress and extract, Trash, USB drives (FAT and exFAT).
- **Terminal** with the `nxvsh` shell, **Code Editor**, **Text Editor**, **Notes**, **Calendar**, **Reminders**,
  **Contacts**, **Calculator**, **Clock** and **Sticky Notes**.
- **Automation:** routines that run at login, at a set time, on a battery level, when the console is docked or when a
  USB drive is plugged in.
- **AI Chat:** chat with the AI model you choose, using your own API key, which stays encrypted on the console.
- **Connect to PC:** a wireless FTP server and USB file transfer (MTP), plus an FTP client.

## App Market

<p align="center"><img src=".github/assets/app-market-games.webp" width="80%" alt="App Market: the Games tab with a featured game"></p>

Apps, games, themes and font packs. The Games and Apps tabs open with a featured pick, the New shelf shows what arrived
in the last two weeks, and every page lists the permissions before you install. Packages are checked with SHA-256 and
signed, updates come in one tap, and a Homebrew section installs well-known homebrew from their GitHub releases.
**Every item is reviewed by the maintainer before it is published.** Browse everything in [Store/](Store/README.md).

## Switch Tools

<p align="center"><img src=".github/assets/switch-tools.jpg" width="80%" alt="Switch Tools in the Launcher"></p>

A folder of tools for Atmosphère users: **Mod Manager** and **Mod Finder**, **Cheat Manager** (turn cheats on and off
in a running game), **Overlays**, **Clock Profiles** (per-game clocks for sys-clk), **System Modules**, **Save Backup**,
**Game Info**, **Patch Manager**, **Crash Reports**, **Atmosphère Settings** and **Homebrew**. **Turkish Patches**
installs the translation patches you download and keeps the original files so you can switch back; **YamaNX** is a
Turkish patch installer for console games. The **Game Library** shows your installed games with play time and Album
captures. Changes made by mods take effect the next time the game starts.

## Accessibility and languages

| | |
|:---:|:---:|
| <img src=".github/assets/accessibility.jpg" alt="Accessibility settings with the Screen Reader"> | <img src=".github/assets/japanese-ui.jpg" alt="Nexvyn OS in Japanese"> |
| **Screen Reader** and accessibility settings | The whole system in **Japanese** |

- **8 languages:** English, Türkçe, Deutsch, Français, Español, 日本語, 中文 and 한국어, with Hangul and romaji input.
- A **Screen Reader** that reads aloud what has focus, with its own voice, rate, pitch and hints.
- Zoom that follows the pointer, inverted colors, text and pointer size, reduced motion and transparency, and large
  window buttons.
- An on-screen keyboard (docked, floating or split) with word suggestions, or the console's own keyboard.

## Make it yours

| | |
|:---:|:---:|
| <img src=".github/assets/settings-appearance.jpg" alt="Appearance settings"> | <img src=".github/assets/dark-mode.jpg" alt="Dark mode"> |
| **Appearance:** light, dark or automatic, accent colors, themes | **Dark mode** |

Wallpapers, accent colors, themes from the App Market, Night Mode on a schedule, Dock size and position, desktop icon
size, several users with their own avatars, and an optional PIN on the lock screen.

## Privacy and security

<p align="center"><img src=".github/assets/privacy.jpg" width="80%" alt="Privacy and Permissions"></p>

- Apps installed from the SD card ask **once** for what they need (network, files and so on). Review and change it in
  **System Settings > Privacy & Permissions**. Native C, Java and module code asks before it runs for the first time.
- Passwords in the Browser and API keys in AI Chat are stored encrypted on the console.
- **App Guard** scans every package before it is installed and shows *No issues found*, *Review* or *Dangerous* with
  the reasons (code that could send your private data away, code downloaded and run at run time, obfuscated code).
  Dangerous apps need a second confirmation. Apps from the store can never read the system's settings, other apps'
  data or the Browser's passwords, even with file access. System files can be viewed but not changed.
  [More](SDK/Guides/APP_GUARD.en.md)
- Anonymous usage statistics are announced when Nexvyn OS first starts. They never include your files, passwords or
  keys, and you can turn them off at any time in **System Settings > About > Privacy**.
- A crashing app is closed on its own; a frozen one is stopped or, for older apps, you choose to wait or close it.
  Documents are saved and restored automatically; an app that crashed is skipped once at the next login, and Safe
  Mode is there when something goes wrong.

## Handheld, TV and input

- **Handheld and TV layouts:** in handheld mode the interface is larger for touch; on the TV it renders at 1080p with
  its own Dock, desktop icons and window frames.
- **Touch:** tap to click, touch and hold to right-click, two-finger scroll, pinch and rotate, swipes from the screen
  edges and three-finger swipes between desktops.
- **Controller:** the left stick moves the pointer, A clicks, X right-clicks, the D-pad jumps between buttons. Hold
  L+R for a second to take the controller back from a game.
- **USB keyboard and mouse** with the shortcuts above.
- **Light on resources:** an idle desktop drops to 20 frames per second, windows in the background reuse their last
  frame, slow work runs on background threads, and images, fonts and 3D memory are released when they are not needed.

---

## Requirements

- A console that boots with **Atmosphère**, using the Atmosphère release that supports your system version (the
  newest release is recommended).
- **System version 22.5.0 or later.** Tested up to **23.0.0**. On a newer system version Nexvyn OS still starts, but
  some features are not tested there yet; Nexvyn OS shows a one-time notice about it.
- About **80 MB** free on the SD card for the `.nro` file (about 72 MB), plus space for your own files.
- No SD card partition and no extra setup is needed.
- **Recommended launch: title mode.** Hold **R** while starting a game, then open Nexvyn OS from the Homebrew menu.
  This gives the full memory (about 3.2 GB). Started from the Album (applet mode) it gets only a few hundred MB:
  large apps, the full browser and launching games are limited, and Nexvyn OS tells you so.

<p align="center"><img src=".github/assets/settings-about.webp" width="70%" alt="System Settings > About: system version, Atmosphère, environment, launch mode and the App SDK version 1.8"></p>

**System Settings > About** shows your system version, Atmosphère version, launch mode and the App SDK version.

## Installation

1. You need a console that runs Atmosphère.
2. Download `NexvynOS.nro` from the [latest release](https://github.com/sonerx7/Nexvyn-OS-NX/releases/latest) and copy it
   to `sdmc:/switch/NexvynOS.nro` on the SD card.
3. Start it from the Homebrew Menu. **Tip:** open the Homebrew Menu by holding **R** while you start a game (title
   mode). Nexvyn OS then gets the full memory, and the system browser, launching console games and PC games work. To
   give it its own icon on the HOME menu, see [the forwarder guide](SDK/Guides/FORWARDER.en.md).
4. The setup assistant asks for your language, keyboard, layout and look. At the end the **Tips** app opens with
   step-by-step tutorials.

From then on, Nexvyn OS updates itself from this repository's releases in **System Settings > Software Update**.
The [user guide](SDK/Guides/USER_GUIDE.en.md) explains everything in detail.

## Online and offline

Nexvyn OS works without a network. These parts need an internet connection:

- **Browser** (web pages) and the **full browser**
- **App Market** (installing and updating apps) and **system updates**
- **AI Chat** (with your own API key)
- **Weather**, **News**, **Currency** (exchange rates), **Maps**, **Dictionary**
- **Radio**, **IPTV** and the **video** app
- **Mod Finder** and the Turkish patch downloads
- Anonymous usage statistics (optional, can be turned off in Settings > Privacy)

These use only your local network: **PC Connect** and the **FTP** server and client.
Everything else (files, notes, calendar, music and video players, games, the Game Engine, the 3D Modeler, the Studio)
works offline.

## Known issues

- **Full browser on untested system versions.** On some consoles with a system version newer than the tested ones,
  opening the full browser stopped the console with an Atmosphère fatal error. Nexvyn OS keeps the full browser off on
  untested system versions and opens the page in its built-in browser instead. You can allow it in Browser settings; if
  the console stops, Nexvyn OS turns it off again after the restart. Please report it with your system and Atmosphère
  versions and the report in `sdmc:/atmosphere/fatal_errors/`.
- **The desktop freezes for a moment, or gets slow after games.** 1.2.0 fixes the most common causes. If it still
  happens, please send us the log file `sdmc:/NexvynOS/System/Logs/system.log` (and `system.prev.log` if you restarted
  since). Lines starting with `stall` name the part of Nexvyn OS that took the time. A slow or failing SD card is a
  common cause.
- **Large 3D models.** Very large `.fbx` or `.glb` files take a few seconds to load and use a lot of memory. Use
  `g3d.loadModel` so the game keeps drawing, and keep each model within the limits in the
  [SDK reference](SDK/Reference/SDK.en.md).

## What is where

```
Store/            what the App Market installs
├── Apps/<category>/<slug>/      apps (and the store pages of the apps that ship with Nexvyn OS)
├── Games/<genre>/<slug>/        games
├── Themes/<slug>/               themes (.nxvtheme)
├── Fonts/<slug>/                font packs (.nxvfont)
└── catalog.json, packages.json  what the console reads; README.md lists everything
SDK/              everything for developers, in English and Turkish
├── Reference/                   the SDK reference, the Java SDK, the C header
├── Languages/<language>/        a quick start and a template per language
├── Guides/                      user and developer guides, Make a game
├── Samples/<language>/<slug>/   working samples (samples.json: Studio's Samples), Ember Field
├── AI/                          prompts for AI assistants
├── Publishing/                  how to publish, the review checklist
├── Fonts/                       the system fonts
└── Tools/nxv/                   the nxv command line
Tools/            repository maintenance: build_store.py, CI
.github/          pull request template, issue forms, CODEOWNERS and the README images
```

| Folder | Start with |
|---|---|
| [`Store/`](Store/README.md) | The full list of apps, games, themes and fonts |
| [`SDK/`](SDK/README.md) | SDK 1.8, "Start here" per language, the reference, guides, samples, publishing |
| [`Tools/`](Tools/README.md) | How the catalog is built and checked |

## For developers

Start with the [SDK](SDK/README.md): a quick start and a template for each language, the
[Make a game](SDK/Guides/MAKE_A_GAME.en.md) recipe, the [developer guide](SDK/Guides/DEVELOPER_GUIDE.en.md), the
[Game Engine guide](SDK/Guides/GAME_ENGINE.en.md), the [`.nxvapp` format](SDK/Guides/NXVAPP_FORMAT.en.md),
[working samples](SDK/Samples) and [prompts for AI assistants](SDK/AI/README.md). You can write the whole app on the
console in Nexvyn OS Studio, or on your computer with the `nxv` command line. Apps are written in English, with
`lang/*.json` files for more languages.

## Publish your app

Anyone can submit an app, game, theme or font; the maintainer reviews every submission before it is published.

1. Make it with the [SDK](SDK/README.md), on your computer or in Nexvyn OS Studio.
2. Fork this repository and add your item under `Store/Apps/<category>/<slug>/`, `Store/Games/<genre>/<slug>/`,
   `Store/Themes/<slug>/` or `Store/Fonts/<slug>/`.
3. Run the checks (`nxv check`, `Tools/build_store.py --check`) and open a pull request with the template.
4. After the automatic checks the maintainer reviews it with the [review checklist](SDK/Publishing/REVIEW.en.md). Once
   it is approved and merged, it appears in the App Market as New.

The whole flow, the content rules, updates, reports and signing: [SDK/Publishing](SDK/Publishing/PUBLISHING.en.md). To
report an item, use **Report This App** on its store page or the
[report form](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=report-app.yml).

## FAQ

**Does it replace the console's system?**
No. Nexvyn OS is a homebrew app that runs on top of the console's own system with Atmosphère. Close it and you are back
in the Homebrew Menu. It uses the console's own services for games, accounts, the Album, battery and Wi-Fi.

**Do I have to reboot or partition my SD card?**
No. Copy one `.nro` file and start it. The `sdmc:/NexvynOS/` folder starts small and grows with your files and apps.

**Which system version do I need?**
22.5.0 or later; it is tested up to 23.0.0. System Settings > About shows yours.

**Why title mode?**
Started from the Album (applet mode), homebrew gets only a small part of the memory. Nexvyn OS works there too and tells
you about it once, but some features (large apps, the full browser, launching games) need the full memory of title
mode (about 3.2 GB).

**Can I make a game without writing code?**
Yes. Open the Game Engine, press **Quick Game**, pick a genre and a world and press **Play now**. Open it in the editor
to change it with picture cards and drag and drop, and share it as an app.

**Can I use my own 3D models?**
Yes. Export `.glb` (or `.fbx`) from your 3D tool or from the built-in 3D Modeler, put it in your app's folder and load
it with `g3d.loadModel`. [Make a game](SDK/Guides/MAKE_A_GAME.en.md) shows the whole path, including animations.

**Can I write apps with an AI assistant?**
Yes. Give it the context pack and a task prompt from [SDK/AI](SDK/AI/README.md); Studio's **Ask AI** panel uses the
provider and key you set up in AI Chat.

**Where are my files?**
In `sdmc:/NexvynOS/Users/<your name>/` (Desktop, Documents, Downloads, Pictures, Music, Movies). Settings and apps live
next to it under `sdmc:/NexvynOS/`.

**Can it start my console games?**
Yes. The Game Library lists your installed games and starts them when Nexvyn OS runs in title mode.

**Can I watch subscription video services in the browser?**
No. Services that protect their videos with DRM do not play in the built-in browser or the full browser. Free video
sites and live streams without DRM usually work.

**Does the browser save my data?**
The built-in browser saves history, bookmarks, cookies and downloads in your user folder
(`sdmc:/NexvynOS/Users/<name>/Library/Application Support/browser/`). Saved passwords are encrypted. Private tabs keep
no history. Browser settings > Privacy clears history, cookies and site data (saved passwords stay until you remove
them).

**Is it safe to use mods and cheats?**
The Switch Tools only write to the SD card. Playing online with modified games or cheats can get an account banned, so
use them offline.

**Does it run in an emulator?**
The screenshots and videos were captured in an emulator. Features that need real hardware, such as USB drives, MTP
and the camera, only work on a console.

**How do I get updates?**
System Settings > Software Update downloads the new release, keeps a backup of the old one and installs it. Your apps,
files and settings stay.

## Roadmap

Where Nexvyn OS goes next, with measurable goals: faster starts, no lost work, a Screen Reader that covers every
control, more languages, a better browser and a bigger App Market. Read the [roadmap](ROADMAP.md) and see
[how you can help](ROADMAP.md#how-to-help): publish an app, report a bug or translate.

## License and credits

Nexvyn OS is **GPL-3.0-or-later** ([LICENSE](LICENSE)); third-party components and their licenses are listed in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Items in the store come under the same license unless they state
otherwise (font packs carry their own license, mostly the SIL Open Font License). YamaNX is based on YamaNX by SertAy.
Nintendo Switch is a trademark of Nintendo; this project is not affiliated with Nintendo. Content shown in the Browser,
YousTube, Live TV and Radio belongs to its owners.

Developed by **Soner Çakır** · [github.com/sonerx7](https://github.com/sonerx7) — designed and directed by its author and
built with the help of AI coding tools.
