#!/usr/bin/env python3
"""textures.py - prepare PBR texture sets for Nexvyn OS games (SDK 1.9 pbr renderer). Python 3.8+ with Pillow.

    python textures.py check <folder>                        list texture sets, sizes and what is missing
    python textures.py resize <folder> [--max 1024]          scale every image above --max down (in place, a copy
                                                             of the original goes to <folder>/_originals/)
    python textures.py orm <ao|-> <roughness|-> <metallic|-> <out.png>
                                                             pack glTF ORM: R occlusion, G roughness, B metallic
                                                             ("-" = constant: AO 1, roughness 0.5, metallic 0)
    python textures.py smoothness <metallicSmoothness.png> <outRoughness.png> [--metallic outMetallic.png]
                                                             split a MetallicSmoothness map (R metallic, A smoothness)
                                                             into roughness (1 - smoothness) and metallic
    python textures.py flipgreen <normal.png> <out.png>      convert a DirectX-style normal map (green down) to the
                                                             OpenGL style the pbr renderer reads (green up)

Maps an FBX does not link that the pbr renderer finds next to its external base colour file (<Name>_BaseColor):
<Name>_AO, _Metallic, _Roughness, _MetallicSmoothness (.png / .jpg). Normal and emissive maps must be linked in the
FBX. glTF (.glb) files carry their maps inside the file; pack them with ORM before you export, or let your exporter
do it. See SDK/Guides/AI_WORKFLOW.en.md.
"""
import os
import shutil
import sys

try:
    from PIL import Image
except ImportError:  # pragma: no cover
    sys.exit("textures.py needs Pillow: python -m pip install Pillow")

EXTS = (".png", ".jpg", ".jpeg", ".webp", ".tga", ".bmp")
SUFFIXES = ("BaseColor", "Albedo", "Diffuse", "Normal", "AO", "Occlusion", "Metallic", "Roughness",
            "MetallicSmoothness", "ORM", "Emissive")


def usage(msg=None):
    if msg:
        print("error: " + msg)
    print(__doc__)
    sys.exit(2)


def images(folder):
    for n in sorted(os.listdir(folder)):
        if n.lower().endswith(EXTS) and os.path.isfile(os.path.join(folder, n)):
            yield n


def split_name(name):
    stem = os.path.splitext(name)[0]
    for suf in sorted(SUFFIXES, key=len, reverse=True):
        if stem.lower().endswith("_" + suf.lower()):
            return stem[:-len(suf) - 1], suf
    return stem, None


def cmd_check(folder):
    sets = {}
    for n in images(folder):
        base, suf = split_name(n)
        with Image.open(os.path.join(folder, n)) as im:
            sets.setdefault(base, []).append((suf or "?", n, im.size, im.mode))
    problems = 0
    for base, maps in sorted(sets.items()):
        print(base)
        kinds = {m[0] for m in maps}
        for suf, n, size, mode in maps:
            note = ""
            if max(size) > 2048:
                note = "  <- larger than 2048 px: scale it down (resize)"
                problems += 1
            elif size[0] & (size[0] - 1) or size[1] & (size[1] - 1):
                note = "  <- not a power of two"
            print("  %-20s %-40s %4dx%-4d %s%s" % (suf, n, size[0], size[1], mode, note))
        if kinds & {"BaseColor", "Albedo", "Diffuse"} and "Normal" not in kinds:
            print("  (no normal map: the surface is lit as flat)")
        if "MetallicSmoothness" in kinds and "Roughness" in kinds:
            print("  (both MetallicSmoothness and Roughness: keep one)")
    print("%d texture set(s), %d problem(s)" % (len(sets), problems))
    return 1 if problems else 0


def cmd_resize(folder, limit):
    keep = os.path.join(folder, "_originals")
    for n in images(folder):
        p = os.path.join(folder, n)
        with Image.open(p) as im:
            w, h = im.size
            if max(w, h) <= limit:
                continue
            k = limit / float(max(w, h))
            os.makedirs(keep, exist_ok=True)
            shutil.copyfile(p, os.path.join(keep, n))
            small = im.resize((max(1, round(w * k)), max(1, round(h * k))), Image.LANCZOS)
        small.save(p)
        print("%s: %dx%d -> %dx%d" % (n, w, h, small.size[0], small.size[1]))
    return 0


def channel(path, size, constant):
    if path == "-":
        return Image.new("L", size, constant)
    with Image.open(path) as im:
        return im.convert("L").resize(size, Image.LANCZOS)


def cmd_orm(ao, rough, metal, out):
    real = [p for p in (ao, rough, metal) if p != "-"]
    if not real:
        usage("orm needs at least one map")
    with Image.open(real[0]) as im:
        size = im.size
    Image.merge("RGB", (channel(ao, size, 255), channel(rough, size, 128), channel(metal, size, 0))).save(out)
    print("wrote %s (%dx%d): R occlusion, G roughness, B metallic" % (out, size[0], size[1]))
    return 0


def cmd_smoothness(src, out_rough, out_metal=None):
    with Image.open(src) as im:
        im = im.convert("RGBA")
        r, _, _, a = im.split()
    a.point(lambda v: 255 - v).save(out_rough)
    print("wrote " + out_rough + " (roughness = 1 - smoothness)")
    if out_metal:
        r.save(out_metal)
        print("wrote " + out_metal)
    return 0


def cmd_flipgreen(src, out):
    with Image.open(src) as im:
        im = im.convert("RGB")
        r, g, b = im.split()
    Image.merge("RGB", (r, g.point(lambda v: 255 - v), b)).save(out)
    print("wrote " + out + " (green channel inverted)")
    return 0


def main(argv):
    if len(argv) < 2:
        usage()
    cmd, args = argv[1], argv[2:]
    if cmd == "check" and len(args) == 1:
        return cmd_check(args[0])
    if cmd == "resize" and args:
        limit = 1024
        if "--max" in args:
            i = args.index("--max")
            limit = int(args[i + 1])
            args = args[:i] + args[i + 2:]
        return cmd_resize(args[0], limit)
    if cmd == "orm" and len(args) == 4:
        return cmd_orm(*args)
    if cmd == "smoothness" and len(args) in (2, 4):
        return cmd_smoothness(args[0], args[1], args[3] if len(args) == 4 and args[2] == "--metallic" else None)
    if cmd == "flipgreen" and len(args) == 2:
        return cmd_flipgreen(*args)
    usage("unknown command or wrong arguments")


if __name__ == "__main__":
    sys.exit(main(sys.argv))
