#!/usr/bin/env python3
"""Bakes (with tools/nxv_asset, when needed), builds and packs the windowed Scenes demo (needs devkitPro, a host C compiler and Pillow, numpy, etcpak).

    python sdk/native/examples/scenes/package.py --level1 L1.fbx --library LIB.fbx [--baked DIR] [--out DIR]

The FBX files are your own input and are never copied into the repository. Baked files go to build/scene-demo (ignored by
git); they are copied into the project's data/ folder (also ignored) only while packing, then removed.
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
    ap.add_argument("--level1", default="")
    ap.add_argument("--library", default="")
    ap.add_argument("--baked", default=os.path.join(REPO, "build", "scene-demo"))
    ap.add_argument("--out", default=os.path.join(REPO, "build", "scenes-kit"))
    a = ap.parse_args()
    for fbx, name in ((a.level1, "level1"), (a.library, "library")):
        if fbx:
            run([sys.executable, os.path.join(REPO, "tools", "nxv_asset"), "bake", fbx, "-o", a.baked, "--name", name])
    data = os.path.join(HERE, "data")
    os.makedirs(data, exist_ok=True)
    try:
        for name in ("level1", "library"):
            for ext in (".nxsc", ".nxtx"):
                shutil.copy2(os.path.join(a.baked, name + ext), data)
        os.makedirs(a.out, exist_ok=True)
        run(CLI + ["build", HERE, "--windowed", "--clean"])
        run(CLI + ["package", HERE, "--windowed", "-o", os.path.join(a.out, "com.nexvyn.example.scenes.nxvapp")])
    finally:
        shutil.rmtree(data, ignore_errors=True)
    print("package in " + a.out)


if __name__ == "__main__":
    main()
