# theme

`themecheck.py` checks a theme pack folder and packs it into a `.nxvtheme`. Plain Python 3.8+, no packages.

    python SDK/Tools/theme/themecheck.py MyTheme            # format, limits, contrast
    python SDK/Tools/theme/themecheck.py MyTheme --pack     # also writes MyTheme.nxvtheme

It checks `theme.json` (id, appearance, accent, the files it names, settings values, palette names), the pack limits
(160 files, 32 MB, 12 MB per file, allowed extensions) and the WCAG AA contrast of the palette pairs you set (text on
window, content and sidebar, menu text, selection text). Errors stop the pack; warnings are advice. See
[Making themes](../../Guides/THEMES.md).
