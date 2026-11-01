// Menu screens: title (over a live panorama of a generated world), world list, new world, settings, pause, death,
// loading and the controls help.
import { Menu, panel, shadowText } from "./widgets.js";
import { drawIcon } from "./hud.js";
import { B } from "./registry.js";
import { listWorlds, newWorldId, deleteWorld, loadWorld } from "./storage.js";
import { seedFromString, clamp } from "./util.js";
import { GameWorld } from "./world.js";
import { Renderer } from "./render.js";

const TAGLINES = 8, VERSION = "1.0.0";

export class Screens {
  constructor(app) {
    this.app = app;
    this.menu = new Menu();
    this.screen = "title";
    this.stack = [];
    this.worlds = [];
    this.selected = 0;
    this.form = { name: "", seed: "", type: "normal", mode: "survival" };
    this.tagline = (Math.random() * TAGLINES) | 0;
    this.pano = null;
    this.t = 0;
  }

  go(s) { this.stack.push(this.screen); this.screen = s; this.menu.focus = 0; if (s === "worlds") this.refresh(); }
  backTo() { this.screen = this.stack.pop() || "title"; this.menu.focus = 0; }
  refresh() { this.worlds = listWorlds(); this.selected = clamp(this.selected, 0, Math.max(0, this.worlds.length - 1)); }

  // ---------- title panorama: a small generated world seen from a slowly turning camera ----------
  startPanorama() {
    if (this.pano) return;
    const settings = { ...this.app.settings, renderDistance: 4 };
    const world = new GameWorld({ id: null, seed: 20241101, type: "normal" }, settings);
    const fake = { settings, clock: 0, world, player: null };
    const r = new Renderer(fake);
    // stand on high ground in plains, forest or taiga (the generator knows every column before it is loaded)
    let x = 40, z = -30;
    search: for (let rr = 0; rr <= 960; rr += 24) {
      const n = Math.max(1, Math.round(rr / 8));
      for (let i = 0; i < n; i++) {
        const a = (i / n) * Math.PI * 2, cx = 40 + Math.round(Math.cos(a) * rr), cz = -30 + Math.round(Math.sin(a) * rr);
        const [hh, biome] = world.v.terrain(cx, cz);
        if (hh >= 70 && (biome === 2 || biome === 3 || biome === 5)) { x = cx; z = cz; break search; }
      }
    }
    this.pano = { world, fake, r, x, z };
  }
  stopPanorama() { if (this.pano) { this.pano.world.dispose(); this.pano = null; } }

  drawPanorama(w, h, dt) {
    const p = this.pano;
    if (!p) { gfx.gradient(0, 0, w, h, "#3B6FC4", "#B9D3FF"); return; }
    p.fake.clock += dt;
    const a = p.fake.clock * 0.04;
    const [hgt] = p.world.v.terrain(p.x, p.z);
    p.world.update(p.x, p.z);
    p.r.updateEnvironment(0.12 + Math.sin(p.fake.clock * 0.01) * 0.04, { renderDistance: 4 });
    const cam = p.r.cam;
    cam.x = p.x; cam.z = p.z; cam.y = Math.max(hgt, 62) + 14; cam.yaw = a; cam.pitch = -0.18; cam.roll = 0; cam.fov = 70;
    p.r.drawPanorama(w, h);
  }

  // ---------- frame ----------
  draw(w, h, dt) {
    this.t += dt;
    const k = this.app.uiScale(w, h);
    const m = this.menu;
    m.begin();
    m.nav(dt);
    switch (this.screen) {
      case "title": this.title(w, h, k, dt); break;
      case "worlds": this.drawPanorama(w, h, dt); this.worldList(w, h, k); break;
      case "create": this.drawPanorama(w, h, dt); this.create(w, h, k); break;
      case "settings": if (!this.app.game) this.drawPanorama(w, h, dt); this.settings(w, h, k); break;
      case "help": if (!this.app.game) this.drawPanorama(w, h, dt); this.help(w, h, k); break;
      case "pause": this.pause(w, h, k); break;
      case "dead": this.dead(w, h, k); break;
      case "loading": this.loading(w, h, k); break;
    }
  }

  // The logo: a grass block next to the name, an accent bar and the subtitle under it.
  logo(w, y, k) {
    const name = TR("title"), size = 70 * k;
    const tw = gfx.textWidth(name, size, "bold"), bs = 78 * k, gap = 16 * k;
    const x0 = (w - (bs + gap + tw)) / 2;
    drawIcon(B.grass, x0, y + 2 * k, bs);
    shadowText(name, x0 + bs + gap, y + 6 * k, size, "#FFFFFF", "left", 0, "bold");
    const by = y + 6 * k + size * 1.18;
    gfx.gradient(x0 + bs + gap, by, tw, 5 * k, "#7ED957", "#3DC6C4", true);
    shadowText(TR("subtitle"), 0, y + bs + 26 * k, 18 * k, "#E0E8FF", "center", w, "semibold");
  }

  title(w, h, k, dt) {
    this.startPanorama();
    this.drawPanorama(w, h, dt);
    gfx.gradient(0, 0, w, h * 0.55, "#0A1020A0", "#0A102000");
    const ty = h * 0.1;
    this.logo(w, ty, k);
    // one line about the game under the logo, a new one every six seconds (cross-faded)
    const per = 6, tt = this.t / per, f = tt % 1, a = Math.min(1, f * 6, (1 - f) * 6);
    const line = TR("tagline." + (1 + ((this.tagline + Math.floor(tt)) % TAGLINES)));
    const ts = 15 * k, th = 32 * k, cw = gfx.textWidth(line, ts, "semibold") + 52 * k, cx = (w - cw) / 2, cy = ty + 140 * k;
    gfx.color("#0B1222B8"); gfx.rect(cx, cy, cw, th, th / 2);
    gfx.color("#FFFFFF22"); gfx.rectLine(cx, cy, cw, th, th / 2, 1);
    gfx.alpha(a);
    gfx.icon("eco", cx + 20 * k, cy + th / 2, 17 * k, "#8FE3B8");
    gfx.color("#E8F0FF"); gfx.text(line, cx + 36 * k, cy + (th - ts * 1.3) / 2, ts, "semibold");
    gfx.unalpha();
    const m = this.menu, bw = 380 * k, bh = 50 * k, bx = (w - bw) / 2;
    let y = h * 0.5;
    if (m.button("play", TR("ui.play"), bx, y, bw, bh, k, { primary: true, icon: "play_arrow" })) this.go("worlds");
    y += bh + 14 * k;
    if (m.button("settings", TR("ui.settings"), bx, y, bw / 2 - 7 * k, bh, k, { icon: "settings" })) this.go("settings");
    if (m.button("help", TR("ui.controls"), bx + bw / 2 + 7 * k, y, bw / 2 - 7 * k, bh, k, { icon: "sports_esports" })) this.go("help");
    y += bh + 14 * k;
    if (m.button("quit", TR("ui.quit"), bx, y, bw, bh, k, { icon: "logout" })) { this.stopPanorama(); sys.exit(); }
    gfx.color("#FFFFFFA0");
    gfx.text(TR("credit"), 10 * k, h - 26 * k, 13 * k, "sans");
    gfx.text("v" + VERSION + "  SDK " + sys.sdkVersion(), 0, h - 26 * k, 13 * k, "sans", "right", w - 10 * k);
  }

  worldList(w, h, k) {
    const m = this.menu;
    const pw = Math.min(w - 40 * k, 760 * k), ph = h - 60 * k, px = (w - pw) / 2, py = 30 * k;
    panel(px, py, pw, ph, k);
    shadowText(TR("ui.select_world"), 0, py + 16 * k, 26 * k, "#FFFFFF", "center", w);
    const rowH = 70 * k, listY = py + 64 * k, listH = ph - 64 * k - 80 * k;
    const vis = Math.max(1, Math.floor(listH / rowH));
    if (input.pressed("down") || input.pressed("up")) { /* handled by focus below */ }
    const ws = this.worlds;
    if (!ws.length) shadowText(TR("ui.no_worlds"), px, listY + 30 * k, 18 * k, "#C8C8C8", "center", pw, "semibold");
    // rows are selected with the D-pad; the buttons row below acts on the selection
    if (this.btnFocus === undefined) this.btnFocus = 0;
    if (!m.mouseMoved) {
      if (input.pressed("up")) this.selected = Math.max(0, this.selected - 1);
      if (input.pressed("down")) this.selected = Math.min(ws.length - 1, this.selected + 1);
      const s = m.side();
      if (s) this.btnFocus = Math.max(0, Math.min(3, this.btnFocus + s));
      if (!ws.length && this.btnFocus === 0) this.btnFocus = 1;
      m.focus = this.btnFocus;
    }
    const first = clamp(this.selected - vis + 1, 0, Math.max(0, ws.length - vis));
    for (let i = first; i < Math.min(ws.length, first + vis); i++) {
      const wd = ws[i], y = listY + (i - first) * rowH;
      const hit = ui.hit("world" + i, px + 16 * k, y, pw - 32 * k, rowH - 8 * k);
      if (hit.clicked) { if (this.selected === i || hit.doubleClicked) this.play(wd); this.selected = i; }
      const on = i === this.selected;
      gfx.color(on ? "#3B4A66" : "#262A33"); gfx.rect(px + 16 * k, y, pw - 32 * k, rowH - 8 * k, 6 * k);
      if (on) { gfx.color("#FFFFFF"); gfx.rectLine(px + 16 * k, y, pw - 32 * k, rowH - 8 * k, 6 * k, 2 * k); }
      gfx.icon(wd.mode === "creative" ? "auto_awesome" : "landscape", px + 50 * k, y + rowH / 2 - 4 * k, 30 * k, "#BFD4FF");
      shadowText(wd.name || "?", px + 80 * k, y + 10 * k, 19 * k, "#FFFFFF", "left", 0, "bold");
      const date = wd.lastPlayed ? sys.date(Math.floor(wd.lastPlayed / 1000)) : null;
      const info = `${TR(wd.mode === "creative" ? "ui.creative_mode" : "ui.survival_mode")} · ${TR(wd.type === "flat" ? "ui.type_flat" : "ui.type_normal")}` +
        (date ? ` · ${date.day}.${date.month}.${date.year} ${String(date.hour).padStart(2, "0")}:${String(date.min).padStart(2, "0")}` : "");
      gfx.color("#B8C0D0"); gfx.text(info, px + 80 * k, y + 36 * k, 14 * k, "sans");
    }
    const by = py + ph - 64 * k, bw = (pw - 64 * k) / 4, bh = 46 * k;
    const sel = ws[this.selected];
    if (m.button("playw", TR("ui.play_world"), px + 16 * k, by, bw, bh, k, { primary: true, enabled: !!sel })) this.play(sel);
    if (m.button("new", TR("ui.new_world"), px + 24 * k + bw, by, bw, bh, k)) {
      this.form = { name: TR("ui.default_world_name", ws.length + 1), seed: "", type: "normal", mode: "survival" };
      this.go("create");
    }
    if (m.button("del", TR("ui.delete"), px + 32 * k + bw * 2, by, bw, bh, k, { enabled: !!sel }) || (sel && input.pressed("x"))) this.confirmDelete(sel);
    if (m.button("back", TR("ui.back"), px + 40 * k + bw * 3, by, bw, bh, k) || m.back()) this.backTo();
  }

  confirmDelete(wd) {
    if (!wd) return;
    ui.alert(TR("ui.delete_title"), TR("ui.delete_msg", wd.name), [TR("ui.delete"), TR("ui.cancel")], (i) => {
      if (i === 0) { deleteWorld(wd.id); this.refresh(); }
    });
  }

  play(wd) {
    if (!wd) return;
    const meta = loadWorld(wd.id);
    if (!meta) { ui.alert(TR("ui.error"), TR("ui.world_broken"), [TR("ui.ok")]); return; }
    this.stopPanorama();
    this.app.startGame(meta);
  }

  create(w, h, k) {
    const m = this.menu, f = this.form;
    const pw = Math.min(w - 40 * k, 620 * k), ph = 470 * k, px = (w - pw) / 2, py = (h - ph) / 2;
    panel(px, py, pw, ph, k);
    shadowText(TR("ui.new_world"), 0, py + 16 * k, 26 * k, "#FFFFFF", "center", w);
    const bx = px + 30 * k, bw = pw - 60 * k, bh = 48 * k;
    let y = py + 70 * k;
    if (m.button("name", `${TR("ui.world_name")}: ${f.name}`, bx, y, bw, bh, k, { icon: "edit" }))
      ui.keyboard(f.name, (t) => { if (t) f.name = t.slice(0, 32); }, TR("ui.world_name"));
    y += bh + 12 * k;
    if (m.button("seed", `${TR("ui.seed")}: ${f.seed || TR("ui.random")}`, bx, y, bw, bh, k, { icon: "casino" }))
      ui.keyboard(f.seed, (t) => { if (t !== null && t !== undefined) f.seed = t.slice(0, 32); }, TR("ui.seed"));
    y += bh + 12 * k;
    f.type = m.option("type", TR("ui.world_type"), f.type, ["normal", "flat"], [TR("ui.type_normal"), TR("ui.type_flat")], bx, y, bw, bh, k);
    y += bh + 12 * k;
    f.mode = m.option("mode", TR("ui.game_mode"), f.mode, ["survival", "creative"], [TR("ui.survival_mode"), TR("ui.creative_mode")], bx, y, bw, bh, k);
    y += bh + 26 * k;
    if (m.button("create", TR("ui.create"), bx, y, bw / 2 - 8 * k, bh, k, { primary: true })) {
      const now = Date.now();
      const meta = { id: newWorldId(), name: f.name || TR("ui.default_world_name", 1), seed: seedFromString(f.seed), type: f.type, mode: f.mode, created: now, lastPlayed: now };
      this.stopPanorama();
      this.screen = "title"; this.stack = [];
      this.app.startGame(meta);
      return;
    }
    if (m.button("cancel", TR("ui.cancel"), bx + bw / 2 + 8 * k, y, bw / 2 - 8 * k, bh, k) || m.back()) this.backTo();
  }

  settings(w, h, k) {
    const m = this.menu, s = this.app.settings;
    const pw = Math.min(w - 40 * k, 860 * k), ph = Math.min(h - 40 * k, 600 * k), px = (w - pw) / 2, py = (h - ph) / 2;
    panel(px, py, pw, ph, k);
    shadowText(TR("ui.settings"), 0, py + 14 * k, 26 * k, "#FFFFFF", "center", w);
    const cw = (pw - 72 * k) / 2, bh = 44 * k, gap = 10 * k, c0 = px + 24 * k, c1 = c0 + cw + 24 * k;
    let y = py + 62 * k;
    const old = JSON.stringify(s);
    s.renderDistance = m.slider("rd", TR("set.render_distance"), s.renderDistance, 2, 12, 1, c0, y, cw, bh, k, v => TR("set.chunks", v));
    s.fov = m.slider("fov", TR("set.fov"), s.fov, 50, 110, 1, c1, y, cw, bh, k); y += bh + gap;
    s.sensitivity = m.slider("sens", TR("set.sensitivity"), s.sensitivity, 0.3, 3, 0.1, c0, y, cw, bh, k, v => v.toFixed(1));
    s.volume = m.slider("vol", TR("set.volume"), s.volume, 0, 1, 0.05, c1, y, cw, bh, k, v => Math.round(v * 100) + "%"); y += bh + gap;
    const onOff = v => [true, false].indexOf(v) < 0 ? false : v;
    s.music = m.option("music", TR("set.music"), onOff(s.music), [true, false], [TR("ui.on"), TR("ui.off")], c0, y, cw, bh, k);
    s.viewBobbing = m.option("bob", TR("set.view_bobbing"), onOff(s.viewBobbing), [true, false], [TR("ui.on"), TR("ui.off")], c1, y, cw, bh, k); y += bh + gap;
    s.waving = m.option("wave", TR("set.waving"), onOff(s.waving), [true, false], [TR("ui.on"), TR("ui.off")], c0, y, cw, bh, k);
    s.clouds = m.option("clouds", TR("set.clouds"), onOff(s.clouds), [true, false], [TR("ui.on"), TR("ui.off")], c1, y, cw, bh, k); y += bh + gap;
    s.invertY = m.option("inv", TR("set.invert_y"), onOff(s.invertY), [false, true], [TR("ui.off"), TR("ui.on")], c0, y, cw, bh, k);
    s.rumble = m.option("rumble", TR("set.rumble"), onOff(s.rumble), [true, false], [TR("ui.on"), TR("ui.off")], c1, y, cw, bh, k); y += bh + gap;
    s.showFps = m.option("fps", TR("set.show_fps"), onOff(s.showFps), [false, true], [TR("ui.off"), TR("ui.on")], c0, y, cw, bh, k);
    s.uiScale = m.option("scale", TR("set.ui_scale"), s.uiScale, [0, 0.85, 1, 1.2], [TR("set.auto"), TR("set.small"), TR("set.normal"), TR("set.large")], c1, y, cw, bh, k); y += bh + gap;
    if (JSON.stringify(s) !== old) this.app.saveSettings();
    if (m.button("done", TR("ui.done"), px + pw / 2 - 150 * k, py + ph - 62 * k, 300 * k, 46 * k, k, { primary: true }) || m.back()) {
      if (this.app.game) this.app.game.world.renderDistance = s.renderDistance;
      this.backTo();
    }
  }

  help(w, h, k) {
    const m = this.menu;
    const pw = Math.min(w - 40 * k, 900 * k), ph = Math.min(h - 40 * k, 620 * k), px = (w - pw) / 2, py = (h - ph) / 2;
    panel(px, py, pw, ph, k);
    shadowText(TR("ui.controls"), 0, py + 14 * k, 26 * k, "#FFFFFF", "center", w);
    const cols = [["help.pad_title", 10], ["help.kb_title", 8]];
    const cw = (pw - 72 * k) / 2;
    cols.forEach(([title, n], c) => {
      const x = px + 24 * k + c * (cw + 24 * k);
      shadowText(TR(title), x, py + 60 * k, 18 * k, "#FFE070", "left", 0, "bold");
      for (let i = 0; i < n; i++) {
        gfx.color("#E8ECF4");
        gfx.text(TR((c ? "help.kb" : "help.pad") + (i + 1)), x, py + 92 * k + i * 30 * k, 15 * k, "sans");
      }
    });
    gfx.color("#B8C0D0");
    gfx.wrap(TR("help.touch"), px + 24 * k, py + ph - 130 * k, pw - 48 * k, 14 * k, "sans");
    if (m.button("done", TR("ui.done"), px + pw / 2 - 150 * k, py + ph - 62 * k, 300 * k, 46 * k, k, { primary: true }) || m.back()) this.backTo();
  }

  pause(w, h, k) {
    const m = this.menu, g = this.app.game;
    gfx.color("#00000099"); gfx.rect(0, 0, w, h);
    shadowText(TR("ui.paused"), 0, h * 0.16, 34 * k, "#FFFFFF", "center", w);
    const bw = 380 * k, bh = 48 * k, bx = (w - bw) / 2;
    let y = h * 0.3;
    // (the key that opened the menu must not close it again in the same frame)
    if (m.button("resume", TR("ui.resume"), bx, y, bw, bh, k, { primary: true }) || ((input.pressed("plus") || m.back()) && this.t > 0.3)) { this.app.resume(); return; }
    y += bh + 12 * k;
    if (m.button("settings", TR("ui.settings"), bx, y, bw / 2 - 6 * k, bh, k)) this.go("settings");
    if (m.button("help", TR("ui.controls"), bx + bw / 2 + 6 * k, y, bw / 2 - 6 * k, bh, k)) this.go("help");
    y += bh + 12 * k;
    if (m.button("mode", `${TR("ui.game_mode")}: ${TR(g.mode === "creative" ? "ui.creative_mode" : "ui.survival_mode")}`, bx, y, bw, bh, k)) g.toggleMode();
    y += bh + 12 * k;
    if (g.mode === "creative") {
      if (m.button("time", `${TR("ui.time")}: ${TR("time." + g.dayPhase())}`, bx, y, bw, bh, k, { icon: "schedule" })) g.nextDayPhase();
      y += bh + 12 * k;
    }
    if (m.button("camera", TR("ui.camera") + ": " + TR("camera." + g.cameraMode), bx, y, bw, bh, k)) g.cycleCamera();
    y += bh + 12 * k;
    if (m.button("quit", TR("ui.save_quit"), bx, y, bw, bh, k, { icon: "save" })) this.app.quitToTitle();
  }

  dead(w, h, k) {
    const m = this.menu, g = this.app.game;
    gfx.gradient(0, 0, w, h, "#6A0000A0", "#200000D0");
    shadowText(TR("ui.you_died"), 0, h * 0.22, 48 * k, "#FFFFFF", "center", w);
    shadowText(g.deathMessage || "", 0, h * 0.22 + 64 * k, 18 * k, "#FFD0D0", "center", w, "semibold");
    const bw = 380 * k, bh = 48 * k, bx = (w - bw) / 2;
    if (m.button("respawn", TR("ui.respawn"), bx, h * 0.45, bw, bh, k, { primary: true })) { g.respawn(); this.app.resume(); }
    if (m.button("title", TR("ui.title_screen"), bx, h * 0.45 + bh + 12 * k, bw, bh, k)) this.app.quitToTitle();
  }

  loading(w, h, k) {
    const g = this.app.game;
    gfx.gradient(0, 0, w, h, "#1A2433", "#0B0F16");
    shadowText(TR("ui.loading"), 0, h * 0.4, 26 * k, "#FFFFFF", "center", w);
    const bw = 420 * k, bx = (w - bw) / 2, by = h * 0.4 + 50 * k;
    gfx.color("#2A3240"); gfx.rect(bx, by, bw, 14 * k, 7 * k);
    gfx.color("#4CB860"); gfx.rect(bx, by, Math.max(14 * k, bw * clamp(g ? g.loadProgress || 0 : 0, 0, 1)), 14 * k, 7 * k);
    gfx.color("#9AA4B8"); gfx.wrap(TR("tip." + (1 + (Math.floor(this.t / 6) % 9))), w * 0.2, by + 40 * k, w * 0.6, 15 * k, "sans", "center");
  }
}
