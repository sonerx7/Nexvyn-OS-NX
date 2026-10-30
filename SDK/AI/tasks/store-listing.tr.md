# Görev: store.json ve ekran görüntüsü betiğini yazmak

[English](store-listing.en.md) · **Türkçe**

`system-prompt.tr.md` dosyasından sonra gönderin (bölüm 10 `store.json`'u anlatır). Asistan uygulamanın gerçekte ne
yaptığını ve düğmelerinin nerede olduğunu bilsin diye prompt'un altına `app.json`'u, ana kaynak dosya(lar)ını ve
`lang/en.json`'u yapıştırın.

```text
Bu Nexvyn OS uygulaması için App Market'e store.json yaz.

{
  "kind": "app | game | demo | template",
  "tags": ["3-6 küçük harfli arama sözcüğü"],
  "subtitle": {"en": "...", "tr": "...", "de": "...", "fr": "...", "es": "..."},
  "description": {"en": "...", "tr": "...", "de": "...", "fr": "...", "es": "..."},
  "shots": [[...], [...], [...]]
}

Kurallar:
- subtitle: 60 karakterin altında, kazanımı söyler, uygulama adı yok, sonda nokta yok.
- description: kullanıcının neler yapabileceğini anlatan 2-3 cümlelik bir paragraf, sonra "\n\n" ve 4-6 madde
  ("• ..."); her madde kodda bulunan gerçek bir özellik. Kodda olmayan iddia yok. Abartılı ifade yok.
- Beş dilin hepsi, doğal ifadeyle (kelimesi kelimesine değil), her birinde aynı bilgiler.
- shots: 3 ya da 4 görüntü; her görüntü, o ekran görüntüsünden önce çalışan adımların listesidir ve durum sonraki
  görüntüye taşınır. Yalnızca şu adımlar kullanılabilir:
    wait <saniye>           ör. "wait 1.5"
    wclick <fx> <fy>        uygulama penceresinin içeriğinin 0..1 oranındaki bir noktaya tıkla, ör. "wclick 0.5 0.3"
    wmove <fx> <fy>         işaretçiyi oraya taşı
    key <ad>                enter, space, escape, tab, left, right, up, down, a..z, 0..9, pageup, pagedown...
    dpad <yön>              up, down, left, right
    text <metin>            odaktaki alana metin yazar
    dark 0 | dark 1         açık ya da koyu mod
  fx/fy'yi koddaki koordinatlardan hesapla (x / pencere genişliği, y / app.json "window" pencere yüksekliği).
  Uygulamanın yüklenmesi için "wait 3" ile başla. En önemli ekranları gerçekçi, kişisel olmayan verilerle göster.
  Bir "dark 1" görüntüsüyle bitir.

Ayrıca öğe klasörü için README.md yaz: "# <Türkçe ad> / <İngilizce ad>", Türkçe ve İngilizce ikişer cümle, bir tablo
(Id, Language, Min SDK, Permissions, Gamepad, Window), bir "Ne öğretir" / özellikler listesi ve bir sürümler tablosu.
```

Sonucu `python SDK/Tools/nxv/nxv.py check <öğe klasörü>` ile denetleyin: beş dili, `kind`, `tags` alanlarını ve her
`shots` adımını doğrular.
