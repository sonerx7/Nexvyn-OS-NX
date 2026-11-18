# SDK recipes

Start with the smallest runtime that fits the workload. Commands use `<repo>` for the repository root, `<kit>` for `SDK/Languages/c/native-kit`, and `<project>` for an absolute source-project path. Run each native command from `<kit>`.

| Type | Recipe | Golden | Default choice / RAM target |
|---|---|---|---|
| 2D game | [2d-game](2d-game.md) | [game-2d](../golden/game-2d/) | Lua override; game profile 128 MB |
| 3D game | [3d-game](3d-game.md) | [native-game3d](../../Samples/c/golden/native-game3d/) | Native; 128 MB |
| Emulator port | [emulator-port](emulator-port.md) | [native-emu](../../Samples/c/golden/native-emu/) | Native interpreter; 256 MB |
| Port | [port](port.md) | [native-port](../../Samples/c/golden/native-port/) | Native stand-in; 192 MB |
| Productivity app | [productivity-app](productivity-app.md) | [native-app](../../Samples/c/golden/native-app/) | Lua 24 MB normally; native for native work |
| Tool | [tool](tool.md) | [native-tool](../../Samples/c/golden/native-tool/) | Lua 24 MB normally; native for C library integration |
| Script app | [script-app](script-app.md) | [script-utility](../golden/script-utility/), [script-network](../golden/script-network/) | Lua 24 MB / JavaScript 32 MB |

All targets are 60 fps. Budgets are proposed device targets, not measurements or RAM guarantees. Data/Python is 48 MB; calculator/Lua is 16 MB. New apps require complete en, tr, de, es, fr, ja, ko and zh locale tables. Golden icons are generated template placeholders and need product artwork before Store publication.

Read [RESULTS.md](../golden/RESULTS.md) for the commands run, the results and the scope limits. Each recipe includes lifecycle, resize Busy, input-state and docked/handheld checks; compilation alone does not complete those interactive checks.
