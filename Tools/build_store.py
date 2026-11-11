#!/usr/bin/env python3
"""Builds the Nexvyn OS App Market (Store/) and the SDK samples catalog (SDK/samples.json) from this repository.

App Market items (Store/catalog.json, read by the App Market on the console):
    Store/Apps/<category>/<slug>/       an app:      source/ (the .nxvapp bundle), README.md, store.json, screenshots/
    Store/Games/<genre>/<slug>/         a game:      same layout
    Store/Emulators/<subcat>/<slug>/    an emulator: same layout (handheld, console, pc, arcade, multi, other)
    Store/Themes/<slug>/                a theme:     source/ (theme.json + images [+ sounds/]), store.json, icon.png
    Store/Fonts/<slug>/                 a font:      font.json, the font files, LICENSE, store.json, icon.png, screenshots/
    Store/Beta/...                      beta items:  packaged into Store/beta.json until released into Store/
    A folder in Store/Apps/<category>/, Store/Games/<genre>/ or Store/Emulators/<subcat>/ with app.json and no source/
    is the store page of an app written in C++ that ships with Nexvyn OS: it is enabled from the store. When <id>.nxvapp
    and module.json ({"abi": "...", "version": "..."}) are next to it, it is a native module instead, downloaded like any package.
SDK samples (SDK/samples.json, read by Nexvyn OS Studio's Samples section):
    SDK/Samples/<language>/<slug>/  source/, README.md, store.json ({"kind", "tags", "subtitle", "description"})

store.json (all optional): {"featured": true, "subtitle": {lang: text}, "description": {lang: text},
    "changelog": {lang: text}, "license": "MIT", "shots": [...],
    "kind": "game", "emuCategory": "handheld", "features": ["3d", "online"], "players": "1-4", "themeStyle": "dark"}
  - "shots" is the screenshot script used by the source repository's tools/store_shots.py.
  - Store metadata (the App Market's tabs, sorting and filters; all optional, an older App Market ignores them):
      kind         app, game, port, emulator, demo, theme, font (default: from the folder)
      emuCategory  handheld, console, pc, arcade, multi, other (string or list, for kind "emulator")
      features     3d, online, multiplayer, coop, offline, touch, controller, keyboard (default: derived from the code
                   and permissions: 3d when it calls g3d.*, online when it uses net.*, else offline, touch / controller /
                   keyboard from the input calls; what the maker lists replaces the derived list)
      players      "1", "2" or "1-4" (default: not shown); games that list "multiplayer" or "coop" should set it
      tech         lua, javascript, python, native (default: from the runtime)
      themeStyle   retro, modern, phone, dark, light, nature, minimal (themes)
Packages (.nxvapp, .nxvtheme, .nxvfont, sample .zip) are deterministic (fixed zip timestamps, manifest.sha256), so an
unchanged item keeps its SHA-256. Store/dates.json keeps, per id, when it was first published ("added"), its last
change ("updated") and every published version ("history"); they drive the store's New badges and version history.

Usage:
    python Tools/build_store.py                 build packages, catalogs and listings
    python Tools/build_store.py --check         verify that everything is up to date (CI); exits 1 if not
    python Tools/build_store.py --release ID    promote an item from Store/Beta/ to Store/ and rebuild
"""
import argparse
import datetime
import glob
import hashlib
import io
import json
import os
import re
import shutil
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW = "https://raw.githubusercontent.com/sonerx7/Nexvyn-OS-NX/main/"
TREE = "https://github.com/sonerx7/Nexvyn-OS-NX/tree/main/"
STORE = os.path.join(ROOT, "Store")
BETA = os.path.join(STORE, "Beta")
EMU_DIR = os.path.join(STORE, "Emulators")
SDK = os.path.join(ROOT, "SDK")
CATALOG = os.path.join(STORE, "catalog.json")
BETA_CATALOG = os.path.join(STORE, "beta.json")
SAMPLES = os.path.join(SDK, "samples.json")
DATES = os.path.join(STORE, "dates.json")
DEFAULT_LICENSE = "GPL-3.0-or-later"  # the repository's license (README): what an item is under unless it says otherwise

CATEGORIES = ["productivity", "office", "utilities", "media", "internet", "developer", "system", "switch", "other", "showcase", "games",
              "themes", "fonts"]
EMU_CATEGORIES = ["handheld", "console", "pc", "arcade", "multi", "other"]
EMU_CAT_ALIASES = {"handled": "handheld", "handhelds": "handheld", "consoles": "console", "computer": "pc", "others": "other"}
PERMISSIONS = {"network", "files", "launch", "notifications", "games"}
RETIRED = {"clipboard"}  # no longer a permission (sys.clipboard always works); still accepted in old app.json files
STORED = {".png", ".jpg", ".jpeg", ".ogg", ".mp3", ".zip", ".jar", ".ttf", ".otf", ".ttc", ".otc"}
LANGS = {"lua": "lua", "javascript": "javascript", "js": "javascript", "python": "python", "py": "python",
         "squirrel": "squirrel", "c": "c", "java": "java"}
KINDS = {"app", "game", "demo", "template"}
STORE_KINDS = {"app", "game", "port", "emulator", "demo", "theme", "font"}
FEATURES = ["3d", "online", "multiplayer", "coop", "offline", "touch", "controller", "keyboard"]
THEME_STYLES = ["retro", "modern", "phone", "dark", "light", "nature", "minimal"]
TECHS = {"lua", "javascript", "python", "native", "java", "squirrel"}
TECH_OF = {"lua": "lua", "js": "javascript", "javascript": "javascript", "python": "python", "py": "python", "c": "native",
           "native": "native", "java": "java", "squirrel": "squirrel"}
FONT_STYLES = ["regular", "semibold", "bold", "italic"]
FONT_FILES = (".ttf", ".otf", ".ttc", ".otc")
# SDK calls that need a permission (Lua sys.x(...), JS sys.x(...), Python sys.x(...))
USES = {
    "notifications": r"\bsys\.(notify|schedule)\s*\(",
    "games": r"\bsys\.games\s*\(",
    "launch": r"\bsys\.(launch|appUrl)\s*\(|nxv://",
    "network": r"\bnet\.(get|post|json|download|request|fetchJson)\s*\(",
}
ZIP_TIME = (2026, 1, 1, 0, 0, 0)
CAT_NAMES = {
    "en": {"office": "Office", "productivity": "Productivity", "utilities": "Utilities", "media": "Media", "internet": "Internet",
           "developer": "Developer", "system": "System", "switch": "Switch Tools", "other": "Other", "games": "Games",
           "themes": "Themes", "fonts": "Fonts", "showcase": "Showcase"},
    "tr": {"office": "Ofis", "productivity": "Verimlilik", "utilities": "Araçlar", "media": "Medya", "internet": "İnternet",
           "developer": "Geliştirici", "system": "Sistem", "switch": "Switch Araçları", "other": "Diğer",
           "games": "Oyunlar", "themes": "Temalar", "fonts": "Yazı Tipleri", "showcase": "Vitrin"},
}
EMU_CAT_NAMES = {
    "en": {"handheld": "Handheld", "console": "Console", "pc": "PC / Computer", "arcade": "Arcade", "multi": "Multi-System", "other": "Others"},
    "tr": {"handheld": "El Konsolları", "console": "Ev Konsolları", "pc": "PC / Bilgisayar", "arcade": "Arcade", "multi": "Çoklu Sistem", "other": "Diğer"},
}
# listing pages: README.md in English (what GitHub shows) and README.tr.md in Turkish
LISTING = {
    "en": {"file": "README.md", "other": "README.tr.md", "switch": "Türkçe", "app": "Item", "version": "Version",
           "about": "Description", "name": "Name", "builtin": " · ships with Nexvyn OS",
           "title": "# Nexvyn OS App Market",
           "intro": "Generated by `Tools/build_store.py`. **%d** items in total. The App Market on the console reads "
                    "`Store/catalog.json`; everything here was reviewed before it was published. To publish your own: "
                    "[SDK/Publishing](../SDK/Publishing/README.md)."},
    "tr": {"file": "README.tr.md", "other": "README.md", "switch": "English", "app": "Öğe", "version": "Sürüm",
           "about": "Açıklama", "name": "Ad", "builtin": " · Nexvyn OS ile gelir",
           "title": "# Nexvyn OS App Market (Uygulama Mağazası)",
           "intro": "Bu sayfa `Tools/build_store.py` ile üretilir. Toplam **%d** öğe. Konsoldaki App Market "
                    "`Store/catalog.json` dosyasını okur; buradaki her şey yayımlanmadan önce incelendi. Kendi işinizi "
                    "yayımlamak için: [SDK/Publishing](../SDK/Publishing/README.tr.md)."},
}


def fail(msg):
    print("error: " + msg, file=sys.stderr)
    sys.exit(1)


def rel(path):
    return os.path.relpath(path, ROOT).replace(os.sep, "/")


def text(v, lang="en"):
    if isinstance(v, dict):
        return v.get(lang) or v.get("en") or next(iter(v.values()), "")
    return v or ""


def read_json(path, default=None):
    if not os.path.isfile(path):
        return default
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def valid_id(app_id):
    return bool(re.fullmatch(r"[A-Za-z0-9_\-][A-Za-z0-9_.\-]{0,127}", app_id or "")) and ".." not in app_id


def load_app(src):
    app = read_json(os.path.join(src, "app.json"))
    where = rel(src)
    if not isinstance(app, dict):
        fail(where + ": app.json missing or not an object")
    app_id = app.get("id", "")
    if not valid_id(app_id):
        fail(where + ": bad id %r" % app_id)
    if not app.get("name"):
        fail(where + ": name missing")
    runtime = app.get("runtime", "")
    main = app.get("main") or ("app.jar" if runtime == "java" else "main.lua")
    if runtime != "c" and not os.path.isfile(os.path.join(src, main)):
        fail(where + ": %s missing" % main)
    if not os.path.isfile(os.path.join(src, app.get("icon", "icon.png"))):
        fail(where + ": icon missing")
    if app.get("category", "other") not in CATEGORIES:
        fail(where + ": unknown category %r" % app.get("category"))
    perms = app.get("permissions", [])
    if not isinstance(perms, list) or any(p not in PERMISSIONS | RETIRED for p in perms):
        fail(where + ": bad permissions %r" % perms)
    if app.get("native"):
        fail(where + ": native apps cannot be packaged")
    # Nexvyn OS enforces every permission since SDK 1.4: an undeclared one makes the call fail at run time
    used = set()
    for root, _, names in os.walk(src):
        for n in names:
            if os.path.splitext(n)[1] not in (".lua", ".js", ".mjs", ".py", ".nut", ".c", ".java"):
                continue
            with open(os.path.join(root, n), encoding="utf-8", errors="replace") as f:
                code = f.read()
            for perm, pattern in USES.items():
                if re.search(pattern, code):
                    used.add(perm)
    missing = sorted(used - set(perms))
    if missing:
        fail(where + ": uses %s but app.json does not declare it in \"permissions\"" % ", ".join(missing))
    return app


def valid_players(v):
    """"2" or "1-4" (or the number 2): 1 <= min <= max <= 64. Returns (min, max) or None."""
    m = re.fullmatch(r"(\d{1,2})(?:-(\d{1,2}))?", str(v).strip()) if v is not None else None
    if not m:
        return None
    lo = int(m.group(1))
    hi = int(m.group(2) or lo)
    return (lo, hi) if 1 <= lo <= hi <= 64 else None


def normalize_emu_cat(val):
    if not isinstance(val, str):
        return ""
    s = val.strip().lower()
    return EMU_CAT_ALIASES.get(s, s)


def store_meta(entry, app, src, extra, default_kind, where, warnings, default_emu_cat=None):
    """Adds kind, emuCategory, tech, features, players and themeStyle to a catalog entry. The maker's store.json value wins; what it
    leaves out is derived from the package (tech, 3d, online / offline, input) where that is possible."""
    kind = extra.get("kind", default_kind)
    if kind not in STORE_KINDS:
        fail("%s: store.json kind %r is not one of %s" % (where, kind, ", ".join(sorted(STORE_KINDS))))
    if default_kind in ("theme", "font") and kind != default_kind:
        fail("%s: a %s folder cannot have kind %r" % (where, default_kind, kind))
    entry["kind"] = kind
    if kind == "emulator":
        raw_ec = extra.get("emuCategory", default_emu_cat)
        if raw_ec is not None:
            if isinstance(raw_ec, str):
                c = normalize_emu_cat(raw_ec)
                if c not in EMU_CATEGORIES:
                    fail("%s: emuCategory %r is not one of %s" % (where, raw_ec, ", ".join(EMU_CATEGORIES)))
                entry["emuCategory"] = c
            elif isinstance(raw_ec, list) and raw_ec:
                ecs = []
                for x in raw_ec:
                    c = normalize_emu_cat(x)
                    if c not in EMU_CATEGORIES:
                        fail("%s: emuCategory %r is not one of %s" % (where, x, ", ".join(EMU_CATEGORIES)))
                    if c not in ecs:
                        ecs.append(c)
                entry["emuCategory"] = ecs
            else:
                fail("%s: store.json emuCategory must be a string or non-empty list of %s" % (where, ", ".join(EMU_CATEGORIES)))
    elif "emuCategory" in extra:
        fail("%s: store.json emuCategory is only valid when kind is \"emulator\"" % where)
    code = ""
    if src:
        for root, _, names in os.walk(src):
            for n in names:
                if os.path.splitext(n)[1] in (".lua", ".js", ".mjs", ".py"):
                    with open(os.path.join(root, n), encoding="utf-8", errors="replace") as f:
                        code += f.read() + "\n"
    if default_kind in ("app", "game", "emulator"):
        rt = app.get("runtime") or "lua"
        tech = extra.get("tech") or ("native" if entry.get("builtin") else TECH_OF.get(rt, rt))
        if tech not in TECHS:
            fail("%s: tech %r is not one of %s" % (where, tech, ", ".join(sorted(TECHS))))
        entry["tech"] = tech
        if "features" in extra:
            feats = extra["features"]
            if not isinstance(feats, list) or any(x not in FEATURES for x in feats):
                fail("%s: store.json features must be a list of %s" % (where, ", ".join(FEATURES)))
        else:
            feats = []
            if re.search(r"\bg3d\.", code):
                feats.append("3d")
            feats.append("online" if "network" in entry.get("permissions", []) else "offline")
            if re.search(r"\binput\.touch|\bui\.(button|tap)", code):
                feats.append("touch")
            if re.search(r"\binput\.(down|pressed|stick|buttons)", code):
                feats.append("controller")
            if re.search(r"\binput\.key|\bui\.keyboard", code):
                feats.append("keyboard")
            if entry.get("builtin") or not src:
                feats = [x for x in feats if x not in ("touch", "controller", "keyboard")]
            if kind == "game":
                warnings.append("%s: game declares no \"features\" in store.json (derived: %s)" % (where, ", ".join(feats)))
        entry["features"] = [x for x in FEATURES if x in feats]
        if "players" in extra:
            pl = valid_players(extra["players"])
            if not pl:
                fail("%s: store.json players %r must be like \"2\" or \"1-4\" (1 to 64)" % (where, extra["players"]))
            entry["players"] = "%d" % pl[0] if pl[0] == pl[1] else "%d-%d" % pl
        elif ("multiplayer" in feats or "coop" in feats) and kind == "game":
            warnings.append("%s: lists multiplayer / coop but no \"players\"" % where)
    if default_kind == "theme" or "themeStyle" in extra:
        style = extra.get("themeStyle")
        if style is not None and style not in THEME_STYLES:
            fail("%s: themeStyle %r is not one of %s" % (where, style, ", ".join(THEME_STYLES)))
        if default_kind == "theme" and not style:
            warnings.append("%s: theme declares no \"themeStyle\"" % where)
        if style:
            entry["themeStyle"] = style


def pack_files(files):
    """A deterministic zip of (name, path) pairs: sorted entries, fixed timestamps, plus manifest.sha256."""
    buf = io.BytesIO()
    lines = []
    with zipfile.ZipFile(buf, "w") as z:
        for name, full in sorted(files):
            with open(full, "rb") as f:
                data = f.read()
            lines.append("%s  %s\n" % (hashlib.sha256(data).hexdigest(), name))
            info = zipfile.ZipInfo(name, ZIP_TIME)
            info.external_attr = 0o644 << 16
            ext = os.path.splitext(name)[1].lower()
            info.compress_type = zipfile.ZIP_STORED if ext in STORED else zipfile.ZIP_DEFLATED
            z.writestr(info, data)
        info = zipfile.ZipInfo("manifest.sha256", ZIP_TIME)
        info.external_attr = 0o644 << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, "".join(lines))
    return buf.getvalue()


def pack(src):
    """Every file of a folder (hidden files and manifest.sha256 left out)."""
    files = []
    for root, dirs, names in os.walk(src):
        dirs[:] = sorted(d for d in dirs if not d.startswith(".") and d != "__pycache__")
        for n in sorted(names):
            if n.startswith(".") or n == "manifest.sha256":
                continue
            full = os.path.join(root, n)
            files.append((os.path.relpath(full, src).replace(os.sep, "/"), full))
    return pack_files(files)


def listing(entry, extra):
    """store.json's localized subtitle, longer description, changelog and license win over app.json's."""
    for key in ("subtitle", "description", "changelog"):
        if isinstance(extra.get(key), dict):
            entry[key] = extra[key]
    if isinstance(extra.get("license"), str) and extra["license"].strip():
        entry["license"] = extra["license"].strip()


def load_font(item):
    """Store/Fonts/<slug>/font.json -> (font.json, the files that go into the .nxvfont)."""
    where = rel(item)
    fj = read_json(os.path.join(item, "font.json"))
    if not isinstance(fj, dict):
        fail(where + ": font.json missing or not an object")
    if not valid_id(fj.get("id", "")):
        fail(where + ": bad id %r" % fj.get("id"))
    for key in ("family", "license", "version"):
        if not fj.get(key):
            fail(where + ": font.json needs %r" % key)
    styles = fj.get("styles")
    if not isinstance(styles, dict) or "regular" not in styles or any(s not in FONT_STYLES for s in styles):
        fail(where + ": font.json \"styles\" maps %s to font files and needs \"regular\"" % ", ".join(FONT_STYLES))
    for s, f in styles.items():
        if "/" in f or not f.lower().endswith(FONT_FILES) or not os.path.isfile(os.path.join(item, f)):
            fail(where + ": style %s: %r is not a font file next to font.json" % (s, f))
    lic = [n for n in os.listdir(item) if n.upper().startswith("LICENSE") or n.upper() == "OFL.TXT"]
    if not lic:
        fail(where + ": LICENSE missing (a font pack carries its license)")
    names = ["font.json"] + lic + sorted(set(styles.values()))
    return fj, [(n, os.path.join(item, n)) for n in names]


def build(check):
    stale = []
    today = datetime.date.today().isoformat()

    def put(path, data):
        old = None
        if os.path.exists(path):
            with open(path, "rb") as f:
                old = f.read()
        if old == data:
            return
        if check:
            stale.append(rel(path))
            return
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(data)

    warnings = []

    def put_json(path, obj):
        put(path, (json.dumps(obj, ensure_ascii=False, indent=2) + "\n").encode("utf-8"))

    dates = read_json(DATES, {}) or {}

    def stamp(entry):
        d = dates.get(entry["id"])
        if not d:
            d = dates[entry["id"]] = {"added": today, "updated": today, "version": entry["version"]}
        elif d.get("version") != entry["version"]:
            d.update(updated=today, version=entry["version"])
        hist = d.setdefault("history", [])
        if not hist or hist[-1]["version"] != entry["version"]:
            hist.append({"version": entry["version"], "date": d["updated"]})
        entry["added"], entry["updated"] = d["added"], d["updated"]
        entry["history"] = list(reversed(hist))[:20]  # newest first

    def shots_of(item):
        # .png, .jpg, .jpeg and .webp; ordered by the numeric prefix of the file name (0_cover < 1 < 2_start < 10);
        # one shot is never listed twice when both a png and a jpg of it exist (the jpg wins)
        found = {}
        for s in glob.glob(os.path.join(item, "screenshots", "*")):
            stem, ext = os.path.splitext(os.path.basename(s))
            if ext.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
                continue
            if stem not in found or ext.lower() in (".jpg", ".jpeg"):
                found[stem] = s

        def key(stem):
            m = re.match(r"(\d+)", stem)
            return (int(m.group(1)) if m else 1 << 30, stem)
        return [RAW + rel(found[k]) for k in sorted(found, key=key)]

    entries, seen = [], {}

    def claim(app_id, item):
        if app_id in seen:
            fail("duplicate id %s in %s and %s" % (app_id, seen[app_id], rel(item)))
        seen[app_id] = rel(item)

    # ---- helpers to package one store item cleanly (shared by Store/ and Store/Beta/)
    def add_bundle_item(item, default_kind, default_emu_cat, claim_fn, out_list, is_beta=False):
        src = os.path.join(item, "source")
        app = load_app(src)
        claim_fn(app["id"], item)
        slug = os.path.basename(item)
        data = pack(src)
        pkg = os.path.join(item, slug + ".nxvapp")
        put(pkg, data)
        with open(os.path.join(src, app.get("icon", "icon.png")), "rb") as f:
            put(os.path.join(item, "icon.png"), f.read())
        extra = read_json(os.path.join(item, "store.json"), {}) or {}
        cat_default = "games" if default_kind == "emulator" else app.get("category", "other")
        cat = extra.get("category") if extra.get("category") in CATEGORIES else (cat_default if cat_default in CATEGORIES else "other")
        entry = {"id": app["id"], "name": app["name"], "description": app.get("description", ""),
                 "version": str(app.get("version", "1.0")), "author": app.get("author", ""),
                 "category": cat,
                 "icon": RAW + rel(os.path.join(item, "icon.png")),
                 "download": RAW + rel(pkg), "size": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                 "minSdk": str(app.get("minSdk", "1.0")), "permissions": app.get("permissions", []),
                 "screenshots": shots_of(item), "featured": bool(extra.get("featured", False)),
                 "license": app.get("license") or DEFAULT_LICENSE, "source": TREE + rel(item)}
        if app.get("runtime") and not (app["runtime"] == "native" and app.get("mode") in ("window", "fullscreen")):
            entry["runtime"] = app["runtime"]
        if app.get("targetSdk"):
            entry["targetSdk"] = str(app["targetSdk"])
        if default_kind == "emulator" and extra.get("genre") and isinstance(extra["genre"], str):
            entry["genre"] = extra["genre"]
        listing(entry, extra)
        store_meta(entry, app, src, extra, default_kind, rel(item), warnings, default_emu_cat=default_emu_cat)
        if not is_beta:
            stamp(entry)
        else:
            entry["beta"] = True
            entry.setdefault("updated", today)
        out_list.append((item, app, entry))

    def add_theme_item(item, claim_fn, out_list, is_beta=False):
        src = os.path.join(item, "source")
        th = read_json(os.path.join(src, "theme.json"))
        if not th.get("id") or not th.get("name"):
            fail(rel(src) + ": theme.json needs id and name")
        claim_fn(th["id"], item)
        slug = os.path.basename(item)
        data = pack(src)
        pkg = os.path.join(item, slug + ".nxvtheme")
        put(pkg, data)
        extra = read_json(os.path.join(item, "store.json"), {}) or {}
        icon = os.path.join(item, "icon.png")
        if not os.path.isfile(icon):
            fail(rel(item) + ": icon.png missing")
        shots = shots_of(item) or [RAW + rel(os.path.join(src, th["wallpaper"]))]
        entry = {"id": th["id"], "kind": "theme", "name": th["name"], "description": th.get("description", ""),
                 "version": str(th.get("version", "1.0")), "author": th.get("author", ""), "category": "themes",
                 "icon": RAW + rel(icon), "download": RAW + rel(pkg), "size": len(data),
                 "sha256": hashlib.sha256(data).hexdigest(), "minSdk": "1.5", "permissions": [],
                 "screenshots": shots, "featured": bool(extra.get("featured", False)),
                 "license": th.get("license") or DEFAULT_LICENSE, "source": TREE + rel(item)}
        wav = os.path.join(item, "preview.wav")
        if os.path.isfile(wav):
            entry["audio"] = RAW + rel(wav)
        listing(entry, extra)
        store_meta(entry, th, None, extra, "theme", rel(item), warnings)
        if not is_beta:
            stamp(entry)
        else:
            entry["beta"] = True
            entry.setdefault("updated", today)
        out_list.append((item, th, entry))

    def add_font_item(item, claim_fn, out_list, is_beta=False):
        fj, files = load_font(item)
        claim_fn(fj["id"], item)
        slug = os.path.basename(item)
        data = pack_files(files)
        pkg = os.path.join(item, slug + ".nxvfont")
        put(pkg, data)
        icon = os.path.join(item, "icon.png")
        if not os.path.isfile(icon):
            fail(rel(item) + ": icon.png missing")
        extra = read_json(os.path.join(item, "store.json"), {}) or {}
        entry = {"id": fj["id"], "kind": "font", "name": fj.get("name") or fj["family"],
                 "description": fj.get("description", ""), "version": str(fj["version"]),
                 "author": fj.get("author", ""), "category": "fonts", "icon": RAW + rel(icon),
                 "download": RAW + rel(pkg), "size": len(data), "sha256": hashlib.sha256(data).hexdigest(),
                 "minSdk": "1.6", "permissions": [], "screenshots": shots_of(item),
                 "featured": bool(extra.get("featured", False)), "license": fj["license"],
                 "source": TREE + rel(item), "family": fj["family"],
                 "styles": [s for s in FONT_STYLES if s in fj["styles"]],
                 "tags": [fj.get("classification", "")] + fj.get("languages", [])}
        if fj.get("cjk"):
            entry["cjk"] = fj["cjk"]
        listing(entry, extra)
        entry["license"] = fj["license"]
        store_meta(entry, fj, None, extra, "font", rel(item), warnings)
        if not is_beta:
            stamp(entry)
        else:
            entry["beta"] = True
            entry.setdefault("updated", today)
        out_list.append((item, fj, entry))

    def add_builtin_item(item, default_kind, default_emu_cat, claim_fn, out_list, is_beta=False):
        app = read_json(os.path.join(item, "app.json"))
        claim_fn(app["id"], item)
        extra = read_json(os.path.join(item, "store.json"), {}) or {}
        cat_default = "games" if default_kind == "emulator" else app.get("category", "other")
        cat = extra.get("category") if extra.get("category") in CATEGORIES else (cat_default if cat_default in CATEGORIES else "other")
        entry = {"id": app["id"], "name": app["name"], "description": app.get("description", ""),
                 "version": str(app.get("version", "1.0")), "author": app.get("author", ""), "category": cat,
                 "icon": RAW + rel(os.path.join(item, "icon.png")), "permissions": [],
                 "screenshots": shots_of(item), "featured": bool(extra.get("featured", False)),
                 "license": DEFAULT_LICENSE}
        module = read_json(os.path.join(item, "module.json"))
        slug = os.path.basename(item)
        pkg = os.path.join(item, slug + ".nxvapp")
        if not os.path.isfile(pkg):
            pkg = os.path.join(item, app["id"] + ".nxvapp")
        if module and os.path.isfile(pkg):
            with open(pkg, "rb") as f:
                data = f.read()
            entry.update(runtime="native", abi=module["abi"], version=str(module.get("version", entry["version"])),
                         download=RAW + rel(pkg), size=len(data), sha256=hashlib.sha256(data).hexdigest())
        elif os.path.isfile(pkg):
            with open(pkg, "rb") as f:
                data = f.read()
            entry.update(download=RAW + rel(pkg), size=len(data), sha256=hashlib.sha256(data).hexdigest(),
                         permissions=app.get("permissions", []))
            if app.get("minSdk"):
                entry["minSdk"] = str(app["minSdk"])
            if app.get("targetSdk"):
                entry["targetSdk"] = str(app["targetSdk"])
        else:
            entry["builtin"] = True
        listing(entry, extra)
        store_meta(entry, app, None, extra, default_kind, rel(item), warnings, default_emu_cat=default_emu_cat)
        if not is_beta:
            stamp(entry)
        else:
            entry["beta"] = True
            entry.setdefault("updated", today)
        out_list.append((item, app, entry))

    # ---- apps, games and emulators (.nxvapp packages)
    for app_json in sorted(glob.glob(os.path.join(STORE, "Apps", "*", "*", "source", "app.json")) +
                           glob.glob(os.path.join(STORE, "Games", "*", "*", "source", "app.json"))):
        item = os.path.dirname(os.path.dirname(app_json))
        add_bundle_item(item, "game" if rel(item).startswith("Store/Games/") else "app", None, claim, entries)

    for app_json in sorted(glob.glob(os.path.join(EMU_DIR, "*", "*", "source", "app.json"))):
        item = os.path.dirname(os.path.dirname(app_json))
        sub = normalize_emu_cat(os.path.basename(os.path.dirname(item)))
        if sub not in EMU_CATEGORIES:
            fail("%s: unknown emulator subcategory folder %r (%s)" % (rel(item), sub, ", ".join(EMU_CATEGORIES)))
        add_bundle_item(item, "emulator", sub, claim, entries)

    # ---- themes (.nxvtheme packages)
    for theme_json in sorted(glob.glob(os.path.join(STORE, "Themes", "*", "source", "theme.json"))):
        add_theme_item(os.path.dirname(os.path.dirname(theme_json)), claim, entries)

    # ---- font packs (.nxvfont packages)
    for font_json in sorted(glob.glob(os.path.join(STORE, "Fonts", "*", "font.json"))):
        add_font_item(os.path.dirname(font_json), claim, entries)

    # ---- C++ apps / modules without source/
    builtin = (glob.glob(os.path.join(STORE, "Apps", "*", "*", "app.json")) +
               glob.glob(os.path.join(STORE, "Games", "*", "*", "app.json")))
    for app_json in sorted(builtin):
        item = os.path.dirname(app_json)
        if os.path.isdir(os.path.join(item, "source")):
            continue
        add_builtin_item(item, "game" if rel(item).startswith("Store/Games/") else "app", None, claim, entries)

    for app_json in sorted(glob.glob(os.path.join(EMU_DIR, "*", "*", "app.json"))):
        item = os.path.dirname(app_json)
        if os.path.isdir(os.path.join(item, "source")):
            continue
        sub = normalize_emu_cat(os.path.basename(os.path.dirname(item)))
        if sub not in EMU_CATEGORIES:
            fail("%s: unknown emulator subcategory folder %r (%s)" % (rel(item), sub, ", ".join(EMU_CATEGORIES)))
        add_builtin_item(item, "emulator", sub, claim, entries)

    entries.sort(key=lambda e: (CATEGORIES.index(e[2]["category"]), text(e[2]["name"], "en").lower()))
    put_json(CATALOG, {"schema": 1, "count": len(entries), "apps": [e[2] for e in entries]})

    # ---- Store/Beta -> Store/beta.json (in-development builds; kept separate from catalog.json until --release)
    beta_entries, beta_seen = [], {}

    def claim_beta(app_id, item):
        if app_id in beta_seen:
            fail("duplicate beta id %s in %s and %s" % (app_id, beta_seen[app_id], rel(item)))
        beta_seen[app_id] = rel(item)

    if os.path.isdir(BETA):
        for root, dirs, files in os.walk(BETA):
            dirs[:] = sorted(d for d in dirs if not d.startswith(".") and d != "__pycache__")
            rrel = os.path.relpath(root, BETA).replace(os.sep, "/")
            parts = [] if rrel == "." else rrel.split("/")
            has_src_app = os.path.isfile(os.path.join(root, "source", "app.json"))
            has_src_theme = os.path.isfile(os.path.join(root, "source", "theme.json"))
            has_font = "font.json" in files
            has_bin_app = "app.json" in files and not os.path.isdir(os.path.join(root, "source"))
            if not (has_src_app or has_src_theme or has_font or has_bin_app):
                continue
            dirs[:] = []  # item leaf found: do not descend into source/ or subfolders
            extra = read_json(os.path.join(root, "store.json"), {}) or {}
            emu_sub = None
            if len(parts) >= 3 and parts[0] == "Emulators":
                emu_sub = normalize_emu_cat(parts[1])
                if emu_sub not in EMU_CATEGORIES:
                    fail("%s: unknown beta emulator folder %r" % (rel(root), parts[1]))
            if has_src_theme or parts[:1] == ["Themes"]:
                add_theme_item(root, claim_beta, beta_entries, is_beta=True)
            elif has_font or parts[:1] == ["Fonts"]:
                add_font_item(root, claim_beta, beta_entries, is_beta=True)
            else:
                meta_src = os.path.join(root, "source", "app.json") if has_src_app else os.path.join(root, "app.json")
                app_raw = read_json(meta_src, {}) or {}
                if parts[:1] == ["Emulators"] or extra.get("kind") == "emulator" or "emuCategory" in extra:
                    dk = "emulator"
                elif parts[:1] == ["Games"] or app_raw.get("category") == "games" or extra.get("kind") == "game":
                    dk = "game"
                else:
                    dk = "app"
                if has_src_app:
                    add_bundle_item(root, dk, emu_sub, claim_beta, beta_entries, is_beta=True)
                else:
                    add_builtin_item(root, dk, emu_sub, claim_beta, beta_entries, is_beta=True)

    beta_entries.sort(key=lambda e: text(e[2]["name"], "en").lower())
    put_json(BETA_CATALOG, {"schema": 1, "count": len(beta_entries), "apps": [e[2] for e in beta_entries]})

    # ---- SDK samples for Studio
    samples = []
    for app_json in sorted(glob.glob(os.path.join(SDK, "Samples", "*", "*", "source", "app.json"))):
        src = os.path.dirname(app_json)
        item = os.path.dirname(src)
        language = LANGS.get(os.path.basename(os.path.dirname(item)).lower())
        if not language:
            continue
        app = read_json(app_json)
        slug = os.path.basename(item).lower()
        if not re.fullmatch(r"[a-z0-9_-]{1,64}", slug):
            fail(rel(item) + ": sample folder names must be [a-z0-9_-]")
        extra = read_json(os.path.join(item, "store.json"), {}) or {}
        data = pack(src)
        zpath = os.path.join(item, slug + ".zip")
        put(zpath, data)
        icon = os.path.join(src, app.get("icon", "icon.png"))
        if os.path.isfile(icon):
            with open(icon, "rb") as f:
                put(os.path.join(item, "icon.png"), f.read())
        kind = extra.get("kind") if extra.get("kind") in KINDS else "app"
        s = {"id": app["id"], "slug": slug, "language": language, "kind": kind, "name": app["name"],
             "subtitle": extra.get("subtitle", {}), "description": extra.get("description", app.get("description", "")),
             "tags": extra.get("tags", []), "minSdk": str(app.get("minSdk", "1.0")),
             "icon": RAW + rel(os.path.join(item, "icon.png")), "download": RAW + rel(zpath), "size": len(data),
             "sha256": hashlib.sha256(data).hexdigest(), "screenshots": shots_of(item)[:8]}
        if os.path.isfile(os.path.join(item, "README.md")):
            s["readme"] = RAW + rel(os.path.join(item, "README.md"))
        d = dates.setdefault("sample:" + slug, {"added": today})
        s["added"] = d["added"]
        samples.append(s)
    put_json(SAMPLES, {"schema": 1, "count": len(samples), "samples": samples})
    if not check:
        put_json(DATES, dict(sorted(dates.items())))

    # ---- listings: Store/README.md (+ README.tr.md), Emulators subfolders, Store/Beta/ and one pair per category folder
    groups = {}
    for item, app, entry in entries:
        groups.setdefault(os.path.dirname(item), []).append((item, app, entry))
    for sub in EMU_CATEGORIES:
        groups.setdefault(os.path.join(EMU_DIR, sub), [])
    for lang, L in LISTING.items():
        switch = "[%s](%s)" % (L["switch"], L["other"])
        for folder, rows in groups.items():
            title = EMU_CAT_NAMES[lang].get(os.path.basename(folder), os.path.basename(folder)) if os.path.dirname(folder) == EMU_DIR else os.path.basename(folder)
            lines = ["# %s" % title, "", switch, ""]
            if rows:
                lines += ["| | %s | %s | %s |" % (L["app"], L["version"], L["about"]), "|---|---|---|---|"]
                for item, app, entry in rows:
                    slug = os.path.basename(item)
                    tag = L["builtin"] if entry.get("builtin") else ""
                    lines.append("| <img src=\"%s/icon.png\" width=\"32\"> | [%s](%s/)%s | %s | %s |" % (
                        slug, text(entry["name"], lang), slug, tag, entry["version"],
                        text(entry.get("subtitle") or entry["description"], lang)))
            else:
                lines.append("No items yet." if lang == "en" else "Henüz öğe yok.")
            put(os.path.join(folder, L["file"]), ("\n".join(lines) + "\n").encode("utf-8"))
        # Store/Emulators/README(.tr).md index
        el = ["# Emulators" if lang == "en" else "# Emülatörler", "", switch, ""]
        for sub in EMU_CATEGORIES:
            el.append("- [%s](%s/) (%d)" % (EMU_CAT_NAMES[lang][sub], sub, len(groups.get(os.path.join(EMU_DIR, sub), []))))
        put(os.path.join(EMU_DIR, L["file"]), ("\n".join(el) + "\n").encode("utf-8"))
        # Store/Beta/README(.tr).md
        bl = ["# Beta" if lang == "en" else "# Beta (Geliştirme Aşaması)", "", switch, "",
              ("In-development apps, games and emulators tested via `Store/beta.json`. Promote one to the public store with "
               "`python Tools/build_store.py --release <slug>`." if lang == "en"
               else "Geliştirme aşamasındaki uygulamalar, oyunlar ve emülatörler (`Store/beta.json`). Yayına almak için: "
                    "`python Tools/build_store.py --release <slug>`."), ""]
        if beta_entries:
            bl += ["| | %s | %s | %s |" % (L["app"], L["version"], L["about"]), "|---|---|---|---|"]
            for item, app, entry in beta_entries:
                r = rel(item)[len("Store/Beta/"):]
                bl.append("| <img src=\"%s/icon.png\" width=\"32\"> | [%s](%s/) | %s | %s |" % (
                    r, text(entry["name"], lang), r, entry["version"],
                    text(entry.get("subtitle") or entry["description"], lang)))
        else:
            bl.append("No beta items right now." if lang == "en" else "Şu anda beta öğe yok.")
        put(os.path.join(BETA, L["file"]), ("\n".join(bl) + "\n").encode("utf-8"))
        lines = [L["title"], "", switch, "", L["intro"] % len(entries), ""]
        for cat in CATEGORIES:
            rows = [e for e in entries if e[2]["category"] == cat]
            if not rows:
                continue
            lines += ["## %s (%d)" % (CAT_NAMES[lang][cat], len(rows)), "", "| | %s | %s |" % (L["name"], L["about"]),
                      "|---|---|---|"]
            for item, app, entry in rows:
                r = rel(item)[len("Store/"):]
                tag = L["builtin"] if entry.get("builtin") else ""
                lines.append("| <img src=\"%s/icon.png\" width=\"32\"> | [%s](%s/)%s | %s |" % (
                    r, text(entry["name"], lang), r, tag, text(entry.get("subtitle") or entry["description"], lang)))
            lines.append("")
        put(os.path.join(STORE, L["file"]), "\n".join(lines).encode("utf-8"))

    for w in warnings:
        print("warning: " + w, file=sys.stderr)
    if check:
        if stale:
            print("out of date (run python Tools/build_store.py):")
            for s in stale:
                print("  " + s)
            return 1
        print("store is up to date: %d items, %d beta, %d samples" % (len(entries), len(beta_entries), len(samples)))
        return 0
    counts = {}
    for _, _, e in entries:
        counts[e["category"]] = counts.get(e["category"], 0) + 1
    print("built %d items (%s), %d beta and %d samples" % (
        len(entries), ", ".join("%s %d" % kv for kv in sorted(counts.items())), len(beta_entries), len(samples)))
    return 0


def release_beta(target):
    """Moves a beta item (by folder slug or id) out of Store/Beta/ into Store/ and rebuilds catalogs."""
    if not os.path.isdir(BETA):
        fail("Store/Beta does not exist")
    found = None
    for root, dirs, files in os.walk(BETA):
        dirs[:] = sorted(d for d in dirs if not d.startswith(".") and d != "__pycache__")
        has_src_app = os.path.isfile(os.path.join(root, "source", "app.json"))
        has_src_theme = os.path.isfile(os.path.join(root, "source", "theme.json"))
        has_font = "font.json" in files
        has_bin_app = "app.json" in files and not os.path.isdir(os.path.join(root, "source"))
        if not (has_src_app or has_src_theme or has_font or has_bin_app):
            continue
        dirs[:] = []
        meta_path = (os.path.join(root, "source", "theme.json") if has_src_theme
                     else os.path.join(root, "font.json") if has_font
                     else os.path.join(root, "source", "app.json") if has_src_app
                     else os.path.join(root, "app.json"))
        meta = read_json(meta_path, {}) or {}
        if os.path.basename(root) == target or meta.get("id") == target:
            found = (root, meta, has_src_theme, has_font)
            break
    if not found:
        fail("no beta item matching %r found under Store/Beta" % target)
    root, meta, is_theme, is_font = found
    rrel = os.path.relpath(root, BETA).replace(os.sep, "/")
    parts = rrel.split("/")
    slug = os.path.basename(root)
    if len(parts) >= 2 and parts[0] in ("Apps", "Games", "Emulators", "Themes", "Fonts"):
        dst = os.path.join(STORE, *parts)
    else:
        extra = read_json(os.path.join(root, "store.json"), {}) or {}
        kind = extra.get("kind") or ("theme" if is_theme else "font" if is_font else ("emulator" if "emuCategory" in extra else None))
        if kind == "theme":
            dst = os.path.join(STORE, "Themes", slug)
        elif kind == "font":
            dst = os.path.join(STORE, "Fonts", slug)
        elif kind == "emulator":
            ec = extra.get("emuCategory", "other")
            if isinstance(ec, list):
                ec = ec[0] if ec else "other"
            sub = normalize_emu_cat(ec) if isinstance(ec, str) else "other"
            if sub not in EMU_CATEGORIES:
                sub = "other"
            dst = os.path.join(EMU_DIR, sub, slug)
        elif kind == "game" or meta.get("category") == "games":
            genre = extra.get("genre") if isinstance(extra.get("genre"), str) and extra.get("genre") else "more"
            dst = os.path.join(STORE, "Games", genre, slug)
        else:
            cat = extra.get("category") if extra.get("category") in CATEGORIES else meta.get("category", "other")
            if cat not in CATEGORIES or cat in ("games", "themes", "fonts"):
                cat = "other"
            dst = os.path.join(STORE, "Apps", cat, slug)
    if os.path.exists(dst):
        shutil.rmtree(dst)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.move(root, dst)
    cur = os.path.dirname(root)
    while os.path.abspath(cur) != os.path.abspath(BETA) and os.path.isdir(cur):
        if os.listdir(cur):
            break
        os.rmdir(cur)
        cur = os.path.dirname(cur)
    print("released %s -> %s" % (rrel, rel(dst)))
    return build(False)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--release", metavar="ID_OR_SLUG", help="promote an item from Store/Beta/ to Store/ and rebuild")
    a = ap.parse_args()
    sys.exit(release_beta(a.release) if a.release else build(a.check))
