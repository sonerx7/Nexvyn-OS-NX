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

function tubeLink(url) {
    const address = new URL(url);
    const path = address.pathname;
    const video = /^[A-Za-z0-9_-]{11}$/;
    if (address.hostname === "youtu.be" && video.test(path.slice(1)))
        return "https://www.youtube.com/watch?v=" + path.slice(1);
    if (!["youtube.com", "www.youtube.com", "m.youtube.com"].includes(address.hostname))
        return null;
    if (path === "/") return "";
    if (path === "/results") {
        const query = (address.searchParams.get("search_query") || "").trim();
        return query ? "tube:search:" + query.slice(0, 200) : "";
    }
    if (path === "/watch" && video.test(address.searchParams.get("v") || "")) return url;
    if (/^\/(?:shorts|live)\/[A-Za-z0-9_-]{11}\/?$/.test(path))
        return "https://www.youtube.com/watch?v=" + path.split("/")[2];
    return null;
}

function openTube(tab, arg) {
    if (sys.launch("tube", arg)) return true;
    tab.status = label("YousTube açılamadı. Kurulumu ve başlatma iznini kontrol et.",
        "Could not open YousTube. Check its installation and launch permission.");
    return false;
}

function showCatalog(tab) {
    if (!references) {
        const index = fs.read("bundle:/reference/index.json");
        references = index ? JSON.parse(index) : [];
    }
    cancel(tab);
    if (mediaTab === tab) closeMedia();
    tab.catalog = true;
    tab.info = [];
    tab.sections = [];
    tab.rows = references.map(entry => ({text:entry.name, entry, css:{}}));
    tab.status = references.length + label(" web standardı bağlantısı", " web standards links");
}

function newTab() {
    return {address: "", url: "", rows: [], history: [], index: -1, request: 0,
        styles: [], revision: 0, title: "", reason: "",
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

function watchPage(url, info) {
    const address = new URL(url);
    if (!["www.youtube.com", "m.youtube.com", "youtube.com"].includes(address.hostname)
        || address.pathname !== "/watch") return null;
    const id = address.searchParams.get("v") || "";
    if (!/^[A-Za-z0-9_-]{11}$/.test(id)) return null;
    return {id, title:info.title.replace(/\s+-\s+YouTube$/, "") || "YouTube",
        thumb:"https://i.ytimg.com/vi/" + id + "/hqdefault.jpg"};
}

function netflixAsset(value, page) {
    if (!value) return "";
    const url = resolve(value, page);
    if (!url) return "";
    const address = new URL(url);
    return address.protocol === "https:" && !address.port
        && /\.(?:nflxso\.net|nflximg\.net|nflximg\.com|netflix\.com)$/i.test(address.hostname) ? url : "";
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
    const video = netflixAsset(metadata["og:video:secure_url"] || metadata["og:video"], url);
    return {
        title: title.slice(0, 160),
        description: (metadata["og:description"] || info.description).slice(0, 480),
        poster: netflixAsset(metadata["og:image"], url),
        trailer: video && /\.nflxso\.net$/i.test(new URL(video).hostname)
            && /^\/so\/.+\.mp4$/i.test(new URL(video).pathname) ? video : "",
    };
}

function watchRecommendations(body, current) {
    const items = [], seen = new Set([current]);
    const pattern = /"compactVideoRenderer"\s*:\s*\{\s*"videoId"\s*:\s*"([A-Za-z0-9_-]{11})"/g;
    for (const match of body.matchAll(pattern)) {
        const id = match[1];
        if (seen.has(id)) continue;
        const part = body.slice(match.index, match.index + 2400);
        const title = /"title"\s*:\s*\{\s*(?:"simpleText"\s*:\s*|"runs"\s*:\s*\[\s*\{\s*"text"\s*:\s*)("(?:[^"\\]|\\.)*")/.exec(part);
        if (!title) continue;
        let label;
        try { label = JSON.parse(title[1]); } catch (_) { continue; }
        seen.add(id);
        items.push({id,label});
        if (items.length === 5) break;
    }
    return items;
}

function loadWatchMetadata(tab, revision) {
    const watch = tab.watch;
    const url = "https://www.youtube.com/oembed?format=json&url="
        + encodeURIComponent("https://www.youtube.com/watch?v=" + watch.id);
    let id;
    id = net.request({url,timeout:8,maxBytes:16384,responseType:"json"}, result => {
        if (tab.revision !== revision || tab.watch !== watch) return;
        tab.styles = tab.styles.filter(request => request !== id);
        if (!result.ok || !result.data) return;
        if (typeof result.data.title === "string") tab.title = watch.title = result.data.title.slice(0, 180);
        if (typeof result.data.author_name === "string") watch.author = result.data.author_name.slice(0, 90);
    });
    if (id) tab.styles.push(id);
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
    const candidate = /^https?:\/\//i.test(input) ? input
        : /^[\w.-]+\.[\w-]+(?:[/:?#][^\s]*)?$/.test(input) ? "https://" + input
        : "https://www.google.com/search?q=" + encodeURIComponent(input);
    const url = resolve(candidate);
    if (!url) { tab.status = "Adres geçersiz."; return; }
    const tube = tubeLink(url);
    if (tube !== null) { openTube(tab, tube); return; }
    cancel(tab);
    tab.catalog = false;
    tab.watch = null;
    tab.netflix = null;
    tab.info = [];
    tab.sections = [];
    if (mediaTab === tab) closeMedia();
    if (/\.(mp4|webm|mkv|m3u8|mp3|aac|ogg)$/i.test(new URL(url).pathname)) {
        tab.address = url;
        playMedia(tab, url, /\.(mp3|aac|ogg)$/i.test(new URL(url).pathname));
        return;
    }
    const revision = tab.revision;
    tab.address = url;
    tab.status = "Yükleniyor…";
    tab.reason = "";
    const netflix = ["netflix.com", "www.netflix.com"].includes(new URL(url).hostname);
    tab.request = net.request({url, timeout:22, maxBytes:6291456, retry:1, cache:false,
        headers:Object.assign({Accept:"text/html, application/xhtml+xml, text/plain;q=0.9"},desktopHeaders)}, result => {
        if (tab.revision !== revision) return;
        tab.request = 0;
        if (!result.ok) {
            tab.reason = String(result.error || "").slice(0, 180);
            tab.status = networkFailure(result);
            return;
        }
        const type = String(result.contentType || (result.headers || {})["content-type"] || "").toLowerCase();
        if (!/^(text\/html|text\/plain|application\/xhtml\+xml)\b/.test(type)) {
            tab.status = "Bu içerik türü desteklenmiyor.";
            return;
        }
        tab.url = resolve(result.url || url) || url;
        tab.address = tab.url;
        const body = result.body || "";
        tab.title = "";
        tab.stale = Boolean(result.stale);
        if (type.startsWith("text/plain")) {
            tab.rows = body.split(/\r?\n/, 600).map(text => ({text:text.slice(0, 4096),css:{}}));
        } else {
            const info = describeDocument(body);
            tab.title = info.title;
            tab.docInfo = info;
            tab.watch = watchPage(tab.url, info);
            tab.netflix = netflixTitle(body, tab.url, info) || (netflix ? {
                title: info.title || "Netflix", description: info.description,
            } : null);
            if (tab.watch) {
                tab.rows = [];
                tab.watch.related = watchRecommendations(body, tab.watch.id);
                tab.parser = parseSteps(body, tab.url, []);
                loadWatchMetadata(tab, revision);
            } else if (tab.netflix) {
                tab.rows = [];
                tab.title = tab.netflix.title;
            } else loadStyles(tab, body, revision);
        }
        if (historyIndex === undefined) {
            tab.history = tab.history.slice(0, tab.index + 1).concat(tab.url).slice(-50);
            tab.index = tab.history.length - 1;
        } else {
            tab.index = historyIndex;
            tab.history[historyIndex] = tab.url;
        }
        tab.status = tab.parser ? "Belge işleniyor…" : tab.stale ? "Önbellekteki kopya" : tab.netflix || tab.rows.length ? tab.url : "Gösterilebilir içerik bulunamadı.";
    });
}

let player;
let mediaTab;

function closeMedia() {
    if (player) media.close(player);
    player = undefined;
    mediaTab = undefined;
}

function playMedia(tab, url, audio) {
    closeMedia();
    player = media.open(url, {autoplay:true, audioOnly:audio});
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

function measure(tab, width) {
    if (measuredTab !== tab || measuredWidth !== width || measuredDocument !== tab.rows) {
        measuredTab = tab;
        measuredWidth = width;
        measuredDocument = tab.rows;
        contentHeight = 8;
        layout = [];
    }
    const end = Math.min(tab.rows.length, layout.length + 16);
    const deadline = performance.now() + 3;
    for (let i = layout.length; i < end; i++) {
        const row = tab.rows[i];
        const css = row.css || {};
        const size = Math.max(12, Math.min(40, Number((css["font-size"] || "").replace(/px$/, "")) || 17));
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
    tabs.push(newTab());
    if (arg) openPage(tabs[0], arg);
};
app.open = function(arg) { if (arg) openPage(tabs[active], arg); };
app.close = function() { for (const tab of tabs) cancel(tab); closeMedia(); return true; };
app.suspend = function() { if (player) media.pause(player); };

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

let keyboardOpen = false;
let browserMenu = false;
let browserSettings;

function settings() {
    if (!browserSettings)
        browserSettings = store.get("browser-settings", {language:sys.lang() === "tr" ? "tr" : "en", bookmarks:[]});
    return browserSettings;
}

function label(tr, en) {
    return settings().language === "en" ? en : tr;
}

function drawBrowserMenu(tab, w, h) {
    const prefs = settings();
    const x = 18, width = w - 36;
    gfx.rect(x, 18, width, h - 36, 8, theme.sidebar);
    ui.label(label("Tarayıcı ayarları", "Browser settings"), x + 14, 29, 20, theme.text, "bold");
    if (ui.button(label("Kapat", "Close"), w - 104, 24, 70, 31)) browserMenu = false;
    if (ui.button(label("Dil · Türkçe", "Language · English"), x + 14, 63, 155, 32)) {
        prefs.language = prefs.language === "en" ? "tr" : "en";
        store.set("browser-settings", prefs);
    }
    if (ui.button(label("Kaynaklar", "Resources"), x + 178, 63, 108, 32)) {
        browserMenu = false;
        showCatalog(tab);
    }
    if (tab.url && ui.button(label("Sistem motoru", "System engine"), x + 294, 63, 112, 32)) {
        if (sys.launch("browser", tab.url)) browserMenu = false;
        else tab.status = label("Sistem tarayıcısı açılamadı.", "Could not open the system browser.");
    }
    ui.label(label("Favoriler", "Bookmarks"), x + 14, 108, 17, theme.text, "bold");
    const index = prefs.bookmarks.findIndex(item => item.url === tab.url);
    if (tab.url && ui.button(index < 0 ? label("Sayfayı ekle", "Add page") : label("Sayfayı kaldır", "Remove page"),
        w - 151, 102, 117, 32)) {
        if (index < 0) prefs.bookmarks.unshift({url:tab.url,title:tab.title || tab.url});
        else prefs.bookmarks.splice(index, 1);
        prefs.bookmarks = prefs.bookmarks.slice(0, 50);
        store.set("browser-settings", prefs);
    }
    const viewport = Math.max(36, h - 161);
    const [offset] = ui.beginScroll("bookmark-list", x + 10, 139, width - 20, viewport, prefs.bookmarks.length * 37 + 8);
    let destination;
    for (let i = 0; i < prefs.bookmarks.length; i++) {
        const y = i * 37;
        if (y + 33 < offset || y > offset + viewport) continue;
        const entry = prefs.bookmarks[i];
        if (ui.button(entry.title.replace(/##/g, "# #").slice(0, 56) + "##saved" + i, 4, y, width - 43, 32))
            destination = entry.url;
    }
    ui.endScroll();
    if (destination) { browserMenu = false; openPage(tab, destination); }
}

function editNavigation(tab, initial, guide, onSubmit) {
    if (keyboardOpen) return;
    keyboardOpen = true;
    const revision = tab.revision;
    ui.prompt(guide, "", initial, value => {
        keyboardOpen = false;
        if (typeof value !== "string" || !value.trim()) return;
        if (tab.revision === revision && tabs.includes(tab)) onSubmit(value.trim());
    });
}

function drawWatch(tab, w, h) {
    const wide = w >= 780;
    const side = wide ? Math.min(268, Math.floor(w * 0.30)) : 0;
    const width = Math.min(w - 36 - side, (h - 216) * 16 / 9);
    const x = wide ? 16 : (w - width) / 2, y = 125, height = width * 9 / 16;
    gfx.rect(0, 79, w, h - 104, 0, "#121212");
    gfx.rect(16, 93, 26, 17, 4, "#ff0033");
    ui.label("YouTube", 48, 88, 22, "#ffffff", "bold");
    const searchX = Math.max(142, Math.floor(w * 0.28));
    const searchWidth = Math.max(100, Math.min(410, w - searchX - 82));
    if (ui.button("YouTube’da ara##yt-search", searchX, 87, searchWidth + 54, 30)) {
        editNavigation(tab, "", "YouTube’da ara", query => openTube(tab, "tube:search:" + query.slice(0, 200)));
    }
    gfx.rect(x, y, width, height, 8, "#171717");
    const thumbnail = gfx.imageUrl(tab.watch.thumb, 640);
    if (thumbnail) gfx.draw(thumbnail, x, y, width, height, 8);
    gfx.color("#ffffff");
    gfx.wrap(tab.watch.title, x, y + height + 10, width, 19, "bold");
    if (tab.watch.author) ui.label(tab.watch.author, x, y + height + 39, 13, "#c8c8c8");
    if (tab.watch.stream) {
        if (ui.button("Oynat", x + width / 2 - 52, y + height / 2 - 18, 104, 36, "primary"))
            playMedia(tab, tab.watch.stream, false);
    } else {
        if (ui.button("YousTube’da oynat", x + width / 2 - 82, y + height / 2 - 18, 164, 36, "primary")) {
            const url = "https://www.youtube.com/watch?v=" + tab.watch.id;
            if (!sys.launch("tube", url))
                tab.watch.message = "YousTube kurulumu ve uygulama başlatma iznini kontrol et.";
        }
        if (tab.watch.message) ui.label(tab.watch.message, x, h - 45, 13, "#c8c8c8");
    }
    if (!wide) return;
    const right = x + width + 16;
    ui.label("Önerilen videolar", right, y + 2, 15, "#ffffff", "bold");
    const related = tab.watch.related || [];
    if (!related.length) ui.label("Sayfa öneri verisi sunmadı.", right, y + 32, 13, "#c8c8c8");
    for (let i = 0; i < related.length && y + 102 + i * 70 < h - 25; i++) {
        const item = related[i], top = y + 30 + i * 70;
        const preview = gfx.imageUrl("https://i.ytimg.com/vi/" + item.id + "/mqdefault.jpg", 240);
        if (preview) gfx.draw(preview, right, top, 104, 58, 6);
        gfx.color("#ffffff");
        gfx.wrap(item.label.slice(0, 90), right + 111, top, Math.max(80, w - right - 125), 13);
        if (ui.hit("yt-related" + i, right, top, w - right - 12, 62).clicked) {
            openPage(tab, "https://www.youtube.com/watch?v=" + item.id);
            break;
        }
    }
}

function drawNetflix(tab, w, h) {
    const title = tab.netflix;
    gfx.rect(0, 79, w, h - 104, 0, "#141414");
    ui.label("NETFLIX", 22, 91, 25, "#e50914", "bold");
    const heroX = w >= 750 ? Math.floor(w * 0.48) : 22;
    const heroWidth = w - heroX - 22;
    const heroHeight = Math.min(h - 178, heroWidth * 9 / 16);
    const picture = title.poster && gfx.imageUrl(title.poster, 768);
    if (picture && w >= 750) {
        const scale = Math.min(heroWidth / picture.width, heroHeight / picture.height);
        gfx.draw(picture, heroX, 130, picture.width * scale, picture.height * scale, 8);
    }
    const textWidth = w >= 750 ? heroX - 44 : w - 44;
    gfx.color("#ffffff");
    const headingHeight = gfx.wrap(title.title, 22, 145, textWidth, 30, "bold");
    gfx.color("#dedede");
    gfx.clip(22, 157 + headingHeight, textWidth, Math.max(0, h - 254 - headingHeight));
    gfx.wrap(title.description, 22, 157 + headingHeight, textWidth, 16);
    gfx.unclip();
    if (title.trailer && ui.button(label("Fragmanı oynat", "Play trailer"), 22, h - 95, 156, 34, "primary"))
        playMedia(tab, title.trailer, false);
    if (!title.trailer && ui.button(label("Örnek başlığı aç", "Open sample title"), 22, h - 95, 156, 34))
        openPage(tab, netflixExample);
    ui.label(label("Bölümler korumalı oynatıcı gerektirir.", "Episodes require a protected player."),
        22, h - 51, 13, "#b9b9b9");
}

function mediaTime(value) {
    const seconds = Math.floor(Math.max(0, value || 0));
    return Math.floor(seconds / 60) + ":" + String(seconds % 60).padStart(2, "0");
}

app.draw = function(w, h) {
    gfx.clear(theme.bg);
    if (browserMenu) { drawBrowserMenu(tabs[active], w, h); return; }
    gfx.rect(0, 0, w, 36, 0, theme.sidebar);
    gfx.rect(0, 36, w, 43, 0, theme.window);
    gfx.rect(0, h - 25, w, 25, 0, theme.sidebar);
    const tabWidth = Math.min(142, Math.floor((w - 116) / tabs.length));
    const previous = tabs[active];
    for (let i = 0; i < tabs.length; i++) {
        if (ui.button((tabs[i].title ? tabs[i].title.slice(0, tabWidth > 105 ? 17 : 8) : label("Sekme ", "Tab ") + (i + 1)) + "##tab" + i, 8 + i * tabWidth, 5, tabWidth - 4, 28, i === active ? "primary" : "toolbar")) active = i;
    }
    if (tabs.length < 5 && ui.button("+", 8 + tabs.length * tabWidth, 5, 34, 28)) {
        active = tabs.push(newTab()) - 1;
    }
    if (tabs.length > 1 && ui.button(label("Kapat", "Close"), w - 65, 6, 57, 27)) {
        cancel(tabs[active]);
        if (mediaTab === tabs[active]) closeMedia();
        tabs.splice(active, 1);
        active = Math.min(active, tabs.length - 1);
    }
    const tab = tabs[active];
    if (previous !== tab && player) closeMedia();
    if (ui.button("<", 8, 39, 30, 32)) {
        if (tab.index > 0) openPage(tab, tab.history[tab.index - 1], tab.index - 1);
    }
    if (ui.button(">", 42, 39, 30, 32)) {
        if (tab.index + 1 < tab.history.length) openPage(tab, tab.history[tab.index + 1], tab.index + 1);
    }
    if (ui.button(tab.request || tab.styles.length || tab.parser ? label("Dur", "Stop") : label("Yenile", "Reload"), 76, 39, 61, 32)) {
        if (tab.request || tab.styles.length || tab.parser) { cancel(tab); tab.status = "Durduruldu."; }
        else if (tab.url) openPage(tab, tab.url, tab.index);
    }
    const addressWidth = w - 288;
    const displayAddress = (tab.address || label("Adres veya arama", "Address or search")).replace(/##/g, "# #");
    gfx.rect(143, 39, addressWidth, 32, 5, theme.field);
    gfx.clip(149, 39, addressWidth - 12, 32);
    ui.label(displayAddress, 152, 47, 14, theme.text);
    gfx.unclip();
    if (ui.hit("address-keyboard", 143, 39, addressWidth, 32).clicked
        || ui.button(label("Gir", "Go"), w - 54, 39, 46, 32, "primary"))
        editNavigation(tab, tab.address, label("Adres veya arama", "Address or search"), value => openPage(tab, value));
    if (ui.button(label("Menü", "Menu"), w - 137, 39, 77, 32, "toolbar")) browserMenu = true;
    ui.label(label("MASAÜSTÜ", "DESKTOP") + "  ·  " + tab.status.slice(0, 73), 10, h - 21, 13);
    if (player && mediaTab === tab) {
        const info = media.info(player);
        media.draw(player, 8, 79, w - 16, h - 177, "contain");
        if (info.duration > 0) {
            const position = Number(info.position) || 0;
            const selected = ui.slider("media-seek", position, 0, info.duration, 9, h - 94, w - 105, 0.1);
            if (Number.isFinite(selected) && Math.abs(selected - position) >= 0.05) media.seek(player, selected);
            ui.label(mediaTime(position) + " / " + mediaTime(info.duration), w - 89, h - 92, 13);
        }
        if (ui.button(info.state === "playing" ? label("Duraklat", "Pause") : label("Oynat", "Play"), 8, h - 63, 90, 31)) {
            if (info.state === "playing") media.pause(player);
            else media.play(player);
        }
        if (ui.button(label("Medyayı kapat", "Close media"), 105, h - 63, 118, 31)) closeMedia();
        const state = info.state === "failed" ? label("Akış oynatılamadı.", "Playback failed.")
            : info.buffering ? label("Tamponlanıyor…", "Buffering…") : "";
        ui.label(state, 233, h - 56, 14);
        return;
    }
    if (tab.watch && !tab.catalog) { drawWatch(tab, w, h); return; }
    if (tab.netflix && !tab.catalog) { drawNetflix(tab, w, h); return; }
    if (!tab.url && !tab.rows.length && !tab.request && !tab.parser && !tab.address) {
        const left = Math.max(24, (w - 520) / 2);
        ui.label("NetX-Browser Mini", left, 104, 34, theme.text, "bold");
        ui.label(label("Adres çubuğundan bir site aç veya arama yap.", "Open a site or search from the address bar."), left, 158, 17, theme.text2);
        if (ui.button("Wikipedia", left, 199, 112, 36)) openPage(tab, "https://tr.wikipedia.org/");
        if (ui.button(label("Kaynak kütüphanesi", "Reference library"), left + 122, 199, 160, 36)) showCatalog(tab);
        if (ui.button("WebGL Cubemap", left + 292, 199, 130, 36)
            && !sys.launch("browser", "https://webglsamples.org/dynamic-cubemap/dynamic-cubemap.html"))
            tab.status = label("Sistem tarayıcısı açılamadı.", "Could not open the system browser.");
        if (ui.button("YouTube", left, 246, 112, 36)) openTube(tab, "");
        if (ui.button(label("YouTube’da ara", "Search YouTube"), left + 122, 246, 160, 36))
            editNavigation(tab, "", label("YouTube’da ara", "Search YouTube"),
                query => openTube(tab, "tube:search:" + query.slice(0, 200)));
        if (ui.button("Netflix", left + 292, 246, 130, 36)) openPage(tab, netflixExample);
        if (ui.button(label("Teknoloji haberleri", "Technology news"), left, 293, 160, 36))
            openPage(tab, "https://news.ycombinator.com/");
        if (ui.button("GitHub", left + 170, 293, 112, 36))
            openPage(tab, "https://github.com/explore");
        return;
    }
    const wide = w >= 780 && !tab.catalog && tab.rows.length > 0;
    const contentsWidth = wide && tab.sections && tab.sections.length ? 148 : 0;
    const infoWidth = wide && tab.info && tab.info.length ? Math.min(280, Math.floor(w * 0.28)) : 0;
    const panelWidth = Math.min(1280, w - 28);
    const wiki = wide && /\.wikipedia\.org\//.test(tab.url);
    const panelX = Math.floor((w - panelWidth) / 2);
    const width = panelWidth - 44 - contentsWidth - infoWidth;
    measure(tab, width);
    const top = wiki ? 125 : 85;
    const viewport = h - top - 29;
    gfx.rect(panelX, 85, panelWidth, h - 114, 6, theme.window);
    if (wiki) {
        ui.label("Wikipedia", panelX + 15, 92, 24, theme.text, "bold");
        ui.label("Özgür ansiklopedi", panelX + 145, 101, 13, theme.text2);
        gfx.rect(panelX + 12, 119, panelWidth - 24, 1, 0, theme.separator);
    }
    if (contentsWidth) {
        ui.label("İçindekiler", panelX + 15, top + 12, 15, theme.text, "bold");
        for (let i = 0; i < Math.min(tab.sections.length, Math.floor((viewport - 40) / 22)); i++)
            ui.label(tab.sections[i].text.slice(0, 21), panelX + 15, top + 40 + i * 22, 13, theme.accent);
    }
    if (infoWidth) drawInfoBox(tab.info, panelX + panelWidth - infoWidth - 9, top + 48, infoWidth, viewport - 54);
    if (!tab.rows.length) {
        ui.label(tab.status, panelX + 24, top + 25, 16, theme.text2);
        return;
    }
    const [scroll] = ui.beginScroll("page" + active, panelX + 13 + contentsWidth, top + 6,
        panelWidth - 26 - contentsWidth - infoWidth, viewport - 12, contentHeight + 8);
    let destination = "";
    for (let i = 0; i < layout.length; i++) {
        const box = layout[i];
        if (box.y > scroll + viewport) break;
        if (box.y + box.height < scroll) continue;
        const row = tab.rows[i];
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
            if (row.link && ui.hit("imageLink" + i, 8, box.y, width, box.height).clicked) destination = row.link;
        } else {
            const color = row.css.color || "";
            const background = row.css["background-color"] || "";
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
                        if (part.link && ui.hit("inline" + i + ":" + j + ":" + k, x, y,
                            Math.min(part.w, box.innerWidth), box.rich.lineHeight).clicked) destination = part.link;
                    }
                }
                continue;
            }
            gfx.color(textColor);
            const align = /^(left|right|center)$/.test(row.css["text-align"]) ? row.css["text-align"] : "left";
            gfx.wrap(row.text, 8 + box.padding, box.y + box.padding, box.innerWidth, box.size, box.font, align);
            if (row.link && ui.hit("link" + i, 8, box.y, width, box.height).clicked) destination = row.link;
        }
    }
    ui.endScroll();
    if (destination) openPage(tab, destination);
};
