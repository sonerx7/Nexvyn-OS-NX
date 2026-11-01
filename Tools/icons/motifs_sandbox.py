"""Icons of the sandbox games: BlockCraft."""
from iconkit import U, blur, circle, darken, ellipse, lgrad, lighten, line, poly, rgrad, rrect, sparkle
from motifs_common import motif


def _iso(cx, cy, s):
    """top, left and right faces of an isometric cube whose top corner is at (cx, cy - s)"""
    w = s * 0.866
    top = [(cx, cy - s), (cx + w, cy - s * 0.5), (cx, cy), (cx - w, cy - s * 0.5)]
    left = [(cx - w, cy - s * 0.5), (cx, cy), (cx, cy + s), (cx - w, cy + s * 0.5)]
    right = [(cx, cy), (cx + w, cy - s * 0.5), (cx + w, cy + s * 0.5), (cx, cy + s)]
    return top, left, right


# ------------------------------------------------------------------------------------------------- BlockCraft
@motif
def blockcraft(ic):
    P = ic.P
    # a grass block with pixel speckles, a pickaxe over it and a Puffcap with glowing spots in front
    cx, cy, s = 134, 132, 66
    top, left, right = _iso(cx, cy, s)
    ic.add(blur(circle(cx, cy + 6, 86), 30), P["glow"], 0.18)
    cube = U(poly(top), poly(left), poly(right))
    ic.shadow(cube, 2, 7, 8, 0.45)
    ic.fill(poly(left), lgrad([P["dirt"], darken(P["dirt"], 0.25)], cx - 60, cy, cx, cy + 60))
    ic.fill(poly(right), lgrad([darken(P["dirt"], 0.3), darken(P["dirt"], 0.45)], cx, cy, cx + 60, cy + 60))
    # grass overhang on the sides with a ragged lower edge
    w = s * 0.866
    for side, sgn, shade in ((left, -1, 0.0), (right, 1, 0.28)):
        pts = []
        steps = 8
        for k in range(steps + 1):
            t = k / steps
            x = cx + sgn * w * t
            y = cy - s * 0.5 * t
            pts.append((x, y))
        drip = []
        for k in range(steps, -1, -1):
            t = k / steps
            x = cx + sgn * w * t
            y = cy - s * 0.5 * t + (14 if k % 2 else 22)
            drip.append((x, y))
        ic.fill(poly(pts + drip), darken(P["grass"], shade + 0.08))
    # pixel speckles on the dirt
    for (fx, fy) in ((0.25, 0.55), (0.6, 0.75), (0.45, 0.35), (0.8, 0.5), (0.3, 0.85)):
        for side, sgn, shade in ((left, -1, 0.35), (right, 1, 0.55)):
            x = cx + sgn * w * fx
            y = cy - s * 0.5 * fx + s * fy + 6
            ic.fill(poly([(x - 4, y - 2 * -sgn), (x + 4, y + 2 * -sgn), (x + 4, y + 2 * -sgn + 8), (x - 4, y - 2 * -sgn + 8)]),
                    darken(P["dirt"], shade))
    ic.fill(poly(top), lgrad([lighten(P["grass"], 0.25), P["grass"], darken(P["grass"], 0.1)], cx - 40, cy - 60, cx + 40, cy))
    for (fx, fy) in ((-0.3, -0.62), (0.25, -0.7), (0.05, -0.4), (0.45, -0.48), (-0.5, -0.45)):
        x, y = cx + fx * s, cy + fy * s
        ic.fill(poly([(x, y - 4), (x + 7, y), (x, y + 4), (x - 7, y)]), lighten(P["grass"], 0.3), 0.8)
    ic.rim(cube, 1.4, 0.35)

    # pickaxe leaning over the top right of the block
    ic.fill(line([(150, 118), (206, 50)], 9), darken(P["handle"], 0.35))
    ic.fill(line([(150, 118), (206, 50)], 6), P["handle"])
    head = U(line([(168, 36), (190, 46), (206, 50), (218, 66), (226, 92)], 11))
    ic.shadow(head, 1.5, 4, 4, 0.4)
    ic.fill(head, lgrad([lighten(P["pick"], 0.35), P["pick"], darken(P["pick"], 0.3)], 168, 36, 226, 92))
    ic.rim(head, 1.2, 0.5)

    # the Puffcap: pale stem, glowing eyes, a purple cap with glowing spots
    px, py = 72, 186
    ic.add(blur(circle(px, py - 6, 40), 18), P["glow"], 0.45)
    stem = rrect(px - 17, py - 22, px + 17, py + 26, 8)
    ic.shadow(stem, 1.5, 4, 4, 0.4)
    ic.fill(stem, lgrad([lighten(P["stem"], 0.15), P["stem"], darken(P["stem"], 0.2)], px - 17, 0, px + 17, 0))
    for ex in (px - 7, px + 7):
        ic.fill(rrect(ex - 3.5, py - 10, ex + 3.5, py + 2, 3), darken(P["cap"], 0.55))
        ic.add(blur(rrect(ex - 2.5, py - 8, ex + 2.5, py, 2), 2), P["glow"], 0.9)
        ic.fill(rrect(ex - 2, py - 8, ex + 2, py, 2), "#E8FFF6")
    cap = U(ellipse(px, py - 24, 40, 24), rrect(px - 40, py - 26, px + 40, py - 14, 8))
    ic.shadow(cap, 1.5, 4, 5, 0.45)
    ic.fill(cap, rgrad([lighten(P["cap"], 0.3), P["cap"], darken(P["cap"], 0.35)], px - 10, py - 40, 50))
    ic.fill(rrect(px - 40, py - 19, px + 40, py - 14, 3), darken(P["cap"], 0.4))
    for (x, y, r) in ((px - 18, py - 34, 5.5), (px + 6, py - 40, 4.5), (px + 24, py - 26, 4.5), (px - 28, py - 22, 3.5), (px + 2, py - 26, 3.5)):
        ic.add(blur(circle(x, y, r * 1.9), r), P["glow"], 0.7)
        ic.fill(circle(x, y, r), lighten(P["glow"], 0.25))
    ic.rim(cap, 1.3, 0.5)

    for (x, y, r) in ((44, 62, 6), (70, 40, 4), (214, 132, 4.5), (222, 172, 3)):
        ic.add(blur(sparkle(x, y, r), 0.6), "#FFFFFF", 0.85)
