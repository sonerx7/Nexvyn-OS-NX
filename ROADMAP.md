# Nexvyn OS roadmap

**English** · [Türkçe](ROADMAP.tr.md)

Nexvyn OS 1.0 came out on 30 October 2026. This page says where it goes next: our goals, the numbers we will measure
them by and how you can help. Dates are targets and can move. The numbers will not quietly get softer: if a goal
slips, this page says so and says why.

## Vision

**The best desktop you can hold in your hands.** A complete desktop on the Nintendo Switch that feels as natural with a
controller or your fingers as with a mouse, that lets you make apps and games on the console itself, and that never
loses your work or your trust.

## Principles

1. **Console first.** The controller and the touch screen are first-class, never an afterthought. Every feature has to
   work in handheld mode at 720p and on a TV at 1080p, and every window action has to be reachable with a controller.
2. **Your work is safe.** Documents save themselves, a crashing app closes only its own window, Safe Mode is there when
   something goes wrong and an update can always be undone.
3. **Privacy.** No account is needed anywhere. Apps ask once for what they need, and the App Market lists every
   permission before you install. Usage statistics are announced the first time Nexvyn OS starts, listed in Settings
   and can be turned off; they never contain your files, passwords or keys, and the console never takes commands back.
   See [App Guard](SDK/Guides/APP_GUARD.en.md).
4. **Compatibility promise.** SDK functions are never removed, behaviour changes only reach apps that target the new
   SDK, and every release is tested against every app in the App Market. See
   [App compatibility](SDK/Guides/COMPATIBILITY.en.md).
5. **An open App Market.** Anyone can submit an app, game, theme or font. Every item is reviewed before it is published,
   packages are checked, and there are no accounts and no fees. See [Publishing](SDK/Publishing/PUBLISHING.en.md).
6. **Measured, not claimed.** Every goal below has a number, a device and a way to measure it. The measurements are
   published with each release.

## Where we are: 1.0

- 79 built-in apps and 168 items in the App Market (apps, games, themes and font packs).
- One SDK in six programming languages, with Nexvyn OS Studio and the Game Engine on the console.
- 8 interface languages, each one 100% translated.
- Real overlapping windows, two desktop layouts, Quick Search, a browser with its own engine, media, office apps and
  the Switch Tools.

## How we measure

On two consoles: an original Nintendo Switch and an OLED model, started in title mode, with a 64 GB A1 microSD card and a
profile with about 5,000 files. Results in applet mode (started from the Album, with less memory) are published
separately. Nexvyn OS logs its own boot stages, frame rate and timings, so anyone can repeat a measurement on their
console.

## Release goals

### 1.1: Measured and safe (target: December 2026)

| Goal | Target |
|---|---|
| Measurements | Boot, app launch, dragging, search, memory and battery numbers published for both consoles |
| Cold start | From the Homebrew Menu to a desktop that responds: **under 4 seconds** |
| App launch | Built-in apps open in **under 300 ms** (median) |
| Quick Search | Results in **under 50 ms** per keystroke with 15,000 files |
| Smooth windows | Dragging a window at **60 fps** in handheld mode with four windows open |
| No lost work | Every built-in app that edits your content saves itself; after a power cut at most the **last 10 seconds** of edits are missing |
| Screen Reader | Speaks **all 8** interface languages; **90%** of the controls in the desktop and the 20 most used apps are labeled |
| Browser | `position: absolute` and `fixed`; **63 of 70** automatic tests pass on a console; a published list of 40 everyday sites to test against |
| Safe updates | If a new version fails to start twice, Nexvyn OS offers to go back to the previous one |
| Stability | **98%** of sessions end without a crash; every feature still marked "not verified on a console" is verified or labeled experimental |
| Privacy | Usage statistics carry no names or account details; Settings lists every field that is sent |
| App Market | **190 items**, the first **5 from outside makers**, every submission reviewed within 7 days |

### 1.2: Productive (target: early 2027)

| Goal | Target |
|---|---|
| Speed | Cold start **under 3 seconds**; back from sleep and ready **under 1 second** |
| Smooth windows | **60 fps** window dragging at **1080p on a TV** |
| Search inside documents | Quick Search finds text inside your notes and documents (up to 2,000) in **under 100 ms** |
| Accessibility | The Screen Reader covers **100% of the controls** of the built-in apps; every built-in app can be used with the D-pad alone |
| Languages | **12 interface languages** (adding Italian, Portuguese (Brazil), Russian and Polish) with matching keyboard layouts |
| Browser | **108 of 120** tests pass; web fonts, hover styles and WebSocket; 20 of the 40 sites work without leaving the built-in browser |
| Office and files | Open presentation files, export documents, spreadsheets and presentations as PDF; network folders (SMB and WebDAV) in Files |
| Make on the console | A debugger in Nexvyn OS Studio for Lua; publish to the App Market straight from the console |
| Come back home | Optional: use Nexvyn OS as the Homebrew Menu, so you return to it when another homebrew program closes |
| Media | Hardware video decoding on by default; picture-in-picture for any video |
| SDK 1.7 | Desktop widgets from App Market apps; privacy labels on every store page |
| App Market | **240 items, 25 from outside makers**, reviews within **72 hours** |
| Stability | **99%** of sessions end without a crash |

### 2.0: The console desktop (target: later in 2027)

| Goal | Target |
|---|---|
| Speed | Cold start **under 2.5 seconds**; built-in apps open in **under 200 ms** |
| Smooth windows | **60 fps at 1080p with eight windows** open |
| Search | 50,000 items in under 50 ms, including your games, captures, saves and mods |
| Languages | **16 interface languages** |
| Accessibility | One-button scanning for people who use a single switch or button |
| Browser | **150 of 160** tests pass; video and audio in web pages; 30 of the 40 sites work without leaving the built-in browser |
| Documents | Version history: the last 20 versions of every document, restored in one step |
| App Market | **300+ items, 75+ outside makers**, 25+ games made with the Game Engine |
| Make on the console | Debugging in JavaScript and Python too; a simple Git client in Studio |
| While closed | Alarms, reminders and file transfer while Nexvyn OS is closed (experimental) |
| Companion | Send files, text and links from a phone or computer browser on the same network, with nothing to install |
| Updates | Smaller updates that download only what changed |
| Stability | **99.5%** of sessions end without a crash |

Support for newer Switch models depends on the homebrew community and is not a promise.

## What makes Nexvyn OS different

- **It is a console in your hand.** It knows when you dock and undock, keeps a layout for each, and uses the battery,
  motion sensors, rumble and the IR camera.
- **Controller and touch first.** A desktop you can drive completely with a controller or your fingers.
- **Make apps on the device.** Write, run, fix and publish an app without a computer.
- **Make games.** The Game Engine gives anyone, children included, a playable game in a few steps.
- **Tools for your Switch.** Your game library, mods, cheats, clock profiles, overlays and save backups in one place.

## How to help

- **Publish an app, game, theme or font.** Start with the [SDK](SDK/README.md) and follow the
  [publishing guide](SDK/Publishing/PUBLISHING.en.md). Questions go to the
  [submission question form](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=submission-question.yml).
- **Report a bug.** Use the [bug report form](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=bug-report.yml).
  Say whether it happened on a console or in an emulator and attach the crash report from `System/Logs/Crashes` if
  there is one. Reports from real consoles are especially welcome: they are how the "not verified" items get verified.
- **Translate.** A new language can be tried right away from the SD card
  ([how](SDK/Guides/USER_GUIDE.en.md#adding-a-new-language)). Offer a new language or a fix with the
  [translation form](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=translation.yml).
- **Suggest an idea** with the [idea form](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=idea.yml).
- **Report an app** that breaks the rules with the
  [report form](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=report-app.yml), or with **Report This App**
  on its store page.
- **Docs and SDK mistakes** go to the
  [SDK and docs form](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=sdk-docs-bug.yml).

## How progress is tracked

- Each release has a GitHub milestone: [milestones](https://github.com/sonerx7/Nexvyn-OS-NX/milestones) (1.1, 1.2,
  2.0).
- Roadmap work carries the [`roadmap` label](https://github.com/sonerx7/Nexvyn-OS-NX/issues?q=label%3Aroadmap).
- With every release, this page and the [release notes](CHANGELOG.md) show the measured numbers next to the targets.
- A goal that moves to a later release is marked here with the reason.
