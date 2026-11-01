"""Game icons: racing, sports, strategy, casual and word games."""
import math

import numpy as np

from iconkit import (B, L, N, R, T, U, X, Y, arc, bezier, blur, box, circle, col, darken, ellipse, lgrad, lighten,
                     line, poly, rgrad, ring, rotate, rrect, shift, smoothstep, sparkle, star, sub, text, vgrad)
from motifs_common import motif, sphere


@motif
def fishing(ic):
    P = ic.P
    hz = 132
    water = (Y >= hz).astype(np.float32)
    ic.fill(water, vgrad(P["water1"], P["water2"], hz, B))
    ic.add(blur(circle(196, hz, 26), 10), P["sun"], 0.6)
    ic.fill(circle(196, hz, 20) * (1 - water), P["sun"])
    for (y, x0, x1) in ((150, 40, 90), (166, 150, 210), (190, 60, 120), (206, 160, 200)):
        ic.fill(line([(x0, y), (x1, y)], 2.5), "#FFFFFF", 0.3)
    # ripples where the fish jumped out
    for r, op in ((34, 0.5), (22, 0.7)):
        ic.fill(np.clip(ellipse(124, hz + 10, r, r * 0.28) - ellipse(124, hz + 10, r - 2.5, r * 0.28 - 2), 0, 1),
                "#FFFFFF", op)
    # line from the rod above
    ic.fill(line(bezier((36, T), (90, 40), (150, 40), (182, 74)), 1.6, False), "#FFFFFF", 0.85)
    # fish: an arched leap
    fx, fy, a = 150, 92, -28
    bodym = poly(rotate([(fx + 42 * math.cos(t), fy + 17 * math.sin(t) * (1.15 if math.sin(t) > 0 else 0.95))
                         for t in np.linspace(0, 2 * math.pi, 80)], a, fx, fy))
    tail = poly(rotate([(fx - 34, fy), (fx - 62, fy - 18), (fx - 54, fy), (fx - 62, fy + 18)], a, fx, fy))
    fin = poly(rotate([(fx - 12, fy - 14), (fx + 4, fy - 32), (fx + 18, fy - 15)], a, fx, fy))
    allm = U(bodym, tail, fin)
    ic.shadow(allm, 2, 6, 6, 0.4)
    ic.fill(U(tail, fin), lgrad([lighten(P["fin"], 0.2), darken(P["fin"], 0.2)], fx - 60, fy - 30, fx + 20, fy + 20))
    ic.fill(bodym, lgrad([lighten(P["fish"], 0.3), P["fish"], darken(P["fish"], 0.25)],
                         *rotate([(fx, fy - 18)], a, fx, fy)[0], *rotate([(fx, fy + 18)], a, fx, fy)[0]))
    belly = poly(rotate([(fx + 38 * math.cos(t), fy + 6 + 11 * math.sin(t)) for t in np.linspace(0, math.pi, 40)],
                        a, fx, fy))
    ic.fill(belly * bodym, P["belly"], 0.85)
    for k in (-10, 4):
        ic.fill(line(rotate([(fx + k, fy - 14), (fx + k + 4, fy + 6)], a, fx, fy), 4) * bodym, darken(P["fish"], 0.3),
                0.5)
    ex, ey = rotate([(fx + 26, fy - 4)], a, fx, fy)[0]
    ic.fill(circle(ex, ey, 5), "#FFFFFF")
    ic.fill(circle(ex + 1, ey, 2.8), "#14161C")
    ic.rim(bodym, 1.4, 0.45)
    # splash drops
    for (x, y, r) in ((110, 118, 4), (100, 106, 3), (122, 110, 3.5), (140, 122, 3), (94, 124, 2.5)):
        ic.fill(circle(x, y, r), "#FFFFFF", 0.9)
    # bobber
    bx, by = 66, 150
    ic.fill(line([(bx, by - 26), (bx, by - 12)], 2), "#FFFFFF", 0.9)
    bm = circle(bx, by, 12)
    ic.shadow(bm, 1, 3, 3, 0.3)
    ic.fill(bm, rgrad([lighten(P["bobber"], 0.4), P["bobber"], darken(P["bobber"], 0.3)], bx - 4, by - 5, 14))
    ic.fill(bm * (Y > by), rgrad(["#FFFFFF", "#D9DEE8"], bx - 4, by, 14))
    ic.fill(np.clip(ellipse(bx, by + 10, 16, 4) - ellipse(bx, by + 10, 13, 2.6), 0, 1), "#FFFFFF", 0.6)


@motif
def maze3d(ic):
    P = ic.P
    x0, y0, x1, y1 = 104, 92, 152, 140
    ceil = poly([(L - 5, T - 5), (R + 5, T - 5), (x1, y0), (x0, y0)])
    floor = poly([(L - 5, B + 5), (R + 5, B + 5), (x1, y1), (x0, y1)])
    lw = poly([(L - 5, T - 5), (x0, y0), (x0, y1), (L - 5, B + 5)])
    rw = poly([(R + 5, T - 5), (x1, y0), (x1, y1), (R + 5, B + 5)])
    ic.fill(ceil, vgrad(darken(P["wall"], 0.6), darken(P["wall"], 0.35), T, y0))
    ic.fill(floor, vgrad(darken(P["floor"], 0.2), P["floor"], y1, B))
    ic.fill(lw, lgrad([P["wall"], darken(P["wall"], 0.35)], L, 0, x0, 0))
    ic.fill(rw, lgrad([darken(P["wall"], 0.45), darken(P["wall"], 0.15)], x1, 0, R, 0))
    # bricks: rows converging to the vanishing point, and joints
    joints = np.zeros((N, N), np.float32)
    for k in range(1, 6):
        t = k / 6
        for (xa, xb) in ((L, x0), (R, x1)):
            ya = T + (B - T) * t
            yb = y0 + (y1 - y0) * t
            joints = U(joints, line([(xa, ya), (xb, yb)], 1.2, False))
    for xx in (40, 66, 86):
        f = (xx - L) / (x0 - L)
        joints = U(joints, line([(xx, T + (y0 - T) * f), (xx, B + (y1 - B) * f)], 1.2, False))
        xr = 256 - xx
        joints = U(joints, line([(xr, T + (y0 - T) * f), (xr, B + (y1 - B) * f)], 1.2, False))
    ic.fill(joints * U(lw, rw), darken(P["wall"], 0.6), 0.5)
    # floor tiles
    tiles = np.zeros((N, N), np.float32)
    for k in range(-3, 4):
        tiles = U(tiles, line([(128 + k * 8, y1), (128 + k * 60, B + 5)], 1.2, False))
    for yy in (150, 166, 192):
        tiles = U(tiles, line([(L, yy), (R, yy)], 1.0, False))
    ic.fill(tiles * floor, darken(P["floor"], 0.4), 0.45)
    # the glowing exit
    door = rrect(x0, y0, x1, y1, 0)
    ic.fill(door, rgrad([lighten(P["exit"], 0.7), P["exit"]], 128, 116, 34))
    ic.add(blur(door, 10), P["exit"], 0.8)
    beam = poly([(x0, y1), (x1, y1), (176, B + 5), (80, B + 5)])
    ic.add(beam * smoothstep(B + 10, y1, Y), P["exit"], 0.45)
    # a direction arrow on the floor
    arr = poly([(128, 158), (150, 180), (138, 180), (138, 200), (118, 200), (118, 180), (106, 180)])
    ic.add(blur(arr, 3), P["arrow"], 0.6)
    ic.fill(arr, P["arrow"])


def pin_mask(cx, top, H, ang=0.0):
    prof = [(0, 0.0), (0.02, 0.2), (0.06, 0.3), (0.12, 0.32), (0.2, 0.25), (0.28, 0.17), (0.36, 0.19), (0.5, 0.36),
            (0.64, 0.43), (0.78, 0.4), (0.9, 0.31), (1.0, 0.24)]
    ts = np.linspace(0, 1, 50)
    hw = np.interp(ts, [p[0] for p in prof], [p[1] for p in prof]) * H * 0.42
    left = [(cx - w, top + t * H) for t, w in zip(ts, hw)]
    right = [(cx + w, top + t * H) for t, w in zip(ts[::-1], hw[::-1])]
    pts = left + right
    if ang:
        pts = rotate(pts, ang, cx, top + H / 2)
    return poly(pts)


@motif
def bowling(ic):
    P = ic.P
    for k in range(-4, 5):
        ic.fill(line([(128 + k * 10, T), (128 + k * 34, B)], 1.4, False), darken(P["lane"], 0.25), 0.35)
    pins = [(176, 46, 66, 0, 1.0), (146, 58, 72, -4, 1.0), (204, 72, 70, 26, 1.0)]
    for (x, top, H, ang, _) in pins:
        m = pin_mask(x, top, H, ang)
        ic.shadow(m, 2, 5, 5, 0.35)
        ic.fill(m, lgrad(["#FFFFFF", "#E6E9F0", "#B9C0CF"], x - 14, 0, x + 14, 0))
        for (t0, t1) in ((0.27, 0.31), (0.34, 0.38)):
            band = rrect(x - 30, top + H * t0, x + 30, top + H * t1, 0, ang, (x, top + H / 2))
            ic.fill(band * m, P["stripe"])
        ic.rim(m, 1.2, 0.5)
    # impact burst
    for a in range(-80, 60, 28):
        p0 = (132 + 26 * math.cos(math.radians(a)), 140 + 26 * math.sin(math.radians(a)))
        p1 = (132 + 40 * math.cos(math.radians(a)), 140 + 40 * math.sin(math.radians(a)))
        ic.fill(line([p0, p1], 3.5), "#FFFFFF", 0.85)
    # the ball
    bx, by, r = 90, 168, 42
    for i in range(3):
        ic.fill(line([(bx - 46 - i * 6, by + 18 - i * 14), (bx - 70 - i * 6, by + 24 - i * 14)], 4), "#FFFFFF",
                0.45)
    sphere(ic, bx, by, r, P["ball"], 0.45, 0.8)
    swirl = arc(bx + 6, by + 4, 26, 190, 320, 6) * circle(bx, by, r)
    ic.fill(swirl, lighten(P["ball"], 0.25), 0.4)
    for (dx, dy, rr) in ((10, -20, 5.5), (24, -12, 5.5), (16, 4, 6.5)):
        h = circle(bx + dx, by + dy, rr)
        ic.fill(h, darken(P["ball"], 0.7))
        ic.fill(np.clip(h - shift(h, 0, 1.6), 0, 1), "#000000", 0.5)
        ic.fill(np.clip(shift(h, 0, 1.2) - h, 0, 1), "#FFFFFF", 0.3)


@motif
def minigolf(ic):
    P = ic.P
    # windmill in the back
    wx, wy = 66, 74
    tower = poly([(wx - 12, wy + 40), (wx - 7, wy - 4), (wx + 7, wy - 4), (wx + 12, wy + 40)])
    ic.shadow(tower, 1, 3, 3, 0.3)
    ic.fill(tower, lgrad([lighten(P["mill"], 0.2), darken(P["mill"], 0.2)], wx - 12, 0, wx + 12, 0))
    ic.fill(poly([(wx - 10, wy - 2), (wx, wy - 14), (wx + 10, wy - 2)]), P["roof"])
    blades = U(*[box(*rotate([(wx, wy - 26)], a, wx, wy)[0], 6, 34, 1.5, a) for a in (20, 110)])
    blades = U(*[poly(rotate([(wx - 3, wy), (wx + 3, wy), (wx + 5, wy - 30), (wx - 5, wy - 30)], a, wx, wy))
                 for a in (25, 115, 205, 295)])
    ic.fill(blades, "#FFFFFF", 0.95)
    ic.fill(circle(wx, wy, 3.5), P["roof"])
    # sand bunker
    sand = U(ellipse(194, 206, 40, 16), ellipse(214, 198, 22, 12))
    ic.fill(sand, vgrad(lighten(P["sand"], 0.2), P["sand"], 186, 222))
    ic.inner(sand, 2, 0, 2, 0.3)
    # the hole with its flag
    hx, hy = 156, 150
    ic.fill(ellipse(hx, hy + 1.5, 21, 9), lighten(P["green"], 0.25))
    hole = ellipse(hx, hy, 19, 8)
    ic.fill(hole, "#0E1A10")
    ic.fill(hole * (Y > hy + 2), "#FFFFFF", 0.2)
    pole = line([(hx + 1, hy), (hx + 1, 40)], 3.5)
    ic.shadow(pole, 3, 2, 2, 0.3)
    ic.fill(pole, lgrad(["#FFFFFF", "#C9CFDA"], hx - 1, 0, hx + 3, 0))
    flag = poly([(hx + 3, 40)] + bezier((hx + 3, 40), (hx + 22, 44), (hx + 34, 46), (hx + 48, 52)) +
                bezier((hx + 48, 52), (hx + 34, 60), (hx + 22, 62), (hx + 3, 68)))
    ic.shadow(flag, 1.5, 3, 3, 0.3)
    ic.fill(flag, lgrad([lighten(P["flag"], 0.2), darken(P["flag"], 0.2)], hx, 40, hx + 48, 68))
    # ball and its path
    for i in range(6):
        t = i / 6
        ic.fill(circle(56 + t * 44, 210 - t * 34, 2.2), "#FFFFFF", 0.35 + 0.4 * t)
    bx, by = 118, 170
    ic.fill(blur(ellipse(bx + 3, by + 11, 13, 4), 2), "#000000", 0.35)
    sphere(ic, bx, by, 13, "#F4F6FA", 0.0, 0.9)
    for (dx, dy) in ((-4, -2), (3, -5), (5, 3), (-2, 5), (-7, 4), (8, -1)):
        ic.fill(circle(bx + dx, by + dy, 1.4), "#000000", 0.12)


@motif
def tanks(ic):
    P = ic.P
    back = poly([(L - 5, 150)] + bezier((L - 5, 150), (90, 110), (160, 150), (R + 5, 120)) + [(R + 5, B + 5), (L - 5, B + 5)])
    ic.fill(back, darken(P["hill2"], 0.1), 0.85)
    front = poly([(L - 5, 170)] + bezier((L - 5, 170), (60, 146), (110, 150), (140, 186)) +
                 bezier((140, 186), (170, 214), (190, 170), (R + 5, 160)) + [(R + 5, B + 5), (L - 5, B + 5)])
    front = sub(front, circle(200, 160, 16))
    ic.fill(front, vgrad(P["hill"], darken(P["hill"], 0.45), 146, B))
    ic.fill(np.clip(front - shift(front, 0, 2.5), 0, 1), lighten(P["hill"], 0.4), 0.8)
    # trajectory and shell
    path = bezier((98, 120), (130, 40), (170, 50), (200, 150))
    for i in range(3, len(path) - 4, 4):
        ic.fill(circle(*path[i], 2.2), "#FFFFFF", 0.75)
    sx, sy = path[22]
    ic.add(blur(circle(sx, sy, 6), 4), P["blast"], 0.8)
    ic.fill(circle(sx, sy, 4.5), "#FFFFFF")
    # explosion where it lands
    ex, ey = 200, 152
    ic.add(blur(circle(ex, ey, 22), 10), P["blast"], 0.9)
    ic.fill(star(ex, ey, 22, 11, 9, -12), lighten(P["blast"], 0.3))
    ic.fill(star(ex, ey, 12, 6, 7, 10), "#FFFFFF", 0.9)
    for (dx, dy, r) in ((-20, -18, 3.5), (18, -24, 3), (26, -6, 2.5)):
        ic.fill(circle(ex + dx, ey + dy, r), darken(P["hill"], 0.3))
    # the tank, sitting on the slope
    cx, cy, a = 74, 140, -8
    barrel = line(rotate([(cx + 6, cy - 16), (cx + 34, cy - 40)], a, cx, cy), 6.5)
    treads = rrect(cx - 32, cy - 6, cx + 32, cy + 10, 8, a, (cx, cy))
    hull = poly(rotate([(cx - 28, cy - 6), (cx - 22, cy - 18), (cx + 24, cy - 18), (cx + 30, cy - 6)], a, cx, cy))
    turret = U(ellipse(cx + 1, cy - 18, 15, 11, a), rrect(cx - 14, cy - 20, cx + 16, cy - 17, 0, a, (cx, cy)))
    allm = U(barrel, treads, hull, turret)
    ic.shadow(allm, 2, 5, 5, 0.4)
    ic.fill(barrel, lgrad([lighten(P["tank"], 0.1), darken(P["tank"], 0.3)], 0, cy - 44, 0, cy - 14))
    ic.fill(treads, "#23252E")
    for k in range(-2, 3):
        wx, wy = rotate([(cx + k * 12, cy + 2)], a, cx, cy)[0]
        ic.fill(circle(wx, wy, 5), "#5C6273")
        ic.fill(circle(wx, wy, 2), "#2B2E37")
    ic.fill(hull, lgrad([lighten(P["tank"], 0.25), P["tank"], darken(P["tank"], 0.25)], 0, cy - 20, 0, cy - 4))
    ic.fill(turret, rgrad([lighten(P["tank"], 0.35), P["tank"], darken(P["tank"], 0.2)], cx - 5, cy - 26, 20))
    ic.rim(U(hull, turret), 1.4, 0.5)


@motif
def towerdefense(ic):
    P = ic.P
    path = bezier((L - 10, 190), (90, 230), (110, 120), (170, 150)) + bezier((170, 150), (230, 180), (230, 80), (R + 10, 70))[1:]
    road = line(path, 30)
    ic.fill(road, vgrad(lighten(P["path"], 0.15), P["path"], 60, 230))
    ic.fill(np.clip(road - shift(road, 0, 2), 0, 1), darken(P["path"], 0.25), 0.5)
    for i, c in ((14, P["enemy"]), (52, P["enemy2"]), (70, P["enemy"])):
        x, y = path[i]
        m = U(ellipse(x, y - 5, 11, 10), ellipse(x, y + 1, 13, 6))
        ic.shadow(m, 1, 3, 3, 0.35)
        ic.fill(m, rgrad([lighten(c, 0.35), c, darken(c, 0.3)], x - 3, y - 9, 14))
        ic.fill(circle(x - 4, y - 6, 2.4), "#FFFFFF")
        ic.fill(circle(x + 4, y - 6, 2.4), "#FFFFFF")
        ic.fill(circle(x - 3.5, y - 5.5, 1.2), "#1B1E2B")
        ic.fill(circle(x + 4.5, y - 5.5, 1.2), "#1B1E2B")
    # the tower
    tx, top, bot, w = 104, 84, 176, 58
    bodym = U(rrect(tx - w / 2, top, tx + w / 2, bot, 0), ellipse(tx, bot, w / 2, 10))
    ic.shadow(bodym, 3, 6, 7, 0.45)
    ic.fill(bodym, lgrad([lighten(P["stone"], 0.25), P["stone"], darken(P["stone"], 0.4)], tx - w / 2, 0, tx + w / 2, 0))
    joints = np.zeros((N, N), np.float32)
    for k, yy in enumerate(range(top + 14, bot, 14)):
        joints = U(joints, arc(tx, yy, w / 2, 0, 180, 1.2, False, ry=8))
        for xx in ((-14, 6, 22) if k % 2 else (-22, -4, 14)):
            joints = U(joints, line([(tx + xx, yy - 6 + 8 * (abs(xx) / (w / 2)) ** 2 * 0.5), (tx + xx, yy + 8)], 1.2, False))
    ic.fill(joints * bodym, darken(P["stone"], 0.5), 0.5)
    ic.fill(ellipse(tx, top, w / 2, 10), lighten(P["stone"], 0.1))
    merl = np.zeros((N, N), np.float32)
    for k in range(5):
        xx = tx - w / 2 + 3 + k * (w - 6) / 4
        merl = U(merl, rrect(xx - 6, top - 14, xx + 6, top + 6, 2))
    ic.fill(merl, lgrad([lighten(P["stone"], 0.3), darken(P["stone"], 0.3)], tx - w / 2, 0, tx + w / 2, 0))
    ic.rim(merl, 1.2, 0.4)
    ic.fill(rrect(tx - 7, 120, tx + 7, 142, 7), darken(P["stone"], 0.65))
    # crystal on top and its bolt
    cx_, cy_ = tx, top - 30
    gem = poly([(cx_, cy_ - 20), (cx_ + 12, cy_), (cx_, cy_ + 14), (cx_ - 12, cy_)])
    ic.add(blur(gem, 8), P["crystal"], 0.8)
    ic.fill(gem, lgrad([lighten(P["crystal"], 0.5), P["crystal"], darken(P["crystal"], 0.3)], cx_ - 12, cy_ - 20,
                       cx_ + 12, cy_ + 14))
    ic.fill(poly([(cx_, cy_ - 20), (cx_, cy_ + 14), (cx_ - 12, cy_)]), "#FFFFFF", 0.25)
    tx2, ty2 = path[52]
    bolt = line([(cx_ + 6, cy_ - 2), (150, 80), (144, 100), (tx2, ty2 - 12)], 3.5)
    ic.add(blur(bolt, 3), P["crystal"], 0.9)
    ic.fill(bolt, "#FFFFFF")


@motif
def hangman(ic):
    P = ic.P
    wood = U(rrect(40, 150, 140, 162, 4), rrect(62, 44, 74, 156, 3), rrect(62, 44, 158, 56, 3),
             line([(70, 82), (100, 52)], 8))
    ic.shadow(wood, 2, 6, 6, 0.4)
    ic.fill(wood, lgrad([lighten(P["wood"], 0.2), P["wood"], darken(P["wood"], 0.3)], 40, 44, 160, 162))
    ic.rim(wood, 1.4, 0.45)
    rope = line([(150, 56), (150, 84)], 3)
    loop = ring(150, 96, 11, 3.2)
    ic.shadow(U(rope, loop), 1, 3, 3, 0.3)
    ic.fill(U(rope, loop), P["rope"])
    # letter tiles: one found, two still blank
    tiles = [(44, None), (100, "A"), (156, None)]
    for (x, ch) in tiles:
        m = rrect(x, 172, x + 48, 216, 9)
        ic.shadow(m, 1.5, 4, 4, 0.4)
        ic.fill(m, vgrad(lighten(P["tile"], 0.15), darken(P["tile"], 0.08), 172, 216))
        ic.rim(m, 1.5, 0.7, dark=0.15)
        if ch:
            g = text(ch, "sans", 34, x + 24, 195)
            ic.fill(g, P["letter"])
        else:
            ic.fill(rrect(x + 12, 202, x + 36, 206, 2), P["letter"], 0.45)
    # the one letter answered in the round lies on the third row
    ic.add(sparkle(196, 70, 12), "#FFFFFF", 0.9)
    ic.add(sparkle(214, 100, 7), "#FFFFFF", 0.7)


@motif
def wordtiles(ic):
    P = ic.P

    def tile(cx, cy, s, ang, color, ch=None, letter="#FFFFFF"):
        m = box(cx, cy, s, s, s * 0.2, ang)
        ic.shadow(m, 2, 6, 6, 0.4)
        ic.fill(m, lgrad([lighten(color, 0.2), color, darken(color, 0.2)], cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2))
        ic.rim(m, 1.6, 0.55, dark=0.18)
        if ch:
            g = text(ch, "sans", s * 0.62, cx, cy - s * 0.02, ang)
            ic.shadow(g, 1, 2.5, 2, 0.35)
            ic.fill(g, letter)
        return m

    tile(62, 92, 52, -14, P["t2"])
    tile(196, 92, 52, 14, P["t3"])
    tile(86, 170, 52, -6, P["t3"])
    tile(172, 170, 52, 6, P["t2"])
    tile(128, 120, 100, 0, P["t1"], "Ğ", P["letter"])
    ic.add(sparkle(196, 46, 12), "#FFFFFF", 0.9)
    ic.add(sparkle(52, 140, 8), "#FFFFFF", 0.7)
