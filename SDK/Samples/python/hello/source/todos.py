# To-do list model, persisted with store (store.json in the app's data folder, saved automatically).
# Items are plain dicts, so store.set can save them as JSON.


class TodoList:
    def __init__(self):
        saved = store.get("todos", [])
        if not isinstance(saved, list):
            saved = []
        self.items = [t for t in saved if isinstance(t, dict) and isinstance(t.get("text"), str)]
        next_id = 1
        for t in self.items:
            next_id = max(next_id, int(t.get("id") or 0) + 1)
        for t in self.items:
            if not t.get("id"):
                t["id"] = next_id
                next_id += 1
        self.next_id = next_id

    def save(self):
        store.set("todos", self.items)

    def add(self, text):
        self.items.append({"id": self.next_id, "text": text, "done": False, "created": sys.epoch()})
        self.next_id += 1
        self.save()

    def toggle(self, item_id):
        for t in self.items:
            if t["id"] == item_id:
                t["done"] = not t["done"]
                self.save()
                return

    def remove(self, item_id):
        self.items = [t for t in self.items if t["id"] != item_id]
        self.save()

    def clear_done(self):
        n = self.done_count()
        self.items = [t for t in self.items if not t["done"]]
        self.save()
        return n

    def remaining(self):
        return len([t for t in self.items if not t["done"]])

    def done_count(self):
        return len(self.items) - self.remaining()
