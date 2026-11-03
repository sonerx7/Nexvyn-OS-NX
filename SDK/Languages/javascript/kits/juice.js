// juice.js: graphics, UI and game-feel building blocks for Nexvyn OS games (JavaScript, no dependencies, SDK calls
// only). The same kit as SDK/Languages/lua/kits/juice.lua; functions that return two values in Lua return [a, b].
//
//   easing and tweens, springs and frame-rate independent damping, screen shake (trauma), hit-stop and slow motion,
//   flashes, particles with soft glow sprites, generated textures (glow, vignette, grain, soft shadow, light ray),
//   multi-stop gradients, palettes and colour maths, typography (scale, letter spacing, outlined / two-tone /
//   glowing titles, fit to width), panels with depth in five shape languages, buttons with hover / press / focus
//   states, screen transitions (fade, iris, wipe, blinds, pixels), a smoothed 2D camera and a 3D follow camera,
//   3D lighting / fog / sky presets.
//
//   import J from "./juice.js";
//   app.load = () => J.init();                          // makes the textures once (cached in the folder "fx")
//   app.update = (dt) => { J.update(dt); const gdt = J.dt(dt); /* game simulation with gdt */ };
//   app.event = (e) => J.event(e);                      // pointer for J.button
//   app.draw = (w, h) => {
//     const [sx, sy] = J.shakeOffset(14);
//     gfx.push(sx, sy); /* your world */ J.drawParticles(); gfx.pop();
//     J.vignette(w, h, 0.55); /* HUD */ J.overlay(w, h); J.endFrame();
//   };
//
// Guide with before / after descriptions: SDK/Guides/GAME_FEEL.en.md.

const J = { folder: "fx", version: 1 };
const { floor, sqrt, sin, cos, exp, abs, min, max, PI } = Math;
const rnd = Math.random;
const clamp = (v, a, b) => (v < a ? a : v > b ? b : v);
J.clamp = clamp;
J.lerp = (a, b, t) => a + (b - a) * t;

// ------------------------------------------------------------------ easing
const E = {
  linear: (t) => t,
  inQuad: (t) => t * t,
  outQuad: (t) => 1 - (1 - t) * (1 - t),
  inOutQuad: (t) => (t < 0.5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2),
  outCubic: (t) => 1 - Math.pow(1 - t, 3),
  inOutCubic: (t) => (t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2),
  outQuart: (t) => 1 - Math.pow(1 - t, 4),
  outExpo: (t) => (t >= 1 ? 1 : 1 - Math.pow(2, -10 * t)),
  inOutSine: (t) => -(cos(PI * t) - 1) / 2,
  outBack: (t) => { const c = 1.70158; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); },
  outElastic: (t) => (t <= 0 || t >= 1 ? t : Math.pow(2, -10 * t) * sin(((t * 10 - 0.75) * (2 * PI)) / 3) + 1),
  outBounce: (t) => {
    const n = 7.5625, d = 2.75;
    if (t < 1 / d) return n * t * t;
    if (t < 2 / d) { t -= 1.5 / d; return n * t * t + 0.75; }
    if (t < 2.5 / d) { t -= 2.25 / d; return n * t * t + 0.9375; }
    t -= 2.625 / d;
    return n * t * t + 0.984375;
  },
};
J.ease = E;

// ------------------------------------------------------------------ tweens, springs, damping
const tweens = [];
// tween(target, seconds, {field: value}[, ease name or function[, {delay, done, loop, yoyo}]]) -> tween
J.tween = (obj, sec, props, ease, o = {}) => {
  const tw = { obj, sec: max(sec, 0.0001), to: props, from: {}, t: -(o.delay ?? 0),
    ease: typeof ease === "function" ? ease : E[ease ?? "outCubic"] ?? E.outCubic, done: o.done, loop: o.loop, yoyo: o.yoyo };
  tweens.push(tw);
  return tw;
};
J.cancel = (tw) => { if (tw) tw.dead = true; };
function updateTweens(dt) {
  for (let i = tweens.length - 1; i >= 0; i--) {
    const tw = tweens[i];
    if (!tw.dead) {
      tw.t += dt;
      if (tw.t >= 0) {
        if (!tw.started) { tw.started = true; for (const k in tw.to) tw.from[k] = tw.obj[k] ?? 0; }
        const p = min(1, tw.t / tw.sec);
        const e = tw.ease(p);
        for (const k in tw.to) tw.obj[k] = tw.from[k] + (tw.to[k] - tw.from[k]) * e;
        if (p >= 1) {
          if (tw.loop) { tw.t = 0; if (tw.yoyo) [tw.from, tw.to] = [tw.to, tw.from]; }
          else { tw.dead = true; if (tw.done) tw.done(tw.obj); }
        }
      }
    }
    if (tw.dead) tweens.splice(i, 1);
  }
}
// damp(current, target, rate, dt): smooth follow that looks the same at 30 and 60 fps (rate ~ 4 slow .. 20 snappy)
J.damp = (a, b, rate, dt) => b + (a - b) * exp(-rate * dt);
// spring(state {x, v}, target, dt[, frequency Hz[, damping 0..1]]): overshoots a little when damping < 1
J.spring = (s, target, dt, freq = 4, z = 0.5) => {
  const w = 2 * PI * freq;
  const steps = Math.ceil(dt / (1 / 120));
  const h = dt / steps;
  for (let i = 0; i < steps; i++) {
    const acc = -2 * z * w * s.v - w * w * (s.x - target);
    s.v += acc * h;
    s.x += s.v * h;
  }
  return s.x;
};

// ------------------------------------------------------------------ time: hit-stop, slow motion
let freeze = 0, slowScale = 1, slowLeft = 0;
// hitstop(seconds): the game simulation stops for 2-6 frames on a heavy hit (0.03-0.1 s)
J.hitstop = (sec) => { freeze = max(freeze, sec); };
// slowmo(scale, seconds): e.g. 0.3 for 0.6 s on the last enemy
J.slowmo = (scale, sec) => { slowScale = scale; slowLeft = sec; };
J.dt = (dt) => (freeze > 0 ? 0 : dt * (slowLeft > 0 ? slowScale : 1));

// ------------------------------------------------------------------ shake (trauma: shake = trauma^2)
let trauma = 0, shakeT = 0;
const seedX = rnd() * 100, seedY = rnd() * 100;
J.shake = (amount) => { trauma = min(1, trauma + amount); };
// [dx, dy] in pixels for gfx.push (maxPx: the shake at full trauma)
J.shakeOffset = (maxPx = 12) => {
  const s = trauma * trauma * maxPx;
  if (s <= 0.01) return [0, 0];
  const t = shakeT * 28;
  const x = (sin(t + seedX) + sin(t * 2.3 + seedX * 1.7) * 0.5) / 1.5;
  const y = (sin(t * 1.1 + seedY) + sin(t * 2.7 + seedY * 1.3) * 0.5) / 1.5;
  return [x * s, y * s];
};
J.trauma = () => trauma;

// ------------------------------------------------------------------ colour
const cache = new Map();
// rgb("#RRGGBB" or "#RRGGBBAA") -> [r, g, b, a] (0..255), memoized (do not change the array)
J.rgb = (c) => {
  if (Array.isArray(c)) return [c[0], c[1], c[2], c[3] ?? 255];
  let t = cache.get(c);
  if (!t) {
    const h = c.replace("#", "");
    t = [parseInt(h.slice(0, 2), 16) || 0, parseInt(h.slice(2, 4), 16) || 0, parseInt(h.slice(4, 6), 16) || 0,
      h.length >= 8 ? parseInt(h.slice(6, 8), 16) : 255];
    cache.set(c, t);
  }
  return t;
};
const h2 = (v) => floor(clamp(v, 0, 255)).toString(16).toUpperCase().padStart(2, "0");
const hex = (r, g, b, a) => "#" + h2(r) + h2(g) + h2(b) + (a !== undefined && a < 255 ? h2(a) : "");
J.hex = hex;
// mix(c1, c2, t) -> "#RRGGBB(AA)"; shade(c, f): f < 1 darker, > 1 lighter; alpha(c, 0..1)
J.mix = (c1, c2, t) => {
  const [r1, g1, b1, a1] = J.rgb(c1);
  const [r2, g2, b2, a2] = J.rgb(c2);
  return hex(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t, a1 + (a2 - a1) * t);
};
J.shade = (c, f) => {
  const [r, g, b, a] = J.rgb(c);
  if (f <= 1) return hex(r * f, g * f, b * f, a);
  const k = f - 1;
  return hex(r + (255 - r) * k, g + (255 - g) * k, b + (255 - b) * k, a);
};
J.alpha = (c, a) => { const [r, g, b] = J.rgb(c); return hex(r, g, b, a * 255); };
// mixInto(out, c1, c2, t[, alpha]): the same into a reused array [r, g, b, a] (no garbage in draw loops)
J.mixInto = (out, c1, c2, t, alpha = 1) => {
  const p = J.rgb(c1), q = J.rgb(c2);
  for (let i = 0; i < 3; i++) out[i] = Math.round(clamp(p[i] + (q[i] - p[i]) * t, 0, 255));
  out[3] = Math.round(clamp((p[3] + (q[3] - p[3]) * t) * alpha, 0, 255));
  return out;
};

// Palettes: deep (darkest background), bg, mid (shapes, panels), ink (text), accent (player, actions),
// accent2 (danger, rewards), light (highlights, glows). Start from one, then make it yours.
J.palettes = {
  ember: { deep: "#140C1C", bg: "#2A1630", mid: "#5B2A3C", ink: "#FFE9D2", accent: "#FF6B35", accent2: "#FFC145", light: "#FFF3B0" },
  frost: { deep: "#06121F", bg: "#0E2A47", mid: "#2E5C8A", ink: "#E8F6FF", accent: "#5CE1E6", accent2: "#FF7AA2", light: "#FFFFFF" },
  toxic: { deep: "#0A0F0A", bg: "#14261A", mid: "#2F4F2A", ink: "#E9FFD9", accent: "#9DFF3A", accent2: "#FF3AC8", light: "#F4FFB0" },
  synth: { deep: "#0B0221", bg: "#1D0B45", mid: "#4C1D95", ink: "#FCEBFF", accent: "#FF2E88", accent2: "#19E6FF", light: "#FFD166" },
  jungle: { deep: "#0C1A12", bg: "#183A26", mid: "#2F6B3E", ink: "#F2F7D9", accent: "#F2B134", accent2: "#E8505B", light: "#FFF6C2" },
  paper: { deep: "#2B2118", bg: "#F4EAD5", mid: "#D8C3A0", ink: "#2B2118", accent: "#E9573F", accent2: "#3F7CAC", light: "#FFFDF6" },
  noir: { deep: "#050505", bg: "#121212", mid: "#2B2B2B", ink: "#F2F2F2", accent: "#E63946", accent2: "#F1FAEE", light: "#FFFFFF" },
  candy: { deep: "#2D1B4E", bg: "#FFB5D8", mid: "#FF7EB6", ink: "#2D1B4E", accent: "#7AE7C7", accent2: "#FFE156", light: "#FFFFFF" },
};

// gradient(x, y, w, h, [c1, c2, c3, ...][, horizontal]): several stops, evenly spaced
J.gradient = (x, y, w, h, stops, horizontal) => {
  const n = stops.length - 1;
  if (n < 1) { gfx.rect(x, y, w, h, 0, stops[0]); return; }
  for (let i = 1; i <= n; i++) {
    if (horizontal) {
      const x0 = floor(x + (w * (i - 1)) / n), x1 = x + (w * i) / n;
      gfx.gradient(x0, y, Math.ceil(x1 - x0) + 1, h, stops[i - 1], stops[i], true);
    } else {
      const y0 = floor(y + (h * (i - 1)) / n), y1 = y + (h * i) / n;
      gfx.gradient(x, y0, w, Math.ceil(y1 - y0) + 1, stops[i - 1], stops[i]);
    }
  }
};

// ------------------------------------------------------------------ generated textures (PNG, made once)
const CRC = new Uint32Array(256);
for (let i = 0; i < 256; i++) {
  let c = i;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  CRC[i] = c >>> 0;
}
function crc32(bytes, start, end) {
  let c = 0xffffffff;
  for (let i = start; i < end; i++) c = CRC[(c ^ bytes[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
// png(w, h, fn(x, y) -> [r, g, b, a]) -> Uint8Array with a PNG file (uncompressed deflate)
J.png = (w, h, fn) => {
  const rowLen = w * 4 + 1;
  const raw = new Uint8Array(rowLen * h);
  for (let y = 0; y < h; y++) {
    raw[y * rowLen] = 0;
    for (let x = 0; x < w; x++) {
      const p = fn(x, y);
      const o = y * rowLen + 1 + x * 4;
      for (let k = 0; k < 4; k++) raw[o + k] = clamp(floor(p[k]), 0, 255);
    }
  }
  const nBlocks = Math.max(1, Math.ceil(raw.length / 65535));
  const idatLen = 2 + raw.length + nBlocks * 5 + 4;
  const total = 8 + (12 + 13) + (12 + idatLen) + 12;
  const out = new Uint8Array(total);
  const dv = new DataView(out.buffer);
  let o = 0;
  out.set([137, 80, 78, 71, 13, 10, 26, 10], 0); o = 8;
  const chunk = (type, len, fill) => {
    dv.setUint32(o, len); o += 4;
    const start = o;
    for (let i = 0; i < 4; i++) out[o++] = type.charCodeAt(i);
    fill();
    dv.setUint32(o, crc32(out, start, o)); o += 4;
  };
  chunk("IHDR", 13, () => { dv.setUint32(o, w); dv.setUint32(o + 4, h); out.set([8, 6, 0, 0, 0], o + 8); o += 13; });
  chunk("IDAT", idatLen, () => {
    out[o++] = 0x78; out[o++] = 0x01;
    let pos = 0;
    let a = 1, b = 0;
    for (let i = 0; i < raw.length; i++) { a = (a + raw[i]) % 65521; b = (b + a) % 65521; }
    do {
      const len = Math.min(65535, raw.length - pos);
      out[o++] = pos + len >= raw.length ? 1 : 0;
      out[o++] = len & 255; out[o++] = len >> 8; out[o++] = ~len & 255; out[o++] = (~len >> 8) & 255;
      out.set(raw.subarray(pos, pos + len), o); o += len; pos += len;
    } while (pos < raw.length);
    dv.setUint32(o, ((b << 16) | a) >>> 0); o += 4;
  });
  chunk("IEND", 0, () => {});
  return out;
};
// texture(name, w, h, fn) -> image: generated once into the data folder, then loaded from there
J.texture = (name, w, h, fn) => {
  const path = `${J.folder}/${name}_${J.version}_${w}x${h}.png`;
  if (!fs.exists(path)) fs.write(path, J.png(w, h, fn));
  return gfx.image(path);
};
const smooth = (a, b, x) => { const t = clamp((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t); };
J.smoothstep = smooth;

J.tex = {};
J.init = (o = {}) => {
  J.folder = o.folder ?? J.folder;
  fs.mkdir(J.folder);
  J.tex.glow = J.texture("glow", 64, 64, (x, y) => {
    const d = sqrt((x - 31.5) ** 2 + (y - 31.5) ** 2) / 32;
    return [255, 255, 255, Math.pow(1 - smooth(0, 1, d), 2.2) * 255];
  });
  J.tex.vignette = J.texture("vignette", 128, 128, (x, y) => {
    const dx = (x - 63.5) / 63.5, dy = (y - 63.5) / 63.5;
    return [0, 0, 0, Math.pow(smooth(0.35, 1.0, sqrt(dx * dx + dy * dy) / sqrt(2)), 1.4) * 255];
  });
  let s = 12345;
  J.tex.grain = J.texture("grain", 128, 128, () => {
    s = (Math.imul(s, 1103515245) + 12345) & 0x7fffffff;
    const v = s % 256;
    return [v, v, v, 255];
  });
  J.tex.shadow = J.texture("shadow", 64, 32, (x, y) => {
    const dx = (x - 31.5) / 32, dy = (y - 15.5) / 16;
    return [0, 0, 0, (1 - smooth(0.2, 1, sqrt(dx * dx + dy * dy))) * 200];
  });
  J.tex.ray = J.texture("ray", 32, 128, (x, y) => {
    const dx = abs(x - 15.5) / 16;
    return [255, 255, 255, (1 - smooth(0, 1, dx)) * Math.pow(1 - y / 127, 1.5) * 255];
  });
};

// glow(x, y, radius, colour[, alpha]): a soft light (core + halo); bright colours on dark backgrounds read best
J.glow = (x, y, r, color, a = 1) => {
  if (!J.tex.glow) return;
  gfx.alpha(a);
  gfx.draw(J.tex.glow, x - r, y - r, r * 2, r * 2, 0, color);
  gfx.draw(J.tex.glow, x - r * 0.45, y - r * 0.45, r * 0.9, r * 0.9, 0, color);
  gfx.unalpha();
};
J.vignette = (w, h, strength = 0.5, color) => {
  if (!J.tex.vignette) return;
  gfx.alpha(strength);
  gfx.draw(J.tex.vignette, -2, -2, w + 4, h + 4, 0, color);
  gfx.unalpha();
};
J.grain = (w, h, a = 0.04) => {
  if (!J.tex.grain) return;
  const ox = -floor(rnd() * 128), oy = -floor(rnd() * 128);
  gfx.alpha(a);
  for (let y = oy; y < h; y += 128) for (let x = ox; x < w; x += 128) gfx.draw(J.tex.grain, x, y, 128, 128);
  gfx.unalpha();
};
J.blob = (x, y, w, h, a = 0.6) => {
  if (!J.tex.shadow) return;
  gfx.alpha(a);
  gfx.draw(J.tex.shadow, x - w / 2, y - h / 2, w, h);
  gfx.unalpha();
};
J.rays = (x, y, len, count, color, a = 0.18, t = 0, wd = 60) => {
  if (!J.tex.ray) return;
  gfx.alpha(a);
  for (let i = 1; i <= count; i++) {
    const f = (i - 0.5) / count;
    const sway = sin(t * 0.4 + i * 1.7) * 18;
    const rw = wd * (0.6 + 0.4 * sin(i * 2.1) ** 2);
    gfx.draw(J.tex.ray, x + (f - 0.5) * len * 0.8 + sway - rw / 2, y, rw, len * (0.7 + 0.3 * sin(i * 1.3) ** 2), 0, color);
  }
  gfx.unalpha();
};

// ------------------------------------------------------------------ flash and floaters
let flash = null;
J.flash = (color, sec = 0.2, a = 0.6) => { flash = { c: color, t: 0, sec, a }; };
const floaters = [];
J.floatText = (s, x, y, color = "#FFFFFF", size = 20) => {
  floaters.push({ s: String(s), x, y, c: color, size, t: 0, life: 0.9, vx: (rnd() - 0.5) * 30 });
};
J.drawFloaters = () => {
  for (const f of floaters) {
    const p = f.t / f.life;
    const pop = p < 0.15 ? E.outBack(p / 0.15) : 1;
    gfx.alpha(1 - smooth(0.6, 1, p));
    gfx.color("#00000088");
    gfx.text(f.s, f.x + 2, f.y - p * 40 + 2, f.size * pop, "bold", "center", 0);
    gfx.color(f.c);
    gfx.text(f.s, f.x, f.y - p * 40, f.size * pop, "bold", "center", 0);
    gfx.unalpha();
  }
};

// ------------------------------------------------------------------ particles
let parts = [];
const MAXP = 600;
const C = [0, 0, 0, 0];
J.presets = {
  sparks: { n: 18, speed: [180, 420], life: [0.18, 0.45], size: [3, 0], colors: ["#FFF3B0", "#FF6B35"], gravity: 600, drag: 2, kind: "spark" },
  embers: { n: 10, speed: [20, 70], life: [0.8, 1.8], size: [6, 0], colors: ["#FFC145", "#FF3B1F00"], gravity: -40, drag: 0.5, kind: "glow", flicker: true },
  dust: { n: 8, speed: [20, 60], angle: -PI / 2, spread: PI, life: [0.4, 0.8], size: [5, 12], colors: ["#D8C3A0AA", "#D8C3A000"], gravity: -20, drag: 3, kind: "dot" },
  smoke: { n: 8, speed: [10, 40], life: [0.8, 1.6], size: [10, 34], colors: ["#55555588", "#22222200"], gravity: -50, drag: 1, kind: "glow" },
  confetti: { n: 30, speed: [150, 380], angle: -PI / 2, spread: 1.2, life: [0.9, 1.6], size: [6, 4], colors: ["#FF2E88", "#19E6FF"], gravity: 500, drag: 1.5, kind: "square", multi: ["#FF2E88", "#19E6FF", "#FFD166", "#7AE7C7"] },
  magic: { n: 16, speed: [30, 120], life: [0.5, 1.1], size: [8, 0], colors: ["#B388FF", "#19E6FF00"], gravity: -60, drag: 1.5, kind: "glow", flicker: true },
  hit: { n: 1, speed: [0, 0], life: [0.25, 0.25], size: [6, 46], colors: ["#FFFFFF", "#FFFFFF00"], gravity: 0, drag: 0, kind: "ring" },
};
// burst(x, y, preset name or object[, overrides {n, angle, spread}])
J.burst = (x, y, preset, o = {}) => {
  const P = typeof preset === "object" ? preset : J.presets[preset] ?? J.presets.sparks;
  const n = o.n ?? P.n;
  for (let i = 0; i < n; i++) {
    if (parts.length >= MAXP) parts.shift();
    const ang = o.angle ?? P.angle;
    const a = ang !== undefined ? ang + (rnd() - 0.5) * (o.spread ?? P.spread ?? 0.6) : rnd() * 2 * PI;
    const sp = P.speed[0] + rnd() * (P.speed[1] - P.speed[0]);
    const life = P.life[0] + rnd() * (P.life[1] - P.life[0]);
    const c0 = P.multi ? P.multi[floor(rnd() * P.multi.length)] : P.colors[0];
    parts.push({ x, y, vx: cos(a) * sp, vy: sin(a) * sp, t: 0, life, s0: P.size[0] * (0.7 + rnd() * 0.6), s1: P.size[1],
      c0, c1: P.multi ? c0 : P.colors[1], g: P.gravity ?? 0, drag: P.drag ?? 0, kind: P.kind, flicker: P.flicker, ph: rnd() * 10 });
  }
};
J.drawParticles = () => {
  for (const p of parts) {
    const k = p.t / p.life;
    const s = p.s0 + (p.s1 - p.s0) * k;
    J.mixInto(C, p.c0, p.c1, k);
    if (p.c0 === p.c1) C[3] = floor(C[3] * (1 - k));
    if (p.flicker) C[3] = floor(C[3] * (0.65 + 0.35 * sin(p.ph + p.t * 30)));
    if (p.kind === "glow" && J.tex.glow) gfx.draw(J.tex.glow, p.x - s * 2, p.y - s * 2, s * 4, s * 4, 0, C);
    else if (p.kind === "spark") { gfx.color(C); gfx.line(p.x, p.y, p.x - p.vx * 0.03, p.y - p.vy * 0.03, max(1, s)); }
    else if (p.kind === "square") { gfx.color(C); const w = s * (0.4 + 0.6 * abs(sin(p.ph + p.t * 9))); gfx.rect(p.x - w / 2, p.y - s / 2, w, s, 0); }
    else if (p.kind === "ring") { gfx.color(C); gfx.circleLine(p.x, p.y, s, max(1, 4 * (1 - k))); }
    else { gfx.color(C); gfx.circle(p.x, p.y, max(0.5, s / 2)); }
  }
};
J.particleCount = () => parts.length;
J.clearParticles = () => { parts = []; };

// ------------------------------------------------------------------ typography
J.scale = (base = 16, ratio = 1.333) => ({ xs: base / ratio / ratio, sm: base / ratio, md: base, lg: base * ratio,
  xl: base * ratio ** 2, xxl: base * ratio ** 3, display: base * ratio ** 5 });
J.spacedWidth = (s, size, font, sp) => {
  let w = 0, n = 0;
  for (const ch of s) { w += gfx.textWidth(ch, size, font); n++; }
  return w + max(0, n - 1) * sp;
};
J.spaced = (s, x, y, size, font, sp, align, w = 0) => {
  const tw = J.spacedWidth(s, size, font, sp);
  if (align === "center") x += (w - tw) / 2;
  else if (align === "right") x += w - tw;
  for (const ch of s) { gfx.text(ch, x, y, size, font); x += gfx.textWidth(ch, size, font) + sp; }
  return tw;
};
J.fit = (s, maxW, size, font, minSize = 10) => {
  const w = gfx.textWidth(s, size, font);
  return w <= maxW ? size : max(minSize, (size * maxW) / w);
};
// title(text, x, y, size, {font, fill, fill2, outline, outlineW, shadow, shadowY, glow, glowAlpha, spacing, align, w,
// bands}) -> [width, height]
J.title = (s, x, y, size, o = {}) => {
  const font = o.font ?? "bold";
  const sp = o.spacing ?? size * 0.04;
  const tw = J.spacedWidth(s, size, font, sp);
  const th = gfx.textHeight(size, font);
  let lx = x;
  if (o.align === "center") lx = x + ((o.w ?? 0) - tw) / 2;
  else if (o.align === "right") lx = x + (o.w ?? 0) - tw;
  const put = (dx, dy) => J.spaced(s, lx + dx, y + dy, size, font, sp);
  if (o.glow) J.glow(lx + tw / 2, y + th / 2, max(tw, th) * 0.75, o.glow, o.glowAlpha ?? 0.5);
  if (o.shadow) {
    const sy = o.shadowY ?? size * 0.08;
    gfx.alpha(0.35); gfx.color(o.shadow); put(0, sy * 1.6); gfx.unalpha();
    gfx.color(o.shadow); put(0, sy);
  }
  if (o.outline) {
    const ow = o.outlineW ?? max(1, size * 0.05);
    gfx.color(o.outline);
    for (let i = 0; i < 8; i++) put(cos((i * PI) / 4) * ow, sin((i * PI) / 4) * ow);
  }
  const fill = o.fill ?? "#FFFFFF";
  if (o.fill2) {
    const n = o.bands ?? 10;
    const top = y + th * 0.18, hgt = th * 0.7;
    for (let i = 0; i < n; i++) {
      const y0 = i === 0 ? y - size : top + (hgt * i) / n;
      const y1 = i === n - 1 ? y + th + size : top + (hgt * (i + 1)) / n;
      gfx.clip(lx - size, y0, tw + size * 2, y1 - y0);
      gfx.color(J.mix(fill, o.fill2, i / (n - 1)));
      put(0, 0);
      gfx.unclip();
    }
  } else { gfx.color(fill); put(0, 0); }
  return [tw, th];
};

// ------------------------------------------------------------------ panels
const shapePts = (x, y, w, h, shape, cut) => {
  if (shape === "cut") return [x + cut, y, x + w - cut, y, x + w, y + cut, x + w, y + h - cut, x + w - cut, y + h, x + cut, y + h, x, y + h - cut, x, y + cut];
  if (shape === "slant") return [x + cut, y, x + w, y, x + w - cut, y + h, x, y + h];
  if (shape === "tab") return [x, y, x + w - cut, y, x + w, y + cut, x + w, y + h, x, y + h];
  return null;
};
J.shapePoints = shapePts;
// panel(x, y, w, h, {shape: "round" | "pill" | "cut" | "slant" | "tab", r, cut, fill, fill2, border, borderW, shadow,
//   blur, shadowY, depth, depthColor, highlight})
J.panel = (x, y, w, h, o = {}) => {
  const shape = o.shape ?? "round";
  const r = shape === "pill" ? h / 2 : o.r ?? 10;
  const cut = o.cut ?? min(h * 0.3, 16);
  const fill = o.fill ?? "#2A2A3A";
  const depth = o.depth ?? 0;
  if (o.shadow !== false) {
    gfx.alpha(o.shadow ?? 0.5);
    gfx.shadow(x, y + depth, w, h, shape === "round" || shape === "pill" ? r : 4, o.blur ?? 16, o.shadowY ?? 6);
    gfx.unalpha();
  }
  const pts = shapePts(x, y, w, h, shape, cut);
  if (depth > 0) {
    const dc = o.depthColor ?? J.shade(fill, 0.55);
    if (pts) gfx.poly(shapePts(x, y + depth, w, h, shape, cut), dc); else gfx.rect(x, y + depth, w, h, r, dc);
  }
  if (pts) {
    gfx.poly(pts, fill);
    if (o.highlight) { gfx.color(o.highlight); gfx.line(pts[0], pts[1] + 1, pts[2], pts[3] + 1, 1.5); }
    if (o.border) { gfx.color(o.border); gfx.lines(pts, o.borderW ?? 2, true); }
  } else {
    if (o.fill2) gfx.gradient(x, y, w, h, fill, o.fill2, false, r); else gfx.rect(x, y, w, h, r, fill);
    if (o.highlight) { gfx.color(o.highlight); gfx.line(x + r, y + 1.5, x + w - r, y + 1.5, 1.5); }
    if (o.border) { gfx.color(o.border); gfx.rectLine(x, y, w, h, r, o.borderW ?? 2); }
  }
};

// ------------------------------------------------------------------ pointer and buttons
J.pointer = { x: -1, y: -1, down: false, pressed: false, released: false, downX: -1, downY: -1 };
J.event = (e) => {
  const P = J.pointer;
  if (e.type === "mousemove" || e.type === "mousedown" || e.type === "mouseup") { P.x = e.x ?? P.x; P.y = e.y ?? P.y; }
  if (e.type === "mousedown") { P.down = true; P.pressed = true; P.downX = P.x; P.downY = P.y; }
  if (e.type === "mouseup") { P.down = false; P.released = !e.cancel; }
};
const states = new Map();
// onUi(kind) is called on "hover" and "press": set it to play your UI sounds, e.g.
//   J.onUi = (kind) => sfx.play(kind === "press" ? "confirm" : "tick");
J.onUi = null;
// button(id, label, x, y, w, h[, {focused, activate, enabled, shape, r, cut, fill, fillHover, ink, inkHover, border,
//   focusColor, highlight, size, font, depth, glow}]) -> [clicked, state]
J.button = (id, label, x, y, w, h, o = {}) => {
  let st = states.get(id);
  if (!st) { st = { hover: { x: 0, v: 0 }, press: { x: 0, v: 0 }, wasHover: false, kick: 0 }; states.set(id, st); }
  const P = J.pointer;
  const inside = P.x >= x && P.x <= x + w && P.y >= y && P.y <= y + h;
  const enabled = o.enabled !== false;
  const hot = enabled && (inside || !!o.focused);
  if (hot && !st.wasHover && J.onUi) J.onUi("hover");
  st.wasHover = hot;
  let clicked = false;
  const downInside = P.downX >= x && P.downX <= x + w && P.downY >= y && P.downY <= y + h;
  if (enabled && ((P.released && inside && downInside) || (o.focused && o.activate))) {
    clicked = true;
    st.kick = 1;
    if (J.onUi) J.onUi("press");
  }
  st.kick = max(0, st.kick - 0.12);
  const hv = J.spring(st.hover, hot ? 1 : 0, 1 / 60, 5, 0.55);
  const pr = J.spring(st.press, (P.down && inside) || st.kick > 0.5 ? 1 : 0, 1 / 60, 9, 0.7);
  const depth = o.depth ?? 5;
  const lift = -hv * 2 + pr * depth;
  const k = clamp(hv, 0, 1);
  const fill = enabled ? J.mix(o.fill ?? "#2E2A4A", o.fillHover ?? o.fill ?? "#4B3F8C", k) : "#55555566";
  if (o.glow && hv > 0.05) J.glow(x + w / 2, y + h / 2 + lift, max(w, h) * 0.65, o.glow, 0.35 * k);
  J.panel(x, y + lift, w, h, { shape: o.shape ?? "round", r: o.r, cut: o.cut, fill, depth: max(0, depth - pr * depth),
    border: o.focused && enabled ? o.focusColor ?? "#FFFFFF" : o.border, borderW: 2, highlight: o.highlight ?? "#FFFFFF33",
    shadow: 0.35 + hv * 0.2 });
  const size = o.size ?? h * 0.42;
  const font = o.font ?? "semibold";
  gfx.color(enabled ? J.mix(o.ink ?? "#E8E6FF", o.inkHover ?? o.ink ?? "#FFFFFF", k) : "#FFFFFF77");
  const th = gfx.textHeight(size, font);
  gfx.text(label, x, y + lift + (h - th) / 2, J.fit(label, w - 16, size, font), font, "center", w);
  return [clicked, st];
};
// call at the end of app.draw (after every J.button) so a press counts once
J.endFrame = () => { J.pointer.pressed = false; J.pointer.released = false; };

// ------------------------------------------------------------------ transitions
let tr = null;
let pixelOrder = null;
// transition(kind, seconds, onMiddle[, colour]): "fade", "iris", "wipe", "blinds", "pixels"
J.transition = (kind = "fade", sec = 0.5, mid, color = "#000000") => { tr = { kind, sec, t: 0, mid, c: color, called: false }; };
J.transitioning = () => tr !== null;
function drawTransition(w, h) {
  if (!tr) return;
  const half = tr.sec / 2;
  const p = tr.t < half ? E.inOutCubic(tr.t / half) : E.inOutCubic(1 - (tr.t - half) / half);
  gfx.color(tr.c);
  if (tr.kind === "iris") {
    const far = sqrt(w * w + h * h);
    gfx.circleLine(w / 2, h / 2, far * (1 - p) + far / 2, far);
  } else if (tr.kind === "wipe") {
    if (tr.t < half) { const x = (w + h * 0.5 + 20) * p - 10; gfx.poly([-10, -10, x, -10, x - h * 0.5, h + 10, -10, h + 10], tr.c); }
    else { const x = w + 10 - (w + h * 0.5 + 20) * (1 - p); gfx.poly([x, -10, w + 10, -10, w + 10, h + 10, x - h * 0.5, h + 10], tr.c); }
  } else if (tr.kind === "blinds") {
    const n = 8, bh = h / n;
    for (let i = 0; i < n; i++) { const q = clamp(p * 1.6 - (i / n) * 0.6, 0, 1); gfx.rect(0, i * bh + (bh * (1 - q)) / 2, w, bh * q + 1, 0); }
  } else if (tr.kind === "pixels") {
    const cs = max(16, floor(min(w, h) / 12));
    const cols = Math.ceil(w / cs), rows = Math.ceil(h / cs);
    if (!pixelOrder || pixelOrder.length !== cols * rows) pixelOrder = Array.from({ length: cols * rows }, () => rnd());
    for (let i = 0; i < cols * rows; i++) if (pixelOrder[i] < p) gfx.rect((i % cols) * cs, floor(i / cols) * cs, cs + 1, cs + 1, 0);
  } else {
    gfx.alpha(p);
    gfx.rect(0, 0, w, h, 0);
    gfx.unalpha();
  }
}
// overlay(w, h): the flash and the transition; draw it last
J.overlay = (w, h) => {
  if (flash) {
    const k = 1 - flash.t / flash.sec;
    gfx.alpha(flash.a * k * k);
    gfx.rect(0, 0, w, h, 0, flash.c);
    gfx.unalpha();
  }
  drawTransition(w, h);
};

// ------------------------------------------------------------------ cameras
// 2D: camera({x, y, lag, lead, dead: {w, h}, bounds: {x, y, w, h}})
J.camera = (o = {}) => ({
  x: o.x ?? 0, y: o.y ?? 0, lag: o.lag ?? 7, lead: o.lead ?? 0.25, dead: o.dead, bounds: o.bounds, lx: 0, ly: 0,
  follow(tx, ty, vx = 0, vy = 0, dt = 1 / 60) {
    this.lx = J.damp(this.lx, vx * this.lead, 3, dt);
    this.ly = J.damp(this.ly, vy * this.lead * 0.5, 3, dt);
    let gx = tx + this.lx, gy = ty + this.ly;
    if (this.dead) {
      const dx = gx - this.x, dy = gy - this.y, hw = this.dead.w / 2, hh = this.dead.h / 2;
      gx = abs(dx) > hw ? gx - (dx > 0 ? hw : -hw) : this.x;
      gy = abs(dy) > hh ? gy - (dy > 0 ? hh : -hh) : this.y;
    }
    this.x = J.damp(this.x, gx, this.lag, dt);
    this.y = J.damp(this.y, gy, this.lag, dt);
  },
  // offset(w, h[, shakePx]) -> [dx, dy] for gfx.push
  offset(w, h, shakePx = 12) {
    let x = this.x, y = this.y;
    const b = this.bounds;
    if (b) {
      x = clamp(x, b.x + w / 2, max(b.x + w / 2, b.x + b.w - w / 2));
      y = clamp(y, b.y + h / 2, max(b.y + h / 2, b.y + b.h - h / 2));
    }
    const [sx, sy] = J.shakeOffset(shakePx);
    return [Math.round(w / 2 - x + sx), Math.round(h / 2 - y + sy)];
  },
});
// 3D follow camera: cam3d({dist, height, lookHeight, lag, fov}); follow(x, y, z, yaw, dt); apply(); fov(); kick(deg)
J.cam3d = (o = {}) => ({
  dist: o.dist ?? 6, height: o.height ?? 3, look: o.lookHeight ?? 1, lag: o.lag ?? 6, fov0: o.fov ?? 55, kickV: 0,
  tx: 0, ty: 0, tz: 0, yaw: 0, init: false,
  follow(x, y, z, yaw, dt) {
    if (!this.init) { this.yaw = yaw; this.tx = x; this.ty = y; this.tz = z; this.init = true; }
    const dy = ((((yaw - this.yaw + PI) % (2 * PI)) + 2 * PI) % (2 * PI)) - PI;
    this.yaw += dy * (1 - exp(-this.lag * 0.5 * dt));
    this.tx = J.damp(this.tx, x, this.lag, dt);
    this.ty = J.damp(this.ty, y, this.lag, dt);
    this.tz = J.damp(this.tz, z, this.lag, dt);
    this.kickV = J.damp(this.kickV, 0, 6, dt);
  },
  kick(deg) { this.kickV += deg; },
  fov() { return this.fov0 + this.kickV; },
  apply() {
    const [sx, sy] = J.shakeOffset(0.25);
    g3d.camera(this.tx - sin(this.yaw) * this.dist + sx, this.ty + this.height + sy, this.tz - cos(this.yaw) * this.dist,
      this.tx, this.ty + this.look, this.tz);
  },
});

J.looks = {
  dusk: { top: "#1B1036", horizon: "#FF7B54", bottom: "#2A1630", fog: "#5B2A4A", light: [-0.4, 0.5, 0.6], ambient: 0.35, color: "#FFD2A8", glow: "#FFB070" },
  noon: { top: "#3A86FF", horizon: "#CDE7FF", bottom: "#9CC9FF", fog: "#BFDFFF", light: [0.3, 1, 0.4], ambient: 0.45, color: "#FFFFFF", glow: "#FFF6C2" },
  night: { top: "#02040F", horizon: "#16315C", bottom: "#050A18", fog: "#0B1730", light: [0.2, 0.8, -0.5], ambient: 0.22, color: "#9DB8FF", glow: "#7CC4FF" },
  toxic: { top: "#0B140B", horizon: "#6BFF3A", bottom: "#102010", fog: "#1F3A1A", light: [0.4, 0.7, 0.2], ambient: 0.3, color: "#D8FFB0", glow: "#9DFF3A" },
  frost: { top: "#0B2545", horizon: "#BEE9FF", bottom: "#13315C", fog: "#8DB8D9", light: [-0.3, 0.9, 0.3], ambient: 0.5, color: "#E8F6FF", glow: "#5CE1E6" },
  desert: { top: "#F28C28", horizon: "#FFE0A3", bottom: "#E7B072", fog: "#F2C48D", light: [0.6, 0.8, 0.2], ambient: 0.45, color: "#FFF1D6", glow: "#FFD27A" },
  abyss: { top: "#000814", horizon: "#00507A", bottom: "#001D3D", fog: "#003049", light: [0, 1, 0.2], ambient: 0.3, color: "#7FDBFF", glow: "#48CAE4" },
  synth: { top: "#0B0221", horizon: "#FF2E88", bottom: "#1D0B45", fog: "#3B0A45", light: [0.3, 0.6, 0.6], ambient: 0.3, color: "#FFC2E2", glow: "#19E6FF" },
};
// sky(w, h, look[, horizonY 0..1]): background for a 3D scene (draw before g3d.begin)
J.sky = (w, h, look, hz = 0.55) => {
  const hy = floor(h * hz);
  gfx.gradient(0, 0, w, hy + 1, look.top, look.horizon);
  gfx.gradient(0, hy, w, h - hy, look.horizon, look.bottom);
  J.glow(w * 0.5, h * hz, w * 0.35, look.glow, 0.35);
};
// light3d(look[, far]): g3d.light + g3d.fog for the look; call after g3d.begin
J.light3d = (look, far = 40) => {
  const l = look.light;
  g3d.light(l[0], l[1], l[2], look.ambient, look.color);
  g3d.fog(look.fog, far * 0.35, far);
};

// ------------------------------------------------------------------ update
J.update = (dt) => {
  shakeT += dt;
  trauma = max(0, trauma - dt * 1.4);
  if (freeze > 0) freeze -= dt;
  if (slowLeft > 0) slowLeft -= dt;
  updateTweens(dt);
  if (flash) { flash.t += dt; if (flash.t >= flash.sec) flash = null; }
  if (tr) {
    tr.t += dt;
    if (!tr.called && tr.t >= tr.sec / 2) { tr.called = true; if (tr.mid) tr.mid(); }
    if (tr.t >= tr.sec) tr = null;
  }
  for (let i = parts.length - 1; i >= 0; i--) {
    const p = parts[i];
    p.t += dt;
    if (p.t >= p.life) { parts.splice(i, 1); continue; }
    const d = exp(-p.drag * dt);
    p.vx *= d;
    p.vy = p.vy * d + p.g * dt;
    p.x += p.vx * dt;
    p.y += p.vy * dt;
  }
  for (let i = floaters.length - 1; i >= 0; i--) {
    const f = floaters[i];
    f.t += dt;
    f.x += f.vx * dt;
    if (f.t >= f.life) floaters.splice(i, 1);
  }
};

export default J;
