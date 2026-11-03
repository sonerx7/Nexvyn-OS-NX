// Encrypted storage follows Nexvyn OS YousTube's AES-CTR + HMAC design (GPL-3.0-or-later).
#include "tiktok_account.h"
#include "../core/fsutil.h"
#include "../core/net.h"
#include <switch.h>

namespace tiktok {
namespace {
std::string nonce() {
    uint8_t bytes[24]; randomGet(bytes, sizeof bytes);
    const char* hex = "0123456789abcdef"; std::string s;
    for (auto b : bytes) { s += hex[b >> 4]; s += hex[b & 15]; } return s;
}
bool sameBytes(const uint8_t* a, const uint8_t* b, size_t n) {
    uint8_t d = 0; for (size_t i=0; i<n; ++i) d |= a[i] ^ b[i]; return d == 0;
}
bool deviceSecret(const std::string& dir, uint8_t out[32], bool create) {
    std::string p = fsx::join(dir,".device_secret"), s;
    if (fsx::readFile(p,s)) { if (s.size()!=32) return false; memcpy(out,s.data(),32); return true; }
    if (!create) return false;
    randomGet(out,32); return fsx::writeFile(p,std::string((char*)out,32));
}
void derive(const uint8_t secret[32], const std::string& name, uint8_t enc[32], uint8_t mac[32]) {
    std::string e = "Nexvyn TikTok enc v1 " + name, m = "Nexvyn TikTok mac v1 " + name;
    hmacSha256CalculateMac(enc,secret,32,e.data(),e.size()); hmacSha256CalculateMac(mac,secret,32,m.data(),m.size());
}
}
bool Account::seal(const std::string& name, const std::string& plain) {
    if (plain.empty()) return false;
    uint8_t secret[32], enc[32], mac[32], iv[16], tag[32];
    if (!deviceSecret(dir_,secret,true)) return false;
    derive(secret,name,enc,mac); randomGet(iv,16);
    std::string blob("NXT1",4), ct(plain.size(),'\0'); blob.append((char*)iv,16);
    Aes256CtrContext ctx; aes256CtrContextCreate(&ctx,enc,iv); aes256CtrCrypt(&ctx,&ct[0],plain.data(),plain.size());
    blob += ct; hmacSha256CalculateMac(tag,mac,32,blob.data(),blob.size()); blob.append((char*)tag,32);
    memset(&ctx,0,sizeof ctx); memset(secret,0,32); memset(enc,0,32); memset(mac,0,32);
    return fsx::writeFile(fsx::join(dir_,name+".bin"),blob) && open(name)==plain;
}
std::string Account::open(const std::string& name) const {
    std::string blob;
    if (!fsx::readFile(fsx::join(dir_,name+".bin"),blob) || blob.size()<53 || blob.size()>65536 || blob.compare(0,4,"NXT1")) return "";
    uint8_t secret[32], enc[32], mac[32], tag[32];
    if (!deviceSecret(dir_,secret,false)) return "";
    derive(secret,name,enc,mac); size_t n = blob.size()-52;
    hmacSha256CalculateMac(tag,mac,32,blob.data(),blob.size()-32);
    if (!sameBytes(tag,(const uint8_t*)blob.data()+blob.size()-32,32)) return "";
    std::string plain(n,'\0'); Aes256CtrContext ctx; aes256CtrContextCreate(&ctx,enc,blob.data()+4);
    aes256CtrCrypt(&ctx,&plain[0],blob.data()+20,n);
    memset(&ctx,0,sizeof ctx); memset(secret,0,32); memset(enc,0,32); memset(mac,0,32); return plain;
}
Account::~Account() { shutdown(); }
void Account::init(const std::string& dir) {
    dir_ = dir; fsx::mkdirs(dir_); const Json c = Json::parse(open("client"));
    key_ = c["key"].str(); secret_ = c["secret"].str(); redirect_ = c["redirect"].str();
    if (configured()) refresh_ = Json::parse(open("session"))["refresh"].str();
}
void Account::resetRequests() {
    ++generation_; for (int id : pending_) net::cancel(id); pending_.clear();
    tokenWaiters_.clear(); polling_ = refreshing_ = false;
}
void Account::shutdown() { if (!*alive_) return; *alive_ = false; resetRequests(); }
bool Account::configure(const std::string& key, const std::string& secret, const std::string& redirect) {
    if (key.empty() || secret.empty() || redirect.find("https://")!=0 || redirect.find_first_of("?#\r\n ")!=std::string::npos) return false;
    Json c = Json::object(); c["key"]=key; c["secret"]=secret; c["redirect"]=redirect;
    if (!seal("client",c.dump())) return false;
    resetRequests(); key_=key; secret_=secret; redirect_=redirect; access_.clear(); refresh_.clear();
    seal("session","{}"); flow=IDLE; qrUrl.clear(); error.clear(); ++revision; return true;
}
void Account::request(const std::string& method, const std::string& path, const std::string& body,
                      bool bearer, bool isJson, Callback cb) {
    net::Request r; r.url="https://open.tiktokapis.com/v2/"+path; r.method=method; r.body=body;
    r.followRedirects=false; r.timeout=20; r.maxBytes=4*1024*1024;
    r.headers={"Accept: application/json"};
    if (method=="POST") r.headers.push_back(isJson ? "Content-Type: application/json" : "Content-Type: application/x-www-form-urlencoded");
    if (bearer) r.headers.push_back("Authorization: Bearer "+access_);
    auto alive=alive_; auto gen=generation_; auto box=std::make_shared<int>(0);
    *box=net::request(r,[this,alive,gen,box,cb](const net::Response& res) {
        if (!*alive || gen!=generation_) return;
        pending_.erase(*box); Json j=Json::parse(res.body);
        std::string err=apiError(j);
        if (!res.error.empty()) err="network";
        else if (res.status==401) err="access_token_invalid";
        else if (!res.ok() && err.empty()) err="http_"+std::to_string(res.status);
        else if (!j.isObject()) err="invalid_json";
        cb(j,err);
    });
    pending_.insert(*box);
}
void Account::token(const std::string& body, Callback cb) { request("POST","oauth/token/",body,false,false,cb); }
bool Account::acceptTokens(const Json& j) {
    if (j["access_token"].str().empty() || j["refresh_token"].str().empty() || j["expires_in"].integer()<=0) return false;
    Json s=Json::object(); s["refresh"]=j["refresh_token"];
    if (!seal("session",s.dump())) return false;
    access_=j["access_token"].str(); refresh_=j["refresh_token"].str();
    expires_=nowSeconds()+std::max(0,j["expires_in"].integer()-60); ++revision; return true;
}
void Account::cancelLogin() { resetRequests(); flow=IDLE; qrUrl.clear(); qrToken_.clear(); ticket_.clear(); state_.clear(); }
void Account::signIn() {
    if (!configured()) { flow=FAILED; error="client_required"; return; }
    cancelLogin(); error.clear(); flow=REQUESTING; ticket_=nonce(); state_=nonce();
    request("POST","oauth/get_qrcode/",form({{"client_key",key_},{"scope","user.info.basic,video.list"},{"state",state_}}),false,false,
        [this](const Json& j,const std::string& err) {
            if (!err.empty()) { flow=FAILED; error=err; return; }
            qrUrl=withTicket(j["scan_qrcode_url"].str(),ticket_); qrToken_=j["token"].str();
            if (qrUrl.empty() || qrToken_.empty()) { flow=FAILED; error="invalid_qr"; return; }
            flow=WAITING; nextPoll_=nowSeconds()+3; deadline_=nowSeconds()+180;
        });
}
void Account::tick() {
    if (flow!=WAITING && flow!=SCANNED) return;
    if (nowSeconds()>deadline_) { flow=FAILED; error="expired"; qrUrl.clear(); return; }
    if (polling_ || nowSeconds()<nextPoll_) return;
    polling_=true;
    request("POST","oauth/check_qrcode/",form({{"client_key",key_},{"client_secret",secret_},{"token",qrToken_}}),false,false,
        [this](const Json& j,const std::string& err) {
            polling_=false; nextPoll_=nowSeconds()+3;
            if (flow!=WAITING && flow!=SCANNED) return;
            if (!err.empty()) { flow=FAILED; error=err; qrUrl.clear(); return; }
            std::string status=j["status"].str();
            if (status=="expired" || status=="utilised") { flow=FAILED; error="expired"; qrUrl.clear(); return; }
            if (status=="new") return;
            if (status=="scanned" && j["client_ticket"].str()==ticket_) { flow=SCANNED; return; }
            std::string code;
            if (!confirmedCode(j,ticket_,state_,redirect_,code)) { flow=FAILED; error="authorization_mismatch"; qrUrl.clear(); return; }
            flow=EXCHANGING; qrUrl.clear();
            token(form({{"client_key",key_},{"client_secret",secret_},{"code",code},{"grant_type","authorization_code"},{"redirect_uri",redirect_}}),
                [this](const Json& t,const std::string& e) {
                    if (!e.empty() || !acceptTokens(t)) { flow=FAILED; error=e.empty()?"token_storage":e; }
                    else { flow=IDLE; error.clear(); }
                });
        });
}
void Account::withToken(std::function<void(bool)> cb) {
    if (!access_.empty() && nowSeconds()<expires_) { cb(true); return; }
    if (!signedIn()) { cb(false); return; }
    tokenWaiters_.push_back(cb); if (refreshing_) return; refreshing_=true;
    token(form({{"client_key",key_},{"client_secret",secret_},{"grant_type","refresh_token"},{"refresh_token",refresh_}}),
        [this](const Json& j,const std::string& err) {
            refreshing_=false; bool ok=err.empty() && acceptTokens(j);
            error=ok?"":(err.empty()?"token_storage":err);
            if (err=="invalid_grant" || err=="access_token_invalid") { refresh_.clear(); access_.clear(); seal("session","{}"); ++revision; }
            auto callbacks=std::move(tokenWaiters_); tokenWaiters_.clear(); for (auto& cb:callbacks) cb(ok);
        });
}
void Account::api(const std::string& method,const std::string& path,const Json& body,Callback cb,bool retry) {
    withToken([this,method,path,body,cb,retry](bool ok) {
        if (!ok) { cb(Json(),error.empty()?"sign_in_required":error); return; }
        request(method,path,method=="POST"?body.dump():"",true,true,[this,method,path,body,cb,retry](const Json& j,const std::string& err) {
            if (retry && err=="access_token_invalid") { access_.clear(); expires_=0; api(method,path,body,cb,false); return; }
            cb(j,err);
        });
    });
}
void Account::signOut() {
    std::string old=access_; cancelLogin(); access_.clear(); refresh_.clear(); error.clear();
    // Preserve the user's key and credential files. Only this app's session is replaced.
    if (!seal("session","{}")) error="token_storage";
    ++revision;
    if (!old.empty()) request("POST","oauth/revoke/",form({{"client_key",key_},{"client_secret",secret_},{"token",old}}),false,false,
        [this](const Json&,const std::string& err) { if (!err.empty()) error="revoke_failed"; });
}
}
