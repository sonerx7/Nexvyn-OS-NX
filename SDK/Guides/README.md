# Guides

Every guide exists in English (`NAME.md`) and Turkish (`NAME.md`). The complete API is in the
[SDK reference](../Reference/SDK.md); if a function is not there, it does not exist.

## Start with SDK 1.9

| Guide | What it covers |
|---|---|
| [PBR game recipe](PBR_GAME_RECIPE.md) | A complete small 3D game step by step on the pbr renderer (materials, lights, shadows, bloom, instancing, a loaded model), in Lua and JavaScript, with Python and C versions |
| [Social app recipe](SOCIAL_APP_RECIPE.md) | A complete feed app step by step (network with an offline cache, web pictures, a virtualized feed, rich text, a clip player), in Lua and JavaScript, with Python and C versions |
| [AI-assisted workflow](AI_WORKFLOW.md) | From AI-generated code, models and textures to a console-ready game: context packs, scale, pivot, LOD, texture sizes, ORM and MetallicSmoothness maps, normal maps, glass and emission, reflections, rights |
| [SDK versions](SDK_VERSIONS.md) | What each SDK version from 1.0 to 1.12 added, which Nexvyn OS brought it, which languages get new APIs, how to set `minSdk` and `targetSdk` |
| [Make a game](MAKE_A_GAME.md) | The complete game recipe: project, 3D models (`.glb` / `.fbx`), loading, input, collision, speed on the console, the pbr renderer budget, art direction, store icon, publishing |
| [Make a social app](MAKE_A_SOCIAL_APP.md) | Feed, photo, short-video and chat apps: requests with cache and retry, uploads, WebSocket, sign-in, web pictures, video players, feeds and pagers |
| [Sound design](SOUND_DESIGN.md) | The sound kit: layered recipes, variants, buses, ducking, ambience, music loops, levels |
| [Input and play modes](INPUT_AND_PLAY_MODES.md) | Fitting into Nexvyn: touch, controller (Joy-Con pair or single), handheld and docked, window and full screen, sound, system navigation, performance, with a checklist |
| [Making themes](THEMES.md) | Theme packs (`.nxvtheme`): colors and accent, wallpapers, window chrome, dock or taskbar layout, icon set, sounds, the Store `audio` field, testing, publishing and the originality rules; with the template in `Samples/themes/template` and the checker `Tools/theme/themecheck.py` |
| [Graphics, UI and game feel](GAME_FEEL.md) | The feel kit: motion, impact, light, type, UI shapes, cameras, 3D moods and the store quality bar |

## Languages

| Guide | What it covers |
|---|---|
| [Automated testing](AutomatedTesting.md) | Run your app in an emulator by itself with `SDK/Tools/nxvtest`: scenarios with launch, clicks, keys, screenshots and log checks, a PASS / FAIL report and exit code for CI, troubleshooting, and what it cannot do |
| [Developer guide](DEVELOPER_GUIDE.md) | Studio and templates, `app.json`, choosing a language, 2D and 3D, packaging, testing |
| [Apps in JavaScript](JS_APPS.md) | Differences from Lua, Promises, limits, checking |
| [Apps in Python](PY_APPS.md) | The light runtime and CPython 3.12, interpreter limits, system library |
| [Apps in C](C_APPS.md) | C compiled on the console, `nexvyn.h`, memory and safety rules |
| [Apps in Squirrel](SQUIRREL_APPS.md) | Squirrel apps (frozen at SDK 1.8) |
| [Apps in Java](JAVA_APPS.md) | Java apps and building them on a PC (frozen at SDK 1.8) |
| [Lua capabilities](LUA_CAPABILITIES.md) | What can realistically be built in Lua, and where the limits are |
| [Language support](LANGUAGE_SUPPORT.md) | Why these runtimes, and the policy for new APIs |

## Formats, engine and system

| Guide | What it covers |
|---|---|
| [Package format](NXVAPP_FORMAT.md) | `.nxvapp`, `.nxvtheme`, `.nxvfont`: `app.json` fields, runtimes, permissions, `manifest.sha256`, signing |
| [Compatibility](COMPATIBILITY.md) | The compatibility contract: nothing removed, `targetSdk`-gated changes, frozen runtimes, release checks |
| [App Guard](APP_GUARD.md) | How packages are scanned before they are installed, and what makes an app *Review* or *Dangerous* |
| [Game engine](GAME_ENGINE.md) | The `nexvyn.game` 2D engine: scenes, sprites, maps, camera, physics, particles, tweens |
| [Game Engine projects](GAME_ENGINE_PROJECTS.md) | The Game Engine app: games with little or no code, Quick Game, the project format |
| [Native SDK guide](NATIVE_GUIDE.md) | C / C++ apps inside Nexvyn OS: install, new, build, package, crash reports (Native SDK 1.1) |
| [Native SDK kit](NATIVE_KIT.md) | Every `nxv-native` command, header and CMake function of the kit |
| [Native compatibility layer](NATIVE_COMPAT.md) | The POSIX / libc layer that lets ports run unchanged, and its limits |
| [Native modules](NATIVE_MODULES.md) | How the optional built-in apps are installed from the App Market (internal mechanism, not an SDK) |
| [Built-in apps in C++](APP_GUIDE.md) | How the system's own apps are written |

## For users

| Guide | What it covers |
|---|---|
| [User guide](USER_GUIDE.md) | Setup, desktop, shortcuts, apps, the App Market, Connect to PC |
| [Forwarder](FORWARDER.md) | An icon on the HOME menu that opens Nexvyn OS |
| [Browser](BROWSER.md) | The built-in browser and the full browser |
| [Turkish patches](TURKISH_PATCHES.md) | The Turkish Patches app |

Where to start: the [SDK start page](../README.md), then the [quick start of your language](../Languages/README.md),
then the [PBR game recipe](PBR_GAME_RECIPE.md) or the [social app recipe](SOCIAL_APP_RECIPE.md).
