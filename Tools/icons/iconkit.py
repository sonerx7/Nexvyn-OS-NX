"""Drawing kit for the App Market icons.

An icon is a 256x256 RGBA PNG in the shape of the Nexvyn OS system icons: a superellipse (n = 5) squircle of 206 px
centred at (128, 124), with the same soft drop shadow underneath. Everything is drawn at 4x (1024 px) as float masks
and colour layers, then box-filtered down. Coordinates are in output pixels (0..256), angles in degrees, clockwise
on screen (0 = pointing right).

The light comes from the top left: shadows fall down and slightly to the right, bodies get lighter at the top.
"""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SIZE = 256
SS = 4
N = SIZE * SS
CX, CY, SQ = 128.0, 124.0, 206.0
L, T, R, B = CX - SQ / 2, CY - SQ / 2, CX + SQ / 2, CY + SQ / 2  # 25, 21, 231, 227

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
FONT_FILES = {
    "sans": "poppins/Poppins-Bold.ttf",
    "round": "nunito/Nunito-Bold.ttf",
    "serif": "lora/Lora-Bold.ttf",
    "mono": "fira-code/FiraCode-Bold.ttf",
    "display": "bebas-neue/BebasNeue-Regular.ttf",
    "hand": "caveat/Caveat-Bold.ttf",
}

_yy, _xx = np.mgrid[0:N, 0:N].astype(np.float32)
X = (_xx + 0.5) / SS
Y = (_yy + 0.5) / SS
del _yy, _xx


# ----------------------------------------------------------------------------------------------------------- colour
def col(c):
    if isinstance(c, str):
        h = c.lstrip("#")
        if len(h) == 3:
            h = "".join(ch * 2 for ch in h)
        return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)
    return np.asarray(c, np.float32)


def _to_lin(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1 / 2.4) - 0.055)


_M1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
                [0.2119034982, 0.6806995451, 0.1073969566],
                [0.0883024619, 0.2817188376, 0.6299787005]], np.float32)
_M2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
                [1.9779984951, -2.4285922050, 0.4505937099],
                [0.0259040371, 0.7827717662, -0.8086757660]], np.float32)
_M1I = np.linalg.inv(_M1).astype(np.float32)
_M2I = np.linalg.inv(_M2).astype(np.float32)


def oklab(c):
    lms = _to_lin(np.asarray(c, np.float32)) @ _M1.T
    return np.cbrt(lms) @ _M2.T


def from_oklab(lab):
    lms = (np.asarray(lab, np.float32) @ _M2I.T) ** 3
    return _to_srgb(lms @ _M1I.T).astype(np.float32)


def mix(a, b, t):
    return from_oklab(oklab(col(a)) * (1 - t) + oklab(col(b)) * t)


def lighten(c, t):
    return mix(c, "#FFFFFF", t)


def darken(c, t):
    return mix(c, "#000000", t)


def lum(c):
    c = _to_lin(col(c))
    return float(0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2])


def hexstr(c):
    c = np.clip(col(c), 0, 1)
    return "#%02X%02X%02X" % tuple(int(round(v * 255)) for v in c)


def ramp(t, stops):
    """Colour array for a parameter array t (0..1), interpolated in OKLab. stops: colours or (t, colour) pairs."""
    if not isinstance(stops[0], (tuple, list)) or isinstance(stops[0][0], str) or len(stops[0]) != 2:
        n = len(stops)
        stops = [(i / max(1, n - 1), s) for i, s in enumerate(stops)]
    ts = np.array([s[0] for s in stops], np.float32)
    labs = np.stack([oklab(col(s[1])) for s in stops])
    tt = np.clip(t, 0, 1).ravel()
    out = np.stack([np.interp(tt, ts, labs[:, k]) for k in range(3)], -1).astype(np.float32)
    return from_oklab(out).reshape(t.shape + (3,))


# ------------------------------------------------------------------------------------------------- mask primitives
def _canvas():
    im = Image.new("L", (N, N), 0)
    return im, ImageDraw.Draw(im)


def _arr(im):
    return np.asarray(im, np.float32) * (1.0 / 255.0)


def _p(pts):
    return [(float(x) * SS, float(y) * SS) for x, y in pts]


def rotate(pts, ang, cx, cy):
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * ca - (y - cy) * sa, cy + (x - cx) * sa + (y - cy) * ca) for x, y in pts]


def polar(cx, cy, r, ang):
    a = math.radians(ang)
    return cx + r * math.cos(a), cy + r * math.sin(a)


def ellipse_pts(cx, cy, rx, ry, a0=0.0, a1=360.0, n=120):
    k = max(8, int(n * abs(a1 - a0) / 360))
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / k)),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / k))) for i in range(k + 1)]


def rrect_pts(x0, y0, x1, y1, r, n=12):
    r = max(0.0, min(r, (x1 - x0) / 2, (y1 - y0) / 2))
    pts = []
    for (cx, cy, a0) in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def poly(pts):
    im, d = _canvas()
    d.polygon(_p(pts), fill=255)
    return _arr(im)


def circle(cx, cy, r):
    im, d = _canvas()
    d.ellipse([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], fill=255)
    return _arr(im)


def ellipse(cx, cy, rx, ry, rot=0.0):
    if rot:
        return poly(rotate(ellipse_pts(cx, cy, rx, ry), rot, cx, cy))
    im, d = _canvas()
    d.ellipse([(cx - rx) * SS, (cy - ry) * SS, (cx + rx) * SS, (cy + ry) * SS], fill=255)
    return _arr(im)


def rrect(x0, y0, x1, y1, r=0.0, rot=0.0, about=None):
    if rot:
        c = about or ((x0 + x1) / 2, (y0 + y1) / 2)
        return poly(rotate(rrect_pts(x0, y0, x1, y1, r), rot, c[0], c[1]))
    im, d = _canvas()
    r = max(0.0, min(r, (x1 - x0) / 2, (y1 - y0) / 2))
    d.rounded_rectangle([x0 * SS, y0 * SS, x1 * SS - 1, y1 * SS - 1], radius=r * SS, fill=255)
    return _arr(im)


def box(cx, cy, w, h, r=0.0, rot=0.0):
    return rrect(cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2, r, rot, (cx, cy))


def line(pts, w, cap=True):
    im, d = _canvas()
    pp = _p(pts)
    d.line(pp, fill=255, width=max(1, int(round(w * SS))), joint="curve")
    if cap:
        r = w * SS / 2
        for (x, y) in (pp[0], pp[-1]):
            d.ellipse([x - r, y - r, x + r, y + r], fill=255)
    return _arr(im)


def arc_pts(cx, cy, r, a0, a1, n=96, ry=None):
    return ellipse_pts(cx, cy, r, ry if ry is not None else r, a0, a1, n)


def arc(cx, cy, r, a0, a1, w, cap=True, ry=None):
    return line(arc_pts(cx, cy, r, a0, a1, ry=ry), w, cap)


def pie(cx, cy, r, a0, a1):
    im, d = _canvas()
    d.pieslice([(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS], a0, a1, fill=255)
    return _arr(im)


def ring(cx, cy, r, w):
    return np.clip(circle(cx, cy, r + w / 2) - circle(cx, cy, r - w / 2), 0, 1)


def star_pts(cx, cy, ro, ri, n=5, rot=-90.0):
    pts = []
    for i in range(2 * n):
        rr = ro if i % 2 == 0 else ri
        pts.append(polar(cx, cy, rr, rot + 180.0 * i / n))
    return pts


def star(cx, cy, ro, ri=None, n=5, rot=-90.0):
    return poly(star_pts(cx, cy, ro, ri if ri is not None else ro * 0.45, n, rot))


def sparkle(cx, cy, r, rot=0.0):
    """Four-pointed twinkle."""
    pts = []
    for i in range(8):
        rr = r if i % 2 == 0 else r * 0.22
        pts.append(polar(cx, cy, rr, rot - 90 + 45 * i))
    return poly(pts)


def heart_pts(cx, cy, s, n=120):
    pts = []
    for i in range(n):
        t = 2 * math.pi * i / n
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((cx + x * s / 16, cy - y * s / 16))
    return pts


def heart(cx, cy, s):
    return poly(heart_pts(cx, cy, s))


def bezier(p0, p1, p2, p3=None, n=48):
    out = []
    for i in range(n + 1):
        t = i / n
        if p3 is None:
            x = (1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0]
            y = (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]
        else:
            x = ((1 - t) ** 3 * p0[0] + 3 * (1 - t) ** 2 * t * p1[0] + 3 * (1 - t) * t * t * p2[0]
                 + t ** 3 * p3[0])
            y = ((1 - t) ** 3 * p0[1] + 3 * (1 - t) ** 2 * t * p1[1] + 3 * (1 - t) * t * t * p2[1]
                 + t ** 3 * p3[1])
        out.append((x, y))
    return out


_FONT_CACHE = {}


def font(name, size):
    key = (name, int(size * SS))
    if key not in _FONT_CACHE:
        path = os.path.join(ROOT, "Store", "Fonts", FONT_FILES.get(name, name))
        _FONT_CACHE[key] = ImageFont.truetype(path, int(size * SS))
    return _FONT_CACHE[key]


def text(s, name="sans", size=100, cx=128, cy=128, rot=0.0):
    """Text mask, its ink box centred on (cx, cy)."""
    f = font(name, size)
    im, d = _canvas()
    bb = d.textbbox((0, 0), s, font=f)
    d.text((cx * SS - (bb[0] + bb[2]) / 2, cy * SS - (bb[1] + bb[3]) / 2), s, font=f, fill=255)
    if rot:
        im = im.rotate(-rot, resample=Image.BICUBIC, center=(cx * SS, cy * SS))
    return _arr(im)


# ------------------------------------------------------------------------------------------------------- mask ops
def U(*ms):
    out = ms[0]
    for m in ms[1:]:
        out = np.maximum(out, m)
    return out


def sub(a, *bs):
    for b in bs:
        a = a * (1 - b)
    return a


def blur(m, r):
    if r <= 0:
        return m
    im = Image.fromarray(np.clip(m * 255 + 0.5, 0, 255).astype(np.uint8), "L")
    return _arr(im.filter(ImageFilter.GaussianBlur(r * SS)))


def shift(m, dx, dy):
    dx, dy = int(round(dx * SS)), int(round(dy * SS))
    out = np.zeros_like(m)
    h, w = m.shape[:2]
    xs0, xd0 = (0, dx) if dx >= 0 else (-dx, 0)
    ys0, yd0 = (0, dy) if dy >= 0 else (-dy, 0)
    cw, ch = w - abs(dx), h - abs(dy)
    if cw > 0 and ch > 0:
        out[yd0:yd0 + ch, xd0:xd0 + cw] = m[ys0:ys0 + ch, xs0:xs0 + cw]
    return out


def bbox(m):
    ys = np.nonzero(m.max(1) > 0.05)[0]
    xs = np.nonzero(m.max(0) > 0.05)[0]
    if not len(ys):
        return 0.0, 0.0, 1.0, 1.0
    return xs[0] / SS, ys[0] / SS, (xs[-1] + 1) / SS, (ys[-1] + 1) / SS


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


# ---------------------------------------------------------------------------------------------------- gradients
def lgrad(stops, x0, y0, x1, y1):
    dx, dy = x1 - x0, y1 - y0
    t = ((X - x0) * dx + (Y - y0) * dy) / (dx * dx + dy * dy + 1e-9)
    return ramp(t, stops)


def vgrad(c0, c1, y0, y1):
    return lgrad([c0, c1], 0, y0, 0, y1)


def rgrad(stops, cx, cy, r, sy=1.0):
    t = np.sqrt((X - cx) ** 2 + ((Y - cy) / sy) ** 2) / r
    return ramp(t, stops)


def agrad(stops, cx, cy, a0=0.0):
    t = ((np.degrees(np.arctan2(Y - cy, X - cx)) - a0) % 360.0) / 360.0
    return ramp(t, stops)


def _squircle_sdf(n=5.0):
    r = SQ / 2
    u = np.abs(X - CX) / r
    v = np.abs(Y - CY) / r
    return ((u ** n + v ** n) ** (1.0 / n) - 1.0) * r


SQ_SDF = _squircle_sdf()
SQM = np.clip(0.5 - SQ_SDF * SS, 0, 1).astype(np.float32)


# ----------------------------------------------------------------------------------------------------------- icon
class Icon:
    """One icon: a colour buffer for the inside of the squircle, painted back to front."""

    def __init__(self, spec, seed=1):
        self.spec = spec
        self.P = spec.get("palette", {})
        self.px = np.zeros((N, N, 3), np.float32)
        self.rng = np.random.default_rng(seed)
        bgc = spec.get("bg", {}).get("colors", ["#808080"])
        self.ink = col(spec.get("ink") or darken(bgc[-1], 0.55))  # shadow tint: the background, darker

    def c(self, key):
        return self.P[key]

    # ---- compositing
    def fill(self, m, paint, op=1.0):
        a = m if op == 1.0 else m * op
        p = col(paint) if (isinstance(paint, str) or np.ndim(paint) == 1) else paint
        self.px += (p - self.px) * a[..., None]

    def add(self, m, paint, op=1.0):
        """Additive light (glows, flares)."""
        p = col(paint) if (isinstance(paint, str) or np.ndim(paint) == 1) else paint
        self.px += p * (m * op)[..., None]
        np.clip(self.px, 0, 1, out=self.px)

    def shadow(self, m, dx=1.5, dy=4.0, r=5.0, op=0.35, color=None):
        self.fill(shift(blur(m, r), dx, dy), self.ink if color is None else color, op)

    def glow(self, m, r, color, op=0.7, add=True):
        g = np.clip(blur(m, r) * 1.6, 0, 1)
        if add:
            self.add(g, color, op)
        else:
            self.fill(g, color, op)

    def inner(self, m, r=3.0, dx=0.0, dy=2.5, op=0.45, color=None):
        """Inner shadow along the top edge (holes, sockets, recessed things)."""
        s = m * np.clip(1 - shift(blur(m, r), dx, dy), 0, 1)
        self.fill(s, self.ink if color is None else color, op)

    def body(self, m, base, light=0.22, dark=0.22, tilt=0.25):
        """Gradient fill over the mask's box: lighter at the top left, darker at the bottom right."""
        x0, y0, x1, y1 = bbox(m)
        w = x1 - x0
        g = lgrad([lighten(base, light), col(base), darken(base, dark)],
                  x0 + w * (0.5 - tilt), y0, x0 + w * (0.5 + tilt), y1)
        self.fill(m, g)

    def rim(self, m, w=1.6, op=0.5, color="#FFFFFF", dark=0.0):
        """Light band along the upper edges (and optionally a dark one along the lower edges)."""
        if op:
            self.fill(np.clip(m - shift(m, w * 0.35, w), 0, 1), color, op)
        if dark:
            self.fill(np.clip(m - shift(m, 0, -w), 0, 1), "#000000", dark)

    def gloss(self, m, op=0.3, h=0.48):
        x0, y0, x1, y1 = bbox(m)
        w, hh = x1 - x0, y1 - y0
        e = ellipse((x0 + x1) / 2 - w * 0.04, y0 + hh * h * 0.35, w * 0.52, hh * h * 0.72)
        fade = np.clip(1 - (Y - y0) / max(1.0, hh * h), 0, 1)
        self.fill(m * e * fade, "#FFFFFF", op)

    def solid(self, m, base, shadow=0.35, sd=(1.5, 4.0, 5.0), light=0.2, dark=0.24, rim=0.45, edge=0.15,
              gloss=0.0, tilt=0.25):
        """A raised object: soft shadow, gradient body, lit top edge, darker bottom edge, optional gloss."""
        if shadow:
            self.shadow(m, sd[0], sd[1], sd[2], shadow)
        self.body(m, base, light, dark, tilt)
        if rim or edge:
            self.rim(m, 1.6, rim, dark=edge)
        if gloss:
            self.gloss(m, gloss)

    def flat(self, m, color, op=1.0):
        self.fill(m, color, op)

    # ---- background and finish
    def background(self, bg):
        st = bg.get("style", "linear")
        cs = bg["colors"]
        if st == "flat":
            self.px[:] = col(cs[0])
        elif st == "radial":
            cx, cy = bg.get("center", [CX, 96])
            self.px[:] = rgrad(cs, cx, cy, bg.get("radius", 170))
        elif st == "conic":
            self.px[:] = agrad(cs, CX, CY, bg.get("angle", -90))
        elif st == "split":
            a = math.radians(bg.get("angle", 30))
            d = (X - CX) * math.sin(a) - (Y - CY) * math.cos(a) - bg.get("offset", 0)
            t = smoothstep(-0.6, 0.6, d)
            g0 = vgrad(cs[0], cs[1], T, B)
            g1 = vgrad(cs[2], cs[3] if len(cs) > 3 else cs[2], T, B)
            self.px[:] = g0 * (1 - t[..., None]) + g1 * t[..., None]
        else:
            a = math.radians(bg.get("angle", 90))
            dx, dy = math.cos(a) * SQ / 2, math.sin(a) * SQ / 2
            self.px[:] = lgrad(cs, CX - dx, CY - dy, CX + dx, CY + dy)
        pat = bg.get("pattern")
        if pat:
            self.pattern(pat, bg.get("pcolor", "#FFFFFF"), bg.get("pop", 0.07), bg)

    def pattern(self, kind, color, op, bg):
        m = None
        if kind == "rays":
            cx, cy = bg.get("pcenter", [CX, CY])
            n = bg.get("rays", 16)
            ang = (np.degrees(np.arctan2(Y - cy, X - cx)) + 360 + bg.get("prot", 0)) % (360.0 / n)
            m = blur((ang < 180.0 / n).astype(np.float32), 0.4)
        elif kind == "rings":
            cx, cy = bg.get("pcenter", [CX, CY])
            step = bg.get("step", 16)
            d = np.sqrt((X - cx) ** 2 + (Y - cy) ** 2)
            m = blur((np.abs((d / step) % 1.0 - 0.5) < bg.get("width", 0.12)).astype(np.float32), 0.3)
        elif kind == "grid":
            step = bg.get("step", 16)
            gx = np.abs(((X - CX) / step) % 1.0 - 0.5) > 0.5 - 0.6 / step
            gy = np.abs(((Y - CY) / step) % 1.0 - 0.5) > 0.5 - 0.6 / step
            m = (gx | gy).astype(np.float32)
        elif kind == "dots":
            step = bg.get("step", 14)
            u = ((X - CX) / step) % 1.0 - 0.5
            v = ((Y - CY) / step) % 1.0 - 0.5
            rr = bg.get("dot", 0.16)
            m = np.clip((rr - np.sqrt(u * u + v * v)) * step * SS, 0, 1)
        elif kind == "stripes":
            step = bg.get("step", 18)
            a = math.radians(bg.get("pangle", 45))
            d = (X * math.cos(a) + Y * math.sin(a)) / step
            m = np.clip((np.abs(d % 1.0 - 0.5) - 0.25) * step * SS / 2, 0, 1)
        elif kind == "checker":
            step = bg.get("step", 16)
            m = (((np.floor((X - CX) / step) + np.floor((Y - CY) / step)) % 2) == 0).astype(np.float32)
        elif kind == "stars":
            m = np.zeros((N, N), np.float32)
            rng = np.random.default_rng(bg.get("seed", 7))
            for _ in range(bg.get("count", 40)):
                x, y = rng.uniform(L, R), rng.uniform(T, B)
                r = rng.uniform(0.5, 1.6)
                m = U(m, circle(x, y, r) * rng.uniform(0.4, 1.0))
        elif kind == "bokeh":
            m = np.zeros((N, N), np.float32)
            rng = np.random.default_rng(bg.get("seed", 3))
            for _ in range(bg.get("count", 9)):
                x, y = rng.uniform(L, R), rng.uniform(T, B)
                m = U(m, blur(circle(x, y, rng.uniform(8, 22)), 2) * rng.uniform(0.3, 1.0))
        elif kind == "waves":
            step = bg.get("step", 22)
            d = (Y + np.sin(X / 14.0) * 4) / step
            m = np.clip((np.abs(d % 1.0 - 0.5) - 0.38) * step * SS / 2, 0, 1)
        if m is not None:
            self.fill(m, color, op)

    def finish(self, kind="soft", bgc=None):
        sq = SQM
        light = kind != "matte"
        glow = np.exp(-(((X - CX) / (SQ * 0.62)) ** 2 + ((Y - T) / (SQ * 0.5)) ** 2))
        self.fill(glow, "#FFFFFF", 0.10 if light else 0.05)
        shade = smoothstep(CY + SQ * 0.05, B, Y)
        self.fill(shade, "#000000", 0.14 if light else 0.08)
        if kind == "gloss":
            e = np.clip(0.5 - (np.sqrt(((X - CX) / (SQ * 0.66)) ** 2 + ((Y - (T - 6)) / (SQ * 0.5)) ** 2) - 1) * 20,
                        0, 1)
            fade = np.clip(1 - (Y - T) / (SQ * 0.48), 0, 1) ** 1.4
            self.fill(e * fade, "#FFFFFF", 0.16)
        fade = np.clip(1.0 - (Y - T) / (SQ * 0.5), 0, 1)
        top = np.clip(sq - shift(sq, 0, 2.0), 0, 1)
        self.fill(top * fade, "#FFFFFF", 0.55 if light else 0.35)
        fadeb = np.clip((Y - (CY + SQ * 0.1)) / (SQ * 0.4), 0, 1)
        bot = np.clip(sq - shift(sq, 0, -2.0), 0, 1)
        self.fill(bot * fadeb, "#000000", 0.14)
        edge = np.clip(sq - np.clip(0.5 - (SQ_SDF + 1.4) * SS, 0, 1), 0, 1)
        l = float(np.mean(self.px[sq > 0.5]))
        if l < 0.45:
            self.fill(edge, "#FFFFFF", 0.20 - 0.18 * l)
        self.fill(edge, "#000000", 0.04 + 0.10 * l)

    def image(self):
        sq = SQM
        rgb = np.clip(self.px, 0, 1)
        s1 = shift(blur(sq, 6.4), 0, 4.8) * 0.28
        s2 = shift(blur(sq, 1.4), 0, 1.2) * 0.14
        sh = 1 - (1 - s1) * (1 - s2)
        a = sq + sh * (1 - sq)
        pre = rgb * sq[..., None]  # the shadow is black: it only adds alpha
        pre = pre.reshape(SIZE, SS, SIZE, SS, 3).mean(axis=(1, 3))
        a = a.reshape(SIZE, SS, SIZE, SS).mean(axis=(1, 3))
        c = np.where(a[..., None] > 1e-4, pre / np.maximum(a[..., None], 1e-4), 0)
        out = np.concatenate([np.clip(c, 0, 1), np.clip(a, 0, 1)[..., None]], -1)
        out = (out * 255 + 0.5).astype(np.uint8)
        out[out[..., 3] == 0] = 0
        return Image.fromarray(out, "RGBA")
