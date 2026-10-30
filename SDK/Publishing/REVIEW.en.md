# Review checklist

**English** · [Türkçe](REVIEW.tr.md)

What the maintainer checks before approving a pull request that adds or updates an item in `Store/`. Nothing is
merged (= published) until every line that applies is ticked. Submitters: run through it yourself first; the
[publishing guide](PUBLISHING.en.md) explains each point.

Verdicts: **approve and merge**, **request changes** (with the lines that failed), or **close** (with the reason, for
items the rules do not allow at all).

## 1. Automatic checks (CI)

- [ ] `python Tools/build_store.py --check` passes (after the maintainer's `build_store.py` run)
- [ ] `tools/catalog_check.py Store/catalog.json --strict` has no errors
- [ ] The language checker passes: `lua_check.py` · `js_check.mjs` · `py_check.py` · `rt_check.py`
- [ ] `nxv check <folder> --sdk <source checkout>` is clean
- [ ] The pull request touches only the item's folder (plus generated files when the submitter ran `build_store.py`)

## 2. Identity and versions

- [ ] `id` is unique, reverse domain, and unchanged for an update
- [ ] `version` is higher than the published one for an update; the README's versions table has the new line
- [ ] `minSdk` matches the newest SDK feature used
- [ ] The folder is in the right place: `Store/Apps/<category>/`, `Store/Games/<genre>/`, `Store/Themes/`, `Store/Fonts/`

## 3. Safety and privacy

- [ ] No malware, obfuscated code, or code downloaded at run time and executed (`load` of a fetched string ...)
- [ ] No tracking, analytics or data collection the user did not ask for; no personal data, API keys or passwords
      collected or uploaded; network use matches the description
- [ ] No ads that harm the experience (full-screen, deceptive, scams, gambling, adult)
- [ ] Every permission is used and explained in the pull request; nothing undeclared (build_store.py enforces it)
- [ ] C and Java: the README says why native code / Java is needed; no code that touches system files, other apps'
      data or the console's settings
- [ ] Network: a friendly message offline; no hard-coded secrets in the source

## 4. Rights and licensing

- [ ] The submitter owns the item or has a license that allows publishing it
- [ ] Every third-party part (code, images, sounds, music, fonts, data) is listed in the README with its author, source
      and license, YamaNX-style; the licenses allow redistribution
- [ ] No trademarks or names used in a way that suggests an official product
- [ ] Font packs: `LICENSE` present and redistributable (OFL, Apache 2.0 ...); `font.json` `license` matches

## 5. Content

- [ ] Suitable for everyone, or `"age": "teen"` in `store.json` for mild violence or scary themes; nothing adult-only,
      hateful, or encouraging illegal activity (including piracy)
- [ ] The description is honest: it does what it says, the screenshots are of this item
- [ ] Not a near copy of an existing item

## 6. Quality

- [ ] Installs and opens on the console or in Ryujinx; no crash in a few minutes of use
- [ ] Readable in light and dark mode; nothing overflows at the minimum window size, handheld and TV
- [ ] Usable by touch, cursor and (games) controller; targets of at least 28 px
- [ ] Smooth: nothing heavy in `app.draw`, no callback near 3 seconds
- [ ] Data is saved right away and survives `suspend` / `autosave`
- [ ] Every on-screen text goes through `TR()`; `lang/en.json` complete (Turkish strongly recommended)

## 7. Store listing

- [ ] `store.json`: `subtitle` (≤ 45 characters) and `description` at least in English; `kind`, `tags`; `shots` valid
- [ ] `icon.png` square 128 or 256 px; 3-4 screenshots without personal data
- [ ] `README.md` in English and Turkish
- [ ] An update has a `changelog` (What's New)

## 8. After merging

- [ ] `python Tools/build_store.py` run and committed (catalog, packages, listings, `dates.json` history)
- [ ] The item appears in the App Market (Discover > New) after a reload
- [ ] For a takedown: the folder is removed (or the previous version restored), the report issue is answered and closed
