// The game's view of the world: a g3d.voxels world (SDK 1.7: chunks, generation, light, meshes, saving on
// background threads) plus block entities (chests, furnaces) and the block updater (water, lava, fire, growth).
import { blocks, B, COLLIDE, SOLID, voxelDef } from "./registry.js";
import { BlockUpdater } from "./updater.js";
import { chunkDir } from "./storage.js";

export const CHUNK = 16, HEIGHT = 128, SEA_LEVEL = 62, FLAT_Y = 3;

export class GameWorld {
  constructor(meta, settings) {
    this.meta = meta;
    this.seed = meta.seed | 0;
    this.renderDistance = settings.renderDistance;
    this.v = g3d.voxels({
      atlas: "bundle:/textures/atlas.png", tiles: 16, height: HEIGHT, seed: this.seed, sea: SEA_LEVEL, flatY: FLAT_Y,
      generator: meta.type === "flat" ? "flat" : "terrain", save: meta.id ? chunkDir(meta.id) : "", threads: 2,
      blocks: {
        stone: B.stone, grass: B.grass, dirt: B.dirt, sand: B.sand, sandstone: B.sandstone, gravel: B.gravel, bedrock: B.bedrock,
        water: B.water, lava: B.lava, ice: B.ice, snow: B.snow, snowyGrass: B.snowy_grass, coalOre: B.coal_ore,
        ironOre: B.iron_ore, goldOre: B.gold_ore, diamondOre: B.diamond_ore, oakLog: B.oak_log, oakLeaves: B.oak_leaves,
        birchLog: B.birch_log, birchLeaves: B.birch_leaves, spruceLog: B.spruce_log, spruceLeaves: B.spruce_leaves,
        cactus: B.cactus, tallGrass: B.tall_grass, dandelion: B.dandelion, poppy: B.poppy, deadBush: B.dead_bush,
      },
    });
    for (const d of blocks) if (d.id > 0) this.v.define(d.id, voxelDef(d));
    this.blockEntities = new Map();   // "x,y,z" -> { type, slots, ... }
    this.updater = new BlockUpdater(this);
    this.game = null;
    this.fresh = [];                  // chunks generated in the last update (decorated by the game)
  }

  // ---------- blocks ----------
  getBlock(x, y, z) { const id = this.v.get(x, y, z); return id < 0 ? 0 : id; }
  isLoaded(x, z) { return this.v.loaded(Math.floor(x / CHUNK), Math.floor(z / CHUNK)); }
  setBlock(x, y, z, id, opts) {
    x = Math.floor(x); y = Math.floor(y); z = Math.floor(z);
    if (y < 0 || y >= HEIGHT) return false;
    const old = this.v.get(x, y, z);
    if (old < 0) return false;
    if (!this.v.set(x, y, z, id)) return false;
    if (old !== id && !(opts && opts.update === false)) this.updater.onChanged(x, y, z, old, id);
    return true;
  }
  collides(x, y, z) { return COLLIDE[this.getBlock(x, y, z)] === 1; }
  solid(x, y, z) { return SOLID[this.getBlock(x, y, z)] === 1; }
  topY(x, z) { return this.v.top(Math.floor(x), Math.floor(z)); }
  getLight(x, y, z) { const l = this.v.light(x, y, z); return l ? (l[0] << 4) | l[1] : 0xF0; }
  skyLight(x, y, z) { const l = this.v.light(x, y, z); return l ? l[0] : 15; }
  biome(x, z) { return this.v.biome(x, z); }

  // ---------- block entities ----------
  key(x, y, z) { return `${x},${y},${z}`; }
  getBlockEntity(x, y, z) { return this.blockEntities.get(this.key(x, y, z)) || null; }
  setBlockEntity(x, y, z, be) { this.blockEntities.set(this.key(x, y, z), be); }
  removeBlockEntity(x, y, z) {
    const k = this.key(x, y, z), be = this.blockEntities.get(k);
    if (be) this.blockEntities.delete(k);
    return be || null;
  }

  // ---------- streaming ----------
  update(px, pz) {
    this.v.view(px, pz, this.renderDistance);
    const gen = this.v.update();
    this.fresh.length = 0;
    for (let i = 0; i + 1 < gen.length; i += 2) this.fresh.push([gen[i], gen[i + 1]]);
    return this.fresh;
  }
  // loaded chunks within r of the player (for the loading screen)
  progress(px, pz, r) {
    const cx = Math.floor(px / CHUNK), cz = Math.floor(pz / CHUNK);
    let done = 0, total = 0;
    for (let dz = -r; dz <= r; dz++) for (let dx = -r; dx <= r; dx++) { total++; if (this.v.loaded(cx + dx, cz + dz)) done++; }
    const s = this.v.stats();
    return { done, total, meshed: s.meshed };
  }
  save() { return this.v.save(); }
  dispose() { this.v.close(); }
}
