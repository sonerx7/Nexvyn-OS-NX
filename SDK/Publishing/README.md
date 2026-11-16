# Publishing

New app, game, port and launcher submissions require complete eight-language UI: en, tr, de,
es, fr, ja, ko, zh. Run `python SDK/Tools/nxv/nxv_i18n.py --check <bundle>` and the SDK's
`nxv.py check` before submission. All user-facing text, including launcher/settings/errors,
needs translation. Review translation quality and actual CJK layout; matching keys alone is
not enough. English UI store screenshots are accepted; eight screenshot sets are unnecessary.
Follow `../Guides/PRODUCT_QUALITY.md`, `INPUT_CONTRACT.md`, `LOCALIZATION_CONTRACT.md` and
`PORT_AND_LAUNCHER.md`. SDK Markdown is English only.


How an app, game, theme or font gets into the Nexvyn OS App Market: a pull request to this repository that the
maintainer reviews and approves.

| Document | For |
|---|---|
| [PUBLISHING.md](PUBLISHING.md) | Developers: the flow (fork → `Store/...` → checks → pull request → review → merge), folder layout, `app.json`, permissions, `store.json`, screenshots, content rules, updates, reports and takedowns, signing |
| [REVIEW.md](REVIEW.md) | The checklist the maintainer uses to approve; run through it before you open the pull request |
| [Pull request template](../../.github/PULL_REQUEST_TEMPLATE.md) | Filled in automatically when you open a pull request |
| [Report an app](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=report-app.yml) | Users: something in the store breaks the rules |
| [Questions](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=submission-question.yml) | Developers: ask before or while submitting |
