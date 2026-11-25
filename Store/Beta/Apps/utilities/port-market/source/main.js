// Port Market 0.3.0 — Nexvyn OS SDK 1.15.
// Store tab: custom gfx layout (nxui cannot report a widget rectangle, so icons and screenshots are drawn here).
// Archive items and Local tabs: nxui, unchanged from 0.2.1.
const ARCHIVE = "https://archive.org";
const CATALOG_ITEM = "nexvyn-port-market"; // the one Internet Archive item that holds catalog.json
const CATALOG_URL = `${ARCHIVE}/download/${CATALOG_ITEM}/catalog.json`;
const CATALOG_REFRESH_S = 300;
const CATALOG_RETRY_S = 20;
const MAX_ARCHIVES = 24;
const MAX_APPS = 256;
const MAX_TEXT = 2000;
const MAX_BYTES = 1074000000;
const MAX_HASH_BYTES = 8 * 1048576; // larger files are only size-checked (no streaming hash API in the SDK)
const LANGS = ["en", "tr", "de", "es", "fr", "ja", "ko", "zh"];
const ARCHIVE_ID = /^[A-Za-z0-9][A-Za-z0-9._-]{2,99}$/;
const PACKAGE_NAME = /^[A-Za-z0-9][A-Za-z0-9._-]{0,119}\.nxvapp$/;
const IMAGE_NAME = /^[A-Za-z0-9][A-Za-z0-9._-]{0,119}\.png$/;
const VERSION = /^(?:0|[1-9][0-9]*)(?:\.(?:0|[1-9][0-9]*)){2}$/;
const SOURCE_URL = /^https:\/\/[^\s"<>]{4,300}$/;
const SHA1 = /^[a-f0-9]{40}$/;
const SHA256 = /^[a-f0-9]{64}$/;
const SLUG = /^[a-z0-9][a-z0-9-]{0,39}$/;

const TAB_STORE = 0, TAB_ARCHIVE = 1, TAB_LOCAL = 2;
let sources = [], archiveRows = [], localRows = [];
let localFolder = "", selected = "", tab = TAB_STORE, scroll = 0;
let refreshing = false, transfer = null, status = "", failedSources = 0, refreshedAt = 0;
let dialogBusy = false;
// Store tab state.
let catalog = [], catalogLoading = false, catalogOffline = false, catalogLoaded = false, catalogAt = 0, savedCatalog = "";
let filter = 0, detail = "", shot = 0;
let installedCache = {};

// ---- catalog validation (the same rules as market_publish.check_listing in the publishing tool) ----

function itemId(value) {
    const result = String(value ?? "").trim().replace(/^https:\/\/archive\.org\/details\//, "").replace(/\/$/, "");
    return ARCHIVE_ID.test(result) && !result.includes("..") ? result : "";
}

function packageName(value) {
    return typeof value === "string" && PACKAGE_NAME.test(value) && !value.includes("..");
}

function textMap(value, limit) {
    const result = {};
    if (!value || typeof value !== "object" || Array.isArray(value)) return result;
    for (const lang of LANGS) {
        const text = value[lang];
        if (typeof text === "string" && text.trim()) result[lang] = text.split(/\s+/).filter(Boolean).join(" ").slice(0, limit);
    }
    return result;
}

function slugList(value, limit) {
    return Array.isArray(value) ? value.filter(item => typeof item === "string" && SLUG.test(item)).slice(0, limit) : [];
}

function shortText(value, limit) {
    return typeof value === "string" ? value.slice(0, limit) : "";
}

// Returns the listing the store shows, or null when the entry is invalid (the caller skips it).
function checkListing(entry) {
    if (!entry || typeof entry !== "object" || Array.isArray(entry) || entry.schema !== 1) return null;
    if (typeof entry.item !== "string" || !ARCHIVE_ID.test(entry.item) || entry.item.includes("..")) return null;
    if (entry.kind !== "game" && entry.kind !== "software") return null;
    if (typeof entry.version !== "string" || !VERSION.test(entry.version)) return null;
    if (typeof entry.file !== "string" || !PACKAGE_NAME.test(entry.file)) return null;
    if (!Number.isInteger(entry.size) || entry.size < 1 || entry.size >= MAX_BYTES) return null;
    if (typeof entry.sha256 !== "string" || !SHA256.test(entry.sha256)) return null;
    if (typeof entry.name !== "string" || !entry.name.trim() || entry.name.length > 160) return null;
    if (!Array.isArray(entry.screenshots) || entry.screenshots.length > 5) return null;
    const images = (entry.icon ? [entry.icon] : []).concat(entry.screenshots);
    if (images.some(image => typeof image !== "string" || !IMAGE_NAME.test(image))) return null;
    const source = entry.source ?? "";
    if (source && (typeof source !== "string" || !SOURCE_URL.test(source))) return null;
    const sdk = entry.sdk && typeof entry.sdk === "object" ? entry.sdk : {};
    return {
        schema: 1, item: entry.item, appId: shortText(entry.appId, 120), kind: entry.kind, category: shortText(entry.category, 40),
        name: entry.name.trim(), version: entry.version, file: entry.file, size: entry.size, sha256: entry.sha256,
        icon: entry.icon ? entry.icon : "", screenshots: entry.screenshots.slice(),
        subtitle: textMap(entry.subtitle, 160), description: textMap(entry.description, MAX_TEXT),
        tags: slugList(entry.tags, 16), features: slugList(entry.features, 8), age: shortText(entry.age, 24),
        license: shortText(entry.license, 64), source,
        sdk: { sdk: shortText(sdk.sdk, 16), native: shortText(sdk.native, 16) },
        updated: /^\d{4}-\d{2}-\d{2}$/.test(entry.updated ?? "") ? entry.updated : "",
    };
}

// Returns the valid listings of a catalog document, or null when the document itself is unusable.
function parseCatalog(data) {
    if (!data || typeof data !== "object" || data.schema !== 1 || !Array.isArray(data.apps)) return null;
    const seen = new Set(), apps = [];
    for (const entry of data.apps) {
        const listing = checkListing(entry);
        if (!listing || seen.has(listing.item)) continue;
        seen.add(listing.item);
        apps.push(listing);
        if (apps.length >= MAX_APPS) break;
    }
    return apps;
}

function compareVersions(a, b) {
    const x = a.split(".").map(Number), y = b.split(".").map(Number);
    for (let i = 0; i < 3; i++) if (x[i] !== y[i]) return x[i] < y[i] ? -1 : 1;
    return 0;
}

function pickText(map) {
    let lang = "en";
    try { lang = String(sys.lang() || "en"); } catch { /* keep en */ }
    return map[lang] || map.en || map.tr || Object.values(map)[0] || "";
}

function sizeText(bytes) {
    if (bytes < 1048576) return Math.max(1, Math.round(bytes / 1024)) + " KiB";  // small packages read as 0.0 MiB
    return (bytes / 1048576).toFixed(1) + " MiB";
}

function imageUrl(app, file) {
    return `${ARCHIVE}/download/${app.item}/${file}`;
}

function storeRow(app) {
    return { key: `store:${app.item}:${app.version}`, name: app.file, id: app.item, bytes: app.size, sha256: app.sha256,
        version: app.version, url: imageUrl(app, app.file), folder: `downloads/${app.item}/${app.version}` };
}

// Highest version of this item that is fully downloaded on the device ("" when none).
function installedVersion(item) {
    if (item in installedCache) return installedCache[item];
    let best = "";
    for (const folder of fs.list(`downloads/${item}`) ?? []) {
        if (!folder.dir || !VERSION.test(folder.name)) continue;
        const ready = (fs.list(`downloads/${item}/${folder.name}`) ?? []).some(file => !file.dir && packageName(file.name));
        if (ready && (!best || compareVersions(best, folder.name) < 0)) best = folder.name;
    }
    installedCache[item] = best;
    return best;
}

function updateAvailable(app) {
    const have = installedVersion(app.item);
    return !!have && compareVersions(have, app.version) < 0;
}

function loadCachedCatalog() {
    const saved = store.get("catalog", null);
    const apps = saved && typeof saved === "object" ? parseCatalog({ schema: 1, apps: saved.apps }) : null;
    if (apps) { catalog = apps; savedCatalog = JSON.stringify(apps); }
}

async function refreshCatalog() {
    if (catalogLoading) return;
    catalogLoading = true;
    try {
        const apps = parseCatalog(await net.fetchJson(CATALOG_URL));
        if (!apps) throw new Error("catalog format");
        catalog = apps;
        catalogOffline = false;
        const text = JSON.stringify(apps);
        if (text !== savedCatalog) { store.set("catalog", { apps }); savedCatalog = text; }
    } catch (error) {
        catalogOffline = true;
        sys.log("port-market catalog:", String(error?.message ?? error)); // the reason only, never catalog content
    } finally {
        catalogLoaded = true;
        catalogLoading = false;
        // a failed load is retried after 20 s, a good one after CATALOG_REFRESH_S
        catalogAt = catalogOffline ? sys.time() - (CATALOG_REFRESH_S - CATALOG_RETRY_S) : sys.time();
        installedCache = {};
    }
}

// ---- SHA-256 (small packages only) ----

const K256 = new Uint32Array([
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
]);

function sha256Hex(bytes) {
    const length = bytes.length;
    const padded = new Uint8Array(((length + 9 + 63) >> 6) << 6);
    padded.set(bytes);
    padded[length] = 0x80;
    const view = new DataView(padded.buffer);
    view.setUint32(padded.length - 8, Math.floor(length / 0x20000000));
    view.setUint32(padded.length - 4, (length << 3) >>> 0);
    const h = new Uint32Array([0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]);
    const w = new Uint32Array(64);
    const rotr = (x, n) => (x >>> n) | (x << (32 - n));
    for (let block = 0; block < padded.length; block += 64) {
        for (let i = 0; i < 16; i++) w[i] = view.getUint32(block + i * 4);
        for (let i = 16; i < 64; i++) {
            const s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
            const s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
            w[i] = (w[i - 16] + s0 + w[i - 7] + s1) | 0;
        }
        let [a, b, c, d, e, f, g, hh] = h;
        for (let i = 0; i < 64; i++) {
            const t1 = (hh + (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) + ((e & f) ^ (~e & g)) + K256[i] + w[i]) | 0;
            const t2 = ((rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) + ((a & b) ^ (a & c) ^ (b & c))) | 0;
            hh = g; g = f; f = e; e = (d + t1) | 0; d = c; c = b; b = a; a = (t1 + t2) | 0;
        }
        h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
    }
    return Array.from(h, word => word.toString(16).padStart(8, "0")).join("");
}

// ---- Internet Archive items (0.2.1) ----

function archiveFiles(id, response) {
    if (!response || response.error || !Array.isArray(response.result)) throw new Error("archive metadata");
    return response.result.flatMap(file => {
        const bytes = Number(file?.size);
        const sha1 = String(file?.sha1 ?? "").toLowerCase();
        if (file?.source !== "original" || !packageName(file.name) || !Number.isSafeInteger(bytes) ||
                bytes < 1 || bytes > MAX_BYTES || !SHA1.test(sha1)) return [];
        const version = file.name.match(/[-_]([0-9]+\.[0-9]+\.[0-9]+)(?:[-_]local)?\.nxvapp$/)?.[1] ?? "";
        return [{ key: `remote:${id}:${file.name}`, name: file.name, id, bytes, sha1, version,
            date: Number(file.mtime) || 0,
            url: `${ARCHIVE}/download/${id}/${encodeURIComponent(file.name)}`,
            folder: `downloads/${id}/${sha1}` }];
    });
}

async function refreshArchive() {
    if (refreshing || !sources.length) return;
    refreshing = true;
    failedSources = 0;
    const next = [];
    for (const id of sources) {
        try {
            const result = await net.fetchJson(`${ARCHIVE}/metadata/${id}/files?start=0&count=500`);
            next.push(...archiveFiles(id, result));
        } catch {
            failedSources += 1;
            next.push(...archiveRows.filter(row => row.id === id));
        }
    }
    archiveRows = next.sort((a, b) => b.date - a.date || a.name.localeCompare(b.name));
    refreshedAt = sys.time();
    refreshing = false;
}

async function addArchive() {
    if (dialogBusy || refreshing || sources.length >= MAX_ARCHIVES) return;
    dialogBusy = true;
    try {
        const input = await ui.prompt(TR("archive.add"), TR("archive.prompt"), "");
        if (input == null) return;
        const id = itemId(input);
        if (!id || sources.includes(id)) { status = TR("archive.invalid"); return; }
        sources = [...sources, id];
        store.set("archiveItems", sources);
        status = "";
        await refreshArchive();
    } catch {
        status = TR("archive.invalid");
    } finally {
        dialogBusy = false;
    }
}

function removeArchive(id) {
    if (refreshing || transfer?.row.id === id) return;
    sources = sources.filter(value => value !== id);
    archiveRows = archiveRows.filter(row => row.id !== id);
    store.set("archiveItems", sources);
    localSelectionReset();
    status = "";
    void refreshArchive();
}

function localSelectionReset() {
    selected = "";
    scroll = 0;
}

function refreshLocal() {
    localRows = [];
    if (!localFolder || !fs.folderGranted(localFolder)) return;
    const text = fs.read(`${localFolder}/port-market.tsv`);
    if (typeof text !== "string" || text.length > 262144) return;
    const lines = text.split(/\r?\n/);
    if (lines.shift() !== "NXVPORTMARKET\t1") return;
    const keys = new Set();
    for (const line of lines.slice(0, 256)) {
        const fields = line.split("\t");
        if (fields.length !== 7) continue;
        const [kind, name, version, size, , path, url] = fields;
        const parts = path.split("/");
        const [root] = parts;
        const file = parts[parts.length - 1];
        const validFolder = parts.length === 2 || (parts.length === 3 && /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(parts[1]));
        const bytes = Number(size);
        if (url || !name || name.length > 160 || !["game", "software"].includes(kind) ||
            root !== kind || !validFolder || !packageName(file) || !Number.isSafeInteger(bytes) || bytes < 1 ||
            !/^\d+\.\d+\.\d+$/.test(version) || keys.has(path)) continue;
        keys.add(path);
        localRows.push({ key: `local:${path}`, name, version, bytes, path: `${localFolder}/${path}` });
    }
}

async function chooseLocal() {
    if (dialogBusy) return;
    dialogBusy = true;
    try {
        const path = await ui.chooseFolder({ title: TR("library.choose"), remember: true });
        if (path) {
            localFolder = path.replace(/\/$/, "");
            store.set("library", localFolder);
            status = "";
            localSelectionReset();
            refreshLocal();
        }
    } catch {
        status = TR("library.save_failed");
    } finally {
        dialogBusy = false;
    }
}

// ---- download and open (shared by the Store and Archive items tabs) ----

function localPackageReady(row) {
    if (!row.url) return !!fs.folderGranted(localFolder) && fs.exists(row.path);
    const files = fs.list(row.folder) ?? [];
    return files.some(file => !file.dir && file.name === row.name && Number(file.size) === row.bytes);
}

function downloadedPath(row) {
    return `${row.folder}/${row.name}`;
}

async function download(row) {
    if (transfer) return;
    transfer = { row, bytes: 0 };
    status = "";
    const path = downloadedPath(row);
    const partial = path + ".part";
    try {
        if (fs.exists(partial)) fs.remove(partial, true);
        await net.download(row.url, partial, null, done => { transfer.bytes = done; });
        const files = fs.list(row.folder) ?? [];
        if (!files.some(file => !file.dir && file.name === row.name + ".part" && Number(file.size) === row.bytes)) {
            throw new Error("unexpected download size");
        }
        if (row.sha256 && row.bytes <= MAX_HASH_BYTES) {
            const data = fs.readBytes(partial);
            if (!data || sha256Hex(data) !== row.sha256) throw new Error("checksum mismatch");
        }
        if (fs.exists(path)) fs.remove(path, true);
        if (!fs.rename(partial, path)) throw new Error("rename failed");
        status = TR("download.ready");
    } catch {
        if (fs.exists(partial)) fs.remove(partial, true);
        status = TR("download.failed");
    } finally {
        transfer = null;
        installedCache = {};
    }
}

function openPackage(row) {
    if (!sys.open(row.url ? downloadedPath(row) : row.path)) status = TR("download.open_failed");
}

// ---- Store tab: immediate-mode widgets (gfx drawing, pointer and gamepad input) ----

const PAD = 16, CHIP_H = 36, ROW_H = 76, ICON_ROW = 56;
let widgets = [], lastWidgets = [], focusId = "", clickId = "", padMode = false, frame = 0, ensureId = "";
let area = { top: 0, bottom: 0 }, contentH = 0, pointer = null, lastNav = { name: "", frame: -9 };
let winW = 0, winH = 0;

function colorText(c) { gfx.color(c); }

function register(id, x, y, w, h, clipped) {
    widgets.push({ id, x, y, w, h, clipped: !!clipped });
}

function widgetAt(x, y) {
    for (let i = lastWidgets.length - 1; i >= 0; i--) {
        const item = lastWidgets[i];
        if (x < item.x || x >= item.x + item.w || y < item.y || y >= item.y + item.h) continue;
        if (item.clipped && (y < area.top || y >= area.bottom)) continue;
        return item;
    }
    return null;
}

// Draws a button and returns true on the frame it was activated. `inArea` buttons live in the scrolling area.
function drawButton(id, x, y, w, label, style, inArea, h = CHIP_H) {
    register(id, x, y, w, h, inArea);
    if (inArea && ensureId === id) ensureVisible(y, h);
    const primary = style === "primary", active = style === "active";
    gfx.rect(x, y, w, h, 8, primary || active ? theme.accent : theme.control);
    gfx.color(primary || active ? "#ffffff" : theme.text);
    gfx.text(label, x, y + (h - gfx.textHeight(14, "medium")) / 2, 14, "medium", "center", w);
    if (padMode && focusId === id) {
        gfx.color(theme.accent);
        gfx.rectLine(x - 3, y - 3, w + 6, h + 6, 10, 2);
    }
    const hit = clickId === id;
    if (hit) clickId = "";
    return hit;
}

function buttonWidth(label) {
    return Math.ceil(gfx.textWidth(label, 14, "medium")) + 28;
}

function ensureVisible(y, h) {
    if (y < area.top) scroll -= area.top - y;
    else if (y + h > area.bottom) scroll += y + h - area.bottom;
    ensureId = "";
}

function clampScroll() {
    scroll = Math.max(0, Math.min(scroll, Math.max(0, contentH - (area.bottom - area.top))));
}

function navigate(direction) {
    if (!lastWidgets.length) return;
    const current = lastWidgets.find(item => item.id === focusId);
    if (!current) {
        focusId = lastWidgets[0].id;
        ensureId = focusId;
        return;
    }
    const cx = current.x + current.w / 2, cy = current.y + current.h / 2;
    let best = null, bestScore = Infinity;
    for (const item of lastWidgets) {
        if (item === current) continue;
        const dx = item.x + item.w / 2 - cx, dy = item.y + item.h / 2 - cy;
        const ahead = direction === "up" ? -dy : direction === "down" ? dy : direction === "left" ? -dx : dx;
        if (ahead <= 4) continue;
        const across = direction === "up" || direction === "down" ? Math.abs(dx) : Math.abs(dy);
        const score = ahead + across * 3;
        if (score < bestScore) { best = item; bestScore = score; }
    }
    if (best) { focusId = best.id; ensureId = best.id; }
}

function activateFocus() {
    if (focusId && lastWidgets.some(item => item.id === focusId)) clickId = focusId;
}

function goBack() {
    if (detail) { detail = ""; shot = 0; scroll = 0; status = ""; ensureId = ""; focusId = ""; }
}

function nav(name, action) {
    if (lastNav.name === name && frame - lastNav.frame <= 1) { lastNav.frame = frame; return; }
    lastNav = { name, frame };
    padMode = true;
    action();
}

function selectTab(next) {
    if (next === tab) return;
    tab = next;
    detail = "";
    shot = 0;
    localSelectionReset();
    status = "";
    focusId = "";
}

app.event = e => {
    if (tab !== TAB_STORE) return;
    if (e.type === "mousedown" && (e.button === undefined || e.button === "left")) {
        pointer = { x: e.x, y: e.y, startY: e.y, start: scroll, moved: false };
    } else if (e.type === "mousemove" && pointer) {
        if (!pointer.moved && Math.abs(e.y - pointer.startY) > 10) pointer.moved = true;
        if (pointer.moved && pointer.y >= area.top) { scroll = pointer.start - (e.y - pointer.startY); clampScroll(); }
    } else if (e.type === "mouseup" && pointer) {
        const moved = pointer.moved || e.cancel;
        pointer = null;
        padMode = false;
        if (!moved) {
            const hit = widgetAt(e.x, e.y);
            if (hit) { clickId = hit.id; focusId = hit.id; }
        }
    } else if (e.type === "scroll") {
        scroll -= (e.dy || 0);
        clampScroll();
    } else if (e.type === "paddown") {
        const pad = e.pad;
        if (["up", "down", "left", "right"].includes(pad)) nav(pad, () => navigate(pad));
        else if (pad === "a") nav("a", activateFocus);
        else if (pad === "b") nav("b", goBack);
        else if (pad === "l") nav("l", () => selectTab((tab + 2) % 3));
        else if (pad === "r") nav("r", () => selectTab((tab + 1) % 3));
    } else if (e.type === "keydown") {
        const key = e.key;
        if (["up", "down", "left", "right"].includes(key)) nav(key, () => navigate(key));
        else if (key === "enter" || key === "space") nav("a", activateFocus);
        else if (key === "escape" || key === "backspace") nav("b", goBack);
    }
};

function drawIcon(app, x, y, size) {
    const img = app.icon ? gfx.imageUrl(imageUrl(app, app.icon), 96) : null;
    if (img) gfx.draw(img, x, y, size, size, 12);
    else {
        gfx.rect(x, y, size, size, 12, theme.control);
        gfx.color(theme.text3);
        gfx.text((app.name[0] ?? "?").toUpperCase(), x, y + (size - gfx.textHeight(size * 0.45, "bold")) / 2, size * 0.45, "bold", "center", size);
    }
}

function fitText(text, size, font, maxWidth) {
    if (gfx.textWidth(text, size, font) <= maxWidth) return text;
    let cut = text.length;
    while (cut > 1 && gfx.textWidth(text.slice(0, cut) + "…", size, font) > maxWidth) cut--;
    return text.slice(0, cut) + "…";
}

function drawHeader(w) {
    let x = PAD;
    const labels = [["tab.store", TAB_STORE], ["item.archive", TAB_ARCHIVE], ["item.local", TAB_LOCAL]];
    for (const [key, index] of labels) {
        const label = TR(key), bw = buttonWidth(label);
        if (drawButton("tab:" + index, x, 12, bw, label, tab === index ? "active" : "plain", false)) selectTab(index);
        x += bw + 8;
    }
}

function storeStatusLine() {
    if (transfer) {
        const pct = Math.min(100, Math.round(100 * transfer.bytes / transfer.row.bytes));
        return `${TR("download.progress")} ${pct}% · ${transfer.row.name}`;
    }
    if (status) return status;
    if (catalogLoading && !catalog.length) return TR("store.loading");
    if (catalogOffline) return TR(catalog.length ? "store.offline" : "store.unavailable");
    return "";
}

function drawStoreList(w, h) {
    // Filter chips and refresh.
    let x = PAD;
    const filters = [["filter.all", 0], ["filter.game", 1], ["filter.software", 2]];
    for (const [key, index] of filters) {
        const label = TR(key), bw = buttonWidth(label);
        if (drawButton("filter:" + index, x, 60, bw, label, filter === index ? "active" : "plain", false)) { filter = index; scroll = 0; }
        x += bw + 8;
    }
    const refreshLabel = TR("library.refresh"), rw = buttonWidth(refreshLabel);
    if (!catalogLoading && drawButton("refresh", w - PAD - rw, 60, rw, refreshLabel, "plain", false)) void refreshCatalog();
    const line = storeStatusLine();
    area = { top: 112, bottom: h };
    if (line) {
        colorText(catalogOffline ? theme.orange : theme.text2);
        gfx.text(fitText(line, 12, "medium", w - 2 * PAD), PAD, 108, 12, "medium");
        area.top = 130;
    }
    const apps = catalog.filter(app => filter === 0 || app.kind === (filter === 1 ? "game" : "software"));
    contentH = apps.length * ROW_H;
    clampScroll();
    gfx.clip(0, area.top, w, area.bottom - area.top);
    apps.forEach((app, index) => {
        const y = area.top + index * ROW_H - scroll;
        const id = "app:" + app.item;
        register(id, PAD, y, w - 2 * PAD, ROW_H - 6, true);
        if (ensureId === id) ensureVisible(y, ROW_H - 6);
        if (y + ROW_H < area.top || y > area.bottom) { if (clickId === id) { clickId = ""; detail = app.item; shot = 0; scroll = 0; } return; }
        gfx.rect(PAD, y, w - 2 * PAD, ROW_H - 6, 10, padMode && focusId === id ? theme.selection : theme.control);
        drawIcon(app, PAD + 10, y + (ROW_H - 6 - ICON_ROW) / 2, ICON_ROW);
        const textX = PAD + 10 + ICON_ROW + 14;
        const metaW = Math.min(180, (w - 2 * PAD) * 0.3);
        const textW = w - PAD - 10 - metaW - textX;
        colorText(theme.text);
        gfx.text(fitText(app.name, 15, "semibold", textW), textX, y + 10, 15, "semibold");
        colorText(theme.text2);
        gfx.text(fitText(pickText(app.subtitle), 12, "sans", textW), textX, y + 34, 12, "sans");
        const meta = [`v${app.version}`, sizeText(app.size)];
        gfx.text(meta.join(" · "), w - PAD - 10 - metaW, y + 10, 12, "medium", "right", metaW);
        gfx.text(TR(app.kind === "game" ? "kind.game" : "kind.software"), w - PAD - 10 - metaW, y + 34, 12, "sans", "right", metaW);
        if (updateAvailable(app)) {
            colorText(theme.accent);
            gfx.text(TR("detail.update"), textX, y + 50, 11, "semibold");
        }
        if (padMode && focusId === id) { gfx.color(theme.accent); gfx.rectLine(PAD - 2, y - 2, w - 2 * PAD + 4, ROW_H - 2, 12, 2); }
        if (clickId === id) { clickId = ""; detail = app.item; shot = 0; scroll = 0; status = ""; focusId = ""; }
    });
    gfx.unclip();
    if (!apps.length && !catalogLoading) {
        colorText(theme.text2);
        gfx.text(TR(catalogOffline && !catalog.length ? "store.unavailable" : "store.empty"), PAD, area.top + 16, 14, "sans");
    }
}

function drawShots(app, x, y, w, h) {
    gfx.rect(x, y, w, h, 10, theme.control);
    const list = app.screenshots;
    if (!list.length) return;
    const index = Math.min(shot, list.length - 1);
    const url = imageUrl(app, list[index]);
    const img = gfx.imageUrl(url, 640);
    if (img) {
        const scale = Math.min(w / img.width, h / img.height);
        const dw = Math.round(img.width * scale), dh = Math.round(img.height * scale);
        gfx.draw(img, x + (w - dw) / 2, y + (h - dh) / 2, dw, dh, 8);
    } else {
        colorText(theme.text3);
        gfx.text(TR("store.loading"), x, y + h / 2 - 8, 13, "medium", "center", w);
    }
}

function drawDetail(app, w, h) {
    const row = storeRow(app);
    const back = TR("detail.back");
    if (drawButton("back", PAD, 60, buttonWidth(back), back, "plain", false)) goBack();
    area = { top: 108, bottom: h };
    const cw = Math.min(w - 2 * PAD, 760), cx = PAD;
    const stateOf = () => transfer?.row.key === row.key ? "busy" : localPackageReady(row) ? "ready" : "idle";
    let y = area.top - scroll;
    gfx.clip(0, area.top, w, area.bottom - area.top);
    // Header: icon, name, meta.
    drawIcon(app, cx, y, 96);
    const tx = cx + 112, tw = cw - 112;
    colorText(theme.text);
    gfx.text(fitText(app.name, 22, "bold", tw), tx, y + 2, 22, "bold");
    colorText(theme.text2);
    gfx.text(fitText(pickText(app.subtitle), 13, "sans", tw), tx, y + 32, 13, "sans");
    const info = [`${TR("item.version")} ${app.version}`, sizeText(app.size), app.category, app.age].filter(Boolean).join(" · ");
    gfx.text(fitText(info, 12, "medium", tw), tx, y + 54, 12, "medium");
    if (updateAvailable(app)) {
        colorText(theme.accent);
        gfx.text(TR("detail.update"), tx, y + 74, 12, "semibold");
    } else if (installedVersion(app.item)) {
        colorText(theme.green);
        gfx.text(TR("detail.installed"), tx, y + 74, 12, "semibold");
    }
    y += 112;
    // Action.
    const state = stateOf();
    if (state === "busy") {
        const pct = Math.min(100, Math.round(100 * transfer.bytes / row.bytes));
        gfx.rect(cx, y, Math.min(cw, 360), CHIP_H, 8, theme.control);
        gfx.rect(cx, y, Math.max(8, Math.min(cw, 360) * pct / 100), CHIP_H, 8, theme.accent);
        colorText(pct > 50 ? "#ffffff" : theme.text);
        gfx.text(`${TR("download.progress")} ${pct}%`, cx, y + 9, 14, "medium", "center", Math.min(cw, 360));
    } else if (state === "ready") {
        const label = TR("detail.install");
        if (drawButton("action", cx, y, Math.max(buttonWidth(label), 200), label, "primary", true)) openPackage(row);
    } else {
        const label = TR("download.start");
        if (drawButton("action", cx, y, Math.max(buttonWidth(label), 200), label, "primary", true)) void download(row);
    }
    y += CHIP_H + 8;
    const line = storeStatusLine();
    if (line && !transfer) {
        colorText(theme.text2);
        gfx.text(fitText(line, 12, "medium", cw), cx, y, 12, "medium");
    }
    y += 24;
    // Screenshots.
    if (app.screenshots.length) {
        colorText(theme.text);
        gfx.text(TR("detail.screens"), cx, y, 15, "semibold");
        y += 26;
        const sh = Math.round(Math.min(cw, 640) * 9 / 16), sw = Math.round(sh * 16 / 9);
        register("shot", cx, y, sw, sh, true);
        drawShots(app, cx, y, sw, sh);
        if (clickId === "shot") { clickId = ""; shot = (shot + 1) % app.screenshots.length; }
        y += sh + 8;
        if (app.screenshots.length > 1) {
            const prev = TR("detail.prev"), next = TR("detail.next");
            if (drawButton("shot-prev", cx, y, buttonWidth(prev), prev, "plain", true))
                shot = (shot + app.screenshots.length - 1) % app.screenshots.length;
            const nx = cx + buttonWidth(prev) + 8;
            if (drawButton("shot-next", nx, y, buttonWidth(next), next, "plain", true)) shot = (shot + 1) % app.screenshots.length;
            colorText(theme.text2);
            gfx.text(`${shot + 1} / ${app.screenshots.length}`, nx + buttonWidth(next) + 12, y + 10, 13, "medium");
            y += CHIP_H + 8;
        }
        y += 8;
    }
    // Description.
    const description = pickText(app.description);
    if (description) {
        colorText(theme.text);
        gfx.text(TR("detail.about"), cx, y, 15, "semibold");
        y += 26;
        colorText(theme.text2);
        y += gfx.wrap(description, cx, y, cw, 13, "sans") + 16;
    }
    // Info block.
    const facts = [
        [TR("detail.sdk"), app.sdk.sdk ? `${app.sdk.sdk}${app.sdk.native ? " / " + TR("detail.native") + " " + app.sdk.native : ""}` : ""],
        [TR("detail.license"), app.license], [TR("detail.updated"), app.updated],
    ].filter(entry => entry[1]);
    for (const [label, value] of facts) {
        colorText(theme.text3);
        gfx.text(label, cx, y, 12, "medium");
        colorText(theme.text);
        gfx.text(fitText(value, 13, "sans", cw - 130), cx + 120, y - 1, 13, "sans");
        y += 22;
    }
    y += 8;
    if (app.source) {
        const label = TR("detail.source");
        if (drawButton("source", cx, y, Math.max(buttonWidth(label), 160), label, "plain", true)) {
            status = sys.clipboard(app.source) === false ? TR("action.copy_failed") : TR("detail.source_copied");
        }
        y += CHIP_H + 8;
    }
    gfx.unclip();
    contentH = y + scroll - area.top + PAD;
    clampScroll();
}

function drawStore(w, h) {
    drawHeader(w);
    const app = detail ? catalog.find(value => value.item === detail) : null;
    if (detail && !app) detail = "";
    if (app) drawDetail(app, w, h);
    else drawStoreList(w, h);
}

// ---- app lifecycle ----

app.load = () => {
    const saved = store.get("archiveItems", []);
    if (Array.isArray(saved)) sources = [...new Set(saved.map(itemId).filter(Boolean))].slice(0, MAX_ARCHIVES);
    const folder = store.get("library", "");
    localFolder = typeof folder === "string" ? folder : "";
    refreshLocal();
    loadCachedCatalog();
    void refreshCatalog();
    void refreshArchive();
};

app.update = () => {
    if (!refreshing && sources.length && sys.time() - refreshedAt >= 300) void refreshArchive();
    if (!catalogLoading && catalogLoaded && sys.time() - catalogAt >= CATALOG_REFRESH_S) void refreshCatalog();
};

function drawArchiveLocal(w, h) {
    nxui.begin(w, h);
    nxui.column("port-market");
    nxui.label("title", TR("app.title"), "title");
    nxui.row("source-tabs");
    let nextTab = tab;
    if (nxui.button("store-tab", TR("tab.store"), "plain")) nextTab = TAB_STORE;
    if (nxui.button("archive-tab", TR("item.archive"), tab === TAB_ARCHIVE ? "primary" : "plain")) nextTab = TAB_ARCHIVE;
    if (nxui.button("local-tab", TR("item.local"), tab === TAB_LOCAL ? "primary" : "plain")) nextTab = TAB_LOCAL;
    nxui.rowEnd();
    if (nextTab !== tab) {
        selectTab(nextTab);
        nxui.columnEnd();
        nxui.endFrame();
        return;
    }
    nxui.row("toolbar");
    if (tab === TAB_ARCHIVE && !refreshing && sources.length < MAX_ARCHIVES &&
            nxui.button("add", TR("archive.add"), "primary")) void addArchive();
    if (tab === TAB_LOCAL && nxui.button("choose", TR("library.choose"), "primary")) void chooseLocal();
    if (!refreshing && nxui.button("refresh", TR("library.refresh"))) {
        status = "";
        if (tab === TAB_ARCHIVE) void refreshArchive();
        else refreshLocal();
    }
    nxui.rowEnd();

    if (refreshing) nxui.label("sync", TR("archive.sync"), "caption");
    else if (tab === TAB_ARCHIVE && failedSources) nxui.label("sync-error", TR("archive.failed"), "caption");
    if (status) nxui.label("status", status, "caption");
    if (transfer) {
        const pct = Math.min(100, Math.round(100 * transfer.bytes / transfer.row.bytes));
        nxui.label("transfer", `${TR("download.progress")} ${pct}% · ${transfer.row.name}`, "caption");
    }

    const rows = tab === TAB_ARCHIVE ? archiveRows : localRows;
    const row = rows.find(value => value.key === selected);
    if (row) {
        nxui.card("package");
        nxui.label("package-name", row.name, "headline");
        const size = sizeText(row.bytes);
        nxui.label("package-meta", row.version ? `${TR("item.version")} ${row.version} · ${size}` : size, "caption");
        const ready = localPackageReady(row);
        if (ready && nxui.button("open", TR("download.open"), "primary")) openPackage(row);
        if (!ready && row.url && !transfer && nxui.button("download", TR("download.start"), "primary")) void download(row);
        if (!ready && !row.url) nxui.label("missing", TR("item.local_missing"), "caption");
        nxui.cardEnd();
    }
    if (!rows.length && !(tab === TAB_ARCHIVE && refreshing)) {
        const key = tab === TAB_ARCHIVE && !sources.length ? "archive.hint" :
            tab === TAB_LOCAL && !localFolder ? "library.choose_hint" : "library.empty";
        nxui.label("empty", TR(key));
    }
    const canScroll = typeof nxui.scrollBegin === "function" && typeof nxui.scrollEnd === "function";
    if (canScroll) scroll = nxui.scrollBegin("catalog", Math.max(120, w - 32), Math.max(100, h - (row ? 260 : 162)), scroll);
    for (const value of rows.slice(0, canScroll ? 256 : 4)) {
        if (nxui.button(value.key, value.name, value.key === selected ? "primary" : "plain")) selected = value.key;
    }
    if (tab === TAB_ARCHIVE && sources.length) {
        nxui.label("source-list", TR("archive.items"), "caption");
        for (const id of sources) {
            nxui.row("source:" + id);
            nxui.label("name:" + id, id, "body");
            if (!refreshing && transfer?.row.id !== id &&
                    nxui.button("remove:" + id, TR("archive.remove"), "plain")) removeArchive(id);
            nxui.rowEnd();
        }
    }
    if (canScroll) nxui.scrollEnd();
    nxui.columnEnd();
    nxui.endFrame();
}

app.draw = (w, h) => {
    gfx.clear(theme.window ?? theme.bg);
    frame += 1;
    winW = w;
    winH = h;
    if (tab === TAB_STORE) {
        lastWidgets = widgets;
        widgets = [];
        drawStore(w, h);
        if (!focusId && padMode && lastWidgets.length) focusId = lastWidgets[0].id;
    } else {
        drawArchiveLocal(w, h);
    }
};
