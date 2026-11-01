// Box physics for every entity. The sweep itself (sliding along blocks, stepping up ledges, partial boxes such as
// slabs, doors and 1.5 high fences) runs natively in the voxel world (world.move, SDK 1.7); the contact helpers
// below work on the same boxes. An entity box: pos = feet centre {x, y, z}, hw = half width, h = height.
import { isWater, isLava, blocks } from "./registry.js";

const EPS = 1e-7;

// Moves e by (dx, dy, dz) with step-up, sets e.onGround / e.collidedH / e.hitCeiling and stops the velocity along
// blocked axes.
export function moveBoxStep(world, e, dx, dy, dz, stepH = 0) {
  const r = world.v.move(e.pos.x, e.pos.y, e.pos.z, e.hw, e.h, dx, dy, dz, stepH);
  const f = r[3];
  e.pos.x = r[0]; e.pos.y = r[1]; e.pos.z = r[2];
  e.onGround = (f & 1) !== 0;
  e.hitCeiling = (f & 2) !== 0;
  e.collidedH = (f & 12) !== 0;
  if (e.onGround || e.hitCeiling) e.vel.y = 0;
  if (f & 4) e.vel.x = 0;
  if (f & 8) e.vel.z = 0;
  return f;
}
export const moveBox = (world, e, dx, dy, dz) => moveBoxStep(world, e, dx, dy, dz, 0);

export function boxBlocked(world, x, y, z, hw, h) { return world.v.blocked(x, y, z, hw, h); }

// Cells (block ids) overlapping a box, for contact effects (fire, ladders, cactus).
export function touchingIds(world, e, grow = 0) {
  const out = [];
  for (let y = Math.floor(e.pos.y - grow); y <= Math.floor(e.pos.y + e.h - 0.01); y++)
    for (let z = Math.floor(e.pos.z - e.hw - grow); z <= Math.floor(e.pos.z + e.hw + grow); z++)
      for (let x = Math.floor(e.pos.x - e.hw - grow); x <= Math.floor(e.pos.x + e.hw + grow); x++)
        out.push(world.getBlock(x, y, z));
  return out;
}

// Is there something to stand on under a box placed at (x, y, z)?
export function hasGround(world, x, y, z, hw) {
  const yy = Math.floor(y - 0.5);
  for (let bz = Math.floor(z - hw + EPS); bz <= Math.floor(z + hw - EPS); bz++)
    for (let bx = Math.floor(x - hw + EPS); bx <= Math.floor(x + hw - EPS); bx++)
      if (world.collides(bx, yy, bz)) return true;
  return false;
}

// Liquid contact for a box: { water, lava, eyeWater } (eyeY = absolute eye height, optional).
export function liquidContact(world, e, eyeY) {
  let water = false, lava = false;
  const y0 = Math.floor(e.pos.y + 0.05), y1 = Math.floor(e.pos.y + e.h * 0.6);
  for (let y = y0; y <= y1; y++)
    for (let z = Math.floor(e.pos.z - e.hw); z <= Math.floor(e.pos.z + e.hw); z++)
      for (let x = Math.floor(e.pos.x - e.hw); x <= Math.floor(e.pos.x + e.hw); x++) {
        const id = world.getBlock(x, y, z);
        if (isWater(id)) water = true;
        else if (isLava(id)) lava = true;
      }
  let eyeWater = false;
  if (eyeY !== undefined) eyeWater = isWater(world.getBlock(Math.floor(e.pos.x), Math.floor(eyeY), Math.floor(e.pos.z)));
  return { water, lava, eyeWater };
}

export function touchesHurtful(world, e) {
  const g = 0.05;
  for (let y = Math.floor(e.pos.y - g); y <= Math.floor(e.pos.y + e.h); y++)
    for (let z = Math.floor(e.pos.z - e.hw - g); z <= Math.floor(e.pos.z + e.hw + g); z++)
      for (let x = Math.floor(e.pos.x - e.hw - g); x <= Math.floor(e.pos.x + e.hw + g); x++)
        if (blocks[world.getBlock(x, y, z)].hurts) return true;
  return false;
}

// Ray vs axis-aligned box. Returns distance or -1.
export function rayBox(ox, oy, oz, dx, dy, dz, minX, minY, minZ, maxX, maxY, maxZ) {
  let t0 = 0, t1 = Infinity;
  const o = [ox, oy, oz], d = [dx, dy, dz], mn = [minX, minY, minZ], mx = [maxX, maxY, maxZ];
  for (let k = 0; k < 3; k++) {
    if (Math.abs(d[k]) < 1e-9) { if (o[k] < mn[k] || o[k] > mx[k]) return -1; continue; }
    let ta = (mn[k] - o[k]) / d[k], tb = (mx[k] - o[k]) / d[k];
    if (ta > tb) { const t = ta; ta = tb; tb = t; }
    if (ta > t0) t0 = ta;
    if (tb < t1) t1 = tb;
    if (t0 > t1) return -1;
  }
  return t0;
}

// Block ray cast. Solid targets come from the voxel world (selection boxes included); liquids (buckets) are found
// with a JavaScript walk: "source" stops at water / lava sources, "any" at any liquid.
export function raycastBlocks(world, ox, oy, oz, dx, dy, dz, maxDist, liquids = null) {
  const h = world.v.raycast(ox, oy, oz, dx, dy, dz, maxDist);
  let hit = h ? { x: h.x, y: h.y, z: h.z, id: h.id, face: [h.nx, h.ny, h.nz], dist: h.dist } : null;
  if (!liquids) return hit;
  let x = Math.floor(ox), y = Math.floor(oy), z = Math.floor(oz);
  const sx = Math.sign(dx), sy = Math.sign(dy), sz = Math.sign(dz);
  const tdx = dx ? Math.abs(1 / dx) : Infinity, tdy = dy ? Math.abs(1 / dy) : Infinity, tdz = dz ? Math.abs(1 / dz) : Infinity;
  let tmx = dx > 0 ? (x + 1 - ox) * tdx : dx < 0 ? (ox - x) * tdx : Infinity;
  let tmy = dy > 0 ? (y + 1 - oy) * tdy : dy < 0 ? (oy - y) * tdy : Infinity;
  let tmz = dz > 0 ? (z + 1 - oz) * tdz : dz < 0 ? (oz - z) * tdz : Infinity;
  let face = [0, 0, 0], t = 0;
  const limit = hit ? hit.dist : maxDist;
  for (let i = 0; i < 256 && t <= limit; i++) {
    const id = world.getBlock(x, y, z);
    const def = blocks[id];
    if (id && def.liquid && (liquids === "any" || def.level === 8 || (def.liquid === "lava" && def.level === 8))) return { x, y, z, id, face, dist: t, liquid: true };
    if (tmx < tmy && tmx < tmz) { x += sx; t = tmx; tmx += tdx; face = [-sx, 0, 0]; }
    else if (tmy < tmz) { y += sy; t = tmy; tmy += tdy; face = [0, -sy, 0]; }
    else { z += sz; t = tmz; tmz += tdz; face = [0, 0, -sz]; }
  }
  return hit;
}
