"""Icons of the Nexvyn OS 1.1 flagship games: Photon Garden, Banners of Aldmoor, Void Delve, Lanternfall, Turbo Isles."""
import math

import numpy as np

from iconkit import (B, CX, CY, L, N, R, T, U, X, Y, arc, blur, circle, col, darken, ellipse, ellipse_pts, lgrad,
                     lighten, line, mix, poly, polar, rgrad, ring, rotate, rrect, shift, smoothstep, sparkle, star,
                     star_pts, sub, vgrad)
from motifs_common import motif, sphere


def _beam(ic, pts, color, w=7.0):
    """A glowing beam along a polyline: wide soft halo, coloured body, white-hot core."""
    m = line(pts, w)
    ic.add(blur(line(pts, w * 2.4), w * 1.6), color, 0.55)
    ic.fill(m, color, 0.9)
    ic.add(line(pts, w * 0.38), "#FFFFFF", 0.95)


# ------------------------------------------------------------------------------------------------- Photon Garden
@motif
def photongarden(ic):
    P = ic.P
    # a mirror on the left catches the beam and sends it up into a crystal flower
    ic.add(blur(circle(150, 104, 58), 28), P["bloom"], 0.35)
    _beam(ic, [(L - 6, 178), (86, 178)], P["beam"], 8)
    _beam(ic, [(86, 178), (150, 114)], P["beam"], 8)
    # mirror: a silver bar on a stand, tilted 45 degrees
    mir = poly(rotate([(62, 172), (110, 172), (110, 184), (62, 184)], -45, 86, 178))
    ic.shadow(mir, 2, 5, 4, 0.45)
    ic.fill(mir, lgrad([lighten(P["mirror"], 0.4), P["mirror"], darken(P["mirror"], 0.35)], 64, 150, 110, 200))
    ic.rim(mir, 1.4, 0.7)
    ic.fill(line([(92, 214), (86, 186)], 5), darken(P["stem"], 0.25))
    # flower: crystal petals around a glowing heart
    cx, cy = 150, 104
    for i in range(6):
        a = i * 60 - 90
        px, py = polar(cx, cy, 30, a)
        pet = poly(rotate(ellipse_pts(px, py, 22, 12), a, px, py))
        ic.fill(pet, rgrad([lighten(P["petal"], 0.55), P["petal"], darken(P["petal"], 0.3)], px - 6, py - 8, 26))
        ic.rim(pet, 1.2, 0.5)
    ic.add(blur(circle(cx, cy, 16), 8), "#FFFFFF", 0.6)
    sphere(ic, cx, cy, 15, P["heart"], shadow=0.0, spec=0.9)
    # stem and leaves
    stem = line([(150, 132), (156, 170), (150, 214)], 7)
    ic.fill(stem, lgrad([lighten(P["stem"], 0.2), darken(P["stem"], 0.3)], 140, 0, 160, 0))
    leaf = poly(rotate(ellipse_pts(172, 176, 20, 8), -30, 172, 176))
    ic.fill(leaf, lgrad([lighten(P["stem"], 0.35), darken(P["stem"], 0.2)], 160, 166, 186, 186))
    leaf2 = poly(rotate(ellipse_pts(134, 188, 16, 7), 25, 134, 188))
    ic.fill(leaf2, lgrad([lighten(P["stem"], 0.3), darken(P["stem"], 0.25)], 120, 180, 150, 196))
    for (x, y, r) in ((190, 64, 7), (204, 92, 4.5), (112, 60, 5), (196, 140, 4)):
        ic.add(blur(sparkle(x, y, r), 0.6), "#FFFFFF", 0.9)


# ------------------------------------------------------------------------------------------------- Turbo Isles
@motif
def turboisles(ic):
    P = ic.P
    # sunset sun over the sea, an island with a palm, a road sweeping in from the bottom
    ic.add(blur(circle(170, 92, 34), 18), P["sun"], 0.5)
    ic.fill(circle(170, 92, 26), lgrad([lighten(P["sun"], 0.3), P["sun"]], 170, 66, 170, 118))
    sea = poly([(L - 4, 128), (R + 4, 128), (R + 4, B + 4), (L - 4, B + 4)])
    ic.fill(sea, vgrad(P["sea"], darken(P["sea"], 0.45), 128, B))
    for y in (136, 146, 158):
        ic.fill(line([(150, y), (196, y)], 1.6), "#FFFFFF", 0.35)
    isle = U(ellipse(64, 132, 46, 12), ellipse(52, 128, 22, 9))
    ic.fill(isle, darken(P["isle"], 0.1))
    trunk = line([(60, 128), (58, 104), (62, 84)], 4)
    ic.fill(trunk, "#7A5636")
    for a in (-160, -120, -60, -20, 20):
        lx, ly = polar(62, 84, 20, a)
        ic.fill(poly(rotate(ellipse_pts((62 + lx) / 2, (84 + ly) / 2, 12, 3.5), a, (62 + lx) / 2, (84 + ly) / 2)), P["isle"])
    road = poly([(L - 6, 236), (96, 150), (124, 150), (R + 6, 236)])
    ic.fill(road, lgrad([P["road"], darken(P["road"], 0.35)], 0, 150, 0, 230))
    for k in range(4):
        t0, t1 = 0.18 + k * 0.22, 0.28 + k * 0.22
        ic.fill(line([(110 - 6 * t0, 150 + 86 * t0), (110 - 6 * t1, 150 + 86 * t1)], 2 + 5 * t1, False), "#FFFFFF", 0.8)
    # the car, slightly sideways (drifting), seen from behind
    cx, cy = 128, 182
    body = poly(rotate([(84, 196), (88, 172), (106, 160), (150, 160), (168, 172), (172, 196)], -8, cx, cy))
    ic.shadow(body, 2, 8, 6, 0.5)
    ic.fill(body, lgrad([lighten(P["car"], 0.35), P["car"], darken(P["car"], 0.35)], 0, 158, 0, 198))
    win = poly(rotate([(102, 172), (110, 162), (146, 162), (154, 172)], -8, cx, cy))
    ic.fill(win, lgrad([lighten(P["glass"], 0.3), P["glass"]], 0, 162, 0, 172))
    spoil = poly(rotate([(84, 166), (172, 166), (170, 158), (86, 158)], -8, cx, cy))
    ic.fill(spoil, darken(P["car"], 0.45))
    for lx in (98, 158):
        x, y = rotate([(lx, 184)], -8, cx, cy)[0]
        ic.add(blur(ellipse(x, y, 9, 5), 3), "#FF2E4F", 0.9)
        ic.fill(ellipse(x, y, 7, 3.5), "#FF6070")
    for wx in (90, 166):
        x, y = rotate([(wx, 198)], -8, cx, cy)[0]
        ic.fill(rrect(x - 8, y - 9, x + 8, y + 9, 3), "#16171C")
    # boost flames and drift sparks
    for fx in (114, 142):
        x, y = rotate([(fx, 200)], -8, cx, cy)[0]
        fl = poly([(x - 5, y), (x + 5, y), (x + 1, y + 26)])
        ic.add(blur(fl, 4), P["flame"], 0.9)
        ic.fill(poly([(x - 3, y), (x + 3, y), (x, y + 14)]), "#FFFFFF", 0.9)
    for (x, y, r) in ((70, 214, 4), (60, 204, 3), (78, 222, 2.5), (186, 212, 3)):
        ic.add(blur(sparkle(x, y, r * 1.6), 0.5), P["spark"], 1.0)


# ------------------------------------------------------------------------------------------------- Void Delve
@motif
def voiddelve(ic):
    P = ic.P
    cx, cy = 150, 98
    # the void: glowing rings spiralling into a black core
    for k in range(6):
        r = 18 + k * 13
        ic.add(blur(ring(cx, cy, r, 2.4), 1.2), P["ring"] if k % 2 == 0 else P["ring2"], 0.55 - k * 0.06)
    for k in range(10):
        a = k * 36
        x0, y0 = polar(cx, cy, 22, a)
        x1, y1 = polar(cx, cy, 86, a + 50)
        ic.add(blur(line([(x0, y0), ((x0 + x1) / 2 + 6, (y0 + y1) / 2 - 6), (x1, y1)], 2), 1.0), P["ring"], 0.35)
    ic.fill(circle(cx, cy, 16), "#05040C")
    ic.fill(ring(cx, cy, 16, 2), "#FFFFFF", 0.8)
    # enemy bullets coming out of the void
    for (x, y, r) in ((112, 70, 6), (190, 132, 5), (124, 128, 5.5), (200, 74, 4.5)):
        ic.add(blur(circle(x, y, r * 2), r), P["bullet"], 0.6)
        ic.fill(circle(x, y, r), P["bullet"])
        ic.fill(circle(x, y, r * 0.45), "#FFFFFF")
    # the ship, bottom left, firing a stream into the void
    sx, sy, ang = 82, 176, -42
    shots = [polar(sx, sy, d, ang) for d in (36, 52, 68)]
    for (x, y) in shots:
        ic.add(blur(circle(x, y, 7), 4), P["ship"], 0.7)
        ic.fill(circle(x, y, 3.4), "#FFFFFF")
    pts = rotate([(sx + 26, sy), (sx - 16, sy - 18), (sx - 8, sy), (sx - 16, sy + 18)], ang, sx, sy)
    ship = poly(pts)
    ic.glow(ship, 8, P["ship"], 0.7)
    ic.shadow(ship, 1.5, 4, 4, 0.4)
    ic.fill(ship, lgrad(["#FFFFFF", "#CFEFFF"], sx - 10, sy - 18, sx + 20, sy + 18))
    ic.fill(line(pts + [pts[0]], 2.4) * blur(ship, 0.1), P["ship"])
    ic.add(blur(circle(*polar(sx, sy, 18, ang + 180), 7), 3), "#FF8A1A", 0.9)


# ------------------------------------------------------------------------------------------------- Lanternfall
@motif
def lanternfall(ic):
    P = ic.P
    # distant hills, a mossy ledge, a hooded traveller raising a glowing lantern, fireflies
    ic.fill(U(circle(60, 214, 70), circle(190, 220, 80)), P["hill"], 0.9)
    ledge = rrect(L - 10, 176, 170, B + 10, 14)
    ic.shadow(ledge, 1.5, 4, 5, 0.4)
    ic.fill(ledge, vgrad(P["earth"], darken(P["earth"], 0.4), 176, B))
    ic.fill(rrect(L - 10, 172, 172, 184, 6), P["moss"])
    for x in range(36, 168, 9):
        ic.fill(line([(x, 176), (x + 2, 168 - (x % 5))], 2.2), lighten(P["moss"], 0.25))
    lx, ly = 150, 92
    ic.add(blur(circle(lx, ly, 46), 26), P["glow"], 0.75)
    ic.add(blur(circle(lx, ly, 18), 8), "#FFFFFF", 0.5)
    # the traveller
    cx = 96
    cloak = poly([(cx - 26, 174), (cx + 22, 174), (cx + 12, 118), (cx - 12, 118)])
    ic.shadow(cloak, 2, 5, 5, 0.4)
    ic.fill(cloak, lgrad([lighten(P["cloak"], 0.2), darken(P["cloak"], 0.3)], cx - 20, 118, cx + 20, 174))
    hood = circle(cx, 112, 19)
    ic.fill(hood, rgrad([lighten(P["cloak"], 0.3), P["cloak"], darken(P["cloak"], 0.3)], cx - 6, 104, 24))
    ic.fill(circle(cx + 6, 114, 12), P["face"])
    ic.fill(circle(cx + 11, 112, 2.2), "#1A1020")
    # arm and pole to the lantern
    ic.fill(line([(cx + 10, 134), (cx + 30, 120), (lx - 6, ly + 10)], 6), darken(P["cloak"], 0.2))
    ic.fill(line([(lx - 6, ly + 10), (lx, ly - 12)], 3), "#5A4632")
    lamp = rrect(lx - 12, ly - 14, lx + 12, ly + 16, 6)
    ic.fill(lamp, rgrad(["#FFFFFF", P["glow"], darken(P["glow"], 0.2)], lx, ly, 18))
    ic.fill(rrect(lx - 14, ly - 20, lx + 14, ly - 12, 3), "#5A4632")
    ic.fill(rrect(lx - 14, ly + 14, lx + 14, ly + 20, 3), "#5A4632")
    for (x, y, r) in ((196, 66, 3), (212, 120, 2.5), (60, 70, 2.5), (178, 150, 2), (44, 120, 2)):
        ic.add(blur(circle(x, y, r * 2.5), r * 1.5), P["glow"], 0.8)
        ic.fill(circle(x, y, r * 0.8), "#FFF6D0")


# ------------------------------------------------------------------------------------------------- Banners of Aldmoor
@motif
def aldmoor(ic):
    P = ic.P
    # a castle on a hill at dusk with a blue banner and a shield with crossed spears in front
    ic.add(blur(circle(170, 84, 30), 16), P["sun"], 0.45)
    ic.fill(circle(170, 84, 18), P["sun"])
    ic.fill(circle(128, 300, 150), P["hill"])
    base = 172
    keep = U(rrect(84, base - 40, 172, base + 20, 2), rrect(80, base - 70, 102, base + 20, 2),
             rrect(154, base - 70, 176, base + 20, 2), rrect(116, base - 92, 140, base + 20, 2))
    ic.fill(keep, darken(P["hill"], 0.35))
    for x0 in (80, 154):
        ic.fill(poly([(x0 - 2, base - 70), (x0 + 11, base - 88), (x0 + 24, base - 70)]), darken(P["hill"], 0.15))
    ic.fill(poly([(114, base - 92), (128, base - 114), (142, base - 92)]), darken(P["hill"], 0.15))
    for (x, y) in ((88, base - 52), (162, base - 52), (124, base - 72), (106, base - 22), (146, base - 22)):
        ic.add(blur(rrect(x, y, x + 6, y + 9, 2), 1.5), P["sun"], 0.8)
    # banner on the tallest tower
    ic.fill(line([(128, base - 112), (128, base - 142)], 2.4), "#C9B48A")
    flag = poly([(128, base - 142), (162, base - 139), (156, base - 130), (162, base - 121), (128, base - 123)])
    ic.fill(flag, lgrad([lighten(P["banner"], 0.25), P["banner"], darken(P["banner"], 0.2)], 128, 0, 166, 0))
    ic.add(blur(flag, 2), P["banner"], 0.25)
    # shield and spears in front
    sx, sy = 128, 192
    for a in (-35, 35):
        x0, y0 = polar(sx, sy + 6, 52, 90 + a)
        x1, y1 = polar(sx, sy + 6, 52, -90 + a)
        ic.fill(line([(x0, y0), (x1, y1)], 4), "#8A6A45")
        tip = polar(x1, y1, 12, -90 + a)
        ic.fill(poly([polar(x1, y1, 5, a), tip, polar(x1, y1, 5, 180 + a)]), "#D8DEE9")
    shield = poly([(sx - 28, sy - 30), (sx + 28, sy - 30), (sx + 26, sy + 2), (sx, sy + 30), (sx - 26, sy + 2)])
    ic.shadow(shield, 2, 5, 5, 0.45)
    ic.fill(shield, lgrad([lighten(P["shield"], 0.3), P["shield"], darken(P["shield"], 0.3)], sx - 28, sy - 30, sx + 28, sy + 30))
    ic.rim(shield, 1.6, 0.6)
    inner = poly([(sx - 20, sy - 23), (sx + 20, sy - 23), (sx + 18, sy + 1), (sx, sy + 21), (sx - 18, sy + 1)])
    ic.fill(inner, P["banner"])
    ic.fill(star(sx, sy - 3, 11, 5), P["sun"])
