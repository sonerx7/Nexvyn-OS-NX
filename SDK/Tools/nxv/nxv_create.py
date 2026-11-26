#!/usr/bin/env python3
"""
Nexvyn OS N2 Smart App Creator & 4-Track Generator (N2 Plan Section 8, 13 & Phase 2).
Guides language selection based on workload profile and generates ready-to-pack project templates.

Official 4 Tracks:
  1. Lua 5.4.7 (PUC Lua - default for utilities, calculators, settings, lightweight tools)
  2. JavaScript ES2023 (QuickJS-ng 0.17.0 - default for dynamic/network/REST/JSON apps)
  3. Python 3.12 (CPython 3.12.16 - default for data processing, stdlib, automation tools)
  4. Native C/C++ (devkitA64 GCC AOT - default for 2D/3D games, OpenGL, emulators, heavy ports)

Legacy compatibility engines (PocketPy, TinyCC, miniJVM Java, Squirrel) are strictly excluded from creator options.
"""
import os
import sys
import json
import re
import struct
import zlib
import argparse
from pathlib import Path
from nxv_i18n import starter_tables

VALID_RUNTIMES = ("lua", "js", "python", "native")
VALID_PROFILES = ("calculator", "utility", "network", "data", "game", "qemu", "emulator", "port")

PROFILE_RECOMMENDATIONS = {
    "calculator": {
        "runtime": "lua",
        "reason": "Fastest cold-start time, lowest RAM footprint, and responsive NXUI layout for utility tools.",
        "perfBudget": {"maxRamMb": 16, "targetFps": 60, "profile": "utility"}
    },
    "utility": {
        "runtime": "lua",
        "reason": "Lightweight resource usage and immediate NXUI scripting for system utilities and panels.",
        "perfBudget": {"maxRamMb": 24, "targetFps": 60, "profile": "utility"}
    },
    "network": {
        "runtime": "js",
        "reason": "Native JSON modeling, Promises/async-await, and REST/WebSocket integration via QuickJS-ng ES2023.",
        "perfBudget": {"maxRamMb": 32, "targetFps": 60, "profile": "media/network"}
    },
    "data": {
        "runtime": "python",
        "reason": "Full CPython 3.12 standard library, data analysis, and rich scripting ecosystem.",
        "perfBudget": {"maxRamMb": 48, "targetFps": 60, "profile": "utility"}
    },
    "game": {
        "runtime": "native",
        "reason": "Direct OpenGL 4.3 / NexGFX GPU control, deterministic 60 FPS frame pacing, and full AArch64 speed.",
        "perfBudget": {"maxRamMb": 128, "targetFps": 60, "profile": "2D/3D game"}
    },
    "qemu": {
        "runtime": "native",
        "reason": "Ahead-Of-Time GCC compilation, virtual memory W^X JIT support, and low-level Port Kit architecture.",
        "perfBudget": {"maxRamMb": 256, "targetFps": 60, "profile": "emulator/heavy port"}
    },
    "emulator": {
        "runtime": "native",
        "reason": "Low-level CPU loops, W^X JIT code memory, multi-threaded audio/video, and Port Kit foundation.",
        "perfBudget": {"maxRamMb": 256, "targetFps": 60, "profile": "emulator/heavy port"}
    },
    "port": {
        "runtime": "native",
        "reason": "Direct C/C++ compilation with devkitA64 GCC and Native SDK ABI v1 window/OpenGL/audio bridges.",
        "perfBudget": {"maxRamMb": 192, "targetFps": 60, "profile": "emulator/heavy port"}
    }
}

def make_png(size=256):
    """Pure-Python gradient PNG icon generator."""
    rows = bytearray()
    for y in range(size):
        rows.append(0)
        for x in range(size):
            rows += bytes((20 + x // 5, 30 + y // 6, 90 + (x + y) // 8))
    def chunk(t, data):
        c = struct.pack(">I", len(data)) + t + data
        return c + struct.pack(">I", zlib.crc32(t + data) & 0xFFFFFFFF)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b""))

def score_workload(answers):
    """
    Evaluates questionnaire answers to recommend the optimal language track (Section 8.1).
    """
    scores = {"lua": 0, "js": 0, "python": 0, "native": 0}

    if answers.get("has_c_deps"):
        scores["native"] += 12
    if answers.get("is_emulator_or_vm"):
        scores["native"] += 15
    if answers.get("is_heavy_3d"):
        scores["native"] += 10
    if answers.get("is_network_json"):
        scores["js"] += 10
    if answers.get("is_data_script"):
        scores["python"] += 10
    if answers.get("is_lightweight_tool"):
        scores["lua"] += 12
    if answers.get("fast_startup_low_ram"):
        scores["lua"] += 8

    best = max(scores, key=scores.get)
    return best, scores

def create_project(dest_dir, app_id, name, runtime, profile="utility"):
    dest = Path(dest_dir)
    dest.mkdir(parents=True, exist_ok=True)

    perf_info = PROFILE_RECOMMENDATIONS.get(profile, PROFILE_RECOMMENDATIONS["utility"])
    perf_budget = perf_info["perfBudget"]

    manifest = {
        "id": app_id,
        "name": name,
        "version": "1.0.0",
        "build": 1,
        "type": "app",
        "runtime": runtime,
        "minSdk": "1.12",
        "targetSdk": "2.0",
        "targetNative": "2.0",
        "dataSchema": 1,
        "uiApi": 2,
        "uiTheme": 2,
        "perfBudget": perf_budget,
        "author": "Nexvyn Developer",
        "description": f"{name} - built for Nexvyn OS N2",
        "window": {
            "width": 920,
            "height": 580,
            "minWidth": 480,
            "minHeight": 320,
            "resizable": True
        },
        "permissions": []
    }

    if runtime == "native":
        manifest["runtime"] = "native"
        manifest["mode"] = "window"
        manifest["minNative"] = "1.3"
        manifest["targetNative"] = "2.0"
        manifest["main"] = f"{app_id}.nxvmod"
    elif runtime == "lua":
        manifest["main"] = "main.lua"
    elif runtime == "js":
        manifest["main"] = "main.js"
    elif runtime == "python":
        manifest["main"] = "main.py"

    # Write app.json
    (dest / "app.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    # All eight locales are required for new apps and games.
    lang_dir = dest / "lang"
    lang_dir.mkdir(exist_ok=True)
    for code, table in starter_tables(name).items():
        (lang_dir / (code + ".json")).write_text(json.dumps(table, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    # Write icon.png
    (dest / "icon.png").write_bytes(make_png())

    # Write main code file with real Nexvyn OS lifecycle callbacks (load, update, draw, event)
    if runtime == "lua":
        code = f"""-- {name} (Nexvyn OS N2 — Official Lua 5.4.7 Track)
local app = {{
    count = 0,
    sliderVal = 0.5
}}

function app.load(arg)
    print("[{name}] Loaded with Nexvyn OS N2 Lua 5.4.7 runtime")
end

function app.update(dt)
    -- Per-frame logic update
end

function app.draw(w, h)
    gfx.clear(theme.bg)
    nxui.begin(w, h)
    nxui.card("main_card")
        nxui.label("hdr", TR("greeting"), "title")
        nxui.label("sub", TR("counter") .. ": " .. tostring(app.count), "body")
        if nxui.button("btn_inc", TR("action.confirm") .. " (+1)", "primary") then
            app.count = app.count + 1
        end
        app.sliderVal = nxui.slider("sl_demo", app.sliderVal, 0.0, 1.0)
    nxui.cardEnd()
    nxui.endFrame()
end

function app.event(e)
    -- Handle raw input/window events if needed
end

return app
"""
        (dest / "main.lua").write_text(code, encoding="utf-8")

    elif runtime == "js":
        code = f"""// {name} (Nexvyn OS N2 — Official QuickJS-ng ES2023 Track)

export default {{
    count: 0,
    sliderVal: 0.5,

    load(arg) {{
        print("[{name}] Loaded with Nexvyn OS N2 QuickJS-ng ES2023 runtime");
    }},

    update(dt) {{
        // Per-frame state update
    }},

    draw(w, h) {{
        gfx.clear(theme.bg);
        nxui.begin(w, h);
        nxui.card("main_card");
            nxui.label("hdr", TR("greeting"), "title");
            nxui.label("sub", `${{TR("counter")}}: ${{this.count}}`, "body");
            if (nxui.button("btn_inc", `${{TR("action.confirm")}} (+1)`, "primary")) {{
                this.count += 1;
            }}
            this.sliderVal = nxui.slider("sl_demo", this.sliderVal, 0.0, 1.0);
        nxui.cardEnd();
        nxui.endFrame();
    }},

    event(e) {{
        // Optional event handler
    }}
}};
"""
        (dest / "main.js").write_text(code, encoding="utf-8")

    elif runtime == "python":
        code = f"""# {name} (Nexvyn OS N2 — Official CPython 3.12 Track)


class App:
    def __init__(self):
        self.count = 0
        self.slider_val = 0.5

    def load(self, arg=""):
        print("[{name}] Loaded with Nexvyn OS N2 CPython 3.12 runtime")

    def update(self, dt):
        pass

    def draw(self, w, h):
        gfx.clear(theme.bg)
        nxui.begin(w, h)
        nxui.card("main_card")
        nxui.label("hdr", TR("greeting"), "title")
        nxui.label("sub", TR("counter") + ": " + str(self.count), "body")
        if nxui.button("btn_inc", f"{{TR('action.confirm')}} (+1)", "primary"):
            self.count += 1
        self.slider_val = nxui.slider("sl_demo", self.slider_val, 0.0, 1.0)
        nxui.cardEnd()
        nxui.endFrame()

    def event(self, e):
        pass


app = App()
"""
        (dest / "main.py").write_text(code, encoding="utf-8")

    elif runtime == "native":
        template_kind = "game" if profile == "game" else "app"
        candidates = [base / rel for base in Path(__file__).resolve().parents for rel in (
            f"sdk/native/templates/{template_kind}", f"Languages/c/native-kit/sdk/native/templates/{template_kind}",
            f"SDK/Languages/c/native-kit/sdk/native/templates/{template_kind}")]
        template = next((path for path in candidates if path.is_dir()), None)
        if template is None:
            raise FileNotFoundError("Native app template missing: install the complete Native SDK kit")
        overrides = template / "template.json"
        if overrides.is_file():
            manifest.update(json.loads(overrides.read_text(encoding="utf-8")))
        project_name = re.sub(r"[^a-z0-9_]", "_", app_id.lower())
        for source in template.rglob("*"):
            if not source.is_file():
                continue
            target = dest / source.relative_to(template)
            target.parent.mkdir(parents=True, exist_ok=True)
            title = json.dumps(name, ensure_ascii=False)[1:-1] if source.suffix == ".json" else name
            text = source.read_text(encoding="utf-8").replace("@NAME@", project_name).replace("@TITLE@", title).replace("@ID@", app_id)
            target.write_text(text, encoding="utf-8")
        manifest["main"] = project_name + ".nxvmod"
        (dest / "app.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        if profile == "game":
            manifest["type"] = "game"
            manifest["category"] = "games"
            manifest["mode"] = "fullscreen"
            app_locales = template.parent / "app/lang"
            for source in app_locales.glob("*.json"):
                target = dest / "lang" / source.name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(source.read_text(encoding="utf-8").replace("@TITLE@", json.dumps(name, ensure_ascii=False)[1:-1]), encoding="utf-8")
            (dest / "app.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        return dest
    return dest

def main():
    parser = argparse.ArgumentParser(description="Nexvyn OS N2 Smart App Creator")
    parser.add_argument("name", nargs="?", default="MyNewApp", help="Application display name")
    parser.add_argument("--id", help="Reverse domain package ID (e.g. com.example.calc)")
    parser.add_argument("--profile", choices=VALID_PROFILES, help="Target workload profile")
    parser.add_argument("--runtime", choices=VALID_RUNTIMES, help="Explicitly force runtime (lua, js, python, native)")
    parser.add_argument("--dir", help="Destination folder (defaults to ./<name>)")
    parser.add_argument("--recommend-only", action="store_true", help="Print recommendation without creating files")
    args = parser.parse_args()

    profile = args.profile or "utility"
    rec = PROFILE_RECOMMENDATIONS.get(profile, PROFILE_RECOMMENDATIONS["utility"])
    chosen_runtime = args.runtime or rec["runtime"]

    if args.recommend_only:
        print(f"Profile:        {profile}")
        print(f"Recommendation: {rec['runtime']}")
        print(f"Reason:         {rec['reason']}")
        print(f"RAM Budget:     {rec['perfBudget']['maxRamMb']} MB")
        print(f"Target FPS:     {rec['perfBudget']['targetFps']}")
        return

    safe_name = re.sub(r"[^a-zA-Z0-9_\-]", "", args.name.lower())
    app_id = args.id or f"com.nexvyn.{safe_name}"
    target_dir = args.dir or str(Path(safe_name))

    print("--- Nexvyn OS N2 App Creator ---")
    print(f"App Name:       {args.name}")
    print(f"Package ID:     {app_id}")
    print(f"Profile:        {profile}")
    print(f"Runtime:        {chosen_runtime} (Recommended: {rec['runtime']})")
    print(f"Target Dir:     {target_dir}")

    created = create_project(target_dir, app_id, args.name, chosen_runtime, profile)
    print(f"\nSUCCESS: Project created at {created}")
    print(f"To pack:   python tools/nxv.py pack {target_dir}")
    print(f"To check:  python tools/nxv.py check {target_dir}")

if __name__ == "__main__":
    main()
