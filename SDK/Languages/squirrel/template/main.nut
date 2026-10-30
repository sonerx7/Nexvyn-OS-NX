// My App: a minimal Nexvyn OS app in Squirrel 3.2 (SDK.md section 13).
// The SDK modules (gfx, ui, store, theme, TR...) are global tables: no import needed.
// main.nut returns the app: a class instance (or table) whose methods are the callbacks.

class App {
    taps = 0;      // numbers and strings are fine as defaults; create tables/arrays in load()

    function load(arg) {
        // once, when the window opens; arg = the file / link the app was opened with, or ""
        taps = store.get("taps", 0);
    }

    function draw(w, h) {
        // every frame: draw everything and handle widgets; w, h = content size in pixels
        gfx.clear(theme.bg);
        gfx.color(theme.text);
        gfx.text(TR("hello"), 0, h / 2 - 70, 28, "bold", "center", w);
        gfx.color(theme.text2);
        gfx.text(TR("edit_me"), 40, h / 2 - 24, 14, "sans", "center", w - 80);
        if (ui.button(TR("tap", taps), w / 2 - 90, h / 2 + 20, 180, 40, "primary")) {
            bump(taps + 1);
            audio.play("pop");
        }
    }

    function event(e) {
        if (e.type == "keydown" && e.key == "space") bump(taps + 1);
    }

    function menu() {
        return [{title = TR("app"), items = [{label = TR("reset"), id = 1}]}];
    }

    function onmenu(id) {
        if (id == 1) bump(0);
    }

    function bump(n) {
        taps = n;
        store.set("taps", taps);   // store keeps small values between runs (the app's own data folder)
    }
}

return App();
