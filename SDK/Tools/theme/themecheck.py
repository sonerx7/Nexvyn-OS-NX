#!/usr/bin/env python3
"""Checks a Nexvyn OS theme pack folder and packs it into a .nxvtheme.

  python themecheck.py MyTheme            check: format, limits, contrast
  python themecheck.py MyTheme --pack     check, then write MyTheme.nxvtheme next to the folder

Plain Python 3.8+, standard library only. Exit code 1 when there is an error.
"""
import json
import os
import re
import sys
import zipfile

EXT = {".json", ".jpg", ".jpeg", ".png", ".webp", ".wav", ".md", ".txt"}
MAX_FILES, MAX_TOTAL, MAX_FILE = 160, 32 * 1024 * 1024, 12 * 1024 * 1024
PALETTE = set("windowBg titlebar titlebarInactive contentBg sidebarBg text text2 text3 controlBg controlBorder "
              "controlHover fieldBg fieldBorder selection selectionText menuBg menuText panelTint menubarTint "
              "menubarText separator accentText".split())
CHROME = {"default", "bevel", "flat", "glass", "mono"}
LAYOUT = {"dock", "taskbar"}
SIZES = {"small", "medium", "large"}
# (foreground, background, minimum ratio): WCAG AA, 4.5:1 for text
PAIRS = [("text", "windowBg", 4.5), ("text", "contentBg", 4.5), ("text", "sidebarBg", 4.5), ("menuText", "menuBg", 4.5),
         ("selectionText", "selection", 4.5), ("menubarText", "menubarTint", 4.5)]


def lum(hexrgb):
    def ch(v):
        v /= 255.0
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (int(hexrgb[i:i + 2], 16) for i in (0, 2, 4))
    return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)


def ratio(a, b):
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def files_of(folder):
    out = []
    for root, _, names in os.walk(folder):
        for n in names:
            if not n.startswith("."):
                out.append(os.path.relpath(os.path.join(root, n), folder).replace(os.sep, "/"))
    return sorted(out)


def check(folder):
    errs, warns = [], []
    tj = os.path.join(folder, "theme.json")
    if not os.path.isfile(tj):
        return ["theme.json is missing"], []
    try:
        with open(tj, encoding="utf-8") as f:
            t = json.load(f)
    except ValueError as e:
        return ["theme.json is not valid JSON: %s" % e], []
    files = files_of(folder)
    total = 0
    if len(files) > MAX_FILES:
        errs.append("%d files (limit %d)" % (len(files), MAX_FILES))
    for rel in files:
        size = os.path.getsize(os.path.join(folder, rel))
        total += size
        if os.path.splitext(rel)[1].lower() not in EXT:
            errs.append("extension not allowed: " + rel)
        if size > MAX_FILE:
            errs.append("over 12 MB: " + rel)
    if total > MAX_TOTAL:
        errs.append("total size over 32 MB")
    tid = t.get("id", "")
    if not re.fullmatch(r"[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)+", str(tid)):
        errs.append('"id" must be a reverse domain with at least one dot, like com.you.theme.name')
    if not t.get("name"):
        errs.append('"name" is missing')
    elif isinstance(t["name"], dict) and "en" not in t["name"]:
        warns.append('"name" has no "en" entry (the fallback language)')
    if t.get("appearance") not in (None, "light", "dark", "auto"):
        errs.append('"appearance" must be light, dark or auto')
    if "accent" in t and not re.fullmatch(r"#[0-9A-Fa-f]{6}", str(t["accent"])):
        errs.append('"accent" must be #RRGGBB')
    if not t.get("wallpaper"):
        errs.append('"wallpaper" is required')
    for key in ("wallpaper", "wallpaperDark", "preview"):
        if t.get(key) and t[key] not in files:
            errs.append('"%s" names a missing file: %s' % (key, t[key]))
    for w in t.get("wallpapers", []):
        if w not in files:
            errs.append('"wallpapers" names a missing file: ' + w)
    for key in ("sounds", "icons"):
        if t.get(key) and not any(f.startswith(t[key].rstrip("/") + "/") for f in files):
            errs.append('"%s" folder is empty or missing: %s' % (key, t[key]))
    icons = [f for f in files if t.get("icons") and f.startswith(t["icons"].rstrip("/") + "/")]
    if len(icons) > 160:
        errs.append("more than 160 icon files")
    for f in icons:
        if not f.lower().endswith(".png"):
            warns.append("icon is not a PNG: " + f)
    st = t.get("settings", {})
    if st.get("shell.layout", "dock") not in LAYOUT:
        errs.append("settings.shell.layout must be dock or taskbar")
    if st.get("window.chrome", "default") not in CHROME:
        errs.append("settings.window.chrome must be one of " + ", ".join(sorted(CHROME)))
    if st.get("taskbar.size", "medium") not in SIZES:
        errs.append("settings.taskbar.size must be small, medium or large")
    if t.get("full") is not True and ("shell.layout" in st or "taskbar.size" in st or "start.sidePanel" in st):
        warns.append('layout settings without "full": true leave old bar settings behind when packs are switched')
    pal = t.get("palette", {})
    for k, v in pal.items():
        if k not in PALETTE:
            warns.append("unknown palette name (ignored): " + k)
        elif not re.fullmatch(r"[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?", str(v)):
            errs.append("palette %s must be RRGGBB or RRGGBBAA" % k)
    for fg, bg, need in PAIRS:
        if fg in pal and bg in pal:
            try:
                r = ratio(str(pal[fg])[:6], str(pal[bg])[:6])
            except ValueError:
                continue
            if r < need:
                errs.append("contrast %s on %s is %.2f:1 (needs %.1f:1, WCAG AA)" % (fg, bg, r, need))
    return errs, warns


def pack(folder):
    out = os.path.abspath(folder).rstrip("/\\") + ".nxvtheme"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in files_of(folder):
            info = zipfile.ZipInfo(rel, date_time=(2020, 1, 1, 0, 0, 0))  # same bytes for the same folder
            info.compress_type = zipfile.ZIP_DEFLATED
            with open(os.path.join(folder, rel), "rb") as f:
                z.writestr(info, f.read())
    return out


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if len(args) != 1 or not os.path.isdir(args[0]):
        print(__doc__)
        return 2
    errs, warns = check(args[0])
    for w in warns:
        print("warning: " + w)
    for e in errs:
        print("error:   " + e)
    if errs:
        print("%d error(s)" % len(errs))
        return 1
    print("ok" + (" with %d warning(s)" % len(warns) if warns else ""))
    if "--pack" in sys.argv:
        print("wrote " + pack(args[0]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
