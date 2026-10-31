"""Game icons: puzzles and word games."""
import math

import numpy as np

from iconkit import (B, L, N, R, T, U, X, Y, arc, bezier, blur, box, circle, col, darken, ellipse, lgrad, lighten,
                     line, poly, rgrad, ring, rotate, rrect, shift, sparkle, star, sub, text, vgrad)
from motifs_common import iso_box, motif, pencil, sphere


def _tile(ic, m, color, shadow=0.35, light=0.2, dark=0.2):
    ic.solid(m, color, shadow, (1.2, 3.5, 3.5), light, dark, 0.55, 0.18)


@motif
def fifteen(ic):
    P = ic.P
    frame = rrect(40, 36, 216, 212, 20)
    ic.shadow(frame, 2, 7, 7, 0.45)
    ic.fill(frame, lgrad([lighten(P["frame"], 0.2), P["frame"], darken(P["frame"], 0.3)], 40, 36, 216, 212))
    ic.rim(frame, 1.8, 0.45)
    well = rrect(50, 46, 206, 202, 12)
    ic.fill(well, darken(P["frame"], 0.55))
    ic.inner(well, 3, 0, 3, 0.6, "#000000")
    # the picture on the tiles: a sunset over hills
    pic = vgrad(P["sky1"], P["sky2"], 50, 200)
    sun = circle(150, 118, 30)
    hills = poly([(40, 170)] + bezier((40, 170), (90, 120), (130, 160), (170, 140)) +
                 bezier((170, 140), (190, 130), (205, 140), (220, 136)) + [(220, 210), (40, 210)])
    step, g = 38, 3
    for r in range(4):
        for c in range(4):
            if (c, r) == (3, 3):
                continue
            x0 = 52 + c * step + g / 2
            y0 = 48 + r * step + g / 2
            if (c, r) == (2, 3):
                x0 += 18
            m = rrect(x0, y0, x0 + step - g, y0 + step - g, 6)
            ic.shadow(m, 1, 2.5, 2.5, 0.45)
            ic.fill(m, pic)
            ic.fill(m * sun, rgrad([P["sun"], darken(P["sun"], 0.1)], 150, 110, 34))
            ic.fill(m * hills, vgrad(P["hill"], darken(P["hill"], 0.35), 130, 210))
            ic.rim(m, 1.4, 0.55, dark=0.2)


@motif
def g2048(ic):
    P = ic.P
    board = rrect(40, 40, 216, 216, 22)
    ic.shadow(board, 2, 7, 7, 0.4)
    ic.fill(board, lgrad([lighten(P["board"], 0.1), darken(P["board"], 0.12)], 0, 40, 0, 216))
    ic.rim(board, 1.8, 0.4)
    tiles = [[0, 1, 3], [0, 2, 4], [1, 5, 6]]
    cs = [P["t1"], P["t2"], P["t3"], P["t4"], P["t5"], P["t6"], P["t7"]]
    step, g = 56, 8
    for r in range(3):
        for c in range(3):
            x0 = 44 + c * step + g / 2
            y0 = 44 + r * step + g / 2
            m = rrect(x0, y0, x0 + step - g, y0 + step - g, 10)
            k = tiles[r][c]
            cx, cy = x0 + (step - g) / 2, y0 + (step - g) / 2
            if k == 0:
                ic.fill(m, darken(P["board"], 0.18))
                ic.inner(m, 2, 0, 2, 0.3, "#000000")
                continue
            if k == 6:
                ic.add(blur(m, 8), P["t7"], 0.7)
            _tile(ic, m, cs[k], 0.3, 0.25, 0.2)
            pips = {1: 2, 2: 4, 3: 8, 4: 16, 5: 32}.get(k, 0)
            if k == 6:
                st = star(cx, cy + 1, 17, 7.5)
                ic.shadow(st, 0.5, 2, 2, 0.3)
                ic.fill(st, "#FFFFFF")
            elif pips <= 4:
                pts = [(-7, 0), (7, 0)] if pips == 2 else [(-7, -7), (7, -7), (-7, 7), (7, 7)]
                for (dx, dy) in pts:
                    ic.fill(circle(cx + dx, cy + dy, 4.2), "#FFFFFF", 0.95)
            else:
                n = 4 if pips == 16 else 3
                for i in range(n):
                    for j in range(n):
                        d = 22 / (n - 1)
                        ic.fill(circle(cx - 11 + i * d, cy - 11 + j * d, 2.6), "#FFFFFF", 0.95)


@motif
def lightsout(ic):
    P = ic.P
    panel = rrect(40, 40, 216, 208, 22)
    ic.shadow(panel, 2, 7, 7, 0.45)
    ic.fill(panel, lgrad([lighten(P["panel"], 0.15), darken(P["panel"], 0.25)], 0, 40, 0, 208))
    ic.rim(panel, 1.8, 0.35)
    lit = {(2, 1), (1, 2), (2, 2), (3, 2), (2, 3), (0, 0), (4, 4)}
    step = 34
    for r in range(5):
        for c in range(5):
            x, y = 60 + c * step, 58 + r * step
            if (c, r) in lit:
                ic.add(blur(circle(x, y, 12), 7), P["glow"], 0.55)
            m = circle(x, y, 12.5)
            ic.fill(circle(x, y + 1.5, 13.5), "#000000", 0.4)
            if (c, r) in lit:
                ic.fill(m, rgrad([lighten(P["glow"], 0.7), P["glow"], darken(P["glow"], 0.15)], x - 3, y - 4, 15))
                ic.fill(ellipse(x - 3, y - 5, 5, 3), "#FFFFFF", 0.7)
            else:
                ic.fill(m, rgrad([lighten(P["off"], 0.12), P["off"], darken(P["off"], 0.3)], x - 3, y - 4, 15))
                ic.fill(np.clip(m - shift(m, 0, 1.4), 0, 1), "#FFFFFF", 0.25)


@motif
def minesweeper(ic):
    P = ic.P
    step = 52
    x0, y0 = 50, 46
    open_cells = {(1, 1), (2, 1), (0, 2), (1, 2)}
    for r in range(3):
        for c in range(3):
            x, y = x0 + c * step, y0 + r * step
            m = rrect(x + 2, y + 2, x + step - 2, y + step - 2, 8)
            if (c, r) in open_cells:
                ic.fill(m, P["open"])
                ic.inner(m, 2, 0, 2, 0.35, "#000000")
            else:
                _tile(ic, m, P["tile"], 0.3, 0.3, 0.2)
    # a count of dots on two open cells instead of digits
    for (c, r, n, color) in ((2, 1, 1, P["n1"]), (0, 2, 2, P["n2"])):
        cx, cy = x0 + c * step + step / 2, y0 + r * step + step / 2
        for i in range(n):
            ic.fill(circle(cx + (i - (n - 1) / 2) * 12, cy, 5.5), color)
    # the mine on a red cell
    mx, my = x0 + step * 1.5, y0 + step * 1.5
    ic.fill(rrect(mx - step / 2 + 2, my - step / 2 + 2, mx + step / 2 - 2, my + step / 2 - 2, 8), P["boom"])
    spikes = np.zeros((N, N), np.float32)
    for a in range(0, 360, 45):
        p0 = (mx + 8 * math.cos(math.radians(a)), my + 8 * math.sin(math.radians(a)))
        p1 = (mx + 22 * math.cos(math.radians(a)), my + 22 * math.sin(math.radians(a)))
        spikes = U(spikes, line([p0, p1], 5))
    ic.shadow(U(spikes, circle(mx, my, 15)), 1, 3, 3, 0.4)
    ic.fill(spikes, P["mine"])
    sphere(ic, mx, my, 15, P["mine"], 0.0, 0.9)
    # the flag on a closed cell
    fx, fy = x0 + step * 2.5 - 6, y0 + step * 0.5
    ic.fill(rrect(fx - 12, fy + 12, fx + 12, fy + 17, 2), darken(P["tile"], 0.6))
    ic.fill(line([(fx, fy - 18), (fx, fy + 14)], 3.5), darken(P["tile"], 0.6))
    flag = poly([(fx + 1, fy - 19), (fx + 22, fy - 10), (fx + 1, fy - 1)])
    ic.shadow(flag, 1, 2, 2, 0.3)
    ic.fill(flag, lgrad([lighten(P["flag"], 0.2), darken(P["flag"], 0.15)], fx, fy - 19, fx + 22, fy))


PICTURE = ["..XX..",
           ".XXXX.",
           "XXXXXX",
           "XXXXXX",
           ".XXXX.",
           "..XX.."]


@motif
def nonogram(ic):
    P = ic.P
    sheet = rrect(44, 40, 214, 210, 14)
    ic.shadow(sheet, 2, 6, 6, 0.35)
    ic.fill(sheet, vgrad("#FFFFFF", "#EEF1F6", 40, 210))
    gx, gy, step = 88, 84, 19
    n = 6
    clues_top = [[2], [4], [6], [6], [4], [2]]
    clues_left = [[2], [4], [6], [6], [4], [2]]
    for c, cl in enumerate(clues_top):
        h = 6 + 4 * cl[0]
        x = gx + c * step + step / 2
        ic.fill(rrect(x - 3.5, gy - 8 - h, x + 3.5, gy - 8, 3.5), P["clue"], 0.85)
    for r, cl in enumerate(clues_left):
        w = 6 + 4 * cl[0]
        y = gy + r * step + step / 2
        ic.fill(rrect(gx - 8 - w, y - 3.5, gx - 8, y + 3.5, 3.5), P["clue"], 0.85)
    for r in range(n):
        for c in range(n):
            x, y = gx + c * step, gy + r * step
            m = rrect(x + 1.5, y + 1.5, x + step - 1.5, y + step - 1.5, 3)
            if PICTURE[r][c] == "X":
                col_ = P["fill"] if r < 4 else P["fill2"]
                ic.fill(m, lgrad([lighten(col_, 0.15), darken(col_, 0.1)], x, y, x + step, y + step))
            else:
                ic.fill(m, "#E2E7F0")
                ic.fill(U(line([(x + 6, y + 6), (x + step - 6, y + step - 6)], 1.8),
                          line([(x + step - 6, y + 6), (x + 6, y + step - 6)], 1.8)), "#A9B3C6")
    ic.fill(sub(rrect(gx - 1, gy - 1, gx + n * step + 1, gy + n * step + 1, 3),
                rrect(gx + 1, gy + 1, gx + n * step - 1, gy + n * step - 1, 2)), P["clue"], 0.7)


@motif
def sokoban(ic):
    P = ic.P
    s = 40
    o = (128, 86)

    def iso(u, v):
        return (o[0] + (u - v) * s * 0.866, o[1] + (u + v) * s * 0.5)

    for u in range(-2, 4):
        for v in range(-2, 4):
            cell = poly([iso(u, v), iso(u + 1, v), iso(u + 1, v + 1), iso(u, v + 1)])
            c = P["floor"] if (u + v) % 2 == 0 else darken(P["floor"], 0.08)
            ic.fill(cell, c)
            ic.fill(np.clip(cell - shift(cell, 0, 1), 0, 1), "#FFFFFF", 0.12)
    # goal marker
    gx, gy = iso(1.5, 1.5)
    goal = poly([(gx, gy - 14), (gx + 24, gy), (gx, gy + 14), (gx - 24, gy)])
    ic.add(blur(goal, 6), P["goal"], 0.8)
    ic.fill(np.clip(goal - poly([(gx, gy - 8), (gx + 14, gy), (gx, gy + 8), (gx - 14, gy)]), 0, 1), P["goal"])
    # the crate, half-way onto the goal
    cx, cy = iso(1.0, 0.95)
    h = 40
    iso_box(ic, cx, cy - h + 6, 46, 46, h, P["crate"], shadow=0.4, light=0.25, darkr=0.3, rim=0.5)
    ex, ey = 0.866 * 23, 0.5 * 23
    top_y = cy - h + 6
    C = (cx, top_y + 2 * ey)            # front corner of the top face
    Lc = (cx - 2 * ex, top_y)          # left corner
    Rc = (cx + 2 * ex, top_y)          # right corner
    dn = lambda p: (p[0], p[1] + h)
    plank = darken(P["crate"], 0.45)
    for (a0, b0) in ((Lc, C), (C, Rc)):
        face = poly([a0, b0, dn(b0), dn(a0)])
        inner = np.clip(face - poly([(a0[0] + (b0[0] - a0[0]) * 0.12, a0[1] + (b0[1] - a0[1]) * 0.12 + 5),
                                     (a0[0] + (b0[0] - a0[0]) * 0.88, a0[1] + (b0[1] - a0[1]) * 0.88 + 5),
                                     (a0[0] + (b0[0] - a0[0]) * 0.88, a0[1] + (b0[1] - a0[1]) * 0.88 + h - 5),
                                     (a0[0] + (b0[0] - a0[0]) * 0.12, a0[1] + (b0[1] - a0[1]) * 0.12 + h - 5)]), 0, 1)
        ic.fill(inner, plank, 0.55)
        p0 = (a0[0] + (b0[0] - a0[0]) * 0.12, a0[1] + (b0[1] - a0[1]) * 0.12 + 5)
        p1 = (a0[0] + (b0[0] - a0[0]) * 0.88, a0[1] + (b0[1] - a0[1]) * 0.88 + h - 5)
        ic.fill(line([p0, p1], 4) * face, plank, 0.55)
    # push arrow
    ax, ay = iso(-0.6, 0.0)
    arr = poly([(ax - 18, ay - 9), (ax + 2, ay + 1), (ax - 2, ay - 9), (ax + 14, ay + 5), (ax - 6, ay + 13),
                (ax - 4, ay + 5), (ax - 24, ay - 5)])
    ic.shadow(arr, 1, 3, 3, 0.3)
    ic.fill(arr, P["arrow"])


@motif
def sudoku(ic):
    P = ic.P
    sheet = rrect(40, 40, 216, 216, 14)
    ic.shadow(sheet, 2, 6, 6, 0.4)
    ic.fill(sheet, vgrad("#FFFFFF", "#EEF2F8", 40, 216))
    g0, step = 50, 156 / 9
    hr, hc = 4, 6
    ic.fill(rrect(g0, g0 + hr * step, g0 + 9 * step, g0 + (hr + 1) * step, 0), P["hl"], 0.25)
    ic.fill(rrect(g0 + hc * step, g0, g0 + (hc + 1) * step, g0 + 9 * step, 0), P["hl"], 0.25)
    ic.fill(rrect(g0 + hc * step, g0 + hr * step, g0 + (hc + 1) * step, g0 + (hr + 1) * step, 0), P["hl"], 0.5)
    grid = np.zeros((N, N), np.float32)
    thick = np.zeros((N, N), np.float32)
    for i in range(10):
        p = g0 + i * step
        if i % 3 == 0:
            thick = U(thick, line([(p, g0), (p, g0 + 9 * step)], 3, False), line([(g0, p), (g0 + 9 * step, p)], 3, False))
        else:
            grid = U(grid, line([(p, g0), (p, g0 + 9 * step)], 1.0, False), line([(g0, p), (g0 + 9 * step, p)], 1.0, False))
    ic.fill(grid, P["line"], 0.35)
    ic.fill(thick, P["line"], 0.9)
    cols = [P["c1"], P["c2"], P["c3"], P["c4"], P["c5"]]
    rng = np.random.default_rng(12)
    for r in range(9):
        for c in range(9):
            if rng.random() < 0.38 and (r, c) != (hr, hc):
                k = rng.integers(0, 5)
                x, y = g0 + (c + 0.5) * step, g0 + (r + 0.5) * step
                ic.fill(circle(x, y, 5.2), cols[k])
    pencil(ic, 214, 236, 160, 150, 14, P["pencil"])


def _tube(mx, my, ex, ey, w):
    """A test tube from its mouth (mx, my) to the centre of its round bottom (ex, ey): (glass mask, lip mask)."""
    d = math.hypot(ex - mx, ey - my)
    ux, uy = (ex - mx) / d, (ey - my) / d
    nx, ny = -uy, ux
    a0 = math.degrees(math.atan2(ny, nx))
    pts = [(mx + nx * w / 2, my + ny * w / 2)]
    pts += [(ex + w / 2 * math.cos(math.radians(a0 - k)), ey + w / 2 * math.sin(math.radians(a0 - k)))
            for k in range(0, 181, 8)]
    pts += [(mx - nx * w / 2, my - ny * w / 2)]
    lw = w / 2 + 4
    lip = poly([(mx + nx * lw - ux * 4, my + ny * lw - uy * 4), (mx + nx * lw + ux * 4, my + ny * lw + uy * 4),
                (mx - nx * lw + ux * 4, my - ny * lw + uy * 4), (mx - nx * lw - ux * 4, my - ny * lw - uy * 4)])
    return poly(pts), lip


@motif
def watersort(ic):
    P = ic.P
    w, lh = 32, 24

    def glass(outer, lip):
        ic.fill(np.clip(outer - shift(outer, 2.5, 0), 0, 1), "#FFFFFF", 0.7)
        ic.fill(np.clip(outer - shift(outer, -2.5, 0), 0, 1), "#FFFFFF", 0.35)
        ic.fill(lip, "#FFFFFF", 0.85)

    def liquid(m, y0, y1, cc, x0, x1):
        band = m * ((Y >= y0) & (Y < y1)).astype(np.float32)
        ic.fill(band, lgrad([lighten(cc, 0.25), cc, darken(cc, 0.2)], x0, 0, x1, 0))
        ic.fill(np.clip(band - shift(band, 0, 2), 0, 1), lighten(cc, 0.5), 0.8)

    def upright(cx, top, bottom, layers):
        outer, lip = _tube(cx, top, cx, bottom - w / 2, w)
        ic.shadow(outer, 2, 6, 6, 0.35)
        ic.fill(outer, "#FFFFFF", 0.25)
        yb = bottom - 3
        for i, cc in enumerate(layers):
            liquid(outer, yb - (i + 1) * lh, yb - i * lh, cc, cx - w / 2, cx + w / 2)
        glass(outer, lip)

    upright(64, 112, 216, [P["a"], P["b"], P["a"]])
    upright(122, 112, 216, [P["c"], P["b"]])
    # the tube pouring into the middle one: its liquid gathers at the mouth
    outer, lip = _tube(146, 94, 212, 42, w)
    path = bezier((142, 96), (132, 98), (124, 104), (122, 150))
    stream = line(path, 5.5)
    ic.fill(stream, P["c"])
    ic.fill(line(path, 1.8) * stream, lighten(P["c"], 0.5), 0.6)
    ic.shadow(outer, 2, 6, 6, 0.35)
    ic.fill(outer, "#FFFFFF", 0.25)
    liquid(outer, 84, 140, P["c"], 130, 200)
    liquid(outer, 66, 84, P["a"], 130, 220)
    glass(outer, lip)
