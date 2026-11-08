#!/usr/bin/env python3
"""Draws icon.png of the Tour: a lit cube and a sphere on a soft dark ground (needs Pillow). python gen_icon.py"""
import math, os
from PIL import Image, ImageDraw, ImageFilter

S, K = 256, 4
W = S * K
HERE = os.path.dirname(os.path.abspath(__file__))
img = Image.new("RGB", (W, W))
px = img.load()
for y in range(W):  # a vertical gradient with a glow behind the objects
    for x in range(0, W):
        d = math.hypot(x - W * 0.5, y - W * 0.55) / W
        g = max(0.0, 1 - d * 1.7)
        px[x, y] = (int(22 + 40 * g), int(28 + 62 * g), int(44 + 110 * g))
d = ImageDraw.Draw(img)
# ground shadow
sh = Image.new("L", (W, W), 0)
ImageDraw.Draw(sh).ellipse((W * 0.18, W * 0.70, W * 0.86, W * 0.86), fill=150)
sh = sh.filter(ImageFilter.GaussianBlur(W * 0.025))
img.paste((6, 8, 16), mask=sh)
d = ImageDraw.Draw(img)
# isometric cube
cx, cy, a = W * 0.43, W * 0.50, W * 0.19
top = [(cx, cy - a), (cx + a * 0.87, cy - a * 0.5), (cx, cy), (cx - a * 0.87, cy - a * 0.5)]
left = [(cx - a * 0.87, cy - a * 0.5), (cx, cy), (cx, cy + a), (cx - a * 0.87, cy + a * 0.5)]
right = [(cx, cy), (cx + a * 0.87, cy - a * 0.5), (cx + a * 0.87, cy + a * 0.5), (cx, cy + a)]
d.polygon(top, fill=(118, 190, 255))
d.polygon(left, fill=(36, 106, 214))
d.polygon(right, fill=(22, 70, 160))
for poly in (top, left, right):
    d.line(poly + [poly[0]], fill=(200, 228, 255), width=K * 2)
# sphere with a highlight
sx, sy, r = W * 0.68, W * 0.64, W * 0.15
for i in range(int(r), 0, -1):
    t = i / r
    c = (int(255 * (1 - t * 0.55)), int(190 * (1 - t * 0.6)), int(80 * (1 - t * 0.7)))
    ox, oy = -(1 - t) * r * 0.35, -(1 - t) * r * 0.40
    d.ellipse((sx + ox - i, sy + oy - i, sx + ox + i, sy + oy + i), fill=c)
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, W - 1, W - 1), radius=int(W * 0.22), fill=255)
out = img.resize((S, S), Image.LANCZOS).convert("RGBA")
out.putalpha(mask.resize((S, S), Image.LANCZOS))
out.save(os.path.join(HERE, "icon.png"))
