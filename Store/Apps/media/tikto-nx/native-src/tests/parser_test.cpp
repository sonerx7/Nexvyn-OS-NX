#define _CRT_SECURE_NO_WARNINGS
#ifdef _MSC_VER
#define __attribute__(x)
#endif
#include "tiktok_parse.h"
#include <cassert>
#include <cstdarg>
#include <fstream>
#include <iostream>

// Host shims only for JSON's file and formatting helpers; parser is production code.
namespace fsx {
bool readFile(const std::string& p,std::string& s) { std::ifstream f(p,std::ios::binary); if(!f)return false; s.assign(std::istreambuf_iterator<char>(f),{});return true; }
bool writeFile(const std::string& p,const std::string& s) { std::ofstream f(p,std::ios::binary);f<<s;return !!f; }
}
namespace str {
std::string fmt(const char* format,...) { char b[1024];va_list v;va_start(v,format);vsnprintf(b,sizeof b,format,v);va_end(v);return b; }
void append(std::string& s,uint32_t cp) {
 if(cp<128)s+=(char)cp;
 else if(cp<2048){s+=(char)(192|(cp>>6));s+=(char)(128|(cp&63));}
 else if(cp<65536){s+=(char)(224|(cp>>12));s+=(char)(128|((cp>>6)&63));s+=(char)(128|(cp&63));}
 else{s+=(char)(240|(cp>>18));s+=(char)(128|((cp>>12)&63));s+=(char)(128|((cp>>6)&63));s+=(char)(128|(cp&63));}
}
}
int main(int argc,char** argv) {
 using namespace tiktok;
 assert(canonical(" @sonerx7 ")=="https://www.tiktok.com/@sonerx7");
 assert(canonical("https://m.tiktok.com/@someone/video/123456?is_from_webapp=1")=="https://www.tiktok.com/@someone/video/123456");
 for(const std::string s:{"https://tiktok.com.evil.test/@me","https://www.tiktok.com@evil.test/@me","http://www.tiktok.com/@me","https://127.0.0.1/@me","https://www.tiktok.com:443/@me","@../test","https://www.tiktok.com/@me/video/a","file:///keys"}) assert(canonical(s).empty());
 assert(canonical("https://vm.tiktok.com/Zexample/")=="https://vm.tiktok.com/Zexample/");
 assert(publicEndpoint("https://www.tiktok.com/@someone/video/123456")=="https://www.tiktok.com/embed/v2/123456?lang=en-US");
 assert(form({{"x","a+b&c/"}})=="x=a%2Bb%26c%2F");
 assert(queryValue("https://x/?code=a%2Bb%3D&state=z","code")=="a+b=");
 assert(withTicket("aweme://authorize?client_ticket=tobefilled&x=y","xyz")=="aweme://authorize?client_ticket=xyz&x=y");
 assert(withTicket("https://evil.test/?client_ticket=x","xyz").empty());
 Json ok=Json::parse(R"({"status":"confirmed","client_ticket":"ticket","state":"state","redirect_uri":"https://app.example/callback?code=a%2Bb%3D&state=state"})");
 std::string code; assert(confirmedCode(ok,"ticket","state","https://app.example/callback",code)&&code=="a+b=");
 assert(!confirmedCode(ok,"wrong","state","https://app.example/callback",code));
 assert(!confirmedCode(ok,"ticket","other","https://app.example/callback",code));
 assert(!confirmedCode(ok,"ticket","state","https://evil.test/callback",code));
 assert(!confirmedCode(ok,"","state","https://app.example/callback",code));
 Page p;
 const char* html=R"(<script nonce='a' id='__UNIVERSAL_DATA_FOR_REHYDRATION__' type='application/json'>{"__DEFAULT_SCOPE__":{"webapp.video-detail":{"itemInfo":{"itemStruct":{"id":"1234567890123456789","desc":"Hello \u0130stanbul","author":{"uniqueId":"test.user"},"video":{"playAddr":"https://cdn.example/video.mp4?a=1&b=2","cover":"https://cdn.example/cover.jpg","duration":12}}}}}}</script>)";
 assert(parsePublic(html,p) && p.videos.size()==1);
 assert(p.videos[0].id=="1234567890123456789" && p.videos[0].duration==12);
 assert(p.videos[0].stream=="https://cdn.example/video.mp4?a=1&b=2");
 assert(p.videos[0].share=="https://www.tiktok.com/@test.user/video/1234567890123456789");
 assert(!parsePublic("<html>Verify you are human</html>",p) && p.videos.empty());
 const char* sigi=R"(<script id="SIGI_STATE">{"ItemModule":{"1":{"id":"1","author":"test.user","desc":"Legacy","video":{"playAddr":{"urlList":["https://cdn.example/a"]}}}}}</script>)";
 assert(parsePublic(sigi,p) && p.videos[0].stream=="https://cdn.example/a");
 const char* profile=R"(<script id="__FRONTITY_CONNECT_STATE__">{"source":{"data":{"/embed/@tester?lang=en-US":{"userInfo":{"uniqueId":"tester","nickname":"Tester","signature":"Bio"},"videoList":[{"id":"11","authorUniqueId":"tester","desc":"Video","coverUrl":"https://cdn.example/cover","playAddr":"https://cdn.example/play"},{"id":"12","authorUniqueId":"tester","privateItem":true,"playAddr":"https://cdn.example/private"}]}}}}</script>)";
 assert(parsePublic(profile,p)&&p.username=="tester"&&p.videos.size()==1&&p.videos[0].stream=="https://cdn.example/play");
 auto saved=savedVideo(p.videos[0]);assert(!saved.has("stream")&&!saved.has("cover"));assert(loadVideo(saved).stream.empty());
 auto display=parseDisplay(Json::parse(R"({"data":{"videos":[{"id":"1234567890123456789","share_url":"https://www.tiktok.com/@test.user/video/1234567890123456789","duration":4}],"cursor":1730000000000,"has_more":true},"error":{"code":"ok"}})"));
 assert(display.videos.size()==1 && display.videos[0].author=="test.user" && display.cursor==1730000000000LL && display.more);
 assert(apiError(Json::parse(R"({"error":{"code":"ok"}})")).empty());
 assert(apiError(Json::parse(R"({"error":"invalid_client"})"))=="invalid_client");
 std::cout<<"PASS: URL boundaries, QR state/ticket/redirect checks, Unicode JSON, public video schemas, Display API pagination and credential-free persistence\n";
 if(argc>1){std::string body;assert(fsx::readFile(argv[1],body));bool found=parsePublic(body,p);std::cout<<"LIVE PUBLIC PAGE: "<<(found?"metadata available":"no accessible metadata")<<"; videos="<<p.videos.size()<<"\n";}
}
