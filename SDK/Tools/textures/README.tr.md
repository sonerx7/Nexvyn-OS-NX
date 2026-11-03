# Doku aracı

[English](README.md) · **Türkçe**

`textures.py`, Nexvyn OS pbr renderer'ı (SDK 1.9) için PBR doku setlerini hazırlar: varlık kitlerinden, doku
üreticilerinden ve 3B programlarından gelen dokular genellikle fazla büyük, başka bir kanal düzeninde ya da DirectX
tarzı normal haritalı olur. Pillow'lu Python 3.8+ (`python -m pip install Pillow`).

```
python textures.py check <klasör>                         doku setleri, boyutlar ve eksik haritalar
python textures.py resize <klasör> [--max 1024]           --max'tan büyük her resmi yerinde küçültür
                                                          (özgünler <klasör>/_originals/ içine)
python textures.py orm <ao|-> <roughness|-> <metallic|-> <çıktı.png>
                                                          glTF ORM paketler: R occlusion, G roughness, B metallic
                                                          ("-" = sabit: AO 1, roughness 0.5, metallic 0)
python textures.py smoothness <MetallicSmoothness.png> <çıktıRoughness.png> [--metallic çıktıMetallic.png]
                                                          R metallic, A smoothness -> roughness = 1 - smoothness
python textures.py flipgreen <normal.png> <çıktı.png>     DirectX normal haritası (yeşil aşağı) -> OpenGL (yeşil yukarı)
```

## Renderer hangi haritaları okur

| Kaynak | Haritalar |
|---|---|
| glTF / `.glb` | dosyadan base color, normal, occlusion'lı metallic-roughness (ORM), emissive |
| `.fbx` | dosyanın bağladığı haritalar; dosya bağlamıyorsa `_AO`, `_Metallic`, `_Roughness` ya da `_MetallicSmoothness` dış base color dosyasının yanında adıyla bulunur (`<Ad>_BaseColor` -> `<Ad>_AO`). Normal ve emissive haritaları dosyada bağlı olmalı |
| Düz mesh'ler | `g3d.material(mesh, {normalMap, metalRoughMap, occlusionMap, metalSmoothMap, emissiveMap, ...})` |

Konsoldaki boyutlar: base color ve normal 1024 px, diğer haritalar 512 px. Her harita tam boyutta yüklenir; göndermeden
önce küçültün. Üretilmiş bir modelden oyuna giden yolun tamamı:
[AI destekli çalışma](../../Guides/AI_WORKFLOW.tr.md).
