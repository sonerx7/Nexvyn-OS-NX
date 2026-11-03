// Rendering: sky (gradient, round sun and moon, stars), the voxel world (g3d.voxels, SDK 1.7), clouds, entities with
// box models and pixel-art textures, extruded item models, particles, block highlight and cracks, rain and snow,
// lightning, and the first-person hand in its own overlay pass.
import models from "../mobs/models.json";
import masks from "../textures/masks.json";
import { blocks, B, I, MODEL, MODELS, itemDef, isWater, isLava, voxelDef } from "./registry.js";
import { clamp, lerp, smooth, lerp3, scale3, add3, hex3, mulberry32, hash2 } from "./util.js";

const ATLAS = "bundle:/textures/atlas.png", ITEMS = "bundle:/textures/items.png", CRACKS = "bundle:/textures/cracks.png";
const SHADOW = "bundle:/textures/shadow.png";
const T16 = 1 / 16;
// faces: -x, +x, -y, +y, -z, +z; corners [x, y, z, u, v] with v = 1 at the top of the tile (as the voxel mesher)
const FACES = [
  { d: [-1, 0, 0], s: 0.8, c: [[0, 1, 0, 0, 1], [0, 0, 0, 0, 0], [0, 1, 1, 1, 1], [0, 0, 1, 1, 0]] },
  { d: [1, 0, 0], s: 0.8, c: [[1, 1, 1, 0, 1], [1, 0, 1, 0, 0], [1, 1, 0, 1, 1], [1, 0, 0, 1, 0]] },
  { d: [0, -1, 0], s: 0.5, c: [[1, 0, 1, 1, 0], [0, 0, 1, 0, 0], [1, 0, 0, 1, 1], [0, 0, 0, 0, 1]] },
  { d: [0, 1, 0], s: 1.0, c: [[0, 1, 1, 1, 1], [1, 1, 1, 0, 1], [0, 1, 0, 1, 0], [1, 1, 0, 0, 0]] },
  { d: [0, 0, -1], s: 0.6, c: [[1, 0, 0, 0, 0], [0, 0, 0, 1, 0], [1, 1, 0, 0, 1], [0, 1, 0, 1, 1]] },
  { d: [0, 0, 1], s: 0.6, c: [[0, 0, 1, 0, 0], [1, 0, 1, 1, 0], [0, 1, 1, 0, 1], [1, 1, 1, 1, 1]] },
];
const FLAT_MODELS = new Set([MODELS.cross, MODELS.torch, MODELS.crop, MODELS.fire, MODELS.ladder, MODELS.door]);
const TINT_CACHE = new Map();
const gray = k => { const v = clamp(Math.round(k * 255), 0, 255); let s = TINT_CACHE.get(v); if (!s) { s = hex3([v / 255, v / 255, v / 255]); TINT_CACHE.set(v, s); } return s; };

// ---------------------------------------------------------------- tiny mat4 (column-major) for the mob rigs
const M = {
  ident() { return [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]; },
  mul(a, b) {
    const r = new Array(16);
    for (let c = 0; c < 4; c++) for (let rr = 0; rr < 4; rr++) {
      r[c * 4 + rr] = a[rr] * b[c * 4] + a[4 + rr] * b[c * 4 + 1] + a[8 + rr] * b[c * 4 + 2] + a[12 + rr] * b[c * 4 + 3];
    }
    return r;
  },
  t(x, y, z) { return [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, x, y, z, 1]; },
  s(k) { return [k, 0, 0, 0, 0, k, 0, 0, 0, 0, k, 0, 0, 0, 0, 1]; },
  rx(a) { const c = Math.cos(a), s = Math.sin(a); return [1, 0, 0, 0, 0, c, s, 0, 0, -s, c, 0, 0, 0, 0, 1]; },
  ry(a) { const c = Math.cos(a), s = Math.sin(a); return [c, 0, -s, 0, 0, 1, 0, 0, s, 0, c, 0, 0, 0, 0, 1]; },
  rz(a) { const c = Math.cos(a), s = Math.sin(a); return [c, s, 0, 0, -s, c, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]; },
  // Euler XYZ (three.js default order): Rx * Ry * Rz
  xyz(x, y, z) { return M.mul(M.mul(M.rx(x), M.ry(y)), M.rz(z)); },
};
// g3d.draw's rotation is rotY(ry) * rotX(rx) * rotZ(rz): decompose a rotation(+uniform scale) matrix into it
function toG3d(m) {
  const s = Math.hypot(m[0], m[1], m[2]) || 1;
  const r12 = m[9] / s;
  let rx, ry, rz;
  if (Math.abs(r12) < 0.9999) {
    rx = Math.asin(-r12);
    ry = Math.atan2(m[8] / s, m[10] / s);
    rz = Math.atan2(m[1] / s, m[5] / s);
  } else {
    rx = r12 < 0 ? Math.PI / 2 : -Math.PI / 2;
    rz = 0;
    ry = Math.atan2(-m[2] / s, m[0] / s);
  }
  return [m[12], m[13], m[14], rx, ry, rz, s];
}

export class Renderer {
  constructor(game) {
    this.game = game;
    this.cubes = new Map();      // block id -> textured cube mesh
    this.sprites = new Map();    // "i<id>" / "t<tile>" -> extruded sprite mesh
    this.tileBits = new Map();   // block id -> particle mesh
    this.mobParts = new Map();   // type -> [{part, mesh}]
    this.particles = new Particles(this);
    this.hand = { swingT: 1, swinging: false, eq: 0, lastId: -2, swing: (cont) => { if (cont && this.hand.swingT < 1) return; this.hand.swingT = 0; } };
    this.highlight = null;
    this.crack = null; this.crackStage = -1;
    this.daylight = 1;
    this.env = null;
    this.cam = { x: 0, y: 80, z: 0, yaw: 0, pitch: 0, roll: 0, fov: 70, fx: 0, fy: 0, fz: -1 };
    try {
    this.cracks = [];
    for (let k = 0; k < 10; k++) this.cracks.push(this.cubeMesh(() => [k, 0, 1 / 10, 1], CRACKS, 1.006));
    this.unit = g3d.mesh("cube", 1);
    this.shadow = g3d.custom([-0.5, 0, -0.5, 0.5, 0, -0.5, 0.5, 0, 0.5, -0.5, 0, 0.5], [0, 2, 1, 0, 3, 2], null, true, [0, 0, 1, 0, 1, 1, 0, 1]);
    this.shadow.setTexture(SHADOW, true);
    this.arrowMesh = g3d.mesh("box", 0.06, 0.06, 0.55);
    this.arrowMesh.setColor("#8B6A3C");
    this.buildClouds();
    this.stars = [];
    const rnd = mulberry32(1234);
    for (let i = 0; i < 260; i++) {
      const u = rnd() * 2 - 1, a = rnd() * Math.PI * 2, r = Math.sqrt(1 - u * u);
      this.stars.push([r * Math.cos(a), u, r * Math.sin(a), 0.5 + rnd() * 1.4, rnd()]);
    }
    this.rainCols = [];
    } catch (e) { this.dispose(); throw e; }
  }

  dispose() {
    if (this.disposed) return;
    this.disposed = true;
    const handles = new Set([this.unit, this.shadow, this.arrowMesh, this.clouds, ...(this.cracks || [])]);
    for (const cache of [this.cubes, this.sprites, this.tileBits]) {
      if (cache) { for (const m of cache.values()) handles.add(m); cache.clear(); }
    }
    if (this.mobParts) { for (const parts of this.mobParts.values()) for (const part of parts) handles.add(part.mesh); this.mobParts.clear(); }
    for (const m of handles) if (m) { try { m.free(); } catch (e) { console.log("mesh cleanup: " + e); } }
    if (this.particles) this.particles.list.length = 0;
  }

  // ---------------------------------------------------------------- meshes
  // A unit cube centred on the origin, every face mapped to cell (col, row) of a tiles-wide atlas.
  cubeMesh(cellOf, tex, size = 1, colors = false) {
    const pos = [], uv = [], idx = [], col = colors ? [] : null;
    const h = size / 2;
    for (let f = 0; f < 6; f++) {
      const F = FACES[f];
      const cell = cellOf(f);
      if (!cell) continue;
      const [cx, cy, cw, ch] = cell;
      const b = pos.length / 3;
      for (const c of F.c) {
        pos.push((c[0] - 0.5) * size, (c[1] - 0.5) * size, (c[2] - 0.5) * size);
        uv.push((cx + 0.001 + c[3] * 0.998) * cw, (cy + 0.001 + (1 - c[4]) * 0.998) * ch);
        if (col) { const v = Math.round(F.s * 255); col.push([v, v, v, 255]); }
      }
      idx.push(b, b + 1, b + 2, b + 2, b + 1, b + 3);
    }
    void h;
    const m = g3d.custom(pos, idx, col, true, uv);
    m.setTexture(tex, true);
    return m;
  }

  blockCube(id) {
    let m = this.cubes.get(id);
    if (!m) {
      const d = voxelDef(blocks[id]);
      const tex = Array.isArray(d.tex) ? d.tex : [d.tex, d.tex, d.tex, d.tex, d.tex, d.tex];
      m = this.cubeMesh(f => (tex[f] === 255 ? null : [tex[f] % 16, Math.floor(tex[f] / 16), T16, T16]), ATLAS, 1, true);
      this.cubes.set(id, m);
    }
    return m;
  }

  // Extruded 16x16 sprite: front and back faces with the whole picture (alpha cut out) plus one thin side face per
  // pixel edge, so held and dropped items look solid.
  spriteMesh(key, tex, col, row, maskHex) {
    let m = this.sprites.get(key);
    if (m) return m;
    const bits = [];
    for (let y = 0; y < 16; y++) bits.push(parseInt((maskHex || "").substr(y * 4, 4) || "0", 16));
    const on = (x, y) => x >= 0 && y >= 0 && x < 16 && y < 16 && (bits[y] >> x) & 1;
    const pos = [], uv = [], idx = [], cols = [];
    const t = T16 / 2;
    const u0 = col / 16, v0 = row / 16;
    const quad = (p, q, shade) => {
      const b = pos.length / 3;
      for (let k = 0; k < 4; k++) { pos.push(p[k][0], p[k][1], p[k][2]); uv.push(q[k][0], q[k][1]); const v = Math.round(shade * 255); cols.push([v, v, v, 255]); }
      idx.push(b, b + 1, b + 2, b, b + 2, b + 3);
    };
    const X = x => x / 16 - 0.5, Y = y => 0.5 - y / 16;
    const U = x => u0 + x / 256, V = y => v0 + y / 256;
    quad([[X(0), Y(16), t], [X(16), Y(16), t], [X(16), Y(0), t], [X(0), Y(0), t]], [[U(0), V(16)], [U(16), V(16)], [U(16), V(0)], [U(0), V(0)]], 1);
    quad([[X(16), Y(16), -t], [X(0), Y(16), -t], [X(0), Y(0), -t], [X(16), Y(0), -t]], [[U(16), V(16)], [U(0), V(16)], [U(0), V(0)], [U(16), V(0)]], 0.75);
    for (let y = 0; y < 16; y++) for (let x = 0; x < 16; x++) {
      if (!on(x, y)) continue;
      const pu = U(x + 0.5), pv = V(y + 0.5), q = [[pu, pv], [pu, pv], [pu, pv], [pu, pv]];
      if (!on(x, y - 1)) quad([[X(x), Y(y), t], [X(x + 1), Y(y), t], [X(x + 1), Y(y), -t], [X(x), Y(y), -t]], q, 1);
      if (!on(x, y + 1)) quad([[X(x), Y(y + 1), -t], [X(x + 1), Y(y + 1), -t], [X(x + 1), Y(y + 1), t], [X(x), Y(y + 1), t]], q, 0.55);
      if (!on(x - 1, y)) quad([[X(x), Y(y + 1), -t], [X(x), Y(y + 1), t], [X(x), Y(y), t], [X(x), Y(y), -t]], q, 0.7);
      if (!on(x + 1, y)) quad([[X(x + 1), Y(y + 1), t], [X(x + 1), Y(y + 1), -t], [X(x + 1), Y(y), -t], [X(x + 1), Y(y), t]], q, 0.7);
    }
    m = g3d.custom(pos, idx, cols, true, uv);
    m.setTexture(tex, true);
    this.sprites.set(key, m);
    return m;
  }

  // the mesh of an inventory item (block cube or extruded sprite) and whether it is a cube
  itemMesh(id) {
    if (id < 256) {
      const d = blocks[id];
      if (!d) return [null, false];
      if (FLAT_MODELS.has(MODEL[id]) || d.model === "bed") {
        const tile = d.t.side;
        return [this.spriteMesh("t" + tile, ATLAS, tile % 16, Math.floor(tile / 16), masks.tiles[tile]), false];
      }
      return [this.blockCube(id), true];
    }
    const cell = id - 256;
    return [this.spriteMesh("i" + cell, ITEMS, cell % 16, Math.floor(cell / 16), masks.items[cell]), false];
  }

  particleMesh(id) {
    let m = this.tileBits.get(id);
    if (!m) {
      const d = blocks[id];
      const tile = d && d.t ? d.t.side : 0;
      const cx = tile % 16, cy = Math.floor(tile / 16);
      m = this.cubeMesh(() => [cx * 4 + 1 + (id % 2), cy * 4 + 1, 1 / 64, 1 / 64], ATLAS);
      this.tileBits.set(id, m);
    }
    return m;
  }

  mobMeshes(type) {
    let list = this.mobParts.get(type);
    if (list) return list;
    const spec = models[type];
    list = [];
    if (spec) {
      for (const p of spec.parts) {
        const mesh = g3d.custom(p.verts, p.idx, null, true, p.uvs);
        mesh.setTexture(`bundle:/mobs/${type}.png`, true);
        list.push({ p, mesh });
      }
    }
    this.mobParts.set(type, list);
    return list;
  }

  buildClouds() {
    // flat cloud layer: 32 x 32 cells of 12 blocks, 4 blocks thick, merged into one mesh
    const N = 32, C = 12, H = 4;
    const cell = (x, z) => {
      x = ((x % N) + N) % N; z = ((z % N) + N) % N;
      const v = hash2(x >> 1, z >> 1, 77) * 0.55 + hash2(x, z, 91) * 0.45;
      return v > 0.6;
    };
    const pos = [], idx = [], col = [];
    const quad = (pts, c) => {
      const b = pos.length / 3;
      for (const p of pts) { pos.push(p[0], p[1], p[2]); col.push(c); }
      idx.push(b, b + 1, b + 2, b, b + 2, b + 3);
    };
    const top = [255, 255, 255, 205], side = [232, 236, 242, 205], bot = [205, 210, 218, 205];
    for (let z = 0; z < N; z++) for (let x = 0; x < N; x++) {
      if (!cell(x, z)) continue;
      const x0 = x * C, x1 = x0 + C, z0 = z * C, z1 = z0 + C;
      quad([[x0, H, z0], [x0, H, z1], [x1, H, z1], [x1, H, z0]], top);
      quad([[x0, 0, z0], [x1, 0, z0], [x1, 0, z1], [x0, 0, z1]], bot);
      if (!cell(x - 1, z)) quad([[x0, 0, z0], [x0, 0, z1], [x0, H, z1], [x0, H, z0]], side);
      if (!cell(x + 1, z)) quad([[x1, 0, z1], [x1, 0, z0], [x1, H, z0], [x1, H, z1]], side);
      if (!cell(x, z - 1)) quad([[x1, 0, z0], [x0, 0, z0], [x0, H, z0], [x1, H, z0]], side);
      if (!cell(x, z + 1)) quad([[x0, 0, z1], [x1, 0, z1], [x1, H, z1], [x0, H, z1]], side);
    }
    this.clouds = g3d.custom(pos, idx, col, true);
    this.cloudSize = N * C;
  }

  // ---------------------------------------------------------------- hooks used by the game logic
  setHighlight(t) { this.highlight = t; }
  setCrack(b, stage) { this.crack = b; this.crackStage = stage; }

  // ---------------------------------------------------------------- environment: sky, fog and light colours
  updateEnvironment(t, o) {
    const a = t * Math.PI * 2;
    const sunH = Math.sin(a);
    const dayK = smooth(-0.25, 0.3, sunH);
    const wet = o.rain || 0, storm = o.thunder || 0, flash = o.flash || 0;
    const dusk = Math.exp(-(((sunH - 0.02) / 0.17) ** 2)) * (1 - 0.8 * wet);
    this.daylight = 0.25 + 0.75 * smooth(-0.12, 0.25, sunH) * (1 - 0.32 * wet - 0.22 * storm) + flash * 0.5;
    const overcast = (c, grey) => lerp3(c, scale3(grey, 0.15 + 0.85 * dayK * (1 - 0.35 * storm)), wet * 0.8);
    let top = lerp3([0.005, 0.01, 0.04], [0.42, 0.62, 1.0], dayK);
    let hor = lerp3(lerp3([0.02, 0.03, 0.08], [0.72, 0.84, 1.0], dayK), [0.98, 0.55, 0.3], dusk * 0.55);
    top = overcast(top, [0.46, 0.49, 0.54]); hor = overcast(hor, [0.6, 0.63, 0.67]);
    top = add3(top, scale3([0.5, 0.5, 0.6], flash)); hor = add3(hor, scale3([0.5, 0.5, 0.6], flash));
    let tint = lerp3([0.62, 0.72, 1.0], [1, 1, 1], dayK);
    tint = lerp3(tint, [1.0, 0.82, 0.68], dusk * 0.35);
    tint = add3(scale3(tint, 1 - 0.2 * wet), scale3([0.8, 0.8, 1], flash));
    const cl = lerp3(lerp3([0.18, 0.2, 0.28], [1, 1, 1], dayK), [0.5, 0.52, 0.56], wet * 0.75);
    const rd = o.renderDistance * 16;
    let fog = hor, near = rd * 0.55 * (1 - 0.4 * wet), far = rd * 0.92 * (1 - 0.25 * wet);
    if (o.underwater) { const k = this.daylight; fog = [0.06 * k + 0.01, 0.16 * k + 0.02, 0.42 * k + 0.04]; near = 1; far = 18; }
    else if (o.inLava) { fog = [0.6, 0.15, 0.02]; near = 0; far = 3; }
    this.env = {
      t, sunH, dayK, dusk, top, hor, tint, cloud: lerp3(cl, [1, 0.8, 0.7], dusk * 0.4), fog, near, far, wet,
      sunDir: [Math.cos(a), sunH, 0.18], stars: (1 - dayK) * (1 - wet), glow: dusk,
    };
  }

  // ---------------------------------------------------------------- frame
  draw(w, h) {
    const g = this.game, p = g.player, s = g.settings, e = this.env;
    if (!e) return;
    const cam = this.cam;
    const cp = Math.cos(cam.pitch);
    const fx = -Math.sin(cam.yaw) * cp, fy = Math.sin(cam.pitch), fz = -Math.cos(cam.yaw) * cp;
    cam.fx = fx; cam.fy = fy; cam.fz = fz;
    const far = Math.max(96, s.renderDistance * 16 + 48);
    // roll: rotate the up vector around the view direction
    const rx = Math.cos(cam.yaw), rz = -Math.sin(cam.yaw);
    const ux = -Math.sin(cam.roll) * rx, uy = Math.cos(cam.roll), uz = -Math.sin(cam.roll) * rz;
    g3d.begin(0, 0, w, h, cam.fov, 0.06, far);
    g3d.camera(cam.x, cam.y, cam.z, cam.x + fx, cam.y + fy, cam.z + fz, ux, uy, uz);
    this.drawSky(w, h, cam);

    g3d.fog(hex3(e.fog), e.near, e.far);
    const sd = e.sunDir, sl = Math.hypot(sd[0], sd[1], sd[2]);
    const sunUp = e.sunH > -0.05;
    g3d.light(sunUp ? sd[0] / sl : -sd[0] / sl, Math.abs(sd[1]) / sl + 0.2, sd[2] / sl, 0.45 + 0.25 * e.dayK, "#FFFFFF");
    g.world.v.environment({
      daylight: this.daylight, skyTint: hex3(e.tint), time: g.clock, wave: s.waving, sun: sunUp ? sd : [-sd[0], -sd[1], -sd[2]],
      skyTop: hex3(e.top), skyHorizon: hex3(e.hor), blockLight: "#FFDBAD", minLight: 0.035,
    });
    g.world.v.draw();
    this.drawClouds(cam, e, g);
    g.entities.draw(this);
    if (g.cameraMode !== 0 && !p.dead) this.drawPlayer();
    this.particles.draw(cam);
    this.drawHighlight();
    this.drawWeather(cam, g);
    g3d.finish();

    // first-person hand in its own pass (never clips into walls)
    if (g.cameraMode === 0 && !p.dead && !p.sleeping && !g.hud.hidden) {
      g3d.begin(0, 0, w, h, 70, 0.02, 10);
      g3d.camera(0, 0, 0, 0, 0, -1);
      g3d.light(0.3, 0.8, 0.5, 0.5, "#FFFFFF");
      this.drawHand();
      g3d.finish();
    }
    // screen tints
    if (e.near < 2 && e.far < 20) { gfx.color(e.far < 5 ? "#C83A0A88" : "#1A3A8A55"); gfx.rect(0, 0, w, h); }
    if (p.hurtTime > 0) { gfx.alpha(clamp(p.hurtTime / 0.35, 0, 1) * 0.35); gfx.color("#C00000"); gfx.rect(0, 0, w, h); gfx.unalpha(); }
    if (p.fireTime > 0 && !p.creative) this.drawFireOverlay(w, h);
    if (p.spores > 0) {
      const a = Math.min(1, p.spores / 1.5) * (0.16 + 0.05 * Math.sin(g.clock * 5));
      gfx.alpha(a); gfx.color("#6FD8A8"); gfx.rect(0, 0, w, h); gfx.unalpha();
      gfx.alpha(a * 1.6); gfx.color("#5A3A7A");
      const e = Math.min(w, h) * 0.08;
      gfx.rect(0, 0, w, e); gfx.rect(0, h - e, w, e); gfx.rect(0, e, e, h - 2 * e); gfx.rect(w - e, e, e, h - 2 * e);
      gfx.unalpha();
    }
  }

  // title screen background: just sky, terrain and clouds
  drawPanorama(w, h) {
    const g = this.game, e = this.env, cam = this.cam;
    if (!e) return;
    const cp = Math.cos(cam.pitch);
    cam.fx = -Math.sin(cam.yaw) * cp; cam.fy = Math.sin(cam.pitch); cam.fz = -Math.cos(cam.yaw) * cp;
    g3d.begin(0, 0, w, h, cam.fov, 0.1, 120);
    g3d.camera(cam.x, cam.y, cam.z, cam.x + cam.fx, cam.y + cam.fy, cam.z + cam.fz);
    this.drawSky(w, h, cam);
    g3d.fog(hex3(e.fog), e.near, e.far);
    g.world.v.environment({ daylight: this.daylight, skyTint: hex3(e.tint), time: g.clock, wave: true, sun: e.sunDir, skyTop: hex3(e.top), skyHorizon: hex3(e.hor) });
    g.world.v.draw();
    this.drawClouds(cam, e, g);
    g3d.finish();
  }

  brightnessAt(x, y, z) {
    const l = this.game.world.getLight(Math.floor(x), Math.floor(y), Math.floor(z));
    const curve = v => { const c = v / (4 - 3 * v); return lerp(c, v, 0.35); };
    return Math.max(curve((l >> 4) / 15) * this.daylight, curve((l & 15) / 15) * 0.95, 0.08);
  }

  drawSky(w, h, cam) {
    const e = this.env;
    const tanH = Math.tan((cam.fov * Math.PI) / 360);
    // screen y of a sky elevation angle (radians)
    const yOf = el => h / 2 - (Math.tan(clamp(el - cam.pitch, -1.45, 1.45)) / tanH) * (h / 2);
    const yH = yOf(0), y40 = yOf(0.7);
    const topC = hex3(e.top), horC = hex3(e.hor);
    gfx.color(topC);
    if (y40 > 0) gfx.rect(0, 0, w, Math.min(h, y40));
    if (yH > 0 && y40 < h) gfx.gradient(0, Math.max(-h, y40), w, Math.min(2 * h, yH) - Math.max(-h, y40), topC, horC);
    gfx.color(horC);
    if (yH < h) gfx.rect(0, Math.max(0, yH), w, h - Math.max(0, yH));
    // dusk glow around the sun on the horizon
    const sd = e.sunDir;
    const sp = g3d.project(cam.x + sd[0] * 300, cam.y + sd[1] * 300, cam.z + sd[2] * 300);
    if (e.glow > 0.05) {
      const gx = sp ? sp[0] : null;
      if (gx !== null) {
        gfx.color("#FF8A40");
        gfx.alpha(e.glow * 0.3); gfx.circle(gx, yH, h * 0.45); gfx.unalpha();
        gfx.alpha(e.glow * 0.35); gfx.circle(gx, yH, h * 0.22); gfx.unalpha();
      }
    }
    // stars (they turn with the sky)
    if (e.stars > 0.02) {
      const a = e.t * Math.PI * 2, ca = Math.cos(a), sa = Math.sin(a);
      gfx.color("#FFFFFF");
      for (const st of this.stars) {
        const x = st[0] * ca - st[1] * sa, y = st[0] * sa + st[1] * ca, z = st[2];
        if (y < 0.05) continue;
        const q = g3d.project(cam.x + x * 300, cam.y + y * 300, cam.z + z * 300);
        if (!q || q[0] < 0 || q[1] < 0 || q[0] > w || q[1] > h) continue;
        const tw = 0.7 + 0.3 * Math.sin(this.game.clock * 3 + st[4] * 40);
        gfx.alpha(e.stars * tw * clamp(y * 3, 0, 1));
        gfx.rect(q[0], q[1], st[3], st[3]);
        gfx.unalpha();
      }
    }
    // round sun with a soft halo, round moon with a few craters
    const wet = 1 - e.wet;
    if (sp && sd[1] > -0.1 && wet > 0.05) {
      const r = h * 0.045;
      gfx.color("#FFE9A8");
      gfx.alpha(wet * 0.12); gfx.circle(sp[0], sp[1], r * 3.2); gfx.unalpha();
      gfx.alpha(wet * 0.22); gfx.circle(sp[0], sp[1], r * 1.9); gfx.unalpha();
      gfx.alpha(wet); gfx.color("#FFF8DC"); gfx.circle(sp[0], sp[1], r); gfx.unalpha();
    }
    const mp = g3d.project(cam.x - sd[0] * 300, cam.y - sd[1] * 300, cam.z - sd[2] * 300);
    if (mp && -sd[1] > -0.1 && wet > 0.05) {
      const r = h * 0.032;
      gfx.alpha(wet * 0.14); gfx.color("#C8D4F0"); gfx.circle(mp[0], mp[1], r * 2.2); gfx.unalpha();
      gfx.alpha(wet * 0.95); gfx.color("#E6EBF5"); gfx.circle(mp[0], mp[1], r);
      gfx.color("#C4CBDA"); gfx.circle(mp[0] - r * 0.3, mp[1] - r * 0.2, r * 0.26); gfx.circle(mp[0] + r * 0.35, mp[1] + r * 0.3, r * 0.2);
      gfx.circle(mp[0] + r * 0.15, mp[1] - r * 0.45, r * 0.13);
      gfx.unalpha();
    }
  }

  drawClouds(cam, e, g) {
    if (!g.settings.clouds) return;
    const S = this.cloudSize, y = 116;
    const off = g.clock * 0.9;
    const bx = Math.floor((cam.x - off) / S) * S + off, bz = Math.floor(cam.z / S) * S;
    const c = hex3(e.cloud, 0.82);
    for (let dz = -1; dz <= 0; dz++) for (let dx = -1; dx <= 0; dx++) {
      const ox = bx + (dx + ((cam.x - bx) > S / 2 ? 1 : 0)) * S, oz = bz + (dz + ((cam.z - bz) > S / 2 ? 1 : 0)) * S;
      g3d.draw(this.clouds, ox, y, oz, 0, 0, 0, 1, 1, 1, c, "unlit");
    }
  }

  // ---------------------------------------------------------------- entities
  drawItem(id, x, y, z, yaw, pitch, size) {
    const [m, cube] = this.itemMesh(id);
    if (!m) return;
    const k = this.brightnessAt(x, y + 0.2, z);
    const s = cube ? size : size * 1.6;
    g3d.draw(m, x, y + (cube ? size * 0.5 : size * 0.8), z, pitch, yaw, 0, s, s, s, gray(k));
    this.drawShadow(x, y - 0.12, z, 0.35, 0.5);
  }

  drawBlockCube(id, x, y, z, size, flashColor) {
    const k = this.brightnessAt(x, y, z);
    g3d.draw(this.blockCube(id), x, y, z, 0, 0, 0, size, size, size, flashColor || gray(k), flashColor ? "unlit" : undefined);
  }

  drawArrow(x, y, z, yaw, pitch) {
    const k = this.brightnessAt(x, y, z);
    g3d.draw(this.arrowMesh, x, y, z, pitch, yaw, 0, 1, 1, 1, gray(k));
  }

  drawShadow(x, y, z, r, alpha) {
    const w = this.game.world;
    const by = Math.floor(y);
    let gy = -1;
    for (let k = 0; k < 4; k++) if (w.collides(Math.floor(x), by - k, Math.floor(z))) { gy = by - k + 1; break; }
    if (gy < 0) return;
    const a = alpha * clamp(1 - (y - gy) / 4, 0, 1) * (0.4 + 0.6 * this.daylight);
    if (a < 0.03) return;
    g3d.draw(this.shadow, x, gy + 0.015, z, 0, 0, 0, r * 2, 1, r * 2, "#000000" + Math.round(a * 140).toString(16).padStart(2, "0"), "unlit");
  }

  drawMob(mob) {
    const parts = this.mobMeshes(mob.type);
    if (!parts.length) return;
    const k = this.brightnessAt(mob.pos.x, mob.pos.y + mob.h * 0.7, mob.pos.z);
    const hurt = mob.hurtTime > 0 || mob.death >= 0;
    const tint = hurt ? hex3([k, k * 0.45, k * 0.45]) : gray(k);
    this.drawRig(mob.type, parts, mob.pos, mob.yaw, mob.scale, mob.anim, tint);
    if (mob.death < 0) this.drawShadow(mob.pos.x, mob.pos.y, mob.pos.z, mob.hw * 1.3, 0.55);
  }

  drawRig(type, parts, pos, yaw, scale, s, tint, flags) {
    const humanoid = type === "zombie" || type === "skeleton" || type === "player";
    const forward = type === "zombie" || type === "skeleton";
    const sw = Math.sin(s.walk) * 0.9 * s.amount;
    const swell = 1 + (s.swell || 0) * 0.2;
    let root = M.mul(M.t(pos.x, pos.y, pos.z), M.ry(yaw));
    root = M.mul(root, M.s(scale * swell));
    if (s.death > 0) root = M.mul(root, M.rz(Math.min(1, s.death / 0.6) * Math.PI / 2));
    const frames = {};
    for (const { p, mesh } of parts) {
      if (p.optional) continue;
      let rx = 0, ry = 0, rz = 0;
      const nm = p.name;
      if (nm === "leg1" || nm === "leg2") rx = sw;
      if (nm === "leg0" || nm === "leg3") rx = -sw;
      if (humanoid && nm.startsWith("arm")) {
        const side = nm === "arm1" ? 1 : 0;
        rx = forward ? -Math.PI / 2 + Math.sin(s.walk * 0.5 + side) * 0.05 : (side ? -sw : sw) * 0.8;
        if (s.aim) rx = -Math.PI / 2 - 0.1;
        if (s.attack > 0) rx -= Math.sin(s.attack * Math.PI) * 0.6;
        if (s.swing > 0 && side === 0) rx -= Math.sin(s.swing * Math.PI) * 1.2;
        rz = (side ? 1 : -1) * 0.05;
      }
      if (nm.startsWith("wing")) rz = (nm === "wing1" ? 1 : -1) * (s.flap ? Math.abs(Math.sin(s.walk * 4)) * 1.1 : 0);
      if (nm === "head") { ry = s.headYaw || 0; rx = -(s.headPitch || 0); }
      const parent = p.parent ? frames[p.parent] : root;
      const frame = M.mul(M.mul(M.mul(parent || root, M.t(p.pivot[0], p.pivot[1], p.pivot[2])), M.xyz(rx, ry, rz)), M.xyz(p.rot[0], p.rot[1], p.rot[2]));
      frames[nm] = frame;
      const m = M.mul(frame, M.t(p.at[0], p.at[1], p.at[2]));
      const d = toG3d(m);
      // glowing parts (the Puffcap's spots and eyes) ignore the light and pulse with anim.glow
      if (p.glow) g3d.draw(mesh, d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[6], d[6], gray(clamp(s.glow ?? 1, 0, 1)), "unlit glow");
      else g3d.draw(mesh, d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[6], d[6], tint, flags);
    }
  }

  drawPlayer() {
    const g = this.game, p = g.player;
    const parts = this.mobMeshes("player");
    const k = this.brightnessAt(p.pos.x, p.pos.y + 1.2, p.pos.z);
    const look = p.yaw + Math.PI;
    const moving = Math.hypot(p.vel.x, p.vel.z) > 0.5;
    if (this.bodyYaw === undefined) this.bodyYaw = look;
    let d = look - this.bodyYaw; d = Math.atan2(Math.sin(d), Math.cos(d));
    if (moving) this.bodyYaw += d * 0.25; else if (Math.abs(d) > 0.85) this.bodyYaw += d - Math.sign(d) * 0.85;
    let hd = look - this.bodyYaw; hd = Math.atan2(Math.sin(hd), Math.cos(hd));
    const anim = { walk: p.walkDist * 2.6, amount: p.bobAmount, headYaw: clamp(hd, -1.2, 1.2), headPitch: p.pitch, death: -1, swing: this.hand.swingT < 1 ? this.hand.swingT : 0 };
    this.drawRig("player", parts, { x: p.pos.x, y: p.pos.y + (p.sneaking ? -0.1 : 0), z: p.pos.z }, this.bodyYaw, 1, anim, p.hurtTime > 0 ? hex3([k, k * 0.45, k * 0.45]) : gray(k));
    this.drawShadow(p.pos.x, p.pos.y, p.pos.z, 0.4, 0.55);
  }

  drawHand() {
    const g = this.game, p = g.player, held = g.inventory.held, hd = this.hand;
    const id = held ? held.id : -1;
    if (id !== hd.lastId) { hd.eq = 0; hd.lastId = id; }
    hd.eq = Math.min(1, hd.eq + 0.12);
    const sw = hd.swingT < 1 ? Math.sin(hd.swingT * Math.PI) : 0;
    const sw2 = hd.swingT < 1 ? Math.sin(Math.sqrt(hd.swingT) * Math.PI) : 0;
    const bob = g.settings.viewBobbing ? p.bobAmount : 0;
    const wb = p.walkDist * Math.PI;
    const bx = Math.sin(wb) * 0.025 * bob, by = -Math.abs(Math.cos(wb)) * 0.03 * bob;
    const k = this.brightnessAt(p.pos.x, p.eyeY, p.pos.z);
    const tint = gray(k);
    const eat = g.interaction.eatProgress;
    const eatBob = eat > 0 ? Math.abs(Math.sin(eat * 18)) * 0.03 : 0;
    const lower = (1 - hd.eq) * 0.4;
    if (id < 0) {
      // bare arm from the player model
      const parts = this.mobMeshes("player");
      const arm = parts.find(q => q.p.name === "arm1");
      // shoulder off screen at the bottom right, the hand reaching forward (the skin end of the arm faces away)
      if (arm) g3d.draw(arm.mesh, 0.5 + bx - sw2 * 0.22, -0.5 + by - lower + sw * 0.12, -0.62 - sw * 0.18, 1.92 - sw * 0.7, 0.42 - sw2 * 0.3, 0.12, 1.1, 1.1, 1.1, tint);
      return;
    }
    const [m, cube] = this.itemMesh(id);
    if (!m) return;
    const def = itemDef(id);
    const tool = def && def.tool;
    const x = 0.42 + bx - sw2 * 0.28 + (eat > 0 ? -0.22 : 0);
    const y = -0.38 + by - lower + sw * 0.12 + eatBob + (eat > 0 ? 0.08 : 0);
    const z = -0.72 - sw * 0.18;
    if (cube) g3d.draw(m, x, y, z, 0.1 - sw * 0.8, 0.75 + sw2 * 0.3, 0, 0.36, 0.36, 0.36, tint);
    else if (tool || id === I.bow) g3d.draw(m, x + 0.02, y + 0.08, z, -0.1 - sw * 1.1, -1.35, 0.55 - sw2 * 0.4, 0.62, 0.62, 0.62, tint);
    else g3d.draw(m, x, y + 0.05, z, -0.2 - sw * 0.9, -0.5 + sw2 * 0.3, 0.1, 0.5, 0.5, 0.5, tint);
  }

  // ---------------------------------------------------------------- highlight, cracks, weather
  drawHighlight() {
    const t = this.highlight;
    if (!t) return;
    const d = blocks[t.id];
    if (!d) return;
    const vd = voxelDef(d);
    const b = vd.selection || (vd.model === "box" ? vd.box : vd.model === "cross" ? [0.15, 0, 0.15, 0.85, 0.8, 0.85] : vd.model === "torch" ? [0.4, 0, 0.4, 0.6, 0.625, 0.6] : vd.model === "fence" ? [0.25, 0, 0.25, 0.75, 1, 0.75] : vd.model === "cactus" ? [1 / 16, 0, 1 / 16, 15 / 16, 1, 15 / 16] : [0, 0, 0, 1, 1, 1]);
    const e = 0.004;
    const x0 = t.x + b[0] - e, y0 = t.y + b[1] - e, z0 = t.z + b[2] - e, x1 = t.x + b[3] + e, y1 = t.y + b[4] + e, z1 = t.z + b[5] + e;
    const c = "#000000A0", th = 2;
    g3d.line(x0, y0, z0, x1, y0, z0, c, th); g3d.line(x0, y1, z0, x1, y1, z0, c, th); g3d.line(x0, y0, z1, x1, y0, z1, c, th); g3d.line(x0, y1, z1, x1, y1, z1, c, th);
    g3d.line(x0, y0, z0, x0, y1, z0, c, th); g3d.line(x1, y0, z0, x1, y1, z0, c, th); g3d.line(x0, y0, z1, x0, y1, z1, c, th); g3d.line(x1, y0, z1, x1, y1, z1, c, th);
    g3d.line(x0, y0, z0, x0, y0, z1, c, th); g3d.line(x1, y0, z0, x1, y0, z1, c, th); g3d.line(x0, y1, z0, x0, y1, z1, c, th); g3d.line(x1, y1, z0, x1, y1, z1, c, th);
    if (this.crack && this.crackStage >= 0 && this.crack.x === t.x && this.crack.y === t.y && this.crack.z === t.z) {
      const sx = b[3] - b[0], sy = b[4] - b[1], sz = b[5] - b[2];
      g3d.draw(this.cracks[this.crackStage], t.x + (b[0] + b[3]) / 2, t.y + (b[1] + b[4]) / 2, t.z + (b[2] + b[5]) / 2, 0, 0, 0, sx, sy, sz, "#000000A0", "unlit");
    }
  }

  drawWeather(cam, g) {
    const wth = g.weather;
    for (const b of wth.bolts) {
      const rnd = mulberry32(b.seed | 0);
      let x = b.x, y = b.y, z = b.z;
      const c = "#E8F0FF";
      for (let i = 0; i < 18; i++) {
        const nx = x + (rnd() - 0.5) * 3, nz = z + (rnd() - 0.5) * 3, ny = y + 6;
        g3d.line(x, y, z, nx, ny, nz, c, 3);
        x = nx; y = ny; z = nz;
      }
    }
    if (wth.rain < 0.05) return;
    const n = Math.round(160 * wth.rain);
    const t = g.clock;
    const snow = wth.precipitationAt(cam.x, cam.z) === "snow";
    const dry = wth.precipitationAt(cam.x, cam.z) === "none";
    if (dry) return;
    const w = g.world;
    for (let i = 0; i < n; i++) {
      const hx = hash2(i, 7, 3), hz = hash2(i, 11, 5), hs = hash2(i, 13, 9);
      const x = Math.floor(cam.x) + Math.floor(hx * 24) - 12 + 0.5 + (hs - 0.5) * 0.6;
      const z = Math.floor(cam.z) + Math.floor(hz * 24) - 12 + 0.5 + (hx - 0.5) * 0.6;
      const top = w.topY(Math.floor(x), Math.floor(z));
      const speed = snow ? 2 : 14;
      const span = 16;
      let y = cam.y + 8 - ((t * speed + hs * span) % span);
      if (y < top + 1) continue;
      if (snow) g3d.point(x + Math.sin(t + i) * 0.3, y, z, 2.5, "#FFFFFFD0");
      else g3d.line(x, y, z, x + 0.05, y - 0.7, z, "#9DB4D8B0", 1.5);
    }
  }

  drawFireOverlay(w, h) {
    gfx.alpha(0.35 + 0.1 * Math.sin(this.game.clock * 20));
    gfx.gradient(0, h * 0.55, w, h * 0.45, "#FF660000", "#FF6600");
    gfx.unalpha();
  }
}

// ---------------------------------------------------------------- particles
class Particles {
  constructor(r) {
    this.r = r;
    this.list = [];
  }
  add(p) { if (this.list.length < 400) this.list.push(p); }
  blockBreak(x, y, z, def) {
    const id = def ? def.id : B.stone;
    for (let i = 0; i < 18; i++) {
      this.add({ x: x + 0.2 + Math.random() * 0.6, y: y + 0.2 + Math.random() * 0.6, z: z + 0.2 + Math.random() * 0.6,
        vx: (Math.random() - 0.5) * 3, vy: Math.random() * 3 + 1, vz: (Math.random() - 0.5) * 3, life: 0.6 + Math.random() * 0.5, size: 0.1 + Math.random() * 0.05, block: id, g: 18 });
    }
  }
  blockHit(x, y, z, face, def) {
    for (let i = 0; i < 2; i++) {
      this.add({ x: x + 0.5 + face[0] * 0.55 + (Math.random() - 0.5) * 0.7 * (1 - Math.abs(face[0])), y: y + 0.5 + face[1] * 0.55 + (Math.random() - 0.5) * 0.7 * (1 - Math.abs(face[1])),
        z: z + 0.5 + face[2] * 0.55 + (Math.random() - 0.5) * 0.7 * (1 - Math.abs(face[2])), vx: face[0] * 1.5, vy: 1 + face[1], vz: face[2] * 1.5, life: 0.4, size: 0.08, block: def.id, g: 18 });
    }
  }
  smoke(x, y, z, n = 1) { for (let i = 0; i < n; i++) this.add({ x: x + (Math.random() - 0.5) * 0.4, y, z: z + (Math.random() - 0.5) * 0.4, vx: 0, vy: 0.8 + Math.random() * 0.5, vz: 0, life: 1 + Math.random(), size: 0.12, color: "#5A5A5A", grow: 0.08, g: -0.4 }); }
  flame(x, y, z) { this.add({ x, y, z, vx: 0, vy: 0.3, vz: 0, life: 0.45, size: 0.07, color: "#FFB040", glow: true, g: -0.5 }); }
  lavaPop(x, y, z) { this.add({ x, y, z, vx: (Math.random() - 0.5) * 2, vy: 4, vz: (Math.random() - 0.5) * 2, life: 1.2, size: 0.08, color: "#FF7A1A", glow: true, g: 12 }); }
  hearts(x, y, z, n) { for (let i = 0; i < n; i++) this.add({ x: x + (Math.random() - 0.5) * 0.8, y: y + Math.random() * 0.3, z: z + (Math.random() - 0.5) * 0.8, vx: 0, vy: 0.8, vz: 0, life: 1, size: 0.14, color: "#FF4A6A", g: -0.6 }); }
  crit(x, y, z, n = 8) { for (let i = 0; i < n; i++) this.add({ x, y, z, vx: (Math.random() - 0.5) * 6, vy: Math.random() * 4, vz: (Math.random() - 0.5) * 6, life: 0.5, size: 0.06, color: "#FFF4B0", glow: true, g: 8 }); }
  // Puffcap spores: lilac and pale green motes that drift and swell; some glow so the cloud shows at night
  spore(x, y, z, fast) {
    const c = Math.random();
    this.add({ x, y, z, vx: (Math.random() - 0.5) * (fast ? 2.4 : 0.5), vy: 0.15 + Math.random() * 0.35, vz: (Math.random() - 0.5) * (fast ? 2.4 : 0.5),
      life: 0.9 + Math.random() * 0.9, size: 0.09 + Math.random() * 0.08, color: c < 0.45 ? "#B48CE0" : c < 0.85 ? "#8FE3B8" : "#E8F8D0",
      glow: c >= 0.6, grow: 0.12, g: -0.05, drag: fast ? 2.5 : 0.8 });
  }
  sporeBurst(x, y, z, r) { for (let i = 0; i < 26; i++) { const a = Math.random() * Math.PI * 2; this.spore(x + Math.cos(a) * 0.3, y + Math.random() * 0.4, z + Math.sin(a) * 0.3, true); } void r; }
  sparkle(x, y, z) { for (let i = 0; i < 10; i++) this.add({ x: x + (Math.random() - 0.5), y: y + Math.random() * 0.6, z: z + (Math.random() - 0.5), vx: 0, vy: 0.6, vz: 0, life: 0.9, size: 0.07, color: "#8CFF8C", glow: true, g: -0.3 }); }
  itemCrumbs(x, y, z, id) { const blk = id < 256 ? id : B.dirt; for (let i = 0; i < 3; i++) this.add({ x, y, z, vx: (Math.random() - 0.5) * 2, vy: 1.5, vz: (Math.random() - 0.5) * 2, life: 0.5, size: 0.06, block: id < 256 ? blk : 0, color: id >= 256 ? "#C8955A" : undefined, g: 16 }); }
  explosion(x, y, z, power) {
    for (let i = 0; i < 30 + power * 6; i++) {
      const a = Math.random() * Math.PI * 2, u = Math.random() * 2 - 1, r = Math.sqrt(1 - u * u), sp = 2 + Math.random() * power * 2;
      this.add({ x, y, z, vx: Math.cos(a) * r * sp, vy: u * sp, vz: Math.sin(a) * r * sp, life: 0.6 + Math.random() * 0.8, size: 0.25 + Math.random() * 0.3, color: Math.random() < 0.5 ? "#E8E8E8" : "#9A9A9A", grow: 0.6, g: -0.5, drag: 3 });
    }
    for (let i = 0; i < 12; i++) this.add({ x: x + (Math.random() - 0.5) * 2, y: y + (Math.random() - 0.5) * 2, z: z + (Math.random() - 0.5) * 2, vx: 0, vy: 0.5, vz: 0, life: 0.35, size: 0.6, color: "#FFC060", glow: true, g: 0 });
  }
  update(dt, world) {
    const L = this.list;
    let j = 0;
    for (let i = 0; i < L.length; i++) {
      const p = L[i];
      p.life -= dt;
      if (p.life <= 0) continue;
      p.vy -= (p.g || 0) * dt;
      if (p.drag) { const k = Math.exp(-p.drag * dt); p.vx *= k; p.vy *= k; p.vz *= k; }
      const nx = p.x + p.vx * dt, ny = p.y + p.vy * dt, nz = p.z + p.vz * dt;
      if (p.block !== undefined && world.collides(Math.floor(nx), Math.floor(ny - p.size / 2), Math.floor(nz))) { p.vx *= 0.3; p.vz *= 0.3; p.vy = 0; }
      else { p.x = nx; p.y = ny; p.z = nz; }
      if (p.grow) p.size += p.grow * dt;
      L[j++] = p;
    }
    L.length = j;
  }
  draw(cam) {
    const r = this.r;
    for (const p of this.list) {
      const dx = p.x - cam.x, dy = p.y - cam.y, dz = p.z - cam.z;
      if (dx * cam.fx + dy * cam.fy + dz * cam.fz < 0) continue;
      if (p.block) {
        const k = r.brightnessAt(p.x, p.y, p.z);
        g3d.draw(r.particleMesh(p.block), p.x, p.y, p.z, 0, 0, 0, p.size, p.size, p.size, gray(k));
      } else {
        const a = clamp(p.life * 2, 0, 1);
        g3d.draw(r.unit, p.x, p.y, p.z, 0, 0, 0, p.size, p.size, p.size, p.color + Math.round(a * 255).toString(16).padStart(2, "0"), p.glow ? "unlit glow" : "unlit");
      }
    }
  }
}
