// kit.js: small helpers shared by this app's screens: colours, text-field focus, toasts, undo history, a scroller
// that can jump, modal sheets and a few widgets that follow the system theme.
export const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
export const approach = (cur, target, speed, dt) => cur + (target - cur) * (1 - Math.exp(-speed * dt));

const ccache = new Map();
export function rgba(c) {
  if (Array.isArray(c)) return c;
  c = String(c || "#000000");
  let t = ccache.get(c);
  if (!t) {
    t = [parseInt(c.slice(1, 3), 16) || 0, parseInt(c.slice(3, 5), 16) || 0, parseInt(c.slice(5, 7), 16) || 0,
      c.length >= 9 ? parseInt(c.slice(7, 9), 16) : 255];
    ccache.set(c, t);
  }
  return t;
}
export function alpha(c, a) {
  const t = rgba(c);
  return [t[0], t[1], t[2], clamp(Math.round((t[3] ?? 255) * a), 0, 255)];
}
export function mix(c1, c2, k) {
  const a = rgba(c1), b = rgba(c2);
  return [0, 1, 2, 3].map((i) => Math.round((a[i] ?? 255) + ((b[i] ?? 255) - (a[i] ?? 255)) * k));
}
export function onColor(c) {
  const t = rgba(c);
  return t[0] * 0.299 + t[1] * 0.587 + t[2] * 0.114 > 165 ? "#1C1C1E" : "#FFFFFF";
}
export function ellipsize(s, size, font, maxW) {
  s = String(s ?? "");
  if (maxW <= 8) return "";
  if (gfx.textWidth(s, size, font) <= maxW) return s;
  const chars = Array.from(s);
  let lo = 0, hi = chars.length;
  while (lo < hi) {
    const mid = Math.floor((lo + hi + 1) / 2);
    if (gfx.textWidth(chars.slice(0, mid).join("") + "…", size, font) <= maxW) lo = mid; else hi = mid - 1;
  }
  return chars.slice(0, lo).join("") + "…";
}
export const lower = (s) => String(s ?? "").toLowerCase();
export const copy = (v) => (v === undefined ? undefined : JSON.parse(JSON.stringify(v)));
export function dayKey(epoch) {
  const d = sys.date(epoch);
  return `${d.year}-${String(d.month).padStart(2, "0")}-${String(d.day).padStart(2, "0")}`;
}
export function baseName(p) {
  p = String(p || "").replace(/\\/g, "/");
  return (p.split("/").pop() || p).replace(/\.[^.]+$/, "");
}
const PAL = ["blue", "green", "orange", "purple", "pink", "red", "yellow"];
export function colorFor(name) {
  let h = 7;
  for (const ch of String(name ?? "")) h = (h * 31 + ch.codePointAt(0)) % 1000003;
  return theme[PAL[h % PAL.length]] || theme.accent;
}

// ------------------------------------------------------------------ text-field focus
// K.editing is false or the id of the field that has the keyboard (shortcut keys are ignored while typing)
export const K = { editing: false };
let pressAt = false, fieldHit = false;
export function press(e) {
  if (e.type === "mousedown") { pressAt = true; fieldHit = false; }
  if (e.type === "keydown" && e.key === "escape" && K.editing) { K.editing = false; return true; }
  return false;
}
export function field(id, text, x, y, w, h = 32, ph, flags) {
  const nt = ui.textfield(id, String(text ?? ""), x, y, w, h, ph, flags);
  if (pressAt) {
    const [mx, my] = ui.mouse();
    if (mx >= x && mx <= x + w && my >= y && my <= y + h) fieldHit = id;
  }
  return nt;
}
export function focus(id) { ui.focus(id); K.editing = id; pressAt = false; fieldHit = false; }
export function blur() { K.editing = false; }
export function frameEnd() { if (pressAt) { K.editing = fieldHit; pressAt = false; fieldHit = false; } }

// ------------------------------------------------------------------ toasts
let toastMsg = null, toastAt = 0, toastIcon = null;
export function toast(msg, icon) { toastMsg = String(msg); toastAt = sys.time(); toastIcon = icon || null; }
export function drawToast(w, h) {
  if (!toastMsg) return;
  const age = sys.time() - toastAt;
  if (age > 2.4) { toastMsg = null; return; }
  const a = Math.min(1, age * 8, (2.4 - age) * 4);
  const tw = Math.min(gfx.textWidth(toastMsg, 14, "medium") + (toastIcon ? 58 : 36), w - 24);
  const x = Math.floor((w - tw) / 2), y = h - 62 + Math.floor((1 - a) * 10);
  gfx.alpha(a);
  gfx.shadow(x, y, tw, 38, 19, 12, 4);
  gfx.rect(x, y, tw, 38, 19, theme.dark ? "#48484A" : "#1C1C1E");
  let tx = x + 18;
  if (toastIcon) { gfx.icon(toastIcon, x + 26, y + 19, 18, "#FFFFFF"); tx = x + 42; }
  gfx.color("#FFFFFF");
  gfx.text(ellipsize(toastMsg, 14, "medium", tw - (tx - x) - 16), tx, y + 10, 14, "medium");
  gfx.unalpha();
}

// ------------------------------------------------------------------ undo / redo
export class History {
  constructor(limit = 80) { this.u = []; this.r = []; this.limit = limit; }
  push(s) { this.u.push(s); if (this.u.length > this.limit) this.u.shift(); this.r = []; }
  undo(cur) { if (!this.u.length) return null; this.r.push(cur); return this.u.pop(); }
  redo(cur) { if (!this.r.length) return null; this.u.push(cur); return this.r.pop(); }
  canUndo() { return this.u.length > 0; }
  canRedo() { return this.r.length > 0; }
  clear() { this.u = []; this.r = []; }
}

// ------------------------------------------------------------------ scroller with jumps
export class Scroller {
  constructor() { this.y = 0; this.max = 0; this.target = null; this.drag = null; this.moved = false; this.vel = 0; }
  setMax(m) { this.max = Math.max(0, m); if (this.y > this.max) this.y = this.max; if (this.target !== null && this.target > this.max) this.target = this.max; }
  to(y, instant) { y = clamp(y, 0, this.max); if (instant) { this.y = y; this.target = null; } else this.target = y; }
  reveal(top, bottom, viewH) {
    const cur = this.target ?? this.y;
    if (top < cur) this.to(top - 16); else if (bottom > cur + viewH) this.to(bottom - viewH + 16);
  }
  event(e, r) {
    const inside = e.x >= r[0] && e.x <= r[0] + r[2] && e.y >= r[1] && e.y <= r[1] + r[3];
    if (e.type === "scroll" && inside) { this.y = clamp(this.y + (e.dy || 0), 0, this.max); this.target = null; this.vel = 0; return true; }
    if (e.type === "mousedown") {
      this.moved = false;
      if (inside && e.touch) { this.drag = { y0: e.y, s0: this.y, ly: e.y, lt: sys.time() }; this.vel = 0; }
    } else if (e.type === "mousemove" && this.drag) {
      const d = e.y - this.drag.y0;
      if (Math.abs(d) > 10) this.moved = true;
      if (this.moved) {
        const now = sys.time(), dt = Math.max(1 / 120, now - this.drag.lt);
        this.vel = (this.drag.ly - e.y) / dt;
        this.drag.ly = e.y; this.drag.lt = now;
        this.y = clamp(this.drag.s0 - d, 0, this.max);
        this.target = null;
        return true;
      }
    } else if (e.type === "mouseup" && this.drag) {
      this.drag = null;
      if (!this.moved) this.vel = 0;
    }
    return false;
  }
  dragged() { return this.moved; }
  update(dt) {
    if (this.drag) return;
    if (this.target !== null) {
      this.y = approach(this.y, this.target, 14, dt);
      if (Math.abs(this.y - this.target) < 0.5) { this.y = this.target; this.target = null; }
    } else if (Math.abs(this.vel) > 20) {
      this.y = clamp(this.y + this.vel * dt, 0, this.max);
      this.vel *= Math.exp(-4 * dt);
      if (this.y <= 0 || this.y >= this.max) this.vel = 0;
    } else this.vel = 0;
  }
  bar(x, y, h) {
    if (this.max <= 0) return;
    const th = Math.max(28, (h * h) / (h + this.max));
    const ty = y + (h - th) * (this.y / this.max);
    gfx.rect(x, ty, 4, th, 2, alpha(theme.text, 0.22));
  }
}

// ------------------------------------------------------------------ modal sheet
export function modal(id, w, h, cw, ch, t = 1) {
  gfx.rect(0, 0, w, h, 0, [0, 0, 0, Math.floor((theme.dark ? 120 : 90) * t)]);
  const hit = ui.hit(id + "##modal", 0, 0, w, h);
  cw = Math.min(cw, w - 24); ch = Math.min(ch, h - 24);
  const x = Math.floor((w - cw) / 2), y = Math.floor((h - ch) / 2 + (1 - t) * 24);
  gfx.shadow(x, y, cw, ch, 16, 26, 8);
  gfx.rect(x, y, cw, ch, 16, theme.window);
  gfx.color(theme.separator);
  gfx.rectLine(x, y, cw, ch, 16, 1);
  const [mx, my] = ui.mouse();
  const outside = hit.clicked && !(mx >= x && mx <= x + cw && my >= y && my <= y + ch);
  return [x, y, cw, ch, outside];
}

// ------------------------------------------------------------------ small widgets
export const chipWidth = (label, icon) => gfx.textWidth(label, 13, "medium") + 24 + (icon ? 20 : 0);
export function chip(id, label, x, y, h, active, color, icon) {
  const tw = chipWidth(label, icon);
  const hit = ui.hit(id, x, y, tw, h);
  const c = color || theme.accent;
  gfx.rect(x, y, tw, h, h / 2, active ? c : hit.hovered ? theme.hover : alpha(theme.text, 0.06));
  const fg = active ? onColor(c) : theme.text;
  let tx = x + 12;
  if (icon) { gfx.icon(icon, x + 20, y + h / 2, 16, fg); tx = x + 30; }
  gfx.color(fg);
  gfx.text(label, tx, y + (h - 17) / 2, 13, "medium");
  return [hit.clicked, tw];
}
export function heading(s, x, y, w) {
  s = String(s).toUpperCase();
  gfx.color(theme.text2);
  gfx.text(s, x, y, 11, "semibold");
  if (w) {
    const tw = gfx.textWidth(s, 11, "semibold");
    if (tw + 8 < w) { gfx.color(theme.separator); gfx.line(x + tw + 8, y + 7, x + w, y + 7, 1); }
  }
}
export function empty(icon, title, hint, x, y, w, h) {
  const cy = y + h / 2 - 40;
  gfx.icon(icon, x + w / 2, cy, 44, alpha(theme.text, 0.25));
  gfx.color(theme.text2);
  gfx.text(title, x, cy + 34, 16, "semibold", "center", w);
  if (hint) { gfx.color(theme.text3); gfx.wrap(hint, x + 24, cy + 58, w - 48, 13, "sans", "center"); }
}
