// Port Market — Nexvyn OS SDK 1.15.
const ARCHIVE = "https://archive.org";
const MAX_ARCHIVES = 24;
const MAX_BYTES = 1074000000;
const ARCHIVE_ID = /^[A-Za-z0-9][A-Za-z0-9._-]{2,99}$/;
const PACKAGE_NAME = /^[A-Za-z0-9][A-Za-z0-9._-]{0,119}\.nxvapp$/;
const SHA1 = /^[a-f0-9]{40}$/;
let sources = [], archiveRows = [], localRows = [];
let localFolder = "", selected = "", tab = 0, scroll = 0;
let refreshing = false, transfer = null, status = "", failedSources = 0, refreshedAt = 0;
let dialogBusy = false;

function itemId(value) {
    const result = String(value ?? "").trim().replace(/^https:\/\/archive\.org\/details\//, "").replace(/\/$/, "");
    return ARCHIVE_ID.test(result) && !result.includes("..") ? result : "";
}

function packageName(value) {
    return typeof value === "string" && PACKAGE_NAME.test(value) && !value.includes("..");
}

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
        if (fs.exists(path)) fs.remove(path, true);
        if (!fs.rename(partial, path)) throw new Error("rename failed");
        status = TR("download.ready");
    } catch {
        if (fs.exists(partial)) fs.remove(partial, true);
        status = TR("download.failed");
    } finally {
        transfer = null;
    }
}

function openPackage(row) {
    if (!sys.open(row.url ? downloadedPath(row) : row.path)) status = TR("download.open_failed");
}

app.load = () => {
    const saved = store.get("archiveItems", []);
    if (Array.isArray(saved)) sources = [...new Set(saved.map(itemId).filter(Boolean))].slice(0, MAX_ARCHIVES);
    const folder = store.get("library", "");
    localFolder = typeof folder === "string" ? folder : "";
    refreshLocal();
    void refreshArchive();
};

app.update = () => {
    if (!refreshing && sources.length && sys.time() - refreshedAt >= 300) void refreshArchive();
};

app.draw = (w, h) => {
    gfx.clear(theme.window ?? theme.bg);
    nxui.begin(w, h);
    nxui.column("port-market");
    nxui.label("title", TR("app.title"), "title");
    nxui.row("source-tabs");
    let nextTab = tab;
    if (nxui.button("archive-tab", TR("item.archive"), tab === 0 ? "primary" : "plain")) nextTab = 0;
    if (nxui.button("local-tab", TR("item.local"), tab === 1 ? "primary" : "plain")) nextTab = 1;
    nxui.rowEnd();
    if (nextTab !== tab) {
        tab = nextTab;
        localSelectionReset();
        status = "";
    }
    nxui.row("toolbar");
    if (tab === 0 && !refreshing && sources.length < MAX_ARCHIVES &&
            nxui.button("add", TR("archive.add"), "primary")) void addArchive();
    if (tab === 1 && nxui.button("choose", TR("library.choose"), "primary")) void chooseLocal();
    if (!refreshing && nxui.button("refresh", TR("library.refresh"))) {
        status = "";
        if (tab === 0) void refreshArchive();
        else refreshLocal();
    }
    nxui.rowEnd();

    if (refreshing) nxui.label("sync", TR("archive.sync"), "caption");
    else if (tab === 0 && failedSources) nxui.label("sync-error", TR("archive.failed"), "caption");
    if (status) nxui.label("status", status, "caption");
    if (transfer) {
        const pct = Math.min(100, Math.round(100 * transfer.bytes / transfer.row.bytes));
        nxui.label("transfer", `${TR("download.progress")} ${pct}% · ${transfer.row.name}`, "caption");
    }

    const rows = tab === 0 ? archiveRows : localRows;
    const row = rows.find(value => value.key === selected);
    if (row) {
        nxui.card("package");
        nxui.label("package-name", row.name, "headline");
        const size = (row.bytes / 1048576).toFixed(1) + " MiB";
        nxui.label("package-meta", row.version ? `${TR("item.version")} ${row.version} · ${size}` : size, "caption");
        const ready = localPackageReady(row);
        if (ready && nxui.button("open", TR("download.open"), "primary")) openPackage(row);
        if (!ready && row.url && !transfer && nxui.button("download", TR("download.start"), "primary")) void download(row);
        if (!ready && !row.url) nxui.label("missing", TR("item.local_missing"), "caption");
        nxui.cardEnd();
    }
    if (!rows.length && !(tab === 0 && refreshing)) {
        const key = tab === 0 && !sources.length ? "archive.hint" :
            tab === 1 && !localFolder ? "library.choose_hint" : "library.empty";
        nxui.label("empty", TR(key));
    }
    const canScroll = typeof nxui.scrollBegin === "function" && typeof nxui.scrollEnd === "function";
    if (canScroll) scroll = nxui.scrollBegin("catalog", Math.max(120, w - 32), Math.max(100, h - (row ? 260 : 162)), scroll);
    for (const value of rows.slice(0, canScroll ? 256 : 4)) {
        if (nxui.button(value.key, value.name, value.key === selected ? "primary" : "plain")) selected = value.key;
    }
    if (tab === 0 && sources.length) {
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
};
