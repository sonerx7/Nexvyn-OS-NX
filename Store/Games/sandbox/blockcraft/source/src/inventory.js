// Item stacks and the player inventory. A stack is a plain object { id, count, damage }.
import { itemDef, maxStack } from "./registry.js";

export const stack = (id, count = 1, damage = 0) => ({ id, count, damage });
export const clone = s => (s ? { id: s.id, count: s.count, damage: s.damage || 0 } : null);
export const sameItem = (a, b) => !!a && !!b && a.id === b.id && (a.damage || 0) === (b.damage || 0);
export const canStack = (a, b) => sameItem(a, b) && maxStack(a.id) > 1;

export const serializeStacks = arr => arr.map(s => (s ? [s.id, s.count, s.damage || 0] : 0));
export const deserializeStacks = (arr, size) => {
  const out = new Array(size).fill(null);
  if (Array.isArray(arr)) arr.forEach((v, i) => { if (i < size && Array.isArray(v) && itemDef(v[0])) out[i] = stack(v[0], v[1], v[2] || 0); });
  return out;
};

// Adds as much of `s` as fits into `slots[order...]`. Mutates s.count; returns the leftover count.
export function addToSlots(slots, s, order) {
  const max = maxStack(s.id);
  for (const i of order) {
    if (s.count <= 0) break;
    const t = slots[i];
    if (t && canStack(t, s) && t.count < max) {
      const n = Math.min(max - t.count, s.count);
      t.count += n; s.count -= n;
    }
  }
  for (const i of order) {
    if (s.count <= 0) break;
    if (!slots[i]) {
      const n = Math.min(max, s.count);
      slots[i] = stack(s.id, n, s.damage || 0);
      s.count -= n;
    }
  }
  return s.count;
}

const HOTBAR_FIRST = [...Array(36).keys()];

export class Inventory {
  constructor() {
    this.slots = new Array(36).fill(null); // 0-8 hotbar, 9-35 main
    this.selected = 0;
    this.version = 0; // bumped on every change so the UI knows when to redraw
  }

  get held() { return this.slots[this.selected]; }

  changed() { this.version++; }

  // Returns the count that did NOT fit.
  add(s) {
    const copy = clone(s);
    const left = addToSlots(this.slots, copy, HOTBAR_FIRST);
    if (left !== s.count) this.changed();
    return left;
  }

  canFit(s) {
    const max = maxStack(s.id);
    let room = 0;
    for (const t of this.slots) {
      if (!t) room += max;
      else if (canStack(t, s)) room += max - t.count;
      if (room >= s.count) return true;
    }
    return false;
  }

  count(id) { let n = 0; for (const t of this.slots) if (t && t.id === id) n += t.count; return n; }

  // Removes n items from slot i; returns the removed stack.
  take(i, n = 1) {
    const t = this.slots[i];
    if (!t) return null;
    const k = Math.min(n, t.count);
    t.count -= k;
    if (t.count <= 0) this.slots[i] = null;
    this.changed();
    return stack(t.id, k, t.damage);
  }

  consumeHeld(n = 1) { return this.take(this.selected, n); }

  // Wears the held tool. Returns true if it broke.
  damageHeld(amount = 1) {
    const t = this.held;
    if (!t) return false;
    const def = itemDef(t.id);
    if (!def || !def.durability) return false;
    t.damage = (t.damage || 0) + amount;
    this.changed();
    if (t.damage >= def.durability) { this.slots[this.selected] = null; return true; }
    return false;
  }

  // Moves stack in slot i to the other section (hotbar <-> main). Used by shift-click.
  quickMove(i) {
    const s = this.slots[i];
    if (!s) return;
    const order = i < 9 ? [...Array(27).keys()].map(k => k + 9) : [...Array(9).keys()];
    const copy = clone(s);
    const left = addToSlots(this.slots, copy, order);
    if (left <= 0) this.slots[i] = null; else this.slots[i].count = left;
    this.changed();
  }

  clear() { this.slots.fill(null); this.changed(); }

  toJSON() { return { slots: serializeStacks(this.slots), selected: this.selected }; }
  load(data) {
    if (!data) return;
    this.slots = deserializeStacks(data.slots, 36);
    this.selected = Math.max(0, Math.min(8, data.selected | 0));
    this.changed();
  }
}
