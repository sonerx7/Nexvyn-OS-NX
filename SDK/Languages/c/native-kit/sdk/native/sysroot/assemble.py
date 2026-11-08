#!/usr/bin/env python3
"""Nexvyn native SDK sysroot: reports which libraries the devkitPro portlibs give, and prepares the overlay prefix.

  python assemble.py                      report: present / missing per plan item (docs/archive/NATIVE_PLATFORM_PLAN.md 3.3)
  python assemble.py --prefix DIR         also create the overlay prefix DIR (include/, lib/, lib/pkgconfig, sysroot.json)
  python assemble.py --prefix DIR --archive FILE
                                          unpack a kit archive (build.py package: nexvyn-native-sysroot-<ver>.tar.zst or .zip)
                                          into DIR, then report; the libraries in DIR count as present
  python assemble.py --show NAME          print the build steps of a missing library (recipes.json), builds nothing
  python assemble.py --json               machine readable report

The base sysroot is devkitPro's portlibs/switch (read only, never touched). The overlay prefix holds what the portlibs
lack; point the kit at it with `nxv-native build --sysroot DIR` or the NEXVYN_SYSROOT variable. This script downloads
and builds nothing: `build.py` (same folder) builds the recipes and packages the archive, --archive unpacks it.
"""
import argparse
import glob
import json
import os
import shutil
import subprocess
import sys
import tarfile
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))

# plan item -> (files that prove it is installed, relative to portlibs/switch; any one is enough)
ITEMS = {
    "sdl2": ["lib/libSDL2.a"],
    "gl (mesa/egl/gles)": ["lib/libEGL.a", "lib/libGLESv2.a"],
    "glad": ["lib/libglad.a"],
    "zlib": ["lib/libz.a"],
    "libpng": ["lib/libpng.a"],
    "libjpeg-turbo": ["lib/libjpeg.a", "lib/libturbojpeg.a"],
    "freetype": ["lib/libfreetype.a"],
    "curl": ["lib/libcurl.a"],
    "mbedtls": ["lib/libmbedtls.a"],
    "ffmpeg": ["lib/libavcodec.a"],
    "bzip2": ["lib/libbz2.a"],
    "zstd": ["lib/libzstd.a"],
    "lz4": ["lib/liblz4.a"],
    "openal": ["lib/libopenal.a"],
    "libarchive": ["lib/libarchive.a"],
    "sqlite": ["lib/libsqlite3.a"],
    "glib": ["lib/libglib-2.0.a"],
    "pixman": ["lib/libpixman-1.a"],
    "libiconv": ["lib/libiconv.a"],
}
# items solved without the portlibs: (where)
ALTERNATIVES = {
    "libiconv": "newlib ships a basic iconv.h/iconv() in devkitA64; the recipe adds the full encoding set",
}
# plan item -> recipe name in recipes.json
RECIPE_OF = {"zstd": "zstd", "lz4": "lz4", "openal": "openal", "libarchive": "libarchive", "sqlite": "sqlite",
             "glib": "glib", "pixman": "pixman", "libiconv": "libiconv"}


def dkp_root():
    cand = [os.environ.get("DEVKITPRO"), "/opt/devkitpro", "C:/devkitPro", "/c/devkitPro"]
    for c in cand:
        if c and os.path.isdir(os.path.join(c, "portlibs", "switch")):
            return c
    return None


def scan(root, overlay=None):
    """item -> where it was found: "portlibs", "overlay" or None. The overlay is the unpacked/built sysroot prefix."""
    base = os.path.join(root, "portlibs", "switch")
    res = {}
    for item, files in ITEMS.items():
        where = None
        if any(os.path.isfile(os.path.join(base, f)) for f in files):
            where = "portlibs"
        elif overlay and any(os.path.isfile(os.path.join(overlay, f)) for f in files):
            where = "overlay"
        res[item] = where
    return res


def unpack(archive, prefix):
    """Unpack a kit archive into prefix (the archive's single top folder is stripped)."""
    os.makedirs(prefix, exist_ok=True)
    tmp = None
    if archive.endswith(".zst"):
        zstd = shutil.which("zstd") or os.path.join(dkp_root() or "", "msys2", "usr", "bin", "zstd.exe")
        if not os.path.isfile(zstd) and not shutil.which("zstd"):
            raise SystemExit("zstd not found: install zstd or use the .zip archive")
        tmp = os.path.join(prefix, ".unpack.tar")
        subprocess.run([zstd, "-d", "-q", "-f", archive, "-o", tmp], check=True)
        opener = lambda: tarfile.open(tmp)
    elif archive.endswith(".zip"):
        opener = None
    else:
        opener = lambda: tarfile.open(archive)
    n = 0
    if opener is None:
        with zipfile.ZipFile(archive) as z:
            for m in z.namelist():
                parts = m.split("/", 1)
                if len(parts) == 2 and parts[1] and not m.endswith("/"):
                    dst = os.path.join(prefix, *parts[1].split("/"))
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    with z.open(m) as src, open(dst, "wb") as out:
                        shutil.copyfileobj(src, out)
                    n += 1
    else:
        with opener() as t:
            for m in t:
                parts = m.name.split("/", 1)
                if len(parts) == 2 and parts[1] and m.isfile():
                    dst = os.path.join(prefix, *parts[1].split("/"))
                    os.makedirs(os.path.dirname(dst), exist_ok=True)
                    with t.extractfile(m) as src, open(dst, "wb") as out:
                        shutil.copyfileobj(src, out)
                    n += 1
    if tmp and os.path.exists(tmp):
        os.remove(tmp)
    return n


def newlib_has_iconv(root):
    return os.path.isfile(os.path.join(root, "devkitA64", "aarch64-none-elf", "include", "iconv.h"))


def load_recipes():
    with open(os.path.join(HERE, "recipes.json"), encoding="utf-8") as f:
        return json.load(f)


def show(name):
    rec = load_recipes()
    r = rec["recipes"].get(name)
    if not r:
        print("no recipe for %s (known: %s)" % (name, ", ".join(rec["recipes"])), file=sys.stderr)
        return 1
    print("%s %s (%s)\n  url:    %s\n  sha256: %s" % (name, r["version"], r["license"], r["url"],
                                                     r["sha256"] or "(not pinned yet: fill from the first verified download)"))
    print("  needs:  %s\n  gives:  %s" % (", ".join(r["needs"]) or "-", ", ".join(r["provides"])))
    tc = "$NEXVYN_KIT/toolchain/nexvyn-switch.cmake"
    prefix = "$NEXVYN_SYSROOT"
    if r["system"] == "cmake":
        print("  steps:  cmake -S <src>/%s -B build -G Ninja -DCMAKE_TOOLCHAIN_FILE=%s -DCMAKE_INSTALL_PREFIX=%s %s"
              % (r["subdir"], tc, prefix, " ".join(r["flags"])))
        print("          cmake --build build && cmake --install build")
    elif r["system"] == "meson":
        print("  steps:  meson setup build <src> --cross-file $NEXVYN_KIT/toolchain/nexvyn-switch.meson.ini --prefix %s %s"
              % (prefix, " ".join(r["flags"])))
        print("          meson install -C build")
    elif r["system"] == "autotools":
        print("  steps:  ./configure --prefix=%s %s CC=aarch64-none-elf-gcc CFLAGS='-O2 -fPIE -D__SWITCH__'"
              % (prefix, " ".join(r["flags"])))
        print("          make install")
    else:
        print("  steps:  aarch64-none-elf-gcc -O2 -fPIE -D__SWITCH__ %s -c %s/sqlite3.c -o sqlite3.o; "
              "aarch64-none-elf-ar rcs %s/lib/libsqlite3.a sqlite3.o; copy sqlite3.h sqlite3ext.h to %s/include"
              % (" ".join(r["flags"]), r["subdir"], prefix, prefix))
    print("  note:   " + r["notes"])
    print("  easier: python build.py %s   (downloads, verifies, builds into build/native-sysroot)" % name)
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--prefix", help="create the overlay prefix here (or the prefix to unpack --archive into)")
    ap.add_argument("--archive", help="kit archive (.tar.zst / .zip from build.py package) to unpack into --prefix")
    ap.add_argument("--show", metavar="NAME", help="print the recipe steps for NAME")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    if a.show:
        return show(a.show)
    if a.archive and not a.prefix:
        print("--archive needs --prefix DIR", file=sys.stderr)
        return 1

    root = dkp_root()
    if not root:
        print("devkitPro not found (set DEVKITPRO)", file=sys.stderr)
        return 1
    pre = os.path.abspath(a.prefix) if a.prefix else None
    if a.archive:
        n = unpack(os.path.abspath(a.archive), pre)
        print("unpacked %d files from %s into %s" % (n, os.path.basename(a.archive), pre))
    found = scan(root, pre)
    iconv_nl = newlib_has_iconv(root)
    rec = load_recipes()
    vend = os.path.isfile(os.path.join(HERE, "vendor", "imgui", "imgui.cpp"))
    report = {"devkitpro": root, "present": sorted(k for k, v in found.items() if v),
              "overlay": sorted(k for k, v in found.items() if v == "overlay"),
              "missing": sorted(k for k, v in found.items() if not v),
              "newlib_iconv": iconv_nl, "imgui_vendored": vend}
    if a.json:
        print(json.dumps(report, indent=2))
    else:
        print("portlibs: %s/portlibs/switch" % root)
        for item in ITEMS:
            if found[item] == "portlibs":
                st = "present"
            elif found[item] == "overlay":
                st = "present (overlay %s)" % pre
            elif item in ALTERNATIVES and iconv_nl:
                st = "basic (%s)" % ALTERNATIVES[item]
            else:
                r = rec["recipes"].get(RECIPE_OF.get(item, ""), {})
                st = "MISSING  recipe: %s %s" % (RECIPE_OF.get(item, "-"), r.get("version", ""))
            print("  %-22s %s" % (item, st))
        print("  %-22s %s" % ("dear imgui", "vendored in vendor/imgui (MIT)" if vend else "MISSING"))

    if pre:
        for d in ("include", "lib/pkgconfig", "share"):
            os.makedirs(os.path.join(pre, d), exist_ok=True)
        with open(os.path.join(pre, "sysroot.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump({"base": os.path.join(root, "portlibs", "switch"), "overlay": pre,
                       "missing": report["missing"], "imgui": os.path.join(HERE, "vendor", "imgui")}, f, indent=2)
        print("overlay prefix ready: %s (set NEXVYN_SYSROOT to it; missing libraries: build.py <name>)" % pre)
    return 0


if __name__ == "__main__":
    sys.exit(main())
