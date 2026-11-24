# Repository tools

Maintenance of this repository: building and checking the App Market catalog. Tools for app makers (the `nxv` command
line) are in [SDK/Tools](../SDK/Tools/README.md).

| Path | What it does |
|---|---|
| [`build_store.py`](build_store.py) | Packs every item in `Store/` (`.nxvapp`, `.nxvtheme`, `.nxvfont`; deterministic, with `manifest.sha256`) and every sample in `SDK/Samples/` (`.zip`), writes `Store/catalog.json`, `SDK/samples.json`, `Store/dates.json` (first release, last change and version history per id) and the listings (`Store/README.md` and one README per category folder). It refuses items with a bad id, a missing icon or license, or code that uses a permission `app.json` does not declare. `--check` changes nothing and exits 1 when something is out of date (CI). |

## Where things are

| Path | Contents | Made by |
|---|---|---|
| `Store/Apps/<category>/<slug>/`, `Store/Games/<genre>/<slug>/`, `Store/Ports/<genre>/<slug>/`, `Store/Emulators/<subcat>/<slug>/` | apps, games, ports and emulators: `source/`, `store.json`, `README.md`, `screenshots/` | developers (pull requests) |
| the same, with `app.json` and no `source/` | store pages of the apps that ship with Nexvyn OS | the Nexvyn OS project |
| `Store/Themes/<slug>/`, `Store/Fonts/<slug>/` | themes, font packs | developers; `Store/Themes/tools/gen_themes.py` for the official themes |
| `Store/catalog.json`, `*.nxvapp`, `*.nxvtheme`, `*.nxvfont`, listings | what the console downloads | `build_store.py` |
| `Store/packages.json` | the homebrew package catalog | the Nexvyn OS release process |
| `SDK/Reference/`, `SDK/Guides/`, `SDK/Fonts/` | the SDK reference, guides and system fonts | the Nexvyn OS release process |
| `SDK/Languages/`, `SDK/Samples/`, `SDK/AI/`, `SDK/Publishing/` | templates, samples, prompts, the publishing guide | edited here |
| `CHANGELOG.md`, `LICENSE`, `THIRD_PARTY_NOTICES.md` | release notes and licenses | the Nexvyn OS release process |

The documentation website is built from the Nexvyn OS project, not from here.

## Review rule

**Settings > Branches > Add rule** for `main`: require a pull request and **Require review from Code Owners**
(`.github/CODEOWNERS`). Then nothing reaches `Store/` or `SDK/` without approval.
