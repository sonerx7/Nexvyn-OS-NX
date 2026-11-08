#!/usr/bin/env python3
"""Makes the Tour's small 3D scene from nothing (procedural geometry + a generated floor texture, no third-party content):

    python sdk/native/examples/tour/gen_scene.py [--out DIR]    (needs numpy and Pillow; the bake step also needs etcpak)

Writes tour.glb to a temporary folder and bakes it with tools/nxv_asset into data/tour.nxsc + data/tour.nxtx (a few KB).
The baked files are committed, so building the app needs none of this.
"""
import argparse, io, json, math, os, shutil, struct, subprocess, sys, tempfile
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))


def sphere(r, seg=48, rings=24):
    P, N, U = [], [], []
    for i in range(rings + 1):
        v = i / rings
        th = v * math.pi
        for j in range(seg + 1):
            u = j / seg
            ph = u * 2 * math.pi
            n = (math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph))
            P.append([c * r for c in n]); N.append(n); U.append((u, v))
    I = []
    for i in range(rings):
        for j in range(seg):
            a = i * (seg + 1) + j; b = a + seg + 1
            I += [a, a + 1, b, a + 1, b + 1, b]
    return P, N, U, I


def torus(R, r, seg=64, ring=24):
    P, N, U = [], [], []
    for i in range(seg + 1):
        u = i / seg; a = u * 2 * math.pi
        for j in range(ring + 1):
            v = j / ring; b = v * 2 * math.pi
            n = (math.cos(a) * math.cos(b), math.sin(b), math.sin(a) * math.cos(b))
            c = (math.cos(a) * R, 0, math.sin(a) * R)
            P.append([c[0] + n[0] * r, n[1] * r, c[2] + n[2] * r]); N.append(n); U.append((u * 4, v))
    I = []
    for i in range(seg):
        for j in range(ring):
            a = i * (ring + 1) + j; b = a + ring + 1
            I += [a, b, a + 1, a + 1, b, b + 1]
    return P, N, U, I


def box(w, h, d):
    P, N, U, I = [], [], [], []
    faces = [((1, 0, 0), (0, 0, -1), (0, 1, 0)), ((-1, 0, 0), (0, 0, 1), (0, 1, 0)), ((0, 1, 0), (1, 0, 0), (0, 0, -1)),
             ((0, -1, 0), (1, 0, 0), (0, 0, 1)), ((0, 0, 1), (1, 0, 0), (0, 1, 0)), ((0, 0, -1), (-1, 0, 0), (0, 1, 0))]
    half = (w / 2, h / 2, d / 2)
    for n, t, b in faces:
        base = len(P)
        for su, sv in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            P.append([n[k] * half[k] + t[k] * su * half[k] + b[k] * sv * half[k] for k in range(3)])
            N.append(n); U.append(((su + 1) / 2, (sv + 1) / 2))
        I += [base, base + 1, base + 2, base, base + 2, base + 3]
    return P, N, U, I


def plane(s):
    return [[-s, 0, -s], [s, 0, -s], [s, 0, s], [-s, 0, s]], [(0, 1, 0)] * 4, [(0, 0), (6, 0), (6, 6), (0, 6)], [0, 2, 1, 0, 3, 2]


def floor_png():
    y, x = np.mgrid[0:256, 0:256]
    chk = ((x // 128) + (y // 128)) % 2
    base = np.where(chk[..., None] == 0, np.array([58, 64, 76]), np.array([44, 49, 60])).astype(np.float32)
    # soft grid lines and a little grain so the floor reads as a surface, not a flat colour
    line = ((x % 128 < 2) | (y % 128 < 2))[..., None] * 14.0
    rng = np.random.RandomState(7)
    img = np.clip(base + line + rng.normal(0, 2.0, base.shape), 0, 255).astype(np.uint8)
    buf = io.BytesIO(); Image.fromarray(img).save(buf, "PNG"); return buf.getvalue()


def build(out):
    meshes = []  # (geometry, translation, material index)
    meshes.append((plane(7.0), (0, 0, 0), 0))
    meshes.append((sphere(1.0), (0, 1.15, 0), 1))
    meshes.append((torus(2.0, 0.22), (0, 0.3, 0), 2))
    for k, (h, mat) in enumerate(((1.6, 3), (1.0, 4), (2.2, 5))):
        a = k * 2 * math.pi / 3 + 0.5
        meshes.append((box(0.9, h, 0.9), (math.cos(a) * 3.6, h / 2, math.sin(a) * 3.6), mat))
    meshes.append((sphere(0.28), (0, 3.0, 0), 6))
    mats = [
        dict(pbrMetallicRoughness=dict(baseColorFactor=[1, 1, 1, 1], baseColorTexture={"index": 0}, metallicFactor=0.0, roughnessFactor=0.85)),
        dict(pbrMetallicRoughness=dict(baseColorFactor=[0.95, 0.72, 0.30, 1], metallicFactor=1.0, roughnessFactor=0.22)),
        dict(pbrMetallicRoughness=dict(baseColorFactor=[0.10, 0.45, 0.95, 1], metallicFactor=0.15, roughnessFactor=0.35)),
        dict(pbrMetallicRoughness=dict(baseColorFactor=[0.85, 0.20, 0.25, 1], metallicFactor=0.0, roughnessFactor=0.5)),
        dict(pbrMetallicRoughness=dict(baseColorFactor=[0.20, 0.75, 0.45, 1], metallicFactor=0.0, roughnessFactor=0.6)),
        dict(pbrMetallicRoughness=dict(baseColorFactor=[0.92, 0.92, 0.95, 1], metallicFactor=0.6, roughnessFactor=0.3)),
        dict(pbrMetallicRoughness=dict(baseColorFactor=[1, 0.9, 0.7, 1], metallicFactor=0.0, roughnessFactor=0.4), emissiveFactor=[1.0, 0.85, 0.5]),
    ]
    blob = bytearray(); views, accs, prims, nodes = [], [], [], []

    def add(arr, target, kind, ctype, count_t):
        while len(blob) % 4: blob.append(0)
        views.append(dict(buffer=0, byteOffset=len(blob), byteLength=arr.nbytes, target=target))
        blob.extend(arr.tobytes())
        a = dict(bufferView=len(views) - 1, componentType=ctype, count=count_t, type=kind)
        accs.append(a); return len(accs) - 1, a

    for gi, (g, t, m) in enumerate(meshes):
        P, N, U, I = g
        P = np.array(P, np.float32); N = np.array(N, np.float32); U = np.array(U, np.float32); I = np.array(I, np.uint32)
        ap, a = add(P, 34962, "VEC3", 5126, len(P)); a["min"] = P.min(0).tolist(); a["max"] = P.max(0).tolist()
        an, _ = add(N, 34962, "VEC3", 5126, len(N)); au, _ = add(U, 34962, "VEC2", 5126, len(U))
        ai, _ = add(I, 34963, "SCALAR", 5125, len(I))
        prims.append(dict(primitives=[dict(attributes=dict(POSITION=ap, NORMAL=an, TEXCOORD_0=au), indices=ai, material=m)]))
        nodes.append(dict(mesh=gi, translation=list(t)))
    png = floor_png()
    while len(blob) % 4: blob.append(0)
    views.append(dict(buffer=0, byteOffset=len(blob), byteLength=len(png))); blob.extend(png)
    # a directional sun: -Z of the node points along the light direction
    d = np.array([-0.55, -0.75, -0.45]); d /= np.linalg.norm(d)
    f = np.array([0, 0, -1.0]); ax = np.cross(f, d); s = np.linalg.norm(ax); c = float(f @ d); ax /= s
    ang = math.atan2(s, c); q = [*(ax * math.sin(ang / 2)), math.cos(ang / 2)]
    nodes.append(dict(rotation=[float(v) for v in q], extensions={"KHR_lights_punctual": {"light": 0}}))
    doc = dict(asset=dict(version="2.0", generator="tour gen_scene.py"), scene=0, scenes=[dict(nodes=list(range(len(nodes))))],
               nodes=nodes, meshes=prims, materials=mats, accessors=accs, bufferViews=views, buffers=[dict(byteLength=len(blob))],
               images=[dict(bufferView=len(views) - 1, mimeType="image/png")], textures=[dict(source=0)],
               extensionsUsed=["KHR_lights_punctual"],
               extensions={"KHR_lights_punctual": {"lights": [dict(type="directional", color=[1, 0.96, 0.9], intensity=3.0)]}})
    js = json.dumps(doc).encode()
    js += b" " * (-len(js) % 4)
    bb = bytes(blob) + b"\0" * (-len(blob) % 4)
    glb = (struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(bb)) + struct.pack("<I4s", len(js), b"JSON") + js +
           struct.pack("<I4s", len(bb), b"BIN\0") + bb)
    path = os.path.join(out, "tour.glb")
    open(path, "wb").write(glb)
    return path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(HERE, "data"))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        glb = build(tmp)
        rc = subprocess.call([sys.executable, os.path.join(REPO, "tools", "nxv_asset"), "bake", glb, "-o", a.out, "--name", "tour"])
        shutil.rmtree(os.path.join(a.out, "tour_img"), ignore_errors=True)  # the baker leaves its texture work folder
        sys.exit(rc)


if __name__ == "__main__":
    main()
