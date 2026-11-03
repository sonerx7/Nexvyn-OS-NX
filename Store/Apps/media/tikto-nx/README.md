# TikTo-NX 0.1.0

Nexvyn OS için tarayıcı ve WebView kullanmayan, resmî olmayan native TikTok istemcisi.
YousTube ile aynı C++ `media::Player` motorunu kullanır. Kaynaklar ayrı tutulur;
referans SDK, asıl Nexvyn OS kaynakları ve `start.bat` değiştirilmez.

## Kullanım ve kurulum

Derlenmiş paket bu sayfadaki `tiktok.nxvapp` dosyasıdır. Uyumlu NRO: [TikTo-NX 0.1.0 sürümü](https://github.com/sonerx7/Nexvyn-OS-NX/releases/tag/tikto-nx-v0.1.0).

1. `NexvynOS-TikTo-NX.nro`: Bu native modülle aynı ABI'ye sahip sistem derlemesi.
   Homebrew Menu üzerinden bu NRO'yu başlat.
2. `TikTo-NX.nxvapp`: SD karttaki `NexvynOS/Applications/` klasörüne kopyala;
   ayrıca Nexvyn OS içinde Dosyalar'dan açıp **Yükle** seçeneğini kullanabilirsin.
3. Başlatıcı'dan **TikTo-NX**'i aç. Native modül için sistem ilk açılışta izin ister.

**Uyumlu NRO gereklidir.** Mevcut halka açık SDK, Lua/JS uygulamalarına video
oynatma API'si sunmuyor. Bu nedenle paket gerçek bir C++ `.nxvmod` taşır ve beraber
verilen sistem derlemesinin ABI'sine bağlıdır. Başka bir NRO'da çalışacağı iddia edilmez.

Üstteki alana `@kullanıcıadı` veya bir TikTok video bağlantısı gir. Herkese açık
profilin gömme sayfasının sunduğu videolar listelenir; liste mevcut durumda en fazla
ilk 10 videoyu içerir. Video aç, kaydet, profilini aç veya konsolda takip et.

- Yukarı/aşağı: önceki/sonraki video; video üzerinde dikey dokunma hareketi de desteklenir.
- Boşluk: duraklat/devam et. Sol/sağ: 5 saniye geri/ileri.
- Oynatıcıdaki düğmeler: sessiz, önceki/sonraki ve zaman çubuğu.
- Uygulama menüsü: döngü ve otomatik sonraki video.
- Takipler, kayıtlar ve geçmiş **konsola özeldir**; TikTok hesabına yazılmaz.
- Özel, silinmiş, bölgesel kısıtlı veya doğrulama isteyen içerikler açılamayabilir.
  Fotoğraf gönderileri bu sürümde desteklenmez. Kişisel **Sana Özel** akışı yoktur.

## Hesap girişi

Hesap ekranında TikTok uygulamasından okutulan gerçek QR yetkilendirme akışı bulunur.
TikTok Developer Portal'da **Login Kit** ve **Display API** ürünleri ile
`user.info.basic` ve `video.list` izinleri olan kendi uygulaman gerekir.

Hesap ekranında Client Key, Client Secret ve portalda kayıtlı HTTPS Redirect URI'yi
girip kaydet; sonra **QR ile giriş yap** seç. Telefonunda TikTok ile kodu okut ve
yetkiyi onayla. Kullanıcı adı/parola toplama ekranı veya sahte giriş bulunmaz.
Bu izinler profil ve kullanıcının kendi herkese açık videoları içindir; kişisel akış,
hesaptaki takip listesi ve beğeniler için erişim vermez.

Anahtarlar ve yenileme tokeni uygulamanın özel veri klasöründe AES-256-CTR ve
HMAC-SHA256 ile saklanır; erişim tokeni yalnızca bellekte tutulur. Oturum kapatılırken
bu uygulamanın kayıtlı oturumu boşaltılır; geliştirici bilgileri ve cihaz anahtarı
korunur. Bu, kullanıcının **kendi** geliştirici istemcisiyle yerel kullanım içindir;
paylaşılan bir servis sırrını paket içinde dağıtmak için tasarlanmamıştır.

Kaynaklar: [TikTok QR yetkilendirmesi](https://developers.tiktok.com/docs/en/login-kit-qr-code-authorization),
[token yönetimi](https://developers.tiktok.com/docs/en/oauth-user-access-token-management),
[Display API](https://developers.tiktok.com/docs/en/display-api-overview).

Gerçek hesapla uçtan uca giriş, geliştirici bilgileri bulunmadığı için doğrulanmadı.
QR durumları, token yenileme, iptal ve sahte yanıt reddi kontrollü testlerle doğrulanır.

## Geliştirme

Windows, devkitPro ve yereldeki `../SnxOS-NX` native kaynak ağacı gerekir:

```powershell
python TikTok.native/build.py --prepare-only
python TikTok.native/package_native.py
python TikTok.native/test.py
```

İlk komut `.local/tiktok-native-build/` içinde ayrı bir kopya hazırlar. İkinci komut
Nexvyn OS'un kendi native modül araçlarıyla modülü ve uyumlu NRO'yu derler, tüm
import sembollerini ve paket bütünlüğünü denetler. MSVC testleri gerçek parser ve
hesap durum makinesini çalıştırır. Hesap testindeki libnx şimi kriptografi testi değildir.

Masaüstü fare/klavyesine dokunmadan, ayrı Ryujinx profili ve uygulama içi otomasyonla test:

```powershell
python TikTok.native/emulator.py --module --script TikTok.native/tests/profile.autorun.txt
```

Test profili `.local/tiktok-emulator/` içindedir. İnternet bu profile açılır;
asıl Ryujinx profili ve kullanıcı SD kartı değiştirilmez. Testte yalnızca kendi
`tiktok` modülümüz önceden güvenilir kabul edilir. Dağıtılan NRO ve paket kullanıcının
normal native izin ekranını korur. Ekran görüntüleri test SD kartındaki `autoshots/`
klasörüne yazılır. Cihaz doğrulaması ayrıca yapılmalıdır.

GPL-3.0-or-later. Nexvyn OS medya motoru ve YousTube'un oturum saklama tasarımı
üzerine kuruludur. TikTok/ByteDance tarafından yayımlanmış veya onaylanmış değildir.
