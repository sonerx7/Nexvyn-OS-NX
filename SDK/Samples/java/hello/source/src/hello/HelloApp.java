// Merhaba Java / Hello Java: a small tour of the Nexvyn OS SDK in Java (sdk/SDK.md, section "Java").
//  - A to-do list saved with Store
//  - A clock drawn with Gfx (overriding update() makes the window redraw every frame)
//  - Live JSON with Net.json(url, callback)   (Open-Meteo current weather, no API key)
// Built on the PC: python tools/java_build.py app romfs/Applications/hellojava.nxvapp  ->  app.jar
package hello;

import java.util.ArrayList;
import java.util.List;

import nexvyn.*;

public class HelloApp extends App {
    private static final String WEATHER_URL = "https://api.open-meteo.com/v1/forecast?latitude=41.0082&longitude=28.9784"
            + "&current=temperature_2m,relative_humidity_2m,wind_speed_10m";

    private int tab;
    private final List<Object> todos = new ArrayList<Object>();
    private String draft = "";
    private String toast = "";
    private int toastTimer = -1;
    private boolean loading;
    private Record weather;
    private String error = "";

    @Override
    @SuppressWarnings("unchecked")
    public void load(String arg) {
        Object saved = Store.get("todos");
        if (saved instanceof List) todos.addAll((List<Object>) saved);
        Object t = Store.get("tab", 0);
        tab = t instanceof Number ? ((Number) t).intValue() : 0;
        System.out.println("hellojava started, " + todos.size() + " to-dos");
    }

    @Override
    public void update(double dt) {
        // only for the clock: an app that overrides update() is redrawn every frame
    }

    @Override
    public void draw(double w, double h) {
        Gfx.clear(Theme.bg());
        int t = Ui.segmented("tabs", new String[]{TR("tab_todo"), TR("tab_clock"), TR("tab_net")}, tab, w / 2 - 180, 14, 360, 30);
        if (t != tab) {
            tab = t;
            Store.set("tab", tab);
        }
        if (tab == 0) drawTodos(w, h);
        else if (tab == 1) drawClock(w, h);
        else drawNetwork(w, h);
        if (!toast.isEmpty()) {
            double tw = Gfx.textWidth(toast, 14) + 32;
            Gfx.rect((w - tw) / 2, h - 56, tw, 34, 17, Theme.text());
            Gfx.color(Theme.bg());
            Gfx.text(toast, (w - tw) / 2, h - 47, 14, "medium", "center", tw);
        }
    }

    @Override
    public List<Menu> menu() {
        return Menu.bar(new Menu(TR("app_name"))
                .item(TR("clear_done"), 1, null, false, doneCount() > 0)
                .item(TR("refresh"), 2)
                .separator()
                .item(TR("about"), 3));
    }

    @Override
    public void onmenu(int id) {
        if (id == 1) clearDone();
        else if (id == 2) {
            tab = 2;
            fetchWeather();
        } else if (id == 3) {
            // the callback gets the button index (0-based)
            Ui.alert(TR("about"), TR("about_body"), new String[]{TR("ok"), TR("open_code")}, (Callback) args -> {
                if (((Number) args[0]).intValue() == 1) Sys.open("bundle:/src/hello/HelloApp.java");
            });
        }
    }

    @Override
    public boolean close() {
        Store.save();
        return true;
    }

    // ------------------------------------------------------------------ helpers
    private void showToast(String text) {
        toast = text;
        if (toastTimer >= 0) Timer.cancel(toastTimer);
        toastTimer = Timer.after(1.8, (Callback) args -> {
            toast = "";
            toastTimer = -1;
        });
    }

    private Record todo(int i) {
        Object o = todos.get(i);
        return o instanceof Record ? (Record) o : new Record();
    }

    private int doneCount() {
        int n = 0;
        for (int i = 0; i < todos.size(); i++) if (todo(i).bool("done")) n++;
        return n;
    }

    private void clearDone() {
        int before = todos.size();
        for (int i = todos.size() - 1; i >= 0; i--) if (todo(i).bool("done")) todos.remove(i);
        Store.set("todos", todos);
        showToast(TR("cleared", before - todos.size()));
    }

    private void addDraft() {
        String text = draft.trim();
        if (text.isEmpty()) return;
        Record r = new Record();
        r.put("text", text);
        r.put("done", Boolean.FALSE);
        todos.add(r);
        Store.set("todos", todos);
        draft = "";
        showToast(TR("added"));
    }

    private void fetchWeather() {
        if (loading) return;
        loading = true;
        error = "";
        // runs in the background; the callback gets (data, error)
        Net.json(WEATHER_URL, (Callback) args -> {
            loading = false;
            if (args.length > 1 && args[1] != null) error = String.valueOf(args[1]);
            else if (args[0] instanceof Record) weather = ((Record) args[0]).rec("current");
        });
    }

    // ------------------------------------------------------------------ tabs
    private void drawTodos(double w, double h) {
        Gfx.color(Theme.text());
        Gfx.text(TR("todo_title"), 24, 58, 20, "bold");
        Gfx.color(Theme.text2());
        Gfx.text(TR("remaining", todos.size() - doneCount()), 24, 62, 13, "sans", "right", w - 48);
        draft = Ui.textfield("draft", draft, 24, 92, w - 150, 32, TR("todo_hint"));
        if (Ui.submitted("draft")) addDraft();
        if (Ui.button(TR("add"), w - 118, 92, 94, 32, "primary", "add")) addDraft();
        double top = 138, listH = h - top - 16;
        Ui.group(24, top, w - 48, listH);
        if (todos.isEmpty()) {
            Gfx.color(Theme.text3());
            Gfx.text(TR("empty"), 24, top + listH / 2 - 9, 14, "sans", "center", w - 48);
            return;
        }
        Ui.beginScroll("list", 24, top, w - 48, listH, todos.size() * 40 + 8);
        for (int i = 0; i < todos.size(); i++) {
            Record t = todo(i);
            double y = 4 + i * 40;
            boolean done = Ui.checkbox(t.str("text") + "##" + i, t.bool("done"), 14, y + 10);
            if (done != t.bool("done")) {
                t.put("done", Boolean.valueOf(done));
                Store.set("todos", todos);
            }
            if (Ui.iconButton("close", w - 48 - 40, y + 6, 28, 28, Theme.text3(), false, "del" + i)) {
                todos.remove(i);
                Store.set("todos", todos);
                break;
            }
        }
        Ui.endScroll();
    }

    private void drawClock(double w, double h) {
        double side = Math.min(w, h - 60);
        double cx = w / 2, cy = h / 2 + 24, r = side / 2 - 30;
        Record d = Sys.date();
        double t = Sys.time();
        double sec = d.num("sec") + (t - Math.floor(t));
        Gfx.shadow(cx - r, cy - r, r * 2, r * 2, r, 18, 6);
        Gfx.circle(cx, cy, r, Theme.window());
        Gfx.color(Theme.separator());
        Gfx.circleLine(cx, cy, r, 2);
        for (int i = 0; i < 60; i++) {
            double a = i * Math.PI / 30, inner = i % 5 == 0 ? r - 16 : r - 8;
            Gfx.color(i % 5 == 0 ? Theme.text() : Theme.text3());
            Gfx.line(cx + Math.cos(a) * inner, cy + Math.sin(a) * inner, cx + Math.cos(a) * (r - 4), cy + Math.sin(a) * (r - 4),
                    i % 5 == 0 ? 3 : 1);
        }
        hand(cx, cy, (d.num("hour") % 12 + d.num("min") / 60) * Math.PI / 6, r * 0.5, 6, Theme.text());
        hand(cx, cy, (d.num("min") + sec / 60) * Math.PI / 30, r * 0.75, 4, Theme.text());
        hand(cx, cy, sec * Math.PI / 30, r * 0.85, 2, Theme.red());
        Gfx.circle(cx, cy, 6, Theme.red());
        Gfx.color(Theme.text2());
        Gfx.text(two(d.integer("hour")) + ":" + two(d.integer("min")) + ":" + two(d.integer("sec")), 0, cy + r + 12, 16, "mono",
                "center", w);
    }

    private static String two(int n) {
        return n < 10 ? "0" + n : String.valueOf(n);
    }

    private static void hand(double cx, double cy, double angle, double len, double width, String color) {
        double a = angle - Math.PI / 2;
        Gfx.color(color);
        Gfx.line(cx, cy, cx + Math.cos(a) * len, cy + Math.sin(a) * len, width);
    }

    private void drawNetwork(double w, double h) {
        Gfx.color(Theme.text());
        Gfx.text(TR("net_title"), 24, 58, 20, "bold");
        Gfx.color(Theme.text2());
        Gfx.wrap(TR("net_body"), 24, 88, w - 48, 13);
        if (Ui.button(TR("fetch"), 24, 140, 160, 34, "primary", "cloud_download", !loading)) {
            if (!Sys.online()) error = TR("offline");
            else fetchWeather();
        }
        if (loading) Ui.spinner(206, 157, 10);
        double y = 196;
        Ui.group(24, y, w - 48, 150);
        if (!error.isEmpty()) {
            Gfx.color(Theme.red());
            Gfx.text(TR("failed", error), 40, y + 20, 14);
        } else if (weather == null) {
            Gfx.color(Theme.text3());
            Gfx.text(TR("no_data"), 40, y + 20, 14);
        } else {
            Gfx.icon("thermostat", 64, y + 52, 40, Theme.orange());
            Gfx.color(Theme.text());
            Gfx.text(TR("city"), 100, y + 18, 15, "semibold");
            Gfx.text(weather.str("temperature_2m") + "°C", 100, y + 40, 32, "bold");
            Gfx.color(Theme.text2());
            Gfx.text(TR("humidity", weather.str("relative_humidity_2m")), 40, y + 96, 13);
            Gfx.text(TR("wind", weather.str("wind_speed_10m")), 40, y + 118, 13);
        }
    }
}
