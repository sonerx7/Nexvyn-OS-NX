// Snake: a complete little game in Squirrel.
// Shows: "gamepad": true with paddown events, keyboard arrows, touch (tap beside the head to turn),
// a fixed-step game loop in update(dt), arrays of tables, rand/srand, audio.tone, sys.vibrate and a best score in store.

const COLS = 24;
const ROWS = 16;
local WASD = {w = "up", s = "down", a = "left", d = "right"};

class Snake {
    body = null;       // [{x, y}, ...], head first
    dir = null;        // current direction {x, y}
    next = null;       // queued turns, so two quick presses in one step both count
    food = null;
    score = 0;
    best = 0;
    state = "ready";   // "ready", "play", "paused", "over"
    acc = 0.0;
    step = 0.14;

    function load(arg) {
        best = store.get("best", 0);
        srand(sys.epoch().tointeger());
        restart();
        state = "ready";
    }

    function restart() {
        body = [{x = 6, y = 8}, {x = 5, y = 8}, {x = 4, y = 8}];
        dir = {x = 1, y = 0};
        next = [];
        score = 0;
        step = 0.14;
        acc = 0.0;
        placeFood();
        state = "play";
    }

    function placeFood() {
        while (true) {
            local f = {x = rand() % COLS, y = rand() % ROWS};
            local free = true;
            foreach (p in body) if (p.x == f.x && p.y == f.y) { free = false; break; }
            if (free) { food = f; return; }
        }
    }

    // any input on the title or game-over screen starts a new game; on the pause screen it continues
    function wake() {
        if (state == "paused") state = "play";
        else if (state != "play") restart();
    }

    function turn(dx, dy) {
        if (state != "play") { wake(); return; }
        local last = next.len() > 0 ? next[next.len() - 1] : dir;
        if (last.x == -dx && last.y == -dy) return;   // no instant reverse
        if (last.x == dx && last.y == dy) return;
        if (next.len() < 2) next.append({x = dx, y = dy});
    }

    function update(dt) {
        if (state != "play") return;
        acc += dt;
        while (acc >= step && state == "play") {
            acc -= step;
            tick();
        }
    }

    function tick() {
        if (next.len() > 0) dir = next.remove(0);
        local head = {x = (body[0].x + dir.x + COLS) % COLS, y = (body[0].y + dir.y + ROWS) % ROWS};
        foreach (i, p in body) {
            if (i < body.len() - 1 && p.x == head.x && p.y == head.y) { gameOver(); return; }
        }
        body.insert(0, head);
        if (head.x == food.x && head.y == food.y) {
            score++;
            if (step > 0.06) step -= 0.004;
            audio.tone(660 + score * 10, 0.06, 0.4, "square");
            placeFood();
        } else {
            body.pop();
        }
    }

    function gameOver() {
        state = "over";
        audio.tone(160, 0.35, 0.5, "saw");
        sys.vibrate(0.6, 200);
        if (score > best) {
            best = score;
            store.set("best", best);
        }
    }

    function draw(w, h) {
        gfx.clear(theme.dark ? "#10141A" : "#E9EEF3");
        local cell = (w / COLS < (h - 40) / ROWS ? w / COLS : (h - 40) / ROWS).tointeger();
        local ox = (w - cell * COLS) / 2, oy = 40 + (h - 40 - cell * ROWS) / 2;
        gfx.color(theme.text);
        gfx.text(TR("score", score), 16, 10, 16, "semibold");
        gfx.color(theme.text2);
        gfx.text(TR("best", best), 0, 10, 16, "sans", "right", w - 16);
        gfx.rect(ox, oy, cell * COLS, cell * ROWS, 6, theme.dark ? "#1A212B" : "#FFFFFF");
        gfx.circle(ox + food.x * cell + cell / 2.0, oy + food.y * cell + cell / 2.0, cell * 0.38, theme.red);
        foreach (i, p in body) {
            gfx.rect(ox + p.x * cell + 1, oy + p.y * cell + 1, cell - 2, cell - 2, 4, i == 0 ? theme.green : theme.accent);
        }
        if (state != "play") {
            gfx.rect(ox, oy, cell * COLS, cell * ROWS, 6, "#00000088");
            gfx.color("#FFFFFF");
            local title = state == "over" ? TR("game_over") : (state == "paused" ? TR("paused") : TR("title"));
            gfx.text(title, 0, oy + cell * ROWS / 2 - 40, 30, "bold", "center", w);
            gfx.text(TR("start_hint"), 0, oy + cell * ROWS / 2 + 4, 15, "sans", "center", w);
        }
        // touch: a tap beside the head turns the snake towards it
        local hit = ui.hit("board", ox, oy, cell * COLS, cell * ROWS);
        if (hit.clicked) {
            if (state != "play") { wake(); return; }
            local m = ui.mouse();
            local hx = ox + body[0].x * cell + cell / 2.0, hy = oy + body[0].y * cell + cell / 2.0;
            local dx = m[0] - hx, dy = m[1] - hy;
            if (dir.x != 0) turn(0, dy < 0 ? -1 : 1);
            else turn(dx < 0 ? -1 : 1, 0);
        }
    }

    function event(e) {
        local k = null;
        if (e.type == "paddown") {
            k = e.pad;                                   // "up" "down" "left" "right" "a" "plus" ...
            if (k == "plus" && state == "play") { state = "paused"; return; }
            if (k == "a" || k == "plus") { wake(); return; }
        } else if (e.type == "keydown") {
            k = WASD.rawin(e.key) ? WASD[e.key] : e.key;
            if ((k == "escape" || k == "p") && state == "play") { state = "paused"; return; }
            if (k == "space" || k == "enter") { wake(); return; }
        } else {
            return;
        }
        if (k == "up") turn(0, -1);
        else if (k == "down") turn(0, 1);
        else if (k == "left") turn(-1, 0);
        else if (k == "right") turn(1, 0);
    }

    function menu() {
        return [{title = TR("game"), items = [{label = TR("new_game"), id = 1, shortcut = "Enter"}, "-",
                                              {label = TR("reset_best"), id = 2}]}];
    }

    function onmenu(id) {
        if (id == 1) restart();
        else if (id == 2) {
            best = 0;
            store.set("best", 0);
        }
    }

    // HOME button, sleep or another window: pause, any input continues
    function suspend() {
        if (state == "play") state = "paused";
    }

    function focus(focused) {
        if (!focused && state == "play") state = "paused";
    }
}

return Snake();
