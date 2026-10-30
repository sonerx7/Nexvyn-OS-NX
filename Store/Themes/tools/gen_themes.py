#!/usr/bin/env python3
"""Generates the Nexvyn OS App Market themes (format: Nexvyn OS docs/NXVAPP_FORMAT.md section 9).

For every theme below it writes Store/Themes/<slug>/:
    source/theme.json            the package manifest
    source/wallpaper.jpg         1280x720 (and wallpaper-dark.jpg for themes that follow the light/dark appearance)
    source/sounds/<name>.wav     UI sounds (only Retro Terminal)
    icon.png                     256 px preview tile: the wallpaper (light/dark split) with the accent color
    store.json                   App Market subtitle and description (en, tr, de, fr, es)
    README.md                    Turkish + English

The .nxvtheme packages are not built here (tools/build_store.py zips source/).

Usage:
    python Store/Themes/tools/gen_themes.py            # every theme
    python Store/Themes/tools/gen_themes.py aurora     # selected slugs

Needs Python 3, Pillow and numpy. Deterministic (fixed seeds).
"""
import json
import math
import os
import struct
import sys
import wave

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
THEMES_DIR = os.path.dirname(HERE)
REPO = os.path.dirname(os.path.dirname(THEMES_DIR))
W, H = 1280, 720
SS = 2  # supersampling
AUTHOR = "Soner Çakır (sonerx7)"


# ==========================================================================
# colour helpers
# ==========================================================================
def rgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def _lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


def to_oklab(c):
    r, g, b = _lin(np.asarray(c, np.float64))
    l = np.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
    m = np.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
    s = np.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
    return np.array([0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                     1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s])


def from_oklab(L):
    l_ = L[..., 0] + 0.3963377774 * L[..., 1] + 0.2158037573 * L[..., 2]
    m_ = L[..., 0] - 0.1055613458 * L[..., 1] - 0.0638541728 * L[..., 2]
    s_ = L[..., 0] - 0.0894841775 * L[..., 1] - 1.2914855480 * L[..., 2]
    l, m, s = l_ ** 3, m_ ** 3, s_ ** 3
    r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    return _srgb(np.stack([r, g, b], -1)).astype(np.float32)


def ramp(t, stops):
    """Colour gradient through (position, "#hex") stops, interpolated in OKLab. t: array -> t.shape + (3,)."""
    t = np.clip(np.asarray(t, np.float32), 0, 1)
    pos = np.array([s[0] for s in stops], np.float32)
    labs = np.array([to_oklab(rgb(s[1])) for s in stops], np.float32)
    out = np.empty(t.shape + (3,), np.float32)
    for k in range(3):
        out[..., k] = np.interp(t, pos, labs[:, k])
    return from_oklab(out)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def _box(a, r, axis):
    if r < 1:
        return a
    pad = [(0, 0)] * a.ndim
    pad[axis] = (r + 1, r)
    c = np.cumsum(np.pad(a, pad, mode="edge"), axis=axis, dtype=np.float64)
    n = a.shape[axis]
    hi = np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=axis)
    lo = np.take(c, np.arange(0, n), axis=axis)
    return ((hi - lo) / (2 * r + 1)).astype(np.float32)


def blur(a, sigma, axes=(0, 1)):
    """Gaussian blur approximated by three box passes per axis."""
    r = int(round((math.sqrt(4 * sigma * sigma + 1) - 1) / 2))
    for axis in axes:
        for _ in range(3):
            a = _box(a, r, axis)
    return a


def sines(xs, terms, base=0.0, tilt=0.0):
    y = base + tilt * (xs - W / 2)
    for amp, wl, ph in terms:
        y = y + amp * np.sin(2 * math.pi * xs / wl + ph)
    return y.astype(np.float32)


# ==========================================================================
# canvas
# ==========================================================================
class WP:
    def __init__(self, seed):
        self.Wp, self.Hp = W * SS, H * SS
        yy, xx = np.mgrid[0:self.Hp, 0:self.Wp].astype(np.float32)
        self.x = (xx + 0.5) / SS  # 1x pixel units
        self.y = (yy + 0.5) / SS
        self.xs = self.x[0]
        self.img = np.zeros((self.Hp, self.Wp, 3), np.float32)
        self.rng = np.random.RandomState(seed)

    def vgrad(self, stops, y0=0.0, y1=H):
        col = ramp((self.y[:, :1] - y0) / (y1 - y0), stops)
        return np.broadcast_to(col, (self.Hp, self.Wp, 3)).copy()

    def over(self, col, a):
        a = np.clip(a, 0, 1)[..., None]
        self.img = self.img * (1 - a) + col * a

    def add(self, col, a):
        self.img = self.img + np.asarray(col, np.float32) * np.clip(a, 0, None)[..., None]

    def layer(self, f, col, shadow=(0.0, 30.0), glow=None, rim=None, shadow_col="#000000"):
        """Fills everything below the edge curve f (1D over x): soft shadow above, glow and rim on the edge."""
        fy = f[None, :]
        slope = np.gradient(f, self.xs)
        d = (self.y - fy) / np.sqrt(1 + slope ** 2)[None, :]
        if shadow and shadow[0] > 0:
            sa = shadow[0] * np.exp(-np.maximum(-d, 0) / shadow[1]) * (d < 0.5)
            self.img = self.img * (1 - sa[..., None]) + rgb(shadow_col) * sa[..., None]
        cov = np.clip(d * SS + 0.5, 0, 1)
        self.over(col, cov)
        if glow:
            self.over(rgb(glow[2]), glow[0] * np.exp(-np.maximum(d, 0) / glow[1]) * cov)
        if rim:
            self.over(rgb(rim[2]), rim[0] * np.exp(-((d - rim[1] * 0.5) / rim[1]) ** 2) * cov)
        return cov

    def stamp(self, cx, cy, rad, cov_fn, col, alpha=1.0, mode="over"):
        """Draws a small shape: cov_fn(dx, dy) gives coverage in a window of radius rad around (cx, cy)."""
        x0, x1 = max(0, int((cx - rad) * SS)), min(self.Wp, int((cx + rad) * SS) + 1)
        y0, y1 = max(0, int((cy - rad) * SS)), min(self.Hp, int((cy + rad) * SS) + 1)
        if x0 >= x1 or y0 >= y1:
            return
        dx = self.x[y0:y1, x0:x1] - cx
        dy = self.y[y0:y1, x0:x1] - cy
        a = (np.clip(cov_fn(dx, dy), 0, 1) * alpha)[..., None]
        c = col(dx, dy) if callable(col) else col
        sub = self.img[y0:y1, x0:x1]
        if mode == "add":
            sub += c * a
        elif mode == "multiply":
            sub *= 1 - a * (1 - c)
        else:
            sub[:] = sub * (1 - a) + c * a

    def finish(self, path, grain=1.8, quality=90):
        a = self.img.reshape(H, SS, W, SS, 3).mean((1, 3)) * 255.0
        save_jpg(a, path, grain, quality)
        return np.clip(a, 0, 255).astype(np.uint8)


def save_jpg(a, path, grain, quality=90):
    rng = np.random.RandomState(1234)
    n = rng.uniform(-grain, grain, (H, W, 1)).astype(np.float32)
    n = n + rng.uniform(-grain * 0.35, grain * 0.35, (H, W, 3)).astype(np.float32)
    im = Image.fromarray(np.clip(a + n + 0.5, 0, 255).astype(np.uint8), "RGB")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, quality=quality, subsampling=0, optimize=True)


def disc(r, soft=0.0):
    """Coverage of a circle of radius r (antialiased, or with a soft edge `soft` px wide)."""
    def f(dx, dy):
        d = r - np.sqrt(dx * dx + dy * dy)
        return np.clip(d / soft + 0.5, 0, 1) if soft > 0 else np.clip(d * SS + 0.5, 0, 1)
    return f


def stars(p, n, ymax=H, bright=1.0, big=0.02):
    rng = p.rng
    acc = np.zeros((p.Hp, p.Wp), np.float32)
    for x, y, b in zip(rng.uniform(0, W, n), rng.uniform(0, ymax, n), rng.uniform(0.15, 1.0, n) ** 2.2 * bright):
        ix, iy = int(x * SS), int(y * SS)
        if 0 <= ix < p.Wp and 0 <= iy < p.Hp:
            acc[iy, ix] += b * 3.0
    acc = blur(acc, 0.7)
    glow = np.zeros_like(acc)
    for _ in range(int(n * big)):
        ix, iy = int(rng.uniform(0, W) * SS), int(rng.uniform(0, ymax * 0.8) * SS)
        glow[iy, ix] += rng.uniform(4, 9)
    glow = blur(glow, 1.2) + blur(glow, 5.0) * 0.6
    return np.clip(acc + glow, 0, 1.5)


def noise1d(n, sigma, rng):
    v = blur(rng.randn(n).astype(np.float32)[None, :], sigma, axes=(1,))[0]
    return v / (np.abs(v).max() + 1e-6)


def glow_at(p, cx, cy, rx, ry=None):
    ry = ry or rx
    return np.exp(-(((p.x - cx) / rx) ** 2 + ((p.y - cy) / ry) ** 2))


def reflect(p, water_y, tint, depth_dark=0.55, ripple=2.5):
    """Mirrors the picture above water_y into the water below it, with ripples and a tint."""
    wl = int(water_y * SS)
    rows = np.arange(wl, p.Hp)
    src = np.clip(2 * wl - rows - 1, 0, p.Hp - 1)
    out = p.img[src].copy()
    for k, r in enumerate(rows):
        t = (r - wl) / max(1, p.Hp - wl)
        shift = int(round(math.sin(r * 0.45) * ripple * SS * (0.3 + t)))
        if shift:
            out[k] = np.roll(out[k], shift, axis=0)
    t = ((rows - wl) / max(1, p.Hp - wl))[:, None, None]
    out = out * (1 - depth_dark * (0.4 + 0.6 * t)) + rgb(tint) * (0.25 + 0.35 * t)
    p.img[wl:] = out
    p.add(np.array([1, 1, 1], np.float32) * 0.12, np.exp(-((p.y - water_y) / 1.2) ** 2))


# ==========================================================================
# wallpapers
# ==========================================================================
def wp_aurora(out):
    p = WP(11)
    rng = p.rng
    p.img = p.vgrad([(0, "#020511"), (0.42, "#05132E"), (0.72, "#0A2A3F"), (1, "#0B2A35")])
    p.add(rgb("#DDE8FF"), stars(p, 800, ymax=520, bright=0.85) * 0.7)
    rays, rays2 = noise1d(p.Wp, 14.0, rng), noise1d(p.Wp, 60.0, rng)
    curtains = [(300, [(90, 1500, 0.5), (30, 560, 2.0)], 1.0, 90.0, -0.10),
                (370, [(60, 1200, 2.6), (22, 470, 0.9)], 0.65, 60.0, -0.05),
                (230, [(70, 1800, 4.0), (20, 640, 3.3)], 0.45, 70.0, -0.16)]
    acc = np.zeros_like(p.img)
    for base, terms, k, up, tilt in curtains:
        c = sines(p.xs, terms, base, tilt)[None, :]
        d = p.y - c
        prof = np.where(d > 0, np.exp(-(np.maximum(d, 0) / 7.0) ** 2),
                        np.exp(-np.maximum(-d, 0) / up) * (0.85 + 0.15 * np.exp(-np.maximum(-d, 0) / 12.0)))
        mod = (0.78 + 0.22 * rays[None, :]) * (0.55 + 0.45 * (0.5 + 0.5 * rays2[None, :]))
        env = 0.35 + 0.65 * np.exp(-((p.xs - 760) / 560) ** 2)[None, :]
        h = np.clip(-d / (up * 2.2), 0, 1)
        col = ramp(h, [(0, "#B5FFE0"), (0.2, "#3DDC97"), (0.55, "#18A8A8"), (1, "#7A4BFF")])
        acc += col * (prof * mod * env * k)[..., None]
    acc = acc + blur(acc, 18.0) * 0.6
    p.img = p.img + (1 - np.exp(-acc * 1.2)) * 0.95
    p.add(rgb("#1E6F5C") * 0.25, np.exp(-((p.y - 560) / 80) ** 2))
    m1 = sines(p.xs, [(40, 700, 0.3), (22, 260, 1.7), (7, 90, 0.4)], 548, -0.03)
    p.layer(m1, rgb("#0A1B26"), glow=(0.30, 5.0, "#2E8F7E"), rim=(0.35, 1.0, "#5FD8B5"))
    m2 = sines(p.xs, [(26, 900, 2.3), (14, 330, 0.2), (5, 70, 2.0)], 588, 0.04)
    p.layer(m2, rgb("#03090E"), glow=(0.12, 5.0, "#1A5A55"))
    reflect(p, 612, "#03141C", depth_dark=0.5)
    return p.finish(out)


def sakura(out, dark):
    p = WP(21)
    rng = p.rng
    if not dark:
        p.img = p.vgrad([(0, "#FFF7F9"), (0.5, "#FCE3EB"), (1, "#F5CCDA")])
        p.add(rgb("#FFFFFF") * 0.6, glow_at(p, 1010, 160, 330))
        hills = [("#EDC6D4", "#FBE9F0"), ("#E2AFC4", "#F8DDE8")]
        branch_c, petal_out, petal_in, stamen = rgb("#5E3B45"), "#F6A9C3", "#FFF5F8", rgb("#D64F7E")
        falling, bokeh = rgb("#F4A3BE"), rgb("#FFFFFF")
    else:
        p.img = p.vgrad([(0, "#0D0A1E"), (0.55, "#1D1533"), (1, "#3A2142")])
        p.add(rgb("#DDE6FF"), stars(p, 260, ymax=420, bright=0.6) * 0.5)
        p.add(rgb("#FFE6F0") * 0.35, glow_at(p, 1010, 160, 260))
        p.stamp(1010, 160, 44, disc(36), lambda dx, dy: ramp(0.5 + dy / 72.0, [(0, "#FFF8FB"), (1, "#F6D9E6")]))
        hills = [("#2A1B34", "#3E2649"), ("#1E1328", "#2E1C38")]
        branch_c, petal_out, petal_in, stamen = rgb("#140B12"), "#E585AA", "#FFD6E5", rgb("#FFE08A")
        falling, bokeh = rgb("#F08DB4"), rgb("#FF9CC4")
    # distant hills in the mist
    for i, (col, fog) in enumerate(hills):
        f = sines(p.xs, [(28 - 6 * i, 900 + 300 * i, 0.7 + 1.9 * i), (10, 330, 2.1 * i)], 545 + 55 * i, -0.04 + 0.05 * i)
        p.layer(f, rgb(col))
        p.over(rgb(fog), 0.45 * np.exp(-((p.y - f[None, :] - 30) / 60) ** 2))
    # the branch: a cubic curve from the top-left corner, thinner towards the tip, with three twigs
    mask = np.zeros((p.Hp, p.Wp), np.float32)

    def stroke(pts, w0, w1):
        n = 260
        t = np.linspace(0, 1, n)
        (ax, ay), (bx, by), (cx_, cy_), (dx_, dy_) = pts
        xs = (1 - t) ** 3 * ax + 3 * (1 - t) ** 2 * t * bx + 3 * (1 - t) * t ** 2 * cx_ + t ** 3 * dx_
        ys = (1 - t) ** 3 * ay + 3 * (1 - t) ** 2 * t * by + 3 * (1 - t) * t ** 2 * cy_ + t ** 3 * dy_
        for x, y, w in zip(xs, ys, w0 + (w1 - w0) * t ** 0.8):
            r = w / 2
            x0, x1 = max(0, int((x - r - 1) * SS)), min(p.Wp, int((x + r + 1) * SS) + 1)
            y0, y1 = max(0, int((y - r - 1) * SS)), min(p.Hp, int((y + r + 1) * SS) + 1)
            if x0 < x1 and y0 < y1:
                d = r - np.sqrt((p.x[y0:y1, x0:x1] - x) ** 2 + (p.y[y0:y1, x0:x1] - y) ** 2)
                mask[y0:y1, x0:x1] = np.maximum(mask[y0:y1, x0:x1], np.clip(d * SS + 0.5, 0, 1))
        return list(zip(xs, ys))

    main = stroke([(-40, 70), (220, 120), (430, 300), (820, 250)], 30, 5)
    twigs = [stroke([main[70], (main[70][0] + 40, main[70][1] + 90), (main[70][0] + 110, main[70][1] + 120),
                     (main[70][0] + 170, main[70][1] + 175)], 11, 3),
             stroke([main[140], (main[140][0] + 30, main[140][1] - 70), (main[140][0] + 90, main[140][1] - 110),
                     (main[140][0] + 150, main[140][1] - 120)], 9, 3),
             stroke([main[200], (main[200][0] + 50, main[200][1] + 50), (main[200][0] + 90, main[200][1] + 60),
                     (main[200][0] + 140, main[200][1] + 95)], 7, 2.5)]
    p.over(np.array([0, 0, 0], np.float32), blur(mask, 6.0) * (0.10 if not dark else 0.3))
    shade = ramp(np.clip(p.y / 400, 0, 1), [(0, "#FFFFFF"), (1, "#000000")]) * 0.15
    p.over(branch_c + shade * (0.4 if not dark else 0.3), mask)
    # blossoms along the branch and the twigs
    spots = main[60::9] + [pt for tw in twigs for pt in tw[40::22]]
    for k, (bx, by) in enumerate(spots):
        for _ in range(2 if k % 3 else 3):
            cx, cy = bx + rng.uniform(-26, 26), by + rng.uniform(-24, 22)
            r = rng.uniform(9, 19)
            if rng.rand() < 0.22:  # a bud
                p.stamp(cx, cy, r, disc(r * 0.38), rgb(petal_out) * 0.85)
                continue
            rot = rng.uniform(0, 2 * math.pi)

            def petals(dx, dy, r=r, rot=rot):
                m = np.zeros_like(dx)
                for i in range(5):
                    a = rot + i * 2 * math.pi / 5
                    px, py = math.cos(a) * r * 0.52, math.sin(a) * r * 0.52
                    m = np.maximum(m, np.clip((r * 0.5 - np.sqrt((dx - px) ** 2 + (dy - py) ** 2)) * SS + 0.5, 0, 1))
                return m

            p.stamp(cx + 2, cy + 3, r * 1.4, disc(r, soft=6), np.array([0, 0, 0], np.float32), 0.10 if not dark else 0.25)
            p.stamp(cx, cy, r * 1.1, petals,
                    lambda dx, dy, r=r: ramp(np.sqrt(dx * dx + dy * dy) / r, [(0, petal_in), (0.45, petal_in), (1, petal_out)]))
            p.stamp(cx, cy, r * 0.3, disc(r * 0.18), stamen)
            if dark:
                p.stamp(cx, cy, r * 2.5, disc(r * 1.6, soft=r * 1.5), bokeh * 0.25, 0.5, mode="add")
    # falling petals and blurred bokeh
    for _ in range(26):
        cx, cy, r = rng.uniform(0, W), rng.uniform(0, H), rng.uniform(18, 46)
        p.stamp(cx, cy, r * 1.6, disc(r, soft=r * 0.9), bokeh, rng.uniform(0.10, 0.22) if not dark else 0.12)
    for _ in range(70):
        cx, cy = rng.uniform(380, W), rng.uniform(80, H)
        a, b, rot = rng.uniform(4, 9), rng.uniform(2.5, 5), rng.uniform(0, math.pi)
        ca, sa = math.cos(rot), math.sin(rot)

        def ell(dx, dy, a=a, b=b, ca=ca, sa=sa):
            u, v = dx * ca + dy * sa, -dx * sa + dy * ca
            return np.clip((1 - np.sqrt((u / a) ** 2 + (v / b) ** 2)) * a * SS + 0.5, 0, 1)

        p.stamp(cx, cy, a + 2, ell, falling, rng.uniform(0.55, 0.95))
    return p.finish(out)


def ocean(out, dark):
    p = WP(31)
    rng = p.rng
    hz = 330
    if not dark:
        p.img = p.vgrad([(0, "#3E9FDF"), (0.7, "#A9DCF7"), (1, "#E2F5FF")], 0, hz)
        p.add(rgb("#FFF4D8") * 0.38, glow_at(p, 900, 190, 200, 160))
        p.stamp(900, 190, 60, disc(36, soft=3), rgb("#FFF6D6") * 0.55, mode="add")
        for _ in range(9):  # soft clouds
            cx, cy = rng.uniform(0, W), rng.uniform(70, 250)
            for k in range(7):
                rx, ry = rng.uniform(40, 110), rng.uniform(18, 34)
                ox, oy = cx + rng.uniform(-120, 120), cy + rng.uniform(-12, 12)
                p.stamp(ox, oy, rx * 1.5, lambda dx, dy, rx=rx, ry=ry: np.clip(1.4 - np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2), 0, 1),
                        rgb("#FFFFFF"), 0.35)
        sea = [(0, "#8ED8EA"), (0.18, "#36AFD6"), (0.55, "#0C7FB5"), (1, "#05568A")]
        spec_col, spec_k, sky_bounce = rgb("#FFFFFF"), 1.3, rgb("#CFF2FF")
        sun_x = 900
    else:
        p.img = p.vgrad([(0, "#02050E"), (0.7, "#0B1F3D"), (1, "#173A63")], 0, hz)
        p.add(rgb("#E4ECFF"), stars(p, 600, ymax=hz - 20, bright=0.8) * 0.65)
        p.add(rgb("#BFD6FF") * 0.45, glow_at(p, 900, 170, 200))
        p.stamp(900, 170, 50, disc(34), lambda dx, dy: ramp(0.5 + (dx + dy) / 96.0, [(0, "#FFFFFF"), (1, "#C9D8EE")]))
        sea = [(0, "#1D3B60"), (0.15, "#0E2645"), (0.6, "#06152B"), (1, "#020914")]
        spec_col, spec_k, sky_bounce = rgb("#D6E6FF"), 1.1, rgb("#1D3B60")
        sun_x = 900
    below = p.y > hz
    d = np.maximum(p.y - hz, 0.5)
    seacol = ramp((p.y - hz) / (H - hz), sea)
    # waves in perspective: depth Z from the horizon, X across
    Z = 2400.0 / d
    X = (p.x - 640) * Z / 900.0
    shade = np.zeros_like(Z)
    for i in range(7):
        ang = rng.uniform(-0.6, 0.6)
        k = rng.uniform(0.6, 1.6) * (1 + i * 0.35)
        shade += math.sqrt(1.0 / (1 + i)) * np.cos(k * (math.sin(ang) * X + math.cos(ang) * Z) + rng.uniform(0, 6.3))
    fade = np.exp(-Z / 260.0)
    shade = shade * fade / 2.2
    col = seacol * (1 + 0.16 * shade)[..., None] + sky_bounce * (0.18 * np.exp(-d / 26.0))[..., None]
    column = np.exp(-((p.x - sun_x) / (24 + d * 0.55)) ** 2)
    spec = np.clip(shade, 0, None) ** 3 * (0.25 + column * 1.6 * np.exp(-d / 260.0)) * spec_k
    spec = spec * (1 - 0.75 * smoothstep(150.0, 390.0, d))  # no glare blob at the bottom edge
    col = col + spec_col * np.clip(spec, 0, 1.2)[..., None]
    col = col + spec_col * (0.22 * column * np.exp(-d / 220.0))[..., None]
    p.img = np.where(below[..., None], col, p.img)
    p.add(np.array([1, 1, 1], np.float32) * (0.10 if not dark else 0.05), np.exp(-((p.y - hz) / 1.5) ** 2))
    return p.finish(out)


def treeline(xs, base_y, terms, rng, density, hmin, hmax, wfac=0.30):
    ridge = sines(xs, terms, base_y)
    top = ridge.copy()
    n = int(W * density)
    xi = rng.uniform(-30, W + 30, n)
    hi = rng.uniform(hmin, hmax, n)
    wi = hi * wfac * rng.uniform(0.8, 1.25, n)
    ri = np.interp(xi, xs, ridge)
    for x0, h, w, r in zip(xi, hi, wi, ri):
        dxa = np.abs(xs - x0)
        cand = r - h + dxa * h / w
        # stepped branches: the outline jumps out a little every quarter of the height
        cand -= h * 0.07 * ((dxa / w * 4) % 1.0) * (dxa < w)
        top = np.minimum(top, cand)
    return top.astype(np.float32)


def forest(out, dark):
    p = WP(41)
    rng = p.rng
    if not dark:
        p.img = p.vgrad([(0, "#B9D8E2"), (0.5, "#E5EEE6"), (1, "#F6EBD3")])
        p.add(rgb("#FFF1D0") * 0.3, glow_at(p, 430, 250, 200, 160))
        p.stamp(430, 250, 40, disc(26, soft=3), rgb("#FFF6DC") * 0.5, mode="add")
        cols = ["#AFC9C3", "#8DB2A9", "#638F82", "#3D6758", "#1D3E32"]
        fog = rgb("#EEF3EC")
        fog_k = [0.65, 0.55, 0.45, 0.32, 0.0]
    else:
        p.img = p.vgrad([(0, "#040912"), (0.6, "#0E1D2D"), (1, "#1A2E3E")])
        p.add(rgb("#E4ECFF"), stars(p, 700, ymax=420, bright=0.8) * 0.6)
        p.add(rgb("#C8DAF0") * 0.35, glow_at(p, 930, 150, 220))
        p.stamp(930, 150, 40, disc(26), lambda dx, dy: ramp(0.5 + (dx + dy) / 70.0, [(0, "#FFFFFF"), (1, "#CBD9EA")]))
        cols = ["#1E3242", "#182A37", "#12212C", "#0C171F", "#060C11"]
        fog = rgb("#2B4558")
        fog_k = [0.55, 0.45, 0.35, 0.25, 0.0]
    layers = [(400, 0.10, 20, 46), (455, 0.09, 28, 62), (515, 0.075, 40, 86), (585, 0.06, 60, 118), (665, 0.05, 90, 170)]
    for i, (by, dens, hmin, hmax) in enumerate(layers):
        terms = [(30 + 6 * i, 1100 + 200 * i, 0.9 * i + 0.3), (12, 420 + 40 * i, 1.7 * i)]
        top = treeline(p.xs, by, terms, rng, dens, hmin, hmax)
        p.layer(top, rgb(cols[i]))
        if fog_k[i] > 0:
            p.over(fog, fog_k[i] * np.exp(-((p.y - by - 25) / 70.0) ** 2))
    if not dark:  # morning light shafts through the mist
        ang = np.arctan2(p.x - 430, p.y - 250)
        rays = np.zeros_like(ang)
        for _ in range(12):
            rays += rng.uniform(0.4, 1.0) * np.exp(-((ang - rng.uniform(-1.2, 1.2)) / rng.uniform(0.02, 0.06)) ** 2)
        p.add(rgb("#FFF4DA") * 0.10, rays * (p.y > 250) * np.exp(-np.maximum(p.y - 250, 0) / 420.0))
    else:  # fireflies over the nearest trees
        for _ in range(46):
            cx, cy = rng.uniform(0, W), rng.uniform(520, H - 10)
            p.stamp(cx, cy, 16, disc(7, soft=8), rgb("#D9FF7A"), rng.uniform(0.25, 0.6), mode="add")
            p.stamp(cx, cy, 3, disc(1.4), rgb("#F4FFC4"), 0.9)
    return p.finish(out)


def wp_sunset(out):
    p = WP(51)
    rng = p.rng
    p.img = p.vgrad([(0, "#271A4E"), (0.24, "#61306F"), (0.44, "#BE476F"), (0.6, "#F0775C"), (0.72, "#FFB26A"),
                     (0.79, "#FFD48E"), (1, "#FFD48E")])
    sx, sy = 780, 520
    p.add(rgb("#FFD08A") * 0.45, glow_at(p, sx, sy, 420, 230))
    p.add(rgb("#FFF0C8") * 0.35, glow_at(p, sx, sy, 140))
    p.stamp(sx, sy, 90, disc(72, soft=2), lambda dx, dy: ramp(0.5 + dy / 144.0, [(0, "#FFF6D0"), (1, "#FFC070")]) * 0.6, mode="add")
    for _ in range(26):  # cloud streaks lit from below
        cx, cy = rng.uniform(-100, W + 100), rng.uniform(150, 470)
        rx, ry = rng.uniform(140, 420), rng.uniform(5, 13)
        t = (cy - 150) / 320
        col = ramp(np.float32(t), [(0, "#C35A86"), (0.6, "#FF8C73"), (1, "#FFC48A")])
        p.stamp(cx, cy, rx * 1.2, lambda dx, dy, rx=rx, ry=ry: np.clip(1 - np.sqrt((dx / rx) ** 2 + (dy / ry) ** 2), 0, 1) * 1.6,
                col, rng.uniform(0.25, 0.55))
    hills = [(560, [(34, 1300, 0.4), (12, 480, 1.9)], "#B9567C", "#FF9E7A"),
             (600, [(40, 1500, 1.4), (14, 560, 0.4)], "#86346A", "#F07C77"),
             (640, [(44, 1700, 2.3), (12, 620, 2.6)], "#57225C", "#C4566E"),
             (684, [(40, 1900, 3.1), (10, 700, 1.1)], "#33163F", "#8E3B5E"),
             (718, [(30, 2100, 4.0), (9, 760, 2.0)], "#1C0C29", "#5B2448")]
    for by, terms, col, rim in hills:
        f = sines(p.xs, terms, by, -0.05)
        depth = np.clip((p.y - f[None, :]) / 160.0, 0, 1)
        p.layer(f, rgb(col) * (1 - 0.25 * depth[..., None]), shadow=(0.25, 30.0), glow=(0.25, 10.0, rim),
                rim=(0.3, 1.4, rim), shadow_col="#1A0A22")
    return p.finish(out)


def wp_neon(out):
    p = WP(61)
    rng = p.rng
    hz = 440
    p.img = p.vgrad([(0, "#06021A"), (0.55, "#220842"), (1, "#5A0F62")], 0, hz)
    p.add(rgb("#F2E6FF"), stars(p, 500, ymax=hz - 60, bright=0.7) * 0.55)
    # the sun with its stripes
    sx, sy, sr = 640, 320, 160
    p.add(rgb("#FF4FD8") * 0.55, glow_at(p, sx, sy, 330, 260))

    def striped(dx, dy):
        c = np.clip((sr - np.sqrt(dx * dx + dy * dy)) * SS + 0.5, 0, 1)
        t = np.clip(dy / sr, 0, 1)  # lower half: gaps that widen downwards
        gap = 4 + 14 * t
        phase = (dy % 26) < gap
        return c * np.where((dy > 10) & phase, 0.0, 1.0)

    p.stamp(sx, sy, sr + 2, striped, lambda dx, dy: ramp(0.5 + dy / (2 * sr), [(0, "#FFF27A"), (0.45, "#FF9B4A"), (1, "#FF2BD6")]))
    # mountains, lower in the middle
    side = np.abs(p.xs - 640) / 640.0
    for i, (amp, col, rimc) in enumerate([(120, "#1B0538", "#00E5FF"), (70, "#0E0224", "#FF2BD6")]):
        noise = noise1d(p.Wp, 22.0 + 10 * i, rng) * (16 + 8 * i)
        f = hz - (18 + amp * side ** 1.3) - noise - 6 * i
        p.layer(f.astype(np.float32), rgb(col), glow=(0.25, 6.0, rimc), rim=(0.8, 1.2, rimc))
    # the floor grid in perspective
    below = p.y > hz
    d = np.maximum(p.y - hz, 0.3)
    floor = ramp((p.y - hz) / (H - hz), [(0, "#2A0646"), (0.35, "#12022A"), (1, "#060012")])
    zk = 300.0 / d
    t = zk + 0.0
    fz = np.abs(t - np.round(t)) / (300.0 / d ** 2)  # distance to the nearest horizontal line, in px
    hline = np.exp(-(fz / 1.1) ** 2)
    u = (p.x - 640) / d * 14.0
    fu = np.abs(u - np.round(u)) / (14.0 / d)
    vline = np.exp(-(fu / 1.0) ** 2)
    grid = np.clip(hline + vline, 0, 1) * (1 - np.exp(-d / 30.0))
    gridcol = ramp(np.clip((p.y - hz) / 200, 0, 1), [(0, "#00E5FF"), (1, "#FF2BD6")])
    col = floor + gridcol * (grid * 0.95)[..., None]
    col = col + gridcol * (blur(grid, 6.0) * 0.6)[..., None]
    p.img = np.where(below[..., None], col, p.img)
    p.add(rgb("#FF6BE6") * 0.8, np.exp(-((p.y - hz) / 2.0) ** 2) * (1 - 0.6 * side[None, :]))
    p.add(rgb("#FF2BD6") * 0.25, np.exp(-((p.y - hz) / 30.0) ** 2))
    return p.finish(out)


def wp_paper(out):
    p = WP(71)
    rng = p.rng
    p.img = np.broadcast_to(rgb("#F5F1E8"), p.img.shape).copy()
    # paper: fine grain and long horizontal fibres, a slightly warmer edge
    fine = blur(rng.randn(p.Hp, p.Wp).astype(np.float32), 0.8) * 0.020
    fib = blur(rng.randn(p.Hp, p.Wp).astype(np.float32), 9.0, axes=(1,)) * 0.05
    p.img = p.img * (1 + fine + fib)[..., None]
    v = ((p.x - W / 2) / (W * 0.75)) ** 2 + ((p.y - H / 2) / (H * 0.8)) ** 2
    p.img = p.img * (1 - 0.06 * np.clip(v, 0, 1))[..., None]
    ink = blur(rng.randn(p.Hp, p.Wp).astype(np.float32), 1.2)
    ink = 0.86 + 0.14 * np.clip(ink * 3 + 0.5, 0, 1)  # risograph grain inside the inks

    def shape(cx, cy, rad, fn, col, a):
        x0, x1 = max(0, int((cx - rad) * SS)), min(p.Wp, int((cx + rad) * SS) + 1)
        y0, y1 = max(0, int((cy - rad) * SS)), min(p.Hp, int((cy + rad) * SS) + 1)
        dx, dy = p.x[y0:y1, x0:x1] - cx, p.y[y0:y1, x0:x1] - cy
        cov = (np.clip(fn(dx, dy), 0, 1) * a * ink[y0:y1, x0:x1])[..., None]
        p.img[y0:y1, x0:x1] *= 1 - cov * (1 - rgb(col))  # inks multiply like printed layers

    shape(930, 300, 200, disc(188), "#E07A5F", 0.92)
    arch = lambda dx, dy: np.where(dy < 0, np.clip((140 - np.sqrt(dx * dx + dy * dy)) * SS + 0.5, 0, 1),
                                   np.clip((140 - np.abs(dx)) * SS + 0.5, 0, 1) * np.clip((150 - dy) * SS + 0.5, 0, 1))
    shape(1080, 570, 300, arch, "#3D405B", 0.88)
    shape(770, 520, 120, disc(108), "#F2CC8F", 0.95)
    for i in range(6):  # a small dot grid
        for j in range(5):
            shape(640 + i * 22, 120 + j * 22, 6, disc(4.2), "#81B29A", 0.95)
    # one ink line sweeping across
    f = sines(p.xs, [(26, 900, 0.6), (8, 300, 2.0)], 430, -0.08)
    line = np.exp(-((p.y - f[None, :]) / 1.1) ** 2) * (p.x > 560)
    p.img = p.img * (1 - (line * 0.85)[..., None] * (1 - rgb("#3D405B")))
    return p.finish(out, grain=1.2)


def mono_font(size):
    for f in (os.path.join(REPO, "SDK", "Fonts", "JetBrainsMono-Regular.ttf"), "DejaVuSansMono.ttf", "consola.ttf"):
        try:
            return ImageFont.truetype(f, size)
        except OSError:
            continue
    return ImageFont.load_default()


TERMINAL = """NEXVYN OS 1.0 (tty1)
[  OK  ] Mounted sdmc:/NexvynOS
[  OK  ] Started window manager
[  OK  ] Started App Market catalog sync
[  OK  ] Reached target Desktop

nexvyn login: guest
guest@switch:~$ nxvpkg themes
  com.sonerx7.theme.retroterminal  1.0  applied
guest@switch:~$ uptime
  up 3 days, 4:12,  1 user,  load: 0.08
guest@switch:~$ cat motd.txt
  READY.
  HAPPY HACKING.
guest@switch:~$ _"""


def wp_terminal(out):
    font = mono_font(19)
    txt = Image.new("L", (W, H), 0)
    dr = ImageDraw.Draw(txt)
    y = 92
    for line in TERMINAL.split("\n"):
        if line.endswith("_"):  # the cursor as a block
            dr.text((560, y), line[:-1], fill=255, font=font)
            x = 560 + dr.textlength(line[:-1], font=font)
            dr.rectangle([x + 2, y + 2, x + 13, y + 22], fill=255)
        else:
            dr.text((560, y), line, fill=200 if line.startswith("[") else 255, font=font)
        y += 28
    t = np.asarray(txt, np.float32) / 255.0
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    base = np.broadcast_to(rgb("#03110A"), (H, W, 3)).copy()
    base += rgb("#0B3A1A")[None, None] * np.exp(-(((xx - 820) / 700) ** 2 + ((yy - 330) / 420) ** 2))[..., None] * 0.9
    green, glow = rgb("#4BFF7A"), rgb("#1FC24E")
    img = base + green * t[..., None] * 0.95 + glow * (blur(t, 2.2) * 0.75 + blur(t, 9.0) * 0.55)[..., None]
    img *= np.where((yy.astype(np.int32) % 3) == 2, 0.72, 1.0)[..., None]  # scan lines
    # CRT: darker, rounded corners and a soft rolling band
    u, v = (xx - W / 2) / (W / 2), (yy - H / 2) / (H / 2)
    vig = np.clip(1 - 0.55 * (u ** 2 + v ** 2) ** 1.6, 0, 1)
    img *= vig[..., None]
    img += rgb("#2BFF66") * (0.035 * np.exp(-((yy - 470) / 60) ** 2))[..., None]
    save_jpg(img * 255.0, out, grain=2.4)
    return np.clip(img * 255, 0, 255).astype(np.uint8)


# ==========================================================================
# sounds (Retro Terminal): square-wave bleeps, 22050 Hz 16-bit mono
# ==========================================================================
RATE = 22050


def tone_seq(notes, vol=0.30, duty=0.5, noise=False, sweep=None):
    out = []
    rng = np.random.RandomState(7)
    for freq, dur in notes:
        n = int(RATE * dur)
        t = np.arange(n) / RATE
        if noise:
            s = rng.uniform(-1, 1, n)
            s = np.convolve(s, np.ones(4) / 4, mode="same")
        else:
            f = freq if sweep is None else freq * (sweep ** (t / dur))
            ph = np.cumsum(f / RATE) % 1.0
            s = np.where(ph < duty, 1.0, -1.0)
        env = np.minimum(1, t / 0.003) * np.exp(-t / max(dur * 0.55, 0.004))
        out.append(s * env * vol)
        out.append(np.zeros(int(RATE * 0.012)))
    return np.concatenate(out)


SOUNDS = {
    "click": lambda: tone_seq([(1250, 0.018)]),
    "key": lambda: tone_seq([(950, 0.012)], vol=0.22),
    "pop": lambda: tone_seq([(420, 0.07)], sweep=2.4),
    "volume": lambda: tone_seq([(660, 0.05)]),
    "notify": lambda: tone_seq([(880, 0.08), (1320, 0.12)]),
    "error": lambda: tone_seq([(220, 0.11), (165, 0.16)], duty=0.25),
    "trash": lambda: tone_seq([(0, 0.18)], noise=True, vol=0.25),
    "shutter": lambda: tone_seq([(0, 0.05), (0, 0.04)], noise=True, vol=0.3),
    "alarm": lambda: tone_seq([(988, 0.12), (740, 0.12)] * 4),
    "startup": lambda: tone_seq([(523, 0.09), (659, 0.09), (784, 0.09), (1047, 0.22)]),
}


def write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = np.clip(samples * 32767, -32768, 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)


# ==========================================================================
# preview tile
# ==========================================================================
def icon(light, dark, accent, path, focus=0.62, size=256):
    def square(a):
        im = Image.fromarray(a, "RGB")
        s = H  # the right-centre square of the picture: the left side is kept free for desktop icons
        x0 = int(min(max(W * focus - s / 2, 0), W - s))
        return im.crop((x0, 0, x0 + s, s)).resize((size, size), Image.LANCZOS)

    tile = square(light)
    if dark is not None:  # light top-left, dark bottom-right
        mask = Image.new("L", (size, size), 0)
        ImageDraw.Draw(mask).polygon([(size, 0), (size, size), (0, size)], fill=255)
        tile.paste(square(dark), (0, 0), mask)
    sc = 4
    big = Image.new("L", (size * sc, size * sc), 0)
    ImageDraw.Draw(big).rounded_rectangle([0, 0, size * sc - 1, size * sc - 1], radius=56 * sc, fill=255)
    alpha = big.resize((size, size), Image.LANCZOS)
    out = tile.convert("RGBA")
    out.putalpha(alpha)
    # the accent color as a swatch with a white ring and a soft shadow
    ov = Image.new("RGBA", (size * sc, size * sc), (0, 0, 0, 0))
    d = ImageDraw.Draw(ov)
    cx, cy, r = (size - 48) * sc, (size - 48) * sc, 26 * sc
    d.ellipse([cx - r - 6 * sc, cy - r - 3 * sc, cx + r + 6 * sc, cy + r + 9 * sc], fill=(0, 0, 0, 60))
    d.ellipse([cx - r - 5 * sc, cy - r - 5 * sc, cx + r + 5 * sc, cy + r + 5 * sc], fill=(255, 255, 255, 255))
    a = accent.lstrip("#")
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(int(a[0:2], 16), int(a[2:4], 16), int(a[4:6], 16), 255))
    out = Image.alpha_composite(out, ov.resize((size, size), Image.LANCZOS))
    out.save(path, optimize=True)


# ==========================================================================
# the themes
# ==========================================================================
L5 = ("en", "tr", "de", "fr", "es")


def m(*v):
    return dict(zip(L5, v))


THEMES = [
    {
        "slug": "aurora", "id": "com.sonerx7.theme.aurora", "appearance": "dark", "accent": "#3DDC97",
        "wallpapers": [wp_aurora], "settings": {"screensaver.style": 1},
        "name": m("Aurora", "Kutup Işıkları", "Polarlicht", "Aurore boréale", "Aurora boreal"),
        "description": m("Northern lights over a mountain lake, in the dark appearance with a mint accent.",
                         "Dağ gölünün üzerinde kuzey ışıkları; koyu görünüm ve nane yeşili vurgu rengi.",
                         "Nordlichter über einem Bergsee, im dunklen Erscheinungsbild mit Mintakzent.",
                         "Des aurores boréales sur un lac de montagne, en apparence sombre avec un accent menthe.",
                         "Auroras boreales sobre un lago de montaña, con aspecto oscuro y acento menta."),
        "subtitle": m("Northern lights over a still lake", "Durgun gölde kuzey ışıkları", "Nordlichter über einem stillen See",
                      "Aurores sur un lac paisible", "Auroras sobre un lago en calma"),
        "features": m(["Dark appearance", "Mint accent color", "Star warp screen saver"],
                      ["Koyu görünüm", "Nane yeşili vurgu rengi", "Yıldız yolculuğu ekran koruyucusu"],
                      ["Dunkles Erscheinungsbild", "Mintgrüne Akzentfarbe", "Bildschirmschoner Sternenflug"],
                      ["Apparence sombre", "Couleur d’accent menthe", "Économiseur d’écran voyage stellaire"],
                      ["Aspecto oscuro", "Color de acento menta", "Salvapantallas viaje estelar"]),
        "long": m("Green and violet curtains of light ripple above a ridge of mountains and are mirrored in the still water below, under a sky full of stars.",
                  "Yeşil ve mor ışık perdeleri dağ sırtının üzerinde dalgalanır, yıldızlarla dolu gökyüzünün altında durgun suya yansır.",
                  "Grüne und violette Lichtvorhänge wogen über einem Bergkamm und spiegeln sich unter einem Sternenhimmel im stillen Wasser.",
                  "Des voiles de lumière verts et violets ondulent au-dessus des montagnes et se reflètent dans l’eau calme, sous un ciel étoilé.",
                  "Cortinas de luz verdes y violetas ondean sobre las montañas y se reflejan en el agua en calma, bajo un cielo lleno de estrellas."),
    },
    {
        "slug": "sakura", "id": "com.sonerx7.theme.sakura", "appearance": "auto", "accent": "#E86A92", "focus": 0.3,
        "wallpapers": [lambda o: sakura(o, False), lambda o: sakura(o, True)], "settings": {},
        "name": m("Sakura", "Sakura", "Kirschblüte", "Sakura", "Sakura"),
        "description": m("A cherry blossom branch in soft spring light, and at night under the moon. Pink accent.",
                         "Yumuşak bahar ışığında, geceleri de ay altında bir kiraz çiçeği dalı. Pembe vurgu rengi.",
                         "Ein Kirschblütenzweig im sanften Frühlingslicht und nachts unter dem Mond. Rosa Akzent.",
                         "Une branche de cerisier en fleurs dans la douce lumière du printemps, et la nuit sous la lune. Accent rose.",
                         "Una rama de cerezo en flor con la suave luz de primavera, y de noche bajo la luna. Acento rosa."),
        "subtitle": m("Cherry blossoms by day and by night", "Gündüz ve gece kiraz çiçekleri", "Kirschblüten bei Tag und Nacht",
                      "Cerisiers en fleurs, jour et nuit", "Cerezos en flor de día y de noche"),
        "features": m(["Follows light and dark automatically", "Light and night wallpapers", "Pink accent color"],
                      ["Açık ve koyu görünümü kendiliğinden izler", "Gündüz ve gece duvar kâğıtları", "Pembe vurgu rengi"],
                      ["Folgt automatisch hell und dunkel", "Hintergründe für Tag und Nacht", "Rosa Akzentfarbe"],
                      ["Suit automatiquement le clair et le sombre", "Fonds de jour et de nuit", "Couleur d’accent rose"],
                      ["Sigue el modo claro y oscuro automáticamente", "Fondos de día y de noche", "Color de acento rosa"]),
        "long": m("Petals drift past a blossoming branch over misty hills. When the dark appearance turns on in the evening, the same branch glows under the moon.",
                  "Sisli tepelerin üzerinde çiçek açmış bir dalın önünden yapraklar süzülür. Akşam koyu görünüm açılınca aynı dal ay ışığında parlar.",
                  "Blütenblätter treiben an einem blühenden Zweig über nebligen Hügeln vorbei. Wird abends das dunkle Erscheinungsbild aktiv, leuchtet derselbe Zweig im Mondlicht.",
                  "Des pétales flottent devant une branche fleurie au-dessus de collines brumeuses. Le soir, en apparence sombre, la même branche brille sous la lune.",
                  "Los pétalos flotan junto a una rama en flor sobre colinas con niebla. Al anochecer, con el aspecto oscuro, la misma rama brilla bajo la luna."),
    },
    {
        "slug": "ocean", "id": "com.sonerx7.theme.ocean", "appearance": "auto", "accent": "#0A9FD8",
        "wallpapers": [lambda o: ocean(o, False), lambda o: ocean(o, True)], "settings": {"dock.magnification": 1.7},
        "name": m("Ocean", "Okyanus", "Ozean", "Océan", "Océano"),
        "description": m("The open sea under the midday sun and a moonlit night. Turquoise accent.",
                         "Öğle güneşinde ve ay ışıklı bir gecede açık deniz. Turkuaz vurgu rengi.",
                         "Das offene Meer in der Mittagssonne und in einer Mondnacht. Türkiser Akzent.",
                         "La haute mer sous le soleil de midi et par une nuit de lune. Accent turquoise.",
                         "El mar abierto bajo el sol del mediodía y en una noche de luna. Acento turquesa."),
        "subtitle": m("Sunlit sea by day, moonlit sea at night", "Gündüz güneşli, gece ay ışıklı deniz", "Sonniges Meer, nachts im Mondlicht",
                      "La mer au soleil, puis sous la lune", "Mar al sol de día, a la luz de luna de noche"),
        "features": m(["Follows light and dark automatically", "Day and night wallpapers", "Turquoise accent color"],
                      ["Açık ve koyu görünümü kendiliğinden izler", "Gündüz ve gece duvar kâğıtları", "Turkuaz vurgu rengi"],
                      ["Folgt automatisch hell und dunkel", "Hintergründe für Tag und Nacht", "Türkise Akzentfarbe"],
                      ["Suit automatiquement le clair et le sombre", "Fonds de jour et de nuit", "Couleur d’accent turquoise"],
                      ["Sigue el modo claro y oscuro automáticamente", "Fondos de día y de noche", "Color de acento turquesa"]),
        "long": m("Waves glitter in the path of the sun under a summer sky with soft clouds. At night the stars come out and the moon draws a silver road across the water.",
                  "Yaz gökyüzünün yumuşak bulutları altında dalgalar güneşin yolunda pırıldar. Gece yıldızlar çıkar, ay suyun üzerinde gümüş bir yol çizer.",
                  "Wellen glitzern im Pfad der Sonne unter einem Sommerhimmel mit weichen Wolken. Nachts erscheinen die Sterne, und der Mond zieht eine silberne Bahn über das Wasser.",
                  "Les vagues scintillent dans le sillage du soleil sous un ciel d’été aux nuages doux. La nuit, les étoiles apparaissent et la lune trace un chemin d’argent sur l’eau.",
                  "Las olas brillan en el camino del sol bajo un cielo de verano con nubes suaves. De noche salen las estrellas y la luna traza un camino de plata sobre el agua."),
    },
    {
        "slug": "forest", "id": "com.sonerx7.theme.forest", "appearance": "auto", "accent": "#3E9B5B",
        "wallpapers": [lambda o: forest(o, False), lambda o: forest(o, True)], "settings": {},
        "name": m("Forest", "Orman", "Wald", "Forêt", "Bosque"),
        "description": m("Misty pine ridges in the morning sun and a starry night with fireflies. Green accent.",
                         "Sabah güneşinde sisli çam sırtları ve ateş böcekli yıldızlı bir gece. Yeşil vurgu rengi.",
                         "Neblige Kiefernhänge in der Morgensonne und eine Sternennacht mit Glühwürmchen. Grüner Akzent.",
                         "Des crêtes de pins dans la brume du matin et une nuit étoilée avec des lucioles. Accent vert.",
                         "Crestas de pinos con niebla al sol de la mañana y una noche estrellada con luciérnagas. Acento verde."),
        "subtitle": m("Misty pines at dawn, fireflies at night", "Şafakta sisli çamlar, gece ateş böcekleri", "Neblige Kiefern, nachts Glühwürmchen",
                      "Pins brumeux et lucioles la nuit", "Pinos con niebla y luciérnagas de noche"),
        "features": m(["Follows light and dark automatically", "Morning and night wallpapers", "Forest green accent color"],
                      ["Açık ve koyu görünümü kendiliğinden izler", "Sabah ve gece duvar kâğıtları", "Orman yeşili vurgu rengi"],
                      ["Folgt automatisch hell und dunkel", "Hintergründe für Morgen und Nacht", "Waldgrüne Akzentfarbe"],
                      ["Suit automatiquement le clair et le sombre", "Fonds du matin et de la nuit", "Couleur d’accent vert forêt"],
                      ["Sigue el modo claro y oscuro automáticamente", "Fondos de mañana y de noche", "Color de acento verde bosque"]),
        "long": m("Five ridges of pine trees fade into the morning mist while light shafts fall through the valley. In the dark appearance the forest sleeps under the moon and fireflies light up the trees.",
                  "Beş sıra çam ağacı sabah sisinde kaybolurken vadiye ışık huzmeleri düşer. Koyu görünümde orman ay altında uyur, ağaçların arasında ateş böcekleri parlar.",
                  "Fünf Reihen Kiefern verschwinden im Morgennebel, während Lichtstrahlen ins Tal fallen. Im dunklen Erscheinungsbild schläft der Wald unter dem Mond, und Glühwürmchen leuchten zwischen den Bäumen.",
                  "Cinq rangées de pins se fondent dans la brume du matin tandis que des rayons de lumière tombent dans la vallée. En apparence sombre, la forêt dort sous la lune et les lucioles s’allument entre les arbres.",
                  "Cinco hileras de pinos se pierden en la niebla de la mañana mientras rayos de luz caen sobre el valle. Con el aspecto oscuro, el bosque duerme bajo la luna y las luciérnagas brillan entre los árboles."),
    },
    {
        "slug": "sunset", "id": "com.sonerx7.theme.sunset", "appearance": "light", "accent": "#F7821B",
        "wallpapers": [wp_sunset], "settings": {},
        "name": m("Sunset", "Gün Batımı", "Sonnenuntergang", "Coucher de soleil", "Atardecer"),
        "description": m("Warm layered hills under a glowing evening sky, in the light appearance with an orange accent.",
                         "Parlayan akşam göğünün altında sıcak tonlu tepeler; açık görünüm ve turuncu vurgu rengi.",
                         "Warme Hügelketten unter einem glühenden Abendhimmel, im hellen Erscheinungsbild mit orangem Akzent.",
                         "Des collines aux tons chauds sous un ciel du soir embrasé, en apparence claire avec un accent orange.",
                         "Colinas de tonos cálidos bajo un cielo de tarde encendido, con aspecto claro y acento naranja."),
        "subtitle": m("Golden hour over rolling hills", "Tepelerin üzerinde altın saat", "Goldene Stunde über sanften Hügeln",
                      "L’heure dorée sur les collines", "La hora dorada sobre las colinas"),
        "features": m(["Light appearance", "Orange accent color (one of the system colors)", "Glowing sun and cloud streaks"],
                      ["Açık görünüm", "Turuncu vurgu rengi (sistem renklerinden biri)", "Parlayan güneş ve bulut şeritleri"],
                      ["Helles Erscheinungsbild", "Orange Akzentfarbe (eine der Systemfarben)", "Leuchtende Sonne und Wolkenstreifen"],
                      ["Apparence claire", "Couleur d’accent orange (une des couleurs système)", "Soleil éclatant et traînées de nuages"],
                      ["Aspecto claro", "Color de acento naranja (uno de los colores del sistema)", "Sol radiante y nubes alargadas"]),
        "long": m("The sun sinks behind five layers of hills in plum and rose, the sky shading from violet to gold with thin clouds lit from below.",
                  "Güneş mürdüm ve gül rengi beş sıra tepenin ardına iner; gökyüzü mordan altına döner, ince bulutlar alttan aydınlanır.",
                  "Die Sonne versinkt hinter fünf Hügelketten in Pflaume und Rosé; der Himmel geht von Violett in Gold über, dünne Wolken leuchten von unten.",
                  "Le soleil descend derrière cinq rangées de collines prune et rose ; le ciel passe du violet à l’or, de fins nuages éclairés par en dessous.",
                  "El sol se oculta tras cinco hileras de colinas color ciruela y rosa; el cielo pasa del violeta al dorado, con nubes finas iluminadas desde abajo."),
    },
    {
        "slug": "midnight-neon", "id": "com.sonerx7.theme.midnightneon", "appearance": "dark", "accent": "#FF2BD6",
        "wallpapers": [wp_neon], "settings": {"screensaver.style": 1, "dock.magnification": 1.8},
        "name": m("Midnight Neon", "Gece Yarısı Neonu", "Mitternachtsneon", "Néon de minuit", "Neón de medianoche"),
        "description": m("A retro-wave sun over a glowing grid, in the dark appearance with a magenta accent.",
                         "Parlayan bir ızgaranın üzerinde retro dalga güneşi; koyu görünüm ve eflatun vurgu rengi.",
                         "Eine Retrowave-Sonne über einem leuchtenden Raster, im dunklen Erscheinungsbild mit Magenta-Akzent.",
                         "Un soleil rétro au-dessus d’une grille lumineuse, en apparence sombre avec un accent magenta.",
                         "Un sol retro sobre una cuadrícula luminosa, con aspecto oscuro y acento magenta."),
        "subtitle": m("Synthwave sun over a neon grid", "Neon ızgara üzerinde synthwave güneşi", "Synthwave-Sonne über Neonraster",
                      "Soleil synthwave sur grille néon", "Sol synthwave sobre una cuadrícula neón"),
        "features": m(["Dark appearance", "Magenta accent color", "Star warp screen saver, stronger Dock magnification"],
                      ["Koyu görünüm", "Eflatun vurgu rengi", "Yıldız yolculuğu ekran koruyucusu, daha güçlü Dock büyütmesi"],
                      ["Dunkles Erscheinungsbild", "Magenta-Akzentfarbe", "Bildschirmschoner Sternenflug, stärkere Dock-Vergrößerung"],
                      ["Apparence sombre", "Couleur d’accent magenta", "Économiseur voyage stellaire, agrandissement du Dock plus fort"],
                      ["Aspecto oscuro", "Color de acento magenta", "Salvapantallas viaje estelar, mayor ampliación del Dock"]),
        "long": m("A striped sun sets between neon-rimmed mountains while a cyan and magenta grid runs to the horizon. Straight out of an 80s cassette cover.",
                  "Çizgili bir güneş neon kenarlı dağların arasında batarken camgöbeği ve eflatun bir ızgara ufka uzanır. Doğrudan bir 80'ler kaset kapağından.",
                  "Eine gestreifte Sonne geht zwischen neongesäumten Bergen unter, während ein Raster in Cyan und Magenta zum Horizont läuft. Direkt von einem Kassettencover der 80er.",
                  "Un soleil rayé se couche entre des montagnes bordées de néon tandis qu’une grille cyan et magenta file vers l’horizon. Tout droit sorti d’une pochette de cassette des années 80.",
                  "Un sol a rayas se pone entre montañas con bordes de neón mientras una cuadrícula cian y magenta corre hacia el horizonte. Salido de una portada de casete de los 80."),
    },
    {
        "slug": "paper", "id": "com.sonerx7.theme.paper", "appearance": "light", "accent": "#C8553D",
        "wallpapers": [wp_paper], "settings": {"appearance.reduceTransparency": True, "dock.magnify": False},
        "name": m("Paper", "Kâğıt", "Papier", "Papier", "Papel"),
        "description": m("Calm printed shapes on warm paper: a minimal light look with opaque panels and a terracotta accent.",
                         "Sıcak tonlu kâğıt üzerinde sakin baskı şekilleri: opak panelli, kiremit vurgu renkli sade bir açık görünüm.",
                         "Ruhige gedruckte Formen auf warmem Papier: ein schlichtes helles Aussehen mit deckenden Leisten und Terrakotta-Akzent.",
                         "Des formes imprimées sur un papier chaleureux : un style clair et épuré, panneaux opaques et accent terre cuite.",
                         "Formas impresas serenas sobre papel cálido: un aspecto claro y sobrio con paneles opacos y acento terracota."),
        "subtitle": m("Minimal light look with printed shapes", "Baskı şekilli sade açık görünüm", "Schlichtes Hell mit Druckformen",
                      "Style clair épuré, formes imprimées", "Aspecto claro sobrio con formas impresas"),
        "features": m(["Light appearance", "Opaque Dock and menu bar (reduced transparency)", "Dock without magnification", "Terracotta accent color"],
                      ["Açık görünüm", "Opak Dock ve menü çubuğu (azaltılmış saydamlık)", "Büyütmesiz Dock", "Kiremit vurgu rengi"],
                      ["Helles Erscheinungsbild", "Deckendes Dock und Menüleiste (weniger Transparenz)", "Dock ohne Vergrößerung", "Terrakotta-Akzentfarbe"],
                      ["Apparence claire", "Dock et barre des menus opaques (transparence réduite)", "Dock sans agrandissement", "Couleur d’accent terre cuite"],
                      ["Aspecto claro", "Dock y barra de menús opacos (transparencia reducida)", "Dock sin ampliación", "Color de acento terracota"]),
        "long": m("Overlapping circles and an arch in terracotta, ink blue and mustard, printed like a risograph poster on fibrous off-white paper. The left side stays quiet for your desktop icons.",
                  "Kiremit, mürekkep mavisi ve hardal renginde üst üste binen daireler ve bir kemer, lifli kırık beyaz kâğıda risograf afişi gibi basılmış. Sol taraf masaüstü simgeleri için sade kalır.",
                  "Überlappende Kreise und ein Bogen in Terrakotta, Tintenblau und Senf, gedruckt wie ein Risografie-Plakat auf faserigem, gebrochen weißem Papier. Die linke Seite bleibt ruhig für deine Schreibtischsymbole.",
                  "Des cercles qui se chevauchent et une arche terre cuite, bleu encre et moutarde, imprimés comme une affiche risographiée sur un papier blanc cassé fibreux. Le côté gauche reste calme pour vos icônes.",
                  "Círculos superpuestos y un arco en terracota, azul tinta y mostaza, impresos como un cartel en risografía sobre papel blanco roto con fibras. El lado izquierdo queda despejado para tus iconos."),
    },
    {
        "slug": "retro-terminal", "id": "com.sonerx7.theme.retroterminal", "appearance": "dark", "accent": "#2FD25B",
        "wallpapers": [wp_terminal], "sounds": True,
        "settings": {"appearance.reduceTransparency": True, "screensaver.style": 2},
        "name": m("Retro Terminal", "Retro Terminal", "Retro-Terminal", "Terminal rétro", "Terminal retro"),
        "description": m("A green phosphor CRT with a boot log, dark appearance, opaque panels and 8-bit interface sounds.",
                         "Açılış kayıtlı yeşil fosforlu bir CRT ekran; koyu görünüm, opak paneller ve 8 bit arayüz sesleri.",
                         "Ein grüner Phosphor-Röhrenmonitor mit Bootprotokoll, dunkles Erscheinungsbild, deckende Leisten und 8-Bit-Systemtöne.",
                         "Un écran cathodique à phosphore vert avec un journal de démarrage, apparence sombre, panneaux opaques et sons 8 bits.",
                         "Una pantalla CRT de fósforo verde con un registro de arranque, aspecto oscuro, paneles opacos y sonidos de 8 bits."),
        "subtitle": m("Green phosphor CRT with 8-bit sounds", "8 bit sesli yeşil fosfor CRT", "Grüner Phosphor-CRT mit 8-Bit-Tönen",
                      "CRT phosphore vert, sons 8 bits", "CRT de fósforo verde con sonido 8 bits"),
        "features": m(["Dark appearance", "Phosphor green accent color", "8-bit sounds for clicks, alerts, trash and startup", "Opaque panels, clock screen saver"],
                      ["Koyu görünüm", "Fosfor yeşili vurgu rengi", "Tıklama, uyarı, çöp ve açılış için 8 bit sesler", "Opak paneller, saat ekran koruyucusu"],
                      ["Dunkles Erscheinungsbild", "Phosphorgrüne Akzentfarbe", "8-Bit-Töne für Klicks, Hinweise, Papierkorb und Start", "Deckende Leisten, Uhr-Bildschirmschoner"],
                      ["Apparence sombre", "Couleur d’accent vert phosphore", "Sons 8 bits pour les clics, alertes, corbeille et démarrage", "Panneaux opaques, économiseur horloge"],
                      ["Aspecto oscuro", "Color de acento verde fósforo", "Sonidos de 8 bits para clics, avisos, papelera e inicio", "Paneles opacos, salvapantallas reloj"]),
        "long": m("Scan lines, a glowing boot log and a blinking prompt on a curved green screen. The theme also swaps the interface sounds for square-wave bleeps.",
                  "Kavisli yeşil bir ekranda tarama çizgileri, parlayan bir açılış kaydı ve yanıp sönen bir komut istemi. Tema arayüz seslerini de kare dalga bip seslerine çevirir.",
                  "Scanlines, ein leuchtendes Bootprotokoll und eine blinkende Eingabeaufforderung auf einem gewölbten grünen Bildschirm. Das Theme ersetzt auch die Systemtöne durch Rechteck-Piepser.",
                  "Lignes de balayage, journal de démarrage lumineux et invite clignotante sur un écran vert bombé. Le thème remplace aussi les sons de l’interface par des bips en onde carrée.",
                  "Líneas de barrido, un registro de arranque luminoso y un cursor parpadeante en una pantalla verde curva. El tema también cambia los sonidos de la interfaz por pitidos de onda cuadrada."),
    },
]

APPEAR = {
    "light": m("Light", "Açık", "Hell", "Clair", "Claro"),
    "dark": m("Dark", "Koyu", "Dunkel", "Sombre", "Oscuro"),
    "auto": m("Auto (light by day, dark at night)", "Otomatik (gündüz açık, gece koyu)", "Automatisch (tagsüber hell, nachts dunkel)",
              "Auto (clair le jour, sombre la nuit)", "Automático (claro de día, oscuro de noche)"),
}


def store_description(t, lang):
    head = {"en": "Included", "tr": "İçerik", "de": "Enthalten", "fr": "Inclus", "es": "Incluye"}[lang]
    howto = {
        "en": "Get installs it and offers to apply it. Switch themes or restore the default look in System Settings > Appearance > Themes.",
        "tr": "Al ile yüklenir ve uygulanması önerilir. Temayı Sistem Ayarları > Görünüm > Temalar'dan değiştirebilir ya da varsayılan görünüme dönebilirsiniz.",
        "de": "„Laden“ installiert das Theme und bietet an, es anzuwenden. Themes wechselst du oder setzt das Aussehen zurück unter Systemeinstellungen > Erscheinungsbild > Themes.",
        "fr": "Obtenir l’installe et propose de l’appliquer. Changez de thème ou rétablissez l’apparence par défaut dans Réglages Système > Apparence > Thèmes.",
        "es": "Obtener lo instala y ofrece aplicarlo. Cambia de tema o restaura el aspecto predeterminado en Ajustes del Sistema > Apariencia > Temas.",
    }[lang]
    bullets = "\n".join("• " + f for f in t["features"][lang])
    return f"{t['long'][lang]}\n\n{head}:\n{bullets}\n\n{howto}"


def readme(t):
    tr, en = t["name"]["tr"], t["name"]["en"]
    title = en if tr == en else f"{tr} / {en}"
    files = "`wallpaper.jpg`" + (", `wallpaper-dark.jpg`" if len(t["wallpapers"]) > 1 else "") + \
            (", `sounds/*.wav`" if t.get("sounds") else "")
    st = ", ".join(f"`{k}` = `{json.dumps(v)}`" for k, v in t["settings"].items()) or "—"
    return f"""# {title}

{t['description']['tr']}
{t['description']['en']}

## Özellikler / Features

{chr(10).join('- ' + a + ' / ' + b for a, b in zip(t['features']['tr'], t['features']['en']))}

| | |
|---|---|
| Kimlik / Id | `{t['id']}` |
| Görünüm / Appearance | {APPEAR[t['appearance']]['tr']} / {APPEAR[t['appearance']]['en']} |
| Vurgu rengi / Accent | `{t['accent']}` |
| Dosyalar / Files | {files} |
| Ayarlar / Settings | {st} |

## Kurulum / Install

- **Mağaza:** Uygulama Mağazası > Temalar > {tr} > Al. / **Store:** App Market > Themes > {en} > Get.
- **Dosya / File:** `{t['slug']}.nxvtheme` dosyasını Dosyalar'da açın, **Yükle ve Uygula**'ya basın. / Open
  `{t['slug']}.nxvtheme` in Files and choose **Install and Apply**.

Temalar `~/Library/Themes/{t['id']}/` içine kurulur; *Sistem Ayarları > Görünüm > Temalar*'dan değiştirilir,
kaldırılır ya da **Varsayılanlara Dön** ile eski görünüme dönülür. / Themes are installed in
`~/Library/Themes/{t['id']}/` and managed in *System Settings > Appearance > Themes* (**Restore Defaults** brings back
the standard look).

## Geliştirme / Development

Duvar kâğıtları{', sesler' if t.get('sounds') else ''} ve önizleme Python ile üretilir (Pillow + numpy). / The wallpapers{', sounds' if t.get('sounds') else ''} and
the preview are generated:

    python Store/Themes/tools/gen_themes.py {t['slug']}

Biçim / Format: Nexvyn OS `docs/NXVAPP_FORMAT.md`, bölüm / section 9.

## Sürümler / Versions

| Sürüm / Version | Değişiklik / Change |
|---|---|
| 1.0 | İlk sürüm. / First release. |
"""


def build(t):
    base = os.path.join(THEMES_DIR, t["slug"])
    src = os.path.join(base, "source")
    os.makedirs(src, exist_ok=True)
    names = ["wallpaper.jpg", "wallpaper-dark.jpg"]
    pics = [fn(os.path.join(src, names[i])) for i, fn in enumerate(t["wallpapers"])]
    manifest = {"id": t["id"], "name": t["name"], "description": t["description"], "version": "1.0", "author": AUTHOR,
                "appearance": t["appearance"], "accent": t["accent"], "wallpaper": names[0]}
    if len(pics) > 1:
        manifest["wallpaperDark"] = names[1]
    if t.get("sounds"):
        for name, fn in SOUNDS.items():
            write_wav(os.path.join(src, "sounds", name + ".wav"), fn())
        manifest["sounds"] = "sounds"
    if t["settings"]:
        manifest["settings"] = t["settings"]
    with open(os.path.join(src, "theme.json"), "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    icon(pics[0], pics[1] if len(pics) > 1 else None, t["accent"], os.path.join(base, "icon.png"), t.get("focus", 0.62))
    for lang, s in t["subtitle"].items():
        assert len(s) <= 45, (t["slug"], lang, s)
    store = {"subtitle": t["subtitle"], "description": {lang: store_description(t, lang) for lang in L5}}
    with open(os.path.join(base, "store.json"), "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(store, ensure_ascii=False, indent=2) + "\n")
    with open(os.path.join(base, "README.md"), "w", encoding="utf-8", newline="\n") as f:
        f.write(readme(t))
    return base


def main(argv):
    only = set(argv)
    unknown = only - {t["slug"] for t in THEMES}
    if unknown:
        print("unknown theme:", ", ".join(sorted(unknown)))
        return 1
    for t in THEMES:
        if not only or t["slug"] in only:
            print("built", build(t))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
