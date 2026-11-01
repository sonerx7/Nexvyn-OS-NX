// Block + item registry (ids are stored in saves: append only). Display names come from lang/*.json ("n.<key>");
// the Turkish names below are working names and are not shown.
// Block ids are 0..255 (stored in Uint8Array chunks); item ids start at 256.

// ---------- Texture tiles (atlas order of textures/atlas.png) ----------
export const TILES = [
  "stone", "grass_top", "grass_side", "dirt", "cobblestone", "planks", "bedrock", "sand",
  "gravel", "oak_log", "log_top", "oak_leaves", "glass", "coal_ore", "iron_ore", "gold_ore",
  "diamond_ore", "crafting_top", "crafting_side", "crafting_front", "furnace_front", "furnace_front_on", "furnace_side", "furnace_top",
  "chest_front", "chest_side", "chest_top", "torch", "water", "lava", "sandstone_side", "sandstone_top",
  "snow", "snowy_grass_side", "ice", "cactus_side", "cactus_top", "birch_log", "birch_leaves", "spruce_log",
  "spruce_leaves", "tall_grass", "dandelion", "poppy", "dead_bush", "bricks", "wool", "tnt_side",
  "tnt_top", "tnt_bottom", "stone_bricks", "spruce_log_top", "birch_log_top", "sandstone_bottom",
  // 1.2
  "fire", "asphalt", "road_line_x", "road_line_z", "sidewalk", "concrete", "concrete_gray", "window",
  "window_lit", "lamp", "checker", "curb_red", "curb_white", "barrier", "boost_pad", "iron_block",
  "gold_block", "diamond_block", "coal_block", "hay_top", "hay_side", "bookshelf", "farmland", "path_top",
  "path_side", "wheat_0", "wheat_1", "wheat_2", "wheat_3", "door_top", "door_bottom", "ladder",
  "bed_top_foot", "bed_top_head", "bed_side_foot", "bed_side_head", "bed_end_foot", "bed_end_head", "sapling_oak", "sapling_birch",
  "sapling_spruce", "wool_black", "wool_red", "wool_blue", "wool_yellow", "wool_green", "wool_orange", "wool_gray",
  "wool_light_blue", "wool_purple", "obsidian",
  // 1.0 (BlockCraft)
  "sulfur_ore",
];
export const TILE = Object.fromEntries(TILES.map((n, i) => [n, i]));
export const ATLAS_COLS = 16;

// ---------- Tools ----------
export const TOOL_TIERS = [
  { key: "wood",    name: "Tahta",  speed: 2, durability: 59,   damage: 4 },
  { key: "stone",   name: "Taş",    speed: 4, durability: 131,  damage: 5 },
  { key: "iron",    name: "Demir",  speed: 6, durability: 250,  damage: 6 },
  { key: "diamond", name: "Elmas",  speed: 8, durability: 1561, damage: 7 },
];
export const TOOL_TYPES = [
  { key: "pickaxe", name: "Kazma" },
  { key: "axe",     name: "Balta" },
  { key: "shovel",  name: "Kürek" },
  { key: "sword",   name: "Kılıç" },
];

// ---------- Blocks ----------
export const blocks = [];
export const B = {};

const DEFAULTS = {
  model: "cube",       // cube | cutout | cross | torch | cactus | liquid | fire | crop | fence | door | ladder | bed | slab | none
  solid: true,         // full opaque cube: culls neighbour faces, casts AO
  collide: true,
  opacity: 15,         // light reduction (15 = blocks light)
  emit: 0,
  hardness: 1,
  tool: null,          // pickaxe | axe | shovel
  tier: -1,            // min tool tier index needed to get drops (-1 = any, incl. hand)
  sound: "stone",
  selectable: true,
  replaceable: false,
  gravity: false,
  needsSupport: false, // breaks when block below disappears
  creative: true,      // shown in creative palette
  stack: 64,
  facing: -1,          // 0..3 for oriented blocks
};

function def(key, name, props) {
  const id = blocks.length;
  const d = Object.assign({ id, key, name, nk: key }, DEFAULTS, props);
  if (typeof d.tex === "string") d.tex = { top: d.tex, bottom: d.tex, side: d.tex };
  if (d.tex) {
    d.t = {
      top: TILE[d.tex.top], bottom: TILE[d.tex.bottom], side: TILE[d.tex.side],
      front: d.tex.front != null ? TILE[d.tex.front] : TILE[d.tex.side],
    };
    for (const k in d.t) if (d.t[k] === undefined) throw new Error(`Unknown tile for ${key}.${k}`);
  }
  if (d.drop === undefined) d.drop = id;
  blocks.push(d);
  B[key] = id;
  return id;
}

// Four ids, one per facing (0:+z 1:-x 2:-z 3:+x). Items use the base id.
function defOriented(key, name, props) {
  const base = blocks.length;
  for (let f = 0; f < 4; f++) {
    def(f === 0 ? key : `${key}_${f}`, name, Object.assign({}, props, { nk: key, facing: f, base, drop: base, creative: f === 0 && props.creative !== false }));
  }
  B[key] = base;
  return base;
}

def("air", "Hava", { model: "none", solid: false, collide: false, opacity: 0, selectable: false, replaceable: true, creative: false, hardness: 0, drop: 0 });
def("stone", "Taş", { tex: "stone", hardness: 1.5, tool: "pickaxe", tier: 0, drop: "cobblestone" });
def("grass", "Çimen Bloğu", { tex: { top: "grass_top", bottom: "dirt", side: "grass_side" }, hardness: 0.6, tool: "shovel", sound: "grass", drop: "dirt" });
def("dirt", "Toprak", { tex: "dirt", hardness: 0.5, tool: "shovel", sound: "gravel" });
def("cobblestone", "Kırık Taş", { tex: "cobblestone", hardness: 2, tool: "pickaxe", tier: 0 });
def("planks", "Tahta", { tex: "planks", hardness: 2, tool: "axe", sound: "wood", fuel: 15, fire: [5, 20] });
def("bedrock", "Ana Kaya", { tex: "bedrock", hardness: Infinity, drop: 0 });
def("sand", "Kum", { tex: "sand", hardness: 0.5, tool: "shovel", sound: "sand", gravity: true });
def("gravel", "Çakıl", { tex: "gravel", hardness: 0.6, tool: "shovel", sound: "gravel", gravity: true });
def("oak_log", "Meşe Kütüğü", { tex: { top: "log_top", bottom: "log_top", side: "oak_log" }, hardness: 2, tool: "axe", sound: "wood", fuel: 15, log: true, fire: [5, 5] });
def("oak_leaves", "Meşe Yaprağı", { tex: "oak_leaves", model: "cutout", solid: false, opacity: 1, hardness: 0.2, sound: "grass", leaves: true, drop: 0, fire: [30, 60] });
def("glass", "Cam", { tex: "glass", model: "cutout", solid: false, opacity: 0, hardness: 0.3, sound: "glass", drop: 0 });
def("coal_ore", "Kömür Cevheri", { tex: "coal_ore", hardness: 3, tool: "pickaxe", tier: 0, drop: "coal" });
def("iron_ore", "Demir Cevheri", { tex: "iron_ore", hardness: 3, tool: "pickaxe", tier: 1 });
def("gold_ore", "Altın Cevheri", { tex: "gold_ore", hardness: 3, tool: "pickaxe", tier: 2 });
def("diamond_ore", "Elmas Cevheri", { tex: "diamond_ore", hardness: 3, tool: "pickaxe", tier: 2, drop: "diamond" });
def("crafting_table", "Üretim Masası", { tex: { top: "crafting_top", bottom: "planks", side: "crafting_side", front: "crafting_front" }, hardness: 2.5, tool: "axe", sound: "wood", fuel: 15, use: "crafting" });
defOriented("furnace", "Fırın", { tex: { top: "furnace_top", bottom: "furnace_top", side: "furnace_side", front: "furnace_front" }, hardness: 3.5, tool: "pickaxe", tier: 0, use: "furnace" });
defOriented("furnace_lit", "Yanan Fırın", { tex: { top: "furnace_top", bottom: "furnace_top", side: "furnace_side", front: "furnace_front_on" }, hardness: 3.5, tool: "pickaxe", tier: 0, emit: 13, use: "furnace", creative: false, dropKey: "furnace" });
defOriented("chest", "Sandık", { tex: { top: "chest_top", bottom: "chest_top", side: "chest_side", front: "chest_front" }, hardness: 2.5, tool: "axe", sound: "wood", fuel: 15, use: "chest" });
def("torch", "Meşale", { tex: "torch", model: "torch", solid: false, collide: false, opacity: 0, emit: 14, hardness: 0, sound: "wood", needsSupport: true });
// Wall torches lean away from the block they hang on. attach = direction of that block (0:+z 1:-x 2:-z 3:+x).
for (let a = 0; a < 4; a++) {
  def(`wall_torch_${a}`, "Meşale", { nk: "torch", tex: "torch", model: "torch", solid: false, collide: false, opacity: 0, emit: 14, hardness: 0, sound: "wood", needsSupport: true, attach: a, drop: "torch", creative: false });
}
def("water", "Su", { tex: "water", model: "liquid", solid: false, collide: false, opacity: 2, hardness: Infinity, selectable: false, replaceable: true, liquid: "water", level: 8, creative: false, drop: 0 });
for (let l = 1; l <= 7; l++) {
  def(`water_${l}`, "Akan Su", { nk: "water", tex: "water", model: "liquid", solid: false, collide: false, opacity: 2, hardness: Infinity, selectable: false, replaceable: true, liquid: "water", level: l, creative: false, drop: 0 });
}
def("lava", "Lav", { tex: "lava", model: "liquid", solid: false, collide: false, opacity: 0, emit: 15, hardness: Infinity, selectable: false, replaceable: true, liquid: "lava", level: 8, creative: false, drop: 0 });
def("sandstone", "Kumtaşı", { tex: { top: "sandstone_top", bottom: "sandstone_bottom", side: "sandstone_side" }, hardness: 0.8, tool: "pickaxe", tier: 0 });
def("snow", "Kar", { tex: "snow", hardness: 0.2, tool: "shovel", sound: "snow" });
def("snowy_grass", "Karlı Çimen", { tex: { top: "snow", bottom: "dirt", side: "snowy_grass_side" }, hardness: 0.6, tool: "shovel", sound: "snow", drop: "dirt" });
def("ice", "Buz", { tex: "ice", model: "cutout", solid: false, opacity: 2, hardness: 0.5, tool: "pickaxe", sound: "glass", drop: 0, translucent: true });
def("cactus", "Kaktüs", { tex: { top: "cactus_top", bottom: "cactus_top", side: "cactus_side" }, model: "cactus", solid: false, opacity: 0, hardness: 0.4, sound: "wool", needsSupport: true, hurts: 1 });
def("birch_log", "Huş Kütüğü", { tex: { top: "birch_log_top", bottom: "birch_log_top", side: "birch_log" }, hardness: 2, tool: "axe", sound: "wood", fuel: 15, log: true, fire: [5, 5] });
def("birch_leaves", "Huş Yaprağı", { tex: "birch_leaves", model: "cutout", solid: false, opacity: 1, hardness: 0.2, sound: "grass", leaves: true, drop: 0, fire: [30, 60] });
def("spruce_log", "Ladin Kütüğü", { tex: { top: "spruce_log_top", bottom: "spruce_log_top", side: "spruce_log" }, hardness: 2, tool: "axe", sound: "wood", fuel: 15, log: true, fire: [5, 5] });
def("spruce_leaves", "Ladin Yaprağı", { tex: "spruce_leaves", model: "cutout", solid: false, opacity: 1, hardness: 0.2, sound: "grass", leaves: true, drop: 0, fire: [30, 60] });
def("tall_grass", "Uzun Ot", { tex: "tall_grass", model: "cross", solid: false, collide: false, opacity: 0, hardness: 0, sound: "grass", replaceable: true, needsSupport: true, drop: 0, plant: true, fire: [60, 100] });
def("dandelion", "Karahindiba", { tex: "dandelion", model: "cross", solid: false, collide: false, opacity: 0, hardness: 0, sound: "grass", needsSupport: true, plant: true, fire: [60, 100] });
def("poppy", "Gelincik", { tex: "poppy", model: "cross", solid: false, collide: false, opacity: 0, hardness: 0, sound: "grass", needsSupport: true, plant: true, fire: [60, 100] });
def("dead_bush", "Kuru Çalı", { tex: "dead_bush", model: "cross", solid: false, collide: false, opacity: 0, hardness: 0, sound: "grass", replaceable: true, needsSupport: true, drop: 0, plant: true, fire: [60, 100] });
def("bricks", "Tuğla", { tex: "bricks", hardness: 2, tool: "pickaxe", tier: 0 });
def("wool", "Yün", { tex: "wool", hardness: 0.8, sound: "wool", fire: [30, 60] });
def("tnt", "TNT", { tex: { top: "tnt_top", bottom: "tnt_bottom", side: "tnt_side" }, hardness: 0, sound: "grass", tnt: true, fire: [15, 100] });
def("stone_bricks", "Taş Tuğla", { tex: "stone_bricks", hardness: 1.5, tool: "pickaxe", tier: 0 });

// ---------------------------------------------------------------- 1.2 (append only: ids are stored in saves)
// fire: [chance to catch fire from a burning neighbour, chance to burn away]
const FLAM_WOOD = [5, 20], FLAM_LOG = [5, 5], FLAM_LEAF = [30, 60], FLAM_WOOL = [30, 60], FLAM_PLANT = [60, 100];
def("fire", "Ateş", { tex: "fire", model: "fire", solid: false, collide: false, opacity: 0, emit: 15, hardness: 0, sound: "wool", replaceable: true, creative: false, drop: 0, fire: null, hurtsFire: true });
def("asphalt", "Asfalt", { tex: "asphalt", hardness: 1.5, tool: "pickaxe", tier: 0 });
def("road_line_x", "Yol Çizgisi (D-B)", { tex: { top: "road_line_x", bottom: "asphalt", side: "asphalt" }, hardness: 1.5, tool: "pickaxe", tier: 0 });
def("road_line_z", "Yol Çizgisi (K-G)", { tex: { top: "road_line_z", bottom: "asphalt", side: "asphalt" }, hardness: 1.5, tool: "pickaxe", tier: 0 });
def("sidewalk", "Kaldırım", { tex: "sidewalk", hardness: 1.5, tool: "pickaxe", tier: 0 });
def("concrete", "Beton", { tex: "concrete", hardness: 1.8, tool: "pickaxe", tier: 0 });
def("concrete_gray", "Gri Beton", { tex: "concrete_gray", hardness: 1.8, tool: "pickaxe", tier: 0 });
def("window", "Pencere", { tex: "window", hardness: 0.3, sound: "glass", drop: 0 });
def("window_lit", "Aydınlık Pencere", { tex: "window_lit", hardness: 0.3, sound: "glass", emit: 10, fxGlow: true, drop: 0 });
def("lamp", "Lamba", { tex: "lamp", hardness: 0.3, sound: "glass", emit: 15, fxEmit: true });
def("checker", "Damalı Blok", { tex: "checker", hardness: 1.5, tool: "pickaxe", tier: 0 });
def("curb_red", "Kırmızı Bordür", { tex: "curb_red", hardness: 1.5, tool: "pickaxe", tier: 0 });
def("curb_white", "Beyaz Bordür", { tex: "curb_white", hardness: 1.5, tool: "pickaxe", tier: 0 });
def("barrier", "Lastik Bariyer", { tex: "barrier", hardness: 1, sound: "wool" });
def("boost_pad", "Hız Pedi", { tex: { top: "boost_pad", bottom: "asphalt", side: "asphalt" }, hardness: 1.5, tool: "pickaxe", tier: 0, emit: 7, fxGlow: true, boost: true });
def("iron_block", "Demir Blok", { tex: "iron_block", hardness: 5, tool: "pickaxe", tier: 1 });
def("gold_block", "Altın Blok", { tex: "gold_block", hardness: 3, tool: "pickaxe", tier: 2 });
def("diamond_block", "Elmas Blok", { tex: "diamond_block", hardness: 5, tool: "pickaxe", tier: 2 });
def("coal_block", "Kömür Blok", { tex: "coal_block", hardness: 5, tool: "pickaxe", tier: 0, fuel: 800, fire: FLAM_LOG });
def("hay_bale", "Saman Balyası", { tex: { top: "hay_top", bottom: "hay_top", side: "hay_side" }, hardness: 0.5, sound: "grass", fire: [60, 20] });
def("bookshelf", "Kitaplık", { tex: { top: "planks", bottom: "planks", side: "bookshelf" }, hardness: 1.5, tool: "axe", sound: "wood", fire: [30, 20], fuel: 15 });
def("farmland", "Tarla", { tex: { top: "farmland", bottom: "dirt", side: "dirt" }, hardness: 0.6, tool: "shovel", sound: "gravel", drop: "dirt" });
def("grass_path", "Patika", { tex: { top: "path_top", bottom: "dirt", side: "path_side" }, hardness: 0.6, tool: "shovel", sound: "grass", drop: "dirt" });
for (let st = 0; st < 4; st++) {
  def(`wheat_${st}`, "Buğday", { nk: "wheat", tex: `wheat_${st}`, model: "crop", solid: false, collide: false, opacity: 0, hardness: 0, sound: "grass", needsSupport: true, crop: st, creative: false, fire: FLAM_PLANT, drop: "wheat_seeds" });
}
// 1.5 blocks tall for collision: animals and players cannot jump over fences
def("fence", "Çit", { tex: "planks", model: "fence", solid: false, opacity: 0, hardness: 2, tool: "axe", sound: "wood", fire: FLAM_WOOD, fuel: 15, box: [0, 0, 0, 1, 1.5, 1] });
// doors: lower/upper half x facing (front, 0:+z 1:-x 2:-z 3:+x) x open
for (let half = 0; half < 2; half++) for (let f = 0; f < 4; f++) for (let open = 0; open < 2; open++) {
  def(`oak_door_${half}${f}${open}`, "Tahta Kapı", { nk: "oak_door", tex: half ? "door_top" : "door_bottom", model: "door", solid: false, opacity: 0, hardness: 3, tool: "axe", sound: "wood", creative: false, door: { half, facing: f, open }, drop: "oak_door", fire: FLAM_WOOD });
}
for (let a = 0; a < 4; a++) {
  def(`ladder_${a}`, "Merdiven", { nk: "ladder", tex: "ladder", model: "ladder", solid: false, collide: false, opacity: 0, hardness: 0.4, tool: "axe", sound: "wood", attach: a, climbable: true, creative: a === 0, drop: "ladder_0", needsSupport: true });
}
for (let part = 0; part < 2; part++) for (let f = 0; f < 4; f++) {
  def(`bed_${part ? "head" : "foot"}_${f}`, "Yatak", { nk: "bed",
    tex: part ? { top: "bed_top_head", bottom: "planks", side: "bed_side_head", front: "bed_end_head" } : { top: "bed_top_foot", bottom: "planks", side: "bed_side_foot", front: "bed_end_foot" },
    model: "bed", solid: false, opacity: 0, hardness: 0.2, sound: "wool", creative: false, bed: { head: part === 1, facing: f }, drop: "bed", fire: FLAM_WOOL,
  });
}
def("sapling_oak", "Meşe Fidanı", { tex: "sapling_oak", model: "cross", solid: false, collide: false, opacity: 0, hardness: 0, sound: "grass", needsSupport: true, plant: true, sapling: "oak" });
def("sapling_birch", "Huş Fidanı", { tex: "sapling_birch", model: "cross", solid: false, collide: false, opacity: 0, hardness: 0, sound: "grass", needsSupport: true, plant: true, sapling: "birch" });
def("sapling_spruce", "Ladin Fidanı", { tex: "sapling_spruce", model: "cross", solid: false, collide: false, opacity: 0, hardness: 0, sound: "grass", needsSupport: true, plant: true, sapling: "spruce" });
for (const [k, n] of [["black", "Siyah"], ["red", "Kırmızı"], ["blue", "Mavi"], ["yellow", "Sarı"], ["green", "Yeşil"], ["orange", "Turuncu"], ["gray", "Gri"], ["light_blue", "Açık Mavi"], ["purple", "Mor"]]) {
  def(`wool_${k}`, `${n} Yün`, { tex: `wool_${k}`, hardness: 0.8, sound: "wool", fire: FLAM_WOOL });
}
def("slab_stone", "Taş Basamak", { tex: "stone", model: "slab", solid: false, opacity: 0, hardness: 1.5, tool: "pickaxe", tier: 0, box: [0, 0, 0, 1, 0.5, 1] });
def("slab_planks", "Tahta Basamak", { tex: "planks", model: "slab", solid: false, opacity: 0, hardness: 2, tool: "axe", sound: "wood", box: [0, 0, 0, 1, 0.5, 1], fire: FLAM_WOOD, fuel: 7 });
def("slab_cobble", "Kırık Taş Basamak", { tex: "cobblestone", model: "slab", solid: false, opacity: 0, hardness: 2, tool: "pickaxe", tier: 0, box: [0, 0, 0, 1, 0.5, 1] });
def("obsidian", "Obsidyen", { tex: "obsidian", hardness: 50, tool: "pickaxe", tier: 3 });
for (let l = 1; l <= 3; l++) {
  def(`lava_${l}`, "Akan Lav", { nk: "lava", tex: "lava", model: "liquid", solid: false, collide: false, opacity: 0, emit: 15, hardness: Infinity, selectable: false, replaceable: true, liquid: "lava", level: l, creative: false, drop: 0 });
}
// sulfur ore: small veins deep in the stone (game.js decorate); mined with any pickaxe, it gives 1-2 gunpowder
def("sulfur_ore", "Kükürt Cevheri", { tex: "sulfur_ore", hardness: 3, tool: "pickaxe", tier: 0, drop: "gunpowder", dropCount: [1, 2] });

export const BLOCK_COUNT = blocks.length;

// Fast lookup tables (used heavily by mesher/physics).
export const SOLID = new Uint8Array(256);
export const COLLIDE = new Uint8Array(256);
export const OPACITY = new Uint8Array(256);
export const EMIT = new Uint8Array(256);
export const MODEL = new Uint8Array(256);
export const MODELS = { none: 0, cube: 1, cutout: 2, cross: 3, torch: 4, cactus: 5, liquid: 6, fire: 7, crop: 8, fence: 9, door: 10, ladder: 11, bed: 12, slab: 13 };
for (const d of blocks) {
  SOLID[d.id] = d.solid ? 1 : 0;
  COLLIDE[d.id] = d.collide ? 1 : 0;
  OPACITY[d.id] = d.opacity;
  EMIT[d.id] = d.emit;
  MODEL[d.id] = MODELS[d.model];
}

export const isWater = id => id >= B.water && id <= B.water_7;
export const isLava = id => id === B.lava || (id >= B.lava_1 && id <= B.lava_3);
export const lavaLevel = id => (id === B.lava ? 4 : id >= B.lava_1 && id <= B.lava_3 ? id - B.lava_1 + 1 : 0);
export const lavaId = level => (level >= 4 ? B.lava : level <= 0 ? B.air : B.lava_1 + level - 1);
export const isFlammable = id => !!(blocks[id] && blocks[id].fire);
export const isLiquid = id => isWater(id) || isLava(id);
export const waterLevel = id => (id === B.water ? 8 : isWater(id) ? id - B.water : 0);
export const waterId = level => (level >= 8 ? B.water : level <= 0 ? B.air : B.water + level);

// ---------- Items ----------
export const items = new Map();
export const I = {};
let nextItem = 256;

function item(key, name, props = {}) {
  const id = nextItem++;
  const d = Object.assign({ id, key, name, stack: 64, isBlock: false, creative: true }, props);
  items.set(id, d);
  I[key] = id;
  return id;
}

item("stick", "Çubuk", { fuel: 5 });
item("coal", "Kömür", { fuel: 80 });
item("iron_ingot", "Demir Külçe");
item("gold_ingot", "Altın Külçe");
item("diamond", "Elmas");
item("flint", "Çakmaktaşı");
item("flint_and_steel", "Çakmak", { stack: 1, durability: 64, igniter: true });
item("gunpowder", "Barut");
item("bone", "Kemik");
item("arrow", "Ok");
item("feather", "Tüy");
item("leather", "Deri");
item("rotten_flesh", "Çürük Et", { food: { hunger: 4, sat: 0.8 } });
item("apple", "Elma", { food: { hunger: 4, sat: 2.4 } });
item("porkchop", "Çiğ Domuz Eti", { food: { hunger: 3, sat: 1.8 } });
item("cooked_porkchop", "Pişmiş Domuz Eti", { food: { hunger: 8, sat: 12.8 } });
item("beef", "Çiğ Sığır Eti", { food: { hunger: 3, sat: 1.8 } });
item("steak", "Biftek", { food: { hunger: 8, sat: 12.8 } });
item("chicken", "Çiğ Tavuk", { food: { hunger: 2, sat: 1.2 } });
item("cooked_chicken", "Pişmiş Tavuk", { food: { hunger: 6, sat: 7.2 } });
item("mutton", "Çiğ Koyun Eti", { food: { hunger: 2, sat: 1.2 } });
item("cooked_mutton", "Pişmiş Koyun Eti", { food: { hunger: 6, sat: 9.6 } });

for (let t = 0; t < TOOL_TIERS.length; t++) {
  for (const type of TOOL_TYPES) {
    const tier = TOOL_TIERS[t];
    const damage = type.key === "sword" ? tier.damage : type.key === "axe" ? tier.damage - 1 : 2;
    item(`${tier.key}_${type.key}`, `${tier.name} ${type.name}`, {
      stack: 1, durability: tier.durability,
      tool: { type: type.key, tier: t, speed: tier.speed, damage },
      fuel: t === 0 ? 10 : undefined,
    });
  }
}

// ---------------------------------------------------------------- 1.2 items (append only)
item("bucket", "Kova", { stack: 16, bucket: "empty" });
item("water_bucket", "Su Kovası", { stack: 1, bucket: "water" });
item("lava_bucket", "Lav Kovası", { stack: 1, bucket: "lava", fuel: 1000 });
item("milk_bucket", "Süt Kovası", { stack: 1, food: { hunger: 0, sat: 0, drink: true } });
item("bow", "Yay", { stack: 1, durability: 384, bow: true });
item("wheat_seeds", "Buğday Tohumu", { seeds: true });
item("wheat", "Buğday");
item("bread", "Ekmek", { food: { hunger: 5, sat: 6 } });
for (let t = 0; t < TOOL_TIERS.length; t++) {
  const tier = TOOL_TIERS[t];
  item(`${tier.key}_hoe`, `${tier.name} Çapa`, { stack: 1, durability: tier.durability, tool: { type: "hoe", tier: t, speed: 1, damage: 1 }, fuel: t === 0 ? 10 : undefined });
}
// vehicles and horses are not part of this version: the ids stay (saves), the items are hidden
item("car", "Araba", { stack: 1, vehicle: "car", creative: false });
item("plane", "Uçak", { stack: 1, vehicle: "plane", creative: false });
item("boat", "Kayık", { stack: 1, vehicle: "boat", creative: false });
item("horse_egg", "At Yumurtası", { stack: 16, spawnMob: "horse", creative: false });
item("donkey_egg", "Eşek Yumurtası", { stack: 16, spawnMob: "donkey", creative: false });
item("oak_door", "Tahta Kapı", { placesDoor: true });
item("bed", "Yatak", { stack: 1, placesBed: true });
item("bone_meal", "Kemik Tozu", { boneMeal: true });
item("saddle", "Eyer", { stack: 1, saddle: true, creative: false });
for (const [k, n] of [["pig", "Domuz"], ["cow", "İnek"], ["sheep", "Koyun"], ["chicken", "Tavuk"], ["zombie", "Zombi"], ["skeleton", "İskelet"], ["puffcap", "Pufmantar"], ["villager", "Köylü"]]) {
  item(`${k}_egg`, `${n} Yumurtası`, { stack: 16, spawnMob: k });
}

// Resolve string drops now that every key exists.
for (const d of blocks) {
  if (typeof d.drop === "string") d.drop = B[d.drop] ?? I[d.drop];
  if (d.dropKey) d.drop = B[d.dropKey];
}

// Unified lookup for anything that can live in an inventory slot.
export function itemDef(id) {
  if (id < 256) {
    const b = blocks[id];
    return b ? { id, key: b.key, name: b.name, stack: b.stack, isBlock: true, block: b, fuel: b.fuel } : null;
  }
  return items.get(id) || null;
}
export const maxStack = id => itemDef(id)?.stack ?? 64;

export function byKey(key) {
  return B[key] ?? I[key];
}

// Ordered list for the creative palette.
export function creativeList() {
  const list = [];
  for (const b of blocks) if (b.creative && b.id !== 0) list.push(b.id);
  for (const d of items.values()) if (d.creative) list.push(d.id);
  return list;
}

// ---------- geometry (from geometry.js) ----------
export const FRONT_FACE = [5, 0, 4, 1];  // facing 0:+z 1:-x 2:-z 3:+x -> face index (-x, +x, -y, +y, -z, +z)
export const DIR4 = [[0, 1], [-1, 0], [0, -1], [1, 0]];
export const BED_BOX = [0, 0, 0, 1, 9 / 16, 1];
export function doorBox(facing, open) {
  const t = 3 / 16;
  switch (open ? (facing + 1) % 4 : facing) {
    case 0: return [0, 0, 0, 1, 1, t];
    case 1: return [1 - t, 0, 0, 1, 1, 1];
    case 2: return [0, 0, 1 - t, 1, 1, 1];
    default: return [0, 0, 0, t, 1, 1];
  }
}
export function ladderBox(attach) {
  const t = 1 / 16;
  const [ax, az] = DIR4[attach];
  if (az === 1) return [0, 0, 1 - t, 1, 1, 1];
  if (az === -1) return [0, 0, 0, 1, 1, t];
  if (ax === 1) return [1 - t, 0, 0, 1, 1, 1];
  return [0, 0, 0, t, 1, 1];
}
export const FACE_OF_DIR = (dx, dz) => (dx === -1 ? 0 : dx === 1 ? 1 : dz === -1 ? 4 : 5);
export const nameKey = id => (id < 256 ? blocks[id]?.nk : itemDef(id)?.key) || "unknown";

// The g3d.voxels definition of a block (SDK 1.7).
export function voxelDef(d) {
  const t = d.t || { top: 0, bottom: 0, side: 0, front: 0 };
  // faces: -x, +x, -y (bottom), +y (top), -z, +z
  const tex = [t.side, t.side, t.bottom, t.top, t.side, t.side];
  if (d.facing >= 0) tex[FRONT_FACE[d.facing]] = t.front;
  if (d.key === "crafting_table") { tex[5] = t.front; tex[1] = t.front; }
  const o = { tex, solid: d.solid, opacity: d.opacity, light: d.emit, collide: d.collide, select: d.selectable };
  if (d.fxGlow) o.glow = true;
  if (d.fxEmit || isLava(d.id) || d.id === B.fire) o.emissive = true;
  if (d.use === "furnace" && d.emit) o.frontGlow = true;
  if (d.facing >= 0) o.facing = d.facing;
  switch (d.model) {
    case "none": return { model: "none", collide: false, select: false, opacity: 0 };
    case "cube": return { model: "cube", ...o };
    case "cutout": return { model: "cutout", ...o, solid: false, leaves: !!d.leaves, cullSame: !d.leaves };
    case "cross": return { model: "cross", ...o, tex: t.side, wave: true };
    case "torch": return { model: "torch", ...o, tex: t.side, attach: d.attach ?? -1 };
    case "cactus": return { model: "cactus", ...o, collision: [0, 0, 0, 1, 1, 1] };
    case "liquid": return { model: "liquid", ...o, tex: t.side, liquid: d.liquid, level: d.liquid === "lava" ? Math.min(8, d.level * 2) : d.level };
    case "fire": return { model: "fire", ...o, tex: t.side };
    case "crop": return { model: "crop", ...o, tex: t.side, selection: [0, 0, 0, 1, 0.25 + d.crop * 0.2, 1] };
    case "fence": return { model: "fence", ...o, tex: t.side };
    case "slab": return { model: "box", ...o, box: d.box };
    case "door": {
      const box = doorBox(d.door.facing, d.door.open), tx = t.side;
      const ftex = [tx, tx, d.door.half ? 255 : tx, d.door.half ? tx : 255, tx, tx];
      return { model: "box", ...o, tex: ftex, box };
    }
    case "ladder": return { model: "box", ...o, tex: t.side, box: ladderBox(d.attach), collide: false };
    case "bed": {
      const bd = d.bed, [hx, hz] = DIR4[bd.facing];
      const endFace = bd.head ? FACE_OF_DIR(hx, hz) : FACE_OF_DIR(-hx, -hz);
      const innerFace = bd.head ? FACE_OF_DIR(-hx, -hz) : FACE_OF_DIR(hx, hz);
      const btex = [0, 1, 2, 3, 4, 5].map(f => (f === 3 ? t.top : f === 2 ? t.bottom : f === endFace ? t.front : f === innerFace ? 255 : t.side));
      return { model: "box", ...o, tex: btex, box: BED_BOX, rotate: bd.facing };
    }
    default: return { model: "cube", ...o };
  }
}
