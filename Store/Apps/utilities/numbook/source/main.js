// Numbook for Nexvyn OS: a notepad that calculates. Write plain lines like "Rent: 1200", "20% of 350" or
// "5 km in mi" and the answer appears beside each line. Variables, totals, percentages, units and temperatures;
// several sheets, undo/redo, copy and text export. A calculator keypad for touch and controller.
import * as K from "./kit.js";
import { evalLine, formatValue, plainValue } from "./calc.js";

const { clamp, alpha, ellipsize } = K;

// ================================================================== state
let sheets = [];
let cur = null;
let editLine = -1, editText = "";
let lineCursor = 0;
let lineSnap = null;
const hist = new K.History(120);
let dirty = false, changedAt = 0;
let numStyle = "auto";
let showPad = false;
let narrowPane = "sheet";
let query = "";
const listScroll = new K.Scroller(), sheetScroll = new K.Scroller();
let listRect = [0, 0, 0, 0], sheetRect = [0, 0, 0, 0];
let lineTops = [];
let results = [], resultsKey = null;

const now = () => sys.epoch();
const markDirty = () => { dirty = true; changedAt = sys.time(); if (cur) cur.updated = now(); resultsKey = null; };
function style() {
  if (numStyle !== "auto") return numStyle;
  const l = sys.lang();
  return l === "tr" || l === "de" || l === "es" ? "dot" : l === "fr" ? "space" : "comma";
}

// ================================================================== sheets
function newSheet(title, lines) {
  return { id: now() * 1000 + Math.floor(Math.random() * 1000), title, lines: lines || [""], updated: now() };
}
function samples() {
  return [
    newSheet(TR("s1_title"), TR("s1_body").split("\n")),
    newSheet(TR("s2_title"), TR("s2_body").split("\n")),
    newSheet(TR("s3_title"), TR("s3_body").split("\n")),
  ];
}
function save() {
  store.set("sheets", sheets);
  store.set("prefs", { cur: cur ? cur.id : 0, style: numStyle, pad: showPad });
  dirty = false;
}
function compute() {
  const key = cur ? cur.lines.join("\n") + "\u0000" + style() : "";
  if (key === resultsKey) return results;
  resultsKey = key;
  results = [];
  if (!cur) return results;
  const vars = {};
  for (const l of cur.lines) results.push(evalLine(l, vars, results));
  return results;
}

// ================================================================== editing
const snapshot = () => ({ id: cur.id, title: cur.title, lines: cur.lines.slice() });
function restore(s) {
  const sh = sheets.find((x) => x.id === s.id);
  if (!sh) return;
  sh.title = s.title; sh.lines = s.lines.slice();
  cur = sh;
  editLine = -1;
  markDirty();
}
function pushHist() { if (cur) hist.push(snapshot()); }
function undo() { stopEdit(); if (!cur) return; const s = hist.undo(snapshot()); if (s) { restore(s); K.toast(TR("undone"), "undo"); } else K.toast(TR("nothing_undo"), "undo"); }
function redo() { stopEdit(); if (!cur) return; const s = hist.redo(snapshot()); if (s) { restore(s); K.toast(TR("redone"), "redo"); } else K.toast(TR("nothing_redo"), "redo"); }

function stopEdit() { editLine = -1; lineSnap = null; if (K.K.editing === "ln") K.blur(); }
function startEdit(i) {
  if (!cur) return;
  if (!cur.lines.length) cur.lines = [""];
  i = clamp(i, 0, cur.lines.length - 1);
  editLine = i; editText = cur.lines[i]; lineCursor = i;
  lineSnap = snapshot();
  K.focus("ln");
}
function setLine(t) {
  if (editLine < 0 || t === editText) return;
  if (lineSnap) { hist.push(lineSnap); lineSnap = null; }
  editText = t;
  cur.lines[editLine] = t;
  markDirty();
}
function enterLine() {
  if (editLine < 0) return;
  if (lineSnap) { hist.push(lineSnap); lineSnap = null; }
  cur.lines.splice(editLine + 1, 0, "");
  markDirty();
  const n = editLine + 1;
  startEdit(n);
  lineSnap = null;
}
function backLine() {
  if (editLine < 0 || editText !== "" || cur.lines.length <= 1) return;
  if (lineSnap) { hist.push(lineSnap); lineSnap = null; }
  cur.lines.splice(editLine, 1);
  markDirty();
  startEdit(Math.max(0, editLine - 1));
  lineSnap = null;
}
function insertText(t) {
  // keypad: adds to the end of the line being edited (or of the current line)
  const i = editLine >= 0 ? editLine : lineCursor;
  if (!cur || i < 0) return;
  if (editLine < 0) startEdit(i);
  if (lineSnap) { hist.push(lineSnap); lineSnap = null; }
  editText = (cur.lines[i] || "") + t;
  cur.lines[i] = editText;
  markDirty();
  K.focus("ln");
}

function addSheet() {
  const s = newSheet(TR("untitled_n", sheets.length + 1), [""]);
  sheets.unshift(s);
  cur = s;
  hist.clear();
  markDirty();
  narrowPane = "sheet";
  startEdit(0);
}
function deleteSheet(s) {
  ui.alert(TR("delete_title"), TR("delete_msg", s.title), [TR("delete"), TR("cancel")], (b) => {
    if (b !== 0) return;
    const i = sheets.indexOf(s);
    if (i >= 0) sheets.splice(i, 1);
    if (!sheets.length) sheets.push(newSheet(TR("untitled_n", 1), [""]));
    if (cur === s) { cur = sheets[0]; hist.clear(); }
    markDirty();
    audio.play("trash", 0.4);
  });
}
function sheetText(s, withResults) {
  if (!withResults) return s.lines.join("\n") + "\n";
  const vars = {}, rs = [];
  const out = [];
  for (const l of s.lines) {
    const r = evalLine(l, vars, rs);
    rs.push(r);
    out.push(r.kind === "value" && l.trim() ? `${l} = ${formatValue(r.value, style())}` : l);
  }
  return out.join("\n") + "\n";
}

// ================================================================== drawing: list
function filtered() {
  const q = query.trim().toLowerCase();
  const list = sheets.filter((s) => !q || s.title.toLowerCase().includes(q) || s.lines.some((l) => l.toLowerCase().includes(q)));
  return list.sort((a, b) => b.updated - a.updated);
}
function drawList(x, y, w, h) {
  gfx.rect(x, y, w, h, 0, theme.sidebar);
  const p = 12;
  gfx.color(theme.text);
  gfx.text(TR("app_name"), x + p, y + 14, 18, "bold");
  if (ui.iconButton("note_add", x + w - p - 34, y + 9, 34, 34, theme.accent, false, "##new")) addSheet();
  query = K.field("search", query, x + p, y + 50, w - p * 2, 32, TR("search_ph"), "search");
  const ly = y + 92, lh = h - 92;
  const list = filtered();
  listRect = [x, ly, w, lh];
  listScroll.setMax(list.length * 60 + 8 - lh);
  gfx.clip(x, ly, w, lh);
  list.forEach((s, i) => {
    const ry = ly + 4 + i * 60 - listScroll.y;
    if (ry < ly - 60 || ry > ly + lh) return;
    const hit = ui.hit("sh" + s.id, x + 6, ry, w - 12, 56);
    gfx.rect(x + 6, ry, w - 12, 56, 10, s === cur ? alpha(theme.accent, theme.dark ? 0.3 : 0.15) : hit.hovered ? theme.hover : alpha(theme.text, 0));
    gfx.color(theme.text);
    gfx.text(ellipsize(s.title, 14, "semibold", w - 40), x + 18, ry + 8, 14, "semibold");
    // the last result of the sheet as a preview
    const vars = {}, rs = [];
    let last = "";
    for (const l of s.lines.slice(0, 60)) { const r = evalLine(l, vars, rs); rs.push(r); if (r.kind === "value") last = formatValue(r.value, style()); }
    gfx.color(theme.text3);
    gfx.text(ellipsize(TR("lines_n", s.lines.filter((l) => l.trim()).length) + (last ? " · " + last : ""), 12, "sans", w - 40), x + 18, ry + 30, 12);
    if (hit.clicked && !listScroll.dragged()) { stopEdit(); cur = s; hist.clear(); narrowPane = "sheet"; sheetScroll.to(0, true); save(); }
    if (hit.rightClicked) {
      ui.contextMenu([{ label: TR("rename"), id: 1, icon: "edit" }, { label: TR("duplicate"), id: 2, icon: "content_copy" }, "-",
        { label: TR("delete"), id: 3, icon: "delete" }], (id) => {
        if (id === 1) ui.prompt(TR("rename"), TR("sheet_name"), s.title, (t) => { if (t && t.trim()) { s.title = t.trim(); markDirty(); } });
        else if (id === 2) { const c = newSheet(TR("copy_of", s.title), s.lines.slice()); sheets.unshift(c); markDirty(); }
        else if (id === 3) deleteSheet(s);
      });
    }
  });
  gfx.unclip();
  gfx.color(theme.separator); gfx.line(x + w - 1, y, x + w - 1, y + h, 1);
}

// ================================================================== drawing: sheet
function drawSheet(x, y, w, h, narrow) {
  if (!cur) { K.empty("calculate", TR("no_sheet"), null, x, y, w, h); return; }
  const rs = compute();
  // toolbar
  gfx.rect(x, y, w, 50, 0, theme.window);
  let bx = x + 10;
  if (narrow && ui.iconButton("arrow_back", bx, 8, 36, 34, theme.text2, false, "##back")) { stopEdit(); narrowPane = "list"; }
  if (narrow) bx += 42;
  let right = x + w - 10;
  const rb = (icon, id, enabled = true, active = false) => {
    right -= 38;
    if (!enabled) { gfx.icon(icon, right + 18, 25, 20, theme.text3); return false; }
    return ui.iconButton(icon, right, 8, 36, 34, active ? theme.accent : theme.text2, active, id);
  };
  if (rb("more_horiz", "##more")) {
    ui.contextMenu([{ label: TR("copy_all"), id: 1, icon: "content_copy" }, { label: TR("copy_results"), id: 2, icon: "functions" },
      { label: TR("export"), id: 3, icon: "ios_share" }, { label: TR("import"), id: 4, icon: "file_download" }, "-",
      { label: TR("rename"), id: 5, icon: "edit" }, { label: TR("delete_sheet"), id: 6, icon: "delete" }], (id) => app.onmenu(id));
  }
  if (rb("dialpad", "##pad", true, showPad)) { showPad = !showPad; markDirty(); }
  if (rb("redo", "##redo", hist.canRedo())) redo();
  if (rb("undo", "##undo", hist.canUndo() || !!lineSnap)) undo();
  gfx.color(theme.text);
  const th = ui.hit("title", bx, 8, Math.min(right - bx - 8, gfx.textWidth(cur.title, 17, "bold") + 16), 34);
  if (th.hovered) gfx.rect(bx, 8, Math.min(right - bx - 8, gfx.textWidth(cur.title, 17, "bold") + 16), 34, 8, theme.hover);
  gfx.text(ellipsize(cur.title, 17, "bold", right - bx - 24), bx + 8, 16, 17, "bold");
  if (th.clicked) ui.prompt(TR("rename"), TR("sheet_name"), cur.title, (t) => { if (t && t.trim()) { pushHist(); cur.title = t.trim(); markDirty(); } });
  gfx.color(theme.separator); gfx.line(x, 50, x + w, 50, 1);
  // lines
  const padH = showPad ? Math.min(230, Math.floor(h * 0.42)) : 0;
  const cy = y + 51, ch = h - 51 - padH - 40;
  sheetRect = [x, cy, w, ch];
  const lh = 38;
  const resW = Math.min(260, Math.floor(w * 0.36));
  const textW = w - resW - 60;
  lineTops = cur.lines.map((_, i) => i * lh);
  sheetScroll.setMax(cur.lines.length * lh + 90 - ch);
  gfx.clip(x, cy, w, ch);
  const oy = cy + 8 - sheetScroll.y;
  gfx.rect(x + w - resW - 16, cy, resW + 16, ch, 0, alpha(theme.accent, theme.dark ? 0.06 : 0.04));
  let todo = null;
  for (let i = 0; i < cur.lines.length; i++) {
    const ly = oy + i * lh;
    if (ly < cy - lh || ly > cy + ch) continue;
    const r = rs[i] || { kind: "blank" };
    gfx.color(theme.text3);
    gfx.text(String(i + 1), x + 4, ly + 10, 11, "mono", "right", 28);
    if (i === editLine) {
      const nt = K.field("ln", editText, x + 38, ly + 2, textW + 10, 34, TR("line_ph"));
      if (nt !== editText && editLine === i) setLine(nt);
      if (ui.submitted("ln") && editLine === i) todo = enterLine;
    } else {
      const hit = ui.hit("l" + i, x + 34, ly, textW + 20, lh);
      if (hit.hovered || (i === lineCursor && editLine < 0 && !K.K.editing)) gfx.rect(x + 34, ly + 1, w - 40, lh - 2, 6, alpha(theme.text, 0.04));
      const line = cur.lines[i];
      if (r.kind === "heading") { gfx.color(theme.text); gfx.text(ellipsize(r.text, 17, "bold", textW), x + 46, ly + 8, 17, "bold"); }
      else if (r.kind === "comment") { gfx.color(theme.text3); gfx.text(ellipsize(line, 14, "italic", textW), x + 46, ly + 10, 14, "italic"); }
      else {
        gfx.color(r.kind === "value" ? theme.text : theme.text2);
        gfx.text(ellipsize(line, 15, "sans", textW), x + 46, ly + 9, 15);
      }
      if (hit.clicked && !sheetScroll.dragged() && !todo) todo = () => startEdit(i);
    }
    // result
    if (r.kind === "value" && cur.lines[i].trim()) {
      const txt = formatValue(r.value, style());
      const rx = x + w - resW - 6;
      const hit = ui.hit("r" + i, rx, ly + 3, resW - 4, lh - 6);
      if (hit.hovered) gfx.rect(rx, ly + 3, resW - 4, lh - 6, 8, alpha(theme.accent, 0.12));
      gfx.color(r.isSum ? theme.green : (r.name ? theme.purple : theme.accent));
      gfx.text(ellipsize(txt, 15, r.isSum ? "monobold" : "mono", resW - 20), rx, ly + 9, 15, r.isSum ? "monobold" : "mono", "right", resW - 14);
      if (hit.clicked) { sys.clipboard(plainValue(r.value)); K.toast(TR("copied_value", txt), "content_copy"); }
    } else if (r.kind === "error") {
      gfx.color(theme.red);
      gfx.text("?", x + w - resW - 6, ly + 9, 15, "monobold", "right", resW - 14);
    }
    if (r.isSum) { gfx.color(alpha(theme.green, 0.5)); gfx.line(x + w - resW + 20, ly + 1, x + w - 20, ly + 1, 1.5); }
  }
  const endY = oy + cur.lines.length * lh;
  const eh = ui.hit("end", x + 34, endY, w - 40, 80);
  if (eh.hovered && editLine < 0) { gfx.color(theme.text3); gfx.text(TR("tap_to_add"), x + 46, endY + 10, 13, "italic"); }
  if (todo) todo();
  else if (eh.clicked && !sheetScroll.dragged()) {
    if (cur.lines[cur.lines.length - 1] !== "") { pushHist(); cur.lines.push(""); markDirty(); }
    startEdit(cur.lines.length - 1);
  }
  gfx.unclip();
  sheetScroll.bar(x + w - 6, cy + 4, ch - 8);
  // footer: grand total of every plain value
  const fy = y + h - padH - 40;
  gfx.rect(x, fy, w, 40, 0, theme.window);
  gfx.color(theme.separator); gfx.line(x, fy, x + w, fy, 1);
  let total = null, count = 0;
  for (const r of rs) {
    if (r.kind === "value" && !r.isSum && !r.name && !r.value.dim && !r.value.pct) { total = (total || 0) + r.value.v; count++; }
  }
  gfx.color(theme.text2);
  gfx.text(TR("footer", count), x + 16, fy + 12, 13, "medium");
  if (total !== null) {
    gfx.color(theme.text);
    gfx.text(formatValue({ v: total, unit: null, dim: null }, style()), x, fy + 10, 16, "monobold", "right", w - 20);
  }
  if (padH) drawPad(x, y + h - padH, w, padH);
}

const PAD = [["7", "8", "9", "÷", "("], ["4", "5", "6", "×", ")"], ["1", "2", "3", "−", "%"], ["0", ".", "=", "+", "⏎"]];
function drawPad(x, y, w, h) {
  gfx.rect(x, y, w, h, 0, theme.window);
  gfx.color(theme.separator); gfx.line(x, y, x + w, y, 1);
  const extras = [" of ", " in ", "sum", "^", "√"];
  const cols = 5, rows = PAD.length + 1;
  const kw = (w - 16) / cols, kh = (h - 12) / rows;
  for (let r = 0; r < rows; r++) {
    const keys = r < PAD.length ? PAD[r] : extras;
    for (let c = 0; c < cols; c++) {
      const k = keys[c];
      const kx = x + 8 + c * kw, ky = y + 6 + r * kh;
      const op = "÷×−+%()^√=".includes(k) || r === PAD.length;
      if (ui.button(k === "⏎" ? "" : k.trim(), kx + 3, ky + 3, kw - 6, kh - 6, k === "⏎" ? "primary" : op ? "default" : "plain", k === "⏎" ? "keyboard_return" : undefined)) {
        if (k === "⏎") { if (editLine >= 0) enterLine(); else startEdit(lineCursor); }
        else if (k === "√") insertText("sqrt(");
        else if (k === "sum") insertText("sum");
        else if (k === "×") insertText(" × ");
        else if (k === "÷") insertText(" ÷ ");
        else if (k === "−") insertText(" - ");
        else if (k === "+") insertText(" + ");
        else if (k === "=") insertText(" = ");
        else insertText(k);
      }
    }
  }
}

// ================================================================== app callbacks
app.load = (arg) => {
  const raw = store.get("sheets", null);
  sheets = Array.isArray(raw) ? raw.filter((s) => s && Array.isArray(s.lines)).map((s) => ({ id: Number(s.id) || now(), title: String(s.title || TR("untitled_n", 1)), lines: s.lines.map(String), updated: Number(s.updated) || now() })) : [];
  if (!sheets.length) sheets = samples();
  const p = store.get("prefs", null) || {};
  numStyle = ["comma", "dot", "space"].includes(p.style) ? p.style : "auto";
  showPad = !!p.pad;
  cur = sheets.find((s) => s.id === p.cur) || sheets[0];
  if (arg) app.open(arg);
};
app.open = (arg) => {
  if (typeof arg !== "string" || !arg) return;
  const m = arg.match(/^sheet:(\d+)$/);
  if (m) { const s = sheets.find((x) => String(x.id) === m[1]); if (s) { cur = s; narrowPane = "sheet"; } return; }
  if (arg.includes(":/")) {
    const t = fs.read(arg);
    if (t === null || t === undefined) { K.toast(TR("read_failed"), "error"); return; }
    const s = newSheet(K.baseName(arg), String(t).replace(/\r/g, "").split("\n").map((l) => l.replace(/\s=\s[^=]*$/, "")));
    sheets.unshift(s); cur = s; markDirty();
  } else {
    const s = newSheet(TR("shared"), arg.split("\n"));
    sheets.unshift(s); cur = s; markDirty();
  }
  narrowPane = "sheet";
  K.toast(TR("imported"), "file_download");
};

app.update = (dt) => {
  listScroll.update(dt);
  sheetScroll.update(dt);
  if (editLine >= 0 && K.K.editing !== "ln") stopEdit();
  if (dirty && sys.time() - changedAt > 1.2) save();
};

app.draw = (w, h) => {
  gfx.clear(theme.bg);
  const narrow = w < 700;
  if (narrow) {
    if (narrowPane === "list") { drawList(0, 0, w, h); sheetRect = [0, 0, 0, 0]; }
    else { drawSheet(0, 0, w, h, true); listRect = [0, 0, 0, 0]; }
  } else {
    const lw = clamp(Math.floor(w * 0.27), 220, 300);
    drawList(0, 0, lw, h);
    drawSheet(lw, 0, w - lw, h, false);
  }
  K.drawToast(w, h);
  K.frameEnd();
};

app.event = (e) => {
  if (K.press(e)) { stopEdit(); return; }
  if (listScroll.event(e, listRect)) return;
  if (sheetScroll.event(e, sheetRect)) return;
  if (e.type !== "keydown") return;
  const k = e.key;
  if (e.ctrl) {
    if (k === "z") { if (e.shift) redo(); else undo(); }
    else if (k === "y") redo();
    else if (k === "n") addSheet();
    else if (k === "f") { narrowPane = "list"; K.focus("search"); }
    else if (k === "c" && !K.K.editing) app.onmenu(1);
    else if (k === "e") app.onmenu(3);
    else if (k === "o") app.onmenu(4);
    else if (k === "k") { showPad = !showPad; markDirty(); }
    return;
  }
  if (K.K.editing === "ln" && editLine >= 0) {
    if (k === "up" && editLine > 0) startEdit(editLine - 1);
    else if (k === "down") { if (editLine < cur.lines.length - 1) startEdit(editLine + 1); else enterLine(); }
    else if (k === "backspace") backLine();
    return;
  }
  if (K.K.editing || !cur) return;
  if (k === "up") { lineCursor = Math.max(0, lineCursor - 1); sheetScroll.reveal(lineTops[lineCursor] || 0, (lineTops[lineCursor] || 0) + 40, sheetRect[3]); }
  else if (k === "down") { lineCursor = Math.min(cur.lines.length - 1, lineCursor + 1); sheetScroll.reveal(lineTops[lineCursor] || 0, (lineTops[lineCursor] || 0) + 40, sheetRect[3]); }
  else if (k === "enter") startEdit(lineCursor);
  else if (k === "left" || k === "right") {
    const list = filtered();
    const i = list.indexOf(cur);
    const n = list[clamp(i + (k === "left" ? -1 : 1), 0, list.length - 1)];
    if (n && n !== cur) { cur = n; hist.clear(); sheetScroll.to(0, true); }
  }
  else if (k === "delete") {
    if (cur.lines.length > 1) { pushHist(); cur.lines.splice(lineCursor, 1); lineCursor = Math.min(lineCursor, cur.lines.length - 1); markDirty(); }
  }
  else if (k === "escape") narrowPane = "list";
};

app.menu = () => [
  { title: TR("m_file"), items: [
    { label: TR("new_sheet"), id: 10, shortcut: "Ctrl+N" },
    { label: TR("import"), id: 4, shortcut: "Ctrl+O" },
    { label: TR("export"), id: 3, shortcut: "Ctrl+E" },
    "-",
    { label: TR("delete_sheet"), id: 6 },
  ] },
  { title: TR("m_edit"), items: [
    { label: TR("undo"), id: 11, shortcut: "Ctrl+Z" },
    { label: TR("redo"), id: 12, shortcut: "Ctrl+Y" },
    "-",
    { label: TR("copy_all"), id: 1, shortcut: "Ctrl+C" },
    { label: TR("copy_results"), id: 2 },
    { label: TR("rename"), id: 5 },
  ] },
  { title: TR("m_view"), items: [
    { label: TR("keypad"), id: 13, shortcut: "Ctrl+K" },
    "-",
    { label: TR("fmt_auto"), id: 20 },
    { label: "1,234.5", id: 21 },
    { label: "1.234,5", id: 22 },
    { label: "1 234,5", id: 23 },
    "-",
    { label: TR("help"), id: 30 },
  ] },
];

app.onmenu = (id) => {
  if (id === 10) addSheet();
  else if (id === 11) undo();
  else if (id === 12) redo();
  else if (id === 13) { showPad = !showPad; markDirty(); }
  else if (id >= 20 && id <= 23) { numStyle = ["auto", "comma", "dot", "space"][id - 20]; markDirty(); }
  else if (id === 30) { if (cur) { pushHist(); cur.lines.push(...TR("help_body").split("\n")); markDirty(); } }
  else if (!cur) return;
  else if (id === 1) { sys.clipboard(sheetText(cur, true)); K.toast(TR("copied"), "content_copy"); }
  else if (id === 2) {
    const rs = compute();
    sys.clipboard(rs.filter((r) => r.kind === "value").map((r) => formatValue(r.value, style())).join("\n"));
    K.toast(TR("copied"), "content_copy");
  }
  else if (id === 3) {
    const s = cur;
    ui.saveFile((p) => {
      if (!p) return;
      if (!/\.txt$/i.test(p)) p += ".txt";
      K.toast(fs.write(p, sheetText(s, true)) ? TR("exported") : TR("write_failed"), "ios_share");
    }, s.title.replace(/[\\/:*?"<>|]/g, "-") + ".txt", TR("export"));
  }
  else if (id === 4) ui.openFile((p) => { if (p) app.open(p); }, [".txt", ".md", ".csv"], TR("import"));
  else if (id === 5) ui.prompt(TR("rename"), TR("sheet_name"), cur.title, (t) => { if (t && t.trim()) { pushHist(); cur.title = t.trim(); markDirty(); } });
  else if (id === 6) deleteSheet(cur);
};

app.search = (q) => {
  q = String(q || "").trim().toLowerCase();
  if (!q) return [];
  return sheets.filter((s) => s.title.toLowerCase().includes(q) || s.lines.some((l) => l.toLowerCase().includes(q))).slice(0, 5)
    .map((s) => ({ title: s.title, subtitle: TR("app_name"), icon: "calculate", arg: "sheet:" + s.id }));
};
app.suspend = () => { if (dirty) save(); };
app.autosave = () => { if (dirty) save(); };
app.unsaved = () => dirty;
app.close = () => { save(); store.save(); return true; };
