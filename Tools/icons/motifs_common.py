"""Motif registry and the small illustrated parts several icons share (coins, balls, cubes, clocks, paper...)."""
import math

import numpy as np

from iconkit import (CX, CY, N, SS, X, Y, U, blur, box, circle, col, darken, ellipse, lgrad, lighten, line, mix,
                     poly, rgrad, ring, rrect, shift, sub)

MOTIFS = {}


def motif(fn):
    MOTIFS[fn.__name__.rstrip("_")] = fn
    return fn


def sphere(ic, cx, cy, r, color, shadow=0.4, spec=0.85, sd=(2.0, 5.0, 5.0), m=None):
    """A shaded ball lit from the top left, with a specular spot and a faint bounce light at the bottom right."""
    m = circle(cx, cy, r) if m is None else m
    if shadow:
        ic.shadow(m, sd[0], sd[1], sd[2], shadow)
    ic.fill(m, rgrad([(0, lighten(color, 0.45)), (0.45, col(color)), (1.0, darken(color, 0.5))],
                     cx - r * 0.38, cy - r * 0.42, r * 1.55))
    ic.fill(m * circle(cx + r * 0.25, cy + r * 0.3, r * 0.95) * (1 - circle(cx + r * 0.05, cy + r * 0.08, r * 0.95)),
            lighten(color, 0.3), 0.25)
    if spec:
        ic.fill(blur(ellipse(cx - r * 0.36, cy - r * 0.42, r * 0.3, r * 0.2, -35), r * 0.06) * m, "#FFFFFF", spec)
    return m


def coin(ic, cx, cy, r, color="#F5B921", tilt=0.0, mark="star", shadow=0.35):
    """A thick gold coin seen slightly from above: edge, face, inner ring and an embossed mark."""
    ry = r * (1 - tilt)
    edge = ellipse(cx, cy + r * 0.12, r, ry)
    face = ellipse(cx, cy, r, ry)
    if shadow:
        ic.shadow(U(edge, face), 1.5, 4, 4, shadow)
    ic.fill(edge, darken(color, 0.3))
    ic.fill(face, lgrad([lighten(color, 0.35), col(color), darken(color, 0.15)], cx - r, cy - ry, cx + r, cy + ry))
    inner = ellipse(cx, cy, r * 0.74, ry * 0.74)
    ic.fill(np.clip(face - inner, 0, 1), lighten(color, 0.25), 0.35)
    ic.fill(np.clip(ellipse(cx, cy + 0.8, r * 0.74, ry * 0.74) - inner, 0, 1), darken(color, 0.35), 0.5)
    if mark == "star":
        from iconkit import star_pts
        pts = [(x, cy + (y - cy) * (1 - tilt)) for x, y in star_pts(cx, cy, r * 0.42, r * 0.19)]
        s = poly(pts)
        ic.fill(shift(s, 0, 0.8), darken(color, 0.35), 0.6)
        ic.fill(s, lighten(color, 0.3))
    ic.fill(face * ellipse(cx - r * 0.35, cy - ry * 0.45, r * 0.45, ry * 0.22), "#FFFFFF", 0.25)
    return U(edge, face)


def iso_cube(ic, cx, cy, s, top, left, right, h=None, shadow=0.3, edge=True, gap=0.0):
    """An isometric cube whose top face is centred at (cx, cy). Returns its mask."""
    h = s if h is None else h
    dx, dy = s * 0.866, s * 0.5
    t = [(cx, cy - dy), (cx + dx, cy), (cx, cy + dy), (cx - dx, cy)]
    lf = [(cx - dx, cy), (cx, cy + dy), (cx, cy + dy + h), (cx - dx, cy + h)]
    rt = [(cx, cy + dy), (cx + dx, cy), (cx + dx, cy + h), (cx, cy + dy + h)]

    def inset(pts):
        if not gap:
            return pts
        mx = sum(p[0] for p in pts) / len(pts)
        my = sum(p[1] for p in pts) / len(pts)
        out = []
        for x, y in pts:
            d = math.hypot(x - mx, y - my) or 1
            out.append((x - (x - mx) / d * gap, y - (y - my) / d * gap))
        return out

    mt, ml, mr = poly(inset(t)), poly(inset(lf)), poly(inset(rt))
    allm = poly([t[0], t[1], rt[2], rt[3], lf[3], t[3]])
    if shadow:
        ic.shadow(allm, 2, 5, 5, shadow)
    if gap:
        ic.fill(allm, darken(right, 0.45))
    ic.fill(ml, lgrad([lighten(left, 0.06), darken(left, 0.06)], cx - dx, cy, cx, cy + h + dy))
    ic.fill(mr, lgrad([col(right), darken(right, 0.1)], cx, cy, cx + dx, cy + h))
    ic.fill(mt, lgrad([lighten(top, 0.1), col(top)], cx - dx, cy - dy, cx + dx, cy + dy))
    if edge:
        ic.fill(line(inset(t)[3:] + inset(t)[:2], 1.0), "#FFFFFF", 0.45)
        ic.fill(line([inset(lf)[1], inset(lf)[2]], 0.8), "#FFFFFF", 0.2)
    return allm


def paper(ic, m, top="#FFFFFF", bottom="#E9ECF2", shadow=0.3, sd=(1.5, 4.5, 5.0)):
    """A white sheet or card."""
    from iconkit import bbox, vgrad
    if shadow:
        ic.shadow(m, sd[0], sd[1], sd[2], shadow)
    x0, y0, x1, y1 = bbox(m)
    ic.fill(m, vgrad(top, bottom, y0, y1))
    ic.rim(m, 1.4, 0.8, dark=0.08)


def check(cx, cy, s, w):
    """A check mark polyline mask, s = width of the mark."""
    return line([(cx - s * 0.5, cy), (cx - s * 0.15, cy + s * 0.34), (cx + s * 0.5, cy - s * 0.36)], w)


def clock_face(ic, cx, cy, r, face="#FFFFFF", rim="#2B2F3A", hands="#1E2230", accent="#FF5A36", h=10.2, mn=2.0,
               ticks=True, shadow=0.35, sec=True):
    """A round clock: rim, face, ticks and hands (h hours, mn minutes as clock positions 0..12)."""
    outer = circle(cx, cy, r)
    if shadow:
        ic.shadow(outer, 1.5, 4.5, 5, shadow)
    ic.fill(outer, lgrad([lighten(rim, 0.25), col(rim), darken(rim, 0.25)], cx - r, cy - r, cx + r, cy + r))
    fr = r * 0.86
    fm = circle(cx, cy, fr)
    ic.fill(fm, rgrad([(0, lighten(face, 0.05)), (0.85, col(face)), (1, darken(face, 0.08))], cx, cy - fr * 0.3,
                      fr * 1.3))
    ic.inner(fm, 2.0, 0, 1.5, 0.35)
    if ticks:
        tm = np.zeros((N, N), np.float32)
        for i in range(12):
            a = math.radians(i * 30 - 90)
            big = i % 3 == 0
            r0 = fr * (0.74 if big else 0.8)
            tm = U(tm, line([(cx + r0 * math.cos(a), cy + r0 * math.sin(a)),
                             (cx + fr * 0.88 * math.cos(a), cy + fr * 0.88 * math.sin(a))], r * (0.07 if big else 0.035)))
        ic.fill(tm, hands, 0.85)

    def hand(pos, length, w, color):
        a = math.radians(pos * 30 - 90)
        hm = line([(cx - math.cos(a) * w, cy - math.sin(a) * w), (cx + length * math.cos(a), cy + length * math.sin(a))], w)
        ic.shadow(hm, 0.8, 1.6, 1.2, 0.3)
        ic.fill(hm, color)

    hand(h, fr * 0.5, r * 0.1, hands)
    hand(mn, fr * 0.74, r * 0.07, hands)
    if sec:
        hand((mn + 3.6) % 12, fr * 0.8, r * 0.03, accent)
    ic.fill(circle(cx, cy, r * 0.075), accent)
    ic.fill(circle(cx, cy, r * 0.03), "#FFFFFF", 0.9)
    return outer


def pixels(ic, rows, x0, y0, px, colors, gap=0.0, shadow=0.3, bevel=True):
    """Pixel art from strings: each character is a key in colors ('.' or ' ' is empty)."""
    allm = np.zeros((N, N), np.float32)
    cells = {}
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch in ". ":
                continue
            m = rrect(x0 + i * px + gap / 2, y0 + j * px + gap / 2, x0 + (i + 1) * px - gap / 2,
                      y0 + (j + 1) * px - gap / 2, gap * 0.6)
            cells.setdefault(ch, []).append(m)
            allm = U(allm, m)
    if shadow:
        ic.shadow(allm, 1.5, 4, 4, shadow)
    for ch, ms in cells.items():
        m = U(*ms)
        ic.fill(m, colors[ch])
        if bevel:
            ic.fill(np.clip(m - shift(m, 0, px * 0.18), 0, 1), "#FFFFFF", 0.22)
            ic.fill(np.clip(m - shift(m, 0, -px * 0.18), 0, 1), "#000000", 0.16)
    return allm


def pencil(ic, x0, y0, x1, y1, w, body="#FFC93C", wood="#F3D3A1", lead="#2B2B33", eraser="#FF7A8A",
           band="#C9CED8", shadow=0.35):
    """A pencil from the eraser end (x0, y0) to the tip (x1, y1)."""
    ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
    Lg = math.hypot(x1 - x0, y1 - y0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2

    def seg(a, b, w2, r=0.0):
        # a rectangle from a to b along the pencil (fractions of the length)
        xa, xb = cx - Lg / 2 + a * Lg, cx - Lg / 2 + b * Lg
        return rrect(xa, cy - w2 / 2, xb, cy + w2 / 2, r, ang, (cx, cy))

    tipL = 0.2
    from iconkit import rotate
    xt0 = cx - Lg / 2 + (1 - tipL) * Lg
    tip = poly(rotate([(xt0, cy - w / 2), (cx + Lg / 2, cy), (xt0, cy + w / 2)], ang, cx, cy))
    xl = cx - Lg / 2 + (1 - tipL * 0.32) * Lg
    leadm = poly(rotate([(xl, cy - w * 0.16), (cx + Lg / 2, cy), (xl, cy + w * 0.16)], ang, cx, cy))
    er = seg(0.0, 0.14, w, w * 0.35)
    bd = seg(0.12, 0.22, w * 1.04)
    shaft = seg(0.2, 1 - tipL + 0.005, w)
    allm = U(er, bd, shaft, tip)
    if shadow:
        ic.shadow(allm, 2, 5, 5, shadow)
    ic.body(er, eraser, 0.2, 0.2)
    ic.body(bd, band, 0.3, 0.3)
    ic.fill(tip, wood)
    ic.fill(leadm, lead)
    ic.body(shaft, body, 0.25, 0.2)
    # a lighter facet along the shaft
    ic.fill(seg(0.21, 1 - tipL, w * 0.22), "#FFFFFF", 0.22)
    return allm


def iso_box(ic, cx, cy, sw, sd, h, color, shadow=0.3, light=0.2, darkr=0.28, rim=0.5):
    """An isometric box: top face centred at (cx, cy), sw along the right axis, sd along the left one, h tall."""
    ex = (0.866 * sw / 2, 0.5 * sw / 2)
    ey = (-0.866 * sd / 2, 0.5 * sd / 2)
    A = (cx - ex[0] - ey[0], cy - ex[1] - ey[1])
    Bp = (cx + ex[0] - ey[0], cy + ex[1] - ey[1])
    C = (cx + ex[0] + ey[0], cy + ex[1] + ey[1])
    D = (cx - ex[0] + ey[0], cy - ex[1] + ey[1])
    dn = lambda p: (p[0], p[1] + h)
    top = poly([A, Bp, C, D])
    right = poly([Bp, C, dn(C), dn(Bp)])
    left = poly([D, C, dn(C), dn(D)])
    allm = U(top, right, left)
    if shadow:
        ic.shadow(allm, 2, 5, 5, shadow)
    ic.fill(left, lgrad([col(color), darken(color, 0.1)], D[0], D[1], C[0], C[1] + h))
    ic.fill(right, lgrad([darken(color, darkr * 0.7), darken(color, darkr)], C[0], C[1], Bp[0], Bp[1] + h))
    ic.fill(top, lgrad([lighten(color, light + 0.08), lighten(color, light * 0.6)], A[0], A[1], C[0], C[1]))
    if rim:
        ic.fill(line([D, C, Bp], 1.0), "#FFFFFF", rim)
    return allm


def cloud(cx, cy, w, puffs=None):
    """A flat-bottomed cloud mask, w wide."""
    s = w / 100.0
    puffs = puffs or [(-28, 4, 22), (-6, -12, 28), (22, -4, 24), (38, 8, 16)]
    m = rrect(cx - 46 * s, cy + 2 * s, cx + 52 * s, cy + 26 * s, 12 * s)
    for (x, y, r) in puffs:
        m = U(m, circle(cx + x * s, cy + y * s, r * s))
    return m


def soft_shadow_ellipse(ic, cx, cy, rx, ry, op=0.3, r=4.0):
    ic.fill(blur(ellipse(cx, cy, rx, ry), r), ic.ink, op)


__all__ = ["MOTIFS", "motif", "sphere", "coin", "iso_cube", "iso_box", "cloud", "paper", "check", "clock_face", "pixels", "pencil",
           "soft_shadow_ellipse"]
