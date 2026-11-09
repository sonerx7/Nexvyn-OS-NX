#!/usr/bin/env python3
"""Spike: builds Nexvyn windowed apps (.nxvmod) with clang/LLVM instead of devkitA64's gcc.

  python sdk/native/toolchain/clang/build_clang.py [--llvm DIR] [--out DIR] window | app NAME SRC... | all

LLVM comes from build/llvm/llvm20 (official release, never installed system-wide). The sysroot is devkitPro's: newlib
headers/libs, libnx, portlibs (glad), libstdc++ / libsupc++ / libgcc / crtend.o of devkitA64's pic multilib. Linking uses
lld (ld.lld). Same flags as nexvyn_add_windowed() except what clang does not have (see the report, qa/reports/2026-11-09_clang_spike.md):
no -mtp=soft (invalid for aarch64), no -mtls-dialect (rejected for aarch64-none-elf; clang's default is traditional TLS).
"""
import argparse
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
KIT = os.path.abspath(os.path.join(HERE, "..", ".."))
REPO = os.path.abspath(os.path.join(KIT, "..", ".."))
DKP = os.environ.get("DEVKITPRO_WIN") or "C:/devkitPro"
A64 = DKP + "/devkitA64"
NEWLIB = A64 + "/aarch64-none-elf"
GCCLIB = A64 + "/lib/gcc/aarch64-none-elf/15.2.0"
CXXINC = NEWLIB + "/include/c++/15.2.0"

ARCH = ["--target=aarch64-none-elf", "-march=armv8-a+crc+crypto", "-mtune=cortex-a57"]
COMMON = ARCH + ["-fPIC", "-ftls-model=global-dynamic", "-ffunction-sections", "-fdata-sections", "-O2", "-g",
                 "-D__SWITCH__", "-DNEXVYN_ABI=1", "-DNEXVYN_WINDOWED=1", "-I" + KIT + "/include", "-I" + KIT + "/loader",
                 "-isystem", NEWLIB + "/include", "-isystem", DKP + "/libnx/include",
                 "-isystem", DKP + "/portlibs/switch/include"]
CFLAGS = ["-std=gnu11", "-Wall", "-Wextra", "-Wno-unused-parameter"]
CXXFLAGS = ["-std=gnu++17", "-fexceptions", "-frtti", "-nostdinc++", "-isystem", CXXINC,
            "-isystem", CXXINC + "/aarch64-none-elf/pic", "-isystem", CXXINC + "/backward"]


def run(cmd):
    print(" ".join(cmd) if os.environ.get("V") else "  " + os.path.basename(cmd[0]) + " " + cmd[-1], flush=True)
    r = subprocess.run(cmd)
    if r.returncode:
        sys.exit("FAILED: " + " ".join(cmd))


def tool(llvm, name):
    return os.path.join(llvm, "bin", name + (".exe" if os.name == "nt" else ""))


def compile_one(llvm, src, obj, defs=()):
    cxx = src.endswith((".cpp", ".cc"))
    # the C++ include dirs come first: libstdc++ headers #include_next the newlib ones
    cmd = [tool(llvm, "clang++" if cxx else "clang")] + (CXXFLAGS + COMMON if cxx else COMMON + CFLAGS) + ["-D" + d for d in defs] + ["-c", src, "-o", obj]
    cmd[1:1] = os.environ.get("NXN_CFLAGS", "").split()  # extra flags, e.g. NXN_CFLAGS=-flto=thin
    if "STL_STD20" in defs:
        cmd = [("-std=gnu++20" if c == "-std=gnu++17" else c) for c in cmd]
    run(cmd)


def build_window(llvm, out):
    os.makedirs(out + "/win", exist_ok=True)
    objs = []
    for f in ("nxwin_support", "nxwin_gles", "nxwin_glcore"):
        o = "%s/win/%s.o" % (out, f)
        compile_one(llvm, "%s/lib/win/%s.c" % (KIT, f), o)
        objs.append(o)
    lib = out + "/libnexvyn_window.a"
    if os.path.exists(lib):
        os.remove(lib)
    run([tool(llvm, "llvm-ar"), "rcs", lib] + objs)


def link_module(llvm, objs, out_file, window_lib_dir):
    cmd = [tool(llvm, "ld.lld"), "-shared", "-Bsymbolic", "-z", "now", "-z", "text", "-z", "max-page-size=0x1000",
           "--hash-style=sysv", "--gc-sections", "--build-id=sha1", "--undefined=nxnwin_identity",
           "-o", out_file] + objs + ["--start-group", NEWLIB + "/lib/pic/libstdc++.a", NEWLIB + "/lib/pic/libsupc++.a",
                                     GCCLIB + "/pic/libgcc.a", "--end-group",
                                     "-L" + window_lib_dir, "-lnexvyn_window", DKP + "/portlibs/switch/lib/libglad.a",
                                     GCCLIB + "/pic/crtend.o"]
    run(cmd)


def build_app(llvm, out, name, srcs, defs=()):
    os.makedirs(out + "/" + name, exist_ok=True)
    objs = []
    for s in srcs:
        o = "%s/%s/%s.o" % (out, name, os.path.splitext(os.path.basename(s))[0])
        compile_one(llvm, s, o, defs)
        objs.append(o)
    mod = "%s/%s.nxvmod" % (out, name)
    link_module(llvm, objs, mod, out)
    print("built", mod)
    return mod


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--llvm", default=os.path.join(REPO, "build", "llvm", "llvm20"))
    ap.add_argument("--out", default=os.path.join(REPO, "build", "clangspike"))
    ap.add_argument("what", choices=["window", "app", "all"])
    ap.add_argument("rest", nargs="*")
    a = ap.parse_args()
    if a.what in ("window", "all"):
        build_window(a.llvm, a.out)
    if a.what == "app":
        build_app(a.llvm, a.out, a.rest[0], [os.path.abspath(s) for s in a.rest[1:]],
                  os.environ.get("NXN_DEFS", "").split())  # e.g. NXN_DEFS=STL_STD20 (-DSTL_STD20, and -std=gnu++20)
    if a.what == "all":
        build_app(a.llvm, a.out, "hello_c", [KIT + "/examples/hello_gl/source/main.c"])
        build_app(a.llvm, a.out, "cxx_probe", [HERE + "/tests/cxx_probe.cpp"])
        build_app(a.llvm, a.out, "cxx_probe_notls", [HERE + "/tests/cxx_probe.cpp"], ["PROBE_NO_TLS"])
        build_app(a.llvm, a.out, "stl_app", [HERE + "/tests/stl_app.cpp", HERE + "/tests/stl_heavy.cpp"])


if __name__ == "__main__":
    main()
