# Building Nexvyn OS Apps & Games with AI (SDK 2.0 / 1.13)

This folder provides complete, zero-hallucination context packs, architectural rules, language packs and task prompts
for AI coding agents (Cursor, Windsurf, Claude Code, GitHub Copilot, Antigravity, ChatGPT, Claude, Gemini, and local
LLMs).

Without these files, AI assistants guess browser, Node.js, LÖVE or standard OS APIs that do not exist on Nexvyn OS.
With these files, an AI assistant can generate complete, 60 fps apps and games across all **4 Official Primary
Runtimes** (**Lua 5.4.7**, **JavaScript ES2023**, **CPython 3.12**, and **Native C/C++ ABI v1**) using the **NXUI
Retained UI Engine (`nxui.*` / `nxn_nxui_*`)** and **NexGFX PBR 3D Renderer (`g3d.*`)**.

## Context Files

| File | Purpose |
|---|---|
| **[llms.txt](llms.txt)** | **Master AI Index & Quick Contract:** Single-file architecture map, runtime selection matrix, `nxui.*` & `g3d.*` cheat sheet, and verification commands for LLM agents. |
| **[system-prompt.md](system-prompt.md)** | **Full SDK 2.0 / 1.13 System Prompt (~8k tokens):** Bundle layout, `app.json`, enforced permissions, lifecycle callbacks, hard limits (3 s / 10 s, 64 MB, 60 fps, `TR()`), `gfx`, `ui`, **`nxui` (Retained UI)**, `g3d` (NexGFX PBR & skeletal models), `nexvyn.game`, `sfx` & `juice` kits, `fs`, `store`, `net`, `sys`, `audio`, and store publishing format. |
| **[AI_RULES.md](AI_RULES.md)** | **Strict Engineering Rules:** MUST / MUST NOT rules, runtime decision tree, Native C/C++ ABI v1 & Dear ImGui rules, and the build-package-test loop. |
| **[GEMINI_WORKFLOW.md](GEMINI_WORKFLOW.md)** | **End-to-End Gemini & AI Agent Guide:** Exact `1.13` / Native `1.2` manifest rules, porting & multi-touch input (`nxn_port_input.h`), UI/swkbd freeze prevention, and full verification commands. |
| **[checklist.md](checklist.md)** | **Pre-Answer Verification Checklist:** Every item the AI must verify before delivering code. |
| **[languages/](languages/)** | Per-language packs: [lua.md](languages/lua.md) (Lua 5.4.7), [javascript.md](languages/javascript.md) (QuickJS-ng ES2023), [python.md](languages/python.md) (CPython 3.12 & PocketPy), [native.md](languages/native.md) (Native C/C++ `.nxvmod` ABI v1), [c.md](languages/c.md) (TinyCC C), [squirrel.md](languages/squirrel.md), [java.md](languages/java.md). |
| **[tasks/](tasks/)** | Ready-to-fill task prompts: [3D PBR game](tasks/make-3d-game.md), [2D game](tasks/make-game.md), [social/feed/media app](tasks/make-social-app.md), [utility app](tasks/make-utility.md), [store key-art icon](tasks/store-icon.md), [theme pack](tasks/make-theme.md), [port Lua to JS](tasks/port-lua-to-js.md), [add UI language](tasks/add-language.md), [store listing](tasks/store-listing.md), [fix checker failure](tasks/fix-lua-check.md), [test on emulator](tasks/test-on-emulator.md). |

## How to Use with Any AI Assistant

1. **Attach Context:**
   - **IDE Agents (Cursor, Windsurf, Claude Code, Antigravity):** Point the agent at `SDK/AI/llms.txt`, `SDK/AI/system-prompt.md`, and `SDK/AI/languages/<lang>.md` (plus `SDK/Reference/SDK.md` for deep lookups).
   - **Chat Assistants (ChatGPT, Claude, Gemini):** Upload `SDK/AI/system-prompt.md` and the chosen language pack from `SDK/AI/languages/`.
2. **Pick one of the 4 Official Runtimes:**
   - **Lua 5.4.7 (`"runtime": "lua"`):** Best for utilities, system tools, 2D games (`nexvyn.game`), and 3D PBR apps.
   - **JavaScript ES2023 (`"runtime": "js"`):** Best for network/REST/WebSocket apps, social feeds, and voxel games (`g3d.voxels`).
   - **Python 3.12 (`"runtime": "python3"` or `"targetSdk": "2.0"`):** Best for data processing, scientific tools, and standard-library heavy apps.
   - **Native C/C++ (`"runtime": "native"`):** Best for high-performance 2D/3D engines, SDL2/OpenGL ports, and emulators (`.nxvmod`).
3. **Scaffold & Check:**
   - Scaffold: `python SDK/Tools/nxv/nxv.py create "My App" --profile utility --runtime lua`
   - Validate: `python SDK/Tools/nxv/nxv.py check <bundle_folder>`
   - Pack: `python SDK/Tools/nxv/nxv.py pack <bundle_folder>`
