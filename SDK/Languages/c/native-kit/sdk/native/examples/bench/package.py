#!/usr/bin/env python3
"""Builds and packs Nexvyn Bench (needs devkitPro). The city is the Scenes demo's baked Level 1 (your own FBX, baked with
tools/nxv_asset; never committed): it is copied into data/ (ignored by git) only while packing, then removed.

    python sdk/native/examples/bench/package.py [--baked DIR] [--out DIR]
"""
import argparse, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
CLI = [sys.executable, os.path.join(REPO, "tools", "nxv_native")]


def run(cmd):
    if subprocess.call(cmd):
        sys.exit(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--baked", default=os.path.join(REPO, "build", "scene-demo"))
    ap.add_argument("--out", default=os.path.join(REPO, "build", "bench-kit"))
    a = ap.parse_args()
    data = os.path.join(HERE, "data")
    os.makedirs(data, exist_ok=True)
    try:
        for ext in (".nxsc", ".nxtx"):
            shutil.copy2(os.path.join(a.baked, "level1" + ext), data)
        os.makedirs(a.out, exist_ok=True)
        run(CLI + ["build", HERE, "--windowed", "--clean"])
        run(CLI + ["package", HERE, "--windowed", "-o", os.path.join(a.out, "com.nexvyn.example.bench.nxvapp")])
    finally:
        shutil.rmtree(data, ignore_errors=True)
    print("package in " + a.out)


if __name__ == "__main__":
    main()
