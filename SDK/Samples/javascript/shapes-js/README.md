# Shapes JS Demo

**English** · [Türkçe](README.tr.md)

The seven g3d primitives on a turntable in JavaScript: textures, wireframe, clickable labels and an intro that runs with async/await.

| | |
|---|---|
| Id | `com.sonerx7.demo.shapes-js` |
| Language | JavaScript |
| Min SDK | 1.1 |
| Permissions | none |
| Gamepad | drives the cursor |
| Window | 900 × 560, resizable |

## What it teaches

- ES modules: `import` from another file of the bundle (shapes.js)
- `g3d.mesh` for every primitive kind, `mesh.setTexture(path | null)` and `mesh.triangles()`
- `async`/`await timer.sleep(sec)`: an intro that pops the shapes in one by one and cancels cleanly when restarted
- `setInterval`/`clearInterval` (milliseconds) to cycle textures, `setTimeout` for a short bounce; cleanup in `app.close`
- `g3d.project` → `[sx, sy, depth]` or `null`; clickable labels over 3D objects with `ui.hit`
- Differences from Lua: 0-based `ui.segmented`, multi-value results as arrays

**APIs used:** `import`, `g3d.mesh`, `mesh.setTexture/setColor/triangles`, `g3d.project`, `timer.sleep`, `setInterval/clearInterval/setTimeout`, `ui.segmented/checkbox/button/hit`, `store`, `audio.tone`

**Controls:** Drag: orbit · wheel or pinch: zoom · tap a label: select · left/right arrows: select · Space: intro.

## Code excerpt

A restartable async intro: every run gets a number, and an older run stops after its next `await`.

```js
async function intro() {
  const run = ++introRun;             // a newer intro makes this one stop at its next await
  for (const s of shapes) s.target = 0;
  await timer.sleep(0.45);
  for (const s of shapes) {
    if (run !== introRun) return;
    s.target = 1;                     // app.update eases s.scale towards s.target
    await timer.sleep(0.16);
  }
}
autoTimer = setInterval(() => applyTexture((texIndex + 1) % TEXTURES.length), 2500);
```

## Running it

Copy the `source/` folder to `sdmc:/NexvynOS/Applications/` as `ShapesJSDemo.nxvapp`, or pack it into one file with `python tools/nxvapp_pack.py`. Files: `main.js` (231 lines), `shapes.js` (16 lines), `app.json`, `lang/en.json`, `lang/tr.json`, `icon.png`, `tex/*.png`.

Check it on a PC (from the root of the Nexvyn OS source repository; `<Nexvyn-OS-NX>` is this repository's folder):

    node tools/js_check.mjs <Nexvyn-OS-NX>/SDK/Samples/javascript/shapes-js/source --frames 900

## Versions

| Version | Change |
|---|---|
| 1.0 | First release. |
