<p align="center"><img src=".github/assets/nexvyn-os-teaser.webp" width="100%" alt="Nexvyn OS in motion: windows, Studio, Game Engine and 3D"></p>

<h1 align="center"><img src="icon.jpg" width="40" alt=""> Nexvyn OS</h1>

<p align="center"><b>English</b> · <a href="README.tr.md">Türkçe</a></p>

<p align="center"><b>A complete desktop operating system shell for the Nintendo Switch.</b><br>
Real windows, two desktop layouts, a web browser, video, Live TV, office apps, a game engine, a 3D modeler, a code studio
and an App Market, all in one <code>.nro</code> that you open from the Homebrew Menu. No reboot, no partitioning.</p>

<p align="center">
<a href="https://github.com/sonerx7/Nexvyn-OS-NX/releases/latest"><img src="https://img.shields.io/github/v/release/sonerx7/Nexvyn-OS-NX?label=latest%20release&color=2f7cf6" alt="Latest release"></a>
<a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0--or--later-blue" alt="License: GPL-3.0-or-later"></a>
<a href="SDK/README.md"><img src="https://img.shields.io/badge/SDK-1.6-8a5cf6" alt="SDK 1.6"></a>
<a href="#accessibility-and-languages"><img src="https://img.shields.io/badge/languages-8-22a55e" alt="8 languages"></a>
</p>

<p align="center">
<a href="https://github.com/sonerx7/Nexvyn-OS-NX/releases/latest"><b>⬇ Download NexvynOS.nro</b></a> ·
<a href=".github/assets/nexvyn-os-demo.mp4"><b>▶ Watch the 1-minute demo</b></a> ·
<a href="SDK/Guides/USER_GUIDE.en.md">User guide</a> ·
<a href="Store/README.md">App Market</a> ·
<a href="SDK/README.md">SDK</a> ·
<a href="CHANGELOG.md">Release notes</a>
</p>

<p align="center"><a href=".github/assets/nexvyn-os-demo.mp4"><img src=".github/assets/hero-desktop.jpg" width="100%" alt="The Nexvyn OS desktop with the Browser, YousTube, Photos and the Terminal open"></a></p>

## At a glance

- **A real desktop.** Overlapping, resizable windows, snapping, virtual desktops, Window Overview, a Launcher, Quick
  Search, Control Center, Notification Center, desktop widgets and right-click menus everywhere.
- **Two layouts.** The **Dock layout** (menu bar on top, Dock below) or the **taskbar layout** (taskbar with a Start
  menu, menus inside each window). Switch any time.
- **More than 70 built-in apps.** Browser, YousTube, Live TV, Radio, Music, Photos, Video Player, Writer, Spreadsheet,
  Presenter, Files, Terminal, Weather, Maps, Calendar, Notes and many more.
- **Create on the console.** Nexvyn OS Studio for apps in six languages, the Game Engine for 2D and 3D games and a full
  3D Modeler, with an SDK, samples and guides.
- **App Market.** Apps, games, themes and font packs, each one reviewed before it is published.
- **Switch Tools.** Mods, cheats, overlays, clock profiles, system modules, save backups and Turkish patches.
- **For everyone.** 8 languages, a Screen Reader, touch, controller, USB keyboard and mouse, handheld and TV layouts.

---

## The desktop

Nexvyn OS is not a launcher with a skin. Its windows are real: drag them, resize them from any edge, snap them to half or a
quarter of the screen, maximize them, go full screen or keep one always on top. Every window reopens where you left it.
Virtual desktops switch with a 3D cube, and a crashing app never takes the system down with it.

| | |
|:---:|:---:|
| <img src=".github/assets/window-overview.jpg" alt="Window Overview"> | <img src=".github/assets/taskbar-start-menu.jpg" alt="Taskbar layout with the Start menu"> |
| **Window Overview:** every window and every desktop at a glance | **Taskbar layout** with the Start menu: pinned apps, all apps, search |
| <img src=".github/assets/launcher.jpg" alt="Launcher"> | <img src=".github/assets/quick-search.jpg" alt="Quick Search"> |
| **Launcher:** every app, sorted by category | **Quick Search:** apps, files, settings, actions, a calculator and the web |
| <img src=".github/assets/control-center.jpg" alt="Control Center"> | <img src=".github/assets/notification-center.jpg" alt="Notification Center"> |
| **Control Center:** Wi-Fi, Do Not Disturb, Dark Mode, volume, Now Playing | **Notification Center** with widgets |
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

## Internet and media

| | |
|:---:|:---:|
| <img src=".github/assets/browser.jpg" alt="Browser"> | <img src=".github/assets/youstube.jpg" alt="YousTube"> |
| **Browser** with its own HTML, CSS and JavaScript engine | **YousTube:** search and watch videos |
| <img src=".github/assets/live-tv.jpg" alt="Live TV"> | <img src=".github/assets/radio.jpg" alt="Radio"> |
| **Live TV:** M3U playlists and ready-made channel lists | **Radio:** stations from around the world |

- **Browser:** its own layout engine with JavaScript (DOM, events, fetch, localStorage), CSS transforms, transitions
  and animations, tabs, bookmarks, history, reader mode, downloads and an encrypted password store.
- **YousTube:** search and watch YouTube videos, Shorts, comments, chapters, a mini player, playback speed, subtitles
  and quality up to 1080p or 2160p where the stream offers it. Optional sign-in (with your own API client) for
  subscriptions, playlists and comments.
- **Live TV:** your own M3U playlists or the ready-made lists by country, with groups, favorites and recently watched.
- **Radio:** browse stations by country and genre, see what is playing, keep favorites and set a sleep timer. It keeps
  playing after you close the window.
- **Music, Photos and Video Player:** tags, cover art and playlists; your pictures and the console's Album captures;
  MP4, MKV, WebM and more, including HTTPS and HLS streams.
- Also: **Camera** (the Joy-Con IR camera), **Weather**, **Maps**, **News**, **Currency** and **Dictionary**.

<p align="center"><img src=".github/assets/photos.jpg" width="80%" alt="Photos"></p>

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

## Create: apps, games and 3D on the console

| | |
|:---:|:---:|
| <img src=".github/assets/studio.jpg" alt="Nexvyn OS Studio"> | <img src=".github/assets/game-engine-editor.jpg" alt="Game Engine editor"> |
| **Nexvyn OS Studio:** write the code, press Run, the app opens next to it | **Game Engine:** drag, drop and press Play |
| <img src=".github/assets/game-engine-3d.jpg" alt="Game Engine in 3D"> | <img src=".github/assets/modeler-3d.jpg" alt="3D Modeler"> |
| **Game Engine** in 3D | **3D Modeler:** a house from the samples |

- **Nexvyn OS Studio:** projects from 15 templates in six languages: **Lua 5.4**, **JavaScript**, **Python** (the
  light runtime or real **CPython 3.12** with its standard library), **Squirrel**, **C** and **Java**. Syntax
  highlighting, live error checking, autocomplete, a console, sprite, tilemap and scene editors, the SDK reference at
  your side and packaging into a `.nxvapp` in one step.
- **Game Engine:** a 2D and 3D game maker that children can use too. The Game wizard builds a playable game in three
  steps (6 genres, 7 worlds). Easy mode uses picture cards and drag and drop; Advanced mode adds an inspector, layers,
  event blocks, pixel and tile editors and the generated Lua code. 13 templates and 5 sample games; share the result as
  an app or keep going in Studio.
- **3D Modeler:** a scene tree, primitives, move, rotate and scale handles, vertex, edge and face editing, 64 steps of
  undo, and OBJ and STL import and export.
- **SDK 1.6:** drawing, UI widgets, files, JSON, storage, HTTPS, audio synthesis, notifications, motion sensors, the
  `nexvyn.game` 2D engine (scenes, sprites, tilemaps, camera, physics, tweens, particles) and the `g3d` GPU renderer.
- **Showcase:** six real-time scenes (an island, a night city, a galaxy and more) that show what the renderer can do.

| | |
|:---:|:---:|
| <img src=".github/assets/game-engine-play.jpg" alt="A game made in Game Engine, running"> | <img src=".github/assets/showcase-3d.jpg" alt="Showcase: Procedural Island"> |
| A Game Engine game, running | **Showcase:** a 56,000-triangle island drawn on the GPU |

## App Market

<p align="center"><img src=".github/assets/app-market.jpg" width="80%" alt="App Market: New and Featured"></p>

Apps, games, themes and font packs. The New shelf shows what arrived in the last two weeks, Featured picks one to try,
and every page lists the permissions before you install. Packages are checked with SHA-256, updates come in one tap, and
a Homebrew section installs well-known homebrew from their GitHub releases. **Every item is reviewed by the maintainer
before it is published.** Browse everything in [Store/](Store/README.md).

## Switch Tools

<p align="center"><img src=".github/assets/switch-tools.jpg" width="80%" alt="Switch Tools in the Launcher"></p>

A folder of tools for Atmosphère users: **Mod Manager** and **Mod Finder**, **Cheat Manager** (turn cheats on and off
in a running game), **Overlays**, **Clock Profiles** (per-game clocks for sys-clk), **System Modules**, **Save Backup**,
**Game Info**, **Patch Manager**, **Crash Reports**, **Atmosphère Settings** and **Homebrew**. **Turkish Patches**
installs the translation patches you download and keeps the original files so you can switch back; **YamaNX** is a
Turkish patch installer for Switch games. The **Game Library** shows your installed games with play time and Album
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
- A crashing app is closed on its own and a frozen one can be forced to quit; documents are saved and restored
  automatically; an app that crashed is skipped once at the next login, and Safe Mode is there when something goes wrong.

## Handheld, TV and input

- **Handheld and TV layouts:** in handheld mode the interface is larger for touch; on the TV it renders at 1080p with
  its own Dock, desktop icons and window frames.
- **Touch:** tap to click, touch and hold to right-click, two-finger scroll, pinch and rotate, swipes from the screen
  edges and three-finger swipes between desktops.
- **Controller:** the left stick moves the pointer, A clicks, X right-clicks, the D-pad jumps between buttons. Hold
  L+R for a second to take the controller back from a game.
- **USB keyboard and mouse** with the shortcuts above.
- **Light on resources:** an idle desktop drops to 20 frames per second, windows in the background reuse their last
  frame, and images and fonts are released when memory runs low.

---

## Installation

1. You need a Nintendo Switch that runs Atmosphère.
2. Download `NexvynOS.nro` from the [latest release](https://github.com/sonerx7/Nexvyn-OS-NX/releases/latest) and copy it
   to `sdmc:/switch/NexvynOS.nro` on the SD card.
3. Start it from the Homebrew Menu. **Tip:** open the Homebrew Menu by holding **R** while you start a game (title
   mode). Nexvyn OS then gets the full memory, and the system browser, launching Switch games and PC games work. To
   give it its own icon on the HOME menu, see [the forwarder guide](SDK/Guides/FORWARDER.en.md).
4. The setup assistant asks for your language, keyboard, layout and look. At the end the **Tips** app opens with
   step-by-step tutorials.

From then on, Nexvyn OS updates itself from this repository's releases in **System Settings > Software Update**.
The [user guide](SDK/Guides/USER_GUIDE.en.md) explains everything in detail.

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
├── Guides/                      user and developer guides
├── Samples/<language>/<slug>/   working samples (samples.json: Studio's Samples)
├── AI/                          prompts for AI assistants
├── Publishing/                  how to publish, the review checklist
├── Fonts/                       the system fonts
└── Tools/nxv/                   the nxv command line
Tools/            repository maintenance: build_store.py, CI
.github/          pull request template, issue forms, CODEOWNERS, README images and the demo video
```

| Folder | Start with |
|---|---|
| [`Store/`](Store/README.md) | The full list of apps, games, themes and fonts |
| [`SDK/`](SDK/README.md) | "Start here" per language, the reference, guides, samples, publishing |
| [`Tools/`](Tools/README.md) | How the catalog is built and checked |

## For developers

Start with the [SDK](SDK/README.md): a quick start and a template for each language, the
[developer guide](SDK/Guides/DEVELOPER_GUIDE.en.md), the [Game Engine guide](SDK/Guides/GAME_ENGINE.en.md), the
[`.nxvapp` format](SDK/Guides/NXVAPP_FORMAT.en.md) and [working samples](SDK/Samples). You can write the whole app on the
console in Nexvyn OS Studio, or on your computer with the `nxv` command line.

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
No. Copy one `.nro` file and start it.

**Why title mode?**
Started from the Album (applet mode), homebrew gets only a small part of the memory. Nexvyn OS works there too and tells
you about it once, but some features need the full memory of title mode.

**Where are my files?**
In `sdmc:/NexvynOS/Users/<your name>/` (Desktop, Documents, Downloads, Pictures, Music, Movies). Settings and apps live
next to it under `sdmc:/NexvynOS/`.

**Can it start my Switch games?**
Yes. The Game Library lists your installed games and starts them when Nexvyn OS runs in title mode.

**Is it safe to use mods and cheats?**
The Switch Tools only write to the SD card. Playing online with modified games or cheats can get an account banned, so
use them offline.

**Does it run in an emulator?**
The screenshots and the demo were captured in an emulator. Features that need real hardware, such as USB drives, MTP
and the camera, only work on a console.

**How do I get updates?**
System Settings > Software Update downloads the new release, keeps a backup of the old one and installs it.

## License and credits

Nexvyn OS is **GPL-3.0-or-later** ([LICENSE](LICENSE)); third-party components and their licenses are listed in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Items in the store come under the same license unless they state
otherwise (font packs carry their own license, mostly the SIL Open Font License). YamaNX is based on YamaNX by SertAy.
Nintendo Switch is a trademark of Nintendo; this project is not affiliated with Nintendo. Content shown in the Browser,
YousTube, Live TV and Radio belongs to its owners.

Developed by **Soner Çakır** · [github.com/sonerx7](https://github.com/sonerx7) — designed and directed by its author and
built with the help of AI coding tools.
