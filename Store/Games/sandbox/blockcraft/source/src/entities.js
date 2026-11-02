// Entities: dropped items, arrows, primed TNT, explosions, spore clouds + the manager; drawing goes through
// render.js (each entity has draw(r)).
import { blocks, B, I, isLiquid, maxStack } from "./registry.js";
import { moveBox, liquidContact, rayBox, raycastBlocks } from "./physics.js";
import { stack, canStack } from "./inventory.js";

let nextId = 1;
const MAX_EXPLOSIONS_PER_FRAME = 1, MAX_PRIMED_TNT = 24, MAX_ENTITIES = 500;

export class Entity {
  constructor(game, x, y, z) {
    this.id = nextId++;
    this.game = game;
    this.pos = { x, y, z };
    this.vel = { x: 0, y: 0, z: 0 };
    this.hw = 0.25; this.h = 0.5;
    this.yaw = 0;
    this.onGround = false; this.collidedH = false;
    this.dead = false;
    this.age = 0;
    this.solidBody = false;
  }
  update() {}
  draw() {}
  remove() { this.dead = true; }
  distTo(p) { return Math.hypot(this.pos.x - p.x, this.pos.y - p.y, this.pos.z - p.z); }
}

// ---------------------------------------------------------------- items
export class ItemEntity extends Entity {
  constructor(game, x, y, z, s, vel) {
    super(game, x, y, z);
    this.stack = s;
    this.hw = 0.125; this.h = 0.25;
    this.pickupDelay = 0.5;
    this.phase = Math.random() * Math.PI * 2;
    if (vel) Object.assign(this.vel, vel);
    else { this.vel.x = (Math.random() - 0.5) * 2.5; this.vel.y = 2 + Math.random() * 1.5; this.vel.z = (Math.random() - 0.5) * 2.5; }
  }
  update(dt) {
    const g = this.game;
    this.age += dt;
    if (this.age > 300) { this.remove(); return; }
    this.pickupDelay -= dt;
    const liq = liquidContact(g.world, this);
    const inFire = g.world.getBlock(Math.floor(this.pos.x), Math.floor(this.pos.y + 0.1), Math.floor(this.pos.z)) === B.fire;
    if (liq.lava || inFire) {
      g.sound.play("fizz", { x: this.pos.x, y: this.pos.y, z: this.pos.z, volume: 0.6 });
      g.renderer.particles.smoke(this.pos.x, this.pos.y + 0.2, this.pos.z, 4);
      this.remove();
      return;
    }
    if (liq.water) { this.vel.y += (3 - this.vel.y) * Math.min(1, dt * 3); this.vel.x *= Math.exp(-dt * 2); this.vel.z *= Math.exp(-dt * 2); }
    else this.vel.y -= 16 * dt;
    this.vel.y = Math.max(this.vel.y, -40);
    if (Math.abs(this.vel.x) + Math.abs(this.vel.y) + Math.abs(this.vel.z) > 0.01 || !this.onGround) moveBox(g.world, this, this.vel.x * dt, this.vel.y * dt, this.vel.z * dt);
    const fr = this.onGround ? 8 : 0.4;
    this.vel.x *= Math.exp(-fr * dt); this.vel.z *= Math.exp(-fr * dt);
    if ((this.id + Math.floor(this.age * 4)) % 8 === 0) {
      for (const o of g.entities.list) {
        if (o === this || o.dead || !(o instanceof ItemEntity) || !canStack(o.stack, this.stack)) continue;
        if (Math.abs(o.pos.x - this.pos.x) > 0.7 || Math.abs(o.pos.y - this.pos.y) > 0.7 || Math.abs(o.pos.z - this.pos.z) > 0.7) continue;
        const room = maxStack(this.stack.id) - this.stack.count;
        if (room <= 0) break;
        const n = Math.min(room, o.stack.count);
        this.stack.count += n; o.stack.count -= n;
        this.age = Math.min(this.age, o.age);
        if (o.stack.count <= 0) o.remove();
      }
    }
    const p = g.player;
    if (!p.dead && this.pickupDelay <= 0) {
      const dx = p.pos.x - this.pos.x, dy = (p.pos.y + 0.8) - this.pos.y, dz = p.pos.z - this.pos.z;
      if (dx * dx + dy * dy + dz * dz < 1.5 * 1.5) {
        const left = g.inventory.add(this.stack);
        if (left < this.stack.count) g.sound.play("pop", { volume: 0.5 });
        this.stack.count = left;
        if (left <= 0) { this.remove(); return; }
      }
    }
  }
  draw(r) {
    const y = this.pos.y + 0.12 + Math.sin(this.age * 2.5 + this.phase) * 0.06;
    const n = this.stack.count > 32 ? 3 : this.stack.count > 1 ? 2 : 1;
    for (let k = 0; k < n; k++) r.drawItem(this.stack.id, this.pos.x + k * 0.06, y + k * 0.05, this.pos.z + k * 0.04, this.age * 1.4 + this.phase, 0, 0.25);
  }
}

// ---------------------------------------------------------------- arrows
export class Arrow extends Entity {
  constructor(game, x, y, z, vx, vy, vz, shooter) {
    super(game, x, y, z);
    this.vel.x = vx; this.vel.y = vy; this.vel.z = vz;
    this.hw = 0.1; this.h = 0.1;
    this.shooter = shooter;
    this.stuck = false;
    this.crit = false;
    this.pickup = false;
    this.ryaw = Math.atan2(vx, vz); this.rpitch = 0;
  }
  update(dt) {
    const g = this.game, p = g.player;
    this.age += dt;
    if (this.stuck) {
      if (this.age > 60) this.remove();
      if (this.pickup && !p.dead && Math.hypot(p.pos.x - this.pos.x, p.pos.y + 0.9 - this.pos.y, p.pos.z - this.pos.z) < 1.5) {
        if (g.inventory.add(stack(I.arrow, 1)) === 0) { g.sound.play("pop", { volume: 0.5 }); this.remove(); }
      }
      return;
    }
    if (this.age > 20) { this.remove(); return; }
    const sp = Math.hypot(this.vel.x, this.vel.y, this.vel.z);
    const step = sp * dt;
    const dx = this.vel.x / sp, dy = this.vel.y / sp, dz = this.vel.z / sp;
    let best = null, bestT = Infinity;
    const test = (e, grow) => {
      const t = rayBox(this.pos.x, this.pos.y, this.pos.z, dx, dy, dz,
        e.pos.x - e.hw - grow, e.pos.y - grow, e.pos.z - e.hw - grow, e.pos.x + e.hw + grow, e.pos.y + e.h + grow, e.pos.z + e.hw + grow);
      if (t >= 0 && t <= step && t < bestT) { bestT = t; best = e; }
    };
    if (!p.dead && (this.shooter !== p || this.age > 0.4)) test(p, 0.1);
    for (const e of g.entities.list) {
      if (e === this || e.dead || !e.hurt || !e.hittable || e === this.shooter) continue;
      test(e, 0.05);
    }
    if (best) {
      let dmg = Math.max(1, Math.ceil(sp / 10));
      if (this.crit) dmg += (Math.random() * (dmg / 2 + 2)) | 0;
      if (best === p) p.damage(dmg, this.shooter && this.shooter.type === "skeleton" ? "skeleton" : "arrow", this);
      else best.hurt(dmg, { x: this.pos.x - dx, y: this.pos.y, z: this.pos.z - dz }, 0.6, this.shooter === p ? "player" : "arrow");
      g.sound.play("arrow_hit", { x: this.pos.x, y: this.pos.y, z: this.pos.z });
      this.remove();
      return;
    }
    if (this.crit && Math.random() < dt * 40) g.renderer.particles.crit(this.pos.x, this.pos.y, this.pos.z, 1);
    const hit = raycastBlocks(g.world, this.pos.x, this.pos.y, this.pos.z, dx, dy, dz, step);
    if (hit && blocks[hit.id].collide) {
      this.pos.x += dx * hit.dist; this.pos.y += dy * hit.dist; this.pos.z += dz * hit.dist;
      this.stuck = true; this.age = 0;
      g.sound.play("arrow_hit", { x: this.pos.x, y: this.pos.y, z: this.pos.z, volume: 0.7 });
    } else {
      this.pos.x += this.vel.x * dt; this.pos.y += this.vel.y * dt; this.pos.z += this.vel.z * dt;
      this.vel.y -= 20 * dt;
      const drag = Math.exp(-0.2 * dt);
      this.vel.x *= drag; this.vel.y *= drag; this.vel.z *= drag;
      this.ryaw = Math.atan2(this.vel.x, this.vel.z);
      this.rpitch = -Math.atan2(this.vel.y, Math.hypot(this.vel.x, this.vel.z));
    }
  }
  draw(r) { r.drawArrow(this.pos.x, this.pos.y, this.pos.z, this.ryaw, this.rpitch); }
}

// ---------------------------------------------------------------- TNT
export class PrimedTNT extends Entity {
  constructor(game, x, y, z, fuse) {
    super(game, x, y, z);
    this.hw = 0.49; this.h = 0.98;
    this.fuse = fuse;
    this.vel.y = 3;
    const a = Math.random() * Math.PI * 2;
    this.vel.x = Math.cos(a) * 0.4; this.vel.z = Math.sin(a) * 0.4;
    game.sound.play("fuse", { x, y, z });
  }
  update(dt) {
    const g = this.game;
    this.fuse -= dt;
    this.vel.y -= 25 * dt;
    moveBox(g.world, this, this.vel.x * dt, this.vel.y * dt, this.vel.z * dt);
    if (this.onGround) { this.vel.x *= Math.exp(-6 * dt); this.vel.z *= Math.exp(-6 * dt); }
    if (this.fuse <= 0) {
      // one explosion per frame: a chain of TNT goes off over several frames instead of all at once
      if (g.entities.explosions >= MAX_EXPLOSIONS_PER_FRAME) return;
      g.entities.explosions++;
      this.remove();
      explode(g, this.pos.x, this.pos.y + 0.5, this.pos.z, 4, 28, 8);
      return;
    }
    if (Math.random() < dt * 20) g.renderer.particles.smoke(this.pos.x, this.pos.y + 1.05, this.pos.z, 1);
  }
  draw(r) {
    const s = this.fuse < 0.4 ? 1 + (0.4 - this.fuse) * 0.6 : 1;
    const flash = Math.floor(this.fuse * 5) % 2 === 0;
    r.drawBlockCube(B.tnt, this.pos.x, this.pos.y + 0.49, this.pos.z, 0.98 * s, flash ? "#FFFFFF" : null);
  }
}

// ---------------------------------------------------------------- spore cloud
// What a Puffcap puffs out: a drifting cloud that lingers for a few seconds. A player inside it is slowed and
// slowly weakened (player.js inSpores); rain washes it away faster. It does nothing to blocks or other mobs.
export class SporeCloud extends Entity {
  constructor(game, x, y, z, radius, life) {
    super(game, x, y, z);
    this.radius = radius;
    this.life = life;
    this.hw = 0; this.h = 0;
  }
  update(dt) {
    const g = this.game;
    this.age += dt;
    const wet = g.weather && g.weather.isRainingAt(this.pos.x, this.pos.y + 1, this.pos.z);
    this.life -= dt * (wet ? 2.5 : 1);
    if (this.life <= 0) { this.remove(); return; }
    const fade = Math.min(1, this.life / 1.5);
    const r = this.radius * (0.55 + 0.45 * Math.min(1, this.age / 0.5));
    this.pos.y += dt * 0.08;
    const n = Math.random() < dt * 40 * fade ? (this.age < 0.3 ? 3 : 1) : 0;
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2, d = Math.sqrt(Math.random()) * r;
      g.renderer.particles.spore(this.pos.x + Math.cos(a) * d, this.pos.y - 0.3 + Math.random() * r * 0.9, this.pos.z + Math.sin(a) * d, this.age < 0.3);
    }
    const p = g.player;
    if (p.dead || p.creative) return;
    const dx = p.pos.x - this.pos.x, dy = p.pos.y + 0.9 - this.pos.y, dz = p.pos.z - this.pos.z;
    if (dx * dx + dz * dz < r * r && Math.abs(dy) < r * 0.7 + 0.8) p.inSpores();
  }
}

// ---------------------------------------------------------------- explosion
export function explode(game, x, y, z, power, maxDamage, radius) {
  const w = game.world;
  game.sound.play("explode", { x, y, z });
  game.renderer.particles.explosion(x, y, z, power);
  const p = game.player;
  const pd = Math.hypot(p.pos.x - x, p.pos.y + 0.9 - y, p.pos.z - z);
  game.shake = Math.max(game.shake, Math.max(0, 1 - pd / (radius * 2)) * 0.9);
  if (pd < radius * 3) game.rumble(Math.max(0.2, 1 - pd / (radius * 2)), 90);
  const r = power * 1.4;
  const ri = Math.ceil(r);
  let drops = 0;
  const bx = Math.floor(x), by = Math.floor(y), bz = Math.floor(z);
  for (let dy = -ri; dy <= ri; dy++) for (let dz = -ri; dz <= ri; dz++) for (let dx = -ri; dx <= ri; dx++) {
    const d = Math.hypot(dx, dy, dz);
    if (d > r * (0.7 + 0.3 * Math.random())) continue;
    const X = bx + dx, Y = by + dy, Z = bz + dz;
    const id = w.getBlock(X, Y, Z);
    if (!id || isLiquid(id)) continue;
    const def = blocks[id];
    if (def.hardness === Infinity) continue;
    if (def.tnt) {
      // chain reaction, capped: past MAX_PRIMED_TNT live charges the block simply stays
      if (game.entities.primedCount() >= MAX_PRIMED_TNT) continue;
      w.setBlock(X, Y, Z, B.air);
      game.entities.spawnTNT(X + 0.5, Y, Z + 0.5, 0.5 + Math.random());
      continue;
    }
    const withDrops = drops < 40 && Math.random() < 1 / power;
    if (withDrops) drops++;
    game.breakBlock(X, Y, Z, { drops: withDrops, byPlayer: false, quiet: true });
  }
  const hurtAt = (ex, ey, ez) => {
    const d = Math.hypot(ex - x, ey - y, ez - z);
    if (d >= radius) return null;
    const impact = 1 - d / radius;
    const l = d || 1;
    return { impact, nx: (ex - x) / l, ny: (ey - y) / l, nz: (ez - z) / l };
  };
  for (const e of game.entities.list) {
    if (e.dead) continue;
    const h = hurtAt(e.pos.x, e.pos.y + e.h / 2, e.pos.z);
    if (!h) continue;
    if (e instanceof ItemEntity) { if (h.impact > 0.4) e.remove(); continue; }
    if (e.hurt) e.hurt(h.impact * maxDamage, { x, y, z }, 0, "explosion");
    e.vel.x += h.nx * h.impact * 12; e.vel.y += Math.max(0, h.ny) * h.impact * 10 + h.impact * 4; e.vel.z += h.nz * h.impact * 12;
  }
  const hp = hurtAt(p.pos.x, p.pos.y + 0.9, p.pos.z);
  if (hp && !p.dead) {
    p.damage(Math.round(hp.impact * maxDamage), "explosion", null, true);
    if (!p.creative) { p.vel.x += hp.nx * hp.impact * 14; p.vel.y += hp.impact * 8; p.vel.z += hp.nz * hp.impact * 14; }
  }
}

// ---------------------------------------------------------------- manager
export class EntityManager {
  constructor(game) {
    this.game = game;
    this.list = [];
  }
  add(e) {
    // hard cap: past MAX_ENTITIES the oldest dropped item goes (mobs and TNT have their own caps)
    if (this.list.length >= MAX_ENTITIES) {
      let old = -1;
      for (let i = 0; i < this.list.length; i++) { const o = this.list[i]; if (!o.dead && o instanceof ItemEntity && (old < 0 || o.age > this.list[old].age)) old = i; }
      if (old >= 0) this.list[old].remove(); else if (!(e instanceof PrimedTNT)) return e;
    }
    this.list.push(e);
    return e;
  }
  primedCount() { let n = 0; for (const e of this.list) if (!e.dead && e instanceof PrimedTNT) n++; return n; }
  spawnItem(x, y, z, s, vel) { return this.add(new ItemEntity(this.game, x, y, z, s, vel)); }
  spawnTNT(x, y, z, fuse) { return this.add(new PrimedTNT(this.game, x, y, z, fuse)); }
  spawnSpores(x, y, z, radius, life) {
    this.game.renderer.particles.sporeBurst(x, y, z, radius);
    return this.add(new SporeCloud(this.game, x, y, z, radius, life));
  }
  spawnArrow(x, y, z, vx, vy, vz, shooter) {
    this.game.sound.play("bow", { x, y, z });
    return this.add(new Arrow(this.game, x, y, z, vx, vy, vz, shooter));
  }
  update(dt) {
    const p = this.game.player;
    this.explosions = 0;
    for (let i = 0; i < this.list.length; i++) {
      const e = this.list[i];
      if (e.dead) continue;
      // entities in chunks that are not loaded wait (their ground does not exist yet)
      if (!this.game.world.isLoaded(e.pos.x, e.pos.z)) continue;
      if (Math.abs(e.pos.x - p.pos.x) > 160 || Math.abs(e.pos.z - p.pos.z) > 160) continue;
      e.update(dt);
    }
    let j = 0;
    for (let i = 0; i < this.list.length; i++) if (!this.list[i].dead) this.list[j++] = this.list[i];
    this.list.length = j;
  }
  draw(r) {
    const c = r.cam, maxD = Math.min(64, this.game.settings.renderDistance * 16) ** 2;
    for (const e of this.list) {
      if (e.dead) continue;
      const dx = e.pos.x - c.x, dy = e.pos.y + e.h * 0.5 - c.y, dz = e.pos.z - c.z;
      const d2 = dx * dx + dz * dz;
      if (d2 > maxD) continue;
      if (d2 > 4 && dx * c.fx + dy * c.fy + dz * c.fz < -1.5) continue;  // behind the camera
      e.draw(r);
    }
  }
  raycast(ox, oy, oz, dx, dy, dz, maxDist, exclude = null) {
    let best = null;
    for (const e of this.list) {
      if (e.dead || !e.hittable || e === exclude) continue;
      const t = rayBox(ox, oy, oz, dx, dy, dz, e.pos.x - e.hw - 0.05, e.pos.y, e.pos.z - e.hw - 0.05, e.pos.x + e.hw + 0.05, e.pos.y + e.h + 0.05, e.pos.z + e.hw + 0.05);
      if (t >= 0 && t <= maxDist && (!best || t < best.dist)) best = { entity: e, dist: t };
    }
    return best;
  }
  count(pred) { let n = 0; for (const e of this.list) if (!e.dead && pred(e)) n++; return n; }
  nearest(pos, r, pred) {
    let best = null, bd = r * r;
    for (const e of this.list) {
      if (e.dead || !pred(e)) continue;
      const dx = e.pos.x - pos.x, dy = e.pos.y - pos.y, dz = e.pos.z - pos.z;
      const d = dx * dx + dy * dy + dz * dz;
      if (d < bd) { bd = d; best = e; }
    }
    return best;
  }
  clear() { this.list = []; }
}
