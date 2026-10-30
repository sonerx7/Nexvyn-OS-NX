package nexvyn;

import java.util.LinkedHashMap;

/** A JSON object from the SDK (events, network responses, sys.date(), fs.list() entries...) with typed getters. */
public class Record extends LinkedHashMap<String, Object> {
    public String str(String key) {
        Object v = get(key);
        return v == null ? "" : v instanceof Double && ((Double) v) == Math.rint((Double) v)
                ? String.valueOf(((Double) v).longValue()) : String.valueOf(v);
    }

    public double num(String key) {
        Object v = get(key);
        return v instanceof Number ? ((Number) v).doubleValue() : v instanceof Boolean && (Boolean) v ? 1 : 0;
    }

    public int integer(String key) {
        return (int) num(key);
    }

    public boolean bool(String key) {
        Object v = get(key);
        return v instanceof Boolean ? (Boolean) v : v instanceof Number ? ((Number) v).doubleValue() != 0 : v != null;
    }

    public Record rec(String key) {
        Object v = get(key);
        return v instanceof Record ? (Record) v : new Record();
    }
}
