# Guides

**English** · [Türkçe](README.tr.md)

Every guide exists in English (`NAME.en.md`) and Turkish (`NAME.tr.md`). The complete API is in the
[SDK reference](../Reference/SDK.en.md); if a function is not there, it does not exist.

## Start with SDK 1.9

| Guide | What it covers |
|---|---|
| [Recipes](RECIPES.en.md) | Two complete apps step by step, in Lua and JavaScript with Python and C notes: a PBR 3D game (renderer, materials, lights, shadows, bloom, instancing) and a social photo feed (network, web pictures, virtualized feed, rich text) |
| [AI-assisted workflow](AI_WORKFLOW.en.md) | From AI-generated code, models and textures to a console-ready game: context packs, scale, pivot, LOD, texture sizes, ORM and MetallicSmoothness maps, normal maps, glass and emission, reflections, rights |
| [SDK versions](SDK_VERSIONS.en.md) | What each SDK version from 1.0 to 1.9 added, which Nexvyn OS brought it, which languages get new APIs, how to set `minSdk` and `targetSdk` |
| [Make a game](MAKE_A_GAME.en.md) | The complete game recipe: project, 3D models (`.glb` / `.fbx`), loading, input, collision, speed on the console, the pbr renderer budget, art direction, store icon, publishing |
| [Make a social app](MAKE_A_SOCIAL_APP.en.md) | Feed, photo, short-video and chat apps: requests with cache and retry, uploads, WebSocket, sign-in, web pictures, video players, feeds and pagers |
| [Sound design](SOUND_DESIGN.en.md) | The sound kit: layered recipes, variants, buses, ducking, ambience, music loops, levels |
| [Graphics, UI and game feel](GAME_FEEL.en.md) | The feel kit: motion, impact, light, type, UI shapes, cameras, 3D moods and the store quality bar |

## Languages

| Guide | What it covers |
|---|---|
| [Developer guide](DEVELOPER_GUIDE.en.md) | Studio and templates, `app.json`, choosing a language, 2D and 3D, packaging, testing |
| [Apps in JavaScript](JS_APPS.en.md) | Differences from Lua, Promises, limits, checking |
| [Apps in Python](PY_APPS.en.md) | The light runtime and CPython 3.12, interpreter limits, system library |
| [Apps in C](C_APPS.en.md) | C compiled on the console, `nexvyn.h`, memory and safety rules |
| [Apps in Squirrel](SQUIRREL_APPS.en.md) | Squirrel apps (frozen at SDK 1.8) |
| [Apps in Java](JAVA_APPS.en.md) | Java apps and building them on a PC (frozen at SDK 1.8) |
| [Lua capabilities](LUA_CAPABILITIES.en.md) | What can realistically be built in Lua, and where the limits are |
| [Language support](LANGUAGE_SUPPORT.en.md) | Why these runtimes, and the policy for new APIs |

## Formats, engine and system

| Guide | What it covers |
|---|---|
| [Package format](NXVAPP_FORMAT.en.md) | `.nxvapp`, `.nxvtheme`, `.nxvfont`: `app.json` fields, runtimes, permissions, `manifest.sha256`, signing |
| [Compatibility](COMPATIBILITY.en.md) | The compatibility contract: nothing removed, `targetSdk`-gated changes, frozen runtimes, release checks |
| [App Guard](APP_GUARD.en.md) | How packages are scanned before they are installed, and what makes an app *Review* or *Dangerous* |
| [Game engine](GAME_ENGINE.en.md) | The `nexvyn.game` 2D engine: scenes, sprites, maps, camera, physics, particles, tweens |
| [Game Engine projects](GAME_ENGINE_PROJECTS.en.md) | The Game Engine app: games with little or no code, Quick Game, the project format |
| [Native modules](NATIVE_MODULES.en.md) | How the optional built-in apps are installed from the App Market (internal mechanism, not an SDK) |
| [Built-in apps in C++](APP_GUIDE.en.md) | How the system's own apps are written |

## For users

| Guide | What it covers |
|---|---|
| [User guide](USER_GUIDE.en.md) | Setup, desktop, shortcuts, apps, the App Market, Connect to PC |
| [Forwarder](FORWARDER.en.md) | An icon on the HOME menu that opens Nexvyn OS |
| [Browser](BROWSER.en.md) | The built-in browser and the full browser |
| [Turkish patches](TURKISH_PATCHES.en.md) | The Turkish Patches app |

Where to start: the [SDK start page](../README.md), then the [quick start of your language](../Languages/README.md),
then the [Recipes](RECIPES.en.md).
