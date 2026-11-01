"""Game icons: action."""
import math

import numpy as np

from iconkit import (B, L, N, R, T, U, X, Y, bezier, blur, circle, col, darken, ellipse, lgrad, lighten, line, polar,
                     poly, rgrad, ring, rotate, rrect, shift, smoothstep, sparkle, star, sub, vgrad, arc)
from motifs_common import cloud, motif, pixels


def rock(cx, cy, r, seed, bumps=0.13):
    rng = np.random.default_rng(seed)
    ph = rng.uniform(0, 6.28, 3)
    pts = []
    for i in range(72):
        a = 2 * math.pi * i / 72
        k = 1 + bumps * math.sin(3 * a + ph[0]) + bumps * 0.6 * math.sin(5 * a + ph[1]) + 0.05 * math.sin(9 * a + ph[2])
        pts.append((cx + r * k * math.cos(a), cy + r * k * math.sin(a)))
    return poly(pts)


def crater(ic, x, y, rx, ry, base):
    ic.fill(ellipse(x, y, rx, ry), darken(base, 0.35))
    ic.fill(sub(ellipse(x, y, rx, ry), ellipse(x - rx * 0.25, y - ry * 0.3, rx, ry)), lighten(base, 0.25), 0.8)


@motif
def asteroids(ic):
    P = ic.P
    rk = rock(150, 104, 54, 3)
    ic.shadow(rk, 3, 7, 7, 0.5)
    ic.fill(rk, rgrad([lighten(P["rock"], 0.25), P["rock"], darken(P["rock"], 0.55)], 128, 80, 90))
    for (x, y, rx, ry) in ((132, 86, 12, 9), (170, 118, 15, 11), (150, 136, 7, 5), (176, 80, 6, 5), (120, 118, 6, 5)):
        crater(ic, x, y, rx, ry, P["rock"])
    small = rock(70, 66, 15, 8, 0.18)
    ic.shadow(small, 2, 4, 4, 0.4)
    ic.fill(small, rgrad([lighten(P["rock"], 0.15), darken(P["rock"], 0.4)], 64, 60, 22))
    beam = line([(98, 170), (128, 132)], 4.5)
    ic.add(blur(beam, 3), P["laser"], 0.9)
    ic.fill(beam, "#FFFFFF", 0.95)
    ic.add(blur(circle(130, 130, 9), 4), P["laser"], 1.0)
    ic.add(sparkle(130, 130, 16, 15), "#FFFFFF", 0.95)
    ang = -52
    sx, sy = 82, 190
    pts = rotate([(sx + 26, sy), (sx - 18, sy - 18), (sx - 9, sy), (sx - 18, sy + 18)], ang, sx, sy)
    flame = poly(rotate([(sx - 10, sy - 7), (sx - 36, sy), (sx - 10, sy + 7)], ang, sx, sy))
    ic.add(blur(flame, 3), P["flame"], 1.0)
    ic.fill(flame, lighten(P["flame"], 0.4), 0.9)
    ship = poly(pts)
    ic.solid(ship, P["ship"], 0.45, (2, 5, 5), 0.3, 0.3, 0.7, 0.2)
    ic.fill(poly(rotate([(sx + 12, sy), (sx - 2, sy - 5), (sx - 2, sy + 5)], ang, sx, sy)), P["laser"], 0.9)


@motif
def froggy(ic):
    P = ic.P
    river = (Y < 98).astype(np.float32)
    ic.fill(river, vgrad(lighten(P["river"], 0.15), P["river"], T, 98))
    for (y, x0, x1) in ((40, 150, 196), (88, 60, 92), (84, 170, 214)):
        ic.fill(line([(x0, y), (x1, y)], 2.5), "#FFFFFF", 0.35)
    log = rrect(36, 50, 156, 78, 14)
    ic.shadow(log, 1, 3, 3, 0.35)
    ic.body(log, P["log"], 0.18, 0.25)
    for x in (70, 104, 130):
        ic.fill(line([(x, 55), (x + 6, 73)], 1.5), darken(P["log"], 0.35), 0.5)
    ic.fill(ellipse(156, 64, 8, 14), lighten(P["log"], 0.3))
    ic.fill(ring(156, 64, 5, 1.5), darken(P["log"], 0.2), 0.7)
    grass = ((Y >= 98) & (Y < 150)).astype(np.float32)
    ic.fill(grass, vgrad(P["grass"], darken(P["grass"], 0.18), 98, 150))
    ic.fill(((Y >= 98) & (Y < 101)).astype(np.float32), lighten(P["grass"], 0.35), 0.7)
    road = (Y >= 150).astype(np.float32)
    ic.fill(road, vgrad(P["road"], darken(P["road"], 0.25), 150, B))
    ic.fill(((Y >= 150) & (Y < 154)).astype(np.float32), "#000000", 0.25)
    for x in range(20, 240, 40):
        ic.fill(rrect(x, 188, x + 22, 194, 2), "#FFE066", 0.9)
    car = rrect(168, 200, 238, 226, 9)
    ic.shadow(car, 1, 3, 3, 0.3)
    ic.body(car, P["car"], 0.25, 0.2)
    ic.fill(rrect(184, 204, 206, 222, 4), darken(P["car"], 0.45), 0.8)
    fx, fy = 120, 132
    legs = U(ellipse(fx - 40, fy + 22, 18, 10, -20), ellipse(fx + 40, fy + 22, 18, 10, 20))
    bodym = U(ellipse(fx, fy + 6, 42, 32), legs)
    eyes = U(circle(fx - 22, fy - 24, 15), circle(fx + 22, fy - 24, 15))
    allm = U(bodym, eyes)
    ic.shadow(allm, 2, 6, 6, 0.4)
    ic.fill(allm, rgrad([lighten(P["frog"], 0.3), P["frog"], darken(P["frog"], 0.35)], fx - 10, fy - 20, 70))
    ic.fill(ellipse(fx, fy + 16, 26, 16), lighten(P["frog"], 0.55), 0.7)
    for ex in (fx - 22, fx + 22):
        ic.fill(circle(ex, fy - 25, 10), "#FFFFFF")
        ic.fill(circle(ex + 2, fy - 24, 5.5), "#15202B")
        ic.fill(circle(ex, fy - 27, 2), "#FFFFFF")
    ic.fill(arc(fx, fy - 2, 20, 25, 155, 3.5), darken(P["frog"], 0.55))
    ic.fill(circle(fx - 24, fy + 2, 5), P["blush"], 0.55)
    ic.fill(circle(fx + 24, fy + 2, 5), P["blush"], 0.55)
    ic.rim(allm, 1.6, 0.4)


ALIEN = ["....GGGGG....",
         "..GGGGGGGGG..",
         ".GGGGGGGGGGG.",
         "GGGGWWWWWGGGG",
         "GGGWWWKKWWGGG",
         "GGGWWWKKWWGGG",
         "GGGGWWWWWGGGG",
         ".GGGGGGGGGGG.",
         ".G.GG.G.GG.G.",
         "G..G..G..G..G"]


@motif
def invaders(ic):
    P = ic.P
    ic.glow(rrect(66, 44, 190, 134, 20), 16, P["alien"], 0.25)
    pixels(ic, ALIEN, 69.5, 46, 9, {"G": P["alien"], "W": "#FFFFFF", "K": P["eye"]}, gap=1.0, shadow=0.45)
    beam = rrect(125, 150, 131, 176, 3)
    ic.add(blur(beam, 4), P["laser"], 0.9)
    ic.fill(beam, "#FFFFFF")
    base = U(rrect(98, 196, 158, 214, 6), rrect(112, 186, 144, 200, 5), rrect(123, 176, 133, 192, 3))
    ic.solid(base, P["cannon"], 0.45, (2, 4, 4), 0.35, 0.25, 0.6, 0.15)
    for x0 in (44, 176):
        sh = sub(rrect(x0, 166, x0 + 36, 190, 10), rrect(x0 + 10, 180, x0 + 26, 194, 6))
        ic.solid(sh, P["shield"], 0.3, (1, 3, 3), 0.2, 0.2, 0.4, 0.1)


def meteor_streak(ic, x, y, r, length, ang, core, glow):
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)  # direction of travel
    px_, py_ = -uy, ux
    tail = poly([(x + px_ * r, y + py_ * r), (x - ux * length, y - uy * length), (x - px_ * r, y - py_ * r)])
    along = ((X - x) * -ux + (Y - y) * -uy) / length
    fade = np.clip(1 - along, 0, 1) ** 1.6
    ic.add(blur(tail, 2) * fade, glow, 0.9)
    ic.add(blur(line([(x, y), (x - ux * length * 0.7, y - uy * length * 0.7)], r * 0.6), 1) * fade, "#FFFFFF", 0.5)
    ic.add(blur(circle(x, y, r * 1.6), r * 0.8), glow, 0.8)
    ic.fill(circle(x, y, r), rgrad([lighten(core, 0.7), core, darken(core, 0.2)], x - r * 0.3, y - r * 0.3, r * 1.3))


@motif
def meteor(ic):
    P = ic.P
    hills = poly([(L, 196)] + bezier((L, 196), (80, 170), (130, 200), (170, 184)) +
                 bezier((170, 184), (200, 172), (220, 180), (R, 176)) + [(R, B), (L, B)])
    ic.fill(hills, vgrad(P["hills"], darken(P["hills"], 0.4), 170, B))
    ic.fill(np.clip(hills - shift(hills, 0, 2), 0, 1), lighten(P["glow"], 0.2), 0.6)
    meteor_streak(ic, 172, 64, 4, 50, 130, P["core"], P["glow"])
    meteor_streak(ic, 70, 92, 3.5, 40, 130, P["core"], P["glow"])
    meteor_streak(ic, 118, 138, 13, 120, 130, P["core"], P["glow"])
    st = star(186, 132, 14, 6.5, 5, -80)
    ic.glow(st, 5, P["star"], 0.6)
    ic.solid(st, P["star"], 0.3, (1, 3, 3), 0.3, 0.2, 0.6, 0.1)


@motif
def missile(ic):
    P = ic.P
    for (x0, y0, x1, y1) in ((60, T, 96, 120), (200, T, 150, 96), (130, T + 6, 182, 150)):
        ic.fill(line([(x0, y0), (x1, y1)], 2.4), P["trail"], 0.55)
        ic.add(blur(circle(x1, y1, 3), 2), P["warhead"], 1.0)
        ic.fill(circle(x1, y1, 2.6), "#FFFFFF")
    for (x1, y1) in ((92, 108), (150, 82)):
        ic.fill(line([(128, 192), (x1, y1)], 2), P["counter"], 0.6)
    for (x, y, r) in ((150, 82, 30), (92, 108, 20)):
        ic.add(blur(circle(x, y, r * 1.2), r * 0.4), P["blast"], 0.8)
        ic.fill(circle(x, y, r), rgrad([(0, "#FFFFFF"), (0.45, lighten(P["blast"], 0.5)), (1, P["blast"])], x, y, r))
        ic.fill(ring(x, y, r * 0.78, 1.5), "#FFFFFF", 0.5)
    city = np.zeros((N, N), np.float32)
    bldg = [(30, 170), (48, 150), (64, 176), (80, 160), (98, 182), (158, 176), (172, 152), (190, 168), (206, 146),
            (222, 172)]
    for (x, h) in bldg:
        city = U(city, rrect(x, h, x + 18, B + 4, 1.5))
    ic.fill(city, vgrad(P["city"], darken(P["city"], 0.35), 146, B))
    win = np.zeros((N, N), np.float32)
    rng = np.random.default_rng(4)
    for (x, h) in bldg:
        for yy in range(int(h) + 6, 220, 9):
            for xx in (x + 4, x + 11):
                if rng.random() < 0.55:
                    win = U(win, rrect(xx, yy, xx + 3.5, yy + 4, 0.5))
    ic.fill(win * city, P["windows"], 0.9)
    dome = U(ellipse(128, 200, 26, 18), rrect(102, 198, 154, B + 4, 2))
    ic.solid(dome, P["battery"], 0.4, (1, -3, 4), 0.3, 0.2, 0.5, 0.0)
    ic.fill(line([(128, 194), (140, 178)], 6), darken(P["battery"], 0.2))


@motif
def spacearena(ic):
    P = ic.P
    cx, cy = 128, 124
    ic.add(blur(ring(cx, cy, 78, 4), 4), P["ring"], 0.7)
    ic.fill(ring(cx, cy, 78, 3), lighten(P["ring"], 0.4))
    ic.fill(ring(cx, cy, 54, 1.2), P["ring"], 0.35)
    ic.fill(ring(cx, cy, 30, 1.0), P["ring"], 0.25)
    for a in (-30, 95, 200):
        x, y = polar(cx, cy, 78, a)
        e = poly([(x, y - 10), (x + 10, y), (x, y + 10), (x - 10, y)])
        ic.add(blur(e, 4), P["enemy"], 0.8)
        ic.solid(e, P["enemy"], 0.3, (1, 3, 3), 0.4, 0.2, 0.5, 0.1)
    for off in (-7, 7):
        p0 = rotate([(cx + 30, cy + off)], -40, cx, cy)[0]
        p1 = rotate([(cx + 58, cy + off)], -40, cx, cy)[0]
        sm = line([p0, p1], 4)
        ic.add(blur(sm, 3), P["shot"], 0.9)
        ic.fill(sm, "#FFFFFF")
    ang = -40
    pts = rotate([(cx + 26, cy), (cx - 16, cy - 22), (cx - 8, cy - 7), (cx - 18, cy), (cx - 8, cy + 7),
                  (cx - 16, cy + 22)], ang, cx, cy)
    ship = poly(pts)
    fl = poly(rotate([(cx - 14, cy - 5), (cx - 34, cy), (cx - 14, cy + 5)], ang, cx, cy))
    ic.add(blur(fl, 3), P["flame"], 1.0)
    ic.solid(ship, P["ship"], 0.5, (2, 5, 5), 0.35, 0.3, 0.7, 0.2)
    ic.fill(poly(rotate([(cx + 12, cy), (cx - 2, cy - 6), (cx - 2, cy + 6)], ang, cx, cy)), P["cockpit"])
