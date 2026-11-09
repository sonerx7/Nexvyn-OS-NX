# BlockCraft



## 1.1.1 güncellemesi

1.1.1: Eski JavaScript SDK mesh nesnelerinde olmayan free() çağrıları kaldırıldı; oturum kapanırken tutulan mesh referansları temizlenir. Voxel menü, tarif kitabı, üretilebilir filtresi, otomatik malzeme yerleştirme, Yaratıcı envanter araması ve grafik profilleri dahil. GPU yalnızca Oyna isteğinde başlatılır. Eski NRO, GPU başlatılmadan uyumluluk mesajıyla durdurulur. Eşlik eden SDK 1.8 NRO, SDL’den ayrı vertex durumu, GPU işlerinin tamamlanmasından sonra kaynak silme, güvenli mesh.free() ve geçersiz geometri indekslerinde silinmiş nesne erişimi düzeltmesi içerir. Ayrı emulator profilinde native güvenlik ve normal/düz dünya aç-kapat-yeniden açma testleri geçti. Fiziksel Switch doğrulaması yapılmadı; önceki QuickJS allocator çökmesinin kesin nedeni henüz yeniden üretilemedi.
