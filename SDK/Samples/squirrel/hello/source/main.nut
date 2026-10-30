// Merhaba Squirrel / Hello Squirrel: a small tour of the Nexvyn OS SDK in Squirrel (sdk/SDK.md, section "Squirrel").
//  - To-do list saved with `store`
//  - A clock drawn with `gfx`                    (clock.nut, loaded with import)
//  - Live JSON with `net.json(url, callback)`    (Open-Meteo current weather, no API key)
// The SDK modules (gfx, ui, store, net, sys, timer, theme, TR...) are global tables: no import needed.
local Clock = import("clock");

const WEATHER_URL = "https://api.open-meteo.com/v1/forecast?latitude=41.0082&longitude=28.9784&current=temperature_2m,relative_humidity_2m,wind_speed_10m";

class Hello {
    tab = 0;
    todos = null;   // tables and arrays are created in load(): class defaults are shared by every instance
    draft = "";
    toast = "";
    toastTimer = null;
    loading = false;
    weather = null;
    error = "";

    function load(arg) {
        todos = store.get("todos", []);
        tab = store.get("tab", 0);
        print("hellosq started, " + todos.len() + " to-dos");
    }

    // only for the clock: an app with update() is redrawn every frame
    function update(dt) {}

    function draw(w, h) {
        gfx.clear(theme.bg);
        local t = ui.segmented("tabs", [TR("tab_todo"), TR("tab_clock"), TR("tab_net")], tab, w / 2 - 180, 14, 360, 30);
        if (t != tab) {
            tab = t;
            store.set("tab", t);
        }
        if (tab == 0) drawTodos(w, h);
        else if (tab == 1) Clock.draw(w, h);
        else drawNetwork(w, h);
        if (toast != "") {
            local tw = gfx.textWidth(toast, 14) + 32;
            gfx.rect((w - tw) / 2, h - 56, tw, 34, 17, theme.text);
            gfx.color(theme.bg);
            gfx.text(toast, (w - tw) / 2, h - 47, 14, "medium", "center", tw);
        }
    }

    function menu() {
        return [{
            title = TR("app_name"),
            items = [
                {label = TR("clear_done"), id = 1, enabled = doneCount() > 0},
                {label = TR("refresh"), id = 2},
                "-",
                {label = TR("about"), id = 3}
            ]
        }];
    }

    function onmenu(id) {
        if (id == 1) clearDone();
        else if (id == 2) {
            tab = 2;
            fetchWeather();
        } else if (id == 3) {
            // the callback gets the button index (0-based) and runs with `this` = the app
            ui.alert(TR("about"), TR("about_body"), [TR("ok"), TR("open_code")], function(button) {
                if (button == 1) sys.open("bundle:/main.nut");
            });
        }
    }

    function close() {
        store.save();
        return true;
    }

    // ------------------------------------------------------------------ helpers
    function showToast(text) {
        toast = text;
        if (toastTimer != null) timer.cancel(toastTimer);
        toastTimer = timer.after(1.8, function() {
            toast = "";
            toastTimer = null;
        });
    }
    function doneCount() {
        local n = 0;
        foreach (t in todos) if (t.done) n++;
        return n;
    }
    function clearDone() {
        local before = todos.len();
        todos = todos.filter(@(i, t) !t.done);
        store.set("todos", todos);
        showToast(TR("cleared", before - todos.len()));
    }
    function addDraft() {
        local text = strip(draft);
        if (text == "") return;
        todos.append({text = text, done = false});
        store.set("todos", todos);
        draft = "";
        showToast(TR("added"));
    }
    function fetchWeather() {
        if (loading) return;
        loading = true;
        error = "";
        net.json(WEATHER_URL, function(data, err) {   // runs later, when the answer arrives
            loading = false;
            if (err != null) error = err;
            else weather = data.current;
        });
    }

    // ------------------------------------------------------------------ tabs
    function drawTodos(w, h) {
        gfx.color(theme.text);
        gfx.text(TR("todo_title"), 24, 58, 20, "bold");
        gfx.color(theme.text2);
        gfx.text(TR("remaining", todos.len() - doneCount()), 24, 62, 13, "sans", "right", w - 48);
        draft = ui.textfield("draft", draft, 24, 92, w - 150, 32, TR("todo_hint"));
        if (ui.submitted("draft")) addDraft();
        if (ui.button(TR("add"), w - 118, 92, 94, 32, "primary", "add")) addDraft();
        local top = 138, listH = h - top - 16;
        ui.group(24, top, w - 48, listH);
        if (todos.len() == 0) {
            gfx.color(theme.text3);
            gfx.text(TR("empty"), 24, top + listH / 2 - 9, 14, "sans", "center", w - 48);
            return;
        }
        ui.beginScroll("list", 24, top, w - 48, listH, todos.len() * 40 + 8);
        foreach (i, t in todos) {
            local y = 4 + i * 40;
            local done = ui.checkbox(t.text + "##" + i, t.done, 14, y + 10);
            if (done != t.done) {
                t.done = done;
                store.set("todos", todos);
            }
            if (ui.iconButton("close", w - 48 - 40, y + 6, 28, 28, theme.text3, false, "del" + i)) {
                todos.remove(i);
                store.set("todos", todos);
                break;
            }
        }
        ui.endScroll();
    }

    function drawNetwork(w, h) {
        gfx.color(theme.text);
        gfx.text(TR("net_title"), 24, 58, 20, "bold");
        gfx.color(theme.text2);
        gfx.wrap(TR("net_body"), 24, 88, w - 48, 13);
        if (ui.button(TR("fetch"), 24, 140, 160, 34, "primary", "cloud_download", !loading)) {
            if (!sys.online()) error = TR("offline");
            else fetchWeather();
        }
        if (loading) ui.spinner(206, 157, 10);
        local y = 196;
        ui.group(24, y, w - 48, 150);
        if (error != "") {
            gfx.color(theme.red);
            gfx.text(TR("failed", error), 40, y + 20, 14);
        } else if (weather == null) {
            gfx.color(theme.text3);
            gfx.text(TR("no_data"), 40, y + 20, 14);
        } else {
            gfx.icon("thermostat", 64, y + 52, 40, theme.orange);
            gfx.color(theme.text);
            gfx.text(TR("city"), 100, y + 18, 15, "semibold");
            gfx.text(weather.temperature_2m + "°C", 100, y + 40, 32, "bold");
            gfx.color(theme.text2);
            gfx.text(TR("humidity", weather.relative_humidity_2m), 40, y + 96, 13);
            gfx.text(TR("wind", weather.wind_speed_10m), 40, y + 118, 13);
        }
    }
}

return Hello();
