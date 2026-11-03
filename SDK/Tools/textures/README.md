# Texture tool

**English** · [Türkçe](README.tr.md)

`textures.py` prepares PBR texture sets for the Nexvyn OS pbr renderer (SDK 1.9): textures from asset kits, texture
generators and 3D programs usually arrive too large, in another channel layout or with -Y (green down) normal maps.
Python 3.8+ with Pillow (`python -m pip install Pillow`).

```
python textures.py check <folder>                         texture sets, sizes and missing maps
python textures.py resize <folder> [--max 1024]           scale every image above --max down in place
                                                          (originals go to <folder>/_originals/)
python textures.py orm <ao|-> <roughness|-> <metallic|-> <out.png>
                                                          pack glTF ORM: R occlusion, G roughness, B metallic
                                                          ("-" = constant: AO 1, roughness 0.5, metallic 0)
python textures.py smoothness <MetallicSmoothness.png> <outRoughness.png> [--metallic outMetallic.png]
                                                          R metallic, A smoothness -> roughness = 1 - smoothness
python textures.py flipgreen <normal.png> <out.png>       -Y normal map (green down) -> +Y (green up)
```

## Which maps the renderer reads

| Source | Maps |
|---|---|
| glTF / `.glb` | base colour, normal, metallic-roughness with occlusion (ORM), emissive, from the file |
| `.fbx` | the maps the file links; when the file does not link them, `_AO`, `_Metallic`, `_Roughness` or `_MetallicSmoothness` by name next to an external base colour file (`<Name>_BaseColor` -> `<Name>_AO`). Normal and emissive maps must be linked in the file |
| Plain meshes | `g3d.material(mesh, {normalMap, metalRoughMap, occlusionMap, metalSmoothMap, emissiveMap, ...})` |

Sizes on the console: base colour and normal 1024 px, the other maps 512 px. Every map is loaded at full size, so
scale them down before you ship. The whole path from a generated model to the game:
[AI-assisted workflow](../../Guides/AI_WORKFLOW.en.md).
