#!/usr/bin/env python3
"""Draws the App Market icons of the apps and games that have their own icon (Store/Apps and Store/Games items with
a source/ folder) from Tools/icons/icons.json.

Every entry of icons.json is keyed by the item's folder under Store/ and says which motif draws it (a function in
one of the motifs_*.py files), its background, its finish and its palette:

    "Games/arcade/snake": {
        "idea": "a snake curled around an apple",
        "motif": "snake",
        "bg": {"style": "radial", "colors": ["#7ED957", "#1F7A3A"], "pattern": "dots"},
        "finish": "gloss",
        "palette": {"body": "#FFD23F", "apple": "#FF3B47"}
    }

bg.style is linear (angle), radial (center, radius), conic, split (angle, offset, four colours) or flat; bg.pattern
is rays, rings, grid, dots, stripes, checker, stars, bokeh or waves (pcolor, pop for its colour and opacity).
finish is soft (the system icons' finish), gloss (an extra sheen) or matte.

The icon is written to the item's source/<icon> (what goes into the .nxvapp) and to its listing icon.png.
Run python Tools/build_store.py afterwards: the packages change with their icons.

Usage:
    python Tools/icons/make_icons.py                       draw every icon into Store/
    python Tools/icons/make_icons.py --only snake,pong     only these items (folder names or keys)
    python Tools/icons/make_icons.py --preview DIR         write <slug>.png files to DIR instead of Store/
    python Tools/icons/make_icons.py --sheet out.png       also write a contact sheet of the drawn icons

Requires Pillow and numpy. The letters come from the font packs in Store/Fonts.
"""
import argparse
import json
import os
import sys
from concurrent.futures import ProcessPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
STORE = os.path.join(ROOT, "Store")
SPEC = os.path.join(HERE, "icons.json")
sys.path.insert(0, HERE)


def load_spec():
    with open(SPEC, encoding="utf-8") as f:
        return json.load(f)["icons"]


def draw(key, spec):
    import glob
    import importlib
    import iconkit
    for path in sorted(glob.glob(os.path.join(HERE, "motifs_*.py"))):
        importlib.import_module(os.path.splitext(os.path.basename(path))[0])  # registers the motifs
    from motifs_common import MOTIFS
    slug = key.rsplit("/", 1)[-1]
    name = spec.get("motif", slug)
    if name not in MOTIFS:
        raise SystemExit("%s: unknown motif %r" % (key, name))
    ic = iconkit.Icon(spec, seed=sum(map(ord, key)))
    ic.background(spec["bg"])
    MOTIFS[name](ic)
    ic.finish(spec.get("finish", "soft"))
    return ic.image()


def targets(key):
    item = os.path.join(STORE, *key.split("/"))
    icon = "icon.png"
    app_json = os.path.join(item, "source", "app.json")
    if os.path.isfile(app_json):
        with open(app_json, encoding="utf-8") as f:
            icon = json.load(f).get("icon", "icon.png")
    return [os.path.join(item, "source", *icon.split("/")), os.path.join(item, "icon.png")]


def job(args):
    key, spec, preview = args
    try:
        img = draw(key, spec)
    except Exception as e:
        raise RuntimeError("%s: %s" % (key, e)) from e
    if preview:
        outs = [os.path.join(preview, key.rsplit("/", 1)[-1] + ".png")]
    else:
        outs = targets(key)
    for p in outs:
        os.makedirs(os.path.dirname(p), exist_ok=True)
        img.save(p, optimize=True)
    return key, outs


def sheet(paths, out, cols=12, cell=96):
    from PIL import Image
    rows = (len(paths) + cols - 1) // cols
    im = Image.new("RGB", (cols * (cell + 8) + 8, rows * (cell + 8) + 8), "#2B2D33")
    for i, p in enumerate(paths):
        ic = Image.open(p).convert("RGBA").resize((cell, cell), Image.LANCZOS)
        im.paste(ic, (8 + (i % cols) * (cell + 8), 8 + (i // cols) * (cell + 8)), ic)
    im.save(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="")
    ap.add_argument("--preview", default="")
    ap.add_argument("--sheet", default="")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 4)
    a = ap.parse_args()
    specs = load_spec()
    keys = sorted(specs)
    if a.only:
        want = set(a.only.split(","))
        keys = [k for k in keys if k in want or k.rsplit("/", 1)[-1] in want]
    if not a.preview:
        missing = [k for k in keys if not os.path.isdir(os.path.join(STORE, *k.split("/"), "source"))]
        if missing:
            raise SystemExit("not an item with a source/ folder: " + ", ".join(missing))
    work = [(k, specs[k], a.preview) for k in keys]
    done = []
    with ProcessPoolExecutor(max_workers=max(1, a.jobs)) as ex:
        for key, outs in ex.map(job, work):
            done.append(outs[0])
    print("drew %d icons" % len(done))
    if a.sheet:
        sheet(done, a.sheet)
        print("sheet:", a.sheet)
    return 0


if __name__ == "__main__":
    sys.exit(main())
