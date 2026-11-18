// User-initiated HTTPS request; late replies cannot revive a suspended app.
let busy = false, generation = 0, active = true, status = "ready";
async function refresh() {
    if (busy || !active) return;
    if (!sys.online()) { status = "offline"; return; }
    busy = true; status = "loading";
    const token = ++generation;
    try {
        const res = await net.get("https://example.com/");
        if (active && token === generation) status = res.ok ? "success" : "error";
    } catch (_) {
        if (active && token === generation) status = "error";
    } finally {
        if (token === generation) busy = false;
    }
}
function stop() { active = false; generation++; busy = false; status = "ready"; }
export default {
    load() { active = true; },
    draw(w, h) {
        gfx.clear(theme.bg);
        nxui.begin(w, h);
        nxui.card("request");
        nxui.label("title", TR("title"), "title");
        nxui.label("status", TR(status), "body");
        if (nxui.button("refresh", TR("refresh"), "primary")) refresh();
        nxui.cardEnd();
        nxui.endFrame();
    },
    suspend: stop,
    resume() { active = true; },
    close: stop
};
