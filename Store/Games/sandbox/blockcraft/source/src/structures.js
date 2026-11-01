// Deterministic structures: tree shapes (growing saplings) and villages (stamped into
// freshly generated chunks by the game; the terrain itself comes from the voxel world's built-in generator).
// Everything here is a pure function of (seed, coordinates), so chunks generated separately fit together.
import { B } from "./registry.js";
import { hash2, hash3, mulberry32 } from "./util.js";
const SEA_LEVEL = 62, HEIGHT = 128;

// ================================================================ trees
// Returns [x, y, z, id, force] placements for a tree whose trunk starts above (x, groundY, z).
export function treeBlocks(kind, x, groundY, z, seed) {
  const out = [];
  const h = groundY;
  const hr = hash2(x, z, seed + 13);
  if (kind === "spruce") {
    const th = 6 + ((hr * 4) | 0), top = h + th;
    for (let y = h + 3; y <= top + 1; y++) {
      const d = top + 1 - y;
      const rad = d === 0 ? 0 : d === 1 ? 1 : d % 2 === 0 ? 2 : 1;
      for (let dz = -rad; dz <= rad; dz++) for (let dx = -rad; dx <= rad; dx++) {
        if (rad === 2 && Math.abs(dx) === 2 && Math.abs(dz) === 2) continue;
        out.push([x + dx, y, z + dz, B.spruce_leaves, false]);
      }
    }
    for (let y = h + 1; y <= top; y++) out.push([x, y, z, B.spruce_log, true]);
    return out;
  }
  const birch = kind === "birch";
  const th = (birch ? 5 : 4) + ((hr * 3) | 0), top = h + th;
  const leaf = birch ? B.birch_leaves : B.oak_leaves;
  for (let y = top - 2; y <= top + 1; y++) {
    const rad = y >= top ? 1 : 2;
    for (let dz = -rad; dz <= rad; dz++) for (let dx = -rad; dx <= rad; dx++) {
      if (Math.abs(dx) === rad && Math.abs(dz) === rad) {
        if (y === top + 1) continue;
        if (hash3(x + dx, y, z + dz, seed + 14) < 0.5) continue;
      }
      out.push([x + dx, y, z + dz, leaf, false]);
    }
  }
  for (let y = h + 1; y <= top; y++) out.push([x, y, z, birch ? B.birch_log : B.oak_log, true]);
  return out;
}

// ================================================================ villages
export const VILLAGE_CELL = 320;
const STYLES = {
  oak:    { wall: "planks", corner: "oak_log", floor: "cobblestone", found: "cobblestone", roof: "planks", path: "grass_path" },
  spruce: { wall: "planks", corner: "spruce_log", floor: "cobblestone", found: "cobblestone", roof: "spruce_log", path: "grass_path" },
  desert: { wall: "sandstone", corner: "sandstone", floor: "sandstone", found: "sandstone", roof: "sandstone", path: "sandstone" },
};
const door = (half, f) => B[`oak_door_${half}${f}0`];

// facing f = direction the front (door side) looks at: 0:+z 1:-x 2:-z 3:+x
const FDIR = [[0, 1], [-1, 0], [0, -1], [1, 0]];

// Build one piece into an array of [x, y, z, id] (absolute). w = size along local x (left-right), d = depth.
function buildPiece(p, st, seed) {
  const out = [];
  const { type, x0, z0, x1, z1, y } = p;
  const W = x1 - x0 + 1, D = z1 - z0 + 1;
  const put = (x, yy, z, id) => out.push([x, yy, z, id]);
  const S = k => B[st[k]];
  const front = p.facing;
  // position helpers in the piece rectangle
  const isEdgeX = x => x === x0 || x === x1, isEdgeZ = z => z === z0 || z === z1;
  // door cell on the front edge, centred
  const [fdx, fdz] = FDIR[front];
  let doorX, doorZ;
  if (fdz === 1) { doorX = x0 + (W >> 1); doorZ = z1; } else if (fdz === -1) { doorX = x0 + (W >> 1); doorZ = z0; }
  else if (fdx === 1) { doorX = x1; doorZ = z0 + (D >> 1); } else { doorX = x0; doorZ = z0 + (D >> 1); }
  const rnd = mulberry32((Math.imul(x0, 92837111) ^ Math.imul(z0, 689287499) ^ seed) | 0);

  if (type === "well") {
    for (let x = x0; x <= x1; x++) for (let z = z0; z <= z1; z++) {
      const edge = isEdgeX(x) || isEdgeZ(z);
      put(x, y, z, edge ? B.cobblestone : B.water);
      put(x, y - 1, z, B.cobblestone);
      if (edge) put(x, y + 1, z, B.cobblestone); else put(x, y + 1, z, B.air);
      put(x, y + 2, z, (isEdgeX(x) && isEdgeZ(z)) ? B.fence : B.air);
      put(x, y + 3, z, (isEdgeX(x) && isEdgeZ(z)) ? B.fence : B.air);
      put(x, y + 4, z, B.slab_cobble);
    }
    return out;
  }
  if (type === "lamp") {
    for (let k = 1; k <= 3; k++) put(x0, y + k, z0, B.fence);
    put(x0, y + 4, z0, B.lamp);
    return out;
  }
  if (type === "farm") {
    for (let x = x0; x <= x1; x++) for (let z = z0; z <= z1; z++) {
      for (let k = 1; k <= 3; k++) put(x, y + k, z, B.air);
      const edge = isEdgeX(x) || isEdgeZ(z);
      if (edge) { put(x, y, z, st === STYLES.desert ? B.sandstone : B.oak_log); continue; }
      const mid = W >= D ? z === z0 + (D >> 1) : x === x0 + (W >> 1);
      if (mid) { put(x, y, z, B.water); continue; }
      put(x, y, z, B.farmland);
      const r = rnd();
      put(x, y + 1, z, r < 0.65 ? B.wheat_3 : r < 0.85 ? B.wheat_2 : B.wheat_1);
    }
    put(x1 + 1, y + 1, z0, B.hay_bale);
    return out;
  }
  // buildings
  const H = type === "tower" ? 9 : type === "big" ? 5 : 4;
  const wallId = type === "tower" || type === "smith" ? B.cobblestone : S("wall");
  const cornerId = type === "tower" || type === "smith" ? B.cobblestone : S("corner");
  for (let x = x0; x <= x1; x++) for (let z = z0; z <= z1; z++) {
    const edge = isEdgeX(x) || isEdgeZ(z), corner = isEdgeX(x) && isEdgeZ(z);
    put(x, y, z, S("floor"));
    for (let k = 1; k <= H + 3; k++) put(x, y + k, z, B.air);
    for (let k = 1; k <= H; k++) {
      if (!edge) continue;
      if (type === "smith" && !corner && (fdz ? (fdz === 1 ? z === z1 : z === z0) : (fdx === 1 ? x === x1 : x === x0))) continue; // open forge front
      let id = corner ? cornerId : wallId;
      const midWall = (isEdgeX(x) && (z - z0) % 3 === 1 && !isEdgeZ(z)) || (isEdgeZ(z) && (x - x0) % 3 === 1 && !isEdgeX(x));
      if (!corner && midWall && (k === 2 || (type === "tower" && (k === 6 || k === 7)))) id = B.glass;
      put(x, y + k, z, id);
    }
    // flat roof with an overhanging rim
    put(x, y + H + 1, z, type === "tower" ? B.cobblestone : S("roof"));
  }
  if (type !== "tower") {
    // second roof tier for a stepped look
    for (let x = x0 + 1; x <= x1 - 1; x++) for (let z = z0 + 1; z <= z1 - 1; z++) put(x, y + H + 2, z, type === "smith" ? B.cobblestone : S("roof"));
  } else {
    for (let x = x0; x <= x1; x++) for (let z = z0; z <= z1; z++) if (isEdgeX(x) || isEdgeZ(z)) put(x, y + H + 2, z, (x + z) % 2 ? B.cobblestone : B.air);
    put(x0 + (W >> 1), y + H + 2, z0 + (D >> 1), B.lamp);
  }
  // door (two halves), facing the road
  if (type !== "smith") {
    put(doorX, y + 1, doorZ, door(0, front));
    put(doorX, y + 2, doorZ, door(1, front));
    put(doorX + fdx, y, doorZ + fdz, S("floor"));
  }
  // furniture
  const inner = [];
  for (let x = x0 + 1; x <= x1 - 1; x++) for (let z = z0 + 1; z <= z1 - 1; z++) {
    if (Math.abs(x - doorX) + Math.abs(z - doorZ) <= 1) continue;
    inner.push([x, z]);
  }
  const take = () => inner.splice((rnd() * inner.length) | 0, 1)[0];
  const atWall = () => {
    const cands = inner.filter(([x, z]) => x === x0 + 1 || x === x1 - 1 || z === z0 + 1 || z === z1 - 1);
    const c = cands[(rnd() * cands.length) | 0];
    if (c) inner.splice(inner.indexOf(c), 1);
    return c;
  };
  const torchAt = (x, z) => put(x, y + 3, z, B.torch);
  if (type === "smith") {
    const a = atWall(), b = atWall(), c = atWall();
    if (a) put(a[0], y + 1, a[1], B.furnace + ((front + 2) % 4));
    if (b) put(b[0], y + 1, b[1], B.chest);
    if (c) { put(c[0], y, c[1], B.lava); put(c[0], y + 1, c[1], B.air); }
    const t = take(); if (t) put(t[0], y + 1, t[1], B.crafting_table);
    return out;
  }
  if (type === "big") {
    for (let k = 0; k < 4; k++) { const c = atWall(); if (c) { put(c[0], y + 1, c[1], B.bookshelf); put(c[0], y + 2, c[1], B.bookshelf); } }
  }
  const bedC = atWall();
  if (bedC) {
    // bed lies along the wall it touches: head toward the nearest wall
    const [bx, bz] = bedC;
    const f = bx === x0 + 1 ? 1 : bx === x1 - 1 ? 3 : bz === z0 + 1 ? 2 : 0;
    const [hx, hz] = FDIR[f];
    const footX = bx - hx, footZ = bz - hz;
    if (footX > x0 && footX < x1 && footZ > z0 && footZ < z1) {
      put(footX, y + 1, footZ, B[`bed_foot_${f}`]);
      put(bx, y + 1, bz, B[`bed_head_${f}`]);
    }
  }
  const ch = atWall(); if (ch) put(ch[0], y + 1, ch[1], B.chest);
  const ct = atWall(); if (ct) put(ct[0], y + 1, ct[1], B.crafting_table);
  const tc = take(); if (tc) torchAt(tc[0], tc[1]);
  if (type === "tower") { for (let k = 0; k < 2; k++) { const t = take(); if (t) put(t[0], y + 6, t[1], B.torch); } }
  return out;
}

// Plan of the village in cell (cellX, cellZ), or null. column(x, z) -> { h, biome } (the generator's).
export function villagePlan(cellX, cellZ, seed, column) {
  const r0 = hash2(cellX, cellZ, seed + 901);
  if (r0 > 0.6) return null;
  const rnd = mulberry32((Math.imul(cellX, 73428767) ^ Math.imul(cellZ, 912931) ^ seed ^ 0x5eed) | 0);
  const cx = cellX * VILLAGE_CELL + 64 + ((rnd() * 192) | 0);
  const cz = cellZ * VILLAGE_CELL + 64 + ((rnd() * 192) | 0);
  const c = column(cx, cz);
  const biome = c.biome, h0 = c.h;
  // BIOME ids: 2 plains, 3 forest, 4 desert, 5 taiga
  if (![2, 3, 4, 5].includes(biome) || h0 <= SEA_LEVEL + 1 || h0 > 92) return null;
  let lo = h0, hi = h0;
  for (let k = 0; k < 12; k++) {
    const a = (k / 12) * Math.PI * 2;
    const hh = column(Math.round(cx + Math.cos(a) * 22), Math.round(cz + Math.sin(a) * 22)).h;
    lo = Math.min(lo, hh); hi = Math.max(hi, hh);
  }
  if (hi - lo > 7) return null;
  const st = biome === 4 ? STYLES.desert : biome === 5 ? STYLES.spruce : STYLES.oak;
  const plan = { x: cx, z: cz, style: st, pieces: [], roads: [], villagers: 3 + ((rnd() * 5) | 0), minX: cx, maxX: cx, minZ: cz, maxZ: cz };
  const rects = [];
  const free = (x0, z0, x1, z1) => rects.every(q => x1 < q[0] - 1 || x0 > q[2] + 1 || z1 < q[1] - 1 || z0 > q[3] + 1);
  const addRect = (x0, z0, x1, z1) => { rects.push([x0, z0, x1, z1]); plan.minX = Math.min(plan.minX, x0); plan.maxX = Math.max(plan.maxX, x1); plan.minZ = Math.min(plan.minZ, z0); plan.maxZ = Math.max(plan.maxZ, z1); };
  const yAt = (x, z) => Math.max(SEA_LEVEL + 1, column(x, z).h);
  // well at the crossing
  plan.pieces.push({ type: "well", x0: cx - 2, z0: cz - 2, x1: cx + 1, z1: cz + 1, y: yAt(cx, cz), facing: 0 });
  addRect(cx - 2, cz - 2, cx + 1, cz + 1);
  // roads: a cross, sometimes a parallel street
  const arms = [[1, 0], [-1, 0], [0, 1], [0, -1]];
  const lens = arms.map(() => 22 + ((rnd() * 22) | 0));
  arms.forEach(([ax, az], i) => {
    const L = lens[i];
    const x0 = ax === 0 ? cx - 1 : ax > 0 ? cx + 2 : cx - 2 - L;
    const x1 = ax === 0 ? cx + 1 : ax > 0 ? cx + 2 + L : cx - 3;
    const z0 = az === 0 ? cz - 1 : az > 0 ? cz + 2 : cz - 2 - L;
    const z1 = az === 0 ? cz + 1 : az > 0 ? cz + 2 + L : cz - 3;
    plan.roads.push({ x0, z0, x1, z1 });
    addRect(x0, z0, x1, z1);
  });
  // houses along each arm, doors facing the road
  const kinds = ["small", "small", "medium", "medium", "big", "farm", "farm", "smith", "tower"];
  arms.forEach(([ax, az], i) => {
    const L = lens[i];
    for (let t = 6; t < L - 2; t += 9 + ((rnd() * 4) | 0)) {
      for (const side of [-1, 1]) {
        if (rnd() < 0.18) continue;
        const kind = kinds[(rnd() * kinds.length) | 0];
        const [w, d] = kind === "small" ? [5, 5] : kind === "medium" ? [7, 6] : kind === "big" ? [9, 7] : kind === "farm" ? [9, 7] : kind === "smith" ? [7, 6] : [5, 5];
        // road centre point and the perpendicular side
        const px = cx + ax * (2 + t), pz = cz + az * (2 + t);
        let x0, z0, x1, z1, facing;
        if (ax !== 0) { // road along x, houses north/south of it
          const off = 3;
          x0 = px - (w >> 1); x1 = x0 + w - 1;
          if (side > 0) { z0 = cz + 1 + off; z1 = z0 + d - 1; facing = 2; } else { z1 = cz - 1 - off; z0 = z1 - d + 1; facing = 0; }
        } else {
          const off = 3;
          z0 = pz - (w >> 1); z1 = z0 + w - 1;
          if (side > 0) { x0 = cx + 1 + off; x1 = x0 + d - 1; facing = 1; } else { x1 = cx - 1 - off; x0 = x1 - d + 1; facing = 3; }
        }
        if (!free(x0, z0, x1, z1)) continue;
        addRect(x0, z0, x1, z1);
        plan.pieces.push({ type: kind, x0, z0, x1, z1, y: yAt((x0 + x1) >> 1, (z0 + z1) >> 1), facing });
      }
      // lamp post at the road side
      if (rnd() < 0.6) {
        const lx = ax !== 0 ? cx + ax * (2 + t) : cx + 2, lz = az !== 0 ? cz + az * (2 + t) : cz + 2;
        if (free(lx, lz, lx, lz)) { addRect(lx, lz, lx, lz); plan.pieces.push({ type: "lamp", x0: lx, z0: lz, x1: lx, z1: lz, y: yAt(lx, lz), facing: 0 }); }
      }
    }
  });
  plan.minX -= 2; plan.maxX += 2; plan.minZ -= 2; plan.maxZ += 12;
  return plan;
}

// Stamp a plan into a chunk. set(x, y, z, id) writes only inside the chunk; column/ground give terrain heights.
export function stampVillage(plan, seed, x0c, z0c, set, column) {
  if (plan.maxX < x0c || plan.minX > x0c + 15 || plan.maxZ < z0c || plan.minZ > z0c + 15) return;
  const inChunk = (x, z) => x >= x0c && x < x0c + 16 && z >= z0c && z < z0c + 16;
  const st = plan.style;
  // roads follow the terrain; bridges over water
  for (const r of plan.roads) {
    for (let x = Math.max(r.x0, x0c); x <= Math.min(r.x1, x0c + 15); x++) for (let z = Math.max(r.z0, z0c); z <= Math.min(r.z1, z0c + 15); z++) {
      const h = column(x, z).h;
      if (h < SEA_LEVEL) { set(x, SEA_LEVEL, z, B.planks); for (let k = 1; k <= 3; k++) set(x, SEA_LEVEL + k, z, B.air); continue; }
      set(x, h, z, B[st.path]);
      for (let k = 1; k <= 4; k++) set(x, h + k, z, B.air);
    }
  }
  for (const p of plan.pieces) {
    if (p.x1 < x0c - 1 || p.x0 > x0c + 16 || p.z1 < z0c - 1 || p.z0 > z0c + 16) continue;
    // foundation down to the terrain
    for (let x = p.x0; x <= p.x1; x++) for (let z = p.z0; z <= p.z1; z++) {
      if (!inChunk(x, z)) continue;
      const h = column(x, z).h;
      for (let y = Math.min(h, p.y - 1); y < p.y; y++) set(x, y, z, B[st.found]);
    }
    for (const [x, y, z, id] of buildPiece(p, st, seed)) if (inChunk(x, z) && y > 0 && y < HEIGHT) set(x, y, z, id);
  }
}

// Village centres near a position (for villager spawning on the main thread).
export function villagesNear(x, z, seed, column, radius = 160) {
  const out = [];
  const c0x = Math.floor((x - radius) / VILLAGE_CELL), c1x = Math.floor((x + radius) / VILLAGE_CELL);
  const c0z = Math.floor((z - radius) / VILLAGE_CELL), c1z = Math.floor((z + radius) / VILLAGE_CELL);
  for (let cz = c0z; cz <= c1z; cz++) for (let cx = c0x; cx <= c1x; cx++) {
    const p = villagePlan(cx, cz, seed, column);
    if (p && Math.hypot(p.x - x, p.z - z) < radius) out.push({ key: `${cx},${cz}`, plan: p });
  }
  return out;
}
