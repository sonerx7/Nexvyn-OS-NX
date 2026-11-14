# Contributing

This repository holds the App Market (`Store/`), the SDK (`SDK/`) and the release files of Nexvyn OS. The source code
of Nexvyn OS itself is not here. You can contribute in four ways: publish an app, report a bug, translate, or improve
the SDK and its documentation. English or Turkish is fine everywhere.

## 1. Publish an app, game, theme or font

Every submission is a pull request and is reviewed by the maintainer before it appears in the App Market
([CODEOWNERS](.github/CODEOWNERS)).

1. **Make it** with the [SDK](SDK/README.md), on your computer or in Nexvyn OS Studio on the console. Apps are written
   in English; add `lang/<code>.json` files for more languages (Turkish is not required).
2. **Fork** this repository and add your item in its own folder:
   `Store/Apps/<category>/<slug>/`, `Store/Games/<genre>/<slug>/`, `Store/Themes/<slug>/` or `Store/Fonts/<slug>/`,
   with `source/` (the bundle), `README.md`, `store.json` and, if you have them, `screenshots/`. The layout and every
   field are in the [publishing guide](SDK/Publishing/PUBLISHING.md).
3. **Check it:** `python SDK/Tools/nxv/nxv.py check Store/<...>/<slug>/source` must pass. Try it on a console (or in
   an emulator), in light and dark mode, handheld and on a TV, with touch and a controller.
4. **Store page:** a 256x256 key-art icon that shows your game or app ([icon tool](SDK/Tools/icon/README.md)),
   five screenshots with the interface in English (or a `shots` script, and the maintainer makes them), an English
   `subtitle` and `description` in `store.json`.
5. **Open the pull request** with the template. Only change files of your own item.
6. The maintainer reviews it with the [review checklist](SDK/Publishing/REVIEW.md), builds the package and the
   catalog, and merges it. It then appears in the App Market as New.

Updates of your item work the same way: raise `version` in `app.json` and say what changed in the pull request.

**Not accepted:** malware, tracking or hidden data collection, ads that harm users, content for adults only, other
people's work without the right to publish it, apps that impersonate other products or brands, API keys or passwords
in the code. The [publishing guide](SDK/Publishing/PUBLISHING.md) has the full content rules.

Questions before you submit: [submission question form](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=submission-question.yml).
If you cannot open a pull request yourself, use the
[app submission form](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=app-submission.yml).

## 2. Report a bug

Use the [bug report form](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=bug-report.yml). It asks for
the Nexvyn OS, system and Atmosphère versions, the launch mode, steps to reproduce and, when something froze or
crashed, the log file `sdmc:/NexvynOS/System/Logs/system.log` (and `system.prev.log` after a restart). Remove personal
data from logs first.

- A problem in an App Market item: **Report This App** on its store page, or the
  [report form](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=report-app.yml).
- A mistake in the SDK or the documentation: the
  [SDK and docs form](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=sdk-docs-bug.yml).
- A security problem: never as an issue; follow the [security policy](SECURITY.md).

## 3. Translate

Nexvyn OS is available in 8 languages. To fix a translation or offer a new language, use the
[translation form](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=translation.yml).

## 4. Improve the SDK and documentation

Pull requests that fix samples, guides or the SDK tools under `SDK/` are welcome. Keep both language versions
(`NAME.md` and `NAME.md`) in step, or say in the pull request which one needs a translation. Code examples must
use only functions from the [SDK reference](SDK/Reference/SDK.md). The guides and the reference are generated from
the Nexvyn OS source; the maintainer carries accepted changes over there.

## Conduct

Be respectful and stay on topic. Harassment, discrimination and personal attacks are not tolerated in issues, pull
requests or store content. The maintainer may close, edit or remove contributions that break this.
