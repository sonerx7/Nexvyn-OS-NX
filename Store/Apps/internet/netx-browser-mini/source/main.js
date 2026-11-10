const tabs = [];
const rulesLimit = 350;
const desktopHeaders = {
    "User-Agent":"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
    "Sec-CH-UA-Mobile":"?0",
    "Sec-CH-UA-Platform":'"Linux"',
};
const inherited = ["color", "font-size", "font-weight", "font-style", "text-align", "line-height"];
let active = 0;
let layout = [];
let measuredTab, measuredWidth, measuredDocument, contentHeight;
let references;
const netflixExample = "https://www.netflix.com/title/80057281";
const cubemapDemo = "https://webglsamples.org/dynamic-cubemap/dynamic-cubemap.html";
const youtubeHome = "https://www.youtube.com/";
const videoId = /^[A-Za-z0-9_-]{11}$/;
const searchEngines = {
    Google:"https://www.google.com/search?gbv=1&q=",
    DuckDuckGo:"https://html.duckduckgo.com/html/?q=",
    Bing:"https://www.bing.com/search?q=",
};

function youtubePage(url) {
    const address = new URL(url);
    const path = address.pathname;
    if (address.hostname === "youtu.be" && videoId.test(path.slice(1)))
        return {kind:"watch", id:path.slice(1)};
    if (!["youtube.com", "www.youtube.com", "m.youtube.com"].includes(address.hostname))
        return null;
    if (path === "/") return {kind:"home"};
    if (path === "/results") {
        const query = (address.searchParams.get("search_query") || "").trim();
        return query ? {kind:"search", query:query.slice(0, 200)} : {kind:"home"};
    }
    const id = path === "/watch" ? address.searchParams.get("v") : path.split("/")[2];
    if (id && videoId.test(id) && /^\/(?:watch|shorts\/|live\/|embed\/)/.test(path))
        return {kind:"watch", id};
    return null;
}

function youtubeUrl(page) {
    if (page.kind === "watch") return youtubeHome + "watch?v=" + page.id;
    if (page.kind === "search") return youtubeHome + "results?search_query=" + encodeURIComponent(page.query);
    return youtubeHome;
}

let tabSerial = 0;
const maxTabs = 8;
const closedTabs = [];
const downloads = [];
let downloadSerial = 0;

function showCatalog(tab) {
    if (!references) {
        const index = fs.read("bundle:/reference/index.json");
        references = index ? JSON.parse(index) : [];
    }
    cancel(tab);
    if (mediaTab === tab) closeMedia();
    tab.catalog = true;
    tab.directMedia = null;
    tab.find = "";
    tab.findOpen = false;
    tab.suggest = false;
    tab.address = tab.draft = tab.url = "";
    tab.title = label("Kaynaklar", "Resources");
    tab.info = [];
    tab.sections = [];
    tab.rows = references.map(entry => ({text:entry.name, entry, css:{}}));
    tab.status = references.length + label(" web standardı bağlantısı", " web standards links");
}

function newTab() {
    return {key:++tabSerial, address: "", draft:"", youtubeQuery:"", url: "", rows: [], history: [], index: -1, request: 0,
        styles: [], revision: 0, title: "", reason: "", find:"", zoom:100, reader:false,
        status: label("Adres veya arama yazın.", "Enter an address or search.")};
}

function decode(value) {
    const entities = {amp: "&", lt: "<", gt: ">", quot: '"', apos: "'", nbsp: " "};
    return value.replace(/&(#x[0-9a-f]+|#\d+|\w+);/gi, (entity, name) => {
        if (name[0] !== "#") return entities[name] || entity;
        const number = /^#x/i.test(name) ? parseInt(name.slice(2), 16) : Number(name.slice(1));
        return number >= 32 && number <= 0x10ffff && !(number >= 0xd800 && number <= 0xdfff)
            ? String.fromCodePoint(number) : entity;
    });
}

function resolve(value, base) {
    try {
        const url = base ? new URL(value, base) : new URL(value);
        if (url.href.length <= 4096 && /^https?:$/.test(url.protocol) && !url.username && !url.password)
            return url.href;
    } catch (_) {}
    return "";
}

function declarations(value) {
    const out = Object.create(null);
    for (const entry of value.split(";")) {
        const at = entry.indexOf(":");
        if (at >= 0) out[entry.slice(0, at).trim().toLowerCase()] = entry.slice(at + 1).trim().toLowerCase();
    }
    return out;
}

function stylesheetSources(body, url) {
    const sheets = [];
    const markup = body.slice(0, 262144).replace(/<!--[\s\S]*?-->|<(script|template)\b[^>]*>[\s\S]*?<\/\1\s*>/gi, "");
    for (const match of markup.matchAll(/<style\b[^>]*>([\s\S]*?)<\/style\s*>|<link\b([^>]*)>/gi)) {
        if (match[1] !== undefined) {
            sheets.push({text:match[1]});
        } else {
            const attrs = attributes(match[2]);
            if (!/^(?:all|screen)?$/i.test(attrs.media || "")) continue;
            if (!/(?:^|\s)stylesheet(?:$|\s)/i.test(attrs.rel || "")) continue;
            if (/(?:^|\s)alternate(?:$|\s)/i.test(attrs.rel || "") || "disabled" in attrs) continue;
            const href = attrs.href && resolve(attrs.href, url);
            if (href && !(url.startsWith("https:") && href.startsWith("http:"))) sheets.push({href});
        }
        if (sheets.length >= 8) break;
    }
    return sheets;
}

function selectorParts(value) {
    const pieces = value.trim().replace(/\s*>\s*/g, ">").split(/(>|\s+)/).filter(Boolean);
    if (!pieces.length || pieces.length > 11 || pieces.length % 2 === 0) return null;
    const chain = [];
    let weight = 0;
    for (let i = 0; i < pieces.length; i += 2) {
        const text = pieces[i];
        const match = /^([a-z][\w-]*|\*)?((?:[.#][\w-]+)*)$/i.exec(text);
        if (!match || !text) return null;
        const tag = match[1] && match[1] !== "*" ? match[1].toLowerCase() : "";
        const attributes = Array.from(match[2].matchAll(/([.#])([\w-]+)/g));
        const ids = attributes.filter(a => a[1] === "#").map(a => a[2]);
        const classes = attributes.filter(a => a[1] === ".").map(a => a[2]);
        weight += ids.length * 10000 + classes.length * 100 + (tag ? 1 : 0);
        chain.push({tag, ids, classes, direct:i > 0 && pieces[i - 1] === ">"});
    }
    return {chain, weight};
}

function matchesCompound(part, node) {
    return (!part.tag || part.tag === node.tag)
        && part.ids.every(id => id === node.id)
        && part.classes.every(name => node.classes.includes(name));
}

function matchesSelector(chain, element, parents) {
    let part = chain.length - 1;
    if (!matchesCompound(chain[part], element)) return false;
    let parent = parents.length - 1;
    while (part > 0) {
        const direct = chain[part--].direct;
        if (!direct) {
            while (parent > 0 && !matchesCompound(chain[part], parents[parent])) parent--;
        }
        if (parent <= 0 || !matchesCompound(chain[part], parents[parent--])) return false;
    }
    return true;
}

function cssRules(sheets) {
    const rules = [];
    for (const sheet of sheets) {
        const css = (sheet.text || "").replace(/\/\*[\s\S]*?\*\//g, "");
        // Ignore nested at-rules until media queries and imports have their own parser.
        let depth = 0, start = 0, selectorText = "", bodyStart = 0;
        for (let i = 0; i < css.length; i++) {
            if (css[i] === ";" && depth === 0) start = i + 1;
            if (css[i] === "{") {
                if (depth === 0) { selectorText = css.slice(start, i).trim(); bodyStart = i + 1; }
                depth++;
            }
            if (css[i] !== "}" || depth === 0 || --depth !== 0) continue;
            start = i + 1;
            if (selectorText.startsWith("@")) continue;
            const props = declarations(css.slice(bodyStart, i));
            for (const value of selectorText.split(",")) {
                const selector = selectorParts(value);
                if (!selector) continue;
                rules.push({chain:selector.chain, weight:selector.weight, props});
                if (rules.length >= rulesLimit) return rules.sort((a,b) => a.weight - b.weight);
            }
        }
    }
    return rules.sort((a,b) => a.weight - b.weight);
}

function attributes(tag) {
    const attrs = Object.create(null);
    for (const item of tag.matchAll(/([^\s=/"'<>]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g))
        attrs[item[1].toLowerCase()] = decode(item[2] || item[3] || item[4] || "");
    return attrs;
}

function resolveCssValue(value, variables) {
    for (let n = 0; n < 8; n++) {
        const match = /^var\(\s*(--[\w-]+)\s*(?:,\s*([\s\S]+))?\)$/.exec(value);
        if (!match) return value;
        value = variables[match[1]] || match[2] || "";
    }
    return "";
}

function* parseSteps(body, url, sheets = stylesheetSources(body, url)) {
    const rules = cssRules(sheets);

    const rows = [], article = [], info = [];
    let preview = false;
    const inline = new Set(["a","span","b","strong","em","i","small","sup","sub","abbr","code","mark","time","wbr"]);
    const stack = [{tag: "", css: {}, link: "", hidden: false}];
    let runs = [], characters = 0, images = 0, mediaCount = 0;
    function add(row, current) {
        if (current.infobox && current.article) {
            if (info.length < 48) info.push(row);
            return;
        }
        row.heading = /^h[1-6]$/.test(current.tag) ? current.tag : "";
        if (rows.length < 600) rows.push(row);
        if (current.article && !current.chrome && article.length < 600) article.push(row);
    }
    function appendText(value, current) {
        if (current.hidden || !value) return;
        const last = runs[runs.length - 1];
        if (last && last.link === current.link) last.text += value;
        else runs.push({text:value,link:current.link});
        characters += value.length;
    }
    function flush() {
        let block = stack.length - 1;
        while (block > 0 && stack[block].inline) block--;
        const current = stack[block];
        const text = runs.map(run => run.text).join("").replace(/\s+/g, " ").trim();
        if (text && !current.hidden) {
            const rich = runs.some(run => run.link);
            add({text, css:current.css, runs:rich ? runs : undefined}, current);
        }
        runs = [];
        characters = 0;
    }
    const tags = /<(\/?)([a-z][\w:-]*)((?:"[^"]*"|'[^']*'|[^'">])*)>|([^<]+|<)/gi;
    let processed = 0;
    let token;
    while ((token = tags.exec(body))) {
        if (++processed % 24 === 0) {
            if (!preview && article.length >= 10) {
                preview = true;
                const first = article.slice();
                first.info = info.slice();
                yield first;
            } else yield;
        }
        if (article.length >= 600) break;
        if (token[4]) {
            if (token[4] === "<") {
                const start = token.index;
                if (body.startsWith("<!--", start)) {
                    const end = body.indexOf("-->", start + 4);
                    tags.lastIndex = end < 0 ? body.length : end + 3;
                    continue;
                }
                if (body.slice(start, start + 9).toLowerCase() === "<!doctype") {
                    const end = body.indexOf(">", start + 9);
                    tags.lastIndex = end < 0 ? body.length : end + 1;
                    continue;
                }
            }
            appendText(decode(token[4].slice(0, 4096)), stack[stack.length - 1]);
            if (characters > 4096 || runs.length >= 64) flush();
            continue;
        }
        const name = token[2].toLowerCase();
        if (!token[1] && (name === "script" || name === "style" || name === "head" || name === "template")) {
            const closeTag = "</" + name + ">";
            const exact = body.indexOf(closeTag, tags.lastIndex);
            if (exact >= 0) {
                tags.lastIndex = exact + closeTag.length;
            } else {
                const closer = new RegExp("</" + name + "\\s*>", "ig");
                closer.lastIndex = tags.lastIndex;
                tags.lastIndex = closer.exec(body) ? closer.lastIndex : body.length;
            }
            continue;
        }
        if (token[1]) {
            for (let i = stack.length - 1; i > 0; i--) {
                if (stack[i].tag !== name) continue;
                if (!stack[i].inline || stack[i].hidden) flush();
                stack.length = i;
                break;
            }
            continue;
        }
        if (name === "br" || name === "hr") { flush(); continue; }
        if (["area","base","col","embed","input","link","meta","param","track","wbr"].includes(name)) continue;
        const parent = stack[stack.length - 1];
        const attrs = attributes(token[3]);
        if (name === "video" || name === "audio" || name === "source") {
            const audio = name === "audio" || (name === "source" && parent.tag === "audio");
            const supported = name !== "source" || parent.tag === "video" || parent.tag === "audio";
            const stream = supported && attrs.src && resolve(attrs.src, url);
            if (stream && !parent.hidden && mediaCount < 12) {
                flush();
                add({stream, audio, text:audio ? "Sesi oynat" : "Videoyu oynat"}, parent);
                mediaCount++;
            }
            if (name === "source") continue;
        }
        if (name === "img") {
            const image = resolve(attrs.src || "", url);
            if (attrs.src && image && !parent.hidden && images < 32) {
                images++;
                flush();
                const height = Number(attrs.height), width = Number(attrs.width);
                if (!(height > 0 && width > 0 && (height <= 32 || width <= 32)))
                    add({image,text:attrs.alt || "Görsel",link:parent.link,height:height > 0 ? Math.min(180,height) : 96}, parent);
            }
            continue;
        }
        if (stack.length >= 64) continue;
        const css = Object.create(null);
        for (const key of inherited) {
            if (parent.css[key] !== undefined) css[key] = parent.css[key];
        }
        const element = {tag:name,id:attrs.id || "",classes:(attrs.class || "").split(/\s+/)};
        if (/^h[123]$/.test(name)) {
            css["font-size"] = ({h1:"30px",h2:"25px",h3:"21px"})[name];
            css["font-weight"] = "bold";
        }
        if (name === "b" || name === "strong") css["font-weight"] = "bold";
        if (name === "i" || name === "em") css["font-style"] = "italic";
        for (const rule of rules) {
            if (!matchesSelector(rule.chain, element, stack)) continue;
            Object.assign(css, rule.props);
        }
        Object.assign(css, declarations(attrs.style || ""));
        const variables = Object.create(parent.variables || null);
        for (const key of Object.keys(css)) {
            if (key.startsWith("--")) {
                variables[key] = css[key];
                delete css[key];
            }
        }
        for (const key of Object.keys(css)) css[key] = resolveCssValue(css[key], variables);
        const hidden = parent.hidden || css.display === "none" || "hidden" in attrs;
        delete css.display;
        const link = name === "a" && attrs.href ? resolve(attrs.href, url) : parent.link;
        const inlineTag = inline.has(name);
        const articleBody = parent.article || name === "main" || name === "article" || attrs.role === "main";
        const chrome = parent.chrome || name === "nav" || name === "footer" || attrs.role === "navigation"
            || element.classes.some(value => /^(vector-page-toolbar|vector-column-start|vector-column-end|mw-editsection|shortdescription|hatnote|metadata)$/.test(value));
        const infobox = parent.infobox || (name === "table" && element.classes.includes("infobox"));
        if (!inlineTag || hidden !== parent.hidden) flush();
        stack.push(Object.assign(element, {css,link,hidden,variables,inline:inlineTag,article:articleBody,chrome,infobox}));
    }
    flush();
    const result = article.length >= 5 ? article : rows;
    result.info = info;
    return result;
}

function cancel(tab) {
    tab.revision++;
    tab.parser = undefined;
    if (tab.youtube) tab.youtube.loadingStream = false;
    if (tab.request) net.cancel(tab.request);
    tab.request = 0;
    for (const id of tab.styles) net.cancel(id);
    tab.styles = [];
}

function loadStyles(tab, body, revision) {
    const base = tab.url;
    const sheets = stylesheetSources(body, base);
    const pending = sheets.filter(sheet => sheet.href).slice(0, 4);
    function renderDocument() {
        tab.parser = parseSteps(body, base, sheets);
    }
    renderDocument();
    if (!pending.length) return;

    let remaining = pending.length;
    for (const sheet of pending) {
        let id;
        id = net.request({url:sheet.href, timeout:8, maxBytes:262144, cache:300,
            redirects:false, headers:Object.assign({Accept:"text/css"},desktopHeaders)}, result => {
            if (tab.revision !== revision) return;
            tab.styles = tab.styles.filter(request => request !== id);
            const type = String((result.headers || {})["content-type"] || result.contentType || "").trim();
            if (result.ok && /^text\/css\b/i.test(type)) sheet.text = result.body || "";
            if (--remaining === 0) renderDocument();
        });
        if (id) tab.styles.push(id);
        else if (--remaining === 0) renderDocument();
    }
}

function finishDocument(tab, rows) {
        if (tab.watch) {
            const direct = rows.find(row => row.stream && !row.audio);
            if (direct) tab.watch.stream = direct.stream;
            tab.status = tab.url;
            return;
        }
        const title = tab.title.replace(/\s+[-–—|]\s+(Wikipedia|GitHub)$/i, "");
        if (title && rows.length >= 8 && !rows.slice(0, 5).some(row => row.text === title))
            rows.unshift({text:title,css:{"font-size":"28px","font-weight":"bold","margin-bottom":"8px"}});
        const info = tab.docInfo;
        const visibleText = rows.reduce((total, row) => total + (row.text || "").length, 0);
        const hasMedia = rows.some(row => row.stream);
        if (info.scripts && visibleText < 450 && !hasMedia) {
            rows.unshift({text:"Bu sayfanın etkileşimli bölümleri JavaScript gerektiriyor.",
                css:{"background-color":"#293849",color:"#ffffff",padding:"9px"}});
            if (info.description) rows.unshift({text:info.description,css:{}});
            if (info.title && !rows.some(row => row.text === info.title))
                rows.unshift({text:info.title,css:{"font-size":"25px","font-weight":"bold"}});
        }
        tab.info = rows.info || [];
        tab.sections = rows.filter(row => row.heading === "h2" || row.heading === "h3").slice(0, 20);
        tab.rows = rows;
        tab.status = rows.length ? (tab.stale ? "Önbellekteki kopya" : tab.url) : "Gösterilebilir içerik bulunamadı.";
}

let nextParserTab = 0;
app.update = function() {
    for (let i = 0; i < tabs.length; ++i) {
        const tab = tabs[nextParserTab++ % tabs.length];
        if (!tab.parser) continue;
        const result = tab.parser.next();
        if (!result.done && result.value && !tab.rows.length) {
            finishDocument(tab, result.value);
            tab.status = "Sayfa açık · içerik yükleniyor";
        }
        if (result.done) {
            tab.parser = undefined;
            finishDocument(tab, result.value);
        }
        break;
    }
};

function describeDocument(body) {
    const head = body.slice(0, 262144);
    const title = /<title\b[^>]*>([\s\S]*?)<\/title\s*>/i.exec(head);
    const meta = /<meta\s+[^>]*(?:name\s*=\s*["']description["']|property\s*=\s*["']og:description["'])[^>]*>/i.exec(head);
    const description = meta ? attributes(meta[0].slice(5, -1)).content || "" : "";
    return {
        title:title ? decode(title[1]).replace(/\s+/g, " ").trim().slice(0, 160) : "",
        description:description.slice(0, 480),
        scripts:/<script\b/i.test(body),
    };
}

function searchResults(body, url) {
    const page = new URL(url);
    if (page.hostname !== "html.duckduckgo.com" || !/^\/html\/?$/.test(page.pathname)) return null;
    const query = page.searchParams.get("q");
    if (!query) return null;
    const items = [], seen = new Set();
    const clean = html => decode(html.replace(/<[^>]+>/g, "")).replace(/\s+/g, " ").trim();
    const anchors = body.slice(0, 350000).matchAll(/<a\s+([^>]+)>([\s\S]*?)<\/a>/gi);
    for (const anchor of anchors) {
        const a = attributes(anchor[1]);
        if (!(a.class || "").split(/\s+/).includes("result__a")) continue;
        let href = a.href && resolve(a.href, url);
        if (!href) continue;
        const link = new URL(href);
        if (["duckduckgo.com","html.duckduckgo.com"].includes(link.hostname) && /^\/l\/?$/.test(link.pathname))
            href = resolve(link.searchParams.get("uddg") || "");
        const title = clean(anchor[2]).slice(0, 155);
        if (!href || !title || seen.has(href)) continue;
        seen.add(href);
        items.push({title, href});
        if (items.length === 25) break;
    }
    return {query, items};
}

function netflixAsset(value, page) {
    if (!value) return "";
    const url = resolve(value, page);
    if (!url) return "";
    const address = new URL(url);
    return address.protocol === "https:" && !address.port
        && /\.(?:nflxso\.net|nflximg\.net|nflximg\.com|netflix\.com)$/i.test(address.hostname) ? url : "";
}

function netflixPreviews(body, page, meta, details) {
    const list = [], seen = new Set();
    function add(value, title, seconds = 0) {
        const url = netflixAsset(value, page);
        if (!url) return;
        const asset = new URL(url);
        if (!/\.nflxso\.net$/i.test(asset.hostname) || !/^\/so\/.+\.mp4$/i.test(asset.pathname)) return;
        if (seen.has(asset.pathname)) return;
        seen.add(asset.pathname);
        list.push({url, title:String(title || label("Fragman", "Trailer")).slice(0, 150), seconds:Number(seconds) || 0});
    }
    const trailer = details.trailer || {};
    add(meta["og:video:secure_url"] || meta["og:video"], trailer.name);
    add(trailer.contentUrl, trailer.name);
    const supplemental = /"playableVideo"\s*:\s*\{[^{}]{0,4000}?"url"\s*:\s*"((?:\\.|[^"\\]){1,3400})"[^{}]{0,60}\}\s*,\s*"runtimeSec"\s*:\s*(\d+)\s*,\s*"title"\s*:\s*"((?:\\.|[^"\\]){1,700})"\s*,\s*"type"\s*:\s*"TRAILER"/g;
    function unescape(value) {
        try { return JSON.parse('"' + value.replace(/\\x([0-9a-f]{2})/gi, "\\u00$1") + '"'); }
        catch (_) { return ""; }
    }
    for (const match of body.slice(0, 2800000).matchAll(supplemental)) {
        add(unescape(match[1]), unescape(match[3]), match[2]);
        if (list.length >= 12) break;
    }
    return list;
}

function netflixTitle(body, url, info) {
    const address = new URL(url);
    if (!["netflix.com", "www.netflix.com"].includes(address.hostname)
        || !/^\/(?:[a-z]{2}(?:-[a-z]{2})?\/)?title\/\d+\/?$/i.test(address.pathname)) return null;
    const metadata = Object.create(null);
    for (const match of body.slice(0, 262144).matchAll(/<meta\s+([^>]+)>/gi)) {
        const tag = attributes(match[1]);
        if (tag.property && tag.content && !metadata[tag.property]) metadata[tag.property] = tag.content;
    }
    const title = (metadata["og:title"] || info.title).replace(/^Watch\s+/i, "").replace(/\s*\|\s*Netflix.*$/i, "").trim();
    if (!title) return null;
    let details = {};
    const structured = /<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]{1,100000}?)<\/script>/i.exec(body.slice(0, 600000));
    if (structured) {
        try {
            const data = JSON.parse(structured[1]);
            if (data && typeof data === "object") details = data;
        } catch (_) {}
    }
    const previews = netflixPreviews(body, url, metadata, details);
    const year = /^\d{4}/.exec(String(details.dateCreated || details.startDate || ""));
    const genre = typeof details.genre === "string" ? details.genre : Array.isArray(details.genre) ? details.genre.join(" / ") : "";
    return {
        title: title.slice(0, 160),
        description: (metadata["og:description"] || info.description).slice(0, 480),
        poster: netflixAsset(metadata["og:image"], url),
        previews,
        summary:[year && year[0], details.contentRating, genre].filter(Boolean).join(" · ").slice(0, 110),
    };
}

function youtubeData(body, field) {
    const marker = new RegExp("\\b" + field + "\\s*=\\s*(?=\\{)").exec(body);
    if (!marker) return null;
    const start = marker.index + marker[0].length;
    const end = body.indexOf("</script", start);
    if (end < start || end - start > 2500000) return null;
    const last = body.lastIndexOf("}", end);
    try { return JSON.parse(body.slice(start, last + 1)); } catch (_) { return null; }
}

function youtubeText(value) {
    if (!value) return "";
    return value.simpleText || value.content || (value.runs || []).map(run => run.text).join("");
}

function youtubeVideos(data, current) {
    const items = [], seen = new Set([current]);
    const stack = data && data.contents ? [data.contents] : [];
    for (let scanned = 0; stack.length && scanned < 9000 && items.length < 24; scanned++) {
        const node = stack.pop();
        if (!node || typeof node !== "object") continue;
        const card = node.videoRenderer || node.compactVideoRenderer || node.videoWithContextRenderer || node.lockupViewModel;
        if (card) {
            const id = card.videoId || card.contentId || "";
            const name = youtubeText(card.title || (card.metadata && card.metadata.lockupMetadataViewModel
                && card.metadata.lockupMetadataViewModel.title));
            if (videoId.test(id) && name && !seen.has(id)) {
                seen.add(id);
                items.push({id, title:name.slice(0, 180), length:youtubeText(card.lengthText).slice(0, 16),
                    author:youtubeText(card.ownerText || card.shortBylineText).slice(0, 80)});
            }
            continue;
        }
        const children = Object.values(node);
        for (let i = children.length - 1; i >= 0; i--) {
            if (children[i] && typeof children[i] === "object") stack.push(children[i]);
        }
    }
    return items;
}

function youtubeStream(response) {
    if (!response || !response.streamingData || !response.playabilityStatus
        || response.playabilityStatus.status !== "OK") return "";
    const formats = response.streamingData.formats || [];
    const candidates = formats.filter(f => typeof f.url === "string"
        && /^video\/mp4\b/i.test(f.mimeType || "") && Number(f.height) <= 720)
        .sort((a, b) => b.height - a.height);
    for (const format of candidates) {
        const url = resolve(format.url);
        if (!url) continue;
        const cdn = new URL(url);
        if (cdn.protocol === "https:" && !cdn.port && cdn.hostname.endsWith(".googlevideo.com"))
            return url;
    }
    return "";
}

function playYouTube(tab) {
    const watch = tab.youtube;
    if (watch.loadingStream) return;
    watch.loadingStream = true;
    watch.error = "";
    const revision = tab.revision;
    const clientVersion = "21.02.35";
    const client = {clientName:"ANDROID", clientVersion, androidSdkVersion:30,
        osName:"Android", osVersion:"11", hl:settings().language};
    let request;
    request = net.request({url:youtubeHome + "youtubei/v1/player?prettyPrint=false",
        method:"POST", body:JSON.stringify({context:{client}, videoId:watch.id}), contentType:"application/json",
        timeout:16, maxBytes:1600000, cache:false, responseType:"json", headers:{
            "User-Agent":"com.google.android.youtube/" + clientVersion + " (Linux; U; Android 11) gzip",
            "X-YouTube-Client-Name":"3",
            "X-YouTube-Client-Version":clientVersion,
    }}, result => {
        if (tab.revision !== revision || tab.youtube !== watch) return;
        tab.styles = tab.styles.filter(id => id !== request);
        watch.loadingStream = false;
        const response = result.ok && result.data;
        const stream = response && response.videoDetails && response.videoDetails.videoId === watch.id
            ? youtubeStream(response) : "";
        if (!stream) {
            watch.error = result.ok ? label("Bu video için uyumlu akış sunulmadı.", "No compatible stream was offered for this video.")
                : networkFailure(result);
            return;
        }
        const details = response.videoDetails;
        watch.title = (details.title || watch.title).slice(0, 180);
        watch.author = (details.author || watch.author).slice(0, 90);
        tab.title = watch.title;
        if (tabs[active] === tab) playMedia(tab, stream, false);
    });
    if (request) tab.styles.push(request);
    else {
        watch.loadingStream = false;
        watch.error = label("Video isteği başlatılamadı.", "Could not start the video request.");
    }
}

function networkFailure(result) {
    const code = Number(result.status) || 0;
    const error = String(result.error || "").toLowerCase();
    if (/size|limit|writ(?:e|ing)|large/.test(error) && code >= 200 && code < 300)
        return "Belge aktarım sınırına ulaştı.";
    if (/timed?\s*out|timeout/.test(error)) return "Ağ isteği zaman aşımına uğradı.";
    if (code >= 400) return "Sunucu HTTP " + code + " döndürdü.";
    if (code >= 200 && code < 300) return "Sunucu yanıt verdi, aktarım tamamlanamadı.";
    return "Ağ bağlantısı kurulamadı.";
}

function openPage(tab, value, historyIndex) {
    const input = value.trim();
    if (!input) return;
    if (input.length > 4096) {
        tab.status = label("Adres veya arama çok uzun.", "Address or search is too long.");
        return;
    }
    const candidate = /^https?:\/\//i.test(input) ? input
        : /^[\w.-]+\.[\w-]+(?:[/:?#][^\s]*)?$/.test(input) ? "https://" + input
        : searchEngines[settings().engine] + encodeURIComponent(input);
    let url = resolve(candidate);
    if (!url) { tab.status = "Adres geçersiz."; return; }
    const youtube = youtubePage(url);
    if (youtube) url = youtubeUrl(youtube);
    cancel(tab);
    tab.catalog = false;
    tab.find = "";
    tab.findOpen = false;
    tab.suggest = false;
    tab.youtube = youtube && Object.assign(youtube, {items:[], title:"YouTube", author:"", error:""});
    if (youtube && youtube.query) tab.youtubeQuery = youtube.query;
    tab.netflix = null;
    tab.search = null;
    tab.directMedia = null;
    tab.rows = [];
    tab.info = [];
    tab.sections = [];
    if (mediaTab === tab) closeMedia();
    const pathname = new URL(url).pathname;
    if (/\.(mp4|webm|mkv|m3u8|mp3|aac|ogg)$/i.test(pathname)) {
        tab.address = tab.draft = url;
        tab.title = new URL(url).hostname;
        tab.status = url;
        recordPage(tab, url, historyIndex);
        tab.directMedia = {url, audio:/\.(mp3|aac|ogg)$/i.test(pathname)};
        if (tabs[active] === tab) playMedia(tab, url, tab.directMedia.audio);
        return;
    }
    const revision = tab.revision;
    tab.address = tab.draft = url;
    tab.title = youtube ? "YouTube" : new URL(url).hostname;
    tab.status = "Yükleniyor…";
    tab.reason = "";
    recordPage(tab, url, historyIndex);
    const navigationIndex = tab.index;
    const netflix = ["netflix.com", "www.netflix.com"].includes(new URL(url).hostname);
    tab.request = net.request({url, timeout:22, maxBytes:6291456, retry:1, cache:false,
        headers:Object.assign({Accept:"text/html, application/xhtml+xml, text/plain;q=0.9"},desktopHeaders)}, result => {
        if (tab.revision !== revision) return;
        tab.request = 0;
        if (!result.ok) {
            tab.reason = String(result.error || "").slice(0, 180);
            tab.status = networkFailure(result);
            if (youtube) youtube.error = tab.status;
            return;
        }
        const type = String(result.contentType || (result.headers || {})["content-type"] || "").toLowerCase();
        if (!/^(text\/html|text\/plain|application\/xhtml\+xml)\b/.test(type)) {
            tab.status = "Bu içerik türü desteklenmiyor.";
            return;
        }
        tab.url = resolve(result.url || url) || url;
        if (tab.draft === tab.address) tab.draft = tab.url;
        tab.address = tab.url;
        const body = result.body || "";
        tab.title = "";
        tab.stale = Boolean(result.stale);
        tab.search = !youtube && searchResults(body, tab.url);
        if (tab.search && tab.search.items.length) {
            tab.title = tab.search.query;
            tab.status = tab.search.items.length + label(" arama sonucu", " search results");
            recordPage(tab, tab.url, navigationIndex);
            rememberPage(tab);
            return;
        }
        if (youtube) {
            const info = describeDocument(body);
            const response = youtube.kind === "watch" ? youtubeData(body, "ytInitialPlayerResponse") : null;
            const details = response && response.videoDetails || {};
            youtube.title = (details.title || info.title.replace(/\s+-\s+YouTube$/, "") || "YouTube").slice(0, 180);
            youtube.author = (details.author || "").slice(0, 90);
            youtube.items = youtubeVideos(youtubeData(body, "ytInitialData"), youtube.id);
            tab.title = youtube.kind === "watch" ? youtube.title : youtube.query || "YouTube";
            tab.status = youtube.kind === "watch" ? tab.url
                : youtube.items.length + label(" video bulundu", " videos found");
            recordPage(tab, tab.url, navigationIndex);
            rememberPage(tab);
            return;
        }
        if (type.startsWith("text/plain")) {
            tab.rows = body.split(/\r?\n/, 600).map(text => ({text:text.slice(0, 4096),css:{}}));
        } else {
            const info = describeDocument(body);
            tab.title = info.title;
            tab.docInfo = info;
            tab.netflix = netflixTitle(body, tab.url, info) || (netflix ? {
                title: info.title || "Netflix", description: info.description,
            } : null);
            if (tab.netflix) {
                tab.rows = [];
                tab.title = tab.netflix.title;
            } else loadStyles(tab, body, revision);
        }
        recordPage(tab, tab.url, navigationIndex);
        rememberPage(tab);
        tab.status = tab.parser ? "Belge işleniyor…" : tab.stale ? "Önbellekteki kopya" : tab.netflix || tab.rows.length ? tab.url : "Gösterilebilir içerik bulunamadı.";
    });
    if (!tab.request) tab.status = label("İstek başlatılamadı.", "Could not start the request.");
}

function recordPage(tab, url, index) {
    tab.url = url;
    if (index === undefined && tab.history[tab.index] !== url) {
        tab.history = tab.history.slice(0, tab.index + 1).concat(url).slice(-50);
        tab.index = tab.history.length - 1;
    } else if (index !== undefined) {
        tab.index = index;
        tab.history[index] = url;
    }
}

function rememberPage(tab) {
    const prefs = settings();
    if (!prefs.keepHistory) return;
    prefs.recent = [{url:tab.url, title:tab.title || tab.url}]
        .concat(prefs.recent.filter(item => item.url !== tab.url)).slice(0, 100);
    store.set("browser-settings", prefs);
}

let player;
let mediaTab;
let mediaMuted = false;
let mediaTheater = false;
let mediaRate = 1;
const playbackRates = [0.75, 1, 1.25, 1.5, 2];

function closeMedia() {
    if (player) media.close(player);
    player = undefined;
    mediaTab = undefined;
    mediaTheater = false;
}

function playMedia(tab, url, audio) {
    closeMedia();
    player = media.open(url, {autoplay:true, audioOnly:audio, muted:mediaMuted, speed:mediaRate});
    if (player) mediaTab = tab;
    else tab.status = "Medya açılamadı.";
}

function cssPixels(value, max) {
    const match = /^([0-9]+(?:\.[0-9]+)?)px$/.exec(value || "");
    return match ? Math.min(Number(match[1]), max) : 0;
}

function layoutRuns(runs, width, size, font, align) {
    const lines = [{width:0, fragments:[]}];
    const spaceWidth = Math.max(1, gfx.textWidth(" ", size, font));
    let pendingSpace = false;
    for (const run of runs) {
        for (const token of run.text.match(/\s+|\S+/g) || []) {
            if (/^\s/.test(token)) { pendingSpace = true; continue; }
            let line = lines[lines.length - 1];
            const wordWidth = gfx.textWidth(token, size, font);
            let gap = pendingSpace && line.fragments.length ? spaceWidth : 0;
            if (line.fragments.length && line.width + gap + wordWidth > width) {
                line = {width:0, fragments:[]};
                lines.push(line);
                gap = 0;
            }
            line.width += gap;
            line.fragments.push({text:token,link:run.link,x:line.width,w:wordWidth});
            line.width += wordWidth;
            pendingSpace = false;
        }
    }
    const lineHeight = Math.ceil(size * 1.45);
    for (const line of lines) {
        line.offset = Math.max(0, (width - line.width) * (align === "center" ? 0.5 : align === "right" ? 1 : 0));
    }
    return {lines,lineHeight,height:lines.length * lineHeight};
}

let measuredZoom;
let measuredReader;
function measure(tab, rows, width) {
    if (measuredTab !== tab || measuredWidth !== width || measuredDocument !== rows
        || measuredZoom !== tab.zoom || measuredReader !== tab.reader) {
        measuredTab = tab;
        measuredWidth = width;
        measuredDocument = rows;
        measuredZoom = tab.zoom;
        measuredReader = tab.reader;
        contentHeight = 8;
        layout = [];
    }
    const end = Math.min(rows.length, layout.length + 16);
    const deadline = performance.now() + 3;
    for (let i = layout.length; i < end; i++) {
        const row = rows[i];
        const css = tab.reader && !row.heading ? {} : row.css || {};
        const baseSize = Number((css["font-size"] || "").replace(/px$/, "")) || (tab.reader ? 18 : 17);
        const size = Math.max(10, Math.min(55, baseSize * tab.zoom / 100));
        const font = /^(bold|[7-9]00)$/.test(css["font-weight"]) ? "bold" : css["font-style"] === "italic" ? "italic" : "sans";
        const isText = !row.image && !row.stream && !row.entry;
        const padding = isText ? cssPixels(css.padding, 40) : 0;
        const margin = isText ? cssPixels(css["margin-top"], 50) : 0;
        const maxWidth = isText ? cssPixels(css["max-width"], width) : 0;
        const textWidth = (maxWidth || width) - 2 * padding;
        const innerWidth = Math.max(40, textWidth);
        const rich = row.runs && layoutRuns(row.runs, innerWidth, size, font, css["text-align"]);
        const height = row.image ? row.height || 96 : row.stream ? 32
            : Math.max(20, rich ? rich.height : gfx.measureWrap(row.text, innerWidth, size, font)) + 2 * padding;
        const item = {y:contentHeight + margin, height, size, font, padding, innerWidth, rich};
        contentHeight += margin + height + 8 + (isText ? cssPixels(css["margin-bottom"], 50) : 0);
        layout.push(item);
        if (performance.now() >= deadline) break;
    }
}

app.load = function(arg) {
    const session = !arg && settings().restoreTabs && store.get("browser-session", {});
    const saved = session && Array.isArray(session.tabs) ? session.tabs.slice(0, maxTabs) : [];
    for (const item of saved) {
        if (!item || typeof item !== "object") continue;
        const tab = newTab();
        tab.restore = typeof item.url === "string" ? resolve(item.url) : "";
        tab.title = typeof item.title === "string" ? item.title.slice(0, 160) : "";
        tab.zoom = [80,90,100,110,125,150,175].includes(item.zoom) ? item.zoom : 100;
        tab.reader = item.reader === true;
        tabs.push(tab);
    }
    if (!tabs.length) tabs.push(newTab());
    active = saved.length ? Math.max(0, Math.min(tabs.length - 1, Math.trunc(Number(session.active) || 0))) : 0;
    if (arg) openPage(tabs[active], arg);
    else activateTab(active);
};
app.open = function(arg) { if (arg) openPage(tabs[active], arg); };
app.close = function() {
    if (settings().restoreTabs) {
        store.set("browser-session", {active, tabs:tabs.map(tab => ({
            url:tab.restore || tab.url, title:tab.title, zoom:tab.zoom, reader:tab.reader,
        }))});
    }
    for (const tab of tabs) cancel(tab);
    for (const item of downloads) {
        if (item.request) net.cancel(item.request);
        if (fs.exists(item.temporary)) fs.remove(item.temporary, true);
    }
    closeMedia();
    return true;
};
app.suspend = function() { if (player) media.pause(player); };

function activateTab(index) {
    const tab = tabs[index];
    if (!tab) return;
    if (index !== active && player) closeMedia();
    active = index;
    if (tab.restore) {
        const url = tab.restore;
        tab.restore = "";
        openPage(tab, url);
    }
}

function addTab(url, select = true) {
    if (tabs.length >= maxTabs) {
        tabs[active].status = label("Sekme sınırına ulaşıldı.", "Tab limit reached.");
        return;
    }
    const tab = newTab();
    tabs.push(tab);
    if (select) activateTab(tabs.length - 1);
    if (url) openPage(tab, url);
}

function closeTab(index) {
    const tab = tabs[index];
    if (!tab) return;
    const url = tab.restore || tab.url;
    if (url) {
        closedTabs.push({url, title:tab.title, history:tab.history.slice(), index:tab.index});
        if (closedTabs.length > maxTabs) closedTabs.shift();
    }
    cancel(tab);
    if (mediaTab === tab) closeMedia();
    tabs.splice(index, 1);
    if (!tabs.length) tabs.push(newTab());
    if (index < active || active >= tabs.length) active = Math.max(0, active - 1);
    activateTab(active);
}

function reopenTab() {
    if (!closedTabs.length || tabs.length >= maxTabs) return;
    const saved = closedTabs.pop();
    addTab();
    const tab = tabs[active];
    tab.history = saved.history;
    tab.index = saved.index;
    openPage(tab, saved.url, tab.index >= 0 ? tab.index : undefined);
}

const zoomLevels = [80, 90, 100, 110, 125, 150, 175];
function zoomPage(tab, step) {
    const at = zoomLevels.indexOf(tab.zoom);
    tab.zoom = step ? zoomLevels[Math.max(0, Math.min(zoomLevels.length - 1, at + step))] : 100;
}

let focusField = "";
app.event = function(e) {
    if (e.type !== "keydown" || !tabs.length) return;
    const tab = tabs[active];
    if (e.key === "escape") {
        tab.suggest = false;
        if (browserMenu) browserMenu = "";
        else if (tab.findOpen) { tab.findOpen = false; tab.find = ""; }
        else if (mediaTheater) mediaTheater = false;
        return;
    }
    if (!e.ctrl) return;
    if (e.key === "l") {
        browserMenu = "";
        mediaTheater = false;
        focusField = "address-" + tab.key;
    } else if (e.key === "t") {
        if (e.shift) reopenTab();
        else addTab();
    } else if (e.key === "w") closeTab(active);
    else if (e.key === "tab") activateTab((active + tabs.length + (e.shift ? -1 : 1)) % tabs.length);
    else if (e.key === "r" && tab.address) openPage(tab, tab.address, tab.index);
    else if (e.key === "d") toggleBookmark(tab);
    else if (e.key === "f" && tab.rows.length && !tab.catalog) {
        browserMenu = "";
        tab.findOpen = true;
        focusField = "find-" + tab.key;
    } else if (e.key === "h") showMenu("history");
    else if (e.key === "j") showMenu("downloads");
    else if (e.key === "=" || e.key === "+") zoomPage(tab, 1);
    else if (e.key === "-") zoomPage(tab, -1);
    else if (e.key === "0") zoomPage(tab, 0);
};

function drawInfoBox(rows, x, y, width, height) {
    if (height < 65) return;
    gfx.rect(x, y, width, height, 4, theme.sidebar);
    let at = y + 8;
    for (const row of rows) {
        if (at + 24 > y + height) break;
        if (row.stream) continue;
        if (row.image) {
            const img = gfx.imageUrl(row.image, 480);
            if (img) {
                const scale = Math.min((width - 14) / img.width, 174 / img.height, (y + height - at - 8) / img.height);
                if (scale > 0) gfx.draw(img, x + (width - img.width * scale) / 2, at, img.width * scale, img.height * scale);
                at += img.height * scale + 8;
            } else {
                at += 35;
            }
        } else {
            gfx.color(theme.text);
            gfx.text(row.text.slice(0, 32), x + 8, at, 13, "medium");
            at += 21;
        }
    }
}

let browserMenu = "";
let libraryQuery = "";
let browserSettings;
const nightChrome = {
    top:"#121b2c", bar:"#202d42", active:"#30415e", hover:"#394d6b", field:"#101a2b",
    text:"#edf5ff", muted:"#a6bad5", accent:"#76ddff", border:"#3b5071",
};
const oceanChrome = {
    top:"#12343e", bar:"#1c4c56", active:"#306475", hover:"#3e7584", field:"#122d36",
    text:"#e9fbff", muted:"#afcdd1", accent:"#8af2db", border:"#497c86",
};
let chrome = nightChrome;

function savedLinks(value, limit) {
    if (!Array.isArray(value)) return [];
    return value.filter(item => item && typeof item.url === "string" && resolve(item.url))
        .slice(0, limit).map(item => ({
            url:item.url, title:typeof item.title === "string" ? item.title.slice(0, 180) : item.url,
        }));
}

function settings() {
    if (!browserSettings) {
        const saved = store.get("browser-settings", {}) || {};
        browserSettings = {
            language:saved.language || (sys.lang() === "tr" ? "tr" : "en"),
            engine:Object.hasOwn(searchEngines, saved.engine) ? saved.engine : "DuckDuckGo",
            bookmarks:savedLinks(saved.bookmarks, 50),
            recent:savedLinks(saved.recent, 100),
            appearance:saved.appearance === "ocean" ? "ocean" : "night",
            keepHistory:saved.keepHistory !== false,
            restoreTabs:saved.restoreTabs === true,
        };
    }
    return browserSettings;
}

function label(tr, en) {
    return settings().language === "en" ? en : tr;
}

function showMenu(section) {
    browserMenu = section;
    libraryQuery = "";
}

function searchable(value) {
    return value.normalize("NFKD").replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/ı/g, "i");
}

function visibleRows(tab) {
    if (tab.catalog || (!tab.find.trim() && !tab.reader)) return tab.rows;
    if (tab.filteredSource !== tab.rows || tab.filteredTerm !== tab.find || tab.filteredReader !== tab.reader) {
        const term = searchable(tab.find.trim());
        tab.filteredRows = tab.rows.filter(row => {
            if (tab.reader && (row.image || row.stream || !row.text.trim())) return false;
            return !term || searchable(row.text || "").includes(term);
        });
        tab.filteredSource = tab.rows;
        tab.filteredTerm = tab.find;
        tab.filteredReader = tab.reader;
    }
    return tab.filteredRows;
}

function visitSuggestions(tab) {
    const query = tab.draft.trim();
    if (!query || !tab.suggest || tab.draft === tab.address) return [];
    const term = searchable(query);
    const prefs = settings();
    const seen = new Set();
    const matches = [];
    for (const entry of prefs.bookmarks.concat(prefs.recent)) {
        if (seen.has(entry.url) || !searchable(entry.title + " " + entry.url).includes(term)) continue;
        seen.add(entry.url);
        matches.push(entry);
        if (matches.length === 5) break;
    }
    return matches;
}

function drawSuggestions(tab, items, x, w) {
    gfx.rect(x, 82, w, 43 + items.length * 43, 8, theme.window);
    ui.label(label("Favoriler ve geçmiş", "Bookmarks and history"), x + 13, 95, 13, theme.text2, "bold");
    if (ui.button("×##close-suggestions", x + w - 31, 86, 24, 28, "toolbar")) tab.suggest = false;
    for (let i = 0; i < items.length; i++) {
        const entry = items[i], y = 120 + i * 43;
        const hit = ui.hit("address-suggestion-" + i, x + 7, y, w - 14, 40);
        if (hit.hovered) gfx.rect(x + 7, y, w - 14, 40, 6, theme.sidebar);
        ui.label(fitText(entry.title, w - 26, 14), x + 13, y + 3, 14, theme.text);
        ui.label(fitText(entry.url, w - 26, 11), x + 13, y + 21, 11, theme.text2);
        if (hit.clicked) { openPage(tab, entry.url); break; }
    }
}

function downloadFile(url) {
    if (downloads.filter(item => item.request).length >= 3) {
        showMenu("downloads");
        return;
    }
    const address = new URL(url);
    let name = address.pathname.split("/").pop() || address.hostname + ".html";
    try { name = decodeURIComponent(name); } catch (_) {}
    name = name.replace(/[<>:"/\\|?*\x00-\x1f]/g, "_").replace(/^\.+/, "").slice(0, 110) || "download";
    ui.saveFile(path => {
        if (!path) return;
        if (downloads.filter(item => item.request).length >= 3
            || downloads.some(item => item.request && item.path === path)) {
            showMenu("downloads");
            return;
        }
        const temporary = fs.dir("cache") + "/netx-downloads/" + Date.now() + "-" + ++downloadSerial;
        const item = {name:path.split("/").pop() || name, path, temporary, state:"running", bytes:0, total:0};
        downloads.unshift(item);
        if (downloads.length > 25) {
            const last = downloads.findIndex((entry, index) => index >= 20 && !entry.request);
            if (last >= 0) downloads.splice(last, 1);
        }
        showMenu("downloads");
        if (fs.exists(path)) {
            item.state = "failed";
            item.error = label("Dosya zaten var. Başka bir ad seç.", "File already exists. Choose a different name.");
            return;
        }
        item.request = net.request({url, saveTo:temporary, timeout:180, redirects:true, headers:desktopHeaders}, result => {
            item.request = 0;
            if (item.state !== "cancelled") {
                const saved = result.ok && fs.rename(temporary, path);
                item.state = saved ? "done" : "failed";
                if (!saved) item.error = result.ok ? label("Dosya hedefe kaydedilemedi.", "Could not save to the selected path.")
                    : networkFailure(result);
            }
            if (fs.exists(temporary)) fs.remove(temporary, true);
        }, (received, total) => {
            item.bytes = received;
            item.total = total;
        });
        if (!item.request) item.state = "failed";
    }, name, label("Dosyayı indir", "Download file"));
}

function linkAction(id, url, x, y, w, h) {
    const hit = ui.hit(id, x, y, w, h);
    if (hit.rightClicked) {
        ui.contextMenu([
            {label:label("Yeni sekmede aç", "Open in new tab"), id:1, icon:"open_in_new"},
            {label:label("Bağlantıyı kopyala", "Copy link"), id:2, icon:"content_copy"},
            {label:label("Bağlantıyı kaydet", "Save link"), id:3, icon:"download"},
        ], action => {
            if (action === 1) addTab(url, false);
            else if (action === 2) sys.clipboard(url);
            else if (action === 3) downloadFile(url);
        });
    }
    return hit.clicked;
}

function drawDownloads(x, y, w, h) {
    if (!downloads.length) {
        ui.label(label("Bu oturumda indirme yok.", "No downloads this session."), x + 3, y + 6, 14, theme.text2);
        return;
    }
    const [offset] = ui.beginScroll("downloads-list", x, y, w, h, downloads.length * 64);
    for (let i = 0; i < downloads.length; i++) {
        const rowY = i * 64;
        if (rowY + 61 < offset || rowY > offset + h) continue;
        const item = downloads[i];
        gfx.rect(0, rowY, w - 10, 59, 6, theme.sidebar);
        ui.label(fitText(item.name, w - 84, 14), 8, rowY + 6, 14, theme.text, "bold");
        const progress = Math.min(1, item.bytes / Math.max(1, item.total));
        const size = item.bytes < 1048576 ? Math.floor(item.bytes / 1024) + " KB" : (item.bytes / 1048576).toFixed(1) + " MB";
        const status = item.state === "running" ? size + (item.total > 0 ? " · " + Math.floor(progress * 100) + "%" : "")
            : item.state === "done" ? label("Tamamlandı", "Complete") + " · " + size
            : item.state === "cancelled" ? label("İptal edildi", "Cancelled")
            : item.error || label("İndirme başarısız.", "Download failed.");
        ui.label(fitText(status, w - 91, 12), 8, rowY + 27, 12, theme.text2);
        if (item.request) {
            if (item.total > 0) gfx.rect(8, rowY + 47, (w - 86) * progress, 3, 1, theme.accent);
            if (ui.button("×##cancel-download-" + i, w - 51, rowY + 13, 31, 30, "toolbar")) {
                item.state = "cancelled";
                net.cancel(item.request);
                item.request = 0;
                if (fs.exists(item.temporary)) fs.remove(item.temporary, true);
            }
        } else if (item.state === "done" && ui.button(label("Konum", "Path") + "##download-" + i,
            w - 73, rowY + 13, 56, 30, "toolbar")) {
            sys.clipboard(item.path);
            item.error = "";
        }
    }
    ui.endScroll();
}

function toggleBookmark(tab) {
    if (!tab.url) return;
    const prefs = settings();
    const index = prefs.bookmarks.findIndex(item => item.url === tab.url);
    if (index < 0) prefs.bookmarks.unshift({url:tab.url,title:tab.title || tab.url});
    else prefs.bookmarks.splice(index, 1);
    prefs.bookmarks = prefs.bookmarks.slice(0, 50);
    store.set("browser-settings", prefs);
}

function home(tab) {
    cancel(tab);
    if (mediaTab === tab) closeMedia();
    tab.address = "";
    tab.draft = "";
    tab.url = "";
    tab.title = "";
    tab.restore = "";
    tab.catalog = false;
    tab.find = "";
    tab.findOpen = false;
    tab.suggest = false;
    tab.youtube = null;
    tab.netflix = null;
    tab.search = null;
    tab.directMedia = null;
    tab.rows = [];
    tab.status = label("Yeni sekme", "New tab");
}

function fitText(text, width, size) {
    if (width < 8) return "";
    if (gfx.textWidth(text, size) <= width) return text;
    let left = 0, right = text.length;
    while (left < right) {
        const middle = Math.ceil((left + right) / 2);
        if (gfx.textWidth(text.slice(0, middle) + "…", size) <= width) left = middle;
        else right = middle - 1;
    }
    return text.slice(0, left) + "…";
}

function chromeIcon(id, icon, x, y, w, h, enabled = true, selected = false) {
    const hit = enabled && ui.hit(id, x, y, w, h);
    if (hit && (hit.hovered || selected))
        gfx.rect(x, y, w, h, 8, hit.hovered ? chrome.hover : chrome.active);
    gfx.icon(icon, x + w / 2, y + h / 2, 18, selected ? chrome.accent : enabled ? chrome.text : "#657690");
    return hit && hit.clicked;
}

function drawBrowserMenu(tab, w, h) {
    const prefs = settings();
    const width = Math.min(392, w - 24), x = w - width - 12;
    const y = 87, bottom = h - 28;
    if (x >= 308) {
        const rail = x - 30;
        gfx.rect(17, y, rail, 139, 12, chrome.top);
        gfx.icon("tune", 42, y + 27, 20, chrome.accent);
        ui.label(label("Tarayıcı kontrolleri", "Browser controls"), 62, y + 17, 19, chrome.text, "bold");
        ui.label(label("Etkin sekme", "Active tab"), 31, y + 57, 12, chrome.muted);
        gfx.clip(30, y + 76, rail - 28, 31);
        ui.label(tab.title || label("Yeni sekme", "New tab"), 31, y + 80, 17, chrome.text, "bold");
        gfx.unclip();
        if (ui.button(label("Ana sayfaya dön", "Return to home"), 17, y + 154, 158, 32, "toolbar", "home")) {
            home(tab);
            browserMenu = "";
            return;
        }
        if (tab.url && ui.button(label("Favoriye al / kaldır", "Toggle bookmark"), 183, y + 154, 153, 32, "toolbar", "star")) {
            toggleBookmark(tab);
            browserMenu = "bookmarks";
        }
    }
    gfx.rect(x, y, width, bottom - y, 12, theme.window);
    gfx.rect(x, y, width, 46, 12, chrome.bar);
    ui.label(label("Tarayıcı menüsü", "Browser menu"), x + 14, y + 12, 19, chrome.text, "bold");
    if (chromeIcon("panel-close", "close", x + width - 37, y + 6, 30, 32)) {
        browserMenu = "";
        return;
    }
    const sections = [
        ["settings",label("Ayarlar", "Settings")],
        ["bookmarks",label("Favoriler", "Bookmarks")],
        ["history",label("Geçmiş", "History")],
        ["tabs",label("Sekmeler", "Tabs")],
        ["downloads",label("İndirilenler", "Downloads")],
        ["page",label("Sayfa", "Page")],
    ];
    const segment = (width - 24) / 3;
    for (let i = 0; i < sections.length; i++) {
        const [key, title] = sections[i];
        if (ui.button(title + "##panel-" + key, x + 12 + i % 3 * segment, y + 55 + Math.floor(i / 3) * 35, segment - 5, 30,
            browserMenu === key ? "primary" : "toolbar")) showMenu(key);
    }
    const left = x + 13, top = y + 127, inner = width - 26;
    if (browserMenu === "page") {
        const enabled = tab.rows.length > 0 && !tab.catalog;
        if (ui.button(label("Sayfada ara", "Find on page"), left, top, 158, 30, "default", "search", enabled)) {
            browserMenu = "";
            tab.findOpen = true;
            focusField = "find-" + tab.key;
        }
        if (ui.button(label("Okuma modu", "Reader mode"), left + 166, top, 158, 30,
            tab.reader ? "primary" : "default", "menu_book", enabled)) {
            tab.reader = !tab.reader;
            browserMenu = "";
        }
        if (ui.button("−##zoom-out", left, top + 36, 32, 30, "toolbar", "", enabled)) zoomPage(tab, -1);
        if (ui.button(tab.zoom + "%##zoom-reset", left + 39, top + 36, 62, 30, "toolbar", "", enabled)) zoomPage(tab, 0);
        if (ui.button("+##zoom-in", left + 108, top + 36, 32, 30, "toolbar", "", enabled)) zoomPage(tab, 1);
        if (ui.button(label("Adresi kaydet", "Save address"), left + 150, top + 36, 174, 30,
            "default", "download", !!tab.address)) downloadFile(tab.address);
        if (tab.address && ui.button(label("Sistem tarayıcısında aç", "Open in system browser"), left, top + 72, 232, 30, "toolbar", "open_in_new"))
            sys.launch("browser", tab.address);
        return;
    }
    if (browserMenu === "downloads") {
        drawDownloads(left, top, inner, Math.max(28, bottom - top - 8));
        return;
    }
    if (browserMenu === "settings") {
        ui.beginScroll("browser-settings-panel", left, top, inner, Math.max(20, bottom - top - 8), 258);
        ui.label(label("Varsayılan arama motoru", "Default search engine"), 0, 0, 15, theme.text, "bold");
        const engines = Object.keys(searchEngines);
        for (let i = 0; i < engines.length; i++) {
            const name = engines[i];
            if (ui.button(name + "##engine-" + name, i * (inner - 10) / 3, 24, (inner - 10) / 3 - 5, 32,
                prefs.engine === name ? "primary" : "toolbar")) {
                prefs.engine = name;
                store.set("browser-settings", prefs);
            }
        }
        ui.label(label("Görünüm ve dil", "Appearance and language"), 0, 66, 15, theme.text, "bold");
        if (ui.button(label("Dil · Türkçe", "Language · English"), 0, 90, 150, 29)) {
            prefs.language = prefs.language === "en" ? "tr" : "en";
            store.set("browser-settings", prefs);
        }
        if (ui.button(prefs.appearance === "ocean" ? label("Tema · Okyanus", "Theme · Ocean")
            : label("Tema · Gece", "Theme · Night"), 158, 90, 147, 29)) {
            prefs.appearance = prefs.appearance === "ocean" ? "night" : "ocean";
            store.set("browser-settings", prefs);
        }
        ui.label(label("Gizlilik ve açılış", "Privacy and startup"), 0, 130, 15, theme.text, "bold");
        const keepHistory = ui.toggle("keep-history", prefs.keepHistory, 0, 152, 46, 24);
        ui.label(label("Geçmişi kaydet", "Save browsing history"), 53, 156, 13, theme.text);
        const restoreTabs = ui.toggle("restore-tabs", prefs.restoreTabs, 0, 181, 46, 24);
        ui.label(label("Son oturumu geri yükle", "Restore the previous session"), 53, 185, 13, theme.text);
        if (keepHistory !== prefs.keepHistory || restoreTabs !== prefs.restoreTabs) {
            prefs.keepHistory = keepHistory;
            prefs.restoreTabs = restoreTabs;
            if (!restoreTabs) store.set("browser-session", {});
            store.set("browser-settings", prefs);
        }
        const resources = ui.button(label("Kaynaklar", "Resources"), 0, 218, 98, 29);
        const cubemap = ui.button("WebGL Cubemap", 104, 218, 116, 29);
        const copy = tab.url && ui.button(label("Adresi kopyala", "Copy address"), 226, 218, 116, 29);
        ui.endScroll();
        if (resources) {
            browserMenu = "";
            showCatalog(tab);
        } else if (copy) {
            sys.clipboard(tab.url);
            browserMenu = "";
        } else if (cubemap) {
            browserMenu = "";
            if (!sys.launch("browser", cubemapDemo))
                tab.status = label("Sistem tarayıcısı açılamadı.", "Could not open the system browser.");
        }
        return;
    }
    if (browserMenu === "tabs") {
        const viewport = Math.max(20, bottom - top - 8);
        ui.beginScroll("all-tabs", left, top, inner, viewport, tabs.length * 38 + 40);
        if (ui.button(label("Son kapanan sekmeyi aç", "Reopen closed tab"), 0, 0, inner - 11, 32,
            "toolbar", "restore", !!closedTabs.length && tabs.length < maxTabs)) {
            reopenTab();
            browserMenu = "";
            ui.endScroll();
            return;
        }
        let selected = -1;
        for (let i = 0; i < tabs.length; i++) {
            const title = fitText(tabs[i].title || label("Yeni sekme", "New tab"), inner - 36, 14).replace(/##/g, "# #");
            if (ui.button(title + "##choose-tab-" + tabs[i].key, 0, 40 + i * 38, inner - 11, 33,
                i === active ? "primary" : "toolbar")) selected = i;
        }
        ui.endScroll();
        if (selected >= 0) {
            browserMenu = "";
            activateTab(selected);
        }
        return;
    }
    const bookmarks = browserMenu === "bookmarks";
    const list = bookmarks ? prefs.bookmarks : prefs.recent;
    if (!list.length) ui.label(label("Henüz kayıt yok.", "Nothing here yet."), left + 4, top + 5, 14, theme.text2);
    if (!list.length) return;
    libraryQuery = ui.textfield("library-filter-" + browserMenu, libraryQuery, left, top,
        bookmarks ? inner - 8 : inner - 137, 29, label("Kayıtlarda ara", "Search entries"), "search");
    if (!bookmarks) {
        if (ui.button(label("Temizle", "Clear history"), left + inner - 129, top, 120, 29)) {
            prefs.recent = [];
            store.set("browser-settings", prefs);
            return;
        }
    }
    const listTop = top + 36;
    const viewport = Math.max(20, bottom - listTop - 8);
    const query = searchable(libraryQuery.trim());
    const shown = query ? list.filter(entry => searchable(entry.title + " " + entry.url).includes(query)) : list;
    const [offset] = ui.beginScroll("browser-list-" + browserMenu, left, listTop, inner, viewport, shown.length * 43);
    let destination = "";
    let remove;
    for (let i = 0; i < shown.length; i++) {
        const rowY = i * 43;
        if (rowY + 40 < offset || rowY > offset + viewport) continue;
        const entry = shown[i], rowWidth = inner - 45;
        const hit = ui.hit("saved-" + i, 0, rowY, rowWidth, 41);
        if (hit.hovered) gfx.rect(0, rowY, rowWidth, 41, 5, theme.sidebar);
        ui.label(fitText(entry.title, rowWidth - 16, 14), 6, rowY + 4, 14, theme.text);
        ui.label(fitText(entry.url, rowWidth - 16, 11), 6, rowY + 23, 11, theme.text2);
        if (hit.clicked) destination = entry.url;
        if (ui.button("×##remove-record-" + i, inner - 42, rowY + 5, 30, 30, "toolbar")) remove = entry;
    }
    ui.endScroll();
    if (remove) {
        list.splice(list.indexOf(remove), 1);
        store.set("browser-settings", prefs);
    }
    if (destination) { browserMenu = ""; openPage(tab, destination); }
}

function drawPlayer(tab, x, y, w, h) {
    const info = media.info(player);
    gfx.rect(x, y, w, h, 8, "#101722");
    media.draw(player, x, y, w, h - 66, "contain");
    const position = Number(info.position) || 0;
    if (info.duration > 0) {
        const selected = ui.slider("media-seek-" + tab.key, position, 0, info.duration, x + 9, y + h - 61, w - 111, 0.1);
        if (Number.isFinite(selected) && Math.abs(selected - position) >= 0.05) media.seek(player, selected);
        ui.label(mediaTime(position) + " / " + mediaTime(info.duration), x + w - 92, y + h - 58, 12, "#dde8f7");
    }
    if (chromeIcon("media-toggle", info.state === "failed" ? "refresh" : info.state === "playing" ? "pause" : "play_arrow",
        x + 7, y + h - 34, 32, 28)) {
        if (info.state === "failed") {
            closeMedia();
            if (tab.youtube) playYouTube(tab);
            else if (tab.address) openPage(tab, tab.address, tab.index);
            return;
        }
        if (info.state === "playing") media.pause(player);
        else media.play(player);
    }
    if (chromeIcon("media-mute", mediaMuted ? "volume_off" : "volume_up", x + 43, y + h - 34, 32, 28, true, mediaMuted)) {
        mediaMuted = !mediaMuted;
        media.set(player, {muted:mediaMuted});
    }
    if (chromeIcon("media-theater", mediaTheater ? "fullscreen_exit" : "fullscreen",
        x + w - 75, y + h - 34, 32, 28, true, mediaTheater)) mediaTheater = !mediaTheater;
    const rate = ui.hit("media-speed", x + w - 124, y + h - 34, 44, 28);
    if (rate.hovered) gfx.rect(x + w - 124, y + h - 34, 44, 28, 6, chrome.hover);
    ui.label(mediaRate + "×", x + w - 120, y + h - 28, 13, chrome.text);
    if (rate.clicked) {
        mediaRate = playbackRates[(playbackRates.indexOf(mediaRate) + 1) % playbackRates.length];
        media.set(player, {speed:mediaRate});
    }
    if (chromeIcon("media-close", "close", x + w - 39, y + h - 34, 32, 28)) closeMedia();
    const state = info.state === "failed" ? label("Akış oynatılamadı.", "Playback failed.")
        : info.state === "opening" || info.buffering ? label("Tamponlanıyor…", "Buffering…") : "";
    ui.label(state, x + 83, y + h - 29, 13, "#dde8f7");
}

function drawYouTube(tab, w, h) {
    const page = tab.youtube;
    gfx.rect(0, 79, w, h - 104, 0, "#101318");
    gfx.rect(0, 79, w, 53, 0, "#1b2028");
    gfx.rect(15, 96, 31, 20, 6, "#dc193b");
    gfx.icon("play_arrow", 30, 106, 18, "#ffffff");
    ui.label("YouTube", 53, 93, 21, "#f9fbff", "bold");
    const sx = 151, sw = Math.min(510, w - sx - 64), input = "yt-search-" + tab.key;
    tab.youtubeQuery = ui.textfield(input, tab.youtubeQuery, sx, 89, sw, 32,
        label("Videolarda ara", "Search videos"), "search");
    const pressed = chromeIcon("yt-submit", "search", sx + sw + 7, 89, 36, 32);
    if ((ui.submitted(input) || pressed) && tab.youtubeQuery.trim()) {
        openPage(tab, youtubeUrl({kind:"search", query:tab.youtubeQuery.trim()}));
        return;
    }
    if (page.kind !== "watch") {
        const heading = page.kind === "search" ? page.query : label("Videolar", "Videos");
        ui.label(heading.slice(0, Math.floor((w - 38) / 12)), 19, 144, 22, "#f1f6fd", "bold");
        if (!page.items.length) {
            const hint = tab.request ? label("YouTube yükleniyor…", "Loading YouTube…")
                : page.error || label("Video arayın veya adres çubuğuna bir YouTube bağlantısı yazın.",
                    "Search for videos or enter a YouTube link in the address bar.");
            gfx.color("#b9c5d7");
            gfx.wrap(hint, 19, 182, w - 38, 15);
            return;
        }
        const columns = w >= 820 ? 3 : 2, gap = 13, viewport = h - 202;
        const cardWidth = Math.floor((w - 43 - (columns - 1) * gap) / columns);
        const thumbHeight = Math.floor(cardWidth * 9 / 16), cardHeight = thumbHeight + 69;
        const [scroll] = ui.beginScroll("yt-results-" + tab.key + "-" + tab.revision, 17, 175,
            w - 34, viewport, Math.ceil(page.items.length / columns) * (cardHeight + gap));
        let chosen;
        for (let i = 0; i < page.items.length; i++) {
            const x = i % columns * (cardWidth + gap), y = Math.floor(i / columns) * (cardHeight + gap);
            if (y + cardHeight < scroll || y > scroll + viewport) continue;
            const item = page.items[i];
            const hit = ui.hit("yt-card-" + item.id, x, y, cardWidth, cardHeight);
            gfx.rect(x, y, cardWidth, cardHeight, 10, hit.hovered ? "#303d50" : "#202833");
            const image = gfx.imageUrl("https://i.ytimg.com/vi/" + item.id + "/mqdefault.jpg", 320);
            if (image) gfx.draw(image, x, y, cardWidth, thumbHeight, 10);
            else gfx.icon("play_circle", x + cardWidth / 2, y + thumbHeight / 2, 28, "#8fa7c6");
            if (item.length) {
                gfx.rect(x + cardWidth - 54, y + thumbHeight - 24, 48, 19, 4, "#111722");
                ui.label(item.length, x + cardWidth - 49, y + thumbHeight - 22, 12, "#ffffff");
            }
            gfx.clip(x + 8, y + thumbHeight + 7, cardWidth - 16, 35);
            gfx.color("#eff5ff");
            gfx.wrap(item.title, x + 8, y + thumbHeight + 7, cardWidth - 16, 14, "bold");
            gfx.unclip();
            ui.label(item.author.slice(0, 32), x + 8, y + thumbHeight + 47, 12, "#a9b7ca");
            if (hit.clicked) chosen = item.id;
        }
        ui.endScroll();
        if (chosen) openPage(tab, youtubeUrl({kind:"watch",id:chosen}));
        return;
    }
    const wide = w >= 790, side = wide ? Math.min(273, Math.floor(w * 0.29)) : 0;
    const x = 15, y = 145, width = w - 30 - side, height = h - y - 78;
    if (player && mediaTab === tab) drawPlayer(tab, x, y, width, height);
    else {
        gfx.rect(x, y, width, height, 12, "#202833");
        const thumbnail = gfx.imageUrl("https://i.ytimg.com/vi/" + page.id + "/hqdefault.jpg", 480);
        if (thumbnail) {
            const scale = Math.min(width / thumbnail.width, height / thumbnail.height);
            gfx.draw(thumbnail, x + (width - thumbnail.width * scale) / 2,
                y + (height - thumbnail.height * scale) / 2, thumbnail.width * scale, thumbnail.height * scale, 8);
        }
        if (ui.button(page.loadingStream ? label("Akış aranıyor…", "Finding stream…") : label("Oynat", "Play"),
            x + width / 2 - 76, y + height / 2 - 19, 152, 38, "primary", "play_arrow", !page.loadingStream))
            playYouTube(tab);
        if (page.error) {
            gfx.rect(x + 8, y + height - 38, width - 16, 30, 6, "#181f2a");
            ui.label(page.error.slice(0, 68), x + 15, y + height - 31, 13, "#fbc3cd");
        }
    }
    gfx.clip(x, y + height + 6, width, 29);
    ui.label(page.title, x, y + height + 8, 17, "#f0f4ff", "bold");
    gfx.unclip();
    ui.label(page.author, x, y + height + 32, 13, "#b8c3d4");
    if (!wide || !page.items.length) return;
    const right = x + width + 12, sidebarWidth = w - right - 13;
    ui.label(label("Önerilen videolar", "Recommended"), right, y, 15, "#f0f4ff", "bold");
    for (let i = 0; i < page.items.length && y + 94 + i * 65 < h - 22; i++) {
        const item = page.items[i], top = y + 27 + i * 65;
        const hit = ui.hit("yt-related-" + item.id, right, top, sidebarWidth, 59);
        if (hit.hovered) gfx.rect(right, top, sidebarWidth, 59, 7, "#263344");
        const image = gfx.imageUrl("https://i.ytimg.com/vi/" + item.id + "/mqdefault.jpg", 240);
        if (image) gfx.draw(image, right, top, 99, 56, 6);
        gfx.color("#eef4ff");
        gfx.clip(right + 105, top, sidebarWidth - 108, 55);
        gfx.wrap(item.title, right + 105, top + 2, sidebarWidth - 108, 13);
        gfx.unclip();
        if (hit.clicked) {
            openPage(tab, youtubeUrl({kind:"watch",id:item.id}));
            break;
        }
    }
}

function drawNetflix(tab, w, h) {
    const title = tab.netflix;
    gfx.rect(0, 79, w, h - 104, 0, "#141414");
    ui.label("Netflix", 22, 91, 25, "#e50914", "bold");
    const wide = w >= 750;
    const heroX = wide ? Math.floor(w * 0.53) : 22;
    const heroWidth = w - heroX - 22;
    const previewsTop = Math.min(349, Math.max(218, h * 0.61));
    const heroHeight = Math.min(previewsTop - 126, heroWidth * 9 / 16);
    const picture = wide && title.poster && gfx.imageUrl(title.poster, 768);
    if (picture) {
        const scale = Math.min(heroWidth / picture.width, heroHeight / picture.height);
        gfx.draw(picture, heroX, 122, picture.width * scale, picture.height * scale, 8);
    }
    const textWidth = wide ? heroX - 44 : w - 44;
    const heading = fitText(title.title, textWidth, 28);
    ui.label(heading, 22, 129, 28, "#ffffff", "bold");
    if (title.summary) ui.label(fitText(title.summary, textWidth, 13), 22, 167, 13, "#b9b9b9");
    gfx.color("#ffffff");
    const descriptionTop = title.summary ? 192 : 169;
    gfx.clip(22, descriptionTop, textWidth, Math.max(0, previewsTop - descriptionTop - 8));
    gfx.wrap(title.description, 22, descriptionTop, textWidth, 15);
    gfx.unclip();
    const previews = title.previews || [];
    ui.label(label("Herkese açık fragmanlar", "Public trailers"), 22, previewsTop, 16, "#f4f4f4", "bold");
    if (!previews.length) {
        if (ui.button(label("Örnek başlığı aç", "Open sample title"), 22, previewsTop + 25, 175, 32))
            openPage(tab, netflixExample);
    } else {
        const viewport = Math.max(39, h - previewsTop - 72);
        ui.beginScroll("netflix-previews-" + tab.key + "-" + tab.revision, 22, previewsTop + 25,
            w - 44, viewport, previews.length * 43);
        let selected;
        for (let i = 0; i < previews.length; i++) {
            const item = previews[i];
            const duration = item.seconds > 0 ? " · " + mediaTime(item.seconds) : "";
            const name = fitText(item.title, w - 150, 14).replace(/##/g, "# #");
            if (ui.button(name + duration + "##netflix-trailer-" + i, 0, i * 43, w - 55, 36,
                i === 0 ? "primary" : "default", "play_arrow")) selected = item;
        }
        ui.endScroll();
        if (selected) playMedia(tab, selected.url, false);
    }
    ui.label(label("Film ve bölümler korumalı oynatıcı gerektirir.", "Films and episodes require protected playback."),
        22, h - 45, 12, "#b9b9b9");
}

function mediaTime(value) {
    const seconds = Math.floor(Math.max(0, value || 0));
    return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
}

function drawSearch(tab, w, h) {
    const panel = Math.min(w - 36, 820), left = (w - panel) / 2;
    const {query, items} = tab.search;
    gfx.rect(left, 90, panel, 65, 10, theme.sidebar);
    ui.label("DuckDuckGo", left + 14, 99, 12, theme.text2, "bold");
    gfx.clip(left + 14, 114, panel - 28, 34);
    ui.label(query, left + 14, 117, 22, theme.text, "bold");
    gfx.unclip();
    const viewport = h - 190;
    const [scroll] = ui.beginScroll("web-results-" + tab.key + "-" + tab.revision,
        left, 161, panel, viewport, items.length * 59);
    let target;
    for (let i = 0; i < items.length; i++) {
        const y = i * 59;
        if (y + 54 < scroll || y > scroll + viewport) continue;
        const item = items[i];
        gfx.rect(0, y, panel - 12, 53, 7, theme.window);
        gfx.icon("language", 20, y + 23, 16, theme.accent);
        gfx.clip(35, y + 3, panel - 56, 48);
        ui.label(item.title, 37, y + 6, 15, theme.accent, "bold");
        ui.label(new URL(item.href).hostname, 37, y + 30, 12, theme.text2);
        gfx.unclip();
        if (linkAction("web-hit-" + i, item.href, 0, y, panel - 12, 53)) target = item.href;
    }
    ui.endScroll();
    if (target) openPage(tab, target);
}

function drawHome(tab, w, h) {
    const width = Math.min(850, w - 36), x = (w - width) / 2;
    const height = h - 108;
    ui.beginScroll("home-" + tab.key, x, 84, width, height, 391);
    gfx.gradient(0, 8, width - 10, 153, "#182948", "#20456b", true, 18);
    gfx.circle(width - 82, 56, 33, "#28567c");
    gfx.color("#6b9bc1");
    gfx.circleLine(width - 82, 56, 29, 1.5);
    gfx.icon("public", width - 82, 56, 37, chrome.accent);
    ui.label("NETX / MINI", 22, 23, 12, chrome.accent, "bold");
    ui.label(label("Web’e açıl", "Open the web"), 22, 43, w >= 620 ? 31 : 26, chrome.text, "bold");
    ui.label(label("Yeni sekme", "New tab"), 22, 81, 13, "#b6cbe7");
    const searchWidth = width - 122;
    const search = ui.hit("home-search", 18, 105, searchWidth, 43);
    gfx.rect(18, 105, searchWidth, 43, 12, search.hovered ? "#2c547b" : "#13273f");
    gfx.icon("search", 40, 126, 18, chrome.accent);
    ui.label(label("Web’de ara veya adres yaz", "Search or enter an address"), 57, 119, 14, chrome.text);
    ui.label(settings().engine, width - 92, 121, 12, "#c0d7ec");
    ui.label(label("Hızlı erişim", "Quick access"), 2, 174, 17, theme.text, "bold");
    const shortcuts = [
        ["YouTube","play_arrow","#97344c",youtubeHome],
        ["Netflix","movie","#99414c",netflixExample],
        ["Wikipedia","menu_book","#2a577c","https://en.wikipedia.org/wiki/Nintendo_Switch"],
        [label("Teknoloji", "Technology"),"bolt","#78542b","https://news.ycombinator.com/"],
        ["GitHub","code","#443c76","https://github.com/explore"],
        [label("Kaynaklar", "Resources"),"bookmarks","#30646d",""],
    ];
    const columns = w >= 705 ? 6 : 3, gap = 9;
    const cardWidth = Math.floor((width - 11 - (columns - 1) * gap) / columns);
    let target = null;
    for (let i = 0; i < shortcuts.length; i++) {
        const [name, icon, color, url] = shortcuts[i];
        const cardX = i % columns * (cardWidth + gap);
        const cardY = 201 + Math.floor(i / columns) * 71;
        const hit = ui.hit("shortcut-" + i, cardX, cardY, cardWidth, 64);
        gfx.rect(cardX, cardY, cardWidth, 64, 9, hit.hovered ? theme.field : theme.sidebar);
        gfx.rect(cardX + 8, cardY + 8, 26, 26, 7, color);
        gfx.icon(icon, cardX + 21, cardY + 21, 16, "#ffffff");
        ui.label(name, cardX + 8, cardY + 41, 13, theme.text, "medium");
        if (hit.clicked) target = url;
    }
    const recent = settings().recent;
    const recentY = 201 + Math.ceil(shortcuts.length / columns) * 71 + 6;
    ui.label(label("Son ziyaretler", "Recent visits"), 2, recentY, 16, theme.text, "bold");
    if (!recent.length) ui.label(label("Ziyaret ettiğin sayfalar burada görünür.", "Pages you visit appear here."),
        2, recentY + 26, 13, theme.text2);
    for (let i = 0; i < Math.min(3, recent.length) && recentY + 57 + i * 33 < 400; i++) {
        if (ui.button(recent[i].title.replace(/##/g, "# #").slice(0, 49) + "##recent-home-" + i,
            0, recentY + 23 + i * 33, width - 15, 29, "toolbar", "history"))
            target = recent[i].url;
    }
    ui.endScroll();
    if (search.clicked) ui.focus("address-" + tab.key);
    if (target === "") showCatalog(tab);
    else if (target) openPage(tab, target);
}

app.draw = function(w, h) {
    gfx.clear(theme.bg);
    chrome = settings().appearance === "ocean" ? oceanChrome : nightChrome;
    if (player && mediaTheater) {
        drawPlayer(mediaTab, 0, 0, w, h);
        return;
    }
    gfx.rect(0, 0, w, 37, 0, chrome.top);
    gfx.rect(0, 37, w, 42, 0, chrome.bar);
    gfx.rect(0, h - 24, w, 24, 0, theme.sidebar);
    const capacity = Math.max(1, Math.floor((w - 77) / 119));
    const visible = Math.min(tabs.length, capacity);
    const first = Math.min(Math.max(0, active - Math.floor(visible / 2)), tabs.length - visible);
    const tabWidth = Math.min(188, Math.floor((w - 77) / visible));
    for (let i = first; i < first + visible; i++) {
            const entry = tabs[i], x = 6 + (i - first) * tabWidth;
            const hasClose = tabs.length > 1, titleWidth = tabWidth - (hasClose ? 42 : 19);
            const hit = !browserMenu && ui.hit("tab-" + entry.key, x, 5, tabWidth - (hasClose ? 29 : 4), 29);
            if (i === active || (hit && hit.hovered))
                gfx.rect(x, 5, tabWidth - 4, 30, 8, i === active ? chrome.active : chrome.hover);
            if (i === active) gfx.rect(x + 8, 33, tabWidth - 20, 2, 1, chrome.accent);
            gfx.icon(entry.youtube ? "play_circle" : entry.url ? "language" : "public",
                x + 14, 19, 15, i === active ? chrome.accent : chrome.muted);
            ui.label(fitText(entry.title || label("Yeni sekme", "New tab"), titleWidth - 11, 13),
                x + 26, 12, 13, chrome.text);
            if (hit && hit.clicked) activateTab(i);
            if (hasClose && chromeIcon("close-tab-" + entry.key, "close", x + tabWidth - 29, 6, 24, 26, !browserMenu)) {
                closeTab(i);
                break;
            }
    }
    if (chromeIcon("add-tab", "add", 7 + visible * tabWidth, 4, 29, 30, !browserMenu && tabs.length < maxTabs))
        addTab();
    if (chromeIcon("tab-list", "expand_more", w - 39, 4, 32, 30, true, browserMenu === "tabs"))
        showMenu(browserMenu === "tabs" ? "" : "tabs");
    const tab = tabs[active];
    const menuX = w - 39, starX = w - 76, goX = w - 113, inputX = 140;
    if (chromeIcon("menu", "more_vert", menuX, 42, 32, 31, true, !!browserMenu))
        showMenu(browserMenu ? "" : "settings");
    if (browserMenu) {
        ui.label(tab.address.slice(0, 49), inputX + 9, 50, 13, chrome.muted);
        drawBrowserMenu(tab, w, h);
        return;
    }
    if (chromeIcon("back", "arrow_back", 5, 42, 31, 31, tab.index > 0))
        openPage(tab, tab.history[tab.index - 1], tab.index - 1);
    if (chromeIcon("forward", "arrow_forward", 37, 42, 31, 31, tab.index + 1 < tab.history.length))
        openPage(tab, tab.history[tab.index + 1], tab.index + 1);
    const loading = tab.request || tab.parser || tab.styles.length;
    if (chromeIcon("refresh", loading ? "close" : "refresh", 69, 42, 31, 31, !!(tab.address || loading))) {
        if (loading) { cancel(tab); tab.status = label("Durduruldu.", "Stopped."); }
        else openPage(tab, tab.address, tab.index >= 0 && tab.url === tab.address ? tab.index : undefined);
    }
    if (chromeIcon("home", "home", 101, 42, 31, 31)) home(tab);
    const inputId = "address-" + tab.key;
    if (focusField === inputId) {
        ui.focus(inputId);
        focusField = "";
    }
    const lastDraft = tab.draft;
    tab.draft = ui.textfield(inputId, tab.draft, inputX, 42, goX - inputX - 5, 31,
        label("Ara veya adres yaz", "Search or enter address"), "search");
    if (tab.draft !== lastDraft) tab.suggest = true;
    const go = chromeIcon("go", "arrow_forward", goX, 42, 31, 31, !!tab.draft.trim());
    if ((ui.submitted(inputId) || go) && tab.draft.trim()) {
        openPage(tab, tab.draft);
    }
    const saved = !!tab.url && settings().bookmarks.some(item => item.url === tab.url);
    if (chromeIcon("bookmark", saved ? "star" : "star_border", starX, 42, 31, 31, !!tab.url, saved)) toggleBookmark(tab);
    if (loading) gfx.rect(0, 77, Math.min(w, 47 + (performance.now() / 8) % Math.max(1,w - 47)), 2, 0, chrome.accent);
    gfx.clip(9, h - 24, w - 18, 24);
    ui.label((tab.status || label("Hazır", "Ready")).slice(0, 125), 10, h - 20, 12, theme.text2);
    gfx.unclip();
    const suggestions = visitSuggestions(tab);
    if (suggestions.length) {
        drawSuggestions(tab, suggestions, inputX, Math.min(w - inputX - 10, 610));
        return;
    }
    if (tab.youtube && !tab.catalog) { drawYouTube(tab, w, h); return; }
    if (player && mediaTab === tab) { drawPlayer(tab, 8, 85, w - 16, h - 117); return; }
    if (tab.directMedia) {
        if (ui.button(label("Medyayı oynat", "Play media"), 20, 97, 155, 34, "primary", "play_arrow"))
            playMedia(tab, tab.directMedia.url, tab.directMedia.audio);
        return;
    }
    if (tab.netflix && !tab.catalog) { drawNetflix(tab, w, h); return; }
    if (tab.search && tab.search.items.length && !tab.catalog) { drawSearch(tab, w, h); return; }
    if (!tab.address && !tab.rows.length && !tab.catalog) { drawHome(tab, w, h); return; }
    if (tab.findOpen) {
        const findId = "find-" + tab.key;
        if (focusField === findId) { ui.focus(findId); focusField = ""; }
        tab.find = ui.textfield(findId, tab.find, 17, 85, w - 204, 29,
            label("Sayfada ara", "Find on page"), "search");
        if (ui.button(label("Kapat", "Close") + "##find-close", w - 71, 85, 54, 29, "toolbar")) {
            tab.findOpen = false;
            tab.find = "";
        }
    }
    const rows = visibleRows(tab);
    if (tab.findOpen && tab.find.trim()) ui.label(rows.length + label(" eşleşen satır", " matching rows"), w - 178, 93, 13, theme.text2);
    const wide = w >= 780 && !tab.catalog && !tab.reader && !tab.find.trim() && rows.length > 0;
    const contentsWidth = wide && tab.sections && tab.sections.length ? 148 : 0;
    const infoWidth = wide && tab.info && tab.info.length ? Math.min(280, Math.floor(w * 0.28)) : 0;
    const panelWidth = Math.min(tab.reader ? 780 : 1280, w - 28);
    const wiki = wide && /\.wikipedia\.org\//.test(tab.url);
    const panelX = Math.floor((w - panelWidth) / 2);
    const width = panelWidth - 44 - contentsWidth - infoWidth;
    measure(tab, rows, width);
    const panelTop = tab.findOpen ? 121 : 85;
    const top = wiki ? panelTop + 40 : panelTop;
    const viewport = h - top - 29;
    gfx.rect(panelX, panelTop, panelWidth, h - panelTop - 29, 6, theme.window);
    if (wiki) {
        ui.label("Wikipedia", panelX + 15, panelTop + 7, 24, theme.text, "bold");
        ui.label(label("Özgür ansiklopedi", "The free encyclopedia"), panelX + 145, panelTop + 16, 13, theme.text2);
        gfx.rect(panelX + 12, panelTop + 34, panelWidth - 24, 1, 0, theme.separator);
    }
    if (contentsWidth) {
        ui.label("İçindekiler", panelX + 15, top + 12, 15, theme.text, "bold");
        for (let i = 0; i < Math.min(tab.sections.length, Math.floor((viewport - 40) / 22)); i++)
            ui.label(tab.sections[i].text.slice(0, 21), panelX + 15, top + 40 + i * 22, 13, theme.accent);
    }
    if (infoWidth) drawInfoBox(tab.info, panelX + panelWidth - infoWidth - 9, top + 48, infoWidth, viewport - 54);
    if (!rows.length) {
        const status = tab.find.trim() ? label("Bu sayfada eşleşme yok.", "No matches on this page.") : tab.status;
        ui.label(fitText(status, panelWidth - 48, 16), panelX + 24, top + 25, 16, theme.text2);
        return;
    }
    const [scroll] = ui.beginScroll("page-" + tab.key + "-" + tab.revision + (tab.find.trim() ? "-find" : ""), panelX + 13 + contentsWidth, top + 6,
        panelWidth - 26 - contentsWidth - infoWidth, viewport - 12, contentHeight + 8);
    let destination = "";
    for (let i = 0; i < layout.length; i++) {
        const box = layout[i];
        if (box.y > scroll + viewport) break;
        if (box.y + box.height < scroll) continue;
        const row = rows[i];
        if (row.entry) {
            if (ui.button(row.text + "##ref" + i, 8, box.y, width, box.height, "toolbar")) destination = row.entry.url;
        } else if (row.stream) {
            if (ui.button(row.text + "##media" + i, 8, box.y, 135, 29)) playMedia(tab, row.stream, row.audio);
        } else if (row.image) {
            const image = gfx.imageUrl(row.image, 512);
            if (image) {
                const scale = Math.min(width / image.width, box.height / image.height, 1);
                gfx.draw(image, 8, box.y, image.width * scale, image.height * scale);
            } else ui.label(row.text.slice(0, 90), 8, box.y, 14);
            if (row.link && linkAction("imageLink" + i, row.link, 8, box.y, width, box.height)) destination = row.link;
        } else {
            const color = tab.reader ? "" : row.css.color || "";
            const background = tab.reader ? "" : row.css["background-color"] || "";
            if (/^#[0-9a-f]{6}$/i.test(background))
                gfx.rect(8, box.y, box.innerWidth + box.padding * 2, box.height, 0, background);
            const textColor = /^#[0-9a-f]{6}$/i.test(color) ? color : theme.text;
            if (box.rich) {
                for (let j = 0; j < box.rich.lines.length; j++) {
                    const line = box.rich.lines[j];
                    const y = box.y + box.padding + j * box.rich.lineHeight;
                    if (y + box.rich.lineHeight < scroll || y > scroll + viewport) continue;
                    for (let k = 0; k < line.fragments.length; k++) {
                        const part = line.fragments[k];
                        const x = 8 + box.padding + line.offset + part.x;
                        gfx.color(part.link ? theme.accent : textColor);
                        gfx.text(part.text, x, y, box.size, box.font);
                        if (part.link && linkAction("inline" + i + ":" + j + ":" + k, part.link, x, y,
                            Math.min(part.w, box.innerWidth), box.rich.lineHeight)) destination = part.link;
                    }
                }
                continue;
            }
            gfx.color(textColor);
            const align = /^(left|right|center)$/.test(row.css["text-align"]) ? row.css["text-align"] : "left";
            gfx.wrap(row.text, 8 + box.padding, box.y + box.padding, box.innerWidth, box.size, box.font, align);
            if (row.link && linkAction("link" + i, row.link, 8, box.y, width, box.height)) destination = row.link;
        }
    }
    ui.endScroll();
    if (destination) openPage(tab, destination);
};
