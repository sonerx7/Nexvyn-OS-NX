"""Packs an app bundle folder into a single-file .nxvapp (format v2, docs/NXVAPP_FORMAT.md).

The zip has app.json at its root and a manifest.sha256 listing every other file (sha256sum format), so Nexvyn OS can
show "Intact" / "Modified" in the install sheet. Hidden files (.git, .DS_Store) are left out. With --sign the manifest
is also signed with the developer's ECDSA P-256 key (manifest.sig) and the sheet shows "Signed by <fingerprint>".

Usage:
  python tools/nxvapp_pack.py <bundle folder> [-o out.nxvapp] [--sign key.pem] [--index]
  python tools/nxvapp_pack.py --verify <file.nxvapp>

  -o        output file (default: <folder name without .nxvapp>.nxvapp next to the folder)
  --sign    sign with this key (create one with tools/nxvapp_keygen.py)
  --index   also print the repository index entry (id, version, size, sha256, signer, ...) as JSON
  --verify  check a package like Nexvyn OS does (file list, hashes, signature) and print the result
"""
import argparse
import hashlib
import json
import os
import re
import sys
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import nxvsign  # noqa: E402
import sdkinfo  # noqa: E402

KNOWN_CATEGORIES = {"system", "productivity", "office", "ai", "utilities", "media", "internet", "games", "switch", "developer", "emulator", "showcase", "other"}
KNOWN_PERMISSIONS = {"network", "files", "launch", "notifications", "games"}
RETIRED_PERMISSIONS = {"clipboard"}  # accepted and ignored by Nexvyn OS (sys.clipboard works for every app)
SHARE_KINDS = {"text", "url", "file", "image"}
STORED = {".png", ".jpg", ".jpeg", ".ogg", ".mp3", ".zip"}
SPECIAL = {"manifest.sha256", "manifest.sig"}
# the same limits as Nexvyn OS (core/nxvpkg): bigger packages are refused
MAX_FILES = 20000
MAX_UNPACKED = 1 << 30


def fail(msg):
    print("error: " + msg, file=sys.stderr)
    sys.exit(1)


def version_tuple(v):
    return tuple(int(x) if x.isdigit() else 0 for x in re.split(r"[.]", str(v).lstrip("vV")))


PACKAGE_TYPES = {"app", "game", "lib", "theme", "runtime"}
ID_RE = re.compile(r"[A-Za-z0-9_\-][A-Za-z0-9_.\-]{0,127}")


def check_v2(app, warnings):
    """The manifest v2 fields (docs/NATIVE_KIT.md "Package format"). Returns a list of hard errors; notes go to warnings.
    The same rules as core/pkgv2.cpp: a bad shape is an error, an unknown extra field is ignored."""
    errors = []
    t = app.get("type")
    if t is not None and (not isinstance(t, str) or t.lower() not in PACKAGE_TYPES):
        errors.append('"type" must be one of %s' % ", ".join(sorted(PACKAGE_TYPES)))
    arch = app.get("arch")
    if arch is not None and arch != "aarch64":
        errors.append('"arch" must be "aarch64" (the only architecture Nexvyn OS runs)')
    if "vulkan" in app:
        if not isinstance(app["vulkan"], bool):
            errors.append('"vulkan" must be a boolean')
        elif app["vulkan"]:
            mode = str(app.get("mode") or "exclusive").strip().lower()
            if sdkinfo.runtime_of(app) != "native" or mode not in ("window", "fullscreen"):
                errors.append('"vulkan" requires a windowed or fullscreen native module')
    for key in ("minOs", "minNative", "minSdk", "targetNative"):
        if key in app:
            v = sdkinfo.version_field(app.get(key))
            if not v or not sdkinfo.VERSION_RE.fullmatch(v):
                errors.append('"%s" must look like "1.2"' % key)
    if "build" in app:
        b = app["build"]
        if isinstance(b, bool) or not isinstance(b, int) or b < 0:
            errors.append('"build" must be a whole number, 0 or more')
    for key in ("uiApi", "uiTheme"):
        if key in app:
            n = app[key]
            if isinstance(n, bool) or not isinstance(n, int) or n < 1:
                errors.append('"%s" must be a whole number, 1 or more' % key)
    if "dataSchema" in app:
        d = app["dataSchema"]
        if isinstance(d, bool) or not isinstance(d, int) or d < 0:
            errors.append('"dataSchema" must be a whole number, 0 or more')
    if "dataSchema" in app and "dataVersion" in app and app["dataSchema"] != app["dataVersion"]:
        errors.append('"dataSchema" and "dataVersion" disagree')
    if "dataVersion" in app:
        d = app["dataVersion"]
        if isinstance(d, bool) or not isinstance(d, int) or d < 0:
            errors.append('"dataVersion" must be a whole number, 0 or more')
    if "provider" in app:
        p = app["provider"]
        if not isinstance(p, dict):
            errors.append('"provider" must be an object')
        else:
            if (t or "app").lower() not in ("lib", "runtime"):
                errors.append('"provider" is only for a "type": "lib" or "runtime" package')
            if not isinstance(p.get("id"), str) or not p.get("id", "").strip():
                errors.append('"provider.id" must be a non-empty string')
            if p.get("kind") not in ("runtime", "compat"):
                errors.append('"provider.kind" must be "runtime" or "compat"')
            if not isinstance(p.get("runtime"), str) or not p.get("runtime", "").strip():
                errors.append('"provider.runtime" must be a non-empty string')
            abi = p.get("abi")
            if isinstance(abi, bool) or abi != 1:
                errors.append('"provider.abi" must be 1: the system knows Runtime Provider ABI v1 only')
            caps = p.get("capabilities")
            if caps is not None and (not isinstance(caps, list) or any(not isinstance(c, str) or not c.strip() for c in caps)):
                errors.append('"provider.capabilities" must be an array of non-empty strings')
    if (t or "").lower() == "runtime" and "provider" not in app:
        errors.append('a "type": "runtime" package needs a "provider" object')
    if "size" in app:
        s = app["size"]
        if isinstance(s, bool) or not isinstance(s, (int, float)) or s < 0:
            errors.append('"size" must be a number of bytes')
    if "hashes" in app:
        h = app["hashes"]
        if not isinstance(h, dict) or not all(isinstance(v, str) and re.fullmatch(r"[0-9a-fA-F]{64}", v) for v in h.values()):
            errors.append('"hashes" must be an object of file: sha256 (64 hex digits)')
    if "needs" in app:
        n = app["needs"]
        if not isinstance(n, list):
            errors.append('"needs" must be an array')
        else:
            for e in n:
                nid = e if isinstance(e, str) else (e.get("id") if isinstance(e, dict) else None)
                ver = None
                if isinstance(e, str) and "@" in e:
                    nid, ver = e.split("@", 1)
                elif isinstance(e, dict):
                    ver = e.get("version")
                if not isinstance(nid, str) or not ID_RE.fullmatch(nid) or ".." in nid:
                    errors.append('"needs": every entry is "<id>", "<id>@<version>" or {"id", "version"}')
                    break
                if ver is not None and not sdkinfo.VERSION_RE.fullmatch(sdkinfo.version_field(ver) or ""):
                    errors.append('"needs": %s has a bad version' % nid)
    if (t or "app") == "lib":
        if app.get("needs"):
            warnings.append("a library that needs other libraries: they are installed first, up to 8 levels deep")
        if app.get("permissions"):
            warnings.append('a library has no permissions of its own (the apps that use it ask)')
    return errors


def validate(folder):
    path = os.path.join(folder, "app.json")
    if not os.path.isfile(path):
        fail("app.json not found in " + folder)
    try:
        with open(path, encoding="utf-8") as f:
            app = json.load(f)
    except ValueError as e:
        fail("app.json is not valid JSON: %s" % e)
    if not isinstance(app, dict):
        fail("app.json must be an object")
    app_id = app.get("id", "")
    if not isinstance(app_id, str) or not re.fullmatch(r"[A-Za-z0-9_\-][A-Za-z0-9_.\-]{0,127}", app_id) or ".." in app_id:
        fail('"id" must be letters, digits, ".", "-", "_" (reverse-domain style, e.g. com.you.app)')
    if not app.get("name"):
        fail('"name" is missing')
    v2_warnings = []
    v2_errors = check_v2(app, v2_warnings)
    if v2_errors:
        fail("; ".join(v2_errors))
    for w in v2_warnings:
        print("warning: " + w, file=sys.stderr)
    is_lib = str(app.get("type") or "app").lower() == "lib"
    runtime = sdkinfo.runtime_of(app)
    main = sdkinfo.main_file(app)
    native = app.get("native")
    if native is True:
        fail('"native": true is for apps built into Nexvyn OS; a C++ app package names its module: "native": "<id>.nxvmod"')
    if native:
        # C++ native module (tools/build_modules.py, docs/NATIVE_MODULES.md)
        if not isinstance(native, str) or not native.endswith(".nxvmod"):
            fail('"native" must name the module file ("<id>.nxvmod")')
        if not re.fullmatch(r"[0-9a-f]{16}", str(app.get("abi", ""))):
            fail('a native module needs the "abi" id of the Nexvyn OS build it was made for (tools/build_modules.py)')
        main = native
    if is_lib:
        pass
    elif runtime not in sdkinfo.RUNTIMES and not native:
        fail('unknown "runtime" "%s" (%s): Nexvyn OS %s would show the app as needing a newer system'
             % (runtime, ", ".join(sdkinfo.RUNTIMES), sdkinfo.SDK_VERSION))
    if runtime == "native" and not native:
        # full-screen native app (NATIVE_KIT.md): the .nro takes over the console
        mode = str(app.get("mode") or "exclusive").strip().lower()
        if mode not in sdkinfo.NATIVE_MODES:
            fail('"mode" "%s" is not available (use "window" or "fullscreen")' % mode)
        ext = ".nro" if mode == "exclusive" else ".nxvmod"  # window / fullscreen: in-process module (NATIVE_SDK_DESIGN 3.2)
        if not str(app.get("main") or "").lower().endswith(ext):
            fail('a %s native app names its program: "main": "<name>%s"' % (mode, ext))
        mn = sdkinfo.version_field(app.get("minNative"))
        if mn and not sdkinfo.VERSION_RE.fullmatch(mn):
            fail('"minNative" must look like "1.0"')
        ms = sdkinfo.version_field(app.get("minSdk"))
        if not ms or not sdkinfo.VERSION_RE.fullmatch(ms) or sdkinfo.cmp_versions(ms, sdkinfo.NATIVE_MIN_SDK) < 0:
            fail('a native app needs "minSdk": "%s" (older Nexvyn OS builds would read the .nro as a Lua script)'
                 % sdkinfo.NATIVE_MIN_SDK)
    if not is_lib and not os.path.isfile(os.path.join(folder, main)):
        fail(main + " not found")
    warnings = []
    if app.get("category", "other") not in KNOWN_CATEGORIES:
        warnings.append('unknown category "%s" (shown as "other")' % app.get("category"))
    perms = app.get("permissions")
    if perms is None:
        warnings.append('no "permissions" array: Nexvyn OS will ask the user about every permission (network, files, launch, notifications)')
    elif not isinstance(perms, list) or not all(isinstance(p, str) for p in perms):
        fail('"permissions" must be an array of strings')
    else:
        for p in perms:
            if p.lower() in RETIRED_PERMISSIONS:
                warnings.append('"%s": clipboard no longer needs a permission (remove it from "permissions")' % p)
            elif p.lower() not in KNOWN_PERMISSIONS:
                warnings.append('unknown permission "%s"' % p)
    targets = app.get("shareTargets")
    if targets is not None:
        if not isinstance(targets, list) or not all(isinstance(t, str) for t in targets):
            fail('"shareTargets" must be an array of strings ("text", "url", "file", "image" or ".ext")')
        for t in targets:
            if t.lower() not in SHARE_KINDS and not re.fullmatch(r"\.[A-Za-z0-9]{1,10}", t):
                warnings.append('unknown share target "%s"' % t)
    # "memory": the heap a windowed native app asks for, in MB (docs/NATIVE_KIT.md); Nexvyn OS ignores anything else
    mem = app.get("memory")
    if mem is not None and (isinstance(mem, bool) or not isinstance(mem, (int, float)) or not 1 <= mem <= 16384):
        warnings.append('"memory" must be a number of MB from 1 to 16384 (anything else is ignored by Nexvyn OS)')
    # versions (docs/COMPATIBILITY.md): minSdk = oldest SDK it runs on, targetSdk = the SDK it was tested on
    for key in ("minSdk", "targetSdk", "runtimeVersion"):
        v = sdkinfo.version_field(app.get(key))
        if v and not sdkinfo.VERSION_RE.fullmatch(v):
            fail('"%s" must look like "1.6"' % key)
    min_sdk, target = sdkinfo.version_field(app.get("minSdk")), sdkinfo.version_field(app.get("targetSdk"))
    if not target:
        warnings.append('no "targetSdk": Nexvyn OS treats the app as tested on SDK %s (its minSdk); add'
                        ' "targetSdk": "%s" once it is tested on this SDK' % (sdkinfo.target_sdk(app), sdkinfo.SDK_VERSION))
    elif min_sdk and sdkinfo.cmp_versions(target, min_sdk) < 0:
        warnings.append('"targetSdk" %s is below "minSdk" %s (it is treated as %s)' % (target, min_sdk, min_sdk))
    for key, v in (("minSdk", min_sdk), ("targetSdk", target)):
        if v and not sdkinfo.supports(v):
            warnings.append('"%s" %s is above SDK %s: only a newer Nexvyn OS can install it' % (key, v, sdkinfo.SDK_VERSION))
    if native or runtime == "native":
        min_native, target_native = sdkinfo.version_field(app.get("minNative")), sdkinfo.version_field(app.get("targetNative"))
        if not target_native:
            warnings.append('no "targetNative": Nexvyn OS treats the app as tested on Native SDK %s (its minNative); add'
                            ' "targetNative": "%s" once it is tested on this Native SDK'
                            % (min_native or "1.0", sdkinfo.NATIVE_VERSION))
        elif min_native and sdkinfo.cmp_versions(target_native, min_native) < 0:
            warnings.append('"targetNative" %s is below "minNative" %s (it is treated as %s)'
                            % (target_native, min_native, min_native))
    if "dataVersion" in app and "dataSchema" not in app:
        warnings.append('"dataVersion" is the old name: write "dataSchema" (Nexvyn OS reads both)')
    rt = sdkinfo.RUNTIMES.get(runtime)
    if rt and runtime != "native" and sdkinfo.cmp_versions(min_sdk or "1.0", rt["since"]) < 0:
        warnings.append('the "%s" runtime arrived in SDK %s: set "minSdk" to %s or newer' % (runtime, rt["since"], rt["since"]))
    icon = app.get("icon", "icon.png")
    if not os.path.isfile(os.path.join(folder, icon)):
        warnings.append(icon + " not found (a generic icon is shown)")
    for w in warnings:
        print("warning: " + w, file=sys.stderr)
    return app


def collect(folder):
    files = []
    for root, dirs, names in os.walk(folder):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for n in sorted(names):
            if n.startswith("."):
                continue
            full = os.path.join(root, n)
            rel = os.path.relpath(full, folder).replace(os.sep, "/")
            if rel in SPECIAL:
                continue
            if "\\" in rel or ":" in rel:
                fail("unsupported file name (no ':' or '\\'): " + rel)
            files.append((rel, full))
    files.sort()
    return files


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def verify(path):
    """Checks a package the way Nexvyn OS does. Exit code 1 when it would be shown as modified or invalid."""
    try:
        z = zipfile.ZipFile(path)
    except (OSError, zipfile.BadZipFile) as e:
        fail("%s: %s" % (path, e))
    names = [n for n in z.namelist() if not n.endswith("/")]
    prefix = ""
    if "app.json" not in names:
        tops = {n.split("/")[0] + "/" for n in names if "/" in n and n.split("/", 1)[1] == "app.json"}
        if len(tops) != 1:
            fail("app.json not found")
        prefix = tops.pop()
    files = {n[len(prefix):] for n in names if n.startswith(prefix)}
    total = sum(i.file_size for i in z.infolist())
    print("files:     %d (%d bytes unpacked)" % (len(files), total))
    if len(files) > MAX_FILES or total > MAX_UNPACKED:
        print("limits:    TOO BIG (at most %d files and %d bytes)" % (MAX_FILES, MAX_UNPACKED))
    bad = 0
    if "manifest.sha256" not in files:
        print("manifest:  none (shown as unsigned)")
    else:
        mtext = z.read(prefix + "manifest.sha256")
        listed = {}
        for line in mtext.decode("utf-8", "replace").splitlines():
            line = line.strip()
            if len(line) >= 66 and not line.startswith("#"):
                name = line[64:].strip().lstrip("*")
                listed[name] = line[:64].lower()
        problem = None
        for f in sorted(files):
            if f in SPECIAL or any(part.startswith(".") for part in f.split("/")):
                continue
            if f not in listed:
                problem = "not listed: " + f
                break
            if hashlib.sha256(z.read(prefix + f)).hexdigest() != listed[f]:
                problem = "hash differs: " + f
                break
        if not problem:
            for f in listed:
                if f not in files:
                    problem = "missing: " + f
                    break
        print("manifest:  " + ("MODIFIED (%s)" % problem if problem else "intact"))
        bad += bool(problem)
        if "manifest.sig" in files:
            ok, info = nxvsign.verify_manifest(z.read(prefix + "manifest.sig").decode("utf-8", "replace"), mtext)
            ok = ok and not problem
            print("signature: " + ("signed by " + info if ok else "INVALID (%s)" % (info if not problem else "files changed")))
            bad += not ok
        else:
            print("signature: none")
    sys.exit(1 if bad else 0)


def main():
    ap = argparse.ArgumentParser(description="Pack a Nexvyn OS app folder into a .nxvapp file (v2).")
    ap.add_argument("folder", nargs="?")
    ap.add_argument("-o", "--output")
    ap.add_argument("--sign", metavar="KEY.pem", help="sign the package with this ECDSA P-256 key")
    ap.add_argument("--index", action="store_true", help="print the repository index entry")
    ap.add_argument("--verify", metavar="FILE.nxvapp", help="check an existing package")
    ap.add_argument("--stamp", action="store_true",
                    help='write "size" (installed bytes) and "hashes" (sha256 of every file but app.json) into the packaged app.json')
    a = ap.parse_args()
    if a.verify:
        verify(a.verify)
        return
    if not a.folder:
        ap.error("the bundle folder is required")
    folder = os.path.abspath(a.folder.rstrip("/\\"))
    if not os.path.isdir(folder):
        fail(folder + " is not a folder")
    app = validate(folder)
    key = None
    if a.sign:
        try:
            with open(a.sign, encoding="ascii") as f:
                key = nxvsign.key_from_pem(f.read())
        except (OSError, ValueError) as e:
            fail("cannot use the signing key %s: %s" % (a.sign, e))
    base = os.path.basename(folder)
    if base.endswith(".nxvapp"):
        base = base[: -len(".nxvapp")]
    out = os.path.abspath(a.output or os.path.join(os.path.dirname(folder), base + ".nxvapp"))
    if out.startswith(folder + os.sep):
        fail("the output file must be outside the bundle folder")

    files = collect(folder)
    if len(files) > MAX_FILES or sum(os.path.getsize(f) for _, f in files) > MAX_UNPACKED:
        fail("the bundle is too big (at most %d files and 1 GB); Nexvyn OS would refuse it" % MAX_FILES)
    override = {}  # files whose packaged bytes differ from the folder's: app.json with "size" and "hashes" stamped in
    if a.stamp:
        stamped = dict(app)
        stamped["hashes"] = {rel: sha256_file(full) for rel, full in files if rel != "app.json"}
        stamped["size"] = sum(os.path.getsize(full) for _, full in files)
        override["app.json"] = (json.dumps(stamped, ensure_ascii=False, indent=2) + "\n").encode("utf-8")
    manifest = "".join("%s  %s\n" % (hashlib.sha256(override[rel]).hexdigest() if rel in override else sha256_file(full), rel)
                       for rel, full in files)
    signature = nxvsign.sign_manifest(key, manifest.encode("utf-8")) if key else None
    tmp = out + ".part"
    with zipfile.ZipFile(tmp, "w") as z:
        for rel, full in files:
            ext = os.path.splitext(rel)[1].lower()
            if rel in override:
                z.writestr(rel, override[rel], compress_type=zipfile.ZIP_DEFLATED)
                continue
            z.write(full, rel, compress_type=zipfile.ZIP_STORED if ext in STORED else zipfile.ZIP_DEFLATED)
        z.writestr("manifest.sha256", manifest, compress_type=zipfile.ZIP_DEFLATED)
        if signature:
            z.writestr("manifest.sig", signature, compress_type=zipfile.ZIP_DEFLATED)
    os.replace(tmp, out)
    size = os.path.getsize(out)
    signer = None
    if key:
        signer = nxvsign.fingerprint(nxvsign.pub_bytes(nxvsign.mul(key)))
    print("%s: %d files, %d bytes%s" % (out, len(files), size, ", signed by " + signer if signer else ""))
    if a.index:
        entry = {
            "id": app["id"],
            "name": app.get("name"),
            "description": app.get("description"),
            "version": str(app.get("version", "1.0")),
            "author": app.get("author", ""),
            "category": app.get("category", "other"),
            "minSdk": sdkinfo.version_field(app.get("minSdk")) or None,
            "targetSdk": sdkinfo.version_field(app.get("targetSdk")) or None,
            "permissions": app.get("permissions", []),
            "runtime": "native" if app.get("native") else app.get("runtime"),
            "abi": app.get("abi"),
            "download": "https://example.com/" + os.path.basename(out),
            "icon": "https://example.com/icon.png",
            "size": size,
            "sha256": sha256_file(out),
            "signer": signer,
        }
        print(json.dumps({k: v for k, v in entry.items() if v is not None}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
