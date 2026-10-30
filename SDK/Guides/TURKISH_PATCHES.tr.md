# Türkçe Yamalar: araştırma ve tasarım

**Türkçe** · [English](TURKISH_PATCHES.en.md)

Bu belge, kullanıcının "YamaNX'i bu sisteme port et, Türkçe yamaları kurabilelim" isteğinin araştırmasını ve
`turkceyama` uygulamasının neden böyle çalıştığını anlatır. Araştırma tarihi: 27 Ekim 2026.

## 1. YamaNX bugün ne?

- **Ne:** SertAy'ın yazdığı, SDL2 tabanlı bir Türkçe yama yükleyicisi (homebrew `.nro`, ana menü için `.nsp`
  kısayolu, PC emülatörleri için `.exe`, mobil emülatörler için `.apk`). Arşivde 650'den fazla oyun var. Yamaların
  çoğu Swatalk'a (470'ten fazla ücretsiz yama), geri kalanı Soner Çakır, Profesör Pikachu, Dede00, emre, davetsiz57
  gibi çevirmenlere ait. Geliştirici yamaları kendisinin yapmadığını açıkça yazıyor.
  - Kaynak: <https://github.com/sertay1/YamaNX> (README, sürümler: v2.1.0 en yenisi)
  - Tanıtım konusu: <https://forum.donanimarsivi.com/posts/11130968/>
  - Geliştiricinin bağlantıları: <https://linktr.ee/yamanx>
- **Kaynak kodu açık mı?** Kod GitHub'da okunabiliyor, ama lisans **özgür yazılım lisansı değil**
  (`LICENSE`, "Copyright (c) 2026 SertAy. All Rights Reserved." + özel koşullar):
  1. Atıf zorunlu, sahiplenmek yasak.
  2. Değişiklikler belgelenmeli, SertAy bağlantıyla anılmalı.
  3. **Ticari olmayan kullanım:** yazılım ve kaynak kodu yazılı izin olmadan satılamaz, para karşılığı dağıtılamaz.
  
  Üçüncü madde GPL-3.0'a ek bir kısıtlama getirir; bu yüzden **YamaNX kodu Nexvyn OS'a (GPL-3.0-or-later) alınamaz.**
  Nexvyn OS'un kendi kodunda YamaNX'ten kod yoktur (YamaNX port'u ayrı lisanslı bir app'tir, bkz. 3b).
- **Katalog / API:** Resmî bir API yok. Uygulama, yama listesini geliştiricinin herkese açık bir gist dosyasından
  (`yamalar.txt`, satır başına `Ad|TitleID|URL|Yapımcı|Sürüm|Boyut`) okuyor; dosyalar Internet Archive'daki
  `YamaNX_Sertay` öğesinde duruyor. Ne gist'te ne de arşiv öğesinde bir lisans ya da kullanım koşulu yok;
  başka istemcilerin bu listeyi kullanmasına izin veren bir açıklama da yok. Bu dosyalar YamaNX'in kendi iç veri
  kaynağı; belgelenmiş, kararlı ya da başkalarına açılmış bir arayüz değil.
- **Kurulum biçimi:** Yamalar Atmosphère LayeredFS mod'ları. Zip, `sdmc:/atmosphere/contents/` içine açılıyor
  (zip içinde `<TID>/romfs/...`). YamaNX, kurduğu her dosyanın tam yolunu
  `atmosphere/contents/<TID>/YamaNX_manifest.txt` dosyasına satır satır yazıyor; kaldırırken bu listeyi kullanıyor.
  Sürüm bilgisi yalnızca bir etiket (ör. `V1.0.4`); oyun sürümüyle karşılaştırma yapılmıyor.
- **Topluluktaki rıza meselesi:** Forum konusunda, çevirmenlerin yamalarının toplu arşivlerde paylaşılması
  üzerine tartışmalar var (ör. <https://forum.donanimarsivi.com/posts/11238902/>). Bazı çevirmenler izin veriyor,
  bazı ekipler yamalarını yalnızca kendi kanallarından dağıtıyor.

## 2. Diğer Türkçe yama kaynakları

| Kaynak | Bağlantı | Not |
| --- | --- | --- |
| Swatalk | <https://discord.com/invite/xshWw2jBK6> | Yüzlerce ücretsiz yama, istek kanalı |
| Soner Çakır | <https://discord.com/invite/tB93ZUsRYE> | Çevirmen topluluk sunucusu |
| SinnerClown Çeviri | <https://sinnerclownceviri.com/forumlar/nintendo-tuerkce-yama.74/> | Ekibin forumundaki konsol yama bölümü ([kaynak](https://forum.donanimhaber.com/nintendo-switch-turkce-yama-arsivi-ariyorum--156348798)) |
| Techolay rehberi | <https://techolay.net/sosyal/konu/guvenilir-turkce-yama-ekipleri-ve-siteler.147247/> | Güvenilir ekip listesi (genel) |

Hiçbiri herkese açık bir API ya da üçüncü taraf istemcilere izin veren koşullar yayımlamıyor.

## 3. Seçilen yol ve nedeni

Görevdeki karar kuralı: açık kaynak bir istemci **ve/veya** üçüncü taraf istemcilere izin veren bir API varsa
yerel istemci yaz; yoksa kazıma/atlatma yapmadan genel bir yükleyici yaz.

- İstemci açık kaynak değil (ticari olmayan kullanım kısıtı, GPL ile uyumsuz) → port edilemez.
- Herkese açık, koşulları belli bir API yok. Gist'i okumak teknik olarak mümkün, ama bu belgelenmemiş bir iç veri
  dosyası; izin yok, ve yamaların sahibi YamaNX değil, çevirmenler. Rıza tartışması da sürüyor.

**Sonuç: 3. yol.** `turkceyama` hiçbir yama sitesinden liste çekmez, dosya indirmez, kopyalamaz, barındırmaz.

### 3b. Güncelleme (2026-10-29): YamaNX port'u

Proje sahibinin kararıyla YamaNX, Nexvyn OS'a Lua ile port edildi: `romfs/Applications/yamanx.app` (Switch Araçları).
YamaNX'in kendi yama listesini ve indirme kaynaklarını YamaNX'in yaptığı gibi kullanır. Kaynak ve yapımcı her ekranda
ve About sayfasında belirtilir: **YamaNX — SertAy**, <https://github.com/sertay1/YamaNX>. App, YamaNX lisansıyla
(ticari olmayan kullanım, atıf) ayrı bir program olarak gelir ve Nexvyn OS'un GPL koduna bağlanmaz; lisans metni ve
değişiklik listesi `yamanx.app/LICENSE` ve `yamanx.app/NOTICE.md` içinde, kısa not `THIRD_PARTY_NOTICES.md`'de.
`turkceyama` olduğu gibi kalır: kendi seçtiğin bir zip'i kurar, liste çekmez.

## 4. Uygulama (`source/apps/app_turkceyama.cpp`)

- **Zip'ten kur:** Kullanıcı yamayı ekibin sitesinden indirir (Tarayıcı, PC, kablo), uygulamada seçer.
  - Yapı tanıma: `[herhangi/]<TID>/romfs|exefs/...` (`atmosphere/contents/<TID>`, `contents/<TID>` dahil),
    yalnızca `romfs/` ya da `exefs/` (oyun listeden seçilir ya da başlık kimliği girilir),
    `exefs_patches/<ad>/...`. Başka her dosya (readme, `YamaNX_manifest.txt`) atlanır ve sayısı gösterilir.
  - Yol güvenliği: her giriş normalize edilir; mutlak yol, sürücü harfi, `..`, `.` ve kontrol karakteri içeren
    girişler yazılmaz. Hedef her zaman `sdmc:/atmosphere/...` altındadır.
  - Yedek: üzerine yazılacak her dosya önce `sdmc:/NexvynOS/Backups/TurkcePatches/<id>/<yol>` altına kopyalanır.
    Yedek alınamazsa kurulum durur. Yazma hatasında kurulum geri alınır.
  - Güncelleme: aynı oyuna yeni zip kurulursa eski yama önce kaldırılır (yedekleri geri konur), sonra yenisi kurulur.
  - Sürüm kontrolü: hedef sürüm katalogdan, yoksa zip adındaki `V1.2.3` kalıbından okunur; konsoldaki oyun sürümüyle
    (ns, `games_lib`) karşılaştırılır. Uymuyorsa turuncu uyarı, bilinmiyorsa gri not.
- **Yüklü yamalar:** aç/kapat (kapalıyken dosyalar `sdmc:/NexvynOS/System/TurkcePatches/disabled/<id>/` altına taşınır
  ve özgün dosyalar yedekten geri konur), kaldır (yedekler geri konur, boş klasörler silinir). YamaNX ile kurulmuş
  yamalar `YamaNX_manifest.txt` üzerinden tanınır ve kaldırılabilir (yalnızca o başlığın klasöründeki dosyalar).
- **YamaNX kartı:** Yüklü Yamalar sayfasının en üstünde. YamaNX ayrı bir program olarak, kodu kopyalanmadan,
  homebrew paket kataloğundan (`romfs/System/Packages/catalog.json`, paket `yamanx`: depo `sertay1/YamaNX`, öğe
  `YamaNX.nro`, hedef `switch/YamaNX/YamaNX.nro`, NACP adı "YamaNX") kurulur; lisans alanı "SertAy — tüm hakları
  saklıdır (ticari olmayan kullanım)", uyarılarda üçüncü taraf olduğu ve yamaların çevirmenlere ait olduğu yazar.
  - Kurulu değilse **YamaNX'i yükle**: paket yöneticisinin onay penceresi (boyut, uyarılar), indirme ilerlemesi kartta.
  - Kuruluysa **YamaNX'i aç**: paket yöneticisinin NRO'ları açtığı gibi hbloader ile zincirleme yükleme (Nexvyn OS
    kapanır, YamaNX başlar). Applet (Albüm) modunda bellek sınırlı olduğu için ek bir not gösterilir.
  - "Proje sayfası" GitHub sayfasını Tarayıcı'da açar. YamaNX'in kurduğu yamalar aşağıdaki listede görünmeye devam eder.
- **Kayıtlar:** `sdmc:/NexvynOS/System/TurkcePatches/installed.json`
  ```json
  {"format": 1, "patches": [{"id": "0100ABCD12345000-1761600000", "tid": "0100ABCD12345000", "name": "Oyun",
    "version": "1.2", "gameVersion": "1.0.4", "team": "Ekip", "page": "https://...", "source": "dosya.zip",
    "installed": 1761600000, "enabled": true, "bytes": 123456,
    "files": ["atmosphere/contents/0100ABCD12345000/romfs/..."], "backedUp": ["atmosphere/..."]}]}
  ```
  `files` SD köküne göredir. Mod Yöneticisi gibi araçlar bu dosyaları "Türkçe Yamalar'a ait" diye tanıyabilir.
- **Yama siteleri:** katalogdaki kaynaklar; "Aç" Tarayıcı'yı açar. Ekip adı ve sayfası kartlarda öne çıkar.
- **Nasıl çalışır:** uygulamanın içinde bu bölümün kısa bir özeti.

## 5. Katalog biçimi

`romfs:/System/TurkcePatches/catalog.json`; sistem güncellemesiyle yenilemek için
`sdmc:/NexvynOS/System/Overlay/TurkcePatches/catalog.json`.

```json
{
  "format": 1,
  "revision": 2,
  "sources": [
    {"name": "Ekip adı", "kind": "web|chat|code", "url": "https://...",
     "about": {"tr": "Kısa tanıtım", "en": "Short intro"}}
  ],
  "patches": [
    {"tid": "0100ABCD12345000", "game": "Oyun adı", "team": "Ekip adı",
     "patchVersion": "1.2", "gameVersion": "1.0.4", "page": "https://ekibin-yama-sayfasi",
     "credits": {"tr": "Çeviri: A, B · Test: C", "en": "Translation: A, B · Testing: C"},
     "notes": {"tr": "DLC gerekir", "en": "Requires the DLC"}}
  ]
}
```

Kurallar:
- Yalnızca ekibin izin verdiği bilgiyi ekle. **İndirme bağlantısı alanı yoktur**: `page`, ekibin kendi sayfasıdır.
- `gameVersion`, yamanın hazırlandığı oyun sürümüdür (konsolun gösterdiği sürüm, ör. `1.0.4`).
- `url` / `page` yalnızca `https://` (sayfa için `http://` da kabul edilir) olabilir; diğerleri yok sayılır.

## 6. İleride

- Bir yama projesi üçüncü taraf istemcilere açık bir API ve koşullar yayımlarsa (ya da SertAy ve çevirmenler yazılı
  izin verirse), katalog bu kaynaktan doldurulabilir; kurulum ve yedek mantığı aynı kalır.
- Ekipler kendi kayıtlarını `catalog.json`'a eklemek için bir PR açabilir.
