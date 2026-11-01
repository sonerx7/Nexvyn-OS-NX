// Hexpad for Nexvyn OS: a hex editor for any file on the SD card. Hex and text panes side by side, overwrite and
// insert modes, unlimited undo, selections, find (hex with ?? wildcards or text), go to offset, bookmarks and a data
// inspector that reads and writes integers, floats, dates and text at the cursor. A hex keypad for touch and controller.
import * as K from "./kit.js";

const { clamp, alpha, ellipsize } = K;

// ================================================================== state
let buf = new Uint8Array(0);
let path = "", fileName = "";
let savedVersion = 0, version = 0;
let cursor = 0, nibble = 0, pane = 0;    // pane 0 hex, 1 text
let anchor = -1;                         // selection anchor (-1 = none)
let topRow = 0;
let insertMode = false;
let cols = 16;
let showPad = false, showSide = true;
let bookmarks = [];                      // {offset, label}
let recent = [];
let undoStack = [], redoStack = [];
let find = null;                         // {q, hex, results, job}
let findQuery = "", findHex = true, findCase = false;
let lastFind = -1;
let gridRect = [0, 0, 0, 0];
let rowsVisible = 20;
let dragSel = null;
let sideTab = 0;                         // 0 inspector, 1 bookmarks
let bigEndian = false;
const MAX_SIZE = 16 * 1024 * 1024;

const hex2 = (v) => (v < 16 ? "0" : "") + v.toString(16).toUpperCase();
const hexN = (v, n) => v.toString(16).toUpperCase().padStart(n, "0");
const modified = () => version !== savedVersion;
const selRange = () => (anchor < 0 ? null : [Math.min(anchor, cursor), Math.max(anchor, cursor)]);

// ================================================================== UTF-8 helpers (no TextEncoder in the runtime)
function utf8Encode(s) {
  const out = [];
  for (const ch of String(s)) {
    let c = ch.codePointAt(0);
    if (c < 0x80) out.push(c);
    else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 63));
    else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
    else out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63));
  }
  return new Uint8Array(out);
}
function utf8At(i) {
  const b0 = buf[i];
  if (b0 === undefined) return null;
  let n = 0, c = 0;
  if (b0 < 0x80) return String.fromCharCode(b0);
  if ((b0 & 0xe0) === 0xc0) { n = 1; c = b0 & 31; } else if ((b0 & 0xf0) === 0xe0) { n = 2; c = b0 & 15; } else if ((b0 & 0xf8) === 0xf0) { n = 3; c = b0 & 7; } else return null;
  for (let k = 1; k <= n; k++) { const b = buf[i + k]; if (b === undefined || (b & 0xc0) !== 0x80) return null; c = (c << 6) | (b & 63); }
  try { return String.fromCodePoint(c); } catch (e) { return null; }
}
const printable = (b) => (b >= 0x20 && b < 0x7f ? String.fromCharCode(b) : "·");

// ================================================================== sample buffer shown before a file is opened
function sampleBuffer() {
  const parts = [];
  const push = (arr) => { for (const b of arr) parts.push(b); };
  push([0x4e, 0x58, 0x56, 0x53, 0x41, 0x56, 0x45, 0x00]);          // "NXVSAVE\0"
  push([0x02, 0x00, 0x01, 0x00]);                                   // version 2, slot 1
  const t = 1798000000;
  push([t & 255, (t >> 8) & 255, (t >> 16) & 255, (t >>> 24) & 255]); // a timestamp
  push(utf8Encode("Player One"));
  push([0, 0, 0, 0, 0, 0]);
  push([0x10, 0x27, 0x00, 0x00]);                                   // 10000 coins
  push([0x00, 0x00, 0x48, 0x42]);                                   // 50.0f
  for (let i = 0; i < 32; i++) push([(i * 37 + 11) & 255]);
  push(utf8Encode("Level 7 · Forest Temple"));
  while (parts.length < 256) parts.push(parts.length & 255);
  return new Uint8Array(parts);
}

// ================================================================== edits (undoable)
function replaceRange(at, removeLen, bytes) {
  const before = buf.slice(at, at + removeLen);
  if (removeLen === bytes.length) buf.set(bytes, at);
  else {
    const nb = new Uint8Array(buf.length - removeLen + bytes.length);
    nb.set(buf.subarray(0, at), 0);
    nb.set(bytes, at);
    nb.set(buf.subarray(at + removeLen), at + bytes.length);
    buf = nb;
  }
  version++;
  return { at, before, after: new Uint8Array(bytes) };
}
function doEdit(at, removeLen, bytes, merge) {
  const op = replaceRange(at, removeLen, bytes);
  const last = undoStack[undoStack.length - 1];
  // typing the second nibble of the same byte joins the first one
  if (merge && last && last.at === op.at && last.after.length === 1 && op.before.length === 1 && last.merge) {
    last.after = op.after;
    last.merge = false;
  } else {
    op.merge = merge;
    undoStack.push(op);
    if (undoStack.length > 2000) undoStack.shift();
  }
  redoStack = [];
}
function undo() {
  const op = undoStack.pop();
  if (!op) { K.toast(TR("nothing_undo"), "undo"); return; }
  replaceRange(op.at, op.after.length, op.before);
  redoStack.push(op);
  cursor = clamp(op.at, 0, Math.max(0, buf.length - 1)); anchor = -1; nibble = 0;
  reveal();
}
function redo() {
  const op = redoStack.pop();
  if (!op) { K.toast(TR("nothing_redo"), "redo"); return; }
  replaceRange(op.at, op.before.length, op.after);
  undoStack.push(op);
  cursor = clamp(op.at, 0, Math.max(0, buf.length - 1)); anchor = -1; nibble = 0;
  reveal();
}

// ================================================================== cursor and view
function reveal() {
  const row = Math.floor(cursor / cols);
  if (row < topRow) topRow = row;
  else if (row >= topRow + rowsVisible) topRow = row - rowsVisible + 1;
  clampTop();
}
function clampTop() {
  const rows = Math.ceil((buf.length + (insertMode ? 1 : 0)) / cols);
  topRow = clamp(topRow, 0, Math.max(0, rows - rowsVisible));
}
function moveTo(off, select) {
  const maxOff = Math.max(0, buf.length - (insertMode ? 0 : 1));
  off = clamp(off, 0, maxOff);
  if (select) { if (anchor < 0) anchor = cursor; } else anchor = -1;
  cursor = off; nibble = 0;
  reveal();
}

function typeNibble(v) {
  if (!buf.length || cursor >= buf.length) { typeNibbleInsert(v); return; }
  const old = buf[cursor];
  const nv = nibble === 0 ? (v << 4) | (old & 15) : (old & 0xf0) | v;
  doEdit(cursor, 1, [nv], nibble === 1);
  if (nibble === 0) { nibble = 1; undoStack[undoStack.length - 1].merge = true; }
  else { nibble = 0; if (cursor < buf.length - 1) cursor++; }
  anchor = -1;
  reveal();
}
// insert mode: the second nibble edits the byte that was just inserted
function typeNibbleInsert(v) {
  if (nibble === 0) { doEdit(cursor, 0, [v << 4], false); undoStack[undoStack.length - 1].merge = true; nibble = 1; }
  else { doEdit(cursor, 1, [(buf[cursor] & 0xf0) | v], true); nibble = 0; cursor++; }
  anchor = -1;
  reveal();
}
function typeHex(v) { if (insertMode) typeNibbleInsert(v); else typeNibble(v); }
function typeText(s) {
  const bytes = utf8Encode(s);
  if (!bytes.length) return;
  if (insertMode || cursor >= buf.length) doEdit(cursor, 0, bytes, false);
  else doEdit(cursor, Math.min(bytes.length, buf.length - cursor), bytes, false);
  cursor = Math.min(cursor + bytes.length, insertMode ? buf.length : Math.max(0, buf.length - 1));
  anchor = -1; nibble = 0;
  reveal();
}
function deleteSel(back) {
  const r = selRange();
  if (r) { doEdit(r[0], r[1] - r[0] + 1, [], false); cursor = clamp(r[0], 0, Math.max(0, buf.length - 1)); anchor = -1; return; }
  if (back) { if (cursor > 0) { doEdit(cursor - 1, 1, [], false); cursor--; } }
  else if (cursor < buf.length) doEdit(cursor, 1, [], false);
  cursor = clamp(cursor, 0, Math.max(0, buf.length - 1));
  nibble = 0;
}
function fillSel(v) {
  const r = selRange();
  if (!r) return;
  doEdit(r[0], r[1] - r[0] + 1, new Uint8Array(r[1] - r[0] + 1).fill(v), false);
}

// ================================================================== files
function loadBytes(bytes, p) {
  if (bytes.length > MAX_SIZE) { K.toast(TR("too_big"), "error"); return; }
  buf = new Uint8Array(bytes);
  path = p || ""; fileName = p ? p.replace(/\\/g, "/").split("/").pop() : TR("sample_name");
  cursor = 0; anchor = -1; nibble = 0; topRow = 0;
  undoStack = []; redoStack = []; version = 0; savedVersion = 0;
  find = null; lastFind = -1;
  const bm = store.get("bookmarks", {});
  bookmarks = p && bm && Array.isArray(bm[p]) ? bm[p] : [];
  if (p) {
    recent = [p, ...recent.filter((x) => x !== p)].slice(0, 8);
    store.set("recent", recent);
    store.set("last", p);
  }
}
function openPath(p) {
  const data = fs.readBytes(p);
  if (!data) { K.toast(TR("read_failed"), "error"); return; }
  loadBytes(data, p);
  K.toast(TR("opened", fileName, fmtSize(buf.length)), "file_open");
}
function confirmDiscard(then) {
  if (!modified()) { then(); return; }
  ui.alert(TR("unsaved_title"), TR("unsaved_msg", fileName), [TR("discard"), TR("cancel")], (b) => { if (b === 0) then(); });
}
function openFile() { confirmDiscard(() => ui.openFile((p) => { if (p) openPath(p); }, [], TR("open"))); }
function saveTo(p) {
  if (fs.write(p, buf)) {
    savedVersion = version;
    if (p !== path) { path = p; fileName = p.replace(/\\/g, "/").split("/").pop(); }
    K.toast(TR("saved", fmtSize(buf.length)), "save");
  } else K.toast(TR("write_failed"), "error");
}
function save() { if (!path) saveAs(); else saveTo(path); }
function saveAs() { ui.saveFile((p) => { if (p) saveTo(p); }, fileName || "data.bin", TR("save_as")); }
function fmtSize(n) {
  if (n < 1024) return TR("bytes_n", n);
  if (n < 1048576) return (n / 1024).toFixed(1) + " KB";
  return (n / 1048576).toFixed(2) + " MB";
}
function saveBookmarks() {
  if (!path) return;
  const bm = store.get("bookmarks", {}) || {};
  bm[path] = bookmarks;
  store.set("bookmarks", bm);
}
function addBookmark() {
  ui.prompt(TR("bookmark"), TR("bookmark_msg", "0x" + hexN(cursor, 6)), "", (label) => {
    if (label === null || label === undefined) return;
    bookmarks.push({ offset: cursor, label: label.trim() || "0x" + hexN(cursor, 6) });
    bookmarks.sort((a, b) => a.offset - b.offset);
    saveBookmarks();
    sideTab = 1;
    K.toast(TR("bookmarked"), "bookmark_add");
  });
}

// ================================================================== find
function parseQuery() {
  if (findHex) {
    const clean = findQuery.replace(/0x/gi, "").replace(/[^0-9a-fA-F?]/g, "");
    if (!clean.length || clean.length % 2) return null;
    const pat = [];
    for (let i = 0; i < clean.length; i += 2) {
      const p2 = clean.slice(i, i + 2);
      pat.push(p2 === "??" ? -1 : parseInt(p2, 16));
    }
    return pat.some((v) => Number.isNaN(v)) ? null : pat;
  }
  const b = utf8Encode(findQuery);
  return b.length ? Array.from(b) : null;
}
function startFind() {
  // text that cannot be hex (letters beyond A-F, an odd count of digits) is searched as text
  if (findHex && !parseQuery() && findQuery.trim()) { findHex = false; K.toast(TR("as_text"), "text_fields"); }
  const pat = parseQuery();
  if (!pat) { K.toast(TR("bad_query"), "error"); return; }
  find = { pat, results: [], pos: 0, done: false, ci: !findHex && !findCase };
  lastFind = -1;
}
function stepFind() {
  if (!find || find.done) return;
  const pat = find.pat, n = pat.length, ci = find.ci;
  const end = Math.min(buf.length - n + 1, find.pos + 400000);
  const low = (b) => (b >= 65 && b <= 90 ? b + 32 : b);
  for (let i = find.pos; i < end; i++) {
    let ok = true;
    for (let k = 0; k < n; k++) {
      const p = pat[k];
      if (p < 0) continue;
      const b = buf[i + k];
      if (ci ? low(b) !== low(p) : b !== p) { ok = false; break; }
    }
    if (ok) { find.results.push(i); if (find.results.length >= 10000) { find.done = true; break; } }
  }
  find.pos = end;
  if (end >= buf.length - n + 1) find.done = true;
  if (find.done && lastFind < 0 && find.results.length) gotoResult(1);
}
function gotoResult(dir) {
  if (!find || !find.results.length) { K.toast(TR("not_found"), "search_off"); return; }
  const rs = find.results;
  let idx = rs.findIndex((r) => (dir > 0 ? r > cursor || (lastFind < 0 && r >= cursor) : r < cursor));
  if (dir < 0) { idx = -1; for (let i = rs.length - 1; i >= 0; i--) if (rs[i] < cursor) { idx = i; break; } }
  if (idx < 0) idx = dir > 0 ? 0 : rs.length - 1;
  lastFind = idx;
  anchor = rs[idx] + find.pat.length - 1;
  cursor = rs[idx];
  nibble = 0;
  reveal();
}
function goTo() {
  ui.prompt(TR("goto"), TR("goto_msg"), "0x" + hexN(cursor, 1), (t) => {
    if (!t) return;
    t = t.trim();
    let v;
    if (/^[+-]/.test(t)) v = cursor + parseNum(t);
    else v = parseNum(t);
    if (Number.isNaN(v)) { K.toast(TR("bad_offset"), "error"); return; }
    moveTo(v, false);
  });
}
function parseNum(t) {
  const neg = t.startsWith("-");
  t = t.replace(/^[+-]/, "");
  const v = /^0x/i.test(t) ? parseInt(t.slice(2), 16) : /[a-f]/i.test(t) ? parseInt(t, 16) : parseInt(t, 10);
  return neg ? -v : v;
}

// ================================================================== copy / paste
function copySel(kind) {
  const r = selRange() || [cursor, cursor];
  const bytes = buf.subarray(r[0], r[1] + 1);
  let s;
  if (kind === "hex") s = Array.from(bytes, hex2).join(" ");
  else if (kind === "c") s = "{ " + Array.from(bytes, (b) => "0x" + hex2(b)).join(", ") + " }";
  else s = Array.from(bytes, printable).join("");
  sys.clipboard(s);
  K.toast(TR("copied_n", bytes.length), "content_copy");
}
function pasteHex() {
  const t = String(sys.clipboard() || "");
  const clean = t.replace(/0x/gi, "").replace(/[^0-9a-fA-F]/g, "");
  if (!clean.length || clean.length % 2) {
    if (t.length) { typeText(t); return; }
    K.toast(TR("clipboard_empty"), "content_paste");
    return;
  }
  const bytes = new Uint8Array(clean.length / 2);
  for (let i = 0; i < bytes.length; i++) bytes[i] = parseInt(clean.slice(i * 2, i * 2 + 2), 16);
  if (insertMode) doEdit(cursor, 0, bytes, false);
  else doEdit(cursor, Math.min(bytes.length, buf.length - cursor), bytes, false);
  K.toast(TR("pasted_n", bytes.length), "content_paste");
}

// ================================================================== data inspector
function inspectorRows() {
  const at = cursor;
  const avail = buf.length - at;
  const dv = new DataView(buf.buffer, buf.byteOffset, buf.byteLength);
  const le = !bigEndian;
  const rows = [];
  const add = (key, size, get, set) => rows.push({ key, size, value: avail >= size ? get() : "—", set: avail >= size ? set : null });
  add("i_bin", 1, () => buf[at].toString(2).padStart(8, "0"), (v) => { const n = parseInt(v.replace(/\s/g, ""), 2); return Number.isNaN(n) ? null : [n & 255]; });
  add("i_u8", 1, () => String(dv.getUint8(at)), (v) => { const n = Number(v); return Number.isInteger(n) ? [n & 255] : null; });
  add("i_i8", 1, () => String(dv.getInt8(at)), (v) => { const n = Number(v); return Number.isInteger(n) ? [n & 255] : null; });
  const w = (size, fn) => (v) => { const b = new Uint8Array(size); const d = new DataView(b.buffer); try { if (fn(d, v) === false) return null; } catch (e) { return null; } return Array.from(b); };
  add("i_u16", 2, () => String(dv.getUint16(at, le)), w(2, (d, v) => { const n = Number(v); if (!Number.isInteger(n)) return false; d.setUint16(0, n, le); }));
  add("i_i16", 2, () => String(dv.getInt16(at, le)), w(2, (d, v) => { const n = Number(v); if (!Number.isInteger(n)) return false; d.setInt16(0, n, le); }));
  add("i_u32", 4, () => String(dv.getUint32(at, le)), w(4, (d, v) => { const n = Number(v); if (!Number.isInteger(n)) return false; d.setUint32(0, n, le); }));
  add("i_i32", 4, () => String(dv.getInt32(at, le)), w(4, (d, v) => { const n = Number(v); if (!Number.isInteger(n)) return false; d.setInt32(0, n, le); }));
  add("i_i64", 8, () => String(dv.getBigInt64(at, le)), w(8, (d, v) => { d.setBigInt64(0, BigInt(v.trim()), le); }));
  add("i_u64", 8, () => String(dv.getBigUint64(at, le)), w(8, (d, v) => { d.setBigUint64(0, BigInt(v.trim()), le); }));
  add("i_f32", 4, () => fmtFloat(dv.getFloat32(at, le)), w(4, (d, v) => { const n = Number(v); if (Number.isNaN(n) && v.trim() !== "NaN") return false; d.setFloat32(0, n, le); }));
  add("i_f64", 8, () => fmtFloat(dv.getFloat64(at, le)), w(8, (d, v) => { const n = Number(v); if (Number.isNaN(n) && v.trim() !== "NaN") return false; d.setFloat64(0, n, le); }));
  add("i_time", 4, () => fmtTime(dv.getUint32(at, le)), null);
  rows[rows.length - 1].set = null;
  add("i_utf8", 1, () => { const c = utf8At(at); return c === null ? "—" : JSON.stringify(c); }, (v) => (v.length ? Array.from(utf8Encode(Array.from(v)[0])) : null));
  return rows;
}
const fmtFloat = (f) => (Number.isFinite(f) ? (Math.abs(f) > 1e-5 && Math.abs(f) < 1e9 ? String(Math.round(f * 1e6) / 1e6) : f.toExponential(6)) : String(f));
function fmtTime(t) {
  if (!t) return "—";
  const d = sys.date(t);
  return `${d.year}-${String(d.month).padStart(2, "0")}-${String(d.day).padStart(2, "0")} ${String(d.hour).padStart(2, "0")}:${String(d.min).padStart(2, "0")}`;
}
function editValue(row) {
  if (!row.set) return;
  ui.prompt(TR(row.key), TR("value_msg", "0x" + hexN(cursor, 6)), row.value === "—" ? "" : row.value.replace(/^"|"$/g, ""), (v) => {
    if (v === null || v === undefined) return;
    const bytes = row.set(String(v));
    if (!bytes) { K.toast(TR("bad_value"), "error"); return; }
    doEdit(cursor, Math.min(bytes.length, buf.length - cursor), bytes, false);
    K.toast(TR("value_written", bytes.length), "edit");
  });
}

// ================================================================== drawing
function drawToolbar(w) {
  gfx.rect(0, 0, w, 50, 0, theme.window);
  let bx = 10;
  const btn = (icon, id, tint, active) => { const r = ui.iconButton(icon, bx, 9, 36, 32, tint || theme.text2, !!active, id); bx += 38; return r; };
  if (btn("folder_open", "##open", theme.accent)) openFile();
  if (btn("save", "##save", modified() ? theme.accent : theme.text2)) save();
  bx += 6;
  if (btn("undo", "##undo", undoStack.length ? theme.text2 : theme.text3)) undo();
  if (btn("redo", "##redo", redoStack.length ? theme.text2 : theme.text3)) redo();
  bx += 6;
  const fx = bx;
  let right = w - 10;
  const rb = (icon, id, tint, active) => { right -= 38; return ui.iconButton(icon, right, 9, 36, 32, tint || theme.text2, !!active, id); };
  if (rb("more_horiz", "##more")) {
    ui.contextMenu([{ label: TR("save_as"), id: 4, icon: "save_as" }, { label: TR("goto"), id: 5, icon: "my_location" },
      { label: TR("bookmark"), id: 6, icon: "bookmark_add" }, "-", { label: TR("copy_hex"), id: 7, icon: "content_copy" },
      { label: TR("copy_text"), id: 8, icon: "text_snippet" }, { label: TR("copy_c"), id: 9, icon: "data_array" },
      { label: TR("paste_bytes"), id: 10, icon: "content_paste" }, "-", { label: TR("fill_zero"), id: 11, icon: "format_color_fill" },
      { label: TR("select_all"), id: 12, icon: "select_all" }, { label: bigEndian ? TR("little_endian") : TR("big_endian"), id: 13, icon: "swap_horiz" },
      ...recent.filter((p) => p !== path).slice(0, 5).map((p, i) => ({ label: TR("recent", p.replace(/\\/g, "/").split("/").pop()), id: 100 + i, icon: "history" }))], (id) => app.onmenu(id));
  }
  if (w > 700 && rb("view_sidebar", "##side", showSide ? theme.accent : theme.text2, showSide)) showSide = !showSide;
  if (rb("dialpad", "##pad", showPad ? theme.accent : theme.text2, showPad)) showPad = !showPad;
  if (rb(insertMode ? "add_box" : "edit_square", "##ins", insertMode ? theme.orange : theme.text2, insertMode)) { insertMode = !insertMode; nibble = 0; K.toast(insertMode ? TR("mode_insert") : TR("mode_over"), "keyboard"); }
  // find field
  const fw = Math.min(360, right - fx - 8);
  if (fw > 150) {
    const segW = 60;
    const nq = K.field("find", findQuery, fx, 10, fw - segW - 4, 30, findHex ? TR("find_hex_ph") : TR("find_text_ph"), "search");
    if (nq !== findQuery) { findQuery = nq; find = null; }
    if (ui.submitted("find")) { if (find && find.done && find.results.length) gotoResult(1); else startFind(); }
    const seg = ui.segmented("fmode", ["hex", "abc"], findHex ? 0 : 1, fx + fw - segW, 10, segW, 30);
    if ((seg === 0) !== findHex) { findHex = seg === 0; find = null; }
  }
  gfx.color(theme.separator); gfx.line(0, 50, w, 50, 1);
  return 51;
}

function drawGrid(x, y, w, h) {
  const fs = 14;
  const cw = gfx.textWidth("0", fs, "mono");
  const rowH = 22;
  const offW = cw * 8 + 18;
  // choose 16, 8 or 4 bytes per row so that hex and text panes fit
  const fitCols = (n) => offW + n * (cw * 2 + cw * 0.9) + cw * 2 + n * cw + 16 <= w;
  cols = fitCols(16) ? 16 : fitCols(8) ? 8 : 4;
  const byteW = cw * 2 + cw * 0.9;
  const hexX = x + offW;
  const txtX = hexX + cols * byteW + cw * 1.5;
  rowsVisible = Math.max(1, Math.floor((h - 28) / rowH));
  gridRect = [x, y, w, h];
  clampTop();
  // header
  gfx.rect(x, y, w, 26, 0, alpha(theme.text, 0.04));
  gfx.color(theme.text3);
  gfx.text(TR("offset"), x + 10, y + 5, 12, "medium");
  for (let c = 0; c < cols; c++) gfx.text(hex2(c), hexX + c * byteW, y + 5, 12, "mono");
  gfx.text(TR("text"), txtX, y + 5, 12, "medium");
  const gy = y + 28;
  const sel = selRange();
  const hit = ui.hit("grid", x, gy, w, h - 28);
  const marks = new Set(bookmarks.map((b) => b.offset));
  const hits = find && find.results.length ? find : null;
  for (let r = 0; r < rowsVisible; r++) {
    const row = topRow + r;
    const base = row * cols;
    if (base > buf.length || (base === buf.length && !(insertMode && base === buf.length && buf.length % cols === 0) && base > 0)) break;
    const ry = gy + r * rowH;
    if (r % 2 === 1) gfx.rect(x, ry, w, rowH, 0, alpha(theme.text, 0.025));
    gfx.color(theme.text3);
    gfx.text(hexN(base, 8), x + 10, ry + 3, fs - 1, "mono");
    for (let c = 0; c < cols; c++) {
      const off = base + c;
      if (off > buf.length || (off === buf.length && !insertMode)) break;
      const bx = hexX + c * byteW, tx = txtX + c * cw;
      const inSel = sel && off >= sel[0] && off <= sel[1];
      let found = false;
      if (hits && find.pat) {
        // binary search the nearest result
        const rs = hits.results;
        let lo = 0, hi = rs.length - 1, k = -1;
        while (lo <= hi) { const m = (lo + hi) >> 1; if (rs[m] <= off) { k = m; lo = m + 1; } else hi = m - 1; }
        found = k >= 0 && off < rs[k] + find.pat.length;
      }
      if (found) { gfx.rect(bx - 2, ry + 1, byteW - 2, rowH - 2, 4, alpha(theme.yellow, 0.4)); gfx.rect(tx, ry + 1, cw, rowH - 2, 2, alpha(theme.yellow, 0.4)); }
      if (inSel) { gfx.rect(bx - 2, ry + 1, byteW - 2, rowH - 2, 4, alpha(theme.accent, 0.3)); gfx.rect(tx, ry + 1, cw, rowH - 2, 2, alpha(theme.accent, 0.3)); }
      if (marks.has(off)) gfx.rect(bx - 2, ry + rowH - 3, byteW - 2, 2, 1, theme.orange);
      if (off === cursor) {
        const focusHex = pane === 0;
        gfx.rect(bx - 2 + (focusHex ? nibble * cw : 0), ry + 1, focusHex ? cw + 2 : byteW - 2, rowH - 2, 4, alpha(theme.accent, focusHex ? 0.75 : 0.25));
        gfx.rect(tx, ry + 1, cw, rowH - 2, 2, alpha(theme.accent, focusHex ? 0.25 : 0.75));
      }
      if (off < buf.length) {
        const b = buf[off];
        gfx.color(off === cursor && pane === 0 ? theme.text : b === 0 ? theme.text3 : theme.text);
        gfx.text(hex2(b), bx, ry + 3, fs, "mono");
        gfx.color(b >= 0x20 && b < 0x7f ? theme.text : theme.text3);
        gfx.text(printable(b), tx, ry + 3, fs, "mono");
      } else {
        gfx.color(theme.text3);
        gfx.text("··", bx, ry + 3, fs, "mono");
      }
    }
  }
  // pointer: click puts the cursor, drag selects
  const [mx, my] = ui.mouse();
  const offAt = () => {
    const r = Math.floor((my - gy) / rowH);
    let c, p;
    if (mx >= txtX) { c = Math.floor((mx - txtX) / cw); p = 1; } else { c = Math.floor((mx - hexX) / byteW); p = 0; }
    c = clamp(c, 0, cols - 1);
    return [clamp((topRow + r) * cols + c, 0, Math.max(0, buf.length - (insertMode ? 0 : 1))), p];
  };
  if (hit.pressed && buf.length) { const [o, p] = offAt(); pane = p; anchor = -1; cursor = o; nibble = 0; dragSel = o; }
  if (hit.held && dragSel !== null) { const [o] = offAt(); if (o !== dragSel) { anchor = dragSel; cursor = o; } }
  if (!hit.held) dragSel = null;
  if (hit.rightClicked) {
    ui.contextMenu([{ label: TR("copy_hex"), id: 7, icon: "content_copy" }, { label: TR("copy_text"), id: 8, icon: "text_snippet" },
      { label: TR("paste_bytes"), id: 10, icon: "content_paste" }, "-", { label: TR("bookmark"), id: 6, icon: "bookmark_add" },
      { label: TR("fill_zero"), id: 11, icon: "format_color_fill" }, { label: TR("delete_bytes"), id: 14, icon: "backspace" }], (id) => app.onmenu(id));
  }
  // scrollbar
  const rows = Math.ceil((buf.length + 1) / cols);
  if (rows > rowsVisible) {
    const th = Math.max(28, (h - 32) * rowsVisible / rows);
    const ty = gy + (h - 32 - th) * (topRow / Math.max(1, rows - rowsVisible));
    gfx.rect(x + w - 7, ty, 4, th, 2, alpha(theme.text, 0.22));
  }
  if (!buf.length) K.empty("memory", TR("empty_file"), TR("empty_file_hint"), x, y, w, h);
}

function drawSide(x, y, w, h) {
  gfx.rect(x, y, w, h, 0, theme.sidebar);
  gfx.color(theme.separator); gfx.line(x, y, x, y + h, 1);
  sideTab = ui.segmented("stab", [TR("inspector"), TR("bookmarks")], sideTab, x + 10, y + 10, w - 20, 30);
  let yy = y + 50;
  const p = 12;
  if (sideTab === 0) {
    const e = ui.segmented("endian", ["LE", "BE"], bigEndian ? 1 : 0, x + p, yy, 110, 28);
    bigEndian = e === 1;
    gfx.color(theme.text3);
    gfx.text("0x" + hexN(cursor, 8), x + p + 120, yy + 6, 13, "mono");
    yy += 38;
    const rows = inspectorRows();
    for (const r of rows) {
      if (yy + 30 > y + h) break;
      const hit = ui.hit("ir" + r.key, x + 6, yy, w - 12, 30);
      if (hit.hovered && r.set) gfx.rect(x + 6, yy, w - 12, 30, 8, theme.hover);
      gfx.color(theme.text2);
      gfx.text(TR(r.key), x + p, yy + 7, 12, "medium");
      gfx.color(theme.text);
      gfx.text(ellipsize(r.value, 13, "mono", w - p * 2 - 92), x + p + 90, yy + 7, 13, "mono");
      if (r.set) gfx.icon("edit", x + w - p - 6, yy + 15, 13, theme.text3);
      if (hit.clicked && r.set) editValue(r);
      yy += 32;
    }
  } else {
    if (ui.button(TR("add_bookmark"), x + p, yy, w - p * 2, 32, "primary", "bookmark_add")) addBookmark();
    yy += 42;
    if (!bookmarks.length) { gfx.color(theme.text3); gfx.wrap(TR("no_bookmarks"), x + p, yy, w - p * 2, 13); }
    bookmarks.forEach((b, i) => {
      if (yy + 40 > y + h) return;
      const hit = ui.hit("bm" + i, x + 6, yy, w - 52, 40);
      gfx.rect(x + 6, yy, w - 12, 40, 8, hit.hovered ? theme.hover : alpha(theme.text, 0.04));
      gfx.icon("bookmark", x + p + 8, yy + 20, 16, theme.orange);
      gfx.color(theme.text);
      gfx.text(ellipsize(b.label, 13, "semibold", w - 90), x + p + 24, yy + 4, 13, "semibold");
      gfx.color(theme.text3);
      gfx.text("0x" + hexN(b.offset, 8), x + p + 24, yy + 21, 11, "mono");
      if (hit.clicked) moveTo(b.offset, false);
      if (ui.iconButton("close", x + w - 44, yy + 4, 32, 32, theme.text3, false, "##bmd" + i)) { bookmarks.splice(i, 1); saveBookmarks(); }
      yy += 44;
    });
  }
}

function drawPad(x, y, w, h) {
  gfx.rect(x, y, w, h, 0, theme.window);
  gfx.color(theme.separator); gfx.line(x, y, x + w, y, 1);
  const keys = "0123456789ABCDEF".split("");
  const extra = [["arrow_back", () => moveTo(cursor - 1, false)], ["arrow_forward", () => moveTo(cursor + 1, false)],
    ["arrow_upward", () => moveTo(cursor - cols, false)], ["arrow_downward", () => moveTo(cursor + cols, false)],
    ["backspace", () => deleteSel(true)]];
  const n = keys.length + extra.length;
  const perRow = w >= 900 ? n : Math.ceil(n / 2);
  const rows = Math.ceil(n / perRow);
  const kw = (w - 16) / perRow, kh = (h - 12) / rows;
  for (let i = 0; i < n; i++) {
    const kx = x + 8 + (i % perRow) * kw, ky = y + 6 + Math.floor(i / perRow) * kh;
    if (i < keys.length) {
      if (ui.button(keys[i], kx + 2, ky + 2, kw - 4, kh - 4, "default")) { pane = 0; typeHex(i); }
    } else {
      const [icon, fn] = extra[i - keys.length];
      if (ui.iconButton(icon, kx + 2, ky + 2, kw - 4, kh - 4, theme.text2, false, "##pad" + i)) fn();
    }
  }
}

function drawStatus(x, y, w) {
  gfx.rect(x, y, w, 26, 0, theme.window);
  gfx.color(theme.separator); gfx.line(x, y, x + w, y, 1);
  const sel = selRange();
  let s = `${fileName}${modified() ? " •" : ""}  ·  ${fmtSize(buf.length)}  ·  ${TR("at", "0x" + hexN(cursor, 1), cursor)}`;
  if (sel) s += "  ·  " + TR("sel_n", sel[1] - sel[0] + 1);
  if (find) s += "  ·  " + (find.done ? TR("found_n", find.results.length) : TR("searching", Math.floor((find.pos / Math.max(1, buf.length)) * 100)));
  gfx.color(theme.text2);
  gfx.text(ellipsize(s, 12, "sans", w - 130), x + 10, y + 6, 12);
  gfx.color(insertMode ? theme.orange : theme.text3);
  gfx.text(insertMode ? "INS" : "OVR", x, y + 6, 12, "monobold", "right", w - 10);
}

// ================================================================== app callbacks
app.load = (arg) => {
  recent = (store.get("recent", []) || []).filter((p) => typeof p === "string");
  showPad = !!store.get("pad", false);
  showSide = store.get("side", true) !== false;
  bigEndian = !!store.get("be", false);
  if (arg) { app.open(arg); if (buf.length || path) return; }
  const last = store.get("last", "");
  if (last && fs.exists(last)) { const d = fs.readBytes(last); if (d && d.length <= MAX_SIZE) { loadBytes(d, last); return; } }
  loadBytes(sampleBuffer(), "");
};
app.open = (arg) => {
  if (typeof arg !== "string" || !arg) return;
  if (arg.includes(":/")) confirmDiscard(() => openPath(arg));
  else confirmDiscard(() => { loadBytes(utf8Encode(arg), ""); fileName = TR("shared_text"); });
};

app.update = () => { if (find && !find.done) stepFind(); };

app.draw = (w, h) => {
  gfx.clear(theme.bg);
  const top = drawToolbar(w);
  const padH = showPad ? (w >= 900 ? 54 : 100) : 0;
  const sideW = showSide && w > 700 ? Math.min(300, Math.floor(w * 0.3)) : 0;
  const bodyH = h - top - padH - 26;
  drawGrid(0, top, w - sideW, bodyH);
  if (sideW) drawSide(w - sideW, top, sideW, bodyH);
  if (padH) drawPad(0, top + bodyH, w, padH);
  drawStatus(0, h - 26, w);
  K.drawToast(w, h - 26);
  K.frameEnd();
};

app.event = (e) => {
  if (K.press(e)) return;
  if (e.type === "scroll" && e.x >= gridRect[0] && e.x <= gridRect[0] + gridRect[2] && e.y >= gridRect[1]) {
    topRow += Math.round((e.dy || 0) / 22) || Math.sign(e.dy || 0);
    clampTop();
    return;
  }
  if (e.type === "text" && !K.K.editing && pane === 1 && !e.ctrl) { typeText(e.text); return; }
  if (e.type !== "keydown" || K.K.editing) return;
  const k = e.key;
  if (e.ctrl) {
    if (k === "z") { if (e.shift) redo(); else undo(); }
    else if (k === "y") redo();
    else if (k === "o") openFile();
    else if (k === "s") { if (e.shift) saveAs(); else save(); }
    else if (k === "f") K.focus("find");
    else if (k === "g") goTo();
    else if (k === "b") addBookmark();
    else if (k === "c") copySel(pane === 0 ? "hex" : "text");
    else if (k === "v") pasteHex();
    else if (k === "a") { anchor = 0; cursor = Math.max(0, buf.length - 1); }
    else if (k === "home") moveTo(0, e.shift);
    else if (k === "end") moveTo(buf.length - 1, e.shift);
    return;
  }
  if (k === "left") moveTo(cursor - 1, e.shift);
  else if (k === "right") moveTo(cursor + 1, e.shift);
  else if (k === "up") moveTo(cursor - cols, e.shift);
  else if (k === "down") moveTo(cursor + cols, e.shift);
  else if (k === "pageup") { moveTo(cursor - cols * rowsVisible, e.shift); }
  else if (k === "pagedown") { moveTo(cursor + cols * rowsVisible, e.shift); }
  else if (k === "home") moveTo(cursor - (cursor % cols), e.shift);
  else if (k === "end") moveTo(cursor - (cursor % cols) + cols - 1, e.shift);
  else if (k === "tab") { pane = 1 - pane; nibble = 0; }
  else if (k === "insert") { insertMode = !insertMode; nibble = 0; K.toast(insertMode ? TR("mode_insert") : TR("mode_over"), "keyboard"); }
  else if (k === "backspace") deleteSel(true);
  else if (k === "delete") deleteSel(false);
  else if (k === "escape") { anchor = -1; find = null; }
  else if (k === "f3") gotoResult(e.shift ? -1 : 1);
  else if (pane === 0 && /^[0-9a-f]$/.test(k)) typeHex(parseInt(k, 16));
};

app.menu = () => [
  { title: TR("m_file"), items: [
    { label: TR("open"), id: 1, shortcut: "Ctrl+O" },
    { label: TR("save"), id: 2, shortcut: "Ctrl+S" },
    { label: TR("save_as"), id: 4, shortcut: "Ctrl+Shift+S" },
    "-",
    { label: TR("show_sample"), id: 15 },
  ] },
  { title: TR("m_edit"), items: [
    { label: TR("undo"), id: 20, shortcut: "Ctrl+Z" },
    { label: TR("redo"), id: 21, shortcut: "Ctrl+Y" },
    "-",
    { label: TR("copy_hex"), id: 7, shortcut: "Ctrl+C" },
    { label: TR("copy_text"), id: 8 },
    { label: TR("copy_c"), id: 9 },
    { label: TR("paste_bytes"), id: 10, shortcut: "Ctrl+V" },
    "-",
    { label: TR("select_all"), id: 12, shortcut: "Ctrl+A" },
    { label: TR("fill_zero"), id: 11 },
    { label: TR("delete_bytes"), id: 14, shortcut: "Del" },
    { label: TR("toggle_insert"), id: 16, shortcut: "Ins" },
  ] },
  { title: TR("m_go"), items: [
    { label: TR("goto"), id: 5, shortcut: "Ctrl+G" },
    { label: TR("find"), id: 22, shortcut: "Ctrl+F" },
    { label: TR("find_next"), id: 23, shortcut: "F3" },
    { label: TR("find_prev"), id: 24, shortcut: "Shift+F3" },
    "-",
    { label: TR("bookmark"), id: 6, shortcut: "Ctrl+B" },
    { label: TR("keypad"), id: 17 },
  ] },
];

app.onmenu = (id) => {
  if (id === 1) openFile();
  else if (id === 2) save();
  else if (id === 4) saveAs();
  else if (id === 5) goTo();
  else if (id === 6) addBookmark();
  else if (id === 7) copySel("hex");
  else if (id === 8) copySel("text");
  else if (id === 9) copySel("c");
  else if (id === 10) pasteHex();
  else if (id === 11) { if (selRange()) fillSel(0); else K.toast(TR("select_first"), "info"); }
  else if (id === 12) { anchor = 0; cursor = Math.max(0, buf.length - 1); }
  else if (id === 13) { bigEndian = !bigEndian; store.set("be", bigEndian); }
  else if (id === 14) deleteSel(false);
  else if (id === 15) confirmDiscard(() => loadBytes(sampleBuffer(), ""));
  else if (id === 16) { insertMode = !insertMode; nibble = 0; }
  else if (id === 17) { showPad = !showPad; store.set("pad", showPad); }
  else if (id === 20) undo();
  else if (id === 21) redo();
  else if (id === 22) K.focus("find");
  else if (id === 23) gotoResult(1);
  else if (id === 24) gotoResult(-1);
  else if (id >= 100) { const p = recent.filter((x) => x !== path)[id - 100]; if (p) confirmDiscard(() => openPath(p)); }
};

app.unsaved = () => modified();
app.autosave = () => { store.set("pad", showPad); store.set("side", showSide); store.set("be", bigEndian); };
app.close = () => {
  store.set("pad", showPad); store.set("side", showSide); store.set("be", bigEndian);
  if (modified()) {
    ui.alert(TR("unsaved_title"), TR("unsaved_msg", fileName), [TR("save"), TR("discard"), TR("cancel")], (b) => {
      if (b === 0) { save(); if (!modified()) sys.exit(); }
      else if (b === 1) { savedVersion = version; sys.exit(); }
    });
    return false;
  }
  store.save();
  return true;
};
