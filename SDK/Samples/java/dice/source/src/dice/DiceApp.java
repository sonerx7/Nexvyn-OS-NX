// Dice Roller: roll up to six d4..d20 dice, hold the ones you like, keep a history.
// Shows: a class extending nexvyn.App, update() only while something moves, java.util.Random, arrays,
// Ui.segmented / Ui.hit / Ui.iconButton, Record and List values in Store, Audio.tone and Sys.vibrate.
package dice;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

import nexvyn.*;

public class DiceApp extends App {
    private static final int[] SIDES = {4, 6, 8, 10, 12, 20};
    private static final String[] NAMES = {"d4", "d6", "d8", "d10", "d12", "d20"};
    private static final int MAX = 6;
    private static final int HISTORY = 12;

    private final Random random = new Random();
    private final int[] values = new int[MAX];
    private final boolean[] held = new boolean[MAX];
    private final List<Object> history = new ArrayList<Object>();
    private int kind = 1;          // index into SIDES (d6)
    private int count = 2;
    private double rolling;        // seconds left in the roll animation
    private double shuffle;

    @Override
    @SuppressWarnings("unchecked")
    public void load(String arg) {
        kind = clamp(intOf(Store.get("kind", 1)), 0, SIDES.length - 1);
        count = clamp(intOf(Store.get("count", 2)), 1, MAX);
        Object saved = Store.get("history");
        if (saved instanceof List) history.addAll((List<Object>) saved);
        for (int i = 0; i < MAX; i++) values[i] = 1 + random.nextInt(SIDES[kind]);
    }

    private static int intOf(Object o) {
        return o instanceof Number ? ((Number) o).intValue() : 0;
    }

    private static int clamp(int v, int lo, int hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    private void roll() {
        if (rolling > 0) return;
        rolling = 0.6;
        Audio.play("click");
    }

    private void finish() {
        int total = 0;
        StringBuilder text = new StringBuilder();
        for (int i = 0; i < count; i++) {
            total += values[i];
            if (i > 0) text.append(" + ");
            text.append(values[i]);
        }
        Record r = new Record();
        r.put("dice", count + NAMES[kind]);
        r.put("text", text.toString());
        r.put("total", Integer.valueOf(total));
        history.add(0, r);
        while (history.size() > HISTORY) history.remove(history.size() - 1);
        Store.set("history", history);
        Audio.tone(520 + total * 8, 0.08, 0.4, "triangle");
        Sys.vibrate(0.4, 60);
    }

    // a window whose app overrides update() is redrawn every frame; here it animates the roll
    @Override
    public void update(double dt) {
        if (rolling <= 0) return;
        rolling -= dt;
        shuffle -= dt;
        if (shuffle <= 0) {
            shuffle = 0.05;
            for (int i = 0; i < count; i++) if (!held[i]) values[i] = 1 + random.nextInt(SIDES[kind]);
        }
        if (rolling <= 0) finish();
    }

    private int total() {
        int t = 0;
        for (int i = 0; i < count; i++) t += values[i];
        return t;
    }

    @Override
    public void draw(double w, double h) {
        Gfx.clear(Theme.bg());
        int k = Ui.segmented("kind", NAMES, kind, 20, 16, w - 190, 32);
        if (k != kind && rolling <= 0) {
            kind = k;
            for (int i = 0; i < MAX; i++) {
                values[i] = 1 + random.nextInt(SIDES[kind]);
                held[i] = false;
            }
            Store.set("kind", kind);
        }
        if (Ui.iconButton("remove", w - 158, 15, 34, 34, null, false, "less") && count > 1) setCount(count - 1);
        Gfx.color(Theme.text());
        Gfx.text(String.valueOf(count), w - 122, 21, 18, "semibold", "center", 40);
        if (Ui.iconButton("add", w - 80, 15, 34, 34, null, false, "more") && count < MAX) setCount(count + 1);

        // the dice: tap one to hold it
        double size = Math.min(84, (w - 40 - (count - 1) * 12) / count);
        double x0 = (w - (size * count + 12 * (count - 1))) / 2, y0 = 76;
        for (int i = 0; i < count; i++) {
            double x = x0 + i * (size + 12);
            Gfx.shadow(x, y0, size, size, 14, 10, 3);
            Gfx.rect(x, y0, size, size, 14, held[i] ? Theme.accent() : Theme.window());
            Gfx.color(held[i] ? "#FFFFFF" : Theme.text());
            Gfx.text(String.valueOf(values[i]), x, y0 + size / 2 - size * 0.22, size * 0.42, "bold", "center", size);
            if (held[i]) Gfx.icon("lock", x + size - 14, y0 + 14, 14, "#FFFFFF");
            Record hit = Ui.hit("die" + i, x, y0, size, size);
            if (hit.bool("clicked") && rolling <= 0) held[i] = !held[i];
        }

        double y = y0 + size + 20;
        Gfx.color(Theme.text2());
        Gfx.text(TR("total", total()), 0, y, 18, "medium", "center", w);
        if (Ui.button(TR("roll"), w / 2 - 80, y + 34, 160, 40, "primary", "casino", rolling <= 0)) roll();

        // history
        double top = y + 92, listH = h - top - 16;
        if (listH < 60) return;
        Ui.group(20, top, w - 40, listH);
        if (history.isEmpty()) {
            Gfx.color(Theme.text3());
            Gfx.text(TR("no_history"), 20, top + listH / 2 - 9, 14, "sans", "center", w - 40);
            return;
        }
        Ui.beginScroll("history", 20, top, w - 40, listH, history.size() * 34 + 8);
        for (int i = 0; i < history.size(); i++) {
            Record r = history.get(i) instanceof Record ? (Record) history.get(i) : new Record();
            double ry = 4 + i * 34;
            Gfx.color(Theme.text2());
            Gfx.text(r.str("dice"), 16, ry + 8, 13, "mono");
            Gfx.color(Theme.text());
            Gfx.text(r.str("text"), 90, ry + 8, 14);
            Gfx.text(String.valueOf(r.integer("total")), 0, ry + 6, 16, "semibold", "right", w - 56);
        }
        Ui.endScroll();
    }

    private void setCount(int n) {
        count = n;
        Store.set("count", count);
    }

    @Override
    public void event(Event e) {
        if (e.is("keydown") && ("space".equals(e.key) || "enter".equals(e.key))) roll();
    }

    @Override
    public List<Menu> menu() {
        return Menu.bar(new Menu(TR("app"))
                .item(TR("roll"), 1, "Space")
                .item(TR("release_all"), 2)
                .separator()
                .item(TR("clear_history"), 3, null, false, !history.isEmpty()));
    }

    @Override
    public void onmenu(int id) {
        if (id == 1) roll();
        else if (id == 2) for (int i = 0; i < MAX; i++) held[i] = false;
        else if (id == 3) {
            history.clear();
            Store.set("history", history);
        }
    }
}
