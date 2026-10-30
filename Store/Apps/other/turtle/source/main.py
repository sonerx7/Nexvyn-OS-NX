# Turtle Graphics: write small programs with Turkish or English commands and watch the turtle draw them.
# The language lives in logo.py; this file is the editor, the animated canvas and the script library.
import math
import logo

SPEEDS = [1, 2, 3, 5, 8, 15, 30, 60, 150, 100000]
EXAMPLES = [
    ("ex_square", ["; kare", "renk mavi", "kalınlık 3", "tekrarla 4 [ ileri 150 sağ 90 ]"]),
    ("ex_star", ["renk sarı", "kalınlık 3", "tekrarla 5 [ ileri 220 sağ 144 ]"]),
    ("ex_spiral", ["renk açıkmavi", "tekrarla 120 [ ileri sayaç*2 sağ 91 ]"]),
    ("ex_flower", ["yap yaprak", "  tekrarla 2 [ tekrarla 18 [ ileri 6 sağ 5 ] sağ 90 ]", "son",
                   "tekrarla 12 [ renk rastgele yaprak sağ 30 ]", "renk yeşil", "kalınlık 4", "sağ 180",
                   "ileri 160"]),
    ("ex_snow", ["yap dal", "  ileri 60",
                 "  tekrarla 3 [ sol 40 ileri 25 geri 25 sağ 80 ileri 25 geri 25 sol 40 ileri 20 ]",
                 "  geri 120", "son", "renk açıkmavi", "kalınlık 2", "tekrarla 6 [ dal sağ 60 ]"]),
    ("ex_squares", ["tekrarla 36 [ renk rastgele tekrarla 4 [ ileri 120 sağ 90 ] sağ 10 ]"]),
    ("ex_english", ["to petal", "  repeat 36 [ forward 4 right 5 ]", "  right 180",
                    "  repeat 36 [ forward 4 right 5 ]", "end", "color purple",
                    "repeat 8 [ petal right 45 ]"]),
]


class Turtle:
    def __init__(self):
        self.scripts = []
        self.cur = 0
        self.sel = 0
        self.speed = 6
        self.segs = []
        self.polys = []
        self.clears = []
        self.shown = 0
        self.running = False
        self.error = None
        self.err_line_no = -1
        self.view_key = ""
        self.zoom, self.ox, self.oy = 1.0, 0.0, 0.0
        self.toast, self.toast_t = "", 0.0
        self.undo = None
        self.canvas = (0, 0, 1, 1)

    # ------------------------------------------------------------------ storage
    def load(self, arg):
        s = store.get("scripts", None)
        if type(s) is list and len(s) > 0:
            for it in s:
                if type(it) is dict and type(it.get("lines")) is list:
                    self.scripts.append({"name": str(it.get("name", "?")), "lines": [str(x) for x in it["lines"]]})
        if len(self.scripts) == 0:
            for key, lines in EXAMPLES[3:4] + EXAMPLES[0:1]:
                self.scripts.append({"name": TR(key), "lines": list(lines)})
        self.cur = max(0, min(len(self.scripts) - 1, int(store.get("cur", 0))))
        self.speed = max(1, min(10, int(store.get("speed", 6))))
        self.run(True)

    def save(self):
        store.set("scripts", self.scripts)
        store.set("cur", self.cur)

    def lines(self):
        if self.cur >= len(self.scripts):
            self.cur = 0
        return self.scripts[self.cur]["lines"]

    def show_toast(self, s):
        self.toast, self.toast_t = s, 2.4

    # ------------------------------------------------------------------ running
    def run(self, instant=False):
        segs, err = logo.execute(self.lines())
        if err is not None:
            self.error = TR("error_line", err.line, TR(err.key, err.arg))
            self.err_line_no = err.line
            self.running = False
            audio.play("error")
            return
        self.error = None
        self.segs = segs
        self.build()
        self.shown = len(segs) if instant else 0
        self.running = not instant
        self.view_key = ""

    def build(self):
        self.polys, self.clears = [], []
        cur = None
        minx, miny, maxx, maxy = 0.0, 0.0, 0.0, 0.0
        for i in range(len(self.segs)):
            s = self.segs[i]
            if s is None:
                self.clears.append(i)
                cur = None
                continue
            x1, y1, x2, y2, color, width = s[0], s[1], s[2], s[3], s[4], s[5]
            minx, maxx = min(minx, x1, x2), max(maxx, x1, x2)
            miny, maxy = min(miny, y1, y2), max(maxy, y1, y2)
            if color is None:
                if x1 != x2 or y1 != y2:
                    cur = None
                continue
            if cur is not None and cur["color"] == color and cur["width"] == width and \
                    cur["pts"][-2] == x1 and cur["pts"][-1] == y1:
                cur["pts"].append(x2)
                cur["pts"].append(y2)
                cur["idx"].append(i)
            else:
                cur = {"color": color, "width": width, "pts": [x1, y1, x2, y2], "idx": [i, i], "scr": None}
                self.polys.append(cur)
        self.bounds = (minx, miny, maxx, maxy)

    def stop(self):
        self.running = False
        self.shown = len(self.segs)

    def update(self, dt):
        if self.toast_t > 0:
            self.toast_t -= dt
        if self.running:
            self.shown = min(len(self.segs), self.shown + SPEEDS[self.speed - 1])
            if self.shown >= len(self.segs):
                self.running = False

    # ------------------------------------------------------------------ editing
    def set_line(self, i, text):
        ls = self.lines()
        if 0 <= i < len(ls) and ls[i] != text:
            ls[i] = text
            self.save()

    def insert_line(self):
        ls = self.lines()
        at = min(len(ls), self.sel + 1)
        ls.insert(at, "")
        self.sel = at
        self.save()
        ui.focus("line")

    def delete_line(self):
        ls = self.lines()
        if len(ls) == 0:
            return
        if 0 <= self.sel < len(ls):
            self.undo = ("line", self.cur, self.sel, ls.pop(self.sel))
            self.sel = max(0, min(self.sel, len(ls) - 1))
            self.save()

    def move_line(self, d):
        ls = self.lines()
        j = self.sel + d
        if 0 <= self.sel < len(ls) and 0 <= j < len(ls):
            ls[self.sel], ls[j] = ls[j], ls[self.sel]
            self.sel = j
            self.save()

    def new_script(self, name, lines):
        self.scripts.append({"name": name, "lines": list(lines)})
        self.cur = len(self.scripts) - 1
        self.sel = 0
        self.save()
        self.run(False)

    def on_example(self, item_id):
        if item_id is not None and 0 <= item_id < len(EXAMPLES):
            key, lines = EXAMPLES[item_id]
            self.new_script(TR(key), lines)

    def on_rename(self, text):
        if text is not None and text.strip() != "" and self.cur < len(self.scripts):
            self.scripts[self.cur]["name"] = text.strip()[:30]
            self.save()

    def on_delete(self, button):
        if button == 0 and len(self.scripts) > 1:
            self.undo = ("script", self.cur, self.scripts.pop(self.cur))
            self.cur = max(0, self.cur - 1)
            self.sel = 0
            self.save()
            self.run(True)
            self.show_toast(TR("deleted"))

    def do_undo(self):
        u = self.undo
        if u is None:
            return
        self.undo = None
        if u[0] == "line" and u[1] < len(self.scripts):
            ls = self.scripts[u[1]]["lines"]
            ls.insert(min(u[2], len(ls)), u[3])
        elif u[0] == "script":
            self.scripts.insert(min(u[1], len(self.scripts)), u[2])
            self.cur = min(u[1], len(self.scripts) - 1)
        self.save()

    # ------------------------------------------------------------------ drawing
    def fit(self, cw, ch):
        minx, miny, maxx, maxy = self.bounds if len(self.segs) > 0 else (-100, -100, 100, 100)
        bw, bh = max(40.0, maxx - minx), max(40.0, maxy - miny)
        self.zoom = max(0.05, min(2.0, min((cw - 40) / bw, (ch - 40) / bh)))
        self.ox, self.oy = -(minx + maxx) / 2, -(miny + maxy) / 2

    def draw_canvas(self, x, y, w, h):
        self.canvas = (x, y, w, h)
        gfx.rect(x, y, w, h, 12, "#101418" if theme.dark else "#FBFBFD")
        gfx.color(theme.separator)
        gfx.rectLine(x, y, w, h, 12, 1)
        key = str(w) + "," + str(h) + "," + str(len(self.segs)) + "," + str(self.cur)
        if key != self.view_key:
            self.view_key = key
            self.fit(w, h)
            for p in self.polys:
                p["scr"] = None
        cx, cy, z = x + w / 2, y + h / 2, self.zoom
        last_clear = -1
        for c in self.clears:
            if c < self.shown:
                last_clear = c
        gfx.clip(x, y, w, h)
        for p in self.polys:
            idx = p["idx"]
            if idx[0] >= self.shown or idx[-1] < last_clear:
                continue
            scr = p["scr"]
            if scr is None:
                pts = p["pts"]
                scr = []
                for i in range(0, len(pts), 2):
                    scr.append(cx + (pts[i] + self.ox) * z)
                    scr.append(cy - (pts[i + 1] + self.oy) * z)
                p["scr"] = scr
            gfx.color(p["color"])
            width = max(1.0, p["width"] * min(1.5, max(0.6, z)))
            if idx[-1] < self.shown:
                gfx.lines(scr, width)
            else:
                n = 1
                while n < len(idx) and idx[n] < self.shown:
                    n += 1
                if n >= 2:
                    gfx.lines(scr[:n * 2], width)
        self.draw_turtle(cx, cy, z)
        gfx.unclip()
        if len(self.segs) == 0 and self.error is None:
            gfx.icon("pets", x + w / 2, y + h / 2 - 20, 48, theme.text3)
            gfx.color(theme.text2)
            gfx.text(TR("empty_canvas"), x, y + h / 2 + 16, 14, "sans", "center", w)

    def draw_turtle(self, cx, cy, z):
        tx, ty, hd = 0.0, 0.0, 0.0
        k = self.shown - 1
        while k >= 0 and self.segs[k] is None:
            k -= 1
        if k >= 0:
            s = self.segs[k]
            tx, ty, hd = s[2], s[3], s[6]
        sx, sy = cx + (tx + self.ox) * z, cy - (ty + self.oy) * z
        r = hd * math.pi / 180
        fx, fy = math.sin(r), -math.cos(r)
        px, py = -fy, fx
        gfx.poly([sx + fx * 14, sy + fy * 14, sx - fx * 8 + px * 10, sy - fy * 8 + py * 10,
                  sx - fx * 8 - px * 10, sy - fy * 8 - py * 10], "#34C759")
        gfx.circle(sx + fx * 15, sy + fy * 15, 4, "#2A9D4A")

    def draw_editor(self, x, y, w, h):
        ls = self.lines()
        if self.sel >= len(ls):
            self.sel = max(0, len(ls) - 1)
        list_h = h - 92
        ui.group(x, y, w, list_h)
        rh = 28
        action = None
        ui.beginScroll("code", x, y, w, list_h, len(ls) * rh + 8)
        for i in range(len(ls)):
            ry = 4 + i * rh
            if ui.row("ln" + str(i), 4, ry, w - 8, rh, i == self.sel) > 0:
                action = i
            gfx.color(theme.text3)
            gfx.text(str(i + 1), 8, ry + 6, 12, "mono", "right", 26)
            err_here = self.error is not None and self.error_line() == i + 1
            gfx.color(theme.red if err_here else theme.text)
            gfx.text(ls[i] if ls[i] != "" else " ", 42, ry + 6, 13, "mono")
        ui.endScroll()
        if action is not None:
            self.sel = action
        if len(ls) == 0:
            gfx.color(theme.text3)
            gfx.text(TR("empty_script"), x, y + list_h / 2 - 8, 13, "sans", "center", w)
        fy = y + list_h + 10
        cur = ls[self.sel] if 0 <= self.sel < len(ls) else ""
        t = ui.textfield("line", cur, x, fy, w, 34, TR("line_hint"))
        if len(ls) == 0 and t != "":
            ls.append(t)
            self.sel = 0
            self.save()
        elif 0 <= self.sel < len(ls):
            self.set_line(self.sel, t)
        if ui.submitted("line"):
            self.insert_line()
        by = fy + 44
        bw = (w - 18) / 4
        if ui.button(TR("add_line"), x, by, bw, 32, "default", "add"):
            self.insert_line()
        if ui.button(TR("delete") + "##dl", x + bw + 6, by, bw, 32, "default", "backspace"):
            self.delete_line()
        if ui.iconButton("arrow_upward", x + 2 * (bw + 6), by, bw, 32, None, False, "up"):
            self.move_line(-1)
        if ui.iconButton("arrow_downward", x + 3 * (bw + 6), by, bw, 32, None, False, "dn"):
            self.move_line(1)

    def error_line(self):
        if self.error is None:
            return -1
        return self.err_line_no

    def draw(self, w, h):
        gfx.clear(theme.bg)
        names = [s["name"] for s in self.scripts]
        ns = ui.dropdown("script", names, self.cur, 16, 12, 180, 32)
        if ns != self.cur and 0 <= ns < len(self.scripts):
            self.cur = ns
            self.sel = 0
            self.save()
            self.run(True)
        if ui.iconButton("add", 202, 12, 34, 32, None, False, "new"):
            self.new_script(TR("new_name", len(self.scripts) + 1), [])
        if ui.iconButton("edit", 240, 12, 34, 32, None, False, "ren"):
            ui.prompt(TR("rename"), TR("rename_msg"), self.scripts[self.cur]["name"], self.on_rename)
        if ui.iconButton("delete", 278, 12, 34, 32, theme.red, False, "del") and len(self.scripts) > 1:
            ui.alert(TR("delete_script"), TR("delete_msg", self.scripts[self.cur]["name"]),
                     [TR("delete"), TR("common.cancel")], self.on_delete)
        if ui.button(TR("examples"), 320, 12, 130, 32, "default", "auto_stories"):
            items = []
            for i in range(len(EXAMPLES)):
                items.append({"label": TR(EXAMPLES[i][0]), "id": i})
            ui.contextMenu(items, self.on_example)
        gfx.color(theme.text2)
        gfx.text(TR("speed"), w - 386, 20, 12)
        sp = ui.slider("speed", self.speed, 1, 10, w - 336, 18, 110, 1)
        if sp != self.speed:
            self.speed = int(sp)
            store.set("speed", self.speed)
        if self.running:
            if ui.button(TR("stop"), w - 216, 12, 96, 32, "default", "stop"):
                self.stop()
        if ui.button(TR("run"), w - 112, 12, 96, 32, "primary", "play_arrow"):
            self.run(False)

        ew = max(280, min(380, w * 0.4))
        self.draw_editor(16, 56, ew, h - 72)
        cx = 16 + ew + 14
        ch = h - 72 - (36 if self.error is not None else 0)
        self.draw_canvas(cx, 56, w - cx - 16, ch)
        if self.error is not None:
            gfx.icon("error", cx + 12, h - 32, 18, theme.red)
            gfx.color(theme.red)
            gfx.text(self.error, cx + 28, h - 41, 13, "semibold")
        else:
            gfx.color(theme.text3)
            gfx.text(TR("steps", len(self.segs)), 0, h - 30, 11, "sans", "right", w - 24)
        if self.toast_t > 0:
            tw = gfx.textWidth(self.toast, 13) + 32
            gfx.alpha(min(1.0, self.toast_t * 3))
            gfx.rect(w / 2 - tw / 2, h - 60, tw, 32, 16, "#1C1C1EE6")
            gfx.color("#FFFFFF")
            gfx.text(self.toast, w / 2 - tw / 2, h - 52, 13, "semibold", "center", tw)
            gfx.unalpha()

    def event(self, e):
        if e.type != "keydown":
            return
        if e.ctrl and e.key == "z":
            self.do_undo()
        elif e.key == "f5" or (e.ctrl and e.key == "enter"):
            self.run(False)
        elif e.key == "escape":
            self.stop()
        elif e.key == "up" and self.sel > 0:
            self.sel -= 1
        elif e.key == "down" and self.sel < len(self.lines()) - 1:
            self.sel += 1

    def menu(self):
        ex = []
        for i in range(len(EXAMPLES)):
            ex.append({"label": TR(EXAMPLES[i][0]), "id": 100 + i})
        return [
            {"title": TR("app_name"), "items": [
                {"label": TR("run"), "id": 1, "shortcut": "F5"},
                {"label": TR("stop"), "id": 2, "shortcut": "Esc"},
                {"label": TR("undo"), "id": 3, "shortcut": "Ctrl+Z"},
                "-",
                {"label": TR("new_script"), "id": 4},
                {"label": TR("copy_script"), "id": 5},
                {"label": TR("help"), "id": 6},
            ]},
            {"title": TR("examples"), "items": ex},
        ]

    def onmenu(self, item_id):
        if item_id == 1:
            self.run(False)
        elif item_id == 2:
            self.stop()
        elif item_id == 3:
            self.do_undo()
        elif item_id == 4:
            self.new_script(TR("new_name", len(self.scripts) + 1), [])
        elif item_id == 5:
            sys.clipboard("\n".join(self.lines()))
            self.show_toast(TR("copied"))
        elif item_id == 6:
            ui.alert(TR("help"), TR("help_text"), [TR("common.ok")])
        elif item_id >= 100:
            self.on_example(item_id - 100)

    def close(self):
        self.save()
        store.save()
        return True


app = Turtle()
