# Guides

**English** · [Türkçe](README.tr.md)

The user and developer guides of Nexvyn OS. Most are in Turkish; the table says which ones are in English or have an
English summary. The complete API reference is always [SDK/Reference/SDK.en.md](../Reference/SDK.en.md), which is in English.

| File | Topic | Language |
|---|---|---|
| [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.en.md) | The main developer guide: Studio and templates, `app.json`, choosing a language, 2D games, 3D, packaging, the community catalog, Overlay, testing in Ryujinx (`autorun.txt`), built-in C++ apps | TR, English summary |
| [NXVAPP_FORMAT.md](NXVAPP_FORMAT.en.md) | The `.nxvapp` v2 package format: `app.json` fields, runtimes, permissions, `manifest.sha256`, signing (`manifest.sig`), installing, the catalog format, packing | TR, English summary |
| [JS_APPS.md](JS_APPS.en.md) | JavaScript apps: differences from Lua, Promises, limits, checking | TR |
| [PY_APPS.md](PY_APPS.en.md) | Python (pocketpy) apps: differences, interpreter limits, system library | TR |
| [SQUIRREL_APPS.md](SQUIRREL_APPS.en.md) | Squirrel apps | TR |
| [C_APPS.md](C_APPS.en.md) | C apps compiled on the console by TinyCC | TR |
| [JAVA_APPS.md](JAVA_APPS.en.md) | Java apps on miniJVM and building them on a PC | TR |
| [LANGUAGE_SUPPORT.md](LANGUAGE_SUPPORT.en.md) | Research and decisions for new languages: why Squirrel, TinyCC and miniJVM, why not CPython | TR |
| [LUA_CAPABILITIES.md](LUA_CAPABILITIES.en.md) | What can realistically be built with Lua, and where the limits are | TR |
| [GAME_ENGINE.md](GAME_ENGINE.en.md) | Tutorial for the `nexvyn.game` 2D engine: scenes, sprites, maps, camera, physics, particles, tweens | TR |
| [GAME_ENGINE_PROJECTS.md](GAME_ENGINE_PROJECTS.en.md) | The Game Engine app (formerly Game Workshop): making 2D and 3D games with little or no code, the project format | TR |
| [APP_GUIDE.md](APP_GUIDE.en.md) | Writing a built-in C++ app (contributing to the Nexvyn OS source) | EN |
| [USER_GUIDE.md](USER_GUIDE.en.md) | User guide: setup, desktop, shortcuts, apps, the Store, Connect to PC (FTP) | TR |
| [FORWARDER.md](FORWARDER.en.md) | The forwarder that opens Nexvyn OS from the HOME menu | TR + EN |
| [BROWSER.md](BROWSER.en.md) | The browser: engine research and the chosen approach | TR |
| [TURKISH_PATCHES.md](TURKISH_PATCHES.en.md) | Research and design of the Turkish Patches app | TR |
| [NATIVE_MODULES.md](NATIVE_MODULES.en.md) | Native modules (`.nxvmod`): how the optional C++ apps of Nexvyn OS are installed from the App Market (internal mechanism, not an SDK) | TR |

Where to start: [../README.md](../README.md) (the SDK folder start page), then the [Languages](../Languages/README.md)
guide of your language, then the language file above and [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.en.md). The
English-only reader gets everything needed from [SDK/Reference/SDK.en.md](../Reference/SDK.en.md) and the per-language quick starts.
