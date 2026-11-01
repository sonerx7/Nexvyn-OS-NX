"""Game icons: arcade."""
import math

import numpy as np

from iconkit import (B, L, N, R, T, U, X, Y, arc, bezier, blur, box, circle, col, darken, ellipse, lgrad, lighten,
                     line, poly, rgrad, ring, rotate, rrect, shift, star, sub, vgrad)
from motifs_common import cloud, coin, iso_box, motif, pixels


@motif
def airhockey(ic):
    P = ic.P
    ic.fill(line([(L, 124), (R, 124)], 4, False), P["line"], 0.8)
    ic.fill(ring(128, 124, 30, 3), P["line2"], 0.75)
    ic.fill(ring(128, T, 52, 3), P["line2"], 0.75)
    ic.fill(rrect(92, T - 6, 164, T + 6, 4), darken(P["line2"], 0.5), 0.8)
    for j, y in enumerate((60, 92, 156, 188)):
        for x in range(40, 230, 18):
            ic.fill(circle(x + (9 if j % 2 else 0), y, 1.3), darken(P["line2"], 0.3), 0.18)
    px_, py_ = 92, 92
    for i, (dx, dy) in enumerate(((22, 26), (30, 34), (38, 42))):
        ic.fill(line([(px_ + dx, py_ + dy), (px_ + dx + 18, py_ + dy + 20)], 4), P["line2"], 0.35 - i * 0.08)
    ic.shadow(ellipse(px_, py_ + 4, 22, 18), 2, 5, 4, 0.35)
    ic.fill(ellipse(px_, py_ + 5, 22, 18), darken(P["puck"], 0.4))
    ic.fill(ellipse(px_, py_, 22, 18), rgrad([lighten(P["puck"], 0.25), P["puck"]], px_ - 8, py_ - 8, 26))
    ic.fill(np.clip(ellipse(px_, py_, 16, 12) - ellipse(px_, py_, 13, 9.5), 0, 1), "#FFFFFF", 0.25)
    mx, my = 160, 160
    ic.shadow(ellipse(mx, my + 10, 38, 30), 3, 7, 7, 0.45)
    ic.fill(ellipse(mx, my + 10, 38, 30), darken(P["mallet"], 0.4))
    ic.fill(ellipse(mx, my, 38, 30), rgrad([lighten(P["mallet"], 0.3), P["mallet"], darken(P["mallet"], 0.2)],
                                         mx - 12, my - 12, 46))
    ic.fill(np.clip(ellipse(mx, my + 2, 27, 21) - ellipse(mx, my, 27, 21), 0, 1), "#FFFFFF", 0.45)
    knob = U(ellipse(mx, my - 2, 15, 12), rrect(mx - 15, my - 24, mx + 15, my - 2, 3))
    ic.shadow(knob, 1, 3, 3, 0.35)
    ic.fill(knob, lgrad([darken(P["mallet"], 0.2), lighten(P["mallet"], 0.1), darken(P["mallet"], 0.35)],
                        mx - 15, 0, mx + 15, 0))
    ic.fill(ellipse(mx, my - 24, 15, 12), rgrad([lighten(P["mallet"], 0.55), P["mallet"]], mx - 4, my - 28, 18))
    ic.fill(ellipse(mx - 5, my - 27, 5, 3), "#FFFFFF", 0.7)


def balloon(ic, x, y, r, color, string_to):
    m = U(ellipse(x, y, r, r * 1.18), poly([(x - r * 0.45, y + r * 0.95), (x, y + r * 1.3), (x + r * 0.45, y + r * 0.95)]))
    knot = poly([(x - 5, y + r * 1.32), (x + 5, y + r * 1.32), (x, y + r * 1.17)])
    ic.fill(line(bezier((x, y + r * 1.3), (x - 14, y + r * 1.8), (string_to[0] + 12, string_to[1] - 30), string_to),
                 1.6, False), "#FFFFFF", 0.75)
    ic.shadow(m, 3, 6, 6, 0.3)
    ic.fill(m, rgrad([(0, lighten(color, 0.45)), (0.5, col(color)), (1, darken(color, 0.4))], x - r * 0.35,
                     y - r * 0.45, r * 1.7))
    ic.fill(knot, darken(color, 0.15))
    ic.fill(blur(ellipse(x - r * 0.38, y - r * 0.45, r * 0.18, r * 0.32, 25), 1.0), "#FFFFFF", 0.8)
    return m


@motif
def balloons(ic):
    P = ic.P
    for (x, y, w) in ((60, 196, 80), (190, 206, 70)):
        ic.fill(cloud(x, y, w), "#FFFFFF", 0.85)
    balloon(ic, 86, 102, 30, P["b1"], (116, 214))
    balloon(ic, 160, 86, 33, P["b2"], (118, 214))
    balloon(ic, 124, 130, 28, P["b3"], (120, 214))
    bx, by = 196, 154
    ic.fill(star(bx, by, 20, 9, 8, -10), "#FFFFFF", 0.85)
    ic.fill(star(bx, by, 12, 6, 8, 12), P["b4"])
    for (dx, dy, a) in ((-24, -14, 30), (22, -20, -40), (24, 18, 15), (-18, 22, -20)):
        ic.fill(box(bx + dx, by + dy, 9, 4, 2, a), P["b4"])


@motif
def flappy(ic):
    P = ic.P
    ic.fill(cloud(80, 190, 110), "#FFFFFF", 0.8)
    ic.fill(cloud(190, 70, 70), "#FFFFFF", 0.6)

    def tower(x0, y0, y1, cap_low):
        m = rrect(x0, y0, x0 + 42, y1, 3)
        cap = rrect(x0 - 6, y1 - 14, x0 + 48, y1, 4) if cap_low else rrect(x0 - 6, y0, x0 + 48, y0 + 14, 4)
        allm = U(m, cap)
        ic.shadow(allm, 3, 4, 5, 0.35)
        ic.fill(allm, lgrad([lighten(P["tower"], 0.25), P["tower"], darken(P["tower"], 0.3)], x0 - 6, 0, x0 + 48, 0))
        jm = np.zeros((N, N), np.float32)
        for k, yy in enumerate(range(int(y0), int(y1), 12)):
            jm = U(jm, line([(x0, yy), (x0 + 42, yy)], 1.2, False))
            off = 14 if k % 2 else 28
            jm = U(jm, line([(x0 + off, yy), (x0 + off, yy + 12)], 1.2, False))
        ic.fill(jm * m, darken(P["tower"], 0.4), 0.45)
        ic.fill(cap, lgrad([lighten(P["cap"], 0.3), P["cap"], darken(P["cap"], 0.3)], x0 - 6, 0, x0 + 48, 0))
        ic.rim(allm, 1.4, 0.35)

    tower(168, 150, B + 10, False)
    tower(168, T - 10, 66, True)
    bx, by = 104, 112
    ic.fill(line([(40, by + 10), (62, by + 6)], 4), "#FFFFFF", 0.6)
    ic.fill(line([(36, by + 26), (60, by + 20)], 4), "#FFFFFF", 0.45)
    bodym = ellipse(bx, by, 38, 33)
    crest = poly([(bx - 4, by - 30), (bx - 2, by - 48), (bx + 10, by - 32), (bx + 16, by - 44), (bx + 18, by - 28)])
    ic.shadow(U(bodym, crest), 2, 6, 6, 0.4)
    ic.fill(crest, darken(P["bird"], 0.1))
    ic.fill(bodym, rgrad([lighten(P["bird"], 0.35), P["bird"], darken(P["bird"], 0.35)], bx - 12, by - 14, 50))
    ic.fill(ellipse(bx + 4, by + 16, 24, 14) * bodym, P["belly"])
    wing = ellipse(bx - 14, by + 6, 20, 13, -25)
    ic.fill(wing, lgrad([lighten(P["wing"], 0.2), darken(P["wing"], 0.2)], bx - 30, by - 6, bx, by + 20))
    ic.rim(wing, 1.2, 0.5)
    ic.fill(circle(bx + 18, by - 10, 10), "#FFFFFF")
    ic.fill(circle(bx + 21, by - 9, 5), "#1B1E2B")
    ic.fill(circle(bx + 19, by - 12, 1.8), "#FFFFFF")
    beak = poly([(bx + 30, by - 2), (bx + 52, by + 4), (bx + 30, by + 12)])
    ic.fill(beak, lgrad([lighten(P["beak"], 0.2), darken(P["beak"], 0.15)], 0, by - 2, 0, by + 12))
    ic.fill(line([(bx + 32, by + 5), (bx + 48, by + 5)], 1.2), darken(P["beak"], 0.4), 0.6)
    ic.rim(bodym, 1.6, 0.4)


@motif
def jumper(ic):
    P = ic.P

    def platform(x, y, w):
        m = U(rrect(x - w / 2, y, x + w / 2, y + 14, 7), cloud(x, y - 6, w * 0.9) * (Y < y + 4))
        ic.shadow(m, 1, 4, 4, 0.25)
        ic.fill(m, vgrad("#FFFFFF", lighten(P["sky2"], 0.5), y - 20, y + 14))
        return m

    platform(80, 196, 84)
    platform(178, 92, 64)
    platform(70, 62, 50)
    sx, sy = 92, 192
    coil = line([(sx - 9, sy - 2), (sx + 9, sy - 7), (sx - 9, sy - 12), (sx + 9, sy - 17), (sx - 9, sy - 22)], 3)
    ic.fill(coil, P["spring"])
    ic.fill(rrect(sx - 12, sy - 27, sx + 12, sy - 22, 2), darken(P["spring"], 0.2))
    for (x, y) in ((176, 60), (196, 42)):
        coin(ic, x, y, 9, P["coin"], 0.0, None, 0.25)
    hx, hy = 132, 132
    for i, dy in enumerate((26, 36, 46)):
        ic.fill(line([(hx - 10 + i * 10, hy + dy + 8), (hx - 10 + i * 10, hy + dy + 18)], 3), "#FFFFFF", 0.5 - i * 0.1)
    hb = ellipse(hx, hy, 30, 33)
    ic.shadow(hb, 2, 6, 6, 0.4)
    ic.fill(hb, rgrad([lighten(P["hero"], 0.4), P["hero"], darken(P["hero"], 0.35)], hx - 10, hy - 14, 44))
    for ex in (hx - 10, hx + 10):
        ic.fill(ellipse(ex, hy - 8, 7, 9), "#FFFFFF")
        ic.fill(circle(ex + 1, hy - 6, 4), "#1B1E2B")
        ic.fill(circle(ex - 0.5, hy - 8.5, 1.4), "#FFFFFF")
    ic.fill(arc(hx, hy + 6, 9, 20, 160, 3), darken(P["hero"], 0.6))
    for ex in (hx - 18, hx + 18):
        ic.fill(circle(ex, hy + 6, 4.5), P["blush"], 0.5)
    ic.fill(U(ellipse(hx - 30, hy - 12, 8, 6, -40), ellipse(hx + 30, hy - 12, 8, 6, 40)), lighten(P["hero"], 0.1))
    ic.rim(hb, 1.6, 0.45)


@motif
def mazeeater(ic):
    P = ic.P
    walls = np.zeros((N, N), np.float32)
    for (x0, y0, x1, y1) in ((38, 40, 104, 72), (152, 40, 218, 72), (38, 178, 104, 210), (152, 178, 218, 210),
                             (112, 150, 144, 210)):
        walls = U(walls, sub(rrect(x0, y0, x1, y1, 10), rrect(x0 + 4, y0 + 4, x1 - 4, y1 - 4, 7)))
    ic.add(blur(walls, 3), P["wall"], 0.7)
    ic.fill(walls, lighten(P["wall"], 0.3))
    for x in range(150, 220, 18):
        ic.add(blur(circle(x, 124, 4), 2), P["dot"], 0.5)
        ic.fill(circle(x, 124, 3.6), P["dot"])
    ic.add(blur(circle(214, 160, 9), 5), P["dot"], 0.8)
    ic.fill(circle(214, 160, 8), lighten(P["dot"], 0.3))
    cx, cy = 96, 124
    bodym = rrect(cx - 40, cy - 38, cx + 40, cy + 38, 22)
    ic.shadow(bodym, 2, 6, 6, 0.45)
    ic.fill(bodym, lgrad([lighten(P["eater"], 0.3), P["eater"], darken(P["eater"], 0.3)], cx - 40, cy - 38,
                         cx + 40, cy + 38))
    mouth = rrect(cx - 26, cy + 2, cx + 40, cy + 26, 8)
    ic.fill(mouth * bodym, "#2A0B2E")
    teeth = np.zeros((N, N), np.float32)
    for x in range(int(cx - 22), int(cx + 38), 12):
        teeth = U(teeth, poly([(x, cy + 2), (x + 10, cy + 2), (x + 5, cy + 10)]))
        teeth = U(teeth, poly([(x + 6, cy + 26), (x + 16, cy + 26), (x + 11, cy + 18)]))
    ic.fill(teeth * mouth * bodym, "#FFFFFF")
    for ex in (cx - 14, cx + 16):
        ic.fill(circle(ex, cy - 16, 10), "#FFFFFF")
        ic.fill(circle(ex + 3, cy - 15, 5), "#1B1E2B")
        ic.fill(circle(ex + 1.5, cy - 17.5, 1.6), "#FFFFFF")
    ic.rim(bodym, 1.8, 0.5)


RUNNER = [".....A.....",
          ".....A.....",
          "..HHHHHHH..",
          "..HVVVVVH..",
          "..HVEVEVH..",
          "..HHHHHHH..",
          "...BBBBB...",
          ".BBBBBBBBB.",
          ".H.BBBBB.H.",
          "...LL.LL...",
          "..LL...LL..",
          ".KK.....KK."]


@motif
def pixelrun(ic):
    P = ic.P
    for (x, y) in ((54, 52), (168, 70)):
        pixels(ic, ["..WWW...", ".WWWWW..", "WWWWWWWW"], x, y, 6, {"W": "#FFFFFF"}, shadow=0.0, bevel=False)
    ground = ["GGGGGGGGGGGGGGGG", "DDDDDDDDDDDDDDDD", "DDdDDDDDdDDDDdDD", "DDDDDdDDDDDDDDDD"]
    pixels(ic, ground, 0, 180, 16, {"G": P["grass"], "D": P["dirt"], "d": darken(P["dirt"], 0.2)}, shadow=0.0)
    pixels(ic, ["GGGG", "DDDD"], 160, 128, 12, {"G": P["grass"], "D": P["dirt"]}, gap=0.0, shadow=0.35)
    pixels(ic, [".YY.", "YyYY", "YyYY", ".YY."], 177, 94, 6, {"Y": P["coin"], "y": lighten(P["coin"], 0.5)},
           shadow=0.3)
    ic.add(blur(rrect(79, 116, 103, 124, 2), 3), P["eyes"], 0.6)
    pixels(ic, RUNNER, 56, 84, 8, {"A": P["legs"], "H": P["head"], "V": P["visor"], "E": P["eyes"], "B": P["body"],
                                   "L": P["legs"], "K": P["boots"]}, shadow=0.4)
    for i, y in enumerate((132, 148, 164)):
        ic.fill(rrect(24 + i * 4, y, 46, y + 4, 1), "#FFFFFF", 0.55)


@motif
def pong(ic):
    P = ic.P
    field = sub(rrect(36, 40, 220, 208, 18), rrect(40, 44, 216, 204, 15))
    ic.add(blur(field, 3), P["frame"], 0.6)
    ic.fill(field, lighten(P["frame"], 0.3), 0.9)
    for y in range(52, 200, 16):
        ic.fill(rrect(126.5, y, 129.5, y + 9, 1.5), "#FFFFFF", 0.3)
    ic.fill(np.clip(circle(128, 124, 24) - circle(128, 124, 22), 0, 1), "#FFFFFF", 0.25)
    lp = rrect(52, 62, 66, 124, 7)
    rp = rrect(190, 124, 204, 186, 7)
    ic.add(blur(lp, 7), P["left"], 0.9)
    ic.add(blur(rp, 7), P["right"], 0.9)
    ic.solid(lp, P["left"], 0.0, rim=0.6, edge=0.1, light=0.35)
    ic.solid(rp, P["right"], 0.0, rim=0.6, edge=0.1, light=0.35)
    bx, by = 160, 150
    for i in range(6):
        t = i / 6
        x, y = 78 + (bx - 78) * t, 98 + (by - 98) * t
        ic.add(circle(x, y, 4 + 7 * t), P["trail"], 0.08 + 0.12 * t)
    ic.add(blur(circle(bx, by, 13), 8), P["ball"], 0.9)
    ic.fill(circle(bx, by, 11), rgrad(["#FFFFFF", lighten(P["ball"], 0.6)], bx - 3, by - 3, 12))


@motif
def rhythm(ic):
    P = ic.P
    vx, vy = 128, 18
    yb = B + 6
    xl, xr = 28, 228
    hw = poly([(vx - 14, vy + 10), (vx + 14, vy + 10), (xr, yb), (xl, yb)])
    ic.fill(hw, vgrad(darken(P["lane"], 0.4), P["lane"], vy, yb))
    lanes = [P["n1"], P["n2"], P["n3"], P["n4"]]

    def lane_x(k, y):
        t = (y - vy - 10) / (yb - vy - 10)
        x0 = (vx - 14) + (xl - (vx - 14)) * t
        x1 = (vx + 14) + (xr - (vx + 14)) * t
        return x0 + (x1 - x0) * k / 4

    for k in range(5):
        edge = k in (0, 4)
        ic.fill(line([(lane_x(k, vy + 12), vy + 12), (lane_x(k, yb), yb)], 1.6 if edge else 1.0, False),
                P["edge"] if edge else "#FFFFFF", 0.9 if edge else 0.25)
    yh = 190
    ic.add(blur(line([(lane_x(0, yh), yh), (lane_x(4, yh), yh)], 4), 4), "#FFFFFF", 0.5)
    for k in range(4):
        x = (lane_x(k, yh) + lane_x(k + 1, yh)) / 2
        ic.fill(ellipse(x, yh, 18, 8), darken(lanes[k], 0.45))
        ic.fill(np.clip(ellipse(x, yh, 18, 8) - ellipse(x, yh, 13, 5.5), 0, 1), lanes[k])
    for (k, y) in ((0, 150), (2, 112), (1, 74), (3, 58), (2, 176)):
        t = (y - vy - 10) / (yb - vy - 10)
        x = (lane_x(k, y) + lane_x(k + 1, y)) / 2
        w = 8 + 26 * t
        m = rrect(x - w / 2, y - w * 0.22, x + w / 2, y + w * 0.22, w * 0.2)
        ic.add(blur(m, 2 + 3 * t), lanes[k], 0.7)
        ic.solid(m, lanes[k], 0.0, rim=0.7, edge=0.2, light=0.4)


@motif
def stack(ic):
    P = ic.P
    cols = [P["c1"], P["c2"], P["c3"], P["c4"], P["c5"]]
    cx, base = 118, 186
    h = 16
    for i in range(5):
        iso_box(ic, cx, base - i * h, 86, 86, h, cols[i], shadow=0.3 if i == 0 else 0.1)
    # the top slab lands a little off; the overhang drops away
    iso_box(ic, cx + 10, base - 5 * h - 2, 72, 86, h, P["top"], shadow=0.25)
    iso_box(ic, 196, 150, 18, 60, 14, lighten(P["top"], 0.05), shadow=0.3)
    for (x, y0) in ((206, 104), (216, 112), (196, 98)):
        ic.fill(line([(x, y0), (x, y0 + 16)], 2.5), "#FFFFFF", 0.5)


@motif
def whack(ic):
    P = ic.P
    hx, hy = 112, 182
    ic.fill(ellipse(hx, hy + 6, 70, 22), darken(P["dirt"], 0.1))
    ic.fill(ellipse(hx, hy + 2, 66, 18), lgrad([lighten(P["dirt"], 0.2), P["dirt"]], 0, hy - 16, 0, hy + 20))
    hole = ellipse(hx, hy, 48, 13)
    ic.fill(hole, "#1E120C")
    mole = U(rrect(hx - 36, hy - 70, hx + 36, hy + 2, 34), ellipse(hx, hy - 2, 36, 10))
    mole = mole * (1 - (Y > hy + 1) * (1 - hole))
    ic.fill(mole, lgrad([lighten(P["mole"], 0.25), P["mole"], darken(P["mole"], 0.3)], hx - 36, 0, hx + 36, 0))
    ic.fill(ellipse(hx, hy - 30, 22, 17) * mole, P["muzzle"])
    ic.fill(ellipse(hx, hy - 42, 8, 6), P["nose"])
    ic.fill(ellipse(hx - 2, hy - 44, 3, 2), "#FFFFFF", 0.7)
    ic.fill(U(rrect(hx - 6, hy - 30, hx - 0.8, hy - 20, 1.5), rrect(hx + 0.8, hy - 30, hx + 6, hy - 20, 1.5)), "#FFFFFF")
    for ex in (hx - 16, hx + 16):
        ic.fill(line([(ex - 6, hy - 50), (ex, hy - 54), (ex + 6, hy - 50)], 3), "#2A1A12")
    ic.fill(ellipse(hx - 26, hy - 34, 5, 3.5), P["blush"], 0.6)
    ic.fill(ellipse(hx + 26, hy - 34, 5, 3.5), P["blush"], 0.6)
    ic.fill(np.clip(mole - shift(mole, 0.5, 1.6), 0, 1), "#FFFFFF", 0.35)
    ic.fill(np.clip(ellipse(hx, hy + 4, 50, 14) - ellipse(hx, hy, 50, 14), 0, 1) * (Y > hy), lighten(P["dirt"], 0.3))
    ang = -38
    mx, my = 178, 76
    handle = box(mx + 18, my + 34, 10, 80, 4, ang)
    hx2, hy2 = mx - 8, my + 2
    head = box(hx2, hy2, 66, 36, 8, ang)
    capl = ellipse(*rotate([(hx2 - 33, hy2)], ang, hx2, hy2)[0], 7, 18, ang)
    capr = ellipse(*rotate([(hx2 + 33, hy2)], ang, hx2, hy2)[0], 7, 18, ang)
    ic.shadow(U(handle, head), 3, 6, 6, 0.45)
    ic.body(handle, P["handle"], 0.2, 0.2)
    ic.fill(head, lgrad([lighten(P["hammer"], 0.35), P["hammer"], darken(P["hammer"], 0.35)],
                        *rotate([(hx2, hy2 - 18)], ang, hx2, hy2)[0], *rotate([(hx2, hy2 + 18)], ang, hx2, hy2)[0]))
    ic.fill(capr, lighten(P["hammer"], 0.2))
    ic.fill(np.clip(capr - shift(capr, 1, 1), 0, 1), "#FFFFFF", 0.4)
    ic.fill(capl, darken(P["hammer"], 0.25), 0.6)
    ic.rim(head, 1.6, 0.5)
    for (x, y, r) in ((60, 92, 8), (78, 70, 6), (156, 132, 6)):
        ic.fill(star(x, y, r, r * 0.45), P["star"])
