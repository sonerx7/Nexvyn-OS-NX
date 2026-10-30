# My App: a minimal Nexvyn OS app in Python (SDK.md section 12, pocketpy).
# The SDK modules (gfx, ui, store, theme, TR...) are built in: no import needed.
# Differences from Lua: indexes start at 0, None instead of nil, several results are tuples,
# async calls take callbacks.


class App:
    def load(self, arg):
        # once, when the window opens; arg = the file / link the app was opened with, or ""
        self.taps = store.get("taps", 0)

    def bump(self, n):
        self.taps = n
        store.set("taps", n)       # store keeps small values between runs (the app's own data folder)

    def draw(self, w, h):
        # every frame: draw everything and handle widgets; w, h = content size in pixels
        gfx.clear(theme.bg)
        gfx.color(theme.text)
        gfx.text(TR("hello"), 0, h / 2 - 70, 28, "bold", "center", w)
        gfx.color(theme.text2)
        gfx.text(TR("edit_me"), 40, h / 2 - 24, 14, "sans", "center", w - 80)
        if ui.button(TR("tap", self.taps), w / 2 - 90, h / 2 + 20, 180, 40, "primary"):
            self.bump(self.taps + 1)
            audio.play("pop")

    def event(self, e):
        if e.type == "keydown" and e.key == "space":
            self.bump(self.taps + 1)

    def menu(self):
        return [{"title": TR("app"), "items": [{"label": TR("reset"), "id": 1}]}]

    def onmenu(self, item_id):
        if item_id == 1:
            self.bump(0)


app = App()
