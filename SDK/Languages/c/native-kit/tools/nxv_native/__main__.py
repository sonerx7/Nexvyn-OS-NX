"""nxv-native: command line for the Nexvyn native SDK (C/C++ apps that run inside Nexvyn OS, in a window or full screen).

  python tools/nxv_native new <name> [--template app|game|port|sdl2|gl|vulkan|emu-skeleton|decomp-skeleton|shared-lib] [--dir DIR]
  python tools/nxv_native build [DIR] [--debug] [--clean] [--sysroot PATH]
  python tools/nxv_native lib [DIR] [--debug] [--clean] [--sysroot PATH]   (a project with only nexvyn_add_lib())
  python tools/nxv_native check-lib FILE.nxvlib [--host APP.elf]
  python tools/nxv_native exports FILE.nxvlib... -o imports.ld             (Makefile projects: EXTERN for the app)
  python tools/nxv_native package [DIR] [-o FILE] [--sign key.pem]    (-> build/<name>.nxvapp)
  python tools/nxv_native run [DIR] [--sd SDCARD_ROOT]  (copies into <sd>/NexvynOS/Applications, never starts anything)
  python tools/nxv_native check-win FILE.nxvmod   (identity, no TLS / text relocations, every import in the host set)
  python tools/nxv_native shader FILE --target vulkan -o FILE.spv
  python tools/nxv_native shader FILE --target gl
  python tools/nxv_native clang-build NAME SOURCE... --llvm DIR [--std 17|20|23]
  python tools/nxv_native check-design [DIR]      (the OS design rules of an ImGui app: frame layer, nxn_os_* widgets,
                                                   no FontGlobalScale / own fonts / pixel literals; `package` runs it too)

The app is a .nxvmod that runs in Nexvyn OS's process: app.json "mode" is "window" (default) or "fullscreen". The same
build serves both; the user can switch while it runs.
  python tools/nxv_native doctor

No dependencies beyond Python 3 and devkitPro. Works from any shell: on Windows the build runs inside devkitPro's
msys2 shell (like build.sh), elsewhere it expects the devkitPro environment (DEVKITPRO) to be set.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", ".."))
KIT = os.path.join(REPO, "sdk", "native")
TEMPLATES = os.path.join(KIT, "templates")
TEMPLATE_NAMES = ("app", "game", "port", "sdl2", "gl", "vulkan", "emu-skeleton", "decomp-skeleton", "shared-lib")
DKP_BASH = os.environ.get("DKP_BASH", "C:/devkitPro/msys2/usr/bin/bash.exe")
sys.path.insert(0, os.path.join(REPO, "tools"))
import sdkinfo  # noqa: E402  (the SDK facts: Native SDK version and the SDK that brought it)

NATIVE_VERSION = sdkinfo.NATIVE_VERSION
NATIVE_MIN_SDK = sdkinfo.NATIVE_MIN_SDK


def die(msg, code=1):
    print("error: " + msg, file=sys.stderr)
    sys.exit(code)


def valid_name(name):
    return re.fullmatch(r"[a-z][a-z0-9_\-]{0,40}", name) is not None


def msys_path(p):
    """C:\\a\\b -> /c/a/b for the msys2 shell."""
    p = os.path.abspath(p).replace("\\", "/")
    m = re.match(r"^([A-Za-z]):/(.*)$", p)
    return "/%s/%s" % (m.group(1).lower(), m.group(2)) if m else p


def sh_quote(p):
    return "'" + p.replace("'", "'\\''") + "'"


def run_dkp(script, cwd=None):
    """Runs a shell script with the devkitPro environment; returns the exit code."""
    if os.path.isfile(DKP_BASH):
        full = "export DEVKITPRO=/opt/devkitpro; export PATH=/opt/devkitpro/tools/bin:/opt/devkitpro/devkitA64/bin:$PATH; " + script
        return subprocess.call([DKP_BASH, "-lc", full], cwd=cwd)
    if not os.environ.get("DEVKITPRO"):
        die("devkitPro not found (set DEVKITPRO or DKP_BASH); see docs/NATIVE_KIT.md")
    return subprocess.call(["sh", "-c", script], cwd=cwd)


def project_dir(arg):
    d = os.path.abspath(arg or ".")
    if not os.path.isfile(os.path.join(d, "CMakeLists.txt")):
        die("no CMakeLists.txt in " + d)
    return d


def project_name(d):
    """The project() name of CMakeLists.txt = the nro name."""
    with open(os.path.join(d, "CMakeLists.txt"), encoding="utf-8") as f:
        m = re.search(r"^\s*project\(\s*([A-Za-z0-9_\-]+)", f.read(), re.M | re.I)
    if not m:
        die("project(<name> ...) not found in CMakeLists.txt")
    return m.group(1)


def make_png(size=256):
    """A plain 256x256 gradient icon (PNG, pure Python) so a new project packs without extra files."""
    rows = bytearray()
    for y in range(size):
        rows.append(0)
        for x in range(size):
            rows += bytes((30 + x // 4, 40 + y // 5, 110 + (x + y) // 8))
    def chunk(t, data):
        c = struct.pack(">I", len(data)) + t + data
        return c + struct.pack(">I", zlib.crc32(t + data) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b""))


def cmd_new(a):
    if not valid_name(a.name):
        die("name must be lower case letters, digits, '-' or '_' and start with a letter")
    src = os.path.join(TEMPLATES, a.template)
    if not os.path.isdir(src):
        die("template not found: " + src)
    dst = os.path.abspath(os.path.join(a.dir or ".", a.name))
    if os.path.exists(dst):
        die(dst + " already exists")
    title = a.name.replace("-", " ").replace("_", " ").title()
    for root, _dirs, files in os.walk(src):
        rel = os.path.relpath(root, src)
        os.makedirs(os.path.join(dst, rel), exist_ok=True)
        for fn in files:
            if fn == "template.json" and rel == ".":  # the template's app.json overrides, not a project file
                continue
            with open(os.path.join(root, fn), encoding="utf-8") as f:
                text = f.read().replace("@NAME@", a.name).replace("@TITLE@", title)
            with open(os.path.join(dst, rel, fn), "w", encoding="utf-8", newline="\n") as f:
                f.write(text)
    app = {"id": "com.example." + a.name.replace("_", "-"), "name": title, "version": "1.0.0", "author": "Unknown",
           "category": "games", "runtime": "native", "mode": "window", "main": a.name + ".nxvmod",
           "minNative": NATIVE_VERSION, "targetNative": NATIVE_VERSION, "icon": "icon.png", "permissions": ["files"], "minSdk": NATIVE_MIN_SDK, "targetSdk": NATIVE_MIN_SDK}
    over = os.path.join(src, "template.json")
    if os.path.isfile(over):
        with open(over, encoding="utf-8") as f:
            app.update(json.load(f))
    extra_ignore = app.pop("_gitignore", [])
    with open(os.path.join(dst, "app.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(app, f, indent=2)
        f.write("\n")
    with open(os.path.join(dst, "icon.png"), "wb") as f:
        f.write(make_png())
    with open(os.path.join(dst, ".gitignore"), "w", newline="\n") as f:
        f.write("build/\n" + "".join(line + "\n" for line in extra_ignore))
    if app.get("type", "app") not in ("lib", "runtime"):
        locale_dir = os.path.join(dst, "lang")
        os.makedirs(locale_dir, exist_ok=True)
        for locale in os.listdir(os.path.join(TEMPLATES, "app", "lang")):
            target = os.path.join(locale_dir, locale)
            if locale.endswith(".json") and not os.path.exists(target):
                with open(os.path.join(TEMPLATES, "app", "lang", locale), encoding="utf-8") as f:
                    content = f.read().replace("@TITLE@", title)
                with open(target, "w", encoding="utf-8") as f:
                    f.write(content)
    print("created %s (template %s)\nnext: python tools/nxv_native build %s" % (dst, a.template, dst))


# ------------------------------------------------------------------ shared libraries (.nxvlib)
def lib_abi_gen():
    """NXN_LIB_ABI_GEN of the kit's header (sdk/native/include/nexvyn/nxn_lib.h)."""
    with open(os.path.join(KIT, "include", "nexvyn", "nxn_lib.h"), encoding="utf-8") as f:
        return re.search(r'#define\s+NXN_LIB_ABI_GEN\s+"([^"]+)"', f.read()).group(1)


def elf_info(path):
    """Program header types, dynamic tags and named sections of an ELF64 little-endian file (None if not one)."""
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 64 or data[:4] != b"\x7fELF" or data[4] != 2 or data[5] != 1:
        return None
    etype, machine = struct.unpack_from("<HH", data, 16)
    phoff, shoff = struct.unpack_from("<QQ", data, 32)
    phentsize, phnum, shentsize, shnum, shstrndx = struct.unpack_from("<HHHHH", data, 54)
    phdrs = [struct.unpack_from("<IIQQQQQQ", data, phoff + i * phentsize) for i in range(phnum)]
    dyn = []
    for p in phdrs:
        if p[0] == 2:  # PT_DYNAMIC
            for off in range(p[2], p[2] + p[5], 16):
                tag, val = struct.unpack_from("<qQ", data, off)
                if tag == 0:
                    break
                dyn.append((tag, val))
    sections = {}
    if shoff and shnum and shstrndx < shnum:
        shdrs = [struct.unpack_from("<IIQQQQIIQQ", data, shoff + i * shentsize) for i in range(shnum)]
        names = shdrs[shstrndx]
        for sh in shdrs:
            start = names[4] + sh[0]
            name = data[start:data.index(b"\0", start)].decode("ascii", "replace")
            sections[name] = data[sh[4]:sh[4] + sh[5]] if sh[1] != 8 else b""  # SHT_NOBITS has no bytes
    return {"type": etype, "machine": machine, "phdrs": [p[0] for p in phdrs], "dyn": dyn, "sections": sections}


def tls_problem(path, name, info):
    """thread_local of a windowed module or library (W2a): None when fine. Nexvyn OS serves general-dynamic TLS
    (__tls_get_addr, R_AARCH64_TLS_DTPMOD64 / DTPREL64; compile with -mtls-dialect=trad, the kit does). The default
    TLSDESC dialect with -mtp=soft is miscompiled by devkitA64's gcc, so TLSDESC / TPREL relocations, or a PT_TLS
    without any DTPMOD64, are refused."""
    if 7 not in info["phdrs"]:  # PT_TLS
        return None
    sys.path.insert(0, os.path.join(REPO, "tools"))
    import nxwin_imports  # noqa: E402 (where the toolchain is)
    nm = nxwin_imports.NM
    readelf = os.path.join(os.path.dirname(nm), os.path.basename(nm).replace("-nm", "-readelf"))
    try:
        out = subprocess.run([readelf, "-rW", path], capture_output=True, text=True).stdout
    except OSError:
        return None  # no readelf: Nexvyn OS checks the same when it loads the file
    if "R_AARCH64_TLSDESC" in out or "R_AARCH64_TLS_TPREL" in out or "R_AARCH64_TLS_DTPMOD64" not in out:
        return ("%s: thread_local code built for another TLS model: compile every object with -mtls-dialect=trad "
                "(nexvyn_add_windowed / nexvyn_add_lib do)" % name)
    return None


def check_lib(path, host=None):
    """Problems of a .nxvlib (empty list: fine). host: the app's .elf, whose exports must cover the library's imports."""
    info = elf_info(path)
    name = os.path.basename(path)
    if not info or info["machine"] != 183 or info["type"] != 3:
        return ["%s: not an AArch64 shared object" % name]
    problems = []
    tags = dict(info["dyn"])
    if 22 in tags or tags.get(30, 0) & 4:  # DT_TEXTREL, DT_FLAGS & DF_TEXTREL
        problems.append("%s: text relocations (compile every object with -fPIC)" % name)
    tls = tls_problem(path, name, info)  # PT_TLS: windowed apps with native.windowedTls on (W2a)
    if tls:
        problems.append(tls)
    if 4 not in tags:  # DT_HASH
        problems.append("%s: no SysV hash table (link with -Wl,--hash-style=sysv)" % name)
    ident = info["sections"].get(".nxvlib", b"").split(b"\0")[0].decode("utf-8", "replace")
    fields = dict(f.split("=", 1) for f in ident.split(";")[1:] if "=" in f) if ident.startswith("nxvlib;") else {}
    if not fields.get("name") or not fields.get("version"):
        problems.append("%s: no .nxvlib identity (build it with nexvyn_add_lib() / nxv-native lib)" % name)
    elif fields.get("abi") != lib_abi_gen():
        problems.append("%s: library ABI generation %s, this kit has %s" % (name, fields.get("abi"), lib_abi_gen()))
    if host and not problems:
        import build_modules  # noqa: E402 (tools/: the ELF symbol rules shared with the OS modules)
        have = set(build_modules.exported(build_modules.dynsyms(host)))
        strong, _weak, _shared = build_modules.imports(path)
        missing = [n for n in strong if n not in have]
        if missing:
            problems.append("%s imports symbols %s does not export: %s (nexvyn_export_symbols(<app> LIBS ...))"
                            % (name, os.path.basename(host), ", ".join(missing[:8]) + (" ..." if len(missing) > 8 else "")))
    return problems


def check_built_libs(d, require=False):
    """Checks every build/*.nxvlib of a project (and the app's exports when the app is there too)."""
    bdir = os.path.join(d, "build")
    libs = sorted(os.path.join(bdir, f) for f in os.listdir(bdir) if f.endswith(".nxvlib")) if os.path.isdir(bdir) else []
    if require and not libs:
        die("no .nxvlib in %s (did you call nexvyn_add_lib()?)" % bdir)
    elf = os.path.join(bdir, project_name(d) + ".elf")
    problems = []
    for lib in libs:
        problems += check_lib(lib, elf if os.path.isfile(elf) else None)
    if problems:
        die("\n  ".join(["shared library check failed:"] + problems))
    for lib in libs:
        print("built %s (%d bytes, checked)" % (lib, os.path.getsize(lib)))
    return libs


def cmd_check_lib(a):
    problems = check_lib(a.file, a.host)
    if problems:
        die("\n  ".join(problems))
    print("%s: ok" % a.file)


def cmd_exports(a):
    import build_modules  # noqa: E402
    names = set()
    for f in a.files:
        strong, _weak, _shared = build_modules.imports(f)
        names.update(strong)
    text = "/* generated by nxv-native exports - the symbols the app's shared libraries import */\n"
    if names:
        text += "EXTERN(\n" + "".join("  %s\n" % n for n in sorted(names)) + ")\n"
    with open(a.output, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("%s: %d imported symbols (link it into the app with -Wl,--export-dynamic -Wl,--hash-style=sysv)" % (a.output, len(names)))


VK_RESOLVER_SYM = "nxn_vk_proc"


def vk_shim_names():
    """Generated Vulkan link-time shim names (sdk/native/lib/win/nxwin_vk.txt)."""
    path = os.path.join(KIT, "lib", "win", "nxwin_vk.txt")
    if not os.path.isfile(path):
        return set()
    names = set()
    with open(path, encoding="utf-8") as f:
        for line in f:
            s = line.split("#", 1)[0].strip()
            if s:
                names.add(s)
    return names


def check_win(path):
    """Problems of a windowed app module (empty list: fine): ELF, identity, TLS / text relocations, imports."""
    info = elf_info(path)
    name = os.path.basename(path)
    if not info or info["machine"] != 183 or info["type"] != 3:
        return ["%s: not an AArch64 shared object" % name]
    problems = []
    tags = dict(info["dyn"])
    if 22 in tags or tags.get(30, 0) & 4:
        problems.append("%s: text relocations (compile every object with -fPIC)" % name)
    tls = tls_problem(path, name, info)  # PT_TLS: Nexvyn OS with native.windowedTls on (W2a)
    if tls:
        problems.append(tls)
    ident = info["sections"].get(".nxnwin", b"").split(b"\0")[0].decode("utf-8", "replace")
    if not ident.startswith("nxnwin;"):
        problems.append("%s: no .nxnwin identity (link libnexvyn_window.a: nexvyn_add_windowed / make windowed)" % name)
    sys.path.insert(0, os.path.join(REPO, "tools"))
    import nxwin_imports  # noqa: E402 (the host import set of Nexvyn OS)
    have = nxwin_imports.all_names(nxwin_imports.read_list())
    missing = [n for n in nxwin_imports.nm_undefined(path) if n not in have or n == VK_RESOLVER_SYM]
    if missing:
        vk_names = vk_shim_names()
        vk_res = [n for n in missing if n == VK_RESOLVER_SYM]
        vk_syms = [n for n in missing if n in vk_names]
        other = [n for n in missing if n not in vk_names and n != VK_RESOLVER_SYM]
        if vk_res:
            problems.append("%s imports %s as a strong symbol (must be weak/optional so apps fail cleanly on an OS without Vulkan)" %
                            (name, VK_RESOLVER_SYM))
        if vk_syms:
            problems.append("%s leaves generated Vulkan shim entry point(s) unresolved (%s): link libnexvyn_window.a with NEXVYN_VK_SHIMS=1 or load via volk" %
                            (name, ", ".join(vk_syms)))
        if other:
            problems.append("%s imports what Nexvyn OS does not offer to windowed apps: %s" %
                            (name, ", ".join(other)))  # the whole list: a port misses dozens, one pass should name them all
    return problems


def cmd_check_win(a):
    problems = check_win(a.file)
    if problems:
        die("\n  ".join(problems))
    print("%s: ok" % a.file)


def native_sysroot(explicit=None):
    sysroot = explicit or os.environ.get("NEXVYN_SYSROOT")
    default = os.path.join(REPO, "build", "native-sysroot")
    return sysroot or (default if os.path.isdir(default) else "")


def configure_and_build(a, d):
    bdir = os.path.join(d, "build")
    if a.clean and os.path.isdir(bdir):
        shutil.rmtree(bdir)
    sysroot = native_sysroot(a.sysroot)
    windowed = getattr(a, "windowed", False)
    vk_shims = windowed and os.environ.get("NEXVYN_VK_SHIMS") == "1"
    if vk_shims and not os.path.isfile(os.path.join(sysroot, "include", "vulkan", "vulkan_core.h")):
        die("Vulkan shims need Vulkan headers: build the vulkan-headers sysroot recipe or pass --sysroot")
    if windowed and uses_sdl(d) and not os.path.isdir(os.path.join(sysroot or "-", "windowed")):
        die("this project includes SDL: a windowed build needs the SDL2 of the kit (<sysroot>/windowed). Build it with "
            "`python sdk/native/sysroot/build.py sdl2-nexvyn` or pass --sysroot of a kit that has it.")
    cfg = ("cmake -S %s -B %s -G Ninja -DCMAKE_TOOLCHAIN_FILE=%s -DNEXVYN_KIT=%s -DCMAKE_BUILD_TYPE=%s -DNEXVYN_ABI=%s"
           % (sh_quote(msys_path(d)), sh_quote(msys_path(bdir)),
              sh_quote(msys_path(os.path.join(KIT, "toolchain", "nexvyn-switch.cmake"))),
              sh_quote(msys_path(KIT)), "Debug" if a.debug else "Release",
              "ON" if a.abi or windowed else "OFF"))
    cfg += " -DNEXVYN_WINDOWED=" + ("ON" if windowed else "OFF")  # explicit: the cache keeps old values
    cfg += " -DNEXVYN_VK_SHIMS=" + ("1" if vk_shims else "0")
    if sysroot:
        cfg += " -DNEXVYN_SYSROOT=" + sh_quote(msys_path(sysroot))
    # Ninja when the shell has it, plain make otherwise
    # the kit's own libraries (libnexvyn_native.a, libnexvyn_window.a) are build output: make them when they are missing
    klib = sh_quote(msys_path(os.path.join(KIT, "lib")))
    script = (f"[ -f {klib}/libnexvyn_native.a ] && [ -f {klib}/libnexvyn_window.a ] || "
              f"make -s -C {klib} NEXVYN_VK_SHIMS=0 || exit 1; ")
    if vk_shims:
        script += (f"make -s -C {klib} window NEXVYN_VK_SHIMS=1 "
                   f"NEXVYN_SYSROOT={sh_quote(msys_path(sysroot))} || exit 1; ")
    else:
        script += (f"[ ! -f {klib}/build/win/.vk-shims-1 ] || "
                   f"make -s -C {klib} window NEXVYN_VK_SHIMS=0 || exit 1; ")
    script += ("GEN=Ninja; command -v ninja >/dev/null 2>&1 || GEN='Unix Makefiles'; "
              + cfg.replace("-G Ninja", '-G "$GEN"') + " && cmake --build " + sh_quote(msys_path(bdir)) + " -j 8")
    rc = run_dkp(script)
    if rc:
        die("build failed", rc)


def uses_sdl(d):
    """True when the project's sources include SDL (the SDL2 driver for windows comes with W1, docs/reference/plans/NATIVE_SDK_PLANI.md)."""
    for root, _dirs, files in os.walk(os.path.join(d, "src")):
        for fn in files:
            if fn.endswith((".c", ".cc", ".cpp", ".h", ".hpp")):
                with open(os.path.join(root, fn), encoding="utf-8", errors="replace") as f:
                    if re.search(r'#\s*include\s*[<"]SDL', f.read()):
                        return True
    return False


def cmd_build(a):
    d = project_dir(a.dir)
    configure_and_build(a, d)
    if a.windowed:
        mod = os.path.join(d, "build", project_name(d) + ".nxvmod")
        if not os.path.isfile(mod):
            die("build finished but %s is missing (did you call nexvyn_add_nro() or nexvyn_add_windowed()?)" % mod)
        problems = check_win(mod)
        if problems:
            die("\n  ".join(["windowed app check failed:"] + problems))
        print("built %s (%d bytes, checked)" % (mod, os.path.getsize(mod)))
        return
    nro = os.path.join(d, "build", project_name(d) + ".nro")
    if not os.path.isfile(nro):
        die("build finished but %s is missing (did you call nexvyn_add_nro()?)" % nro)
    check_built_libs(d)
    print("built %s (%d bytes)" % (nro, os.path.getsize(nro)))


def cmd_lib(a):
    d = project_dir(a.dir)
    a.abi = False
    configure_and_build(a, d)
    check_built_libs(d, require=True)


def elf_build_id(path):
    """Hex GNU build-id of an ELF64 file (section .note.gnu.build-id; a split .debug file keeps it), or ''."""
    try:
        with open(path, "rb") as f:
            d = f.read()
        if d[:4] != b"\x7fELF" or d[4] != 2:
            return ""
        shoff, = struct.unpack_from("<Q", d, 40)
        shentsize, shnum, shstrndx = struct.unpack_from("<HHH", d, 58)
        sh = [struct.unpack_from("<IIQQQQIIQQ", d, shoff + i * shentsize) for i in range(shnum)]
        strtab = sh[shstrndx]
        for name, typ, _fl, _ad, off, size, *_rest in sh:
            nm = d[strtab[4] + name:d.index(b"\0", strtab[4] + name)]
            if nm == b".note.gnu.build-id":
                nsz, dsz, _nt = struct.unpack_from("<III", d, off)
                start = off + 12 + ((nsz + 3) & ~3)
                return d[start:start + dsz].hex()
    except (OSError, struct.error, ValueError, IndexError):
        pass
    return ""


def find_addr2line():
    for cand in (shutil.which("aarch64-none-elf-addr2line"),
                 os.path.join(os.environ.get("DEVKITPRO", ""), "devkitA64", "bin", "aarch64-none-elf-addr2line"),
                 "C:/devkitPro/devkitA64/bin/aarch64-none-elf-addr2line"):
        if cand and (os.path.isfile(cand) or os.path.isfile(cand + ".exe")):
            return cand
    die("aarch64-none-elf-addr2line not found (install devkitPro or put devkitA64/bin on PATH)")


def cmd_symbolize(a):
    """Crash report -> function:line for every module-relative address (pc, lr, backtrace)."""
    with open(a.report, encoding="utf-8", errors="replace") as f:
        text = f.read().split("--- last log lines ---")[0]  # the log tail repeats the crash line, cut short
    ids = {}   # module name -> build-id the report names
    for m in re.finditer(r"^module (\S+): base \w+, size \w+, build-id (\w+)", text, re.M):
        ids[m.group(1)] = "" if m.group(2) == "none" else m.group(2)
    # the addresses, in the order the report shows them: "name+0x1234"
    seen, addrs = set(), []
    for m in re.finditer(r"\b([A-Za-z0-9_.\-]+)\+0x([0-9a-f]+)\b", text):
        key = (m.group(1), int(m.group(2), 16))
        if (m.group(1) in ids or (not ids and m.group(1) != "os")) and key not in seen:
            seen.add(key)
            addrs.append(key)
    if not addrs:
        die("no module-relative addresses (name+0x...) in the report: it comes from a Nexvyn OS without backtrace support")
    cands = list(a.elf or [])
    if not cands:  # the project's build folder: <dir>/build/*.debug, *.nxvmod, *.nxvlib
        for root in (os.getcwd(), os.path.dirname(os.path.abspath(a.report))):
            for sub in ("build", "."):
                bd = os.path.join(root, sub)
                if os.path.isdir(bd):
                    cands += [os.path.join(bd, n) for n in sorted(os.listdir(bd)) if n.endswith((".debug", ".nxvmod", ".nxvlib", ".elf"))]
    by_id = {}
    for c in cands:
        bid = elf_build_id(c)
        if bid and (c.endswith(".debug") or bid not in by_id):
            by_id[bid] = c
    tool = find_addr2line()
    printed = False
    for name in sorted({n for n, _ in addrs}, key=lambda n: [x[0] for x in addrs].index(n)):
        bid = ids.get(name, "")
        elf = by_id.get(bid) if bid else None
        if not elf and a.elf and len(a.elf) == 1 and name == "app":
            elf = a.elf[0]
            if bid and elf_build_id(elf) != bid:
                print("warning: %s has build-id %s, the report says %s: lines may be wrong" % (elf, elf_build_id(elf) or "none", bid))
        if not elf:
            print("%s: no debug ELF with build-id %s found (pass --elf <file.nxvmod.debug>)" % (name, bid or "?"))
            continue
        offs = ["0x%x" % o for n, o in addrs if n == name]
        out = subprocess.run([tool, "-f", "-C", "-p", "-e", elf] + offs, capture_output=True, text=True)
        if out.returncode:
            die("addr2line failed: " + out.stderr.strip())
        for o, line in zip(offs, out.stdout.splitlines()):
            print("%s+%s  %s" % (name, o, line))
            printed = True
    if not printed:
        sys.exit(1)


def stage_bundle(d, windowed=False):
    name = project_name(d)
    nro = os.path.join(d, "build", name + (".nxvmod" if windowed else ".nro"))
    if not os.path.isfile(nro):
        die(nro + " not found: run `build` first")
    app_path = os.path.join(d, "app.json")
    if not os.path.isfile(app_path):
        die("app.json not found in " + d)
    with open(app_path, encoding="utf-8") as f:
        app = json.load(f)
    # fixed by the build; "fullscreen" is the developer's choice, anything else is a window
    app["runtime"] = "native"
    app["mode"] = "fullscreen" if windowed and app.get("mode") == "fullscreen" else ("window" if windowed else "exclusive")
    app["main"] = name + (".nxvmod" if windowed else ".nro")
    app.setdefault("minNative", NATIVE_VERSION)
    # older Nexvyn OS builds would read the .nro as a Lua script: the SDK gate makes them say "needs a newer Nexvyn OS"
    if sdkinfo.cmp_versions(sdkinfo.version_field(app.get("minSdk")) or "1.0", NATIVE_MIN_SDK) < 0:
        app["minSdk"] = NATIVE_MIN_SDK
    stage = os.path.join(d, "build", "bundle", name + ".nxvapp")
    if os.path.isdir(stage):
        shutil.rmtree(stage)
    os.makedirs(stage)
    shutil.copy2(nro, os.path.join(stage, app["main"]))
    icon = app.get("icon", "icon.png")
    if os.path.isfile(os.path.join(d, icon)):
        shutil.copy2(os.path.join(d, icon), os.path.join(stage, icon))
    # shared libraries built with the app ship next to the nro, where nxn_lib_open("<name>") looks first
    for lib in check_built_libs(d):  # windowed apps open them too (W2a, setting native.windowedLibs)
        shutil.copy2(lib, os.path.join(stage, os.path.basename(lib)))
    for extra in ("data", "romfs", "lang"):   # optional asset folders ship next to the nro (lang/<code>.json: nxn_tr)
        if os.path.isdir(os.path.join(d, extra)):
            shutil.copytree(os.path.join(d, extra), os.path.join(stage, extra))
    with open(os.path.join(stage, "app.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(app, f, indent=2)
        f.write("\n")
    return stage, app


def design_findings(d):
    """tools/design_check.py on the project's sources: [(severity, message)] ([] when the checker is not in the kit)."""
    try:
        import design_check  # noqa: E402  (tools/design_check.py)
    except ImportError:
        return []
    return design_check.check_folder(d)


def cmd_check_design(a):
    d = project_dir(a.dir)
    found = design_findings(d)
    for sev, msg in found:
        print("%-4s %s" % (sev, msg))
    fails = sum(1 for sev, _ in found if sev == "FAIL")
    print("design: %s (%d FAIL, %d WARN)" % ("FAIL" if fails else "ok", fails, len(found) - fails))
    return 1 if fails else 0


def cmd_package(a):
    d = project_dir(a.dir)
    with open(os.path.join(d, "app.json"), encoding="utf-8") as manifest_file:
        authoring_manifest = json.load(manifest_file)
    if authoring_manifest.get("vulkan") is True:
        if not a.windowed:
            die("the Vulkan manifest flag requires a windowed or fullscreen native module")
        mod = os.path.join(d, "build", project_name(d) + ".nxvmod")
        if not os.path.isfile(mod):
            die(mod + " not found: run `build --windowed` first")
        problems = check_win(mod)
        if problems:
            die("\n  ".join(problems))
    if authoring_manifest.get("type", "app") in ("app", "game"):
        from nxv_i18n import check_app_locales
        ok, locale_errors = check_app_locales(d)
        if not ok:
            die("eight complete locales required before packaging: " + "; ".join(locale_errors))
    found = [m for sev, m in design_findings(d) if sev == "FAIL"]
    if found:  # reported, not blocking: `check-design` (and `nxv check`) fail on it
        print("design: %d problem(s) with the OS design rules, fix them before publishing (nxv-native check-design):"
              % len(found))
        for m in found[:8]:
            print("  " + m)
    stage, app = stage_bundle(d, a.windowed)
    import nxvapp_pack  # noqa: E402
    out = os.path.abspath(a.output or os.path.join(d, "build", project_name(d) + ".nxvapp"))
    argv = [stage, "-o", out] + (["--sign", a.sign] if a.sign else [])
    old = sys.argv
    sys.argv = ["nxvapp_pack.py"] + argv
    try:
        nxvapp_pack.main()
    finally:
        sys.argv = old
    print("packed " + out)
    mod = os.path.join(d, "build", project_name(d) + (".nxvmod" if a.windowed else ".nro"))
    bid = elf_build_id(mod) if a.windowed else ""
    if bid:
        dbg = mod + ".debug"
        print("build-id %s (crash reports name it; keep %s: `nxv-native symbolize <report>` uses it)"
              % (bid, os.path.basename(dbg) if os.path.isfile(dbg) else "the unstripped build"))


def cmd_run(a):
    d = project_dir(a.dir)
    stage, app = stage_bundle(d, a.windowed)
    sd = a.sd or os.environ.get("NEXVYN_SD")
    if not sd:
        try:
            import ryu_env  # optional private development environment, not part of the public kit
            sd = ryu_env.SDROOT
        except ModuleNotFoundError as error:
            if error.name != "ryu_env":
                raise
            die("pass --sd with the SD card root, or set NEXVYN_SD")
    if not os.path.isdir(sd):
        die("SD card folder not found: %s (pass --sd)" % sd)
    dest = os.path.join(sd, "NexvynOS", "Applications", os.path.basename(stage))
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    shutil.copytree(stage, dest)
    print("copied to %s\nstart Nexvyn yourself; nothing was launched." % dest)


def cmd_doctor(a):
    ok = True
    def line(label, good, detail=""):
        nonlocal ok
        ok = ok and good
        print("%-22s %s %s" % (label, "ok     " if good else "MISSING", detail))
    line("devkitPro shell", os.path.isfile(DKP_BASH) or bool(os.environ.get("DEVKITPRO")), DKP_BASH)
    rc = subprocess.call(["python", os.path.join(REPO, "tools", "toolchain_check.py")]) if os.path.isfile(
        os.path.join(REPO, "tools", "toolchain_check.py")) else 0
    line("toolchain versions", rc == 0, "(tools/toolchain_check.py)")
    line("kit", os.path.isfile(os.path.join(KIT, "toolchain", "nexvyn-switch.cmake")), KIT)
    has_abi = os.path.isfile(os.path.join(KIT, "include", "nexvyn", "nexvyn_native.h"))
    print("%-22s %s (optional until the ABI kit exists)" % ("Nexvyn ABI header", "ok     " if has_abi else "absent "))
    sysroot = native_sysroot(a.sysroot)
    vk_headers = bool(sysroot) and os.path.isfile(os.path.join(sysroot, "include", "vulkan", "vulkan_core.h"))
    vk_sources = os.path.isfile(os.path.join(KIT, "lib", "win", "nxwin_vk.c"))
    print("%-22s %s (optional, host build only)" % ("Vulkan SDK", "ok     " if vk_headers and vk_sources else "absent "))
    sys.exit(0 if ok else 1)


def cmd_clang_build(args):
    """Compile an explicit source list with the experimental AArch64 profile."""
    if not re.fullmatch(r"[A-Za-z0-9_-]+", args.name):
        die("clang module name may contain only ASCII letters, digits, hyphens and underscores")
    llvm = Path(args.llvm).resolve()
    suffix = ".exe" if os.name == "nt" else ""
    for tool in ("clang", "clang++", "llvm-ar", "ld.lld"):
        if not (llvm / "bin" / (tool + suffix)).is_file():
            die(f"LLVM tool missing: {llvm / 'bin' / (tool + suffix)}")
    sources = [Path(name).resolve() for name in args.sources]
    for source in sources:
        if not source.is_file() or source.suffix not in (".c", ".cc", ".cpp"):
            die(f"expected a C or C++ source: {source}")
    if len({source.stem.lower() for source in sources}) != len(sources):
        die("clang profile source basenames must be unique")

    out = Path(args.output_dir).resolve()
    script = Path(KIT) / "toolchain" / "clang" / "build_clang.py"
    common = [sys.executable, str(script), "--llvm", str(llvm), "--std", args.std]
    if args.sysroot:
        sysroot = Path(args.sysroot).resolve()
        if not (sysroot / "windowed" / "include").is_dir():
            die("--sysroot must contain windowed/include")
        common += ["--sysroot", str(sysroot)]
    out.mkdir(parents=True, exist_ok=True)
    result = out / (args.name + ".nxvmod")
    with tempfile.TemporaryDirectory(prefix=".nxv-clang-", dir=out) as temporary:
        builder = [*common, "--out", temporary]
        for stage in (["window"], ["app", args.name, *map(str, sources)]):
            if rc := subprocess.call([*builder, *stage]):
                die("experimental Clang build failed", rc)
        candidate = Path(temporary) / result.name
        if not candidate.is_file():
            die("Clang build completed without a module")
        if problems := check_win(str(candidate)):
            die("\n  ".join(problems))
        candidate.replace(result)
    print(f"built {result} (experimental Clang, checked)")
    return 0


def cmd_shader(args):
    source = Path(args.source).resolve()
    if not source.is_file():
        die(f"shader source not found: {source}")
    compiler = shutil.which(args.glslang) if args.glslang else (
        shutil.which("glslang") or shutil.which("glslangValidator")
    )
    if not compiler:
        die("install glslang or specify --glslang")
    command = [compiler]
    if args.stage:
        command += ["-S", args.stage]
    if args.target == "gl":
        if args.output:
            die("--output applies to the vulkan target only")
        try:
            subprocess.run([*command, str(source)], check=True)
        except (OSError, subprocess.CalledProcessError) as error:
            die(f"GLSL validation failed: {error}")
        return 0

    if not args.output:
        die("the vulkan target requires --output")
    validator = shutil.which(args.spirv_val)
    if not validator:
        die("install SPIRV-Tools or specify --spirv-val")
    output = Path(args.output).resolve()
    if output == source:
        die("shader output must differ from its source")
    environment = "vulkan1.3"
    try:
        with tempfile.TemporaryDirectory(prefix=".nxv-shader-", dir=output.parent) as temporary:
            candidate = Path(temporary) / "shader.spv"
            subprocess.run([*command, "-V", "--target-env", environment, str(source),
                            "-o", str(candidate)], check=True)
            subprocess.run([validator, "--target-env", environment, str(candidate)], check=True)
            candidate.replace(output)
    except (OSError, subprocess.CalledProcessError) as error:
        die(f"SPIR-V build failed: {error}")
    print(f"validated {output}")
    return 0


def main():
    ap = argparse.ArgumentParser(prog="nxv-native", description="Nexvyn native SDK command line")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("new", help="create a project from a template")
    p.add_argument("name")
    p.add_argument("--template", choices=TEMPLATE_NAMES, default="app")
    p.add_argument("--dir", help="parent folder (default: current)")
    p.set_defaults(fn=cmd_new)
    p = sub.add_parser("build", help="CMake configure + build to <name>.nxvmod (checked)")
    p.add_argument("dir", nargs="?")
    p.add_argument("--abi", action="store_true", help="link the Nexvyn native ABI (needs the ABI header and library)")
    p.add_argument("--windowed", action="store_true", help=argparse.SUPPRESS)  # old spelling: the default now
    p.add_argument("--exclusive", action="store_true", help=argparse.SUPPRESS)  # hidden fallback: its own .nro (retired mode)
    p.add_argument("--debug", action="store_true")
    p.add_argument("--clean", action="store_true")
    p.add_argument("--sysroot", help="extra library prefix made by sdk/native/sysroot/assemble.py")
    p.set_defaults(fn=cmd_build)
    p = sub.add_parser("lib", help="CMake configure + build of a shared library project (nexvyn_add_lib) to .nxvlib")
    p.add_argument("dir", nargs="?")
    p.add_argument("--debug", action="store_true")
    p.add_argument("--clean", action="store_true")
    p.add_argument("--sysroot", help="extra library prefix made by sdk/native/sysroot/assemble.py")
    p.set_defaults(fn=cmd_lib)
    p = sub.add_parser("check-lib", help="check a .nxvlib (-fPIC, no TEXTREL / TLS, identity, the app's exports)")
    p.add_argument("file")
    p.add_argument("--host", help="the app's .elf: every import of the library must be exported by it")
    p.set_defaults(fn=cmd_check_lib)
    p = sub.add_parser("check-win", help="check a windowed app (.nxvmod): identity, -fPIC, imports Nexvyn OS offers")
    p.add_argument("file")
    p.set_defaults(fn=cmd_check_win)
    p = sub.add_parser("shader", help="validate GLSL or compile and validate a Vulkan SPIR-V shader")
    p.add_argument("source")
    p.add_argument("--target", choices=("gl", "vulkan"), required=True)
    p.add_argument("--stage", choices=("vert", "frag", "comp", "geom", "tesc", "tese"))
    p.add_argument("-o", "--output")
    p.add_argument("--glslang", help="optional path to glslang")
    p.add_argument("--spirv-val", default="spirv-val", help="optional path to SPIRV-Tools validator")
    p.set_defaults(fn=cmd_shader)
    p = sub.add_parser("clang-build", help="experimental AArch64 windowed build for explicit C/C++ sources")
    p.add_argument("name")
    p.add_argument("sources", nargs="+")
    p.add_argument("--llvm", required=True, help="LLVM toolchain root containing bin/")
    p.add_argument("--std", choices=("17", "20", "23"), default="17")
    p.add_argument("--output-dir", default="build/clang")
    p.add_argument("--sysroot", help="optional assembled native sysroot with windowed headers")
    p.set_defaults(fn=cmd_clang_build)
    p = sub.add_parser("exports", help="EXTERN linker script of the symbols shared libraries import (Makefile apps)")
    p.add_argument("files", nargs="+")
    p.add_argument("-o", "--output", required=True)
    p.set_defaults(fn=cmd_exports)
    p = sub.add_parser("check-design", help="OS design rules of an ImGui app (frame layer, nxn_os_* widgets, NXN_S)")
    p.add_argument("dir", nargs="?", default=".")
    p.set_defaults(fn=cmd_check_design)
    p = sub.add_parser("package", help="wrap the built module + icon + app.json into <name>.nxvapp")
    p.add_argument("dir", nargs="?")
    p.add_argument("-o", "--output")
    p.add_argument("--sign", help="developer key (tools/nxvapp_keygen.py)")
    p.add_argument("--windowed", action="store_true", help=argparse.SUPPRESS)
    p.add_argument("--exclusive", action="store_true", help=argparse.SUPPRESS)
    p.set_defaults(fn=cmd_package)
    p = sub.add_parser("run", help="copy the bundle to the emulator SD card (does not start the emulator)")
    p.add_argument("dir", nargs="?")
    p.add_argument("--sd", help="SD card root (or set NEXVYN_SD)")
    p.add_argument("--windowed", action="store_true", help=argparse.SUPPRESS)
    p.add_argument("--exclusive", action="store_true", help=argparse.SUPPRESS)
    p.set_defaults(fn=cmd_run)
    p = sub.add_parser("symbolize", help="crash report -> function:line (addr2line on the build's debug ELF)")
    p.add_argument("report", help="a System/Logs/Crashes/*-native.txt report")
    p.add_argument("--elf", action="append", help="debug ELF of a module (<name>.nxvmod.debug); default: the project's build folder")
    p.set_defaults(fn=cmd_symbolize)
    p = sub.add_parser("doctor", help="check the toolchain")
    p.add_argument("--sysroot", help="sysroot to inspect for optional SDK headers")
    p.set_defaults(fn=cmd_doctor)
    a = ap.parse_args()
    if hasattr(a, "exclusive"):
        a.windowed = not a.exclusive  # in-process module by default; --exclusive is the hidden fallback (own .nro)
    rc = a.fn(a)
    if a.fn is cmd_check_design:
        sys.exit(rc)


if __name__ == "__main__":
    main()
