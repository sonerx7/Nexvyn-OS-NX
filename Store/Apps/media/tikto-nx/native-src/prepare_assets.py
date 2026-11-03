"""Write native bundle metadata, translations and the code-drawn launcher icon."""
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent
BUNDLE = ROOT / 'bundle'
TRANSLATIONS = {
 'native': ('NATIVE · NEXVYN OS', 'NATIVE · NEXVYN OS'),
 'home': ('Keşfet', 'Discover'), 'following': ('Takip ettiklerim', 'Following'),
 'saved': ('Kaydedilenler', 'Saved'), 'history': ('Geçmiş', 'History'), 'account': ('Hesap', 'Account'),
 'local_note': ('Takipler ve kayıtlar bu konsolda saklanır.', 'Follows and saves stay on this console.'),
 'storage_error': ('Kayıt yazılamadı. SD kart alanını kontrol et.', 'Could not save. Check SD card storage.'),
 'invalid_link': ('Bir TikTok video bağlantısı veya @kullanıcıadı gir.', 'Enter a TikTok video link or @username.'),
 'public_error': ('TikTok yanıt vermedi. Bağlantını kontrol edip yeniden dene.', 'TikTok did not respond. Check your connection and retry.'),
 'public_blocked': ('TikTok bu içeriği uygulamaya vermedi. İçerik özel, bölgeyle sınırlı veya doğrulama gerektiriyor olabilir.', 'TikTok did not provide this content. It may be private, region restricted or require verification.'),
 'profile_empty': ('Profil bulundu; TikTok sayfası video listesi sağlamadı. İzlemek için bir video bağlantısı yapıştır.', 'Profile found; TikTok did not provide a video list. Paste a video link to watch.'),
 'stream_unavailable': ('Bu video için native oynatılabilir bir adres sağlanmadı. Fotoğraf gönderileri desteklenmiyor.', 'No native playable stream was provided. Photo posts are not supported.'),
 'api_error': ('TikTok API isteği tamamlanamadı.', 'TikTok API request failed.'),
 'own_empty': ('Hesabında erişilebilir herkese açık video bulunamadı.', 'No accessible public videos found on your account.'),
 'open': ('Aç', 'Open'), 'follow': ('Konsolda takip et', 'Follow locally'), 'unfollow': ('Takipten çıkar', 'Unfollow locally'),
 'following_note': ('Bu liste konsola özeldir; TikTok hesabındaki takip listesiyle eşitlenmez.', 'This list is local; it does not sync with your TikTok follows.'),
 'no_follows': ('Video izlerken veya profil sayfasında “Konsolda takip et” seçeneğini kullan.', 'Choose Follow locally while watching a video or viewing a profile.'),
 'discover': ('Keşfet', 'Discover'),
 'saved_note': ('Daha sonra izlemek için bu konsola kaydettiğin videolar.', 'Videos saved on this console to watch later.'),
 'history_note': ('Bu konsolda açtığın videolar. TikTok hesap geçmişinle eşitlenmez.', 'Videos opened on this console. Does not sync with TikTok account history.'),
 'home_note': ('Video bağlantısı yapıştır veya @kullanıcıadıyla profil aç. Kişisel “Sana Özel” akışı TikTok tarafından bu istemciye sunulmuyor.', 'Paste a video link or open a profile with @username. TikTok does not provide your personal For You feed to this client.'),
 'empty': ('Bir video ile başla', 'Start with a video'),
 'paste_hint': ('Üstteki alana TikTok bağlantısını veya @kullanıcıadını yaz.', 'Enter a TikTok link or @username in the field above.'),
 'more': ('Daha fazla yükle', 'Load more'), 'retry': ('Yeniden dene', 'Retry'),
 'playback_error': ('Video oynatılamadı. Bağlantı süresi dolmuş veya TikTok erişimi kısıtlamış olabilir.', 'Playback failed. The link may have expired or TikTok may have restricted access.'),
 'save': ('Kaydet', 'Save locally'), 'unsave': ('Kaydı kaldır', 'Unsave'), 'profile': ('Profili aç', 'Open profile'),
 'copy_link': ('Bağlantıyı kopyala', 'Copy link'), 'copied': ('Bağlantı kopyalandı.', 'Link copied.'), 'back': ('Geri', 'Back'),
 'account_note': ('Telefondaki TikTok uygulamasından QR kodunu okutup izin ver. Giriş, profilini ve kendi herkese açık videolarını bağlar; Sana Özel akışı, hesap takipleri ve beğeniler için erişim sağlamaz.', 'Scan the QR code with TikTok on your phone and authorize access. Login connects your profile and own public videos; it does not grant access to For You, account follows or likes.'),
 'connected': ('Hesap bağlı', 'Account connected'), 'my_videos': ('Kendi videolarım', 'My videos'),
 'sign_out': ('Çıkış yap', 'Sign out'), 'qr_login': ('QR ile giriş yap', 'Sign in with QR'),
 'client_needed': ('QR girişi için aşağıdaki geliştirici ayarları gerekli.', 'Developer settings below are required for QR login.'),
 'qr_confirm': ('Kod okundu. Telefonda TikTok iznini onayla.', 'Code scanned. Confirm the TikTok authorization on your phone.'),
 'qr_scan': ('TikTok → Ara → QR tarayıcı ile okut. Kod 3 dakika sonra yenilenmelidir.', 'Scan using TikTok → Search → QR scanner. Refresh the code after 3 minutes.'),
 'qr_too_large': ('TikTok bağlantısı QR sınırını aştı. Girişi iptal edip yeniden dene.', 'TikTok link exceeds QR capacity. Cancel login and retry.'),
 'cancel': ('İptal', 'Cancel'), 'login_error': ('Giriş tamamlanamadı; ayarları kontrol edip yeniden dene.', 'Login failed; check settings and retry.'),
 'developer_settings': ('TikTok geliştirici ayarları', 'TikTok developer settings'),
 'secret_hint': ('Client Secret (kaydetmek için gir)', 'Client Secret (required to save)'),
 'save_client': ('Ayarları kaydet', 'Save settings'), 'client_saved': ('Giriş ayarları şifrelenerek kaydedildi.', 'Login settings saved with encryption.'),
 'client_invalid': ('Client Key, Client Secret ve geçerli bir HTTPS Redirect URI gerekli.', 'Client Key, Client Secret and a valid HTTPS Redirect URI are required.'),
 'client_help': ('TikTok Developer Portal: Login Kit + Display API; user.info.basic ve video.list izinleri gerekir. Redirect URI portalda kayıtlı adresle aynı olmalı. Şifreler ve anahtarlar uygulamayla dağıtılmaz.', 'TikTok Developer Portal: Login Kit + Display API with user.info.basic and video.list. Redirect URI must match the registered address. Credentials are not shipped with the app.'),
 'search_hint': ('TikTok bağlantısı veya @kullanıcıadı', 'TikTok link or @username'),
 'loop': ('Videoyu tekrarla', 'Loop video'), 'auto_next': ('Otomatik sonraki video', 'Auto next video'),
}

def main():
    (BUNDLE/'lang').mkdir(parents=True, exist_ok=True)
    manifest = {
      'id':'tiktok', 'name':{'en':'TikTo-NX','tr':'TikTo-NX'},
      'description':{'en':'Unofficial native TikTok viewer. Public links, local follows and QR authorization with your own developer client.',
                     'tr':'Resmî olmayan native TikTok istemcisi. Herkese açık bağlantılar, yerel takipler ve kendi geliştirici uygulamanla QR girişi.'},
      'version':'0.1.0', 'author':'Soner Çakır (sonerx7)', 'category':'media', 'minSdk':'1.8', 'targetSdk':'1.8',
      'native':True, 'icon':'icon.png', 'singleInstance':True, 'permissions':['network'],
      'window':{'width':1100,'height':620,'minWidth':900,'minHeight':580,'resizable':True},
      'license':'GPL-3.0-or-later'
    }
    (BUNDLE/'app.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    for i, lang in enumerate(['tr','en']):
        (BUNDLE/'lang'/f'{lang}.json').write_text(json.dumps({k:v[i] for k,v in TRANSLATIONS.items()},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    # Geometric note icon drawn in code; no fetched branding asset.
    im=Image.new('RGBA',(768,768)); d=ImageDraw.Draw(im)
    d.rounded_rectangle((12,12,756,756),radius=173,fill=(15,15,20,255))
    for dx,dy,c in [(-17,-9,(37,244,238,255)),(17,12,(254,44,85,255)),(0,0,(248,248,250,255))]:
        d.rounded_rectangle((385+dx,165+dy,455+dx,505+dy),radius=12,fill=c)
        d.ellipse((230+dx,424+dy,455+dx,615+dy),fill=c)
        d.ellipse((297+dx,478+dy,389+dx,555+dy),fill=(15,15,20,255))
        d.polygon([(446+dx,165+dy),(473+dx,213+dy),(557+dx,242+dy),(557+dx,318+dy),(472+dx,292+dy),(422+dx,253+dy)],fill=c)
    im.resize((256,256),Image.Resampling.LANCZOS).save(BUNDLE/'icon.png')
    print('Native bundle assets ready')

if __name__=='__main__': main()
