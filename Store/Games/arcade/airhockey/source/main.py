# Air Hockey: a fast table game for one player against the console or two players on one Switch.
# Player 1 (red, left): touch / mouse on the left half, left stick or WASD.
# Player 2 (blue, right): right stick, arrow keys, or touch on the right half (the SDK reports one pointer,
# so two players share the controller sticks: hold the console flat, one Joy-Con stick each).
import math
import random

TW, TH = 2.0, 1.0          # table size in table units
PR, MR = 0.036, 0.062      # puck and mallet radius
GOAL = 0.34                # goal mouth height
WIN = 7
MAX_PUCK = 3.4
PLAYER_SPEED = 2.6
CPU = [  # speed, reaction delay, aim error
    {"speed": 1.0, "react": 0.28, "err": 0.10},
    {"speed": 1.55, "react": 0.14, "err": 0.05},
    {"speed": 2.2, "react": 0.05, "err": 0.015},
]
RED, BLUE = "#FF3B30", "#0A84FF"
CONFETTI = ["#FF3B30", "#FFD60A", "#30D158", "#0A84FF", "#BF5AF2"]


def uniform(a, b):
    return a + (b - a) * random.random()


def clamp(v, lo, hi):
    return lo if v < lo else (hi if v > hi else v)


class Mallet:
    def __init__(self, x, y, left):
        self.x, self.y = x, y
        self.vx, self.vy = 0.0, 0.0
        self.left = left
        self.squash = 0.0

    def move_to(self, tx, ty, speed, dt):
        lo, hi = (MR, TW / 2 - MR) if self.left else (TW / 2 + MR, TW - MR)
        tx, ty = clamp(tx, lo, hi), clamp(ty, MR, TH - MR)
        dx, dy = tx - self.x, ty - self.y
        d = math.sqrt(dx * dx + dy * dy)
        step = speed * dt
        if d > step and d > 0:
            dx, dy = dx / d * step, dy / d * step
        nx, ny = self.x + dx, self.y + dy
        self.vx, self.vy = (nx - self.x) / max(dt, 0.001), (ny - self.y) / max(dt, 0.001)
        self.x, self.y = nx, ny


class AirHockey:
    def __init__(self):
        self.screen = "title"
        self.mode = 0            # 0 = vs CPU, 1 = two players
        self.diff = 1
        self.stats = {}
        self.paused = False
        self.keys = {}
        self.ptr = None          # (x, y) in window pixels while pressed
        self.rect = (0.0, 0.0, 1.0, 1.0, 1.0)   # table x, y, w, h, scale
        self.parts = []
        self.trail = []
        self.shake = 0.0
        self.flash = 0.0
        self.banner = ""
        self.banner_t = 0.0
        self.t = 0.0
        self.p1 = Mallet(0.3, 0.5, True)
        self.p2 = Mallet(1.7, 0.5, False)
        self.px, self.py, self.pvx, self.pvy = 1.0, 0.5, 0.0, 0.0
        self.s1, self.s2 = 0, 0
        self.serve_t = 0.0
        self.still_t = 0.0
        self.cpu_t = 0.0
        self.cpu_target = (1.8, 0.5)
        self.hits = 0
        self.max_speed = 0.0
        self.new_best = False
        self.demo = [1.0, 0.5, 0.9, 0.6]

    # ------------------------------------------------------------------ setup
    def load(self, arg):
        s = store.get("stats", {})
        self.stats = s if type(s) is dict else {}
        self.diff = clamp(int(store.get("diff", 1)), 0, 2)
        self.mode = clamp(int(store.get("mode", 0)), 0, 1)

    def stat(self, key):
        v = self.stats.get(key, 0)
        return v if type(v) in (int, float) else 0

    def add_stat(self, key, n=1):
        self.stats[key] = self.stat(key) + n
        store.set("stats", self.stats)

    def start(self):
        self.s1, self.s2 = 0, 0
        self.p1 = Mallet(0.3, 0.5, True)
        self.p2 = Mallet(1.7, 0.5, False)
        self.hits, self.max_speed = 0, 0.0
        self.parts = []
        self.serve(random.random() < 0.5)
        self.paused = False
        self.screen = "play"
        self.banner, self.banner_t = TR("ready"), 1.0
        audio.tone(523, 0.12, 0.4, "triangle")

    def serve(self, to_left):
        self.px = TW / 2 - 0.35 if to_left else TW / 2 + 0.35
        self.py = 0.5
        self.pvx, self.pvy = 0.0, 0.0
        self.trail = []
        self.serve_t = 0.8

    # ------------------------------------------------------------------ effects
    def burst(self, x, y, color, n, power):
        for i in range(n):
            a = random.random() * math.pi * 2
            sp = (0.2 + random.random()) * power
            self.parts.append([x, y, math.cos(a) * sp, math.sin(a) * sp, 0.4 + random.random() * 0.5, color])

    def confetti(self):
        for i in range(90):
            self.parts.append([TW / 2 + uniform(-0.3, 0.3), 0.15, uniform(-1.4, 1.4),
                               uniform(-1.6, -0.3), 2.0 + random.random(), CONFETTI[i % 5], True])

    # ------------------------------------------------------------------ input
    def to_table(self, x, y):
        tx, ty, tw, th, s = self.rect
        return (x - tx) / s, (y - ty) / s

    def event(self, e):
        if e.type == "mousedown" or (e.type == "mousemove" and self.ptr is not None):
            self.ptr = (e.x, e.y)
        elif e.type == "mouseup":
            self.ptr = None
        elif e.type == "keydown":
            self.keys[e.key] = True
            self.on_key(e.key)
        elif e.type == "keyup":
            self.keys[e.key] = False
        elif e.type == "paddown":
            if e.pad == "plus" and self.screen == "play":
                self.paused = not self.paused
            elif e.pad == "a":
                self.on_key("enter")
            elif e.pad == "b":
                self.on_key("escape")
            elif e.pad in ("left", "right", "x"):
                self.on_key("tab" if e.pad == "x" else e.pad)

    def on_key(self, k):
        if self.screen == "play":
            if k in ("escape", "p"):
                self.paused = not self.paused
            elif k == "enter" and self.paused:
                self.paused = False
        elif self.screen == "result":
            if k == "enter":
                self.start()
            elif k == "escape":
                self.screen = "title"
        elif k == "enter" or k == "space":
            self.start()
        elif k == "tab":
            self.mode = 1 - self.mode
            store.set("mode", self.mode)
        elif k in ("left", "right") and self.mode == 0:
            self.diff = clamp(self.diff + (1 if k == "right" else -1), 0, 2)
            store.set("diff", self.diff)

    def held(self, *names):
        for n in names:
            if self.keys.get(n):
                return True
        return False

    # ------------------------------------------------------------------ simulation
    def update(self, dt):
        self.t += dt
        dt = min(dt, 1 / 30)
        self.shake = max(0.0, self.shake - dt)
        self.flash = max(0.0, self.flash - dt)
        self.banner_t = max(0.0, self.banner_t - dt)
        alive = []
        for p in self.parts:
            p[4] -= dt
            if p[4] > 0:
                p[0] += p[2] * dt
                p[1] += p[3] * dt
                if len(p) > 6:
                    p[3] += 2.2 * dt
                alive.append(p)
        self.parts = alive
        if self.screen == "title":
            d = self.demo
            d[0] += d[2] * dt
            d[1] += d[3] * dt
            if d[0] < 0.1 or d[0] > 1.9:
                d[2] = -d[2]
            if d[1] < 0.1 or d[1] > 0.9:
                d[3] = -d[3]
            return
        if self.screen != "play" or self.paused:
            return
        self.control_player1(dt)
        if self.mode == 0:
            self.control_cpu(dt)
        else:
            self.control_player2(dt)
        if self.serve_t > 0:
            self.serve_t -= dt
            return
        steps = 4
        for i in range(steps):
            if self.physics(dt / steps):
                break
        # dead puck: stuck almost still for 5 seconds -> serve again on the same half
        if self.pvx * self.pvx + self.pvy * self.pvy < 0.01:
            self.still_t += dt
            if self.still_t > 5:
                self.still_t = 0.0
                self.serve(self.px < TW / 2)
                self.banner, self.banner_t = TR("reserve"), 1.0
        else:
            self.still_t = 0.0
        self.trail.append((self.px, self.py))
        if len(self.trail) > 10:
            self.trail.pop(0)

    def control_player1(self, dt):
        m = self.p1
        if self.ptr is not None:
            x, y = self.to_table(self.ptr[0], self.ptr[1])
            if x <= TW / 2 or self.mode == 0:
                m.move_to(x, y, 7.0, dt)
                return
        sx, sy = input.stick("left")
        kx = (1 if self.held("d") else 0) - (1 if self.held("a") else 0)
        ky = (1 if self.held("s") else 0) - (1 if self.held("w") else 0)
        if self.mode == 0:   # one player: the arrow keys / D-pad steer player 1 too
            kx += (1 if self.held("right") else 0) - (1 if self.held("left") else 0)
            ky += (1 if self.held("down") else 0) - (1 if self.held("up") else 0)
        vx, vy = clamp(sx + kx, -1, 1), clamp(-sy + ky, -1, 1)
        m.move_to(m.x + vx * PLAYER_SPEED * dt, m.y + vy * PLAYER_SPEED * dt, PLAYER_SPEED, dt)

    def control_player2(self, dt):
        m = self.p2
        if self.ptr is not None:
            x, y = self.to_table(self.ptr[0], self.ptr[1])
            if x > TW / 2:
                m.move_to(x, y, 7.0, dt)
                return
        sx, sy = input.stick("right")
        kx = (1 if self.held("right") else 0) - (1 if self.held("left") else 0)
        ky = (1 if self.held("down") else 0) - (1 if self.held("up") else 0)
        vx, vy = clamp(sx + kx, -1, 1), clamp(-sy + ky, -1, 1)
        m.move_to(m.x + vx * PLAYER_SPEED * dt, m.y + vy * PLAYER_SPEED * dt, PLAYER_SPEED, dt)

    def control_cpu(self, dt):
        c = CPU[self.diff]
        m = self.p2
        self.cpu_t -= dt
        if self.cpu_t <= 0:
            self.cpu_t = c["react"]
            err = uniform(-c["err"], c["err"])
            if self.px > TW / 2 - 0.05:
                if self.px > m.x - 0.02:       # puck got behind: go around it
                    self.cpu_target = (self.px + 0.16, self.py + (0.14 if self.py < m.y else -0.14))
                else:                          # strike towards the left goal
                    aim = 0.5 - self.py
                    self.cpu_target = (self.px + 0.03, self.py - aim * 0.08 + err)
            else:                              # defend: stay between puck and goal
                py = self.py
                if self.pvx > 0.05:
                    t = (TW - 0.2 - self.px) / self.pvx
                    py = self.py + self.pvy * min(t, 1.0)
                    while py < 0 or py > TH:
                        py = -py if py < 0 else 2 * TH - py
                self.cpu_target = (TW - 0.2, clamp(py + err, 0.5 - GOAL / 2, 0.5 + GOAL / 2))
        m.move_to(self.cpu_target[0], self.cpu_target[1], c["speed"], dt)

    def physics(self, dt):
        self.px += self.pvx * dt
        self.py += self.pvy * dt
        f = 0.82 ** dt
        self.pvx, self.pvy = self.pvx * f, self.pvy * f
        for m in (self.p1, self.p2):
            self.collide(m)
        in_mouth = abs(self.py - 0.5) < GOAL / 2 - PR * 0.5
        # walls (after the mallets, so a mallet can never push the puck through a wall)
        if self.py < PR:
            self.py, self.pvy = PR, abs(self.pvy) * 0.92
            self.wall_hit()
        elif self.py > TH - PR:
            self.py, self.pvy = TH - PR, -abs(self.pvy) * 0.92
            self.wall_hit()
        if not in_mouth:
            if self.px < PR:
                self.px, self.pvx = PR, abs(self.pvx) * 0.92
                self.wall_hit()
            elif self.px > TW - PR:
                self.px, self.pvx = TW - PR, -abs(self.pvx) * 0.92
                self.wall_hit()
        # goals
        if self.px < -PR:
            self.goal(False)
            return True
        if self.px > TW + PR:
            self.goal(True)
            return True
        # a puck pinned against a wall pushes the mallet back instead
        for m in (self.p1, self.p2):
            dx, dy = m.x - self.px, m.y - self.py
            d = math.sqrt(dx * dx + dy * dy)
            if d < PR + MR:
                if d < 0.0001:
                    dx, dy, d = (-1.0 if m.left else 1.0), 0.0, 1.0
                m.x, m.y = self.px + dx / d * (PR + MR), self.py + dy / d * (PR + MR)
        return False

    def collide(self, m):
        dx, dy = self.px - m.x, self.py - m.y
        d = math.sqrt(dx * dx + dy * dy)
        if d >= PR + MR or d < 0.0001:
            return
        nx, ny = dx / d, dy / d
        self.px, self.py = m.x + nx * (PR + MR), m.y + ny * (PR + MR)
        rvx, rvy = self.pvx - m.vx, self.pvy - m.vy
        vn = rvx * nx + rvy * ny
        if vn >= 0:
            return
        self.pvx -= 1.9 * vn * nx
        self.pvy -= 1.9 * vn * ny
        sp = math.sqrt(self.pvx * self.pvx + self.pvy * self.pvy)
        if sp > MAX_PUCK:
            self.pvx, self.pvy = self.pvx / sp * MAX_PUCK, self.pvy / sp * MAX_PUCK
            sp = MAX_PUCK
        self.max_speed = max(self.max_speed, sp)
        if sp > 0.25:
            self.hits += 1
            m.squash = 0.18
            audio.tone(300 + int(sp * 4) * 40, 0.05, min(0.6, 0.2 + sp * 0.12), "square")
            self.burst(self.px, self.py, RED if m.left else BLUE, 6, 0.5 + sp * 0.2)
        if sp > 2.4:
            self.shake = 0.12
            sys.vibrate(0.3, 40)

    def wall_hit(self):
        sp = math.sqrt(self.pvx * self.pvx + self.pvy * self.pvy)
        if sp > 0.3:
            audio.tone(180 + int(sp * 4) * 15, 0.03, min(0.4, sp * 0.1), "triangle")

    def goal(self, left_scored):
        if left_scored:
            self.s1 += 1
        else:
            self.s2 += 1
        self.add_stat("goals", 1)
        self.flash, self.shake = 0.5, 0.35
        self.burst(TW if left_scored else 0.0, 0.5, RED if left_scored else BLUE, 40, 1.4)
        audio.tone(880, 0.12, 0.5, "square")
        audio.play("notify")
        sys.vibrate(0.6, 120)
        self.banner, self.banner_t = TR("goal"), 1.2
        if self.s1 >= WIN or self.s2 >= WIN:
            self.finish()
        else:
            self.serve(left_scored is False)

    def finish(self):
        p1won = self.s1 > self.s2
        self.new_best = False
        if self.mode == 0:
            key = "d" + str(self.diff)
            self.add_stat(key + "_played", 1)
            if p1won:
                self.add_stat(key + "_won", 1)
                margin = self.s1 - self.s2
                if margin > self.stat(key + "_margin"):
                    self.stats[key + "_margin"] = margin
                    store.set("stats", self.stats)
                    self.new_best = True
        else:
            self.add_stat("pvp", 1)
        if p1won or self.mode == 1:
            self.confetti()
        self.screen = "result"

    # ------------------------------------------------------------------ drawing
    def draw_table(self, w, h, top):
        avail_w, avail_h = w - 40, h - top - 16
        s = min(avail_w / TW, avail_h / TH)
        tw, th = TW * s, TH * s
        tx, ty = (w - tw) / 2, top + (avail_h - th) / 2
        if self.shake > 0:
            tx += uniform(-1, 1) * self.shake * 30
            ty += uniform(-1, 1) * self.shake * 30
        self.rect = (tx, ty, tw, th, s)
        ice = "#0F1C2B" if theme.dark else "#EAF4FF"
        line = "#FFFFFF22" if theme.dark else "#1C3A5A22"
        gfx.shadow(tx - 10, ty - 10, tw + 20, th + 20, 22, 18, 4)
        gfx.rect(tx - 10, ty - 10, tw + 20, th + 20, 22, "#3A3A44" if theme.dark else "#C9D6E3")
        gfx.rect(tx, ty, tw, th, 14, ice)
        gfx.color(line)
        gfx.line(tx + tw / 2, ty + 4, tx + tw / 2, ty + th - 4, 3)
        gfx.circleLine(tx + tw / 2, ty + th / 2, th * 0.18, 3)
        gfx.color(RED + "40")
        gfx.arc(tx, ty + th / 2, th * 0.26, -math.pi / 2, math.pi / 2, 3)
        gfx.color(BLUE + "40")
        gfx.arc(tx + tw, ty + th / 2, th * 0.26, math.pi / 2, math.pi * 1.5, 3)
        gy = ty + th * (0.5 - GOAL / 2)
        gfx.rect(tx - 9, gy, 12, th * GOAL, 4, "#111114")
        gfx.rect(tx + tw - 3, gy, 12, th * GOAL, 4, "#111114")
        gfx.rect(tx - 9, gy, 4, th * GOAL, 2, RED)
        gfx.rect(tx + tw + 5, gy, 4, th * GOAL, 2, BLUE)
        return tx, ty, s

    def draw_mallet(self, m, tx, ty, s, color):
        r = MR * s * (1 - m.squash * 0.5)
        x, y = tx + m.x * s, ty + m.y * s
        gfx.circle(x + 2, y + 4, r, "#00000033")
        gfx.circle(x, y, r, color)
        gfx.circle(x, y, r * 0.72, "#FFFFFF30")
        gfx.circle(x, y, r * 0.42, color)
        gfx.circle(x - r * 0.12, y - r * 0.14, r * 0.18, "#FFFFFF70")

    def draw_play(self, w, h):
        top = 52
        # score bar
        gfx.color(RED)
        gfx.text(str(self.s1), 0, 6, 32, "bold", "right", w / 2 - 40)
        gfx.color(BLUE)
        gfx.text(str(self.s2), w / 2 + 40, 6, 32, "bold")
        gfx.color(theme.text2)
        gfx.text(":", 0, 8, 28, "bold", "center", w)
        names = TR("you") if self.mode == 0 else TR("player1")
        gfx.text(names, 20, 18, 13, "semibold")
        right = TR("cpu_" + str(self.diff)) if self.mode == 0 else TR("player2")
        gfx.text(right, 0, 18, 13, "semibold", "right", w - 64)
        if ui.iconButton("pause", w - 52, 8, 36, 34):
            self.paused = True
        tx, ty, s = self.draw_table(w, h, top)
        for i in range(len(self.trail)):
            p = self.trail[i]
            gfx.alpha((i + 1) / len(self.trail) * 0.35)
            gfx.circle(tx + p[0] * s, ty + p[1] * s, PR * s * (0.5 + 0.5 * (i + 1) / len(self.trail)), theme.text3)
            gfx.unalpha()
        self.draw_mallet(self.p1, tx, ty, s, RED)
        self.draw_mallet(self.p2, tx, ty, s, BLUE)
        self.p1.squash = max(0.0, self.p1.squash - 0.02)
        self.p2.squash = max(0.0, self.p2.squash - 0.02)
        px, py = tx + self.px * s, ty + self.py * s
        gfx.circle(px + 2, py + 3, PR * s, "#00000033")
        gfx.circle(px, py, PR * s, "#1C1C1E" if not theme.dark else "#F2F2F7")
        gfx.circleLine(px, py, PR * s * 0.65, 2)
        self.draw_parts(tx, ty, s)
        if self.flash > 0:
            gfx.alpha(self.flash)
            gfx.rect(tx, ty, TW * s, TH * s, 14, "#FFFFFF55")
            gfx.unalpha()
        if self.banner_t > 0:
            a = min(1.0, self.banner_t * 3)
            size = 48 + (1.2 - self.banner_t) * 20
            gfx.alpha(a)
            gfx.color("#FFFFFF" if theme.dark else "#1C1C1E")
            gfx.text(self.banner, 0, ty + TH * s / 2 - size * 0.6, size, "bold", "center", w)
            gfx.unalpha()
        if self.paused:
            self.draw_pause(w, h)

    def draw_parts(self, tx, ty, s):
        for p in self.parts:
            gfx.alpha(min(1.0, p[4] * 2))
            gfx.circle(tx + p[0] * s, ty + p[1] * s, 4 if len(p) > 6 else 3, p[5])
            gfx.unalpha()

    def draw_pause(self, w, h):
        gfx.rect(0, 0, w, h, 0, "#00000088")
        pw, ph = 300, 214
        x, y = (w - pw) / 2, (h - ph) / 2
        gfx.shadow(x, y, pw, ph, 16, 18, 4)
        gfx.rect(x, y, pw, ph, 16, theme.window)
        gfx.color(theme.text)
        gfx.text(TR("paused"), x, y + 18, 20, "bold", "center", pw)
        if ui.button(TR("resume"), x + 30, y + 60, pw - 60, 36, "primary", "play_arrow"):
            self.paused = False
        if ui.button(TR("restart"), x + 30, y + 106, pw - 60, 36, "default", "refresh"):
            self.start()
        if ui.button(TR("menu"), x + 30, y + 152, pw - 60, 36, "default", "home"):
            self.paused = False
            self.screen = "title"

    def draw_title(self, w, h):
        tx, ty, s = self.draw_table(w, h, 12)
        d = self.demo
        gfx.alpha(0.5)
        gfx.circle(tx + d[0] * s, ty + d[1] * s, PR * s, theme.text2)
        gfx.unalpha()
        pw, ph = min(440, w - 40), 300
        x, y = (w - pw) / 2, (h - ph) / 2
        gfx.shadow(x, y, pw, ph, 18, 20, 4)
        gfx.rect(x, y, pw, ph, 18, theme.window)
        gfx.color(theme.text)
        gfx.text(TR("app_name"), x, y + 18, 28, "bold", "center", pw)
        gfx.color(theme.text2)
        gfx.text(TR("first_to", WIN), x, y + 56, 13, "sans", "center", pw)
        m = ui.segmented("mode", [TR("vs_cpu"), TR("two_players")], self.mode, x + 24, y + 84, pw - 48, 32)
        if m != self.mode:
            self.mode = m
            store.set("mode", m)
        if self.mode == 0:
            dsel = ui.segmented("diff", [TR("easy"), TR("normal"), TR("hard")], self.diff, x + 24, y + 126, pw - 48, 30)
            if dsel != self.diff:
                self.diff = dsel
                store.set("diff", dsel)
            key = "d" + str(self.diff)
            gfx.color(theme.text2)
            gfx.text(TR("record", self.stat(key + "_won"), self.stat(key + "_played"), self.stat(key + "_margin")),
                     x, y + 168, 13, "sans", "center", pw)
        else:
            gfx.color(theme.text2)
            gfx.wrap(TR("two_help"), x + 24, y + 128, pw - 48, 13, "sans", "center")
        if ui.button(TR("play"), x + pw / 2 - 90, y + 200, 180, 40, "primary", "play_arrow"):
            self.start()
        gfx.color(theme.text3)
        gfx.wrap(TR("controls"), x + 20, y + 252, pw - 40, 12, "sans", "center")

    def draw_result(self, w, h):
        tx, ty, s = self.draw_table(w, h, 12)
        self.draw_parts(tx, ty, s)
        pw, ph = min(420, w - 40), 270
        x, y = (w - pw) / 2, (h - ph) / 2
        gfx.shadow(x, y, pw, ph, 18, 20, 4)
        gfx.rect(x, y, pw, ph, 18, theme.window)
        p1won = self.s1 > self.s2
        if self.mode == 0:
            title = TR("you_win") if p1won else TR("you_lose")
        else:
            title = TR("p1_wins") if p1won else TR("p2_wins")
        gfx.color(RED if p1won else BLUE)
        gfx.text(title, x, y + 20, 26, "bold", "center", pw)
        gfx.color(theme.text)
        gfx.text(str(self.s1) + " : " + str(self.s2), x, y + 60, 34, "bold", "center", pw)
        gfx.color(theme.text2)
        gfx.text(TR("hits", self.hits), x, y + 110, 13, "sans", "center", pw)
        gfx.text(TR("top_speed", int(self.max_speed * 100)), x, y + 130, 13, "sans", "center", pw)
        if self.new_best:
            gfx.color(theme.orange)
            gfx.text(TR("new_best"), x, y + 154, 14, "bold", "center", pw)
        bw = (pw - 60) / 2
        if ui.button(TR("rematch"), x + 20, y + 196, bw, 38, "primary", "refresh"):
            self.start()
        if ui.button(TR("menu"), x + 40 + bw, y + 196, bw, 38, "default", "home"):
            self.screen = "title"

    def draw(self, w, h):
        gfx.clear(theme.bg)
        if self.screen == "play":
            self.draw_play(w, h)
        elif self.screen == "result":
            self.draw_result(w, h)
        else:
            self.draw_title(w, h)

    def menu(self):
        return [{"title": TR("app_name"), "items": [
            {"label": TR("new_game"), "id": 1, "shortcut": "Enter"},
            {"label": TR("pause"), "id": 2, "shortcut": "Esc"},
            "-",
            {"label": TR("reset_stats"), "id": 3},
        ]}]

    def onmenu(self, item_id):
        if item_id == 1:
            self.start()
        elif item_id == 2 and self.screen == "play":
            self.paused = not self.paused
        elif item_id == 3:
            ui.alert(TR("reset_stats"), TR("reset_msg"), [TR("reset"), TR("common.cancel")], self.on_reset)

    def on_reset(self, button):
        if button == 0:
            self.stats = {}
            store.set("stats", self.stats)

    def close(self):
        store.save()
        return True


app = AirHockey()
