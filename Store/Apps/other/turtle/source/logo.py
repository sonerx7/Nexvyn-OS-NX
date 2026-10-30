# A tiny Logo-like language with Turkish and English keywords.
#   ileri/forward N   geri/back N   sağ/right A   sol/left A   kalemkaldır/penup   kalemindir/pendown
#   renk/color NAME|#RRGGBB|rastgele   kalınlık/width N   tekrarla/repeat N [ ... ]   merkez/home   temizle/clear
#   yap/to NAME ... son/end   (procedures without parameters; call them by name)
# Numbers may be small expressions without spaces: 100, sayaç*3, (sayaç+2)*5/2   (sayaç/repcount = loop counter)
import math
import random

FOLD = {"ç": "c", "Ç": "c", "ğ": "g", "Ğ": "g", "ı": "i", "İ": "i", "I": "i", "ö": "o", "Ö": "o", "ş": "s",
        "Ş": "s", "ü": "u", "Ü": "u", "â": "a", "î": "i", "û": "u"}

KEYWORDS = {
    "ileri": "fd", "forward": "fd", "fd": "fd", "geri": "bk", "back": "bk", "bk": "bk",
    "sag": "rt", "right": "rt", "rt": "rt", "sol": "lt", "left": "lt", "lt": "lt",
    "kalemkaldir": "pu", "penup": "pu", "pu": "pu", "kalemindir": "pd", "pendown": "pd", "pd": "pd",
    "renk": "color", "color": "color", "kalinlik": "width", "width": "width",
    "tekrarla": "repeat", "repeat": "repeat", "merkez": "home", "home": "home",
    "temizle": "clear", "clear": "clear", "yap": "to", "to": "to", "son": "end", "end": "end",
}
COLORS = {
    "kirmizi": "#FF3B30", "red": "#FF3B30", "turuncu": "#FF9500", "orange": "#FF9500", "sari": "#FFCC00",
    "yellow": "#FFCC00", "yesil": "#34C759", "green": "#34C759", "mavi": "#007AFF", "blue": "#007AFF",
    "acikmavi": "#5AC8FA", "cyan": "#5AC8FA", "mor": "#AF52DE", "purple": "#AF52DE", "pembe": "#FF2D55",
    "pink": "#FF2D55", "beyaz": "#FFFFFF", "white": "#FFFFFF", "siyah": "#1C1C1E", "black": "#1C1C1E",
    "gri": "#8E8E93", "gray": "#8E8E93", "grey": "#8E8E93", "kahverengi": "#A2845E", "brown": "#A2845E",
}
RANDOM_COLORS = ["#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#5AC8FA", "#007AFF", "#AF52DE", "#FF2D55"]
MAX_SEGMENTS = 30000


def is_digit(c):
    return c != "" and "0" <= c <= "9"


def is_alpha(c):
    return c != "" and ("a" <= c <= "z" or c == "_")


def fold(s):
    out = []
    for ch in s:
        out.append(FOLD.get(ch, ch))
    return "".join(out).lower()


class LogoError(Exception):
    def __init__(self, line, key, arg=""):
        super().__init__(key)
        self.line = line
        self.key = key
        self.arg = arg


# ------------------------------------------------------------------ expressions
class Expr:
    def __init__(self, text, line):
        self.text = text
        self.line = line
        self.pos = 0

    def value(self, counter):
        self.pos = 0
        self.counter = counter
        v = self.sum()
        if self.pos != len(self.text):
            raise LogoError(self.line, "err_number", self.text)
        return v

    def peek(self):
        return self.text[self.pos] if self.pos < len(self.text) else ""

    def sum(self):
        v = self.product()
        while self.peek() == "+" or self.peek() == "-":
            op = self.peek()
            self.pos += 1
            r = self.product()
            v = v + r if op == "+" else v - r
        return v

    def product(self):
        v = self.atom()
        while self.peek() == "*" or self.peek() == "/":
            op = self.peek()
            self.pos += 1
            r = self.atom()
            if op == "*":
                v = v * r
            else:
                if r == 0:
                    raise LogoError(self.line, "err_div")
                v = v / r
        return v

    def atom(self):
        c = self.peek()
        if c == "-":
            self.pos += 1
            return -self.atom()
        if c == "(":
            self.pos += 1
            v = self.sum()
            if self.peek() != ")":
                raise LogoError(self.line, "err_number", self.text)
            self.pos += 1
            return v
        start = self.pos
        if is_digit(c) or c == ".":
            while is_digit(self.peek()) or self.peek() == ".":
                self.pos += 1
            try:
                return float(self.text[start:self.pos])
            except ValueError:
                raise LogoError(self.line, "err_number", self.text)
        while is_alpha(self.peek()):
            self.pos += 1
        word = self.text[start:self.pos]
        if word in ("sayac", "repcount"):
            return float(self.counter)
        if word in ("rastgele", "random"):
            return float(random.randint(0, 360))
        raise LogoError(self.line, "err_number", self.text)


# ------------------------------------------------------------------ parser
def tokenize(lines):
    toks = []
    for i in range(len(lines)):
        text = lines[i]
        if text.strip().startswith(";") or text.strip().startswith("//"):
            continue
        text = text.replace("[", " [ ").replace("]", " ] ")
        for part in text.split():
            toks.append((part, i + 1))
    return toks


def parse(lines):
    toks = tokenize(lines)
    procs = {}
    body, pos = parse_block(toks, 0, procs, False)
    return body, procs


def need_arg(toks, pos, line, word):
    if pos >= len(toks):
        raise LogoError(line, "err_missing", word)
    return toks[pos]


def parse_block(toks, pos, procs, in_bracket):
    out = []
    while pos < len(toks):
        word, line = toks[pos]
        w = fold(word)
        pos += 1
        if w == "]":
            if in_bracket:
                return out, pos
            raise LogoError(line, "err_bracket_extra")
        kind = KEYWORDS.get(w)
        if kind in ("fd", "bk", "rt", "lt", "width"):
            arg, aline = need_arg(toks, pos, line, word)
            pos += 1
            out.append((kind, Expr(fold(arg), aline), line))
        elif kind in ("pu", "pd", "home", "clear"):
            out.append((kind, None, line))
        elif kind == "color":
            arg, aline = need_arg(toks, pos, line, word)
            pos += 1
            a = fold(arg)
            if a.startswith("#") and len(a) == 7:
                ok = True
                for ch in a[1:]:
                    if ch not in "0123456789abcdef":
                        ok = False
                if not ok:
                    raise LogoError(aline, "err_color", arg)
                out.append(("color", a.upper(), line))
            elif a in ("rastgele", "random"):
                out.append(("color", "random", line))
            elif a in COLORS:
                out.append(("color", COLORS[a], line))
            else:
                raise LogoError(aline, "err_color", arg)
        elif kind == "repeat":
            arg, aline = need_arg(toks, pos, line, word)
            pos += 1
            if pos >= len(toks) or toks[pos][0] != "[":
                raise LogoError(line, "err_bracket_open")
            inner, pos = parse_block(toks, pos + 1, procs, True)
            out.append(("repeat", (Expr(fold(arg), aline), inner), line))
        elif kind == "to":
            name, nline = need_arg(toks, pos, line, word)
            pos += 1
            nm = fold(name)
            if nm in KEYWORDS:
                raise LogoError(nline, "err_name", name)
            start = pos
            depth = 0
            while pos < len(toks) and not (KEYWORDS.get(fold(toks[pos][0])) == "end" and depth == 0):
                if KEYWORDS.get(fold(toks[pos][0])) == "to":
                    raise LogoError(toks[pos][1], "err_nested_to")
                pos += 1
            if pos >= len(toks):
                raise LogoError(line, "err_no_end", name)
            inner, _ = parse_block(toks[start:pos], 0, procs, False)
            procs[nm] = inner
            pos += 1
        elif kind == "end":
            raise LogoError(line, "err_end_extra")
        elif w == "[":
            raise LogoError(line, "err_bracket_where")
        else:
            out.append(("call", w, line, word))
    if in_bracket:
        raise LogoError(toks[-1][1] if toks else 1, "err_bracket_missing")
    return out, pos


# ------------------------------------------------------------------ interpreter -> segments
class Run:
    def __init__(self):
        self.x, self.y, self.h = 0.0, 0.0, 0.0   # heading in degrees, 0 = up, clockwise
        self.pen = True
        self.color = "#007AFF"
        self.width = 2.0
        self.segs = []      # (x1, y1, x2, y2, color, width, heading) ; None = clear
        self.depth = 0

    def run(self, body, procs, counter):
        for node in body:
            kind = node[0]
            line = node[2]
            if kind in ("fd", "bk"):
                d = node[1].value(counter)
                if kind == "bk":
                    d = -d
                r = self.h * math.pi / 180
                nx, ny = self.x + math.sin(r) * d, self.y + math.cos(r) * d
                self.add((self.x, self.y, nx, ny, self.color if self.pen else None, self.width, self.h), line)
                self.x, self.y = nx, ny
            elif kind == "rt":
                self.h = (self.h + node[1].value(counter)) % 360
                self.add((self.x, self.y, self.x, self.y, None, self.width, self.h), line)
            elif kind == "lt":
                self.h = (self.h - node[1].value(counter)) % 360
                self.add((self.x, self.y, self.x, self.y, None, self.width, self.h), line)
            elif kind == "pu":
                self.pen = False
            elif kind == "pd":
                self.pen = True
            elif kind == "width":
                self.width = max(1.0, min(20.0, node[1].value(counter)))
            elif kind == "color":
                self.color = random.choice(RANDOM_COLORS) if node[1] == "random" else node[1]
            elif kind == "home":
                self.add((self.x, self.y, 0.0, 0.0, None, self.width, 0.0), line)
                self.x, self.y, self.h = 0.0, 0.0, 0.0
            elif kind == "clear":
                self.segs.append(None)
            elif kind == "repeat":
                expr, inner = node[1]
                n = int(expr.value(counter))
                if n < 0 or n > 10000:
                    raise LogoError(line, "err_repeat", str(n))
                for i in range(n):
                    self.run(inner, procs, i + 1)
            elif kind == "call":
                name = node[1]
                if name not in procs:
                    raise LogoError(line, "err_unknown", node[3])
                self.depth += 1
                if self.depth > 40:
                    raise LogoError(line, "err_deep", node[3])
                self.run(procs[name], procs, counter)
                self.depth -= 1

    def add(self, seg, line):
        if len(self.segs) >= MAX_SEGMENTS:
            raise LogoError(line, "err_long")
        self.segs.append(seg)


def execute(lines):
    """Returns (segments, None) or (None, LogoError)."""
    try:
        body, procs = parse(lines)
        r = Run()
        r.run(body, procs, 1)
        return r.segs, None
    except LogoError as e:
        return None, e
