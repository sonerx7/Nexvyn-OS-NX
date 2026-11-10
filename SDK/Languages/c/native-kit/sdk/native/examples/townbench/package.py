#!/usr/bin/env python3
"""Bakes (with tools/nxv_asset), builds and packs the Village Bench (needs devkitPro, a host C compiler and Pillow, numpy, etcpak).

    python sdk/native/examples/graphics/package.py --fbx FantasyTownKit_A.fbx [--baked DIR] [--out DIR]

The FBX is your own input and is never copied into the repository. The bake step also paints the two inn-sign boards of
the kit's props texture (base colour and normal map) blank, so no readable lettering ships; texture sizes are capped
(base colour 2048, normal 1024, roughness 512) to keep the package near 60 MB. Baked files go to build/graphics-baked
(ignored by git) and are copied into data/ (also ignored) only while packing.
"""
import argparse, os, shutil, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
CLI = [sys.executable, os.path.join(REPO, "tools", "nxv_native")]
ASSET = os.path.join(REPO, "tools", "nxv_asset")
CAPS = {0: 2048, 3: 1024, 1: 1024, 2: 512}  # texture role (base, normal, roughness+metal, emissive) -> max side
SIGNS = ((0, 505, 1225, 1610), (1380, 1762, 1388, 1890))  # the two sign boards in the 4096 props texture (x0, x1, y0, y1)


def run(cmd):
    if subprocess.call(cmd):
        sys.exit(1)


def bake(fbx, baked):
    import numpy as np
    from PIL import Image
    Image.MAX_IMAGE_PIXELS = None
    sys.path.insert(0, ASSET)
    sys.path.insert(0, os.path.join(REPO, "tools"))
    import importlib.util
    import bake_textures
    # the converter binary is built by nxv_asset (build/nxv-asset); a first nxv_asset run creates it
    exe = os.path.join(REPO, "build", "nxv-asset", "fbx_bake" + (".exe" if os.name == "nt" else ""))
    if not os.path.exists(exe):
        tmp = os.path.join(baked, "_probe")
        run([sys.executable, ASSET, "bake", fbx, "-o", tmp, "--name", "town"])
        shutil.rmtree(tmp, ignore_errors=True)
    shutil.rmtree(baked, ignore_errors=True)
    os.makedirs(baked)
    run([exe, fbx, baked, "town"])
    for idx in (0, 1):  # props: base colour and normal map
        p = os.path.join(baked, "src", "%d_0.png" % idx)
        a = np.asarray(Image.open(p).convert("RGBA")).copy()
        if a.shape[:2] != (4096, 4096):
            print("warning: texture %d is not the 4096 props texture, signs not painted" % idx)
            continue
        for x0, x1, y0, y1 in SIGNS:
            if idx == 0:
                a[y0:y1, x0:x1, :3] = np.median(a[y0 + 8:y0 + 20, x0 + 8:x1 - 8, :3].reshape(-1, 3), axis=0).astype(np.uint8)
            else:
                a[y0:y1, x0:x1] = (128, 128, 255, 255)
        Image.fromarray(a, "RGBA").save(p)
    jobs = os.path.join(baked, "town.jobs")
    rows = []
    for line in open(jobs, encoding="utf-8"):
        f = line.rstrip("\n").split("\t")
        f[3] = str(CAPS.get(int(f[1]), 1024))
        rows.append("\t".join(f))
    open(jobs, "w", encoding="utf-8").write("\n".join(rows) + "\n")
    sys.argv = ["bake_textures.py", baked, "town"]
    bake_textures.main()
    os.remove(jobs)
    shutil.rmtree(os.path.join(baked, "src"), ignore_errors=True)
    run([sys.executable, ASSET, "check", os.path.join(baked, "town.nxsc"), os.path.join(baked, "town.nxtx")])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fbx", default="")
    ap.add_argument("--baked", default=os.path.join(REPO, "build", "graphics-baked"))
    ap.add_argument("--out", default=os.path.join(REPO, "build", "townbench-kit"))
    a = ap.parse_args()
    if a.fbx:
        bake(a.fbx, a.baked)
    data = os.path.join(HERE, "data")
    os.makedirs(data, exist_ok=True)
    try:
        for ext in (".nxsc", ".nxtx"):
            shutil.copy2(os.path.join(a.baked, "town" + ext), data)
        os.makedirs(a.out, exist_ok=True)
        run(CLI + ["build", HERE, "--windowed", "--clean"])
        run(CLI + ["package", HERE, "--windowed", "-o", os.path.join(a.out, "com.nexvyn.demo.townbench.nxvapp")])
    finally:
        shutil.rmtree(data, ignore_errors=True)
    print("package in " + a.out)


if __name__ == "__main__":
    main()
