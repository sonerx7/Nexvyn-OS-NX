// calc.js: Numbook's evaluator. Every line is parsed on its own: numbers, + - × ÷ ^ and parentheses, functions,
// variables (name = expression), percentages (20% of 350, 80 + 15%), units with conversions (5 km in mi, 2 h 30 min),
// temperatures, and "sum"/"total" of the lines above.

const UNITS = {};
function def(dim, factor, ...names) { for (const n of names) UNITS[n] = { dim, factor, name: names[0] }; }
def("length", 0.001, "mm"); def("length", 0.01, "cm"); def("length", 1, "m"); def("length", 1000, "km");
def("length", 0.0254, "in", "inch", "inches"); def("length", 0.3048, "ft", "feet", "foot"); def("length", 0.9144, "yd", "yard", "yards");
def("length", 1609.344, "mi", "mile", "miles");
def("mass", 1e-6, "mg"); def("mass", 0.001, "g", "gram", "grams"); def("mass", 1, "kg", "kilo", "kilos"); def("mass", 1000, "t", "ton", "tons");
def("mass", 0.028349523125, "oz", "ounce", "ounces"); def("mass", 0.45359237, "lb", "lbs", "pound", "pounds");
def("time", 0.001, "ms"); def("time", 1, "s", "sec", "secs", "second", "seconds"); def("time", 60, "min", "mins", "minute", "minutes");
def("time", 3600, "h", "hr", "hrs", "hour", "hours"); def("time", 86400, "day", "days", "d"); def("time", 604800, "week", "weeks", "wk");
def("time", 2629746, "month", "months"); def("time", 31556952, "year", "years", "yr");
def("data", 0.125, "bit", "bits"); def("data", 1, "B", "byte", "bytes"); def("data", 1000, "KB", "kB"); def("data", 1e6, "MB"); def("data", 1e9, "GB");
def("data", 1e12, "TB"); def("data", 1024, "KiB"); def("data", 1048576, "MiB"); def("data", 1073741824, "GiB");
def("volume", 0.001, "ml", "mL"); def("volume", 0.01, "cl"); def("volume", 0.1, "dl"); def("volume", 1, "l", "L", "liter", "liters", "litre", "litres");
def("volume", 3.785411784, "gal", "gallon", "gallons"); def("volume", 0.946352946, "qt", "quart", "quarts"); def("volume", 0.2365882365, "cup", "cups");
def("volume", 0.0295735, "floz"); def("volume", 0.00492892, "tsp"); def("volume", 0.0147868, "tbsp");
def("speed", 1, "mps"); def("speed", 1 / 3.6, "kmh", "kph"); def("speed", 0.44704, "mph"); def("speed", 0.514444, "knot", "knots");
def("area", 1, "m2", "m²"); def("area", 1e6, "km2", "km²"); def("area", 10000, "ha"); def("area", 4046.8564224, "acre", "acres"); def("area", 0.09290304, "ft2", "ft²");
def("temp", 1, "C", "°C", "celsius"); def("temp", 1, "F", "°F", "fahrenheit"); def("temp", 1, "K", "kelvin");

const FUNCS = {
  sqrt: Math.sqrt, cbrt: Math.cbrt, abs: Math.abs, round: (x, d = 0) => Math.round(x * 10 ** d) / 10 ** d, floor: Math.floor, ceil: Math.ceil,
  sin: (x) => Math.sin(x), cos: (x) => Math.cos(x), tan: (x) => Math.tan(x), asin: Math.asin, acos: Math.acos, atan: Math.atan,
  ln: Math.log, log: (x, b) => (b ? Math.log(x) / Math.log(b) : Math.log10(x)), exp: Math.exp,
  min: (...a) => Math.min(...a), max: (...a) => Math.max(...a), avg: (...a) => a.reduce((s, x) => s + x, 0) / a.length,
  fact: (n) => { let r = 1; for (let i = 2; i <= n && i <= 170; i++) r *= i; return r; },
};
const CONSTS = { pi: Math.PI, π: Math.PI, e: Math.E, tau: Math.PI * 2 };
const CONVERT = new Set(["to", "in", "as", "->", "→", "into"]);

// a value: number v in base units; unit = display unit name or null; dim = dimension or null; pct = percentage flag
const num = (v) => ({ v, unit: null, dim: null });
function withUnit(x, u) {
  const U = UNITS[u];
  if (U.dim === "temp") {
    const n = U.name;
    const k = n === "C" ? x + 273.15 : n === "F" ? (x - 32) * 5 / 9 + 273.15 : x;
    return { v: k, unit: n, dim: "temp" };
  }
  return { v: x * U.factor, unit: U.name, dim: U.dim };
}
function inUnit(val, u) {
  const U = UNITS[u];
  if (U.dim === "temp") {
    const k = val.v;
    return U.name === "C" ? k - 273.15 : U.name === "F" ? (k - 273.15) * 9 / 5 + 32 : k;
  }
  return val.v / U.factor;
}
export function displayNumber(val) { return val.unit ? inUnit(val, val.unit) : val.v; }

// ---------------------------------------------------------------- tokenizer
function tokenize(s) {
  const out = [];
  let i = 0, depth = 0;
  while (i < s.length) {
    const c = s[i];
    if (/\s/.test(c) || "€$£¥₺₩".includes(c)) { i++; continue; }
    if (c === "(") depth++;
    if (c === ")") depth = Math.max(0, depth - 1);
    let m;
    const rest = s.slice(i);
    // a decimal comma (1,5) is read outside function calls only, where commas separate arguments
    if ((m = rest.match(depth > 0 ? /^(\d+(?:\.\d+)?|\.\d+)(?:e[+-]?\d+)?/i : /^(\d+(?:[.,]\d+)?|\.\d+)(?:e[+-]?\d+)?/i))) {
      let t = m[0].replace(",", ".");
      let v = parseFloat(t);
      i += m[0].length;
      // 5k = 5000, 2M = 2 000 000 (unless it is a unit like MB)
      const suf = s.slice(i).match(/^([kKM])(?![A-Za-z])/);
      if (suf) { v *= suf[1] === "M" ? 1e6 : 1000; i += 1; }
      out.push({ t: "num", v });
      continue;
    }
    if ((m = rest.match(/^(->|→|\*\*|[+\-*\/×÷^%(),=−·])/))) {
      const map = { "×": "*", "·": "*", "÷": "/", "**": "^", "−": "-", "→": "->" };
      out.push({ t: "op", v: map[m[0]] || m[0] });
      i += m[0].length;
      continue;
    }
    if ((m = rest.match(/^°?[\p{L}_][\p{L}\p{N}_²]*/u))) {
      out.push({ t: "id", v: m[0] });
      i += m[0].length;
      continue;
    }
    throw new Error("char");
  }
  return out;
}

// ---------------------------------------------------------------- parser (precedence climbing)
export function evaluate(src, vars) {
  const toks = tokenize(src);
  let p = 0;
  const peek = () => toks[p];
  const next = () => toks[p++];
  const isOp = (v) => peek() && peek().t === "op" && peek().v === v;
  const isId = (v) => peek() && peek().t === "id" && peek().v.toLowerCase() === v;

  function add(a, b, sign) {
    if (b.pct && !a.pct) return { ...a, v: a.v * (1 + sign * b.v) };
    if (a.dim !== b.dim) {
      if (!a.dim) a = { ...b, v: b.unit ? withUnit(a.v, b.unit).v : a.v };
      else if (!b.dim) b = { ...a, v: a.unit ? withUnit(b.v, a.unit).v : b.v };
      else throw new Error("dim");
    }
    if (a.dim === "temp") return withUnit(inUnit(a, a.unit) + sign * inUnit(b, b.unit === "K" ? "K" : a.unit), a.unit);
    return { v: a.v + sign * b.v, unit: a.unit || b.unit, dim: a.dim || b.dim, pct: a.pct && b.pct };
  }
  function mul(a, b, div) {
    if (div) {
      if (b.v === 0) throw new Error("div0");
      if (a.dim && a.dim === b.dim) return num(a.v / b.v);
      if (b.dim) throw new Error("dim");
      return { ...a, v: a.v / b.v, pct: false };
    }
    if (a.dim && b.dim) throw new Error("dim");
    const d = a.dim ? a : b;
    return { v: a.v * b.v, unit: d.unit, dim: d.dim };
  }

  function primary() {
    const t = next();
    if (!t) throw new Error("end");
    if (t.t === "num") return num(t.v);
    if (t.t === "op" && t.v === "(") {
      const v = expr();
      if (!isOp(")")) throw new Error("paren");
      next();
      return v;
    }
    if (t.t === "id") {
      const name = t.v;
      const lname = name.toLowerCase();
      if (FUNCS[lname] && isOp("(")) {
        next();
        const args = [];
        if (!isOp(")")) {
          args.push(expr());
          while (isOp(",")) { next(); args.push(expr()); }
        }
        if (!isOp(")")) throw new Error("paren");
        next();
        const r = FUNCS[lname](...args.map((a) => displayNumber(a)));
        if (!Number.isFinite(r)) throw new Error("nan");
        // round/abs/min/max keep the unit of their first argument
        if (["abs", "round", "floor", "ceil", "min", "max", "avg"].includes(lname) && args[0] && args[0].unit) return withUnit(r, args[0].unit);
        return num(r);
      }
      if (vars && Object.prototype.hasOwnProperty.call(vars, lname)) return { ...vars[lname] };
      if (Object.prototype.hasOwnProperty.call(CONSTS, lname)) return num(CONSTS[lname]);
      throw new Error("unknown:" + name);
    }
    throw new Error("unexpected");
  }
  function unary() {
    if (isOp("-")) {
      next();
      const v = unary();
      if (v.unit) return withUnit(-inUnit(v, v.unit), v.unit);
      return { ...v, v: -v.v };
    }
    if (isOp("+")) { next(); return unary(); }
    return postfix();
  }
  function postfix() {
    let v = primary();
    for (;;) {
      if (isOp("%")) { next(); v = { v: v.v / 100, unit: null, dim: null, pct: true }; continue; }
      if (peek() && peek().t === "id" && UNITS[peek().v] && !v.dim) {
        // "in" followed by a unit or % is the conversion keyword, not inches
        const nx = toks[p + 1];
        if (peek().v === "in" && nx && ((nx.t === "id" && UNITS[nx.v]) || (nx.t === "op" && nx.v === "%"))) break;
        const u = next().v;
        v = withUnit(v.v, u);
        // compound durations and lengths: 2 h 30 min, 5 ft 11 in
        while (peek() && peek().t === "num" && toks[p + 1] && toks[p + 1].t === "id" && UNITS[toks[p + 1].v] && UNITS[toks[p + 1].v].dim === v.dim) {
          const n2 = next().v;
          const u2 = next().v;
          v = { ...v, v: v.v + withUnit(n2, u2).v };
        }
        continue;
      }
      break;
    }
    return v;
  }
  function power() {
    const b = unary();
    if (isOp("^")) {
      next();
      const e = power();
      if (e.dim) throw new Error("dim");
      if (b.dim) throw new Error("dim");
      return num(Math.pow(b.v, e.v));
    }
    return b;
  }
  function term() {
    let a = power();
    for (;;) {
      if (isOp("*")) { next(); a = mul(a, power(), false); }
      else if (isOp("/")) { next(); a = mul(a, power(), true); }
      else if (isId("of") && a.pct) { next(); const b = term(); return { ...b, v: b.v * a.v }; }
      else if (peek() && (peek().t === "num" || (peek().t === "op" && peek().v === "("))) { a = mul(a, power(), false); }
      else break;
    }
    return a;
  }
  function sum() {
    let a = term();
    for (;;) {
      if (isOp("+")) { next(); a = add(a, term(), 1); }
      else if (isOp("-")) { next(); a = add(a, term(), -1); }
      else break;
    }
    return a;
  }
  function expr() {
    let a = sum();
    // conversions: "to km", "in mi", "as %", "as % of 200"
    while (peek() && ((peek().t === "id" && CONVERT.has(peek().v.toLowerCase())) || (peek().t === "op" && peek().v === "->"))) {
      next();
      const t = next();
      if (!t) throw new Error("end");
      if (t.t === "op" && t.v === "%") {
        if (isId("of")) { next(); const b = sum(); if (b.v === 0) throw new Error("div0"); a = { v: a.v / b.v, unit: null, dim: null, pct: true }; }
        else a = { v: a.v, unit: null, dim: null, pct: true };
        continue;
      }
      if (t.t !== "id" || !UNITS[t.v]) throw new Error("unit");
      const U = UNITS[t.v];
      if (!a.dim) a = withUnit(a.v, t.v);
      else if (a.dim !== U.dim) throw new Error("dim");
      else a = { ...a, unit: U.name };
    }
    return a;
  }
  const v = expr();
  if (p < toks.length) throw new Error("trailing");
  return v;
}

// ---------------------------------------------------------------- lines
// returns {kind: "blank"|"heading"|"comment"|"value"|"error", value, name, label}
export function evalLine(line, vars, above) {
  let s = String(line);
  const t = s.trim();
  if (!t) return { kind: "blank" };
  if (t.startsWith("#")) return { kind: "heading", text: t.replace(/^#+\s*/, "") };
  if (t.startsWith("//")) return { kind: "comment" };
  s = s.replace(/\/\/.*$/, "");
  let label = null;
  const lm = s.match(/^([^:=0-9()+\-*/]+[^:=]*?):\s*(.+)$/);
  if (lm && /[\p{L}]/u.test(lm[1])) { label = lm[1].trim(); s = lm[2]; }
  let name = null;
  const am = s.match(/^\s*([\p{L}_][\p{L}\p{N}_]*)\s*=\s*(.+)$/u);
  if (am && !UNITS[am[1]]) { name = am[1].toLowerCase(); s = am[2]; }
  const low = s.trim().toLowerCase();
  if (["sum", "total", "toplam", "summe", "somme", "suma", "合計", "合计", "합계"].includes(low)) {
    // sum of the results since the last blank line or heading
    let acc = null;
    for (let i = above.length - 1; i >= 0; i--) {
      const r = above[i];
      if (r.kind === "blank" || r.kind === "heading") break;
      if (r.kind === "value" && !r.isSum) {
        try { acc = acc ? addValues(acc, r.value) : { ...r.value }; } catch (e) { /* mixed units are skipped */ }
      }
    }
    const value = acc || num(0);
    if (name) vars[name] = value;
    return { kind: "value", value, label, name, isSum: true };
  }
  try {
    const localVars = { ...vars };
    const prev = [...above].reverse().find((r) => r.kind === "value");
    if (prev) { localVars.ans = prev.value; localVars.prev = prev.value; }
    const value = evaluate(s, localVars);
    if (!Number.isFinite(value.v)) throw new Error("nan");
    if (name) vars[name] = value;
    return { kind: "value", value, label, name };
  } catch (e) {
    return { kind: label || name ? "error" : "text", error: String(e.message || e) };
  }
}
function addValues(a, b) {
  if (a.dim !== b.dim) {
    if (!a.dim && a.v === 0) return { ...b };
    throw new Error("dim");
  }
  return { ...a, v: a.v + b.v, unit: a.unit || b.unit };
}

export function formatValue(val, style) {
  let x = displayNumber(val);
  if (val.pct) x = val.v * 100;
  const abs = Math.abs(x);
  let s;
  if (abs !== 0 && (abs >= 1e15 || abs < 1e-6)) s = x.toExponential(6).replace(/\.?0+e/, "e");
  else {
    const dec = abs >= 1000 ? 2 : abs >= 1 ? 4 : 8;
    s = (Math.round(x * 10 ** dec) / 10 ** dec).toString();
    if (s.includes("e")) s = x.toPrecision(10);
    const [int, frac] = s.split(".");
    const sign = int.startsWith("-") ? "-" : "";
    const digits = int.replace("-", "");
    const sep = style === "dot" ? "." : style === "space" ? " " : ",";
    const decSep = style === "dot" || style === "space" ? "," : ".";
    const grouped = digits.replace(/\B(?=(\d{3})+(?!\d))/g, sep);
    s = sign + grouped + (frac ? decSep + frac : "");
  }
  if (val.pct) return s + " %";
  if (val.unit) return s + " " + (val.unit === "C" ? "°C" : val.unit === "F" ? "°F" : val.unit);
  return s;
}
export function plainValue(val) {
  const x = val.pct ? val.v * 100 : displayNumber(val);
  return String(Math.round(x * 1e10) / 1e10);
}
