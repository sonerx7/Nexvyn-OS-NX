// Caves on top of the native terrain generator: winding "worm" tunnels with large chambers, mouths that open at the
// surface, and water or lava pools at the deep ends. Carved into each freshly generated chunk (one chunk() copy,
// edited as bytes, one setChunk(), so the chunk stays "unmodified" and is generated again identically when it
// reloads). Every worm comes from a seed of its origin chunk, so neighbouring chunks carve matching halves.
import { B } from "./registry.js";
import { mulberry32 } from "./util.js";

const CS = 16, LAYER = CS * CS;
const REACH = 3;                 // chunks: worms of origin chunks this far away can reach into a chunk
const MAX_DIST = REACH * CS - 8; // a worm never wanders further than this from its origin chunk's centre
const LAVA_Y = 10;

let CARVE = null;
function carvable() {
  if (CARVE) return CARVE;
  CARVE = new Uint8Array(256);
  for (const k of ["stone", "dirt", "grass", "gravel", "sand", "sandstone", "coal_ore", "iron_ore", "gold_ore", "diamond_ore", "snowy_grass", "snow", "sulfur_ore"])
    if (B[k] !== undefined) CARVE[B[k]] = 1;
  return CARVE;
}

// The worms that start in origin chunk (ox, oz). `spawn` (block x/z) forces a surface cave mouth near the spawn.
function wormsOf(ox, oz, seed, column, spawn, avoid) {
  const rnd = mulberry32((Math.imul(ox, 0x2C1B3C6D) ^ Math.imul(oz, 0x297A2D39) ^ Math.imul(seed | 0, 0x1B873593) ^ 0x5CA7E) | 0);
  const list = [];
  let n = rnd() < 0.55 ? 1 : 0;
  if (rnd() < 0.25) n++;
  for (let k = 0; k < n; k++) {
    const x = ox * CS + rnd() * CS, z = oz * CS + rnd() * CS;
    const surface = rnd() < 0.3;
    const h = column(Math.floor(x), Math.floor(z)).h;
    let y = surface ? h + 1 : 8 + rnd() * Math.max(10, Math.min(52, h - 12));
    let ok = true;
    if (surface && (h < 63 || avoid(x, z))) ok = false;  // no mouths in the sea or in villages
    const wseed = (rnd() * 4294967296) | 0;
    if (ok) list.push({ x, y, z, surface, wseed });
  }
  if (spawn && Math.floor(spawn.x / CS) === ox && Math.floor(spawn.z / CS) === oz) {
    // a cave mouth 10 to 30 blocks from the spawn point, away from villages
    for (let t = 0; t < 8; t++) {
      const a = rnd() * Math.PI * 2, d = 10 + rnd() * 20 + t * 2;
      const x = spawn.x + Math.cos(a) * d, z = spawn.z + Math.sin(a) * d;
      const h = column(Math.floor(x), Math.floor(z)).h;
      const wseed = (rnd() * 4294967296) | 0;
      if (h < 63 || avoid(x, z)) continue;
      list.push({ x, y: h + 1, z, surface: true, wseed, big: true, ox, oz });
      break;
    }
  }
  return list;
}

// Walks one worm and calls sphere(cx, cy, cz, r, ry) for each step; spheres far from the target chunk are skipped
// by the caller. Returns the end point for pools.
function walk(w, ox, oz, sphere) {
  const rnd = mulberry32(w.wseed);
  let x = w.x, y = w.y, z = w.z;
  let yaw = rnd() * Math.PI * 2, pitch = w.surface ? -0.55 - rnd() * 0.25 : (rnd() - 0.5) * 0.4;
  let dyaw = 0, dpitch = 0;
  const len = (w.big ? 110 : 70) + ((rnd() * 70) | 0);
  const base = 1.4 + rnd() * 1.2;
  const chamberAt = rnd() < (w.big ? 1 : 0.45) ? Math.floor(len * (0.35 + rnd() * 0.4)) : -1;
  const chamberR = 4 + rnd() * 2.5;
  const cxm = ox * CS + 8, czm = oz * CS + 8;
  for (let i = 0; i < len; i++) {
    let r = base * (0.8 + 0.4 * Math.sin((i / len) * Math.PI));
    if (w.surface && i < 6) r = Math.min(r, 1.6 + i * 0.15);
    if (chamberAt >= 0 && Math.abs(i - chamberAt) < 6) r = Math.max(r, chamberR * Math.cos(((i - chamberAt) / 6) * Math.PI * 0.5));
    sphere(x, y, z, r, r * 0.75);
    const cp = Math.cos(pitch);
    x += Math.sin(yaw) * cp; z += Math.cos(yaw) * cp; y += Math.sin(pitch);
    yaw += dyaw * 0.12; pitch = pitch * 0.92 + dpitch * 0.08;
    dyaw = dyaw * 0.85 + (rnd() - 0.5) * 2.2;
    dpitch = dpitch * 0.7 + (rnd() - 0.5) * 1.2;
    if (w.surface && i < 14) pitch = Math.min(pitch, -0.35);   // mouths lead down into the ground
    if (y < 6) { y = 6; pitch = Math.abs(pitch) * 0.5; }
    if (y > 110) break;
    if (Math.hypot(x - cxm, z - czm) > MAX_DIST) break;
  }
  return { x, y, z, deep: y < 34, pool: rnd() };
}

// The worms of one origin chunk walked once: [x, y, z, r, ry, ...] spheres plus pools [x, y, z, fill, ...].
function origin(cache, ox, oz, seed, column, spawn, avoid) {
  const key = ox * 100003 + oz;
  let o = cache.get(key);
  if (o) return o;
  const sph = [], pools = [];
  for (const w of wormsOf(ox, oz, seed, column, spawn, avoid)) {
    const end = walk(w, ox, oz, (x, y, z, r, ry) => sph.push(x, y, z, r, ry));
    if (end.deep && end.pool < 0.45) pools.push(end.x, end.y, end.z, end.pool < 0.15 ? B.lava : B.water);
  }
  o = { sph: new Float32Array(sph), pools };
  if (cache.size > 700) cache.clear();
  cache.set(key, o);
  return o;
}

// Carves the caves of chunk (cx, cz) into `data` (chunk bytes). Returns true when something changed.
export function carveChunk(data, cx, cz, height, seed, column, spawn, avoid, villageRects, cache) {
  const C = carvable();
  const x0 = cx * CS, z0 = cz * CS;
  const water = B.water, lava = B.lava;
  // surface height of each column: no carving right under the sea floor or inside villages near the surface
  const colH = new Int16Array(LAYER), keep = new Int16Array(LAYER);
  for (let lz = 0; lz < CS; lz++) for (let lx = 0; lx < CS; lx++) {
    const h = column(x0 + lx, z0 + lz).h;
    colH[lx + lz * CS] = h;
    let k = h < 63 ? h - 4 : height;   // under water: keep a 4 block floor
    for (const r of villageRects) if (x0 + lx >= r[0] && x0 + lx <= r[2] && z0 + lz >= r[1] && z0 + lz <= r[3]) k = Math.min(k, h - 6);
    keep[lx + lz * CS] = k;
  }
  let changed = false;
  const sphere = (sx, sy, sz, r, ry, fill) => {
    if (sx + r < x0 || sx - r >= x0 + CS || sz + r < z0 || sz - r >= z0 + CS) return;
    const xa = Math.max(x0, Math.floor(sx - r)), xb = Math.min(x0 + CS - 1, Math.floor(sx + r));
    const za = Math.max(z0, Math.floor(sz - r)), zb = Math.min(z0 + CS - 1, Math.floor(sz + r));
    const ya = Math.max(1, Math.floor(sy - ry)), yb = Math.min(height - 2, Math.floor(sy + ry));
    const ir2 = 1 / (r * r), iry2 = 1 / (ry * ry);
    for (let y = ya; y <= yb; y++) {
      const dy = (y + 0.5 - sy) * (y + 0.5 - sy) * iry2;
      if (dy >= 1) continue;
      for (let z = za; z <= zb; z++) {
        const dz = (z + 0.5 - sz) * (z + 0.5 - sz) * ir2;
        if (dy + dz >= 1) continue;
        for (let x = xa; x <= xb; x++) {
          const dx = (x + 0.5 - sx) * (x + 0.5 - sx) * ir2;
          if (dy + dz + dx >= 1) continue;
          const l = (x - x0) + (z - z0) * CS;
          const i = l + y * LAYER;
          if (fill) {
            if (data[i] === 0 && y <= sy - ry * 0.25) { data[i] = y <= LAVA_Y + 2 ? lava : fill; changed = true; }
            continue;
          }
          if (!C[data[i]] || y > keep[l] || y <= 2) continue;
          const up = data[i + LAYER];
          if (up === water || up === lava && y > LAVA_Y) continue;
          data[i] = y <= LAVA_Y ? lava : 0;
          changed = true;
        }
      }
    }
  };
  const origins = [];
  for (let oz = cz - REACH; oz <= cz + REACH; oz++) for (let ox = cx - REACH; ox <= cx + REACH; ox++) origins.push(origin(cache, ox, oz, seed, column, spawn, avoid));
  for (const o of origins) { const a = o.sph; for (let i = 0; i < a.length; i += 5) sphere(a[i], a[i + 1], a[i + 2], a[i + 3], a[i + 4], 0); }
  // deep ends: a water pool (or lava near the bottom), after all tunnels so none cuts through it
  for (const o of origins) { const q = o.pools; for (let i = 0; i < q.length; i += 4) sphere(q[i], q[i + 1], q[i + 2], 3.2, 2.4, q[i + 3]); }
  return changed;
}
