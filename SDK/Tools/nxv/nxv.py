#!/usr/bin/env python3
"""nxv - the Nexvyn OS app developer's command line (PC side). One file, Python 3.8+, no extra packages.

    nxv new <lang> <name> [--id ID] [--author NAME] [--dir DIR] [--store]
    nxv check <bundle> [--sdk PATH] [--frames N]
    nxv build <bundle> --sdk PATH                       Java: compile src/ into app.jar
    nxv pack <bundle> [-o OUT.nxvapp] [--sign KEY.pem --sdk PATH]  default: dist/<name>.nxvapp next to the folder
    nxv icon <glyph> <top color> <bottom color> <out.png> --sdk PATH [--glyph-color #FFFFFF]
    nxv install <bundle> [--sd SDROOT] [--autorun]      copy into an SD card folder (Ryujinx's by default)
    nxv push <bundle> --host CONSOLE_IP [--port 5000] [--user U --password P] [--packed] [--dry-run]

<lang> is lua, js (javascript), py (python), sq (squirrel), c or java. <bundle> is an app folder with app.json at its
root (MyApp.nxvapp/ or an App Market item's source/ folder).

--sdk (or the NEXVYN_SDK environment variable) is the path of a Nexvyn OS source checkout (the folder that holds
tools/lua_check.py). With it, `check` also runs the official checker of the app's language (lua_check.py, js_check.mjs,
py_check.py, rt_check.py), `build` compiles Java, `icon` draws icons and `pack --sign` signs. Without it, `check` does
the manifest, file, translation, permission and store.json checks below, which need nothing but Python.

Exit code 0 = everything passed, 1 = problems were found, 2 = wrong usage.
"""
import argparse
import ftplib
import hashlib
import io
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
RELEASE_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))  # Nexvyn-OS-NX/ (this file: SDK/Tools/nxv/)
TEMPLATES = os.path.join(RELEASE_ROOT, "SDK", "Languages")

LANGS = {"lua": "lua", "js": "javascript", "javascript": "javascript", "py": "python", "python": "python",
         "sq": "squirrel", "nut": "squirrel", "squirrel": "squirrel", "c": "c", "java": "java"}
# app.json "runtime" value and main-file extension of each language (docs/NXVAPP_FORMAT.md)
RUNTIME_OF = {"lua": "lua", "js": "javascript", "python": "python", "squirrel": "squirrel", "c": "c", "java": "java"}
EXT_OF = {".lua": "lua", ".js": "javascript", ".mjs": "javascript", ".py": "python", ".nut": "squirrel", ".c": "c",
          ".jar": "java"}
DEFAULT_MAIN = {"lua": "main.lua", "javascript": "main.js", "python": "main.py", "squirrel": "main.nut", "c": "main.c",
                "java": "app.jar"}
MIN_SDK = {"lua": (1, 0), "javascript": (1, 1), "python": (1, 3), "squirrel": (1, 5), "c": (1, 5), "java": (1, 5)}
SOURCE_EXT = {"lua": (".lua",), "javascript": (".js", ".mjs"), "python": (".py",), "squirrel": (".nut",),
              "c": (".c", ".h"), "java": (".java",)}
CHECKER = {"lua": ["python", "tools/lua_check.py"], "javascript": ["node", "tools/js_check.mjs"],
           "python": ["python", "tools/py_check.py"], "squirrel": ["python", "tools/rt_check.py"],
           "c": ["python", "tools/rt_check.py"], "java": ["python", "tools/rt_check.py"]}

CATEGORIES = {"system", "productivity", "utilities", "media", "internet", "games", "developer", "other"}
PERMISSIONS = {"network", "files", "launch", "notifications", "clipboard"}
SHARE_KINDS = {"text", "url", "file", "image"}
STORE_LANGS = ("en", "tr", "de", "fr", "es")
KINDS = {"app", "game", "demo", "template"}
# SDK calls that need a permission, in every language (Lua/JS/Python/Squirrel sys.x, C sys_x, Java Sys.x / Net.x)
USES = {
    "network": r"\b(?:net|Net)[._](?:get|post|json|download|request|fetch|fetchJson)\s*\(",
    "notifications": r"\b(?:sys|Sys)[._](?:notify|schedule)\s*\(",
    "clipboard": r"\b(?:sys|Sys)[._](?:clipboard|setClipboard)\s*\(",
    "launch": r"\b(?:sys|Sys)[._](?:launch|appUrl)\s*\(|nxv://",
}
TR_CALL = re.compile(r"""\bTR[123]?\(\s*["']([^"'\n]+)["']""")
# store.json "shots" steps (SnxOS tools/store_shots.py)
SHOT_STEP = re.compile(r"^(wait \d+(\.\d+)?|wclick [01](\.\d+)? [01](\.\d+)?|wmove [01](\.\d+)? [01](\.\d+)?|"
                       r"key \S+|dpad \S+|text .+|dark [01])$")
ZIP_TIME = (2026, 1, 1, 0, 0, 0)
STORED = {".png", ".jpg", ".jpeg", ".ogg", ".mp3", ".zip"}
MAX_FILES = 20000
MAX_UNPACKED = 1 << 30
TRANSLIT = str.maketrans("çğıöşüÇĞİÖŞÜâîûÂÎÛäëïÿÄËÏéèêáàóòúù", "cgiosuCGIOSUaiuAIUaeiyAEIeeeaaoouu")


# ------------------------------------------------------------------ helpers
class Report:
    def __init__(self):
        self.errors, self.warnings = [], []

    def error(self, msg):
        self.errors.append(msg)

    def warn(self, msg):
        self.warnings.append(msg)


def die(msg, code=2):
    print("nxv: " + msg, file=sys.stderr)
    sys.exit(code)


def version_tuple(v):
    return tuple(int(x) for x in re.findall(r"\d+", str(v))[:3])


def load_json(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def write_json(path, data):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def bundle_dir(path):
    path = os.path.abspath(path)
    if not os.path.isfile(os.path.join(path, "app.json")):
        if os.path.isfile(os.path.join(path, "source", "app.json")):
            return os.path.join(path, "source")  # an App Market / SDK item folder: use its source/
        die("%s has no app.json (give the app folder, e.g. MyApp.nxvapp/ or an item's source/)" % path)
    return path


def slug_of(bundle):
    """The package name: the folder name without .nxvapp, or the item folder's name for <item>/source."""
    name = os.path.basename(bundle.rstrip("/\\"))
    if name == "source":
        name = os.path.basename(os.path.dirname(bundle))
    return name[:-7] if name.lower().endswith(".nxvapp") else name


def slugify(name):
    s = re.sub(r"[^a-z0-9]+", "-", name.translate(TRANSLIT).lower()).strip("-")
    return s or "app"


def language_of(manifest):
    r = str(manifest.get("runtime", "")).lower()
    if r in RUNTIME_OF:
        return RUNTIME_OF[r]
    return EXT_OF.get(os.path.splitext(manifest.get("main", ""))[1].lower(), "lua")


def find_sdk(arg, required=False, what=""):
    path = arg or os.environ.get("NEXVYN_SDK", "")
    if path:
        path = os.path.abspath(path)
        if not os.path.isfile(os.path.join(path, "tools", "lua_check.py")):
            die("%s is not a Nexvyn OS source checkout (tools/lua_check.py missing)" % path)
        return path
    if required:
        die("%s needs a Nexvyn OS source checkout: pass --sdk PATH or set NEXVYN_SDK" % what)
    return None


def walk_files(root):
    """(relative path with /, absolute path) of every file, hidden files and __pycache__ left out, sorted."""
    out = []
    for base, dirs, names in os.walk(root):
        dirs[:] = sorted(d for d in dirs if not d.startswith(".") and d != "__pycache__")
        for n in sorted(names):
            if n.startswith("."):
                continue
            full = os.path.join(base, n)
            out.append((os.path.relpath(full, root).replace(os.sep, "/"), full))
    return sorted(out)


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] != b"\x89PNG\r\n\x1a\n" or head[12:16] != b"IHDR":
        return None
    return struct.unpack(">II", head[16:24])


# ------------------------------------------------------------------ new
def cmd_new(a):
    lang = LANGS.get(a.lang.lower())
    if not lang:
        die("unknown language %r (lua, js, py, sq, c, java)" % a.lang)
    tdir = os.path.join(a.templates or TEMPLATES, lang, "template")
    if not os.path.isfile(os.path.join(tdir, "app.json")):
        die("template not found: %s" % tdir)
    slug = slugify(a.name)
    parent = os.path.abspath(a.dir or ".")
    if a.store:
        item = os.path.join(parent, slug)
        dest = os.path.join(item, "source")
    else:
        item = None
        dest = os.path.join(parent, a.name if a.name.lower().endswith(".nxvapp") else a.name + ".nxvapp")
    if os.path.exists(item or dest):
        die("%s already exists" % (item or dest))
    shutil.copytree(tdir, dest, ignore=shutil.ignore_patterns("__pycache__", ".*"))
    m = load_json(os.path.join(dest, "app.json"))
    app_id = a.id or "com.%s.%s" % (re.sub(r"[^a-z0-9]", "", (a.author or "yourname").translate(TRANSLIT).lower()) or "yourname",
                                     slug.replace("-", ""))
    if not re.fullmatch(r"[A-Za-z0-9_\-][A-Za-z0-9_.\-]{0,127}", app_id):
        die("bad id %r: letters, digits, '.', '-', '_' (reverse domain: com.you.app)" % app_id)
    m["id"] = app_id
    m["name"] = {code: a.name for code in STORE_LANGS}
    if a.author:
        m["author"] = a.author
    write_json(os.path.join(dest, "app.json"), m)
    if item:
        write_json(os.path.join(item, "store.json"), {
            "kind": "app", "tags": [],
            "subtitle": {code: "" for code in STORE_LANGS},
            "description": {code: "" for code in STORE_LANGS},
            "shots": [["wait 3"], ["wait 1.5"], ["dark 1", "wait 1.5"]]})
        with open(os.path.join(item, "README.md"), "w", encoding="utf-8", newline="\n") as f:
            f.write("# %s\n\nTR: Uygulamanın ne yaptığını iki üç cümleyle anlatın.\n\nEN: Say what the app does in two or three "
                    "sentences.\n\n| | |\n|---|---|\n| Id | `%s` |\n| Language | %s |\n| Min SDK | %s |\n| Permissions | %s |\n"
                    % (a.name, app_id, lang, m.get("minSdk", "1.0"), ", ".join(m.get("permissions", [])) or "none"))
        os.makedirs(os.path.join(item, "screenshots"), exist_ok=True)
    print("created %s (%s, id %s)" % (item or dest, lang, app_id))
    if lang == "java":
        print("  Java: app.jar already holds the template's compiled code; rebuild it after editing src/:")
        print("        nxv build %s --sdk <Nexvyn OS checkout>" % dest)
    print("  next: edit the code, then  nxv check %s" % dest)
    return 0


# ------------------------------------------------------------------ check
def check_manifest(bundle, m, rep):
    if not isinstance(m, dict):
        rep.error("app.json: not a JSON object")
        return None
    app_id = m.get("id", "")
    if not re.fullmatch(r"[A-Za-z0-9_\-][A-Za-z0-9_.\-]{0,127}", str(app_id)) or ".." in str(app_id):
        rep.error("app.json: bad or missing id %r (reverse domain: com.you.app)" % app_id)
    elif "." not in app_id:
        rep.warn("app.json: id %r is not reverse-domain style (com.you.app)" % app_id)
    for field in ("name", "description"):
        v = m.get(field)
        if not v:
            (rep.error if field == "name" else rep.warn)("app.json: %s missing" % field)
        elif isinstance(v, dict):
            if "en" not in v:
                rep.warn("app.json: %s has no \"en\" text" % field)
            missing = [c for c in STORE_LANGS if c not in v]
            if missing:
                rep.warn("app.json: %s has no %s text (the store shows five languages)" % (field, "/".join(missing)))
    if "version" in m and not re.fullmatch(r"\d+(\.\d+){0,3}", str(m["version"])):
        rep.error("app.json: version %r must be dotted numbers like \"1.2\"" % m["version"])
    if m.get("category", "other") not in CATEGORIES:
        rep.error("app.json: unknown category %r (%s)" % (m.get("category"), ", ".join(sorted(CATEGORIES))))
    lang = language_of(m)
    if "runtime" in m and str(m["runtime"]).lower() not in RUNTIME_OF:
        rep.error("app.json: unknown runtime %r (lua, js, python, squirrel, c, java)" % m["runtime"])
    main = m.get("main") or DEFAULT_MAIN[lang]
    if not os.path.isfile(os.path.join(bundle, main)):
        rep.error("%s missing (app.json \"main\")" % main)
    if "minSdk" in m and not re.fullmatch(r"\d+\.\d+(\.\d+)?", str(m["minSdk"])):
        rep.error("app.json: minSdk %r must look like \"1.5\"" % m["minSdk"])
    elif version_tuple(m.get("minSdk", "1.0")) < MIN_SDK[lang]:
        rep.error('app.json: %s apps need "minSdk": "%d.%d"' % (lang, MIN_SDK[lang][0], MIN_SDK[lang][1]))
    perms = m.get("permissions")
    if perms is None:
        rep.warn("app.json: no \"permissions\" array; users are asked about all five permissions ([] = none needed)")
        perms = []
    elif not isinstance(perms, list) or any(p not in PERMISSIONS for p in perms):
        rep.error("app.json: permissions must be a list of %s" % ", ".join(sorted(PERMISSIONS)))
        perms = []
    for t in m.get("shareTargets", []) or []:
        if t not in SHARE_KINDS and not re.fullmatch(r"\.[A-Za-z0-9]+", str(t)):
            rep.error("app.json: shareTargets entry %r (text, url, file, image or an extension like \".txt\")" % t)
    win = m.get("window", {})
    if not isinstance(win, dict) or any(k in win and not isinstance(win[k], (int, float)) for k in
                                        ("width", "height", "minWidth", "minHeight")):
        rep.error("app.json: window width/height/minWidth/minHeight must be numbers")
    if m.get("native"):
        rep.error("app.json: \"native\" apps cannot be packaged")
    if m.get("category") == "games" and not m.get("gamepad"):
        rep.warn("app.json: games usually want \"gamepad\": true (the controller goes to the app)")
    icon = os.path.join(bundle, m.get("icon", "icon.png"))
    if not os.path.isfile(icon):
        rep.error("%s missing (the store needs an icon)" % m.get("icon", "icon.png"))
    else:
        size = png_size(icon)
        if not size:
            rep.error("%s is not a PNG" % m.get("icon", "icon.png"))
        elif size not in ((128, 128), (256, 256)):
            rep.warn("%s is %dx%d; 128x128 or 256x256 is recommended" % (m.get("icon", "icon.png"), size[0], size[1]))
    if lang == "java":
        check_jar(bundle, m, main, rep)
    return lang, set(perms)


def check_jar(bundle, m, main, rep):
    jar = os.path.join(bundle, main)
    if not os.path.isfile(jar):
        return
    try:
        with zipfile.ZipFile(jar) as z:
            names = set(z.namelist())
            mf = z.read("META-INF/MANIFEST.MF").decode("utf-8", "replace") if "META-INF/MANIFEST.MF" in names else ""
    except zipfile.BadZipFile:
        rep.error("%s is not a jar" % main)
        return
    cls = m.get("mainClass") or next((l.split(":", 1)[1].strip() for l in mf.splitlines() if l.startswith("Main-Class:")), "")
    if not cls:
        rep.error("no main class: app.json \"mainClass\" or Main-Class in the jar manifest")
    elif cls.replace(".", "/") + ".class" not in names:
        rep.error("%s is not in %s (rebuild it: nxv build)" % (cls, main))
    src = os.path.join(bundle, "src")
    if os.path.isdir(src):
        newest = max((os.path.getmtime(f) for _, f in walk_files(src)), default=0)
        if newest > os.path.getmtime(jar) + 1:
            rep.warn("src/ is newer than %s: rebuild it with nxv build" % main)


def check_sources(bundle, lang, perms, rep):
    files = walk_files(bundle)
    if len(files) > MAX_FILES:
        rep.error("%d files: Nexvyn OS refuses packages over %d files" % (len(files), MAX_FILES))
    total = sum(os.path.getsize(f) for _, f in files)
    if total > MAX_UNPACKED:
        rep.error("%d bytes: Nexvyn OS refuses packages over 1 GiB unpacked" % total)
    used, keys = set(), set()
    for rel, full in files:
        ext = os.path.splitext(rel)[1].lower()
        if ext in (".pyc", ".class") and not rel.startswith("src/"):
            rep.warn("%s: compiled files are not loaded by the runtime" % rel)
        if ext not in (".lua", ".js", ".mjs", ".py", ".nut", ".c", ".h", ".java"):
            continue
        with open(full, encoding="utf-8", errors="replace") as f:
            code = f.read()
        for perm, pattern in USES.items():
            if re.search(pattern, code):
                used.add(perm)
        keys |= {k for k in TR_CALL.findall(code) if not k.endswith((".", "_"))}  # "prefix." + x is built at run time
    for p in sorted(used - perms):
        rep.error("uses %s calls but app.json \"permissions\" does not declare \"%s\" (every permission is enforced)" % (p, p))
    for p in sorted(perms - used - {"files"}):
        rep.warn("declares \"%s\" but no call that needs it was found" % p)
    # translations: every TR key in lang/en.json and lang/tr.json (dotted keys may be system strings such as common.ok)
    tables = {}
    ldir = os.path.join(bundle, "lang")
    for code in sorted(os.listdir(ldir)) if os.path.isdir(ldir) else []:
        if not code.endswith(".json"):
            continue
        try:
            tables[code[:-5]] = load_json(os.path.join(ldir, code))
        except ValueError as e:
            rep.error("lang/%s: %s" % (code, e))
    if keys and not tables:
        rep.error("TR() is used but there is no lang/ folder")
    for code in ("en", "tr"):
        if keys and code not in tables:
            rep.error("lang/%s.json missing" % code)
    for code, table in tables.items():
        for k in sorted(keys):
            if k not in table and (code in ("en", "tr")):
                (rep.warn if "." in k else rep.error)('TR("%s") missing in lang/%s.json%s' % (
                    k, code, " (fine if it is a system key)" if "." in k else ""))
        if "en" in tables and code != "en":
            extra = set(tables["en"]) - set(table)
            if extra and code not in ("en", "tr"):
                rep.warn("lang/%s.json lacks %d key(s) of en.json (English is shown for them)" % (code, len(extra)))
    return files


def check_store_item(bundle, rep):
    """store.json, README.md and screenshots/ of an App Market / SDK item (the folder above source/)."""
    if os.path.basename(bundle) != "source":
        return
    item = os.path.dirname(bundle)
    sj = os.path.join(item, "store.json")
    if not os.path.isfile(os.path.join(item, "README.md")):
        rep.warn("item: README.md missing next to source/")
    if not os.path.isfile(sj):
        rep.warn("item: store.json missing (subtitle, description, kind, tags, shots)")
        return
    try:
        s = load_json(sj)
    except ValueError as e:
        rep.error("store.json: %s" % e)
        return
    for field in ("subtitle", "description"):
        v = s.get(field)
        if not isinstance(v, dict):
            rep.error("store.json: %s must be a {language: text} map" % field)
            continue
        for code in STORE_LANGS:
            if not str(v.get(code, "")).strip():
                rep.error("store.json: %s has no %s text" % (field, code))
        if field == "subtitle" and any(len(str(t)) > 60 for t in v.values()):
            rep.warn("store.json: keep subtitles under 60 characters")
    if "kind" in s and s["kind"] not in KINDS:
        rep.error("store.json: kind must be one of %s" % ", ".join(sorted(KINDS)))
    if "tags" in s and (not isinstance(s["tags"], list) or not all(isinstance(t, str) for t in s["tags"])):
        rep.error("store.json: tags must be a list of strings")
    shots = s.get("shots")
    if shots is not None:
        if not isinstance(shots, list) or not all(isinstance(x, list) for x in shots):
            rep.error("store.json: shots must be a list of lists of steps")
        else:
            if not 3 <= len(shots) <= 4:
                rep.warn("store.json: give 3-4 shots (got %d)" % len(shots))
            for i, shot in enumerate(shots, 1):
                for step in shot:
                    if not isinstance(step, str) or not SHOT_STEP.match(step):
                        rep.error("store.json: shot %d: bad step %r (wait S, wclick FX FY, wmove FX FY, key K, dpad D, "
                                  "text T, dark 0|1)" % (i, step))
    sdir = os.path.join(item, "screenshots")
    if not os.path.isdir(sdir) or not any(n.endswith(".png") for n in os.listdir(sdir)):
        rep.warn("item: no screenshots/*.png yet (SnxOS tools/store_shots.py takes them from \"shots\")")


def cmd_check(a):
    sdk = find_sdk(a.sdk)
    failed = 0
    for path in a.bundle:
        bundle = bundle_dir(path)
        rep = Report()
        try:
            m = load_json(os.path.join(bundle, "app.json"))
        except ValueError as e:
            rep.error("app.json: %s" % e)
            m = None
        lang = None
        if m is not None:
            res = check_manifest(bundle, m, rep)
            if res:
                lang, perms = res
                check_sources(bundle, lang, perms, rep)
        check_store_item(bundle, rep)
        print("%s %s (%s)" % ("FAIL" if rep.errors else "ok  ", bundle, lang or "?"))
        for e in rep.errors:
            print("  error: " + e)
        for w in rep.warnings:
            print("  warning: " + w)
        if rep.errors:
            failed += 1
        if lang and sdk:
            tool = CHECKER[lang]
            exe = sys.executable if tool[0] == "python" else shutil.which(tool[0])
            if not exe:
                print("  note: %s not found, the %s checker was skipped" % (tool[0], lang))
                continue
            cmd = [exe, os.path.join(sdk, tool[1]), bundle]
            if a.frames and lang in ("lua", "javascript", "python"):
                cmd += ["--frames", str(a.frames)]
            r = subprocess.run(cmd, cwd=sdk, capture_output=True, text=True, encoding="utf-8", errors="replace",
                               env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"))  # no __pycache__ in the bundle
            out = (r.stdout + r.stderr).strip()
            print("  %s: %s" % (os.path.basename(tool[1]), "passed" if r.returncode == 0 else "FAILED"))
            if r.returncode != 0 or a.verbose:
                print("    " + out.replace("\n", "\n    "))
            if r.returncode != 0 and not rep.errors:
                failed += 1
        elif lang and not sdk:
            print("  note: only the PC-side checks ran; add --sdk <Nexvyn OS checkout> (or NEXVYN_SDK) for the %s checker"
                  % lang)
    return 1 if failed else 0


# ------------------------------------------------------------------ build
def cmd_build(a):
    bundle = bundle_dir(a.bundle)
    lang = language_of(load_json(os.path.join(bundle, "app.json")))
    if lang != "java":
        print("%s: %s apps have no build step (C is compiled on the console, the others are interpreted)" % (bundle, lang))
        return 0
    sdk = find_sdk(a.sdk, True, "nxv build")
    r = subprocess.run([sys.executable, os.path.join(sdk, "tools", "java_build.py"), "app", bundle], cwd=sdk)
    return 0 if r.returncode == 0 else 1


# ------------------------------------------------------------------ pack
def pack_bytes(bundle):
    """The .nxvapp bytes, deterministic like the release repo's tools/build_store.py: sorted entries, fixed
    timestamps, manifest.sha256 last, hidden files and __pycache__ left out."""
    buf = io.BytesIO()
    lines = []
    with zipfile.ZipFile(buf, "w") as z:
        for name, full in walk_files(bundle):
            if name in ("manifest.sha256", "manifest.sig"):
                continue
            with open(full, "rb") as f:
                data = f.read()
            lines.append("%s  %s\n" % (hashlib.sha256(data).hexdigest(), name))
            info = zipfile.ZipInfo(name, ZIP_TIME)
            info.external_attr = 0o644 << 16
            info.compress_type = zipfile.ZIP_STORED if os.path.splitext(name)[1].lower() in STORED else zipfile.ZIP_DEFLATED
            z.writestr(info, data)
        info = zipfile.ZipInfo("manifest.sha256", ZIP_TIME)
        info.external_attr = 0o644 << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(info, "".join(lines))
    return buf.getvalue()


def cmd_pack(a):
    bundle = bundle_dir(a.bundle)
    if a.output:
        out = os.path.abspath(a.output)
    elif os.path.basename(bundle) == "source":
        out = os.path.join(os.path.dirname(bundle), slug_of(bundle) + ".nxvapp")  # <item>/<slug>.nxvapp, like build_store
    else:
        out = os.path.join(os.path.dirname(bundle), "dist", slug_of(bundle) + ".nxvapp")  # MyApp.nxvapp/ -> dist/MyApp.nxvapp
    os.makedirs(os.path.dirname(out), exist_ok=True)
    if os.path.abspath(out).startswith(bundle + os.sep):
        die("the output must not be inside the bundle")
    if a.sign:
        sdk = find_sdk(a.sdk, True, "nxv pack --sign")
        r = subprocess.run([sys.executable, os.path.join(sdk, "tools", "nxvapp_pack.py"), bundle, "-o", out, "--sign",
                            os.path.abspath(a.sign)])
        return 0 if r.returncode == 0 else 1
    data = pack_bytes(bundle)
    with open(out, "wb") as f:
        f.write(data)
    m = load_json(os.path.join(bundle, "app.json"))
    print("wrote %s (%d bytes)" % (out, len(data)))
    print("  id %s  version %s  sha256 %s" % (m.get("id"), m.get("version", "1.0"), hashlib.sha256(data).hexdigest()))
    return 0


# ------------------------------------------------------------------ icon
def cmd_icon(a):
    sdk = find_sdk(a.sdk, True, "nxv icon")
    cmd = [sys.executable, os.path.join(sdk, "tools", "make_icon.py"), a.glyph, a.top, a.bottom, os.path.abspath(a.out)]
    if a.glyph_color:
        cmd += ["--glyph-color", a.glyph_color]
    r = subprocess.run(cmd)
    return 0 if r.returncode == 0 else 1


# ------------------------------------------------------------------ install (local SD card folder, e.g. Ryujinx)
def default_sd():
    if os.name == "nt":
        return os.path.join(os.environ.get("APPDATA", ""), "Ryujinx", "sdcard")
    return os.path.join(os.path.expanduser("~"), ".config", "Ryujinx", "sdcard")


def cmd_install(a):
    bundle = bundle_dir(a.bundle)
    sd = os.path.abspath(a.sd or default_sd())
    if not os.path.isdir(sd):
        die("SD card folder not found: %s (pass --sd)" % sd)
    m = load_json(os.path.join(bundle, "app.json"))
    dest = os.path.join(sd, "NexvynOS", "Applications", slug_of(bundle) + ".nxvapp")
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    shutil.copytree(bundle, dest, ignore=shutil.ignore_patterns("__pycache__", ".*"))
    print("copied to %s" % dest)
    if a.autorun:
        path = os.path.join(sd, "NexvynOS", "autorun.txt")
        with open(path, "w", encoding="utf-8", newline="\n") as f:
            f.write("# written by nxv install --autorun: opens the app at boot. Delete this file afterwards.\n"
                    "wait 4\nlaunch %s\n" % m["id"])
        print("wrote %s (launch %s); delete it after testing or it runs at every boot" % (path, m["id"]))
    return 0


# ------------------------------------------------------------------ push (FTP to the console)
def ftp_mkdirs(ftp, path, made):
    cur = ""
    for part in [p for p in path.split("/") if p]:
        cur += "/" + part
        if cur in made:
            continue
        try:
            ftp.mkd(cur)
        except ftplib.error_perm:
            pass  # exists already
        made.add(cur)


def cmd_push(a):
    bundle = bundle_dir(a.bundle)
    remote_root = "/" + a.remote.strip("/")
    if a.packed:
        data = pack_bytes(bundle)
        uploads = [(remote_root + "/" + slug_of(bundle) + ".nxvapp", None, data)]
    else:
        target = remote_root + "/" + (a.name or slug_of(bundle) + ".nxvapp")
        uploads = [(target + "/" + rel, full, None) for rel, full in walk_files(bundle)]
    total = sum(len(d) if d is not None else os.path.getsize(f) for _, f, d in uploads)
    print("%s %d file(s), %d bytes to ftp://%s:%d%s" % ("would upload" if a.dry_run else "uploading", len(uploads), total,
                                                        a.host, a.port, remote_root))
    if a.dry_run:
        for path, _, _ in uploads:
            print("  " + path)
        return 0
    ftp = ftplib.FTP()
    try:
        ftp.connect(a.host, a.port, timeout=a.timeout)
        ftp.login(a.user or "anonymous", a.password or "")
        ftp.set_pasv(True)
        made = set()
        for path, full, data in uploads:
            ftp_mkdirs(ftp, path.rsplit("/", 1)[0], made)
            src = io.BytesIO(data) if data is not None else open(full, "rb")
            with src:
                ftp.storbinary("STOR " + path, src)
            print("  " + path)
        ftp.quit()
    except (OSError, ftplib.Error) as e:
        die("FTP: %s (is Connect to PC's FTP server running on the console, and is the address right?)" % e, 1)
    if a.packed:
        print("done: Nexvyn OS unpacks .nxvapp files in Applications/ at the next start (or open it in Files to install)")
    else:
        print("done: reopen Launcher on the console to see the app")
    return 0


# ------------------------------------------------------------------ main
def main(argv=None):
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")  # app names are often not ASCII
        except (AttributeError, ValueError):
            pass
    ap = argparse.ArgumentParser(prog="nxv", description="Nexvyn OS app developer tool (PC side).",
                                 formatter_class=argparse.RawDescriptionHelpFormatter, epilog=__doc__.split("\n\n", 1)[1])
    sub = ap.add_subparsers(dest="cmd")

    p = sub.add_parser("new", help="create an app from the SDK folder language templates")
    p.add_argument("lang")
    p.add_argument("name")
    p.add_argument("--id", help="app id (default com.<author>.<name>)")
    p.add_argument("--author")
    p.add_argument("--dir", help="parent folder (default: current folder)")
    p.add_argument("--store", action="store_true", help="App Market item layout: <slug>/source/, store.json, README.md")
    p.add_argument("--templates", help="Languages folder (default: SDK/Languages of this repository)")
    p.set_defaults(fn=cmd_new)

    p = sub.add_parser("check", help="check one or more bundles")
    p.add_argument("bundle", nargs="+")
    p.add_argument("--sdk")
    p.add_argument("--frames", type=int)
    p.add_argument("-v", "--verbose", action="store_true", help="also print the official checker's output when it passes")
    p.set_defaults(fn=cmd_check)

    p = sub.add_parser("build", help="Java: compile src/ into app.jar (needs a JDK and --sdk)")
    p.add_argument("bundle")
    p.add_argument("--sdk")
    p.set_defaults(fn=cmd_build)

    p = sub.add_parser("pack", help="pack a bundle into a deterministic .nxvapp")
    p.add_argument("bundle")
    p.add_argument("-o", "--output")
    p.add_argument("--sign", metavar="KEY.pem", help="sign with an ECDSA P-256 key (uses the checkout's nxvapp_pack.py)")
    p.add_argument("--sdk")
    p.set_defaults(fn=cmd_pack)

    p = sub.add_parser("icon", help="draw an icon in the built-in style (make_icon.py)")
    p.add_argument("glyph")
    p.add_argument("top")
    p.add_argument("bottom")
    p.add_argument("out")
    p.add_argument("--glyph-color")
    p.add_argument("--sdk")
    p.set_defaults(fn=cmd_icon)

    p = sub.add_parser("install", help="copy a bundle into an SD card folder (default: Ryujinx's)")
    p.add_argument("bundle")
    p.add_argument("--sd", help="SD card root folder")
    p.add_argument("--autorun", action="store_true", help="also write NexvynOS/autorun.txt that opens the app at boot")
    p.set_defaults(fn=cmd_install)

    p = sub.add_parser("push", help="upload a bundle to the console over FTP (Connect to PC)")
    p.add_argument("bundle")
    p.add_argument("--host", required=True)
    p.add_argument("--port", type=int, default=5000)
    p.add_argument("--user")
    p.add_argument("--password")
    p.add_argument("--remote", default="/NexvynOS/Applications",
                   help="Applications folder as the FTP server shows it (default /NexvynOS/Applications)")
    p.add_argument("--name", help="remote folder name (default <slug>.nxvapp)")
    p.add_argument("--packed", action="store_true", help="upload one .nxvapp file instead of the folder")
    p.add_argument("--timeout", type=float, default=15)
    p.add_argument("--dry-run", action="store_true", help="list what would be uploaded, connect to nothing")
    p.set_defaults(fn=cmd_push)

    a = ap.parse_args(argv)
    if not a.cmd:
        ap.print_help()
        return 2
    return a.fn(a)


if __name__ == "__main__":
    sys.exit(main())
