"""App icons: learning and fun (Other) and System."""
import math

import numpy as np

from iconkit import (L, N, R, T, X, U, agrad, arc, blur, circle, darken, ellipse, lgrad, lighten, line, mix, polar,
                     poly, rgrad, rotate, rrect, shift, smoothstep, star, vgrad)
from motifs_common import iso_cube, motif


@motif
def capitals(ic):
    P = ic.P
    panels = [((44, 96), (100, 84), (100, 204), (44, 216)), ((100, 84), (156, 96), (156, 216), (100, 204)),
              ((156, 96), (212, 84), (212, 204), (156, 216))]
    allm = U(*[poly(p) for p in panels])
    ic.shadow(allm, 2, 7, 7, 0.4)
    for i, p in enumerate(panels):
        m = poly(p)
        base = P["map"] if i != 1 else darken(P["map"], 0.08)
        ic.fill(m, vgrad(lighten(base, 0.1), darken(base, 0.06), 84, 216))
        land = U(ellipse(p[0][0] + 22, 140, 18, 26, 20), ellipse(p[0][0] + 36, 180, 14, 12))
        ic.fill(land * m, P["land"] if i != 1 else darken(P["land"], 0.08))
    route = [(64, 190), (90, 160), (124, 172), (150, 134), (176, 150)]
    for i in range(len(route) - 1):
        a, b = route[i], route[i + 1]
        for k in range(4):
            t = k / 4
            ic.fill(circle(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, 2.0), P["route"], 0.9)
    px_, py_ = 176, 140
    pin = U(circle(px_, py_ - 52, 30), poly([(px_ - 26, py_ - 40), (px_ + 26, py_ - 40), (px_, py_)]))
    ic.fill(blur(ellipse(px_, py_ + 2, 12, 4), 2), "#000000", 0.35)
    ic.shadow(pin, 2, 6, 6, 0.4)
    ic.fill(pin, rgrad([lighten(P["pin"], 0.35), P["pin"], darken(P["pin"], 0.3)], px_ - 10, py_ - 64, 44))
    ic.fill(circle(px_, py_ - 52, 18), "#FFFFFF")
    ic.fill(star(px_, py_ - 52, 13, 5.5), P["star"])
    ic.rim(pin, 1.4, 0.45)


@motif
def life(ic):
    P = ic.P
    s = 22
    x0, y0 = 128 - 4.5 * s, 124 - 4.5 * s

    def cell(c, r):
        return rrect(x0 + c * s + 2, y0 + r * s + 2, x0 + (c + 1) * s - 2, y0 + (r + 1) * s - 2, 4)

    grid = np.zeros((N, N), np.float32)
    for k in range(10):
        grid = U(grid, line([(x0 + k * s, y0), (x0 + k * s, y0 + 9 * s)], 1.0, False),
                 line([(x0, y0 + k * s), (x0 + 9 * s, y0 + k * s)], 1.0, False))
    ic.fill(grid, P["grid"], 0.4)
    for (c, r, op) in ((2, 2, 0.12), (3, 3, 0.18), (1, 3, 0.18), (2, 3, 0.25), (3, 4, 0.3), (2, 4, 0.3)):
        ic.fill(cell(c, r), P["cell"], op)
    allm = U(*[cell(c, r) for c, r in ((4, 3), (5, 4), (3, 5), (4, 5), (5, 5))])
    ic.add(blur(allm, 7), P["cell"], 0.8)
    ic.fill(allm, lgrad([lighten(P["cell"], 0.45), P["cell"]], 0, y0 + 3 * s, 0, y0 + 6 * s))
    ic.rim(allm, 1.2, 0.5)
    for (c, r) in ((7, 1), (1, 7), (7, 7)):
        ic.fill(cell(c, r), P["cell2"], 0.85)


@motif
def mathrace(ic):
    P = ic.P
    pole = rrect(52, 40, 60, 214, 4)
    ic.shadow(pole, 1.5, 4, 4, 0.35)
    ic.fill(pole, lgrad(["#F4F6FA", "#8D95A8"], 52, 0, 60, 0))
    ic.fill(circle(56, 40, 7), P["ball"])

    def fy(x, y):
        return y + 8 * math.sin((x - 60) / 26.0)

    s = 17
    flag = np.zeros((N, N), np.float32)
    dark = np.zeros((N, N), np.float32)
    for r in range(5):
        for c in range(8):
            xa, xb = 60 + c * s, 60 + (c + 1) * s
            ya, yb = 46 + r * s, 46 + (r + 1) * s
            q = poly([(xa, fy(xa, ya)), (xb, fy(xb, ya)), (xb, fy(xb, yb)), (xa, fy(xa, yb))])
            flag = U(flag, q)
            if (r + c) % 2 == 0:
                dark = U(dark, q)
    ic.shadow(flag, 2, 6, 6, 0.4)
    ic.fill(flag, "#FFFFFF")
    ic.fill(dark, P["check"])
    ic.fill(flag * (0.5 - 0.5 * np.cos((X - 60) / 26.0)), "#000000", 0.18)
    bx, by = 172, 168
    badge = circle(bx, by, 40)
    ic.shadow(badge, 2, 6, 6, 0.45)
    ic.fill(badge, rgrad([lighten(P["badge"], 0.35), P["badge"], darken(P["badge"], 0.2)], bx - 12, by - 14, 50))
    ic.rim(badge, 1.6, 0.5)
    plus = U(rrect(bx - 22, by - 7, bx + 22, by + 7, 7), rrect(bx - 7, by - 22, bx + 7, by + 22, 7))
    ic.shadow(plus, 1, 3, 3, 0.3)
    ic.fill(plus, "#FFFFFF")
    for (y, w) in ((150, 30), (170, 22), (190, 30)):
        ic.fill(line([(bx - 46 - w, y), (bx - 50, y)], 4), "#FFFFFF", 0.6)


@motif
def multiply(ic):
    P = ic.P
    a = line([(70, 70), (186, 186)], 38)
    b = line([(186, 70), (70, 186)], 38)
    ic.shadow(U(a, b), 2, 8, 8, 0.45)
    ic.fill(shift(U(a, b), 4, 7), darken(P["x2"], 0.45))
    ic.fill(b, lgrad([lighten(P["x2"], 0.3), P["x2"], darken(P["x2"], 0.2)], 70, 70, 186, 186))
    ic.rim(b, 1.6, 0.5)
    ic.shadow(a, 1, 4, 5, 0.35)
    ic.fill(a, lgrad([lighten(P["x1"], 0.3), P["x1"], darken(P["x1"], 0.2)], 70, 70, 186, 186))
    ic.rim(a, 1.6, 0.55)
    ic.gloss(a, 0.15)
    for (x, y, r) in ((60, 182, 16), (196, 56, 13), (204, 196, 9)):
        st = star(x, y, r, r * 0.45)
        ic.shadow(st, 1, 3, 3, 0.3)
        ic.fill(st, lgrad([lighten(P["star"], 0.35), darken(P["star"], 0.1)], x - r, y - r, x + r, y + r))


def _isprime(n):
    if n < 2:
        return False
    return all(n % k for k in range(2, int(n ** 0.5) + 1))


@motif
def primes(ic):
    P = ic.P
    s = 15.5
    cx, cy = 128, 124
    x, y, n = 0, 0, 1
    dx, dy = 1, 0
    seg, steps, turns = 1, 0, 0
    pts = []
    while n <= 15 * 15:
        pts.append((x, y, n))
        x += dx
        y += dy
        n += 1
        steps += 1
        if steps == seg:
            steps = 0
            dx, dy = dy, -dx
            turns += 1
            if turns % 2 == 0:
                seg += 1
    path = [(cx + px_ * s, cy + py_ * s) for (px_, py_, _) in pts[:60]]
    ic.fill(line(path, 1.4, False), P["path"], 0.3)
    glow = np.zeros((N, N), np.float32)
    dots = []
    for (px_, py_, k) in pts:
        x0, y0 = cx + px_ * s, cy + py_ * s
        if abs(px_) > 6 or abs(py_) > 6:
            continue
        if _isprime(k):
            dots.append((x0, y0))
            glow = U(glow, circle(x0, y0, 5.6))
        else:
            ic.fill(circle(x0, y0, 2.0), P["path"], 0.35)
    ic.add(blur(glow, 4), P["glow"], 0.7)
    for (x0, y0) in dots:
        t = min(1.0, math.hypot(x0 - cx, y0 - cy) / 90)
        c = mix(P["p1"], P["p2"], t)
        ic.fill(circle(x0, y0, 5.6), rgrad([lighten(c, 0.5), c], x0 - 1.5, y0 - 1.5, 6))
    ic.fill(circle(cx, cy, 5.5), "#FFFFFF")


@motif
def turtle(ic):
    P = ic.P
    cx, cy, r0 = 128, 128, 74
    pts = [(cx + r0 * math.cos(math.radians(-90 + i * 144)), cy + r0 * math.sin(math.radians(-90 + i * 144)))
           for i in range(6)]
    path = []
    for i in range(5):
        a, b = pts[i], pts[i + 1]
        for j in range(12):
            t = j / 12
            path.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    path.append(pts[5])
    stop = 30
    drawn = line(path[:stop + 1], 5)
    ic.shadow(drawn, 0.5, 2, 2, 0.2)
    ic.fill(drawn, P["trail"])
    for i in range(stop + 2, len(path) - 1, 3):
        ic.fill(circle(*path[i], 2.2), P["trail"], 0.35)
    tx, ty = path[stop]
    nx_, ny_ = path[stop + 1]
    hd = math.degrees(math.atan2(ny_ - ty, nx_ - tx))
    k = 1.15
    legs = U(*[ellipse(*polar(tx, ty, 30 * k, hd + a), 10 * k, 7 * k, hd + a) for a in (45, 135, 225, 315)])
    head = ellipse(*polar(tx, ty, 39 * k, hd), 13 * k, 11 * k, hd)
    tail = poly([polar(tx, ty, 30 * k, hd + 172), polar(tx, ty, 44 * k, hd + 180), polar(tx, ty, 30 * k, hd + 188)])
    skin = U(legs, head, tail)
    shell = ellipse(tx, ty, 36 * k, 31 * k, hd)
    ic.shadow(U(skin, shell), 2, 6, 6, 0.4)
    ic.fill(skin, lgrad([lighten(P["skin"], 0.2), darken(P["skin"], 0.2)], tx - 40, ty - 40, tx + 40, ty + 40))
    for side in (-90, 90):
        ex, ey = polar(*polar(tx, ty, 44 * k, hd), 5.5, hd + side)
        ic.fill(circle(ex, ey, 2.6), "#1B1E2B")
    ic.fill(shell, rgrad([lighten(P["shell"], 0.3), P["shell"], darken(P["shell"], 0.3)], tx - 10, ty - 12, 50))
    hexes = np.zeros((N, N), np.float32)
    for (dx, dy) in ((0, 0), (19, 0), (-19, 0), (9.5, 16), (-9.5, 16), (9.5, -16), (-9.5, -16)):
        hx, hy = rotate([(tx + dx, ty + dy)], hd, tx, ty)[0]
        hexes = U(hexes, poly([polar(hx, hy, 9.5, hd + 30 + j * 60) for j in range(6)]))
    ic.fill(hexes * shell, lighten(P["shell"], 0.25), 0.9)
    ic.fill(np.clip(shell - ellipse(tx, ty, 33 * k, 28 * k, hd), 0, 1), darken(P["shell"], 0.35), 0.8)
    ic.rim(shell, 1.4, 0.45)


@motif
def benchmark(ic):
    P = ic.P
    cx, cy, r = 128, 136, 82
    face = circle(cx, cy, r + 8)
    ic.shadow(face, 2, 7, 7, 0.5)
    ic.fill(face, lgrad(["#5A6275", "#1A1D27"], cx - r, cy - r, cx + r, cy + r))
    dial = circle(cx, cy, r)
    ic.fill(dial, rgrad([lighten(P["dial"], 0.12), P["dial"], darken(P["dial"], 0.35)], cx, cy - 20, r * 1.2))
    ic.inner(dial, 3, 0, 3, 0.5, "#000000")
    a0, a1 = 135, 405
    m = arc(cx, cy, r - 16, a0, a1, 11, False)
    ic.add(blur(m, 4) * smoothstep(cx - 10, cx + 60, X), P["hot"], 0.5)
    ic.fill(m, agrad([(0.0, P["cool"]), (0.375, P["cool"]), (0.6, P["mid"]), (0.85, P["hot"]), (1.0, P["cool"])],
                     cx, cy, 90))
    tm = np.zeros((N, N), np.float32)
    for k in range(10):
        a = a0 + (a1 - a0) * k / 9
        tm = U(tm, line([polar(cx, cy, r - 34, a), polar(cx, cy, r - 26, a)], 3))
    ic.fill(tm, "#FFFFFF", 0.8)
    na = 345
    nd = poly([polar(cx, cy, 64, na), polar(cx, cy, 6, na + 90), polar(cx, cy, 14, na + 180), polar(cx, cy, 6, na - 90)])
    ic.add(blur(nd, 3), P["needle"], 0.6)
    ic.shadow(nd, 1, 3, 3, 0.4, "#000000")
    ic.fill(nd, P["needle"])
    ic.fill(circle(cx, cy, 11), lgrad(["#F4F6FA", "#6E7689"], cx - 11, cy - 11, cx + 11, cy + 11))
    iso_cube(ic, cx, cy + 46, 16, P["cube1"], P["cube2"], darken(P["cube2"], 0.25), 16, shadow=0.3)
