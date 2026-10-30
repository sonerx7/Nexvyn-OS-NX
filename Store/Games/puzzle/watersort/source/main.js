// Su Sıralama / Water Sort for Nexvyn OS, written in JavaScript to show off the JS runtime (SDK section 11):
// ES modules (kit.js helpers, level.js rules + generator + solver), generator functions that spread the solver over
// frames, classes, destructuring and the 0-based widget indexes. Pour coloured layers until every tube holds one colour.
import * as K from "./kit.js";
import { CAP, canPour, pour, isComplete, solved, topRun, generate, solve, colorsFor } from "./level.js";

const COLORS = ["#E53935", "#1E88E5", "#FDD835", "#43A047", "#8E24AA", "#FB8C00", "#00ACC1", "#EC407A",
  "#6D4C41", "#7CB342", "#3949AB", "#90A4AE"];
const POUR = { lift: 0.12, move: 0.2, pour: 0.28, back: 0.18 };
const POUR_TOTAL = POUR.lift + POUR.move + POUR.pour + POUR.back;
const SUB = new Set(["stats", "reset", "help", "confirm"]);

let scene = "title";
let returnTo = null;
const dlg = {};
let level = 1, maxLevel = 1;
let tubes = [], startTubes = [];
let history = [];
let moves = 0;
let sel = -1, cursor = 0;
let anim = null;              // {a, b, n, color, t0}
let genIt = null;             // level generator in progress
let hintIt = null, hintMove = null, hintT = -10;
let extraUsed = false;
let completedAt = [];         // per tube: time it was completed (sparkle)
let wonAt = 0, isWon = false;
let stats = { solved: 0, moves: 0, hints: 0, undos: 0 };
let best = {};
const fx = new K.Particles();
const stick = {};
let layout = [];              // [{x, y, w, h}]
let titleSel = 0;
let newRecord = false;

// ------------------------------------------------------------------ scenes
function open(s, sel = 0) {
  if (SUB.has(s)) { if (scene === "title" || scene === "pause") returnTo = scene; }
  else returnTo = null;
  scene = s;
  K.openDialog(dlg, sel);
}
function close() {
  const r = returnTo;
  returnTo = null;
  if (r) { scene = r; K.openDialog(dlg); } else scene = "play";
}
const modal = () => scene !== "play";

// ------------------------------------------------------------------ persistence
function saveAll() {
  store.set("progress", { level, maxLevel, tubes, start: startTubes, history, moves, extra: extraUsed, won: isWon });
  store.set("stats", stats);
  store.set("best", best);
}

function clone(t) { return t.map((x) => x.slice()); }

function startLevel(n) {
  level = Math.max(1, n);
  genIt = generate(level);
  tubes = [];
  hintIt = null;
  hintMove = null;
  anim = null;
  sel = -1;
  scene = "play";
  returnTo = null;
}

function finishGenerate(t) {
  startTubes = clone(t);
  tubes = clone(t);
  history = [];
  moves = 0;
  extraUsed = false;
  isWon = false;
  newRecord = false;
  completedAt = tubes.map(() => -10);
  cursor = 0;
  K.notes([392, 494, 587], 0.06, 0.14);
  saveAll();
}

function restart() {
  if (!startTubes.length) return;
  tubes = clone(startTubes);
  history = [];
  moves = 0;
  extraUsed = false;
  isWon = false;
  sel = -1;
  anim = null;
  hintMove = null;
  completedAt = tubes.map(() => -10);
  K.play("pop", 0.5);
  saveAll();
}

// ------------------------------------------------------------------ actions
function onWin() {
  isWon = true;
  wonAt = sys.time();
  stats.solved++;
  const k = String(level);
  newRecord = !best[k] || moves < best[k];
  if (newRecord) best[k] = moves;
  maxLevel = Math.max(maxLevel, level + 1);
  saveAll();
  K.winSound();
  K.rumble(0.5, 90);
  const l0 = layout[0], l1 = layout[layout.length - 1];
  if (l0 && l1) K.celebrate(fx, l0.x, l0.y, l1.x + l1.w - l0.x, l1.y + l1.h - l0.y);
  timer.after(1.3, () => { if (isWon && scene === "play") open("won"); });
}

function tryPour(a, b) {
  if (!canPour(tubes, a, b) || isComplete(tubes[a])) {
    K.tone(150, 0.06, 0.15, "square");
    K.rumble(0.15, 20);
    return false;
  }
  const color = tubes[a][tubes[a].length - 1];
  const n = pour(tubes, a, b);
  history.push([a, b, n]);
  moves++;
  stats.moves++;
  hintMove = null;
  anim = { a, b, n, color, t0: sys.time() };
  K.tone(500, 0.05, 0.15, "triangle");
  // gurgle while pouring
  for (let k = 0; k < n; k++) {
    timer.after(POUR.lift + POUR.move + k * 0.07, () => K.tone(300 + tubes[b].length * 90 + k * 40, 0.06, 0.12, "sine"));
  }
  if (isComplete(tubes[b])) {
    timer.after(POUR_TOTAL - POUR.back, () => {
      completedAt[b] = sys.time();
      K.chord([659, 830, 988], 0.3, 0.25);
      const L = layout[b];
      if (L) fx.burst(L.x + L.w / 2, L.y + 8, 22, COLORS[color], L.w * 3, 0.7, 3, 200, 2);
    });
  }
  if (solved(tubes)) timer.after(POUR_TOTAL, onWin);
  saveAll();
  return true;
}

function choose(i) {
  if (modal() || isWon || !tubes.length) return;
  if (anim && sys.time() - anim.t0 < POUR_TOTAL) return;
  cursor = i;
  if (sel < 0) {
    if (tubes[i].length === 0 || isComplete(tubes[i])) { K.tone(180, 0.04, 0.1, "square"); return; }
    sel = i;
    K.tone(760, 0.04, 0.15, "triangle");
  } else if (sel === i) {
    sel = -1;
    K.tone(560, 0.04, 0.12, "triangle");
  } else {
    if (tryPour(sel, i)) sel = -1;
    else if (tubes[i].length && !isComplete(tubes[i])) sel = i;
  }
}

function undo() {
  if (modal() || isWon) return;
  if (sel >= 0) { sel = -1; return; }
  const h = history.pop();
  if (!h) { K.tone(160, 0.05, 0.12, "square"); return; }
  const [a, b, n] = h;
  for (let k = 0; k < n; k++) tubes[a].push(tubes[b].pop());
  moves = Math.max(0, moves - 1);
  stats.undos++;
  anim = null;
  hintMove = null;
  K.tone(600, 0.05, 0.16, "triangle");
  saveAll();
}

function addTube() {
  if (modal() || isWon || !tubes.length) return;
  if (extraUsed) { K.toast(TR("extra_used")); return; }
  extraUsed = true;
  tubes.push([]);
  completedAt.push(-10);
  K.chord([523, 784], 0.2, 0.2, "sine");
  saveAll();
}

function hint() {
  if (modal() || isWon || !tubes.length || hintIt) return;
  hintIt = solve(tubes, 60000);
  stats.hints++;
}

// ------------------------------------------------------------------ app
app.load = () => {
  K.loadPrefs();
  const s = store.get("stats", null);
  if (s && typeof s === "object") for (const k of Object.keys(stats)) stats[k] = Number(s[k]) || 0;
  const b = store.get("best", null);
  best = b && typeof b === "object" ? b : {};
  const p = store.get("progress", null);
  const valid = (t) => Array.isArray(t) && t.length >= 4 && t.every((x) => Array.isArray(x) && x.length <= CAP &&
    x.every((c) => Number.isInteger(c) && c >= 0 && c < COLORS.length));
  if (p && valid(p.tubes) && valid(p.start) && !p.won) {
    level = Math.max(1, Number(p.level) || 1);
    maxLevel = Math.max(level, Number(p.maxLevel) || 1);
    tubes = clone(p.tubes);
    startTubes = clone(p.start);
    history = Array.isArray(p.history) ? p.history.filter((h) => Array.isArray(h) && h.length === 3) : [];
    moves = Number(p.moves) || 0;
    extraUsed = p.extra === true;
    completedAt = tubes.map(() => -10);
  } else {
    maxLevel = p ? Math.max(1, Number(p.maxLevel) || 1) : 1;
    startLevel(p && p.won ? maxLevel : maxLevel);
  }
  scene = "title";
  K.openDialog(dlg);
};

function stepIterator(it, budgetMs) {
  const end = Date.now() + budgetMs;
  let r;
  do { r = it.next(); } while (!r.done && Date.now() < end);
  return r;
}

app.update = (dt) => {
  fx.update(dt);
  if (genIt) {
    const r = stepIterator(genIt, 10);
    if (r.done) { genIt = null; finishGenerate(r.value); }
  }
  if (hintIt) {
    const r = stepIterator(hintIt, 8);
    if (r.done) {
      hintIt = null;
      const path = r.value;
      if (path && path.length) {
        hintMove = path[0];
        hintT = sys.time();
        cursor = hintMove[0];
        K.chord([660, 880, 1100], 0.2, 0.2, "sine");
      } else {
        K.toast(TR("stuck"), 2.4);
        K.tone(200, 0.15, 0.15, "square");
      }
    }
  }
  const d = K.stickDir(stick, dt);
  if (d) {
    if (modal()) K.dialogInput(dlg, d === "up" || d === "left" ? "up" : "down");
    else moveCursor(d);
  }
};

// ------------------------------------------------------------------ layout & drawing
function computeLayout(w, top, bottom) {
  const n = tubes.length;
  const avail = w - 32;
  let perRow = n;
  let tw = Math.min(64, (avail - (n - 1) * 14) / n);
  if (tw < 42 && n > 4) { perRow = Math.ceil(n / 2); tw = Math.min(64, (avail - (perRow - 1) * 14) / perRow); }
  const rows = Math.ceil(n / perRow);
  const rowH = (bottom - top) / rows;
  const th = Math.min(tw * 3.6, rowH - 70);
  layout = [];
  for (let i = 0; i < n; i++) {
    const r = Math.floor(i / perRow), c = i % perRow;
    const inRow = r === rows - 1 ? n - perRow * (rows - 1) : perRow;
    const rowW = inRow * tw + (inRow - 1) * 14;
    const x = (w - rowW) / 2 + c * (tw + 14);
    const y = top + r * rowH + (rowH - th) / 2 + 20;
    layout.push({ x, y, w: tw, h: th, perRow });
  }
}

// segments: [[colorIndex, amount], ...] bottom to top (amount may be fractional)
function segmentsOf(t, dropTop = 0) {
  const segs = [];
  for (let i = 0; i < t.length - dropTop; i++) {
    const c = t[i];
    if (segs.length && segs[segs.length - 1][0] === c) segs[segs.length - 1][1]++;
    else segs.push([c, 1]);
  }
  return segs;
}

function drawTube(x, y, w, h, segs, highlight, done, now, i) {
  const pad = 4;
  const layerH = (h - w * 0.25 - pad) / CAP;
  // glass
  gfx.rect(x, y, w, h, w * 0.45, K.col(theme.text, theme.dark ? 0.08 : 0.05));
  let level0 = y + h - pad;
  for (let s = 0; s < segs.length; s++) {
    const [c, amt] = segs[s];
    if (amt <= 0.001) continue;
    const hh = amt * layerH;
    const top = level0 - hh;
    const col = COLORS[c];
    if (s === 0) {
      // rounded bottom
      gfx.rect(x + pad, top, w - 2 * pad, hh, (w - 2 * pad) * 0.45, col);
      gfx.rect(x + pad, top, w - 2 * pad, Math.min(hh, hh - (w - 2 * pad) * 0.45 + 1), 0, col);
    } else {
      gfx.rect(x + pad, top, w - 2 * pad, hh + 0.5, 0, col);
    }
    gfx.rect(x + pad + 3, top + 2, 4, Math.max(0, hh - 4), 2, K.col("#FFFFFF", 0.22));
    level0 = top;
  }
  // surface shine
  if (segs.length) gfx.rect(x + pad, level0, w - 2 * pad, 3, 1.5, K.col("#FFFFFF", 0.35));
  gfx.color(highlight ? theme.accent : K.col(theme.text, 0.45));
  gfx.rectLine(x, y, w, h, w * 0.45, highlight ? 3 : 2);
  gfx.rect(x - 3, y - 2, w + 6, 6, 3, highlight ? theme.accent : K.col(theme.text, 0.45));
  if (done) {
    const k = now - (completedAt[i] || -10);
    if (k > 0 && k < 1) {
      gfx.color(K.col("#FFFFFF", 1 - k));
      gfx.rectLine(x - k * 8, y - k * 8, w + k * 16, h + k * 16, w * 0.5, 2);
    }
    gfx.icon("check_circle", x + w / 2, y - 16, 18, theme.green);
  }
}

function drawTubes(now) {
  const animP = anim ? (now - anim.t0) : 99;
  for (let i = 0; i < tubes.length; i++) {
    const L = layout[i];
    let x = L.x, y = L.y;
    let segs;
    const isSrc = anim && animP < POUR_TOTAL && anim.a === i;
    const isDst = anim && animP < POUR_TOTAL && anim.b === i;
    let pourP = 0;
    if (anim && animP < POUR_TOTAL) pourP = K.clamp((animP - POUR.lift - POUR.move) / POUR.pour, 0, 1);
    if (isDst) {
      segs = segmentsOf(tubes[i], anim.n);
      if (pourP > 0) segs.push([anim.color, anim.n * pourP]);
    } else {
      segs = segmentsOf(tubes[i]);
    }
    if (isSrc) {
      if (pourP < 1) segs.push([anim.color, anim.n * (1 - pourP)]);
      const T = layout[anim.b];
      const tx = T.x + (T.x > L.x ? -L.w * 0.6 : L.w * 0.6), ty = T.y - L.h * 0.55;
      if (animP < POUR.lift) {
        y -= 26 * K.easeOut(animP / POUR.lift);
      } else if (animP < POUR.lift + POUR.move) {
        const p = K.easeInOut((animP - POUR.lift) / POUR.move);
        x = K.lerp(L.x, tx, p);
        y = K.lerp(L.y - 26, ty, p);
      } else if (animP < POUR.lift + POUR.move + POUR.pour) {
        x = tx; y = ty;
      } else {
        const p = K.easeInOut((animP - POUR.lift - POUR.move - POUR.pour) / POUR.back);
        x = K.lerp(tx, L.x, p);
        y = K.lerp(ty, L.y, p);
      }
      // stream
      if (pourP > 0 && pourP < 1) {
        const sx = x + (T.x > L.x ? L.w - 4 : 4), sy = y + 4;
        gfx.color(COLORS[anim.color]);
        gfx.line(sx, sy, T.x + T.w / 2, T.y + T.h * 0.3, 5);
      }
      continue; // drawn last, above the others
    }
    const lift = sel === i ? -18 : 0;
    drawTube(x, y + lift, L.w, L.h, segs, sel === i, isComplete(tubes[i]), now, i);
    if (hintMove && now - hintT < 3) {
      const pulse = 0.5 + 0.5 * Math.sin(now * 8);
      if (hintMove[0] === i || hintMove[1] === i) {
        gfx.color(K.col(theme.yellow, 0.6 + 0.4 * pulse));
        gfx.rectLine(x - 6, y - 8, L.w + 12, L.h + 14, L.w * 0.5, 3);
        gfx.icon(hintMove[0] === i ? "arrow_upward" : "arrow_downward", x + L.w / 2, y + L.h + 18, 18, theme.yellow);
      }
    }
    if (cursor === i && !modal()) K.ring(x - 7, y + lift - 10, L.w + 14, L.h + 18, L.w * 0.5);
  }
  if (anim && animP < POUR_TOTAL) {
    const i = anim.a, L = layout[i];
    // recompute the moving tube's position (same as above) for the final draw
    const T = layout[anim.b];
    const tx = T.x + (T.x > L.x ? -L.w * 0.6 : L.w * 0.6), ty = T.y - L.h * 0.55;
    let x = L.x, y = L.y;
    if (animP < POUR.lift) y -= 26 * K.easeOut(animP / POUR.lift);
    else if (animP < POUR.lift + POUR.move) { const p = K.easeInOut((animP - POUR.lift) / POUR.move); x = K.lerp(L.x, tx, p); y = K.lerp(L.y - 26, ty, p); }
    else if (animP < POUR.lift + POUR.move + POUR.pour) { x = tx; y = ty; }
    else { const p = K.easeInOut((animP - POUR.lift - POUR.move - POUR.pour) / POUR.back); x = K.lerp(tx, L.x, p); y = K.lerp(ty, L.y, p); }
    const pourP = K.clamp((animP - POUR.lift - POUR.move) / POUR.pour, 0, 1);
    const segs = segmentsOf(tubes[i]);
    if (pourP < 1) segs.push([anim.color, anim.n * (1 - pourP)]);
    drawTube(x, y, L.w, L.h, segs, true, false, now, i);
  }
}

function drawHints(w, y) {
  if (K.state.lastInput === "pad") {
    K.hints([["dpad", TR("h_move")], ["A", TR("h_pour")], ["B", TR("h_undo")], ["Y", TR("h_hint")], ["X", TR("restart")],
      ["-", TR("h_extra")], ["+", TR("h_pause")]], 0, y, w);
  } else if (K.state.lastInput === "key") {
    K.hints([[TR("k_arrows"), TR("h_move")], ["Enter", TR("h_pour")], ["1-9", TR("h_tube")], ["Z", TR("h_undo")],
      ["H", TR("h_hint")], ["R", TR("restart")], ["Esc", TR("h_pause")]], 0, y, w);
  } else {
    K.hints([["touch", TR("h_tap")]], 0, y, w);
  }
}

function statLines() {
  let bestCount = 0;
  for (const k of Object.keys(best)) if (best[k]) bestCount++;
  return [[TR("levels_solved"), String(stats.solved)], [TR("highest_level"), String(maxLevel)],
    [TR("total_moves"), String(stats.moves)], [TR("hints_used"), String(stats.hints)], [TR("undos"), String(stats.undos)]];
}

function drawDialogs(w, h) {
  if (scene === "pause") {
    K.dialog(dlg, w, h, { icon: "pause_circle", title: TR("paused"), buttons: [
      [TR("resume"), close, "primary", "play_arrow"],
      [TR("restart"), () => { close(); restart(); }, "default", "replay"],
      [TR("stats_title"), () => open("stats"), "default", "bar_chart"],
      [TR("main_menu"), () => open("title"), "default", "home"]] });
  } else if (scene === "won") {
    const b = best[String(level)];
    K.dialog(dlg, w, h, { icon: "emoji_events", iconColor: theme.yellow, title: TR("level_done", level),
      subtitle: newRecord ? TR("new_record") : undefined,
      lines: [[TR("moves"), String(moves)], [TR("best"), String(b || moves)]],
      buttons: [[TR("next_level"), () => startLevel(level + 1), "primary", "arrow_forward"],
        [TR("restart"), () => { scene = "play"; restart(); }, "default", "replay"]] });
  } else if (scene === "stats") {
    K.dialog(dlg, w, h, { icon: "bar_chart", title: TR("stats_title"), width: 320, lines: statLines(),
      buttons: [[TR("close"), close], [TR("reset_stats"), () => open("reset", 1), "destructive"]] });
  } else if (scene === "reset") {
    K.dialog(dlg, w, h, { icon: "delete", iconColor: theme.red, title: TR("reset_stats"), subtitle: TR("reset_sub"),
      buttons: [[TR("reset"), () => { stats = { solved: 0, moves: 0, hints: 0, undos: 0 }; best = {}; saveAll(); close(); }, "destructive"],
        [TR("cancel"), close]] });
  } else if (scene === "help") {
    K.dialog(dlg, w, h, { icon: "help", title: TR("how_to"), subtitle: TR("help_text"), width: 380,
      buttons: [[TR("close"), close]] });
  }
}

let floaters = null;
function drawTitle(w, h, now) {
  if (!floaters) floaters = Array.from({ length: 16 }, (_, i) => ({ x: Math.random(), y: Math.random(), s: 0.6 + Math.random(), v: 0.02 + Math.random() * 0.03, c: COLORS[i % COLORS.length] }));
  gfx.gradient(0, 0, w, h, K.mix(theme.bg, "#67E8F9", theme.dark ? 0.15 : 0.12), K.mix(theme.bg, "#0E7490", theme.dark ? 0.25 : 0.14));
  for (const f of floaters) {
    const y = (((f.y - now * f.v) % 1.2) + 1.2) % 1.2 * h - 0.1 * h;
    gfx.icon("water_drop", f.x * w + Math.sin(now * 0.7 + f.x * 9) * 14, y, 18 * f.s + 10, K.col(f.c, 0.22));
  }
  const t = now - (dlg.t0 || 0);
  const buttons = [
    [tubes.length && moves > 0 ? TR("continue") : TR("play"), () => { scene = "play"; returnTo = null; }, "primary", "play_arrow"],
    [TR("level_select_next", maxLevel), () => startLevel(maxLevel), "default", "skip_next"],
    [TR("how_to"), () => open("help"), "default", "help"],
    [TR("stats_title"), () => open("stats"), "default", "bar_chart"]];
  const bw = Math.min(300, w - 48);
  let y = Math.max(16, Math.floor((h - (198 + buttons.length * 50)) / 2) - 10);
  const a = K.easeOutBack(t / 0.5), s = 96 * a, bob = Math.sin(now * 2) * 4;
  if (s > 4) {
    gfx.shadow(w / 2 - s / 2, y + 48 - s / 2 + bob, s, s, s * 0.24, 20, 6);
    gfx.gradient(w / 2 - s / 2, y + 48 - s / 2 + bob, s, s, "#67E8F9", "#0E7490", false, s * 0.24);
    gfx.icon("science", w / 2, y + 48 + bob, s * 0.56, "#FFFFFF");
  }
  y += 110;
  const ta = K.easeOut((t - 0.15) / 0.4);
  gfx.alpha(ta);
  gfx.color(theme.text);
  gfx.text(TR("title"), 0, y + (1 - ta) * 12, 34, "bold", "center", w);
  gfx.color(theme.text2);
  gfx.text(TR("tagline"), 0, y + 46, 14, "medium", "center", w);
  gfx.unalpha();
  y += 80;
  const active = scene === "title";
  if (active) { dlg.buttons = buttons; dlg.sel = K.clamp(dlg.sel || 0, 0, buttons.length - 1); }
  buttons.forEach((b, i) => {
    const ba = K.easeOut((t - 0.25 - i * 0.07) / 0.35);
    const bx = Math.floor((w - bw) / 2 + (1 - ba) * 40);
    gfx.alpha(ba);
    if (active && dlg.sel === i) K.ring(bx - 3, y - 3, bw + 6, 46, 12);
    if (ui.button(b[0] + "##title" + i, bx, y, bw, 40, b[2], b[3]) && active && ba > 0.5) {
      dlg.sel = i;
      K.tone(660, 0.05, 0.2, "triangle");
      b[1]();
    }
    gfx.unalpha();
    y += 50;
  });
  gfx.color(theme.text3);
  gfx.text(TR("title_footer", stats.solved, maxLevel), 0, h - 54, 12, "medium", "center", w);
}

app.draw = (w, h) => {
  const now = sys.time();
  gfx.clear(theme.bg);
  if (scene === "title" || (scene !== "play" && returnTo === "title")) {
    drawTitle(w, h, now);
    if (scene !== "title") drawDialogs(w, h);
    return;
  }
  gfx.color(theme.text);
  gfx.text(TR("level_n", level), 16, 10, 26, "bold");
  gfx.color(theme.text2);
  gfx.text(TR("sub_line", colorsFor(level), moves), 17, 43, 12, "medium");
  // toolbar (right aligned)
  const items = [["pause", "pause"], [K.state.muted ? "volume_off" : "volume_up", "sound"], ["add_circle_outline", "extra"],
    ["replay", "restart"], ["lightbulb", "hint"], ["undo", "undo"]];
  let x = w - 16;
  let hit = null;
  for (const [icon, id] of items) {
    x -= 40;
    const tint = id === "extra" && extraUsed ? theme.text3 : theme.text;
    if (ui.iconButton(icon, x, 14, 40, 34, tint, false, "tb" + id) && !modal()) hit = id;
    x -= 6;
  }
  if (hit === "pause") open("pause");
  else if (hit === "sound") K.setMuted(!K.state.muted);
  else if (hit === "extra") addTube();
  else if (hit === "restart") restart();
  else if (hit === "hint") hint();
  else if (hit === "undo") undo();
  if (genIt || !tubes.length) {
    ui.spinner(w / 2, h / 2 - 10, 14);
    gfx.color(theme.text2);
    gfx.text(TR("generating"), 0, h / 2 + 16, 14, "medium", "center", w);
  } else {
    computeLayout(w, 70, h - 40);
    drawTubes(now);
    if (hintIt) ui.spinner(w - 30, 64, 8);
  }
  fx.draw();
  drawHints(w, h - 28);
  drawDialogs(w, h);
  K.drawToast(w, h - 84);
};

// ------------------------------------------------------------------ input
function moveCursor(d) {
  if (!layout.length) return;
  const per = layout[0].perRow || layout.length;
  const n = tubes.length;
  if (d === "left") cursor = (cursor - 1 + n) % n;
  else if (d === "right") cursor = (cursor + 1) % n;
  else if (d === "up" && cursor - per >= 0) cursor -= per;
  else if (d === "down" && cursor + per < n) cursor += per;
  K.tone(1100, 0.015, 0.06, "sine");
}

function dialogEvent(e) {
  const pad = e.type === "paddown";
  const k = pad ? e.pad : (e.type === "keydown" ? e.key : null);
  if (!k) return;
  if (k === "up" || k === "left") K.dialogInput(dlg, "up");
  else if (k === "down" || k === "right" || k === "tab") K.dialogInput(dlg, "down");
  else if ((pad && k === "a") || (!pad && (k === "enter" || k === "space"))) K.dialogInput(dlg, "ok");
  else if ((pad && k === "b") || (!pad && k === "escape")) { if (scene !== "title" && scene !== "won") close(); }
}

function tubeAt(x, y) {
  for (let i = 0; i < layout.length; i++) {
    const L = layout[i];
    if (x >= L.x - 7 && x <= L.x + L.w + 7 && y >= L.y - 30 && y <= L.y + L.h + 10) return i;
  }
  return -1;
}

let pressTube = -1;
app.event = (e) => {
  K.track(e);
  if (modal()) { dialogEvent(e); return; }
  if (e.type === "paddown") {
    const p = e.pad;
    if (isWon) { if (p === "a") open("won"); return; }
    if (p === "left" || p === "right" || p === "up" || p === "down") moveCursor(p);
    else if (p === "a") choose(cursor);
    else if (p === "b") undo();
    else if (p === "y") hint();
    else if (p === "x") restart();
    else if (p === "minus") addTube();
    else if (p === "plus") open("pause");
  } else if (e.type === "keydown") {
    const k = e.key;
    if (isWon) { if (k === "enter" || k === "space") open("won"); return; }
    const n = Number(k);
    if (k === "left" || k === "right" || k === "up" || k === "down") moveCursor(k);
    else if (k === "enter" || k === "space") choose(cursor);
    else if (k.length === 1 && n >= 0 && n <= 9) { const i = n === 0 ? 9 : n - 1; if (i < tubes.length) choose(i); }
    else if (k === "z" || k === "backspace") undo();
    else if (k === "h") hint();
    else if (k === "r") restart();
    else if (k === "t") addTube();
    else if (k === "escape" || k === "p") open("pause");
  } else if (e.type === "mousedown") {
    pressTube = tubeAt(e.x, e.y);
  } else if (e.type === "mouseup") {
    const i = tubeAt(e.x, e.y);
    if (i >= 0 && i === pressTube && !e.cancel) choose(i);
    else if (i < 0 && pressTube < 0 && sel >= 0) sel = -1;
    pressTube = -1;
  }
};

app.menu = () => [{ title: TR("menu_game"), items: [
  { label: TR("restart"), id: 1, shortcut: "R" },
  { label: TR("undo"), id: 2, shortcut: "Z", enabled: history.length > 0 },
  { label: TR("hint"), id: 3, shortcut: "H" },
  { label: TR("extra_tube"), id: 4, shortcut: "T", enabled: !extraUsed },
  "-",
  { label: TR("sound"), id: 5, checked: !K.state.muted },
  { label: TR("stats_title"), id: 6 },
] }];

app.onmenu = (id) => {
  if (id === 1) restart();
  else if (id === 2) undo();
  else if (id === 3) hint();
  else if (id === 4) addTube();
  else if (id === 5) K.setMuted(!K.state.muted);
  else if (id === 6) open("stats");
};

app.close = () => { saveAll(); return true; };
