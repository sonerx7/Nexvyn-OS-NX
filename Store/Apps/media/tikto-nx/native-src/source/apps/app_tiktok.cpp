// Native TikTok client for Nexvyn OS. Uses the same media::Player as YousTube.
#include "../wm/app.h"
#include "../wm/registry.h"
#include "../core/gfx.h"
#include "../core/text.h"
#include "../core/net.h"
#include "../core/media.h"
#include "../core/fsutil.h"
#include "../core/qr.h"
#include "tiktok_account.h"
#include <set>

namespace {
const Color BG(12,12,16), PANEL(22,22,28), WHITE(248,248,250), MUTED(160,161,176), CYAN(37,244,238), PINK(254,44,85);
const char* UA="Mozilla/5.0";
const char* L(const char* key) { return i18n::tns("tiktok",key); }

class TikTokApp : public App {
    enum View { HOME, FOLLOWING, SAVED, HISTORY, ACCOUNT, WATCH };
    View view_=HOME, returnView_=HOME;
    media::Player player_;
    tiktok::Account account_;
    std::vector<tiktok::Video> videos_;
    Json local_=Json::object();
    tiktok::Page profile_;
    std::string input_, notice_, clientKey_, clientSecret_, redirect_;
    std::string myName_, qrEncoded_, pendingUrl_, toast_;
    qr::Code qr_;
    int index_=-1, pageRequest_=0;
    uint32_t pageGeneration_=0, resolveGeneration_=0, accountRevision_=0;
    bool loading_=false, resolving_=false, muted_=false, loop_=true, autoNext_=false;
    bool suspended_=false;
    double wheelAt_=0, toastUntil_=0;
    Rect videoRect_;
    float volume_=0.85f, speed_=1, touchStart_=0, touchX_=0;
    bool touchTracking_=false;
    std::map<std::string,gfx::Image*> images_;
    std::set<std::string> imageFailed_, imagePending_;
    std::set<int> requests_;

    std::string localPath() const { return fsx::join(dataDir(),"library.json"); }
    void save() {
        local_["volume"]=volume_; local_["mute"]=muted_; local_["loop"]=loop_; local_["autoNext"]=autoNext_;
        if (!local_.save(localPath())) notice_=L("storage_error");
    }
    void cancelPage() {
        ++pageGeneration_; if (pageRequest_) { net::cancel(pageRequest_); requests_.erase(pageRequest_); pageRequest_=0; }
        loading_=false;
    }
    void stopVideo() { ++resolveGeneration_; resolving_=false; player_.close(); }
    int get(const std::string& url, std::function<void(const net::Response&)> cb, size_t max=8*1024*1024) {
        net::Request r; r.url=url; r.userAgent=UA;
        r.maxBytes=max; r.timeout=25;
        auto alive=aliveToken(); auto box=std::make_shared<int>(0);
        *box=net::request(r,[this,alive,box,cb](const net::Response& res) {
            if (!*alive) return;
            requests_.erase(*box);
            if (!res.ok()) LOGT("tiktok","public request: HTTP %d, %s",res.status,res.error.c_str());
            cb(res); redraw();
        }); requests_.insert(*box); return *box;
    }
    gfx::Image* image(const std::string& url) {
        if (url.find("https://")!=0) return nullptr;
        auto it=images_.find(url); if (it!=images_.end()) return it->second;
        if (imagePending_.size()>=2 || imageFailed_.count(url) || imagePending_.count(url)) return nullptr;
        if (images_.size()>=20) { auto old=images_.begin(); gfx::dropImage("tiktok-cover:"+old->first); images_.erase(old); }
        imagePending_.insert(url);
        get(url,[this,url](const net::Response& res) {
            imagePending_.erase(url);
            if (!res.ok()) { imageFailed_.insert(url); return; }
            std::string key="tiktok-cover:"+url;
            auto* im=gfx::imageFromMemory(key,res.body.data(),res.body.size());
            if (im) images_[url]=im; else imageFailed_.insert(url);
        },2*1024*1024);
        return nullptr;
    }
    void clearImages() {
        for (const auto& im:images_) gfx::dropImage("tiktok-cover:"+im.first);
        images_.clear(); imageFailed_.clear();
    }
    bool contains(const char* list,const std::string& share) const {
        for (const auto& j:local_[list].elements()) if (j["share"].str()==share) return true;
        return false;
    }
    void remember(const char* list,const tiktok::Video& v,bool toggle=false) {
        Json next=Json::array(); bool exists=contains(list,v.share);
        if (!toggle || !exists) next.push(tiktok::savedVideo(v));
        for (const auto& j:local_[list].elements()) if (j["share"].str()!=v.share && next.size()<200) next.push(j);
        local_[list]=next; save();
    }
    bool followed(const std::string& name) const {
        for (const auto& j:local_["following"].elements()) if (j.str()==name) return true;
        return false;
    }
    void follow(const std::string& name) {
        if (tiktok::canonical("@"+name).empty()) return;
        Json list=Json::array(); bool has=followed(name);
        for (const auto& j:local_["following"].elements()) if (j.str()!=name) list.push(j);
        if (!has && list.size()<200) list.push(name);
        local_["following"]=list; save();
    }
    void go(View v) {
        cancelPage(); stopVideo(); notice_.clear(); view_=v; profile_=tiktok::Page();
        if (v==HOME || v==FOLLOWING || v==ACCOUNT) videos_.clear();
        if (v==SAVED || v==HISTORY) {
            videos_.clear(); for (const auto& j:local_[v==SAVED?"saved":"history"].elements()) {
                auto item=tiktok::loadVideo(j); if (!item.share.empty()) videos_.push_back(item);
            }
        }
    }
    void openInput() {
        std::string url=tiktok::canonical(input_);
        if (url.empty()) { notice_=L("invalid_link"); return; }
        ui::unfocus(); fetchPublic(url,true);
    }
    void fetchPublic(const std::string& url,bool enterWatch) {
        cancelPage(); stopVideo(); view_=HOME; videos_.clear(); profile_=tiktok::Page();
        notice_.clear(); loading_=true; pendingUrl_=url; auto gen=pageGeneration_;
        pageRequest_=get(tiktok::publicEndpoint(url),[this,gen,enterWatch](const net::Response& res) {
            if (gen!=pageGeneration_) return;
            pageRequest_=0; loading_=false;
            if (!res.ok()) { notice_=std::string(L("public_error"))+" (HTTP "+std::to_string(res.status)+(res.error.empty()?"":", "+res.error)+")"; return; }
            tiktok::Page p;
            if (!tiktok::parsePublic(res.body,p)) {
                auto resolved=tiktok::canonical(res.url);
                if (!resolved.empty() && resolved!=pendingUrl_ && tiktok::publicEndpoint(resolved)!=resolved) { fetchPublic(resolved,enterWatch); return; }
                notice_=L("public_blocked"); return;
            }
            profile_=p; videos_=p.videos;
            if (videos_.empty()) notice_=L("profile_empty");
            if (enterWatch && videos_.size()==1 && pendingUrl_.find("/video/")!=std::string::npos) play(0);
        });
    }
    void startStream() {
        if (index_<0 || index_>=(int)videos_.size()) return;
        auto& v=videos_[index_];
        if (v.stream.empty()) return;
        media::OpenOptions opt; opt.userAgent=UA; opt.referer="https://www.tiktok.com/"; opt.loop=loop_; opt.speed=speed_;
        player_.setVolume(volume_); player_.setMuted(muted_); player_.open(v.stream,opt);
        remember("history",v);
    }
    void play(int i) {
        if (i<0 || i>=(int)videos_.size()) return;
        stopVideo(); if (view_!=WATCH) returnView_=view_; view_=WATCH; index_=i; notice_.clear();
        if (!videos_[i].stream.empty()) { startStream(); return; }
        resolving_=true; auto gen=resolveGeneration_; std::string id=videos_[i].id;
        get(tiktok::publicEndpoint(videos_[i].share),[this,gen,id](const net::Response& res) {
            if (gen!=resolveGeneration_ || view_!=WATCH) return;
            resolving_=false;
            tiktok::Page p;
            if (!res.ok() || !tiktok::parsePublic(res.body,p)) { notice_=L("public_blocked"); return; }
            for (const auto& v:p.videos) if (v.id==id && !v.stream.empty()) { videos_[index_]=v; startStream(); return; }
            notice_=L("stream_unavailable");
        });
    }
    void step(int direction) { if (view_==WATCH) play(index_+direction); }
    void myVideos(bool append=false) {
        if (loading_ || !account_.signedIn()) return;
        if (!append) { cancelPage(); stopVideo(); videos_.clear(); view_=HOME; profile_=tiktok::Page(); }
        loading_=true; notice_.clear(); auto gen=pageGeneration_;
        Json body=Json::object(); body["max_count"]=20; if (append) body["cursor"]=profile_.cursor;
        account_.api("POST","video/list/?fields=id,title,video_description,duration,cover_image_url,share_url",body,
            [this,gen,append](const Json& j,const std::string& err) {
                if (gen!=pageGeneration_) return;
                loading_=false;
                if (!err.empty()) { notice_=std::string(L("api_error"))+" ("+err+")"; return; }
                auto p=tiktok::parseDisplay(j); profile_.cursor=p.cursor; profile_.more=p.more;
                for (const auto& v:p.videos) if (videos_.size()<400) {
                    bool has=false; for (const auto& old:videos_) if (old.id==v.id) has=true; if (!has) videos_.push_back(v);
                }
                if (videos_.empty()) notice_=L("own_empty");
                redraw();
            });
    }
    void accountProfile() {
        account_.api("GET","user/info/?fields=open_id,display_name",Json(),[this](const Json& j,const std::string& err) {
            if (err.empty()) myName_=j["data"]["user"]["display_name"].str();
            redraw();
        });
    }
    bool nav(const char* key,const char* icon,float y,View v) {
        bool selected=view_==v || (view_==WATCH && returnView_==v);
        if (selected) gfx::roundRect(Rect(12,y,170,43),10,Color(39,28,37));
        text::icon(icon,26,y+10,23,selected?PINK:MUTED);
        text::draw(L(key),60,y+12,15,selected?WHITE:MUTED,text::SANS_SEMI);
        if (ui::interact(ui::makeId(key),Rect(12,y,170,43)).clicked) { go(v); return true; } return false;
    }
    void sidebar(float h) {
        gfx::rect(Rect(0,0,196,h),Color(17,17,22));
        text::icon("music_note",22,25,34,CYAN); text::icon("music_note",25,27,34,PINK);
        text::draw("TikTo-NX",61,28,22,WHITE,text::SANS_BOLD);
        text::draw(L("native"),25,69,11,MUTED);
        nav("home","home",110,HOME); nav("following","people",160,FOLLOWING);
        nav("saved","bookmark",210,SAVED); nav("history","history",260,HISTORY); nav("account","person",310,ACCOUNT);
        text::drawWrapped(L("local_note"),24,std::max(370.f,h-95),147,12,MUTED);
    }
    void library(float x,float y,float w,float h) {
        if (view_==FOLLOWING) {
            text::draw(L("following"),x,y,24,WHITE,text::SANS_BOLD);
            text::drawWrapped(L("following_note"),x,y+39,w,14,MUTED);
            auto names=local_["following"].elements();
            if (names.empty()) text::drawWrapped(L("no_follows"),x,y+110,w,16,MUTED);
            ui::beginScroll("follow_list",Rect(x,y+100,w,h-110),(float)names.size()*62);
            std::string open,remove;
            for (size_t i=0;i<names.size();++i) {
                std::string name=names[i].str(); float yy=(float)i*62;
                text::draw("@"+name,12,yy+14,18,WHITE);
                if (ui::button(std::string(L("open"))+"##"+name,Rect(w-185,yy+8,80,36))) open=name;
                if (ui::iconButton("person_remove",Rect(w-85,yy+8,40,36),MUTED,false,true,name)) remove=name;
            }
            ui::endScroll(); if (!remove.empty()) follow(remove); if (!open.empty()) fetchPublic(tiktok::canonical("@"+open),false); return;
        }
        const char* heading=view_==SAVED?"saved":view_==HISTORY?"history":"discover";
        text::draw(profile_.username.empty()?L(heading):"@"+profile_.username,x,y,25,WHITE,text::SANS_BOLD);
        if (!profile_.username.empty()) {
            if (ui::button(L(followed(profile_.username)?"unfollow":"follow"),Rect(x+w-168,y,168,36),ui::BTN_PRIMARY)) follow(profile_.username);
            text::drawWrapped(profile_.bio,x,y+41,w-10,13,MUTED,text::SANS,text::LEFT,1,2);
        } else text::drawWrapped(L(view_==SAVED?"saved_note":view_==HISTORY?"history_note":"home_note"),x,y+41,w,14,MUTED,text::SANS,text::LEFT,1,3);
        y+=109; h-=109;
        if (loading_) { ui::spinner(x+w/2,y+48,17); return; }
        if (!notice_.empty()) { text::drawWrapped(notice_,x,y,w,15,MUTED); y+=92; h-=92; }
        if (videos_.empty()) {
            if (notice_.empty()) {
                gfx::roundRect(Rect(x,y,w,std::min(190.f,h)),16,PANEL);
                text::iconCentered("ondemand_video",x+w/2,y+43,38,CYAN);
                text::drawWrapped(L("empty"),x+24,y+85,w-48,17,WHITE,text::SANS,text::CENTER);
                text::drawWrapped(L("paste_hint"),x+24,y+124,w-48,13,MUTED,text::SANS,text::CENTER);
            } return;
        }
        int columns=std::max(1,(int)(w/175)); float cw=(w-12*(columns-1))/columns, ch=cw*1.28f+83;
        float content=std::ceil((float)videos_.size()/columns)*ch+52; int picked=-1;
        Vec2 offset=ui::beginScroll("video_grid",Rect(x,y,w,std::max(40.f,h)),content);
        for (size_t i=0;i<videos_.size();++i) {
            const auto& v=videos_[i]; float xx=(i%columns)*(cw+12), yy=(i/columns)*ch;
            if (yy+ch<offset.y || yy>offset.y+h) continue;
            Rect card(xx,yy,cw,cw*1.28f); gfx::roundRect(card,12,PANEL);
            if (ui::hovered(card)) gfx::roundRectOutline(card,12,CYAN,2);
            auto* cover=image(v.cover); if (cover) gfx::drawImageFit(cover,card,true,12);
            else text::iconCentered("play_circle",xx+cw/2,yy+cw*.64f,36,MUTED);
            gfx::roundRect(Rect(xx+8,yy+card.h-28,60,21),6,Color(0,0,0,190));
            text::draw(media::formatTime(v.duration),xx+15,yy+card.h-26,11,WHITE);
            text::drawIn("@"+v.author,Rect(xx,yy+card.h+9,cw,21),14,WHITE,text::SANS_BOLD);
            text::drawWrapped(v.caption,xx,yy+card.h+34,cw,12,MUTED,text::SANS,text::LEFT,1,2);
            if (ui::interact(ui::makeId("video_"+v.id),card).clicked) picked=(int)i;
        }
        bool more=profile_.more && ui::button(L("more"),Rect(0,content-48,170,38));
        ui::endScroll(); if (more) myVideos(true); if (picked>=0) play(picked);
    }
    void watch(float x,float y,float w,float h) {
        if (index_<0 || index_>=(int)videos_.size()) return;
        const auto v=videos_[index_]; float right=std::min(220.f,w*.32f), vw=w-right-20;
        Rect video(x,y,vw,h-74); videoRect_=video; gfx::roundRect(video,12,Color(0,0,0)); player_.draw(video,0);
        if (resolving_ || player_.state()==media::OPENING || player_.buffering()) ui::spinner(video.x+video.w/2,video.y+video.h/2,20);
        if (!notice_.empty() || player_.state()==media::FAILED) {
            text::drawWrapped(notice_.empty()?L("playback_error"):notice_,video.x+24,video.y+video.h*.35f,video.w-48,15,WHITE,text::SANS,text::CENTER);
            if (ui::button(L("retry"),Rect(video.x+video.w/2-65,video.y+video.h*.65f,130,36))) { videos_[index_].stream.clear(); play(index_); }
        }
        if (ui::interact(ui::makeId("video_pause"),video).clicked && player_.active()) player_.togglePause();
        float xx=x+vw+20;
        text::drawIn("@"+v.author,Rect(xx,y,right,28),19,WHITE,text::SANS_BOLD);
        text::drawWrapped(v.caption,xx,y+43,right,14,MUTED,text::SANS,text::LEFT,1,5);
        if (ui::button(L(contains("saved",v.share)?"unsave":"save"),Rect(xx,y+175,right,40),ui::BTN_PRIMARY,"bookmark")) remember("saved",v,true);
        if (ui::button(L(followed(v.author)?"unfollow":"follow"),Rect(xx,y+225,right,38))) follow(v.author);
        if (ui::button(L("profile"),Rect(xx,y+273,right,36))) fetchPublic(tiktok::canonical("@"+v.author),false);
        if (ui::button(L("copy_link"),Rect(xx,y+318,right,36))) { SDL_SetClipboardText(v.share.c_str()); toast_=L("copied"); toastUntil_=nowSeconds()+2; }
        if (ui::button(L("back"),Rect(xx,y+h-65,right,38))) { stopVideo(); view_=returnView_; notice_.clear(); }
        float bottom=y+h-63;
        if (ui::iconButton("skip_previous",Rect(x,bottom,38,34),WHITE,false,index_>0)) step(-1);
        if (ui::iconButton(player_.paused()?"play_arrow":"pause",Rect(x+42,bottom,38,34),WHITE)) player_.togglePause();
        if (ui::iconButton("skip_next",Rect(x+84,bottom,38,34),WHITE,false,index_+1<(int)videos_.size())) step(1);
        if (ui::iconButton(muted_?"volume_off":"volume_up",Rect(x+128,bottom,38,34),WHITE)) { muted_=!muted_; player_.setMuted(muted_); save(); }
        text::draw(std::to_string(index_+1)+" / "+std::to_string(videos_.size()),x+178,bottom+8,13,MUTED);
        if (player_.duration()>0) {
            float pos=(float)player_.position();
            if (ui::slider("seek",&pos,0,(float)player_.duration(),Rect(x,bottom+40,vw,16))) player_.seek(pos);
        }
    }
    void accountView(float x,float y,float w,float h) {
        bool qrVisible=!account_.qrUrl.empty() || account_.flow==tiktok::Account::REQUESTING || account_.flow==tiktok::Account::EXCHANGING;
        float developerY=qrVisible?555.f:(account_.error.empty()?245.f:285.f);
        ui::beginScroll("account_settings",Rect(x,y,w,h),developerY+310);
        text::draw(L("account"),0,0,25,WHITE,text::SANS_BOLD);
        text::drawWrapped(L("account_note"),0,43,w,14,MUTED,text::SANS,text::LEFT,1,4);
        if (account_.signedIn()) {
            text::draw(myName_.empty()?L("connected"):myName_,0,140,21,CYAN,text::SANS_BOLD);
            if (ui::button(L("my_videos"),Rect(0,184,185,39),ui::BTN_PRIMARY)) myVideos();
            if (ui::button(L("sign_out"),Rect(200,184,135,39))) { account_.signOut(); myName_.clear(); }
        } else {
            if (ui::button(L("qr_login"),Rect(0,140,180,40),ui::BTN_PRIMARY,nullptr,account_.configured())) account_.signIn();
            if (!account_.configured()) text::drawWrapped(L("client_needed"),200,140,w-200,13,MUTED);
        }
        if (account_.qrUrl!=qrEncoded_) { qrEncoded_=account_.qrUrl; qr_=qr::Code(); if (!qrEncoded_.empty()) qr::encode(qrEncoded_,qr_,'L'); }
        if (!account_.qrUrl.empty()) {
            if (qr_.size>0) {
                float scale=std::floor(250.f/(qr_.size+8)), side=(qr_.size+8)*scale;
                gfx::rect(Rect(0,245,side,side),WHITE);
                for (int yy=0; yy<qr_.size; ++yy) for (int xx=0; xx<qr_.size; ++xx) if (qr_.dark(xx,yy))
                    gfx::rect(Rect((xx+4)*scale,245+(yy+4)*scale,scale,scale),Color(0,0,0));
                text::drawWrapped(L(account_.flow==tiktok::Account::SCANNED?"qr_confirm":"qr_scan"),side+24,265,std::max(70.f,w-side-24),15,WHITE);
                if (ui::button(L("cancel"),Rect(side+24,360,110,35))) account_.cancelLogin();
            } else text::drawWrapped(L("qr_too_large"),0,250,w,15,PINK);
        } else if (account_.flow==tiktok::Account::REQUESTING || account_.flow==tiktok::Account::EXCHANGING) ui::spinner(30,270,18);
        if (!account_.error.empty()) text::drawWrapped(std::string(L("login_error"))+" ("+account_.error+")",0,qrVisible?510.f:210.f,w,13,PINK);
        text::draw(L("developer_settings"),0,developerY,19,WHITE,text::SANS_BOLD);
        ui::textField("client_key",clientKey_,Rect(0,developerY+37,w,35),"Client Key");
        ui::textField("client_secret",clientSecret_,Rect(0,developerY+82,w,35),L("secret_hint"),ui::TF_PASSWORD);
        ui::textField("redirect_uri",redirect_,Rect(0,developerY+127,w,35),"https://... (Redirect URI)");
        if (ui::button(L("save_client"),Rect(0,developerY+175,210,38),ui::BTN_PRIMARY)) {
            if (account_.configure(clientKey_,clientSecret_,redirect_)) { clientSecret_.clear(); notice_=L("client_saved"); }
            else notice_=L("client_invalid");
        }
        text::drawWrapped(L("client_help"),0,developerY+230,w,12,MUTED);
        ui::endScroll();
    }
public:
    void onStart(const std::string& arg) override {
        setTitle("TikTo-NX"); account_.init(dataDir()); local_=Json::load(localPath());
        if (!local_.isObject()) local_=Json::object();
        volume_=clampv((float)local_["volume"].num(.85),0.f,1.f); muted_=local_["mute"].boolean();
        loop_=local_["loop"].boolean(true); autoNext_=local_["autoNext"].boolean();
        clientKey_=account_.key(); redirect_=account_.redirect(); accountRevision_=account_.revision;
        if (account_.signedIn()) accountProfile();
        if (!arg.empty()) onOpen(arg);
    }
    void onOpen(const std::string& arg) override { input_=arg; openInput(); }
    void onClose() override {
        cancelPage(); stopVideo(); account_.shutdown(); for (int id:requests_) net::cancel(id); requests_.clear(); clearImages(); save();
    }
    void onAutosave() override { save(); }
    void onSuspend() override { suspended_=true; player_.pause(); cancelPage(); account_.cancelLogin(); save(); }
    void onResume() override { suspended_=false; }
    void onFocusChanged(bool focused) override { if (!focused) player_.pause(); }
    void onLowMemory() override { clearImages(); }
    bool animating() override { return player_.active() || resolving_ || loading_ || account_.flow==tiktok::Account::WAITING || account_.flow==tiktok::Account::SCANNED; }
    Color background() override { return BG; }
    void update(float) override {
        if (suspended_) return;
        account_.tick(); player_.update();
        if (accountRevision_!=account_.revision) {
            accountRevision_=account_.revision;
            if (account_.signedIn()) accountProfile(); else myName_.clear(); redraw();
        }
        if (view_==WATCH && autoNext_ && !loop_ && player_.state()==media::ENDED && index_+1<(int)videos_.size()) step(1);
    }
    void draw(float w,float h) override {
        gfx::rect(Rect(0,0,w,h),BG); sidebar(h);
        float x=216, available=w-x-20;
        ui::textField("tiktok_search",input_,Rect(x,17,std::max(100.f,available-91),39),L("search_hint"),ui::TF_SEARCH);
        bool submit=ui::submitted();
        if (ui::button(L("open"),Rect(w-100,17,80,39),ui::BTN_PRIMARY) || submit) openInput();
        gfx::rect(Rect(x,72,available,1),Color(38,38,47));
        if (view_==WATCH) watch(x,91,available,h-111);
        else if (view_==ACCOUNT) accountView(x,91,available,h-111);
        else library(x,91,available,h-111);
        if (view_==ACCOUNT && !notice_.empty()) {
            gfx::roundRect(Rect(x,h-55,available,39),8,PANEL); text::drawIn(notice_,Rect(x+12,h-55,available-24,39),13,CYAN);
        }
        if (nowSeconds()<toastUntil_) { gfx::roundRect(Rect(x,h-53,available,36),8,PANEL); text::drawIn(toast_,Rect(x+12,h-53,available-24,36),13,CYAN); }
    }
    void onEvent(const InputEvent& e) override {
        if (view_!=WATCH) return;
        if (e.type==EV_KEY_DOWN && !ui::isFocused("tiktok_search")) {
            if (e.key==KEY_DOWN || e.key==KEY_PAGEDOWN) step(1);
            if (e.key==KEY_UP || e.key==KEY_PAGEUP) step(-1);
            if (e.key==KEY_SPACE) player_.togglePause();
            if (e.key==KEY_ESCAPE) { stopVideo(); view_=returnView_; }
            if (e.key==KEY_LEFT) player_.seekBy(-5);
            if (e.key==KEY_RIGHT) player_.seekBy(5);
        }
        // Only swipe over the picture, so touch controls remain independent.
        if (e.type==EV_MOUSE_DOWN && e.touch && videoRect_.contains(Vec2(e.x,e.y))) { touchStart_=e.y; touchX_=e.x; touchTracking_=true; }
        if (e.type==EV_MOUSE_UP && touchTracking_) {
            touchTracking_=false;
            if (std::fabs(e.x-touchX_)<90 && std::fabs(e.y-touchStart_)>80) step(e.y<touchStart_?1:-1);
        }
        if (e.type==EV_SCROLL && videoRect_.contains(Vec2(e.x,e.y)) && nowSeconds()-wheelAt_>.4 && std::fabs(e.dy)>20) { wheelAt_=nowSeconds(); step(e.dy>0?1:-1); }
    }
    std::vector<Menu> menus() override {
        Menu m; m.title="TikTo-NX";
        m.items={{L("home"),1},{L("account"),2},MenuItem::sep(),{L("loop"),3},{L("auto_next"),4}};
        m.items[3].checked=loop_; m.items[4].checked=autoNext_; return {m,standardEditMenu()};
    }
    void onMenu(int id) override {
        if (id==1) go(HOME);
        if (id==2) go(ACCOUNT);
        if (id==3) { loop_=!loop_; player_.setLoop(loop_); save(); }
        if (id==4) { autoNext_=!autoNext_; if (autoNext_) { loop_=false; player_.setLoop(false); } save(); }
    }
};
REGISTER_APP("tiktok",TikTokApp)
}
