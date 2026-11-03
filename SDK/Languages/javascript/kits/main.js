// Kit demo: the sound kit (sfx.js) and the feel kit (juice.js) working together. Run this folder as an app
// (Studio: open the folder, Run; or copy it to sdmc:/NexvynOS/Applications/KitDemoJS.nxvapp/). Then copy sfx.js and
// juice.js into your own game. This screen shows the blocks; it is not a menu to copy.
//
// Art direction of this demo: "a cold signal". Clean, electric, weightless. Palette frost (deep #06121F,
// ink #E8F6FF, accent #5CE1E6, accent2 #FF7AA2). Wide-tracked semibold capitals, a glowing outlined title.
// Cut-corner panels with thin borders. Floaty motion (springs). Sound: glassy coins, lasers, a lydian arpeggio, ocean.
import sfx from "./sfx.js";
import J from "./juice.js";

const P = J.palettes.frost;
let t = 0;
let sel = 0;
let activate = false;
let scene = "title";
const ship = { x: 0, y: 0, vx: 0 };
let cam = null;

app.load = () => {
  J.init();
  sfx.init();
  const R = sfx.recipes;
  sfx.define("tick", R.ui({ kind: "tick", pitch: 1.2 }), { bus: "ui" });
  sfx.define("confirm", R.ui({ kind: "confirm", pitch: 1.2 }), { bus: "ui" });
  sfx.define("laser", R.laser({ pitch: 1.1 }), { variants: 3, maxVoices: 4 });
  sfx.define("coin", R.coin({ pitch: 1.12 }), { variants: 3 });
  sfx.define("boom", R.explosion({ size: 0.5 }), { duck: ["music", 0.4, 0.4] });
  sfx.define("ocean", R.ambience({ kind: "ocean" }));
  sfx.song("theme", R.song({ bpm: 108, root: "E3", scale: "lydian", chords: [1, 2, 6, 5], arp: "updown", arpRate: 16, drums: "soft", bass: "simple" }));
  J.onUi = (kind) => sfx.play(kind === "press" ? "confirm" : "tick");
  sfx.ambience("ocean");
  sfx.music("theme");
  cam = J.camera({ lag: 5, lead: 0.3 });
};

app.update = (dt) => {
  t += dt;
  sfx.update(dt);
  J.update(dt);
  const gdt = J.dt(dt);
  if (scene === "play") {
    const [sx] = input.stick("left");
    const dir = sx + (input.down("right") ? 1 : 0) - (input.down("left") ? 1 : 0);
    ship.vx = J.damp(ship.vx, dir * 420, 8, gdt);
    ship.x += ship.vx * gdt;
    cam.follow(ship.x, 0, ship.vx, 0, gdt);
  }
};

function fire(big) {
  sfx.play(big ? "boom" : "laser");
  J.burst(ship.x, ship.y - 30, big ? "magic" : "sparks", { angle: -Math.PI / 2, spread: 0.5, n: big ? 30 : 10 });
  J.shake(big ? 0.6 : 0.15);
  if (big) { J.hitstop(0.06); J.flash(P.accent, 0.2, 0.35); }
}

function drawTitle(w, h) {
  const s = Math.floor(Math.min(w * 0.1, h * 0.18));
  J.title(TR("title"), 0, h * 0.14 + Math.sin(t * 1.1) * 4, s, { font: "semibold", fill: P.light, fill2: P.accent, outline: P.deep,
    outlineW: s * 0.04, glow: P.accent, glowAlpha: 0.6, align: "center", w, spacing: s * 0.22 });
  gfx.color(P.ink);
  J.spaced(TR("tagline"), 0, h * 0.14 + s * 1.3, s * 0.18, "medium", s * 0.08, "center", w);
  const items = [["play", TR("play")], ["sound", TR("sound")]];
  const bw = Math.min(280, w * 0.36), bh = Math.max(44, h * 0.08);
  items.forEach(([key, label], i) => {
    const [clicked] = J.button("m" + i, label,w / 2 - bw / 2, h * 0.58 + i * (bh + 14), bw, bh, { shape: "cut", cut: 12,
      fill: P.bg, fillHover: P.mid, ink: P.ink, border: P.accent + "55", focusColor: P.accent, focused: sel === i, activate,
      glow: P.accent, depth: 3, font: "semibold" });
    if (clicked) {
      if (key === "play") J.transition("pixels", 0.7, () => { scene = "play"; }, P.deep);
      else sfx.setBus("music", sfx.bus("music") > 0 ? 0 : 0.55);
    }
  });
}

function drawPlay(w, h) {
  ship.y = h * 0.75;
  const [ox] = cam.offset(w, h, 14);           // only x: the camera follows the ship sideways
  gfx.push(ox, 0);
  for (let i = -20; i <= 20; i++) {             // a floor of light posts to show the camera move
    const x = i * 160;
    J.glow(x, h * 0.86, 40, P.accent2, 0.5);
    gfx.rect(x - 2, h * 0.86, 4, h * 0.14, 0, P.mid);
  }
  J.blob(ship.x, ship.y + 26, 90, 18, 0.6);
  J.glow(ship.x, ship.y + 18, 46, P.accent, 0.7);
  gfx.poly([ship.x, ship.y - 28, ship.x + 30, ship.y + 18, ship.x - 30, ship.y + 18], P.ink);
  J.drawParticles();
  gfx.pop();
  gfx.color(P.ink);
  J.spaced(TR("hint"), 0, h - 40, 15, "medium", 2, "center", w);
}

app.draw = (w, h) => {
  J.gradient(0, 0, w, h, [P.deep, P.bg, P.mid]);
  J.glow(w * 0.5, h * 0.3, w * 0.45, P.accent, 0.25);
  if (!sfx.ready()) {
    J.panel(w / 2 - 160, h - 24, 320, 6, { shape: "pill", fill: P.deep, shadow: false });
    J.panel(w / 2 - 160, h - 24, 320 * sfx.progress(), 6, { shape: "pill", fill: P.accent, shadow: false });
  }
  const [sx, sy] = J.shakeOffset(12);
  gfx.push(sx, sy);
  if (scene === "title") { drawTitle(w, h); J.drawParticles(); } else drawPlay(w, h);
  gfx.pop();
  J.vignette(w, h, 0.5);
  J.overlay(w, h);
  J.endFrame();
  activate = false;
};

app.event = (e) => {
  J.event(e);
  if (e.type === "paddown" || e.type === "keydown") {
    const k = e.pad || e.key;
    if (scene === "title") {
      if (k === "up" || k === "down") sel = (sel + 1) % 2;
      else if (k === "a" || k === "enter" || k === "space") activate = true;
    } else if (k === "a" || k === "space") fire(false);
    else if (k === "x" || k === "enter") fire(true);
    else if (k === "y") { sfx.play("coin"); J.floatText("+10", ship.x, ship.y - 40, P.accent2, 22); }
    else if (k === "b" || k === "escape") J.transition("fade", 0.5, () => { scene = "title"; }, P.deep);
  } else if (e.type === "mousedown" && scene === "play") fire(e.clicks === 2);
};
