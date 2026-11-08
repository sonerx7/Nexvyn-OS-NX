#!/usr/bin/env python3
"""Nexvyn native SDK sysroot builder: builds the libraries devkitPro's portlibs lack, as static libs for devkitA64/libnx.

  python build.py                    build every recipe (idempotent: finished libraries are skipped)
  python build.py zstd sqlite        build only these (their `needs` that are recipes are built first)
  python build.py --force sqlite     rebuild even when the stamp matches
  python build.py --list             show recipes, versions, status
  python build.py test               build tests/sysroot_test.nro against the sysroot
  python build.py package            build everything missing, then write the kit archive + manifest
  python build.py --fetch-only       download and verify sources only

Layout (nothing here is committed):
  build/native-sysroot/              install prefix (include/, lib/, lib/pkgconfig, share/) = the overlay sysroot
  build/native-sysroot-cache/        downloads (dl/), extracted sources (src/), build trees (bld/), per-library logs (logs/)
  build/nexvyn-native-sysroot-<ver>.tar.zst (or .zip) + .manifest.json
A restart loses nothing: downloads, sources and the stamps live in the cache and the prefix.
Override with NEXVYN_SYSROOT_CACHE / NEXVYN_SYSROOT_OUT. Needs devkitPro (DEVKITPRO) with its msys2 (make, sh, pkg-config).
"""
import argparse
import hashlib
import json
import os
import shlex
import shutil
import subprocess
import sys
import tarfile
import time
import urllib.request
import zipfile

ELF_MAGIC = bytes([0x7F]) + b"ELF"
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
KIT_VERSION = "1.0.0"
CACHE = os.path.abspath(os.environ.get("NEXVYN_SYSROOT_CACHE", os.path.join(ROOT, "build", "native-sysroot-cache")))
OUT = os.path.abspath(os.environ.get("NEXVYN_SYSROOT_OUT", os.path.join(ROOT, "build", "native-sysroot")))
TOOLCHAIN_DIR = os.path.join(ROOT, "sdk", "native", "toolchain")
PATCH_DIR = os.path.join(HERE, "patches")
CMAKE_TC = os.path.join(TOOLCHAIN_DIR, "nexvyn-switch.cmake")
CMAKE_TC_LOCAL = None  # filled by dkp_env()


def die(msg):
    print("error: " + msg, file=sys.stderr)
    sys.exit(1)


def posix(p):
    return p.replace("\\", "/")


def dkp_root():
    for c in (os.environ.get("DEVKITPRO"), "C:/devkitPro", "/c/devkitPro", "/opt/devkitpro"):
        if c and os.path.isdir(os.path.join(c, "portlibs", "switch")):
            return posix(c if not c.startswith("/c/") else "C:/" + c[3:])
    die("devkitPro not found (set DEVKITPRO)")


DKP = dkp_root()
PORTLIBS = DKP + "/portlibs/switch"
A64 = DKP + "/devkitA64/bin"
EXE = ".exe" if os.name == "nt" else ""


def M(p):
    """Windows path -> msys2 path (C:/x -> /c/x); everything the build shell sees goes through this."""
    p = posix(p)
    if len(p) > 1 and p[1] == ":":
        return "/" + p[0].lower() + p[2:]
    return p


DKPM = "/opt/devkitpro"
OUTM = M(OUT)
PORTM = DKPM + "/portlibs/switch"
A64M = DKPM + "/devkitA64/bin"


def tool_env():
    env = dict(os.environ)
    env["DEVKITPRO"] = DKPM
    env["DEVKITA64"] = DKPM + "/devkitA64"
    env["NEXVYN_SYSROOT"] = OUTM
    env["PKG_CONFIG_LIBDIR"] = OUTM + "/lib/pkgconfig:" + PORTM + "/lib/pkgconfig"
    env.pop("PKG_CONFIG_PATH", None)
    venv = os.path.join(CACHE, "venv", "Scripts" if os.name == "nt" else "bin")
    if os.path.isdir(venv):
        env["PATH"] = M(venv) + os.pathsep + env.get("PATH", "")
    return env


def load_recipes():
    with open(os.path.join(HERE, "recipes.json"), encoding="utf-8") as f:
        return json.load(f)


def save_recipes(rec):
    with open(os.path.join(HERE, "recipes.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(rec, f, indent=2, ensure_ascii=False)
        f.write("\n")


def sha256_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def fetch(name, r, rec):
    """Download the source archive into the cache, verify (or pin) its sha256. Returns the local path."""
    dl = os.path.join(CACHE, "dl")
    os.makedirs(dl, exist_ok=True)
    fn = r["url"].rsplit("/", 1)[1]
    if "." not in fn or fn.endswith(("master", "main")):
        fn = name + "-" + r["version"] + ".tar.gz"
    if r.get("archive_name"):
        fn = r["archive_name"]
    path = os.path.join(dl, fn)
    if not os.path.isfile(path):
        print("  download %s" % r["url"])
        tmp = path + ".part"
        req = urllib.request.Request(r["url"], headers={"User-Agent": "nexvyn-sysroot/1"})
        try:
            with urllib.request.urlopen(req, timeout=120) as resp, open(tmp, "wb") as f:
                shutil.copyfileobj(resp, f)
        except OSError as e:  # python's CA store can lack an issuer (SSL); curl uses the system one
            print("  python download failed (%s), trying curl" % e)
            curl = shutil.which("curl") or DKP + "/msys2/usr/bin/curl.exe"
            subprocess.run([curl, "-fsSL", "--retry", "3", "-o", tmp, r["url"]], check=True)
        os.replace(tmp, path)
    got = sha256_file(path)
    if r.get("sha256"):
        if got != r["sha256"]:
            os.remove(path)
            die("%s: sha256 mismatch (got %s, recipe %s); file removed" % (name, got, r["sha256"]))
    else:
        print("  pinning sha256 %s" % got)
        r["sha256"] = got
        save_recipes(rec)
    return path


def extract(name, archive, r):
    src = os.path.join(CACHE, "src", name + "-" + r["version"])
    done = os.path.join(src, ".extracted")
    if os.path.isfile(done):
        # the vendored trees are the project's own files: a changed one must reach an already extracted source, or a
        # rebuild (its stamp changed with them) compiles the old copy
        for frm, to in r.get("copy_in", {}).items():
            shutil.copytree(os.path.join(HERE, frm), os.path.join(src, to), dirs_exist_ok=True)
        return src
    shutil.rmtree(src, ignore_errors=True)
    os.makedirs(src)
    if archive.endswith(".zip"):
        with zipfile.ZipFile(archive) as z:
            z.extractall(src)
    else:
        with tarfile.open(archive) as t:
            for m in t:
                try:
                    t.extract(m, src, filter="fully_trusted")
                except (OSError, tarfile.TarError) as e:  # symlinks on Windows: sources do not need them
                    if not (m.issym() or m.islnk()):
                        raise
                    print("  skipped link %s (%s)" % (m.name, e))
    top = [d for d in os.listdir(src)]
    if len(top) == 1 and os.path.isdir(os.path.join(src, top[0])) and not r.get("no_strip"):
        inner = os.path.join(src, top[0])
        for e in os.listdir(inner):
            shutil.move(os.path.join(inner, e), os.path.join(src, e))
        os.rmdir(inner)
    for p in r.get("patches", []):
        pf = os.path.join(PATCH_DIR, p)
        print("  patch %s" % p)
        exe = shutil.which("patch") or shutil.which("patch", path=DKP + "/msys2/usr/bin") or die(
            "`patch` not found (Git for Windows ships it in usr/bin; devkitPro msys2: pacman -S patch)")
        with open(os.path.join(CACHE, "logs", "patch-" + name + ".log"), "w") as lg:
            subprocess.run([exe, "-p1", "-N", "-i", pf], cwd=src, check=True, stdout=lg, stderr=subprocess.STDOUT)
    for frm, to in r.get("copy_in", {}).items():  # small vendored trees dropped into the source (e.g. a meson subproject)
        shutil.copytree(os.path.join(HERE, frm), os.path.join(src, to), dirs_exist_ok=True)
    open(done, "w").write("ok\n")
    return src


class Log:
    def __init__(self, name):
        os.makedirs(os.path.join(CACHE, "logs"), exist_ok=True)
        self.path = os.path.join(CACHE, "logs", name + ".log")
        self.f = open(self.path, "w", encoding="utf-8", errors="replace")

    def run_native(self, cmd, cwd=None, env=None):
        """Run a native (non-msys) process: used for meson, which must not see MSYSTEM (it would switch to cygwin paths)."""
        self.f.write("\n$ [native] %s\n" % " ".join(str(c) for c in cmd))
        self.f.flush()
        e = dict(os.environ, **(env or {}))
        e.pop("MSYSTEM", None)
        p = subprocess.run([str(c) for c in cmd], cwd=cwd, env=e, stdout=self.f, stderr=subprocess.STDOUT)
        if p.returncode != 0:
            raise RuntimeError("command failed (%d): %s; see %s" % (p.returncode, str(cmd[0]) + " " + str(cmd[1]), self.path))

    def run(self, cmd, cwd=None, env=None):
        """Run through devkitPro's msys2 bash (its cmake refuses to run from Windows, and its make/ninja/pkg-config are there)."""
        line = cmd if isinstance(cmd, str) else " ".join(shlex.quote(str(c)) for c in cmd)
        self.f.write("\n$ %s\n" % line)
        self.f.flush()
        e = dict(tool_env(), **(env or {}))
        e["MSYSTEM"] = "MSYS"
        e["CHERE_INVOKING"] = "1"
        bash = DKP + "/msys2/usr/bin/bash.exe" if os.name == "nt" else "bash"
        p = subprocess.run([bash, "-lc", line], cwd=cwd, env=e, stdout=self.f, stderr=subprocess.STDOUT)
        if p.returncode != 0:
            raise RuntimeError("command failed (%d): %s; see %s" % (p.returncode, line[:120], self.path))

    def close(self):
        self.f.close()


def common_cflags():
    return ("-O2 -march=armv8-a+crc+crypto -mtune=cortex-a57 -mtp=soft -ftls-model=local-exec -fPIE -ffunction-sections "
            "-fdata-sections -D__SWITCH__ -I%s/libnx/include -I%s/include -I%s/include" % (DKPM, OUTM, PORTM))


def cmake_build(name, r, src, bld, log):
    sub = os.path.join(src, r.get("subdir", "."))
    os.makedirs(bld, exist_ok=True)
    cmd = ["cmake", "-S", M(sub), "-B", M(bld), "-G", "Ninja", "-DCMAKE_TOOLCHAIN_FILE=" + M(CMAKE_TC),
           "-DCMAKE_INSTALL_PREFIX=" + OUTM + ("/" + r["prefix_subdir"] if r.get("prefix_subdir") else ""),
           "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_POSITION_INDEPENDENT_CODE=ON",
           "-DCMAKE_POLICY_VERSION_MINIMUM=3.5", "-DCMAKE_PREFIX_PATH=" + OUTM + ";" + PORTM,
           "-DCMAKE_INSTALL_LIBDIR=lib"] + [f.replace("{OUT}", OUTM) for f in r.get("flags", [])]
    log.run(cmd)
    log.run(["cmake", "--build", M(bld), "-j", str(os.cpu_count() or 4)])
    log.run(["cmake", "--install", M(bld)])


def amalgamation_build(name, r, src, bld, log):
    sub = os.path.join(src, r.get("subdir", "."))
    os.makedirs(bld, exist_ok=True)
    os.makedirs(OUT + "/lib/pkgconfig", exist_ok=True)
    os.makedirs(OUT + "/include", exist_ok=True)
    lib = OUT + "/lib/libsqlite3.a"
    if os.path.exists(lib):
        os.remove(lib)
    obj = M(os.path.join(bld, "sqlite3.o"))
    log.run([A64M + "/aarch64-none-elf-gcc"] + common_cflags().split() + r.get("flags", [])
            + ["-c", M(os.path.join(sub, "sqlite3.c")), "-o", obj])
    objs = [obj]
    log.run([A64M + "/aarch64-none-elf-gcc-ar", "rcs", M(lib)] + objs)
    for h in ("sqlite3.h", "sqlite3ext.h"):
        shutil.copy2(os.path.join(sub, h), OUT + "/include/" + h)
    with open(OUT + "/lib/pkgconfig/sqlite3.pc", "w", newline="\n") as f:
        f.write("prefix=%s\nlibdir=${prefix}/lib\nincludedir=${prefix}/include\n\nName: SQLite\n"
                "Description: SQL database engine\nVersion: %s\nLibs: -L${libdir} -lsqlite3\nCflags: -I${includedir}\n"
                % (OUTM, r["version"]))


def add_shims(r, bld, log):
    """Compile the recipe's small shim sources (sysroot/shims/) and append them to its first library."""
    lib = M(os.path.join(OUT, provides_paths(r)[0]))
    for extra in r.get("extra_sources", []):
        o = M(os.path.join(bld, os.path.basename(extra) + ".o"))
        os.makedirs(bld, exist_ok=True)
        log.run([A64M + "/aarch64-none-elf-gcc"] + common_cflags().split() + ["-c", M(os.path.join(HERE, extra)), "-o", o])
        log.run([A64M + "/aarch64-none-elf-gcc-ar", "rcs", lib, o])


def mrun(log, cmd, env):
    """meson through the msys shell, with the profile's PKG_CONFIG_PATH removed (its ';' list confuses msys pkg-config)."""
    log.run("unset PKG_CONFIG_PATH; " + " ".join(shlex.quote(str(c)) for c in cmd), env=env)


def strip_debug(r, log):
    """Debug sections only: the kit libraries are for linking, not for debugging them (OpenAL alone was 40 MB)."""
    for rel in provides_paths(r):
        if os.path.isfile(os.path.join(OUT, rel)):
            log.run([A64M + "/aarch64-none-elf-strip", "--strip-debug", M(os.path.join(OUT, rel))])


def meson_build(name, r, src, bld, log):
    """Meson runs as a native Windows process (venv in the cache); the compilers are native too, so every path it sees is
    a Windows path (C:/...). Only the msys2 bash wrapper around it uses msys paths."""
    cross = write_meson_cross(r.get("c_args", []), r.get("link_args", []))
    os.makedirs(bld, exist_ok=True)
    vbin = os.path.join(CACHE, "venv", "Scripts" if os.name == "nt" else "bin")
    meson = os.path.join(vbin, "meson" + EXE)
    if not os.path.isfile(meson):
        die("meson not found: run `python build.py --setup-venv` first")
    sub = os.path.join(src, r.get("subdir", "."))
    env = {"NINJA": os.path.join(vbin, "ninja" + EXE), "MSYS2_ARG_CONV_EXCL": "*"}  # keep "/nxsysroot" a posix prefix
    wipe = ["--wipe"] if os.path.exists(os.path.join(bld, "build.ninja")) else []
    mrun(log, [meson, "setup", bld, sub, "--cross-file", cross, "--prefix", "/nxsysroot", "--libdir", "lib", "--buildtype", "release",
             "--wrap-mode=nodownload"]
            + wipe + r.get("flags", []), env)
    mrun(log, [meson, "compile", "-C", bld], env)
    # the host system is "horizon" (posix rules): meson refuses a C:/ prefix, so install under /nxsysroot into a staging dir
    stage = os.path.join(CACHE, "stage", name)
    shutil.rmtree(stage, ignore_errors=True)
    mrun(log, [meson, "install", "-C", bld], dict(env, DESTDIR=stage))
    shutil.copytree(os.path.join(stage, "nxsysroot"), OUT, dirs_exist_ok=True)
    bindir = os.path.join(OUT, "bin")
    if os.path.isdir(bindir):  # aarch64 executables are useless on the host; the python/shell helper scripts stay
        for fn in os.listdir(bindir):
            with open(os.path.join(bindir, fn), "rb") as f:
                if f.read(4) == ELF_MAGIC:
                    os.remove(os.path.join(bindir, fn))
    fix_pc_prefix()


def fix_pc_prefix():
    """pkg-config files (and the *-config scripts) of the overlay get a relocatable prefix: the kit is unpacked anywhere."""
    # the overlay prefix and the windowed one (<sysroot>/windowed: libraries only windowed builds use, e.g. SDL2)
    for base, basem in ((OUT, OUTM), (OUT + "/windowed", OUTM + "/windowed")):
        d = os.path.join(base, "lib", "pkgconfig")
        for fn in (os.listdir(d) if os.path.isdir(d) else []):
            if not fn.endswith(".pc"):
                continue
            p = os.path.join(d, fn)
            with open(p, encoding="utf-8", newline="") as f:
                lines = f.read().replace("\r\n", "\n").split("\n")
            # prefix itself, then every other absolute build path (libdir=, includedir=) expressed through ${prefix}
            lines = ["prefix=${pcfiledir}/../.." if ln.startswith("prefix=") else ln.replace(basem, "${prefix}").replace(posix(base), "${prefix}")
                     for ln in lines]
            with open(p, "w", encoding="utf-8", newline="\n") as f:
                f.write("\n".join(lines))
    b = os.path.join(OUT, "bin")
    for fn in (os.listdir(b) if os.path.isdir(b) else []):
        p = os.path.join(b, fn)
        with open(p, "rb") as f:
            data = f.read()
        if data[:2] != b"#!" or OUTM.encode() not in data:
            continue
        txt = data.decode("utf-8").replace("\r\n", "\n")
        txt = txt.replace("prefix=" + OUTM, 'prefix="$(cd "$(dirname "$0")/.." && pwd)"')
        with open(p, "w", encoding="utf-8", newline="\n") as f:
            f.write(txt)


def autotools_build(name, r, src, bld, log):
    os.makedirs(bld, exist_ok=True)
    flags = " ".join(r.get("flags", []))
    env = {"CC": A64M + "/aarch64-none-elf-gcc", "AR": A64M + "/aarch64-none-elf-gcc-ar", "RANLIB": A64M + "/aarch64-none-elf-gcc-ranlib",
           "CFLAGS": common_cflags() + " -std=gnu17", "LDFLAGS": "-specs=%s/libnx/switch.specs -fPIE -L%s/lib -L%s/lib" % (DKPM, OUTM, PORTM)}
    exports = "; ".join("export %s='%s'" % (k, v) for k, v in env.items())
    steps = r.get("make", "make -j{J} && make install").replace("{J}", str(os.cpu_count() or 4)).replace("{PREFIX}", OUTM)
    log.run("%s; %s/configure --prefix=%s --libdir=%s/lib %s && %s"
            % (exports, M(os.path.join(src, r.get("subdir", "."))), OUTM, OUTM, flags, steps), cwd=bld)


def write_meson_cross(extra_c_args=(), extra_link_args=()):
    """Meson cross file for this machine: a copy of the kit's, with the devkitPro and sysroot paths filled in."""
    os.makedirs(os.path.join(CACHE, "meson"), exist_ok=True)
    out = os.path.join(CACHE, "meson", "nexvyn-switch.meson.ini")
    with open(os.path.join(TOOLCHAIN_DIR, "nexvyn-switch.meson.ini"), encoding="utf-8") as f:
        txt = f.read()
    txt = txt.replace("dkp = '/opt/devkitpro'", "dkp = '%s'" % DKP)
    if extra_c_args:  # per-recipe defines for things newlib lacks (e.g. SSIZE_MAX)
        txt = txt.replace("'-D__SWITCH__',", "'-D__SWITCH__', " + ", ".join("'%s'" % a for a in extra_c_args) + ",")
    txt = txt.replace("c = dkp / 'devkitA64/bin/aarch64-none-elf-gcc'", "c = dkp / 'devkitA64/bin/aarch64-none-elf-gcc%s'" % EXE)
    txt = txt.replace("cpp = dkp / 'devkitA64/bin/aarch64-none-elf-g++'", "cpp = dkp / 'devkitA64/bin/aarch64-none-elf-g++%s'" % EXE)
    txt = txt.replace("ar = dkp / 'devkitA64/bin/aarch64-none-elf-gcc-ar'", "ar = dkp / 'devkitA64/bin/aarch64-none-elf-gcc-ar%s'" % EXE)
    txt = txt.replace("strip = dkp / 'devkitA64/bin/aarch64-none-elf-strip'", "strip = dkp / 'devkitA64/bin/aarch64-none-elf-strip%s'" % EXE)
    # Overlay prefix first so the sysroot libraries are found; pkg-config comes from devkitPro's msys2.
    txt = txt.replace("pkg-config = dkp / 'portlibs/switch/bin/aarch64-none-elf-pkg-config'",
                      "pkg-config = dkp / 'msys2/usr/bin/pkg-config.exe'")
    txt = txt.replace("'-I' + dkp / 'portlibs/switch/include']", "'-I%s/include', '-I' + dkp / 'portlibs/switch/include']" % posix(OUT))
    txt = txt.replace("'-L' + dkp / 'portlibs/switch/lib']", "'-L%s/lib', '-L' + dkp / 'portlibs/switch/lib']" % posix(OUT))
    # msys pkg-config honours only one search directory when started from a native process, so meson gets a staging
    # dir with every .pc (the overlay's and devkitPro's), prefixes rewritten to Windows paths the native compiler reads.
    if extra_link_args:  # the recipe's helper executables (gtester ...) cannot link on the Switch and are never used
        txt = txt.replace("c_link_args = ['-specs='", "c_link_args = [" + ", ".join("'%s'" % a for a in extra_link_args) + ", '-specs='")
    pcdir = prepare_pc_dir()
    txt = txt.replace("sys_root = dkp / 'portlibs/switch'\n", "")  # pkg-config would prepend it to the Windows paths
    txt = txt.replace("[properties]\n", "[properties]\npkg_config_libdir = ['%s']\n" % M(pcdir))
    with open(out, "w", encoding="utf-8", newline="\n") as f:
        f.write(txt)
    return out


def prepare_pc_dir():
    """Staging dir of .pc files for the meson builds (see write_meson_cross). Returns its path."""
    pcdir = os.path.join(CACHE, "meson", "pc")
    shutil.rmtree(pcdir, ignore_errors=True)
    os.makedirs(pcdir)
    for src_dir, prefix in ((PORTLIBS + "/lib/pkgconfig", PORTLIBS), (OUT + "/lib/pkgconfig", OUT)):
        if not os.path.isdir(src_dir):
            continue
        for fn in os.listdir(src_dir):
            if fn.endswith(".pc"):
                with open(os.path.join(src_dir, fn), encoding="utf-8", newline="") as f:
                    lines = f.read().replace("\r\n", "\n").split("\n")
                lines = ["prefix=" + posix(prefix) if ln.startswith("prefix=") else ln for ln in lines]
                with open(os.path.join(pcdir, fn), "w", encoding="utf-8", newline="\n") as f:
                    f.write("\n".join(lines))
    return os.path.abspath(pcdir)


BUILDERS = {"cmake": cmake_build, "amalgamation": amalgamation_build, "meson": meson_build, "autotools": autotools_build}


def provides_paths(r):
    return ["lib/" + p if "/" not in p else p for p in r["provides"]]


def stamp_path(name):
    return os.path.join(OUT, ".stamps", name + ".json")


def snapshot():
    files = set()
    for d, _, fs in os.walk(OUT):
        if os.sep + ".stamps" in d + os.sep:
            continue
        for fn in fs:
            files.add(posix(os.path.relpath(os.path.join(d, fn), OUT)))
    return files


def is_built(name, r):
    p = stamp_path(name)
    if not os.path.isfile(p):
        return False
    try:
        s = json.load(open(p))
    except ValueError:
        return False
    # the stamp pins the recipe contents, not the script: touching build.py does not rebuild the world
    return s.get("version") == r["version"] and s.get("recipe") == recipe_stamp_light(name, r) and \
        all(os.path.isfile(os.path.join(OUT, f)) for f in provides_paths(r))


def recipe_stamp_light(name, r):
    h = hashlib.sha256(json.dumps({k: v for k, v in r.items() if k not in ("sha256", "license", "notes")}, sort_keys=True).encode())
    for pf in [os.path.join(PATCH_DIR, p) for p in r.get("patches", [])] + [os.path.join(HERE, e) for e in r.get("extra_sources", [])]:
        if os.path.isfile(pf):
            h.update(open(pf, "rb").read())
    for frm in r.get("copy_in", {}):
        for d, _, fs in sorted(os.walk(os.path.join(HERE, frm))):
            for fn in sorted(fs):
                h.update(open(os.path.join(d, fn), "rb").read())
    return h.hexdigest()[:16]


def build_one(name, rec, force, done, stack=()):
    if name in done:
        return
    r = rec["recipes"].get(name)
    if r is None:
        return  # a portlibs dependency
    if name in stack:
        die("dependency cycle at " + name)
    for dep in r.get("needs", []):
        build_one(dep, rec, force, done, stack + (name,))
    if not force and is_built(name, r):
        print("[%s %s] up to date" % (name, r["version"]))
        done.add(name)
        return
    print("[%s %s] building" % (name, r["version"]))
    t0 = time.time()
    if r.get("system") == "skip":
        print("  skipped: %s" % r.get("notes", ""))
        done.add(name)
        return
    log = Log(name)
    try:
        archive = fetch(name, r, rec)
        src = extract(name, archive, r)
        bld = os.path.join(CACHE, "bld", name + "-" + r["version"])
        if force:
            shutil.rmtree(bld, ignore_errors=True)
        before = snapshot()
        BUILDERS[r["system"]](name, r, src, bld, log)
        after = snapshot()
        add_shims(r, bld, log)
        strip_debug(r, log)
        fix_pc_prefix()
        for d, _, fs in os.walk(OUT + "/lib"):
            for fn in fs:
                if fn.endswith(".la"):  # libtool archives hold absolute build paths, nothing links through them
                    os.remove(os.path.join(d, fn))
        after = snapshot()
        missing = [p for p in provides_paths(r) if not os.path.isfile(os.path.join(OUT, p))]
        if missing:
            raise RuntimeError("build finished but missing: %s" % ", ".join(missing))
        os.makedirs(os.path.dirname(stamp_path(name)), exist_ok=True)
        json.dump({"version": r["version"], "recipe": recipe_stamp_light(name, r), "files": sorted(after - before),
                   "seconds": round(time.time() - t0)}, open(stamp_path(name), "w"), indent=1)
        print("  ok in %ds, log %s" % (time.time() - t0, log.path))
    except Exception as e:  # keep going with the other libraries, report at the end
        print("  FAILED: %s" % e)
        FAILED.append(name)
    finally:
        log.close()
    done.add(name)


FAILED = []


def manifest(rec):
    libs = []
    for name, r in rec["recipes"].items():
        sp = stamp_path(name)
        if not os.path.isfile(sp):
            continue
        st = json.load(open(sp))
        sizes = {p: os.path.getsize(os.path.join(OUT, p)) for p in provides_paths(r) if os.path.isfile(os.path.join(OUT, p))}
        libs.append({"lib": name, "version": r["version"], "license": r["license"], "source_sha256": r.get("sha256", ""),
                     "source_url": r["url"], "provides": sizes, "files": len(st.get("files", [])),
                     "lgpl": "LGPL" in r["license"]})
    return {"kit": "nexvyn-native-sysroot", "version": KIT_VERSION, "target": "aarch64-none-elf (devkitA64 + libnx)",
            "libraries": libs, "base": "devkitPro portlibs/switch (not included, installed with devkitPro)"}


def copy_licenses(rec):
    """licenses/<lib>/ in the sysroot: the upstream licence files of every library built (they ship with the archive)."""
    for name, r in rec["recipes"].items():
        if not os.path.isfile(stamp_path(name)):
            continue
        src = os.path.join(CACHE, "src", name + "-" + r["version"])
        dst = os.path.join(OUT, "licenses", name)
        os.makedirs(dst, exist_ok=True)
        for fn in sorted(os.listdir(src)) if os.path.isdir(src) else []:
            low = fn.lower()
            if os.path.isfile(os.path.join(src, fn)) and low.startswith(("license", "licence", "copying", "copyright", "unlicense")):
                shutil.copy2(os.path.join(src, fn), os.path.join(dst, fn))


def package(rec):
    copy_licenses(rec)
    man = manifest(rec)
    json.dump(man, open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8", newline="\n"), indent=2)
    base = os.path.join(ROOT, "build", "nexvyn-native-sysroot-%s" % KIT_VERSION)
    skip_top = {".stamps", "logs"}

    def norm(ti):  # same input, same bytes: no owner, no timestamps
        ti.uid = ti.gid = 0
        ti.uname = ti.gname = ""
        ti.mtime = 0
        return ti

    entries = []
    for d, dirs, fs in os.walk(OUT):
        dirs.sort()
        rel_d = os.path.relpath(d, OUT)
        if rel_d.split(os.sep)[0] in skip_top:
            dirs[:] = []
            continue
        for fn in sorted(fs):
            if not fn.endswith(".la"):
                entries.append(os.path.normpath(os.path.join(rel_d, fn)))
    tmp_tar = base + ".tar"
    with tarfile.open(tmp_tar, "w") as t:
        for rel in entries:
            t.add(os.path.join(OUT, rel), arcname="nexvyn-native-sysroot/" + posix(rel), filter=norm)
    zstd_exe = DKP + "/msys2/usr/bin/zstd.exe"
    if os.path.isfile(zstd_exe):
        arc = base + ".tar.zst"
        subprocess.run([zstd_exe, "-19", "--long=27", "-T0", "-f", "-q", tmp_tar, "-o", arc], check=True)
    else:  # no zstd on this machine: a zip does the same job
        arc = base + ".zip"
        with zipfile.ZipFile(arc, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
            for rel in entries:
                z.write(os.path.join(OUT, rel), "nexvyn-native-sysroot/" + posix(rel))
    os.remove(tmp_tar)
    man["archive"] = {"file": os.path.basename(arc), "bytes": os.path.getsize(arc), "sha256": sha256_file(arc)}
    json.dump(man, open(base + ".manifest.json", "w", encoding="utf-8", newline="\n"), indent=2)
    print("archive %s (%d KiB), %d files\nmanifest %s" % (arc, os.path.getsize(arc) // 1024, len(entries), base + ".manifest.json"))
    return arc


def build_test():
    """Build tests/sysroot_test (CMake + the kit toolchain) into the cache; prints the .nro path."""
    src = os.path.join(HERE, "tests", "sysroot_test")
    bld = os.path.join(CACHE, "bld", "sysroot_test")
    log = Log("sysroot_test")
    try:
        log.run(["cmake", "-S", M(src), "-B", M(bld), "-G", "Ninja", "-DCMAKE_TOOLCHAIN_FILE=" + M(CMAKE_TC),
                 "-DCMAKE_BUILD_TYPE=Release", "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"]
                + (["-DNEXVYN_COMPAT_DIR=" + M(os.environ["NEXVYN_COMPAT_DIR"])] if os.environ.get("NEXVYN_COMPAT_DIR") else []))
        log.run(["cmake", "--build", M(bld)])
    except RuntimeError as e:
        print("FAILED: %s" % e)
        return None
    finally:
        log.close()
    nro = os.path.join(bld, "sysroot_test.nro")
    print("test nro: %s (%d KiB)" % (nro, os.path.getsize(nro) // 1024))
    return nro


def setup_venv():
    """Local venv in the cache with meson (the host may not have it)."""
    v = os.path.join(CACHE, "venv")
    if not os.path.isdir(v):
        subprocess.run([sys.executable, "-m", "venv", v], check=True)
    py = os.path.join(v, "Scripts" if os.name == "nt" else "bin", "python" + EXE)
    subprocess.run([py, "-m", "pip", "install", "-q", "meson", "ninja"], check=True)
    print("meson venv ready in " + v)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("libs", nargs="*", help="library names, or `package`")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--fetch-only", action="store_true")
    ap.add_argument("--setup-venv", action="store_true")
    a = ap.parse_args()
    rec = load_recipes()
    if a.setup_venv:
        setup_venv()
        return 0
    if a.list:
        for n, r in rec["recipes"].items():
            print("%-12s %-9s %-10s %s" % (n, r["version"], "built" if os.path.isfile(stamp_path(n)) else "-", r["license"][:50]))
        return 0
    os.makedirs(OUT, exist_ok=True)
    if "test" in a.libs:
        return 0 if build_test() else 1
    want_pkg = "package" in a.libs
    names = [n for n in a.libs if n != "package"] or list(rec["recipes"])
    if a.fetch_only:
        for n in names:
            r = rec["recipes"][n]
            if r.get("system") != "skip":
                fetch(n, r, rec)
        return 0
    done = set()
    for n in names:
        if n not in rec["recipes"]:
            die("unknown library %s (known: %s)" % (n, ", ".join(rec["recipes"])))
        build_one(n, rec, a.force, done)
    if want_pkg:
        package(rec)
    if FAILED:
        print("FAILED: " + ", ".join(FAILED))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
