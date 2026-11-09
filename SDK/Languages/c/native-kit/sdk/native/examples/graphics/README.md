# Graphics Power

A native 3D keynote of Nexvyn OS (Store category `showcase`, id `com.nexvyn.demo.graphics`): a cinematic intro, seven chapters
(PBR and sun shadows, dynamic resolution, instant streaming, zero-copy frames, touch and Joy-Con, sound, under the hood), each
with an animated card (what it is, driving library, languages, before -> after numbers from `qa/PERFORMANS.md`), a live HUD
and a benchmark with a local top-ten score list (`scores.txt` in the app data folder, no network).

- Uncapped: the display opens with `NXN_DISPLAY_NO_VSYNC`; the HUD shows the real fps. The render scale only drops below 100% when the
  frame rate falls under 60 (floor guard); the chapter "Dynamic resolution" shows it on purpose. The OS's own `gfx.dynamicRes`
  does not apply to `targetSdk` 1.12.
- Scene: a medieval town kit (your own FBX, never committed). `package.py --fbx KIT.fbx` bakes it, paints the two readable
  inn-sign boards blank in the props texture, caps texture sizes and packs the app (about 43 MB).
- UI text: `lang/*.json` (8 languages, `nxn_tr`). Controls: A / B / D-pad in the menus, any stick = free camera in the chapters, `-` cycles the HUD.
- Test hook: `<data>/script` (see the header of `src/main.cpp`), report in `graphics_report.txt`.
