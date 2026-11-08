#!/usr/bin/env python3
"""Builds and packs the windowed Showcase (the exclusive build still compiles, but exclusive mode is retired) (needs devkitPro, see docs/NATIVE_KIT.en.md).

    python sdk/native/examples/showcase/package.py [--sysroot DIR] [--out DIR]

  com.nexvyn.example.showcase       windowed  (.nxvmod, runs in a Nexvyn OS window)
"""
import argparse, json, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
CLI = [sys.executable, os.path.join(REPO, "tools", "nxv_native")]
APP = os.path.join(HERE, "app.json")


def run(args):
    r = subprocess.run(CLI + args)
    if r.returncode:
        sys.exit(r.returncode)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--sysroot", default=os.environ.get("NEXVYN_SYSROOT", ""))
    ap.add_argument("--out", default=os.path.join(REPO, "build", "showcase-kit"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    extra = ["--sysroot", a.sysroot] if a.sysroot else []
    original = open(APP, encoding="utf-8").read()
    try:
        run(["build", HERE, "--windowed", "--clean"] + extra)
        run(["package", HERE, "--windowed", "-o", os.path.join(a.out, "com.nexvyn.example.showcase.nxvapp")])
    finally:
        with open(APP, "w", encoding="utf-8", newline="\n") as f:
            f.write(original)
    print("packages in " + a.out)


if __name__ == "__main__":
    main()
