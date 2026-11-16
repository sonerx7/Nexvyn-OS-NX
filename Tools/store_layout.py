"""Canonical store placement, shared by building, validation and beta promotion.

category describes the app's purpose; kind describes its store section. Runtime
and package format do not change either. Existing package IDs must survive moves.
"""
import json
from pathlib import Path

APP_CATEGORIES = ("productivity", "office", "ai", "utilities", "media", "internet",
                  "developer", "system", "switch", "other", "showcase")
EMU_CATEGORIES = ("handheld", "console", "pc", "arcade", "multi", "other")


def placement(app, extra, section, subgroup):
    """Return (section, subgroup, category, kind) or raise on conflicting metadata."""
    category = app.get("category", "other")
    override = extra.get("category", category)
    if override != category:
        raise ValueError("app.json category %r disagrees with store.json category %r" % (category, override))
    kind = extra.get("kind", {"Games": "game", "Ports": "port", "Emulators": "emulator"}.get(section, "app"))
    if kind == "emulator":
        ec = extra.get("emuCategory", subgroup if section == "Emulators" else "other")
        sub = ec[0] if isinstance(ec, list) and ec else ec
        if sub not in EMU_CATEGORIES:
            raise ValueError("invalid emulator subcategory %r" % sub)
        return "Emulators", sub, "games", kind
    if kind in ("game", "port"):
        genre = extra.get("genre", subgroup if section in ("Games", "Ports") else "more")
        if not isinstance(genre, str) or not genre or genre in (".", "..") or any(c in genre for c in "/\\"):
            raise ValueError("invalid game genre %r" % genre)
        return "Ports" if kind == "port" else "Games", genre, "games", kind
    if kind == "demo":
        return "Apps", "showcase", "showcase", kind
    if kind != "app" or category not in APP_CATEGORIES or category == "showcase":
        raise ValueError("invalid app category/kind: %r / %r" % (category, kind))
    return "Apps", category, category, kind


def validate(store):
    """Validate stable and beta app pages before the builder writes any output."""
    store = Path(store)
    errors = []
    for channel in (store, store / "Beta"):
        for section in ("Apps", "Games", "Ports", "Emulators"):
            for page in sorted((channel / section).glob("*/*")):
                manifest = page / "source/app.json"
                if not manifest.is_file():
                    manifest = page / "app.json"
                if not manifest.is_file():
                    continue
                app = json.loads(manifest.read_text(encoding="utf-8"))
                extra_path = page / "store.json"
                extra = json.loads(extra_path.read_text(encoding="utf-8")) if extra_path.is_file() else {}
                try:
                    dest, sub, category, _ = placement(app, extra, section, page.parent.name)
                    expected = channel / dest / sub / page.name
                    if page != expected:
                        raise ValueError("move to " + expected.relative_to(store).as_posix())
                    if app.get("category", "other") != category:
                        raise ValueError("manifest category must be " + category)
                except ValueError as exc:
                    errors.append("%s: %s" % (page.relative_to(store).as_posix(), exc))
    return errors
