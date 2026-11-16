from nexvyn import gfx, ui, theme, sys
class App:
    def load(self, arg):
        self.volume, self.name, self.selected = 0.5, "", 0
        self.zoom, self.angle = 1, 0
        self.last = ""
        self.lastsize = (0, 0)
    def event(self, e):
        if e.type == "pinch": self.zoom = max(0.25, min(4, self.zoom * e.scale))
        if e.type == "rotate": self.angle += e.angle
    def draw(self, w, h):
        compact = w < 620
        shift = 46 if compact else 0
        if self.lastsize != (w, h):
            sys.log("Layout %s %.0f %.0f" % ("compact" if compact else "wide", w, h))
            self.lastsize = (w, h)
        gfx.clear(theme.window)
        gfx.color(theme.text)
        gfx.text("Input Lab", 20, 16, 19, "bold")
        gfx.text("Touch, scroll, type and try two fingers" if compact else "Drag sliders, swipe inside frames, type and try two fingers", 20, 48, 13.8)
        self.selected = ui.dropdown("mode", ["Touch", "Gamepad", "Keyboard / mouse"], self.selected, 20, 80, 230, 30)
        self.name = ui.textfield("name", self.name, 20 if compact else 270, 80 + shift, w - 40 if compact else w - 290, 30, "Type here")
        self.volume = ui.slider("volume", self.volume, 0, 1, 20, 126 + shift, w - 40)
        status = "Value %.2f | Pinch %.2f | Rotation %.2f" % (self.volume, self.zoom, self.angle)
        if status != self.last:
            sys.log(status)
            self.last = status
        gfx.text(("Value %.2f | Pinch %.2f" % (self.volume, self.zoom)) if compact else status, 20, 164 + shift, 13.8)
        ui.beginScroll("outer", 20, 200 + shift, w - 40, h - 220 - shift, 1100)
        gfx.color(theme.text)
        gfx.text("Nested frame: swipe rows" if compact else "Outer frame: swipe this text or any row", 12, 8, 15, "bold")
        ui.beginScroll("inner", 12, 44, w - 90, 180, 900)
        for i in range(20): ui.button("Inner row " + str(i + 1), 8, i * 44, w - 130, 36)
        ui.endScroll()
        for i in range(18): ui.button("Outer row " + str(i + 1), 12, 244 + i * 44, w - 90, 36)
        ui.endScroll()
app = App()
