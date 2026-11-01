// Worlds on disk, in the app's data folder:
//   worlds/index.json        list of { id, name, seed, type, mode, created, lastPlayed }
//   worlds/<id>/world.json    everything but the blocks (player, inventory, time, chests, furnaces, mobs, weather)
//   worlds/<id>/chunks/       modified chunks, written by the voxel world itself (g3d.voxels "save" folder)
const INDEX = "worlds/index.json";

export function listWorlds() {
  const t = fs.read(INDEX);
  const list = t ? json.decode(t) : null;
  if (!Array.isArray(list)) return [];
  return list.filter(w => w && w.id).sort((a, b) => (b.lastPlayed || 0) - (a.lastPlayed || 0));
}

function writeIndex(list) {
  fs.mkdir("worlds");
  fs.write(INDEX, json.encode(list));
}

export function newWorldId() {
  return "w" + Date.now().toString(36) + ((Math.random() * 1296) | 0).toString(36);
}

export function chunkDir(id) { return `worlds/${id}/chunks`; }

export function loadWorld(id) {
  const t = fs.read(`worlds/${id}/world.json`);
  const m = t ? json.decode(t) : null;
  return m && typeof m === "object" ? m : null;
}

export function saveWorld(meta) {
  fs.mkdir(`worlds/${meta.id}`);
  const ok = fs.write(`worlds/${meta.id}/world.json`, json.encode(meta));
  const list = listWorlds().filter(w => w.id !== meta.id);
  list.push({ id: meta.id, name: meta.name, seed: meta.seed, type: meta.type, mode: meta.mode, created: meta.created, lastPlayed: meta.lastPlayed });
  writeIndex(list);
  return ok;
}

export function deleteWorld(id) {
  fs.remove(`worlds/${id}`, true);
  writeIndex(listWorlds().filter(w => w.id !== id));
}

export function renameWorld(id, name) {
  const m = loadWorld(id);
  if (m) { m.name = name; saveWorld(m); }
}
