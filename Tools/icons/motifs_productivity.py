"""App icons: productivity."""
import math

import numpy as np

from iconkit import (B, L, N, R, T, U, X, Y, arc, bezier, blur, box, circle, col, darken, ellipse, heart_pts, lgrad,
                     lighten, line, polar, poly, rgrad, ring, rotate, rrect, shift, smoothstep, sparkle, star, sub,
                     text, vgrad)
from motifs_common import check, clock_face, cloud, coin, motif, paper, pencil, sphere


def drip(x0, x1, y, depth, n, seed=1):
    """A frosting edge: a band from y down with rounded drips."""
    rng = np.random.default_rng(seed)
    m = rrect(x0, y - 4, x1, y + depth * 0.4, 4)
    for i in range(n):
        x = x0 + (x1 - x0) * (i + 0.5) / n
        d = depth * rng.uniform(0.5, 1.0)
        m = U(m, rrect(x - 6, y, x + 6, y + d, 6))
    return m


@motif
def birthdays(ic):
    P = ic.P
    plate = ellipse(128, 202, 84, 14)
    ic.shadow(plate, 1, 4, 5, 0.35)
    ic.fill(plate, lgrad(["#FFFFFF", "#D5DAE6"], 0, 188, 0, 216))
    t1 = U(rrect(58, 140, 198, 200, 10), ellipse(128, 200, 70, 8))
    ic.shadow(t1, 1, 3, 4, 0.3)
    ic.fill(t1, lgrad([darken(P["cake"], 0.15), lighten(P["cake"], 0.15), darken(P["cake"], 0.2)], 58, 0, 198, 0))
    fr1 = drip(58, 198, 142, 22, 7, 3)
    ic.fill(fr1, lgrad([lighten(P["icing"], 0.2), P["icing"]], 0, 138, 0, 166))
    ic.rim(fr1, 1.2, 0.6)
    t2 = rrect(84, 98, 172, 146, 10)
    ic.shadow(t2, 1, 4, 4, 0.35)
    ic.fill(t2, lgrad([darken(P["cake2"], 0.15), lighten(P["cake2"], 0.15), darken(P["cake2"], 0.2)], 84, 0, 172, 0))
    fr2 = drip(84, 172, 100, 18, 5, 7)
    ic.fill(fr2, lgrad([lighten(P["icing2"], 0.2), P["icing2"]], 0, 96, 0, 120))
    ic.rim(fr2, 1.2, 0.6)
    rng = np.random.default_rng(5)
    sp = [P["s1"], P["s2"], P["s3"]]
    for i in range(16):
        x, y = rng.uniform(66, 190), rng.uniform(172, 194)
        if i >= 9:
            x, y = rng.uniform(92, 164), rng.uniform(124, 140)
        ic.fill(box(x, y, 7, 2.6, 1.3, rng.uniform(0, 180)), sp[i % 3])
    cnd = rrect(122, 62, 134, 100, 3)
    ic.shadow(cnd, 1, 2, 2, 0.3)
    ic.fill(cnd, lgrad(["#FFFFFF", "#DDE2EE"], 122, 0, 134, 0))
    for y in (68, 80, 92):
        ic.fill(poly([(122, y), (134, y - 5), (134, y), (122, y + 5)]) * cnd, P["s1"])
    fl = poly([(128, 34)] + bezier((128, 34), (140, 48), (138, 60), (128, 60)) + bezier((128, 60), (118, 60), (116, 48), (128, 34)))
    ic.add(blur(circle(128, 50, 10), 8), P["flame"], 0.8)
    ic.fill(fl, rgrad(["#FFFFFF", P["flame"]], 128, 54, 14))


@motif
def breathe(ic):
    P = ic.P
    cx, cy = 128, 120
    for r, op in ((92, 0.12), (72, 0.2), (54, 0.3)):
        ic.fill(circle(cx, cy, r), "#FFFFFF", op)
        ic.fill(ring(cx, cy, r, 1.6), "#FFFFFF", 0.35)
    orb = circle(cx, cy, 36)
    ic.add(blur(orb, 12), P["orb"], 0.6)
    ic.fill(orb, rgrad([lighten(P["orb"], 0.75), lighten(P["orb"], 0.2), P["orb"]], cx - 10, cy - 12, 44))
    ic.rim(orb, 1.4, 0.5)
    swirl = bezier((42, 176), (92, 196), (150, 172), (176, 150)) + bezier((176, 150), (196, 132), (186, 110), (170, 116))[1:] + \
        bezier((170, 116), (160, 120), (162, 134), (174, 132))[1:]
    sw = line(swirl, 6)
    ic.shadow(sw, 1, 3, 3, 0.25)
    ic.fill(sw, "#FFFFFF", 0.95)
    sw2 = line(bezier((60, 204), (110, 214), (160, 202), (200, 186)), 4)
    ic.fill(sw2, "#FFFFFF", 0.7)
    leaf = poly(rotate(bezier((0, 0), (10, -14), (30, -14), (40, 0)) + bezier((40, 0), (30, 14), (10, 14), (0, 0))[1:],
                       -40, 0, 0))
    leaf = poly([(x + 150, y + 82) for x, y in rotate(bezier((0, 0), (10, -14), (30, -14), (40, 0)) +
                                                     bezier((40, 0), (30, 14), (10, 14), (0, 0))[1:], -40, 0, 0)])
    ic.shadow(leaf, 1, 3, 3, 0.3)
    ic.fill(leaf, lgrad([lighten(P["leaf"], 0.2), darken(P["leaf"], 0.2)], 150, 82, 180, 56))
    ic.fill(line(rotate([(150, 82), (184, 82)], -40, 150, 82), 1.4), darken(P["leaf"], 0.35), 0.6)


@motif
def budget(ic):
    P = ic.P
    note = box(116, 86, 108, 56, 5, -8)
    ic.shadow(note, 1, 3, 4, 0.3)
    ic.fill(note, lgrad([lighten(P["note"], 0.2), darken(P["note"], 0.15)], 60, 60, 170, 110))
    ic.fill(np.clip(box(116, 86, 96, 44, 4, -8) - box(116, 86, 92, 40, 3, -8), 0, 1), "#FFFFFF", 0.5)
    ic.fill(ellipse(116, 86, 12, 12), lighten(P["note"], 0.35))
    card = box(156, 92, 78, 50, 6, 10)
    ic.shadow(card, 1, 3, 4, 0.3)
    ic.fill(card, lgrad([lighten(P["card"], 0.25), darken(P["card"], 0.15)], 120, 70, 196, 120))
    ic.fill(box(140, 92, 16, 12, 2, 10), "#FFE7A3")
    wal = rrect(48, 104, 208, 204, 18)
    ic.shadow(wal, 2, 7, 7, 0.45)
    ic.fill(wal, lgrad([lighten(P["wallet"], 0.2), P["wallet"], darken(P["wallet"], 0.3)], 0, 104, 0, 204))
    ic.fill(np.clip(rrect(54, 110, 202, 198, 14) - rrect(55.5, 111.5, 200.5, 196.5, 13), 0, 1), "#FFFFFF", 0.25)
    flap = rrect(150, 132, 218, 178, 14)
    ic.shadow(flap, 1.5, 3, 4, 0.35)
    ic.fill(flap, lgrad([lighten(P["wallet"], 0.3), darken(P["wallet"], 0.15)], 0, 132, 0, 178))
    ic.fill(circle(182, 155, 8), lgrad(["#FFF3C4", "#C99A2E"], 174, 147, 190, 163))
    ic.rim(wal, 1.6, 0.4)
    coin(ic, 78, 186, 24, P["coin"], 0.12, "star", 0.4)


@motif
def examcount(ic):
    P = ic.P
    sheet = box(108, 118, 120, 156, 10, -6)
    paper(ic, sheet)
    for i in range(4):
        y = 66 + i * 30
        for j in range(4):
            x = 66 + j * 22
            px_, py_ = rotate([(x, y)], -6, 108, 118)[0]
            filled = (i, j) in ((0, 1), (1, 3), (2, 0), (3, 2))
            ic.fill(circle(px_, py_, 7.5), P["bubble"] if filled else "#D5DBE7")
            if not filled:
                ic.fill(circle(px_, py_, 5.5), "#FFFFFF")
    sx, sy, r = 168, 162, 40
    btn = rrect(sx - 7, sy - r - 14, sx + 7, sy - r + 2, 3)
    ic.shadow(btn, 1, 3, 3, 0.3)
    ic.fill(btn, lgrad(["#E8ECF3", "#9AA3B5"], sx - 7, 0, sx + 7, 0))
    ic.fill(rrect(sx - 10, sy - r - 18, sx + 10, sy - r - 10, 3), P["watch"])
    clock_face(ic, sx, sy, r, "#FFFFFF", P["watch"], "#262B3A", P["hand"], 12.0, 4.2, True, 0.45, sec=False)


@motif
def flashcards(ic):
    P = ic.P

    def card(cx, cy, ang, color, lines=True):
        m = box(cx, cy, 136, 96, 10, ang)
        ic.shadow(m, 2, 6, 6, 0.38)
        ic.fill(m, lgrad([lighten(color, 0.15), darken(color, 0.08)], cx - 60, cy - 50, cx + 60, cy + 50))
        if lines:
            lm = np.zeros((N, N), np.float32)
            for k in range(3):
                y = cy - 18 + k * 18
                lm = U(lm, line(rotate([(cx - 54, y), (cx + 54, y)], ang, cx, cy), 1.4, False))
            ic.fill(lm * m, P["rule"], 0.6)
            ic.fill(line(rotate([(cx - 54, cy - 32), (cx + 54, cy - 32)], ang, cx, cy), 1.8, False) * m, P["red"], 0.7)
        ic.rim(m, 1.4, 0.6)
        return m

    card(120, 84, -12, P["c1"])
    card(138, 114, 7, P["c2"])
    front = card(124, 152, -3, "#FFFFFF", False)
    q = text("?", "sans", 76, 124, 152, -3)
    ic.shadow(q, 1, 3, 2.5, 0.25)
    ic.fill(q, lgrad([lighten(P["q"], 0.2), darken(P["q"], 0.2)], 100, 120, 150, 190))


@motif
def habits(ic):
    P = ic.P
    pot = poly([(84, 148), (172, 148), (162, 212), (94, 212)])
    rimm = rrect(76, 136, 180, 156, 6)
    stem = line(bezier((128, 140), (126, 112), (130, 92), (128, 70)), 6)
    l1 = poly([(x + 128, y + 104) for x, y in rotate(bezier((0, 0), (14, -20), (40, -20), (56, 0)) +
                                                     bezier((56, 0), (40, 16), (14, 16), (0, 0))[1:], -30, 0, 0)])
    l2 = poly([(128 - x, y + 88) for x, y in rotate(bezier((0, 0), (12, -18), (34, -18), (48, 0)) +
                                                   bezier((48, 0), (34, 14), (12, 14), (0, 0))[1:], -36, 0, 0)])
    ic.shadow(U(stem, l1, l2), 1.5, 4, 4, 0.3)
    ic.fill(stem, darken(P["leaf"], 0.15))
    for lf in (l1, l2):
        ic.fill(lf, lgrad([lighten(P["leaf"], 0.3), P["leaf"], darken(P["leaf"], 0.25)], 80, 60, 190, 120))
        ic.rim(lf, 1.2, 0.4)
    bud = circle(128, 66, 9)
    ic.fill(bud, rgrad([lighten(P["leaf"], 0.5), P["leaf"]], 125, 62, 11))
    ic.shadow(U(pot, rimm), 2, 6, 6, 0.4)
    ic.fill(pot, lgrad([lighten(P["pot"], 0.2), P["pot"], darken(P["pot"], 0.3)], 84, 0, 172, 0))
    ic.fill(rimm, lgrad([lighten(P["pot"], 0.35), darken(P["pot"], 0.1)], 0, 136, 0, 156))
    ic.rim(rimm, 1.4, 0.5)
    for i, x in enumerate((106, 128, 150)):
        ic.fill(circle(x, 182, 6), "#FFFFFF", 0.9 if i < 2 else 0.35)
    bx, by = 186, 70
    badge = circle(bx, by, 24)
    ic.shadow(badge, 1.5, 4, 4, 0.35)
    ic.fill(badge, rgrad([lighten(P["badge"], 0.3), P["badge"]], bx - 6, by - 8, 28))
    ic.fill(check(bx, by + 1, 24, 6.5), "#FFFFFF")


@motif
def interval(ic):
    P = ic.P
    cx, cy = 128, 124
    for i in range(10):
        a0 = -90 + i * 36 + 4
        seg = arc(cx, cy, 82, a0, a0 + 28, 12, True)
        on = i < 6
        if on:
            ic.add(blur(seg, 4), P["ring"], 0.35)
        ic.fill(seg, P["ring"] if on else "#FFFFFF", 1.0 if on else 0.22)
    ang = -35
    bar = box(cx, cy, 118, 12, 6, ang)
    plates = []
    for side in (-1, 1):
        for k, (off, w, h) in enumerate(((44, 14, 70), (60, 12, 54))):
            px_, py_ = rotate([(cx + side * off, cy)], ang, cx, cy)[0]
            plates.append((box(px_, py_, w, h, 5, ang), k))
    allm = U(bar, *[p for p, _ in plates])
    ic.shadow(allm, 2, 7, 7, 0.45)
    ic.fill(bar, lgrad(["#F2F4F8", "#8D95A8", "#D9DEE8"], 0, cy - 30, 0, cy + 30))
    for (m, k) in plates:
        c = P["plate"] if k == 0 else P["plate2"]
        ic.fill(m, lgrad([lighten(c, 0.25), c, darken(c, 0.3)], cx - 80, cy - 60, cx + 80, cy + 60))
        ic.rim(m, 1.3, 0.45)


@motif
def journal(ic):
    P = ic.P
    ang = -6
    cx, cy = 120, 128
    pages = box(cx + 6, cy + 4, 128, 160, 10, ang)
    cover = box(cx, cy, 128, 160, 12, ang)
    ic.shadow(U(pages, cover), 2, 8, 8, 0.45)
    ic.fill(pages, lgrad(["#FFF8EA", "#E9DCC2"], cx, 50, cx + 70, 200))
    pl = np.zeros((N, N), np.float32)
    for k in range(6):
        pl = U(pl, line(rotate([(cx + 64, cy - 70 + k * 28), (cx + 70, cy - 70 + k * 28)], ang, cx, cy), 0.8, False))
    ic.fill(pl * pages, "#C9B48F", 0.6)
    ic.fill(cover, lgrad([lighten(P["cover"], 0.2), P["cover"], darken(P["cover"], 0.3)], cx - 64, cy - 80, cx + 64, cy + 80))
    ic.fill(np.clip(box(cx, cy, 116, 148, 9, ang) - box(cx, cy, 113, 145, 8, ang), 0, 1), "#FFFFFF", 0.18)
    ic.rim(cover, 1.6, 0.4)
    emb = box(cx - 4, cy - 30, 54, 30, 6, ang)
    ic.fill(emb, darken(P["cover"], 0.2), 0.6)
    ic.inner(emb, 1.5, 0, 1.5, 0.4)
    band = box(cx + 44, cy, 9, 164, 2, ang)
    ic.shadow(band, 1, 2, 2, 0.3)
    ic.fill(band, lgrad([darken(P["band"], 0.1), lighten(P["band"], 0.2), darken(P["band"], 0.3)], cx + 38, 0, cx + 50, 0))
    rib = poly(rotate([(cx - 20, cy + 76), (cx - 8, cy + 76), (cx - 8, cy + 104), (cx - 14, cy + 98), (cx - 20, cy + 104)], ang, cx, cy))
    ic.fill(rib, lgrad([lighten(P["ribbon"], 0.2), darken(P["ribbon"], 0.2)], 0, cy + 76, 0, cy + 104))
    pen = line([(196, 60), (226, 196)], 11)
    ic.shadow(pen, 2, 5, 5, 0.4)
    ic.fill(pen, lgrad(["#3A3F50", "#14161E", "#4A5066"], 190, 0, 230, 0))
    ic.fill(line([(196, 60), (200, 78)], 11), lgrad([lighten(P["gold"], 0.3), darken(P["gold"], 0.2)], 190, 0, 206, 0))
    ic.fill(line([(203, 66), (210, 100)], 2.6), P["gold"])


@motif
def kanban(ic):
    P = ic.P
    lanes = [(40, P["c1"]), (100, P["c2"]), (160, P["c3"])]
    for (x, _) in lanes:
        ic.fill(rrect(x, 46, x + 56, 212, 12), "#FFFFFF", 0.18)
    cards = {0: [62, 104, 146], 1: [62, 104], 2: [62]}
    for i, (x, c) in enumerate(lanes):
        ic.fill(rrect(x + 10, 52, x + 46, 57, 2.5), "#FFFFFF", 0.7)
        for y in cards[i]:
            m = rrect(x + 5, y, x + 51, y + 34, 7)
            ic.shadow(m, 1, 3, 3, 0.3)
            ic.fill(m, vgrad("#FFFFFF", "#EEF1F6", y, y + 34))
            ic.fill(rrect(x + 5, y, x + 51, y + 8, 7) * m, c)
            ic.fill(rrect(x + 11, y + 16, x + 43, y + 20, 2), "#C3CAD8")
            ic.fill(rrect(x + 11, y + 24, x + 33, y + 28, 2), "#C3CAD8")
    m = box(150, 150, 54, 38, 8, 9)
    ic.shadow(m, 4, 12, 9, 0.45)
    ic.fill(m, vgrad("#FFFFFF", "#EEF1F6", 130, 170))
    top = poly(rotate([(123, 131), (177, 131), (177, 139), (123, 139)], 9, 150, 150)) * m
    ic.fill(top, P["c2"])
    ic.fill(box(146, 152, 32, 4, 2, 9), "#C3CAD8")
    ic.fill(box(140, 160, 22, 4, 2, 9), "#C3CAD8")
    cur = poly([(170, 160), (170, 186), (176, 180), (182, 192), (187, 190), (181, 178), (189, 177)])
    ic.shadow(cur, 1, 3, 2, 0.4)
    ic.fill(cur, "#FFFFFF")
    ic.fill(np.clip(cur - poly([(171.5, 163), (171.5, 182), (176, 177.5), (182, 189), (185, 188), (179, 176.5), (185.5, 176)]), 0, 1), "#1E2433")


def face(ic, cx, cy, r, color, mood, blush):
    m = circle(cx, cy, r)
    ic.shadow(m, 2, 6, 6, 0.38)
    ic.fill(m, rgrad([lighten(color, 0.4), color, darken(color, 0.25)], cx - r * 0.3, cy - r * 0.4, r * 1.4))
    ink = darken(color, 0.72)
    if mood == "happy":
        for ex in (cx - r * 0.34, cx + r * 0.34):
            ic.fill(arc(ex, cy - r * 0.1, r * 0.14, 200, 340, r * 0.08), ink)
        ic.fill(poly([(cx - r * 0.42, cy + r * 0.12)] + bezier((cx - r * 0.42, cy + r * 0.12), (cx - r * 0.3, cy + r * 0.62),
                                                                   (cx + r * 0.3, cy + r * 0.62), (cx + r * 0.42, cy + r * 0.12))), ink)
        ic.fill(ellipse(cx, cy + r * 0.38, r * 0.18, r * 0.09), "#FF6B81", 0.9)
        for ex in (cx - r * 0.58, cx + r * 0.58):
            ic.fill(ellipse(ex, cy + r * 0.18, r * 0.14, r * 0.09), blush, 0.55)
    else:
        for ex in (cx - r * 0.32, cx + r * 0.32):
            ic.fill(circle(ex, cy - r * 0.1, r * 0.09), ink)
        ic.fill(arc(cx, cy + r * 0.55, r * 0.28, 220, 320, r * 0.08), ink)
    ic.fill(blur(ellipse(cx - r * 0.38, cy - r * 0.5, r * 0.22, r * 0.12, -30), 1), "#FFFFFF", 0.5)
    return m


@motif
def mood(ic):
    P = ic.P
    face(ic, 84, 84, 40, P["sad"], "meh", P["blush"])
    face(ic, 146, 146, 64, P["happy"], "happy", P["blush"])
    h = poly(heart_pts(196, 70, 16))
    ic.shadow(h, 1, 3, 3, 0.3)
    ic.fill(h, rgrad([lighten(P["heart"], 0.35), P["heart"]], 190, 64, 20))


@motif
def pomodoro(ic):
    P = ic.P
    cx, cy = 128, 134
    body = U(ellipse(cx, cy, 80, 68), ellipse(cx - 30, cy + 6, 48, 58), ellipse(cx + 30, cy + 6, 48, 58))
    ic.shadow(body, 2, 8, 8, 0.4)
    ic.fill(body, rgrad([lighten(P["tomato"], 0.35), P["tomato"], darken(P["tomato"], 0.35)], cx - 26, cy - 30, 100))
    ic.fill(np.clip(ellipse(cx - 26, cy + 8, 30, 52) - ellipse(cx - 22, cy + 8, 30, 52), 0, 1) * body, darken(P["tomato"], 0.3), 0.35)
    ic.fill(np.clip(ellipse(cx + 26, cy + 8, 30, 52) - ellipse(cx + 22, cy + 8, 30, 52), 0, 1) * body, darken(P["tomato"], 0.3), 0.35)
    ic.fill(blur(ellipse(cx - 34, cy - 34, 18, 10, -25), 2) * body, "#FFFFFF", 0.55)
    # timer ticks and pointer
    tm = np.zeros((N, N), np.float32)
    for k in range(13):
        a = math.radians(200 + k * 11.7)
        r0, r1 = (54, 66) if k % 3 == 0 else (58, 66)
        tm = U(tm, line([(cx + r0 * math.cos(a), cy + 20 + r0 * math.sin(a) * 0.7),
                         (cx + r1 * math.cos(a), cy + 20 + r1 * math.sin(a) * 0.7)], 3))
    ic.fill(tm * body, "#FFFFFF", 0.85)
    ic.fill(poly([(cx - 6, cy + 24), (cx + 6, cy + 24), (cx, cy - 6)]), "#FFFFFF", 0.95)
    leaves = star(cx, cy - 64, 32, 10, 5, -90)
    ic.shadow(leaves, 1, 3, 3, 0.35)
    ic.fill(leaves, lgrad([lighten(P["leaf"], 0.25), darken(P["leaf"], 0.2)], cx - 30, cy - 90, cx + 30, cy - 40))
    ic.fill(line([(cx, cy - 66), (cx + 4, cy - 90)], 7), darken(P["leaf"], 0.15))
    ic.rim(leaves, 1.2, 0.4)


@motif
def reading(ic):
    P = ic.P

    def book(cx, y, w, h, color, ang):
        cover = box(cx, y, w, h, 4, ang)
        pages = box(cx + 2, y + 1, w - 10, h - 6, 2, ang)
        ic.shadow(cover, 1.5, 4, 4, 0.35)
        ic.fill(cover, lgrad([lighten(color, 0.25), color, darken(color, 0.25)], cx - w / 2, y - h / 2, cx + w / 2, y + h / 2))
        pr = box(cx + w / 2 - 4, y + 1, 6, h - 6, 1, ang)
        ic.fill(pr * cover, "#FFF6E5")
        pl = np.zeros((N, N), np.float32)
        for k in range(3):
            pl = U(pl, line(rotate([(cx + w / 2 - 7, y - h / 2 + 5 + k * (h - 10) / 2), (cx + w / 2 - 1, y - h / 2 + 5 + k * (h - 10) / 2)], ang, cx, y), 0.7, False))
        ic.fill(pl * pr, "#C9B48F", 0.7)
        ic.fill(box(cx - w / 2 + 14, y, 5, h, 0, ang) * cover, lighten(color, 0.4), 0.5)
        ic.rim(cover, 1.3, 0.45)

    book(124, 190, 150, 30, P["b1"], 1)
    book(132, 160, 132, 28, P["b2"], -3)
    book(120, 131, 120, 26, P["b3"], 2)
    # open book on top
    ox, oy = 128, 92
    lp = poly(bezier((ox, oy + 8), (ox - 20, oy - 4), (ox - 46, oy - 4), (ox - 64, oy + 2)) + [(ox - 60, oy + 26)] +
              bezier((ox - 60, oy + 26), (ox - 40, oy + 20), (ox - 18, oy + 22), (ox, oy + 32))[1:])
    rp = poly(bezier((ox, oy + 8), (ox + 20, oy - 4), (ox + 46, oy - 4), (ox + 64, oy + 2)) + [(ox + 60, oy + 26)] +
              bezier((ox + 60, oy + 26), (ox + 40, oy + 20), (ox + 18, oy + 22), (ox, oy + 32))[1:])
    cov = poly([(ox - 68, oy + 4), (ox, oy + 12), (ox + 68, oy + 4), (ox + 64, oy + 30), (ox, oy + 38), (ox - 64, oy + 30)])
    ic.shadow(U(lp, rp, cov), 1.5, 4, 4, 0.35)
    ic.fill(cov, darken(P["b4"], 0.1))
    ic.fill(lp, lgrad(["#FFFFFF", "#EADFC8"], ox - 60, 0, ox, 0))
    ic.fill(rp, lgrad(["#EADFC8", "#FFFFFF"], ox, 0, ox + 60, 0))
    rib = poly([(ox + 24, oy + 26), (ox + 32, oy + 26), (ox + 32, oy + 52), (ox + 28, oy + 47), (ox + 24, oy + 52)])
    ic.fill(rib, P["ribbon"])
    st = star(186, 56, 15, 7)
    ic.shadow(st, 1, 3, 3, 0.3)
    ic.fill(st, lgrad([lighten(P["star"], 0.3), darken(P["star"], 0.1)], 171, 41, 201, 71))


@motif
def shopping(ic):
    P = ic.P
    # what pokes out of the bag
    bag_top = 96
    bread = box(102, 74, 26, 92, 13, -22)
    ic.shadow(bread, 1, 3, 3, 0.3)
    ic.fill(bread, lgrad([lighten(P["bread"], 0.25), darken(P["bread"], 0.2)], 80, 30, 130, 120))
    for k in range(3):
        y = 50 + k * 18
        ic.fill(line(rotate([(96, y), (110, y - 6)], -22, 102, 74), 3), lighten(P["bread"], 0.45), 0.8)
    for (x, y, r) in ((150, 82, 20), (170, 90, 16), (134, 92, 15)):
        ic.fill(circle(x, y, r), lgrad([lighten(P["greens"], 0.25), darken(P["greens"], 0.2)], x - r, y - r, x + r, y + r))
    ic.fill(line(bezier((150, 92), (150, 80), (156, 72), (160, 66)), 2), darken(P["greens"], 0.4), 0.6)
    sphere(ic, 182, 100, 18, P["apple"], 0.3, 0.8)
    ic.fill(line([(182, 84), (186, 74)], 3), "#6B3F1D")
    bag = poly([(56, bag_top), (200, bag_top), (192, 214), (64, 214)])
    ic.shadow(bag, 2, 7, 7, 0.45)
    ic.fill(bag, lgrad([lighten(P["bag"], 0.15), P["bag"], darken(P["bag"], 0.2)], 56, 0, 200, 0))
    ic.fill(rrect(54, bag_top, 202, bag_top + 16, 3), lgrad([lighten(P["bag"], 0.3), darken(P["bag"], 0.05)], 0, bag_top, 0, bag_top + 16))
    for x in (92, 164):
        ic.fill(np.clip(ellipse(x, bag_top + 30, 13, 10) - ellipse(x, bag_top + 30, 9, 6.5), 0, 1), darken(P["bag"], 0.45))
    tag = box(128, 168, 70, 50, 8, -4)
    ic.shadow(tag, 1, 3, 3, 0.3)
    ic.fill(tag, "#FFFFFF")
    for k in range(3):
        y = 154 + k * 14
        cx_, cy_ = rotate([(104, y)], -4, 128, 168)[0]
        if k < 2:
            ic.fill(check(cx_, cy_, 10, 3), P["check"])
        else:
            ic.fill(ring(cx_, cy_, 4.2, 1.6), "#B8C0CF")
        ic.fill(line(rotate([(116, y), (154 - k * 8, y)], -4, 128, 168), 3.5), "#C9D0DD")


@motif
def sleep(ic):
    P = ic.P
    cl = cloud(126, 170, 150)
    moon = sub(circle(120, 108, 52), circle(146, 88, 46))
    ic.add(blur(circle(116, 112, 50), 14), P["moon"], 0.3)
    ic.shadow(moon, 2, 6, 6, 0.4)
    ic.fill(moon, rgrad([lighten(P["moon"], 0.5), P["moon"], darken(P["moon"], 0.2)], 90, 100, 70))
    ic.fill(arc(96, 118, 6, 20, 160, 2.6), darken(P["moon"], 0.5))
    ic.fill(circle(86, 132, 5), "#FF9AA2", 0.5)
    ic.shadow(cl, 1, 4, 5, 0.3)
    ic.fill(cl, vgrad("#FFFFFF", lighten(P["cloud"], 0.1), 140, 200))
    ic.rim(cl, 1.2, 0.6)
    for (x, y, r) in ((186, 66, 9), (204, 108, 6), (166, 40, 5), (60, 56, 5)):
        ic.add(star(x, y, r, r * 0.45), P["star"], 0.95)


@motif
def todo(ic):
    P = ic.P
    cardm = box(118, 130, 136, 160, 14, -4)
    paper(ic, cardm, shadow=0.4)
    for i in range(3):
        y = 82 + i * 46
        cx_, cy_ = rotate([(76, y)], -4, 118, 130)[0]
        done = i < 2
        if done:
            ic.fill(circle(cx_, cy_, 13), lgrad([lighten(P["check"], 0.2), darken(P["check"], 0.1)], cx_, cy_ - 13, cx_, cy_ + 13))
            ic.fill(check(cx_, cy_ + 1, 13, 3.6), "#FFFFFF")
        else:
            ic.fill(ring(cx_, cy_, 11, 3), "#B8C0CF")
        l1 = line(rotate([(98, y - 5), (162, y - 5)], -4, 118, 130), 6)
        l2 = line(rotate([(98, y + 7), (140, y + 7)], -4, 118, 130), 5)
        ic.fill(U(l1, l2), "#CBD2DE" if done else "#9AA4B8")
    bx, by = 186, 186
    badge = circle(bx, by, 30)
    ic.shadow(badge, 2, 5, 5, 0.4)
    ic.fill(badge, rgrad([lighten(P["badge"], 0.3), P["badge"], darken(P["badge"], 0.15)], bx - 8, by - 10, 36))
    ic.fill(check(bx, by + 2, 30, 8), "#FFFFFF")


def keycap(ic, cx, cy, s, color, ch=None, ink="#FFFFFF", pressed=False):
    skirt = rrect(cx - s / 2, cy - s / 2, cx + s / 2, cy + s / 2 + (4 if pressed else 9), s * 0.18)
    top = rrect(cx - s / 2 + 6, cy - s / 2 + (6 if pressed else 2), cx + s / 2 - 6, cy + s / 2 - 8 + (5 if pressed else 0), s * 0.14)
    ic.shadow(skirt, 2, 6, 6, 0.45)
    ic.fill(skirt, lgrad([darken(color, 0.15), darken(color, 0.45)], 0, cy - s / 2, 0, cy + s / 2 + 9))
    ic.fill(top, lgrad([lighten(color, 0.25), color], 0, cy - s / 2, 0, cy + s / 2))
    ic.rim(top, 1.4, 0.5)
    if ch:
        g = text(ch, "sans", s * 0.46, cx, cy - (0 if pressed else 3))
        ic.fill(g, ink)


@motif
def typing(ic):
    P = ic.P
    keycap(ic, 76, 78, 58, P["k2"])
    keycap(ic, 182, 82, 58, P["k2"])
    keycap(ic, 64, 172, 58, P["k2"])
    ic.add(blur(rrect(84, 84, 172, 172, 18), 12), P["glow"], 0.55)
    keycap(ic, 128, 126, 88, P["k1"], "A", "#FFFFFF", True)
    for (y, x0, x1) in ((186, 170, 212), (200, 180, 220), (214, 168, 200)):
        ic.fill(line([(x0, y), (x1, y)], 4), "#FFFFFF", 0.55)


@motif
def water(ic):
    P = ic.P
    glass = poly([(70, 76), (186, 76), (170, 212), (86, 212)])
    ic.shadow(glass, 2, 7, 7, 0.35)
    ic.fill(glass, "#FFFFFF", 0.28)
    lvl = 118
    xs = np.linspace(60, 196, 60)
    wpts = [(x, lvl + 4 * math.sin(x / 11.0)) for x in xs] + [(196, 230), (60, 230)]
    wat = poly(wpts) * glass
    ic.fill(wat, lgrad([lighten(P["water"], 0.25), P["water"], darken(P["water"], 0.25)], 0, lvl, 0, 212))
    ic.fill(np.clip(wat - shift(wat, 0, 3), 0, 1), "#FFFFFF", 0.7)
    for (x, y, r) in ((104, 176, 5), (140, 160, 4), (120, 192, 3), (150, 186, 6), (98, 146, 3)):
        ic.fill(ring(x, y, r, 1.4), "#FFFFFF", 0.7)
    ic.fill(np.clip(glass - shift(glass, 3, 0), 0, 1), "#FFFFFF", 0.8)
    ic.fill(np.clip(glass - shift(glass, -3, 0), 0, 1), "#FFFFFF", 0.4)
    ic.fill(poly([(80, 84), (88, 84), (100, 200), (94, 200)]), "#FFFFFF", 0.35)
    ic.fill(np.clip(ellipse(128, 76, 58, 6) - ellipse(128, 77.5, 56, 5), 0, 1), "#FFFFFF", 0.8)
    dx, dy = 182, 54
    dropm = poly(bezier((dx, dy - 30), (dx + 6, dy - 16), (dx + 20, dy - 4), (dx + 20, dy + 8)) +
                 bezier((dx + 20, dy + 8), (dx + 20, dy + 20), (dx + 10, dy + 28), (dx, dy + 28))[1:] +
                 bezier((dx, dy + 28), (dx - 10, dy + 28), (dx - 20, dy + 20), (dx - 20, dy + 8))[1:] +
                 bezier((dx - 20, dy + 8), (dx - 20, dy - 4), (dx - 6, dy - 16), (dx, dy - 30))[1:])
    ic.shadow(dropm, 1.5, 5, 5, 0.35)
    ic.fill(dropm, rgrad([lighten(P["drop"], 0.5), P["drop"], darken(P["drop"], 0.25)], dx - 6, dy, 30))
    ic.fill(blur(ellipse(dx - 8, dy + 6, 4, 8, 20), 0.8), "#FFFFFF", 0.8)
