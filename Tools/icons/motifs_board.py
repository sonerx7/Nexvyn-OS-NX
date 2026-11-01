"""Game icons: board and card games."""
import math

import numpy as np

from iconkit import (B, L, N, R, T, U, X, Y, arc, bezier, blur, box, circle, col, darken, ellipse, heart_pts, lgrad,
                     lighten, line, poly, rgrad, ring, rotate, rrect, shift, sparkle, star, star_pts, sub, text, vgrad)
from motifs_common import motif, sphere


def _iso(o, s, u, v):
    return (o[0] + (u - v) * s * 0.866, o[1] + (u + v) * s * 0.5)


def _disc(ic, x, y, rx, h, color, top=None, shadow=0.35):
    """A thick round piece seen from above at an angle (checkers, discs)."""
    ry = rx * 0.58
    side = U(ellipse(x, y + h, rx, ry), rrect(x - rx, y, x + rx, y + h, 0))
    topm = ellipse(x, y, rx, ry)
    if shadow:
        ic.shadow(U(side, topm), 1.5, 4, 4, shadow)
    ic.fill(side, lgrad([darken(color, 0.15), darken(color, 0.45)], x - rx, 0, x + rx, 0))
    ic.fill(topm, rgrad([lighten(top or color, 0.3), top or color, darken(top or color, 0.1)], x - rx * 0.3,
                        y - ry * 0.4, rx * 1.2))
    ic.fill(np.clip(ellipse(x, y, rx * 0.7, ry * 0.7) - ellipse(x, y + 1.2, rx * 0.7, ry * 0.7), 0, 1),
            darken(color, 0.4), 0.6)
    ic.fill(np.clip(ellipse(x, y + 1.2, rx * 0.7, ry * 0.7) - ellipse(x, y, rx * 0.7, ry * 0.7), 0, 1),
            lighten(color, 0.4), 0.5)
    return U(side, topm)


@motif
def checkers(ic):
    P = ic.P
    s = 30
    o = (128, 58)
    n = 4
    board = poly([_iso(o, s, 0, 0), _iso(o, s, n, 0), _iso(o, s, n, n), _iso(o, s, 0, n)])
    edge = poly([_iso(o, s, n, 0), _iso(o, s, n, n), _iso(o, s, 0, n),
                 (_iso(o, s, 0, n)[0], _iso(o, s, 0, n)[1] + 12), (_iso(o, s, n, n)[0], _iso(o, s, n, n)[1] + 12),
                 (_iso(o, s, n, 0)[0], _iso(o, s, n, 0)[1] + 12)])
    ic.shadow(U(board, edge), 2, 8, 8, 0.45)
    ic.fill(edge, lgrad([P["wood"], darken(P["wood"], 0.4)], 40, 0, 220, 0))
    for u in range(n):
        for v in range(n):
            cell = poly([_iso(o, s, u, v), _iso(o, s, u + 1, v), _iso(o, s, u + 1, v + 1), _iso(o, s, u, v + 1)])
            c = P["light"] if (u + v) % 2 == 0 else P["dark"]
            ic.fill(cell, lgrad([lighten(c, 0.08), darken(c, 0.08)], 40, 60, 220, 190))
    ic.fill(np.clip(board - shift(board, 0, 1.5), 0, 1), "#FFFFFF", 0.4)
    pieces = [(0.5, 2.5, "red"), (1.5, 3.5, "black"), (2.5, 1.5, "black"), (3.5, 2.5, "red")]
    for (u, v, k) in sorted(pieces, key=lambda p: p[0] + p[1]):
        x, y = _iso(o, s, u, v)
        _disc(ic, x, y - 8, 19, 8, P[k], None, 0.35)
    # a king: two stacked pieces and a crown
    x, y = _iso(o, s, 1.5, 1.5)
    _disc(ic, x, y - 8, 21, 8, P["red"], None, 0.4)
    _disc(ic, x, y - 20, 21, 8, P["red"], None, 0.25)
    crown = poly([(x - 11, y - 18), (x - 13, y - 30), (x - 6, y - 24), (x, y - 33), (x + 6, y - 24), (x + 13, y - 30),
                  (x + 11, y - 18)])
    ic.shadow(crown, 0.5, 1.5, 1, 0.3)
    ic.fill(crown, lgrad([lighten(P["crown"], 0.3), darken(P["crown"], 0.15)], 0, y - 33, 0, y - 18))


@motif
def connect4(ic):
    P = ic.P
    # a disc dropping in
    dx, dy = 150, 40
    ic.fill(line([(dx - 8, dy - 20), (dx - 8, dy - 6)], 3), "#FFFFFF", 0.5)
    ic.fill(line([(dx + 8, dy - 22), (dx + 8, dy - 8)], 3), "#FFFFFF", 0.5)
    sphere(ic, dx, dy + 8, 15, P["p1"], 0.3, 0.6)
    frame = rrect(42, 64, 214, 204, 18)
    cols, rows = 5, 4
    holes = []
    for r in range(rows):
        for c in range(cols):
            holes.append((60 + c * 34, 84 + r * 34))
    hm = U(*[circle(x, y, 12.5) for x, y in holes])
    fm = sub(frame, hm)
    ic.shadow(frame, 2, 7, 7, 0.45)
    board = {(0, 3): "p1", (1, 3): "p2", (2, 3): "p1", (3, 3): "p2", (4, 3): "p2", (1, 2): "p1", (2, 2): "p2",
             (3, 2): "p1", (2, 1): "p1", (3, 1): "p2", (3, 0): "p1"}
    ic.fill(hm, darken(P["frame"], 0.6))
    for (c, r), k in board.items():
        x, y = holes[r * cols + c]
        ic.fill(circle(x, y, 12.5), rgrad([lighten(P[k], 0.3), P[k], darken(P[k], 0.3)], x - 4, y - 4, 15))
        ic.fill(ring(x, y, 7.5, 1.6), darken(P[k], 0.25), 0.6)
    ic.fill(fm, lgrad([lighten(P["frame"], 0.25), P["frame"], darken(P["frame"], 0.25)], 42, 64, 214, 204))
    ic.inner(hm, 2.5, 0, 2.5, 0.5, "#000000")
    ic.rim(frame, 1.8, 0.5)
    ic.fill(rrect(30, 198, 226, 214, 6), lgrad([lighten(P["frame"], 0.1), darken(P["frame"], 0.35)], 0, 198, 0, 214))


@motif
def reversi(ic):
    P = ic.P
    for k in range(1, 4):
        ic.fill(line([(L, 44 + k * 52 - 26), (R, 44 + k * 52 - 26)], 2.5, False), darken(P["felt"], 0.45), 0.7)
        ic.fill(line([(24 + k * 52, T), (24 + k * 52, B)], 2.5, False), darken(P["felt"], 0.45), 0.7)
    cells = {(0, 0): "w", (1, 0): "b", (0, 1): "b", (1, 1): "w", (2, 1): "b", (1, 2): "w", (2, 2): "b", (0, 2): "w"}
    for (c, r), k in cells.items():
        x, y = 50 + c * 52, 44 + r * 52
        if (c, r) == (2, 1):
            continue
        base = P["white"] if k == "w" else P["black"]
        m = circle(x, y + 3, 21)
        ic.shadow(m, 1.5, 4, 4, 0.45)
        ic.fill(m, darken(base, 0.3))
        top = circle(x, y, 21)
        ic.fill(top, rgrad([lighten(base, 0.35), base, darken(base, 0.12)], x - 7, y - 8, 26))
        ic.fill(ring(x, y, 14, 1.2), darken(base, 0.2) if k == "w" else lighten(base, 0.15), 0.4)
    # the disc being flipped: tilted, half white half black
    x, y = 154, 100
    ic.shadow(ellipse(x, y + 18, 20, 6), 0, 2, 3, 0.3)
    e = ellipse(x, y, 22, 9, -30)
    ic.shadow(e, 2, 6, 5, 0.4)
    ic.fill(ellipse(x + 1.5, y + 2.5, 22, 9, -30), darken(P["black"], 0.1))
    ic.fill(e, rgrad([lighten(P["white"], 0.2), P["white"]], x - 6, y - 4, 22))
    arcm = arc(x, y, 34, 200, 300, 4)
    ic.fill(arcm, "#FFFFFF", 0.8)
    tip = (x + 34 * math.cos(math.radians(300)), y + 34 * math.sin(math.radians(300)))
    ic.fill(poly([(tip[0] + 6, tip[1] - 6), (tip[0] + 6, tip[1] + 8), (tip[0] - 7, tip[1] + 1)]), "#FFFFFF", 0.8)


@motif
def tictactoe(ic):
    P = ic.P
    for y in range(44, 228, 18):
        ic.fill(line([(L, y), (R, y)], 1.2, False), P["rule"], 0.55)
    ic.fill(line([(54, T), (54, B)], 1.6, False), P["margin"], 0.6)
    ink = P["ink"]
    g = np.zeros((N, N), np.float32)
    for (a, b) in (((104, 46), (100, 206)), ((154, 44), (156, 204)), ((58, 98), (210, 94)), ((60, 150), (208, 152))):
        g = U(g, line(bezier(a, ((a[0] + b[0]) / 2 + 3, (a[1] + b[1]) / 2 - 2), b), 6))
    ic.shadow(g, 1, 2, 1.5, 0.2)
    ic.fill(g, ink)

    def x_mark(cx, cy, s):
        m = U(line([(cx - s, cy - s), (cx + s * 0.95, cy + s * 1.05)], 11), line([(cx + s, cy - s * 1.05), (cx - s, cy + s)], 11))
        ic.shadow(m, 1, 3, 2.5, 0.25)
        ic.fill(m, lgrad([lighten(P["x"], 0.15), darken(P["x"], 0.15)], cx - s, cy - s, cx + s, cy + s))

    def o_mark(cx, cy, r):
        m = arc(cx, cy, r, -70, 270, 11)
        ic.shadow(m, 1, 3, 2.5, 0.25)
        ic.fill(m, lgrad([lighten(P["o"], 0.15), darken(P["o"], 0.15)], cx - r, cy - r, cx + r, cy + r))

    x_mark(78, 72, 14)
    o_mark(130, 72, 16)
    x_mark(130, 124, 14)
    o_mark(182, 124, 16)
    o_mark(78, 178, 16)
    x_mark(182, 178, 14)
    hl = line([(60, 54), (200, 196)], 16)
    ic.fill(hl, P["hl"], 0.45)


@motif
def mastermind(ic):
    P = ic.P
    board = poly([(66, 40), (190, 40), (222, 214), (34, 214)])
    ic.shadow(board, 2, 8, 8, 0.45)
    ic.fill(board, lgrad([lighten(P["board"], 0.15), P["board"], darken(P["board"], 0.3)], 0, 40, 0, 214))
    ic.rim(board, 1.6, 0.4)
    # the hidden code under a hinged cover
    cover = poly([(74, 44), (182, 44), (186, 66), (70, 66)])
    ic.shadow(cover, 1, 3, 3, 0.3)
    ic.fill(cover, lgrad([lighten(P["cover"], 0.25), darken(P["cover"], 0.15)], 0, 44, 0, 66))
    rows = [("abca", "kkw"), ("cdba", "kw"), ("abdc", "kkkk")]
    for i, (code, keys) in enumerate(rows):
        t = (i + 1) / 3.2
        y = 76 + i * 46 + i * i * 2
        sc = 0.8 + 0.25 * t
        x0, x1 = 128 - (52 + 26 * t), 128 + (52 + 26 * t) - 30 * sc
        for j, ch in enumerate(code):
            x = x0 + (x1 - x0) * j / 3
            r = 11 * sc
            ic.fill(ellipse(x, y + r * 0.5, r * 0.9, r * 0.45), darken(P["board"], 0.5), 0.6)
            sphere(ic, x, y, r, P[ch], 0.3, 0.8, (1, 3, 3))
        kx = x1 + 26 * sc
        for j, k in enumerate(keys):
            xx = kx + (j % 2) * 9 * sc
            yy = y - 5 * sc + (j // 2) * 9 * sc
            sphere(ic, xx, yy, 3.4 * sc, P["kb"] if k == "k" else P["kw"], 0.2, 0.6, (0.5, 1, 1))


@motif
def memory(ic):
    P = ic.P

    def card(cx, cy, w, h, ang, face):
        m = box(cx, cy, w, h, 10, ang)
        ic.shadow(m, 2, 6, 6, 0.4)
        if face:
            ic.fill(m, lgrad(["#FFFFFF", "#ECEFF5"], cx, cy - h / 2, cx, cy + h / 2))
            hm = poly(rotate(heart_pts(cx, cy + 2, w * 0.3), ang, cx, cy))
            ic.shadow(hm, 0.5, 2, 2, 0.2)
            ic.fill(hm, rgrad([lighten(P["symbol"], 0.3), P["symbol"], darken(P["symbol"], 0.25)], cx - 6, cy - 8,
                              w * 0.5))
            ic.fill(blur(ellipse(cx - w * 0.1, cy - h * 0.08, 4, 3, ang - 30), 0.6), "#FFFFFF", 0.6)
        else:
            ic.fill(m, lgrad([lighten(P["back"], 0.2), darken(P["back"], 0.2)], cx - w / 2, cy - h / 2, cx + w / 2,
                             cy + h / 2))
            inner = box(cx, cy, w - 14, h - 14, 6, ang)
            pat = np.zeros((N, N), np.float32)
            for i in range(-3, 4):
                pat = U(pat, line(rotate([(cx - 60, cy + i * 12 - 60), (cx + 60, cy + i * 12 + 60)], ang, cx, cy), 2.2, False))
                pat = U(pat, line(rotate([(cx + 60, cy + i * 12 - 60), (cx - 60, cy + i * 12 + 60)], ang, cx, cy), 2.2, False))
            ic.fill(pat * inner, lighten(P["back"], 0.35), 0.5)
            ic.fill(np.clip(inner - box(cx, cy, w - 18, h - 18, 4, ang), 0, 1), "#FFFFFF", 0.6)
        ic.rim(m, 1.6, 0.6)

    card(84, 84, 62, 84, -10, False)
    card(178, 98, 62, 84, 12, False)
    card(80, 170, 62, 84, -6, True)
    card(170, 170, 62, 84, 9, True)
    ic.add(sparkle(126, 140, 14), "#FFFFFF", 0.95)
    ic.add(sparkle(212, 136, 8), "#FFFFFF", 0.8)
