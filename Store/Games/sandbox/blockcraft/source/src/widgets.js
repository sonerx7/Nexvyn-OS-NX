// Immediate-mode menu widgets in the game's own look, usable with the controller (D-pad / stick to move the focus,
// A to choose, left / right on sliders and options, B back), touch and mouse.
import { clamp } from "./util.js";

export function shadowText(s, x, y, size, color = "#FFFFFF", align = "left", w = 0, font = "bold") {
  gfx.color("#00000099");
  gfx.text(s, x + Math.max(1, size * 0.08), y + Math.max(1, size * 0.08), size, font, align, w);
  gfx.color(color);
  gfx.text(s, x, y, size, font, align, w);
}

export function panel(x, y, w, h, k = 1) {
  gfx.color("#00000070");
  gfx.rect(x + 3 * k, y + 4 * k, w, h, 8 * k);
  gfx.color("#1B1E24E8");
  gfx.rect(x, y, w, h, 8 * k);
  gfx.color("#FFFFFF14");
  gfx.rect(x + 2 * k, y + 2 * k, w - 4 * k, 3 * k, 2 * k);
}

export class Menu {
  constructor() {
    this.items = [];
    this.focus = 0;
    this.repeat = 0;
    this.lastDir = 0;
    this.activated = null;
    this.usePad = false;
  }

  begin() {
    this.count = this.items.length;  // the items of the last frame: nav() runs before this frame's buttons exist
    this.items = [];
    this.activated = null;
    const [mx, my] = ui.mouse();
    this.mouseMoved = this.lastMx !== undefined && (Math.abs(mx - this.lastMx) > 2 || Math.abs(my - this.lastMy) > 2);
    if (this.mouseMoved) this.usePad = false;
    this.lastMx = mx; this.lastMy = my;
  }

  nav(dt) {
    const [, sy] = input.stick("left");
    let dir = 0;
    if (input.pressed("down")) dir = 1;
    else if (input.pressed("up")) dir = -1;
    else if (Math.abs(sy) > 0.6) {
      const d = sy > 0 ? -1 : 1;
      if (d !== this.lastDir || this.repeat <= 0) { dir = d; this.repeat = this.lastDir === d ? 0.12 : 0.35; }
      this.repeat -= dt;
      this.lastDir = d;
    } else this.lastDir = 0;
    if (dir) {
      this.usePad = true;
      const n = this.count || this.items.length;
      if (n) this.focus = (this.focus + dir + n) % n;
    }
    return dir;
  }

  side() {
    const [sx] = input.stick("left");
    if (input.pressed("right")) return 1;
    if (input.pressed("left")) return -1;
    if (Math.abs(sx) > 0.6) {
      this.sideRepeat = (this.sideRepeat || 0) - 1 / 60;
      if (this.sideRepeat <= 0) { this.sideRepeat = 0.12; return sx > 0 ? 1 : -1; }
    } else this.sideRepeat = 0;
    return 0;
  }

  focused(i) { return this.usePad && this.focus === i; }

  button(id, label, x, y, w, h, k = 1, opts = {}) {
    const i = this.items.length;
    this.items.push(id);
    const hit = ui.hit("btn:" + id, x, y, w, h);
    if (hit.hovered && this.mouseMoved && !input.touch()) this.focus = i;
    const on = this.focus === i && (this.usePad || hit.hovered || !this.mouseMoved);
    const enabled = opts.enabled !== false;
    gfx.color("#00000060");
    gfx.rect(x + 2 * k, y + 3 * k, w, h, 6 * k);
    gfx.color(!enabled ? "#2A2D33" : opts.primary ? (on ? "#3E9B4F" : "#2F7D3E") : on ? "#4A5160" : "#323741");
    gfx.rect(x, y, w, h, 0);
    gfx.color(on ? "#FFFFFF" : "#FFFFFF22");
    gfx.rectLine(x, y, w, h, 0, on ? 2.5 * k : 1);
    gfx.color(on ? "#CAD5BA" : "#A2A69E");gfx.rect(x+2*k,y+2*k,w-4*k,2*k,0);
    gfx.color("#1F2420");gfx.rect(x+2*k,y+h-4*k,w-4*k,2*k,0);
    if (opts.icon) { gfx.icon(opts.icon, x + 22 * k, y + h / 2, 22 * k, enabled ? "#FFFFFF" : "#888888"); }
    shadowText(label, x + (opts.icon ? 20 * k : 0), y + (h - 20 * k) / 2, 18 * k, enabled ? (on ? "#FFFFA0" : "#FFFFFF") : "#8A8A8A", "center", w - (opts.icon ? 20 * k : 0));
    const clicked = enabled && (hit.clicked || (this.focus === i && input.pressed("a")));
    if (clicked && !hit.clicked) this.usePad = true;
    if (clicked) { this.activated = id; audio.play("click", 0.5); }
    return clicked;
  }

  // option cycling through values: returns the new value
  option(id, label, value, values, names, x, y, w, h, k = 1) {
    const idx = Math.max(0, values.indexOf(value));
    const i = this.items.length;
    let v = value;
    if (this.button(id, `${label}: ${names[idx]}`, x, y, w, h, k)) v = values[(idx + 1) % values.length];
    if (this.focus === i) {
      const s = this.side();
      if (s) { this.usePad = true; v = values[(idx + s + values.length) % values.length]; audio.play("click", 0.4); }
    }
    return v;
  }

  slider(id, label, value, min, max, step, x, y, w, h, k = 1, fmt = v => String(v)) {
    const i = this.items.length;
    this.items.push(id);
    const hit = ui.hit("sld:" + id, x, y, w, h);
    if (hit.hovered && this.mouseMoved && !input.touch()) this.focus = i;
    const on = this.focus === i && (this.usePad || hit.hovered || !this.mouseMoved);
    let v = value;
    if (hit.held) {
      const [mx] = ui.mouse();
      v = min + clamp((mx - x - 8 * k) / (w - 16 * k), 0, 1) * (max - min);
      v = Math.round(v / step) * step;
    }
    if (this.focus === i) { const s = this.side(); if (s) { this.usePad = true; v = clamp(Math.round((v + s * step) / step) * step, min, max); } }
    v = clamp(v, min, max);
    gfx.color("#00000060"); gfx.rect(x + 2 * k, y + 3 * k, w, h, 6 * k);
    gfx.color("#262A31"); gfx.rect(x, y, w, h, 0);
    const f = (v - min) / (max - min);
    gfx.color(on ? "#3E7DD8" : "#2E5EA6"); gfx.rect(x, y, Math.max(12 * k, w * f), h, 6 * k);
    gfx.color(on ? "#FFFFFF" : "#FFFFFF22"); gfx.rectLine(x, y, w, h, 0, on ? 2.5 * k : 1);
    gfx.color("#E8ECF4"); gfx.rect(x + (w - 10 * k) * f, y + 2 * k, 10 * k, h - 4 * k, 3 * k);
    shadowText(`${label}: ${fmt(Math.round(v * 1000) / 1000)}`, x, y + (h - 20 * k) / 2, 18 * k, on ? "#FFFFA0" : "#FFFFFF", "center", w);
    return v;
  }

  back() { return input.pressed("b") || input.key("escape"); }
}
