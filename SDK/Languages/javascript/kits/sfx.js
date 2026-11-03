// sfx.js: a small sound design kit for Nexvyn OS games (JavaScript, no dependencies, only SDK 1.1 calls).
// The same kit as SDK/Languages/lua/kits/sfx.lua, with the same recipes and options.
//
// Sounds are described as layered recipes (oscillators, noise, pitch and filter sweeps, envelopes, echo, room),
// rendered once into 16-bit WAV files in the app's data folder (a few milliseconds per frame, never a long call),
// cached across runs, and played with audio.play. On top: buses (music / sfx / ui / amb) with volumes, ducking,
// random variants, voice limits and cooldowns, looping ambience with random details, and short music loops built
// from a chord progression (pad, bass, arpeggio, drums).
//
//   import sfx from "./sfx.js";
//   app.load = () => {
//     sfx.init();                                                   // 22050 Hz mono WAVs in the folder "sfx"
//     sfx.define("coin", sfx.recipes.coin(), { variants: 3 });
//     sfx.define("hit", sfx.recipes.impact({ weight: 0.7 }), { variants: 4, duck: ["music", 0.45, 0.25] });
//     sfx.define("click", sfx.recipes.ui({ kind: "tick" }), { bus: "ui" });
//     sfx.define("wind", sfx.recipes.ambience({ kind: "wind" }), { bus: "amb" });
//     sfx.song("theme", sfx.recipes.song({ bpm: 92, root: "D3", scale: "dorian", chords: [1, 4, 6, 5] }));
//   };
//   app.update = (dt) => sfx.update(dt);                           // bakes, runs the music, ducking, ambience
//   // sfx.ready() / sfx.progress() for a loading screen; then sfx.play("coin"), sfx.music("theme"),
//   // sfx.ambience("wind"), sfx.setBus("music", 0.4)
//
// Guide (how to make sounds feel good, levels, variation): SDK/Guides/SOUND_DESIGN.en.md.

const S = {
  rate: 22050,      // samples per second of the files (the mixer resamples to 48 kHz)
  folder: "sfx",    // in the app's data folder
  version: 1,       // bump to force every file to be made again
  budget: 0.004,    // seconds of baking per frame
  maxUnits: 60000,  // and at most this many layer-samples per frame
  maxVoices: 12,    // sounds of this kit playing at once (the console has 24 channels for everything)
  buses: { master: { vol: 1 }, music: { vol: 0.55 }, sfx: { vol: 0.9 }, ui: { vol: 0.7 }, amb: { vol: 0.6 } },
};

const defs = new Map();
const order = [];
const jobs = [];
const voices = [];
let now = 0;
let music = null;
let amb = null;
let units = 0;
let tickStart = 0;
let inited = false;
const rand = (a, b) => a + Math.floor(Math.random() * (b - a + 1));

// ------------------------------------------------------------------ small helpers
const NOTE = { c: 0, d: 2, e: 4, f: 5, g: 7, a: 9, b: 11 };
S.midi = (n) => {
  if (typeof n === "number") return n;
  const m = /^([a-gA-G])([#b]?)(-?\d)$/.exec(n);
  if (!m) throw new Error("sfx.note: use names like A4, C#3, Eb5");
  return NOTE[m[1].toLowerCase()] + (m[2] === "#" ? 1 : m[2] === "b" ? -1 : 0) + (Number(m[3]) + 1) * 12;
};
// "A4", "C#3", "Eb5" or a MIDI number -> frequency in Hz
S.note = (n) => 440 * Math.pow(2, (S.midi(n) - 69) / 12);
S.db = (d) => Math.pow(10, d / 20);

const copy = (v) => (v && typeof v === "object" ? (Array.isArray(v) ? v.map(copy) : Object.fromEntries(Object.entries(v).map(([k, x]) => [k, copy(x)]))) : v);

// deterministic text of a recipe (sorted keys): the cache key of its files
function serialize(v, out) {
  if (v && typeof v === "object") {
    out.push("{");
    const keys = Array.isArray(v) ? v.map((_, i) => i + 1) : Object.keys(v).sort();
    for (const k of keys) {
      const x = Array.isArray(v) ? v[k - 1] : v[k];
      if (x === undefined || x === null) continue;
      out.push(String(k), "=");
      serialize(x, out);
      out.push(",");
    }
    out.push("}");
  } else if (typeof v === "number") out.push(Number(v.toPrecision(5)).toString());
  else out.push(String(v));
  return out;
}
function hash(s) {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ (s.charCodeAt(i) & 255), 16777619) >>> 0;
  return h.toString(16).padStart(8, "0");
}

// the baking budget: true when this frame's share is used up
const spent = () => units > S.maxUnits || sys.time() - tickStart > S.budget;

// LCG noise (the same numbers as the Lua kit)
function lcg(seed) {
  let s = seed & 0x7fffffff;
  return () => {
    s = (Math.imul(s, 1103515245) + 12345) & 0x7fffffff;
    return s;
  };
}

// ------------------------------------------------------------------ synthesis (generators: `yield` = pause baking)
function* renderLayer(L, buf, base, total, seed) {
  const rate = S.rate;
  const len = L.len ?? 0.2;
  let n = Math.floor(len * rate);
  const first = base + Math.floor((L.at ?? 0) * rate);
  if (first >= total) return;
  if (first + n > total) n = total - first;
  if (n <= 0) return;
  const wave = L.wave ?? "sine";
  const vol = L.vol ?? 1;
  const a = Math.max(1, Math.floor((L.a ?? 0.004) * rate));
  const d = Math.max(1, Math.floor((L.d ?? 0.08) * rate));
  const s = L.s ?? 0.5;
  const r = Math.max(1, Math.floor((L.r ?? 0.08) * rate));
  const relAt = Math.max(a + 1, n - r);
  const dk = Math.exp(-5 / d);
  const rk = Math.exp(-6.9 / r);
  let f = L.freq ?? 440;
  const fTo = L.to ?? f;
  const glideN = Math.max(1, Math.floor((L.glide ?? len) * rate));
  const fStep = Math.pow(fTo / f, 1 / glideN);
  const vib = L.vib;
  const vibW = vib ? (2 * Math.PI * (vib.rate ?? 5)) / rate : 0;
  const vibD = vib ? (vib.depth ?? 0.3) / 12 : 0;
  const trem = L.trem;
  const tremW = trem ? (2 * Math.PI * (trem.rate ?? 4)) / rate : 0;
  const tremD = trem ? trem.depth ?? 0.5 : 0;
  const duty = L.duty ?? 0.5;
  const uni = L.unison ?? 1;
  const cents = L.cents ?? 10;
  const ph = [];
  const mul = [];
  for (let u = 1; u <= uni; u++) {
    ph.push((seed * 0.618 + u * 0.37) % 1);
    mul.push(uni === 1 ? 1 : Math.pow(2, (((u - 1) / (uni - 1) - 0.5) * cents) / 1200));
  }
  const fm = L.fm;
  const fmRatio = fm ? fm.ratio ?? 2 : 0;
  const fmIdx = fm ? fm.index ?? 2 : 0;
  const fmStep = fm ? ((fm.to ?? fmIdx) - fmIdx) / n : 0;
  let mph = 0;
  const noise = lcg(seed * 7919 + 12345);
  let b0 = 0, b1 = 0, b2 = 0, br = 0;
  const flt = [];
  for (const kind of ["hp", "lp", "bp"]) {
    const F = L[kind];
    if (!F) continue;
    const cut = F.cut ?? 1000;
    flt.push({ kind, cut, step: Math.pow((F.to ?? cut) / cut, 1 / n), k: 1 / (F.q ?? 0.707),
      lfoW: F.lfo ? (2 * Math.PI * (F.lfo.rate ?? 0.5)) / rate : 0, lfoD: F.lfo ? F.lfo.depth ?? 1 : 0,
      ic1: 0, ic2: 0, a1: 0, a2: 0, a3: 0 });
  }
  const TAU = 2 * Math.PI;
  const nyq = rate * 0.45;
  let e = 0;
  for (let i = 0; i < n; i++) {
    if (i < a) e = i / a;
    else if (i < relAt) e = s + (e - s) * dk;
    else e *= rk;
    if (i > n - 33) e *= (n - 1 - i) / 32;
    let fi = f;
    if (vib) fi *= Math.pow(2, vibD * Math.sin(vibW * i));
    let v = 0;
    if (wave === "noise" || wave === "pink" || wave === "brown") {
      const w = noise() / 1073741824 - 1;
      if (wave === "noise") v = w;
      else if (wave === "pink") {
        b0 = 0.99765 * b0 + w * 0.099046;
        b1 = 0.963 * b1 + w * 0.2965164;
        b2 = 0.57 * b2 + w * 1.0526913;
        v = (b0 + b1 + b2 + w * 0.1848) * 0.22;
      } else {
        br = (br + 0.02 * w) / 1.02;
        v = br * 3.5;
      }
    } else {
      const dt = fi / rate;
      if (fm) mph = (mph + dt * fmRatio) % 1;
      for (let u = 0; u < uni; u++) {
        const du = dt * mul[u];
        let p = (ph[u] + du) % 1;
        ph[u] = p;
        let x;
        if (fm) p = (((p + ((fmIdx + fmStep * i) * Math.sin(TAU * mph)) / TAU) % 1) + 1) % 1;
        if (wave === "sine") x = Math.sin(TAU * p);
        else if (wave === "triangle") x = 4 * Math.abs(p - 0.5) - 1;
        else if (wave === "saw") {
          x = 2 * p - 1;
          if (p < du) { const t = p / du; x -= t + t - t * t - 1; }
          else if (p > 1 - du) { const t = (p - 1) / du; x -= t * t + t + t + 1; }
        } else {
          x = p < duty ? 1 : -1;
          if (p < du) { const t = p / du; x += t + t - t * t - 1; }
          else if (p > 1 - du) { const t = (p - 1) / du; x += t * t + t + t + 1; }
          const q = (((p - duty) % 1) + 1) % 1;
          if (q < du) { const t = q / du; x -= t + t - t * t - 1; }
          else if (q > 1 - du) { const t = (q - 1) / du; x -= t * t + t + t + 1; }
        }
        v += x;
      }
      if (uni > 1) v /= Math.sqrt(uni);
    }
    if (i < glideN) f *= fStep;
    for (const F of flt) {
      if (i % 8 === 0) {
        let c = F.cut;
        if (F.lfoD !== 0) c *= Math.pow(2, F.lfoD * Math.sin(F.lfoW * i));
        c = Math.min(nyq, Math.max(20, c));
        const g = Math.tan((Math.PI * c) / rate);
        F.a1 = 1 / (1 + g * (g + F.k));
        F.a2 = g * F.a1;
        F.a3 = g * F.a2;
      }
      const v3 = v - F.ic2;
      const v1 = F.a1 * F.ic1 + F.a2 * v3;
      const v2 = F.ic2 + F.a2 * F.ic1 + F.a3 * v3;
      F.ic1 = 2 * v1 - F.ic1;
      F.ic2 = 2 * v2 - F.ic2;
      v = F.kind === "lp" ? v2 : F.kind === "bp" ? v1 : v - F.k * v1 - v2;
      F.cut *= F.step;
    }
    if (trem) v *= 1 - tremD * 0.5 * (1 + Math.sin(tremW * i));
    buf[first + i] += v * e * vol;
    if (i % 512 === 511) {
      units += 512 * (uni + flt.length);
      if (spent()) yield;
    }
  }
}

function* echo(buf, E) {
  const d = Math.max(1, Math.floor((E.time ?? 0.15) * S.rate));
  const fb = E.feedback ?? 0.35;
  const mix = E.mix ?? 0.3;
  const line = new Float32Array(d);
  let pos = 0;
  for (let i = 0; i < buf.length; i++) {
    const x = buf[i];
    const y = line[pos];
    line[pos] = x + y * fb;
    pos = (pos + 1) % d;
    buf[i] = x + y * mix;
    if (i % 2048 === 2047) { units += 1024; if (spent()) yield; }
  }
}

// a small Schroeder room (4 combs, 2 allpasses), mixed in place
function* room(buf, R) {
  const sc = (S.rate / 44100) * (0.6 + (R.size ?? 0.5) * 0.8);
  const fb = 0.72 + (R.size ?? 0.5) * 0.12;
  const damp = R.damp ?? 0.35;
  const mix = R.mix ?? 0.18;
  const combs = [1116, 1188, 1277, 1356].map((l) => { const n = Math.max(1, Math.floor(l * sc)); return { line: new Float32Array(n), n, pos: 0, lp: 0 }; });
  const aps = [556, 441].map((l) => { const n = Math.max(1, Math.floor(l * sc)); return { line: new Float32Array(n), n, pos: 0 }; });
  for (let i = 0; i < buf.length; i++) {
    const x = buf[i] * 0.25;
    let y = 0;
    for (const C of combs) {
      const o = C.line[C.pos];
      C.lp = o * (1 - damp) + C.lp * damp;
      C.line[C.pos] = x + C.lp * fb;
      C.pos = (C.pos + 1) % C.n;
      y += o;
    }
    for (const A of aps) {
      const o = A.line[A.pos];
      A.line[A.pos] = y + o * 0.5;
      A.pos = (A.pos + 1) % A.n;
      y = o - y * 0.5;
    }
    buf[i] += y * mix;
    if (i % 1024 === 1023) { units += 1024; if (spent()) yield; }
  }
}

// mono master: drive, DC block, normalize to `peak` dB, gain, edge fades
function* master(buf, R, loop) {
  const drive = R.drive ?? 0;
  let x1 = 0, y1 = 0, peak = 0;
  for (let i = 0; i < buf.length; i++) {
    let x = buf[i];
    if (drive > 0) {
      x *= 1 + drive * 3;
      x = Math.max(-3, Math.min(3, x));
      x = (x * (27 + x * x)) / (27 + 9 * x * x);
    }
    const y = x - x1 + 0.995 * y1;
    x1 = x;
    y1 = y;
    buf[i] = y;
    peak = Math.max(peak, Math.abs(y));
    if (i % 4096 === 4095) { units += 1024; if (spent()) yield; }
  }
  const g = peak > 0 ? (S.db(R.peak ?? -1) / peak) * S.db(R.gain ?? 0) : 0;
  const n = buf.length;
  const fadeIn = loop ? 0 : Math.floor(S.rate * 0.001);
  const fadeOut = loop ? 0 : Math.floor(S.rate * 0.005);
  for (let i = 0; i < n; i++) {
    let v = buf[i] * g;
    if (i < fadeIn) v *= (i + 1) / fadeIn;
    if (i >= n - fadeOut) v *= (n - 1 - i) / fadeOut;
    buf[i] = v;
  }
}

// WAV file: 16-bit PCM mono
function wav(buf) {
  const n = buf.length;
  const bytes = new Uint8Array(44 + n * 2);
  const dv = new DataView(bytes.buffer);
  const str = (o, s) => { for (let i = 0; i < s.length; i++) bytes[o + i] = s.charCodeAt(i); };
  str(0, "RIFF"); dv.setUint32(4, 36 + n * 2, true); str(8, "WAVE"); str(12, "fmt ");
  dv.setUint32(16, 16, true); dv.setUint16(20, 1, true); dv.setUint16(22, 1, true); dv.setUint32(24, S.rate, true);
  dv.setUint32(28, S.rate * 2, true); dv.setUint16(32, 2, true); dv.setUint16(34, 16, true); str(36, "data");
  dv.setUint32(40, n * 2, true);
  for (let i = 0; i < n; i++) dv.setInt16(44 + i * 2, Math.max(-32768, Math.min(32767, Math.round(buf[i] * 32767))), true);
  return bytes;
}

function recipeLen(R) {
  let len = R.len ?? 0;
  if (R.len == null) { for (const L of R.layers) len = Math.max(len, (L.at ?? 0) + (L.len ?? 0.2)); len += 0.02; }
  return len;
}

// renders a recipe (or the part between t0 and t1, for music bars) to a sample buffer
function* render(R, seed, t0, t1) {
  const rate = S.rate;
  const bars = t0 !== undefined;
  const loop = R.loop && !bars;
  const len = recipeLen(R);
  let tail = R.echo || R.room || R.stems ? R.tail ?? 0.6 : 0;
  if (loop && R.crossfade) tail = R.crossfade;
  const span = bars ? t1 - t0 : len;
  const total = Math.floor((span + tail) * rate);
  const out = new Float32Array(total);
  const stems = new Map();
  for (const L of R.layers) {
    const at = L.at ?? 0;
    if (!bars || (at >= t0 && at < t1)) {
      const name = L.stem ?? "main";
      if (!stems.has(name)) stems.set(name, []);
      stems.get(name).push(L);
    }
  }
  const tmp = stems.size > 1 ? new Float32Array(total) : null;
  let si = 0;
  for (const [name, list] of stems) {
    si++;
    const cfg = (R.stems && R.stems[name]) || {};
    const dst = tmp || out;
    if (tmp) tmp.fill(0);
    let li = 0;
    for (const L of list) {
      li++;
      const Lr = bars ? { ...L, at: (L.at ?? 0) - t0 } : L;
      yield* renderLayer(Lr, dst, 0, total, seed * 31 + li + si * 1000);
    }
    if (cfg.echo) yield* echo(dst, cfg.echo);
    if (tmp) { const g = S.db(cfg.gain ?? 0); for (let i = 0; i < total; i++) out[i] += tmp[i] * g; }
  }
  if (R.echo) yield* echo(out, R.echo);
  if (R.room) yield* room(out, R.room);
  let res = out;
  if (loop) {
    const n = Math.floor(len * rate);
    const t = total - n;
    if (R.crossfade) {
      for (let i = 0; i < t; i++) { const k = (i + 1) / t; out[i] = out[i] * Math.sqrt(k) + out[n + i] * Math.sqrt(1 - k); }
    } else {
      for (let i = 0; i < t; i++) out[i] += out[n + i];
    }
    res = out.subarray(0, n);
  }
  yield* master(res, R, loop);
  return res;
}

// random variation of a recipe: pitch, filter and level, a few percent each
function vary(R, seed, amount) {
  if (seed === 1 || amount <= 0) return R;
  const next = lcg(Math.imul(seed, 2654435761) & 0x7fffffff);
  const r = () => next() / 1073741824 - 1;
  const V = copy(R);
  const pf = Math.pow(2, (r() * amount * 1.5) / 12);
  const ff = Math.pow(2, r() * amount * 0.4);
  for (const L of V.layers) {
    if (L.freq) L.freq *= pf;
    if (L.to) L.to *= pf;
    for (const k of ["lp", "hp", "bp"]) {
      if (L[k]) { L[k].cut = (L[k].cut ?? 1000) * ff; if (L[k].to) L[k].to *= ff; }
    }
    L.vol = (L.vol ?? 1) * (1 + r() * amount * 0.12);
    if (L.at && L.at > 0) L.at *= 1 + r() * amount * 0.08;
  }
  return V;
}

// ------------------------------------------------------------------ definitions and baking
S.init = (o = {}) => {
  for (const k of ["rate", "folder", "version", "budget", "maxUnits", "maxVoices"]) if (o[k] !== undefined) S[k] = o[k];
  fs.mkdir(S.folder);
  inited = true;
};

function enqueue(d) {
  const key = hash(serialize([d.recipe, d.variants, d.vary, d.mode, S.rate, S.version], []).join(""));
  const count = d.kind === "song" && d.mode === "bars" ? d.recipe.bars : d.variants;
  d.files = [];
  let missing = false;
  for (let v = 1; v <= count; v++) {
    d.files.push(`${S.folder}/${d.name}_${key}_${v}.wav`);
    if (!fs.exists(d.files[v - 1])) missing = true;
  }
  d.ready = !missing;
  d.done = 0;
  if (!missing) return;
  const gen = (function* () {
    for (let v = 1; v <= count; v++) {
      const file = d.files[v - 1];
      if (!fs.exists(file)) {
        const buf = d.kind === "song" && d.mode === "bars"
          ? yield* render(d.recipe, v, (v - 1) * d.recipe.bar, v * d.recipe.bar)
          : yield* render(vary(d.recipe, v, d.vary), v);
        if (!fs.write(file, wav(buf))) throw new Error("cannot write " + file);
      }
      d.done = v;
    }
    d.ready = true;
  })();
  const pri = d.kind === "song" ? 3 : d.bus === "amb" ? 2 : 1;
  let at = jobs.findIndex((j) => j.pri > pri);
  if (at < 0) at = jobs.length;
  jobs.splice(at, 0, { def: d, gen, pri });
}

// define(name, recipe[, {bus, vol (0..1), variants, vary (0..1), maxVoices, cooldown (s), duck: [bus, level, sec]}])
S.define = (name, recipe, o = {}) => {
  if (!inited) throw new Error("sfx.define: call sfx.init() first");
  const d = { name, recipe, kind: "sfx", bus: o.bus ?? (recipe.loop ? "amb" : "sfx"), vol: o.vol ?? 1,
    variants: recipe.loop ? 1 : o.variants ?? 1, vary: o.vary ?? 0.5, maxVoices: o.maxVoices ?? 3,
    cooldown: o.cooldown ?? 0.04, duck: o.duck, last: -1, lastVariant: 0 };
  defs.set(name, d);
  order.push(name);
  enqueue(d);
  return d;
};

// song(name, songRecipe[, {vol, mode: "loop" | "bars"}]): "loop" is one gapless file (best quality, no ducking),
// "bars" is one file per bar played in time by sfx.update (ducking and volume changes apply at every bar)
S.song = (name, recipe, o = {}) => {
  if (!inited) throw new Error("sfx.song: call sfx.init() first");
  const d = { name, recipe, kind: "song", bus: "music", vol: o.vol ?? 1, variants: 1, vary: 0, mode: o.mode ?? "loop" };
  defs.set(name, d);
  order.push(name);
  enqueue(d);
  return d;
};

S.ready = (name) => (name ? defs.has(name) && defs.get(name).ready === true : jobs.length === 0);
// 0..1 over everything defined so far (for a loading bar)
S.progress = () => {
  let total = 0, done = 0;
  for (const n of order) {
    const d = defs.get(n);
    total += d.files.length;
    done += d.ready ? d.files.length : d.done;
  }
  return total === 0 ? 1 : done / total;
};

// ------------------------------------------------------------------ buses and ducking
S.setBus = (name, vol) => { S.buses[name] = S.buses[name] || { vol: 1 }; S.buses[name].vol = vol; };
S.bus = (name) => (S.buses[name] ? S.buses[name].vol : 1);
// duck(bus, level 0..1, seconds): the bus plays at `level` for `seconds`, then comes back over 0.3 s
S.duck = (bus, level, sec = 0.25) => {
  const b = S.buses[bus];
  if (!b) return;
  b.duckLevel = Math.min(b.duckLevel ?? 1, level);
  b.duckUntil = Math.max(b.duckUntil ?? 0, now + sec);
};
function busGain(name) {
  const b = S.buses[name] || { vol: 1 };
  return b.vol * S.buses.master.vol * (b.duckLevel ?? 1);
}

// ------------------------------------------------------------------ playing
function voiceEnd(d) {
  if (d.dur === undefined) {
    let len = d.recipe.len ?? 0;
    for (const L of d.recipe.layers) len = Math.max(len, (L.at ?? 0) + (L.len ?? 0.2));
    d.dur = len + (d.recipe.echo || d.recipe.room ? d.recipe.tail ?? 0.6 : 0.02);
  }
  return now + d.dur;
}

// play(name[, {vol, bus}]) -> channel or null
S.play = (name, o = {}) => {
  const d = defs.get(name);
  if (!d || !d.ready || d.kind !== "sfx") return null;
  if (now - d.last < d.cooldown) return null;
  d.last = now;
  let v = 1;
  if (d.variants > 1) {
    v = rand(1, d.variants);
    if (v === d.lastVariant) v = (v % d.variants) + 1;
  }
  d.lastVariant = v;
  let mine = 0, oldest = null;
  for (const vc of voices) {
    if (vc.def === d) { mine++; if (!oldest || vc.t < oldest.t) oldest = vc; }
  }
  if (mine >= d.maxVoices && oldest) { audio.stop(oldest.ch); oldest.dead = true; }
  if (voices.length >= S.maxVoices) { audio.stop(voices[0].ch); voices[0].dead = true; }
  const vol = (o.vol ?? 1) * d.vol * busGain(o.bus ?? d.bus);
  const ch = audio.play(d.files[v - 1], Math.min(1, vol), 0);
  if (d.duck) S.duck(d.duck[0], d.duck[1], d.duck[2]);
  if (ch === null || ch === undefined || ch < 0) return null;
  voices.push({ ch, def: d, t: now, ends: voiceEnd(d) });
  return ch;
};

// music(name): starts a song made with sfx.song (stops the one playing)
S.music = (name) => {
  S.stopMusic();
  const d = defs.get(name);
  if (!d || d.kind !== "song") return false;
  music = { def: d, bar: 0, next: now, ch: null };
  return true;
};
S.stopMusic = () => { if (music && music.ch !== null) audio.stop(music.ch); music = null; };
S.musicPlaying = () => music !== null;

// ambience(name[, {details: ["drip", ...], every: [min, max], vol}]): a looping bed plus random one-shots
S.ambience = (name, o = {}) => {
  S.stopAmbience();
  amb = { name, details: o.details ?? [], every: o.every ?? [2, 6], vol: o.vol ?? 1, next: now + 1, ch: null };
};
S.stopAmbience = () => { if (amb && amb.ch !== null) audio.stop(amb.ch); amb = null; };

// update(dt): call every frame
S.update = (dt = 1 / 60) => {
  now += dt;
  units = 0;
  tickStart = sys.time();
  while (jobs.length > 0 && !spent()) {
    const j = jobs[0];
    try {
      if (j.gen.next().done) jobs.shift();
    } catch (err) {
      sys.log("sfx: " + j.def.name + ": " + err);
      j.def.failed = true;
      jobs.shift();
    }
  }
  for (const b of Object.values(S.buses)) {
    if (b.duckLevel !== undefined && now > (b.duckUntil ?? 0)) {
      b.duckLevel += dt / 0.3;
      if (b.duckLevel >= 1) delete b.duckLevel;
    }
  }
  for (let i = voices.length - 1; i >= 0; i--) if (voices[i].dead || now > voices[i].ends) voices.splice(i, 1);
  if (music && music.def.ready) {
    const d = music.def;
    if (d.mode === "bars") {
      if (now >= music.next - 0.004) {
        music.bar = (music.bar % d.files.length) + 1;
        audio.play(d.files[music.bar - 1], Math.min(1, d.vol * busGain("music")), 0);
        if (music.next < now - 0.1) music.next = now;
        music.next += d.recipe.bar;
      }
    } else if (music.ch === null) {
      music.ch = audio.play(d.files[0], Math.min(1, d.vol * busGain("music")), -1);
    }
  }
  if (amb) {
    const d = defs.get(amb.name);
    if (d && d.ready && amb.ch === null) amb.ch = audio.play(d.files[0], Math.min(1, d.vol * amb.vol * busGain(d.bus)), -1);
    if (now >= amb.next && amb.details.length > 0) {
      S.play(amb.details[rand(0, amb.details.length - 1)], { vol: amb.vol * (0.35 + Math.random() * 0.65), bus: "amb" });
      amb.next = now + amb.every[0] + Math.random() * (amb.every[1] - amb.every[0]);
    }
  }
};

// removes files of this kit's folder that no current definition uses (after a change of recipes)
S.clean = () => {
  const keep = new Set();
  for (const n of order) for (const f of defs.get(n).files) keep.add(f);
  for (const e of fs.list(S.folder) || []) {
    const p = S.folder + "/" + e.name;
    if (!e.dir && e.name.endsWith(".wav") && !keep.has(p)) fs.remove(p, true);
  }
};

// ------------------------------------------------------------------ recipes (the same as in sfx.lua)
const R = {};
S.recipes = R;

// UI: kind = "tick" (move), "confirm", "back", "error", "open"
R.ui = (o = {}) => {
  const p = o.pitch ?? 1;
  const k = o.kind ?? "tick";
  if (k === "confirm") return { layers: [
    { wave: "triangle", freq: 660 * p, len: 0.07, a: 0.002, d: 0.05, s: 0.2, r: 0.03, vol: 0.8 },
    { wave: "triangle", freq: 990 * p, at: 0.055, len: 0.12, a: 0.002, d: 0.08, s: 0.2, r: 0.05, vol: 0.8 },
    { wave: "noise", len: 0.012, a: 0.001, d: 0.01, s: 0, r: 0.002, hp: { cut: 4000 }, vol: 0.25 }],
    room: { size: 0.2, mix: 0.12 } };
  if (k === "back") return { layers: [
    { wave: "triangle", freq: 520 * p, to: 380 * p, len: 0.09, a: 0.002, d: 0.07, s: 0.1, r: 0.02, vol: 0.8 },
    { wave: "noise", len: 0.01, a: 0.001, d: 0.008, s: 0, r: 0.002, hp: { cut: 3000 }, vol: 0.2 }] };
  if (k === "error") return { layers: [
    { wave: "square", duty: 0.3, freq: 180 * p, len: 0.09, a: 0.002, d: 0.06, s: 0.4, r: 0.03, lp: { cut: 1200 }, vol: 0.6 },
    { wave: "square", duty: 0.3, freq: 150 * p, at: 0.1, len: 0.14, a: 0.002, d: 0.08, s: 0.4, r: 0.05, lp: { cut: 1000 }, vol: 0.6 }] };
  if (k === "open") return { layers: [
    { wave: "noise", len: 0.18, a: 0.05, d: 0.1, s: 0.2, r: 0.05, bp: { cut: 900, to: 3500, q: 1.2 }, vol: 0.5 },
    { wave: "sine", freq: 440 * p, to: 880 * p, len: 0.16, a: 0.02, d: 0.1, s: 0.3, r: 0.05, vol: 0.4 }],
    room: { size: 0.3, mix: 0.15 } };
  return { layers: [
    { wave: "sine", freq: 1250 * p, to: 1100 * p, len: 0.035, a: 0.001, d: 0.025, s: 0, r: 0.01, vol: 0.7 },
    { wave: "noise", len: 0.006, a: 0.0005, d: 0.005, s: 0, r: 0.001, bp: { cut: 5000, q: 1.5 }, vol: 0.3 }] };
};

R.coin = (o = {}) => {
  const p = o.pitch ?? 1;
  return { layers: [
    { wave: "triangle", freq: 988 * p, len: 0.08, a: 0.001, d: 0.06, s: 0.3, r: 0.02, vol: 0.7 },
    { wave: "sine", freq: 1319 * p, at: 0.06, len: 0.32, a: 0.001, d: 0.12, s: 0.25, r: 0.18, vol: 0.8, fm: { ratio: 3, index: 0.6, to: 0 } },
    { wave: "noise", at: 0.06, len: 0.05, a: 0.001, d: 0.04, s: 0, r: 0.01, hp: { cut: 7000 }, vol: 0.15 }],
    echo: { time: 0.085, feedback: 0.25, mix: 0.2 } };
};

R.jump = (o = {}) => {
  const p = (o.pitch ?? 1) * (1.3 - (o.weight ?? 0.4) * 0.6);
  return { layers: [
    { wave: "triangle", freq: 220 * p, to: 520 * p, glide: 0.12, len: 0.18, a: 0.003, d: 0.12, s: 0.2, r: 0.05, vol: 0.8 },
    { wave: "square", duty: 0.25, freq: 220 * p, to: 520 * p, glide: 0.12, len: 0.14, a: 0.003, d: 0.08, s: 0.1, r: 0.04, lp: { cut: 2200, to: 900 }, vol: 0.25 },
    { wave: "noise", len: 0.07, a: 0.002, d: 0.05, s: 0, r: 0.01, bp: { cut: 1200, to: 3000, q: 1 }, vol: 0.25 }] };
};

R.laser = (o = {}) => {
  const p = o.pitch ?? 1;
  const len = o.length ?? 0.22;
  return { layers: [
    { wave: "saw", freq: 1800 * p, to: 220 * p, glide: len * 0.8, len, a: 0.001, d: len * 0.6, s: 0.2, r: len * 0.3,
      lp: { cut: 6000, to: 1200, q: 1.4 }, vol: 0.55, fm: { ratio: 1.5, index: 1.2, to: 0 } },
    { wave: "sine", freq: 900 * p, to: 120 * p, glide: len * 0.7, len, a: 0.001, d: len * 0.5, s: 0.1, r: len * 0.3, vol: 0.5 },
    { wave: "noise", len: 0.02, a: 0.0005, d: 0.015, s: 0, r: 0.003, hp: { cut: 3000 }, vol: 0.35 }],
    echo: { time: 0.06, feedback: 0.2, mix: 0.18 } };
};

R.impact = (o = {}) => {
  const w = o.weight ?? 0.5;
  const b = o.bright ?? 0.5;
  return { layers: [
    { wave: "sine", freq: 160 - w * 60, to: 42, glide: 0.09 + w * 0.08, len: 0.2 + w * 0.25, a: 0.001, d: 0.12 + w * 0.15, s: 0, r: 0.06, vol: 1 },
    { wave: "noise", len: 0.08, a: 0.0005, d: 0.05, s: 0, r: 0.02, bp: { cut: 1500 + b * 2500, to: 700, q: 0.9 }, vol: 0.7 },
    { wave: "noise", len: 0.012, a: 0.0003, d: 0.01, s: 0, r: 0.002, hp: { cut: 5000 }, vol: 0.4 * b },
    { wave: "square", duty: 0.4, freq: 90, to: 55, len: 0.1, a: 0.001, d: 0.07, s: 0, r: 0.02, lp: { cut: 600 }, vol: 0.25 * w }],
    drive: 0.25 + w * 0.3, room: { size: 0.25, mix: 0.1 } };
};

R.explosion = (o = {}) => {
  const sz = o.size ?? 0.6;
  const len = 0.7 + sz;
  const layers = [
    { wave: "sine", freq: 110, to: 30, glide: 0.4, len: 0.5 + sz * 0.4, a: 0.001, d: 0.3, s: 0.3, r: 0.2, vol: 1 },
    { wave: "brown", len, a: 0.002, d: len * 0.4, s: 0.35, r: len * 0.5, lp: { cut: 2400, to: 180, q: 0.8 }, vol: 1 },
    { wave: "noise", len: 0.15, a: 0.0005, d: 0.1, s: 0, r: 0.04, bp: { cut: 2000, to: 600, q: 0.7 }, vol: 0.6 }];
  for (let i = 1; i <= 6 + Math.floor(sz * 8); i++)
    layers.push({ wave: "noise", at: 0.05 + ((i * 0.61803) % 1) * len * 0.6, len: 0.015, a: 0.0005, d: 0.012, s: 0, r: 0.002, hp: { cut: 2500 }, vol: 0.25 });
  return { layers, drive: 0.45, room: { size: 0.7, mix: 0.2 }, tail: 0.8 };
};

R.powerup = (o = {}) => {
  const root = S.midi(o.root ?? "C5");
  const layers = [];
  [0, 4, 7, 12, 16].forEach((st, i) => {
    layers.push({ wave: "triangle", freq: S.note(root + st), at: i * 0.06, len: 0.16, a: 0.002, d: 0.1, s: 0.3, r: 0.05, vol: 0.7, vib: { rate: 7, depth: 0.08 } });
    layers.push({ wave: "sine", freq: S.note(root + st + 12), at: i * 0.06, len: 0.12, a: 0.002, d: 0.08, s: 0.2, r: 0.04, vol: 0.25 });
  });
  return { layers, echo: { time: 0.11, feedback: 0.3, mix: 0.25 } };
};

R.hurt = (o = {}) => {
  const p = o.pitch ?? 1;
  return { layers: [
    { wave: "saw", freq: 420 * p, to: 160 * p, len: 0.25, a: 0.002, d: 0.15, s: 0.3, r: 0.08, unison: 2, cents: 30, lp: { cut: 1800, to: 500 }, vol: 0.55 },
    { wave: "noise", len: 0.07, a: 0.001, d: 0.05, s: 0, r: 0.015, bp: { cut: 900, q: 0.8 }, vol: 0.6 },
    { wave: "sine", freq: 120, to: 60, len: 0.14, a: 0.001, d: 0.1, s: 0, r: 0.03, vol: 0.7 }],
    drive: 0.2 };
};

R.whoosh = (o = {}) => {
  const len = o.length ?? 0.3;
  const p = o.pitch ?? 1;
  return { layers: [{ wave: "pink", len, a: len * 0.45, d: len * 0.3, s: 0.3, r: len * 0.25, bp: { cut: 500 * p, to: 2600 * p, q: 1.6 }, vol: 1 }] };
};

R.footstep = (o = {}) => {
  const sfc = o.surface ?? "stone";
  if (sfc === "grass") return { layers: [
    { wave: "noise", len: 0.09, a: 0.004, d: 0.06, s: 0, r: 0.02, hp: { cut: 1800 }, lp: { cut: 6000 }, vol: 0.6 },
    { wave: "brown", len: 0.06, a: 0.002, d: 0.04, s: 0, r: 0.01, lp: { cut: 300 }, vol: 0.5 }] };
  if (sfc === "wood") return { layers: [
    { wave: "sine", freq: 210, to: 170, len: 0.09, a: 0.001, d: 0.06, s: 0, r: 0.02, vol: 0.8 },
    { wave: "noise", len: 0.03, a: 0.0005, d: 0.02, s: 0, r: 0.005, bp: { cut: 1400, q: 2 }, vol: 0.5 }] };
  if (sfc === "snow") {
    const layers = [];
    for (let i = 1; i <= 5; i++) layers.push({ wave: "noise", at: (i - 1) * 0.018, len: 0.03, a: 0.002, d: 0.02, s: 0, r: 0.005, bp: { cut: 2500 + i * 300, q: 1.2 }, vol: 0.45 });
    return { layers };
  }
  if (sfc === "metal") return { layers: [
    { wave: "noise", len: 0.02, a: 0.0005, d: 0.015, s: 0, r: 0.004, hp: { cut: 2000 }, vol: 0.5 },
    { wave: "sine", freq: 1180, len: 0.25, a: 0.001, d: 0.2, s: 0, r: 0.04, vol: 0.2, fm: { ratio: 1.41, index: 1.5, to: 0.2 } },
    { wave: "sine", freq: 260, to: 220, len: 0.08, a: 0.001, d: 0.05, s: 0, r: 0.02, vol: 0.6 }] };
  return { layers: [
    { wave: "noise", len: 0.05, a: 0.001, d: 0.035, s: 0, r: 0.01, bp: { cut: 2200, q: 1.1 }, vol: 0.6 },
    { wave: "sine", freq: 140, to: 90, len: 0.07, a: 0.001, d: 0.05, s: 0, r: 0.015, vol: 0.7 }] };
};

R.jingle = (o = {}) => {
  const notes = o.notes ?? ["C5", "E5", "G5", "C6"];
  const stp = o.step ?? 0.1;
  const layers = [];
  notes.forEach((n, i) => {
    const last = i === notes.length - 1;
    const f = S.note(n);
    const L = { wave: o.wave ?? "triangle", freq: f, at: i * stp, len: last ? 0.6 : stp * 1.6, a: 0.003, d: 0.1, s: 0.45, r: last ? 0.35 : 0.06, vol: 0.7 };
    if (last) L.vib = { rate: 5.5, depth: 0.12 };
    layers.push(L);
    layers.push({ wave: "sine", freq: f * 2, at: i * stp, len: stp * 1.2, a: 0.003, d: 0.06, s: 0.1, r: 0.04, vol: 0.18 });
  });
  return { layers, echo: { time: stp * 1.5, feedback: 0.25, mix: 0.2 }, room: { size: 0.5, mix: 0.15 } };
};

R.detail = (o = {}) => {
  const k = o.kind ?? "drip";
  if (k === "bird") {
    const f = 2800 * (o.pitch ?? 1);
    return { layers: [
      { wave: "sine", freq: f, to: f * 1.5, glide: 0.06, len: 0.08, a: 0.004, d: 0.05, s: 0.3, r: 0.02, vol: 0.6 },
      { wave: "sine", freq: f * 1.2, to: f * 0.9, at: 0.1, len: 0.1, a: 0.004, d: 0.06, s: 0.3, r: 0.03, vol: 0.5, vib: { rate: 28, depth: 1.2 } }],
      room: { size: 0.6, mix: 0.25 } };
  }
  if (k === "crackle") {
    const layers = [];
    for (let i = 1; i <= 4; i++) layers.push({ wave: "noise", at: ((i * 0.37) % 1) * 0.12, len: 0.008, a: 0.0003, d: 0.006, s: 0, r: 0.001, hp: { cut: 2000 + i * 500 }, vol: 0.6 });
    return { layers };
  }
  if (k === "cricket") {
    const layers = [];
    for (let i = 1; i <= 3; i++) layers.push({ wave: "sine", freq: 4300, at: (i - 1) * 0.07, len: 0.05, a: 0.005, d: 0.03, s: 0.5, r: 0.01, trem: { rate: 90, depth: 1 }, vol: 0.4 });
    return { layers };
  }
  if (k === "creak") return { layers: [
    { wave: "saw", freq: 95, to: 70, len: 0.45, a: 0.08, d: 0.2, s: 0.5, r: 0.1, trem: { rate: 32, depth: 0.8 }, bp: { cut: 700, q: 3 }, vol: 0.6 }] };
  return { layers: [{ wave: "sine", freq: 700, to: 1700, glide: 0.03, len: 0.07, a: 0.001, d: 0.05, s: 0, r: 0.015, vol: 0.7 }],
    echo: { time: 0.13, feedback: 0.45, mix: 0.35 }, room: { size: 0.8, mix: 0.3 } };
};

// a seamless ambience bed: kind = "wind", "rain", "night", "cave", "ocean", "hum", "fire"; length in seconds
R.ambience = (o = {}) => {
  const k = o.kind ?? "wind";
  const len = o.length ?? 8;
  const bed = { len: len + 1, a: 0.5, d: 0.1, s: 1, r: 0.5 };
  let L;
  if (k === "wind") L = [
    { ...bed, wave: "brown", bp: { cut: 380, q: 1.3, lfo: { rate: 2 / len, depth: 1.1 } }, vol: 1 },
    { ...bed, wave: "pink", bp: { cut: 1600, q: 6, lfo: { rate: 3 / len, depth: 0.6 } }, trem: { rate: 1 / len, depth: 0.7 }, vol: 0.25 }];
  else if (k === "rain") {
    L = [{ ...bed, a: 0.3, r: 0.3, wave: "pink", hp: { cut: 1200 }, lp: { cut: 7000 }, vol: 0.8 },
      { ...bed, a: 0.3, r: 0.3, wave: "brown", lp: { cut: 400 }, vol: 0.5 }];
    for (let i = 1; i <= Math.floor(len * 14); i++)
      L.push({ wave: "sine", freq: 2500 + ((i * 977) % 2500), at: ((i * 0.618034) % 1) * len, len: 0.012, a: 0.0005, d: 0.009, s: 0, r: 0.002, vol: 0.12 });
  } else if (k === "night") {
    L = [{ ...bed, wave: "pink", lp: { cut: 500 }, vol: 0.5 }];
    for (let i = 0; i < Math.floor(len / 0.9); i++)
      for (let j = 0; j < 3; j++)
        L.push({ wave: "sine", freq: 4300, at: i * 0.9 + j * 0.07, len: 0.05, a: 0.005, d: 0.03, s: 0.5, r: 0.01, trem: { rate: 90, depth: 1 }, vol: 0.12 });
  } else if (k === "cave") L = [
    { ...bed, wave: "brown", lp: { cut: 220, lfo: { rate: 1 / len, depth: 0.5 } }, vol: 1 },
    { ...bed, wave: "sine", freq: 55, trem: { rate: 2 / len, depth: 0.6 }, vol: 0.25 }];
  else if (k === "ocean") L = [
    { ...bed, wave: "pink", lp: { cut: 700, lfo: { rate: 2 / len, depth: 1.2 } }, trem: { rate: 2 / len, depth: 0.8 }, vol: 1 },
    { ...bed, wave: "brown", lp: { cut: 250 }, vol: 0.6 }];
  else if (k === "fire") {
    L = [{ ...bed, a: 0.3, r: 0.3, wave: "brown", lp: { cut: 900 }, trem: { rate: 3 / len, depth: 0.4 }, vol: 0.9 }];
    for (let i = 1; i <= Math.floor(len * 6); i++)
      L.push({ wave: "noise", at: ((i * 0.618034) % 1) * len, len: 0.01, a: 0.0003, d: 0.008, s: 0, r: 0.001, hp: { cut: 1800 + ((i * 331) % 2000) }, vol: 0.35 });
  } else L = [
    { ...bed, wave: "saw", freq: 55, lp: { cut: 260 }, vol: 0.5, unison: 2, cents: 6 },
    { ...bed, wave: "sine", freq: 110, trem: { rate: 4 / len, depth: 0.4 }, vol: 0.3 },
    { ...bed, wave: "noise", hp: { cut: 5000 }, vol: 0.04 }];
  return { layers: L, len, loop: true, crossfade: 1.0, peak: -3 };
};

// ------------------------------------------------------------------ music
const SCALES = {
  major: [0, 2, 4, 5, 7, 9, 11], minor: [0, 2, 3, 5, 7, 8, 10], dorian: [0, 2, 3, 5, 7, 9, 10],
  phrygian: [0, 1, 3, 5, 7, 8, 10], lydian: [0, 2, 4, 6, 7, 9, 11], mixolydian: [0, 2, 4, 5, 7, 9, 10],
  harmonic: [0, 2, 3, 5, 7, 8, 11], pentatonic: [0, 3, 5, 7, 10] };
S.scales = SCALES;

// song({bpm, root ("A2"), scale, chords: [1, 6, 3, 7] (scale degrees, one per bar), bars, pad,
//       bass ("pulse" | "walk" | "simple" | false), arp ("up" | "updown" | "random" | false), arpRate (8 | 16),
//       drums ("soft" | "drive" | "half" | false), sevenths, seed})
R.song = (o = {}) => {
  const bpm = o.bpm ?? 100;
  const beat = 60 / bpm;
  const bar = beat * 4;
  const root = S.midi(o.root ?? "A2");
  const sc = SCALES[o.scale ?? "minor"] ?? SCALES.minor;
  const chords = o.chords ?? [1, 6, 3, 7];
  const nb = o.bars ?? chords.length;
  const deg = (dg, oct) => { const i = dg - 1; return root + sc[i % sc.length] + 12 * (Math.floor(i / sc.length) + oct); };
  const hz = (m) => 440 * Math.pow(2, (m - 69) / 12);
  const arpMode = o.arp === undefined ? "up" : o.arp;
  const bassMode = o.bass === undefined ? "pulse" : o.bass;
  const drums = o.drums === undefined ? "soft" : o.drums;
  const next = lcg(o.seed ?? 7);
  const r01 = () => next() / 2147483648;
  const L = [];
  let prev = null;
  for (let b = 1; b <= nb; b++) {
    const dg = chords[(b - 1) % chords.length];
    const t0 = (b - 1) * bar;
    const tones = [deg(dg, 1), deg(dg + 2, 1), deg(dg + 4, 1)];
    if (o.sevenths) tones.push(deg(dg + 6, 1));
    if (prev) {
      for (let i = 0; i < tones.length; i++) {
        let best = tones[i], bd = 99;
        for (const cand of [tones[i] - 12, tones[i], tones[i] + 12]) {
          for (const pm of prev) { const dd = Math.abs(cand - pm); if (dd < bd) { best = cand; bd = dd; } }
        }
        tones[i] = best;
      }
    }
    prev = tones;
    if (o.pad !== false) for (const m of tones)
      L.push({ stem: "pad", wave: "saw", unison: 3, cents: 14, freq: hz(m), at: t0, len: bar + 0.5, a: Math.min(0.35, bar * 0.2),
        d: 0.4, s: 0.75, r: 0.5, lp: { cut: 900, to: 1500, q: 0.6 }, vol: 0.22 });
    if (bassMode) {
      const bm = deg(dg, 0);
      const hits = bassMode === "pulse" ? [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5] : bassMode === "walk" ? [0, 1, 2, 3] : [0, 2, 3.5];
      hits.forEach((hb, i) => {
        let m = bm;
        if (bassMode === "walk" && i === 3) m = deg(dg + 4, 0);
        if (bassMode === "simple" && i === 2) m = deg(dg + 4, 0);
        const acc = hb % 1 === 0 ? 1 : 0.7;
        L.push({ stem: "bass", wave: "triangle", freq: hz(m), at: t0 + hb * beat, len: beat * (bassMode === "pulse" ? 0.45 : 0.9), a: 0.004, d: 0.15, s: 0.5, r: 0.06, vol: 0.8 * acc });
        L.push({ stem: "bass", wave: "saw", freq: hz(m), at: t0 + hb * beat, len: beat * 0.3, a: 0.003, d: 0.08, s: 0.2, r: 0.04, lp: { cut: 900, to: 300 }, vol: 0.25 * acc });
      });
    }
    if (arpMode) {
      const rate = o.arpRate ?? 8;
      const stp = bar / rate;
      const seq = [tones[0], tones[1], tones[2], tones[0] + 12, tones[1] + 12];
      for (let i = 0; i < rate; i++) {
        let m;
        if (arpMode === "random") m = seq[Math.floor(r01() * seq.length)];
        else if (arpMode === "updown") { const cyc = seq.length * 2 - 2; const k = i % cyc; m = seq[k < seq.length ? k : cyc - k]; }
        else m = seq[i % seq.length];
        L.push({ stem: "arp", wave: "square", duty: 0.25, freq: hz(m + 12), at: t0 + i * stp, len: stp * 0.9, a: 0.002, d: stp * 0.5, s: 0.15, r: 0.04,
          lp: { cut: 2800, to: 1400 }, vol: 0.32 * (i % 2 === 0 ? 1 : 0.75) });
      }
    }
    if (drums) {
      let kick, snare, hat;
      if (drums === "drive") { kick = [0, 1, 2, 3]; snare = [1, 3]; hat = [0.5, 1.5, 2.5, 3.5, 0, 1, 2, 3]; }
      else if (drums === "half") { kick = [0, 2.5]; snare = [2]; hat = [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5]; }
      else { kick = [0, 2]; snare = [1, 3]; hat = [0.5, 1.5, 2.5, 3.5]; }
      for (const hb of kick) {
        L.push({ stem: "drums", wave: "sine", freq: 150, to: 45, glide: 0.08, at: t0 + hb * beat, len: 0.3, a: 0.001, d: 0.2, s: 0, r: 0.06, vol: 1 });
        L.push({ stem: "drums", wave: "noise", at: t0 + hb * beat, len: 0.008, a: 0.0003, d: 0.006, s: 0, r: 0.001, hp: { cut: 2500 }, vol: 0.25 });
      }
      for (const hb of snare) {
        L.push({ stem: "drums", wave: "noise", at: t0 + hb * beat, len: 0.2, a: 0.001, d: 0.12, s: 0, r: 0.05, bp: { cut: 1900, q: 0.8 }, vol: drums === "soft" ? 0.35 : 0.6 });
        L.push({ stem: "drums", wave: "triangle", freq: 200, to: 160, at: t0 + hb * beat, len: 0.1, a: 0.001, d: 0.07, s: 0, r: 0.02, vol: 0.4 });
      }
      hat.forEach((hb, j) => {
        const i = j + 1;
        L.push({ stem: "drums", wave: "noise", at: t0 + hb * beat, len: 0.04, a: 0.0005, d: 0.025, s: 0, r: 0.008, hp: { cut: 7500 }, vol: 0.16 + (0.08 * ((i * 7) % 3)) / 2 });
      });
    }
  }
  return { layers: L, len: nb * bar, bar, bars: nb, loop: true, tail: 1.0, peak: -1,
    stems: { pad: { gain: o.padGain ?? -2 }, bass: { gain: o.bassGain ?? 0 },
      arp: { gain: o.arpGain ?? -5, echo: { time: beat * 0.75, feedback: 0.35, mix: 0.35 } }, drums: { gain: o.drumsGain ?? -3 } },
    room: { size: 0.6, mix: 0.16 } };
};

export default S;
