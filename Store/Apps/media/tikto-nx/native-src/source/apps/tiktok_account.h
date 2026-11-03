#pragma once
#include "tiktok_parse.h"
#include <set>

namespace tiktok {
class Account {
public:
    using Callback = std::function<void(const Json&, const std::string&)>;
    enum Flow { IDLE, REQUESTING, WAITING, SCANNED, EXCHANGING, FAILED };
    Account() = default;
    ~Account();
    void init(const std::string& dir);
    void shutdown();
    bool configure(const std::string& key, const std::string& secret, const std::string& redirect);
    bool configured() const { return !key_.empty() && !secret_.empty() && !redirect_.empty(); }
    const std::string& key() const { return key_; }
    const std::string& redirect() const { return redirect_; }
    bool signedIn() const { return !refresh_.empty(); }
    void signIn();
    void cancelLogin();
    void signOut();
    void tick();
    void api(const std::string& method, const std::string& path, const Json& body, Callback cb, bool retry = true);
    Flow flow = IDLE;
    std::string qrUrl, error;
    uint32_t revision = 0;
private:
    std::string dir_, key_, secret_, redirect_, access_, refresh_, ticket_, state_, qrToken_;
    double expires_ = 0, nextPoll_ = 0, deadline_ = 0;
    bool polling_ = false, refreshing_ = false;
    uint32_t generation_ = 0;
    std::shared_ptr<bool> alive_ = std::make_shared<bool>(true);
    std::set<int> pending_;
    std::vector<std::function<void(bool)>> tokenWaiters_;
    void request(const std::string& method, const std::string& path, const std::string& body,
                 bool bearer, bool json, Callback cb);
    void token(const std::string& body, Callback cb);
    void withToken(std::function<void(bool)> cb);
    bool acceptTokens(const Json& j);
    bool seal(const std::string& name, const std::string& plain);
    std::string open(const std::string& name) const;
    void resetRequests();
};
}
