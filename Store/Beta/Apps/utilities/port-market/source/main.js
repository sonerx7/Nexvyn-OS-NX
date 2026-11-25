// Port Market 0.3.1 — Nexvyn OS SDK 1.15.
// Store tab: custom gfx layout (nxui cannot report a widget rectangle, so icons and screenshots are drawn here):
// featured banner, New row, card grid, search and a detail page with a screenshot carousel.
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
        whatsNew: textMap(entry.whatsNew, 600), // optional release notes
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
        imageFailed.clear(); // failed images are tried again after each refresh
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

// ---- Store tab: search, filter and featured selection (pure logic, tested) ----

// Lower-case words of a search query; an empty query matches everything.
function queryWords(query) {
    return String(query ?? "").toLowerCase().split(/\s+/).filter(Boolean).slice(0, 8);
}

// The text a query is matched against: name, subtitles in every language, category, tags and kind.
function searchText(app) {
    if (app._search === undefined) {
        const parts = [app.name, app.category, app.kind, ...app.tags, ...Object.values(app.subtitle)];
        Object.defineProperty(app, "_search", { value: parts.join(" ").toLowerCase(), enumerable: false });
    }
    return app._search;
}

// kind: 0 all, 1 games, 2 software. Every query word must appear; catalog order is kept.
function filterApps(apps, kind, query) {
    const words = queryWords(query);
    return apps.filter(app => (kind === 0 || app.kind === (kind === 1 ? "game" : "software")) &&
        words.every(word => searchText(app).includes(word)));
}

// Newest first by the `updated` date; listings without a date keep catalog order after the dated ones.
function newestApps(apps, count) {
    return apps.map((app, index) => ({ app, index }))
        .sort((a, b) => (b.app.updated || "").localeCompare(a.app.updated || "") || a.index - b.index)
        .slice(0, count).map(entry => entry.app);
}

// The hero listing: the newest one that has a screenshot, else the newest one.
function featuredApp(apps) {
    const ordered = newestApps(apps, apps.length);
    return ordered.find(app => app.screenshots.length) ?? ordered[0] ?? null;
}

// ---- Store tab: immediate-mode widgets (gfx drawing, pointer and gamepad input) ----

const PAD = 16, TOP_H = 60, CTRL_H = 36, CHIP_H = 32, CARD_H = 92, CARD_MIN_W = 250, GAP = 16;
const HERO_TOP = "#1B2540", HERO_BOTTOM = "#0D111B", HERO_TEXT2 = "#C5CDDD", HERO_TEXT3 = "#8E9AB2";
let widgets = [], lastWidgets = [], focusId = "", clickId = "", padMode = false, frame = 0, ensureId = "";
let area = { top: 0, bottom: 0 }, contentH = 0, pointer = null, lastNav = { name: "", frame: -9 };
let winW = 0, winH = 0, hoverId = "", hoverAt = null, scrollGoal = null, ring = null;
let query = "";
const imageCache = new Map(), imageFailed = new Set(), fitCache = new Map(), tileColors = new Map();

function colorText(c) { gfx.color(c); }

// Adds an alpha byte to a "#rrggbb" theme color (theme colors with their own alpha are returned unchanged).
function tint(hex, alpha) {
    return typeof hex === "string" && hex.length === 7 ? hex + alpha : hex;
}

// One cached image per URL: gfx.imageUrl returns null while loading; a failed load shows a fallback.
function cachedImage(url, size) {
    const key = url + "@" + size;
    const hit = imageCache.get(key);
    if (hit) return hit;
    if (imageFailed.has(key)) return null;
    const img = gfx.imageUrl(url, size);
    if (img) imageCache.set(key, img);
    else if (typeof gfx.imageState === "function" && String(gfx.imageState(url, size)).startsWith("error")) imageFailed.add(key);
    return img;
}

function imageBroken(url, size) {
    return imageFailed.has(url + "@" + size);
}

function clearImageState() {
    imageCache.clear();
    imageFailed.clear();
}

// `focus` false: a pointer target only (page dots), skipped by gamepad navigation.
function register(id, x, y, w, h, clipped, radius = 10, focus = true) {
    widgets.push({ id, x, y, w, h, clipped: !!clipped, radius, focus });
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

function hovered(id) {
    return !padMode && hoverId === id;
}

function takeClick(id) {
    if (clickId !== id) return false;
    clickId = "";
    return true;
}

// Draws a button and returns true on the frame it was activated. `inArea` buttons live in the scrolling area.
// Styles: primary (accent), active (selected chip), plain (surface), light (white on the dark hero), ghost (no fill).
function drawButton(id, x, y, w, label, style, inArea, h = CTRL_H, icon = "") {
    const radius = h / 2;
    register(id, x, y, w, h, inArea, radius);
    if (inArea && ensureId === id) ensureVisible(y, h);
    const hot = hovered(id);
    let fill = theme.control, ink = theme.text;
    if (style === "primary" || style === "active") { fill = hot ? theme.accentHover ?? theme.accent : theme.accent; ink = "#ffffff"; }
    else if (style === "light") { fill = hot ? "#E8EEFF" : "#ffffff"; ink = theme.accent; }
    else if (style === "ghost") { fill = hot ? theme.hover : ""; ink = theme.text; }
    else if (hot) fill = theme.surfaceHover ?? theme.control;
    if (fill) gfx.rect(x, y, w, h, radius, fill);
    if (style === "plain") { gfx.color(theme.border ?? theme.separator); gfx.rectLine(x, y, w, h, radius, 1); }
    const size = h <= CHIP_H ? 13 : 14;
    const textW = gfx.textWidth(label, size, "semibold");
    const iconW = icon ? 18 + (label ? 6 : 0) : 0;
    let tx = x + (w - textW - iconW) / 2;
    if (icon) { gfx.icon(icon, tx + 9, y + h / 2, 18, ink); tx += iconW; }
    if (label) { gfx.color(ink); gfx.text(label, tx, y + (h - gfx.textHeight(size, "semibold")) / 2, size, "semibold"); }
    return takeClick(id);
}

function buttonWidth(label, icon = false, h = CTRL_H) {
    return Math.ceil(gfx.textWidth(label, h <= CHIP_H ? 13 : 14, "semibold")) + (h <= CHIP_H ? 28 : 36) + (icon ? 24 : 0);
}

function ensureVisible(y, h) {
    const margin = 12;
    let goal = scrollGoal ?? scroll;
    if (y - margin < area.top) goal = scroll - (area.top - y + margin);
    else if (y + h + margin > area.bottom) goal = scroll + (y + h + margin - area.bottom);
    scrollGoal = Math.max(0, goal);
    ensureId = "";
}

function clampScroll() {
    scroll = Math.max(0, Math.min(scroll, Math.max(0, contentH - (area.bottom - area.top))));
}

// Gamepad scrolling eases toward its goal instead of jumping.
function stepScroll() {
    if (scrollGoal === null) return;
    const limit = Math.max(0, contentH - (area.bottom - area.top));
    const goal = Math.max(0, Math.min(scrollGoal, limit));
    const diff = goal - scroll;
    if (Math.abs(diff) < 0.5) { scroll = goal; scrollGoal = null; }
    else scroll += diff * 0.3;
}

function navigate(direction) {
    const targets = lastWidgets.filter(item => item.focus);
    if (!targets.length) return;
    const current = targets.find(item => item.id === focusId);
    if (!current) {
        focusId = targets[0].id;
        ensureId = focusId;
        return;
    }
    const cx = current.x + current.w / 2, cy = current.y + current.h / 2;
    let best = null, bestScore = Infinity;
    for (const item of targets) {
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

function openDetail(app) {
    detail = app.item; shot = 0; scroll = 0; scrollGoal = null; status = ""; focusId = ""; ring = null;
}

function goBack() {
    if (detail) { detail = ""; shot = 0; scroll = 0; scrollGoal = null; status = ""; ensureId = ""; focusId = ""; ring = null; }
    else if (query) setQuery("");
}

function setQuery(text) {
    query = String(text ?? "").replace(/\s+/g, " ").trim().slice(0, 60);
    scroll = 0; scrollGoal = null; focusId = ""; ring = null;
}

async function askSearch() {
    if (dialogBusy) return;
    dialogBusy = true;
    try {
        const input = await ui.prompt(TR("search.title"), TR("search.prompt"), query);
        if (input != null) { setQuery(input); detail = ""; }
    } catch {
        /* the dialog was closed */
    } finally {
        dialogBusy = false;
    }
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
    ring = null;
    scrollGoal = null;
}

app.event = e => {
    if (tab !== TAB_STORE) return;
    if (e.type === "mousedown" && (e.button === undefined || e.button === "left")) {
        pointer = { x: e.x, y: e.y, startY: e.y, start: scroll, moved: false };
        scrollGoal = null;
    } else if (e.type === "mousemove") {
        hoverAt = e.touch ? null : { x: e.x, y: e.y };
        if (!e.touch) padMode = false;
        if (pointer) {
            if (!pointer.moved && Math.abs(e.y - pointer.startY) > 10) pointer.moved = true;
            if (pointer.moved && pointer.y >= area.top) { scroll = pointer.start - (e.y - pointer.startY); clampScroll(); }
        }
    } else if (e.type === "mouseup" && pointer) {
        const moved = pointer.moved || e.cancel;
        pointer = null;
        padMode = false;
        if (e.touch) hoverAt = null;
        if (!moved) {
            const hit = widgetAt(e.x, e.y);
            if (hit) { clickId = hit.id; focusId = hit.id; }
        }
    } else if (e.type === "scroll") {
        scrollGoal = null;
        scroll -= (e.dy || 0);
        clampScroll();
    } else if (e.type === "paddown") {
        const pad = e.pad;
        if (["up", "down", "left", "right"].includes(pad)) nav(pad, () => navigate(pad));
        else if (pad === "a") nav("a", activateFocus);
        else if (pad === "b") nav("b", goBack);
        else if (pad === "y") nav("y", () => void askSearch());
        else if (pad === "l") nav("l", () => selectTab((tab + 2) % 3));
        else if (pad === "r") nav("r", () => selectTab((tab + 1) % 3));
    } else if (e.type === "keydown") {
        const key = e.key;
        if (["up", "down", "left", "right"].includes(key)) nav(key, () => navigate(key));
        else if (key === "enter" || key === "space") nav("a", activateFocus);
        else if (key === "escape" || key === "backspace") nav("b", goBack);
    }
};

// ---- Store tab: drawing helpers ----

function fitText(text, size, font, maxWidth) {
    const key = `${size}|${font}|${Math.floor(maxWidth)}|${text}`;
    const hit = fitCache.get(key);
    if (hit !== undefined) return hit;
    let result = text;
    if (maxWidth <= 0) result = "";
    else if (gfx.textWidth(text, size, font) > maxWidth) {
        let cut = text.length;
        while (cut > 1 && gfx.textWidth(text.slice(0, cut) + "…", size, font) > maxWidth) cut--;
        result = text.slice(0, cut) + "…";
    }
    if (fitCache.size > 600) fitCache.clear();
    fitCache.set(key, result);
    return result;
}

function shade(hex, amount) {
    const value = parseInt(String(hex).slice(1, 7), 16);
    if (!Number.isFinite(value)) return hex;
    const part = shift => Math.max(0, Math.min(255, Math.round(((value >> shift) & 255) * (1 + amount))));
    return "#" + [16, 8, 0].map(shift => part(shift).toString(16).padStart(2, "0")).join("");
}

// A stable color per listing for letter tiles (when the listing has no icon or it failed to load).
function tileColor(app) {
    let color = tileColors.get(app.item);
    if (!color) {
        const palette = [theme.blue, theme.purple, theme.pink, theme.orange, theme.green, theme.red];
        let hash = 0;
        for (const ch of app.item) hash = (hash * 31 + ch.charCodeAt(0)) >>> 0;
        color = palette[hash % palette.length] || theme.accent;
        tileColors.set(app.item, color);
    }
    return color;
}

// Pulsing placeholder while an image loads.
function skeleton(x, y, w, h, r) {
    gfx.alpha(0.55 + 0.25 * Math.sin(frame / 14));
    gfx.rect(x, y, w, h, r, theme.dark ? "#ffffff1a" : "#0000000f");
    gfx.unalpha();
}

function drawIcon(app, x, y, size, shadow = false) {
    const r = Math.round(size * 0.23);
    const url = app.icon ? imageUrl(app, app.icon) : "";
    const img = url ? cachedImage(url, 128) : null;
    if (shadow) gfx.shadow(x, y, size, size, r, 10, 3);
    if (img) { gfx.draw(img, x, y, size, size, r); return; }
    if (url && !imageBroken(url, 128)) { gfx.rect(x, y, size, size, r, theme.control); skeleton(x, y, size, size, r); return; }
    const color = tileColor(app);
    gfx.gradient(x, y, size, size, shade(color, 0.12), shade(color, -0.28), false, r);
    gfx.color("#ffffff");
    gfx.text((app.name[0] ?? "?").toUpperCase(), x, y + (size - gfx.textHeight(size * 0.46, "bold")) / 2, size * 0.46, "bold", "center", size);
}

// Draws a screenshot to fit (x, y, w, h); returns false while it is still loading.
function drawScreenshot(app, file, x, y, w, h, r) {
    const url = imageUrl(app, file);
    const img = cachedImage(url, 640);
    if (img) {
        const scale = Math.min(w / img.width, h / img.height);
        const dw = Math.round(img.width * scale), dh = Math.round(img.height * scale);
        gfx.draw(img, x + (w - dw) / 2, y + (h - dh) / 2, dw, dh, r);
        return true;
    }
    if (imageBroken(url, 640)) {
        gfx.rect(x, y, w, h, r, theme.dark ? "#ffffff12" : "#0000000a");
        gfx.icon("hide_image", x + w / 2, y + h / 2, 32, theme.text3);
    } else skeleton(x, y, w, h, r);
    return false;
}

function kindColor(app) {
    return app.kind === "game" ? theme.purple : theme.blue;
}

function kindLabel(app) {
    return TR(app.kind === "game" ? "kind.game" : "kind.software");
}

// Small rounded label; returns its width.
function drawPill(text, x, y, color, fill) {
    const w = Math.ceil(gfx.textWidth(text, 11, "semibold")) + 16;
    gfx.rect(x, y, w, 20, 10, fill ?? tint(color, "24"));
    gfx.color(color);
    gfx.text(text, x + 8, y + (20 - gfx.textHeight(11, "semibold")) / 2, 11, "semibold");
    return w;
}

function sectionHeader(title, x, y, count = -1) {
    colorText(theme.text);
    const tw = gfx.text(title, x, y, 18, "bold");
    if (count >= 0) {
        gfx.rect(x + tw + 10, y + 3, Math.ceil(gfx.textWidth(String(count), 11, "semibold")) + 14, 20, 10, theme.control);
        colorText(theme.text2);
        gfx.text(String(count), x + tw + 17, y + 3 + (20 - gfx.textHeight(11, "semibold")) / 2, 11, "semibold");
    }
}

// Top bar: tab segments, search field and refresh. Fixed; never scrolls.
function drawTopBar(w) {
    const labels = [["tab.store", TAB_STORE], ["item.archive", TAB_ARCHIVE], ["item.local", TAB_LOCAL]];
    const segW = labels.map(([key]) => Math.ceil(gfx.textWidth(TR(key), 13, "semibold")) + 28);
    const total = segW.reduce((a, b) => a + b, 0) + 8;
    const y = (TOP_H - CTRL_H) / 2;
    gfx.rect(PAD, y, total, CTRL_H, CTRL_H / 2, theme.field ?? theme.control);
    let x = PAD + 4;
    labels.forEach(([key, index], i) => {
        const id = "tab:" + index, active = tab === index;
        register(id, x, y + 4, segW[i], CTRL_H - 8, false, (CTRL_H - 8) / 2);
        if (active) gfx.rect(x, y + 4, segW[i], CTRL_H - 8, (CTRL_H - 8) / 2, theme.accent);
        else if (hovered(id)) gfx.rect(x, y + 4, segW[i], CTRL_H - 8, (CTRL_H - 8) / 2, theme.hover);
        gfx.color(active ? "#ffffff" : theme.text2);
        gfx.text(TR(key), x, y + 4 + (CTRL_H - 8 - gfx.textHeight(13, "semibold")) / 2, 13, "semibold", "center", segW[i]);
        if (takeClick(id)) selectTab(index);
        x += segW[i];
    });
    // Refresh, at the right edge; a spinner while the catalog loads.
    const rx = w - PAD - CTRL_H;
    if (catalogLoading) {
        gfx.color(theme.accent);
        const a = (frame * 7) % 360;
        gfx.arc(rx + CTRL_H / 2, y + CTRL_H / 2, 9, a, a + 270, 2.5);
    } else if (drawButton("refresh", rx, y, CTRL_H, "", "ghost", false, CTRL_H, "refresh")) void refreshCatalog();
    // Search field between the tabs and refresh (an icon button when the window is narrow).
    const sx0 = PAD + total + GAP, sw = Math.min(300, rx - 8 - sx0);
    if (sw < 120) {
        if (drawButton("search", rx - 8 - CTRL_H, y, CTRL_H, "", query ? "active" : "ghost", false, CTRL_H, "search")) void askSearch();
    } else {
        const sx = rx - 8 - sw, clear = !!query;
        register("search", sx, y, clear ? sw - CTRL_H : sw, CTRL_H, false, CTRL_H / 2);
        gfx.rect(sx, y, sw, CTRL_H, CTRL_H / 2, hovered("search") ? theme.surfaceHover ?? theme.field : theme.field ?? theme.control);
        gfx.color(query ? theme.accent : theme.border ?? theme.separator);
        gfx.rectLine(sx, y, sw, CTRL_H, CTRL_H / 2, query ? 1.5 : 1);
        gfx.icon("search", sx + 20, y + CTRL_H / 2, 18, theme.text3);
        colorText(query ? theme.text : theme.text3);
        const text = query || TR("search.placeholder");
        gfx.text(fitText(text, 13, "sans", sw - 44 - (clear ? 28 : 12)), sx + 36, y + (CTRL_H - gfx.textHeight(13, "sans")) / 2, 13, "sans");
        if (takeClick("search")) void askSearch();
        if (clear) {
            register("search-clear", sx + sw - CTRL_H, y, CTRL_H, CTRL_H, false, CTRL_H / 2);
            if (hovered("search-clear")) gfx.circle(sx + sw - CTRL_H / 2, y + CTRL_H / 2, 12, theme.hover);
            gfx.icon("close", sx + sw - CTRL_H / 2, y + CTRL_H / 2, 16, theme.text2);
            if (takeClick("search-clear")) setQuery("");
        }
    }
    gfx.rect(0, TOP_H - 1, w, 1, 0, theme.separator);
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

// A slim notice bar (offline, download result, progress). Returns its height including spacing.
function drawNotice(x, y, w) {
    const line = storeStatusLine();
    if (!line || (catalogLoading && !catalog.length) || (catalogOffline && !catalog.length && !transfer && !status)) return 0;
    const offline = catalogOffline && !transfer && !status;
    const failed = status === TR("download.failed") || status === TR("download.open_failed") || status === TR("action.copy_failed");
    const color = offline ? theme.orange : failed ? theme.red : transfer ? theme.accent : theme.green;
    const icon = offline ? "cloud_off" : failed ? "error_outline" : transfer ? "download" : "check_circle";
    gfx.rect(x, y, w, 40, 12, tint(color, "1f"));
    if (transfer) {
        const pct = Math.min(1, transfer.bytes / transfer.row.bytes);
        gfx.rect(x, y + 36, Math.max(12, w * pct), 4, 2, color);
    }
    gfx.icon(icon, x + 22, y + 20, 18, color);
    colorText(theme.text);
    gfx.text(fitText(line, 13, "medium", w - 52), x + 40, y + (40 - gfx.textHeight(13, "medium")) / 2, 13, "medium");
    return 40 + GAP;
}

// The state of the primary action for a listing: busy, ready (open), update or get.
function actionState(app, row) {
    if (transfer?.row.key === row.key) return "busy";
    if (localPackageReady(row)) return "ready";
    return updateAvailable(app) ? "update" : "get";
}

function actionLabel(state) {
    return TR(state === "ready" ? "detail.open" : state === "update" ? "detail.update_button" : "detail.get");
}

// Primary Get / Update / Open button with an inline progress state, drawn on the dark banners. Returns its width.
function drawAction(app, id, x, y, minW, inArea) {
    const row = storeRow(app), state = actionState(app, row);
    const label = state === "busy" ? `${TR("download.progress")} 100%` : actionLabel(state);
    const w = Math.max(minW, buttonWidth(label, state !== "busy"));
    if (state === "busy") {
        // White text stays readable on both the translucent track and the accent fill.
        const pct = Math.min(1, transfer.bytes / row.bytes);
        register(id, x, y, w, CTRL_H, inArea, CTRL_H / 2);
        gfx.rect(x, y, w, CTRL_H, CTRL_H / 2, "#ffffff26");
        gfx.rect(x, y, Math.max(CTRL_H, w * pct), CTRL_H, CTRL_H / 2, theme.accent);
        gfx.color("#ffffff");
        gfx.text(`${TR("download.progress")} ${Math.round(pct * 100)}%`, x, y + (CTRL_H - gfx.textHeight(14, "semibold")) / 2, 14, "semibold", "center", w);
        takeClick(id);
        return w;
    }
    const icon = state === "ready" ? "open_in_new" : state === "update" ? "update" : "download";
    if (drawButton(id, x, y, w, label, "light", inArea, CTRL_H, icon)) {
        if (state === "ready") openPackage(row);
        else void download(row);
    }
    return w;
}

// ---- Store tab: home ----

function mix(a, b, t) {
    const x = parseInt(a.slice(1, 7), 16), z = parseInt(b.slice(1, 7), 16);
    const part = shift => Math.round(((x >> shift) & 255) * (1 - t) + ((z >> shift) & 255) * t);
    return "#" + [16, 8, 0].map(shift => part(shift).toString(16).padStart(2, "0")).join("");
}

// Banner color at height `dy` of `h`: the dark gradient with the accent glow that fades out downward.
function heroColor(dy, h) {
    const t = Math.max(0, Math.min(1, dy / h));
    return mix(mix(HERO_TOP, HERO_BOTTOM, t), theme.accent, 0.25 * (1 - t));
}

function drawHero(app, x, y, w, h) {
    const id = "hero:" + app.item;
    register(id, x, y, w, h, true, 18);
    if (ensureId === id) ensureVisible(y, h);
    gfx.shadow(x, y, w, h, 18, hovered(id) ? 22 : 16, hovered(id) ? 6 : 4);
    gfx.gradient(x, y, w, h, HERO_TOP, HERO_BOTTOM, false, 18);
    gfx.gradient(x, y, w, h, tint(theme.accent, "40"), tint(theme.accent, "00"), false, 18);
    // Screenshot on the right; its left edge fades into the banner.
    const inset = 16, sh = h - 2 * inset, sw = Math.round(sh * 16 / 9);
    const textW = w - 2 * 24;
    let textRight = x + w - 24;
    if (app.screenshots.length && w - sw > 300) {
        const sx = x + w - inset - sw;
        drawScreenshot(app, app.screenshots[0], sx, y + inset, sw, sh, 12);
        // The banner is a vertical gradient, so the fade is drawn in strips that match its color at each height.
        const strips = 8, fw = Math.round(sw * 0.45);
        for (let i = 0; i < strips; i++) {
            const top = y + inset + Math.floor(i * sh / strips), bottom = y + inset + Math.floor((i + 1) * sh / strips);
            const base = heroColor((top + bottom) / 2 - y, h);
            gfx.gradient(sx - 1, top, fw, bottom - top, base, tint(base, "00"), true);
        }
        textRight = sx + Math.round(sw * 0.2);
    }
    const tx = x + 24, tw = Math.min(textW, textRight - tx);
    let ty = y + 22;
    colorText("#9FB8FF");
    gfx.text(TR("store.featured").toUpperCase(), tx, ty, 11, "bold");
    ty += 24;
    drawIcon(app, tx, ty, 56, true);
    const nx = tx + 56 + 14, nw = tw - 70;
    colorText("#ffffff");
    gfx.text(fitText(app.name, 22, "bold", nw), nx, ty + 2, 22, "bold");
    colorText(HERO_TEXT2);
    gfx.text(fitText(pickText(app.subtitle), 13, "sans", nw), nx, ty + 32, 13, "sans");
    ty += 56 + 14;
    colorText(HERO_TEXT3);
    gfx.text(fitText([kindLabel(app), app.category, sizeText(app.size)].filter(Boolean).join(" · "), 12, "medium", tw), tx, ty, 12, "medium");
    ty = y + h - 22 - CTRL_H;
    drawAction(app, "hero-action", tx, ty, 132, true);
    if (takeClick(id)) openDetail(app);
}

// Card surface: a hairline border; the blurred shadow (the costliest primitive) is drawn only on hover.
function cardBase(x, y, w, h, hot) {
    if (hot) gfx.shadow(x, y, w, h, 14, 14, 4);
    gfx.rect(x, y, w, h, 14, hot ? theme.surfaceHover ?? theme.card : theme.card ?? theme.control);
    gfx.color(theme.dark ? "#ffffff14" : "#0000000f");
    gfx.rectLine(x, y, w, h, 14, 1);
}

function drawNewTile(app, x, y, w, h) {
    const id = "new:" + app.item;
    register(id, x, y, w, h, true, 14);
    if (ensureId === id) ensureVisible(y, h);
    if (y + h < area.top || y > area.bottom) { if (takeClick(id)) openDetail(app); return; }
    const hot = hovered(id);
    cardBase(x, y, w, h, hot);
    const th = Math.round(w * 9 / 16);
    if (app.screenshots.length) drawScreenshot(app, app.screenshots[0], x, y, w, th, 14);
    else {
        const color = tileColor(app);
        gfx.gradient(x, y, w, th, tint(color, "55"), tint(color, "18"), false, 14);
    }
    gfx.rect(x, y + th - 14, w, 14, 0, hot ? theme.surfaceHover ?? theme.card : theme.card ?? theme.control);
    drawIcon(app, x + 12, y + th - 22, 40);
    gfx.color("#ffffff");
    gfx.rectLine(x + 11, y + th - 23, 42, 42, 10, 1.5);
    colorText(theme.text);
    gfx.text(fitText(app.name, 14, "semibold", w - 24), x + 12, y + th + 24, 14, "semibold");
    colorText(theme.text2);
    gfx.text(fitText(kindLabel(app) + (app.category ? " · " + app.category : ""), 12, "sans", w - 24), x + 12, y + th + 44, 12, "sans");
    if (takeClick(id)) openDetail(app);
}

function drawCard(app, x, y, w) {
    const id = "app:" + app.item, h = CARD_H;
    register(id, x, y, w, h, true, 14);
    if (ensureId === id) ensureVisible(y, h);
    if (y + h < area.top || y > area.bottom) { if (takeClick(id)) openDetail(app); return; }
    const hot = hovered(id);
    cardBase(x, y, w, h, hot);
    drawIcon(app, x + 14, y + (h - 64) / 2, 64);
    const tx = x + 14 + 64 + 14;
    let badgeW = 0;
    if (updateAvailable(app)) badgeW = Math.ceil(gfx.textWidth(TR("detail.update_button"), 11, "semibold")) + 24;
    else if (installedVersion(app.item)) badgeW = 24;
    const tw = x + w - 14 - tx - badgeW;
    colorText(theme.text);
    gfx.text(fitText(app.name, 15, "semibold", tw), tx, y + 14, 15, "semibold");
    colorText(theme.text2);
    gfx.text(fitText(pickText(app.subtitle), 12, "sans", x + w - 14 - tx), tx, y + 37, 12, "sans");
    const pw = drawPill(kindLabel(app), tx, y + 60, kindColor(app));
    colorText(theme.text3);
    gfx.text(fitText(`v${app.version} · ${sizeText(app.size)}`, 11, "medium", x + w - 14 - tx - pw - 8), tx + pw + 8, y + 60 + (20 - gfx.textHeight(11, "medium")) / 2, 11, "medium");
    if (updateAvailable(app)) drawPill(TR("detail.update_button"), x + w - 14 - badgeW + 8, y + 14, "#ffffff", theme.accent);
    else if (badgeW) gfx.icon("check_circle", x + w - 14 - 9, y + 24, 18, theme.green);
    if (takeClick(id)) openDetail(app);
}

function drawSkeletonCard(x, y, w) {
    gfx.rect(x, y, w, CARD_H, 14, theme.card ?? theme.control);
    skeleton(x + 14, y + (CARD_H - 64) / 2, 64, 64, 15);
    skeleton(x + 92, y + 18, Math.min(160, w - 110), 14, 7);
    skeleton(x + 92, y + 42, Math.min(220, w - 110), 10, 5);
    skeleton(x + 92, y + 62, 70, 18, 9);
}

// Centered designed state for empty, offline and error views. Returns the button id it drew ("" for none).
function drawEmptyState(icon, title, message, button, cx, y, w) {
    gfx.circle(cx, y + 40, 40, theme.dark ? "#ffffff14" : "#0000000c");
    gfx.icon(icon, cx, y + 40, 40, theme.text3);
    colorText(theme.text);
    gfx.text(title, cx - w / 2, y + 96, 18, "bold", "center", w);
    colorText(theme.text2);
    const mw = Math.min(w, 420);
    const mh = gfx.wrap(message, cx - mw / 2, y + 126, mw, 13, "sans", "center");
    let bottom = y + 126 + mh + GAP;
    if (button) {
        const bw = buttonWidth(button);
        if (drawButton("empty-action", cx - bw / 2, bottom, bw, button, "primary", true)) return "empty-action";
        bottom += CTRL_H;
    }
    return "";
}

function drawStoreList(w, h) {
    area = { top: TOP_H, bottom: h };
    const cx = PAD, cw = w - 2 * PAD;
    gfx.clip(0, area.top, w, area.bottom - area.top);
    let y = area.top + GAP - scroll;
    y += drawNotice(cx, y, cw);
    // Category chips.
    let x = cx;
    for (const [key, index] of [["filter.all", 0], ["filter.game", 1], ["filter.software", 2]]) {
        const label = TR(key), bw = buttonWidth(label, false, CHIP_H);
        if (drawButton("filter:" + index, x, y, bw, label, filter === index ? "active" : "plain", true, CHIP_H)) {
            filter = index; scroll = 0; scrollGoal = null;
        }
        x += bw + 8;
    }
    y += CHIP_H + GAP + 4;
    const apps = filterApps(catalog, filter, query);
    const home = filter === 0 && !query && apps.length > 0;
    const cols = Math.max(1, Math.floor((cw + GAP) / (CARD_MIN_W + GAP)));
    const cardW = (cw - (cols - 1) * GAP) / cols;
    if (!catalog.length && catalogLoading) {
        const heroH = Math.max(208, Math.min(300, Math.round(cw * 0.26)));
        skeleton(cx, y, cw, heroH, 18);
        y += heroH + GAP * 2;
        for (let i = 0; i < cols * 2; i++) drawSkeletonCard(cx + (i % cols) * (cardW + GAP), y + Math.floor(i / cols) * (CARD_H + GAP), cardW);
        y += 2 * (CARD_H + GAP);
    } else if (!apps.length) {
        let action = "";
        if (query) action = drawEmptyState("search_off", TR("search.none_title"), TR("search.none"), TR("search.clear"), w / 2, y + 8, cw);
        else if (catalogOffline && !catalog.length)
            action = drawEmptyState("cloud_off", TR("store.offline_title"), TR("store.unavailable"), TR("store.retry"), w / 2, y + 8, cw);
        else action = drawEmptyState("inventory_2", TR("store.empty_title"), TR(filter ? "library.empty" : "store.empty"), "", w / 2, y + 8, cw);
        if (action && query) setQuery("");
        else if (action) void refreshCatalog();
        y += 260;
    } else {
        if (home) {
            const hero = featuredApp(apps);
            const heroH = Math.max(208, Math.min(300, Math.round(cw * 0.26)));
            drawHero(hero, cx, y, cw, heroH);
            y += heroH + GAP * 2;
            const n = Math.max(2, Math.min(4, Math.floor((cw + GAP) / (190 + GAP))));
            const fresh = newestApps(apps.filter(app => app !== hero), n);
            if (fresh.length >= 2) {
                sectionHeader(TR("store.new"), cx, y);
                y += 34;
                const tw = (cw - (n - 1) * GAP) / n, th = Math.round(tw * 9 / 16) + 66;
                fresh.forEach((app, i) => drawNewTile(app, cx + i * (tw + GAP), y, tw, th));
                y += th + GAP * 2;
            }
        }
        const title = query ? TR("search.results") : TR(filter === 1 ? "filter.game" : filter === 2 ? "filter.software" : "store.all_apps");
        sectionHeader(title, cx, y, apps.length);
        y += 34;
        apps.forEach((app, i) => drawCard(app, cx + (i % cols) * (cardW + GAP), y + Math.floor(i / cols) * (CARD_H + GAP), cardW));
        y += Math.ceil(apps.length / cols) * (CARD_H + GAP);
    }
    gfx.unclip();
    contentH = y + scroll - area.top + PAD;
    clampScroll();
}

// ---- Store tab: detail page ----

function drawCarousel(app, x, y, w) {
    const list = app.screenshots, count = list.length;
    const sw = Math.round(Math.min(w, 720)), sh = Math.round(sw * 9 / 16);
    const index = Math.min(shot, count - 1);
    register("shot", x, y, sw, sh, true, 14);
    if (ensureId === "shot") ensureVisible(y, sh);
    gfx.shadow(x, y, sw, sh, 14, 12, 3);
    gfx.rect(x, y, sw, sh, 14, theme.dark ? "#000000" : "#1a1d24");
    drawScreenshot(app, list[index], x, y, sw, sh, 14);
    if (takeClick("shot")) shot = (index + 1) % count;
    if (count > 1) {
        for (const [id, icon, bx, step] of [["shot-prev", "chevron_left", x + 12, count - 1], ["shot-next", "chevron_right", x + sw - 12 - 40, 1]]) {
            register(id, bx, y + sh / 2 - 20, 40, 40, true, 20);
            if (ensureId === id) ensureVisible(y, sh);
            gfx.circle(bx + 20, y + sh / 2, 20, hovered(id) ? "#000000b3" : "#00000080");
            gfx.icon(icon, bx + 20, y + sh / 2, 26, "#ffffff");
            if (takeClick(id)) shot = (index + step) % count;
        }
        // Page dots; the current one is elongated.
        const dotsW = (count - 1) * 14 + 22;
        let dx = x + (sw - dotsW) / 2;
        for (let i = 0; i < count; i++) {
            const current = i === index, dw = current ? 22 : 8;
            register("dot:" + i, dx - 3, y + sh + 6, dw + 6, 20, true, 6, false);
            gfx.rect(dx, y + sh + 12, dw, 8, 4, current ? theme.accent : theme.dark ? "#ffffff40" : "#00000030");
            if (takeClick("dot:" + i)) shot = i;
            dx += dw + 6;
        }
        return sh + 34;
    }
    return sh + 8;
}

function drawDetail(app, w, h) {
    area = { top: TOP_H, bottom: h };
    const cw = Math.min(w - 2 * PAD, 880), cx = Math.max(PAD, Math.round((w - cw) / 2)); // centered reading column
    gfx.clip(0, area.top, w, area.bottom - area.top);
    let y = area.top + 12 - scroll;
    const back = TR("detail.back");
    if (drawButton("back", cx, y, buttonWidth(back, true, CHIP_H), back, "ghost", true, CHIP_H, "chevron_left")) goBack();
    y += CHIP_H + 12;
    // Header banner: icon, name, subtitle, meta and the primary action.
    const narrow = cw < 560, headH = narrow ? 196 : 148;
    gfx.shadow(cx, y, cw, headH, 18, 16, 4);
    gfx.gradient(cx, y, cw, headH, HERO_TOP, HERO_BOTTOM, false, 18);
    gfx.gradient(cx, y, cw, headH, tint(theme.accent, "40"), tint(theme.accent, "00"), false, 18);
    drawIcon(app, cx + 24, y + 26, 96, true);
    const tx = cx + 24 + 96 + 20;
    const actionW = narrow ? 0 : 172;
    const tw = cw - (tx - cx) - 24 - actionW - (narrow ? 0 : 16);
    colorText("#ffffff");
    gfx.text(fitText(app.name, 24, "bold", tw), tx, y + 28, 24, "bold");
    colorText(HERO_TEXT2);
    gfx.text(fitText(pickText(app.subtitle), 14, "sans", tw), tx, y + 62, 14, "sans");
    colorText(HERO_TEXT3);
    gfx.text(fitText([kindLabel(app), app.category].filter(Boolean).join(" · "), 12, "medium", tw), tx, y + 86, 12, "medium");
    const have = installedVersion(app.item);
    if (updateAvailable(app)) drawPill(TR("detail.update"), tx, y + 106, "#ffffff", tint(theme.accent, "cc"));
    else if (have) drawPill(TR("detail.installed"), tx, y + 106, "#ffffff", tint(theme.green, "b3"));
    const ax = narrow ? tx : cx + cw - 24 - actionW, ay = narrow ? y + headH - 24 - CTRL_H : y + (headH - CTRL_H) / 2;
    if (ensureId === "action") ensureVisible(y, headH);
    drawAction(app, "action", ax, ay, narrow ? Math.min(220, cw - (tx - cx) - 24) : actionW, true);
    y += headH + GAP;
    // Status after an action (download result, copied link).
    if (status && !transfer) y += drawNotice(cx, y, cw);
    // Info strip: version, size, age, license, SDK.
    const sdk = app.sdk.sdk ? app.sdk.sdk + (app.sdk.native ? ` / ${TR("detail.native")} ${app.sdk.native}` : "") : "";
    const cells = [[TR("item.version"), app.version], [TR("item.size"), sizeText(app.size)], [TR("detail.age"), app.age],
        [TR("detail.license"), app.license], [TR("detail.sdk"), sdk]].filter(cell => cell[1]);
    const perRow = cw < 520 ? 3 : cells.length, rows = Math.ceil(cells.length / perRow);
    gfx.rect(cx, y, cw, rows * 60, 14, theme.card ?? theme.control);
    cells.forEach(([label, value], i) => {
        const col = i % perRow, r = Math.floor(i / perRow), cellW = cw / perRow;
        const x = cx + col * cellW, cy = y + r * 60;
        if (col) gfx.rect(x, cy + 14, 1, 32, 0, theme.separator);
        colorText(theme.text3);
        gfx.text(fitText(label.toUpperCase(), 10, "semibold", cellW - 16), x, cy + 12, 10, "semibold", "center", cellW);
        colorText(theme.text);
        gfx.text(fitText(value, 14, "semibold", cellW - 16), x, cy + 30, 14, "semibold", "center", cellW);
    });
    y += rows * 60 + GAP * 2;
    // Screenshots.
    if (app.screenshots.length) {
        sectionHeader(TR("detail.screens"), cx, y);
        y += 34;
        y += drawCarousel(app, cx, y, cw) + GAP;
    }
    // Description and what's new.
    for (const [key, text] of [["detail.about", pickText(app.description)], ["detail.whats_new", pickText(app.whatsNew)]]) {
        if (!text) continue;
        sectionHeader(TR(key), cx, y);
        y += 34;
        colorText(theme.text2);
        y += gfx.wrap(text, cx, y, Math.min(cw, 720), 14, "sans", "left", 1.15) + GAP * 2;
    }
    // Information rows and the source link.
    const facts = [[TR("detail.category"), app.category], [TR("detail.updated"), app.updated], [TR("detail.item"), app.item]]
        .filter(entry => entry[1]);
    if (facts.length) {
        sectionHeader(TR("detail.info"), cx, y);
        y += 34;
        gfx.rect(cx, y, cw, facts.length * 44, 14, theme.card ?? theme.control);
        facts.forEach(([label, value], i) => {
            const ry = y + i * 44;
            if (i) gfx.rect(cx + 16, ry, cw - 32, 1, 0, theme.separator);
            colorText(theme.text2);
            gfx.text(label, cx + 16, ry + (44 - gfx.textHeight(13, "sans")) / 2, 13, "sans");
            colorText(theme.text);
            gfx.text(fitText(value, 13, "medium", cw * 0.6), cx + cw - 16 - cw * 0.6, ry + (44 - gfx.textHeight(13, "medium")) / 2, 13, "medium", "right", cw * 0.6);
        });
        y += facts.length * 44 + GAP;
    }
    if (app.source) {
        const label = TR("detail.source");
        if (drawButton("source", cx, y, buttonWidth(label, true), label, "plain", true, CTRL_H, "link")) {
            status = sys.clipboard(app.source) === false ? TR("action.copy_failed") : TR("detail.source_copied");
        }
        y += CTRL_H + GAP;
    }
    gfx.unclip();
    contentH = y + scroll - area.top + PAD;
    clampScroll();
}

// Animated focus ring for gamepad and keyboard use; it glides to the focused widget.
function drawFocusRing() {
    if (!padMode) { ring = null; return; }
    const target = widgets.find(item => item.id === focusId);
    if (!target) { ring = null; return; }
    const goal = { x: target.x - 4, y: target.y - 4, w: target.w + 8, h: target.h + 8, r: target.radius + 4 };
    if (!ring || Math.abs(goal.y - ring.y) > 600) ring = { ...goal };
    else for (const k of ["x", "y", "w", "h", "r"]) ring[k] += (goal[k] - ring[k]) * 0.35;
    if (target.clipped) gfx.clip(0, area.top, winW, area.bottom - area.top);
    gfx.color(theme.accent);
    gfx.rectLine(ring.x, ring.y, ring.w, ring.h, ring.r, 2.5);
    if (target.clipped) gfx.unclip();
}

function drawStore(w, h) {
    const app = detail ? catalog.find(value => value.item === detail) : null;
    if (detail && !app) detail = "";
    hoverId = hoverAt && !padMode ? widgetAt(hoverAt.x, hoverAt.y)?.id ?? "" : "";
    stepScroll();
    if (app) drawDetail(app, w, h);
    else drawStoreList(w, h);
    drawTopBar(w);
    drawFocusRing();
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
        if (!focusId && padMode) focusId = lastWidgets.find(item => item.focus)?.id ?? "";
    } else {
        drawArchiveLocal(w, h);
    }
};
