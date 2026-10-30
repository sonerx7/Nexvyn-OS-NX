package nexvyn;

/** One answer for App.search(query): picking it calls App.open(arg) (or load(arg) when the app was closed). */
public final class SearchResult implements Json.JsonValue {
    private final Record r = new Record();

    public SearchResult(String title, String subtitle, String icon, String arg) {
        r.put("title", title);
        r.put("subtitle", subtitle);
        r.put("icon", icon);
        r.put("arg", arg);
    }

    @Override
    public Object toJson() {
        return r;
    }
}
