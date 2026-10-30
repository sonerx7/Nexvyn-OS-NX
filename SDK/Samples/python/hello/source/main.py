# Merhaba Python / Hello Python: a small tour of the Nexvyn OS Python SDK (sdk/SDK.md, section "Python").
#  - To-do list saved with `store`               (todos.py, imported below)
#  - A clock drawn with `gfx`                     (clock.py)
#  - Live JSON with `net.json(url, callback)`     (Open-Meteo current weather, no API key)
# The SDK modules (gfx, ui, store, net, sys, timer, theme, TR...) are built in: no import needed.
from todos import TodoList
from clock import draw_clock

WEATHER_URL = ("https://api.open-meteo.com/v1/forecast?latitude=41.0082&longitude=28.9784" +
               "&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code&timezone=auto")


class HelloApp:
    def __init__(self):
        self.tab = 0
        self.todos = None
        self.draft = ""
        self.toast = ""
        self.toast_timer = None
        self.loading = False
        self.weather = None
        self.raw = ""
        self.error = ""

    # ------------------------------------------------------------------ callbacks
    def load(self, arg):
        self.todos = TodoList()
        self.tab = store.get("tab", 0)
        print("hellopy started", repr(arg), len(self.todos.items))

    def draw(self, w, h):
        gfx.clear(theme.bg)
        t = ui.segmented("tabs", [TR("tab_todo"), TR("tab_clock"), TR("tab_net")], self.tab, w / 2 - 180, 14, 360, 30)
        if t != self.tab:
            self.tab = t
            store.set("tab", t)
        if self.tab == 0:
            self.draw_todos(w, h)
        elif self.tab == 1:
            draw_clock(w, h)
        else:
            self.draw_network(w, h)
        if self.toast:
            self.draw_toast(w, h)

    def event(self, e):
        if e.type == "keydown" and e.key == "escape" and self.draft:
            self.draft = ""

    def menu(self):
        return [{
            "title": TR("app_name"),
            "items": [
                {"label": TR("clear_done"), "id": 1, "enabled": self.todos.done_count() > 0},
                {"label": TR("refresh"), "id": 2},
                "-",
                {"label": TR("about"), "id": 3},
            ],
        }]

    def onmenu(self, item_id):
        if item_id == 1:
            self.show_toast(TR("cleared", self.todos.clear_done()))
        elif item_id == 2:
            self.tab = 2
            self.fetch_weather()
        elif item_id == 3:
            # the callback gets the button index (0-based)
            ui.alert(TR("about"), TR("about_body"), [TR("ok"), TR("open_code")], self.on_about)

    def close(self):
        store.save()
        return True

    # ------------------------------------------------------------------ helpers
    def on_about(self, button):
        if button == 1:
            sys.open("bundle:/main.py")

    def show_toast(self, text):
        self.toast = text
        if self.toast_timer is not None:
            timer.cancel(self.toast_timer)
        self.toast_timer = timer.after(1.8, self.hide_toast)

    def hide_toast(self):
        self.toast = ""
        self.toast_timer = None

    def add_draft(self):
        text = self.draft.strip()
        if not text:
            return
        self.todos.add(text)
        self.draft = ""
        self.show_toast(TR("added"))

    def fetch_weather(self):
        if self.loading:
            return
        self.loading = True
        self.error = ""
        net.json(WEATHER_URL, self.on_weather)  # runs in the background, the callback gets (data, error)

    def on_weather(self, data, err):
        self.loading = False
        if err is not None:
            self.error = err
            return
        current = data.get("current") if isinstance(data, dict) else None
        self.weather = current
        self.raw = json.encode(current, True)
        print("weather", current)

    # ------------------------------------------------------------------ tabs
    def draw_todos(self, w, h):
        todos = self.todos
        gfx.color(theme.text)
        gfx.text(TR("todo_title"), 24, 58, 20, "bold")
        gfx.color(theme.text2)
        gfx.text(TR("remaining", todos.remaining()), 0, 63, 13, "sans", "right", w - 24)

        self.draft = ui.textfield("draft", self.draft, 24, 94, w - 160, 32, TR("todo_hint"))
        if ui.submitted("draft"):
            self.add_draft()
        if ui.button(TR("add"), w - 128, 94, 104, 32, "primary", "add", self.draft.strip() != ""):
            self.add_draft()

        top = 138
        bottom = h - 54
        row_h = 40
        list_w = w - 48
        ui.group(24, top, list_w, bottom - top)
        if not todos.items:
            gfx.icon("checklist", w / 2, (top + bottom) / 2 - 14, 40, theme.text3)
            gfx.color(theme.text3)
            gfx.text(TR("empty"), 0, (top + bottom) / 2 + 14, 14, "sans", "center", w)
        else:
            action = None  # change the list after the loop, not while drawing it
            ui.beginScroll("list", 24, top, list_w, bottom - top, len(todos.items) * row_h)
            for i, t in enumerate(todos.items):
                y = i * row_h
                if ui.checkbox("##done" + str(t["id"]), t["done"], 14, y + 11) != t["done"]:
                    action = ("toggle", t["id"])
                gfx.clip(44, y, list_w - 100, row_h)
                gfx.color(theme.text3 if t["done"] else theme.text)
                tw = gfx.text(t["text"], 44, y + 11, 14)
                if t["done"]:
                    gfx.line(44, y + 20, 44 + tw, y + 20, 1)
                gfx.unclip()
                if ui.iconButton("delete", list_w - 42, y + 6, 28, 28, theme.red, False, "del" + str(t["id"])):
                    action = ("remove", t["id"])
                if i < len(todos.items) - 1:
                    ui.separator(14, y + row_h - 0.5, list_w - 14)
            ui.endScroll()
            if action is not None:
                if action[0] == "toggle":
                    todos.toggle(action[1])
                else:
                    todos.remove(action[1])
        if ui.button(TR("clear_done"), 24, h - 44, 190, 30, "default", "cleaning_services", todos.done_count() > 0):
            self.show_toast(TR("cleared", todos.clear_done()))

    def draw_network(self, w, h):
        gfx.color(theme.text)
        gfx.text(TR("net_title"), 24, 58, 20, "bold")
        gfx.color(theme.text2)
        gfx.wrap(TR("net_body"), 24, 88, w - 48, 13)

        online = sys.online()
        if ui.button(TR("fetch"), 24, 130, 170, 34, "primary", "cloud_download", online and not self.loading):
            self.fetch_weather()
        if self.loading:
            ui.spinner(216, 147, 9)
        elif not online:
            gfx.color(theme.orange)
            gfx.text(TR("offline"), 208, 139, 14)
        elif self.error:
            gfx.color(theme.red)
            gfx.text(TR("failed", self.error), 208, 139, 13)

        top = 180
        box_h = h - top - 24
        ui.group(24, top, w - 48, box_h)
        c = self.weather
        if not c:
            gfx.icon("thermostat", w / 2, top + box_h / 2 - 12, 40, theme.text3)
            gfx.color(theme.text3)
            gfx.text(TR("no_data"), 0, top + box_h / 2 + 16, 14, "sans", "center", w)
            return
        gfx.color(theme.accent)
        gfx.text(str(round(c.get("temperature_2m", 0))) + "°", 44, top + 14, 56, "bold")
        gfx.color(theme.text)
        gfx.text(TR("city"), 44, top + 90, 15, "semibold")
        gfx.color(theme.text2)
        gfx.text(TR("humidity", c.get("relative_humidity_2m", "-")), 44, top + 116, 13)
        gfx.text(TR("wind", c.get("wind_speed_10m", "-")), 44, top + 136, 13)
        gfx.text(TR("updated", str(c.get("time", "")).replace("T", " ")), 44, top + 156, 13)

        x = 250
        ui.separator(x - 16, top + 12, x - 16)
        gfx.color(theme.text3)
        gfx.text("JSON", x, top + 14, 11, "semibold")
        gfx.color(theme.text2)
        gfx.clip(x, top + 34, w - x - 40, box_h - 46)
        gfx.wrap(self.raw, x, top + 34, w - x - 40, 12, "mono")
        gfx.unclip()

    def draw_toast(self, w, h):
        tw = gfx.textWidth(self.toast, 13, "semibold") + 36
        gfx.rect(w / 2 - tw / 2, h - 92, tw, 30, 15, (0, 0, 0, 170))
        gfx.color("#FFFFFF")
        gfx.text(self.toast, w / 2 - tw / 2, h - 84, 13, "semibold", "center", tw)


app = HelloApp()
