// Crafting recipes, grid matching, smelting and fuels (no vehicle or saddle recipes: vehicles and horses are not
// part of this version).
import { B, I, TOOL_TIERS, itemDef } from "./registry.js";

const LOGS = [B.oak_log, B.birch_log, B.spruce_log];
const RECIPES = [];

function shaped(pattern, key, id, count = 1) {
  const k = {};
  for (const ch in key) k[ch] = Array.isArray(key[ch]) ? key[ch] : [key[ch]];
  RECIPES.push({ pattern, key: k, result: { id, count }, w: pattern[0].length, h: pattern.length });
}
function shapeless(ingredients, id, count = 1) {
  RECIPES.push({ shapeless: ingredients.map(x => (Array.isArray(x) ? x : [x])), result: { id, count } });
}

shapeless([LOGS], B.planks, 4);
shaped(["P", "P"], { P: B.planks }, I.stick, 4);
shaped(["PP", "PP"], { P: B.planks }, B.crafting_table);
shaped(["CCC", "C C", "CCC"], { C: B.cobblestone }, B.furnace);
shaped(["PPP", "P P", "PPP"], { P: B.planks }, B.chest);
shaped(["C", "S"], { C: I.coal, S: I.stick }, B.torch, 4);
shaped(["SS", "SS"], { S: B.sand }, B.sandstone);
shaped(["SS", "SS"], { S: B.stone }, B.stone_bricks, 4);
shaped(["GSG", "SGS", "GSG"], { G: I.gunpowder, S: B.sand }, B.tnt);
shapeless([I.iron_ingot, I.flint], I.flint_and_steel);

// ---- 1.2: farming, storage, furniture, transport
const WOOL = [B.wool, B.wool_black, B.wool_red, B.wool_blue, B.wool_yellow, B.wool_green, B.wool_orange, B.wool_gray, B.wool_light_blue, B.wool_purple];
shaped(["WWW"], { W: I.wheat }, I.bread);
shaped(["WWW", "WWW", "WWW"], { W: I.wheat }, B.hay_bale);
shapeless([B.hay_bale], I.wheat, 9);
shapeless([I.bone], I.bone_meal, 3);
shaped(["I I", " I "], { I: I.iron_ingot }, I.bucket);
shaped([" SW", "S W", " SW"], { S: I.stick, W: WOOL }, I.bow);
shaped(["F", "S", "E"], { F: I.flint, S: I.stick, E: I.feather }, I.arrow, 4);
for (const [ingot, block] of [[I.iron_ingot, B.iron_block], [I.gold_ingot, B.gold_block], [I.diamond, B.diamond_block], [I.coal, B.coal_block]]) {
  shaped(["XXX", "XXX", "XXX"], { X: ingot }, block);
  shapeless([block], ingot, 9);
}
shaped(["PP", "PP", "PP"], { P: B.planks }, I.oak_door, 3);
shaped(["S S", "SSS", "S S"], { S: I.stick }, B.ladder_0, 3);
shaped(["PSP", "PSP"], { P: B.planks, S: I.stick }, B.fence, 3);
shaped(["WWW", "PPP"], { W: WOOL, P: B.planks }, I.bed);
shaped(["SSS"], { S: B.stone }, B.slab_stone, 6);
shaped(["PPP"], { P: B.planks }, B.slab_planks, 6);
shaped(["CCC"], { C: B.cobblestone }, B.slab_cobble, 6);
shaped(["BB", "BB"], { B: B.bricks }, B.bricks, 4);
shaped(["GGG", "GTG", "GGG"], { G: B.glass, T: B.torch }, B.lamp, 2);
// dyed wool: flowers and plants as dyes, mixed like paint
shapeless([B.wool, I.coal], B.wool_black);
shapeless([B.wool, B.poppy], B.wool_red);
shapeless([B.wool, B.dandelion], B.wool_yellow);
shapeless([B.wool, B.cactus], B.wool_green);
shapeless([B.wool, B.ice], B.wool_blue);
shapeless([B.wool_red, B.wool_yellow], B.wool_orange, 2);
shapeless([B.wool_red, B.wool_blue], B.wool_purple, 2);
shapeless([B.wool_blue, B.wool], B.wool_light_blue, 2);
shapeless([B.wool_black, B.wool], B.wool_gray, 2);

const MATERIALS = [B.planks, B.cobblestone, I.iron_ingot, I.diamond];
TOOL_TIERS.forEach((tier, t) => {
  const M = MATERIALS[t], S = I.stick;
  shaped(["MMM", " S ", " S "], { M, S }, I[`${tier.key}_pickaxe`]);
  shaped(["MM", "MS", " S"], { M, S }, I[`${tier.key}_axe`]);
  shaped(["M", "S", "S"], { M, S }, I[`${tier.key}_shovel`]);
  shaped(["M", "M", "S"], { M, S }, I[`${tier.key}_sword`]);
  shaped(["MM", " S", " S"], { M, S }, I[`${tier.key}_hoe`]);
});

// grid: array of stacks (or null), size w*w. Returns { id, count } or null.
export function matchRecipe(grid, w) {
  let minX = w, minY = w, maxX = -1, maxY = -1;
  const ids = [];
  for (let y = 0; y < w; y++) for (let x = 0; x < w; x++) {
    const s = grid[y * w + x];
    if (!s) continue;
    ids.push(s.id);
    minX = Math.min(minX, x); maxX = Math.max(maxX, x);
    minY = Math.min(minY, y); maxY = Math.max(maxY, y);
  }
  if (!ids.length) return null;
  const gw = maxX - minX + 1, gh = maxY - minY + 1;
  const at = (x, y) => { const s = grid[(minY + y) * w + minX + x]; return s ? s.id : 0; };

  for (const r of RECIPES) {
    if (r.shapeless) {
      if (r.shapeless.length !== ids.length) continue;
      const left = ids.slice();
      let ok = true;
      for (const opts of r.shapeless) {
        const i = left.findIndex(id => opts.includes(id));
        if (i < 0) { ok = false; break; }
        left.splice(i, 1);
      }
      if (ok) return { ...r.result };
      continue;
    }
    if (r.w !== gw || r.h !== gh) continue;
    for (const mirror of [false, true]) {
      let ok = true;
      for (let y = 0; y < gh && ok; y++) for (let x = 0; x < gw && ok; x++) {
        const ch = r.pattern[y][mirror ? gw - 1 - x : x];
        const id = at(x, y);
        if (ch === " ") { if (id) ok = false; }
        else if (!r.key[ch].includes(id)) ok = false;
      }
      if (ok) return { ...r.result };
    }
  }
  return null;
}

// ---------- Furnace ----------
export const SMELT_SECONDS = 10;
const SMELTING = new Map([
  [B.iron_ore, I.iron_ingot], [B.gold_ore, I.gold_ingot], [B.sand, B.glass], [B.cobblestone, B.stone],
  [B.oak_log, I.coal], [B.birch_log, I.coal], [B.spruce_log, I.coal],
  [I.porkchop, I.cooked_porkchop], [I.beef, I.steak], [I.chicken, I.cooked_chicken], [I.mutton, I.cooked_mutton],
]);
export const smeltResult = id => SMELTING.get(id) ?? null;
export const fuelSeconds = id => itemDef(id)?.fuel || 0;

export function newFurnace() {
  return { type: "furnace", slots: [null, null, null], burn: 0, burnMax: 0, cook: 0 }; // input, fuel, output
}
export const RECIPE_COUNT = () => RECIPES.length;

export function newChest() {
  return { type: "chest", slots: new Array(27).fill(null) };
}
