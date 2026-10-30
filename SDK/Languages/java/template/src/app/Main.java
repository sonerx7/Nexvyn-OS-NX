// My App: a minimal Nexvyn OS app in Java (SDK.md section 15, package nexvyn).
// The console runs app.jar on miniJVM. After editing, rebuild it on the PC (JDK 8 or newer):
//     python tools/java_build.py app <this folder>          (from a Nexvyn OS source checkout)
//     python Tools/nxv/nxv.py build <this folder> --sdk <checkout>
package app;

import java.util.List;

import nexvyn.*;

public class Main extends App {
    private int taps;

    // once, when the window opens; arg = the file / link the app was opened with, or ""
    @Override
    public void load(String arg) {
        Object saved = Store.get("taps", 0);              // numbers arrive as Double
        taps = saved instanceof Number ? ((Number) saved).intValue() : 0;
    }

    // every frame: draw everything and handle widgets; w, h = content size in pixels
    @Override
    public void draw(double w, double h) {
        Gfx.clear(Theme.bg());
        Gfx.color(Theme.text());
        Gfx.text(TR("hello"), 0, h / 2 - 70, 28, "bold", "center", w);
        Gfx.color(Theme.text2());
        Gfx.text(TR("edit_me"), 40, h / 2 - 24, 14, "sans", "center", w - 80);
        if (Ui.button(TR("tap", taps), w / 2 - 90, h / 2 + 20, 180, 40, "primary")) {
            bump(taps + 1);
            Audio.play("pop");
        }
    }

    @Override
    public void event(Event e) {
        if (e.is("keydown") && "space".equals(e.key)) bump(taps + 1);
    }

    @Override
    public List<Menu> menu() {
        return Menu.bar(new Menu(TR("app")).item(TR("reset"), 1));
    }

    @Override
    public void onmenu(int id) {
        if (id == 1) bump(0);
    }

    private void bump(int n) {
        taps = n;
        Store.set("taps", taps);   // Store keeps small values between runs (the app's own data folder)
    }
}
