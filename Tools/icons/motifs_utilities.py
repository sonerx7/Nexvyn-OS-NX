"""App icons: utilities."""
import math

import numpy as np

from iconkit import (B, CX, CY, L, N, R, T, U, X, Y, agrad, arc, bezier, blur, box, circle, col, darken, ellipse,
                     ellipse_pts, heart_pts, lgrad, lighten, line, mix, pie, polar, poly, ramp, rgrad, ring, rotate,
                     rrect, shift, smoothstep, sparkle, star, sub, text, vgrad)
from motifs_common import check, clock_face, coin, iso_cube, motif, paper, sphere


def gauge_arc(ic, cx, cy, r, w, a0, a1, colors):
    m = arc(cx, cy, r, a0, a1, w, True)
    ic.fill(m, agrad(colors, cx, cy, a0 - 10))
    return m


@motif
def bmi(ic):
    P = ic.P
    scale = rrect(46, 46, 210, 210, 36)
    ic.shadow(scale, 2, 8, 8, 0.4)
    ic.fill(scale, lgrad([lighten(P["body"], 0.15), P["body"], darken(P["body"], 0.12)], 46, 46, 210, 210))
    ic.rim(scale, 1.8, 0.7, dark=0.1)
    win = rrect(78, 62, 178, 118, 20)
    ic.fill(win, darken(P["window"], 0.1))
    ic.inner(win, 2.5, 0, 2.5, 0.5, "#000000")
    cx, cy = 128, 118
    segs = [(200, 236, P["g1"]), (238, 274, P["g2"]), (276, 312, P["g3"]), (314, 340, P["g4"])]
    for (a0, a1, c) in segs:
        ic.fill(arc(cx, cy, 36, a0, a1, 9, False), c)
    nd = line([(cx, cy), polar(cx, cy, 40, 262)], 3.5)
    ic.fill(nd, P["needle"])
    ic.fill(circle(cx, cy - 1, 5), P["needle"])
    ic.fill(win * smoothstep(90, 62, Y), "#FFFFFF", 0.12)
    for x0 in (66, 136):
        pad = rrect(x0, 132, x0 + 54, 196, 18)
        ic.fill(pad, darken(P["body"], 0.08))
        ic.inner(pad, 2, 0, 1.5, 0.2)
        grip = np.zeros((N, N), np.float32)
        for y in range(142, 190, 9):
            grip = U(grip, line([(x0 + 12, y), (x0 + 42, y)], 2.6))
        ic.fill(grip, darken(P["body"], 0.22))


@motif
def colorconv(ic):
    P = ic.P
    r = 46
    cs = [(128, 92, P["r"]), (98, 144, P["g"]), (158, 144, P["b"])]
    for (x, y, c) in cs:
        ic.add(blur(circle(x, y, r), 10), c, 0.35)
    for (x, y, c) in cs:
        ic.add(circle(x, y, r), c, 0.85)
    for (x, y, _) in cs:
        ic.fill(ring(x, y, r, 1.6), "#FFFFFF", 0.35)
    for (a0, a1) in ((-150, -100), (30, 80)):
        m = arc(128, 124, 96, a0, a1, 5)
        ic.fill(m, "#FFFFFF", 0.85)
        tx, ty = polar(128, 124, 96, a1)
        d = a1 + 90
        ic.fill(poly([polar(tx, ty, 9, d), polar(tx, ty, 8, d - 120), polar(tx, ty, 8, d + 120)]), "#FFFFFF", 0.85)


@motif
def countdown(ic):
    P = ic.P
    cx = 128
    top_cap = rrect(70, 42, 186, 60, 7)
    bot_cap = rrect(70, 190, 186, 208, 7)
    pts_l = bezier((84, 60), (84, 110), (122, 112), (122, 125)) + bezier((122, 125), (122, 138), (84, 140), (84, 190))[1:]
    pts_r = [(256 - x, y) for x, y in pts_l]
    glass = poly(pts_l + pts_r[::-1])
    ic.add(blur(glass, 14), P["glow"], 0.25)
    ic.fill(glass, "#FFFFFF", 0.18)
    sand_top = glass * ((Y > 92) & (Y < 125)).astype(np.float32)
    ic.fill(sand_top, lgrad([lighten(P["sand"], 0.2), darken(P["sand"], 0.15)], 90, 0, 166, 0))
    pile = poly([(88, 190)] + bezier((88, 190), (100, 160), (156, 160), (168, 190))) * glass
    ic.fill(pile, lgrad([lighten(P["sand"], 0.2), darken(P["sand"], 0.15)], 0, 160, 0, 190))
    ic.fill(line([(128, 124), (128, 170)], 2.6), P["sand"])
    ic.fill(np.clip(glass - shift(glass, 2.5, 0), 0, 1), "#FFFFFF", 0.7)
    ic.fill(np.clip(glass - shift(glass, -2.5, 0), 0, 1), "#FFFFFF", 0.35)
    ic.fill(line(bezier((96, 72), (98, 98), (112, 106), (116, 114)), 3) * glass, "#FFFFFF", 0.45)
    for m in (top_cap, bot_cap):
        ic.shadow(m, 1.5, 4, 4, 0.4)
        y0 = 42 if m is top_cap else 190
        ic.fill(m, vgrad(lighten(P["wood"], 0.25), darken(P["wood"], 0.3), y0, y0 + 18))
        ic.rim(m, 1.4, 0.45)
    for x in (78, 178):
        post = rrect(x - 4, 58, x + 4, 192, 3)
        ic.shadow(post, 1, 2, 2, 0.3)
        ic.fill(post, lgrad([lighten(P["wood"], 0.25), darken(P["wood"], 0.25)], x - 4, 0, x + 4, 0))


@motif
def datecalc(ic):
    P = ic.P
    ang = -5
    cx, cy = 124, 132
    page = box(cx, cy, 150, 150, 18, ang)
    ic.shadow(page, 2, 7, 7, 0.4)
    ic.fill(page, vgrad("#FFFFFF", "#EEF1F6", 56, 208))
    head = page * poly(rotate([(cx - 90, cy - 90), (cx + 90, cy - 90), (cx + 90, cy - 40), (cx - 90, cy - 40)], ang, cx, cy))
    ic.fill(head, lgrad([lighten(P["head"], 0.15), darken(P["head"], 0.1)], 0, 56, 0, 92))
    for dx in (-36, 36):
        rx, ry = rotate([(cx + dx, cy - 75)], ang, cx, cy)[0]
        ic.fill(rrect(rx - 5, ry - 16, rx + 5, ry + 6, 5), lgrad(["#FFFFFF", "#9AA3B5"], rx - 5, 0, rx + 5, 0))
    for r in range(4):
        for c in range(5):
            x, y = rotate([(cx - 52 + c * 26, cy - 22 + r * 24)], ang, cx, cy)[0]
            ic.fill(circle(x, y, 4.2), "#C3CAD8")
    # selected range
    a = rotate([(cx - 26, cy + 2)], ang, cx, cy)[0]
    b = rotate([(cx + 52, cy + 2)], ang, cx, cy)[0]
    ic.fill(line([a, b], 20), P["range"], 0.3)
    for p in (a, b):
        ic.fill(circle(p[0], p[1], 11), P["range"])
        ic.fill(circle(p[0], p[1], 4), "#FFFFFF")
    for k in (0, 26, 52):
        x, y = rotate([(cx + k, cy + 2)], ang, cx, cy)[0]
        if k == 26:
            ic.fill(circle(x, y, 4.2), P["range"])
    bx, by = 186, 186
    badge = circle(bx, by, 24)
    ic.shadow(badge, 1.5, 4, 4, 0.4)
    ic.fill(badge, rgrad([lighten(P["badge"], 0.3), P["badge"]], bx - 6, by - 8, 28))
    ic.fill(U(rrect(bx - 12, by - 3, bx + 12, by + 3, 3), rrect(bx - 3, by - 12, bx + 3, by + 12, 3)), "#FFFFFF")


def _face_pip(o, e1, e2, u, v, r, n=24):
    pts = []
    for i in range(n):
        a = 2 * math.pi * i / n
        uu, vv = u + r * math.cos(a), v + r * math.sin(a)
        pts.append((o[0] + uu * e1[0] + vv * e2[0], o[1] + uu * e1[1] + vv * e2[1]))
    return poly(pts)


PIPS = {1: [(0.5, 0.5)], 2: [(0.27, 0.27), (0.73, 0.73)], 3: [(0.25, 0.25), (0.5, 0.5), (0.75, 0.75)],
        4: [(0.27, 0.27), (0.73, 0.27), (0.27, 0.73), (0.73, 0.73)],
        5: [(0.25, 0.25), (0.75, 0.25), (0.5, 0.5), (0.25, 0.75), (0.75, 0.75)],
        6: [(0.27, 0.22), (0.27, 0.5), (0.27, 0.78), (0.73, 0.22), (0.73, 0.5), (0.73, 0.78)]}


def die(ic, cx, cy, s, color, pip, faces=(5, 3, 2)):
    dx, dy, h = s * 0.866, s * 0.5, s
    iso_cube(ic, cx, cy, s, lighten(color, 0.05), darken(color, 0.08), darken(color, 0.22), h, shadow=0.45)
    t = [(cx, cy - dy), (cx + dx, cy), (cx, cy + dy), (cx - dx, cy)]
    lf = [(cx - dx, cy), (cx, cy + dy), (cx, cy + dy + h), (cx - dx, cy + h)]
    rt = [(cx, cy + dy), (cx + dx, cy), (cx + dx, cy + h), (cx, cy + dy + h)]
    for (o, a, b2), n in zip(((t[3], t[0], t[2]), (lf[0], lf[1], lf[3]), (rt[0], rt[1], rt[3])), faces):
        e1 = (a[0] - o[0], a[1] - o[1])
        e2 = (b2[0] - o[0], b2[1] - o[1])
        for (u, v) in PIPS[n]:
            ic.fill(_face_pip(o, e1, e2, u, v, 0.1), pip)


@motif
def dice(ic):
    P = ic.P
    coin(ic, 186, 186, 26, P["coin"], 0.35, "star", 0.4)
    die(ic, 92, 96, 50, P["die1"], P["pip1"], (5, 3, 2))
    die(ic, 158, 138, 46, P["die2"], P["pip2"], (6, 1, 4))


@motif
def finance(ic):
    P = ic.P
    base = 196
    bars = [(52, 150), (88, 128), (124, 104), (160, 82)]
    for i, (x, top) in enumerate(bars):
        m = rrect(x, top, x + 28, base, 6)
        ic.shadow(m, 1.5, 4, 4, 0.35)
        c = mix(P["bar1"], P["bar2"], i / 3)
        ic.fill(m, lgrad([lighten(c, 0.3), c, darken(c, 0.25)], x, 0, x + 28, 0))
        ic.rim(m, 1.4, 0.5)
    ic.fill(rrect(44, base, 200, base + 4, 2), "#FFFFFF", 0.6)
    pts = [(52, 140), (92, 116), (120, 124), (176, 66)]
    ar = line(pts, 9)
    tip = (190, 52)
    head = poly([tip, (164, 58), (182, 76)])
    ic.shadow(U(ar, head), 1.5, 4, 4, 0.4)
    ic.fill(U(ar, head), lgrad([lighten(P["arrow"], 0.3), P["arrow"]], 50, 140, 190, 52))
    ic.rim(U(ar, head), 1.2, 0.5)
    for k in range(3):
        coin(ic, 196, 196 - k * 9, 18, P["coin"], 0.55, None if k < 2 else "star", 0.3 if k == 0 else 0.0)


@motif
def fuel(ic):
    P = ic.P
    bodym = rrect(56, 44, 150, 214, 16)
    ic.shadow(bodym, 2, 7, 7, 0.45)
    ic.fill(bodym, lgrad([lighten(P["pump"], 0.25), P["pump"], darken(P["pump"], 0.3)], 56, 0, 150, 0))
    ic.rim(bodym, 1.8, 0.5)
    ic.fill(rrect(52, 200, 154, 216, 6), darken(P["pump"], 0.45))
    scr = rrect(70, 60, 136, 104, 8)
    ic.fill(scr, "#101422")
    for k, w in enumerate((44, 30)):
        ic.add(blur(rrect(78, 70 + k * 16, 78 + w, 78 + k * 16, 3), 2), P["digits"], 0.6)
        ic.fill(rrect(78, 70 + k * 16, 78 + w, 78 + k * 16, 3), P["digits"])
    dm = poly(bezier((103, 120), (108, 132), (120, 142), (120, 154)) + bezier((120, 154), (120, 166), (110, 172), (103, 172))[1:] +
              bezier((103, 172), (96, 172), (86, 166), (86, 154))[1:] + bezier((86, 154), (86, 142), (98, 132), (103, 120))[1:])
    ic.fill(dm, "#FFFFFF", 0.95)
    hose = line(bezier((150, 90), (196, 88), (206, 150), (186, 200)), 9)
    ic.shadow(hose, 1.5, 4, 4, 0.35)
    ic.fill(hose, lgrad(["#3B4256", "#1A1E2A"], 150, 0, 210, 0))
    noz = poly([(176, 60), (204, 60), (210, 74), (202, 116), (186, 116), (184, 80), (170, 72)])
    ic.shadow(noz, 1.5, 4, 4, 0.4)
    ic.fill(noz, lgrad([lighten(P["nozzle"], 0.3), P["nozzle"], darken(P["nozzle"], 0.3)], 170, 0, 210, 0))
    ic.fill(rrect(160, 62, 184, 70, 3), "#2B2F3A")
    ic.fill(line([(150, 90), (176, 76)], 8), "#2B2F3A")


@motif
def globe(ic):
    P = ic.P
    cx, cy, r = 128, 124, 78
    ic.add(blur(ring(cx, cy, r, 6), 6), P["atmo"], 0.7)
    s = circle(cx, cy, r)
    ic.fill(s, rgrad([lighten(P["ocean"], 0.35), P["ocean"], darken(P["ocean"], 0.45)], cx - 26, cy - 30, r * 1.5))
    land = U(poly([(70, 84), (98, 66), (120, 74), (112, 100), (128, 112), (116, 140), (96, 128), (84, 104)]),
             poly([(124, 150), (146, 142), (156, 166), (146, 196), (132, 190)]),
             poly([(140, 70), (172, 62), (196, 84), (188, 104), (164, 100), (150, 112), (138, 96)]),
             poly([(170, 128), (196, 124), (200, 148), (182, 156)]))
    land = blur(land, 2.5)
    land = np.clip((land - 0.5) * 4 + 0.5, 0, 1) * s
    ic.fill(land, lgrad([lighten(P["land"], 0.25), P["land"], darken(P["land"], 0.3)], 60, 60, 200, 200))
    ic.fill(land * blur(circle(cx - 40, cy - 40, 30), 10), "#FFFFFF", 0.25)
    # night side with city lights
    night = s * smoothstep(cx + 10, cx + 70, X + (Y - cy) * 0.35)
    ic.fill(night, "#050A1E", 0.72)
    rng = np.random.default_rng(3)
    for _ in range(30):
        x, y = rng.uniform(150, 206), rng.uniform(70, 190)
        if land[int(y * 4), int(x * 4)] > 0.5:
            ic.add(circle(x, y, 1.4) * night, P["lights"], 1.0)
    ic.fill(blur(ellipse(cx - 30, cy - 36, 24, 14, -30), 6) * s, "#FFFFFF", 0.35)
    for (x, y) in ((100, 90), (136, 160)):
        pin = U(circle(x, y - 10, 6), poly([(x - 5, y - 8), (x + 5, y - 8), (x, y + 1)]))
        ic.shadow(pin, 1, 2, 2, 0.35)
        ic.fill(pin, P["pin"])
        ic.fill(circle(x, y - 10, 2.4), "#FFFFFF")


@motif
def graph3d(ic):
    P = ic.P
    n = 14
    k = 112 / n
    cx, cy = 128, 120
    us = np.linspace(-1, 1, n + 1)
    Z = lambda u, v: 0.55 * math.sin(2.6 * u) * math.cos(2.2 * v) + 0.2 * math.cos(3 * (u + v))

    def proj(i, j):
        u, v = us[i], us[j]
        return (cx + (i - j) * k * 0.866, cy + (i + j - n) * k * 0.5 - Z(u, v) * 40)

    quads = []
    for i in range(n):
        for j in range(n):
            z = (Z(us[i], us[j]) + Z(us[i + 1], us[j + 1])) / 2
            quads.append((i + j, i, j, z))
    quads.sort()
    stops = [P["s1"], P["s2"], P["s3"], P["s4"]]
    edges = np.zeros((N, N), np.float32)
    for (_, i, j, z) in quads:
        pts = [proj(i, j), proj(i + 1, j), proj(i + 1, j + 1), proj(i, j + 1)]
        m = poly(pts)
        t = np.clip((z + 0.75) / 1.5, 0, 1)
        c = ramp(np.array([[t]], np.float32), stops)[0, 0]
        nx_ = Z(us[i + 1], us[j]) - Z(us[i], us[j])
        shade = 0.85 + 0.6 * nx_
        ic.fill(m, np.clip(c * shade, 0, 1))
        ic.fill(np.clip(m - shift(m, 0, 0.8), 0, 1), "#FFFFFF", 0.35)


@motif
def graph(ic):
    P = ic.P
    grid = np.zeros((N, N), np.float32)
    for v in range(32, 232, 16):
        grid = U(grid, line([(v, T), (v, B)], 1.0, False), line([(L, v), (R, v)], 1.0, False))
    ic.fill(grid, P["grid"], 0.5)
    axes = U(line([(40, 148), (212, 148)], 3.5), line([(64, 46), (64, 212)], 3.5))
    ic.fill(axes, P["axis"])
    ic.fill(poly([(220, 148), (208, 141), (208, 155)]), P["axis"])
    ic.fill(poly([(64, 38), (57, 50), (71, 50)]), P["axis"])

    def f(x):
        return 148 - 50 * math.sin((x - 64) / 30.0)

    curve = line([(x, f(x)) for x in np.linspace(44, 206, 140)], 6, True)
    ic.shadow(curve, 1, 3, 3, 0.25)
    ic.fill(curve, lgrad([P["c1"], P["c2"]], 40, 0, 210, 0))
    px_ = 64 + 15 * math.pi
    for y in range(int(f(px_)) + 8, 146, 8):
        ic.fill(line([(px_, y), (px_, y + 4)], 2), P["axis"], 0.5)
    ic.fill(circle(px_, f(px_), 10), P["c1"])
    ic.fill(circle(px_, f(px_), 4.5), "#FFFFFF")
    rx = 64 + 30 * math.pi
    ic.fill(circle(rx, 148, 8), "#FFFFFF")
    ic.fill(ring(rx, 148, 7, 3.4), P["c2"])


@motif
def loancalc(ic):
    P = ic.P
    house = poly([(52, 110), (120, 52), (188, 110), (176, 110), (176, 196), (64, 196), (64, 110)])
    ic.shadow(house, 2, 7, 7, 0.45)
    walls = rrect(64, 104, 176, 196, 4)
    ic.fill(walls, lgrad([lighten(P["wall"], 0.15), darken(P["wall"], 0.1)], 0, 104, 0, 196))
    roof = poly([(44, 114), (120, 46), (196, 114), (184, 120), (120, 64), (56, 120)])
    ic.fill(roof, lgrad([lighten(P["roof"], 0.25), darken(P["roof"], 0.25)], 44, 46, 196, 120))
    ic.rim(roof, 1.4, 0.5)
    ic.fill(rrect(140, 60, 156, 90, 2), darken(P["roof"], 0.2))
    door = rrect(104, 146, 136, 196, 6)
    ic.fill(door, lgrad([lighten(P["door"], 0.2), darken(P["door"], 0.2)], 0, 146, 0, 196))
    ic.fill(circle(130, 172, 2.4), "#FFE7A3")
    for x in (76, 150):
        w = rrect(x, 122, x + 18, 140, 3)
        ic.fill(w, P["window"])
        ic.fill(U(line([(x + 9, 122), (x + 9, 140)], 1.6, False), line([(x, 131), (x + 18, 131)], 1.6, False)), "#FFFFFF", 0.7)
    tx, ty = 180, 168
    tag = poly(rotate([(tx - 22, ty - 18), (tx + 14, ty - 18), (tx + 30, ty), (tx + 14, ty + 18), (tx - 22, ty + 18)], -20, tx, ty))
    ic.fill(line([(150, 120), polar(tx, ty, 18, 200)], 1.6), "#FFFFFF", 0.8)
    ic.shadow(tag, 1.5, 4, 4, 0.4)
    ic.fill(tag, lgrad([lighten(P["tag"], 0.25), darken(P["tag"], 0.2)], tx - 20, ty - 20, tx + 30, ty + 20))
    ic.fill(circle(*rotate([(tx + 14, ty)], -20, tx, ty)[0], 3.2), "#FFFFFF")
    pc = U(circle(*rotate([(tx - 13, ty - 7)], -20, tx, ty)[0], 4), circle(*rotate([(tx + 1, ty + 7)], -20, tx, ty)[0], 4),
           line(rotate([(tx + 2, ty - 10), (tx - 14, ty + 10)], -20, tx, ty), 3))
    ic.fill(pc, "#FFFFFF")


@motif
def moon(ic):
    P = ic.P
    cx, cy, r = 128, 124, 76
    ic.add(blur(circle(cx - 20, cy, r), 14), P["glow"], 0.3)
    m = circle(cx, cy, r)
    ic.fill(m, rgrad([lighten(P["moon"], 0.3), P["moon"], darken(P["moon"], 0.25)], cx - 20, cy - 24, r * 1.3))
    for (x, y, rx, ry, a) in ((104, 98, 26, 18, -20), (150, 130, 22, 30, 10), (112, 150, 16, 12, 0), (148, 88, 12, 9, 0)):
        ic.fill(blur(ellipse(x, y, rx, ry, a), 3) * m, darken(P["moon"], 0.25), 0.6)
    for (x, y, rr) in ((92, 130, 8), (132, 112, 6), (162, 160, 9), (120, 182, 5), (84, 96, 5), (170, 104, 6)):
        ic.fill(circle(x, y, rr) * m, darken(P["moon"], 0.3), 0.5)
        ic.fill(np.clip(circle(x + rr * 0.25, y + rr * 0.3, rr) - circle(x, y, rr), 0, 1) * m, lighten(P["moon"], 0.4), 0.5)
    # waxing gibbous: lit on the left, the terminator an ellipse bulging to the right
    lit = U((X < cx).astype(np.float32), ellipse(cx, cy, r * 0.55, r))
    night = m * (1 - blur(lit, 3))
    ic.fill(night, P["night"], 0.82)
    ic.rim(m * blur(lit, 3), 1.4, 0.45)


@motif
def morse(ic):
    P = ic.P
    beam = poly([(96, 108), (226, 54), (226, 186), (96, 140)])
    ic.add(beam * smoothstep(240, 96, X), P["beam"], 0.35)
    marks = [("dot", 132), ("dash", 160), ("dot", 196)]
    for kind, x in marks:
        y = 124
        m = circle(x, y, 8) if kind == "dot" else rrect(x - 16, y - 8, x + 16, y + 8, 8)
        ic.add(blur(m, 5), P["beam"], 0.8)
        ic.fill(m, lighten(P["beam"], 0.7))
    for kind, x in (("dash", 150), ("dot", 184)):
        y = 92
        m = circle(x, y, 5) if kind == "dot" else rrect(x - 11, y - 5, x + 11, y + 5, 5)
        ic.fill(m, lighten(P["beam"], 0.5), 0.6)
    for kind, x in (("dot", 146), ("dash", 178)):
        y = 156
        m = circle(x, y, 5) if kind == "dot" else rrect(x - 11, y - 5, x + 11, y + 5, 5)
        ic.fill(m, lighten(P["beam"], 0.5), 0.6)
    stand = U(rrect(54, 196, 118, 210, 6), rrect(80, 150, 92, 200, 4))
    ic.shadow(stand, 1.5, 4, 4, 0.4)
    ic.fill(stand, lgrad([lighten(P["metal"], 0.2), darken(P["metal"], 0.3)], 54, 0, 118, 0))
    lamp = U(rrect(40, 94, 96, 154, 14), ellipse(96, 124, 12, 32))
    ic.shadow(lamp, 2, 6, 6, 0.45)
    ic.fill(lamp, lgrad([lighten(P["lamp"], 0.3), P["lamp"], darken(P["lamp"], 0.35)], 0, 94, 0, 154))
    lens = ellipse(98, 124, 10, 28)
    ic.add(blur(lens, 6), P["beam"], 0.9)
    ic.fill(lens, rgrad(["#FFFFFF", lighten(P["beam"], 0.4)], 98, 120, 26))
    for y in (108, 124, 140):
        ic.fill(rrect(48, y - 2, 84, y + 2, 2), darken(P["lamp"], 0.35), 0.6)
    ic.rim(lamp, 1.4, 0.45)


@motif
def palette(ic):
    P = ic.P
    px_, py_ = 128, 200
    cols = [P["c1"], P["c2"], P["c3"], P["c4"], P["c5"]]
    for i, (a, c) in enumerate(zip((-44, -22, 0, 22, 44), cols)):
        strip = poly(rotate([(px_ - 17, py_), (px_ + 17, py_), (px_ + 17, py_ - 150), (px_ - 17, py_ - 150)], a, px_, py_))
        strip = U(strip, circle(px_, py_, 17))
        ic.shadow(strip, 1.5, 4, 4, 0.3)
        ic.fill(strip, "#FFFFFF")
        for k in range(4):
            y0 = py_ - 146 + k * 30
            chip = poly(rotate([(px_ - 13, y0), (px_ + 13, y0), (px_ + 13, y0 + 26), (px_ - 13, y0 + 26)], a, px_, py_))
            ic.fill(chip, mix(lighten(c, 0.45), darken(c, 0.15), k / 3))
        ic.rim(strip, 1.2, 0.6)
    ic.fill(circle(px_, py_, 9), lgrad(["#FFFFFF", "#9AA3B5"], px_ - 9, py_ - 9, px_ + 9, py_ + 9))
    ic.fill(circle(px_, py_, 3.5), "#5A6275")


@motif
def passgen(ic):
    P = ic.P
    shackle = arc(128, 100, 34, 180, 360, 15, False)
    shackle = U(shackle, rrect(86.5, 98, 101.5, 120, 0), rrect(154.5, 98, 169.5, 112, 0))
    ic.shadow(shackle, 2, 5, 5, 0.4)
    ic.fill(shackle, lgrad(["#F4F6FA", "#9AA2B4", "#D9DEE8", "#6E7689"], 86, 0, 170, 0))
    ic.rim(shackle, 1.2, 0.5)
    bodym = rrect(66, 110, 190, 202, 22)
    ic.shadow(bodym, 2, 7, 7, 0.45)
    ic.fill(bodym, lgrad([lighten(P["lock"], 0.3), P["lock"], darken(P["lock"], 0.3)], 66, 110, 190, 202))
    ic.rim(bodym, 1.8, 0.5)
    ic.gloss(bodym, 0.18)
    kh = U(circle(128, 146, 11), poly([(122, 150), (134, 150), (138, 176), (118, 176)]))
    ic.fill(kh, darken(P["lock"], 0.6))
    ic.fill(np.clip(kh - shift(kh, 0, 1.5), 0, 1), "#000000", 0.4)
    for (x, y, r) in ((62, 70, 14), (196, 66, 10), (210, 112, 7)):
        ic.add(sparkle(x, y, r), P["spark"], 0.9)


@motif
def percent(ic):
    P = ic.P
    bar = line([(170, 52), (86, 196)], 22)
    ic.shadow(bar, 2, 7, 7, 0.45)
    ic.fill(shift(bar, 3, 5), darken(P["bar"], 0.45))
    ic.fill(bar, lgrad([lighten(P["bar"], 0.35), P["bar"], darken(P["bar"], 0.2)], 80, 50, 180, 200))
    ic.rim(bar, 1.6, 0.6)
    sphere(ic, 82, 86, 32, P["ball1"], 0.45, 0.9)
    sphere(ic, 174, 162, 32, P["ball2"], 0.45, 0.9)


TABLE = ["X................X",
         "XX..........XXXXXX",
         "XX..........XXXXXX",
         "XXXXXXXXXXXXXXXXXX",
         "XXXXXXXXXXXXXXXXXX",
         "XXXXXXXXXXXXXXXXXX",
         "XXXXXXXXXXXXXXXXXX"]


@motif
def periodic(ic):
    P = ic.P
    s, g = 10.2, 1.4
    x0, y0 = 128 - 18 * s / 2, 52
    for r, row in enumerate(TABLE):
        for c, ch in enumerate(row):
            if ch != "X":
                continue
            if c < 2:
                k = "s"
            elif c >= 17:
                k = "noble"
            elif c >= 12:
                k = "p"
            else:
                k = "d"
            if r == 0 and c == 0:
                k = "h"
            m = rrect(x0 + c * s + g / 2, y0 + r * s + g / 2, x0 + (c + 1) * s - g / 2, y0 + (r + 1) * s - g / 2, 2)
            ic.fill(m, P[k])
            ic.fill(np.clip(m - shift(m, 0, 1), 0, 1), "#FFFFFF", 0.35)
    for r in range(2):
        for c in range(14):
            x = x0 + (c + 3) * s
            y = y0 + (7.5 + r) * s
            m = rrect(x + g / 2, y + g / 2, x + s - g / 2, y + s - g / 2, 2)
            ic.fill(m, P["f"])
    # one element card lifted out
    cx, cy = 166, 170
    cardm = rrect(cx - 34, cy - 34, cx + 34, cy + 34, 12)
    ic.shadow(cardm, 2, 7, 7, 0.45)
    ic.fill(cardm, lgrad([lighten(P["card"], 0.25), P["card"], darken(P["card"], 0.2)], cx - 34, cy - 34, cx + 34, cy + 34))
    ic.rim(cardm, 1.6, 0.55)
    for a in (0, 60, 120):
        ic.fill(np.clip(ellipse(cx, cy, 24, 9, a) - ellipse(cx, cy, 21.5, 6.8, a), 0, 1), "#FFFFFF", 0.9)
    ic.fill(circle(cx, cy, 5.5), "#FFFFFF")
    for a in (20, 200, 290):
        ex, ey = rotate([(cx + 24, cy)], a if a != 290 else 120, cx, cy)[0]
        ic.fill(circle(ex, ey, 3), P["electron"])


@motif
def qrcode(ic):
    P = ic.P
    cardm = rrect(52, 48, 204, 200, 18)
    ic.shadow(cardm, 2, 7, 7, 0.45)
    ic.fill(cardm, "#FFFFFF")
    n = 21
    s = 128 / n
    x0, y0 = 64, 60
    rng = np.random.default_rng(21)
    mods = np.zeros((N, N), np.float32)
    for r in range(n):
        for c in range(n):
            finder = (r < 8 and c < 8) or (r < 8 and c >= n - 8) or (r >= n - 8 and c < 8)
            centre = 8 <= r <= 12 and 8 <= c <= 12
            if finder or centre:
                continue
            if rng.random() < 0.5:
                mods = U(mods, rrect(x0 + c * s + 0.6, y0 + r * s + 0.6, x0 + (c + 1) * s - 0.6, y0 + (r + 1) * s - 0.6, 1.8))
    ic.fill(mods, lgrad([P["q1"], P["q2"]], x0, y0, x0 + 128, y0 + 128))
    for (fx, fy) in ((x0, y0), (x0 + (n - 7) * s, y0), (x0, y0 + (n - 7) * s)):
        o = sub(rrect(fx, fy, fx + 7 * s, fy + 7 * s, 8), rrect(fx + s, fy + s, fx + 6 * s, fy + 6 * s, 5))
        ic.fill(o, P["q1"])
        ic.fill(rrect(fx + 2 * s, fy + 2 * s, fx + 5 * s, fy + 5 * s, 4), P["q2"])
    lg = rrect(x0 + 8.4 * s, y0 + 8.4 * s, x0 + 12.6 * s, y0 + 12.6 * s, 6)
    ic.fill(lg, lgrad([lighten(P["logo"], 0.2), darken(P["logo"], 0.15)], x0 + 8 * s, y0 + 8 * s, x0 + 13 * s, y0 + 13 * s))
    ic.fill(circle(x0 + 10.5 * s, y0 + 10.5 * s, 4), "#FFFFFF")
    ly = 150
    ic.add(blur(rrect(40, ly - 2, 216, ly + 2, 2), 4), P["laser"], 0.9)
    ic.fill(rrect(40, ly - 1.5, 216, ly + 1.5, 1.5), lighten(P["laser"], 0.5))
    ic.add(cardm * smoothstep(ly + 30, ly, Y) * (Y < ly), P["laser"], 0.12)
    br = np.zeros((N, N), np.float32)
    for (x, y, sx, sy) in ((40, 36, 1, 1), (216, 36, -1, 1), (40, 212, 1, -1), (216, 212, -1, -1)):
        br = U(br, line([(x, y + sy * 22), (x, y), (x + sx * 22, y)], 5))
    ic.fill(br, P["bracket"], 0.95)


@motif
def roman(ic):
    P = ic.P
    tab = U(rrect(72, 70, 184, 204, 10), ellipse(128, 76, 56, 22))
    ic.shadow(tab, 2, 7, 7, 0.45)
    ic.fill(tab, lgrad([lighten(P["marble"], 0.2), P["marble"], darken(P["marble"], 0.15)], 72, 50, 184, 204))
    rng = np.random.default_rng(2)
    veins = np.zeros((N, N), np.float32)
    for _ in range(4):
        x, y = rng.uniform(80, 176), rng.uniform(70, 200)
        pts = [(x, y)]
        for _ in range(6):
            x += rng.uniform(-8, 12)
            y += rng.uniform(4, 12)
            pts.append((x, y))
        veins = U(veins, line(pts, 1.0, False))
    ic.fill(veins * tab, darken(P["marble"], 0.25), 0.5)
    ic.rim(tab, 1.6, 0.6)
    g = text("X", "serif", 96, 128, 140)
    ic.fill(shift(g, -1.2, -1.2), darken(P["marble"], 0.45), 0.9)
    ic.fill(g, lgrad([darken(P["marble"], 0.25), lighten(P["marble"], 0.1)], 0, 100, 0, 180))

    def branch(sgn):
        stem_pts = [(128 + sgn * (66 * math.sin(math.radians(t))), 132 + 74 * math.cos(math.radians(t)) * 0.95)
                    for t in np.linspace(150, 20, 30)]
        st = line(stem_pts, 3)
        ic.fill(st, darken(P["laurel"], 0.2))
        for i in range(2, 30, 4):
            x, y = stem_pts[i]
            a = math.degrees(math.atan2(stem_pts[i][1] - stem_pts[i - 1][1], stem_pts[i][0] - stem_pts[i - 1][0]))
            for side in (-1, 1):
                lx, ly = polar(x, y, 9, a + side * 50)
                lf = ellipse(lx, ly, 10, 4.2, a + side * 50)
                ic.fill(lf, lgrad([lighten(P["laurel"], 0.25), darken(P["laurel"], 0.15)], lx - 8, ly - 8, lx + 8, ly + 8))

    branch(-1)
    branch(1)


@motif
def solar(ic):
    P = ic.P
    sx, sy = 36, 170
    ic.add(blur(circle(sx, sy, 70), 22), P["sun"], 0.7)
    ic.fill(circle(sx, sy, 44), rgrad(["#FFFFFF", lighten(P["sun"], 0.3), P["sun"]], sx + 10, sy - 10, 54))
    orbits = [(70, 0.42), (112, 0.42), (156, 0.42)]
    for (r, k) in orbits:
        ic.fill(np.clip(ellipse(sx, sy, r, r * k, -24) - ellipse(sx, sy, r - 1.4, r * k - 1.4, -24), 0, 1), "#FFFFFF", 0.35)

    def on_orbit(r, k, t):
        x = sx + r * math.cos(math.radians(t))
        y = sy + r * k * math.sin(math.radians(t))
        return rotate([(x, y)], -24, sx, sy)[0]

    x, y = on_orbit(70, 0.42, -40)
    sphere(ic, x, y, 9, P["p1"], 0.3, 0.7)
    x, y = on_orbit(112, 0.42, -70)
    sphere(ic, x, y, 14, P["p2"], 0.35, 0.8)
    x, y = on_orbit(156, 0.42, -62)
    back = np.clip(ellipse(x, y, 40, 11, -24) - ellipse(x, y, 30, 7, -24), 0, 1) * (Y < y)
    front = np.clip(ellipse(x, y, 40, 11, -24) - ellipse(x, y, 30, 7, -24), 0, 1) * (Y >= y)
    ic.fill(back, P["ring"], 0.9)
    sphere(ic, x, y, 24, P["p3"], 0.4, 0.8)
    ic.fill(front, lgrad([lighten(P["ring"], 0.3), darken(P["ring"], 0.2)], x - 40, 0, x + 40, 0))
    x, y = on_orbit(112, 0.42, 40)
    sphere(ic, x, y, 7, P["p4"], 0.25, 0.7)


@motif
def splitbill(ic):
    P = ic.P
    top, bot, tear_x = 44, 206, 128

    def half(left, ang, pivot_x):
        tear = [(tear_x + (3 if i % 2 else -3), top + (bot - top) * i / 11) for i in range(12)]
        if left:
            x0 = 52
            teeth = [(tear_x - (tear_x - x0) * i / 8, bot if i % 2 == 0 else bot - 8) for i in range(9)]
            pts = [(x0, top)] + tear + teeth
        else:
            x1 = 204
            teeth = [(x1 - (x1 - tear_x) * i / 8, bot if i % 2 == 0 else bot - 8) for i in range(9)]
            pts = [(tear_x - 3, top), (x1, top)] + teeth + tear[::-1]
        m = poly(rotate(pts, ang, pivot_x, 125))
        ic.shadow(m, 2, 6, 6, 0.4)
        ic.fill(m, vgrad("#FFFFFF", "#EDF0F5", top, bot))
        lm = np.zeros((N, N), np.float32)
        xa, xb = (64, 118) if left else (138, 192)
        for k in range(5):
            y = 70 + k * 22
            lm = U(lm, line(rotate([(xa, y), (xb - (14 if k == 4 else 0), y)], ang, pivot_x, 125), 5))
        ic.fill(lm * m, "#C9D0DD")

    half(True, -8, 80)
    half(False, 8, 176)
    coin(ic, 92, 196, 20, P["coin"], 0.3, "star", 0.4)
    coin(ic, 170, 196, 20, P["coin"], 0.3, "star", 0.4)


@motif
def tally(ic):
    P = ic.P
    frame = rrect(36, 50, 220, 196, 14)
    ic.shadow(frame, 2, 7, 7, 0.45)
    ic.fill(frame, lgrad([lighten(P["wood"], 0.25), P["wood"], darken(P["wood"], 0.3)], 0, 50, 0, 196))
    board = rrect(48, 62, 208, 184, 6)
    ic.fill(board, rgrad([lighten(P["board"], 0.12), P["board"], darken(P["board"], 0.2)], 110, 100, 130))
    ic.inner(board, 2.5, 0, 2.5, 0.5, "#000000")
    rng = np.random.default_rng(9)
    ch = np.zeros((N, N), np.float32)
    for i in range(4):
        x = 72 + i * 20
        ch = U(ch, line([(x + rng.uniform(-2, 2), 82), (x + rng.uniform(-3, 3), 160)], 6))
    ch = U(ch, line([(60, 146), (148, 92)], 6))
    for i in range(2):
        x = 166 + i * 20
        ch = U(ch, line([(x, 82), (x + rng.uniform(-3, 3), 160)], 6))
    tex = np.clip(rng.random((N, N)).astype(np.float32) * 1.4, 0, 1)
    ic.fill(ch * (0.55 + 0.45 * tex), P["chalk"], 0.95)
    ic.fill(ch * (1 - tex) * 0.6, P["chalk2"], 0.4)
    stick = box(166, 204, 36, 10, 4, -12)
    ic.shadow(stick, 1, 3, 3, 0.35)
    ic.fill(stick, lgrad(["#FFFFFF", "#D9DEE8"], 0, 196, 0, 212))


@motif
def texttools(ic):
    P = ic.P
    sel = rrect(54, 68, 172, 188, 14)
    ic.fill(sel, P["sel"], 0.35)
    g = text("A", "serif", 150, 112, 128)
    ic.shadow(g, 2, 7, 6, 0.45)
    ic.fill(g, lgrad(["#FFFFFF", lighten(P["sel"], 0.6)], 0, 60, 0, 190))
    cur = U(rrect(186, 58, 192, 198, 3), rrect(176, 54, 202, 62, 3), rrect(176, 194, 202, 202, 3))
    ic.add(blur(cur, 5), P["cursor"], 0.6)
    ic.fill(cur, P["cursor"])
    ic.add(sparkle(60, 52, 10), "#FFFFFF", 0.9)


@motif
def tipcalc(ic):
    P = ic.P
    jar = U(rrect(64, 74, 192, 214, 30), rrect(76, 60, 180, 90, 8))
    ic.shadow(jar, 2, 7, 7, 0.4)
    inside = rrect(68, 78, 188, 210, 26)
    for (x, y, r) in ((92, 190, 16), (124, 194, 16), (156, 190, 16), (108, 172, 15), (142, 172, 15), (124, 154, 14)):
        coin(ic, x, y, r, P["coin"], 0.45, "star", 0.0)
    note = box(146, 64, 30, 60, 4, 14)
    ic.fill(note, lgrad([lighten(P["note"], 0.2), darken(P["note"], 0.15)], 130, 30, 160, 96))
    ic.fill(ellipse(*rotate([(146, 58)], 14, 146, 64)[0], 7, 7), lighten(P["note"], 0.35))
    ic.fill(jar, "#FFFFFF", 0.2)
    ic.fill(np.clip(jar - shift(jar, 3, 0), 0, 1), "#FFFFFF", 0.75)
    ic.fill(np.clip(jar - shift(jar, -3, 0), 0, 1), "#FFFFFF", 0.4)
    ic.fill(rrect(78, 96, 86, 196, 4), "#FFFFFF", 0.35)
    neck = rrect(72, 54, 184, 70, 8)
    ic.shadow(neck, 1, 3, 3, 0.3)
    ic.fill(neck, lgrad([lighten(P["lid"], 0.3), P["lid"], darken(P["lid"], 0.3)], 72, 0, 184, 0))
    ic.fill(rrect(110, 59, 146, 64, 2.5), darken(P["lid"], 0.55))
    label = rrect(92, 110, 164, 150, 10)
    ic.fill(label, "#FFFFFF", 0.92)
    h = poly(heart_pts(128, 131, 14))
    ic.fill(h, P["heart"])


@motif
def unitconv(ic):
    P = ic.P
    tape = rrect(110, 132, 226, 168, 3)
    ic.shadow(tape, 1.5, 4, 4, 0.35)
    ic.fill(tape, lgrad([lighten(P["tape"], 0.2), darken(P["tape"], 0.1)], 0, 132, 0, 168))
    ticks = np.zeros((N, N), np.float32)
    for k, x in enumerate(np.arange(116, 226, 6)):
        h = 14 if k % 5 == 0 else 8
        ticks = U(ticks, line([(x, 132), (x, 132 + h)], 1.6, False))
    ic.fill(ticks, "#1E2433", 0.85)
    hook = rrect(214, 124, 224, 176, 2)
    ic.fill(hook, lgrad(["#F4F6FA", "#7C869A"], 214, 0, 224, 0))
    case = circle(92, 138, 58)
    ic.shadow(case, 2, 7, 7, 0.45)
    ic.fill(case, rgrad([lighten(P["case"], 0.35), P["case"], darken(P["case"], 0.35)], 76, 118, 74))
    ic.fill(circle(92, 138, 40), darken(P["case"], 0.2))
    ic.fill(circle(92, 138, 36), rgrad([lighten(P["case"], 0.2), P["case"]], 84, 128, 40))
    ic.fill(circle(92, 138, 14), lgrad(["#F4F6FA", "#7C869A"], 80, 126, 104, 150))
    ic.fill(rrect(132, 128, 150, 172, 4), darken(P["case"], 0.4))
    ic.rim(case, 1.8, 0.5)
    arrows = U(line([(100, 62), (196, 62)], 7), poly([(88, 62), (106, 50), (106, 74)]), poly([(208, 62), (190, 50), (190, 74)]))
    ic.shadow(arrows, 1, 3, 3, 0.3)
    ic.fill(arrows, "#FFFFFF")


@motif
def wheel(ic):
    P = ic.P
    cx, cy, r = 128, 132, 78
    ic.shadow(circle(cx, cy, r + 8), 2, 7, 7, 0.45)
    ic.fill(circle(cx, cy, r + 8), lgrad([lighten(P["rim"], 0.3), darken(P["rim"], 0.3)], cx - r, cy - r, cx + r, cy + r))
    cols = [P["c1"], P["c2"], P["c3"], P["c4"], P["c1"], P["c2"], P["c3"], P["c4"]]
    off = 12
    for i, c in enumerate(cols):
        m = pie(cx, cy, r, off + i * 45, off + (i + 1) * 45)
        ic.fill(m, rgrad([lighten(c, 0.3), c, darken(c, 0.15)], cx, cy, r))
    for i in range(8):
        a = off + i * 45
        ic.fill(line([(cx, cy), polar(cx, cy, r, a)], 2.4, False), "#FFFFFF", 0.9)
    for i in range(16):
        x, y = polar(cx, cy, r + 4, i * 22.5 + 6)
        ic.add(blur(circle(x, y, 2.6), 1.5), P["bulb"], 0.7)
        ic.fill(circle(x, y, 2.2), "#FFFFFF")
    hub = circle(cx, cy, 15)
    ic.shadow(hub, 1, 3, 3, 0.4)
    ic.fill(hub, rgrad(["#FFFFFF", P["rim"]], cx - 4, cy - 5, 18))
    ptr = poly([(cx - 14, 36), (cx + 14, 36), (cx, 64)])
    ic.shadow(ptr, 1.5, 4, 4, 0.45)
    ic.fill(ptr, lgrad([lighten(P["pointer"], 0.3), darken(P["pointer"], 0.2)], 0, 36, 0, 64))
    ic.fill(circle(cx, 38, 7), lighten(P["pointer"], 0.2))
    ic.gloss(circle(cx, cy, r), 0.18)


@motif
def worldclock(ic):
    P = ic.P
    gx, gy, gr = 104, 104, 64
    gm = circle(gx, gy, gr)
    ic.shadow(gm, 2, 6, 6, 0.4)
    ic.fill(gm, rgrad([lighten(P["globe"], 0.35), P["globe"], darken(P["globe"], 0.4)], gx - 20, gy - 24, gr * 1.5))
    mer = np.zeros((N, N), np.float32)
    for rx in (22, 44):
        mer = U(mer, np.clip(ellipse(gx, gy, rx, gr) - ellipse(gx, gy, rx - 1.6, gr - 1.6), 0, 1))
    for dy in (-34, 0, 34):
        w = math.sqrt(max(gr * gr - dy * dy, 0))
        mer = U(mer, line([(gx - w, gy + dy), (gx + w, gy + dy)], 1.6, False))
    mer = U(mer, line([(gx, gy - gr), (gx, gy + gr)], 1.6, False))
    ic.fill(mer * gm, "#FFFFFF", 0.45)
    ic.rim(gm, 1.4, 0.4)
    clock_face(ic, 164, 162, 50, "#FFFFFF", P["rim"], "#1E2433", P["hand"], 10.0, 2.0, True, 0.45)
    ic.fill(circle(190, 66, 13), rgrad(["#FFFFFF", P["sun"]], 186, 62, 16))
    for a in range(0, 360, 45):
        ic.fill(line([polar(190, 66, 17, a), polar(190, 66, 23, a)], 3), P["sun"])
