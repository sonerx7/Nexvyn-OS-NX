// The player: input -> movement, survival stats, burning, spores and sleeping (riding is not part of this version).
import { blocks, B } from "./registry.js";
import { moveBoxStep, hasGround, liquidContact, touchesHurtful, touchingIds, boxBlocked } from "./physics.js";

export const GRAVITY = 32, JUMP_VELOCITY = 9, WALK_SPEED = 4.3, SPRINT_SPEED = 5.6, SNEAK_SPEED = 1.3, FLY_SPEED = 11;
export const TERMINAL_VELOCITY = 60, PLAYER_WIDTH = 0.6, PLAYER_HEIGHT = 1.8, EYE_HEIGHT = 1.62, SNEAK_EYE_HEIGHT = 1.32;
export const MAX_HEALTH = 20, MAX_FOOD = 20, MAX_AIR = 10;
const STEP_HEIGHT = 0.6;
const LADDER_UP = 2.4, LADDER_DOWN = 3;

export class Player {
  constructor(game) {
    this.game = game;
    this.pos = { x: 0, y: 80, z: 0 };
    this.vel = { x: 0, y: 0, z: 0 };
    this.hw = PLAYER_WIDTH / 2;
    this.h = PLAYER_HEIGHT;
    this.yaw = 0; this.pitch = 0;
    this.onGround = false; this.collidedH = false; this.hitCeiling = false;
    this.flying = false; this.sneaking = false; this.sprinting = false;
    this.health = MAX_HEALTH; this.food = MAX_FOOD; this.saturation = 5; this.exhaustion = 0;
    this.air = MAX_AIR;
    this.timers = { air: 0, drown: 0, regen: 0, starve: 0, lava: 0.5, cactus: 0.5, burn: 0, inFire: 0.5, spore: 0 };
    this.spores = 0;     // seconds of spore sickness left: slower, no sprinting, a slow drain down to one heart
    this.fallDistance = 0;
    this.invuln = 0; this.hurtTime = 0; this.hurtTilt = 0;
    this.dead = false; this.deathCause = "";
    this.inWater = false; this.eyeInWater = false; this.inLava = false; this.onLadder = false;
    this.fireTime = 0;
    this.eye = EYE_HEIGHT;
    this.walkDist = 0; this.stepDist = 0; this.bobAmount = 0;
    this.fov = 1;
    this.spawn = { x: 0, y: 80, z: 0 };
    this.bed = null;
    this.sleeping = null;
  }

  get creative() { return this.game.mode === "creative"; }
  get eyeY() { return this.pos.y + this.eye; }

  lookDir() {
    const cp = Math.cos(this.pitch);
    return { x: -Math.sin(this.yaw) * cp, y: Math.sin(this.pitch), z: -Math.cos(this.yaw) * cp };
  }

  update(dt, input, settings) {
    if (this.dead) return;
    const world = this.game.world;
    if (this.sleeping) { this.sleeping.t += dt; return; }
    const [dyaw, dpitch] = input.look(dt, settings.sensitivity * (1 - this.game.interaction.bowProgress * 0.5));
    this.yaw += dyaw;
    this.pitch = Math.max(-Math.PI / 2 + 0.001, Math.min(Math.PI / 2 - 0.001, this.pitch + (settings.invertY ? -dpitch : dpitch)));

    const [strafe, fwd] = input.move();
    const jumpPressed = input.jumpPressed();
    const jump = input.jumpHeld();
    const shift = input.sneakHeld();

    if (this.creative) {
      if (jumpPressed && input.doubleJump) { this.flying = !this.flying; this.vel.y = 0; input.doubleJump = false; }
    } else this.flying = false;
    this.sneaking = shift && !this.flying;

    const canSprint = fwd > 0.5 && !this.sneaking && (this.creative || this.food > 6) && this.spores <= 0;
    if (canSprint && input.sprintPressed()) this.sprinting = !this.sprinting;
    if (canSprint && settings.autoSprint && fwd > 0.97) this.sprinting = true;
    if (!canSprint || (this.collidedH && !this.flying)) this.sprinting = false;

    const liq = liquidContact(world, this, this.eyeY);
    const wasInWater = this.inWater;
    this.inWater = liq.water; this.inLava = liq.lava; this.eyeInWater = liq.eyeWater;
    if (this.inWater && !wasInWater && this.vel.y < -4) this.game.sound.play("splash");
    const feet = world.getBlock(Math.floor(this.pos.x), Math.floor(this.pos.y + 0.01), Math.floor(this.pos.z));
    this.onLadder = !!blocks[feet].climbable && !this.flying;

    const s = Math.sin(this.yaw), c = Math.cos(this.yaw);
    let dx = -s * fwd + c * strafe, dz = -c * fwd - s * strafe;
    const len = Math.hypot(dx, dz);
    if (len > 1) { dx /= len; dz /= len; }
    const liquid = this.inWater || this.inLava;
    let speed;
    if (this.flying) speed = FLY_SPEED * (this.sprinting ? 2 : 1);
    else if (liquid) speed = this.inLava ? 1.2 : this.sprinting ? 3 : 2.2;
    else if (this.sneaking) speed = SNEAK_SPEED;
    else if (this.sprinting) speed = SPRINT_SPEED;
    else speed = WALK_SPEED;
    if (this.spores > 0 && !this.flying) speed *= 0.55;
    const control = this.flying ? 9 : this.onGround ? 16 : liquid ? 7 : 3;
    const a = 1 - Math.exp(-control * dt);
    this.vel.x += (dx * speed - this.vel.x) * a;
    this.vel.z += (dz * speed - this.vel.z) * a;

    if (this.flying) {
      const vy = (jump ? 1 : 0) - (shift ? 1 : 0);
      this.vel.y += (vy * FLY_SPEED * 0.75 - this.vel.y) * (1 - Math.exp(-12 * dt));
    } else if (liquid) {
      this.vel.y -= (this.inLava ? 5 : 7) * dt;
      this.vel.y *= Math.exp(-2.2 * dt);
      if (jump) this.vel.y = Math.min(this.vel.y + 26 * dt, this.collidedH ? 4.2 : 2.6);
      this.vel.y = Math.max(this.vel.y, -3.5);
    } else {
      this.vel.y -= GRAVITY * dt;
      if (jump && this.onGround) {
        this.vel.y = JUMP_VELOCITY;
        if (this.sprinting) { this.vel.x += -s * 1.6; this.vel.z += -c * 1.6; }
        this.exhaustion += this.sprinting ? 0.2 : 0.05;
      }
      this.vel.y = Math.max(this.vel.y, -TERMINAL_VELOCITY);
    }
    if (this.onLadder) {
      this.vel.x = Math.max(-3, Math.min(3, this.vel.x));
      this.vel.z = Math.max(-3, Math.min(3, this.vel.z));
      this.vel.y = Math.max(this.vel.y, -LADDER_DOWN);
      if (this.sneaking && this.vel.y < 0) this.vel.y = 0;
      if (this.collidedH || jump) this.vel.y = LADDER_UP;
      this.fallDistance = 0;
    }

    let mdx = this.vel.x * dt, mdz = this.vel.z * dt;
    const mdy = this.vel.y * dt;
    // sneaking never walks off an edge
    if (this.sneaking && this.onGround) {
      const st = 0.05, p = this.pos, hw = this.hw;
      while (mdx !== 0 && !hasGround(world, p.x + mdx, p.y, p.z, hw)) mdx = Math.abs(mdx) < st ? 0 : mdx - Math.sign(mdx) * st;
      while (mdz !== 0 && !hasGround(world, p.x, p.y, p.z + mdz, hw)) mdz = Math.abs(mdz) < st ? 0 : mdz - Math.sign(mdz) * st;
      while (mdx !== 0 && mdz !== 0 && !hasGround(world, p.x + mdx, p.y, p.z + mdz, hw)) {
        mdx = Math.abs(mdx) < st ? 0 : mdx - Math.sign(mdx) * st;
        mdz = Math.abs(mdz) < st ? 0 : mdz - Math.sign(mdz) * st;
      }
    }

    const ox = this.pos.x, oy = this.pos.y, oz = this.pos.z;
    moveBoxStep(world, this, mdx, mdy, mdz, this.flying ? 0 : STEP_HEIGHT);
    if (this.flying && this.onGround) this.flying = false;

    if (this.pos.y < oy && !this.onGround) this.fallDistance += oy - this.pos.y;
    if (liquid || this.flying || this.vel.y > 0 || this.onLadder) this.fallDistance = 0;
    if (this.onGround) {
      if (this.fallDistance > 0.5 && !this.creative) {
        const bx = Math.floor(this.pos.x), by = Math.floor(this.pos.y - 0.2), bz = Math.floor(this.pos.z);
        if (world.getBlock(bx, by, bz) === B.farmland && Math.random() < this.fallDistance - 0.5) world.setBlock(bx, by, bz, B.dirt);
      }
      if (this.fallDistance > 3 && !this.creative) this.damage(Math.floor(this.fallDistance - 3), "fall");
      if (this.fallDistance > 1.5) this.footstep(true);
      this.fallDistance = 0;
    }
    if (this.pos.y < -30) this.damage(1000, "void", null, true);

    const moved = Math.hypot(this.pos.x - ox, this.pos.z - oz);
    if (this.onGround && !this.flying) {
      this.walkDist += moved;
      if (!this.sneaking) {
        this.stepDist += moved;
        if (this.stepDist > 1.6) { this.stepDist = 0; this.footstep(false); }
      }
      if (this.sprinting) this.exhaustion += 0.1 * moved;
    } else if (this.onLadder && Math.abs(this.pos.y - oy) > 0) {
      this.stepDist += Math.abs(this.pos.y - oy);
      if (this.stepDist > 1.2) { this.stepDist = 0; this.game.sound.play("step:wood", { volume: 0.4 }); }
    } else if (liquid && moved > 0) {
      this.stepDist += moved;
      if (this.stepDist > 2.5) { this.stepDist = 0; this.game.sound.play("swim", { volume: 0.4 }); }
    }
    const walking = this.onGround && moved / Math.max(dt, 1e-4) > 0.5;
    this.bobAmount += ((walking ? 1 : 0) - this.bobAmount) * Math.min(1, dt * 8);
    this.eye += ((this.sneaking ? SNEAK_EYE_HEIGHT : EYE_HEIGHT) - this.eye) * Math.min(1, dt * 14);
    this.updateCommon(dt, world);
  }

  updateCommon(dt, world) {
    if (this.creative) this.spores = 0;
    const zoom = this.game.interaction.bowProgress;
    const fovTarget = (this.sprinting ? 1.12 : 1) * (1 - zoom * 0.15);
    this.fov += (fovTarget - this.fov) * Math.min(1, dt * 8);
    if (this.invuln > 0) this.invuln -= dt;
    if (this.hurtTime > 0) this.hurtTime -= dt;
    this.updateFire(dt, world);
    if (!this.creative) this.survival(dt, world);
    else this.air = MAX_AIR;
  }

  updateFire(dt, world) {
    if (this.creative) { this.fireTime = 0; return; }
    const t = this.timers;
    const inFire = touchingIds(world, this, -0.001).some(id => id === B.fire);
    if (inFire) {
      this.fireTime = Math.max(this.fireTime, 8);
      t.inFire += dt;
      if (t.inFire >= 0.5) { t.inFire = 0; this.damage(1, "inFire"); }
    } else t.inFire = 0.5;
    if (this.inLava) this.fireTime = Math.max(this.fireTime, 15);
    if (this.inWater || (this.fireTime > 0 && this.game.weather.isRainingAt(this.pos.x, this.pos.y + this.h, this.pos.z))) {
      if (this.fireTime > 0) this.game.sound.play("extinguish", { volume: 0.5 });
      this.fireTime = 0;
    }
    if (this.fireTime > 0) {
      this.fireTime -= dt;
      t.burn += dt;
      if (t.burn >= 1) { t.burn = 0; if (!this.inLava) this.damage(1, "fire", null, true); }
    } else t.burn = 0;
  }

  footstep(landing) {
    const p = this.pos;
    const id = this.game.world.getBlock(Math.floor(p.x), Math.floor(p.y - 0.2), Math.floor(p.z));
    if (!id) return;
    this.game.sound.play(`step:${blocks[id].sound || "stone"}`, { volume: landing ? 0.9 : 0.45 });
  }

  survival(dt, world) {
    const t = this.timers;
    if (this.eyeInWater) {
      if (this.air > 0) { t.air += dt; while (t.air >= 1.5 && this.air > 0) { t.air -= 1.5; this.air--; } }
      else { t.drown += dt; if (t.drown >= 1) { t.drown = 0; this.damage(2, "drown", null, true); } }
    } else {
      this.air = Math.min(MAX_AIR, this.air + dt * 5);
      t.air = 0; t.drown = 0;
    }
    if (this.inLava) { t.lava += dt; if (t.lava >= 0.5) { t.lava = 0; this.damage(4, "lava"); } }
    else t.lava = 0.5;
    if (touchesHurtful(world, this)) { t.cactus += dt; if (t.cactus >= 0.5) { t.cactus = 0; this.damage(1, "cactus"); } }
    else t.cactus = 0.5;
    // spores never kill on their own: they stop at one heart
    if (this.spores > 0) {
      this.spores -= dt;
      t.spore += dt;
      if (t.spore >= 1.25) { t.spore = 0; if (this.health > 2) this.damage(1, "spores", null, true); }
    }
    while (this.exhaustion >= 4) {
      this.exhaustion -= 4;
      if (this.saturation > 0) this.saturation = Math.max(0, this.saturation - 1);
      else this.food = Math.max(0, this.food - 1);
    }
    if (this.food >= 18 && this.health < MAX_HEALTH) {
      t.regen += dt;
      if (t.regen >= 4) { t.regen = 0; this.heal(1); this.exhaustion += 6; }
    } else t.regen = 0;
    if (this.food <= 0) {
      t.starve += dt;
      if (t.starve >= 4) { t.starve = 0; if (this.health > 1) this.damage(1, "starve", null, true); }
    } else t.starve = 0;
  }

  heal(n) { this.health = Math.min(MAX_HEALTH, this.health + n); }

  // Standing in a Puffcap's spore cloud (entities.js): the sickness lasts a moment after leaving it.
  inSpores() {
    if (this.creative || this.dead) return;
    if (this.spores <= 0) {
      this.timers.spore = 0.4;
      if (!this.game.sporeHint) { this.game.sporeHint = true; this.game.hud.message(TR("msg.spores")); }
    }
    this.spores = Math.max(this.spores, 2.5);
  }

  damage(amount, cause, source = null, bypass = false) {
    if (this.dead || (this.creative && cause !== "void") || amount <= 0) return false;
    if (this.invuln > 0 && !bypass) return false;
    if (this.sleeping) this.game.wakeUp();
    this.health -= amount;
    this.invuln = 0.5;
    this.hurtTime = 0.35;
    this.hurtTilt = Math.random() < 0.5 ? -1 : 1;
    this.exhaustion += 0.1;
    if (source && source.pos) {
      const kx = this.pos.x - source.pos.x, kz = this.pos.z - source.pos.z;
      const l = Math.hypot(kx, kz) || 1;
      this.vel.x += (kx / l) * 6; this.vel.z += (kz / l) * 6;
      this.vel.y = Math.max(this.vel.y, 4.5);
    }
    this.game.sound.play("hurt");
    this.game.hud.flashDamage();
    this.game.rumble(Math.min(1, 0.35 + amount * 0.08), 120);
    if (this.health <= 0) this.die(cause);
    return true;
  }

  die(cause) {
    this.health = 0;
    this.dead = true;
    this.deathCause = cause;
    this.sprinting = false;
    this.fireTime = 0;
    this.spores = 0;
    this.game.sound.play("death");
    this.game.onPlayerDeath(cause);
  }

  respawn() {
    let s = this.spawn;
    const b = this.bed, w = this.game.world;
    if (b) {
      const head = blocks[w.getBlock(b.x, b.y, b.z)].bed;
      if (head && head.head) s = { x: b.x + 0.5, y: b.y + 0.6, z: b.z + 0.5 };
      else if (w.isLoaded(b.x, b.z)) { this.bed = null; this.game.hud.message(TR("msg.no_bed")); }
    }
    this.pos.x = s.x; this.pos.y = s.y; this.pos.z = s.z;
    this.vel.x = this.vel.y = this.vel.z = 0;
    this.health = MAX_HEALTH; this.food = MAX_FOOD; this.saturation = 5; this.exhaustion = 0; this.air = MAX_AIR;
    this.fallDistance = 0; this.dead = false; this.invuln = 1; this.flying = false; this.fireTime = 0; this.spores = 0;
  }

  eat(food) {
    this.food = Math.min(MAX_FOOD, this.food + food.hunger);
    this.saturation = Math.min(this.food, this.saturation + food.sat);
  }

  boxBlocked(w) { return boxBlocked(w, this.pos.x, this.pos.y, this.pos.z, this.hw, this.h); }

  toJSON() {
    return {
      pos: [this.pos.x, this.pos.y, this.pos.z], yaw: this.yaw, pitch: this.pitch,
      health: this.health, food: this.food, saturation: this.saturation, exhaustion: this.exhaustion,
      air: this.air, flying: this.flying, spawn: [this.spawn.x, this.spawn.y, this.spawn.z], dead: this.dead,
      bed: this.bed ? [this.bed.x, this.bed.y, this.bed.z] : null, fire: this.fireTime,
    };
  }

  load(d) {
    if (!d) return;
    if (Array.isArray(d.pos)) { this.pos.x = d.pos[0]; this.pos.y = d.pos[1]; this.pos.z = d.pos[2]; }
    if (Array.isArray(d.spawn)) { this.spawn.x = d.spawn[0]; this.spawn.y = d.spawn[1]; this.spawn.z = d.spawn[2]; }
    if (Array.isArray(d.bed)) this.bed = { x: d.bed[0], y: d.bed[1], z: d.bed[2] };
    this.yaw = d.yaw || 0; this.pitch = d.pitch || 0;
    this.health = d.health ?? MAX_HEALTH; this.food = d.food ?? MAX_FOOD;
    this.saturation = d.saturation ?? 5; this.exhaustion = d.exhaustion || 0;
    this.air = d.air ?? MAX_AIR; this.flying = !!d.flying;
    this.fireTime = d.fire || 0;
    if (d.dead || this.health <= 0) this.respawn();
  }
}
