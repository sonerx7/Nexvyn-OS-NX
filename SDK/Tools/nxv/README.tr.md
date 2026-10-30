# nxv

[English](README.md) · **Türkçe**

Nexvyn OS uygulama geliştiricileri için tek dosyalık komut satırı aracı. Python 3.8+ yeter, ek paket gerekmez.
Nexvyn OS kaynak deposunun yolu `--sdk` ile (ya da `NEXVYN_SDK` ortam değişkeniyle) verilirse resmî denetleyicileri,
Java derleyicisini, ikon çiziciyi ve imzalayıcıyı da çağırır.

```
python SDK/Tools/nxv/nxv.py <komut> ...          # bu deponun kökünden
```

## Komutlar

| Komut | Açıklama |
|---|---|
| `new <dil> <ad> [--id ID] [--author AD] [--dir KLASÖR] [--store]` | `SDK/Languages/<dil>/template` şablonunu `<Ad>.nxvapp` olarak kopyalar; `id` (varsayılan `com.<yazar>.<ad>`), ad ve yazarı doldurur. `--store`: Mağaza düzeni `<slug>/source/` + boş `store.json`, `README.md`, `screenshots/`. Diller: `lua`, `js`, `py`, `sq`, `c`, `java`. |
| `check <paket>... [--sdk YOL] [--frames N] [-v]` | `app.json` (kimlik, adlar, sürüm, kategori, çalışma ortamı, `minSdk`, izinler, `shareTargets`, pencere), giriş dosyası, ikon (PNG, 128/256), Java jar'ı ve ana sınıfı, `lang/*.json`, `TR()` anahtarları, kullanılan ama bildirilmeyen izinler, dosya sınırları, ve paket bir `source/` klasörüyse `store.json` (beş dil, `kind`, `tags`, `shots` adımları) ile `README.md` / `screenshots/`. `--sdk` ile dilin resmî denetleyicisini de çalıştırır. |
| `build <paket> --sdk YOL` | Java: `src/**/*.java` → `app.jar`. Diğer diller için derleme yoktur. |
| `pack <paket> [-o ÇIKTI] [--sign ANAHTAR.pem --sdk YOL]` | `Tools/build_store.py` ile aynı, belirlenimci `.nxvapp` (sıralı girdiler, sabit zaman, `manifest.sha256`). Varsayılan çıktı: `MyApp.nxvapp/` için yanındaki `dist/MyApp.nxvapp`, `<öğe>/source/` için `<öğe>/<slug>.nxvapp`. `--sign` kaynak deposunun `nxvapp_pack.py`'sini çağırır. |
| `icon <glif> <üst renk> <alt renk> <çıktı.png> --sdk YOL` | Yerleşik stilde ikon (`make_icon.py`; Pillow ve numpy gerekir). |
| `install <paket> [--sd KÖK] [--autorun]` | SD kart klasörüne kopyalar: varsayılan Ryujinx'inki (`%APPDATA%/Ryujinx/sdcard`, Linux/macOS'ta `~/.config/Ryujinx/sdcard`). `--autorun` açılışta uygulamayı açan `NexvynOS/autorun.txt` yazar; testten sonra silin. |
| `push <paket> --host IP [--port 5000] [--user K --password P] [--remote /NexvynOS/Applications] [--name AD] [--packed] [--dry-run]` | Konsoldaki **Bilgisayara Bağlan** uygulamasının FTP sunucusuna yükler. Varsayılan: klasör `/NexvynOS/Applications/<slug>.nxvapp/` olarak. `--packed`: tek `.nxvapp` dosyası (Nexvyn OS bir sonraki açılışta açar ya da Dosyalar'dan kurulur). FTP erişim alanı "yalnızca ana klasör" ise `--remote` ile yolu verin. `--dry-run` hiçbir yere bağlanmadan listeler. |

Çıkış kodu: 0 başarı, 1 sorun bulundu, 2 yanlış kullanım.

## Örnekler

```
python SDK/Tools/nxv/nxv.py new lua "Su Takibi" --author ayse --store --dir Store/Apps/productivity
python SDK/Tools/nxv/nxv.py check Store/Apps/productivity/su-takibi --sdk ../SnxOS
python SDK/Tools/nxv/nxv.py check SDK/Samples/*/* --sdk ../SnxOS     # tüm örnekler
python SDK/Tools/nxv/nxv.py pack SDK/Samples/c/life -o dist/life.nxvapp
python SDK/Tools/nxv/nxv.py push SDK/Samples/c/life --host 192.168.1.40 --dry-run
python SDK/Tools/nxv/nxv.py install SDK/Samples/squirrel/snake --autorun
```

## Notlar

- `check` her zaman güvenli tarafta kalır: kullanılan izin bildirilmemişse hata, bildirilen ama kullanılmayan izin
  uyarıdır. `"common.ok"` gibi noktalı anahtarlar sistem metni olabileceği için yalnızca uyarıdır; kesin karar `--sdk`
  ile çalışan resmî denetleyicidir.
- FTP şifrelenmez; yalnızca güvendiğiniz ağda kullanın. `push` var olan dosyaların üzerine yazar, uzaktaki fazla
  dosyaları silmez.
- Testler (bu sürüm): `new` (altı dil, `--store`), `check` (24 örnek + 6 şablon, `--sdk` ile ve olmadan), `build`
  (Java), `pack` (belirlenimci, `build_store.py` ile aynı baytlar; `--sign` ve `--verify`), `icon`, `install` (geçici bir SD klasörüne) ve
  `push --dry-run` denendi. Gerçek bir konsola `push` denenmedi.
