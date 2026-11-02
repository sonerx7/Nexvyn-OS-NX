// Mobs: definitions, state-machine AI, burning, breeding, villagers, spawning and despawning; the box models are
// drawn by render.js. Horses and donkeys are not part of this version (their ids stay reserved).
// The Puffcap is the night's spore creature: a hopping mushroom that swells up next to the player and puffs a cloud
// of spores (entities.js SporeCloud) that slows and weakens whoever stands in it. It never breaks blocks.
import { B, I, SOLID, COLLIDE, blocks, isLiquid, isLava, isWater } from "./registry.js";
import { Entity } from "./entities.js";
import { moveBox, moveBoxStep, liquidContact, touchingIds, raycastBlocks } from "./physics.js";
import { stack } from "./inventory.js";
const HEIGHT = 128;
const HEAL_FOOD = { [I.wheat]: 2, [I.apple]: 3, [B.hay_bale]: 20, [I.bread]: 4 };
export const MOBS = {
  pig:      { name: "Domuz",   health: 10, speed: 2.5, hw: 0.45, h: 0.9,  breed: [I.wheat, I.apple], drops: [[I.porkchop, 1, 3]] },
  cow:      { name: "İnek",    health: 10, speed: 2.0, hw: 0.45, h: 1.4,  breed: [I.wheat], milk: true, drops: [[I.leather, 0, 2], [I.beef, 1, 3]] },
  sheep:    { name: "Koyun",   health: 8,  speed: 2.3, hw: 0.45, h: 1.3,  breed: [I.wheat], drops: [[B.wool, 1, 1], [I.mutton, 1, 2]] },
  chicken:  { name: "Tavuk",   health: 4,  speed: 2.5, hw: 0.2,  h: 0.7,  breed: [I.wheat_seeds], drops: [[I.feather, 0, 2], [I.chicken, 1, 1]] },
  villager: { name: "Köylü",   health: 20, speed: 1.9, hw: 0.3,  h: 1.95, villager: true, persistent: true, drops: [] },
  // sense: how far (blocks) a hostile mob notices a player it can see
  zombie:   { name: "Zombi",   health: 20, speed: 2.3, hw: 0.3,  h: 1.95, hostile: true, burns: true, sense: 32, damage: 3, drops: [[I.rotten_flesh, 0, 2]] },
  skeleton: { name: "İskelet", health: 20, speed: 2.5, hw: 0.3,  h: 1.99, hostile: true, burns: true, sense: 24, ranged: true, drops: [[I.bone, 0, 2], [I.arrow, 0, 2]] },
  puffcap:  { name: "Pufmantar", health: 16, speed: 2.2, hw: 0.4, h: 1.25, hostile: true, burns: true, sense: 28, spores: true, hops: true, drops: [[I.gunpowder, 0, 2]] },
};
const COOKED = { [I.porkchop]: I.cooked_porkchop, [I.beef]: I.steak, [I.chicken]: I.cooked_chicken, [I.mutton]: I.cooked_mutton };
const PASSIVE = ["pig", "cow", "sheep", "chicken"];
const HOSTILE = [["zombie", 0.4], ["skeleton", 0.3], ["puffcap", 0.3]];
const BABY_SECONDS = 300;
// Hostile mobs hear a player this close (no line of sight needed) and then hunt him with a path around walls.
const HEAR = 16, FORGET = 32, PATH_NODES = 360, PATH_BUDGET = 2;

// ---------------------------------------------------------------- path finding
// A* over block cells a 2-high mob can stand in: walk, step up one block, drop up to three, swim. Bounded by
// PATH_NODES expansions; when the goal is not reached the path leads to the closest cell found.
function standable(w, x, y, z) {
  if (y < 1 || y >= HEIGHT - 2) return false;
  const a = w.getBlock(x, y, z);
  if (COLLIDE[a] || isLava(a) || a === B.fire || COLLIDE[w.getBlock(x, y + 1, z)]) return false;
  if (isWater(a)) return true;
  const below = w.getBlock(x, y - 1, z);
  return COLLIDE[below] === 1 && below !== B.cactus;
}
export function findPath(w, sx, sy, sz, tx, ty, tz) {
  sx = Math.floor(sx); sy = Math.floor(sy); sz = Math.floor(sz);
  tx = Math.floor(tx); ty = Math.floor(ty); tz = Math.floor(tz);
  const key = (x, y, z) => ((x - sx + 64) & 127) | (((z - sz + 64) & 127) << 7) | (y << 14);
  const h = (x, y, z) => Math.abs(x - tx) + Math.abs(z - tz) + Math.abs(y - ty) * 1.5;
  const nodes = new Map();
  const start = { x: sx, y: sy, z: sz, g: 0, f: h(sx, sy, sz), hh: h(sx, sy, sz), parent: null, closed: false };
  nodes.set(key(sx, sy, sz), start);
  const open = [start];
  let best = start, expanded = 0;
  const push = n => {
    let i = open.length;
    open.push(n);
    while (i > 0) { const q = (i - 1) >> 1; if (open[q].f <= n.f) break; open[i] = open[q]; i = q; }
    open[i] = n;
  };
  const pop = () => {
    const top = open[0], last = open.pop();
    const n = open.length;
    if (n) {
      let i = 0;
      for (;;) {
        const l = i * 2 + 1, r = l + 1;
        let m = -1, mf = last.f;
        if (l < n && open[l].f < mf) { m = l; mf = open[l].f; }
        if (r < n && open[r].f < mf) { m = r; }
        if (m < 0) break;
        open[i] = open[m]; i = m;
      }
      open[i] = last;
    }
    return top;
  };
  const DIRS = [[1, 0], [-1, 0], [0, 1], [0, -1]];
  while (open.length && expanded < PATH_NODES) {
    const c = pop();
    if (c.closed) continue;
    c.closed = true; expanded++;
    if (c.hh < best.hh) best = c;
    if (Math.abs(c.x - tx) + Math.abs(c.z - tz) <= 1 && Math.abs(c.y - ty) <= 1) { best = c; break; }
    for (const [dx, dz] of DIRS) {
      const nx = c.x + dx, nz = c.z + dz;
      if (Math.abs(nx - sx) > 60 || Math.abs(nz - sz) > 60) continue;
      let ny = -1;
      if (standable(w, nx, c.y, nz)) ny = c.y;
      else if (!COLLIDE[w.getBlock(c.x, c.y + 2, c.z)] && standable(w, nx, c.y + 1, nz)) ny = c.y + 1;
      else if (!COLLIDE[w.getBlock(nx, c.y, nz)] && !COLLIDE[w.getBlock(nx, c.y + 1, nz)])
        for (let k = 1; k <= 3; k++) if (standable(w, nx, c.y - k, nz)) { ny = c.y - k; break; }
      if (ny < 0) continue;
      const k = key(nx, ny, nz);
      const g = c.g + 1 + (ny !== c.y ? 0.5 : 0);
      let n = nodes.get(k);
      if (n && (n.closed || n.g <= g)) continue;
      if (!n) { n = { x: nx, y: ny, z: nz, g, f: 0, hh: h(nx, ny, nz), parent: c, closed: false }; nodes.set(k, n); }
      n.g = g; n.parent = c; n.f = g + n.hh;
      push(n);
    }
  }
  if (best === start) return null;
  const path = [];
  for (let n = best; n && n !== start; n = n.parent) path.push(n);
  path.reverse();
  return path;
}
const rand = (a, b) => a + Math.random() * (b - a);
const angleDiff = (a, b) => { let d = (b - a) % (Math.PI * 2); if (d > Math.PI) d -= Math.PI * 2; if (d < -Math.PI) d += Math.PI * 2; return d; };

export class Mob extends Entity {
  constructor(game, type, x, y, z, opts = {}) {
    super(game, x, y, z);
    this.type = type;
    this.def = MOBS[type];
    this.baby = opts.baby ? BABY_SECONDS : 0;
    this.variant = opts.variant ?? (this.def.variants ? (Math.random() * this.def.variants) | 0 : 0);
    this.health = opts.health ?? this.def.health;
    this.solidBody = true;
    this.anim = { walk: 0, amount: 0, headYaw: 0, headPitch: 0, death: -1, swell: 0, attack: 0, aim: false, flap: false, glow: 1 };
    this.scale = 1;
    this.yaw = opts.yaw ?? Math.random() * Math.PI * 2;
    this.headYaw = 0; this.headPitch = 0;
    this.walk = 0; this.walkAmount = 0;
    this.hurtTime = 0; this.hurtCooldown = 0;
    this.death = -1;
    this.goal = null; this.wanderTimer = rand(1, 4); this.panic = 0;
    this.attackCooldown = 0; this.attackAnim = 0;
    this.shootCooldown = rand(1.5, 3);
    this.charge = 0; this.puffCooldown = rand(1, 2.5); this.retreat = 0; this.hopT = 0; // puffcap
    this.fireTime = 0; this.burnTick = 0; this.fireHurt = 0;
    this.ambient = rand(4, 16);
    this.aggro = false; this.target = null;
    this.inWater = false;
    this.inLove = 0; this.loveCooldown = 0;
    this.persistent = !!this.def.persistent || !!opts.persistent;
    this.shake = 0;
    this.home = opts.home || null;
    // mounts
    this.rider = null;
    this.tamed = !!opts.tamed; this.saddled = !!opts.saddled;
    this.hasChest = !!opts.hasChest;
    this.chestSlots = opts.chestSlots || (this.hasChest ? new Array(15).fill(null) : null);
    this.temper = opts.temper ?? 0;
    this.stats = opts.stats || (this.def.mount ? {
      speed: type === "donkey" ? 7.5 : 8 + Math.random() * 5,
      jump: type === "donkey" ? 0.5 : 0.55 + Math.random() * 0.45,
      maxHealth: type === "donkey" ? 20 : 18 + ((Math.random() * 12) | 0),
    } : null);
    if (this.stats && opts.health === undefined) this.health = this.stats.maxHealth;
    this.drive = { fwd: 0, strafe: 0 };
    this.jumpCharge = 0; this.tameTimer = 0; this.tameAt = 2; this.stepDist = 0;
    if (this.tamed || this.saddled) this.persistent = true;
    this.applySize();
  }

  applySize() {
    const k = this.baby > 0 ? 0.5 : 1;
    this.hw = this.def.hw * k; this.h = this.def.h * k;
    this.scale = k;
  }

  get hittable() { return this.death < 0; }
  get maxHealth() { return this.stats?.maxHealth ?? this.def.health; }
  // riding API (see Player.updateRiding)
  get steersWithMouse() { return false; }
  get handsBusy() { return false; }
  get fovBoost() { return 1 + Math.min(0.15, Math.hypot(this.vel.x, this.vel.z) / 80); }
  get camDist() { return 5; }
  seat() {
    const back = this.type === "donkey" ? 0.05 : 0.15;
    return { x: this.pos.x - Math.sin(this.yaw) * back, y: this.pos.y + this.def.seatY * (this.baby > 0 ? 0.5 : 1), z: this.pos.z - Math.cos(this.yaw) * back };
  }
  dismountSpots() {
    const rx = -Math.cos(this.yaw), rz = Math.sin(this.yaw);
    return [-1, 1].map(s => ({ x: this.pos.x + rx * s * (this.hw + 0.5), y: this.pos.y, z: this.pos.z + rz * s * (this.hw + 0.5) }));
  }

  hurt(amount, from, knock = 1, cause = "player") {
    if (this.death >= 0 || this.hurtCooldown > 0) return false;
    if (cause === "player" && this.rider) return false; // the rider cannot hit his own horse
    this.health -= amount;
    this.hurtTime = 0.4; this.hurtCooldown = 0.5;
    if (from && knock > 0) {
      const dx = this.pos.x - from.x, dz = this.pos.z - from.z;
      const l = Math.hypot(dx, dz) || 1;
      this.vel.x += (dx / l) * 5 * knock; this.vel.z += (dz / l) * 5 * knock;
      this.vel.y = Math.max(this.vel.y, 4.5);
    }
    const g = this.game;
    g.sound.play(`${this.type}_hurt`, { x: this.pos.x, y: this.pos.y + 1, z: this.pos.z });
    if (this.charge > 0) { this.charge = 0; this.puffCooldown = Math.max(this.puffCooldown, 1.2); } // a hit stops the swelling
    if (!this.def.hostile) { this.panic = 4; this.goal = null; }
    else if (cause === "player") this.aggro = true;
    if (this.health <= 0) this.die(cause);
    return true;
  }

  die(cause) {
    this.death = 0;
    const g = this.game;
    if (this.rider) this.rider.dismount();
    g.sound.play(`${this.type}_death`, { x: this.pos.x, y: this.pos.y + 1, z: this.pos.z });
    if (cause === "despawn" || this.baby > 0) return;
    // a Puffcap bursts when it dies: a small spore cloud where it stood
    if (this.def.spores) g.entities.spawnSpores(this.pos.x, this.pos.y + 0.5, this.pos.z, 1.7, 3.5);
    for (const [id0, min, max] of this.def.drops) {
      const id = this.fireTime > 0 && COOKED[id0] ? COOKED[id0] : id0; // burning animals drop cooked meat
      const n = min + Math.floor(Math.random() * (max - min + 1));
      if (n > 0) g.entities.spawnItem(this.pos.x, this.pos.y + 0.5, this.pos.z, stack(id, n));
    }
    if (this.saddled) g.entities.spawnItem(this.pos.x, this.pos.y + 0.5, this.pos.z, stack(I.saddle, 1));
    if (this.hasChest) {
      g.entities.spawnItem(this.pos.x, this.pos.y + 0.5, this.pos.z, stack(B.chest, 1));
      for (const s of this.chestSlots || []) if (s) g.entities.spawnItem(this.pos.x, this.pos.y + 0.5, this.pos.z, s);
    }
  }

  // ---------- right-click ----------
  interact(p, held, hdef) {
    const g = this.game;
    if (this.death >= 0) return false;
    const id = held?.id;
    void hdef;
    if (this.def.milk && id === I.bucket && this.baby <= 0) {
      g.interaction.replaceHeld(I.milk_bucket);
      g.sound.play("bucket_fill", { x: this.pos.x, y: this.pos.y + 1, z: this.pos.z });
      return true;
    }
    if (this.def.villager) {
      this.shake = 1;
      g.sound.play("villager", { x: this.pos.x, y: this.pos.y + 1.6, z: this.pos.z });
      return true;
    }
    if (this.def.breed && this.def.breed.includes(id)) return this.feed(p);
    return false;
  }

  eatFood(p) {
    const g = this.game;
    g.sound.play("eat", { x: this.pos.x, y: this.pos.y + 1, z: this.pos.z, volume: 0.6 });
    g.renderer.particles.hearts(this.pos.x, this.pos.y + this.h, this.pos.z, 2);
    if (!p.creative) g.inventory.consumeHeld(1);
  }

  feed(p) {
    if (this.baby > 0) { this.baby = Math.max(0, this.baby * 0.9 - 10); this.eatFood(p); return true; }
    if (this.loveCooldown > 0 || this.inLove > 0) return false;
    this.inLove = 30;
    this.persistent = true;
    this.eatFood(p);
    return true;
  }

  // Walk toward (tx, tz); stops at cliffs and (for animals) at water/lava edges.
  steer(tx, tz, speed, dt, careful) {
    const dx = tx - this.pos.x, dz = tz - this.pos.z;
    const d = Math.hypot(dx, dz);
    if (d < 0.3) { this.brake(dt); return true; }
    const nx = dx / d, nz = dz / d;
    const want = Math.atan2(nx, nz);
    this.yaw += angleDiff(this.yaw, want) * Math.min(1, dt * 8);
    if (careful && this.onGround && this.dangerAhead(nx, nz)) { this.brake(dt); this.goal = null; return true; }
    if (this.def.hops) return this.hop(nx, nz, speed, dt);
    const a = 1 - Math.exp(-(this.onGround ? 12 : 3) * dt);
    this.vel.x += (nx * speed - this.vel.x) * a;
    this.vel.z += (nz * speed - this.vel.z) * a;
    return false;
  }

  brake(dt) {
    const a = Math.exp(-10 * dt);
    this.vel.x *= a; this.vel.z *= a;
  }

  // Hoppers move in short bounces: still on the ground between hops, gliding toward the goal in the air.
  hop(nx, nz, speed, dt) {
    if (!this.onGround) {
      const a = 1 - Math.exp(-2 * dt);
      this.vel.x += (nx * speed * 1.4 - this.vel.x) * a;
      this.vel.z += (nz * speed * 1.4 - this.vel.z) * a;
      return false;
    }
    this.brake(dt);
    if (this.hopT <= 0) {
      this.hopT = rand(0.22, 0.42);
      this.vel.x = nx * speed * 1.4; this.vel.z = nz * speed * 1.4;
      this.vel.y = 6.4;
    }
    return false;
  }

  dangerAhead(nx, nz) {
    const w = this.game.world;
    const x = Math.floor(this.pos.x + nx * (this.hw + 0.4)), z = Math.floor(this.pos.z + nz * (this.hw + 0.4));
    const y = Math.floor(this.pos.y);
    const here = w.getBlock(x, y, z);
    if (isLiquid(here) || isLava(w.getBlock(x, y - 1, z)) || here === B.fire) return true;
    for (let k = 1; k <= 3; k++) {
      const id = w.getBlock(x, y - k, z);
      if (COLLIDE[id]) return false;
      if (isLiquid(id)) return true;
    }
    return true;
  }

  canSee(t) {
    const g = this.game;
    const ex = this.pos.x, ey = this.pos.y + this.h * 0.85, ez = this.pos.z;
    const ty0 = t.eyeY ?? t.pos.y + t.h * 0.85;
    const tx = t.pos.x - ex, ty = ty0 - ey, tz = t.pos.z - ez;
    const d = Math.hypot(tx, ty, tz);
    if (d < 0.01) return true;
    const hit = raycastBlocks(g.world, ex, ey, ez, tx / d, ty / d, tz / d, d);
    return !hit || !blocks[hit.id].collide;
  }

  updateFire(dt, liq) {
    const g = this.game;
    if (this.fireHurt > 0) this.fireHurt -= dt;
    if (touchingIds(g.world, this, -0.001).includes(B.fire)) {
      this.fireTime = Math.max(this.fireTime, 8);
      if (this.fireHurt <= 0) { this.fireHurt = 0.5; this.hurt(1, null, 0, "fire"); }
    }
    if (liq.lava) this.fireTime = Math.max(this.fireTime, 15);
    if (liq.water || (this.fireTime > 0 && g.weather?.isRainingAt(this.pos.x, this.pos.y + this.h, this.pos.z))) this.fireTime = 0;
    if (this.fireTime > 0) {
      this.fireTime -= dt;
      this.burnTick += dt;
      if (this.burnTick >= 1) { this.burnTick = 0; this.hurt(1, null, 0, "fire"); }
      if (!this.def.hostile && this.death < 0) this.panic = Math.max(this.panic, 1);
    }
  }

  update(dt) {
    const g = this.game;
    this.age += dt;
    if (this.hurtTime > 0) this.hurtTime -= dt;
    if (this.hurtCooldown > 0) this.hurtCooldown -= dt;
    if (this.attackAnim > 0) this.attackAnim -= dt * 3;
    if (this.loveCooldown > 0) this.loveCooldown -= dt;
    if (this.shake > 0) this.shake -= dt * 1.5;
    if (this.baby > 0) { this.baby -= dt; if (this.baby <= 0) { this.baby = 0; this.applySize(); } }
    if (this.hopT > 0 && this.onGround) this.hopT -= dt;
    const ridden = false;
    if (this.death >= 0) {
      this.death += dt;
      if (this.death > 1) {
        this.remove();
        g.renderer.particles.smoke(this.pos.x, this.pos.y + this.h / 2, this.pos.z, 10);
        return;
      }
    } else this.think(dt);

    // physics
    const liq = liquidContact(g.world, this);
    this.inWater = liq.water || liq.lava;
    if (this.inWater) {
      this.vel.y -= 6 * dt;
      this.vel.y *= Math.exp(-2.5 * dt);
      if (this.death < 0) this.vel.y = Math.min(this.vel.y + 22 * dt, 2.2); // float / swim up
    } else {
      this.vel.y -= 32 * dt;
      if (this.type === "chicken" && this.vel.y < -3) this.vel.y = -3;
    }
    this.vel.y = Math.max(this.vel.y, -50);
    const wasGround = this.onGround;
    const fallStart = this.vel.y;
    moveBoxStep(g.world, this, this.vel.x * dt, this.vel.y * dt, this.vel.z * dt, this.death < 0 ? (this.def.stepH || 0) : 0);
    if (this.death < 0 && this.collidedH && this.onGround && !ridden) this.vel.y = 8.6; // hop up one block
    if (!wasGround && this.onGround && fallStart < -18 && this.type !== "chicken") this.hurt(Math.floor((fallStart * fallStart) / 64 - 3), null, 0, "fall");
    if (liq.lava && this.death < 0) this.hurt(4, null, 0, "lava");
    this.updateFire(dt, liq);
    if (this.pos.y < -20) this.remove();

    // animation
    const hs = Math.hypot(this.vel.x, this.vel.z);
    this.walk += hs * dt * (this.def.mount ? 2.6 : 4);
    this.walkAmount += (Math.min(1, hs / 2) - this.walkAmount) * Math.min(1, dt * 6);
    const an = this.anim;
    an.walk = this.walk; an.amount = this.walkAmount;
    an.headYaw = this.headYaw + (this.shake > 0 ? Math.sin(this.shake * 30) * 0.5 * this.shake : 0);
    an.headPitch = this.headPitch; an.death = this.death; an.swell = this.charge * 0.9; an.attack = this.attackAnim;
    an.glow = this.charge > 0 ? 0.5 + 0.5 * Math.abs(Math.sin(this.age * (8 + this.charge * 18))) : 0.82 + 0.18 * Math.sin(this.age * 2.2);
    an.aim = this.type === "skeleton" && this.aggro; an.flap = this.type === "chicken" && !this.onGround;
    if (this.fireTime > 0 && Math.random() < dt * 14) g.renderer.particles.flame(this.pos.x + rand(-this.hw, this.hw), this.pos.y + rand(0.1, this.h), this.pos.z + rand(-this.hw, this.hw));
  }

  draw(r) { r.drawMob(this); }

  think(dt) {
    const g = this.game, p = g.player, def = this.def;
    const dx = p.pos.x - this.pos.x, dy = p.pos.y - this.pos.y, dz = p.pos.z - this.pos.z;
    const dist = Math.hypot(dx, dy, dz);

    // ambient sounds
    this.ambient -= dt;
    if (this.ambient <= 0) {
      this.ambient = rand(8, 20);
      if (dist < 20) g.sound.play(this.type, { x: this.pos.x, y: this.pos.y + 1, z: this.pos.z, volume: 0.8 });
    }

    // sunlight sets the undead on fire
    if (def.burns && g.daylight > 0.75 && !this.inWater && !g.weather.raining) {
      const hx = Math.floor(this.pos.x), hy = Math.floor(this.pos.y + this.h - 0.1), hz = Math.floor(this.pos.z);
      if (g.world.skyLight(hx, hy, hz) >= 14) this.fireTime = Math.max(this.fireTime, 8);
    }

    // look at the player when close
    const lookYaw = Math.atan2(dx, dz);
    const wantHead = dist < 8 ? Math.max(-1, Math.min(1, angleDiff(this.yaw, lookYaw))) : 0;
    this.headYaw += (wantHead - this.headYaw) * Math.min(1, dt * 6);
    this.headPitch += ((dist < 8 ? Math.atan2(p.eyeY - (this.pos.y + this.h), Math.hypot(dx, dz)) * 0.6 : 0) - this.headPitch) * Math.min(1, dt * 6);

    if (def.hostile) {
      // notices a player it can see within its sense range, or hears one within HEAR blocks; hunts until FORGET
      const tp = !p.dead && !p.creative && dist < (this.aggro ? FORGET : Math.max(HEAR, def.sense || HEAR));
      if (!tp) { this.aggro = false; this.path = null; }
      this.seeTimer = (this.seeTimer || 0) - dt;
      if (tp && this.seeTimer <= 0) { this.seeTimer = 0.3; this.sees = this.canSee(p); }
      if (tp && (this.sees || dist < HEAR)) this.aggro = true;
      if (tp && this.aggro) {
        if (def.spores) return this.thinkPuffcap(dt, p);
        if (def.ranged) return this.thinkSkeleton(dt, dist, p);
        return this.thinkZombie(dt, p);
      }
      // zombies also go for villagers
      if (this.type === "zombie") {
        this.villagerTimer = (this.villagerTimer || 0) - dt;
        if (this.villagerTimer <= 0) {
          this.villagerTimer = 1;
          this.target = g.entities.nearest(this.pos, 16, e => e instanceof Mob && e.def.villager && e.death < 0);
        }
        if (this.target && !this.target.dead && this.target.death < 0) return this.thinkZombie(dt, this.target);
      }
      if (this.charge > 0) this.charge = Math.max(0, this.charge - dt * 2);
      if (def.spores) this.puffCooldown -= dt;
      return this.wander(dt);
    }

    // breeding: find a partner of the same kind that is also in love
    if (this.inLove > 0) {
      this.inLove -= dt;
      if (Math.random() < dt * 2.5) g.renderer.particles.hearts(this.pos.x, this.pos.y + this.h, this.pos.z, 1);
      const mate = g.entities.nearest(this.pos, 8, e => e !== this && e instanceof Mob && e.type === this.type && e.inLove > 0 && e.baby <= 0 && e.death < 0);
      if (mate) {
        this.steer(mate.pos.x, mate.pos.z, def.speed * 0.8, dt, true);
        if (Math.hypot(mate.pos.x - this.pos.x, mate.pos.z - this.pos.z) < this.hw + mate.hw + 0.4) this.breed(mate);
        return;
      }
    }
    // villagers flee from zombies and stay near their village
    if (def.villager) {
      const z = g.entities.nearest(this.pos, 8, e => e instanceof Mob && e.type === "zombie" && e.death < 0);
      if (z) { this.panic = 2; this.goal = { x: this.pos.x - (z.pos.x - this.pos.x) * 2, z: this.pos.z - (z.pos.z - this.pos.z) * 2 }; }
      else if (this.home && Math.hypot(this.home.x - this.pos.x, this.home.z - this.pos.z) > 28 && !this.goal) this.goal = { x: this.home.x + rand(-6, 6), z: this.home.z + rand(-6, 6) };
    }
    // animals follow a player holding their food
    if (def.breed && !p.dead && dist < 10 && this.panic <= 0) {
      const held = g.inventory.held;
      if (held && def.breed.includes(held.id)) {
        if (Math.hypot(dx, dz) > 2.2) this.steer(p.pos.x, p.pos.z, def.speed * 0.7, dt, true); else this.brake(dt);
        this.yaw += angleDiff(this.yaw, lookYaw) * Math.min(1, dt * 4);
        return;
      }
    }
    this.wander(dt);
  }

  breed(mate) {
    const g = this.game;
    this.inLove = 0; mate.inLove = 0;
    this.loveCooldown = 60; mate.loveCooldown = 60;
    const x = (this.pos.x + mate.pos.x) / 2, z = (this.pos.z + mate.pos.z) / 2;
    g.spawner.spawn(this.type, x, Math.max(this.pos.y, mate.pos.y), z, { baby: true, persistent: true });
    g.renderer.particles.hearts(x, this.pos.y + this.h, z, 6);
    g.sound.play("pop", { x, y: this.pos.y + 0.5, z });
  }

  wander(dt) {
    const speed = this.panic > 0 ? this.def.speed * 1.6 : this.def.speed * 0.45;
    if (this.panic > 0) this.panic -= dt;
    this.wanderTimer -= dt;
    if (!this.goal || this.wanderTimer <= 0) {
      this.wanderTimer = this.panic > 0 ? rand(0.6, 1.4) : rand(3, 8);
      if (this.panic > 0 || Math.random() < 0.6) {
        const a = Math.random() * Math.PI * 2, r = rand(3, 9);
        this.goal = { x: this.pos.x + Math.cos(a) * r, z: this.pos.z + Math.sin(a) * r };
      } else this.goal = null;
    }
    if (this.goal) { if (this.steer(this.goal.x, this.goal.z, speed, dt, true)) this.goal = null; }
    else this.brake(dt);
  }

  // Moves toward target t: straight at it when it is close, seen and level, otherwise along an A* path that is
  // recomputed every second or so (the spawner hands out PATH_BUDGET path searches per frame).
  navTo(t, speed, dt) {
    const g = this.game;
    const hd = Math.hypot(t.pos.x - this.pos.x, t.pos.z - this.pos.z), dy = t.pos.y - this.pos.y;
    if (hd < 5 && Math.abs(dy) < 1.2 && this.sees) { this.path = null; this.steer(t.pos.x, t.pos.z, speed, dt, false); return; }
    this.pathT = (this.pathT || 0) - dt;
    if ((!this.path || this.pathT <= 0) && g.spawner.pathBudget > 0) {
      g.spawner.pathBudget--;
      this.pathT = 0.9 + Math.random() * 0.5;
      this.path = findPath(g.world, this.pos.x, this.pos.y + 0.2, this.pos.z, t.pos.x, t.pos.y + 0.2, t.pos.z);
      this.pathI = 0;
    }
    const path = this.path;
    if (path && this.pathI < path.length) {
      let n = path[this.pathI];
      if (Math.hypot(n.x + 0.5 - this.pos.x, n.z + 0.5 - this.pos.z) < 0.4 && Math.abs(n.y - this.pos.y) < 1.1) {
        this.pathI++;
        if (this.pathI >= path.length) { this.path = null; this.steer(t.pos.x, t.pos.z, speed, dt, false); return; }
        n = path[this.pathI];
      }
      if (n.y > Math.floor(this.pos.y + 0.1) && this.onGround && !this.def.hops && Math.hypot(n.x + 0.5 - this.pos.x, n.z + 0.5 - this.pos.z) < 1.3) this.vel.y = 8.6;
      this.steer(n.x + 0.5, n.z + 0.5, speed, dt, false);
      return;
    }
    this.steer(t.pos.x, t.pos.z, speed, dt, false);
  }

  // Chases and hits a target (the player or a villager).
  thinkZombie(dt, t) {
    this.attackCooldown -= dt;
    const hd = Math.hypot(t.pos.x - this.pos.x, t.pos.z - this.pos.z);
    const reach = this.hw + (t.hw || 0.3) + 0.9;
    if (hd > reach * 0.6) this.navTo(t, this.def.speed, dt);
    else { this.brake(dt); this.yaw += angleDiff(this.yaw, Math.atan2(t.pos.x - this.pos.x, t.pos.z - this.pos.z)) * Math.min(1, dt * 8); }
    if (hd < reach && Math.abs(t.pos.y - this.pos.y) < 1.8 && this.attackCooldown <= 0) {
      this.attackCooldown = 1;
      this.attackAnim = 1;
      if (t === this.game.player) t.damage(this.def.damage, "zombie", this);
      else t.hurt(this.def.damage, this.pos, 1, "zombie");
    }
  }

  thinkSkeleton(dt, dist, p) {
    const hd = Math.hypot(p.pos.x - this.pos.x, p.pos.z - this.pos.z);
    const want = Math.atan2(p.pos.x - this.pos.x, p.pos.z - this.pos.z);
    if (hd > 12 || !this.sees) this.navTo(p, this.def.speed, dt);
    else if (hd < 6) this.steer(this.pos.x - (p.pos.x - this.pos.x), this.pos.z - (p.pos.z - this.pos.z), this.def.speed, dt, true);
    else {
      // strafe sideways while keeping the bow on the player
      const side = Math.sin(this.age * 0.7) > 0 ? 1 : -1;
      const sx = this.pos.x + Math.cos(want) * side * 3, sz = this.pos.z - Math.sin(want) * side * 3;
      this.steer(sx, sz, this.def.speed * 0.5, dt, true);
    }
    this.yaw += angleDiff(this.yaw, want) * Math.min(1, dt * 10);
    this.shootCooldown -= dt;
    if (this.shootCooldown <= 0 && hd < 16 && this.sees && this.canSee(p)) {
      this.shootCooldown = rand(1.8, 2.6);
      const ex = this.pos.x, ey = this.pos.y + 1.5, ez = this.pos.z;
      const tx = p.pos.x - ex, ty = p.pos.y + 1.2 - ey, tz = p.pos.z - ez;
      const d = Math.max(1, Math.hypot(tx, ty, tz));
      const speed = 22, t = d / speed;
      const spread = 0.06;
      const vx = (tx / t) + rand(-1, 1) * spread * speed, vz = (tz / t) + rand(-1, 1) * spread * speed;
      const vy = ty / t + 0.5 * 20 * t;
      this.game.entities.spawnArrow(ex + Math.sin(this.yaw) * 0.5, ey, ez + Math.cos(this.yaw) * 0.5, vx, vy, vz, this);
    }
  }

  // Puffcap: hops up to the player, swells for a moment (its spots flicker), then puffs a spore cloud and backs off.
  thinkPuffcap(dt, p) {
    const g = this.game;
    this.puffCooldown -= dt;
    const dx = p.pos.x - this.pos.x, dz = p.pos.z - this.pos.z, hd = Math.hypot(dx, dz);
    const want = Math.atan2(dx, dz);
    if (this.charge > 0) {
      this.brake(dt);
      this.yaw += angleDiff(this.yaw, want) * Math.min(1, dt * 8);
      this.charge += dt / 0.9;
      if (this.charge >= 1) this.puff();
      return;
    }
    if (this.retreat > 0) {
      this.retreat -= dt;
      this.steer(this.pos.x - dx, this.pos.z - dz, this.def.speed, dt, true);
      return;
    }
    if (hd < 3 && Math.abs(p.pos.y - this.pos.y) < 2.5 && this.puffCooldown <= 0 && this.onGround) {
      this.charge = 0.001;
      g.sound.play("puffcap_swell", { x: this.pos.x, y: this.pos.y + 0.8, z: this.pos.z });
      return;
    }
    if (hd > 1.5) this.navTo(p, this.def.speed, dt);
    else { this.brake(dt); this.yaw += angleDiff(this.yaw, want) * Math.min(1, dt * 6); }
  }

  puff() {
    const g = this.game;
    this.charge = 0;
    this.puffCooldown = rand(6, 8);
    this.retreat = 1.4;
    g.entities.spawnSpores(this.pos.x, this.pos.y + 0.5, this.pos.z, 2.6, 6);
    g.sound.play("spore_puff", { x: this.pos.x, y: this.pos.y + 0.8, z: this.pos.z });
  }

  toJSON() {
    return { kind: "mob", type: this.type, x: this.pos.x, y: this.pos.y, z: this.pos.z, yaw: this.yaw, health: this.health, baby: this.baby, home: this.home };
  }
}

// ---------------------------------------------------------------- spawning
export class MobSpawner {
  constructor(game) {
    this.game = game;
    this.hostileTimer = 2;
    this.passiveTimer = 0.5;
    this.villageTimer = 1;
    this.boost = 12; // fast initial passive spawning so the first view has animals
    this.pathBudget = PATH_BUDGET;
  }

  get mobs() { return this.game.entities.list.filter(e => e instanceof Mob && !e.dead); }

  update(dt) {
    const g = this.game;
    this.pathBudget = PATH_BUDGET;
    if (this.boost > 0) this.boost -= dt;
    this.hostileTimer -= dt;
    this.passiveTimer -= dt;
    this.villageTimer -= dt;
    const mobs = this.mobs;
    const p = g.player;
    // mobs push each other apart instead of overlapping
    for (let i = 0; i < mobs.length; i++) for (let j = i + 1; j < mobs.length; j++) {
      const a = mobs[i], b = mobs[j];
      const dx = b.pos.x - a.pos.x, dz = b.pos.z - a.pos.z;
      const min = a.hw + b.hw;
      if (Math.abs(dx) > min || Math.abs(dz) > min || Math.abs(b.pos.y - a.pos.y) > 1) continue;
      const d = Math.hypot(dx, dz) || 0.01;
      if (d >= min) continue;
      const k = ((min - d) * 0.5 * Math.min(1, dt * 10)) / d;
      const ag = a.onGround, bg = b.onGround;
      moveBox(g.world, a, -dx * k, 0, -dz * k);
      moveBox(g.world, b, dx * k, 0, dz * k);
      a.onGround = ag; b.onGround = bg;
    }
    // despawn (persistent mobs - villagers, tamed, bred or fed animals - never despawn)
    for (const m of mobs) {
      if (m.persistent) continue;
      const d = Math.hypot(m.pos.x - p.pos.x, m.pos.z - p.pos.z);
      if (m.def.hostile) {
        if (d > 64 || (d > 32 && Math.random() < dt / 30)) m.remove();
      } else if (d > (g.settings.renderDistance + 1) * 16) m.remove();
    }
    if (this.hostileTimer <= 0) {
      this.hostileTimer = 1;
      if (mobs.filter(m => m.def.hostile).length < 25) this.trySpawnHostile();
    }
    if (this.passiveTimer <= 0) {
      this.passiveTimer = this.boost > 0 ? 0.3 : 4;
      if (mobs.filter(m => !m.def.hostile && !m.persistent).length < 16) this.trySpawnPassive();
    }
    if (this.villageTimer <= 0) { this.villageTimer = 2; this.populateVillages(); }
  }

  spawn(type, x, y, z, opts = {}) {
    const g = this.game;
    if (opts.egg) opts.persistent = true;
    return g.entities.add(new Mob(g, type, x, y, z, opts));
  }

  spawnSaved(d) {
    if (!MOBS[d.type]) return null;
    const opts = { ...d, persistent: true };
    const m = this.spawn(d.type, d.x, d.y, d.z, opts);
    m.baby = d.baby || 0;
    m.applySize();
    return m;
  }

  ring(minR, maxR) {
    const p = this.game.player;
    const a = Math.random() * Math.PI * 2, r = rand(minR, maxR);
    return { x: Math.floor(p.pos.x + Math.cos(a) * r), z: Math.floor(p.pos.z + Math.sin(a) * r) };
  }

  freeAt(x, y, z) {
    const w = this.game.world;
    const a = w.getBlock(x, y, z), b = w.getBlock(x, y + 1, z);
    return !COLLIDE[a] && !COLLIDE[b] && !isLiquid(a) && !isLiquid(b);
  }

  trySpawnHostile() {
    const g = this.game, w = g.world, p = g.player;
    const { x, z } = this.ring(18, 44);
    if (!w.isLoaded(x, z) || !w.v.light(x, 64, z)) return;
    const skySub = Math.round((1 - (g.daylight - 0.25) / 0.75) * 11);
    const y0 = Math.max(1, Math.floor(p.pos.y) - 24), y1 = Math.min(HEIGHT - 3, Math.floor(p.pos.y) + 24);
    for (let y = y1; y >= y0; y--) {
      const below = w.getBlock(x, y - 1, z);
      if (!SOLID[below] || below === B.barrier || !this.freeAt(x, y, z)) continue;
      const l = w.getLight(x, y, z);
      const eff = Math.max((l >> 4) - skySub, l & 15);
      if (eff > 7) continue;
      let r = Math.random(), type = HOSTILE[0][0];
      for (const [t, wgt] of HOSTILE) { if ((r -= wgt) <= 0) { type = t; break; } }
      this.spawn(type, x + 0.5, y, z + 0.5);
      return;
    }
  }

  trySpawnPassive() {
    const g = this.game, w = g.world;
    const { x, z } = this.boost > 0 ? this.ring(10, 40) : this.ring(24, 64);
    if (!w.isLoaded(x, z) || !w.v.light(x, 64, z)) return;
    const y = w.topY(x, z) + 1;
    if (y <= 0 || w.getBlock(x, y - 1, z) !== B.grass || !this.freeAt(x, y, z)) return;
    if (w.skyLight(x, y, z) < 9) return;
    const type = PASSIVE[(Math.random() * PASSIVE.length) | 0];
    const n = 2 + ((Math.random() * 3) | 0);
    for (let i = 0; i < n; i++) {
      const sx = x + ((Math.random() * 5) | 0) - 2, sz = z + ((Math.random() * 5) | 0) - 2;
      const sy = w.topY(sx, sz) + 1;
      if (sy > 0 && w.getBlock(sx, sy - 1, sz) === B.grass && this.freeAt(sx, sy, sz)) this.spawn(type, sx + 0.5, sy, sz + 0.5);
    }
  }

  // Each village gets its villagers once, when the player first comes near it.
  populateVillages() {
    const g = this.game, w = g.world, p = g.player;
    if (g.meta.type !== "normal") return;
    const meta = g.meta;
    meta.villages = meta.villages || {};
    for (const { key, plan } of g.villagesNear(p.pos.x, p.pos.z, 96)) {
      if (meta.villages[key]) continue;
      if (!w.isLoaded(plan.x, plan.z) || !w.v.light(plan.x, 64, plan.z)) continue;
      let placed = 0;
      for (let tries = 0; tries < 60 && placed < plan.villagers; tries++) {
        const x = plan.x + ((Math.random() * 24) | 0) - 12, z = plan.z + ((Math.random() * 24) | 0) - 12;
        if (!w.isLoaded(x, z)) continue;
        const h = g.column(x, z).h;
        for (let y = Math.max(1, h - 2); y <= h + 4; y++) {
          if (!SOLID[w.getBlock(x, y - 1, z)] || !this.freeAt(x, y, z) || w.skyLight(x, y, z) < 4) continue;
          this.spawn("villager", x + 0.5, y, z + 0.5, { home: { x: plan.x, z: plan.z } });
          placed++;
          break;
        }
      }
      if (placed) meta.villages[key] = true;
    }
  }
}
