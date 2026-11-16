# Prepare a portable Game Engine asset pack

Use assets you own or may redistribute. Export runtime-sized GLB models, supported textures and
audio, then create the versioned asset-pack manifest described in [the format guide](GAME_ENGINE_PACKS.md).
The system's internal authoring pipeline is not required to create a conforming pack.

1. Choose only the pieces your game needs. Keep high-resolution source assets outside the runtime
   package. Author clean pivots, consistent units, suitable collisions and useful LODs.
2. Export GLB and prepare shared PNG textures or supported KTX assets; keep external texture paths
   relative to the model's location. Verify actual material/animation support in your target renderer.
3. Place resources under `models/`, `tex/` and `audio/` as appropriate. Add license/source notices
   and a stable pack ID/version. Use ordinary relative paths with no traversal, drive or backslash.
4. Create `manifest.json` with `format: nexvyn-assetpack`, `formatVersion: 1`, complete file entries,
   correct byte sizes, SHA-256 values and `totalSize`. The format guide defines categories/pieces.
5. Use the Game Engine's asset-pack panel to import/verify the folder. Test missing/corrupt files,
   project reopen and removing an optional pack. Required game content should fail with a useful
   message rather than a blank scene.
6. Profile the actual game: visible meshes, draw calls, texture residency, loading and transition
   peaks. The format's maximum limits are safety limits, not recommended memory budgets.

The SDK's texture tools can help prepare materials; your DCC/exporter and optional compression
tools have their own installation requirements. Do not assume a particular internal Blender
script or an owner's source-kit directory exists in a downloaded SDK.

For a game release, include only the selected runtime assets and required notices. Keep pack
updates and game-save migrations separate. Use all eight locales for user-facing pack/product
labels where they appear in your application, and review their layout in the actual editor/game.
