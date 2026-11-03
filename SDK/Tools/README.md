# PC tools

**English** · [Türkçe](README.tr.md)

Tools for people who make Nexvyn OS apps and games on a PC. Each is plain Python 3.8+.

| Tool | What it does | Needs |
|---|---|---|
| [`nxv`](nxv/README.md) | The command line for app makers: `new` (a project from `SDK/Languages/<lang>/template`, `--store` for the App Market layout), `check` (manifest, files, icon, translations, used but undeclared permissions, `store.json` and its `shots` script; with `--sdk` the language checker too), `build` (Java `src/` to `app.jar`), `pack` (the same `.nxvapp` as the App Market build, `--sign` to sign), `install` (copy into an SD card folder), `push --host <ip>` (upload to the console's **Connect to PC** FTP server) | nothing but Python |
| [`icon/`](icon/README.md) | Key-art store icons from your game's own model: `hero_render.py` renders the model with key and rim lights on a transparent background, `finish_icon.py` builds the background, glow, rim, vignette and every size with a 256 / 128 / 64 px preview. Styles `clean` (default), `bold`, `loud`; a title only when asked for | Pillow; `hero_render.py` runs in a free, open-source 3D suite from the command line (see its README) |
| [`textures/`](textures/README.md) | PBR texture sets for the pbr renderer (SDK 1.9): `check` (sets, sizes, missing maps), `resize` (scale maps down, originals kept), `orm` (pack glTF ORM), `smoothness` (MetallicSmoothness to roughness and metallic), `flipgreen` (-Y to +Y normal maps: green down to green up) | Pillow |

Typical loop: `nxv new lua "My Game"` → write the code → `nxv check` → `nxv push` → try it on the console → make the
icon with `icon/` → `nxv check` again before you open the pull request ([Contributing](../../CONTRIBUTING.md)).
