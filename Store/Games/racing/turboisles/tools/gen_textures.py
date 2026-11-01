#!/usr/bin/env python3
"""Generates the textures of Turbo Isles into ../source/textures/ (deterministic: the same PNGs on every run).

    python tools/gen_textures.py        (needs Pillow and numpy)

Per theme (bay, harbor, ridge):
  road_<t>.png    512x256  columns, U across / V along the road (V repeats every 12 units):
                  asphalt with edge lines and centre dashes (x 0-319), kerb (328-391), barrier face (400-455),
                  shoulder (464-511). The layout is mirrored in track.lua (ROADU).
  ground_<t>.png  256x256  seamless ground (grass / harbour paving / canyon rock), mapped in world space
  water_<t>.png   256x256  seamless sea (bay, harbor) or dune sand (ridge), mapped in world space
  sky_<t>.png     512x256  sky panorama, 90 degrees per image, horizon on row 192, distant islands / skyline
Shared:
  props.png       512x512  4x4 atlas of 128 px tiles (index = row * 4 + column), see PROPS in track.lua
  car_<hex>.png   256x256  one livery per paint colour, UV layout in car.lua (CARUV)
Every texture is at most 512 px and power-of-two sized, so the GPU builds mipmaps for it.
"""
import os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "source", "textures"))


# ---------------------------------------------------------------- helpers
def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def noise(w, h, cx, cy, rng):
    """Tileable value noise in 0..1 with cx x cy cells."""
    g = rng.random((cy, cx)).astype(np.float32)
    xs = np.arange(w, dtype=np.float32) / w * cx
    ys = np.arange(h, dtype=np.float32) / h * cy
    x0 = np.floor(xs).astype(int)
    y0 = np.floor(ys).astype(int)
    fx = xs - x0
    fy = ys - y0
    fx = fx * fx * (3 - 2 * fx)
    fy = fy * fy * (3 - 2 * fy)
    x1, y1 = (x0 + 1) % cx, (y0 + 1) % cy
    x0, y0 = x0 % cx, y0 % cy
    a = g[np.ix_(y0, x0)]
    b = g[np.ix_(y0, x1)]
    c = g[np.ix_(y1, x0)]
    d = g[np.ix_(y1, x1)]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


def fbm(w, h, cx, cy, rng, oct=4, pers=0.5):
    tot, amp, s = np.zeros((h, w), np.float32), 1.0, 0.0
    for o in range(oct):
        tot += noise(w, h, cx * 2 ** o, cy * 2 ** o, rng) * amp
        s += amp
        amp *= pers
    return tot / s


def mix(a, b, t):
    t = np.asarray(t, np.float32)
    if t.ndim == 2:
        t = t[..., None]
    return a + (b - a) * t


def fill(w, h, col):
    return np.ones((h, w, 3), np.float32) * rgb(col)


def save(arr, name, alpha=None):
    a = np.clip(arr, 0, 255).astype(np.uint8)
    if alpha is not None:
        img = Image.fromarray(np.dstack([a, np.clip(alpha, 0, 255).astype(np.uint8)]), "RGBA")
    else:
        img = Image.fromarray(a, "RGB")
    img.save(os.path.join(OUT, name), optimize=True)


def shade(arr, k):
    return arr * k


def speckle(h, w, rng, p):
    return (rng.random((h, w)) < p).astype(np.float32)


# ---------------------------------------------------------------- themes
THEMES = {
    "bay": dict(asphalt="#50545F", line="#F4F4F0", centre="#F4F4F0", kerb=("#E0303A", "#F4F4F4"),
                wall=("#F2F2F2", "#2C7BE5"), shoulder="sand", ground="grass", water="sea",
                sky1="#2F7FD6", sky2="#BFE6FF", fog="#BFE6FF", isle=("#3D8F7A", "#57A88C"), seed=11),
    "harbor": dict(asphalt="#33353F", line="#E8E8EE", centre="#FFD23F", kerb=("#FF2E97", "#2E3040"),
                   wall=("#3A3F5A", "#00B8D9"), shoulder="concrete", ground="paving", water="night",
                   sky1="#07061C", sky2="#3B1E5C", fog="#2A1B4A", isle=("#14122E", "#1B1840"), seed=23),
    "ridge": dict(asphalt="#5A4C4C", line="#FFEBD0", centre="#FFE7C2", kerb=("#FF7A1A", "#FFF1D6"),
                  wall=("#FFE7C2", "#B23A2A"), shoulder="dirt", ground="rock", water="dunes",
                  sky1="#4B2A6E", sky2="#FF9A5A", fog="#F7A06A", isle=("#8A3B3B", "#A24A40"), seed=37),
}


# ---------------------------------------------------------------- materials (seamless, any size)
def mat_sand(w, h, rng, base="#E6D3A0"):
    n = fbm(w, h, 4, 4, rng, 5)
    c = mix(rgb(base) * 0.9, rgb(base) * 1.06, n)
    c *= (0.94 + 0.12 * rng.random((h, w)))[..., None]
    sp = speckle(h, w, rng, 0.015)
    c = mix(c, rgb("#FFFFFF"), sp * 0.5)
    sp = speckle(h, w, rng, 0.01)
    c = mix(c, rgb("#8E7A55"), sp * 0.6)
    return c


def mat_concrete(w, h, rng, base="#4A4F63", joint=64):
    n = fbm(w, h, 4, 4, rng, 5)
    c = mix(rgb(base) * 0.85, rgb(base) * 1.1, n)
    c *= (0.95 + 0.1 * rng.random((h, w)))[..., None]
    st = fbm(w, h, 3, 3, rng, 3)
    c = mix(c, c * 0.75, np.clip((st - 0.6) * 3, 0, 1))
    for y in range(0, h, joint):
        c[y:y + 2, :] *= 0.62
    return c


def mat_dirt(w, h, rng, base="#C97E4E"):
    n = fbm(w, h, 4, 4, rng, 5)
    c = mix(rgb(base) * 0.82, rgb(base) * 1.08, n)
    c *= (0.92 + 0.16 * rng.random((h, w)))[..., None]
    for _ in range(w * h // 300):
        x, y = rng.integers(0, w), rng.integers(0, h)
        r = rng.integers(1, 3)
        k = 0.7 if rng.random() < 0.5 else 1.18
        ys = np.arange(y - r, y + r + 1) % h
        xs = np.arange(x - r, x + r + 1) % w
        c[np.ix_(ys, xs)] *= k
    return c


def mat_grass(w, h, rng):
    n = fbm(w, h, 3, 3, rng, 5)
    c = mix(rgb("#4E9A3E"), rgb("#7CC45E"), n)
    blades = noise(w, h, w // 2, h // 8, rng)  # streaky blades
    c *= (0.82 + 0.3 * blades)[..., None]
    c *= (0.9 + 0.2 * rng.random((h, w)))[..., None]
    dry = fbm(w, h, 2, 2, rng, 3)
    c = mix(c, rgb("#A9B860"), np.clip((dry - 0.62) * 2.5, 0, 0.6))
    for col, p in (("#FFE15A", 0.0012), ("#FFFFFF", 0.0012)):
        c = mix(c, rgb(col), speckle(h, w, rng, p))
    return c


def mat_paving(w, h, rng):
    c = mat_concrete(w, h, rng, "#3C4258", joint=64)
    for x in range(0, w, 64):
        c[:, x:x + 2] *= 0.62
    oil = fbm(w, h, 4, 4, rng, 4)
    c = mix(c, c * 0.7, np.clip((oil - 0.66) * 4, 0, 1))
    return c


def mat_rock(w, h, rng):
    n = fbm(w, h, 3, 3, rng, 6)
    c = mix(rgb("#9C4E30"), rgb("#D07A4C"), n)
    cr = noise(w, h, 12, 12, rng)
    cracks = np.clip(1 - np.abs(cr - 0.5) * 30, 0, 1)
    c = mix(c, c * 0.55, cracks * 0.8)
    c *= (0.9 + 0.2 * rng.random((h, w)))[..., None]
    return c


def mat_sea(w, h, rng):
    n = fbm(w, h, 3, 3, rng, 4)
    c = mix(rgb("#168DB8"), rgb("#2BB7D6"), n)
    a = noise(w, h, 8, 8, rng)
    b = noise(w, h, 8, 8, rng)
    caust = np.clip(1 - np.abs(a - b) * 9, 0, 1) ** 2
    c = mix(c, rgb("#BFF4FF"), caust * 0.55)
    c = mix(c, rgb("#FFFFFF"), speckle(h, w, rng, 0.002))
    return c


def mat_night(w, h, rng):
    n = fbm(w, h, 3, 3, rng, 4)
    c = mix(rgb("#0E1430"), rgb("#1C2650"), n)
    streak = noise(w, h, 2, 32, rng)
    c = mix(c, rgb("#00C8E8"), np.clip((streak - 0.72) * 3, 0, 1) * 0.35)
    streak = noise(w, h, 2, 32, rng)
    c = mix(c, rgb("#FF3EA5"), np.clip((streak - 0.75) * 3, 0, 1) * 0.3)
    return c


def mat_dunes(w, h, rng):
    warp = fbm(w, h, 2, 2, rng, 3)
    yy = np.arange(h, dtype=np.float32)[:, None] / h
    rip = np.sin((yy * 10 + warp * 2.5) * 2 * np.pi) * 0.5 + 0.5
    n = fbm(w, h, 4, 4, rng, 4)
    c = mix(rgb("#B9683E"), rgb("#DE9461"), rip * 0.6 + n * 0.4)
    c *= (0.95 + 0.1 * rng.random((h, w)))[..., None]
    return c


MATS = {"sand": mat_sand, "concrete": mat_concrete, "dirt": mat_dirt, "grass": mat_grass, "paving": mat_paving,
        "rock": mat_rock, "sea": mat_sea, "night": mat_night, "dunes": mat_dunes}


# ---------------------------------------------------------------- road strip
def road(t, th):
    rng = np.random.default_rng(th["seed"])
    W, H = 512, 256
    img = np.zeros((H, W, 3), np.float32)
    # asphalt (u across the road)
    aw = 320
    base = rgb(th["asphalt"])
    n = fbm(aw, H, 5, 4, rng, 5)
    a = base[None, None, :] * (0.88 + 0.22 * n)[..., None]
    a *= (0.9 + 0.2 * rng.random((H, aw)))[..., None]
    a = mix(a, a * 1.35, speckle(H, aw, rng, 0.05))
    a = mix(a, a * 0.7, speckle(H, aw, rng, 0.03))
    # tyre wear along the two lanes
    u = np.arange(aw, dtype=np.float32) / aw
    wear = np.exp(-((u - 0.3) / 0.06) ** 2) + np.exp(-((u - 0.7) / 0.06) ** 2)
    wn = fbm(aw, H, 2, 6, rng, 3)
    a *= (1 - 0.13 * wear[None, :] * (0.6 + 0.6 * wn))[..., None]
    # patches and cracks
    for _ in range(3):
        px, py = rng.integers(40, aw - 90), rng.integers(0, H)
        pw, ph = rng.integers(30, 60), rng.integers(30, 70)
        ys = np.arange(py, py + ph) % H
        a[ys, px:px + pw] *= 0.94
    for _ in range(5):
        x, y = float(rng.integers(30, aw - 30)), float(rng.integers(0, H))
        for _ in range(rng.integers(20, 50)):
            xi, yi = int(x) % aw, int(y) % H
            a[yi, xi] *= 0.62
            x += rng.normal(0, 0.8)
            y += 1
    # painted lines (worn)
    wearn = fbm(aw, H, 16, 16, rng, 3)
    paint = np.clip((wearn - 0.08) * 6, 0, 1)

    def line(x0, x1, y0, y1, col):
        ys = np.arange(y0, y1) % H
        m = paint[ys, x0:x1][..., None] * 0.92
        a[ys, x0:x1] = a[ys, x0:x1] * (1 - m) + rgb(col) * (0.92 + 0.08 * wearn[ys, x0:x1, None]) * m

    line(12, 20, 0, H, th["line"])
    line(aw - 20, aw - 12, 0, H, th["line"])
    line(156, 164, 16, 112, th["centre"])
    if t == "harbor":
        line(150, 154, 16, 112, th["centre"])
        line(166, 170, 16, 112, th["centre"])
    img[:, :aw] = a
    img[:, aw:328] = a[:, aw - 1:aw]
    # kerb (u from the road edge outwards), 8 blocks of 32 rows
    k = np.zeros((H, 64, 3), np.float32)
    c1, c2 = rgb(th["kerb"][0]), rgb(th["kerb"][1])
    for b in range(8):
        k[b * 32:(b + 1) * 32] = c1 if b % 2 == 0 else c2
    xs = np.arange(64, dtype=np.float32) / 63
    bevel = 1.05 - 0.25 * np.clip((xs - 0.75) * 4, 0, 1) - 0.1 * np.clip((0.12 - xs) * 8, 0, 1)
    k *= bevel[None, :, None]
    for b in range(8):
        k[b * 32:b * 32 + 2] *= 0.7
    k *= (0.9 + 0.12 * fbm(64, H, 4, 16, rng, 3))[..., None]
    img[:, 328:392] = k
    img[:, 392:400] = k[:, 63:64]
    # barrier face (u from the bottom up), panels of 128 rows
    wl = np.zeros((H, 56, 3), np.float32)
    for p in range(2):
        wl[p * 128:(p + 1) * 128] = rgb(th["wall"][p])
    ux = np.arange(56, dtype=np.float32) / 55
    wl *= (0.82 + 0.22 * ux)[None, :, None]           # darker at the foot
    wl[:, 0:6] *= 0.55                                 # grime line on the ground
    wl[:, 50:56] = wl[:, 50:56] * 0.6 + 255 * 0.4 * (0.9 if t != "harbor" else 0.3)   # top cap
    wl[:, 20:24] *= 0.8                                # rail groove
    for p in range(2):
        wl[p * 128:p * 128 + 3] *= 0.5                 # panel seams
        for by in (32, 96):
            for bx in (12, 40):
                y = p * 128 + by
                wl[y - 2:y + 2, bx - 2:bx + 2] = wl[y - 2:y + 2, bx - 2:bx + 2] * 0.5 + 90
    wl *= (0.92 + 0.12 * fbm(56, H, 4, 8, rng, 3))[..., None]
    img[:, 400:456] = wl
    img[:, 456:464] = wl[:, 55:56]
    # shoulder
    sh = MATS[th["shoulder"]](64, H, rng)[:, :48]
    img[:, 464:512] = sh
    save(img, "road_%s.png" % t)


# ---------------------------------------------------------------- sky panorama
def sky(t, th):
    rng = np.random.default_rng(th["seed"] + 5)
    W, H, HZ = 512, 256, 192
    yy = np.arange(H, dtype=np.float32)[:, None] / HZ
    k = np.clip(yy, 0, 1) ** 1.6
    img = mix(np.broadcast_to(rgb(th["sky1"]), (H, W, 3)).copy(), np.broadcast_to(rgb(th["sky2"]), (H, W, 3)), np.broadcast_to(k, (H, W)))
    if t == "bay":
        n = fbm(W, H, 6, 3, rng, 5)
        band = np.exp(-((np.arange(H)[:, None] - 140) / 40.0) ** 2)
        cl = np.clip((n - 0.5) * 3.2, 0, 1) * band
        under = np.clip((n - 0.62) * 3, 0, 1)
        cloud = mix(np.broadcast_to(rgb("#FFFFFF"), (H, W, 3)), np.broadcast_to(rgb("#C9D9EA"), (H, W, 3)), under * 0.6)
        img = mix(img, cloud, cl * 0.92)
    elif t == "ridge":
        n = noise(W, H, 6, 24, rng) * 0.6 + noise(W, H, 12, 48, rng) * 0.4
        band = np.exp(-((np.arange(H)[:, None] - 120) / 50.0) ** 2)
        cl = np.clip((n - 0.52) * 3, 0, 1) * band
        hue = mix(np.broadcast_to(rgb("#FFB27A"), (H, W, 3)), np.broadcast_to(rgb("#C85A7A"), (H, W, 3)), np.broadcast_to(np.clip(1 - yy, 0, 1), (H, W)))
        img = mix(img, hue, cl * 0.8)
    else:
        n = fbm(W, H, 4, 6, rng, 4)
        band = np.exp(-((np.arange(H)[:, None] - 150) / 45.0) ** 2)
        img = mix(img, np.broadcast_to(rgb("#5A2D7A"), (H, W, 3)), np.clip((n - 0.55) * 2.5, 0, 1) * band * 0.6)
        for _ in range(140):
            x, y = rng.integers(0, W), rng.integers(0, 150)
            b = 120 + rng.integers(0, 135)
            img[y, x] = np.maximum(img[y, x], b)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                img[(y + dy) % H, (x + dx) % W] = np.maximum(img[(y + dy) % H, (x + dx) % W], b * 0.35)
        glow = np.exp(-((np.arange(H)[:, None] - HZ) / 24.0) ** 2)
        img = mix(img, np.broadcast_to(rgb("#B03A8A"), (H, W, 3)), np.broadcast_to(glow * 0.35, (H, W)))
    # distant land on the horizon, hazed towards the fog colour
    prof = noise(W, 1, 7, 1, rng)[0] * 0.65 + noise(W, 1, 23, 1, rng)[0] * 0.35
    fog = rgb(th["fog"])
    x = np.arange(W)
    if t == "harbor":
        hts = np.zeros(W)
        xx = 0
        while xx < W:
            bw = int(rng.integers(6, 18))
            hts[xx:xx + bw] = rng.integers(6, 34) * (0.4 + prof[xx])
            xx += bw
        for xi in range(W):
            top = int(HZ - hts[xi])
            img[top:HZ, xi] = mix(rgb(th["isle"][0]), fog, 0.25)
        for _ in range(260):
            xi = rng.integers(0, W)
            if hts[xi] > 4:
                yi = int(HZ - rng.uniform(2, hts[xi] - 1))
                img[yi, xi] = rgb(["#FFE7A3", "#7FF7FF", "#FFB3E6"][rng.integers(0, 3)])
    else:
        mask = np.clip((prof - (0.36 if t == "ridge" else 0.42)) * 2.2, 0, 1)
        if t == "ridge":
            mask = np.round(mask * 4) / 4   # flat mesa tops
        hts = mask * (40 if t == "ridge" else 26)
        hz = ((0.3, 1.0), (0.12, 0.65)) if t == "ridge" else ((0.6, 1.0), (0.35, 0.65))
        for layer, (haze, scale) in enumerate(hz):
            col = mix(rgb(th["isle"][layer % 2]), fog, haze)
            sh = np.roll(hts * scale, 90 * layer)
            for xi in range(W):
                top = int(HZ - sh[xi])
                if top < HZ:
                    img[top:HZ, xi] = col
    img[HZ:] = fog
    save(img, "sky_%s.png" % t)


# ---------------------------------------------------------------- props atlas (4x4 tiles of 128)
def props():
    rng = np.random.default_rng(7)
    S = 128
    atlas = np.zeros((512, 512, 3), np.float32)
    alpha = np.full((512, 512), 255.0, np.float32)

    def put(idx, arr, al=None):
        r, c = divmod(idx, 4)
        atlas[r * S:(r + 1) * S, c * S:(c + 1) * S] = arr
        if al is not None:
            alpha[r * S:(r + 1) * S, c * S:(c + 1) * S] = al

    # 0 palm trunk: rings
    n = fbm(S, S, 8, 4, rng, 4)
    tr = mix(rgb("#7A5A38"), rgb("#9E7A50"), n)
    yy = np.arange(S)[:, None]
    ring = (yy % 13) / 12.0
    tr *= (0.65 + 0.45 * np.clip(ring * 1.4, 0, 1))[..., None]
    tr *= (0.9 + 0.2 * noise(S, S, 32, 4, rng))[..., None]
    put(0, tr)
    # 1 palm frond on transparent (diamond mapping: base at the bottom centre, tip at the top centre)
    big = 4
    im = Image.new("L", (S * big, S * big), 0)
    d = ImageDraw.Draw(im)
    cx = S * big / 2
    for i in range(22):
        t = 0.04 + i / 22 * 0.9
        y = S * big * (1 - t)
        half = S * big / 2 * (1 - abs(1 - 2 * t))   # diamond half width at this height
        for s in (-1, 1):
            ln = half * 0.97
            tipx, tipy = cx + s * ln, y - ln * 0.45
            wdt = 4.5 * big * (1.1 - t * 0.5)
            d.polygon([(cx, y - wdt), (tipx, tipy), (cx, y + wdt)], fill=255)
    d.line([(cx, S * big), (cx, 0)], fill=255, width=int(3.5 * big))
    al = np.asarray(im.resize((S, S), Image.LANCZOS), np.float32)
    gn = fbm(S, S, 4, 4, rng, 3)
    fr = mix(rgb("#2E8F4A"), rgb("#58C068"), gn)
    xs = np.abs(np.arange(S) - S / 2)[None, :] / (S / 2)
    fr *= (1.08 - 0.3 * xs)[..., None]
    fr[:, 62:66] = rgb("#C8D47A")
    put(1, fr, np.where(al > 110, 255.0, 0.0))
    # 2 rock
    n = fbm(S, S, 3, 3, rng, 6)
    rk = mix(rgb("#7E7A74"), rgb("#B5B0A6"), n)
    cr = noise(S, S, 6, 6, rng)
    rk = mix(rk, rk * 0.5, np.clip(1 - np.abs(cr - 0.5) * 24, 0, 1))
    rk = mix(rk, rgb("#8FA070"), np.clip((fbm(S, S, 4, 4, rng, 3) - 0.66) * 3, 0, 0.5))
    put(2, rk)
    # 3 hut wall: planks and a window
    n = fbm(S, S, 2, 16, rng, 3)
    hw = mix(rgb("#D8BC8C"), rgb("#F0DDB2"), n)
    for y in range(0, S, 16):
        hw[y:y + 2] *= 0.6
    hw *= (0.92 + 0.12 * noise(S, S, 64, 8, rng))[..., None]
    hw[30:76, 40:88] = rgb("#5A3E22")
    hw[34:72, 44:84] = mix(rgb("#1C2E44"), rgb("#4A7090"), np.linspace(0, 1, 38)[:, None].repeat(40, 1))
    hw[34:72, 63:65] = rgb("#5A3E22")
    put(3, hw)
    # 4 thatch
    n = noise(S, S, 48, 3, rng)
    th = mix(rgb("#A8763A"), rgb("#E0B060"), n)
    th *= (0.85 + 0.25 * noise(S, S, 96, 6, rng))[..., None]
    for y in range(0, S, 22):
        th[y:y + 3] *= 0.7
    put(4, th)
    # 5 umbrella fabric: red / white (left half) and yellow / white (right half) stripes
    um = np.zeros((S, S, 3), np.float32)
    for x in range(S):
        half = x // 64
        stripe = (x % 64) // 8 % 2
        um[:, x] = rgb("#FFFFFF") if stripe else rgb(["#FF4A55", "#FFC93C"][half])
    um *= (0.8 + 0.25 * (np.arange(S)[:, None] / S))[..., None]
    put(5, um)
    # 6 glass tower facade (two floors, six windows across)
    fa = mix(rgb("#1A2038"), rgb("#2A3458"), fbm(S, S, 2, 2, rng, 3))
    for fl in range(2):
        for wx in range(6):
            x0, y0 = 4 + wx * 21, 8 + fl * 64
            lit = rng.random()
            col = rgb("#FFE7A3") if lit < 0.35 else (rgb("#7FF7FF") if lit < 0.45 else (rgb("#FFB3E6") if lit < 0.52 else None))
            if col is None:
                g = np.linspace(0, 1, 46)[:, None, None]
                fa[y0:y0 + 46, x0:x0 + 16] = mix(rgb("#22305A"), rgb("#3C5488"), g.repeat(16, 1)[..., 0])
            else:
                fa[y0:y0 + 46, x0:x0 + 16] = col * (0.85 + 0.15 * rng.random())
        fa[fl * 64:fl * 64 + 4] = rgb("#0E1222")
    put(6, fa)
    # 7 concrete facade with balconies
    fb = mat_concrete(S, S, rng, "#585E74", joint=64)
    for fl in range(2):
        y0 = fl * 64
        for wx in range(4):
            x0 = 8 + wx * 30
            lit = rng.random() < 0.45
            fb[y0 + 12:y0 + 44, x0:x0 + 22] = rgb("#FFD98A") * 0.95 if lit else rgb("#1E2438")
        fb[y0 + 46:y0 + 54] = rgb("#8A90A8")
        fb[y0 + 54:y0 + 56] = rgb("#2A2E40")
    put(7, fb)
    # 8 roof: gravel, parapet, a vent box
    rf = mat_concrete(S, S, rng, "#3A3E50", joint=256)
    rf *= (0.9 + 0.2 * rng.random((S, S)))[..., None]
    rf[:6] = rf[-6:] = rgb("#5A6078")
    rf[:, :6] = rf[:, -6:] = rgb("#5A6078")
    rf[40:70, 50:86] = rgb("#7A8098")
    rf[44:66, 54:82] = rgb("#5E6478")
    put(8, rf)
    # 9 mesa strata
    yy = np.arange(S, dtype=np.float32)[:, None]
    wob = fbm(S, S, 4, 2, rng, 3) * 10
    bands = np.sin((yy + wob) / S * 2 * np.pi * 5) * 0.5 + 0.5
    ms = mix(rgb("#A94A32"), rgb("#E08A55"), bands * 0.7 + fbm(S, S, 4, 4, rng, 4) * 0.3)
    streak = noise(S, S, 24, 2, rng)
    ms *= (0.85 + 0.2 * streak)[..., None]
    put(9, ms)
    # 10 cactus ribs
    xs = np.arange(S, dtype=np.float32)[None, :]
    rib = np.sin(xs / S * 2 * np.pi * 6) * 0.5 + 0.5
    ca = mix(rgb("#2F7A3E"), rgb("#5AB063"), np.broadcast_to(rib, (S, S)) * 0.8 + fbm(S, S, 4, 4, rng, 3) * 0.2)
    sp = speckle(S, S, rng, 0.02) * (rib > 0.8)
    ca = mix(ca, rgb("#F0F0C8"), sp)
    put(10, ca)
    # 11 start checker: 8 across, 4 along
    ck = np.zeros((S, S, 3), np.float32)
    for r in range(4):
        for c in range(8):
            ck[r * 32:(r + 1) * 32, c * 16:(c + 1) * 16] = rgb("#F4F4F4") if (r + c) % 2 == 0 else rgb("#1A1A1E")
    ck *= (0.9 + 0.12 * fbm(S, S, 8, 8, rng, 3))[..., None]
    put(11, ck)
    # 12 boost pad: chevrons pointing to the top of the tile (forward)
    big = 4
    im = Image.new("RGB", (S * big, S * big), (22, 30, 58))
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, S * big - 1, S * big - 1], outline=(0, 220, 255), width=6 * big)
    for k in range(3):
        y = (18 + k * 36) * big
        pts = [(16 * big, y + 30 * big), (64 * big, y), (112 * big, y + 30 * big), (112 * big, y + 44 * big),
               (64 * big, y + 14 * big), (16 * big, y + 44 * big)]
        d.polygon(pts, fill=(255, 196 - k * 30, 30))
    put(12, np.asarray(im.resize((S, S), Image.LANCZOS), np.float32))
    # 13 gantry banner: checker bands and arrows
    bn = np.zeros((S, S, 3), np.float32) + rgb("#1A1A24")
    for c in range(16):
        for r in range(2):
            col = rgb("#F4F4F4") if (r + c) % 2 == 0 else rgb("#101014")
            bn[r * 8:(r + 1) * 8, c * 8:(c + 1) * 8] = col
            bn[S - 16 + r * 8:S - 8 + r * 8, c * 8:(c + 1) * 8] = col
    big = 4
    im = Image.new("RGB", (S * big, (S - 32) * big), (26, 26, 36))
    d = ImageDraw.Draw(im)
    for k in range(4):
        x = (8 + k * 30) * big
        d.polygon([(x, 20 * big), (x + 14 * big, 20 * big), (x + 26 * big, 48 * big), (x + 14 * big, 76 * big),
                   (x, 76 * big), (x + 12 * big, 48 * big)], fill=(255, 90, 54))
    bn[16:S - 16] = np.asarray(im.resize((S, S - 32), Image.LANCZOS), np.float32)
    put(13, bn)
    # 14 metal
    mt = mix(rgb("#9AA0AE"), rgb("#D4D8E2"), noise(S, S, 3, 64, rng))
    mt *= (0.94 + 0.08 * rng.random((S, S)))[..., None]
    put(14, mt)
    # 15 plain white (tinted by vertex colours)
    put(15, np.full((S, S, 3), 246.0) + 9 * fbm(S, S, 8, 8, rng, 2)[..., None])
    save(atlas, "props.png", alpha)


# ---------------------------------------------------------------- cars
CARS = ["#2F80ED", "#27C26C", "#F2C94C", "#EB5757", "#9B51E0", "#F2994A", "#2D9CDB", "#E84393", "#6FCF97", "#BDBDBD"]


def car(hexcol, number):
    S, big = 256, 2
    paint = tuple(int(v) for v in rgb(hexcol))
    lum = 0.299 * paint[0] + 0.587 * paint[1] + 0.114 * paint[2]
    stripe = (34, 36, 44) if lum > 150 else (246, 246, 246)
    dark = tuple(int(v * 0.55) for v in paint)
    light = tuple(min(255, int(v * 1.15 + 20)) for v in paint)
    im = Image.new("RGB", (S * big, S * big), paint)
    d = ImageDraw.Draw(im)
    B = big

    def R(x0, y0, x1, y1, col, **kw):
        d.rectangle([x0 * B, y0 * B, x1 * B - 1, y1 * B - 1], fill=col, **kw)

    # SIDE (0,0)-(256,64): u along the car (rear -> front), v from the top edge down
    for y in range(64):
        k = 1.12 - 0.3 * (y / 63)
        R(0, y, 256, y + 1, tuple(min(255, int(c * k)) for c in paint))
    R(0, 52, 256, 64, (26, 27, 32))                                   # sill
    d.polygon([(0, 20 * B), (256 * B, 14 * B), (256 * B, 24 * B), (0, 30 * B)], fill=stripe)   # side stripe
    d.line([(98 * B, 4 * B), (98 * B, 52 * B)], fill=dark, width=B)  # door seams
    d.line([(162 * B, 4 * B), (162 * B, 52 * B)], fill=dark, width=B)
    d.ellipse([(130 - 16) * B, (30 - 16) * B, (130 + 16) * B, (30 + 16) * B], fill=(246, 246, 246), outline=(30, 30, 30), width=2 * B)
    font = ImageFont.load_default(size=22 * B)
    txt = str(number)
    bb = d.textbbox((0, 0), txt, font=font)
    d.text((130 * B - (bb[0] + bb[2]) / 2, 30 * B - (bb[1] + bb[3]) / 2), txt, fill=(20, 20, 24), font=font)
    d.polygon([(176 * B, 40 * B), (196 * B, 40 * B), (190 * B, 48 * B), (176 * B, 48 * B)], fill=(20, 20, 24))  # vent
    # TOP (0,64)-(256,128): u along the car (rear -> front), v across
    for y in range(64, 128):
        k = 1.12 - 0.12 * abs((y - 96) / 32)
        R(0, y, 256, y + 1, tuple(min(255, int(c * k)) for c in paint))
    R(0, 88, 256, 94, stripe)
    R(0, 98, 256, 104, stripe)
    d.line([(196 * B, 66 * B), (196 * B, 126 * B)], fill=dark, width=B)   # bonnet line
    d.line([(26 * B, 66 * B), (26 * B, 126 * B)], fill=dark, width=B)     # boot line
    R(214, 74, 236, 82, (24, 24, 30)); R(214, 110, 236, 118, (24, 24, 30))  # bonnet vents
    # FRONT (0,128)-(128,176): u across the car, v from the top
    R(0, 128, 128, 176, paint)
    R(30, 146, 98, 166, (20, 20, 26))                                 # grille
    for x in range(32, 98, 6):
        d.line([(x * B, 147 * B), (x * B, 165 * B)], fill=(60, 62, 70), width=B)
    R(4, 136, 26, 148, (40, 40, 48)); R(102, 136, 124, 148, (40, 40, 48))   # light housings
    R(0, 168, 128, 176, (22, 22, 26))                                 # splitter
    R(58, 128, 64, 146, stripe); R(66, 128, 72, 146, stripe)
    # REAR (128,128)-(256,176)
    R(128, 128, 256, 176, paint)
    R(132, 136, 160, 148, (90, 10, 18)); R(224, 136, 252, 148, (90, 10, 18))  # tail light housings
    R(128, 160, 256, 176, (24, 24, 28))                               # diffuser
    for ex in (172, 212):
        d.ellipse([(ex - 6) * B, 160 * B, (ex + 6) * B, 172 * B], fill=(150, 150, 160), outline=(40, 40, 40), width=B)
    # GLASS (0,176)-(128,224)
    for y in range(176, 224):
        k = (y - 176) / 47
        R(0, y, 128, y + 1, (int(18 + 30 * k), int(26 + 40 * k), int(44 + 60 * k)))
    d.polygon([(20 * B, 224 * B), (44 * B, 176 * B), (60 * B, 176 * B), (36 * B, 224 * B)], fill=(120, 150, 190))
    d.rectangle([0, 176 * B, 128 * B - 1, 224 * B - 1], outline=dark, width=3 * B)
    # ROOF (128,176)-(256,224)
    R(128, 176, 256, 224, light)
    R(128, 194, 256, 198, stripe); R(128, 202, 256, 206, stripe)
    # TYRE (0,224)-(128,256): u around, v across the tread
    R(0, 224, 128, 256, (24, 24, 28))
    for x in range(0, 128, 8):
        R(x, 228, x + 4, 252, (40, 40, 46))
    # RIM (128,224)-(160,256): spokes
    R(128, 224, 160, 256, (24, 24, 28))
    c0 = (144 * B, 240 * B)
    d.ellipse([c0[0] - 15 * B, c0[1] - 15 * B, c0[0] + 15 * B, c0[1] + 15 * B], fill=(200, 205, 216))
    for k in range(5):
        a = k / 5 * 2 * np.pi
        d.line([c0, (c0[0] + np.cos(a) * 14 * B, c0[1] + np.sin(a) * 14 * B)], fill=(110, 116, 130), width=3 * B)
    d.ellipse([c0[0] - 4 * B, c0[1] - 4 * B, c0[0] + 4 * B, c0[1] + 4 * B], fill=paint)
    # DARK (160,224)-(256,256): underbody, struts
    R(160, 224, 256, 256, (30, 31, 36))
    out = im.resize((S, S), Image.LANCZOS)
    out.save(os.path.join(OUT, "car_%s.png" % hexcol.lstrip("#").upper()), optimize=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for t, th in THEMES.items():
        road(t, th)
        sky(t, th)
        rng = np.random.default_rng(th["seed"] + 1)
        save(MATS[th["ground"]](256, 256, rng), "ground_%s.png" % t)
        save(MATS[th["water"]](256, 256, rng), "water_%s.png" % t)
    props()
    for i, c in enumerate(CARS):
        car(c, [7, 3, 9, 12, 21, 5, 17, 33, 44, 8][i])
    total = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print("textures written to %s (%d files, %.0f KB)" % (OUT, len(os.listdir(OUT)), total / 1024))


if __name__ == "__main__":
    main()
