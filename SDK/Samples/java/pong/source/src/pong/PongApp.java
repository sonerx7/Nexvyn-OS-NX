// Pong: you against the console, first to 7 points.
// Shows: "gamepad": true, polling Input.stick / Input.down every frame, keyboard state from keydown/keyup events,
// dragging the paddle by touch with Ui.mouse, a virtual 640x360 court scaled into any window size with Gfx.push,
// Audio.tone sound effects, a pause on suspend() / focus(false), and the number of wins in Store.
package pong;

import java.util.List;
import java.util.Random;

import nexvyn.*;

public class PongApp extends App {
    private static final double W = 640, H = 360, PADDLE = 70, PW = 10, BALL = 9, WIN = 7;

    private final Random random = new Random();
    private double you, cpu;                 // paddle centres (y)
    private double bx, by, vx, vy;           // ball
    private int yourScore, cpuScore, wins;
    private String state = "serve";          // "serve", "play", "paused", "over"
    private boolean keyUp, keyDown;

    @Override
    public void load(String arg) {
        Object w = Store.get("wins", 0);
        wins = w instanceof Number ? ((Number) w).intValue() : 0;
        newGame();
    }

    private void newGame() {
        yourScore = 0;
        cpuScore = 0;
        you = H / 2;
        cpu = H / 2;
        center();
        state = "serve";
    }

    private void center() {
        bx = W / 2;
        by = H / 2;
        vx = 0;
        vy = 0;
    }

    private void serve() {
        double angle = (random.nextDouble() - 0.5) * 0.9;
        double dir = random.nextInt(2) == 0 ? 1 : -1;
        vx = Math.cos(angle) * 300 * dir;
        vy = Math.sin(angle) * 300;
        state = "play";
    }

    // A, Enter, Space or a tap: serve, continue or start again
    private void confirm() {
        if (state.equals("serve")) serve();
        else if (state.equals("paused")) state = vx == 0 ? "serve" : "play";
        else if (state.equals("over")) newGame();
    }

    @Override
    public void update(double dt) {
        if (dt > 0.05) dt = 0.05;
        // your paddle: stick, D-pad or arrow keys
        double move = 0;
        double[] stick = Input.stick("left");
        if (stick != null && stick.length > 1 && Math.abs(stick[1]) > 0.2) move = -stick[1];   // y up is positive
        if (Input.down("up") || keyUp) move = -1;
        if (Input.down("down") || keyDown) move = 1;
        you = clamp(you + move * 420 * dt, PADDLE / 2, H - PADDLE / 2);
        if (!state.equals("play")) return;

        // the console's paddle follows the ball, a little slower than the ball can move
        double target = vx > 0 ? by : H / 2;
        cpu += clamp(target - cpu, -260 * dt, 260 * dt);
        cpu = clamp(cpu, PADDLE / 2, H - PADDLE / 2);

        bx += vx * dt;
        by += vy * dt;
        if (by < BALL) {
            by = BALL;
            vy = Math.abs(vy);
            Audio.tone(300, 0.03, 0.3, "square");
        } else if (by > H - BALL) {
            by = H - BALL;
            vy = -Math.abs(vy);
            Audio.tone(300, 0.03, 0.3, "square");
        }
        if (vx < 0 && bx - BALL < 30 + PW && bx > 20 && Math.abs(by - you) < PADDLE / 2 + BALL) bounce(you, 1);
        if (vx > 0 && bx + BALL > W - 30 - PW && bx < W - 20 && Math.abs(by - cpu) < PADDLE / 2 + BALL) bounce(cpu, -1);
        if (bx < -20) point(false);
        else if (bx > W + 20) point(true);
    }

    // the further from the paddle's centre, the steeper the ball leaves; every hit is a bit faster
    private void bounce(double paddle, int dir) {
        double offset = (by - paddle) / (PADDLE / 2);
        double speed = Math.min(Math.hypot(vx, vy) * 1.06, 720);
        double angle = offset * 1.0;
        vx = Math.cos(angle) * speed * dir;
        vy = Math.sin(angle) * speed;
        Audio.tone(dir > 0 ? 660 : 520, 0.04, 0.4, "square");
    }

    private void point(boolean yours) {
        if (yours) yourScore++;
        else cpuScore++;
        Audio.tone(yours ? 880 : 180, 0.2, 0.4, yours ? "triangle" : "saw");
        center();
        state = "serve";
        if (yourScore >= WIN || cpuScore >= WIN) {
            state = "over";
            if (yourScore > cpuScore) {
                wins++;
                Store.set("wins", wins);
            } else {
                Sys.vibrate(0.7, 250);
            }
        }
    }

    private static double clamp(double v, double lo, double hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    @Override
    public void draw(double w, double h) {
        Gfx.clear("#0B0F14");
        double s = Math.min(w / W, h / H);
        double ox = (w - W * s) / 2, oy = (h - H * s) / 2;

        // touch / mouse: drag anywhere on the left half to move your paddle, tap to serve
        List<Object> m = Ui.mouse();
        boolean down = m.size() > 2 && Boolean.TRUE.equals(m.get(2));
        Record hit = Ui.hit("court", ox, oy, W * s, H * s);
        if (down && hit.bool("held")) {
            double mx = ((Number) m.get(0)).doubleValue(), my = ((Number) m.get(1)).doubleValue();
            if ((mx - ox) / s < W / 2) you = clamp((my - oy) / s, PADDLE / 2, H - PADDLE / 2);
        }
        if (hit.bool("clicked") && !state.equals("play")) confirm();

        Gfx.push(ox, oy);
        Gfx.rect(0, 0, W * s, H * s, 0, "#111821");
        for (double y = 8; y < H; y += 24) Gfx.rect(W * s / 2 - 2 * s, y * s, 4 * s, 12 * s, 2 * s, "#FFFFFF22");
        Gfx.color("#FFFFFF55");
        Gfx.text(String.valueOf(yourScore), W * s / 2 - 120 * s, 14 * s, 48 * s, "bold", "center", 80 * s);
        Gfx.text(String.valueOf(cpuScore), W * s / 2 + 40 * s, 14 * s, 48 * s, "bold", "center", 80 * s);
        Gfx.rect(20 * s, (you - PADDLE / 2) * s, PW * s, PADDLE * s, 4 * s, Theme.accent());
        Gfx.rect((W - 30) * s, (cpu - PADDLE / 2) * s, PW * s, PADDLE * s, 4 * s, Theme.orange());
        Gfx.circle(bx * s, by * s, BALL * s, "#FFFFFF");
        if (!state.equals("play")) {
            Gfx.color("#FFFFFF");
            String title = state.equals("over") ? (yourScore > cpuScore ? TR("you_win") : TR("you_lose"))
                    : state.equals("paused") ? TR("paused") : TR("serve");
            Gfx.text(title, 0, H * s / 2 + 30 * s, 26 * s, "bold", "center", W * s);
            Gfx.color("#FFFFFFAA");
            Gfx.text(TR("hint"), 0, H * s / 2 + 66 * s, 14 * s, "sans", "center", W * s);
            Gfx.text(TR("wins", wins), 0, H * s - 28 * s, 13 * s, "sans", "center", W * s);
        }
        Gfx.pop();
    }

    @Override
    public void event(Event e) {
        if (e.is("keydown") || e.is("keyup")) {
            boolean pressed = e.is("keydown");
            if ("up".equals(e.key) || "w".equals(e.key)) keyUp = pressed;
            if ("down".equals(e.key) || "s".equals(e.key)) keyDown = pressed;
            if (pressed && ("space".equals(e.key) || "enter".equals(e.key))) confirm();
            if (pressed && ("escape".equals(e.key) || "p".equals(e.key)) && state.equals("play")) state = "paused";
        } else if (e.is("paddown")) {
            if ("a".equals(e.pad)) confirm();
            if ("plus".equals(e.pad)) {
                if (state.equals("play")) state = "paused";
                else confirm();
            }
        }
    }

    @Override
    public List<Menu> menu() {
        return Menu.bar(new Menu(TR("game")).item(TR("new_game"), 1).separator().item(TR("reset_wins"), 2));
    }

    @Override
    public void onmenu(int id) {
        if (id == 1) newGame();
        else if (id == 2) {
            wins = 0;
            Store.set("wins", 0);
        }
    }

    @Override
    public void suspend() {
        if (state.equals("play")) state = "paused";
    }

    @Override
    public void focus(boolean focused) {
        if (!focused && state.equals("play")) state = "paused";
    }
}
