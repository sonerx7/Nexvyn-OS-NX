// kit.js: small helpers for this JavaScript game (the Lua games share kit.lua; this is its JS counterpart):
// colours, easing, sound with mute, input tracking, particles, modal dialogs with controller focus, control hints,
// focus rings and toasts. Only uses the documented SDK globals (gfx, ui, audio, sys, store, timer, theme, input).

export const state = { muted: false, lastInput: "pointer" };

export const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
export const lerp = (a, b, t) => a + (b - a) * t;
export const easeOut = (t) => { t = clamp(t, 0, 1); const u = 1 - t; return 1 - u * u * u; };
export const easeInOut = (t) => { t = clamp(t, 0, 1); return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; };
export const easeOutBack = (t) => { t = clamp(t, 0, 1); const u = t - 1; return 1 + 2.70158 * u * u * u + 1.70158 * u * u; };

const cache = new Map();
export function rgba(c) {
  if (Array.isArray(c)) return c;
  let t = cache.get(c);
  if (t) return t;
  let s = String(c || "#000000").replace("#", "");
  if (s.length === 3) s = s[0] + s[0] + s[1] + s[1] + s[2] + s[2];
  t = [parseInt(s.slice(0, 2), 16) || 0, parseInt(s.slice(2, 4), 16) || 0, parseInt(s.slice(4, 6), 16) || 0,
    s.length >= 8 ? parseInt(s.slice(6, 8), 16) : 255];
  cache.set(c, t);
  return t;
}
const byte = (v) => clamp(Math.round(v), 0, 255);
export function col(c, a = 1) {
  const t = rgba(c);
  return [t[0], t[1], t[2], byte(t[3] * a)];
}
export function mix(c1, c2, t, a = 1) {
  const x = rgba(c1), y = rgba(c2);
  t = clamp(t, 0, 1);
  return [byte(x[0] + (y[0] - x[0]) * t), byte(x[1] + (y[1] - x[1]) * t), byte(x[2] + (y[2] - x[2]) * t),
    byte((x[3] + (y[3] - x[3]) * t) * a)];
}

// ------------------------------------------------------------------ sound
export function loadPrefs() { state.muted = store.get("muted", false) === true; }
export function setMuted(v) { state.muted = !!v; store.set("muted", state.muted); }
export function tone(f, d = 0.1, v = 0.3, w = "sine") { if (!state.muted) audio.tone(f, d, v, w); }
export function play(name, v = 1) { if (!state.muted) audio.play(name, v); }
export function notes(list, step = 0.08, vol = 0.25, wave = "triangle") {
  list.forEach((f, i) => timer.after(i * step + 0.0001, () => tone(f, step * 1.6, vol, wave)));
}
export function chord(list, d = 0.3, vol = 0.3, wave = "triangle") {
  for (const f of list) tone(f, d, (vol / list.length) * 1.6, wave);
}
export function winSound() {
  notes([523, 659, 784, 1047], 0.08, 0.24);
  timer.after(0.34, () => chord([523, 659, 784, 1047], 0.6, 0.3));
}
export function rumble(s = 0.4, ms = 40) { sys.vibrate(s, ms); }

// ------------------------------------------------------------------ input
export function track(e) {
  if (e.type === "mousedown" || e.type === "scroll") state.lastInput = "pointer";
  else if (e.type === "keydown") state.lastInput = "key";
  else if (e.type === "paddown") state.lastInput = "pad";
}

// left stick as a direction with repeat; st is a persistent object
export function stickDir(st, dt) {
  const [x, y] = input.stick("left");
  let dir = null;
  const th = st.dir ? 0.35 : 0.6;
  if (Math.abs(x) > th || Math.abs(y) > th) {
    dir = Math.abs(x) > Math.abs(y) ? (x > 0 ? "right" : "left") : (y > 0 ? "up" : "down");
  }
  if (dir !== st.dir) {
    st.dir = dir;
    st.t = 0.3;
    if (dir) state.lastInput = "pad";
    return dir;
  }
  if (dir) {
    st.t -= dt;
    if (st.t <= 0) { st.t = 0.12; return dir; }
  }
  return null;
}

// ------------------------------------------------------------------ drawing helpers
export function ring(x, y, w, h, r = 8, c = theme.accent, th = 3, force = false) {
  if (state.lastInput === "pointer" && !force) return;
  const p = 0.5 + 0.5 * Math.sin(sys.time() * 6);
  gfx.color(col(c, 0.6 + 0.4 * p));
  gfx.rectLine(x, y, w, h, r, th);
}

export function card(x, y, w, h, r = 14) {
  gfx.shadow(x, y, w, h, r, 26, 10);
  gfx.rect(x, y, w, h, r, theme.window);
  gfx.color(theme.separator);
  gfx.rectLine(x, y, w, h, r, 1);
}

export function stat(x, y, w, h, label, value, accent) {
  gfx.rect(x, y, w, h, 10, accent ? col(accent, 0.16) : col(theme.text, theme.dark ? 0.09 : 0.06));
  gfx.color(accent || theme.text2);
  gfx.text(label, x, y + 5, 11, "semibold", "center", w);
  gfx.color(theme.text);
  gfx.text(String(value), x, y + h * 0.36, Math.min(22, h * 0.42), "bold", "center", w);
}

let toastMsg = null, toastT = 0, toastDur = 1.6;
export function toast(msg, dur = 1.6) { toastMsg = msg; toastT = sys.time(); toastDur = dur; }
export function drawToast(w, y) {
  if (!toastMsg) return;
  const el = sys.time() - toastT;
  if (el > toastDur) { toastMsg = null; return; }
  const a = clamp(Math.min(el / 0.15, (toastDur - el) / 0.3), 0, 1);
  const tw = gfx.textWidth(toastMsg, 14, "semibold") + 36;
  const x = (w - tw) / 2;
  gfx.alpha(a);
  gfx.shadow(x, y, tw, 34, 17, 14, 4);
  gfx.rect(x, y, tw, 34, 17, theme.window);
  gfx.color(theme.separator);
  gfx.rectLine(x, y, tw, 34, 17, 1);
  gfx.color(theme.text);
  gfx.text(toastMsg, x, y + 8, 14, "semibold", "center", tw);
  gfx.unalpha();
}

// control hints: items = [[glyph or [glyphs], label], ...]
function glyphW(g) {
  return ["A", "B", "X", "Y", "+", "-", "dpad", "touch"].includes(g) ? 18 : Math.max(20, gfx.textWidth(g, 11, "bold") + 10);
}
function glyph(g, x, cy, fg, bg) {
  if (["A", "B", "X", "Y", "+", "-"].includes(g)) {
    gfx.circle(x + 9, cy, 9, fg);
    gfx.color(bg);
    gfx.text(g, x, cy - 8, 12, "bold", "center", 18);
    return 18;
  }
  if (g === "dpad") {
    gfx.rect(x + 6, cy - 9, 6, 18, 1.5, fg);
    gfx.rect(x, cy - 3, 18, 6, 1.5, fg);
    return 18;
  }
  if (g === "touch") { gfx.icon("touch_app", x + 9, cy, 18, fg); return 18; }
  const tw = glyphW(g);
  gfx.rect(x, cy - 9, tw, 18, 5, fg);
  gfx.color(bg);
  gfx.text(g, x, cy - 7, 11, "bold", "center", tw);
  return tw;
}
export function hints(items, x, y, w) {
  const fg = col(theme.text, 0.62), bg = theme.bg;
  let gap = 16, total = 0;
  const widths = items.map(([g, label]) => {
    const gs = Array.isArray(g) ? g : [g];
    const gw = gs.reduce((s, q, i) => s + glyphW(q) + (i ? 3 : 0), 0);
    return gw + 6 + gfx.textWidth(label, 12, "medium");
  });
  total = widths.reduce((s, v) => s + v, 0) + gap * (items.length - 1);
  if (total > w && items.length > 1) {
    gap = Math.max(6, gap - (total - w) / (items.length - 1));
    total = widths.reduce((s, v) => s + v, 0) + gap * (items.length - 1);
  }
  let cx = x + (w - total) / 2;
  const cy = y + 9;
  items.forEach(([g, label], i) => {
    const gs = Array.isArray(g) ? g : [g];
    let px = cx;
    gs.forEach((q, j) => { if (j) px += 3; px += glyph(q, px, cy, fg, bg); });
    gfx.color(fg);
    gfx.text(label, px + 6, cy - 8, 12, "medium");
    cx += widths[i] + gap;
  });
}

// ------------------------------------------------------------------ dialogs
export function openDialog(st, sel = 0) { st.sel = sel; st.t0 = sys.time(); st.buttons = null; }

// opts: {title, subtitle, icon, iconColor, width, lines: [[label, value] | text], buttons: [[label, fn, style, icon]]}
export function dialog(st, w, h, opts) {
  const a = easeOut((sys.time() - (st.t0 || 0)) / 0.25);
  gfx.rect(0, 0, w, h, 0, [0, 0, 0, byte(115 * a)]);
  const bw = opts.width || 300, pad = 22;
  let ch = pad;
  if (opts.icon) ch += 56;
  if (opts.title) ch += 32;
  if (opts.subtitle) ch += gfx.measureWrap(opts.subtitle, bw - 2 * pad, 14) + 6;
  const lines = opts.lines || [];
  ch += lines.length * 22 + (lines.length ? 8 : 0);
  const buttons = opts.buttons || [];
  ch += buttons.length * 46 + 8;
  const x = Math.floor((w - bw) / 2), y = Math.floor((h - ch) / 2 + (1 - a) * 24);
  gfx.alpha(a);
  card(x, y, bw, ch, 16);
  let cy = y + pad;
  if (opts.icon) {
    const ic = opts.iconColor || theme.accent;
    gfx.circle(x + bw / 2, cy + 22, 25, col(ic, 0.16));
    gfx.icon(opts.icon, x + bw / 2, cy + 22, 30, ic);
    cy += 56;
  }
  if (opts.title) { gfx.color(theme.text); gfx.text(opts.title, x, cy, 22, "bold", "center", bw); cy += 32; }
  if (opts.subtitle) {
    gfx.color(theme.text2);
    cy += gfx.wrap(opts.subtitle, x + pad, cy, bw - 2 * pad, 14, "sans", "center") + 6;
  }
  for (const l of lines) {
    if (Array.isArray(l)) {
      gfx.color(theme.text2);
      gfx.text(l[0], x + pad + 8, cy + 2, 14);
      gfx.color(theme.text);
      gfx.text(String(l[1]), x, cy + 2, 14, "semibold", "right", bw - pad - 8);
    } else {
      gfx.color(theme.text2);
      gfx.text(l, x, cy + 2, 14, "sans", "center", bw);
    }
    cy += 22;
  }
  if (lines.length) cy += 8;
  cy += 4;
  st.sel = clamp(st.sel || 0, 0, Math.max(0, buttons.length - 1));
  buttons.forEach((b, i) => {
    const bx = x + pad, bww = bw - 2 * pad;
    if (st.sel === i) ring(bx - 3, cy - 3, bww + 6, 42, 10);
    if (ui.button(b[0] + "##dlg" + i, bx, cy, bww, 36, b[2] || (i === 0 ? "primary" : "default"), b[3])) {
      st.sel = i;
      if (a > 0.6) b[1]();
    }
    cy += 46;
  });
  gfx.unalpha();
  st.buttons = buttons;
}

// act: "up" | "down" | "ok"
export function dialogInput(st, act) {
  const bs = st.buttons;
  if (!bs || bs.length === 0) return;
  const n = bs.length;
  if (act === "up") { st.sel = (clamp(st.sel || 0, 0, n - 1) - 1 + n) % n; tone(880, 0.03, 0.12, "triangle"); }
  else if (act === "down") { st.sel = (clamp(st.sel || 0, 0, n - 1) + 1) % n; tone(880, 0.03, 0.12, "triangle"); }
  else if (act === "ok") {
    if (sys.time() - (st.t0 || 0) < 0.15) return;
    const b = bs[clamp(st.sel || 0, 0, n - 1)];
    if (b) { tone(660, 0.05, 0.2, "triangle"); b[1](); }
  }
}

// ------------------------------------------------------------------ particles
export class Particles {
  constructor() { this.list = []; }
  emit(x, y, vx, vy, life, size, color, grav = 0, drag = 0) {
    if (this.list.length > 600) return;
    this.list.push({ x, y, vx, vy, life, max: life, size, c: rgba(color), g: grav, drag });
  }
  burst(x, y, n, color, speed, life, size, grav = 0, drag = 0) {
    for (let i = 0; i < n; i++) {
      const ang = Math.random() * Math.PI * 2, s = speed * (0.25 + Math.random() * 0.75);
      this.emit(x, y, Math.cos(ang) * s, Math.sin(ang) * s, life * (0.6 + Math.random() * 0.4),
        size * (0.6 + Math.random() * 0.6), color, grav, drag);
    }
  }
  update(dt) {
    let j = 0;
    for (const p of this.list) {
      p.life -= dt;
      if (p.life <= 0) continue;
      p.vy += p.g * dt;
      if (p.drag > 0) { const f = Math.exp(-p.drag * dt); p.vx *= f; p.vy *= f; }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      this.list[j++] = p;
    }
    this.list.length = j;
  }
  draw() {
    for (const p of this.list) {
      const k = p.life / p.max;
      gfx.circle(p.x, p.y, Math.max(0.6, p.size * (0.35 + 0.65 * k)), [p.c[0], p.c[1], p.c[2], byte(p.c[3] * Math.min(1, k * 1.4))]);
    }
  }
}

export function celebrate(fx, x, y, w, h) {
  const cs = [theme.red, theme.orange, theme.yellow, theme.green, theme.blue, theme.purple, theme.pink];
  for (const c of cs) fx.burst(x + w * (0.15 + 0.7 * Math.random()), y + h * (0.2 + 0.5 * Math.random()), 14, c, Math.max(w, h) * 0.9, 1.1, 4, 500, 1.5);
}
