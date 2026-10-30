package nexvyn;

import java.util.ArrayList;
import java.util.List;

/**
 * A menu-bar menu for App.menu():
 * {@code return Menu.bar(new Menu(TR("game")).item(TR("new"), 1, "Ctrl+N").separator().item(TR("quit"), 2));}
 */
public final class Menu implements Json.JsonValue {
    private final Record menu = new Record();
    private final List<Object> items = new ArrayList<Object>();

    public Menu(String title) {
        menu.put("title", title);
        menu.put("items", items);
    }

    public Menu item(String label, int id) {
        return item(label, id, null, false, true);
    }

    public Menu item(String label, int id, String shortcut) {
        return item(label, id, shortcut, false, true);
    }

    public Menu item(String label, int id, String shortcut, boolean checked, boolean enabled) {
        Record it = new Record();
        it.put("label", label);
        it.put("id", Integer.valueOf(id));
        if (shortcut != null) it.put("shortcut", shortcut);
        it.put("checked", Boolean.valueOf(checked));
        it.put("enabled", Boolean.valueOf(enabled));
        items.add(it);
        return this;
    }

    public Menu separator() {
        items.add("-");
        return this;
    }

    public static List<Menu> bar(Menu... menus) {
        List<Menu> l = new ArrayList<Menu>();
        for (Menu m : menus) l.add(m);
        return l;
    }

    @Override
    public Object toJson() {
        return menu;
    }
}
