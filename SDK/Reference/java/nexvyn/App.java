package nexvyn;

import java.util.List;

/**
 * Base class of a Java app: override the callbacks you need (sdk/SDK.en.md section 2 and "Java"). The class named by
 * app.json "mainClass" is created once when the window opens; it needs a public no-argument constructor.
 */
public abstract class App {
    /** Once; arg = the file / link / "" the app was opened with. */
    public void load(String arg) {
    }

    /** The app was asked to open something else while running. */
    public void open(String arg) {
    }

    /** Every frame; override it only for animation (the window is then redrawn every frame). */
    public void update(double dt) {
    }

    /** Every frame: draw and handle widgets. */
    public void draw(double w, double h) {
    }

    public void event(Event e) {
    }

    /** Menu-bar menus, see {@link Menu}. */
    public List<Menu> menu() {
        return null;
    }

    public void onmenu(int id) {
    }

    /** Return false to keep the window open. */
    public boolean close() {
        return true;
    }

    /** Quick Search asks running apps; return at most a few results. */
    public List<SearchResult> search(String query) {
        return null;
    }

    public void suspend() {
    }

    public void resume() {
    }

    public void focus(boolean focused) {
    }

    public void autosave() {
    }

    /** True while work would be lost. */
    public boolean unsaved() {
        return false;
    }

    /** Translated text from the bundle's lang/&lt;code&gt;.json; {0}, {1}... are replaced by args. */
    public static String TR(String key, Object... args) {
        // the host takes (key, arg0, arg1...) flat; passing args as one value would print "[0]" for {0}
        Object[] all = new Object[args.length + 1];
        all[0] = key;
        System.arraycopy(args, 0, all, 1, args.length);
        return Tr.tr(all);
    }
}
