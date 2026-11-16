# Eight-language application and game contract

All newly developed applications, games, ports and launchers must support these eight locales:

| Code | Language |
|---|---|
| `en` | English |
| `tr` | Turkish |
| `de` | German |
| `es` | Spanish |
| `fr` | French |
| `ja` | Japanese |
| `ko` | Korean |
| `zh` | Chinese |

All SDK Markdown is English, with a single `NAME.md`. Do not add `.tr.md`, `.en.md` duplicates
or bilingual documentation. This does not remove translations from product interfaces.

## Files and coverage

Ship `lang/<code>.json` for every code. Put every user-facing app string behind the supported
translation API (`TR` for scripts, `nxn_tr`/`nxn_tr_format` for native). Preserve the same keys and
format tokens in all eight files. Native nested JSON objects and flat dotted keys are supported;
do not define the same flattened key twice. Strings must be non-empty; duplicate JSON keys are errors.

Coverage includes title/description, launch/content-selection screens, settings, input-mode labels,
touch controls, menus, pause/help, save dialogs, progress, offline/error messages and recovery.
Never concatenate an English sentence around a translated noun. Keep names/identifiers invariant
when appropriate, but do not copy English prose into seven dictionaries as a completion claim.

For a source port, its launcher and system-facing UI need all eight locales. Audit the engine's
menus, HUD, subtitles and other user-visible strings too; a translated launcher alone does not
make an untranslated game compliant. Use distributable text resources and appropriate font
fallbacks; do not modify or bundle user-owned content without the required rights.

## Check from the downloaded SDK

```text
python SDK/Tools/nxv/nxv_i18n.py --check MyApp
python SDK/Tools/nxv/nxv.py check MyApp
python SDK/Tools/nxv/nxv.py pack MyApp -o MyApp.nxvapp
```

The public authoring check/packer requires all eight complete dictionaries for app/game bundles.
Native-kit projects can run `python tools/nxv_i18n.py --check projects/myapp` before packaging.
This authoring rule does not prevent older installed packages from opening or change their ABI.
Libraries without a user interface are not required to invent eight UI dictionaries.

The locale validator checks keys, non-empty strings, duplicate/colliding keys and placeholder
identities/counts. It accepts reordering while preserving tokens. It cannot prove linguistic
accuracy, grammatical context, font rendering, accessibility or complete extraction of hard-coded
labels. Those require review in the actual application. Extra engines' format conventions need
their own resource validator in addition to the common dictionary check.

## Layout and text acceptance

Test long German/French labels, Turkish case-sensitive names and real Japanese/Korean/Chinese
text. Keep placeholders intact. Use UTF-8 throughout. Avoid fixed-width button assumptions;
wrap/ellipsis where appropriate and keep the full value accessible. Inspect text entry and
cursor/selection, not only static glyphs. Test enlarged text and narrow windows without hiding
required controls. Pseudo-localization helps find overflow but is not a replacement for translation.

Store UI screenshots may be English; eight screenshot sets are not required. Capture the actual
product with readable text and useful scenes. Store metadata should describe the actual locale
coverage; complete the eight language maps for new item titles, subtitles and descriptions.
