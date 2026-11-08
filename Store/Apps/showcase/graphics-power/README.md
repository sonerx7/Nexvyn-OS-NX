# Graphics Power

Nexvyn OS için grafik teknik demosu: yerel 3B, sinematik giriş, yedi bölüm ve kıyaslama.
A graphics tech demo of Nexvyn OS: native 3D, a cinematic intro, seven chapters and a benchmark.

## Bölümler / Chapters

1. Physically based light: PBR, sun shadow map, shadow cache (NexGFX `ngfx_render`).
2. Dynamic resolution: pixels drop only when the frame rate would fall below 60.
3. Instant streaming: a worker thread reads the scene, the main thread uploads a little per frame.
4. Zero-copy frames: the app's picture reaches the compositor without a copy.
5. Touch and Joy-Con: live controller view (`nxn_input_poll`, `nxn_input_touch`).
6. Sound: notes made with `nxn_tone` over the SDL2-nexvyn mixer.
7. Under the hood: tiled lights, half-resolution buffers, batched draws.

Her kart konsolda ölçülmüş sayıları gösterir (`qa/PERFORMANS.md`). / Every card shows numbers measured on the console.
Kare hızı sınırsızdır; HUD gerçek fps'i gösterir (`-` düğmesi). / The frame rate is uncapped; the HUD shows the real fps (`-` button).
Kıyaslama yerel bir ilk-on puan listesi tutar; ağ yok. / The benchmark keeps a local top ten; no network.

## Kurulum / Install

- **Mağaza / Store:** App Market > Showcase > Graphics Power > Get.

İzin / Permission: `files` (yalnızca puan listesi için / only for the score list).
Gerekenler / Needs: Nexvyn OS 1.2.2 or newer (Native SDK 1.1, `minSdk` 1.10).

## Sürümler / Versions

| Sürüm / Version | Değişiklik / Change |
|---|---|
| 1.0.0 | İlk sürüm. / First release. |
