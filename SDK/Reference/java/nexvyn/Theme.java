package nexvyn;

/** The system colors ("#RRGGBB"), updated live with light/dark mode: Theme.get("accent"), Theme.bg(), Theme.dark(). */
public final class Theme {
    private static Record colors = new Record();

    private Theme() {
    }

    static void set(Record r) {
        colors = r;
    }

    public static String get(String name) {
        Object v = colors.get(name);
        return v instanceof String ? (String) v : "#000000";
    }

    public static boolean dark() {
        return colors.bool("dark");
    }

    public static String bg() { return get("bg"); }
    public static String window() { return get("window"); }
    public static String text() { return get("text"); }
    public static String text2() { return get("text2"); }
    public static String text3() { return get("text3"); }
    public static String separator() { return get("separator"); }
    public static String accent() { return get("accent"); }
    public static String red() { return get("red"); }
    public static String orange() { return get("orange"); }
    public static String yellow() { return get("yellow"); }
    public static String green() { return get("green"); }
    public static String blue() { return get("blue"); }
    public static String purple() { return get("purple"); }
    public static String pink() { return get("pink"); }
    public static String gray() { return get("gray"); }
}
