package nexvyn;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * JSON text <-> Java values: null, Boolean, Double (every number), String, List (ArrayList) and Record (a
 * LinkedHashMap). Also the values the SDK passes: a {@link Callback} becomes {"$fn": id}, a {@link Mesh}
 * {"$mesh": id}, objects implementing {@link JsonValue} their toJson().
 */
public final class Json {
    private Json() {
    }

    /** Values with their own JSON form (menus, search results). */
    public interface JsonValue {
        Object toJson();
    }

    // ------------------------------------------------------------------ encode
    public static String encode(Object v) {
        StringBuilder sb = new StringBuilder();
        write(sb, v, 0);
        return sb.toString();
    }

    /** Pretty-printed (two spaces). */
    public static String encode(Object v, boolean pretty) {
        if (!pretty) return encode(v);
        String s = encode(v);
        return Host.str(Host.index("json.encode"), new Object[]{new Raw(s), Boolean.TRUE});
    }

    /** Already encoded JSON text (passed through unchanged). */
    static final class Raw {
        final String json;

        Raw(String json) {
            this.json = json;
        }
    }

    static void write(StringBuilder sb, Object v, int depth) {
        if (depth > 64 || v == null) {
            sb.append("null");
        } else if (v instanceof Raw) {
            sb.append(((Raw) v).json);
        } else if (v instanceof String) {
            quote(sb, (String) v);
        } else if (v instanceof Boolean) {
            sb.append(((Boolean) v).booleanValue() ? "true" : "false");
        } else if (v instanceof Double || v instanceof Float) {
            double d = ((Number) v).doubleValue();
            if (Double.isNaN(d) || Double.isInfinite(d)) sb.append("null");
            else if (d == Math.rint(d) && Math.abs(d) < 1e15) sb.append((long) d);
            else sb.append(d);
        } else if (v instanceof Number) {
            sb.append(((Number) v).longValue());
        } else if (v instanceof Character) {
            quote(sb, String.valueOf(v));
        } else if (v instanceof Callback) {
            sb.append("{\"$fn\":").append(Host.register((Callback) v)).append('}');
        } else if (v instanceof Mesh) {
            sb.append("{\"$mesh\":").append(((Mesh) v).id).append('}');
        } else if (v instanceof JsonValue) {
            write(sb, ((JsonValue) v).toJson(), depth + 1);
        } else if (v instanceof Map) {
            sb.append('{');
            boolean first = true;
            for (Object o : ((Map<?, ?>) v).entrySet()) {
                Map.Entry<?, ?> e = (Map.Entry<?, ?>) o;
                if (!first) sb.append(',');
                first = false;
                quote(sb, String.valueOf(e.getKey()));
                sb.append(':');
                write(sb, e.getValue(), depth + 1);
            }
            sb.append('}');
        } else if (v instanceof List) {
            sb.append('[');
            List<?> l = (List<?>) v;
            for (int i = 0; i < l.size(); i++) {
                if (i > 0) sb.append(',');
                write(sb, l.get(i), depth + 1);
            }
            sb.append(']');
        } else if (v instanceof Object[]) {
            Object[] a = (Object[]) v;
            sb.append('[');
            for (int i = 0; i < a.length; i++) {
                if (i > 0) sb.append(',');
                write(sb, a[i], depth + 1);
            }
            sb.append(']');
        } else if (v instanceof double[]) {
            double[] a = (double[]) v;
            sb.append('[');
            for (int i = 0; i < a.length; i++) {
                if (i > 0) sb.append(',');
                write(sb, Double.valueOf(a[i]), depth + 1);
            }
            sb.append(']');
        } else if (v instanceof float[]) {
            float[] a = (float[]) v;
            sb.append('[');
            for (int i = 0; i < a.length; i++) {
                if (i > 0) sb.append(',');
                write(sb, Double.valueOf(a[i]), depth + 1);
            }
            sb.append(']');
        } else if (v instanceof int[]) {
            int[] a = (int[]) v;
            sb.append('[');
            for (int i = 0; i < a.length; i++) {
                if (i > 0) sb.append(',');
                sb.append(a[i]);
            }
            sb.append(']');
        } else {
            quote(sb, String.valueOf(v));
        }
    }

    static void quote(StringBuilder sb, String s) {
        sb.append('"');
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            switch (c) {
                case '"': sb.append("\\\""); break;
                case '\\': sb.append("\\\\"); break;
                case '\n': sb.append("\\n"); break;
                case '\r': sb.append("\\r"); break;
                case '\t': sb.append("\\t"); break;
                default:
                    if (c < 0x20) {
                        String h = Integer.toHexString(c);
                        sb.append("\\u");
                        for (int k = h.length(); k < 4; k++) sb.append('0');
                        sb.append(h);
                    } else {
                        sb.append(c);
                    }
            }
        }
        sb.append('"');
    }

    // ------------------------------------------------------------------ decode
    /** Parses JSON text; null for invalid text. */
    public static Object decode(String text) {
        if (text == null) return null;
        Parser p = new Parser(text);
        try {
            p.ws();
            Object v = p.value(0);
            p.ws();
            return p.i == text.length() ? v : null;
        } catch (RuntimeException e) {
            return null;
        }
    }

    private static final class Parser {
        final String s;
        int i;

        Parser(String s) {
            this.s = s;
        }

        void ws() {
            while (i < s.length() && s.charAt(i) <= ' ') i++;
        }

        Object value(int depth) {
            if (depth > 200 || i >= s.length()) throw new IllegalArgumentException();
            char c = s.charAt(i);
            if (c == '{') return object(depth);
            if (c == '[') return array(depth);
            if (c == '"') return string();
            if (s.startsWith("true", i)) {
                i += 4;
                return Boolean.TRUE;
            }
            if (s.startsWith("false", i)) {
                i += 5;
                return Boolean.FALSE;
            }
            if (s.startsWith("null", i)) {
                i += 4;
                return null;
            }
            int start = i;
            while (i < s.length() && "+-0123456789.eE".indexOf(s.charAt(i)) >= 0) i++;
            if (start == i) throw new IllegalArgumentException();
            return Double.valueOf(Double.parseDouble(s.substring(start, i)));
        }

        Object object(int depth) {
            Record r = new Record();
            i++;
            ws();
            if (i < s.length() && s.charAt(i) == '}') {
                i++;
                return r;
            }
            while (true) {
                ws();
                String k = string();
                ws();
                if (s.charAt(i++) != ':') throw new IllegalArgumentException();
                ws();
                r.put(k, value(depth + 1));
                ws();
                char c = s.charAt(i++);
                if (c == '}') break;
                if (c != ',') throw new IllegalArgumentException();
            }
            if (r.size() == 1 && r.get("$mesh") instanceof Double) return new Mesh(((Double) r.get("$mesh")).intValue());
            return r;
        }

        List<Object> array(int depth) {
            List<Object> l = new ArrayList<Object>();
            i++;
            ws();
            if (i < s.length() && s.charAt(i) == ']') {
                i++;
                return l;
            }
            while (true) {
                ws();
                l.add(value(depth + 1));
                ws();
                char c = s.charAt(i++);
                if (c == ']') break;
                if (c != ',') throw new IllegalArgumentException();
            }
            return l;
        }

        String string() {
            if (s.charAt(i) != '"') throw new IllegalArgumentException();
            i++;
            StringBuilder sb = new StringBuilder();
            while (true) {
                char c = s.charAt(i++);
                if (c == '"') break;
                if (c != '\\') {
                    sb.append(c);
                    continue;
                }
                char e = s.charAt(i++);
                switch (e) {
                    case 'n': sb.append('\n'); break;
                    case 'r': sb.append('\r'); break;
                    case 't': sb.append('\t'); break;
                    case 'b': sb.append('\b'); break;
                    case 'f': sb.append('\f'); break;
                    case 'u':
                        sb.append((char) Integer.parseInt(s.substring(i, i + 4), 16));
                        i += 4;
                        break;
                    default: sb.append(e);
                }
            }
            return sb.toString();
        }
    }
}
