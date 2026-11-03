"""Builds store key art around a hero render (hero_render.py output, or any PNG with a transparent background):
a lit background, a soft glow behind the hero, a rim highlight on its edges, a vignette and, if you want them, light
rays, sparks, bloom and a title; then every size the App Market needs and a preview sheet. Needs only Pillow
(pip install pillow).

    python finish_icon.py hero.png --look ember --out art/                          (clean, the default)
    python finish_icon.py hero.png --look ember --style bold --title "EMBER" --out art/

The style is the maker's choice:
  clean (default)   polished and calm: the hero, a soft lit background, a gentle glow and rim, no rays or sparks,
                    a natural colour grade, no text
  bold              more contrast and saturation, some light rays and sparks, a stronger glow and rim
  loud              everything turned up: many rays and sparks, strong bloom, a punchy grade (arcade / action games)

Options:
  --style NAME      clean, bold or loud (default clean); the options below override single parts of it
  --title TEXT      a title logo (one or two short words; "\\n" breaks the line). Off unless given
  --look NAME       ember, frost, toxic, synth, gold, royal, jungle, noir (colours of everything)
  --fill F          hero height as a share of the square (default by style, 0.78-0.95; above 1 crops the hero)
  --x F / --y F     hero centre x (default 0.5) and the bottom of the hero (default by style), shares of the square
  --frame           an inner badge frame the hero is drawn over (with a large --fill its head goes over the border)
  --rays N          light rays behind the hero (default by style: 0 / 12 / 18)
  --sparks N        sparks and embers (default by style: 0 / 20 / 40)
  --tilt DEG        title rotation (default -4)
  --font PATH       a .ttf for the title (default: SDK/Fonts/Inter-Bold.ttf next to this kit)
  --seed N          random layout of sparks and rays
  --mask            also cut the corners of the outputs (a rounded square); the store wants them filled, so only
                    for previews and other uses
  --out DIR         output folder (default: the current folder)

Outputs: keyart_1024.png, icon_512.png, icon.png (256 x 256: copy it to source/icon.png), preview.png (the icon at
256 / 128 / 64 px with rounded corners, on dark and light, and in grey to check the value contrast)."""
import argparse
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps

N = 1024
HERE = os.path.dirname(os.path.abspath(__file__))

# bg inner, bg mid, bg outer, rays, glow behind the hero, edge rim, sparks, title top, title bottom, title outline
LOOKS = {
    "ember": ("#B8325A", "#3B1050", "#0B0418", "#FFB36B", "#FF6A1F", "#FFE3A3", "#FFC145", "#FFF6D8", "#FF8A2A", "#2A0E1E"),
    "frost": ("#1F86C4", "#0E2E62", "#030818", "#D8FBFF", "#29D3FF", "#FFFFFF", "#9CF6FF", "#FFFFFF", "#7FE6FF", "#06142E"),
    "toxic": ("#7FD62A", "#144A1E", "#040A05", "#E9FF9A", "#7CFF1F", "#F4FFB0", "#C8FF4A", "#F6FFD0", "#8CFF2A", "#0A1A08"),
    "synth": ("#E8368C", "#3A0E62", "#08021A", "#FFC2E2", "#FF2E88", "#7FF6FF", "#19E6FF", "#FFFFFF", "#FF5FB0", "#16042E"),
    "gold": ("#F0A93A", "#6E300C", "#140803", "#FFF1C2", "#FFB020", "#FFF6D0", "#FFE08A", "#FFFBEA", "#FFB72E", "#2A1404"),
    "royal": ("#8C5CF0", "#2A1270", "#08051A", "#E6D9FF", "#8A5CFF", "#FFE08A", "#FFD36B", "#FFFFFF", "#C9A6FF", "#120A30"),
    "jungle": ("#E8A830", "#145A2C", "#031008", "#FFF0B8", "#FFB82E", "#EFFFD0", "#B8FF7A", "#FFFBE6", "#FFC23A", "#062010"),
    "noir": ("#FF4D5A", "#3A0A12", "#050505", "#FFD0D4", "#FF2238", "#FFFFFF", "#FFFFFF", "#FFFFFF", "#FF4D5A", "#000000"),
}


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def solid(color, size=(N, N)):
    return Image.new("RGB", size, rgb(color))


def screen(base, layer, mask=None, amount=1.0):
    out = ImageChops.screen(base, layer)
    if amount < 1:
        out = Image.blend(base, out, amount)
    return out if mask is None else Image.composite(out, base, mask)


def radial(cx, cy, scale=1.0):
    """L image: 0 at (cx, cy), 255 far away (a radius of about `scale` squares)."""
    g = Image.radial_gradient("L")                                  # 256 x 256, 0 in the centre
    size = int(N * 2 * scale)
    g = g.resize((size, size), Image.BICUBIC)
    left, top = int(size / 2 - cx * N), int(size / 2 - cy * N)
    return g.crop((left, top, left + N, top + N))


# per style: hero fill and bottom, rays and their strength, sparks, bokeh, glow behind the hero (near, far), edge rim,
# bloom (near, far), saturation, contrast, vignette, ground light
STYLES = {
    "clean": dict(fill=0.78, y=0.93, rays=0, ray=0.0, sparks=0, bokeh=0.35, halo=0.45, halo2=0.25, rim=0.55,
                  bloom=(0.15, 0.1), sat=1.04, con=1.03, vig=0.45, ground=0.45),
    "bold": dict(fill=0.86, y=0.97, rays=12, ray=0.28, sparks=20, bokeh=0.8, halo=0.8, halo2=0.45, rim=1.1,
                 bloom=(0.35, 0.25), sat=1.12, con=1.06, vig=0.65, ground=0.8),
    "loud": dict(fill=0.95, y=0.98, rays=18, ray=0.4, sparks=40, bokeh=1.0, halo=1.0, halo2=0.6, rim=1.6,
                 bloom=(0.5, 0.4), sat=1.18, con=1.08, vig=0.75, ground=1.0),
}


def background(look, rnd, rays, cx, cy, ray_amt=0.4, bokeh=1.0):
    inner, mid, outer, ray = look[0], look[1], look[2], look[3]
    img = ImageOps.colorize(radial(cx, cy, 0.95), rgb(inner), rgb(outer), rgb(mid), 0, 255, 110)
    if rays:
        layer = Image.new("L", (N, N), 0)
        d = ImageDraw.Draw(layer)
        a0 = rnd.random() * math.tau
        for i in range(rays):
            a = a0 + i * math.tau / rays + rnd.uniform(-0.08, 0.08)
            w = math.tau / rays * rnd.uniform(0.22, 0.42)
            R = N * 1.6
            pts = [(cx * N, cy * N), (cx * N + math.cos(a - w) * R, cy * N + math.sin(a - w) * R),
                   (cx * N + math.cos(a + w) * R, cy * N + math.sin(a + w) * R)]
            d.polygon(pts, fill=int(rnd.uniform(90, 200)))
        layer = layer.filter(ImageFilter.GaussianBlur(6))
        fade = ImageOps.invert(radial(cx, cy, 0.75))
        layer = ImageChops.multiply(layer, fade)
        img = screen(img, solid(ray), layer.point(lambda v: int(v * ray_amt)))
    # bokeh: big soft circles far away, small sharper ones nearer
    for blur, count, rmin, rmax, alpha in ((22, 10, 40, 110, 70), (5, 26, 6, 22, 120)):
        layer = Image.new("L", (N, N), 0)
        d = ImageDraw.Draw(layer)
        for _ in range(count):
            x, y = rnd.uniform(0, N), rnd.uniform(0, N * 0.9)
            r = rnd.uniform(rmin, rmax)
            d.ellipse((x - r, y - r, x + r, y + r), fill=int(rnd.uniform(0.4, 1) * alpha * bokeh))
        img = screen(img, solid(look[6]), layer.filter(ImageFilter.GaussianBlur(blur)))
    return img


def title_layer(text, look, font_path, tilt):
    lines = [s.strip().upper() for s in text.replace("\\n", "\n").split("\n") if s.strip()]
    size = int(N * 0.2)
    font = ImageFont.truetype(font_path, size)
    while size > 40:   # fit the widest line into 86 % of the square
        font = ImageFont.truetype(font_path, size)
        widest = max(font.getbbox(s)[2] - font.getbbox(s)[0] for s in lines)
        if widest <= N * 0.86:
            break
        size -= 4
    stroke = max(4, int(size * 0.09))
    line_h = int(size * 1.0)
    W, H = N, line_h * len(lines) + stroke * 4 + 40
    fill_mask = Image.new("L", (W, H), 0)
    stroke_mask = Image.new("L", (W, H), 0)
    df, ds = ImageDraw.Draw(fill_mask), ImageDraw.Draw(stroke_mask)
    for i, s in enumerate(lines):
        bb = font.getbbox(s)
        x = (W - (bb[2] - bb[0])) / 2 - bb[0]
        y = 20 + stroke * 2 + i * line_h - bb[1] * 0.35
        ds.text((x, y), s, font=font, fill=255, stroke_width=stroke, stroke_fill=255)
        df.text((x, y), s, font=font, fill=255)
    top, bottom = rgb(look[7]), rgb(look[8])
    grad = Image.new("RGB", (1, H))
    for y in range(H):
        t = min(1, max(0, (y - 20) / max(1, H - 40)))
        t = t * t * (3 - 2 * t)
        grad.putpixel((0, y), tuple(int(top[k] + (bottom[k] - top[k]) * t) for k in range(3)))
    grad = grad.resize((W, H))
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    glow = stroke_mask.filter(ImageFilter.GaussianBlur(size * 0.18)).point(lambda v: int(v * 0.8))
    layer.paste(Image.new("RGBA", (W, H), rgb(look[4]) + (255,)), (0, 0), glow)
    shadow = stroke_mask.filter(ImageFilter.GaussianBlur(6))
    layer.paste(Image.new("RGBA", (W, H), (0, 0, 0, 255)), (0, int(stroke * 0.9)), shadow)
    layer.paste(Image.new("RGBA", (W, H), rgb(look[9]) + (255,)), (0, 0), stroke_mask)
    layer.paste(grad.convert("RGBA"), (0, 0), fill_mask)
    # a thin light line on the upper part of the letters: reads as a bevel
    shine = ImageChops.subtract(fill_mask, ImageChops.offset(fill_mask, 0, max(2, size // 28)))
    layer.paste(Image.new("RGBA", (W, H), (255, 255, 255, 255)), (0, 0), shine.point(lambda v: int(v * 0.7)))
    if tilt:
        layer = layer.rotate(tilt, resample=Image.BICUBIC, expand=True)
    return layer


def squircle(size, n=5.0):
    s = size * 4
    m = Image.new("L", (s, s), 0)
    px = m.load()
    r = s / 2
    for y in range(s):
        dy = abs((y + 0.5 - r) / r) ** n
        if dy >= 1:
            continue
        dx = (1 - dy) ** (1 / n) * r
        for x in range(int(r - dx), int(r + dx)):
            px[x, y] = 255
    return m.resize((size, size), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("hero")
    ap.add_argument("--style", default="clean", choices=sorted(STYLES))
    ap.add_argument("--title", default="")
    ap.add_argument("--look", default="ember", choices=sorted(LOOKS))
    ap.add_argument("--fill", type=float, default=None)
    ap.add_argument("--x", type=float, default=0.5)
    ap.add_argument("--y", type=float, default=None)
    ap.add_argument("--frame", action="store_true")
    ap.add_argument("--rays", type=int, default=None)
    ap.add_argument("--sparks", type=int, default=None)
    ap.add_argument("--tilt", type=float, default=-4)
    ap.add_argument("--font", default=os.path.join(HERE, "..", "..", "Fonts", "Inter-Bold.ttf"))
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--mask", action="store_true")
    ap.add_argument("--out", default=".")
    a = ap.parse_args()
    look = LOOKS[a.look]
    st = STYLES[a.style]
    for k in ("fill", "y", "rays", "sparks"):
        if getattr(a, k) is None:
            setattr(a, k, st[k])
    rnd = random.Random(a.seed)
    os.makedirs(a.out, exist_ok=True)

    # hero: cropped to its pixels, scaled to the fill, standing at (x, y)
    hero = Image.open(a.hero).convert("RGBA")
    bbox = hero.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
    if not bbox:
        raise SystemExit("finish_icon.py: the hero image is empty (it needs a transparent background)")
    hero = hero.crop(bbox)
    scale = min(N * a.fill / hero.height, N * 0.96 / hero.width * max(1.0, a.fill))
    hero = hero.resize((max(1, int(hero.width * scale)), max(1, int(hero.height * scale))), Image.LANCZOS)
    hx, hy = int(a.x * N - hero.width / 2), int(a.y * N - hero.height)
    alpha = Image.new("L", (N, N), 0)
    alpha.paste(hero.getchannel("A"), (hx, hy))
    focus_y = max(0.25, min(0.6, (hy + hero.height * 0.35) / N))

    img = background(look, rnd, a.rays, a.x, focus_y, st["ray"] or 0.3, st["bokeh"])
    # ground light under the hero
    ground = Image.new("L", (N, N), 0)
    ImageDraw.Draw(ground).ellipse((a.x * N - N * 0.42, a.y * N - N * 0.08, a.x * N + N * 0.42, a.y * N + N * 0.1), fill=200)
    img = screen(img, solid(look[4]), ground.filter(ImageFilter.GaussianBlur(40)), amount=st["ground"])
    if a.frame:   # a badge frame inside the square; the hero is drawn over it and breaks out at the top
        fr = Image.new("L", (N, N), 0)
        d = ImageDraw.Draw(fr)
        m = int(N * 0.07)
        d.rounded_rectangle((m, m, N - m, N - m), radius=int(N * 0.12), outline=255, width=int(N * 0.018))
        img.paste(solid("#000000"), (0, 10), fr.filter(ImageFilter.GaussianBlur(10)).point(lambda v: int(v * 0.6)))
        img = screen(img, solid(look[5]), fr)
    # glow behind the hero: its silhouette, grown and blurred, in the glow colour
    halo = alpha.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(34))
    img = screen(img, solid(look[4]), halo, amount=st["halo"])
    img = screen(img, solid(look[4]), halo.filter(ImageFilter.GaussianBlur(60)), amount=st["halo2"])
    # the hero
    img.paste(hero.convert("RGB"), (hx, hy), hero.getchannel("A"))
    # edge rim: the edges facing the upper right light up
    shifted = ImageChops.offset(alpha, -9, 9)
    rim = ImageChops.subtract(alpha, shifted).filter(ImageFilter.GaussianBlur(2.5))
    rim = ImageChops.multiply(rim, alpha)
    img = screen(img, solid(look[5]), rim.point(lambda v: min(255, int(v * st["rim"]))))
    # sparks: small hot dots with a glow, mostly around the hero
    sp = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(sp)
    for _ in range(a.sparks):
        ang = rnd.uniform(0, math.tau)
        dist = rnd.uniform(0.25, 0.55) * N
        x = a.x * N + math.cos(ang) * dist
        y = focus_y * N + math.sin(ang) * dist * 0.8
        r = rnd.uniform(2, 7)
        d.ellipse((x - r, y - r, x + r, y + r), fill=int(rnd.uniform(150, 255)))
    img = screen(img, solid(look[6]), sp.filter(ImageFilter.GaussianBlur(9)))
    img = screen(img, solid(look[6]), sp.filter(ImageFilter.GaussianBlur(1)))
    # bloom: the bright parts bleed light
    lum = img.convert("L").point(lambda v: 0 if v < 205 else int((v - 205) * 5))
    bloom = Image.merge("RGB", [ImageChops.multiply(c, lum) for c in img.split()])
    img = screen(img, bloom.filter(ImageFilter.GaussianBlur(16)), amount=st["bloom"][0])
    img = screen(img, bloom.filter(ImageFilter.GaussianBlur(50)), amount=st["bloom"][1])
    # grade: colour and contrast by style
    img = ImageEnhance.Color(img).enhance(st["sat"])
    img = ImageEnhance.Contrast(img).enhance(st["con"])
    # title over the feet
    if a.title:
        tl = title_layer(a.title, look, a.font, a.tilt)
        tx = int((N - tl.width) / 2)
        ty = int(min(N * 0.97 - tl.height, max(N * 0.6, a.y * N - tl.height * 0.75)))
        base = img.convert("RGBA")
        base.alpha_composite(tl, (tx, ty))
        img = base.convert("RGB")
    # vignette
    vig = radial(0.5, 0.48, 0.72).point(lambda v: max(0, int((v - 120) * 1.3)))
    img = Image.composite(solid("#000000"), img, vig.point(lambda v: int(v * st["vig"])))

    def out(im, size, name):
        r = im.resize((size, size), Image.LANCZOS)
        if size <= 256:
            r = r.filter(ImageFilter.UnsharpMask(radius=1.0, percent=60, threshold=2))
        if a.mask:
            r = r.convert("RGBA")
            r.putalpha(squircle(size))
        r.save(os.path.join(a.out, name))
        return r

    img.save(os.path.join(a.out, "keyart_1024.png"))
    out(img, 512, "icon_512.png")
    icon = out(img, 256, "icon.png")
    # preview: the store sizes with rounded corners on dark and light, plus grey (does the hero still stand out?)
    sheet = Image.new("RGB", (256 + 128 + 64 + 128 + 100, 2 * 276 + 20), (24, 24, 30))
    light = Image.new("RGB", (sheet.width, 276), (236, 236, 240))
    sheet.paste(light, (0, 296))
    for row, y0 in ((0, 10), (1, 306)):
        x = 20
        for s in (256, 128, 64):
            im = img.resize((s, s), Image.LANCZOS)
            sheet.paste(im, (x, y0), squircle(s))
            x += s + 20
        g = ImageOps.grayscale(img.resize((128, 128), Image.LANCZOS)).convert("RGB")
        sheet.paste(g, (x, y0), squircle(128))
    sheet.save(os.path.join(a.out, "preview.png"))
    print("finish_icon: wrote keyart_1024.png, icon_512.png, icon.png, preview.png to", os.path.abspath(a.out))


if __name__ == "__main__":
    main()
