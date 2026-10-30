package nexvyn;

import java.io.OutputStream;
import java.io.PrintStream;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * The bridge to Nexvyn OS (source/runtimes/javaapp.cpp). Not for apps: the SDK classes (Gfx, Ui, Sys...) call it.
 * Every SDK call passes its arguments as JSON text and gets the result back as JSON text.
 */
public final class Host {
    private Host() {
    }

    private static App app;
    private static final Map<Integer, Callback> callbacks = new HashMap<Integer, Callback>();
    private static int nextCallback = 1;

    static native String call0(int fn, String argsJson);

    static native int index0(String qualifiedName);

    static native void log0(String line);

    /** Index of an SDK function ("gfx.rect"); -1 when unknown. */
    static int index(String name) {
        return index0(name);
    }

    static int register(Callback cb) {
        int id = nextCallback++;
        callbacks.put(Integer.valueOf(id), cb);
        return id;
    }

    static Object call(int fn, Object[] args) {
        return Json.decode(call0(fn, Json.encode(args == null ? new Object[0] : args)));
    }

    static void run(int fn, Object[] args) {
        call0(fn, Json.encode(args == null ? new Object[0] : args));
    }

    static boolean bool(int fn, Object[] args) {
        Object r = call(fn, args);
        return r instanceof Boolean ? ((Boolean) r).booleanValue() : r instanceof Number && ((Number) r).doubleValue() != 0;
    }

    static double num(int fn, Object[] args) {
        Object r = call(fn, args);
        return r instanceof Number ? ((Number) r).doubleValue() : 0;
    }

    static int integer(int fn, Object[] args) {
        Object r = call(fn, args);
        return r instanceof Number ? ((Number) r).intValue() : -1;
    }

    static String str(int fn, Object[] args) {
        Object r = call(fn, args);
        return r == null ? null : r instanceof String ? (String) r : String.valueOf(r);
    }

    static Record rec(int fn, Object[] args) {
        Object r = call(fn, args);
        return r instanceof Record ? (Record) r : null;
    }

    @SuppressWarnings("unchecked")
    static List<Object> list(int fn, Object[] args) {
        Object r = call(fn, args);
        return r instanceof List ? (List<Object>) r : new ArrayList<Object>();
    }

    /** Several numbers ([w, h] = Gfx.size()); null when the call returned nothing (G3d.project behind the camera). */
    static double[] nums(int fn, Object[] args) {
        Object r = call(fn, args);
        if (!(r instanceof List)) return null;
        List<?> l = (List<?>) r;
        double[] out = new double[l.size()];
        for (int i = 0; i < out.length; i++) {
            Object v = l.get(i);
            out[i] = v instanceof Number ? ((Number) v).doubleValue() : Boolean.TRUE.equals(v) ? 1 : 0;
        }
        return out;
    }

    static Mesh mesh(int fn, Object[] args) {
        Object r = call(fn, args);
        return r instanceof Mesh ? (Mesh) r : null;
    }

    // ------------------------------------------------------------------ called by javaapp.cpp
    /** System.out / System.err go to the app's log, line by line (UTF-8). */
    private static final class LogStream extends OutputStream {
        private final StringBuilder line = new StringBuilder();
        private final byte[] pending = new byte[4];
        private int pendingLen;

        @Override
        public void write(int b) {
            if (b == 10) {
                flushLine();
                return;
            }
            pending[pendingLen++] = (byte) b;
            int lead = pending[0] & 0xFF;
            int need = lead < 0x80 ? 1 : lead < 0xE0 ? 2 : lead < 0xF0 ? 3 : 4;
            if (pendingLen >= need) {
                try {
                    line.append(new String(pending, 0, pendingLen, "UTF-8"));
                } catch (Exception e) {
                    line.append('?');
                }
                pendingLen = 0;
            }
            if (line.length() > 4096) flushLine();
        }

        @Override
        public void flush() {
            if (line.length() > 0) flushLine();
        }

        private void flushLine() {
            log0(line.toString());
            line.setLength(0);
        }
    }

    /**
     * One entry point for the host: start (a = main class), has (a = callback), call (a = callback, b = JSON list of
     * arguments, returns the JSON result), ref (a = callback id, b = arguments), release (a = id), theme (a = JSON).
     */
    static String host(String op, String a, String b) throws Exception {
        if (op.equals("start")) {
            PrintStream log = new PrintStream(new LogStream());
            System.setOut(log);
            System.setErr(log);
            Object o = Class.forName(a).newInstance();
            if (!(o instanceof App)) throw new IllegalArgumentException(a + " does not extend nexvyn.App");
            app = (App) o;
            return "";
        }
        if (op.equals("has")) return has(a) ? "1" : "";
        if (op.equals("theme")) {
            Object t = Json.decode(a);
            if (t instanceof Record) Theme.set((Record) t);
            return "";
        }
        if (op.equals("release")) {
            callbacks.remove(Integer.valueOf(Integer.parseInt(a)));
            return "";
        }
        Object parsed = Json.decode(b);
        List<?> args = parsed instanceof List ? (List<?>) parsed : new ArrayList<Object>();
        if (op.equals("ref")) {
            Callback cb = callbacks.get(Integer.valueOf(Integer.parseInt(a)));
            if (cb != null) cb.call(args.toArray());
            return "";
        }
        return Json.encode(invoke(a, args));
    }

    private static boolean has(String name) {
        if (app == null) return false;
        if (name.equals("draw")) return true;
        for (Class<?> c = app.getClass(); c != null && c != App.class; c = c.getSuperclass())
            for (Method m : c.getDeclaredMethods())
                if (m.getName().equals(name)) return true;
        return false;
    }

    private static String s(List<?> args, int i) {
        Object v = i < args.size() ? args.get(i) : null;
        return v == null ? "" : String.valueOf(v);
    }

    private static double d(List<?> args, int i) {
        Object v = i < args.size() ? args.get(i) : null;
        return v instanceof Number ? ((Number) v).doubleValue() : 0;
    }

    private static Object invoke(String name, List<?> args) {
        if (app == null) return null;
        if (name.equals("draw")) app.draw(d(args, 0), d(args, 1));
        else if (name.equals("update")) app.update(d(args, 0));
        else if (name.equals("event")) app.event(new Event(args.size() > 0 && args.get(0) instanceof Record ? (Record) args.get(0) : new Record()));
        else if (name.equals("load")) app.load(s(args, 0));
        else if (name.equals("open")) app.open(s(args, 0));
        else if (name.equals("menu")) return app.menu();
        else if (name.equals("onmenu")) app.onmenu((int) d(args, 0));
        else if (name.equals("close")) return Boolean.valueOf(app.close());
        else if (name.equals("search")) return app.search(s(args, 0));
        else if (name.equals("suspend")) app.suspend();
        else if (name.equals("resume")) app.resume();
        else if (name.equals("focus")) app.focus(args.size() > 0 && Boolean.TRUE.equals(args.get(0)));
        else if (name.equals("autosave")) app.autosave();
        else if (name.equals("unsaved")) return Boolean.valueOf(app.unsaved());
        return null;
    }
}
