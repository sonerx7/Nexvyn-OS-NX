# Analog + digital clock drawn with gfx primitives. Angles are radians, 0 = pointing right, clockwise.
import math

TAU = math.pi * 2
_state = {"last_sec": -1, "sec_start": 0.0}


def pad2(v):
    return ("0" + str(v))[-2:]


def hand(cx, cy, turns, length, back, width, color):
    a = turns * TAU - math.pi / 2
    dx = math.cos(a)
    dy = math.sin(a)
    gfx.color(color)
    gfx.line(cx - dx * back, cy - dy * back, cx + dx * length, cy + dy * length, width)


def draw_clock(w, h):
    d = sys.date()
    now = sys.time()
    if d.sec != _state["last_sec"]:
        _state["last_sec"] = d.sec
        _state["sec_start"] = now
    # the seconds hand moves to the new second with a short ease-out
    t = min(1.0, (now - _state["sec_start"]) * 5)
    sec = d.sec - 1 + (1 - (1 - t) ** 3)
    minute = d.min + d.sec / 60
    hour = d.hour % 12 + minute / 60

    r = max(60, min(w * 0.3, (h - 190) / 2))
    cx = w / 2
    cy = 62 + r
    gfx.shadow(cx - r, cy - r, r * 2, r * 2, r, 18, 6)
    gfx.circle(cx, cy, r, theme.window)
    gfx.color(theme.separator)
    gfx.circleLine(cx, cy, r, 2)
    for i in range(60):
        a = i / 60 * TAU - math.pi / 2
        major = i % 5 == 0
        r0 = r - (16 if major else 9)
        r1 = r - 6
        gfx.color(theme.text if major else theme.text3)
        gfx.line(cx + math.cos(a) * r0, cy + math.sin(a) * r0, cx + math.cos(a) * r1, cy + math.sin(a) * r1,
                 3 if major else 1)
    gfx.color(theme.text)
    for n in range(1, 13):
        a = n / 12 * TAU - math.pi / 2
        rr = r - 34
        gfx.text(str(n), cx + math.cos(a) * rr - 20, cy + math.sin(a) * rr - 10, 16, "semibold", "center", 40)
    hand(cx, cy, hour / 12, r * 0.5, 10, 6, theme.text)
    hand(cx, cy, minute / 60, r * 0.74, 12, 4, theme.text)
    hand(cx, cy, sec / 60, r * 0.84, 18, 2, theme.red)
    gfx.circle(cx, cy, 6, theme.red)
    gfx.circle(cx, cy, 2.5, theme.window)

    gfx.color(theme.text)
    gfx.text(pad2(d.hour) + ":" + pad2(d.min) + ":" + pad2(d.sec), 0, cy + r + 18, 28, "monobold", "center", w)
    gfx.color(theme.text2)
    month = TR("date.months." + str(d.month - 1))
    day = TR("date.days." + str(d.wday))
    gfx.text(TR("date_fmt", d.day, month, d.year, day), 0, cy + r + 58, 14, "sans", "center", w)
