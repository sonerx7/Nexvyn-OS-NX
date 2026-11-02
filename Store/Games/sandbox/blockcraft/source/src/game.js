// Game: one loaded world session and its main loop: loading, villages and ore veins in new chunks, beds, death and
// respawn, furnaces, ambient block effects, the camera and saving.
import { blocks, B, I, maxStack, isLiquid, isWater, isLava, DIR4, itemDef } from "./registry.js";
import { GameWorld, CHUNK, HEIGHT, SEA_LEVEL, FLAT_Y } from "./world.js";
import { Player } from "./player.js";
import { Inventory, stack, serializeStacks, deserializeStacks } from "./inventory.js";
import { EntityManager } from "./entities.js";
import { Mob, MobSpawner } from "./mobs.js";
import { Weather } from "./weather.js";
import { Interaction, raycastBlocks } from "./interaction.js";
import { smeltResult, fuelSeconds, SMELT_SECONDS, newFurnace, newChest } from "./crafting.js";
import { villagePlan, stampVillage, VILLAGE_CELL } from "./structures.js";
import { carveChunk } from "./caves.js";
import { Renderer } from "./render.js";
import { saveWorld } from "./storage.js";
import { mulberry32, angleDiff } from "./util.js";

export const DAY_SECONDS = 1200;
const TICK = 1 / 20;
const AUTOSAVE_SECONDS = 30;
const RUMBLE_MAX_MS = 90, RUMBLE_GAP = 0.25, RUMBLE_WATCHDOG = 0.5;
const CREATIVE_HOTBAR = [B.grass, B.dirt, B.stone, B.cobblestone, B.planks, B.oak_log, B.glass, B.torch, B.bricks];
const LOOT = [
  [I.bread, 1, 4, 0.6], [I.apple, 1, 3, 0.45], [I.wheat, 2, 8, 0.4], [I.wheat_seeds, 2, 6, 0.4], [I.iron_ingot, 1, 4, 0.35],
  [I.coal, 2, 6, 0.4], [B.torch, 2, 8, 0.3], [B.sapling_oak, 1, 3, 0.3], [I.gold_ingot, 1, 2, 0.15],
  [I.diamond, 1, 2, 0.06], [I.bucket, 1, 1, 0.15], [I.leather, 1, 3, 0.2], [I.bone, 1, 3, 0.2],
];
const SAPLING_OF = { [B.oak_leaves]: B.sapling_oak, [B.birch_leaves]: B.sapling_birch, [B.spruce_leaves]: B.sapling_spruce };

export class Game {
  constructor(app, meta) {
    this.app = app;
    this.meta = meta;
    this.mode = meta.mode || "survival";
    this.settings = app.settings;
    this.input = app.input;
    this.sound = app.sound;
    this.hud = app.hud;
    this.world = new GameWorld(meta, this.settings);
    this.world.game = this;
    this.loadBlockEntities(meta.blockEntities);
    this.player = new Player(this);
    this.inventory = new Inventory();
    this.entities = new EntityManager(this);
    this.spawner = new MobSpawner(this);
    this.weather = new Weather(this, meta.weather);
    this.interaction = new Interaction(this);
    this.renderer = new Renderer(this);
    this.time = typeof meta.time === "number" ? meta.time : 0.02;
    this.daylight = 1;
    this.clock = 0;
    this.tickAcc = 0;
    this.saveTimer = 0;
    this.shake = 0;
    this.state = "loading";   // loading | playing | screen | dead
    this.cameraMode = 0;
    this.camDist = 4;
    this.loadTime = 0;
    this.parked = Array.isArray(meta.entities) ? meta.entities.slice() : [];
    this.villages = new Map();  // "cx,cz" -> plan | null
    this.cleared = new Set();
    this.columnCache = new Map();
    this.fps = 60; this.fpsAcc = 0; this.fpsFrames = 0;
    this.prepare();
  }

  // generator height + biome of a column (cached)
  column(x, z) {
    const k = x * 65536 + z;
    let c = this.columnCache.get(k);
    if (!c) {
      const r = this.world.v.terrain(x, z);
      c = { h: r[0], biome: r[1] };
      if (this.columnCache.size > 20000) this.columnCache.clear();
      this.columnCache.set(k, c);
    }
    return c;
  }

  village(cx, cz) {
    const k = `${cx},${cz}`;
    if (!this.villages.has(k)) this.villages.set(k, villagePlan(cx, cz, this.world.seed, (x, z) => this.column(x, z)));
    return this.villages.get(k);
  }

  villagesNear(x, z, radius) {
    const out = [];
    if (this.meta.type !== "normal") return out;
    const c0x = Math.floor((x - radius) / VILLAGE_CELL), c1x = Math.floor((x + radius) / VILLAGE_CELL);
    const c0z = Math.floor((z - radius) / VILLAGE_CELL), c1z = Math.floor((z + radius) / VILLAGE_CELL);
    for (let cz = c0z; cz <= c1z; cz++) for (let cx = c0x; cx <= c1x; cx++) {
      const p = this.village(cx, cz);
      if (p && Math.hypot(p.x - x, p.z - z) < radius) out.push({ key: `${cx},${cz}`, plan: p });
    }
    return out;
  }

  // Village areas near the player: no trees there (registered before their chunks are generated).
  planVillages(x, z) {
    if (this.meta.type !== "normal") return;
    const r = (this.settings.renderDistance + 4) * CHUNK;
    const c0x = Math.floor((x - r) / VILLAGE_CELL), c1x = Math.floor((x + r) / VILLAGE_CELL);
    const c0z = Math.floor((z - r) / VILLAGE_CELL), c1z = Math.floor((z + r) / VILLAGE_CELL);
    for (let cz = c0z; cz <= c1z; cz++) for (let cx = c0x; cx <= c1x; cx++) {
      const k = `${cx},${cz}`;
      if (this.cleared.has(k)) continue;
      this.cleared.add(k);
      const p = this.village(cx, cz);
      if (p) this.world.v.clearArea(p.minX, p.minZ, p.maxX, p.maxZ);
    }
  }

  // Freshly generated chunks: sulfur veins in the stone, then the villages that reach into them.
  decorate(fresh) {
    const seed = this.world.seed, v = this.world.v;
    for (const [cx, cz] of fresh) {
      const x0 = cx * CHUNK, z0 = cz * CHUNK;
      if (this.meta.type === "normal") {
        this.carveCaves(cx, cz);
        this.sulfurVeins(cx, cz);
        for (let vz = Math.floor((z0 - 64) / VILLAGE_CELL); vz <= Math.floor((z0 + 80) / VILLAGE_CELL); vz++)
          for (let vx = Math.floor((x0 - 64) / VILLAGE_CELL); vx <= Math.floor((x0 + 80) / VILLAGE_CELL); vx++) {
            const p = this.village(vx, vz);
            if (p) stampVillage(p, seed, x0, z0, (x, y, z, id) => v.set(x, y, z, id), (x, z) => this.column(x, z));
          }
      }
    }
  }

  // Tunnels, chambers, surface mouths and deep pools (caves.js) carved as bytes into the fresh chunk.
  carveCaves(cx, cz) {
    const v = this.world.v;
    const data = v.chunk(cx, cz);
    if (!data) return;
    if (!this.caveCache) this.caveCache = new Map();
    const x0 = cx * CHUNK, z0 = cz * CHUNK;
    const rects = this.villagesNear(x0 + 8, z0 + 8, 120).map(({ plan: p }) => [p.minX - 3, p.minZ - 3, p.maxX + 3, p.maxZ + 3]);
    const avoid = (x, z) => this.villagesNear(x, z, 40).length > 0;
    if (carveChunk(data, cx, cz, HEIGHT, this.world.seed, (x, z) => this.column(x, z), this.meta.caveSpawn, avoid, rects, this.caveCache))
      v.setChunk(cx, cz, data);
  }

  // Two to four small veins of sulfur ore per chunk between y 6 and 48, only inside stone. The same seed always
  // gives the same veins (chunks that were never edited are generated again when they load).
  sulfurVeins(cx, cz) {
    const v = this.world.v, x0 = cx * CHUNK, z0 = cz * CHUNK;
    const rnd = mulberry32((Math.imul(cx, 341873128) ^ Math.imul(cz, 132897987) ^ (this.world.seed * 7 + 0x51F)) | 0);
    const veins = 2 + Math.floor(rnd() * 3);
    for (let n = 0; n < veins; n++) {
      let x = Math.floor(rnd() * 16), y = 6 + Math.floor(rnd() * 42), z = Math.floor(rnd() * 16);
      const size = 3 + Math.floor(rnd() * 5);
      for (let k = 0; k < size; k++) {
        if (v.get(x0 + x, y, z0 + z) === B.stone) v.set(x0 + x, y, z0 + z, B.sulfur_ore);
        const d = Math.floor(rnd() * 6);
        if (d === 0) x = Math.min(15, x + 1); else if (d === 1) x = Math.max(0, x - 1);
        else if (d === 2) z = Math.min(15, z + 1); else if (d === 3) z = Math.max(0, z - 1);
        else if (d === 4) y = Math.min(52, y + 1); else y = Math.max(5, y - 1);
      }
    }
  }

  onChunksLoaded() {
    if (!this.parked.length) return;
    for (let i = this.parked.length - 1; i >= 0; i--) {
      const d = this.parked[i];
      if (!this.world.isLoaded(d.x, d.z)) continue;
      this.parked.splice(i, 1);
      if (d.kind === "mob") this.spawner.spawnSaved(d);
    }
  }

  // ---------- loading ----------
  prepare() {
    const p = this.player, m = this.meta;
    this.fresh = !m.player;
    if (this.fresh) {
      const s = this.findSpawn();
      p.pos.x = s.x; p.pos.y = s.y; p.pos.z = s.z;
      p.spawn = { x: s.x, y: s.y, z: s.z };
      p.yaw = Math.PI * 0.75;
      this.spawnInfo = s;
      if (this.mode === "creative") CREATIVE_HOTBAR.forEach((id, i) => { this.inventory.slots[i] = stack(id, 64); });
    } else {
      p.load(m.player);
      this.inventory.load(m.inventory);
    }
    // the world spawn that guarantees a cave mouth nearby (kept so the caves stay the same in this world)
    if (!m.caveSpawn) m.caveSpawn = { x: Math.floor(p.spawn ? p.spawn.x : p.pos.x), z: Math.floor(p.spawn ? p.spawn.z : p.pos.z) };
    this.planVillages(p.pos.x, p.pos.z);
  }

  findSpawn() {
    if (this.meta.type === "flat") return { x: 0.5, y: FLAT_Y + 1, z: 0.5 };
    let best = null;
    for (let r = 0; r <= 3 && !best; r++) for (let cz = -r; cz <= r; cz++) for (let cx = -r; cx <= r; cx++) {
      if (Math.max(Math.abs(cx), Math.abs(cz)) !== r) continue;
      const p = this.village(cx, cz);
      if (p && (!best || Math.hypot(p.x, p.z) < Math.hypot(best.x, best.z))) best = p;
    }
    if (best) {
      const x = best.x + 3, z = best.z + 6;
      return { x: x + 0.5, y: this.column(x, z).h + 2, z: z + 0.5, village: true };
    }
    for (let r = 0; r < 4096; r += 8) {
      const steps = Math.max(1, Math.round(r / 4));
      for (let k = 0; k < steps; k++) {
        const a = (k / steps) * Math.PI * 2;
        const x = Math.round(Math.cos(a) * r), z = Math.round(Math.sin(a) * r);
        const c = this.column(x, z);
        if (c.h > SEA_LEVEL + 1 && c.biome !== 6) return { x: x + 0.5, y: c.h + 1, z: z + 0.5 };
      }
    }
    return { x: 0.5, y: HEIGHT - 10, z: 0.5 };
  }

  // Called every frame while loading; true once the area around the player is meshed.
  loadStep(dt) {
    const p = this.player;
    this.loadTime += dt;
    this.updateWorld();
    const pr = this.world.progress(p.pos.x, p.pos.z, 2);
    this.loadProgress = pr.done / Math.max(1, pr.total) * 0.6 + Math.min(1, pr.meshed / 20) * 0.4;
    const ready = (pr.done >= pr.total && pr.meshed >= 9) || this.loadTime > 25;
    if (!ready) return false;
    if (this.fresh) this.placeAtSpawn();
    else if (this.world.collides(Math.floor(p.pos.x), Math.floor(p.pos.y + 0.5), Math.floor(p.pos.z))) this.placeAtSpawn(true);
    this.state = "playing";
    const t = this.meta.type;
    if (this.spawnInfo && this.spawnInfo.village) this.hud.message(TR("msg.spawn_village"));
    else if (this.fresh) this.hud.message(TR(this.mode === "creative" ? "msg.creative_hint" : "msg.survival_hint"));
    void t;
    return true;
  }

  placeAtSpawn(keepXZ = false) {
    const w = this.world, p = this.player;
    const bx = Math.floor(keepXZ ? p.pos.x : p.spawn.x), bz = Math.floor(keepXZ ? p.pos.z : p.spawn.z);
    for (let r = 0; r <= 10; r++) for (let dz = -r; dz <= r; dz++) for (let dx = -r; dx <= r; dx++) {
      if (Math.max(Math.abs(dx), Math.abs(dz)) !== r) continue;
      const x = bx + dx, z = bz + dz;
      const y = w.topY(x, z);
      if (y < 0) continue;
      const top = w.getBlock(x, y, z);
      if (isLiquid(top) || blocks[top].leaves || blocks[top].log || top === B.cactus || blocks[top].door || blocks[top].model === "fence") continue;
      p.pos.x = x + 0.5; p.pos.y = y + 1; p.pos.z = z + 0.5;
      if (!keepXZ) p.spawn = { x: p.pos.x, y: p.pos.y, z: p.pos.z };
      return;
    }
  }

  // ---------- screens ----------
  openScreen(kind, be) {
    if (this.state !== "playing") return;
    this.state = "screen";
    this.stopRumble();
    this.interaction.reset();
    this.app.invui.open(kind, be);
  }
  closeScreen() {
    if (this.state !== "screen") return;
    this.app.invui.close();
    this.state = "playing";
  }
  openBlockScreen(kind, x, y, z) {
    if (kind === "crafting") return this.openScreen("crafting");
    let be = this.world.getBlockEntity(x, y, z);
    if (!be) {
      be = kind === "furnace" ? newFurnace() : newChest();
      if (kind === "chest") this.fillLoot(be, x, y, z);
      this.world.setBlockEntity(x, y, z, be);
    }
    if (kind === "chest") this.sound.play("door_open", { x: x + 0.5, y: y + 0.5, z: z + 0.5, volume: 0.6 });
    this.openScreen(kind, be);
  }
  fillLoot(be, x, y, z) {
    if (this.meta.type !== "normal") return;
    const rnd = mulberry32((Math.imul(x, 73856093) ^ Math.imul(y, 19349663) ^ Math.imul(z, 83492791) ^ this.meta.seed) | 0);
    for (const [id, a, b, chance] of LOOT) {
      if (rnd() >= chance) continue;
      const free = be.slots.map((s, i) => (s ? -1 : i)).filter(i => i >= 0);
      if (!free.length) break;
      be.slots[free[(rnd() * free.length) | 0]] = stack(id, a + Math.floor(rnd() * (b - a + 1)));
    }
  }
  toggleMode() {
    this.mode = this.mode === "creative" ? "survival" : "creative";
    this.meta.mode = this.mode;
    if (this.mode === "survival") this.player.flying = false;
    this.hud.message(TR(this.mode === "creative" ? "msg.mode_creative" : "msg.mode_survival"));
  }
  cycleCamera() { this.cameraMode = (this.cameraMode + 1) % 3; }
  // time of day for builders (Creative pause menu): 0 morning, 1 day, 2 evening, 3 night
  dayPhase() { const t = this.time % 1; return t < 0.15 || t >= 0.97 ? 0 : t < 0.42 ? 1 : t < 0.55 ? 2 : 3; }
  nextDayPhase() {
    let t = Math.floor(this.time) + [0.25, 0.47, 0.75, 1.02][this.dayPhase()];
    if (t <= this.time) t += 1;
    this.time = t;
    this.hud.message(`${TR("ui.time")}: ${TR("time." + this.dayPhase())}`);
  }
  // Rumble: short pulses only. Every pulse is at most RUMBLE_MAX_MS long (the system stops pulses up to 200 ms by
  // itself), at most one starts per RUMBLE_GAP seconds, and a watchdog sends an explicit stop shortly after each
  // pulse, so a motor can never be left running (pause, menus, death, quit and close stop it too).
  rumble(strength, ms) {
    if (!this.settings.rumble || this.state === "loading") return;
    const now = this.clock;
    if (now - (this.rumbleAt ?? -1) < RUMBLE_GAP) return;
    this.rumbleAt = now;
    this.rumbleStop = RUMBLE_WATCHDOG;
    const s = Math.max(0, Math.min(1, strength)), d = Math.max(16, Math.min(RUMBLE_MAX_MS, ms | 0));
    try { sys.vibrate(s, d); } catch (e) { /* no rumble */ }
  }
  stopRumble() {
    this.rumbleStop = 0;
    try { sys.vibrate(0, 0); } catch (e) { /* no rumble */ }
  }
  rumbleWatch(dt) {
    if (!(this.rumbleStop > 0)) return;
    this.rumbleStop -= dt;
    if (this.rumbleStop <= 0) this.stopRumble();
  }

  // ---------- beds ----------
  trySleep(x, y, z) {
    const p = this.player, w = this.world;
    const def = blocks[w.getBlock(x, y, z)];
    if (!def.bed) return;
    let hx = x, hz = z;
    if (!def.bed.head) { const [dx, dz] = DIR4[def.bed.facing]; hx += dx; hz += dz; }
    if (!p.bed || p.bed.x !== hx || p.bed.y !== y || p.bed.z !== hz) { p.bed = { x: hx, y, z: hz }; this.hud.message(TR("msg.spawn_set")); }
    const t = this.time % 1;
    if (!(t > 0.53 && t < 0.97) && this.weather.state !== "thunder") { this.hud.message(TR("msg.sleep_night")); return; }
    if (Math.hypot(p.pos.x - x - 0.5, p.pos.z - z - 0.5) > 3.5) { this.hud.message(TR("msg.bed_far")); return; }
    if (this.entities.nearest({ x: x + 0.5, y, z: z + 0.5 }, 8, e => e instanceof Mob && e.def.hostile && e.death < 0)) { this.hud.message(TR("msg.bed_monsters")); return; }
    p.sleeping = { x: hx, y, z: hz, t: 0, facing: def.bed.facing };
    p.vel.x = p.vel.y = p.vel.z = 0;
    this.interaction.reset();
    this.sound.play("sleep");
  }
  updateSleep() {
    const s = this.player.sleeping;
    if (!s) { this.hud.sleep = 0; return; }
    this.hud.sleep = Math.min(1, s.t / 2.5);
    if (s.t >= 2.8) {
      this.time = Math.floor(this.time) + 1.005;
      if (this.weather.state !== "clear") this.weather.set("clear");
      this.wakeUp();
      this.hud.message(TR("msg.good_morning"));
    }
  }
  wakeUp() {
    const p = this.player, s = p.sleeping;
    if (!s) return;
    p.sleeping = null;
    this.hud.sleep = 0;
    const w = this.world;
    for (const [dx, dz] of [[0, 0], ...DIR4, [1, 1], [-1, 1], [1, -1], [-1, -1]]) {
      const x = s.x + dx, z = s.z + dz;
      for (const y of [s.y, s.y + 1]) {
        if (!w.collides(x, y, z) && !w.collides(x, y + 1, z)) {
          p.pos.x = x + 0.5; p.pos.z = z + 0.5;
          p.pos.y = y + (blocks[w.getBlock(x, y, z)].bed ? 0.5625 : 0);
          return;
        }
      }
    }
  }

  onPlayerDeath(cause) {
    this.state = "dead";
    this.interaction.reset();
    if (this.player.sleeping) this.wakeUp();
    if (this.app.invui.isOpen) this.app.invui.close();
    const p = this.player;
    for (let i = 0; i < this.inventory.slots.length; i++) {
      const s = this.inventory.slots[i];
      if (!s) continue;
      const a = Math.random() * Math.PI * 2, v = Math.random() * 3;
      this.entities.spawnItem(p.pos.x, p.pos.y + 1, p.pos.z, s, { x: Math.cos(a) * v, y: 3 + Math.random() * 2, z: Math.sin(a) * v });
      this.inventory.slots[i] = null;
    }
    this.inventory.changed();
    this.deathMessage = TR("death." + cause);
    this.rumbleAt = -1;
    this.rumble(1, 90);
  }
  respawn() {
    this.player.respawn();
    this.state = "playing";
  }

  // ---------- world helpers used by entities / interaction ----------
  lightLevels(x, y, z) {
    const l = this.world.getLight(Math.floor(x), Math.floor(y), Math.floor(z));
    return [(l >> 4) / 15, (l & 15) / 15];
  }
  breakBlock(x, y, z, { drops = true, quiet = false, byPlayer = false } = {}) {
    const w = this.world;
    const id = w.getBlock(x, y, z);
    if (!id) return;
    const def = blocks[id];
    let be = w.removeBlockEntity(x, y, z);
    if (!be && def.use === "chest" && drops) { be = newChest(); this.fillLoot(be, x, y, z); }
    if (be) for (const s of be.slots) if (s) this.entities.spawnItem(x + 0.5, y + 0.5, z + 0.5, s);
    const melt = id === B.ice && byPlayer && !this.player.creative && !isLiquid(w.getBlock(x, y - 1, z)) && w.getBlock(x, y - 1, z) !== B.air;
    w.setBlock(x, y, z, melt ? B.water : B.air);
    if (!quiet) {
      this.sound.play(`break:${def.sound}`, { x: x + 0.5, y: y + 0.5, z: z + 0.5 });
      this.renderer.particles.blockBreak(x, y, z, def);
      if (byPlayer) this.rumble(0.25, 30);
    }
    if (drops) this.spawnBlockDrops(x, y, z, id);
  }
  spawnBlockDrops(x, y, z, id) {
    const def = blocks[id];
    const drop1 = (item, n = 1) => { if (item && n > 0 && itemDef(item)) this.entities.spawnItem(x + 0.5, y + 0.3, z + 0.5, stack(item, n)); };
    if (def.leaves) {
      if (Math.random() < 0.05) drop1(SAPLING_OF[id]);
      else if (id === B.oak_leaves && Math.random() < 0.015) drop1(I.apple);
      return;
    }
    if (def.crop !== undefined) {
      if (def.crop === 3) { drop1(I.wheat); drop1(I.wheat_seeds, Math.floor(Math.random() * 4)); }
      else drop1(I.wheat_seeds);
      return;
    }
    if (id === B.tall_grass) { if (Math.random() < 0.125) drop1(I.wheat_seeds); return; }
    if (id === B.gravel && Math.random() < 0.1) { drop1(I.flint); return; }
    const [lo, hi] = def.dropCount || [1, 1];
    drop1(def.drop, lo + Math.floor(Math.random() * (hi - lo + 1)));
  }
  throwStack(s) {
    if (!s || s.count <= 0) return;
    const p = this.player, d = p.lookDir();
    const e = this.entities.spawnItem(p.pos.x + d.x * 0.3, p.eyeY - 0.3, p.pos.z + d.z * 0.3, s, { x: d.x * 5 + p.vel.x, y: d.y * 5 + 2, z: d.z * 5 + p.vel.z });
    e.pickupDelay = 1.5;
  }

  // ---------- ticks ----------
  tick() {
    this.world.updater.tick();
    this.world.updater.ambientTicks(this.player.pos.x, this.player.pos.z);
    for (const [key, be] of this.world.blockEntities) if (be.type === "furnace") this.tickFurnace(key, be);
  }
  tickFurnace(key, be) {
    const [x, y, z] = key.split(",").map(Number);
    const w = this.world;
    if (!w.isLoaded(x, z)) return;
    const [inp, fuel, out] = be.slots;
    const res = inp ? smeltResult(inp.id) : null;
    const canSmelt = res !== null && (!out || (out.id === res && out.count < maxStack(res)));
    if (be.burn > 0) be.burn = Math.max(0, be.burn - TICK);
    if (be.burn <= 0 && canSmelt && fuel && fuelSeconds(fuel.id) > 0) {
      be.burn = be.burnMax = fuelSeconds(fuel.id);
      if (fuel.id === I.lava_bucket) be.slots[1] = stack(I.bucket, 1);
      else { fuel.count--; if (fuel.count <= 0) be.slots[1] = null; }
    }
    if (be.burn > 0 && canSmelt) {
      be.cook += TICK;
      if (be.cook >= SMELT_SECONDS) {
        be.cook = 0;
        inp.count--;
        if (inp.count <= 0) be.slots[0] = null;
        if (out) out.count++; else be.slots[2] = stack(res, 1);
      }
    } else if (be.cook > 0) be.cook = Math.max(0, be.cook - TICK * 2);
    const id = w.getBlock(x, y, z);
    const def = blocks[id];
    if (def.use === "furnace") {
      const want = (be.burn > 0 ? B.furnace_lit : B.furnace) + def.facing;
      if (want !== id) w.setBlock(x, y, z, want, { update: false });
    }
  }

  // Ambient block effects near the player: flames on fire and torches, lava pops, fire crackle.
  displayTick(dt) {
    const w = this.world, p = this.player, part = this.renderer.particles;
    this.fireSoundT = (this.fireSoundT || 0) - dt;
    this.lavaSoundT = (this.lavaSoundT || 0) - dt;
    const bx = Math.floor(p.pos.x), by = Math.floor(p.pos.y), bz = Math.floor(p.pos.z);
    for (let i = 0; i < 120; i++) {
      const x = bx + ((Math.random() * 25) | 0) - 12, y = by + ((Math.random() * 17) | 0) - 8, z = bz + ((Math.random() * 25) | 0) - 12;
      const id = w.getBlock(x, y, z);
      if (!id) continue;
      if (id === B.fire) {
        part.flame(x + Math.random(), y + Math.random() * 0.7, z + Math.random());
        if (Math.random() < 0.4) part.smoke(x + 0.5, y + 0.9, z + 0.5, 1);
        if (this.fireSoundT <= 0) { this.fireSoundT = 0.4 + Math.random() * 0.8; this.sound.play("fire", { x: x + 0.5, y: y + 0.5, z: z + 0.5 }); }
      } else if (id === B.torch || (id >= B.wall_torch_0 && id <= B.wall_torch_3)) {
        const a = blocks[id].attach;
        const [ax, az] = a === undefined ? [0, 0] : DIR4[a];
        part.flame(x + 0.5 + ax * 0.06, y + (a === undefined ? 0.7 : 0.87), z + 0.5 + az * 0.06);
      } else if (id === B.lava) {
        if (w.getBlock(x, y + 1, z) === B.air && Math.random() < 0.06) {
          part.lavaPop(x + Math.random(), y + 1, z + Math.random());
          if (this.lavaSoundT <= 0) { this.lavaSoundT = 1 + Math.random() * 3; this.sound.play("lava", { x: x + 0.5, y: y + 1, z: z + 0.5, volume: 0.6 }); }
        }
      } else if (id >= B.furnace_lit && id <= B.furnace_lit_3) {
        const [fx, fz] = DIR4[blocks[id].facing];
        const sx = (Math.random() - 0.5) * 0.5;
        part.flame(x + 0.5 + fx * 0.52 + (fz ? sx : 0), y + 0.15 + Math.random() * 0.35, z + 0.5 + fz * 0.52 + (fx ? sx : 0));
      }
    }
  }

  updateWorld() {
    const p = this.player;
    this.planVillages(p.pos.x, p.pos.z);
    const fresh = this.world.update(p.pos.x, p.pos.z);
    if (fresh.length) this.decorate(fresh);
  }

  // ---------- frame ----------
  frame(dt) {
    const input = this.input, p = this.player;
    this.clock += dt;
    this.rumbleWatch(dt);
    this.fpsAcc += dt; this.fpsFrames++;
    if (this.fpsAcc >= 0.5) { this.fps = Math.round(this.fpsFrames / this.fpsAcc); this.fpsAcc = 0; this.fpsFrames = 0; }
    if (this.state === "playing" && this.clock > 20) {
      this.slowT = this.fps < 25 ? (this.slowT || 0) + dt : 0;
      if (this.slowT > 12 && this.settings.renderDistance > 4) {
        this.slowT = 0;
        this.settings.renderDistance--;
        this.world.renderDistance = this.settings.renderDistance;
        this.app.saveSettings();
        this.hud.message(TR("msg.view_lowered", this.settings.renderDistance));
      }
    }
    // memory guard: drop caches when the script heap fills up, then shrink the view before it runs out
    this.memT = (this.memT || 0) + dt;
    if (this.memT >= 2) {
      this.memT = 0;
      const use = this.app.memUse ? this.app.memUse() : 0;
      if (use > 0.8) { this.columnCache.clear(); if (this.caveCache) this.caveCache.clear(); }
      if (use > 0.9 && this.settings.renderDistance > 3) {
        this.settings.renderDistance--;
        this.world.renderDistance = this.settings.renderDistance;
        this.hud.message(TR("msg.low_memory_view", this.settings.renderDistance));
      }
    }
    this.perfT = (this.perfT || 0) + dt;
    if (this.perfT >= 5 && this.state !== "loading" && (this.clock < 90 || this.hud.debug)) {
      this.perfT = 0;
      const s = this.world.v.stats();
      console.log(`perf fps=${this.fps} rd=${this.settings.renderDistance} chunks=${s.chunks} meshed=${s.meshed} visible=${s.visible} quads=${s.quads} draws=${s.drawCalls} gen=${s.genMs.toFixed(1)}ms mesh=${s.meshMs.toFixed(1)}ms entities=${this.entities.list.length}`);
    }
    if (this.state === "loading") { this.loadStep(dt); this.updateEnv(dt); this.updateCamera(dt); return; }

    if (this.state === "playing") {
      const k = input.hotbarKey();
      if (k >= 0) { this.inventory.selected = k; this.inventory.changed(); }
      const d = input.hotbarDelta();
      if (d) { this.inventory.selected = (this.inventory.selected + d + 9) % 9; this.inventory.changed(); this.hud.showItemName(); }
      if (input.inventoryPressed()) this.openScreen(this.mode === "creative" ? "creative" : "inventory");
      if (input.keyPressed("f3")) this.hud.debug = !this.hud.debug;
      if (input.keyPressed("f1")) this.hud.hidden = !this.hud.hidden;
      if (input.keyPressed("t") && this.mode === "creative") this.nextDayPhase();
      if (input.cameraPressed()) this.cycleCamera();
      if (p.sleeping && (input.sneakHeld() || input.jumpPressed())) this.wakeUp();
      if (this.state === "playing") {
        p.update(dt, input, this.settings);
        this.interaction.update(dt, input);
      }
    } else if (this.state === "screen") {
      this.app.invui.update(dt);
    }

    this.time += dt / DAY_SECONDS;
    this.tickAcc = Math.min(this.tickAcc + dt, TICK * 6);
    while (this.tickAcc >= TICK) { this.tick(); this.tickAcc -= TICK; }
    this.entities.update(dt);
    this.spawner.update(dt);
    this.weather.update(dt);
    this.updateSleep();
    this.displayTick(dt);
    this.renderer.particles.update(dt, this.world);
    if (this.renderer.hand.swingT < 1) this.renderer.hand.swingT = Math.min(1, this.renderer.hand.swingT + dt * 3.3);
    if (this.state !== "dead") {
      this.saveTimer += dt;
      if (this.saveTimer >= AUTOSAVE_SECONDS) { this.saveTimer = 0; this.save(); }
    }
    this.updateWorld();
    this.onChunksLoaded();
    this.updateEnv(dt);
    this.updateCamera(dt);
    this.sound.setListener(p.pos.x, p.eyeY, p.pos.z);
    this.sound.update(dt, this.state === "playing");
  }

  updateEnv() {
    const p = this.player, w = this.weather;
    const eyeBlock = this.world.getBlock(Math.floor(p.pos.x), Math.floor(p.eyeY), Math.floor(p.pos.z));
    this.renderer.updateEnvironment(this.time % 1, {
      renderDistance: this.settings.renderDistance, underwater: isWater(eyeBlock), inLava: isLava(eyeBlock),
      rain: w.rain, thunder: w.thunder, flash: w.flash,
    });
    this.daylight = this.renderer.daylight;
  }

  // First person, or a third-person camera that backs off from walls.
  updateCamera(dt) {
    const p = this.player, cam = this.renderer.cam, s = this.settings;
    this.shake = Math.max(0, this.shake - dt * 1.5);
    let yaw = p.yaw, pitch = p.pitch;
    let roll = p.dead ? 0.5 : p.hurtTime > 0 ? p.hurtTilt * Math.sin((p.hurtTime / 0.35) * Math.PI) * 0.07 : 0;
    let x = p.pos.x, y = p.dead ? p.pos.y + 0.3 : p.eyeY, z = p.pos.z;
    if (p.sleeping) { const sl = p.sleeping; x = sl.x + 0.5; y = sl.y + 0.55; z = sl.z + 0.5; pitch = 0.7; }
    const mode = p.dead || p.sleeping ? 0 : this.cameraMode;
    if (mode > 0) {
      const cp = Math.cos(pitch), sgn = mode === 1 ? 1 : -1;
      const dx = Math.sin(yaw) * cp * sgn, dy = -Math.sin(pitch) * sgn, dz = Math.cos(yaw) * cp * sgn;
      const hit = raycastBlocks(this.world, x, y, z, dx, dy, dz, 4.3);
      const want = hit ? Math.max(0.5, hit.dist - 0.3) : 4;
      this.camDist = want < this.camDist ? want : this.camDist + (want - this.camDist) * Math.min(1, dt * 3);
      x += dx * this.camDist; y += dy * this.camDist; z += dz * this.camDist;
      if (mode === 2) { yaw += Math.PI; pitch = -pitch; }
    } else this.camDist = 4;
    if (mode === 0 && s.viewBobbing && p.bobAmount > 0.01) {
      const wb = p.walkDist * Math.PI * 0.62;
      const b = p.bobAmount;
      y += -Math.abs(Math.cos(wb)) * 0.07 * b;
      x += Math.cos(yaw) * Math.sin(wb) * 0.04 * b;
      z += -Math.sin(yaw) * Math.sin(wb) * 0.04 * b;
      roll += Math.sin(wb) * 0.008 * b;
    }
    if (this.shake > 0) { x += (Math.random() - 0.5) * this.shake * 0.3; y += (Math.random() - 0.5) * this.shake * 0.3; }
    cam.x = x; cam.y = y; cam.z = z; cam.yaw = yaw; cam.pitch = pitch; cam.roll = roll;
    cam.fov = s.fov * p.fov * (p.sprinting ? 1.0 : 1) * (this.input && this.state === "playing" ? 1 : 1);
  }

  // ---------- persistence ----------
  loadBlockEntities(obj) {
    if (!obj) return;
    for (const [k, v] of Object.entries(obj)) {
      if (!v || !v.type) continue;
      const size = v.type === "furnace" ? 3 : 27;
      this.world.blockEntities.set(k, { ...v, slots: deserializeStacks(v.slots, size) });
    }
  }
  serializeBlockEntities() {
    const out = {};
    for (const [k, v] of this.world.blockEntities) out[k] = { ...v, slots: serializeStacks(v.slots) };
    return out;
  }
  serializeEntities() {
    const list = this.parked.slice();
    for (const e of this.entities.list) if (e instanceof Mob && !e.dead && e.death < 0 && e.persistent) list.push(e.toJSON());
    return list;
  }
  save() {
    const m = this.meta;
    m.time = this.time;
    m.mode = this.mode;
    m.lastPlayed = Date.now();
    m.player = this.player.toJSON();
    m.inventory = this.inventory.toJSON();
    m.blockEntities = this.serializeBlockEntities();
    m.entities = this.serializeEntities();
    m.weather = this.weather.toJSON();
    const n = this.world.save();
    saveWorld(m);
    return n;
  }
  dispose() {
    this.stopRumble();
    this.sound.rain(false);
    this.sound.stopMusic();
    this.world.dispose();
  }
}
