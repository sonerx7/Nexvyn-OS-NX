# Repository tools

**English** · [Türkçe](README.tr.md)

Maintenance of this repository: building and checking the App Market catalog. Tools for app makers (the `nxv` command
line) are in [SDK/Tools](../SDK/Tools/README.md).

| Path | What it does |
|---|---|
| [`build_store.py`](build_store.py) | Packs every item in `Store/` (`.nxvapp`, `.nxvtheme`, `.nxvfont`; deterministic, with `manifest.sha256`) and every sample in `SDK/Samples/` (`.zip`), writes `Store/catalog.json`, `SDK/samples.json`, `Store/dates.json` (first release, last change and version history per id) and the listings (`Store/README.md` and one README per category folder). It refuses items with a bad id, a missing icon or license, or code that uses a permission `app.json` does not declare. `--check` changes nothing and exits 1 when something is out of date (CI). |
| [`ci/store.yml`](ci/store.yml) | The GitHub Actions workflow for pull requests: `build_store.py --check`, then the source repository's `catalog_check.py` and language checkers on the changed items. |

## Where things are

| Path | Contents | Made by |
|---|---|---|
| `Store/Apps/<category>/<slug>/`, `Store/Games/<genre>/<slug>/` | apps and games: `source/`, `store.json`, `README.md`, `screenshots/` | developers (pull requests) |
| the same, with `app.json` and no `source/` | store pages of the apps that ship with Nexvyn OS | the Nexvyn OS project |
| `Store/Themes/<slug>/`, `Store/Fonts/<slug>/` | themes, font packs | developers; `Store/Themes/tools/gen_themes.py` for the official themes |
| `Store/catalog.json`, `*.nxvapp`, `*.nxvtheme`, `*.nxvfont`, listings | what the console downloads | `build_store.py` |
| `Store/packages.json` | the homebrew package catalog | `tools/release.py` of the source repository |
| `SDK/Reference/`, `SDK/Guides/`, `SDK/Fonts/` | the SDK reference, guides and system fonts | `tools/release.py` (copied from the source repository) |
| `SDK/Languages/`, `SDK/Samples/`, `SDK/AI/`, `SDK/Publishing/` | templates, samples, prompts, the publishing guide | edited here |
| `CHANGELOG.md`, `LICENSE`, `THIRD_PARTY_NOTICES.md` | release notes and licenses | `tools/release.py` |

The documentation website is built from the source repository (`site/`), not from here.

## Enabling the checks on GitHub

1. Copy `Tools/ci/store.yml` to `.github/workflows/store.yml` in the GitHub web UI (**Add file > Create new file**,
   paste the content). Pushing workflow files from a clone needs a token with the `workflow` scope.
2. Optional, while the source repository is private: create a fine-grained read-only token for
   `sonerx7/Nexvyn-OS-NX-Source` and add it as the repository secret `SOURCE_REPO_TOKEN`, so the language checkers run.
3. **Settings > Branches > Add rule** for `main`: require a pull request, **Require review from Code Owners**
   (`.github/CODEOWNERS`) and the `store` status check. Then nothing reaches `Store/` or `SDK/` without approval.
