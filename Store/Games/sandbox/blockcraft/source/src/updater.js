// World simulation.
//  - scheduled updates: water + lava flow (and how they harden each other), fire, falling sand/gravel,
//    blocks that need support, two-block doors and beds, leaf decay
//  - ambient ticks (randomly chosen blocks near the player get a turn now and then): crops, saplings, grass spreading,
//    farmland drying, cactus growth, lava sparks. They sample blocks through the voxel world (a few per chunk per
//    tick instead of reading whole chunk arrays) and make up for it with higher growth odds.
import {
  blocks, B, COLLIDE, SOLID, OPACITY, isWater, isLava, isLiquid, waterLevel, waterId, lavaLevel, lavaId, DIR4,
} from "./registry.js";
import { treeBlocks } from "./structures.js";
const HEIGHT = 128;

const WATER_DELAY = 5;   // ticks (0.25 s)
const LAVA_DELAY = 30;   // ticks (1.5 s): lava creeps much slower than water
const MAX_PER_TICK = 256;
const LEAF_R = 4;        // leaves farther than this from any log decay
const RANDOM_PER_CHUNK = 6;  // samples per chunk column per ambient-tick round
const RANDOM_BOOST = 8;      // rounds run every other tick with a quarter of the samples: growth odds x8
const N6 = [[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]];
const SIDES = [[1, 0], [-1, 0], [0, 1], [0, -1]];
const PLANT_SOIL = new Set([B.grass, B.dirt, B.snowy_grass, B.farmland]);
const rand = n => (Math.random() * n) | 0;

// fire odds per block id: CATCH = how eagerly fire spreads next to it, BURN = how fast it burns away
const CATCH = new Uint8Array(256), BURN = new Uint8Array(256);
for (const d of blocks) if (d.fire) { CATCH[d.id] = d.fire[0]; BURN[d.id] = d.fire[1]; }

export const doorId = (half, facing, open) => B[`oak_door_${half}${facing}${open ? 1 : 0}`];
export const bedId = (head, facing) => B[`bed_${head ? "head" : "foot"}_${facing}`];

const RT = { NONE: 0, GRASS: 1, FARMLAND: 2, CROP: 3, SAPLING: 4, CACTUS: 5, LAVA: 6, PENDING: 7 };
const RANDOM = new Uint8Array(256);
RANDOM[B.grass] = RT.GRASS; RANDOM[B.snowy_grass] = RT.GRASS;
RANDOM[B.farmland] = RT.FARMLAND;
for (let s = 0; s < 3; s++) RANDOM[B[`wheat_${s}`]] = RT.CROP;
for (const k of ["sapling_oak", "sapling_birch", "sapling_spruce"]) RANDOM[B[k]] = RT.SAPLING;
RANDOM[B.cactus] = RT.CACTUS;
RANDOM[B.lava] = RT.LAVA;
for (let l = 1; l <= 3; l++) RANDOM[B[`lava_${l}`]] = RT.LAVA;
// blocks loaded from a save may have lost their pending update: an ambient tick re-schedules them
RANDOM[B.fire] = RT.PENDING;
for (let l = 1; l <= 7; l++) RANDOM[B[`water_${l}`]] = RT.PENDING;

export class BlockUpdater {
  constructor(world) {
    this.world = world;
    this.now = 0;
    this.due = new Map();       // tick -> array of [x, y, z]
    this.scheduled = new Map(); // "x,y,z" -> due tick
    this.fireAge = new Map();   // "x,y,z" -> 0..15: how long a fire has burned (old fires go out)
    this.raining = false;       // set by the weather
    this.randomRadius = 4;      // chunks around the player that get ambient ticks
    this.round = 0;
  }

  schedule(x, y, z, delay) {
    if (y < 0 || y >= HEIGHT) return;
    const k = `${x},${y},${z}`;
    const at = this.now + Math.max(1, delay);
    const prev = this.scheduled.get(k);
    if (prev !== undefined && prev <= at) return;
    this.scheduled.set(k, at);
    let list = this.due.get(at);
    if (!list) this.due.set(at, list = []);
    list.push([x, y, z]);
  }

  delayFor(x, y, z) {
    const id = this.world.getBlock(x, y, z);
    if (isWater(id)) return WATER_DELAY;
    if (isLava(id)) return LAVA_DELAY;
    if (id === B.fire) return 30 + rand(10);
    if (blocks[id].gravity) return 2;
    return 1;
  }

  onChanged(x, y, z, old, id) {
    const k = `${x},${y},${z}`;
    if (id === B.fire) { if (!this.fireAge.has(k)) this.fireAge.set(k, 0); }
    else if (old === B.fire) this.fireAge.delete(k);
    this.schedule(x, y, z, this.delayFor(x, y, z));
    const w = this.world;
    const wet = isWater(id);
    for (const [dx, dy, dz] of N6) {
      const nx = x + dx, ny = y + dy, nz = z + dz;
      // water arriving next to lava hardens it right away (on the neighbour change, not on the next tick)
      if (wet && isLava(w.getBlock(nx, ny, nz))) this.schedule(nx, ny, nz, 1);
      else this.schedule(nx, ny, nz, this.delayFor(nx, ny, nz));
    }
    // a log disappeared: nearby leaves re-check whether they are still attached to a tree
    if (old !== undefined && blocks[old].log && !(blocks[id] && blocks[id].log)) {
      for (let dy = -LEAF_R; dy <= LEAF_R; dy++) for (let dz = -LEAF_R; dz <= LEAF_R; dz++) for (let dx = -LEAF_R; dx <= LEAF_R; dx++) {
        if (blocks[w.getBlock(x + dx, y + dy, z + dz)].leaves) this.schedule(x + dx, y + dy, z + dz, 20 + rand(130));
      }
    }
  }

  hasLogNear(x, y, z) {
    const w = this.world;
    for (let dy = -LEAF_R; dy <= LEAF_R; dy++) for (let dz = -LEAF_R; dz <= LEAF_R; dz++) for (let dx = -LEAF_R; dx <= LEAF_R; dx++) {
      if (blocks[w.getBlock(x + dx, y + dy, z + dz)].log) return true;
    }
    return false;
  }

  tick() {
    this.now++;
    const list = this.due.get(this.now);
    if (!list) return;
    this.due.delete(this.now);
    let processed = 0;
    for (let i = 0; i < list.length; i++) {
      const [x, y, z] = list[i];
      const k = `${x},${y},${z}`;
      if (this.scheduled.get(k) !== this.now) continue;
      this.scheduled.delete(k);
      if (processed++ >= MAX_PER_TICK) { this.schedule(x, y, z, 1); continue; }
      if (!this.world.isLoaded(x, z)) continue;
      this.update(x, y, z);
    }
  }

  // ---------------------------------------------------------------- scheduled updates
  update(x, y, z) {
    const w = this.world;
    const id = w.getBlock(x, y, z);
    const def = blocks[id];
    if (isWater(id)) return this.updateWater(x, y, z, id);
    if (isLava(id)) return this.updateLava(x, y, z, id);
    if (id === B.fire) return this.tickFire(x, y, z);
    if (def.gravity) return this.fall(x, y, z, id);
    if (def.leaves) {
      if (!this.hasLogNear(x, y, z)) {
        w.setBlock(x, y, z, B.air);
        w.game?.spawnBlockDrops(x, y, z, id, false);
        w.game?.renderer?.particles?.blockBreak(x, y, z, def);
      }
      return;
    }
    if (def.door) return this.checkDoor(x, y, z, def.door);
    if (def.bed) return this.checkBed(x, y, z, def.bed);
    if (def.needsSupport && !this.supported(x, y, z, id)) return this.breakNaturally(x, y, z, id);
    if (id === B.farmland && SOLID[w.getBlock(x, y + 1, z)]) w.setBlock(x, y, z, B.dirt);
  }

  breakNaturally(x, y, z, id) {
    const w = this.world;
    w.setBlock(x, y, z, B.air);
    w.game?.spawnBlockDrops(x, y, z, id, false);
  }

  // Door halves keep each other alive; the lower half also needs a block to stand on.
  // The half that was broken by the player already dropped the door item, so the partner vanishes quietly.
  checkDoor(x, y, z, d) {
    const w = this.world;
    if (d.half === 0) {
      const up = blocks[w.getBlock(x, y + 1, z)].door;
      if (!up || up.half !== 1) { w.setBlock(x, y, z, B.air); return; }
      if (!COLLIDE[w.getBlock(x, y - 1, z)]) this.breakNaturally(x, y, z, w.getBlock(x, y, z));
    } else {
      const lo = blocks[w.getBlock(x, y - 1, z)].door;
      if (!lo || lo.half !== 0) w.setBlock(x, y, z, B.air);
    }
  }

  checkBed(x, y, z, b) {
    const w = this.world;
    const [dx, dz] = DIR4[b.facing];
    const s = b.head ? -1 : 1;
    const other = blocks[w.getBlock(x + dx * s, y, z + dz * s)].bed;
    if (!other || other.head === b.head || other.facing !== b.facing) w.setBlock(x, y, z, B.air);
  }

  supported(x, y, z, id) {
    const w = this.world;
    const def = blocks[id];
    const below = w.getBlock(x, y - 1, z);
    if (def.attach !== undefined) {
      const [ax, az] = DIR4[def.attach];
      const n = w.getBlock(x + ax, y, z + az);
      return COLLIDE[n] === 1 && (SOLID[n] === 1 || !def.climbable); // ladders need a full block behind them
    }
    if (id === B.torch) return COLLIDE[below] === 1 && (SOLID[below] === 1 || blocks[below].model === "fence");
    if (id === B.cactus) {
      if (below !== B.sand && below !== B.cactus) return false;
      for (const [dx, dz] of SIDES) if (SOLID[w.getBlock(x + dx, y, z + dz)]) return false; // a cactus cannot grow next to a solid block
      return true;
    }
    if (id === B.dead_bush) return below === B.sand || below === B.dirt;
    if (def.crop !== undefined) return below === B.farmland;
    if (def.plant) return PLANT_SOIL.has(below);
    return COLLIDE[below] === 1;
  }

  // Can water / lava / a falling block move into this cell (destroying what is there)?
  passable(id) {
    if (id === B.air) return true;
    const d = blocks[id];
    if (isLiquid(id)) return false;
    return !d.collide && (d.replaceable || d.needsSupport) && !d.climbable;
  }

  replaceInto(x, y, z, newId, drops = true) {
    const w = this.world;
    const old = w.getBlock(x, y, z);
    if (old === B.fire && isWater(newId)) this.sound("extinguish", x, y, z, 0.5);
    else if (drops && old !== B.air && !isLiquid(old)) w.game?.spawnBlockDrops(x, y, z, old, false);
    w.setBlock(x, y, z, newId);
  }

  sound(name, x, y, z, volume = 1) { this.world.game?.sound?.play(name, { x: x + 0.5, y: y + 0.5, z: z + 0.5, volume }); }

  fall(x, y, z, id) {
    const w = this.world;
    let ty = y;
    while (ty > 0) {
      const below = w.getBlock(x, ty - 1, z);
      if (below === B.air || isWater(below) || this.passable(below)) ty--;
      else break;
    }
    if (ty === y) return;
    w.setBlock(x, y, z, B.air);
    this.replaceInto(x, ty, z, id);
  }

  // ---------------------------------------------------------------- water + lava
  updateWater(x, y, z, id) {
    const w = this.world;
    const level = waterLevel(id);
    if (level < 8) {
      let expected;
      if (isWater(w.getBlock(x, y + 1, z))) expected = 7;
      else {
        let maxN = 0, sources = 0;
        for (const [dx, dz] of SIDES) {
          const n = w.getBlock(x + dx, y, z + dz);
          if (!isWater(n)) continue;
          const l = waterLevel(n);
          if (l === 8) sources++;
          if (l > maxN) maxN = l;
        }
        expected = maxN - 1;
        if (sources >= 2) {
          const below = w.getBlock(x, y - 1, z);
          if (SOLID[below] || below === B.water) expected = 8;
        }
      }
      if (expected <= 0) { w.setBlock(x, y, z, B.air); return; }
      if (expected !== level) { w.setBlock(x, y, z, waterId(expected)); return; }
    }
    // spread: down first, sideways only when resting on something
    const below = y > 0 ? w.getBlock(x, y - 1, z) : B.bedrock;
    if (y > 0 && this.passable(below)) { this.replaceInto(x, y - 1, z, waterId(7)); return; }
    if (isWater(below) && below !== B.water) return;
    const next = level >= 8 ? 7 : level - 1;
    if (next <= 0) return;
    for (const [dx, dz] of SIDES) {
      const n = w.getBlock(x + dx, y, z + dz);
      if (this.passable(n)) this.replaceInto(x + dx, y, z + dz, waterId(next));
      else if (isWater(n) && n !== B.water && waterLevel(n) < next) w.setBlock(x + dx, y, z + dz, waterId(next));
    }
  }

  // Lava: source = level 4, flows 3 blocks, never creates new sources. Touching water (from above or the side)
  // turns a source into obsidian and flowing lava into cobblestone; lava falling onto water makes stone.
  updateLava(x, y, z, id) {
    const w = this.world;
    const level = lavaLevel(id);
    let water = isWater(w.getBlock(x, y + 1, z));
    if (!water) for (const [dx, dz] of SIDES) if (isWater(w.getBlock(x + dx, y, z + dz))) { water = true; break; }
    if (water) { this.harden(x, y, z, level >= 4 ? B.obsidian : B.cobblestone); return; }
    if (level < 4) {
      let expected;
      if (isLava(w.getBlock(x, y + 1, z))) expected = 3;
      else {
        let maxN = 0;
        for (const [dx, dz] of SIDES) { const n = w.getBlock(x + dx, y, z + dz); if (isLava(n)) maxN = Math.max(maxN, lavaLevel(n)); }
        expected = maxN - 1;
      }
      if (expected <= 0) { w.setBlock(x, y, z, B.air); return; }
      if (expected !== level) { w.setBlock(x, y, z, lavaId(expected)); return; }
    }
    const below = y > 0 ? w.getBlock(x, y - 1, z) : B.bedrock;
    if (y > 0 && isWater(below)) { this.harden(x, y - 1, z, B.stone); return; }
    if (y > 0 && this.passable(below)) { this.replaceInto(x, y - 1, z, lavaId(3), false); return; }
    if (isLava(below) && below !== B.lava) return;
    const next = level - 1;
    if (next <= 0) return;
    for (const [dx, dz] of SIDES) {
      const n = w.getBlock(x + dx, y, z + dz);
      if (this.passable(n)) this.replaceInto(x + dx, y, z + dz, lavaId(next), false);
      else if (isLava(n) && n !== B.lava && lavaLevel(n) < next) w.setBlock(x + dx, y, z + dz, lavaId(next));
    }
  }

  harden(x, y, z, id) {
    const w = this.world;
    w.setBlock(x, y, z, id);
    this.sound("fizz", x, y, z, 0.7);
    w.game?.renderer?.particles?.smoke(x + 0.5, y + 1, z + 0.5, 6);
  }

  // ---------------------------------------------------------------- fire: spreading to flammable blocks, burning out
  flammableAround(x, y, z) {
    const w = this.world;
    for (const [dx, dy, dz] of N6) if (CATCH[w.getBlock(x + dx, y + dy, z + dz)]) return true;
    return false;
  }

  // Fire stays where something solid is below it or anything flammable touches it.
  fireCanSurvive(x, y, z) {
    return COLLIDE[this.world.getBlock(x, y - 1, z)] === 1 || this.flammableAround(x, y, z);
  }

  exposed(x, y, z) { return this.world.topY(x, z) < y; }
  rainingAt(x, y, z) { return this.raining && this.exposed(x, y, z); }

  placeFire(x, y, z, age) {
    if (this.world.setBlock(x, y, z, B.fire)) this.fireAge.set(`${x},${y},${z}`, Math.min(15, age));
  }

  tickFire(x, y, z) {
    const w = this.world, k = `${x},${y},${z}`;
    let age = this.fireAge.get(k) ?? 0;
    const below = w.getBlock(x, y - 1, z);
    const sturdy = COLLIDE[below] === 1;
    const fuel = this.flammableAround(x, y, z);
    if (!sturdy && !fuel) { w.setBlock(x, y, z, B.air); return; }
    if (this.rainingAt(x, y, z) && Math.random() < 0.2 + age * 0.03) {
      w.setBlock(x, y, z, B.air);
      this.sound("extinguish", x, y, z, 0.6);
      return;
    }
    age = Math.min(15, age + (rand(3) === 2 ? 1 : 0));
    this.fireAge.set(k, age);
    this.schedule(x, y, z, 30 + rand(10));
    if (!fuel) { if (age > 3) w.setBlock(x, y, z, B.air); return; } // fire on bare stone dies out after a while
    if (age === 15 && rand(4) === 0 && !BURN[below]) { w.setBlock(x, y, z, B.air); return; }
    // burn the blocks it touches
    this.burnOut(x + 1, y, z, 300, age); this.burnOut(x - 1, y, z, 300, age);
    this.burnOut(x, y - 1, z, 250, age); this.burnOut(x, y + 1, z, 250, age);
    this.burnOut(x, y, z + 1, 300, age); this.burnOut(x, y, z - 1, 300, age);
    // spread to nearby air next to flammable blocks (mostly upwards)
    for (let dy = -1; dy <= 4; dy++) for (let dz = -1; dz <= 1; dz++) for (let dx = -1; dx <= 1; dx++) {
      if (!dx && !dy && !dz) continue;
      const tx = x + dx, ty = y + dy, tz = z + dz;
      if (ty < 1 || ty >= HEIGHT || w.getBlock(tx, ty, tz) !== B.air) continue;
      let enc = 0;
      for (const [ex, ey, ez] of N6) enc = Math.max(enc, CATCH[w.getBlock(tx + ex, ty + ey, tz + ez)]);
      if (!enc) continue;
      const odds = Math.floor((enc + 40 + 14) / (age + 30));
      const l = 100 + (dy > 1 ? (dy - 1) * 100 : 0);
      if (odds > 0 && rand(l) <= odds && !this.rainingAt(tx, ty, tz)) this.placeFire(tx, ty, tz, age + (rand(5) >> 2));
    }
  }

  burnOut(x, y, z, chance, age) {
    const w = this.world;
    const id = w.getBlock(x, y, z);
    if (!BURN[id] || rand(chance) >= BURN[id]) return;
    if (rand(age + 10) < 5 && !this.rainingAt(x, y, z)) this.placeFire(x, y, z, age + (rand(5) >> 2));
    else w.setBlock(x, y, z, B.air);
    if (blocks[id].tnt) w.game?.entities?.spawnTNT(x + 0.5, y, z + 0.5, 4);
  }

  // ---------------------------------------------------------------- ambient ticks
  ambientTicks(px, pz) {
    if ((this.round++ & 1) === 0) return;
    const w = this.world, R = this.randomRadius, v = w.v;
    const pcx = Math.floor(px / 16), pcz = Math.floor(pz / 16);
    for (let dz = -R; dz <= R; dz++) for (let dx = -R; dx <= R; dx++) {
      const cx = pcx + dx, cz = pcz + dz;
      if (!v.loaded(cx, cz)) continue;
      for (let k = 0; k < RANDOM_PER_CHUNK; k++) {
        const x = cx * 16 + ((Math.random() * 16) | 0), z = cz * 16 + ((Math.random() * 16) | 0);
        // most interesting blocks live near the surface: sample there twice as often
        const top = k & 1 ? v.top(x, z) : -1;
        const y = top >= 0 ? top - ((Math.random() * 3) | 0) : (Math.random() * HEIGHT) | 0;
        const id = v.get(x, y, z);
        const kind = id > 0 ? RANDOM[id] : 0;
        if (kind) this.ambientTick(kind, x, y, z, id);
      }
    }
  }

  light(x, y, z) { const l = this.world.getLight(x, y, z); return Math.max(l >> 4, l & 15); }

  hydrated(x, y, z) {
    const w = this.world;
    for (let dy = 0; dy <= 1; dy++) for (let dz = -4; dz <= 4; dz++) for (let dx = -4; dx <= 4; dx++) {
      if (isWater(w.getBlock(x + dx, y + dy, z + dz))) return true;
    }
    return false;
  }

  ambientTick(kind, x, y, z, id) {
    const w = this.world;
    switch (kind) {
      case RT.GRASS: {
        const above = w.getBlock(x, y + 1, z);
        if (OPACITY[above] >= 15 || above === B.water) { w.setBlock(x, y, z, B.dirt); return; }
        if (this.light(x, y + 1, z) < 9) return;
        for (let i = 0; i < 4; i++) {
          const tx = x + rand(3) - 1, ty = y + rand(5) - 3, tz = z + rand(3) - 1;
          if (w.getBlock(tx, ty, tz) !== B.dirt) continue;
          const up = w.getBlock(tx, ty + 1, tz);
          if (OPACITY[up] < 15 && !isLiquid(up) && this.light(tx, ty + 1, tz) >= 4) w.setBlock(tx, ty, tz, B.grass);
        }
        return;
      }
      case RT.FARMLAND: {
        const above = w.getBlock(x, y + 1, z);
        if (SOLID[above]) { w.setBlock(x, y, z, B.dirt); return; }
        if (!this.hydrated(x, y, z) && !this.rainingAt(x, y + 1, z) && blocks[above].crop === undefined && rand(4) === 0) w.setBlock(x, y, z, B.dirt);
        return;
      }
      case RT.CROP: {
        if (this.light(x, y, z) < 9) return;
        const wet = this.hydrated(x, y - 1, z) || this.rainingAt(x, y, z);
        if (Math.random() * (wet ? 3 : 6) < RANDOM_BOOST * 0.5) w.setBlock(x, y, z, id + 1);
        return;
      }
      case RT.SAPLING:
        if (this.light(x, y + 1, z) >= 9 && Math.random() * 7 < RANDOM_BOOST * 0.5) this.growTree(x, y, z, blocks[id].sapling);
        return;
      case RT.CACTUS: {
        if (w.getBlock(x, y + 1, z) !== B.air || Math.random() * 16 > RANDOM_BOOST * 0.5) return;
        let h = 1;
        while (h < 3 && w.getBlock(x, y - h, z) === B.cactus) h++;
        if (h < 3) w.setBlock(x, y + 1, z, B.cactus);
        return;
      }
      case RT.LAVA: this.lavaSpark(x, y, z); if (id !== B.lava) this.ensureScheduled(x, y, z); return;
      case RT.PENDING: this.ensureScheduled(x, y, z); return;
    }
  }

  ensureScheduled(x, y, z) { if (!this.scheduled.has(`${x},${y},${z}`)) this.schedule(x, y, z, this.delayFor(x, y, z)); }

  // Lava sparks: now and then air above or beside lava catches fire when something flammable touches it.
  lavaSpark(x, y, z) {
    const w = this.world;
    const n = rand(3);
    if (n > 0) {
      let px = x, py = y, pz = z;
      for (let j = 0; j < n; j++) {
        px += rand(3) - 1; py += 1; pz += rand(3) - 1;
        if (py >= HEIGHT) return;
        const id = w.getBlock(px, py, pz);
        if (id === B.air) { if (this.flammableAround(px, py, pz)) { this.placeFire(px, py, pz, 0); return; } }
        else if (COLLIDE[id]) return;
      }
    } else {
      for (let j = 0; j < 3; j++) {
        const px = x + rand(3) - 1, pz = z + rand(3) - 1;
        if (w.getBlock(px, y + 1, pz) === B.air && CATCH[w.getBlock(px, y, pz)]) this.placeFire(px, y + 1, pz, 0);
      }
    }
  }

  // Grows a sapling at (x, y, z) into a tree if there is room. Returns true on success.
  growTree(x, y, z, kind) {
    const w = this.world;
    const list = treeBlocks(kind, x, y - 1, z, (Math.random() * 1e9) | 0);
    for (const [tx, ty, tz, , trunk] of list) {
      if (ty >= HEIGHT) return false;
      if (!trunk) continue;
      if (tx === x && ty === y && tz === z) continue;
      const cur = w.getBlock(tx, ty, tz);
      const d = blocks[cur];
      if (!(cur === B.air || d.leaves || (d.replaceable && !isLiquid(cur)) || d.sapling)) return false;
    }
    const ground = w.getBlock(x, y - 1, z);
    if (ground === B.grass || ground === B.farmland || ground === B.snowy_grass) w.setBlock(x, y - 1, z, B.dirt);
    w.setBlock(x, y, z, B.air);
    for (const [tx, ty, tz, tid, trunk] of list) {
      const cur = w.getBlock(tx, ty, tz);
      const d = blocks[cur];
      if (trunk || cur === B.air || d.leaves || (d.replaceable && !isLiquid(cur))) w.setBlock(tx, ty, tz, tid);
    }
    return true;
  }
}
