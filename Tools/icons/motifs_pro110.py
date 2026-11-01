"""App icons: the 1.1 programs (knowledge base, diagrams, tracker, regex, hex editor, logic, chords, recipes,
tournaments, calculation notepad)."""
import math

import numpy as np

from iconkit import (U, X, arc, bezier, blur, box, circle, darken, ellipse, lgrad, lighten, line, poly, rgrad, ring,
                     rrect, shift, sparkle, star, sub, text, vgrad)
from motifs_common import motif, paper


@motif
def linkwise(ic):
    P = ic.P
    nodes = [(70, 82, 15, P["n1"]), (178, 70, 13, P["n2"]), (128, 132, 24, P["hub"]), (72, 182, 13, P["n3"]),
             (186, 178, 16, P["n4"]), (128, 210, 9, P["n2"]), (206, 124, 9, P["n1"])]
    edges = [(0, 2), (1, 2), (3, 2), (4, 2), (5, 3), (5, 4), (6, 1), (6, 4), (0, 3)]
    for a, b in edges:
        x1, y1 = nodes[a][0], nodes[a][1]
        x2, y2 = nodes[b][0], nodes[b][1]
        ic.fill(line([(x1, y1), (x2, y2)], 4), "#FFFFFF", 0.55)
    ic.glow(circle(128, 132, 26), 14, P["hub"], 0.55)
    for x, y, r, c in nodes:
        m = circle(x, y, r)
        ic.shadow(m, 1, 3, 3, 0.35)
        ic.fill(m, rgrad([lighten(c, 0.45), c, darken(c, 0.2)], x - r * 0.35, y - r * 0.4, r * 1.4))
        ic.rim(m, 1.2, 0.5)
    # a tiny note glyph on the hub
    for i, yy in enumerate((123, 131, 139)):
        ic.fill(rrect(116, yy - 2, 140 - (8 if i == 2 else 0), yy + 2, 2), "#FFFFFF", 0.95)


@motif
def flowmap(ic):
    P = ic.P
    # arrows
    ic.fill(line([(128, 88), (128, 104)], 5), "#FFFFFF", 0.85)
    ic.fill(poly([(119, 102), (137, 102), (128, 112)]), "#FFFFFF", 0.85)
    ic.fill(line([(128, 160), (128, 172)], 5), "#FFFFFF", 0.85)
    ic.fill(poly([(119, 170), (137, 170), (128, 180)]), "#FFFFFF", 0.85)
    ic.fill(line([(164, 136), (190, 136), (190, 172)], 5), "#FFFFFF", 0.7)
    top = rrect(84, 46, 172, 88, 20)
    ic.solid(top, P["start"], shadow=0.35)
    dia = poly([(128, 110), (166, 136), (128, 162), (90, 136)])
    ic.solid(dia, P["decide"], shadow=0.35)
    bot = rrect(80, 180, 152, 214, 8)
    ic.solid(bot, P["step"], shadow=0.35)
    side = rrect(170, 172, 214, 206, 8)
    ic.solid(side, P["alt"], shadow=0.3)
    for y in (63, 71):
        ic.fill(rrect(104, y - 2, 152 - (10 if y == 71 else 0), y + 2, 2), "#FFFFFF", 0.9)
    ic.fill(text("?", "sans", 30, 128, 136), "#FFFFFF")
    ic.fill(rrect(94, 194, 138, 199, 2.5), "#FFFFFF", 0.9)


@motif
def chiptrack(ic):
    P = ic.P
    panel = rrect(40, 50, 216, 210, 16)
    ic.shadow(panel, 2, 6, 7, 0.4)
    ic.fill(panel, vgrad(P["panel"], darken(P["panel"], 0.25), 50, 210))
    ic.rim(panel, 1.4, 0.25)
    cols = [P["c1"], P["c2"], P["c3"], P["c4"]]
    rng = np.random.default_rng(7)
    for r in range(8):
        y = 66 + r * 17
        if r == 3:
            ic.fill(rrect(46, y - 3, 210, y + 12, 4), "#FFFFFF", 0.18)
        for c in range(4):
            x = 52 + c * 40
            if rng.random() < 0.62 or r == 3:
                ic.fill(rrect(x, y, x + 30, y + 9, 3), cols[c], 0.95 if r == 3 else 0.7)
    # square wave on top
    pts = [(30, 44), (60, 44), (60, 24), (100, 24), (100, 44), (140, 44), (140, 24), (180, 24), (180, 44), (226, 44)]
    wave = line(pts, 6)
    ic.glow(wave, 6, P["wave"], 0.5)
    ic.fill(wave, P["wave"])


@motif
def regexlab(ic):
    P = ic.P
    card = rrect(34, 62, 222, 194, 18)
    ic.shadow(card, 2, 6, 7, 0.4)
    ic.fill(card, vgrad(P["card"], darken(P["card"], 0.18), 62, 194))
    ic.rim(card, 1.4, 0.2)
    ic.fill(rrect(60, 96, 196, 150, 12), P["hl"], 0.9)
    ic.fill(text("/", "mono", 70, 52, 124), P["slash"])
    ic.fill(text("/", "mono", 70, 204, 124), P["slash"])
    ic.fill(text(".*", "mono", 64, 128, 118), "#FFFFFF")
    ic.fill(rrect(70, 170, 120, 178, 4), P["g1"])
    ic.fill(rrect(128, 170, 186, 178, 4), P["g2"])
    sp = sparkle(196, 70, 16)
    ic.glow(sp, 6, "#FFFFFF", 0.5)
    ic.fill(sp, "#FFFFFF")


@motif
def hexpad(ic):
    P = ic.P
    card = rrect(36, 48, 220, 208, 16)
    ic.shadow(card, 2, 6, 7, 0.4)
    ic.fill(card, vgrad(P["card"], darken(P["card"], 0.2), 48, 208))
    rows = [["4E", "58", "56"], ["00", "FF", "2A"], ["C0", "DE", "07"]]
    for r, row in enumerate(rows):
        for c, s in enumerate(row):
            cx, cy = 80 + c * 48, 86 + r * 42
            if (r, c) == (1, 1):
                m = rrect(cx - 22, cy - 17, cx + 22, cy + 17, 8)
                ic.glow(m, 8, P["cursor"], 0.45)
                ic.fill(m, P["cursor"])
                ic.fill(text(s, "mono", 28, cx, cy), "#FFFFFF")
            else:
                ic.fill(text(s, "mono", 26, cx, cy), P["digits"], 0.92 if r != 2 else 0.6)
    ic.fill(rrect(56, 188, 200, 194, 3), P["cursor"], 0.5)


@motif
def logiclab(ic):
    P = ic.P
    # wires
    ic.fill(line([(30, 104), (84, 104)], 7), P["on"])
    ic.fill(line([(30, 152), (84, 152)], 7), P["on"])
    ic.fill(line([(168, 128), (196, 128)], 7), P["on"])
    for y in (104, 152):
        ic.fill(circle(34, y, 8), P["on"])
    # AND gate: flat back, round front
    gate = U(rrect(80, 82, 126, 174, 4), circle(124, 128, 46) * (X >= 124))
    ic.solid(gate, P["gate"], shadow=0.4, gloss=0.25)
    ic.fill(text("&", "sans", 40, 116, 130), "#FFFFFF")
    # glowing LED
    led = circle(206, 128, 20)
    ic.glow(led, 16, P["led"], 0.8)
    ic.fill(led, rgrad(["#FFFFFF", lighten(P["led"], 0.2), P["led"]], 200, 120, 24))
    ic.fill(rrect(194, 148, 218, 158, 3), "#D8DCE6")


@motif
def chordbook(ic):
    P = ic.P
    board = rrect(58, 52, 186, 214, 14)
    ic.shadow(board, 2, 6, 7, 0.4)
    ic.fill(board, vgrad(P["wood"], darken(P["wood"], 0.25), 52, 214))
    ic.fill(rrect(66, 66, 178, 74, 3), "#F4EEE2")
    for i in range(6):
        x = 74 + i * 19.5
        ic.fill(line([(x, 70), (x, 204)], 2.2), "#E9E2D2", 0.9)
    for f in range(1, 5):
        y = 70 + f * 33
        ic.fill(line([(68, y), (176, y)], 2.5), "#C8B79A", 0.9)
    for s, f in ((1, 3), (2, 2), (4, 1)):
        cx, cy = 74 + s * 19.5, 70 + f * 33 - 16
        m = circle(cx, cy, 10)
        ic.shadow(m, 0.5, 2, 2, 0.3)
        ic.fill(m, P["dot"])
    # a music note
    note = U(circle(196, 178, 14), rrect(204, 96, 211, 178, 3), poly([(204, 96), (232, 112), (232, 126), (211, 112)]))
    ic.shadow(note, 1, 4, 4, 0.35)
    ic.fill(note, P["note"])
    ic.rim(note, 1.2, 0.4)


@motif
def recipebox(ic):
    P = ic.P
    # steam
    for x, ph in ((104, 0), (128, 1), (152, 0)):
        pts = [(x + 8 * math.sin(t / 7 + ph), 98 - t * 1.6) for t in range(0, 34, 2)]
        ic.fill(line(pts, 5), "#FFFFFF", 0.6)
    pot = U(rrect(62, 112, 194, 190, 20), rrect(52, 104, 204, 120, 8))
    ic.solid(pot, P["pot"], shadow=0.4, gloss=0.3)
    for x in (40, 196):
        ic.fill(rrect(x, 128, x + 20, 140, 6), darken(P["pot"], 0.25))
    ic.fill(rrect(114, 92, 142, 104, 6), darken(P["pot"], 0.2))
    heart = poly([(128, 176)] + bezier((128, 176), (96, 154), (104, 128), (128, 142)) + bezier((128, 142), (152, 128), (160, 154), (128, 176))[1:])
    ic.fill(heart, "#FFFFFF", 0.9)
    leaf = ellipse(196, 78, 18, 9, -35)
    ic.fill(leaf, P["leaf"])
    ic.fill(line([(186, 86), (206, 70)], 1.5), darken(P["leaf"], 0.3))


@motif
def bracket(ic):
    P = ic.P
    lw = 6
    ys = [62, 98, 158, 194]
    for y in ys:
        ic.fill(rrect(36, y - 10, 82, y + 10, 8), "#FFFFFF", 0.9)
    for a, b, mid in ((62, 98, 80), (158, 194, 176)):
        ic.fill(line([(82, a), (100, a), (100, b), (82, b)], lw, cap=False), "#FFFFFF", 0.85)
        ic.fill(line([(100, mid), (118, mid)], lw), "#FFFFFF", 0.85)
        ic.fill(rrect(118, mid - 10, 150, mid + 10, 8), P["semi"], 0.95)
    ic.fill(line([(150, 80), (162, 80), (162, 176), (150, 176)], lw, cap=False), "#FFFFFF", 0.85)
    ic.fill(line([(162, 128), (172, 128)], lw), "#FFFFFF", 0.85)
    # trophy
    cup = U(poly([(176, 92), (228, 92), (222, 124)] + bezier((222, 124), (218, 142), (186, 142), (182, 124))[1:]),
            rrect(197, 138, 207, 160, 2), rrect(184, 158, 220, 170, 4))
    handles = U(ring(178, 108, 10, 4) * 1.0, ring(226, 108, 10, 4) * 1.0)
    ic.fill(handles, darken(P["gold"], 0.1))
    ic.glow(cup, 10, P["gold"], 0.4)
    ic.solid(cup, P["gold"], shadow=0.35, gloss=0.35)
    st = star(202, 112, 9, 4)
    ic.fill(st, "#FFFFFF", 0.9)


@motif
def numbook(ic):
    P = ic.P
    pad = rrect(46, 40, 196, 216, 14)
    paper(ic, pad, top=P["paper"], bottom=darken(P["paper"], 0.08))
    ic.fill(rrect(46, 40, 196, 70, 14) * pad, P["top"])
    for i in range(4):
        y = 92 + i * 30
        ic.fill(rrect(60, y, 120 - (i % 2) * 18, y + 7, 3), "#B7BECC")
        ic.fill(rrect(144, y - 2, 184, y + 9, 4), P["res"], 0.85 if i < 3 else 0)
    ic.fill(rrect(60, 182, 184, 186, 2), P["res"], 0.5)
    ic.fill(text("=", "sans", 34, 132, 200), P["res"])
    # the round + badge
    b = circle(196, 186, 30)
    ic.shadow(b, 1, 4, 5, 0.4)
    ic.fill(b, rgrad([lighten(P["badge"], 0.35), P["badge"]], 186, 176, 36))
    ic.fill(U(rrect(182, 183, 210, 189, 3), rrect(193, 172, 199, 200, 3)), "#FFFFFF")
