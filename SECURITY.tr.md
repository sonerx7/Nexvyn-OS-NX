# Güvenlik politikası

[English](SECURITY.md) · **Türkçe**

## Desteklenen sürümler

Güvenlik düzeltmeleri Nexvyn OS'un en yeni kararlı sürümüne ve güncel SDK'ya girer. Beta sürümler (ön sürümler) test
içindir ve düzeltmeleri sonraki derlemeyle alır. Bildirmeden önce lütfen **Sistem Ayarları > Yazılım Güncelleme** ile
güncelleyin.

| Sürüm | Destekleniyor |
|---|---|
| En yeni kararlı sürüm ([Sürümler](https://github.com/sonerx7/Nexvyn-OS-NX/releases/latest)) | evet |
| Eski sürümler | hayır; lütfen güncelleyin |
| Beta ön sürümleri | sonraki beta ya da kararlı sürümle |

## Güvenlik açığı bildirme

Bir güvenlik sorunu için lütfen **herkese açık bir konu, tartışma ya da pull request açmayın**.

1. GitHub'ın özel güvenlik açığı bildirimini kullanın: bu deponun **Security** sekmesi, sonra **Report a
   vulnerability**. Bildirimi yalnızca bakımcı görür.
2. Bu düğme sizde görünmüyorsa bakımcıyla [GitHub profili](https://github.com/sonerx7) üzerinden iletişime geçip
   özel bir kanal isteyin. Herkese açık bir mesaja ayrıntı yazmayın.

Lütfen şunları ekleyin:

- Nexvyn OS sürümü (**Sistem Ayarları > Hakkında**), sistem sürümü ve Atmosphère sürümü;
- bir saldırganın ne yapabildiği ve bunun için neye ihtiyaç duyduğu (hazırlanmış bir paket, bir web sayfası, ağdaki
  konumu, konsola erişim);
- yeniden üretme adımları ve varsa bir kavram kanıtı;
- kişisel verileri çıkarılmış olarak `sdmc:/NexvynOS/System/Logs/system.log` içindeki ilgili satırlar.

## Kapsam

- Nexvyn OS'un kendisi (`NexvynOS.nro`): izin sistemi ve uygulama sandbox'ı, App Guard, paket kurma ve imza
  denetimleri, güncelleyici, şifreli parola ve anahtar depoları, tarayıcı, ağ ve dosya işleme.
- Bu depodan sunulan Uygulama Mağazası: `Store/catalog.json`, `Store/packages.json`, paket özetleri ve imzaları.
- `SDK/Tools/` ve `Tools/` içindeki SDK araçları.

Burada kapsam dışı: başka yapımcıların yayımladığı uygulama ya da oyunlardaki sorunlar (mağaza sayfasındaki **Bu
Uygulamayı Bildir**'i ya da [bildirim formunu](https://github.com/sonerx7/Nexvyn-OS-NX/issues/new?template=report-app.yml)
kullanın), Atmosphère'deki, konsolun kendi sistemindeki ya da diğer homebrew'lardaki sorunlar.

## Sonrası

Bakımcı bildirimi doğrular, düzeltme üzerinde gizli çalışır ve ayrıntıların ne zaman yayımlanacağında sizinle
anlaşır; bu genellikle düzeltmeyi getiren sürümle olur. İsterseniz sürüm notlarında adınız anılır. Lütfen bir şey
yayımlamadan önce düzeltmenin kullanıcılara ulaşmasına zaman tanıyın.

Bu politikaya uygun, kendi konsolunuzda ve kendi verilerinizle iyi niyetle yapılan araştırma memnuniyetle karşılanır.
Başkalarının verilerine erişmeyin, Uygulama Mağazası'nı ya da güncelleme hizmetini başkaları için bozmayın ve sorunu
kullanan paketler yayımlamayın.
