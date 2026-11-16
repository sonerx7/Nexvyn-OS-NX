"""Host-only regression checks: python -m unittest discover -s Tools -p test_store_layout.py"""
import json
from pathlib import Path
import tempfile
import unittest

from store_layout import placement, validate


class StoreLayoutTests(unittest.TestCase):
    def test_catalog_preserves_package_requirements(self):
        from build_store import store_meta
        entry = {}
        store_meta(entry, {"runtime": "native", "minOs": "1.3.26", "minNative": "1.2"},
                   None, {"kind": "port", "features": ["offline"], "minOs": "1.0.0"},
                   "port", "Store/Beta/Ports/strategy/redalert2", [])
        self.assertEqual(entry["minOs"], "1.3.26")
        self.assertEqual(entry["minNative"], "1.2")

    def test_manifest_override_conflict(self):
        with self.assertRaises(ValueError):
            placement({"category": "system"}, {"category": "ai"}, "Apps", "ai")

    def test_emulator_primary_category(self):
        result = placement({"category": "games"}, {"kind": "emulator", "emuCategory": ["handheld", "console"]}, "Games", "arcade")
        self.assertEqual(result, ("Emulators", "handheld", "games", "emulator"))

    def test_port_and_demo_sections(self):
        self.assertEqual(placement({"category": "games"}, {"kind": "port", "genre": "strategy"}, "Ports", "strategy")[:3],
                         ("Ports", "strategy", "games"))
        self.assertEqual(placement({"category": "showcase"}, {"kind": "demo"}, "Apps", "showcase")[:3],
                         ("Apps", "showcase", "showcase"))

    def test_reject_unsafe_genre(self):
        with self.assertRaises(ValueError):
            placement({"category": "games"}, {"kind": "port", "genre": "../system"}, "Ports", "action")

    def test_misfiled_page_detected_before_packaging(self):
        with tempfile.TemporaryDirectory() as tmp:
            store = Path(tmp)
            page = store / "Apps/ai/benchmark/source"
            page.mkdir(parents=True)
            (page / "app.json").write_text(json.dumps({"category": "system"}), encoding="utf-8")
            self.assertIn("move to Apps/system/benchmark", validate(store)[0])


if __name__ == "__main__":
    unittest.main()
