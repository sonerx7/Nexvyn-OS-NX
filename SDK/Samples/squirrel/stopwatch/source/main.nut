// Stopwatch: start, stop, laps with the fastest and slowest highlighted, kept between runs.
// Shows: a class as the app, update() for smooth redraws only while running, ui.beginScroll lists,
// store for arrays, menu items with "enabled", sys.share for the lap list, suspend/autosave.

class Stopwatch {
    running = false;
    stored = 0.0;        // seconds measured before the current run
    since = 0.0;       // sys.time() when the current run started
    laps = null;       // created in load(): array defaults would be shared by every instance

    function load(arg) {
        laps = store.get("laps", []);
        stored = store.get("elapsed", 0.0).tofloat();
    }

    // update() exists only so the window is redrawn every frame while the clock runs
    function update(dt) {}

    function elapsed() {
        return running ? stored + (sys.time() - since) : stored;
    }

    function clock(t) {
        local cs = (t * 100).tointeger();
        return format("%02d:%02d.%02d", cs / 6000, (cs / 100) % 60, cs % 100);
    }

    function toggle() {
        if (running) {
            stored = elapsed();
            running = false;
            save();
        } else {
            since = sys.time();
            running = true;
        }
        audio.play("click");
    }

    function lap() {
        if (!running) return;
        local total = elapsed();
        local prev = laps.len() > 0 ? laps[laps.len() - 1].total : 0.0;
        laps.append({total = total, split = total - prev});
        save();
        audio.tone(880, 0.05, 0.3, "sine");
    }

    function reset() {
        running = false;
        stored = 0.0;
        laps = [];
        save();
    }

    function save() {
        store.set("laps", laps);
        store.set("elapsed", running ? elapsed() : stored);
    }

    function extremes() {
        local best = -1, worst = -1;
        if (laps.len() < 2) return [best, worst];
        foreach (i, l in laps) {
            if (best < 0 || l.split < laps[best].split) best = i;
            if (worst < 0 || l.split > laps[worst].split) worst = i;
        }
        return [best, worst];
    }

    function draw(w, h) {
        gfx.clear(theme.bg);
        gfx.color(running ? theme.accent : theme.text);
        gfx.text(clock(elapsed()), 0, 26, 56, "mono", "center", w);

        local bw = 130, gap = 12, x = (w - bw * 3 - gap * 2) / 2, y = 104;
        if (ui.button(running ? TR("stop") : TR("start"), x, y, bw, 40, running ? "destructive" : "primary",
                running ? "pause" : "play_arrow")) toggle();
        if (ui.button(TR("lap"), x + bw + gap, y, bw, 40, "default", "flag", running)) lap();
        if (ui.button(TR("reset"), x + (bw + gap) * 2, y, bw, 40, "default", "restart_alt", !running && stored > 0)) reset();

        local top = 162, listH = h - top - 16;
        ui.group(20, top, w - 40, listH);
        if (laps.len() == 0) {
            gfx.color(theme.text3);
            gfx.text(TR("no_laps"), 20, top + listH / 2 - 9, 14, "sans", "center", w - 40);
            return;
        }
        local ex = extremes();
        ui.beginScroll("laps", 20, top, w - 40, listH, laps.len() * 36 + 8);
        for (local n = 0; n < laps.len(); n++) {
            local i = laps.len() - 1 - n;      // newest first
            local l = laps[i], ry = 4 + n * 36;
            gfx.color(i == ex[0] ? theme.green : (i == ex[1] ? theme.red : theme.text));
            gfx.text(TR("lap_n", i + 1), 16, ry + 9, 14, "medium");
            gfx.text(clock(l.split), 0, ry + 9, 14, "mono", "center", w - 40);
            gfx.color(theme.text2);
            gfx.text(clock(l.total), 0, ry + 9, 14, "mono", "right", w - 56);
            if (n < laps.len() - 1) ui.separator(16, ry + 35, w - 56);
        }
        ui.endScroll();
    }

    function event(e) {
        if (e.type != "keydown") return;
        if (e.key == "space" || e.key == "enter") toggle();
        else if (e.key == "l") lap();
        else if (e.key == "r" && !running) reset();
    }

    function menu() {
        return [{title = TR("app"), items = [
            {label = running ? TR("stop") : TR("start"), id = 1, shortcut = "Space"},
            {label = TR("lap"), id = 2, shortcut = "L", enabled = running},
            "-",
            {label = TR("share"), id = 3, enabled = laps.len() > 0},
            {label = TR("reset"), id = 4, enabled = !running}
        ]}];
    }

    function onmenu(id) {
        if (id == 1) toggle();
        else if (id == 2) lap();
        else if (id == 3) {
            local text = "";
            foreach (i, l in laps) text += TR("lap_n", i + 1) + "  " + clock(l.split) + "  " + clock(l.total) + "\n";
            sys.share(text);
        } else if (id == 4) reset();
    }

    // the console goes to sleep or HOME: stop counting and keep the result
    function suspend() {
        if (running) toggle();
    }

    function autosave() {
        save();
    }

    function close() {
        save();
        return true;
    }
}

return Stopwatch();
