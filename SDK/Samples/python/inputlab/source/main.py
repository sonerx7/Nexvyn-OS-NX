from nexvyn import gfx, ui, theme, sys, TR
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
        gfx.text(TR("title"), 20, 16, 19, "bold")
        gfx.text(TR("hint.compact") if compact else TR("hint.wide"), 20, 48, 13.8)
        self.selected = ui.dropdown("mode", [TR("mode.touch"), TR("mode.pad"), TR("mode.keyboard")], self.selected, 20, 80, 230, 30)
        self.name = ui.textfield("name", self.name, 20 if compact else 270, 80 + shift, w - 40 if compact else w - 290, 30, TR("placeholder"))
        self.volume = ui.slider("volume", self.volume, 0, 1, 20, 126 + shift, w - 40)
        status = "Value %.2f | Pinch %.2f | Rotation %.2f" % (self.volume, self.zoom, self.angle)
        if status != self.last:
            sys.log(status)
            self.last = status
        visible = "%s %.2f | %s %.2f" % (TR("value"), self.volume, TR("pinch"), self.zoom)
        if not compact: visible += " | %s %.2f" % (TR("rotation"), self.angle)
        gfx.text(visible, 20, 164 + shift, 13.8)
        ui.beginScroll("outer", 20, 200 + shift, w - 40, h - 220 - shift, 1100)
        gfx.color(theme.text)
        gfx.text(TR("frame.compact") if compact else TR("frame.wide"), 12, 8, 15, "bold")
        ui.beginScroll("inner", 12, 44, w - 90, 180, 900)
        for i in range(20): ui.button(TR("row.inner") + " " + str(i + 1), 8, i * 44, w - 130, 36)
        ui.endScroll()
        for i in range(18): ui.button(TR("row.outer") + " " + str(i + 1), 12, 244 + i * 44, w - 90, 36)
        ui.endScroll()
app = App()
