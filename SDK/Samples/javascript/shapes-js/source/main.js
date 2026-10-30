// Shapes JS demo: the g3d primitives in JavaScript, textures with mesh.setTexture and asynchronous timers.
//
// What this file teaches:
//   1. ES modules: `import` from another file of the bundle (shapes.js)
//   2. g3d.mesh for every primitive kind, mesh.setTexture(path | null) and mesh.triangles() in JavaScript
//   3. async/await with timer.sleep(seconds): an intro that pops the shapes in one after another,
//      cancelled cleanly when it is started again
//   4. setInterval / clearInterval (milliseconds) to cycle textures, setTimeout for a short bounce
//   5. g3d.project -> [sx, sy, depth] or null, used to put clickable labels (ui.hit) over 3D objects
//   6. JavaScript differences from Lua: 0-based ui.segmented, arrays from multi-value calls
import { KINDS, codeFor } from "./shapes.js";

const TEXTURES = [null, "bundle:/tex/uvgrid.png", "bundle:/tex/stripes.png", "bundle:/tex/dots.png"];
const RING = 3.2;                     // radius of the turntable ring

let shapes = [];                      // { ...kind, mesh, scale, target, focus }
let selected = 2;                     // index into shapes
let texIndex = 1;
let wire = false;
let autoTex = false;
let autoTimer = null;                 // setInterval id
let introRun = 0;                     // increases every time the intro starts
let status = "";
let yaw = 0.4, pitch = 0.38, dist = 9;
let drag = null;
let spin = 0;
let tris = 0;
let floorMesh = null;

// ------------------------------------------------------------------ 2. meshes and textures
app.load = () => {
  shapes = KINDS.map((k) => {
    const mesh = g3d.mesh(k.kind, ...k.args);
    mesh.setColor(k.color);
    return { ...k, mesh, scale: 0, target: 0, focus: 0 };
  });
  floorMesh = g3d.mesh("cylinder", RING + 1.4, 0.2, 64);
  floorMesh.setColor("#2A3048");
  texIndex = store.get("tex", 1);
  wire = store.get("wire", false);
  applyTexture(texIndex);
  setAuto(store.get("auto", false));
  intro();                            // not awaited: it runs over the next frames while the app keeps drawing
};

function applyTexture(i) {
  texIndex = i;
  // null removes the texture: the mesh shows its setColor colour again
  for (const s of shapes) s.mesh.setTexture(TEXTURES[i]);
  store.set("tex", i);
}

// ------------------------------------------------------------------ 3. async intro
async function intro() {
  const run = ++introRun;             // a newer intro makes this one stop at its next await
  status = TR("status_intro");
  for (const s of shapes) s.target = 0;
  await timer.sleep(0.45);
  for (const s of shapes) {
    if (run !== introRun) return;
    s.target = 1;
    audio.tone(330 + shapes.indexOf(s) * 70, 0.09, 0.25, "triangle");
    await timer.sleep(0.16);
  }
  if (run === introRun) status = TR("status_ready");
}

// ------------------------------------------------------------------ 4. setInterval / setTimeout
function setAuto(on) {
  autoTex = on;
  store.set("auto", on);
  if (on && autoTimer === null) {
    autoTimer = setInterval(() => applyTexture((texIndex + 1) % TEXTURES.length), 2500);
  } else if (!on && autoTimer !== null) {
    clearInterval(autoTimer);
    autoTimer = null;
  }
}

function select(i) {
  selected = i;
  const s = shapes[i];
  s.target = 1.35;                                    // bounce up...
  setTimeout(() => { s.target = 1; }, 180);           // ...and settle 180 ms later
  audio.tone(523, 0.08, 0.3, "sine");
}

// ------------------------------------------------------------------ update and input
app.update = (dt) => {
  spin += dt * 0.25;
  for (let i = 0; i < shapes.length; i++) {
    const s = shapes[i];
    s.scale += (s.target - s.scale) * Math.min(1, dt * 10);
    const want = i === selected ? 1 : 0;
    s.focus += (want - s.focus) * Math.min(1, dt * 5);  // 0 = on the ring, 1 = in the middle
  }
  if (!drag) yaw += dt * 0.12;
};

app.event = (e) => {
  if (e.type === "mousedown" && e.button === "left" && e.y < viewHeight) drag = { x: e.x, y: e.y };
  else if (e.type === "mousemove" && drag) {
    yaw -= (e.x - drag.x) * 0.008;
    pitch = Math.max(0.05, Math.min(1.3, pitch + (e.y - drag.y) * 0.006));
    drag = { x: e.x, y: e.y };
  } else if (e.type === "mouseup") drag = null;
  else if (e.type === "pinch") dist = Math.max(4, Math.min(18, dist / e.scale));
  else if (e.type === "scroll" && !e.touch) dist = Math.max(4, Math.min(18, dist * (1 + e.dy * 0.002)));
  else if (e.type === "keydown") {
    if (e.key === "right") select((selected + 1) % shapes.length);
    if (e.key === "left") select((selected + shapes.length - 1) % shapes.length);
    if (e.key === "space") intro();
  }
};

// ------------------------------------------------------------------ drawing
let viewHeight = 0;

function shapePosition(i) {
  const s = shapes[i];
  const a = (i / shapes.length) * Math.PI * 2 + spin;
  const rx = Math.cos(a) * RING, rz = Math.sin(a) * RING;
  const f = s.focus;
  // mix between the ring position and the centre, lifted a little when focused
  return [rx * (1 - f), 0.95 + f * 0.6 + Math.sin(spin * 6 + i) * 0.06, rz * (1 - f)];
}

function draw3d(w, h, t) {
  const cp = Math.cos(pitch);
  g3d.begin(0, 0, w, h, 50, 0.1, 60);
  g3d.camera(Math.sin(yaw) * cp * dist, 1 + Math.sin(pitch) * dist, Math.cos(yaw) * cp * dist, 0, 0.8, 0);
  g3d.light(0.4, 1, 0.6, 0.32);
  g3d.draw(floorMesh, 0, -0.1, 0);
  const labels = [];
  for (let i = 0; i < shapes.length; i++) {
    const s = shapes[i];
    if (s.scale < 0.02) continue;
    const [x, y, z] = shapePosition(i);
    const sc = s.scale * (1 + s.focus * 0.5);
    const flags = (wire ? "wire " : "") + (s.kind === "plane" ? "nocull" : "");
    const tilt = s.kind === "plane" ? 0.9 : 0.35;
    g3d.draw(s.mesh, x, y, z, tilt, t * (0.6 + i * 0.07), 0, sc, sc, sc, null, flags || null);
    const p = g3d.project(x, y + 1.0 * sc, z);       // 5. null when behind the camera
    if (p) labels.push({ i, sx: p[0], sy: p[1] });
  }
  tris = g3d.finish();
  return labels;
}

function drawLabels(labels) {
  for (const L of labels) {
    const s = shapes[L.i];
    const text = TR(s.nameKey);
    const tw = gfx.textWidth(text, 12, "semibold") + 18;
    const x = L.sx - tw / 2, y = L.sy - 13;
    const hit = ui.hit("label" + L.i, x, y, tw, 24);   // a clickable area: the label selects its shape
    if (hit.clicked) select(L.i);
    const on = L.i === selected;
    gfx.rect(x, y, tw, 24, 12, on ? theme.accent : hit.hovered ? "#FFFFFF40" : "#00000090");
    gfx.color("#FFFFFF");
    gfx.text(text, x, y + 5, 12, "semibold", "center", tw);
  }
}

function drawBar(w, h, barH) {
  const y0 = h - barH;
  gfx.rect(0, y0, w, barH, 0, theme.window);
  gfx.rect(0, y0, w, 1, 0, theme.separator);
  const twoRows = barH > 60;
  // 6. ui.segmented is 0-based in JavaScript
  const names = [TR("tex_none"), TR("tex_grid"), TR("tex_stripes"), TR("tex_dots")];
  const segW = Math.min(360, w - 32);
  const ni = ui.segmented("tex", names, texIndex, 16, y0 + 12, segW, 30);
  if (ni !== texIndex) applyTexture(ni);
  const rowY = twoRows ? y0 + 54 : y0 + 12;
  let x = twoRows ? 16 : segW + 32;
  const nw = ui.checkbox(TR("wire"), wire, x, rowY + 6);
  if (nw !== wire) { wire = nw; store.set("wire", wire); }
  x += gfx.textWidth(TR("wire"), 14) + 44;
  const na = ui.checkbox(TR("auto"), autoTex, x, rowY + 6);
  if (na !== autoTex) setAuto(na);
  x += gfx.textWidth(TR("auto"), 14) + 44;
  if (ui.button(TR("intro"), x, rowY, 110, 30, "primary", "play_arrow")) intro();
  // code line of the selected shape, right-aligned when it fits
  const s = shapes[selected];
  const code = codeFor(s) + "  // " + TR("triangles", s.mesh.triangles());
  gfx.color(theme.text2);
  const cx = x + 126;
  if (cx + gfx.textWidth(code, 12, "mono") < w - 12) gfx.text(code, cx, rowY + 8, 12, "mono");
}

app.draw = (w, h) => {
  const t = sys.time();
  const barH = w < 820 ? 100 : 56;
  viewHeight = h - barH;
  gfx.gradient(0, 0, w, viewHeight, "#23283F", "#0C0E18");
  const labels = draw3d(w, viewHeight, t);
  drawLabels(labels);
  gfx.color("#FFFFFFB0");
  gfx.text(status + "  ·  " + TR("stats", tris, Math.round(sys.fps())), 16, 14, 12, "semibold");
  const s = shapes[selected];
  gfx.color("#FFFFFF");
  gfx.text(TR(s.nameKey), 0, 12, 20, "bold", "right", w - 16);
  gfx.color("#FFFFFF99");
  gfx.text(codeFor(s), 0, 38, 12, "mono", "right", w - 16);
  drawBar(w, h, barH);
};

app.menu = () => [{
  title: TR("menu_title"),
  items: [
    { label: TR("intro"), id: 1, shortcut: "Space" },
    { label: TR("wire"), id: 2 },
    { label: TR("auto"), id: 3 },
  ],
}];

app.onmenu = (id) => {
  if (id === 1) intro();
  else if (id === 2) { wire = !wire; store.set("wire", wire); }
  else if (id === 3) setAuto(!autoTex);
};

app.close = () => {
  // the window is closing: stop the interval (the saved "auto" choice stays as it is for next time)
  if (autoTimer !== null) {
    clearInterval(autoTimer);
    autoTimer = null;
  }
  return true;
};
