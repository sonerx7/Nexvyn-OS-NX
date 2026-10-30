// To-do list model, persisted with store (store.json in the app's data folder, saved automatically).
export class TodoList {
  constructor() {
    const saved = store.get("todos", []);
    this.items = Array.isArray(saved) ? saved.filter((t) => t && typeof t.text === "string") : [];
    let next = 1;
    for (const t of this.items) next = Math.max(next, (t.id | 0) + 1);
    for (const t of this.items) if (!t.id) t.id = next++;
    this.nextId = next;
  }

  save() {
    store.set("todos", this.items);
  }

  add(text) {
    this.items.push({ id: this.nextId++, text, done: false, created: sys.epoch() });
    this.save();
  }

  toggle(id) {
    const t = this.items.find((x) => x.id === id);
    if (!t) return;
    t.done = !t.done;
    this.save();
  }

  remove(id) {
    this.items = this.items.filter((x) => x.id !== id);
    this.save();
  }

  clearDone() {
    const n = this.doneCount();
    this.items = this.items.filter((x) => !x.done);
    this.save();
    return n;
  }

  remaining() {
    return this.items.filter((x) => !x.done).length;
  }

  doneCount() {
    return this.items.length - this.remaining();
  }
}
