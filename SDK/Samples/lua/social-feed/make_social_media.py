#!/usr/bin/env python3
"""Media of the Social Feed sample (SDK/Samples/lua/social-feed): 12 photos and 3 short vertical clips, all generated
here (procedural art and ffmpeg test sources), so they are free to use: CC0 1.0 (public domain dedication).

    python tools/store_pending/social19/make_social_media.py [out_dir]

Default out_dir: tools/store_pending/social19/SDK/Samples/lua/social-feed/source/media. Needs Pillow and ffmpeg.
"""
import json
import math
import os
import random
import subprocess
import sys

from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "SDK", "Samples", "lua", "social-feed", "source", "media")

PALETTES = [
    ("#FF7A59", "#FFD36E", "#2B2D42"), ("#3A86FF", "#8338EC", "#FFFFFF"), ("#06D6A0", "#118AB2", "#073B4C"),
    ("#EF476F", "#FFD166", "#26547C"), ("#F72585", "#4CC9F0", "#3A0CA3"), ("#FFB703", "#FB8500", "#023047"),
    ("#2EC4B6", "#CBF3F0", "#FF9F1C"), ("#E63946", "#F1FAEE", "#1D3557"), ("#80ED99", "#57CC99", "#22577A"),
    ("#FFADAD", "#FFC6FF", "#9BF6FF"), ("#BDB2FF", "#A0C4FF", "#3D405B"), ("#F4A261", "#E76F51", "#264653"),
]


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def photo(i, size=720):
    rnd = random.Random(100 + i)
    a, b, c = (hexrgb(x) for x in PALETTES[i % len(PALETTES)])
    im = Image.new("RGB", (size, size))
    px = im.load()
    for y in range(size):
        t = y / (size - 1)
        row = tuple(int(a[k] * (1 - t) + b[k] * t) for k in range(3))
        for x in range(size):
            px[x, y] = row
    d = ImageDraw.Draw(im, "RGBA")
    # soft sun / moon
    cx, cy, r = rnd.randint(150, 570), rnd.randint(120, 330), rnd.randint(70, 140)
    for k in range(6, 0, -1):
        rr = r + k * 18
        d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=(255, 255, 255, 10))
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(255, 250, 235, 230))
    # layered hills
    for layer in range(4):
        base = 420 + layer * 70
        amp = 40 + layer * 12
        ph = rnd.random() * 6.28
        col = tuple(int(c[k] * (0.45 + layer * 0.17) + a[k] * (0.4 - layer * 0.1)) for k in range(3))
        pts = [(0, size)]
        for x in range(0, size + 8, 8):
            pts.append((x, base + amp * math.sin(x / (90 + layer * 30) + ph) + 18 * math.sin(x / 33 + ph * 2)))
        pts.append((size, size))
        d.polygon(pts, fill=col + (255,))
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    return im


def make_photos():
    os.makedirs(OUT, exist_ok=True)
    for i in range(12):
        photo(i).save(os.path.join(OUT, "photo%02d.jpg" % (i + 1)), quality=82, optimize=True, progressive=False)


def clip_frame(k, t, w=480, h=854):
    """One frame: a slowly turning two-colour gradient with floating soft circles."""
    import numpy as np
    a, b, c = (np.array(hexrgb(x), dtype=np.float32) for x in PALETTES[(k * 4 + 1) % len(PALETTES)])
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    ang = t * 0.6 + k
    g = ((xx / w - 0.5) * math.cos(ang) + (yy / h - 0.5) * math.sin(ang)) + 0.5
    g = np.clip(g, 0, 1)[..., None]
    img = a * (1 - g) + b * g
    for i in range(7):
        cx = w * (0.5 + 0.38 * math.sin(t * (0.7 + i * 0.13) + i * 1.7))
        cy = h * (0.5 + 0.42 * math.cos(t * (0.5 + i * 0.11) + i * 2.3))
        r = 40 + 18 * i
        d2 = ((xx - cx) ** 2 + (yy - cy) ** 2) / (r * r)
        m = np.clip(1.2 - d2, 0, 1)[..., None] * 0.35
        img = img * (1 - m) + c * m
    return np.clip(img, 0, 255).astype(np.uint8)


def make_clips():
    for k, hz in enumerate((330, 392, 262)):
        out = os.path.join(OUT, "clip%d.mp4" % (k + 1))
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", "480x854", "-r", "30",
               "-i", "-", "-f", "lavfi", "-i", "sine=frequency=%d:sample_rate=48000:duration=4" % hz,
               "-af", "volume=0.08", "-shortest", "-c:v", "libx264", "-profile:v", "main", "-preset", "veryslow",
               "-crf", "30", "-pix_fmt", "yuv420p", "-c:a", "aac", "-strict", "-2", "-b:a", "64k", "-movflags", "+faststart", out]
        p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
        for f in range(120):
            p.stdin.write(clip_frame(k, f / 30.0).tobytes())
        p.stdin.close()
        if p.wait() != 0:
            raise SystemExit("ffmpeg failed for " + out)


def make_feed():
    """feed.json: the posts the sample shows (also what a server would answer for page 1)."""
    captions = [
        "Golden hour on the hills **again** #sunset #nature",
        "First try with the new lens, thoughts? @mira",
        "Weekend plan: walk, coffee, repeat #weekend",
        "The colors today were unreal https://example.com/blog/colors",
        "Shot this right before the rain #weather",
        "**Big news** coming soon, stay tuned!",
        "Thanks @leo for the tip on composition #photography",
        "Quiet morning #calm",
        "Testing the night mode, not bad #night",
        "Throwback to the summer trip #travel @ana",
        "Minimal and clean #minimal",
        "Can you guess where this is? #guess",
    ]
    users = ["mira", "leo", "ana", "kai", "noa", "eli"]
    posts = []
    for i in range(12):
        posts.append({"id": i + 1, "user": users[i % len(users)], "photo": "photo%02d.jpg" % (i + 1),
                      "caption": captions[i], "likes": 12 + i * 7, "minutesAgo": 3 + i * 47})
    with open(os.path.join(OUT, "feed.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"posts": posts, "clips": ["clip1.mp4", "clip2.mp4", "clip3.mp4"]}, f, indent=1)
        f.write("\n")


def make_icon():
    """icon.png next to media/: three stacked photo cards with a play badge, 256 x 256 with transparency."""
    s = 4  # drawn at 4x, scaled down for smooth edges
    im = Image.new("RGBA", (256 * s, 256 * s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle((8 * s, 8 * s, 248 * s, 248 * s), 56 * s, fill=hexrgb("#1D1B3A") + (255,))
    for k, (ang, src) in enumerate(((-14, 4), (8, 1), (0, 0))):
        card = photo(src, 150 * s).convert("RGBA")
        mask = Image.new("L", card.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle((0, 0, card.size[0] - 1, card.size[1] - 1), 22 * s, fill=255)
        frame = Image.new("RGBA", (card.size[0] + 12 * s, card.size[1] + 12 * s), (255, 255, 255, 0))
        ImageDraw.Draw(frame).rounded_rectangle((0, 0, frame.size[0] - 1, frame.size[1] - 1), 26 * s, fill=(255, 255, 255, 255))
        frame.paste(card, (6 * s, 6 * s), mask)
        frame = frame.rotate(ang, resample=Image.BICUBIC, expand=True)
        im.alpha_composite(frame, ((256 * s - frame.size[0]) // 2 + (k - 1) * 10 * s, (256 * s - frame.size[1]) // 2 - 6 * s))
    cx, cy, r = 186 * s, 186 * s, 38 * s
    d = ImageDraw.Draw(im)
    d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=hexrgb("#F72585") + (255,), outline=(255, 255, 255, 255), width=5 * s)
    d.polygon([(cx - 12 * s, cy - 18 * s), (cx - 12 * s, cy + 18 * s), (cx + 20 * s, cy)], fill=(255, 255, 255, 255))
    im.resize((256, 256), Image.LANCZOS).save(os.path.join(os.path.dirname(OUT), "icon.png"))


if __name__ == "__main__":
    make_photos()
    make_clips()
    make_feed()
    make_icon()
    print("media written to", OUT)
