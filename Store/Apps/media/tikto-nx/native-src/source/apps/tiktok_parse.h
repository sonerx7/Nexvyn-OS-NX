#pragma once
#include "../core/json.h"

namespace tiktok {
struct Video {
    std::string id, author, caption, cover, stream, share;
    int duration = 0;
};
struct Page {
    std::vector<Video> videos;
    std::string username, name, bio;
    int64_t cursor = 0;
    bool more = false;
};
// Only TikTok HTTPS pages are accepted. Bare @user names are supported.
std::string canonical(const std::string& input);
std::string publicEndpoint(const std::string& canonicalUrl);
std::string queryValue(const std::string& url, const std::string& key);
std::string withTicket(const std::string& url, const std::string& ticket);
// Reject a confirmed authorization unless both state and client_ticket match.
bool confirmedCode(const Json& j, const std::string& ticket, const std::string& state,
                   const std::string& redirect, std::string& code);
bool parsePublic(const std::string& html, Page& out);
Page parseDisplay(const Json& root);
Json savedVideo(const Video& v); // no expiring CDN URL or credentials persisted
Video loadVideo(const Json& j);
std::string form(const std::vector<std::pair<std::string, std::string>>& pairs);
std::string apiError(const Json& j);
}
