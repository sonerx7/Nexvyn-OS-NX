#define _CRT_SECURE_NO_WARNINGS
#ifdef _MSC_VER
#define __attribute__(x)
#endif
#include "tiktok_account.h"
#include "../core/net.h"
#include <cassert>
#include <cstdarg>
#include <iostream>

static double clockNow=1;
double nowSeconds(){return clockNow;}
static std::map<std::string,std::string> files;
namespace fsx {
bool readFile(const std::string& p,std::string& s){auto it=files.find(p);if(it==files.end())return false;s=it->second;return true;}
bool writeFile(const std::string& p,const std::string& s){files[p]=s;return true;}
bool mkdirs(const std::string&){return true;}
std::string join(const std::string& a,const std::string& b){return a+"/"+b;}
}
namespace str {
std::string fmt(const char* format,...){char b[1024];va_list v;va_start(v,format);vsnprintf(b,sizeof b,format,v);va_end(v);return b;}
void append(std::string& s,uint32_t cp){if(cp<128)s+=(char)cp;else if(cp<2048){s+=(char)(192|(cp>>6));s+=(char)(128|(cp&63));}else{s+=(char)(224|(cp>>12));s+=(char)(128|((cp>>6)&63));s+=(char)(128|(cp&63));}}
}
struct Pending {net::Request request;net::Callback cb;bool cancelled=false;};
static std::map<int,Pending> pending;static int nextId=0;
namespace net {
int request(const Request& r,Callback cb,Progress){pending[++nextId]={r,cb};return nextId;}
void cancel(int id){pending[id].cancelled=true;}
}
static void respond(int id,const std::string& body,int status=200,const std::string& error="") {
 auto cb=pending.at(id).cb;net::Response r;r.status=status;r.body=body;r.error=error;cb(r);
}
static std::string value(const std::string& body,const std::string& key){return tiktok::queryValue("https://local/?"+body,key);}
static void authorize(tiktok::Account& a){
 a.signIn();int qr=nextId;
 assert(value(pending[qr].request.body,"scope")=="user.info.basic,video.list");
 std::string state=value(pending[qr].request.body,"state");assert(!state.empty());
 respond(qr,R"({"scan_qrcode_url":"aweme://authorize?client_ticket=tobefilled&client_key=example","token":"qr-token"})");
 assert(a.flow==tiktok::Account::WAITING);
 std::string ticket=tiktok::queryValue(a.qrUrl,"client_ticket");assert(!ticket.empty()&&ticket!="tobefilled");
 clockNow+=4;a.tick();int poll=nextId;
 assert(value(pending[poll].request.body,"token")=="qr-token");
 Json j=Json::object();j["status"]="confirmed";j["client_ticket"]=ticket;j["state"]=state;
 j["redirect_uri"]="https://app.example/callback?code=auth%2Bcode&state="+state;
 respond(poll,j.dump());int token=nextId;assert(a.flow==tiktok::Account::EXCHANGING);
 assert(value(pending[token].request.body,"code")=="auth+code");
 assert(value(pending[token].request.body,"redirect_uri")=="https://app.example/callback");
 respond(token,R"({"access_token":"test-access","refresh_token":"test-refresh","expires_in":120,"scope":"user.info.basic,video.list"})");
 assert(a.signedIn()&&a.flow==tiktok::Account::IDLE);
}
int main(){
 using tiktok::Account;
 Account a;a.init("memory");a.signIn();assert(a.flow==Account::FAILED&&a.error=="client_required");
 assert(!a.configure("key","secret","http://wrong/callback"));
 assert(a.configure("key","secret","https://app.example/callback"));
 authorize(a);assert(files.count("memory/.device_secret")&&files.count("memory/client.bin")&&files.count("memory/session.bin"));
 bool called=false;
 a.api("GET","user/info/?fields=display_name",Json(),[&](const Json& j,const std::string& e){called=true;assert(e.empty()&&j["data"]["display_name"].str()=="Tester");});
 assert(pending[nextId].request.headers.back()=="Authorization: Bearer test-access");
 respond(nextId,R"({"data":{"display_name":"Tester"},"error":{"code":"ok"}})");assert(called);
 clockNow+=70;bool first=false,second=false;
 a.api("GET","user/info/",Json(),[&](const Json&,const std::string& e){first=e.empty();});int refresh=nextId;
 a.api("POST","video/list/",Json::object(),[&](const Json&,const std::string& e){second=e.empty();});
 assert(nextId==refresh && value(pending[refresh].request.body,"refresh_token")=="test-refresh");
 respond(refresh,R"({"access_token":"rotated-access","refresh_token":"rotated-refresh","expires_in":600})");
 int last=nextId;respond(last-1,R"({"error":{"code":"ok"}})");respond(last,R"({"error":{"code":"ok"}})");assert(first&&second);
 a.signIn();int stale=nextId;a.cancelLogin();respond(stale,R"({"scan_qrcode_url":"aweme://authorize?client_ticket=x","token":"stale"})");assert(a.qrUrl.empty()&&a.flow==Account::IDLE);
 a.signIn();respond(nextId,R"({"scan_qrcode_url":"aweme://authorize?client_ticket=x","token":"qr"})");clockNow+=4;a.tick();
 respond(nextId,R"({"status":"confirmed","client_ticket":"attacker","state":"bad","redirect_uri":"https://app.example/callback?code=bad"})");
 assert(a.flow==Account::FAILED&&a.error=="authorization_mismatch");
 a.signOut();assert(!a.signedIn()&&files.count("memory/client.bin")&&files.count("memory/.device_secret"));
 Account b;b.init("memory");assert(b.configured()&&!b.signedIn());
 b.signIn();int late=nextId;b.shutdown();respond(late,R"({"error":"invalid_request"})");
 assert(b.error.empty());
 std::cout<<"PASS: QR authorization, code exchange, token rotation, concurrent refresh, cancellation, forged confirmation, logout persistence and late-close callbacks (mock transport/libnx)\n";
}
