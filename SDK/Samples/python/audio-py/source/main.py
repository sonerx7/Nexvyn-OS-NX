# Melody Player (Python): plays tunes note by note and shows how callbacks work in Nexvyn OS Python apps.
#
# What this file teaches:
#   1. timer.after(seconds, fn) chains: every note schedules the next one; timer.cancel(id) stops the chain
#   2. bound methods and lambdas as callbacks (no async/await in the console's Python: callbacks instead)
#   3. ui.prompt(title, message, text, callback) to type your own melody, ui.alert(..., callback) to answer it
#   4. a callback log that shows WHEN each callback ran (always later, on a following frame)
#   5. a piano roll drawn from the note list, with a smooth playhead between callbacks (update + sys.time)
#   6. Python SDK differences: 0-based ui.dropdown / ui.segmented / ui.alert, keyword arguments, store for saving
import melody

SONGS = [
    ("song_ode", "E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 E4:1.5 D4:0.5 D4:2 " +
                 "E4 E4 F4 G4 G4 F4 E4 D4 C4 C4 D4 E4 D4:1.5 C4:0.5 C4:2"),
    ("song_twinkle", "C4 C4 G4 G4 A4 A4 G4:2 F4 F4 E4 E4 D4 D4 C4:2 G4 G4 F4 F4 E4 E4 D4:2 " +
                     "G4 G4 F4 F4 E4 E4 D4:2 C4 C4 G4 G4 A4 A4 G4:2 F4 F4 E4 E4 D4 D4 C4:2"),
    ("song_jacques", "C4 D4 E4 C4 C4 D4 E4 C4 E4 F4 G4:2 E4 F4 G4:2 G4:0.5 A4:0.5 G4:0.5 F4:0.5 E4 C4 " +
                     "G4:0.5 A4:0.5 G4:0.5 F4:0.5 E4 C4 C4 G3 C4:2 C4 G3 C4:2"),
    ("song_elise", "E5:0.5 D#5:0.5 E5:0.5 D#5:0.5 E5:0.5 B4:0.5 D5:0.5 C5:0.5 A4:1.5 R:0.5 C4:0.5 E4:0.5 " +
                   "A4:0.5 B4:1.5 R:0.5 E4:0.5 G#4:0.5 B4:0.5 C5:1.5 R:0.5 E4:0.5 E5:0.5 D#5:0.5 E5:0.5 " +
                   "D#5:0.5 E5:0.5 B4:0.5 D5:0.5 C5:0.5 A4:2"),
]
WAVES = ["sine", "triangle", "square", "saw"]
DEFAULT_CUSTOM = "C4 E4 G4 C5:2 B4:0.5 G4:0.5 E4 C4:2"


class Player:
    def __init__(self):
        self.song = 0                 # index into SONGS; len(SONGS) = "My melody"
        self.custom = DEFAULT_CUSTOM
        self.notes = []
        self.starts = []              # beat where each note starts
        self.total = 0.0
        self.bpm = 112.0
        self.wave = 1
        self.loop = False
        self.playing = False
        self.index = -1               # the note sounding now
        self.note_at = 0.0            # sys.time() when it started
        self.pending = None           # id of the scheduled timer.after
        self.log = []                 # (time, text) of recent callbacks

    # ------------------------------------------------------------------ helpers
    def say(self, text):
        self.log.append((sys.time(), text))
        if len(self.log) > 6:
            self.log.pop(0)

    def song_names(self):
        return [TR(key) for key, _ in SONGS] + [TR("song_custom")]

    def select(self, i):
        self.stop()
        self.song = i
        text = self.custom if i == len(SONGS) else SONGS[i][1]
        notes, bad = melody.parse(text)
        self.set_notes(notes)
        store.set("song", i)

    def set_notes(self, notes):
        self.notes = notes
        self.starts = []
        beat = 0.0
        for _, beats in notes:
            self.starts.append(beat)
            beat += beats
        self.total = beat

    # ------------------------------------------------------------------ SDK callbacks
    def load(self, arg):
        self.custom = store.get("custom", DEFAULT_CUSTOM)
        self.bpm = store.get("bpm", 112.0)
        self.wave = store.get("wave", 1)
        self.select(store.get("song", 0))

    def update(self, dt):
        pass                          # having update() makes the window redraw every frame (smooth playhead)

    # ------------------------------------------------------------------ 1. + 2. the timer chain
    def play(self):
        self.stop()
        if not self.notes:
            return
        self.playing = True
        self.index = -1
        self.say(TR("log_play"))
        self.next_note()

    def stop(self):
        if self.pending is not None:
            timer.cancel(self.pending)  # the scheduled callback will never run
            self.pending = None
        if self.playing:
            self.say(TR("log_stop"))
        self.playing = False
        self.index = -1

    def next_note(self):
        # called directly for the first note, then by timer.after for every following one
        self.pending = None
        self.index += 1
        if self.index >= len(self.notes):
            if not self.loop:
                self.playing = False
                self.index = -1
                self.say(TR("log_end"))
                return
            self.index = 0
        midi, beats = self.notes[self.index]
        seconds = beats * 60.0 / self.bpm
        if midi is not None:
            # keyword arguments work for every SDK function
            audio.tone(melody.freq(midi), sec=seconds * 0.92, volume=0.45, wave=WAVES[self.wave])
        self.note_at = sys.time()
        # a bound method is a fine callback; the lambda version would be: timer.after(seconds, lambda: self.next_note())
        self.pending = timer.after(seconds, self.next_note)
        label = melody.name(midi) if midi is not None else TR("rest")
        self.say(TR("log_note", self.index + 1, label))

    # ------------------------------------------------------------------ 3. prompt and alert callbacks
    def edit_custom(self):
        self.say(TR("log_prompt_open"))
        ui.prompt(TR("edit_title"), TR("edit_message"), self.custom, self.on_prompt)

    def on_prompt(self, text):
        # runs on a later frame, after the user closed the dialog; text is None when cancelled
        if text is None:
            self.say(TR("log_prompt_cancel"))
            return
        notes, bad = melody.parse(text)
        if bad is not None or not notes:
            self.say(TR("log_prompt_bad", bad or "-"))
            ui.alert(TR("bad_title"), TR("bad_message", bad or "-"), [TR("try_again"), TR("cancel")],
                     lambda button: self.edit_custom() if button == 0 else None)
            return
        self.custom = text
        store.set("custom", text)
        self.say(TR("log_prompt_ok", len(notes)))
        self.select(len(SONGS))
        self.play()

    def reset_custom(self):
        def answer(button):           # a nested function works as a callback too
            if button == 0:
                self.custom = DEFAULT_CUSTOM
                store.set("custom", DEFAULT_CUSTOM)
                if self.song == len(SONGS):
                    self.select(self.song)
                self.say(TR("log_reset"))
        ui.alert(TR("reset_title"), TR("reset_message"), [TR("reset"), TR("cancel")], answer)

    # ------------------------------------------------------------------ 5. drawing
    def current_beat(self):
        if not self.playing or self.index < 0:
            return -1.0
        _, beats = self.notes[self.index]
        seconds = beats * 60.0 / self.bpm
        f = min(1.0, (sys.time() - self.note_at) / seconds)
        return self.starts[self.index] + f * beats

    def draw_roll(self, x, y, w, h):
        gfx.rect(x, y, w, h, 12, "#141826")
        pitches = [m for m, _ in self.notes if m is not None]
        if not pitches:
            return
        lo, hi = min(pitches) - 1, max(pitches) + 1
        rows = hi - lo + 1
        key_w = 44
        rh = (h - 16) / rows
        # keyboard strip: black keys darker, the sounding pitch lit
        sounding = self.notes[self.index][0] if self.playing and self.index >= 0 else None
        for p in range(lo, hi + 1):
            ry = y + 8 + (hi - p) * rh
            black = (p % 12) in (1, 3, 6, 8, 10)
            col = "#FFB347" if p == sounding else ("#2A2E3E" if black else "#D8DCE8")
            gfx.rect(x + 8, ry + 1, key_w - 12, max(1.0, rh - 2), 3, col)
            if p % 12 == 0 and rh >= 9:
                gfx.color("#6E7387")
                gfx.text(melody.name(p), x + 10, ry + rh / 2 - 6, size=10, font="semibold")
        # notes: the whole tune fits when it can, otherwise the view follows the playhead
        area_x, area_w = x + key_w + 4, w - key_w - 12
        ppb = max(18.0, area_w / max(1.0, self.total))
        beat = self.current_beat()
        scroll = 0.0
        if ppb * self.total > area_w and beat > 0:
            scroll = min(beat * ppb - area_w * 0.35, ppb * self.total - area_w)
            scroll = max(0.0, scroll)
        gfx.clip(area_x, y, area_w, h)
        for i in range(len(self.notes)):
            midi, beats = self.notes[i]
            if midi is None:
                continue
            nx = area_x + self.starts[i] * ppb - scroll
            if nx > area_x + area_w or nx + beats * ppb < area_x:
                continue
            ny = y + 8 + (hi - midi) * rh
            if i == self.index and self.playing:
                col = "#FFB347"
            elif self.playing and i < self.index:
                col = "#4D6CA8"
            else:
                col = "#7FA7FF"
            gfx.rect(nx + 1, ny + 1, beats * ppb - 2, max(2.0, rh - 2), min(6.0, rh / 2), col)
        if beat >= 0:
            px = area_x + beat * ppb - scroll
            gfx.color("#FFFFFF")
            gfx.line(px, y + 4, px, y + h - 4, 2)
        gfx.unclip()

    def draw_log(self, x, y, w, h):
        ui.group(x, y, w, h)
        gfx.color(theme.text2)
        gfx.text(TR("log_title"), x + 14, y + 10, size=12, font="semibold")
        now = sys.time()
        ly = y + 32
        for t, text in self.log[::-1]:
            if ly > y + h - 18:
                break
            age = now - t
            gfx.color(theme.accent if age < 0.4 else theme.text)
            gfx.text(text, x + 14, ly, size=12, font="mono")
            ly += 18

    def draw(self, w, h):
        gfx.clear(theme.bg)
        m = 16
        gfx.color(theme.text)
        gfx.text(TR("title"), m, 14, size=20, font="bold")
        # row 1: song, play/stop, edit
        names = self.song_names()
        sel = ui.dropdown("song", names, self.song, m, 50, min(220, w - 300), 32)   # 0-based in Python
        if sel != self.song:
            self.select(sel)
        bx = m + min(220, w - 300) + 10
        if ui.button(TR("stop") if self.playing else TR("play"), bx, 50, 100, 32, style="primary",
                     icon="stop" if self.playing else "play_arrow"):
            if self.playing:
                self.stop()
            else:
                self.play()
        if ui.button(TR("edit"), bx + 110, 50, 120, 32, icon="edit_note"):
            self.edit_custom()
        # row 2: tempo, wave, loop
        gfx.color(theme.text)
        gfx.text(TR("tempo", int(self.bpm)), m, 98, size=13)
        bpm = ui.slider("bpm", self.bpm, 50, 220, m + 100, 92, min(220, w * 0.3), step=1)
        if bpm != self.bpm:
            self.bpm = bpm
            store.set("bpm", bpm)
        wx = m + 110 + min(220, w * 0.3)
        wv = ui.segmented("wave", [TR("sine"), TR("triangle"), TR("square"), TR("saw")], self.wave, wx, 92,
                          min(300, w - wx - 120), 30)
        if wv != self.wave:
            self.wave = wv
            store.set("wave", wv)
        self.loop = ui.checkbox(TR("loop"), self.loop, w - m - 90, 98)
        # piano roll and callback log; side by side on wide windows, stacked on narrow ones
        top = 138
        if w >= 820:
            log_w = 280
            self.draw_roll(m, top, w - 3 * m - log_w, h - top - m)
            self.draw_log(w - m - log_w, top, log_w, h - top - m)
        else:
            log_h = 140
            self.draw_roll(m, top, w - 2 * m, h - top - 2 * m - log_h)
            self.draw_log(m, h - m - log_h, w - 2 * m, log_h)

    def event(self, e):
        if e.type == "keydown":
            if e.key == "space":
                if self.playing:
                    self.stop()
                else:
                    self.play()
            elif e.key == "e":
                self.edit_custom()

    def menu(self):
        return [{"title": TR("title"), "items": [
            {"label": TR("play"), "id": 1, "shortcut": "Space"},
            {"label": TR("stop"), "id": 2},
            "-",
            {"label": TR("edit"), "id": 3, "shortcut": "E"},
            {"label": TR("reset_custom"), "id": 4},
        ]}]

    def onmenu(self, item_id):
        if item_id == 1:
            self.play()
        elif item_id == 2:
            self.stop()
        elif item_id == 3:
            self.edit_custom()
        elif item_id == 4:
            self.reset_custom()

    def close(self):
        self.stop()
        return True


app = Player()
