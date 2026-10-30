package nexvyn;

/** Raw input for App.event(): see sdk/SDK.en.md section 5 for the types and names. */
public final class Event {
    /** "mousedown" "mouseup" "mousemove" "scroll" "keydown" "keyup" "text" "paddown" "padup" "pinch" "rotate" */
    public final String type;
    public final double x, y, dx, dy, scale, angle;
    public final String button, key, text, pad;
    public final int clicks;
    public final boolean touch, shift, ctrl, cancel;

    Event(Record r) {
        type = r.str("type");
        x = r.num("x");
        y = r.num("y");
        dx = r.num("dx");
        dy = r.num("dy");
        scale = r.num("scale");
        angle = r.num("angle");
        button = r.str("button");
        key = r.str("key");
        text = r.str("text");
        pad = r.str("pad");
        clicks = r.integer("clicks");
        touch = r.bool("touch");
        shift = r.bool("shift");
        ctrl = r.bool("ctrl");
        cancel = r.bool("cancel");
    }

    public boolean is(String t) {
        return type.equals(t);
    }
}
