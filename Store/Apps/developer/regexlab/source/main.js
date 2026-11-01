// Regex Lab for Nexvyn OS: write a regular expression and watch it work. Matches and capture groups are highlighted
// live in your test text, with a list of every match, replace and split previews, a plain-language explanation of the
// pattern, a reference you can tap to insert tokens, and a library of saved and ready-made patterns.
import * as K from "./kit.js";

const { clamp, alpha, mix, ellipsize } = K;

// ================================================================== state
let pattern = "", flags = "g", lines = [""], replaceWith = "";
let library = [];
let tab = 0;                       // 0 matches, 1 replace, 2 split, 3 explain, 4 reference
let narrowPane = 0;                // narrow windows: 0 text, 1 results
let editLine = -1, editText = "";
let lineCursor = 0;
let patSnap = null, lineSnap = null, repSnap = null;
const hist = new K.History(100);
const textScroll = new K.Scroller(), panelScroll = new K.Scroller();
let textRect = [0, 0, 0, 0], panelRect = [0, 0, 0, 0];
let result = { key: null };
let dirty = false, changedAt = 0;
let libOpen = null;                // library sheet {q, t}
let selMatch = -1;
let lineTops = [];

const FLAGS = ["g", "i", "m", "s", "u", "y"];
const FLAG_KEYS = { g: "flag_g", i: "flag_i", m: "flag_m", s: "flag_s", u: "flag_u", y: "flag_y" };
const GROUP_COLORS = ["blue", "green", "orange", "purple", "pink", "red", "yellow"];
const MAX_TEXT = 20000;

const EXAMPLES = [
  { key: "ex_email", pattern: "[\\w.+-]+@[\\w-]+\\.[\\w.-]+", flags: "g", text: "Write to info@example.com or sales.team@shop.co.uk\nnot-an-email@ and @nobody" },
  { key: "ex_url", pattern: "https?:\\/\\/[\\w.-]+(?:\\/[\\w\\/.%-]*)?(?:\\?[\\w=&%-]*)?", flags: "g", text: "Docs: https://example.com/guide/start?lang=en\nOld site http://old.example.org and ftp://files.example.org" },
  { key: "ex_ipv4", pattern: "\\b(?:(?:25[0-5]|2[0-4]\\d|1?\\d?\\d)\\.){3}(?:25[0-5]|2[0-4]\\d|1?\\d?\\d)\\b", flags: "g", text: "Router 192.168.1.1, DNS 8.8.8.8\nNot valid: 256.1.1.1 and 10.0.0" },
  { key: "ex_date", pattern: "(?<year>\\d{4})-(?<month>0[1-9]|1[0-2])-(?<day>0[1-9]|[12]\\d|3[01])", flags: "g", text: "Released 2026-10-30, patched 2026-11-01.\nWrong: 2026-13-01 and 26-1-1" },
  { key: "ex_time", pattern: "\\b([01]?\\d|2[0-3]):([0-5]\\d)\\b", flags: "g", text: "Meeting at 9:30, lunch 12:45, train 23:59\nNot a time: 24:00 or 7:60" },
  { key: "ex_hex", pattern: "#(?:[0-9a-fA-F]{3}){1,2}\\b", flags: "g", text: "Accent #007AFF, text #333, error #FF3B30\nNot a colour: #12345 or #GGG" },
  { key: "ex_hashtag", pattern: "(?<!\\w)#(\\w+)", flags: "g", text: "Loving the new #homebrew build! #switch #retro\nissue#42 is not a tag" },
  { key: "ex_number", pattern: "-?\\d{1,3}(?:[,.]\\d{3})*(?:[.,]\\d+)?", flags: "g", text: "Total: 1,234.56 items, -42 left, 3.14 pi\nPrice 1.000,50 €" },
  { key: "ex_repeat", pattern: "\\b(\\w+)\\s+\\1\\b", flags: "gi", text: "This is is a test of the the repeated words.\nNo doubles here." },
  { key: "ex_trailing", pattern: "[ \\t]+$", flags: "gm", text: "line with spaces   \nclean line\ntabs at the end\t\t" },
];

const REFERENCE = [
  ["cat_chars", [[".", "x_dot"], ["\\d", "x_digit"], ["\\w", "x_word"], ["\\s", "x_space"], ["\\D", "x_ndigit"], ["\\W", "x_nword"], ["\\S", "x_nspace"], ["[abc]", "x_set"], ["[^abc]", "x_nset"], ["[a-z]", "x_range"]]],
  ["cat_anchors", [["^", "x_start"], ["$", "x_end"], ["\\b", "x_wordb"], ["\\B", "x_nwordb"]]],
  ["cat_quant", [["*", "x_star"], ["+", "x_plus"], ["?", "x_opt"], ["{3}", "x_exact"], ["{2,}", "x_atleast"], ["{2,5}", "x_between"], ["*?", "x_lazy"]]],
  ["cat_groups", [["(…)", "x_group"], ["(?:…)", "x_ncgroup"], ["(?<name>…)", "x_named"], ["\\1", "x_backref"], ["a|b", "x_alt"], ["(?=…)", "x_ahead"], ["(?!…)", "x_nahead"], ["(?<=…)", "x_behind"], ["(?<!…)", "x_nbehind"]]],
  ["cat_escapes", [["\\t", "x_tab"], ["\\n", "x_newline"], ["\\.", "x_literal"], ["\\u00E9", "x_unicode"]]],
];

const markDirty = () => { dirty = true; changedAt = sys.time(); };
const snapshot = () => ({ pattern, flags, lines: lines.slice(), replaceWith });
function restore(s) { pattern = s.pattern; flags = s.flags; lines = s.lines.slice(); replaceWith = s.replaceWith; editLine = -1; markDirty(); }
function pushHist() { hist.push(snapshot()); }
function undo() { stopEdit(); const s = hist.undo(snapshot()); if (s) { restore(s); K.toast(TR("undone"), "undo"); } }
function redo() { stopEdit(); const s = hist.redo(snapshot()); if (s) { restore(s); K.toast(TR("redone"), "redo"); } }

function save() {
  store.set("session", { pattern, flags, lines, replaceWith, tab });
  store.set("library", library);
  dirty = false;
}

// ================================================================== matching
// nested quantifiers like (a+)+ can take ages on long text: they are only tried on the start of the text
const risky = (p) => /\((?:[^()\\]|\\.)*[+*](?:[^()\\]|\\.)*\)[+*{]/.test(p);

function compute() {
  const text = lines.join("\n");
  const key = pattern + "\u0000" + flags + "\u0000" + text;
  if (result.key === key) return result;
  const r = { key, error: null, matches: [], truncated: false, slow: false, groupNames: [], replaced: null, parts: null, ms: 0 };
  result = r;
  if (!pattern) return r;
  let re;
  try { re = new RegExp(pattern, flags); } catch (e) { r.error = String(e.message || e).replace(/^SyntaxError:\s*/, ""); return r; }
  let hay = text.length > MAX_TEXT ? text.slice(0, MAX_TEXT) : text;
  if (risky(pattern) && hay.length > 300) { hay = hay.slice(0, 300); r.slow = true; }
  let ri;
  try { ri = new RegExp(pattern, flags.replace(/[gy]/g, "") + "gd"); } catch (e) { ri = new RegExp(pattern, flags.replace(/[gy]/g, "") + "g"); }
  const global = flags.includes("g");
  const sticky = flags.includes("y");
  if (sticky) { try { ri = new RegExp(pattern, flags.replace("g", "") + "d" + (global ? "g" : "")); } catch (e) { ri = new RegExp(pattern, flags); } }
  const t0 = Date.now();
  ri.lastIndex = 0;
  let m;
  while ((m = ri.exec(hay)) !== null) {
    const groups = [];
    for (let i = 1; i < m.length; i++) {
      const ind = m.indices && m.indices[i];
      groups.push({ text: m[i], start: ind ? ind[0] : -1, end: ind ? ind[1] : -1 });
    }
    r.matches.push({ start: m.index, end: m.index + m[0].length, text: m[0], groups, names: m.groups ? Object.keys(m.groups) : [] });
    if (m[0].length === 0) ri.lastIndex++;
    if (!global || (sticky && !global)) break;
    if (r.matches.length >= 1000 || Date.now() - t0 > 400) { r.truncated = true; break; }
  }
  r.ms = Date.now() - t0;
  // names of the groups in pattern order
  const names = [];
  const rx = /\(\?<([A-Za-z_$][\w$]*)>/g;
  let nm;
  while ((nm = rx.exec(pattern)) !== null) names.push(nm[1]);
  r.groupNames = names;
  try { r.replaced = hay.replace(re, replaceWith); } catch (e) { r.replaced = null; }
  try { r.parts = hay.split(new RegExp(pattern, flags.replace(/[gy]/g, "")), 500); } catch (e) { r.parts = null; }
  return r;
}

// ================================================================== explanation
function explain(p) {
  const out = [];
  let i = 0, depth = 0;
  const add = (tok, key, ...args) => out.push({ tok, text: TR(key, ...args), depth });
  const quant = () => {
    const rest = p.slice(i);
    let m = rest.match(/^(\*|\+|\?|\{(\d+)(,(\d*))?\})(\??)/);
    if (!m) return;
    const lazy = m[5] === "?";
    let key, args = [];
    if (m[1] === "*") key = "q_star";
    else if (m[1] === "+") key = "q_plus";
    else if (m[1] === "?") key = "q_opt";
    else if (m[3] === undefined) { key = "q_exact"; args = [m[2]]; }
    else if (m[4] === "") { key = "q_atleast"; args = [m[2]]; }
    else { key = "q_between"; args = [m[2], m[4]]; }
    out.push({ tok: m[0], text: TR(key, ...args) + (lazy ? " · " + TR("q_lazy") : ""), depth: depth + 1, quant: true });
    i += m[0].length;
  };
  const ESC = { d: "e_digit", D: "e_ndigit", w: "e_word", W: "e_nword", s: "e_space", S: "e_nspace", b: "e_wordb", B: "e_nwordb",
    n: "e_newline", t: "e_tab", r: "e_cr", f: "e_ff", v: "e_vt", "0": "e_null" };
  while (i < p.length) {
    const c = p[i];
    if (c === "\\") {
      const n = p[i + 1] ?? "";
      let m;
      if (ESC[n]) { add("\\" + n, ESC[n]); i += 2; }
      else if ((m = p.slice(i).match(/^\\([1-9]\d*)/))) { add(m[0], "e_backref", m[1]); i += m[0].length; }
      else if ((m = p.slice(i).match(/^\\k<([^>]+)>/))) { add(m[0], "e_backref", m[1]); i += m[0].length; }
      else if ((m = p.slice(i).match(/^\\u\{?([0-9a-fA-F]{4,6})\}?/))) { add(m[0], "e_unicode", String.fromCodePoint(parseInt(m[1], 16))); i += m[0].length; }
      else if ((m = p.slice(i).match(/^\\x([0-9a-fA-F]{2})/))) { add(m[0], "e_unicode", String.fromCharCode(parseInt(m[1], 16))); i += m[0].length; }
      else if ((m = p.slice(i).match(/^\\[pP]\{([^}]+)\}/))) { add(m[0], m[0][1] === "p" ? "e_prop" : "e_nprop", m[1]); i += m[0].length; }
      else { add("\\" + n, "e_literal", n); i += 2; }
      quant();
    } else if (c === "[") {
      let j = i + 1;
      if (p[j] === "^") j++;
      if (p[j] === "]") j++;
      while (j < p.length && p[j] !== "]") { if (p[j] === "\\") j++; j++; }
      const body = p.slice(i, j + 1);
      const neg = body[1] === "^";
      add(body, neg ? "c_nset" : "c_set", body.slice(neg ? 2 : 1, -1));
      i = j + 1;
      quant();
    } else if (c === "(") {
      let m, tok = "(", key = "g_capture", arg;
      const rest = p.slice(i);
      if (rest.startsWith("(?:")) { tok = "(?:"; key = "g_noncap"; }
      else if (rest.startsWith("(?=")) { tok = "(?="; key = "g_ahead"; }
      else if (rest.startsWith("(?!")) { tok = "(?!"; key = "g_nahead"; }
      else if (rest.startsWith("(?<=")) { tok = "(?<="; key = "g_behind"; }
      else if (rest.startsWith("(?<!")) { tok = "(?<!"; key = "g_nbehind"; }
      else if ((m = rest.match(/^\(\?<([^>]+)>/))) { tok = m[0]; key = "g_named"; arg = m[1]; }
      add(tok, key, arg);
      depth++;
      i += tok.length;
    } else if (c === ")") {
      depth = Math.max(0, depth - 1);
      add(")", "g_end");
      i++;
      quant();
    } else if (c === "|") { add("|", "o_alt"); i++; }
    else if (c === "^") { add("^", "a_start"); i++; }
    else if (c === "$") { add("$", "a_end"); i++; }
    else if (c === ".") { add(".", "c_dot"); i++; quant(); }
    else {
      // a run of literal characters
      let j = i;
      while (j < p.length && !"\\[]()|^$.*+?{}".includes(p[j])) j++;
      if (j === i) j = i + 1;
      let lit = p.slice(i, j);
      // a quantifier binds to the last character only
      if (j < p.length && "*+?{".includes(p[j]) && lit.length > 1) { lit = lit.slice(0, -1); j--; }
      add(lit, "l_text", lit);
      i = j;
      quant();
    }
  }
  return out;
}

// ================================================================== editing the test text
function stopEdit() {
  editLine = -1;
  lineSnap = null;
  if (K.K.editing === "tl") K.blur();
}
function startEdit(i) {
  if (!lines.length) lines = [""];
  i = clamp(i, 0, lines.length - 1);
  editLine = i;
  editText = lines[i];
  lineCursor = i;
  lineSnap = snapshot();
  K.focus("tl");
}
function setLine(t) {
  if (editLine < 0 || t === editText) return;
  if (lineSnap) { hist.push(lineSnap); lineSnap = null; }
  editText = t;
  lines[editLine] = t;
  markDirty();
}
function enterLine() {
  if (editLine < 0) return;
  if (lineSnap) { hist.push(lineSnap); lineSnap = null; }
  lines.splice(editLine + 1, 0, "");
  markDirty();
  startEdit(editLine + 1);
  lineSnap = null;
}
function backLine() {
  if (editLine < 0 || editText !== "" || lines.length <= 1) return false;
  if (lineSnap) { hist.push(lineSnap); lineSnap = null; }
  lines.splice(editLine, 1);
  markDirty();
  startEdit(Math.max(0, editLine - 1));
  lineSnap = null;
  return true;
}
function setText(t, toast) {
  pushHist();
  lines = String(t ?? "").replace(/\r\n?/g, "\n").split("\n");
  if (!lines.length) lines = [""];
  editLine = -1;
  markDirty();
  if (toast) K.toast(toast, "content_paste");
}
function insertToken(tok) {
  pushHist();
  pattern += tok.replace("…", "");
  markDirty();
  K.toast(TR("inserted", tok), "add");
}
function setFlag(f) {
  pushHist();
  flags = flags.includes(f) ? flags.replace(f, "") : flags + f;
  flags = FLAGS.filter((x) => flags.includes(x)).join("");
  markDirty();
}
function loadEntry(e, name) {
  stopEdit();
  pushHist();
  pattern = e.pattern;
  flags = e.flags || "";
  if (e.text !== undefined) lines = String(e.text).split("\n");
  markDirty();
  libOpen = null;
  K.toast(TR("loaded", name), "bookmark");
}
function saveToLibrary() {
  if (!pattern) { K.toast(TR("nothing_to_save"), "error"); return; }
  ui.prompt(TR("save_pattern"), TR("save_pattern_msg"), "", (name) => {
    if (!name || !name.trim()) return;
    library.unshift({ name: name.trim(), pattern, flags, text: lines.join("\n") });
    save();
    K.toast(TR("saved_to_library"), "bookmark_add");
  });
}
function copyAs(kind) {
  let s;
  if (kind === "js") s = "/" + pattern.replace(/\//g, "\\/") + "/" + flags;
  else if (kind === "py") {
    const pf = [];
    if (flags.includes("i")) pf.push("re.IGNORECASE");
    if (flags.includes("m")) pf.push("re.MULTILINE");
    if (flags.includes("s")) pf.push("re.DOTALL");
    s = `re.compile(r"${pattern.replace(/"/g, '\\"').replace(/\(\?<([A-Za-z_]\w*)>/g, "(?P<$1>")}"${pf.length ? ", " + pf.join(" | ") : ""})`;
  } else s = pattern;
  sys.clipboard(s);
  K.toast(TR("copied"), "content_copy");
}
function exportSession() {
  ui.saveFile((p) => {
    if (!p) return;
    if (!/\.json$/i.test(p)) p += ".json";
    const d = { app: "regexlab", version: 1, current: { pattern, flags, text: lines.join("\n"), replace: replaceWith }, library };
    K.toast(fs.write(p, json.encode(d, true)) ? TR("exported") : TR("write_failed"), "ios_share");
  }, "regexlab.json", TR("export"));
}
function importSession(path) {
  const d = json.decode(fs.read(path) || "");
  if (!d || d.app !== "regexlab") {
    // a plain text file becomes the test text
    const t = fs.read(path);
    if (t !== null && t !== undefined) setText(String(t).slice(0, MAX_TEXT), TR("text_loaded"));
    else K.toast(TR("read_failed"), "error");
    return;
  }
  pushHist();
  if (d.current) {
    pattern = String(d.current.pattern || ""); flags = String(d.current.flags || "");
    lines = String(d.current.text || "").split("\n"); replaceWith = String(d.current.replace || "");
  }
  if (Array.isArray(d.library)) {
    for (const e of d.library) if (e && e.pattern !== undefined && !library.some((x) => x.name === e.name)) library.push(e);
  }
  markDirty();
  K.toast(TR("imported"), "file_download");
}

// ================================================================== text view with highlights
const cwCache = new Map();
function charW(ch) {
  let w = cwCache.get(ch);
  if (w === undefined) { w = gfx.textWidth(ch, 14, "mono"); cwCache.set(ch, w); }
  return w;
}
// wrap points of a line (code-unit offsets where a visual row starts)
function wrapLine(line, width) {
  const rows = [0];
  let x = 0;
  for (let i = 0; i < line.length;) {
    const cp = line.codePointAt(i);
    const ch = String.fromCodePoint(cp);
    const w = charW(ch);
    if (x + w > width && x > 0) { rows.push(i); x = 0; }
    x += w;
    i += ch.length;
  }
  return rows;
}
function xOf(line, from, to) { return gfx.textWidth(line.slice(from, to), 14, "mono"); }

function drawText(x, y, w, h, r) {
  const pad = 12, numW = 34;
  const lh = 22;
  const tw = w - pad * 2 - numW;
  textRect = [x, y, w, h];
  // layout
  let total = 8;
  const layout = [];
  let offset = 0;
  for (let i = 0; i < lines.length; i++) {
    const rows = i === editLine ? [0] : wrapLine(lines[i], tw);
    const hh = i === editLine ? 38 : rows.length * lh + 4;
    layout.push({ top: total, h: hh, rows, start: offset });
    total += hh;
    offset += lines[i].length + 1;
  }
  lineTops = layout.map((l) => l.top);
  total += 80;
  textScroll.setMax(total - h);
  gfx.clip(x, y, w, h);
  const oy = y - textScroll.y;
  const matches = r.matches;
  let todo = null;
  for (let i = 0; i < lines.length; i++) {
    const L = layout[i];
    if (L.top + L.h < textScroll.y - 20 || L.top > textScroll.y + h + 20) continue;
    const ly = oy + L.top;
    gfx.color(theme.text3);
    gfx.text(String(i + 1), x + 4, ly + 4, 12, "mono", "right", numW - 8);
    if (i === editLine) {
      const nt = K.field("tl", editText, x + numW + pad - 6, ly + 2, tw + 12, 34, TR("line_ph"));
      if (nt !== editText && editLine === i) setLine(nt);
      if (ui.submitted("tl") && editLine === i) todo = enterLine;
      continue;
    }
    const hit = ui.hit("ln" + i, x + numW, ly, w - numW, L.h);
    if (hit.hovered || (i === lineCursor && editLine < 0 && !K.K.editing)) gfx.rect(x + numW + 2, ly, w - numW - 4, L.h, 6, alpha(theme.text, 0.035));
    const line = lines[i];
    const ls = L.start, le = ls + line.length;
    // match backgrounds, then group underlines
    for (let mi = 0; mi < matches.length; mi++) {
      const m = matches[mi];
      if (m.end < ls || m.start > le) continue;
      if (m.start > le) break;
      const segs = [[m.start, m.end, mi === selMatch ? alpha(theme.accent, 0.45) : alpha(theme.yellow, theme.dark ? 0.35 : 0.45), 0]];
      m.groups.forEach((g, gi) => { if (g.start >= 0 && g.end > g.start) segs.push([g.start, g.end, theme[GROUP_COLORS[gi % GROUP_COLORS.length]], 1]); });
      for (const [s0, s1, col, kind] of segs) {
        const a = Math.max(s0, ls) - ls, b = Math.min(s1, le) - ls;
        if (b < a) continue;
        for (let ri = 0; ri < L.rows.length; ri++) {
          const rs = L.rows[ri], re2 = ri + 1 < L.rows.length ? L.rows[ri + 1] : line.length;
          const sa = Math.max(a, rs), sb = Math.min(b, re2);
          if (sb < sa || (sb === sa && !(m.start === m.end))) continue;
          const sx = x + numW + pad + xOf(line, rs, sa);
          const sw = Math.max(sb > sa ? xOf(line, sa, sb) : 2, 2);
          const ry = ly + 2 + ri * lh;
          if (kind === 0) gfx.rect(sx, ry, sw, lh - 2, 4, col);
          else gfx.rect(sx, ry + lh - 5, sw, 3, 1.5, col);
        }
      }
    }
    gfx.color(theme.text);
    for (let ri = 0; ri < L.rows.length; ri++) {
      const rs = L.rows[ri], re2 = ri + 1 < L.rows.length ? L.rows[ri + 1] : line.length;
      gfx.text(line.slice(rs, re2), x + numW + pad, ly + 4 + ri * lh, 14, "mono");
    }
    if (line === "" && lines.length === 1) { gfx.color(theme.text3); gfx.text(TR("text_ph"), x + numW + pad, ly + 4, 14, "italic"); }
    if (hit.clicked && !textScroll.dragged() && !todo) todo = () => startEdit(i);
  }
  // tap below the text: a new line
  const endY = oy + total - 80;
  const eh = ui.hit("textend", x + numW, endY, w - numW, 70);
  if (eh.hovered && editLine < 0) { gfx.color(theme.text3); gfx.text(TR("tap_to_add"), x + numW + pad, endY + 8, 13, "italic"); }
  if (todo) todo();
  else if (eh.clicked && !textScroll.dragged()) {
    if (lines[lines.length - 1] !== "") { pushHist(); lines.push(""); markDirty(); }
    startEdit(lines.length - 1);
  }
  gfx.unclip();
  textScroll.bar(x + w - 6, y + 4, h - 8);
}

// ================================================================== results panel
function drawPanel(x, y, w, h, r) {
  gfx.rect(x, y, w, h, 0, theme.sidebar);
  const tabs = [TR("t_matches"), TR("t_replace"), TR("t_split"), TR("t_explain"), TR("t_reference")];
  const nt = ui.segmented("ptab", w < 420 ? tabs.map((t) => Array.from(t)[0]) : tabs, tab, x + 10, y + 10, w - 20, 30);
  if (nt !== tab) { tab = nt; panelScroll.to(0, true); markDirty(); }
  const cy = y + 50, ch = h - 50;
  panelRect = [x, cy, w, ch];
  gfx.clip(x, cy, w, ch);
  const oy = cy - panelScroll.y;
  const p = 12;
  let yy = oy + 4;
  const iw = w - p * 2;
  if (tab === 0) {
    if (r.error) { gfx.color(theme.red); yy += gfx.wrap(TR("invalid", r.error), x + p, yy, iw, 13) + 8; }
    else if (!pattern) { K.empty("manage_search", TR("no_pattern"), TR("no_pattern_hint"), x, cy, w, ch); }
    else if (!r.matches.length) { K.empty("search_off", TR("no_matches"), TR("no_matches_hint"), x, cy, w, ch); }
    if (r.slow) { gfx.color(theme.orange); yy += gfx.wrap(TR("slow_warning"), x + p, yy, iw, 12) + 8; }
    for (let i = 0; i < r.matches.length; i++) {
      const m = r.matches[i];
      const gh = m.groups.length * 22;
      const bh = 52 + gh;
      if (yy + bh > cy - 10 && yy < cy + ch + 10) {
        const hit = ui.hit("m" + i, x + 8, yy, w - 16, bh);
        gfx.rect(x + 8, yy, w - 16, bh, 10, i === selMatch ? alpha(theme.accent, 0.15) : hit.hovered ? theme.hover : alpha(theme.text, 0.04));
        gfx.color(theme.text2);
        gfx.text(TR("match_n", i + 1, m.start, m.end), x + p + 4, yy + 6, 11, "medium");
        gfx.color(theme.text);
        gfx.text(ellipsize(m.text === "" ? TR("empty_match") : JSON.stringify(m.text).slice(1, -1), 14, "mono", iw - 8), x + p + 4, yy + 24, 14, "mono");
        m.groups.forEach((g, gi) => {
          const gy = yy + 48 + gi * 22;
          gfx.circle(x + p + 10, gy + 8, 4, theme[GROUP_COLORS[gi % GROUP_COLORS.length]]);
          gfx.color(theme.text2);
          const name = r.groupNames.length && m.names.length ? (gi < r.groupNames.length ? r.groupNames[gi] : String(gi + 1)) : String(gi + 1);
          gfx.text(name, x + p + 20, gy, 12, "medium");
          gfx.color(g.text === undefined ? theme.text3 : theme.text);
          gfx.text(ellipsize(g.text === undefined ? TR("not_matched") : g.text, 13, "mono", iw - 90), x + p + 84, gy, 13, "mono");
        });
        if (hit.clicked && !panelScroll.dragged()) {
          selMatch = i === selMatch ? -1 : i;
          // show the match in the text
          const lineIdx = lines.join("\n").slice(0, m.start).split("\n").length - 1;
          if (lineTops[lineIdx] !== undefined) textScroll.reveal(lineTops[lineIdx], lineTops[lineIdx] + 40, textRect[3]);
        }
      }
      yy += bh + 6;
    }
    if (r.truncated) { gfx.color(theme.orange); gfx.text(TR("truncated"), x + p, yy, 12); yy += 24; }
  } else if (tab === 1) {
    gfx.color(theme.text2);
    gfx.text(TR("replace_with"), x + p, yy, 12, "medium");
    yy += 18;
    const nrep = K.field("rep", replaceWith, x + p, yy, iw, 32, TR("replace_ph"));
    if (nrep !== replaceWith) { if (!repSnap) { repSnap = snapshot(); hist.push(repSnap); } replaceWith = nrep; markDirty(); }
    yy += 40;
    gfx.color(theme.text3);
    yy += gfx.wrap(TR("replace_hint"), x + p, yy, iw, 12) + 10;
    if (r.replaced !== null && r.replaced !== undefined && !r.error) {
      const bw = Math.floor((iw - 6) / 2);
      if (ui.button(TR("copy_result"), x + p, yy, bw, 30, "default", "content_copy")) { sys.clipboard(r.replaced); K.toast(TR("copied"), "content_copy"); }
      if (ui.button(TR("use_result"), x + p + bw + 6, yy, bw, 30, "default", "south")) setText(r.replaced, TR("result_used"));
      yy += 40;
      K.heading(TR("result"), x + p, yy, iw);
      yy += 20;
      gfx.rect(x + 8, yy, w - 16, 10, 10, alpha(theme.text, 0.04));
      const startY = yy;
      for (const ln of r.replaced.split("\n").slice(0, 400)) {
        const hh = gfx.measureWrap(ln || " ", iw - 8, 13, "mono");
        if (yy + hh > cy - 20 && yy < cy + ch) { gfx.color(theme.text); gfx.wrap(ln || " ", x + p + 4, yy + 4, iw - 8, 13, "mono"); }
        yy += hh + 2;
      }
      gfx.color(alpha(theme.text, 0.06));
      gfx.rectLine(x + 8, startY, w - 16, yy - startY + 8, 10, 1);
      yy += 12;
    }
  } else if (tab === 2) {
    if (r.parts && !r.error && pattern) {
      gfx.color(theme.text2);
      gfx.text(TR("parts_n", r.parts.length), x + p, yy, 12, "medium");
      yy += 22;
      r.parts.forEach((part, i) => {
        if (yy > cy - 40 && yy < cy + ch) {
          gfx.rect(x + 8, yy, w - 16, 30, 8, alpha(theme.text, 0.04));
          gfx.color(theme.text3);
          gfx.text(String(i), x + p, yy + 7, 12, "mono", "right", 22);
          gfx.color(part === undefined ? theme.text3 : theme.text);
          gfx.text(ellipsize(part === undefined ? TR("not_matched") : (part === "" ? "∅" : JSON.stringify(part).slice(1, -1)), 13, "mono", iw - 40), x + p + 32, yy + 7, 13, "mono");
        }
        yy += 34;
      });
    } else K.empty("call_split", TR("no_split"), null, x, cy, w, ch);
  } else if (tab === 3) {
    if (!pattern) K.empty("school", TR("no_pattern"), TR("explain_hint"), x, cy, w, ch);
    else {
      if (r.error) { gfx.color(theme.red); yy += gfx.wrap(TR("invalid", r.error), x + p, yy, iw, 13) + 8; }
      const toks = cacheExplain();
      for (const t of toks) {
        const ind = Math.min(t.depth, 5) * 14;
        const tokW = Math.min(110, Math.max(36, gfx.textWidth(t.tok, 13, "monobold") + 14));
        const th = Math.max(26, gfx.measureWrap(t.text, iw - ind - tokW - 10, 12) + 8);
        if (yy + th > cy - 10 && yy < cy + ch) {
          gfx.rect(x + p + ind, yy, tokW, 24, 6, t.quant ? alpha(theme.purple, 0.18) : alpha(theme.accent, 0.14));
          gfx.color(t.quant ? theme.purple : theme.accent);
          gfx.text(ellipsize(t.tok, 13, "monobold", tokW - 10), x + p + ind + 5, yy + 4, 13, "monobold");
          gfx.color(theme.text);
          gfx.wrap(t.text, x + p + ind + tokW + 8, yy + 4, iw - ind - tokW - 10, 12);
        }
        yy += th + 4;
      }
    }
  } else {
    gfx.color(theme.text3);
    yy += gfx.wrap(TR("reference_hint"), x + p, yy, iw, 12) + 10;
    for (const [cat, items] of REFERENCE) {
      K.heading(TR(cat), x + p, yy, iw);
      yy += 22;
      for (const [tok, key] of items) {
        if (yy > cy - 40 && yy < cy + ch) {
          const hit = ui.hit("ref" + tok + key, x + 8, yy, w - 16, 30);
          if (hit.hovered) gfx.rect(x + 8, yy, w - 16, 30, 8, theme.hover);
          gfx.rect(x + p, yy + 3, 84, 24, 6, alpha(theme.accent, 0.14));
          gfx.color(theme.accent);
          gfx.text(tok, x + p + 6, yy + 7, 13, "monobold");
          gfx.color(theme.text);
          gfx.text(ellipsize(TR(key), 13, "sans", iw - 100), x + p + 94, yy + 7, 13);
          if (hit.clicked && !panelScroll.dragged()) insertToken(tok);
        }
        yy += 32;
      }
      yy += 8;
    }
  }
  panelScroll.setMax(yy - oy + 20 - ch);
  gfx.unclip();
  panelScroll.bar(x + w - 6, cy + 4, ch - 8);
}

let explainKey = null, explainList = [];
function cacheExplain() {
  const k = pattern + "\u0000" + sys.lang();
  if (k !== explainKey) { explainKey = k; try { explainList = explain(pattern); } catch (e) { explainList = []; } }
  return explainList;
}

// ================================================================== library sheet
function drawLibrary(w, h) {
  if (!libOpen) return;
  libOpen.t = Math.min(1, libOpen.t + 0.15);
  const [mx, my, cw, ch, outside] = K.modal("lib", w, h, 520, 480, libOpen.t);
  gfx.color(theme.text);
  gfx.text(TR("library"), mx + 18, my + 16, 18, "bold");
  if (ui.iconButton("close", mx + cw - 46, my + 10, 34, 32, theme.text2, false, "##lclose") || outside) { libOpen = null; return; }
  if (ui.button(TR("save_current"), mx + cw - 200, my + 10, 146, 32, "primary", "bookmark_add")) saveToLibrary();
  libOpen.q = K.field("lq", libOpen.q, mx + 16, my + 52, cw - 32, 32, TR("search_ph"), "search");
  const q = libOpen.q.trim().toLowerCase();
  const items = [];
  library.forEach((e, i) => { if (!q || e.name.toLowerCase().includes(q) || e.pattern.toLowerCase().includes(q)) items.push({ name: e.name, e, mine: i }); });
  for (const ex of EXAMPLES) {
    const name = TR(ex.key);
    if (!q || name.toLowerCase().includes(q) || ex.pattern.toLowerCase().includes(q)) items.push({ name, e: ex, mine: -1 });
  }
  const ly = my + 94, lh = ch - 104;
  ui.beginScroll("liblist", mx + 8, ly, cw - 16, lh, items.length * 56 + 30);
  let yy = 4;
  let lastMine = null;
  items.forEach((it, i) => {
    const mine = it.mine >= 0;
    if (lastMine !== mine) {
      K.heading(mine ? TR("my_patterns") : TR("examples"), 10, yy + 4, cw - 40);
      yy += 24;
      lastMine = mine;
    }
    const hit = ui.hit("li" + i, 0, yy, cw - 16, 52);
    gfx.rect(2, yy, cw - 20, 52, 10, hit.hovered ? theme.hover : alpha(theme.text, 0.04));
    gfx.icon(mine ? "bookmark" : "auto_awesome", 22, yy + 26, 18, mine ? theme.orange : theme.accent);
    gfx.color(theme.text);
    gfx.text(ellipsize(it.name, 14, "semibold", cw - 120), 42, yy + 7, 14, "semibold");
    gfx.color(theme.text2);
    gfx.text(ellipsize("/" + it.e.pattern + "/" + (it.e.flags || ""), 12, "mono", cw - 120), 42, yy + 28, 12, "mono");
    if (hit.clicked) loadEntry(it.e, it.name);
    if (mine && ui.iconButton("delete", cw - 60, yy + 10, 34, 32, theme.text3, false, "##ld" + i)) {
      ui.alert(TR("delete_pattern"), TR("delete_pattern_msg", it.name), [TR("delete"), TR("cancel")], (b) => {
        if (b === 0) { library.splice(it.mine, 1); save(); }
      });
    }
    yy += 56;
  });
  ui.endScroll();
}

// ================================================================== top area
function drawTop(w, r) {
  const p = 12;
  gfx.rect(0, 0, w, 104, 0, theme.window);
  gfx.color(theme.text);
  gfx.text(TR("app_name"), p, 14, 18, "bold");
  let right = w - p;
  const rb = (icon, id, enabled = true, tint) => {
    right -= 38;
    if (!enabled) { gfx.icon(icon, right + 18, 26, 20, theme.text3); return false; }
    return ui.iconButton(icon, right, 9, 36, 32, tint || theme.text2, false, id);
  };
  if (rb("more_horiz", "##more")) {
    ui.contextMenu([{ label: TR("copy_js"), id: 1, icon: "javascript" }, { label: TR("copy_py"), id: 2, icon: "code" },
      { label: TR("copy_plain"), id: 3, icon: "content_copy" }, "-", { label: TR("paste_text"), id: 4, icon: "content_paste" },
      { label: TR("keyboard_text"), id: 5, icon: "keyboard" }, { label: TR("open_text"), id: 6, icon: "folder_open" },
      { label: TR("clear_text"), id: 7, icon: "backspace" }, "-", { label: TR("export"), id: 8, icon: "ios_share" },
      { label: TR("import"), id: 9, icon: "file_download" }], (id) => app.onmenu(id));
  }
  if (rb("bookmarks", "##lib", true, theme.accent)) libOpen = { q: "", t: 0 };
  if (rb("redo", "##redo", hist.canRedo())) redo();
  if (rb("undo", "##undo", hist.canUndo())) undo();
  // status
  let status, scol;
  if (r.error) { status = TR("s_error"); scol = theme.red; }
  else if (!pattern) { status = TR("s_empty"); scol = theme.text3; }
  else { status = TR("s_matches", r.matches.length) + (r.truncated ? "+" : ""); scol = r.matches.length ? theme.green : theme.orange; }
  const sx = p + gfx.textWidth(TR("app_name"), 18, "bold") + 16;
  if (right - sx > 80) {
    gfx.circle(sx + 6, 26, 5, scol);
    gfx.color(scol);
    gfx.text(ellipsize(status + (r.ms > 20 ? "  ·  " + r.ms + " ms" : ""), 13, "medium", right - sx - 24), sx + 16, 18, 13, "medium");
  }
  // pattern row
  const py = 54;
  const flagW = Math.min(FLAGS.length * 34, Math.max(0, w - 360));
  gfx.color(theme.text3);
  gfx.text("/", p, py + 6, 18, "mono");
  const fw = w - p * 2 - 28 - flagW - 10;
  const np = K.field("pat", pattern, p + 16, py, fw, 34, TR("pattern_ph"));
  if (np !== pattern) {
    if (!patSnap) { patSnap = snapshot(); hist.push(patSnap); }
    pattern = np;
    selMatch = -1;
    markDirty();
  }
  if (K.K.editing !== "pat") patSnap = null;
  gfx.color(theme.text3);
  gfx.text("/", p + 20 + fw, py + 6, 18, "mono");
  const fx = p + 36 + fw;
  const per = Math.max(1, Math.floor(flagW / 34));
  FLAGS.slice(0, per).forEach((f, i) => {
    const on = flags.includes(f);
    const hit = ui.hit("flag" + f, fx + i * 34, py + 2, 30, 30);
    gfx.rect(fx + i * 34, py + 2, 30, 30, 8, on ? theme.accent : hit.hovered ? theme.hover : alpha(theme.text, 0.06));
    gfx.color(on ? "#FFFFFF" : theme.text2);
    gfx.text(f, fx + i * 34, py + 8, 14, "monobold", "center", 30);
    if (hit.clicked) { setFlag(f); K.toast(TR(FLAG_KEYS[f]) + (flags.includes(f) ? " ✓" : " ✗"), "flag"); }
  });
  if (r.error) {
    gfx.color(theme.red);
    gfx.rect(p + 16, py + 34, fw, 2, 1, theme.red);
  }
  gfx.color(theme.separator);
  gfx.line(0, 104, w, 104, 1);
  return 105;
}

// ================================================================== app callbacks
app.load = (arg) => {
  const s = store.get("session", null);
  if (s && typeof s === "object") {
    pattern = String(s.pattern ?? ""); flags = String(s.flags ?? "g");
    lines = Array.isArray(s.lines) && s.lines.length ? s.lines.map(String) : [""];
    replaceWith = String(s.replaceWith ?? ""); tab = clamp(Number(s.tab) || 0, 0, 4);
  } else {
    const ex = EXAMPLES[3];
    pattern = ex.pattern; flags = ex.flags; lines = ex.text.split("\n"); replaceWith = "$<day>.$<month>.$<year>";
  }
  const lib = store.get("library", []);
  library = Array.isArray(lib) ? lib.filter((e) => e && typeof e.pattern === "string").map((e) => ({ name: String(e.name || "?"), pattern: e.pattern, flags: String(e.flags || ""), text: String(e.text ?? "") })) : [];
  if (arg) app.open(arg);
};
app.open = (arg) => {
  if (typeof arg !== "string" || !arg) return;
  const m = arg.match(/^lib:(\d+)$/);
  if (m) { const e = library[Number(m[1])]; if (e) loadEntry(e, e.name); return; }
  if (arg.includes(":/")) importSession(arg);
  else setText(arg.slice(0, MAX_TEXT), TR("text_loaded"));
};

app.update = (dt) => {
  textScroll.update(dt);
  panelScroll.update(dt);
  if (editLine >= 0 && K.K.editing !== "tl") stopEdit();
  if (K.K.editing !== "rep") repSnap = null;
  if (dirty && sys.time() - changedAt > 1.2) save();
};

app.draw = (w, h) => {
  gfx.clear(theme.bg);
  const r = compute();
  const top = drawTop(w, r);
  const narrow = w < 760;
  if (narrow) {
    const np = ui.segmented("npane", [TR("test_text"), TR("results")], narrowPane, 10, top + 6, w - 20, 30);
    if (np !== narrowPane) { narrowPane = np; stopEdit(); }
    if (narrowPane === 0) { drawText(0, top + 42, w, h - top - 42, r); panelRect = [0, 0, 0, 0]; }
    else { drawPanel(0, top + 42, w, h - top - 42, r); textRect = [0, 0, 0, 0]; }
  } else {
    const pw = clamp(Math.floor(w * 0.4), 300, 460);
    drawText(0, top, w - pw, h - top, r);
    drawPanel(w - pw, top, pw, h - top, r);
    gfx.color(theme.separator);
    gfx.line(w - pw, top, w - pw, h, 1);
  }
  drawLibrary(w, h);
  K.drawToast(w, h);
  K.frameEnd();
};

app.event = (e) => {
  if (K.press(e)) { if (libOpen) libOpen = null; stopEdit(); return; }
  if (libOpen) { if (e.type === "keydown" && e.key === "escape") libOpen = null; return; }
  if (textScroll.event(e, textRect)) return;
  if (panelScroll.event(e, panelRect)) return;
  if (e.type !== "keydown") return;
  const k = e.key;
  if (e.ctrl) {
    if (k === "z") { if (e.shift) redo(); else undo(); }
    else if (k === "y") redo();
    else if (k === "l") libOpen = { q: "", t: 0 };
    else if (k === "s") saveToLibrary();
    else if (k === "f") K.focus("pat");
    else if (k === "e") exportSession();
    else if (k === "o") app.onmenu(6);
    else if (k === "j") copyAs("js");
    else if (k >= "1" && k <= "5") { tab = Number(k) - 1; panelScroll.to(0, true); }
    return;
  }
  if (K.K.editing === "tl" && editLine >= 0) {
    if (k === "up" && editLine > 0) startEdit(editLine - 1);
    else if (k === "down" && editLine < lines.length - 1) startEdit(editLine + 1);
    else if (k === "backspace") backLine();
    return;
  }
  if (K.K.editing) return;
  if (k === "up") { lineCursor = Math.max(0, lineCursor - 1); textScroll.reveal(lineTops[lineCursor] || 0, (lineTops[lineCursor] || 0) + 30, textRect[3]); }
  else if (k === "down") { lineCursor = Math.min(lines.length - 1, lineCursor + 1); textScroll.reveal(lineTops[lineCursor] || 0, (lineTops[lineCursor] || 0) + 30, textRect[3]); }
  else if (k === "enter") startEdit(lineCursor);
  else if (k === "tab") { tab = (tab + (e.shift ? 4 : 1)) % 5; panelScroll.to(0, true); }
  else if (k === "left") { selMatch = Math.max(-1, selMatch - 1); }
  else if (k === "right") { selMatch = Math.min(result.matches ? result.matches.length - 1 : -1, selMatch + 1); }
  else if (k === "/") K.focus("pat");
  else if (k === "l") libOpen = { q: "", t: 0 };
  else if (k >= "1" && k <= "5") { tab = Number(k) - 1; panelScroll.to(0, true); }
};

app.menu = () => [
  { title: TR("m_file"), items: [
    { label: TR("library"), id: 20, shortcut: "Ctrl+L" },
    { label: TR("save_current"), id: 21, shortcut: "Ctrl+S" },
    "-",
    { label: TR("open_text"), id: 6, shortcut: "Ctrl+O" },
    { label: TR("export"), id: 8, shortcut: "Ctrl+E" },
    { label: TR("import"), id: 9 },
  ] },
  { title: TR("m_edit"), items: [
    { label: TR("undo"), id: 10, shortcut: "Ctrl+Z" },
    { label: TR("redo"), id: 11, shortcut: "Ctrl+Y" },
    "-",
    { label: TR("copy_js"), id: 1, shortcut: "Ctrl+J" },
    { label: TR("copy_py"), id: 2 },
    { label: TR("copy_plain"), id: 3 },
    "-",
    { label: TR("paste_text"), id: 4 },
    { label: TR("keyboard_text"), id: 5 },
    { label: TR("clear_text"), id: 7 },
  ] },
  { title: TR("m_view"), items: [
    { label: TR("t_matches"), id: 30, shortcut: "Ctrl+1" },
    { label: TR("t_replace"), id: 31, shortcut: "Ctrl+2" },
    { label: TR("t_split"), id: 32, shortcut: "Ctrl+3" },
    { label: TR("t_explain"), id: 33, shortcut: "Ctrl+4" },
    { label: TR("t_reference"), id: 34, shortcut: "Ctrl+5" },
  ] },
];

app.onmenu = (id) => {
  if (id === 1) copyAs("js");
  else if (id === 2) copyAs("py");
  else if (id === 3) copyAs("plain");
  else if (id === 4) { const t = sys.clipboard(); if (t) setText(String(t).slice(0, MAX_TEXT), TR("pasted")); else K.toast(TR("clipboard_empty"), "content_paste"); }
  else if (id === 5) ui.keyboard(lines.join("\n"), (t) => { if (t !== null && t !== undefined) setText(t, TR("text_loaded")); }, TR("test_text"));
  else if (id === 6) ui.openFile((p) => { if (p) importSession(p); }, [".txt", ".log", ".csv", ".md", ".json"], TR("open_text"));
  else if (id === 7) setText("", TR("cleared"));
  else if (id === 8) exportSession();
  else if (id === 9) ui.openFile((p) => { if (p) importSession(p); }, [".json"], TR("import"));
  else if (id === 10) undo();
  else if (id === 11) redo();
  else if (id === 20) libOpen = { q: "", t: 0 };
  else if (id === 21) saveToLibrary();
  else if (id >= 30 && id <= 34) { tab = id - 30; panelScroll.to(0, true); }
};

app.search = (q) => {
  q = String(q || "").trim().toLowerCase();
  if (!q) return [];
  const out = [];
  library.forEach((e, i) => { if (out.length < 5 && (e.name.toLowerCase().includes(q) || e.pattern.toLowerCase().includes(q))) out.push({ title: e.name, subtitle: "/" + e.pattern + "/" + e.flags, icon: "manage_search", arg: "lib:" + i }); });
  return out;
};
app.suspend = () => { if (dirty) save(); };
app.autosave = () => { if (dirty) save(); };
app.unsaved = () => dirty;
app.close = () => { save(); store.save(); return true; };
