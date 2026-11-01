// Targeting, breaking, placing and using blocks, items and entities. The block ray cast is the voxel world's
// (selection boxes included); vehicles are not part of this version.
import { blocks, B, I, COLLIDE, isLiquid, isLava, isWater, itemDef, DIR4 } from "./registry.js";
import { doorId, bedId } from "./updater.js";
import { raycastBlocks } from "./physics.js";
import { newFurnace, newChest } from "./crafting.js";
import { stack } from "./inventory.js";

const REACH_SURVIVAL = 5, REACH_CREATIVE = 6, HEIGHT = 128;
const EAT_TIME = 1.6;
const PLACE_REPEAT = 0.2;
const BREAK_DELAY = 0.25;
const BOW_FULL = 1.0;
const ARROW_SPEED = 55;
const SLAB_FULL = { [B.slab_stone]: B.stone, [B.slab_planks]: B.planks, [B.slab_cobble]: B.cobblestone };
const TILLABLE = new Set([B.grass, B.dirt, B.grass_path, B.snowy_grass]);
const rand = n => (Math.random() * n) | 0;
export { raycastBlocks };

export function canHarvest(def, held) {
  if (def.tier < 0) return true;
  const tool = held ? itemDef(held.id)?.tool : null;
  return !!tool && tool.type === def.tool && tool.tier >= def.tier;
}

export function breakTime(def, held, player) {
  if (def.hardness === Infinity) return Infinity;
  if (def.hardness === 0) return 0;
  const tool = held ? itemDef(held.id)?.tool : null;
  let speed = 1;
  if (tool && def.tool && tool.type === def.tool) speed = tool.speed;
  else if (tool && tool.type === "sword" && def.leaves) speed = 1.5;
  let t = def.hardness * (canHarvest(def, held) ? 1.5 : 5) / speed;
  if (player.eyeInWater) t *= 5;
  if (!player.onGround && !player.flying && !player.riding) t *= 5;
  return t;
}

// facing whose front looks back at the player (0:+z 1:-x 2:-z 3:+x)
export function facingFromYaw(yaw) {
  const nx = Math.sin(yaw), nz = Math.cos(yaw);
  if (Math.abs(nx) > Math.abs(nz)) return nx > 0 ? 3 : 1;
  return nz > 0 ? 0 : 2;
}
// facing the player looks toward (doors, beds, ladders on top faces)
const lookFacing = yaw => (facingFromYaw(yaw) + 2) % 4;

export class Interaction {
  constructor(game) {
    this.game = game;
    this.target = null;      // { kind: "block", x, y, z, id, face, dist } | { kind: "entity", entity, dist }
    this.breaking = null;    // { x, y, z, id, progress }
    this.breakCooldown = 0;
    this.placeTimer = 0;
    this.digSound = 0;
    this.eating = null;      // { t, slot, id, sound }
    this.drawing = null;     // bow: { t, slot }
  }

  get reach() { return this.game.player.creative ? REACH_CREATIVE : REACH_SURVIVAL; }

  updateTarget() {
    const g = this.game, p = g.player;
    const d = p.lookDir();
    const ox = p.pos.x, oy = p.eyeY, oz = p.pos.z;
    const hit = raycastBlocks(g.world, ox, oy, oz, d.x, d.y, d.z, this.reach);
    const ent = g.entities.raycast(ox, oy, oz, d.x, d.y, d.z, 3.5, null);
    if (ent && (!hit || ent.dist < hit.dist)) this.target = { kind: "entity", entity: ent.entity, dist: ent.dist };
    else if (hit) this.target = { kind: "block", ...hit };
    else this.target = null;
  }

  update(dt, input) {
    const g = this.game, p = g.player;
    if (p.dead || p.sleeping) { this.reset(); return; }
    this.updateTarget();
    const t = this.target;
    const breakPressed = input.breakPressed(), breakHeld = input.breakHeld();
    const usePressed = input.usePressed(), useHeld = input.useHeld() || usePressed;

    // ----- attack / break -----
    if (breakPressed) {
      g.renderer.hand.swing();
      if (t && t.kind === "entity") this.attack(t.entity);
    }
    if (this.breakCooldown > 0) this.breakCooldown -= dt;
    if (breakHeld && t && t.kind === "block" && !this.eating && !this.drawing) this.continueBreaking(dt, t, breakPressed);
    else this.stopBreaking();

    // ----- use / place / eat / draw the bow -----
    if (usePressed) { this.placeTimer = PLACE_REPEAT * 1.4; this.use(false); }
    else if (useHeld) {
      this.placeTimer -= dt;
      if (this.placeTimer <= 0 && !this.eating && !this.drawing) { this.placeTimer = PLACE_REPEAT; this.use(true); }
    }
    this.updateEating(dt, useHeld);
    this.updateBow(dt, useHeld);
    if (input.dropPressed()) this.dropHeld(input.sneakToggle || input.key("shift"));

    g.renderer.setHighlight(t && t.kind === "block" ? t : null);
  }

  reset() {
    this.stopBreaking();
    this.eating = null;
    this.drawing = null;
    this.target = null;
    this.game.renderer.setHighlight(null);
  }

  stopBreaking() {
    if (this.breaking) { this.breaking = null; this.game.renderer.setCrack(null, -1); }
  }

  continueBreaking(dt, t, justPressed) {
    const g = this.game, p = g.player;
    const b = this.breaking;
    if (!b || b.x !== t.x || b.y !== t.y || b.z !== t.z || b.id !== t.id) {
      this.breaking = { x: t.x, y: t.y, z: t.z, id: t.id, progress: 0 };
      this.digSound = 0;
    }
    if (this.breakCooldown > 0) return;
    const def = blocks[t.id];
    g.renderer.hand.swing(true);
    if (p.creative) {
      if (justPressed || this.breakCooldown <= 0) {
        this.finishBreak(t.x, t.y, t.z, t.id);
        this.breakCooldown = BREAK_DELAY;
      }
      return;
    }
    const time = breakTime(def, g.inventory.held, p);
    const br = this.breaking;
    br.progress += time === 0 ? 1 : dt / time;
    this.digSound -= dt;
    if (this.digSound <= 0 && time > 0) {
      this.digSound = 0.25;
      g.sound.play(`dig:${def.sound}`, { x: t.x + 0.5, y: t.y + 0.5, z: t.z + 0.5, volume: 0.6 });
      g.renderer.particles.blockHit(t.x, t.y, t.z, t.face, def);
    }
    if (br.progress >= 1) {
      this.finishBreak(t.x, t.y, t.z, t.id);
      this.breaking = null;
      this.breakCooldown = time === 0 ? 0.05 : BREAK_DELAY;
      g.renderer.setCrack(null, -1);
    } else {
      g.renderer.setCrack(br, Math.min(9, Math.floor(br.progress * 10)));
    }
  }

  finishBreak(x, y, z, id) {
    const g = this.game, p = g.player, inv = g.inventory;
    const def = blocks[id];
    const held = inv.held;
    if (id === B.fire) {
      // punching fire puts it out
      g.world.setBlock(x, y, z, B.air);
      g.sound.play("extinguish", { x: x + 0.5, y: y + 0.5, z: z + 0.5, volume: 0.6 });
      return;
    }
    const harvest = canHarvest(def, held);
    g.breakBlock(x, y, z, { drops: !p.creative && harvest, byPlayer: true });
    if (!p.creative) {
      p.exhaustion += 0.005;
      const tool = held ? itemDef(held.id)?.tool : null;
      if (tool && def.hardness > 0) {
        if (inv.damageHeld(tool.type === "sword" ? 2 : 1)) g.sound.play("tool_break");
      }
    }
  }

  attack(entity) {
    const g = this.game, p = g.player, inv = g.inventory;
    if (!entity.hurt) return;
    const held = inv.held;
    const tool = held ? itemDef(held.id)?.tool : null;
    let dmg = tool ? tool.damage : 1;
    const crit = !p.onGround && !p.inWater && p.vel.y < 0;
    if (crit) dmg *= 1.5;
    const knock = p.sprinting ? 1.6 : 1;
    if (entity.hurt(dmg, p.pos, knock, "player")) {
      if (crit) g.renderer.particles.crit(entity.pos.x, entity.pos.y + entity.h * 0.6, entity.pos.z);
      if (!p.creative) {
        p.exhaustion += 0.1;
        if (tool && inv.damageHeld(tool.type === "sword" ? 1 : 2)) g.sound.play("tool_break");
      }
      if (p.sprinting) p.sprinting = false;
    }
  }

  use(repeat) {
    const g = this.game, p = g.player, inv = g.inventory, w = g.world;
    const t = this.target;
    const held = inv.held;
    const hdef = held ? itemDef(held.id) : null;

    if (t && t.kind === "entity") {
      if (!repeat && t.entity.interact && t.entity.interact(p, held, hdef)) { g.renderer.hand.swing(); return; }
    } else if (t && t.kind === "block") {
      const bdef = blocks[t.id];
      if (!p.sneaking && !repeat) {
        if (bdef.use) { g.openBlockScreen(bdef.use, t.x, t.y, t.z); return; }
        if (bdef.door) { this.toggleDoor(t); return; }
        if (bdef.bed) { g.trySleep(t.x, t.y, t.z); return; }
      }
      if (bdef.tnt && hdef?.igniter && !repeat) {
        w.setBlock(t.x, t.y, t.z, B.air);
        g.entities.spawnTNT(t.x + 0.5, t.y, t.z + 0.5, 4);
        g.sound.play("ignite", { x: t.x + 0.5, y: t.y + 0.5, z: t.z + 0.5 });
        g.renderer.hand.swing();
        if (!p.creative && inv.damageHeld(1)) g.sound.play("tool_break");
        return;
      }
    }
    if (!hdef) return;
    if (hdef.bucket) { if (!repeat) this.useBucket(hdef); return; }
    if (hdef.food) {
      if (!this.eating && (p.food < 20 || p.creative || hdef.food.drink)) {
        this.eating = { t: 0, slot: inv.selected, id: held.id, sound: 0 };
      }
      return;
    }
    if (hdef.bow) { if (!repeat && !this.drawing) this.startDraw(); return; }
    if (hdef.igniter) { if (!repeat) this.ignite(t); return; }
    if (hdef.vehicle) return;
    if (!t || t.kind !== "block") return;
    if (hdef.tool?.type === "hoe") { this.till(t); return; }
    if (hdef.seeds) { this.plantSeeds(t); return; }
    if (hdef.boneMeal) { if (!repeat) this.boneMeal(t); return; }
    if (hdef.spawnMob) { if (!repeat) this.spawnEgg(hdef.spawnMob, t); return; }
    if (hdef.placesDoor) { this.placeDoor(t); return; }
    if (hdef.placesBed) { if (!repeat) this.placeBed(t); return; }
    if (hdef.isBlock) this.place(held.id, t);
  }

  // ---------- placement helpers ----------
  // The cell a block would go into when clicking face t.face of t (replaceable blocks are replaced in place).
  placeCell(t) {
    const w = this.game.world;
    let x = t.x, y = t.y, z = t.z, face = t.face;
    const tdef = blocks[t.id];
    if (!(tdef.replaceable && !isLiquid(t.id))) { x += face[0]; y += face[1]; z += face[2]; }
    else face = [0, 1, 0];
    if (y < 0 || y >= HEIGHT || !w.isLoaded(x, z)) return null;
    if (!blocks[w.getBlock(x, y, z)].replaceable) return null;
    return { x, y, z, face };
  }

  // Would a solid block in cells (x, y..y+h-1, z) overlap the player or a solid mob?
  blocked(x, y, z, h = 1) {
    const g = this.game, p = g.player;
    const hit = e => x + 1 > e.pos.x - e.hw && x < e.pos.x + e.hw && z + 1 > e.pos.z - e.hw && z < e.pos.z + e.hw && y + h > e.pos.y && y < e.pos.y + e.h;
    if (!p.riding && hit(p)) return true;
    for (const e of g.entities.list) if (e.solidBody && !e.dead && hit(e)) return true;
    return false;
  }

  consume() {
    const g = this.game;
    g.renderer.hand.swing();
    if (!g.player.creative) g.inventory.consumeHeld(1);
  }

  place(id, t) {
    const g = this.game, p = g.player, w = g.world;
    const def = blocks[id];
    // a slab on top of the same slab becomes the full block
    if (SLAB_FULL[id] && t.id === id && t.face[1] === 1) {
      if (this.blocked(t.x, t.y, t.z)) return;
      w.setBlock(t.x, t.y, t.z, SLAB_FULL[id]);
      g.sound.play(`place:${def.sound}`, { x: t.x + 0.5, y: t.y + 0.5, z: t.z + 0.5 });
      this.consume();
      return;
    }
    const c = this.placeCell(t);
    if (!c) return;
    const { x, y, z, face } = c;
    let placeId = id;
    if (def.facing === 0) placeId = def.base + facingFromYaw(p.yaw);
    if (id === B.torch) {
      if (face[1] === 1) placeId = B.torch;
      else if (face[1] === 0) placeId = B.wall_torch_0 + DIR4.findIndex(([ax, az]) => ax === -face[0] && az === -face[2]);
      else return;
    }
    if (def.climbable) {
      // ladders hang on the wall that was clicked (or, from the top/bottom, the wall the player faces)
      const a = face[1] === 0 ? DIR4.findIndex(([ax, az]) => ax === -face[0] && az === -face[2]) : lookFacing(p.yaw);
      placeId = B.ladder_0 + a;
    }
    if (blocks[placeId].needsSupport && !w.updater.supported(x, y, z, placeId)) return;
    if (COLLIDE[placeId] && this.blocked(x, y, z)) return;
    if (!w.setBlock(x, y, z, placeId)) return;
    const pd = blocks[placeId];
    if (pd.use === "furnace") w.setBlockEntity(x, y, z, newFurnace());
    else if (pd.use === "chest") w.setBlockEntity(x, y, z, newChest());
    g.sound.play(`place:${pd.sound}`, { x: x + 0.5, y: y + 0.5, z: z + 0.5 });
    this.consume();
  }

  placeDoor(t) {
    const g = this.game, p = g.player, w = g.world;
    const c = this.placeCell(t);
    if (!c || c.y + 1 >= HEIGHT) return;
    const { x, y, z } = c;
    if (!blocks[w.getBlock(x, y + 1, z)].replaceable || !COLLIDE[w.getBlock(x, y - 1, z)]) return;
    if (this.blocked(x, y, z, 2)) return;
    const f = lookFacing(p.yaw);
    w.setBlock(x, y, z, doorId(0, f, false));
    w.setBlock(x, y + 1, z, doorId(1, f, false));
    g.sound.play("place:wood", { x: x + 0.5, y: y + 0.5, z: z + 0.5 });
    this.consume();
  }

  placeBed(t) {
    const g = this.game, p = g.player, w = g.world;
    const c = this.placeCell(t);
    if (!c) return;
    const f = lookFacing(p.yaw), [dx, dz] = DIR4[f];
    const hx = c.x + dx, hz = c.z + dz;
    if (!w.isLoaded(hx, hz) || !blocks[w.getBlock(hx, c.y, hz)].replaceable) return;
    if (!COLLIDE[w.getBlock(c.x, c.y - 1, c.z)] || !COLLIDE[w.getBlock(hx, c.y - 1, hz)]) return;
    if (this.blocked(c.x, c.y, c.z) || this.blocked(hx, c.y, hz)) return;
    w.setBlock(c.x, c.y, c.z, bedId(false, f));
    w.setBlock(hx, c.y, hz, bedId(true, f));
    g.sound.play("place:wool", { x: c.x + 0.5, y: c.y + 0.5, z: c.z + 0.5 });
    this.consume();
  }

  toggleDoor(t) {
    const g = this.game, w = g.world;
    const d = blocks[t.id].door;
    const ly = d.half ? t.y - 1 : t.y;
    const lower = blocks[w.getBlock(t.x, ly, t.z)].door, upper = blocks[w.getBlock(t.x, ly + 1, t.z)].door;
    if (!lower || !upper) return;
    const open = !lower.open;
    w.setBlock(t.x, ly, t.z, doorId(0, lower.facing, open));
    w.setBlock(t.x, ly + 1, t.z, doorId(1, lower.facing, open));
    g.sound.play(open ? "door_open" : "door_close", { x: t.x + 0.5, y: ly + 1, z: t.z + 0.5 });
    g.renderer.hand.swing();
  }

  // ---------- items ----------
  // Flint and steel lights a fire on whatever face was clicked.
  ignite(t) {
    const g = this.game, p = g.player, w = g.world, inv = g.inventory;
    if (!t || t.kind !== "block") return;
    let x = t.x, y = t.y, z = t.z;
    const cdef = blocks[t.id];
    if (!(cdef.replaceable && !isLiquid(t.id) && t.id !== B.fire)) { x += t.face[0]; y += t.face[1]; z += t.face[2]; }
    if (y <= 0 || y >= HEIGHT || !w.isLoaded(x, z)) return;
    const cur = w.getBlock(x, y, z);
    if (cur !== B.air && !(blocks[cur].replaceable && !isLiquid(cur) && cur !== B.fire)) return;
    if (!w.updater.fireCanSurvive(x, y, z)) return;
    w.setBlock(x, y, z, B.fire);
    g.sound.play("ignite", { x: x + 0.5, y: y + 0.5, z: z + 0.5 });
    g.renderer.hand.swing();
    if (!p.creative && inv.damageHeld(1)) g.sound.play("tool_break");
  }

  useBucket(hdef) {
    const g = this.game, p = g.player, w = g.world;
    const d = p.lookDir();
    if (hdef.bucket === "empty") {
      const hit = raycastBlocks(w, p.pos.x, p.eyeY, p.pos.z, d.x, d.y, d.z, this.reach, "source");
      if (!hit || !hit.liquid) return;
      const lava = isLava(hit.id);
      w.setBlock(hit.x, hit.y, hit.z, B.air);
      g.sound.play(lava ? "bucket_fill_lava" : "bucket_fill", { x: hit.x + 0.5, y: hit.y + 0.5, z: hit.z + 0.5 });
      this.replaceHeld(lava ? I.lava_bucket : I.water_bucket);
      g.renderer.hand.swing();
      return;
    }
    const hit = raycastBlocks(w, p.pos.x, p.eyeY, p.pos.z, d.x, d.y, d.z, this.reach);
    if (!hit) return;
    let x = hit.x, y = hit.y, z = hit.z;
    if (!(blocks[hit.id].replaceable && !isLiquid(hit.id))) { x += hit.face[0]; y += hit.face[1]; z += hit.face[2]; }
    if (y < 0 || y >= HEIGHT || !w.isLoaded(x, z)) return;
    const cur = w.getBlock(x, y, z);
    const cd = blocks[cur];
    if (!(cur === B.air || isLiquid(cur) || cd.replaceable || (!cd.collide && cd.needsSupport && !cd.climbable))) return;
    const lava = hdef.bucket === "lava";
    if (cur === B.fire && !lava) g.sound.play("extinguish", { x: x + 0.5, y: y + 0.5, z: z + 0.5 });
    else if (cur !== B.air && !isLiquid(cur)) g.spawnBlockDrops(x, y, z, cur);
    w.setBlock(x, y, z, lava ? B.lava : B.water);
    g.sound.play(lava ? "bucket_empty_lava" : "bucket_empty", { x: x + 0.5, y: y + 0.5, z: z + 0.5 });
    this.replaceHeld(I.bucket);
    g.renderer.hand.swing();
  }

  // Swaps one of the held items for another (bucket <-> filled bucket). Creative keeps the held item.
  replaceHeld(id) {
    const g = this.game, inv = g.inventory;
    if (g.player.creative) return;
    const held = inv.held;
    if (held && held.count > 1) {
      held.count--;
      inv.changed();
      const left = inv.add(stack(id, 1));
      if (left > 0) g.throwStack(stack(id, left));
    } else { inv.slots[inv.selected] = stack(id, 1); inv.changed(); }
  }

  till(t) {
    const g = this.game, w = g.world, p = g.player, inv = g.inventory;
    if (t.face[1] === -1 || !TILLABLE.has(t.id) || w.getBlock(t.x, t.y + 1, t.z) !== B.air) return;
    w.setBlock(t.x, t.y, t.z, B.farmland);
    g.sound.play("till", { x: t.x + 0.5, y: t.y + 1, z: t.z + 0.5 });
    g.renderer.hand.swing();
    if (!p.creative && inv.damageHeld(1)) g.sound.play("tool_break");
  }

  plantSeeds(t) {
    const g = this.game, w = g.world;
    if (t.id !== B.farmland || t.face[1] !== 1 || w.getBlock(t.x, t.y + 1, t.z) !== B.air) return;
    w.setBlock(t.x, t.y + 1, t.z, B.wheat_0);
    g.sound.play("place:grass", { x: t.x + 0.5, y: t.y + 1, z: t.z + 0.5 });
    this.consume();
  }

  boneMeal(t) {
    const g = this.game, w = g.world;
    const def = blocks[t.id];
    let ok = false;
    if (def.crop !== undefined && def.crop < 3) {
      w.setBlock(t.x, t.y, t.z, t.id + Math.min(3 - def.crop, 1 + rand(2)));
      ok = true;
    } else if (def.sapling) {
      if (Math.random() < 0.45) w.updater.growTree(t.x, t.y, t.z, def.sapling);
      ok = true;
    } else if (t.id === B.grass && w.getBlock(t.x, t.y + 1, t.z) === B.air) {
      for (let i = 0; i < 32; i++) {
        const tx = t.x + rand(7) - 3, tz = t.z + rand(7) - 3;
        for (const ty of [t.y, t.y + 1, t.y - 1]) {
          if (w.getBlock(tx, ty, tz) !== B.grass || w.getBlock(tx, ty + 1, tz) !== B.air) continue;
          const r = Math.random();
          w.setBlock(tx, ty + 1, tz, r < 0.8 ? B.tall_grass : r < 0.9 ? B.dandelion : B.poppy);
          break;
        }
      }
      ok = true;
    }
    if (!ok) return;
    g.renderer.particles.sparkle(t.x + 0.5, t.y + 0.6, t.z + 0.5, [0.45, 1, 0.45]);
    g.sound.play("place:grass", { x: t.x + 0.5, y: t.y + 0.5, z: t.z + 0.5 });
    this.consume();
  }

  spawnEgg(type, t) {
    const g = this.game;
    const c = this.placeCell(t);
    if (!c) return;
    g.spawner.spawn(type, c.x + 0.5, c.y, c.z + 0.5, { egg: true, yaw: g.player.yaw + Math.PI });
    g.sound.play("pop", { x: c.x + 0.5, y: c.y + 0.5, z: c.z + 0.5, volume: 0.6 });
    this.consume();
  }

  startDraw() {
    const g = this.game, p = g.player, inv = g.inventory;
    if (!p.creative && inv.count(I.arrow) <= 0) return;
    this.drawing = { t: 0, slot: inv.selected };
    g.sound.play("bow_draw", { volume: 0.6 });
  }

  updateBow(dt, holding) {
    const d = this.drawing;
    if (!d) return;
    const g = this.game, inv = g.inventory, p = g.player;
    const held = inv.held;
    if (inv.selected !== d.slot || !held || !itemDef(held.id).bow) { this.drawing = null; return; }
    if (holding) { d.t += dt; return; }
    this.drawing = null;
    let f = Math.min(1, d.t / BOW_FULL);
    f = (f * f + f * 2) / 3;
    if (f < 0.1) return;
    const dir = p.lookDir();
    const speed = ARROW_SPEED * f;
    const a = g.entities.spawnArrow(p.pos.x + dir.x * 0.4, p.eyeY - 0.1 + dir.y * 0.4, p.pos.z + dir.z * 0.4,
      dir.x * speed + p.vel.x, dir.y * speed, dir.z * speed + p.vel.z, p);
    a.crit = f >= 1;
    a.pickup = !p.creative;
    g.renderer.hand.swing();
    if (!p.creative) {
      const i = inv.slots.findIndex(s => s && s.id === I.arrow);
      if (i >= 0) inv.take(i, 1);
      if (inv.damageHeld(1)) g.sound.play("tool_break");
    }
  }

  get bowProgress() { return this.drawing ? Math.min(1, this.drawing.t / BOW_FULL) : 0; }

  updateEating(dt, holding) {
    const e = this.eating;
    if (!e) return;
    const g = this.game, inv = g.inventory, p = g.player;
    const held = inv.held;
    if (!holding || inv.selected !== e.slot || !held || held.id !== e.id) { this.eating = null; return; }
    const food = itemDef(held.id).food;
    e.t += dt;
    e.sound -= dt;
    if (e.sound <= 0) {
      e.sound = food.drink ? 0.5 : 0.22;
      g.sound.play(food.drink ? "drink" : "eat", { volume: 0.7 });
      const d = p.lookDir();
      if (!food.drink) g.renderer.particles.itemCrumbs(p.pos.x + d.x * 0.5, p.eyeY - 0.25 + d.y * 0.5, p.pos.z + d.z * 0.5, held.id);
    }
    if (e.t >= EAT_TIME) {
      p.eat(food);
      if (!p.creative) {
        if (food.drink) this.replaceHeld(I.bucket);
        else inv.consumeHeld(1);
      }
      if (!food.drink) g.sound.play("burp", { volume: 0.6 });
      this.eating = null;
    }
  }

  get eatProgress() { return this.eating ? this.eating.t / EAT_TIME : 0; }

  pickBlock() {
    const g = this.game, inv = g.inventory, t = this.target;
    if (!t || t.kind !== "block") return;
    const def = blocks[t.id];
    let id = def.base !== undefined ? def.base : t.id;
    if (def.climbable) id = B.ladder_0;
    else if (def.attach !== undefined) id = B.torch;
    if (def.door) id = I.oak_door;
    if (def.bed) id = I.bed;
    if (def.crop !== undefined) id = I.wheat_seeds;
    if (t.id === B.fire) return;
    if (t.id >= B.furnace_lit && t.id <= B.furnace_lit_3) id = B.furnace;
    for (let i = 0; i < 9; i++) if (inv.slots[i] && inv.slots[i].id === id) { inv.selected = i; inv.changed(); return; }
    if (!g.player.creative || !itemDef(id)) return;
    let slot = inv.slots[inv.selected] ? inv.slots.findIndex((s, i) => i < 9 && !s) : inv.selected;
    if (slot < 0) slot = inv.selected;
    inv.slots[slot] = stack(id, Math.min(64, itemDef(id).stack));
    inv.selected = slot;
    inv.changed();
  }

  dropHeld(all) {
    const g = this.game, inv = g.inventory;
    if (!inv.held) return;
    const s = inv.take(inv.selected, all ? inv.held.count : 1);
    g.throwStack(s);
    g.renderer.hand.swing();
  }
}
