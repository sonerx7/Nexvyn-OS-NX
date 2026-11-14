# Nexvyn OS Developer Guide: Applications and Games

**The Complete Tutorial, Architecture Manual, and Reference Map for Developers and AI Coding Assistants**

---

## Table of Contents

- [Chapter 0: Start Here — Decision Tree](#chapter-0-start-here--decision-tree)
  - [0.1 Architecture Decision Flowchart](#01-architecture-decision-flowchart)
  - [0.2 Runtime Engine Comparison](#02-runtime-engine-comparison)
  - [0.3 Language Evolution and Frozen Runtimes Policy](#03-language-evolution-and-frozen-runtimes-policy)
  - [0.4 Quick Reference: Selecting Your Stack](#04-quick-reference-selecting-your-stack)
- [Chapter 1: Project Layout and the `app.json` Manifest](#chapter-1-project-layout-and-the-appjson-manifest)
  - [1.1 Bundle Directory Hierarchy](#11-bundle-directory-hierarchy)
  - [1.2 Comprehensive `app.json` Field Specification](#12-comprehensive-appjson-field-specification)
  - [1.3 Manifest Examples by Language and Runtime](#13-manifest-examples-by-language-and-runtime)
  - [1.4 Quick Reference: Manifest Rules](#14-quick-reference-manifest-rules)
- [Chapter 2: Application Lifecycle, Watchdog, and Background Rules](#chapter-2-application-lifecycle-watchdog-and-background-rules)
  - [2.1 The Application State Machine](#21-the-application-state-machine)
  - [2.2 Script Lifecycle Callbacks (Lua, JavaScript, Python)](#22-script-lifecycle-callbacks-lua-javascript-python)
  - [2.3 Native Event Loop Lifecycle (Native SDK 1.2)](#23-native-event-loop-lifecycle-native-sdk-12)
  - [2.4 Suspend, Resume, and Background State](#24-suspend-resume-and-background-state)
  - [2.5 The Watchdog, Unresponsive Dialogs, and `loadingHint`](#25-the-watchdog-unresponsive-dialogs-and-loadinghint)
  - [2.6 Save on Quit, Autosave, and Unsaved State](#26-save-on-quit-autosave-and-unsaved-state)
  - [2.7 Quick Reference: Lifecycle Rules](#27-quick-reference-lifecycle-rules)
- [Chapter 3: UI Design Tokens, Controls, and Game Art Direction](#chapter-3-ui-design-tokens-controls-and-game-art-direction)
  - [3.1 The Two Worlds Principle: System Apps vs Video Games](#31-the-two-worlds-principle-system-apps-vs-video-games)
  - [3.2 Design Tokens and Themes (`ui.tokens` / `nxn_ui_tokens_get`)](#32-design-tokens-and-themes-uitokens--nxn_ui_tokens_get)
  - [3.3 Immediate-Mode Widget Library (`ui.*`)](#33-immediate-mode-widget-library-ui)
  - [3.4 Window Management: Menus, Titles, and Status Indicators](#34-window-management-menus-titles-and-status-indicators)
  - [3.5 System Modals: Dialogs, Prompts, and Virtual Keyboard](#35-system-modals-dialogs-prompts-and-virtual-keyboard)
  - [3.6 Game Art Direction and Presentation Standards](#36-game-art-direction-and-presentation-standards)
  - [3.7 Quick Reference: UI and Game Rules](#37-quick-reference-ui-and-game-rules)
- [Chapter 4: Input Architecture, Controllers, and Surface Pixels](#chapter-4-input-architecture-controllers-and-surface-pixels)
  - [4.1 Coordinate Space: The Surface Pixels Rule](#41-coordinate-space-the-surface-pixels-rule)
  - [4.2 Pointer, Mouse, and Multi-Touch Input](#42-pointer-mouse-and-multi-touch-input)
  - [4.3 Controller Input, Bitmasks, and Deadzones](#43-controller-input-bitmasks-and-deadzones)
  - [4.4 Logical Actions and System Remapping](#44-logical-actions-and-system-remapping)
  - [4.5 USB Keyboard and Typing Input](#45-usb-keyboard-and-typing-input)
  - [4.6 HD Rumble and Haptic Actuation](#46-hd-rumble-and-haptic-actuation)
  - [4.7 Quick Reference: Input Rules](#47-quick-reference-input-rules)
- [Chapter 5: Graphics Architecture — 2D Canvas, `g3d` PBR, and Native OpenGL](#chapter-5-graphics-architecture--2d-canvas-g3d-pbr-and-native-opengl)
  - [5.1 2D Vector Canvas Pipeline (`gfx.*`)](#51-2d-vector-canvas-pipeline-gfx)
  - [5.2 Real-Time 3D Engine (`g3d`) Basics and Primitives](#52-real-time-3d-engine-g3d-basics-and-primitives)
  - [5.3 Skeletal 3D Models (`g3d.model`) and Animation Blending](#53-skeletal-3d-models-g3dmodel-and-animation-blending)
  - [5.4 Modern PBR Rendering with NexGFX (`g3d.renderer("pbr")`)](#54-modern-pbr-rendering-with-nexgfx-g3drendererpbr)
  - [5.5 GPU Instanced Rendering](#55-gpu-instanced-rendering)
  - [5.6 Native Desktop OpenGL Core 4.3 and GLES 3.2 via Mesa](#56-native-desktop-opengl-core-43-and-gles-32-via-mesa)
  - [5.7 Frame Pacing, Vsync, and Resolution Profiles](#57-frame-pacing-vsync-and-resolution-profiles)
  - [5.8 Quick Reference: Graphics Rules](#58-quick-reference-graphics-rules)
- [Chapter 6: Audio System and the OS Sound Mixer](#chapter-6-audio-system-and-the-os-sound-mixer)
  - [6.1 Audio Architecture and Mixer Hierarchy](#61-audio-architecture-and-mixer-hierarchy)
  - [6.2 Script Audio API: Tones, Sound Effects, and Music](#62-script-audio-api-tones-sound-effects-and-music)
  - [6.3 Native Sound Mixer (`NXN_CAP_MIXER`)](#63-native-sound-mixer-nxn_cap_mixer)
  - [6.4 Native Push PCM Audio Streams](#64-native-push-pcm-audio-streams)
  - [6.5 Latency, Formats, and Channel Downmixing](#65-latency-formats-and-channel-downmixing)
  - [6.6 Quick Reference: Audio Rules](#66-quick-reference-audio-rules)
- [Chapter 7: Storage, Sandboxing, Network, and Security](#chapter-7-storage-sandboxing-network-and-security)
  - [7.1 Virtual Filesystem Sandboxing and Protected Roots](#71-virtual-filesystem-sandboxing-and-protected-roots)
  - [7.2 Atomic Persistence Pattern (Data Loss Prevention)](#72-atomic-persistence-pattern-data-loss-prevention)
  - [7.3 Save Game Management and Backups](#73-save-game-management-and-backups)
  - [7.4 Asynchronous HTTP Networking (`net.request`)](#74-asynchronous-http-networking-netrequest)
  - [7.5 Persistent WebSockets (`net.ws`)](#75-persistent-websockets-netws)
  - [7.6 Secure Authentication via OAuth 2.0 PKCE (`net.oauth`)](#76-secure-authentication-via-oauth-20-pkce-netoauth)
  - [7.7 Security Rules: Secrets and Kernel Isolation](#77-security-rules-secrets-and-kernel-isolation)
  - [7.8 Quick Reference: Storage and Network Rules](#78-quick-reference-storage-and-network-rules)
- [Chapter 8: Internationalisation and the 8 UI Languages](#chapter-8-internationalisation-and-the-8-ui-languages)
  - [8.1 Localisation File Architecture](#81-localisation-file-architecture)
  - [8.2 Translation Format and Parameter Replacement](#82-translation-format-and-parameter-replacement)
  - [8.3 The Translation Fallback Chain](#83-the-translation-fallback-chain)
  - [8.4 Translation Queries in Scripts and Native Code](#84-translation-queries-in-scripts-and-native-code)
  - [8.5 Typography and CJK / Extended Character Coverage](#85-typography-and-cjk--extended-character-coverage)
  - [8.6 Quick Reference: Localisation Rules](#86-quick-reference-localisation-rules)
- [Chapter 9: Native C and C++ Applications (`.nxvmod` and Native SDK 1.2)](#chapter-9-native-c-and-c-applications-nxvmod-and-native-sdk-12)
  - [9.1 Toolchain Architecture and Compilation Model](#91-toolchain-architecture-and-compilation-model)
  - [9.2 Native SDK ABI v1 Freeze and Capability Discovery](#92-native-sdk-abi-v1-freeze-and-capability-discovery)
  - [9.3 Complete `nxn_*` API Tour and Signatures](#93-complete-nxn_-api-tour-and-signatures)
  - [9.4 Windowed Mode vs Fullscreen Execution](#94-windowed-mode-vs-fullscreen-execution)
  - [9.5 Concurrency and Locking Invariants](#95-concurrency-and-locking-invariants)
  - [9.6 Arena Memory Model and Crash Containment](#96-arena-memory-model-and-crash-containment)
  - [9.7 App Guard Trust Model for Native Code](#97-app-guard-trust-model-for-native-code)
  - [9.8 Porting Architecture: SDL2 Driver and Libretro Cores](#98-porting-architecture-sdl2-driver-and-libretro-cores)
  - [9.9 Quick Reference: Native Rules](#99-quick-reference-native-rules)
- [Chapter 10: The OS Browser as an Application Platform](#chapter-10-the-os-browser-as-an-application-platform)
  - [10.1 Web Engine Architecture and Standards](#101-web-engine-architecture-and-standards)
  - [10.2 HTML5, CSS Grid, Flexbox, and Styling](#102-html5-css-grid-flexbox-and-styling)
  - [10.3 High-Performance Canvas 2D and WebGL 2](#103-high-performance-canvas-2d-and-webgl-2)
  - [10.4 Web Workers, Threading, and Structured Cloning](#104-web-workers-threading-and-structured-cloning)
  - [10.5 Persistent Storage via IndexedDB](#105-persistent-storage-via-indexeddb)
  - [10.6 WebAudio API and Digital Sound Synthesis](#106-webaudio-api-and-digital-sound-synthesis)
  - [10.7 Gamepad API and Fullscreen Presentation](#107-gamepad-api-and-fullscreen-presentation)
  - [10.8 Video Playback, MSE, and ClearKey EME](#108-video-playback-mse-and-clearkey-eme)
  - [10.9 Engine Limitations and Unsupported Features](#109-engine-limitations-and-unsupported-features)
  - [10.10 Quick Reference: Web Platform Rules](#1010-quick-reference-web-platform-rules)
- [Chapter 11: Performance Rules, Hardware Budgets, and Profiling](#chapter-11-performance-rules-hardware-budgets-and-profiling)
  - [11.1 The 60 fps Budget and Frame Timing](#111-the-60-fps-budget-and-frame-timing)
  - [11.2 Memory Allocation Constraints (Zero Allocations in Loop)](#112-memory-allocation-constraints-zero-allocations-in-loop)
  - [11.3 Memory Pressure and Resource Reclaim](#113-memory-pressure-and-resource-reclaim)
  - [11.4 Power and Thermal Adaptation (`nxn_power_get`)](#114-power-and-thermal-adaptation-nxn_power_get)
  - [11.5 Profiling Realities: Emulators vs Console Hardware](#115-profiling-realities-emulators-vs-console-hardware)
  - [11.6 Quick Reference: Performance Rules](#116-quick-reference-performance-rules)
- [Chapter 12: Automated Testing with `nxvtest`](#chapter-12-automated-testing-with-nxvtest)
  - [12.1 The `nxvtest` Architecture](#121-the-nxvtest-architecture)
  - [12.2 Scenario File Specification (`scenario.json`)](#122-scenario-file-specification-scenariojson)
  - [12.3 Running Test Suites and Inspecting Reports](#123-running-test-suites-and-inspecting-reports)
  - [12.4 Pre-Publishing Verification Checklist](#124-pre-publishing-verification-checklist)
  - [12.5 Quick Reference: Testing Rules](#125-quick-reference-testing-rules)
- [Chapter 13: Packaging, Publishing, and the App Market](#chapter-13-packaging-publishing-and-the-app-market)
  - [13.1 Package Formats: `.nxvapp`, `.nxvmod`, and `.nxvlib`](#131-package-formats-nxvapp-nxvmod-and-nxvlib)
  - [13.2 Store Catalog Metadata (`store.json`)](#132-store-catalog-metadata-storejson)
  - [13.3 Screenshots Standards (5 Shots, English UI)](#133-screenshots-standards-5-shots-english-ui)
  - [13.4 Icon Key-Art Requirements](#134-icon-key-art-requirements)
  - [13.5 Licences, Attribution, and Port Packaging](#135-licences-attribution-and-port-packaging)
  - [13.6 The "Runtimes & Libraries" Store Category](#136-the-runtimes--libraries-store-category)
  - [13.7 Package Signing Model (Unsigned Store Decisions)](#137-package-signing-model-unsigned-store-decisions)
  - [13.8 Safe Update Path and Data Migration](#138-safe-update-path-and-data-migration)
  - [13.9 Quick Reference: Store Publishing Rules](#139-quick-reference-store-publishing-rules)
- [Chapter 14: Compatibility Promises and Version History](#chapter-14-compatibility-promises-and-version-history)
  - [14.1 The Three Version Tiers](#141-the-three-version-tiers)
  - [14.2 The Additive Compatibility Contract](#142-the-additive-compatibility-contract)
  - [14.3 Behaviour Gating via `targetSdk`](#143-behaviour-gating-via-targetsdk)
  - [14.4 Reading the Version History: SDK 1.0 to 1.13](#144-reading-the-version-history-sdk-10-to-113)
  - [14.5 Reading the Native SDK Version History: 1.0 to 1.2](#145-reading-the-native-sdk-version-history-10-to-12)
  - [14.6 Quick Reference: Compatibility Rules](#146-quick-reference-compatibility-rules)
- [Chapter 15: Common Mistakes and Solutions](#chapter-15-common-mistakes-and-solutions)
  - [15.1 Troubleshooting Matrix (Symptom -> Cause -> Fix)](#151-troubleshooting-matrix-symptom---cause---fix)
  - [15.2 In-Depth Analysis of Critical Failure Modes](#152-in-depth-analysis-of-critical-failure-modes)
| Red banner "MESSAGE FROM DEAR IMGUI! 2 visible items with conflicting ID" on screen (native ImGui app, often only in an empty or first-run state) | Two widgets share the same label, so the same ImGui ID (e.g. a toolbar Rescan button and an empty-state Rescan button) | Give repeated labels a `##suffix` (`Button("Rescan##toolbar")`), use `PushID(i)` in loops, never an empty label; test every UI state |
- [Chapter 16: Glossary](#chapter-16-glossary)

---

## Chapter 0: Start Here — Decision Tree

This chapter guides developers and AI code generation models through selecting the exact architecture, language runtime, and rendering technology suited to your application goals.

### 0.1 Architecture Decision Flowchart

```
What is the primary purpose of your project?
│
├── [A] Productivity Utility / Document Editor / Media Tool / Social Client
│   │
│   ├── Want ultra-fast startup (<10 ms), low footprint (~2 MB RAM), pure simplicity?
│   │   └──► RUNTIME: Lua 5.4.7 ("lua")
│   │        Reason: Standard system scripting engine, immediate startup, lowest overhead.
│   │
│   ├── Want modern asynchronous paradigms, Promise pipelines, or TypeScript transpilation?
│   │   └──► RUNTIME: JavaScript / QuickJS-ng ("js")
│   │        Reason: Full ES2023 language support, native async/await, Promise-based SDK APIs.
│   │
│   └── Want clean Python syntax, dataclasses, scientific math, or rich text parsing?
│       └──► RUNTIME: Python / pocketpy 2.2 ("python") or CPython 3.12 ("python3")
│            Reason: Python 3 syntax, comprehensions, standard math/collections libraries.
│
├── [B] 2D Video Game (Platformer, Top-down, Puzzle, Bullet Hell, RPG)
│   │
│   └──► RUNTIME: Lua ("lua") with "nexvyn.game"
│        Reason: Built-in 2D game engine (`require("nexvyn.game")`) providing scene management,
│                kinematic physics, particle emitters, sprite animation, virtual coordinate
│                scaling, camera control, and audio mixing.
│
├── [C] 3D Video Game (Stylized Low-Poly, Voxel Worlds, or Modern PBR)
│   │
│   ├── Script-driven 3D game (Rapid development, hot-reloading)
│   │   └──► RUNTIME: Lua, JavaScript, or Python with "g3d"
│   │        Reason: GPU-driven rendering (`g3d.renderer("pbr")` NexGFX core), glTF 2.0 / FBX
│   │                skeletal animation, real-time cascaded shadows, ACES tonemapping, bloom.
│   │
│   └── High-performance AAA 3D game / Heavy simulation
│       └──► RUNTIME: Native C/C++ (".nxvmod")
│            Reason: Direct compiled AArch64 binary, zero interpreter overhead, custom memory
│                    allocators, multi-threading, direct Mesa desktop OpenGL 4.3 or GLES 3.2.
│
├── [D] Standalone Emulator / Ported Existing Engine / Complex C++ Program
│   │
│   └──► RUNTIME: Native C/C++ (".nxvmod") with Native SDK 1.2
│        Reason: Loads inside the OS process space, built-in SDL2 windowed driver, POSIX
│                compatibility shim (`libnexvyn_compat`), dynamic library linking (`.nxvlib`),
│                low-latency push PCM audio stream, OS menu and dialog integration.
│
└── [E] Existing Web Application / HTML5 Canvas or WebGL Game
    │
    └──► PLATFORM: Nexvyn OS Browser Engine
         Reason: Built-in HTML5 engine supporting Canvas 2D, WebGL 2, Web Workers, IndexedDB,
                 WebAudio, Gamepad API, and MediaSource Extensions (MSE) with ClearKey EME.
```

### 0.2 Runtime Engine Comparison

The following table contrasts all active execution runtimes supported by the operating system:

| Runtime Identifier | Underlying Engine | Memory Quota | Primary Use Cases | Strengths | Constraints |
|---|---|---|---|---|---|
| `"lua"` | Lua 5.4.7 | 64 MB heap | Utilities, 2D games, 3D games | Instant launch, smallest RAM footprint, `nexvyn.game` built-in | 1-based indexing, no native classes |
| `"js"` | QuickJS-ng 0.17.0 | 64 MB heap | Web utilities, async tools | ES2023, native Promises, `async`/`await`, JSON handling | 0-based indexing, no browser DOM globals |
| `"python"` | pocketpy 2.2.0 | 64 MB heap | General tools, games | Clean syntax, dataclasses, fast lightweight bytecode | Subset of CPython, no `async`/`await` |
| `"python3"` | CPython 3.12.16 | System available | Heavy data tools, scripts | Full standard library, ecosystem modules | Slower cold startup, larger romfs footprint |
| `"c"` | TinyCC 0.9.28rc | 64 MB heap | Fast algorithmic tools | On-console JIT compilation from C sources, direct C99 | Unsandboxed permission prompt, no PC toolchain |
| `"native"` | AArch64 Shared ELF | Dynamic heap | Emulators, ports, 3D games | Maximum hardware performance, Mesa GL 4.3, SDL2 driver | Requires devkitA64 toolchain, manual memory management |

### 0.3 Language Evolution and Frozen Runtimes Policy

> [!IMPORTANT]
> **Language Parity Rule**: When new system features and API capabilities are introduced, they arrive simultaneously in **Lua, JavaScript, Python, and C** with identical naming conventions.
>
> **Frozen Runtimes Policy**: Squirrel 3.2 (`"squirrel"`) and MiniJVM Java (`"java"`) were officially frozen at SDK 1.8. Existing applications written in Squirrel or Java continue to execute indefinitely with full backward compatibility. However, no new SDK APIs (such as SDK 1.9 PBR or SDK 1.11 kept folders) are added to them. For all new development, authors MUST select Lua, JavaScript, Python, or Native C/C++.

### 0.4 Quick Reference: Selecting Your Stack
- **MUST**: Choose `"lua"` with `nexvyn.game` for rapid 2D game development.
- **MUST**: Choose `"native"` with Native SDK 1.2 for emulators, ports of existing C/C++ engines, or multi-threaded games.
- **MUST NOT**: Select `"squirrel"` or `"java"` for new projects requiring SDK 1.9+ features.

---

## Chapter 1: Project Layout and the `app.json` Manifest

Every Nexvyn OS application or game is distributed as a `.nxvapp` bundle. A bundle is either a physical directory whose name ends in `.nxvapp` or a zip archive renamed with the `.nxvapp` extension.

### 1.1 Bundle Directory Hierarchy

The standard filesystem layout of a `.nxvapp` bundle is structured as follows:

```text
MyApp.nxvapp/
├── app.json              # Required: Application manifest defining metadata, window, permissions
├── main.lua              # Required entrypoint (or main.js, main.py, main.c, or native .nxvmod)
├── icon.png              # Recommended: 128x128 or 256x256 RGBA PNG key-art
├── lang/                 # Required when TR() is used
│   ├── en.json           # Required: English base translations
│   ├── tr.json           # Optional: Turkish translations
│   ├── es.json           # Optional: Spanish translations
│   └── ...               # Additional languages: de.json, fr.json, ja.json, ko.json, zh.json
├── data/                 # Optional: Static read-only assets bundled with the application
└── romfs/                # Optional: Native asset mount point for ported C/C++ game engines
```

### 1.2 Comprehensive `app.json` Field Specification

The manifest file `app.json` resides at the root of every bundle. The system validates these fields during installation and execution:

| Field | Type | Default | Since | Description |
|---|---|---|---|---|
| `id` | `string` | *(Required)* | 1.0 | Unique reverse-domain identifier (e.g. `"com.example.game"`). Never change across updates. |
| `name` | `string` \| `object` | *(Required)* | 1.0 | Application display name. Either a plain string or a locale map: `{"en": "Name", "tr": "Ad"}`. `"en"` is mandatory. |
| `description` | `string` \| `object` | `""` | 1.0 | Descriptive text shown in the store and install sheet. Plain string or locale map. |
| `version` | `string` | `"1.0"` | 1.0 | Display and packaging version (e.g., `"1.0.0"` or `"1.2"`). |
| `author` | `string` | `""` | 1.0 | Creator or organisation name displayed in the About dialog and App Market. |
| `homepage` | `string` | `""` | 1.0 | Public repository URL or website link. |
| `category` | `string` | `"other"` | 1.0 | Categorisation slug: `"system"`, `"productivity"`, `"utilities"`, `"media"`, `"internet"`, `"games"`, `"developer"`, `"runtimes"`, `"other"`. |
| `icon` | `string` | `"icon.png"` | 1.0 | Relative path to the application icon. |
| `runtime` | `string` | Inferred | 1.0 | Execution engine: `"lua"`, `"js"`, `"python"`, `"python3"`, `"c"`, or `"native"`. |
| `main` | `string` | Inferred | 1.0 | Entrypoint file (e.g. `"main.lua"`, `"main.js"`, `"main.py"`, `"main.c"`, `"game.nxvmod"`). |
| `mode` | `string` | `"window"` | 1.10 | Presentation mode: `"window"` (resizable desktop window) or `"fullscreen"` (covers full display). |
| `window` | `object` | *(See below)* | 1.0 | Initial content geometry and resizing capabilities. |
| `window.width` | `integer` | `640` | 1.0 | Initial content area width in surface pixels (excluding OS window borders and title bar). |
| `window.height` | `integer` | `480` | 1.0 | Initial content area height in surface pixels. |
| `window.minWidth` | `integer` | `320` | 1.0 | Minimum allowable content width during interactive window resizing. |
| `window.minHeight` | `integer` | `240` | 1.0 | Minimum allowable content height during interactive window resizing. |
| `window.resizable` | `boolean` | `true` | 1.0 | Whether the user may freely resize the window. |
| `minSdk` | `string` | `"1.0"` | 1.2 | Oldest Script SDK version required. Lower system versions reject installation with a clean message. |
| `targetSdk` | `string` | `minSdk` | 1.2 | Tested SDK version. Gates behaviour changes while preserving backward compatibility. |
| `minNative` | `string` | `"1.0"` | 1.10 | Oldest Native SDK version required (`"1.0"`, `"1.1"`, `"1.2"`). Native modules only. |
| `runtimeVersion` | `string` | `""` | 1.2 | Specific engine version tested against (e.g., `"2.2"` for pocketpy). |
| `loadingHint` | `boolean` | `false` | 1.13 | Indicates long loading times. Extends watchdog "Not Responding" threshold from 5 s to 120 s. |
| `permissions` | `array` | `[]` | 1.2 | Array of capability strings: `"network"`, `"files"`, `"launch"`, `"notifications"`, `"games"`. |
| `gamepad` | `boolean` | `false` | 1.0 | When `true`, controller events route directly to the app; OS cursor navigation is disabled. |
| `fileTypes` | `array` | `[]` | 1.0 | Array of file extensions (e.g., `[".png", ".txt"]`) associated with the app in "Open With". |
| `shareTargets` | `array` | `[]` | 1.4 | Content types accepted from system share sheet: `"text"`, `"url"`, `"file"`, `"image"`, or extensions. |
| `singleInstance` | `boolean` | `true` | 1.0 | If `true`, re-launching delivers arguments to `app.open(arg)` rather than spawning another window. |
| `memory` | `integer` | Inferred | 1.10 | Target native heap size in megabytes (1 to 16384). Validated against free memory at launch. |
| `type` | `string` | `"app"` | 1.10 | Package v2 type descriptor: `"app"`, `"game"`, or `"lib"`. |
| `arch` | `string` | `"aarch64"`| 1.10 | Architecture string (Package v2). |
| `needs` | `array` | `[]` | 1.10 | Shared library requirements (e.g., `["com.nexvyn.zstd@1"]`). |
| `dataVersion` | `integer` | `1` | 1.10 | User data schema version. Increments trigger automatic data backups prior to package update. |

### 1.3 Manifest Examples by Language and Runtime

#### 1. Lua 2D Game Manifest
```json
{
  "id": "com.indie.dungeonrun",
  "name": { "en": "Dungeon Run", "tr": "Zindan Koşusu" },
  "description": { "en": "A 2D rogue-lite dungeon crawler", "tr": "2D rogue-lite zindan oyunu" },
  "version": "1.0.0",
  "author": "Indie Games Studio",
  "category": "games",
  "runtime": "lua",
  "main": "main.lua",
  "mode": "fullscreen",
  "gamepad": true,
  "window": { "width": 1280, "height": 720, "resizable": true },
  "minSdk": "1.2",
  "targetSdk": "1.13",
  "permissions": []
}
```

#### 2. JavaScript Social & Network Application
```json
{
  "id": "com.social.client",
  "name": { "en": "Nexvyn Social", "tr": "Nexvyn Sosyal" },
  "description": { "en": "Social media and photo feed", "tr": "Sosyal medya ve fotoğraf akışı" },
  "version": "1.1.0",
  "author": "Social Team",
  "category": "internet",
  "runtime": "js",
  "main": "main.js",
  "window": { "width": 720, "height": 600, "minWidth": 480, "minHeight": 400, "resizable": true },
  "minSdk": "1.9",
  "targetSdk": "1.13",
  "permissions": ["network", "notifications"]
}
```

#### 3. Python 3 Productivity Utility
```json
{
  "id": "com.lab.dataviewer",
  "name": { "en": "Data Viewer", "tr": "Veri Görüntüleyici" },
  "description": { "en": "CSV and JSON visualizer", "tr": "CSV ve JSON görselleştirici" },
  "version": "2.0.0",
  "category": "productivity",
  "runtime": "python",
  "main": "main.py",
  "window": { "width": 840, "height": 520, "resizable": true },
  "fileTypes": [".csv", ".json"],
  "minSdk": "1.3",
  "targetSdk": "1.13",
  "permissions": ["files"]
}
```

#### 4. C Script App (TinyCC On-Console Compiler)
```json
{
  "id": "com.demo.helloc",
  "name": { "en": "C Mandelbrot", "tr": "C Mandelbrot" },
  "version": "1.0.0",
  "category": "developer",
  "runtime": "c",
  "main": "main.c",
  "window": { "width": 640, "height": 480, "resizable": true },
  "minSdk": "1.5",
  "targetSdk": "1.13",
  "permissions": []
}
```

#### 5. Native C/C++ Windowed Application (`.nxvmod`)
```json
{
  "id": "com.tools.hexeditor",
  "name": { "en": "Hex Master", "tr": "Hex Ustası" },
  "description": { "en": "Native binary hex editor", "tr": "Yerel ikili hex düzenleyici" },
  "version": "1.0.0",
  "author": "System Tools",
  "category": "utilities",
  "runtime": "native",
  "main": "hexeditor.nxvmod",
  "mode": "window",
  "window": { "width": 960, "height": 540, "minWidth": 640, "minHeight": 400, "resizable": true },
  "minNative": "1.2",
  "minSdk": "1.10",
  "targetSdk": "1.13",
  "permissions": ["files"]
}
```

#### 6. Native C/C++ Fullscreen Emulator Frontend (`.nxvmod`)
```json
{
  "id": "com.emu.genesis",
  "name": { "en": "EmuFront 16-Bit", "tr": "EmuFront 16-Bit" },
  "description": { "en": "Dedicated console emulator frontend", "tr": "Özel konsol emülatör önyüzü" },
  "version": "1.0.0",
  "author": "Preservation Project",
  "category": "games",
  "runtime": "native",
  "main": "emufront.nxvmod",
  "mode": "fullscreen",
  "gamepad": true,
  "loadingHint": true,
  "window": { "width": 1280, "height": 720, "resizable": true },
  "minNative": "1.2",
  "minSdk": "1.10",
  "targetSdk": "1.13",
  "permissions": ["files", "notifications"]
}
```

### 1.4 Quick Reference: Manifest Rules
- **MUST**: Set `"id"` in reverse-domain syntax. Never change the `id` after public release.
- **MUST**: Include an `"en"` property inside `"name"` when specifying locale objects.
- **MUST**: Declare `"loadingHint": true` if your application takes more than 5 seconds to initialise heavy data or recompile shaders.
- **MUST NOT**: Request permissions your application never exercises. App Guard flags undeclared or unused permissions.

---

## Chapter 2: Application Lifecycle, Watchdog, and Background Rules

Nexvyn OS supervises execution within its multitasking desktop environment. Applications transition through standard lifecycle states in response to window management, power changes, and user interaction.

### 2.1 The Application State Machine

```
              ┌───────────────────────────┐
              │      Process Launch       │
              │  app.load(arg) / nxn_init │
              └─────────────┬─────────────┘
                            │
                            ▼
              ┌───────────────────────────┐
        ┌────►│       Active Loop         │◄────────────────┐
        │     │  update(dt) / draw(w, h)  │                 │
        │     │   or nxn_display_swap     │                 │
        │     └─────────────┬─────────────┘                 │
        │                   │                               │
[app.resume()]       [Focus Lost]                      [app.resume()]
[NXN_EVENT_RESUME]   [NXN_EVENT_FOCUS(0)]              [NXN_EVENT_RESUME]
        │                   │                               │
        │                   ▼                               │
        │     ┌───────────────────────────┐                 │
        │     │      Unfocused State      │                 │
        │     │ Window visible, no inputs │                 │
        │     └─────────────┬─────────────┘                 │
        │                   │                               │
        │           [Sleep / HOME Menu]                     │
        │        [app.suspend() / SUSPEND]                  │
        │                   │                               │
        │                   ▼                               │
        │     ┌───────────────────────────┐                 │
        └─────┤      Suspended State      ├─────────────────┘
              │  Audio cut, swaps skipped │
              └─────────────┬─────────────┘
                            │
                      [Quit Event]
                 [app.close() / QUIT]
                            │
                            ▼
              ┌───────────────────────────┐
              │   Shutdown & Save Point   │
              │   app.autosave() / exit   │
              └───────────────────────────┘
```

### 2.2 Script Lifecycle Callbacks (Lua, JavaScript, Python)

Script applications register callback functions on the global `app` object:

```lua
local app = {}

-- Called once upon application start.
-- arg: File path, URL, or command-line string the app was launched with.
function app.load(arg)
  if arg ~= "" then parse_startup_document(arg) end
end

-- Called if another process opens this app while it is already running.
function app.open(arg)
  parse_startup_document(arg)
end

-- Called every simulation tick (~60 fps). dt is elapsed time in seconds.
function app.update(dt)
  simulation_step(dt)
end

-- Called every display render frame.
-- w, h: Active content width and height in surface pixels.
function app.draw(w, h)
  gfx.clear(theme.bg)
  render_ui(w, h)
end

-- Called when window gains (true) or loses (false) input focus.
function app.focus(is_focused)
  if not is_focused then auto_pause_game() end
end

-- Called when the console enters sleep mode or HOME menu is opened.
function app.suspend()
  audio.musicPause(true)
  persist_transient_data()
end

-- Called when waking from sleep or returning to the foreground.
function app.resume()
  audio.musicPause(false)
  validate_network_connections()
end

-- Called periodically by system or before restart/shutdown.
function app.autosave()
  perform_atomic_save()
end

-- Called to inspect if unsaved documents exist before closing.
function app.unsaved()
  return has_unsaved_changes
end

-- Intercepts window closing. Return false to cancel closing.
function app.close()
  if has_unsaved_changes then
    ui.alert("Unsaved Work", "Save changes before closing?", {"Save", "Discard", "Cancel"}, function(btn)
      if btn == 1 then perform_atomic_save(); sys.exit()
      elseif btn == 2 then has_unsaved_changes = false; sys.exit() end
    end)
    return false -- Cancel immediate window destruction
  end
  return true
end

return app
```

### 2.3 Native Event Loop Lifecycle (Native SDK 1.2)

Native applications (`.nxvmod`) drive their execution via an event loop:

```c
#include <nexvyn/nexvyn_native.h>

int main(int argc, char** argv) {
    nxn_event ev = NXN_STRUCT_INIT(nxn_event);

    while (!nxn_should_quit()) {
        // Drain system event queue
        while (nxn_event_poll(&ev) > 0) {
            switch (ev.type) {
                case NXN_EVENT_RESIZE:
                    // Window size or docked resolution changed
                    nxn_display_resize(disp, ev.width, ev.height);
                    glViewport(0, 0, ev.width, ev.height);
                    break;
                case NXN_EVENT_FOCUS:
                    // ev.focused: 1 = gained focus, 0 = lost focus
                    break;
                case NXN_EVENT_SUSPEND:
                    // Console entering sleep / background
                    persist_game_state();
                    break;
                case NXN_EVENT_RESUME:
                    // Restored from sleep: drop stale audio buffers, check time
                    break;
                case NXN_EVENT_QUIT:
                    // User closed window or OS requested shutdown
                    return 0;
                default:
                    break;
            }
            ev.size = sizeof(ev);
        }

        // Logic & Render
        update_game(0.0166f);
        render_game();

        // Swap buffers and synchronize to display vsync
        nxn_display_swap(disp);
    }
    return 0;
}
```

### 2.4 Suspend, Resume, and Background State

When the console enters sleep mode or the user accesses the HOME menu:
- The system fires `app.suspend()` or `NXN_EVENT_SUSPEND`.
- All audio output from the application is silenced immediately by the OS mixer.
- Window display presentation stops; `nxn_display_swap` returns without reading pixels back.
- When the console wakes up, `app.resume()` or `NXN_EVENT_RESUME` fires. Any audio queued prior to suspension is discarded so that stale sound buffers never play. Monotonic clocks jump; applications should recalculate delta times.

### 2.5 The Watchdog, Unresponsive Dialogs, and `loadingHint`

To prevent malfunctioning code from hanging the operating system, a multi-tier watchdog monitors UI responsiveness:

```
Script callback starts
  │
  ├── Callback exceeds 3.0 seconds (10.0 s for app.load)
  │   ├── targetSdk >= 1.8: TERMINATE app immediately with Crash Screen
  │   └── targetSdk <  1.8: PAUSE callback, show "Not Responding" (Wait / Close)
  │
Native app frame loop
  │
  ├── Window fails to swap for 5.0 seconds
  │   ├── loadingHint: false (default): Show "Not Responding" dialog (Wait / Close)
  │   └── loadingHint: true: WAIT up to 120.0 seconds before showing dialog
  │
  └── Total stall exceeds 12.0 seconds without returning to OS
      └── OS presents Force Quit / Wait dialog
          (Emergency: Hold + and - for 2 seconds to force-quit)
```

1. **The 3-Second Script Boundary**: Any individual callback invocation (`update`, `draw`, `event`) running longer than **3 seconds** is halted by the interpreter. The main script body and `app.load` receive **10 seconds** (SDK 1.8+).
2. **`targetSdk` Policy**:
   - For `targetSdk >= "1.8"`, a stalled callback halts the application with an error crash report screen ("This app stopped responding").
   - For `targetSdk < "1.8"`, the system pauses execution and asks the user: *Wait* (resumes execution) or *Close*.
3. **`loadingHint: true` (SDK 1.13)**: Large native modules, emulators, or heavy 3D scenes that take significant time to parse asset files or compile shaders can set `"loadingHint": true` in `app.json`. The unresponsive watchdog threshold is extended from **5 seconds to 120 seconds**. Clicking *Wait* silences further warnings for **60 seconds** and until the window completes its next frame presentation.
4. **Emergency Console Recovery**: If a native module stalls in an infinite loop, holding **+ and - simultaneously for 2 seconds** terminates the process cleanly and restores the desktop session.

### 2.6 Save on Quit, Autosave, and Unsaved State

Applications mark their dirty state using `app.unsaved()` or `nxn_window_set_modified(1)`:
- When set, a dot appears in the window title bar.
- When the user commands the console to shut down, restart, or log out, Nexvyn OS checks all open windows. Any window reporting unsaved modifications is listed in a confirmation sheet (*"These applications have unsaved changes. Quit anyway?"*).

### 2.7 Quick Reference: Lifecycle Rules
- **MUST**: Dispatch heavy decompression, network queries, and asset baking to worker threads.
- **MUST**: Pause audio playback and transient simulations during `app.suspend` / `NXN_EVENT_SUSPEND`.
- **MUST NOT**: Block the main thread inside `app.draw` or event handlers for more than 3 seconds.
- **MUST**: Set `"loadingHint": true` in `app.json` for heavy ports with prolonged initial loading periods.

---

## Chapter 3: UI Design Tokens, Controls, and Game Art Direction

### 3.1 The Two Worlds Principle: System Apps vs Video Games

Nexvyn OS enforces a strict architectural division between standard applications and games:

| Dimension | System & Productivity Apps | Video Games & Ports |
|---|---|---|
| **Visual Styling** | MUST use OS Design Tokens (`ui.tokens()`, `nxn_ui_tokens_get`) | MUST NOT copy OS widgets or standard grey dialogs |
| **Theme Alignment** | Follows system Light/Dark/Accent/High Contrast settings | Develops independent, custom in-game Art Direction |
| **Window Frame** | Standard title bar, close buttons, OS menu bar items | Fullscreen canvas or thematic custom HUD framing |
| **Menu System** | Standard OS menu bar items (`app.menu`, `nxn_menu_set`) | Custom in-engine pause menus matching game art |
| **Quality Standard**| Clean, modern desktop tool aesthetics | AAA visual presentation; no generic template menus |

> [!CAUTION]
> **Game Review Rejection Rule**: The SDK intentionally does not provide a "ready-made game menu template". Games that copy the standard OS buttons, grey background boxes, or top menu bar to form their in-game interface will be **rejected during App Market review**. The SDK provides building blocks (fonts, shaders, sound mixers, layout mathematics); authors MUST define their own art direction.

### 3.2 Design Tokens and Themes (`ui.tokens` / `nxn_ui_tokens_get`)

Standard applications query the system palette to adapt to light, dark, and accent colour adjustments:

```lua
-- Retrieve active design tokens (SDK 1.12+)
local tokens = ui.tokens()

-- Semantic Palette (Hex strings)
local bg_window    = tokens.colors.windowBg
local bg_content   = tokens.colors.contentBg
local bg_surface   = tokens.colors.surface
local color_accent = tokens.colors.accent
local text_primary = tokens.colors.text
local text_muted   = tokens.colors.textSecondary
local color_border = tokens.colors.border

-- Metrics and Spacing
local radius_box   = tokens.cornerRadius    -- Default control corner radius
local radius_field = tokens.cornerRadiusField
local row_height   = tokens.rowHeight
local gap_default  = tokens.spacing[2]      -- Standard 8px spacing
```

In Native C (`nxn_ui.h`):
```c
nxn_ui_tokens tokens = NXN_STRUCT_INIT(nxn_ui_tokens);
if (nxn_ui_tokens_get(&tokens) == NXN_OK) {
    uint32_t bg = tokens.color_content_bg;
    uint32_t accent = tokens.color_accent;
    float radius = tokens.corner_radius;
}
```

### 3.3 Immediate-Mode Widget Library (`ui.*`)

The `ui` library provides immediate-mode controls evaluated during `app.draw`:

```lua
function app.draw(w, h)
  gfx.clear(theme.bg)

  -- 1. Buttons
  -- style: "default", "primary", "destructive", "plain", "toolbar", "link"
  if ui.button("Confirm", 20, 20, 140, 36, "primary") then
    commit_changes()
  end
  if ui.button("Delete", 170, 20, 100, 36, "destructive") then
    delete_selected()
  end

  -- 2. Toggles and Checkboxes
  active_state = ui.toggle("sw_active", active_state, 20, 70)
  shadows_on = ui.checkbox("Cast Shadows", shadows_on, 100, 70)

  -- 3. Sliders
  master_vol = ui.slider("sld_vol", master_vol, 0.0, 1.0, 20, 110, 220)

  -- 4. Text Input Field
  -- flags: "search", "password", "numeric", "readonly"
  search_str, submitted = ui.textfield("txt_search", search_str, 20, 150, 260, 36, "Search...", "search")
  if submitted then execute_search(search_str) end

  -- 5. Segmented Selection (1-based index)
  active_tab = ui.segmented("seg_tabs", {"Inbox", "Sent", "Archive"}, active_tab, 20, 200, 320, 32)

  -- 6. Scrollable Viewport
  local sy, sx = ui.beginScroll("scr_list", 20, 245, 320, 200, 800)
    for i = 1, 30 do
      ui.label("List element " .. i, 10, i * 26 - 20)
    end
  ui.endScroll()
end
```

### 3.4 Window Management: Menus, Titles, and Status Indicators

#### Menu Bar Registration

Applications register menus that populate the global OS menu bar when the window has focus:

```lua
function app.menu()
  return {
    {
      title = TR("menu.file"),
      items = {
        { label = TR("menu.new"), id = 101, shortcut = "Ctrl+N" },
        { label = TR("menu.open"), id = 102, shortcut = "Ctrl+O" },
        "-",
        { label = TR("menu.save"), id = 103, shortcut = "Ctrl+S" }
      }
    }
  }
end

function app.onmenu(id)
  if id == 101 then new_file()
  elseif id == 102 then open_file()
  elseif id == 103 then save_file() end
end
```

In Native C (`nxn_menu.h`):
```c
nxn_menu_item items[] = {
    {sizeof(nxn_menu_item), 101, "menu.new", "Ctrl+N", 0, 0},
    {sizeof(nxn_menu_item), 0, NULL, NULL, NXN_MENU_SEPARATOR, 0},
    {sizeof(nxn_menu_item), 103, "menu.save", "Ctrl+S", 0, 0}
};
nxn_menu_menu menus[] = {
    {sizeof(nxn_menu_menu), "menu.file", items, 3, sizeof(nxn_menu_item)}
};
nxn_menu_spec spec = {sizeof(nxn_menu_spec), menus, 1, sizeof(nxn_menu_menu)};
nxn_menu_set(&spec);
```

#### Window Title, Subtitle, and Modification Dot (Native 1.2)

```c
#include <nexvyn/nxn_window.h>

// Set title and subtitle: "Project.c - Code Editor"
nxn_window_set_title("Project.c", "Code Editor");

// Mark document as modified (displays edited mark dot in title bar)
nxn_window_set_modified(1);

// Switch window mode: NXN_WIN_NORMAL, NXN_WIN_MAXIMIZED, NXN_WIN_FULLSCREEN
nxn_window_set_mode(NXN_WIN_FULLSCREEN);
```

### 3.5 System Modals: Dialogs, Prompts, and Virtual Keyboard

#### Alert and Prompt Dialogs

```lua
-- Modal Alert Dialog
ui.alert("Confirm Discard", "Discard changes to this document?", {"Discard", "Cancel"}, function(btn)
  if btn == 1 then discard_document() end
end)

-- Text Prompt Dialog
ui.prompt("Rename Item", "Enter new name:", "Document", function(text)
  if text then apply_new_name(text) end
end)
```

In Native C (`nxn_dialog.h`):
```c
const char* labels[] = {"Confirm", "Cancel"};
nxn_dialog_params params = NXN_STRUCT_INIT(nxn_dialog_params);
params.title = "Delete File";
params.message = "Are you sure you want to delete this file?";
params.buttons = labels;
params.button_count = 2;
params.danger_button = 0; // "Confirm" drawn in destructive style
params.cancel_button = 1; // "Cancel" mapped to Esc / B

uint32_t chosen = 0;
// Note: nxn_dialog blocks the calling thread while keeping the OS compositor responsive.
if (nxn_dialog(&params, &chosen) == NXN_OK && chosen == 0) {
    execute_file_deletion();
}
```

#### On-Screen Keyboard Request (Native 1.2)

Native controls request the OS virtual keyboard when custom text input gains focus:

```c
#include <nexvyn/nxn_input.h>

void on_custom_text_focus(void) {
    nxn_input_text_request(1); // Virtual keyboard opens
}

void on_custom_text_blur(void) {
    nxn_input_text_request(0); // Virtual keyboard hides
}
```

### 3.6 Game Art Direction and Presentation Standards

Game developers must follow these principles:
1. **Cohesive In-Game HUD**: Develop typography, dialogue boxes, health meters, and pause screens using in-engine 2D drawing (`gfx.*`), sprite batches, or shaders.
2. **Distinct Identity**: Every game must feel like a standalone production. Avoid default grey buttons or OS-styled windows within game scenes.
3. **Typography**: Bundle custom pixel or TrueType fonts in your bundle and load them with `gfx.text` or engine font loaders.

### 3.7 Quick Reference: UI and Game Rules
- **MUST**: Use `ui.tokens()` for standard desktop and utility applications.
- **MUST NOT**: Use OS widgets as in-game menus in video games.
- **MUST**: Map dialog cancel actions to `NXN_DIALOG_NONE` or button indices that respond to the B button.

---

## Chapter 4: Input Architecture, Controllers, and Surface Pixels

### 4.1 Coordinate Space: The Surface Pixels Rule

> [!IMPORTANT]
> **CRITICAL ARCHITECTURAL INVARIANT: SURFACE PIXELS**
> Coordinates delivered to your application through `app.event(e)`, `ui.mouse()`, or `nxn_input_touch` are **already in surface pixels** (local content space).
> - `(0, 0)` is strictly the top-left corner of your application's rendered content area.
> - `(w, h)` are the exact content dimensions in physical pixels.
> - **NEVER** re-multiply or re-scale touch/pointer coordinates by screen resolution scale factors or aspect ratios! Doing so produces the "double-scaled pointer" bug where touch coordinates drift wildly from the physical finger position.

### 4.2 Pointer, Mouse, and Multi-Touch Input

The touch screen supports up to 16 simultaneous fingers with stable track identifiers:

```lua
function app.event(e)
  if e.type == "mousedown" or e.type == "mousemove" then
    local px, py = e.x, e.y -- Already in local surface pixels!
    process_pointer(px, py, e.button)
  elseif e.type == "pinch" then
    -- e.scale: Ratio of finger distance change (> 1.0 = apart, < 1.0 = together)
    zoom_factor = math.max(0.2, math.min(5.0, zoom_factor * e.scale))
  elseif e.type == "rotate" then
    -- e.angle: Angular change in radians since last frame (positive = clockwise)
    rotation_angle = rotation_angle + e.angle
  end
end
```

Native Multi-Touch Inspection (`nxn_input.h`):
```c
nxn_input_state in_state = NXN_STRUCT_INIT(nxn_input_state);
if (nxn_input_poll(&in_state) == NXN_OK) {
    for (uint32_t i = 0; i < in_state.touch_count; i++) {
        nxn_touch touch = NXN_STRUCT_INIT(nxn_touch);
        if (nxn_input_touch(i, &touch) == NXN_OK) {
            // touch.id: Stable identifier while held
            // touch.x, touch.y: Local surface pixels
            handle_touch_point(touch.id, touch.x, touch.y);
        }
    }
}
```

### 4.3 Controller Input, Bitmasks, and Deadzones

When `"gamepad": true` is set in `app.json`, all controller inputs route directly to the active window.

#### Button Constants Bitmask (`nxn_input.h`)

| Constant | Bit Mask | Physical Button |
|---|---|---|
| `NXN_BTN_A` | `1ULL << 0` | A (East action button) |
| `NXN_BTN_B` | `1ULL << 1` | B (South action button) |
| `NXN_BTN_X` | `1ULL << 2` | X (North action button) |
| `NXN_BTN_Y` | `1ULL << 3` | Y (West action button) |
| `NXN_BTN_LSTICK` | `1ULL << 4` | L3 (Left Stick Click) |
| `NXN_BTN_RSTICK` | `1ULL << 5` | R3 (Right Stick Click) |
| `NXN_BTN_L` | `1ULL << 6` | L (Left Shoulder Trigger) |
| `NXN_BTN_R` | `1ULL << 7` | R (Right Shoulder Trigger) |
| `NXN_BTN_ZL` | `1ULL << 8` | ZL (Left Analog/Digital Trigger) |
| `NXN_BTN_ZR` | `1ULL << 9` | ZR (Right Analog/Digital Trigger) |
| `NXN_BTN_PLUS` | `1ULL << 10` | Plus (+) Button |
| `NXN_BTN_MINUS` | `1ULL << 11` | Minus (-) Button |
| `NXN_BTN_LEFT` | `1ULL << 12` | D-Pad Left |
| `NXN_BTN_UP` | `1ULL << 13` | D-Pad Up |
| `NXN_BTN_RIGHT` | `1ULL << 14` | D-Pad Right |
| `NXN_BTN_DOWN` | `1ULL << 15` | D-Pad Down |

Polling Input in Lua:
```lua
function app.update(dt)
  -- Analog sticks return -1.0 to 1.0 (Y-axis: positive is UP)
  local lx, ly = input.stick("left")
  local rx, ry = input.stick("right")

  -- Apply 10% deadzone
  if math.abs(lx) < 0.1 then lx = 0.0 end
  if math.abs(ly) < 0.1 then ly = 0.0 end

  if input.down("a") then fire_weapon() end
  if input.pressed("plus") then toggle_pause_menu() end
end
```

Native Button Query:
```c
nxn_input_state s = NXN_STRUCT_INIT(nxn_input_state);
nxn_input_poll(&s);

if (s.pressed & NXN_BTN_A) {
    character_jump();
}
// Analog sticks: -1.0f to 1.0f
float move_x = s.lx;
float move_y = s.ly;
```

### 4.4 Logical Actions and System Remapping

Users can remap Confirm and Cancel actions in System Settings. Applications should honour these preferences:

```c
// Respect user-mapped Confirm and Cancel actions
if (s.actions_pressed & NXN_ACT_CONFIRM) {
    accept_selection();
} else if (s.actions_pressed & NXN_ACT_CANCEL) {
    back_or_exit();
}
```

### 4.5 USB Keyboard and Typing Input

When a USB keyboard is connected, raw keys and text arrive via events:

```c
#include <nexvyn/nxn_input.h>

// Inspect USB HID usage held state
if (nxn_input_key_held(4)) { // 4 = USB HID 'a'
    strafe_left();
}

// Drain queued text input buffer (UTF-8)
char typed_text[128];
int bytes = nxn_input_text(typed_text, sizeof(typed_text));
if (bytes > 0) {
    append_to_editor(typed_text);
}
```

### 4.6 HD Rumble and Haptic Actuation

```lua
-- strength: 0.0 (off) to 1.0 (maximum)
-- duration: 1 to 2000 milliseconds (automatically clamped)
sys.vibrate(0.7, 180)
```

In Native C (`nxn_sys.h`):
```c
// Non-blocking rumble command; stops automatically after duration
nxn_rumble(0.85f, 250);
```

### 4.7 Quick Reference: Input Rules
- **MUST NOT**: Apply resolution scaling math to pointer coordinates delivered by `app.event` or `nxn_input_touch`.
- **MUST**: Apply deadzone thresholds (at least 0.1) to analog stick readings.
- **MUST**: Support both touch screen and gamepad navigation in menus.

---

## Chapter 5: Graphics Architecture — 2D Canvas, `g3d` PBR, and Native OpenGL

### 5.1 2D Vector Canvas Pipeline (`gfx.*`)

The immediate 2D graphics library renders high-speed vector primitives:

```lua
function app.draw(w, h)
  gfx.clear("#12141A")

  -- 1. Rectangles and Rounded Corners
  gfx.color("#3A86FF")
  gfx.rect(30, 30, 200, 120, 10) -- Filled rectangle with 10px corner radius
  gfx.rectLine(30, 30, 200, 120, 10, 2.0) -- Outline

  -- 2. Circles, Arcs, and Lines
  gfx.circle(300, 90, 45, "#FF006E")
  gfx.line(30, 180, 380, 180, 2.5)

  -- 3. Soft Drop Shadows and Gradients
  gfx.shadow(30, 210, 220, 90, 8, 12.0, 4.0)
  gfx.gradient(30, 210, 220, 90, "#8338EC", "#3A86FF", false, 8)

  -- 4. Text and Font Layout
  gfx.color("#FFFFFF")
  gfx.text("Nexvyn Graphics Engine", 30, 320, 22, "bold")
  local text_h = gfx.wrap("Multi-line text wraps automatically according to layout width.", 30, 350, 300, 16, "sans")

  -- 5. Sprites and Texture Regions
  local sheet = gfx.image("bundle:/sprites/atlas.png")
  if sheet then
    -- drawRegion(img, sx, sy, sw, sh, dx, dy, dw, dh, [angleDeg])
    gfx.drawRegion(sheet, 0, 0, 32, 32, 30, 370 + text_h, 64, 64)
  end
end
```

### 5.2 Real-Time 3D Engine (`g3d`) Basics and Primitives

The built-in `g3d` subsystem runs on the hardware GPU with depth testing, directional lighting, and fog:

```lua
local cube_mesh, sphere_mesh

function app.load()
  -- Create procedural meshes
  cube_mesh = g3d.mesh("box", 1.5, 1.5, 1.5)
  cube_mesh:setColor("#4CC9F0")

  sphere_mesh = g3d.mesh("sphere", 1.0, 32, 16)
  sphere_mesh:setColor("#F72585")
end

function app.draw(w, h)
  gfx.clear("#0F1117")

  g3d.begin(0, 0, w, h, 60.0) -- Viewport x, y, w, h, FOV degrees
  g3d.camera(0.0, 4.0, 7.0, 0.0, 0.0, 0.0)
  g3d.light(0.5, 1.0, 0.4, 0.3, "#FFFFFF")
  g3d.fog("#0F1117", 8.0, 25.0)

  g3d.draw(cube_mesh, -1.8, 0.0, 0.0, 0.0, rotation_y, 0.0)
  g3d.draw(sphere_mesh, 1.8, 0.0, 0.0)

  g3d.finish()
end
```

### 5.3 Skeletal 3D Models (`g3d.model`) and Animation Blending

`g3d.model` loads `.glb`, `.gltf`, and `.fbx` assets complete with bone hierarchies, skeletal skinning, and material textures:

```lua
local character

function app.load()
  -- Load model asynchronously on worker thread
  g3d.loadModel("bundle:/models/warrior.glb", 2.0, function(model, err)
    if model then
      character = model
      character:play("Idle", { loop = true, speed = 1.0 })
    else
      sys.log("Model loading error: " .. tostring(err))
    end
  end)
end

function app.update(dt)
  if character then
    character:update(dt) -- Advance active animation clip
  end
end

-- Crossfade to a new animation clip over 0.3 seconds
function trigger_run()
  if character then
    character:play("Run", { loop = true, speed = 1.2, fade = 0.3 })
  end
end
```

### 5.4 Modern PBR Rendering with NexGFX (`g3d.renderer("pbr")`)

SDK 1.9 introduces the opt-in physically based rendering (PBR) core:

```lua
function app.load()
  -- Activate the NexGFX PBR pipeline
  g3d.renderer("pbr")

  -- Configure HDR, post-processing, and shadows
  g3d.postfx({ exposure = 1.0, tonemap = "aces", bloom = 0.06, msaa = 4 })
  g3d.shadows({ quality = "high", distance = 35.0, bias = 0.002 })
  g3d.environment({ sky = "#7AA5D8", ground = "#382D24", sun = 3.2 })

  -- Register real-time point light
  point_light = g3d.addLight({
    type = "point",
    x = 0.0, y = 2.5, z = 1.0,
    color = "#FF9E3B",
    intensity = 8.0,
    range = 10.0
  })
end
```

### 5.5 GPU Instanced Rendering

Render thousands of instances with a single draw call:

```lua
-- Array of 7 floats per instance: {x, y, z, rx, ry, rz, scale, ...}
local forest = {}
for i = 1, 1000 do
  table.insert(forest, math.random(-60, 60)) -- x
  table.insert(forest, 0.0)                  -- y
  table.insert(forest, math.random(-60, 60)) -- z
  table.insert(forest, 0.0)                  -- rx
  table.insert(forest, math.random() * 6.28) -- ry
  table.insert(forest, 0.0)                  -- rz
  table.insert(forest, math.random(8, 12) / 10.0) -- scale
end

g3d.drawInstanced(tree_mesh, forest, "#FFFFFF", "nocull")
```

### 5.6 Native Desktop OpenGL Core 4.3 and GLES 3.2 via Mesa

Native C/C++ applications access the hardware GPU via Mesa:

```c
#include <nexvyn/nxn_display.h>
#include <glad/glad.h>

nxn_display* disp;

void init_gl(void) {
    // 1. Initialise display surface bound to window geometry
    nxn_display_open(NULL, 1280, 720, &disp);

    // 2. Load OpenGL core function pointers via the host loader
    gladLoadGLLoader((GLADloadproc)nxn_display_proc);

    // 3. Configure pipeline
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);
    glEnable(GL_CULL_FACE);
}

void render_frame(void) {
    // Framebuffer 0 represents the window's content surface
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0, 0, current_w, current_h);
    glClearColor(0.08f, 0.1f, 0.14f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    // Execute native OpenGL drawing...

    // 4. Synchronise with OS compositor
    nxn_display_swap(disp);
}
```

### 5.7 Frame Pacing, Vsync, and Resolution Profiles

- Native display presentation is paced by `nxn_display_swap`, which waits for the OS compositing vsync.
- Frame execution must complete within **16.66 ms** for 60 fps.
- When the console docks, `NXN_EVENT_RESIZE` arrives with `1920x1080`; when undocked, `1280x720`. Call `nxn_display_resize` to adapt your framebuffer.

### 5.8 Quick Reference: Graphics Rules
- **MUST**: Pre-load all 3D meshes and models in `app.load` rather than per-frame.
- **MUST**: Check `g3d.caps()` to verify hardware features on the running console.
- **MUST NOT**: Call `eglMakeCurrent` or create secondary raw OpenGL contexts in native modules.

---

## Chapter 6: Audio System and the OS Sound Mixer

### 6.1 Audio Architecture and Mixer Hierarchy

The audio subsystem comprises three functional layers:
1. **OS Sound Mixer**: Zero-latency one-shot triggers (`audio.play`, `nxn_sfx_play`, `nxn_tone`).
2. **Music Streaming**: Disk-streamed background music playback (`audio.music`).
3. **Native PCM Push Streams**: Raw 16-bit stereo buffers for emulators and engines (`nxn_audio_queue`).

All sounds automatically cease when the application closes or goes to sleep.

### 6.2 Script Audio API: Tones, Sound Effects, and Music

```lua
-- 1. Synthesize Pure Audio Tones
-- Freq (Hz), Duration (s), Volume (0..1), Waveform ("sine", "square", "saw", "triangle", "noise")
audio.tone(523.25, 0.2, 0.7, "sine")

-- 2. Trigger System Sound Effects and Audio Files
-- Returns channel ID
local ch = audio.play("bundle:/sfx/laser.wav", 0.9, 0) -- 0 = once, -1 = loop

-- Built-in system triggers:
-- "click", "pop", "notify", "alarm", "trash", "shutter", "error", "key", "volume", "startup"
audio.play("click")

-- Stop all sound effects started by this application (SDK 1.12+)
audio.stopAll()

-- 3. Streaming Background Music
audio.music("bundle:/bgm/adventure.ogg")
audio.musicPause(true)  -- Pause music
audio.musicPause(false) -- Resume music
audio.musicStop()       -- Stop and unload track
```

### 6.3 Native Sound Mixer (`NXN_CAP_MIXER`)

Native applications trigger audio without maintaining their own mixing threads:

```c
#include <nexvyn/nxn_audio.h>

// Trigger audio file on the OS mixer (non-blocking)
nxn_sfx_play("bundle:/sfx/explosion.wav", 1.0f);

// Synthesize tone
nxn_tone(440.0f, 0.25f, 0.8f, "triangle");

// Silence all active sound effects owned by this module
nxn_sfx_stop_all();
```

### 6.4 Native Push PCM Audio Streams

For emulators or synthesizers generating custom audio waveforms:

```c
nxn_audio_params params = NXN_STRUCT_INIT(nxn_audio_params);
params.rate = 48000;
params.channels = 2;              // stereo
params.format = NXN_AUDIO_S16;    // signed 16-bit, interleaved
params.callback = NULL;           // push mode: you call nxn_audio_queue

nxn_audio* stream = NULL;
nxn_audio_open(&params, &stream); // the stream starts paused
nxn_audio_pause(stream, 0);

// Queue 16-bit interleaved PCM frames (one producer thread at a time)
int16_t samples[1024 * 2];
render_synth_audio(samples, 1024);
nxn_audio_queue(stream, samples, sizeof(samples));

// Drop everything queued but not played yet (state restore, seek, leaving a menu).
// Check NXN_CAP_AUDIO_CLEAR (Native 1.1) in nxn_caps.features first.
nxn_audio_clear(stream);

nxn_audio_close(stream);
```

### 6.5 Latency, Formats, and Channel Downmixing

- The OS audio engine operates at a native sample rate of **48,000 Hz**.
- Latency for push streams averages ~42.7 ms for 1024 samples.
- The mixer automatically downmixes multichannel audio streams to stereo output.

### 6.6 Quick Reference: Audio Rules
- **MUST**: Call `nxn_audio_clear` or pause audio immediately inside `app.suspend` / `NXN_EVENT_SUSPEND`.
- **MUST NOT**: Block the main rendering thread while generating or waiting for audio buffers.

---

## Chapter 7: Storage, Sandboxing, Network, and Security

### 7.1 Virtual Filesystem Sandboxing and Protected Roots

Applications run in a sandboxed virtual filesystem:

```
Virtual Path                     Physical Target & Permission
─────────────────────────────────────────────────────────────────────────────
bundle:/                         Read-Only package assets inside .nxvapp
~/Library/Application Support/<id>/ Persistent private app data (No permission needed)
~/Library/Caches/<id>/           Temporary cache storage (Evictable by system)
~/Library/Backups/<id>/<slot>    Named save-game backups
sdmc:/                           SD card root (Requires "files" permission)
sdmc:/NexvynOS/System/           PROTECTED SYSTEM DIR: Always read-only to apps!
```

App Guard permanently blocks applications from modifying `sdmc:/NexvynOS/System` or accessing other applications' private libraries, even when the `"files"` permission is granted.

### 7.2 Atomic Persistence Pattern (Data Loss Prevention)

> [!CAUTION]
> **Data Integrity Rule**: Writing directly to your destination file is vulnerable to total corruption if the console is switched off, power is lost, or an unhandled exception occurs mid-write. Always write to a temporary file and atomically rename.

```lua
function save_data_atomic(relative_filename, data_content)
  local full_dest = fs.path(relative_filename)
  local temp_dest = full_dest .. ".tmp"

  -- 1. Write payload to temporary file
  local ok, err = fs.write(temp_dest, data_content)
  if not ok then
    sys.log("Atomic write failed: " .. tostring(err))
    return false
  end

  -- 2. Atomically rename temporary file over target
  ok, err = fs.rename(temp_dest, full_dest)
  if not ok then
    sys.log("Atomic swap failed: " .. tostring(err))
    return false
  end

  return true
end
```

### 7.3 Save Game Management and Backups

The SDK provides dedicated save management APIs (`fs.saveBackup`, `fs.saveRestore` / `nxn_save_backup`, `nxn_save_restore`):

```lua
-- Create a named save backup outside the application's volatile folder
fs.saveBackup("boss_checkpoint", function(ok, err)
  if ok then sys.log("Backup preserved safely.") end
end)

-- Restore a named backup
fs.saveRestore("boss_checkpoint", function(ok, err)
  if ok then reload_game_state() end
end)
```

In Native C (`nxn_sys.h`):
```c
char save_dir[256];
nxn_save_path(save_dir, sizeof(save_dir)); // Retrieves <data>/save/

// Asynchronously or on a worker thread:
nxn_save_backup("slot_01");
nxn_save_restore("slot_01");
```

### 7.4 Asynchronous HTTP Networking (`net.request`)

All network requests require `"network"` in `app.json` `permissions` and execute asynchronously:

```lua
local id = net.request({
  url = "https://api.example.com/v1/profile",
  method = "GET",
  headers = { Authorization = "Bearer " .. token },
  responseType = "json",
  timeout = 15,
  retry = 3,       -- Exponential backoff on 5xx and 429 errors
  cache = 300,     -- Fresh for 300 s; returns stale copy when offline
  cookies = true   -- Maintain persistent cookie jar
}, function(res)
  if res.ok then
    render_profile(res.data)
  else
    show_error(res.error)
  end
end)
```

### 7.5 Persistent WebSockets (`net.ws`)

```lua
local ws = net.ws("wss://live.example.com/stream")

function app.update(dt)
  for _, event in ipairs(net.wsPoll(ws)) do
    if event.type == "open" then
      net.wsSend(ws, "hello")
    elseif event.type == "message" then
      dispatch_event(event.data)
    elseif event.type == "close" then
      schedule_reconnect()
    end
  end
end
```

### 7.6 Secure Authentication via OAuth 2.0 PKCE (`net.oauth`)

Applications must never prompt users for third-party service passwords. Use `net.oauth` (RFC 8252):

```lua
net.oauth({
  url = "https://auth.example.com/authorize?client_id=MY_ID&response_type=code",
  redirect = "http://localhost/callback",
  pkce = true
}, function(res, err)
  if err then
    sys.log("OAuth error: " .. err)
    return
  end
  exchange_token(res.code, res.verifier)
end)
```

### 7.7 Security Rules: Secrets and Kernel Isolation
- **Secrets Prohibition**: NEVER bundle API secrets or private encryption keys in the client bundle.
- **Filesystem Boundaries**: Applications cannot traverse outside their sandbox root without explicit user permission.

### 7.8 Quick Reference: Storage and Network Rules
- **MUST**: Use atomic file swaps (`.tmp` write followed by `fs.rename`) for game saves and configuration files.
- **MUST**: Declare `"network"` in `app.json` before invoking any `net.*` API.
- **MUST NOT**: Store plain passwords or secret tokens in unencrypted local storage.

---

## Chapter 8: Internationalisation and the 8 UI Languages

### 8.1 Localisation File Architecture

Applications place translation catalogs in the `lang/` subdirectory:

```text
MyApp.nxvapp/
└── lang/
    ├── en.json   # REQUIRED: English reference catalog
    ├── tr.json   # Turkish
    ├── de.json   # German
    ├── es.json   # Spanish
    ├── fr.json   # French
    ├── ja.json   # Japanese
    ├── ko.json   # Korean
    └── zh.json   # Simplified Chinese
```

### 8.2 Translation Format and Parameter Replacement

Translations support dot-separated hierarchical namespaces and numbered replacement parameters:

```json
{
  "menu": {
    "play": "Start Game",
    "settings": "Settings",
    "quit": "Quit to Desktop"
  },
  "score": "High Score: {0} pts (Rank #{1})"
}
```

### 8.3 The Translation Fallback Chain

When a localized string is requested at runtime:
```
Requested Locale (e.g., "tr") ──► Base Language ("en") ──► System Global Strings ──► Raw Key Name
```
A partial translation file is completely valid: missing translation keys automatically fall back to the English entry in `lang/en.json`.

### 8.4 Translation Queries in Scripts and Native Code

In Lua:
```lua
-- Simple key lookup
local play_btn = TR("menu.play")

-- Formatted parameter replacement
local score_label = TR("score", 9850, 4)
```

In Native C (`nxn_ui.h`):
```c
// Direct translated string
const char* play_text = nxn_tr("menu.play");

// Formatted translation buffer
char buffer[128];
const char* args[] = { "9850", "4" };
nxn_tr_format("score", buffer, sizeof(buffer), args, 2);
```

### 8.5 Typography and CJK / Extended Character Coverage

The operating system includes the Inter font family for Latin, Greek, and Cyrillic scripts. When running under Japanese, Korean, or Chinese system languages, the system dynamically mounts CJK glyph sets (`NXN_UI_FONT_CJK` / `NXN_CAP_UI_FONT_CJK`).

In Dear ImGui applications, include `<nexvyn/nxn_imgui.h>` and invoke `nxn_imgui_add_font(io.Fonts, NXN_UI_FONT_SANS, 20.0f, 0, NULL)` to configure glyph ranges automatically without bloating the font atlas.

### 8.6 Quick Reference: Localisation Rules
- **MUST**: Ship `lang/en.json` whenever `TR()` or `nxn_tr()` is utilised.
- **MUST**: Format replacement variables using `{0}`, `{1}` syntax.

---

## Chapter 9: Native C and C++ Applications (`.nxvmod` and Native SDK 1.2)

### 9.1 Toolchain Architecture and Compilation Model

Native apps compile as AArch64 shared dynamic libraries with the `.nxvmod` extension. The operating system loads the module directly into its process space and maps execution to the window surface.

- **Standard**: C11 and C++17 (GNU dialect).
- **Optimization Flags**: `-O2 -fno-omit-frame-pointer -mno-omit-leaf-frame-pointer -fPIC`.
- **Target Architecture**: `-march=armv8-a+crc+crypto -mtp=soft`.

### 9.2 Native SDK ABI v1 Freeze and Capability Discovery

> [!IMPORTANT]
> **ABI v1 Freeze Guarantee (2026-11-09)**
> All `nxn_*` function signatures, struct layouts, error codes, and capability bits in ABI v1 are strictly frozen. They are append-only.
> - All structs begin with `uint32_t size`.
> - Always initialise versioned structs with `NXN_STRUCT_INIT(struct_type)`.
> - Always verify capability bits (`nxn_caps_get`) prior to calling optional system services.

### 9.3 Complete `nxn_*` API Tour and Signatures

#### 1. Core Lifecycle (`nxn_app.h`)
```c
nxn_result nxn_init(const nxn_init_params* params);
void nxn_shutdown(void);
int nxn_run(int argc, char** argv, nxn_entry_fn entry, const nxn_init_params* params);
int nxn_should_quit(void);
void nxn_request_return(nxn_return_reason reason, int32_t code, const char* message);
nxn_result nxn_caps_get(nxn_caps* out);
nxn_result nxn_info_get(nxn_info* out);
const char* nxn_info_string(nxn_info_key key);
const char* nxn_last_error(void);
```

#### 2. Window Control — Native 1.2 (`nxn_window.h`, `NXN_CAP_WINDOW_CTL`)
```c
nxn_result nxn_window_set_title(const char* title, const char* subtitle);
nxn_result nxn_window_set_mode(nxn_window_mode mode); // NXN_WIN_NORMAL, MAXIMIZED, FULLSCREEN
nxn_result nxn_window_set_modified(int modified);     // 1 = unsaved work dot, 0 = clean
```

#### 3. Power and Battery State — Native 1.2 (`nxn_power.h`, `NXN_CAP_POWER_STATE`)
```c
typedef struct nxn_power {
    uint32_t size;
    int32_t percent;    // Battery 0..100, -1 = unknown
    uint32_t charging;  // 1 = charging, 0 = discharging
    uint32_t docked;    // 1 = TV dock (1080p), 0 = handheld (720p)
    uint32_t online;    // 1 = internet active, 0 = offline
    uint32_t reserved;
} nxn_power;

nxn_result nxn_power_get(nxn_power* out);
```

#### 4. OS Dialogs and Prompts — Native 1.2 (`nxn_dialog.h`, `NXN_CAP_DIALOG`)
```c
typedef struct nxn_dialog_params {
    uint32_t size;
    uint32_t flags;
    const char* title;
    const char* message;
    const char* const* buttons;
    uint32_t button_count;
    uint32_t cancel_button;
    uint32_t danger_button;
    uint32_t reserved;
} nxn_dialog_params;

nxn_result nxn_dialog(const nxn_dialog_params* params, uint32_t* picked);
nxn_result nxn_prompt(const char* title, const char* message, const char* initial, char* out, size_t cap);
```

#### 5. Window Menu Bar (`nxn_menu.h`, `NXN_CAP_MENU`)
```c
nxn_result nxn_menu_set(const nxn_menu_spec* spec);
nxn_result nxn_menu_clear(void);
```

#### 6. Input and Virtual Keyboard (`nxn_input.h`)
```c
nxn_result nxn_input_poll(nxn_input_state* out);
nxn_result nxn_input_touch(uint32_t index, nxn_touch* out);
int nxn_input_key_held(uint32_t hid_usage);
int nxn_input_key_poll(nxn_key_event* out);
int nxn_input_text(char* out, size_t cap);
nxn_result nxn_input_text_request(int wanted); // Native 1.1, NXN_CAP_TEXT_REQUEST: ask the OS keyboard
int nxn_input_mouse(nxn_mouse* out);
nxn_result nxn_input_action_buttons(const char* action, uint64_t* mask); // NXN_CAP_INPUT_ACTIONS: the user's button mapping for a named action
```

#### 7. System Events Queue (`nxn_event.h`, `NXN_CAP_EVENTS`)
```c
int nxn_event_poll(nxn_event* out);
```
Event types: `NXN_EVENT_RESIZE`, `NXN_EVENT_QUIT`, `NXN_EVENT_FOCUS`, `NXN_EVENT_DOCK`, `NXN_EVENT_SUSPEND`, `NXN_EVENT_RESUME`, `NXN_EVENT_THEME`, `NXN_EVENT_MENU`, `NXN_EVENT_POWER`.

#### 8. System Services and File Pickers (`nxn_sys.h`)
```c
uint64_t nxn_time_ns(void);
int64_t nxn_time_unix(void);
void nxn_sleep_ns(uint64_t ns);
nxn_result nxn_thread_start(const nxn_thread_params* params, nxn_thread** out);
nxn_result nxn_thread_join(nxn_thread* t);
void nxn_log(nxn_log_level level, const char* fmt, ...);
nxn_result nxn_perm_query(const char* name, nxn_perm_state* out);
nxn_result nxn_perm_request(const char* name, nxn_perm_state* out);
nxn_result nxn_notify(const char* title, const char* body);
nxn_result nxn_clipboard_get(char* buf, size_t cap, size_t* len);
nxn_result nxn_clipboard_set(const char* text);
nxn_result nxn_rumble(float strength, uint32_t ms);
nxn_result nxn_pick(const nxn_pick_params* params, char* path, size_t cap);
nxn_result nxn_grant_get(uint32_t index, char* path, size_t cap);
nxn_result nxn_grant_check(const char* path, int* granted);
nxn_result nxn_grant_revoke(const char* path);
nxn_result nxn_save_path(char* path, size_t cap);
nxn_result nxn_save_backup(const char* slot);
nxn_result nxn_save_restore(const char* slot);
nxn_result nxn_save_backup_get(uint32_t index, char* slot, size_t cap);
nxn_result nxn_save_backup_delete(const char* slot);
```

### 9.4 Windowed Mode vs Fullscreen Execution

A single native binary targets both presentation modes:
- `"mode": "window"`: Runs in a standard desktop window with title bar and borders.
- `"mode": "fullscreen"`: Runs full screen with OS menu bar and Dock hidden. The menu bar automatically slides into view only when the cursor lingers at the very top edge.
- Users switch between window and fullscreen seamlessly (Ctrl+Alt+F or window menu); the application receives `NXN_EVENT_RESIZE` and adapts its viewport.

### 9.5 Concurrency and Locking Invariants

> [!CAUTION]
> **Lock Invariant Rule**: Never block on a synchronization lock held across worker threads if that same lock is needed by the main UI thread during `nxn_display_swap` or message processing. Doing so produces a deadlock that stalls the entire OS desktop.

### 9.6 Arena Memory Model and Crash Containment

- All allocations (`malloc`, `realloc`, `calloc`) originate from a private memory arena dedicated to the application.
- When the application quits or crashes, the entire arena is reclaimed in a single kernel step, preventing persistent memory leaks.
- A fatal CPU exception (SIGSEGV / data abort) within any application thread is intercepted by the crash guard (`NXN_CAP_CRASH_GUARD`). The error is written to `System/Logs/Crashes/` and the application window closes safely without taking down the operating system.

### 9.7 App Guard Trust Model for Native Code

- **Store Installations**: Packages installed via the App Market are inspected during packaging and receive a trust record (`apps.nativeTrust`), launching without prompts.
- **Sideloaded Modules**: Packages copied manually to `sdmc:/NexvynOS/Applications/` prompt the user once on first execution (*"Run unsandboxed native application?"*). Upon confirmation, the module hash is recorded in `appguard.json` and subsequent launches proceed immediately.

### 9.8 Porting Architecture: SDL2 Driver and Libretro Cores

The Native SDK provides an altered SDL 2.28 driver that redirects video, audio, and controller input directly into the `nxn_*` host interfaces:
- Video maps to `nxn_display`.
- Audio streams to `nxn_audio`.
- Controller input maps to `nxn_input`.
- Emulator packages (such as ported Libretro cores) adopt the `emufront` frontend architecture: left navigation rail, cover grid, game detail pane, and worker-thread screenshot capture.

### 9.9 Quick Reference: Native Rules
- **MUST**: Initialise all versioned structs using `NXN_STRUCT_INIT(struct_type)`.
- **MUST**: Check capability bits with `nxn_caps_get()` before invoking optional system services.
- **MUST NOT**: Call `chdir()` or attempt to alter the working directory of the shared host process.

---

## Chapter 10: The OS Browser as an Application Platform

The Nexvyn OS Browser engine (`source/web/`) serves as a self-contained runtime for modern web applications.

### 10.1 Web Engine Architecture and Standards

The engine combines an HTML5 parser, CSS layout engine, and QuickJS-ng ECMAScript environment. It features zero background overhead when no browser window is open.

### 10.2 HTML5, CSS Grid, Flexbox, and Styling

- **Flexbox**: Full row and column flexbox (`flex-grow`, `flex-shrink`, `flex-basis`, `gap`, `justify-content`, `align-items`).
- **CSS Grid**: Multi-column grids (`grid-template-columns: repeat(auto-fill, minmax(180px, 1fr))`, `grid-area`, `gap`).
- **Variables & Animations**: CSS Custom Properties (`var(--accent)`), `@keyframes` animations, and CSS transitions.
- **Graphics & Vectors**: Inline SVG rendering, `<use>` sprites, and WebP decoding.

### 10.3 High-Performance Canvas 2D and WebGL 2

- **Canvas 2D**: Standard immediate canvas (`getContext('2d')`), Bézier curves, path clipping, gradients, pattern fills, 26 Porter-Duff compositing modes, and Gaussian shadow blur.
- **WebGL 2**: Full `WebGL2RenderingContext` supported by the console's GLES 3.2 pipeline. Features vertex array objects (VAOs), uniform buffer objects (UBOs), instancing (`drawArraysInstanced`), 3D textures, and multiple render targets.

### 10.4 Web Workers, Threading, and Structured Cloning

- Up to **4 concurrent Web Workers** (`new Worker('worker.js')`).
- Each worker executes on an independent OS thread with an isolated QuickJS runtime.
- Inter-thread messaging uses standard structured cloning supporting typed arrays, BigInt, objects, and transferable `ArrayBuffer` instances.

### 10.5 Persistent Storage via IndexedDB

Web applications store persistent client data using standard IndexedDB:
- Object stores, primary keys, key generators, and compound indexes.
- Transactional read/write semantics with automatic rollback on error.
- Quota: Up to 32 MB per web origin.

### 10.6 WebAudio API and Digital Sound Synthesis

- Node graph: `AudioContext`, `OscillatorNode`, `GainNode`, `AudioBufferSourceNode`, `BiquadFilterNode`, `StereoPannerNode`, and `DynamicsCompressorNode`.
- Audio graph computes on a dedicated low-priority audio thread mixing into the OS sound stream.

### 10.7 Gamepad API and Fullscreen Presentation

- Standard `navigator.getGamepads()` reporting 17 buttons and 4 analog axes.
- Vibration supported via `gamepad.vibrationActuator.playEffect('dual-rumble', ...)`.
- Fullscreen element presentation supported via `element.requestFullscreen()`.

### 10.8 Video Playback, MSE, and ClearKey EME

- Codecs: H.264 video up to 720p, VP8, AAC, and Vorbis audio.
- Streaming: MediaSource Extensions (MSE) with fragmented MP4 and WebM.
- ClearKey: W3C ClearKey decryption (`org.w3.clearkey`) for CENC AES-CTR streams.

### 10.9 Engine Limitations and Unsupported Features

- **No Proprietary DRM**: Widevine, FairPlay, and PlayReady are strictly unsupported.
- **No External Web Fonts**: `@font-face` network downloads are bypassed; rendering uses system Inter sans fonts.
- **No Service Workers**: Offline service workers are not implemented.

### 10.10 Quick Reference: Web Platform Rules
- **MUST**: Use IndexedDB or Web Storage rather than expecting native filesystem access.
- **MUST NOT**: Rely on proprietary DRM systems for media streaming.

---

## Chapter 11: Performance Rules, Hardware Budgets, and Profiling

### 11.1 The 60 fps Budget and Frame Timing

```
Total Frame Budget: 16.66 ms (100%)
├── Game Logic & Physics:      ~4.0 ms (24%)
├── CPU Draw Setup & Batches:  ~3.0 ms (18%)
├── GPU Vertex & Fragment:     ~8.5 ms (51%)
└── Vsync Pacing & Overhead:   ~1.1 ms (7%)
```

### 11.2 Memory Allocation Constraints (Zero Allocations in Loop)

> [!CAUTION]
> **Allocation Rule**: NEVER instantiate tables, objects, or arrays inside `app.update(dt)` or `app.draw(w, h)`. Pre-allocate all scratch vectors and temporary buffers during `app.load()`. Repeated allocations trigger the garbage collector, resulting in periodic frame drops.

```lua
-- BAD PRACTICE: Creates temporary tables every frame
function app.draw(w, h)
  local pos = { x = 10, y = 20 } -- Allocates table!
  gfx.circle(pos.x, pos.y, 5)
end

-- GOOD PRACTICE: Pre-allocate scratch storage once
local scratch_pos = { x = 0, y = 0 }
function app.draw(w, h)
  scratch_pos.x = 10
  scratch_pos.y = 20
  gfx.circle(scratch_pos.x, scratch_pos.y, 5)
end
```

### 11.3 Memory Pressure and Resource Reclaim

- Script runtimes are capped at **64 MB** of script heap memory.
- Textures exceeding a 256 MB soft budget are automatically evicted if unused for 30 seconds.
- Native applications should track memory usage and respond to `NXN_ERR_NO_MEMORY`.

### 11.4 Power and Thermal Adaptation (`nxn_power_get`)

Applications should adjust quality based on power state:

```c
nxn_power p = NXN_STRUCT_INIT(nxn_power);
if (nxn_power_get(&p) == NXN_OK) {
    if (!p.charging && p.percent >= 0 && p.percent < 15) {
        // Battery under 15%: reduce rendering scale or drop framerate to 30 fps
        set_low_power_mode(1);
    }
}
```

In Lua:
```lua
local percent, charging = sys.battery()
if not charging and percent >= 0 and percent < 15 then
  g3d.shadows(false) -- Disable real-time shadows to conserve power
end
```

### 11.5 Profiling Realities: Emulators vs Console Hardware

> [!WARNING]
> **PROFILING REALITY**: Emulator execution speeds on desktop PCs do NOT reflect physical console hardware timings. Desktop CPUs possess significantly higher clock speeds and memory bandwidth. Always profile using console profiling tools or test directly on hardware before releasing.

### 11.6 Quick Reference: Performance Rules
- **MUST**: Maintain 60 fps (16.66 ms frame budget) without drops.
- **MUST NOT**: Allocate dynamic objects inside the active rendering loop.
- **MUST**: Adapt quality settings when low battery is detected.

---

## Chapter 12: Automated Testing with `nxvtest`

Automated testing is driven by the `SDK/Tools/nxvtest` runner. For comprehensive setup guidelines, refer to [AutomatedTesting.md](AutomatedTesting.md).

### 12.1 The `nxvtest` Architecture

`nxvtest` initialises an isolated virtual SD card environment, starts the system, dispatches simulated inputs (touch, controller, keyboard), captures screenshots, and asserts log output.

### 12.2 Scenario File Specification (`scenario.json`)

```json
{
  "name": "smoke-test-scenario",
  "time_limit": 60,
  "steps": [
    { "launch": "com.example.myapp" },
    { "wait": 3 },
    { "screenshot": "initial_screen" },
    { "wclick": [0.5, 0.5] },
    { "wait": 1 },
    { "pad": "a" },
    { "wait": 1 },
    { "screenshot": "after_interaction" },
    { "expect_log": "Button triggered successfully" },
    { "expect_screenshot": "initial_screen" },
    { "expect_screenshots_differ": ["initial_screen", "after_interaction"] },
    { "expect_no_crash": true },
    { "max_not_responding": 0 }
  ]
}
```

### 12.3 Running Test Suites and Inspecting Reports

```bash
cd SDK/Tools/nxvtest
python nxvtest.py run scenarios/smoke-test-scenario.json
python nxvtest.py report
```

### 12.4 Pre-Publishing Verification Checklist

- [ ] Clean execution without warnings or errors in `System/Logs/Apps/<id>.log`.
- [ ] Zero memory allocations inside frame update and draw loops.
- [ ] Responsive in both handheld (720p) and docked (1080p) display modes.
- [ ] Full navigation support with both Touch Screen and Gamepad.
- [ ] Recovers cleanly from sleep mode suspension (`suspend` -> `resume`).
- [ ] All user-facing strings are localised in `lang/en.json`.
- [ ] `nxvtest` scenario passes with zero "Not Responding" events.

### 12.5 Quick Reference: Testing Rules
- **MUST**: Include log assertion triggers in application startup routines.
- **MUST**: Ensure `nxvtest` runs report `max_not_responding: 0`.

---

## Chapter 13: Packaging, Publishing, and the App Market

### 13.1 Package Formats: `.nxvapp`, `.nxvmod`, and `.nxvlib`

- **`.nxvapp`**: Primary application and game distribution bundle.
- **`.nxvmod`**: Compiled AArch64 native dynamic module.
- **`.nxvlib`**: Reusable shared library installed to `Libraries/<id>/<major>/`.

Pack a bundle using the SDK tools:
```bash
python tools/nxvapp_pack.py MyApp.nxvapp
```

### 13.2 Store Catalog Metadata (`store.json`)

Bundles submitted to the public App Market require a companion `store.json`:

```json
{
  "kind": "game",
  "category": "games",
  "license": "GPL-3.0-or-later",
  "sourceUrl": "https://github.com/developer/dungeonrun",
  "providedBy": "Indie Games Studio",
  "subtitle": {
    "en": "Fast-paced dungeon action game",
    "tr": "Hızlı tempolu zindan aksiyon oyunu"
  }
}
```

### 13.3 Screenshots Standards (5 Shots, English UI)

- **Exact Count**: Exactly **5 screenshots** must be provided.
- **Language Requirement**: All store screenshots **MUST be captured with the system language set to English (`en`)**.
- **Resolution**: Native 1280×720 or 1920×1080 resolution showing real in-game or in-app scenes.

### 13.4 Icon Key-Art Requirements

- Dimensions: 128×128 or 256×256 pixels in PNG format with transparency.
- Content: Polished key-art visually representing the application. Flat single-colour gradient squares or bare text placeholders are rejected.

### 13.5 Licences, Attribution, and Port Packaging

- Third-party ports (emulators, engines, tools) must bundle their licence text (`LICENSE` or `COPYING`).
- Ports MUST NOT bundle copyrighted BIOS files, firmware binaries, or proprietary game assets.

### 13.6 The "Runtimes & Libraries" Store Category

Shared components (such as language engines or codecs) are published under the `runtimes` category (`"category": "runtimes"`, `"type": "lib"`).

### 13.7 Package Signing Model (Unsigned Store Decisions)

Community App Market packages are unsigned by design. Developers do not need code-signing certificates to publish to the App Market.

### 13.8 Safe Update Path and Data Migration

- Application updates must preserve existing user documents and settings.
- When altering file schemas, increment `"dataVersion"` in `app.json` so the OS automatically creates a backup of user data prior to applying the update.

### 13.9 Quick Reference: Store Publishing Rules
- **MUST**: Supply exactly 5 screenshots taken with the English UI.
- **MUST**: Include an icon representing the application (not a placeholder).
- **MUST NOT**: Include copyrighted BIOS, firmware, or proprietary game ROMs in packages.

---

## Chapter 14: Compatibility Promises and Version History

### 14.1 The Three Version Tiers

```
System Release Version (e.g. 1.2.4) ── SemVer: Major.Minor.Patch
         │
         ▼
SDK Surface Version (e.g. 1.13)     ── Major.Minor: Public API Contract
         │
         ▼
Native ABI Generation (e.g. 1.2)    ── Hand-bumped binary layout generation
```

### 14.2 The Additive Compatibility Contract

1. **Never Removed**: SDK functions and headers are never removed. Replaced functions are marked deprecated and continue functioning indefinitely.
2. **Behavioral Invariance**: Behaviour never changes under an older application. Behavioural adjustments are gated by `targetSdk`.
3. **ABI Freeze**: Native ABI v1 is frozen. Data structures and host import tables are strictly append-only.

### 14.3 Behaviour Gating via `targetSdk`

When system features must change behaviour, the host gates the change against `targetSdk`:

```cpp
// Internal host gating pattern:
if (sdkcompat::atLeast(app_desc, 1, 8)) {
    new_watchdog_policy();
} else {
    legacy_watchdog_policy();
}
```

Applications opting into newer behaviours simply raise `"targetSdk"` in `app.json`.

### 14.4 Reading the Version History: SDK 1.0 to 1.13

- **SDK 1.0**: Lua 5.4, `gfx`, `ui`, `fs`, `json`, `store`, `net`, `sys`, `audio`, `input`, `timer`, `TR`, `g3d` basics.
- **SDK 1.1**: JavaScript runtime (QuickJS-ng), Promises, GPU textures.
- **SDK 1.2**: `nexvyn.game` 2D engine, `sys.sdkVersion()`, `minSdk`, `permissions`.
- **SDK 1.3**: Python runtime (pocketpy).
- **SDK 1.4**: Permission enforcement, `sys.share`, scheduled notifications, `nxv://` links.
- **SDK 1.5**: TinyCC C runtime, Squirrel and Java runtimes.
- **SDK 1.6**: `fs.unzip`, `sys.games` query, Text-to-Speech (`sys.speak`), CPython (`"python3"`).
- **SDK 1.7**: Voxel worlds, pixelated texture filtering (`mesh:setTexture(path, true)`).
- **SDK 1.8**: Skeletal 3D models (`g3d.model`), `g3d.drawMatrix`, watchdog crash policy for `targetSdk >= 1.8`.
- **SDK 1.9**: NexGFX PBR renderer (`g3d.renderer("pbr")`), `net.request`, WebSockets, `net.oauth`, `gfx.imageUrl`, `media.*`, `ui.beginFeed`.
- **SDK 1.10**: Native C/C++ runtime (`.nxvmod`), Native SDK 1.0, soft texture budget manager.
- **SDK 1.11**: Kept folder picker (`ui.chooseFolder`), save game backup API (`fs.saveBackup/saveRestore`).
- **SDK 1.12**: UI design tokens (`ui.tokens()`), `audio.stopAll()`, controller action remapping.
- **SDK 1.13**: Manifest `"loadingHint": true` (120 s watchdog grace period for heavy native ports).

### 14.5 Reading the Native SDK Version History: 1.0 to 1.2

- **Native SDK 1.0**: Core `nxn_*` C interface: window display (GL), input, audio streams, filesystem, return codes.
- **Native SDK 1.1**: SDL2 windowed driver, extended input events, POSIX compatibility layer, save backups, UI tokens (`nxn_ui.h`), NexGFX native (`nexgfx_native.h`), OS mixer (`nxn_sfx_play`).
- **Native SDK 1.2**: Window control (`nxn_window_set_title/mode/modified`), battery and power state query (`nxn_power_get`, `NXN_EVENT_POWER`), OS modal dialogs (`nxn_dialog`, `nxn_prompt`), virtual keyboard request (`nxn_input_text_request`).

### 14.6 Quick Reference: Compatibility Rules
- **MUST**: Set `"minSdk"` to the oldest SDK version whose functions you invoke.
- **MUST**: Set `"targetSdk"` to the SDK version you tested against.

---

## Chapter 15: Common Mistakes and Solutions

### 15.1 Troubleshooting Matrix (Symptom -> Cause -> Fix)

| Symptom | Root Cause | Solution |
|---|---|---|
| **Clicks and touch points drift away from finger** | Coordinates were multiplied by display scale or aspect ratio | Do not re-scale! Window coordinates are **already in surface pixels**. Use `e.x` and `e.y` directly. |
| **Entire OS freezes when loading an asset** | Background thread held a lock required by the UI thread | Never hold a lock across file I/O or sleep that the main UI thread acquires during frame rendering. |
| **Periodic frame hitching every few seconds** | Allocating tables, strings, or objects every frame inside `update` or `draw` | Pre-allocate scratch tables, vectors, and buffers during `app.load()`. Zero allocations in loop. |
| **Corrupted save file after power-off** | Wrote directly to target file without an atomic swap | Write to a temporary file (`.tmp`), flush to disk, and atomically rename over target with `fs.rename`. |
| **Game rejected during store review** | Game used standard OS grey widgets and top menu bar | Develop a custom in-game art direction! Games must not use OS widgets as in-game menus. |
| **Game runs at 60 fps on PC, but drops to 20 fps on console** | Developer assumed emulator timings equal console timings | Profile using console profiling tools or test directly on hardware. |
| **Native module fails with bad struct size** | Passed uninitialised struct across native boundary | Always initialise native structs with `NXN_STRUCT_INIT(struct_type)`. |
| **Watchdog terminates app during startup** | Loaded large assets synchronously on main thread | Set `"loadingHint": true` in `app.json` and load assets asynchronously with worker threads. |

### 15.2 In-Depth Analysis of Critical Failure Modes

#### 1. The Double-Scaled Pointer Coordinate Trap
A developer creating an app on a 1080p display might observe `e.x = 640` and assume it needs scaling by `1920 / 1280 = 1.5`, computing `960`. In Nexvyn OS, the coordinate delivered to the window is already in local surface pixels. Multiplying by a scale factor causes touch points to drift further from the finger as the coordinate increases.

#### 2. Worker Thread Locking Inversion
A native module uses a mutex `g_data_lock` to guard game state. The background thread locks `g_data_lock` and begins reading a 50 MB asset file from the SD card. Meanwhile, the main UI thread tries to lock `g_data_lock` to draw a frame. Because the SD card is busy, the background thread blocks for 200 ms. The main thread blocks waiting for the lock, missing multiple frames and triggering the watchdog "Not Responding" dialog.

#### 3. Non-Atomic Save Writes
Calling `fs.write("save.dat", data)` opens the file and truncates it. If the console runs out of battery, the user powers off, or the application is killed while writing, `save.dat` is left with zero bytes. Writing to `save.dat.tmp` and renaming with `fs.rename` ensures that the old save remains intact until the new one is completely written.

---

## Chapter 16: Glossary

- **`.nxvapp`**: The standard application package bundle containing `app.json`, executable code, and assets.
- **`.nxvmod`**: An AArch64 shared object native binary loaded directly into the Nexvyn OS process space.
- **`.nxvlib`**: A shared native library installed to `Libraries/` providing reusable runtime dependencies.
- **App Guard**: The built-in security subsystem that inspects application packages at install time and protects system folders.
- **NexGFX**: The versioned rendering core behind `g3d.renderer("pbr")` and `ngfx_*`.
- **Surface Pixels**: The local coordinate space of an application's rendered content canvas with `(0, 0)` at the top-left.
- **`targetSdk`**: The manifest declaration locking application behaviour to a specific SDK version for compatibility.
- **`loadingHint`**: An `app.json` flag signaling long loading times, extending the watchdog timeout from 5 s to 120 s.
- **Watchdog**: The operating system supervisor that detects frozen main threads and prevents unyielding code from stalling the desktop.
- **Native SDK 1.2**: The C/C++ native development kit providing window control, power state queries, OS dialogs, and virtual keyboard integration.
