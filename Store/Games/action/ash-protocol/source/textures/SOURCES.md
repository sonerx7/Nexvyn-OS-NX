# Material sources

Poly Haven, CC0: https://polyhaven.com/license

- Metal Plate — Rob Tuytel: https://polyhaven.com/a/metal_plate
- Hangar Concrete Floor — Dimitrios Savva: https://polyhaven.com/a/hangar_concrete_floor
- Blue Metal Plate — Rob Tuytel: https://polyhaven.com/a/blue_metal_plate

Base-colour/AO derivatives and, since 1.4.0, the normal, roughness and AO maps (textures/pbr) are used in the game. Originals are
kept in art/materials. SDK 1.9 renders those maps with g3d.material;
the basic renderer ignores them and keeps the documented native directional
light and the game's mesh-level light calculations.

Since 1.5.0: `textures/env/c<N>_*.png` (interior reflection probes) and the roughness channel of
`textures/pbr/grain_orm.jpg` are procedural (tools/ash_pbr_assets.py, original, no external source); the original
1.4.0 grain ORM is kept in art/ash_pbr_src.
