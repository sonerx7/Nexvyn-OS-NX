"""Game icons: playful, illustrated scenes."""
import math

import numpy as np

from iconkit import (B, CX, CY, L, N, R, SS, T, U, X, Y, arc, arc_pts, bbox, bezier, blur, box, circle, col, darken,
                     ellipse, ellipse_pts, heart, lgrad, lighten, line, mix, polar, poly, rgrad, ring, rotate, rrect,
                     rrect_pts, shift, smoothstep, sparkle, star, star_pts, sub, text, vgrad)
from motifs_common import (check, clock_face, cloud, coin, iso_box, iso_cube, motif, paper, pencil, pixels, soft_shadow_ellipse,
                           sphere)


def _tube(ic, pts, w, base, belly=None, spots=None, shadow=0.35):
    """A round tube along a path (snake bodies, hoses): dark outline, lit middle, thin highlight."""
    m = line(pts, w)
    if shadow:
        ic.shadow(m, 1.5, 4.5, 4.5, shadow)
    ic.fill(m, darken(base, 0.3))
    inner = line([(x - w * 0.06, y - w * 0.1) for x, y in pts], w * 0.74)
    ic.fill(inner * m, base)
    ic.fill(line([(x - w * 0.12, y - w * 0.22) for x, y in pts], w * 0.22) * m, lighten(base, 0.45), 0.7)
    return m


def _path_dir(pts, i):
    j = min(len(pts) - 1, i + 1)
    k = max(0, i - 1)
    return math.atan2(pts[j][1] - pts[k][1], pts[j][0] - pts[k][0])


# ------------------------------------------------------------------------------------------------------- arcade
@motif
def snake(ic):
    P = ic.P
    ax, ay, ar = 150, 142, 36
    # the coil: a spiral around the apple, the first half behind it
    pts = []
    for i in range(160):
        t = i / 159
        a = math.radians(150 + t * 330)
        r = 76 - 14 * t
        pts.append((ax - 6 + r * math.cos(a), ay + 4 + r * 0.78 * math.sin(a)))
    behind, front = pts[:70], pts[66:]
    w = 25
    _tube(ic, behind, w, P["body"])
    # apple
    am = U(circle(ax - 14, ay, ar * 0.86), circle(ax + 14, ay, ar * 0.86), circle(ax, ay + 6, ar * 0.9))
    am = sub(am, circle(ax, ay - ar * 1.02, ar * 0.32))
    ic.shadow(am, 2, 5, 5, 0.4)
    ic.fill(am, rgrad([(0, lighten(P["apple"], 0.35)), (0.5, P["apple"]), (1, darken(P["apple"], 0.45))],
                      ax - 16, ay - 14, ar * 1.6))
    ic.fill(am * blur(ellipse(ax - 18, ay - 12, 7, 12, 25), 1.5), "#FFFFFF", 0.65)
    ic.fill(line([(ax, ay - ar * 0.68), (ax + 3, ay - ar * 1.18)], 5), P["stem"])
    leaf = poly(rotate(ellipse_pts(ax + 16, ay - ar * 1.05, 15, 7), -28, ax + 16, ay - ar * 1.05))
    ic.fill(leaf, lgrad([lighten(P["leaf"], 0.2), darken(P["leaf"], 0.2)], ax + 4, ay - 50, ax + 30, ay - 30))
    ic.fill(line([(ax + 5, ay - ar * 0.98), (ax + 27, ay - ar * 1.12)], 1.2) * leaf, darken(P["leaf"], 0.35), 0.6)
    # the front of the coil, with spots
    fm = _tube(ic, front, w, P["body"])
    sp = np.zeros((N, N), np.float32)
    for i in range(4, len(front) - 18, 11):
        x, y = front[i]
        sp = U(sp, ellipse(x - 1, y - 2, 4.5, 3.2, math.degrees(_path_dir(front, i))))
    ic.fill(sp * fm, P["spots"], 0.9)
    # head at the end of the coil, looking at the apple
    hx, hy = front[-1]
    d = math.degrees(_path_dir(front, len(front) - 1))
    hx, hy = hx + 6 * math.cos(math.radians(d)), hy + 6 * math.sin(math.radians(d))
    head = ellipse(hx, hy, 26, 20, d)
    ic.shadow(head, 1.5, 4, 4, 0.35)
    ic.fill(head, rgrad([lighten(P["body"], 0.3), P["body"], darken(P["body"], 0.3)], hx - 6, hy - 8, 26))
    tx, ty = polar(hx, hy, 25, d)
    tongue = line([(tx, ty), polar(tx, ty, 10, d), polar(*polar(tx, ty, 10, d), 6, d - 35)], 2.6)
    tongue = U(tongue, line([polar(tx, ty, 10, d), polar(*polar(tx, ty, 10, d), 6, d + 35)], 2.6))
    ic.fill(tongue, P["tongue"])
    for side in (-1, 1):
        ex, ey = polar(*polar(hx, hy, 7, d), 10, d + 90 * side)
        ic.fill(circle(ex, ey, 6.5), "#FFFFFF")
        ic.fill(circle(ex + 1.6 * math.cos(math.radians(d)), ey + 1.6 * math.sin(math.radians(d)), 3.8), "#14161C")
        ic.fill(circle(ex - 1.2, ey - 2, 1.5), "#FFFFFF")


@motif
def pinball(ic):
    P = ic.P
    # pop bumper (top left)
    bx, by = 82, 82
    ic.glow(circle(bx, by, 24), 10, P["bumper"], 0.5)
    base = circle(bx, by + 5, 24)
    ic.shadow(base, 1, 4, 4, 0.4)
    ic.fill(base, darken(P["bumper"], 0.35))
    cap = circle(bx, by, 24)
    ic.fill(cap, rgrad([lighten(P["bumper"], 0.5), P["bumper"], darken(P["bumper"], 0.2)], bx - 6, by - 8, 28))
    ic.fill(ring(bx, by, 15, 3.5), "#FFFFFF", 0.85)
    ic.fill(circle(bx, by, 7), lighten(P["bumper"], 0.6))
    # second, smaller bumper
    b2x, b2y = 168, 70
    ic.glow(circle(b2x, b2y, 15), 7, P["bumper2"], 0.45)
    ic.fill(circle(b2x, b2y + 4, 15), darken(P["bumper2"], 0.35))
    ic.fill(circle(b2x, b2y, 15), rgrad([lighten(P["bumper2"], 0.5), P["bumper2"]], b2x - 4, b2y - 5, 18))
    ic.fill(ring(b2x, b2y, 9, 2.5), "#FFFFFF", 0.85)
    # flipper (bottom right, swung up)
    px_, py_ = 198, 186
    ang = 200
    tipx, tipy = polar(px_, py_, 92, ang)
    fl = poly(rotate([(px_, py_ - 15)] + [polar(px_, py_, 15, a) for a in range(-90, 91, 10)] +
                     [(px_ - 92, py_ + 7)] + [polar(px_ - 92, py_, 7, a) for a in range(90, 271, 15)],
                     ang - 180, px_, py_))
    ic.glow(fl, 6, P["flipper"], 0.35)
    ic.solid(fl, P["flipper"], 0.45, (2, 5, 5), 0.3, 0.25, 0.6, 0.2, gloss=0.2)
    ic.fill(circle(px_, py_, 6), "#FFFFFF", 0.9)
    ic.fill(circle(px_, py_, 3), darken(P["flipper"], 0.4))
    # the ball, with a trail
    cx, cy = 116, 140
    trail = line([(cx + 52, cy - 62), (cx + 6, cy - 6)], 22)
    tfade = smoothstep(cx + 50, cx, X)
    ic.add(blur(trail, 4) * tfade, P["trail"], 0.5)
    ic.glow(circle(cx, cy, 20), 8, P["trail"], 0.55)
    sphere(ic, cx, cy, 20, P["ball"], 0.45, 0.95)
    ic.fill(ellipse(cx + 5, cy + 9, 9, 4, -20) * circle(cx, cy, 20), "#FFFFFF", 0.25)
    for (x, y, r) in ((178, 122, 7), (64, 150, 5), (150, 196, 4)):
        ic.add(sparkle(x, y, r), "#FFFFFF", 0.85)


@motif
def blocks(ic):
    P = ic.P
    s = 25
    dx, dy, h = s * 0.866, s * 0.5, s
    ox, oy = 128, 132

    def at(i, j, k):
        return ox + (i - j) * dx, oy + (i + j - 3) * dy - k * h

    cells = {(0, 0, 0): "a", (1, 0, 0): "a", (2, 0, 0): "a", (0, 1, 0): "a",
             (0, 2, 0): "b", (1, 2, 0): "b", (1, 1, 0): "b", (2, 1, 0): "b",
             (3, 0, 0): "c", (3, 1, 0): "c", (3, 2, 0): "c", (2, 2, 0): "c",
             (0, 3, 0): "d", (1, 3, 0): "d", (2, 3, 0): "d", (0, 0, 1): "d"}
    fall = {(1, 1, 2.7): "e", (2, 1, 2.7): "e", (3, 1, 2.7): "e", (2, 2, 2.7): "e"}
    allc = dict(cells)
    allc.update(fall)
    order = sorted(allc, key=lambda c: (c[0] + c[1] + c[2], c[2]))
    for c in order:
        if c in fall and c == min(fall, key=lambda q: q[0] + q[1]):
            # the falling piece's shadow on the stack, and motion lines above it
            sh = U(*[poly([(at(i, j, 1)[0], at(i, j, 1)[1] - dy), (at(i, j, 1)[0] + dx, at(i, j, 1)[1]),
                           (at(i, j, 1)[0], at(i, j, 1)[1] + dy), (at(i, j, 1)[0] - dx, at(i, j, 1)[1])])
                     for (i, j, k) in fall])
            ic.fill(blur(sh, 3), "#000000", 0.28)
        key = allc[c]
        x, y = at(*c)
        base = P[key]
        iso_cube(ic, x, y, s, lighten(base, 0.22), base, darken(base, 0.25), h,
                 shadow=0.0, gap=0.9)
    for (i, j, k) in ((1, 1, 2.7), (3, 1, 2.7)):
        x, y = at(i, j, k)
        ic.fill(line([(x, y - 22), (x, y - 40)], 3.5), "#FFFFFF", 0.5)
    x, y = at(2, 1, 2.7)
    ic.fill(line([(x, y - 26), (x, y - 50)], 3.5), "#FFFFFF", 0.5)


@motif
def breakout(ic):
    P = ic.P
    cols = [P["r1"], P["r2"], P["r3"], P["r4"]]
    bw, bh, g = 34, 15, 4
    x0 = 128 - (4 * bw + 3 * g) / 2
    for r in range(4):
        for c in range(4):
            if (r, c) in ((3, 1), (2, 2), (3, 2)):
                continue
            x = x0 + c * (bw + g) + (bw / 2 + g / 2 if r % 2 else 0) - (bw / 4 if r % 2 else 0)
            y = 44 + r * (bh + g)
            m = rrect(x, y, x + bw, y + bh, 4)
            ic.solid(m, cols[r], 0.3, (1, 3, 3), 0.28, 0.22, 0.55, 0.2)
    # fragments of the brick just hit
    for (x, y, a, s) in ((112, 108, 20, 6), (124, 114, -30, 5), (101, 116, 50, 4), (136, 104, 10, 4)):
        ic.solid(box(x, y, s * 1.6, s, 1, a), cols[2], 0.25, (1, 2, 2), 0.2, 0.2, 0.4, 0)
    # trajectory
    pts = [(160, 186), (128, 140), (116, 122)]
    for i in range(1, 7):
        t = i / 7
        x = 160 + (116 - 160) * t
        y = 186 + (122 - 186) * t
        ic.fill(circle(x, y, 2.2), "#FFFFFF", 0.25 + 0.4 * (1 - t))
    # ball
    ic.glow(circle(122, 130, 10), 7, P["ball"], 0.7)
    sphere(ic, 122, 130, 10, P["ball"], 0.3, 0.9)
    # paddle
    pm = rrect(132, 190, 202, 204, 7)
    ic.glow(pm, 6, P["paddle"], 0.4)
    ic.solid(pm, P["paddle"], 0.4, (1.5, 4, 4), 0.35, 0.25, 0.7, 0.2, gloss=0.25)


@motif
def racer(ic):
    P = ic.P
    # road: a band sweeping up to the right
    road = poly([(L - 5, 214), (R + 5, 150), (R + 5, 196), (L - 5, B + 10)])
    ic.fill(road, lgrad([P["road"], darken(P["road"], 0.3)], 60, 150, 200, 230))
    for i in range(5):
        t0, t1 = i / 5 + 0.03, i / 5 + 0.12
        xa, xb = L + (R - L) * t0, L + (R - L) * t1
        ya, yb = 228 - 56 * t0, 228 - 56 * t1
        ic.fill(line([(xa, ya), (xb, yb)], 4, False), "#FFFFFF", 0.7)
    # speed lines
    for (y, x0, x1, w) in ((92, 36, 92, 5), (112, 30, 76, 4), (132, 40, 86, 5), (152, 34, 70, 3.5)):
        ic.fill(line([(x0, y), (x1, y)], w), P["speed"], 0.75)
    # car body (side view, tilted up a little)
    a = -9
    cx, cy = 140, 140
    bodyp = [(70, 150), (72, 136), (92, 128), (122, 124), (142, 106), (166, 102), (184, 106), (204, 124),
             (214, 130), (218, 146), (212, 152)]
    bodyp = bezier((70, 152), (66, 128), (100, 128), (122, 124))[:-1] + \
        bezier((122, 124), (138, 104), (170, 96), (192, 112))[:-1] + \
        bezier((192, 112), (206, 122), (222, 126), (218, 150))
    body = poly(rotate(bodyp + [(70, 152)], a, cx, cy))
    ic.shadow(body, 2, 10, 6, 0.45)
    ic.fill(body, lgrad([lighten(P["car"], 0.35), P["car"], darken(P["car"], 0.35)], 0, 100, 0, 156))
    # window
    win = poly(rotate(bezier((128, 124), (142, 108), (166, 104), (184, 116)) + [(170, 124)], a, cx, cy))
    ic.fill(win, lgrad([lighten(P["glass"], 0.3), darken(P["glass"], 0.3)], 0, 104, 0, 126))
    ic.fill(poly(rotate([(150, 108), (158, 106), (144, 123), (136, 123)], a, cx, cy)), "#FFFFFF", 0.35)
    # stripe and highlight
    ic.fill(line(rotate([(74, 138), (214, 138)], a, cx, cy), 4) * body, "#FFFFFF", 0.85)
    ic.fill(body * (1 - shift(body, 0, 3)), "#FFFFFF", 0.5)
    # spoiler
    sp = poly(rotate([(66, 124), (84, 124), (86, 130), (70, 134)], a, cx, cy))
    ic.fill(sp, darken(P["car"], 0.3))
    # wheels
    for wx in (94, 192):
        x, y = rotate([(wx, 152)], a, cx, cy)[0]
        ic.fill(circle(x, y, 17), "#16171C")
        ic.fill(circle(x, y, 9.5), lgrad(["#F2F4F8", "#9AA3B5"], x - 8, y - 8, x + 8, y + 8))
        ic.fill(circle(x, y, 3.5), "#3A3F4C")
        ic.fill(arc(x, y, 14.5, 200, 260, 2, False), "#FFFFFF", 0.35)
    # head light
    hx, hy = rotate([(214, 136)], a, cx, cy)[0]
    ic.add(blur(circle(hx, hy, 6), 3), P["light"], 0.8)
