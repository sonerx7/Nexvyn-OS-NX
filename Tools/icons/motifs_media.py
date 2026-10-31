"""App icons: media and developer tools."""
import math

import numpy as np

from iconkit import (B, CX, CY, L, N, R, SS, T, U, X, Y, arc, bezier, blur, box, circle, col, darken, ellipse,
                     heart_pts, lgrad, lighten, line, polar, poly, ramp, rgrad, ring, rotate, rrect, shift, smoothstep,
                     sparkle, star, sub, vgrad)
from motifs_common import iso_cube, motif, pencil, pixels, sphere


# ---------------------------------------------------------------------------------------------------- developer
@motif
def hashtool(ic):
    P = ic.P
    rows = [(46, 52, [16, 10, 22]), (46, 200, [22, 14, 10, 16]), (160, 42, [10, 18]), (176, 210, [14, 10])]
    for (x, y, ws) in rows:
        for w in ws:
            ic.fill(rrect(x, y - 3.5, x + w, y + 3.5, 3.5), P["bits"], 0.35)
            x += w + 5
    bars = U(line([(108, 56), (96, 196)], 24), line([(164, 56), (152, 196)], 24),
             line([(54, 100), (206, 100)], 24), line([(48, 152), (200, 152)], 24))
    ic.shadow(bars, 3, 8, 8, 0.45)
    ic.fill(shift(bars, 4, 6), darken(P["hash"], 0.5))
    ic.fill(bars, lgrad([lighten(P["hash"], 0.35), P["hash"], P["hash2"]], 60, 50, 200, 200))
    ic.rim(bars, 1.8, 0.55)
    ic.gloss(bars, 0.18)
    k = rrect(168, 166, 214, 212, 14)
    ic.solid(k, P["badge"], 0.4, (1.5, 4, 4), 0.3, 0.2, 0.6, 0.15)
    ic.fill(U(circle(191, 184, 6.5), poly([(187, 186), (195, 186), (197, 202), (185, 202)])), darken(P["badge"], 0.55))


@motif
def jsonfmt(ic):
    P = ic.P

    def brace(x, sgn):
        pts = (bezier((x + 14 * sgn, 50), (x - 2 * sgn, 50), (x - 2 * sgn, 62), (x - 2 * sgn, 78)) +
               bezier((x - 2 * sgn, 78), (x - 2 * sgn, 112), (x - 4 * sgn, 122), (x - 16 * sgn, 124))[1:] +
               bezier((x - 16 * sgn, 124), (x - 4 * sgn, 126), (x - 2 * sgn, 136), (x - 2 * sgn, 170))[1:] +
               bezier((x - 2 * sgn, 170), (x - 2 * sgn, 186), (x - 2 * sgn, 198), (x + 14 * sgn, 198))[1:])
        return line(pts, 13)

    br = U(brace(70, 1), brace(186, -1))
    ic.shadow(br, 2, 6, 6, 0.45)
    ic.fill(br, lgrad(["#FFFFFF", lighten(P["brace"], 0.3)], 0, 50, 0, 198))
    ic.rim(br, 1.4, 0.4)
    rows = [(84, 96, [("k", 30), ("v", 30)]), (108, 108, [("k", 26), ("s", 34)]), (132, 108, [("k", 32), ("n", 22)]),
            (156, 96, [("k", 24), ("v", 38)])]
    for (y, x, parts) in rows:
        for (kind, w) in parts:
            m = rrect(x, y - 7, x + w, y + 7, 7)
            ic.shadow(m, 1, 3, 3, 0.35)
            c = P[kind]
            ic.fill(m, lgrad([lighten(c, 0.2), darken(c, 0.1)], 0, y - 7, 0, y + 7))
            x += w + 6
            if kind == "k":
                ic.fill(U(circle(x - 3, y - 4, 2), circle(x - 3, y + 4, 2)), "#FFFFFF", 0.8)
                x += 2


# -------------------------------------------------------------------------------------------------------- media
@motif
def drums(ic):
    P = ic.P
    cx, ty, rx, ry, hh = 128, 128, 74, 24, 58
    shell = U(rrect(cx - rx, ty, cx + rx, ty + hh, 0), ellipse(cx, ty + hh, rx, ry))
    ic.shadow(shell, 2, 8, 8, 0.45)
    ic.fill(shell, lgrad([darken(P["shell"], 0.3), lighten(P["shell"], 0.25), P["shell"], darken(P["shell"], 0.45)],
                         cx - rx, 0, cx + rx, 0))
    ic.fill(shell * smoothstep(ty + 6, ty + hh + 20, Y), "#000000", 0.2)
    # tension cords
    cords = np.zeros((N, N), np.float32)
    for k in range(-3, 4):
        x0 = cx + k * 20
        cords = U(cords, line([(x0, ty + 14), (x0 + 10, ty + hh), (x0 + 20, ty + 14)], 2.4, False))
    ic.fill(cords * shell, "#FFFFFF", 0.7)
    rimb = np.clip(ellipse(cx, ty + hh, rx + 2, ry + 3) - ellipse(cx, ty + hh - 5, rx + 2, ry + 3), 0, 1)
    ic.fill(rimb, lgrad(["#8C93A3", "#F4F6FA", "#7A8194"], cx - rx, 0, cx + rx, 0))
    rim_top = ellipse(cx, ty, rx + 3, ry + 4)
    ic.fill(rim_top, lgrad(["#9AA1B0", "#FFFFFF", "#8A90A0"], cx - rx, 0, cx + rx, 0))
    head = ellipse(cx, ty - 1, rx - 2, ry - 1)
    ic.fill(head, rgrad([lighten(P["head"], 0.5), P["head"], darken(P["head"], 0.12)], cx - 18, ty - 10, rx))
    ic.fill(ellipse(cx - 20, ty - 7, 22, 6), "#FFFFFF", 0.35)
    # sticks crossing above
    for (a, b) in (((58, 44), (164, 118)), ((200, 40), (96, 116))):
        st = line([a, b], 9)
        ic.shadow(st, 2, 5, 4, 0.4)
        ic.fill(st, lgrad([lighten(P["stick"], 0.3), P["stick"], darken(P["stick"], 0.25)], a[0], a[1] - 5, a[0], a[1] + 5))
        ic.fill(line([a, (a[0] + (b[0] - a[0]) * 0.12, a[1] + (b[1] - a[1]) * 0.12)], 9), darken(P["stick"], 0.25), 0.5)
        ic.fill(ellipse(b[0], b[1], 6, 5), lighten(P["stick"], 0.35))
    for (x, y, r) in ((48, 108, 9), (210, 100, 7)):
        ic.add(sparkle(x, y, r), "#FFFFFF", 0.85)


@motif
def lavalamp(ic):
    P = ic.P
    ic.add(blur(ellipse(128, 128, 60, 90), 26), P["glow"], 0.35)
    prof = [(60, 15), (90, 20), (120, 26), (150, 30), (170, 26)]
    left = [(128 - w, y) for (y, w) in prof]
    right = [(128 + w, y) for (y, w) in prof[::-1]]
    ys = np.linspace(60, 170, 40)
    ws = np.interp(ys, [p[0] for p in prof], [p[1] for p in prof])
    glass = poly([(128 - w, y) for y, w in zip(ys, ws)] + [(128 + w, y) for y, w in zip(ys[::-1], ws[::-1])])
    ic.shadow(glass, 0, 4, 6, 0.4)
    ic.fill(glass, vgrad(P["liquid1"], P["liquid2"], 60, 170))
    ic.add(blur(glass, 6) * glass, P["glow"], 0.25)
    blobs = U(circle(122, 150, 18), ellipse(134, 160, 22, 12), circle(140, 112, 11), ellipse(118, 84, 8, 11),
              circle(132, 70, 6), ellipse(124, 128, 6, 9))
    blobs = blobs * glass
    ic.add(blur(blobs, 5), P["wax"], 0.6)
    ic.fill(blobs, rgrad([lighten(P["wax"], 0.6), P["wax"], P["wax2"]], 122, 110, 70))
    ic.fill(glass * ((X > 128 - 12) & (X < 128 - 6)).astype(np.float32) * smoothstep(60, 100, Y), "#FFFFFF", 0.3)
    ic.rim(glass, 1.2, 0.4)
    cap = poly([(112, 62), (144, 62), (136, 36), (120, 36)])
    base = poly([(80, 214), (176, 214), (156, 168), (100, 168)])
    for m in (cap, base):
        ic.shadow(m, 1.5, 4, 4, 0.35)
        ic.fill(m, lgrad([darken(P["metal"], 0.35), lighten(P["metal"], 0.45), P["metal"], darken(P["metal"], 0.4)],
                         70, 0, 186, 0))
        ic.rim(m, 1.2, 0.5)
    ic.fill(rrect(96, 166, 160, 172, 3), darken(P["metal"], 0.3))


@motif
def mandelbrot(ic):
    P = ic.P
    ss = 2
    n = 256 * ss
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float64)
    scale = 3.05 / (206 * ss)
    re = -0.62 + (xs - 128 * ss) * scale
    im = (ys - 124 * ss) * scale
    c = re + 1j * im
    z = np.zeros_like(c)
    it = np.zeros(c.shape, np.float64)
    alive = np.ones(c.shape, bool)
    for i in range(96):
        z[alive] = z[alive] ** 2 + c[alive]
        esc = alive & (np.abs(z) > 4)
        it[esc] = i + 1 - np.log(np.log(np.abs(z[esc]))) / math.log(2)
        alive &= ~esc
    t = np.clip((it / 30.0) ** 0.6, 0, 1).astype(np.float32)
    img = ramp(t, [(0, P["c0"]), (0.25, P["c1"]), (0.55, P["c2"]), (0.8, P["c3"]), (1.0, "#FFFFFF")])
    img[alive] = col(P["inside"])
    from PIL import Image
    big = np.zeros((N, N, 3), np.float32)
    for k in range(3):
        big[..., k] = np.asarray(Image.fromarray(img[..., k]).resize((N, N), Image.BILINEAR))
    ic.px[:] = big
    inside = np.asarray(Image.fromarray(alive.astype(np.float32)).resize((N, N), Image.BILINEAR))
    ic.add(blur(inside.astype(np.float32), 6) * (1 - inside), P["c2"], 0.3)
    # a magnifying lens on the edge of the set
    lx, ly, lr = 168, 92, 32
    lens = circle(lx, ly, lr)
    handle = line([polar(lx, ly, lr + 4, 45), polar(lx, ly, lr + 44, 45)], 13)
    ic.shadow(U(ring(lx, ly, lr, 9), handle), 2, 6, 6, 0.5, "#000000")
    ic.fill(lens, "#FFFFFF", 0.12)
    ic.fill(ellipse(lx - 10, ly - 14, 12, 7, -30) * lens, "#FFFFFF", 0.35)
    ic.fill(handle, lgrad([lighten(P["handle"], 0.3), darken(P["handle"], 0.3)], lx + 30, ly + 30, lx + 60, ly + 60))
    ic.fill(ring(lx, ly, lr, 9), lgrad(["#FFFFFF", "#B9C2D3", "#7C869A"], lx - lr, ly - lr, lx + lr, ly + lr))
    ic.fill(ring(lx, ly, lr - 3, 1.2), "#FFFFFF", 0.6)


@motif
def metronome(ic):
    P = ic.P
    plinth = rrect(58, 196, 198, 214, 7)
    bodym = poly([(70, 200), (186, 200), (146, 46), (110, 46)])
    ic.shadow(U(plinth, bodym), 2, 7, 7, 0.4)
    ic.fill(plinth, lgrad([lighten(P["wood"], 0.1), darken(P["wood"], 0.4)], 0, 196, 0, 214))
    ic.fill(bodym, lgrad([lighten(P["wood"], 0.3), P["wood"], darken(P["wood"], 0.35)], 70, 0, 186, 0))
    ic.fill(rrect(108, 40, 148, 52, 6), darken(P["wood"], 0.2))
    face = poly([(94, 188), (162, 188), (138, 66), (118, 66)])
    ic.fill(face, vgrad(lighten(P["face"], 0.1), darken(P["face"], 0.08), 66, 188))
    ic.inner(face, 2, 0, 2, 0.3)
    ticks = np.zeros((N, N), np.float32)
    for k in range(9):
        y = 76 + k * 11
        ticks = U(ticks, line([(128 - 5, y), (128 + 5, y)], 1.6, False))
    ic.fill(ticks, darken(P["face"], 0.5), 0.6)
    # swinging pendulum
    piv = (128, 176)
    ang = 22
    tip = rotate([(128, 54)], ang, *piv)[0]
    arm = line([piv, tip], 5)
    for k, a in enumerate((-30, -18)):
        ghost = line([piv, rotate([(128, 60)], a, *piv)[0]], 4)
        ic.fill(ghost, "#FFFFFF", 0.18 + k * 0.1)
    ic.shadow(arm, 1.5, 3, 3, 0.35)
    ic.fill(arm, lgrad(["#F4F6FA", "#9AA2B4"], 0, 50, 0, 180))
    wpos = rotate([(128, 96)], ang, *piv)[0]
    weight = box(wpos[0], wpos[1], 26, 18, 4, ang)
    ic.shadow(weight, 1, 3, 3, 0.4)
    ic.fill(weight, lgrad([lighten(P["weight"], 0.3), darken(P["weight"], 0.25)], wpos[0], wpos[1] - 9, wpos[0], wpos[1] + 9))
    ic.rim(weight, 1.2, 0.5)
    ic.fill(circle(*piv, 6), lgrad(["#FFFFFF", "#9AA2B4"], 0, 170, 0, 182))
    for (a0, a1) in ((-130, -112), (-68, -50)):
        ic.fill(arc(128, 176, 136, a0, a1, 3), P["motion"], 0.6)


@motif
def noise(ic):
    P = ic.P
    cm = U(circle(102, 76, 24), circle(132, 64, 30), circle(160, 80, 22), rrect(80, 76, 182, 102, 13))
    ic.shadow(cm, 2, 6, 7, 0.35)
    ic.fill(cm, vgrad("#FFFFFF", lighten(P["cloud"], 0.2), 36, 102))
    ic.rim(cm, 1.4, 0.6)
    for (x, y) in ((100, 114), (124, 120), (148, 112), (172, 118), (112, 140), (160, 138)):
        ic.fill(line([(x, y), (x - 5, y + 13)], 3.2), P["rain"], 0.85)
    for i, (y0, amp, ph, c) in enumerate(((160, 6, 0.0, P["w1"]), (178, 7, 1.7, P["w2"]), (196, 6, 3.1, P["w3"]))):
        xs = np.linspace(L - 5, R + 5, 80)
        pts = [(x, y0 + amp * math.sin(x / 17.0 + ph)) for x in xs] + [(R + 5, B + 5), (L - 5, B + 5)]
        m = poly(pts)
        ic.shadow(m, 0, -3, 4, 0.25)
        ic.fill(m, vgrad(lighten(c, 0.15), darken(c, 0.2), y0 - amp, B))
        ic.fill(np.clip(m - shift(m, 0, 2), 0, 1), "#FFFFFF", 0.45)


@motif
def piano(ic):
    P = ic.P
    ang = -16
    cx, cy = 120, 150
    kw, kh = 25, 112
    n = 7
    x0 = cx - n * kw / 2
    allk = rrect(x0 - 6, cy - kh / 2 - 14, x0 + n * kw + 6, cy + kh / 2 + 8, 10, ang, (cx, cy))
    ic.shadow(allk, 3, 9, 9, 0.5)
    ic.fill(allk, lgrad(["#3A3D4A", "#0E0F14"], 0, cy - 80, 0, cy + 80))
    ic.rim(allk, 1.4, 0.3)
    for i in range(n):
        k = rrect(x0 + i * kw + 1.2, cy - kh / 2, x0 + (i + 1) * kw - 1.2, cy + kh / 2, 5, ang, (cx, cy))
        front = rrect(x0 + i * kw + 1.2, cy + kh / 2 - 8, x0 + (i + 1) * kw - 1.2, cy + kh / 2, 4, ang, (cx, cy))
        pressed = i == 3
        ic.fill(k, lighten(P["keys"], 0.0) if not pressed else P["press"])
        ic.fill(k * smoothstep(cy - 60, cy + 70, Y), "#000000", 0.08)
        ic.fill(front, darken(P["keys"] if not pressed else P["press"], 0.25))
    for i in (0, 1, 3, 4, 5):
        bx = x0 + (i + 1) * kw
        bk = rrect(bx - 8, cy - kh / 2, bx + 8, cy + 8, 3, ang, (cx, cy))
        ic.shadow(bk, 1.5, 3, 3, 0.4)
        ic.fill(bk, lgrad(["#4A4D5C", "#121318"], bx - 8, 0, bx + 8, 0))
        ic.fill(rrect(bx - 5, cy - kh / 2 + 2, bx - 2, cy + 2, 1.5, ang, (cx, cy)), "#FFFFFF", 0.25)
    ic.add(blur(rrect(x0 + 3 * kw, cy - kh / 2, x0 + 4 * kw, cy + kh / 2, 4, ang, (cx, cy)), 8), P["press"], 0.5)
    # a note rising from the pressed key
    nx, ny = 182, 52
    head = ellipse(nx, ny + 30, 13, 10, -25)
    stem = rrect(nx + 8, ny - 14, nx + 13, ny + 28, 2)
    flag = line(bezier((nx + 11, ny - 12), (nx + 30, ny - 4), (nx + 34, ny + 10), (nx + 24, ny + 20)), 5)
    nm = U(head, stem, flag)
    ic.add(blur(nm, 6), P["note"], 0.5)
    ic.solid(nm, P["note"], 0.35, (1.5, 4, 4), 0.35, 0.2, 0.5, 0.1)


HEART = ["..XX...XX..",
         ".XhXX.XXXX.",
         "XhhXXXXXXXX",
         "XhXXXXXXXXX",
         "XXXXXXXXXXd",
         ".XXXXXXXXd.",
         "..XXXXXXd..",
         "...XXXXd...",
         "....XXd....",
         ".....X....."]


@motif
def pixelart(ic):
    P = ic.P
    pixels(ic, HEART, 48, 52, 13, {"X": P["heart"], "h": lighten(P["heart"], 0.5), "d": darken(P["heart"], 0.3)},
           gap=1.2, shadow=0.4)
    pencil(ic, 222, 226, 150, 154, 18, P["pencil"])
    ic.fill(rrect(130, 158, 143, 171, 2), P["heart"])


@motif
def sequencer(ic):
    P = ic.P
    panel = rrect(38, 44, 218, 206, 20)
    ic.shadow(panel, 2, 8, 8, 0.45)
    ic.fill(panel, vgrad(lighten(P["panel"], 0.12), darken(P["panel"], 0.2), 44, 206))
    ic.rim(panel, 1.6, 0.35)
    inner = rrect(46, 52, 210, 198, 13)
    ic.fill(inner, darken(P["panel"], 0.35))
    kx0, kx1 = 50, 72
    for k in range(9):
        y = 56 + k * 15.5
        black = k in (1, 3, 6)
        ic.fill(rrect(kx0, y + 1, kx1 if not black else kx1 - 8, y + 14, 3), "#1C1F2B" if black else "#F4F6FA")
    lines = np.zeros((N, N), np.float32)
    for k in range(10):
        y = 56 + k * 15.5
        lines = U(lines, line([(kx1 + 4, y), (206, y)], 1.0, False))
    for k in range(6):
        x = 80 + k * 22
        lines = U(lines, line([(x, 54), (x, 196)], 1.0, False))
    ic.fill(lines * inner, "#FFFFFF", 0.1)
    notes = [(0, 80, 34, "n1"), (2, 118, 26, "n2"), (4, 80, 22, "n3"), (4, 146, 44, "n1"), (6, 104, 38, "n4"),
             (7, 150, 26, "n2"), (1, 150, 30, "n3"), (8, 80, 20, "n4"), (5, 178, 24, "n3")]
    for (row, x, w, k) in notes:
        y = 56 + row * 15.5
        m = rrect(x, y + 2, x + w, y + 13.5, 4)
        ic.add(blur(m, 4), P[k], 0.45)
        ic.solid(m, P[k], 0.0, rim=0.6, edge=0.2, light=0.3)
    ph = rrect(140, 52, 143, 198, 1.5)
    ic.add(blur(ph, 4), P["head"], 0.8)
    ic.fill(ph, "#FFFFFF")
    ic.fill(poly([(133, 48), (150, 48), (141.5, 58)]), "#FFFFFF")


@motif
def spirograph(ic):
    P = ic.P
    gx, gy, gr = 196, 196, 36
    teeth = []
    for i in range(48):
        a = 2 * math.pi * i / 48
        rr = gr + (4 if i % 2 == 0 else 0)
        teeth.append((gx + rr * math.cos(a), gy + rr * math.sin(a)))
    gear = sub(poly(teeth), circle(gx, gy, 10))
    ic.fill(gear, P["gear"], 0.55)
    ic.fill(circle(gx - 16, gy - 14, 3), "#FFFFFF", 0.8)

    def curve(Rr, r, d, s, rot, color, w):
        pts = []
        k = Rr - r
        for t in np.linspace(0, 2 * math.pi * r, 1600):
            x = k * math.cos(t) + d * math.cos(k / r * t)
            y = k * math.sin(t) - d * math.sin(k / r * t)
            pts.append((x, y))
        pts = rotate([(128 + x * s, 122 + y * s) for x, y in pts], rot, 128, 122)
        m = line(pts, w, False)
        ic.add(blur(m, 2), color, 0.25)
        ic.fill(m, color, 0.95)

    curve(9, 4, 6, 7.0, 0, P["c1"], 2.0)
    curve(8, 3, 5, 8.0, 18, P["c2"], 1.6)
    curve(7, 2, 3.2, 10.0, 9, P["c3"], 1.4)


@motif
def tonegen(ic):
    P = ic.P
    dev = rrect(40, 48, 216, 204, 22)
    ic.shadow(dev, 2, 8, 8, 0.45)
    ic.fill(dev, lgrad([lighten(P["case"], 0.2), P["case"], darken(P["case"], 0.3)], 0, 48, 0, 204))
    ic.rim(dev, 1.8, 0.5)
    scr = rrect(54, 62, 202, 158, 12)
    ic.fill(scr, "#0A0F0D")
    inner = rrect(57, 65, 199, 155, 10)
    ic.fill(inner, rgrad([lighten(P["screen"], 0.12), P["screen"]], 128, 110, 90))
    grid = np.zeros((N, N), np.float32)
    for x in range(57, 200, 18):
        grid = U(grid, line([(x, 65), (x, 155)], 1.0, False))
    for y in range(65, 156, 15):
        grid = U(grid, line([(57, y), (199, y)], 1.0, False))
    ic.fill(grid * inner, P["trace"], 0.16)
    pts = [(x, 110 - 28 * math.sin((x - 57) / 142 * 2 * math.pi * 1.5)) for x in np.linspace(60, 196, 120)]
    wave = line(pts, 3.2, False)
    ic.add(blur(wave, 4) * inner, P["trace"], 0.9)
    ic.fill(wave, lighten(P["trace"], 0.6))
    ic.fill(inner * smoothstep(100, 65, Y), "#FFFFFF", 0.06)
    for (x, c) in ((86, P["knob"]), (128, P["knob2"])):
        k = circle(x, 182, 13)
        ic.shadow(k, 1, 3, 3, 0.4)
        ic.fill(k, rgrad([lighten(c, 0.4), c, darken(c, 0.3)], x - 4, 178, 16))
        ic.fill(line([(x, 182), polar(x, 182, 9, -60)], 3), "#FFFFFF", 0.9)
    for i in range(3):
        ic.fill(rrect(158 + i * 14, 176, 168 + i * 14, 188, 3), darken(P["case"], 0.45))
    ic.fill(rrect(158, 176, 168, 188, 3), P["trace"], 0.9)


@motif
def viewer3d(ic):
    P = ic.P
    orbit_back = arc(128, 136, 92, 180, 360, 4, False, ry=30)
    ic.fill(orbit_back, P["orbit"], 0.45)
    s = 58
    iso_cube(ic, 128, 98, s, P["top"], P["left"], P["right"], s, shadow=0.45, edge=False)
    dx, dy = s * 0.866, s * 0.5
    pts = {"t": (128, 98 - dy), "r": (128 + dx, 98), "b": (128, 98 + dy), "l": (128 - dx, 98),
           "lb": (128 - dx, 98 + s), "bb": (128, 98 + dy + s), "rb": (128 + dx, 98 + s)}
    edges = [("t", "r"), ("r", "b"), ("b", "l"), ("l", "t"), ("l", "lb"), ("b", "bb"), ("r", "rb"), ("lb", "bb"),
             ("bb", "rb")]
    em = U(*[line([pts[a], pts[b]], 2.2) for a, b in edges])
    ic.add(blur(em, 2), P["edge"], 0.5)
    ic.fill(em, lighten(P["edge"], 0.5), 0.9)
    for p in pts.values():
        ic.fill(circle(p[0], p[1], 4.2), "#FFFFFF")
    orbit = arc(128, 136, 92, 10, 170, 4.5, False, ry=30)
    ic.add(blur(orbit, 2), P["orbit"], 0.6)
    ic.fill(orbit, lighten(P["orbit"], 0.4))
    tx, ty = 128 + 92 * math.cos(math.radians(10)), 136 + 30 * math.sin(math.radians(10))
    ic.fill(poly([(tx - 10, ty - 4), (tx + 8, ty - 12), (tx + 4, ty + 8)]), lighten(P["orbit"], 0.4))


@motif
def xylophone(ic):
    P = ic.P
    rails = U(line([(46, 92), (206, 116)], 7), line([(46, 176), (206, 160)], 7))
    ic.shadow(rails, 1, 4, 4, 0.35)
    ic.fill(rails, P["rail"])
    cols = [P["b1"], P["b2"], P["b3"], P["b4"], P["b5"], P["b6"]]
    for i, c in enumerate(cols):
        x = 52 + i * 26
        top = 66 + i * 7
        bot = 206 - i * 7
        m = rrect(x, top, x + 21, bot, 6)
        ic.shadow(m, 1.5, 5, 5, 0.35)
        ic.fill(m, lgrad([lighten(c, 0.3), c, darken(c, 0.2)], x, 0, x + 21, 0))
        ic.rim(m, 1.4, 0.55, dark=0.15)
        for y in (92 + i * 4.8, 176 - i * 3.2):
            ic.fill(circle(x + 10.5, y, 3), "#FFFFFF", 0.8)
            ic.fill(circle(x + 10.5, y + 0.6, 1.6), darken(c, 0.4), 0.7)
    stick = line([(214, 214), (150, 92)], 7)
    ic.shadow(stick, 2, 5, 4, 0.4)
    ic.fill(stick, lgrad([lighten(P["stick"], 0.3), darken(P["stick"], 0.2)], 140, 90, 220, 214))
    sphere(ic, 146, 84, 15, P["mallet"], 0.35, 0.85)
    for (x, y, r) in ((112, 48, 10), (176, 62, 7)):
        ic.add(sparkle(x, y, r), "#FFFFFF", 0.85)
