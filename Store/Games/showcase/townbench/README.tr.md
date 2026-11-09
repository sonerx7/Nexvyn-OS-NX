# Köy Benchmark

[English](README.md)

Nexvyn OS için bir benchmark. Tamamen dokulu 3B bir köyün üzerinde sabit 60 saniyelik bir kamera yolu izler; ortalama, en düşük ve %1 düşük kare sürelerini, kare hızını ve bir puan gösterir.

- Üç kalite ayarı: Düşük (çizim ölçeği %60, gölge yok, kenar yumuşatma yok), Orta (%80, güneş gölgesi, kenar yumuşatma), Yüksek (%100, güneş gölgesi, kenar yumuşatma).
- Her seferinde aynı yol, sonuçlar karşılaştırılabilir. Kare hızı sınırlanmaz, ses yoktur.
- Puan = (0,7 x ortalama fps + 0,3 x %1 düşük fps) x 10 x ayar ağırlığı (1,0, 1,6, 2,4). Her koşunun ilk saniyesi sayılmaz.
- Her ayarın en iyi puanı cihazda saklanır (`best.txt`); son sonuç uygulamanın veri klasöründe `townbench_result.json` dosyasına da yazılır.
- Pencerede açılır; tam ekran için büyüt. Kontroller: Yukarı / Aşağı seç, A başlat, B çık (koşu sırasında B iptal eder).
- Sahne: kendi script'lerimizle yapılmış bir ortaçağ köyü; zemin ve duvar malzemeleri CC0 fotoğraf tabanlıdır (ambientCG). Ses yok, ağ yok, yalnızca `files` izni.

Paket: `com.nexvyn.demo.townbench.nxvapp` (yaklaşık 43 MB). Kurmak için Nexvyn OS Dosyalar'da aç. Nexvyn OS 1.2.2 (SDK 1.12) gerekir.
