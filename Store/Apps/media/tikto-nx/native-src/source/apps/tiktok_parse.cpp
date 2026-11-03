#include "tiktok_parse.h"
#include <cctype>
#include <set>

namespace tiktok {
namespace {
std::string trim(std::string s) {
    while (!s.empty() && std::isspace((unsigned char)s.front())) s.erase(s.begin());
    while (!s.empty() && std::isspace((unsigned char)s.back())) s.pop_back();
    return s;
}
std::string enc(const std::string& s) {
    const char* hex = "0123456789ABCDEF";
    std::string out;
    for (unsigned char c : s) {
        if (std::isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~') out += (char)c;
        else { out += '%'; out += hex[c >> 4]; out += hex[c & 15]; }
    }
    return out;
}
int unhex(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}
std::string dec(const std::string& s) {
    std::string out;
    for (size_t i = 0; i < s.size(); ++i) {
        if (s[i] == '%' && i + 2 < s.size() && unhex(s[i+1]) >= 0 && unhex(s[i+2]) >= 0) {
            out += (char)(unhex(s[i+1]) * 16 + unhex(s[i+2])); i += 2;
        } else out += s[i] == '+' ? ' ' : s[i];
    }
    return out;
}
bool user(const std::string& s) {
    if (s.empty() || s.size() > 64) return false;
    for (unsigned char c : s) if (!std::isalnum(c) && c != '_' && c != '.') return false;
    return true;
}
std::string address(const Json& a) {
    if (a.isString()) return a.str();
    const Json& list = a["urlList"].isArray() ? a["urlList"] : a["UrlList"];
    for (const auto& x : list.elements()) if (x.isString() && x.str().find("https://") == 0) return x.str();
    return "";
}
Video item(const Json& j) {
    Video v;
    if (j["privateItem"].boolean()) return v;
    v.id = j["id"].str();
    v.caption = j["desc"].str();
    v.author = j["author"].isString() ? j["author"].str() : j["author"]["uniqueId"].str(j["authorUniqueId"].str());
    v.duration = j["video"]["duration"].integer(j["duration"].integer());
    v.cover = address(j["video"]["cover"]);
    v.stream = address(j["video"]["playAddr"]);
    if (v.cover.empty()) v.cover=address(j["coverUrl"]);
    if (v.stream.empty()) v.stream=address(j["playAddr"]);
    if (v.stream.find("https://") != 0) v.stream.clear();
    if (!v.id.empty() && user(v.author)) v.share = "https://www.tiktok.com/@" + v.author + "/video/" + v.id;
    return v;
}
Video embeddedItem(const Json& data) {
    const Json& info=data["itemInfos"];
    Video v; v.id=info["id"].str(); v.caption=info["text"].str();
    v.author=data["authorInfos"]["uniqueId"].str();
    v.duration=info["video"]["videoMeta"]["duration"].integer();
    for (const auto& url:info["video"]["urls"].elements()) if (url.isString() && url.str().find("https://")==0) { v.stream=url.str(); break; }
    for (const auto& url:info["covers"].elements()) if (url.isString()) { v.cover=url.str(); break; }
    if (!v.id.empty() && user(v.author)) v.share="https://www.tiktok.com/@"+v.author+"/video/"+v.id;
    return v;
}
Json script(const std::string& html, const std::string& id) {
    size_t p = html.find("id=\"" + id + "\"");
    if (p == std::string::npos) p = html.find("id='" + id + "'");
    if (p == std::string::npos) return Json();
    p = html.find('>', p);
    if (p == std::string::npos) return Json();
    size_t end = html.find("</script>", ++p);
    if (end == std::string::npos || end - p > 6 * 1024 * 1024) return Json();
    return Json::parse(html.substr(p, end-p));
}
}

std::string canonical(const std::string& input) {
    std::string s = trim(input);
    if (!s.empty() && s[0] == '@') {
        std::string name = s.substr(1);
        return user(name) ? "https://www.tiktok.com/@" + name : "";
    }
    if (s.find("https://") != 0) return "";
    size_t end = s.find_first_of("/?#", 8);
    std::string host = s.substr(8, end == std::string::npos ? end : end-8);
    if (host != "www.tiktok.com" && host != "tiktok.com" && host != "m.tiktok.com" &&
        host != "vm.tiktok.com" && host != "vt.tiktok.com") return "";
    if (s.find_first_of("\r\n\t ") != std::string::npos || s.size() > 2048) return "";
    if (host == "vm.tiktok.com" || host == "vt.tiktok.com") return s;
    if (end == std::string::npos || s.compare(end, 2, "/@") != 0) return "";
    std::string path = s.substr(end, s.find_first_of("?#", end) - end);
    if (!path.empty() && path.back() == '/') path.pop_back();
    size_t slash = path.find('/', 2);
    std::string name = path.substr(2, slash == std::string::npos ? slash : slash-2);
    if (!user(name)) return "";
    if (slash != std::string::npos) {
        if (path.compare(slash, 7, "/video/") != 0) return "";
        std::string id = path.substr(slash + 7);
        if (id.empty() || id.size() > 25) return "";
        for (unsigned char c : id) if (!std::isdigit(c)) return "";
    }
    return "https://www.tiktok.com" + path;
}
std::string publicEndpoint(const std::string& url) {
    std::string clean=canonical(url);
    if (clean.empty()) return "";
    const std::string base="https://www.tiktok.com/@";
    if (clean.find(base)!=0) return clean; // short share links resolve first
    size_t p=clean.find("/video/",base.size());
    if (p!=std::string::npos) return "https://www.tiktok.com/embed/v2/"+clean.substr(p+7)+"?lang=en-US";
    return "https://www.tiktok.com/embed/@"+clean.substr(base.size())+"?lang=en-US";
}

std::string queryValue(const std::string& url, const std::string& key) {
    size_t p = url.find('?');
    if (p == std::string::npos) return "";
    while (++p < url.size()) {
        size_t end = url.find_first_of("&#", p), eq = url.find('=', p);
        if (end == std::string::npos) end = url.size();
        if (eq < end && dec(url.substr(p, eq-p)) == key) return dec(url.substr(eq+1, end-eq-1));
        if (end == url.size() || url[end] == '#') break;
        p = end;
    }
    return "";
}
std::string withTicket(const std::string& url, const std::string& ticket) {
    if (url.find("aweme://authorize?") != 0 && url.find("https://www.tiktok.com/") != 0) return "";
    size_t p = url.find("client_ticket=");
    if (p == std::string::npos || (p && url[p-1] != '?' && url[p-1] != '&')) return "";
    size_t end = url.find_first_of("&#", p);
    return url.substr(0,p) + "client_ticket=" + enc(ticket) + (end == std::string::npos ? "" : url.substr(end));
}
bool confirmedCode(const Json& j, const std::string& ticket, const std::string& state,
                   const std::string& redirect, std::string& code) {
    code.clear();
    if (ticket.empty() || state.empty() || j["status"].str() != "confirmed" || j["client_ticket"].str() != ticket) return false;
    std::string uri = j["redirect_uri"].str();
    size_t p = uri.find('?');
    if (p == std::string::npos || uri.substr(0,p) != redirect) return false;
    std::string received = j["state"].str();
    if (received.empty()) received = queryValue(uri, "state");
    if (received != state) return false;
    code = queryValue(uri,"code");
    return !code.empty();
}
bool parsePublic(const std::string& html, Page& out) {
    out = Page();
    const Json scope = script(html,"__UNIVERSAL_DATA_FOR_REHYDRATION__")["__DEFAULT_SCOPE__"];
    const Json& detail = scope["webapp.video-detail"]["itemInfo"]["itemStruct"];
    std::set<std::string> seen;
    auto add = [&](const Json& j) { Video v = item(j); if (!v.id.empty() && !v.share.empty() && seen.insert(v.id).second) out.videos.push_back(v); };
    add(detail);
    const Json& info = scope["webapp.user-detail"]["userInfo"]["user"];
    out.username = info["uniqueId"].str(); out.name = info["nickname"].str(); out.bio = info["signature"].str();
    const Json sigi = script(html, "SIGI_STATE");
    for (const auto& kv : sigi["ItemModule"].items()) add(kv.second);
    for (const auto& j : scope["webapp.user-detail"]["itemList"].elements()) add(j);
    for (const auto& j : scope["webapp.user-post"]["itemList"].elements()) add(j);
    const Json embed=script(html,"__FRONTITY_CONNECT_STATE__");
    for (const auto& kv:embed["source"]["data"].items()) {
        const Json& d=kv.second;
        if (!d["userInfo"]["uniqueId"].str().empty()) {
            out.username=d["userInfo"]["uniqueId"].str();out.name=d["userInfo"]["nickname"].str();out.bio=d["userInfo"]["signature"].str();
        }
        auto v=embeddedItem(d["videoData"]);
        if (!v.id.empty() && !v.share.empty() && seen.insert(v.id).second) out.videos.push_back(v);
        for (const auto& entry:d["videoList"].elements()) {
            auto ev=embeddedItem(entry);
            if (ev.id.empty()) ev=item(entry);
            if (!ev.id.empty() && !ev.share.empty() && seen.insert(ev.id).second) out.videos.push_back(ev);
        }
    }
    if (out.username.empty()) for (const auto& kv : sigi["UserModule"]["users"].items()) {
        const auto& u = kv.second; out.username = u["uniqueId"].str(); out.name = u["nickname"].str(); out.bio = u["signature"].str(); break;
    }
    return !out.videos.empty() || !out.username.empty();
}
Page parseDisplay(const Json& root) {
    Page p; const Json& data = root["data"];
    p.cursor = (int64_t)data["cursor"].num(); p.more = data["has_more"].boolean();
    for (const auto& j : data["videos"].elements()) {
        Video v; v.id = j["id"].str(); v.caption = j["video_description"].str(j["title"].str());
        v.cover = j["cover_image_url"].str(); v.share = canonical(j["share_url"].str()); v.duration = j["duration"].integer();
        if (!v.id.empty() && !v.share.empty()) {
            const size_t start = std::string("https://www.tiktok.com/@").size();
            size_t slash = v.share.find('/', start); v.author = v.share.substr(start, slash-start); p.videos.push_back(v);
        }
    }
    return p;
}
Json savedVideo(const Video& v) {
    Json j = Json::object(); j["id"] = v.id; j["author"] = v.author; j["caption"] = v.caption; j["share"] = v.share; j["duration"] = v.duration; return j;
}
Video loadVideo(const Json& j) {
    Video v; v.id = j["id"].str(); v.author = j["author"].str(); v.caption = j["caption"].str(); v.share = canonical(j["share"].str()); v.duration = j["duration"].integer(); return v;
}
std::string form(const std::vector<std::pair<std::string, std::string>>& pairs) {
    std::string out; for (const auto& kv : pairs) { if (!out.empty()) out += '&'; out += enc(kv.first) + '=' + enc(kv.second); } return out;
}
std::string apiError(const Json& j) {
    if (j["error"].isString()) return j["error"].str();
    std::string code = j["error"]["code"].str(); return code == "ok" ? "" : code;
}
}
